--!strict
--[[
	EconomyService: the team's shared stockpile, production, consumption and caps (bible
	Sections 5, 13 and 23). Run place only.

	* The stockpile (Prompt 8): every stocked resource in Config.Resources starts at its Start
	  amount (Section 6). Caps: each resource's Cap plus CapPerStorageCell for every Storage
	  cell, times bunker-wide StockpileCaps modifiers (the Quartermaster, Prompt 20). Adding
	  stops at the cap; a stock above a lower cap keeps what it has but can't grow.
	* Production (Prompt 9): rooms make things all the time while the run clock runs (Section
	  5). A room's output per cycle is Rules.Economy.Output, Section 13's formula, from its crew,
	  level and span, whether it is lit (PowerService pushes the dark rooms in with SetPowered)
	  and bunker-wide modifiers (RoomOutput, AllOutput; the difficulty's ResourceMultiplier on
	  stock). Whole units go into the stockpile as they are made; the fractions carry over. Lab
	  research adds to Research. Outputs that aren't stock (the Lounge's morale, the Radio
	  Room's recruits, training, crafting, thawing, decon) get a rate here for the systems that
	  use them later (Rate).
	* Consumption (Prompt 9): at the start of every cycle each resident eats FoodPerCycle Food
	  (times their FoodUse and bunker-wide FoodUse) and drinks WaterPerCycle Water
	  (Tuning.Residents). If the stockpile can't cover it, it gives what it has, Shortfall fires
	  with what was missing (ResidentService makes the hungry pay in health and morale, Prompt 10)
	  and the team gets an alert.
	* The crew and the eaters come from ResidentService (Prompt 10) through SetResidents. Until
	  then nobody works or eats unless DevTools staffs rooms (`staff`) or seats eaters (`eaters`).
	* Replication: amounts are RunState values (one per resource, plus Research); every room
	  that makes something is in the Production collection: id -> { Rate (per cycle), Makes
	  (a resource id or an Output kind), Idle ("NoCrew", "Dark", "Wrecked" or nil), Workers }.

	API:
		EconomyService:Get(id), :Stock(), :Cap(id), :CanAfford(costs), :Spend(costs, reason)
		EconomyService:Add(id, amount, reason): number    -- what was added (the cap stops it)
		EconomyService:Research(), :AddResearch(amount)
		EconomyService:SetResidents(source)             -- ResidentService: { Crew = fn(roomId), Eaters = fn() }
		EconomyService:RefreshCrew()                    -- ResidentService: a crew changed
		EconomyService:Crew(roomId): Crew?
		EconomyService:SetPowered(dark)                 -- PowerService: the dark rooms
		EconomyService:Rate(roomId): (number, string?, string?)  -- per cycle, what, why idle
		EconomyService:SetModifier(source, key, value?, room?)   -- bunker-wide; nil clears
		EconomyService:Multiplier(key, roomType?), :OutputMultiplier(roomType)
		EconomyService.Changed: Signal<string>            -- a resource id, or "Research"
		EconomyService.CrewChanged: Signal<()>            -- crews or output modifiers changed
		EconomyService.Ate: Signal<number, taken, missing>       -- cycle, what was taken, what was short
		EconomyService.Shortfall: Signal<{ [string]: number }>      -- what was missing
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Construction = require(Shared.Rules.Construction)
local Economy = require(Shared.Rules.Economy)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("EconomyService")
local set = RunState.Writer("EconomyService")

export type Crew = Economy.Crew
export type Eater = { Id: string, FoodUse: number? }
export type Residents = {
	Crew: (roomId: string) -> Crew?,
	Eaters: () -> { Eater },
}

type RoomRate = { Rate: number, Makes: string?, Resource: string?, Idle: string?, Workers: number }

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "BunkerGrid", "CycleClock", "SessionService", "ReplicationService", "DevService" },
	Changed = Signal.new() :: Signal.Signal<string>,
	CrewChanged = Signal.new() :: Signal.Signal<()>,
	Ate = Signal.new() :: Signal.Signal<number, { [string]: number }, { [string]: number }>,
	Shortfall = Signal.new() :: Signal.Signal<{ [string]: number }>,
}

