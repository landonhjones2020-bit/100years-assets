--!strict
--[[
	RunState: the run's small values, replicated as attributes on this ModuleScript (bible
	Section 23: small values such as the year and the cycle phase replicate as attributes;
	collections go through the delta channel).

	One list of names, types, meanings and owners, like Remotes for events. Each value has
	one writer: the service that owns it gets a setter with RunState.Writer("CycleClock") and
	can only set its own values. Anything on either side reads with RunState.Get and
	RunState.Changed. In the Lobby nothing is set.

	Times are server time (workspace:GetServerTimeNow()), so every client counts down to the
	same moment; RunState.TimeLeft() does the sum.

	Players also carry two attributes the clock reads for skips (CycleClock writes them):
	Ready (pressed Ready this day) and Resting (lying in a Quarters bed).

	The stockpile (EconomyService): one value per stocked resource in Config.Resources (Food,
	Water, Scrap, Iron, Copper, Crystal, Medkits, Ammo), plus Research.
	Power (PowerService): PowerMade, PowerUsed, PowerNeeded and DarkRooms.
	Threat (ThreatDirector): Threat and Monsters.
	Disasters (DisasterService, Prompt 13): Fires, BlackoutRooms, Rubble, Meltdown, MeltdownEndsAt
	and ValvesTurned.
	Digging (DigService, Prompt 14): Disturbance, DigLimit, DigSeed, DigOverrides, TremorAt and Nests.
	The surface (SurfaceService, Prompt 16): Storm and StormAt. Players also carry Zone (Surface,
	Bunker or Deep), Radiation, ClearRad, PackUsed, PackSlots, Pack, Carrying and Riding attributes
	(SurfaceService and InventoryService).
	The Deep (DeepService, Prompt 17): Caves and CryoPods.
	Expeditions (ExpeditionService, Prompt 18): RadioWorks.
	Classes (Prompt 20): BuildCost (BuildService), LevelStat, BeaconUntil and BeaconBy (ClassService).
	Players also carry Class, ClassLevel and the ability's AbilityReadyAt, AbilityReadyCycle,
	AbilityUses, AbilityMax, AbilityOption, AbilityOptionReadyAt, AbilityActiveUntil and
	SteadyShots (ClassService).
]]

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

export type RunPhase = "Waiting" | "Intro" | "Playing" | "Ended"
export type CyclePhase = "Day" | "Surge"
export type Outcome = "CenturyVictory" | "DeepVictory" | "Defeat"
export type Writer = "RunDirector" | "CycleClock" | "ObjectiveService" | "EconomyService" | "PowerService" | "ThreatDirector"
	| "DisasterService" | "DigService" | "SurfaceService" | "DeepService" | "ExpeditionService" | "BuildService" | "ClassService"

type Field = {
	Type: "string" | "number" | "boolean",
	By: Writer,
	Values: { string }?,
	Doc: string,
}

