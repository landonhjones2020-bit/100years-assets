--!strict
--[[
	Config: every piece of content is data (bible Section 23). Rooms, resident name pools,
	traits, classes, talents, Legends, monsters, weapons, loot tables, draft cards,
	disasters, objectives and prices each get a ModuleScript under this one, and systems
	read them through this aggregator. Adding content never needs new system code.

	A content module returns:

		return {
			Schema = Check.shape({ ... }),   -- the checker for one entry
			Entries = {                      -- keyed by id (letters, digits, _; starts with a letter)
				Kitchen = { ... },
			},
			Order = { "Kitchen", ... },      -- optional display order (default: ids sorted)
		}

	Every entry is checked against its Schema when Config loads; Check.ref("Weapons") fields
	must name an entry that exists. Entries come back frozen, with an `Id` field added.
	Problems don't stop the game from loading: they are listed by Config.Errors(), logged,
	and fail DevTools' StructureCheck and data tests.

	Content types arrive with Prompt 1; Prompt 0 ships the aggregator.
]]

local Check = require(script.Parent.Utilities.Check)
local Log = require(script.Parent.Utilities.Log)
local TableUtil = require(script.Parent.Utilities.TableUtil)

export type Entry = { [string]: any }

export type ContentType = {
	Name: string,
	Entries: { [string]: Entry },
	Order: { string },
}

export type Registry = {
	Types: { [string]: ContentType },
	Errors: { string },
}

local ID_PATTERN = "^[%a][%w_]*$"

local Config = {}

--[[
	Builds a registry from definitions ({ [typeName] = module table }). Pure: the data tests
	call it with fixtures.
]]
function Config.Build(definitions: { [string]: any }): Registry
	local registry: Registry = { Types = {}, Errors = {} }
	local errors = registry.Errors
	local refs: { { from: string, typeName: string, id: string } } = {}

	local typeNames = TableUtil.SortedKeys(definitions)
	for _, typeName in typeNames do
		local definition = definitions[typeName]
		if type(definition) ~= "table" then
			local reason = if type(definition) == "string" then definition else "the module must return a table"
			table.insert(errors, `{typeName}: {reason}`)
			continue
		end
		local schema = definition.Schema
		local entries = definition.Entries
		if type(schema) ~= "function" then
			table.insert(errors, `{typeName}: Schema must be a Check checker`)
			continue
		end
		if type(entries) ~= "table" then
			table.insert(errors, `{typeName}: Entries must be a table of id = entry`)
			continue
		end

		local built: { [string]: Entry } = {}
		for _, id in TableUtil.SortedKeys(entries) do
			local entry = entries[id]
			if type(id) ~= "string" or not string.find(id, ID_PATTERN) then
				table.insert(errors, `{typeName}: bad id {tostring(id)} (letters, digits and _, starting with a letter)`)
				continue
			end
			if type(entry) ~= "table" then
				table.insert(errors, `{typeName}.{id}: entry must be a table`)
				continue
			end
			if entry.Id ~= nil and entry.Id ~= id then
				table.insert(errors, `{typeName}.{id}: Id field doesn't match its key`)
				continue
			end
			local copy = TableUtil.DeepCopy(entry)
			copy.Id = nil
			Check._setRefSink(function(refType: string, refId: string)
				table.insert(refs, { from = `{typeName}.{id}`, typeName = refType, id = refId })
			end)
			local called, ok, why = pcall(schema, copy)
			Check._setRefSink(nil)
			if not called then
				table.insert(errors, `{typeName}.{id}: the schema check failed: {tostring(ok)}`)
				continue
			elseif not ok then
				table.insert(errors, `{typeName}.{id}: {why}`)
				continue
			end
			copy.Id = id
			built[id] = TableUtil.DeepFreeze(copy)
		end

		local order: { string } = {}
		if definition.Order ~= nil then
			if type(definition.Order) ~= "table" then
				table.insert(errors, `{typeName}: Order must be a list of ids`)
			else
				local listed: { [string]: boolean } = {}
				for _, id in definition.Order do
					if built[id] == nil then
						table.insert(errors, `{typeName}: Order lists {tostring(id)}, which isn't an entry`)
					elseif listed[id] then
						table.insert(errors, `{typeName}: Order lists {id} twice`)
					else
						listed[id] = true
						table.insert(order, id)
					end
				end
				for _, id in TableUtil.SortedKeys(built) do
					if not listed[id] then
						table.insert(errors, `{typeName}: Order is missing {id}`)
						table.insert(order, id)
					end
				end
			end
		else
			order = TableUtil.SortedKeys(built) :: { string }
		end

		registry.Types[typeName] = table.freeze({
			Name = typeName,
			Entries = table.freeze(built),
			Order = table.freeze(order),
		})
	end

	for _, ref in refs do
		local target = registry.Types[ref.typeName]
		if target == nil then
			table.insert(errors, `{ref.from}: refers to {ref.typeName}, which isn't a content type`)
		elseif target.Entries[ref.id] == nil then
			table.insert(errors, `{ref.from}: {ref.typeName}.{ref.id} doesn't exist`)
		end
	end

	table.freeze(registry.Types)
	return registry
end

local function loadChildren(): { [string]: any }
	local definitions: { [string]: any } = {}
	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			definitions[child.Name] = if ok then result else `failed to load: {result}`
		end
	end
	return definitions
end

local registry = Config.Build(loadChildren())

if #registry.Errors > 0 then
	local log = Log.new("Config")
	for _, problem in registry.Errors do
		log:Error("%s", problem)
	end
end

local function contentType(typeName: string): ContentType
	local found = registry.Types[typeName]
	if not found then
		error(`Config has no content type {tostring(typeName)}`, 3)
	end
	return found
end

-- The entry, or an error if it doesn't exist (a bug in the caller or the data).
function Config.Get(typeName: string, id: string): Entry
	local entry = contentType(typeName).Entries[id]
	if entry == nil then
		error(`Config: {typeName}.{tostring(id)} doesn't exist`, 2)
	end
	return entry
end

-- The entry or nil (for ids that arrive from players or saved data).
function Config.Find(typeName: string, id: any): Entry?
	local found = registry.Types[typeName]
	if not found or type(id) ~= "string" then
		return nil
	end
	return found.Entries[id]
end

-- Every entry of a type, in its Order.
function Config.All(typeName: string): { Entry }
	local found = contentType(typeName)
	local list = {}
	for _, id in found.Order do
		table.insert(list, found.Entries[id])
	end
	return list
end

function Config.Ids(typeName: string): { string }
	return contentType(typeName).Order
end

function Config.Types(): { string }
	return TableUtil.SortedKeys(registry.Types) :: { string }
end

function Config.Errors(): { string }
	return table.clone(registry.Errors)
end

return table.freeze(Config)
