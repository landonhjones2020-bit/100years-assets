--!strict
--[[
	ResidentService: resident data, jobs, needs, morale, levels and death, phase 1 (bible Sections
	11 and 23). Run place only. The rules are Shared.Rules.Residents; walking and routines are
	ResidentBrain's.

	* The six founders (Tuning.StartingBunker: Common, levels 1 to 3) arrive idle when the run
	  starts (Landon, Nov 8, 2026): the players give them their jobs, and on a first run the
	  tutorial does (Prompt 31). Until someone works the Reactor Core the bunker is dark. When the
	  run starts, the team is told who is waiting for work.
	* Jobs: AssignResident (a room id, or "" for none) and AutoAssign come from players, with no
	  vote (Section 8). A room's crew goes to EconomyService (SetResidents), which works out
	  production and power. When a room goes, its workers move to the room standing in its cells
	  (a merge) if it has room, or go idle.
	* Every cycle, after the meal (EconomyService.Ate), each resident's needs move (Rules.Residents
	  .Cycle): rest with work and beds, the meal (the newest arrivals go hungry first when the
	  stockpile runs short; Landon, Nov 8, 2026), morale with job fit, dark job rooms and beds. Workers gain
	  XPPerWorkCycle; each level adds 1 to their job's stat. A staffed, lit Medbay heals the hurt.
	  Surviving a Surge gives everyone SurgeSurvivedMorale.
	* At 0 health a resident is down for DeathReviveSeconds: a player can revive them with a
	  Medkit from the stockpile (ReviveResident). Then they are gone for the run. When the last
	  one is gone, the run is lost (RunDirector, "ResidentsLost").
	* Trapped (Prompt 13): cave-in rubble cuts a resident off from where they need to be
	  (ResidentBrain says so). A trapped resident isn't in their room's crew until they are free.
	* Away (Prompt 18; Section 12: expeditions leave the map): ExpeditionService sends residents
	  out (SetAway). Away, they have no job, don't eat from the stockpile, don't work, rest or
	  lose morale in the bunker, and can't be hurt by anything in it; their expedition can wound
	  them (Wound: never below 1 health), teach them (GainXP), write in their log (Note) or lose
	  them (Lose: gone at once, no revive). Home again (SetAway off) they are Alive with no job.
	* Replication: the Residents collection, id -> { Name, First, Last, Age, Tier, Level, XP,
	  XPNext, Stats, Job, Health, MaxHealth, Rest, Morale, Mood, State, Hungry, Trapped, DownUntil,
	  Weapon, Sick, Irradiated, Quarantined }.
	* Conditions (Prompt 24): Sick (an Outbreak: contagious, works slowly, loses health each cycle
	  until the Medbay cures them; with no job they keep to a Quarters bed, which is quarantine) and
	  Irradiated (a radiation leak: loses health each cycle until a working Decon Room clears
	  them). DisasterService sets them (SetCondition); Section 11's other conditions are Prompt 26.
	* Classes (Prompt 20): experience is times the bunker's ResidentXP (the Warden); a level goes
	  into the stat a level 2 Warden picked (SetLevelStat), else their job's. Armed residents (a
	  Weapon; gear and how they get one are Prompt 26) answer the Warden's Rally Call.

	API:
		ResidentService:All(): { Resident }, :Get(id), :Workers(roomId)
		ResidentService:Assign(id, roomId?): (boolean, string?)
		ResidentService:AutoAssign(): number          -- residents given a job
		ResidentService:Hurt(id, amount, how), :Revive(id, player?): (boolean, string?)
		ResidentService:SetTrapped(id, on)              -- ResidentBrain (Prompt 13)
		ResidentService:Add(tier?, level?): string    -- a new resident (recruits, rescues; DevTools)
		ResidentService:Count(): number                -- residents in the run (not dead; the away too)
		ResidentService:SetAway(id, on, health?): (boolean, string?) -- an expedition sets out / comes home (Prompt 18)
		ResidentService:Wound(id, amount): number, :GainXP(id, xp), :Note(id, text), :Lose(id, how)
		ResidentService:AddLevels(n, why): number      -- every resident n levels up now (Prompt 19: Field Training)
		ResidentService:AddMorale(amount, why): number -- every resident's morale now (Prompt 19: Morale Broadcast)
		ResidentService:Heal(id, amount): number       -- Prompt 20: the Medic's touch, Triage Pulse, Hearty Meal
		ResidentService:SetModifier(source, "ResidentXP", value?) -- Prompt 20: the Warden's +20% experience
		ResidentService:SetLevelStat(stat?)            -- Prompt 20: a level 2 Warden picks the stat levels raise
		ResidentService:Arm(id, itemId?)               -- the weapon a resident carries (gear is Prompt 26; DevTools)
		ResidentService:SetCondition(id, "Sick" | "Irradiated", on, why?): boolean -- Prompt 24 (DisasterService)
		ResidentService:HasCondition(id, condition): boolean
		ResidentService.Changed: Signal<string>         -- a resident's data changed
		ResidentService.Assigned: Signal<string, string?> -- resident, room (first-run objective 1)
		ResidentService.Died: Signal<string, string>    -- resident, how
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("ResidentService")

