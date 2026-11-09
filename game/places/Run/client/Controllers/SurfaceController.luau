--!strict
--[[
	SurfaceController: what a player sees of the surface (bible Sections 9, 12, 18 and 23; Run place,
	Prompt 16). The server's SurfaceService, InventoryService and RescueService decide everything.

	* Lighting by zone (Section 23: each zone has its own lighting preset, switched on the client;
	  Section 19: an ashy orange-grey surface): the bunker keeps the place's own Lighting (captured
	  at start); the surface and the storm have their presets. Ash drifts down on the surface; in a
	  storm (RunState Storm) it blows sideways, the light drops and lightning flashes.
	* The elevator: the Elevator remote fades the HUD's Fade to black, the server moves the
	  character, and the screen comes back. Arriving on the surface shows a banner.
	* The HUD: the radiation gauge (the Radiation attribute, Section 18's top-left instruments) and
	  the backpack chip under the Medkits (PackUsed of PackSlots, a fill as it fills).
	* Prompts: each client shows the ones meant for it: CARRY when nobody carries a big find, PUT
	  DOWN to its carrier, HELP CARRY to everyone else with free hands, UNLOAD to a player with
	  something in their pack or a find in their hands.
	* Movement: carrying slows the character (Rules.Surface.CarrySpeed by the Carriers attribute);
	  the Scout's SurfaceMoveSpeed applies on the surface.
	* The Scout's LootOutline: unsearched containers near the player glow.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Surface = require(Shared.Rules.Surface)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Movement = require(Lib:WaitForChild("Movement"))

local log = Log.new("SurfaceController")
local player = Players.LocalPlayer

local SurfaceController = {
	Name = "SurfaceController",
	Dependencies = { "HUDController", "CameraController" },
}

type Preset = { Lighting: { [string]: any }, Atmosphere: { [string]: any } }

local LIGHTING_KEYS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }
local ATMOSPHERE_KEYS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }

local PRESETS: { [string]: Preset } = {
	Surface = {
		Lighting = {
			ClockTime = 15.4, Brightness = 2.1, Ambient = Color3.fromRGB(92, 80, 72), OutdoorAmbient = Color3.fromRGB(146, 124, 108),
			ExposureCompensation = 0, EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.5,
		},
		Atmosphere = {
			Density = 0.36, Offset = 0.12, Color = Color3.fromRGB(206, 172, 142), Decay = Color3.fromRGB(112, 84, 70), Glare = 0.12, Haze = 1.8,
		},
	},
	Storm = {
		Lighting = {
			ClockTime = 17.4, Brightness = 0.9, Ambient = Color3.fromRGB(62, 56, 54), OutdoorAmbient = Color3.fromRGB(90, 80, 76),
			ExposureCompensation = -0.2, EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.3,
		},
		Atmosphere = {
			Density = 0.6, Offset = 0.28, Color = Color3.fromRGB(122, 106, 96), Decay = Color3.fromRGB(72, 60, 56), Glare = 0, Haze = 3,
		},
	},
}

local hud: any = nil
local bunkerPreset: Preset? = nil
local applied: string? = nil
local zone = "Bunker"
local atmosphere: Atmosphere? = nil
local flash: ColorCorrectionEffect? = nil
local dust: Part? = nil
local ash: ParticleEmitter? = nil
local gusts: ParticleEmitter? = nil
local lightningAt = 0
local fading = false
local outlined: { [Model]: Highlight } = {}

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function classValue(key: string): number?
	local class = player:GetAttribute("Class")
	return Modifiers.ClassValue(if type(class) == "string" then class else nil, key)
end

local function storming(): boolean
	return RunState.Get("Storm") == true
end

-- Lighting --------------------------------------------------------------------------------------

local function capture(): Preset
	local preset: Preset = { Lighting = {}, Atmosphere = {} }
	for _, key in LIGHTING_KEYS do
		preset.Lighting[key] = (Lighting :: any)[key]
	end
	if atmosphere then
		for _, key in ATMOSPHERE_KEYS do
			preset.Atmosphere[key] = (atmosphere :: any)[key]
		end
	end
	return preset
