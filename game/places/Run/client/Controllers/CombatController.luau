--!strict
--[[
	CombatController: the local player's side of fighting (bible Section 9; Section 23: the
	client fires for instant feedback and sends only what it wants to do; the server checks).
	Run place only; Prompt 11.

	* Hotbar (1 to 5, the D-pad, a tap): the HUD's slots show what the player carries, a gun with
	  its rounds ("8/52": loaded and carried). Picking a slot asks the server to hold its item.
	* Fire (left mouse, the right trigger, the Fire button): with a gun held, a shot leaves the
	  muzzle toward what the reticle covers. The spread comes from the shot's seed (the server
	  makes the same), each pellet is raycast here at once (tracer, sparks, a hit marker on a
	  monster) and its hits go to the server, which checks them and confirms the damage
	  (HitConfirmed: the damage number, a kill marker). Automatic guns fire while held; an empty
	  magazine reloads instead. Recoil kicks the camera up. Flame guns burn a cone and launcher
	  rounds fly: the server works out what they hit.
	* Aim assist (Section 9): on a gamepad or touch, while aiming or firing, the camera is pulled
	  softly toward the monster nearest the aim, within AimAssistDegrees.
	* Reload (R, a tap of X): from carried ammo, over the gun's ReloadSeconds.
	* Throw (Landon, 2026-11-08): with a throwable's slot held, Fire throws one toward the
	  reticle, lofted so it lands there (ThrowSpeed, ThrowGravity). The slot shows "x2".
	* Tools (Prompt 13): with the tool slot held, holding Fire uses the tool (UseTool on, then
	  off on release) and the character faces where the camera looks: the Extinguisher sprays
	  the fire in front, the Welder repairs the room in front. The tool is held forward like a
	  gun (GunHold).
	* Heal (H, a hold of D-pad up, the Heal button; Landon, 2026-11-08): uses a carried Medkit
	  over MedkitSeconds, walking slower meanwhile. The HUD's Medkits chip shows the count and
	  fills while healing.
	* Melee (F, the right bumper, the Melee button): a tap swings light, and three light swings
	  chain into a combo; held past HeavyChargeSeconds it swings heavy (HeavySwingStamina).
	* Dodge (Ctrl, B, the Dodge button): a roll the way the player moves (backward when
	  standing), DodgeDistance in DodgeSeconds, when the stamina is there.
	* Sprint (hold Shift; the left stick click and the touch button toggle): SprintMultiplier
	  faster while stamina lasts, not while aiming or downed (Lib.Movement).
	* The HUD's stamina gauge follows the server's Stamina attribute.
	* Life (the server's Life attribute): Downed crawls (CrawlSpeed), can't jump, plays the
	  downed clip and shows the countdown; Dead shows the respawn countdown. The Humanoid's Dead
	  state is turned off for this client's character, so 0 health downs instead of killing.
	* Clips (Config.Animations, players' activities) play when they exist; without them the
	  game still works.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared.Rules.Combat)
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Movement = require(Lib:WaitForChild("Movement"))
local UIKit = require(Lib:WaitForChild("UIKit"))

local log = Log.new("CombatController")
local player = Players.LocalPlayer

local SLOTS = 5
local FACE_AFTER_SHOT = 0.8 -- seconds the character keeps facing the aim after a shot
local HIT_MARKER_SECONDS = 0.12
local KILL_MARKER_SECONDS = 0.3
local HEALTH_BAR_SECONDS = 4
local TRACER_SECONDS = 0.07
local CREAM = Color3.fromHex("F2E6C9")
local HAZARD = Color3.fromHex("F2C14E")
local SIGNAL = Color3.fromHex("E8743B")
local GLOW = Color3.fromHex("7CFF9B")

local CombatController = {
	Name = "CombatController",
	Dependencies = { "InputController", "CameraController", "HUDController" },
}

local input: any = nil
local camera: any = nil
local hud: any = nil

local t: { [string]: any } = {}
local p: { [string]: any } = {}

-- local state
local character: Model? = nil
local humanoidRef: Humanoid? = nil
local rootRef: BasePart? = nil
local animator: Animator? = nil
local tracks: { [string]: AnimationTrack } = {}
local holdTrack: string? = nil

local shotNext = 1
local lastShotAt = -math.huge
local fireHeld = false
local firePressed = false -- a new press, for guns that fire once per press
local faceUntil = 0
local magazines: { [number]: number } = {}
local swingEndsAt = 0
local comboStep = 0
local lastSwingEnd = -math.huge
local meleeDownAt: number? = nil
local dodgeUntil = 0
local sprintHeld = false
local sprintToggle = false
local sprinting = false
local savedJump: number? = nil
local syncingSlot = false
local healthBars: { [Model]: { Gui: BillboardGui, Until: number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function life(): string
	local value = player:GetAttribute("Life")
	return if type(value) == "string" then value else "Alive"
end

local function alive(): boolean
	return life() == "Alive" and humanoidRef ~= nil
end

local function selected(): number
	local value = player:GetAttribute("Slot")
	return if type(value) == "number" then value else 0
end

local function itemIn(slot: number): string?
	if slot < 1 then
		return nil
	end
	local value = player:GetAttribute(`Item{slot}`)
	return if type(value) == "string" then value else nil
end

local function countOf(slot: number): number
	local value = player:GetAttribute(`Count{slot}`)
	return if type(value) == "number" then value else 0
end

local function stamina(): number
	local value = player:GetAttribute("Stamina")
	return if type(value) == "number" then value else p.Stamina
end

local function carried(): number
	local value = player:GetAttribute("CarriedAmmo")
	return if type(value) == "number" then value else 0
end

local function reloading(): boolean
	local value = player:GetAttribute("ReloadEndsAt")
	return type(value) == "number" and value > now()
end

local function magazineOf(slot: number): number
	local local_ = magazines[slot]
	if local_ then
		return local_
	end
	local value = player:GetAttribute(`Mag{slot}`)
	return if type(value) == "number" then value else 0
end

-- Clips ----------------------------------------------------------------------------------------

local function track(activity: string): AnimationTrack?
	if tracks[activity] then
		return tracks[activity]
	end
	if not animator then
		return nil
	end
	local found: any = nil
	for _, clip in Config.All("Animations") do
		if clip.Activity == activity and clip.Rig == "R15" then
			found = clip
			break
		end
	end
	if not found then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = found.AssetId
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if not ok then
		log:Warn("couldn't load %s: %s", activity, tostring(loaded))
		return nil
	end
	loaded.Looped = found.Looped
	tracks[activity] = loaded
	return loaded
end

local function play(activity: string, length: number?, fade: number?)
	local clip = track(activity)
	if not clip then
		return
	end
	clip:Play(fade or 0.08)
	if length and length > 0 and clip.Length > 0 then
		clip:AdjustSpeed(clip.Length / length)
	end
end

local function stop(activity: string, fade: number?)
	local clip = tracks[activity]
	if clip and clip.IsPlaying then
		clip:Stop(fade or 0.15)
	end
end

-- The pose for what's held: a gun's hold or aim pose; nothing for a melee weapon.
local function updateHold()
	local item = itemIn(selected())
	local wanted: string? = nil
	local entry = if item then Config.Find("Items", item) else nil
	if alive() and Combat.Gun(item) and now() >= swingEndsAt then
		wanted = if camera:IsAiming() then "GunAim" else "GunHold"
	elseif alive() and entry and entry.Kind == "Tool" and now() >= swingEndsAt then
		wanted = "GunHold" -- tools are held forward like a gun (Prompt 13)
	end
	if wanted ~= holdTrack then
		if holdTrack then
			stop(holdTrack)
		end
		holdTrack = wanted
		if wanted then
			play(wanted, nil, 0.15)
		end
	end
end

-- Effects --------------------------------------------------------------------------------------

local function effectsFolder(): Folder
	local found = workspace:FindFirstChild("LocalEffects")
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = workspace
	return folder
end

local function tracer(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local beam = Instance.new("Part")
	beam.Name = "Tracer"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.07, 0.07, length)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	beam.Transparency = 0.2
	beam.Parent = effectsFolder()
	TweenService:Create(beam, TweenInfo.new(TRACER_SECONDS), { Transparency = 1, Size = Vector3.new(0.02, 0.02, length) }):Play()
	Debris:AddItem(beam, TRACER_SECONDS + 0.05)
end

local function spark(at: Vector3, normal: Vector3, color: Color3, count: number)
	local holder = Instance.new("Part")
	holder.Name = "Spark"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.lookAt(at, at + normal)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.12, 0.25)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = effectsFolder()
	emitter:Emit(count)
	Debris:AddItem(holder, 0.4)
end

local function muzzleFlash(muzzle: Attachment?)
	if not muzzle then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = HAZARD
	light.Range = 10
	light.Brightness = 3
	light.Parent = muzzle
	Debris:AddItem(light, 0.06)
	local flash = Instance.new("ParticleEmitter")
	flash.Color = ColorSequence.new(HAZARD, SIGNAL)
	flash.LightEmission = 1
	flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	flash.Lifetime = NumberRange.new(0.04, 0.06)
	flash.Speed = NumberRange.new(1, 2)
	flash.Rate = 0
	flash.Parent = muzzle
	flash:Emit(3)
	Debris:AddItem(flash, 0.2)
end

local function hudPart(path: string): Instance?
	local gui = player:FindFirstChild("PlayerGui")
	local node: Instance? = gui
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local markerToken = 0
local function hitMarker(kill: boolean)
	local sight = hudPart("Reticle.Sight")
	if not sight then
		return
	end
	local hit = sight:FindFirstChild("Hit") :: GuiObject?
	local killed = sight:FindFirstChild("Kill") :: GuiObject?
	markerToken += 1
	local token = markerToken
	if hit then
		hit.Visible = not kill
	end
	if killed then
		killed.Visible = kill
	end
	task.delay(if kill then KILL_MARKER_SECONDS else HIT_MARKER_SECONDS, function()
		if markerToken == token then
			if hit then
				hit.Visible = false
			end
			if killed then
				killed.Visible = false
			end
		end
	end)
end

local function template(name: string): Instance?
	local templates = hudPart("HUD.Templates")
	local found = templates and templates:FindFirstChild(name)
	return if found then found:Clone() else nil
end

local function damageNumber(at: Vector3, amount: number, kill: boolean)
	local gui = template("DamageNumber") :: BillboardGui?
	if not gui then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "DamageAt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = at + Vector3.new((math.random() - 0.5) * 1.2, 1, (math.random() - 0.5) * 1.2)
	anchor.Parent = effectsFolder()
	gui.Adornee = anchor
	gui.Enabled = true
	local label = gui:FindFirstChild("Value") :: TextLabel?
	if label then
		label.Text = tostring(math.max(1, math.floor(amount + 0.5)))
		label.TextColor3 = if kill then HAZARD else CREAM
		TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
		local outline = label:FindFirstChildOfClass("UIStroke")
		if outline then
			TweenService:Create(outline, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end
	gui.Parent = anchor
	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = anchor.Position + Vector3.new(0, 2.2, 0) }):Play()
	Debris:AddItem(anchor, 0.8)
end

local function modelOfCombatant(id: string): Model?
	for _, holder in { workspace:FindFirstChild("Dummies"), workspace:FindFirstChild("Monsters") } do
		if holder then
			for _, model in holder:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("CombatantId") == id then
					return model
				end
			end
		end
	end
	return nil
end

local function showHealth(model: Model)
	local entry = healthBars[model]
	if not entry then
		local gui = template("HealthBar") :: BillboardGui?
		local root = model.PrimaryPart
		if not gui or not root then
			return
		end
		local _, size = model:GetBoundingBox()
		gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1, 0)
		gui.Adornee = root
		gui.Enabled = true
		gui.Parent = player:FindFirstChild("PlayerGui")
		entry = { Gui = gui, Until = 0 }
		healthBars[model] = entry
	end
	local e = entry :: { Gui: BillboardGui, Until: number }
	if e.Gui.Parent ~= player:FindFirstChild("PlayerGui") then
		e.Gui.Parent = player:FindFirstChild("PlayerGui") -- billboards draw from PlayerGui with an Adornee
	end
	e.Until = os.clock() + HEALTH_BAR_SECONDS
	local health, max = model:GetAttribute("Health"), model:GetAttribute("MaxHealth")
	local fill = e.Gui:FindFirstChild("Fill", true) :: GuiObject?
	if fill and type(health) == "number" and type(max) == "number" and max > 0 then
		fill.Size = UDim2.fromScale(math.clamp(health / max, 0, 1), 1)
	end
