--!strict
--[[
	DisasterController: what players see and hear of disasters and repairs (bible Sections 7, 10
	and 20). Run place only; Prompt 13. The server's DisasterService decides everything; this
	draws it from the Disasters collection and a few attributes.

	* World effects, made here on each client (workspace.LocalEffects.Disasters): flames, smoke
	  and embers in every cell of a burning room, scaled by the fire's strength, with a
	  flickering orange light; steam when a fire goes out; sparks and a flickering cold light in
	  a room with an electrical surge; a pulsing red alarm light in the Reactor Core during a
	  meltdown; dust when rubble falls and each time it is hit.
	* Tools in use (the ToolInUse attribute on any player): the Extinguisher sprays foam, the
	  Welder throws sparks, from the held tool's muzzle (or the hand). The local player's Welder
	  shows the room's HP filling over it (HUD.Templates.HealthBar); pointing at nothing that
	  needs it says so.
	* The meltdown: the HUD's Meltdown telegram in the banner's place (the countdown, the three
	  valves' lamps, what to do: all at once, or each held 10 s alone or in two), hidden while
	  the player is down; a plate over each valve (HUD.Templates.Valve).
	* The Command View: rooms on fire, melting down or surging blink (Section 7: active
	  disasters blink), and the mini-map blinks them too. Room labels show a status when the
	  overlay tab has nothing to say (ON FIRE 64%, MELTDOWN 0:42, SURGE, BLACKOUT, RUBBLE,
	  WRECKED, DARK); the room panel's Condition says what to do.
	* Digging through rubble needs a Drill or a Pickaxe: its prompt only shows for players who
	  carry one (everyone can smash it with a melee weapon).
	* Sounds (Section 20) play when Prompt 32 adds them to SoundService: FireBell, ReactorAlarm
	  (looped through a meltdown), Klaxon (a blackout), CaveIn, Sparks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bunker = require(Shared.Rules.Bunker)
local Config = require(Shared.Config)
local Disasters = require(Shared.Rules.Disasters)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))
local Movement = require(Lib:WaitForChild("Movement"))

local log = Log.new("DisasterController")
local player = Players.LocalPlayer

local DisasterController = {
	Name = "DisasterController",
	Dependencies = { "HUDController", "MiniMapController", "CommandViewController", "ReplicaController" },
}

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE_LIGHT = Color3.fromRGB(255, 140, 60)
local SURGE_LIGHT = Color3.fromRGB(150, 200, 255)
local ALARM_LIGHT = Color3.fromRGB(255, 40, 30)
local LEAF = Color3.fromHex("#6F9B4C")
local RUST = Color3.fromHex("#B5412B")
local NAVY = Color3.fromHex("#1B2A3A")
local MESSAGE_SECONDS = 4

local hud: any = nil
local miniMap: any = nil
local commandView: any = nil
local replica: any = nil

type Effect = { Parts: { BasePart }, Emitters: { ParticleEmitter }, Lights: { PointLight }, Kind: string, Level: number?, Shown: number? }

local effects: { [string]: Effect } = {} -- disaster id -> what is drawn for it
local blinking: { [string]: boolean } = {} -- room ids blinking now
local toolEffects: { [Player]: { Item: string, Parts: { Instance } } } = {}
local valvePlates: { [BasePart]: BillboardGui } = {}
local roomBar: { Gui: BillboardGui, Anchor: BasePart, Room: string?, HideAt: number }? = nil
local lastMessage = 0
local alarm: Sound? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function holder(): Folder
	local root = workspace:FindFirstChild("LocalEffects")
	if not (root and root:IsA("Folder")) then
		root = Instance.new("Folder")
		root.Name = "LocalEffects"
		root.Parent = workspace
	end
	local found = (root :: Folder):FindFirstChild("Disasters")
	if not (found and found:IsA("Folder")) then
		found = Instance.new("Folder")
		found.Name = "Disasters"
		found.Parent = root
	end
	return found :: Folder
end

local function play(name: string, looped: boolean?): Sound?
	local template = SoundService:FindFirstChild(name)
	if not (template and template:IsA("Sound")) then
		return nil
	end
	local sound = template:Clone()
	sound.Looped = looped == true
	sound.Parent = SoundService
	sound:Play()
	if not looped then
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	return sound
end

local function anchor(position: Vector3, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = holder()
	return part
end

local function emitter(parent: Instance, spec: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in spec do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function roomOf(roomId: string): any
	local room = replica:Get("Rooms", roomId)
	return if type(room) == "table" then room else nil
end

-- The cells of a room, as world floor centres.
local function cellsOf(roomId: string): { Vector3 }
	local room = roomOf(roomId)
	local list = {}
	if room then
		for offset = 0, (room.Span or 1) - 1 do
			table.insert(list, Grid.CellPosition(room.Floor, room.Column + offset))
		end
	end
	return list
end

local function clearEffect(id: string)
	local effect = effects[id]
	if not effect then
		return
	end
	effects[id] = nil
	for _, part in effect.Parts do
		part:Destroy()
	end
end

-- Fire ---------------------------------------------------------------------------------------------------

local FLAME_SPOTS = { Vector3.new(-9, 0.2, -6), Vector3.new(1, 0.2, -9), Vector3.new(9, 0.2, -4) }

local function makeFire(id: string, roomId: string): Effect
	local effect: Effect = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Fire" }
	for _, cell in cellsOf(roomId) do
		for i, spot in FLAME_SPOTS do
			local part = anchor(cell + spot, "Flame")
			table.insert(effect.Parts, part)
			table.insert(effect.Emitters, emitter(part, {
				Name = "Flames", Texture = FIRE_TEXTURE, LightEmission = 0.9, LightInfluence = 0,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 110)),
					ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 120, 40)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 30, 20)),
				}),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(0.45, 5.2), NumberSequenceKeypoint.new(1, 0.8) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(16, 16),
				Acceleration = Vector3.new(0, 5, 0), RotSpeed = NumberRange.new(-60, 60), Rotation = NumberRange.new(0, 360),
				EmissionDirection = Enum.NormalId.Top, Rate = 0,
			}))
			if i == 2 then
				table.insert(effect.Emitters, emitter(part, {
					Name = "Smoke", Texture = SMOKE_TEXTURE, LightEmission = 0, LightInfluence = 1,
					Color = ColorSequence.new(Color3.fromRGB(46, 42, 40), Color3.fromRGB(24, 22, 21)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 13) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(2.8, 4.2), Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(30, 30),
					Acceleration = Vector3.new(0, 1.5, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
					EmissionDirection = Enum.NormalId.Top, Rate = 0,
				}))
				table.insert(effect.Emitters, emitter(part, {
					Name = "Embers", Texture = SPARK_TEXTURE, LightEmission = 1, LightInfluence = 0,
					Color = ColorSequence.new(Color3.fromRGB(255, 170, 70)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
					Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(40, 40),
					Acceleration = Vector3.new(0, 2, 0), EmissionDirection = Enum.NormalId.Top, Rate = 0,
				}))
				local light = Instance.new("PointLight")
				light.Color = FIRE_LIGHT
				light.Range = 20
				light.Brightness = 1.5
				light.Shadows = false
				light.Parent = part
				table.insert(effect.Lights, light)
			end
		end
	end
	effects[id] = effect
	return effect
end

local function setFireStrength(effect: Effect, strength: number)
	local k = math.clamp(strength / 100, 0.15, 1)
	for _, e in effect.Emitters do
		if e.Name == "Flames" then
			e.Rate = 30 * k
		elseif e.Name == "Smoke" then
			e.Rate = 10 * k
		elseif e.Name == "Embers" then
			e.Rate = 10 * k
		end
	end
	if effect.Parts[1] then
		effect.Parts[1]:SetAttribute("Strength", strength)
	end
end

-- Floods and gas (Prompt 23) ---------------------------------------------------------------------------

local WATER = Color3.fromRGB(58, 118, 128)
local WATER_TOP = Color3.fromRGB(150, 205, 205)
local GAS = Color3.fromRGB(150, 172, 72)

-- A room's water: a block of it in every cell, its top a paler skin. animate() raises and lowers it.
local function makeFlood(id: string, roomId: string): Effect
	local effect: Effect = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Flood", Level = 0, Shown = 0 }
	local g = Grid.Tuning()
	for _, cell in cellsOf(roomId) do
		local water = anchor(cell, "Water")
		-- plain and see-through: Glass hides what is behind it and goes black from inside (playtest)
		water.Material = Enum.Material.SmoothPlastic
		water.Color = WATER
		water.Transparency = 0.42
		water.Size = Vector3.new(g.CellWidth - 0.4, 0.2, g.CellDepth - 0.4)
		water:SetAttribute("Floor", cell.Y)
		table.insert(effect.Parts, water)
		local top = anchor(cell, "WaterTop")
		top.Material = Enum.Material.SmoothPlastic
		top.Color = WATER_TOP
		top.Transparency = 0.55
		top.Size = Vector3.new(g.CellWidth - 0.4, 0.12, g.CellDepth - 0.4)
		top:SetAttribute("Floor", cell.Y)
		table.insert(effect.Parts, top)
		table.insert(effect.Emitters, emitter(top, {
			Name = "Ripples", Texture = SMOKE_TEXTURE, LightEmission = 0.3, LightInfluence = 1,
			Color = ColorSequence.new(Color3.fromRGB(215, 240, 238)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.9, 1.5), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180),
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, Rate = 0,
		}))
	end
	effects[id] = effect
	return effect
end

local function setFloodLevel(effect: Effect, level: number, pipe: boolean)
	effect.Level = level
	for _, e in effect.Emitters do
		e.Rate = if pipe then 14 else 5
	end
end

-- A room's gas: a slow cloud filling every cell, and a sick light.
local function makeGas(id: string, roomId: string): Effect
	local effect: Effect = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Gas" }
	local g = Grid.Tuning()
	for _, cell in cellsOf(roomId) do
		local part = anchor(cell + Vector3.new(0, g.CellHeight * 0.4, 0), "Gas")
		part.Size = Vector3.new(g.CellWidth - 4, g.CellHeight * 0.7, g.CellDepth - 6)
		table.insert(effect.Parts, part)
		table.insert(effect.Emitters, emitter(part, {
			Name = "Cloud", Texture = SMOKE_TEXTURE, LightEmission = 0.25, LightInfluence = 0.6,
			Color = ColorSequence.new(GAS, Color3.fromRGB(104, 128, 60)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 11) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.72), NumberSequenceKeypoint.new(0.8, 0.8), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(0.4, 1.2), SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-12, 12),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, Rate = 0,
		}))
		local light = Instance.new("PointLight")
		light.Color = GAS
		light.Range = 22
		light.Brightness = 0
		light.Shadows = false
		light.Parent = part
		table.insert(effect.Lights, light)
	end
	effects[id] = effect
	return effect
