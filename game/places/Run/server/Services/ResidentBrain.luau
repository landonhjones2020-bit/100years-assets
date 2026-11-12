--!strict
--[[
	ResidentBrain: residents' routines and behaviour states in the world, phase 1 (bible Sections
	11 and 23). Run place only.

	Every resident in ResidentService has a body: a clone of ServerStorage.Assets.Residents
	.Resident_Common (the A0 resident; A3 brings the full kit) in workspace.Bunker.Residents,
	named by the resident's id, with ResidentId and Activity attributes. NPCAnimator (client)
	plays clips from Activity (Section 23).

	The routine, worked out 5 times a second (Section 11: work a shift, eat at the Kitchen, rest
	in Quarters; Tuning.Residents, provisional):
	* the first MealSeconds of each day: a seat at a Kitchen (standing room when the seats run out);
	* the rest of the day: a work spot in their job's room (WorkSpot1, 2... in the order they
	  joined it); with no job, their bed;
	* the Surge: their bed in the Quarters (Bed1, 2... by arrival; no bed: standing in the Quarters).
	* idle during the day: a seat in the Lounge when there is one (Section 11: socialise in the
	  Lounge; Landon, Nov 8, 2026), or by their bed.
	* sick with no job (Prompt 24): in their Quarters bed all day, which is quarantine;
	* Down: lying where they fell with a Revive prompt (a Medkit from the stockpile); dead: gone.
	* Away (Prompt 18; Section 12: expeditions leave the map): they walk to the Blast Door and are
	  gone (after Tuning.Expeditions.LeaveSeconds at the latest); no body while they are away.
	  Home again, a body steps in wherever ExpeditionService puts it.
	* Danger (Prompt 12; Section 11: in danger the unarmed flee to the nearest safe room, and
	  they handle a single Burrow Tick themselves): a monster in their room, or within
	  ResidentFleeRadius on their floor, sends them to the nearest room with no monster in or
	  next to it, until ResidentCalmSeconds pass with none near. A lone Burrow Tick they swat
	  (ResidentSwatDamage every ResidentSwatSeconds). Spitter goo slows them (SlowedUntil).
	* Disasters (Prompt 13; Section 11: residents caught in a disaster fight it if they can, and
	  handle a small fire in their own room): a resident in a burning room beats the fire down
	  (Activity Extinguish; DisasterService counts them) until their health falls below
	  Tuning.Disasters.Fire.ResidentFleeHealth, then flees to a room with no fire and no monster,
	  and keeps out of burning rooms while that hurt. Cave-in rubble (Lib.Hazards) blocks
	  passages: routes go around it, and a resident with no way round is Trapped (they wait
	  where they are; ResidentService takes them off their crew) until it is cleared. When
	  rubble falls or is cleared, everyone plans their way again.
	They walk the room graph (Lib.PathGraph: doorways, Shaft stairs) with Humanoid:MoveTo, at a
	speed from their Speed stat. A resident stuck for STUCK_SECONDS steps to their next waypoint.
	Residents pass through each other and through players (collision groups).

	* Rally (Prompt 20; Section 14's Rally Call, Section 11: armed residents answer rally calls):
	  Rally(ids, leader, seconds, bonus, instant?) sends residents to a player for `seconds`: they
	  walk to them (instant: they are there at once, the Security's level 3) and fight any monster
	  within Tuning.Classes.RallyReach beside them, with their weapon's melee damage (or a swat),
	  times `bonus` (RallyBonus, read by ClassService's damage filter). A rally ends early when the
	  leader falls or leaves the bunker. It comes before fleeing: rallied, they stand their ground.

	API:
		ResidentBrain:Body(id): Model?
		ResidentBrain:Activity(id): string?
		ResidentBrain:Rally(ids, leader, seconds, bonus, instant?): number
		ResidentBrain:RallyBonus(id): number
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Disasters = require(Shared.Rules.Disasters)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)
local Hazards = require(ServerScriptService.Lib.Hazards)
local PathGraph = require(ServerScriptService.Lib.PathGraph)

local log = Log.new("ResidentBrain")

local ResidentBrain = {
	Name = "ResidentBrain",
	Dependencies = { "ResidentService", "BunkerGrid", "CycleClock", "CombatService", "EconomyService", "DevService" },
}

local TICK = 0.2 -- 5 Hz (Section 23)
local ARRIVE = 2 -- studs
local STUCK_SECONDS = 2.5
local RESIDENT_GROUP, PLAYER_GROUP = "Residents", "Players"

type Body = {
	Id: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Goal: string?, -- what it is heading for: "Work:R4:WorkSpot2"
	GoalActivity: string,
	Points: { Vector3 },
	Index: number,
	Best: number, -- closest it has come to the current waypoint
	Since: number, -- when it last got closer
	Lying: boolean,
	Prompt: ProximityPrompt?,
	Trapped: boolean, -- rubble cuts them off from their goal (Prompt 13)
	HazardVersion: number, -- Lib.Hazards' version when the goal was planned
	LeaveSince: number?, -- when they set out through the Blast Door (Prompt 18)
}

local residents: any = nil
local grid: any = nil
local clock: any = nil
local combat: any = nil
local economy: any = nil
local DRY_ALERT_SECONDS = 30 -- how often the "guns are empty" alert may show
local dryAt = -math.huge
local fleeing: { [string]: { Until: number, Room: string? } } = {}
local rallies: { [string]: { Until: number, Leader: Player, Bonus: number } } = {} -- Prompt 20
local swattedAt: { [string]: number } = {}
local bodies: { [string]: Body } = {}
local folder: Folder? = nil
local dayStartedAt = os.clock()

local function bodiesFolder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local root = grid:Root()
	if not root then
		return nil
	end
	local found = root:FindFirstChild("Residents")
	if not found then
		found = Instance.new("Folder")
		found.Name = "Residents"
		found.Parent = root
	end
	folder = found :: Folder
	return folder
end

local function setActivity(body: Body, activity: string)
	if body.Model:GetAttribute("Activity") ~= activity then
		body.Model:SetAttribute("Activity", activity)
	end
end

local function lie(body: Body, at: CFrame?)
	if body.Lying then
		return
	end
	body.Lying = true
	body.Humanoid:MoveTo(body.Root.Position)
	local base = at or body.Root.CFrame
	body.Root.Anchored = true
	-- on the back, a little above what they lie on
	body.Root.CFrame = CFrame.new(base.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function standUp(body: Body)
	if not body.Lying then
		return
	end
	body.Lying = false
	local position = body.Root.Position
	body.Root.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	body.Root.Anchored = false
end

local function speedFor(id: string): number
	local resident = residents:Get(id)
	local t = Config.Get("Tuning", "Residents")
	return t.WalkSpeedBase + (if resident then resident.Stats.Speed or 0 else 5) * t.WalkSpeedPerSpeed
end

local function slowedSpeed(body: any): number
	local floor, column = Grid.CellAt(body.Root.Position)
	local unit = if floor and column and grid then grid:Bunker():UnitAt(floor, column) else nil
	local base = speedFor(body.Id) * Disasters.WadeSpeed(Hazards.Flood(unit)) -- wading (Prompt 23)
	local slowed = body.Model:GetAttribute("SlowedUntil")
	if type(slowed) == "number" and slowed > workspace:GetServerTimeNow() then
		return base * Config.Get("Tuning", "MonsterAI").GooSlowMultiplier
	end
	return base
end

local function spawnBody(id: string): Body?
	local holder = bodiesFolder()
	local assets = ServerStorage:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("Residents") and assets.Residents:FindFirstChild("Resident_Common")
	if not holder or not source then
		log:Warn("no resident model (ServerStorage.Assets.Residents.Resident_Common) or no bunker yet")
		return nil
	end
	local model = (source :: Model):Clone()
	model.Name = id
	model:SetAttribute("ResidentId", id)
	model:SetAttribute("Activity", "Idle")
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if not humanoid or not root then
		model:Destroy()
		log:Warn("the resident model has no Humanoid or HumanoidRootPart")
		return nil
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = speedFor(id)
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = RESIDENT_GROUP
			part.Anchored = false
			if part ~= root then
				part.CanCollide = false
			end
		end
	end
	-- start in their job room, or the Quarters, or the Medbay
	local resident = residents:Get(id)
	local room = (resident and resident.Job and grid:Room(resident.Job)) or grid:RoomsOfType("Quarters")[1]
		or grid:RoomsOfType("Medbay")[1]
	local start = if room then Grid.CellPosition(room.Floor, room.Column) else Vector3.zero
	model:PivotTo(CFrame.new(start + Vector3.new(0, 3, 8)))
	model.Parent = holder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local body: Body = {
		Id = id, Model = model, Humanoid = humanoid, Root = root, Goal = nil, GoalActivity = "Idle",
		Points = {}, Index = 1, Best = math.huge, Since = os.clock(), Lying = false, Prompt = nil,
		Trapped = false, HazardVersion = 0, LeaveSince = nil,
	}
	bodies[id] = body
	return body
end

-- Where a resident should be, and doing what -------------------------------------------------------

local function socketsOf(roomId: string, pattern: string): { CFrame }
	local model = grid:RoomModel(roomId)
	if not model then
		return {}
	end
	local found = BunkerKit.Sockets(model, pattern)
	local names = {}
	for name in found do
		table.insert(names, name)
	end
	table.sort(names, function(a: string, b: string): boolean
		return (tonumber(string.match(a, "%d+")) or 0) < (tonumber(string.match(b, "%d+")) or 0)
	end)
	local list = {}
	for _, name in names do
		table.insert(list, found[name])
	end
	return list
end

-- The n-th spot of a kind across every room of a type (seats in every Kitchen, beds in every
-- Quarters), or a place to stand in the first of those rooms when they run out.
local function spotAcross(roomType: string, pattern: string, n: number): (string?, CFrame?)
	local rooms = grid:RoomsOfType(roomType)
	table.sort(rooms, function(a, b)
		return a.Id < b.Id
	end)
	local i = n
	for _, room in rooms do
		local spots = socketsOf(room.Id, pattern)
		if i <= #spots then
			return room.Id, spots[i]
		end
		i -= #spots
	end
	local room = rooms[1]
	if room then
		local cell = Grid.CellPosition(room.Floor, room.Column + (n % room.Span))
		return room.Id, CFrame.new(cell + Vector3.new(((n * 3) % 12) - 6, 0, 4))
	end
	return nil, nil
end

-- Danger (Prompt 12) ---------------------------------------------------------------------------

local function unitAt(position: Vector3): string?
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return grid:Bunker():UnitAt(floor, column)
end

local function monstersNear(position: Vector3): { any }
	local t = Config.Get("Tuning", "MonsterAI")
	local near = {}
	local myUnit = unitAt(position)
	local myFloor = Grid.CellAt(position)
	for _, c in combat:All("Monsters") do
		local floor = Grid.CellAt(c.Root.Position)
		local sameUnit = myUnit ~= nil and unitAt(c.Root.Position) == myUnit
		if sameUnit or (floor == myFloor and (c.Root.Position - position).Magnitude <= t.ResidentFleeRadius) then
			table.insert(near, c)
		end
	end
	return near
end

-- The nearest room (by the room graph) with no monster in it or next to it; else any room with
-- none in it.
local function safeRoom(fromUnit: string?): string?
	if not fromUnit then
		return nil
	end
	local danger: { [string]: boolean } = {}
	for _, c in combat:All("Monsters") do
		local unit = unitAt(c.Root.Position)
		if unit then
			danger[unit] = true
		end
	end
	for unit in Hazards.Fires() do
		danger[unit] = true -- a burning room is no refuge (Prompt 13)
	end
	local d = Config.Get("Tuning", "Disasters")
	for unit, level in Hazards.Floods() do
		if level >= d.Flood.ResidentFleeLevel then
			danger[unit] = true -- nor one deep in water, or full of gas (Prompt 23)
		end
	end
	for unit, strength in Hazards.GasLeaks() do
		if strength >= d.Gas.ResidentFleeStrength then
			danger[unit] = true
		end
	end
	local bunker = grid:Bunker()
	local seen: { [string]: boolean } = { [fromUnit] = true }
	local queue = { fromUnit }
	local fallback: string? = nil
	local index = 1
	while index <= #queue do
		local unit = queue[index]
		index += 1
		local room = grid:Room(unit)
		if unit ~= fromUnit and room and room.Type ~= "Shaft" and not danger[unit] then
			local nextToDanger = false
			for _, other in bunker:Neighbors(unit) do
				if danger[other] then
					nextToDanger = true
				end
			end
			if not nextToDanger then
				return unit
			end
			fallback = fallback or unit
		end
		for _, other in Hazards.Neighbors(bunker, unit) do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return fallback
end

local function danger(id: string): (string?, string?, CFrame?, string?)
	local body = bodies[id]
	if not body or not combat then
		return nil
	end
	local t = Config.Get("Tuning", "MonsterAI")
	local near = monstersNear(body.Root.Position)
	if #near == 1 and near[1].MonsterType == "BurrowTick" then
		fleeing[id] = nil
		return `Swat:{near[1].Id}`, nil, nil, "Fight"
	end
	-- Prompt 26 (Section 11: "armed and brave residents fight in their room and the rest flee"):
	-- whoever carries a weapon, or is Brave, takes on the nearest monster in the room they are in
	local person = residents:Get(id)
	if #near > 0 and person and (Residents.Armed(person) or Residents.Has(person, "DefendsUnarmed")) then
		local mine = unitAt(body.Root.Position)
		local best: any, bestDistance = nil, math.huge
		for _, c in near do
			local distance = (c.Root.Position - body.Root.Position).Magnitude
			if mine ~= nil and unitAt(c.Root.Position) == mine and distance < bestDistance then
				best, bestDistance = c, distance
			end
		end
		if best then
			fleeing[id] = nil
			return `RallyFight:{best.Id}`, nil, nil, "Fight"
		end
	end
	local flee = fleeing[id]
	if #near > 0 then
		local room = if flee then flee.Room else nil
		local current = if room then grid:Room(room) else nil
		if not current or #monstersNear(Grid.CellPosition(current.Floor, current.Column)) > 0 then
			room = safeRoom(unitAt(body.Root.Position))
		end
		flee = { Until = os.clock() + t.ResidentCalmSeconds, Room = room }
		fleeing[id] = flee
		-- they are Panicked while they run and for a while after (Config.Conditions.Panicked: no
		-- work); a Cool Head in their room calms them sooner, and the Brave and Cool Heads never are
		if person then
			local calmed = false
			if person.Job then
				for _, mate in residents:Workers(person.Job) do
					if mate.Id ~= id and Residents.Has(mate, "CalmsRoommates") then
						calmed = true
					end
				end
			end
			residents:Panic(id, t.ResidentCalmSeconds + Residents.PanicSeconds(person, calmed), "monsters")
		end
	end
	-- fire where they stand (Prompt 13): fight it while they can, else get out
	local here = unitAt(body.Root.Position)
	if #near == 0 and here and Hazards.Fire(here) then
		local resident = residents:Get(id)
		local f = Config.Get("Tuning", "Disasters").Fire
		local healthy = resident ~= nil and resident.Health >= resident.MaxHealth * f.ResidentFleeHealth
		if healthy and not (flee and os.clock() < flee.Until) then
			local room = grid:Room(here)
			if room then
				local n = tonumber(string.match(id, "%d+")) or 0
				local cell = Grid.CellPosition(room.Floor, room.Column + n % room.Span)
				local spot = CFrame.new(cell + Vector3.new(((n * 5) % 15) - 7, 0, 3))
				return `Extinguish:{here}`, here, spot, "Extinguish"
			end
		end
		if not flee or not flee.Room or Hazards.Fire(flee.Room) then
			flee = { Until = os.clock() + t.ResidentCalmSeconds, Room = safeRoom(here) }
			fleeing[id] = flee
		end
	end
	-- water rising or gas where they stand (Prompt 23): residents can't fix either, they get out
	if #near == 0 and here and not Hazards.Fire(here) then
		local d = Config.Get("Tuning", "Disasters")
		if Hazards.Unsafe(here, d.Flood.ResidentFleeLevel, d.Gas.ResidentFleeStrength, d.Radiation.ResidentFleeStrength) then
			if not flee or not flee.Room or Hazards.Unsafe(flee.Room, d.Flood.ResidentFleeLevel, d.Gas.ResidentFleeStrength, d.Radiation.ResidentFleeStrength) then
				flee = { Until = os.clock() + t.ResidentCalmSeconds, Room = safeRoom(here) }
				fleeing[id] = flee
			else
				flee.Until = math.max(flee.Until, os.clock() + 2)
			end
		end
	end
	if flee and os.clock() < flee.Until and flee.Room and grid:Room(flee.Room) then
		local room = grid:Room(flee.Room)
		local spot = CFrame.new(Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, 0, 4))
		return `Flee:{flee.Room}`, flee.Room, spot, "Flee"
	end
	fleeing[id] = nil
	return nil
end

local routine: (id: string, order: number, resident: any) -> (string, string?, CFrame?, string)

local function leaderRoot(player: Player): BasePart?
	if player.Parent ~= Players or player:GetAttribute("Life") ~= "Alive" then
		return nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A rallied resident (Prompt 20): fight the nearest monster in reach beside the leader, else go to them.
local function rallyPlan(id: string, order: number): (string?, string?, CFrame?, string?)
	local rally = rallies[id]
	local body = bodies[id]
	if not rally or not body then
		return nil
	end
	local root = leaderRoot(rally.Leader)
	local unit = if root then unitAt(root.Position) else nil
	if os.clock() >= rally.Until or not root or not unit then
		rallies[id] = nil
		return nil
	end
	local reach = Config.Get("Tuning", "Classes").RallyReach
	local best, bestDistance = nil, reach * 2
	for _, c in combat:All("Monsters") do
		local d = (c.Root.Position - body.Root.Position).Magnitude - c.Reach
		if d <= bestDistance and (c.Root.Position - root.Position).Magnitude <= reach * 3 then
			best, bestDistance = c, d
		end
	end
	if best then
		return `RallyFight:{best.Id}`, nil, nil, "Fight"
	end
	local angle = order * 2.4
	local spot = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 4, -2.5, math.sin(angle) * 2))
	return `Rally:{rally.Leader.UserId}:{unit}`, unit, spot, "Idle"