end

local function flashModel(model: Model)
	local glow = Instance.new("Highlight")
	glow.FillColor = CREAM
	glow.FillTransparency = 0.45
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = model
	glow.Parent = effectsFolder()
	TweenService:Create(glow, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
	Debris:AddItem(glow, 0.2)
end

-- Guns -------------------------------------------------------------------------------------------

local function shotFilter(): RaycastParams
	local ignore: { Instance } = { effectsFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character) -- teammates: no friendly fire, shots pass by
		end
	end
	local bunker = workspace:FindFirstChild("Bunker")
	local residents = bunker and bunker:FindFirstChild("Residents")
	if residents then
		table.insert(ignore, residents)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function monsterOf(instance: Instance?): Model?
	local node = instance
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("Team") == "Monsters" and type(node:GetAttribute("CombatantId")) == "string" then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function muzzleAttachment(): Attachment?
	local held = character and character:FindFirstChild("HeldItem")
	local muzzle = held and held:FindFirstChild("Muzzle", true)
	return if muzzle and muzzle:IsA("Attachment") then muzzle else nil
end

local function reload()
	local slot = selected()
	local item = itemIn(slot)
	local gun = Combat.Gun(item)
	if not gun or not alive() or reloading() then
		return
	end
	if magazineOf(slot) >= gun.Magazine or carried() < gun.AmmoPerShot then
		return
	end
	Remotes.FireServer("ReloadWeapon")
	play("Reload", gun.ReloadSeconds)
end

local function fire(slot: number, item: string, gun: { [string]: any })
	local root = rootRef
	local ray = camera:AimRay()
	if not root or not ray then
		return
	end
	local muzzle = muzzleAttachment()
	local origin = if muzzle then muzzle.WorldPosition else root.Position + Vector3.new(0, 1.5, 0)
	local params = shotFilter()
	-- Where the reticle points: a ray from the camera, started level with the muzzle so
	-- nothing between the camera and the player can catch it.
	local direction = ray.Direction.Unit
	local start = ray.Origin + direction * math.max((origin - ray.Origin):Dot(direction), 0)
	local reach = gun.Range + 30
	local seen = workspace:Raycast(start, direction * reach, params)
	local aimPoint = if seen then seen.Position else start + direction * reach
	local aim = aimPoint - origin
	if aim.Magnitude < 0.5 then
		aim = direction
	end
	aim = aim.Unit

	local shot = shotNext
	shotNext += 1
	lastShotAt = os.clock()
	magazines[slot] = math.max(magazineOf(slot) - 1, 0)
	local claims = {}
	if gun.Cone then
		-- the flame: a short burst of glowing particles along the cone
		spark(origin, aim, SIGNAL, 6)
	elseif not gun.Projectile then
		local salt = player:GetAttribute("ShotSalt")
		local pellets = Combat.Spread(Combat.ShotSeed(if type(salt) == "number" then salt else 0, shot), aim, item)
		for index, pellet in pellets do
			local hit = workspace:Raycast(origin, pellet * gun.Range, params)
			local finish = if hit then hit.Position else origin + pellet * gun.Range
			tracer(origin, finish, HAZARD)
			if hit then
				local monster = monsterOf(hit.Instance)
				if monster then
					table.insert(claims, { Id = monster:GetAttribute("CombatantId") :: string, Point = hit.Position, Pellet = index })
					flashModel(monster)
					spark(hit.Position, hit.Normal, GLOW, 5)
				else
					spark(hit.Position, hit.Normal, HAZARD, 4)
				end
			end
		end
		if #claims > 0 then
			hitMarker(false)
		end
	end
	Remotes.FireServer("FireWeapon", slot, shot, origin, aim, now(), claims)
	muzzleFlash(muzzle)
	play("Fire", nil, 0.02)
	-- recoil: a kick up, more for heavier rounds
	local kick = math.clamp(gun.Damage / 20, 0.25, 2.2) * (if camera:IsAiming() then 0.6 else 1)
	camera:Nudge((math.random() - 0.5) * kick * 0.4, kick)
	faceUntil = os.clock() + FACE_AFTER_SHOT
	camera:Face("Fire", true)
end

-- Throwables: lofted toward what the reticle covers.
local lastThrowAt = -math.huge
local function throw(slot: number)
	local root = rootRef
	local ray = camera:AimRay()
	if not root or not ray or countOf(slot) <= 0 or os.clock() - lastThrowAt < t.ThrowCooldownSeconds then
		return
	end
	lastThrowAt = os.clock()
	local origin = root.Position + Vector3.new(0, 1.6, 0) + root.CFrame.RightVector * 0.8
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, shotFilter())
	local target = if hit then hit.Position else ray.Origin + ray.Direction * 60
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z).Magnitude
	local need = math.clamp(t.ThrowGravity * flat / (t.ThrowSpeed * t.ThrowSpeed), 0, 1)
	local loft = 0.5 * math.asin(need)
	local direction = (CFrame.lookAt(origin, target) * CFrame.Angles(loft, 0, 0)).LookVector
	camera:Face("Fire", true)
	faceUntil = os.clock() + 0.6
	play("Melee3", 0.35, 0.05) -- the overhead swing reads as a throw until A2's own clip
	Remotes.FireServer("ThrowItem", slot, origin, direction)
