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
	* Down: lying where they fell with a Revive prompt (a Medkit from the stockpile); dead: gone.
	They walk the room graph (Lib.PathGraph: doorways, Shaft stairs) with Humanoid:MoveTo, at a
	speed from their Speed stat. A resident stuck for STUCK_SECONDS steps to their next waypoint.
	Residents pass through each other and through players (collision groups).

	API:
		ResidentBrain:Body(id): Model?
		ResidentBrain:Activity(id): string?
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)
local PathGraph = require(ServerScriptService.Lib.PathGraph)

local log = Log.new("ResidentBrain")

local ResidentBrain = {
	Name = "ResidentBrain",
	Dependencies = { "ResidentService", "BunkerGrid", "CycleClock", "DevService" },
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
}

local residents: any = nil
local grid: any = nil
local clock: any = nil
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

local function plan(id: string, order: number): (string, string?, CFrame?, string)
	local resident = residents:Get(id)
	if not resident then
		return "Gone", nil, nil, "Idle"
	end
	if resident.State == "Down" then
		return "Down", nil, nil, "Down"
	end
	local phase = clock:Phase()
	local mealSeconds = Config.Get("Tuning", "Residents").MealSeconds / math.max(clock:TimeScale(), 0.01)
	if phase == "Surge" or not clock:IsRunning() and phase == nil then
		local roomId, spot = spotAcross("Quarters", "^Bed%d+$", order)
		return `Sleep:{roomId}:{order}`, roomId, spot, "Sleep"
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
	local points = if from then PathGraph.Waypoints(grid:Bunker(), function(unit: string): Model?
		return grid:RoomModel(unit)
	end, body.Root.Position, from, to, spot.Position) else nil
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
	if goal ~= body.Goal then
		setGoal(body, goal, roomId, spot, activity)
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
			spawnBody(resident.Id)
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