local FIELDS: { [string]: Field } = {
	-- RunDirector: the run's lifecycle
	RunPhase = { Type = "string", By = "RunDirector", Values = { "Waiting", "Intro", "Playing", "Ended" }, Doc = "where the run is" },
	IntroEndsAt = { Type = "number", By = "RunDirector", Doc = "server time the intro ends and the run clock starts (Intro only)" },
	Difficulty = { Type = "string", By = "RunDirector", Doc = "Normal, Hard or Nightmare (Config.Difficulties)" },
	Outcome = { Type = "string", By = "RunDirector", Values = { "CenturyVictory", "DeepVictory", "Defeat" }, Doc = "how the run ended (Ended only)" },
	DefeatReason = { Type = "string", By = "RunDirector", Values = { "ReactorDestroyed", "ResidentsLost" }, Doc = "why the bunker fell (Defeat only): the Reactor Core melted down, or the last resident died" },
	Victory = { Type = "string", By = "RunDirector", Values = { "Century", "Deep" }, Doc = "the victory this run won; kept through Endless" },
	Endless = { Type = "boolean", By = "RunDirector", Doc = "Keep Going passed: the run carries on past Year 100 with stronger Surges" },

	-- CycleClock: cycles, phases and the year counter
	Cycle = { Type = "number", By = "CycleClock", Doc = "the cycle number, from 1" },
	Year = { Type = "number", By = "CycleClock", Doc = "the year counter, from 1" },
	Era = { Type = "string", By = "CycleClock", Doc = "the era the year is in (Config.Eras)" },
	YearsPerCycle = { Type = "number", By = "CycleClock", Doc = "how far the year jumps at the end of this cycle" },
	CyclePhase = { Type = "string", By = "CycleClock", Values = { "Day", "Surge" }, Doc = "the phase of the cycle (from the first day on)" },
	PhaseLength = { Type = "number", By = "CycleClock", Doc = "seconds the current phase lasts in all" },
	PhaseEndsAt = { Type = "number", By = "CycleClock", Doc = "server time the phase ends; nil while the clock is stopped or the phase has no timer" },
	PhaseLeft = { Type = "number", By = "CycleClock", Doc = "seconds left, only while the clock is stopped" },
	PhaseOpen = { Type = "boolean", By = "CycleClock", Doc = "the phase has no timer: a boss Surge lasts until its boss is beaten" },
	Siren = { Type = "boolean", By = "CycleClock", Doc = "the Surge siren is sounding: the last 20 seconds of a day" },
	SurgeKind = { Type = "string", By = "CycleClock", Values = { "Tutorial", "Normal", "Boss", "Final", "Endless" }, Doc = "the coming Surge (during a day) or the current one" },
	SurgeBoss = { Type = "string", By = "CycleClock", Doc = "the boss of a Boss or Final Surge (Config.Bosses)" },
	ReadyCount = { Type = "number", By = "CycleClock", Doc = "players ready to skip: Ready pressed, or resting in a Quarters bed" },
	ReadyNeeded = { Type = "number", By = "CycleClock", Doc = "players in the run; when all are ready, the day skips to the siren" },
	Paused = { Type = "boolean", By = "CycleClock", Doc = "DevTools paused the clock" },
	TimeScale = { Type = "number", By = "CycleClock", Doc = "DevTools time scale (nil means 1)" },

	-- ObjectiveService: what makes more years pass per cycle
	LostCrews = { Type = "number", By = "ObjectiveService", Doc = "Lost Crews rescued" },
	BossesBeaten = { Type = "number", By = "ObjectiveService", Doc = "era bosses beaten" },

	-- EconomyService: Lab research so far (the stock amounts are added below from Config.Resources)
	Research = { Type = "number", By = "EconomyService", Doc = "Lab research so far (level 3 upgrades need it)" },

	-- PowerService: the live power balance (Power is not a stock)
	PowerMade = { Type = "number", By = "PowerService", Doc = "power the Reactor Core and Generators make now" },
	PowerUsed = { Type = "number", By = "PowerService", Doc = "power the lit rooms draw" },
	PowerNeeded = { Type = "number", By = "PowerService", Doc = "power every room would draw" },
	DarkRooms = { Type = "number", By = "PowerService", Doc = "rooms dark for want of power" },
	-- ThreatDirector (Prompt 12): the danger now
	Threat = { Type = "number", By = "ThreatDirector", Doc = "the threat level (Section 10), rounded" },
	Monsters = { Type = "number", By = "ThreatDirector", Doc = "monsters on the map plus those queued at the cap" },

	-- DisasterService (Prompt 13): disasters now (the details are the Disasters collection)
	Fires = { Type = "number", By = "DisasterService", Doc = "rooms on fire" },
	BlackoutRooms = { Type = "number", By = "DisasterService", Doc = "rooms and tunnels dark in a blackout (0: none)" },
	Rubble = { Type = "number", By = "DisasterService", Doc = "piles of rubble blocking the way" },
	Meltdown = { Type = "boolean", By = "DisasterService", Doc = "the Reactor Core is melting down (Section 10)" },
	MeltdownEndsAt = { Type = "number", By = "DisasterService", Doc = "server time the meltdown loses the run (Meltdown only)" },
	ValvesTurned = { Type = "number", By = "DisasterService", Doc = "the meltdown valves turned now, 0 to 3 (Meltdown only)" },

	-- DigService (Prompt 14): Disturbance and digging
	Disturbance = { Type = "number", By = "DigService", Doc = "the Disturbance meter, 0 to 100 (Section 10): the HUD's seismograph" },
	DigLimit = { Type = "number", By = "DigService", Doc = "the deepest floor the team may dig without a Push Deeper vote (3, then 6, 9, 10)" },
	DigSeed = { Type = "number", By = "DigService", Doc = "the run's seed for what dug cells hold (Rules.Dig.Roll), so the Driller's hints match" },
	DigOverrides = { Type = "string", By = "DigService", Doc = "cells whose roll is fixed this run, \"3,-2=CaveOpening;...\" (Rules.Dig.DecodeOverrides; Prompt 17: the Lost Crews' caves)" },
	TremorAt = { Type = "number", By = "DigService", Doc = "server time of the last Tremor (clients shake the camera)" },
	Nests = { Type = "number", By = "DigService", Doc = "nests alive in the bunker" },

	-- SurfaceService (Prompt 16): the storm over Brightwater Ruins
	Storm = { Type = "boolean", By = "SurfaceService", Doc = "the storm is over the surface (every Surge, Section 12): radiation climbs fast, visibility drops, Ash Wraiths hunt" },
	StormAt = { Type = "number", By = "SurfaceService", Doc = "server time the next storm hits (the Surge siren's end), or the current one began" },

	-- DeepService (Prompt 17): the caves behind the grid and cryo pods
	Caves = { Type = "number", By = "DeepService", Doc = "caves open behind dug cells (Section 12)" },
	CryoPods = { Type = "number", By = "DeepService", Doc = "cryo pods hauled home and waiting for a Cryo Bay to thaw them (Section 6)" },

	-- ExpeditionService (Prompt 18): whether the bunker can hear a distress call
	RadioWorks = { Type = "boolean", By = "ExpeditionService", Doc = "a Radio Room is staffed and powered, so an expedition's distress call is heard (Landon, Prompt 18: unheard, the team is lost)" },

	-- Classes (Prompt 20)
	BuildCost = { Type = "number", By = "BuildService", Doc = "build and upgrade costs times this (the Quartermaster); nil is 1" },
	LevelStat = { Type = "string", By = "ClassService", Doc = "the stat residents raise when they level, a level 2 Warden's choice (Section 11); nil: their job's" },
	BeaconUntil = { Type = "number", By = "ClassService", Doc = "server time the Mad Scientist's Teleport Beacon stands until; nil: none" },
	BeaconBy = { Type = "string", By = "ClassService", Doc = "who placed the Teleport Beacon (their display name)" },
}

