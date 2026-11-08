--!strict
--[[
	BunkerKit: builds the bunker's world from Rules.Bunker data (bible Section 6). This is
	the graybox kit of Prompt 4: plain parts with the right sizes, doorways, stairs and
	labels. The A1 art kit replaces the parts later behind the same calls.

	workspace.Bunker
	  Frame     crust above floor 1, bedrock under floor 10, walls at the grid's two sides
	  Rock      one block per Rock cell, named by its key ("3,-2")
	  Dug       one model per Dug cell, named by its graph node ("D:2,3")
	  Rooms     one model per room, named by its id ("R4")

	* Every model streams as Persistent, so the Command View always has the whole bunker
	  (bible Section 23).
	* Every room has walls. A side wall gets a doorway when the cell beyond it is open
	  (rooms connect sideways through doorways in shared walls). Cells of one room have no
	  wall between them.
	* Front walls carry the FrontWall tag: solid while playing, hidden in the Command View
	  (Prompt 7).
	* Stacked Shafts get a hole in the slab between them and a stair up from the lower one.
	* The Medbay holds the players' spawn (it is their respawn point, Section 6).
	* Quarters get Beds[level] beds per cell; the Reactor Core and the Blast Door get a
	  marker. The Blast Door has a SurfaceExit attachment in its ceiling for the surface lift
	  (Prompt 16).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bunker = require(Shared.Rules.Bunker)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)

local BunkerKit = {}

BunkerKit.FRONT_WALL_TAG = "FrontWall"

local DOOR_WIDTH, DOOR_HEIGHT = 8, 10 -- the A0 cell shell's doorway
local CRUST, BEDROCK, EDGE = 6, 6, 6 -- rock around the grid
local SHAFT_HOLE = { FromX = 2, Depth = 8 } -- the opening between stacked Shafts, at the back right

local ROOM_COLORS: { [string]: Color3 } = {
	BlastDoor = Color3.fromRGB(96, 102, 110),
	Shaft = Color3.fromRGB(214, 168, 46),
	ReactorCore = Color3.fromRGB(58, 148, 160),
	Generator = Color3.fromRGB(210, 120, 40),
	Kitchen = Color3.fromRGB(200, 96, 64),
	WaterPurifier = Color3.fromRGB(70, 130, 190),
	Quarters = Color3.fromRGB(140, 120, 180),
	Medbay = Color3.fromRGB(226, 226, 220),
	Storage = Color3.fromRGB(150, 116, 80),
	Workshop = Color3.fromRGB(170, 150, 90),
}
local DEFAULT_ROOM_COLOR = Color3.fromRGB(170, 170, 160)
local WALL_COLOR = Color3.fromRGB(226, 216, 190) -- Steadfast cream
local FRONT_COLOR = Color3.fromRGB(200, 190, 166)
local CEILING_COLOR = Color3.fromRGB(236, 230, 214)
local LAMP_COLOR = Color3.fromRGB(255, 236, 196)
local BAND_COLORS: { [string]: Color3 } = {
	Mines = Color3.fromRGB(118, 94, 72),
	FloodedCaverns = Color3.fromRGB(74, 94, 108),
	CrystalHollows = Color3.fromRGB(100, 82, 128),
	SourceChamber = Color3.fromRGB(116, 52, 52),
}

type Folders = { Root: Instance, Frame: Model, Rock: Model, Dug: Folder, Rooms: Folder }

-- Parts --------------------------------------------------------------------------------

-- An anchored block between two corners.
local function block(parent: Instance, name: string, low: Vector3, high: Vector3, color: Color3, material: Enum.Material): Part?
	local size = high - low
	if size.X <= 0.01 or size.Y <= 0.01 or size.Z <= 0.01 then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = CFrame.new((low + high) / 2)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A horizontal slab, with an optional rectangular hole (x and z ranges) cut out of it.
local function slab(
	parent: Instance,
	name: string,
	low: Vector3,
	high: Vector3,
	hole: { MinX: number, MaxX: number, MinZ: number, MaxZ: number }?,
	color: Color3,
	material: Enum.Material
)
	if not hole then
		block(parent, name, low, high, color, material)
		return
	end
	block(parent, name, low, Vector3.new(hole.MinX, high.Y, high.Z), color, material)
	block(parent, name, Vector3.new(hole.MaxX, low.Y, low.Z), high, color, material)
	block(parent, name, Vector3.new(hole.MinX, low.Y, low.Z), Vector3.new(hole.MaxX, high.Y, hole.MinZ), color, material)
	block(parent, name, Vector3.new(hole.MinX, low.Y, hole.MaxZ), Vector3.new(hole.MaxX, high.Y, high.Z), color, material)
end

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	return model
end

local function lamp(parent: Instance, cell: Vector3, bright: boolean)
	local t = Grid.Tuning()
	local y = cell.Y + t.CellHeight - 0.6
	local part = block(
		parent,
		"Lamp",
		Vector3.new(cell.X - 2, y - 0.2, cell.Z + 3),
		Vector3.new(cell.X + 2, y, cell.Z + 5),
		LAMP_COLOR,
		if bright then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
	if part then
		part.CanCollide = false
		part.CastShadow = false
		local light = Instance.new("PointLight")
		light.Range = if bright then 30 else 18
		light.Brightness = if bright then 1.4 else 0.6
		light.Color = LAMP_COLOR
		light.Shadows = false
		light.Parent = part
	end
end

local function label(wall: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Back -- +Z: into the room
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.2
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(1, 0, 0, 56)
	textLabel.Position = UDim2.new(0, 0, 0, 16)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.fromRGB(40, 44, 48)
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = wall
end

-- Room walls and extras ----------------------------------------------------------------

-- A side wall on the plane between two cells: solid, or with a centred doorway.
local function sideWall(parent: Instance, name: string, x0: number, x1: number, floorY: number, z: number, doorway: boolean)
	local t = Grid.Tuning()
	local top = floorY + t.CellHeight
	local back, front = z - t.CellDepth / 2, z + t.CellDepth / 2
	if not doorway then
		block(parent, name, Vector3.new(x0, floorY, back), Vector3.new(x1, top, front), WALL_COLOR, Enum.Material.SmoothPlastic)
		return
	end
	local half = DOOR_WIDTH / 2
	block(parent, name, Vector3.new(x0, floorY, back), Vector3.new(x1, top, z - half), WALL_COLOR, Enum.Material.SmoothPlastic)
	block(parent, name, Vector3.new(x0, floorY, z + half), Vector3.new(x1, top, front), WALL_COLOR, Enum.Material.SmoothPlastic)
	block(parent, name, Vector3.new(x0, floorY + DOOR_HEIGHT, z - half), Vector3.new(x1, top, z + half), WALL_COLOR, Enum.Material.SmoothPlastic)
end

-- The stair up from a Shaft to the Shaft above: a plank along the back, rising to the right.
local function stair(parent: Instance, cell: Vector3)
	local t = Grid.Tuning()
	local rise = t.CellHeight + t.SlabThickness
	local run = t.CellWidth - 4
	local zMid = cell.Z - t.CellDepth / 2 + SHAFT_HOLE.Depth / 2
	local angle = math.atan2(rise, run)
	local length = math.sqrt(rise * rise + run * run)
	local normal = Vector3.new(-math.sin(angle), math.cos(angle), 0)
	local mid = Vector3.new(cell.X, cell.Y + rise / 2, zMid) - normal * 0.5
	local plank = Instance.new("Part")
	plank.Name = "Stair"
	plank.Anchored = true
	plank.Size = Vector3.new(length, 1, SHAFT_HOLE.Depth)
	plank.CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, angle)
	plank.Color = ROOM_COLORS.Shaft
	plank.Material = Enum.Material.DiamondPlate
	plank.Parent = parent
end

local function extras(model: Model, room: Bunker.Room, info: { [string]: any }, centre: Vector3, back: BasePart?)
	local t = Grid.Tuning()
	local y0, z0 = centre.Y, centre.Z
	if room.Type == "ReactorCore" then
		block(model, "CoreBase", Vector3.new(centre.X - 4, y0, z0 - 8), Vector3.new(centre.X + 4, y0 + 1, z0), Color3.fromRGB(60, 64, 70), Enum.Material.DiamondPlate)
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Anchored = true
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(10, 5, 5)
		core.CFrame = CFrame.new(centre.X, y0 + 6, z0 - 4) * CFrame.Angles(0, 0, math.rad(90))
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(90, 200, 230)
		core.Parent = model
	elseif room.Type == "BlastDoor" then
		local door = Instance.new("Part")
		door.Name = "Door"
		door.Anchored = true
		door.Shape = Enum.PartType.Cylinder
		door.Size = Vector3.new(1, 13, 13)
		door.CFrame = CFrame.new(centre.X, y0 + 7, z0 - t.CellDepth / 2 + 0.5) * CFrame.Angles(0, math.rad(90), 0)
		door.Material = Enum.Material.DiamondPlate
		door.Color = Color3.fromRGB(70, 74, 80)
		door.Parent = model
		if back then
			local exit = Instance.new("Attachment")
			exit.Name = "SurfaceExit"
			exit.Parent = back
			exit.WorldPosition = Vector3.new(centre.X, y0 + t.CellHeight, z0)
		end
	elseif room.Type == "Medbay" then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "MedbaySpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(centre.X, y0 + 0.5, z0 + 6)
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = Color3.fromRGB(196, 60, 60)
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.Parent = model
	elseif room.Type == "Quarters" and info.Beds then
		local beds = info.Beds[room.Level]
		for offset = 0, room.Span - 1 do
			local cell = Grid.CellPosition(room.Floor, room.Column + offset)
			local pitch = (t.CellWidth - 2) / beds
			for index = 1, beds do
				local x = cell.X - t.CellWidth / 2 + 1 + pitch * (index - 0.5)
				local bed = block(model, "Bed", Vector3.new(x - 1.4, y0, z0 - t.CellDepth / 2 + 0.5), Vector3.new(x + 1.4, y0 + 1.6, z0 - t.CellDepth / 2 + 7), Color3.fromRGB(120, 104, 160), Enum.Material.Fabric)
				if bed then
					bed:SetAttribute("Bed", offset * beds + index)
				end
			end
		end
	end
end

-- Units ----------------------------------------------------------------------------------

local function buildRoom(bunker: Bunker.Bunker, room: Bunker.Room, parent: Instance): Model
	local t = Grid.Tuning()
	local W, H, D, T, S = t.CellWidth, t.CellHeight, t.CellDepth, t.WallThickness, t.SlabThickness
	local info = Config.Get("Rooms", room.Type)
	local first = Grid.CellPosition(room.Floor, room.Column)
	local last = Grid.CellPosition(room.Floor, room.Column + room.Span - 1)
	local y0, z0 = first.Y, first.Z
	local xL, xR = first.X - W / 2 - T, last.X + W / 2 + T
	local centre = Vector3.new((first.X + last.X) / 2, y0, z0)
	local color = ROOM_COLORS[room.Type] or DEFAULT_ROOM_COLOR

	local model = newModel(room.Id, parent)
	model:SetAttribute("RoomId", room.Id)
	model:SetAttribute("RoomType", room.Type)
	model:SetAttribute("Floor", room.Floor)
	model:SetAttribute("Column", room.Column)
	model:SetAttribute("Span", room.Span)
	model:SetAttribute("Level", room.Level)

	local shaftBelow = room.Type == "Shaft" and bunker:IsShaft(room.Floor + 1, room.Column)
	local shaftAbove = room.Type == "Shaft" and bunker:IsShaft(room.Floor - 1, room.Column)
	local hole = {
		MinX = first.X + SHAFT_HOLE.FromX,
		MaxX = first.X + W / 2,
		MinZ = z0 - D / 2,
		MaxZ = z0 - D / 2 + SHAFT_HOLE.Depth,
	}

	slab(model, "Floor", Vector3.new(xL, y0 - S, z0 - D / 2 - T), Vector3.new(xR, y0, z0 + D / 2 + T), if shaftBelow then hole else nil, color, Enum.Material.SmoothPlastic)
	slab(model, "Ceiling", Vector3.new(xL + T, y0 + H - 0.5, z0 - D / 2), Vector3.new(xR - T, y0 + H, z0 + D / 2), if shaftAbove then hole else nil, CEILING_COLOR, Enum.Material.SmoothPlastic)
	local back = block(model, "BackWall", Vector3.new(xL, y0, z0 - D / 2 - T), Vector3.new(xR, y0 + H, z0 - D / 2), WALL_COLOR, Enum.Material.SmoothPlastic)
	local front = block(model, "FrontWall", Vector3.new(xL, y0, z0 + D / 2), Vector3.new(xR, y0 + H, z0 + D / 2 + T), FRONT_COLOR, Enum.Material.SmoothPlastic)
	if front then
		CollectionService:AddTag(front, BunkerKit.FRONT_WALL_TAG)
	end
	sideWall(model, "SideWallLeft", xL, xL + T, y0, z0, bunker:IsOpen(room.Floor, room.Column - 1))
	sideWall(model, "SideWallRight", xR - T, xR, y0, z0, bunker:IsOpen(room.Floor, room.Column + room.Span))
	for offset = 0, room.Span - 1 do
		lamp(model, Grid.CellPosition(room.Floor, room.Column + offset), true)
	end
	if back then
		label(back, `{info.Name}  L{room.Level}  ({room.Id})`)
	end
	if shaftAbove then
		stair(model, first)
	end
	extras(model, room, info, centre, back)
	return model
end

local function buildDug(floor: number, column: number, parent: Instance): Model
	local t = Grid.Tuning()
	local W, H, D, T, S = t.CellWidth, t.CellHeight, t.CellDepth, t.WallThickness, t.SlabThickness
	local cell = Grid.CellPosition(floor, column)
	local band = Grid.BandOf(floor)
	local rock = BAND_COLORS[band.Id] or BAND_COLORS.Mines
	local model = newModel("D:" .. Grid.Key(floor, column), parent)
	model:SetAttribute("Floor", floor)
	model:SetAttribute("Column", column)
	local x0, x1 = cell.X - W / 2 - T, cell.X + W / 2 + T
	block(model, "Floor", Vector3.new(x0, cell.Y - S, cell.Z - D / 2 - T), Vector3.new(x1, cell.Y, cell.Z + D / 2 + T), rock:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Ground)
	block(model, "BackRock", Vector3.new(x0, cell.Y, cell.Z - D / 2 - T), Vector3.new(x1, cell.Y + H, cell.Z - D / 2), rock, Enum.Material.Slate)
	local front = block(model, "FrontWall", Vector3.new(x0, cell.Y, cell.Z + D / 2), Vector3.new(x1, cell.Y + H, cell.Z + D / 2 + T), rock, Enum.Material.Slate)
	if front then
		CollectionService:AddTag(front, BunkerKit.FRONT_WALL_TAG)
	end
	lamp(model, cell, false)
	return model
end

local function buildRock(floor: number, column: number, parent: Instance)
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local cell = Grid.CellPosition(floor, column)
	local band = Grid.BandOf(floor)
	local part = block(
		parent,
		Grid.Key(floor, column),
		Vector3.new(cell.X - pitch.X / 2, cell.Y - t.SlabThickness, cell.Z - pitch.Z / 2),
		Vector3.new(cell.X + pitch.X / 2, cell.Y + t.CellHeight, cell.Z + pitch.Z / 2),
		BAND_COLORS[band.Id] or BAND_COLORS.Mines,
		Enum.Material.Slate
	)
	if part then
		part:SetAttribute("Floor", floor)
		part:SetAttribute("Column", column)
		part:SetAttribute("Band", band.Id)
	end
end

local function buildFrame(parent: Model)
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local topCell = Grid.CellPosition(t.FloorMin, t.ColumnMin)
	local bottomCell = Grid.CellPosition(t.FloorMax, t.ColumnMax)
	local left = topCell.X - pitch.X / 2
	local right = bottomCell.X + pitch.X / 2
	local top = topCell.Y + t.CellHeight
	local bottom = bottomCell.Y - t.SlabThickness
	local back, front = topCell.Z - pitch.Z / 2, topCell.Z + pitch.Z / 2
	local crust = BAND_COLORS.Mines:Lerp(Color3.fromRGB(90, 80, 60), 0.5)
	for column = t.ColumnMin, t.ColumnMax do
		local x = Grid.CellPosition(t.FloorMin, column).X
		block(parent, `Crust {column}`, Vector3.new(x - pitch.X / 2, top, back), Vector3.new(x + pitch.X / 2, top + CRUST, front), crust, Enum.Material.Ground)
	end
	block(parent, "Bedrock", Vector3.new(left - EDGE, bottom - BEDROCK, back), Vector3.new(right + EDGE, bottom, front), Color3.fromRGB(40, 34, 34), Enum.Material.Basalt)
	block(parent, "EdgeLeft", Vector3.new(left - EDGE, bottom, back), Vector3.new(left, top + CRUST, front), crust, Enum.Material.Slate)
	block(parent, "EdgeRight", Vector3.new(right, bottom, back), Vector3.new(right + EDGE, top + CRUST, front), crust, Enum.Material.Slate)
end

-- Sync -----------------------------------------------------------------------------------

local function folders(root: Instance): Folders
	local function child(name: string, className: string): Instance
		local found = root:FindFirstChild(name)
		if not found then
			found = Instance.new(className)
			found.Name = name
			if found:IsA("Model") then
				found.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			end
			found.Parent = root
		end
		return found :: Instance
	end
	return {
		Root = root,
		Frame = child("Frame", "Model") :: Model,
		Rock = child("Rock", "Model") :: Model,
		Dug = child("Dug", "Folder") :: Folder,
		Rooms = child("Rooms", "Folder") :: Folder,
	}
end

--[[
	Makes the world under `root` match `bunker`. With `dirty` (cell keys), only those cells
	and the units holding them are rebuilt (BunkerGrid passes the changed cells and their
	neighbours); without it, everything is.
]]
function BunkerKit.Sync(bunker: Bunker.Bunker, root: Instance, dirty: { [string]: boolean }?)
	local t = Grid.Tuning()
	local f = folders(root)
	if #f.Frame:GetChildren() == 0 then
		buildFrame(f.Frame)
	end

	local keys: { string } = {}
	if dirty then
		for key in dirty do
			table.insert(keys, key)
		end
	else
		for floor = t.FloorMin, t.FloorMax do
			for column = t.ColumnMin, t.ColumnMax do
				table.insert(keys, Grid.Key(floor, column))
			end
		end
	end

	local units: { [string]: boolean } = {}
	for _, key in keys do
		local floor, column = Grid.Parse(key)
		if not floor or not column or not Grid.OnGrid(floor, column) then
			continue
		end
		local rockBlock = f.Rock:FindFirstChild(key)
		if bunker:State(floor, column) == "Rock" then
			if not rockBlock then
				buildRock(floor, column, f.Rock)
			end
		else
			if rockBlock then
				rockBlock:Destroy()
			end
			local unit = bunker:UnitAt(floor, column)
			if unit then
				units[unit] = true
			end
		end
	end

	-- Models whose unit is gone or is being rebuilt
	for _, model in f.Rooms:GetChildren() do
		if units[model.Name] or bunker:Room(model.Name) == nil then
			model:Destroy()
		end
	end
	for _, model in f.Dug:GetChildren() do
		local floor, column = Grid.Parse(string.sub(model.Name, 3))
		local current = if floor and column then bunker:UnitAt(floor, column) else nil
		if units[model.Name] or current ~= model.Name then
			model:Destroy()
		end
	end

	for unit in units do
		local room = bunker:Room(unit)
		if room then
			buildRoom(bunker, room, f.Rooms)
		else
			local floor, column = Grid.Parse(string.sub(unit, 3))
			if floor and column then
				buildDug(floor, column, f.Dug)
			end
		end
	end
end

-- Counts parts under the bunker (DevTools).
function BunkerKit.PartCount(root: Instance): number
	local count = 0
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

return BunkerKit
