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
local Signal = require(Shared.Utilities.Signal)
local TableUtil = require(Shared.Utilities.TableUtil)
local Trove = require(Shared.Utilities.Trove)

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

-- Remotes and constants ------------------------------------------------------------------

test("Remotes: every definition is complete", function()
	for name, definition in Remotes.Definitions do
		expect(string.find(name, "^%u%w*$"), `{name} to be PascalCase`)
		expect(definition.To == "Server" or definition.To == "Client", `{name}.To`)
		expect(type(definition.Doc) == "string" and #definition.Doc > 10, `{name}.Doc`)
		if definition.To == "Server" then
			expect(definition.Args ~= nil and definition.Rate ~= nil, `{name} to have Args and Rate`)
		end
	end
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
