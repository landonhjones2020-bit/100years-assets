--!strict
--[[
	ReplicationService: the server end of the delta channel (bible Section 23: collections
	such as rooms, residents and votes go through one delta channel; small values replicate
	as attributes instead).

	A system keeps its replicated state in collections:

		local Rooms = ReplicationService:Collection("Rooms")
		Rooms:Set("R12", { Kind = "Kitchen", Level = 1, Cell = { 2, 3 } })
		Rooms:Patch("R12", { Level = 2 })          -- only Level travels
		Rooms:Remove("R12")

	Changes are batched and flushed Constants.DELTA_HZ times a second to every ready player
	(SessionService); a player who becomes ready first gets a snapshot. Values must be
	remote-safe (Utilities.Delta.IsRemoteSafe); they are copied and frozen when set, so later
	edits to the caller's table can't leak into replicated state.

	A collection can be per-player with `Visible = function(player, key) -> boolean`
	(an inventory only its owner sees). Clients read collections through ReplicaController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Constants = require(Shared.Constants)
local Delta = require(Shared.Utilities.Delta)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local TableUtil = require(Shared.Utilities.TableUtil)

local log = Log.new("ReplicationService")
local IS_STUDIO = RunService:IsStudio()

export type CollectionOptions = {
	Visible: ((player: Player, key: string) -> boolean)?,
}

export type Collection = {
	Name: string,
	Set: (self: Collection, key: string, value: any) -> (),
	Patch: (self: Collection, key: string, fields: { [string]: any }) -> (),
	Remove: (self: Collection, key: string) -> (),
	Clear: (self: Collection) -> (),
	Get: (self: Collection, key: string) -> any,
	All: (self: Collection) -> { [string]: any },
	Count: (self: Collection) -> number,
}

type State = {
	Name: string,
	Values: { [string]: any },
	Visible: ((player: Player, key: string) -> boolean)?,
}

local ReplicationService = {
	Name = "ReplicationService",
	Dependencies = { "SessionService", "DevService" },
}

local states: { [string]: State } = {}
local collections: { [string]: Collection } = {}
local pending: { Delta.Op } = {}
local counters = { Flushes = 0, OpsQueued = 0, EventsSent = 0, Snapshots = 0 }
local sessions: any = nil

local function queue(op: Delta.Op)
	table.insert(pending, op)
	counters.OpsQueued += 1
end

local function assertKey(state: State, key: any)
	if type(key) ~= "string" or key == "" then
		error(`{state.Name}: keys must be non-empty strings, got {tostring(key)}`, 3)
	end
end

local function assertSafe(state: State, key: string, value: any)
	local ok, why = Delta.IsRemoteSafe(value)
	if not ok then
		local message = `{state.Name}.{key} can't replicate: {why}`
		if IS_STUDIO then
			error(message, 3)
		end
		log:Error("%s", message)
	end
end

local CollectionClass = {}
CollectionClass.__index = CollectionClass

function CollectionClass.Set(self: any, key: string, value: any)
	local state: State = self._state
	assertKey(state, key)
	if value == nil then
		CollectionClass.Remove(self, key)
		return
	end
	assertSafe(state, key, value)
	if TableUtil.DeepEqual(state.Values[key], value) then
		return
	end
	local frozen = TableUtil.DeepFreeze(TableUtil.DeepCopy(value))
	state.Values[key] = frozen
	queue({ Delta.SET, state.Name, key, frozen })
end

function CollectionClass.Patch(self: any, key: string, fields: { [string]: any })
	local state: State = self._state
	assertKey(state, key)
	local old = state.Values[key]
	if type(old) ~= "table" then
		error(`{state.Name}.{key}: Patch needs an existing table value (use Set first)`, 2)
	end
	assertSafe(state, key, fields)
	local merged = Delta.Merge(old, TableUtil.DeepCopy(fields))
	local diff = Delta.Diff(old, merged)
	if not diff then
		return
	end
	state.Values[key] = TableUtil.DeepFreeze(merged)
	queue({ Delta.PATCH, state.Name, key, TableUtil.DeepFreeze(diff) })
end

function CollectionClass.Remove(self: any, key: string)
	local state: State = self._state
	assertKey(state, key)
	if state.Values[key] == nil then
		return
	end
	state.Values[key] = nil
	queue({ Delta.REMOVE, state.Name, key })
end

function CollectionClass.Clear(self: any)
	local state: State = self._state
	if next(state.Values) == nil then
		return
	end
	table.clear(state.Values)
	queue({ Delta.CLEAR, state.Name })
end

function CollectionClass.Get(self: any, key: string): any
	return self._state.Values[key]
end

-- A shallow copy of the whole collection (the values themselves are frozen).
function CollectionClass.All(self: any): { [string]: any }
	return table.clone(self._state.Values)
end

function CollectionClass.Count(self: any): number
	return TableUtil.Count(self._state.Values)
end

-- The named collection, created on first use. Options only apply when it's created.
function ReplicationService:Collection(name: string, options: CollectionOptions?): Collection
	assert(type(name) == "string" and string.find(name, "^[%a_][%w_]*$"), "Collection names are identifiers")
	local existing = collections[name]
	if existing then
		if options and options.Visible ~= states[name].Visible then
			error(`Collection {name} already exists with other options`, 2)
		end
		return existing
	end
	local state: State = { Name = name, Values = {}, Visible = options and options.Visible }
	states[name] = state
	local collection: Collection = setmetatable({ Name = name, _state = state }, CollectionClass) :: any
	collections[name] = collection
	return collection
end

local function visibleOps(player: Player, ops: { Delta.Op }): { Delta.Op }
	local list = {}
	for _, op in ops do
		local state = states[op[2]]
		local visible = state and state.Visible
		if visible == nil or op[1] == Delta.CLEAR then
			table.insert(list, op)
		else
			local ok, result = pcall(visible, player, op[3])
			if ok and result then
				table.insert(list, op)
			elseif not ok then
				log:Error("%s.Visible failed: %s", op[2], tostring(result))
			end
		end
	end
	return list
end

local function snapshotFor(player: Player): { Delta.Op }
	local ops: { Delta.Op } = {}
	for _, name in TableUtil.SortedKeys(states) do
		local state = states[name]
		for key, value in state.Values do
			table.insert(ops, { Delta.SET, name, key, value })
		end
	end
	return visibleOps(player, ops)
end

local function flush()
	if #pending == 0 then
		return
	end
	local ops = pending
	pending = {}
	counters.Flushes += 1
	local players = sessions:ReadyPlayers()
	if #players == 0 then
		return
	end
	local anyPerPlayer = false
	for _, op in ops do
		local state = states[op[2]]
		if state and state.Visible then
			anyPerPlayer = true
			break
		end
	end
	if not anyPerPlayer then
		Remotes.FireClients("Delta", players, ops, false)
		counters.EventsSent += #players
		return
	end
	for _, player in players do
		local list = visibleOps(player, ops)
		if #list > 0 then
			Remotes.FireClient("Delta", player, list, false)
			counters.EventsSent += 1
		end
	end
end

function ReplicationService:Init(registry)
	sessions = registry.SessionService
	local dev = registry.DevService

	dev:Register("rep", {
		Description = "Delta channel: collections, sizes and traffic.",
		Run = function(_player: Player?, _args: { any }): string?
			local lines = {
				("flushes %d, ops queued %d, events sent %d, snapshots %d, pending %d"):format(
					counters.Flushes,
					counters.OpsQueued,
					counters.EventsSent,
					counters.Snapshots,
					#pending
				),
			}
			for _, name in TableUtil.SortedKeys(states) do
				local state = states[name]
				local scope = if state.Visible then " (per player)" else ""
				table.insert(lines, `  {name}: {TableUtil.Count(state.Values)} values{scope}`)
			end
			return table.concat(lines, "\n")
		end,
	})

	dev:Register("rep.selftest", {
		Description = "Runs set, patch and remove on the _SelfTest collection; compare with `/dev replica _SelfTest` on a client.",
		Run = function(_player: Player?, _args: { any }): string?
			local test = ReplicationService:Collection("_SelfTest")
			test:Clear()
			test:Set("Alpha", { Count = 1, Label = "first", Tags = { "a", "b" } })
			test:Patch("Alpha", { Count = 2, Label = Delta.NONE })
			test:Set("Beta", { Count = 10 })
			test:Remove("Beta")
			test:Set("Gamma", { Where = Vector3.new(1, 2, 3), Done = true })
			test:Set("Stamp", { At = workspace:GetServerTimeNow() })
			return "queued: Alpha {Count=2, Tags={a,b}}, Gamma {Where=1,2,3, Done=true}, Stamp; Beta removed"
		end,
	})
end

function ReplicationService:Start()
	sessions.PlayerReady:Connect(function(player: Player)
		local ops = snapshotFor(player)
		Remotes.FireClient("Delta", player, ops, true)
		counters.Snapshots += 1
		log:Debug("snapshot to %s: %d values", player.Name, #ops)
	end)
	local interval = 1 / Constants.DELTA_HZ
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			flush()
		end
	end)
end

-- Server-side view of a collection's values (for DevTools and tests).
function ReplicationService:Peek(name: string): { [string]: any }?
	local state = states[name]
	return if state then table.clone(state.Values) else nil
end

return ReplicationService