end

local function setGasStrength(effect: Effect, strength: number)
	local k = math.clamp(strength / 100, 0, 1)
	for _, e in effect.Emitters do
		e.Rate = 2 + 12 * k
	end
	for _, light in effect.Lights do
		light.Brightness = 0.9 * k
	end
end

-- A burst pipe sprays and a leaking vent hisses (the server's fittings in workspace.Bunker.Disasters).
local function watchFitting(item: Instance)
	local isPipe = string.sub(item.Name, 1, 5) == "Pipe:"
	local isVent = string.sub(item.Name, 1, 8) == "GasVent:"
	if not (isPipe or isVent) or item:FindFirstChild("SprayFx", true) then
		return
	end
	local base = if item:IsA("BasePart") then item elseif item:IsA("Model") then item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true) else nil
	if not base then
		return
	end
	-- the art's socket (a CFrame attribute about the model's pivot: Socket_Spray, Socket_Leak), else the block's face
	local socket = item:GetAttribute(if isPipe then "Socket_Spray" else "Socket_Leak")
	local from = Instance.new("Attachment")
	from.Name = "SprayFx"
	from.Parent = base
	if typeof(socket) == "CFrame" and item:IsA("Model") then
		from.WorldCFrame = item:GetPivot() * socket
	else
		from.CFrame = CFrame.new(0, 0, base.Size.Z / 2)
	end
	if isPipe then
		emitter(from, {
			Name = "Water", Texture = SMOKE_TEXTURE, LightEmission = 0.2, LightInfluence = 1,
			Color = ColorSequence.new(Color3.fromRGB(196, 232, 236), Color3.fromRGB(120, 180, 190)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2.6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(14, 20), SpreadAngle = Vector2.new(14, 14),
			Acceleration = Vector3.new(0, -34, 0), EmissionDirection = Enum.NormalId.Back, Rate = 70,
		})
	else
		emitter(from, {
			Name = "Gas", Texture = SMOKE_TEXTURE, LightEmission = 0.3, LightInfluence = 0.5,
			Color = ColorSequence.new(GAS),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 4.5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(6, 9), SpreadAngle = Vector2.new(18, 18),
			Acceleration = Vector3.new(0, -2, 0), EmissionDirection = Enum.NormalId.Back, Rate = 26,
		})
	end
	local sound = play(if isPipe then "WaterSpray" else "GasHiss", true)
	if sound then
		item.Destroying:Once(function()
			sound:Destroy()
		end)
	end
end

-- What the local player stands in: wading slows, gas greens the picture (not for the gas-immune).
local gasHaze: ColorCorrectionEffect? = nil
local function updateStanding()
	local wading = player:GetAttribute("Wading")
	Movement.Set("Wading", if type(wading) == "number" and Disasters.WadeSpeed(wading) < 1 then Disasters.WadeSpeed(wading) else nil)
	local inGas = player:GetAttribute("InGas")
	local k = if type(inGas) == "number" then math.clamp(inGas / 100, 0, 1) else 0
	if k <= 0 then
		if gasHaze then
			gasHaze:Destroy()
			gasHaze = nil
		end
		return
	end
	local haze = gasHaze
	if not haze then
		haze = Instance.new("ColorCorrectionEffect")
		haze.Name = "GasHaze"
		haze.Parent = game:GetService("Lighting")
		gasHaze = haze
	end
	haze.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(196, 222, 132), 0.75 * k)
	haze.Saturation = -0.25 * k
	haze.Contrast = -0.08 * k
