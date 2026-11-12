--!strict
--[[
	BossController: what players see of a boss fight beyond the boss itself (bible Sections 10 and
	18; Prompt 15). Run place only. The server's BossService decides everything; this draws the
	Boss collection's "Fight" entry.

	* The HUD's boss bar under the cycle bar: the boss's name, BREAKING THROUGH while it comes,
	  its phase (PHASE 1 OF 2), and its health draining; DEAD when it falls.
	* The camera shakes when the boss breaks through the floor, when its slam or bite lands near
	  the player (the model's AttackAt plus its HitTime) and when The Deluge surfaces near them
	  (SurfacedAt). The bar says whether The Deluge is under the floor or up (the fight's Mode).
	* The Crystal Colossus (Prompt 24): the bar says whether its cores are lit or it is all armour
	  (the fight's Lit), and each shard it throws shows on the floor before it lands (the server's
	  ShardMark parts: a ring that closes in as the crystal falls).
	* The Source (Prompt 25): the bar says whether its eye is shut (and how many tendrils are left
	  to cut down) or open; the rooms its tendrils stand in blink on the mini-map and each tendril
	  shows through the walls (a Highlight), so a team that has to split up knows where to go; a
	  root about to burst up shows on the floor first (the server's RootMark parts).
	The boss's clips play through NPCAnimator (workspace.Monsters, Rig and Activity); the cracks,
	dust and rock bursts are the server's parts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boss = require(Shared.Rules.Boss)
local Log = require(Shared.Utilities.Log)

local log = Log.new("BossController")
local player = Players.LocalPlayer

local BossController = {
	Name = "BossController",
	Dependencies = { "ReplicaController", "HUDController", "CameraController", "MiniMapController" },
}

local replica: any = nil
local hud: any = nil
local camera: any = nil
local miniMap: any = nil
local lastState: string? = nil
local blinking: { [string]: boolean } = {} -- the rooms the Source's tendrils stand in
local watched: { [Model]: RBXScriptConnection } = {}

local function myPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function bar(): any
	local gui = hud:Gui()
	return gui and gui:FindFirstChild("BossBar")
end

local function update()
	local f = replica:Get("Boss", "Fight")
	local b = bar()
	if not b then
		return
	end
	local rooms: { [string]: boolean } = {}
	if type(f) == "table" and type(f.Rooms) == "table" and f.State ~= "Dying" then
		for _, id in f.Rooms do
			rooms[id] = true
		end
	end
	for id in blinking do
		if not rooms[id] then
			blinking[id] = nil
			miniMap:Blink(id, false)
		end
	end
	for id in rooms do
		if not blinking[id] then
			blinking[id] = true
			miniMap:Blink(id, true)
		end
	end
	if type(f) ~= "table" then
		b.Visible = false
		lastState = nil
		return
	end
	b.Visible = true
	b:FindFirstChild("Name").Text = Boss.Title(f.Name or "Boss")
	local phase = b:FindFirstChild("Phase")
	if f.State == "Warning" or f.State == "Rising" then
		phase.Text = "BREAKING THROUGH"
	elseif f.State == "Dying" then
		phase.Text = "DEAD"
	else
		local where = if f.Mode == "Swim" or f.Mode == "Diving" then " · UNDER THE FLOOR" elseif f.Mode ~= nil then " · UP: HIT ITS HEAD"
			-- the Crystal Colossus (Prompt 24): all armour until a light shows its cores
			elseif f.Lit == true then " · LIT: HIT ITS GLOWING CORES" elseif f.Lit == false then " · ARMOURED: LIGHT IT WITH A FLARE"
			-- the Source (Prompt 25): tendrils in many rooms, then the core
			elseif f.Stage == "Tendrils" then ` · EYE SHUT: CUT DOWN ITS TENDRILS ({f.Tendrils or 0} LEFT)`
			elseif f.Stage == "Core" then " · EYE OPEN: HIT THE EYE" else ""
		phase.Text = `PHASE {f.Phase or 1} OF {f.Phases or 1}{where}`
	end
	local fill = b:FindFirstChild("Back") and b.Back:FindFirstChild("Fill")
	if fill then
		local fraction = if (f.Max or 0) > 0 then math.clamp((f.Health or 0) / f.Max, 0, 1) else 0
		fill.Size = UDim2.fromScale(fraction, 1)
	end
	if f.Chamber and f.State == "Fighting" and lastState == nil then
		camera:Shake(1.6, 2.2) -- it wakes
	end
	if f.State == "Rising" and lastState ~= "Rising" then
		local me = myPosition()
		local at = if type(f.At) == "table" then Vector3.new(f.At.X, f.At.Y, f.At.Z) else nil
		local distance = if me and at then (me - at).Magnitude else math.huge
		camera:Shake(if distance < 80 then 2.5 else 1.2, if distance < 80 then 2.4 else 0.8)
	end
	lastState = f.State
end

local SOURCE = Color3.fromRGB(124, 255, 155)

-- A slam that lands near the player shakes the camera.
local function watch(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Boss") == nil or watched[model] then
		return
	end
	if model:FindFirstChildOfClass("Humanoid") == nil then
		return -- an egg sac
	end
	if model:GetAttribute("Tendril") == true and not model:FindFirstChild("TendrilMark") then
		-- seen through the walls, so whoever goes after it can find it
		local mark = Instance.new("Highlight")
		mark.Name = "TendrilMark"
		mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		mark.FillColor = SOURCE
		mark.FillTransparency = 0.82
		mark.OutlineColor = SOURCE
		mark.OutlineTransparency = 0.1
		mark.Adornee = model
		mark.Parent = model
	end
	watched[model] = model:GetAttributeChangedSignal("AttackAt"):Connect(function()
		local hitTime = (model:GetAttribute("HitTime") :: number?) or 0.8
		task.delay(hitTime, function()
			local me = myPosition()
			if me and model.Parent and (me - model:GetPivot().Position).Magnitude < 32 then
				camera:Shake(0.5, 1.6)
			end
		end)
	end)
	-- The Deluge coming up out of the floor shakes it too.
	model:GetAttributeChangedSignal("SurfacedAt"):Connect(function()
		local me = myPosition()
		if me and model.Parent and (me - model:GetPivot().Position).Magnitude < 60 then
			camera:Shake(1.2, 1.4)
		end
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil and watched[model] then
			watched[model]:Disconnect()
			watched[model] = nil
		end
	end)
end

-- A shard of the Crystal Colossus on its way down (Prompt 24): the server's ShardMark part says
-- where and when (Radius, LandsAt). A ring on the floor closes in as a crystal falls to its middle.
local SHARD = Color3.fromRGB(176, 238, 234)
local function watchMark(mark: Instance)
	if not mark:IsA("BasePart") or mark.Name ~= "ShardMark" then
		return
	end
	local radius = (mark:GetAttribute("Radius") :: number?) or 6
	local landsAt = (mark:GetAttribute("LandsAt") :: number?) or workspace:GetServerTimeNow()
	local total = math.max(landsAt - workspace:GetServerTimeNow(), 0.05)
	local centre = mark.Position
	local function piece(name: string, shape: Enum.PartType): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = SHARD
		part.Parent = workspace.CurrentCamera or workspace
		return part
	end
	local edge = piece("ShardRing", Enum.PartType.Cylinder)
	edge.Transparency = 0.72
	edge.Size = Vector3.new(0.1, radius * 2, radius * 2)
	edge.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
	local closing = piece("ShardClosing", Enum.PartType.Cylinder)
	closing.Color = Color3.fromRGB(255, 255, 255)
	closing.Transparency = 0.45
	local shard = piece("Shard", Enum.PartType.Block)
	shard.Size = Vector3.new(1.4, 7, 1.4)
	shard.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = SHARD
	light.Range = radius * 2.2
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = edge
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		edge:Destroy()
		closing:Destroy()
		shard:Destroy()
	end
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local left = landsAt - workspace:GetServerTimeNow()
		local k = math.clamp(1 - left / total, 0, 1)
		local r = radius * (1 - k * 0.92)
		closing.Size = Vector3.new(0.14, r * 2, r * 2)
		closing.CFrame = CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local height = 16 * (1 - k * k) -- it falls faster as it comes
		shard.CFrame = CFrame.new(centre + Vector3.new(0, height + 3, 0)) * CFrame.Angles(math.rad(8), k * 6, math.rad(-6))
		if left <= 0 or not mark.Parent then
			local me = myPosition()
			if me and (me - centre).Magnitude < radius * 3 then
				camera:Shake(0.35, 0.9)
			end
			finish()
		end
	end)
	mark.Destroying:Once(finish)
end

-- A root of the Source about to burst up (Prompt 25): the server's RootMark part says where and
-- when (Radius, LandsAt). A ring on the floor closes in, then roots stab up through it and sink.
local ROOT = Color3.fromRGB(110, 71, 102)
local function watchRoot(mark: Instance)
	if not mark:IsA("BasePart") or mark.Name ~= "RootMark" then
		return
	end
	local radius = (mark:GetAttribute("Radius") :: number?) or 5.5
	local landsAt = (mark:GetAttribute("LandsAt") :: number?) or workspace:GetServerTimeNow()
	local total = math.max(landsAt - workspace:GetServerTimeNow(), 0.05)
	local centre = mark.Position
	local made: { Instance } = {}
	local function piece(name: string, shape: Enum.PartType, color: Color3, material: Enum.Material): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = material
		part.Color = color
		part.Parent = workspace.CurrentCamera or workspace
		table.insert(made, part)
		return part
	end
	local edge = piece("RootRing", Enum.PartType.Cylinder, SOURCE, Enum.Material.Neon)
	edge.Transparency = 0.7
	edge.Size = Vector3.new(0.1, radius * 2, radius * 2)
	edge.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
	local closing = piece("RootClosing", Enum.PartType.Cylinder, Color3.fromRGB(232, 255, 238), Enum.Material.Neon)
	closing.Transparency = 0.4
	local light = Instance.new("PointLight")
	light.Color = SOURCE
	light.Range = radius * 2.4
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = edge
	-- the roots wait under the floor: a ring of them, leaning out, and one up the middle
	local roots: { { Part: Part, Base: CFrame, Length: number } } = {}
	local random = Random.new(math.floor(centre.X * 31 + centre.Z * 17))
	for i = 0, 5 do
		local length = if i == 0 then random:NextNumber(8, 10) else random:NextNumber(5, 7.5)
		local root = piece("Root", Enum.PartType.Block, ROOT, Enum.Material.SmoothPlastic)
		root.Size = Vector3.new(if i == 0 then 1.5 else 1.0, length, if i == 0 then 1.5 else 1.0)
		local angle = (i / 5) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local out = if i == 0 then 0 else radius * random:NextNumber(0.35, 0.7)
		local base = CFrame.new(centre + Vector3.new(math.cos(angle) * out, 0, math.sin(angle) * out))
			* CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, if i == 0 then 0 else -math.rad(random:NextNumber(10, 24)))
		table.insert(roots, { Part = root, Base = base, Length = length })
		local vein = piece("RootVein", Enum.PartType.Block, SOURCE, Enum.Material.Neon)
		vein.Size = Vector3.new(0.18, length * 0.8, 0.18)
		table.insert(roots, { Part = vein, Base = base * CFrame.new(root.Size.X / 2, 0, 0), Length = length })
	end
	local connection: RBXScriptConnection? = nil
	local burstAt: number? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		for _, part in made do
			part:Destroy()
		end
	end
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local left = landsAt - workspace:GetServerTimeNow()
		local k = math.clamp(1 - left / total, 0, 1)
		local r = radius * (1 - k * 0.92)
		closing.Size = Vector3.new(0.14, r * 2, r * 2)
		closing.CFrame = CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local up = 0 -- how far out of the floor the roots are, 0 to 1
		if left <= 0 then
			if not burstAt then
				burstAt = os.clock()
				edge.Transparency = 1
				closing.Transparency = 1
				local me = myPosition()
				if me and (me - centre).Magnitude < radius * 3 then
					camera:Shake(0.35, 1.1)
				end
			end
			local since = os.clock() - (burstAt :: number)
			up = if since < 0.12 then since / 0.12 elseif since < 0.6 then 1 else math.max(1 - (since - 0.6) / 0.35, 0)
			if since > 0.95 then
				finish()
				return
			end
		end
		for _, root in roots do
			root.Part.CFrame = root.Base * CFrame.new(0, root.Length * (up - 0.5) - 0.3, 0)
		end
		if not mark.Parent and not burstAt then
			finish()
		end
	end)
end

function BossController:Init(registry)
	miniMap = registry.MiniMapController
	replica = registry.ReplicaController
	hud = registry.HUDController
	camera = registry.CameraController
end

function BossController:Start()
	replica:Changed("Boss"):Connect(update)
	if replica:IsReady() then
		update()
	else
		replica:Ready():Connect(update)
	end
	task.spawn(function()
		local monsters = workspace:WaitForChild("Monsters", 120)
		if not monsters then
			return
		end
		for _, model in monsters:GetChildren() do
			watch(model)
			watchMark(model)
			watchRoot(model)
		end
		monsters.ChildAdded:Connect(function(child: Instance)
			-- attributes arrive with the model; wait a frame for safety
			task.defer(watch, child)
			task.defer(watchMark, child)
			task.defer(watchRoot, child)
		end)
	end)
	log:Debug("boss display ready")
end

return BossController
