--!strict
--[[
	DataTests: tests for the shared modules and, from Prompt 1, the content data
	(bible Section 23: DevTools ... and data tests).

	Run with `/dev test [filter]` in a game, Invoke:Invoke("test") in a Studio playtest, or
	require it from the command bar (DataTests.Format(DataTests.Run())). In Studio they also
	run once when the server starts.

	Add tests with test("Area: what it proves", function() ... end), using expect,
	expectEqual and expectError. A test may yield (2 s limit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Check = require(Shared.Utilities.Check)
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Delta = require(Shared.Utilities.Delta)
local Loader = require(Shared.Utilities.Loader)
local Log = require(Shared.Utilities.Log)
local RateLimit = require(Shared.Utilities.RateLimit)
local Remotes = require(Shared.Remotes)
local Bunker = require(Shared.Rules.Bunker)
local CameraRig = require(Shared.Rules.CameraRig)
local Hud = require(Shared.Rules.Hud)
local CommandView = require(Shared.Rules.CommandView)
local Combat = require(Shared.Rules.Combat)
local Threat = require(Shared.Rules.Threat)
local Disasters = require(Shared.Rules.Disasters)
local Modifiers = require(Shared.Rules.Modifiers)
local Dig = require(Shared.Rules.Dig)
local Loot = require(Shared.Rules.Loot)
local Construction = require(Shared.Rules.Construction)
local Economy = require(Shared.Rules.Economy)
local Residents = require(Shared.Rules.Residents)
local Votes = require(Shared.Rules.Votes)
local Boss = require(Shared.Rules.Boss)
local Results = require(Shared.Rules.Results)
local UIContract = require(Shared.UIContract)
local Clock = require(Shared.Rules.Clock)
local Grid = require(Shared.Rules.Grid)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local TableUtil = require(Shared.Utilities.TableUtil)
local Trove = require(Shared.Utilities.Trove)
local ProfileSchema = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("ProfileSchema")) :: any

export type Failure = { Name: string, Error: string }
export type Report = { Passed: number, Failed: { Failure }, Skipped: number, Ms: number }

type Test = { Name: string, Run: () -> () }

local TIMEOUT_SECONDS = 2
local tests: { Test } = {}

local function test(name: string, run: () -> ())
	table.insert(tests, { Name = name, Run = run })
end

local function show(value: any, depth: number?): string
	local level = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" then
		return tostring(value)
	elseif level > 3 then
		return "{...}"
	end
	local parts = {}
	for _, key in TableUtil.SortedKeys(value) do
		table.insert(parts, `{tostring(key)}={show(value[key], level + 1)}`)
	end
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function expect(condition: any, label: string)
	if not condition then
		error(`expected {label}`, 2)
	end
end

local function expectEqual(actual: any, expected: any, label: string?)
	if not TableUtil.DeepEqual(actual, expected) then
		error(`{label or "value"}: expected {show(expected)}, got {show(actual)}`, 2)
	end
end

local function expectError(run: () -> (), pattern: string?)
	local ok, err = pcall(run)
	if ok then
		error("expected an error", 2)
	end
	if pattern and not string.find(tostring(err), pattern) then
		error(`error {show(tostring(err))} doesn't match {pattern}`, 2)
	end
end

local function rejects(check: Check.Checker, value: any, pattern: string?)
	local ok, why = check(value)
	if ok then
		error(`checker accepted {show(value)}`, 2)
	end
	if pattern and not string.find(why or "", pattern) then
		error(`reason {show(why)} doesn't match {pattern}`, 2)
	end
end

local function accepts(check: Check.Checker, value: any)
	local ok, why = check(value)
	if not ok then
		error(`checker rejected {show(value)}: {why}`, 2)
	end
end

local silent: Log.Logger = {
	Tag = "test",
	Debug = function() end,
	Info = function() end,
	Warn = function() end,
	Error = function() end,
} :: any

-- Signal ---------------------------------------------------------------------------------

test("Signal: handlers get the fired arguments", function()
	local signal = Signal.new()
	local got = nil
	signal:Connect(function(a, b)
		got = { a, b }
	end)
	signal:Fire(1, "two")
	expectEqual(got, { 1, "two" })
end)

test("Signal: Disconnect stops delivery and Once fires once", function()
	local signal = Signal.new()
	local count, onceCount = 0, 0
	local connection = signal:Connect(function()
		count += 1
	end)
	signal:Once(function()
		onceCount += 1
	end)
	signal:Fire()
	connection:Disconnect()
	signal:Fire()
	expectEqual(count, 1, "count")
	expectEqual(onceCount, 1, "once count")
	expect(not connection.Connected, "Connected = false")
end)

test("Signal: a handler disconnecting itself mid-fire doesn't skip the others", function()
	local signal = Signal.new()
	local ran = {}
	signal:Connect(function()
		table.insert(ran, "a")
	end)
	local middle
	middle = signal:Connect(function()
		table.insert(ran, "b")
		middle:Disconnect()
	end)
	signal:Connect(function()
		table.insert(ran, "c")
	end)
	signal:Fire()
	expectEqual(#ran, 3, "handlers run on the first fire")
	signal:Fire()
	expectEqual(#ran, 5, "handlers run after the second fire")
end)

test("Signal: a yielding handler doesn't hold up the others", function()
	local signal = Signal.new()
	local reached = false
	signal:Connect(function()
		task.wait(0.05)
	end)
	signal:Connect(function()
		reached = true
	end)
	signal:Fire()
	expect(reached, "the second handler to run before Fire returns")
end)

test("Signal: Wait returns the fired values", function()
	local signal = Signal.new()
	task.defer(function()
		signal:Fire(42, "x")
	end)
	local a, b = signal:Wait()
	expectEqual({ a, b }, { 42, "x" })
end)

-- Trove ----------------------------------------------------------------------------------

test("Trove: cleans newest first, and disconnects signals", function()
	local trove = Trove.new()
	local order = {}
	for index = 1, 3 do
		trove:Add(function()
			table.insert(order, index)
		end)
	end
	local signal = Signal.new()
	local heard = 0
	trove:Connect(signal, function()
		heard += 1
	end)
	local folder = trove:Add(Instance.new("Folder"))
	trove:Clean()
	signal:Fire()
	expectEqual(order, { 3, 2, 1 }, "cleanup order")
	expectEqual(heard, 0, "handler calls after Clean")
	expect(not pcall(function()
		folder.Parent = workspace
	end), "the folder to be destroyed")
end)

test("Trove: refuses things it can't clean", function()
	expectError(function()
		Trove.new():Add(5 :: any)
	end, "can't clean")
end)

-- TableUtil ------------------------------------------------------------------------------

test("TableUtil: DeepCopy shares nothing; DeepFreeze freezes every level", function()
	local original = { a = { b = { 1, 2 } } }
	local copy = TableUtil.DeepCopy(original)
	copy.a.b[1] = 99
	expectEqual(original.a.b[1], 1, "original")
	TableUtil.DeepFreeze(original)
	expect(table.isfrozen(original) and table.isfrozen(original.a) and table.isfrozen(original.a.b), "all frozen")
end)

test("TableUtil: DeepEqual compares structure, extra keys and NaN", function()
	expect(TableUtil.DeepEqual({ x = { 1, 2 } }, { x = { 1, 2 } }), "equal tables")
	expect(not TableUtil.DeepEqual({ x = 1 }, { x = 1, y = 2 }), "an extra key to differ")
	expect(not TableUtil.DeepEqual({ 1, 2 }, { 2, 1 }), "order to matter")
	expect(TableUtil.DeepEqual(0 / 0, 0 / 0), "NaN to equal NaN")
end)

test("TableUtil: SortedKeys puts numbers first, then strings", function()
	expectEqual(TableUtil.SortedKeys({ b = 1, a = 1, [2] = 1, [1] = 1 }), { 1, 2, "a", "b" })
end)

-- Check ----------------------------------------------------------------------------------

test("Check: numbers must be finite and in range", function()
	local check = Check.number({ min = 0, max = 10, integer = true })
	accepts(check, 5)
	rejects(check, 0 / 0, "number")
	rejects(check, math.huge, "number")
	rejects(check, -1, "minimum")
	rejects(check, 11, "maximum")
	rejects(check, 2.5, "integer")
	rejects(check, "5", "number")
end)

test("Check: strings have a length limit, valid UTF-8 and a pattern", function()
	local check = Check.string(5, { pattern = "^%a+$", min = 1 })
	accepts(check, "abc")
	rejects(check, "abcdef", "longer")
	rejects(check, "", "shorter")
	rejects(check, "ab1", "match")
	rejects(Check.string(10), "\255\254", "UTF%-8")
end)

test("Check: lists have no holes, no named keys and a maximum length", function()
	local check = Check.array(Check.number(), 3)
	accepts(check, { 1, 2, 3 })
	rejects(check, { 1, 2, 3, 4 }, "longer")
	rejects(check, { 1, nil :: any, 3 }, "holes")
	rejects(check, { 1, x = 2 }, "index")
	rejects(check, { 1, "2" }, "%[2%]")
end)

test("Check: shapes name the field that failed and reject unknown fields", function()
	local check = Check.shape({ Name = Check.string(10), Cost = Check.optional(Check.integer(0)) })
	accepts(check, { Name = "Crate" })
	accepts(check, { Name = "Crate", Cost = 3 })
	rejects(check, { Cost = 3 }, "^Name:")
	rejects(check, { Name = "Crate", Cost = -1 }, "^Cost:")
	rejects(check, { Name = "Crate", Extra = true }, "unknown field")
	accepts(Check.shape({ Name = Check.string(10) }, { open = true }), { Name = "Crate", Extra = true })
end)

test("Check: literals, unions, vectors and primitives", function()
	local kind = Check.enum({ "Gun", "Melee" })
	accepts(kind, "Gun")
	rejects(kind, "Laser", "one of")
	local either = Check.union(Check.number(), Check.boolean())
	accepts(either, true)
	rejects(either, "x")
	local vector = Check.vector3(10)
	accepts(vector, Vector3.new(1, 2, 3))
	rejects(vector, Vector3.new(0 / 0, 0, 0), "finite")
	rejects(vector, Vector3.new(100, 0, 0), "longer")
	local primitive = Check.primitive(8)
	accepts(primitive, "word")
	accepts(primitive, 3)
	rejects(primitive, 0 / 0, "finite")
	rejects(primitive, {}, "expected")
end)

-- RateLimit ------------------------------------------------------------------------------

test("RateLimit: a burst, then refills over time, per key", function()
	local now = 0
	local limiter = RateLimit.new(3, 1, function()
		return now
	end)
	expect(limiter:Take("a") and limiter:Take("a") and limiter:Take("a"), "a burst of 3")
	expect(not limiter:Take("a"), "the 4th call to be refused")
	expect(limiter:Take("b"), "another key to have its own bucket")
	now = 1.5
	expect(limiter:Take("a"), "a token back after a second")
	expect(not limiter:Take("a"), "only one token back")
	limiter:Forget("a")
	expect(limiter:Take("a"), "a fresh bucket after Forget")
end)

-- Loader ---------------------------------------------------------------------------------

test("Loader: dependencies come first, ties alphabetical", function()
	local order = Loader.Order({
		Gamma = { Name = "Gamma", Dependencies = { "Alpha" } },
		Beta = { Name = "Beta" },
		Alpha = { Name = "Alpha" },
	})
	expectEqual(order, { "Alpha", "Beta", "Gamma" })
	order = Loader.Order({
		Alpha = { Name = "Alpha", Dependencies = { "Gamma" } },
		Beta = { Name = "Beta" },
		Gamma = { Name = "Gamma" },
	})
	expectEqual(order, { "Beta", "Gamma", "Alpha" })
end)

test("Loader: names missing dependencies and cycles", function()
	local order, problem = Loader.Order({ A = { Name = "A", Dependencies = { "Nope" } } })
	expect(order == nil and string.find(problem or "", "Nope"), "a missing-dependency error")
	order, problem = Loader.Order({
		A = { Name = "A", Dependencies = { "B" } },
		B = { Name = "B", Dependencies = { "C" } },
		C = { Name = "C", Dependencies = { "A" } },
		D = { Name = "D" },
	})
	expect(order == nil and string.find(problem or "", "cycle"), "a cycle error")
	expect(string.find(problem or "", "A") and string.find(problem or "", "C"), "the cycle named")
end)

test("Loader: Init in order, registry limited to declared dependencies, failures skip dependents", function()
	local calls = {}
	local modules = {
		Base = {
			Name = "Base",
			Init = function()
				table.insert(calls, "Base.Init")
			end,
		},
		User = {
			Name = "User",
			Dependencies = { "Base" },
			Init = function(_self, registry)
				table.insert(calls, "User.Init")
				expect(registry.Base ~= nil, "the declared dependency")
			end,
		},
		Sneaky = {
			Name = "Sneaky",
			Init = function(_self, registry)
				local _ = registry.Base -- not declared: must fail
			end,
		},
		AfterSneaky = { Name = "AfterSneaky", Dependencies = { "Sneaky" } },
	}
	local report = Loader.Run(modules :: any, silent)
	expectEqual(calls, { "Base.Init", "User.Init" }, "Init calls")
	expect(report.Failed.Sneaky ~= nil, "Sneaky to fail")
	expect(string.find(report.Failed.Sneaky or "", "not in its Dependencies"), "the reason")
	expect(report.Skipped.AfterSneaky ~= nil, "AfterSneaky to be skipped")
end)

-- Config ---------------------------------------------------------------------------------

local function fixture(): { [string]: any }
	return {
		Weapons = {
			Schema = Check.shape({ Damage = Check.number({ min = 0 }) }),
			Entries = { Pistol = { Damage = 10 }, Rifle = { Damage = 25 } },
			Order = { "Rifle", "Pistol" },
		},
		Classes = {
			Schema = Check.shape({ Weapon = Check.ref("Weapons") }),
			Entries = { Security = { Weapon = "Pistol" } },
		},
	}
end

test("Config: builds, adds Id, freezes and keeps Order", function()
	local registry = Config.Build(fixture())
	expectEqual(registry.Errors, {}, "errors")
	local pistol = registry.Types.Weapons.Entries.Pistol
	expectEqual(pistol.Id, "Pistol", "Id")
	expect(table.isfrozen(pistol), "frozen entries")
	expectEqual(registry.Types.Weapons.Order, { "Rifle", "Pistol" }, "Order")
	expectEqual(registry.Types.Classes.Order, { "Security" }, "default order")
end)

test("Config: reports bad values, bad ids, broken refs and bad Order", function()
	local defs = fixture()
	defs.Weapons.Entries.Rifle.Damage = "lots"
	defs.Weapons.Entries["rifle-2"] = { Damage = 1 }
	defs.Classes.Entries.Medic = { Weapon = "Laser" }
	defs.Weapons.Order = { "Pistol", "Ghost" }
	local errors = table.concat(Config.Build(defs).Errors, "\n")
	expect(string.find(errors, "Weapons.Rifle: Damage:"), "the bad value")
	expect(string.find(errors, "bad id rifle%-2"), "the bad id")
	expect(string.find(errors, "Classes.Medic: Weapons.Laser doesn't exist"), "the broken ref")
	expect(string.find(errors, "Order lists Ghost"), "the bad Order")
end)

test("Config: the place's own content loads without errors", function()
	expectEqual(Config.Errors(), {}, "Config.Errors()")
end)

-- Content (Prompt 1): the data agrees with the bible and with itself ---------------------

local function all(typeName: string): { any }
	return Config.All(typeName)
end

test("Content: the starting bunker matches bible Section 6 and its diagram", function()
	local bunker = Bunker.FromStart() -- every room placed by the grid's rules, or this errors
	local function row(floor: number): { string }
		local tokens = {}
		for column = -3, 3 do
			local state = bunker:State(floor, column)
			local room = bunker:RoomAt(floor, column)
			table.insert(tokens, if room then room.Type else tostring(state))
		end
		return tokens
	end
	expectEqual(row(1), { "Rock", "BlastDoor", "BlastDoor", "Shaft", "Quarters", "Quarters", "Dug" }, "floor 1, columns -3 to 3")
	expectEqual(row(2), { "Rock", "Kitchen", "WaterPurifier", "Shaft", "ReactorCore", "Medbay", "Dug" }, "floor 2, columns -3 to 3")
	expectEqual(row(3), { "Rock", "Rock", "Rock", "Rock", "Rock", "Rock", "Rock" }, "floor 3")
	expectEqual(#bunker:AllRooms(), 8, "eight rooms (the Blast Door and the Quarters are 2 cells each)")
	expectEqual(bunker:RoomsOfType("BlastDoor")[1].Span, 2, "the Blast Door's cells")
	expectEqual(Config.Get("Tuning", "StartingBunker").Residents, 6, "starting residents")
end)

test("Content: starting stock is bible Section 6", function()
	local stock = {}
	for _, resource in all("Resources") do
		stock[resource.Id] = resource.Start
	end
	expectEqual(stock, { Power = 0, Food = 30, Water = 30, Scrap = 300, Iron = 0, Copper = 0, Crystal = 0, Medkits = 4, Ammo = 200 })
end)

test("Content: rooms have three levels and consistent output", function()
	for _, room in all("Rooms") do
		expectEqual(#room.Costs, 3, `{room.Id} cost levels`)
		expectEqual(#room.Power, 3, `{room.Id} power levels`)
		if room.Output then
			local isResource = room.Output.Kind == "Resource"
			expect(isResource == (room.Output.Resource ~= nil), `{room.Id}: only Resource output names a resource`)
		end
		if room.Unlock.Kind == "Era" then
			expect(room.Unlock.Era ~= nil, `{room.Id}: an Era unlock names the era`)
		end
	end
	local rules = Config.Get("Tuning", "Rooms")
	expectEqual(rules.HP, { 500, 800, 1200 }, "room HP")
	expectEqual(rules.WorkerSlotsPerCell, { 2, 3, 4 }, "worker slots")
end)

test("Content: every draft room has exactly one room card", function()
	local cards: { [string]: number } = {}
	for _, card in all("DraftCards") do
		if card.Kind == "Room" then
			cards[card.Room] = (cards[card.Room] or 0) + 1
		end
	end
	for _, room in all("Rooms") do
		local drafted = room.Unlock.Kind == "Draft" or room.Unlock.Kind == "DraftOrDepth"
		expectEqual(cards[room.Id] or 0, if drafted then 1 else 0, `{room.Id} room cards`)
	end
end)

test("Content: odds add up (dig results, wanderers)", function()
	local dig = 0
	for _, result in all("DigResults") do
		dig += result.Chance
	end
	expectEqual(dig, 100, "dig result weights")
	local wanderers = 0
	for _, outcome in all("WandererOutcomes") do
		wanderers += outcome.Chance
	end
	expect(math.abs(wanderers - 1) < 1e-9, "wanderer odds sum to 1")
end)

test("Content: eras cover the century and end in their boss's year", function()
	local nextYear = 1
	for _, era in all("Eras") do
		expectEqual(era.Years.From, nextYear, `{era.Id} starts where the last ended`)
		expectEqual(Config.Get("Bosses", era.Boss).Year, era.Years.To, `{era.Id} boss year`)
		nextYear = era.Years.To + 1
	end
	expectEqual(nextYear, 101, "the century ends at Year 100")
	local clock = Config.Get("Tuning", "Clock")
	expectEqual(clock.DaySeconds + clock.SurgeSeconds, clock.CycleSeconds, "a cycle is a day plus a Surge")
end)

test("Content: 18 buyable classes plus the Survivor, priced by tier", function()
	local prices = { Free = 0, Common = 40, Rare = 120, Epic = 300, Legendary = 500 }
	local buyable = 0
	for _, class in all("Classes") do
		expectEqual(class.Price, prices[class.Tier], `{class.Id} price`)
		if class.Tier ~= "Free" then
			buyable += 1
		end
	end
	expectEqual(buyable, 18, "buyable classes")
end)

test("Content: 30 traits (18 good, 12 bad), 12 Legends with one starter", function()
	local good, bad = 0, 0
	for _, trait in all("Traits") do
		if trait.Type == "Good" then
			good += 1
		else
			bad += 1
		end
	end
	expectEqual({ good, bad }, { 18, 12 }, "good and bad traits")
	local starters = 0
	for _, legend in all("Legends") do
		if legend.Get.Kind == "Starter" then
			starters += 1
		end
	end
	expectEqual(#all("Legends"), 12, "Legends")
	expectEqual(starters, 1, "starter Legends")
end)

test("Content: RoomOutput modifiers always name their room", function()
	local function checkList(where: string, modifiers: { any }?)
		for _, modifier in modifiers or {} do
			if modifier.Key == "RoomOutput" then
				expect(modifier.Room ~= nil, `{where}: RoomOutput names a room`)
			end
		end
	end
	for _, class in all("Classes") do
		for _, part in { class.Passive, class.Level2, class.Level3, class.Ability } do
			checkList(`Classes.{class.Id}`, part and part.Modifiers)
		end
	end
	for _, trait in all("Traits") do
		checkList(`Traits.{trait.Id}`, trait.Modifiers)
	end
	for _, legend in all("Legends") do
		checkList(`Legends.{legend.Id}`, legend.Signature.Modifiers)
	end
	for _, card in all("DraftCards") do
		checkList(`DraftCards.{card.Id}`, card.Modifiers)
	end
end)

test("Content: loot lines give one thing each, and ranges are ordered", function()
	for _, tableEntry in all("LootTables") do
		for index, line in tableEntry.Lines do
			local kinds = (if line.Resource then 1 else 0) + (if line.Item then 1 else 0) + (if line.Special then 1 else 0)
			expectEqual(kinds, 1, `{tableEntry.Id}[{index}] gives one thing`)
			expect(line.Min <= line.Max, `{tableEntry.Id}[{index}] Min <= Max`)
		end
	end
	for _, monster in all("Monsters") do
		expect(monster.Group.Min <= monster.Group.Max, `{monster.Id} group size`)
	end
end)

test("Content: name pools are big and have no repeats; morale states cover 0 to 100", function()
	for _, pool in all("ResidentNames") do
		local seen = {}
		for _, name in pool.Names do
			expect(not seen[name], `{pool.Id}: {name} once`)
			seen[name] = true
		end
	end
	expect(#Config.Get("ResidentNames", "First").Names >= 100, "100+ first names")
	expect(#Config.Get("ResidentNames", "Last").Names >= 100, "100+ last names")
	local nextValue = 0
	for _, state in all("MoraleStates") do
		expectEqual(state.From, nextValue, `{state.Id} starts where the last ended`)
		nextValue = state.To + 1
	end
	expectEqual(nextValue, 101, "morale states end at 100")
end)

test("Content: Glowshard packs get better per Robux (bible Section 17)", function()
	local last = 0
	for _, pack in all("GlowshardPacks") do
		local per100 = math.floor(pack.Glowshards / pack.Robux * 100 + 0.5)
		expect(per100 > last, `{pack.Id} gives more per Robux than the pack before`)
		last = per100
	end
end)

-- Profiles (Prompt 2) ----------------------------------------------------------------------

test("Profiles: a new profile owns the free class and the starter Legend, and validates", function()
	local data, status = ProfileSchema.Load(nil)
	expectEqual(status, "New", "status")
	expect(data.Classes.Survivor ~= nil, "the Survivor owned")
	expect(data.Legends[Config.Get("Tuning", "Legends").StarterLegend] ~= nil, "the starter Legend owned")
	expectEqual(data.Glowshards, 0, "Glowshards")
	expect((ProfileSchema.Validate(data)), "the default to validate")
end)

test("Profiles: newer versions are refused, missing fields reconciled, bad values rejected", function()
	local _, status = ProfileSchema.Load({ Version = ProfileSchema.VERSION + 1 })
	expectEqual(status, "TooNew", "a newer save")
	local old = ProfileSchema.Default()
	old.Stats = { Runs = 3 }
	old.ClassShop = nil
	old.FirstRunDone = nil
	local data, loaded = ProfileSchema.Load(old)
	expectEqual(loaded, "Loaded", "a save with missing fields")
	expectEqual(data.Stats.Runs, 3, "kept values")
	expectEqual(data.Stats.Wins, 0, "a missing record field filled")
	expect(data.ClassShop ~= nil and data.FirstRunDone == false, "missing fields filled")
	local bad = ProfileSchema.Default()
	bad.Glowshards = -5
	local none, invalid, why = ProfileSchema.Load(bad)
	expect(none == nil and invalid == "Invalid", "negative Glowshards refused")
	expect(string.find(why or "", "Glowshards"), "the reason names the field")
	local wrong = ProfileSchema.Default()
	wrong.Classes.Survivor.Level = 9
	expectEqual(select(2, ProfileSchema.Load(wrong)), "Invalid", "a class level out of range")
end)

test("Profiles: migrations run in order up to the current version", function()
	local migrations = ProfileSchema._MIGRATIONS
	local version = ProfileSchema.VERSION
	ProfileSchema.VERSION = version + 1
	migrations[version] = function(data)
		data.Glowshards += 10
		return data
	end
	local ok, result = pcall(function()
		local stored = ProfileSchema.Default()
		stored.Version = version
		return table.pack(ProfileSchema.Load(stored))
	end)
	migrations[version] = nil
	ProfileSchema.VERSION = version
	expect(ok, "the load not to error")
	local data, status = result[1], result[2]
	expectEqual(status, "Loaded", "status")
	expectEqual(data.Version, version + 1, "the migrated version")
	expectEqual(data.Glowshards, 10, "the migration ran")
end)

test("Profiles: receipts keep the newest 200; the player's copy has none", function()
	local data = ProfileSchema.Default()
	for index = 1, 205 do
		ProfileSchema.AddReceipt(data, `r{index}`)
	end
	expectEqual(#data.Receipts, 200, "kept receipts")
	expectEqual(data.Receipts[1], "r6", "oldest kept")
	expect((ProfileSchema.Validate(data)), "still valid")
	expectEqual(ProfileSchema.Public(data).Receipts, nil, "receipts hidden from the client")
end)

-- Delta ----------------------------------------------------------------------------------

test("Delta: only remote-safe values", function()
	expect(Delta.IsRemoteSafe({ a = 1, b = { 1, 2 }, at = Vector3.new(1, 2, 3) }), "plain data")
	expect(not Delta.IsRemoteSafe({ 1, x = 2 }), "mixed tables refused")
	expect(not Delta.IsRemoteSafe({ [1] = 1, [3] = 3 }), "sparse lists refused")
	expect(not Delta.IsRemoteSafe({ f = print }), "functions refused")
	expect(not Delta.IsRemoteSafe({ n = 0 / 0 }), "NaN refused")
	expect(not Delta.IsRemoteSafe({ [true] = 1 } :: any), "boolean keys refused")
end)

test("Delta: Diff sends only changed fields, NONE for removed ones", function()
	expectEqual(Delta.Diff({ a = 1, b = 2 }, { a = 1, b = 3, c = 4 }), { b = 3, c = 4 })
	expectEqual(Delta.Diff({ a = 1, b = 2 }, { a = 1 }), { b = Delta.NONE })
	expectEqual(Delta.Diff({ a = { 1 } }, { a = { 1 } }), nil, "equal tables")
end)

test("Delta: Apply runs set, patch, remove and clear on a mirror", function()
	local store = {}
	local changes = Delta.Apply(store, {
		{ Delta.SET, "Rooms", "R1", { Kind = "Kitchen", Level = 1, Fire = true } },
		{ Delta.PATCH, "Rooms", "R1", { Level = 2, Fire = Delta.NONE } },
		{ Delta.SET, "Rooms", "R2", { Kind = "Dorm" } },
		{ Delta.REMOVE, "Rooms", "R2" },
	})
	expectEqual(store.Rooms, { R1 = { Kind = "Kitchen", Level = 2 } }, "store")
	expectEqual(#changes, 4, "change count")
	expectEqual(changes[2].Old, { Kind = "Kitchen", Level = 1, Fire = true }, "the patch keeps the old value")
	expect(table.isfrozen(store.Rooms.R1), "applied values frozen")
	changes = Delta.Apply(store, { { Delta.CLEAR, "Rooms" } })
	expectEqual(store.Rooms, {}, "after clear")
	expectEqual(#changes, 1, "one clear change")
end)

-- The clock (Rules.Clock, bible Section 5) ----------------------------------------------

local function objectiveIds(kind: string): { string }
	local ids = {}
	for _, objective in all("Objectives") do
		if objective.Kind == kind then
			table.insert(ids, objective.Id)
		end
	end
	return ids
end

local function bossObjective(bossId: string): string
	for _, objective in all("Objectives") do
		if objective.Kind == "Boss" and objective.Boss == bossId then
			return objective.Id
		end
	end
	error(`no objective for {bossId}`)
end

-- Plays a century with the clock rules: Lost Crews rescued in the given cycles, era bosses
-- beaten when they come or not. Returns the cycle of the final Surge and the boss Surges.
local function century(crewCycles: { number }, beatBosses: boolean): (number, { string })
	local state = Clock.NewState()
	local crews = objectiveIds("LostCrew")
	local rescued = 0
	local bosses = {}
	for _ = 1, 200 do
		for _, cycle in crewCycles do
			if cycle == state.Cycle then
				rescued += 1
				state.Completed[crews[rescued]] = true
			end
		end
		local kind, boss = Clock.StartSurge(state)
		if kind == "Final" then
			return state.Cycle, bosses
		end
		if kind == "Boss" and boss then
			table.insert(bosses, `{boss}@{state.Cycle}`)
			if beatBosses then
				state.Completed[bossObjective(boss)] = true
			end
		end
		Clock.EndCycle(state)
	end
	error("the century never ended")
end

test("Clock: Years per Cycle starts at 1, +2 a Lost Crew, +1 an era boss, 12 with everything", function()
	local crews, bosses = objectiveIds("LostCrew"), objectiveIds("Boss")
	expectEqual({ #crews, #bosses }, { 4, 3 }, "four Lost Crews and three era bosses")
	expectEqual(Clock.YearsPerCycle({}), 1, "nothing done")
	expectEqual(Clock.YearsPerCycle({ [crews[1]] = true }), 3, "one crew")
	expectEqual(Clock.YearsPerCycle({ [bosses[1]] = true }), 2, "one boss")
	local everything: { [string]: boolean } = {}
	for _, id in crews do
		everything[id] = true
	end
	for _, id in bosses do
		everything[id] = true
	end
	expectEqual(Clock.YearsPerCycle(everything), Clock.Tuning().YearsPerCycleMax, "everything done reaches the cap")
	expectEqual(Clock.Tuning().YearsPerCycleMax, 12, "the cap")
	everything.NotAnObjective = true
	expectEqual(Clock.YearsPerCycle(everything), 12, "unknown ids count for nothing")
	local eras = all("Eras")
	expectEqual(Clock.Tuning().FinalYear, eras[#eras].Years.To, "the final year ends the last era")
end)

test("Clock: reaching or passing an era's last year makes its boss the next Surge, once", function()
	local state = Clock.NewState()
	state.Year = 24
	local before, due = Clock.EndCycle(state)
	expectEqual({ before, state.Year, state.Cycle, due }, { 24, 25, 2, "BroodMother" }, "24 -> 25")
	expectEqual({ Clock.SurgeKind(state) }, { "Boss", "BroodMother" }, "the next Surge")
	expectEqual({ Clock.StartSurge(state) }, { "Boss", "BroodMother" }, "the boss Surge")
	expectEqual(state.PendingBoss, nil, "the boss Surge comes once")
	expectEqual(Clock.SurgeKind(state), "Normal", "the Surge after it")

	local jump = Clock.NewState()
	jump.Year = 23
	jump.Completed = { [objectiveIds("LostCrew")[1]] = true } -- 3 years per cycle
	local _, passed = Clock.EndCycle(jump)
	expectEqual({ jump.Year, passed }, { 26, "BroodMother" }, "23 + 3 passes 25")

	local beaten = Clock.NewState()
	beaten.Year = 49
	beaten.Completed = { [bossObjective("Deluge")] = true } -- 2 years per cycle
	local _, none = Clock.EndCycle(beaten)
	expectEqual({ beaten.Year, none, beaten.PendingBoss }, { 51, nil, nil }, "a beaten boss doesn't come again")
end)

test("Clock: the year stops at 100 and the next Surge is the final one; Endless goes on", function()
	local state = Clock.NewState()
	state.Year = 99
	state.Completed = { [objectiveIds("LostCrew")[1]] = true } -- 3 years per cycle
	local _, due = Clock.EndCycle(state)
	expectEqual({ state.Year, due }, { 100, nil }, "capped at the final year, no era boss for it")
	expectEqual({ Clock.SurgeKind(state) }, { "Final", "Source" }, "the final Surge")
	state.Endless = true
	expectEqual(Clock.SurgeKind(state), "Endless", "Endless Surges")
	Clock.EndCycle(state)
	expectEqual(state.Year, 103, "Endless goes past 100")
end)

test("Clock: eras by year; the first Surge is the tutorial wave", function()
	expectEqual(
		{ Clock.EraOf(1), Clock.EraOf(25), Clock.EraOf(26), Clock.EraOf(100), Clock.EraOf(140) },
		{ "SettlingIn", "SettlingIn", "Expansion", "Reckoning", "Reckoning" },
		"eras"
	)
	local state = Clock.NewState()
	expectEqual(Clock.SurgeKind(state), "Tutorial", "cycle 1")
	Clock.EndCycle(state)
	expectEqual(Clock.SurgeKind(state), "Normal", "cycle 2")
end)

test("Clock: completing nothing takes 100 cycles; crews and bosses make it 13 to 20 (bible Section 5)", function()
	local cycles, bosses = century({}, false)
	expectEqual(cycles, 100, "cycles with nothing done")
	expectEqual(bosses, { "BroodMother@25", "Deluge@50", "CrystalColossus@75" }, "boss Surges")
	for _, schedule in { { 2, 4, 6, 8 }, { 3, 6, 9, 12 }, { 4, 8, 12, 16 } } do
		local fast = century(schedule, true)
		expect(fast >= 13 and fast <= 20, `13 to 20 cycles with crews rescued in cycles {table.concat(schedule, ", ")} (got {fast})`)
	end
end)

test("RunState: every value has one owner, a type and its allowed values", function()
	local owners = { RunDirector = true, CycleClock = true, ObjectiveService = true, EconomyService = true, PowerService = true,
		ThreatDirector = true, DisasterService = true, DigService = true }
	for name, field in RunState.Fields do
		expect(owners[field.By], `{name} to have a known owner`)
	end
	expect(RunState.Check("Year", 12), "a number year")
	expect(not RunState.Check("Year", "12"), "a string year rejected")
	expect(not RunState.Check("Year", 0 / 0), "NaN rejected")
	expect(not RunState.Check("RunPhase", "Paused"), "an unknown phase rejected")
	expect(RunState.Check("SurgeBoss", nil), "nil clears a value")
	expect(not RunState.Check("Nope", 1), "unknown names rejected")
	expectError(function()
		RunState.Writer("ObjectiveService")("Year", 5)
	end, "belongs to CycleClock")
end)

-- The bunker grid (Rules.Grid, Rules.Bunker; bible Section 6) ---------------------------

test("Grid: cells sit 34 studs apart and 18 down; world positions map back to their cell", function()
	local pitch = Grid.Pitch()
	expectEqual({ pitch.X, pitch.Y, pitch.Z }, { 34, 18, 34 }, "pitch")
	local origin = Grid.Tuning().Origin
	expectEqual(Grid.CellPosition(1, 0), Vector3.new(origin.X, origin.Y, origin.Z), "floor 1, column 0 is the origin")
	for _, cell in { { 1, 0 }, { 2, -6 }, { 10, 6 }, { 5, 3 } } do
		local position = Grid.CellPosition(cell[1], cell[2])
		for _, offset in { Vector3.new(0, 1, 0), Vector3.new(15, 15.5, 15), Vector3.new(-15, -1.5, -15) } do
			expectEqual({ Grid.CellAt(position + offset) }, cell, `cell {cell[1]},{cell[2]} plus {offset}`)
		end
	end
	expectEqual({ Grid.CellAt(Grid.CellPosition(1, 6) + Vector3.new(40, 0, 0)) }, {}, "past the right edge")
	expectEqual({ Grid.Parse(Grid.Key(7, -4)) }, { 7, -4 }, "keys")
	expect(Grid.Buildable(9) and not Grid.Buildable(10), "nothing built on floor 10")
	expect(Grid.IsBandStart(4) and Grid.IsBandStart(7) and Grid.IsBandStart(10), "Push Deeper at floors 4, 7 and 10")
	expect(not Grid.IsBandStart(1) and not Grid.IsBandStart(3), "not at floors 1 and 3")
end)

test("Bunker: the starting bunker is one connected place; the shafts join floors 1 and 2", function()
	local bunker = Bunker.FromStart()
	local blast = bunker:RoomsOfType("BlastDoor")[1]
	local reach = bunker:Reachable(blast.Id)
	for _, unit in bunker:Units() do
		expect(reach[unit], `{unit} reachable from the Blast Door`)
	end
	local upper, lower = bunker:RoomAt(1, 0), bunker:RoomAt(2, 0)
	expect(upper and lower and upper.Type == "Shaft" and lower.Type == "Shaft", "shafts in column 0")
	expect(table.find(bunker:Neighbors((upper :: Bunker.Room).Id), (lower :: Bunker.Room).Id), "the shafts connect")
	local core = bunker:RoomsOfType("ReactorCore")[1]
	local medbay = bunker:RoomsOfType("Medbay")[1]
	local expected = { (lower :: Bunker.Room).Id, medbay.Id }
	table.sort(expected)
	expectEqual(bunker:Neighbors(core.Id), expected, "the Reactor Core's doorways")
	expectEqual(bunker:DeepestFloor(), 2, "deepest floor")
end)

test("Bunker: digging goes left, right or down from an open cell, never up or off the grid", function()
	local bunker = Bunker.FromStart()
	expect(bunker:CanDig(1, 4), "right of the dug cell on floor 1")
	expect(bunker:CanDig(1, -3), "left of the Blast Door")
	expect(bunker:CanDig(3, 0), "below the shaft")
	expect(not bunker:CanDig(3, 5), "floor 3 away from any open cell")
	expect(not bunker:CanDig(1, 0), "an open cell")
	expect(not bunker:CanDig(0, 0), "above floor 1")
	expect(not bunker:CanDig(1, 7), "past column 6")
	expect(bunker:Dig(3, 0), "dig below the shaft")
	expect(bunker:CanDig(4, 0), "and on down")
	expect(bunker:CanDig(3, 1) and bunker:CanDig(3, -1), "and sideways from the new cell")
	expectEqual(bunker:DeepestFloor(), 3, "deepest floor after digging")
end)

test("Bunker: rooms go on dug cells, within MaxCells, one of a unique room, never in the Source Chamber", function()
	local bunker = Bunker.FromStart()
	expect(not bunker:CanPlace("Kitchen", 3, 0, 1), "on rock")
	expect(not bunker:CanPlace("Kitchen", 1, 0, 1), "on a room")
	expect(not bunker:CanPlace("ReactorCore", 1, 3, 1), "a second Reactor Core")
	expect(not bunker:CanPlace("BlastDoor", 2, 3, 1), "a Blast Door off floor 1")
	expect(not bunker:CanPlace("Shaft", 1, 3, 2), "a 2-cell Shaft")
	expect(not bunker:CanPlace("Nope", 1, 3, 1), "an unknown room")
	local id = bunker:Place("Storage", 1, 3, 1)
	expect(id, "Storage on the dug cell")
	local room = bunker:Room(id :: string) :: Bunker.Room
	expectEqual({ room.Level, room.HP, room.MaxHP, room.Span }, { 1, 500, 500, 1 }, "a new level 1 room")
	for floor = 3, 10 do
		bunker:Open(floor, 0)
	end
	expect(not bunker:CanPlace("Storage", 10, 0, 1), "nothing is built in the Source Chamber")
	expect(bunker:CanPlace("Storage", 9, 0, 1), "the Crystal Hollows can be built on")
end)

test("Bunker: matching rooms side by side merge up to MaxCells; fixed rooms never merge or go", function()
	local bunker = Bunker.FromStart()
	expect(bunker:Dig(1, 4) and bunker:Dig(1, 5) and bunker:Dig(1, 6), "dig three cells")
	local a = bunker:Place("Storage", 1, 3, 1) :: string
	local b = bunker:Place("Storage", 1, 4, 2) :: string
	local c = bunker:Place("Storage", 1, 6, 1) :: string
	expectEqual(bunker:Merge(b, a), a, "the left room's id survives")
	expectEqual((bunker:Room(a) :: Bunker.Room).Span, 3, "three cells")
	expect(bunker:Room(b) == nil, "the right room is gone")
	expect(not bunker:CanMerge(a, c), "a fourth cell is past MaxCells")
	expect(not bunker:CanMerge(bunker:RoomsOfType("Quarters")[1].Id, a), "different types don't merge")
	expect(not bunker:CanRemove(bunker:RoomsOfType("BlastDoor")[1].Id), "the Blast Door stays")
	expect(not bunker:CanRemove(bunker:RoomsOfType("ReactorCore")[1].Id), "the Reactor Core stays")
	expect(bunker:Remove(a), "a Storage comes down")
	expectEqual({ bunker:State(1, 4) }, { "Dug" }, "its cells are dug again")

	expect(bunker:Dig(2, 4), "dig on floor 2")
	local g1 = bunker:Place("Generator", 2, 3, 1) :: string
	local g2 = bunker:Place("Generator", 2, 4, 1) :: string
	bunker:SetLevel(g2, 2)
	expect(not bunker:CanMerge(g1, g2), "different levels don't merge")
	bunker:SetLevel(g2, 1)
	expect(bunker:CanMerge(g1, g2), "the same level does")
end)

test("Bunker: levels set HP from Tuning.Rooms.HP, keeping its share; SetHP clamps", function()
	local bunker = Bunker.FromStart()
	local medbay = bunker:RoomsOfType("Medbay")[1]
	bunker:SetHP(medbay.Id, 250)
	expect(bunker:SetLevel(medbay.Id, 2), "level 2")
	expectEqual({ medbay.HP, medbay.MaxHP, medbay.Level }, { 400, 800, 2 }, "half HP stays half")
	expect(not bunker:SetLevel(medbay.Id, 4), "no level 4")
	expectEqual(bunker:SetHP(medbay.Id, 5000), 800, "clamped to the maximum")
	expectEqual(bunker:SetHP(medbay.Id, -3), 0, "0 is Wrecked")
end)

test("Bunker: HP is per cell; a merged room keeps both rooms' HP", function()
	local bunker = Bunker.FromStart()
	local perCell = Config.Get("Tuning", "Rooms").HP
	expectEqual(bunker:RoomsOfType("Quarters")[1].MaxHP, perCell[1] * 2, "the 2-cell Quarters")
	expect(bunker:Dig(1, 4) and bunker:Dig(1, 5), "dig two cells")
	local a = bunker:Place("Storage", 1, 3, 1) :: string
	local b = bunker:Place("Storage", 1, 4, 2) :: string
	expectEqual((bunker:Room(b) :: Bunker.Room).MaxHP, perCell[1] * 2, "a 2-cell room at level 1")
	bunker:SetHP(a, 300)
	expectEqual(bunker:Merge(a, b), a, "merged")
	local merged = bunker:Room(a) :: Bunker.Room
	expectEqual({ merged.HP, merged.MaxHP }, { 300 + perCell[1] * 2, perCell[1] * 3 }, "both parts keep their HP")
	expect(bunker:SetLevel(a, 2), "level 2")
	expectEqual(merged.MaxHP, perCell[2] * 3, "level 2, three cells")
	expectEqual(Bunker.MaxHP(1, 3), 1500, "a 3-cell room at level 1 (Landon's example)")
end)

-- Camera ---------------------------------------------------------------------------------

test("CameraRig: the camera sits behind the focus, over the right shoulder by default", function()
	local t = CameraRig.Tuning()
	local pivot = Vector3.new(0, 10, 0)
	local right = CameraRig.Focus(pivot, 0, 1, t.ShoulderOffset, t.ShoulderRaise)
	expect(right.X > 0, "right of the pivot at yaw 0 (the camera looks toward -Z)")
	local left = CameraRig.Focus(pivot, 0, -1, t.ShoulderOffset, t.ShoulderRaise)
	expect(math.abs(left.X + right.X) < 1e-6, "the left shoulder mirrors it")
	local turned = CameraRig.Focus(pivot, math.rad(90), 1, t.ShoulderOffset, 0)
	expect(math.abs(turned.Z + t.ShoulderOffset) < 1e-6, "the shoulder turns with the yaw")
	local at = CameraRig.Position(right, 0, 0, 10)
	expect((at - (right + Vector3.new(0, 0, 10))).Magnitude < 1e-6, "10 studs behind (+Z) at pitch 0")
	expect(CameraRig.Position(right, 0, math.rad(-30), 10).Y > right.Y, "looking down puts the camera above the focus")
	expectEqual(CameraRig.ClampPitch(math.rad(-120)), math.rad(t.PitchMin), "pitch clamps")
	expect(t.PitchMin < 0 and t.PitchMax > 0, "looks both up and down")
end)

test("CameraRig: zoom is capped indoors; the camera stays between a cell's floor and ceiling", function()
	local t = CameraRig.Tuning()
	local g = Grid.Tuning()
	local nearest, indoors = CameraRig.ZoomRange(true)
	local _, outdoors = CameraRig.ZoomRange(false)
	expectEqual(nearest, t.Distance.Min, "nearest")
	expect(indoors <= t.IndoorMax and indoors < outdoors, "indoors is shorter")
	expect(t.Distance.Min <= t.Distance.Default and t.Distance.Default <= t.Distance.Max, "the default is in range")
	expect(t.AimDistance >= t.Distance.Min and t.AimDistance <= t.IndoorMax, "aiming stays in range")
	local cell = Grid.CellPosition(2, 1)
	local low, high = CameraRig.CellHeights(cell + Vector3.new(0, 3, 0))
	expectEqual({ low, high }, { cell.Y + t.FloorMargin, cell.Y + g.CellHeight - t.CeilingMargin }, "cell 2,1")
	expect(CameraRig.CellHeights(Vector3.new(0, 500, 0)) == nil, "nothing outside the grid")
	local floorY, ceilingY = low :: number, high :: number
	local focus = Vector3.new(0, ceilingY - 2, 0)
	local down = CameraRig.Rotation(0, math.rad(-30)).LookVector
	local limit = CameraRig.HeightLimit(focus, down, floorY, ceilingY)
	expect(math.abs(limit - 4) < 1e-3, `looking 30 degrees down 2 under the limit allows 4, got {limit}`)
	expectEqual(CameraRig.HeightLimit(focus, Vector3.new(0, 0, -1), floorY, ceilingY), math.huge, "a level view has no limit")
end)

test("CameraRig: sticks have a dead zone and a squared response; easing is frame-rate free", function()
	expectEqual(CameraRig.Stick(Vector2.new(0.1, 0), 0.15), Vector2.zero, "inside the dead zone")
	expect(math.abs(CameraRig.Stick(Vector2.new(1, 0), 0.15).X - 1) < 1e-6, "full tilt is 1")
	expect(math.abs(CameraRig.Stick(Vector2.new(0.575, 0), 0.15).X - 0.25) < 1e-3, "half way is a quarter")
	local once = CameraRig.Approach(0, 10, 5, 0.2)
	local twice = CameraRig.Approach(CameraRig.Approach(0, 10, 5, 0.1), 10, 5, 0.1)
	expect(math.abs(once - twice) < 1e-9, "two half steps equal one step")
	expectEqual(CameraRig.MoveToward(0, 1, 0.25), 0.25, "steps toward")
	expectEqual(CameraRig.MoveToward(0.9, 1, 0.25), 1, "never past")
end)

test("Clock: boss Surges and the final Surge have no timer; the others do", function()
	expect(Clock.IsOpenEnded("Boss") and Clock.IsOpenEnded("Final"), "a boss Surge runs until the boss is beaten")
	for _, kind in { "Tutorial", "Normal", "Endless" } do
		expect(not Clock.IsOpenEnded(kind :: Clock.SurgeKind), `{kind} to be timed`)
	end
end)

-- HUD and UI ------------------------------------------------------------------------------

test("Hud: clock text, year tiles and gauge needles", function()
	expectEqual(Hud.Clock(102.4), "1:43", "rounded up")
	expectEqual(Hud.Clock(0.2), "0:01", "the last second still shows")
	expectEqual(Hud.Clock(0), "0:00", "zero")
	expectEqual(Hud.Clock(nil), "--:--", "no timer")
	expectEqual(Hud.YearDigits(7), { "0", "0", "7" }, "Year 7")
	expectEqual(Hud.YearDigits(100), { "1", "0", "0" }, "Year 100")
	expectEqual(Hud.YearDigits(1234), { "9", "9", "9" }, "the counter has three tiles")
	expectEqual(Hud.NeedleRotation(0), -135, "empty")
	expectEqual(Hud.NeedleRotation(1), 135, "full")
	expectEqual(Hud.NeedleRotation(2), 135, "clamped")
	expectEqual(Hud.Numeral(4), "IV", "Era IV")
end)

test("Hud: the cycle dial gives the day two thirds and the Surge one third (3:00 and 1:30)", function()
	local face = Hud.DialFace
	local function at(value: number): number
		return face.From + (face.To - face.From) * value
	end
	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end
	expect(near(Hud.DialPosition("Day", 180, 180, false, 180, 90), at(0)), "a day starts at the left")
	expect(near(Hud.DialPosition("Day", 180, 90, false, 180, 90), at(1 / 3)), "half a day")
	expect(near(Hud.DialPosition("Day", 180, 0, false, 180, 90), at(2 / 3)), "the day ends at two thirds")
	expect(near(Hud.DialPosition("Surge", 90, 45, false, 180, 90), at(5 / 6)), "half a Surge")
	expect(near(Hud.DialPosition("Surge", 0, nil, true, 180, 90), at(2 / 3)), "a boss Surge parks at its start")
	expect(near(Hud.DialPosition(nil, nil, nil, false, 180, 90), at(0)), "before the first day")
end)

test("Hud: the mini-map window follows the player and stays on the grid", function()
	local grid = { ColumnMin = -6, ColumnMax = 6, FloorMin = 1, FloorMax = 10 }
	expectEqual({ Hud.MapWindow(2, 0, grid, 5, 5) }, { -2, 1 }, "centred on the player, one floor above")
	expectEqual({ Hud.MapWindow(1, -6, grid, 5, 5) }, { -6, 1 }, "the left edge")
	expectEqual({ Hud.MapWindow(10, 6, grid, 5, 5) }, { 2, 6 }, "the bottom right corner")
end)

test("Bunker: a client copy from the replicated collections matches the bunker", function()
	local bunker = Bunker.FromStart()
	local cells, rooms = {}, {}
	for key, value in bunker.Cells do
		cells[key] = if value == "" then {} else { Room = value }
	end
	for id, room in bunker.Rooms do
		rooms[id] = { Type = room.Type, Floor = room.Floor, Column = room.Column, Span = room.Span,
			Level = room.Level, HP = room.HP, MaxHP = room.MaxHP }
	end
	local copy = Bunker.FromSnapshot(cells, rooms)
	for key in bunker.Cells do
		local floor, column = Grid.Parse(key)
		expectEqual({ copy:State(floor :: number, column :: number) }, { bunker:State(floor :: number, column :: number) }, key)
	end
	expectEqual(copy:DeepestFloor(), 2, "deepest floor")
	expect(copy:Dig(3, 3), "the copy follows the rules (dig under an open cell)")
	expect(copy:Place("Storage", 2, 3, 1) ~= nil, "and builds with fresh ids")
end)

test("CommandView: distance and visible height invert; the view stays over the grid", function()
	local d = CommandView.DistanceFor(63, 8)
	expect(math.abs(CommandView.VisibleHeight(d, 8) - 63) < 1e-9, "round trip")
	local bounds = CommandView.Bounds()
	expect(bounds.Left < bounds.Right and bounds.Bottom < bounds.Top, "bounds are ordered")
	local pitch = Grid.Pitch()
	expect(math.abs((bounds.Right - bounds.Left) - 13 * pitch.X) < 1e-6, "13 columns wide")
	expect(math.abs((bounds.Top - bounds.Bottom) - 10 * pitch.Y) < 1e-6, "10 floors tall")
	local far = CommandView.Clamp(Vector2.new(1e6, -1e6), bounds)
	expectEqual(far, Vector2.new(bounds.Right, bounds.Bottom), "clamped to the corner")
	local grid = Grid.Tuning()
	expectEqual(bounds.Top, Grid.CellPosition(1, 0).Y + grid.CellHeight, "the top is floor 1's ceiling")
	local low, high = CommandView.CellBox(2, -2, 2)
	expectEqual(low, Vector2.new(Grid.CellPosition(2, -2).X - pitch.X / 2, Grid.CellPosition(2, -2).Y), "a box starts at its floor")
	expectEqual(high.Y - low.Y, grid.CellHeight, "and reaches the ceiling")
	expect(math.abs((high.X - low.X) - 2 * pitch.X) < 1e-9, "two cells wide")
end)

test("CommandView: the camera never backs off past MaxDistance; the field of view widens instead", function()
	local tuning = CommandView.Tuning()
	local near = tuning.MaxDistance * 2 * math.tan(math.rad(tuning.FieldOfView) / 2) * 0.5
	local d, fov = CommandView.Lens(near)
	expectEqual(fov, tuning.FieldOfView, "close in: the narrow field of view")
	expect(d < tuning.MaxDistance, "and nearer than the cap")
	for _, floors in { tuning.StartFloors, tuning.MaxFloors } do
		local height = floors * Grid.Pitch().Y
		d, fov = CommandView.Lens(height)
		expect(d <= tuning.MaxDistance + 1e-9, `{floors} floors: within the cap`)
		expect(math.abs(CommandView.VisibleHeight(d, fov) - height) < 1e-6, `{floors} floors: still that many floors on screen`)
		expect(fov >= tuning.FieldOfView and fov < 40, `{floors} floors: a field of view of {fov}`)
	end
	expect(tuning.MaxDistance + Grid.Pitch().Z < 500, "the back of the bunker is within the lowest graphics level's draw distance")
end)

test("CommandView: the build menu follows the unlocks and the placement rules (bible Section 6)", function()
	local bunker = Bunker.FromStart()
	local era1 = { Era = 1, Deepest = bunker:DeepestFloor() }
	expect(CommandView.RoomChoice(bunker, "Kitchen", 2, 3, era1), "a Kitchen on an open cell")
	local ok, why = CommandView.RoomChoice(bunker, "Armory", 2, 3, era1)
	expect(not ok and string.find(why or "", "blueprint draft"), "the Armory needs a draft")
	ok, why = CommandView.RoomChoice(bunker, "DeconRoom", 2, 3, era1)
	expect(not ok and string.find(why or "", "Era II"), "the Decon Room needs Era II")
	expect(CommandView.RoomChoice(bunker, "DeconRoom", 2, 3, { Era = 2, Deepest = 2 }), "and has it in Era II")
	expect(CommandView.RoomChoice(bunker, "DrillBay", 2, 3, era1), "depth 2 unlocks the Drill Bay")
	ok, why = CommandView.RoomChoice(bunker, "ReactorCore", 2, 3, era1)
	expect(not ok and string.find(why or "", "already"), "one Reactor Core")
	ok = CommandView.RoomChoice(bunker, "Armory", 2, 3, { Era = 1, Deepest = 2, Unlocked = { Armory = true } })
	expect(ok, "a draft won unlocks the Armory")
	expectEqual(CommandView.CostText({ Scrap = 120 }), "120 SCRAP", "one cost")
	expectEqual(CommandView.CostText({ Iron = 20, Scrap = 220 }), "220 SCRAP · 20 IRON", "costs in Resources order")
	expectEqual(CommandView.CostText({}), "FREE", "nothing")
end)

test("Votes: Section 8's rules (abstaining, ties fail, whole-team majority, two thirds, everyone yes)", function()
	expectEqual(Votes.Outcome("MoreYes", 2, 1, 4), "Pass", "more yes than no")
	expectEqual(Votes.Outcome("MoreYes", 1, 0, 6), "Pass", "abstainers don't count")
	expectEqual(Votes.Outcome("MoreYes", 1, 1, 3), "Tie", "a tie")
	expectEqual(Votes.Outcome("MoreYes", 0, 0, 3), "Tie", "nobody voted: a tie, so it fails")
	expectEqual(Votes.Outcome("MoreYes", 1, 2, 3), "Fail", "more no")
	expectEqual(Votes.Outcome("WholeTeamMajority", 3, 0, 4), "Pass", "3 of 4")
	expectEqual(Votes.Outcome("WholeTeamMajority", 2, 0, 4), "Fail", "2 of 4 is not a majority")
	expectEqual(Votes.Outcome("WholeTeamMajority", 2, 2, 4), "Tie", "the team split evenly")
	expectEqual(Votes.Outcome("WholeTeamMajority", 2, 1, 3), "Pass", "2 of 3")
	expectEqual(Votes.Majority(5), 3, "a majority of 5")
	expectEqual(Votes.TwoThirds(3), 2, "two thirds of 3 others")
	expectEqual(Votes.Outcome("TwoThirdsOfOthers", 4, 1, 5), "Pass", "4 of 5 others")
	expectEqual(Votes.Outcome("TwoThirdsOfOthers", 3, 2, 5), "Fail", "3 of 5 others is short")
	expect(Votes.AllYes(4, 4) and not Votes.AllYes(3, 4), "everyone yes passes at once")
	local stock = { Scrap = 300, Iron = 50 }
	expect(not Votes.BigSpend({ Scrap = 120 }, stock), "120 of 300 Scrap is 40%: not more")
	expect(Votes.BigSpend({ Scrap = 121 }, stock), "121 of 300 is more than 40%")
	expect(Votes.BigSpend({ Scrap = 10, Iron = 30 }, stock), "any one stock counts")
	expectEqual(Votes.RuleFor("Build", false), "MoreYes", "a build")
	expectEqual(Votes.RuleFor("Build", true), "WholeTeamMajority", "a big spend")
	expectEqual(Votes.RuleFor("PushDeeper", false), "WholeTeamMajority", "Push Deeper")
	expectEqual(Votes.NeedText("WholeTeamMajority", 4), "3 OF 4 MUST SAY YES", "need text")
	local seen = {}
	for seed = 1, 40 do
		seen[Votes.Winner({ A = 2, B = 2, C = 1 }, { "A", "B", "C" }, Random.new(seed)) :: string] = true
	end
	expect(seen.A and seen.B and not seen.C, "a draft tie is picked at random between the leaders")
	expectEqual(Votes.Winner({}, {}, Random.new(1)), nil, "no options")
end)

test("Construction: plans follow the bunker's rules, the unlocks, the stockpile and research", function()
	local bunker = Bunker.FromStart()
	local context = { Era = 1, Deepest = bunker:DeepestFloor(), Stock = { Scrap = 300 }, Research = 0 }
	local plan, why = Construction.Plan(bunker, { Action = "Build", Floor = 2, Column = 3, RoomType = "Workshop" }, context)
	expect(plan ~= nil, `a Workshop on the open cell ({why})`)
	expectEqual((plan :: any).Costs, Config.Get("Rooms", "Workshop").Costs[1], "level 1 costs")
	expectEqual((plan :: any).Label, "WORKSHOP", "label")
	plan, why = Construction.Plan(bunker, { Action = "Build", Floor = 2, Column = 3, RoomType = "Armory" }, context)
	expect(plan == nil and string.find(why or "", "blueprint draft"), "the Armory needs a draft")
	plan, why = Construction.Plan(bunker, { Action = "Build", Floor = 2, Column = 3, RoomType = "ReactorCore" }, context)
	expect(plan == nil and string.find(why or "", "comes with the bunker"), "Fixed rooms are never built")
	local reserved = { Era = 1, Deepest = 2, Reserved = { ["2,3"] = true } }
	plan, why = Construction.Plan(bunker, { Action = "Build", Floor = 2, Column = 3, RoomType = "Kitchen" }, reserved)
	expect(plan == nil and string.find(why or "", "already proposed"), "one proposal per cell")
	plan, why = Construction.Plan(bunker, { Action = "Build", Floor = 2, Column = 3, RoomType = "Kitchen" },
		{ Era = 1, Deepest = 2, Stock = { Scrap = 50 } })
	expect(plan == nil and string.find(why or "", "70 Scrap short"), `the stockpile must pay ({why})`)
	local medbay = bunker:RoomAt(2, 2) :: any
	local noCosts = { Era = 1, Deepest = 2 } -- no stock: costs aren't checked
	plan = Construction.Plan(bunker, { Action = "Upgrade", Floor = 2, Column = 2 }, noCosts)
	expect(plan ~= nil and plan.Level == 2 and plan.RoomId == medbay.Id, "an upgrade to level 2")
	expectEqual((plan :: any).Costs, Config.Get("Rooms", "Medbay").Costs[2], "level 2 costs")
	plan, why = Construction.Plan(bunker, { Action = "Upgrade", Floor = 2, Column = 2 }, context)
	expect(plan == nil and string.find(why or "", "Iron short"), `level 2 needs Iron the stock hasn't got ({why})`)
	bunker:SetLevel(medbay.Id, 2)
	plan, why = Construction.Plan(bunker, { Action = "Upgrade", Floor = 2, Column = 2 },
		{ Era = 1, Deepest = 2, Research = 5 })
	expect(plan == nil and string.find(why or "", "Lab research"), "level 3 needs Lab research")
	local quarters = bunker:RoomAt(1, 1) :: any
	plan = Construction.Plan(bunker, { Action = "Upgrade", Floor = 1, Column = 2 }, noCosts)
	local perCell = Config.Get("Rooms", "Quarters").Costs[2]
	expect(plan ~= nil and quarters.Span == 2, "the 2-cell Quarters")
	for id, amount in perCell do
		expectEqual((plan :: any).Costs[id], amount * 2, `a 2-cell upgrade pays {id} for both cells`)
	end
	plan, why = Construction.Plan(bunker, { Action = "TearDown", Floor = 2, Column = 1 }, context)
	expect(plan == nil and why ~= nil, "the Reactor Core can't be torn down")
	plan = Construction.Plan(bunker, { Action = "TearDown", Floor = 2, Column = -2 }, context)
	expect(plan ~= nil and next(plan.Costs) == nil, "tearing down is free")
	expectEqual((plan :: any).Refund, { Scrap = 60 }, "a level 1 Kitchen gives half its 120 Scrap back (Landon)")
	local kitchen = bunker:Place("Kitchen", 2, 3, 1) :: string
	local first = bunker:RoomAt(2, -2) :: any
	plan, why = Construction.Plan(bunker, { Action = "Merge", Floor = 2, Column = 3, Other = first.Id }, context)
	expect(plan == nil and why ~= nil, `rooms apart don't merge ({why})`)
	expect(kitchen ~= nil, "a second Kitchen")
	expectEqual(Construction.Seconds(1), 20, "20 s a cell")
	expectEqual(Construction.Rate(0), 1, "alone")
	expectEqual(Construction.Rate(2), 1.5, "two helpers")
	expectEqual(Construction.CostText({ Iron = 20, Scrap = 220 }), "220 SCRAP · 20 IRON", "cost text")
	local ok, short, missing = Construction.CanAfford({ Scrap = 120, Iron = 10 }, { Scrap = 200, Iron = 4 })
	expect(not ok and short == "Iron" and missing == 6, "the first short resource")
end)

test("Economy: Section 13's output formula, power made and drawn, food eaten", function()
	local average = { Workers = 2, StatSum = 10, Morale = 1 }
	expectEqual(Economy.Output("Kitchen", 1, 1, average, true), 8, "a level 1 Kitchen with workers summing to 10 makes its Base")
	local big = Economy.Output("Kitchen", 2, 2, { Workers = 4, StatSum = 20, Morale = 1 }, true)
	expect(math.abs(big - 26.4) < 1e-6, `2 cells at level 2: 8 x 2 x 1.5 x 1.1 = 26.4 (got {big})`)
	expectEqual(Economy.Output("Kitchen", 1, 1, average, false), 0, "a dark room makes nothing")
	expectEqual(Economy.Output("Kitchen", 1, 1, nil, true), 0, "no crew, nothing made")
	local happy = Economy.Output("Kitchen", 1, 1, { Workers = 2, StatSum = 10, Morale = 1.2 }, true, 1.5)
	expect(math.abs(happy - 14.4) < 1e-6, `morale and bunker-wide multipliers (got {happy})`)
	expectEqual(Economy.Output("Quarters", 1, 2, average, true), 0, "Quarters make nothing")
	expectEqual(Economy.PowerMade("ReactorCore", 1, 1, average), 24, "the Reactor Core with a full crew")
	expectEqual(Economy.PowerMade("ReactorCore", 1, 1, { Workers = 1, StatSum = 5, Morale = 1 }), 12, "half the stat, half the power")
	expectEqual(Economy.PowerMade("ReactorCore", 1, 1, nil), 0, "no crew, no power (Landon: A)")
	expectEqual(Economy.Draw("Quarters", 1, 2), 2, "the 2-cell Quarters draw 1 a cell")
	local kind, resource = Economy.Makes("Kitchen", 2)
	expect(kind == "Resource" and resource == "Food", "the Kitchen makes Food")
	kind, resource = Economy.Makes("DrillBay", 5)
	expect(kind == "Resource" and resource == "Copper", "a Drill Bay makes its band's ore")
	kind, resource = Economy.Makes("Lab", 2)
	expect(kind == "Research" and resource == nil, "the Lab makes research")
	expect(Economy.Makes("Quarters", 1) == nil, "the Quarters make nothing")
	local take, carry = Economy.Eat({ 1, 1, 1, 0.5 }, 1, 0)
	expect(take == 3 and math.abs(carry - 0.5) < 1e-6, "3.5 Food: 3 now, half carried")
	take, carry = Economy.Eat({ 1, 1, 1, 0.5 }, 1, carry)
	expect(take == 4 and carry < 1e-6, "the carried half makes 4 the next cycle")
	local whole, rest = Economy.Accrue(0, 8, 135, 270)
	expect(whole == 4 and rest < 1e-6, "half a cycle makes half of 8")
	whole, rest = Economy.Accrue(0.9, 8, 10, 270)
	expect(whole == 1 and math.abs(rest - (0.9 + 80 / 270 - 1)) < 1e-6, "fractions carry over")
	expectEqual(Construction.Refund("Kitchen", 2, 2), { Scrap = 340, Iron = 20 }, "half of both levels' costs, per cell")
	expect(Config.Get("Difficulties", "Nightmare").UpgradesTakeTime == true, "upgrades take time on Nightmare")
	expect(not Config.Get("Difficulties", "Normal").UpgradesTakeTime, "and are instant on Normal")
end)

test("Economy: power goes dark farthest from the Reactor Core first", function()
	local bunker = Bunker.FromStart()
	local reactor = bunker:RoomAt(2, 1) :: any
	local full = { Workers = 2, StatSum = 10, Morale = 1 }
	local function crewWith(crew: any): (string) -> any
		return function(roomId: string): any
			return if roomId == reactor.Id then crew else nil
		end
	end
	local balance = Economy.Balance(bunker, crewWith(full))
	expect(balance.Made == 24 and balance.Needed == 10 and balance.Used == 10 and next(balance.Dark) == nil,
		`the starting bunker: 24 made, 10 drawn, nothing dark (got {balance.Made}, {balance.Needed})`)
	expectEqual(balance.Steps[reactor.Id], 0, "the Reactor Core is step 0")
	expectEqual(balance.Steps[(bunker:RoomAt(2, 2) :: any).Id], 1, "the Medbay beside it")
	expectEqual(balance.Steps[bunker:UnitAt(2, 3) :: string], 2, "a dug cell counts as a step")
	expectEqual(balance.Steps[(bunker:RoomAt(1, 1) :: any).Id], 3, "the Quarters, up the Shaft")
	expectEqual(balance.Steps[bunker:UnitAt(1, 3) :: string], 4, "the dug cell past the Quarters")
	local kitchen = bunker:RoomAt(2, -2) :: any
	balance = Economy.Balance(bunker, crewWith({ Workers = 1, StatSum = 4, Morale = 1 }))
	expect(math.abs(balance.Made - 9.6) < 1e-6, "a weak crew makes 9.6")
	expectEqual(balance.Dark, { [kitchen.Id] = true }, "short by 0.4: equal draws, so the newest of the farthest rooms goes dark")
	-- at the same distance the biggest draw goes first (Landon): the Quarters at level 3 draw 4
	local quarters = bunker:RoomAt(1, 1) :: any
	bunker:SetLevel(quarters.Id, 3)
	balance = Economy.Balance(bunker, crewWith({ Workers = 1, StatSum = 4, Morale = 1 }))
	expectEqual(balance.Dark, { [quarters.Id] = true }, "12 needed, 9.6 made: the Quarters (draw 4) go before the newer Kitchen (draw 2)")
	bunker:SetLevel(quarters.Id, 1)
	-- a wrecked room draws nothing (Landon)
	bunker:SetHP(kitchen.Id, 0)
	balance = Economy.Balance(bunker, crewWith(full))
	expect(balance.Needed == 8 and balance.Draw[kitchen.Id] == nil, `a wrecked Kitchen draws nothing ({balance.Needed})`)
	bunker:SetHP(kitchen.Id, kitchen.MaxHP)
	balance = Economy.Balance(bunker, crewWith(nil))
	local darkCount = 0
	for id in balance.Dark do
		darkCount += 1
		expect((bunker:Room(id) :: any).Type ~= "Shaft", "Shafts draw nothing and stay lit")
	end
	expect(darkCount == 5 and balance.Used == 0, `no crew: every room that draws goes dark ({darkCount})`)
	-- a room nothing can reach goes dark before a far one, even when it is older
	expect(bunker:Dig(3, 3), "dig under the dug cell")
	local lost = bunker:Place("Kitchen", 3, 3, 1) :: string
	local far = bunker:Place("Kitchen", 1, 3, 1) :: string
	expect(lost ~= nil and far ~= nil, "two more Kitchens")
	balance = Economy.Balance(bunker, crewWith({ Workers = 1, StatSum = 5, Morale = 1 }))
	expect(balance.Steps[lost] == nil and balance.Steps[far] == 4, "the dug-under Kitchen can't be reached")
	expectEqual(balance.Dark, { [lost] = true }, "12 made, 14 needed: the unreachable Kitchen goes dark first")
end)

test("Residents: rolls, levels, morale, crews, Auto-Assign and needs (Section 11)", function()
	local t = Config.Get("Tuning", "Residents")
	local rng = Random.new(7)
	local used = {}
	local a = Residents.Roll(rng, "N1", "Common", 1, used)
	local b = Residents.Roll(rng, "N2", "Common", 3, used)
	expect(Residents.Name(a) ~= Residents.Name(b) and used[Residents.Name(a)] and used[Residents.Name(b)], "names don't repeat")
	for _, stat in Residents.StatIds() do
		expect(a.Stats[stat] >= t.StatMin and a.Stats[stat] <= t.StatMax, `{stat} rolls {t.StatMin} to {t.StatMax}`)
	end
	expectEqual(a.MaxHealth, t.HealthBase + a.Stats.Grit * t.HealthPerGrit, "max health from Grit")
	expect(a.Health == a.MaxHealth and a.Morale == t.MoraleStart and a.Rest == 100 and a.State == "Alive", "a fresh resident")
	expect(b.Level == 3, "a level 3 founder")
	expectEqual(Residents.XPToLevel(1), t.XPToLevelBase, "XP to level 2")
	local speed = a.Stats.Speed
	expectEqual(Residents.AddXP(a, Residents.XPToLevel(1), "Speed"), 1, "one level")
	expect(a.Level == 2 and a.Stats.Speed == math.min(t.StatCap, speed + 1), "the level goes into the job's stat")
	local mood, effect = Residents.MoraleState(60)
	expect(mood == "Settled" and effect == 1, "60 is Settled")
	mood, effect = Residents.MoraleState(95)
	expect(mood == "Inspired" and effect == 1.2, "95 is Inspired: +20%")
	-- a crew: Speed 4 and 6 at morale 60 and 80
	local cook1 = Residents.Roll(rng, "N3", "Common", 1, used)
	local cook2 = Residents.Roll(rng, "N4", "Common", 1, used)
	cook1.Stats.Speed, cook2.Stats.Speed, cook1.Morale, cook2.Morale = 4, 6, 60, 80
	local crew = Residents.Crew({ cook1, cook2 }, "Kitchen") :: any
	expect(crew.Workers == 2 and crew.StatSum == 10 and math.abs(crew.Morale - 1.05) < 1e-6, "a Kitchen crew: Speed 10, morale 1.05")
	cook2.Rest = 0
	crew = Residents.Crew({ cook1, cook2 }, "Kitchen") :: any
	expect(crew.StatSum == 4 + 6 * Config.Get("Conditions", "Exhausted").OutputMultiplier, "an Exhausted worker counts half")
	expect(Residents.Crew({ cook1 }, "Quarters") == nil, "nobody works in the Quarters")
	-- Auto-Assign on the starting bunker: the Reactor Core first
	local bunker = Bunker.FromStart()
	local rooms = {}
	for _, room in bunker:AllRooms() do
		table.insert(rooms, { Id = room.Id, Type = room.Type, Level = room.Level, Span = room.Span })
	end
	local free = {}
	for i = 1, 6 do
		table.insert(free, Residents.Roll(rng, `N{10 + i}`, "Common", 1, used))
	end
	local plan = Residents.AutoAssign(rooms, {}, free)
	local reactor = (bunker:RoomAt(2, 1) :: any).Id
	local onReactor, assigned = 0, 0
	for _, roomId in plan do
		assigned += 1
		if roomId == reactor then
			onReactor += 1
		end
	end
	expect(assigned == 6 and onReactor == 2 and #free == 0, `six jobs, two on the Reactor Core ({assigned}, {onReactor})`)
	-- the best matches: a fast cook goes to the Kitchen, not the reactor
	local cook = Residents.Roll(rng, "N40", "Common", 1, used)
	local strong = Residents.Roll(rng, "N41", "Common", 1, used)
	cook.Stats = { Strength = 7, Smarts = 1, Grit = 1, Speed = 10, Charm = 1 }
	strong.Stats = { Strength = 6, Smarts = 1, Grit = 1, Speed = 2, Charm = 1 }
	local kitchen = (bunker:RoomAt(2, -2) :: any).Id
	plan = Residents.AutoAssign({ { Id = reactor, Type = "ReactorCore", Level = 1, Span = 1 },
		{ Id = kitchen, Type = "Kitchen", Level = 1, Span = 1 } }, { [reactor] = 1, [kitchen] = 1 }, { cook, strong })
	expect(plan[cook.Id] == kitchen and plan[strong.Id] == reactor, "the Speed 10 resident cooks; the Strength 6 one runs the reactor")
	-- needs: a worker with a bed, one without, one who missed the meal
	local worker = Residents.Roll(rng, "N30", "Common", 1, used)
	Residents.Cycle(worker, true, nil, true, true, false)
	expectEqual(worker.Rest, 100, "work then a bed: rested")
	Residents.Cycle(worker, true, nil, false, true, false)
	expectEqual(worker.Rest, 100 - t.RestDrainPerShift + t.RestRefillPerCycle * t.NoBedRestMultiplier, "no bed: less rest")
	local health = worker.Health
	Residents.Cycle(worker, true, nil, true, false, false)
	expect(worker.Hungry and worker.Health == health - t.ShortfallHealth, "a missed meal costs health")
end)

test("RunState: a value for every stocked resource, written by EconomyService", function()
	for _, id in Config.Ids("Resources") do
		local resource = Config.Get("Resources", id)
		if resource.Kind == "Stock" then
			expect(RunState.Fields[id] ~= nil and RunState.Fields[id].By == "EconomyService", `{id} in RunState`)
		else
			expect(RunState.Fields[id] == nil, `{id} is live, not a RunState stock`)
		end
	end
end)

test("UIContract: the Frame is in both places, the HUD in the Run; paths are unique", function()
	expectEqual(UIContract.Screens.Frame.Places, { "Lobby", "Run" }, "Frame places")
	expectEqual(UIContract.Screens.HUD.Places, { "Run" }, "HUD places")
	for name, screen in UIContract.Screens do
		local seen = {}
		for _, path in screen.Paths do
			expect(not seen[path], `{name}: {path} listed once`)
			seen[path] = true
		end
	end
end)

-- Combat ---------------------------------------------------------------------------------

test("Combat: damage, fire rate, spread and reloads (Section 9)", function()
	expectEqual(Combat.Damage("PocketPistol", "Standard"), 12, "the Pocket Pistol at Standard")
	expect(math.abs(Combat.Damage("PocketPistol", "Rusty") - 10.2) < 1e-6, "Rusty is 0.85x")
	expectEqual(Combat.Damage("Wrench", nil), 14, "a light Wrench swing")
	expectEqual(Combat.Damage("Wrench", "Legendary", true), 39, "a heavy Legendary Wrench swing (26 x 1.5)")
	expectEqual(Combat.Damage("Medkit", nil), 0, "not a weapon")
	expect(math.abs(Combat.Interval("PocketPistol") - 0.25) < 1e-9, "4 shots a second")
	expectEqual(Combat.Pellets("PumpShotgun"), 8, "the shotgun's pellets")
	local aim = Vector3.new(0, 0, -1)
	local seed = Combat.ShotSeed(123456, 7)
	local a = Combat.Spread(seed, aim, "PumpShotgun")
	local b = Combat.Spread(seed, aim, "PumpShotgun")
	expect(#a == 8, "eight pellet directions")
	for i, direction in a do
		expect(direction:FuzzyEq(b[i], 1e-9), "the same seed gives the same spread on both sides")
		local off = math.deg(math.acos(math.clamp(direction:Dot(aim), -1, 1)))
		expect(off <= 7 + 1e-6 and math.abs(direction.Magnitude - 1) < 1e-6, `pellet {i} within 7 degrees ({off})`)
	end
	expect(Combat.ShotSeed(123456, 8) ~= seed, "every shot has its own seed")
	local one = Combat.Spread(Combat.ShotSeed(1, 1), aim, "LeverRifle")
	expect(#one == 1 and math.deg(math.acos(math.clamp(one[1]:Dot(aim), -1, 1))) <= 0.3 + 1e-6, "one bullet, 0.3 degrees at most")
	local magazine, carried = Combat.Reload(3, 60, "PocketPistol")
	expect(magazine == 10 and carried == 53, `reload the Pocket Pistol: 10 and 53 ({magazine}, {carried})`)
	magazine, carried = Combat.Reload(0, 5, "PumpShotgun")
	expect(magazine == 2 and carried == 1, `2 ammo a shotgun shot: 2 shots and 1 left ({magazine}, {carried})`)
	magazine, carried = Combat.Reload(10, 60, "PocketPistol")
	expect(magazine == 10 and carried == 60, "a full magazine takes nothing")
end)

test("Combat: hit checks against where the target was (Section 23)", function()
	local origin = Vector3.new(0, 5, 0)
	local aim = Vector3.new(0, 0, -1)
	local history = {
		{ T = 10.0, P = Vector3.new(0, 5, -40) },
		{ T = 10.1, P = Vector3.new(2, 5, -40) },
		{ T = 10.2, P = Vector3.new(4, 5, -40) },
		{ T = 10.3, P = Vector3.new(6, 5, -40) },
	}
	expect(Combat.PositionAt(history, 10.05):FuzzyEq(Vector3.new(1, 5, -40), 1e-6), "positions between samples")
	expect(Combat.PositionAt(history, 9):FuzzyEq(history[1].P, 1e-6), "before the history: its first sample")
	local ok, why = Combat.CheckHit(origin, aim, Vector3.new(0, 5, -39), 120, history, 10.05, 10.3, 2)
	expect(ok, `a hit where the target was 0.25 s ago counts ({why})`)
	ok, why = Combat.CheckHit(origin, aim, Vector3.new(0, 5, -39), 120, history, 10.25, 10.3, 2)
	expect(not ok and why == "not where the target was", `the target had moved on by then ({why})`)
	ok, why = Combat.CheckHit(origin, aim, Vector3.new(4, 5, -40), 120, history, 10.05, 10.3, 2)
	expect(not ok and why == "off the shot's line", `4 studs off the line ({why})`)
	ok, why = Combat.CheckHit(origin, aim, Vector3.new(0, 5, -40), 30, history, 10.05, 10.3, 2)
	expect(not ok and why == "out of range", `past the gun's range ({why})`)
	ok, why = Combat.CheckHit(origin, aim, Vector3.new(0, 5, 10), 120, {}, 0, 0, 2)
	expect(not ok and why == "behind the shot", `behind the shooter ({why})`)
end)

test("Combat: melee arcs, combos, cones, stamina and respawn (Section 9)", function()
	local attacker = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
	expect(Combat.InArc(attacker, Vector3.new(0, 0, -5), 6, 110, 1), "in front, in reach")
	expect(Combat.InArc(attacker, Vector3.new(4.5, 0, -4.5), 6, 110, 1), "45 degrees off: inside a 110-degree arc")
	expect(not Combat.InArc(attacker, Vector3.new(0, 0, 5), 6, 110, 1), "behind")
	expect(not Combat.InArc(attacker, Vector3.new(0, 0, -9), 6, 110, 1), "out of reach")
	expect(not Combat.InArc(attacker, Vector3.new(0, 9, -2), 6, 110, 1), "far overhead")
	expect(Combat.InCone(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(3, 0, -15), 18, 20, 0), "inside the flame's cone")
	expect(not Combat.InCone(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(12, 0, -10), 18, 20, 0), "outside it")
	expect(not Combat.InCone(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 0, -25), 18, 20, 0), "past its range")
	local index, angle = Combat.AssistTarget(Vector3.zero, Vector3.new(0, 0, -1),
		{ Vector3.new(10, 0, -10), Vector3.new(0.5, 0, -10) }, 6, 100)
	expect(index == 2 and angle < 6, "aim assist picks the target nearest the aim, within 6 degrees")
	expect(Combat.AssistTarget(Vector3.zero, Vector3.new(0, 0, -1), { Vector3.new(10, 0, -10) }, 6, 100) == nil,
		"and nothing outside its cone")
	expect(Combat.NextCombo(0, 0) == 1 and Combat.NextCombo(1, 0.3) == 2 and Combat.NextCombo(2, 0.3) == 3, "1, 2, 3")
	expect(Combat.NextCombo(3, 0.3) == 1 and Combat.NextCombo(1, 2) == 1, "after the third hit, or too late: 1 again")
	local windup, length = Combat.Swing("Wrench", false)
	expect(math.abs(windup - 0.14) < 1e-9 and math.abs(length - 0.35) < 1e-9, `a Wrench swing ({windup}, {length})`)
	windup, length = Combat.Swing("Wrench", true)
	expect(math.abs(length - 0.56) < 1e-9, `a heavy one takes 1.6x ({length})`)
	expectEqual(Combat.Stamina(100, 100, 1, true, 0), 88, "sprinting drains 12 a second")
	expectEqual(Combat.Stamina(50, 100, 1, false, 0.2), 50, "no regrowth right after spending")
	expectEqual(Combat.Stamina(50, 100, 1, false, 2), 68, "then 18 a second")
	expectEqual(Combat.Stamina(95, 100, 1, false, 2), 100, "up to the maximum")
	expectEqual(Combat.Stamina(5, 100, 1, true, 0), 0, "never below 0")
	local nearest = Combat.Nearest(Vector3.zero, {
		{ Id = "R8", Position = Vector3.new(40, 0, 0) },
		{ Id = "R12", Position = Vector3.new(0, -20, 0) },
	})
	expect(nearest and nearest.Id == "R12", "the closest Medbay")
	expect(Combat.Nearest(Vector3.zero, {}) == nil, "none to pick")
	local tuning = Config.Get("Tuning", "Player")
	expect(tuning.DownedSeconds == 20 and tuning.ReviveSeconds == 3 and tuning.RespawnSeconds == 15, "Section 9's timings")
end)

test("Throwables: each can be crafted and found exploring (Landon's Prompt 12 answer)", function()
	local found: { [string]: boolean } = {}
	for _, tbl in all("LootTables") do
		for _, line in tbl.Lines do
			if line.Item then
				found[line.Item] = true
			end
		end
	end
	local crafted: { [string]: boolean } = {}
	for _, recipe in all("Recipes") do
		if recipe.Gives and recipe.Gives.Item then
			crafted[recipe.Gives.Item] = true
		end
	end
	for _, item in all("Items") do
		if item.Kind == "Throwable" then
			expect(crafted[item.Id], `{item.Id} has a Workshop recipe`)
			expect(found[item.Id], `{item.Id} is in a loot table`)
		end
	end
end)

test("Combat: every kit has a melee weapon; Medkits and throwables (Landon, 2026-11-08)", function()
	for _, class in Config.All("Classes") do
		local id = class.Id
		local melee = 0
		for _, stack in class.Kit do
			local item = Config.Find("Items", stack.Item)
			expect(item ~= nil, `{id}'s kit item {stack.Item} exists`)
			if item and item.Kind == "Melee" then
				melee += 1
			end
		end
		expectEqual(melee, 1, `{id}'s kit has one melee weapon`)
	end
	for _, item in Config.All("Items") do
		if item.Kind == "Throwable" then
			expect(item.Throwable ~= nil and item.Throwable.Radius > 0, `{item.Id} has its throw numbers`)
		end
	end
	local p = Config.Get("Tuning", "Player")
	expect(p.MedkitHeal == 60 and p.MedkitSeconds == 1.5 and p.Loadout.Medkits == 3, "a Medkit heals 60 over 1.5 s; carry 3")
	local medic = Config.Get("Classes", "Medic")
	expect(medic.Kit[1].Item == "Medkit" and medic.Kit[1].Count == 5, "the Medic starts with 5 Medkits (Section 14)")
end)

-- Threats (Prompt 12) -----------------------------------------------------------------------

test("Threat: level, Surge budgets and the era's roster (Section 10)", function()
	local t = Config.Get("Tuning", "Threat")
	local level = Threat.Level({ Year = 10, DeepestFloor = 2, Disturbance = 0, Rooms = 8, Players = 1 })
	expect(math.abs(level - (t.Base + t.PerYear * 10 + t.PerDeepestFloor * 2 + t.PerRoom * 8)) < 1e-9, `solo level ({level})`)
	local four = Threat.Level({ Year = 10, DeepestFloor = 2, Disturbance = 0, Rooms = 8, Players = 4 })
	expect(math.abs(four - level * t.PlayerScale[4]) < 1e-9, "four players scale it")
	expect(Threat.Level({ Year = 10, DeepestFloor = 2, Disturbance = 40, Rooms = 8, Players = 1 }) > level, "Disturbance raises it")
	expectEqual(Threat.SurgeBudget(level, "Tutorial", false), t.TutorialSurgeBudget, "the first Surge is the tutorial wave")
	expectEqual(Threat.SurgeBudget(level, "Boss", false), 0, "a boss Surge brings its boss instead")
	expect(math.abs(Threat.SurgeBudget(level, "Normal", true) - level * 0.7) < 1e-9, "a first run's Era I is 30% easier")
	local roster = Threat.Roster("SettlingIn")
	expect(#roster == 4 and table.find(roster, "BurrowTick") and table.find(roster, "HollowMiner")
		and table.find(roster, "SpitterGrub") and table.find(roster, "TunnelHound"), "Era I: the four Mines monsters")
	expect(not table.find(Threat.Roster("Expansion"), "AshRaider"), "raiders come by the Blast Door, not breaches")
	expect(table.find(Threat.Roster(4), "Murkling") ~= nil, "Era IV: everything before")
	expectEqual(t.MaxMonsters, 25, "Section 23's cap")
end)

test("Threat: groups within the budget, weighted points, target order", function()
	local rng = Random.new(7)
	local roster = Threat.Roster("SettlingIn")
	for _, budget in { 6, 20, 45 } do
		local groups = Threat.Groups(budget, roster, rng)
		expect(#groups > 0, `something to spend {budget} on`)
		expect(Threat.Cost(groups) <= budget, `{budget}: spent {Threat.Cost(groups)}`)
		for _, group in groups do
			local monster = Config.Get("Monsters", group.Type)
			expect(group.Count >= 1 and group.Count <= monster.Group.Max, `{group.Type} x{group.Count} within its group size`)
		end
	end
	expectEqual(#Threat.Groups(0.5, roster, rng), 0, "too little for anything")
	local hits = { Lit = 0, Dark = 0 }
	for _ = 1, 3000 do
		local point = Threat.Pick({ { Id = "Lit", Weight = 1 }, { Id = "Dark", Weight = 2 } }, rng)
		if point then
			hits[point.Id] += 1
		end
	end
	expect(hits.Dark > hits.Lit * 1.7 and hits.Dark < hits.Lit * 2.3, `dark rooms twice as often ({hits.Dark} to {hits.Lit})`)
	expectEqual(Threat.Choose({ "Residents", "Machines", "Players" }, { Machines = true, Players = true }), "Machines",
		"residents first, then machines")
	expectEqual(Threat.Choose({ "Machines", "Residents", "Players" }, { Residents = true, Machines = true }), "Machines",
		"the Hollow Miner goes for machines first")
	expectEqual(Threat.Choose({ "Residents" }, {}), nil, "nothing to go for")
end)

test("Animations: every Mines monster and the Brood Mother have their clips (A4)", function()
	local have: { [string]: boolean } = {}
	for _, clip in all("Animations") do
		expect(not have[clip.Rig .. ":" .. clip.Activity], `one {clip.Activity} clip for {clip.Rig}`)
		have[clip.Rig .. ":" .. clip.Activity] = true
	end
	for _, monster in all("Monsters") do
		if table.find(monster.Where, "Mines") then
			local rig = string.gsub(monster.Asset, "^Monster_", "")
			for _, activity in { "Walk", "Attack" } do
				expect(have[rig .. ":" .. activity], `{monster.Id}: a {activity} clip for rig {rig}`)
			end
		end
	end
	for _, activity in { "Idle", "Walk", "Attack", "Roar", "LayEggs", "Stagger", "Death" } do
		expect(have["BroodMother:" .. activity], `the Brood Mother's {activity} clip`)
	end
end)

-- Disasters and repairs (Prompt 13) ---------------------------------------------------------

test("Disasters: fire grows, residents and Extinguishers put it out, damage scales (Section 10)", function()
	local f = Config.Get("Tuning", "Disasters").Fire
	local grown = Disasters.FireStep(40, 10, 0, 0)
	expect(math.abs(grown - (40 + f.GrowPerSecond * 10)) < 1e-9, `a fire left alone grows ({grown})`)
	expectEqual(Disasters.FireStep(99, 10, 0, 0), 100, "up to 100")
	local fought = Disasters.FireStep(40, 5, 2, 0)
	expect(math.abs(fought - (40 + (f.GrowPerSecond - 2 * f.ResidentPerSecond) * 5)) < 1e-9, `two residents beat it down ({fought})`)
	expectEqual(Disasters.FireStep(10, 1, 0, 30), 0, "an Extinguisher puts a small one out")
	local full = Disasters.FireRoomDamage(100, 1)
	expectEqual(full, Config.Get("Disasters", "Fire").RoomDamagePerSecond, "a full fire burns RoomDamagePerSecond")
	expectEqual(Disasters.FireRoomDamage(50, 2), full, "half the strength, twice as long")
	expect(math.abs(Disasters.FirePlayerDamage(100, 1, 0.25) - f.PlayerDamagePerSecond * 0.25) < 1e-9, "a Firefighter takes a quarter")
	expectEqual(Disasters.SpreadSeconds(), 15, "it spreads every 15 seconds (Section 10)")
	expectEqual(Disasters.SpreadSeconds(0.5), 30, "Sprinklers: 50% slower")
	expect(Disasters.CanSpread(f.SpreadMinStrength) and not Disasters.CanSpread(f.SpreadMinStrength - 1), "a weak fire doesn't spread")
end)

test("Disasters: fire spreads through doorways to rooms on its floor, never up the Shaft", function()
	local bunker = Bunker.FromStart()
	local kitchen = bunker:RoomAt(2, -2) :: any
	local purifier = bunker:RoomAt(2, -1) :: any
	local reactor = bunker:RoomAt(2, 1) :: any
	local medbay = bunker:RoomAt(2, 2) :: any
	expectEqual(Disasters.SpreadTargets(bunker, kitchen.Id, {}), { purifier.Id }, "the Kitchen's only neighbour")
	expectEqual(Disasters.SpreadTargets(bunker, purifier.Id, { [kitchen.Id] = true }), {}, "the Kitchen burns already; the Shaft doesn't burn")
	expectEqual(Disasters.SpreadTargets(bunker, reactor.Id, {}), { medbay.Id }, "the Reactor Core: the Medbay, not the Shaft")
	expect(not Disasters.Burns("Shaft") and Disasters.Burns("Kitchen") and Disasters.Burns("ReactorCore"), "the Shaft's bare steel")
end)

test("Disasters: a Surge's disaster is one Surges cause, of its era, within its budget (Section 5)", function()
	local rng = Random.new(3)
	local seen: { [string]: boolean } = {}
	for _ = 1, 200 do
		local id = Disasters.SurgePick(1, 100, rng)
		if id then
			seen[id] = true
		end
	end
	expect(seen.Fire and seen.Blackout, "Era I Surges bring fires and blackouts")
	for id in seen do
		expect(id == "Fire" or id == "Blackout", `only Era I Surge disasters ({id})`)
	end
	expectEqual(Disasters.SurgePick(1, 5, rng), nil, "nothing under the cheapest's ThreatCost")
	expectEqual(Disasters.SurgePick(1, 9, rng), "Blackout", "only the blackout fits 9")
	for _, d in all("Disasters") do
		local caused = string.find(d.CausedBy, "Surges") ~= nil
		expect(((d.SurgeWeight or 0) > 0) == caused, `{d.Id}: a Surge weight exactly when Surges cause it`)
	end
end)

test("Disasters: the meltdown's three valves (Section 10; Landon, 2026-11-08)", function()
	local m = Config.Get("Tuning", "Disasters").Meltdown
	expectEqual(Config.Get("Disasters", "ReactorOverload").TimerSeconds, 60, "a 60-second meltdown")
	expectEqual({ m.SoloPlayers, m.SoloValveSeconds }, { 2, 10 }, "1 or 2 players: each turned valve stays turned 10 s")
	local t0 = 1000
	local solo = { Disasters.ValveTurned(1, t0), Disasters.ValveTurned(1, t0 + 3), Disasters.ValveTurned(1, t0 + 6) }
	expectEqual(solo[1], t0 + m.SoloValveSeconds, "turned for 10 s")
	expect(Disasters.MeltdownStopped(solo, t0 + 6.5), "alone: three turned within 10 s stop it")
	expect(not Disasters.MeltdownStopped({ solo[1], solo[2], Disasters.ValveTurned(1, t0 + 12) }, t0 + 12.5), "the first ran out")
	expectEqual(Disasters.ValveReleased(solo[1], 1, t0 + 1), solo[1], "letting go alone doesn't close it")
	expect(Disasters.ValveTurned(2, t0) > t0, "two players: the same rule")
	local team = { Disasters.ValveTurned(3, t0), Disasters.ValveTurned(3, t0), 0 }
	expectEqual(team[1], Disasters.HELD, "three or more: a valve counts while it is held")
	expect(not Disasters.MeltdownStopped(team, t0), "two held, one open")
	team[3] = Disasters.ValveTurned(3, t0 + 1)
	expect(Disasters.MeltdownStopped(team, t0 + 1), "all three held at the same time")
	team[1] = Disasters.ValveReleased(team[1], 3, t0 + 1)
	expect(Disasters.MeltdownStopped(team, t0 + 1.2) == (m.HeldGraceSeconds > 0.2), "a let-go valve counts a moment (network slack)")
	expect(not Disasters.MeltdownStopped(team, t0 + 1 + m.HeldGraceSeconds + 0.1), "then it is open again")
	expectEqual(Disasters.ValveReleased(Disasters.HELD, 2, t0), t0 + m.SoloValveSeconds, "held, then the team shrinks to two: 10 s")
	expectEqual(Disasters.ValvesOn({ 0, Disasters.HELD, t0 + 5 }, t0), 2, "held and turned valves count")
end)

test("Disasters: blackouts, cave-ins and repairs (Sections 6 and 10)", function()
	local bunker = Bunker.FromStart()
	local floor2 = Disasters.BlackoutUnits(bunker, 2)
	for unit in floor2 do
		expectEqual(bunker:CellsOf(unit)[1][1], 2, `{unit} is on floor 2`)
	end
	expect(floor2[(bunker:RoomAt(2, 1) :: any).Id] and floor2["D:2,3"], "the floor's rooms and tunnels")
	local whole = 0
	for _ in Disasters.BlackoutUnits(bunker, nil) do
		whole += 1
	end
	expectEqual(whole, #bunker:Units(), "the whole grid")
	expectEqual(Disasters.BlackoutSeconds(), 60, "60 seconds")
	expectEqual(Disasters.BlackoutSeconds(0.5), 30, "Insulated Grid: half as long")
	local kitchen = bunker:RoomAt(2, -2) :: any
	local purifier = bunker:RoomAt(2, -1) :: any
	expectEqual(Disasters.RubbleEdges(bunker, "Doorway", 2, -2, "Right"), { { kitchen.Id, purifier.Id } }, "the Kitchen's doorway")
	expectEqual(#Disasters.RubbleEdges(bunker, "Doorway", 2, -2, "Left"), 0, "rock on the left: no doorway")
	expectEqual(#Disasters.RubbleEdges(bunker, "Tunnel", 2, 3, nil), 1, "the tunnel's one way in (from the Medbay)")
	expectEqual(#Disasters.RubbleEdges(bunker, "Tunnel", 2, 2, nil), 0, "a room isn't a tunnel")
	expectEqual(#Disasters.Doorways(bunker), 8, "the starting bunker's eight doorways")
	local c = Config.Get("Tuning", "Disasters").CaveIn
	expectEqual(Disasters.RubbleDamage("FireAxe", 30), 30 * c.BreakerMultiplier, "the Fire Axe breaks rubble")
	expectEqual(Disasters.RubbleDamage("Wrench", 14), 14, "a Wrench just hits it")
	expect(Disasters.CanDig({ "Wrench", "Drill" }) and Disasters.CanDig({ "Pickaxe" }) and not Disasters.CanDig({ "Wrench", "Welder" }),
		"a Drill or a Pickaxe digs")
	local r = Config.Get("Tuning", "Repairs")
	local perResident = Config.Get("Tuning", "Rooms").ResidentRepairPerSecond
	expectEqual(Disasters.WelderPerSecond(2), r.WelderPerSecond * 2, "the Engineer welds twice as fast")
	expectEqual(Disasters.ResidentRepairPerSecond(r.ResidentSmartsBase), perResident, "a resident of average Smarts")
	expectEqual(Disasters.ResidentRepairPerSecond(r.ResidentSmartsBase * 2), perResident * 2, "Smarts is repair speed (Section 11)")
end)

test("Bunker: a wrecked room works again once repaired to RepairedAt; HP modifiers (Prompt 13)", function()
	local bunker = Bunker.FromStart()
	local kitchen = bunker:RoomAt(2, -2) :: any
	expect(kitchen.Wrecked == false, "a new room works")
	bunker:SetHP(kitchen.Id, 0)
	expect(Bunker.IsWrecked(kitchen), "0 HP: wrecked")
	local at = Bunker.RepairedAt(kitchen.MaxHP)
	expectEqual(at, math.ceil(kitchen.MaxHP * Config.Get("Tuning", "Repairs").RepairedAt), "it works again at RepairedAt")
	bunker:SetHP(kitchen.Id, at - 1)
	expect(kitchen.Wrecked, "still wrecked just short of it")
	local balance = Economy.Balance(bunker, function(): any
		return nil
	end)
	expect(balance.Draw[kitchen.Id] == nil, "a wrecked room draws nothing while it is repaired")
	bunker:SetHP(kitchen.Id, at)
	expect(not kitchen.Wrecked, "repaired")
	bunker:SetHP(kitchen.Id, 1)
	expect(not kitchen.Wrecked, "damage short of 0 doesn't wreck it")
	local blast = bunker:RoomsOfType("BlastDoor")[1] :: any
	local before = blast.MaxHP
	bunker:SetHPScale("BlastDoor", 1.2)
	expectEqual(blast.MaxHP, math.floor(before * 1.2 + 0.5), "BlastDoorHealth +20%")
	bunker:SetHPScale("All", 1.25)
	expectEqual(blast.MaxHP, math.floor(Bunker.MaxHP(1, 2) * 1.25 * 1.2 + 0.5), "Reinforced Walls on top")
	expectEqual(bunker:MaxHPOf("Kitchen", 1, 1), math.floor(Bunker.MaxHP(1, 1) * 1.25 + 0.5), "new rooms get it too")
	local copy = Bunker.FromSnapshot({ ["2,-2"] = { Room = "R9" } }, { R9 = { Type = "Kitchen", Floor = 2, Column = -2, Span = 1,
		Level = 1, HP = 40, MaxHP = 500, Wrecked = true } })
	expect(Bunker.IsWrecked(copy:Room("R9")), "the client's copy knows a room is wrecked")
end)

test("Modifiers: class passives fold by unit (Prompt 13)", function()
	expectEqual(Modifiers.ClassValue("Firefighter", "ExtinguishSpeed"), 3, "the Firefighter puts out fires 3x faster")
	expectEqual(Modifiers.ClassValue("Firefighter", "FireFloodDamageTaken"), 0.25, "and takes a quarter of the damage")
	expectEqual(Modifiers.ClassValue("Engineer", "RepairSpeed"), 2, "the Engineer repairs twice as fast")
	expectEqual(Modifiers.ClassValue("Survivor", "RepairSpeed"), 1, "no modifier: 1")
	expectEqual(Modifiers.ClassValue("Firefighter", "FireSpread", 2), 0.5, "the Firefighter's level 2")
	expectEqual(Modifiers.ClassValue("Firefighter", "FireSpread", 1), 1, "not at level 1")
	expectEqual(Modifiers.ClassValue("Nobody", "RepairSpeed"), 1, "an unknown class")
end)

test("Disasters: rubble blocks passages; routes go round, or say Blocked (Run)", function()
	local lib = game:GetService("ServerScriptService"):FindFirstChild("Lib")
	local hazardsModule = lib and lib:FindFirstChild("Hazards")
	local pathModule = lib and lib:FindFirstChild("PathGraph")
	if not (hazardsModule and pathModule) then
		return -- the Lobby has no bunker
	end
	local Hazards = require(hazardsModule) :: any
	local PathGraph = require(pathModule) :: any
	local bunker = Bunker.FromStart()
	local kitchen = bunker:RoomAt(2, -2) :: any
	local purifier = bunker:RoomAt(2, -1) :: any
	local medbay = bunker:RoomAt(2, 2) :: any
	local ok, err = pcall(function()
		expect(PathGraph.Route(bunker, kitchen.Id, medbay.Id) ~= nil, "a way from the Kitchen to the Medbay")
		Hazards.Block(kitchen.Id, purifier.Id, "DataTest")
		expect(Hazards.Blocked(purifier.Id, kitchen.Id), "blocked both ways")
		expectEqual(PathGraph.Route(bunker, kitchen.Id, medbay.Id), nil, "the Kitchen's one doorway is blocked")
		expect(PathGraph.Blocked(bunker, kitchen.Id, medbay.Id), "rubble is the reason: a resident there is trapped")
		expect(PathGraph.Route(bunker, kitchen.Id, medbay.Id, true) ~= nil, "without the rubble there is a way")
		expect(PathGraph.Route(bunker, purifier.Id, medbay.Id) ~= nil, "the other side still gets about")
	end)
	Hazards.Unblock("DataTest")
	if not ok then
		error(err, 0)
	end
	expect(not Hazards.Blocked(kitchen.Id, purifier.Id), "cleared")
end)

-- Digging, Disturbance and loot (Prompt 14) ------------------------------------------------------

test("Dig: dig time by band, stacking, the Driller and the Drill Bay (Section 6)", function()
	expectEqual(Dig.Seconds(1), 20, "the Mines: 20 s a cell")
	expectEqual(Dig.Seconds(5), 30, "the Flooded Caverns: 30 s")
	expectEqual(Dig.Seconds(8), 45, "the Crystal Hollows: 45 s")
	expectEqual(Dig.Rate({ 1 }, 2), 1 / 20, "one player")
	expectEqual(Dig.Rate({ 1, 1 }, 2), 2 / 20, "two players on one cell stack")
	expectEqual(Dig.Rate({ Modifiers.ClassValue("Driller", "DigSpeed") or 1 }, 2), 2 / 20, "the Driller digs twice as fast")
	expectEqual(Dig.Rate({}, 2), 0, "nobody digging")
	local base = Config.Get("Rooms", "DrillBay").Output.Base
	expectEqual(Dig.DrillBaySpeed(base, base), Dig.Tuning().ResidentDigMultiplier, "a Drill Bay's unit of crew digs slowly")
	expectEqual(Dig.DrillBaySpeed(0, base), 0, "an idle Drill Bay doesn't dig")
	expect(Dig.CanDigWith({ "PocketPistol", "Drill" }), "a Drill digs")
	expect(Dig.CanDigWith({ "Pickaxe" }), "a Pickaxe digs")
	expect(not Dig.CanDigWith({ "Wrench", "Welder" }), "nothing else does")
	for _, id in Dig.Tuning().Tools do
		expect(Config.Find("Items", id) ~= nil, `dig tool {id} is an item`)
	end
end)

test("Dig: faces to dig from and Push Deeper's floors (Sections 6 and 8)", function()
	local bunker = Bunker.FromStart()
	local function sides(floor: number, column: number): string
		local list = {}
		for _, face in Dig.Faces(bunker, floor, column) do
			table.insert(list, face.Side)
		end
		table.sort(list)
		return table.concat(list, ",")
	end
	expectEqual(sides(1, 4), "Left", "beside the dug cell at the end of floor 1")
	expectEqual(sides(3, 0), "Above", "under the Shaft")
	expectEqual(sides(1, 0), "", "an open cell has nothing to dig")
	expectEqual(sides(3, 5), "", "deep in the rock: nothing beside or above it is open")
	local face = Dig.Faces(bunker, 1, 4)[1]
	local point = Dig.FacePoint(face, 1, 4)
	local wall = (Grid.CellPosition(1, 3).X + Grid.CellPosition(1, 4).X) / 2
	expectEqual(point.X, wall, "a side's prompt is on the wall line")
	expectEqual(Dig.StartLimit(), 3, "the Mines are open from the start")
	expect(not Dig.NeedsVote(3, 3), "floor 3 needs no vote")
	expect(Dig.NeedsVote(4, 3), "floor 4 opens the Flooded Caverns: a vote")
	expectEqual(Dig.LimitAfter(4), 6, "the vote opens the whole band")
	expectEqual(Dig.LimitAfter(7), 9, "and the Crystal Hollows")
	expectEqual(Dig.LimitAfter(10), 10, "and the Source Chamber")
	for _, floor in Dig.Tuning().PushDeeperFloors do
		expect(Grid.IsBandStart(floor), `floor {floor} starts a band`)
	end
	expectEqual(Dig.Depth(bunker, 1, 4, 2), 1, "one cell into the rock")
	expectEqual(Dig.Depth(bunker, 1, 5, 2), 2, "two cells in")
	expectEqual(Dig.Depth(bunker, 1, 6, 2), nil, "past the Driller's sight")
end)

test("Dig: a cell's roll is fixed for the run and keeps Section 6's odds", function()
	local available = { Empty = true, OrePocket = true, CaveOpening = true, Cache = true, Nest = true }
	expectEqual(Dig.Roll(77, 3, 1, 1, available), Dig.Roll(77, 3, 1, 1, available), "the same roll every time")
	local counts: { [string]: number } = {}
	local n = 0
	for seedValue = 1, 40 do
		for floor = 1, 10 do
			for column = -6, 6 do
				local result = Dig.Roll(seedValue * 7919, floor, column, 1, available)
				counts[result] = (counts[result] or 0) + 1
				n += 1
			end
		end
	end
	local function share(id: string): number
		return (counts[id] or 0) / n
	end
	expect(math.abs(share("OrePocket") - 0.20) < 0.04, `ore pockets near 20% (got {share("OrePocket")})`)
	expect(math.abs(share("CaveOpening") - 0.08) < 0.03, `cave openings near 8% (got {share("CaveOpening")})`)
	expect(math.abs(share("Cache") - 0.04) < 0.02, `caches near 4% (got {share("Cache")})`)
	expect(share("Nest") < 0.025, `nests rare (got {share("Nest")})`)
	expectEqual(counts.HazardPocket, nil, "hazard pockets wait for gas and floods (Prompt 23): Empty")
	expectEqual(counts.CryoPod, nil, "no cryo pods in Era I")
	expect(math.abs(share("Empty") - 0.67) < 0.05, `the rest is empty (got {share("Empty")})`)
	local withPods = table.clone(available)
	withPods.CryoPod = true
	local pods = 0
	for column = -6, 6 do
		for floor = 1, 10 do
			for seedValue = 1, 30 do
				if Dig.Roll(seedValue * 104729, floor, column, 2, withPods) == "CryoPod" then
					pods += 1
				end
			end
		end
	end
	expect(pods > 0, "cryo pods from Era II when their system exists")
	local hint = Dig.Hint(77, 3, 1, 1, available)
	expect(hint == nil or hint == "OrePocket" or hint == "CaveOpening", "the Driller sees ore and caves only")
end)

test("Dig: Disturbance's extra breach and Tremor (Section 10)", function()
	local t = Dig.DisturbanceTuning()
	expectEqual(Dig.AddDisturbance(98, 5), t.Max, "it tops out at 100")
	expectEqual(Dig.AddDisturbance(3, -10), 0, "and bottoms out at 0")
	local extra, tremor = Dig.Crossed(45, 50)
	expect(extra and not tremor, "reaching 50: an extra small breach")
	extra, tremor = Dig.Crossed(55, 60)
	expect(not extra and not tremor, "past 50 already: nothing new")
	extra, tremor = Dig.Crossed(95, 100)
	expect(tremor and not extra, "reaching 100: a Tremor")
	expectEqual(Dig.AfterTremor(), 40, "then it drops to 40")
	expectEqual(Dig.Level(0), "CALM", "the seismograph at rest")
	expectEqual(Dig.Level(30), "RISING", "rising")
	expectEqual(Dig.Level(60), "UNSETTLED", "past the extra breach")
	expectEqual(Dig.Level(90), "DANGER", "near a Tremor")
	expectEqual(Dig.Tuning().DisturbancePerCell, 5, "every dug cell adds 5")
	expectEqual(t.DecayPerCycle, 10, "it falls 10 a cycle")
	expectEqual(t.NestDestroyed, 20, "and 20 when a nest is destroyed")
	expectEqual(t.Explosive, 10, "explosives add 10")
end)

test("Loot: tables roll by weight, band ore and skipped specials (Prompt 14)", function()
	local rng = Random.new(5)
	for _ = 1, 20 do
		local drops = Loot.Roll("OrePocket", rng, { BandOre = "Iron" })
		expectEqual(#drops, 1, "an ore pocket gives one drop")
		expectEqual(drops[1].Resource, "Iron", "the band's ore")
		expect(drops[1].Count >= 8 and drops[1].Count <= 15, "8 to 15")
	end
	expectEqual(#Loot.Roll("OrePocket", rng, {}), 0, "no ore in a band without one")
	local boosted = Loot.Roll("OrePocket", Random.new(9), { BandOre = "Copper", OreMultiplier = 2 })
	local plain = Loot.Roll("OrePocket", Random.new(9), { BandOre = "Copper" })
	expectEqual(boosted[1].Count, math.floor(plain[1].Count * 2 + 0.5), "the Driller's DugOre scales the ore")
	local skip = { Gear = true, RadioLog = true }
	for _ = 1, 40 do
		for _, drop in Loot.Roll("Cache", rng, { BandOre = "Iron", Skip = skip }) do
			expect(drop.Special == nil, "skipped specials never drop")
			expect(drop.Resource ~= nil or drop.Item ~= nil, "a resource or an item")
		end
	end
	local nest = Loot.Roll("Nest", rng, { BandOre = "Iron" })
	expect(#nest >= 1, "a nest pays")
	expect(Loot.Text({ { Resource = "Scrap", Count = 62 }, { Item = "Flare", Count = 1 } }) == "62 SCRAP · 1 FLARE", "alert text")
	for _, id in Config.Ids("DigResults") do
		local entry = Config.Get("DigResults", id)
		if entry.Loot then
			expect(Config.Find("LootTables", entry.Loot) ~= nil, `{id}'s loot table exists`)
		end
	end
end)

test("Boss: the Brood Mother's health, phases and hits (Sections 5 and 22, Prompt 15)", function()
	expectEqual(Boss.Health("BroodMother", 1, false), 6000, "solo, not a first run")
	expectEqual(Boss.Health("BroodMother", 1, true), 4200, "an account's first run: 70%")
	expectEqual(Boss.Health("BroodMother", 4, false), 15000, "four players: x2.5 (Threat.PlayerScale)")
	expectEqual(Boss.Health("BroodMother", 9, false), 18000, "more than six counts as six")
	expectEqual(Boss.Health("Deluge", 1, true), 12000, "only an Era I boss is weaker on a first run")
	expectEqual(Boss.Phase("BroodMother", 1), 1, "full health: phase 1")
	expectEqual(Boss.Phase("BroodMother", 0.51), 1, "just over half: phase 1")
	expectEqual(Boss.Phase("BroodMother", 0.5), 2, "half lost: phase 2")
	expectEqual(Boss.Phase("BroodMother", 0), 2, "dead: still the last phase")
	expectEqual(Boss.Phase("Source", 0.74), 2, "a four-phase boss at 74%")
	expectEqual(Boss.Phase("Source", 0.25), 4, "and at a quarter")
	expectEqual(Boss.ByPhase({ 5, 7 }, 1), 5, "phase 1's value")
	expectEqual(Boss.ByPhase({ 5, 7 }, 3), 7, "the last value carries on")
	expectEqual(Boss.HitMultiplier(false), 0.25, "armour")
	expectEqual(Boss.HitMultiplier(true), 2, "the belly")
	expectEqual(Boss.HitMultiplier(true, 2.5), 2.5, "the Sharpshooter's weak-point hits")
	expectEqual(Boss.HitMultiplier(false, 2.5), 0.25, "but not on armour")
	local cf = CFrame.new(10, 5, -3) * CFrame.Angles(0, math.pi / 2, 0)
	local size = Vector3.new(4, 2, 6)
	expect(Boss.OnPart(cf.Position, cf, size, 0), "the part's middle to be on it")
	expect(not Boss.OnPart(cf:PointToWorldSpace(Vector3.new(2.5, 0, 0)), cf, size, 0), "half a stud past its side to miss")
	expect(Boss.OnPart(cf:PointToWorldSpace(Vector3.new(2.5, 0, 0)), cf, size, 1), "the tolerance to catch it")
	expect(Boss.OnPart(cf:PointToWorldSpace(Vector3.new(0, 0, 2.9)), cf, size, 0), "the box to turn with the part")
	local hits = { { At = 10, Amount = 100 }, { At = 12, Amount = 200 } }
	expect(Boss.Staggers(hits, 12.5, 3, 300), "300 inside 3 s to stagger")
	expect(not Boss.Staggers(hits, 13.5, 3, 300), "the first hit to be too old by then")
	local fight = Boss.Fight("BroodMother") :: any
	expect(fight ~= nil and fight.SlamDamage > 0, "her fight's numbers")
	local phases = Config.Get("Bosses", "BroodMother").Phases
	for _, key in { "MoveSpeed", "AttackSeconds", "LaySeconds", "SacsPerLay" } do
		expectEqual(#fight[key], phases, `{key}: one value per phase`)
	end
	expectEqual(Boss.Fight("Deluge"), nil, "no fight yet for the Era II boss")
end)

test("Boss: the arena is the deepest tunnel, else a room, else a cell (Section 10)", function()
	local bunker = Bunker.FromStart()
	local arena = Boss.Arena(bunker) :: Boss.Arena
	expect(arena ~= nil, "the starting bunker to have one")
	expectEqual({ arena.Floor, arena.From, arena.To, arena.Kind }, { 2, 3, 3, "Tunnel" }, "floor 2's dug cell")
	expect(bunker:Dig(2, 4) and bunker:Dig(2, 5), "two more cells dug beside it")
	arena = Boss.Arena(bunker) :: Boss.Arena
	expectEqual({ arena.From, arena.To }, { 3, 5 }, "the run of three")
	expectEqual(Boss.ArenaMiddle(arena), 4, "she breaks in at its middle")
	local left, right = Boss.ArenaSpan(arena, 10)
	expectEqual(right - left, 2 * Grid.Pitch().X + Grid.Tuning().CellWidth - 20, "end wall to end wall, less the margins")
	expect(bunker:Dig(3, 3), "a cell dug a floor down")
	arena = Boss.Arena(bunker) :: Boss.Arena
	expectEqual({ arena.Floor, arena.From, arena.To }, { 3, 3, 3 }, "the deepest floor wins")
	left, right = Boss.ArenaSpan(arena, 20)
	expectEqual(left, right, "a margin wider than the cell pins her to its middle")
	local rooms = Bunker.new()
	for column = 0, 2 do
		rooms:Open(1, column)
	end
	expect(rooms:Place("Shaft", 1, 0, 1) and rooms:Place("Quarters", 1, 1, 2), "a Shaft and Quarters placed")
	arena = Boss.Arena(rooms) :: Boss.Arena
	expectEqual({ arena.Kind, arena.From, arena.To }, { "Room", 1, 2 }, "no tunnel: the widest room that isn't a Shaft")
	local shaftOnly = Bunker.new()
	shaftOnly:Open(1, 0)
	shaftOnly:Place("Shaft", 1, 0, 1)
	arena = Boss.Arena(shaftOnly) :: Boss.Arena
	expectEqual({ arena.Kind, arena.From }, { "Cell", 0 }, "only a Shaft: its cell")
	expectEqual(Boss.Arena(Bunker.new()), nil, "an empty grid: nowhere")
end)

test("Results: a run's Glowshards, line by line, paid once (Section 16, Prompt 15)", function()
	expectEqual(Results.BandsReached(2), 1, "the Mines from the start")
	expectEqual(Results.BandsReached(4), 2, "floor 4 opens the Flooded Caverns")
	expectEqual(Results.BandsReached(10), 4, "the Source Chamber")
	local century: Results.Run = {
		Year = 100, DeepestFloor = 6, Victory = "Century", Bosses = { "BroodMother", "Deluge", "CrystalColossus" }, Difficulty = "Normal",
	}
	local payout = Results.Payout(century, Results.EmptyLedger(), { FirstWinToday = false })
	expectEqual(payout.Total, 52, "25 for the years, 6 for two bands, 15 for the win and 6 for three bosses")
	expectEqual(#payout.Lines, 6, "a line each: years, bands, the win and each boss")
	expect(payout.Ledger.Bosses.Deluge == true and payout.Ledger.Years == 100, "the ledger to keep what was paid")
	expectEqual(Results.Payout(century, payout.Ledger, { FirstWinToday = false }).Total, 0, "the same run ending again pays nothing")
	local endless: Results.Run = { Year = 112, DeepestFloor = 7, Victory = "Century", Bosses = century.Bosses, Difficulty = "Normal" }
	expectEqual(Results.Payout(endless, payout.Ledger, { FirstWinToday = false }).Total, 6,
		"after Keep Going: 3 for twelve more years and 3 for a new band, no second win")
	expectEqual(Results.Payout(century, Results.EmptyLedger(), { FirstWinToday = true }).Total, 104, "the first win of the day doubles it")
	local quick: Results.Run = { Year = 3, DeepestFloor = 2, Bosses = {}, Difficulty = "Normal" }
	expectEqual(Results.Payout(quick, Results.EmptyLedger(), { FirstWinToday = true }).Total, 3,
		"a quick loss: the Mines' 3, no years yet, and no win to double")
	local hard: Results.Run = { Year = 40, DeepestFloor = 3, Bosses = { "BroodMother" }, Difficulty = "Hard" }
	local hardPayout = Results.Payout(hard, Results.EmptyLedger(), { FirstWinToday = false })
	expectEqual(hardPayout.Total, 23, "Hard: 15 times 1.5, rounded")
	expectEqual(hardPayout.Lines[#hardPayout.Lines].Amount, 8, "the difficulty's own line")
end)

test("Results: account experience, levels and the MVP (Sections 16 and 18)", function()
	expectEqual(Results.AccountXP(30, 0), 300, "10 a year")
	expectEqual(Results.AccountXP(30, 25), 50, "only the new years after Keep Going")
	expectEqual(Results.AccountXP(10, 20), 0, "never negative")
	expectEqual(Results.XPToNext(1), 200, "level 1 to 2")
	expectEqual(Results.XPToNext(2), 250, "each level 50 more")
	expectEqual({ Results.LevelUp(1, 0, 200) }, { 2, 0 }, "exactly one level")
	expectEqual({ Results.LevelUp(1, 150, 300) }, { 3, 0 }, "two levels at once")
	expectEqual({ Results.LevelUp(1, 0, 100) }, { 1, 100 }, "not yet")
	local top, xp = Results.LevelUp(99, 0, 10 ^ 9)
	expectEqual(top, 100, "it stops at the top level")
	expect(xp <= Results.XPToNext(100), "its experience capped")
	expectEqual(Results.Score({ Damage = 1000, Kills = 5 }), 150, "damage and kills")
	expectEqual(Results.Score({}), 0, "nothing done")
	expectEqual(Results.MVP({ [1] = { Kills = 3 }, [2] = { Kills = 5 } }), 2, "the higher score")
	expectEqual(Results.MVP({ [7] = { Kills = 2 }, [3] = { Kills = 2 } }), 3, "a tie: the lower user id")
	expectEqual(Results.MVP({ [1] = {} }), nil, "nobody scored")
	expectEqual(Results.Day(86400 * 3 + 5), 3, "the UTC day")
	expectEqual(Config.Get("Votes", "PlayAgain").Rule, "WholeTeamMajority", "Play Again: a whole-team vote")
end)

-- Remotes and constants ------------------------------------------------------------------

test("Remotes: every definition is complete", function()
	for name, definition in Remotes.Definitions do
		expect(string.find(name, "^%u%w*$"), `{name} to be PascalCase`)
		expect(definition.To == "Server" or definition.To == "Client", `{name}.To`)
		expect(type(definition.Doc) == "string" and #definition.Doc > 10, `{name}.Doc`)
		expect(definition.Place == nil or definition.Place == "Lobby" or definition.Place == "Run", `{name}.Place`)
		if definition.To == "Server" then
			expect(definition.Args ~= nil and definition.Rate ~= nil, `{name} to have Args and Rate`)
		end
	end
	expectEqual(Remotes.InPlace("SetReady"), Constants.PlaceKind() == "Run", "SetReady only in the Run place")
end)

test("Constants: this place knows what it is", function()
	local kind = Constants.PlaceKind()
	expect(kind == "Lobby" or kind == "Run", "Lobby or Run")
end)

-- Runner ---------------------------------------------------------------------------------

local DataTests = {}

function DataTests.Run(filter: string?): Report
	local began = os.clock()
	local report: Report = { Passed = 0, Failed = {}, Skipped = 0, Ms = 0 }
	for _, item in tests do
		if filter and not string.find(string.lower(item.Name), string.lower(filter), 1, true) then
			report.Skipped += 1
			continue
		end
		local done, ok, message = false, false, nil :: string?
		local thread = task.spawn(function()
			local success, err = xpcall(item.Run, debug.traceback)
			ok, message, done = success, if success then nil else tostring(err), true
		end)
		local waited = 0
		while not done and waited < TIMEOUT_SECONDS do
			waited += task.wait()
		end
		if not done then
			pcall(task.cancel, thread)
			table.insert(report.Failed, { Name = item.Name, Error = `timed out after {TIMEOUT_SECONDS} s` })
		elseif ok then
			report.Passed += 1
		else
			table.insert(report.Failed, { Name = item.Name, Error = message or "?" })
		end
	end
	report.Ms = (os.clock() - began) * 1000
	return report
end

function DataTests.Format(report: Report): string
	local filtered = if report.Skipped > 0 then `, {report.Skipped} filtered out` else ""
	local lines = {
		`DataTests: {report.Passed} passed, {#report.Failed} failed{filtered} ({string.format("%.0f", report.Ms)} ms)`,
	}
	for _, failure in report.Failed do
		local firstLine = string.split(failure.Error, "\n")[1]
		table.insert(lines, `  FAIL {failure.Name}: {firstLine}`)
	end
	return table.concat(lines, "\n")
end

function DataTests.Count(): number
	return #tests
end

return DataTests
