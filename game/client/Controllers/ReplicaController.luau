--!strict
--[[
	ReplicaController: the client end of the delta channel. It mirrors the server's
	collections (ReplicationService) and tells controllers what changed.

		local Rooms = registry.ReplicaController
		Rooms:Changed("Rooms"):Connect(function(key, value, old) ... end)  -- value nil = removed
		local room = Rooms:Get("Rooms", "R12")                              -- frozen; never edit
		Rooms:Ready():Wait()                                                -- first snapshot in

	A snapshot replaces the whole mirror: keys that disappeared fire a removal.
	A collection cleared on the server fires one change with key nil.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Delta = require(Shared.Utilities.Delta)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("ReplicaController")

export type ChangedSignal = Signal.Signal<string?, any, any>

local ReplicaController = {
	Name = "ReplicaController",
	Dependencies = {},
}

local store: Delta.Store = {}
local changedSignals: { [string]: ChangedSignal } = {}
local readySignal = Signal.new() :: Signal.Signal<()>
local isReady = false
local counters = { Events = 0, Ops = 0, Snapshots = 0 }

local function onDelta(ops: any, snapshot: any)
	if type(ops) ~= "table" then
		return
	end
	counters.Events += 1
	counters.Ops += #ops
	local changes: { Delta.Change }
	if snapshot == true then
		counters.Snapshots += 1
		local previous = store
		store = {}
		changes = Delta.Apply(store, ops)
		for _, change in changes do
			local before = previous[change.Collection]
			change.Old = if before and change.Key then before[change.Key] else nil
		end
		for collectionName, values in previous do
			local now = store[collectionName]
			for key, value in values do
				if not now or now[key] == nil then
					table.insert(changes, { Collection = collectionName, Key = key, Value = nil, Old = value })
				end
			end
		end
	else
		changes = Delta.Apply(store, ops)
	end
	for _, change in changes do
		local signal = changedSignals[change.Collection]
		if signal then
			signal:Fire(change.Key, change.Value, change.Old)
		end
	end
	if snapshot == true and not isReady then
		isReady = true
		log:Debug("snapshot: %d values", #ops)
		readySignal:Fire()
	end
end

function ReplicaController:Init(_registry)
	Remotes.OnClient("Delta", onDelta)
end

function ReplicaController:Get(collection: string, key: string): any
	local values = store[collection]
	return if values then values[key] else nil
end

-- A shallow copy of a collection (the values are frozen).
function ReplicaController:All(collection: string): { [string]: any }
	local values = store[collection]
	return if values then table.clone(values) else {}
end

function ReplicaController:Changed(collection: string): ChangedSignal
	local signal = changedSignals[collection]
	if not signal then
		signal = Signal.new() :: ChangedSignal
		changedSignals[collection] = signal
	end
	return signal :: ChangedSignal
end

function ReplicaController:IsReady(): boolean
	return isReady
end

-- Fires once, after the first snapshot. Check IsReady first: it won't fire again.
function ReplicaController:Ready(): Signal.Signal<()>
	return readySignal
end

function ReplicaController:Stats(): { Events: number, Ops: number, Snapshots: number }
	return table.clone(counters)
end

return ReplicaController
