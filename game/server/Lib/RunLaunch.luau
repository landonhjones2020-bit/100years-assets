--!strict
--[[
	RunLaunch: sends a party to a fresh Run server (bible Section 21: "On launch, the lobby reserves
	a private Run server and teleports the party there. Loadouts and the party list are written to
	MemoryStore under the run's id first"). The lobby's pads use it (PadService), and so does Play
	Again on the results screen (ResultsService), so a party's classes go with it.

		RunLaunch.Start(players, difficulty, loadouts) -> (ok, why?)

	loadouts: [userId] = { Class = "Medic", Trial = false }. In order: reserve the server, write the
	run's record under its id (Lib.RunRecord: party, difficulty, loadouts, the access code), write
	each player's rejoin record (Lib.Rejoin), teleport. Any step failing stops the launch and says
	why; nothing is left behind but records that expire.

	Studio can't reserve servers or teleport: there the record goes under RunRecord.STUDIO_KEY, so
	a Run playtest started next reads it, and Start says so.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Rejoin = require(script.Parent.Rejoin)
local RunRecord = require(script.Parent.RunRecord)

local RunLaunch = {}

export type Loadouts = { [number]: RunRecord.Loadout }

local function record(players: { Player }, difficulty: string, loadouts: Loadouts, code: string?): RunRecord.Record
	local party, packed = {}, {}
	for _, player in players do
		table.insert(party, player.UserId)
		local loadout = loadouts[player.UserId]
		packed[tostring(player.UserId)] = {
			Class = if loadout then loadout.Class else "Survivor",
			Trial = if loadout and loadout.Trial then true else nil,
		}
	end
	return {
		Version = RunRecord.VERSION,
		Party = party,
		Difficulty = difficulty,
		Loadouts = packed,
		CreatedAt = os.time(),
		Code = code,
	}
end

function RunLaunch.Start(players: { Player }, difficulty: string, loadouts: Loadouts): (boolean, string?)
	if #players == 0 then
		return false, "NOBODY TO SEND"
	end
	if not Config.Find("Difficulties", difficulty) then
		return false, "NO SUCH DIFFICULTY"
	end
	local t = Config.Get("Tuning", "Lobby")
	if RunService:IsStudio() then
		-- ten minutes: long enough to start a Run playtest next, short enough not to haunt later ones
		local ok, why = RunRecord.Write(RunRecord.STUDIO_KEY, record(players, difficulty, loadouts, nil), 600)
		return false, if ok then "TELEPORTS DON'T WORK IN STUDIO (THE RUN'S RECORD IS WRITTEN)" else `NO RECORD: {tostring(why)}`
	end
	local placeId = Constants.PLACE_IDS.Run
	local reserved, code, serverId = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if not reserved or type(code) ~= "string" or type(serverId) ~= "string" then
		return false, `NO SERVER: {tostring(code)}`
	end
	local wrote, why = RunRecord.Write(serverId, record(players, difficulty, loadouts, code), t.RecordSeconds)
	if not wrote then
		return false, `NO RECORD: {tostring(why)}`
	end
	for _, player in players do
		Rejoin.Write(player.UserId, { Key = serverId, Code = code, Difficulty = difficulty, At = os.time() }, t.RejoinStartSeconds)
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not sent then
		for _, player in players do
			Rejoin.Remove(player.UserId)
		end
		RunRecord.Remove(serverId)
		return false, `THE TELEPORT FAILED: {tostring(err)}`
	end
	return true, nil
end

-- Sends one player back into the run their rejoin record names. (ok, why?)
function RunLaunch.Rejoin(player: Player): (boolean, string?)
	local found, why = Rejoin.Read(player.UserId)
	if not found then
		return false, if why == "no record" then "THAT RUN HAS ENDED" else `NO RECORD: {tostring(why)}`
	end
	if RunService:IsStudio() then
		return false, "TELEPORTS DON'T WORK IN STUDIO"
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = found.Code
	local sent, err = pcall(function()
		TeleportService:TeleportAsync(Constants.PLACE_IDS.Run, { player }, options)
	end)
	return sent, if sent then nil else `THE TELEPORT FAILED: {tostring(err)}`
end

return table.freeze(RunLaunch)
