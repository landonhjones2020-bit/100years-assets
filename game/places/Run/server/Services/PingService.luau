--!strict
--[[
	PingService: cell pings (bible Section 7: "Ping any cell; it shows on every player's
	mini-map"). Run place only.

	A player pings a cell from the Command View (the PingCell remote: floor, column). The
	server checks the cell is on the grid and the player's session is ready (the remote's rate
	limit stops spam), then tells every ready player (CellPinged: floor, column, the pinger's
	UserId and display name). Clients show the ping on the mini-map and in the Command View for
	Tuning.Ping.Seconds.

	The world ping (the Ping action in play, and the Rally ping of Section 11) comes with combat
	and residents and will go through here too.

	API:
		PingService:Ping(player, floor, column): (boolean, string?)
		PingService.Pinged: Signal<Player, number, number>
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("PingService")

local PingService = {
	Name = "PingService",
	Dependencies = { "SessionService", "DevService" },
	Pinged = Signal.new() :: Signal.Signal<Player, number, number>,
}

local session: any = nil
local sent = 0

function PingService:Ping(player: Player, floor: number, column: number): (boolean, string?)
	if not session:IsReady(player) then
		return false, "not ready yet"
	elseif not Grid.OnGrid(floor, column) then
		return false, "off the grid"
	end
	sent += 1
	Remotes.FireClients("CellPinged", session:ReadyPlayers(), floor, column, player.UserId, player.DisplayName)
	log:Debug("%s pinged %s", player.Name, Grid.Key(floor, column))
	PingService.Pinged:Fire(player, floor, column)
	return true, nil
end

function PingService:Init(registry)
	session = registry.SessionService
	Remotes.OnServer("PingCell", function(player: Player, floor: number, column: number)
		PingService:Ping(player, floor, column)
	end)
	registry.DevService:Register("cell.ping", {
		Description = "Ping a cell as if from the Command View (every player sees it on the mini-map).",
		Usage = "cell.ping <floor> <column>",
		Run = function(player: Player, args): string?
			local floor, column = tonumber(args[1]), tonumber(args[2])
			if not floor or not column then
				return "usage: cell.ping <floor> <column>"
			end
			local ok, why = PingService:Ping(player, floor, column)
			return if ok then `pinged {Grid.Key(floor, column)} ({sent} pings this run)` else `not pinged: {why}`
		end,
	})
end

return PingService
