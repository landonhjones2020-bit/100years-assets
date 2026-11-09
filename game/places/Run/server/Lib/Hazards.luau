--!strict
--[[
	Hazards: what disasters do to the bunker that other systems must see at once (bible Section 10;
	Prompt 13). Run place, server. DisasterService writes it; Lib.PathGraph, ResidentBrain and
	MonsterService read it. It is a module rather than a service so readers need not depend on
	DisasterService (which itself needs the residents and the combatants).

	* Fires: a room id -> the fire's strength (0 to 100).
	* Blocked passages: cave-in rubble between two graph units (a doorway, or every passage into
	  a tunnel cell). Routes go around them; when there is no way round, residents are trapped.
	* Version() grows with every change to the blocked passages, so walkers know to plan again.
]]

local Hazards = {}

local fires: { [string]: number } = {}
local blocked: { [string]: string } = {} -- "a|b" (sorted) -> the rubble's id
local version = 0

local function edgeKey(a: string, b: string): string
	return if a < b then `{a}|{b}` else `{b}|{a}`
end

Hazards.EdgeKey = edgeKey

-- Fires --------------------------------------------------------------------------------------------

function Hazards.SetFire(unit: string, strength: number?)
	fires[unit] = if strength and strength > 0 then strength else nil
end

function Hazards.Fire(unit: string?): number?
	return if unit then fires[unit] else nil
end

function Hazards.Fires(): { [string]: number }
	return fires
end

-- Blocked passages ---------------------------------------------------------------------------------

function Hazards.Block(a: string, b: string, by: string)
	local key = edgeKey(a, b)
	if blocked[key] ~= by then
		blocked[key] = by
		version += 1
	end
end

-- Opens every passage the rubble `by` blocked.
function Hazards.Unblock(by: string)
	for key, owner in table.clone(blocked) do
		if owner == by then
			blocked[key] = nil
			version += 1
		end
	end
end

function Hazards.Blocked(a: string, b: string): boolean
	return blocked[edgeKey(a, b)] ~= nil
end

-- The rubble blocking a passage, if any.
function Hazards.BlockedBy(a: string, b: string): string?
	return blocked[edgeKey(a, b)]
end

function Hazards.AnyBlocked(): boolean
	return next(blocked) ~= nil
end

-- The units next to `unit` that can be walked to (Bunker:Neighbors without blocked passages).
function Hazards.Neighbors(bunker: any, unit: string): { string }
	local list = bunker:Neighbors(unit)
	if next(blocked) == nil then
		return list
	end
	local open = {}
	for _, other in list do
		if not blocked[edgeKey(unit, other)] then
			table.insert(open, other)
		end
	end
	return open
end

function Hazards.Version(): number
	return version
end

-- Forgets everything (a new run in the same server; DevTools).
function Hazards.Clear()
	table.clear(fires)
	if next(blocked) then
		table.clear(blocked)
		version += 1
	end
end

return Hazards
