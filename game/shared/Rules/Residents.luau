--!strict
--[[
	Residents: the rules of residents, phase 1 (bible Section 11: identity, stats, jobs, levels,
	needs, routine and death). ResidentService runs them on the server; the Residents screen and
	the Command View show their numbers; DataTests hold them to the bible.

	* Identity: a first and last name from Config.ResidentNames (no repeats in a run while the
	  pool lasts), an age from Tuning.Aging.StartAge, a tier (the six founders are Common).
	* Stats: Strength, Smarts, Grit, Speed and Charm, StatMin to StatMax when they arrive (Rares
	  add RareStatBonus to their best two), never past StatCap. Max health grows with Grit
	  (HealthBase + Grit x HealthPerGrit, provisional).
	* Levels 1 to LevelMax: XPToLevelBase + XPToLevelStep x (level - 1) to the next; each level
	  adds 1 to the stat their job uses (Section 11). Founders above level 1 put theirs into
	  their best stat.
	* Jobs: one room each, if the room has a worker stat and a free slot
	  (Tuning.Rooms.WorkerSlotsPerCell x span). AutoAssign picks the empty slots to fill in
	  Tuning.Residents.AutoAssignOrder (power first, so the lights stay on), then fills them with
	  the best matches by stat.
	* A room's crew for Section 13's formula: workers, the sum of their job stat (an Exhausted
	  resident counts half), and their average morale effect (Config.MoraleStates).
	* Needs once a cycle: rest drains with work and refills in a Quarters bed (less without
	  one); food and water come from the stockpile, and the hungry lose health and morale;
	  morale moves with job fit, meals, dark rooms and beds (Tuning.Morale).
	* Death: at 0 health a resident is down for DeathReviveSeconds; then gone for the run.
]]

local Config = require(script.Parent.Parent.Config)

