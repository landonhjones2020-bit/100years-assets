--!strict
--[[
	Rules.Construction: what a construction proposal needs and how long a build takes (bible
	Sections 6 and 8). Pure, so BuildService, the Command View and the data tests share it.

	* Actions:
	  * Build: a room on an open cell, paying its level-1 costs.
	  * Upgrade: the next level's costs for every cell of the room; level 3 also needs Lab
	    research (a threshold the Lab reaches, not spent).
	  * Merge: a room with a matching neighbour (free).
	  * TearDown: a room goes and its cells become open cells (free, nothing back).
	* Unlocks (Section 6), for Build: Start; a blueprint draft; a draft or reaching depth N; an
	  era; the first cryo pod. Rooms won from drafts or cryo pods come in `Context.Unlocked`.
	* Reserved cells: a cell in an open vote or under construction can't be in another
	  proposal.
	* Construction time: BuildSecondsPerCell (20) for each cell. Each helper nearby adds
	  HelperBuildSpeed (25%) to the speed (players now, residents with Prompt 10).
]]

local Config = require(script.Parent.Parent.Config)
local Grid = require(script.Parent.Grid)
local Hud = require(script.Parent.Hud)

export type Action = "Build" | "Upgrade" | "Merge" | "TearDown"
export type Proposal = {
	Action: Action,
	Floor: number,
	Column: number,
	RoomType: string?, -- Build
	Other: string?, -- Merge: the room it joins
}
export type Context = {
	Era: number, -- the current era's place in Config.Eras (1 to 4)
	Deepest: number, -- the deepest open floor
	Unlocked: { [string]: boolean }?, -- room types won from drafts or cryo pods
	Stock: { [string]: number }?, -- the stockpile; nil skips the cost check
	Research: number?, -- Lab research so far; nil skips the research check
	Reserved: { [string]: boolean }?, -- cell keys in open votes or under construction
}
export type Plan = {
	Action: Action,
	Floor: number,
	Column: number,
	Span: number, -- the cells it covers (a merge: both rooms)
	RoomType: string, -- what it builds or changes
	RoomId: string?, -- the room it changes
	Other: string?, -- Merge: the other room
	Level: number?, -- Upgrade: the new level
	Costs: { [string]: number },
	Research: number?, -- Upgrade to level 3: the research it needs
	Label: string, -- "KITCHEN", "QUARTERS TO LEVEL 2", "MERGE STORAGE", "TEAR DOWN MEDBAY"
}

local Construction = {}

local function rooms(): { [string]: any }
	return Config.Get("Tuning", "Rooms")
end

local function nameOf(roomType: string): string
	local info = Config.Find("Rooms", roomType)
	return if info then info.Name else roomType
end

function Construction.Seconds(span: number): number
	return rooms().BuildSecondsPerCell * span
end

-- How fast a site builds with `helpers` nearby (1 alone, 1.25 with one helper...).
function Construction.Rate(helpers: number): number
	return 1 + rooms().HelperBuildSpeed * math.max(0, helpers)
end

-- A room type's costs at `level` (1 to 3) for `span` cells (Config.Rooms costs are per cell,
-- like HP and power, so a merged room pays for every cell it upgrades).
function Construction.CostsAt(roomType: string, level: number, span: number?): { [string]: number }
	local costs = {}
	for id, amount in Config.Get("Rooms", roomType).Costs[level] or {} do
		costs[id] = amount * (span or 1)
	end
	return costs
end

-- Research needed to upgrade a room type to `level`: its Research for level 3, else none.
function Construction.ResearchFor(roomType: string, level: number): number
	if level >= 3 then
		return Config.Get("Rooms", roomType).Research or 0
	end
	return 0
end

-- Can `stock` pay `costs`? If not, the first short resource and how much is missing.
function Construction.CanAfford(costs: { [string]: number }, stock: { [string]: number }): (boolean, string?, number?)
	for _, id in Config.Ids("Resources") do
		local amount = costs[id]
		if amount and amount > 0 and (stock[id] or 0) < amount then
			return false, id, amount - (stock[id] or 0)
		end
	end
	return true, nil, nil
end

-- "120 SCRAP · 20 IRON" in Config.Resources order, or "FREE".
function Construction.CostText(costs: { [string]: number }?): string
	local parts = {}
	for _, id in Config.Ids("Resources") do
		local amount = if costs then costs[id] else nil
		if amount and amount > 0 then
			table.insert(parts, `{amount} {string.upper(Config.Get("Resources", id).Name)}`)
		end
	end
	return if #parts > 0 then table.concat(parts, " · ") else "FREE"
end

