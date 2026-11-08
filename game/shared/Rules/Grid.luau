--!strict
--[[
	Rules.Grid: the bunker grid's geometry (bible Section 6), shared so BunkerGrid, the
	Command View (Prompt 7) and the data tests agree on where every cell is.

	* Columns Tuning.Grid.ColumnMin..ColumnMax (-6 to 6), left to right as seen from the
	  front; floors 1 to 10, where the floor number is the depth. Floor 10 is the Source
	  Chamber.
	* A cell is 32 wide, 16 tall and 32 deep inside. Walls are WallThickness (1) on each side
	  and slabs SlabThickness (2) between floors, so cells repeat every 34 studs across and
	  18 down.
	* In the world, Tuning.Grid.Origin is the interior floor centre of floor 1, column 0.
	  Columns grow along +X, floors go down -Y, and the front (the Command View camera's
	  side) faces +Z. Models from the art pipeline face -Z, so CellCFrame turns them half a
	  turn.
]]

local Config = require(script.Parent.Parent.Config)

local Grid = {}

function Grid.Tuning(): { [string]: any }
	return Config.Get("Tuning", "Grid")
end

-- "floor,column", the key cells go by everywhere (collections, models, the delta channel).
function Grid.Key(floor: number, column: number): string
	return `{floor},{column}`
end

function Grid.Parse(key: string): (number?, number?)
	local floor, column = string.match(key, "^(%-?%d+),(%-?%d+)$")
	if not floor then
		return nil, nil
	end
	return tonumber(floor), tonumber(column)
end

function Grid.OnGrid(floor: number, column: number): boolean
	local t = Grid.Tuning()
	return floor == math.floor(floor)
		and column == math.floor(column)
		and floor >= t.FloorMin
		and floor <= t.FloorMax
		and column >= t.ColumnMin
		and column <= t.ColumnMax
end

-- How far apart cells are: across (X), down (Y), and a cell's full depth (Z).
function Grid.Pitch(): Vector3
	local t = Grid.Tuning()
	return Vector3.new(t.CellWidth + 2 * t.WallThickness, t.CellHeight + t.SlabThickness, t.CellDepth + 2 * t.WallThickness)
end

-- The centre of a cell's interior floor, in the world.
function Grid.CellPosition(floor: number, column: number): Vector3
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	return Vector3.new(t.Origin.X + column * pitch.X, t.Origin.Y - (floor - 1) * pitch.Y, t.Origin.Z)
end

-- A cell's interior floor centre, turned so a model that faces -Z faces the front (+Z).
function Grid.CellCFrame(floor: number, column: number): CFrame
	return CFrame.new(Grid.CellPosition(floor, column)) * CFrame.Angles(0, math.pi, 0)
end

-- The cell a world position is in (its interior, or the slab under it), or nil off the grid.
function Grid.CellAt(position: Vector3): (number?, number?)
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local floor = math.floor((t.Origin.Y + t.CellHeight - position.Y) / pitch.Y) + 1
	local column = math.floor((position.X - t.Origin.X) / pitch.X + 0.5)
	if math.abs(position.Z - t.Origin.Z) > pitch.Z / 2 or not Grid.OnGrid(floor, column) then
		return nil, nil
	end
	return floor, column
end

-- The depth band a floor is in (Config.DepthBands).
function Grid.BandOf(floor: number): { [string]: any }
	for _, band in Config.All("DepthBands") do
		if floor >= band.Floors.From and floor <= band.Floors.To then
			return band
		end
	end
	error(`Rules.Grid: no depth band holds floor {floor}`)
end

-- The first floor of a band below the first one (4, 7, 10): opening it needs Push Deeper.
function Grid.IsBandStart(floor: number): boolean
	local band = Grid.BandOf(floor)
	return band.Floors.From == floor and floor > Grid.Tuning().FloorMin
end

-- Can rooms be built on this floor? (Not in the Source Chamber.)
function Grid.Buildable(floor: number): boolean
	return Grid.BandOf(floor).Buildable == true
end

return table.freeze(Grid)
