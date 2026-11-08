--!strict
--[[
	Delta: the wire format and the pure logic of the delta channel (bible Section 23:
	"collections (rooms, residents, votes) go through one delta channel").

	The server keeps named collections of keyed values (ReplicationService); clients keep a
	mirror (ReplicaController). Changes travel as ops, batched into one Delta event per
	flush:

		{ Delta.SET,    "Rooms", "R12", { Kind = "Kitchen", Level = 1 } }
		{ Delta.PATCH,  "Rooms", "R12", { Level = 2, Damaged = Delta.NONE } }  -- NONE clears a field
		{ Delta.REMOVE, "Rooms", "R12" }
		{ Delta.CLEAR,  "Rooms" }

	Values must survive a RemoteEvent: nil, booleans, finite numbers, strings, Vector3,
	CFrame, Color3, and tables that are either a list 1..n or a dictionary with string keys
	(Roblox drops data from mixed or sparse tables). IsRemoteSafe checks this.
]]

local TableUtil = require(script.Parent.TableUtil)

local Delta = {}

Delta.SET = 1
Delta.PATCH = 2
Delta.REMOVE = 3
Delta.CLEAR = 4

-- In a patch, this value removes the field.
Delta.NONE = "\0none"

export type Op = { any }
export type Store = { [string]: { [string]: any } }
export type Change = {
	Collection: string,
	Key: string?, -- nil when a whole collection was cleared
	Value: any, -- the new value (nil when removed)
	Old: any, -- the previous value
}

local SAFE_TYPES = {
	boolean = true,
	string = true,
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	EnumItem = true,
}

local function remoteSafe(value: any, depth: number, path: string): (boolean, string?)
	local kind = typeof(value)
	if kind == "nil" or SAFE_TYPES[kind] then
		return true
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return false, `{path}: number isn't finite`
		end
		return true
	elseif kind ~= "table" then
		return false, `{path}: a {kind} can't be replicated`
	end
	if depth > 16 then
		return false, `{path}: nested too deep`
	end
	local count = 0
	local stringKeys = 0
	for key, item in value do
		count += 1
		if type(key) == "string" then
			stringKeys += 1
		elseif type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false, `{path}: key {tostring(key)} must be a string or a list index`
		end
		local ok, why = remoteSafe(item, depth + 1, `{path}.{tostring(key)}`)
		if not ok then
			return false, why
		end
	end
	if stringKeys > 0 and stringKeys < count then
		return false, `{path}: mixes list items and named fields`
	end
	if stringKeys == 0 and count ~= #value then
		return false, `{path}: list has holes`
	end
	return true
end

function Delta.IsRemoteSafe(value: any): (boolean, string?)
	return remoteSafe(value, 0, "value")
end

--[[
	The fields of `new` that differ from `old`, with NONE for fields `old` had and `new`
	doesn't. Nil when nothing changed. Both must be string-keyed tables.
]]
function Delta.Diff(old: { [string]: any }, new: { [string]: any }): { [string]: any }?
	local patch: { [string]: any } = {}
	local changed = false
	for field, value in new do
		if not TableUtil.DeepEqual(old[field], value) then
			patch[field] = value
			changed = true
		end
	end
	for field in old do
		if new[field] == nil then
			patch[field] = Delta.NONE
			changed = true
		end
	end
	return if changed then patch else nil
end

-- `value` with `patch` applied, as a new table (the old one is left untouched).
function Delta.Merge(value: { [string]: any }, patch: { [string]: any }): { [string]: any }
	local merged = table.clone(value)
	for field, item in patch do
		if item == Delta.NONE then
			merged[field] = nil
		else
			merged[field] = item
		end
	end
	return merged
end

--[[
	Applies ops to a mirror and returns what changed. Applied values are frozen, so readers
	can hold on to them; a patch makes a new table instead of editing the old one.
]]
function Delta.Apply(store: Store, ops: { Op }): { Change }
	local changes: { Change } = {}
	for _, op in ops do
		local code, collectionName, key, value = op[1], op[2], op[3], op[4]
		if type(collectionName) ~= "string" then
			continue
		end
		local collection = store[collectionName]
		if not collection then
			collection = {}
			store[collectionName] = collection
		end
		if code == Delta.SET and type(key) == "string" then
			local old = collection[key]
			local new = TableUtil.DeepFreeze(value)
			collection[key] = new
			table.insert(changes, { Collection = collectionName, Key = key, Value = new, Old = old })
		elseif code == Delta.PATCH and type(key) == "string" and type(value) == "table" then
			local old = collection[key]
			local base = if type(old) == "table" then old else {}
			local new = TableUtil.DeepFreeze(Delta.Merge(base, value))
			collection[key] = new
			table.insert(changes, { Collection = collectionName, Key = key, Value = new, Old = old })
		elseif code == Delta.REMOVE and type(key) == "string" then
			local old = collection[key]
			if old ~= nil then
				collection[key] = nil
				table.insert(changes, { Collection = collectionName, Key = key, Value = nil, Old = old })
			end
		elseif code == Delta.CLEAR then
			if next(collection) ~= nil then
				store[collectionName] = {}
				table.insert(changes, { Collection = collectionName, Key = nil, Value = nil, Old = collection })
			end
		end
	end
	return changes
end

return table.freeze(Delta)
