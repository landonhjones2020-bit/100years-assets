--!strict
--[[
	Rules.Disasters: the arithmetic of disasters and repairs (bible Sections 6 and 10). Pure, so
	DisasterService and BuildService on the server, the HUD and the Command View on the client
	and the data tests share it. Prompt 13. Numbers: Config.Disasters (each disaster's own) and
	Tuning.Disasters / Tuning.Repairs (the rules), all provisional.

	* Fire: a room burns with a strength from 0 to 100. It grows on its own; residents in the
	  room beat it down; an Extinguisher sprays it down faster; at 0 it is out. Room damage,
	  and the harm to residents and players inside, scale with strength. Every SpreadSeconds
	  (15; FireSpread multipliers slow it) a fire strong enough spreads to a room next door
	  through a doorway; the Shaft doesn't burn, so fires stay on their floor.
	* The Surge's one disaster (Section 5): a weighted pick among the disasters a Surge causes
	  (Config.Disasters SurgeWeight), of this era and before, that the budget can pay for.
	* Blackout: a floor, or the whole grid, dark for DurationSeconds (BlackoutDuration
	  multipliers), unless the fuse box in the Reactor Core is reset first.
	* The meltdown (Section 10's Reactor overload; Landon): three valves turned together stop
	  it. A turned valve counts while its player holds it; with SoloPlayers or fewer in the run,
	  a turned valve stays turned SoloValveSeconds.
	* Cave-in: rubble blocks a doorway (the passage between two units side by side) or fills a
	  dug cell (a tunnel: every passage into it). Melee smashes it, more with weapons that break
	  rubble; a Drill or a Pickaxe digs through it.
	* Repairs (Section 6): the Welder repairs WelderPerSecond (RepairSpeed: the Engineer twice
	  as fast); a worker in the room ResidentRepairPerSecond times Smarts over
	  ResidentSmartsBase (Section 11: Smarts is repair speed).
]]

local Config = require(script.Parent.Parent.Config)

local Disasters = {}

export type Shape = "Doorway" | "Tunnel"

-- A valve held by a player right now (a turned valve otherwise stores until when, server time).
Disasters.HELD = -1

function Disasters.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Disasters")
end

function Disasters.Repairs(): { [string]: any }
	return Config.Get("Tuning", "Repairs")
end

-- Fire ----------------------------------------------------------------------------------------

-- A fire's strength after dt seconds: it grows, `residents` beat it down, `extinguish` (strength a
-- second from Extinguishers) sprays it down. 0 is out.
function Disasters.FireStep(strength: number, dt: number, residents: number, extinguish: number?): number
	local f = Disasters.Tuning().Fire
	local change = f.GrowPerSecond - residents * f.ResidentPerSecond - (extinguish or 0)
	return math.clamp(strength + change * dt, 0, 100)
end

-- HP a burning room loses in dt seconds.
function Disasters.FireRoomDamage(strength: number, dt: number): number
	return (Config.Get("Disasters", "Fire").RoomDamagePerSecond or 0) * strength / 100 * dt
end

-- Health a player inside loses in dt seconds; `taken` is their FireFloodDamageTaken (the
-- Firefighter's 0.25).
function Disasters.FirePlayerDamage(strength: number, dt: number, taken: number?): number
	return Disasters.Tuning().Fire.PlayerDamagePerSecond * strength / 100 * dt * (taken or 1)
end

function Disasters.FireResidentDamage(strength: number, dt: number): number
	return Disasters.Tuning().Fire.ResidentDamagePerSecond * strength / 100 * dt
end

-- Seconds between a fire's spreads (Section 10: every 15 s). FireSpread multipliers below 1
-- slow it: 0.5 is "50% slower", 30 s.
function Disasters.SpreadSeconds(spread: number?): number
	return (Config.Get("Disasters", "Fire").SpreadSeconds or 15) / math.max(spread or 1, 0.05)
end

function Disasters.CanSpread(strength: number): boolean
	return strength >= Disasters.Tuning().Fire.SpreadMinStrength
end

function Disasters.Burns(roomType: string): boolean
	return table.find(Disasters.Tuning().Fire.Fireproof, roomType) == nil
end

-- The rooms a fire in `roomId` can spread to: rooms through a doorway (never dug cells, never
-- up or down: the Shaft doesn't burn) that burn and aren't burning yet. Sorted.
function Disasters.SpreadTargets(bunker: any, roomId: string, burning: { [string]: any }): { string }
	local list = {}
	for _, other in bunker:Neighbors(roomId) do
		local room = bunker:Room(other)
		if room and burning[other] == nil and Disasters.Burns(room.Type) then
			table.insert(list, other)
		end
	end
	table.sort(list)
	return list
end

-- Floods (Prompt 23) --------------------------------------------------------------------------

-- A flood's level after dt seconds. `pipe`: its burst pipe still runs. `fed`: the level of the
-- highest water that pours into it (nil: none). `drain`: the bunker's FloodDrainSpeed.
function Disasters.FloodStep(level: number, dt: number, pipe: boolean, fed: number?, drain: number?): number
	local f = Disasters.Tuning().Flood
	if pipe then
		return math.clamp(level + f.RisePerSecond * dt, 0, 100)
	elseif fed and fed > level then
		return math.min(level + f.OverflowPerSecond * dt, fed)
	end
	return math.max(level - f.DrainPerSecond * math.max(drain or 1, 0.05) * dt, 0)
end

-- How deep in it people are: 0 up to WadeLevel (ankle deep), rising to 1 at level 100.
function Disasters.FloodDepth(level: number): number
	local wade = Disasters.Tuning().Flood.WadeLevel
	return math.clamp((level - wade) / (100 - wade), 0, 1)
end

-- What wading does to walking speed (1: nothing).
function Disasters.WadeSpeed(level: number?): number
	local f = Disasters.Tuning().Flood
	if not level or level < f.WadeLevel then
		return 1
	end
	return f.WadeSpeed + (f.DeepSpeed - f.WadeSpeed) * Disasters.FloodDepth(level)
end

function Disasters.FloodRoomDamage(level: number, dt: number): number
	return (Config.Get("Disasters", "Flood").RoomDamagePerSecond or 0) * level / 100 * dt
end

-- `taken` is the player's FireFloodDamageTaken (the Firefighter's 0.25).
function Disasters.FloodPlayerDamage(level: number, dt: number, taken: number?): number
	return Disasters.Tuning().Flood.PlayerDamagePerSecond * Disasters.FloodDepth(level) * dt * (taken or 1)
end

function Disasters.FloodResidentDamage(level: number, dt: number): number
	return Disasters.Tuning().Flood.ResidentDamagePerSecond * Disasters.FloodDepth(level) * dt
end

function Disasters.FloodSpreadSeconds(): number
	return Config.Get("Disasters", "Flood").SpreadSeconds or 20
end

function Disasters.FloodCanSpread(level: number): boolean
	return level >= Disasters.Tuning().Flood.SpreadMinLevel
end

-- Where the water in `unit` pours next: rooms beside it on its floor and the Shaft below it
-- (Section 10: "pours down the Shaft"; never up, never into bare tunnels), not yet flooded.
-- The way down comes first: water falls before it spreads.
function Disasters.FloodSpreadTargets(bunker: any, unit: string, flooded: { [string]: any }): { string }
	local from = bunker:Room(unit)
	local down, level = {}, {}
	if not from then
		return down
	end
	for _, other in bunker:Neighbors(unit) do
		local room = bunker:Room(other)
		if room and flooded[other] == nil and room.Floor >= from.Floor then
			table.insert(if room.Floor > from.Floor then down else level, other)
		end
	end
	table.sort(down)
	table.sort(level)
	return if #down > 0 then down else level
end

-- The highest water that pours into `unit`: a neighbour on its floor or above it whose level can
-- spread and is higher than its own. nil: nothing feeds it.
function Disasters.FloodFed(bunker: any, unit: string, levels: { [string]: number }): number?
	local room = bunker:Room(unit)
	if not room then
		return nil
	end
	local own = levels[unit] or 0
	local best: number? = nil
	for _, other in bunker:Neighbors(unit) do
		local from = bunker:Room(other)
		local level = levels[other]
		if from and level and from.Floor <= room.Floor and level > own and Disasters.FloodCanSpread(level) then
			best = math.max(best or 0, level)
		end
	end
	return best
end

-- Gas leaks (Prompt 23) -----------------------------------------------------------------------

-- A leak's strength after dt seconds: it fills while the vent leaks, then the room airs out.
function Disasters.GasStep(strength: number, dt: number, leaking: boolean): number
	local g = Disasters.Tuning().Gas
	return math.clamp(strength + (if leaking then g.FillPerSecond else -g.ClearPerSecond) * dt, 0, 100)
end

function Disasters.GasSeconds(): number
	return Config.Get("Disasters", "GasLeak").DurationSeconds or 90
end

-- `bunker` is the GasStrength modifier (Gas Filters: 0.5); `immune` the player's GasImmune;
-- `taken` their GasDamageTaken.
function Disasters.GasPlayerDamage(strength: number, dt: number, bunker: number?, immune: boolean?, taken: number?): number
	if immune then
		return 0
	end
	return Disasters.Tuning().Gas.PlayerDamagePerSecond * strength / 100 * dt * (bunker or 1) * (taken or 1)
end

function Disasters.GasResidentDamage(strength: number, dt: number, bunker: number?, taken: number?): number
	return Disasters.Tuning().Gas.ResidentDamagePerSecond * strength / 100 * dt * (bunker or 1) * (taken or 1)
end

-- What bursts out of a hazard pocket (Section 7: "Gas or water bursts out"), from the band's
-- Hazards: "GasLeak", "Flood", or nil when the band has neither.
function Disasters.HazardKind(hazards: { string }, rng: Random): string?
	local gas = table.find(hazards, "GasLeak") ~= nil
	local water = table.find(hazards, "Flood") ~= nil
	if gas and water then
		return if rng:NextNumber() < Disasters.Tuning().HazardPocket.GasChance then "GasLeak" else "Flood"
	end
	if gas or water then
		return if gas then "GasLeak" else "Flood"
	end
	-- the Crystal Hollows (Prompt 24; Section 12: "radiation in the Crystal Hollows")
	return if table.find(hazards, "RadiationLeak") ~= nil then "RadiationLeak" else nil
end

-- Radiation leaks (Prompt 24) --------------------------------------------------------------------

-- A leak's strength after dt: filling while it leaks (`slow` is DeconSlow while a Decon Room
-- works), fading once it is sealed.
function Disasters.RadiationStep(strength: number, dt: number, leaking: boolean, slow: number?): number
	local r = Disasters.Tuning().Radiation
	return math.clamp(strength + (if leaking then r.FillPerSecond * (slow or 1) else -r.FadePerSecond) * dt, 0, 100)
end

function Disasters.RadiationSeconds(): number
	return Config.Get("Disasters", "RadiationLeak").DurationSeconds or 120
end

-- Radiation a player standing in it takes per second (`gain` is their RadiationGain).
function Disasters.RadiationPlayerRate(strength: number, gain: number?): number
	return Disasters.Tuning().Radiation.PlayerPerSecond * math.clamp(strength, 0, 100) / 100 * math.max(gain or 1, 0)
end

function Disasters.RadiationResidentDamage(strength: number, dt: number, taken: number?): number
	return Disasters.Tuning().Radiation.ResidentDamagePerSecond * math.clamp(strength, 0, 100) / 100 * dt * (taken or 1)
end

-- The odds that a Surge's storm gets through the Blast Door (Section 10: "a weak Blast Door"):
-- by its level, more the more HP it has lost; a wrecked door always leaks; never before FromEra.
function Disasters.DoorLeakChance(era: number, level: number, hpFraction: number, wrecked: boolean): number
	local r = Disasters.Tuning().Radiation
	if era < r.FromEra then
		return 0
	end
	if wrecked then
		return 1
	end
	local base = r.DoorLeakChance[math.clamp(math.floor(level), 1, #r.DoorLeakChance)]
	return math.clamp(base + r.DoorDamagedChance * (1 - math.clamp(hpFraction, 0, 1)), 0, 1)
end

-- Outbreaks (Prompt 24) --------------------------------------------------------------------------

-- Does someone coming in from the Deep carry the sickness? (`roll` is 0 to 1.)
function Disasters.CarriesSickness(era: number, roll: number): boolean
	local o = Disasters.Tuning().Outbreak
	return era >= o.FromEra and roll < o.CarrierChance
end

-- Who a sick resident can pass it to: the others in their room who are well and haven't had it.
-- `people` is { { Id, Room, Sick, Immune, Quarantined } }; the quarantined pass nothing on.
function Disasters.OutbreakTargets(people: { { [string]: any } }, carrier: { [string]: any }): { string }
	local out = {}
	if carrier.Quarantined or not carrier.Sick or not carrier.Room then
		return out
	end
	for _, other in people do
		if other.Id ~= carrier.Id and other.Room == carrier.Room and not other.Sick and not other.Immune then
			table.insert(out, other.Id)
		end
	end
	table.sort(out)
	return out
end

-- Seconds a working Medbay takes over one patient (`speed` is the team's best OutbreakCureSpeed).
function Disasters.CureSeconds(speed: number?): number
	return Disasters.Tuning().Outbreak.CureSeconds / math.max(speed or 1, 0.1)
end

-- The Surge's disaster -------------------------------------------------------------------------

-- Section 5: every Surge brings one disaster. A weighted pick among the disasters with a
-- SurgeWeight, of era `era` and before, whose ThreatCost `budget` covers; nil when none fits.
-- `startable` (optional) narrows it to the disasters whose systems exist (floods and gas leaks:
-- Prompt 23; Landon, Prompt 13: Surges bring cave-ins from Era I, floods and gas leaks from Era II).
function Disasters.SurgePick(era: number, budget: number, rng: Random, startable: { [string]: boolean }?): string?
	local options: { string } = {}
	local total = 0
	for _, id in Config.Ids("Disasters") do
		local d = Config.Get("Disasters", id)
		if (d.SurgeWeight or 0) > 0 and d.Era <= era and d.ThreatCost <= budget and (not startable or startable[id]) then
			table.insert(options, id)
			total += d.SurgeWeight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, id in options do
		roll -= Config.Get("Disasters", id).SurgeWeight
		if roll <= 0 then
			return id
		end
	end
	return options[#options]
end

-- Blackouts ------------------------------------------------------------------------------------

-- How long a blackout lasts (BlackoutDuration multipliers: Insulated Grid's 0.5 halves it).
function Disasters.BlackoutSeconds(duration: number?): number
	return (Config.Get("Disasters", "Blackout").DurationSeconds or 60) * math.max(duration or 1, 0.05)
end

-- Which floor goes dark: nil for the whole grid (WholeGridChance), else one of `floors`.
function Disasters.BlackoutFloor(floors: { number }, rng: Random): number?
	if #floors == 0 or rng:NextNumber() < Disasters.Tuning().Blackout.WholeGridChance then
		return nil
	end
	return floors[rng:NextInteger(1, #floors)]
end

-- The units (rooms and dug cells) a blackout darkens: those on `floor`, or all of them.
function Disasters.BlackoutUnits(bunker: any, floor: number?): { [string]: boolean }
	local units: { [string]: boolean } = {}
	for _, unit in bunker:Units() do
		local cell = bunker:CellsOf(unit)[1]
		if cell and (floor == nil or cell[1] == floor) then
			units[unit] = true
		end
	end
	return units
end

-- The meltdown -----------------------------------------------------------------------------------

-- A valve a player has just turned: until when it counts (server time), or HELD (while held).
function Disasters.ValveTurned(players: number, now: number): number
	local m = Disasters.Tuning().Meltdown
	if players <= m.SoloPlayers then
		return now + m.SoloValveSeconds
	end
	return Disasters.HELD
end

-- A valve let go of: alone or in two, it keeps its SoloValveSeconds; in a team, a held valve
-- counts a moment longer (network slack), then it is open again.
function Disasters.ValveReleased(value: number, players: number, now: number): number
	local m = Disasters.Tuning().Meltdown
	if value ~= Disasters.HELD then
		return value
	end
	return now + (if players <= m.SoloPlayers then m.SoloValveSeconds else m.HeldGraceSeconds)
end

function Disasters.ValveOn(value: number, now: number): boolean
	return value == Disasters.HELD or value > now
end

function Disasters.ValvesOn(valves: { number }, now: number): number
	local n = 0
	for _, value in valves do
		if Disasters.ValveOn(value, now) then
			n += 1
		end
	end
	return n
end

-- All three valves turned at once: the meltdown stops (Section 10).
function Disasters.MeltdownStopped(valves: { number }, now: number): boolean
	return #valves >= 3 and Disasters.ValvesOn(valves, now) == #valves
end

-- Cave-ins --------------------------------------------------------------------------------------

function Disasters.RubbleHP(shape: Shape): number
	local c = Disasters.Tuning().CaveIn
	return if shape == "Tunnel" then c.TunnelHP else c.DoorwayHP
end

-- Seconds of digging that clear rubble (DigSpeed multipliers: the Driller's 2 halves it).
function Disasters.DigSeconds(shape: Shape, digSpeed: number?): number
	local c = Disasters.Tuning().CaveIn
	return (if shape == "Tunnel" then c.TunnelDigSeconds else c.DigSeconds) / math.max(digSpeed or 1, 0.05)
end

-- What a melee hit does to rubble: weapons that break rubble (the Fire Axe, the Sledgehammer)
-- do BreakerMultiplier times their damage; others their damage.
function Disasters.RubbleDamage(itemId: string, damage: number): number
	local item = Config.Find("Items", itemId)
	local breaks = item ~= nil and item.Melee ~= nil and item.Melee.BreaksRubble == true
	return damage * (if breaks then Disasters.Tuning().CaveIn.BreakerMultiplier else 1)
end

-- Can someone carrying `items` dig through rubble? (A Drill or a Pickaxe.)
function Disasters.CanDig(items: { string }): boolean
	for _, id in items do
		if table.find(Disasters.Tuning().CaveIn.DigItems, id) then
			return true
		end
	end
	return false
end

-- The passages rubble blocks, as pairs of graph units. A doorway: between (floor, column) and
-- its neighbour to the Left or Right, two open cells of different units. A tunnel: a dug cell,
-- every passage into it. Empty when there is nothing to block.
function Disasters.RubbleEdges(bunker: any, shape: Shape, floor: number, column: number, side: string?): { { string } }
	local here = bunker:UnitAt(floor, column)
	if not here then
		return {}
	end
	if shape == "Tunnel" then
		if bunker:State(floor, column) ~= "Dug" then
			return {}
		end
		local edges = {}
		for _, other in bunker:Neighbors(here) do
			table.insert(edges, { here, other })
		end
		return edges
	end
	local otherColumn = if side == "Left" then column - 1 else column + 1
	local other = bunker:UnitAt(floor, otherColumn)
	if not other or other == here then
		return {}
	end
	return { { here, other } }
end

-- Every doorway in the bunker, for cave-ins to fall in (Prompt 14's Tremors): { Floor, Column,
-- Side = "Right" } for each pair of open cells side by side in different units.
function Disasters.Doorways(bunker: any): { { Floor: number, Column: number, Side: string } }
	local list = {}
	for _, unit in bunker:Units() do
		for _, cell in bunker:CellsOf(unit) do
			local right = bunker:UnitAt(cell[1], cell[2] + 1)
			if right and right ~= unit then
				table.insert(list, { Floor = cell[1], Column = cell[2], Side = "Right" })
			end
		end
	end
	table.sort(list, function(a, b)
		return if a.Floor ~= b.Floor then a.Floor < b.Floor else a.Column < b.Column
	end)
	return list
end

-- Electrical surges ------------------------------------------------------------------------------

-- The chance a day brings an electrical surge (Section 10: random, more often in Era III).
function Disasters.ElectricalChance(era: number): number
	local chances = Disasters.Tuning().ElectricalSurge.EraChance
	return chances[math.clamp(math.floor(era), 1, #chances)] or 0
end

-- What an unwelded surge leaves behind when it ends (Section 10: they cause fires and
-- blackouts): "Fire", "Blackout" or nil.
function Disasters.SurgeAftermath(rng: Random): string?
	local e = Disasters.Tuning().ElectricalSurge
	local roll = rng:NextNumber()
	if roll < e.FireChance then
		return "Fire"
	elseif roll < e.FireChance + e.BlackoutChance then
		return "Blackout"
	end
	return nil
end

-- Repairs -----------------------------------------------------------------------------------------

-- HP a second from a Welder (RepairSpeed: the Engineer's 2).
function Disasters.WelderPerSecond(repairSpeed: number?): number
	return Disasters.Repairs().WelderPerSecond * (repairSpeed or 1)
end

-- HP a second from one resident working in the room, by their Smarts.
function Disasters.ResidentRepairPerSecond(smarts: number): number
	return Config.Get("Tuning", "Rooms").ResidentRepairPerSecond * math.max(smarts, 0) / Disasters.Repairs().ResidentSmartsBase
end

-- HP a wrecked room needs before it works again.
function Disasters.RepairedAt(maxHP: number): number
	return math.ceil(maxHP * Disasters.Repairs().RepairedAt)
end

return table.freeze(Disasters)