end

-- Tools (Prompt 13): Fire held with the tool slot uses it; the server does the work.
local toolOn = false
local function updateTool()
	local item = itemIn(selected())
	local entry = if item then Config.Find("Items", item) else nil
	local want = fireHeld and alive() and entry ~= nil and entry.Kind == "Tool" and now() >= swingEndsAt
		and os.clock() >= dodgeUntil
	if want ~= toolOn then
		toolOn = want
		Remotes.FireServer("UseTool", want)
		camera:Face("Tool", want)
	end
end

local function tryFire()
	local slot = selected()
	local item = itemIn(slot)
	local gun = Combat.Gun(item)
	local pressed = firePressed
	firePressed = false
	local entry = if item and not gun then Config.Find("Items", item) else nil
	if entry and entry.Kind == "Tool" then
		return -- updateTool
	end
	if entry and entry.Kind == "Throwable" then
		if pressed and alive() and now() >= swingEndsAt and os.clock() >= dodgeUntil then
			throw(slot)
		end
		return
	end
	if not gun or not item or not alive() or reloading() or now() < swingEndsAt or os.clock() < dodgeUntil then
		return
	end
	if magazineOf(slot) < 1 then
		if pressed then
			reload()
		end
		return
	end
	if not gun.Automatic and not pressed then
		return
	end
	if os.clock() - lastShotAt < Combat.Interval(item) then
		if not gun.Automatic and pressed then
			firePressed = true -- keep the press until the gun is ready
		end
		return
	end
	fire(slot, item, gun)
