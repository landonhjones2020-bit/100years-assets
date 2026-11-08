--!strict
--[[
	EconomyService: the team's shared stockpile (bible Sections 13 and 23). Run place only.

	Prompt 8 brings the stockpile itself, so construction can be paid for:
	* Every stocked resource in Config.Resources starts at its Start amount (Section 6: 300
	  Scrap, 30 Food, 30 Water, 4 Medkits, 200 Ammo; the ores start at 0).
	* Caps: each resource's Cap, plus CapPerStorageCell for every Storage cell in the bunker.
	  Adding stops at the cap. Nothing is lost when a Storage goes and a stock sits above its
	  new cap; it just can't grow.
	* Lab research so far (level 3 upgrades need it), from 0.
	* Amounts replicate as RunState values, one per resource, plus Research (Section 23: small
	  values such as resources replicate as attributes).
	Production, consumption and power come with Prompt 9 (EconomyService and PowerService).

	API:
		EconomyService:Get(id): number
		EconomyService:Stock(): { [string]: number }     -- a copy of every stocked amount
		EconomyService:Cap(id): number
		EconomyService:CanAfford(costs): (boolean, string?, number?)  -- the short resource, how much
		EconomyService:Spend(costs, reason): (boolean, string?)
		EconomyService:Add(id, amount, reason): number    -- what was added (the cap stops it)
		EconomyService:Research(): number
		EconomyService:AddResearch(amount)
		EconomyService.Changed: Signal<string>            -- a resource id, or "Research"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Construction = require(Shared.Rules.Construction)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("EconomyService")
local set = RunState.Writer("EconomyService")

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "BunkerGrid", "DevService" },
	Changed = Signal.new() :: Signal.Signal<string>,
}

local grid: any = nil
local stock: { [string]: number } = {}
local research = 0

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
	return resource.Cap + resource.CapPerStorageCell * cells
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
	log:Info("spent %s on %s", Construction.CostText(costs), reason)
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

-- DevTools ----------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	for _, id in stocked() do
		table.insert(lines, `{id} {stock[id]}/{EconomyService:Cap(id)}`)
	end
	return "stockpile: " .. table.concat(lines, ", ") .. `; research {research}`
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

function EconomyService:Init(registry)
	grid = registry.BunkerGrid
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
end

function EconomyService:Start()
	for _, id in stocked() do
		stock[id] = Config.Get("Resources", id).Start
		publish(id)
	end
	set("Research", research)
	log:Debug("stockpile ready: %s", describe())
end

return EconomyService