-- Bunker-wide modifier keys this service applies (Config.Modifiers, Prompt 9).
local MODIFIER_KEYS = { "RoomOutput", "AllOutput", "StockpileCaps", "FoodUse" }
local TICK_SECONDS = 0.5 -- production
local REFRESH_SECONDS = 2 -- rates again, in case

local grid: any = nil
local clock: any = nil
local session: any = nil
local productionCollection: any = nil
local stock: { [string]: number } = {}
local research = 0
local residents: Residents? = nil
local devCrew: { [string]: Crew } = {} -- DevTools: room id -> a pretend crew (Studio)
local devEaters = 0 -- DevTools: pretend residents who eat and drink
local dark: { [string]: boolean } = {} -- PowerService: dark room ids
local progress: { [string]: number } = {} -- room id -> fraction of its next unit
local carry: { [string]: number } = { Food = 0, Water = 0 }
local modifiers: { [string]: { Key: string, Value: number, Room: string? } } = {}
local rates: { [string]: RoomRate } = {}

local function stocked(): { string }
	local ids = {}
	for _, id in Config.Ids("Resources") do
		if Config.Get("Resources", id).Kind == "Stock" then
			table.insert(ids, id)
		end
	end
	return ids
end

local function publish(id: string)
	set(id, stock[id])
	EconomyService.Changed:Fire(id)
end

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function roomName(roomType: string): string
	return Config.Get("Rooms", roomType).Name
end

-- The stockpile ------------------------------------------------------------------------------

function EconomyService:Get(id: string): number
	return stock[id] or 0
end

function EconomyService:Stock(): { [string]: number }
	return table.clone(stock)
end

function EconomyService:Cap(id: string): number
	local resource = Config.Get("Resources", id)
	local cells = 0
	for _, room in grid:RoomsOfType("Storage") do
		cells += room.Span
	end
	return math.floor((resource.Cap + resource.CapPerStorageCell * cells) * EconomyService:Multiplier("StockpileCaps"))
end

function EconomyService:CanAfford(costs: { [string]: number }): (boolean, string?, number?)
	return Construction.CanAfford(costs, stock)
end

function EconomyService:Spend(costs: { [string]: number }, reason: string): (boolean, string?)
	local ok, short, missing = Construction.CanAfford(costs, stock)
	if not ok and short then
		return false, `the stockpile is {missing} {Config.Get("Resources", short).Name} short`
	end
	for id, amount in costs do
		if amount > 0 and stock[id] ~= nil then
			stock[id] -= amount
			publish(id)
		end
	end
	if next(costs) then
		log:Info("spent %s on %s", Construction.CostText(costs), reason)
	end
	return true, nil
end

function EconomyService:Add(id: string, amount: number, reason: string): number
	assert(stock[id] ~= nil, `EconomyService: {id} isn't a stocked resource`)
	assert(amount >= 0 and amount == amount, "EconomyService: Add takes a positive amount (Spend takes away)")
	local room = math.max(0, EconomyService:Cap(id) - stock[id])
	local added = math.min(math.floor(amount), room)
	if added > 0 then
		stock[id] += added
		publish(id)
		log:Debug("+%d %s (%s)", added, id, reason)
	end
	return added
end

function EconomyService:Research(): number
	return research
end

function EconomyService:AddResearch(amount: number)
	assert(amount >= 0 and amount == amount, "EconomyService: AddResearch takes a positive amount")
	research += amount
	set("Research", research)
	EconomyService.Changed:Fire("Research")
end

-- Modifiers ------------------------------------------------------------------------------------

-- The product of bunker-wide modifiers with `key`; RoomOutput only where its Room matches.
function EconomyService:Multiplier(key: string, roomType: string?): number
	local value = 1
	for _, modifier in modifiers do
		if modifier.Key == key and (modifier.Room == nil or modifier.Room == roomType) then
			value *= modifier.Value
		end
	end
	return value
end

-- Everything bunker-wide on a room type's output (power included): RoomOutput and AllOutput.
function EconomyService:OutputMultiplier(roomType: string): number
	return EconomyService:Multiplier("RoomOutput", roomType) * EconomyService:Multiplier("AllOutput")
end

local recompute: () -> () -- below