end

-- Aim assist: a soft pull toward the monster nearest the aim (gamepad and touch, Section 9).
local function assist(dt: number)
	local device = input:Device()
	if device == "Keyboard" or not (camera:IsAiming() or fireHeld) then
		return
	end
	local ray = camera:AimRay()
	if not ray then
		return
	end
	local points, models = {}, {}
	for _, holder in { workspace:FindFirstChild("Dummies"), workspace:FindFirstChild("Monsters") } do
		if holder then
			for _, model in holder:GetChildren() do
				if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("Team") == "Monsters" then
					table.insert(points, model.PrimaryPart.Position)
					table.insert(models, model)
				end
			end
		end
	end
	local index, angle = Combat.AssistTarget(ray.Origin, ray.Direction, points, p.AimAssistDegrees, 200)
	if not index or angle < 0.3 then
		return
	end
	local to = (points[index] - ray.Origin).Unit
	local look = ray.Direction.Unit
	local yawNow = math.atan2(-look.X, -look.Z)
	local yawTo = math.atan2(-to.X, -to.Z)
	local dYaw = (yawTo - yawNow + math.pi) % (2 * math.pi) - math.pi
	local dPitch = math.asin(math.clamp(to.Y, -1, 1)) - math.asin(math.clamp(look.Y, -1, 1))
	local share = math.min(t.AssistPullPerSecond * dt, 1)
	camera:Nudge(math.deg(dYaw) * share, math.deg(dPitch) * share)