end

local function plan(id: string, order: number): (string, string?, CFrame?, string)
	local resident = residents:Get(id)
	if not resident then
		return "Gone", nil, nil, "Idle"
	end
	if resident.State == "Down" then
		return "Down", nil, nil, "Down"
	end
	if resident.State == "Away" then
		-- an expedition sets out (Prompt 18): to the Blast Door, then off the map
		local door = grid:RoomsOfType("BlastDoor")[1]
		local model = door and grid:RoomModel(door.Id)
		local socket = model and BunkerKit.Socket(model, "Door")
		if door and socket then
			return "Leave", door.Id, CFrame.new(socket.Position), "Walk"
		end
		return "Leave", nil, nil, "Walk"
	end
	-- held by a Lurker (Prompt 23; MonsterService sets Grabbed): they can't move until it lets go
	local held = bodies[id]
	if held and held.Model:GetAttribute("Grabbed") then
		return "Grabbed", nil, nil, "Flee"
	end
	local rallyGoal, rallyRoom, rallySpot, rallyActivity = rallyPlan(id, order)
	if rallyGoal then
		return rallyGoal, rallyRoom, rallySpot, rallyActivity :: string
	end
	local threatGoal, threatRoom, threatSpot, threatActivity = danger(id)
	if threatGoal then
		return threatGoal, threatRoom, threatSpot, threatActivity :: string
	end
	local goal, roomId, spot, activity = routine(id, order, resident)
	-- a room deep in water or full of gas (Prompt 23): they wait outside until it is safe
	if roomId and not Hazards.Fire(roomId) then
		local d = Config.Get("Tuning", "Disasters")
		if Hazards.Unsafe(roomId, d.Flood.ResidentFleeLevel, d.Gas.ResidentFleeStrength, d.Radiation.ResidentFleeStrength) then
			local body = bodies[id]
			local here = if body then unitAt(body.Root.Position) else nil
			if here ~= roomId then
				return "Wait:hazard", nil, nil, "Idle"
			end
		end
	end
	-- too hurt to fight a fire (Prompt 13): they keep out of burning rooms and wait where they are
	if roomId and Hazards.Fire(roomId) then
		local f = Config.Get("Tuning", "Disasters").Fire
		if resident.Health < resident.MaxHealth * f.ResidentFleeHealth then
			local body = bodies[id]
			local here = if body then unitAt(body.Root.Position) else nil
			if here ~= roomId then
				return "Wait:fire", nil, nil, "Idle"
			end
		end
	end
	return goal, roomId, spot, activity
