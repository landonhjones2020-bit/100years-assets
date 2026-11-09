--!strict
--[[
	BreachService: where monsters break in, the warning, and the spawns (bible Section 10).
	Run place only; Prompt 12.

	Breach points (Section 10; Section 6: every dug cell next to rock is a way in)
	* every room's vent (BunkerKit's Kit_Vent; the Shaft and the Blast Door have none);
	* every dug cell next to rock, on any floor (Landon, 2026-11-08: every tunnel touching rock
	  counts, not only the deepest band's);
	* cave openings and living nests in dug cells (DigService adds them, Prompt 14; the caves
	  behind the openings come with Prompt 17), and the Blast Door's surface threats with raids
	  (Prompt 16).
	Each point has a weight: DarkRoomWeight in a dark room (Section 6: dark rooms spawn monsters
	twice as often), BarricadeWeight when barricaded (its Barricaded attribute; the Engineer's
	barricades come with Prompt 20).

	Open(pointId, groups, tag)
	* BreachWarningSeconds of warning (Section 10: cracks, dust and a rumble give 10 seconds):
	  dust pours from the point and a red lamp pulses there; every player gets the BreachWarning
	  remote (the HUD's alert, the mini-map's marker) and the Breaches collection carries it for
	  the Command View's Threat overlay.
	* Then the monsters come out one by one (SpawnSpacingSeconds) through MonsterService.

	API:
		BreachService:Points(): { { Id, Kind, RoomId?, Floor, Column, Weight, Dark } }
		BreachService:Pick(rng): point?                    -- weighted
		BreachService:Open(pointId, groups, tag?): boolean
		BreachService:SetExtraPoint(id, point?)            -- Prompt 14: cave openings and nests
		BreachService.Opened: Signal<string, string?>      -- point id, tag (after the warning)
	Dev: breaches, breach.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)
local Threat = require(Shared.Rules.Threat)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("BreachService")

local BreachService = {
	Name = "BreachService",
	Dependencies = { "BunkerGrid", "PowerService", "MonsterService", "SessionService", "ReplicationService", "DevService" },
	Opened = Signal.new() :: Signal.Signal<string, string?>,
}

export type Point = {
	Id: string, -- "V:<roomId>" (a vent), "D:<floor>,<column>" (a dug cell at the rock), or one another service adds
	Kind: string, -- "Vent", "Rock", or another service's ("Cave", "Nest": DigService, Prompt 14)
	RoomId: string?,
	Floor: number,
	Column: number,
	Weight: number,
	Dark: boolean,
	At: CFrame, -- where monsters come out, on the floor, facing into the bunker
	Source: Vector3, -- the vent or the rock face, for the dust
}

local NO_VENT: { [string]: boolean } = { Shaft = true, BlastDoor = true }

local grid: any = nil
local power: any = nil
local monsters: any = nil
local session: any = nil
local dev: any = nil
local collection: any = nil

local warnings: { [string]: { EndsAt: number, Tag: string? } } = {}
local extra: { [string]: Point } = {} -- points other services add (Prompt 14: cave openings, nests)

local function threatTuning(): { [string]: any }
	return Config.Get("Tuning", "Threat")
end

local function ventOf(room: any): (Vector3?, CFrame?)
	local model = grid:RoomModel(room.Id)
	if not model then
		return nil, nil
	end
	local vent = model:FindFirstChild("Vent", true)
	local socket = BunkerKit.Socket(model, "Vent")
	local position = if socket then socket.Position elseif vent and vent:IsA("BasePart") then vent.Position
		elseif vent and vent:IsA("Model") then (vent:GetBoundingBox()).Position else nil
	return position, socket
end

local function roomPoint(room: any, dark: boolean): Point
	local cell = Grid.CellPosition(room.Floor, room.Column)
	local vent = ventOf(room)
	local source = vent or (cell + Vector3.new(0, 6, -6))
	-- monsters drop from the vent to the floor in front of it, a little into the room
	local out = Vector3.new(source.X, cell.Y + 0.5, math.min(source.Z + 4, cell.Z + 4))
	local t = threatTuning()
	local weight = if dark then t.DarkRoomWeight else 1
	return {
		Id = `V:{room.Id}`,
		Kind = "Vent",
		RoomId = room.Id,
		Floor = room.Floor,
		Column = room.Column,
		Weight = weight,
		Dark = dark,
		At = CFrame.lookAt(out, out + Vector3.new(0, 0, 1)),
		Source = source,
	}
end

-- Every dug cell next to rock, on any floor (Landon's answer to the Prompt 12 question: every
-- tunnel touching rock is a way in, not only the deepest band's).
local function rockPoints(): { Point }
	local list: { Point } = {}
	local t = Grid.Tuning()
	for floor = t.FloorMin, t.FloorMax do
		for column = t.ColumnMin, t.ColumnMax do
			local state = grid:State(floor, column)
			if state == "Dug" then
				local rockSide: number? = nil
				for _, dc in { -1, 1 } do
					if Grid.OnGrid(floor, column + dc) and grid:State(floor, column + dc) == "Rock" then
						rockSide = dc
					end
				end
				local below = Grid.OnGrid(floor + 1, column) and grid:State(floor + 1, column) == "Rock"
				if rockSide or below then
					local cell = Grid.CellPosition(floor, column)
					local side = rockSide or 0
					local source = cell + Vector3.new(side * (Grid.Pitch().X / 2 - 1), 3, 0)
					local out = cell + Vector3.new(side * (Grid.Pitch().X / 2 - 5), 0.5, 4)
					table.insert(list, {
						Id = `D:{floor},{column}`,
						Kind = "Rock",
						RoomId = nil,
						Floor = floor,
						Column = column,
						Weight = 1,
						Dark = false,
						At = CFrame.lookAt(out, out + Vector3.new(-side, 0, 1)),
						Source = source,
					})
				end
			end
		end
	end
	return list
end

function BreachService:Points(): { Point }
	local list: { Point } = {}
	for _, room in grid:Rooms() do
		if not NO_VENT[room.Type] then
			local point = roomPoint(room, power:IsDark(room.Id))
			local model = grid:RoomModel(room.Id)
			if model and model:GetAttribute("Barricaded") then
				point.Weight *= threatTuning().BarricadeWeight
			end
			table.insert(list, point)
		end
	end
	for _, point in rockPoints() do
		table.insert(list, point)
	end
	for _, point in extra do
		table.insert(list, point)
	end
	return list
end

-- A breach point another service owns (Prompt 14: a cave opening, a living nest); nil removes it.
function BreachService:SetExtraPoint(id: string, point: Point?)
	extra[id] = point
end

function BreachService:Pick(rng: Random, exclude: { [string]: boolean }?): Point?
	local candidates = {}
	for _, point in BreachService:Points() do
		if not (exclude and exclude[point.Id]) then
			table.insert(candidates, point)
		end
	end
	local picked = Threat.Pick(candidates :: any, rng)
	return picked :: any
end

local function pointById(id: string): Point?
	for _, point in BreachService:Points() do
		if point.Id == id then
			return point
		end
	end
	return nil
end

local function placeName(point: Point): string
	if point.RoomId then
		local room = grid:Room(point.RoomId)
		if room then
			return string.upper(Config.Get("Rooms", room.Type).Name)
		end
	end
	if point.Kind == "Cave" then
		return `THE CAVE OPENING, FLOOR {point.Floor}`
	elseif point.Kind == "Nest" then
		return `THE NEST, FLOOR {point.Floor}`
	end
	return `THE ROCK, FLOOR {point.Floor}`
end

-- the warning in the world: dust from the vent or the rock, and a pulsing red lamp
local function warningEffect(point: Point, seconds: number)
	local part = Instance.new("Part")
	part.Name = `Breach_{point.Id}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(4, 1, 1)
	part.Position = point.Source
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 140, 128))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.6) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.2)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.Acceleration = Vector3.new(0, -4, 0)
	dust.Rate = 26
	dust.Parent = part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(232, 80, 59)
	light.Range = 16
	light.Brightness = 2
	light.Parent = part
	part.Parent = workspace:FindFirstChild("Monsters") or workspace
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while os.clock() < endsAt and part.Parent do
			light.Brightness = if light.Brightness > 1 then 0.4 else 2.6
			task.wait(0.45)
		end
		dust.Rate = 60 -- the burst as they come out
		task.wait(1.2)
		part:Destroy()
	end)
end

local function publish(point: Point)
	local warning = warnings[point.Id]
	if warning then
		collection:Set(point.Id, {
			Floor = point.Floor,
			Column = point.Column,
			RoomId = point.RoomId,
			EndsAt = warning.EndsAt,
		})
	else
		collection:Remove(point.Id)
	end
end

function BreachService:Open(pointId: string, groups: { Threat.Group }, tag: string?): boolean
	local point = pointById(pointId)
	if not point or #groups == 0 then
		return false
	end
	local seconds = threatTuning().BreachWarningSeconds
	local endsAt = workspace:GetServerTimeNow() + seconds
	warnings[point.Id] = { EndsAt = endsAt, Tag = tag }
	publish(point)
	warningEffect(point, seconds)
	local total = 0
	for _, group in groups do
		total += group.Count
	end
	for _, player in session:ReadyPlayers() do
		Remotes.FireClient("BreachWarning", player, point.Floor, point.Column, seconds, placeName(point), total, point.RoomId)
	end
	log:Info("breach at %s in %d s: %d monsters (%s)", point.Id, seconds, total, tag or "-")
	task.delay(seconds, function()
		warnings[point.Id] = nil
		publish(point)
		BreachService.Opened:Fire(point.Id, tag)
		local spacing = threatTuning().SpawnSpacingSeconds
		local n = 0
		for _, group in groups do
			for _ = 1, group.Count do
				local offset = CFrame.new(((n % 3) - 1) * 2.2, 0, -math.floor(n / 3) * 0.6)
				monsters:Spawn(group.Type, point.At * offset, tag)
				n += 1
				task.wait(spacing)
			end
		end
	end)
	return true
end

function BreachService:Warnings(): number
	local n = 0
	for _ in warnings do
		n += 1
	end
	return n
end

function BreachService:Init(registry)
	grid = registry.BunkerGrid
	power = registry.PowerService
	monsters = registry.MonsterService
	session = registry.SessionService
	dev = registry.DevService
	collection = registry.ReplicationService:Collection("Breaches")

	dev:Register("breaches", {
		Description = "The breach points and their weights (Prompt 12).",
		Usage = "breaches",
		Run = function(): string?
			local lines = {}
			for _, point in BreachService:Points() do
				table.insert(lines, `{point.Id} {point.Kind} floor {point.Floor} weight {point.Weight}{if point.Dark then " (dark)" else ""}`)
			end
			return if #lines > 0 then table.concat(lines, "\n") else "no breach points"
		end,
	})
	dev:Register("breach", {
		Description = "Open a breach now: a point (or a weighted pick), a monster type and how many.",
		Usage = "breach [pointId|any] [Type] [count]",
		Run = function(_player, args): string?
			local rng = Random.new()
			local pointId = tostring(args[1] or "any")
			if pointId == "any" then
				local point = BreachService:Pick(rng)
				if not point then
					return "no breach points"
				end
				pointId = point.Id
			end
			local monsterType = tostring(args[2] or "BurrowTick")
			if not Config.Find("Monsters", monsterType) then
				return `no monster {monsterType}`
			end
			local count = math.clamp(math.floor(tonumber(args[3]) or 3), 1, 25)
			local ok = BreachService:Open(pointId, { { Type = monsterType, Count = count } }, "Dev")
			return if ok then `breach at {pointId}: {count} {monsterType} in {threatTuning().BreachWarningSeconds} s` else `no point {pointId}`
		end,
	})
end

function BreachService:Start()
	log:Info("breach points ready")
end

return BreachService
