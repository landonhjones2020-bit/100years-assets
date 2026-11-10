--!strict
--[[
	ExpeditionService: resident expeditions, distress calls and the Radio Room (bible Sections 6, 8,
	11, 12 and 23; Run place, Prompt 18). The arithmetic is Shared.Rules.Expeditions, the numbers
	Tuning.Expeditions (provisional), the log lines Config.ExpeditionLogs.

	* Sending (Section 12: "From the Radio Room or the Blast Door, send 1 to 3 residents to the
	  surface or the Deep for 1, 2 or 3 cycles, with gear and supplies"; Section 8: never voted):
	  an EXPEDITIONS console prompt in the Blast Door hall and in every Radio Room opens the
	  Expeditions screen (ExpeditionsController). Its SendExpedition remote is checked here: the
	  sender within UseRange of a console, the team (Rules.Expeditions.Check), the supplies. Food and
	  Water for every member for every cycle, and the Medkits packed, come out of the stockpile; each
	  member leaves their job and walks out through the Blast Door (ResidentService:SetAway,
	  ResidentBrain). Gear waits for resident gear (Prompt 26). A Deep expedition goes to the band
	  of the bunker's deepest floor (its ore).
	* Away (Section 12: "They leave the map. Every cycle their log gets a line"): at each dawn
	  (CycleClock.CycleStarted) an expedition out since an earlier cycle lives one cycle: its members
	  eat their packed Food and Water and gain XPPerExpeditionCycle; the team finds the destination's
	  loot (Rules.Expeditions.Scale: Scrap, Food, Water, the band's ore; one recruit at most a trip;
	  gear and blueprints wait for Prompts 26 and 19); and one thing happens (Rules.Expeditions
	  .Event): nothing, someone hurt (a packed Medkit halves it), someone lost (a packed Medkit makes
	  it a bad hurt instead), or a distress call. The line goes in the expedition's log and in its
	  members' run logs. After their last cycle they come home through the Blast Door with what they
	  found and what's left of the supplies, and go back to their old jobs if there's room. A
	  fast team (average Speed FastSpeed or more when they set out) comes home a cycle sooner,
	  never under 1, with the full trip's finds (Landon, Prompt 18).
	* Distress calls (Section 12: "a marker appears and players have until the end of the next day
	  phase to reach them, or they are lost along with their loot"): the call comes CallDelay seconds
	  into that day, DistressCallLeadSeconds sooner (the Radio Operator). Only a working Radio Room
	  (staffed and powered) hears it (Landon, Prompt 18): unheard, the team and its finds are lost.
	  Heard, it is on everyone's radio card and in the alerts. The team is pinned down at a survivor
	  spot in Brightwater Ruins
	  (SurfaceService:DistressSpot) or in a cave the bunker has opened (DeepService:DistressSpot), each
	  member with a HELP prompt (RescueService, Kind Expedition); the Expeditions collection carries
	  the marker. Helped, they follow home like a rescue; the first one home brings the finds. Whoever
	  is still pinned down when the day phase of the cycle after the call ends (the Surge starts) is
	  lost, and with nobody left to bring them, so are the finds.
	* The Radio Room (Charm; Section 6: "Recruits survivors, places supply calls, hears distress
	  calls"): its Recruits output (EconomyService:Rate) times RecruitRate (the Radio Operator, Wren
	  Holloway) brings a recruit to the Blast Door at each whole point, Rare at RadioRareChance times
	  RareRecruitChance. While a Lost Crew is still out and a Radio Room works, every RadioHintCycles
	  cycles it picks up that crew's call (Section 12: "Radio logs and the Radio Room give hints about
	  where each crew is"; DeepService:CrewCall). No recruit comes past Constants.CAPS.Residents.
	  The Radio Operator's Supply Call is Prompt 20's.

	API:
		ExpeditionService:Send(destination, memberIds, cycles, medkits, player?): (string?, string?)
		ExpeditionService:Recruit(tier?, how): string?        -- a newcomer at the Blast Door (draft cards, Prompt 19)
		ExpeditionService:SetModifier(source, key, value?)    -- RecruitRate, RareRecruitChance, DistressCallLeadSeconds
		ExpeditionService:Active(): number
	Signals: Sent(id, destination, names), Returned(id, destination, names, finds), Lost(id, destination, names),
	Distress(id, where), Reached(id, player), Recruited(residentId, how).
	Replication: the Expeditions collection, id -> { Destination, Band, Members = { { Id, Name, Status } }, Cycles,
	Trip, Done, LeftAt, Back, State, Log, Finds, Recruits, Food, Water, Medkits, CallCycle, Deadline,
	Marker = { X, Y, Z }, Where }; RunState RadioWorks (a Radio Room can hear a call).
	Dev: exp, exp.send, exp.cycle, exp.call, exp.home, exp.deadline, recruit, radio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Economy = require(Shared.Rules.Economy)
local Expeditions = require(Shared.Rules.Expeditions)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Residents = require(Shared.Rules.Residents)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("ExpeditionService")

local ExpeditionService = {
	Name = "ExpeditionService",
	Dependencies = {
		"BunkerGrid", "CycleClock", "RunDirector", "SessionService", "EconomyService", "ResidentService",
		"ResidentBrain", "RescueService", "SurfaceService", "DeepService", "ReplicationService", "DevService",
	},
	Sent = Signal.new() :: Signal.Signal<string, string, string>,
	Returned = Signal.new() :: Signal.Signal<string, string, string, string>,
	Lost = Signal.new() :: Signal.Signal<string, string, string>,
	Distress = Signal.new() :: Signal.Signal<string, string>,
	Reached = Signal.new() :: Signal.Signal<string, Player>,
	Recruited = Signal.new() :: Signal.Signal<string, string>,
	BlueprintsHome = Signal.new() :: Signal.Signal<number, string>, -- Prompt 19: count, destination
}

-- loot nothing hands out yet: gear (Prompt 26), blueprints (Prompt 19); recruits are this service's
local SKIP: { [string]: boolean } = { Gear = true } -- blueprints come home for the draft (Prompt 19)
local HALL = Vector3.new(0, 0, 6) -- from the Blast Door's Door socket into the hall (where the elevator lets out)
local BLAST_CONSOLE = Vector3.new(-10, 2.5, 1) -- the hall's console without the art kit's GuardDesk: left of the door
local RADIO_CONSOLE_BACK = 5 -- a Radio Room's console: this far in from its back wall (or its Console socket)
local RADIO_SCALE = 1.5 -- the radio set on a Radio Room's console (Prop_RadioLog, A6) until A7 brings the room's art
local MODIFIER_KEYS = { "RecruitRate", "RareRecruitChance", "DistressCallLeadSeconds" }

type Member = {
	Id: string,
	Name: string,
	Job: string?, -- the job they left, to go back to
	Status: string, -- Away, Pinned, Following, Home, Lost
	Rescue: string?, -- RescueService id while pinned down or following
}
type Expedition = {
	Id: string,
	Destination: string,
	Band: string?,
	Ore: string?,
	Members: { Member },
	Cycles: number, -- the length picked
	Trip: number, -- the cycles they are away: one less for a fast team (Landon, Prompt 18)
	Done: number,
	LeftAt: number,
	Food: number,
	Water: number,
	Medkits: number,
	Finds: { [string]: number },
	Recruits: number,
	Blueprints: number, -- Prompt 19: found blueprints, each a card for the draft once home
	Log: { string },
	State: string, -- Away, Calling, Distress, Reached, Home, Lost
	CallIn: number?, -- running seconds until the call (Calling)
	CallCycle: number?,
	Deadline: number?,
	Marker: Vector3?,
	Where: string?,
	Delivered: boolean,
	FindsText: string?, -- what they brought home (once delivered)
}

local grid: any = nil
local clock: any = nil
local director: any = nil
local session: any = nil
local economy: any = nil
local residents: any = nil
local brain: any = nil
local rescue: any = nil
local surface: any = nil
local deep: any = nil
local collection: any = nil

local expeditions: { [string]: Expedition } = {}
local counter = 0
local radioProgress = 0
local lastHintCycle = 0
local radioHeard: boolean? = nil
local setState: (name: string, value: any) -> () = function() end
local bunkerModifiers: { [string]: { [string]: number } } = {} -- key -> source -> value
local rng = Random.new()

-- Helpers ------------------------------------------------------------------------------------------

local function t(): { [string]: any }
	return Expeditions.Tuning()
end

local function alertAll(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function order(id: string): number
	return tonumber(string.match(id, "%d+")) or 0
end

local function sortedActive(): { Expedition }
	local list = {}
	for _, e in expeditions do
		table.insert(list, e)
	end
	table.sort(list, function(a: Expedition, b: Expedition): boolean
		return order(a.Id) < order(b.Id)
	end)
	return list
end

local function destinationText(e: Expedition): string
	if e.Destination == "Deep" then
		local band = e.Band and Config.Find("DepthBands", e.Band)
		return if band then Expeditions.Place(band.Name) else "the Deep"
	end
	return "the surface"
end

local function namesOf(e: Expedition, statuses: { [string]: boolean }?): { string }
	local list = {}
	for _, m in e.Members do
		if not statuses or statuses[m.Status] then
			table.insert(list, m.Name)
		end
	end
	return list
end

local function membersWith(e: Expedition, status: string): { Member }
	local list = {}
	for _, m in e.Members do
		if m.Status == status then
			table.insert(list, m)
		end
	end
	return list
end

local function statsOf(members: { Member }): { Expeditions.Stats }
	local list = {}
	for _, m in members do
		local resident = residents:Get(m.Id)
		table.insert(list, if resident then resident.Stats else {})
	end
	return list
end

-- A member's own effects (traits from Prompt 26, a Legend's signature from Prompt 27): none yet.
local function effectsOf(members: { Member }): { { any } }
	local list = {}
	for _ in members do
		table.insert(list, {})
	end
	return list
end

-- Bunker-wide modifiers: the best player's class value (the Radio Operator) with the run's own sources.
local function bunkerValue(key: string): number
	local info = Config.Get("Modifiers", key)
	local add = info.Unit == "Add"
	local best = if add then 0 else 1
	for _, player in Players:GetPlayers() do
		local value = Modifiers.PlayerValue(player, key)
		if value then
			best = math.max(best, value)
		end
	end
	for _, value in bunkerModifiers[key] or {} do
		best = if add then best + value else best * value
	end
	return best
end

local function pick(list: { string }): string?
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

-- A place on the way for this cycle's line: a place in Brightwater Ruins (open this era), or the band.
local function placeFor(e: Expedition): string
	if e.Destination == "Deep" then
		return destinationText(e)
	end
	local era = table.find(Config.Ids("Eras"), clock:Era()) or 1
	local open = {}
	for _, id in Config.Ids("SurfaceLocations") do
		local location = Config.Get("SurfaceLocations", id)
		if location.MinEra <= era then
			table.insert(open, location.Name)
		end
	end
	local name = pick(open)
	return if name then Expeditions.Place(name) else "the ruins"
end

local function line(e: Expedition, event: string, fields: { [string]: string }): string?
	local text = pick(Expeditions.Lines(e.Destination, event))
	return if text then Expeditions.Fill(text, fields) else nil
end

-- A line in the expedition's log and its members' run logs.
local function note(e: Expedition, text: string?, members: { Member }?)
	if not text then
		return
	end
	local year = clock:Year()
	table.insert(e.Log, `Year {year}: {text}`)
	if #e.Log > 12 then
		table.remove(e.Log, 1)
	end
	for _, m in members or e.Members do
		if m.Status ~= "Lost" then
			residents:Note(m.Id, `{if e.Destination == "Deep" then "Deep" else "surface"} expedition: {text}`)
		end
	end
end

local function publish(e: Expedition)
	local members = {}
	for _, m in e.Members do
		table.insert(members, { Id = m.Id, Name = m.Name, Status = m.Status })
	end
	collection:Set(e.Id, {
		Destination = e.Destination,
		Band = e.Band,
		Members = members,
		Cycles = e.Cycles,
		Trip = e.Trip,
		Done = e.Done,
		LeftAt = e.LeftAt,
		Back = e.LeftAt + e.Trip,
		State = e.State,
		Log = table.clone(e.Log),
		Finds = table.clone(e.Finds),
		Recruits = e.Recruits,
		Blueprints = e.Blueprints,
		Food = e.Food,
		Water = e.Water,
		Medkits = e.Medkits,
		CallCycle = e.CallCycle,
		Deadline = e.Deadline,
		Marker = if e.Marker then { X = e.Marker.X, Y = e.Marker.Y, Z = e.Marker.Z } else nil,
		Where = e.Where,
	})
end

local function findsText(finds: { [string]: number }, recruits: number, blueprints: number?): string
	local parts = {}
	for _, id in Config.Ids("Resources") do
		local amount = finds[id]
		if amount and amount > 0 then
			table.insert(parts, `+{amount} {string.upper(Config.Get("Resources", id).Name)}`)
		end
	end
	if recruits > 0 then
		table.insert(parts, if recruits == 1 then "A RECRUIT" else `{recruits} RECRUITS`)
	end
	if blueprints and blueprints > 0 then
		table.insert(parts, if blueprints == 1 then "A BLUEPRINT" else `{blueprints} BLUEPRINTS`)
	end
	return if #parts > 0 then table.concat(parts, " · ") else "NOTHING FOUND"
end

-- The Blast Door hall --------------------------------------------------------------------------------

local function doorSocket(): CFrame?
	local door = grid:RoomsOfType("BlastDoor")[1]
	local model = door and grid:RoomModel(door.Id)
	return model and BunkerKit.Socket(model, "Door")
end

-- Where the i-th of a group steps into the hall, facing in.
local function hallSpot(i: number): CFrame?
	local socket = doorSocket()
	if not socket then
		return nil
	end
	local at = socket.Position + HALL + Vector3.new(((i - 1) % 3 - 1) * 3, 0, math.floor((i - 1) / 3) * 3)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
end

local function stepIn(residentId: string, at: CFrame?)
	local body = brain:Body(residentId)
	if body and at then
		body:PivotTo(at)
	end
end

-- Recruits ---------------------------------------------------------------------------------------------

function ExpeditionService:Recruit(tier: string?, how: string): string?
	if residents:Count() >= Constants.CAPS.Residents then
		alertAll("Warning", `THE BUNKER IS FULL ({Constants.CAPS.Residents}): A RECRUIT WAS TURNED AWAY`)
		log:Info("a recruit (%s) was turned away: the bunker is full", how)
		return nil
	end
	local level = t().RadioLevel
	local id = residents:Add(tier or "Common", rng:NextInteger(level.Min, level.Max))
	stepIn(id, hallSpot(rng:NextInteger(1, 3)))
	residents:Note(id, how)
	local record = residents:Get(id)
	local name = if record then string.upper(Residents.Name(record)) else id
	alertAll("Info", `{name}{if tier and tier ~= "Common" then ` ({string.upper(tier)})` else ""} JOINS THE BUNKER: {string.upper(how)}`)
	log:Info("%s (%s) joined: %s", id, tier or "Common", how)
	ExpeditionService.Recruited:Fire(id, how)
	return id
end

local function radioRate(): number
	local rate = 0
	for _, room in grid:RoomsOfType("RadioRoom") do
		local value, makes = economy:Rate(room.Id)
		if makes == "Recruits" or makes == nil then
			rate += value
		end
	end
	return rate * bunkerValue("RecruitRate")
end

local function radioWorks(): boolean
	for _, room in grid:RoomsOfType("RadioRoom") do
		if (economy:Rate(room.Id)) > 0 then
			return true
		end
	end
	return false
end

local function radioRecruit()
	local chance = t().RadioRareChance * bunkerValue("RareRecruitChance")
	ExpeditionService:Recruit(Expeditions.RecruitTier(rng:NextNumber(), chance), "answered the Radio Room's call")
end

-- A Lost Crew's call, picked up by a working Radio Room (Section 12: crew hints).
local function crewCall(force: boolean?): boolean
	if not force and not radioWorks() then
		return false
	end
	local logId, where = deep:CrewCall()
	if not logId then
		return false
	end
	for _, player in session:ReadyPlayers() do
		deep:PlayLog(player, logId, where)
	end
	alertAll("Info", "THE RADIO ROOM PICKED UP A LOST CREW'S CALL")
	return true
end

-- Sending -----------------------------------------------------------------------------------------------

local function consoles(): Folder?
	local root = grid:Root()
	return if root then root:FindFirstChild("ExpeditionConsoles") :: Folder? else nil
end

local function nearConsole(player: Player): boolean
	local root = rootOf(player)
	local holder = consoles()
	if not root or not holder then
		return false
	end
	for _, anchor in holder:GetChildren() do
		if anchor:IsA("BasePart") and (anchor.Position - root.Position).Magnitude <= t().UseRange then
			return true
		end
	end
	return false
end

function ExpeditionService:Send(destination: string, memberIds: { string }, cycles: number, medkits: number, player: Player?): (string?, string?)
	if director:Phase() ~= "Playing" then
		return nil, "Expeditions go out while the run is on."
	end
	if player and not nearConsole(player) then
		return nil, "Send expeditions from the Blast Door hall or a Radio Room."
	end
	local seen: { [string]: boolean } = {}
	local candidates = {}
	local teamStats = {}
	for _, id in memberIds do
		local resident = residents:Get(id)
		if not resident then
			return nil, "That resident isn't in the bunker."
		elseif seen[id] then
			return nil, "Pick each resident once."
		end
		seen[id] = true
		table.insert(candidates, { State = resident.State, Trapped = resident.Trapped })
		table.insert(teamStats, resident.Stats)
	end
	local ok, why = Expeditions.Check(destination, candidates, cycles, medkits)
	if not ok then
		return nil, why
	end
	local supplies = Expeditions.Supplies(#memberIds, cycles)
	local costs: { [string]: number } = { Food = supplies.Food, Water = supplies.Water }
	if medkits > 0 then
		costs.Medkits = medkits
	end
	local paid, short = economy:Spend(costs, "an expedition's supplies")
	if not paid then
		return nil, `Not enough supplies: {short}.`
	end
	counter += 1
	local band = if destination == "Deep" then Grid.BandOf(math.max(grid:DeepestFloor(), 1)) else nil
	local e: Expedition = {
		Id = `E{counter}`,
		Destination = destination,
		Band = if band then band.Id else nil,
		Ore = if band then band.Ore else nil,
		Members = {},
		Cycles = cycles,
		Trip = Expeditions.Trip(cycles, teamStats),
		Done = 0,
		LeftAt = clock:Cycle(),
		Food = supplies.Food,
		Water = supplies.Water,
		Medkits = medkits,
		Finds = {},
		Recruits = 0,
		Blueprints = 0,
		Log = {},
		State = "Away",
		CallIn = nil,
		CallCycle = nil,
		Deadline = nil,
		Marker = nil,
		Where = nil,
		Delivered = false,
		FindsText = nil,
	}
	for _, id in memberIds do
		local resident = residents:Get(id)
		table.insert(e.Members, { Id = id, Name = Residents.Name(resident), Job = resident.Job, Status = "Away", Rescue = nil })
		residents:SetAway(id, true)
	end
	expeditions[e.Id] = e
	local names = Expeditions.Names(namesOf(e))
	note(e, line(e, "SetOut", { names = names, place = destinationText(e) }))
	publish(e)
	alertAll("Info", `{string.upper(names)} SET OUT FOR {string.upper(destinationText(e))}: BACK IN {e.Trip} CYCLE{if e.Trip == 1 then "" else "S"}`
		.. (if e.Trip < e.Cycles then " (A FAST TEAM)" else ""))
	log:Info("%s: %s to %s for %d cycle(s), %d Medkit(s)%s", e.Id, names, destination, cycles, medkits,
		if player then ` (sent by {player.Name})` else "")
	ExpeditionService.Sent:Fire(e.Id, destination, names)
	return e.Id, nil
end

-- Home ------------------------------------------------------------------------------------------------

local function backToWork(m: Member): boolean
	if m.Job and grid:Room(m.Job) then
		local ok = residents:Assign(m.Id, m.Job)
		return ok
	end
	return false
end

-- The finds, what's left of the supplies and any recruit go into the bunker (once a trip).
local function deliver(e: Expedition): string
	if e.Delivered then
		return ""
	end
	e.Delivered = true
	local got: { [string]: number } = {}
	for resource, amount in e.Finds do
		local added = if amount > 0 then economy:Add(resource, amount, `the {e.Destination} expedition`) else 0
		if added > 0 then
			got[resource] = added
		end
	end
	for resource, amount in { Food = e.Food, Water = e.Water, Medkits = e.Medkits } do
		if amount > 0 then
			economy:Add(resource, amount, "an expedition's supplies, back")
		end
	end
	e.Food, e.Water, e.Medkits = 0, 0, 0
	local recruits = 0
	for _ = 1, e.Recruits do
		local tier = Expeditions.RecruitTier(rng:NextNumber(), t().RecruitRareChance * bunkerValue("RareRecruitChance"))
		if ExpeditionService:Recruit(tier, `came home with the {if e.Destination == "Deep" then "Deep" else "surface"} expedition`) then
			recruits += 1
		end
	end
	local blueprints = e.Blueprints
	e.Blueprints = 0
	if blueprints > 0 then
		ExpeditionService.BlueprintsHome:Fire(blueprints, e.Destination)
	end
	e.FindsText = findsText(got, recruits, blueprints)
	return e.FindsText :: string
end

local function finish(e: Expedition, how: string, finds: string?)
	e.State = how
	expeditions[e.Id] = nil
	collection:Remove(e.Id)
	local names = Expeditions.Names(namesOf(e))
	if how == "Home" then
		ExpeditionService.Returned:Fire(e.Id, e.Destination, Expeditions.Names(namesOf(e, { Home = true })), finds or "")
	else
		ExpeditionService.Lost:Fire(e.Id, e.Destination, names)
	end
	log:Info("%s finished: %s (%s)", e.Id, how, finds or "-")
end

-- Every member is home or lost: the trip is over.
local function settle(e: Expedition)
	for _, m in e.Members do
		if m.Status ~= "Home" and m.Status ~= "Lost" then
			return
		end
	end
	if #membersWith(e, "Home") > 0 then
		finish(e, "Home", e.FindsText)
	else
		alertAll("Danger", `THE {string.upper(e.Destination)} EXPEDITION IS LOST: {string.upper(Expeditions.Names(namesOf(e)))} DIDN'T COME BACK`)
		finish(e, "Lost")
	end
end

-- The end of the trip: everyone still away walks in through the Blast Door with the finds.
local function comeHome(e: Expedition)
	local back = membersWith(e, "Away")
	local idle = {}
	for i, m in back do
		residents:SetAway(m.Id, false)
		stepIn(m.Id, hallSpot(i))
		m.Status = "Home"
		if not backToWork(m) then
			table.insert(idle, m.Name)
		end
	end
	local home = Expeditions.Names(namesOf(e, { Home = true }))
	note(e, line(e, "Home", { names = home }), back)
	local finds = deliver(e)
	alertAll("Info", `THE {string.upper(e.Destination)} EXPEDITION IS HOME: {string.upper(home)} · {finds}`)
	if #idle > 0 then
		alertAll("Warning", `{string.upper(Expeditions.Names(idle))} {if #idle == 1 then "IS" else "ARE"} BACK AND WAITING FOR A JOB`)
	end
	publish(e)
	if #back > 0 then
		finish(e, "Home", finds)
	else
		settle(e)
	end
end

-- Losing members ------------------------------------------------------------------------------------

local function lose(e: Expedition, m: Member, how: string, quiet: boolean?)
	if m.Status == "Lost" or m.Status == "Home" then
		return
	end
	if m.Rescue then
		rescue:Remove(m.Rescue)
		m.Rescue = nil
	end
	m.Status = "Lost"
	residents:Lose(m.Id, how)
	if not quiet then
		alertAll("Danger", `{string.upper(m.Name)} IS GONE: {string.upper(how)}`)
	end
end

-- Distress calls ------------------------------------------------------------------------------------

local function call(e: Expedition)
	local spot, where = nil, nil
	if e.Destination == "Deep" then
		spot, where = deep:DistressSpot()
	else
		local at, name = surface:DistressSpot()
		spot, where = at, if name then Expeditions.Place(name) else "the ruins"
	end
	local pinned = membersWith(e, "Away")
	if not spot or not where or #pinned == 0 then
		-- nowhere to be found (no surface map, nothing dug): they make their own way on, shaken
		log:Warn("%s: no spot for a distress call; it passes", e.Id)
		e.State = "Away"
		e.CallIn = nil
		publish(e)
		return
	end
	if not radioWorks() then
		-- no Radio Room staffed and powered: nobody hears the call (Landon, Prompt 18)
		local names = Expeditions.Names(namesOf(e, { Away = true }))
		note(e, line(e, "Unheard", { names = names, place = where }), pinned)
		for _, m in pinned do
			lose(e, m, "lost: no Radio Room heard their call", true)
		end
		-- short: the alert box shows two lines (the names are in the logs)
		alertAll("Danger", `THE {string.upper(e.Destination)} EXPEDITION IS LOST: NO RADIO ROOM HEARD ITS CALL`)
		log:Info("%s radioed from %s, unheard: lost", e.Id, where)
		finish(e, "Lost")
		return
	end
	e.State = "Distress"
	e.CallIn = nil
	e.CallCycle = clock:Cycle()
	e.Deadline = Expeditions.Deadline(e.CallCycle :: number)
	e.Marker = spot.Position
	e.Where = where
	for i, m in pinned do
		local resident = residents:Get(m.Id)
		local offset = CFrame.new(((i - 1) % 3 - 1) * 2.2, 0, 0) -- side by side, close enough to stay indoors
		local id = rescue:Trap(spot * offset, {
			Kind = "Expedition",
			Tier = if resident then resident.Tier else "Common",
			Level = if resident then resident.Level else 1,
			Where = where,
			Tag = e.Id,
			Resident = m.Id,
			Health = if resident then resident.Health else nil,
			Label = m.Name,
			Action = "HELP",
		})
		if id then
			m.Status = "Pinned"
			m.Rescue = id
		end
	end
	local names = Expeditions.Names(namesOf(e, { Pinned = true }))
	note(e, line(e, "Distress", { names = names, place = where }), pinned)
	local caller = pinned[1]
	local message = line(e, "Call", { name = caller.Name, names = names, place = where }) or `{caller.Name} calling the bunker: we need help at {where}.`
	for _, player in session:ReadyPlayers() do
		Remotes.FireClient("RadioLog", player, "Distress call", `{caller.Name}, {destinationText(e)} expedition`, message, where)
	end
	alertAll("Danger", `DISTRESS CALL FROM {string.upper(where)}: REACH THEM BEFORE TOMORROW'S SURGE`)
	log:Info("%s radioed for help from %s (deadline: cycle %d's day)", e.Id, where, e.Deadline :: number)
	publish(e)
	ExpeditionService.Distress:Fire(e.Id, where)
end

local function findMember(rescueId: string): (Expedition?, Member?)
	for _, e in expeditions do
		for _, m in e.Members do
			if m.Rescue == rescueId then
				return e, m
			end
		end
	end
	return nil, nil
end

local function helped(rescueId: string, player: Player)
	local e, m = findMember(rescueId)
	if not e or not m then
		return
	end
	m.Status = "Following"
	residents:Note(m.Id, `reached by {player.DisplayName}`)
	if e.State == "Distress" then
		e.State = "Reached"
		alertAll("Info", `{string.upper(player.DisplayName)} REACHED THE {string.upper(e.Destination)} EXPEDITION: BRING THEM HOME`)
		ExpeditionService.Reached:Fire(e.Id, player)
	end
	publish(e)
end

-- A member helped home walks in (RescueService arrival, Kind Expedition).
local function arrived(r: any, leader: Player?, residentId: string)
	local e, m = findMember(r.Id)
	if not e or not m then
		return
	end
	m.Status = "Home"
	m.Rescue = nil
	residents:SetAway(m.Id, false, r.HealthLeft)
	stepIn(m.Id, r.HomeAt)
	residents:Note(m.Id, if leader then `came home, led by {leader.DisplayName}` else "came home")
	local working = backToWork(m)
	local finds = deliver(e)
	alertAll("Info", `{string.upper(m.Name)} IS HOME{if leader then `, LED BY {string.upper(leader.DisplayName)}` else ""}`
		.. (if finds ~= "" then ` · {finds}` else "") .. (if working then "" else " · WAITING FOR A JOB"))
	publish(e)
	settle(e)
end

local function strayLost(rescueId: string, kind: string)
	if kind ~= "Expedition" then
		return
	end
	local e, m = findMember(rescueId)
	if not e or not m then
		return
	end
	m.Rescue = nil -- RescueService already let them go
	lose(e, m, "killed on the way home")
	publish(e)
	settle(e)
end

-- The end of the day phase after a call: whoever is still pinned down is lost.
local function deadline(force: boolean?)
	local cycle = clock:Cycle()
	for _, e in sortedActive() do
		if (e.State == "Distress" or e.State == "Reached") and e.Deadline and (force or cycle >= e.Deadline) then
			local pinned = membersWith(e, "Pinned")
			for _, m in pinned do
				lose(e, m, "lost waiting for help")
			end
			if #pinned > 0 then
				log:Info("%s: %d pinned down member(s) lost at the deadline", e.Id, #pinned)
				publish(e)
				settle(e)
			end
		end
	end
end

-- Away: a cycle ------------------------------------------------------------------------------------

-- A cycle's finds for the members still out (the destination's loot table, scaled by the team).
local function find(e: Expedition, away: { Member })
	local team = Expeditions.Team(statsOf(away), effectsOf(away))
	local drops = Expeditions.Scale(Loot.Roll(Expeditions.LootTable(e.Destination), rng, { BandOre = e.Ore, Skip = SKIP }), team)
	for _, drop in drops do
		if drop.Resource then
			e.Finds[drop.Resource] = (e.Finds[drop.Resource] or 0) + drop.Count
		elseif drop.Special == "Recruit" and e.Recruits < t().RecruitsMax then
			e.Recruits += 1
		elseif drop.Special == "Blueprint" then
			e.Blueprints += 1
		end
	end
end

local function live(e: Expedition, forced: string?)
	local away = membersWith(e, "Away")
	if #away == 0 then
		return
	end
	local residentTuning = Config.Get("Tuning", "Residents")
	e.Done += 1
	e.Food = math.max(0, e.Food - #away * residentTuning.FoodPerCycle)
	e.Water = math.max(0, e.Water - #away * residentTuning.WaterPerCycle)
	for _, m in away do
		residents:GainXP(m.Id, residentTuning.XPPerExpeditionCycle)
	end
	find(e, away)
	-- what happened
	local odds = Expeditions.Odds(e.Destination, statsOf(away))
	local event = forced or Expeditions.Event(odds, rng:NextNumber())
	local place = placeFor(e)
	local m = away[rng:NextInteger(1, #away)]
	local resident = residents:Get(m.Id)
	local maxHealth = if resident then resident.MaxHealth else 100
	if event == "Hurt" then
		local medkit = e.Medkits > 0
		if medkit then
			e.Medkits -= 1
		end
		residents:Wound(m.Id, Expeditions.Harm(maxHealth, rng:NextNumber(), medkit))
		note(e, line(e, "Hurt", { name = m.Name, place = place }), away)
	elseif event == "Lost" then
		if e.Medkits > 0 then
			e.Medkits -= 1
			residents:Wound(m.Id, Expeditions.Harm(maxHealth, 1, false))
			note(e, line(e, "Patched", { name = m.Name, place = place }), away)
		else
			note(e, line(e, "Lost", { name = m.Name, place = place }), away)
			lose(e, m, `lost on the {if e.Destination == "Deep" then "Deep" else "surface"} expedition`)
		end
	elseif event == "Distress" then
		local delay = t().CallDelay
		e.State = "Calling"
		e.CallIn = math.max(0, rng:NextNumber(delay.Min, delay.Max) - bunkerValue("DistressCallLeadSeconds"))
	else
		note(e, line(e, "Quiet", { names = Expeditions.Names(namesOf(e, { Away = true })), place = place }), away)
	end
	log:Info("%s lived cycle %d of %d: %s (%s)", e.Id, e.Done, e.Trip, event, findsText(e.Finds, e.Recruits, e.Blueprints))
	if #membersWith(e, "Away") == 0 and e.State == "Away" then
		publish(e)
		settle(e)
		return
	end
	if e.State == "Away" and e.Done >= e.Trip then
		-- a fast team turns for home early, with the finds of the whole length picked (Landon, Prompt 18)
		local still = membersWith(e, "Away")
		for _ = e.Trip + 1, e.Cycles do
			find(e, still)
		end
		if e.Trip < e.Cycles then
			note(e, line(e, "Early", { names = Expeditions.Names(namesOf(e, { Away = true })), place = place }), still)
		end
		comeHome(e)
		return
	end
	publish(e)
end

local function dawn(cycle: number)
	for _, e in sortedActive() do
		if e.State == "Away" and cycle > e.LeftAt then
			local ok, err = pcall(live, e)
			if not ok then
				log:Warn("%s: %s", e.Id, tostring(err))
			end
		end
	end
	-- the Radio Room picks up a Lost Crew's call now and then
	if cycle - lastHintCycle >= t().RadioHintCycles and crewCall(false) then
		lastHintCycle = cycle
	end
end

local function tick(dt: number)
	local works = radioWorks()
	if works ~= radioHeard then
		radioHeard = works
		setState("RadioWorks", works)
	end
	if not clock:IsRunning() or director:Phase() ~= "Playing" then
		return
	end
	local running = dt * clock:TimeScale()
	for _, e in sortedActive() do
		if e.State == "Calling" and e.CallIn then
			e.CallIn -= running
			if e.CallIn <= 0 then
				local ok, err = pcall(call, e)
				if not ok then
					log:Warn("%s call: %s", e.Id, tostring(err))
				end
			end
		end
	end
	local rate = radioRate()
	if rate > 0 then
		local whole, rest = Economy.Accrue(radioProgress, rate, running, Economy.CycleSeconds())
		radioProgress = rest
		for _ = 1, whole do
			radioRecruit()
		end
	end
end

-- The consoles ------------------------------------------------------------------------------------------

local function consolePrompt(anchor: BasePart, label: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ExpeditionsPrompt"
	prompt.ActionText = "EXPEDITIONS"
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", "Expeditions") -- ExpeditionsController opens the screen
	prompt.Parent = anchor
end

-- A radio set (the A6 recorder) on a Radio Room's console, so the room shows where to send from.
local function radioSet(anchor: BasePart, at: Vector3)
	local assets = game:GetService("ServerStorage"):FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local source = props and props:FindFirstChild("Prop_RadioLog")
	if not source or not source:IsA("Model") then
		return
	end
	local radio = source:Clone()
	radio.Name = "Radio"
	radio:SetAttribute("Find", nil)
	for _, part in radio:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	radio:ScaleTo(RADIO_SCALE)
	radio:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi, 0)) -- facing into the room
	radio.Parent = anchor
end

local function syncConsoles()
	local root = grid:Root()
	if not root then
		return
	end
	local holder = root:FindFirstChild("ExpeditionConsoles")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "ExpeditionConsoles"
		holder.Parent = root
	end
	local wanted: { [string]: { At: Vector3, Label: string, Radio: Vector3? } } = {}
	-- the Blast Door guard's desk and its radio (Kit_BlastDoor), or beside the door in a graybox hall
	local door = grid:RoomsOfType("BlastDoor")[1]
	local doorModel = door and grid:RoomModel(door.Id)
	local desk = doorModel and doorModel:FindFirstChild("GuardDesk", true)
	local socket = doorSocket()
	if desk and desk:IsA("BasePart") then
		wanted.Hall = { At = desk.Position + Vector3.new(0, desk.Size.Y / 2 + 1.5, 0), Label = "Blast Door radio" }
	elseif socket then
		wanted.Hall = { At = socket.Position + BLAST_CONSOLE, Label = "Blast Door radio" }
	end
	local g = Grid.Tuning()
	for _, room in grid:RoomsOfType("RadioRoom") do
		local model = grid:RoomModel(room.Id)
		local socket = model and BunkerKit.Socket(model, "Console")
		local cell = Grid.CellPosition(room.Floor, room.Column + (room.Span - 1) / 2)
		local spot = if socket then socket.Position else cell + Vector3.new(0, 0, -g.CellDepth / 2 + RADIO_CONSOLE_BACK)
		-- the set stands on whatever is there: a desk, or the floor
		local top = spot.Y
		if model then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { model }
			local hit = workspace:Raycast(spot + Vector3.new(0, 8, 0), Vector3.new(0, -12, 0), params)
			if hit then
				top = hit.Position.Y
			end
		end
		local base = Vector3.new(spot.X, top, spot.Z)
		wanted[`Radio {room.Id}`] = { At = base + Vector3.new(0, 1.8, 0), Label = "Radio Room", Radio = base }
	end
	for _, child in (holder :: Folder):GetChildren() do
		if not wanted[child.Name] then
			child:Destroy()
		end
	end
	for name, spec in wanted do
		local anchor = (holder :: Folder):FindFirstChild(name) :: BasePart?
		if not anchor then
			local part = Instance.new("Part")
			part.Name = name
			part.Size = Vector3.new(1, 1, 1)
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Parent = holder
			consolePrompt(part, spec.Label)
			anchor = part
		end
		(anchor :: BasePart).CFrame = CFrame.new(spec.At)
		local radio = (anchor :: BasePart):FindFirstChild("Radio")
		if spec.Radio and not radio then
			radioSet(anchor :: BasePart, spec.Radio)
		elseif radio and spec.Radio then
			(radio :: Model):PivotTo(CFrame.new(spec.Radio) * CFrame.Angles(0, math.pi, 0))
		end
	end
end

-- Modifiers ----------------------------------------------------------------------------------------------

function ExpeditionService:SetModifier(source: string, key: string, value: number?)
	assert(table.find(MODIFIER_KEYS, key), `ExpeditionService: {key} isn't a modifier it applies`)
	bunkerModifiers[key] = bunkerModifiers[key] or {}
	bunkerModifiers[key][source] = value
end

function ExpeditionService:Active(): number
	local n = 0
	for _ in expeditions do
		n += 1
	end
	return n
end

-- DevTools ---------------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	for _, e in sortedActive() do
		local members = {}
		for _, m in e.Members do
			table.insert(members, `{m.Id} {m.Name} ({m.Status}{if m.Rescue then ` {m.Rescue}` else ""})`)
		end
		table.insert(lines, string.format("%s %s%s: %s; cycle %d of %d%s (left at %d), %s%s; packs %d food %d water %d medkits; finds %s",
			e.Id, e.Destination, if e.Band then ` ({e.Band})` else "", table.concat(members, ", "), e.Done, e.Trip,
			if e.Trip < e.Cycles then ` (a fast team: {e.Cycles} picked)` else "", e.LeftAt, e.State,
			if e.CallIn then string.format(" in %.0fs", e.CallIn) elseif e.Deadline then ` deadline cycle {e.Deadline} at {e.Where}` else "",
			e.Food, e.Water, e.Medkits, findsText(e.Finds, e.Recruits, e.Blueprints)))
		for _, entry in e.Log do
			table.insert(lines, `    {entry}`)
		end
	end
	table.insert(lines, string.format("radio: %s; %.3f recruits a cycle (RecruitRate %.2f), progress %.2f; lead %ds; residents %d of %d",
		if radioWorks() then "a Radio Room hears calls" else "NO working Radio Room (a call goes unheard)",
		radioRate(), bunkerValue("RecruitRate"), radioProgress, bunkerValue("DistressCallLeadSeconds"), residents:Count(), Constants.CAPS.Residents))
	return table.concat(lines, "\n")
end

local function pickExpedition(id: any): Expedition?
	if type(id) == "string" and expeditions[id] then
		return expeditions[id]
	end
	return sortedActive()[1]
end

function ExpeditionService:Init(registry)
	setState = RunState.Writer("ExpeditionService")
	grid = registry.BunkerGrid
	clock = registry.CycleClock
	director = registry.RunDirector
	session = registry.SessionService
	economy = registry.EconomyService
	residents = registry.ResidentService
	brain = registry.ResidentBrain
	rescue = registry.RescueService
	surface = registry.SurfaceService
	deep = registry.DeepService
	collection = registry.ReplicationService:Collection("Expeditions")
	Remotes.OnServer("SendExpedition", function(player: Player, destination: string, members: { string }, cycles: number, medkits: number)
		local id, why = ExpeditionService:Send(destination, members, cycles, medkits, player)
		if not id and why then
			Remotes.FireClient("Alert", player, "Warning", why)
		end
	end)
	local dev = registry.DevService
	dev:Register("exp", {
		Description = "Expeditions out, their logs, and the Radio Room (Prompt 18).",
		Usage = "exp",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("exp.send", {
		Description = "Send an expedition from anywhere: destination, cycles, Medkits, resident ids.",
		Usage = "exp.send <surface|deep> <cycles> <medkits> <id> [id] [id]",
		Run = function(_player: Player?, args): string?
			local destination = if string.lower(tostring(args[1] or "")) == "deep" then "Deep" else "Surface"
			local ids = {}
			for i = 4, 6 do
				if args[i] then
					table.insert(ids, tostring(args[i]))
				end
			end
			local id, why = ExpeditionService:Send(destination, ids, tonumber(args[2]) or 1, tonumber(args[3]) or 0, nil)
			return if id then `sent {id}\n{describe()}` else `refused: {why}`
		end,
	})
	dev:Register("exp.cycle", {
		Description = "Every expedition away lives a cycle now (as at dawn); an event forces what happens.",
		Usage = "exp.cycle [Quiet|Hurt|Lost|Distress]",
		Run = function(_player: Player?, args): string?
			local wanted = tostring(args[1] or "")
			local forced = if table.find({ "Quiet", "Hurt", "Lost", "Distress" }, wanted) then wanted else nil
			for _, e in sortedActive() do
				if e.State == "Away" then
					live(e, forced)
				end
			end
			return describe()
		end,
	})
	dev:Register("exp.call", {
		Description = "An expedition radios for help now.",
		Usage = "exp.call [id]",
		Run = function(_player: Player?, args): string?
			local e = pickExpedition(args[1])
			if not e or (e.State ~= "Away" and e.State ~= "Calling") then
				return "no expedition away to call"
			end
			call(e)
			return describe()
		end,
	})
	dev:Register("exp.home", {
		Description = "An expedition away comes home now.",
		Usage = "exp.home [id]",
		Run = function(_player: Player?, args): string?
			local e = pickExpedition(args[1])
			if not e or e.State ~= "Away" then
				return "no expedition away"
			end
			comeHome(e)
			return describe()
		end,
	})
	dev:Register("exp.deadline", {
		Description = "A distress call's time runs out now: whoever is still pinned down is lost.",
		Usage = "exp.deadline",
		Run = function(): string?
			deadline(true)
			return describe()
		end,
	})
	dev:Register("recruit", {
		Description = "A recruit answers the radio now (Common, or the tier given).",
		Usage = "recruit [tier]",
		Run = function(_player: Player?, args): string?
			local id = ExpeditionService:Recruit(if args[1] then tostring(args[1]) else nil, "answered the Radio Room's call")
			return if id then `recruited {id}` else "turned away (the bunker is full)"
		end,
	})
	dev:Register("radio", {
		Description = "The Radio Room's state; 'radio call' plays a Lost Crew's call now.",
		Usage = "radio [call]",
		Run = function(_player: Player?, args): string?
			if tostring(args[1] or "") == "call" then
				return if crewCall(true) then "played a crew's call" else "no Lost Crew is out"
			end
			return describe()
		end,
	})
end

function ExpeditionService:Start()
	rescue:SetArrival("Expedition", arrived)
	rescue.Freed:Connect(helped)
	rescue.Lost:Connect(strayLost)
	clock.CycleStarted:Connect(dawn)
	clock.SurgeStarted:Connect(function()
		deadline(false)
	end)
	syncConsoles()
	grid.Changed:Connect(syncConsoles)
	RunService.Heartbeat:Connect(tick)
	log:Info("expedition consoles: %d", if consoles() then #(consoles() :: Folder):GetChildren() else 0)
end

return ExpeditionService