end

local function apply(name: string, seconds: number)
	if applied == name then
		return
	end
	applied = name
	local preset = if name == "Bunker" then bunkerPreset else PRESETS[name]
	if not preset then
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if seconds <= 0 then
		for key, value in preset.Lighting do
			(Lighting :: any)[key] = value
		end
		if atmosphere then
			for key, value in preset.Atmosphere do
				(atmosphere :: any)[key] = value
			end
		end
		return
	end
	local clockTime = preset.Lighting.ClockTime
	local rest = table.clone(preset.Lighting)
	rest.ClockTime = nil
	TweenService:Create(Lighting, info, rest):Play()
	if type(clockTime) == "number" then
		Lighting.ClockTime = clockTime -- a tween would sweep the sun across the sky
	end
	if atmosphere and next(preset.Atmosphere) then
		TweenService:Create(atmosphere, info, preset.Atmosphere):Play()
	end
end

local function wanted(): string
	if zone ~= "Surface" then
		return "Bunker"
	end
	return if storming() then "Storm" else "Surface"
end

local function refreshLighting(seconds: number)
	apply(wanted(), seconds)
end

-- The weather -----------------------------------------------------------------------------------

local function makeWeather()
	local part = Instance.new("Part")
	part.Name = "SurfaceWeather"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(140, 1, 140)
	local a = Instance.new("ParticleEmitter")
	a.Name = "Ash"
	a.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	a.Color = ColorSequence.new(Color3.fromRGB(196, 186, 176), Color3.fromRGB(150, 140, 132))
	a.LightEmission = 0
	a.Size = NumberSequence.new(0.18, 0.12)
	a.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.25), NumberSequenceKeypoint.new(1, 1) })
	a.Lifetime = NumberRange.new(5, 8)
	a.Speed = NumberRange.new(2, 5)
	a.SpreadAngle = Vector2.new(30, 30)
	a.EmissionDirection = Enum.NormalId.Bottom
	a.Acceleration = Vector3.new(2, -1, 0.6)
	a.Rate = 0
	a.Parent = part
	local g = Instance.new("ParticleEmitter")
	g.Name = "Gusts"
	g.Texture = "rbxasset://textures/particles/smoke_main.dds"
	g.Color = ColorSequence.new(Color3.fromRGB(150, 128, 112), Color3.fromRGB(110, 96, 90))
	g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
	g.Lifetime = NumberRange.new(2.5, 4)
	g.Speed = NumberRange.new(26, 40)
	g.EmissionDirection = Enum.NormalId.Right
	g.SpreadAngle = Vector2.new(12, 20)
	g.Acceleration = Vector3.new(10, -2, 4)
	g.RotSpeed = NumberRange.new(-30, 30)
	g.Rate = 0
	g.Parent = part
	part.Parent = workspace.CurrentCamera
	dust = part
	ash = a
	gusts = g
end

local function weatherStep()
	local camera = workspace.CurrentCamera
	if not dust or not camera then
		return
	end
	local on = zone == "Surface"
	local wild = on and storming()
	local at = camera.CFrame.Position
	;(dust :: Part).CFrame = CFrame.new(at.X - (if wild then 60 else 0), at.Y + 22, at.Z)
	if ash then
		ash.Rate = if wild then 240 elseif on then 45 else 0
		ash.Acceleration = if wild then Vector3.new(38, -6, 10) else Vector3.new(2, -1, 0.6)
	end
	if gusts then
		gusts.Rate = if wild then 14 else 0
	end
	-- lightning in the storm
	if wild and os.clock() >= lightningAt and flash then
		lightningAt = os.clock() + 4 + math.random() * 8
		local fx = flash :: ColorCorrectionEffect
		task.spawn(function()
			for _ = 1, 2 do
				fx.Brightness = 0.35
				fx.Enabled = true
				task.wait(0.06)
				fx.Brightness = 0
				task.wait(0.08)
			end
			fx.Enabled = false
		end)
	end