type Resident = Residents.Resident

local ResidentService = {
	Name = "ResidentService",
	Dependencies = { "BunkerGrid", "EconomyService", "PowerService", "CycleClock", "RunDirector", "SessionService", "ReplicationService", "DevService" },
	Changed = Signal.new() :: Signal.Signal<string>,
	Assigned = Signal.new() :: Signal.Signal<string, string?>,
	Died = Signal.new() :: Signal.Signal<string, string>,
}

local grid: any = nil
local economy: any = nil
local power: any = nil
local clock: any = nil
local director: any = nil
local session: any = nil
local collection: any = nil
local rng = Random.new()
local residents: { [string]: Resident } = {}
local count = 0
local usedNames: { [string]: boolean } = {}
local downUntil: { [string]: number } = {}
local downHow: { [string]: string } = {}
local jobCells: { [string]: { number } } = {} -- room id -> { floor, column } of the rooms people work in

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function order(id: string): number
	return tonumber(string.match(id, "%d+")) or 0
end

local function sorted(): { Resident }
	local list = {}
	for _, resident in residents do
		table.insert(list, resident)
	end
	table.sort(list, function(a: Resident, b: Resident): boolean
		return order(a.Id) < order(b.Id)
	end)
	return list
end

local function logLine(resident: Resident, text: string)
	table.insert(resident.Log, `Year {RunState.Get("Year") or 1}: {text}`)
	if #resident.Log > 20 then
		table.remove(resident.Log, 1)
	end
end

local function publish(resident: Resident)
	local mood = Residents.MoraleState(resident.Morale)
	collection:Set(resident.Id, {
		Name = Residents.Name(resident),
		First = resident.First,
		Last = resident.Last,
		Age = resident.Age,
		Tier = resident.Tier,
		Level = resident.Level,
		XP = math.floor(resident.XP),
		XPNext = Residents.XPToLevel(resident.Level),
		Stats = table.clone(resident.Stats),
		Job = resident.Job,
		Health = math.floor(resident.Health + 0.5),
		MaxHealth = resident.MaxHealth,
		Rest = math.floor(resident.Rest + 0.5),
		Morale = math.floor(resident.Morale + 0.5),
		Mood = mood,
		State = resident.State,
		Hungry = resident.Hungry,
		Trapped = resident.Trapped == true,
		DownUntil = downUntil[resident.Id],
		Weapon = resident.Weapon,
		Sick = resident.Sick == true or nil,
		Irradiated = resident.Irradiated == true or nil,
		Quarantined = Residents.Quarantined(resident) or nil,
		Log = table.clone(resident.Log),
	})
	ResidentService.Changed:Fire(resident.Id)
end

-- Classes (Prompt 20) -----------------------------------------------------------------------------

local xpModifiers: { [string]: number } = {} -- source -> ResidentXP multiplier
local levelStat: string? = nil -- a level 2 Warden's pick (Section 11)

local function xpMultiplier(): number
	local value = 1
	for _, v in xpModifiers do
		value *= v
	end
	return value
end

function ResidentService:SetModifier(source: string, key: string, value: number?)
	assert(key == "ResidentXP", `ResidentService:SetModifier: {key} isn't a resident modifier`)
	xpModifiers[source] = value
end

function ResidentService:SetLevelStat(stat: string?)
	assert(stat == nil or Config.Find("Stats", stat), `ResidentService:SetLevelStat: no stat {tostring(stat)}`)
	levelStat = stat
end

function ResidentService:LevelStat(): string?
	return levelStat