end

local function steam(roomId: string)
	for _, cell in cellsOf(roomId) do
		local part = anchor(cell + Vector3.new(0, 1, -5), "Steam")
		local e = emitter(part, {
			Texture = SMOKE_TEXTURE, LightInfluence = 1,
			Color = ColorSequence.new(Color3.fromRGB(235, 235, 230)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top, Rate = 0,
		})
		e:Emit(40)
		task.delay(2.5, function()
			part:Destroy()
		end)
	end
end

-- Electrical surges and the meltdown ------------------------------------------------------------------------

local function makeSurge(id: string, roomId: string): Effect
	local effect: Effect = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Surge" }
	for _, cell in cellsOf(roomId) do
		local part = anchor(cell + Vector3.new(0, 7, -8), "Sparks")
		table.insert(effect.Parts, part)
		table.insert(effect.Emitters, emitter(part, {
			Name = "Sparks", Texture = SPARK_TEXTURE, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 250, 210), Color3.fromRGB(140, 200, 255)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.25, 0.6), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -40, 0), Rate = 0,
		}))
		local light = Instance.new("PointLight")
		light.Color = SURGE_LIGHT
		light.Range = 18
		light.Brightness = 0
		light.Shadows = false
		light.Parent = part
		table.insert(effect.Lights, light)
	end
	effects[id] = effect
	play("Sparks")
	return effect