end

routine = function(id: string, order: number, resident: any): (string, string?, CFrame?, string)
	local phase = clock:Phase()
	local mealSeconds = Config.Get("Tuning", "Residents").MealSeconds / math.max(clock:TimeScale(), 0.01)
	if phase == "Surge" or not clock:IsRunning() and phase == nil then
		local roomId, spot = spotAcross("Quarters", "^Bed%d+$", order)
		return `Sleep:{roomId}:{order}`, roomId, spot, "Sleep"
	end
	-- Quarantine (Prompt 24; Section 10: "quarantine in Quarters"): a sick resident with no job
	-- keeps to their bed, away from the Kitchen and the Lounge
	if resident.Sick and not resident.Job and #grid:RoomsOfType("Quarters") > 0 then
		local roomId, spot = spotAcross("Quarters", "^Bed%d+$", order)
		return `Quarantine:{roomId}:{order}`, roomId, spot, "Sleep"
	end
	if phase == "Day" and os.clock() - dayStartedAt < mealSeconds and #grid:RoomsOfType("Kitchen") > 0 then
		local roomId, spot = spotAcross("Kitchen", "^Seat%d+$", order)
		return `Eat:{roomId}:{order}`, roomId, spot, "Eat"
	end
	if resident.Job and grid:Room(resident.Job) then
		local workers = residents:Workers(resident.Job)
		local index = 1
		for i, worker in workers do
			if worker.Id == id then
				index = i
			end
		end
		local spots = socketsOf(resident.Job, "^WorkSpot%d+$")
		local room = grid:Room(resident.Job)
		local spot = spots[index] or spots[1]
			or CFrame.new(Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, 0, 4))
		return `Work:{resident.Job}:{index}`, resident.Job, spot, "Work"
	end
	if #grid:RoomsOfType("Lounge") > 0 then
		local roomId, spot = spotAcross("Lounge", "^Seat%d+$", order)
		return `Idle:{roomId}:{order}`, roomId, spot, "Idle"
	end
	local roomId, spot = spotAcross("Quarters", "^Bed%d+$", order)
	return `Idle:{roomId}:{order}`, roomId, spot, "Idle"
