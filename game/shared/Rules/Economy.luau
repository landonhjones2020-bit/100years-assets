--!strict
--[[
	Economy: the arithmetic of production, power and food (bible Sections 5, 6 and 13).
	EconomyService and PowerService run it on the server; the HUD and the Command View show
	its numbers. Nothing here touches the world, so DataTests can check every rule.

	Production (Section 13, provisional):
		Output per cycle = B x (sum of worker stat / 10) x L x M x R x P
	B is the room's Output.Base (what one cell's worth of workers with stats summing to 10
	makes), L Tuning.Rooms.LevelMultiplier, M Tuning.Rooms.MergeMultiplier by span, R the crew's
	average morale effect (Config.MoraleStates) and P 1 when lit, 0 when dark. The crew's own
	multiplier (traits, from ResidentService) and bunker-wide ones (a draft card, a class, the
	difficulty) come on top. A room with no crew, a dark room and a wrecked room (0 HP) make
	nothing. Rooms make it all the time (Section 5): the output per cycle is spread over a full
	cycle (Tuning.Clock.CycleSeconds), so a skipped day makes less.

	Power (Section 6): the Reactor Core and Generators (rooms with PowerOutput) need residents
	working in them, like every other room (Landon, Nov 8, 2026), and make PowerOutput[level]
	(the level is already in it) x (crew stat / 10) x M x R. Every room
	draws Power[level] per cell. When the draw passes what is made, rooms go dark farthest
	first: steps along the room graph from the nearest Reactor Core or Generator, dug cells
	counting as steps (Landon, Nov 7, 2026). A room nothing can reach is farthest of all; at the
	same distance the room drawing the most goes dark first (Landon, Nov 8, 2026), then the newest.
	Rooms that draw nothing (Shafts, Storage at level 1) never go dark, and a wrecked room (0 HP)
	draws nothing until it is repaired (Landon, Nov 8, 2026).

	Food and water (Section 5): every resident eats FoodPerCycle and drinks WaterPerCycle at the
	start of each cycle (food times their FoodUse). Whole units come off the stockpile and the
	rest carries to the next cycle, so someone who eats half takes 1 every other cycle.
]]

local Config = require(script.Parent.Parent.Config)

export type Crew = {
	Workers: number, -- residents working in the room
	StatSum: number, -- the sum of their stat for the room's job (Strength in the Reactor Core)
	Morale: number, -- their average morale effect: 0.85 to 1.2 (Config.MoraleStates)
	Multiplier: number?, -- their traits and the like (Green Thumb, Lazy), from ResidentService
}

export type Consumer = { Id: string, Draw: number, Steps: number?, Order: number }

export type Balance = {
	Made: number, -- power made
	Needed: number, -- power every room would draw
	Used: number, -- power the lit rooms draw
	Dark: { [string]: boolean }, -- dark room ids
	Draw: { [string]: number }, -- room id -> its draw (rooms that draw something)
	MadeBy: { [string]: number }, -- room id -> power it makes (the Reactor Core, Generators)
	Steps: { [string]: number }, -- graph node -> steps from the nearest power room (absent: unreachable)
}

local Economy = {}

local EPSILON = 1e-6

local function rooms(): { [string]: any }
	return Config.Get("Tuning", "Rooms")
end

function Economy.CycleSeconds(): number
	return Config.Get("Tuning", "Clock").CycleSeconds
end

-- The ore of the depth band a floor is in (Iron in the Mines), or nil.
function Economy.BandOre(floor: number): string?
	for _, band in Config.All("DepthBands") do
		if floor >= band.Floors.From and floor <= band.Floors.To then
			return band.Ore
		end
	end
	return nil
end

--[[
	What a room makes: "Resource" with the stocked resource ("Food"; a Drill Bay makes its band's
	ore), or its Output kind ("Research", "Morale", "Recruits"...) with no resource. nil for rooms
	that make nothing (Quarters, Storage, the Shaft) and for the power rooms (see PowerMade).
]]
function Economy.Makes(roomType: string, floor: number): (string?, string?)
	local output = Config.Get("Rooms", roomType).Output
	if not output then
		return nil, nil
	end
	if output.Kind == "Resource" then
		return "Resource", output.Resource
	elseif output.Kind == "BandOre" then
		local ore = Economy.BandOre(floor)
		return if ore then "Resource" else nil, ore
	end
	return output.Kind, nil
end

-- The crew's part of the formula: (stat sum / 10) x morale x their multiplier; 0 with no crew.
function Economy.CrewFactor(crew: Crew?): number
	if not crew or crew.Workers <= 0 or crew.StatSum <= 0 then
		return 0
	end
	return (crew.StatSum / 10) * crew.Morale * (crew.Multiplier or 1)
end

-- A room's output per cycle (Section 13). `multiplier` is everything bunker-wide on top.
function Economy.Output(roomType: string, level: number, span: number, crew: Crew?, lit: boolean, multiplier: number?): number
	local output = Config.Get("Rooms", roomType).Output
	if not output or not lit then
		return 0
	end
	local t = rooms()
	return output.Base * Economy.CrewFactor(crew) * t.LevelMultiplier[level] * t.MergeMultiplier[span] * (multiplier or 1)
end

