--!strict
--[[
	PartyService: who belongs to this run (bible Section 21). Run place only; Prompt 21.

	The lobby writes the run's record to MemoryStore before it teleports the party (Lib.RunLaunch,
	Lib.RunRecord: the party, the difficulty, the loadouts, the server's access code). This service
	reads it once and:

	* sets the run's difficulty (RunDirector:SetDifficulty) before the first player is ready;
	* lets in only the record's party ("New players can't join a run in progress"): a session
	  waits at the Party gate until the record is read; a stranger is sent back to the lobby, and so
	  is anyone who lands in a Run server that isn't a reserved one (runs start from the lobby);
	* keeps each party member's rejoin record alive (Lib.Rejoin) while the run is on, so one who
	  drops can come back from the lobby, and removes them when the run ends or the server closes.

	In Studio there is no reserved server: everyone is let in, and a record under the Studio key (a
	Lobby playtest's pad, or dev `record`) still sets the difficulty and classes.

	API: Party(): { number } (the record's user ids; empty without a record), Record().
	Dev: party.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Rejoin = require(ServerScriptService.Lib.Rejoin)
local RunRecord = require(ServerScriptService.Lib.RunRecord)

local log = Log.new("PartyService")

local GATE = "Party"
local IS_STUDIO = RunService:IsStudio()

local PartyService = {
	Name = "PartyService",
	Dependencies = { "SessionService", "RunDirector", "DevService" },
}

local session: any = nil
local director: any = nil

local record: RunRecord.Record? = nil
local why: string? = nil
local read = false
local cleared = false

local function toLobby(player: Player, message: string)
	log:Info("%s isn't in this run's party: back to the lobby (%s)", player.Name, message)
	local ok = pcall(function()
		TeleportService:Teleport(Constants.PLACE_IDS.Lobby, player)
	end)
	if not ok then
		session:Fail(player, message)
	end
end

local function admit(player: Player)
	if player.Parent ~= Players then
		return
	end
	if IS_STUDIO then
		session:Pass(player, GATE)
		return
	end
	if not record then
		toLobby(player, "Runs start from the lobby.")
		return
	end
	if not table.find(record.Party, player.UserId) then
		toLobby(player, "This run has already started. Start a new one from the lobby.")
		return
	end
	session:Pass(player, GATE)
end

local function refreshRejoin()
	local key = RunRecord.Key()
	if IS_STUDIO or not record or not record.Code or not key then
		return
	end
	local seconds = Config.Get("Tuning", "Lobby").RejoinSeconds
	for _, userId in record.Party do
		Rejoin.Write(userId, { Key = key, Code = record.Code, Difficulty = record.Difficulty, At = os.time() }, seconds)
	end
end

local function clearRejoin()
	if cleared or IS_STUDIO or not record then
		return
	end
	cleared = true
	for _, userId in record.Party do
		Rejoin.Remove(userId)
	end
	log:Info("the run is over: %d rejoin records removed", #record.Party)
end

function PartyService:Party(): { number }
	return if record then table.clone(record.Party) else {}
end

function PartyService:Record(): RunRecord.Record?
	return record
end

function PartyService:Init(registry)
	session = registry.SessionService
	director = registry.RunDirector
	session:AddGate(GATE)
	registry.DevService:Register("party", {
		Description = "This run's record: its key, party, difficulty and whether it was read.",
		Run = function(): string?
			if not read then
				return "the record hasn't been read yet"
			end
			if not record then
				return `no record under {tostring(RunRecord.Key())} ({tostring(why)}); difficulty {director:Difficulty()}`
			end
			local ids = {}
			for _, userId in record.Party do
				table.insert(ids, tostring(userId))
			end
			return `record {tostring(RunRecord.Key())}: party {table.concat(ids, ", ")}, {tostring(record.Difficulty)}, written {os.time() - record.CreatedAt} s ago, access code {if record.Code then "kept" else "none"}`
		end,
	})
end

function PartyService:Start()
	task.spawn(function()
		record, why = RunRecord.Mine()
		read = true
		if record then
			if record.Difficulty and director:SetDifficulty(record.Difficulty) then
				log:Info("the run's record: %d in the party, %s", #record.Party, record.Difficulty)
			else
				log:Info("the run's record: %d in the party", #record.Party)
			end
		else
			log:Info("no run record (%s)", tostring(why))
		end
		for _, player in Players:GetPlayers() do
			admit(player)
		end
		Players.PlayerAdded:Connect(admit)
		-- the rejoin records live as long as the run does
		local t = Config.Get("Tuning", "Lobby")
		local nextWrite = 0
		while not cleared do
			if director:Phase() == "Ended" then
				clearRejoin()
				break
			end
			if os.clock() >= nextWrite then
				nextWrite = os.clock() + t.RejoinRefreshSeconds
				refreshRejoin()
			end
			task.wait(5)
		end
	end)
	director.RunEnded:Connect(function()
		task.spawn(clearRejoin)
	end)
	game:BindToClose(function()
		clearRejoin()
	end)
end

return PartyService
