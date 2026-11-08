--!strict
--[[
	BunkerKit: builds the bunker's world from Rules.Bunker data (bible Section 6).

	It builds from the A1 art kit in ServerStorage.Assets (bible Section 19): the Kit_* shell
	pieces, Kit_Rock_<Band> and Kit_Dug_<Band>, Kit_Shaft_L<level>, Kit_BlastDoor_L<level>,
	Kit_Vent and Room_<Type>_L<level>, each copied to its cell with Grid.CellCFrame. A piece
	the place doesn't have falls back to the Prompt 4 graybox (plain parts with the same
	sizes), so the bunker always builds, even in a place without the art.

	workspace.Bunker
	  Frame     rock around the grid: a column each side, a row above floor 1, a row below 10
	  Rock      one model per Rock cell, named by its key ("3,-2"); alternate cells turned
	  Dug       one model per Dug cell, named by its graph node ("D:2,3")
	  Rooms     one model per room, named by its id ("R4")

	* Every unit streams as Persistent, so the Command View always has the whole bunker
	  (bible Section 23).
	* Every room has walls. A side wall gets a doorway when the cell beyond it is open
	  (rooms connect sideways through doorways in shared walls). Cells of one room have no
	  wall between them.
	* Front walls carry the FrontWall tag (every part of a front wall piece, and the front
	  face of a dug cell): solid while playing, hidden in the Command View (Prompt 7).
	* Furniture, the Blast Door set, the stair, vents, lamps and cave props carry the
	  CameraFade tag: the over-the-shoulder camera passes through them and fades them when
	  they hide the character (Prompt 5). Floors, walls, ceilings and rock stop the camera.
	* Stacked Shafts get a hole in the upper one's floor, a hole in the lower one's ceiling
	  and the stair in the lower one.
	* Each room has a Sockets part (invisible) with an Attachment per gameplay point its art
	  carries: WorkSpot1.., Bed1.., Seat1.., Core, Valve1.., FuseBox, Breaker, Tap, Bench,
	  Respawn, Door, SurfaceExit, Vent, Lift, Chute, Top, Bottom, Light1.. Numbered points
	  count up across the room's cells from left to right; an unnumbered point that repeats
	  gets its cell's number (Breaker, Breaker2). BunkerKit.Socket and .Sockets read them.
	* The Medbay holds the players' spawn on its respawn pad (Section 6).
	* Lights: two per room cell at the ceiling strip, a lantern per dug cell, the Reactor's
	  core glow and the Kitchen's pendants. Each carries the RoomLight tag and a Unit
	  attribute (room id or dug node) for the power system (dark rooms, blackouts).
	* Each room gets one vent (a breach point, Section 10) in its first cell, except the
	  Shaft and the Blast Door (the door is the surface breach point).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Bunker = require(Shared.Rules.Bunker)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)

local BunkerKit = {}

BunkerKit.FRONT_WALL_TAG = "FrontWall"
BunkerKit.ROOM_LIGHT_TAG = "RoomLight"
BunkerKit.CAMERA_FADE_TAG = "CameraFade"

local ASSET_TAG = "Asset" -- marks the source models in ServerStorage.Assets; copies drop it
local HALF_TURN = CFrame.Angles(0, math.pi, 0)

-- Graybox (Prompt 4) ---------------------------------------------------------------------

local DOOR_WIDTH, DOOR_HEIGHT = 8, 10 -- the kit's doorway
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

-- Art lights ---------------------------------------------------------------------------------

type LightSpec = { Range: number, Brightness: number, Color: Color3 }