-- Power a Reactor Core or Generator makes; 0 for any other room.
function Economy.PowerMade(roomType: string, level: number, span: number, crew: Crew?, multiplier: number?): number
	local made = Config.Get("Rooms", roomType).PowerOutput
	if not made then
		return 0
	end
	return made[level] * Economy.CrewFactor(crew) * rooms().MergeMultiplier[span] * (multiplier or 1)
end

-- Power a room draws: Power[level] for each of its cells.
function Economy.Draw(roomType: string, level: number, span: number): number
	return Config.Get("Rooms", roomType).Power[level] * span
end

function Economy.IsPowerRoom(roomType: string): boolean
	return Config.Get("Rooms", roomType).PowerOutput ~= nil
end

-- Steps from the nearest power room along the room graph (dug cells count), for every node
-- that can be reached from one.
function Economy.Steps(bunker: any): { [string]: number }
	local steps: { [string]: number } = {}
	local queue: { string } = {}
	for _, room in bunker:AllRooms() do
		if Economy.IsPowerRoom(room.Type) then
			steps[room.Id] = 0
			table.insert(queue, room.Id)
		end
	end
	local index = 1
	while index <= #queue do
		local unit = queue[index]
		for _, other in bunker:Neighbors(unit) do
			if steps[other] == nil then
				steps[other] = steps[unit] + 1
				table.insert(queue, other)
			end
		end
		index += 1
	end
	return steps
end

-- A room id's place in build order (R12 -> 12), for ties: the newest goes dark first.
function Economy.Order(roomId: string): number
	return tonumber(string.match(roomId, "%d+")) or 0
end

-- The rooms that go dark: farthest first (unreachable first of all), then the biggest draw, then
-- the newest, until what the rest draw fits in `made`.
function Economy.Shed(consumers: { Consumer }, made: number): { [string]: boolean }
	local needed = 0
	for _, consumer in consumers do
		needed += consumer.Draw
	end
	local dark: { [string]: boolean } = {}
	if needed <= made + EPSILON then
		return dark
	end
	local order = table.clone(consumers)
	table.sort(order, function(a: Consumer, b: Consumer): boolean
		local sa, sb = a.Steps or math.huge, b.Steps or math.huge
		if sa ~= sb then
			return sa > sb
		end
		if a.Draw ~= b.Draw then
			return a.Draw > b.Draw
		end
		return a.Order > b.Order
	end)
	for _, consumer in order do
		if needed <= made + EPSILON then
			break
		end
		dark[consumer.Id] = true
		needed -= consumer.Draw
	end
	return dark
end

--[[
	The whole power balance of a bunker. `crewOf(roomId)` gives a power room's crew;
	`multiplierOf(roomType)` bunker-wide power on top (the Overclock card). A wrecked power room
	(Rules.Bunker: from 0 HP until repaired) makes nothing and a wrecked room draws nothing.
]]
-- Wrecked (Prompt 13: from 0 HP until repaired); a record without the flag is wrecked at 0 HP.
local function wrecked(room: any): boolean
	if room.Wrecked ~= nil then
		return room.Wrecked == true
	end
	return room.HP <= 0
end

function Economy.Balance(bunker: any, crewOf: (string) -> Crew?, multiplierOf: ((string) -> number)?): Balance
	local steps = Economy.Steps(bunker)
	local made = 0
	local consumers: { Consumer } = {}
	local draw: { [string]: number } = {}
	local madeBy: { [string]: number } = {}
	for _, room in bunker:AllRooms() do
		if Economy.IsPowerRoom(room.Type) then
			local amount = 0
			if not wrecked(room) then
				amount = Economy.PowerMade(room.Type, room.Level, room.Span, crewOf(room.Id),
					if multiplierOf then multiplierOf(room.Type) else 1)
			end
			madeBy[room.Id] = amount
			made += amount
		end
		local d = if not wrecked(room) then Economy.Draw(room.Type, room.Level, room.Span) else 0 -- wrecked: none
		if d > 0 then
			draw[room.Id] = d
			table.insert(consumers, { Id = room.Id, Draw = d, Steps = steps[room.Id], Order = Economy.Order(room.Id) })
		end
	end
	local dark = Economy.Shed(consumers, made)
	local needed, used = 0, 0
	for id, d in draw do
		needed += d
		if not dark[id] then
			used += d
		end
	end
	return { Made = made, Needed = needed, Used = used, Dark = dark, Draw = draw, MadeBy = madeBy, Steps = steps }
end

-- Whole units eaten this cycle and the carry to the next: `uses` is each resident's use (1
-- normally; FoodUse changes it), `per` FoodPerCycle or WaterPerCycle.
function Economy.Eat(uses: { number }, per: number, carry: number): (number, number)
	local need = carry
	for _, use in uses do
		need += per * use
	end
	local take = math.floor(need + EPSILON)
	return take, math.max(0, need - take)
end

-- Progress toward whole units: `rate` per cycle for `seconds` of a cycle `cycle` seconds long.
-- Returns the whole units made and the fraction left over.
function Economy.Accrue(progress: number, rate: number, seconds: number, cycle: number): (number, number)
	local total = progress + rate * seconds / cycle
	local whole = math.floor(total + EPSILON)
	return whole, math.max(0, total - whole)
end

return Economy
