--!strict
--[[
	SessionService: player sessions in this server (infrastructure, Prompt 0; gates Prompt 2).

	A player is "ready" once every gate has passed: the client has bootstrapped (the
	ClientReady remote) and each gate a service added (ProfileService adds "Profile": the save
	has loaded). Services that send a player state wait for PlayerReady instead of
	PlayerAdded, so nothing is sent before the client can receive it or before the player's
	data exists.

	API:
		SessionService:AddGate(name)           -- in Init: one more thing a session waits for
		SessionService:Pass(player, name)      -- that thing is done for this player
		SessionService:Fail(player, message)   -- it can't be done: the player is kicked
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

local CLIENT_GATE = "Client"
local gates: { string } = { CLIENT_GATE }
local passed: { [Player]: { [string]: boolean } } = {}
local ready: { [Player]: number } = {}

local function checkReady(player: Player)
	if ready[player] or player.Parent ~= Players then
		return
	end
	local done = passed[player]
	if not done then
		return
	end
	for _, gate in gates do
		if not done[gate] then
			return
		end
	end
	ready[player] = os.clock()
	player:SetAttribute("SessionReady", true)
	log:Debug("%s ready", player.Name)
	SessionService.PlayerReady:Fire(player)
end

function SessionService:AddGate(name: string)
	assert(not table.find(gates, name), `SessionService: gate {name} already exists`)
	table.insert(gates, name)
end

function SessionService:Pass(player: Player, gate: string)
	assert(table.find(gates, gate), `SessionService: no gate {gate}`)
	local done = passed[player]
	if not done then
		done = {}
		passed[player] = done
	end
	if done[gate] then
		return
	end
	done[gate] = true
	checkReady(player)
end

function SessionService:Fail(player: Player, message: string)
	log:Warn("%s can't start a session: %s", player.Name, message)
	player:Kick(message)
end

function SessionService:Init(_registry)
	Remotes.OnServer("ClientReady", function(player: Player)
		if player.Parent ~= Players then
			return
		end
		player:SetAttribute("ClientReady", true)
		SessionService:Pass(player, CLIENT_GATE)
	end)
end

function SessionService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		SessionService.PlayerLeaving:Fire(player)
		ready[player] = nil
		passed[player] = nil
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

-- Which gates a player has passed (for DevTools).
function SessionService:Gates(player: Player): { [string]: boolean }
	local result: { [string]: boolean } = {}
	local done = passed[player] or {}
	for _, gate in gates do
		result[gate] = done[gate] == true
	end
	return result
end

return SessionService
