--!strict
--[[
	Check: runtime validators for anything that crosses a trust boundary (remote arguments)
	or comes from data (Config entries).

	A checker is a function `(value) -> (ok, why?)`:

		local shape = Check.shape({
			Name = Check.string(40),
			Cost = Check.number({ min = 0, integer = true }),
			Tags = Check.optional(Check.array(Check.string(20), 8)),
		})
		local ok, why = shape(value)   -- why = "Cost: expected an integer, got 2.5"

	Numbers are always finite (NaN and infinity fail), strings are valid UTF-8, arrays have
	no holes, and shapes reject unknown fields unless `{ open = true }`.
]]

export type Checker = (value: any) -> (boolean, string?)

local Check = {}

-- The Config aggregator collects references while it validates (see Check.ref).
local refSink: ((typeName: string, id: string) -> ())? = nil

local function describe(value: any): string
	local kind = typeof(value)
	if kind == "string" then
		return if #value > 24 then `a string of {#value} bytes` else `"{value}"`
	elseif kind == "number" then
		return tostring(value)
	elseif kind == "nil" then
		return "nothing"
	end
	return `a {kind}`
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

export type NumberOptions = { min: number?, max: number?, integer: boolean? }

function Check.number(options: NumberOptions?): Checker
	local min = options and options.min
	local max = options and options.max
	local integer = options and options.integer
	return function(value: any): (boolean, string?)
		if not isFinite(value) then
			return false, `expected a number, got {describe(value)}`
		end
		if integer and value % 1 ~= 0 then
			return false, `expected an integer, got {value}`
		end
		if min and value < min then
			return false, `{value} is below the minimum {min}`
		end
		if max and value > max then
			return false, `{value} is above the maximum {max}`
		end
		return true
	end
end

function Check.integer(min: number?, max: number?): Checker
	return Check.number({ min = min, max = max, integer = true })
end

export type StringOptions = { pattern: string?, min: number? }

function Check.string(maxLength: number, options: StringOptions?): Checker
	local pattern = options and options.pattern
	local minLength = options and options.min or 0
	return function(value: any): (boolean, string?)
		if type(value) ~= "string" then
			return false, `expected a string, got {describe(value)}`
		end
		if #value > maxLength then
			return false, `string longer than {maxLength} bytes`
		end
		if #value < minLength then
			return false, `string shorter than {minLength} bytes`
		end
		if utf8.len(value) == nil then
			return false, "string is not valid UTF-8"
		end
		if pattern and not string.find(value, pattern) then
			return false, `"{value}" doesn't match {pattern}`
		end
		return true
	end
end

function Check.boolean(): Checker
	return function(value: any): (boolean, string?)
		if type(value) ~= "boolean" then
			return false, `expected true or false, got {describe(value)}`
		end
		return true
	end
end

-- One of the given values (strings, numbers or booleans).
function Check.literal(...: any): Checker
	local allowed = {}
	local names = {}
	for _, item in { ... } do
		allowed[item] = true
		table.insert(names, tostring(item))
	end
	local list = table.concat(names, ", ")
	return function(value: any): (boolean, string?)
		if value == nil or not allowed[value] then
			return false, `expected one of {list}, got {describe(value)}`
		end
		return true
	end
end

function Check.enum(values: { string }): Checker
	return Check.literal(table.unpack(values))
end

function Check.optional(check: Checker): Checker
	return function(value: any): (boolean, string?)
		if value == nil then
			return true
		end
		return check(value)
	end
end

-- Passes if any of the checkers passes.
function Check.union(...: Checker): Checker
	local checks = { ... }
	return function(value: any): (boolean, string?)
		local reasons = {}
		for _, check in checks do
			local ok, why = check(value)
			if ok then
				return true
			end
			table.insert(reasons, why or "?")
		end
		return false, table.concat(reasons, "; or ")
	end
end

-- A sequence 1..n with no holes and no other keys.
function Check.array(check: Checker, maxLength: number): Checker
	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return false, `expected a list, got {describe(value)}`
		end
		local count = 0
		for key in value do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
				return false, "list has a key that isn't an index"
			end
			count += 1
		end
		if count ~= #value then
			return false, "list has holes"
		end
		if count > maxLength then
			return false, `list longer than {maxLength}`
		end
		for index, item in ipairs(value) do
			local ok, why = check(item)
			if not ok then
				return false, `[{index}]: {why}`
			end
		end
		return true
	end
