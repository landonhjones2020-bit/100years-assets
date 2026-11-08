--!strict
--[[
	Rules.Clock: the century's arithmetic (bible Section 5). Pure functions over a State
	table, so CycleClock, the client and the data tests share one copy. CycleClock owns the
	timers; these functions only decide numbers and kinds.

	* A cycle is a day phase, then a Surge. At the end of each cycle the year counter jumps by
	  Years per Cycle: Tuning.Clock.YearsPerCycleStart (1) plus the YearsPerCycle of every
	  objective done (Config.Objectives: each Lost Crew rescued +2, each era boss beaten +1),
	  at most Tuning.Clock.YearsPerCycleMax (12).
	* When the counter reaches or passes the last year of era I, II or III (25, 50, 75), the
	  next Surge is that era's boss, unless it is already beaten. The boss Surge comes once.
	* When the counter reaches Tuning.Clock.FinalYear (100) it stops there, and the next
	  Surge is the final one (the Source rises into the bunker).
	* A boss Surge (an era boss, or the final Surge's Source) has no timer: it lasts until
	  its boss is beaten (Landon, Nov 8, 2026). Other Surges end on the timer, or earlier when
	  cleared.
	* The first cycle's Surge is a small tutorial wave.
	* Endless (Keep Going after a victory): no cap, no era bosses, every Surge an Endless one.

	In cycle order:
		local state = Clock.NewState()               -- Cycle 1, Year 1
		local coming = Clock.SurgeKind(state)        -- during the day: what the Surge will be
		local kind, boss = Clock.StartSurge(state)   -- the Surge begins (uses up a due boss)
		local before, due = Clock.EndCycle(state)    -- Year += Years per Cycle, Cycle += 1
]]

local Config = require(script.Parent.Parent.Config)

export type SurgeKind = "Tutorial" | "Normal" | "Boss" | "Final" | "Endless"

export type State = {
	Cycle: number, -- from 1
	Year: number, -- from 1
	Completed: { [string]: boolean }, -- objective ids done (Config.Objectives)
	PendingBoss: string?, -- an era boss due at the next Surge (Config.Bosses)
	Endless: boolean,
}

local Clock = {}

function Clock.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Clock")
end

function Clock.NewState(): State
	return { Cycle = 1, Year = 1, Completed = {}, PendingBoss = nil, Endless = false }
end

-- Years per Cycle when these objectives are done.
function Clock.YearsPerCycle(completed: { [string]: boolean }): number
	local tuning = Clock.Tuning()
	local years = tuning.YearsPerCycleStart
	for id, done in completed do
		local objective = Config.Find("Objectives", id)
		if done and objective then
			years += objective.YearsPerCycle
		end
	end
	return math.min(years, tuning.YearsPerCycleMax)
end

-- Has this era boss been beaten (its objective done)?
function Clock.BossBeaten(completed: { [string]: boolean }, bossId: string): boolean
	for _, objective in Config.All("Objectives") do
		if objective.Kind == "Boss" and objective.Boss == bossId and completed[objective.Id] then
			return true
		end
	end
	return false
end

-- The era a year belongs to; past Year 100 (Endless), the last era.
function Clock.EraOf(year: number): string
	local eras = Config.All("Eras")
	for _, era in eras do
		if year <= era.Years.To then
			return era.Id
		end
	end
	return eras[#eras].Id
end

-- The boss of the final Surge: the boss of the era that ends in the final year.
function Clock.FinalBoss(): string?
	local finalYear = Clock.Tuning().FinalYear
	for _, era in Config.All("Eras") do
		if era.Years.To == finalYear then
			return era.Boss
		end
	end
	return nil
end

-- What the coming Surge is, and its boss (an era boss, or the final boss).
function Clock.SurgeKind(state: State): (SurgeKind, string?)
	local tuning = Clock.Tuning()
	if state.Endless then
		return "Endless", nil
	elseif state.PendingBoss ~= nil then
		return "Boss", state.PendingBoss
	elseif state.Year >= tuning.FinalYear then
		return "Final", Clock.FinalBoss()
	elseif state.Cycle == 1 and tuning.TutorialFirstSurge then
		return "Tutorial", nil
	end
	return "Normal", nil
end

-- Does a Surge of this kind run until its boss is beaten, with no timer?
function Clock.IsOpenEnded(kind: SurgeKind): boolean
	return kind == "Boss" or kind == "Final"
end

-- The Surge begins: its kind and boss. A due era boss is used up (its Surge comes once).
function Clock.StartSurge(state: State): (SurgeKind, string?)
	local kind, boss = Clock.SurgeKind(state)
	if kind == "Boss" then
		state.PendingBoss = nil
	end
	return kind, boss
end

--[[
	The end of a cycle: the year counter jumps by Years per Cycle (stopping at the final year
	outside Endless) and the cycle number goes up. Returns the year before the jump, and the
	era boss that became due because the jump reached or passed the end of its era.
]]
function Clock.EndCycle(state: State): (number, string?)
	local tuning = Clock.Tuning()
	local before = state.Year
	local after = before + Clock.YearsPerCycle(state.Completed)
	if not state.Endless then
		after = math.min(after, tuning.FinalYear)
	end
	state.Year = after
	state.Cycle += 1
	if state.Endless then
		return before, nil
	end
	local due: string? = nil
	for _, era in Config.All("Eras") do
		local last = era.Years.To
		if last < tuning.FinalYear and before < last and after >= last and not Clock.BossBeaten(state.Completed, era.Boss) then
			due = era.Boss
		end
	end
	if due then
		state.PendingBoss = due
	end
	return before, due
end

return table.freeze(Clock)
