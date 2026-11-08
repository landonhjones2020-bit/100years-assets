--!strict
--[[
	CycleClock: 4:30 cycles, day and Surge phases, the year counter, Years per Cycle and skips
	(bible Sections 5 and 23). Run place only.

	A cycle is a 3:00 day (building, digging, trips outside) then a 1:30 Surge (a breach wave
	below, a storm above, one disaster). The siren sounds 20 seconds before the Surge. A Surge
	ends when its time is up, or earlier when ThreatDirector calls EndSurge (its last monster
	died and its disaster is fixed). Then the year counter jumps by Years per Cycle and the
	next cycle starts. The arithmetic (Years per Cycle, era bosses, the final Surge, Endless)
	is Shared.Rules.Clock; the published values are Shared.RunState.

	Skips: when every player in the run has pressed Ready (the SetReady remote) or is resting
	in a Quarters bed (SetResting, called by the bed interaction), the day jumps to the siren.
	Ready resets at the siren and at the start of every day.

	RunDirector drives it: Begin when the intro ends, Halt on a victory or a defeat, Resume
	(after SetEndless) for Keep Going. When the final Surge ends the clock halts by itself,
	before the year jumps, and fires CenturySurvived.

	API:
		CycleClock.CycleStarted: Signal<number>              -- the cycle number (residents eat and drink)
		CycleClock.SirenStarted: Signal<SurgeKind, string?>  -- 20 s to the Surge: its kind and boss
		CycleClock.SurgeStarted: Signal<SurgeKind, string?>
		CycleClock.SurgeEnded: Signal<SurgeKind, string>     -- how: "Time" or "Cleared"
		CycleClock.YearChanged: Signal<number, number>       -- year, previous year (aging)
		CycleClock.EraChanged: Signal<string, string>        -- era, previous era
		CycleClock.CenturySurvived: Signal<()>
		CycleClock.Skipped: Signal<()>                       -- everyone was ready
		CycleClock:Begin(), :Halt(), :Resume(), :SetEndless(on)
		CycleClock:EndSurge(): boolean                       -- ThreatDirector: this Surge is cleared
		CycleClock:SetResting(player, on)                    -- a player lies down in or leaves a Quarters bed
		CycleClock:Phase(), :Year(), :Cycle(), :Era(), :YearsPerCycle(), :Surge(), :TimeLeft(), :IsRunning()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Clock = require(Shared.Rules.Clock)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("CycleClock")

export type CyclePhase = RunState.CyclePhase
export type SurgeKind = Clock.SurgeKind

local CycleClock = {
	Name = "CycleClock",
	Dependencies = { "SessionService", "ObjectiveService", "DevService" },
	CycleStarted = Signal.new() :: Signal.Signal<number>,
	SirenStarted = Signal.new() :: Signal.Signal<SurgeKind, string?>,
	SurgeStarted = Signal.new() :: Signal.Signal<SurgeKind, string?>,
	SurgeEnded = Signal.new() :: Signal.Signal<SurgeKind, string>,
	YearChanged = Signal.new() :: Signal.Signal<number, number>,
	EraChanged = Signal.new() :: Signal.Signal<string, string>,
	CenturySurvived = Signal.new() :: Signal.Signal<()>,
	Skipped = Signal.new() :: Signal.Signal<()>,
}

local MAX_TIME_SCALE = 100

local session: any = nil
local objectives: any = nil
local set: (string, any) -> () = function() end
local tuning: { [string]: any } = {}

local state: Clock.State = Clock.NewState()
local begun = false
local running = false -- the timers are live
local halted = false -- RunDirector stopped the clock (a victory or a defeat)
local devPaused = false -- DevTools paused it
local cycleEndPending = false -- stopped after the final Surge, before the year jumps
local phase: CyclePhase? = nil
local surgeKind: SurgeKind = "Tutorial"
local surgeBoss: string? = nil
local phaseLength = 0 -- seconds of clock time
local endsAt = 0 -- server time
local sirenAt: number? = nil -- server time; nil once the siren sounds, and during Surges
local siren = false
local leftWhenStopped = 0 -- clock seconds left in the phase when the clock stopped
local sirenInWhenStopped: number? = nil
local scale = 1
local ready: { [Player]: boolean } = {}
local resting: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Publishing ------------------------------------------------------------------------------

local function publishTimes()
	set("PhaseLength", phaseLength)
	if running then
		set("PhaseEndsAt", endsAt)
		set("PhaseLeft", nil)
	else
		set("PhaseEndsAt", nil)
		set("PhaseLeft", leftWhenStopped / scale)
	end
end

local function publishSurge()
	set("SurgeKind", surgeKind)
	set("SurgeBoss", surgeBoss)
end

local function publishYear()
	set("Cycle", state.Cycle)
	set("Year", state.Year)
	set("Era", Clock.EraOf(state.Year))
	set("YearsPerCycle", Clock.YearsPerCycle(state.Completed))
end

-- Ready and skips -------------------------------------------------------------------------

local startSiren: () -> ()
local skipToSiren: (why: string) -> ()

-- A skip is possible during a day, before the siren.
local function canSkip(): boolean
	return running and phase == "Day" and sirenAt ~= nil
end

local function countReady(leaving: Player?)
	local inRun = 0
	local count = 0
	for _, player in session:ReadyPlayers() do
		if player ~= leaving then
			inRun += 1
			if ready[player] or resting[player] then
				count += 1
			end
		end
	end
	set("ReadyCount", count)
	set("ReadyNeeded", inRun)
	if inRun > 0 and count == inRun and canSkip() then
		skipToSiren("everyone is ready")
	end
end

local function setReady(player: Player, on: boolean)
	if (ready[player] == true) == on then
		return
	end
	ready[player] = if on then true else nil
	player:SetAttribute("Ready", on)
	countReady()
end

local function clearReady()
	for player in ready do
		if player.Parent then
			player:SetAttribute("Ready", false)
		end
	end
	table.clear(ready)
end

-- The SetReady remote and DevTools: Ready only counts during a day, before the siren.
local function requestReady(player: Player, on: boolean): boolean
	if not session:IsReady(player) then
		return false
	end
	if on and not canSkip() then
		return false
	end
	setReady(player, on)
	return true
end

-- Phases ----------------------------------------------------------------------------------

startSiren = function()
	sirenAt = nil
	siren = true
	set("Siren", true)
	clearReady()
	countReady()
	log:Debug("cycle %d: siren (%s Surge)", state.Cycle, surgeKind)
	CycleClock.SirenStarted:Fire(surgeKind, surgeBoss)
end

skipToSiren = function(why: string)
	endsAt = now() + tuning.SurgeSirenSeconds / scale
	publishTimes()
	log:Info("cycle %d: %s; the day skips to the siren", state.Cycle, why)
	CycleClock.Skipped:Fire()
	startSiren()
end

local function startDay()
	phase = "Day"
	phaseLength = tuning.DaySeconds
	local t = now()
	endsAt = t + phaseLength / scale
	sirenAt = t + math.max(0, phaseLength - tuning.SurgeSirenSeconds) / scale
	siren = false
	surgeKind, surgeBoss = Clock.SurgeKind(state)
	clearReady()
	set("CyclePhase", "Day")
	set("Siren", false)
	publishSurge()
	publishTimes()
	log:Info("cycle %d, Year %d: day (next Surge: %s)", state.Cycle, state.Year, surgeKind)
	CycleClock.CycleStarted:Fire(state.Cycle)
	countReady()
end

local function startSurge()
	surgeKind, surgeBoss = Clock.StartSurge(state)
	phase = "Surge"
	phaseLength = tuning.SurgeSeconds
	endsAt = now() + phaseLength / scale
	sirenAt = nil
	siren = false
	clearReady()
	set("CyclePhase", "Surge")
	set("Siren", false)
	publishSurge()
	publishTimes()
	countReady()
	log:Info("cycle %d, Year %d: %s Surge %s", state.Cycle, state.Year, surgeKind, surgeBoss or "")
	CycleClock.SurgeStarted:Fire(surgeKind, surgeBoss)
end

local function endCycle()
	cycleEndPending = false
	local oldEra = Clock.EraOf(state.Year)
	local before, due = Clock.EndCycle(state)
	publishYear()
	if state.Year ~= before then
		CycleClock.YearChanged:Fire(state.Year, before)
	end
	local era = Clock.EraOf(state.Year)
	if era ~= oldEra then
		CycleClock.EraChanged:Fire(era, oldEra)
	end
	if due then
		log:Info("Year %d: %s comes at the next Surge", state.Year, due)
	end
	startDay()
end

local function freeze()
	if not running then
		return
	end
	local t = now()
	leftWhenStopped = math.max(0, endsAt - t) * scale
	sirenInWhenStopped = if sirenAt then math.max(0, sirenAt - t) * scale else nil
	running = false
	publishTimes()
end

local function thaw()
	if running or not begun or halted or devPaused then
		return
	end
	running = true
	if cycleEndPending then
		endCycle()
		return
	end
	local t = now()
	endsAt = t + leftWhenStopped / scale
	sirenAt = if sirenInWhenStopped then t + sirenInWhenStopped / scale else nil
	publishTimes()
	countReady()
end

local function endSurge(how: string)
	local kind = surgeKind
	log:Info("cycle %d: %s Surge over (%s)", state.Cycle, kind, how)
	cycleEndPending = true -- the year jumps next; if the clock stops first, Resume does it
	CycleClock.SurgeEnded:Fire(kind, how)
	if kind == "Final" then
		-- The century is over. Hold before the year jumps until RunDirector decides: a
		-- Century Victory, and Keep Going resumes the clock into Endless.
		if running then
			halted = true
			freeze()
			CycleClock.CenturySurvived:Fire()
		end
		return
	end
	if running then
		endCycle()
	end
end

local function tick()
	if not running then
		return
	end
	local t = now()
	if sirenAt and t >= sirenAt then
		startSiren()
	end
	if running and t >= endsAt then
		if phase == "Day" then
			startSurge()
		elseif phase == "Surge" then
			endSurge("Time")
		end
	end
end

local function setScale(value: number)
	local wasRunning = running
	if wasRunning then
		freeze()
	end
	scale = value
	if wasRunning then
		thaw()
	else
		publishTimes()
	end
	set("TimeScale", if scale == 1 then nil else scale)
end

-- API -------------------------------------------------------------------------------------

-- RunDirector: the intro is over; cycle 1 starts.
function CycleClock:Begin()
	if begun then
		return
	end
	begun = true
	running = true
	state.Completed = objectives:Completed()
	publishYear()
	startDay()
	if devPaused or halted then
		freeze()
	end
end

-- RunDirector: stop the clock (a victory or a defeat).
function CycleClock:Halt()
	halted = true
	freeze()
end

-- RunDirector: carry on after a Halt (Keep Going).
function CycleClock:Resume()
	if not halted then
		return
	end
	halted = false
	thaw()
end

-- RunDirector: Endless mode (no year cap, no more era bosses, Endless Surges).
function CycleClock:SetEndless(on: boolean)
	state.Endless = on
	if phase == "Day" then
		surgeKind, surgeBoss = Clock.SurgeKind(state)
		publishSurge()
	end
end

-- ThreatDirector: the Surge's last monster died and its disaster is fixed.
function CycleClock:EndSurge(): boolean
	if not running or phase ~= "Surge" then
		return false
	end
	endSurge("Cleared")
	return true
end

-- The bed interaction: a player lies down in (or gets out of) a Quarters bed.
function CycleClock:SetResting(player: Player, on: boolean)
	if (resting[player] == true) == on then
		return
	end
	resting[player] = if on then true else nil
	player:SetAttribute("Resting", on)
	countReady()
end

function CycleClock:Phase(): CyclePhase?
	return phase
end

function CycleClock:Year(): number
	return state.Year
end

function CycleClock:Cycle(): number
	return state.Cycle
end

function CycleClock:Era(): string
	return Clock.EraOf(state.Year)
end

function CycleClock:YearsPerCycle(): number
	return Clock.YearsPerCycle(state.Completed)
end

-- The coming (during a day) or current Surge: its kind and boss.
function CycleClock:Surge(): (SurgeKind, string?)
	return surgeKind, surgeBoss
end

-- Real seconds left in the current phase.
function CycleClock:TimeLeft(): number
	if running then
		return math.max(0, endsAt - now())
	end
	return leftWhenStopped / scale
end

function CycleClock:IsRunning(): boolean
	return running
end

-- DevTools --------------------------------------------------------------------------------

local function describe(): string
	local endless = if state.Endless then ", Endless" else ""
	local lines = {
		`cycle {state.Cycle}, Year {state.Year} ({Clock.EraOf(state.Year)}), {Clock.YearsPerCycle(state.Completed)} years per cycle{endless}`,
	}
	if not begun then
		table.insert(lines, "not started: the clock starts when the intro ends")
	else
		local stopped = ""
		if not running then
			local why = {}
			if devPaused then
				table.insert(why, "paused")
			end
			if halted then
				table.insert(why, "halted")
			end
			stopped = ` (stopped: {table.concat(why, ", ")})`
		end
		local sirenText = if siren then ", siren" else ""
		table.insert(lines, `{phase} {string.format("%.1f", CycleClock:TimeLeft())} s left of {phaseLength} s{sirenText}{stopped}`)
		local which = if phase == "Surge" then "this" else "next"
		local bossText = if surgeBoss then ` ({surgeBoss})` else ""
		local dueText = if state.PendingBoss then `, due: {state.PendingBoss}` else ""
		table.insert(lines, `{which} Surge: {surgeKind}{bossText}{dueText}`)
	end
	table.insert(lines, `ready {RunState.Get("ReadyCount") or 0}/{RunState.Get("ReadyNeeded") or 0}`)
	if scale ~= 1 then
		table.insert(lines, `time scale {scale}`)
	end
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("clock", {
		Description = "The cycle clock: cycle, year, phase, time left, the coming Surge, ready count.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("clock.speed", {
		Description = "Run the clock faster or slower (1 is normal).",
		Usage = "clock.speed <0.1 to 100>",
		Run = function(_player, args): string?
			local value = tonumber(args[1])
			if not value or value < 0.1 or value > MAX_TIME_SCALE then
				return `usage: clock.speed <0.1 to {MAX_TIME_SCALE}>`
			end
			setScale(value)
			return describe()
		end,
	})
	dev:Register("clock.pause", {
		Description = "Pause the clock.",
		Run = function(): string?
			devPaused = true
			freeze()
			set("Paused", true)
			return describe()
		end,
	})
	dev:Register("clock.resume", {
		Description = "Resume a paused clock.",
		Run = function(): string?
			devPaused = false
			set("Paused", nil)
			thaw()
			return describe()
		end,
	})
	dev:Register("clock.next", {
		Description = "Jump to the next moment: day to siren, siren to Surge, Surge to the next cycle.",
		Run = function(): string?
			if not begun then
				return "the clock starts when the intro ends (run.skipintro)"
			elseif not running then
				return "the clock is stopped:\n" .. describe()
			end
			if phase == "Day" and sirenAt ~= nil then
				skipToSiren("DevTools")
			elseif phase == "Day" then
				startSurge()
			else
				endSurge("Time")
			end
			return describe()
		end,
	})
	dev:Register("clock.clear", {
		Description = "End the Surge as cleared (what ThreatDirector does when it is over).",
		Run = function(): string?
			if not CycleClock:EndSurge() then
				return "no running Surge to clear"
			end
			return describe()
		end,
	})
	dev:Register("year", {
		Description = "Set the year counter (bosses come only when a cycle's jump reaches an era's end).",
		Usage = "year <1 to 100, more in Endless>",
		Run = function(_player, args): string?
			local value = tonumber(args[1])
			local top = if state.Endless then 100000 else tuning.FinalYear
			if not value or value ~= math.floor(value) or value < 1 or value > top then
				return `usage: year <1 to {top}>`
			end
			local before = state.Year
			local oldEra = Clock.EraOf(before)
			state.Year = value
			publishYear()
			if phase == "Day" then
				surgeKind, surgeBoss = Clock.SurgeKind(state)
				publishSurge()
			end
			if value ~= before then
				CycleClock.YearChanged:Fire(value, before)
			end
			if Clock.EraOf(value) ~= oldEra then
				CycleClock.EraChanged:Fire(Clock.EraOf(value), oldEra)
			end
			return describe()
		end,
	})
	dev:Register("ready.all", {
		Description = "Set Ready for every player, as if each pressed the button.",
		Usage = "ready.all [true|false]",
		Run = function(_player, args): string?
			local on = args[1] ~= false
			for _, player in session:ReadyPlayers() do
				requestReady(player, on)
			end
			return describe()
		end,
	})
	dev:Register("rest.all", {
		Description = "Put every player in (or out of) a Quarters bed, as the bed interaction will.",
		Usage = "rest.all [true|false]",
		Run = function(_player, args): string?
			local on = args[1] ~= false
			for _, player in session:ReadyPlayers() do
				CycleClock:SetResting(player, on)
			end
			return describe()
		end,
	})
end

-- Lifecycle -------------------------------------------------------------------------------

function CycleClock:Init(registry)
	session = registry.SessionService
	objectives = registry.ObjectiveService
	set = RunState.Writer("CycleClock")
	tuning = Clock.Tuning()
	publishYear()
	set("ReadyCount", 0)
	set("ReadyNeeded", 0)

	Remotes.OnServer("SetReady", function(player: Player, on: boolean)
		requestReady(player, on)
	end)
	registerCommands(registry.DevService)
end

function CycleClock:Start()
	objectives.Changed:Connect(function()
		state.Completed = objectives:Completed()
		set("YearsPerCycle", Clock.YearsPerCycle(state.Completed))
	end)
	session.PlayerReady:Connect(function(player: Player)
		player:SetAttribute("Ready", false)
		player:SetAttribute("Resting", false)
		countReady()
	end)
	session.PlayerLeaving:Connect(function(player: Player)
		ready[player] = nil
		resting[player] = nil
		countReady(player)
	end)
	RunService.Heartbeat:Connect(tick)
end

return CycleClock
