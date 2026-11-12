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
	* The Source (Prompt 25; Section 10: "tendrils in many rooms at once, then the core, so the team
	  has to split up and regroup"): its fight is a list of stages (Tuning.Source.Stages), each
	  Tendrils or Core. SourceTendrils is how many stand in a Tendrils stage (and how many of those
	  in its own chamber when it is fought there), SourceRooms where in the bunker, SourceWound what
	  each one cut down takes off the Source so the last ends the stage, SourceCoreOver when a Core
	  stage is.
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

-- A boss's name for an alert: capitals, with one THE ("THE BROOD MOTHER", "THE DELUGE").
function Boss.Title(name: string): string
	local upper = string.upper(name)
	return if string.sub(upper, 1, 4) == "THE " then upper else `THE {upper}`
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

-- The Source (Prompt 25) ---------------------------------------------------------------------------

export type TendrilSpot = { Floor: number, Column: number, RoomId: string? }

-- What a stage of the Source's fight is: "Tendrils" (its eye is shut) or "Core" (its eye is open).
function Boss.SourceStage(stage: number): string
	local stages = Config.Get("Tuning", "Source").Stages
	return stages[math.clamp(math.floor(stage), 1, #stages)]
end

-- How many tendrils stand in this stage for a team of `players`, and how many of them rise in its
-- own chamber when it is fought there (the rest are in the bunker's rooms).
function Boss.SourceTendrils(stage: number, players: number, chamber: boolean): (number, number)
	local t = Config.Get("Tuning", "Source")
	local base = Boss.ByPhase(t.Tendrils, stage)
	if Boss.SourceStage(stage) ~= "Tendrils" or base <= 0 then
		return 0, 0
	end
	local total = math.min(base + t.TendrilsPerPlayer * (math.max(math.floor(players), 1) - 1), t.TendrilsMax)
	local inChamber = if chamber then math.min(Boss.ByPhase(t.ChamberTendrils, stage), total) else 0
	return total, inChamber
end

-- A tendril's health for the team (scaled like a boss's).
function Boss.TendrilHealth(players: number): number
	local scale = Config.Get("Tuning", "Threat").PlayerScale
	local n = math.clamp(math.floor(players), 1, #scale)
	return math.floor(Config.Get("Tuning", "Source").TendrilHealth * scale[n] + 0.5)
end

-- What a tendril cut down takes off the Source: an even share of the health still between it and
-- the stage's end, over the tendrils left (this one counted), so the last one ends the stage.
function Boss.SourceWound(health: number, max: number, stage: number, left: number): number
	local untilFraction = Boss.ByPhase(Config.Get("Tuning", "Source").StageUntil, stage)
	return math.max(health - untilFraction * max, 0) / math.max(left, 1)
end

-- Is a Core stage over at this health? The last stage ends only with its death.
function Boss.SourceCoreOver(health: number, max: number, stage: number): boolean
	local t = Config.Get("Tuning", "Source")
	if stage >= #t.Stages then
		return false
	end
	return health <= Boss.ByPhase(t.StageUntil, stage) * max
end

--[[
	Where `count` tendrils stand in the bunker: one to a room (a cell of it picked by `pick`), never
	a Shaft or the Reactor Core (a tendril there would be a meltdown nobody could answer in time),
	never a cell in `avoid` ("floor,column" keys: the Source's own arena). Spread: rooms on floors
	that have none yet come first, so the team has to split up; `deepest` (the chamber fight) takes
	the deepest floors first instead, the rooms nearest the chamber. With fewer rooms than tendrils
	the rest stand in dug cells; with none of those either, fewer come. `pick(n)` returns 1 to n.
]]
function Boss.SourceRooms(bunker: any, count: number, pick: (number) -> number, avoid: { [string]: boolean }?, deepest: boolean?): { TendrilSpot }
	local out: { TendrilSpot } = {}
	if count <= 0 then
		return out
	end
	local candidates: { TendrilSpot } = {}
	for _, room in bunker:AllRooms() do
		if room.Type ~= "Shaft" and room.Type ~= "ReactorCore" then
			local cells = {}
			for c = room.Column, room.Column + room.Span - 1 do
				if not (avoid and avoid[Grid.Key(room.Floor, c)]) then
					table.insert(cells, c)
				end
			end
			if #cells > 0 then
				table.insert(candidates, { Floor = room.Floor, Column = cells[pick(#cells)], RoomId = room.Id })
			end
		end
	end
	-- a shuffle (Fisher-Yates with the caller's pick), then the order the rule asks for
	table.sort(candidates, function(a, b)
		return if a.Floor ~= b.Floor then a.Floor < b.Floor else a.Column < b.Column
	end)
	for i = #candidates, 2, -1 do
		local j = pick(i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local used: { [number]: number } = {}
	while #out < count and #candidates > 0 do
		local best, bestScore = 1, math.huge
		for i, spot in candidates do
			local score = if deepest then -spot.Floor else (used[spot.Floor] or 0)
			if score < bestScore then
				best, bestScore = i, score
			end
		end
		local spot = table.remove(candidates, best) :: TendrilSpot
		used[spot.Floor] = (used[spot.Floor] or 0) + 1
		table.insert(out, spot)
	end
	if #out < count then
		local t = Grid.Tuning()
		local dug: { TendrilSpot } = {}
		for floor = 1, bunker:DeepestFloor() do
			for column = t.ColumnMin, t.ColumnMax do
				if bunker:State(floor, column) == "Dug" and not (avoid and avoid[Grid.Key(floor, column)]) then
					table.insert(dug, { Floor = floor, Column = column })
				end
			end
		end
		while #out < count and #dug > 0 do
			table.insert(out, table.remove(dug, pick(#dug)) :: TendrilSpot)
		end
	end
	return out
end

return table.freeze(Boss)
