--!strict
--[[
	RejoinService: "Rejoin your run" (bible Section 21: "A player who drops sees Rejoin your run in
	the lobby and comes back at the Medbay with their loadout"). Lobby only; Prompt 21.

	When a player's session is ready their rejoin record is read (Lib.Rejoin: written when their pad
	left, kept alive by the Run server while the run is on). If there is one, the Player gets the
	`RejoinOffer` attribute (the run's difficulty) and the client shows the card. RejoinRun sends
	them back with the record's access code (Lib.RunLaunch.Rejoin); RejoinDismiss puts the card away
	for this visit. A run that has ended has no record, so nothing is offered.

	Dev: rejoin (your record), rejoin.fake [Difficulty] (write a record so the card can be seen in
	Studio), rejoin.clear.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Rejoin = require(ServerScriptService.Lib.Rejoin)
local RunLaunch = require(ServerScriptService.Lib.RunLaunch)

local log = Log.new("RejoinService")

local RejoinService = {
	Name = "RejoinService",
	Dependencies = { "SessionService", "DevService" },
}

local session: any = nil
local busy: { [Player]: boolean } = {}

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function check(player: Player)
	local found, why = Rejoin.Read(player.UserId)
	if player.Parent ~= Players then
		return
	end
	if found then
		player:SetAttribute("RejoinOffer", found.Difficulty or "Normal")
		log:Info("%s has a run to rejoin (%s)", player.Name, tostring(found.Difficulty))
	else
		player:SetAttribute("RejoinOffer", nil)
		if why ~= "no record" then
			log:Warn("%s's rejoin record couldn't be read: %s", player.Name, tostring(why))
		end
	end
end

local function onRejoin(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	local ok, why = RunLaunch.Rejoin(player)
	busy[player] = nil
	if ok then
		alert(player, "Info", "BACK TO YOUR RUN: HOLD ON")
	else
		alert(player, "Warning", why or "YOU COULDN'T REJOIN")
		if why == "THAT RUN HAS ENDED" then
			player:SetAttribute("RejoinOffer", nil)
		end
	end
	log:Info("%s rejoins: %s", player.Name, if ok then "teleporting" else tostring(why))
end

function RejoinService:Init(registry)
	session = registry.SessionService
	Remotes.OnServer("RejoinRun", onRejoin)
	Remotes.OnServer("RejoinDismiss", function(player: Player)
		player:SetAttribute("RejoinOffer", nil)
	end)
	local dev = registry.DevService
	dev:Register("rejoin", {
		Description = "Your rejoin record, read again (the card shows if there is one).",
		Run = function(player: Player?): string?
			local who = player or Players:GetPlayers()[1]
			if not who then
				return "no player"
			end
			check(who)
			local found, why = Rejoin.Read(who.UserId)
			return if found then `{who.Name}: run {found.Key}, {tostring(found.Difficulty)}, written {os.time() - found.At} s ago`
				else `{who.Name}: {tostring(why)}`
		end,
	})
	dev:Register("rejoin.fake", {
		Description = "Write a rejoin record for you (Studio: to see the card; the teleport itself needs the live game).",
		Usage = "rejoin.fake [Difficulty]",
		Run = function(player: Player?, args): string?
			local who = player or Players:GetPlayers()[1]
			if not who then
				return "no player"
			end
			local ok, why = Rejoin.Write(who.UserId, { Key = "DevRun", Code = "dev-code", Difficulty = tostring(args[1] or "Normal"), At = os.time() }, 120)
			check(who)
			return if ok then `{who.Name}: a record for 120 s` else `not written: {tostring(why)}`
		end,
	})
	dev:Register("rejoin.clear", {
		Description = "Remove your rejoin record.",
		Run = function(player: Player?): string?
			local who = player or Players:GetPlayers()[1]
			if not who then
				return "no player"
			end
			Rejoin.Remove(who.UserId)
			check(who)
			return `{who.Name}: cleared`
		end,
	})
end

function RejoinService:Start()
	local function onReady(player: Player)
		task.spawn(check, player)
	end
	session.PlayerReady:Connect(onReady)
	for _, player in session:ReadyPlayers() do
		onReady(player)
	end
	session.PlayerLeaving:Connect(function(player: Player)
		busy[player] = nil
	end)
end

return RejoinService
