--!strict
--[[
	Rules.Surface: the surface's arithmetic (bible Sections 9, 12 and 13; Prompt 16). Pure, so the
	data tests, the server and the client share it. The numbers are Tuning.Surface (provisional).

	* Zones: Zone(position) is "Surface" above Tuning.Surface.ZoneY (the town is high above the
	  bunker, Section 23), "Deep" behind the grid (the caves, Prompt 17: z past Tuning.Deep.GridBack),
	  else "Bunker". Realm(zone) joins the Bunker and the Deep ("Underground"): they touch through
	  the cave mouths, so people follow and monsters hunt across them.
	* Radiation (Section 9: 0 to 100, builds on the surface, faster in a storm; at 100 it drains
	  health): RadiationRate(zone, storm, gain) per second.
	* Backpacks (Section 12: 10 slots, Scavenger +8, Big Backpack +5): a pack is a list of stacks
	  { Id, Count }, an Id being a resource (Config.Resources) or an item; each stack fills one slot
	  up to Stack(id). Fit adds as much as fits; Merge pours one pack into another; Unload hands the
	  stockpile what it has room for and keeps the rest; Used and Summary describe a pack.
	* Carrying (Section 12: big finds are carried with both hands, slowly; two carriers move
	  faster): CarrySpeed(carriers).
	* Spawns: SpawnSpot picks a marker at the right distance from the players.

		Surface.Fit({}, 10, "Scrap", 120) -- { { Id = "Scrap", Count = 50 }, { Id = "Scrap", Count = 50 }, { Id = "Scrap", Count = 20 } }, 120
]]

local Config = require(script.Parent.Parent.Config)

local Surface = {}

export type Zone = "Surface" | "Bunker" | "Deep"
export type Stack = { Id: string, Count: number }
export type Pack = { Stack }

function Surface.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Surface")
end

-- Zones -------------------------------------------------------------------------------------------

function Surface.Zone(position: Vector3): Zone
	if position.Y > Surface.Tuning().ZoneY then
		return "Surface"
	end
	return if position.Z < Config.Get("Tuning", "Deep").GridBack then "Deep" else "Bunker"
end

-- The Bunker and the Deep are one realm ("Underground"): a cave mouth is a walk away.
function Surface.Realm(zone: string): string
	return if zone == "Surface" then "Surface" else "Underground"
end

function Surface.SameRealm(a: Vector3, b: Vector3): boolean
	return Surface.Realm(Surface.Zone(a)) == Surface.Realm(Surface.Zone(b))
end

-- Radiation ----------------------------------------------------------------------------------------

-- Per second: only on the surface; a storm's rate during a Surge; gain is the RadiationGain modifier.
function Surface.RadiationRate(zone: string, storm: boolean, gain: number?): number
	if zone ~= "Surface" then
		return 0
	end
	local t = Surface.Tuning()
	return (if storm then t.StormRadiationPerSecond else t.RadiationPerSecond) * math.max(gain or 1, 0)
end

-- Backpacks ----------------------------------------------------------------------------------------

-- How many of one thing fill a slot.
function Surface.Stack(id: string): number
	local t = Surface.Tuning()
	return t.Stacks[id] or t.ItemStack
end

