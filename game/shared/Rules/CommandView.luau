--!strict
--[[
	Rules.CommandView: the Command View's arithmetic and build-menu rules (bible Section 7),
	pure so the data tests can check them.

	* The view is a far camera with a narrow field of view, so the bunker looks nearly flat.
	  VisibleHeight and DistanceFor convert between the camera's distance and how many studs
	  fit on screen; Lens caps the distance (the lowest graphics level draws about 500 studs)
	  and widens the field of view past it; CellBox is a cell's interior; Bounds and Clamp keep
	  the view over the grid.
	* RoomChoice says whether a room type can be proposed on an open cell, and why not: its
	  unlock (Rules.Construction.Unlock: start, a blueprint draft, a draft or a depth, an era,
	  the first cryo pod), then the placement rules (Rules.Bunker.CanPlace).
	* CostText: "120 SCRAP · 20 IRON", in Config.Resources order (Rules.Construction).
]]

local Config = require(script.Parent.Parent.Config)
local Construction = require(script.Parent.Construction)
local Grid = require(script.Parent.Grid)

export type Bounds = { Left: number, Right: number, Top: number, Bottom: number }
export type Context = {
	Era: number, -- the current era's place in Config.Eras (1 to 4)
	Deepest: number, -- the deepest open floor
	Unlocked: { [string]: boolean }?, -- room types won from drafts or cryo pods
}

local CommandView = {}

function CommandView.Tuning(): { [string]: any }
	return Config.Get("Tuning", "CommandView")
end

function CommandView.VisibleHeight(distance: number, fieldOfView: number): number
	return 2 * distance * math.tan(math.rad(fieldOfView) / 2)
end

function CommandView.DistanceFor(height: number, fieldOfView: number): number
	return height / (2 * math.tan(math.rad(fieldOfView) / 2))
end

-- The camera for a visible height (studs at the cells' plane): the narrow field of view while
-- that fits within MaxDistance, then MaxDistance with a wider field of view. Roblox stops drawing
-- parts about 500 studs away at the lowest graphics level, so a farther camera shows nothing on
-- phones set to low graphics.
function CommandView.Lens(height: number): (number, number)
	local t = CommandView.Tuning()
	local distance = CommandView.DistanceFor(height, t.FieldOfView)
	if distance <= t.MaxDistance then
		return distance, t.FieldOfView
	end
	return t.MaxDistance, 2 * math.deg(math.atan(height / 2 / t.MaxDistance))
end

-- A cell's box in world studs: Grid.CellPosition is the centre of its interior floor, so the
-- interior runs from that floor up to the ceiling (CellHeight).
function CommandView.CellBox(floor: number, column: number, span: number?): (Vector2, Vector2)
	local pitch = Grid.Pitch()
	local first = Grid.CellPosition(floor, column)
	local last = Grid.CellPosition(floor, column + (span or 1) - 1)
	return Vector2.new(first.X - pitch.X / 2, first.Y), Vector2.new(last.X + pitch.X / 2, first.Y + Grid.Tuning().CellHeight)
end

-- The grid's outer edges in world studs: the top floor's ceiling to the slab under the bottom floor.
function CommandView.Bounds(): Bounds
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local topLeft = Grid.CellPosition(t.FloorMin, t.ColumnMin)
	local bottomRight = Grid.CellPosition(t.FloorMax, t.ColumnMax)
	return {
		Left = topLeft.X - pitch.X / 2,
		Right = bottomRight.X + pitch.X / 2,
		Top = topLeft.Y + t.CellHeight,
		Bottom = bottomRight.Y - t.SlabThickness,
	}
end

-- Keeps the view's centre (world X and Y) over the grid.
function CommandView.Clamp(center: Vector2, bounds: Bounds): Vector2
	return Vector2.new(math.clamp(center.X, bounds.Left, bounds.Right), math.clamp(center.Y, bounds.Bottom, bounds.Top))
end

-- Can `roomType` be proposed on an open cell? Its unlock (Rules.Construction.Unlock), then the
-- placement rules (Rules.Bunker.CanPlace). The server checks the same with Construction.Plan.
function CommandView.RoomChoice(bunker: any, roomType: string, floor: number, column: number, context: Context): (boolean, string?)
	local ok, why = Construction.Unlock(roomType, context)
	if not ok then
		return false, why
	end
	return bunker:CanPlace(roomType, floor, column, 1)
end

CommandView.CostText = Construction.CostText

return CommandView
