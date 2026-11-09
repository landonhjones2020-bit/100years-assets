--!strict
--[[
	Rules.Expeditions: resident expeditions and the radio (bible Sections 11 and 12; Prompt 18).
	Pure, so ExpeditionService, the Expeditions screen and the data tests share it. Numbers are
	Tuning.Expeditions (provisional); log lines are Config.ExpeditionLogs.

	* Who goes: 1 to 3 residents (Size), alive, in the bunker and not trapped by rubble. How long:
	  1, 2 or 3 cycles (Cycles), the players' choice (Section 12).
	* Supplies (Section 12: "with gear and supplies"): Food and Water for every member for every
	  cycle away (they eat away what they would eat at home: Tuning.Residents FoodPerCycle and
	  WaterPerCycle), taken from the stockpile when they set out, plus up to MedkitsMax Medkits.
	  What they don't use comes home with them.
	* Danger, once a cycle away (Section 12: "length and danger depend on Speed, Grit, gear and
	  supplies"): the chance someone is hurt (HurtChance), the team radios a distress call
	  (DistressChance) or someone is lost (BaseLossChance), each times the destination's Danger
	  and the team's Risk. Risk comes from the team's average of Grit and Speed (Section 11: Grit
	  resists harm, Speed is fleeing): StatStep less per point above StatPivot, more per point
	  below, kept within RiskMin..RiskMax. Gear (Prompt 26) will lower it further.
	* Medkits (supplies): a packed Medkit is used when someone is hurt (they keep MedkitHurtKept of
	  the harm) or would be lost (hurt instead: badly, the full harm).
	* Finds, once a cycle away (Section 12: Scrap, ore, gear, blueprints and sometimes a recruit):
	  the destination's loot table rolled once, its resources times the team's Carry. A member
	  carries CarryBase + Strength x CarryPerStrength (Section 11: Strength is carrying on
	  expeditions) times their ExpeditionCarry; Scrap also takes the team's ExpeditionScrap and
	  everything its ExpeditionLoot (a member's own effects: traits from Prompt 26, a Legend's
	  signature from Prompt 27).
	* A distress call (Section 12): players have until the end of the next day phase to reach
	  them: the day of the cycle after the one the call came in (Deadline).
]]

local Config = require(script.Parent.Parent.Config)
local Loot = require(script.Parent.Loot)
local Modifiers = require(script.Parent.Modifiers)

local Expeditions = {}

export type Stats = { [string]: number }
export type Event = "Quiet" | "Hurt" | "Distress" | "Lost"
export type Odds = { Hurt: number, Distress: number, Lost: number }
export type Candidate = { State: string, Trapped: boolean? }

local DESTINATIONS = { "Surface", "Deep" }

function Expeditions.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Expeditions")
end

function Expeditions.Destinations(): { string }
	return table.clone(DESTINATIONS)
end

function Expeditions.IsDestination(destination: any): boolean
	return type(destination) == "string" and table.find(DESTINATIONS, destination) ~= nil
end

-- The loot table a destination rolls each cycle.
function Expeditions.LootTable(destination: string): string
	local t = Expeditions.Tuning()
	return if destination == "Deep" then t.DeepLoot else t.SurfaceLoot
end

-- Food and Water for the whole trip.
function Expeditions.Supplies(members: number, cycles: number): { Food: number, Water: number }
	local r = Config.Get("Tuning", "Residents")
	return { Food = math.ceil(members * cycles * r.FoodPerCycle), Water = math.ceil(members * cycles * r.WaterPerCycle) }
end

--[[
	Whether a team can set out: (true) or (false, why). `members` are the chosen residents' records
	(State, Trapped), in order; ids must not repeat (the caller checks).
]]
function Expeditions.Check(destination: any, members: { Candidate }, cycles: any, medkits: any): (boolean, string?)
	local t = Expeditions.Tuning()
	if not Expeditions.IsDestination(destination) then
		return false, "Pick the surface or the Deep."
	end
	if #members < t.Size.Min then
		return false, "Pick who goes: 1 to 3 residents."
	end
	if #members > t.Size.Max then
		return false, `{t.Size.Max} residents at most.`
	end
	if type(cycles) ~= "number" or cycles ~= math.floor(cycles) or cycles < t.Cycles.Min or cycles > t.Cycles.Max then
		return false, `An expedition lasts {t.Cycles.Min} to {t.Cycles.Max} cycles.`
	end
	if type(medkits) ~= "number" or medkits ~= math.floor(medkits) or medkits < 0 or medkits > t.MedkitsMax then
		return false, `{t.MedkitsMax} Medkits at most.`
	end
	for _, member in members do
		if member.State == "Away" then
			return false, "Someone in the team is already away."
		elseif member.State ~= "Alive" then
			return false, "Someone in the team is down or gone."
		elseif member.Trapped then
			return false, "Someone in the team is cut off by rubble."
		end
	end
	return true, nil
end

-- The team's Risk: 1 at an average Grit and Speed of StatPivot, lower for tougher, faster teams.
function Expeditions.Risk(team: { Stats }): number
	local t = Expeditions.Tuning()
	if #team == 0 then
		return 1
	end
	local sum = 0
	for _, stats in team do
		sum += ((stats.Grit or 0) + (stats.Speed or 0)) / 2
	end
	local average = sum / #team
	return math.clamp(1 - (average - t.StatPivot) * t.StatStep, t.RiskMin, t.RiskMax)
end

-- Each cycle's chances of trouble.
function Expeditions.Odds(destination: string, team: { Stats }): Odds
	local t = Expeditions.Tuning()
	local scale = (t.Danger[destination] or 1) * Expeditions.Risk(team)
	return {
		Hurt = math.clamp(t.HurtChance * scale, 0, 0.9),
		Distress = math.clamp(t.DistressChance * scale, 0, 0.9),
		Lost = math.clamp(t.BaseLossChance * scale, 0, 0.9),
	}
end

-- What happened this cycle, for a roll x in [0, 1): someone lost, a distress call, someone hurt, or nothing.
function Expeditions.Event(odds: Odds, x: number): Event
	if x < odds.Lost then
		return "Lost"
	elseif x < odds.Lost + odds.Distress then
		return "Distress"
	elseif x < odds.Lost + odds.Distress + odds.Hurt then
		return "Hurt"
	end
	return "Quiet"
end

-- "LOW", "MEDIUM" or "HIGH": the chance a cycle goes wrong at all.
function Expeditions.RiskLabel(odds: Odds): string
	local any = odds.Hurt + odds.Distress + odds.Lost
	return if any < 0.3 then "LOW" elseif any < 0.5 then "MEDIUM" else "HIGH"
end

-- One member's share of the carrying.
function Expeditions.Carry(stats: Stats, effects: { any }?): number
	local t = Expeditions.Tuning()
	return (t.CarryBase + (stats.Strength or 0) * t.CarryPerStrength) * (Modifiers.Fold(effects, "ExpeditionCarry") or 1)
end

--[[
	The team's multipliers from its members: Carry (the sum of their shares), Loot and Scrap (the best
	member's ExpeditionLoot and ExpeditionScrap: a Lucky member's luck is the team's).
]]
function Expeditions.Team(team: { Stats }, effects: { { any } }?): { Carry: number, Loot: number, Scrap: number }
	local carry, loot, scrap = 0, 1, 1
	for i, stats in team do
		local own = if effects then effects[i] else nil
		carry += Expeditions.Carry(stats, own)
		loot = math.max(loot, Modifiers.Fold(own, "ExpeditionLoot") or 1)
		scrap = math.max(scrap, Modifiers.Fold(own, "ExpeditionScrap") or 1)
	end
	return { Carry = carry, Loot = loot, Scrap = scrap }
end

-- A cycle's finds scaled for the team: resources times Carry and Loot (Scrap also times Scrap); specials as rolled.
function Expeditions.Scale(drops: { Loot.Drop }, team: { Carry: number, Loot: number, Scrap: number }): { Loot.Drop }
	local out = {}
	for _, drop in drops do
		if drop.Resource then
			local multiplier = team.Carry * team.Loot * (if drop.Resource == "Scrap" then team.Scrap else 1)
			local count = math.floor(drop.Count * multiplier + 0.5)
			if count > 0 then
				table.insert(out, { Resource = drop.Resource, Count = count })
			end
		else
			table.insert(out, table.clone(drop))
		end
	end
	return out
end

-- What a cycle finds on average, resources only (the Expeditions screen): resource -> amount.
function Expeditions.Expected(destination: string, team: { Carry: number, Loot: number, Scrap: number },
	bandOre: string?, skip: { [string]: boolean }?): { [string]: number }
	local tableId = Expeditions.LootTable(destination)
	local lines = Loot.Lines(tableId, { BandOre = bandOre, Skip = skip })
	local total = 0
	for _, line in lines do
		total += line.Weight
	end
	local out: { [string]: number } = {}
	if total <= 0 then
		return out
	end
	local rolls = Config.Get("LootTables", tableId).Rolls
	for _, line in lines do
		local resource = if line.Special == "BandOre" then bandOre else line.Resource
		if resource then
			local each = (line.Min + math.max(line.Min, line.Max)) / 2
			local multiplier = team.Carry * team.Loot * (if resource == "Scrap" then team.Scrap else 1)
			out[resource] = (out[resource] or 0) + rolls * (line.Weight / total) * each * multiplier
		end
	end
	return out
end

-- The harm when someone is hurt: a share of their max health (HurtShare), less with a Medkit.
function Expeditions.Harm(maxHealth: number, x: number, medkit: boolean): number
	local t = Expeditions.Tuning()
	local share = t.HurtShare.Min + (t.HurtShare.Max - t.HurtShare.Min) * math.clamp(x, 0, 1)
	local harm = maxHealth * share * (if medkit then t.MedkitHurtKept else 1)
	return math.max(1, math.floor(harm + 0.5))
end

-- The cycle whose day phase is the last chance to reach a team that radioed in `cycle`.
function Expeditions.Deadline(cycle: number): number
	return cycle + 1
end

-- A recruit's tier for a roll x in [0, 1): Rare at `chance`, else Common.
function Expeditions.RecruitTier(x: number, chance: number): string
	return if x < math.clamp(chance, 0, 1) then "Rare" else "Common"
end

-- "Mara", "Mara and Jude", "Mara, Jude and Ana".
function Expeditions.Names(names: { string }): string
	if #names <= 1 then
		return names[1] or "nobody"
	end
	return `{table.concat(names, ", ", 1, #names - 1)} and {names[#names]}`
end

-- A place's name as it reads mid-sentence: "the motel", "the Main Street diner", "the Mines".
function Expeditions.Place(name: string): string
	local lower = string.lower(name)
	lower = string.gsub(lower, "main street", "Main Street")
	lower = string.gsub(lower, "steadfast", "Steadfast")
	lower = string.gsub(lower, "^mines$", "Mines")
	lower = string.gsub(lower, "flooded caverns", "Flooded Caverns")
	lower = string.gsub(lower, "crystal hollows", "Crystal Hollows")
	lower = string.gsub(lower, "source chamber", "Source Chamber")
	return "the " .. lower
end

-- A log line with its blanks filled: {name}, {names}, {place}.
function Expeditions.Fill(text: string, fields: { [string]: string }): string
	return (string.gsub(text, "{(%a+)}", function(key: string): string?
		return fields[key]
	end))
end

-- The lines Config.ExpeditionLogs has for a destination and event (its own, then those for Any).
function Expeditions.Lines(destination: string, event: string): { string }
	local list = {}
	for _, id in Config.Ids("ExpeditionLogs") do
		local entry = Config.Get("ExpeditionLogs", id)
		if entry.Event == event and (entry.Destination == destination or entry.Destination == "Any") then
			table.insert(list, entry.Text)
		end
	end
	return list
end

return table.freeze(Expeditions)
