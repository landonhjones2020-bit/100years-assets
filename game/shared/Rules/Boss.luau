--!strict
--[[
	Rules.Boss: boss fights as arithmetic (bible Sections 10 and 22; Prompt 15). Pure, so BossService,
	BossController, WeaponService and the data tests agree. The numbers are Config.Bosses (health,
	phases), Tuning.Bosses (every boss) and Tuning.<BossId> (one boss's fight), provisional.

	* Health: Config.Bosses' Health times Threat.PlayerScale for the team (Section 5: the threat
	  scales with player count), times FirstRunHealth on an account's first run for an Era I boss
	  (Section 22: the Brood Mother is weaker).
	* Phases: a boss with N phases moves to the next at each Nth of its health lost.
	* The arena (Section 10: the Brood Mother bursts up through the deepest tunnel): on the deepest
	  floor, the longest run of side-by-side dug cells (a tunnel: nothing walls them apart); with
	  none, the widest room there that isn't the Reactor Core or a Shaft; with none, any open cell.
	  A boss can't fit through a doorway, so it fights in its arena.
	* Hits: armour takes ArmourMultiplier, a weak point WeakPointMultiplier (or a class's own).
	* Staggers: enough weak-point damage inside a short window staggers the boss.
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)

local Boss = {}

export type Arena = {
	Floor: number,
	From: number, -- first column
	To: number, -- last column
	Kind: "Tunnel" | "Room" | "Cell",
	RoomId: string?,
}

function Boss.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Bosses")
end

-- A boss's own fight numbers (Tuning.<BossId>), or nil before its fight exists.
function Boss.Fight(bossId: string): { [string]: any }?
	return Config.Find("Tuning", bossId)
end

-- The value for this phase from a by-phase list (the last one carries on).
function Boss.ByPhase(list: { any }, phase: number): any
	return list[math.clamp(phase, 1, #list)]
end

function Boss.Health(bossId: string, players: number, firstRun: boolean): number
	local entry = Config.Get("Bosses", bossId)
	local scale = Config.Get("Tuning", "Threat").PlayerScale
	local n = math.clamp(math.floor(players), 1, #scale)
	local health = entry.Health * scale[n]
	if firstRun and entry.Year <= 25 then
		health *= Boss.Tuning().FirstRunHealth
	end
	return math.floor(health + 0.5)
end

-- The phase at this share of health left (1 at full health, Phases near the end).
function Boss.Phase(bossId: string, fraction: number): number
	local phases = Config.Get("Bosses", bossId).Phases
	local lost = 1 - math.clamp(fraction, 0, 1)
	return math.clamp(math.floor(lost * phases + 1e-9) + 1, 1, phases)
end

-- Where a boss breaks in: see the header. `bunker` is a Rules.Bunker.
function Boss.Arena(bunker: any): Arena?
	local floor = bunker:DeepestFloor()
	if floor < 1 then
		return nil
	end
	local t = Grid.Tuning()
	-- runs of dug cells side by side
	local best: Arena? = nil
	local column = t.ColumnMin
	while column <= t.ColumnMax do
		if bunker:State(floor, column) == "Dug" then
			local from = column
			while column + 1 <= t.ColumnMax and bunker:State(floor, column + 1) == "Dug" do
				column += 1
			end
			if not best or column - from > best.To - best.From then
				best = { Floor = floor, From = from, To = column, Kind = "Tunnel" }
			end
		end
		column += 1
	end
	if best then
		return best
	end
	-- the widest room on the floor that isn't the Reactor Core or a Shaft
	local room: any = nil
	for _, r in bunker:AllRooms() do
		if r.Floor == floor and r.Type ~= "ReactorCore" and r.Type ~= "Shaft" then
			if not room or r.Span > room.Span or (r.Span == room.Span and r.Column < room.Column) then
				room = r
			end
		end
	end
	if room then
		return { Floor = floor, From = room.Column, To = room.Column + room.Span - 1, Kind = "Room", RoomId = room.Id }
	end
	for c = t.ColumnMin, t.ColumnMax do
		if bunker:IsOpen(floor, c) then
			return { Floor = floor, From = c, To = c, Kind = "Cell" }
		end
	end
	return nil
end

-- The middle column of an arena (where the boss breaks in).
function Boss.ArenaMiddle(arena: Arena): number
	return math.floor((arena.From + arena.To) / 2)
end

-- How far along X the boss's centre may go: `margin` studs inside the arena's end walls.
function Boss.ArenaSpan(arena: Arena, margin: number): (number, number)
	local half = Grid.Tuning().CellWidth / 2
	local left = Grid.CellPosition(arena.Floor, arena.From).X - half + margin
	local right = Grid.CellPosition(arena.Floor, arena.To).X + half - margin
	if left > right then
		local mid = (left + right) / 2
		return mid, mid
	end
	return left, right
end

-- A hit's multiplier: the weak point's (a class's own if it has one), else the armour's.
function Boss.HitMultiplier(weak: boolean, classWeakPoint: number?): number
	local t = Boss.Tuning()
	if weak then
		return classWeakPoint or t.WeakPointMultiplier
	end
	return t.ArmourMultiplier
end

-- Is `point` on a weak point part? (`size` and `cframe` are the part's; tolerance in studs.)
function Boss.OnPart(point: Vector3, cframe: CFrame, size: Vector3, tolerance: number): boolean
	local p = cframe:PointToObjectSpace(point)
	local h = size / 2 + Vector3.one * tolerance
	return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end

-- Weak-point damage inside the window (hits are { At, Amount }) reaching `threshold` staggers.
function Boss.Staggers(hits: { { At: number, Amount: number } }, now: number, window: number, threshold: number): boolean
	local sum = 0
	for _, hit in hits do
		if now - hit.At <= window then
			sum += hit.Amount
		end
	end
	return sum >= threshold
end

return table.freeze(Boss)