-- Is a room type unlocked for building? If not, what unlocks it.
function Construction.Unlock(roomType: string, context: Context): (boolean, string?)
	local unlock = Config.Get("Rooms", roomType).Unlock
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
	return true, nil
end

local function reservedRoom(bunker: any, roomId: string, reserved: { [string]: boolean }?): boolean
	if not reserved then
		return false
	end
	local room = bunker:Room(roomId)
	if room then
		for offset = 0, room.Span - 1 do
			if reserved[Grid.Key(room.Floor, room.Column + offset)] then
				return true
			end
		end
	end
	return false
end

-- Checks a proposal against the bunker and the context. Returns the plan, or nil and why not
-- (a sentence for the player).
function Construction.Plan(bunker: any, proposal: Proposal, context: Context): (Plan?, string?)
	local floor, column = proposal.Floor, proposal.Column
	if not Grid.OnGrid(floor, column) then
		return nil, "That cell is off the grid."
	end
	local plan: Plan
	if proposal.Action == "Build" then
		local roomType = proposal.RoomType
		if not roomType or not Config.Find("Rooms", roomType) then
			return nil, "That isn't a room type."
		end
		local info = Config.Get("Rooms", roomType)
		if info.Fixed then
			return nil, `The {info.Name} comes with the bunker.`
		end
		if context.Reserved and context.Reserved[Grid.Key(floor, column)] then
			return nil, "Something is already proposed or being built there."
		end
		local unlocked, why = Construction.Unlock(roomType, context)
		if not unlocked then
			return nil, `{info.Name}: {why}.`
		end
		local ok, reason = bunker:CanPlace(roomType, floor, column, 1)
		if not ok then
			return nil, `Can't build a {info.Name} there: {reason}.`
		end
		plan = {
			Action = "Build", Floor = floor, Column = column, Span = 1, RoomType = roomType,
			Costs = Construction.CostsAt(roomType, 1), Label = string.upper(info.Name),
		}
	else
		local room = bunker:RoomAt(floor, column)
		if not room then
			return nil, "There's no room there."
		end
		if reservedRoom(bunker, room.Id, context.Reserved) then
			return nil, `The {nameOf(room.Type)} already has a proposal open.`
		end
		local name = nameOf(room.Type)
		if proposal.Action == "Upgrade" then
			if room.Level >= 3 then
				return nil, `The {name} is at level 3 already.`
			end
			local level = room.Level + 1
			plan = {
				Action = "Upgrade", Floor = room.Floor, Column = room.Column, Span = room.Span, RoomType = room.Type,
				RoomId = room.Id, Level = level, Costs = Construction.CostsAt(room.Type, level, room.Span),
				Research = Construction.ResearchFor(room.Type, level), Label = `{string.upper(name)} TO LEVEL {level}`,
			}
			local needs = plan.Research or 0
			if needs > 0 and context.Research ~= nil and context.Research < needs then
				return nil, `Level 3 needs {needs} Lab research ({math.floor(context.Research)} so far).`
			end
		elseif proposal.Action == "Merge" then
			local other = if proposal.Other then bunker:Room(proposal.Other) else nil
			if not other then
				return nil, "There's no room to merge with."
			end
			if reservedRoom(bunker, other.Id, context.Reserved) then
				return nil, `The other {nameOf(other.Type)} already has a proposal open.`
			end
			local ok, why = bunker:CanMerge(room.Id, other.Id)
			if not ok then
				return nil, `Can't merge: {why}.`
			end
			plan = {
				Action = "Merge", Floor = room.Floor, Column = math.min(room.Column, other.Column),
				Span = room.Span + other.Span, RoomType = room.Type, RoomId = room.Id, Other = other.Id,
				Costs = {}, Label = `MERGE {string.upper(name)}`,
			}
		elseif proposal.Action == "TearDown" then
			local ok, why = bunker:CanRemove(room.Id)
			if not ok then
				return nil, `Can't tear down the {name}: {why}.`
			end
			plan = {
				Action = "TearDown", Floor = room.Floor, Column = room.Column, Span = room.Span, RoomType = room.Type,
				RoomId = room.Id, Costs = {}, Label = `TEAR DOWN {string.upper(name)}`,
			}
		else
			return nil, "That isn't something to propose."
		end
	end
	if context.Stock then
		local ok, short, missing = Construction.CanAfford(plan.Costs, context.Stock)
		if not ok and short then
			return nil, `The stockpile is {missing} {Config.Get("Resources", short).Name} short.`
		end
	end
	return plan, nil
end

-- The cells a plan covers, as keys.
function Construction.Cells(plan: Plan): { string }
	local keys = {}
	for offset = 0, plan.Span - 1 do
		table.insert(keys, Grid.Key(plan.Floor, plan.Column + offset))
	end
	return keys
end

return Construction
