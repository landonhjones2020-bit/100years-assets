--!strict
--[[
	ThreatController: what players see of the Threat Director (bible Sections 7 and 10). Run
	place only; Prompt 12.

	* A breach warning (BreachService's BreachWarning: Section 10's 10 seconds of cracks, dust
	  and rumble, with an alert on the HUD and the mini-map): a Danger alert ("BREACH IN 10 S:
	  KITCHEN · 4 MONSTERS"), a pin on the mini-map and the room's block blinking until the
	  monsters come out.
	* The Command View's Threat overlay (Section 7: likely breach points): a room with monsters
	  in it reads "3 MONSTERS" in red; a breach on its way "BREACH 7 S" in red; a dark room's vent
	  (twice as likely, Section 6) "LIKELY" in amber; any other vent "VENT" in green.
	* Spitter goo's slow on the local player (the SlowedUntil attribute) through Lib.Movement.
	* The Crystal Hollows (Prompt 24): a dead Shardling's burst of shards (Shattered), a Prism
	  Stalker all but unseen while Hidden (only its Glint parts catch the light), a small gun's
	  shot glancing off a Geode Golem (ShruggedAt), a Resonator's hum ring (HumAt) and its light on
	  the monsters it reached (HummedAt), and the Crystal Colossus's stun on the local player
	  (StunnedUntil: no walking).
	* The Flooded Caverns' monsters (Prompt 23), from attributes MonsterService sets on their models:
	  - Hidden (a Lurker lying in wait): it fades to almost nothing and casts no shadow; its lure
	    stays faintly lit (the one thing a careful player can spot), and it isn't counted in the
	    Threat overlay;
	  - ShellHitAt and WeakHitAt (a Tide Crab): sparks off its shell where a hit from in front
	    glanced off, a green burst from its back where one got through;
	  - Burst (a Bloat Toad going off): a burst of water where it stood, and the camera shakes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local Movement = require(Lib:WaitForChild("Movement"))

local log = Log.new("ThreatController")

local ThreatController = {
	Name = "ThreatController",
	Dependencies = { "HUDController", "MiniMapController", "CommandViewController", "ReplicaController", "CameraController" },
}

local NO_VENT: { [string]: boolean } = { Shaft = true, BlastDoor = true }

local hud: any = nil
local miniMap: any = nil
local commandView: any = nil
local replica: any = nil
local camera: any = nil
local player = Players.LocalPlayer

-- monsters per room, from the monster models' positions (counted a few times a second)
local perRoom: { [string]: number } = {}

local function countMonsters()
	table.clear(perRoom)
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then
		return
	end
	local rooms = replica:All("Rooms")
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("MonsterType") and not model:GetAttribute("Hidden") then
			local floor, column = Grid.CellAt(model:GetPivot().Position)
			if floor and column then
				for id, room in rooms do
					if type(room) == "table" and room.Floor == floor and column >= room.Column
						and column < room.Column + (room.Span or 1) then
						perRoom[id] = (perRoom[id] or 0) + 1
					end
				end
			end
		end
	end
end

local function warningFor(roomId: string): number?
	local warning = replica:Get("Breaches", `V:{roomId}`)
	if type(warning) == "table" and type(warning.EndsAt) == "number" then
		local left = warning.EndsAt - workspace:GetServerTimeNow()
		if left > 0 then
			return left
		end
	end
	return nil
end

-- The Flooded Caverns' monsters ------------------------------------------------------------------

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local HIDDEN_BODY, HIDDEN_GLOW, HIDDEN_LURE = 0.95, 0.93, 0.35 -- how far each kind of part fades
local HIDDEN_UNSEEN, HIDDEN_GLINT = 0.985, 0.8 -- a Prism Stalker's body and its glints (Prompt 24)
local CRYSTAL = Color3.fromRGB(176, 238, 234)
local FADE_PER_SECOND = 2.5

type Watched = {
	Connections: { RBXScriptConnection },
	Fade: number, -- 0 seen, 1 hidden
	Target: number,
	Shadows: { BasePart }, -- parts whose shadow is off while it hides
	Unseen: boolean?, -- a Prism Stalker: nearly nothing shows
}
local watched: { [Model]: Watched } = {}

local function rootOf(model: Model): BasePart?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function applyFade(model: Model, w: Watched)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			-- a Prism Stalker (Prompt 24) is all but unseen: only its Glint parts catch the light
			local most = if string.find(part.Name, "Lure") then HIDDEN_LURE
				elseif string.find(part.Name, "Glint") then HIDDEN_GLINT
				elseif w.Unseen then HIDDEN_UNSEEN
				elseif part.Material == Enum.Material.Neon then HIDDEN_GLOW
				else HIDDEN_BODY
			part.LocalTransparencyModifier = most * w.Fade
		end
	end
end

local function setHidden(model: Model, w: Watched, hidden: boolean)
	w.Target = if hidden then 1 else 0
	if hidden then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.CastShadow then
				part.CastShadow = false
				table.insert(w.Shadows, part)
			end
		end
	else
		for _, part in w.Shadows do
			part.CastShadow = true
		end
		table.clear(w.Shadows)
	end
end

-- A short burst of particles at a point, on a part of its own that cleans itself up.
local function puff(at: Vector3, life: number, make: (part: Part) -> ())
	local part = Instance.new("Part")
	part.Name = "MonsterFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at)
	part.Parent = workspace.CurrentCamera or workspace
	make(part)
	task.delay(life, function()
		part:Destroy()
	end)
end

local function sparks(model: Model, weak: boolean)
	local root = rootOf(model)
	if not root then
		return
	end
	local socket = model:GetAttribute("Socket_Back")
	local at = if weak and typeof(socket) == "CFrame" then (model:GetPivot() * socket).Position
		elseif weak then (root.CFrame * CFrame.new(0, 1, 3)).Position
		else (root.CFrame * CFrame.new(0, 0.5, -4)).Position
	puff(at, 1.2, function(part: Part)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(if weak then Color3.fromRGB(124, 255, 155) else Color3.fromRGB(255, 226, 150))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if weak then 0.5 else 0.22), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.25, 0.55)
		e.Speed = NumberRange.new(14, 30)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0, -50, 0)
		e.Drag = 2
		e.Rate = 0
		e.Parent = part
		e:Emit(if weak then 16 else 12)
	end)
