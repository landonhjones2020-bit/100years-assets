--!strict
--[[
	SessionService: player sessions in this server (infrastructure, Prompt 0).

	A player is "ready" once their client has bootstrapped and said so (the ClientReady
	remote). Services that send a player state wait for PlayerReady instead of PlayerAdded,
	so nothing is sent before the client can receive it. From Prompt 2 a session will also
	wait for the player's profile to load.

	API:
		SessionService.PlayerReady: Signal<Player>
		SessionService.PlayerLeaving: Signal<Player>
		SessionService:IsReady(player): boolean
		SessionService:ReadyPlayers(): { Player }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("SessionService")

local SessionService = {
	Name = "SessionService",
	Dependencies = {},
	PlayerReady = Signal.new() :: Signal.Signal<Player>,
	PlayerLeaving = Signal.new() :: Signal.Signal<Player>,
}

local ready: { [Player]: number } = {}

function SessionService:Init(_registry)
	Remotes.OnServer("ClientReady", function(player: Player)
		if ready[player] or player.Parent ~= Players then
			return
		end
		ready[player] = os.clock()
		player:SetAttribute("ClientReady", true)
		log:Debug("%s ready", player.Name)
		SessionService.PlayerReady:Fire(player)
	end)
end

function SessionService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		SessionService.PlayerLeaving:Fire(player)
		ready[player] = nil
	end)
end

function SessionService:IsReady(player: Player): boolean
	return ready[player] ~= nil
end

function SessionService:ReadyPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if ready[player] then
			table.insert(list, player)
		end
	end
	return list
end

return SessionService