local CEILING_LIGHT: LightSpec = { Range = 18, Brightness = 1, Color = Color3.fromRGB(255, 228, 188) }
local DUG_LIGHTS: { [string]: LightSpec } = {
	Mines = { Range = 20, Brightness = 0.9, Color = Color3.fromRGB(255, 196, 120) },
	FloodedCaverns = { Range = 22, Brightness = 0.8, Color = Color3.fromRGB(140, 200, 210) },
	CrystalHollows = { Range = 22, Brightness = 1, Color = Color3.fromHex("8FE3E0") },
	SourceChamber = { Range = 22, Brightness = 1, Color = Color3.fromHex("7CFF9B") },
}
-- Rooms whose own Light sockets are real fixtures (the rest light from the ceiling kit).
local ACCENT_LIGHTS: { [string]: LightSpec } = {
	ReactorCore = { Range = 16, Brightness = 2, Color = Color3.fromHex("8FE3E0") },
	Kitchen = { Range = 12, Brightness = 0.8, Color = Color3.fromRGB(255, 214, 160) },
}
local NO_VENT: { [string]: boolean } = { Shaft = true, BlastDoor = true }

type Folders = { Root: Instance, Frame: Model, Rock: Model, Dug: Folder, Rooms: Folder }
type Socket = { Name: string, CFrame: CFrame }
type Holder = { Part: BasePart, Counters: { [string]: number }, Taken: { [string]: boolean } }

-- Parts --------------------------------------------------------------------------------------

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

-- The camera passes through this (and fades it when it hides the character).
local function fadeable(item: Instance)
	CollectionService:AddTag(item, BunkerKit.CAMERA_FADE_TAG)
end