export type Stats = { [string]: number }
export type State = "Alive" | "Down" | "Dead" | "Away" -- Away: on an expedition, off the map (Prompt 18)
export type Resident = {
	Id: string,
	First: string,
	Last: string,
	Age: number,
	Tier: string,
	Level: number,
	XP: number,
	Stats: Stats,
	Job: string?, -- a room id
	Health: number,
	MaxHealth: number,
	Rest: number, -- 0 to 100
	Morale: number, -- 0 to 100
	State: State,
	Hungry: boolean, -- missed the last meal
	Trapped: boolean?, -- cave-in rubble cuts them off from where they need to be (Prompt 13)
	Weapon: string?, -- the weapon they carry (Section 11's gear, Prompt 26): armed residents answer rally calls
	Sick: boolean?, -- an Outbreak's sickness (Prompt 24; Config.Conditions.Sick: contagious until treated)
	Irradiated: boolean?, -- caught in a radiation leak (Prompt 24; Config.Conditions.Irradiated: loses health until cleared)
	-- Phase 2 (Prompt 26)
	Traits: { string }, -- Config.Traits ids: two each (Section 11)
	Outfit: string?, -- a gear piece ("LabCoat:Reinforced"; Piece and PieceKey below)
	Tool: string?, -- a gear piece ("Ladle")
	Injured: boolean?, -- hurt badly: works slowly until treated (Config.Conditions.Injured)
	Panicked: boolean?, -- fleeing danger: no work until they calm down (Config.Conditions.Panicked)
	Refusing: boolean?, -- Miserable: won't work this cycle
	Lucky: boolean?, -- the Lucky trait's roll came up: double output this cycle
	Low: number?, -- cycles in a row spent Miserable
	Log: { string }, -- the run log (Section 11)
}
export type Crew = { Workers: number, StatSum: number, Morale: number, Multiplier: number? }
export type Morale = { Workers: { Resident }, Floor: number?, Lounge: boolean } -- what a cycle's morale needs to know of a resident's room
export type Rng = { NextInteger: (self: any, number, number) -> number, NextNumber: (self: any) -> number }

local Modifiers = require(script.Parent.Modifiers)

local Residents = {}

local function tuning(): { [string]: any }
	return Config.Get("Tuning", "Residents")
end

-- Armed residents defend their room and answer rally calls (Section 11; the Warden's Rally Call).
-- How a Miserable resident who walked out is recorded (ResidentService:Lose's "how"): they are
-- lost to the bunker like the dead, but the log, the results and the Memorial say they left.
Residents.LEFT = "left the bunker"

function Residents.Armed(resident: Resident): boolean
	return resident.Weapon ~= nil
end

function Residents.StatIds(): { string }
	return Config.Ids("Stats")
end

-- Traits (Prompt 26) ---------------------------------------------------------------------------------

-- Every modifier a resident's traits carry.
local function traitModifiers(resident: Resident): { any }
	local list = {}
	for _, id in resident.Traits or {} do
		local trait = Config.Find("Traits", id)
		if trait then
			for _, modifier in trait.Modifiers do
				table.insert(list, modifier)
			end
		end
	end
	return list
end

-- A resident's own value for a modifier key from their traits (nil: none of their traits has it).
-- `room`: for keys that name a room type (RoomOutput), only that room's. `scope` "Room": the
-- modifiers that reach everyone in their room (a Natural Leader's); otherwise their own.
function Residents.Trait(resident: Resident, key: string, room: string?, scope: string?): number?
	local picked = {}
	for _, modifier in traitModifiers(resident) do
		local reach = modifier.Scope or "Self"
		if modifier.Key == key and (modifier.Room == nil or modifier.Room == room)
			and (if scope == "Room" then reach == "Room" else reach ~= "Room" or scope == "Any") then
			table.insert(picked, modifier)
		end
	end
	if #picked == 0 then
		return nil
	end
	return Modifiers.Fold(picked, key)
end

function Residents.Has(resident: Resident, key: string): boolean
	local value = Residents.Trait(resident, key, nil, "Any")
	return value ~= nil and value ~= 0
end

-- Section 11: "Commons roll one good and one bad trait. Rares roll two good". A Legendary's
-- signature trait comes with its Legend (Prompt 27); until then it rolls two good ones too.
function Residents.RollTraits(rng: Rng, tier: string): { string }
	local good, bad = {}, {}
	for _, id in Config.Ids("Traits") do
		table.insert(if Config.Get("Traits", id).Type == "Good" then good else bad, id)
	end
	local first = good[rng:NextInteger(1, #good)]
	if tier == "Common" or tier == "Free" then
		return { first, bad[rng:NextInteger(1, #bad)] }
	end
	local second = first
	for _ = 1, 20 do
		second = good[rng:NextInteger(1, #good)]
		if second ~= first then
			break
		end
	end
	return { first, second }
end

-- Gear (Prompt 26) -----------------------------------------------------------------------------------

-- A gear piece is an item and its rarity, written "Item:Rarity" ("Ladle" alone is Standard).
function Residents.Piece(key: string?): (string?, string)
	if not key or key == "" then
		return nil, "Standard"
	end
	local item, rarity = string.match(key, "^([%w_]+):([%w_]+)$")
	if item and Config.Find("ItemRarities", rarity) then
		return item, rarity
	end
	return key, "Standard"
end

function Residents.PieceKey(itemId: string, rarity: string?): string
	return if rarity and rarity ~= "Standard" then `{itemId}:{rarity}` else itemId
end

-- Which of a resident's three slots an item goes in (Section 11: Weapon, Outfit, Tool).
function Residents.Slot(itemId: string?): string?
	local item = if itemId then Config.Find("Items", itemId) else nil
	if not item then
		return nil
	end
	if item.Kind == "Outfit" then
		return "Outfit"
	elseif item.Kind == "ResidentTool" or table.find(tuning().RepairTools, itemId :: string) then
		return "Tool" -- the Wrench is a tool in a resident's hands ("Wrench (repairs)")
	elseif item.Kind == "Gun" or item.Kind == "Melee" then
		return "Weapon"
	end
	return nil
end

-- "Lab Coat (Reinforced)", "Ladle".
function Residents.PieceName(key: string?): string
	local itemId, rarity = Residents.Piece(key)
	local item = if itemId then Config.Find("Items", itemId) else nil
	if not item then
		return "none"
	end
	return if rarity ~= "Standard" then `{item.Name} ({Config.Get("ItemRarities", rarity).Name})` else item.Name
end

-- What an outfit adds: +1 to +3 to its stat by its rarity (Config.ItemRarities' OutfitBonus).
function Residents.OutfitBonus(key: string?): (string?, number, number, boolean)
	local itemId, rarity = Residents.Piece(key)
	local item = if itemId then Config.Find("Items", itemId) else nil
	if not item or not item.Outfit then
		return nil, 0, 0, false
	end
	return item.Outfit.Stat, Config.Get("ItemRarities", rarity).OutfitBonus, item.Outfit.Health or 0, item.Outfit.IgnoresGas == true
end

-- A resident's stats with their outfit on (never over StatCap).
function Residents.EffectiveStats(resident: Resident): Stats
	local stat, bonus = Residents.OutfitBonus(resident.Outfit)
	if not stat or bonus <= 0 then
		return resident.Stats
	end
	local stats = table.clone(resident.Stats)
	stats[stat] = math.min(tuning().StatCap, (stats[stat] or 0) + bonus)
	return stats
end

-- The room types a tool helps in, and by how much (Tuning.Residents.ToolOutput).
function Residents.ToolBonus(key: string?, roomType: string): number
	local itemId = Residents.Piece(key)
	local rooms = if itemId then tuning().ToolRooms[itemId] else nil
	if rooms and table.find(rooms, roomType) then
		return tuning().ToolOutput
	end
	return 1
end

-- Do they mend their room each cycle (a repair tool in hand, or the Tinkerer's trait)?
function Residents.Repairs(resident: Resident): boolean
	local itemId = Residents.Piece(resident.Tool)
	return (itemId ~= nil and table.find(tuning().RepairTools, itemId) ~= nil) or Residents.Has(resident, "RepairsRooms")
end

-- Hurt badly enough to be Injured? Healed enough to be over it?
function Residents.InjuredAt(health: number, maxHealth: number): boolean
	return health > 0 and health < maxHealth * tuning().InjuredBelow
end

function Residents.Recovered(health: number, maxHealth: number): boolean
	return health >= maxHealth * tuning().InjuredClearAt
end

-- How long a resident stays Panicked once the danger is gone (never, for the Brave and Cool Heads).
function Residents.PanicSeconds(resident: Resident, calmed: boolean): number
	if Residents.Has(resident, "NeverPanics") then
		return 0
	end
	return tuning().PanicSeconds * (Residents.Trait(resident, "PanicChance") or 1) * (if calmed then tuning().CalmedMultiplier else 1)
end

-- Found gear: an item from the pool at a weighted rarity, as a piece's key. `a` and `b`: 0 to 1.
function Residents.RollGear(a: number, b: number): string
	local t = tuning()
	local item = t.GearPool[math.clamp(math.floor(a * #t.GearPool) + 1, 1, #t.GearPool)]
	local total = 0
	for _, weight in t.GearRarity do
		total += weight
	end
	local roll = b * total
	local rarity = "Standard"
	for _, id in Config.Ids("ItemRarities") do
		local weight = t.GearRarity[id]
		if weight then
			roll -= weight
			if roll < 0 then
				rarity = id
				break
			end
		end
	end
	-- only an outfit's rarity changes what it does for a resident
	return Residents.PieceKey(item, if Residents.Slot(item) == "Outfit" then rarity else nil)
end

-- A resident's max health: their Grit (with their outfit), their Tough or Frail, their vest.
function Residents.MaxHealthOf(resident: Resident): number
	local _, _, vest = Residents.OutfitBonus(resident.Outfit)
	local base = Residents.MaxHealth(Residents.EffectiveStats(resident))
	return math.floor(base * (Residents.Trait(resident, "MaxHealthMult") or 1) + vest + 0.5)
end

-- How much of a meal they eat (Iron Stomach half, Glutton twice).
function Residents.FoodUse(resident: Resident): number
	return Residents.Trait(resident, "FoodUse") or 1
end

-- Does gas hurt them (a Hazmat Suit ignores it), and how much of it (Hardy halves it)?
function Residents.GasTaken(resident: Resident): number
	local _, _, _, ignores = Residents.OutfitBonus(resident.Outfit)
	if ignores then
		return 0
	end
	return Residents.Trait(resident, "GasDamageTaken") or 1
end

-- Can they work right now? Not while Panicked (Config.Conditions.Panicked stops work) or refusing.
function Residents.Working(resident: Resident): boolean
	return resident.State == "Alive" and not resident.Panicked and not resident.Refusing
end

function Residents.MaxHealth(stats: Stats): number
	local t = tuning()
	return t.HealthBase + (stats.Grit or 0) * t.HealthPerGrit
end

function Residents.XPToLevel(level: number): number
	local t = tuning()
	return t.XPToLevelBase + t.XPToLevelStep * (level - 1)
end

-- Their best stat (ties: the order of Config.Stats) and their worst.
function Residents.Best(stats: Stats): string
	local best, value = "Strength", -1
	for _, id in Residents.StatIds() do
		if (stats[id] or 0) > value then
			best, value = id, stats[id] or 0
		end
	end
	return best
end

function Residents.Worst(stats: Stats): string
	local worst, value = "Strength", math.huge
	for _, id in Residents.StatIds() do
		if (stats[id] or 0) < value then
			worst, value = id, stats[id] or 0
		end
	end
	return worst
end

-- The stat a room's job uses (nil: nobody works there).
function Residents.JobStat(roomType: string): string?
	return Config.Get("Rooms", roomType).WorkerStat
end

function Residents.Slots(roomType: string, level: number, span: number): number
	if not Residents.JobStat(roomType) then
		return 0
	end
	return Config.Get("Tuning", "Rooms").WorkerSlotsPerCell[level] * span
end

local function bump(stats: Stats, stat: string)
	stats[stat] = math.min(tuning().StatCap, (stats[stat] or 0) + 1)
end

--[[
	A new resident. `used` holds the full names taken this run (it is updated). Founders above
	level 1 have put each level into their best stat.
]]
function Residents.Roll(rng: Rng, id: string, tier: string, level: number, used: { [string]: boolean }): Resident
	local t = tuning()
	local names = Config.Get("ResidentNames", "First").Names
	local lasts = Config.Get("ResidentNames", "Last").Names
	local first, last = "", ""
	for _ = 1, 40 do
		first, last = names[rng:NextInteger(1, #names)], lasts[rng:NextInteger(1, #lasts)]
		if not used[`{first} {last}`] then
			break
		end
	end
	used[`{first} {last}`] = true
	local stats: Stats = {}
	for _, stat in Residents.StatIds() do
		stats[stat] = rng:NextInteger(t.StatMin, t.StatMax)
	end
	if tier ~= "Common" and tier ~= "Free" then -- Rares and above: their best two get a bonus
		local order = table.clone(Residents.StatIds())
		table.sort(order, function(a: string, b: string): boolean
			return stats[a] > stats[b]
		end)
		for i = 1, 2 do
			stats[order[i]] = math.min(t.StatCap, stats[order[i]] + t.RareStatBonus)
		end
	end
	for _ = 2, level do
		bump(stats, Residents.Best(stats))
	end
	local aging = Config.Get("Tuning", "Aging")
	local traits = Residents.RollTraits(rng, tier)
	local maxHealth = Residents.MaxHealthOf({ Stats = stats, Traits = traits } :: any)
	return {
		Id = id,
		First = first,
		Last = last,
		Age = rng:NextInteger(aging.StartAge.Min, aging.StartAge.Max),
		Tier = tier,
		Level = level,
		XP = 0,
		Stats = stats,
		Job = nil,
		Health = maxHealth,
		MaxHealth = maxHealth,
		Rest = 100,
		Morale = t.MoraleStart,
		State = "Alive",
		Hungry = false,
		Traits = traits,
		Log = {},
	}
end

-- Experience: returns the levels gained; each adds 1 to `jobStat` (their best stat if nil).
function Residents.AddXP(resident: Resident, xp: number, jobStat: string?): number
	local t = tuning()
	local gained = 0
	resident.XP += xp * (Residents.Trait(resident, "ResidentXP") or 1) -- a Fast Learner's
	while resident.Level < t.LevelMax and resident.XP >= Residents.XPToLevel(resident.Level) do
		resident.XP -= Residents.XPToLevel(resident.Level)
		resident.Level += 1
		gained += 1
		bump(resident.Stats, jobStat or Residents.Best(resident.Stats))
	end
	if resident.Level >= t.LevelMax then
		resident.XP = 0
	end
	resident.MaxHealth = Residents.MaxHealthOf(resident)
	return gained
end

-- Morale's state (Config.MoraleStates) and its output effect (R in Section 13).
function Residents.MoraleState(morale: number): (string, number)
	for _, id in Config.Ids("MoraleStates") do
		local state = Config.Get("MoraleStates", id)
		if morale >= state.From and morale <= state.To + 0.999 then
			return id, state.OutputMultiplier
		end
	end
	return "Settled", 1
end

function Residents.IsExhausted(resident: Resident): boolean
	return resident.Rest <= 0
end

-- The health a resident's conditions cost them each cycle (Prompt 24: Sick and Irradiated;
-- Config.Conditions' HealthPerCycle). Zero or less.
function Residents.ConditionHealth(resident: Resident): number
	local sum = 0
	if resident.Sick then
		sum += Config.Get("Conditions", "Sick").HealthPerCycle or 0
	end
	if resident.Irradiated then
		sum += Config.Get("Conditions", "Irradiated").HealthPerCycle or 0
	end
	return sum
end

-- Quarantine (Section 10: "quarantine in Quarters"): a sick resident with no job keeps to a bed.
function Residents.Quarantined(resident: Resident): boolean
	return resident.Sick == true and resident.Job == nil and resident.State == "Alive"
end

-- A room's crew: who works there, alive and working, with their job stat. Each worker counts
-- their stat (with their outfit on) times what slows or speeds them: Exhausted half, the Sick and
-- the Injured less, their traits (Hard Worker, Lazy, Green Thumb in a Kitchen), their tool in its
-- room, a Lucky cycle twice. The Panicked and those refusing work don't count. What reaches the
-- whole room (a Natural Leader) is the crew's Multiplier.
function Residents.Crew(workers: { Resident }, roomType: string): Crew?
	local stat = Residents.JobStat(roomType)
	if not stat then
		return nil
	end
	local count, sum, morale, room = 0, 0, 0, 1
	local conditions = Config.Get("Conditions", "Exhausted").OutputMultiplier
	local sick = Config.Get("Conditions", "Sick").OutputMultiplier or 1
	local injured = Config.Get("Conditions", "Injured").OutputMultiplier or 1
	for _, resident in workers do
		if Residents.Working(resident) then
			count += 1
			local own = (if Residents.IsExhausted(resident) then conditions else 1)
				* (if resident.Sick then sick else 1) -- Prompt 24: the sick work slowly
				* (if resident.Injured then injured else 1)
				* (Residents.Trait(resident, "AllOutput") or 1)
				* (Residents.Trait(resident, "RoomOutput", roomType) or 1)
				* Residents.ToolBonus(resident.Tool, roomType)
				* (if resident.Lucky then 2 else 1)
			sum += (Residents.EffectiveStats(resident)[stat] or 0) * own
			room *= Residents.Trait(resident, "AllOutput", nil, "Room") or 1
			local _, effect = Residents.MoraleState(resident.Morale)
			morale += effect
		end
	end
	if count == 0 then
		return nil
	end
	return { Workers = count, StatSum = sum, Morale = morale / count, Multiplier = if room ~= 1 then room else nil }
end

export type Room = { Id: string, Type: string, Level: number, Span: number }

--[[
	Auto-Assign (Section 7: "fills empty slots by best stat"). Which slots get filled: the empty
	ones in Tuning.Residents.AutoAssignOrder (power first, so the lights stay on), then any other
	working room, as many as there are free residents. Who fills them: the best matches first
	across all of those slots (the highest stat for a slot's job wins it), so a fast cook ends up
	in the Kitchen rather than at the reactor. `free` is changed in place: assigned residents leave
	it. Returns { residentId = roomId }.
]]
function Residents.AutoAssign(rooms: { Room }, taken: { [string]: number }, free: { Resident }): { [string]: string }
	local order = tuning().AutoAssignOrder
	local sorted = table.clone(rooms)
	table.sort(sorted, function(a: Room, b: Room): boolean
		local ia, ib = table.find(order, a.Type) or #order + 1, table.find(order, b.Type) or #order + 1
		if ia ~= ib then
			return ia < ib
		end
		return a.Id < b.Id
	end)
	local alive = {}
	for _, resident in free do
		if resident.State == "Alive" then
			table.insert(alive, resident)
		end
	end
	-- the slots to fill, in priority order
	local slots: { { Room: string, Stat: string, Rank: number } } = {}
	for _, room in sorted do
		local stat = Residents.JobStat(room.Type)
		if stat then
			for _ = 1, Residents.Slots(room.Type, room.Level, room.Span) - (taken[room.Id] or 0) do
				if #slots < #alive then
					table.insert(slots, { Room = room.Id, Stat = stat, Rank = #slots + 1 })
				end
			end
		end
	end
	-- the best matches first
	local pairs_ = {}
	for i, resident in alive do
		for j, slot in slots do
			table.insert(pairs_, { R = i, S = j, Value = resident.Stats[slot.Stat] or 0 })
		end
	end
	table.sort(pairs_, function(a: any, b: any): boolean
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		if a.S ~= b.S then
			return a.S < b.S
		end
		return a.R < b.R
	end)
	local result: { [string]: string } = {}
	local usedResident, usedSlot = {}, {}
	for _, pair in pairs_ do
		if not usedResident[pair.R] and not usedSlot[pair.S] then
			usedResident[pair.R] = true
			usedSlot[pair.S] = true
			local resident, slot = alive[pair.R], slots[pair.S]
			result[resident.Id] = slot.Room
			taken[slot.Room] = (taken[slot.Room] or 0) + 1
		end
	end
	for i = #free, 1, -1 do
		if result[free[i].Id] then
			table.remove(free, i)
		end
	end
	return result
end

--[[
	One cycle of needs for a resident (Section 11), at the cycle's start:
	* rest: -RestDrainPerShift for a worker, +RestRefillPerCycle in a bed (x NoBedRestMultiplier
	  without one), 0 to 100;
	* food and water: `fed` false means they missed the meal: -ShortfallHealth health and
	  Tuning.Morale.Hungry morale;
	* morale: JobFit or PoorFit for their job, FedCycle, DarkRoom for a dark job room (not with
	  Night Vision; AfraidOfDark instead for those afraid of it), NoBed, Injured, their roommates'
	  RoommateMorale, Claustrophobic from floor ClaustrophobicFloor down, Homesick without a Lounge
	  (`where`: who shares their room, its floor, whether they have a Lounge to sit in).
	Returns what changed for the run log.
]]
function Residents.Cycle(resident: Resident, worked: boolean, jobStat: string?, bed: boolean, fed: boolean, darkJob: boolean,
	where: Morale?): { string }
	local t = tuning()
	local m = Config.Get("Tuning", "Morale")
	local notes = {}
	local rest = resident.Rest
	if worked then
		rest -= t.RestDrainPerShift * (Residents.Trait(resident, "RestNeed") or 1) -- a Sleepyhead tires faster
	end
	rest += t.RestRefillPerCycle * (if bed then 1 else t.NoBedRestMultiplier)
	resident.Rest = math.clamp(rest, 0, 100)
	local morale = resident.Morale
	if jobStat then
		if jobStat == Residents.Best(resident.Stats) then
			morale += m.JobFit
		elseif jobStat == Residents.Worst(resident.Stats) then
			morale += m.PoorFit
		end
	end
	if fed then
		morale += m.FedCycle
		resident.Hungry = false
	else
		morale += m.Hungry
		resident.Health = math.max(0, resident.Health - t.ShortfallHealth)
		resident.Hungry = true
		table.insert(notes, "went hungry")
	end
	if darkJob and Residents.Has(resident, "AfraidOfDark") then
		morale += m.AfraidOfDark -- "Morale crashes in dark rooms"
		table.insert(notes, "was afraid in the dark")
	elseif darkJob and not Residents.Has(resident, "NoDarkPenalty") then
		morale += m.DarkRoom
	end
	if not bed then
		morale += m.NoBed
		table.insert(notes, "had no bed")
	end
	-- Phase 2 (Prompt 26): injuries, and what their own traits and their roommates' do to them
	if resident.Injured then
		morale += m.Injured
	end
	if where then
		for _, other in where.Workers do
			if other ~= resident and other.State == "Alive" then
				morale += Residents.Trait(other, "RoommateMorale", nil, "Any") or 0 -- a Chatterbox, a Grumpy one
			end
		end
		if Residents.Has(resident, "Claustrophobic") and where.Floor and where.Floor >= m.ClaustrophobicFloor then
			morale += m.Claustrophobic
		end
		if Residents.Has(resident, "Homesick") and not where.Lounge then
			morale += m.Homesick
		end
	end
	resident.Morale = math.clamp(morale, 0, 100)
	return notes
end

--[[
	Morale's bottom (Section 11: a Miserable resident "May refuse work, start fights or leave the
	bunker for good"). Called once a cycle with the cycles they have now spent Miserable in a row
	(resident.Low) and two rolls from 0 to 1. Returns "Leave" (after LeaveAfterCycles, LeaveChance),
	"Fight" (FightChance, with someone to fight), "Refuse" (RefuseChance) or nil.
]]
function Residents.Miserable(resident: Resident, company: boolean, roll: number, second: number): string?
	local m = Config.Get("Tuning", "Morale").Miserable
	if Residents.MoraleState(resident.Morale) ~= "Miserable" then
		return nil
	end
	if (resident.Low or 0) >= m.LeaveAfterCycles and roll < m.LeaveChance then
		return "Leave"
	end
	if company and second < m.FightChance then
		return "Fight"
	end
	if second < m.FightChance + m.RefuseChance then
		return "Refuse"
	end
	return nil
end

-- The full name, as the HUD and the run log write it.
function Residents.Name(resident: Resident): string
	return `{resident.First} {resident.Last}`
end

return Residents
