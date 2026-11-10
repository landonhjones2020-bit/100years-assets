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
	  - on a machine (a room): its HP falls by RoomDamageMultiplier of the damage (SmashesMachines:
	    SmashMultiplier times that). A wrecked
	    room stops (Prompt 9) and isn't a target until it is repaired. The Reactor Core at 0 HP
	    starts the meltdown (DisasterService, Prompt 13).
	* The surface (Prompt 16): a monster and its targets must be in the same realm (Rules.Surface:
	  the town high above, or underground: the bunker and the Deep's caves behind it, Prompt 17). On
	  the surface there are no machines, rescued survivors count as residents, players are seen from
	  SurfaceAggro, and paths come from PathfindingService (Section 23), planned off the AI's thread
	  every PathSeconds. Ash Jackals (PackRunner) circle at CircleRadius between bites; Ash Raiders
	  (Shoots) keep their distance and fire a rifle (ShotAccuracy, line of sight checked when the
	  shot lands).
	* The Deep (Prompt 17): in a cave there are no machines either, players are seen from
	  Tuning.Deep.DeepAggro, and paths come from PathfindingService; a target in the bunker is
	  reached through the cave's mouth (SetCaveExit: DeepService says where a cave position's mouth
	  is), and a monster in the bunker goes after a target in a cave the same way round.
	* Guards (Spawn's options.Guard, Prompt 17: the caves' guards and the raider camp's): asleep at
	  their post until a player comes within Guard studs or hits them; awake, they only go after
	  what is within 1.6 times that of their post, and with nothing left they walk back and sleep.
	* Traits: Latches (Burrow Tick) hangs on a resident and bites until killed or swatted;
	  Slows (Spitter Grub) keeps its distance and spits goo that slows (players: the SlowedUntil
	  attribute; residents: their walk); stunned monsters (StunnedUntil: melee, Shock Mines)
	  stand still.

	API:
		MonsterService.Spawned: Signal<string, string, string?> -- id, type, tag
		MonsterService.Died: Signal<string, string, string?>    -- id, type, tag
		MonsterService:Spawn(type, at: CFrame, tag?, options?): string? -- nil when queued (or no such type); options.Guard
		MonsterService:SetCaveExit(fn)                          -- fn(position in a cave): its mouth, in the bunker
		MonsterService:Count(tag?): number                      -- alive plus queued
		MonsterService:All(): { { Id, Type, Tag, Position } }
		MonsterService:InUnit(unit): number                     -- monsters in a room or dug cell
		MonsterService:Clear()
		MonsterService:Despawn(id)                              -- fades one away (the surface's leftovers)
		MonsterService:ZoneOf(id): string?
		MonsterService:Taunt(sourceId, position, radius, seconds): number -- Hold the Line (Prompt 20)
	Dev: monster, monsters, monsters.clear.
]]

local PathfindingService = game:GetService("PathfindingService")
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
local Surface = require(Shared.Rules.Surface)
local Threat = require(Shared.Rules.Threat)
local Hazards = require(ServerScriptService.Lib.Hazards)
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
local BLOCKED_SKIP_SECONDS = 6 -- rubble cuts a target off: look for others this long (Prompt 13)
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
	PlannedVersion: number, -- Lib.Hazards' version when planned: rubble falling or cleared plans again
	AttackReadyAt: number,
	Aggro: { [string]: number }, -- player combatant id -> until (os.clock)
	Skip: { [string]: number }, -- a target id rubble cuts it off from -> until (os.clock; Prompt 13)
	LatchedTo: string?, -- a resident id (Burrow Ticks)
	Latch: WeldConstraint?,
	Zone: string, -- "Surface", "Bunker" or "Deep" (Prompts 16 and 17)
	Mode: string, -- "Graph" (the room graph) or "Path" (PathfindingService: the surface, the caves)
	Post: Vector3?, -- a guard's post (Prompt 17)
	Guard: number?, -- a guard's wake range
	Asleep: boolean,
	Pathing: boolean, -- a PathfindingService plan is being worked out (the surface)
	Path: Path?,
	CircleUntil: number, -- a PackRunner circles its target until then (os.clock)
	CircleAngle: number,
	Taunt: { Id: string, Until: number }?, -- Hold the Line (Prompt 20): this player comes first until then
}

