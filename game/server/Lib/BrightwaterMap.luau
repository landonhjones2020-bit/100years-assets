--!strict
--[[
	BrightwaterMap: builds Brightwater Ruins, the surface map, as workspace.Surface in the Run place
	(bible Sections 12 and 23; Prompt 16). It is a tool run in Studio, never by the game:

		require(game.ServerScriptService.Lib.BrightwaterMap).Build()   -- execute_luau, Edit

	* The town sits GROUND studs up, high above the bunker (Section 23; the bunker's floor 1 is at
	  -120, and the place's old Baseplate and A0 showroom stay below at 0).
	* Each place comes from ServerStorage.Assets.Surface.<Asset> when its A5 art exists, else from a
	  graybox stand-in. Containers, survivor spots and find spots sit at the art's sockets
	  (Socket_Container1.., Socket_Survivor1.., Socket_BigFind) or the stand-in's, at least 8 studs
	  apart (the nearest prompt per key wins).
	* Rebuilding keeps every place where it was moved in Studio (its current pivot) and leaves
	  workspace.Surface.Decor alone: Landon's own dressing goes there.
	* SurfaceService reads the result (markers ElevatorExit, ElevatorCall, SurvivorSpot, BigFindSpot,
	  SpawnPoint; containers with Container and Location attributes; gates with MinEra).
	* The layout is shared with the lobby's clean town (Prompt 21): -Z is north, Main Street runs
	  along X at Z = 0, the bunker entrance is in the north hill.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BrightwaterMap = {}

BrightwaterMap.GROUND = 200

local GROUND = BrightwaterMap.GROUND
local function W(x: number, y: number, z: number): CFrame
	return CFrame.new(x, GROUND + y, z)
end


local C = {
	ash = Color3.fromRGB(122, 112, 104), road = Color3.fromRGB(58, 56, 60), walk = Color3.fromRGB(150, 144, 136),
	line = Color3.fromRGB(196, 172, 96), hill = Color3.fromRGB(104, 92, 84), wall = Color3.fromRGB(176, 162, 146),
	trim = Color3.fromRGB(47, 111, 115), rust = Color3.fromRGB(150, 76, 48), dark = Color3.fromRGB(70, 66, 64),
	cream = Color3.fromRGB(242, 230, 201), steel = Color3.fromRGB(120, 124, 130), wood = Color3.fromRGB(116, 86, 62),
	sand = Color3.fromRGB(176, 156, 112), signal = Color3.fromRGB(232, 116, 59), olive = Color3.fromRGB(96, 104, 70),
}

-- The layout: X and Z of each place's pivot (its ground, bottom centre), its yaw (0: its front
-- faces -Z, north; 180: south, towards Main Street from the north side) and its stand-in.
local PLACES = {
	{ Id = "Entrance", Asset = "Bldg_BunkerEntrance", At = { 0, -205 }, Yaw = 180, Kind = "Entrance" },
	{ Id = "Diner", Location = "Diner", Asset = "Bldg_Diner", At = { -100, -46 }, Yaw = 180, Kind = "Store", W = 44, D = 30 },
	{ Id = "HardwareStore", Location = "HardwareStore", Asset = "Bldg_HardwareStore", At = { 60, -48 }, Yaw = 180, Kind = "Store", W = 40, D = 32 },
	{ Id = "GasStation", Location = "GasStation", Asset = "Bldg_GasStation", At = { 190, -52 }, Yaw = 180, Kind = "Station", W = 56, D = 44 },
	{ Id = "Grocery", Location = "Grocery", Asset = "Bldg_Grocery", At = { -170, 50 }, Yaw = 0, Kind = "Store", W = 50, D = 36 },
	{ Id = "Showroom", Location = "Showroom", Asset = "Bldg_Showroom", At = { -40, 54 }, Yaw = 0, Kind = "Store", W = 54, D = 38 },
	{ Id = "Motel", Location = "Motel", Asset = "Bldg_Motel", At = { 120, 60 }, Yaw = 0, Kind = "Motel", W = 76, D = 26 },
	{ Id = "RadioTower", Location = "RadioTower", Asset = "Bldg_RadioTower", At = { 205, -168 }, Yaw = 200, Kind = "Radio", W = 26, D = 22 },
	{ Id = "WaterTower", Location = "WaterTower", Asset = "Bldg_WaterTower", At = { -215, -150 }, Yaw = 160, Kind = "Tower", W = 26, D = 22 },
	{ Id = "RailYard", Location = "RailYard", Asset = "Bldg_RailYard", At = { -10, 168 }, Yaw = 0, Kind = "Train", W = 150, D = 30 },
	{ Id = "Checkpoint", Location = "Checkpoint", Asset = "Bldg_Checkpoint", At = { 272, 0 }, Yaw = 90, Kind = "Checkpoint", W = 50, D = 44 },
}
-- What the art's sign boards (parts whose Role is Sign) say: the location's name unless set here,
-- and the ink when the board is dark.
local INK = { navy = Color3.fromRGB(27, 42, 58), cream = Color3.fromRGB(242, 230, 201) }
local SIGN_TEXT = { Entrance = "Steadfast Shelter Co.", WaterTower = "Brightwater" }
local SIGN_INK = { WaterTower = INK.cream }
-- Wrecks and clutter: { asset, x, z, yaw }
local DECOR = {
	{ "Prop_CarWreck_A", -235, 9, 80 }, { "Prop_CarWreck_B", -62, -9, 262 }, { "Prop_CarWreck_A", 38, 10, 95 },
	{ "Prop_CarWreck_B", 150, -8, 275 }, { "Prop_CarWreck_A", 236, 9, 70 }, { "Prop_CarWreck_B", 9, -120, 10 },
	{ "Prop_BurntTree", -262, -96, 0 }, { "Prop_BurntTree", -140, -118, 40 }, { "Prop_BurntTree", -42, -112, 90 },
	{ "Prop_BurntTree", 94, -114, 130 }, { "Prop_BurntTree", 150, 118, 200 }, { "Prop_BurntTree", -252, 112, 250 },
	{ "Prop_BurntTree", 252, 150, 300 }, { "Prop_BurntTree", -110, 120, 20 }, { "Prop_BurntTree", 40, -150, 60 },
	{ "Prop_Debris", -128, -24, 0 }, { "Prop_Debris", 92, -26, 70 }, { "Prop_Debris", -200, 26, 140 },
	{ "Prop_Debris", 12, 30, 210 }, { "Prop_Debris", 168, 30, 280 }, { "Prop_Debris", -30, -150, 30 },
	{ "Prop_Debris", 70, 120, 100 }, { "Prop_Debris", -150, 140, 170 },
}
-- Creature spawn points round the edge, all on open ground (the north hill's face is at Z = -212:
-- points behind it were buried in the hill, and creatures spawned there fell out of the town)
local SPAWNS = {
	{ -285, -196 }, { -285, -60 }, { -285, 80 }, { -285, 205 }, { -120, 212 }, { 60, 212 }, { 220, 208 },
	{ 288, 120 }, { 288, -100 }, { 252, -196 }, { 100, -196 }, { -90, -196 }, { -200, -60 }, { 110, -125 },
	{ -70, 112 }, { 170, 112 }, { -250, -165 }, { 240, -40 },
}

-- Builds (or rebuilds) workspace.Surface; returns a summary.
function BrightwaterMap.Build(): string
	local assets = ServerStorage:FindFirstChild("Assets")
	local ART: any = assets and assets:FindFirstChild("Surface")
	local PROPS: any = assets and assets:FindFirstChild("Props")
	local holder: any = workspace:FindFirstChild("Surface")
	local moved: { [string]: CFrame } = {}
	local decor: any = nil
	if holder then
		for _, child in holder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("PlaceId") then
				moved[child:GetAttribute("PlaceId")] = child:GetPivot()
			end
		end
		decor = holder:FindFirstChild("Decor")
		if decor then
			decor.Parent = nil
		end
		holder:Destroy()
	end
	holder = Instance.new("Model")
	holder.Name = "Surface"
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Default

	local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?): any
		local p: any = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for k, v in props or {} do
			p[k] = v
		end
		p.Parent = parent
		return p
	end

	local function marker(parent: Instance, name: string, cframe: CFrame, location: string?): any
		local m = part(parent, name, Vector3.new(1, 1, 1), cframe, C.signal, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		if location then
			m:SetAttribute("Location", location)
		end
		return m
	end

	-- The ground ---------------------------------------------------------------------------------------
	local ground = Instance.new("Model")
	ground.Name = "Ground"
	ground.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	part(ground, "Ash", Vector3.new(640, 2, 520), W(0, -1, -15), C.ash)
	part(ground, "MainStreet", Vector3.new(600, 0.2, 28), W(0, 0.1, 0), C.road, { CanCollide = false })
	for x = -280, 280, 40 do
		part(ground, "Line", Vector3.new(14, 0.22, 0.8), W(x, 0.11, 0), C.line, { CanCollide = false })
	end
	part(ground, "WalkNorth", Vector3.new(600, 0.3, 8), W(0, 0.15, -18), C.walk)
	part(ground, "WalkSouth", Vector3.new(600, 0.3, 8), W(0, 0.15, 18), C.walk)
	part(ground, "HillLane", Vector3.new(16, 0.2, 172), W(0, 0.1, -108), C.road, { CanCollide = false })
	part(ground, "RailBed", Vector3.new(600, 0.4, 16), W(0, 0.2, 168), C.dark)
	for _, z in { 164, 172 } do
		part(ground, "Rail", Vector3.new(600, 0.5, 0.6), W(0, 0.6, z), C.steel)
	end
	-- the north hill the bunker is dug into, and low hills round the edge
	part(ground, "HillNorth", Vector3.new(660, 44, 80), W(0, 18, -252), C.hill)
	for _, h in { { -330, -15, 40, 540 }, { 330, -15, 40, 540 }, { 0, 252, 700, 40 } } do
		part(ground, "HillEdge", Vector3.new(h[3], 26, h[4]), W(h[1], 6, h[2]), C.hill)
	end
	for _, w in { { -305, -15, 2, 540 }, { 305, -15, 2, 540 }, { 0, 232, 640, 2 }, { 0, -245, 640, 2 } } do
		part(ground, "Boundary", Vector3.new(w[3], 80, w[4]), W(w[1], 40, w[2]), C.hill, { Transparency = 1, CanQuery = false })
	end
	ground.Parent = holder

	-- Stand-ins -------------------------------------------------------------------------------------------
	-- Each returns sockets in the place's own space (its front faces -Z): Container1.., Survivor1..,
	-- BigFind, and for the entrance Exit and Call.
	local function walls(m: any, w: number, d: number, h: number, color: Color3, door: number?)
		part(m, "Floor", Vector3.new(w, 0.6, d), CFrame.new(0, 0.3, 0), C.dark)
		part(m, "Back", Vector3.new(w, h, 1), CFrame.new(0, h / 2, d / 2), color)
		part(m, "Left", Vector3.new(1, h, d), CFrame.new(-w / 2, h / 2, 0), color)
		part(m, "Right", Vector3.new(1, h * 0.7, d), CFrame.new(w / 2, h * 0.35, 0), color) -- ruined
		local gap = door or 10
		local side = (w - gap) / 2
		part(m, "FrontL", Vector3.new(side, h, 1), CFrame.new(-w / 2 + side / 2, h / 2, -d / 2), color)
		part(m, "FrontR", Vector3.new(side, h * 0.5, 1), CFrame.new(w / 2 - side / 2, h * 0.25, -d / 2), color)
		part(m, "Trim", Vector3.new(w + 1, 1.2, 1.4), CFrame.new(0, h, -d / 2), C.trim)
		part(m, "Roof", Vector3.new(w * 0.55, 0.8, d), CFrame.new(-w * 0.22, h + 0.4, 0), C.dark)
	end

	-- Lettering on a sign board's front (-Z) face, lit by the scene like paint.
	local function letter(board: BasePart, text: string, ink: Color3?)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Lettering"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(board.Size.X * 40, board.Size.Y * 40)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.9, 0.8)
		label.Position = UDim2.fromScale(0.05, 0.1)
		label.BackgroundTransparency = 1
		label.Text = string.upper(text)
		label.TextScaled = true
		label.Font = Enum.Font.Oswald
		label.TextColor3 = ink or INK.navy
		label.Parent = gui
		gui.Parent = board
	end
	local function sign(m: Instance, text: string, at: CFrame, w: number)
		letter(part(m, "Sign", Vector3.new(w, 4, 0.6), at, C.cream), text)
	end

	local function backRow(n: number, w: number, d: number): { [string]: CFrame }
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			local x = -w / 2 + 4 + (w - 8) * (if n == 1 then 0.5 else (i - 1) / (n - 1))
			s["Container" .. i] = CFrame.new(x, 0.6, d / 2 - 2.5)
		end
		return s
	end

	local STAND: { [string]: (any, any, number) -> { [string]: CFrame } } = {}
	STAND.Store = function(m: any, p: any, n: number)
		walls(m, p.W, p.D, 14, C.wall, 12)
		sign(m, Config.Get("SurfaceLocations", p.Location).Name, CFrame.new(0, 16.5, -p.D / 2 - 0.4), math.min(p.W - 6, 30))
		local s = backRow(n, p.W, p.D)
		-- prompts at least 8 studs apart: the nearest one per key wins (Exclusivity OnePerButton)
		s.Survivor1 = CFrame.new(p.W / 2 - 5, 0.6, -p.D / 2 + 6)
		s.BigFind = CFrame.new(-p.W / 2 + 6, 0.6, -p.D / 2 + 7)
		return s
	end
	STAND.Station = function(m: any, p: any, n: number)
		part(m, "Slab", Vector3.new(p.W, 0.4, p.D), CFrame.new(0, 0.2, 0), C.walk)
		part(m, "Canopy", Vector3.new(p.W * 0.7, 1.2, 18), CFrame.new(-6, 15, -8), C.cream)
		for _, x in { -22, 10 } do
			part(m, "Post", Vector3.new(1.4, 15, 1.4), CFrame.new(x, 7.5, -8), C.steel)
			part(m, "Pump", Vector3.new(2.4, 5, 2), CFrame.new(x + 5, 2.7, -8), C.signal)
		end
		local shop: any = Instance.new("Model")
		shop.Name = "Shop"
		shop.Parent = m
		walls(shop, 22, 16, 12, C.wall, 8)
		shop.WorldPivot = CFrame.new()
		shop:PivotTo(CFrame.new(14, 0, 12))
		sign(m, "Gas", CFrame.new(-6, 17.2, -17.4), 12)
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			s["Container" .. i] = CFrame.new(6 + (i - 1) * 7, 0.6, 18)
		end
		s.Survivor1 = CFrame.new(8, 0.6, 7)
		s.BigFind = CFrame.new(-20, 0.4, 8)
		return s
	end
	STAND.Motel = function(m: any, p: any, n: number)
		walls(m, p.W, p.D, 12, C.wall, 0)
		m.FrontL:Destroy()
		m.FrontR:Destroy()
		local rooms = 6
		for i = 1, rooms - 1 do
			local x = -p.W / 2 + p.W / rooms * i
			part(m, "Divider", Vector3.new(1, 12, p.D - 6), CFrame.new(x, 6, 3), C.wall)
		end
		part(m, "Walkway", Vector3.new(p.W, 0.4, 6), CFrame.new(0, 0.2, -p.D / 2 - 3), C.walk)
		sign(m, "Motel", CFrame.new(-p.W / 2 + 8, 17, -p.D / 2 - 6), 14)
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			local x = -p.W / 2 + p.W / rooms * (i - 0.5)
			s["Container" .. i] = CFrame.new(x, 0.6, p.D / 2 - 2.5)
		end
		s.Survivor1 = CFrame.new(-p.W / 2 + p.W / rooms * 1.5, 0.6, 2)
		s.Survivor2 = CFrame.new(-p.W / 2 + p.W / rooms * 4.5, 0.6, 2)
		return s
	end
	local function shack(m: Instance, x: number, z: number, w: number, d: number)
		local hut: any = Instance.new("Model")
		hut.Name = "Shack"
		hut.Parent = m
		walls(hut, w, d, 10, C.wood, 6)
		hut.WorldPivot = CFrame.new()
		hut:PivotTo(CFrame.new(x, 0, z))
	end
	STAND.Tower = function(m: any, p: any, n: number)
		for _, xz in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
			part(m, "Leg", Vector3.new(1.4, 40, 1.4), CFrame.new(xz[1], 20, xz[2]), C.steel)
		end
		part(m, "Tank", Vector3.new(18, 12, 18), CFrame.new(0, 46, 0), C.cream, { Shape = Enum.PartType.Cylinder })
		m.Tank.CFrame = CFrame.new(0, 46, 0) * CFrame.Angles(0, 0, math.pi / 2)
		shack(m, 0, 16, 14, 10)
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			s["Container" .. i] = CFrame.new(-4 + (i - 1) * 8, 0.6, 19.5)
		end
		s.Survivor1 = CFrame.new(0, 0.6, 1)
		return s
	end
	STAND.Radio = function(m: any, p: any, n: number)
		for i = 0, 5 do
			part(m, "Mast", Vector3.new(3 - i * 0.3, 14, 3 - i * 0.3), CFrame.new(0, 7 + i * 14, -4), C.signal)
		end
		part(m, "Light", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 92, -4), Color3.fromRGB(255, 80, 60), { Material = Enum.Material.Neon })
		shack(m, 0, 8, 16, 11)
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			s["Container" .. i] = CFrame.new(-5 + (i - 1) * 5, 0.6, 11.5)
		end
		s.Survivor1 = CFrame.new(-10, 0.6, -3)
		s.BigFind = CFrame.new(10, 0.4, -6)
		return s
	end
	STAND.Train = function(m: any, p: any, n: number)
		local cars = { { "Loco", -48, 34, C.dark }, { "Boxcar", -8, 34, C.rust }, { "Boxcar2", 34, 34, C.trim } }
		local s: { [string]: CFrame } = {}
		local i = 0
		for c, car in cars do
			local body: any = Instance.new("Model")
			body.Name = car[1]
			body.Parent = m
			part(body, "Floor", Vector3.new(car[3], 1, 10), CFrame.new(car[2], 2.6, 0), C.dark)
			part(body, "Back", Vector3.new(car[3], 10, 1), CFrame.new(car[2], 7.6, 4.5), car[4])
			part(body, "Front", Vector3.new(car[3] * 0.4, 10, 1), CFrame.new(car[2] - car[3] * 0.3, 7.6, -4.5), car[4])
			part(body, "Roof", Vector3.new(car[3], 1, 10), CFrame.new(car[2], 13, 0), car[4])
			part(body, "Ramp", Vector3.new(5, 1, 6), CFrame.new(car[2] + 4, 1.2, -7) * CFrame.Angles(math.rad(-22), 0, 0), C.wood)
			for k = 1, 2 do
				i += 1
				if i <= n then
					s["Container" .. i] = CFrame.new(car[2] + (k == 1 and -8 or 8), 3.1, 2.4)
				end
			end
			if c == 2 then
				s.BigFind = CFrame.new(car[2], 3.1, -1.5)
			end
		end
		shack(m, -150, -26, 18, 12)
		s.Survivor1 = CFrame.new(-150, 0.6, -24)
		return s
	end
	STAND.Checkpoint = function(m: any, p: any, n: number)
		-- a sandbagged compound across the end of Main Street, its front (the gate) facing the town
		part(m, "Slab", Vector3.new(44, 0.4, 34), CFrame.new(0, 0.2, 13), C.walk)
		for _, side in { -22, 22 } do
			part(m, "Sandbags", Vector3.new(3, 6, 34), CFrame.new(side, 3, 13), C.sand)
		end
		part(m, "BackWall", Vector3.new(44, 8, 2), CFrame.new(0, 4, 30), C.sand)
		part(m, "Booth", Vector3.new(7, 9, 7), CFrame.new(-15, 4.5, 3), C.olive)
		part(m, "Tent", Vector3.new(16, 8, 12), CFrame.new(10, 4, 16), C.olive)
		local gate: any = Instance.new("Model")
		gate.Name = "Gate"
		gate:SetAttribute("MinEra", Config.Get("SurfaceLocations", "Checkpoint").MinEra)
		gate.Parent = m
		local bar = part(gate, "Barrier", Vector3.new(41, 10, 1.2), CFrame.new(0, 5, -4), C.signal)
		bar:SetAttribute("Barrier", true)
		sign(m, "Military Checkpoint", CFrame.new(0, 11.5, -4.8), 22)
		local s: { [string]: CFrame } = {}
		for i = 1, n do
			s["Container" .. i] = CFrame.new(-16 + (i - 1) * 32 / math.max(n - 1, 1), 0.6, 27)
		end
		s.Survivor1 = CFrame.new(16, 0.6, 8)
		s.BigFind = CFrame.new(-6, 0.4, 14)
		return s
	end
	STAND.Entrance = function(m: any, p: any, _n: number)
		part(m, "Headwall", Vector3.new(44, 22, 6), CFrame.new(0, 11, 3), C.walk)
		part(m, "DoorRing", Vector3.new(18, 18, 2), CFrame.new(0, 10, -0.5), C.steel)
		part(m, "Door", Vector3.new(14, 14, 1.2), CFrame.new(0, 8, -1.2), C.dark)
		part(m, "Stripe", Vector3.new(20, 1.2, 1), CFrame.new(0, 1, -1.4), C.line)
		part(m, "Pad", Vector3.new(30, 0.4, 16), CFrame.new(0, 0.2, -8), C.walk)
		sign(m, "Steadfast Shelter Co.", CFrame.new(0, 20, -0.6), 26)
		return { Exit = CFrame.new(0, 0.4, -10), Call = CFrame.new(5, 3, -2.6) } -- Exit faces out, towards the town
	end

	-- A container's prop: a cabinet, a locker or a crate (the art when it exists).
	local CONTAINER_ART = { "Prop_Cabinet", "Prop_Locker", "Prop_SupplyCrate" }
	local function containerModel(i: number): any
		local name = CONTAINER_ART[(i - 1) % #CONTAINER_ART + 1]
		local src = (ART and ART:FindFirstChild(name)) or (PROPS and PROPS:FindFirstChild(name))
		if src then
			return src:Clone()
		end
		local m: any = Instance.new("Model")
		m.Name = name
		local box = part(m, "Body", Vector3.new(4, 3.4, 2.4), CFrame.new(0, 1.7, 0), C.trim)
		part(m, "Lid", Vector3.new(4.2, 0.4, 2.6), CFrame.new(0, 3.6, 0), C.steel)
		box.PivotOffset = CFrame.new(0, -1.7, 0)
		m.PrimaryPart = box
		return m
	end

	local function socketsOf(model: Instance): { [string]: CFrame }
		local s: { [string]: CFrame } = {}
		for k, v in model:GetAttributes() do
			local name = string.match(k, "^Socket_(.+)$")
			if name and typeof(v) == "CFrame" then
				s[name] = v
			end
		end
		return s
	end

	local counts = { Containers = 0, Survivors = 0, Finds = 0, Art = 0, Stand = 0, Signs = 0 }
	for _, p in PLACES do
		local cf = moved[p.Id] or W(p.At[1], 0, p.At[2]) * CFrame.Angles(0, math.rad(p.Yaw), 0)
		local model: any
		local sockets: { [string]: CFrame }
		local src = ART and ART:FindFirstChild(p.Asset)
		local n = if p.Location then Config.Get("SurfaceLocations", p.Location).Containers else 0
		if src then
			model = src:Clone()
			sockets = socketsOf(model)
			counts.Art += 1
			local text = SIGN_TEXT[p.Id] or (p.Location and Config.Get("SurfaceLocations", p.Location).Name)
			if text then
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and d:GetAttribute("Role") == "Sign" then
						letter(d, text, SIGN_INK[p.Id])
						counts.Signs += 1
					end
				end
			end
			if p.Location and Config.Get("SurfaceLocations", p.Location).MinEra > 1 then
				-- the art's gate: parts whose Role is Barrier close the place until its era
				model:SetAttribute("MinEra", Config.Get("SurfaceLocations", p.Location).MinEra)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") and d:GetAttribute("Role") == "Barrier" then
						d:SetAttribute("Barrier", true)
					end
				end
			end
		else
			model = Instance.new("Model")
			model.Name = p.Asset
			sockets = STAND[p.Kind](model, p, n)
			model.WorldPivot = CFrame.new()
			counts.Stand += 1
		end
		model:SetAttribute("PlaceId", p.Id)
		if p.Location then
			model:SetAttribute("Location", p.Location)
		end
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:PivotTo(cf)
		model.Parent = holder
		local pivot = model:GetPivot()
		local markers = Instance.new("Folder")
		markers.Name = "Markers"
		markers.Parent = model
		for name, local_ in sockets do
			local at = pivot * local_
			local base = string.match(name, "^(%a+)")
			if base == "Container" then
				local i = tonumber(string.match(name, "(%d+)$")) or 1
				if i <= n then
					local c = containerModel(i)
					c.Name = "Container" .. i
					c:SetAttribute("Container", true)
					c:SetAttribute("Location", p.Location)
					c:PivotTo(at)
					c.Parent = model
					counts.Containers += 1
				end
			elseif base == "Survivor" then
				marker(markers, "SurvivorSpot", at, p.Location)
				counts.Survivors += 1
			elseif base == "BigFind" then
				marker(markers, "BigFindSpot", at, p.Location)
				counts.Finds += 1
			elseif name == "Exit" then
				marker(markers, "ElevatorExit", at)
			elseif name == "Call" then
				marker(markers, "ElevatorCall", at)
			end
		end
	end

	local decorModel = Instance.new("Model")
	decorModel.Name = "Wrecks"
	decorModel.Parent = holder
	for _, d in DECOR do
		local src = (ART and ART:FindFirstChild(d[1])) or (PROPS and PROPS:FindFirstChild(d[1]))
		local m: any
		if src then
			m = src:Clone()
		else
			m = Instance.new("Model")
			m.Name = d[1]
			local size = if string.find(d[1], "Car") then Vector3.new(7, 4, 13) elseif string.find(d[1], "Tree") then Vector3.new(2, 14, 2) else Vector3.new(8, 2.5, 6)
			local b = part(m, "Body", size, CFrame.new(0, size.Y / 2, 0), if string.find(d[1], "Tree") then C.dark else C.rust)
			b.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
			m.PrimaryPart = b
		end
		m:PivotTo(W(d[2], 0, d[3]) * CFrame.Angles(0, math.rad(d[4]), 0))
		m.Parent = decorModel
	end

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = holder
	for _, s in SPAWNS do
		marker(spawns, "SpawnPoint", W(s[1], 1, s[2]))
	end
	if decor then
		decor.Parent = holder
	else
		local d = Instance.new("Model")
		d.Name = "Decor"
		d.Parent = holder
	end
	holder.Parent = workspace
	return string.format("workspace.Surface built: %d places (%d art, %d stand-ins), %d signs lettered, %d containers, %d survivor spots, %d find spots, %d spawn points, %d wrecks",
		counts.Art + counts.Stand, counts.Art, counts.Stand, counts.Signs, counts.Containers, counts.Survivors, counts.Finds, #SPAWNS, #DECOR)
end

return BrightwaterMap
