--!strict
--[[
	ClassAbilities: what each class ability does in the world, and the class devices that stay in it
	(bible Section 14). ClassService owns who has which class, cooldowns, uses and the remotes; this
	module is called with the player's class state and does the rest. Numbers: Tuning.Classes
	(provisional) and Config.Classes.

	Use(state, option, origin, look) -> (ok, text?, effect?, seconds?): ok spends the cooldown or the
	use; text is told to the player (a warning when not ok); effect and seconds are what stays on the
	player (Hold the Line's "Hold", a drone mode), for ClassService's damage filter and the HUD.

	The abilities (Section 14):
	* Survivor, Second Wind: heal SecondWindFraction of max health.
	* Engineer, Deploy Turret: an auto-turret in front of you (Prop_Turret) for its duration
	  (TurretDuration at level 3, shocks with TurretShock): it shoots the nearest monster in Range it
	  can see. One turret each; a new one replaces the old.
	  Barricades (Section 10: the Engineer seals a breach point): every room vent has a Barricade
	  prompt only Engineers see (ForClass); it costs the Barricade recipe (Config.Recipes; BarricadeCost:
	  half at level 2) from the stockpile and takes its Seconds. A barricaded vent opens less often
	  (BreachService's Barricaded, BarricadeWeight); the barricade stays with its room.
	* Medic, Triage Pulse: TriageHeal to every player, resident and rescued survivor within
	  TriageRadius; level 3 also clears radiation and goo slow (resident conditions are Prompt 26).
	  Touch heal (the passive): residents within TouchHealRange of a Medic heal TouchHealPerSecond.
	* Firefighter, Foam Burst: the fire in the room you stand in (else the nearest burning room within
	  FoamRange) goes out at once. Floods are Prompt 23.
	* Cook, Hearty Meal: the team's max health and stamina x its modifiers for one cycle, residents
	  +MoraleNow; level 2 heals everyone (MealHealFraction). The Cook's Kitchen bonus (Presence) follows
	  them into any Kitchen.
	* Security, Hold the Line: monsters within TauntRadius come for you (MonsterService:Taunt) and you
	  take HoldDamageTaken of their damage, for its duration.
	* Scout, Flare Ping: enemies (red), loot (amber) and survivors (green) within FlareRadius are
	  outlined for its duration, for the whole team.
	* Quartermaster, Emergency Requisition: RequisitionScrap Scrap, or RequisitionFoodWater Food and
	  Water, into the stockpile (up to its caps).
	* Radio Operator, Supply Call: a crate lands in front of you (Prop_SupplyCrate); opened, CrateLoot
	  goes into the stockpile in the bunker, or the opener's pack elsewhere.
	* Hazmat Tech, Decon Field: radiation off everyone in your room (within DeconRadius away from
	  rooms). Gas is Prompt 23.
	* Exterminator, Napalm Line: a burning strip (Napalm Length by Width) ahead of you for its
	  duration: monsters in it burn. Burning (flame guns and napalm) hurts Burn.DamagePerSecond for
	  Burn.Seconds; the Exterminator's burning spreads between monsters within Burn.SpreadRadius
	  (never to rooms: players' fire never starts room fires).
	* Marksman, Steady Shot: the next SteadyShots gun shots pierce and crit (WeaponService's shot hook).
	* Driller, Overdrive: OverdriveCells rock cells in a line from your cell (the way you look: left,
	  right or down) dig at once, each adding its Disturbance; not past the dig limit.
	* Scavenger, Magnet Sweep: containers, cave caches and dropped packs within MagnetRadius come to you.
	* Warden, Rally Call: armed residents within RallyFloors floors come to you and fight beside you,
	  RallyDamage times as hard, for its duration (ResidentBrain:Rally). Armed residents come with
	  Prompt 26's gear.
	* Demolitionist, Breaching Charge: a blast (Breaching Damage and Radius, times the explosive
	  modifiers) where you aim within Breaching Range; a rock cell there is cleared.
	* Spelunker, Grapple Line: zip to where you aim (Grapple Range), or pull the teammate you aim at
	  to you. The client moves the character (the Grapple remote).
	* Mad Scientist, Gadget Belt: Shock Trap (stuns what comes within Trap Radius), Teleport Beacon
	  (BeaconSeconds; the team teleports to it: TeleportToBeacon) or Gravity Well (holds and pulls
	  monsters within its Radius for its Seconds), each on its own cooldown.
	* Tinkerer, Drone Mode: the combat drone (always beside a Tinkerer: Prop_CombatDrone) shoots the
	  nearest monster it sees and picks up dropped packs near you; Guard (you take GuardDamageTaken),
	  Assault (AssaultMultiplier damage) or Repair (it repairs the nearest damaged room within
	  RepairRange instead of shooting) for the mode's duration. Level 2: two guns (fires twice as
	  often). Level 3: the drone revives you once per Surge (Drone.ReviveSeconds after you go down).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Dig = require(Shared.Rules.Dig)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Classes = require(Shared.Rules.Classes)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local RunState = require(Shared.RunState)
local Surface = require(Shared.Rules.Surface)
local Hazards = require(ServerScriptService.Lib.Hazards)

local log = Log.new("ClassAbilities")

export type State = {
	Player: Player,
	Class: string,
	Level: number,
	Option: number,
	Effect: string?,
	EffectUntil: number,
	Shots: number,
	DroneRevives: number,
}
export type Context = {
	Combat: any,
	Weapons: any,
	Monsters: any,
	Boss: any,
	Grid: any,
	Economy: any,
	Build: any,
	Disasters: any,
	Dig: any,
	Residents: any,
	Brain: any,
	Breaches: any,
	Surface: any,
	Deep: any,
	Inventory: any,
	Rescue: any,
	Clock: any,
	Session: any,
	State: (Player) -> State?,
	SetBeacon: (until_: number?, by: string?) -> (),
}

type Turret = { Owner: Player, Model: Model, Until: number, NextShot: number, Shock: boolean, Shots: number }
type Drone = { Owner: Player, Part: BasePart, Align: AlignPosition, Turn: AlignOrientation, NextShot: number, NextPickup: number }
type Strip = { Owner: Player, Part: BasePart, CFrame: CFrame, Size: Vector3, Until: number }
type Well = { Owner: Player, Part: BasePart, At: Vector3, Until: number }
type Trap = { Owner: Player, Part: BasePart, At: Vector3, Until: number }
type Burn = { Owner: Player?, Until: number, Spreads: boolean, Fire: Fire?, FireId: number }

local ctx: Context = nil :: any
local rng = Random.new()
local turrets: { [Player]: Turret } = {}
local drones: { [Player]: Drone } = {}
local strips: { Strip } = {}
local wells: { Well } = {}
local traps: { Trap } = {}
local burning: { [string]: Burn } = {} -- monster combatant id
-- Each fire a flame starts has an id, and a spread carries it on: a monster burns once in a given
-- fire (two monsters side by side passed one fire back and forth for good: playtest, Prompt 20).
local fireCount = 0
local lastFire: { [string]: number } = {} -- monster combatant id -> the fire it last burned in
local beacon: { Part: BasePart, Until: number, By: Player }? = nil
local barricaded: { [string]: boolean } = {} -- room id
local barricadeSpots: { [string]: BasePart } = {} -- room id -> the prompt's part
local crates = 0

local Abilities = {}

local function t(): { [string]: any }
	return Classes.Tuning()
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function standing(player: Player): boolean
	return player.Parent == Players and player:GetAttribute("Life") == "Alive" and rootOf(player) ~= nil
end

local function holder(name: string): Folder
	local found = workspace:FindFirstChild(name)
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

local function art(category: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	local model = folder and folder:FindFirstChild(name)
	return if model and model:IsA("Model") then model else nil
end

local function fx(player: Player, kind: string, at: Vector3?, data: { [string]: any }?)
	local state = ctx.State(player)
	Remotes.FireAllClients("AbilityFx", player.UserId, if state then state.Class else "", kind, at, data or {})
end

local function bodiesOf(): { Instance }
	local list: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(list, monsters)
	end
	for _, name in { "ClassDevices", "Finds", "Rescues" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(list, folder)
		end
	end
	local bunker = workspace:FindFirstChild("Bunker")
	local residents = bunker and bunker:FindFirstChild("Residents")
	if residents then
		table.insert(list, residents)
	end
	return list
end

-- Line of sight between two points, through bodies and devices.
local function clear(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = bodiesOf()
	return workspace:Raycast(from, to - from, params) == nil
end

-- The ground under a point (within 40 studs), or the point itself.
local function ground(at: Vector3, ignore: { Instance }?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or bodiesOf()
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -43, 0), params)
	return if hit then hit.Position else at
end

-- Where the camera's ray lands within `range` of the player (origin must be near them: the camera).
local function aim(player: Player, origin: Vector3, look: Vector3, range: number, hitPlayers: boolean?): RaycastResult?
	local root = rootOf(player)
	if not root or (origin - root.Position).Magnitude > 30 or look.Magnitude < 0.5 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { player.Character :: Instance }
	if not hitPlayers then
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(ignore, p.Character)
			end
		end
	end
	local devices = workspace:FindFirstChild("ClassDevices")
	if devices then
		table.insert(ignore, devices)
	end
	params.FilterDescendantsInstances = ignore
	local reach = range + (origin - root.Position).Magnitude
	local hit = workspace:Raycast(origin, look.Unit * reach, params)
	if hit and (hit.Position - root.Position).Magnitude <= range + 2 then
		return hit
	end
	return nil
end

local function unitAt(position: Vector3): string?
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return ctx.Grid:Bunker():UnitAt(floor, column)
end

local function roomAt(position: Vector3): any
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return ctx.Grid:RoomAt(floor, column)
end

local function roomCentre(room: any): Vector3
	local column = room.Column + (room.Span - 1) / 2
	return Grid.CellPosition(room.Floor, math.floor(column)) + Vector3.new(if room.Span % 2 == 0 then Grid.Pitch().X / 2 else 0, 3, 0)
end

local function playerCombatId(player: Player): string
	local c = ctx.Combat:PlayerCombatant(player)
	return if c then c.Id else `P{player.UserId}`
end

local function stun(model: Model, seconds: number)
	local current = model:GetAttribute("StunnedUntil")
	local untilAt = now() + seconds
	if type(current) ~= "number" or current < untilAt then
		model:SetAttribute("StunnedUntil", untilAt)
	end
end

local function makePart(name: string, size: Vector3, colour: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = colour
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- A model from the art pipeline when it exists, else `graybox()`; anchored, no collisions.
local function device(category: string, asset: string, graybox: () -> Model): Model
	local source = art(category, asset)
	local model = if source then source:Clone() else graybox()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	return model
end

local function socketOf(model: Model, name: string): Vector3?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("Attachment") then
		return found.WorldPosition
	elseif found and found:IsA("BasePart") then
		return found.Position
	end
	return nil
end

-- The nearest living monster within `range` of `from` that `from` can see.
local function nearestMonster(from: Vector3, range: number): any
	local best, bestDistance = nil, range
	for _, c in ctx.Combat:All("Monsters") do
		if c.State == "Alive" then
			local d = (c.Root.Position - from).Magnitude - c.Reach
			if d <= bestDistance and clear(from, c.Root.Position) then
				best, bestDistance = c, d
			end
		end
	end
	return best
end

-- Burning ------------------------------------------------------------------------------------------

-- A monster catches fire (flame guns, napalm): Burn.Seconds of Burn.DamagePerSecond; the owner's
-- BurnSpreadsBetweenMonsters lets it spread. fireId: the fire a spread carries on (none: a new fire).
function Abilities.Burn(targetId: string, owner: Player?, fireId: number?)
	local c = ctx.Combat:Get(targetId)
	if not c or c.State ~= "Alive" or c.Team ~= "Monsters" then
		return
	end
	local b = burning[targetId]
	local seconds = t().Burn.Seconds
	if b then
		b.Until = math.max(b.Until, os.clock() + seconds)
		if owner then
			b.Owner = owner
			b.Spreads = b.Spreads or Modifiers.PlayerValue(owner, "BurnSpreadsBetweenMonsters") ~= nil
		end
		return
	end
	if not fireId then
		fireCount += 1
		fireId = fireCount
	end
	lastFire[targetId] = fireId
	local fire = Instance.new("Fire")
	fire.Size = math.clamp(c.Reach * 1.5, 3, 12)
	fire.Heat = 6
	fire.Parent = c.Root
	burning[targetId] = {
		Owner = owner,
		Until = os.clock() + seconds,
		Spreads = owner ~= nil and Modifiers.PlayerValue(owner, "BurnSpreadsBetweenMonsters") ~= nil,
		Fire = fire,
		FireId = fireId :: number,
	}
end

local function tickBurning(dt: number)
	local b_ = t().Burn
	local spreadTo: { { Id: string, Owner: Player?, FireId: number } } = {}
	for id in lastFire do
		if not burning[id] and not ctx.Combat:Get(id) then
			lastFire[id] = nil
		end
	end
	for id, b in burning do
		local c = ctx.Combat:Get(id)
		if not c or c.State ~= "Alive" or os.clock() >= b.Until then
			if b.Fire then
				b.Fire:Destroy()
			end
			burning[id] = nil
		else
			local source = if b.Owner then playerCombatId(b.Owner) else nil
			ctx.Combat:Damage(id, b_.DamagePerSecond * dt, source, "burning")
			if b.Spreads then
				for _, other in ctx.Combat:All("Monsters") do
					if not burning[other.Id] and lastFire[other.Id] ~= b.FireId and other.State == "Alive"
						and (other.Root.Position - c.Root.Position).Magnitude - other.Reach <= b_.SpreadRadius then
						table.insert(spreadTo, { Id = other.Id, Owner = b.Owner, FireId = b.FireId })
					end
				end
			end
		end
	end
	for _, s in spreadTo do
		Abilities.Burn(s.Id, s.Owner, s.FireId)
	end
end

-- Survivor ------------------------------------------------------------------------------------------

local function secondWind(state: State): (boolean, string?, string?, number?)
	local c = ctx.Combat:PlayerCombatant(state.Player)
	if not c then
		return false, "YOU NEED TO BE STANDING"
	end
	local health, max = ctx.Combat:HealthOf(c.Id)
	if health >= max - 0.5 then
		return false, "YOU'RE AT FULL HEALTH"
	end
	local healed = ctx.Combat:Heal(c.Id, max * t().SecondWindFraction)
	fx(state.Player, "Heal", c.Root.Position, { Radius = 4 })
	return true, `SECOND WIND: +{math.floor(healed + 0.5)} HEALTH`
end

-- Engineer -----------------------------------------------------------------------------------------

local function turretGraybox(): Model
	local model = Instance.new("Model")
	model.Name = "Turret"
	local base = makePart("Base", Vector3.new(2.6, 0.6, 2.6), Color3.fromRGB(70, 78, 72), Enum.Material.Metal)
	base.CFrame = CFrame.new(0, 0.3, 0)
	base.Parent = model
	local post = makePart("Post", Vector3.new(0.6, 1.8, 0.6), Color3.fromRGB(96, 104, 98), Enum.Material.Metal)
	post.CFrame = CFrame.new(0, 1.5, 0)
	post.Parent = model
	local head = makePart("Head", Vector3.new(1.4, 1, 2.2), Color3.fromRGB(196, 150, 54), Enum.Material.Metal)
	head.CFrame = CFrame.new(0, 2.7, 0)
	head.Parent = model
	local barrel = makePart("Barrel", Vector3.new(0.35, 0.35, 1.6), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
	barrel.CFrame = CFrame.new(0, 2.7, -1.7)
	barrel.Parent = model
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0, -0.8)
	muzzle.Parent = barrel
	model.PrimaryPart = base
	return model
end

local function removeTurret(player: Player)
	local turret = turrets[player]
	turrets[player] = nil
	if turret and turret.Model.Parent then
		turret.Model:Destroy()
	end
end

local function deployTurret(state: State, _origin: Vector3, _look: Vector3): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	removeTurret(player)
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local at = ground(root.Position + flat.Unit * t().Turret.PlaceDistance)
	local model = device("Props", "Prop_Turret", turretGraybox)
	model.Name = `Turret_{player.UserId}`
	model:SetAttribute("Owner", player.UserId)
	model:PivotTo(CFrame.lookAt(at, at + flat))
	model.Parent = holder("ClassDevices")
	local seconds = Classes.Duration(state.Class, state.Level)
	turrets[player] = {
		Owner = player,
		Model = model,
		Until = os.clock() + seconds,
		NextShot = 0,
		Shock = Modifiers.PlayerValue(player, "TurretShock") ~= nil,
		Shots = 0,
	}
	fx(player, "Deploy", at, {})
	return true, `TURRET DEPLOYED FOR {math.floor(seconds)} S`
end

local function tickTurrets()
	local tt = t().Turret
	for player, turret in turrets do
		if os.clock() >= turret.Until or player.Parent ~= Players or not turret.Model.Parent then
			removeTurret(player)
		elseif os.clock() >= turret.NextShot then
			local muzzle = socketOf(turret.Model, "Muzzle") or (turret.Model:GetPivot().Position + Vector3.new(0, 2.7, 0))
			local target = nearestMonster(muzzle, tt.Range)
			if target then
				turret.NextShot = os.clock() + tt.FireSeconds
				local pivot = turret.Model:GetPivot()
				local flat = Vector3.new(target.Root.Position.X, pivot.Position.Y, target.Root.Position.Z)
				if (flat - pivot.Position).Magnitude > 0.5 then
					turret.Model:PivotTo(CFrame.lookAt(pivot.Position, flat))
				end
				ctx.Combat:Damage(target.Id, tt.Damage, playerCombatId(player), "turret")
				turret.Shots += 1
				local shocks = turret.Shock and turret.Shots % math.max(tt.ShockEvery, 1) == 0
				if shocks and target.Model.Parent then
					stun(target.Model, tt.ShockSeconds)
				end
				Remotes.FireAllClients("AbilityFx", player.UserId, "Engineer", if shocks then "ShockTracer" else "Tracer",
					muzzle, { To = target.Root.Position })
			else
				turret.NextShot = os.clock() + 0.2
			end
		end
	end
end

local function barricadeGraybox(): Model
	local model = Instance.new("Model")
	model.Name = "Barricade"
	for i = 0, 2 do
		local plank = makePart(`Plank{i + 1}`, Vector3.new(5.2, 0.7, 0.25), Color3.fromRGB(122, 92, 60), Enum.Material.WoodPlanks)
		plank.CFrame = CFrame.new(0, (i - 1) * 0.9, 0) * CFrame.Angles(0, 0, math.rad((i - 1) * 6))
		plank.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("Plank2") :: BasePart
	return model
end

local function barricadeCost(player: Player?): { [string]: number }
	local recipe = Config.Get("Recipes", "Barricade")
	local m = if player then Modifiers.PlayerValue(player, "BarricadeCost") or 1 else 1
	local costs = {}
	for id, amount in recipe.Costs do
		costs[id] = math.max(1, math.ceil(amount * m - 1e-6))
	end
	return costs
end

local function costText(costs: { [string]: number }): string
	local parts = {}
	for _, id in Config.Ids("Resources") do
		if costs[id] then
			table.insert(parts, `{costs[id]} {Config.Get("Resources", id).Name}`)
		end
	end
	return table.concat(parts, ", ")
end

local function placeBarricade(roomId: string, at: Vector3)
	local model = ctx.Grid:RoomModel(roomId)
	if not model then
		return
	end
	local old = model:FindFirstChild("Barricade")
	if old then
		old:Destroy()
	end
	local barricade = device("Props", "Prop_Barricade", barricadeGraybox)
	barricade.Name = "Barricade"
	barricade:PivotTo(CFrame.new(at + Vector3.new(0, 0, 0.6)) * CFrame.Angles(0, math.pi, 0)) -- art faces -Z: turn it to the room
	barricade.Parent = model
	model:SetAttribute("Barricaded", true)
end

-- Barricade prompts at every vent that has none yet (Engineers only), and barricades put back on
-- rooms whose models were rebuilt.
function Abilities.SyncBarricades()
	local seen: { [string]: boolean } = {}
	local folder = holder("ClassDevices")
	for _, point in ctx.Breaches:Points() do
		if point.Kind == "Vent" and point.RoomId then
			local roomId = point.RoomId :: string
			seen[roomId] = true
			local model = ctx.Grid:RoomModel(roomId)
			if barricaded[roomId] then
				if model and not model:GetAttribute("Barricaded") then
					placeBarricade(roomId, point.Source)
				end
				local spot = barricadeSpots[roomId]
				if spot then
					spot:Destroy()
					barricadeSpots[roomId] = nil
				end
			elseif not barricadeSpots[roomId] then
				local recipe = Config.Get("Recipes", "Barricade")
				local spot = makePart(`BarricadeSpot_{roomId}`, Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
				spot.Transparency = 1
				spot.Position = point.Source + Vector3.new(0, -3, 2)
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "BarricadePrompt"
				prompt.ActionText = "Barricade"
				prompt.ObjectText = `Vent · {costText(barricadeCost(nil))}`
				prompt.HoldDuration = recipe.Seconds
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
				prompt.Style = Enum.ProximityPromptStyle.Custom
				prompt:SetAttribute("Kind", "Barricade")
				prompt:SetAttribute("ForClass", "Engineer")
				prompt.Triggered:Connect(function(player: Player)
					local state = ctx.State(player)
					if not state or state.Class ~= "Engineer" or not standing(player) or barricaded[roomId] then
						return
					end
					local costs = barricadeCost(player)
					local paid, why = ctx.Economy:Spend(costs, "Barricade")
					if not paid then
						Remotes.FireClient("Alert", player, "Warning", `CAN'T BARRICADE: {string.upper(why or "not enough in the stockpile")}`)
						return
					end
					barricaded[roomId] = true
					local vent = point.Source
					for _, p in ctx.Breaches:Points() do
						if p.RoomId == roomId and p.Kind == "Vent" then
							vent = p.Source
						end
					end
					placeBarricade(roomId, vent)
					spot:Destroy()
					barricadeSpots[roomId] = nil
					local room = ctx.Grid:Room(roomId)
					local name = if room then string.upper(Config.Get("Rooms", room.Type).Name) else "THE ROOM"
					for _, p in ctx.Session:ReadyPlayers() do
						Remotes.FireClient("Alert", p, "Info", `{string.upper(player.DisplayName)} BARRICADED THE {name} VENT ({costText(costs)})`)
					end
					log:Info("%s barricaded %s's vent", player.Name, roomId)
				end)
				prompt.Parent = spot
				spot.Parent = folder
				barricadeSpots[roomId] = spot
			end
		end
	end
	for roomId, spot in barricadeSpots do
		if not seen[roomId] then
			spot:Destroy()
			barricadeSpots[roomId] = nil
		end
	end
	for roomId in barricaded do
		if not ctx.Grid:Room(roomId) then
			barricaded[roomId] = nil
		end
	end
end

function Abilities.Barricaded(): { [string]: boolean }
	return table.clone(barricaded)
end

-- Medic ------------------------------------------------------------------------------------------------

local function triagePulse(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local tt = t()
	local clears = Modifiers.PlayerValue(player, "TriagePulseClears") ~= nil
	local healed, cleared = 0, 0
	for _, c in ctx.Combat:All("Survivors") do
		if c.State == "Alive" and (c.Root.Position - root.Position).Magnitude <= tt.TriageRadius then
			if c.Kind == "Player" or c.Kind == "Survivor" then
				if ctx.Combat:Heal(c.Id, tt.TriageHeal) > 0 then
					healed += 1
				end
				if clears and c.Player then
					local p = c.Player :: Player
					if (ctx.Surface:Radiation(p) or 0) > 0 then
						ctx.Surface:AddRadiation(p, -1e6, "Triage Pulse")
						cleared += 1
					end
					if p:GetAttribute("SlowedUntil") then
						p:SetAttribute("SlowedUntil", nil)
						cleared += 1
					end
				end
			elseif c.Kind == "Resident" and c.ResidentId then
				if ctx.Residents:Heal(c.ResidentId, tt.TriageHeal) > 0 then
					healed += 1
				end
			end
		end
	end
	if healed == 0 and cleared == 0 then
		return false, "NOBODY NEARBY NEEDS HEALING"
	end
	fx(player, "Pulse", root.Position, { Radius = tt.TriageRadius })
	return true, `TRIAGE PULSE: {healed} HEALED{if cleared > 0 then ` · {cleared} CLEARED` else ""}`
end

local function tickTouchHeal(dt: number)
	local tt = t()
	for _, player in ctx.Session:ReadyPlayers() do
		if Modifiers.PlayerValue(player, "TouchHeal") and standing(player) then
			local root = rootOf(player) :: BasePart
			for _, c in ctx.Combat:All("Survivors") do
				if c.Kind == "Resident" and c.ResidentId and c.State == "Alive"
					and (c.Root.Position - root.Position).Magnitude <= tt.TouchHealRange then
					ctx.Residents:Heal(c.ResidentId, tt.TouchHealPerSecond * dt)
				end
			end
		end
	end
end

-- Firefighter ------------------------------------------------------------------------------------------

local function foamBurst(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local room = roomAt(root.Position)
	local target = if room and Hazards.Fire(room.Id) then room else nil
	if not target then
		local best = t().FoamRange
		for _, entry in ctx.Disasters:Active() do
			if entry.Kind == "Fire" and entry.Room then
				local r = ctx.Grid:Room(entry.Room)
				local d = if r then (roomCentre(r) - root.Position).Magnitude else math.huge
				if r and d <= best then
					target, best = r, d
				end
			end
		end
	end
	if not target then
		return false, "NO FIRE NEARBY"
	end
	ctx.Disasters:Extinguish(target.Id, 1e6, "Foam Burst", player)
	fx(player, "Foam", roomCentre(target), { Radius = 14 })
	return true, `FOAM BURST: THE {string.upper(Config.Get("Rooms", target.Type).Name)} FIRE IS OUT`
end

-- Cook ----------------------------------------------------------------------------------------------------

local meal: { Until: number, Source: string }? = nil

-- The team's max health multiplier from a Hearty Meal in effect (ClassService's max health).
function Abilities.MealMultiplier(): number
	local m = meal
	if not m or os.clock() >= m.Until then
		return 1
	end
	local cook = Config.Get("Classes", "Cook").Ability
	return Modifiers.Fold(cook.Modifiers, "MaxHealthMult") or 1
end

local function endMeal()
	meal = nil
	ctx.Weapons:SetModifier("HeartyMeal", "StaminaMult", nil)
	for _, p in Players:GetPlayers() do
		ctx.Combat:RefreshMaxHealth(p)
		p:SetAttribute("MealUntil", nil)
	end
end

local function heartyMeal(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local ability = Config.Get("Classes", "Cook").Ability
	local seconds = Config.Get("Tuning", "Clock").CycleSeconds / math.max(ctx.Clock:TimeScale(), 0.01)
	meal = { Until = os.clock() + seconds, Source = player.Name }
	ctx.Weapons:SetModifier("HeartyMeal", "StaminaMult", Modifiers.Fold(ability.Modifiers, "StaminaMult"))
	local morale = Modifiers.Fold(ability.Modifiers, "MoraleNow") or 0
	if morale > 0 then
		ctx.Residents:AddMorale(morale, "Hearty Meal")
	end
	local heals = Modifiers.PlayerValue(player, "MealsHeal") ~= nil
	local fraction = t().MealHealFraction
	for _, p in ctx.Session:ReadyPlayers() do
		ctx.Combat:RefreshMaxHealth(p)
		p:SetAttribute("MealUntil", now() + seconds)
		local c = ctx.Combat:PlayerCombatant(p)
		if heals and c then
			local _, max = ctx.Combat:HealthOf(c.Id)
			ctx.Combat:Heal(c.Id, max * fraction)
		end
	end
	if heals then
		for _, resident in ctx.Residents:All() do
			if resident.State == "Alive" then
				ctx.Residents:Heal(resident.Id, resident.MaxHealth * fraction)
			end
		end
	end
	local root = rootOf(player)
	fx(player, "Meal", if root then root.Position else nil, {})
	for _, p in ctx.Session:ReadyPlayers() do
		Remotes.FireClient("Alert", p, "Info", `HEARTY MEAL: +20% HEALTH AND STAMINA FOR A CYCLE{if heals then " · ALL HEALED" else ""}`)
	end
	log:Info("%s served a Hearty Meal%s", player.Name, if heals then " (heals)" else "")
	task.delay(seconds, function()
		local m = meal
		if m and os.clock() >= m.Until - 0.05 then
			endMeal()
		end
	end)
	return true, nil
end

-- The Cook's Kitchen bonus (Presence) follows them into whichever Kitchen they stand in.
local presence: { [Player]: string } = {} -- player -> the room id holding their bonus
local function tickPresence()
	for player, roomId in table.clone(presence) do
		if player.Parent ~= Players then
			ctx.Economy:SetModifier(`presence:{player.UserId}`, "RoomOutput", nil, roomId)
			presence[player] = nil
		end
	end
	for _, player in ctx.Session:ReadyPlayers() do
		local list = {}
		local class = player:GetAttribute("Class")
		local level = player:GetAttribute("ClassLevel")
		for _, modifier in Modifiers.ClassModifiers(if type(class) == "string" then class else nil, if type(level) == "number" then level else nil) do
			if modifier.Scope == "Presence" and modifier.Key == "RoomOutput" then
				table.insert(list, modifier)
			end
		end
		local root = rootOf(player)
		local room = if root and standing(player) then roomAt(root.Position) else nil
		local wanted: string? = nil
		local value: number? = nil
		for _, modifier in list do
			if room and modifier.Room == room.Type then
				wanted, value = room.Id, modifier.Value
			end
		end
		local had = presence[player]
		if had ~= wanted then
			if had then
				ctx.Economy:SetModifier(`presence:{player.UserId}`, "RoomOutput", nil, had)
			end
			if wanted and value then
				ctx.Economy:SetModifier(`presence:{player.UserId}`, "RoomOutput", value, wanted)
			end
			presence[player] = wanted
		end
	end
end

-- Security -----------------------------------------------------------------------------------------------

local function holdTheLine(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local seconds = Classes.Duration(state.Class, state.Level)
	local drawn = ctx.Monsters:Taunt(playerCombatId(player), root.Position, t().TauntRadius, seconds)
	local character = player.Character
	if character then
		local glow = Instance.new("Highlight")
		glow.Name = "HoldTheLine"
		glow.FillColor = Color3.fromRGB(80, 160, 230)
		glow.FillTransparency = 0.75
		glow.OutlineColor = Color3.fromRGB(150, 210, 255)
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = character
		Debris:AddItem(glow, seconds)
	end
	fx(player, "Shield", root.Position, { Radius = t().TauntRadius })
	return true, if drawn > 0 then `HOLD THE LINE: {drawn} MONSTER{if drawn == 1 then "" else "S"} DRAWN TO YOU` else "HOLD THE LINE",
		"Hold", seconds
end

-- Scout ----------------------------------------------------------------------------------------------------

local LOOT_FINDS: { [string]: boolean } = { Cache = true, OreVein = true, GlowshardChest = true, RadioLog = true }

local function outline(model: Model, colour: Color3, seconds: number)
	local old = model:FindFirstChild("FlarePing")
	if old then
		old:Destroy()
	end
	local glow = Instance.new("Highlight")
	glow.Name = "FlarePing"
	glow.FillColor = colour
	glow.FillTransparency = 0.8
	glow.OutlineColor = colour
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Adornee = model
	glow.Parent = model
	Debris:AddItem(glow, seconds)
end

local function flarePing(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local radius = t().FlareRadius
	local seconds = Classes.Duration(state.Class, state.Level)
	local enemies, loot, survivors = 0, 0, 0
	for _, c in ctx.Combat:All("Monsters") do
		if c.State == "Alive" and (c.Root.Position - root.Position).Magnitude <= radius then
			outline(c.Model, Color3.fromRGB(232, 70, 50), seconds)
			enemies += 1
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Monsters") or workspace.Terrain }
	params.MaxParts = 4000
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInRadius(root.Position, radius, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not seen[model] do
			local isLoot = (model:GetAttribute("Container") ~= nil and not model:GetAttribute("Looted") and not model:GetAttribute("Locked"))
				or LOOT_FINDS[model:GetAttribute("Find") or ""] or model:GetAttribute("Feature") == "Cache"
				or model:GetAttribute("BigFind") ~= nil or model:GetAttribute("Bag") ~= nil
			local isSurvivor = model:GetAttribute("RescueId") ~= nil
			if isLoot or isSurvivor then
				seen[model] = true
				if isSurvivor then
					outline(model, Color3.fromRGB(110, 210, 120), seconds)
					survivors += 1
				else
					outline(model, Color3.fromRGB(240, 180, 60), seconds)
					loot += 1
				end
				break
			end
			model = model:FindFirstAncestorOfClass("Model")
		end
	end
	fx(player, "Flare", root.Position, { Radius = radius })
	if enemies + loot + survivors == 0 then
		return true, `FLARE PING: NOTHING WITHIN {radius} STUDS`
	end
	return true, `FLARE PING: {enemies} ENEMIES · {loot} LOOT · {survivors} SURVIVOR{if survivors == 1 then "" else "S"}`
end

-- Quartermaster -------------------------------------------------------------------------------------------

local function requisition(state: State, option: number): (boolean, string?, string?, number?)
	local tt = t()
	local name = Classes.OptionName(state.Class, option) or "Scrap"
	local given: { string } = {}
	if name == "Scrap" then
		local added = ctx.Economy:Add("Scrap", tt.RequisitionScrap, "Emergency Requisition")
		if added > 0 then
			table.insert(given, `+{added} SCRAP`)
		end
	else
		for _, id in { "Food", "Water" } do
			local added = ctx.Economy:Add(id, tt.RequisitionFoodWater, "Emergency Requisition")
			if added > 0 then
				table.insert(given, `+{added} {string.upper(id)}`)
			end
		end
	end
	if #given == 0 then
		return false, "THE STOCKPILE IS FULL"
	end
	local text = `{string.upper(state.Player.DisplayName)}'S EMERGENCY REQUISITION: {table.concat(given, ", ")}`
	for _, p in ctx.Session:ReadyPlayers() do
		Remotes.FireClient("Alert", p, "Info", text)
	end
	return true, nil
end

-- Radio Operator -------------------------------------------------------------------------------------------

local function crateGraybox(): Model
	local model = Instance.new("Model")
	model.Name = "SupplyCrate"
	local box = makePart("Box", Vector3.new(3, 2, 2), Color3.fromRGB(86, 104, 70), Enum.Material.WoodPlanks)
	box.CFrame = CFrame.new(0, 1, 0)
	box.Parent = model
	model.PrimaryPart = box
	return model
end

local function supplyCall(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local tt = t()
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local at = ground(root.Position + flat.Unit * tt.CrateDistance)
	local model = device("Props", "Prop_SupplyCrate", crateGraybox)
	crates += 1
	model.Name = `SupplyCall_{crates}`
	model:PivotTo(CFrame.lookAt(at, at - flat))
	local _, size = model:GetBoundingBox()
	local spot = makePart("PromptSpot", Vector3.new(1, 1, 1), Color3.new(1, 1, 1))
	spot.Transparency = 1
	spot.Position = at + Vector3.new(0, size.Y + 0.5, 0)
	spot.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Supply crate"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "OpenCrate")
	local left: { Loot.Drop } = Loot.Roll(tt.CrateLoot, rng, {})
	local opened = false
	prompt.Triggered:Connect(function(opener: Player)
		if opened or not standing(opener) then
			return
		end
		local inBunker = Surface.Zone(at) == "Bunker"
		local given: { Loot.Drop } = {}
		local rest: { Loot.Drop } = {}
		if inBunker then
			for _, drop in left do
				if drop.Resource then
					local added = ctx.Economy:Add(drop.Resource, drop.Count, "Supply Call")
					if added > 0 then
						table.insert(given, { Resource = drop.Resource, Count = added })
					end
				end
			end
		else
			given, rest = ctx.Inventory:Give(opener, left)
		end
		if #rest > 0 then
			left = rest
			prompt.ActionText = "Take the rest"
			Remotes.FireClient("Alert", opener, "Warning", `PACK FULL: {Loot.Text(rest)} LEFT IN THE CRATE`)
		else
			opened = true
			model:Destroy()
		end
		if #given > 0 then
			for _, p in ctx.Session:ReadyPlayers() do
				Remotes.FireClient("Alert", p, "Info", `{string.upper(opener.DisplayName)} OPENED THE SUPPLY CRATE: {Loot.Text(given)}`)
			end
		end
	end)
	prompt.Parent = spot
	model.Parent = holder("ClassDevices")
	fx(player, "Crate", at, {})
	return true, "SUPPLY CALL: A CRATE LANDED IN FRONT OF YOU"
end

-- Hazmat Tech ---------------------------------------------------------------------------------------------

local function deconField(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local unit = unitAt(root.Position)
	local radius = t().DeconRadius
	local cleared = 0
	for _, p in ctx.Session:ReadyPlayers() do
		local other = rootOf(p)
		if other and standing(p) then
			local inside = if unit then unitAt(other.Position) == unit else (other.Position - root.Position).Magnitude <= radius
			if inside and (ctx.Surface:Radiation(p) or 0) > 0 then
				ctx.Surface:AddRadiation(p, -1e6, "Decon Field")
				cleared += 1
			end
		end
	end
	if cleared == 0 then
		return false, "NOBODY HERE NEEDS DECONTAMINATING"
	end
	fx(player, "Decon", root.Position, { Radius = if unit then 14 else radius })
	return true, `DECON FIELD: RADIATION CLEARED FROM {cleared} PLAYER{if cleared == 1 then "" else "S"}`
end

-- Exterminator ---------------------------------------------------------------------------------------------

local function napalmLine(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local n = t().Napalm
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	local start = ground(root.Position)
	local centre = start + flat * (n.Length / 2 + 1.5)
	local cframe = CFrame.lookAt(centre, centre + flat)
	local seconds = Classes.Duration(state.Class, state.Level)
	local part = makePart("NapalmLine", Vector3.new(n.Width, 0.3, n.Length), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	part.Transparency = 0.35
	part.CFrame = cframe + Vector3.new(0, 0.15, 0)
	for i = 1, 3 do
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(0, 0.2, (i - 2) * n.Length / 3)
		a.Parent = part
		local flame = Instance.new("Fire")
		flame.Size = 6
		flame.Heat = 9
		flame.Parent = a
	end
	part.Parent = holder("ClassDevices")
	Debris:AddItem(part, seconds)
	table.insert(strips, { Owner = player, Part = part, CFrame = cframe, Size = part.Size, Until = os.clock() + seconds })
	return true, "NAPALM LINE"
end

local function tickStrips(dt: number)
	local n = t().Napalm
	for i = #strips, 1, -1 do
		local strip = strips[i]
		if os.clock() >= strip.Until or not strip.Part.Parent then
			table.remove(strips, i)
		else
			for _, c in ctx.Combat:All("Monsters") do
				if c.State == "Alive" then
					local localPoint = strip.CFrame:PointToObjectSpace(c.Root.Position)
					if math.abs(localPoint.X) <= strip.Size.X / 2 + c.Reach * 0.5 and math.abs(localPoint.Z) <= strip.Size.Z / 2 + c.Reach * 0.5
						and math.abs(localPoint.Y) <= 8 then
						ctx.Combat:Damage(c.Id, n.DamagePerSecond * dt, playerCombatId(strip.Owner), "burned")
						Abilities.Burn(c.Id, strip.Owner)
					end
				end
			end
		end
	end
end

-- Marksman ----------------------------------------------------------------------------------------------------

local function steadyShot(state: State): (boolean, string?, string?, number?)
	state.Shots = t().SteadyShots
	state.Player:SetAttribute("SteadyShots", state.Shots)
	return true, `STEADY SHOT: THE NEXT {state.Shots} SHOTS PIERCE AND CRIT`
end

-- WeaponService's shot hook: a Steady Shot pierces and crits.
function Abilities.ShotHook(player: Player, _itemId: string): any
	local state = ctx.State(player)
	if not state or state.Shots <= 0 then
		return nil
	end
	state.Shots -= 1
	player:SetAttribute("SteadyShots", if state.Shots > 0 then state.Shots else nil)
	return { Pierce = true, Crit = t().CritMultiplier }
end

-- Driller --------------------------------------------------------------------------------------------------------

local function overdrive(state: State, _origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	if not Dig.CanDigWith(ctx.Weapons:Items(player)) then
		return false, "YOU NEED A DRILL OR A PICKAXE"
	end
	local floor, column = Grid.CellAt(root.Position)
	if not floor or not column then
		return false, "OVERDRIVE WORKS IN THE BUNKER'S ROCK"
	end
	local df, dc = 0, 0
	if look.Y < -0.55 then
		df = 1
	elseif look.X >= 0 then
		dc = 1
	else
		dc = -1
	end
	local limit = RunState.Get("DigLimit")
	local dug = 0
	local why: string? = nil
	for i = 1, t().OverdriveCells do
		local f, c = floor + df * i, column + dc * i
		local cellState = if Grid.OnGrid(f, c) then ctx.Grid:State(f, c) else nil
		if cellState ~= "Rock" then
			why = if dug == 0 then "NO ROCK TO DIG THAT WAY" else nil
			break
		end
		if type(limit) == "number" and f > limit then
			why = if dug == 0 then "PAST THE DIG LIMIT: PUSH DEEPER FIRST" else "THE REST IS PAST THE DIG LIMIT"
			break
		end
		local ok, reason = ctx.Dig:DigNow(f, c, "Overdrive", player)
		if not ok then
			why = if dug == 0 then string.upper(reason or "IT WON'T DIG") else nil
			break
		end
		dug += 1
	end
	if dug == 0 then
		return false, why or "NO ROCK TO DIG THAT WAY"
	end
	fx(player, "Overdrive", root.Position, {})
	return true, `OVERDRIVE: {dug} CELL{if dug == 1 then "" else "S"} DUG{if why then ` · {why}` else ""}`
end

-- Scavenger --------------------------------------------------------------------------------------------------------

local function magnetSweep(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local radius = t().MagnetRadius
	local reached = ctx.Surface:SearchNear(player, root.Position, radius)
		+ ctx.Deep:OpenNear(player, root.Position, radius)
		+ ctx.Inventory:CollectBags(player, root.Position, radius)
	if reached == 0 then
		return false, `NO LOOT WITHIN {radius} STUDS`
	end
	fx(player, "Magnet", root.Position, { Radius = radius })
	return true, nil
end

-- Warden ----------------------------------------------------------------------------------------------------------------

local function rallyCall(state: State): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root or not unitAt(root.Position) then
		return false, "RALLY CALL WORKS IN THE BUNKER"
	end
	local myFloor = Grid.CellAt(root.Position)
	local tt = t()
	local ids = {}
	for _, resident in ctx.Residents:All() do
		local body = ctx.Brain:Body(resident.Id)
		if resident.State == "Alive" and Residents.Armed(resident) and body then
			local floor = Grid.CellAt(body:GetPivot().Position)
			if floor and myFloor and math.abs(floor - myFloor) <= tt.RallyFloors then
				table.insert(ids, resident.Id)
			end
		end
	end
	if #ids == 0 then
		return false, `NO ARMED RESIDENTS WITHIN {tt.RallyFloors} FLOORS`
	end
	local seconds = Classes.Duration(state.Class, state.Level)
	local instant = Modifiers.PlayerValue(player, "InstantRally") ~= nil
	local answered = ctx.Brain:Rally(ids, player, seconds, tt.RallyDamage, instant)
	fx(player, "Rally", root.Position, { Radius = 12 })
	return true, `RALLY CALL: {answered} ARMED RESIDENT{if answered == 1 then "" else "S"} ON THEIR WAY`, "Rally", seconds
end

-- Demolitionist ----------------------------------------------------------------------------------------------------------

local function breachingCharge(state: State, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local b = t().Breaching
	local hit = aim(player, origin, look, b.Range)
	local at = if hit then hit.Position else root.Position + Vector3.new(look.X, 0, look.Z).Unit * 6
	ctx.Weapons:Explode(player, at, b.Radius, b.Damage)
	-- a rock cell where it went off is cleared (not past the dig limit)
	local cleared = false
	if hit then
		local floor, column = Grid.CellAt(hit.Position - hit.Normal * 1.5)
		local limit = RunState.Get("DigLimit")
		if floor and column and ctx.Grid:State(floor, column) == "Rock" and (type(limit) ~= "number" or floor <= limit) then
			cleared = ctx.Dig:DigNow(floor, column, "Breaching Charge", player)
		end
	end
	return true, if cleared then "BREACHING CHARGE: THE ROCK CELL IS CLEARED" else "BREACHING CHARGE"
end

-- Spelunker ----------------------------------------------------------------------------------------------------------

local function grappleLine(state: State, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local player = state.Player
	local root = rootOf(player)
	if not root then
		return false, "YOU NEED TO BE STANDING"
	end
	local g = t().Grapple
	local hit = aim(player, origin, look, g.Range, true)
	if not hit then
		return false, `NOTHING TO GRAPPLE WITHIN {g.Range} STUDS`
	end
	local hitModel = hit.Instance:FindFirstAncestorOfClass("Model")
	local other = if hitModel then Players:GetPlayerFromCharacter(hitModel) else nil
	if other and other ~= player then
		if not standing(other) then
			return false, "THEY CAN'T BE PULLED NOW"
		end
		local to = root.Position + root.CFrame.LookVector * 3
		Remotes.FireClient("Grapple", other, to, g.Speed, player.UserId)
		fx(player, "Rope", root.Position, { To = (rootOf(other) :: BasePart).Position })
		return true, `GRAPPLE LINE: PULLING {string.upper(other.DisplayName)}`
	end
	local to = hit.Position + hit.Normal * 2.5 + Vector3.new(0, 1.5, 0)
	Remotes.FireClient("Grapple", player, to, g.Speed, player.UserId)
	fx(player, "Rope", root.Position, { To = hit.Position })
	return true, nil
end

-- Mad Scientist ----------------------------------------------------------------------------------------------------------

local function gadgetSpot(player: Player, origin: Vector3, look: Vector3): Vector3?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local hit = aim(player, origin, look, t().AimRange)
	local at = if hit then hit.Position else root.Position + Vector3.new(look.X, 0, look.Z).Unit * 8
	return ground(at)
end

local function shockTrap(state: State, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local at = gadgetSpot(state.Player, origin, look)
	if not at then
		return false, "YOU NEED TO BE STANDING"
	end
	local tr = t().Trap
	local part = makePart("ShockTrap", Vector3.new(2.4, 0.3, 2.4), Color3.fromRGB(230, 190, 50), Enum.Material.Neon)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, 2.4, 2.4)
	part.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(140, 200, 255)
	light.Range = tr.Radius
	light.Brightness = 1.5
	light.Parent = part
	part.Parent = holder("ClassDevices")
	table.insert(traps, { Owner = state.Player, Part = part, At = at, Until = os.clock() + tr.Seconds })
	return true, "SHOCK TRAP SET"
end

local function tickTraps()
	local tr = t().Trap
	for i = #traps, 1, -1 do
		local trap = traps[i]
		local sprung = false
		if os.clock() < trap.Until and trap.Part.Parent then
			for _, c in ctx.Combat:All("Monsters") do
				if c.State == "Alive" and (c.Root.Position - trap.At).Magnitude - c.Reach <= tr.Radius then
					stun(c.Model, tr.StunSeconds)
					ctx.Combat:Damage(c.Id, 10, playerCombatId(trap.Owner), "shocked")
					sprung = true
				end
			end
		end
		if sprung or os.clock() >= trap.Until or not trap.Part.Parent then
			if sprung then
				Remotes.FireAllClients("AbilityFx", trap.Owner.UserId, "MadScientist", "Zap", trap.At, { Radius = tr.Radius })
			end
			trap.Part:Destroy()
			table.remove(traps, i)
		end
	end
end

local function teleportBeacon(state: State, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local at = gadgetSpot(state.Player, origin, look)
	if not at then
		return false, "YOU NEED TO BE STANDING"
	end
	local old = beacon
	if old then
		old.Part:Destroy()
	end
	local seconds = t().BeaconSeconds
	local part = makePart("TeleportBeacon", Vector3.new(1, 5, 1), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	part.Transparency = 0.2
	part.CFrame = CFrame.new(at + Vector3.new(0, 2.5, 0))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 220, 255)
	light.Range = 16
	light.Brightness = 2
	light.Parent = part
	part.Parent = holder("ClassDevices")
	local untilAt = os.clock() + seconds
	beacon = { Part = part, Until = untilAt, By = state.Player }
	ctx.SetBeacon(now() + seconds, state.Player.DisplayName)
	task.delay(seconds, function()
		local b = beacon
		if b and b.Until == untilAt then
			b.Part:Destroy()
			beacon = nil
			ctx.SetBeacon(nil, nil)
		end
	end)
	for _, p in ctx.Session:ReadyPlayers() do
		if p ~= state.Player then
			Remotes.FireClient("Alert", p, "Info", `{string.upper(state.Player.DisplayName)} PLACED A TELEPORT BEACON: T TO TELEPORT`)
		end
	end
	return true, `TELEPORT BEACON SET FOR {math.floor(seconds)} S`
end

-- A teammate's TeleportToBeacon.
function Abilities.Teleport(player: Player): (boolean, string?)
	local b = beacon
	if not b or os.clock() >= b.Until or not b.Part.Parent then
		return false, "THERE'S NO TELEPORT BEACON"
	end
	if not standing(player) then
		return false, "YOU NEED TO BE STANDING"
	end
	if ctx.Inventory:Carrying(player) then
		return false, "PUT DOWN WHAT YOU'RE CARRYING FIRST"
	end
	local character = player.Character :: Model
	local angle = rng:NextNumber() * math.pi * 2
	local at = b.Part.Position + Vector3.new(math.cos(angle) * 3, 1, math.sin(angle) * 3)
	character:PivotTo(CFrame.new(at))
	fx(player, "Teleport", at, {})
	return true, nil
end

local function gravityWell(state: State, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local at = gadgetSpot(state.Player, origin, look)
	if not at then
		return false, "YOU NEED TO BE STANDING"
	end
	local g = t().GravityWell
	local part = makePart("GravityWell", Vector3.new(2, 2, 2), Color3.fromRGB(150, 90, 230), Enum.Material.ForceField)
	part.Shape = Enum.PartType.Ball
	part.CFrame = CFrame.new(at + Vector3.new(0, 2, 0))
	part.Parent = holder("ClassDevices")
	Debris:AddItem(part, g.Seconds)
	table.insert(wells, { Owner = state.Player, Part = part, At = at + Vector3.new(0, 2, 0), Until = os.clock() + g.Seconds })
	fx(state.Player, "Well", at, { Radius = g.Radius })
	return true, "GRAVITY WELL"
end

local function tickWells()
	local g = t().GravityWell
	for i = #wells, 1, -1 do
		local well = wells[i]
		if os.clock() >= well.Until or not well.Part.Parent then
			table.remove(wells, i)
		else
			for _, c in ctx.Combat:All("Monsters") do
				local offset = well.At - c.Root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if c.State == "Alive" and offset.Magnitude - c.Reach <= g.Radius and not ctx.Boss:IsBoss(c.Id) then
					stun(c.Model, 0.35)
					if flat.Magnitude > 1.5 and not c.Root.Anchored then
						c.Root.AssemblyLinearVelocity = flat.Unit * g.Pull + Vector3.new(0, c.Root.AssemblyLinearVelocity.Y, 0)
					end
				end
			end
		end
	end
end

local GADGETS: { [string]: (State, Vector3, Vector3) -> (boolean, string?, string?, number?) } = {
	["Shock Trap"] = shockTrap,
	["Teleport Beacon"] = teleportBeacon,
	["Gravity Well"] = gravityWell,
}

-- Tinkerer --------------------------------------------------------------------------------------------------------

local function droneGraybox(): Model
	local model = Instance.new("Model")
	model.Name = "CombatDrone"
	local body = makePart("Body", Vector3.new(1.6, 0.6, 1.6), Color3.fromRGB(196, 150, 54), Enum.Material.Metal)
	body.Parent = model
	local eye = makePart("Eye", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	eye.Shape = Enum.PartType.Ball
	eye.CFrame = CFrame.new(0, -0.1, -0.8)
	eye.Parent = model
	model.PrimaryPart = body
	return model
end

local function removeDrone(player: Player)
	local drone = drones[player]
	drones[player] = nil
	if drone then
		local model = drone.Part:FindFirstAncestorOfClass("Model")
		if model then
			model:Destroy()
		else
			drone.Part:Destroy()
		end
	end
end

local function spawnDrone(player: Player)
	if drones[player] then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local model = device("Props", "Prop_CombatDrone", droneGraybox)
	model.Name = `Drone_{player.UserId}`
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Mode", "Escort")
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	-- one physics body, server-owned and moved by constraints, so every client sees it glide
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = part ~= primary
			if part ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	primary.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.3, 0.5)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DroneAttachment"
	attachment.Parent = primary
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = 4000
	align.Responsiveness = 18
	align.Parent = primary
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.MaxTorque = 4000
	turn.Responsiveness = 15
	turn.Parent = primary
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 0.8
	light.Color = Color3.fromRGB(120, 220, 255)
	light.Parent = primary
	local start = root.Position + Vector3.new(2.5, 4, 1.5)
	model:PivotTo(CFrame.new(start))
	align.Position = start
	model.Parent = holder("ClassDevices")
	pcall(function()
		primary:SetNetworkOwner(nil)
	end)
	drones[player] = { Owner = player, Part = primary, Align = align, Turn = turn, NextShot = 0, NextPickup = 0 }
end

local MODE_COLOURS: { [string]: Color3 } = {
	Escort = Color3.fromRGB(120, 220, 255),
	Guard = Color3.fromRGB(110, 170, 255),
	Assault = Color3.fromRGB(255, 110, 70),
	Repair = Color3.fromRGB(120, 230, 120),
}

local function tickDrones()
	local d = t().Drone
	for player, drone in drones do
		local state = ctx.State(player)
		local root = rootOf(player)
		if not state or state.Class ~= "Tinkerer" or player.Parent ~= Players or not drone.Part.Parent then
			removeDrone(player)
		elseif root then
			local mode = if state.Effect and os.clock() < state.EffectUntil then state.Effect else "Escort"
			local model = drone.Part:FindFirstAncestorOfClass("Model")
			if model and model:GetAttribute("Mode") ~= mode then
				model:SetAttribute("Mode", mode)
				local light = drone.Part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = MODE_COLOURS[mode] or MODE_COLOURS.Escort
				end
			end
			local side = root.CFrame.RightVector * 2.5 + root.CFrame.LookVector * (if mode == "Guard" then 2 else -1.5)
			local goal = root.Position + side + Vector3.new(0, 3.5 + math.sin(os.clock() * 2) * 0.3, 0)
			if (drone.Part.Position - goal).Magnitude > 40 then
				drone.Part.CFrame = CFrame.new(goal) -- left far behind (a teleport, the elevator): catch up
			end
			drone.Align.Position = goal
			local from = drone.Part.Position
			if mode == "Repair" then
				-- the nearest damaged room within RepairRange of you
				local best, bestDistance = nil, d.RepairRange
				for _, room in ctx.Grid:Rooms() do
					if room.HP < room.MaxHP then
						local dist = (roomCentre(room) - root.Position).Magnitude
						if dist <= bestDistance then
							best, bestDistance = room, dist
						end
					end
				end
				if best and os.clock() >= drone.NextShot then
					drone.NextShot = os.clock() + 0.5
					ctx.Build:Repair(best.Id, d.RepairPerSecond * 0.5, "Drone", player)
					Remotes.FireAllClients("AbilityFx", player.UserId, "Tinkerer", "RepairBeam", from, { To = roomCentre(best) })
				end
				drone.Turn.CFrame = CFrame.lookAt(from, from + root.CFrame.LookVector)
			else
				local target = nearestMonster(from, d.Range)
				if target then
					drone.Turn.CFrame = CFrame.lookAt(from, target.Root.Position)
					if os.clock() >= drone.NextShot then
						local guns = math.max(1, math.floor(Modifiers.PlayerValue(player, "DroneGuns") or 1))
						drone.NextShot = os.clock() + d.FireSeconds / guns
						local damage = d.Damage * (if mode == "Assault" then d.AssaultMultiplier else 1)
						ctx.Combat:Damage(target.Id, damage, playerCombatId(player), "drone")
						Remotes.FireAllClients("AbilityFx", player.UserId, "Tinkerer", "Tracer", from, { To = target.Root.Position })
					end
				else
					drone.Turn.CFrame = CFrame.lookAt(from, from + root.CFrame.LookVector)
				end
			end
			if os.clock() >= drone.NextPickup then
				drone.NextPickup = os.clock() + 1
				ctx.Inventory:CollectBags(player, root.Position, d.PickupRange)
			end
		end
	end
end

local function droneMode(state: State, option: number): (boolean, string?, string?, number?)
	if not drones[state.Player] then
		spawnDrone(state.Player)
	end
	local name = Classes.OptionName(state.Class, option) or "Guard"
	local seconds = Classes.Duration(state.Class, state.Level)
	return true, `DRONE MODE: {string.upper(name)} FOR {math.floor(seconds)} S`, name, seconds
end

-- The drone revives its owner once per Surge (the Tinkerer's level 3): ClassService calls this when
-- a player goes down.
function Abilities.Downed(player: Player)
	local state = ctx.State(player)
	if not state or state.Class ~= "Tinkerer" or state.DroneRevives <= 0 or not drones[player] then
		return
	end
	state.DroneRevives -= 1
	task.delay(t().Drone.ReviveSeconds, function()
		if player.Parent == Players and player:GetAttribute("Life") == "Downed" then
			local ok = ctx.Combat:Revive(player, nil)
			if ok then
				Remotes.FireClient("Alert", player, "Info", "YOUR DRONE REVIVED YOU")
				local drone = drones[player]
				if drone then
					Remotes.FireAllClients("AbilityFx", player.UserId, "Tinkerer", "RepairBeam", drone.Part.Position,
						{ To = (rootOf(player) or drone.Part).Position })
				end
			end
		end
	end)
end

-- Dispatch ---------------------------------------------------------------------------------------------------------

local HANDLERS: { [string]: (State, number, Vector3, Vector3) -> (boolean, string?, string?, number?) } = {
	Survivor = function(state)
		return secondWind(state)
	end,
	Engineer = function(state, _, origin, look)
		return deployTurret(state, origin, look)
	end,
	Medic = function(state)
		return triagePulse(state)
	end,
	Firefighter = function(state)
		return foamBurst(state)
	end,
	Cook = function(state)
		return heartyMeal(state)
	end,
	Security = function(state)
		return holdTheLine(state)
	end,
	Scout = function(state)
		return flarePing(state)
	end,
	Quartermaster = function(state, option)
		return requisition(state, option)
	end,
	RadioOperator = function(state)
		return supplyCall(state)
	end,
	HazmatTech = function(state)
		return deconField(state)
	end,
	Exterminator = function(state)
		return napalmLine(state)
	end,
	Marksman = function(state)
		return steadyShot(state)
	end,
	Driller = function(state, _, origin, look)
		return overdrive(state, origin, look)
	end,
	Scavenger = function(state)
		return magnetSweep(state)
	end,
	Warden = function(state)
		return rallyCall(state)
	end,
	Demolitionist = function(state, _, origin, look)
		return breachingCharge(state, origin, look)
	end,
	Spelunker = function(state, _, origin, look)
		return grappleLine(state, origin, look)
	end,
	MadScientist = function(state, option, origin, look)
		local fn = GADGETS[Classes.OptionName(state.Class, option) or ""]
		if not fn then
			return false, "NO SUCH GADGET"
		end
		return fn(state, origin, look)
	end,
	Tinkerer = function(state, option)
		return droneMode(state, option)
	end,
}

function Abilities.Has(classId: string): boolean
	return HANDLERS[classId] ~= nil
end

function Abilities.Use(state: State, option: number, origin: Vector3, look: Vector3): (boolean, string?, string?, number?)
	local handler = HANDLERS[state.Class]
	if not handler then
		return false, "THIS CLASS HAS NO ABILITY YET"
	end
	local ok, used, text, effect, seconds = pcall(handler, state, option, origin, look)
	if not ok then
		log:Warn("%s's %s failed: %s", state.Player.Name, state.Class, tostring(used))
		return false, "THAT DIDN'T WORK"
	end
	return used, text, effect, seconds
end

-- A player's class or level is now `state` (or they left: nil): devices that belong to a class.
function Abilities.ClassChanged(player: Player, state: State?)
	if not state or state.Class ~= "Tinkerer" then
		removeDrone(player)
	elseif standing(player) then
		spawnDrone(player)
	end
	if not state or state.Class ~= "Engineer" then
		removeTurret(player)
	end
	if not state then
		local had = presence[player]
		if had then
			ctx.Economy:SetModifier(`presence:{player.UserId}`, "RoomOutput", nil, had)
			presence[player] = nil
		end
	end
end

-- A respawned Tinkerer gets their drone back.
function Abilities.Spawned(player: Player)
	local state = ctx.State(player)
	if state and state.Class == "Tinkerer" then
		removeDrone(player)
		task.delay(0.5, spawnDrone, player)
	end
end

function Abilities.Tick(dt: number)
	for _, step in { tickTurrets, tickDrones, tickTraps, tickWells } do
		local ok, err = pcall(step :: any)
		if not ok then
			log:Warn("tick: %s", tostring(err))
		end
	end
	for _, step in { tickStrips, tickBurning } do
		local ok, err = pcall(step :: any, dt)
		if not ok then
			log:Warn("tick: %s", tostring(err))
		end
	end
end

-- Once a second: the Medic's touch and the Cook's Kitchen.
function Abilities.Slow(dt: number)
	local ok, err = pcall(tickTouchHeal, dt)
	if not ok then
		log:Warn("touch heal: %s", tostring(err))
	end
	ok, err = pcall(tickPresence)
	if not ok then
		log:Warn("presence: %s", tostring(err))
	end
end

function Abilities.Describe(): string
	local lines = {}
	for player, turret in turrets do
		table.insert(lines, string.format("turret: %s, %.0f s left", player.Name, turret.Until - os.clock()))
	end
	for player, drone in drones do
		local model = drone.Part:FindFirstAncestorOfClass("Model")
		table.insert(lines, `drone: {player.Name}, mode {if model then tostring(model:GetAttribute("Mode")) else "?"}`)
	end
	local burns = 0
	for _ in burning do
		burns += 1
	end
	table.insert(lines, `burning monsters {burns}; napalm strips {#strips}; traps {#traps}; wells {#wells}`)
	local b = beacon
	table.insert(lines, if b then string.format("beacon by %s, %.0f s left", b.By.Name, b.Until - os.clock()) else "no beacon")
	local count = 0
	for _ in barricaded do
		count += 1
	end
	table.insert(lines, `barricaded vents {count}; meal {if meal then "on" else "off"}`)
	return table.concat(lines, "\n")
end

function Abilities.Init(context: Context)
	ctx = context
end

return Abilities