local combat: any = nil
local grid: any = nil
local residents: any = nil
local director: any = nil
local dev: any = nil

export type Options = { Guard: number? }

local monsters: { [string]: Monster } = {}
local queue: { { Type: string, At: CFrame, Tag: string?, Options: Options? } } = {}
local caveExit: ((Vector3) -> Vector3?)? = nil -- DeepService: a cave position's mouth (Prompt 17)
local LEASH = 1.6 -- an awake guard's reach from its post, times its wake range
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

local function spawnNow(monsterType: string, at: CFrame, tag: string?, options: Options?): string?
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
		PlannedVersion = 0,
		AttackReadyAt = os.clock() + 0.6,
		Aggro = {},
		Skip = {},
		LatchedTo = nil,
		Latch = nil,
		Zone = Surface.Zone(at.Position),
		Mode = "Graph",
		Post = if options and options.Guard then at.Position else nil,
		Guard = if options then options.Guard else nil,
		Asleep = options ~= nil and options.Guard ~= nil,
		Pathing = false,
		Path = nil,
		CircleUntil = 0,
		CircleAngle = rng:NextNumber() * math.pi * 2,
	}
	MonsterService.Spawned:Fire(id, monsterType, tag)
	return id
end

function MonsterService:Spawn(monsterType: string, at: CFrame, tag: string?, options: Options?): string?
	if not Config.Find("Monsters", monsterType) then
		return nil
	end
	if aliveCount() >= cap() then
		table.insert(queue, { Type = monsterType, At = at, Tag = tag, Options = options })
		return nil
	end
	return spawnNow(monsterType, at, tag, options)
end

-- DeepService (Prompt 17): where a position in a cave comes out into the bunker.
function MonsterService:SetCaveExit(fn: ((Vector3) -> Vector3?)?)
	caveExit = fn
end

local function drainQueue()
	while #queue > 0 and aliveCount() < cap() do
		local next_ = table.remove(queue, 1)
		if next_ then
			spawnNow(next_.Type, next_.At, next_.Tag, next_.Options)
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

-- Fades one monster away without a kill (surface creatures left behind when everyone goes home,
-- wraiths when the storm passes).
function MonsterService:Despawn(id: string)
	local m = monsters[id]
	if not m then
		return
	end
	unlatch(m)
	monsters[id] = nil
	combat:Unregister(id)
	combat:Dissolve(m.Model)
	task.defer(drainQueue)
end

function MonsterService:ZoneOf(id: string): string?
	local m = monsters[id]
	return if m then m.Zone else nil
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

local function skipped(m: Monster, id: string): boolean
	local untilAt = m.Skip[id]
	return untilAt ~= nil and untilAt > os.clock()
end

-- In reach of the monster at all: the same realm (the surface, or underground: the bunker and the
-- Deep), and for an awake guard within its leash of its post (Prompt 17).
local function reachable(m: Monster, position: Vector3): boolean
	if Surface.Realm(Surface.Zone(position)) ~= Surface.Realm(m.Zone) then
		return false
	end
	local post, guard = m.Post, m.Guard
	if post and guard and (position - post).Magnitude > guard * LEASH then
		return false
	end
	return true
end

local function residentTarget(m: Monster): Target?
	local best, bestScore = nil, math.huge
	for _, c in combat:All("Survivors") do
		if c.Kind == "Survivor" and c.State == "Alive" and not skipped(m, c.Id) and reachable(m, c.Root.Position) then
			-- a rescued survivor on the way home (Prompt 16) counts as a resident
			local s = score(m.Root.Position, c.Root.Position)
			if s < bestScore then
				best, bestScore = c, s
			end
		elseif c.Kind == "Resident" and c.State == "Alive" and c.ResidentId and not skipped(m, c.Id)
			and reachable(m, c.Root.Position) then
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
	if m.Zone ~= "Bunker" or m.Post then
		return nil -- no machines up in the town or in the caves; guards keep to their post
	end
	local best, bestScore = nil, math.huge
	for _, room in grid:Rooms() do
		if not NO_MACHINE[room.Type] and not room.Wrecked and not skipped(m, room.Id) then
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
	local aggro = if m.Zone == "Surface" then t.SurfaceAggro
		elseif m.Zone == "Deep" then Config.Get("Tuning", "Deep").DeepAggro
		else t.ProximityAggro
	for _, c in combat:All("Survivors") do
		if c.Kind == "Player" and c.State == "Alive" and c.Player and c.Player:GetAttribute("Life") == "Alive"
			and not skipped(m, c.Id) and reachable(m, c.Root.Position) then
			local hit = (m.Aggro[c.Id] or 0) > os.clock()
			local s = score(m.Root.Position, c.Root.Position)
			local near = not runner and s <= aggro
			if (hit or near) and s < bestScore then
				best, bestScore = c, s
			end
		end
	end
	return if best then { Kind = "Players", Id = best.Id, Position = best.Root.Position } else nil
