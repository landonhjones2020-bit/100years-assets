--!strict
--[[
	Rules.Dig: digging, the dug cell's roll, Push Deeper and Disturbance as arithmetic (bible
	Sections 6 and 10). Pure, so DigService, the Command View, the HUD and the data tests agree.
	The numbers are Tuning.Digging, Tuning.Disturbance, Config.DepthBands (dig seconds per band)
	and Config.DigResults (the roll); provisional ones are marked there.

	* Digging (Section 6): a Rock cell left of, right of or below an open cell can be dug
	  (Rules.Bunker.CanDig) from that cell: Faces. Players hold Interact with a Drill or a
	  Pickaxe (CanDigWith); a cell takes its band's DigSeconds; the Driller digs twice as fast
	  (DigSpeed) and players on one cell stack (Rate). A Drill Bay digs its queue at
	  ResidentDigMultiplier of a player for each unit of its crew's output (DrillBaySpeed).
	* Push Deeper (Section 6): the first cell of a new band (floors 4, 7 and 10) needs a vote.
	  Cells down to Limit can be dug without one: the last floor of the Mines at the start, the
	  last floor of each band the team has voted into after that (LimitAfter).
	* The roll (Section 6: rolled when it opens): Roll is the same for a cell every time in one
	  run (seeded by the run and the cell), so the Driller can see ore and caves before they are
	  dug (Hint). Results whose systems aren't built yet, and those of a later era, count as
	  Empty, so the others keep the bible's odds.
	* Disturbance (Section 10): 0 to Max; Add clamps; Crossed says whether a change set off the
	  extra breach (crossing ExtraBreachAt upward) or a Tremor (reaching TremorAt, after which it
	  drops to AfterTremor). Level names the reading for the seismograph.
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)

local Dig = {}

export type Face = { Side: "Left" | "Right" | "Above", Floor: number, Column: number } -- the open cell it's dug from

function Dig.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Digging")
end

function Dig.DisturbanceTuning(): { [string]: any }
	return Config.Get("Tuning", "Disturbance")
end

-- Digging ------------------------------------------------------------------------------------

-- Seconds for one player to dig a cell on this floor (Config.DepthBands).
function Dig.Seconds(floor: number): number
	return Grid.BandOf(floor).DigSeconds or 45
end

-- Does what a player carries dig? (a Drill or a Pickaxe)
function Dig.CanDigWith(items: { string }): boolean
	local tools = Dig.Tuning().Tools
	for _, id in items do
		if table.find(tools, id) then
			return true
		end
	end
	return false
end

-- Progress a second (0 to 1 is the whole cell) for diggers with these speeds (1 = a player, the
-- Driller 2): stacked, or the fastest alone when StackPlayers is off.
function Dig.Rate(speeds: { number }, floor: number): number
	local total = 0
	for _, speed in speeds do
		if Dig.Tuning().StackPlayers then
			total += speed
		else
			total = math.max(total, speed)
		end
	end
	return total / Dig.Seconds(floor)
end

-- A Drill Bay's digging speed in players, from its output rate (Rules.Economy) and its Base.
function Dig.DrillBaySpeed(rate: number, base: number): number
	if rate <= 0 or base <= 0 then
		return 0
	end
	return Dig.Tuning().ResidentDigMultiplier * rate / base
end

-- The open cells a rock cell can be dug from: beside it on its floor, or above it.
function Dig.Faces(bunker: any, floor: number, column: number): { Face }
	local faces: { Face } = {}
	if bunker:State(floor, column) ~= "Rock" then
		return faces
	end
	if bunker:IsOpen(floor, column - 1) then
		table.insert(faces, { Side = "Left", Floor = floor, Column = column - 1 })
	end
	if bunker:IsOpen(floor, column + 1) then
		table.insert(faces, { Side = "Right", Floor = floor, Column = column + 1 })
	end
	if bunker:IsOpen(floor - 1, column) then
		table.insert(faces, { Side = "Above", Floor = floor - 1, Column = column })
	end
	return faces
end

