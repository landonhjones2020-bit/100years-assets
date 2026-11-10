--!strict
--[[
	Rejoin: where a player's run is, so one who drops can come back (bible Section 21: "the run id
	and the server's access code stay in MemoryStore under each player's id until the run ends").

	* One MemoryStore hash map, RunRejoin; the key is the player's user id.
	* The record: { Key = "<the Run server's reserved id>", Code = "<its access code>",
	  Difficulty = "Normal", At = os.time() }. Server-side only: access codes never go to clients.
	* The lobby writes it when a pad leaves (Lib.RunLaunch) for Tuning.Lobby.RejoinStartSeconds; the
	  Run server (PartyService) writes it again every RejoinRefreshSeconds for RejoinSeconds while
	  the run is on, and removes it when the run ends. A run whose server died stops being offered
	  within RejoinSeconds.
	* Read(userId) retries a failed MemoryStore call; nothing here errors.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")

local Check = require(game:GetService("ReplicatedStorage").Shared.Utilities.Check)

local Rejoin = {}

Rejoin.MAP = "RunRejoin"

export type Record = { Key: string, Code: string, Difficulty: string?, At: number }

local Schema = Check.shape({
	Key = Check.string(200, { min = 1 }),
	Code = Check.string(400, { min = 1 }),
	Difficulty = Check.optional(Check.string(32)),
	At = Check.number({ min = 0 }),
})

local function map(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(Rejoin.MAP)
end

function Rejoin.Read(userId: number): (Record?, string?)
	local lastError = "not read"
	for attempt = 1, 2 do
		local ok, value = pcall(function()
			return map():GetAsync(tostring(userId))
		end)
		if ok then
			if value == nil then
				return nil, "no record"
			end
			local good, why = Schema(value)
			return if good then value :: Record else nil, if good then nil else `a bad record: {why}`
		end
		lastError = tostring(value)
		task.wait(attempt)
	end
	return nil, lastError
end

function Rejoin.Write(userId: number, record: Record, seconds: number): (boolean, string?)
	local good, why = Schema(record)
	if not good then
		return false, `a bad record: {why}`
	end
	local ok, err = pcall(function()
		map():SetAsync(tostring(userId), record, math.clamp(math.floor(seconds), 1, 3888000))
	end)
	return ok, if ok then nil else tostring(err)
end

function Rejoin.Remove(userId: number): boolean
	local ok = pcall(function()
		map():RemoveAsync(tostring(userId))
	end)
	return ok
end

return table.freeze(Rejoin)