end

local function chooseTarget(m: Monster)
	-- Hold the Line (Prompt 20): a taunting Security comes before everything while they stand
	local taunt = m.Taunt
	if taunt then
		local c = combat:Get(taunt.Id)
		if os.clock() < taunt.Until and c and c.State == "Alive" and reachable(m, c.Root.Position) then
			m.Target = { Kind = "Players", Id = c.Id, Position = c.Root.Position }
			m.TargetAt = os.clock()
			return
		end
		m.Taunt = nil
	end
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

-- Hold the Line (Prompt 20): monsters within `radius` of `position` go after the combatant
-- `sourceId` for `seconds` (Runners too), whatever else is near. Returns how many.
function MonsterService:Taunt(sourceId: string, position: Vector3, radius: number, seconds: number): number
	local n = 0
	for _, m in monsters do
		if (m.Root.Position - position).Magnitude <= radius and reachable(m, position) then
			m.Taunt = { Id = sourceId, Until = os.clock() + seconds }
			m.Aggro[sourceId] = os.clock() + seconds
			m.Asleep = false
			m.TargetAt = 0
			n += 1
		end
	end
	return n
end

local function targetPosition(target: Target): Vector3?
	if target.Kind == "Machines" then
		local room = grid:Room(target.RoomId :: string)
		return if room and not room.Wrecked then roomPoint(room) else nil
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
	if Surface.Realm(Surface.Zone(c.Root.Position)) ~= Surface.Realm(Surface.Zone(target.Position)) then
		return nil -- it rode the elevator away (Prompt 16)
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
	m.PlannedVersion = Hazards.Version()
	if from and to and from ~= to then
		local points, why = PathGraph.Waypoints(grid:Bunker(), function(unit: string): Model?
			return grid:RoomModel(unit)
		end, m.Root.Position, from, to, goal)
		if points then
			m.Points = points
			return
		end
		if why == "Blocked" then
			-- cave-in rubble stands between it and its target (Prompt 13): it looks for another
			-- one for a while instead of walking through the rubble
			if m.Target then
				m.Skip[m.Target.Id] = os.clock() + BLOCKED_SKIP_SECONDS
			end
			m.Target = nil
			m.Points = { m.Root.Position }
			return
		end
	end
	m.Points = { goal }
end

-- The surface (Prompt 16): PathfindingService plans off the AI's thread; until a plan arrives the
-- monster heads straight for its goal.
local function surfacePlan(m: Monster, goal: Vector3)
	if m.Pathing then
		return
	end
	m.Pathing = true
	m.PlannedAt = os.clock()
	task.spawn(function()
		local path = m.Path or PathfindingService:CreatePath({
			AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8,
		})
		m.Path = path
		local ok = pcall(function()
			(path :: Path):ComputeAsync(m.Root.Position, goal)
		end)
		m.Pathing = false
		if monsters[m.Id] ~= m then
			return
		end
		local points: { Vector3 } = {}
		if ok and (path :: Path).Status == Enum.PathStatus.Success then
			for _, waypoint in (path :: Path):GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
			table.remove(points, 1) -- where it stands
		end
		if #points == 0 then
			points = { goal }
		end
		m.Points = points
		m.Index = 1
		m.Best = math.huge
		m.Since = os.clock()
	end)
end

