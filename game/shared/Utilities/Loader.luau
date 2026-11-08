--!strict
--[[
	Loader: the declared-dependency lifecycle both bootstraps use (bible Section 23).

	Every ModuleScript in a folder returns a module table:

		local BunkerGrid = {
			Name = "BunkerGrid",                       -- must match the ModuleScript
			Dependencies = { "CycleClock", "DevService" },
		}
		function BunkerGrid:Init(registry)          -- wire up; don't start loops here
			self.Clock = registry.CycleClock         -- only declared dependencies resolve
		end
		function BunkerGrid:Start()                  -- runs once every Init has finished
		end
		return BunkerGrid

	Run orders modules so dependencies come first (ties alphabetical, so the order never
	changes between runs), calls every Init in that order, then starts every Start on its
	own thread. A module whose Init fails is reported, and anything depending on it is
	skipped rather than started half-wired.
]]

local Log = require(script.Parent.Log)

export type Module = {
	Name: string,
	Dependencies: { string }?,
	Init: ((self: any, registry: { [string]: any }) -> ())?,
	Start: ((self: any) -> ())?,
	[string]: any,
}

export type Report = {
	Order: { string },
	Failed: { [string]: string },
	Skipped: { [string]: string },
	InitMs: { [string]: number },
}

local SLOW_INIT_SECONDS = 0.5

local Loader = {}

-- Requires every ModuleScript directly inside `folder` and checks its shape.
function Loader.Collect(folder: Instance, kind: string): { [string]: Module }
	local modules: { [string]: Module } = {}
	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		local ok, result = pcall(require, child)
		if not ok then
			error(`{kind} {child.Name} failed to load: {result}`, 0)
		end
		if type(result) ~= "table" then
			error(`{kind} {child.Name} must return a table`, 0)
		end
		local module = result :: Module
		if module.Name ~= child.Name then
			error(`{kind} {child.Name} must have Name = "{child.Name}" (has {tostring(module.Name)})`, 0)
		end
		if module.Dependencies ~= nil then
			if type(module.Dependencies) ~= "table" then
				error(`{kind} {child.Name}: Dependencies must be a list of names`, 0)
			end
			for _, dependency in module.Dependencies :: { any } do
				if type(dependency) ~= "string" then
					error(`{kind} {child.Name}: Dependencies must be a list of names`, 0)
				end
			end
		end
		for _, method in { "Init", "Start" } do
			local value = module[method]
			if value ~= nil and type(value) ~= "function" then
				error(`{kind} {child.Name}: {method} must be a function`, 0)
			end
		end
		modules[child.Name] = module
	end
	return modules
end

-- Dependency order, or nil and the reason (a missing dependency or a cycle).
function Loader.Order(modules: { [string]: Module }): ({ string }?, string?)
	local names = {}
	for name in modules do
		table.insert(names, name)
	end
	table.sort(names)

	local waitingOn: { [string]: number } = {}
	local dependents: { [string]: { string } } = {}
	for _, name in names do
		waitingOn[name] = 0
		dependents[name] = {}
	end
	for _, name in names do
		for _, dependency in modules[name].Dependencies or {} do
			if modules[dependency] == nil then
				return nil, `{name} depends on {dependency}, which doesn't exist`
			end
			if dependency == name then
				return nil, `{name} depends on itself`
			end
			waitingOn[name] += 1
			table.insert(dependents[dependency], name)
		end
	end

	local ready = {}
	for _, name in names do
		if waitingOn[name] == 0 then
			table.insert(ready, name)
		end
	end
	local order = {}
	while #ready > 0 do
		table.sort(ready)
		local name = table.remove(ready, 1) :: string
		table.insert(order, name)
		for _, dependent in dependents[name] do
			waitingOn[dependent] -= 1
			if waitingOn[dependent] == 0 then
				table.insert(ready, dependent)
			end
		end
	end
	if #order == #names then
		return order, nil
	end

	-- Name a cycle: walk dependencies from any module still waiting until one repeats.
	local start: string? = nil
	for _, name in names do
		if waitingOn[name] > 0 then
			start = name
			break
		end
	end
	local path = {}
	local seen: { [string]: number } = {}
	local current = start :: string
	while seen[current] == nil do
		seen[current] = #path + 1
		table.insert(path, current)
		for _, dependency in modules[current].Dependencies or {} do
			if waitingOn[dependency] > 0 then
				current = dependency
				break
			end
		end
	end
	local cycle = table.move(path, seen[current], #path, 1, {})
	table.insert(cycle, current)
	return nil, `dependency cycle: {table.concat(cycle, " -> ")}`
end

-- A view of the modules that only resolves the ones `module` declared.
local function registryFor(module: Module, modules: { [string]: Module }): { [string]: any }
	local allowed: { [string]: boolean } = {}
	for _, dependency in module.Dependencies or {} do
		allowed[dependency] = true
	end
	return setmetatable({}, {
		__index = function(_, name: string)
			if allowed[name] then
				return modules[name]
			end
			error(`{module.Name}: {tostring(name)} is not in its Dependencies`, 2)
		end,
		__newindex = function()
			error(`{module.Name}: the registry is read-only`, 2)
		end,
	}) :: any
end

function Loader.Run(modules: { [string]: Module }, log: Log.Logger): Report
	local order, problem = Loader.Order(modules)
	if not order then
		error(`Loader: {problem}`, 0)
	end
	local report: Report = { Order = order, Failed = {}, Skipped = {}, InitMs = {} }

	local function blockedBy(module: Module): string?
		for _, dependency in module.Dependencies or {} do
			if report.Failed[dependency] or report.Skipped[dependency] then
				return dependency
			end
		end
		return nil
	end

	for _, name in order do
		local module = modules[name]
		local blocker = blockedBy(module)
		if blocker then
			report.Skipped[name] = `needs {blocker}`
			log:Error("%s skipped: it needs %s, which didn't start", name, blocker)
			continue
		end
		local init = module.Init
		if init then
			local began = os.clock()
			local ok, err = xpcall(init, debug.traceback, module, registryFor(module, modules))
			local seconds = os.clock() - began
			report.InitMs[name] = seconds * 1000
			if not ok then
				report.Failed[name] = tostring(err)
				log:Error("%s.Init failed: %s", name, tostring(err))
				continue
			end
			if seconds > SLOW_INIT_SECONDS then
				log:Warn("%s.Init took %.2f s; Init should only wire things up", name, seconds)
			end
		end
	end

	for _, name in order do
		if report.Failed[name] or report.Skipped[name] then
			continue
		end
		local module = modules[name]
		local start = module.Start
		if start then
			task.spawn(function()
				local ok, err = xpcall(start, debug.traceback, module)
				if not ok then
					log:Error("%s.Start failed: %s", name, tostring(err))
				end
			end)
		end
	end
	return report
end

return table.freeze(Loader)
