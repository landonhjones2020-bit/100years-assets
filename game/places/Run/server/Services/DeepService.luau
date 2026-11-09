--!strict
--[[
	DeepService: the Deep, the caves behind the bunker (bible Sections 6, 11, 12 and 23; Run place,
	Prompt 17). The arithmetic is Shared.Rules.Deep; the pieces Config.CavePieces (A6); the numbers
	Tuning.Deep (provisional); the logs Config.RadioLogs.

	* Caves (Section 12: "When a dug cell breaks into a cave, a cave area opens behind it. Caves are
	  put together from hand-made pieces for that band, so no two runs match"): when a cave opening
	  appears in a dug cell (DigService.FeatureAdded), its cave is put together behind the grid from
	  the band's pieces (Rules.Deep.Plan, clear of every cave already open) in workspace.Deep. The
	  dug cell's back rock steps aside for the Entry's rock face (again whenever the grid rebuilds
	  the cell), the mouth's stand-in goes (DigService:OpenCave), exits with no room left are
	  plugged with rubble, and each piece's Light sockets get a lantern's light. Caves stay open
	  (Section 12): the mouth stays a breach point (DigService) and monsters walk in and out
	  through it (MonsterService:SetCaveExit).
	* Finds (Section 12: ore veins, caches, radio logs, cryo pods, trapped miners, Glowshard chests):
	  each Find socket rolls Rules.Deep.RollFind (cryo pods from Era II; the team's best FindChance,
	  the Spelunker's level 2):
	  - Ore vein: MINE: Loot OreVein (the band's ore, "much richer than digging alone") into the
	    miner's pack. Anyone can mine (a Bible Question).
	  - Cache: OPEN: Loot Cache into the opener's pack (radio logs play, throwables to the hotbar).
	  - Radio log: LISTEN: the recorder plays its log (below) to whoever listens.
	  - Trapped miner: RescueService, Kind Miner (Rare at MinerRareChance); brought home, a resident.
	  - Cryo pod: a big find (InventoryService); the Cryo Bay unlocks when the first is found.
	  - Glowshard chest (rare): OPEN: 1 to 3 Glowshards to everyone in the run (a Bible Question).
	  What doesn't fit in a pack stays for TAKE THE REST.
	* Guards and nests (Section 12: monsters; nests): pieces with Spawn sockets hold guards
	  (GuardChance) worth GuardBudget of the band's monsters (Rules.Deep.Roster); a cavern's Nest
	  socket holds a nest (NestChance, else a cache). They come out when a player first comes within
	  WakeRange of their piece, asleep at their posts until one comes within GuardRange
	  (MonsterService guards). A cave nest is a monster combatant: while it lives it raises
	  Disturbance every cycle like a dug nest (NestPerCycle) and feeds breaches through the cave's
	  mouth; destroyed, it pays Loot Nest into the killer's pack, drops Disturbance by NestDestroyed
	  (Section 10) and stops feeding breaches.
	* Lost Crews (Section 12: one in each band of the Deep, their spots change each run, guarded by
	  a nest below): at the start each band's crew is put in a rock cell (Rules.Deep.CrewCell, at
	  least CrewMinDepth from anything open) whose roll becomes a cave opening (DigService:SetRoll);
	  that cave ends in the band's CrewPocket with the crew trapped there (three, one Rare:
	  RescueService Kind Crew, Tag the objective) and a nest with NestBudget of guards. The surface's
	  crew is SurfaceService's raider camp. When the first of a crew comes home, its objective is
	  done (ObjectiveService: +2 Years per Cycle); if all three are lost, so is the crew.
	* Radio logs (Section 12: radio logs give hints about where each crew is): from Find spots and
	  from loot (InventoryService's RadioLog special): the next log not yet heard this run; while a
	  crew is still lost, HintChance of the time a crew's log, ending with where that crew was last
	  heard from (Rules.Deep.Hint; the surface's from SurfaceService:CrewWhere). The RadioLog remote
	  shows it (DeepController).
	* Cryo pods (Sections 6 and 11): found in caves and in dug cells (DigService's CryoPod result,
	  Era II). Hauled home (unloaded at the hall or a Storage room) they wait (RunState CryoPods);
	  Cryo Bays thaw them with their Thawing output (EconomyService:Rate), ThawPoints a pod, into a
	  Rare or Legendary resident (LegendaryChance) who steps out in the Cryo Bay.
	* Drops and darkness (Section 12): a player in the Deep carries a light (DeepLight: LightRange
	  times LightRadius, the Spelunker's double); a fall past FallDamageFrom studs hurts
	  (NoFallDamage). The Deep's lighting is the client's (SurfaceController).

	API: Caves(): number, CaveAt(position): string?, Pods(): number; Prompt 18: DistressSpot(): (CFrame?, string?),
	CrewCall(): (logId?, where?) and PlayLog(player, logId, hint?) for the Radio Room.
	Signals: CaveOpened(cellKey, band, pieces), CrewHome(objectiveId, leader?), Thawed(residentId, tier),
	ChestOpened(player, glowshards).
	Dev: deep, deep.cave <floor> <column>, deep.find <kind>, deep.tp <floor> <column>, cryo.add [n],
	radiolog [id], crews.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Deep = require(Shared.Rules.Deep)
local Dig = require(Shared.Rules.Dig)
local Economy = require(Shared.Rules.Economy)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local Surface = require(Shared.Rules.Surface)
local Threat = require(Shared.Rules.Threat)

local log = Log.new("DeepService")

local DeepService = {
	Name = "DeepService",
	Dependencies = {
		"BunkerGrid", "CycleClock", "RunDirector", "SessionService", "DigService", "InventoryService", "RescueService",
		"MonsterService", "CombatService", "ResidentService", "ResidentBrain", "EconomyService", "BuildService",
		"ObjectiveService", "BreachService", "ProfileService", "SurfaceService", "DevService",
	},
	CaveOpened = Signal.new() :: Signal.Signal<string, string, number>,
	CrewHome = Signal.new() :: Signal.Signal<string, Player?>,
	Thawed = Signal.new() :: Signal.Signal<string, string>,
	ChestOpened = Signal.new() :: Signal.Signal<Player, number>,
}

local CAMERA_IGNORE_TAG = "CameraIgnore"
-- loot nothing hands out yet: gear (Prompt 26), blueprints (19), recruits (18), the Lamp (placeables)
local SKIP: { [string]: boolean } = { Gear = true, Blueprint = true, Recruit = true, Lamp = true }
local LANTERN: { [string]: Color3 } = {
	Mines = Color3.fromRGB(255, 178, 104),
	FloodedCaverns = Color3.fromRGB(150, 232, 214),
	CrystalHollows = Color3.fromRGB(180, 255, 205),
}
local OWN_LIGHT = Color3.fromRGB(255, 236, 206)
local PLUG_SCALE = 1.45 -- the doorway rubble (8 x 10) over a cave's 14 x 12 opening
local FIND_PROMPT: { [string]: { Action: string, Object: string, Hold: string } } = {
	OreVein = { Action = "MINE", Object = "Ore vein", Hold = "MineSeconds" },
	Cache = { Action = "OPEN", Object = "Cache", Hold = "OpenSeconds" },
	RadioLog = { Action = "LISTEN", Object = "Radio log", Hold = "ListenSeconds" },
	GlowshardChest = { Action = "OPEN", Object = "Glowshard chest", Hold = "ChestSeconds" },
}

type Piece = {
	Index: number,
	Spec: any,
	CFrame: CFrame,
	Box: Deep.Box,
	Model: Model,
	Guards: number, -- the guards' budget (0: none)
	Posts: { CFrame },
	Woken: boolean,
}
type Cave = {
	Key: string,
	Floor: number,
	Column: number,
	Band: string,
	Folder: Model,
	Pieces: { Piece },
	Crew: string?, -- the Lost Crew's objective
}
type Find = {
	Id: string,
	Kind: string,
	Cave: string,
	Band: string,
	Model: Model,
	Prompt: ProximityPrompt,
	Left: { Loot.Drop }?,
	LogId: string?,
	Hint: string?,
}
type Nest = { Id: string, Cave: string, Model: Model }
type Crew = { Objective: string, Band: string, Floor: number, Column: number, State: string } -- Hidden, Found, Home, Lost

local grid: any = nil
local clock: any = nil
local director: any = nil
local session: any = nil
local dig: any = nil
local inventory: any = nil
local rescue: any = nil
local monsterService: any = nil
local combat: any = nil
local residents: any = nil
local brain: any = nil
local economy: any = nil
local builds: any = nil
local objectives: any = nil
local breaches: any = nil
local profiles: any = nil
local surface: any = nil
local set: (string, any) -> () = function() end

local caves: { [string]: Cave } = {}
local boxes: { Deep.Box } = {} -- every placed piece (the planner keeps clear of them)
local finds: { [string]: Find } = {}
local nests: { [string]: Nest } = {} -- combatant id -> nest
local nestHits: { [string]: string } = {} -- a nest's combatant id -> who hit it last
local crews: { [string]: Crew } = {} -- objective -> crew (the Deep's)
local crewCells: { [string]: string } = {} -- cell key -> objective
local crewSeen: { [string]: boolean } = {} -- crews whose members were ever out (lost when none are left)
local heard: { [string]: boolean } = {} -- radio logs played this run
local pods = 0
local thaw = 0
local counter = 0
local rng = Random.new()

-- Helpers -----------------------------------------------------------------------------------------

local function t(): { [string]: any }
	return Deep.Tuning()
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function alertAll(kind: string, text: string)
	for _, player in Players:GetPlayers() do
		alert(player, kind, text)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(player: Player): boolean
	return player.Parent == Players and player:GetAttribute("Life") == "Alive"
end

local function eraNumber(): number
	return Threat.EraNumber(clock:Era())
end

-- A class modifier at the player's class level (class levels come with Prompt 20).
local function classValue(player: Player?, key: string): number?
	local class = if player then player:GetAttribute("Class") else nil
	local level = if player then player:GetAttribute("ClassLevel") else nil
	return Modifiers.ClassValue(if type(class) == "string" then class else nil, key, if type(level) == "number" then level else nil)
end

local function holder(): Folder
	local f = workspace:FindFirstChild("Deep")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Deep"
		f.Parent = workspace
	end
	return f :: Folder
end

local function art(category: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	local found = folder and folder:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

-- A model's sockets matching a pattern ("^Find"), in the world, in name order.
local function sockets(model: Model, pattern: string): { CFrame }
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
	local pivot = model:GetPivot()
	local out = {}
	for _, item in list do
		table.insert(out, pivot * item.At)
	end
	return out
end

local function anchorAll(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

local function nearestOnBox(box: Deep.Box, position: Vector3): Vector3
	return position:Max(box.Min):Min(box.Max)
end

local function lightAt(parent: Instance, at: CFrame, color: Color3, range: number, brightness: number)
	local part = Instance.new("Part")
	part.Name = "Lantern"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = at
	part.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false -- many lanterns: shadows only from players' own lights (phones, Section 26)
	light.Parent = part
end

local function bandName(band: string): string
	local entry = Config.Find("DepthBands", band)
	return if entry then entry.Name else band
end

-- Where a cave's monsters come out into the bunker (and walk back in): the dug cell in front.
local function mouthBreach(c: Cave, id: string): any
	local cell = Grid.CellPosition(c.Floor, c.Column)
	local out = Deep.MouthPoint(c.Floor, c.Column)
	return {
		Id = id,
		Kind = "Cave",
		RoomId = nil,
		Floor = c.Floor,
		Column = c.Column,
		Weight = 1,
		Dark = false,
		At = CFrame.lookAt(out, out + Vector3.new(0, 0, 1)),
		Source = cell + Vector3.new(0, 3, -13),
	}
end

-- Radio logs --------------------------------------------------------------------------------------

-- The crews still lost, and where each was last heard from.
local function lostCrews(): { { Objective: string, Where: string } }
	local list = {}
	for _, crew in crews do
		if crew.State == "Hidden" or crew.State == "Found" then
			local trapped = crew.State == "Hidden"
			for _, r in rescue:Tagged(crew.Objective) do
				if r.State == "Trapped" then
					trapped = true
				end
			end
			if trapped then
				table.insert(list, { Objective = crew.Objective, Where = Deep.Hint(crew.Floor, crew.Column) })
			end
		end
	end
	local up = surface:CrewWhere()
	if up then
		table.insert(list, { Objective = "CrewSurface", Where = up })
	end
	table.sort(list, function(a, b)
		return a.Objective < b.Objective
	end)
	return list
end

local function crewLog(objectiveId: string): string?
	for _, id in Config.Ids("RadioLogs") do
		if Config.Get("RadioLogs", id).Crew == objectiveId then
			return id
		end
	end
	return nil
end

-- The next log to play, and where its crew was last heard from (or nil). While a crew is still
-- lost, HintChance of the time it is that crew's own call; else the story goes on in order.
local function chooseLog(): (string?, string?)
	local era = eraNumber()
	local lost = {}
	for _, crew in lostCrews() do
		if crewLog(crew.Objective) then
			table.insert(lost, crew)
		end
	end
	if #lost > 0 and rng:NextNumber() < t().HintChance then
		local crew = lost[rng:NextInteger(1, #lost)]
		local id = crewLog(crew.Objective) :: string
		heard[id] = true
		return id, crew.Where
	end
	local story = {}
	for _, id in Config.Ids("RadioLogs") do
		local entry = Config.Get("RadioLogs", id)
		if (entry.MinEra or 1) <= era and not entry.Crew then
			table.insert(story, id)
		end
	end
	for _, id in story do
		if not heard[id] then
			heard[id] = true
			return id, nil
		end
	end
	if #lost > 0 then
		local crew = lost[rng:NextInteger(1, #lost)]
		return crewLog(crew.Objective), crew.Where
	end
	return story[rng:NextInteger(1, math.max(#story, 1))], nil -- every log heard: they repeat
end

local function playLog(player: Player, id: string, hint: string?)
	local entry = Config.Get("RadioLogs", id)
	Remotes.FireClient("RadioLog", player, entry.Title, entry.From, entry.Text, hint)
	log:Info("%s heard %s%s", player.Name, id, if hint then ` (hint: {hint})` else "")
end

-- Glowshard chests --------------------------------------------------------------------------------

-- A chest's Glowshards go to everyone in the run (a Bible Question), straight into their profiles.
local function payChest(opener: Player, shards: number): number
	if shards <= 0 then
		return 0
	end
	local paid = 0
	for _, player in session:ReadyPlayers() do
		local ok = profiles:Update(player, function(data: any)
			data.Glowshards += shards
		end)
		if ok then
			paid += 1
		end
	end
	alertAll("Info", `{string.upper(opener.DisplayName)} OPENED A GLOWSHARD CHEST: +{shards} GLOWSHARD{if shards == 1 then "" else "S"} FOR EVERYONE`)
	log:Info("%s opened a Glowshard chest: %d each to %d players", opener.Name, shards, paid)
	DeepService.ChestOpened:Fire(opener, shards)
	return shards
end

-- Finds -------------------------------------------------------------------------------------------

local function removeFind(f: Find)
	if finds[f.Id] ~= f then
		return
	end
	finds[f.Id] = nil
	f.Model:Destroy()
end

-- Loot into the player's pack; what doesn't fit stays in the find (TAKE THE REST).
local function takeLoot(f: Find, player: Player, tableId: string, verb: string)
	local drops = f.Left or Loot.Roll(tableId, rng, { BandOre = Config.Get("DepthBands", f.Band).Ore, Skip = SKIP })
	local given, left = inventory:Give(player, drops)
	if #left > 0 then
		f.Left = left
		f.Prompt.ActionText = "TAKE THE REST"
		alert(player, "Warning", `PACK FULL: {inventory:PackLine(player)} · THE REST STAYS`)
	else
		removeFind(f)
	end
	if #given > 0 then
		alert(player, "Info", `{verb}: {Loot.Text(given)} · {inventory:PackLine(player)}`)
	end
end

local function onFind(f: Find, player: Player)
	if finds[f.Id] ~= f or not alive(player) then
		return
	end
	if f.Kind == "OreVein" then
		takeLoot(f, player, "OreVein", "MINED")
	elseif f.Kind == "Cache" then
		takeLoot(f, player, "Cache", "THE CACHE")
	elseif f.Kind == "GlowshardChest" then
		local drops = Loot.Roll("GlowshardChest", rng, {})
		local shards = 0
		for _, drop in drops do
			if drop.Special == "Glowshards" then
				shards += drop.Count
			end
		end
		removeFind(f)
		payChest(player, math.max(shards, 1))
	elseif f.Kind == "RadioLog" then
		if not f.LogId then
			f.LogId, f.Hint = chooseLog()
			f.Prompt.ObjectText = "Radio log · heard"
		end
		local id = f.LogId
		if id then
			playLog(player, id, f.Hint)
		end
	end
end

local function findModel(kind: string, band: string): Model
	local source = if kind == "OreVein" then art("Props", `Prop_OreVein_{Config.Get("DepthBands", band).Ore or "Iron"}`)
		elseif kind == "Cache" then art("Props", "Prop_SupplyCrate")
		else art("Props", `Prop_{kind}`)
	if source then
		return source:Clone()
	end
	local model = Instance.new("Model")
	local box = Instance.new("Part")
	box.Name = "Body"
	box.Size = if kind == "OreVein" then Vector3.new(5, 3.5, 4) else Vector3.new(2.4, 2, 2)
	box.Color = if kind == "OreVein" then Color3.fromRGB(150, 92, 60) elseif kind == "GlowshardChest" then Color3.fromHex("#7CFF9B")
		else Color3.fromRGB(96, 102, 110)
	box.Material = Enum.Material.SmoothPlastic
	box.PivotOffset = CFrame.new(0, -box.Size.Y / 2, 0)
	box.Parent = model
	model.PrimaryPart = box
	return model
end

local function placeFind(c: Cave, kind: string, at: CFrame): string?
	if kind == "Nothing" then
		return nil
	elseif kind == "TrappedMiner" then
		local level = t().MinerLevel
		return rescue:Trap(at, {
			Kind = "Miner",
			Tier = if rng:NextNumber() < t().MinerRareChance then "Rare" else "Common",
			Level = rng:NextInteger(level.Min, level.Max),
			Where = `the {bandName(c.Band)}`,
			Tag = `Cave:{c.Key}`,
		})
	elseif kind == "CryoPod" then
		return DeepService:PlacePod(at, `Cave:{c.Key}`)
	end
	local spec = FIND_PROMPT[kind]
	if not spec then
		return nil
	end
	counter += 1
	local id = `D{counter}`
	local model = findModel(kind, c.Band)
	model.Name = `{kind}_{id}`
	model:SetAttribute("Find", kind)
	model:SetAttribute("FindId", id)
	anchorAll(model)
	model:PivotTo(at)
	model.Parent = c.Folder
	local _, size = model:GetBoundingBox()
	local spot = Instance.new("Part")
	spot.Name = "FindPrompt"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = CFrame.new(at.Position + Vector3.new(0, math.min(size.Y, 4) + 0.5, 0))
	spot.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = spec.Action
	prompt.ObjectText = spec.Object
	prompt.HoldDuration = t()[spec.Hold]
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = spot
	local f: Find = { Id = id, Kind = kind, Cave = c.Key, Band = c.Band, Model = model, Prompt = prompt, Left = nil, LogId = nil, Hint = nil }
	finds[id] = f
	prompt.Triggered:Connect(function(player: Player)
		onFind(f, player)
	end)
	return id
end

-- The team's best FindChance (the Spelunker's level 2): cryo pods and caches turn up more often.
local function teamFindChance(): number
	local best = 1
	for _, player in Players:GetPlayers() do
		best = math.max(best, classValue(player, "FindChance") or 1)
	end
	return best
end

-- Cryo pods -----------------------------------------------------------------------------------------

local function unlockCryo()
	if builds:Unlocked().CryoBay then
		return
	end
	builds:Unlock("CryoBay")
	alertAll("Info", "A CRYO POD! THE CRYO BAY IS UNLOCKED: HAUL THE POD HOME AND BUILD ONE TO THAW IT")
end

-- Puts a cryo pod (a big find) in the world; the Cryo Bay unlocks with the first (Section 6).
function DeepService:PlacePod(at: CFrame, tag: string?): string?
	local id = inventory:PlaceFind("CryoPod", at, tag)
	unlockCryo()
	return id
end

function DeepService:Pods(): number
	return pods
end

local function thawOne()
	local rooms = grid:RoomsOfType("CryoBay")
	local room = rooms[rng:NextInteger(1, math.max(#rooms, 1))]
	local tier = Deep.CryoTier(rng:NextNumber())
	local level = t().CryoLevel
	local id = residents:Add(tier, rng:NextInteger(level.Min, level.Max))
	local body = brain:Body(id)
	if body and room then
		body:PivotTo(Grid.CellCFrame(room.Floor, room.Column) * CFrame.new(0, 0, 2))
	end
	local record = residents:Get(id)
	local name = if record then Residents.Name(record) else id
	alertAll("Info", `{string.upper(name)} ({string.upper(tier)}) THAWS OUT IN THE CRYO BAY AND JOINS THE BUNKER`)
	log:Info("a cryo pod thawed: %s (%s)", id, tier)
	DeepService.Thawed:Fire(id, tier)
end

local function thawTick(dt: number)
	if pods <= 0 then
		thaw = 0
		return
	end
	local rate = 0
	for _, room in grid:RoomsOfType("CryoBay") do
		rate += economy:Rate(room.Id)
	end
	if rate <= 0 then
		return
	end
	thaw += rate * dt / Economy.CycleSeconds()
	if thaw >= t().ThawPoints then
		thaw -= t().ThawPoints
		pods -= 1
		set("CryoPods", pods)
		thawOne()
	end
end

-- Nests -------------------------------------------------------------------------------------------

local function placeNest(c: Cave, at: CFrame)
	local source = art("Props", "Prop_Nest")
	local model: Model
	if source then
		model = source:Clone()
	else
		model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Name = "Graybox"
		p.Size = Vector3.new(7, 5, 6)
		p.Color = Color3.fromHex("#6E4766")
		p.PivotOffset = CFrame.new(0, -2.5, 0)
		p.Parent = model
		model.PrimaryPart = p
	end
	model.Name = `Nest_{c.Key}`
	model:SetAttribute("Find", "Nest")
	anchorAll(model)
	model:PivotTo(at)
	if not model.PrimaryPart then
		local best, volume = nil, 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Size.X * part.Size.Y * part.Size.Z > volume then
				best, volume = part, part.Size.X * part.Size.Y * part.Size.Z
			end
		end
		model.PrimaryPart = best
	end
	model.Parent = c.Folder
	local id = combat:Register(model, { Kind = "Monster", Team = "Monsters", Health = Dig.Tuning().NestHealth, MonsterType = "Nest" })
	if not id then
		model:Destroy()
		return
	end
	nests[id] = { Id = id, Cave = c.Key, Model = model }
	breaches:SetExtraPoint(`CN:{id}`, mouthBreach(c, `CN:{id}`))
end

local function destroyNest(n: Nest, killer: Player?)
	if nests[n.Id] ~= n then
		return
	end
	nests[n.Id] = nil
	nestHits[n.Id] = nil
	breaches:SetExtraPoint(`CN:{n.Id}`, nil)
	local c = caves[n.Cave]
	local band = if c then c.Band else "Mines"
	local drops = Loot.Roll("Nest", rng, { BandOre = Config.Get("DepthBands", band).Ore, Skip = SKIP })
	local text = "NOTHING"
	if killer and killer.Parent == Players then
		local given, left = inventory:Give(killer, drops)
		text = if #given > 0 then `{Loot.Text(given)} INTO {string.upper(killer.DisplayName)}'S PACK` else "THE PACK WAS FULL"
		if #left > 0 then
			alert(killer, "Warning", `PACK FULL: {inventory:PackLine(killer)}`)
		end
	else
		local given = {}
		for _, drop in drops do
			if drop.Resource then
				local added = economy:Add(drop.Resource, drop.Count, "cave nest")
				if added > 0 then
					table.insert(given, { Resource = drop.Resource, Count = added })
				end
			end
		end
		text = if #given > 0 then Loot.Text(given) else "NOTHING"
	end
	local drop = Dig.DisturbanceTuning().NestDestroyed
	dig:AddDisturbance(-drop, "NestDestroyed")
	alertAll("Info", `THE CAVE NEST IS DESTROYED: {text} · DISTURBANCE -{drop}`)
	log:Info("cave nest %s destroyed by %s", n.Id, if killer then killer.Name else "-")
end

-- Guards ------------------------------------------------------------------------------------------

local function usable(monsterType: string): boolean
	local spec = Config.Find("Monsters", monsterType)
	return spec ~= nil and art("Monsters", spec.Asset) ~= nil
end

local function spawnGuards(c: Cave, budget: number, posts: { CFrame })
	if budget <= 0 or #posts == 0 then
		return
	end
	local roster = Deep.Roster(c.Band, usable)
	if #roster == 0 then
		return
	end
	local n = 0
	for _, group in Threat.Groups(budget, roster, rng) do
		for _ = 1, group.Count do
			n += 1
			local post = posts[(n - 1) % #posts + 1]
			local jitter = Vector3.new(rng:NextNumber(-2.5, 2.5), 2, rng:NextNumber(-2.5, 2.5))
			monsterService:Spawn(group.Type, post + jitter, `Cave:{c.Key}`, { Guard = t().GuardRange })
		end
	end
	log:Info("%d guards came out in the cave at %s", n, c.Key)
end

local function wakeTick()
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and alive(player) and Surface.Zone(root.Position) ~= "Surface" then
			table.insert(positions, root.Position)
		end
	end
	if #positions == 0 then
		return
	end
	local range = t().WakeRange
	for _, c in caves do
		for _, piece in c.Pieces do
			if not piece.Woken and piece.Guards > 0 then
				for _, at in positions do
					if (nearestOnBox(piece.Box, at) - at).Magnitude <= range then
						piece.Woken = true
						spawnGuards(c, piece.Guards, piece.Posts)
						break
					end
				end
			end
		end
	end
end

-- Lost Crews --------------------------------------------------------------------------------------

local function trapCrew(c: Cave, crew: Crew, piece: Piece?)
	local spots: { CFrame } = if piece then sockets(piece.Model, "^Crew") else {}
	if #spots == 0 then
		-- no room met the crew's pocket: they're in the cave's last piece
		local last = c.Pieces[#c.Pieces]
		local at = if last then last.CFrame * CFrame.new(0, 0, -10)
			else Deep.MouthCFrame(c.Floor, c.Column) * CFrame.new(0, 0, 4) * CFrame.Angles(0, math.pi, 0) -- in the dug cell
		spots = { at * CFrame.new(-3, 0, 0), at, at * CFrame.new(3, 0, 0) }
	end
	local level = t().CrewLevel
	local rare = rng:NextInteger(1, 3)
	for i = 1, 3 do
		rescue:Trap(spots[(i - 1) % #spots + 1], { -- the pocket's Crew sockets face its way in
			Kind = "Crew",
			Tier = if i == rare then "Rare" else "Common",
			Level = rng:NextInteger(level.Min, level.Max),
			Where = `the {bandName(crew.Band)}`,
			Tag = crew.Objective,
		})
	end
	crew.State = "Found"
	crewSeen[crew.Objective] = true
	alertAll("Info", `A LOST CREW! THE {string.upper(bandName(crew.Band))} CREW IS TRAPPED IN THIS CAVE, GUARDED BY A NEST`)
end

local function setupCrews()
	local seed = RunState.Get("DigSeed")
	local bunker = grid:Bunker()
	for _, objective in Config.All("Objectives") do
		local band = objective.Where
		if objective.Kind == "LostCrew" and t().CrewFloors[band] and #Deep.Pieces(band, "CrewPocket") > 0 then
			local floor, column = Deep.CrewCell(if type(seed) == "number" then seed else 1, band, function(f: number, col: number): boolean
				return bunker:IsOpen(f, col)
			end)
			if floor and column then
				crews[objective.Id] = { Objective = objective.Id, Band = band, Floor = floor, Column = column, State = "Hidden" }
				crewCells[Grid.Key(floor, column)] = objective.Id
				dig:SetRoll(floor, column, "CaveOpening")
				log:Info("%s is behind %s", objective.Id, Grid.Key(floor, column))
			end
		end
	end
	if #rescue:Tagged("CrewSurface") > 0 then
		crewSeen.CrewSurface = true
	end
end

local function crewArrived(r: any, leader: Player?, _residentId: string)
	local objectiveId = r.Tag
	local objective = if type(objectiveId) == "string" then Config.Find("Objectives", objectiveId) else nil
	if not objective or objective.Kind ~= "LostCrew" then
		return
	end
	local crew = crews[objective.Id]
	if crew then
		crew.State = "Home"
	end
	if objectives:Complete(objective.Id) then
		alertAll("Info", `{string.upper(objective.Name)}: HOME! +{objective.YearsPerCycle} YEARS PER CYCLE`)
		DeepService.CrewHome:Fire(objective.Id, leader)
	end
end

local function crewMemberLost(_rescueId: string, kind: string)
	if kind ~= "Crew" then
		return
	end
	for objectiveId in crewSeen do
		if not objectives:IsComplete(objectiveId) and #rescue:Tagged(objectiveId) == 0 then
			crewSeen[objectiveId] = nil
			local crew = crews[objectiveId]
			if crew then
				crew.State = "Lost"
			end
			local objective = Config.Get("Objectives", objectiveId)
			alertAll("Danger", `{string.upper(objective.Name)}: ALL OF THEM ARE LOST`)
		end
	end
end

-- Caves -------------------------------------------------------------------------------------------

-- The dug cell's back rock steps aside for the cave's mouth (the Entry's rock face stands there);
-- anything else in the opening stops colliding (the Mines' timber frame).
local function openMouth(c: Cave)
	local root = grid:Root()
	local dug = root and root:FindFirstChild("Dug")
	local model = dug and dug:FindFirstChild(`D:{c.Key}`)
	if not model or model:GetAttribute("CaveOpen") then
		return
	end
	model:SetAttribute("CaveOpen", true)
	local mouth = Deep.MouthCFrame(c.Floor, c.Column).Position
	local lo = Vector3.new(mouth.X - 7.5, mouth.Y + 0.5, mouth.Z - 1)
	local hi = Vector3.new(mouth.X + 7.5, mouth.Y + 12, mouth.Z + 4)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Floor" and part.Name ~= "FrontWall" then
			if part.Name == "BackRock" then
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
				part.CastShadow = false
				CollectionService:AddTag(part, CAMERA_IGNORE_TAG)
			elseif part.CanCollide then
				local half = part.Size / 2
				local cf = part.CFrame
				local extent = Vector3.new(
					math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z,
					math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z,
					math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
				)
				local pMin, pMax = cf.Position - extent, cf.Position + extent
				if pMin.X < hi.X and pMax.X > lo.X and pMin.Y < hi.Y and pMax.Y > lo.Y and pMin.Z < hi.Z and pMax.Z > lo.Z then
					part.CanCollide = false
				end
			end
		end
	end
end

local function grayPiece(spec: any): Model
	local model = Instance.new("Model")
	local lo, hi = spec.Box.Min, spec.Box.Max
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(hi[1] - lo[1], 1, hi[3] - lo[3])
	floor.CFrame = CFrame.new((lo[1] + hi[1]) / 2, -0.5, (lo[3] + hi[3]) / 2)
	floor.Color = Color3.fromRGB(70, 64, 60)
	floor.Material = Enum.Material.Slate
	floor.Parent = model
	model.PrimaryPart = floor
	model.WorldPivot = CFrame.new()
	return model
end

local function plug(c: Cave, at: CFrame)
	local source = art("Kit", "Kit_Rubble_Doorway")
	local model: Model
	if source then
		model = source:Clone()
		model:ScaleTo(PLUG_SCALE)
	else
		model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Name = "Rubble"
		p.Size = Vector3.new(14, 12, 3)
		p.Color = Color3.fromRGB(96, 88, 80)
		p.Material = Enum.Material.Slate
		p.PivotOffset = CFrame.new(0, -6, 0)
		p.Parent = model
		model.PrimaryPart = p
	end
	model.Name = "Plug"
	anchorAll(model)
	model:PivotTo(at)
	model.Parent = c.Folder
	local block = Instance.new("Part")
	block.Name = "PlugBlock"
	block.Anchored = true
	block.CanQuery = false
	block.CanTouch = false
	block.Transparency = 1
	block.Size = Vector3.new(15, 13, 2)
	block.CFrame = at * CFrame.new(0, 6.5, 0)
	CollectionService:AddTag(block, CAMERA_IGNORE_TAG)
	block.Parent = model
end

local function placePiece(c: Cave, placement: Deep.Placement, index: number, findChance: number): Piece
	local spec = Config.Get("CavePieces", placement.Piece)
	local source = art("Caves", spec.Asset)
	local model = if source then source:Clone() else grayPiece(spec)
	model.Name = `{index} {spec.Id}`
	model:SetAttribute("Piece", spec.Id)
	anchorAll(model)
	model:PivotTo(placement.CFrame)
	model.Parent = c.Folder
	local piece: Piece = {
		Index = index,
		Spec = spec,
		CFrame = placement.CFrame,
		Box = placement.Box,
		Model = model,
		Guards = 0,
		Posts = sockets(model, "^Spawn"),
		Woken = false,
	}
	for _, at in sockets(model, "^Light") do
		lightAt(model, at, LANTERN[c.Band] or LANTERN.Mines, t().LampRange, t().LampBrightness)
	end
	local era = eraNumber()
	for _, at in sockets(model, "^Find") do
		placeFind(c, Deep.RollFind(rng:NextNumber(), era, findChance), at)
	end
	local nestAt = sockets(model, "^Nest$")[1]
	if spec.Kind == "CrewPocket" and nestAt then
		-- the crew's guard (Section 12): a nest, and its monsters round it
		placeNest(c, nestAt)
		piece.Guards = t().NestBudget
		piece.Posts = { nestAt * CFrame.new(-5, 0, 2), nestAt * CFrame.new(5, 0, 2), nestAt * CFrame.new(0, 0, 5) }
	elseif nestAt then
		if rng:NextNumber() < t().NestChance then
			placeNest(c, nestAt)
			piece.Guards = t().NestBudget
			if #piece.Posts == 0 then
				piece.Posts = { nestAt * CFrame.new(-5, 0, 3), nestAt * CFrame.new(5, 0, 3) }
			end
		else
			placeFind(c, "Cache", nestAt)
		end
	end
	if piece.Guards == 0 and #piece.Posts > 0 and rng:NextNumber() < t().GuardChance then
		piece.Guards = t().GuardBudget
	end
	return piece
end

function DeepService:Caves(): number
	local n = 0
	for _ in caves do
		n += 1
	end
	return n
end

-- The cave (its dug cell's key) a position is in, if any.
--[[
	Where a Deep expedition radioing for help is cut off (Prompt 18), and how to say where: a piece of
	an open cave (not its mouth, a drop or a crew's pocket), on its floor; with no cave open, at the
	rock face of the bunker's deepest floor.
]]
function DeepService:DistressSpot(): (CFrame?, string?)
	local options = {}
	for _, c in caves do
		for _, piece in c.Pieces do
			local kind = piece.Spec.Kind
			if kind ~= "Entry" and kind ~= "Drop" and kind ~= "CrewPocket" then
				table.insert(options, { Cave = c, Piece = piece })
			end
		end
	end
	if #options > 0 then
		local pick = options[rng:NextInteger(1, #options)]
		local box = pick.Piece.Spec.Box
		local at = pick.Piece.CFrame * CFrame.new(0, 0, (box.Min[3] + box.Max[3]) / 2)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { pick.Cave.Folder }
		local hit = workspace:Raycast(at.Position + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
		if hit then
			at = CFrame.new(hit.Position) * at.Rotation
		end
		return at, `a cave off {Deep.Hint(pick.Cave.Floor, pick.Cave.Column)}`
	end
	local floor = grid:DeepestFloor()
	local t = Grid.Tuning()
	for column = 0, math.max(math.abs(t.ColumnMin), t.ColumnMax) do
		for _, c in (if column == 0 then { 0 } else { -column, column }) do
			if Grid.OnGrid(floor, c) and grid:State(floor, c) ~= "Rock" then
				local at = Grid.CellPosition(floor, c) + Vector3.new(0, 0, -t.CellDepth / 2 + 4)
				return CFrame.new(at), `the rock below the bunker ({Deep.Hint(floor, c)})`
			end
		end
	end
	return nil, nil
end

-- A Lost Crew's own call and where they were last heard from, for the Radio Room (Prompt 18), or nil when none is out.
function DeepService:CrewCall(): (string?, string?)
	local lost = {}
	for _, crew in lostCrews() do
		if crewLog(crew.Objective) then
			table.insert(lost, crew)
		end
	end
	if #lost == 0 then
		return nil, nil
	end
	local crew = lost[rng:NextInteger(1, #lost)]
	local id = crewLog(crew.Objective) :: string
	heard[id] = true
	return id, crew.Where
end

-- Plays a radio log (Config.RadioLogs) for a player, with a hint.
function DeepService:PlayLog(player: Player, id: string, hint: string?)
	playLog(player, id, hint)
end

function DeepService:CaveAt(position: Vector3): string?
	for key, c in caves do
		for _, piece in c.Pieces do
			if Deep.Inside(piece.Box, position) then
				return key
			end
		end
	end
	return nil
end

local function buildCave(floor: number, column: number)
	local key = Grid.Key(floor, column)
	if caves[key] then
		return
	end
	local band = Deep.Band(floor)
	if #Deep.Pieces(band, "Entry") == 0 then
		log:Info("no cave pieces for the %s yet: the cave at %s stays a dark mouth", band, key)
		return
	end
	local objectiveId = crewCells[key]
	local crew = if objectiveId then crews[objectiveId] else nil
	if crew and crew.State ~= "Hidden" then
		crew = nil
	end
	local plan = Deep.Plan(band, Deep.MouthCFrame(floor, column), rng, boxes, { Crew = crew ~= nil })
	if #plan.Pieces == 0 then
		-- another cave already fills the rock behind: the mouth stays a dark hole (still a breach point)
		log:Info("the rock behind %s is another cave's: no cave of its own", key)
		if crew then
			-- the crew can't be lost to that: they're in the dug cell, against the back wall
			local fake: Cave = { Key = key, Floor = floor, Column = column, Band = band, Folder = holder() :: any, Pieces = {}, Crew = objectiveId }
			trapCrew(fake, crew, nil)
		end
		return
	end
	local folder = Instance.new("Model")
	folder.Name = `Cave {key}`
	folder:SetAttribute("Cell", key)
	folder:SetAttribute("Band", band)
	folder.Parent = holder()
	local c: Cave = { Key = key, Floor = floor, Column = column, Band = band, Folder = folder, Pieces = {}, Crew = objectiveId }
	caves[key] = c
	local findChance = teamFindChance()
	local pocket: Piece? = nil
	for i, placement in plan.Pieces do
		local piece = placePiece(c, placement, i, findChance)
		table.insert(c.Pieces, piece)
		if piece.Spec.Kind == "CrewPocket" then
			pocket = piece
		end
	end
	for _, at in plan.Plugs do
		plug(c, at)
	end
	openMouth(c)
	dig:OpenCave(floor, column)
	if crew then
		trapCrew(c, crew, pocket)
		local last = c.Pieces[#c.Pieces]
		if not pocket and last then
			-- no room for their pocket: they're at the end of the cave, still guarded (Section 12)
			local nestAt = last.CFrame * CFrame.new(0, 0, -6)
			placeNest(c, nestAt)
			last.Guards = t().NestBudget
			last.Posts = { nestAt * CFrame.new(-5, 0, 2), nestAt * CFrame.new(5, 0, 2) }
			last.Woken = false
		end
	end
	set("Caves", DeepService:Caves())
	log:Info("a cave opened at %s (%s): %d pieces, %d plugs%s", key, band, #c.Pieces, #plan.Plugs, if crew then ", the Lost Crew" else "")
	DeepService.CaveOpened:Fire(key, band, #c.Pieces)
end

-- Where a cave position comes out into the bunker (MonsterService walks monsters through it).
local function caveExit(position: Vector3): Vector3?
	local key = DeepService:CaveAt(position)
	local c = if key then caves[key] else nil
	if not c then
		-- between pieces or just outside one: the nearest cave's mouth
		local best, bestDistance = nil, math.huge
		for _, other in caves do
			for _, piece in other.Pieces do
				local d = (nearestOnBox(piece.Box, position) - position).Magnitude
				if d < bestDistance then
					best, bestDistance = other, d
				end
			end
		end
		c = best
	end
	return if c then Deep.MouthPoint(c.Floor, c.Column) else nil
end

-- Players in the Deep: their own light, and falls ------------------------------------------------

local function lightTick()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local light = root:FindFirstChild("DeepLight")
			local inDeep = Surface.Zone(root.Position) == "Deep"
			if inDeep and not light then
				local l = Instance.new("PointLight")
				l.Name = "DeepLight"
				l.Color = OWN_LIGHT
				l.Shadows = true
				l.Parent = root
				light = l
			end
			if light and light:IsA("PointLight") then
				light.Enabled = inDeep
				light.Range = Deep.LightRange(classValue(player, "LightRadius"))
				light.Brightness = t().LightBrightness
			end
		end
	end
end

-- Falls (Section 12: drops): the server watches characters fall (a Humanoid's states are its
-- client's, so it reads the root's speed) and land; a drop in the Deep past FallDamageFrom hurts.
local FALLING = -8 -- studs a second down: falling, not walking down a slope
local falls: { [Player]: { Top: number, At: Vector3 } } = {}

local function fallStep()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local f = falls[player]
		if not root then
			falls[player] = nil
		else
			local vy = root.AssemblyLinearVelocity.Y
			if vy < FALLING then
				if not f then
					falls[player] = { Top = root.Position.Y, At = root.Position }
				end
			elseif f and math.abs(vy) < 2 then
				falls[player] = nil
				local drop = f.Top - root.Position.Y
				local flat = Vector3.new(root.Position.X - f.At.X, 0, root.Position.Z - f.At.Z).Magnitude
				-- only in the Deep, and not a teleport (DevTools, a respawn)
				if drop > 0 and drop < 120 and flat < 80 and Surface.Zone(root.Position) == "Deep" then
					local damage = Deep.FallDamage(drop, (classValue(player, "NoFallDamage") or 0) ~= 0)
					local c = combat:PlayerCombatant(player)
					if damage > 0 and c and alive(player) then
						local done = combat:Damage(c.Id, damage, nil, "fell")
						log:Info("%s fell %.1f studs in the Deep: %d damage", player.Name, drop, done)
					end
				end
			end
		end
	end
end

-- Loop --------------------------------------------------------------------------------------------

local function loop()
	local last = os.clock()
	while true do
		task.wait(1)
		local dt = math.min(os.clock() - last, 3)
		last = os.clock()
		for name, fn in { wake = wakeTick, light = lightTick, thaw = function()
			-- the Cryo Bay works like any room: while the clock runs, at its speed (EconomyService)
			if clock:IsRunning() then
				thawTick(dt * clock:TimeScale())
			end
		end } do
			local ok, err = pcall(fn)
			if not ok then
				log:Warn("%s: %s", name, tostring(err))
			end
		end
	end
end

local function onGridChanged()
	for _, c in caves do
		openMouth(c) -- a rebuilt dug cell brings its back rock back
	end
end

local function clear()
	for _, n in nests do
		breaches:SetExtraPoint(`CN:{n.Id}`, nil)
	end
	table.clear(nests)
end

-- DevTools ----------------------------------------------------------------------------------------

local function describe(): string
	local lines = { `{DeepService:Caves()} caves, {#boxes} pieces in the Deep, cryo pods waiting {pods} (thaw {string.format("%.2f", thaw)}/{t().ThawPoints})` }
	for key, c in caves do
		local kinds = {}
		for _, piece in c.Pieces do
			table.insert(kinds, `{piece.Spec.Kind}{if piece.Guards > 0 then (if piece.Woken then "*" else "+") else ""}`)
		end
		table.insert(lines, `cave {key} ({c.Band}): {table.concat(kinds, " ")}{if c.Crew then ` · {c.Crew}` else ""}`)
	end
	local counts: { [string]: number } = {}
	for _, f in finds do
		counts[f.Kind] = (counts[f.Kind] or 0) + 1
	end
	local parts = {}
	for kind, n in counts do
		table.insert(parts, `{kind} {n}`)
	end
	table.sort(parts)
	local nestCount = 0
	for _ in nests do
		nestCount += 1
	end
	table.insert(lines, `finds: {if #parts > 0 then table.concat(parts, ", ") else "none"} · cave nests {nestCount}`)
	return table.concat(lines, "\n")
end

local function describeCrews(): string
	local lines = {}
	for _, objective in Config.All("Objectives") do
		if objective.Kind == "LostCrew" then
			local crew = crews[objective.Id]
			local members = rescue:Tagged(objective.Id)
			local states = {}
			for _, r in members do
				table.insert(states, r.State)
			end
			local where = if crew then `{Grid.Key(crew.Floor, crew.Column)} ({Deep.Hint(crew.Floor, crew.Column)}), {crew.State}`
				elseif objective.Id == "CrewSurface" then (surface:CrewWhere() or "the camp's crew is out")
				else "not placed (its band has no cave pieces yet)"
			table.insert(lines, `{if objectives:IsComplete(objective.Id) then "done" else "    "} {objective.Id}: {where}{if #states > 0 then ` · {table.concat(states, ", ")}` else ""}`)
		end
	end
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("deep", {
		Description = "The Deep: caves (pieces, + guards asleep, * woken), finds, cave nests, cryo pods (Prompt 17).",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("deep.cave", {
		Description = "Dig a rock cell now and break into a cave behind it (or build the cave behind a dug cave opening).",
		Usage = "deep.cave <floor> <column>",
		Run = function(player, args): string?
			local floor, column = tonumber(args[1]), tonumber(args[2])
			if not floor or not column then
				return "usage: deep.cave <floor> <column>"
			end
			if grid:State(floor, column) == "Rock" then
				if not crewCells[Grid.Key(floor, column)] then
					dig:SetRoll(floor, column, "CaveOpening")
				end
				local ok, why = dig:DigNow(floor, column, "DevTools", player)
				if not ok then
					return `can't dig: {why}`
				end
			else
				buildCave(floor, column)
			end
			return describe()
		end,
	})
	dev:Register("deep.tp", {
		Description = "Go into the cave behind a cell (to its first piece's end).",
		Usage = "deep.tp <floor> <column> [piece]",
		Run = function(player, args): string?
			local c = caves[Grid.Key(tonumber(args[1]) or 0, tonumber(args[2]) or 0)]
			local p = player or Players:GetPlayers()[1]
			local root = if p then rootOf(p) else nil
			if not c or not root then
				return "usage: deep.tp <floor> <column> [piece] (a cave that is open)"
			end
			local piece = c.Pieces[math.clamp(tonumber(args[3]) or 1, 1, #c.Pieces)]
			local at = piece.CFrame * CFrame.new(0, 3, -8)
			root.CFrame = CFrame.lookAt(at.Position, (at * CFrame.new(0, 0, -5)).Position)
			return `in {piece.Spec.Id} of the cave at {c.Key}`
		end,
	})
	dev:Register("deep.find", {
		Description = "Put a find in front of you: OreVein, Cache, RadioLog, GlowshardChest, TrappedMiner, CryoPod.",
		Usage = "deep.find <kind>",
		Run = function(player, args): string?
			local p = player or Players:GetPlayers()[1]
			local root = if p then rootOf(p) else nil
			local kind = tostring(args[1] or "")
			if not root or not (FIND_PROMPT[kind] or kind == "TrappedMiner" or kind == "CryoPod") then
				return "usage: deep.find <OreVein|Cache|RadioLog|GlowshardChest|TrappedMiner|CryoPod>"
			end
			local key = DeepService:CaveAt(root.Position)
			local c = if key then caves[key] else nil
			local fake: Cave = c or { Key = "dev", Floor = 1, Column = 0, Band = "Mines", Folder = holder() :: any, Pieces = {}, Crew = nil }
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
			local at = CFrame.lookAt(root.Position + look * 6 - Vector3.new(0, 3, 0), root.Position - Vector3.new(0, 3, 0))
			local id = placeFind(fake, kind, at)
			return `{kind}: {id or "nothing"}`
		end,
	})
	dev:Register("cryo.add", {
		Description = "Cryo pods home and waiting to thaw, as if hauled (the Cryo Bay unlocks).",
		Usage = "cryo.add [n]",
		Run = function(_player, args): string?
			local n = math.max(math.floor(tonumber(args[1]) or 1), 0)
			pods += n
			set("CryoPods", pods)
			unlockCryo()
			return describe()
		end,
	})
	dev:Register("radiolog", {
		Description = "Play a radio log to you (the next one, or by id).",
		Usage = "radiolog [id]",
		Run = function(player, args): string?
			local p = player or Players:GetPlayers()[1]
			if not p then
				return "no player"
			end
			local id, hint = tostring(args[1] or ""), nil
			if not Config.Find("RadioLogs", id) then
				local chosen, h = chooseLog()
				id, hint = chosen or "", h
			else
				local objective = Config.Get("RadioLogs", id).Crew
				for _, crew in lostCrews() do
					if crew.Objective == objective then
						hint = crew.Where
					end
				end
			end
			if id == "" then
				return "no radio logs"
			end
			playLog(p, id, hint)
			return `{id}{if hint then ` · {hint}` else ""}`
		end,
	})
	dev:Register("crews", {
		Description = "The Lost Crews: where each is, and how they are.",
		Run = function(): string?
			return describeCrews()
		end,
	})
end

-- Lifecycle ---------------------------------------------------------------------------------------

function DeepService:Init(registry)
	grid = registry.BunkerGrid
	clock = registry.CycleClock
	director = registry.RunDirector
	session = registry.SessionService
	dig = registry.DigService
	inventory = registry.InventoryService
	rescue = registry.RescueService
	monsterService = registry.MonsterService
	combat = registry.CombatService
	residents = registry.ResidentService
	brain = registry.ResidentBrain
	economy = registry.EconomyService
	builds = registry.BuildService
	objectives = registry.ObjectiveService
	breaches = registry.BreachService
	profiles = registry.ProfileService
	surface = registry.SurfaceService
	set = RunState.Writer("DeepService")
	registerCommands(registry.DevService)
end

function DeepService:Start()
	set("Caves", 0)
	set("CryoPods", 0)
	holder()
	dig.FeatureAdded:Connect(function(kind: string, floor: number, column: number)
		if kind == "CaveOpening" and caves[Grid.Key(floor, column)] then
			dig:OpenCave(floor, column) -- DevTools put the opening back: the cave is already there
		elseif kind == "CaveOpening" then
			local ok, err = pcall(buildCave, floor, column)
			if not ok then
				log:Error("the cave at %s: %s", Grid.Key(floor, column), tostring(err))
			end
		end
	end)
	dig:SetResultHandler("CryoPod", function(floor: number, column: number, _finisher: Player?): string
		DeepService:PlacePod(Grid.CellCFrame(floor, column) * CFrame.new(-5, 0, 4) * CFrame.Angles(0, math.rad(15), 0), "Dug")
		return "A CRYO POD! CARRY IT HOME TO THE HALL OR A STORAGE ROOM"
	end)
	inventory:SetDelivery("CryoPod", function(player: Player, _kind: string): { Loot.Drop }
		pods += 1
		set("CryoPods", pods)
		local bays = #grid:RoomsOfType("CryoBay")
		alertAll("Info", `{string.upper(player.DisplayName)} BROUGHT A CRYO POD HOME ({pods} WAITING): `
			.. (if bays > 0 then "THE CRYO BAY WILL THAW IT" else "BUILD A CRYO BAY TO THAW IT"))
		return {}
	end)
	inventory:SetSpecial("RadioLog", function(player: Player, count: number): number
		local id, hint = chooseLog()
		if id then
			playLog(player, id, hint)
		end
		return if id then count else 0
	end)
	inventory:SetSpecial("Glowshards", function(player: Player, count: number): number
		return payChest(player, count)
	end)
	rescue:SetArrival("Crew", crewArrived)
	rescue.Lost:Connect(crewMemberLost)
	monsterService:SetCaveExit(caveExit)
	combat.Damaged:Connect(function(id: string, _amount: number, source: string?)
		if source and nests[id] then
			nestHits[id] = source
		end
	end)
	combat.Died:Connect(function(id: string)
		local n = nests[id]
		if not n then
			return
		end
		local killer: Player? = nil
		local source = nestHits[id]
		for _, player in Players:GetPlayers() do
			if `P{player.UserId}` == source then
				killer = player
			end
		end
		destroyNest(n, killer)
	end)
	clock.CycleStarted:Connect(function(cycle: number)
		local n = 0
		for _ in nests do
			n += 1
		end
		if cycle > 1 and n > 0 then
			dig:AddDisturbance(n * Dig.Tuning().NestPerCycle, "CaveNests")
		end
	end)
	grid.Changed:Connect(onGridChanged)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(fallStep)
		if not ok then
			log:Warn("falls: %s", tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		falls[player] = nil
	end)
	director.RunEnded:Connect(clear)
	local ok, err = pcall(setupCrews)
	if not ok then
		log:Error("the Lost Crews: %s", tostring(err))
	end
	task.spawn(loop)
	local placed = 0
	for _ in crews do
		placed += 1
	end
	log:Info("the Deep ready: %d cave pieces, %d Lost Crews hidden in the rock", #Config.Ids("CavePieces"), placed)
end

return DeepService