local function walkSurface(m: Monster, goal: Vector3)
	local root = m.Root
	local flatGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Magnitude
	if os.clock() - m.PlannedAt > ai().PathSeconds or #m.Points == 0 then
		surfacePlan(m, goal)
	end
	local point = m.Points[m.Index]
	if flatGoal < 14 or not point then
		point = goal -- close: straight at it
	end
	local distance = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z).Magnitude
	if distance <= ARRIVE + 1 and m.Index < #m.Points then
		m.Index += 1
		m.Best = math.huge
		m.Since = os.clock()
		point = m.Points[m.Index]
	elseif distance < m.Best - 0.5 then
		m.Best = distance
		m.Since = os.clock()
	elseif os.clock() - m.Since > ai().StuckSeconds then
		-- stuck on wreckage: hop, and plan again
		m.Humanoid.Jump = true
		m.Best = math.huge
		m.Since = os.clock()
		m.PlannedAt = 0
	end
	m.Humanoid:MoveTo(point)
	setActivity(m, "Walk")
end

-- Switching between the room graph and PathfindingService starts the plan afresh.
local function setMode(m: Monster, mode: string)
	if m.Mode ~= mode then
		m.Mode = mode
		m.Points = {}
		m.Index = 1
		m.Best = math.huge
		m.Since = os.clock()
		m.PlannedAt = 0
		m.PlannedFor = nil
	end
end

local function walk(m: Monster, goal: Vector3)
	if m.Zone == "Surface" then
		setMode(m, "Path")
		walkSurface(m, goal)
		return
	end
	local goalZone = Surface.Zone(goal)
	local exit = caveExit
	if m.Zone == "Deep" then
		-- in a cave (Prompt 17): PathfindingService; a goal in the bunker through the cave's mouth
		local mouth = if goalZone ~= "Deep" and exit then exit(m.Root.Position) else nil
		setMode(m, "Path")
		walkSurface(m, mouth or goal)
		return
	end
	if goalZone == "Deep" and exit then
		-- in the bunker, after something in a cave: to the cave's mouth, then in
		local mouth = exit(goal)
		if mouth then
			if Vector3.new(mouth.X - m.Root.Position.X, 0, mouth.Z - m.Root.Position.Z).Magnitude < 6 then
				setMode(m, "Path")
				walkSurface(m, goal)
				return
			end
			goal = mouth
		end
	end
	setMode(m, "Graph")
	local goalUnit = unitOf(goal + Vector3.new(0, 1, 0))
	if m.PlannedFor ~= goalUnit or os.clock() - m.PlannedAt > REPLAN_SECONDS or #m.Points == 0
		or m.PlannedVersion ~= Hazards.Version() then
		local chasing = m.Target ~= nil -- a guard walking back to its post has none
		plan(m, goal)
		if chasing and not m.Target then
			-- rubble cut the target off (plan): wait here and choose again next tick
			halt(m)
			setActivity(m, "Idle")
			return
		end
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
	if m.Zone == "Deep" or Surface.Zone(at) == "Deep" then
		sameFloor = math.abs(at.Y - m.Root.Position.Y) < 7 -- caves are off the grid: a drop's ledge is another floor
	end
	local extra = if target.Kind == "Machines" then 4 else 1
	return sameFloor and flat - reach <= m.Spec.Range + extra
end

local function hurtRoom(m: Monster, roomId: string, amount: number)
	local room = grid:Room(roomId)
	if not room or room.Wrecked then
		return
	end
	local smash = if m.Spec.Traits and table.find(m.Spec.Traits, "SmashesMachines") then ai().SmashMultiplier else 1
	local hp = grid:SetHP(roomId, math.max(room.HP - amount * smash * ai().RoomDamageMultiplier, 0))
	if hp and hp <= 0 then
		-- a Reactor Core at 0 HP melts down (DisasterService listens to BunkerGrid.Wrecked;
		-- Landon, 2026-11-08: the 60-second meltdown instead of losing at once)
		log:Info("%s wrecked %s (%s)", m.Id, roomId, room.Type)
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

