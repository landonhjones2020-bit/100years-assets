--!strict
--[[
	ThreatController: what players see of the Threat Director (bible Sections 7 and 10). Run
	place only; Prompt 12.

	* A breach warning (BreachService's BreachWarning: Section 10's 10 seconds of cracks, dust
	  and rumble, with an alert on the HUD and the mini-map): a Danger alert ("BREACH IN 10 S:
	  KITCHEN · 4 MONSTERS"), a pin on the mini-map and the room's block blinking until the
	  monsters come out.
	* The Command View's Threat overlay (Section 7: likely breach points): a room with monsters
	  in it reads "3 MONSTERS" in red; a breach on its way "BREACH 7 S" in red; a dark room's vent
	  (twice as likely, Section 6) "LIKELY" in amber; any other vent "VENT" in green.
	* Spitter goo's slow on the local player (the SlowedUntil attribute) through Lib.Movement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Movement = require(Lib:WaitForChild("Movement"))

local log = Log.new("ThreatController")

local ThreatController = {
	Name = "ThreatController",
	Dependencies = { "HUDController", "MiniMapController", "CommandViewController", "ReplicaController" },
}

local NO_VENT: { [string]: boolean } = { Shaft = true, BlastDoor = true }

local hud: any = nil
local miniMap: any = nil
local commandView: any = nil
local replica: any = nil
local player = Players.LocalPlayer

-- monsters per room, from the monster models' positions (counted a few times a second)
local perRoom: { [string]: number } = {}

local function countMonsters()
	table.clear(perRoom)
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return
	end
	local rooms = replica:All("Rooms")
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("MonsterType") then
			local floor, column = Grid.CellAt(model:GetPivot().Position)
			if floor and column then
				for id, room in rooms do
					if type(room) == "table" and room.Floor == floor and column >= room.Column
						and column < room.Column + (room.Span or 1) then
						perRoom[id] = (perRoom[id] or 0) + 1
					end
				end
			end
		end
	end
end

local function warningFor(roomId: string): number?
	local warning = replica:Get("Breaches", `V:{roomId}`)
	if type(warning) == "table" and type(warning.EndsAt) == "number" then
		local left = warning.EndsAt - workspace:GetServerTimeNow()
		if left > 0 then
			return left
		end
	end
	return nil
end

function ThreatController:Init(registry)
	hud = registry.HUDController
	miniMap = registry.MiniMapController
	commandView = registry.CommandViewController
	replica = registry.ReplicaController
end

function ThreatController:Start()
	Remotes.OnClient("BreachWarning", function(floor: any, column: any, seconds: any, place: any, count: any, roomId: any)
		if type(floor) ~= "number" or type(column) ~= "number" or type(seconds) ~= "number" then
			return
		end
		local where = if type(place) == "string" then place else "THE BUNKER"
		local how = if type(count) == "number" then ` · {count} {if count == 1 then "MONSTER" else "MONSTERS"}` else ""
		hud:Alert("Danger", `BREACH IN {math.floor(seconds + 0.5)} S: {where}{how}`, seconds)
		miniMap:Ping(floor, column)
		local key = if type(roomId) == "string" then roomId else `{floor},{column}`
		miniMap:Blink(key, true)
		task.delay(seconds + 2, function()
			miniMap:Blink(key, false)
		end)
	end)

	commandView:SetOverlay("Threat", function(roomId: string, room: any): (string?, string?)
		local n = perRoom[roomId] or 0
		if n > 0 then
			return "Lamp_Red", if n == 1 then "1 MONSTER" else `{n} MONSTERS`
		end
		local left = warningFor(roomId)
		if left then
			return "Lamp_Red", `BREACH {math.ceil(left)} S`
		end
		if NO_VENT[room.Type] then
			return nil, nil
		end
		local power = replica:Get("Power", roomId)
		if type(power) == "table" and power.Dark then
			return "Lamp_Amber", "LIKELY"
		end
		return "Lamp_Green", "VENT"
	end)

	-- Spitter goo slows the local player (MonsterService sets SlowedUntil)
	local slowed = false
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.25 then
			return
		end
		last = os.clock()
		pcall(countMonsters)
		local untilAt = player:GetAttribute("SlowedUntil")
		local on = type(untilAt) == "number" and untilAt > workspace:GetServerTimeNow()
		if on ~= slowed then
			slowed = on
			Movement.Set("Slowed", if on then Config.Get("Tuning", "MonsterAI").GooSlowMultiplier else nil)
		end
	end)
	log:Debug("threat display ready")
end

return ThreatController