end

local function unitOf(position: Vector3): string?
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return grid:Bunker():UnitAt(floor, column)
end

local function setGoal(body: Body, goal: string, roomId: string?, spot: CFrame?, activity: string)
	body.HazardVersion = Hazards.Version()
	body.Goal = goal
	body.GoalActivity = activity
	body.Points = {}
	body.Index = 1
	body.Best = math.huge
	body.Since = os.clock()
	if not roomId or not spot then
		return
	end
	standUp(body)
	local from = unitOf(body.Root.Position)
	local to = unitOf(spot.Position + Vector3.new(0, 1, 0)) or roomId
	local points, why = nil, nil
	if from then
		points, why = PathGraph.Waypoints(grid:Bunker(), function(unit: string): Model?
			return grid:RoomModel(unit)
		end, body.Root.Position, from, to, spot.Position)
	end
	if why == "Blocked" then
		-- cave-in rubble cuts them off (Prompt 13): they wait where they are until it's cleared
		body.Points = {}
		body.GoalActivity = "Idle"
		body.Humanoid:MoveTo(body.Root.Position)
		setActivity(body, "Idle")
		if not body.Trapped then
			body.Trapped = true
			residents:SetTrapped(body.Id, true)
		end
		return
	end
	if body.Trapped then
		body.Trapped = false
		residents:SetTrapped(body.Id, false)
	end
	body.Points = points or { spot.Position }
	setActivity(body, "Walk")