end

local function waterBurst(model: Model)
	local at = model:GetPivot().Position + Vector3.new(0, 2, 0)
	puff(at, 3.5, function(part: Part)
		part.Size = Vector3.new(6, 2, 6)
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = SMOKE
		mist.Color = ColorSequence.new(Color3.fromRGB(196, 232, 236), Color3.fromRGB(120, 180, 190))
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) })
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		mist.Lifetime = NumberRange.new(0.8, 1.6)
		mist.Speed = NumberRange.new(12, 26)
		mist.SpreadAngle = Vector2.new(180, 180)
		mist.Drag = 3
		mist.Rate = 0
		mist.Parent = part
		local drops = Instance.new("ParticleEmitter")
		drops.Color = ColorSequence.new(Color3.fromRGB(210, 240, 244))
		drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
		drops.Lifetime = NumberRange.new(0.6, 1.2)
		drops.Speed = NumberRange.new(26, 46)
		drops.SpreadAngle = Vector2.new(75, 75)
		drops.Acceleration = Vector3.new(0, -90, 0)
		drops.Rate = 0
		drops.Parent = part
		mist:Emit(40)
		drops:Emit(70)
	end)
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if me and me:IsA("BasePart") and (me.Position - at).Magnitude < 40 then
		camera:Shake(0.9, 0.7)
	end
end

-- The Crystal Hollows' monsters (Prompt 24) --------------------------------------------------------------