-- Where a face's dig prompt stands: on the wall line at chest height for a side, on the floor of
-- the cell above (towards the front) for digging down.
function Dig.FacePoint(face: Face, floor: number, column: number): Vector3
	local from = Grid.CellPosition(face.Floor, face.Column)
	if face.Side == "Above" then
		return from + Vector3.new(0, 1, Grid.Tuning().CellDepth / 4)
	end
	local rock = Grid.CellPosition(floor, column)
	return Vector3.new((from.X + rock.X) / 2, from.Y + 3.5, from.Z)
end

-- Push Deeper -----------------------------------------------------------------------------------

-- The deepest floor the team may dig to without a vote at the start: the first band's last.
function Dig.StartLimit(): number
	return Grid.BandOf(Grid.Tuning().FloorMin).Floors.To
end

-- After a Push Deeper vote into this floor's band: its last floor.
function Dig.LimitAfter(floor: number): number
	return Grid.BandOf(floor).Floors.To
end

function Dig.NeedsVote(floor: number, limit: number): boolean
	return floor > limit
end

-- The roll -----------------------------------------------------------------------------------------

-- The same Random for a cell every time in one run.
function Dig.CellRandom(seed: number, floor: number, column: number): Random
	local n = (math.floor(seed) * 92821 + floor * 1000003 + (column + 64) * 7919) % 2147483647
	return Random.new(n)
end

-- What opening this cell finds. `available` names the results that can happen now (systems
-- built); the rest, and those of a later era, are Empty.
function Dig.Roll(seed: number, floor: number, column: number, era: number, available: { [string]: boolean }): string
	local rng = Dig.CellRandom(seed, floor, column)
	local total = 0
	for _, entry in Config.All("DigResults") do
		total += entry.Chance
	end
	local pick = rng:NextNumber() * total
	for _, id in Config.Ids("DigResults") do
		local entry = Config.Get("DigResults", id)
		pick -= entry.Chance
		if pick <= 0 then
			if available[id] and era >= (entry.MinEra or 1) then
				return id
			end
			return "Empty"
		end
	end
	return "Empty"
end

-- What the Driller sees in rock before it is dug (Section 14: ore and caves): the roll when it is
-- an ore pocket or a cave opening, else nil.
function Dig.Hint(seed: number, floor: number, column: number, era: number, available: { [string]: boolean }): string?
	local result = Dig.Roll(seed, floor, column, era, available)
	return if result == "OrePocket" or result == "CaveOpening" then result else nil
end

-- How far into rock a cell is: steps from the nearest open cell (left, right, up, down), up to max.
function Dig.Depth(bunker: any, floor: number, column: number, max: number): number?
	for d = 1, max do
		for df = -d, d do
			local dc = d - math.abs(df)
			for _, c in { column - dc, column + dc } do
				if bunker:IsOpen(floor + df, c) then
					return d
				end
			end
		end
	end
	return nil
end

-- Disturbance -------------------------------------------------------------------------------------

function Dig.AddDisturbance(value: number, amount: number): number
	return math.clamp(value + amount, 0, Dig.DisturbanceTuning().Max)
end

-- What a change from `before` to `after` sets off.
function Dig.Crossed(before: number, after: number): (boolean, boolean)
	local t = Dig.DisturbanceTuning()
	local extra = before < t.ExtraBreachAt and after >= t.ExtraBreachAt and after < t.TremorAt
	local tremor = after >= t.TremorAt
	return extra, tremor
end

function Dig.AfterTremor(): number
	return Dig.DisturbanceTuning().AfterTremor
end

-- The seismograph's reading: CALM, RISING, UNSETTLED or DANGER, by quarters of the meter.
function Dig.Level(value: number): string
	local t = Dig.DisturbanceTuning()
	local fraction = value / t.Max
	if fraction < 0.25 then
		return "CALM"
	elseif fraction < t.ExtraBreachAt / t.Max then
		return "RISING"
	elseif fraction < 0.75 then
		return "UNSETTLED"
	end
	return "DANGER"
end

return table.freeze(Dig)