-- An Ash Raider's rifle (Prompt 16): line of sight from its chest to the target when the shot
-- lands, then ShotAccuracy of the time a hit. A tracer shows every shot.
local function shoot(m: Monster, target: Target, at: Vector3)
	local from = m.Root.Position + Vector3.new(0, 1.5, 0) + m.Root.CFrame.LookVector * 1.5
	local to = at + Vector3.new(0, 1, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { holder(), m.Model }
	local c = combat:Get(target.Id)
	if c then
		table.insert(ignore, c.Model)
	end
	params.FilterDescendantsInstances = ignore
	local blocked = workspace:Raycast(from, to - from, params)
	local hit = not blocked and rng:NextNumber() < ai().ShotAccuracy
	local finish = if blocked then blocked.Position
		elseif hit then to
		else to + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 2), rng:NextNumber(-3, 3))
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 196, 120)
	local length = (finish - from).Magnitude
	tracer.Size = Vector3.new(0.12, 0.12, math.max(length, 0.1))
	tracer.CFrame = CFrame.lookAt(from, finish) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = holder()
	task.delay(0.07, function()
		tracer:Destroy()
	end)
	if hit and c then
		combat:Damage(c.Id, m.Spec.Damage, m.Id, "shot")
	end
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
		if spec.Traits and table.find(spec.Traits, "Shoots") then
			if (at - m.Root.Position).Magnitude <= spec.Range + 4 then
				shoot(m, target, at)
			end
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
		if spec.Role == "PackRunner" then
			-- circle and dart in (Section 10's Ash Jackals): back off and circle before the next bite
			local range = ai().CircleSeconds
			m.CircleUntil = os.clock() + rng:NextNumber(range.Min, range.Max)
		end
		if c.Kind == "Resident" and spec.Traits and table.find(spec.Traits, "Latches") then
			latch(m, c)
		end
	end)
end

-- The tick -----------------------------------------------------------------------------------------

local function step(m: Monster)
	m.Zone = Surface.Zone(m.Root.Position)
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
				local t = ai()
				m.AttackReadyAt = os.clock() + m.Spec.AttackSeconds * t.LatchIntervalMultiplier
				m.Model:SetAttribute("AttackAt", os.clock())
				combat:Damage(c.Id, m.Spec.Damage * t.LatchDamageMultiplier, m.Id, "bitten")
			end
			return
		end
	end
	local post = m.Post
	if post and m.Asleep then
		-- a guard asleep at its post (Prompt 17): a player close by, or a hit, wakes it
		local woken = false
		for _, untilAt in m.Aggro do
			if untilAt > os.clock() then
				woken = true
			end
		end
		if not woken then
			for _, c in combat:All("Survivors") do
				if c.Kind == "Player" and c.State == "Alive" and c.Player and c.Player:GetAttribute("Life") == "Alive"
					and (c.Root.Position - m.Root.Position).Magnitude <= (m.Guard or 0) and reachable(m, c.Root.Position) then
					woken = true
					break
				end
			end
		end
		if not woken then
			halt(m)
			setActivity(m, "Idle")
			return
		end
		m.Asleep = false
		m.TargetAt = 0
	end
	if not m.Target or os.clock() - m.TargetAt > 1 then
		chooseTarget(m)
	end
	local target = m.Target
	local at = if target then targetPosition(target) else nil
	if target and at and not reachable(m, at) then
		target, at = nil, nil -- off its leash
	end
	if not target or not at then
		m.Target = nil
		if post then
			-- nothing near its post: back to it, and asleep there
			if Vector3.new(post.X - m.Root.Position.X, 0, post.Z - m.Root.Position.Z).Magnitude > 4 then
				walk(m, post)
				return
			end
			m.Asleep = true
		end
		halt(m)
		setActivity(m, "Idle")
		return
	end
	target.Position = at
	if m.Spec.Role == "PackRunner" and os.clock() < m.CircleUntil then
		-- circling its prey between bites
		m.CircleAngle += ai().TickSeconds * 1.6
		local r = ai().CircleRadius
		local spot = at + Vector3.new(math.cos(m.CircleAngle) * r, 0, math.sin(m.CircleAngle) * r)
		m.Humanoid:MoveTo(spot)
		setActivity(m, "Walk")
		return
	end
	local ranged = m.Spec.Role == "Ranged" or (m.Spec.Traits ~= nil and table.find(m.Spec.Traits, "Shoots") ~= nil)
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
