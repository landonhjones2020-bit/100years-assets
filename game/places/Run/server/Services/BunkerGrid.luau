--!strict
--[[
	BunkerGrid: the bunker's cells, rooms, levels, merges and the room graph (bible Sections 6
	and 23). Run place only.

	The data and its rules are Shared.Rules.Bunker (Rock, Dug and room cells; dig left, right
	or down; rooms on Dug cells, MaxCells, Unique, Fixed, floor rules; matching rooms merge;
	levels 1 to 3; the graph of doorways and Shafts). This service holds the run's one bunker,
	starts it from Tuning.StartingBunker, builds the world from it (Lib.BunkerKit, graybox
	until the A1 art) and replicates it:
	* Cells collection: "floor,column" -> { Room = id } for every open cell ({} when Dug);
	* Rooms collection: id -> { Type, Floor, Column, Span, Level, HP, MaxHP, Wrecked }.

	HP (Prompt 13): SetHP is how damage and repairs land. A room at 0 HP is Wrecked until it is
	repaired to Tuning.Repairs.RepairedAt of its maximum (Rules.Bunker); Wrecked and Repaired
	fire when that changes. SetHPModifier applies the RoomHP (every room) and BlastDoorHealth
	(the Blast Door) multipliers from draft cards and classes.

	Votes, costs and build time are BuildService's (Prompt 8); dig time, cell rolls and Push
	Deeper are DigService's (Prompt 14). They call the methods below.

	API:
		BunkerGrid:Bunker(): Bunker               -- the live data: read only
		BunkerGrid:State(floor, column), :Room(id), :RoomAt(floor, column), :Rooms(), :RoomsOfType(type)
		BunkerGrid:Dig(floor, column): (boolean, string?)
		BunkerGrid:PlaceRoom(type, floor, column, span, level?): (string?, string?)
		BunkerGrid:RemoveRoom(id): (boolean, string?)
		BunkerGrid:MergeRooms(a, b): (string?, string?)
		BunkerGrid:SetLevel(id, level): (boolean, string?)
		BunkerGrid:SetHP(id, hp): number?
		BunkerGrid:SetHPModifier(source, key, value?)  -- RoomHP or BlastDoorHealth; nil clears
		BunkerGrid:Neighbors(unit), :Graph(), :DeepestFloor()
		BunkerGrid:RoomModel(id): Model?, :Root(): Folder
		BunkerGrid.Changed: Signal<{ string }>    -- the cell keys whose state changed
		BunkerGrid.RoomChanged: Signal<string>    -- a room was added, changed or removed
	BunkerGrid.Wrecked: Signal<string>        -- a room's HP reached 0 (Prompt 13: the Reactor Core melts down)
	BunkerGrid.Repaired: Signal<string>       -- a wrecked room works again
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Bunker = require(Shared.Rules.Bunker)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("BunkerGrid")

local BunkerGrid = {
	Name = "BunkerGrid",
	Dependencies = { "ReplicationService", "DevService" },
	Changed = Signal.new() :: Signal.Signal<{ string }>,
	RoomChanged = Signal.new() :: Signal.Signal<string>,
	Wrecked = Signal.new() :: Signal.Signal<string>,
	Repaired = Signal.new() :: Signal.Signal<string>,
}

-- Which room types an HP modifier key scales (Config.Modifiers, Prompt 13).
local HP_KEYS: { [string]: string } = { RoomHP = "All", BlastDoorHealth = "BlastDoor" }

local CODES: { [string]: string } = {
	BlastDoor = "BLD", Shaft = "SHF", ReactorCore = "RCT", Generator = "GEN", Kitchen = "KIT",
	WaterPurifier = "WTR", Quarters = "QTR", Medbay = "MED", Storage = "STO", Workshop = "WRK",
	Armory = "ARM", RadioRoom = "RAD", Lounge = "LNG", Lab = "LAB", DrillBay = "DRL",
	Greenhouse = "GRN", TrainingRoom = "TRN", DeconRoom = "DCN", CryoBay = "CRY",
	TradingPost = "TRD", Memorial = "MEM",
}

local bunker: Bunker.Bunker = Bunker.new()
local root: Folder? = nil
local cellsCollection: any = nil
local roomsCollection: any = nil
local hpModifiers: { [string]: { [string]: number } } = {} -- key -> source -> multiplier

-- Replication and the world ---------------------------------------------------------------

local function publishRoom(id: string)
	local room = bunker:Room(id)
	if room then
		roomsCollection:Set(id, {
			Type = room.Type,
			Floor = room.Floor,
			Column = room.Column,
			Span = room.Span,
			Level = room.Level,
			HP = room.HP,
			MaxHP = room.MaxHP,
			Wrecked = room.Wrecked,
		})
	elseif roomsCollection:Get(id) ~= nil then
		roomsCollection:Remove(id)
	end
end

local function publishCell(key: string)
	local floor, column = Grid.Parse(key)
	if not floor or not column then
		return
	end
	local state, id = bunker:State(floor, column)
	if state == "Dug" then
		cellsCollection:Set(key, {})
	elseif state == "Room" then
		cellsCollection:Set(key, { Room = id })
	elseif cellsCollection:Get(key) ~= nil then
		cellsCollection:Remove(key)
	end
end

-- The cells of these rooms and cells, and their neighbours left, right, above and below.
local function around(cells: { { number } }): { [string]: boolean }
	local dirty: { [string]: boolean } = {}
	for _, cell in cells do
		local floor, column = cell[1], cell[2]
		for _, offset in { { 0, 0 }, { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local f, c = floor + offset[1], column + offset[2]
			if Grid.OnGrid(f, c) then
				dirty[Grid.Key(f, c)] = true
			end
		end
	end
	return dirty
end

local function roomCells(room: Bunker.Room): { { number } }
	local cells = {}
	for offset = 0, room.Span - 1 do
		table.insert(cells, { room.Floor, room.Column + offset })
	end
	return cells
end

-- After a change: replicate the changed cells and rooms, rebuild the world around them.
local function changed(cells: { { number } }, roomIds: { string })
	local keys = {}
	for _, cell in cells do
		local key = Grid.Key(cell[1], cell[2])
		table.insert(keys, key)
		publishCell(key)
	end
	for _, id in roomIds do
		publishRoom(id)
	end
	if root then
		BunkerKit.Sync(bunker, root, around(cells))
	end
	BunkerGrid.Changed:Fire(keys)
	for _, id in roomIds do
		BunkerGrid.RoomChanged:Fire(id)
	end
end

-- API ----------------------------------------------------------------------------------------

function BunkerGrid:Bunker(): Bunker.Bunker
	return bunker
end

function BunkerGrid:Root(): Folder?
	return root
end

function BunkerGrid:State(floor: number, column: number): (Bunker.CellState?, string?)
	return bunker:State(floor, column)
end

function BunkerGrid:Room(id: string): Bunker.Room?
	return bunker:Room(id)
end

function BunkerGrid:RoomAt(floor: number, column: number): Bunker.Room?
	return bunker:RoomAt(floor, column)
end

function BunkerGrid:Rooms(): { Bunker.Room }
	return bunker:AllRooms()
end

function BunkerGrid:RoomsOfType(roomType: string): { Bunker.Room }
	return bunker:RoomsOfType(roomType)
end

function BunkerGrid:Neighbors(unit: string): { string }
	return bunker:Neighbors(unit)
end

function BunkerGrid:Graph(): { [string]: { string } }
	return bunker:Graph()
end

function BunkerGrid:DeepestFloor(): number
	return bunker:DeepestFloor()
end

function BunkerGrid:RoomModel(id: string): Model?
	local folder = root and root:FindFirstChild("Rooms")
	local model = folder and folder:FindFirstChild(id)
	return if model and model:IsA("Model") then model else nil
end

function BunkerGrid:Dig(floor: number, column: number): (boolean, string?)
	local ok, why = bunker:Dig(floor, column)
	if ok then
		log:Info("dug %s", Grid.Key(floor, column))
		changed({ { floor, column } }, {})
	end
	return ok, why
end

function BunkerGrid:PlaceRoom(roomType: string, floor: number, column: number, span: number, level: number?): (string?, string?)
	local id, why = bunker:Place(roomType, floor, column, span, level)
	if id then
		local room = bunker:Room(id) :: Bunker.Room
		log:Info("%s %s on floor %d, columns %d to %d", id, roomType, floor, column, column + span - 1)
		changed(roomCells(room), { id })
	end
	return id, why
end

function BunkerGrid:RemoveRoom(id: string): (boolean, string?)
	local room = bunker:Room(id)
	local cells = if room then roomCells(room) else {}
	local ok, why = bunker:Remove(id)
	if ok then
		log:Info("%s torn down", id)
		changed(cells, { id })
	end
	return ok, why
end

function BunkerGrid:MergeRooms(a: string, b: string): (string?, string?)
	local first, second = bunker:Room(a), bunker:Room(b)
	local cells = {}
	for _, room in { first, second } do
		if room then
			for _, cell in roomCells(room) do
				table.insert(cells, cell)
			end
		end
	end
	local id, why = bunker:Merge(a, b)
	if id then
		log:Info("%s and %s merged into %s", a, b, id)
		changed(cells, { a, b })
	end
	return id, why
end

function BunkerGrid:SetLevel(id: string, level: number): (boolean, string?)
	local ok, why = bunker:SetLevel(id, level)
	if ok then
		changed(roomCells(bunker:Room(id) :: Bunker.Room), { id })
	end
	return ok, why
end

function BunkerGrid:SetHP(id: string, hp: number): number?
	local room = bunker:Room(id)
	if not room then
		return nil
	end
	local before, wasWrecked = room.HP, room.Wrecked
	local result = bunker:SetHP(id, hp)
	if result and (result ~= before or room.Wrecked ~= wasWrecked) then
		roomsCollection:Patch(id, { HP = result, Wrecked = room.Wrecked })
		BunkerGrid.RoomChanged:Fire(id)
		if room.Wrecked and not wasWrecked then
			log:Info("%s (%s) is wrecked", id, room.Type)
			BunkerGrid.Wrecked:Fire(id)
		elseif wasWrecked and not room.Wrecked then
			log:Info("%s (%s) is repaired", id, room.Type)
			BunkerGrid.Repaired:Fire(id)
		end
	end
	return result
end

-- RoomHP (every room) and BlastDoorHealth (the Blast Door) multipliers, by source (a draft card,
-- a class); nil clears that source's. Every room keeps its share of its HP.
function BunkerGrid:SetHPModifier(source: string, key: string, value: number?)
	local target = HP_KEYS[key]
	assert(target, `BunkerGrid:SetHPModifier: {key} isn't an HP modifier`)
	hpModifiers[key] = hpModifiers[key] or {}
	hpModifiers[key][source] = value
	local product = 1
	for _, v in hpModifiers[key] do
		product *= v
	end
	bunker:SetHPScale(target, product)
	for _, room in bunker:AllRooms() do
		publishRoom(room.Id)
	end
end

-- DevTools ----------------------------------------------------------------------------------

local function map(): string
	local t = Grid.Tuning()
	local lines = {}
	local header = { "floor  " }
	for column = t.ColumnMin, t.ColumnMax do
		table.insert(header, string.format("%5d", column))
	end
	table.insert(lines, table.concat(header))
	local last = math.min(t.FloorMax, math.max(bunker:DeepestFloor() + 1, 3))
	for floor = t.FloorMin, last do
		local row = { string.format("%5d  ", floor) }
		for column = t.ColumnMin, t.ColumnMax do
			local state, id = bunker:State(floor, column)
			local token = "  ###"
			if state == "Dug" then
				token = "  ..."
			elseif state == "Room" and id then
				local room = bunker:Room(id) :: Bunker.Room
				token = `  {CODES[room.Type] or string.sub(room.Type, 1, 3)}`
			end
			table.insert(row, token)
		end
		table.insert(lines, table.concat(row))
	end
	return table.concat(lines, "\n")
end

local function roomList(): string
	local lines = {}
	for _, room in bunker:AllRooms() do
		table.insert(lines, `{room.Id} {room.Type} L{room.Level} floor {room.Floor} columns {room.Column}..{room.Column + room.Span - 1} HP {room.HP}/{room.MaxHP}{if room.Wrecked then " WRECKED" else ""}`)
	end
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("grid", {
		Description = "The bunker map (### rock, ... dug, room codes) and its size.",
		Run = function(): string?
			local parts = if root then BunkerKit.PartCount(root) else 0
			return `{map()}\n{#bunker:AllRooms()} rooms, deepest floor {bunker:DeepestFloor()}, {parts} parts`
		end,
	})
	dev:Register("grid.rooms", {
		Description = "Every room: id, type, level, cells and HP.",
		Run = function(): string?
			return roomList()
		end,
	})
	dev:Register("grid.graph", {
		Description = "The room graph: each room or dug cell and what it connects to.",
		Run = function(): string?
			local lines = {}
			local graph = bunker:Graph()
			for _, unit in bunker:Units() do
				table.insert(lines, `{unit}: {table.concat(graph[unit], ", ")}`)
			end
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("grid.dig", {
		Description = "Dig a rock cell (no time, no vote: DigService adds those).",
		Usage = "grid.dig <floor> <column>",
		Run = function(_player, args): string?
			local floor, column = tonumber(args[1]), tonumber(args[2])
			if not floor or not column then
				return "usage: grid.dig <floor> <column>"
			end
			local ok, why = BunkerGrid:Dig(floor, column)
			return if ok then map() else `can't dig: {why}`
		end,
	})
	dev:Register("grid.build", {
		Description = "Place a room on dug cells (no vote or cost: BuildService adds those).",
		Usage = "grid.build <RoomType> <floor> <column> [span] [level]",
		Run = function(_player, args): string?
			local roomType = tostring(args[1] or "")
			local floor, column = tonumber(args[2]), tonumber(args[3])
			local span, level = tonumber(args[4]) or 1, tonumber(args[5])
			if not floor or not column then
				return "usage: grid.build <RoomType> <floor> <column> [span] [level]"
			end
			local id, why = BunkerGrid:PlaceRoom(roomType, floor, column, span, level)
			return if id then `{id} placed\n{map()}` else `can't build: {why}`
		end,
	})
	dev:Register("grid.remove", {
		Description = "Tear a room down (its cells become dug).",
		Usage = "grid.remove <roomId>",
		Run = function(_player, args): string?
			local ok, why = BunkerGrid:RemoveRoom(tostring(args[1] or ""))
			return if ok then map() else `can't remove: {why}`
		end,
	})
	dev:Register("grid.merge", {
		Description = "Merge two matching rooms side by side.",
		Usage = "grid.merge <roomId> <roomId>",
		Run = function(_player, args): string?
			local id, why = BunkerGrid:MergeRooms(tostring(args[1] or ""), tostring(args[2] or ""))
			return if id then `merged into {id}\n{roomList()}` else `can't merge: {why}`
		end,
	})
	dev:Register("grid.level", {
		Description = "Set a room's level (1 to 3).",
		Usage = "grid.level <roomId> <level>",
		Run = function(_player, args): string?
			local ok, why = BunkerGrid:SetLevel(tostring(args[1] or ""), tonumber(args[2]) or 0)
			return if ok then roomList() else `can't set the level: {why}`
		end,
	})
	dev:Register("grid.hp", {
		Description = "Set a room's HP (0 wrecks it; a wrecked room works again at Tuning.Repairs.RepairedAt).",
		Usage = "grid.hp <roomId> <hp>",
		Run = function(_player, args): string?
			local id, hp = tostring(args[1] or ""), tonumber(args[2])
			if not hp or not bunker:Room(id) then
				return "usage: grid.hp <roomId> <hp> (see grid.rooms)"
			end
			BunkerGrid:SetHP(id, hp)
			local room = bunker:Room(id) :: Bunker.Room
			return `{id} {room.Type}: {room.HP}/{room.MaxHP}{if room.Wrecked then ", WRECKED" else ""}`
		end,
	})
	dev:Register("grid.sockets", {
		Description = "A room's gameplay points (work spots, beds, valves...) and where they are.",
		Usage = "grid.sockets <roomId>",
		Run = function(_player, args): string?
			local model = BunkerGrid:RoomModel(tostring(args[1] or ""))
			if not model then
				return "usage: grid.sockets <roomId> (see grid.rooms)"
			end
			local lines = {}
			for name, at in BunkerKit.Sockets(model) do
				local p = at.Position
				table.insert(lines, string.format("%s (%.1f, %.1f, %.1f)", name, p.X, p.Y, p.Z))
			end
			table.sort(lines)
			return `{model.Name}: {#lines} sockets\n{table.concat(lines, "\n")}`
		end,
	})
	dev:Register("grid.art", {
		Description = "Which units are built from the art kit and which from the graybox.",
		Run = function(): string?
			if not root then
				return "no bunker world yet"
			end
			local art, gray = {}, {}
			for _, folderName in { "Rooms", "Dug" } do
				local folder = root:FindFirstChild(folderName)
				for _, model in if folder then folder:GetChildren() else {} do
					table.insert(if model:GetAttribute("Art") then art else gray, model.Name)
				end
			end
			local lights = 0
			for _, item in root:GetDescendants() do
				if item:IsA("PointLight") then
					lights += 1
				end
			end
			return `art kit: {if BunkerKit.HasArt() then "yes" else "missing"}\nart: {table.concat(art, ", ")}\ngraybox: {table.concat(gray, ", ")}\n{lights} lights, {BunkerKit.PartCount(root)} parts`
		end,
	})
	dev:Register("grid.rebuild", {
		Description = "Rebuild the whole bunker world from the data.",
		Run = function(): string?
			if not root then
				return "no bunker world yet"
			end
			local began = os.clock()
			root:ClearAllChildren()
			BunkerKit.Sync(bunker, root, nil)
			return `rebuilt {BunkerKit.PartCount(root)} parts in {string.format("%.1f", (os.clock() - began) * 1000)} ms`
		end,
	})
end

-- Lifecycle -----------------------------------------------------------------------------------

function BunkerGrid:Init(registry)
	bunker = Bunker.FromStart()
	cellsCollection = registry.ReplicationService:Collection("Cells")
	roomsCollection = registry.ReplicationService:Collection("Rooms")
	for key in bunker.Cells do
		publishCell(key)
	end
	for _, room in bunker:AllRooms() do
		publishRoom(room.Id)
	end
	registerCommands(registry.DevService)
end

function BunkerGrid:Start()
	local began = os.clock()
	local old = workspace:FindFirstChild("Bunker")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bunker"
	BunkerKit.Sync(bunker, folder, nil)
	folder.Parent = workspace
	root = folder

	-- Players spawn in the Medbay (their respawn point); other spawns in the place sleep.
	for _, item in workspace:GetDescendants() do
		if item:IsA("SpawnLocation") and not item:IsDescendantOf(folder) then
			item.Enabled = false
		end
	end
	local open = 0
	for _ in bunker.Cells do
		open += 1
	end
	log:Info(
		"bunker built from the %s: %d rooms, %d open cells, %d parts in %.1f ms",
		if BunkerKit.HasArt() then "art kit" else "graybox",
		#bunker:AllRooms(),
		open,
		BunkerKit.PartCount(folder),
		(os.clock() - began) * 1000
	)
end

return BunkerGrid