end

-- Melee --------------------------------------------------------------------------------------

local function swing(heavy: boolean)
	if not alive() or now() < swingEndsAt or os.clock() < dodgeUntil then
		return
	end
	local item = player:GetAttribute("MeleeItem")
	local itemId = if type(item) == "string" then item else Combat.UNARMED
	if heavy and stamina() < p.HeavySwingStamina then
		heavy = false
	end
	local clock = now()
	local step = if heavy then 0 else Combat.NextCombo(comboStep, clock - lastSwingEnd)
	local _, length = Combat.Swing(itemId, heavy)
	comboStep = step
	swingEndsAt = clock + length
	lastSwingEnd = clock + length
	stop("MeleeCharge", 0.05)
	if holdTrack then
		stop(holdTrack, 0.05)
		holdTrack = nil
	end
	play(if heavy then "MeleeHeavy" else `Melee{step}`, length, 0.04)
	camera:Face("Swing", true)
	task.delay(length, function()
		if now() >= swingEndsAt - 0.01 then
			camera:Face("Swing", false)
		end
	end)
	local ray = camera:AimRay()
	local look = if ray then ray.Direction else Vector3.new(0, 0, -1)
	local flat = Vector3.new(look.X, 0, look.Z)
	Remotes.FireServer("MeleeSwing", heavy, if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1))
end

-- Dodge ----------------------------------------------------------------------------------------

