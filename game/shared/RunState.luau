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
]]

local RunService = game:GetService("RunService")

export type RunPhase = "Waiting" | "Intro" | "Playing" | "Ended"
export type CyclePhase = "Day" | "Surge"
export type Outcome = "CenturyVictory" | "DeepVictory" | "Defeat"
export type Writer = "RunDirector" | "CycleClock" | "ObjectiveService"

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
	DefeatReason = { Type = "string", By = "RunDirector", Values = { "ReactorDestroyed", "ResidentsLost" }, Doc = "why the bunker fell (Defeat only)" },
	Victory = { Type = "string", By = "RunDirector", Values = { "Century", "Deep" }, Doc = "the victory this run won; kept through Endless" },
	Endless = { Type = "boolean", By = "RunDirector", Doc = "Keep Going passed: the run carries on past Year 100 with stronger Surges" },

	-- CycleClock: cycles, phases and the year counter
	Cycle = { Type = "number", By = "CycleClock", Doc = "the cycle number, from 1" },
	Year = { Type = "number", By = "CycleClock", Doc = "the year counter, from 1" },
	Era = { Type = "string", By = "CycleClock", Doc = "the era the year is in (Config.Eras)" },
	YearsPerCycle = { Type = "number", By = "CycleClock", Doc = "how far the year jumps at the end of this cycle" },
	CyclePhase = { Type = "string", By = "CycleClock", Values = { "Day", "Surge" }, Doc = "the phase of the cycle (from the first day on)" },
	PhaseLength = { Type = "number", By = "CycleClock", Doc = "seconds the current phase lasts in all" },
	PhaseEndsAt = { Type = "number", By = "CycleClock", Doc = "server time the phase ends; nil while the clock is stopped" },
	PhaseLeft = { Type = "number", By = "CycleClock", Doc = "seconds left, only while the clock is stopped" },
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
}

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
	assert(IS_SERVER, "RunState values are set on the server")
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
