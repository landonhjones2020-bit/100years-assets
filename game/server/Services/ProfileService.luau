--!strict
--[[
	ProfileService: saved data (bible Section 23; Prompt 2). One profile per player, in both
	places.

	The stored value is a record { Data = profile, Lock = { Session, PlaceId, At }, Meta }.
	Every read-modify-write goes through UpdateAsync:
	* load claims the lock: a fresh lock held by another server means wait and retry (it may
	  be saving on the way out, as when a player teleports from the Lobby), and in the end
	  refuse; a stale lock (a crashed server) is taken over. Data newer than this server's
	  ProfileSchema.VERSION is never loaded or written.
	* the profile then goes through migrate, reconcile, validate (ProfileSchema.Load). A failed
	  or refused load kicks the player with a message and writes nothing.
	* saves happen every Constants.AUTOSAVE_SECONDS (staggered per player; each also refreshes
	  the lock), when the player leaves (and releases the lock) and on shutdown (BindToClose).
	  A save only writes if this server still holds the lock and the profile still validates.

	Gameplay never touches DataStores: it calls Update, AddGlowshards, SpendGlowshards and
	GrantPurchase. The player's own client sees their profile (minus receipts) in the
	"Profiles" collection of the delta channel. A session isn't ready until the profile loads
	(the "Profile" gate in SessionService).

	In Studio the store is PlayerProfiles_Studio, so tests never touch live saves; if Studio
	has no API access, an in-memory store stands in (and says so).
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)
local TableUtil = require(Shared.Utilities.TableUtil)
local ProfileSchema = require(ServerScriptService:WaitForChild("Lib"):WaitForChild("ProfileSchema"))

local log = Log.new("ProfileService")

local IS_STUDIO = RunService:IsStudio()
local STORE_NAME = if IS_STUDIO then "PlayerProfiles_Studio" else "PlayerProfiles"
local SESSION_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local LOCK_STALE_SECONDS = if IS_STUDIO then 30 else Constants.AUTOSAVE_SECONDS * 3
local CLAIM_ATTEMPTS = 8
local CLAIM_WAIT_SECONDS = 2
local CALL_ATTEMPTS = 4
local SHUTDOWN_WAIT_SECONDS = if IS_STUDIO then 8 else 25
local GATE = "Profile"

local MESSAGES: { [string]: string } = {
	Locked = "Your save is still being written by another server. Please rejoin in a moment.",
	TooNew = "Your save is from a newer version of the game. Please rejoin to get an up-to-date server.",
	Corrupt = "We couldn't read your save, so nothing was changed. Please rejoin; if this keeps happening, let us know.",
	Invalid = "We couldn't read your save, so nothing was changed. Please rejoin; if this keeps happening, let us know.",
	Error = "Saved data is unavailable right now (Roblox DataStores). Please rejoin in a few minutes.",
	LockLost = "Your save was opened in another server, so this one stopped. Please rejoin.",
}

export type Profile = { [string]: any }

type Session = {
	Player: Player,
	Key: string,
	Data: Profile,
	Receipts: { [string]: boolean },
	Saving: boolean,
	Released: boolean,
	LockLost: boolean,
	NextSave: number,
	Saves: number,
}

local ProfileService = {
	Name = "ProfileService",
	Dependencies = { "SessionService", "ReplicationService", "DevService" },
	Loaded = Signal.new() :: Signal.Signal<Player, Profile>,
	Releasing = Signal.new() :: Signal.Signal<Player>,
}

local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local sessionService: any = nil
local profiles: any = nil
local store: any = nil
local storeKind = "none"
local usingDataStore = false
local shuttingDown = false
local releasesInFlight = 0

-- An in-memory store with DataStore semantics (values go through JSON, as they would).
local function memoryStore(): any
	local values: { [string]: string } = {}
	local memory = {}
	function memory.UpdateAsync(_self: any, key: string, transform: (any) -> any): any
		local current = values[key]
		local result = transform(if current then HttpService:JSONDecode(current) else nil)
		if result ~= nil then
			values[key] = HttpService:JSONEncode(result)
		end
		return result
	end
	function memory.GetAsync(_self: any, key: string): any
		local current = values[key]
		return if current then HttpService:JSONDecode(current) else nil
	end
	function memory.RemoveAsync(_self: any, key: string): any
		local current = values[key]
		values[key] = nil
		return if current then HttpService:JSONDecode(current) else nil
	end
	return memory
end

local function keyFor(userId: number): string
	return `Player_{userId}`
end

-- Calls a DataStore function with retries and backoff. Returns ok and its result or error.
local function attempt(what: string, call: () -> any): (boolean, any)
	local delay = 1
	local lastError: any = nil
	for try = 1, CALL_ATTEMPTS do
		local ok, result = pcall(call)
		if ok then
			return true, result
		end
		lastError = result
		log:Warn("%s failed (try %d of %d): %s", what, try, CALL_ATTEMPTS, tostring(result))
		if try < CALL_ATTEMPTS then
			task.wait(delay)
			delay = math.min(delay * 2, 8)
		end
	end
	return false, lastError
end

local function isForeignLock(lock: any): boolean
	return type(lock) == "table"
		and lock.Session ~= SESSION_ID
		and type(lock.At) == "number"
		and os.time() - lock.At < LOCK_STALE_SECONDS
end

local function isTooNew(data: any): boolean
	return type(data) == "table" and type(data.Version) == "number" and data.Version > ProfileSchema.VERSION
end

-- Claims a key's lock. Returns "Claimed" and the stored Data (nil for a new player), or
-- "Locked", "TooNew", "Corrupt" or "Error" (and the error).
local function claim(key: string): (string, any)
	local status, stored = "Error", nil
	local ok, err = attempt(`claim {key}`, function(): any
		status, stored = "Error", nil
		return store:UpdateAsync(key, function(old: any): any
			if old ~= nil and (type(old) ~= "table" or (old.Data ~= nil and type(old.Data) ~= "table")) then
				status = "Corrupt"
				return nil
			end
			local record = old or {}
			if isForeignLock(record.Lock) then
				status = "Locked"
				return nil
			end
			if isTooNew(record.Data) then
				status = "TooNew"
				return nil
			end
			record.Lock = { Session = SESSION_ID, PlaceId = game.PlaceId, At = os.time() }
			if type(record.Meta) ~= "table" then
				record.Meta = { Created = os.time(), Saves = 0 }
			end
			status, stored = "Claimed", record.Data
			return record
		end)
	end)
	if not ok then
		return "Error", tostring(err)
	end
	return status, stored
end

-- Gives a lock back without touching the data (after a load we can't use).
local function releaseLockOnly(key: string)
	attempt(`release {key}`, function(): any
		return store:UpdateAsync(key, function(old: any): any
			if type(old) ~= "table" or type(old.Lock) ~= "table" or old.Lock.Session ~= SESSION_ID then
				return nil
			end
			old.Lock = nil
			return old
		end)
	end)
end

-- Writes the session's profile (and releases the lock if asked). Only if we still hold it.
local function write(session: Session, release: boolean): boolean
	local valid, why = ProfileSchema.Validate(session.Data)
	if not valid then
		log:Error("%s: not saving an invalid profile (%s)", session.Key, tostring(why))
		return false
	end
	local data = session.Data
	local status = "Error"
	local ok, err = attempt(`save {session.Key}`, function(): any
		status = "Error"
		return store:UpdateAsync(session.Key, function(old: any): any
			local record = if type(old) == "table" then old else {}
			local lock = record.Lock
			if type(lock) ~= "table" or lock.Session ~= SESSION_ID then
				status = "LockLost"
				return nil
			end
			if isTooNew(record.Data) then
				status = "TooNew"
				return nil
			end
			record.Data = data
			record.Lock = if release then nil else { Session = SESSION_ID, PlaceId = game.PlaceId, At = os.time() }
			local meta = if type(record.Meta) == "table" then record.Meta else {}
			meta.Saves = (tonumber(meta.Saves) or 0) + 1
			meta.LastSave = os.time()
			meta.LastPlace = game.PlaceId
			record.Meta = meta
			status = "Saved"
			return record
		end)
	end)
	if not ok then
		log:Error("couldn't save %s: %s", session.Key, tostring(err))
		return false
	end
	if status == "LockLost" then
		session.LockLost = true
		log:Error("%s: the save lock is gone; not writing over another server", session.Key)
		if session.Player.Parent == Players and not release then
			session.Player:Kick(MESSAGES.LockLost)
		end
		return false
	end
	if status ~= "Saved" then
		log:Error("%s: save refused (%s)", session.Key, status)
		return false
	end
	session.Saves += 1
	return true
end

-- One write at a time per player; a release waits for a running save, then finishes.
local function save(session: Session, release: boolean): boolean
	while session.Saving do
		task.wait(0.1)
	end
	if session.Released or session.LockLost then
		return false
	end
	session.Saving = true
	local ok = write(session, release)
	session.Saving = false
	session.NextSave = os.clock() + Constants.AUTOSAVE_SECONDS
	if release then
		session.Released = true
	end
	return ok
end

local function publish(session: Session)
	local key = tostring(session.Player.UserId)
	if profiles:Get(key) == nil then
		profiles:Set(key, ProfileSchema.Public(session.Data))
	else
		profiles:Patch(key, ProfileSchema.Public(session.Data))
	end
end

local function load(player: Player)
	if loading[player] or sessions[player] then
		return
	end
	loading[player] = true
	local key = keyFor(player.UserId)
	local status, stored = "Locked", nil
	for try = 1, CLAIM_ATTEMPTS do
		status, stored = claim(key)
		if status ~= "Locked" or player.Parent ~= Players then
			break
		end
		log:Info("%s's save is open in another server; waiting (%d of %d)", player.Name, try, CLAIM_ATTEMPTS)
		task.wait(CLAIM_WAIT_SECONDS)
	end
	loading[player] = nil
	if status ~= "Claimed" then
		log:Error("%s: profile not loaded (%s %s)", player.Name, status, tostring(stored))
		if player.Parent == Players then
			sessionService:Fail(player, MESSAGES[status] or MESSAGES.Error)
		end
		return
	end
	local data, loadStatus, why = ProfileSchema.Load(stored)
	if not data then
		releaseLockOnly(key)
		log:Error("%s: profile %s (%s); nothing written", player.Name, loadStatus, tostring(why))
		if player.Parent == Players then
			sessionService:Fail(player, MESSAGES[loadStatus] or MESSAGES.Invalid)
		end
		return
	end
	local session: Session = {
		Player = player,
		Key = key,
		Data = data,
		Receipts = {},
		Saving = false,
		Released = false,
		LockLost = false,
		NextSave = os.clock() + (player.UserId % Constants.AUTOSAVE_SECONDS) + 5,
		Saves = 0,
	}
	for _, receiptId in data.Receipts do
		session.Receipts[receiptId] = true
	end
	if player.Parent ~= Players then
		release(session) -- left while loading: write what we migrated and let go
		return
	end
	sessions[player] = session
	publish(session)
	player:SetAttribute("ProfileLoaded", true)
	log:Info("%s: profile %s, %d Glowshards", player.Name, loadStatus, data.Glowshards)
	ProfileService.Loaded:Fire(player, data)
	sessionService:Pass(player, GATE)
end

-- Saves and lets go of a session; shutdown waits for every release in flight.
local function release(session: Session)
	releasesInFlight += 1
	local ok, err = pcall(save, session, true)
	releasesInFlight -= 1
	if not ok then
		log:Error("%s: release failed: %s", session.Key, tostring(err))
	end
end

local function leave(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	ProfileService.Releasing:Fire(player)
	profiles:Remove(tostring(player.UserId))
	release(session)
end

-- Public API --------------------------------------------------------------------------------

function ProfileService:IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- The live profile (read it; change it only through Update).
function ProfileService:Get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.Data else nil
end

--[[
	Changes a profile. `change` edits the table it is given and must not yield. If it errors or
	leaves the profile invalid, every change is undone and Update returns false. Changes are
	replicated to the player and saved with the next save.
]]
function ProfileService:Update(player: Player, change: (Profile) -> ()): boolean
	local session = sessions[player]
	if not session or session.Released then
		return false
	end
	local data = session.Data
	local backup = TableUtil.DeepCopy(data)
	local ok, err = pcall(change, data)
	local valid, why = true, nil
	if ok then
		valid, why = ProfileSchema.Validate(data)
	end
	if not ok or not valid then
		table.clear(data)
		for field, value in backup do
			data[field] = value
		end
		log:Error("%s: profile change undone (%s)", player.Name, tostring(if ok then why else err))
		return false
	end
	publish(session)
	return true
end

function ProfileService:AddGlowshards(player: Player, amount: number, reason: string): boolean
	assert(amount >= 0 and amount % 1 == 0, "AddGlowshards: a whole, positive amount")
	local ok = ProfileService:Update(player, function(data)
		data.Glowshards += amount
	end)
	if ok then
		log:Info("%s +%d Glowshards (%s)", player.Name, amount, reason)
	end
	return ok
end

-- Spends Glowshards if the player has enough. Returns false (and changes nothing) otherwise.
function ProfileService:SpendGlowshards(player: Player, amount: number, reason: string): boolean
	assert(amount >= 0 and amount % 1 == 0, "SpendGlowshards: a whole, positive amount")
	local data = ProfileService:Get(player)
	if not data or data.Glowshards < amount then
		return false
	end
	local ok = ProfileService:Update(player, function(profile)
		profile.Glowshards -= amount
	end)
	if ok then
		log:Info("%s -%d Glowshards (%s)", player.Name, amount, reason)
	end
	return ok
end

-- Saves now (yields). True when the profile is safely stored.
function ProfileService:SaveNow(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and save(session, false)
end

function ProfileService:HasReceipt(player: Player, receiptId: string): boolean
	local session = sessions[player]
	return session ~= nil and session.Receipts[receiptId] == true
end

--[[
	For ProcessReceipt (bible Section 17): grant first, record the receipt id in the profile,
	save, and only then tell Roblox it was granted. A repeated receipt is never granted twice:
	if the id is already recorded, the grant is skipped and only the save is redone.
]]
function ProfileService:GrantPurchase(player: Player, receiptId: string, grant: (Profile) -> ()): Enum.ProductPurchaseDecision
	local session = sessions[player]
	if not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not session.Receipts[receiptId] then
		local ok = ProfileService:Update(player, function(data)
			grant(data)
			ProfileSchema.AddReceipt(data, receiptId)
		end)
		if not ok then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		session.Receipts[receiptId] = true
	end
	if save(session, false) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- DevTools ---------------------------------------------------------------------------------

local function targetOf(player: Player?, arg: any): Player?
	if type(arg) == "number" then
		return Players:GetPlayerByUserId(arg)
	end
	return player or Players:GetPlayers()[1]
end

local function summary(data: Profile): string
	local classes = TableUtil.SortedKeys(data.Classes)
	local legends = TableUtil.SortedKeys(data.Legends)
	return `v{data.Version}, {data.Glowshards} Glowshards, account level {data.AccountLevel}, `
		.. `classes {table.concat(classes :: { any }, "/")}, Legends {table.concat(legends :: { any }, "/")}, `
		.. `receipts {#data.Receipts}, first run done {tostring(data.FirstRunDone)}`
end

-- Runs the lock rules against a scratch key (Studio store only).
local function lockTest(): string
	local key = `Test_{SESSION_ID}`
	local lines = {}
	local function step(name: string, expected: string, got: string)
		table.insert(lines, `{if got == expected then "ok  " else "FAIL"} {name}: {got} (expected {expected})`)
	end
	store:RemoveAsync(key)
	step("new key", "Claimed", (claim(key)))
	store:UpdateAsync(key, function(old: any): any
		old.Lock = { Session = "another-server", PlaceId = 1, At = os.time() }
		return old
	end)
	step("fresh foreign lock", "Locked", (claim(key)))
	store:UpdateAsync(key, function(old: any): any
		old.Lock.At = os.time() - LOCK_STALE_SECONDS - 5
		return old
	end)
	step("stale foreign lock", "Claimed", (claim(key)))
	store:UpdateAsync(key, function(_old: any): any
		return { Data = { Version = ProfileSchema.VERSION + 1, Glowshards = 7 } }
	end)
	step("newer version", "TooNew", (claim(key)))
	local after = store:GetAsync(key)
	step("newer data untouched", "untouched", if after.Lock == nil and after.Data.Glowshards == 7 then "untouched" else "changed")
	store:UpdateAsync(key, function(_old: any): any
		return "garbage"
	end)
	step("corrupt record", "Corrupt", (claim(key)))
	store:RemoveAsync(key)
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("profile", {
		Description = "A player's profile (yours, or by user id).",
		Usage = "profile [userId]",
		Run = function(player: Player?, args: { any }): string?
			local target = targetOf(player, args[1])
			local data = target and ProfileService:Get(target)
			if not target or not data then
				return "no loaded profile"
			end
			local session = sessions[target] :: Session
			return `{target.Name}: {summary(data)} | store {storeKind}, saves {session.Saves}`
		end,
	})
	dev:Register("profile.add", {
		Description = "Give Glowshards (testing).",
		Usage = "profile.add <amount> [userId]",
		Run = function(player: Player?, args: { any }): string?
			local amount = tonumber(args[1])
			local target = targetOf(player, args[2])
			if not amount or amount < 0 or amount % 1 ~= 0 or not target then
				return "usage: profile.add <whole amount> [userId]"
			end
			local ok = ProfileService:AddGlowshards(target, amount, "dev command")
			return if ok then `{target.Name} now has {(ProfileService:Get(target) :: Profile).Glowshards}` else "failed"
		end,
	})
	dev:Register("profile.save", {
		Description = "Save a profile now.",
		Run = function(player: Player?, args: { any }): string?
			local target = targetOf(player, args[1])
			if not target then
				return "no player"
			end
			return if ProfileService:SaveNow(target) then `saved {target.Name}` else "save failed (see logs)"
		end,
	})
	dev:Register("profile.raw", {
		Description = "Read a stored record straight from the store (read-only).",
		Usage = "profile.raw [userId]",
		Run = function(player: Player?, args: { any }): string?
			local target = targetOf(player, args[1])
			local userId = if type(args[1]) == "number" then args[1] else target and target.UserId
			if not userId then
				return "no player"
			end
			local ok, record = attempt("read", function(): any
				return store:GetAsync(keyFor(userId))
			end)
			if not ok then
				return `read failed: {tostring(record)}`
			end
			if record == nil then
				return "no record"
			end
			local lock = record.Lock
			local lockText = if type(lock) == "table"
				then `{if lock.Session == SESSION_ID then "this server" else tostring(lock.Session)}, {os.time() - (lock.At or 0)} s ago`
				else "none"
			local data = record.Data
			local dataText = if type(data) == "table" then summary(data) else "no data yet"
			local meta = record.Meta or {}
			return `lock: {lockText} | saves {tostring(meta.Saves)} | {dataText}`
		end,
	})
	dev:Register("profile.locktest", {
		Description = "Run the lock rules against a scratch key (Studio only).",
		Run = function(): string?
			if not IS_STUDIO then
				return "Studio only"
			end
			return lockTest()
		end,
	})
end

-- Lifecycle --------------------------------------------------------------------------------

function ProfileService:Init(registry)
	sessionService = registry.SessionService
	sessionService:AddGate(GATE)
	profiles = registry.ReplicationService:Collection("Profiles", {
		Visible = function(player: Player, key: string): boolean
			return key == tostring(player.UserId)
		end,
	})
	registerCommands(registry.DevService)
end

function ProfileService:Start()
	local ok, result = pcall(function(): any
		local dataStore = DataStoreService:GetDataStore(STORE_NAME)
		dataStore:GetAsync("Probe")
		return dataStore
	end)
	if ok then
		store, storeKind, usingDataStore = result, `DataStore {STORE_NAME}`, true
	elseif IS_STUDIO then
		store, storeKind = memoryStore(), "memory (Studio has no DataStore access)"
		log:Warn("DataStores unavailable in this Studio session (%s): profiles live in memory only", tostring(result))
	else
		store, storeKind, usingDataStore = DataStoreService:GetDataStore(STORE_NAME), `DataStore {STORE_NAME}`, true
		log:Error("DataStore probe failed (%s); loads will retry", tostring(result))
	end
	log:Info("profiles in %s", storeKind)

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(leave)

	game:BindToClose(function()
		shuttingDown = true
		for player, session in sessions do
			sessions[player] = nil
			task.spawn(release, session)
		end
		local waited = 0
		while (releasesInFlight > 0 or next(loading) ~= nil) and waited < SHUTDOWN_WAIT_SECONDS do
			waited += task.wait(0.2)
		end
		log:Info("shutdown: profiles released (%d still in flight after %.1f s)", releasesInFlight, waited)
	end)

	task.spawn(function()
		while not shuttingDown do
			task.wait(5)
			local now = os.clock()
			local budget = if usingDataStore
				then DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
				else math.huge
			for _, session in sessions do
				if budget > 10 and not session.Saving and now >= session.NextSave then
					budget -= 1
					task.spawn(save, session, false)
				end
			end
		end
	end)
end

return ProfileService