local function newModel(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	return model
end

local function addLight(parent: Instance, spec: LightSpec, unit: string)
	local light = Instance.new("PointLight")
	light.Range = spec.Range
	light.Brightness = spec.Brightness
	light.Color = spec.Color
	light.Shadows = false
	light:SetAttribute("Unit", unit)
	CollectionService:AddTag(light, BunkerKit.ROOM_LIGHT_TAG)
	light.Parent = parent
end

local function lamp(parent: Instance, cell: Vector3, bright: boolean, unit: string)
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
		fadeable(part)
		addLight(part, {
			Range = if bright then 30 else 18,
			Brightness = if bright then 1.4 else 0.6,
			Color = LAMP_COLOR,
		}, unit)
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

-- Art ----------------------------------------------------------------------------------------

local function art(category: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild(category) else nil
	local found = if folder then folder:FindFirstChild(name) else nil
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Has this place got the art kit? Without it the bunker is all graybox.
function BunkerKit.HasArt(): boolean
	return art("Kit", "Kit_Floor") ~= nil
end

-- A copy of an art model with its pivot at `at`.
local function place(source: Model, name: string, parent: Instance, at: CFrame, persistent: boolean?): Model
	local copy = source:Clone()
	copy.Name = name
	CollectionService:RemoveTag(copy, ASSET_TAG)
	if persistent then
		copy.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	copy:PivotTo(at)
	copy.Parent = parent
	return copy
end

local function piece(name: string, label_: string, parent: Instance, at: CFrame): Model?
	local source = art("Kit", name)
	return if source then place(source, label_, parent, at) else nil
end

-- "WorkSpot12" -> "WorkSpot", 12; "Core" -> "Core", nil.
local function splitName(name: string): (string, number?)
	local base, digits = string.match(name, "^(.-)(%d+)$")
	if base and base ~= "" then
		return base, tonumber(digits)
	end
	return name, nil
end

-- A placed copy's sockets (its Socket_<name> attributes, in the model's own space) in the
-- world, sorted by name and then number.
local function socketsOf(copy: Model): { Socket }
	local list: { Socket } = {}
	local pivot = copy:GetPivot()
	for key, value in copy:GetAttributes() do
		local name = string.match(key, "^Socket_(.+)$")
		if name and typeof(value) == "CFrame" then
			table.insert(list, { Name = name, CFrame = pivot * value })
		end
	end
	table.sort(list, function(a: Socket, b: Socket): boolean
		local baseA, numberA = splitName(a.Name)
		local baseB, numberB = splitName(b.Name)
		if baseA ~= baseB then
			return baseA < baseB
		end
		return (numberA or 0) < (numberB or 0)
	end)
	return list
end

local function attach(part: BasePart, name: string, at: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = part.CFrame:ToObjectSpace(at)
	attachment.Parent = part
	return attachment
end

local function newHolder(model: Model, at: Vector3): Holder
	local part = Instance.new("Part")
	part.Name = "Sockets"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(at)
	part.Parent = model
	return { Part = part, Counters = {}, Taken = {} }
end

-- Adds a gameplay point to a room, numbered within the room (see the header).
local function addSocket(holder: Holder, name: string, at: CFrame, cellIndex: number): Attachment
	local base, number = splitName(name)
	local final = name
	if number then
		holder.Counters[base] = (holder.Counters[base] or 0) + 1
		final = base .. holder.Counters[base]
	elseif holder.Taken[name] then
		final = name .. cellIndex
	end
	holder.Taken[final] = true
	return attach(holder.Part, final, at)
end

-- Every socket of a placed copy into the room's holder; returns the new attachments.
local function collect(holder: Holder, copy: Model, cellIndex: number): { Attachment }
	local made = {}
	for _, socket in socketsOf(copy) do
		table.insert(made, addSocket(holder, socket.Name, socket.CFrame, cellIndex))
	end
	return made
end

local function tagFront(model: Model, whole: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and (whole or item:GetAttribute("Role") == "FrontWall") then
			CollectionService:AddTag(item, BunkerKit.FRONT_WALL_TAG)
		end
	end
end

-- The ceiling piece's two lamps, on its light strip.
local function ceilingLights(copy: Model, unit: string)
	local strip = copy:FindFirstChild("CeilingLight")
	if not (strip and strip:IsA("BasePart")) then
		return
	end
	for _, socket in socketsOf(copy) do
		if string.match(socket.Name, "^Light%d*$") then
			addLight(attach(strip, socket.Name, socket.CFrame), CEILING_LIGHT, unit)
		end
	end
end

-- Rooms: shells ------------------------------------------------------------------------------

type Shape = { ShaftBelow: boolean, ShaftAbove: boolean, LeftOpen: boolean, RightOpen: boolean }

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

-- Inside a room of several cells the ceiling pieces (32 wide) leave the 2-stud strip over
-- the wall line between cells open; a steel beam closes it.
local SEAM_COLOR = Color3.fromHex("8D969D") -- palette: steel
local function ceilingSeam(model: Model, floor: number, column: number)
	local t = Grid.Tuning()
	local cell = Grid.CellPosition(floor, column)
	local x = cell.X - t.CellWidth / 2 - t.WallThickness
	local top = cell.Y + t.CellHeight
	local beam = block(
		model,
		"CeilingSeam",
		Vector3.new(x - t.WallThickness, top - 1.5, cell.Z - t.CellDepth / 2),
		Vector3.new(x + t.WallThickness, top, cell.Z + t.CellDepth / 2),
		SEAM_COLOR,
		Enum.Material.SmoothPlastic
	)
	if beam then
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
	end
end

-- The art shell: per cell a floor, a ceiling with its lamps, a back and a front wall, and
-- side walls at the room's two ends (the left one is the right-hand piece turned around).
local function shellArt(model: Model, room: Bunker.Room, shape: Shape)
	for offset = 0, room.Span - 1 do
		local column = room.Column + offset
		local key = Grid.Key(room.Floor, column)
		local at = Grid.CellCFrame(room.Floor, column)
		local floor = piece(if shape.ShaftBelow then "Kit_FloorHole" else "Kit_Floor", `Floor {key}`, model, at)
		local rail = if floor then floor:FindFirstChild("HoleRail") else nil
		if rail then
			fadeable(rail)
		end
		local ceiling = piece(if shape.ShaftAbove then "Kit_CeilingHole" else "Kit_Ceiling", `Ceiling {key}`, model, at)
		if ceiling then
			ceilingLights(ceiling, room.Id)
		end
		piece("Kit_WallBack", `WallBack {key}`, model, at)
		local front = piece("Kit_WallFront", `WallFront {key}`, model, at)
		if front then
			tagFront(front, true)
		end
		if offset == 0 then
			piece(if shape.LeftOpen then "Kit_WallSideDoor" else "Kit_WallSide", `WallLeft {key}`, model, at * HALF_TURN)
		else
			ceilingSeam(model, room.Floor, column)
		end
		if offset == room.Span - 1 then
			piece(if shape.RightOpen then "Kit_WallSideDoor" else "Kit_WallSide", `WallRight {key}`, model, at)
		end
	end
end

-- The graybox shell (Prompt 4): slabs, walls with doorways, a lamp per cell and a label.
local function shellGraybox(model: Model, room: Bunker.Room, info: { [string]: any }, shape: Shape)
	local t = Grid.Tuning()
	local W, H, D, T, S = t.CellWidth, t.CellHeight, t.CellDepth, t.WallThickness, t.SlabThickness
	local first = Grid.CellPosition(room.Floor, room.Column)
	local last = Grid.CellPosition(room.Floor, room.Column + room.Span - 1)
	local y0, z0 = first.Y, first.Z
	local xL, xR = first.X - W / 2 - T, last.X + W / 2 + T
	local color = ROOM_COLORS[room.Type] or DEFAULT_ROOM_COLOR
	local hole = {
		MinX = first.X + SHAFT_HOLE.FromX,
		MaxX = first.X + W / 2,
		MinZ = z0 - D / 2,
		MaxZ = z0 - D / 2 + SHAFT_HOLE.Depth,
	}

	slab(model, "Floor", Vector3.new(xL, y0 - S, z0 - D / 2 - T), Vector3.new(xR, y0, z0 + D / 2 + T), if shape.ShaftBelow then hole else nil, color, Enum.Material.SmoothPlastic)
	slab(model, "Ceiling", Vector3.new(xL + T, y0 + H - 0.5, z0 - D / 2), Vector3.new(xR - T, y0 + H, z0 + D / 2), if shape.ShaftAbove then hole else nil, CEILING_COLOR, Enum.Material.SmoothPlastic)
	local back = block(model, "BackWall", Vector3.new(xL, y0, z0 - D / 2 - T), Vector3.new(xR, y0 + H, z0 - D / 2), WALL_COLOR, Enum.Material.SmoothPlastic)
	local front = block(model, "FrontWall", Vector3.new(xL, y0, z0 + D / 2), Vector3.new(xR, y0 + H, z0 + D / 2 + T), FRONT_COLOR, Enum.Material.SmoothPlastic)
	if front then
		CollectionService:AddTag(front, BunkerKit.FRONT_WALL_TAG)
	end
	sideWall(model, "SideWallLeft", xL, xL + T, y0, z0, shape.LeftOpen)
	sideWall(model, "SideWallRight", xR - T, xR, y0, z0, shape.RightOpen)
	for offset = 0, room.Span - 1 do
		lamp(model, Grid.CellPosition(room.Floor, room.Column + offset), true, room.Id)
	end
	if back then
		label(back, `{info.Name}  L{room.Level}  ({room.Id})`)
	end
end

-- Rooms: insides -----------------------------------------------------------------------------

-- The graybox stair up from a Shaft to the Shaft above: a plank along the back, rising to
-- the right.
local function grayboxStair(parent: Instance, cell: Vector3)
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
	fadeable(plank)
	plank.Parent = parent
end

-- Graybox stand-ins for a room's furniture when its art is missing, with the same sockets.
local function grayboxInterior(model: Model, room: Bunker.Room, info: { [string]: any }, centre: Vector3, holder: Holder)
	local t = Grid.Tuning()
	local y0, z0 = centre.Y, centre.Z
	local backZ = z0 - t.CellDepth / 2
	if room.Type == "ReactorCore" then
		local base = block(model, "CoreBase", Vector3.new(centre.X - 4, y0, z0 - 8), Vector3.new(centre.X + 4, y0 + 1, z0), Color3.fromRGB(60, 64, 70), Enum.Material.DiamondPlate)
		if base then
			fadeable(base)
		end
		local core = Instance.new("Part")
		core.Name = "Core"
		core.Anchored = true
		core.Shape = Enum.PartType.Cylinder
		core.Size = Vector3.new(10, 5, 5)
		core.CFrame = CFrame.new(centre.X, y0 + 6, z0 - 4) * CFrame.Angles(0, 0, math.rad(90))
		core.Material = Enum.Material.Neon
		core.Color = Color3.fromRGB(90, 200, 230)
		fadeable(core)
		core.Parent = model
		addSocket(holder, "Core", CFrame.new(centre.X, y0, z0 - 4), 1)
	elseif room.Type == "BlastDoor" then
		local door = Instance.new("Part")
		door.Name = "Door"
		door.Anchored = true
		door.Shape = Enum.PartType.Cylinder
		door.Size = Vector3.new(1, 13, 13)
		door.CFrame = CFrame.new(centre.X, y0 + 7, backZ + 0.5) * CFrame.Angles(0, math.rad(90), 0)
		door.Material = Enum.Material.DiamondPlate
		door.Color = Color3.fromRGB(70, 74, 80)
		fadeable(door)
		door.Parent = model
		addSocket(holder, "Door", CFrame.new(centre.X, y0, backZ + 3), 1)
		addSocket(holder, "SurfaceExit", CFrame.new(centre.X, y0 + t.CellHeight, backZ + 3), 1)
	elseif room.Type == "Medbay" then
		addSocket(holder, "Respawn", CFrame.new(centre.X, y0, z0 + 6), 1)
	elseif room.Type == "Quarters" and info.Beds then
		local beds = info.Beds[room.Level]
		for offset = 0, room.Span - 1 do
			local cell = Grid.CellPosition(room.Floor, room.Column + offset)
			local pitch = (t.CellWidth - 2) / beds
			for index = 1, beds do
				local x = cell.X - t.CellWidth / 2 + 1 + pitch * (index - 0.5)
				local bed = block(model, "Bed", Vector3.new(x - 1.4, y0, backZ + 0.5), Vector3.new(x + 1.4, y0 + 1.6, backZ + 7), Color3.fromRGB(120, 104, 160), Enum.Material.Fabric)
				if bed then
					bed:SetAttribute("Bed", offset * beds + index)
					fadeable(bed)
				end
				addSocket(holder, `Bed{index}`, CFrame.new(x, y0 + 1.6, backZ + 3.75), offset + 1)
			end
		end
	end
end

-- A room's insides: the Blast Door set, the Shaft stair, or its furniture per cell, then
-- its vent. Missing art falls back to the graybox. Returns whether the furniture is art.
local function interior(model: Model, room: Bunker.Room, info: { [string]: any }, shape: Shape, centre: Vector3, holder: Holder): boolean
	local first = Grid.CellPosition(room.Floor, room.Column)
	local isArt = false
	if room.Type == "BlastDoor" then
		local source = art("Kit", `Kit_BlastDoor_L{room.Level}`)
		if source then
			local set = place(source, "BlastDoor", model, CFrame.new(centre) * HALF_TURN)
			fadeable(set)
			collect(holder, set, 1)
			isArt = true
		else
			grayboxInterior(model, room, info, centre, holder)
		end
	elseif room.Type == "Shaft" then
		isArt = BunkerKit.HasArt()
		if shape.ShaftAbove then
			local source = art("Kit", `Kit_Shaft_L{room.Level}`)
			if source then
				local stair = place(source, "Stair", model, Grid.CellCFrame(room.Floor, room.Column))
				fadeable(stair)
				collect(holder, stair, 1)
			else
				grayboxStair(model, first)
				isArt = false
			end
		end
	else
		local source = art("Rooms", `Room_{room.Type}_L{room.Level}`)
		if source then
			local accent = ACCENT_LIGHTS[room.Type]
			for offset = 0, room.Span - 1 do
				local column = room.Column + offset
				local copy = place(source, `Interior {Grid.Key(room.Floor, column)}`, model, Grid.CellCFrame(room.Floor, column))
				fadeable(copy)
				for _, attachment in collect(holder, copy, offset + 1) do
					if accent and string.match(attachment.Name, "^Light%d*$") then
						addLight(attachment, accent, room.Id)
					end
				end
			end
			isArt = true
		else
			grayboxInterior(model, room, info, centre, holder)
		end
	end
	if not NO_VENT[room.Type] then
		local vent = piece("Kit_Vent", "Vent", model, Grid.CellCFrame(room.Floor, room.Column))
		if vent then
			fadeable(vent)
			collect(holder, vent, 1)
		end
	end
	return isArt
end

-- The players' spawn on the Medbay's Respawn point: invisible on the art pad, a red pad in
-- the graybox.
local function medbaySpawn(model: Model, holder: Holder, visible: boolean)
	local respawn = holder.Part:FindFirstChild("Respawn")
	if not (respawn and respawn:IsA("Attachment")) then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MedbaySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(6, if visible then 1 else 0.2, 6)
	spawn.CFrame = CFrame.new(respawn.WorldPosition + Vector3.new(0, spawn.Size.Y / 2, 0))
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(196, 60, 60)
	if not visible then
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.CastShadow = false
	end
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end
	spawn.Parent = model
end

-- Units --------------------------------------------------------------------------------------

local function buildRoom(bunker: Bunker.Bunker, room: Bunker.Room, parent: Instance): Model
	local info = Config.Get("Rooms", room.Type)
	local first = Grid.CellPosition(room.Floor, room.Column)
	local last = Grid.CellPosition(room.Floor, room.Column + room.Span - 1)
	local centre = (first + last) / 2

	local model = newModel(room.Id, parent)
	model:SetAttribute("RoomId", room.Id)
	model:SetAttribute("RoomType", room.Type)
	model:SetAttribute("Floor", room.Floor)
	model:SetAttribute("Column", room.Column)
	model:SetAttribute("Span", room.Span)
	model:SetAttribute("Level", room.Level)

	local shape: Shape = {
		ShaftBelow = room.Type == "Shaft" and bunker:IsShaft(room.Floor + 1, room.Column),
		ShaftAbove = room.Type == "Shaft" and bunker:IsShaft(room.Floor - 1, room.Column),
		LeftOpen = bunker:IsOpen(room.Floor, room.Column - 1),
		RightOpen = bunker:IsOpen(room.Floor, room.Column + room.Span),
	}
	local holder = newHolder(model, centre)
	local artShell = BunkerKit.HasArt()
	if artShell then
		shellArt(model, room, shape)
	else
		shellGraybox(model, room, info, shape)
	end
	local artInside = interior(model, room, info, shape, centre, holder)
	medbaySpawn(model, holder, not artInside)
	model:SetAttribute("Art", artShell and artInside)
	return model
end

local function buildDug(floor: number, column: number, parent: Instance): Model
	local t = Grid.Tuning()
	local band = Grid.BandOf(floor)
	local name = "D:" .. Grid.Key(floor, column)
	local source = art("Kit", `Kit_Dug_{band.Id}`)
	if source then
		local model = place(source, name, parent, Grid.CellCFrame(floor, column), true)
		model:SetAttribute("Floor", floor)
		model:SetAttribute("Column", column)
		model:SetAttribute("Band", band.Id)
		model:SetAttribute("Art", true)
		tagFront(model, false)
		for _, item in model:GetChildren() do
			if item:IsA("BasePart") and item.Name ~= "Floor" and item.Name ~= "BackRock" and item.Name ~= "FrontWall" then
				fadeable(item) -- timber, carts, pipes and other cave props
			end
		end
		local host = model:FindFirstChild("Floor")
		if host and host:IsA("BasePart") then
			for _, socket in socketsOf(model) do
				if socket.Name == "Light" then
					addLight(attach(host, "Light", socket.CFrame), DUG_LIGHTS[band.Id] or DUG_LIGHTS.Mines, name)
				end
			end
		end
		return model
	end

	local W, H, D, T, S = t.CellWidth, t.CellHeight, t.CellDepth, t.WallThickness, t.SlabThickness
	local cell = Grid.CellPosition(floor, column)
	local rock = BAND_COLORS[band.Id] or BAND_COLORS.Mines
	local model = newModel(name, parent)
	model:SetAttribute("Floor", floor)
	model:SetAttribute("Column", column)
	local x0, x1 = cell.X - W / 2 - T, cell.X + W / 2 + T
	block(model, "Floor", Vector3.new(x0, cell.Y - S, cell.Z - D / 2 - T), Vector3.new(x1, cell.Y, cell.Z + D / 2 + T), rock:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Ground)
	block(model, "BackRock", Vector3.new(x0, cell.Y, cell.Z - D / 2 - T), Vector3.new(x1, cell.Y + H, cell.Z - D / 2), rock, Enum.Material.Slate)
	local front = block(model, "FrontWall", Vector3.new(x0, cell.Y, cell.Z + D / 2), Vector3.new(x1, cell.Y + H, cell.Z + D / 2 + T), rock, Enum.Material.Slate)
	if front then
		CollectionService:AddTag(front, BunkerKit.FRONT_WALL_TAG)
	end
	lamp(model, cell, false, name)
	return model
end

-- A rock cell's art, turned half a turn on alternate cells so the face doesn't repeat.
local function rockArt(bandId: string, name: string, parent: Instance, floor: number, column: number): Model?
	local source = art("Kit", `Kit_Rock_{bandId}`)
	if not source then
		return nil
	end
	local at = Grid.CellCFrame(floor, column)
	if (floor + column) % 2 == 1 then
		at *= HALF_TURN
	end
	local model = place(source, name, parent, at)
	model:SetAttribute("Floor", floor)
	model:SetAttribute("Column", column)
	model:SetAttribute("Band", bandId)
	return model
end

local function buildRock(floor: number, column: number, parent: Instance)
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local band = Grid.BandOf(floor)
	local key = Grid.Key(floor, column)
	if rockArt(band.Id, key, parent, floor, column) then
		return
	end
	local cell = Grid.CellPosition(floor, column)
	local part = block(
		parent,
		key,
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
	if art("Kit", "Kit_Rock_Mines") then
		-- A ring of rock cells: the Mines above floor 1, the Source's rock under floor 10, and
		-- each floor's band at the grid's two sides.
		for floor = t.FloorMin - 1, t.FloorMax + 1 do
			local outside = floor < t.FloorMin or floor > t.FloorMax
			local bandId = if floor < t.FloorMin then "Mines" elseif floor > t.FloorMax then "SourceChamber" else Grid.BandOf(floor).Id
			for column = t.ColumnMin - 1, t.ColumnMax + 1 do
				if outside or column < t.ColumnMin or column > t.ColumnMax then
					rockArt(bandId, `Frame {Grid.Key(floor, column)}`, parent, floor, column)
				end
			end
		end
		return
	end

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

-- Sync ---------------------------------------------------------------------------------------

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
		local rock = f.Rock:FindFirstChild(key)
		if bunker:State(floor, column) == "Rock" then
			if not rock then
				buildRock(floor, column, f.Rock)
			end
		else
			if rock then
				rock:Destroy()
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

-- Queries ------------------------------------------------------------------------------------

-- A room's gameplay point (an Attachment on its Sockets part), in the world.
function BunkerKit.Socket(model: Instance, name: string): CFrame?
	local holder = model:FindFirstChild("Sockets")
	local attachment = if holder then holder:FindFirstChild(name) else nil
	if attachment and attachment:IsA("Attachment") then
		return attachment.WorldCFrame
	end
	return nil
end

-- A room's gameplay points whose names match a Lua pattern ("^WorkSpot%d+$"), or all.
function BunkerKit.Sockets(model: Instance, pattern: string?): { [string]: CFrame }
	local found: { [string]: CFrame } = {}
	local holder = model:FindFirstChild("Sockets")
	if holder then
		for _, item in holder:GetChildren() do
			if item:IsA("Attachment") and (pattern == nil or string.match(item.Name, pattern)) then
				found[item.Name] = item.WorldCFrame
			end
		end
	end
	return found
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