-- EconomyService: one value per stocked resource (Config.Resources, Kind "Stock"), its amount
-- in the team's stockpile. Power is a live balance, not a stock.
for _, id in Config.Ids("Resources") do
	local resource = Config.Get("Resources", id)
	if resource.Kind == "Stock" then
		assert(FIELDS[id] == nil, `RunState: the resource {id} clashes with a RunState value`)
		FIELDS[id] = { Type = "number", By = "EconomyService", Doc = `{resource.Name} in the stockpile` }
	end
end

for name, field in FIELDS do
	local values = field.Values
	if values then
		table.freeze(values)
	end
	table.freeze(field)
	assert(string.find(name, "^%u%w*$"), `RunState: {name} must be PascalCase`)
end
table.freeze(FIELDS)

local IS_SERVER = RunService:IsServer()

local RunState = {}

RunState.Fields = FIELDS

-- Is `value` allowed for `name`? (nil always is: it clears the value.)
function RunState.Check(name: string, value: any): (boolean, string?)
	local field = FIELDS[name]
	if not field then
		return false, `no RunState value {tostring(name)}`
	end
	if value == nil then
		return true
	end
	if type(value) ~= field.Type then
		return false, `{name} is a {field.Type}, got a {typeof(value)}`
	end
	if field.Type == "number" and (value ~= value or math.abs(value) == math.huge) then
		return false, `{name} must be a finite number`
	end
	if field.Values and not table.find(field.Values, value) then
		return false, `{name} can't be {tostring(value)}`
	end
	return true
end

-- Server: a setter for the values `writer` owns. Setting anything else is an error.
function RunState.Writer(writer: Writer): (name: string, value: any) -> ()
	return function(name: string, value: any)
		local field = FIELDS[name]
		if not field then
			error(`RunState: no value {tostring(name)}`, 2)
		end
		if field.By ~= writer then
			error(`RunState: {name} belongs to {field.By}, not {writer}`, 2)
		end
		local ok, why = RunState.Check(name, value)
		if not ok then
			error(`RunState: {why}`, 2)
		end
		if not IS_SERVER then
			error("RunState: values are set on the server", 2)
		end
		script:SetAttribute(name, value)
	end
end

function RunState.Get(name: string): any
	assert(FIELDS[name], `RunState: no value {tostring(name)}`)
	return script:GetAttribute(name)
end

function RunState.Changed(name: string): RBXScriptSignal
	assert(FIELDS[name], `RunState: no value {tostring(name)}`)
	return script:GetAttributeChangedSignal(name)
end

-- Every value that is set.
function RunState.All(): { [string]: any }
	local values = {}
	for name in FIELDS do
		values[name] = script:GetAttribute(name)
	end
	return values
end

-- Seconds left in the intro or the current cycle phase (nil when nothing is counting down).
function RunState.TimeLeft(): number?
	if script:GetAttribute("RunPhase") == "Intro" then
		local introEndsAt = script:GetAttribute("IntroEndsAt")
		if type(introEndsAt) == "number" then
			return math.max(0, introEndsAt - workspace:GetServerTimeNow())
		end
		return nil
	end
	local endsAt = script:GetAttribute("PhaseEndsAt")
	if type(endsAt) == "number" then
		return math.max(0, endsAt - workspace:GetServerTimeNow())
	end
	local left = script:GetAttribute("PhaseLeft")
	return if type(left) == "number" then left else nil
end

return table.freeze(RunState)
