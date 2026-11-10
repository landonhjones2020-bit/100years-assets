--!strict
--[[
	PadService: the elevator pads that start runs (bible Section 21). Lobby only; Prompt 21. The
	rules are Shared.Rules.Lobby, the pads Config.Pads, the numbers Tuning.Lobby.

	A pad in the world is a Model under Workspace with a `PadId` attribute naming a Config.Pads
	entry and a `Floor` part: a player whose root is over that part (and within 12 studs above it)
	is riding the pad.

	* Public pads have a fixed difficulty. The countdown (PadCountdownSeconds) starts with the first
	  rider; the pad leaves when it is full (PartyMax) or the time is up.
	* Private pads: the first rider leads. Their Roblox friends may step on, and anyone they invite
	  from the lobby (PadInvite); the leader picks the difficulty (PadDifficulty: the next one every
	  rider has unlocked) and starts when ready (PadStart). A leader who steps off hands on to the
	  next rider.
	* The solo pad takes one rider and leaves after SoloCountdownSeconds. The rider picks the
	  difficulty (the count starts over), and the count waits while they have the loadout open
	  (PadHold).
	* Nobody boards a pad whose difficulty they haven't unlocked (Rules.Lobby.MayBoard); a rider
	  refused is told why, a few seconds apart.
	* Leaving: each rider's loadout comes from ClassShopService (a free trial is marked used), then
	  Lib.RunLaunch reserves a Run server, writes the run's record and the rejoin records, and
	  teleports the party. A failed launch says why and the pad is free again after
	  LaunchRetrySeconds.

	What clients read: the Pads collection ([padId] = { Kind, Difficulty, Phase, LeavesAt, Leader,
	Riders = { { UserId, Name, Class, Trial } }, Invited = { user ids }, Hold }) and the Player's
	`Pad` attribute (the pad they ride).

	Dev: pads, pad.go <padId> (launch it now), pad.fill <padId> <n> (pretend riders, to see a pad
	fill; they aren't sent anywhere), pad.unlock <Hard|Nightmare|none> (your profile's unlocks).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Lobby = require(Shared.Rules.Lobby)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunLaunch = require(ServerScriptService.Lib.RunLaunch)

local log = Log.new("PadService")

local PadService = {
	Name = "PadService",
	Dependencies = { "SessionService", "ProfileService", "ClassShopService", "ReplicationService", "DevService" },
}

type Live = {
	Pad: Lobby.Pad,
	Model: Model,
	Floor: BasePart,
	Hold: boolean, -- the solo rider has the loadout open
	Pretend: number, -- dev: riders that aren't players
	RetryAt: number, -- when a pad that is leaving is free again (os.clock)
	Sent: boolean, -- its party is on the way: free as soon as the riders are gone
	PublishedAt: number,
	Friends: { [number]: string }, -- would-be riders asked about as the leader's friends: Asking, Friend, No
}

local session: any = nil
local profiles: any = nil
local shop: any = nil
local collection: any = nil

local pads: { [string]: Live } = {}
local order: { string } = {}
local riding: { [Player]: string } = {}
local toldAt: { [Player]: number } = {}

local TICK = 0.2
local HEIGHT = 12

local function now(): number
	return workspace:GetServerTimeNow()
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function statsOf(player: Player): { [string]: number }?
	local profile = profiles:Get(player)
	return if profile then profile.Stats else nil
end

local function playerOf(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

local function ridersOf(live: Live): { Player }
	local out = {}
	for _, userId in live.Pad.Riders do
		local player = playerOf(userId)
		if player and session:IsReady(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function publish(live: Live)
	local pad = live.Pad
	local riders = {}
	for _, player in ridersOf(live) do
		local class, trial = shop:Loadout(player)
		table.insert(riders, { UserId = player.UserId, Name = player.DisplayName, Class = class, Trial = trial })
	end
	for i = 1, live.Pretend do
		table.insert(riders, { UserId = -i, Name = `Rider {i}`, Class = "Survivor", Trial = false })
	end
	local invited = {}
	for userId in pad.Invited or {} do
		table.insert(invited, userId)
	end
	table.sort(invited)
	live.PublishedAt = os.clock()
	collection:Set(pad.Id, {
		Kind = pad.Kind,
		Difficulty = pad.Difficulty,
		Phase = pad.Phase,
		LeavesAt = pad.LeavesAt,
		Leader = pad.Riders[1],
		Riders = riders,
		Invited = invited,
		Hold = live.Hold,
	})
end

local function count(live: Live): number
	return #live.Pad.Riders + live.Pretend
end

local function reset(live: Live)
	local pad = live.Pad
	local spec = Config.Get("Pads", pad.Id)
	pad.Phase = "Idle"
	pad.LeavesAt = nil
	pad.Invited = if pad.Kind == "Private" then {} else nil
	pad.Difficulty = spec.Difficulty or "Normal"
	live.Hold = false
	live.Friends = {}
end

local function startCount(live: Live)
	live.Pad.Phase = "Counting"
	live.Pad.LeavesAt = now() + Lobby.CountdownSeconds(live.Pad.Kind)
end

local function launch(live: Live, why: string)
	local pad = live.Pad
	local party = ridersOf(live)
	if #party == 0 then
		reset(live)
		publish(live)
		return
	end
	pad.Phase = "Launching"
	pad.LeavesAt = nil
	live.RetryAt = math.huge
	live.Sent = false
	publish(live)
	local loadouts: RunLaunch.Loadouts = {}
	local trials: { Player } = {}
	for _, player in party do
		local class, trial = shop:Loadout(player)
		loadouts[player.UserId] = { Class = class, Trial = trial }
		if trial then
			table.insert(trials, player)
		end
	end
	log:Info("%s leaves (%s): %d riders, %s", pad.Id, why, #party, pad.Difficulty)
	task.spawn(function()
		local ok, failed = RunLaunch.Start(party, pad.Difficulty, loadouts)
		if ok then
			for _, player in trials do
				shop:UseTrial(player)
			end
			for _, player in party do
				alert(player, "Info", "GOING DOWN: HOLD ON")
			end
			-- the riders teleport away; the pad frees itself as they go (or after a while if they don't)
			live.Sent = true
			live.RetryAt = os.clock() + 30
		else
			for _, player in party do
				alert(player, "Warning", `THE PAD DIDN'T LEAVE · {failed or "TRY AGAIN"}`)
			end
			log:Warn("%s didn't leave: %s", pad.Id, tostring(failed))
			live.RetryAt = os.clock() + Config.Get("Tuning", "Lobby").LaunchRetrySeconds
		end
	end)
end

local function over(live: Live, position: Vector3): boolean
	local floor = live.Floor
	local at = floor.CFrame:PointToObjectSpace(position)
	return math.abs(at.X) <= floor.Size.X / 2 and math.abs(at.Z) <= floor.Size.Z / 2 and at.Y > 0 and at.Y < HEIGHT
end

local function padUnder(player: Player): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	for _, id in order do
		if over(pads[id], root.Position) then
			return id
		end
	end
	return nil
end

local function tell(player: Player, text: string)
	if os.clock() - (toldAt[player] or 0) > 4 then
		toldAt[player] = os.clock()
		alert(player, "Warning", text)
	end
end

local function leave(player: Player)
	local id = riding[player]
	if not id then
		return
	end
	riding[player] = nil
	player:SetAttribute("Pad", nil)
	local live = pads[id]
	local index = table.find(live.Pad.Riders, player.UserId)
	if index then
		table.remove(live.Pad.Riders, index)
	end
	if live.Pad.Phase ~= "Launching" then
		if count(live) == 0 then
			reset(live)
		elseif live.Pad.Kind == "Private" and index == 1 then
			live.Friends = {} -- the next leader's friends are asked about afresh
			local leader = playerOf(live.Pad.Riders[1])
			if leader then
				alert(leader, "Info", "YOU LEAD THIS PAD NOW")
			end
		end
	end
	publish(live)
end

-- A private pad admits its leader's Roblox friends: asked once per pair, off the tick. True
-- while the answer is still on its way (nobody is refused before it is known).
local function friendCheck(live: Live, player: Player): boolean
	local leaderId = live.Pad.Riders[1]
	if not leaderId then
		return false
	end
	local known = live.Friends[player.UserId]
	if known ~= nil then
		return known == "Asking"
	end
	live.Friends[player.UserId] = "Asking"
	local asked = live.Friends
	task.spawn(function()
		local ok, friends = pcall(function()
			return player:IsFriendsWith(leaderId)
		end)
		if live.Friends ~= asked or live.Pad.Riders[1] ~= leaderId then
			return -- the pad changed hands meanwhile
		end
		asked[player.UserId] = if ok and friends then "Friend" else "No"
		if ok and friends and live.Pad.Invited then
			live.Pad.Invited[player.UserId] = true
		end
	end)
	return true
end

local function board(player: Player, id: string)
	local live = pads[id]
	local pad = live.Pad
	if pad.Kind == "Private" and #pad.Riders > 0 and not (pad.Invited and pad.Invited[player.UserId])
		and not table.find(pad.Riders, player.UserId) and friendCheck(live, player) then
		return -- a friend of the leader's? The answer comes within a tick or two
	end
	local ok, why = Lobby.MayBoard(pad, player.UserId, statsOf(player))
	if ok and count(live) >= Lobby.Capacity(pad.Kind) then
		ok, why = false, "THIS PAD IS FULL"
	end
	if not ok then
		tell(player, why or "YOU CAN'T BOARD THIS PAD")
		return
	end
	table.insert(pad.Riders, player.UserId)
	riding[player] = id
	player:SetAttribute("Pad", id)
	if pad.Kind == "Private" then
		if #pad.Riders == 1 then
			pad.Phase = "Waiting"
		end
	elseif pad.Phase == "Idle" then
		startCount(live)
	end
	publish(live)
end

local function step()
	for _, player in session:ReadyPlayers() do
		local under = padUnder(player)
		local current = riding[player]
		if current and current ~= under then
			leave(player)
			current = nil
		end
		if under and not current then
			board(player, under)
		end
	end
	local t = now()
	for _, id in order do
		local live = pads[id]
		local pad = live.Pad
		if pad.Phase == "Counting" then
			if count(live) >= Lobby.Capacity(pad.Kind) and pad.Kind == "Public" then
				launch(live, "full")
			elseif pad.LeavesAt and t >= pad.LeavesAt and not live.Hold then
				launch(live, "time")
			end
		elseif pad.Phase == "Launching" and (os.clock() >= live.RetryAt or (live.Sent and count(live) == 0)) then
			-- the launch failed, or its riders are gone: the pad is free again
			if count(live) == 0 then
				reset(live)
			elseif pad.Kind == "Private" then
				pad.Phase = "Waiting"
			else
				startCount(live)
			end
			publish(live)
		elseif #pad.Riders > 0 and os.clock() - live.PublishedAt > 1 then
			publish(live) -- a rider may have changed their class
		end
	end
end

local function leaderPad(player: Player, kinds: { string }): Live?
	local id = riding[player]
	local live = if id then pads[id] else nil
	if not live or not table.find(kinds, live.Pad.Kind) or live.Pad.Riders[1] ~= player.UserId then
		return nil
	end
	return if live.Pad.Phase == "Launching" then nil else live
end

local function onDifficulty(player: Player)
	local live = leaderPad(player, { "Private", "Solo" })
	if not live then
		return
	end
	local statsList = {}
	for _, rider in ridersOf(live) do
		table.insert(statsList, statsOf(rider) or {})
	end
	local nextOne = Lobby.NextDifficulty(live.Pad.Difficulty, statsList)
	if nextOne == live.Pad.Difficulty then
		alert(player, "Info", if #statsList > 1 then "NO OTHER DIFFICULTY EVERY RIDER HAS UNLOCKED" else "HARD UNLOCKS AFTER A VICTORY")
		return
	end
	live.Pad.Difficulty = nextOne
	if live.Pad.Kind == "Solo" then
		startCount(live)
	end
	publish(live)
end

local function onStart(player: Player)
	local live = leaderPad(player, { "Private" })
	if not live then
		return
	end
	for _, rider in ridersOf(live) do
		if not Lobby.Unlocked(statsOf(rider), live.Pad.Difficulty) then
			alert(player, "Warning", string.upper(`{rider.DisplayName} HASN'T UNLOCKED {live.Pad.Difficulty}`))
			return
		end
	end
	launch(live, "its leader's word")
end

local function onInvite(player: Player, userId: number, invited: boolean)
	local live = leaderPad(player, { "Private" })
	local guest = playerOf(userId)
	if not live or not guest or guest == player or not live.Pad.Invited then
		return
	end
	local list = live.Pad.Invited
	if invited then
		local n = 0
		for _ in list do
			n += 1
		end
		if n >= Config.Get("Tuning", "Lobby").PrivateInvites then
			alert(player, "Warning", "THAT'S EVERY INVITATION THIS PAD HAS")
			return
		end
		if not list[userId] then
			list[userId] = true
			alert(guest, "Info", string.upper(`{player.DisplayName} INVITED YOU TO THEIR PRIVATE PAD`))
		end
	else
		list[userId] = nil
		if riding[guest] == live.Pad.Id then
			leave(guest)
			alert(guest, "Info", "YOUR INVITATION WAS TAKEN BACK")
		end
	end
	publish(live)
end

local function onHold(player: Player, hold: boolean)
	-- kept whatever the pad is doing (a hold sent while a launch is retrying still counts after it)
	local id = riding[player]
	local live = if id then pads[id] else nil
	if live and live.Pad.Kind == "Solo" and live.Pad.Riders[1] == player.UserId and live.Hold ~= hold then
		live.Hold = hold
		if not hold and live.Pad.Phase == "Counting" then
			startCount(live)
		end
		publish(live)
	end
end

local function describe(): string
	local lines = {}
	for _, id in order do
		local live = pads[id]
		local pad = live.Pad
		local names = {}
		for _, player in ridersOf(live) do
			table.insert(names, player.Name)
		end
		table.insert(lines, string.format("%s: %s %s, %s%s, riders %d%s [%s]", id, pad.Kind, pad.Difficulty, pad.Phase,
			if pad.LeavesAt then string.format(" (%.1f s)", pad.LeavesAt - now()) else "", count(live),
			if live.Pretend > 0 then ` ({live.Pretend} pretend)` else "", table.concat(names, ", ")))
	end
	return if #lines > 0 then table.concat(lines, "\n") else "no pads in this place (models with a PadId attribute and a Floor part)"
end

local function registerCommands(dev: any)
	dev:Register("pads", { Description = "Every pad: kind, difficulty, phase and riders.", Run = function(): string?
		return describe()
	end })
	dev:Register("pad.go", {
		Description = "Make a pad leave now.",
		Usage = "pad.go <padId>",
		Run = function(_player: Player?, args): string?
			local live = pads[tostring(args[1] or "")]
			if not live then
				return "usage: pad.go <padId> (see pads)"
			end
			launch(live, "DevTools")
			return describe()
		end,
	})
	dev:Register("pad.fill", {
		Description = "Put n pretend riders on a pad (they count towards full; they aren't sent anywhere).",
		Usage = "pad.fill <padId> <n>",
		Run = function(_player: Player?, args): string?
			local live = pads[tostring(args[1] or "")]
			if not live then
				return "usage: pad.fill <padId> <n>"
			end
			live.Pretend = math.clamp(math.floor(tonumber(args[2]) or 0), 0, Lobby.Capacity(live.Pad.Kind))
			if live.Pretend > 0 and live.Pad.Phase == "Idle" and live.Pad.Kind == "Public" then
				startCount(live)
			elseif count(live) == 0 then
				reset(live)
			end
			publish(live)
			return describe()
		end,
	})
	dev:Register("pad.unlock", {
		Description = "Set your profile's difficulty unlocks (Hard: one win; Nightmare: one Hard win too; none: neither).",
		Usage = "pad.unlock <Hard|Nightmare|none>",
		Run = function(player: Player?, args): string?
			local who = player or Players:GetPlayers()[1]
			local wanted = string.lower(tostring(args[1] or ""))
			if not who or (wanted ~= "hard" and wanted ~= "nightmare" and wanted ~= "none") then
				return "usage: pad.unlock <Hard|Nightmare|none>"
			end
			profiles:Update(who, function(data: any)
				data.Stats.Wins = if wanted == "none" then 0 else math.max(1, data.Stats.Wins or 0)
				data.Stats.HardWins = if wanted == "nightmare" then math.max(1, data.Stats.HardWins or 0) else 0
			end)
			return `{who.Name}: {table.concat(Lobby.Difficulties(statsOf(who)), ", ")}`
		end,
	})
end

local function adopt(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("PadId")
	local floor = model:FindFirstChild("Floor")
	if type(id) ~= "string" or pads[id] or not (floor and floor:IsA("BasePart")) then
		return
	end
	local spec = Config.Find("Pads", id)
	if not spec then
		log:Warn("%s names pad %s, which isn't in Config.Pads", model:GetFullName(), id)
		return
	end
	local live: Live = {
		Pad = { Id = id, Kind = spec.Kind, Difficulty = spec.Difficulty or "Normal", Riders = {}, Phase = "Idle" },
		Model = model,
		Floor = floor,
		Hold = false,
		Pretend = 0,
		RetryAt = 0,
		Sent = false,
		PublishedAt = 0,
		Friends = {},
	}
	reset(live)
	pads[id] = live
	table.insert(order, id)
	publish(live)
end

function PadService:Init(registry)
	session = registry.SessionService
	profiles = registry.ProfileService
	shop = registry.ClassShopService
	collection = registry.ReplicationService:Collection("Pads")
	Remotes.OnServer("PadDifficulty", onDifficulty)
	Remotes.OnServer("PadStart", onStart)
	Remotes.OnServer("PadInvite", onInvite)
	Remotes.OnServer("PadHold", onHold)
	registerCommands(registry.DevService)
end

function PadService:Start()
	for _, item in workspace:GetDescendants() do
		if item:GetAttribute("PadId") ~= nil then
			adopt(item)
		end
	end
	table.sort(order, function(a, b)
		local ids = Config.Ids("Pads")
		return (table.find(ids, a) or 0) < (table.find(ids, b) or 0)
	end)
	session.PlayerLeaving:Connect(function(player: Player)
		leave(player)
		toldAt[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(step)
			if not ok then
				log:Warn("pad step: %s", tostring(err))
			end
		end
	end)
	log:Info("pads ready: %d (%s)", #order, table.concat(order, ", "))
end

return PadService
