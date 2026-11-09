--!strict
--[[
	PathGraph: walking routes inside the bunker (bible Section 23: residents move along the room
	graph; every room has nodes for doors, work spots, beds and tables). Run place, server.

	A route is the room graph's shortest path (Bunker:Neighbors: doorways sideways, Shafts up and
	down; dug cells count). Its waypoints:
	* inside a room or dug cell, along the front aisle (AISLE studs in front of the cell's centre
	  line, clear of the furniture against the back wall);
	* through a doorway at its middle (DOOR studs in front of centre; doorways are 8 wide);
	* up or down a Shaft by its stairs: the lower Shaft cell's Bottom and Top sockets (the stairs
	  climb from its floor to the floor above);
	* the target last (a work spot, a seat, a bed).
	Graybox rooms without sockets fall back to the cell's middle.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Grid = require(ReplicatedStorage.Shared.Rules.Grid)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local PathGraph = {}

local AISLE = 8 -- studs in front of the cell's centre line
local DOOR = 2 -- the doorway's walking line, in front of centre
local DOOR_REACH = 6 -- how far either side of a wall the doorway approach starts

-- The shortest route from one graph node to another (both included), or nil.
function PathGraph.Route(bunker: any, from: string, to: string): { string }?
	if from == to then
		return { from }
	end
	local previous: { [string]: string } = {}
	local seen: { [string]: boolean } = { [from] = true }
	local queue = { from }
	local index = 1
	while index <= #queue do
		local unit = queue[index]
		index += 1
		for _, other in bunker:Neighbors(unit) do
			if not seen[other] then
				seen[other] = true
				previous[other] = unit
				if other == to then
					local route = { to }
					local at = to
					while previous[at] do
						at = previous[at]
						table.insert(route, 1, at)
					end
					return route
				end
				table.insert(queue, other)
			end
		end
	end
	return nil
end

local function floorY(floor: number, column: number): number
	return Grid.CellPosition(floor, column).Y
end

local function aisle(x: number, floor: number, column: number): Vector3
	local cell = Grid.CellPosition(floor, column)
	return Vector3.new(x, cell.Y, cell.Z + AISLE)
end

-- The cells of `a` and `b` that touch: a horizontal pair on one floor, or a vertical pair.
local function touching(bunker: any, a: string, b: string): ({ number }?, { number }?)
	for _, ca in bunker:CellsOf(a) do
		for _, cb in bunker:CellsOf(b) do
			local same = ca[1] == cb[1] and math.abs(ca[2] - cb[2]) == 1
			local stacked = ca[2] == cb[2] and math.abs(ca[1] - cb[1]) == 1
			if same or stacked then
				return ca, cb
			end
		end
	end
	return nil, nil
end

--[[
	Waypoints from `fromPosition` (in node `fromUnit`) to `target` (in node `toUnit`). `modelOf`
	gives a room's model (for the Shafts' stair sockets). nil when no route exists.
]]
function PathGraph.Waypoints(bunker: any, modelOf: (string) -> Model?, fromPosition: Vector3, fromUnit: string,
	toUnit: string, target: Vector3): { Vector3 }?
	local route = PathGraph.Route(bunker, fromUnit, toUnit)
	if not route then
		return nil
	end
	local points: { Vector3 } = {}
	local startCell = bunker:CellsOf(fromUnit)[1]
	if startCell then
		local floor, column = Grid.CellAt(fromPosition)
		table.insert(points, aisle(fromPosition.X, floor or startCell[1], column or startCell[2]))
	end
	for i = 1, #route - 1 do
		local u, v = route[i], route[i + 1]
		local cu, cv = touching(bunker, u, v)
		if cu and cv then
			if cu[1] == cv[1] then
				-- sideways, through the doorway in the shared wall
				local pu, pv = Grid.CellPosition(cu[1], cu[2]), Grid.CellPosition(cv[1], cv[2])
				local wall = (pu.X + pv.X) / 2
				local dir = if cv[2] > cu[2] then 1 else -1
				local y = pu.Y
				table.insert(points, Vector3.new(wall - dir * DOOR_REACH, y, pu.Z + AISLE))
				table.insert(points, Vector3.new(wall - dir * DOOR_REACH, y, pu.Z + DOOR))
				table.insert(points, Vector3.new(wall + dir * DOOR_REACH, y, pu.Z + DOOR))
				table.insert(points, Vector3.new(wall + dir * DOOR_REACH, y, pu.Z + AISLE))
			else
				-- up or down a Shaft: the lower cell's stairs, Bottom (its floor) to Top (the floor above)
				local lower = if cu[1] > cv[1] then cu else cv
				local lowerUnit = if lower == cu then u else v
				local model = modelOf(lowerUnit)
				local bottom = if model then BunkerKit.Socket(model, "Bottom") else nil
				local top = if model then BunkerKit.Socket(model, "Top") else nil
				local up = cv[1] < cu[1]
				if bottom and top then
					local first, last = if up then bottom.Position else top.Position, if up then top.Position else bottom.Position
					table.insert(points, aisle(first.X, cu[1], cu[2]))
					table.insert(points, first)
					table.insert(points, last)
					table.insert(points, aisle(last.X, cv[1], cv[2]))
				else
					local pv = Grid.CellPosition(cv[1], cv[2])
					table.insert(points, Vector3.new(pv.X, pv.Y, pv.Z + AISLE))
				end
			end
		end
	end
	local floor, column = Grid.CellAt(target + Vector3.new(0, 1, 0))
	if floor and column then
		table.insert(points, Vector3.new(target.X, floorY(floor, column), Grid.CellPosition(floor, column).Z + AISLE))
	end
	table.insert(points, target)
	return points
end

return PathGraph
