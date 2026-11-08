--!strict
--[[
	TableUtil: copies, freezing and comparison for plain data (Config entries, replicated
	values). Data is tree-shaped; a cycle or nesting deeper than MAX_DEPTH is an error.
]]

local MAX_DEPTH = 32

local TableUtil = {}

local function deepCopy(value: any, depth: number): any
	if type(value) ~= "table" then
		return value
	end
	if depth > MAX_DEPTH then
		error("TableUtil.DeepCopy: nesting too deep (a cycle?)", depth + 2)
	end
	local copy = {}
	for key, item in value do
		copy[key] = deepCopy(item, depth + 1)
	end
	return copy
end

-- A copy with no shared tables. The copy is never frozen.
function TableUtil.DeepCopy<T>(value: T): T
	return deepCopy(value, 0)
end

local function deepFreeze(value: any, depth: number)
	if type(value) ~= "table" then
		return
	end
	if depth > MAX_DEPTH then
		error("TableUtil.DeepFreeze: nesting too deep (a cycle?)", depth + 2)
	end
	for _, item in value do
		deepFreeze(item, depth + 1)
	end
	if not table.isfrozen(value) then
		table.freeze(value)
	end
end

-- Freezes the table and every table inside it; returns it for chaining.
function TableUtil.DeepFreeze<T>(value: T): T
	deepFreeze(value, 0)
	return value
end

local function deepEqual(a: any, b: any, depth: number): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		-- NaN is never equal to itself; treat two NaNs as equal data
		return type(a) == "number" and type(b) == "number" and a ~= a and b ~= b
	end
	if depth > MAX_DEPTH then
		error("TableUtil.DeepEqual: nesting too deep (a cycle?)", depth + 2)
	end
	for key, item in a do
		if not deepEqual(item, b[key], depth + 1) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TableUtil.DeepEqual(a: any, b: any): boolean
	return deepEqual(a, b, 0)
end

function TableUtil.Count(t: { [any]: any }): number
	local count = 0
	for _ in t do
		count += 1
	end
	return count
end

-- Keys in a stable order: numbers ascending, then strings ascending, then the rest by tostring.
function TableUtil.SortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any): boolean
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			if ta == "number" then
				return true
			elseif tb == "number" then
				return false
			end
			return ta < tb
		end
		if ta == "number" or ta == "string" then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

return table.freeze(TableUtil)