-- A bunker-wide modifier from `source` (a draft card, a class, a Legend); a nil value clears it.
function EconomyService:SetModifier(source: string, key: string, value: number?, room: string?)
	assert(table.find(MODIFIER_KEYS, key), `EconomyService: {key} isn't a modifier it applies`)
	modifiers[`{source}|{key}|{room or "*"}`] = if value then { Key = key, Value = value, Room = room } else nil
	recompute()
	EconomyService.CrewChanged:Fire() -- power rooms' output may have changed (Overclock)
end

-- Crews and production -------------------------------------------------------------------------

function EconomyService:SetResidents(source: Residents?)
	residents = source
	EconomyService:RefreshCrew()
end

function EconomyService:RefreshCrew()
	recompute()
	EconomyService.CrewChanged:Fire()
end

function EconomyService:Crew(roomId: string): Crew?
	local pretend = devCrew[roomId]
	if pretend then
		return pretend
	end
	local source = residents
	if source then
		local ok, crew = pcall(source.Crew, roomId)
		if ok then
			return crew
		end
		log:Warn("Crew(%s) failed: %s", roomId, tostring(crew))
	end
	return nil
end

function EconomyService:Eaters(): { Eater }
	local list: { Eater } = {}
	local source = residents
	if source then
		local ok, got = pcall(source.Eaters)
		if ok and type(got) == "table" then
			list = table.clone(got)
		elseif not ok then
			log:Warn("Eaters() failed: %s", tostring(got))
		end
	end
	for i = 1, devEaters do
		table.insert(list, { Id = `dev{i}` })
	end
	return list
end

function EconomyService:SetPowered(darkRooms: { [string]: boolean })
	dark = table.clone(darkRooms)
	recompute()
end

local function resourceMultiplier(): number
	local difficulty = Config.Find("Difficulties", RunState.Get("Difficulty") or "Normal")
	return if difficulty then difficulty.ResourceMultiplier else 1
end

local function rateOf(room: any): RoomRate?
	local kind, resource = Economy.Makes(room.Type, room.Floor)
	if not kind then
		return nil
	end
	local crew = EconomyService:Crew(room.Id)
	local workers = if crew then crew.Workers else 0
	local idle: string? = nil
	if room.Wrecked then
		idle = "Wrecked"
	elseif dark[room.Id] then
		idle = "Dark"
	elseif workers <= 0 or Economy.CrewFactor(crew) <= 0 then
		idle = "NoCrew"
	end
	local multiplier = EconomyService:OutputMultiplier(room.Type)
	if kind == "Resource" then
		multiplier *= resourceMultiplier()
	end
	local rate = if idle then 0 else Economy.Output(room.Type, room.Level, room.Span, crew, true, multiplier)
	return { Rate = rate, Makes = resource or kind, Resource = resource, Idle = idle, Workers = workers }
end

local function rounded(rate: number): number
	return math.floor(rate * 10 + 0.5) / 10
end

recompute = function()
	if not grid then
		return
	end
	local seen: { [string]: boolean } = {}
	for _, room in grid:Rooms() do
		local r = rateOf(room)
		if r then
			seen[room.Id] = true
			local old = rates[room.Id]
			rates[room.Id] = r
			if not old or rounded(old.Rate) ~= rounded(r.Rate) or old.Idle ~= r.Idle or old.Makes ~= r.Makes
				or old.Workers ~= r.Workers then
				productionCollection:Set(room.Id, { Rate = rounded(r.Rate), Makes = r.Makes, Idle = r.Idle, Workers = r.Workers })
			end
		end
	end
	for id in table.clone(rates) do
		if not seen[id] then
			rates[id] = nil
			progress[id] = nil
			productionCollection:Remove(id)
		end
	end
end

-- Output per cycle, what it makes, and why it is idle ("NoCrew", "Dark", "Wrecked").
function EconomyService:Rate(roomId: string): (number, string?, string?)
	local r = rates[roomId]
	if not r then
		return 0, nil, nil
	end
	return r.Rate, r.Makes, r.Idle
end

