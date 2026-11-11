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
	* Shell: what a hit on a shelled monster does, by where it comes from (Prompt 23).
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

-- A shelled monster's hit (the Tide Crab: "Armoured front, weak point on its back"; Tuning.MonsterAI).
-- `dot` is how far in front the attacker stands (1: dead ahead, -1: straight behind). Returns the
-- damage multiplier and what was hit: "Shell", "Weak" or nil.
function Threat.Shell(dot: number, armoredFront: boolean, weakBack: boolean): (number, string?)
	local t = Config.Get("Tuning", "MonsterAI")
	if armoredFront and dot >= math.cos(math.rad(t.ArmorArcDegrees / 2)) then
		return t.ArmorFront, "Shell"
	elseif weakBack and dot <= -math.cos(math.rad(t.WeakArcDegrees / 2)) then
		return t.WeakBack, "Weak"
	end
	return 1, nil
end

-- The Crystal Hollows' monsters (Prompt 24) ---------------------------------------------------------

-- Is `position` lit by a flare or a lamp? `lights` are { Position, Radius }; a light reaches its
-- Radius along the floor and LightHeight up and down (so one a floor away shows nothing).
function Threat.Lit(position: Vector3, lights: { { Position: Vector3, Radius: number } }): boolean
	local height = Config.Get("Tuning", "MonsterAI").LightHeight
	for _, light in lights do
		local offset = position - light.Position
		if math.abs(offset.Y) <= height and Vector3.new(offset.X, 0, offset.Z).Magnitude <= light.Radius then
			return true
		end
	end
	return false
end

-- A Prism Stalker is seen while a light is on it and for StalkerRevealSeconds after it strikes or
-- is hit (`shownUntil`).
function Threat.StalkerSeen(lit: boolean, now: number, shownUntil: number?): boolean
	return lit or (shownUntil ~= nil and now < shownUntil)
end

-- What a Geode Golem takes of a shot from `itemId` ("shrugs off small guns"): SmallGunMultiplier
-- from a small gun (Config.Items: Gun.Small), all of it from anything else.
function Threat.SmallGunMultiplier(itemId: string?): number
	local item = if itemId then Config.Find("Items", itemId) else nil
	if item and item.Gun and item.Gun.Small then
		return Config.Get("Tuning", "MonsterAI").SmallGunMultiplier
	end
	return 1
end

-- A Resonator's hum on a monster with `health` of `max`: what it heals.
function Threat.HumHeal(health: number, max: number): number
	if health <= 0 or health >= max then
		return 0
	end
	return math.min(max - health, max * Config.Get("Tuning", "MonsterAI").HumHealFraction)
end

-- A dead Shardling's shards: what they do to someone `distance` studs away.
function Threat.ShatterDamage(distance: number): number
	local t = Config.Get("Tuning", "MonsterAI")
	return if distance <= t.ShatterRadius then t.ShatterDamage else 0
end

return Threat
