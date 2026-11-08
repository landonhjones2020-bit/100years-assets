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
local Clock = require(Shared.Rules.Clock)
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

test("Content: the starting bunker matches bible Section 6", function()
	local start = Config.Get("Tuning", "StartingBunker")
	local grid = Config.Get("Tuning", "Grid")
	local taken: { [string]: boolean } = {}
	local shaftColumns: { [number]: number } = {}
	local roomsByFloor: { [number]: { string } } = { [1] = {}, [2] = {} }
	for _, cell in start.Cells do
		local span = cell.Span or 1
		for offset = 0, span - 1 do
			local column = cell.Column + offset
			local key = `{cell.Floor},{column}`
			expect(not taken[key], `cell {key} used once`)
			expect(column >= grid.ColumnMin and column <= grid.ColumnMax, `column {column} on the grid`)
			taken[key] = true
		end
		if cell.Room then
			local room = Config.Get("Rooms", cell.Room)
			expect(room.Unlock.Kind == "Start", `{cell.Room} to be a start room`)
			table.insert(roomsByFloor[cell.Floor], cell.Room)
			if cell.Room == "Shaft" then
				shaftColumns[cell.Floor] = cell.Column
			end
		end
	end
	expectEqual(roomsByFloor[1], { "BlastDoor", "Shaft", "Quarters" }, "floor 1 rooms")
	expectEqual(roomsByFloor[2], { "Kitchen", "WaterPurifier", "Shaft", "ReactorCore", "Medbay" }, "floor 2 rooms")
	expectEqual(shaftColumns[1], shaftColumns[2], "the shaft lines up on floors 1 and 2")
	expectEqual(start.Residents, 6, "starting residents")
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
	local owners = { RunDirector = true, CycleClock = true, ObjectiveService = true }
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
