--!strict
--[[
	Rules.CommandView: the Command View's arithmetic and build-menu rules (bible Section 7),
	pure so the data tests can check them.

	* The view is a far camera with a narrow field of view, so the bunker looks nearly flat.
	  VisibleHeight and DistanceFor convert between the camera's distance and how many studs
	  fit on screen; Bounds and Clamp keep the view over the grid.
	* RoomChoice says whether a room type can be proposed on an open cell, and why not: its
	  unlock (Section 6: start, a blueprint draft, a draft or a depth, an era, the first cryo
	  pod), then the placement rules (Rules.Bunker.CanPlace).
	* CostText: "120 SCRAP · 20 IRON", in Config.Resources order.
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)
local Hud = require(script.Parent.Hud)

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

-- The grid's outer edges in world studs.
function CommandView.Bounds(): Bounds
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local topLeft = Grid.CellPosition(t.FloorMin, t.ColumnMin)
	local bottomRight = Grid.CellPosition(t.FloorMax, t.ColumnMax)
	return {
		Left = topLeft.X - pitch.X / 2,
		Right = bottomRight.X + pitch.X / 2,
		Top = topLeft.Y + pitch.Y / 2,
		Bottom = bottomRight.Y - pitch.Y / 2,
	}
end

-- Keeps the view's centre (world X and Y) over the grid.
function CommandView.Clamp(center: Vector2, bounds: Bounds): Vector2
	return Vector2.new(math.clamp(center.X, bounds.Left, bounds.Right), math.clamp(center.Y, bounds.Bottom, bounds.Top))
end

function CommandView.RoomChoice(bunker: any, roomType: string, floor: number, column: number, context: Context): (boolean, string?)
	local info = Config.Get("Rooms", roomType)
	local unlock = info.Unlock
	local won = context.Unlocked ~= nil and context.Unlocked[roomType] == true
	if unlock.Kind == "Draft" and not won then
		return false, "Unlock: a blueprint draft"
	elseif unlock.Kind == "DraftOrDepth" and not won and context.Deepest < (unlock.Depth or 10) then
		return false, `Unlock: a blueprint draft, or reach depth {unlock.Depth}`
	elseif unlock.Kind == "Era" and context.Era < (unlock.Era or 1) then
		return false, `Unlock: Era {Hud.Numeral(unlock.Era or 1)}`
	elseif unlock.Kind == "CryoPod" and not won then
		return false, "Unlock: find the first cryo pod"
	end
	return bunker:CanPlace(roomType, floor, column, 1)
end

function CommandView.CostText(costs: { [string]: number }?): string
	local parts = {}
	for _, id in Config.Ids("Resources") do
		local amount = if costs then costs[id] else nil
		if amount and amount > 0 then
			table.insert(parts, `{amount} {string.upper(Config.Get("Resources", id).Name)}`)
		end
	end
	return if #parts > 0 then table.concat(parts, " · ") else "FREE"
end

return CommandView