-- The pack's slots: the bible's 10 plus the BackpackSlots modifier (Scavenger +8, Scout's level 2 +5).
function Surface.Slots(extra: number?): number
	return Config.Get("Tuning", "Player").BackpackSlots + math.max(math.floor(extra or 0), 0)
end

function Surface.Used(pack: Pack): number
	return #pack
end

local function copy(pack: Pack): Pack
	local out: Pack = {}
	for _, stack in pack do
		table.insert(out, { Id = stack.Id, Count = stack.Count })
	end
	return out
end

-- Adds up to count of id: tops up its stacks, then opens new slots while there are free ones.
-- Returns the new pack and how many it took.
function Surface.Fit(pack: Pack, slots: number, id: string, count: number): (Pack, number)
	local out = copy(pack)
	local size = Surface.Stack(id)
	local left = math.max(math.floor(count), 0)
	for _, stack in out do
		if left <= 0 then
			break
		end
		if stack.Id == id and stack.Count < size then
			local add = math.min(size - stack.Count, left)
			stack.Count += add
			left -= add
		end
	end
	while left > 0 and #out < slots do
		local add = math.min(size, left)
		table.insert(out, { Id = id, Count = add })
		left -= add
	end
	return out, math.max(math.floor(count), 0) - left
end

-- Pours `from` into `into` (a dropped pack picked up): returns the new pack and what didn't fit.
function Surface.Merge(into: Pack, from: Pack, slots: number): (Pack, Pack)
	local out = copy(into)
	local leftover: Pack = {}
	for _, stack in from do
		local took
		out, took = Surface.Fit(out, slots, stack.Id, stack.Count)
		if took < stack.Count then
			table.insert(leftover, { Id = stack.Id, Count = stack.Count - took })
		end
	end
	return out, leftover
end

-- Unloading at the Blast Door hall or Storage (Section 12: loot only counts once dropped there):
-- room[id] is how much more of a resource the stockpile can hold. Returns what was delivered
-- (id -> count) and the pack that's left (what the stockpile had no room for, and anything that
-- isn't a stockpile resource).
function Surface.Unload(pack: Pack, room: { [string]: number }): ({ [string]: number }, Pack)
	local space: { [string]: number } = {}
	for id, n in room do
		space[id] = math.max(math.floor(n), 0)
	end
	local delivered: { [string]: number } = {}
	local leftover: Pack = {}
	for _, stack in pack do
		local can = math.min(stack.Count, space[stack.Id] or 0)
		if can > 0 then
			delivered[stack.Id] = (delivered[stack.Id] or 0) + can
			space[stack.Id] -= can
		end
		if stack.Count - can > 0 then
			table.insert(leftover, { Id = stack.Id, Count = stack.Count - can })
		end
	end
	return delivered, leftover
end

-- Totals by id, in first-seen order: { { Id, Count } } with one entry per id.
function Surface.Totals(pack: Pack): Pack
	local byId: { [string]: Stack } = {}
	local order: Pack = {}
	for _, stack in pack do
		local have = byId[stack.Id]
		if have then
			have.Count += stack.Count
		else
			local entry = { Id = stack.Id, Count = stack.Count }
			byId[stack.Id] = entry
			table.insert(order, entry)
		end
	end
	return order
end

local function nameOf(id: string): string
	local resource = Config.Find("Resources", id)
	if resource then
		return resource.Name
	end
	local card = Config.Find("DraftCards", id) -- a blueprint (Prompt 19)
	if card then
		return `blueprint: {card.Name}`
	end
	local item = Config.Find("Items", id)
	return if item then item.Name else id
end

-- "50 SCRAP · 8 FOOD" (totals), or "EMPTY".
function Surface.Summary(pack: Pack): string
	local parts = {}
	for _, stack in Surface.Totals(pack) do
		table.insert(parts, `{stack.Count} {string.upper(nameOf(stack.Id))}`)
	end
	return if #parts > 0 then table.concat(parts, " · ") else "EMPTY"
end

-- The compact form the server puts in the Pack attribute: "Scrap:50,Food:8" (totals).
function Surface.Encode(pack: Pack): string
	local parts = {}
	for _, stack in Surface.Totals(pack) do
		table.insert(parts, `{stack.Id}:{stack.Count}`)
	end
	return table.concat(parts, ",")
end

function Surface.Decode(text: string?): Pack
	local out: Pack = {}
	for id, n in string.gmatch(text or "", "([%w_]+):(%d+)") do
		table.insert(out, { Id = id, Count = tonumber(n) or 0 })
	end
	return out
end

-- Carrying -----------------------------------------------------------------------------------------

-- The walk-speed multiplier for a big find with this many carriers (0: not carrying).
function Surface.CarrySpeed(carriers: number): number
	if carriers <= 0 then
		return 1
	end
	local t = Surface.Tuning()
	return if carriers >= 2 then t.TeamCarryWalkMultiplier else t.CarryWalkMultiplier
end

-- Spawns -------------------------------------------------------------------------------------------

local function nearest(point: Vector3, players: { Vector3 }): number
	local best = math.huge
	for _, at in players do
		best = math.min(best, (Vector3.new(at.X, 0, at.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude)
	end
	return best
end

-- A spawn marker between range.Min and range.Max (flat studs) from the nearest player, picked at
-- random; failing that, the one closest to that band that is at least range.Min / 2 away. Nil
-- with no players or no markers far enough.
function Surface.SpawnSpot(points: { Vector3 }, players: { Vector3 }, range: { Min: number, Max: number }, rng: Random): Vector3?
	if #players == 0 or #points == 0 then
		return nil
	end
	local inBand: { Vector3 } = {}
	local fallback, fallbackGap = nil, math.huge
	for _, point in points do
		local d = nearest(point, players)
		if d >= range.Min and d <= range.Max then
			table.insert(inBand, point)
		elseif d >= range.Min / 2 then
			local gap = if d < range.Min then range.Min - d else d - range.Max
			if gap < fallbackGap then
				fallback, fallbackGap = point, gap
			end
		end
	end
	if #inBand > 0 then
		return inBand[rng:NextInteger(1, #inBand)]
	end
	return fallback
end

-- A survivor's tier: Rare RareSurvivorChance of the time (Section 12: "sometimes a Rare one").
function Surface.SurvivorTier(roll: number): string
	return if roll < Surface.Tuning().RareSurvivorChance then "Rare" else "Common"
end

return table.freeze(Surface)
