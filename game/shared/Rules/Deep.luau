--!strict
--[[
	Rules.Deep: the Deep's arithmetic (bible Sections 6, 12 and 14; Prompt 17). Pure, so the data
	tests, the server and the client share it. The numbers are Tuning.Deep (provisional), the pieces
	Config.CavePieces (made with the A6 art).

	* Caves (Section 12: "When a dug cell breaks into a cave, a cave area opens behind it. Caves are
	  put together from hand-made pieces for that band, so no two runs match"): a cave grows from its
	  mouth, the dug cell's back wall (MouthCFrame), into the rock behind the grid (-Z). Plan places
	  the band's Entry there, then grows piece by piece from open exits (PieceAt: a piece's pivot sits
	  on the exit, facing on), never into the grid, below LowestY or into another piece (Overlaps,
	  with the boxes of every cave already open; a piece shares RIM studs of wall with the one it
	  hangs off), until it has its pieces; exits left over are plugged with rubble. A cave with a
	  Lost Crew ends in its band's CrewPocket. When another cave already fills the rock behind the
	  cell there is no mouth at all (an empty plan).
	* Finds (Section 12: ore veins, caches, radio logs, cryo pods, trapped miners, Glowshard chests):
	  RollFind picks what a Find spot holds (cryo pods from Era II; the Spelunker's FindChance makes
	  cryo pods and caches likelier).
	* Lost Crews (Section 12: one in each band of the Deep, their spots change each run): CrewCell
	  picks the rock cell whose cave holds a band's crew, CrewMinDepth cells from anything open.
	* Hints (Section 12: radio logs hint where each crew is): Hint(floor, column) in words.
	* Guards (Section 12: monsters, each crew guarded by a nest below): Roster(band, usable) is the
	  band's own monsters (Where), or the Mines' until the band's have their models (A8).
	* Drops and darkness (Section 12): FallDamage(drop, immune) past FallDamageFrom studs (the
	  Spelunker's NoFallDamage), LightRange(multiplier) for a player's own light (LightRadius).

		Deep.Plan("Mines", Deep.MouthCFrame(3, 4), Random.new(7), {}, { Crew = true })
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)

local Deep = {}

-- A piece's box takes in its walls, 4 studs past its openings (A6: generators/Caves/cavelib.py's
-- box_of), so a piece and the one at its exit share that much wall: the planner lets them.
local RIM = 4

export type Box = { Min: Vector3, Max: Vector3 }
export type Placement = { Piece: string, CFrame: CFrame, Depth: number, Box: Box, Parent: Box? } -- Parent: the piece it hangs off
export type Plan = { Pieces: { Placement }, Plugs: { CFrame }, Crew: boolean }

function Deep.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Deep")
end

-- The band a floor's caves belong to (DepthBands id).
function Deep.Band(floor: number): string
	return Grid.BandOf(floor).Id
end

-- Where a cell's cave starts: the floor centre of its back wall's inner face, facing into the rock.
function Deep.MouthCFrame(floor: number, column: number): CFrame
	local cell = Grid.CellPosition(floor, column)
	local depth = Grid.Tuning().CellDepth
	return CFrame.new(cell.X, cell.Y, cell.Z - depth / 2)
end

-- A cave's way out into the bunker: a spot in the dug cell in front of its mouth (monsters and
-- followers walk there, then the bunker's paths take over).
function Deep.MouthPoint(floor: number, column: number): Vector3
	local cell = Grid.CellPosition(floor, column)
	return cell + Vector3.new(0, 0.5, -6)
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- An exit's frame in the world: on its opening's floor, looking out of the piece.
function Deep.ExitCFrame(pieceCFrame: CFrame, exit: { P: { number }, Yaw: number }): CFrame
	return pieceCFrame * CFrame.new(vec(exit.P)) * CFrame.Angles(0, math.rad(exit.Yaw), 0)
end

-- The piece that comes next at an exit: its pivot on the exit, its -Z going on the same way.
function Deep.PieceAt(exitCFrame: CFrame): CFrame
	return exitCFrame
end

-- A piece's box in the world (its turns are quarter turns, so the box stays tight).
function Deep.WorldBox(pieceCFrame: CFrame, box: { Min: { number }, Max: { number } }): Box
	local lo, hi = vec(box.Min), vec(box.Max)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, x in { lo.X, hi.X } do
		for _, y in { lo.Y, hi.Y } do
			for _, z in { lo.Z, hi.Z } do
				local p = pieceCFrame * Vector3.new(x, y, z)
				min = min:Min(p)
				max = max:Max(p)
			end
		end
	end
	return { Min = min, Max = max }
end

-- Two boxes overlap by more than margin on every axis.
function Deep.Overlaps(a: Box, b: Box, margin: number): boolean
	return a.Min.X < b.Max.X - margin and b.Min.X < a.Max.X - margin
		and a.Min.Y < b.Max.Y - margin and b.Min.Y < a.Max.Y - margin
		and a.Min.Z < b.Max.Z - margin and b.Min.Z < a.Max.Z - margin
end

function Deep.Inside(box: Box, position: Vector3): boolean
	return position.X >= box.Min.X and position.X <= box.Max.X and position.Y >= box.Min.Y and position.Y <= box.Max.Y
		and position.Z >= box.Min.Z and position.Z <= box.Max.Z
end

-- The band's pieces of a kind ("Entry", "CrewPocket"), or the planner's own (Weight > 0).
function Deep.Pieces(band: string, kind: string?): { any }
	local list = {}
	for _, piece in Config.All("CavePieces") do
		if piece.Band == band and (if kind then piece.Kind == kind else piece.Weight > 0) then
			table.insert(list, piece)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

local function pick(list: { any }, rng: Random): any?
	local total = 0
	for _, piece in list do
		total += piece.Weight
	end
	if total <= 0 then
		return list[1]
	end
	local roll = rng:NextNumber() * total
	for _, piece in list do
		roll -= piece.Weight
		if roll <= 0 then
			return piece
		end
	end
	return list[#list]
end

-- Can a piece stand here: behind the grid, above the lowest floor, clear of every other piece
-- (but for the wall it shares with the piece whose exit it hangs off, `parent`)?
local function fits(box: Box, occupied: { Box }, t: { [string]: any }, parent: Box?): boolean
	if box.Max.Z > t.GridBack or box.Min.Y < t.LowestY then
		return false
	end
	for _, other in occupied do
		if Deep.Overlaps(box, other, if other == parent then t.Margin + RIM else t.Margin) then
			return false
		end
	end
	return true
end

--[[
	Grow a cave. occupied: the boxes of every piece already in the Deep (this cave's are added).
	options.Crew: end in the CrewPocket. options.Pieces: how many pieces after the mouth (default:
	a roll in CavePieces). Returns the placements (the Entry first), the exits plugged with rubble,
	and whether the CrewPocket found a place.
]]
function Deep.Plan(band: string, mouth: CFrame, rng: Random, occupied: { Box }, options: { Crew: boolean?, Pieces: number? }?): Plan
	local t = Deep.Tuning()
	local o = options or {}
	local placed: { Placement } = {}
	local plugs: { CFrame } = {}
	local entry = Deep.Pieces(band, "Entry")[1]
	if not entry then
		return { Pieces = placed, Plugs = plugs, Crew = false }
	end
	local entryBox = Deep.WorldBox(mouth, entry.Box)
	for _, other in occupied do
		if Deep.Overlaps(entryBox, other, t.Margin + RIM) then
			-- another cave already fills the rock behind this cell: no room for a mouth
			return { Pieces = placed, Plugs = plugs, Crew = false }
		end
	end
	table.insert(placed, { Piece = entry.Id, CFrame = mouth, Depth = 0, Box = entryBox })
	table.insert(occupied, entryBox)
	local open: { { CFrame: CFrame, Depth: number, Parent: Box } } = {}
	for _, exit in entry.Exits do
		table.insert(open, { CFrame = Deep.ExitCFrame(mouth, exit), Depth = 1, Parent = entryBox })
	end
	local target = o.Pieces or rng:NextInteger(t.CavePieces.Min, t.CavePieces.Max)
	local crewPiece = if o.Crew then Deep.Pieces(band, "CrewPocket")[1] else nil
	local crewPlaced = false
	local pieces = Deep.Pieces(band)
	local deadEnds = {}
	for _, piece in pieces do
		if #piece.Exits == 0 then
			table.insert(deadEnds, piece)
		end
	end
	local count = 0
	while #open > 0 do
		local slot = table.remove(open, 1) :: { CFrame: CFrame, Depth: number, Parent: Box }
		local at = Deep.PieceAt(slot.CFrame)
		local left = target - count
		local candidates: { any } = {}
		if crewPiece and not crewPlaced and (left <= 1 + #open or #open == 0 and left <= 2) then
			table.insert(candidates, crewPiece)
		end
		if left > 0 then
			-- with as many exits waiting as pieces left, close them off with dead ends
			local pool = if left <= #open then deadEnds else pieces
			for _ = 1, t.PlannerTries do
				local choice = pick(pool, rng)
				if choice and not table.find(candidates, choice) then
					table.insert(candidates, choice)
				end
			end
		end
		local done = false
		for _, piece in candidates do
			local box = Deep.WorldBox(at, piece.Box)
			if fits(box, occupied, t, slot.Parent) then
				table.insert(placed, { Piece = piece.Id, CFrame = at, Depth = slot.Depth, Box = box, Parent = slot.Parent })
				table.insert(occupied, box)
				count += 1
				if piece == crewPiece then
					crewPlaced = true
				end
				for _, exit in piece.Exits do
					table.insert(open, { CFrame = Deep.ExitCFrame(at, exit), Depth = slot.Depth + 1, Parent = box })
				end
				done = true
				break
			end
		end
		if not done then
			table.insert(plugs, slot.CFrame)
		end
	end
	if crewPiece and not crewPlaced then
		-- no room met it on the way: swap the deepest dead end for it, if it fits there
		for i = #placed, 2, -1 do
			local p = placed[i]
			local piece = Config.Get("CavePieces", p.Piece)
			if #piece.Exits == 0 then
				local box = Deep.WorldBox(p.CFrame, crewPiece.Box)
				local index = table.find(occupied, p.Box)
				if index then
					table.remove(occupied, index)
				end
				if fits(box, occupied, t, p.Parent) then
					placed[i] = { Piece = crewPiece.Id, CFrame = p.CFrame, Depth = p.Depth, Box = box, Parent = p.Parent }
					table.insert(occupied, box)
					crewPlaced = true
					break
				end
				table.insert(occupied, p.Box)
			end
		end
	end
	return { Pieces = placed, Plugs = plugs, Crew = crewPlaced }
end

-- What a Find spot holds: a FindOdds key ("Nothing" too). Cryo pods from their DigResults era;
-- findChance (the Spelunker's FindChance) scales cryo pods and caches.
function Deep.RollFind(roll: number, era: number, findChance: number?): string
	local t = Deep.Tuning()
	local scale = findChance or 1
	local cryoEra = Config.Get("DigResults", "CryoPod").MinEra or 2
	local weights: { [string]: number } = {}
	local total = 0
	local order = { "OreVein", "Cache", "RadioLog", "TrappedMiner", "CryoPod", "GlowshardChest", "Nothing" }
	for _, id in order do
		local w = t.FindOdds[id] or 0
		if id == "CryoPod" and era < cryoEra then
			w = 0
		elseif id == "CryoPod" or id == "Cache" then
			w *= scale
		end
		weights[id] = w
		total += w
	end
	local pickAt = roll * total
	for _, id in order do
		pickAt -= weights[id]
		if pickAt <= 0 and weights[id] > 0 then
			return id
		end
	end
	return "Nothing"
end

-- A cryo pod thaws into a Rare or a Legendary resident (Section 6).
function Deep.CryoTier(roll: number): string
	return if roll < Deep.Tuning().LegendaryChance then "Legendary" else "Rare"
end

--[[
	The rock cell whose cave holds a band's Lost Crew: a Rock cell on the band's CrewFloors, at
	least CrewMinDepth cells from anything open (so it takes some digging), chosen by the seed.
	isOpen(floor, column) says whether a cell is open now.
]]
function Deep.CrewCell(seed: number, band: string, isOpen: (number, number) -> boolean): (number?, number?)
	local t = Deep.Tuning()
	local floors = t.CrewFloors[band]
	if not floors then
		return nil, nil
	end
	local g = Grid.Tuning()
	local candidates: { { number } } = {}
	for floor = floors.Min, floors.Max do
		for column = g.ColumnMin, g.ColumnMax do
			if not isOpen(floor, column) then
				local near = false
				for df = -t.CrewMinDepth + 1, t.CrewMinDepth - 1 do
					for dc = -t.CrewMinDepth + 1, t.CrewMinDepth - 1 do
						if math.abs(df) + math.abs(dc) < t.CrewMinDepth and isOpen(floor + df, column + dc) then
							near = true
						end
					end
				end
				if not near then
					table.insert(candidates, { floor, column })
				end
			end
		end
	end
	if #candidates == 0 then
		return nil, nil
	end
	local rng = Random.new(seed + #band * 7919)
	local choice = candidates[rng:NextInteger(1, #candidates)]
	return choice[1], choice[2]
end

-- Where a crew was last heard from, in words ("the Mines, floor 3, two cells west of the shaft").
local COUNT = { "one cell", "two cells", "three cells", "four cells", "five cells", "six cells" }
function Deep.Hint(floor: number, column: number): string
	local band = Grid.BandOf(floor)
	local n = math.abs(column)
	local cells = COUNT[n] or `{n} cells`
	local side = if column < 0 then `{cells} west of the shaft` elseif column > 0 then `{cells} east of the shaft` else "under the shaft"
	return `the {band.Name}, floor {floor}, {side}`
end

-- Damage from a fall of `drop` studs (0 below FallDamageFrom, or for the immune).
function Deep.FallDamage(drop: number, immune: boolean?): number
	local t = Deep.Tuning()
	if immune or drop <= t.FallDamageFrom then
		return 0
	end
	return math.min(math.floor((drop - t.FallDamageFrom) * t.FallDamagePerStud + 0.5), t.FallDamageMax)
end

-- A player's own light in the Deep (studs); multiplier is LightRadius (the Spelunker's 2).
function Deep.LightRange(multiplier: number?): number
	return Deep.Tuning().LightRange * math.max(multiplier or 1, 0)
end

-- The monsters that guard a band's caves: its own (Config.Monsters Where), those `usable` says can
-- come out now (their model is in); the Mines' when none of the band's can. Sorted.
function Deep.Roster(band: string, usable: (string) -> boolean): { string }
	local function of(b: string): { string }
		local list = {}
		for _, monster in Config.All("Monsters") do
			if table.find(monster.Where, b) and usable(monster.Id) then
				table.insert(list, monster.Id)
			end
		end
		table.sort(list)
		return list
	end
	local list = of(band)
	if #list == 0 and band ~= "Mines" then
		list = of("Mines")
	end
	return list
end

return Deep
