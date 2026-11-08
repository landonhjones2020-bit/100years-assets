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
local Construction = require(Shared.Rules.Construction)
local Votes = require(Shared.Rules.Votes)
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