local function dodge()
	local h, root = humanoidRef, rootRef
	if not alive() or not h or not root or os.clock() < dodgeUntil or now() < swingEndsAt then
		return
	end
	if stamina() < p.DodgeStamina or h.FloorMaterial == Enum.Material.Air then
		return
	end
	local move = h.MoveDirection
	local direction: Vector3
	if move.Magnitude > 0.1 then
		direction = Vector3.new(move.X, 0, move.Z).Unit
	else
		local ray = camera:AimRay()
		local look = if ray then ray.Direction else root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		direction = if flat.Magnitude > 1e-3 then -flat.Unit else -root.CFrame.LookVector
	end
	dodgeUntil = os.clock() + t.DodgeSeconds + t.DodgeCooldownSeconds
	Remotes.FireServer("Dodge", direction)
	play("Dodge", t.DodgeSeconds, 0.03)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DodgeAttachment"
	attachment.Parent = root
	local push = Instance.new("LinearVelocity")
	push.Name = "DodgePush"
	push.Attachment0 = attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	push.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	push.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	push.VectorVelocity = direction * (t.DodgeDistance / t.DodgeSeconds)
	push.Parent = root
	Debris:AddItem(push, t.DodgeSeconds)
	Debris:AddItem(attachment, t.DodgeSeconds)
end

-- Life: downed, dead, alive ---------------------------------------------------------------------

local function overlay()
	local gui = hudPart("HUD.Downed") :: GuiObject?
	if not gui then
		return
	end
	local state = life()
	gui.Visible = state ~= "Alive"
	if state == "Alive" then
		return
	end
	local endsAt = player:GetAttribute("LifeEndsAt")
	local left = if type(endsAt) == "number" then math.max(0, math.ceil(endsAt - now())) else 0
	local title = gui:FindFirstChild("Title") :: TextLabel?
	local body = gui:FindFirstChild("Text") :: TextLabel?
	local count = gui:FindFirstChild("Count") :: TextLabel?
	if title then
		title.Text = if state == "Downed" then "YOU'RE DOWN" else "YOU'RE OUT"
	end
	if body then
		body.Text = if state == "Downed" then "A TEAMMATE CAN REVIVE YOU. HOLD ON." else "BACK AT THE MEDBAY IN"
	end
	if count then
		count.Text = string.format("0:%02d", left)
	end
end

local function applyLife()
	local h = humanoidRef
	local state = life()
	if state ~= "Alive" then
		hud:SetVital("Health", 0, "0") -- the Humanoid stays at 1 while down (CombatService)
	end
	if state == "Downed" then
		Movement.Override("Downed", t.CrawlSpeed)
		Movement.Set("Sprint", nil)
		sprinting, sprintToggle = false, false
		fireHeld = false
		if h then
			if savedJump == nil then
				savedJump = if h.UseJumpPower then h.JumpPower else h.JumpHeight
			end
			if h.UseJumpPower then
				h.JumpPower = 0
			else
				h.JumpHeight = 0
			end
		end
		if holdTrack then
			stop(holdTrack)
			holdTrack = nil
		end
		play("Downed", nil, 0.2)
	else
		Movement.Override("Downed", nil)
		stop("Downed", 0.25)
		if h and savedJump ~= nil then
			if h.UseJumpPower then
				h.JumpPower = savedJump
			else
				h.JumpHeight = savedJump
			end
		end
		savedJump = nil
	end
	overlay()
end

-- The hotbar -----------------------------------------------------------------------------------

local function iconFor(item: string?): string?
	if not item then
		return nil
	end
	local named = `Icon_{item}`
	if UIKit.Sprites[named] then
		return named
	end
	local entry = Config.Find("Items", item)
	if entry and entry.Kind == "Gun" then
		return "Icon_Fire"
	elseif entry and entry.Kind == "Melee" then
		return "Icon_Melee"
	end
	return "Icon_Interact"
end

local function refreshHotbar()
	for i = 1, SLOTS do
		local item = itemIn(i)
		local gun = Combat.Gun(item)
		local ammo: string? = nil
		if gun then
			ammo = if reloading() and selected() == i then "RELOAD" else `{magazineOf(i)}/{carried()}`
		elseif item and i >= 4 then
			ammo = `x{countOf(i)}`
		end
		hud:SetSlot(i, iconFor(item), ammo)
	end
	local slot = selected()
	if slot >= 1 and hud:SelectedSlot() ~= slot then
		syncingSlot = true
		hud:SelectSlot(slot)
		syncingSlot = false
	end
end

-- Aiming: the upper body follows the camera's pitch ------------------------------------------------
-- The aim clip holds the gun straight and level (Landon, Nov 8: the aim looked crooked); while
-- aiming, the waist tips with the camera so the barrel points at the reticle up and down too.
-- Local only: other players see the clip's level aim.

