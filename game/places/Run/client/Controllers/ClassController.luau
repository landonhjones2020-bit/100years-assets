--!strict
--[[
	ClassController: the class ability on this client (bible Section 14; Section 9: Q is the class
	ability). Run place only; Prompt 20. The server decides everything (ClassService); this sends
	what the player wants and shows what the server says.

	* The ability key (Q, LB, the touch Ability button, a click on the HUD's ability): a tap uses the
	  selected option, aimed where the camera looks (UseAbility); a hold past Tuning.Classes
	  .HoldSeconds picks the next option (PickAbilityOption: the Gadget Belt's gadgets, the drone's
	  modes, the Quartermaster's requisitions).
	* The HUD, from the Player's attributes: the class plate (HUDController:SetClass, whenever Class
	  or ClassLevel changes) and, 10 times a second, the ability (HUDController:SetAbility): the
	  seconds or cycles left over the cooldown shade, uses left or Steady Shot's shots, the selected
	  option, and a ring while its effect is in play.
	* The Teleport Beacon: its chip shows while RunState BeaconUntil is ahead; its key (T, a hold of
	  D-pad down) or a tap on it asks for the teleport (TeleportToBeacon).
	* Grapple Line (the Grapple remote): this character zips to the point (a LinearVelocity on its
	  root) until it arrives, at Grapple.Speed.
	* Prompts: class-only prompts (ForClass: the Engineer's barricades) are enabled for that class
	  only; a revive prompt holds for this player's ReviveSeconds (the Medic's 1 s); a barricade
	  prompt names this Engineer's cost (BarricadeCost).
	* The Marksman's level 2 aim zoom (CameraController:SetAimZoom with AimZoom).
	* Effects (AbilityFx, ArcZap): rings, beams and bursts drawn here, gone in a second.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Classes = require(Shared.Rules.Classes)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)

local log = Log.new("ClassController")
local player = Players.LocalPlayer

local ClassController = {
	Name = "ClassController",
	Dependencies = { "InputController", "CameraController", "HUDController" },
}

local input: any = nil
local camera: any = nil
local hud: any = nil
local fxFolder: Folder? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function classOf(): string
	local class = player:GetAttribute("Class")
	return if type(class) == "string" then class else "Survivor"
end

-- The ability key ---------------------------------------------------------------------------------------

local pressedAt: number? = nil
local cycled = false

local function useAbility()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	Remotes.FireServer("UseAbility", 0, cam.CFrame.Position, cam.CFrame.LookVector)
end

local function nextOption()
	local options = Classes.Options(classOf())
	if #options == 0 then
		return false
	end
	local current = player:GetAttribute("AbilityOption")
	local index = table.find(options, if type(current) == "string" then current else "") or 1
	Remotes.FireServer("PickAbilityOption", index % #options + 1)
	return true
end

local function abilityDown()
	local at = os.clock()
	pressedAt = at
	cycled = false
	task.delay(Classes.Tuning().HoldSeconds, function()
		if pressedAt == at then
			cycled = nextOption()
		end
	end)
end

local function abilityUp()
	local wasPressed = pressedAt ~= nil
	pressedAt = nil
	if wasPressed and not cycled then
		useAbility()
	end
	cycled = false
end

-- The HUD --------------------------------------------------------------------------------------------------

local function refreshClass()
	local level = player:GetAttribute("ClassLevel")
	hud:SetClass(classOf(), if type(level) == "number" then level else 1)
	camera:SetAimZoom(Modifiers.PlayerValue(player, "AimZoom") or 1)
end

local function refreshAbility()
	local class = classOf()
	local ability = Classes.Ability(class)
	if not ability then
		return
	end
	local waitText: string? = nil
	local readyCycle = player:GetAttribute("AbilityReadyCycle")
	local cycle = RunState.Get("Cycle")
	if type(readyCycle) == "number" and type(cycle) == "number" and readyCycle > cycle then
		waitText = if readyCycle - cycle == 1 then "1 CY" else `{readyCycle - cycle} CY`
	end
	local own = if Classes.OwnCooldowns(class) then player:GetAttribute("AbilityOptionReadyAt") else player:GetAttribute("AbilityReadyAt")
	if not waitText and type(own) == "number" and own > now() + 0.05 then
		waitText = tostring(math.ceil(own - now()))
	end
	local uses = player:GetAttribute("AbilityUses")
	local max = player:GetAttribute("AbilityMax")
	local usesText: string? = nil
	if type(uses) == "number" then
		usesText = if type(max) == "number" then `{uses}/{max}` else tostring(uses)
		if uses <= 0 and not waitText then
			waitText = "" -- shaded: no uses left until the next Surge, cycle or era
		end
	end
	local shots = player:GetAttribute("SteadyShots")
	if type(shots) == "number" and shots > 0 then
		usesText = `x{shots}`
	end
	local activeUntil = player:GetAttribute("AbilityActiveUntil")
	local option = player:GetAttribute("AbilityOption")
	hud:SetAbility({
		Wait = waitText,
		Uses = usesText,
		Option = if type(option) == "string" then option else nil,
		Active = (type(activeUntil) == "number" and activeUntil > now()) or (type(shots) == "number" and shots > 0),
	})
	local beaconUntil = RunState.Get("BeaconUntil")
	hud:SetBeacon(type(beaconUntil) == "number" and beaconUntil > now())
end

-- The beacon ----------------------------------------------------------------------------------------------

local function teleport()
	local beaconUntil = RunState.Get("BeaconUntil")
	if type(beaconUntil) == "number" and beaconUntil > now() then
		Remotes.FireServer("TeleportToBeacon")
	end
end

-- Grapple Line ---------------------------------------------------------------------------------------------

local zipping: RBXScriptConnection? = nil

local function zip(to: Vector3, speed: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	if zipping then
		zipping:Disconnect()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "GrappleAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Grapple"
	velocity.Attachment0 = attachment
	velocity.MaxForce = 1e7
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.Parent = root
	local started = os.clock()
	local limit = (to - root.Position).Magnitude / math.max(speed, 1) + 0.8
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local function finish()
		if zipping then
			zipping:Disconnect()
			zipping = nil
		end
		velocity:Destroy()
		attachment:Destroy()
	end
	zipping = RunService.Heartbeat:Connect(function()
		if not root.Parent or humanoid.Health <= 0 or player:GetAttribute("Life") ~= "Alive" then
			finish()
			return
		end
		local offset = to - root.Position
		if offset.Magnitude < 3 or os.clock() - started > limit then
			finish()
			root.AssemblyLinearVelocity = if offset.Magnitude > 0.1 then offset.Unit * 8 else Vector3.zero
			return
		end
		velocity.VectorVelocity = offset.Unit * speed
	end)
end

-- Prompts --------------------------------------------------------------------------------------------------

local function applyForClass(prompt: ProximityPrompt)
	local forClass = prompt:GetAttribute("ForClass")
	if type(forClass) == "string" then
		prompt.Enabled = forClass == classOf()
	end
end

local function watchDevices(folder: Instance)
	for _, d in folder:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			applyForClass(d)
		end
	end
	folder.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("ProximityPrompt") then
			applyForClass(d)
		end
	end)
end

local function refreshPrompts()
	local folder = workspace:FindFirstChild("ClassDevices")
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				applyForClass(d)
			end
		end
	end
end

local function barricadeText(): string
	local recipe = Config.Get("Recipes", "Barricade")
	local m = Modifiers.PlayerValue(player, "BarricadeCost") or 1
	local parts = {}
	for _, id in Config.Ids("Resources") do
		local amount = recipe.Costs[id]
		if amount then
			table.insert(parts, `{math.max(1, math.ceil(amount * m - 1e-6))} {Config.Get("Resources", id).Name}`)
		end
	end
	return `Vent · {table.concat(parts, ", ")}`
end

local function onPromptShown(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("Kind")
	if kind == "Revive" or kind == "ReviveResident" then
		local seconds = Modifiers.PlayerValue(player, "ReviveSeconds")
		if type(seconds) == "number" and seconds > 0 and math.abs(prompt.HoldDuration - seconds) > 0.01 then
			prompt.HoldDuration = seconds -- the Medic revives in 1 s (the hold is the client's)
		end
	elseif kind == "Barricade" then
		prompt.ObjectText = barricadeText()
	end
end

-- Effects --------------------------------------------------------------------------------------------------

local FX_COLOURS: { [string]: Color3 } = {
	Heal = Color3.fromRGB(124, 255, 155),
	Pulse = Color3.fromRGB(124, 255, 155),
	Foam = Color3.fromRGB(240, 240, 232),
	Meal = Color3.fromRGB(242, 193, 78),
	Shield = Color3.fromRGB(110, 170, 255),
	Flare = Color3.fromRGB(232, 116, 59),
	Crate = Color3.fromRGB(242, 230, 201),
	Decon = Color3.fromRGB(180, 240, 90),
	Rally = Color3.fromRGB(242, 193, 78),
	Magnet = Color3.fromRGB(90, 220, 240),
	Rope = Color3.fromRGB(150, 116, 80),
	Tracer = Color3.fromRGB(255, 220, 120),
	ShockTracer = Color3.fromRGB(140, 200, 255),
	RepairBeam = Color3.fromRGB(124, 255, 155),
	Zap = Color3.fromRGB(140, 200, 255),
	Well = Color3.fromRGB(160, 100, 240),
	Teleport = Color3.fromRGB(120, 220, 255),
	Deploy = Color3.fromRGB(242, 193, 78),
	Overdrive = Color3.fromRGB(170, 150, 120),
}

local function folder(): Folder
	local f = fxFolder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ClassFx"
	made.Parent = workspace
	fxFolder = made
	return made
end

local function fxPart(name: string, colour: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = colour
	return part
end

local function ring(at: Vector3, radius: number, colour: Color3)
	local part = fxPart("Ring", colour)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, 2, 2)
	part.Transparency = 0.35
	part.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = folder()
	TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.6)
end

local function beam(from: Vector3, to: Vector3, colour: Color3, width: number, seconds: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local part = fxPart("Beam", colour)
	part.Size = Vector3.new(width, width, length)
	part.CFrame = CFrame.lookAt((from + to) / 2, to)
	part.Transparency = 0.2
	part.Parent = folder()
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 }):Play()
	Debris:AddItem(part, seconds + 0.05)
end

local function bolt(from: Vector3, to: Vector3, colour: Color3)
	local points = { from }
	local segments = 5
	for i = 1, segments - 1 do
		local p = from:Lerp(to, i / segments)
		table.insert(points, p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6)
	end
	table.insert(points, to)
	for i = 1, #points - 1 do
		beam(points[i], points[i + 1], colour, 0.18, 0.25)
	end
end

local function burst(at: Vector3, colour: Color3, count: number)
	local holder = fxPart("Burst", colour)
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = folder()
	emitter:Emit(count)
	Debris:AddItem(holder, 1.2)
end

local function onFx(_userId: number, _classId: string, kind: string, at: Vector3?, data: { [string]: any }?)
	local colour = FX_COLOURS[kind] or Color3.new(1, 1, 1)
	local d = data or {}
	local to = d.To
	if typeof(to) == "Vector3" and at then
		if kind == "Rope" then
			beam(at, to, colour, 0.12, 0.6)
		elseif kind == "RepairBeam" then
			beam(at, to, colour, 0.15, 0.4)
		elseif kind == "ShockTracer" then
			bolt(at, to, colour)
		else
			beam(at, to, colour, 0.08, 0.1)
		end
		return
	end
	if not at then
		return
	end
	local radius = if type(d.Radius) == "number" then d.Radius else nil
	if radius then
		ring(at, radius, colour)
	end
	if not radius or kind == "Zap" or kind == "Foam" then
		burst(at + Vector3.new(0, 2, 0), colour, if kind == "Foam" then 60 else 30)
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------------

function ClassController:Init(registry)
	input = registry.InputController
	camera = registry.CameraController
	hud = registry.HUDController
end

function ClassController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	input:On("Ability", abilityDown, abilityUp)
	input:On("Beacon", teleport)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("HUD", 30)
	local chip = gui and gui:FindFirstChild("Beacon")
	if chip and chip:IsA("ImageButton") then
		chip.Activated:Connect(teleport)
	end
	for _, name in { "Class", "ClassLevel" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshClass()
			refreshPrompts()
			refreshAbility()
		end)
	end
	refreshClass()
	Remotes.OnClient("Grapple", function(to: Vector3, speed: number)
		zip(to, speed)
	end)
	Remotes.OnClient("AbilityFx", onFx)
	Remotes.OnClient("ArcZap", function(from: Vector3, to: Vector3)
		bolt(from, to, Color3.fromRGB(140, 200, 255))
	end)
	ProximityPromptService.PromptShown:Connect(onPromptShown)
	local devices = workspace:FindFirstChild("ClassDevices")
	if devices then
		watchDevices(devices)
	end
	workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == "ClassDevices" then
			watchDevices(child)
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			local ok, err = pcall(refreshAbility)
			if not ok then
				log:Warn("ability: %s", tostring(err))
			end
		end
	end)
end

return ClassController
