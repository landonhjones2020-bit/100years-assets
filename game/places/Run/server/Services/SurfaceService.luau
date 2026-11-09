--!strict
--[[
	SurfaceService: Brightwater Ruins, the surface above the bunker (bible Sections 9, 12 and 23;
	Run place, Prompt 16). Raids and wanderers (also the surface's, Section 23) come with Prompt 30.

	* The map is workspace.Surface, a static part of the Run place high above the bunker (Section 23:
	  the surface map high above, the bunker grid in the middle), built in Studio by
	  Lib.BrightwaterMap.Build() (Landon can dress it there). This service never rebuilds it: it reads
	  its markers (parts named ElevatorExit, ElevatorCall, SurvivorSpot, BigFindSpot, SpawnPoint),
	  its containers (models with Container and Location attributes) and its gates (models with a
	  MinEra attribute: the military checkpoint opens in Era III). Without a map the elevator says
	  so and nothing else changes.
	* Zones: every player carries a Zone attribute (Rules.Surface.Zone: Surface or Bunker);
	  ZoneChanged fires when it changes.
	* The elevator behind the Blast Door (Section 12): RIDE UP by the hall's door, RIDE DOWN at the
	  surface hut. The screen fades (the Elevator remote) and the server moves the character, the
	  survivors following them (RescueService) and anything in their hands.
	* Containers (Section 12; Config.SurfaceLocations): SEARCH rolls the location's loot table (the
	  Scavenger's ExtraLootRolls) into the searcher's backpack (InventoryService:Give); what doesn't
	  fit stays in the container (TAKE THE REST). Every era they refill; the checkpoint's are locked
	  until its MinEra.
	* Storms (Section 12): the storm is over the town for every Surge (RunState Storm, StormAt); the
	  siren's alert reaches players on the surface, and the Scout's StormWarningSeconds earlier.
	* Radiation (Section 9): the Player attribute Radiation, 0 to RadiationMax, builds on the surface
	  (RadiationPerSecond, StormRadiationPerSecond in a storm, times RadiationGain) and with each Ash
	  Wraith hit (Radiates); a working Decon Room clears it (Section 6). At PillUseAt a carried
	  Clear-Rad pill is taken by itself; at the max it drains health (RadiationHealthDrainPerSecond).
	  A new life (a respawn) starts clean.
	* Creatures (Section 12; Config.Monsters, Where Surface): while players are on the surface, packs
	  of Ash Jackals by day, Ash Raiders from RaiderMinEra and Ash Wraiths only in storms, at
	  SpawnPoint markers SpawnDistance from the players, at most MaxMonsters at once (within the
	  map's cap of 25); wraiths fade when the storm passes and everything fades DespawnSeconds after
	  the last player leaves. A creature that falls FALL_GUARD studs below the exit is removed.
	* Survivors and big finds (Section 12): at the start of each day a survivor may be trapped at a
	  SurvivorSpot (RescueService:Trap) and generator parts may turn up at a BigFindSpot
	  (InventoryService:PlaceFind).
	* The surface's Lost Crew (Section 12; Prompt 17): a raider camp (A6's Bldg_RaiderCamp) stands
	  at one of the map's CampSpots, picked each run, with the crew trapped in its pen (Kind Crew, Tag
	  CrewSurface: DeepService completes the objective when they come home). Its Ash Raiders guard
	  it from Era I: they come out at the camp's Guard sockets when a player comes within
	  Tuning.Deep.CampWakeRange, asleep at their posts until one comes within GuardRange
	  (MonsterService guards), and go back in after CampSleepSeconds with nobody near; the ones
	  killed stay dead. CrewWhere() says where the camp is for the radio logs.

	API: Zone(player), Storm(), Radiation(player), AddRadiation(player, amount, why), Map(), CrewWhere().
	Signals: ZoneChanged(player, zone), Searched(player, location, given).
	Dev: surface, surface.up [player], surface.down [player], rad <n>, storm <on|off>, loot.refill,
	surface.spawn <type> [n], survivor, surface.find.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local Surface = require(Shared.Rules.Surface)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("SurfaceService")

local SurfaceService = {
	Name = "SurfaceService",
	Dependencies = {
		"SessionService", "CycleClock", "RunDirector", "BunkerGrid", "PowerService", "CombatService", "MonsterService",
		"InventoryService", "RescueService", "DevService",
	},
	ZoneChanged = Signal.new() :: Signal.Signal<Player, string>,
	Searched = Signal.new() :: Signal.Signal<Player, string, { Loot.Drop }>,
}

-- loot nothing hands out yet (radio logs play through InventoryService's handler, Prompt 17)
local SKIP: { [string]: boolean } = { Gear = true, Blueprint = true, Recruit = true, Glowshards = true, Lamp = true }
local CAMP_TAG = "Camp"
local CREW_TAG = "CrewSurface" -- the surface's Lost Crew (Config.Objectives)
local SURFACE_TAG = "Surface"
local FALL_GUARD = 30 -- studs under the elevator exit: below this a surface creature has fallen out of the town
local HALL_ARRIVAL = Vector3.new(0, 0, 6) -- from the Blast Door's Door socket, into the hall
local ELEVATOR_PROMPT = Vector3.new(0, 2.5, 0.5)

type Container = {
	Model: Model,
	Location: string,
	Prompt: ProximityPrompt,
	Left: { Loot.Drop }?,
	Looted: boolean,
	Locked: boolean,
}
type Spot = { CFrame: CFrame, Location: string? }
type Camp = {
	Model: Model,
	CFrame: CFrame,
	Hint: string,
	Posts: { CFrame }, -- the Guard sockets in the world
	Guards: { [string]: boolean }, -- monster ids out now
	Left: number, -- guards not yet killed
	NearAt: number, -- os.clock a player was last near
}

local clock: any = nil
local director: any = nil
local grid: any = nil
local power: any = nil
local combat: any = nil
local monsterService: any = nil
local inventory: any = nil
local rescue: any = nil
local set: (string, any) -> () = function() end

local map: Instance? = nil
local exitAt: CFrame? = nil
local containers: { Container } = {}
local survivorSpots: { Spot } = {}
local findSpots: { Spot } = {}
local spawnPoints: { Vector3 } = {}
local gates: { Model } = {}
local campSpots: { { CFrame: CFrame, Hint: string } } = {}
local camp: Camp? = nil
local radiation: { [Player]: number } = {}
local warned: { [Player]: number } = {} -- 0 none, 1 high, 2 sickness
local earlyWarned: { [Player]: number } = {} -- the cycle a Scout heard the storm coming
local riding: { [Player]: boolean } = {}
local creatures: { [string]: string } = {} -- surface monster id -> type
local storm = false
local emptySince = 0
local nextAt: { [string]: number } = { AshJackal = 0, AshRaider = 0, AshWraith = 0 }
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

local function t(): { [string]: any }
	return Surface.Tuning()
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(player: Player): boolean
	return player:GetAttribute("Life") == "Alive"
end

local function classValue(player: Player, key: string): number?
	local class = player:GetAttribute("Class")
	return Modifiers.ClassValue(if type(class) == "string" then class else nil, key)
end

local function eraNumber(): number
	local era = Config.Find("Eras", clock:Era())
	return if era then era.Number else 1
end

local function locationName(id: string?): string
	local location = id and Config.Find("SurfaceLocations", id)
	return if location then location.Name else "the ruins"
end

local function locked(id: string?): boolean
	local location = id and Config.Find("SurfaceLocations", id)
	return location ~= nil and location.MinEra > eraNumber()
end

local function onSurface(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Zone") == "Surface" and alive(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function randomIn(range: { Min: number, Max: number }): number
	return rng:NextNumber(range.Min, math.max(range.Min, range.Max))
end

-- Zones -----------------------------------------------------------------------------------------

local function setZone(player: Player, zone: string)
	if player:GetAttribute("Zone") ~= zone then
		player:SetAttribute("Zone", zone)
		SurfaceService.ZoneChanged:Fire(player, zone)
	end
end

function SurfaceService:Zone(player: Player): string
	local zone = player:GetAttribute("Zone")
	return if type(zone) == "string" then zone else "Bunker"
end

function SurfaceService:Storm(): boolean
	return storm
end

function SurfaceService:Map(): Instance?
	return map
end

-- Radiation -------------------------------------------------------------------------------------

local function publishRadiation(player: Player, value: number)
	local shown = player:GetAttribute("Radiation")
	local rounded = math.floor(value * 10 + 0.5) / 10
	if type(shown) ~= "number" or math.abs(shown - rounded) >= 0.5 or (rounded == 0) ~= (shown == 0) then
		player:SetAttribute("Radiation", rounded)
	end
end

function SurfaceService:Radiation(player: Player): number
	return radiation[player] or 0
end

function SurfaceService:AddRadiation(player: Player, amount: number, why: string)
	local max = Config.Get("Tuning", "Player").RadiationMax
	radiation[player] = math.clamp((radiation[player] or 0) + amount, 0, max)
	publishRadiation(player, radiation[player])
	log:Debug("%s radiation %+.1f (%s) = %.1f", player.Name, amount, why, radiation[player])
end

local function inDecon(position: Vector3): boolean
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return false
	end
	local room = grid:RoomAt(floor, column)
	return room ~= nil and room.Type == "DeconRoom" and not room.Wrecked and not power:IsDark(room.Id)
end

local function radiationTick(player: Player, root: BasePart, dt: number)
	local tuning = t()
	local p = Config.Get("Tuning", "Player")
	local value = radiation[player] or 0
	if alive(player) then
		local zone = SurfaceService:Zone(player)
		value += Surface.RadiationRate(zone, storm, classValue(player, "RadiationGain")) * dt
		if zone == "Bunker" and value > 0 and inDecon(root.Position) then
			value -= tuning.DeconPerSecond * dt
		end
	end
	value = math.clamp(value, 0, p.RadiationMax)
	if value >= tuning.PillUseAt and inventory:TakePill(player) then
		value = 0
		alert(player, "Info", `YOU TOOK A CLEAR-RAD PILL: RADIATION CLEARED ({inventory:Pills(player)} LEFT)`)
	end
	radiation[player] = value
	publishRadiation(player, value)
	local level = if value >= p.RadiationMax then 2 elseif value >= p.RadiationMax * tuning.RadiationWarnAt then 1 else 0
	if level > (warned[player] or 0) then
		if level == 1 then
			alert(player, "Warning", "RADIATION HIGH: HEAD BACK TO THE ELEVATOR")
		else
			alert(player, "Danger", "RADIATION SICKNESS: YOU'RE LOSING HEALTH · CLEAR-RAD PILLS OR A DECON ROOM CLEAR IT")
		end
	end
	warned[player] = level
	if value >= p.RadiationMax and alive(player) then
		combat:Damage(`P{player.UserId}`, p.RadiationHealthDrainPerSecond * dt, nil, "radiation")
	end
end

-- The elevator ----------------------------------------------------------------------------------

local function hallArrival(): CFrame?
	local doors = grid:RoomsOfType("BlastDoor")
	local door = doors[1]
	local model = door and grid:RoomModel(door.Id)
	local socket = model and BunkerKit.Socket(model, "Door")
	if not socket then
		return nil
	end
	local at = socket.Position + HALL_ARRIVAL
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) -- facing into the hall, away from the door
end

local function ride(player: Player, way: string)
	if riding[player] or not alive(player) then
		return
	end
	local destination = if way == "Up" then exitAt else hallArrival()
	if not destination then
		alert(player, "Warning", if way == "Up" then "THE SURFACE ISN'T BUILT IN THIS PLACE YET" else "THE BLAST DOOR HALL IS GONE")
		return
	end
	local tuning = t()
	local followers = rescue:Followers(player, tuning.EscortRange)
	riding[player] = true
	player:SetAttribute("Riding", true)
	Remotes.FireClient("Elevator", player, way, tuning.FadeSeconds)
	task.delay(tuning.FadeSeconds, function()
		local character = player.Character
		if player.Parent == Players and character and alive(player) then
			local spot = (destination :: CFrame) * CFrame.new(rng:NextNumber(-1.5, 1.5), 0, 0)
			character:PivotTo(spot * CFrame.new(0, 3, 0))
			for i, id in followers do
				local column = (i - 1) % 3 - 1
				local row = math.floor((i - 1) / 3)
				rescue:MoveTo(id, spot * CFrame.new(column * 3, 0, -(3 + row * 3)))
			end
			setZone(player, Surface.Zone(spot.Position))
			log:Info("%s rode the elevator %s%s", player.Name, string.lower(way), if #followers > 0 then ` with {#followers} following` else "")
		end
		task.delay(tuning.FadeSeconds + 0.25, function()
			riding[player] = nil
			player:SetAttribute("Riding", nil)
		end)
	end)
end

local function elevatorPrompt(parent: BasePart, way: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ElevatorPrompt"
	prompt.ActionText = if way == "Up" then "RIDE UP" else "RIDE DOWN"
	prompt.ObjectText = if way == "Up" then "Elevator to the surface" else "Elevator to the bunker"
	prompt.HoldDuration = t().ElevatorHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "Elevator")
	prompt.Triggered:Connect(function(player: Player)
		ride(player, way)
	end)
	prompt.Parent = parent
	return prompt
end

local function syncHallElevator()
	local root = grid:Root()
	if not root then
		return
	end
	local folder = root:FindFirstChild("Elevator")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Elevator"
		folder.Parent = root
	end
	local doors = grid:RoomsOfType("BlastDoor")
	local door = doors[1]
	local model = door and grid:RoomModel(door.Id)
	local socket = model and BunkerKit.Socket(model, "Door")
	local anchor = (folder :: Folder):FindFirstChild("Up") :: BasePart?
	if not socket then
		if anchor then
			anchor:Destroy()
		end
		return
	end
	if not anchor then
		local part = Instance.new("Part")
		part.Name = "Up"
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = folder
		elevatorPrompt(part, "Up")
		anchor = part
	end
	(anchor :: BasePart).CFrame = CFrame.new(socket.Position + ELEVATOR_PROMPT)
end

-- Containers ------------------------------------------------------------------------------------

local function setLocked(c: Container, on: boolean)
	c.Locked = on
	c.Model:SetAttribute("Locked", if on then true else nil)
	c.Prompt.Enabled = not on and not c.Looted
end

local function refill(why: string)
	for _, c in containers do
		c.Left = nil
		c.Looted = false
		c.Model:SetAttribute("Looted", nil)
		c.Prompt.ActionText = "SEARCH"
		setLocked(c, locked(c.Location))
	end
	for _, gate in gates do
		local minEra = gate:GetAttribute("MinEra")
		local open = type(minEra) ~= "number" or eraNumber() >= minEra
		gate:SetAttribute("Open", open)
		for _, part in gate:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Barrier") then
				part.CanCollide = not open
				part.Transparency = if open then 1 else (part:GetAttribute("ShownTransparency") or 0) :: number
			end
		end
	end
	log:Info("containers refilled (%s): %d", why, #containers)
end

local function search(c: Container, player: Player)
	if c.Looted or c.Locked or not alive(player) then
		return
	end
	local location = Config.Find("SurfaceLocations", c.Location)
	if not location then
		return
	end
	local drops = c.Left or Loot.Roll(location.Loot, rng, { Skip = SKIP, ExtraRolls = classValue(player, "ExtraLootRolls") or 0 })
	local given, left = inventory:Give(player, drops)
	if #left > 0 then
		c.Left = left
		c.Prompt.ActionText = "TAKE THE REST"
		alert(player, "Warning", `PACK FULL: {Loot.Text(left)} LEFT IN IT · {inventory:PackLine(player)}`)
	else
		c.Left = nil
		c.Looted = true
		c.Model:SetAttribute("Looted", true)
		c.Prompt.Enabled = false
	end
	if #given > 0 then
		alert(player, "Info", `{string.upper(location.Name)}: {Loot.Text(given)} · {inventory:PackLine(player)}`)
	elseif #left == 0 then
		alert(player, "Info", `{string.upper(location.Name)}: NOTHING USEFUL`)
	end
	SurfaceService.Searched:Fire(player, c.Location, given)
end

local function addContainer(model: Model)
	local location = model:GetAttribute("Location")
	if type(location) ~= "string" or not Config.Find("SurfaceLocations", location) then
		log:Warn("container %s has no known Location", model:GetFullName())
		return
	end
	local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SearchPrompt"
	prompt.ActionText = "SEARCH"
	prompt.ObjectText = locationName(location)
	prompt.HoldDuration = t().SearchSeconds
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "Search")
	prompt.Parent = part
	local c: Container = { Model = model, Location = location, Prompt = prompt, Left = nil, Looted = false, Locked = false }
	prompt.Triggered:Connect(function(player: Player)
		search(c, player)
	end)
	table.insert(containers, c)
end

-- The map ---------------------------------------------------------------------------------------

local function readMap()
	local found = workspace:FindFirstChild("Surface")
	if not found then
		log:Warn("no workspace.Surface: build it with studio/map/Surface.lua (the elevator goes nowhere until then)")
		return
	end
	map = found
	for _, item in found:GetDescendants() do
		if item:IsA("BasePart") then
			local location = item:GetAttribute("Location")
			local spot: Spot = { CFrame = item.CFrame, Location = if type(location) == "string" then location else nil }
			if item.Name == "ElevatorExit" then
				exitAt = item.CFrame
			elseif item.Name == "ElevatorCall" then
				elevatorPrompt(item, "Down")
			elseif item.Name == "SurvivorSpot" then
				table.insert(survivorSpots, spot)
			elseif item.Name == "BigFindSpot" then
				table.insert(findSpots, spot)
			elseif item.Name == "SpawnPoint" then
				table.insert(spawnPoints, item.Position)
			elseif item.Name == "CampSpot" then
				local hint = item:GetAttribute("Hint")
				table.insert(campSpots, { CFrame = item.CFrame, Hint = if type(hint) == "string" then hint else "in the ruins" })
			end
		elseif item:IsA("Model") then
			if item:GetAttribute("Container") == true then
				addContainer(item)
			elseif item:GetAttribute("MinEra") ~= nil then
				table.insert(gates, item)
				for _, part in item:GetDescendants() do
					if part:IsA("BasePart") and part:GetAttribute("Barrier") then
						part:SetAttribute("ShownTransparency", part.Transparency)
					end
				end
			end
		end
	end
	log:Info("surface map: %d containers, %d survivor spots, %d find spots, %d spawn points, %d camp spots, %d gates, exit %s",
		#containers, #survivorSpots, #findSpots, #spawnPoints, #campSpots, #gates, if exitAt then "found" else "MISSING")
end

-- Survivors and big finds -----------------------------------------------------------------------

local function near(list: { Vector3 }, at: Vector3, within: number): boolean
	for _, p in list do
		if (p - at).Magnitude <= within then
			return true
		end
	end
	return false
end

local function trapSurvivor(): string?
	local taken = rescue:Spots()
	local free = {}
	for _, spot in survivorSpots do
		if not locked(spot.Location) and not near(taken, spot.CFrame.Position, 4) then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return nil
	end
	local spot = free[rng:NextInteger(1, #free)]
	return rescue:Trap(spot.CFrame, { Kind = "Survivor", Where = string.lower(locationName(spot.Location)), Tag = SURFACE_TAG })
end

local function placeFind(): string?
	local taken = {}
	for _, f in inventory:Finds() do
		table.insert(taken, f.Position)
	end
	local free = {}
	for _, spot in findSpots do
		if not locked(spot.Location) and not near(taken, spot.CFrame.Position, 6) then
			table.insert(free, spot)
		end
	end
	if #free == 0 then
		return nil
	end
	local spot = free[rng:NextInteger(1, #free)]
	return inventory:PlaceFind(t().BigFindLoot, spot.CFrame, SURFACE_TAG)
end

local function newDay(cycle: number)
	local tuning = t()
	if map and rescue:Count("Trapped", "Survivor") < tuning.MaxTrapped and rng:NextNumber() < tuning.SurvivorChancePerDay then
		local id = trapSurvivor()
		if id then
			log:Info("cycle %d: a survivor is trapped on the surface (%s)", cycle, id)
		end
	end
	local finds = 0
	for _, f in inventory:Finds(SURFACE_TAG) do
		if not f.Carried then
			finds += 1
		end
	end
	if map and finds < tuning.MaxBigFinds and rng:NextNumber() < tuning.BigFindChancePerDay then
		placeFind()
	end
end

-- The raider camp and the surface's Lost Crew (Prompt 17) ---------------------------------------

local function campSockets(model: Model, pattern: string): { CFrame }
	local list: { { Name: string, At: CFrame } } = {}
	for key, value in model:GetAttributes() do
		local name = string.match(key, "^Socket_(.+)$")
		if name and string.match(name, pattern) and typeof(value) == "CFrame" then
			table.insert(list, { Name = name, At = value })
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	local out = {}
	for _, item in list do
		table.insert(out, item.At)
	end
	return out
end

local function setupCamp()
	if not map or #campSpots == 0 or camp then
		return
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local art = assets and assets:FindFirstChild("Surface") and assets.Surface:FindFirstChild("Bldg_RaiderCamp")
	local spot = campSpots[rng:NextInteger(1, #campSpots)]
	local model: Model
	if art and art:IsA("Model") then
		model = art:Clone()
	else
		-- graybox until the art is in: a ring of crates and a pen at the back
		model = Instance.new("Model")
		local base = Instance.new("Part")
		base.Name = "Pen"
		base.Size = Vector3.new(20, 4, 1)
		base.Color = Color3.fromRGB(116, 86, 62)
		base.Anchored = true
		base.CFrame = CFrame.new(0, 2, 15)
		base.Parent = model
		model.PrimaryPart = base
		model.WorldPivot = CFrame.new()
		for i, at in { CFrame.new(-8, 0, 11), CFrame.new(0, 0, 12.5), CFrame.new(8, 0, 11) } do
			model:SetAttribute(`Socket_Crew{i}`, at)
		end
		for i, at in { CFrame.new(-12, 0, -6), CFrame.new(12, 0, -6), CFrame.new(-6, 0, -14), CFrame.new(6, 0, -14) } do
			model:SetAttribute(`Socket_Guard{i}`, at)
		end
	end
	model.Name = "RaiderCamp"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local folder = workspace:FindFirstChild("SurfaceCamp") or Instance.new("Folder")
	folder.Name = "SurfaceCamp"
	folder.Parent = workspace
	model:PivotTo(spot.CFrame)
	model.Parent = folder
	for _, at in campSockets(model, "^Light") do
		local holder_ = Instance.new("Part")
		holder_.Name = "CampLight"
		holder_.Anchored = true
		holder_.CanCollide = false
		holder_.CanQuery = false
		holder_.CanTouch = false
		holder_.Transparency = 1
		holder_.Size = Vector3.new(0.2, 0.2, 0.2)
		holder_.CFrame = spot.CFrame * at
		holder_.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 90)
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = holder_
	end
	local posts = {}
	for _, at in campSockets(model, "^Guard") do
		table.insert(posts, spot.CFrame * at)
	end
	camp = { Model = model, CFrame = spot.CFrame, Hint = spot.Hint, Posts = posts, Guards = {}, Left = #posts, NearAt = 0 }
	-- the crew in the pen: three, one of them Rare (Section 12)
	local deep = Config.Get("Tuning", "Deep")
	local crewSpots = campSockets(model, "^Crew")
	local rare = rng:NextInteger(1, math.max(#crewSpots, 1))
	for i, at in crewSpots do
		rescue:Trap(spot.CFrame * at, {
			Kind = "Crew",
			Tier = if i == rare then "Rare" else "Common",
			Level = rng:NextInteger(deep.CrewLevel.Min, deep.CrewLevel.Max),
			Where = "the raider camp",
			Tag = CREW_TAG,
		})
	end
	log:Info("the raider camp stands %s with %d crew and %d guards", spot.Hint, #crewSpots, #posts)
end

-- Where the surface's Lost Crew is held, while any of them is still trapped (the radio logs' hint).
function SurfaceService:CrewWhere(): string?
	local c = camp
	if not c then
		return nil
	end
	for _, r in rescue:Tagged(CREW_TAG) do
		if r.State == "Trapped" then
			return `Brightwater Ruins, a raider camp {c.Hint}`
		end
	end
	return nil
end

local function campTick()
	local c = camp
	if not c or director:Phase() ~= "Playing" then
		return
	end
	local deep = Config.Get("Tuning", "Deep")
	local near = false
	for _, player in onSurface() do
		local root = rootOf(player)
		if root and (root.Position - c.CFrame.Position).Magnitude <= deep.CampWakeRange then
			near = true
		end
	end
	local out = 0
	for id in c.Guards do
		if monsterService:ZoneOf(id) then
			out += 1
		else
			c.Guards[id] = nil
		end
	end
	if near then
		c.NearAt = os.clock()
		if out == 0 and c.Left > 0 then
			-- the guards come out at their posts (the ones still standing)
			for i = 1, math.min(c.Left, #c.Posts) do
				local post = c.Posts[i]
				local id = monsterService:Spawn("AshRaider", post + Vector3.new(0, 3, 0), CAMP_TAG, { Guard = deep.GuardRange })
				if id then
					c.Guards[id] = true
				end
			end
		end
	elseif out > 0 and os.clock() - c.NearAt > deep.CampSleepSeconds then
		for id in c.Guards do
			monsterService:Despawn(id)
		end
		table.clear(c.Guards)
	end
end

-- Storms ----------------------------------------------------------------------------------------

local function setStorm(on: boolean)
	storm = on
	set("Storm", on)
	if on then
		set("StormAt", now())
		nextAt.AshWraith = os.clock() + randomIn(t().WraithEverySeconds) / 2
		for _, player in onSurface() do
			alert(player, "Danger", "THE STORM HITS: RADIATION IS RISING FAST AND ASH WRAITHS ARE OUT")
		end
	else
		for id, monsterType in creatures do
			local spec = Config.Find("Monsters", monsterType)
			if spec and spec.Traits and table.find(spec.Traits, "StormOnly") then
				monsterService:Despawn(id)
				creatures[id] = nil
			end
		end
	end
end

local function earlyWarnings()
	if RunState.Get("CyclePhase") ~= "Day" or storm then
		return
	end
	local endsAt = RunState.Get("PhaseEndsAt")
	if type(endsAt) ~= "number" then
		return
	end
	local left = endsAt - now()
	local cycle = RunState.Get("Cycle") or 0
	for _, player in onSurface() do
		local extra = classValue(player, "StormWarningSeconds") or 0
		if extra > 0 and left <= t().StormSirenSeconds + extra and left > t().StormSirenSeconds and earlyWarned[player] ~= cycle then
			earlyWarned[player] = cycle
			alert(player, "Warning", `YOU HEAR THE STORM COMING: {math.ceil(left)} S`)
		end
	end
end

-- Creatures -------------------------------------------------------------------------------------

local function spawnGroup(monsterType: string, range: { Min: number, Max: number }, room: number): number
	local spec = Config.Find("Monsters", monsterType)
	if not spec or room <= 0 then
		return 0
	end
	local positions = {}
	for _, player in onSurface() do
		local root = rootOf(player)
		if root then
			table.insert(positions, root.Position)
		end
	end
	local spot = Surface.SpawnSpot(spawnPoints, positions, range, rng)
	if not spot then
		return 0
	end
	local count = math.min(rng:NextInteger(spec.Group.Min, math.max(spec.Group.Min, spec.Group.Max)), room)
	for i = 1, count do
		local angle = i / count * math.pi * 2
		local at = (spot :: Vector3) + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
		monsterService:Spawn(monsterType, CFrame.new(at + Vector3.new(0, 3, 0)), SURFACE_TAG)
	end
	log:Info("%d %s on the surface", count, monsterType)
	return count
end

local function creaturesTick()
	local players = onSurface()
	local tuning = t()
	if #players == 0 then
		if next(creatures) == nil then
			return
		end
		if emptySince == 0 then
			emptySince = os.clock()
		elseif os.clock() - emptySince > tuning.DespawnSeconds then
			for id in creatures do
				monsterService:Despawn(id)
			end
			table.clear(creatures)
			emptySince = 0
		end
		return
	end
	if emptySince ~= 0 or next(creatures) == nil then
		-- someone just came up: the first pack doesn't wait on the doorstep
		local soon = os.clock() + tuning.JackalEverySeconds.Min / 2
		nextAt.AshJackal = math.max(nextAt.AshJackal, soon)
		nextAt.AshRaider = math.max(nextAt.AshRaider, os.clock() + tuning.RaiderEverySeconds.Min / 2)
	end
	emptySince = 0
	-- a creature that fell out of the town (through a wall or a seam) is gone, not walking under it
	local floorY = if exitAt then (exitAt :: CFrame).Position.Y - FALL_GUARD else nil
	if floorY then
		for _, m in monsterService:All() do
			if creatures[m.Id] and m.Position.Y < floorY then
				log:Warn("%s fell out of the town at %s: removed", m.Id, tostring(m.Position))
				creatures[m.Id] = nil
				monsterService:Despawn(m.Id)
			end
		end
	end
	local count = 0
	for id in creatures do
		if monsterService:ZoneOf(id) then
			count += 1
		else
			creatures[id] = nil
		end
	end
	local room = tuning.MaxMonsters - count
	if room <= 0 or director:Phase() ~= "Playing" then
		return
	end
	if storm then
		if os.clock() >= nextAt.AshWraith then
			spawnGroup("AshWraith", tuning.WraithDistance, room)
			nextAt.AshWraith = os.clock() + randomIn(tuning.WraithEverySeconds)
		end
		return
	end
	if os.clock() >= nextAt.AshJackal then
		room -= spawnGroup("AshJackal", tuning.SpawnDistance, room)
		nextAt.AshJackal = os.clock() + randomIn(tuning.JackalEverySeconds)
	end
	if eraNumber() >= tuning.RaiderMinEra and os.clock() >= nextAt.AshRaider then
		spawnGroup("AshRaider", tuning.SpawnDistance, room)
		nextAt.AshRaider = os.clock() + randomIn(tuning.RaiderEverySeconds)
	end
end

-- Loops -----------------------------------------------------------------------------------------

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			if not riding[player] then
				setZone(player, Surface.Zone(root.Position))
			end
			radiationTick(player, root, dt)
		end
	end
	earlyWarnings()
end

local function loop()
	local last = os.clock()
	local creatureAt = 0
	while true do
		task.wait(t().TickSeconds)
		local clockNow = os.clock()
		local dt = math.min(clockNow - last, 2)
		last = clockNow
		local ok, err = pcall(tick, dt)
		if not ok then
			log:Warn("tick: %s", tostring(err))
		end
		if clockNow >= creatureAt then
			creatureAt = clockNow + 1
			local okC, errC = pcall(creaturesTick)
			if not okC then
				log:Warn("creatures: %s", tostring(errC))
			end
			local okK, errK = pcall(campTick)
			if not okK then
				log:Warn("camp: %s", tostring(errK))
			end
		end
	end
end

local function clear()
	for id in creatures do
		monsterService:Despawn(id)
	end
	table.clear(creatures)
	local c = camp
	if c then
		for id in c.Guards do
			monsterService:Despawn(id)
		end
		table.clear(c.Guards)
	end
	if storm then
		setStorm(false)
	end
end

-- Dev -------------------------------------------------------------------------------------------

local function targetPlayer(player: Player?, name: any): Player?
	if type(name) == "string" and name ~= "" then
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
				return p
			end
		end
	end
	return player or Players:GetPlayers()[1]
end

local function describe(): string
	local looted, lockedCount = 0, 0
	for _, c in containers do
		if c.Looted then
			looted += 1
		end
		if c.Locked then
			lockedCount += 1
		end
	end
	local creatureCount = 0
	for _ in creatures do
		creatureCount += 1
	end
	local lines = {
		`map {if map then "found" else "MISSING"} · storm {storm} · {#containers} containers ({looted} searched, {lockedCount} locked) · {creatureCount} creatures up`,
		`survivor spots {#survivorSpots}, find spots {#findSpots}, spawn points {#spawnPoints}, trapped {rescue:Count("Trapped")}`,
	}
	for _, player in Players:GetPlayers() do
		table.insert(lines, `  {player.Name}: {SurfaceService:Zone(player)}, radiation {string.format("%.1f", radiation[player] or 0)}, {inventory:PackLine(player)}, pills {inventory:Pills(player)}`)
	end
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("surface", {
		Description = "The surface: map, storm, containers, creatures, players' zones and radiation (Prompt 16).",
		Usage = "surface",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("surface.up", {
		Description = "Ride the elevator up (as if holding RIDE UP).",
		Usage = "surface.up [player]",
		Run = function(player, args): string?
			local p = targetPlayer(player, args[1])
			if not p then
				return "no player"
			end
			ride(p, "Up")
			return `{p.Name} going up`
		end,
	})
	dev:Register("surface.down", {
		Description = "Ride the elevator down.",
		Usage = "surface.down [player]",
		Run = function(player, args): string?
			local p = targetPlayer(player, args[1])
			if not p then
				return "no player"
			end
			ride(p, "Down")
			return `{p.Name} going down`
		end,
	})
	dev:Register("rad", {
		Description = "Set your radiation (0 to 100).",
		Usage = "rad <n> [player]",
		Run = function(player, args): string?
			local p = targetPlayer(player, args[2])
			if not p then
				return "no player"
			end
			radiation[p] = math.clamp(tonumber(args[1]) or 0, 0, Config.Get("Tuning", "Player").RadiationMax)
			publishRadiation(p, radiation[p])
			return `{p.Name}: radiation {radiation[p]}`
		end,
	})
	dev:Register("storm", {
		Description = "Start or stop the storm over the surface (the next Surge sets it again).",
		Usage = "storm <on|off>",
		Run = function(_, args): string?
			setStorm(tostring(args[1] or "on") ~= "off")
			return `storm {storm}`
		end,
	})
	dev:Register("loot.refill", {
		Description = "Refill every surface container now (as at a new era).",
		Usage = "loot.refill",
		Run = function(): string?
			refill("dev")
			return `{#containers} containers refilled`
		end,
	})
	dev:Register("surface.spawn", {
		Description = "Spawn a surface creature group by the players on the surface.",
		Usage = "surface.spawn <AshJackal|AshRaider|AshWraith> [room]",
		Run = function(_, args): string?
			local monsterType = tostring(args[1] or "AshJackal")
			local n = spawnGroup(monsterType, if monsterType == "AshWraith" then t().WraithDistance else t().SpawnDistance,
				math.floor(tonumber(args[2]) or 6))
			return `{n} {monsterType}`
		end,
	})
	dev:Register("survivor", {
		Description = "Trap a survivor at a free spot on the surface.",
		Usage = "survivor",
		Run = function(): string?
			return trapSurvivor() or "no free survivor spot"
		end,
	})
	dev:Register("surface.find", {
		Description = "Put generator parts at a free find spot on the surface.",
		Usage = "surface.find",
		Run = function(): string?
			return placeFind() or "no free find spot"
		end,
	})
end

function SurfaceService:Init(registry)
	clock = registry.CycleClock
	director = registry.RunDirector
	grid = registry.BunkerGrid
	power = registry.PowerService
	combat = registry.CombatService
	monsterService = registry.MonsterService
	inventory = registry.InventoryService
	rescue = registry.RescueService
	set = RunState.Writer("SurfaceService")
	registerCommands(registry.DevService)
end

function SurfaceService:Start()
	set("Storm", false)
	readMap()
	refill("start")
	local okCamp, errCamp = pcall(setupCamp)
	if not okCamp then
		log:Warn("the raider camp: %s", tostring(errCamp))
	end
	syncHallElevator()
	grid.Changed:Connect(syncHallElevator)
	clock.EraChanged:Connect(function()
		refill("new era")
	end)
	clock.CycleStarted:Connect(newDay)
	clock.SirenStarted:Connect(function()
		local endsAt = RunState.Get("PhaseEndsAt")
		if type(endsAt) == "number" then
			set("StormAt", endsAt)
		end
		for _, player in onSurface() do
			alert(player, "Warning", `THE STORM HITS IN {t().StormSirenSeconds} S: GET BACK TO THE ELEVATOR`)
		end
	end)
	clock.SurgeStarted:Connect(function()
		setStorm(true)
	end)
	clock.SurgeEnded:Connect(function()
		setStorm(false)
	end)
	monsterService.Spawned:Connect(function(id: string, monsterType: string, tag: string?)
		if tag == SURFACE_TAG then
			creatures[id] = monsterType
		end
	end)
	monsterService.Died:Connect(function(id: string)
		creatures[id] = nil
		local c = camp
		if c and c.Guards[id] then
			c.Guards[id] = nil
			c.Left = math.max(c.Left - 1, 0)
			if c.Left == 0 then
				for _, player in onSurface() do
					alert(player, "Info", "THE RAIDER CAMP IS CLEARED: FREE THE CREW IN THE PEN")
				end
			end
		end
	end)
	combat.Damaged:Connect(function(targetId: string, amount: number, sourceId: string?)
		if amount <= 0 or not sourceId or string.sub(sourceId, 1, 1) ~= "M" or string.sub(targetId, 1, 1) ~= "P" then
			return
		end
		local source = combat:Get(sourceId)
		local spec = source and source.MonsterType and Config.Find("Monsters", source.MonsterType)
		if spec and spec.Traits and table.find(spec.Traits, "Radiates") then
			local target = combat:Get(targetId)
			local player = target and target.Player
			if player then
				SurfaceService:AddRadiation(player, t().WraithRadiationPerHit * (classValue(player, "RadiationGain") or 1), "wraith")
			end
		end
	end)
	local function joined(player: Player)
		radiation[player] = 0
		player:SetAttribute("Radiation", 0)
		player:SetAttribute("Zone", "Bunker")
		player.CharacterAdded:Connect(function()
			-- a new life starts clean (a Bible Question: the bible doesn't say)
			radiation[player] = 0
			warned[player] = 0
			player:SetAttribute("Radiation", 0)
		end)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player: Player)
		radiation[player] = nil
		warned[player] = nil
		earlyWarned[player] = nil
		riding[player] = nil
	end)
	director.RunEnded:Connect(clear)
	task.spawn(loop)
end

return SurfaceService