end

-- Health back (never past their max; nobody down or away). Returns what it gave.
function ResidentService:Heal(id: string, amount: number): number
	local resident = residents[id]
	if not resident or resident.State ~= "Alive" or amount <= 0 or resident.Health >= resident.MaxHealth then
		return 0
	end
	local before = resident.Health
	resident.Health = math.min(resident.MaxHealth, resident.Health + amount)
	publish(resident)
	return resident.Health - before
end

-- Conditions (Prompt 24: Sick from an Outbreak, Irradiated from a radiation leak; the rest of
-- Section 11's conditions are Prompt 26). Returns true when it changed.
local CONDITIONS: { [string]: boolean } = { Sick = true, Irradiated = true }
function ResidentService:SetCondition(id: string, condition: string, on: boolean, why: string?): boolean
	local resident = residents[id]
	if not resident or not CONDITIONS[condition] or resident.State == "Dead" then
		return false
	end
	local record = resident :: any
	if (record[condition] == true) == on then
		return false
	end
	record[condition] = if on then true else nil
	if condition == "Sick" then
		if on then
			resident.Morale = math.clamp(resident.Morale + Config.Get("Tuning", "Disasters").Outbreak.MoraleNow, 0, 100)
			logLine(resident, `fell sick{if why then ` ({why})` else ""}`)
		else
			logLine(resident, `got over the sickness{if why then ` ({why})` else ""}`)
		end
		economy:RefreshCrew() -- the sick work slowly
	elseif on then
		logLine(resident, `was caught in the radiation{if why then ` ({why})` else ""}`)
	end
	publish(resident)
	log:Info("%s %s %s (%s)", Residents.Name(resident), if on then "is" else "is no longer", condition, why or "-")
	return true
end

function ResidentService:HasCondition(id: string, condition: string): boolean
	local resident = residents[id]
	return resident ~= nil and (resident :: any)[condition] == true
end

-- The weapon a resident carries (nil: none). Gear and how residents get it are Prompt 26; until
-- then DevTools arms them, to try the Warden's Rally Call.
function ResidentService:Arm(id: string, itemId: string?): boolean
	local resident = residents[id]
	if not resident or (itemId ~= nil and not Config.Find("Items", itemId)) then
		return false
	end
	resident.Weapon = itemId
	publish(resident)
	return true
end

-- Queries ------------------------------------------------------------------------------------------

function ResidentService:All(): { Resident }
	return sorted()
end

function ResidentService:Get(id: string): Resident?
	return residents[id]
end

function ResidentService:Workers(roomId: string): { Resident }
	local list = {}
	for _, resident in sorted() do
		if resident.Job == roomId and resident.State ~= "Dead" then
			table.insert(list, resident)
		end
	end
	return list
end

local function slotsFree(roomId: string, except: string?): number
	local room = grid:Room(roomId)
	if not room then
		return 0
	end
	local used = 0
	for _, resident in residents do
		if resident.Job == roomId and resident.State ~= "Dead" and resident.Id ~= except then
			used += 1
		end
	end
	return Residents.Slots(room.Type, room.Level, room.Span) - used
end

-- Jobs ---------------------------------------------------------------------------------------------

local function setJob(resident: Resident, roomId: string?)
	resident.Job = roomId
	if roomId then
		local room = grid:Room(roomId)
		if room then
			jobCells[roomId] = { room.Floor, room.Column }
		end
	end
	publish(resident)
	ResidentService.Assigned:Fire(resident.Id, roomId)
end

function ResidentService:Assign(id: string, roomId: string?): (boolean, string?)
	local resident = residents[id]
	if not resident or resident.State == "Dead" then
		return false, "That resident isn't in the bunker."
	end
	if resident.State == "Away" then
		return false, `{Residents.Name(resident)} is away on an expedition.`
	end
	if roomId == nil then
		if resident.Job then
			setJob(resident, nil)
			economy:RefreshCrew()
		end
		return true, nil
	end
	local room = grid:Room(roomId)
	if not room then
		return false, "That room isn't there any more."
	end
	if not Residents.JobStat(room.Type) then
		return false, `Nobody works in the {Config.Get("Rooms", room.Type).Name}.`
	end
	if resident.Job == roomId then
		return true, nil
	end
	if slotsFree(roomId, id) <= 0 then
		return false, `The {Config.Get("Rooms", room.Type).Name} is full.`
	end
	setJob(resident, roomId)
	log:Info("%s works in %s (%s) now", Residents.Name(resident), roomId, room.Type)
	economy:RefreshCrew()
	return true, nil
end

function ResidentService:AutoAssign(): number
	local free = {}
	local taken: { [string]: number } = {}
	for _, resident in sorted() do
		if resident.State == "Alive" then
			if resident.Job and grid:Room(resident.Job) then
				taken[resident.Job] = (taken[resident.Job] or 0) + 1
			else
				table.insert(free, resident)
			end
		end
	end
	local rooms = {}
	for _, room in grid:Rooms() do
		table.insert(rooms, { Id = room.Id, Type = room.Type, Level = room.Level, Span = room.Span })
	end
	local plan = Residents.AutoAssign(rooms, taken, free)
	local n = 0
	for residentId, roomId in plan do
		local resident = residents[residentId]
		if resident then
			setJob(resident, roomId)
			n += 1
		end
	end
	if n > 0 then
		economy:RefreshCrew()
		log:Info("Auto-Assign gave %d resident(s) a job", n)
	end
	return n
end

-- A room went: its workers move to the room now standing in its cells (a merge), or go idle.
local function roomChanged(roomId: string)
	if grid:Room(roomId) then
		return
	end
	local cell = jobCells[roomId]
	jobCells[roomId] = nil
	local successor = if cell then grid:RoomAt(cell[1], cell[2]) else nil
	local moved = false
	for _, resident in sorted() do
		if resident.Job == roomId then
			if successor and Residents.JobStat(successor.Type) and slotsFree(successor.Id) > 0 then
				setJob(resident, successor.Id)
			else
				setJob(resident, nil)
			end
			moved = true
		end
	end
	if moved then
		economy:RefreshCrew()
	end
end

-- Health and death ---------------------------------------------------------------------------------

local function goDown(resident: Resident, how: string)
	if resident.State ~= "Alive" then
		return
	end
	resident.State = "Down"
	resident.Health = 0
	downUntil[resident.Id] = workspace:GetServerTimeNow() + Config.Get("Tuning", "Residents").DeathReviveSeconds
	downHow[resident.Id] = how
	logLine(resident, `fell ({how})`)
	publish(resident)
	economy:RefreshCrew()
	announce("Danger", `{string.upper(Residents.Name(resident))} IS DOWN: REVIVE THEM WITH A MEDKIT`)
end

local function checkLost()
	for _, resident in residents do
		if resident.State ~= "Dead" then
			return
		end
	end
	if next(residents) and director:Phase() == "Playing" then
		log:Warn("the last resident is gone: the bunker falls")
		director:Lose("ResidentsLost")
	end
end

local function die(resident: Resident, quiet: boolean?)
	local how = downHow[resident.Id] or "unknown"
	resident.State = "Dead"
	downUntil[resident.Id] = nil
	downHow[resident.Id] = nil
	resident.Job = nil
	logLine(resident, `died ({how})`)
	publish(resident)
	economy:RefreshCrew()
	log:Warn("%s died (%s)", Residents.Name(resident), how)
	if not quiet then
		announce("Danger", `{string.upper(Residents.Name(resident))} DIED`)
	end
	ResidentService.Died:Fire(resident.Id, how)
	checkLost()
end

function ResidentService:Hurt(id: string, amount: number, how: string)
	local resident = residents[id]
	if not resident or resident.State ~= "Alive" then
		return
	end
	resident.Health = math.max(0, resident.Health - amount)
	if resident.Health <= 0 then
		goDown(resident, how)
	else
		publish(resident)
	end
end

-- Cave-in rubble cuts a resident off (ResidentBrain): out of their crew until they are free.
function ResidentService:SetTrapped(id: string, on: boolean)
	local resident = residents[id]
	if not resident or (resident.Trapped == true) == on then
		return
	end
	resident.Trapped = on
	if on then
		logLine(resident, "trapped by a cave-in")
	end
	publish(resident)
	economy:RefreshCrew()
end

function ResidentService:Revive(id: string, player: Player?): (boolean, string?)
	local resident = residents[id]
	if not resident or resident.State ~= "Down" then
		return false, "Nobody is down there."
	end
	local paid, why = economy:Spend({ Medkits = 1 }, `reviving {Residents.Name(resident)}`)
	if not paid then
		return false, `No Medkit: {why}.`
	end
	resident.State = "Alive"
	resident.Health = math.max(1, math.floor(resident.MaxHealth * 0.25))
	downUntil[id] = nil
	downHow[id] = nil
	logLine(resident, if player then `revived by {player.DisplayName}` else "revived")
	publish(resident)
	economy:RefreshCrew()
	announce("Info", `{string.upper(Residents.Name(resident))} IS BACK ON THEIR FEET`)
	return true, nil
end

-- New residents ------------------------------------------------------------------------------------

function ResidentService:Add(tier: string?, level: number?): string
	count += 1
	local resident = Residents.Roll(rng, `N{count}`, tier or "Common", level or 1, usedNames)
	residents[resident.Id] = resident
	logLine(resident, "came into the bunker")
	publish(resident)
	return resident.Id
end

-- Residents in the run: everyone not dead, the away included (the cap, Constants.CAPS.Residents).
function ResidentService:Count(): number
	local n = 0
	for _, resident in residents do
		if resident.State ~= "Dead" then
			n += 1
		end
	end
	return n
end

-- Expeditions (Prompt 18) ----------------------------------------------------------------------------

--[[
	Sets out (on): an Alive resident in the bunker leaves their job and goes Away (ResidentBrain walks
	them out through the Blast Door). Comes home (off): an Away resident is Alive again with no job,
	at `health` if given (what an escort home left them).
]]
function ResidentService:SetAway(id: string, on: boolean, health: number?): (boolean, string?)
	local resident = residents[id]
	if not resident then
		return false, "Nobody by that id."
	end
	if on then
		if resident.State ~= "Alive" then
			return false, `{Residents.Name(resident)} can't go: they're {string.lower(resident.State)}.`
		end
		if resident.Trapped then
			return false, `{Residents.Name(resident)} is cut off by rubble.`
		end
		local hadJob = resident.Job ~= nil
		resident.Job = nil
		resident.State = "Away"
		resident.Hungry = false
		publish(resident)
		if hadJob then
			ResidentService.Assigned:Fire(resident.Id, nil)
		end
	else
		if resident.State ~= "Away" then
			return false, `{Residents.Name(resident)} isn't away.`
		end
		resident.State = "Alive"
		if health then
			resident.Health = math.clamp(math.floor(health + 0.5), 1, resident.MaxHealth)
		end
		publish(resident)
	end
	economy:RefreshCrew()
	return true, nil
end

-- Harm on an expedition: never below 1 health (they come back hurt; Lose is for the lost). Returns the harm done.
function ResidentService:Wound(id: string, amount: number): number
	local resident = residents[id]
	if not resident or resident.State ~= "Away" or amount <= 0 then
		return 0
	end
	local before = resident.Health
	resident.Health = math.max(1, resident.Health - amount)
	publish(resident)
	return before - resident.Health
end

-- Experience away (Section 11: residents gain experience from expeditions). With no job, a level goes into their best stat.
function ResidentService:GainXP(id: string, xp: number)
	local resident = residents[id]
	if not resident or resident.State == "Dead" or xp <= 0 then
		return
	end
	local room = if resident.Job then grid:Room(resident.Job) else nil
	local levels = Residents.AddXP(resident, xp * xpMultiplier(), levelStat or (if room then Residents.JobStat(room.Type) else nil))
	if levels > 0 then
		logLine(resident, `reached level {resident.Level}`)
		announce("Info", `{string.upper(Residents.Name(resident))} REACHED LEVEL {resident.Level}`)
	end
	publish(resident)
end

-- Every resident (the away too, not the dead) goes up n levels now, each level adding to their
-- job's stat (or their best with no job), as levels always do (Prompt 19: Field Training).
function ResidentService:AddLevels(n: number, why: string): number
	local raised = 0
	local maxLevel = Config.Get("Tuning", "Residents").LevelMax
	for _, resident in residents do
		if resident.State ~= "Dead" and resident.Level < maxLevel then
			local room = if resident.Job then grid:Room(resident.Job) else nil
			local stat = levelStat or (if room then Residents.JobStat(room.Type) else nil)
			local gained = 0
			for _ = 1, n do
				if resident.Level >= maxLevel then
					break
				end
				gained += Residents.AddXP(resident, math.max(Residents.XPToLevel(resident.Level) - resident.XP, 0), stat)
			end
			if gained > 0 then
				raised += 1
				logLine(resident, `reached level {resident.Level} ({why})`)
				publish(resident)
			end
		end
	end
	if raised > 0 then
		announce("Info", `{string.upper(why)}: {raised} RESIDENTS LEVEL UP`)
	end
	economy:RefreshCrew()
	return raised
end

-- Every resident's morale goes up (or down) by `amount` now (Prompt 19: Morale Broadcast).
function ResidentService:AddMorale(amount: number, why: string): number
	local reached = 0
	for _, resident in residents do
		if resident.State ~= "Dead" then
			resident.Morale = math.clamp(resident.Morale + amount, 0, 100)
			reached += 1
			publish(resident)
		end
	end
	if reached > 0 then
		announce("Info", `{string.upper(why)}: {if amount >= 0 then "+" else ""}{math.floor(amount)} MORALE FOR EVERYONE`)
	end
	economy:RefreshCrew()
	return reached
end

-- A line in a resident's run log (Section 11).
function ResidentService:Note(id: string, text: string)
	local resident = residents[id]
	if not resident then
		return
	end
	logLine(resident, text)
	publish(resident)
end

-- Lost for good, at once (an expedition member who didn't come back): no revive. Quiet: the caller tells the team.
function ResidentService:Lose(id: string, how: string)
	local resident = residents[id]
	if not resident or resident.State == "Dead" then
		return
	end
	downHow[id] = how
	resident.Health = 0
	die(resident, true)
end

-- Once a cycle, after the meal ---------------------------------------------------------------------

local function beds(): number
	local n = 0
	for _, room in grid:RoomsOfType("Quarters") do
		local info = Config.Get("Rooms", "Quarters")
		n += (info.Beds and info.Beds[room.Level] or 0) * room.Span
	end
	return n
end

local function medbayHeals(): boolean
	for _, room in grid:RoomsOfType("Medbay") do
		if not room.Wrecked and not power:IsDark(room.Id) and economy:Crew(room.Id) then
			return true
		end
	end
	return false
end

local function afterMeal(cycle: number, _taken: { [string]: number }, missing: { [string]: number })
	local t = Config.Get("Tuning", "Residents")
	local alive = {}
	for _, resident in sorted() do
		if resident.State == "Alive" then
			table.insert(alive, resident)
		end
	end
	-- who goes hungry: one resident for each missing meal, the newest arrivals first
	local short = math.max(missing.Food or 0, missing.Water or 0)
	local hungry: { [string]: boolean } = {}
	for i = #alive, math.max(1, #alive - short + 1), -1 do
		if short > 0 then
			hungry[alive[i].Id] = true
		end
	end
	local bedsLeft = beds()
	local heals = medbayHeals()
	local decon = false
	for _, room in grid:RoomsOfType("DeconRoom") do
		if not room.Wrecked and not power:IsDark(room.Id) then
			decon = true
		end
	end
	local conditionDown: string? = nil
	for _, resident in alive do
		local room = if resident.Job then grid:Room(resident.Job) else nil
		local jobStat = if room then Residents.JobStat(room.Type) else nil
		local bed = bedsLeft > 0
		if bed then
			bedsLeft -= 1
		end
		local notes = Residents.Cycle(resident, room ~= nil, jobStat, bed, not hungry[resident.Id],
			room ~= nil and power:IsDark(room.Id))
		for _, note in notes do
			logLine(resident, note)
		end
		if room and jobStat then
			local levels = Residents.AddXP(resident, t.XPPerWorkCycle * xpMultiplier(), levelStat or jobStat)
			if levels > 0 then
				logLine(resident, `reached level {resident.Level}`)
				announce("Info", `{string.upper(Residents.Name(resident))} REACHED LEVEL {resident.Level}`)
			end
		end
		if heals and resident.Health > 0 and resident.Health < resident.MaxHealth then
			resident.Health = math.min(resident.MaxHealth, resident.Health + t.MedbayHealPerCycle)
		end
		-- Prompt 24: a working Decon Room clears the irradiated (Section 6: "Clears radiation from
		-- players and residents"); the sick and the irradiated lose health until they are treated
		if resident.Irradiated and decon then
			resident.Irradiated = nil
			logLine(resident, "was cleared of radiation in the Decon Room")
		end
		local cost = Residents.ConditionHealth(resident)
		if cost < 0 and resident.Health > 0 then
			resident.Health = math.max(0, resident.Health + cost)
			conditionDown = if resident.Health <= 0 then (if resident.Sick then "sickness" else "radiation") else nil
		else
			conditionDown = nil
		end
		if resident.Health <= 0 then
			goDown(resident, conditionDown or (if hungry[resident.Id] then "hunger" else "weakness"))
		else
			publish(resident)
		end
	end
	log:Info("cycle %d: needs for %d residents (%d hungry, %d beds)", cycle, #alive, short, beds())
	economy:RefreshCrew()
end

local function afterSurge()
	local boost = Config.Get("Tuning", "Residents").SurgeSurvivedMorale
	for _, resident in residents do
		if resident.State == "Alive" then
			resident.Morale = math.min(100, resident.Morale + boost)
			publish(resident)
		end
	end
	economy:RefreshCrew()
end

-- DevTools ---------------------------------------------------------------------------------------

local function describe(resident: Resident): string
	local stats = {}
	for _, stat in Residents.StatIds() do
		table.insert(stats, `{string.sub(stat, 1, 3)} {resident.Stats[stat]}`)
	end
	local room = if resident.Job then grid:Room(resident.Job) else nil
	return string.format("%s %s, %d, L%d (%d/%d xp): %s; job %s; HP %d/%d, rest %d, morale %d (%s)%s%s",
		resident.Id, Residents.Name(resident), resident.Age, resident.Level, resident.XP, Residents.XPToLevel(resident.Level),
		table.concat(stats, ", "), if room then `{room.Id} {room.Type}` else "none", resident.Health, resident.MaxHealth,
		resident.Rest, resident.Morale, (Residents.MoraleState(resident.Morale)),
		if resident.Hungry then ", HUNGRY" else "", if resident.State ~= "Alive" then `, {string.upper(resident.State)}` else "")
end

local function describeAll(): string
	local lines = {}
	for _, resident in sorted() do
		table.insert(lines, describe(resident))
	end
	return if #lines > 0 then table.concat(lines, "\n") else "no residents"
end

function ResidentService:Init(registry)
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	power = registry.PowerService
	clock = registry.CycleClock
	director = registry.RunDirector
	session = registry.SessionService
	collection = registry.ReplicationService:Collection("Residents")
	Remotes.OnServer("AssignResident", function(player: Player, id: string, roomId: string)
		local ok, why = ResidentService:Assign(id, if roomId == "" then nil else roomId)
		if not ok and why then
			Remotes.FireClient("Alert", player, "Warning", why)
		end
	end)
	Remotes.OnServer("AutoAssign", function(player: Player)
		local n = ResidentService:AutoAssign()
		Remotes.FireClient("Alert", player, "Info",
			if n > 0 then `AUTO-ASSIGN: {n} RESIDENT{if n == 1 then "" else "S"} PUT TO WORK` else "AUTO-ASSIGN: NO EMPTY JOB FITS ANYONE IDLE")
	end)
	Remotes.OnServer("ReviveResident", function(player: Player, id: string)
		local ok, why = ResidentService:Revive(id, player)
		if not ok and why then
			Remotes.FireClient("Alert", player, "Warning", why)
		end
	end)
	local dev = registry.DevService
	dev:Register("residents", {
		Description = "Every resident: stats, job, needs and state.",
		Usage = "residents",
		Run = function(): string?
			return describeAll()
		end,
	})
	dev:Register("residents.auto", {
		Description = "Auto-Assign idle residents.",
		Usage = "residents.auto",
		Run = function(): string?
			return `assigned {ResidentService:AutoAssign()}\n{describeAll()}`
		end,
	})
	dev:Register("residents.add", {
		Description = "New residents (a recruit, for testing).",
		Usage = "residents.add [count] [tier] [level]",
		Run = function(_player: Player?, args): string?
			for _ = 1, math.clamp(tonumber(args[1]) or 1, 1, 20) do
				ResidentService:Add(if args[2] then tostring(args[2]) else nil, tonumber(args[3]))
			end
			return describeAll()
		end,
	})
	dev:Register("resident.assign", {
		Description = "Give a resident a job (a room id) or none.",
		Usage = "resident.assign <id> <roomId|none>",
		Run = function(_player: Player?, args): string?
			local id, roomId = tostring(args[1] or ""), tostring(args[2] or "")
			local ok, why = ResidentService:Assign(id, if roomId == "none" then nil else roomId)
			return if ok then describeAll() else `refused: {why}`
		end,
	})
	dev:Register("resident.hurt", {
		Description = "Hurt a resident (0 health: down, then dead).",
		Usage = "resident.hurt <id> <amount>",
		Run = function(_player: Player?, args): string?
			ResidentService:Hurt(tostring(args[1] or ""), tonumber(args[2]) or 10, "DevTools")
			return describeAll()
		end,
	})
	dev:Register("resident.revive", {
		Description = "Revive a downed resident with a Medkit from the stockpile.",
		Usage = "resident.revive <id>",
		Run = function(_player: Player?, args): string?
			local ok, why = ResidentService:Revive(tostring(args[1] or ""), nil)
			return if ok then describeAll() else `refused: {why}`
		end,
	})
	dev:Register("resident.set", {
		Description = "Set a resident's need or stat: health, rest, morale, xp or a stat name.",
		Usage = "resident.set <id> <field> <value>",
		Run = function(_player: Player?, args): string?
			local resident = residents[tostring(args[1] or "")]
			local field, value = string.lower(tostring(args[2] or "")), tonumber(args[3])
			if not resident or not value then
				return "usage: resident.set <id> <health|rest|morale|xp|Strength...> <value>"
			end
			if field == "health" then
				resident.Health = math.clamp(value, 0, resident.MaxHealth)
			elseif field == "rest" then
				resident.Rest = math.clamp(value, 0, 100)
			elseif field == "morale" then
				resident.Morale = math.clamp(value, 0, 100)
			elseif field == "xp" then
				Residents.AddXP(resident, value, nil)
			else
				for _, stat in Residents.StatIds() do
					if string.lower(stat) == field then
						resident.Stats[stat] = math.clamp(value, 1, Config.Get("Tuning", "Residents").StatCap)
						resident.MaxHealth = Residents.MaxHealth(resident.Stats)
					end
				end
			end
			publish(resident)
			economy:RefreshCrew()
			return describe(resident)
		end,
	})
end

function ResidentService:Start()
	local start = Config.Get("Tuning", "StartingBunker")
	for _ = 1, start.Residents do
		ResidentService:Add(start.ResidentTier, rng:NextInteger(start.ResidentLevels.Min, start.ResidentLevels.Max))
	end
	-- the founders start idle (Landon): when play starts, tell the team they're waiting for work
	director.PhaseChanged:Connect(function(phase: string, old: string)
		if phase ~= "Playing" or old ~= "Intro" then -- only when the run starts (not after Keep Going)
			return
		end
		local idle = 0
		for _, resident in residents do
			if resident.State == "Alive" and not resident.Job then
				idle += 1
			end
		end
		if idle > 0 then
			task.delay(2, function()
				announce("Warning", if idle == 1
					then "1 RESIDENT IS WAITING FOR A JOB: OPEN THE COMMAND VIEW AND ASSIGN THEM"
					else `{idle} RESIDENTS ARE WAITING FOR JOBS: OPEN THE COMMAND VIEW AND ASSIGN THEM`)
			end)
		end
	end)
	economy:SetResidents({
		Crew = function(roomId: string): Residents.Crew?
			local room = grid:Room(roomId)
			if not room then
				return nil
			end
			local workers = {}
			for _, resident in residents do
				if resident.Job == roomId and not resident.Trapped then
					table.insert(workers, resident)
				end
			end
			return Residents.Crew(workers, room.Type)
		end,
		Eaters = function(): { { Id: string, FoodUse: number? } }
			local list = {}
			for _, resident in sorted() do
				if resident.State == "Alive" then
					table.insert(list, { Id = resident.Id })
				end
			end
			return list
		end,
	})
	economy.Ate:Connect(afterMeal)
	clock.SurgeEnded:Connect(afterSurge)
	grid.RoomChanged:Connect(roomChanged)
	RunService.Heartbeat:Connect(function()
		if next(downUntil) == nil then
			return
		end
		local now = workspace:GetServerTimeNow()
		for id, untilTime in table.clone(downUntil) do
			local resident = residents[id]
			if resident and resident.State == "Down" and now >= untilTime then
				die(resident)
			end
		end
	end)
	log:Info("%d founders in the bunker:\n%s", start.Residents, describeAll())
end

return ResidentService
