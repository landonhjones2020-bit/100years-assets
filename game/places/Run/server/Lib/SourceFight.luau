--!strict
--[[
	SourceFight: the Source's own fight (bible Sections 5 and 10; Prompt 25), driven by BossService,
	which owns the fight, the Boss collection, the model and its clips. Run place, server.

	Section 10: "Several phases: tendrils in many rooms at once, then the core, so the team has to
	split up and regroup." The arithmetic is Shared.Rules.Boss (SourceStage, SourceTendrils,
	SourceRooms, SourceWound, SourceCoreOver); the numbers are Tuning.Source (provisional).

	* Stages (Tuning.Source.Stages; the fight's Phase is the stage): Tendrils, Core, Tendrils, Core.
	* A Tendrils stage: its eye is shut. Tendrils rise in rooms spread over the bunker's floors (in
	  its chamber some rise round it instead, and the rest in the deepest rooms). Each is a
	  combatant of its own (MonsterType SourceTendril, clips through NPCAnimator): it turns to
	  whoever comes near and slams them, and with nobody in reach it slams its room. Each one cut
	  down wounds the Source (Rules.Boss.SourceWound), and the last ends the stage.
	* A Core stage: the eye opens (BossService's hit modifier makes it the weak point). Roots burst
	  up under survivors: a RootMark part in workspace.Monsters (Radius, LandsAt), which clients
	  draw, then the damage. In a stage with RegrowSeconds a tendril grows back now and then (those
	  take nothing off the Source). The stage ends at its health (SourceCoreOver); the last at its
	  death.
	* The Source's own turning and slams are BossService's (it has every boss's).

	API (ctx is BossService's: its services and helpers):
		SourceFight.new(chamberSockets: { CFrame }?): State
		SourceFight.start(ctx, f)                       -- it is up: stage 1
		SourceFight.tick(ctx, f, dt), SourceFight.frame(ctx, f, dt)
		SourceFight.onDied(ctx, f, id): boolean         -- a tendril's death (true: it was one)
		SourceFight.onDamaged(f, id, source)
		SourceFight.isTendril(f, id): boolean
		SourceFight.open(f): boolean                    -- is its eye open?
		SourceFight.base(f): string                     -- its resting clip: Idle or OpenIdle
		SourceFight.counts(f): (number, number)         -- tendrils standing that hold the stage, and all
		SourceFight.places(f): { string }               -- where they stand, for the HUD
		SourceFight.rooms(f): { string }                -- the rooms they stand in, for the mini-map
		SourceFight.regrow(ctx, f), SourceFight.erupt(ctx, f)   -- now (DevTools)
		SourceFight.skip(ctx, f)                        -- cut every tendril down now (DevTools)
		SourceFight.cleanup(ctx, f, wither)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Boss = require(Shared.Rules.Boss)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)

local log = Log.new("SourceFight")

local SourceFight = {}

export type Tendril = {
	Id: string,
	Model: Model,
	Root: BasePart,
	At: Vector3, -- where its crater is, on the floor
	Yaw: number,
	Shown: number, -- the yaw its model was last put at
	Floor: number?,
	Column: number?,
	RoomId: string?,
	Where: string,
	Holds: boolean, -- cutting it down wounds the Source (a regrown one doesn't)
	BornAt: number,
	Up: boolean,
	Busy: number,
	NextAttack: number,
}

export type State = {
	Stage: number,
	Kind: string, -- "Tendrils" | "Core"
	Open: boolean,
	Tendrils: { [string]: Tendril },
	LastBy: { [string]: string },
	Sockets: { CFrame }, -- its chamber's tendril spots (empty in the bunker)
	Chamber: boolean,
	NextErupt: number,
	NextRegrow: number,
	Marks: { Instance },
}

local RISE_SECONDS = 0.5 -- the crater comes up this fast; the Rise clip brings the trunk up after it
local CELL_BACK = 6 -- a tendril stands this far behind its cell's middle, clear of the doorways

function SourceFight.new(chamberSockets: { CFrame }?): State
	return {
		Stage = 0,
		Kind = "Tendrils",
		Open = false,
		Tendrils = {},
		LastBy = {},
		Sockets = chamberSockets or {},
		Chamber = chamberSockets ~= nil,
		NextErupt = math.huge,
		NextRegrow = math.huge,
		Marks = {},
	}
end

local function t(): { [string]: any }
	return Config.Get("Tuning", "Source")
end

local function stateOf(f: any): State
	return f.Source :: State
end

function SourceFight.open(f: any): boolean
	local s = f.Source :: State?
	return s ~= nil and s.Open
end

function SourceFight.base(f: any): string
	return if SourceFight.open(f) then "OpenIdle" else "Idle"
end

function SourceFight.isTendril(f: any, id: string): boolean
	local s = f.Source :: State?
	return s ~= nil and s.Tendrils[id] ~= nil
end

function SourceFight.counts(f: any): (number, number)
	local s = f.Source :: State?
	local holds, all = 0, 0
	if s then
		for _, tendril in s.Tendrils do
			all += 1
			if tendril.Holds then
				holds += 1
			end
		end
	end
	return holds, all
end

function SourceFight.places(f: any): { string }
	local s = f.Source :: State?
	local list = {}
	if s then
		for _, tendril in s.Tendrils do
			table.insert(list, tendril.Where)
		end
		table.sort(list)
	end
	return list
end

-- The rooms tendrils stand in (the mini-map blinks them).
function SourceFight.rooms(f: any): { string }
	local s = f.Source :: State?
	local list = {}
	if s then
		for _, tendril in s.Tendrils do
			if tendril.RoomId and not table.find(list, tendril.RoomId) then
				table.insert(list, tendril.RoomId)
			end
		end
		table.sort(list)
	end
	return list
end

-- Tendrils -------------------------------------------------------------------------------------------

local function tendrilModel(): (Model, BasePart)
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild("Monster_SourceTendril")
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		-- no art in this place: a post with an eye, so the fight still plays
		model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2.4, 2, 2.4)
		root.Transparency = 1
		root.CFrame = CFrame.new(0, 1, 0)
		root.Parent = model
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Size = Vector3.new(2.4, 11, 2.4)
		trunk.Color = Color3.fromHex("#6E4766")
		trunk.CFrame = CFrame.new(0, 5.5, 0)
		trunk.CanCollide = false
		trunk.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = trunk
		weld.Parent = root
		model.PrimaryPart = root
		model.WorldPivot = CFrame.identity
		model:SetAttribute("Graybox", true)
	end
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
			part.CanCollide = false
			part.Anchored = part == root
		end
	end
	root.CanQuery = false
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.MaxHealth = math.huge -- CombatService keeps its health
		humanoid.Health = math.huge
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid.PlatformStand = true
	end
	return model, root
end

local function place(tendril: Tendril, sink: number)
	tendril.Model:PivotTo(CFrame.new(tendril.At - Vector3.new(0, sink, 0)) * CFrame.Angles(0, tendril.Yaw, 0))
	tendril.Shown = tendril.Yaw
end

local function raise(ctx: any, f: any, at: Vector3, yaw: number, where: string, spot: Boss.TendrilSpot?, holds: boolean): Tendril?
	local s = stateOf(f)
	local model, root = tendrilModel()
	model:SetAttribute("Rig", "SourceTendril")
	model:SetAttribute("MonsterType", "SourceTendril")
	model:SetAttribute("Boss", f.BossId)
	model:SetAttribute("Tendril", true)
	model:SetAttribute("Where", where)
	model:SetAttribute("Activity", "Rise")
	local players = math.max(#ctx.session:ReadyPlayers(), 1)
	local tendril: Tendril = {
		Id = "",
		Model = model,
		Root = root,
		At = at,
		Yaw = yaw,
		Shown = yaw,
		Floor = if spot then spot.Floor else nil,
		Column = if spot then spot.Column else nil,
		RoomId = if spot then spot.RoomId else nil,
		Where = where,
		Holds = holds,
		BornAt = os.clock(),
		Up = false,
		Busy = os.clock() + t().TendrilRiseSeconds,
		NextAttack = os.clock() + t().TendrilRiseSeconds + 0.6,
	}
	place(tendril, t().TendrilRiseDepth)
	model.Parent = ctx.holder()
	local id = ctx.combat:Register(model, {
		Kind = "Monster", Team = "Monsters", Health = Boss.TendrilHealth(players), MonsterType = "SourceTendril", Root = root,
	})
	if not id then
		model:Destroy()
		return nil
	end
	tendril.Id = id
	model.Name = `SourceTendril_{id}`
	s.Tendrils[id] = tendril
	ctx.rockBurst(at, 14, f)
	return tendril
end

local function roomName(ctx: any, spot: Boss.TendrilSpot): string
	local room = if spot.RoomId then ctx.grid:Room(spot.RoomId) else nil
	local name = if room then string.upper(Config.Get("Rooms", room.Type).Name) else "THE TUNNEL"
	return `{name} · FLOOR {spot.Floor}`
end

-- The cells the Source's own body fills (a tendril never rises through it).
local function arenaCells(f: any): { [string]: boolean }
	local avoid = {}
	if f.Arena and not stateOf(f).Chamber then
		for c = f.Arena.From, f.Arena.To do
			avoid[Grid.Key(f.Arena.Floor, c)] = true
		end
	end
	return avoid
end

local function raiseInRooms(ctx: any, f: any, count: number, holds: boolean): number
	local s = stateOf(f)
	local taken = arenaCells(f)
	for _, tendril in s.Tendrils do
		if tendril.Floor and tendril.Column then
			taken[Grid.Key(tendril.Floor, tendril.Column)] = true
		end
		if tendril.RoomId then
			local room = ctx.grid:Room(tendril.RoomId)
			if room then
				for c = room.Column, room.Column + room.Span - 1 do
					taken[Grid.Key(room.Floor, c)] = true -- one tendril to a room
				end
			end
		end
	end
	local spots = Boss.SourceRooms(ctx.grid:Bunker(), count, function(n: number): number
		return ctx.rng:NextInteger(1, n)
	end, taken, s.Chamber)
	local made = 0
	for _, spot in spots do
		local cell = Grid.CellPosition(spot.Floor, spot.Column)
		if raise(ctx, f, cell + Vector3.new(0, 0, -CELL_BACK), math.pi, roomName(ctx, spot), spot, holds) then
			made += 1
		end
	end
	return made
end

local function raiseInChamber(ctx: any, f: any, count: number, holds: boolean): number
	local s = stateOf(f)
	local free = {}
	for _, at in s.Sockets do
		local clear = true
		for _, tendril in s.Tendrils do
			if (tendril.At - at.Position).Magnitude < 4 then
				clear = false
			end
		end
		if clear then
			table.insert(free, at)
		end
	end
	local made = 0
	while made < count and #free > 0 do
		local at = table.remove(free, ctx.rng:NextInteger(1, #free)) :: CFrame
		local toSource = Vector3.new(f.X - at.Position.X, 0, f.Z - at.Position.Z)
		-- its back to the Source, looking out at whoever comes
		local yaw = if toSource.Magnitude > 0.5 then math.atan2(toSource.X, toSource.Z) else math.pi
		if raise(ctx, f, at.Position, yaw, "THE CHAMBER", nil, holds) then
			made += 1
		end
	end
	return made
end

local function summary(f: any): string
	local where: { [string]: number } = {}
	local order = {}
	for _, place_ in SourceFight.places(f) do
		if not where[place_] then
			where[place_] = 0
			table.insert(order, place_)
		end
		where[place_] += 1
	end
	local parts = {}
	for _, place_ in order do
		table.insert(parts, if where[place_] > 1 then `{place_} ×{where[place_]}` else place_)
	end
	return table.concat(parts, ", ")
end

-- Stages ---------------------------------------------------------------------------------------------

local function enter(ctx: any, f: any, stage: number)
	local s = stateOf(f)
	local first = s.Stage == 0
	s.Stage = stage
	s.Kind = Boss.SourceStage(stage)
	f.Phase = stage
	if s.Kind == "Tendrils" then
		local wasOpen = s.Open
		s.Open = false
		s.NextErupt = math.huge
		s.NextRegrow = math.huge
		local players = math.max(#ctx.session:ReadyPlayers(), 1)
		local total, inChamber = Boss.SourceTendrils(stage, players, s.Chamber)
		local made = raiseInChamber(ctx, f, inChamber, true)
		made += raiseInRooms(ctx, f, total - made, true)
		if not first then
			-- its lids slam shut and it roars as they come up
			local hold = (if wasOpen then t().CloseSeconds else 0) + t().RoarSeconds
			f.Busy = os.clock() + hold
			f.NextAttack = f.Busy + 1
			if wasOpen then
				ctx.setActivity("Close", true)
				task.delay(t().CloseSeconds, function()
					if ctx.current() == f and f.State == "Fighting" and stateOf(f).Stage == stage then
						ctx.setActivity("Roar", true)
					end
				end)
			else
				ctx.setActivity("Roar", true)
			end
		end
		for _ = 1, Boss.ByPhase(t().Breaches, stage) do
			local ok, err = pcall(function()
				ctx.threat:ExtraBreach()
			end)
			if not ok then
				log:Warn("extra breach: %s", tostring(err))
			end
		end
		if made > 0 then
			ctx.announce("Danger", `{Boss.Title(f.Name)} SHUTS ITS EYE · {made} TENDRILS: {summary(f)} · SPLIT UP AND CUT THEM DOWN`)
		end
		log:Info("%s stage %d: %d tendrils (%s)", f.Name, stage, made, summary(f))
	else
		s.Open = true
		f.Busy = os.clock() + t().OpenSeconds
		f.NextAttack = f.Busy + 1.5
		ctx.setActivity("Open", true)
		local every = Boss.ByPhase(t().EruptSeconds, stage)
		s.NextErupt = if every > 0 then os.clock() + t().OpenSeconds + every * 0.6 else math.huge
		local regrow = Boss.ByPhase(t().RegrowSeconds, stage)
		s.NextRegrow = if regrow > 0 then os.clock() + regrow else math.huge
		ctx.announce("Danger", `{Boss.Title(f.Name)} OPENS ITS EYE · REGROUP AND HIT THE EYE`)
		log:Info("%s stage %d: the core", f.Name, stage)
	end
	if f.Model then
		f.Model:SetAttribute("EyeOpen", s.Open)
		f.Model:SetAttribute("Stage", stage)
	end
	ctx.publish(true)
end

function SourceFight.start(ctx: any, f: any)
	enter(ctx, f, 1)
end

-- Roots ----------------------------------------------------------------------------------------------

local function floorUnder(position: Vector3, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local residents = workspace:FindFirstChild("Residents")
	if residents then
		table.insert(ignore, residents)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position, Vector3.new(0, -14, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function rootMark(ctx: any, f: any, at: Vector3)
	local s = stateOf(f)
	local radius = t().EruptRadius
	local mark = ctx.effectPart(at + Vector3.new(0, 0.15, 0), "RootMark")
	mark.Size = Vector3.new(radius * 2, 0.3, radius * 2)
	mark:SetAttribute("Radius", radius)
	mark:SetAttribute("LandsAt", ctx.now() + t().EruptWarnSeconds)
	table.insert(s.Marks, mark)
	task.delay(t().EruptWarnSeconds, function()
		if ctx.current() ~= f or not mark.Parent or f.State ~= "Fighting" then
			mark:Destroy()
			return
		end
		local centre = mark.Position
		local hit = 0
		for _, c in ctx.combat:All("Survivors") do
			local offset = c.Root.Position - centre
			if c.State == "Alive" and Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius + c.Reach and math.abs(offset.Y) < 9 then
				if f.CombatId and ctx.combat:Damage(c.Id, t().EruptDamage, f.CombatId, "root") > 0 then
					hit += 1
				end
			end
		end
		ctx.rockBurst(centre, 12, f)
		mark:SetAttribute("Landed", true)
		task.delay(0.9, function()
			mark:Destroy()
		end)
		if hit > 0 then
			log:Debug("a root hit %d", hit)
		end
	end)
end

function SourceFight.erupt(ctx: any, f: any): number
	local s = stateOf(f)
	local origin = Vector3.new(f.X, f.Y, f.Z)
	local players, others = {}, {}
	for _, c in ctx.combat:All("Survivors") do
		local offset = c.Root.Position - origin
		if c.State == "Alive" and offset.Magnitude <= t().EruptRange and math.abs(offset.Y) < 22 then
			table.insert(if c.Kind == "Player" then players else others, c)
		end
	end
	local count = Boss.ByPhase(t().Eruptions, s.Stage)
	if count <= 0 then
		count = 2 -- asked for outside a Core stage (DevTools)
	end
	local made = 0
	for _, list in { players, others } do
		while made < count and #list > 0 do
			local c = table.remove(list, ctx.rng:NextInteger(1, #list))
			local p = c.Root.Position
			local at = Vector3.new(p.X + ctx.rng:NextNumber(-1.5, 1.5), 0, p.Z + ctx.rng:NextNumber(-1.5, 1.5))
			rootMark(ctx, f, Vector3.new(at.X, floorUnder(p, p.Y - 3), at.Z))
			made += 1
		end
	end
	return made
end

function SourceFight.regrow(ctx: any, f: any): boolean
	local s = stateOf(f)
	local made = 0
	if s.Chamber then
		made = raiseInChamber(ctx, f, 1, false)
	end
	if made == 0 then
		made = raiseInRooms(ctx, f, 1, false)
	end
	if made > 0 then
		ctx.announce("Danger", `A TENDRIL GROWS BACK: {summary(f)}`)
		ctx.publish(true)
	end
	return made > 0
end

-- Each tick -------------------------------------------------------------------------------------------

local function nearest(ctx: any, tendril: Tendril, range: number): (any?, number)
	local best, bestDistance = nil, math.huge
	for _, c in ctx.combat:All("Survivors") do
		local offset = c.Root.Position - tendril.At
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if c.State == "Alive" and flat <= range and math.abs(offset.Y) < 9 and flat < bestDistance then
			best, bestDistance = c, flat
		end
	end
	return best, bestDistance
end

local function strike(ctx: any, f: any, tendril: Tendril, room: boolean)
	local model = tendril.Model
	local hitTime = (model:GetAttribute("HitTime") :: number?) or 0.55
	model:SetAttribute("Activity", "Attack")
	model:SetAttribute("AttackAt", ctx.now())
	tendril.Busy = os.clock() + hitTime + 0.75
	tendril.NextAttack = os.clock() + t().TendrilAttackSeconds
	task.delay(hitTime, function()
		if ctx.current() ~= f or stateOf(f).Tendrils[tendril.Id] ~= tendril or not model.Parent then
			return
		end
		local at = ctx.socket(model, "Slam").Position
		if model:GetAttribute("Socket_Slam") == nil then
			at = (model:GetPivot() * CFrame.new(0, 0, -7)).Position
		end
		local hit = 0
		for _, c in ctx.combat:All("Survivors") do
			local offset = c.Root.Position - at
			if c.State == "Alive" and Vector3.new(offset.X, 0, offset.Z).Magnitude <= t().TendrilRadius + c.Reach and math.abs(offset.Y) < 9 then
				if ctx.combat:Damage(c.Id, t().TendrilDamage, tendril.Id, "slammed") > 0 then
					hit += 1
				end
			end
		end
		if room and hit == 0 and tendril.RoomId then
			local r = ctx.grid:Room(tendril.RoomId)
			if r and r.HP > 0 then
				ctx.grid:SetHP(tendril.RoomId, math.max(r.HP - t().TendrilRoomDamage, 0))
			end
		end
		ctx.rockBurst(at, 5, f)
	end)
end

local function tickTendril(ctx: any, f: any, tendril: Tendril)
	if os.clock() < tendril.Busy then
		return
	end
	local model = tendril.Model
	if not tendril.Up then
		tendril.Up = true
	end
	local target, distance = nearest(ctx, tendril, t().TendrilSense)
	if os.clock() >= tendril.NextAttack then
		if target and distance <= t().TendrilReach then
			-- someone in reach: it waits until it has turned to them
			local offset = target.Root.Position - tendril.At
			local want = math.atan2(-offset.X, -offset.Z)
			local delta = (want - tendril.Yaw + math.pi) % (math.pi * 2) - math.pi
			if math.abs(delta) < math.rad(28) then
				strike(ctx, f, tendril, false)
				return
			end
		elseif tendril.RoomId then
			strike(ctx, f, tendril, true) -- nobody in reach: the room takes it
			return
		end
	end
	if model:GetAttribute("Activity") ~= "Idle" then
		model:SetAttribute("Activity", "Idle")
	end
end

function SourceFight.tick(ctx: any, f: any, _dt: number)
	local s = stateOf(f)
	if s.Stage == 0 or not f.CombatId then
		return
	end
	for _, tendril in table.clone(s.Tendrils) do
		tickTendril(ctx, f, tendril)
	end
	local health, max = ctx.combat:HealthOf(f.CombatId)
	if s.Kind == "Tendrils" then
		local holds = SourceFight.counts(f)
		if holds == 0 and os.clock() >= f.Busy then
			enter(ctx, f, math.min(s.Stage + 1, #t().Stages))
		end
		return
	end
	if Boss.SourceCoreOver(health, max, s.Stage) and os.clock() >= f.Busy then
		enter(ctx, f, s.Stage + 1)
		return
	end
	if os.clock() >= s.NextErupt then
		s.NextErupt = os.clock() + Boss.ByPhase(t().EruptSeconds, s.Stage)
		SourceFight.erupt(ctx, f)
	end
	if os.clock() >= s.NextRegrow then
		s.NextRegrow = os.clock() + Boss.ByPhase(t().RegrowSeconds, s.Stage)
		local _, all = SourceFight.counts(f)
		if all < t().RegrowMax then
			SourceFight.regrow(ctx, f)
		end
	end
end

-- Every frame: tendrils come up out of the floor and turn to whoever is near (an anchored model
-- isn't smoothed between server ticks).
function SourceFight.frame(ctx: any, f: any, dt: number)
	local s = f.Source :: State?
	if not s then
		return
	end
	for _, tendril in s.Tendrils do
		local age = os.clock() - tendril.BornAt
		local rising = age < RISE_SECONDS
		if not rising and tendril.Up and os.clock() >= tendril.Busy then
			local target = nearest(ctx, tendril, t().TendrilSense)
			if target then
				local offset = target.Root.Position - tendril.At
				local want = math.atan2(-offset.X, -offset.Z)
				local delta = (want - tendril.Yaw + math.pi) % (math.pi * 2) - math.pi
				local step = math.rad(t().TendrilTurnDegreesPerSecond) * dt
				tendril.Yaw += math.clamp(delta, -step, step)
			end
		end
		if rising then
			local k = math.clamp(age / RISE_SECONDS, 0, 1)
			place(tendril, t().TendrilRiseDepth * (1 - k) * (1 - k))
		elseif math.abs(tendril.Yaw - tendril.Shown) > math.rad(0.5) or tendril.Model:GetPivot().Position.Y < tendril.At.Y - 0.01 then
			place(tendril, 0)
		end
	end
end

-- Hits and deaths -------------------------------------------------------------------------------------

function SourceFight.onDamaged(f: any, id: string, source: string?)
	local s = f.Source :: State?
	if s and source and s.Tendrils[id] then
		s.LastBy[id] = source
	end
end

function SourceFight.onDied(ctx: any, f: any, id: string): boolean
	local s = f.Source :: State?
	local tendril = if s then s.Tendrils[id] else nil
	if not s or not tendril then
		return false
	end
	local holdsBefore = SourceFight.counts(f)
	s.Tendrils[id] = nil
	local by = s.LastBy[id]
	s.LastBy[id] = nil
	ctx.rockBurst(tendril.At, 10, f)
	if tendril.Holds and s.Kind == "Tendrils" and f.CombatId and f.State == "Fighting" then
		local health, max = ctx.combat:HealthOf(f.CombatId)
		local wound = Boss.SourceWound(health, max, s.Stage, holdsBefore)
		if wound >= 1 then
			ctx.combat:Damage(f.CombatId, wound, by, "tendril")
		end
		local left = holdsBefore - 1
		if left > 0 then
			ctx.announce("Info", `A TENDRIL IS CUT DOWN · {left} LEFT: {summary(f)}`)
		else
			ctx.announce("Info", "THE LAST TENDRIL IS CUT DOWN")
		end
	end
	ctx.publish(true)
	return true
end

function SourceFight.skip(ctx: any, f: any): number
	local s = stateOf(f)
	local n = 0
	for id in table.clone(s.Tendrils) do
		ctx.combat:Damage(id, 1e9, nil, "dev")
		n += 1
	end
	return n
end

-- Its tendrils go with it: wither (it died) dissolves them where they stand.
function SourceFight.cleanup(ctx: any, f: any, _wither: boolean?)
	local s = f.Source :: State?
	if not s then
		return
	end
	for id, tendril in table.clone(s.Tendrils) do
		s.Tendrils[id] = nil
		ctx.combat:Unregister(id)
		if tendril.Model.Parent then
			ctx.combat:Dissolve(tendril.Model)
		end
	end
	for _, mark in s.Marks do
		mark:Destroy()
	end
	table.clear(s.Marks)
	s.NextErupt = math.huge
	s.NextRegrow = math.huge
end

return SourceFight
