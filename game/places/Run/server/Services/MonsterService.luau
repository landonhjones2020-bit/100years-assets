--!strict
--[[
	MonsterService: monsters in the bunker and the monster cap (bible Sections 10 and 23, the
	Appendix's monster table). Run place only; Prompt 12.

	Spawning
	* Spawn(type, at, tag?) makes a monster from ServerStorage.Assets.Monsters.<Asset> (A4), or a
	  graybox rig until its model exists, in workspace.Monsters. It registers with CombatService
	  (team Monsters) and carries Rig, MonsterType, Activity and AttackAt attributes for
	  NPCAnimator (Section 23: clips play on clients from replicated state).
	* At most Tuning.Threat.MaxMonsters are on the map at once (Section 23's cap of 25); the rest
	  wait in a queue and come out where they were meant to as others die.
	* Tags group monsters (a Surge's wave: "Surge:7"); Count(tag) includes the queue.

	Behaviour, 5 times a second (Tuning.MonsterAI)
	* Targets (Section 10): residents first, then machines, then players who hit them; each type
	  has its own order (Config.Monsters.Targets). "Players" means players who hit it in the last
	  AggroSeconds, or who come within ProximityAggro (Runners only answer hits: Section 10's
	  Tunnel Hound sprints past defenders). Downed residents and players are left alone.
	* Walking: the room graph (Lib.PathGraph: doorways, Shaft stairs; Section 23), MoveTo at the
	  type's MoveSpeed; stuck for StuckSeconds, it steps to its next waypoint.
	* Attacks: in Range, a windup (the rig's HitTime attribute, else WindupFraction of
	  AttackSeconds), then the hit is checked again (Monster Lab's rule) and lands:
	  - on a player or resident through CombatService:Damage;
	  - on a machine (a room): its HP falls (SmashesMachines: SmashMultiplier times). A wrecked
	    room stops (Prompt 9). The Reactor Core at 0 HP is destroyed and the run is lost
	    (Section 5).
	* Traits: Latches (Burrow Tick) hangs on a resident and bites until killed or swatted;
	  Slows (Spitter Grub) keeps its distance and spits goo that slows (players: the SlowedUntil
	  attribute; residents: their walk); stunned monsters (StunnedUntil: melee, Shock Mines)
	  stand still.

	API:
		MonsterService.Spawned: Signal<string, string, string?> -- id, type, tag
		MonsterService.Died: Signal<string, string, string?>    -- id, type, tag
		MonsterService:Spawn(type, at: CFrame, tag?): string?   -- nil when queued (or no such type)
		MonsterService:Count(tag?): number                      -- alive plus queued
		MonsterService:All(): { { Id, Type, Tag, Position } }
		MonsterService:InUnit(unit): number                     -- monsters in a room or dug cell
		MonsterService:Clear()
	Dev: monster, monsters, monsters.clear.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)
local Threat = require(Shared.Rules.Threat)
local PathGraph = require(ServerScriptService.Lib.PathGraph)

local log = Log.new("MonsterService")

local MonsterService = {
	Name = "MonsterService",
	Dependencies = { "CombatService", "BunkerGrid", "ResidentService", "RunDirector", "DevService" },
	Spawned = Signal.new() :: Signal.Signal<string, string, string?>,
	Died = Signal.new() :: Signal.Signal<string, string, string?>,
}

local MONSTER_GROUP = "Monsters"
local ARRIVE = 2.5
local REPLAN_SECONDS = 2.5
local FLOOR_PENALTY = 40 -- studs a floor's difference counts as, when picking the nearest target
local NO_MACHINE: { [string]: boolean } = { Shaft = true }

type Target = { Kind: string, Id: string, RoomId: string?, Position: Vector3 }
type Monster = {
	Id: string,
	Type: string,
	Tag: string?,
	Spec: any,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Target: Target?,
	TargetAt: number,
	Points: { Vector3 },
	Index: number,
	Best: number,
	Since: number,
	PlannedFor: string?, -- the target unit the points lead to
	PlannedAt: number,
	AttackReadyAt: number,
	Aggro: { [string]: number }, -- player combatant id -> until (os.clock)
	LatchedTo: string?, -- a resident id (Burrow Ticks)
	Latch: WeldConstraint?,
}

local combat: any = nil
local grid: any = nil
local residents: any = nil
local director: any = nil
local dev: any = nil

local monsters: { [string]: Monster } = {}
local queue: { { Type: string, At: CFrame, Tag: string? } } = {}
local folder: Folder? = nil
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function ai(): { [string]: any }
	return Config.Get("Tuning", "MonsterAI")
end

local function cap(): number
	return Config.Get("Tuning", "Threat").MaxMonsters
end

local function holder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = workspace:FindFirstChild("Monsters")
	if not (f and f:IsA("Folder")) then
		f = Instance.new("Folder")
		f.Name = "Monsters"
		f.Parent = workspace
	end
	folder = f :: Folder
	return folder :: Folder
end

local function setActivity(m: Monster, activity: string)
	if m.Model:GetAttribute("Activity") ~= activity then
		m.Model:SetAttribute("Activity", activity)
	end
end

-- Models --------------------------------------------------------------------------------------

-- A graybox rig until A4's model exists: a root, a body, two glowing eyes. Sized by role.
local GRAYBOX: { [string]: { Size: Vector3, Colour: Color3 } } = {
	Swarmer = { Size = Vector3.new(2, 1.2, 2.4), Colour = Color3.fromRGB(64, 59, 55) },
	Runner = { Size = Vector3.new(2.2, 2.6, 4.4), Colour = Color3.fromRGB(94, 106, 68) },
	Brute = { Size = Vector3.new(4.5, 6, 3.5), Colour = Color3.fromRGB(64, 59, 55) },
	Ranged = { Size = Vector3.new(3, 2.4, 4.6), Colour = Color3.fromRGB(138, 154, 70) },
}

local function graybox(monsterType: string, spec: any): Model
	local look = GRAYBOX[spec.Role] or GRAYBOX.Runner
	local model = Instance.new("Model")
	model.Name = monsterType
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(look.Size.X, math.min(2, look.Size.Y), look.Size.Z)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = look.Size
	body.Color = look.Colour
	body.Material = Enum.Material.Slate
	body.CFrame = root.CFrame
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	for _, x in { -0.25, 0.25 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.4, 0.4, 0.4) * math.max(1, look.Size.X / 2.5)
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(124, 255, 155)
		eye.CanCollide = false
		eye.CFrame = root.CFrame * CFrame.new(x * look.Size.X, look.Size.Y * 0.25, -look.Size.Z / 2)
		eye.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = eye
		w.Parent = eye
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = look.Size.Y / 2 - root.Size.Y / 2 + 0.1
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = root
	model:SetAttribute("Graybox", true)
	return model
end

local function makeModel(monsterType: string, spec: any): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local monstersFolder = assets and assets:FindFirstChild("Monsters")
	local template = monstersFolder and monstersFolder:FindFirstChild(spec.Asset)
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
		return template:Clone()
	end
	return graybox(monsterType, spec)
end

-- Spawning ------------------------------------------------------------------------------------

local function aliveCount(): number
	local n = 0
	for _ in monsters do
		n += 1
	end
	return n
end

local function standOn(model: Model, at: CFrame)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { holder(), model }
	local hit = workspace:Raycast(at.Position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	local floorY = if hit then hit.Position.Y else at.Position.Y
	model:PivotTo(at)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(at + Vector3.new(0, floorY - (cf.Position.Y - size.Y / 2) + 0.05, 0))
end

local function spawnNow(monsterType: string, at: CFrame, tag: string?): string?
	local spec = Config.Find("Monsters", monsterType)
	if not spec then
		return nil
	end
	local model = makeModel(monsterType, spec)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CollisionGroup = MONSTER_GROUP
			part.CanTouch = false
		end
	end
	humanoid.WalkSpeed = spec.MoveSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.huge -- CombatService keeps a monster's health; the Humanoid only walks
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("Rig", monsterType)
	model:SetAttribute("MonsterType", monsterType)
	model:SetAttribute("Activity", "Idle")
	if tag then
		model:SetAttribute("Tag", tag)
	end
	standOn(model, at)
	model.Parent = holder()
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local id = combat:Register(model, { Kind = "Monster", Team = "Monsters", Health = spec.Health, MonsterType = monsterType })
	if not id then
		model:Destroy()
		return nil
	end
	model.Name = `{monsterType}_{id}`
	monsters[id] = {
		Id = id,
		Type = monsterType,
		Tag = tag,
		Spec = spec,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Target = nil,
		TargetAt = 0,
		Points = {},
		Index = 1,
		Best = math.huge,
		Since = os.clock(),
		PlannedFor = nil,
		PlannedAt = 0,
		AttackReadyAt = os.clock() + 0.6,
		Aggro = {},
		LatchedTo = nil,
		Latch = nil,
	}
	MonsterService.Spawned:Fire(id, monsterType, tag)
	return id
end

function MonsterService:Spawn(monsterType: string, at: CFrame, tag: string?): string?
	if not Config.Find("Monsters", monsterType) then
		return nil
	end
	if aliveCount() >= cap() then
		table.insert(queue, { Type = monsterType, At = at, Tag = tag })
		return nil
	end
	return spawnNow(monsterType, at, tag)
end

local function drainQueue()
	while #queue > 0 and aliveCount() < cap() do
		local next_ = table.remove(queue, 1)
		if next_ then
			spawnNow(next_.Type, next_.At, next_.Tag)
		end
	end
end

function MonsterService:Count(tag: string?): number
	local n = 0
	for _, m in monsters do
		if tag == nil or m.Tag == tag then
			n += 1
		end
	end
	for _, q in queue do
		if tag == nil or q.Tag == tag then
			n += 1
		end
	end
	return n
end

function MonsterService:Queued(): number
	return #queue
end

local function unitOf(position: Vector3): string?
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return grid:Bunker():UnitAt(floor, column)
end

function MonsterService:All(): { { Id: string, Type: string, Tag: string?, Position: Vector3, Unit: string? } }
	local list = {}
	for id, m in monsters do
		table.insert(list, { Id = id, Type = m.Type, Tag = m.Tag, Position = m.Root.Position, Unit = unitOf(m.Root.Position) })
	end
	return list
end

function MonsterService:InUnit(unit: string): number
	local n = 0
	for _, m in monsters do
		if unitOf(m.Root.Position) == unit then
			n += 1
		end
	end
	return n
end

local function unlatch(m: Monster)
	if m.Latch then
		m.Latch:Destroy()
		m.Latch = nil
	end
	if m.LatchedTo then
		m.LatchedTo = nil
		m.Humanoid.PlatformStand = false
	end
end

function MonsterService:Clear()
	table.clear(queue)
	for id, m in monsters do
		unlatch(m)
		combat:Unregister(id)
		m.Model:Destroy()
	end
	table.clear(monsters)
end

-- Targets -------------------------------------------------------------------------------------

local function floorOf(position: Vector3): number
	local floor = Grid.CellAt(position)
	return floor or 0
end

local function score(from: Vector3, to: Vector3): number
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude
	return flat + math.abs(floorOf(from) - floorOf(to)) * FLOOR_PENALTY
end

local function roomPoint(room: any): Vector3
	local column = room.Column + math.floor((room.Span - 1) / 2)
	local cell = Grid.CellPosition(room.Floor, column)
	return Vector3.new(cell.X + (if room.Span % 2 == 0 then Grid.Pitch().X / 2 else 0), cell.Y, cell.Z + 2)
end

local function residentTarget(m: Monster): Target?
	local best, bestScore = nil, math.huge
	for _, c in combat:All("Survivors") do
		if c.Kind == "Resident" and c.State == "Alive" and c.ResidentId then
			local record = residents:Get(c.ResidentId)
			if record and record.State == "Alive" then
				local s = score(m.Root.Position, c.Root.Position)
				if s < bestScore then
					best, bestScore = c, s
				end
			end
		end
	end
	return if best then { Kind = "Residents", Id = best.Id, Position = best.Root.Position } else nil
end

local function machineTarget(m: Monster): Target?
	local best, bestScore = nil, math.huge
	for _, room in grid:Rooms() do
		if not NO_MACHINE[room.Type] and room.HP > 0 then
			local s = score(m.Root.Position, roomPoint(room))
			if s < bestScore then
				best, bestScore = room, s
			end
		end
	end
	return if best then { Kind = "Machines", Id = best.Id, RoomId = best.Id, Position = roomPoint(best) } else nil
end

local function playerTarget(m: Monster): Target?
	local t = ai()
	local best, bestScore = nil, math.huge
	local runner = m.Spec.Role == "Runner"
	for _, c in combat:All("Survivors") do
		if c.Kind == "Player" and c.State == "Alive" and c.Player and c.Player:GetAttribute("Life") == "Alive" then
			local hit = (m.Aggro[c.Id] or 0) > os.clock()
			local s = score(m.Root.Position, c.Root.Position)
			local near = not runner and s <= t.ProximityAggro
			if (hit or near) and s < bestScore then
				best, bestScore = c, s
			end
		end
	end
	return if best then { Kind = "Players", Id = best.Id, Position = best.Root.Position } else nil
end

local function chooseTarget(m: Monster)
	local found: { [string]: Target } = {}
	local available: { [string]: boolean } = {}
	for _, kind in m.Spec.Targets do
		local target = if kind == "Residents" then residentTarget(m)
			elseif kind == "Machines" then machineTarget(m)
			elseif kind == "Players" then playerTarget(m)
			else nil
		if target then
			found[kind] = target
			available[kind] = true
		end
	end
	-- a player who is hitting it, or right in its face, comes before a far resident: anything
	-- in reach now beats walking away from a fight (the residents-first order picks among the rest)
	local player = found.Players
	if player and score(m.Root.Position, player.Position) <= m.Spec.Range + 4 and m.Spec.Role ~= "Runner" then
		m.Target = player
	else
		local kind = Threat.Choose(m.Spec.Targets, available)
		m.Target = if kind then found[kind] else nil
	end
	m.TargetAt = os.clock()
end

local function targetPosition(target: Target): Vector3?
	if target.Kind == "Machines" then
		local room = grid:Room(target.RoomId :: string)
		return if room and room.HP > 0 then roomPoint(room) else nil
	end
	local c = combat:Get(target.Id)
	if not c or c.State ~= "Alive" then
		return nil
	end
	if c.Kind == "Resident" then
		local record = residents:Get(c.ResidentId)
		if not record or record.State ~= "Alive" then
			return nil
		end
	elseif c.Kind == "Player" and c.Player and c.Player:GetAttribute("Life") ~= "Alive" then
		return nil
	end
	return c.Root.Position
end

-- Moving --------------------------------------------------------------------------------------

local function halt(m: Monster)
	m.Humanoid:MoveTo(m.Root.Position)
end

local function face(m: Monster, at: Vector3)
	local flat = Vector3.new(at.X, m.Root.Position.Y, at.Z)
	if (flat - m.Root.Position).Magnitude > 0.2 then
		m.Root.CFrame = CFrame.lookAt(m.Root.Position, flat)
	end
end

local function plan(m: Monster, goal: Vector3)
	local from = unitOf(m.Root.Position)
	local to = unitOf(goal + Vector3.new(0, 1, 0))
	m.Points = {}
	m.Index = 1
	m.Best = math.huge
	m.Since = os.clock()
	m.PlannedFor = to
	m.PlannedAt = os.clock()
	if from and to and from ~= to then
		local points = PathGraph.Waypoints(grid:Bunker(), function(unit: string): Model?
			return grid:RoomModel(unit)
		end, m.Root.Position, from, to, goal)
		if points then
			m.Points = points
			return
		end
	end
	m.Points = { goal }
end

local function walk(m: Monster, goal: Vector3)
	local goalUnit = unitOf(goal + Vector3.new(0, 1, 0))
	if m.PlannedFor ~= goalUnit or os.clock() - m.PlannedAt > REPLAN_SECONDS or #m.Points == 0 then
		plan(m, goal)
	end
	-- the last point follows a moving target
	if #m.Points > 0 then
		m.Points[#m.Points] = goal
	end
	local point = m.Points[m.Index]
	if not point then
		m.Humanoid:MoveTo(goal)
		return
	end
	local root = m.Root
	local distance = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z).Magnitude
	if distance <= ARRIVE and m.Index < #m.Points then
		m.Index += 1
		m.Best = math.huge
		m.Since = os.clock()
		point = m.Points[m.Index]
	elseif distance < m.Best - 0.5 then
		m.Best = distance
		m.Since = os.clock()
	elseif os.clock() - m.Since > ai().StuckSeconds then
		-- stuck on a corner or the stairs: step to the waypoint (as residents do)
		root.CFrame = CFrame.new(point + Vector3.new(0, m.Humanoid.HipHeight + root.Size.Y / 2, 0)) * root.CFrame.Rotation
		m.Best = math.huge
		m.Since = os.clock()
	end
	m.Humanoid:MoveTo(point)
	setActivity(m, "Walk")
end

-- Attacks -------------------------------------------------------------------------------------

local function inReach(m: Monster, target: Target, at: Vector3): boolean
	local c = combat:Get(m.Id)
	local reach = if c then c.Reach else 2
	local flat = Vector3.new(at.X - m.Root.Position.X, 0, at.Z - m.Root.Position.Z).Magnitude
	local sameFloor = math.abs(floorOf(at) - floorOf(m.Root.Position)) == 0
	local extra = if target.Kind == "Machines" then 4 else 1
	return sameFloor and flat - reach <= m.Spec.Range + extra
end

local function hurtRoom(m: Monster, roomId: string, amount: number)
	local room = grid:Room(roomId)
	if not room or room.HP <= 0 then
		return
	end
	local smash = if m.Spec.Traits and table.find(m.Spec.Traits, "SmashesMachines") then ai().SmashMultiplier else 1
	local hp = grid:SetHP(roomId, math.max(room.HP - amount * smash, 0))
	if hp and hp <= 0 then
		log:Info("%s wrecked %s (%s)", m.Id, roomId, room.Type)
		if room.Type == "ReactorCore" then
			director:Lose("ReactorDestroyed") -- Section 5: the Reactor Core destroyed loses the run
		end
	end
end

local function slow(c: any, seconds: number)
	if c.Kind == "Player" and c.Player then
		c.Player:SetAttribute("SlowedUntil", now() + seconds)
	elseif c.Kind == "Resident" then
		c.Model:SetAttribute("SlowedUntil", now() + seconds)
	end
end

local function spit(m: Monster, target: Target)
	local t = ai()
	local goo = Instance.new("Part")
	goo.Name = "Goo"
	goo.Shape = Enum.PartType.Ball
	goo.Size = Vector3.new(0.9, 0.9, 0.9)
	goo.Material = Enum.Material.Neon
	goo.Color = Color3.fromRGB(124, 255, 155)
	goo.Anchored = true
	goo.CanCollide = false
	goo.CanQuery = false
	goo.CanTouch = false
	local from = m.Root.Position + Vector3.new(0, 1, 0) + m.Root.CFrame.LookVector * 1.5
	goo.Position = from
	goo.Parent = holder()
	local aim = (target.Position + Vector3.new(0, 0.5, 0)) - from
	local velocity = aim.Unit * t.GooSpeed + Vector3.new(0, aim.Magnitude * 0.12, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { holder() }
	local position = from
	local flown = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = velocity * dt
		local hit = workspace:Raycast(position, step, params)
		velocity -= Vector3.new(0, 24 * dt, 0)
		flown += dt
		if hit or flown > 3 then
			if connection then
				connection:Disconnect()
			end
			goo:Destroy()
			local at = if hit then hit.Position else position
			for _, c in combat:All("Survivors") do
				if (c.Root.Position - at).Magnitude <= 3 + c.Reach then
					combat:Damage(c.Id, m.Spec.Damage, m.Id, "goo")
					slow(c, t.GooSlowSeconds)
				end
			end
			return
		end
		position += step
		goo.Position = position
	end)
end

local function latch(m: Monster, c: any)
	if m.Latch or not c.Root then
		return
	end
	m.LatchedTo = c.ResidentId
	m.Humanoid.PlatformStand = true
	m.Root.CFrame = c.Root.CFrame * CFrame.new(0, 0.6, 0.9)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = c.Root
	weld.Part1 = m.Root
	weld.Parent = m.Root
	m.Latch = weld
	setActivity(m, "Latched")
end

local function attack(m: Monster, target: Target)
	if os.clock() < m.AttackReadyAt then
		return
	end
	local spec = m.Spec
	m.AttackReadyAt = os.clock() + spec.AttackSeconds
	local hitTime = m.Model:GetAttribute("HitTime")
	local windup = if type(hitTime) == "number" then hitTime else spec.AttackSeconds * ai().WindupFraction
	m.Model:SetAttribute("AttackAt", os.clock()) -- NPCAnimator replays the attack clip
	setActivity(m, "Attack")
	task.delay(windup, function()
		if not monsters[m.Id] then
			return
		end
		local at = targetPosition(target)
		if not at then
			return
		end
		if spec.Traits and table.find(spec.Traits, "Slows") then
			target.Position = at
			spit(m, target)
			return
		end
		if not inReach(m, target, at) then
			return -- the hit is checked again when it lands
		end
		if target.Kind == "Machines" then
			hurtRoom(m, target.RoomId :: string, spec.Damage)
			return
		end
		local c = combat:Get(target.Id)
		if not c then
			return
		end
		combat:Damage(c.Id, spec.Damage, m.Id, "attacked")
		if c.Kind == "Resident" and spec.Traits and table.find(spec.Traits, "Latches") then
			latch(m, c)
		end
	end)
end

-- The tick -----------------------------------------------------------------------------------------

local function step(m: Monster)
	local stunned = m.Model:GetAttribute("StunnedUntil")
	if type(stunned) == "number" and stunned > now() then
		unlatch(m)
		halt(m)
		setActivity(m, "Stunned")
		return
	end
	if m.LatchedTo then
		local c = combat:Get(m.LatchedTo)
		local record = residents:Get(m.LatchedTo)
		if not c or c.State ~= "Alive" or not record or record.State ~= "Alive" then
			unlatch(m)
		else
			if os.clock() >= m.AttackReadyAt then
				m.AttackReadyAt = os.clock() + m.Spec.AttackSeconds
				m.Model:SetAttribute("AttackAt", os.clock())
				combat:Damage(c.Id, m.Spec.Damage, m.Id, "bitten")
			end
			return
		end
	end
	if not m.Target or os.clock() - m.TargetAt > 1 then
		chooseTarget(m)
	end
	local target = m.Target
	local at = if target then targetPosition(target) else nil
	if not target or not at then
		m.Target = nil
		halt(m)
		setActivity(m, "Idle")
		return
	end
	target.Position = at
	local ranged = m.Spec.Role == "Ranged"
	if inReach(m, target, at) then
		local flat = Vector3.new(at.X - m.Root.Position.X, 0, at.Z - m.Root.Position.Z).Magnitude
		if ranged and flat > m.Spec.Range * ai().KeepDistanceFraction then
			-- spitters keep their distance but close in a little while they spit
			m.Humanoid:MoveTo(m.Root.Position + (at - m.Root.Position).Unit * 2)
		else
			halt(m)
		end
		face(m, at)
		attack(m, target)
		return
	end
	walk(m, at)
end

local function loop()
	while true do
		task.wait(ai().TickSeconds)
		for id, m in monsters do
			if not m.Model.Parent then
				monsters[id] = nil
			else
				local ok, err = pcall(step, m)
				if not ok then
					log:Warn("%s: %s", id, tostring(err))
				end
			end
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------------------

local function nearPlayer(player: Player?): CFrame?
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local spot = root.Position + look * 14
	return CFrame.lookAt(spot, Vector3.new(root.Position.X, spot.Y, root.Position.Z))
end

function MonsterService:Init(registry)
	combat = registry.CombatService
	grid = registry.BunkerGrid
	residents = registry.ResidentService
	director = registry.RunDirector
	dev = registry.DevService

	pcall(function()
		PhysicsService:RegisterCollisionGroup(MONSTER_GROUP)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(MONSTER_GROUP, MONSTER_GROUP, false)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Residents")
		PhysicsService:CollisionGroupSetCollidable(MONSTER_GROUP, "Residents", false)
	end)

	dev:Register("monster", {
		Description = "Spawn monsters in front of you (Prompt 12).",
		Usage = "monster <Type> [count]",
		Run = function(player, args): string?
			local monsterType = tostring(args[1] or "")
			if not Config.Find("Monsters", monsterType) then
				return `no monster {monsterType}`
			end
			player = player or Players:GetPlayers()[1]
			local at = nearPlayer(player)
			if not at then
				return "no player to spawn by"
			end
			local count = math.clamp(math.floor(tonumber(args[2]) or 1), 1, 30)
			local made = {}
			for i = 1, count do
				local offset = CFrame.new((i - 1) % 4 * 2.5 - 3.75, 0, -math.floor((i - 1) / 4) * 3)
				table.insert(made, MonsterService:Spawn(monsterType, at * offset, "Dev") or "queued")
			end
			return `{monsterType}: {table.concat(made, ", ")}`
		end,
	})
	dev:Register("monsters", {
		Description = "The monsters on the map, the queue and what each is after.",
		Usage = "monsters",
		Run = function(): string?
			local lines = { `{aliveCount()} on the map (cap {cap()}), {#queue} queued` }
			for id, m in monsters do
				local health = combat:HealthOf(id)
				local target = if m.Target then `{m.Target.Kind} {m.Target.Id}` else "nothing"
				table.insert(lines, `  {id} {m.Type} {math.ceil(health)}hp in {unitOf(m.Root.Position) or "?"}, after {target}, {m.Model:GetAttribute("Activity")}{if m.LatchedTo then ` (latched to {m.LatchedTo})` else ""}`)
			end
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("monsters.clear", {
		Description = "Remove every monster and the queue.",
		Usage = "monsters.clear",
		Run = function(): string?
			local n = aliveCount() + #queue
			MonsterService:Clear()
			return `{n} removed`
		end,
	})
end

function MonsterService:Start()
	holder()
	combat.Died:Connect(function(id: string)
		local m = monsters[id]
		if not m then
			return
		end
		unlatch(m)
		monsters[id] = nil
		MonsterService.Died:Fire(id, m.Type, m.Tag)
		task.defer(drainQueue)
	end)
	combat.Damaged:Connect(function(targetId: string, _amount: number, sourceId: string?)
		local m = monsters[targetId]
		if m and sourceId and string.sub(sourceId, 1, 1) == "P" then
			m.Aggro[sourceId] = os.clock() + ai().AggroSeconds
			if m.Target == nil or m.Target.Kind ~= "Residents" then
				m.TargetAt = 0 -- rethink now
			end
		end
	end)
	task.spawn(loop)
	log:Info("monsters ready: cap %d", cap())
end

return MonsterService