local function produce(seconds: number)
	local cycle = Economy.CycleSeconds()
	for id, r in rates do
		local research_ = r.Makes == "Research"
		if r.Rate > 0 and (r.Resource ~= nil or research_) then
			local whole, rest = Economy.Accrue(progress[id] or 0, r.Rate, seconds, cycle)
			progress[id] = rest
			if whole > 0 then
				if research_ then
					EconomyService:AddResearch(whole)
				elseif r.Resource and stock[r.Resource] ~= nil then
					EconomyService:Add(r.Resource, whole, id)
				end
			end
		end
	end
end

-- Food and water at the start of a cycle --------------------------------------------------------

local function eat(cycle: number)
	local eaters = EconomyService:Eaters()
	if #eaters == 0 then
		return
	end
	local t = Config.Get("Tuning", "Residents")
	local bunkerUse = EconomyService:Multiplier("FoodUse")
	local uses: { [string]: { number } } = { Food = {}, Water = {} }
	for _, eater in eaters do
		table.insert(uses.Food, (eater.FoodUse or 1) * bunkerUse)
		table.insert(uses.Water, 1)
	end
	local taken: { [string]: number } = {}
	local missing: { [string]: number } = {}
	for _, id in { "Food", "Water" } do
		local need, rest = Economy.Eat(uses[id], if id == "Food" then t.FoodPerCycle else t.WaterPerCycle, carry[id])
		carry[id] = rest
		local take = math.min(need, stock[id] or 0)
		if take > 0 then
			stock[id] -= take
			publish(id)
		end
		taken[id] = take
		if need > take then
			missing[id] = need - take
		end
	end
	log:Info("cycle %d: %d residents ate %d Food and drank %d Water", cycle, #eaters, taken.Food, taken.Water)
	EconomyService.Ate:Fire(cycle, taken, missing)
	if next(missing) then
		local parts = {}
		for _, id in { "Food", "Water" } do
			if missing[id] then
				table.insert(parts, `{missing[id]} {string.upper(id)}`)
			end
		end
		log:Warn("cycle %d: the stockpile ran short by %s", cycle, table.concat(parts, " and "))
		announce("Danger", `THE STOCKPILE RAN SHORT: {table.concat(parts, " AND ")} MISSING`)
		EconomyService.Shortfall:Fire(missing)
	end
end

-- DevTools --------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	for _, id in stocked() do
		table.insert(lines, `{id} {stock[id]}/{EconomyService:Cap(id)}`)
	end
	return "stockpile: " .. table.concat(lines, ", ") .. `; research {research}`
end

local function describeProduction(): string
	local lines = {}
	local totals: { [string]: number } = {}
	for _, room in grid:Rooms() do
		local r = rates[room.Id]
		if r then
			table.insert(lines, string.format("%s %s L%d: %.1f %s a cycle (%d working%s)", room.Id, room.Type, room.Level,
				r.Rate, r.Makes or "?", r.Workers, if r.Idle then `, idle: {r.Idle}` else ""))
			if r.Makes then
				totals[r.Makes] = (totals[r.Makes] or 0) + r.Rate
			end
		end
	end
	table.sort(lines)
	local sums = {}
	for what, amount in totals do
		table.insert(sums, string.format("%s %.1f", what, amount))
	end
	table.sort(sums)
	return `production a cycle: {if #sums > 0 then table.concat(sums, ", ") else "nothing"}\n`
		.. table.concat(lines, "\n") .. `\neaters {#EconomyService:Eaters()}; carry Food {string.format("%.2f", carry.Food)}`
end

local function resourceId(text: any): string?
	if type(text) ~= "string" then
		return nil
	end
	for _, id in stocked() do
		if string.lower(id) == string.lower(text) then
			return id
		end
	end
	return nil
end

-- "R3" or a room type (every room of it).
local function roomsNamed(text: string): { any }
	local room = grid:Room(text)
	if room then
		return { room }
	end
	for _, id in Config.Ids("Rooms") do
		if string.lower(id) == string.lower(text) then
			return grid:RoomsOfType(id)
		end
	end
	return {}
end

function EconomyService:Init(registry)
	grid = registry.BunkerGrid
	clock = registry.CycleClock
	session = registry.SessionService
	productionCollection = registry.ReplicationService:Collection("Production")
	local dev = registry.DevService
	dev:Register("stock", {
		Description = "The team's stockpile and its caps.",
		Usage = "stock",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("stock.set", {
		Description = "Set a resource's amount (ignores the cap).",
		Usage = "stock.set <resource> <amount>",
		Run = function(_player: Player, args): string?
			local id, amount = resourceId(args[1]), tonumber(args[2])
			if not id or not amount or amount < 0 then
				return "usage: stock.set <resource> <amount>"
			end
			stock[id] = math.floor(amount)
			publish(id)
			return describe()
		end,
	})
	dev:Register("stock.add", {
		Description = "Add to a resource (up to its cap).",
		Usage = "stock.add <resource> <amount>",
		Run = function(_player: Player, args): string?
			local id, amount = resourceId(args[1]), tonumber(args[2])
			if not id or not amount or amount < 0 then
				return "usage: stock.add <resource> <amount>"
			end
			EconomyService:Add(id, amount, "DevTools")
			return describe()
		end,
	})
	dev:Register("research", {
		Description = "Lab research so far; with an amount, add that much.",
		Usage = "research [amount]",
		Run = function(_player: Player, args): string?
			local amount = tonumber(args[1])
			if amount and amount > 0 then
				EconomyService:AddResearch(amount)
			end
			return `research {research}`
		end,
	})
	dev:Register("production", {
		Description = "What every room makes a cycle, and why idle rooms are idle.",
		Usage = "production",
		Run = function(): string?
			return describeProduction()
		end,
	})
	dev:Register("staff", {
		Description = "Studio: give rooms a pretend crew until residents arrive (Prompt 10).",
		Usage = "staff <roomId|roomType> <statSum> [workers] [morale]",
		Run = function(_player: Player, args): string?
			local found = roomsNamed(tostring(args[1] or ""))
			local statSum = tonumber(args[2])
			if #found == 0 or not statSum or statSum < 0 then
				return "usage: staff <roomId|roomType> <statSum> [workers] [morale]"
			end
			for _, room in found do
				local slots = Config.Get("Tuning", "Rooms").WorkerSlotsPerCell[room.Level] * room.Span
				local workers = math.clamp(math.floor(tonumber(args[3]) or math.ceil(statSum / 5)), 0, slots)
				if statSum == 0 or workers == 0 then
					devCrew[room.Id] = nil
				else
					devCrew[room.Id] = { Workers = workers, StatSum = statSum, Morale = tonumber(args[4]) or 1 }
				end
			end
			EconomyService:RefreshCrew()
			return describeProduction()
		end,
	})
	dev:Register("staff.clear", {
		Description = "Studio: remove every pretend crew.",
		Usage = "staff.clear",
		Run = function(): string?
			table.clear(devCrew)
			EconomyService:RefreshCrew()
			return describeProduction()
		end,
	})
	dev:Register("eaters", {
		Description = "Studio: pretend residents who eat and drink each cycle until residents arrive.",
		Usage = "eaters <count>",
		Run = function(_player: Player, args): string?
			local count = tonumber(args[1])
			if not count or count < 0 then
				return `eaters {devEaters}; usage: eaters <count>`
			end
			devEaters = math.floor(count)
			return `eaters {#EconomyService:Eaters()}`
		end,
	})
	dev:Register("eat", {
		Description = "Run the start-of-cycle meal now.",
		Usage = "eat",
		Run = function(): string?
			eat(RunState.Get("Cycle") or 0)
			return describe()
		end,
	})
end

function EconomyService:Start()
	for _, id in stocked() do
		stock[id] = Config.Get("Resources", id).Start
		publish(id)
	end
	set("Research", research)
	grid.RoomChanged:Connect(function(roomId: string)
		if not grid:Room(roomId) then
			devCrew[roomId] = nil
		end
		recompute()
	end)
	clock.CycleStarted:Connect(eat)
	RunState.Changed("Difficulty"):Connect(recompute)
	recompute()
	local acc, since = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		since += dt
		if since >= REFRESH_SECONDS then
			since = 0
			recompute()
		end
		if acc >= TICK_SECONDS then
			if clock:IsRunning() then
				produce(acc * clock:TimeScale())
			end
			acc = 0
		end
	end)
	log:Debug("stockpile ready: %s", describe())
end

return EconomyService
