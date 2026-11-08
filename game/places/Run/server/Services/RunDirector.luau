--!strict
--[[
	RunDirector: the run's lifecycle, how it ends, and Endless (bible Sections 4, 5 and 23;
	named so it never clashes with Roblox's RunService). Run place only.

		Waiting -> Intro -> Playing -> Ended (-> Playing again in Endless after Keep Going)

	* Waiting until the first player's session is ready (Prompt 21 adds waiting for the
	  party list the lobby writes to MemoryStore).
	* Intro: 30 seconds. The run clock starts at the 30-second mark for everyone, so a player
	  who skips the cutscene (personal, from 2 seconds in, Prompt 22) gains nothing.
	* Playing: CycleClock runs the cycles.
	* Victory: Century (the final Surge survived; CycleClock reports it) or Deep (the Source
	  destroyed in its chamber at depth 10; Prompt 25 calls Win("Deep")). After a victory the
	  team can Keep Going (a vote, Prompt 8): the run carries on in Endless.
	* Defeat: the Reactor Core is destroyed or the last resident dies (the systems that own
	  them call Lose). Players dying never loses the run.
	* The results screen (Prompt 15) reads Summary(); Play Again and Return to Lobby are
	  Prompt 21.

	API:
		RunDirector:Phase(): RunPhase
		RunDirector:Win(kind: "Century" | "Deep"): boolean
		RunDirector:Lose(reason: "ReactorDestroyed" | "ResidentsLost"): boolean
		RunDirector:KeepGoing(): boolean
		RunDirector:Summary(): Summary
		RunDirector.PhaseChanged: Signal<RunPhase, RunPhase>   -- new, old
		RunDirector.RunEnded: Signal<Summary>
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("RunDirector")
local IS_STUDIO = RunService:IsStudio()

export type RunPhase = RunState.RunPhase
export type VictoryKind = "Century" | "Deep"
export type DefeatReason = "ReactorDestroyed" | "ResidentsLost"
export type Summary = {
	Outcome: RunState.Outcome?,
	DefeatReason: DefeatReason?,
	Victory: VictoryKind?,
	Endless: boolean,
	Year: number,
	Cycle: number,
	Era: string,
	Difficulty: string,
	Seconds: number, -- played time, from the end of the intro
	Players: { number }, -- user ids of everyone who played in this run
}

local RunDirector = {
	Name = "RunDirector",
	Dependencies = { "SessionService", "CycleClock", "DevService" },
	PhaseChanged = Signal.new() :: Signal.Signal<RunPhase, RunPhase>,
	RunEnded = Signal.new() :: Signal.Signal<Summary>,
}

local session: any = nil
local clock: any = nil
local set: (string, any) -> () = function() end

local phase: RunPhase = "Waiting"
local difficulty = "Normal"
local outcome: RunState.Outcome? = nil
local defeatReason: DefeatReason? = nil
local victory: VictoryKind? = nil
local endless = false
local playingSince: number? = nil
local playedSeconds = 0
local played: { [number]: boolean } = {}

local function setPhase(new: RunPhase)
	local old = phase
	if old == new then
		return
	end
	phase = new
	set("RunPhase", new)
	log:Info("run: %s -> %s", old, new)
	RunDirector.PhaseChanged:Fire(new, old)
end

local function introSeconds(): number
	local devTools = ServerScriptService:FindFirstChild("DevTools")
	if IS_STUDIO and devTools and devTools:GetAttribute("SkipIntro") == true then
		return 0
	end
	return Config.Get("Tuning", "Clock").IntroSeconds
end

local function startPlaying()
	if phase ~= "Intro" then
		return
	end
	set("IntroEndsAt", nil)
	setPhase("Playing")
	playingSince = os.clock()
	clock:Begin()
end

local function startIntro()
	if phase ~= "Waiting" then
		return
	end
	local seconds = introSeconds()
	set("IntroEndsAt", workspace:GetServerTimeNow() + seconds)
	setPhase("Intro")
	task.delay(seconds, startPlaying)
end

local function finish(result: RunState.Outcome, reason: DefeatReason?)
	clock:Halt()
	outcome = result
	defeatReason = reason
	if playingSince then
		playedSeconds += os.clock() - playingSince
		playingSince = nil
	end
	set("Outcome", result)
	set("DefeatReason", reason)
	setPhase("Ended")
	local summary = RunDirector:Summary()
	log:Info("run over: %s %s in Year %d, cycle %d", result, reason or "", summary.Year, summary.Cycle)
	RunDirector.RunEnded:Fire(summary)
end

function RunDirector:Phase(): RunPhase
	return phase
end

-- A victory (Century: the final Surge survived; Deep: the Source destroyed in its chamber).
function RunDirector:Win(kind: VictoryKind): boolean
	assert(kind == "Century" or kind == "Deep", "RunDirector:Win takes Century or Deep")
	if phase ~= "Playing" or endless then
		return false
	end
	victory = kind
	set("Victory", kind)
	finish(if kind == "Century" then "CenturyVictory" else "DeepVictory", nil)
	return true
end

-- The bunker falls (the Reactor Core destroyed, or the last resident dead).
function RunDirector:Lose(reason: DefeatReason): boolean
	assert(reason == "ReactorDestroyed" or reason == "ResidentsLost", "RunDirector:Lose takes ReactorDestroyed or ResidentsLost")
	if phase ~= "Playing" then
		return false
	end
	finish("Defeat", reason)
	return true
end

-- Keep Going passed after a victory: the run carries on in Endless.
function RunDirector:KeepGoing(): boolean
	if phase ~= "Ended" or victory == nil or outcome == "Defeat" or endless then
		return false
	end
	endless = true
	outcome = nil
	set("Endless", true)
	set("Outcome", nil)
	clock:SetEndless(true)
	setPhase("Playing")
	playingSince = os.clock()
	clock:Resume()
	return true
end

function RunDirector:Summary(): Summary
	local ids = {}
	for userId in played do
		table.insert(ids, userId)
	end
	table.sort(ids)
	return {
		Outcome = outcome,
		DefeatReason = defeatReason,
		Victory = victory,
		Endless = endless,
		Year = clock:Year(),
		Cycle = clock:Cycle(),
		Era = clock:Era(),
		Difficulty = difficulty,
		Seconds = playedSeconds + (if playingSince then os.clock() - playingSince else 0),
		Players = ids,
	}
end

local function describe(): string
	local summary = RunDirector:Summary()
	local lines = { `run {phase}, {difficulty}, Year {summary.Year}, cycle {summary.Cycle}, played {string.format("%.0f", summary.Seconds)} s` }
	if phase == "Intro" then
		table.insert(lines, `intro: {string.format("%.1f", RunState.TimeLeft() or 0)} s left`)
	end
	if outcome then
		local reason = if defeatReason then ` ({defeatReason})` else ""
		table.insert(lines, `outcome: {outcome}{reason}`)
	end
	if victory then
		local now = if endless then ", now Endless" else ""
		table.insert(lines, `victory: {victory}{now}`)
	end
	table.insert(lines, `players: {#summary.Players}`)
	return table.concat(lines, "\n")
end

local function registerCommands(dev: any)
	dev:Register("run", {
		Description = "The run's phase, outcome and summary.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("run.skipintro", {
		Description = "End the intro now and start the clock.",
		Run = function(): string?
			if phase ~= "Intro" then
				return `no intro running (run is {phase})`
			end
			startPlaying()
			return describe()
		end,
	})
	dev:Register("run.win", {
		Description = "Win the run (Century or Deep).",
		Usage = "run.win <century|deep>",
		Run = function(_player, args): string?
			local word = string.lower(tostring(args[1] or ""))
			local kind: VictoryKind? = if word == "century" then "Century" elseif word == "deep" then "Deep" else nil
			if not kind then
				return "usage: run.win <century|deep>"
			end
			if not RunDirector:Win(kind) then
				local mode = if endless then ", Endless" else ""
				return `can't win now (run is {phase}{mode})`
			end
			return describe()
		end,
	})
	dev:Register("run.lose", {
		Description = "Lose the run (the Reactor Core destroyed, or the last resident dead).",
		Usage = "run.lose <reactor|residents>",
		Run = function(_player, args): string?
			local word = string.lower(tostring(args[1] or ""))
			local reason: DefeatReason? = if word == "reactor" then "ReactorDestroyed" elseif word == "residents" then "ResidentsLost" else nil
			if not reason then
				return "usage: run.lose <reactor|residents>"
			end
			if not RunDirector:Lose(reason) then
				return `can't lose now (run is {phase})`
			end
			return describe()
		end,
	})
	dev:Register("run.keepgoing", {
		Description = "Keep Going after a victory: carry on in Endless.",
		Run = function(): string?
			if not RunDirector:KeepGoing() then
				return `can't keep going (run is {phase}, outcome {tostring(outcome)})`
			end
			return describe()
		end,
	})
end

function RunDirector:Init(registry)
	session = registry.SessionService
	clock = registry.CycleClock
	set = RunState.Writer("RunDirector")
	set("RunPhase", phase)
	set("Difficulty", difficulty)
	set("Endless", false)
	registerCommands(registry.DevService)
end

function RunDirector:Start()
	clock.CenturySurvived:Connect(function()
		RunDirector:Win("Century")
	end)
	local function onReady(player: Player)
		played[player.UserId] = true
		startIntro()
	end
	session.PlayerReady:Connect(onReady)
	for _, player in session:ReadyPlayers() do
		onReady(player)
	end
end

return RunDirector
