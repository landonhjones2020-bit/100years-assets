--!strict
--[[
	Rules.Threat: the Threat Director's arithmetic (bible Section 10), pure so DataTests can hold
	it to the bible. Prompt 12.

	* Level: threat rises with the year, the deepest floor reached, Disturbance, bunker size and
	  player count (Tuning.Threat, provisional).
	* SurgeBudget: what a Surge spends on monster groups; the first cycle's Surge is a small
	  tutorial wave (Section 5), and a player's first run is 30% easier in Era I (Section 22).
	* Roster: the monsters an era sends (Section 5's eras: each brings its band's creatures, Era
	  IV everything before). Surface monsters come with storms and raids (Prompt 16), not breaches.
	* Groups: a budget spent on groups of monsters (each type's Group size and ThreatCost), with
	  variety; Pick: one breach point, weighted.
]]

local Config = require(script.Parent.Parent.Config)

local Threat = {}

export type Inputs = {
	Year: number,
	DeepestFloor: number,
	Disturbance: number,
	Rooms: number,
	Players: number,
}

export type Group = { Type: string, Count: number }

local function tuning(): { [string]: any }
	return Config.Get("Tuning", "Threat")
end

function Threat.Level(inputs: Inputs): number
	local t = tuning()
	local players = math.clamp(math.floor(inputs.Players), 1, #t.PlayerScale)
	local base = t.Base + t.PerYear * inputs.Year + t.PerDeepestFloor * inputs.DeepestFloor
		+ t.PerDisturbance * inputs.Disturbance + t.PerRoom * inputs.Rooms
	return base * t.PlayerScale[players]
end

-- What a Surge spends. kind is the CycleClock's Surge kind; boss Surges bring their boss
-- instead (Prompt 15), so they spend nothing here.
function Threat.SurgeBudget(level: number, kind: string, firstRunEraI: boolean): number
	local t = tuning()
	if kind == "Tutorial" then
		return t.TutorialSurgeBudget
	elseif kind == "Boss" or kind == "Final" then
		return 0
	end
	return level * (if firstRunEraI then t.FirstRunEraIMultiplier else 1)
end

-- Between Surges: a small amount each cycle (spread over the day).
function Threat.TrickleBudget(level: number, firstRunEraI: boolean): number
	local t = tuning()
	return level * t.BetweenSurgesFraction * (if firstRunEraI then t.FirstRunEraIMultiplier else 1)
end

function Threat.EraNumber(era: string | number): number
	if type(era) == "number" then
		return math.clamp(math.floor(era), 1, 4)
	end
	local entry = Config.Find("Eras", era)
	return if entry then entry.Number else 1
end

-- The monsters that come through breaches by an era: every era's NewMonsters up to it (Section
-- 5's era table; Era IV brings "everything before, stronger"). Sorted, so picks repeat with a seed.
-- Surface monsters come with storms and raids (Prompt 16), not breaches.
function Threat.Roster(era: string | number): { string }
	local n = Threat.EraNumber(era)
	local list = {}
	for _, entry in Config.All("Eras") do
		if entry.Number <= n then
			for _, id in entry.NewMonsters or {} do
				local monster = Config.Find("Monsters", id)
				local surfaceOnly = monster ~= nil and #monster.Where == 1 and monster.Where[1] == "Surface"
				if monster and not surfaceOnly and not table.find(list, id) then
					table.insert(list, id)
				end
			end
		end
	end
	table.sort(list)
	return list
end

-- Spends a budget on groups: each pick is a type whose cost fits what is left, the types used
-- least so far first (variety), then a group size from its Group range that the budget covers.
-- Leftovers smaller than the cheapest monster are dropped. rng: a Random.
function Threat.Groups(budget: number, roster: { string }, rng: Random): { Group }
	local groups: { Group } = {}
	local left = budget
	local used: { [string]: number } = {}
	local guard = 0
	while guard < 40 do
		guard += 1
		local fits = {}
		for _, id in roster do
			local monster = Config.Get("Monsters", id)
			if monster.ThreatCost <= left then
				table.insert(fits, id)
			end
		end
		if #fits == 0 then
			break
		end
		local fewest = math.huge
		for _, id in fits do
			fewest = math.min(fewest, used[id] or 0)
		end
		local least = {}
		for _, id in fits do
			if (used[id] or 0) == fewest then
				table.insert(least, id)
			end
		end
		local id = least[rng:NextInteger(1, #least)]
		local monster = Config.Get("Monsters", id)
		local most = math.min(monster.Group.Max, math.floor(left / monster.ThreatCost))
		local least_ = math.min(monster.Group.Min, most)
		local count = rng:NextInteger(least_, most)
		table.insert(groups, { Type = id, Count = count })
		used[id] = (used[id] or 0) + 1
		left -= count * monster.ThreatCost
	end
	return groups
end

-- The total cost of some groups.
function Threat.Cost(groups: { Group }): number
	local total = 0
	for _, group in groups do
		total += Config.Get("Monsters", group.Type).ThreatCost * group.Count
	end
	return total
end

export type Point = { Id: string, Weight: number }

-- One point, by weight (dark rooms count double, barricaded points less: BreachService).
function Threat.Pick(points: { Point }, rng: Random): Point?
	local total = 0
	for _, point in points do
		total += math.max(point.Weight, 0)
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, point in points do
		roll -= math.max(point.Weight, 0)
		if roll <= 0 then
			return point
		end
	end
	return points[#points]
end

-- Target priority: which of a monster's Targets it goes for, given what is available. Targets
-- is the type's own order (Section 10: residents first, then machines, then players who hit
-- them; each type its own); available says which kinds have a reachable target now.
function Threat.Choose(targets: { string }, available: { [string]: boolean }): string?
	for _, kind in targets do
		if available[kind] then
			return kind
		end
	end
	return nil
end

return Threat