end

local function makeMeltdown(id: string, roomId: string): Effect
	local effect: Effect = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Meltdown" }
	for _, cell in cellsOf(roomId) do
		local part = anchor(cell + Vector3.new(0, 12, -2), "Alarm")
		table.insert(effect.Parts, part)
		local light = Instance.new("PointLight")
		light.Color = ALARM_LIGHT
		light.Range = 40
		light.Brightness = 0
		light.Shadows = false
		light.Parent = part
		table.insert(effect.Lights, light)
		local core = anchor(cell + Vector3.new(0, 6, 6), "CoreSparks")
		table.insert(effect.Parts, core)
		table.insert(effect.Emitters, emitter(core, {
			Name = "Sparks", Texture = SPARK_TEXTURE, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(180, 255, 190), Color3.fromRGB(255, 120, 80)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.3, 0.8), Speed = NumberRange.new(8, 18), SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, -30, 0), Rate = 0,
		}))
	end
	effects[id] = effect
	return effect
end

-- Rubble: dust as it falls and when it is hit ---------------------------------------------------------------

local function dust(at: Vector3, amount: number)
	local part = anchor(at, "Dust")
	local e = emitter(part, {
		Texture = SMOKE_TEXTURE, LightInfluence = 1,
		Color = ColorSequence.new(Color3.fromRGB(150, 132, 112)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(70, 70), Rate = 0,
	})
	e:Emit(amount)
	task.delay(2.2, function()
		part:Destroy()
	end)
end

local watchedRubble: { [Model]: RBXScriptConnection } = {}

local function watchRubble(model: Instance)
	if not model:IsA("Model") or watchedRubble[model] or model:GetAttribute("Shape") == nil then
		return
	end
	local function blocks(): { BasePart }
		local list = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Block" then
				table.insert(list, child)
			end
		end
		return list
	end
	for _, block in blocks() do
		dust(block.Position, 50)
	end
	play("CaveIn")
	local last = model:GetAttribute("HP")
	watchedRubble[model] = model:GetAttributeChangedSignal("HP"):Connect(function()
		local hp = model:GetAttribute("HP")
		if type(hp) == "number" and type(last) == "number" and hp < last then
			for _, block in blocks() do
				dust(block.Position - Vector3.new(0, block.Size.Y / 4, 0), 14)
			end
		end
		last = hp
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			local connection = watchedRubble[model]
			if connection then
				connection:Disconnect()
			end
			watchedRubble[model] = nil
		end
	end)
end

-- Digging through rubble needs a Drill or a Pickaxe: the prompt shows only to players who carry one.
local function carried(): { string }
	local items = {}
	for i = 1, 5 do
		local item = player:GetAttribute(`Item{i}`)
		if type(item) == "string" then
			table.insert(items, item)
		end
	end
	local melee = player:GetAttribute("MeleeItem")
	if type(melee) == "string" then
		table.insert(items, melee)
	end
	return items
end

local digPrompts: { [ProximityPrompt]: boolean } = {}

local function gate(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Kind") == "DigRubble" then
		digPrompts[prompt] = true
		prompt.Enabled = Disasters.CanDig(carried())
		prompt.AncestryChanged:Connect(function()
			if not prompt:IsDescendantOf(workspace) then
				digPrompts[prompt] = nil
			end
		end)
	end
end

local function regate()
	local can = Disasters.CanDig(carried())
	for prompt in digPrompts do
		prompt.Enabled = can
	end
end

-- Valve plates ---------------------------------------------------------------------------------------------

local function template(name: string): Instance?
	local gui = hud:Gui()
	local templates = gui and gui:FindFirstChild("Templates")
	return templates and templates:FindFirstChild(name)
end

local function watchValve(part: Instance)
	if not part:IsA("BasePart") or valvePlates[part] or type(part:GetAttribute("Valve")) ~= "number" then
		return
	end
	local base = template("Valve")
	if not (base and base:IsA("BillboardGui")) then
		return
	end
	local plate = base:Clone()
	plate.Name = `ValvePlate{part:GetAttribute("Valve")}`
	plate.Adornee = part
	plate.Enabled = true
	plate.Parent = player:FindFirstChild("PlayerGui")
	valvePlates[part] = plate
	local label = plate:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = `VALVE {part:GetAttribute("Valve")}`
	end
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			plate:Destroy()
			valvePlates[part] = nil
		end
	end)
end

local function currentMeltdown(): any
	for _, entry in replica:All("Disasters") do
		if type(entry) == "table" and entry.Kind == "Meltdown" then
			return entry
		end
	end
	return nil
end

local function valveLook(value: number, t: number, solo: boolean): (string, string, number, Color3)
	-- lamp, words, gauge fill, words' colour
	if value == Disasters.HELD then
		return "Lamp_Green", "HELD", 1, LEAF
	elseif value > t then
		local left = value - t
		local full = Disasters.Tuning().Meltdown.SoloValveSeconds
		return if left < 3 then "Lamp_Amber" else "Lamp_Green", `TURNED · {math.ceil(left)} S`,
			if solo then math.clamp(left / full, 0, 1) else 1, LEAF
	end
	return "Lamp_Red", "OPEN · TURN ME", 0, RUST
end

local function updateMeltdown()
	local gui = hud:Gui()
	local panel = gui and gui:FindFirstChild("Meltdown")
	local entry = currentMeltdown()
	hud:HoldBanner("Meltdown", entry ~= nil)
	if entry and not alarm then
		alarm = play("ReactorAlarm", true)
	elseif not entry and alarm then
		alarm:Destroy()
		alarm = nil
	end
	local t = now()
	if panel then
		local life = player:GetAttribute("Life")
		panel.Visible = entry ~= nil and (life == nil or life == "Alive")
		if entry then
			local left = math.max(0, math.ceil((entry.EndsAt or t) - t))
			local count = panel:FindFirstChild("Count")
			if count then
				count.Text = string.format("%d:%02d", left // 60, left % 60)
				count.TextColor3 = if left <= 10 and left % 2 == 0 then Color3.fromHex("#F2C14E") else Color3.fromHex("#F2E6C9")
			end
			local text = panel:FindFirstChild("Text")
			if text then
				text.Text = if entry.Solo
					then `TURN ALL THREE VALVES · EACH STAYS TURNED {Disasters.Tuning().Meltdown.SoloValveSeconds} S`
					else "TURN ALL THREE VALVES IN THE REACTOR CORE AT ONCE"
			end
			local valves = panel:FindFirstChild("Valves")
			for i = 1, 3 do
				local frame = if valves then valves:FindFirstChild(`Valve{i}`) else nil
				local lamp = if frame then frame:FindFirstChild("Lamp") else nil
				if lamp and lamp:IsA("ImageLabel") then
					KitRuntime.SetSprite(lamp, (valveLook(entry.Valves and entry.Valves[i] or 0, t, entry.Solo == true)))
				end
			end
		end
	end
	for part, plate in valvePlates do
		local i = part:GetAttribute("Valve")
		local value = if entry and entry.Valves and type(i) == "number" then entry.Valves[i] or 0 else 0
		local lamp, words, fill, color = valveLook(value, t, entry ~= nil and entry.Solo == true)
		local lampImage = plate:FindFirstChild("Lamp", true)
		if lampImage and lampImage:IsA("ImageLabel") then
			KitRuntime.SetSprite(lampImage, lamp)
		end
		local state = plate:FindFirstChild("State", true)
		if state and state:IsA("TextLabel") then
			state.Text = words
			state.TextColor3 = color
		end
		local gauge = plate:FindFirstChild("Fill", true)
		if gauge and gauge:IsA("Frame") then
			gauge.Size = UDim2.fromScale(fill, 1)
		end
	end
end

-- Tools in use: foam and sparks --------------------------------------------------------------------------

local function nozzle(character: Model): Instance?
	local held = character:FindFirstChild("HeldItem")
	if held then
		local point = held:FindFirstChild("Muzzle", true) or held:FindFirstChild("Tip", true)
		if point and point:IsA("Attachment") then
			return point
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local at = root:FindFirstChild("ToolNozzle")
		if not at then
			at = Instance.new("Attachment")
			at.Name = "ToolNozzle"
			at.CFrame = CFrame.new(0.8, 0.4, -1.6)
			at.Parent = root
		end
		return at
	end
	return nil
end

local function stopToolEffect(who: Player)
	local entry = toolEffects[who]
	if entry then
		for _, item in entry.Parts do
			item:Destroy()
		end
		toolEffects[who] = nil
	end
end

local function startToolEffect(who: Player, item: string)
	stopToolEffect(who)
	local character = who.Character
	local at = character and nozzle(character)
	if not at then
		return
	end
	local parts: { Instance } = {}
	if item == "Extinguisher" then
		table.insert(parts, emitter(at, {
			Name = "Foam", Texture = SMOKE_TEXTURE, LightInfluence = 0.6, LightEmission = 0.1,
			Color = ColorSequence.new(Color3.fromRGB(250, 250, 245), Color3.fromRGB(215, 225, 230)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 3.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.45, 0.7), Speed = NumberRange.new(24, 32), SpreadAngle = Vector2.new(7, 7),
			Acceleration = Vector3.new(0, -12, 0), Drag = 2, EmissionDirection = Enum.NormalId.Front, Rate = 70,
			Rotation = NumberRange.new(0, 360),
		}))
	elseif item == "Welder" then
		table.insert(parts, emitter(at, {
			Name = "WeldSparks", Texture = SPARK_TEXTURE, LightEmission = 1, LightInfluence = 0,
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 170, 60)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
			Lifetime = NumberRange.new(0.2, 0.5), Speed = NumberRange.new(8, 16), SpreadAngle = Vector2.new(55, 55),
			Acceleration = Vector3.new(0, -35, 0), EmissionDirection = Enum.NormalId.Front, Rate = 90,
		}))
		local light = Instance.new("PointLight")
		light.Name = "WeldLight"
		light.Color = Color3.fromRGB(170, 210, 255)
		light.Range = 12
		light.Brightness = 2
		light.Shadows = false
		light.Parent = at
		table.insert(parts, light)
	end
	toolEffects[who] = { Item = item, Parts = parts }
end

local function watchToolUse(who: Player)
	local function refresh()
		local item = who:GetAttribute("ToolInUse")
		if type(item) == "string" then
			startToolEffect(who, item)
		else
			stopToolEffect(who)
		end
	end
	who:GetAttributeChangedSignal("ToolInUse"):Connect(refresh)
	refresh()
end

-- The Welder's progress over the room it repairs (the local player).
local function updateRoomBar()
	local welding = player:GetAttribute("Welding")
	local using = player:GetAttribute("ToolInUse")
	if using == "Welder" and welding == "" and os.clock() - lastMessage > MESSAGE_SECONDS then
		lastMessage = os.clock()
		hud:Alert("Info", "NOTHING IN FRONT OF YOU NEEDS REPAIRS")
	end
	if using == "Extinguisher" and player:GetAttribute("Spraying") == "" and os.clock() - lastMessage > MESSAGE_SECONDS then
		lastMessage = os.clock()
		hud:Alert("Info", "NO FIRE IN FRONT OF YOU")
	end
	local roomId = if using == "Welder" and type(welding) == "string" and welding ~= "" then welding else nil
	if roomId then
		local room = roomOf(roomId)
		if not room then
			return
		end
		if not roomBar then
			local base = template("HealthBar")
			if not (base and base:IsA("BillboardGui")) then
				return
			end
			local gui = base:Clone()
			gui.Name = "RoomRepairBar"
			gui.Size = UDim2.fromScale(10, 0.8)
			local part = anchor(Vector3.zero, "RepairBar")
			gui.Adornee = part
			gui.Parent = player:FindFirstChild("PlayerGui")
			roomBar = { Gui = gui, Anchor = part, Room = nil, HideAt = 0 }
		end
		local bar = roomBar :: any
		local low, high = Grid.CellPosition(room.Floor, room.Column), Grid.CellPosition(room.Floor, room.Column + (room.Span or 1) - 1)
		bar.Anchor.Position = (low + high) / 2 + Vector3.new(0, 8.5, 4) -- at eye height over the room's middle
		bar.Room = roomId
		bar.HideAt = os.clock() + 1.5
		bar.Gui.Enabled = true
		local fill = bar.Gui:FindFirstChild("Fill", true)
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.fromScale(math.clamp((room.HP or 0) / math.max(room.MaxHP or 1, 1), 0, 1), 1)
			fill.BackgroundColor3 = if room.Wrecked then RUST else LEAF
		end
	elseif roomBar and os.clock() > roomBar.HideAt then
		roomBar.Gui.Enabled = false
	end
end

-- The collection -----------------------------------------------------------------------------------------

local function blinkFor(entry: any): string?
	if type(entry) ~= "table" then
		return nil
	end
	if entry.Kind == "Fire" or entry.Kind == "Surge" or entry.Kind == "Meltdown" then
		return entry.Room
	elseif (entry.Kind == "Flood" and entry.Pipe) or (entry.Kind == "Gas" and entry.Leaking) then
		return entry.Room -- a pipe to patch, a vent to seal
	end
	return nil
end

local function sync()
	local entries = replica:All("Disasters")
	local wantBlink: { [string]: boolean } = {}
	for id, entry in entries do
		if type(entry) ~= "table" then
			continue
		end
		local room = blinkFor(entry)
		if room then
			wantBlink[room] = true
		end
		local effect = effects[id]
		if entry.Kind == "Fire" then
			if not effect then
				effect = makeFire(id, entry.Room)
				play("FireBell")
			end
			setFireStrength(effect :: Effect, entry.Strength or 50)
		elseif entry.Kind == "Flood" then
			if not effect then
				effect = makeFlood(id, entry.Room)
				play("FloodAlarm")
			end
			setFloodLevel(effect :: Effect, entry.Level or 0, entry.Pipe == true)
		elseif entry.Kind == "Gas" then
			if not effect then
				effect = makeGas(id, entry.Room)
				play("GasAlarm")
			end
			setGasStrength(effect :: Effect, entry.Strength or 0)
		elseif entry.Kind == "Surge" and not effect then
			makeSurge(id, entry.Room)
		elseif entry.Kind == "Meltdown" and not effect then
			makeMeltdown(id, entry.Room)
		elseif entry.Kind == "Blackout" and not effect then
			effects[id] = { Parts = {}, Emitters = {}, Lights = {}, Kind = "Blackout" }
			play("Klaxon")
		end
	end
	for id, effect in table.clone(effects) do
		if entries[id] == nil then
			if effect.Kind == "Fire" then
				local roomId = string.sub(id, 3)
				steam(roomId)
			end
			clearEffect(id)
		end
	end
	for room in wantBlink do
		if not blinking[room] then
			blinking[room] = true
			commandView:Blink(room, true)
			miniMap:Blink(room, true)
		end
	end
	for room in table.clone(blinking) do
		if not wantBlink[room] then
			blinking[room] = nil
			commandView:Blink(room, false)
			miniMap:Blink(room, false)
		end
	end
end

-- Lights flicker and the alarm pulses, every frame.
local underwater: ColorCorrectionEffect? = nil
local function animate()
	local t = os.clock()
	local under = false
	for _, effect in effects do
		if effect.Kind == "Flood" then
			-- the water climbs and falls smoothly between the server's levels
			local g = Grid.Tuning()
			local want = (effect.Level or 0) / 100 * g.CellHeight * Disasters.Tuning().Flood.WaterHeight
			local shown = effect.Shown or 0
			shown += (want - shown) * 0.06
			effect.Shown = shown
			local swell = math.sin(t * 1.7) * 0.06
			local eye = workspace.CurrentCamera.CFrame.Position
			for _, part in effect.Parts do
				if part.Name == "Water" and shown > 0.3 then
					local half = part.Size / 2
					local d = eye - part.Position
					if math.abs(d.X) <= half.X and math.abs(d.Y) <= half.Y and math.abs(d.Z) <= half.Z then
						under = true -- the camera is below this room's water
					end
				end
			end
			for _, part in effect.Parts do
				local floor = part:GetAttribute("Floor")
				if type(floor) == "number" then
					local tall = math.max(shown + swell, 0.05)
					if part.Name == "Water" then
						part.Size = Vector3.new(part.Size.X, tall, part.Size.Z)
						part.Position = Vector3.new(part.Position.X, floor + tall / 2, part.Position.Z)
					else
						part.Position = Vector3.new(part.Position.X, floor + tall + 0.02, part.Position.Z)
					end
				end
			end
		elseif effect.Kind == "Fire" then
			for i, light in effect.Lights do
				local strength = if effect.Parts[1] then effect.Parts[1]:GetAttribute("Strength") else nil
				local k = if type(strength) == "number" then math.clamp(strength / 100, 0.2, 1) else 0.6
				light.Brightness = (1.1 + 0.5 * math.noise(t * 6, i * 3.1)) * 1.6 * k
			end
		elseif effect.Kind == "Surge" then
			for i, light in effect.Lights do
				local flash = math.noise(t * 14, i * 7.3)
				light.Brightness = if flash > 0.25 then 3 else 0
				if flash > 0.3 and effect.Emitters[i] then
					effect.Emitters[i]:Emit(6)
				end
			end
		elseif effect.Kind == "Meltdown" then
			local pulse = (math.sin(t * math.pi * 2) + 1) / 2
			for _, light in effect.Lights do
				light.Brightness = 0.5 + pulse * 3
			end
			for _, e in effect.Emitters do
				if math.noise(t * 9, 1.7) > 0.35 then
					e:Emit(4)
				end
			end
		end
	end
	-- under the water the picture goes green-blue
	if under and not underwater then
		local tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "Underwater"
		tint.TintColor = Color3.fromRGB(128, 196, 204)
		tint.Brightness = -0.06
		tint.Contrast = -0.1
		tint.Parent = game:GetService("Lighting")
		underwater = tint
	elseif not under and underwater then
		underwater:Destroy()
		underwater = nil
	end
end

-- The Command View's statuses and notes ----------------------------------------------------------------

local function fluidAt(roomId: string): (any, any)
	local flood, gas = nil, nil
	for _, entry in replica:All("Disasters") do
		if type(entry) == "table" and entry.Room == roomId then
			if entry.Kind == "Flood" then
				flood = entry
			elseif entry.Kind == "Gas" then
				gas = entry
			end
		end
	end
	return flood, gas
end

local function disasterAt(roomId: string): (any, any, any)
	local fire, surge, melt = nil, nil, nil
	for _, entry in replica:All("Disasters") do
		if type(entry) == "table" and entry.Room == roomId then
			if entry.Kind == "Fire" then
				fire = entry
			elseif entry.Kind == "Surge" then
				surge = entry
			elseif entry.Kind == "Meltdown" then
				melt = entry
			end
		end
	end
	return fire, surge, melt
end

local function blackoutHas(roomId: string): boolean
	for _, entry in replica:All("Disasters") do
		if type(entry) == "table" and entry.Kind == "Blackout" and table.find(entry.Rooms or {}, roomId) then
			return true
		end
	end
	return false
end

local function rubbleBy(roomId: string): any
	for _, entry in replica:All("Disasters") do
		if type(entry) == "table" and entry.Kind == "Rubble" then
			for _, edge in entry.Edges or {} do
				local a, b = string.match(edge, "^(.-)|(.+)$")
				if a == roomId or b == roomId then
					return entry
				end
			end
		end
	end
	return nil
end

local function status(roomId: string, room: any): (string?, string?)
	local fire, surge, melt = disasterAt(roomId)
	if melt then
		local left = math.max(0, math.ceil((melt.EndsAt or now()) - now()))
		return "Lamp_Red", string.format("MELTDOWN %d:%02d", left // 60, left % 60)
	elseif fire then
		return "Lamp_Red", `ON FIRE {fire.Strength or 0}%`
	elseif surge then
		return "Lamp_Amber", "SURGE: WELD IT"
	end
	local flood, gas = fluidAt(roomId)
	if gas then
		return if gas.Leaking then "Lamp_Red" else "Lamp_Amber", if gas.Leaking then `GAS {gas.Strength or 0}%` else "AIRING OUT"
	elseif flood then
		return if flood.Pipe then "Lamp_Red" else "Lamp_Amber", if flood.Pipe then `FLOODING {flood.Level or 0}%` else `WATER {flood.Level or 0}%`
	end
	if room and room.Wrecked then
		return "Lamp_Red", "WRECKED"
	elseif blackoutHas(roomId) then
		return "Lamp_Amber", "BLACKOUT"
	elseif rubbleBy(roomId) then
		return "Lamp_Amber", "RUBBLE"
	end
	local power = replica:Get("Power", roomId)
	if type(power) == "table" and power.Dark then
		return "Lamp_Amber", "DARK"
	end
	return nil, nil
end

local function note(roomId: string): string?
	local lines = {}
	local fire, surge, melt = disasterAt(roomId)
	if melt then
		table.insert(lines, "Meltdown: turn the three valves in here together, or the bunker is lost.")
	end
	if fire then
		table.insert(lines, `On fire ({fire.Strength or 0}%): it spreads to the next room unless it is put out. Residents in here fight it; an Extinguisher or a Foam Grenade puts it out.`)
	end
	if surge then
		table.insert(lines, "Electrical surge: sparks wreck its machines. Weld it before it starts a fire or a blackout.")
	end
	local flood, gas = fluidAt(roomId)
	if flood then
		table.insert(lines, if flood.Pipe
			then `Flooding ({flood.Level or 0}%): a pipe has burst. Patch it and the room drains; left alone the water pours on, and down the Shaft.`
			else `Water ({flood.Level or 0}%): it drains once nothing pours in. Find the burst pipe it comes from.`)
	end
	if gas then
		table.insert(lines, if gas.Leaking
			then `Gas ({gas.Strength or 0}%): it hurts everyone in here. Seal the vent, or keep out until it airs out.`
			else `Gas ({gas.Strength or 0}%): the leak has stopped and the room is airing out.`)
	end
	if blackoutHas(roomId) then
		table.insert(lines, "Blackout: reset the fuse box in the Reactor Core.")
	end
	local r = rubbleBy(roomId)
	if r then
		table.insert(lines, `Rubble blocks {if r.Shape == "Tunnel" then "a tunnel" else "a doorway"} here ({r.HP} of {r.MaxHP}): smash it, or dig with a Drill or a Pickaxe.`)
	end
	local room = roomOf(roomId)
	if room and room.Wrecked then
		table.insert(lines, `Repair it with a Welder; it works again at {Bunker.RepairedAt(room.MaxHP or 0)} HP. Its residents repair it slowly.`)
	end
	return if #lines > 0 then table.concat(lines, "\n") else nil
end

-- Lifecycle ---------------------------------------------------------------------------------------------

function DisasterController:Init(registry)
	hud = registry.HUDController
	miniMap = registry.MiniMapController
	commandView = registry.CommandViewController
	replica = registry.ReplicaController
end

function DisasterController:Start()
	replica:Changed("Disasters"):Connect(function()
		local ok, err = pcall(sync)
		if not ok then
			log:Warn("sync: %s", tostring(err))
		end
	end)
	task.defer(sync)
	commandView:SetStatus("Disasters", status)
	commandView:SetConditionNote(note)

	-- the meltdown's valves and the rubble's dig prompts live in workspace.Bunker.Disasters
	local function watchFolder(folder: Instance)
		for _, item in folder:GetDescendants() do
			watchValve(item)
			gate(item)
		end
		for _, item in folder:GetChildren() do
			watchRubble(item)
			watchFitting(item)
		end
		folder.DescendantAdded:Connect(function(item: Instance)
			watchValve(item)
			gate(item)
			if item.Parent == folder then
				watchRubble(item)
				watchFitting(item)
			end
		end)
	end
	task.spawn(function()
		local bunker = workspace:WaitForChild("Bunker", 60)
		if not bunker then
			return
		end
		local existing = bunker:FindFirstChild("Disasters")
		if existing then
			watchFolder(existing)
		end
		bunker.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Disasters" then
				watchFolder(child)
			end
		end)
	end)
	for _, name in { "Item1", "Item2", "Item3", "Item4", "Item5", "MeleeItem" } do
		player:GetAttributeChangedSignal(name):Connect(regate)
	end
	player:GetAttributeChangedSignal("Wading"):Connect(updateStanding)
	player:GetAttributeChangedSignal("InGas"):Connect(updateStanding)
	updateStanding()

	for _, who in Players:GetPlayers() do
		watchToolUse(who)
	end
	Players.PlayerAdded:Connect(watchToolUse)
	Players.PlayerRemoving:Connect(stopToolEffect)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt: number)
		animate()
		acc += dt
		if acc >= 0.1 then
			acc = 0
			local ok, err = pcall(function()
				updateMeltdown()
				updateRoomBar()
			end)
			if not ok then
				log:Warn("update: %s", tostring(err))
			end
		end
	end)
	log:Debug("disaster display ready")
end

return DisasterController