end

-- A dictionary whose keys and values pass the checkers.
function Check.map(keyCheck: Checker, valueCheck: Checker, maxCount: number): Checker
	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return false, `expected a table, got {describe(value)}`
		end
		local count = 0
		for key, item in value do
			count += 1
			if count > maxCount then
				return false, `more than {maxCount} entries`
			end
			local ok, why = keyCheck(key)
			if not ok then
				return false, `key {describe(key)}: {why}`
			end
			ok, why = valueCheck(item)
			if not ok then
				return false, `{tostring(key)}: {why}`
			end
		end
		return true
	end
end

export type ShapeOptions = { open: boolean? }

-- A table with these fields. Unknown fields fail unless `open`.
function Check.shape(fields: { [string]: Checker }, options: ShapeOptions?): Checker
	local open = options and options.open
	local names = {}
	for name in fields do
		table.insert(names, name)
	end
	table.sort(names)
	return function(value: any): (boolean, string?)
		if type(value) ~= "table" then
			return false, `expected a table, got {describe(value)}`
		end
		for _, name in names do
			local ok, why = fields[name](value[name])
			if not ok then
				return false, `{name}: {why}`
			end
		end
		if not open then
			for key in value do
				if type(key) ~= "string" or fields[key] == nil then
					return false, `unknown field {describe(key)}`
				end
			end
		end
		return true
	end
end

function Check.vector3(maxMagnitude: number?): Checker
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Vector3" then
			return false, `expected a Vector3, got {describe(value)}`
		end
		if not (isFinite(value.X) and isFinite(value.Y) and isFinite(value.Z)) then
			return false, "Vector3 isn't finite"
		end
		if maxMagnitude and value.Magnitude > maxMagnitude then
			return false, `Vector3 longer than {maxMagnitude}`
		end
		return true
	end
end

function Check.cframe(): Checker
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "CFrame" then
			return false, `expected a CFrame, got {describe(value)}`
		end
		for _, component in { value:GetComponents() } do
			if not isFinite(component) then
				return false, "CFrame isn't finite"
			end
		end
		return true
	end
end

function Check.color3(): Checker
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Color3" then
			return false, `expected a Color3, got {describe(value)}`
		end
		return true
	end
end

-- An Instance, optionally of a class (IsA). Remote arguments can't be trusted to still
-- exist or to be where the client says: services check ownership themselves.
function Check.instance(className: string?): Checker
	return function(value: any): (boolean, string?)
		if typeof(value) ~= "Instance" then
			return false, `expected an Instance, got {describe(value)}`
		end
		if className and not value:IsA(className) then
			return false, `expected a {className}, got a {value.ClassName}`
		end
		return true
	end
end

-- A string, finite number or boolean (DevTools arguments).
function Check.primitive(maxStringLength: number): Checker
	local text = Check.string(maxStringLength)
	return function(value: any): (boolean, string?)
		local kind = type(value)
		if kind == "boolean" then
			return true
		elseif kind == "number" then
			if isFinite(value) then
				return true
			end
			return false, "number isn't finite"
		elseif kind == "string" then
			return text(value)
		end
		return false, `expected text, a number or true/false, got {describe(value)}`
	end
end

-- Anything at all: only for data the server itself produces.
function Check.any(): Checker
	return function(_value: any): (boolean, string?)
		return true
	end
end

--[[
	The id of an entry of another Config type, e.g. `Check.ref("Weapons")`. It checks the
	value is an id-shaped string; the Config aggregator then checks that the entry exists,
	once every type has loaded.
]]
function Check.ref(typeName: string): Checker
	local idCheck = Check.string(64, { pattern = "^[%a][%w_]*$" })
	return function(value: any): (boolean, string?)
		local ok, why = idCheck(value)
		if not ok then
			return false, `{typeName} id: {why}`
		end
		local sink = refSink
		if sink then
			sink(typeName, value)
		end
		return true
	end
end

-- Used by the Config aggregator only.
function Check._setRefSink(sink: ((typeName: string, id: string) -> ())?)
	refSink = sink
end

return table.freeze(Check)