local waistJoint: Instance? = nil -- a Motor6D, or the AnimationConstraint of Roblox's newer avatar joints
local waistBase: CFrame? = nil
local waistPitch = 0
local function aimPitch(dt: number)
	local character = player.Character
	local upper = character and character:FindFirstChild("UpperTorso")
	local joint = upper and upper:FindFirstChild("Waist")
	if joint ~= waistJoint then
		waistJoint = joint
		waistBase = nil
		waistPitch = 0
		if joint and joint:IsA("Motor6D") then
			waistBase = joint.C0
		elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
			waistBase = joint.Attachment0.CFrame
		end
	end
	if not joint or not waistBase then
		return
	end
	local want = 0
	if camera:IsAiming() and alive() then
		local ray = camera:AimRay()
		if ray then
			local y = math.clamp(ray.Direction.Unit.Y, -1, 1)
			want = math.clamp(math.asin(y), math.rad(-50), math.rad(50))
		end
	end
	if math.abs(want - waistPitch) < 1e-4 and want == 0 then
		return
	end
	waistPitch += (want - waistPitch) * math.min(1, dt * 12)
	local frame = waistBase * CFrame.Angles(waistPitch, 0, 0)
	if joint:IsA("Motor6D") then
		joint.C0 = frame
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then
		joint.Attachment0.CFrame = frame
	end
end

-- Medkits -----------------------------------------------------------------------------------------

local function healEndsAt(): number?
	local value = player:GetAttribute("HealEndsAt")
	return if type(value) == "number" and value > now() then value else nil
end

local function heal()
	if not alive() or healEndsAt() then
		return
	end
	Remotes.FireServer("UseMedkit")
end

local function refreshMedkits()
	local label = hudPart("HUD.Medkits.Count") :: TextLabel?
	if label then
		local value = player:GetAttribute("Medkits")
		label.Text = `x{if type(value) == "number" then value else 0}`
	end
end

local healing = false
local function updateHeal()
	local ends = healEndsAt()
	local on = ends ~= nil and alive()
	if on ~= healing then
		healing = on
		Movement.Set("Heal", if on then p.HealWalkMultiplier else nil)
	end
	local fill = hudPart("HUD.Medkits.Fill") :: GuiObject?
	if fill then
		fill.Visible = on
		if on and ends then
			local done = 1 - math.clamp((ends - now()) / p.MedkitSeconds, 0, 1)
			fill.Size = UDim2.fromScale(0.88 * done, fill.Size.Y.Scale) -- the chip's inner width
		end
	end
end

-- Character -------------------------------------------------------------------------------------

local function setCharacter(model: Model?)
	character = model
	humanoidRef, rootRef, animator = nil, nil, nil
	table.clear(tracks)
	holdTrack = nil
	savedJump = nil
	swingEndsAt, dodgeUntil = 0, 0
	sprinting, sprintToggle, sprintHeld = false, false, false
	Movement.Set("Sprint", nil)
	if not model then
		return
	end
	local h = model:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = model:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not root or character ~= model then
		return
	end
	-- 0 health downs a player instead of killing them (CombatService)
	h:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	h.BreakJointsOnDeath = false
	humanoidRef, rootRef = h, root
	animator = h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator", 5) :: Animator?
	table.clear(magazines)
	local next_ = player:GetAttribute("ShotNext")
	if type(next_) == "number" then
		shotNext = next_
	end
	Movement.Apply()
	applyLife()
	refreshHotbar()
end

-- Lifecycle ---------------------------------------------------------------------------------------

-- Kneel while holding a revive prompt (PromptController).
function CombatController:Kneel(on: boolean)
	if on and alive() then
		play("Revive", nil, 0.15)
	else
		stop("Revive", 0.15)
	end
end

function CombatController:Init(registry)
	input = registry.InputController
	camera = registry.CameraController
	hud = registry.HUDController
	t = Combat.Tuning()
	p = Config.Get("Tuning", "Player")
end

-- Both hands on a big find (Prompt 16): no firing, reloading, swinging, rolling or healing.
local function handsBusy(): boolean
	return player:GetAttribute("Carrying") ~= nil
end

