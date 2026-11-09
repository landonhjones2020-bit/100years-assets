--!strict
--[[
	ThreatDirector: the danger budget (bible Section 10). Run place only; Prompt 12.

	* The threat level rises with the year, the deepest floor, Disturbance, bunker size and
	  player count (Rules.Threat.Level, Tuning.Threat). It is published as RunState.Threat.
	* Each Surge gets a budget from the threat level (the first cycle's is the small tutorial
	  wave, Section 5; a first run's Era I is 30% easier, Section 22) and spends it on monster
	  groups from the era's roster (Rules.Threat.Groups), opened at weighted breach points
	  (BreachService), up to MaxBreachPointsPerSurge places, in waves WaveSpacingSeconds apart.
	  Boss Surges bring their boss instead (Prompt 15). A Normal or Endless Surge first pays for
	  its one disaster from the budget (Section 5; DisasterService:SurgeDisaster, Prompt 13); the
	  Tutorial Surge is a small wave with no disaster.
	* A Surge ends as soon as its last monster dies and its disaster is fixed (Section 5):
	  CycleClock:EndSurge. Monsters left when a Surge times out stay and keep fighting.
	* Between Surges it spends TrickleBudget a cycle on single monsters at weighted points (not in
	  the first cycle, so the tutorial day stays calm), and minor incidents (Section 10): each day
	  from the second may bring one electrical surge (Rules.Disasters.ElectricalChance by era, at a
	  random moment of the day, in a random room).
	* Disturbance (DigService, Prompt 14) calls ExtraBreach at 50 and Tremor at 100; a nest dug open
	  calls Burst.
	* At most 25 monsters are on the map at once: MonsterService queues the rest.

	API:
		ThreatDirector:Level(): number
		ThreatDirector:SpendSurge(kind?): number      -- the wave now (DevTools; Tremor)
		ThreatDirector:ExtraBreach(): boolean        -- Disturbance 50 (Section 10)
		ThreatDirector:Tremor(): number              -- Disturbance 100: a full wave at once
		ThreatDirector:Burst(fraction, at, tag): number -- Prompt 14: a nest's monsters, at once
		ThreatDirector:IsFirstRun(): boolean         -- Prompt 15: someone's first run (a weaker Brood Mother)
		ThreatDirector:SetDisasterCheck(fn)          -- replaces DisasterService:HoldsSurge (tests)
	Dev: threat, surge.wave.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Disasters = require(Shared.Rules.Disasters)
local Log = require(Shared.Utilities.Log)
local RunState = require(Shared.RunState)
local Threat = require(Shared.Rules.Threat)

local log = Log.new("ThreatDirector")

local ThreatDirector = {
	Name = "ThreatDirector",
	Dependencies = {
		"CycleClock", "RunDirector", "BunkerGrid", "SessionService", "ProfileService", "BreachService", "MonsterService",
		"DisasterService", "DevService",
	},
}

local clock: any = nil
local director: any = nil
local grid: any = nil
local session: any = nil
local profiles: any = nil
local breaches: any = nil
local monsters: any = nil
local disasters: any = nil
local dev: any = nil
local set: (string, any) -> () = function() end

local rng = Random.new()
local surge: { Tag: string, Expected: number, Spawned: number, WavesLeft: number, LastWaveAt: number }? = nil
local trickle = 0
local disasterActive: () -> boolean = function()
	return false
end

local function tuning(): { [string]: any }
	return Config.Get("Tuning", "Threat")
end

local function disturbance(): number
	local ok, value = pcall(RunState.Get, "Disturbance")
	return if ok and type(value) == "number" then value else 0
end

local function firstRunEraI(): boolean
	if Threat.EraNumber(clock:Era()) ~= 1 then
		return false
	end
	for _, player in session:ReadyPlayers() do
		local data = profiles:Get(player)
		if data and data.FirstRunDone == false then
			return true
		end
	end
	return false
end

-- Is this an account's first run for anyone in it (Section 22: Era I is 30% easier and the Brood
-- Mother weaker)? Unlike the Era I easing, true in any era (the Brood Mother can come in Year 27).
function ThreatDirector:IsFirstRun(): boolean
	for _, player in session:ReadyPlayers() do
		local data = profiles:Get(player)
		if data and data.FirstRunDone == false then
			return true
		end
	end
	return false
end

function ThreatDirector:Level(): number
	return Threat.Level({
		Year = clock:Year(),
		DeepestFloor = grid:DeepestFloor(),
		Disturbance = disturbance(),
		Rooms = #grid:Rooms(),
		Players = math.max(#session:ReadyPlayers(), 1),
	})
end

-- Opens groups at up to `places` weighted points, in waves `spacing` seconds apart.
local function spend(groups: { Threat.Group }, tag: string, places: number, spacing: number): number
	if #groups == 0 then
		return 0
	end
	local points = {}
	local taken: { [string]: boolean } = {}
	for _ = 1, math.max(1, places) do
		local point = breaches:Pick(rng, taken)
		if point then
			taken[point.Id] = true
			table.insert(points, point)
		end
	end
	if #points == 0 then
		log:Warn("no breach points: %d groups not spent", #groups)
		return 0
	end
	local waves = math.min(#groups, 4)
	local byWave: { { Threat.Group } } = {}
	for i, group in groups do
		local w = (i - 1) % waves + 1
		byWave[w] = byWave[w] or {}
		table.insert(byWave[w], group)
	end
	local total = 0
	for w, list in byWave do
		for _, group in list do
			total += group.Count
		end
		local point = points[(w - 1) % #points + 1]
		task.delay((w - 1) * spacing, function()
			breaches:Open(point.Id, list, tag)
			if surge and surge.Tag == tag then
				surge.WavesLeft -= 1
				surge.LastWaveAt = os.clock()
			end
		end)
	end
	return total
end

function ThreatDirector:SpendSurge(kind: string?): number
	local level = ThreatDirector:Level()
	local surgeKind = kind or clock:Surge() or "Normal"
	local budget = Threat.SurgeBudget(level, surgeKind, firstRunEraI())
	if budget <= 0 then
		return 0
	end
	-- Section 5: a Surge brings a breach wave and one disaster; the disaster is paid for first
	local disasterCost = 0
	if surgeKind == "Normal" or surgeKind == "Endless" then
		disasterCost = disasters:SurgeDisaster(budget, rng)
		budget -= disasterCost
	end
	local groups = Threat.Groups(budget, Threat.Roster(clock:Era()), rng)
	local tag = `Surge:{clock:Cycle()}`
	local waves = math.min(#groups, 4)
	surge = { Tag = tag, Expected = 0, Spawned = 0, WavesLeft = waves, LastWaveAt = os.clock() }
	local t = tuning()
	local total = spend(groups, tag, math.min(t.MaxBreachPointsPerSurge, waves), t.WaveSpacingSeconds)
	if surge and surge.Tag == tag then
		surge.Expected = total
	end
	log:Info("%s Surge (threat %.1f, budget %.1f after %d for its disaster): %d monsters in %d groups", surgeKind, level,
		budget, disasterCost, total, #groups)
	return total
end

-- Disturbance's breaches (Prompt 14) are priced like a normal Surge now, so the first run's Era I
-- is easier for them too: a quarter of one for the extra breach, a whole one for a Tremor.
function ThreatDirector:ExtraBreach(): boolean
	local budget = Threat.SurgeBudget(ThreatDirector:Level(), "Normal", firstRunEraI()) * 0.25
	local groups = Threat.Groups(budget, Threat.Roster(clock:Era()), rng)
	return spend(groups, "Extra", 1, 0) > 0
end

function ThreatDirector:Tremor(): number
	local budget = Threat.SurgeBudget(ThreatDirector:Level(), "Normal", firstRunEraI())
	local groups = Threat.Groups(budget, Threat.Roster(clock:Era()), rng)
	return spend(groups, "Tremor", tuning().MaxBreachPointsPerSurge, 0)
end

-- Monsters all at once at one spot, no warning (Prompt 14: a nest pours its monsters out when it is
-- dug open): `fraction` of what a normal Surge would spend now (so the first run's Era I is
-- easier here too), bought like any group.
function ThreatDirector:Burst(fraction: number, at: CFrame, tag: string): number
	local budget = Threat.SurgeBudget(ThreatDirector:Level(), "Normal", firstRunEraI()) * fraction
	local groups = Threat.Groups(budget, Threat.Roster(clock:Era()), rng)
	local n = 0
	for _, group in groups do
		for _ = 1, group.Count do
			local offset = CFrame.new(((n % 3) - 1) * 2.2, 0, -math.floor(n / 3) * 1.6)
			monsters:Spawn(group.Type, at * offset, tag)
			n += 1
		end
	end
	log:Info("burst of %d monsters (%s)", n, tag)
	return n
end

function ThreatDirector:SetDisasterCheck(fn: () -> boolean)
	disasterActive = fn
end

-- A Surge ends as soon as its last monster dies and its disaster is fixed (Section 5).
local function checkCleared()
	if not surge or clock:Phase() ~= "Surge" then
		return
	end
	local current = surge
	if current.WavesLeft > 0 then
		return
	end
	local spawnedAll = current.Spawned >= current.Expected or os.clock() - current.LastWaveAt > 25
	if spawnedAll and monsters:Count(current.Tag) == 0 and not disasterActive() then
		surge = nil
		if clock:EndSurge() then
			log:Info("%s cleared: the Surge ends", current.Tag)
		end
	end
end

local function cheapest(roster: { string }): (string?, number)
	local best, cost = nil, math.huge
	for _, id in roster do
		local monster = Config.Get("Monsters", id)
		if monster.ThreatCost < cost then
			best, cost = id, monster.ThreatCost
		end
	end
	return best, cost
end

-- Between Surges: small spends on single monsters (Section 10).
local function trickleTick(dt: number)
	if clock:Phase() ~= "Day" or clock:Cycle() <= 1 or director:Phase() ~= "Playing" then
		return
	end
	local cycleSeconds = 270 / math.max(clock:TimeScale(), 0.01)
	trickle += Threat.TrickleBudget(ThreatDirector:Level(), firstRunEraI()) * dt / cycleSeconds
	local roster = Threat.Roster(clock:Era())
	local _, cost = cheapest(roster)
	if trickle < cost then
		return
	end
	local affordable = {}
	for _, id in roster do
		if Config.Get("Monsters", id).ThreatCost <= trickle then
			table.insert(affordable, id)
		end
	end
	local id = affordable[rng:NextInteger(1, #affordable)]
	trickle -= Config.Get("Monsters", id).ThreatCost
	spend({ { Type = id, Count = 1 } }, "Trickle", 1, 0)
end

function ThreatDirector:Init(registry)
	clock = registry.CycleClock
	director = registry.RunDirector
	grid = registry.BunkerGrid
	session = registry.SessionService
	profiles = registry.ProfileService
	breaches = registry.BreachService
	monsters = registry.MonsterService
	disasters = registry.DisasterService
	disasterActive = function(): boolean
		return disasters:HoldsSurge()
	end
	dev = registry.DevService
	set = RunState.Writer("ThreatDirector")

	dev:Register("threat", {
		Description = "The threat level, its inputs, the Surge's wave and the monsters (Prompt 12).",
		Usage = "threat",
		Run = function(): string?
			local level = ThreatDirector:Level()
			local lines = {
				string.format("threat %.1f: year %d, deepest floor %d, Disturbance %d, %d rooms, %d players",
					level, clock:Year(), grid:DeepestFloor(), disturbance(), #grid:Rooms(), math.max(#session:ReadyPlayers(), 1)),
				string.format("Surge budget %.1f (%s), between Surges %.1f a cycle (saved %.2f); first-run Era I: %s",
					Threat.SurgeBudget(level, clock:Surge() or "Normal", firstRunEraI()), tostring(clock:Surge()),
					Threat.TrickleBudget(level, firstRunEraI()), trickle, tostring(firstRunEraI())),
				`roster: {table.concat(Threat.Roster(clock:Era()), ", ")}`,
				if surge then `this Surge ({surge.Tag}): {surge.Spawned}/{surge.Expected} out, {surge.WavesLeft} waves to come, {monsters:Count(surge.Tag)} alive or queued` else "no Surge wave running",
				`monsters: {monsters:Count()} ({monsters:Queued()} queued)`,
			}
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("surge.wave", {
		Description = "Spend a Surge's budget now (Normal unless a kind is given).",
		Usage = "surge.wave [Tutorial|Normal]",
		Run = function(_player, args): string?
			local total = ThreatDirector:SpendSurge(if args[1] then tostring(args[1]) else "Normal")
			return `{total} monsters coming`
		end,
	})
end

function ThreatDirector:Start()
	clock.SurgeStarted:Connect(function(kind: string)
		if director:Phase() ~= "Playing" then
			return
		end
		task.spawn(function()
			ThreatDirector:SpendSurge(kind)
		end)
	end)
	clock.SurgeEnded:Connect(function()
		surge = nil
	end)
	-- minor incidents (Section 10): an electrical surge on some days, in a random room
	clock.CycleStarted:Connect(function(cycle: number)
		if cycle <= 1 or director:Phase() ~= "Playing" then
			return
		end
		local era = Threat.EraNumber(clock:Era())
		if rng:NextNumber() >= Disasters.ElectricalChance(era) then
			return
		end
		local dayScale = math.max(clock:TimeScale(), 0.01)
		task.delay(rng:NextNumber(25, 150) / dayScale, function()
			if clock:Phase() ~= "Day" or director:Phase() ~= "Playing" then
				return
			end
			local options = {}
			for _, room in grid:Rooms() do
				if room.Type ~= "Shaft" and not room.Wrecked then
					table.insert(options, room.Id)
				end
			end
			if #options > 0 then
				disasters:StartElectricalSurge(options[rng:NextInteger(1, #options)], "Incident")
			end
		end)
	end)
	monsters.Spawned:Connect(function(_id: string, _type: string, tag: string?)
		if surge and tag == surge.Tag then
			surge.Spawned += 1
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local dt = os.clock() - last
			last = os.clock()
			pcall(checkCleared)
			pcall(trickleTick, dt)
			pcall(function()
				set("Threat", math.floor(ThreatDirector:Level() + 0.5))
				set("Monsters", monsters:Count())
			end)
		end
	end)
	log:Info("threat director ready")
end

return ThreatDirector