end

local function revivePrompt(body: Body, on: boolean)
	if on and not body.Prompt then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Revive (1 Medkit)"
		local resident = residents:Get(body.Id)
		prompt.ObjectText = if resident then Residents.Name(resident) else "Resident"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (Prompt 11)
		prompt:SetAttribute("Kind", "ReviveResident")
		prompt.Triggered:Connect(function(player: Player)
			local ok, why = residents:Revive(body.Id, player)
			if not ok and why then
				Remotes.FireClient("Alert", player, "Warning", why)
			end
		end)
		prompt.Parent = body.Root
		body.Prompt = prompt
	elseif not on and body.Prompt then
		body.Prompt:Destroy()
		body.Prompt = nil
	end
end

local function step(body: Body, order: number)
	local goal, roomId, spot, activity = plan(body.Id, order)
	if goal == "Gone" then
		return
	end
	if goal == "Down" then
		if body.Goal ~= "Down" then
			body.Goal = "Down"
			body.Points = {}
			lie(body, nil)
			setActivity(body, "Down")
			revivePrompt(body, true)
		end
		return
	end
	if body.Goal == "Down" then
		revivePrompt(body, false)
		standUp(body)
	end
	if goal ~= body.Goal or body.HazardVersion ~= Hazards.Version() then
		if goal == "Leave" and body.Goal ~= "Leave" then
			body.LeaveSince = os.clock()
		end
		setGoal(body, goal, roomId, spot, activity)
	end
	if goal == "Leave" then
		-- off the map once they reach the door, or after LeaveSeconds whatever is in their way
		local arrived = body.Points[body.Index] == nil
		if arrived or os.clock() - (body.LeaveSince or os.clock()) > Config.Get("Tuning", "Expeditions").LeaveSeconds then
			bodies[body.Id] = nil
			local model = body.Model
			body.Humanoid:MoveTo(body.Root.Position)
			setActivity(body, "Idle")
			task.delay(0.4, function()
				model:Destroy()
			end)
			return
		end
	end
	local speed = slowedSpeed(body)
	if math.abs(body.Humanoid.WalkSpeed - speed) > 0.05 then
		body.Humanoid.WalkSpeed = speed
	end
	if string.sub(goal, 1, 11) == "RallyFight:" then
		-- rallied (Prompt 20): fight it beside the leader, with the weapon they carry
		local monster = combat:Get(string.sub(goal, 12))
		if monster and monster.State == "Alive" then
			local t = Config.Get("Tuning", "MonsterAI")
			local reach = Config.Get("Tuning", "Classes").RallyReach
			local flat = Vector3.new(monster.Root.Position.X, body.Root.Position.Y, monster.Root.Position.Z)
			if (flat - body.Root.Position).Magnitude > math.max(reach - 2, 3) + monster.Reach then
				body.Humanoid:MoveTo(flat)
			else
				body.Humanoid:MoveTo(body.Root.Position)
				if os.clock() - (swattedAt[body.Id] or 0) >= t.ResidentSwatSeconds then
					swattedAt[body.Id] = os.clock()
					local resident = residents:Get(body.Id)
					local held = resident and resident.Weapon and Config.Find("Items", (Residents.Piece(resident.Weapon)) or "")
					local damage = t.ResidentSwatDamage -- bare hands (the Brave)
					if held and held.Melee then
						damage = held.Melee.Damage
					elseif held and held.Gun and resident then
						-- Section 11: "using the shared Ammo pool". With none left they use their hands.
						if economy:Use("Ammo", held.Gun.AmmoPerShot or 1) then
							damage = held.Gun.Damage * (Residents.Trait(resident, "GunDamage") or 1) -- a Sharpshooter's
						elseif os.clock() - dryAt > DRY_ALERT_SECONDS then
							dryAt = os.clock()
							Remotes.FireAllClients("Alert", "Warning", "THE RESIDENTS' GUNS ARE EMPTY: THE STOCKPILE HAS NO AMMO")
						end
					end
					combat:Damage(monster.Id, damage, body.Id, "rallied")
				end
			end
			setActivity(body, "Fight")
		end
		return
	end
	if string.sub(goal, 1, 5) == "Swat:" then
		-- a lone Burrow Tick: stand and swat it (Section 11)
		local tickId = string.sub(goal, 6)
		local tick = combat:Get(tickId)
		if tick and tick.State == "Alive" then
			local t = Config.Get("Tuning", "MonsterAI")
			local flat = Vector3.new(tick.Root.Position.X, body.Root.Position.Y, tick.Root.Position.Z)
			if (flat - body.Root.Position).Magnitude > 4 then
				body.Humanoid:MoveTo(flat)
			else
				body.Humanoid:MoveTo(body.Root.Position)
				if os.clock() - (swattedAt[body.Id] or 0) >= t.ResidentSwatSeconds then
					swattedAt[body.Id] = os.clock()
					combat:Damage(tickId, t.ResidentSwatDamage, body.Id, "swatted")
				end
			end
			setActivity(body, "Fight")
		end
		return
	end
	local target = body.Points[body.Index]
	if not target then
		-- arrived: face the spot's way, and lie down in bed
		if body.Model:GetAttribute("Activity") ~= body.GoalActivity then
			setActivity(body, body.GoalActivity)
			if body.GoalActivity == "Sleep" and spot and string.match(goal, "^Sleep") then
				lie(body, spot)
			end
		end
		return
	end
	local root = body.Root
	local distance = (Vector3.new(target.X, 0, target.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	if distance <= ARRIVE and math.abs(target.Y - (root.Position.Y - 3)) < 6 then
		body.Index += 1
		body.Best = math.huge
		body.Since = os.clock()
		local nextPoint = body.Points[body.Index]
		if nextPoint then
			body.Humanoid:MoveTo(nextPoint)
		else
			body.Humanoid:MoveTo(root.Position)
		end
		return
	end
	if distance < body.Best - 0.5 then
		body.Best = distance
		body.Since = os.clock()
	elseif os.clock() - body.Since > STUCK_SECONDS then
		-- stuck on furniture or a corner: step to the waypoint
		root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
		body.Best = math.huge
		body.Since = os.clock()
	end
	body.Humanoid:MoveTo(target)
end

-- Lifecycle -----------------------------------------------------------------------------------------

-- The Warden's Rally Call (Prompt 20). Returns how many answer.
function ResidentBrain:Rally(ids: { string }, leader: Player, seconds: number, bonus: number, instant: boolean?): number
	local root = leaderRoot(leader)
	if not root or not unitAt(root.Position) then
		return 0
	end
	local n = 0
	for i, id in ids do
		local body = bodies[id]
		if body and not body.Lying then
			rallies[id] = { Until = os.clock() + seconds, Leader = leader, Bonus = bonus }
			fleeing[id] = nil
			if instant then
				local angle = i * 2.4
				body.Root.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 2))
				body.Goal = nil
			end
			n += 1
		end
	end
	return n
