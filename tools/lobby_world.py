"""Print the Luau that builds the lobby's world in the Lobby place (Prompt 21, A9): the Steadfast
showroom with its pads and booths, Main Street's blocks, the roadway, parked cars, bunting, the
town beyond the barricades, the walls that keep players on the street, the spawn and the daylight.

    python3 tools/lobby_world.py > /tmp/lobby_world.lua      # send with execute_luau (Edit), Lobby place

It needs every Lobby_* and Town_* asset in ServerStorage.Assets (CLAUDE.md section 4). It
replaces workspace.Lobby each time (and removes the old blockout, baseplate and spawn), so
re-run it after re-importing an asset or changing the plan (generators/Lobby/street_plan.py).
Positions here are Blender space, the showroom's frame; the Luau turns them over:
(x, y, z) -> (-x, z, y), the same yaw.
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(REPO, "generators", "Lobby"))
import street_plan as SP  # noqa: E402

PAL = {s["name"]: s["hex"] for s in json.load(open(os.path.join(REPO, "palette", "palette.json")))["swatches"] if s["hex"]}
PAD_IDS = ["Solo", "PrivateA", "PublicNormal", "PublicHard", "PublicNightmare", "PrivateB"]      # Bay1..Bay6, left to right
CAR_PAINTS = ["teal", "signal", "hazard", "mint", "blush", "cream", "skyblue", "rust", "navy", "leaf", "plum", "porcelain"]
N, S, W = SP.NORTH_Y, SP.SOUTH_Y, SP.WALK
R0, R1 = SP.ROAD                       # the roadway: y from -118 to -74
X0, X1 = SP.STREET_X                   # the walked street: x from -204 to 240
C = SP.CROSS
FAR0, FAR1 = X0 - C - 190.0, X1 + C + 190.0      # how far the ground goes
TOP = 160.0                            # how high the walls nobody sees go
TOWER = (-104.0, S - 112.0)            # the water tower, behind the diner


def lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return f"{v:g}"
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    raise TypeError(v)


def plan() -> dict:
    rng = random.Random(21)
    d: dict = {}
    d["blocks"] = [[n, x, y, yaw] for n, x, y, yaw in SP.PLAN]
    d["beyond"] = [[n, x, y, yaw] for n, x, y, yaw in SP.BEYOND]
    # -- the ground: [name, x0, x1, y0, y1, z0, z1, swatch] ---------------------------------------
    g = []
    road, walk, kerb, grass, alley = "gunmetal", "ash", "sandstone", "leaf", "stone"
    g.append(["Road", FAR0, FAR1, R0, R1, -2.5, SP.ROAD_TOP, road])
    cross = [(X0 - C, X0), (X1, X1 + C)]
    for i, (a, b) in enumerate(cross):                       # Elm St and Oak St
        g.append([f"CrossRoad{i + 1}N", a + 6, b - 6, R1, 150.0, -2.5, SP.ROAD_TOP, road])
        g.append([f"CrossRoad{i + 1}S", a + 6, b - 6, -340.0, R0, -2.5, SP.ROAD_TOP, road])
        for j, (c, e) in enumerate(((a, a + 6), (b - 6, b))):
            g.append([f"CrossWalk{i + 1}{j + 1}N", c, e, N, 150.0, -2.5, 0.0, walk])
            g.append([f"CrossWalk{i + 1}{j + 1}S", c, e, -340.0, S, -2.5, 0.0, walk])
    stretches = [(FAR0, X0 - C), (X0, X1), (X1 + C, FAR1)]
    for i, (a, b) in enumerate(stretches):
        g.append([f"WalkNorth{i + 1}", a, b, R1, N, -2.5, 0.0, walk])
        g.append([f"WalkSouth{i + 1}", a, b, S, R0, -2.5, 0.0, walk])
        g.append([f"KerbNorth{i + 1}", a, b, R1, R1 + 0.9, -2.4, 0.03, kerb])
        g.append([f"KerbSouth{i + 1}", a, b, R0 - 0.9, R0, -2.4, 0.03, kerb])
    for i, (a, b) in enumerate(cross):                       # the pavement's corners at the cross streets
        for j, (c, e) in enumerate(((a, a + 6), (b - 6, b))):
            g.append([f"CornerNorth{i + 1}{j + 1}", c, e, R1, N, -2.5, 0.0, walk])
            g.append([f"CornerSouth{i + 1}{j + 1}", c, e, S, R0, -2.5, 0.0, walk])
    g.append(["GroundNorth", FAR0, FAR1, N, 420.0, -3.0, -0.06, grass])
    g.append(["GroundSouth", FAR0, FAR1, -620.0, S, -3.0, -0.06, grass])
    for i, (a, b) in enumerate(((-76.0, -66.0), (66.0, 76.0))):     # the alleys beside the showroom
        g.append([f"Alley{i + 1}", a, b, N, 60.0, -1.0, -0.02, alley])
    x = FAR0 + 8.0
    while x < FAR1 - 8.0:                                    # the centre line
        if not any(a - 2 < x < b + 2 for a, b in cross) and not (-12.0 < x < 12.0):
            g.append(["Dash", x, x + 6.0, (R0 + R1) / 2 - 0.25, (R0 + R1) / 2 + 0.25, -0.6, SP.ROAD_TOP + 0.02, "cream"])
        x += 16.0
    for i in range(7):                                       # the crossing to the showroom's door
        xa = -9.1 + i * 2.6
        g.append(["Crossing", xa, xa + 1.5, R0 + 1.2, R1 - 1.2, -0.6, SP.ROAD_TOP + 0.02, "porcelain"])
    d["ground"] = g
    # -- what stops a player: [x0, x1, y0, y1] from the ground to TOP -------------------------------
    b = []
    b += [[X0 - 9.0, X0 - 7.5, S - 2.0, N + 2.0], [X0 - 9.0, X0 + 0.5, N + 0.5, N + 2.0], [X0 - 9.0, X0 + 0.5, S - 2.0, S - 0.5]]      # the west end
    b += [[X1 + 7.5, X1 + 9.0, S - 2.0, N + 2.0], [X1 - 0.5, X1 + 9.0, N + 0.5, N + 2.0], [X1 - 0.5, X1 + 9.0, S - 2.0, S - 0.5]]      # the east end
    b += [[-76.0, -66.0, N + 23.5, N + 25.0], [66.0, 76.0, N + 23.5, N + 25.0]]                                                         # the alleys' fences
    gx, dx = -132.0, -66.0                                   # the gas station's and the diner's blocks (their left ends)
    b += [[gx - 72.0, gx, S - 62.5, S - 61.0], [gx - 0.6, gx, S - 62.0, S], [gx - 72.0, gx - 71.4, S - 62.0, S]]
    b += [[dx - 0.6, dx, S - 40.0, S], [dx - 66.0, dx - 65.4, S - 40.0, S], [dx - 66.0, dx, S - 37.0, S - 36.0]]
    d["bounds"] = b
    d["fences"] = [[-76.0, -66.0, N + 23.0], [66.0, 76.0, N + 23.0]]
    # -- barricades across both ends: [x, y, yaw] -----------------------------------------------------
    bars = []
    for x in (X0 - 4.0, X1 + 4.0):
        for y in (R1 + 6.0, R1 - 6.0, R1 - 17.0, R0 + 17.0, R0 + 6.0, R0 - 6.0):
            bars.append([x, y, 90])
    d["barricades"] = bars
    # -- parked cars: [kind, x, y, z, yaw, paint] (a car's nose is -Y at yaw 0; they park facing the traffic's way) --
    cars = []
    north = [-188.0, -164.0, -118.0, -92.0, 96.0, 122.0, 172.0, 196.0, 222.0]
    south = [-118.0, -92.0, -52.0, -26.0, 34.0, 60.0, 104.0, 150.0, 176.0, 220.0]
    rt = SP.ROAD_TOP
    i = 0
    for x in north:
        cars.append(["CarPickup" if i % 4 == 2 else "CarSedan", round(x + rng.uniform(-1.5, 1.5), 2), R1 - 4.3, rt, round(270 + rng.uniform(-2, 2), 2),
                     CAR_PAINTS[i % len(CAR_PAINTS)]])
        i += 1
    for x in south:
        cars.append(["CarPickup" if i % 4 == 2 else "CarSedan", round(x + rng.uniform(-1.5, 1.5), 2), R0 + 4.3, rt, round(90 + rng.uniform(-2, 2), 2),
                     CAR_PAINTS[(i * 5 + 3) % len(CAR_PAINTS)]])
        i += 1
    cars.append(["CarPickup", gx - 38.0, S - 15.8, 0.06, 270, "rust"])                  # at the Starlite's pumps
    cars.append(["CarSedan", gx - 30.5, S - 28.0, 0.06, 0, "skyblue"])                  # nose to a service bay
    cars.append(["CarSedan", X0 - C / 2 - 8.5, N + 40.0, rt, 0, "cream"])               # on Elm St
    cars.append(["CarSedan", X1 + C / 2 + 8.5, S - 46.0, rt, 180, "teal"])              # on Oak St
    cars.append(["CarPickup", X1 + C + 30.0, R1 - 4.3, rt, 270, "hazard"])              # beyond Oak St
    cars.append(["CarSedan", X0 - C - 34.0, R0 + 4.3, rt, 90, "blush"])                 # beyond Elm St
    d["cars"] = cars
    # -- bunting from lamp to lamp, down the street: [x, y, z, yaw, scale] --------------------------------
    north_l, south_l = SP.lamps()
    both = sorted([(x, y, "n") for x, y in north_l] + [(x, y, "s") for x, y in south_l])
    strings = []
    last = None
    for x, y, side in both:
        if last and last[2] != side:
            ln = math.hypot(x - last[0], y - last[1])
            if ln <= 76.0:
                strings.append([last[0], last[1], SP.LAMP_TOP - 0.1, round(math.degrees(math.atan2(y - last[1], x - last[0])), 2), round(ln / 68.0, 4)])
        last = (x, y, side)
    d["bunting"] = strings
    d["banners"] = [[X0 + 36.0, (R0 + R1) / 2, 90, 0.8], [X1 - 36.0, (R0 + R1) / 2, 90, 0.8]]
    # -- the town beyond: tree clumps, pines, hills, the water tower: [asset, x, y, yaw, scale] -------------
    far = []
    x = FAR0 + 30.0
    k = 0
    while x < FAR1 - 20.0:
        if not any(a - 24 < x < b + 24 for a, b in cross):
            far.append(["TreeClump", x, (86.0 if -80.0 < x < 80.0 else 34.0) + rng.uniform(-8, 10), rng.uniform(-12, 12) + (180 if k % 2 else 0), rng.uniform(0.9, 1.25)])
            if abs(x - TOWER[0]) > 44.0:
                far.append(["TreeClump", x + rng.uniform(-10, 10), S - 92.0 + rng.uniform(-10, 8), rng.uniform(-12, 12) + (0 if k % 2 else 180), rng.uniform(0.9, 1.25)])
        x += rng.uniform(50.0, 62.0)
        k += 1
    for i, (a, b) in enumerate(cross):                       # trees down the cross streets, and where they end
        for y in (60.0, 112.0, -212.0, -270.0):
            far.append(["TreeBig", a - 10.0, y + rng.uniform(-6, 6), rng.uniform(0, 360), rng.uniform(0.9, 1.2)])
            far.append(["TreePine", b + 12.0, y + rng.uniform(-6, 6) + 20.0, rng.uniform(0, 360), rng.uniform(0.9, 1.2)])
        far.append(["TreeClump", (a + b) / 2, 170.0, 0, 1.3])
        far.append(["TreeClump", (a + b) / 2, -360.0, 180, 1.3])
    far += [["TreeClump", FAR0 + 60.0, (R0 + R1) / 2, 90, 1.4], ["TreeClump", FAR1 - 60.0, (R0 + R1) / 2, 270, 1.4]]     # where Main Street ends
    far += [["Hill", -260.0, 330.0, 10, 2.6], ["Hill", 120.0, 380.0, -20, 3.2], ["Hill", 470.0, 300.0, 30, 2.4],
            ["Hill", -330.0, -520.0, 160, 3.0], ["Hill", 60.0, -560.0, 200, 3.4], ["Hill", 420.0, -480.0, 170, 2.6],
            ["Hill", FAR0 - 120.0, -80.0, 80, 2.8], ["Hill", FAR1 + 120.0, -110.0, 100, 2.8]]
    far.append(["WaterTower", TOWER[0], TOWER[1], 12, 1.0])
    d["far"] = [[f[0]] + [round(v, 2) for v in f[1:]] for f in far]
    d["spawns"] = [[-7.5, N - 6.0], [-2.5, N - 6.0], [2.5, N - 6.0], [7.5, N - 6.0]]
    return d


TEMPLATE = r'''-- LobbyWorld: generated by tools/lobby_world.py (Prompt 21). Builds workspace.Lobby.
local SS = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local A = SS.Assets
local HEX = @HEX@
local TOP = @TOP@
for _, n in {"Lobby", "LobbyBlockout", "Baseplate", "SpawnLocation"} do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local root = Instance.new("Folder")
root.Name = "Lobby"
root.Parent = workspace
local count = {}
local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
-- Blender space (the showroom's frame) to Studio
local function B(x, y, z, yaw)
	return CFrame.new(-x, z or 0, y) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end
local function place(category, asset, cf, parent, name, scale)
	local m = A[category][asset]:Clone()
	m.Name = name or asset
	m:PivotTo(cf)
	if scale and math.abs(scale - 1) > 0.001 then m:ScaleTo(scale) end
	m.Parent = parent
	count[asset] = (count[asset] or 0) + 1
	return m
end
local function slab(parent, name, x0, x1, y0, y1, z0, z1, swatch)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(z1 - z0), math.abs(y1 - y0))
	p.CFrame = CFrame.new(-(x0 + x1) / 2, (z0 + z1) / 2, (y0 + y1) / 2)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if swatch then
		p.Color = Color3.fromHex(HEX[swatch])
	else
		p.Transparency = 1
		p.CastShadow = false
		p.CanTouch = false
	end
	p.Parent = parent
	return p
end
-- A block's bodies and shop fronts go up out of reach: nobody gets onto a roof.
local RAISE = { Building = true, Wall = true, Door = true, Doors = true }
local function seal(model)
	local c = model:FindFirstChild("Colliders")
	if not c then return end
	for _, p in c:GetChildren() do
		if RAISE[p.Name] then
			local base = p.Position.Y - p.Size.Y / 2
			p.Size = Vector3.new(p.Size.X, TOP - base, p.Size.Z)
			p.Position = Vector3.new(p.Position.X, base + p.Size.Y / 2, p.Position.Z)
		end
	end
end

-- the showroom ---------------------------------------------------------------------------------
local show = folder("Showroom")
local origin = CFrame.new()
local shell = place("Lobby", "Lobby_Showroom", origin, show)
place("Lobby", "Lobby_ShowroomHall", origin, show)
place("Lobby", "Lobby_ShowroomFit", origin, show)
place("Lobby", "Lobby_Frontage", origin, show)
local function socket(name)
	return origin * (shell:GetAttribute("Socket_" .. name) :: CFrame)
end
local pads = folder("Pads")
for i, id in @PADS@ do
	local pad = place("Lobby", "Lobby_ElevatorPad", socket("Bay" .. i), pads, "Pad_" .. id)
	pad:SetAttribute("PadId", id)
end
local function booth(asset, socketName, action, label)
	local m = place("Lobby", asset, socket(socketName), show)
	local at = Instance.new("Part")
	at.Name = "PromptAnchor"
	at.Size = Vector3.new(1, 1, 1)
	at.CFrame = m:GetPivot() * (m:GetAttribute("Socket_Prompt") :: CFrame)
	at.Transparency = 1
	at.Anchored = true
	at.CanCollide = false
	at.CanQuery = false
	at.CanTouch = false
	at.CastShadow = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = label
	prompt.ObjectText = "Steadfast showroom"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("LobbyAction", action)
	prompt.Parent = at
	at.Parent = m
end
booth("Lobby_ClassBooth", "ClassBooth", "ClassShop", "Class Shop")
booth("Lobby_LoadoutBooth", "LoadoutBooth", "Loadout", "Loadout")
place("Lobby", "Lobby_BunkerCutaway", socket("Cutaway"), show)
task.wait()

-- Main Street ----------------------------------------------------------------------------------
local street = folder("Street")
for _, b in @BLOCKS@ do
	seal(place("Lobby", "Lobby_Block" .. b[1], B(b[2], b[3], 0, b[4]), street, b[1]))
	task.wait()
end
local ground = folder("Ground")
for _, g in @GROUND@ do
	local p = slab(ground, g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8])
	if g[1] == "Dash" or g[1] == "Crossing" or string.sub(g[1], 1, 4) == "Kerb" then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
end
slab(ground, "Forecourt", -69, 69, @N@ , @N@ + 14, -1, 0.07, nil)
local bounds = folder("Bounds")
for _, w in @BOUNDS@ do
	slab(bounds, "Bound", w[1], w[2], w[3], w[4], -1, TOP, nil)
end
-- a board fence closes each alley
local dressing = folder("Dressing")
for _, f in @FENCES@ do
	local n = math.floor((f[2] - f[1]) / 1.25)
	for i = 0, n - 1 do
		local h = 8.4 + ((i * 7) % 5) * 0.22
		local x0 = f[1] + i * (f[2] - f[1]) / n
		slab(dressing, "FencePlank", x0 + 0.06, x0 + (f[2] - f[1]) / n - 0.06, f[3], f[3] + 0.3, 0, h, (i % 3 == 1) and "leather" or "walnut")
	end
	slab(dressing, "FenceRail", f[1], f[2], f[3] - 0.25, f[3], 1.6, 2.1, "walnut")
	slab(dressing, "FenceRail", f[1], f[2], f[3] - 0.25, f[3], 6.2, 6.7, "walnut")
end
for _, b in @BARRICADES@ do
	place("Town", "Town_Barricade", B(b[1], b[2], @ROADTOP@ * ((b[2] > @R1@ or b[2] < @R0@) and 0 or 1), b[3]), dressing)
end
for _, c in @CARS@ do
	local car = place("Town", "Town_" .. c[1], B(c[2], c[3], c[4], c[5]), dressing)
	local paint = car:FindFirstChild("Paint")
	if paint and paint:IsA("BasePart") then paint.Color = Color3.fromHex(HEX[c[6]]) end
end
task.wait()
for _, s in @BUNTING@ do
	place("Town", "Town_Bunting", B(s[1], s[2], s[3], s[4]), dressing, nil, s[5])
end
for _, s in @BANNERS@ do
	place("Town", "Town_WelcomeBanner", B(s[1], s[2], 0, s[3]), dressing, nil, s[4])
end
task.wait()

-- the town beyond the barricades ---------------------------------------------------------------
local beyond = folder("Beyond")
for _, b in @BEYOND@ do
	place("Lobby", "Lobby_Block" .. b[1], B(b[2], b[3], 0, b[4]), beyond, b[1])
	task.wait()
end
for _, f in @FAR@ do
	local m = place("Town", "Town_" .. f[1], B(f[2], f[3], f[1] == "Hill" and -4 or 0, f[4]), beyond, nil, f[5])
	local c = m:FindFirstChild("Colliders")
	if c then c:Destroy() end
end
for _, d in beyond:GetDescendants() do
	if d:IsA("BasePart") then
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
	end
end
task.wait()

-- spawns: on the pavement, facing the showroom ----------------------------------------------------
local spawns = folder("Spawns")
for _, s in @SPAWNS@ do
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Size = Vector3.new(4, 1, 4)
	sp.CFrame = CFrame.new(-s[1], -0.5, s[2]) * CFrame.Angles(0, math.pi, 0)
	sp.Anchored = true
	sp.Transparency = 1
	sp.CanCollide = false
	sp.CanQuery = false
	sp.CanTouch = false
	sp.CastShadow = false
	sp.Neutral = true
	sp.Duration = 0
	sp.Parent = spawns
end

-- a sunny morning ----------------------------------------------------------------------------------
Lighting.ClockTime = 10            -- with this latitude the sun stands over the south side and lights the showroom's front
Lighting.GeographicLatitude = -15
Lighting.Brightness = 3.2
Lighting.Ambient = Color3.fromRGB(112, 118, 132)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 158, 172)
Lighting.ColorShift_Top = Color3.fromRGB(255, 244, 224)
Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ExposureCompensation = 0.15
Lighting.ShadowSoftness = 0.25
Lighting.GlobalShadows = true
Lighting.FogEnd = 100000
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then
	atmo.Density = 0.22
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(205, 224, 240)
	atmo.Decay = Color3.fromRGB(150, 180, 210)
	atmo.Glare = 0.15
	atmo.Haze = 1.2
end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.6
end
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then dof.Enabled = false end
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then
	rays.Intensity = 0.06
	rays.Spread = 0.6
end
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.42
clouds.Density = 0.55
clouds.Color = Color3.fromRGB(255, 255, 255)
clouds.Parent = workspace.Terrain

local parts, tris = 0, 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then parts += 1 end
	if d:IsA("Model") and d:GetAttribute("Tris") then tris += d:GetAttribute("Tris") end
end
local list = {}
for k, v in count do table.insert(list, k .. " x" .. v) end
table.sort(list)
return string.format("workspace.Lobby built: %d parts, about %d triangles\n%s", parts, tris, table.concat(list, ", "))
'''


def main() -> str:
    d = plan()
    code = TEMPLATE
    used = sorted({g[7] for g in d["ground"]} | set(CAR_PAINTS) | {"walnut", "leather", "rust", "skyblue", "cream", "teal", "hazard", "blush"})
    rep = {
        "@HEX@": "{" + ", ".join(f'{k} = "{PAL[k]}"' for k in used) + "}",
        "@TOP@": lua(TOP), "@PADS@": lua(PAD_IDS), "@BLOCKS@": lua(d["blocks"]), "@GROUND@": lua(d["ground"]), "@BOUNDS@": lua(d["bounds"]),
        "@FENCES@": lua(d["fences"]), "@BARRICADES@": lua(d["barricades"]), "@CARS@": lua(d["cars"]), "@BUNTING@": lua(d["bunting"]),
        "@BANNERS@": lua(d["banners"]), "@BEYOND@": lua(d["beyond"]), "@FAR@": lua(d["far"]), "@SPAWNS@": lua(d["spawns"]),
        "@N@": lua(N), "@R0@": lua(R0), "@R1@": lua(R1), "@ROADTOP@": lua(SP.ROAD_TOP),
    }
    for k, v in rep.items():
        code = code.replace(k, v)
    assert "@" not in code, "unfilled placeholder"
    return code


if __name__ == "__main__":
    print(main())