-- A dead Shardling shatters: a ring of flying shards and a flash where it stood.
local function shatterBurst(model: Model)
	local at = model:GetPivot().Position + Vector3.new(0, 1, 0)
	puff(at, 1.6, function(part: Part)
		local shards = Instance.new("ParticleEmitter")
		shards.Color = ColorSequence.new(CRYSTAL)
		shards.LightEmission = 0.8
		shards.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.1) })
		shards.Lifetime = NumberRange.new(0.35, 0.7)
		shards.Speed = NumberRange.new(22, 38)
		shards.SpreadAngle = Vector2.new(180, 30)
		shards.Rotation = NumberRange.new(0, 360)
		shards.RotSpeed = NumberRange.new(-400, 400)
		shards.Acceleration = Vector3.new(0, -40, 0)
		shards.Drag = 1.5
		shards.Rate = 0
		shards.Parent = part
		local flash = Instance.new("PointLight")
		flash.Color = CRYSTAL
		flash.Range = 14
		flash.Brightness = 4
		flash.Parent = part
		shards:Emit(34)
		task.delay(0.15, function()
			flash.Enabled = false
		end)
	end)
end

-- A small gun's shot glancing off a Geode Golem.
local function ricochet(model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	local cameraNow = workspace.CurrentCamera
	local towards = if cameraNow then (cameraNow.CFrame.Position - root.Position) else Vector3.new(0, 0, 1)
	local flat = Vector3.new(towards.X, 0, towards.Z)
	local at = root.Position + (if flat.Magnitude > 0.1 then flat.Unit * 3 else Vector3.zero) + Vector3.new(0, 1.5, 0)
	puff(at, 1, function(part: Part)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 236, 190))
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.15, 0.4)
		e.Speed = NumberRange.new(18, 34)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Acceleration = Vector3.new(0, -60, 0)
		e.Rate = 0
		e.Parent = part
		e:Emit(8)
	end)
end

-- A Resonator's hum: a ring running out along the floor to its Range.
local function humRing(model: Model)
	local root = rootOf(model)
	local entry = Config.Find("Monsters", tostring(model:GetAttribute("MonsterType")))
	if not root or not entry then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "HumRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = CRYSTAL
	ring.Transparency = 0.55
	local floorY = model:GetPivot().Position.Y + 0.25
	local centre = Vector3.new(root.Position.X, floorY, root.Position.Z)
	ring.Parent = workspace.CurrentCamera or workspace
	local started = os.clock()
	local seconds = 0.9
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - started) / seconds, 0, 1)
		local radius = 2 + (entry.Range - 2) * (1 - (1 - k) * (1 - k))
		ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
		ring.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.55 + 0.45 * k
		if k >= 1 then
			if connection then
				connection:Disconnect()
			end
			ring:Destroy()
		end
	end)
end

-- A monster the hum reached: a breath of crystal light on it.
local function hummed(model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	puff(root.Position, 1.2, function(part: Part)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(CRYSTAL)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Speed = NumberRange.new(2, 6)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 10, 0)
		e.Rate = 0
		e.Parent = part
		e:Emit(10)
	end)
end

