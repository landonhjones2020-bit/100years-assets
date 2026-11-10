--!strict
--[[
	RescueService: trapped people and bringing them home (bible Sections 11 and 12; Run place,
	Prompt 16). Survivors are trapped in buildings on the surface; trapped miners in the Deep and
	the Lost Crews' members (Prompt 17) use the same rescue (Kind Survivor, Miner or Crew).

	* Trap(at, options) puts one in workspace.Rescues, pinned under a little rubble, with a Free
	  prompt (hold Tuning.Surface.FreeSeconds; Section 12: free them, hold interact).
	* Freed, they follow the player who freed them (their leader) FollowDistance behind, at
	  SurvivorWalkSpeed times the leader's RescuedFollowSpeed (Spelunker, Section 14). A leader who
	  is downed, gone, out of EscortRange or in another realm (the surface, or underground: the
	  bunker and the Deep are one) is replaced by the nearest standing player in range; with none
	  they wait where they are. A survivor left far behind on open ground is brought up to their
	  leader (no one is lost to a fence).
	* On the way they are CombatService combatants (Kind Survivor, team Survivors): monsters treat
	  them as residents (Section 12: protect them on the way). Their health is SurvivorHealth divided
	  by the leader's RescuedDamageTaken; killed, they are lost.
	* The elevator: SurfaceService moves a rider's followers with them (Followers).
	* Home (Section 12: each rescue becomes a resident, sometimes a Rare one): a follower in the bunker
	  joins it through ResidentService:Add(tier, level), their new body stepping out where they
	  stood. Joined(residentId, player?, kind, where) fires; SetArrival(kind, fn) adds what a kind
	  does after joining (Prompt 17: a Lost Crew home completes its objective).
	* Residents already in the run (Prompt 18: an expedition pinned down, Kind Expedition, Options
	  Resident): their prompt says what Options Action and Label give (HELP, their name), they follow
	  with their own health (Options Health), and home they don't join again: the kind's arrival
	  (SetArrival) brings that resident back, with the health the way home left them (HealthLeft)
	  where they stood (HomeAt). Joined doesn't fire for them.

	Dev: rescues, rescue.free <id>.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local Signal = require(Shared.Utilities.Signal)
local Surface = require(Shared.Rules.Surface)

local log = Log.new("RescueService")

local RescueService = {
	Name = "RescueService",
	Dependencies = { "SessionService", "CombatService", "ResidentService", "ResidentBrain", "RunDirector", "DevService" },
	Freed = Signal.new() :: Signal.Signal<string, Player>,
	Joined = Signal.new() :: Signal.Signal<string, Player?, string, string>, -- resident id, leader, kind, where
	Lost = Signal.new() :: Signal.Signal<string, string>, -- rescue id, kind
}

local GROUP = "Residents" -- ResidentBrain's collision group: no bumping into players or monsters
local TICK = 0.25
local CATCH_UP = 40 -- studs behind on the same zone for a while: brought up to the leader
local REPLAN_SECONDS = 1.5

export type Options = {
	Kind: string?, -- "Survivor" (the surface), "Miner" (the Deep) or "Crew" (a Lost Crew's member; Prompt 17)
	Tier: string?, -- Common or Rare (rolled when nil)
	Level: number?,
	Where: string?, -- "the motel": for the alerts and the run's story
	Tag: string?,
	Resident: string?, -- a resident already in the run (Prompt 18: an expedition member), not a newcomer
	Health: number?, -- their health while following (default SurvivorHealth over the leader's RescuedDamageTaken)
	Label: string?, -- the prompt's object text (default the kind's)
	Action: string?, -- the prompt's action (default FREE)
}

type Rescue = {
	Id: string,
	Kind: string,
	Tier: string,
	Level: number,
	Where: string,
	Tag: string?,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	State: "Trapped" | "Following" | "Waiting",
	Leader: Player?,
	CombatId: string?,
	Prompt: ProximityPrompt?,
	Rubble: BasePart?,
	BehindSince: number,
	Points: { PathWaypoint }, -- PathfindingService's way round walls and wrecks
	Index: number,
	PlannedAt: number,
	Pathing: boolean,
	Path: Path?,
	Resident: string?, -- Prompt 18
	Health: number?,
	HealthLeft: number?, -- home: what the way home left them
	HomeAt: CFrame?, -- home: where they stood
}

local combat: any = nil
local residents: any = nil
local brain: any = nil
local director: any = nil

local rescues: { [string]: Rescue } = {}
local arrivals: { [string]: (any, Player?, string) -> () } = {} -- kind -> after joining (rescue, leader, resident id)
-- what the prompt and the alerts call each kind
local KIND_TEXT: { [string]: { Trapped: string, Freed: string, Lost: string } } = {
	Survivor = { Trapped = "Trapped survivor", Freed = "YOU FREED A SURVIVOR: BRING THEM HOME TO THE BLAST DOOR", Lost = "A SURVIVOR DIDN'T MAKE IT" },
	Miner = { Trapped = "Trapped miner", Freed = "YOU FREED A TRAPPED MINER: BRING THEM BACK INTO THE BUNKER", Lost = "A RESCUED MINER DIDN'T MAKE IT" },
	Crew = { Trapped = "Steadfast work crew", Freed = "YOU FREED ONE OF THE LOST CREW: BRING THEM HOME", Lost = "WE LOST ONE OF THE LOST CREW" },
	Expedition = { Trapped = "Expedition", Freed = "YOU REACHED THEM: BRING THEM HOME TO THE BUNKER", Lost = "AN EXPEDITION MEMBER DIDN'T MAKE IT HOME" },
}

local function kindText(kind: string): { Trapped: string, Freed: string, Lost: string }
	return KIND_TEXT[kind] or KIND_TEXT.Survivor
end
local counter = 0
local rng = Random.new()

local function alertAll(kind: string, text: string)
	for _, player in Players:GetPlayers() do
		Remotes.FireClient("Alert", player, kind, text)
	end
end

local function folder(): Folder
	local f = workspace:FindFirstChild("Rescues")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Rescues"
		f.Parent = workspace
	end
	return f :: Folder
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function standing(player: Player): boolean
	return player.Parent == Players and player:GetAttribute("Life") == "Alive" and rootOf(player) ~= nil
end

local function classValue(player: Player?, key: string): number
	return Modifiers.PlayerValue(player, key) or 1 -- at the leader's class level (Prompt 20)
end

local function setActivity(r: Rescue, activity: string)
	if r.Model:GetAttribute("Activity") ~= activity then
		r.Model:SetAttribute("Activity", activity)
	end
end

local function makeBody(id: string): (Model?, Humanoid?, BasePart?)
	local assets = ServerStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Residents") and assets.Residents:FindFirstChild("Resident_Common")
	if not source then
		log:Warn("no resident model (ServerStorage.Assets.Residents.Resident_Common)")
		return nil, nil, nil
	end
	local model = (source :: Model):Clone()
	model.Name = id
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, nil, nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.huge -- CombatService keeps their health
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = GROUP
			part.Anchored = false
			if part ~= root then
				part.CanCollide = false
			end
		end
	end
	return model, humanoid, root
end

local function makeRubble(at: CFrame, parent: Instance): BasePart
	local plank = Instance.new("Part")
	plank.Name = "Rubble"
	plank.Size = Vector3.new(5, 0.6, 1.2)
	plank.Color = Color3.fromRGB(110, 84, 60)
	plank.Material = Enum.Material.WoodPlanks
	plank.Anchored = true
	plank.CanCollide = false
	plank.CanQuery = false
	plank.CanTouch = false
	plank.CFrame = at * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, math.rad(35), math.rad(12))
	plank.Parent = parent
	return plank
end

-- Trapping --------------------------------------------------------------------------------------

local function free(r: Rescue, player: Player)
	if r.State ~= "Trapped" or not standing(player) then
		return
	end
	if r.Prompt then
		r.Prompt:Destroy()
		r.Prompt = nil
	end
	if r.Rubble then
		r.Rubble:Destroy()
		r.Rubble = nil
	end
	r.Root.Anchored = false
	pcall(function()
		r.Root:SetNetworkOwner(nil)
	end)
	r.State = "Following"
	r.Leader = player
	r.BehindSince = 0
	local health = (r.Health or Surface.Tuning().SurvivorHealth) / math.max(classValue(player, "RescuedDamageTaken"), 0.1)
	r.CombatId = combat:Register(r.Model, { Kind = "Survivor", Team = "Survivors", Root = r.Root, Health = health, Id = r.Id })
	r.Model:SetAttribute("State", "Following")
	r.Model:SetAttribute("Leader", player.UserId)
	setActivity(r, "Walk")
	RescueService.Freed:Fire(r.Id, player)
	Remotes.FireClient("Alert", player, "Info", kindText(r.Kind).Freed)
	log:Info("%s freed %s (%s)", player.Name, r.Id, r.Where)
end

-- Puts a trapped person at a spot; returns their id.
function RescueService:Trap(at: CFrame, options: Options?): string?
	local o: Options = options or {}
	counter += 1
	local id = `S{counter}`
	local model, humanoid, root = makeBody(id)
	if not model or not humanoid or not root then
		return nil
	end
	local t = Surface.Tuning()
	local tier = o.Tier or Surface.SurvivorTier(rng:NextNumber())
	local level = o.Level or rng:NextInteger(t.SurvivorLevel.Min, t.SurvivorLevel.Max)
	model:PivotTo(at) -- the resident model's pivot is at its feet
	root.Anchored = true
	model:SetAttribute("RescueId", id)
	model:SetAttribute("RescueKind", o.Kind or "Survivor")
	model:SetAttribute("Tier", tier)
	model:SetAttribute("State", "Trapped")
	model:SetAttribute("Activity", "Downed")
	model.Parent = folder()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FreePrompt"
	prompt.ActionText = o.Action or "FREE"
	local label = o.Label or kindText(o.Kind or "Survivor").Trapped
	prompt.ObjectText = if tier == "Common" or o.Label then label else `{label} ({tier})`
	prompt.HoldDuration = t.FreeSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "Free")
	prompt.Parent = root
	local r: Rescue = {
		Id = id,
		Kind = o.Kind or "Survivor",
		Tier = tier,
		Level = level,
		Where = o.Where or "the ruins",
		Tag = o.Tag,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		State = "Trapped",
		Leader = nil,
		CombatId = nil,
		Prompt = prompt,
		Rubble = makeRubble(at, model),
		BehindSince = 0,
		Points = {},
		Index = 1,
		PlannedAt = 0,
		Pathing = false,
		Path = nil,
		Resident = o.Resident,
		Health = o.Health,
		HealthLeft = nil,
		HomeAt = nil,
	}
	prompt.Triggered:Connect(function(player: Player)
		free(r, player)
	end)
	rescues[id] = r
	log:Info("%s trapped at %s (%s, %s level %d)", id, r.Where, r.Kind, tier, level)
	return id
end

function RescueService:Remove(id: string)
	local r = rescues[id]
	if not r then
		return
	end
	rescues[id] = nil
	if r.CombatId then
		combat:Unregister(r.CombatId)
	end
	if r.Rubble then
		r.Rubble:Destroy()
	end
	r.Model:Destroy()
end

function RescueService:Count(state: string?, kind: string?): number
	local n = 0
	for _, r in rescues do
		if (state == nil or r.State == state) and (kind == nil or r.Kind == kind) then
			n += 1
		end
	end
	return n
end

-- The spots taken by trapped people (SurfaceService doesn't put two on one spot).
function RescueService:Spots(): { Vector3 }
	local list = {}
	for _, r in rescues do
		if r.State == "Trapped" then
			table.insert(list, r.Root.Position)
		end
	end
	return list
end

-- The rescues following a player within range (they ride the elevator with them).
function RescueService:Followers(player: Player, range: number): { string }
	local root = rootOf(player)
	local list = {}
	if not root then
		return list
	end
	for id, r in rescues do
		if r.State ~= "Trapped" and r.Leader == player and (r.Root.Position - root.Position).Magnitude <= range then
			table.insert(list, id)
		end
	end
	return list
end

-- Moves a rescue (the elevator).
function RescueService:MoveTo(id: string, at: CFrame)
	local r = rescues[id]
	if r then
		r.Model:PivotTo(at)
		r.BehindSince = 0
	end
end

-- What a kind does after one of them joins the bunker: fn(rescue, leader, residentId).
function RescueService:SetArrival(kind: string, fn: ((any, Player?, string) -> ())?)
	arrivals[kind] = fn
end

-- The trapped and the rescued with a tag (a Lost Crew's members): { Id, State, Position }.
function RescueService:Tagged(tag: string): { { Id: string, State: string, Position: Vector3 } }
	local list = {}
	for id, r in rescues do
		if r.Tag == tag then
			table.insert(list, { Id = id, State = r.State, Position = r.Root.Position })
		end
	end
	return list
end

-- Home ------------------------------------------------------------------------------------------

local function arrive(r: Rescue)
	rescues[r.Id] = nil
	if r.CombatId then
		local c = combat:Get(r.CombatId)
		r.HealthLeft = if c then c.Health else nil
		combat:Unregister(r.CombatId)
	end
	local where = r.Root.CFrame
	local leader = r.Leader
	if r.Resident then
		-- someone already in the run (Prompt 18): their kind brings them back
		r.HomeAt = where
		r.Model:Destroy()
		log:Info("%s (%s) is home (%s)", r.Id, r.Resident, r.Where)
		local back = arrivals[r.Kind]
		if back then
			local ok, err = pcall(back, r, leader, r.Resident)
			if not ok then
				log:Warn("%s arrival: %s", r.Kind, tostring(err))
			end
		end
		return
	end
	local residentId = residents:Add(r.Tier, r.Level)
	local record = residents:Get(residentId)
	local name = if record then Residents.Name(record) else residentId
	local body = brain:Body(residentId)
	if body then
		body:PivotTo(where)
	end
	r.Model:Destroy()
	alertAll("Info", `{string.upper(name)}{if r.Tier ~= "Common" then ` ({string.upper(r.Tier)})` else ""} JOINS THE BUNKER`
		.. (if leader then `: RESCUED BY {string.upper(leader.DisplayName)}` else ""))
	RescueService.Joined:Fire(residentId, leader, r.Kind, r.Where)
	log:Info("%s joined as %s (%s, %s)", r.Id, residentId, r.Tier, r.Where)
	local after = arrivals[r.Kind]
	if after then
		local ok, err = pcall(after, r, leader, residentId)
		if not ok then
			log:Warn("%s arrival: %s", r.Kind, tostring(err))
		end
	end
end

local function lose(r: Rescue)
	if rescues[r.Id] ~= r then
		return
	end
	rescues[r.Id] = nil
	if r.Rubble then
		r.Rubble:Destroy()
	end
	alertAll("Danger", kindText(r.Kind).Lost)
	RescueService.Lost:Fire(r.Id, r.Kind)
	log:Info("%s was lost", r.Id)
end

-- Following -------------------------------------------------------------------------------------

local function nearestStanding(position: Vector3, range: number): Player?
	local best, bestDistance = nil, range
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and standing(player) and Surface.SameRealm(root.Position, position) then
			local d = (root.Position - position).Magnitude
			if d <= bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best
end

-- A path round the walls (Section 23: PathfindingService off the bunker's room graph), planned off
-- the loop's thread; until it arrives they head straight for their leader.
local function plan(r: Rescue, goal: Vector3)
	if r.Pathing then
		return
	end
	r.Pathing = true
	r.PlannedAt = os.clock()
	task.spawn(function()
		local path = r.Path or PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5.5, AgentCanJump = true, WaypointSpacing = 6 })
		r.Path = path
		local ok = pcall(function()
			(path :: Path):ComputeAsync(r.Root.Position, goal)
		end)
		r.Pathing = false
		if rescues[r.Id] ~= r then
			return
		end
		local points: { PathWaypoint } = {}
		if ok and (path :: Path).Status == Enum.PathStatus.Success then
			points = (path :: Path):GetWaypoints()
			table.remove(points, 1)
		end
		r.Points = points
		r.Index = 1
	end)
end

local function follow(r: Rescue)
	local t = Surface.Tuning()
	local position = r.Root.Position
	if Surface.Zone(position) == "Bunker" then
		arrive(r)
		return
	end
	local leader = r.Leader
	local leaderRoot = leader and rootOf(leader)
	if not leader or not leaderRoot or not standing(leader) or (leaderRoot.Position - position).Magnitude > t.EscortRange * 2
		or not Surface.SameRealm(leaderRoot.Position, position) then
		local other = nearestStanding(position, t.EscortRange)
		if other ~= leader then
			r.Leader = other
			r.Model:SetAttribute("Leader", if other then other.UserId else nil)
		end
		leader = other
		leaderRoot = if other then rootOf(other) else nil
	end
	if not leader or not leaderRoot then
		r.State = "Waiting"
		r.Model:SetAttribute("State", "Waiting")
		r.Humanoid:MoveTo(position)
		setActivity(r, "Idle")
		return
	end
	r.State = "Following"
	r.Model:SetAttribute("State", "Following")
	r.Humanoid.WalkSpeed = t.SurvivorWalkSpeed * classValue(leader, "RescuedFollowSpeed")
	local offset = position - leaderRoot.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = flat.Magnitude
	if distance > CATCH_UP then
		if r.BehindSince == 0 then
			r.BehindSince = os.clock()
		elseif os.clock() - r.BehindSince > 4 then
			-- left far behind: brought up to their leader
			local back = leaderRoot.CFrame * CFrame.new(rng:NextNumber(-2, 2), -3, t.FollowDistance) -- feet, not the root's height
			r.Model:PivotTo(back)
			r.BehindSince = 0
			return
		end
	else
		r.BehindSince = 0
	end
	if distance > t.FollowDistance then
		local spot = leaderRoot.Position + flat.Unit * t.FollowDistance
		if os.clock() - r.PlannedAt > REPLAN_SECONDS then
			plan(r, spot)
		end
		local waypoint = r.Points[r.Index]
		local point = if waypoint and distance > t.FollowDistance + 6 then waypoint.Position else spot
		if waypoint and (Vector3.new(point.X, 0, point.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < 2.5 then
			r.Index += 1
			local next_ = r.Points[r.Index]
			if next_ then
				point = next_.Position
				if next_.Action == Enum.PathWaypointAction.Jump then
					r.Humanoid.Jump = true
				end
			end
		end
		r.Humanoid:MoveTo(point)
		setActivity(r, "Walk")
	else
		r.Humanoid:MoveTo(position)
		setActivity(r, "Idle")
	end
end

local function loop()
	while true do
		task.wait(TICK)
		for _, r in rescues do
			if r.State ~= "Trapped" then
				local ok, err = pcall(follow, r)
				if not ok then
					log:Warn("%s: %s", r.Id, tostring(err))
				end
			end
		end
	end
end

local function clear()
	for id in table.clone(rescues) do
		RescueService:Remove(id)
	end
end

function RescueService:Init(registry)
	combat = registry.CombatService
	residents = registry.ResidentService
	brain = registry.ResidentBrain
	director = registry.RunDirector
	registry.DevService:Register("rescues", {
		Description = "Trapped and rescued people (Prompt 16).",
		Usage = "rescues",
		Run = function(): string?
			local lines = {}
			for id, r in rescues do
				table.insert(lines, `{id} {r.Kind} {r.Tier} L{r.Level} {r.State} at {r.Where}{if r.Leader then ` following {r.Leader.Name}` else ""}`)
			end
			table.sort(lines)
			return if #lines > 0 then table.concat(lines, "\n") else "nobody trapped or on the way"
		end,
	})
	registry.DevService:Register("rescue.free", {
		Description = "Free a trapped person as you (they follow you).",
		Usage = "rescue.free <id>",
		Run = function(player, args): string?
			local r = rescues[tostring(args[1] or "")]
			local p = player or Players:GetPlayers()[1]
			if not r or not p then
				return "rescue.free <id>"
			end
			free(r, p)
			return `{r.Id}: {r.State}`
		end,
	})
end

function RescueService:Start()
	folder()
	combat.Died:Connect(function(id: string)
		local r = rescues[id]
		if r and r.CombatId == id then
			lose(r)
		end
	end)
	director.RunEnded:Connect(clear)
	task.spawn(loop)
end

return RescueService
