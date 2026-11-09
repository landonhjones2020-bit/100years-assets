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
	Log: { string }, -- the run log (Section 11)
}
export type Crew = { Workers: number, StatSum: number, Morale: number, Multiplier: number? }
export type Rng = { NextInteger: (self: any, number, number) -> number, NextNumber: (self: any) -> number }

local Residents = {}

local function tuning(): { [string]: any }
	return Config.Get("Tuning", "Residents")
end

function Residents.StatIds(): { string }
	return Config.Ids("Stats")
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
	local maxHealth = Residents.MaxHealth(stats)
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
		Log = {},
	}
end

-- Experience: returns the levels gained; each adds 1 to `jobStat` (their best stat if nil).
function Residents.AddXP(resident: Resident, xp: number, jobStat: string?): number
	local t = tuning()
	local gained = 0
	resident.XP += xp
	while resident.Level < t.LevelMax and resident.XP >= Residents.XPToLevel(resident.Level) do
		resident.XP -= Residents.XPToLevel(resident.Level)
		resident.Level += 1
		gained += 1
		bump(resident.Stats, jobStat or Residents.Best(resident.Stats))
	end
	if resident.Level >= t.LevelMax then
		resident.XP = 0
	end
	resident.MaxHealth = Residents.MaxHealth(resident.Stats)
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

-- A room's crew: who works there, alive, with their job stat (Exhausted counts half).
function Residents.Crew(workers: { Resident }, roomType: string): Crew?
	local stat = Residents.JobStat(roomType)
	if not stat then
		return nil
	end
	local count, sum, morale = 0, 0, 0
	for _, resident in workers do
		if resident.State == "Alive" then
			count += 1
			local exhausted = Config.Get("Conditions", "Exhausted").OutputMultiplier
			sum += (resident.Stats[stat] or 0) * (if Residents.IsExhausted(resident) then exhausted else 1)
			local _, effect = Residents.MoraleState(resident.Morale)
			morale += effect
		end
	end
	if count == 0 then
		return nil
	end
	return { Workers = count, StatSum = sum, Morale = morale / count }
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
	* morale: JobFit or PoorFit for their job, FedCycle, DarkRoom for a dark job room, NoBed.
	Returns what changed for the run log.
]]
function Residents.Cycle(resident: Resident, worked: boolean, jobStat: string?, bed: boolean, fed: boolean, darkJob: boolean): { string }
	local t = tuning()
	local m = Config.Get("Tuning", "Morale")
	local notes = {}
	local rest = resident.Rest
	if worked then
		rest -= t.RestDrainPerShift
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
	if darkJob then
		morale += m.DarkRoom
	end
	if not bed then
		morale += m.NoBed
		table.insert(notes, "had no bed")
	end
	resident.Morale = math.clamp(morale, 0, 100)
	return notes
end

-- The full name, as the HUD and the run log write it.
function Residents.Name(resident: Resident): string
	return `{resident.First} {resident.Last}`
end

return Residents
