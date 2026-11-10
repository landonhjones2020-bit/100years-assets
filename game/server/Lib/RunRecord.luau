--!strict
--[[
	RunRecord: the record the lobby writes before it teleports a party into a Run server (bible
	Sections 21 and 23: "Loadouts and the party list are written to MemoryStore under the run's id
	first. The Run server reads them from there and never trusts teleport data").

	* One MemoryStore hash map, RunRecords; the key is the Run server's reserved-server id
	  (game.PrivateServerId, which TeleportService:ReserveServer gives the lobby). In Studio there
	  is no reserved server: the key is "Studio" (DevTools can write a test record there, so the
	  read path can be tried before Prompt 21's lobby writes real ones).
	* The record (version 1):
		{ Version = 1, Party = { user ids }, Difficulty = "Normal",
		  Loadouts = { ["<user id>"] = { Class = "Medic", Trial = false } }, CreatedAt = os.time() }
	  Prompt 20 reads Loadouts (ClassService); Prompt 21 writes the record and reads Party and
	  Difficulty (RunDirector).
	* Read(key) retries a failed MemoryStore call a few times; it never errors. Write(key, record,
	  seconds) is the lobby's (and DevTools').
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local Check = require(game:GetService("ReplicatedStorage").Shared.Utilities.Check)

local RunRecord = {}

RunRecord.MAP = "RunRecords"
RunRecord.VERSION = 1
RunRecord.STUDIO_KEY = "Studio"

export type Loadout = { Class: string, Trial: boolean? }
export type Record = {
	Version: number,
	Party: { number },
	Difficulty: string?,
	Loadouts: { [string]: Loadout },
	CreatedAt: number,
}

local Schema = Check.shape({
	Version = Check.integer(1, 100),
	Party = Check.array(Check.integer(1), 12),
	Difficulty = Check.optional(Check.string(32)),
	Loadouts = Check.map(Check.string(20, { pattern = "^%d+$", min = 1 }), Check.shape({
		Class = Check.string(40, { pattern = "^%a[%w]*$", min = 1 }),
		Trial = Check.optional(Check.boolean()),
	}), 12),
	CreatedAt = Check.number({ min = 0 }),
})

-- This server's key, or nil when it isn't a reserved Run server (and isn't Studio).
function RunRecord.Key(): string?
	local id = game.PrivateServerId
	if id ~= "" then
		return id
	end
	return if RunService:IsStudio() then RunRecord.STUDIO_KEY else nil
end

local function map(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(RunRecord.MAP)
end

-- The record under `key`, or nil and why (none written, a MemoryStore failure, a bad shape).
function RunRecord.Read(key: string): (Record?, string?)
	local lastError = "not read"
	for attempt = 1, 3 do
		local ok, value = pcall(function()
			return map():GetAsync(key)
		end)
		if ok then
			if value == nil then
				return nil, "no record"
			end
			local good, why = Schema(value)
			if not good then
				return nil, `a bad record: {why}`
			end
			return value :: Record, nil
		end
		lastError = tostring(value)
		task.wait(attempt)
	end
	return nil, lastError
end

-- Writes the record for `seconds` (MemoryStore expires it after). The lobby's, and DevTools'.
function RunRecord.Write(key: string, record: Record, seconds: number): (boolean, string?)
	local good, why = Schema(record)
	if not good then
		return false, `a bad record: {why}`
	end
	local ok, err = pcall(function()
		map():SetAsync(key, record, math.clamp(math.floor(seconds), 1, 3888000))
	end)
	return ok, if ok then nil else tostring(err)
end

function RunRecord.Remove(key: string): boolean
	local ok = pcall(function()
		map():RemoveAsync(key)
	end)
	return ok
end

-- A player's loadout in a record.
function RunRecord.Loadout(record: Record?, userId: number): Loadout?
	if not record then
		return nil
	end
	return record.Loadouts[tostring(userId)]
end

return table.freeze(RunRecord)
