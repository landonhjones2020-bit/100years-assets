--!strict
--[[
	ObjectiveService: the run's big objectives (bible Sections 5, 12 and 23): Lost Crews
	rescued and era bosses beaten. Each one done adds its YearsPerCycle (Config.Objectives:
	+2 a crew, +1 a boss) to Years per Cycle, which CycleClock reads. Run place only.

	Prompt 3 keeps the record. The systems that rescue crews (Prompts 16 and 17) and beat the
	bosses (Prompts 15, 23 and 24) call Complete or BossBeaten. A boss's death is also what
	ends its Surge: boss Surges have no timer (Landon, Nov 8, 2026), so CycleClock listens to
	BossDefeated. The Source has no objective; beating it ends the final Surge (a Century
	Victory) or, in its chamber, wins the Deep Victory.

	API:
		ObjectiveService:Complete(objectiveId): boolean       -- false if unknown or already done
		ObjectiveService:BossBeaten(bossId): boolean          -- a boss died: its objective (if any), BossDefeated
		ObjectiveService:IsComplete(objectiveId): boolean
		ObjectiveService:Completed(): { [string]: boolean }   -- frozen copy
		ObjectiveService:Counts(): (number, number)           -- Lost Crews rescued, era bosses beaten
		ObjectiveService.Changed: Signal<string>              -- the objective just completed
		ObjectiveService:IsBossBeaten(bossId): boolean
		ObjectiveService.BossDefeated: Signal<string>         -- the boss just beaten (once per boss)
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
	BossDefeated = Signal.new() :: Signal.Signal<string>,
}

local completed: { [string]: boolean } = {}
local defeated: { [string]: boolean } = {} -- bosses beaten this run
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

local function complete(objective: { [string]: any }): boolean
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

-- A Lost Crew rescued, or an era boss beaten (which is BossBeaten for that boss).
function ObjectiveService:Complete(objectiveId: string): boolean
	local objective = Config.Find("Objectives", objectiveId)
	if not objective then
		log:Warn("no objective %s", tostring(objectiveId))
		return false
	end
	if objective.Kind == "Boss" and objective.Boss and not completed[objective.Id] then
		return ObjectiveService:BossBeaten(objective.Boss)
	end
	return complete(objective)
end

function ObjectiveService:BossBeaten(bossId: string): boolean
	if not Config.Find("Bosses", bossId) then
		log:Warn("no boss %s", tostring(bossId))
		return false
	end
	if defeated[bossId] then
		return false
	end
	defeated[bossId] = true
	for _, objective in Config.All("Objectives") do
		if objective.Kind == "Boss" and objective.Boss == bossId then
			complete(objective)
		end
	end
	log:Info("%s beaten", bossId)
	ObjectiveService.BossDefeated:Fire(bossId)
	return true
end

function ObjectiveService:IsBossBeaten(bossId: string): boolean
	return defeated[bossId] == true
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
