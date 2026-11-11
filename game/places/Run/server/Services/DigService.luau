--!strict
--[[
	DigService: digging, what a dug cell holds, Push Deeper, the Drill Bay's queue and
	Disturbance (bible Sections 6, 7, 10 and 14). Run place only; Prompt 14. The arithmetic is
	Shared.Rules.Dig and Shared.Rules.Loot; the numbers are Config.DepthBands, Config.DigResults,
	Config.LootTables, Tuning.Digging and Tuning.Disturbance (provisional ones marked there).

	* Digging (Section 6): every Rock cell left of, right of or below an open cell has a dig
	  prompt at each face it can be dug from (Rules.Dig.Faces): on the wall line for a side, on
	  the floor of the cell above for digging down. Players who carry a Drill or a Pickaxe hold
	  Interact there (the prompt only shows to them); the cell takes its band's DigSeconds, the
	  Driller digs twice as fast (DigSpeed) and players on one cell stack. Progress stays when
	  they let go. The prompt's Progress attribute drives its gauge.
	* The Drill Bay (Sections 6 and 7): any player marks rock cells for its queue in the Command
	  View (MarkDig, no vote). Each working Drill Bay digs the first queued cell it can at
	  ResidentDigMultiplier of a player for each unit of its crew's output.
	* Push Deeper (Section 6): the first cell of a new band (floors 4, 7 and 10) needs a vote.
	  Trying to dig past RunState.DigLimit opens it (VoteService, Kind PushDeeper; solo runs pass
	  at once); a pass moves DigLimit to the band's last floor.
	* When a cell opens (BunkerGrid:Dig): Disturbance rises (DisturbancePerCell, DigDisturbance:
	  the Driller's level 3, Deep Charges), the cell's roll is applied (Rules.Dig.Roll, the same
	  all run, so the Driller's hints match), and now and then its passage caves in
	  (CaveInChance; Section 10: digging causes cave-ins).
	  * Ore pocket: the band's ore (Loot OrePocket; the Driller's DugOre) into the stockpile.
	  * Cave opening: a dark cave mouth in the back wall and a breach point (Section 10). The cave
	    behind it is Prompt 17's.
	  * Cache: a crate; holding Interact opens it: resources into the stockpile, throwables to
	    the player who opened it (Loot Cache; gear and radio logs wait for their prompts).
	  * Nest: monsters pour out at once (ThreatDirector:Burst), it is a breach point while it
	    lives and raises Disturbance every cycle (NestPerCycle); destroying it (it is a monster
	    combatant, NestHealth) pays Loot Nest and drops Disturbance by NestDestroyed.
	  * Cryo pod (Era II, Prompt 17): the handler DeepService sets (SetResultHandler) puts a pod in
	    the cell, a big find to carry home.
	  * Hazard pockets (gas and water, Prompt 23) count as Empty until their system exists.
	  A few cells hold a fixed result this run (SetRoll, Prompt 17: the Lost Crews' caves); RunState
	  DigOverrides carries them so the Driller's hints match.
	  Nothing is built on a cell with a nest, a cache or a cave opening (BuildService:SetCellCheck).
	* Disturbance (Section 10): RunState.Disturbance 0 to 100. Digging, explosives
	  (WeaponService.Exploded, Explosive) and living nests raise it; it falls DecayPerCycle each
	  cycle and NestDestroyed when a nest is destroyed. Crossing ExtraBreachAt brings an extra
	  small breach (ThreatDirector:ExtraBreach); reaching TremorAt is a Tremor: a full breach wave
	  at once (ThreatDirector:Tremor), a cave-in (Section 10: Tremors cause cave-ins), the camera
	  shakes (RunState.TremorAt), and the meter drops to AfterTremor.
	* The Command View sees digging in front of each rock cell being dug or queued: a hazard
	  frame and a bar that fills with progress.

	Replication: the Digs collection, "S:<floor>,<column>" -> { Floor, Column, Progress, Diggers,
	Queue, Bay, Vote } for cells being dug or queued, "F:<floor>,<column>" -> { Floor, Column,
	Kind } for what dug cells hold (CaveOpening, Cache, Nest). RunState Disturbance, DigLimit,
	DigSeed, DigOverrides, TremorAt and Nests.

	API:
		DigService:Disturbance(): number
		DigService:AddDisturbance(amount, source)        -- Overdrive, Breaching Charges (Prompt 20)
		DigService:DigNow(floor, column, cause, player?): (boolean, string?) -- abilities, DevTools
		DigService:Mark(floor, column, on, player?): (boolean, string?)
		DigService:SetModifier(source, key, value?)      -- DigSpeed, DigDisturbance (team-wide)
		DigService:Feature(floor, column): string?
		DigService:SetRoll(floor, column, result?)        -- fix a cell's roll this run (Prompt 17)
		DigService:SetResultHandler(result, fn?)          -- fn(floor, column, finisher): text (Prompt 17's cryo pods)
		DigService:OpenCave(floor, column)                -- the cave behind is built: the mouth's stand-in goes
		DigService.Dug: Signal<number, number, string, string, Player?> -- floor, column, result, cause, who finished it
		DigService.FeatureAdded: Signal<string, number, number> -- kind, floor, column (Prompt 17 builds caves on it)
	Dev: digs, dig, dig.roll, dig.mark, disturbance, disturbance.add, tremor, pushdeeper, nest, cache, cave.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Dig = require(Shared.Rules.Dig)
local Disasters = require(Shared.Rules.Disasters)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("DigService")

local DigService = {
	Name = "DigService",
	Dependencies = {
		"BunkerGrid", "CycleClock", "RunDirector", "SessionService", "ReplicationService", "EconomyService", "WeaponService",
		"CombatService", "VoteService", "BuildService", "BreachService", "ThreatDirector", "DisasterService", "InventoryService",
		"DevService",
	},
	Dug = Signal.new() :: Signal.Signal<number, number, string, string, Player?>,
	FeatureAdded = Signal.new() :: Signal.Signal<string, number, number>,
}

-- Results whose systems exist; the rest count as Empty (hazard pockets: Prompt 23).
local AVAILABLE: { [string]: boolean } = {
	Empty = true, OrePocket = true, CaveOpening = true, Cache = true, Nest = true, CryoPod = true,
	HazardPocket = true, -- Prompt 23: gas or water bursts out (DisasterService:HazardPocket)
}
-- Loot specials nothing hands out yet: gear (Prompt 26), blueprints (19), recruits (18). Radio logs
-- go to InventoryService's handler (Prompt 17).
local SKIP_SPECIALS: { [string]: boolean } = { Gear = true, Recruit = true, Glowshards = true } -- blueprints: Prompt 19 (DraftService)
local CAMERA_IGNORE_TAG = "CameraIgnore"
local MARK_COLOR = Color3.fromHex("#F2C14E") -- Hazard Yellow
local FILL_COLOR = Color3.fromHex("#E8743B") -- Signal Orange
local MAX_QUEUE = 12

type Site = {
	Key: string,
	Floor: number,
	Column: number,
	Progress: number,
	Diggers: { [Player]: number }, -- player -> speed
	Bay: boolean, -- a Drill Bay is digging it this tick
	Sent: string,
}
type Feature = {
	Key: string,
	Floor: number,
	Column: number,
	Kind: string, -- "CaveOpening" | "Cache" | "Nest"
	Model: Model?,
	CombatId: string?,
}

local grid: any = nil
local clock: any = nil
local director: any = nil
local session: any = nil
local economy: any = nil
local weapons: any = nil
local combat: any = nil
local votes: any = nil
local builds: any = nil
local breaches: any = nil
local threat: any = nil
local disasters: any = nil
local inventory: any = nil
local collection: any = nil
local set: (string, any) -> () = function() end

local rng = Random.new()
local sites: { [string]: Site } = {}
local queue: { string } = {}
local features: { [string]: Feature } = {}
local disturbance = 0
local limit = 3
local seed = 0
local votesOpen: { [number]: string } = {} -- a band's first floor -> its vote id
local retryAt: { [number]: number } = {}
local modifiers: { [string]: { [string]: number } } = {} -- key -> source -> value
local overrides: Dig.Overrides = {} -- cells whose roll is fixed this run (Prompt 17)
local resultHandlers: { [string]: (number, number, Player?) -> string } = {}
local prompts: { [string]: { Part: BasePart, Prompt: ProximityPrompt, Key: string } } = {} -- "<key>|<side>"
local markers: { [string]: Model } = {}
local folder: Folder? = nil

-- Helpers -------------------------------------------------------------------------------------------

local function now(): number
	return workspace:GetServerTimeNow()
end

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function eraNumber(): number
	return table.find(Config.Ids("Eras"), clock:Era()) or 1
end

local function teamValue(key: string): number
	local value = 1
	for _, v in modifiers[key] or {} do
		value *= v
	end
	return value
end

local function classValue(player: Player?, key: string): number
	if not player then
		return 1
	end
	return Modifiers.PlayerValue(player, key) or 1 -- at the player's class level (Prompt 20)
end

local function holder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local root = grid:Root()
	if not root then
		return nil
	end
	local found = root:FindFirstChild("Digging")
	if not found then
		found = Instance.new("Folder")
		found.Name = "Digging"
		found.Parent = root
	end
	folder = found :: Folder
	return folder
end

local function art(category: string, name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local f = assets and assets:FindFirstChild(category)
	local found = f and f:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

local function bandName(floor: number): string
	return string.upper(Grid.BandOf(floor).Name)
end

local function where(floor: number, column: number): string
	return `FLOOR {floor} · COLUMN {column}`
end

local function inRun(): boolean
	return director:Phase() == "Playing"
end

-- Disturbance --------------------------------------------------------------------------------------

local function tremorCaveIn()
	local bunker = grid:Bunker()
	local doorways = Disasters.Doorways(bunker)
	local deepest = grid:DeepestFloor()
	local near = {}
	for _, d in doorways do
		if d.Floor >= deepest - 1 then
			table.insert(near, d)
		end
	end
	local list = if #near > 0 then near else doorways
	if #list == 0 then
		return
	end
	local pick = list[rng:NextInteger(1, #list)]
	disasters:CaveIn(pick.Floor, pick.Column, pick.Side, "Tremor")
end

local function setDisturbance(value: number, source: string)
	local before = disturbance
	disturbance = math.clamp(value, 0, Dig.DisturbanceTuning().Max)
	local extra, tremor = Dig.Crossed(before, disturbance)
	if tremor then
		disturbance = Dig.AfterTremor()
		log:Info("TREMOR (%s): Disturbance %.0f -> %.0f", source, before, disturbance)
		set("TremorAt", now())
		announce("Danger", "TREMOR! THE DEEP IS AWAKE: MONSTERS ARE BREAKING IN EVERYWHERE")
		if inRun() then
			local ok, err = pcall(function()
				threat:Tremor()
				tremorCaveIn()
			end)
			if not ok then
				log:Warn("tremor: %s", tostring(err))
			end
		end
	elseif extra then
		log:Info("Disturbance passed %d (%s): an extra breach", Dig.DisturbanceTuning().ExtraBreachAt, source)
		if inRun() then
			local ok, err = pcall(function()
				threat:ExtraBreach()
			end)
			if not ok then
				log:Warn("extra breach: %s", tostring(err))
			end
		end
	end
	set("Disturbance", math.floor(disturbance * 10 + 0.5) / 10)
end

function DigService:Disturbance(): number
	return disturbance
end

function DigService:AddDisturbance(amount: number, source: string)
	setDisturbance(Dig.AddDisturbance(disturbance, amount), source)
end

function DigService:SetModifier(source: string, key: string, value: number?)
	modifiers[key] = modifiers[key] or {}
	modifiers[key][source] = value
end

-- Sites and the Command View's marks ----------------------------------------------------------------

local function siteOf(key: string): Site?
	return sites[key]
end

local function getSite(floor: number, column: number): Site
	local key = Grid.Key(floor, column)
	local site = sites[key]
	if not site then
		site = { Key = key, Floor = floor, Column = column, Progress = 0, Diggers = {}, Bay = false, Sent = "" }
		sites[key] = site
	end
	return site
end

local function diggerCount(site: Site): number
	local n = 0
	for _ in site.Diggers do
		n += 1
	end
	return n
end

local function updateMarker(site: Site?, key: string)
	local floor, column = Grid.Parse(key)
	local queued = table.find(queue, key)
	local show = site ~= nil and (site.Progress > 0 or diggerCount(site) > 0 or site.Bay) or queued ~= nil
	local marker = markers[key]
	if not show or not floor or not column then
		if marker then
			marker:Destroy()
			markers[key] = nil
		end
		return
	end
	local parent = holder()
	if not parent then
		return
	end
	if not marker then
		local model = Instance.new("Model")
		model.Name = `Mark_{key}`
		local cell = Grid.CellPosition(floor, column)
		local pitch = Grid.Pitch()
		local t = Grid.Tuning()
		local z = cell.Z + pitch.Z / 2 + 1.2 -- in front of the rock face, where the Command View looks
		local w, h = t.CellWidth - 4, t.CellHeight - 3
		local centre = Vector3.new(cell.X, cell.Y + t.CellHeight / 2, z)
		local function bar(name: string, size: Vector3, at: Vector3, color: Color3)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = color
			p.Size = size
			p.Position = at
			CollectionService:AddTag(p, CAMERA_IGNORE_TAG)
			p.Parent = model
			return p
		end
		bar("Top", Vector3.new(w, 0.5, 0.3), centre + Vector3.new(0, h / 2, 0), MARK_COLOR)
		bar("Bottom", Vector3.new(w, 0.5, 0.3), centre - Vector3.new(0, h / 2, 0), MARK_COLOR)
		bar("Left", Vector3.new(0.5, h, 0.3), centre - Vector3.new(w / 2, 0, 0), MARK_COLOR)
		bar("Right", Vector3.new(0.5, h, 0.3), centre + Vector3.new(w / 2, 0, 0), MARK_COLOR)
		local fill = bar("Fill", Vector3.new(0.1, 1.6, 0.35), centre - Vector3.new(w / 2 - 0.05, h / 2 - 1.6, 0), FILL_COLOR)
		fill:SetAttribute("Left", (centre - Vector3.new(w / 2 - 0.5, h / 2 - 1.6, 0)))
		fill:SetAttribute("Width", w - 1)
		model:SetAttribute("Cell", key)
		model.Parent = parent
		markers[key] = model
		marker = model
	end
	local fill = (marker :: Model):FindFirstChild("Fill") :: BasePart?
	if fill then
		local progress = if site then site.Progress else 0
		local width = (fill:GetAttribute("Width") :: number?) or 20
		local left = fill:GetAttribute("Left") :: Vector3?
		local length = math.max(width * progress, 0.1)
		fill.Size = Vector3.new(length, fill.Size.Y, fill.Size.Z)
		if left then
			fill.Position = left + Vector3.new(length / 2, 0, 0)
		end
		fill.Transparency = if progress > 0 then 0 else 1
	end
end

local function publishSite(key: string)
	local site = siteOf(key)
	local queued = table.find(queue, key)
	local floor, column = Grid.Parse(key)
	if not floor or not column then
		return
	end
	local band = Grid.BandOf(floor)
	local vote = votesOpen[band.Floors.From] ~= nil and Dig.NeedsVote(floor, limit)
	if not site and not queued then
		collection:Remove(`S:{key}`)
	else
		local progress = if site then math.floor(site.Progress * 100) / 100 else 0
		local diggers = if site then diggerCount(site) else 0
		local bay = site ~= nil and site.Bay
		local sent = `{progress}|{diggers}|{queued or 0}|{bay}|{vote}`
		if not site or site.Sent ~= sent then
			collection:Set(`S:{key}`, {
				Floor = floor, Column = column, Progress = progress, Diggers = diggers, Queue = queued, Bay = bay, Vote = vote,
			})
			if site then
				site.Sent = sent
			end
		end
	end
	-- the prompts' gauges and words
	for _, entry in prompts do
		if entry.Key == key then
			entry.Prompt:SetAttribute("Progress", if site then site.Progress else 0)
		end
	end
	updateMarker(site, key)
end

local function dropSite(key: string)
	sites[key] = nil
	local index = table.find(queue, key)
	if index then
		table.remove(queue, index)
		for _, other in queue do
			publishSite(other)
		end
	end
	publishSite(key)
end

function DigService:Mark(floor: number, column: number, on: boolean, player: Player?): (boolean, string?)
	local key = Grid.Key(floor, column)
	if not Grid.OnGrid(floor, column) or grid:State(floor, column) ~= "Rock" then
		return false, "Only rock can go on the dig queue."
	end
	local index = table.find(queue, key)
	if on then
		if index then
			return true, nil
		end
		if #queue >= MAX_QUEUE then
			return false, `The dig queue is full ({MAX_QUEUE} cells).`
		end
		table.insert(queue, key)
		log:Info("%s queued %s (%d in the queue)", if player then player.Name else "DevTools", key, #queue)
	else
		if not index then
			return true, nil
		end
		table.remove(queue, index)
		log:Info("%s took %s off the queue", if player then player.Name else "DevTools", key)
	end
	for _, other in queue do
		publishSite(other)
	end
	publishSite(key)
	return true, nil
end

-- Features: what dug cells hold -----------------------------------------------------------------------

local function publishFeature(f: Feature?, key: string)
	if f then
		collection:Set(`F:{key}`, { Floor = f.Floor, Column = f.Column, Kind = f.Kind })
	else
		collection:Remove(`F:{key}`)
	end
	local nests = 0
	for _, other in features do
		if other.Kind == "Nest" then
			nests += 1
		end
	end
	set("Nests", nests)
end

-- Monsters come out in front of the cave mouth or the nest's maw (the back of the cell is -Z).
local function breachPoint(f: Feature, kind: string): any
	local cell = Grid.CellPosition(f.Floor, f.Column)
	local out = cell + Vector3.new(0, 0.5, if kind == "Nest" then -2.5 else -6)
	return {
		Id = `{if kind == "Nest" then "N" else "O"}:{f.Key}`,
		Kind = kind,
		RoomId = nil,
		Floor = f.Floor,
		Column = f.Column,
		Weight = 1,
		Dark = false,
		At = CFrame.lookAt(out, out + Vector3.new(0, 0, 1)),
		Source = cell + Vector3.new(0, 3, -13),
	}
end

local function placeModel(f: Feature, source: Model?, offset: CFrame): Model
	local model: Model
	if source then
		model = source:Clone()
	else
		model = Instance.new("Model")
	end
	model.Name = `{f.Kind}_{f.Key}`
	model:SetAttribute("Cell", f.Key)
	model:SetAttribute("Feature", f.Kind)
	local parent = holder()
	model.Parent = parent
	if #model:GetChildren() == 0 then
		-- graybox until the art arrives
		local p = Instance.new("Part")
		p.Name = "Graybox"
		p.Size = if f.Kind == "Nest" then Vector3.new(7, 5, 6) elseif f.Kind == "Cache" then Vector3.new(3, 2.4, 2.4)
			else Vector3.new(10, 9, 1)
		p.Color = if f.Kind == "Nest" then Color3.fromHex("#6E4766") elseif f.Kind == "Cache" then Color3.fromHex("#5E6A44")
			else Color3.fromHex("#1B2A3A")
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.Parent = model
		model.PrimaryPart = p
		p.CFrame = Grid.CellCFrame(f.Floor, f.Column) * offset * CFrame.new(0, p.Size.Y / 2, 0)
		model.WorldPivot = Grid.CellCFrame(f.Floor, f.Column) * offset
	else
		model:PivotTo(Grid.CellCFrame(f.Floor, f.Column) * offset)
		if not model.PrimaryPart then
			-- the biggest part is the root (CombatService registers a nest by it)
			local best, volume = nil, 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Size.X * part.Size.Y * part.Size.Z > volume then
					best, volume = part, part.Size.X * part.Size.Y * part.Size.Z
				end
			end
			model.PrimaryPart = best
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			if f.Kind ~= "Nest" then
				part.CanCollide = false
			end
		end
	end
	return model
end

local function removeFeature(key: string, how: string)
	local f = features[key]
	if not f then
		return
	end
	features[key] = nil
	if f.Kind == "CaveOpening" then
		breaches:SetExtraPoint(`O:{key}`, nil)
	elseif f.Kind == "Nest" then
		breaches:SetExtraPoint(`N:{key}`, nil)
		if f.CombatId then
			combat:Unregister(f.CombatId)
		end
	end
	if f.Model then
		f.Model:Destroy()
	end
	publishFeature(nil, key)
	log:Info("%s at %s gone (%s)", f.Kind, key, how)
end

local function giveDrops(drops: { Loot.Drop }, player: Player?, why: string): { Loot.Drop }
	local given: { Loot.Drop } = {}
	for _, drop in drops do
		if drop.Resource then
			local added = economy:Add(drop.Resource, drop.Count, why)
			if added and added > 0 then
				table.insert(given, { Resource = drop.Resource, Count = added })
			end
		elseif drop.Item and player then
			local took = weapons:GiveThrowable(player, drop.Item, drop.Count)
			if took > 0 then
				table.insert(given, { Item = drop.Item, Count = took })
			end
		elseif drop.Special and player then
			-- a radio log plays for the player who found it (InventoryService's handlers, Prompt 17)
			local took = inventory:GiveSpecial(player, drop.Special, drop.Count)
			if took > 0 then
				table.insert(given, { Special = drop.Special, Count = took })
			end
		end
	end
	return given
end

local function openCache(f: Feature, player: Player)
	if features[f.Key] ~= f then
		return
	end
	local band = Grid.BandOf(f.Floor)
	local drops = Loot.Roll("Cache", rng, { BandOre = band.Ore, Skip = SKIP_SPECIALS })
	local given = giveDrops(drops, player, `cache {f.Key}`)
	removeFeature(f.Key, "Opened")
	announce("Info", `{string.upper(player.DisplayName)} OPENED THE CACHE: {if #given > 0 then Loot.Text(given) else "NOTHING LEFT IN IT"}`)
end

local function destroyNest(f: Feature, killer: Player?)
	if features[f.Key] ~= f then
		return
	end
	local band = Grid.BandOf(f.Floor)
	local drops = Loot.Roll("Nest", rng, { BandOre = band.Ore, Skip = SKIP_SPECIALS })
	local given = giveDrops(drops, killer, `nest {f.Key}`)
	f.Model = nil -- CombatService dissolves a dead combatant's model itself
	f.CombatId = nil
	removeFeature(f.Key, "Destroyed")
	DigService:AddDisturbance(-Dig.DisturbanceTuning().NestDestroyed, "NestDestroyed")
	announce("Info", `THE NEST IS DESTROYED: {if #given > 0 then Loot.Text(given) else "NOTHING"} · DISTURBANCE -{Dig.DisturbanceTuning().NestDestroyed}`)
end

local function addFeature(kind: string, floor: number, column: number): Feature
	local key = Grid.Key(floor, column)
	removeFeature(key, "Replaced")
	local f: Feature = { Key = key, Floor = floor, Column = column, Kind = kind, Model = nil, CombatId = nil }
	features[key] = f
	local depth = Grid.Tuning().CellDepth
	if kind == "CaveOpening" then
		-- 2 studs off the back wall: the dug cell's rock face bulges up to 2 studs into the room
		f.Model = placeModel(f, art("Kit", "Kit_CaveMouth"), CFrame.new(0, 0, depth / 2 - 2))
		breaches:SetExtraPoint(`O:{key}`, breachPoint(f, "Cave"))
	elseif kind == "Cache" then
		-- towards the back and to the right, clear of the dug cells' dressing (the Mines' ore cart)
		local model = placeModel(f, art("Props", "Prop_SupplyCrate"), CFrame.new(-6, 0, 5) * CFrame.Angles(0, math.rad(-18), 0))
		f.Model = model
		local _, size = model:GetBoundingBox()
		local spot = Instance.new("Part")
		spot.Name = "CachePrompt"
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Transparency = 1
		spot.Size = Vector3.new(1, 1, 1)
		spot.CFrame = model:GetPivot() + Vector3.new(0, size.Y + 0.5, 0)
		spot.Parent = model
		local p = Instance.new("ProximityPrompt")
		p.ActionText = "Open the cache"
		p.ObjectText = "Dug up · loot for the team"
		p.HoldDuration = Dig.Tuning().CacheOpenSeconds
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Style = Enum.ProximityPromptStyle.Custom
		p:SetAttribute("Kind", "OpenCache")
		p.Parent = spot
		p.Triggered:Connect(function(player: Player)
			openCache(f, player)
		end)
	elseif kind == "Nest" then
		local model = placeModel(f, art("Props", "Prop_Nest"), CFrame.new(0, 0, 8))
		f.Model = model
		-- an ordinary monster id (M<n>): FireWeapon only takes those as hits
		local id = combat:Register(model, {
			Kind = "Monster", Team = "Monsters", Health = Dig.Tuning().NestHealth, MonsterType = "Nest",
		})
		f.CombatId = id
		breaches:SetExtraPoint(`N:{key}`, breachPoint(f, "Nest"))
	end
	publishFeature(f, key)
	DigService.FeatureAdded:Fire(kind, floor, column)
	return f
end

function DigService:Feature(floor: number, column: number): string?
	local f = features[Grid.Key(floor, column)]
	return if f then f.Kind else nil
end

-- The cave behind a cave opening is built (DeepService): its stand-in mouth goes, the breach point
-- stays (Section 12: caves stay open, so they are routes monsters take).
function DigService:OpenCave(floor: number, column: number)
	local f = features[Grid.Key(floor, column)]
	if f and f.Kind == "CaveOpening" and f.Model then
		f.Model:Destroy()
		f.Model = nil
	end
end

-- Fixes what a cell holds this run (nil puts it back to its roll). Prompt 17: the Lost Crews' caves.
function DigService:SetRoll(floor: number, column: number, result: string?)
	assert(result == nil or Config.Find("DigResults", result), `DigService:SetRoll: no dig result {tostring(result)}`)
	overrides[Grid.Key(floor, column)] = result
	set("DigOverrides", Dig.EncodeOverrides(overrides))
end

-- What a result does when a cell opens with it, for results another service owns (cryo pods).
function DigService:SetResultHandler(result: string, fn: ((number, number, Player?) -> string)?)
	resultHandlers[result] = fn
end

-- Opening a cell ----------------------------------------------------------------------------------------

local function sideOf(floor: number, column: number, from: { Floor: number, Column: number }?): string?
	if not from or from.Floor ~= floor then
		return nil
	end
	return if from.Column < column then "Left" else "Right"
end

local function applyRoll(result: string, floor: number, column: number, finisher: Player?): string
	local band = Grid.BandOf(floor)
	if result == "OrePocket" then
		if not band.Ore then
			return "the rock is bare"
		end
		local drops = Loot.Roll("OrePocket", rng, { BandOre = band.Ore, OreMultiplier = classValue(finisher, "DugOre") })
		local given = giveDrops(drops, finisher, `ore pocket {Grid.Key(floor, column)}`)
		return `AN ORE POCKET: {if #given > 0 then Loot.Text(given) else "THE STOCKPILE IS FULL"}`
	elseif result == "CaveOpening" then
		addFeature("CaveOpening", floor, column)
		return "A CAVE OPENING: SOMETHING CAN COME THROUGH IT"
	elseif result == "Cache" then
		addFeature("Cache", floor, column)
		return "A CACHE: OPEN IT FOR THE TEAM"
	elseif result == "HazardPocket" then
		local kind = disasters:HazardPocket(floor, column, finisher)
		return if kind == "Flood" then "A HAZARD POCKET! WATER BURSTS OUT" elseif kind == "GasLeak" then "A HAZARD POCKET! GAS BURSTS OUT" else ""
	elseif result == "Nest" then
		local f = addFeature("Nest", floor, column)
		local at = Grid.CellCFrame(f.Floor, f.Column) * CFrame.new(0, 0.5, 3) * CFrame.Angles(0, math.pi, 0)
		local ok, err = pcall(function()
			threat:Burst(Dig.Tuning().NestBudget, at, `Nest:{f.Key}`)
		end)
		if not ok then
			log:Warn("nest burst: %s", tostring(err))
		end
		return "A NEST! MONSTERS POUR OUT · DESTROY IT"
	end
	local handler = resultHandlers[result]
	if handler then
		local ok, text = pcall(handler, floor, column, finisher)
		if not ok then
			log:Warn("%s at %s: %s", result, Grid.Key(floor, column), tostring(text))
			return ""
		end
		return text
	end
	return ""
end

local function open(floor: number, column: number, cause: string, finisher: Player?, from: { Floor: number, Column: number }?): (boolean, string?)
	local ok, why = grid:Dig(floor, column)
	if not ok then
		return false, why
	end
	local key = Grid.Key(floor, column)
	sites[key] = nil
	local index = table.find(queue, key)
	if index then
		table.remove(queue, index)
	end
	-- Section 10: every dug cell adds Disturbance (the Driller's level 3, Deep Charges)
	local amount = Dig.Tuning().DisturbancePerCell * classValue(finisher, "DigDisturbance") * teamValue("DigDisturbance")
	DigService:AddDisturbance(amount, "Digging")
	local result = Dig.Roll(seed, floor, column, eraNumber(), AVAILABLE, overrides)
	local found = applyRoll(result, floor, column, finisher)
	log:Info("dug %s (%s, %s): %s", key, cause, if finisher then finisher.Name else "-", result)
	announce(if result == "Nest" or result == "HazardPocket" then "Danger" else "Info",
		`DUG THROUGH TO {where(floor, column)}{if found ~= "" then `: {found}` else ""}`)
	for _, other in queue do
		publishSite(other)
	end
	publishSite(key)
	-- Section 10: digging causes cave-ins, now and then the passage it was dug through
	local side = sideOf(floor, column, from)
	if side and rng:NextNumber() < Dig.Tuning().CaveInChance then
		task.defer(function()
			disasters:CaveIn(floor, column, side, "Digging")
		end)
	end
	DigService.Dug:Fire(floor, column, result, cause, finisher)
	return true, nil
end

function DigService:DigNow(floor: number, column: number, cause: string, player: Player?): (boolean, string?)
	local faces = Dig.Faces(grid:Bunker(), floor, column)
	return open(floor, column, cause, player, faces[1])
end

-- Push Deeper ------------------------------------------------------------------------------------------

local function setLimit(value: number)
	limit = value
	set("DigLimit", limit)
end

local function askPushDeeper(player: Player, floor: number, column: number)
	local band = Grid.BandOf(floor)
	local first = band.Floors.From
	if votesOpen[first] then
		Remotes.FireClient("Alert", player, "Info", `THE PUSH DEEPER VOTE IS ON: VOTE ON THE BANNER`)
		return
	end
	local wait = (retryAt[first] or 0) - os.clock()
	if wait > 0 then
		Remotes.FireClient("Alert", player, "Warning", `THE TEAM SAID NO TO PUSHING DEEPER: ASK AGAIN IN {math.ceil(wait)} S`)
		return
	end
	local key = Grid.Key(floor, column)
	local id, err = votes:Open({
		Kind = "PushDeeper",
		Proposer = player,
		Title = `PUSH DEEPER: THE {string.upper(band.Name)}`,
		Subject = { Floor = floor, Column = column, Span = 1, Label = "PUSH DEEPER" },
		Cells = { key },
		Check = function(): (boolean, string?)
			return true, nil
		end,
		OnPass = function()
			votesOpen[first] = nil
			if limit < Dig.LimitAfter(floor) then
				setLimit(Dig.LimitAfter(floor))
			end
			log:Info("Push Deeper passed: the %s (dig to floor %d)", band.Name, limit)
			announce("Info", `PUSH DEEPER: THE TEAM OPENS THE {string.upper(band.Name)} · DIG DOWN TO FLOOR {limit}`)
			for k in sites do
				publishSite(k)
			end
		end,
		OnFail = function(reason: string)
			votesOpen[first] = nil
			retryAt[first] = os.clock() + Dig.Tuning().VoteRetrySeconds
			log:Info("Push Deeper failed: %s", reason)
			for k in sites do
				publishSite(k)
			end
		end,
	})
	if not id then
		Remotes.FireClient("Alert", player, "Warning", string.upper(err or "THE VOTE COULDN'T START"))
		return
	end
	if id ~= "solo" and limit < floor then
		votesOpen[first] = id
	end
	publishSite(key)
end

-- Players digging ----------------------------------------------------------------------------------------

local function canDigNow(player: Player): boolean
	return player:GetAttribute("Life") == "Alive" and Dig.CanDigWith(weapons:Items(player))
end

local function startDigging(player: Player, key: string)
	local floor, column = Grid.Parse(key)
	if not floor or not column or not inRun() then
		return
	end
	if not Dig.CanDigWith(weapons:Items(player)) then
		Remotes.FireClient("Alert", player, "Warning", "DIGGING NEEDS A DRILL OR A PICKAXE")
		return
	end
	local ok = grid:Bunker():CanDig(floor, column)
	if not ok then
		return
	end
	if Dig.NeedsVote(floor, limit) then
		askPushDeeper(player, floor, column)
		return
	end
	local site = getSite(floor, column)
	site.Diggers[player] = classValue(player, "DigSpeed") * teamValue("DigSpeed")
	publishSite(key)
end

local function stopDigging(player: Player, key: string)
	local site = sites[key]
	if site and site.Diggers[player] then
		site.Diggers[player] = nil
		publishSite(key)
	end
end

-- Dig prompts ---------------------------------------------------------------------------------------------

local function promptText(floor: number, face: Dig.Face): (string, string)
	local action = if face.Side == "Above" then "Dig down" else "Dig"
	local object
	if Dig.NeedsVote(floor, limit) then
		object = `{Grid.BandOf(floor).Name} · Push Deeper vote first`
	else
		object = `{Grid.BandOf(floor).Name} · {Dig.Seconds(floor)} s · Drill or Pickaxe`
	end
	return action, object
end

local function refreshPrompts()
	local parent = holder()
	if not parent then
		return
	end
	local bunker = grid:Bunker()
	local t = Grid.Tuning()
	local wanted: { [string]: { Floor: number, Column: number, Face: Dig.Face } } = {}
	for floor = t.FloorMin, t.FloorMax do
		for column = t.ColumnMin, t.ColumnMax do
			if bunker:State(floor, column) == "Rock" then
				for _, face in Dig.Faces(bunker, floor, column) do
					wanted[`{Grid.Key(floor, column)}|{face.Side}`] = { Floor = floor, Column = column, Face = face }
				end
			end
		end
	end
	for id, entry in prompts do
		if not wanted[id] then
			entry.Part:Destroy()
			prompts[id] = nil
		end
	end
	for id, w in wanted do
		local key = Grid.Key(w.Floor, w.Column)
		local action, object = promptText(w.Floor, w.Face)
		local entry = prompts[id]
		if not entry then
			local part = Instance.new("Part")
			part.Name = `Dig_{id}`
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part.Position = Dig.FacePoint(w.Face, w.Floor, w.Column)
			CollectionService:AddTag(part, CAMERA_IGNORE_TAG)
			part.Parent = parent
			local p = Instance.new("ProximityPrompt")
			p.Style = Enum.ProximityPromptStyle.Custom
			p.RequiresLineOfSight = false
			p.MaxActivationDistance = Dig.Tuning().PromptReach
			-- the cell is dug when its progress is full; the hold itself never runs out first
			p.HoldDuration = math.max(Dig.Seconds(w.Floor) * 2, 10)
			p:SetAttribute("Kind", "DigCell")
			p:SetAttribute("Cell", key)
			p.Parent = part
			p.PromptButtonHoldBegan:Connect(function(player: Player)
				startDigging(player, key)
			end)
			p.PromptButtonHoldEnded:Connect(function(player: Player)
				stopDigging(player, key)
			end)
			p.Triggered:Connect(function(player: Player)
				stopDigging(player, key)
			end)
			entry = { Part = part, Prompt = p, Key = key }
			prompts[id] = entry
		end
		local e = entry :: any
		e.Prompt.ActionText = action
		e.Prompt.ObjectText = object
		local site = sites[key]
		e.Prompt:SetAttribute("Progress", if site then site.Progress else 0)
	end
end

-- The tick ---------------------------------------------------------------------------------------------------

local function drillBaySpeed(): number
	local base = Config.Get("Rooms", "DrillBay").Output.Base
	local speed = 0
	for _, room in grid:RoomsOfType("DrillBay") do
		if not room.Wrecked then
			local rate = economy:Rate(room.Id)
			speed += Dig.DrillBaySpeed(rate, base)
		end
	end
	return speed
end

local function bayTarget(): string?
	local bunker = grid:Bunker()
	for _, key in queue do
		local floor, column = Grid.Parse(key)
		if floor and column and bunker:CanDig(floor, column) and not Dig.NeedsVote(floor, limit) then
			return key
		end
	end
	return nil
end

local function near(player: Player, key: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, entry in prompts do
		if entry.Key == key and (entry.Part.Position - root.Position).Magnitude <= Dig.Tuning().PromptReach + 4 then
			return true
		end
	end
	return false
end

local function tick(dt: number)
	if not inRun() then
		return
	end
	-- the Drill Bay's queue
	local target = bayTarget()
	local baySpeed = if target then drillBaySpeed() else 0
	for key, site in sites do
		local wasBay = site.Bay
		site.Bay = key == target and baySpeed > 0
		if wasBay ~= site.Bay then
			publishSite(key)
		end
	end
	if target and baySpeed > 0 and not sites[target] then
		local floor, column = Grid.Parse(target)
		if floor and column then
			local site = getSite(floor, column)
			site.Bay = true
		end
	end
	for key, site in table.clone(sites) do
		local speeds = {}
		local finisher: Player? = nil
		for player, speed in table.clone(site.Diggers) do
			if player.Parent ~= Players or not canDigNow(player) or not near(player, key) then
				site.Diggers[player] = nil
			else
				table.insert(speeds, speed)
				finisher = player
			end
		end
		if site.Bay and baySpeed > 0 then
			table.insert(speeds, baySpeed)
		end
		if #speeds > 0 then
			if not grid:Bunker():CanDig(site.Floor, site.Column) then
				dropSite(key)
			elseif Dig.NeedsVote(site.Floor, limit) then
				site.Diggers = {}
				publishSite(key)
			else
				site.Progress = math.min(site.Progress + Dig.Rate(speeds, site.Floor) * dt, 1)
				if site.Progress >= 1 then
					local faces = Dig.Faces(grid:Bunker(), site.Floor, site.Column)
					local from = faces[1]
					if finisher then
						-- the face the finisher stood at
						local character = finisher.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and root:IsA("BasePart") then
							local best = math.huge
							for _, face in faces do
								local d = (Dig.FacePoint(face, site.Floor, site.Column) - root.Position).Magnitude
								if d < best then
									best, from = d, face
								end
							end
						end
					end
					open(site.Floor, site.Column, if finisher then "Player" else "DrillBay", finisher, from)
				else
					publishSite(key)
				end
			end
		elseif site.Progress <= 0 and not table.find(queue, key) then
			sites[key] = nil
			publishSite(key)
		else
			publishSite(key)
		end
	end
end

-- Each cycle (Section 10): Disturbance falls, living nests raise it.
local function onCycle()
	local t = Dig.DisturbanceTuning()
	local nests = 0
	for _, f in features do
		if f.Kind == "Nest" then
			nests += 1
		end
	end
	local change = nests * Dig.Tuning().NestPerCycle - t.DecayPerCycle
	if change ~= 0 then
		DigService:AddDisturbance(change, "Cycle")
	end
end

-- The world changed: prompts follow the open cells; features in cells that closed go.
local function onGridChanged()
	for key, f in table.clone(features) do
		local floor, column = Grid.Parse(key)
		if floor and column and grid:State(floor, column) ~= "Dug" and f.Kind ~= "CaveOpening" then
			removeFeature(key, "Gone")
		end
	end
	for key in table.clone(sites) do
		local floor, column = Grid.Parse(key)
		if floor and column and grid:State(floor, column) ~= "Rock" then
			dropSite(key)
		end
	end
	refreshPrompts()
end

-- DevTools -----------------------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	table.insert(lines, string.format("Disturbance %.1f (%s), dig limit floor %d, deepest floor %d, seed %d", disturbance,
		Dig.Level(disturbance), limit, grid:DeepestFloor(), seed))
	for key, site in sites do
		table.insert(lines, string.format("site %s: %.0f%%, %d diggers%s%s", key, site.Progress * 100, diggerCount(site),
			if site.Bay then ", the Drill Bay" else "", if table.find(queue, key) then `, queued {table.find(queue, key)}` else ""))
	end
	if #queue > 0 then
		table.insert(lines, `queue: {table.concat(queue, " ")} (Drill Bay speed {string.format("%.2f", drillBaySpeed())})`)
	end
	for key, f in features do
		table.insert(lines, `{f.Kind} at {key}{if f.CombatId then ` ({f.CombatId})` else ""}`)
	end
	local promptCount = 0
	for _ in prompts do
		promptCount += 1
	end
	table.insert(lines, `{promptCount} dig prompts`)
	for first, id in votesOpen do
		table.insert(lines, `Push Deeper vote for floor {first}: {id}`)
	end
	return table.concat(lines, "\n")
end

local function cellArgs(args: { any }): (number?, number?)
	return tonumber(args[1]), tonumber(args[2])
end

local function registerCommands(dev: any)
	dev:Register("digs", {
		Description = "Digging now: Disturbance, the dig limit, sites, the Drill Bay's queue, what dug cells hold.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("dig", {
		Description = "Dig a rock cell now, with its roll and Disturbance (no time, no vote).",
		Usage = "dig <floor> <column>",
		Run = function(player, args): string?
			local floor, column = cellArgs(args)
			if not floor or not column then
				return "usage: dig <floor> <column>"
			end
			local ok, why = DigService:DigNow(floor, column, "DevTools", player)
			return if ok then describe() else `can't dig: {why}`
		end,
	})
	dev:Register("dig.roll", {
		Description = "What a cell holds when it is dug (this run's roll), and the Driller's hint.",
		Usage = "dig.roll <floor> <column>",
		Run = function(_player, args): string?
			local floor, column = cellArgs(args)
			if not floor or not column then
				return "usage: dig.roll <floor> <column>"
			end
			return `{Dig.Roll(seed, floor, column, eraNumber(), AVAILABLE, overrides)} (hint {Dig.Hint(seed, floor, column, eraNumber(), AVAILABLE, overrides) or "none"})`
		end,
	})
	dev:Register("dig.mark", {
		Description = "Put a rock cell on the Drill Bay's queue (or off with 'off').",
		Usage = "dig.mark <floor> <column> [off]",
		Run = function(player, args): string?
			local floor, column = cellArgs(args)
			if not floor or not column then
				return "usage: dig.mark <floor> <column> [off]"
			end
			local ok, why = DigService:Mark(floor, column, args[3] ~= "off", player)
			return if ok then describe() else why
		end,
	})
	dev:Register("disturbance", {
		Description = "Set Disturbance (thresholds fire as in play).",
		Usage = "disturbance <value>",
		Run = function(_player, args): string?
			local n = tonumber(args[1])
			if not n then
				return "usage: disturbance <value>"
			end
			setDisturbance(n, "DevTools")
			return describe()
		end,
	})
	dev:Register("disturbance.add", {
		Description = "Add to Disturbance (or take away with a negative number), as digging would.",
		Usage = "disturbance.add <n>",
		Run = function(_player, args): string?
			local n = tonumber(args[1])
			if not n then
				return "usage: disturbance.add <n>"
			end
			DigService:AddDisturbance(n, "DevTools")
			return describe()
		end,
	})
	dev:Register("tremor", {
		Description = "A Tremor now (Disturbance to 100).",
		Run = function(): string?
			setDisturbance(Dig.DisturbanceTuning().TremorAt, "DevTools")
			return describe()
		end,
	})
	dev:Register("pushdeeper", {
		Description = "Open the next band without a vote (or set the dig limit).",
		Usage = "pushdeeper [floor]",
		Run = function(_player, args): string?
			local floor = tonumber(args[1]) or (limit + 1)
			setLimit(math.clamp(Dig.LimitAfter(math.clamp(floor, 1, Grid.Tuning().FloorMax)), 1, Grid.Tuning().FloorMax))
			refreshPrompts()
			return describe()
		end,
	})
	for _, kind in { "Nest", "Cache", "CaveOpening" } do
		local name = if kind == "CaveOpening" then "cave" else string.lower(kind)
		dev:Register(name, {
			Description = `Put a {kind} in a dug cell, as if digging had found it.`,
			Usage = `{name} <floor> <column>`,
			Run = function(player, args): string?
				local floor, column = cellArgs(args)
				if not floor or not column or grid:State(floor, column) ~= "Dug" then
					return `usage: {name} <floor> <column> (a dug cell)`
				end
				local found = applyRoll(kind, floor, column, player)
				return `{found}\n{describe()}`
			end,
		})
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------------------

function DigService:Init(registry)
	grid = registry.BunkerGrid
	clock = registry.CycleClock
	director = registry.RunDirector
	session = registry.SessionService
	economy = registry.EconomyService
	weapons = registry.WeaponService
	combat = registry.CombatService
	votes = registry.VoteService
	builds = registry.BuildService
	breaches = registry.BreachService
	threat = registry.ThreatDirector
	disasters = registry.DisasterService
	inventory = registry.InventoryService
	collection = registry.ReplicationService:Collection("Digs")
	set = RunState.Writer("DigService")
	registerCommands(registry.DevService)
end

function DigService:Start()
	seed = Random.new():NextInteger(1, 2 ^ 30)
	limit = Dig.StartLimit()
	set("DigSeed", seed)
	set("DigLimit", limit)
	set("Disturbance", 0)
	set("Nests", 0)
	set("DigOverrides", Dig.EncodeOverrides(overrides))
	grid.Changed:Connect(onGridChanged)
	clock.CycleStarted:Connect(function(cycle: number)
		if cycle > 1 then
			onCycle()
		end
	end)
	weapons.Exploded:Connect(function()
		if inRun() then
			DigService:AddDisturbance(Dig.DisturbanceTuning().Explosive, "Explosive")
		end
	end)
	local lastHit: { [string]: string } = {} -- a nest's combatant id -> who hit it last
	local function isNest(id: string): boolean
		for _, f in features do
			if f.CombatId == id then
				return true
			end
		end
		return false
	end
	combat.Damaged:Connect(function(id: string, _amount: number, source: string?)
		if source and isNest(id) then
			lastHit[id] = source
		end
	end)
	combat.Died:Connect(function(id: string)
		for _, f in features do
			if f.CombatId == id then
				local killer: Player? = nil
				for _, player in Players:GetPlayers() do
					if `P{player.UserId}` == lastHit[id] then
						killer = player
					end
				end
				lastHit[id] = nil
				destroyNest(f, killer)
				return
			end
		end
	end)
	builds:SetCellCheck(function(floor: number, column: number): (boolean, string?)
		local f = features[Grid.Key(floor, column)]
		if not f then
			return true, nil
		elseif f.Kind == "Nest" then
			return false, "A nest is in that cell: destroy it first"
		elseif f.Kind == "Cache" then
			return false, "A cache is in that cell: open it first"
		end
		return false, "A cave opening is in that cell: it stays open to the Deep"
	end)
	Remotes.OnServer("MarkDig", function(player: Player, floor: number, column: number, on: boolean)
		local ok, why = DigService:Mark(floor, column, on, player)
		if not ok and why then
			Remotes.FireClient("Alert", player, "Warning", string.upper(why))
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= Dig.Tuning().TickSeconds then
			local elapsed = math.min(acc, 1)
			acc = 0
			local ok, err = pcall(tick, elapsed)
			if not ok then
				log:Warn("tick: %s", tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for key, site in sites do
			if site.Diggers[player] then
				site.Diggers[player] = nil
				publishSite(key)
			end
		end
	end)
	task.defer(refreshPrompts)
	log:Info("digging ready: dig to floor %d without a vote", limit)
end

return DigService