function CombatController:Start()
	-- input
	input:On("Fire", function()
		if handsBusy() then
			return
		end
		fireHeld = true
		firePressed = true
	end, function()
		fireHeld = false
	end)
	input:On("Reload", function()
		if not handsBusy() then
			reload()
		end
	end)
	input:On("Melee", function()
		if handsBusy() then
			return
		end
		meleeDownAt = os.clock()
		local pressedAt = meleeDownAt
		task.delay(t.HeavyChargeSeconds, function()
			if meleeDownAt == pressedAt and alive() and stamina() >= p.HeavySwingStamina then
				play("MeleeCharge", nil, 0.1)
			end
		end)
	end, function()
		local pressedAt = meleeDownAt
		meleeDownAt = nil
		if pressedAt then
			swing(os.clock() - pressedAt >= t.HeavyChargeSeconds)
		end
	end)
	input:On("Dodge", function()
		if not handsBusy() then
			dodge()
		end
	end)
	input:On("Heal", function()
		if not handsBusy() then
			heal()
		end
	end)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		if handsBusy() then
			fireHeld = false
			firePressed = false
			meleeDownAt = nil
		end
	end)
	input:On("Sprint", function()
		if input:Device() == "Gamepad" then
			sprintToggle = not sprintToggle
		else
			sprintHeld = true
		end
	end, function()
		sprintHeld = false
	end)
	hud.HotbarSelected:Connect(function(index: number)
		if syncingSlot then
			return
		end
		if index ~= selected() then
			Remotes.FireServer("SelectSlot", index)
		end
	end)

	-- server state
	for _, name in { "Slot", "Item1", "Item2", "Item3", "Item4", "Item5", "Count4", "Count5", "CarriedAmmo", "ReloadEndsAt" } do
		player:GetAttributeChangedSignal(name):Connect(refreshHotbar)
	end
	player:GetAttributeChangedSignal("Medkits"):Connect(refreshMedkits)
	for slot = 1, 2 do
		player:GetAttributeChangedSignal(`Mag{slot}`):Connect(function()
			magazines[slot] = nil -- the server's count wins
			refreshHotbar()
		end)
	end
	player:GetAttributeChangedSignal("ShotNext"):Connect(function()
		local value = player:GetAttribute("ShotNext")
		if type(value) == "number" and value > shotNext then
			shotNext = value -- a shot the server didn't take: catch up
		end
	end)
	player:GetAttributeChangedSignal("Stamina"):Connect(function()
		hud:SetVital("Stamina", math.clamp(stamina() / p.Stamina, 0, 1))
	end)
	player:GetAttributeChangedSignal("Life"):Connect(applyLife)
	Remotes.OnClient("HitConfirmed", function(targetId: any, damage: any, killed: any, point: any)
		if type(targetId) ~= "string" or type(damage) ~= "number" then
			return
		end
		local model = modelOfCombatant(targetId)
		local at = if typeof(point) == "Vector3" then point elseif model and model.PrimaryPart then model.PrimaryPart.Position else nil
		if at then
			damageNumber(at, damage, killed == true)
		end
		if killed == true then
			hitMarker(true)
		end
		if model and killed ~= true then
			showHealth(model)
		end
	end)

	player.CharacterAdded:Connect(setCharacter)
	if player.Character then
		task.spawn(setCharacter, player.Character)
	end
	-- the HUD finds its ScreenGui after the controllers start: fill the hotbar and the stamina
	-- gauge once it is there
	task.spawn(function()
		while not hud:Gui() do
			task.wait(0.2)
		end
		refreshHotbar()
		refreshMedkits()
		hud:SetVital("Stamina", math.clamp(stamina() / p.Stamina, 0, 1))
	end)

	local lastSecond = -1
	RunService.RenderStepped:Connect(function(dt)
		if fireHeld or firePressed then
			tryFire()
		end
		updateTool()
		if os.clock() > faceUntil then
			camera:Face("Fire", false)
		end
		assist(dt)
		updateHold()
		updateHeal()
		aimPitch(dt)
		-- sprint
		local h = humanoidRef
		local moving = h ~= nil and h.MoveDirection.Magnitude > 0.1
		if sprintToggle and not moving then
			sprintToggle = false
		end
		local want = (sprintHeld or sprintToggle) and moving and alive() and stamina() > 0 and not camera:IsAiming()
		if want ~= sprinting then
			sprinting = want
			if not want then
				sprintToggle = false
			end
			Movement.Set("Sprint", if want then t.SprintMultiplier else nil)
			Remotes.FireServer("Sprint", want)
		end
		-- countdowns and fading health bars
		local second = math.floor(os.clock())
		if second ~= lastSecond then
			lastSecond = second
			if life() ~= "Alive" then
				overlay()
			end
		end
		for model, entry in healthBars do
			if os.clock() > entry.Until or model.Parent == nil then
				entry.Gui:Destroy()
				healthBars[model] = nil
			end
		end
	end)
	log:Info("combat controls ready")
end

return CombatController
