--!strict
--[[
	Rules.Bunker: the bunker as data, with the grid's rules (bible Section 6). Pure (no
	Instances), so BunkerGrid on the server, the Command View on the client (ghost outlines,
	what can be dug) and the data tests share it.

	Every cell on the grid is Rock, Dug (empty) or part of a room. `Cells` holds the open ones:
	"" for a Dug cell, the room's id for a room cell; a cell that isn't there is Rock.

	The rules:
	* Dig: a Rock cell to the left of, right of or below an open cell.
	* Place: a room on Dug cells side by side on one floor, at most its MaxCells, in a band
	  that can be built on (not the Source Chamber), on its own Floor if it has one, and only
	  one of a Unique room.
	* Merge: two rooms of one type and level side by side, at most MaxCells together (rooms at
	  different levels never merge; Landon, Nov 8, 2026). Fixed rooms (the Blast Door, the
	  Reactor Core) never merge, move or go. The merged room keeps both rooms' HP.
	* HP is per cell (Landon, Nov 8, 2026): a room's maximum is Tuning.Rooms.HP for its level
	  times its cells, so a 3-cell room at level 1 has 1,500. RoomHP and BlastDoorHealth
	  modifiers scale it (SetHPScale; Prompt 13).
	* Wrecked (Section 6: at 0 HP a room is wrecked and stops until repaired): a room is
	  Wrecked from the moment its HP reaches 0 until repairs bring it back to Tuning.Repairs
	  .RepairedAt of its maximum (Prompt 13). Wrecked rooms make nothing and draw nothing.
	* SetLevel: 1 to 3; HP keeps its share of the new maximum.
	* The room graph: a node per room ("R3") and per Dug cell ("D:2,3"), with an edge between
	  side-by-side open cells of different units (a doorway) and between stacked Shafts. A dug
	  cell is a step like a room when power counts steps from a Reactor Core or a Generator
	  (Section 6; Landon, Nov 8, 2026).

	Votes, costs and build time (BuildService, Prompt 8), dig time and Push Deeper (DigService,
	Prompt 14) are not here.
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)

export type CellState = "Rock" | "Dug" | "Room"
export type Room = {
	Id: string,
	Type: string,
	Floor: number,
	Column: number, -- the leftmost cell
	Span: number, -- cells, side by side
	Level: number,
	HP: number,
	MaxHP: number,
	Wrecked: boolean, -- from 0 HP until repaired to RepairedAt of MaxHP (Prompt 13)
}

type Data = {
	Cells: { [string]: string },
	Rooms: { [string]: Room },
	NextId: number,
	HPScale: { [string]: number }, -- "All" or a room type -> HP multiplier (RoomHP, BlastDoorHealth)
}

local Bunker = {}
Bunker.__index = Bunker

export type Bunker = typeof(setmetatable({} :: Data, Bunker))

local DUG_PREFIX = "D:"

-- A room's maximum HP: per cell, by level.
local function maxHP(level: number, span: number): number
	return Config.Get("Tuning", "Rooms").HP[level] * span
end

Bunker.MaxHP = maxHP

-- HP a wrecked room needs before it works again.
local function repairedAt(maxHPValue: number): number
	return math.ceil(maxHPValue * Config.Get("Tuning", "Repairs").RepairedAt)
end

Bunker.RepairedAt = repairedAt

local function idNumber(id: string): number
	return tonumber(string.sub(id, 2)) or 0
end

function Bunker.new(): Bunker
	return setmetatable({ Cells = {}, Rooms = {}, NextId = 1, HPScale = {} } :: Data, Bunker)
end

-- The starting bunker (Tuning.StartingBunker), built by the same rules.
function Bunker.FromStart(): Bunker
	local bunker = Bunker.new()
	local start = Config.Get("Tuning", "StartingBunker")
	for _, cell in start.Cells do
		for column = cell.Column, cell.Column + (cell.Span or 1) - 1 do
			bunker:Open(cell.Floor, column)
		end
	end
	for _, cell in start.Cells do
		if cell.Room then
			local id, why = bunker:Place(cell.Room, cell.Floor, cell.Column, cell.Span or 1)
			if not id then
				error(`Tuning.StartingBunker: {cell.Room} at {Grid.Key(cell.Floor, cell.Column)}: {why}`)
			end
		end
	end
	return bunker
end