end

function ResidentBrain:RallyBonus(id: string): number
	local rally = rallies[id]
	return if rally and os.clock() < rally.Until then rally.Bonus else 1
end

function ResidentBrain:Body(id: string): Model?
	local body = bodies[id]
	return if body then body.Model else nil
end

function ResidentBrain:Activity(id: string): string?
	local body = bodies[id]
	return if body then body.Model:GetAttribute("Activity") :: string? else nil
end

local function sync()
	for _, resident in residents:All() do
		local body = bodies[resident.Id]
		if resident.State == "Dead" then
			if body then
				bodies[resident.Id] = nil
				local model = body.Model
				task.delay(2, function()
					model:Destroy()
				end)
			end
		elseif not body then
			if resident.State ~= "Away" then -- the away have no body (Prompt 18)
				spawnBody(resident.Id)
			end
		elseif body.Model.Parent == nil then
			bodies[resident.Id] = nil
		end
	end
end

local function groups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RESIDENT_GROUP)
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(RESIDENT_GROUP, RESIDENT_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(RESIDENT_GROUP, PLAYER_GROUP, false)
	local function character(model: Model)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CollisionGroup = PLAYER_GROUP
			end
		end
		model.DescendantAdded:Connect(function(part: Instance)
			if part:IsA("BasePart") then
				part.CollisionGroup = PLAYER_GROUP
			end
		end)
	end
	local function player(p: Player)
		if p.Character then
			character(p.Character)
		end
		p.CharacterAdded:Connect(character)
	end
	for _, p in Players:GetPlayers() do
		player(p)
	end
	Players.PlayerAdded:Connect(player)
end

function ResidentBrain:Init(registry)
	residents = registry.ResidentService
	grid = registry.BunkerGrid
	clock = registry.CycleClock
	combat = registry.CombatService
	economy = registry.EconomyService
	registry.DevService:Register("brains", {
		Description = "Where every resident is going and what they are doing.",
		Usage = "brains",
		Run = function(): string?
			local lines = {}
			for id, body in bodies do
				table.insert(lines, string.format("%s %s -> %s (waypoint %d of %d), at %s", id,
					tostring(body.Model:GetAttribute("Activity")), tostring(body.Goal), body.Index, #body.Points,
					tostring(Vector3.new(math.floor(body.Root.Position.X), math.floor(body.Root.Position.Y), math.floor(body.Root.Position.Z)))))
			end
			table.sort(lines)
			return if #lines > 0 then table.concat(lines, "\n") else "no resident bodies"
		end,
	})
end

function ResidentBrain:Start()
	groups()
	clock.CycleStarted:Connect(function()
		dayStartedAt = os.clock()
	end)
	residents.Changed:Connect(function(id: string)
		local body = bodies[id]
		if body then
			body.Humanoid.WalkSpeed = speedFor(id)
		end
		sync()
	end)
	sync()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local order = 0
		for _, resident in residents:All() do
			local body = bodies[resident.Id]
			if body and resident.State ~= "Dead" then
				order += 1
				local ok, err = pcall(step, body, order)
				if not ok then
					log:Warn("%s: %s", resident.Id, tostring(err))
				end
			end
		end
	end)
	log:Info("%d resident bodies in the bunker", #residents:All())
end

return ResidentBrain