end

-- The elevator ----------------------------------------------------------------------------------

local function fadeFrame(): Frame?
	local gui = hud:Gui()
	local frame = gui and gui:FindFirstChild("Fade")
	return if frame and frame:IsA("Frame") then frame else nil
end

local function onElevator(way: string, seconds: number)
	local frame = fadeFrame()
	if not frame then
		return
	end
	fading = true
	frame.Visible = true
	frame.BackgroundTransparency = 1
	TweenService:Create(frame, TweenInfo.new(seconds), { BackgroundTransparency = 0 }):Play()
	local root = myRoot()
	local from = if root then root.Position else Vector3.zero
	task.spawn(function()
		local started = os.clock()
		-- wait for the server's move (or give up)
		while os.clock() - started < seconds + 1.5 do
			task.wait(0.05)
			local r = myRoot()
			if r and (r.Position - from).Magnitude > 30 then
				break
			end
		end
		local r = myRoot()
		if r then
			zone = Surface.Zone(r.Position)
		end
		refreshLighting(0)
		task.wait(0.15)
		TweenService:Create(frame, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
		task.wait(seconds)
		frame.Visible = false
		fading = false
		if way == "Up" then
			hud:Banner(if storming() then "BRIGHTWATER RUINS  ·  THE STORM IS ON" else "BRIGHTWATER RUINS", if storming() then "Danger" else "Info", 3)
		end
	end)
end

-- The HUD ---------------------------------------------------------------------------------------

local function updateRadiation()
	local value = player:GetAttribute("Radiation")
	local max = Config.Get("Tuning", "Player").RadiationMax
	local v = if type(value) == "number" then value else 0
	hud:SetVital("Radiation", math.clamp(v / max, 0, 1))
end

local function updatePack()
	local gui = hud:Gui()
	local chip = gui and gui:FindFirstChild("Backpack")
	if not chip then
		return
	end
	local used = player:GetAttribute("PackUsed")
	local slots = player:GetAttribute("PackSlots")
	local u = if type(used) == "number" then used else 0
	local s = if type(slots) == "number" and slots > 0 then slots else Config.Get("Tuning", "Player").BackpackSlots
	local count = chip:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Text = `{u}/{s}`
		count.TextColor3 = if u >= s then Color3.fromHex("#F2C14E") else Color3.fromHex("#F2E6C9")
	end
	local fill = chip:FindFirstChild("Fill")
	if fill and fill:IsA("Frame") then
		fill.Visible = u > 0
		fill.Size = UDim2.new(0.88 * math.clamp(u / s, 0, 1), 0, fill.Size.Y.Scale, 0)
	end
end

-- Prompts ---------------------------------------------------------------------------------------

local gated: { [ProximityPrompt]: boolean } = {}

local function gate(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	local by = prompt:GetAttribute("CarriedBy")
	local busy = player:GetAttribute("Carrying") ~= nil
	if kind == "Carry" then
		prompt.Enabled = by == nil and not busy
	elseif kind == "HelpCarry" then
		prompt.Enabled = by ~= nil and by ~= player.UserId and not busy
	elseif kind == "PutDown" then
		prompt.Enabled = by == player.UserId
	elseif kind == "Unload" then
		local used = player:GetAttribute("PackUsed")
		prompt.Enabled = (type(used) == "number" and used > 0) or busy
	end
end

local function regateAll()
	for prompt in gated do
		if prompt.Parent then
			gate(prompt)
		else
			gated[prompt] = nil
		end
	end
end

local function watchPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt") then
		return
	end
	local kind = instance:GetAttribute("Kind")
	if kind ~= "Carry" and kind ~= "HelpCarry" and kind ~= "PutDown" and kind ~= "Unload" then
		return
	end
	gated[instance] = true
	instance:GetAttributeChangedSignal("CarriedBy"):Connect(function()
		gate(instance)
	end)
	instance.AncestryChanged:Connect(function()
		if not instance.Parent then
			gated[instance] = nil
		end
	end)
	gate(instance)
end

local function watchFolder(name: string, parentName: string?)
	task.spawn(function()
		local parent: Instance? = workspace
		if parentName then
			parent = workspace:WaitForChild(parentName, 120)
		end
		local folder = parent and parent:WaitForChild(name, 300)
		if not folder then
			return
		end
		for _, d in folder:GetDescendants() do
			watchPrompt(d)
		end
		folder.DescendantAdded:Connect(watchPrompt)
	end)
end

-- Movement and the Scout's outline ---------------------------------------------------------------

local function updateMovement()
	local carriers = player:GetAttribute("Carriers")
	local carrying = player:GetAttribute("Carrying") ~= nil
	Movement.Set("Carry", if carrying then Surface.CarrySpeed(if type(carriers) == "number" then carriers else 1) else nil)
	local surfaceSpeed = classValue("SurfaceMoveSpeed")
	Movement.Set("SurfaceSpeed", if zone == "Surface" and surfaceSpeed and surfaceSpeed ~= 1 then surfaceSpeed else nil)
end

local function updateOutlines()
	local on = zone == "Surface" and classValue("LootOutline") == true
	local root = myRoot()
	local map = workspace:FindFirstChild("Surface")
	local keep: { [Model]: boolean } = {}
	if on and root and map then
		for _, item in map:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("Container") and not item:GetAttribute("Looted") and not item:GetAttribute("Locked") then
				local pivot = item:GetPivot().Position
				if (pivot - root.Position).Magnitude <= 70 then
					keep[item] = true
					if not outlined[item] then
						local h = Instance.new("Highlight")
						h.FillTransparency = 1
						h.OutlineColor = Color3.fromHex("#F2C14E")
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Adornee = item
						h.Parent = item
						outlined[item] = h
					end
				end
			end
		end
	end
	for model, h in outlined do
		if not keep[model] then
			h:Destroy()
			outlined[model] = nil
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------------------

function SurfaceController:Init(registry)
	hud = registry.HUDController
end

function SurfaceController:Start()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	bunkerPreset = capture()
	applied = "Bunker"
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Lightning"
	cc.Enabled = false
	cc.Parent = Lighting
	flash = cc
	makeWeather()
	Remotes.OnClient("Elevator", function(way: any, seconds: any)
		onElevator(tostring(way), tonumber(seconds) or 0.35)
	end)
	RunState.Changed("Storm"):Connect(function()
		if not fading then
			refreshLighting(4)
		end
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(function()
		local value = player:GetAttribute("Zone")
		local new = if type(value) == "string" then value else "Bunker"
		if new ~= zone and not fading then
			zone = new
			refreshLighting(0.5)
		end
		updateMovement()
	end)
	for _, name in { "Radiation" } do
		player:GetAttributeChangedSignal(name):Connect(updateRadiation)
	end
	for _, name in { "PackUsed", "PackSlots" } do
		player:GetAttributeChangedSignal(name):Connect(updatePack)
	end
	for _, name in { "Carrying", "Carriers", "Class" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			updateMovement()
			regateAll()
		end)
	end
	player:GetAttributeChangedSignal("PackUsed"):Connect(regateAll)
	watchFolder("Finds")
	watchFolder("Hauling", "Bunker")
	updateRadiation()
	updatePack()
	updateMovement()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		weatherStep()
		acc += dt
		if acc >= 0.5 then
			acc = 0
			local root = myRoot()
			if root and not fading then
				local here = Surface.Zone(root.Position)
				if here ~= zone then
					zone = here
					refreshLighting(0.5)
					updateMovement()
				end
			end
			updateOutlines()
		end
	end)
	log:Info("surface view ready")
end

return SurfaceController