-- A copy of the bunker from the replicated collections, for client previews (the Command
-- View's build menu): Cells maps "floor,column" to { Room = id } or {}, Rooms maps an id to
-- { Type, Floor, Column, Span, Level, HP, MaxHP }.
function Bunker.FromSnapshot(cells: { [string]: any }, rooms: { [string]: any }): Bunker
	local bunker = Bunker.new()
	for key, cell in cells do
		local roomId = if type(cell) == "table" then cell.Room else nil
		bunker.Cells[key] = if type(roomId) == "string" then roomId else ""
	end
	for id, room in rooms do
		bunker.Rooms[id] = {
			Id = id,
			Type = room.Type,
			Floor = room.Floor,
			Column = room.Column,
			Span = room.Span,
			Level = room.Level,
			HP = room.HP,
			MaxHP = room.MaxHP,
			Wrecked = if room.Wrecked ~= nil then room.Wrecked == true else room.HP <= 0,
		}
		bunker.NextId = math.max(bunker.NextId, idNumber(id) + 1)
	end
	return bunker
end

-- Cells ---------------------------------------------------------------------------------

-- Rock, Dug or Room (and the room's id); nil off the grid.
function Bunker.State(self: Bunker, floor: number, column: number): (CellState?, string?)
	if not Grid.OnGrid(floor, column) then
		return nil, nil
	end
	local value = self.Cells[Grid.Key(floor, column)]
	if value == nil then
		return "Rock", nil
	elseif value == "" then
		return "Dug", nil
	end
	return "Room", value
end

function Bunker.IsOpen(self: Bunker, floor: number, column: number): boolean
	local state = self:State(floor, column)
	return state == "Dug" or state == "Room"
end

-- Opens a cell with no questions asked: for the starting bunker and tests only.
function Bunker.Open(self: Bunker, floor: number, column: number)
	assert(Grid.OnGrid(floor, column), `Rules.Bunker: {Grid.Key(floor, column)} is off the grid`)
	local key = Grid.Key(floor, column)
	if self.Cells[key] == nil then
		self.Cells[key] = ""
	end
end

function Bunker.CanDig(self: Bunker, floor: number, column: number): (boolean, string?)
	if not Grid.OnGrid(floor, column) then
		return false, "off the grid"
	elseif self:IsOpen(floor, column) then
		return false, "already open"
	elseif self:IsOpen(floor, column - 1) or self:IsOpen(floor, column + 1) or self:IsOpen(floor - 1, column) then
		return true, nil
	end
	return false, "nothing dug beside or above it (dig left, right or down from a dug cell or room)"
end

function Bunker.Dig(self: Bunker, floor: number, column: number): (boolean, string?)
	local ok, why = self:CanDig(floor, column)
	if ok then
		self.Cells[Grid.Key(floor, column)] = ""
	end
	return ok, why
end

-- The deepest floor with an open cell.
function Bunker.DeepestFloor(self: Bunker): number
	local deepest = 0
	for key in self.Cells do
		local floor = Grid.Parse(key)
		if floor and floor > deepest then
			deepest = floor
		end
	end
	return deepest
end

-- Rooms ---------------------------------------------------------------------------------

-- A room's maximum HP here: per cell by level, times this bunker's RoomHP scale and its type's.
function Bunker.MaxHPOf(self: Bunker, roomType: string, level: number, span: number): number
	local scale = (self.HPScale.All or 1) * (self.HPScale[roomType] or 1)
	return math.floor(maxHP(level, span) * scale + 0.5)
end

-- Sets an HP multiplier ("All" rooms, or one room type) and rescales every room it touches,
-- each keeping its share of its maximum (RoomHP: Reinforced Walls; BlastDoorHealth).
function Bunker.SetHPScale(self: Bunker, key: string, value: number)
	self.HPScale[key] = if value == 1 then nil else value
	for _, room in self.Rooms do
		local newMax = self:MaxHPOf(room.Type, room.Level, room.Span)
		if newMax ~= room.MaxHP then
			room.HP = math.floor(room.HP / math.max(room.MaxHP, 1) * newMax + 0.5)
			room.MaxHP = newMax
		end
	end
end

-- Is the room wrecked? (Section 6: it stops until repaired.)
function Bunker.IsWrecked(room: Room?): boolean
	return room ~= nil and room.Wrecked == true
end

-- The live record: read it, never edit it (use the methods).
function Bunker.Room(self: Bunker, id: string): Room?
	return self.Rooms[id]
end

function Bunker.RoomAt(self: Bunker, floor: number, column: number): Room?
	local state, id = self:State(floor, column)
	return if state == "Room" and id then self.Rooms[id] else nil
end

function Bunker.IsShaft(self: Bunker, floor: number, column: number): boolean
	local room = self:RoomAt(floor, column)
	return room ~= nil and room.Type == "Shaft"
end

-- Every room, oldest first.
function Bunker.AllRooms(self: Bunker): { Room }
	local list = {}
	for _, room in self.Rooms do
		table.insert(list, room)
	end
	table.sort(list, function(a, b)
		return idNumber(a.Id) < idNumber(b.Id)
	end)
	return list
end

function Bunker.RoomsOfType(self: Bunker, roomType: string): { Room }
	local list = {}
	for _, room in self:AllRooms() do
		if room.Type == roomType then
			table.insert(list, room)
		end
	end
	return list
end

function Bunker.CanPlace(self: Bunker, roomType: string, floor: number, column: number, span: number): (boolean, string?)
	local info = Config.Find("Rooms", roomType)
	if not info then
		return false, `no room type {tostring(roomType)}`
	elseif span ~= math.floor(span) or span < 1 or span > info.MaxCells then
		return false, `{info.Name} takes 1 to {info.MaxCells} cells`
	end
	for offset = 0, span - 1 do
		local state = self:State(floor, column + offset)
		if state == nil then
			return false, "off the grid"
		elseif state ~= "Dug" then
			return false, `cell {Grid.Key(floor, column + offset)} isn't dug and empty`
		end
	end
	if not Grid.Buildable(floor) then
		return false, "nothing is built in the Source Chamber"
	elseif info.Floor and info.Floor ~= floor then
		return false, `{info.Name} only goes on floor {info.Floor}`
	elseif info.Unique and #self:RoomsOfType(roomType) > 0 then
		return false, `there is already a {info.Name}`
	end
	return true, nil
end

function Bunker.Place(self: Bunker, roomType: string, floor: number, column: number, span: number, level: number?): (string?, string?)
	local ok, why = self:CanPlace(roomType, floor, column, span)
	if not ok then
		return nil, why
	end
	local startLevel = level or 1
	if startLevel ~= 1 and startLevel ~= 2 and startLevel ~= 3 then
		return nil, "levels go from 1 to 3"
	end
	local id = `R{self.NextId}`
	self.NextId += 1
	local hp = self:MaxHPOf(roomType, startLevel, span)
	self.Rooms[id] = {
		Id = id,
		Type = roomType,
		Floor = floor,
		Column = column,
		Span = span,
		Level = startLevel,
		HP = hp,
		MaxHP = hp,
		Wrecked = false,
	}
	for offset = 0, span - 1 do
		self.Cells[Grid.Key(floor, column + offset)] = id
	end
	return id, nil
end

function Bunker.CanRemove(self: Bunker, id: string): (boolean, string?)
	local room = self.Rooms[id]
	if not room then
		return false, `no room {tostring(id)}`
	elseif Config.Get("Rooms", room.Type).Fixed then
		return false, `the {Config.Get("Rooms", room.Type).Name} can't be torn down`
	end
	return true, nil
end

-- Tears a room down; its cells become Dug again.
function Bunker.Remove(self: Bunker, id: string): (boolean, string?)
	local ok, why = self:CanRemove(id)
	if not ok then
		return false, why
	end
	local room = self.Rooms[id]
	for offset = 0, room.Span - 1 do
		self.Cells[Grid.Key(room.Floor, room.Column + offset)] = ""
	end
	self.Rooms[id] = nil
	return true, nil
end

function Bunker.CanMerge(self: Bunker, a: string, b: string): (boolean, string?)
	local first, second = self.Rooms[a], self.Rooms[b]
	if not first or not second then
		return false, "no such room"
	elseif a == b then
		return false, "a room can't merge with itself"
	end
	local info = Config.Get("Rooms", first.Type)
	if first.Type ~= second.Type then
		return false, "only matching rooms merge"
	elseif info.Fixed then
		return false, `the {info.Name} can't be merged`
	elseif first.Floor ~= second.Floor
		or (first.Column + first.Span ~= second.Column and second.Column + second.Span ~= first.Column)
	then
		return false, "the rooms aren't side by side"
	elseif first.Level ~= second.Level then
		return false, "the rooms are at different levels"
	elseif first.Span + second.Span > info.MaxCells then
		return false, `{info.Name} takes at most {info.MaxCells} cells`
	end
	return true, nil
end

-- Merges two rooms into one (the left room's id survives). Returns that id.
function Bunker.Merge(self: Bunker, a: string, b: string): (string?, string?)
	local ok, why = self:CanMerge(a, b)
	if not ok then
		return nil, why
	end
	local left, right = self.Rooms[a], self.Rooms[b]
	if right.Column < left.Column then
		left, right = right, left
	end
	for offset = 0, right.Span - 1 do
		self.Cells[Grid.Key(right.Floor, right.Column + offset)] = left.Id
	end
	left.Span += right.Span
	left.HP += right.HP -- HP is per cell: each part keeps what it had
	left.MaxHP = self:MaxHPOf(left.Type, left.Level, left.Span)
	left.HP = math.min(left.HP, left.MaxHP)
	left.Wrecked = (left.Wrecked or right.Wrecked) and left.HP < repairedAt(left.MaxHP)
	self.Rooms[right.Id] = nil
	return left.Id, nil
end

function Bunker.SetLevel(self: Bunker, id: string, level: number): (boolean, string?)
	local room = self.Rooms[id]
	if not room then
		return false, `no room {tostring(id)}`
	elseif level ~= 1 and level ~= 2 and level ~= 3 then
		return false, "levels go from 1 to 3"
	end
	local newMax = self:MaxHPOf(room.Type, level, room.Span)
	room.HP = math.floor(room.HP / room.MaxHP * newMax + 0.5)
	room.MaxHP = newMax
	room.Level = level
	if room.Wrecked and room.HP >= repairedAt(room.MaxHP) then
		room.Wrecked = false
	end
	return true, nil
end

-- Sets a room's HP. At 0 it is Wrecked; a wrecked room works again once repairs bring it back
-- to RepairedAt of its maximum (Prompt 13). Returns the HP it now has.
function Bunker.SetHP(self: Bunker, id: string, hp: number): number?
	local room = self.Rooms[id]
	if not room then
		return nil
	end
	room.HP = math.clamp(math.floor(hp + 0.5), 0, room.MaxHP)
	if room.HP <= 0 then
		room.Wrecked = true
	elseif room.Wrecked and room.HP >= repairedAt(room.MaxHP) then
		room.Wrecked = false
	end
	return room.HP
end

-- The room graph ------------------------------------------------------------------------

-- The graph node a cell belongs to: a room id, "D:<key>" for a Dug cell, nil for Rock.
function Bunker.UnitAt(self: Bunker, floor: number, column: number): string?
	local state, id = self:State(floor, column)
	if state == "Room" then
		return id
	elseif state == "Dug" then
		return DUG_PREFIX .. Grid.Key(floor, column)
	end
	return nil
end

-- The cells of a node, as { floor, column } pairs.
function Bunker.CellsOf(self: Bunker, unit: string): { { number } }
	if string.sub(unit, 1, #DUG_PREFIX) == DUG_PREFIX then
		local floor, column = Grid.Parse(string.sub(unit, #DUG_PREFIX + 1))
		if floor and column and self:State(floor, column) == "Dug" then
			return { { floor, column } }
		end
		return {}
	end
	local room = self.Rooms[unit]
	local cells = {}
	if room then
		for offset = 0, room.Span - 1 do
			table.insert(cells, { room.Floor, room.Column + offset })
		end
	end
	return cells
end

-- Every node: rooms oldest first, then Dug cells by key.
function Bunker.Units(self: Bunker): { string }
	local units = {}
	for _, room in self:AllRooms() do
		table.insert(units, room.Id)
	end
	local dug = {}
	for key, value in self.Cells do
		if value == "" then
			table.insert(dug, DUG_PREFIX .. key)
		end
	end
	table.sort(dug)
	table.move(dug, 1, #dug, #units + 1, units)
	return units
end

function Bunker.Neighbors(self: Bunker, unit: string): { string }
	local found: { [string]: boolean } = {}
	local list = {}
	local function add(other: string?)
		if other and other ~= unit and not found[other] then
			found[other] = true
			table.insert(list, other)
		end
	end
	for _, cell in self:CellsOf(unit) do
		local floor, column = cell[1], cell[2]
		add(self:UnitAt(floor, column - 1))
		add(self:UnitAt(floor, column + 1))
		if self:IsShaft(floor, column) then
			if self:IsShaft(floor - 1, column) then
				add(self:UnitAt(floor - 1, column))
			end
			if self:IsShaft(floor + 1, column) then
				add(self:UnitAt(floor + 1, column))
			end
		end
	end
	table.sort(list)
	return list
end

function Bunker.Graph(self: Bunker): { [string]: { string } }
	local graph = {}
	for _, unit in self:Units() do
		graph[unit] = self:Neighbors(unit)
	end
	return graph
end

-- Every node reachable from `from` (including it).
function Bunker.Reachable(self: Bunker, from: string): { [string]: boolean }
	local seen: { [string]: boolean } = { [from] = true }
	local queue = { from }
	local index = 1
	while index <= #queue do
		for _, other in self:Neighbors(queue[index]) do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
		index += 1
	end
	return seen
end

return Bunker
