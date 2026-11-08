--!strict
--[[
	ObjectiveService: the run's big objectives (bible Sections 5, 12 and 23): Lost Crews
	rescued and era bosses beaten. Each one done adds its YearsPerCycle (Config.Objectives:
	+2 a crew, +1 a boss) to Years per Cycle, which CycleClock reads. Run place only.

	Prompt 3 keeps the record. The systems that rescue crews (Prompts 16 and 17) and beat the
	bosses (Prompts 15, 23 and 24) call Complete or BossBeaten.

	API:
		ObjectiveService:Complete(objectiveId): boolean       -- false if unknown or already done
		ObjectiveService:BossBeaten(bossId): boolean          -- completes that boss's objective
		ObjectiveService:IsComplete(objectiveId): boolean
		ObjectiveService:Completed(): { [string]: boolean }   -- frozen copy
		ObjectiveService:Counts(): (number, number)           -- Lost Crews rescued, era bosses beaten
		ObjectiveService.Changed: Signal<string>              -- the objective just completed
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("ObjectiveService")

local ObjectiveService = {
	Name = "ObjectiveService",
	Dependencies = { "DevService" },
	Changed = Signal.new() :: Signal.Signal<string>,
}

local completed: { [string]: boolean } = {}
local snapshot: { [string]: boolean } = table.freeze({})
local set: ((string, any) -> ())? = nil

local function counts(): (number, number)
	local crews, bosses = 0, 0
	for id in completed do
		local objective = Config.Get("Objectives", id)
		if objective.Kind == "LostCrew" then
			crews += 1
		elseif objective.Kind == "Boss" then
			bosses += 1
		end
	end
	return crews, bosses
end

local function publish()
	local crews, bosses = counts()
	if set then
		set("LostCrews", crews)
		set("BossesBeaten", bosses)
	end
end

function ObjectiveService:Complete(objectiveId: string): boolean
	local objective = Config.Find("Objectives", objectiveId)
	if not objective then
		log:Warn("no objective %s", tostring(objectiveId))
		return false
	end
	if completed[objective.Id] then
		return false
	end
	completed[objective.Id] = true
	snapshot = table.freeze(table.clone(completed))
	publish()
	log:Info("%s done (+%d Years per Cycle)", objective.Name, objective.YearsPerCycle)
	ObjectiveService.Changed:Fire(objective.Id)
	return true
end

function ObjectiveService:BossBeaten(bossId: string): boolean
	for _, objective in Config.All("Objectives") do
		if objective.Kind == "Boss" and objective.Boss == bossId then
			return ObjectiveService:Complete(objective.Id)
		end
	end
	log:Warn("%s has no objective (the final boss ends the run instead)", tostring(bossId))
	return false
end

function ObjectiveService:IsComplete(objectiveId: string): boolean
	return completed[objectiveId] == true
end

function ObjectiveService:Completed(): { [string]: boolean }
	return snapshot
end

function ObjectiveService:Counts(): (number, number)
	return counts()
end

function ObjectiveService:Init(registry)
	set = RunState.Writer("ObjectiveService")
	publish()

	registry.DevService:Register("objectives", {
		Description = "List the run's objectives and which are done.",
		Run = function(): string?
			local lines = {}
			for _, objective in Config.All("Objectives") do
				local mark = if completed[objective.Id] then "done" else "    "
				table.insert(lines, `{mark} {objective.Id}: {objective.Name} (+{objective.YearsPerCycle})`)
			end
			local crews, bosses = counts()
			table.insert(lines, `Lost Crews {crews}, era bosses {bosses}`)
			return table.concat(lines, "\n")
		end,
	})
	registry.DevService:Register("objective", {
		Description = "Complete an objective (a Lost Crew rescued or an era boss beaten).",
		Usage = "objective <id>",
		Run = function(_player, args): string?
			local id = tostring(args[1] or "")
			if not Config.Find("Objectives", id) then
				return `no objective {id}; ids: {table.concat(Config.Ids("Objectives"), ", ")}`
			end
			if not ObjectiveService:Complete(id) then
				return `{id} was already done`
			end
			return `{id} done`
		end,
	})
end

return ObjectiveService