local function watchMonster(model: Instance)
	if not model:IsA("Model") or watched[model] or model:GetAttribute("MonsterType") == nil then
		return
	end
	local w: Watched = { Connections = {}, Fade = 0, Target = 0, Shadows = {} }
	local entry = Config.Find("Monsters", tostring(model:GetAttribute("MonsterType")))
	w.Unseen = entry ~= nil and entry.Traits ~= nil and table.find(entry.Traits, "Invisible") ~= nil
	watched[model] = w
	table.insert(w.Connections, model:GetAttributeChangedSignal("Shattered"):Connect(function()
		if model:GetAttribute("Shattered") then
			shatterBurst(model)
		end
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("ShruggedAt"):Connect(function()
		ricochet(model)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("HumAt"):Connect(function()
		humRing(model)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("HummedAt"):Connect(function()
		hummed(model)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("Hidden"):Connect(function()
		setHidden(model, w, model:GetAttribute("Hidden") == true)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("ShellHitAt"):Connect(function()
		sparks(model, false)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("WeakHitAt"):Connect(function()
		sparks(model, true)
	end))
	table.insert(w.Connections, model:GetAttributeChangedSignal("Burst"):Connect(function()
		if model:GetAttribute("Burst") then
			waterBurst(model)
		end
	end))
	table.insert(w.Connections, model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			for _, c in w.Connections do
				c:Disconnect()
			end
			watched[model] = nil
		end
	end))
	if model:GetAttribute("Hidden") == true then
		setHidden(model, w, true)
		w.Fade = 1
		applyFade(model, w)
	end
end

function ThreatController:Init(registry)
	hud = registry.HUDController
	miniMap = registry.MiniMapController
	commandView = registry.CommandViewController
	replica = registry.ReplicaController
	camera = registry.CameraController
end

function ThreatController:Start()
	Remotes.OnClient("BreachWarning", function(floor: any, column: any, seconds: any, place: any, count: any, roomId: any)
		if type(floor) ~= "number" or type(column) ~= "number" or type(seconds) ~= "number" then
			return
		end
		local where = if type(place) == "string" then place else "THE BUNKER"
		local how = if type(count) == "number" then ` · {count} {if count == 1 then "MONSTER" else "MONSTERS"}` else ""
		hud:Alert("Danger", `BREACH IN {math.floor(seconds + 0.5)} S: {where}{how}`, seconds)
		miniMap:Ping(floor, column)
		local key = if type(roomId) == "string" then roomId else `{floor},{column}`
		miniMap:Blink(key, true)
		task.delay(seconds + 2, function()
			miniMap:Blink(key, false)
		end)
	end)

	commandView:SetOverlay("Threat", function(roomId: string, room: any): (string?, string?)
		local n = perRoom[roomId] or 0
		if n > 0 then
			return "Lamp_Red", if n == 1 then "1 MONSTER" else `{n} MONSTERS`
		end
		local left = warningFor(roomId)
		if left then
			return "Lamp_Red", `BREACH {math.ceil(left)} S`
		end
		if NO_VENT[room.Type] then
			return nil, nil
		end
		local power = replica:Get("Power", roomId)
		if type(power) == "table" and power.Dark then
			return "Lamp_Amber", "LIKELY"
		end
		return "Lamp_Green", "VENT"
	end)

	-- Spitter goo slows the local player (MonsterService sets SlowedUntil)
	local slowed = false
	local last = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() - last < 0.25 then
			return
		end
		last = os.clock()
		pcall(countMonsters)
		local untilAt = player:GetAttribute("SlowedUntil")
		local on = type(untilAt) == "number" and untilAt > workspace:GetServerTimeNow()
		if on ~= slowed then
			slowed = on
			Movement.Set("Slowed", if on then Config.Get("Tuning", "MonsterAI").GooSlowMultiplier else nil)
		end
	end)
	-- the Crystal Colossus's shards stun the local player (BossService sets StunnedUntil; Prompt 24):
	-- no walking until it passes (the server refuses their shots and swings meanwhile)
	local stunned = false
	local function readStun()
		local untilAt = player:GetAttribute("StunnedUntil")
		local left = if type(untilAt) == "number" then untilAt - workspace:GetServerTimeNow() else 0
		local on = left > 0
		if on ~= stunned then
			stunned = on
			Movement.Set("Stunned", if on then 0 else nil)
			if on then
				hud:Alert("Danger", "STUNNED", math.min(left, 3))
				camera:Shake(0.8, 0.5)
			end
		end
		if on then
			task.delay(left + 0.05, readStun)
		end
	end
	player:GetAttributeChangedSignal("StunnedUntil"):Connect(readStun)
	-- the Flooded Caverns' monsters: hiding, shell hits, bursts
	task.spawn(function()
		local folder = workspace:WaitForChild("Monsters", 300)
		if not folder then
			return
		end
		for _, model in folder:GetChildren() do
			watchMonster(model)
		end
		folder.ChildAdded:Connect(function(child: Instance)
			task.defer(watchMonster, child) -- its attributes arrive with it; a frame for safety
		end)
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		for model, w in watched do
			if w.Fade ~= w.Target then
				local step = FADE_PER_SECOND * dt
				w.Fade = if w.Fade < w.Target then math.min(w.Fade + step, w.Target) else math.max(w.Fade - step, w.Target)
				applyFade(model, w)
			end
		end
	end)
	log:Debug("threat display ready")
end

return ThreatController
