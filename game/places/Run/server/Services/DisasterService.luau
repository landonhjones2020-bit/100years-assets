--!strict
--[[
	DisasterService: fires, blackouts, cave-ins, the Reactor meltdown and electrical surges (bible
	Section 10, with Sections 5, 6 and 23). Run place only; Prompt 13. The arithmetic is
	Shared.Rules.Disasters; the numbers are Config.Disasters and Tuning.Disasters (provisional).

	* Fire: a room burns with a strength (0 to 100) that grows. Every SpreadSeconds (15; FireSpread
	  multipliers slow it) a fire strong enough spreads through a doorway to the next room. It
	  burns the room's HP, the residents in it and the players in it (Firefighters take a
	  quarter). Residents caught in it beat it down (ResidentBrain's Extinguish), an Extinguisher
	  sprays it down (WeaponService.ToolTick; the Firefighter 3x), a Foam Grenade puts out every
	  fire in its burst (WeaponService.Foamed). At 0 it is out.
	* Blackout: a floor or the whole grid goes dark (PowerService:SetBlackout) for
	  DurationSeconds (BlackoutDuration multipliers), unless someone resets the fuse box in the
	  Reactor Core first (hold Interact FuseSeconds).
	* Cave-in: rubble blocks a doorway, or fills a dug cell (a tunnel), and can trap residents
	  (Lib.Hazards blocks the passages; routes go around; residents with no way round are
	  trapped). Anyone under it is hurt. Melee smashes it (WeaponService.Swung; the Fire Axe and
	  the Sledgehammer three times as hard; a level 3 Firefighter's Fire Axe at once, Prompt 20)
	  and a Drill or a Pickaxe digs through it in one hold.
	  Digging and Tremors (Prompt 14) bring cave-ins: CaveIn(floor, column, side?).
	* The meltdown (Section 10's Reactor overload; Landon, 2026-11-08): a Reactor Core at 0 HP
	  (BunkerGrid.Wrecked), or an overclocked one (Prompt 19), starts a 60-second meltdown. Three
	  valves in the Reactor Core turned at the same time stop it; with 1 or 2 players each turned
	  valve stays turned for 10 seconds. A meltdown that runs out loses the run
	  ("ReactorDestroyed"). It also starts a fire in the Reactor Core (Section 10: Reactor
	  overloads cause fires). The Reactor stays wrecked until it is repaired.
	* Electrical surge (Section 10: random, more often in Era III; ThreatDirector rolls one a
	  day): sparks damage the machines in one room for DurationSeconds; welding the room ends it
	  (BuildService.Repaired). Left alone it may end in a fire or a blackout of its floor.
	* The Surge's one disaster (Section 5): ThreatDirector pays for it from the Surge's budget
	  (SurgeDisaster) and it starts SurgeDelaySeconds into the Surge, a fire in a random room or
	  a blackout. A Surge can't end early while its disaster, a fire or a meltdown is on
	  (HoldsSurge; Section 5).

	* Flood (Prompt 23): water in a room with a level (0 to 100). A burst pipe raises it until
	  someone patches the pipe (hold Interact); then it drains. Water high enough pours through a
	  doorway or down the Shaft every SpreadSeconds (never up), and a room it has reached rises
	  towards its source. It ruins the room, slows and hurts whoever is deep in it (the Firefighter
	  a quarter). StartFlood(room, cause, level?, pipe?); a Bloat Toad's burst and The Deluge
	  bring water without a pipe. Foam Burst drains a room at once (Drain).
	* Gas leak (Prompt 23): gas in a room with a strength (0 to 100) that fills while its vent
	  leaks, for DurationSeconds, unless someone seals the vent (hold Interact); then the room airs
	  out. It hurts everyone in it (GasImmune players not at all; the bunker's GasStrength scales
	  it). Decon Field clears a room at once (ClearGas).
	* A hazard pocket found by digging bursts gas or water into the digger's room (HazardPocket); in
	  the Crystal Hollows it opens a crystal seam that leaks radiation into it (Prompt 24).
	* Radiation leak (Prompt 24; Section 10: "Surface storms against a weak Blast Door. Floor 1 fills
	  with radiation. Seal or upgrade the door; Decon Room."). As each Surge's storm hits, from Era
	  III, it may get through the Blast Door (Rules.Disasters.DoorLeakChance: its level, its lost
	  HP). The leak has a strength (0 to 100) on every open cell of the door's floor: it fills until
	  someone seals the door (hold Interact), the door goes up a level, or DurationSeconds pass;
	  then it fades. A working Decon Room slows the fill. Players in it gain radiation (their
	  InRadiation attribute; SurfaceService keeps the meter); residents lose health, leave, and
	  from IrradiateAt are Irradiated until a Decon Room clears them (ResidentService).
	* Outbreak (Prompt 24; Section 10: "A sickness spreads between residents. Medbay treatment and
	  quarantine in Quarters."). From Era III someone who comes in from the Deep may carry it
	  (FromTheDeep: RescueService, ExpeditionService). The Sick pass it on to others in their room
	  every SpreadSeconds; a sick resident with no job keeps to a Quarters bed and passes nothing on
	  (quarantine); a working Medbay cures one patient every CureSeconds. It ends when nobody is sick.

	Disasters run while the run is playing (like monsters and residents, they go on when DevTools
	pause the cycle clock).

	Replication: the Disasters collection, id -> one of
	  { Kind = "Fire", Room, Strength, Cause }                       id "F:<room>"
	  { Kind = "Blackout", Floor?, Rooms, EndsAt, Cause }             id "B:<n>" (Floor nil: the grid)
	  { Kind = "Rubble", Shape, Floor, Column, Side?, HP, MaxHP, Cause, Edges }  id "C:<n>"
	  { Kind = "Meltdown", Room, EndsAt, Valves, Solo, Cause }        id "M:<n>"; Valves: 0 open,
	                                                                  -1 held, else turned until
	  { Kind = "Surge", Room, EndsAt, Cause }                         id "S:<room>"
	  { Kind = "Flood", Room, Level, Pipe, Cause }                    id "W:<room>"
	  { Kind = "Gas", Room, Strength, Leaking, EndsAt, Cause }        id "G:<room>"
	  { Kind = "Radiation", Floor, Room?, Units, Strength, Leaking, EndsAt, Cause }  id "R:Door" or "R:<room>"
	  { Kind = "Outbreak", Sick, Quarantined, Patient?, Cure, Treating, Cause }      id "O:<n>"
	and RunState Fires, BlackoutRooms, Rubble, Floods, GasLeaks, Meltdown, MeltdownEndsAt, ValvesTurned.
	workspace.Bunker.Disasters holds the fuse box and valve prompts, the rubble, burst pipes
	("Pipe:<room>") and leaking vents ("GasVent:<room>"). Players in water or gas carry the Wading
	and InGas attributes (the level or strength where they stand).

	API:
		DisasterService:StartFire(roomId, cause, strength?): string?
		DisasterService:Extinguish(roomId, amount, how, player?): boolean   -- true when it went out
		DisasterService:StartBlackout(floor?, cause): string?             -- floor nil: the whole grid
		DisasterService:EndBlackout(how, player?)
		DisasterService:CaveIn(floor, column, side?, cause): (string?, string?) -- side "Left"/"Right": a doorway
		DisasterService:ClearRubble(id, how, player?)
		DisasterService:StartMeltdown(cause): boolean
		DisasterService:StartElectricalSurge(roomId, cause): string?
		DisasterService:StartFlood(roomId, cause, level?, pipe?): string?  -- pipe false: no burst pipe
		DisasterService:PatchPipe(roomId, how, player?): boolean
		DisasterService:Drain(roomId, how, player?): boolean               -- at once (Foam Burst)
		DisasterService:Flooded(roomId): number?
		DisasterService:StartGasLeak(roomId, cause, strength?): string?
		DisasterService:SealVent(roomId, how, player?): boolean
		DisasterService:ClearGas(roomId, how, player?): boolean            -- at once (Decon Field)
		DisasterService:Gassed(roomId): number?
		DisasterService:HazardPocket(floor, column, player?): string?      -- "Flood", "GasLeak", "RadiationLeak" or nil
		DisasterService:StartRadiationLeak(cause, roomId?, strength?): string? -- roomId nil: the Blast Door's, its whole floor
		DisasterService:SealLeak(id, how, player?): boolean
		DisasterService:ClearRadiation(roomId, how, player?): boolean       -- at once (Decon Field)
		DisasterService:Irradiated(unit): number?
		DisasterService:StartOutbreak(cause, residentId?): string?
		DisasterService:FromTheDeep(residentId, why): boolean               -- rolls for a carrier
		DisasterService:Cure(residentId, how, player?): boolean
		DisasterService:SurgeDisaster(budget, rng): number   -- ThreatDirector: the ThreatCost spent
		DisasterService:HoldsSurge(): boolean                -- ThreatDirector: don't end the Surge yet
		DisasterService:SetModifier(source, key, value?)     -- FireSpread, BlackoutDuration
		DisasterService:Active(): { [string]: any }          -- the collection's entries
		DisasterService.Started: Signal<string, string>      -- id, kind
		DisasterService.Ended: Signal<string, string, string> -- id, kind, how
	Dev: disasters, fire, fire.out, blackout, blackout.end, cavein, rubble.clear, meltdown,
	meltdown.stop, valve, esurge, disaster.surge, flood, flood.patch, flood.drain, gas, gas.seal,
	gas.clear, pocket, leak, leak.storm, leak.seal, leak.clear, outbreak, outbreak.cure, outbreak.deep.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Rules.Combat)
local Config = require(Shared.Config)
local Disasters = require(Shared.Rules.Disasters)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)
local Hazards = require(ServerScriptService.Lib.Hazards)

local log = Log.new("DisasterService")

local DisasterService = {
	Name = "DisasterService",
	Dependencies = {
		"BunkerGrid", "PowerService", "CycleClock", "RunDirector", "CombatService", "WeaponService",
		"ResidentService", "BuildService", "SessionService", "ReplicationService", "DevService",
	},
	Started = Signal.new() :: Signal.Signal<string, string>,
	Ended = Signal.new() :: Signal.Signal<string, string, string>,
}

local CAMERA_FADE_TAG = BunkerKit.CAMERA_FADE_TAG
local CAMERA_IGNORE_TAG = "CameraIgnore"
local ROCK = Color3.fromRGB(104, 92, 78)
local ROCK_DARK = Color3.fromRGB(72, 64, 56)
local TIMBER = Color3.fromRGB(118, 94, 72)

type Fire = { Id: string, Room: string, Strength: number, NextSpread: number, Carry: number, Cause: string, Sent: number }
type Blackout = { Id: string, Floor: number?, Units: { [string]: boolean }, EndsAt: number, Cause: string }
type Rubble = {
	Id: string,
	Shape: Disasters.Shape,
	Floor: number,
	Column: number,
	Side: string?,
	HP: number,
	MaxHP: number,
	Cause: string,
	Model: Model?,
	Points: { Vector3 }, -- where melee can hit it (each blocked face)
	Height: number,
	Edges: { { string } },
}
type Meltdown = { Id: string, Room: string, EndsAt: number, Valves: { number }, Cause: string, Sent: string }
type Surge = { Id: string, Room: string, EndsAt: number, Carry: number, Cause: string }
type Flood = {
	Id: string, Room: string, Level: number, Pipe: boolean, NextSpread: number, Carry: number, Cause: string,
	Sent: number, SentPipe: boolean, Prop: Instance?,
}
type Gas = {
	Id: string, Room: string, Strength: number, Leaking: boolean, EndsAt: number, Cause: string,
	Sent: number, SentLeaking: boolean, Prop: Instance?,
}
-- A radiation leak (Prompt 24): the Blast Door's fills its floor (Room nil), a hazard pocket's one room.
type Leak = {
	Id: string, Floor: number, Room: string?, Strength: number, Leaking: boolean, EndsAt: number, Cause: string,
	Sent: number, SentLeaking: boolean, Prop: Instance?, Units: { [string]: boolean }, DoorLevel: number?,
}
type Outbreak = {
	Id: string, Cause: string, NextSpread: number, Cure: number, Patient: string?, Immune: { [string]: boolean }, Sent: string,
}

local grid: any = nil
local power: any = nil
local clock: any = nil
local director: any = nil
local combat: any = nil
local weapons: any = nil
local residents: any = nil
local builds: any = nil
local session: any = nil
local collection: any = nil
local set: (string, any) -> () = function() end

local rng = Random.new()
local fires: { [string]: Fire } = {} -- by room id
local blackout: Blackout? = nil
local rubble: { [string]: Rubble } = {}
local meltdown: Meltdown? = nil
local surges: { [string]: Surge } = {} -- by room id
local floods: { [string]: Flood } = {} -- by room id (Prompt 23)
local gases: { [string]: Gas } = {} -- by room id (Prompt 23)
local leaks: { [string]: Leak } = {} -- radiation, by id: "R:Door" or "R:<room>" (Prompt 24)
local outbreak: Outbreak? = nil -- Prompt 24
local surgeDisaster: { Kind: string, Id: string?, Cycle: number }? = nil
local modifiers: { [string]: { [string]: number } } = {} -- key -> source -> value
local counter = 0
local folder: Folder? = nil
local fuseBox: BasePart? = nil
local valveParts: { BasePart } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function nextId(prefix: string): string
	counter += 1
	return `{prefix}:{counter}`
end

local function roomName(roomType: string): string
	local info = Config.Find("Rooms", roomType)
	return if info then string.upper(info.Name) else string.upper(roomType)
end

local function nameOf(roomId: string): string
	local room = grid:Room(roomId)
	return if room then `THE {roomName(room.Type)}` else "A ROOM"
end

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function playerCount(): number
	return math.max(#session:ReadyPlayers(), 1)
end

local function modifierValue(key: string): number
	local value = 1
	for _, v in modifiers[key] or {} do
		value *= v
	end
	return value
end

local function unitAt(position: Vector3): string?
	local floor, column = Grid.CellAt(position)
	if not floor or not column then
		return nil
	end
	return grid:Bunker():UnitAt(floor, column)
end

local function holder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local root = grid:Root()
	if not root then
		return nil
	end
	local found = root:FindFirstChild("Disasters")
	if not found then
		found = Instance.new("Folder")
		found.Name = "Disasters"
		found.Parent = root
	end
	folder = found :: Folder
	return folder
end

-- The living players and residents in each unit.
local function occupants(): { [string]: { any } }
	local by: { [string]: { any } } = {}
	for _, c in combat:All("Survivors") do
		if c.State == "Alive" and c.Root.Parent then
			local unit = unitAt(c.Root.Position)
			if unit then
				by[unit] = by[unit] or {}
				table.insert(by[unit], c)
			end
		end
	end
	return by
end

-- Replication -----------------------------------------------------------------------------------------

local function publishCounts()
	local fireCount, rubbleCount, floodCount, gasCount = 0, 0, 0, 0
	for _ in fires do
		fireCount += 1
	end
	for _ in floods do
		floodCount += 1
	end
	for _ in gases do
		gasCount += 1
	end
	for _ in rubble do
		rubbleCount += 1
	end
	local dark = 0
	if blackout then
		for unit in blackout.Units do
			if grid:Room(unit) then
				dark += 1
			end
		end
	end
	set("Fires", fireCount)
	set("Rubble", rubbleCount)
	set("Floods", floodCount)
	set("GasLeaks", gasCount)
	local leakCount, sick = 0, 0
	for _ in leaks do
		leakCount += 1
	end
	if outbreak then
		for _, resident in residents:All() do
			if resident.Sick and resident.State ~= "Dead" then
				sick += 1
			end
		end
	end
	set("RadiationLeaks", leakCount)
	set("Sick", sick)
	set("BlackoutRooms", dark)
	set("Meltdown", if meltdown then true else nil)
	set("MeltdownEndsAt", if meltdown then meltdown.EndsAt else nil)
	set("ValvesTurned", if meltdown then Disasters.ValvesOn(meltdown.Valves, now()) else nil)
end

local function publishFire(fire: Fire)
	fire.Sent = math.ceil(fire.Strength)
	collection:Set(fire.Id, { Kind = "Fire", Room = fire.Room, Strength = fire.Sent, Cause = fire.Cause })
end

local function publishRubble(r: Rubble)
	local edges = {}
	for _, edge in r.Edges do
		table.insert(edges, `{edge[1]}|{edge[2]}`)
	end
	collection:Set(r.Id, {
		Kind = "Rubble", Shape = r.Shape, Floor = r.Floor, Column = r.Column, Side = r.Side,
		HP = math.ceil(r.HP), MaxHP = r.MaxHP, Cause = r.Cause, Edges = edges,
	})
end

local function valveStates(m: Meltdown): { number }
	local t = now()
	local list = {}
	for i, value in m.Valves do
		list[i] = if value == Disasters.HELD then Disasters.HELD elseif value > t then value else 0
	end
	return list
end

local function publishMeltdown(m: Meltdown)
	local valves = valveStates(m)
	local key = table.concat(valves, ",")
	if key == m.Sent then
		return
	end
	m.Sent = key
	collection:Set(m.Id, {
		Kind = "Meltdown", Room = m.Room, EndsAt = m.EndsAt, Valves = valves,
		Solo = playerCount() <= Disasters.Tuning().Meltdown.SoloPlayers, Cause = m.Cause,
	})
end

-- Fire --------------------------------------------------------------------------------------------------

function DisasterService:StartFire(roomId: string, cause: string, strength: number?): string?
	local room = grid:Room(roomId)
	if not room or not Disasters.Burns(room.Type) or fires[roomId] then
		return nil
	end
	local fire: Fire = {
		Id = `F:{roomId}`,
		Room = roomId,
		Strength = strength or Disasters.Tuning().Fire.StartStrength,
		NextSpread = now() + Disasters.SpreadSeconds(modifierValue("FireSpread")),
		Carry = 0,
		Cause = cause,
		Sent = -1,
	}
	fires[roomId] = fire
	Hazards.SetFire(roomId, fire.Strength)
	publishFire(fire)
	publishCounts()
	log:Info("fire in %s (%s): %s", roomId, room.Type, cause)
	announce("Danger", if cause == "Spread" then `THE FIRE SPREADS TO {nameOf(roomId)}`
		else `FIRE IN {nameOf(roomId)}: PUT IT OUT BEFORE IT SPREADS`)
	DisasterService.Started:Fire(fire.Id, "Fire")
	return fire.Id
end

local function putOut(fire: Fire, how: string, player: Player?)
	if fires[fire.Room] ~= fire then
		return
	end
	fires[fire.Room] = nil
	Hazards.SetFire(fire.Room, nil)
	collection:Remove(fire.Id)
	publishCounts()
	log:Info("fire in %s out (%s%s)", fire.Room, how, if player then `, {player.Name}` else "")
	if how ~= "Gone" then
		announce("Info", `FIRE OUT IN {nameOf(fire.Room)}{if player then ` · {string.upper(player.DisplayName)}` else ""}`)
	end
	DisasterService.Ended:Fire(fire.Id, "Fire", how)
end

-- Puts `amount` of strength out of a room's fire. Returns true when it went out.
function DisasterService:Extinguish(roomId: string, amount: number, how: string, player: Player?): boolean
	local fire = fires[roomId]
	if not fire or amount <= 0 then
		return false
	end
	fire.Strength -= amount
	if fire.Strength <= 0 then
		putOut(fire, how, player)
		return true
	end
	Hazards.SetFire(roomId, fire.Strength)
	if math.ceil(fire.Strength) ~= fire.Sent then
		publishFire(fire)
	end
	return false
end

local function tickFires(dt: number, t: number, inside: { [string]: { any } })
	for roomId, fire in table.clone(fires) do
		local room = grid:Room(roomId)
		if not room then
			putOut(fire, "Gone")
			continue
		end
		local people = inside[roomId] or {}
		local fighters = 0
		for _, c in people do
			if c.Kind == "Resident" and c.Model:GetAttribute("Activity") == "Extinguish" then
				fighters += 1
			end
		end
		fire.Strength = Disasters.FireStep(fire.Strength, dt, fighters, 0)
		if fire.Strength <= 0 then
			putOut(fire, "Residents")
			continue
		end
		-- the room burns
		fire.Carry += Disasters.FireRoomDamage(fire.Strength, dt)
		if fire.Carry >= 1 and room.HP > 0 then
			local whole = math.floor(fire.Carry)
			fire.Carry -= whole
			grid:SetHP(roomId, room.HP - whole)
		end
		-- and so does everyone in it (Section 10: residents; the Firefighter's passive says players too)
		for _, c in people do
			if c.Kind == "Resident" then
				combat:Damage(c.Id, Disasters.FireResidentDamage(fire.Strength, dt), nil, "fire")
			elseif c.Kind == "Player" and c.Player then
				local taken = Modifiers.PlayerValue(c.Player, "FireFloodDamageTaken") or 1
				combat:Damage(c.Id, Disasters.FirePlayerDamage(fire.Strength, dt, taken), nil, "fire")
			end
		end
		-- it spreads to the next room (Section 10: every 15 seconds)
		if t >= fire.NextSpread then
			fire.NextSpread = t + Disasters.SpreadSeconds(modifierValue("FireSpread"))
			if Disasters.CanSpread(fire.Strength) then
				local targets = Disasters.SpreadTargets(grid:Bunker(), roomId, fires)
				if #targets > 0 then
					DisasterService:StartFire(targets[rng:NextInteger(1, #targets)], "Spread")
				end
			end
		end
		Hazards.SetFire(roomId, fire.Strength)
		if math.ceil(fire.Strength) ~= fire.Sent then
			publishFire(fire)
		end
	end
end

-- The Extinguisher: the first burning room along the player's facing within reach.
local function onToolTick(player: Player, tool: string, at: CFrame, dt: number)
	if tool ~= "Extinguisher" then
		return
	end
	local f = Disasters.Tuning().Fire
	local target: string? = nil
	for _, d in { 0, 4, 8, 12, f.ExtinguisherReach } do
		local unit = unitAt(at.Position + at.LookVector * d)
		if unit and fires[unit] then
			target = unit
			break
		end
	end
	player:SetAttribute("Spraying", target or "")
	if target then
		local speed = Modifiers.PlayerValue(player, "ExtinguishSpeed") or 1
		DisasterService:Extinguish(target, f.ExtinguisherPerSecond * speed * dt, "Extinguisher", player)
	end
end

-- A Foam Grenade puts out every fire whose room its burst reaches.
local function onFoamed(at: Vector3, radius: number, player: Player)
	local t = Grid.Tuning()
	for roomId, fire in table.clone(fires) do
		local room = grid:Room(roomId)
		if room then
			for offset = 0, room.Span - 1 do
				local cell = Grid.CellPosition(room.Floor, room.Column + offset)
				local low = cell - Vector3.new(t.CellWidth / 2, 0, t.CellDepth / 2)
				local high = cell + Vector3.new(t.CellWidth / 2, t.CellHeight, t.CellDepth / 2)
				local nearest = Vector3.new(math.clamp(at.X, low.X, high.X), math.clamp(at.Y, low.Y, high.Y), math.clamp(at.Z, low.Z, high.Z))
				if (nearest - at).Magnitude <= radius then
					putOut(fire, "Foam", player)
					break
				end
			end
		end
	end
end

-- Blackouts ---------------------------------------------------------------------------------------------

local function fusePosition(): Vector3?
	local reactor = grid:RoomsOfType("ReactorCore")[1]
	if not reactor then
		return nil
	end
	local model = grid:RoomModel(reactor.Id)
	local socket = if model then BunkerKit.Socket(model, "FuseBox") else nil
	if socket then
		return socket.Position + Vector3.new(0, 4, 0)
	end
	return Grid.CellPosition(reactor.Floor, reactor.Column) + Vector3.new(-12, 4, -6)
end

-- A crystal seam splits the back wall where nothing stands in front of it: the first clear stretch
-- of a few, low ones first, then above the furniture, then under the ceiling (Prompt 24's
-- playtests: the first seam grew behind the Medbay's cabinet and the second behind the Kitchen's
-- stove, where nobody could see them). Walls, floors and long runs of pipe are as wide as the
-- cell and don't count.
local SEAM_SIZE = Vector3.new(5.6, 5.2, 1.6)
local SEAM_VIEW = 5 -- studs in front of the wall that must be clear, so nothing hides it
local function wallClear(model: Instance, centre: Vector3, size: Vector3, widest: number): boolean
	local half = size / 2
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and math.max(d.Size.X, d.Size.Z) < widest then
			local cf = d.CFrame
			local s = d.Size / 2
			local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
			local ey = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
			local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
			local o = cf.Position - centre
			if math.abs(o.X) < ex + half.X and math.abs(o.Y) < ey + half.Y and math.abs(o.Z) < ez + half.Z then
				return false
			end
		end
	end
	return true
end

local function seamSpot(room: any): CFrame
	local g = Grid.Tuning()
	local model = grid:RoomModel(room.Id)
	local back = -(g.CellDepth / 2 - 0.8)
	local view = Vector3.new(SEAM_SIZE.X, SEAM_SIZE.Y, SEAM_VIEW)
	local last: CFrame? = nil
	for _, height in { 3, g.CellHeight * 0.6, g.CellHeight * 0.735 } do
		for span = 0, (room.Span or 1) - 1 do
			local cell = Grid.CellPosition(room.Floor, room.Column + span)
			for _, x in { -0.25, 0.25, 0, -0.38, 0.38, -0.12, 0.12 } do
				local at = cell + Vector3.new(g.CellWidth * x, height, back)
				-- the seam itself comes 1.5 studs out of the wall; the box starts just in front of the wall's trim
				if not model or wallClear(model, at + Vector3.new(0, 0, 0.3 + SEAM_VIEW / 2), view, g.CellWidth * 0.8) then
					return CFrame.new(at)
				end
				if x == -0.25 and span == 0 then
					last = CFrame.new(at) -- nothing clear anywhere: under the ceiling, where the least stands
				end
			end
		end
	end
	return last :: CFrame
end

-- The door's seal clamps the jamb, this far along the wall from the door's middle: the lift's own
-- prompt (RIDE UP) is at the middle, and of two prompts on one key Roblox shows the one nearer the
-- middle of the screen, so a seal there could not be reached (Prompt 24's playtest).
local DOOR_SEAL_SIDE = 8

local function promptPart(name: string, position: Vector3): BasePart?
	local parent = holder()
	if not parent then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	CollectionService:AddTag(part, CAMERA_IGNORE_TAG)
	part.Parent = parent
	return part
end

local function prompt(part: BasePart, kind: string, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController (Prompt 11)
	p:SetAttribute("Kind", kind)
	p.Parent = part
	return p
end

function DisasterService:EndBlackout(how: string, player: Player?)
	local current = blackout
	if not current then
		return
	end
	blackout = nil
	power:SetBlackout(nil)
	if fuseBox then
		fuseBox:Destroy()
		fuseBox = nil
	end
	collection:Remove(current.Id)
	publishCounts()
	log:Info("blackout %s over (%s)", current.Id, how)
	if how == "Fixed" then
		announce("Info", `FUSE BOX RESET{if player then ` BY {string.upper(player.DisplayName)}` else ""}: THE LIGHTS ARE BACK`)
	elseif how == "Expired" then
		announce("Info", "THE BLACKOUT IS OVER: THE LIGHTS ARE BACK")
	end
	DisasterService.Ended:Fire(current.Id, "Blackout", how)
end

function DisasterService:StartBlackout(floor: number?, cause: string): string?
	local units = Disasters.BlackoutUnits(grid:Bunker(), floor)
	if next(units) == nil then
		return nil
	end
	if blackout then
		DisasterService:EndBlackout("Replaced")
	end
	local id = nextId("B")
	local current: Blackout = {
		Id = id,
		Floor = floor,
		Units = units,
		EndsAt = now() + Disasters.BlackoutSeconds(modifierValue("BlackoutDuration")),
		Cause = cause,
	}
	blackout = current
	power:SetBlackout(units)
	local at = fusePosition()
	if at then
		local part = promptPart("FuseBox", at)
		if part then
			local p = prompt(part, "FuseBox", "Reset fuse box", "Reactor Core", Disasters.Tuning().FuseSeconds, 8)
			p.Triggered:Connect(function(player: Player)
				if blackout == current then
					DisasterService:EndBlackout("Fixed", player)
				end
			end)
			fuseBox = part
		end
	end
	local rooms = {}
	for unit in units do
		if grid:Room(unit) then
			table.insert(rooms, unit)
		end
	end
	table.sort(rooms)
	collection:Set(id, { Kind = "Blackout", Floor = floor, Rooms = rooms, EndsAt = current.EndsAt, Cause = cause })
	publishCounts()
	log:Info("blackout %s: %s (%s)", id, if floor then `floor {floor}` else "the whole grid", cause)
	announce("Danger", `BLACKOUT: {if floor then `FLOOR {floor} IS` else "THE WHOLE BUNKER IS"} DARK · RESET THE FUSE BOX IN THE REACTOR CORE`)
	DisasterService.Started:Fire(id, "Blackout")
	return id
end

-- Cave-ins ----------------------------------------------------------------------------------------------

local function art(name: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local kit = assets and assets:FindFirstChild("Kit")
	local found = kit and kit:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

-- Where rubble stands: for each blocked face, its centre, its size (thickness, height, width) and
-- the side a digger stands on.
type Face = { Centre: Vector3, Size: Vector3 }

local function facesOf(r: Rubble): { Face }
	local t = Grid.Tuning()
	local pitch = Grid.Pitch()
	local cell = Grid.CellPosition(r.Floor, r.Column)
	local faces: { Face } = {}
	if r.Shape == "Tunnel" then
		for _, dir in { -1, 1 } do
			table.insert(faces, {
				Centre = Vector3.new(cell.X + dir * pitch.X / 2, cell.Y + t.CellHeight / 2, cell.Z),
				Size = Vector3.new(2, t.CellHeight, t.CellDepth),
			})
		end
		return faces
	end
	local otherColumn = if r.Side == "Left" then r.Column - 1 else r.Column + 1
	local bunker = grid:Bunker()
	local roomSide = bunker:RoomAt(r.Floor, r.Column) ~= nil or bunker:RoomAt(r.Floor, otherColumn) ~= nil
	local wallX = (cell.X + Grid.CellPosition(r.Floor, otherColumn).X) / 2
	-- a room's side wall has the 8 x 10 doorway (the kit's); between two dug cells it is open rock
	local width = if roomSide then 8 else t.CellDepth
	local height = if roomSide then 10 else t.CellHeight
	table.insert(faces, { Centre = Vector3.new(wallX, cell.Y + height / 2, cell.Z), Size = Vector3.new(2, height, width) })
	return faces
end

-- A graybox pile: rocks and a broken timber across the face, sitting on the floor.
local function grayboxPile(parent: Model, face: Face, seed: number)
	local local_rng = Random.new(seed)
	local base = face.Centre - Vector3.new(0, face.Size.Y / 2, 0)
	local count = math.clamp(math.floor(face.Size.Z / 2.2), 4, 14)
	for i = 1, count do
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		local s = local_rng:NextNumber(1.8, 3.6)
		rock.Size = Vector3.new(s * local_rng:NextNumber(0.9, 1.6), s * local_rng:NextNumber(0.7, 1.1), s * local_rng:NextNumber(0.9, 1.4))
		local z = -face.Size.Z / 2 + (i - 0.5) * face.Size.Z / count + local_rng:NextNumber(-0.6, 0.6)
		local pileHeight = face.Size.Y * 0.75 * (1 - math.abs(z) / (face.Size.Z / 2 + 2))
		local y = local_rng:NextNumber(0.3, math.max(pileHeight, 1))
		rock.CFrame = CFrame.new(base + Vector3.new(local_rng:NextNumber(-1.8, 1.8), y, z))
			* CFrame.Angles(local_rng:NextNumber(-0.6, 0.6), local_rng:NextNumber(0, math.pi), local_rng:NextNumber(-0.6, 0.6))
		rock.Material = Enum.Material.Slate
		rock.Color = if i % 3 == 0 then ROCK_DARK else ROCK
		rock.Parent = parent
	end
	local beam = Instance.new("Part")
	beam.Name = "Timber"
	beam.Size = Vector3.new(0.9, 0.9, math.min(face.Size.Z * 0.9, 12))
	beam.CFrame = CFrame.new(base + Vector3.new(0.4, face.Size.Y * 0.35, 0.5)) * CFrame.Angles(0.5, 0.15, 0)
	beam.Material = Enum.Material.Wood
	beam.Color = TIMBER
	beam.Parent = parent
end

local function buildRubble(r: Rubble): Model?
	local parent = holder()
	if not parent then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = r.Id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("Shape", r.Shape)
	model:SetAttribute("HP", r.HP)
	model:SetAttribute("MaxHP", r.MaxHP)
	local faces = facesOf(r)
	local pile = Instance.new("Model")
	pile.Name = "Pile"
	pile.Parent = model
	for i, face in faces do
		-- the invisible block: nothing walks through until it is cleared
		local block = Instance.new("Part")
		block.Name = "Block"
		block.Anchored = true
		block.CanCollide = true
		block.CanQuery = false
		block.CanTouch = false
		block.CastShadow = false
		block.Transparency = 1
		block.Size = face.Size
		block.CFrame = CFrame.new(face.Centre)
		CollectionService:AddTag(block, CAMERA_IGNORE_TAG)
		block.Parent = model
		-- what you see: the art kit's pile, or a graybox one. A room's 8-wide doorway gets the
		-- doorway pile; a tunnel's ends and the open rock between two dug cells (32 wide) get the
		-- tunnel's rockfall.
		local source = art(if face.Size.Z > 12 then "Kit_Rubble_Tunnel" else "Kit_Rubble_Doorway")
		local floorAt = face.Centre - Vector3.new(0, face.Size.Y / 2, 0)
		if source then
			local copy = source:Clone()
			copy.Name = `Pile{i}`
			-- a filled tunnel: each pile sits inside the tunnel cell, its outer toe at the cell's
			-- end, so nothing spills into the room or the cell next door (a doorway's pile spills
			-- into both sides, as rubble through a doorway would)
			local at = floorAt
			if r.Shape == "Tunnel" then
				local inward = math.sign(Grid.CellPosition(r.Floor, r.Column).X - face.Centre.X)
				at += Vector3.new(inward * source:GetExtentsSize().Z / 2, 0, 0)
			end
			-- art faces -Z with its width along X: turn it to lie across the wall line
			copy:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.pi / 2, 0))
			copy.Parent = pile
		else
			local group = Instance.new("Model")
			group.Name = `Pile{i}`
			group.Parent = pile
			grayboxPile(group, face, r.Floor * 100 + r.Column * 7 + i)
		end
		-- the dig prompt (a Drill or a Pickaxe), on the face at chest height, from either side
		local spot = promptPart(`Dig{i}`, Vector3.new(face.Centre.X, floorAt.Y + 3.5, face.Centre.Z + math.min(face.Size.Z / 2 - 1, 4)))
		if spot then
			spot.Parent = model
			local p = prompt(spot, "DigRubble", "Dig through", "Rubble · Drill or Pickaxe",
				Disasters.DigSeconds(r.Shape), 9)
			p:SetAttribute("Rubble", r.Id)
			p.Triggered:Connect(function(player: Player)
				if rubble[r.Id] ~= r then
					return
				end
				if Disasters.CanDig(weapons:Items(player)) then
					DisasterService:ClearRubble(r.Id, "Dug", player)
				else
					Remotes.FireClient("Alert", player, "Warning", "DIGGING NEEDS A DRILL OR A PICKAXE: SMASH IT WITH A MELEE WEAPON")
				end
			end)
		end
	end
	for _, part in pile:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			CollectionService:AddTag(part, CAMERA_FADE_TAG)
		end
	end
	local _, size = pile:GetBoundingBox()
	r.Height = size.Y
	model.Parent = parent
	return model
end

-- The pile sinks as it is broken up (readable from across a room), then goes.
local function showDamage(r: Rubble)
	local model = r.Model
	local pile = model and model:FindFirstChild("Pile")
	if not model or not pile or not pile:IsA("Model") then
		return
	end
	model:SetAttribute("HP", math.ceil(r.HP))
	local base = pile:GetAttribute("BaseCFrame")
	if typeof(base) ~= "CFrame" then
		base = pile:GetPivot()
		pile:SetAttribute("BaseCFrame", base)
	end
	local sink = (1 - math.clamp(r.HP / r.MaxHP, 0, 1)) * r.Height * 0.55
	pile:PivotTo((base :: CFrame) - Vector3.new(0, sink, 0))
end

local function blockEdges(r: Rubble)
	Hazards.Unblock(r.Id)
	r.Edges = Disasters.RubbleEdges(grid:Bunker(), r.Shape, r.Floor, r.Column, r.Side)
	for _, edge in r.Edges do
		Hazards.Block(edge[1], edge[2], r.Id)
	end
end

function DisasterService:ClearRubble(id: string, how: string, player: Player?)
	local r = rubble[id]
	if not r then
		return
	end
	rubble[id] = nil
	Hazards.Unblock(id)
	if r.Model then
		r.Model:Destroy()
	end
	collection:Remove(id)
	publishCounts()
	log:Info("rubble %s cleared (%s%s)", id, how, if player then `, {player.Name}` else "")
	announce("Info", `THE WAY IS CLEAR{if player then ` · {string.upper(player.DisplayName)} ` .. (if how == "Dug" then "DUG THROUGH" else "SMASHED THROUGH") else ""}`)
	DisasterService.Ended:Fire(id, "Rubble", how)
end

-- Hurts whoever the rubble falls on (Section 10) and moves players out of the block.
local function fallOn(r: Rubble)
	local damage = Disasters.Tuning().CaveIn.Damage
	local tunnel = if r.Shape == "Tunnel" then grid:Bunker():UnitAt(r.Floor, r.Column) else nil
	for _, c in combat:All("Survivors") do
		if c.State == "Alive" and c.Root.Parent then
			local position = c.Root.Position
			local under = tunnel ~= nil and unitAt(position) == tunnel
			for _, face in facesOf(r) do
				local offset = position - face.Centre
				local inBlock = math.abs(offset.X) <= face.Size.X / 2 + 1 and math.abs(offset.Z) <= face.Size.Z / 2
					and math.abs(offset.Y) <= face.Size.Y / 2 + 3
				if inBlock then
					under = true
					if c.Kind == "Player" then
						-- step out of the block, on the side they stood
						local dir = if offset.X >= 0 then 1 else -1
						c.Root.CFrame = c.Root.CFrame + Vector3.new(dir * (face.Size.X / 2 + 2.5 - math.abs(offset.X)), 0, 0)
					end
				end
			end
			if under then
				combat:Damage(c.Id, damage, nil, "cave-in")
			end
		end
	end
end

function DisasterService:CaveIn(floor: number, column: number, side: string?, cause: string): (string?, string?)
	local shape: Disasters.Shape = if side then "Doorway" else "Tunnel"
	if side and side ~= "Left" and side ~= "Right" then
		return nil, "side must be Left or Right"
	end
	local edges = Disasters.RubbleEdges(grid:Bunker(), shape, floor, column, side)
	if #edges == 0 then
		return nil, if shape == "Tunnel" then "only a dug cell with a way into it can cave in" else "there is no doorway there"
	end
	for _, other in rubble do
		for _, edge in other.Edges do
			for _, new in edges do
				if Hazards.EdgeKey(edge[1], edge[2]) == Hazards.EdgeKey(new[1], new[2]) then
					return nil, "rubble already blocks it"
				end
			end
		end
	end
	local id = nextId("C")
	local hp = Disasters.RubbleHP(shape)
	local r: Rubble = {
		Id = id, Shape = shape, Floor = floor, Column = column, Side = side, HP = hp, MaxHP = hp,
		Cause = cause, Model = nil, Points = {}, Height = 6, Edges = edges,
	}
	for _, face in facesOf(r) do
		table.insert(r.Points, face.Centre)
	end
	rubble[id] = r
	blockEdges(r)
	r.Model = buildRubble(r)
	fallOn(r)
	publishRubble(r)
	publishCounts()
	local here = grid:Bunker():UnitAt(floor, column)
	local hereRoom = if here then grid:Room(here) else nil
	local where = if hereRoom then nameOf(hereRoom.Id) else `THE TUNNEL ON FLOOR {floor}`
	log:Info("cave-in %s: %s at %d,%d%s (%s)", id, shape, floor, column, if side then ` {side}` else "", cause)
	announce("Danger", `CAVE-IN: RUBBLE BLOCKS {if shape == "Tunnel" then where else `A DOORWAY OF {where}`} · DIG OR SMASH THROUGH IT`)
	DisasterService.Started:Fire(id, "Rubble")
	return id, nil
end

-- A melee swing landing: the first rubble in its arc takes the hit.
local function onSwung(player: Player, at: CFrame, reach: number, arc: number, damage: number, item: string, _heavy: boolean)
	for id, r in table.clone(rubble) do
		for _, point in r.Points do
			if Combat.InArc(at, point, reach, arc, 4) then
				r.HP -= Disasters.RubbleDamage(item, damage)
				-- the Firefighter's level 3: the Fire Axe clears rubble at once (Prompt 20)
				if item == "FireAxe" and Modifiers.PlayerValue(player, "RubbleClearInstant") then
					r.HP = 0
				end
				if r.HP <= 0 then
					DisasterService:ClearRubble(id, "Smashed", player)
				else
					showDamage(r)
					publishRubble(r)
				end
				return
			end
		end
	end
end

-- The meltdown ------------------------------------------------------------------------------------------

local function valvePositions(roomId: string): { Vector3 }
	local room = grid:Room(roomId)
	local model = grid:RoomModel(roomId)
	local list = {}
	if model then
		for i = 1, 3 do
			local socket = BunkerKit.Socket(model, `Valve{i}`)
			if socket then
				table.insert(list, socket.Position + Vector3.new(0, 3.5, 0))
			end
		end
	end
	if #list < 3 and room then
		table.clear(list)
		local cell = Grid.CellPosition(room.Floor, room.Column)
		for _, offset in { Vector3.new(-12, 3.5, -10), Vector3.new(12, 3.5, -10), Vector3.new(0, 3.5, -1.5) } do
			table.insert(list, cell + offset)
		end
	end
	return list
end

local function clearValves()
	for _, part in valveParts do
		part:Destroy()
	end
	table.clear(valveParts)
end

local function endMeltdown(how: string)
	local m = meltdown
	if not m then
		return
	end
	meltdown = nil
	clearValves()
	collection:Remove(m.Id)
	publishCounts()
	log:Info("meltdown %s over (%s)", m.Id, how)
	if how == "Fixed" then
		local room = grid:Room(m.Room)
		announce("Info", if room and room.Wrecked then "THE REACTOR IS STABLE · REPAIR IT TO GET ITS POWER BACK"
			else "THE REACTOR IS STABLE")
	elseif how == "Lost" then
		announce("Danger", "THE REACTOR CORE MELTED DOWN")
	end
	DisasterService.Ended:Fire(m.Id, "Meltdown", how)
end

function DisasterService:StartMeltdown(cause: string): boolean
	if meltdown or director:Phase() ~= "Playing" then
		return false
	end
	local reactor = grid:RoomsOfType("ReactorCore")[1]
	if not reactor then
		return false
	end
	local seconds = Config.Get("Disasters", "ReactorOverload").TimerSeconds or 60
	local m: Meltdown = { Id = nextId("M"), Room = reactor.Id, EndsAt = now() + seconds, Valves = { 0, 0, 0 }, Cause = cause, Sent = "" }
	meltdown = m
	clearValves()
	for i, position in valvePositions(reactor.Id) do
		local part = promptPart(`Valve{i}`, position)
		if part then
			part:SetAttribute("Valve", i)
			local p = prompt(part, "Valve", "Turn valve", `Valve {i}`, Disasters.Tuning().ValveSeconds, 7)
			p.Triggered:Connect(function(player: Player)
				if meltdown == m then
					m.Valves[i] = Disasters.ValveTurned(playerCount(), now())
					log:Info("%s turned valve %d", player.Name, i)
					publishMeltdown(m)
				end
			end)
			p.TriggerEnded:Connect(function(_player: Player)
				if meltdown == m then
					m.Valves[i] = Disasters.ValveReleased(m.Valves[i], playerCount(), now())
					publishMeltdown(m)
				end
			end)
			table.insert(valveParts, part)
		end
	end
	publishMeltdown(m)
	publishCounts()
	log:Warn("REACTOR MELTDOWN (%s): %d s", cause, seconds)
	announce("Danger", if playerCount() <= Disasters.Tuning().Meltdown.SoloPlayers
		then `REACTOR MELTDOWN IN {seconds} S: TURN ALL THREE VALVES IN THE REACTOR CORE · EACH STAYS TURNED {Disasters.Tuning().Meltdown.SoloValveSeconds} S`
		else `REACTOR MELTDOWN IN {seconds} S: TURN ALL THREE VALVES IN THE REACTOR CORE AT ONCE`)
	DisasterService.Started:Fire(m.Id, "Meltdown")
	if Disasters.Tuning().Meltdown.StartsFire then
		DisasterService:StartFire(reactor.Id, "Meltdown")
	end
	return true
end

local function tickMeltdown(t: number)
	local m = meltdown
	if not m then
		return
	end
	if Disasters.MeltdownStopped(m.Valves, t) then
		endMeltdown("Fixed")
		return
	end
	if t >= m.EndsAt then
		endMeltdown("Lost")
		director:Lose("ReactorDestroyed") -- Section 5: the Reactor Core melts down
		return
	end
	publishMeltdown(m)
	set("ValvesTurned", Disasters.ValvesOn(m.Valves, t))
end

-- Electrical surges -------------------------------------------------------------------------------------

function DisasterService:StartElectricalSurge(roomId: string, cause: string): string?
	local room = grid:Room(roomId)
	if not room or surges[roomId] or room.Type == "Shaft" then
		return nil
	end
	local info = Config.Get("Disasters", "ElectricalSurge")
	local s: Surge = { Id = `S:{roomId}`, Room = roomId, EndsAt = now() + (info.DurationSeconds or 20), Carry = 0, Cause = cause }
	surges[roomId] = s
	collection:Set(s.Id, { Kind = "Surge", Room = roomId, EndsAt = s.EndsAt, Cause = cause })
	log:Info("electrical surge in %s (%s)", roomId, cause)
	announce("Warning", `ELECTRICAL SURGE IN {nameOf(roomId)}: WELD IT BEFORE IT SPARKS A FIRE`)
	DisasterService.Started:Fire(s.Id, "Surge")
	return s.Id
end

local function endSurge(s: Surge, how: string, player: Player?)
	if surges[s.Room] ~= s then
		return
	end
	surges[s.Room] = nil
	collection:Remove(s.Id)
	log:Info("electrical surge in %s over (%s)", s.Room, how)
	if how == "Fixed" then
		announce("Info", `THE SURGE IN {nameOf(s.Room)} IS WELDED{if player then ` · {string.upper(player.DisplayName)}` else ""}`)
	end
	DisasterService.Ended:Fire(s.Id, "Surge", how)
end

local function tickSurges(dt: number, t: number)
	local info = Config.Get("Disasters", "ElectricalSurge")
	for roomId, s in table.clone(surges) do
		local room = grid:Room(roomId)
		if not room then
			endSurge(s, "Gone")
			continue
		end
		s.Carry += (info.RoomDamagePerSecond or 0) * dt
		if s.Carry >= 1 and room.HP > 0 then
			local whole = math.floor(s.Carry)
			s.Carry -= whole
			grid:SetHP(roomId, room.HP - whole)
		end
		if t >= s.EndsAt then
			endSurge(s, "Expired")
			local after = Disasters.SurgeAftermath(rng)
			if after == "Fire" then
				DisasterService:StartFire(roomId, "ElectricalSurge")
			elseif after == "Blackout" then
				DisasterService:StartBlackout(room.Floor, "ElectricalSurge")
			end
		end
	end
end

-- The Surge's disaster (Section 5) ------------------------------------------------------------------------

-- Floods (Prompt 23) -------------------------------------------------------------------------------------

local function publishFlood(flood: Flood)
	flood.Sent = math.ceil(flood.Level)
	flood.SentPipe = flood.Pipe
	collection:Set(flood.Id, { Kind = "Flood", Room = flood.Room, Level = flood.Sent, Pipe = flood.Pipe, Cause = flood.Cause })
end

-- Where a room's burst pipe is: on the back wall of one of its cells, under the ceiling.
local function pipePosition(room: any): Vector3
	local g = Grid.Tuning()
	local n = (tonumber(string.match(room.Id, "%d+")) or 0) + counter
	local cell = Grid.CellPosition(room.Floor, room.Column + n % room.Span)
	return cell + Vector3.new(if n % 2 == 0 then -7 else 7, g.CellHeight * 0.62, -(g.CellDepth / 2 - 1.2))
end

-- A fitting on a wall with its prompt: the art's model if it is there (ServerStorage.Assets.Kit),
-- else a plain block.
local function fitting(name: string, asset: string, at: CFrame, size: Vector3, colour: Color3): Instance?
	local parent = holder()
	if not parent then
		return nil
	end
	local source = art(asset)
	local item: Instance
	if source then
		local model = source:Clone()
		CollectionService:RemoveTag(model, "Asset")
		model:PivotTo(at)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				CollectionService:AddTag(part, CAMERA_IGNORE_TAG)
			end
		end
		item = model
	else
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Metal
		part.Color = colour
		part.Size = size
		part.CFrame = at
		CollectionService:AddTag(part, CAMERA_IGNORE_TAG)
		item = part
	end
	item.Name = name
	item.Parent = parent
	return item
end

local function endFlood(flood: Flood, how: string, player: Player?)
	if floods[flood.Room] ~= flood then
		return
	end
	floods[flood.Room] = nil
	Hazards.SetFlood(flood.Room, nil)
	if flood.Prop then
		flood.Prop:Destroy()
	end
	collection:Remove(flood.Id)
	publishCounts()
	log:Info("flood in %s over (%s%s)", flood.Room, how, if player then `, {player.Name}` else "")
	if how ~= "Gone" then
		announce("Info", `{nameOf(flood.Room)} IS DRY{if player then ` · {string.upper(player.DisplayName)}` else ""}`)
	end
	DisasterService.Ended:Fire(flood.Id, "Flood", how)
end

-- The burst pipe is patched: the water stops rising and the room drains.
function DisasterService:PatchPipe(roomId: string, how: string, player: Player?): boolean
	local flood = floods[roomId]
	if not flood or not flood.Pipe then
		return false
	end
	flood.Pipe = false
	if flood.Prop then
		flood.Prop:Destroy()
		flood.Prop = nil
	end
	publishFlood(flood)
	log:Info("pipe patched in %s (%s%s) at level %.0f", roomId, how, if player then `, {player.Name}` else "", flood.Level)
	announce("Info", `PIPE PATCHED IN {nameOf(roomId)}{if player then ` · {string.upper(player.DisplayName)}` else ""}: IT IS DRAINING`)
	return true
end

-- Ends a room's flood at once (the Firefighter's Foam Burst: "Ends a room's fire or flood at once").
function DisasterService:Drain(roomId: string, how: string, player: Player?): boolean
	local flood = floods[roomId]
	if not flood then
		return false
	end
	endFlood(flood, how, player)
	return true
end

-- Water in a room. `pipe` (default true): a burst pipe feeds it until someone patches it; false:
-- so much water and no more (a Bloat Toad's burst, water pouring in from next door). Into a room
-- that is already flooded it adds `level` and, if asked, bursts a pipe there too.
function DisasterService:StartFlood(roomId: string, cause: string, level: number?, pipe: boolean?): string?
	local room = grid:Room(roomId)
	if not room then
		return nil
	end
	local f = Disasters.Tuning().Flood
	local burst = pipe ~= false
	local flood = floods[roomId]
	if flood then
		flood.Level = math.clamp(flood.Level + (level or 0), 0, 100)
		if not burst or flood.Pipe then
			Hazards.SetFlood(roomId, flood.Level)
			publishFlood(flood)
			return flood.Id
		end
	else
		flood = {
			Id = `W:{roomId}`, Room = roomId, Level = math.clamp(level or f.StartLevel, 1, 100), Pipe = false,
			NextSpread = now() + Disasters.FloodSpreadSeconds(), Carry = 0, Cause = cause, Sent = -1, SentPipe = false,
		}
		floods[roomId] = flood
	end
	if burst then
		flood.Pipe = true
		local at = pipePosition(room)
		local prop = fitting(`Pipe:{roomId}`, "Kit_BurstPipe", CFrame.new(at), Vector3.new(5, 1.4, 1.4), Color3.fromRGB(141, 150, 157))
		flood.Prop = prop
		local base = if prop and prop:IsA("Model") then prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true) else prop
		if prop and base and base:IsA("BasePart") then
			prop:SetAttribute("Room", roomId)
			local p = prompt(base, "PatchPipe", "Patch the pipe", "Burst pipe", f.PatchSeconds, 14)
			p.Triggered:Connect(function(player: Player)
				DisasterService:PatchPipe(roomId, "Patched", player)
			end)
		end
	end
	Hazards.SetFlood(roomId, flood.Level)
	publishFlood(flood)
	publishCounts()
	log:Info("flood in %s (%s): %s, level %.0f%s", roomId, room.Type, cause, flood.Level, if flood.Pipe then ", a burst pipe" else "")
	if cause ~= "Spread" then
		announce("Danger", if cause == "Deluge" then `THE DELUGE FLOODS {nameOf(roomId)}{if flood.Pipe then ": PATCH ITS PIPE" else ""}`
			elseif flood.Pipe then `A PIPE HAS BURST IN {nameOf(roomId)}: PATCH IT`
			else `{nameOf(roomId)} IS FLOODING`)
	elseif room.Type == "Shaft" then
		announce("Danger", `WATER IS POURING DOWN THE SHAFT TO FLOOR {room.Floor}`)
	else
		announce("Danger", `THE WATER REACHES {nameOf(roomId)}`)
	end
	DisasterService.Started:Fire(flood.Id, "Flood")
	return flood.Id
end

-- The water's level in a room (nil: dry).
function DisasterService:Flooded(roomId: string): number?
	local flood = floods[roomId]
	return if flood then flood.Level else nil
end

local function tickFloods(dt: number, t: number, inside: { [string]: { any } })
	if next(floods) == nil then
		return
	end
	local bunker = grid:Bunker()
	local levels: { [string]: number } = {}
	for roomId, flood in floods do
		levels[roomId] = flood.Level
	end
	local drain = modifierValue("FloodDrainSpeed")
	for roomId, flood in table.clone(floods) do
		local room = grid:Room(roomId)
		if not room then
			endFlood(flood, "Gone")
			continue
		end
		local fed = if flood.Pipe then nil else Disasters.FloodFed(bunker, roomId, levels)
		flood.Level = Disasters.FloodStep(flood.Level, dt, flood.Pipe, fed, drain)
		if flood.Level <= 0 then
			endFlood(flood, "Drained")
			continue
		end
		-- the water ruins the room (Section 6: "fires and floods hurt rooms")
		flood.Carry += Disasters.FloodRoomDamage(flood.Level, dt)
		if flood.Carry >= 1 and room.HP > 0 then
			local whole = math.floor(flood.Carry)
			flood.Carry -= whole
			grid:SetHP(roomId, room.HP - whole)
		end
		-- and anyone deep in it
		if Disasters.FloodDepth(flood.Level) > 0 then
			for _, c in inside[roomId] or {} do
				if c.Kind == "Resident" then
					combat:Damage(c.Id, Disasters.FloodResidentDamage(flood.Level, dt), nil, "flood")
				elseif c.Kind == "Player" and c.Player then
					local taken = Modifiers.PlayerValue(c.Player, "FireFloodDamageTaken") or 1
					combat:Damage(c.Id, Disasters.FloodPlayerDamage(flood.Level, dt, taken), nil, "flood")
				end
			end
		end
		-- it pours on (Section 10: "pours down the Shaft")
		if t >= flood.NextSpread then
			flood.NextSpread = t + Disasters.FloodSpreadSeconds()
			if Disasters.FloodCanSpread(flood.Level) then
				local targets = Disasters.FloodSpreadTargets(bunker, roomId, floods)
				if #targets > 0 then
					DisasterService:StartFlood(targets[rng:NextInteger(1, #targets)], "Spread", Disasters.Tuning().Flood.OverflowStartLevel, false)
				end
			end
		end
		Hazards.SetFlood(roomId, flood.Level)
		if math.ceil(flood.Level) ~= flood.Sent or flood.Pipe ~= flood.SentPipe then
			publishFlood(flood)
		end
	end
end

-- Gas leaks (Prompt 23) --------------------------------------------------------------------------------

local function publishGas(gas: Gas)
	gas.Sent = math.ceil(gas.Strength)
	gas.SentLeaking = gas.Leaking
	collection:Set(gas.Id, { Kind = "Gas", Room = gas.Room, Strength = gas.Sent, Leaking = gas.Leaking, EndsAt = gas.EndsAt, Cause = gas.Cause })
end

-- A room's vent (the kit's Vent socket or part), else a spot high on its back wall.
local function ventPosition(room: any): Vector3
	local model = grid:RoomModel(room.Id)
	if model then
		local socket = BunkerKit.Socket(model, "Vent")
		if socket then
			return socket.Position
		end
		local vent = model:FindFirstChild("Vent", true)
		if vent and vent:IsA("BasePart") then
			return vent.Position
		elseif vent and vent:IsA("Model") then
			return (vent:GetBoundingBox()).Position
		end
	end
	local g = Grid.Tuning()
	return Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, g.CellHeight * 0.7, -(g.CellDepth / 2 - 1.2))
end

local function endGas(gas: Gas, how: string, player: Player?)
	if gases[gas.Room] ~= gas then
		return
	end
	gases[gas.Room] = nil
	Hazards.SetGas(gas.Room, nil)
	if gas.Prop then
		gas.Prop:Destroy()
	end
	collection:Remove(gas.Id)
	publishCounts()
	log:Info("gas in %s gone (%s%s)", gas.Room, how, if player then `, {player.Name}` else "")
	if how ~= "Gone" then
		announce("Info", `THE AIR IS CLEAR IN {nameOf(gas.Room)}{if player then ` · {string.upper(player.DisplayName)}` else ""}`)
	end
	DisasterService.Ended:Fire(gas.Id, "Gas", how)
end

-- The vent is sealed (or the leak has run its time): no more gas comes in and the room airs out.
function DisasterService:SealVent(roomId: string, how: string, player: Player?): boolean
	local gas = gases[roomId]
	if not gas or not gas.Leaking then
		return false
	end
	gas.Leaking = false
	if gas.Prop then
		gas.Prop:Destroy()
		gas.Prop = nil
	end
	publishGas(gas)
	log:Info("gas vent in %s shut (%s%s) at strength %.0f", roomId, how, if player then `, {player.Name}` else "", gas.Strength)
	if how ~= "Expired" then
		announce("Info", `VENT SEALED IN {nameOf(roomId)}{if player then ` · {string.upper(player.DisplayName)}` else ""}: THE GAS IS THINNING`)
	end
	return true
end

-- Clears a room's gas at once (the Hazmat Tech's Decon Field: "Clears radiation and gas from a room").
function DisasterService:ClearGas(roomId: string, how: string, player: Player?): boolean
	local gas = gases[roomId]
	if not gas then
		return false
	end
	endGas(gas, how, player)
	return true
end

function DisasterService:StartGasLeak(roomId: string, cause: string, strength: number?): string?
	local room = grid:Room(roomId)
	if not room or gases[roomId] then
		return nil
	end
	local g = Disasters.Tuning().Gas
	local gas: Gas = {
		Id = `G:{roomId}`, Room = roomId, Strength = math.clamp(strength or g.StartStrength, 1, 100), Leaking = true,
		EndsAt = now() + Disasters.GasSeconds(), Cause = cause, Sent = -1, SentLeaking = true,
	}
	gases[roomId] = gas
	local prop = fitting(`GasVent:{roomId}`, "Kit_GasVent", CFrame.new(ventPosition(room) + Vector3.new(0, 0, 0.6)), Vector3.new(3, 3, 0.6),
		Color3.fromRGB(94, 106, 68))
	gas.Prop = prop
	local base = if prop and prop:IsA("Model") then prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true) else prop
	if prop and base and base:IsA("BasePart") then
		prop:SetAttribute("Room", roomId)
		local p = prompt(base, "SealVent", "Seal the vent", "Gas leak", g.SealSeconds, 14)
		p.Triggered:Connect(function(player: Player)
			DisasterService:SealVent(roomId, "Sealed", player)
		end)
	end
	Hazards.SetGas(roomId, gas.Strength)
	publishGas(gas)
	publishCounts()
	log:Info("gas leak in %s (%s): %s", roomId, room.Type, cause)
	announce("Danger", `GAS IN {nameOf(roomId)}: SEAL THE VENT OR GET OUT`)
	DisasterService.Started:Fire(gas.Id, "Gas")
	return gas.Id
end

-- A room's gas strength (nil: clear air).
function DisasterService:Gassed(roomId: string): number?
	local gas = gases[roomId]
	return if gas then gas.Strength else nil
end

local function flagOn(value: any): boolean
	return value == true or (type(value) == "number" and value > 0)
end

local function tickGas(dt: number, t: number, inside: { [string]: { any } })
	if next(gases) == nil then
		return
	end
	local strength = modifierValue("GasStrength")
	for roomId, gas in table.clone(gases) do
		if not grid:Room(roomId) then
			endGas(gas, "Gone")
			continue
		end
		if gas.Leaking and t >= gas.EndsAt then
			DisasterService:SealVent(roomId, "Expired") -- Section 10: "or air the room out"
		end
		gas.Strength = Disasters.GasStep(gas.Strength, dt, gas.Leaking)
		if gas.Strength <= 0 then
			endGas(gas, "Aired")
			continue
		end
		for _, c in inside[roomId] or {} do
			if c.Kind == "Resident" then
				combat:Damage(c.Id, Disasters.GasResidentDamage(gas.Strength, dt, strength), nil, "gas")
			elseif c.Kind == "Player" and c.Player then
				local immune = flagOn(Modifiers.PlayerValue(c.Player, "GasImmune"))
				local taken = Modifiers.PlayerValue(c.Player, "GasDamageTaken")
				local damage = Disasters.GasPlayerDamage(gas.Strength, dt, strength, immune, if type(taken) == "number" then taken else 1)
				if damage > 0 then
					combat:Damage(c.Id, damage, nil, "gas")
				end
			end
		end
		Hazards.SetGas(roomId, gas.Strength)
		if math.ceil(gas.Strength) ~= gas.Sent or gas.Leaking ~= gas.SentLeaking then
			publishGas(gas)
		end
	end
end

-- Radiation leaks (Prompt 24) ------------------------------------------------------------------------

local function leakUnits(leak: Leak): { [string]: boolean }
	local units: { [string]: boolean } = {}
	if leak.Room then
		if grid:Room(leak.Room) then
			units[leak.Room] = true
		end
		return units
	end
	local g = Grid.Tuning()
	local bunker = grid:Bunker()
	for column = g.ColumnMin, g.ColumnMax do
		local unit = bunker:UnitAt(leak.Floor, column)
		if unit then
			units[unit] = true
		end
	end
	return units
end

local function publishLeak(leak: Leak)
	leak.Sent = math.ceil(leak.Strength)
	leak.SentLeaking = leak.Leaking
	local list = {}
	for unit in leak.Units do
		table.insert(list, unit)
	end
	table.sort(list)
	collection:Set(leak.Id, {
		Kind = "Radiation", Floor = leak.Floor, Room = leak.Room, Units = list, Strength = leak.Sent, Leaking = leak.Leaking,
		EndsAt = leak.EndsAt, Cause = leak.Cause,
	})
end

local function leakWhere(leak: Leak): string
	return if leak.Room then nameOf(leak.Room) else `FLOOR {leak.Floor}`
end

-- A working Decon Room "slows leaks" (Section 6).
local function workingDecon(): boolean
	for _, room in grid:RoomsOfType("DeconRoom") do
		if not room.Wrecked and not power:IsDark(room.Id) then
			return true
		end
	end
	return false
end

local function endLeak(leak: Leak, how: string, player: Player?)
	if leaks[leak.Id] ~= leak then
		return
	end
	leaks[leak.Id] = nil
	for unit in leak.Units do
		Hazards.SetRadiation(unit, nil)
	end
	-- another leak may still fill some of those
	for _, other in leaks do
		for unit in other.Units do
			Hazards.SetRadiation(unit, other.Strength)
		end
	end
	if leak.Prop then
		leak.Prop:Destroy()
	end
	collection:Remove(leak.Id)
	publishCounts()
	log:Info("radiation on %s gone (%s%s)", leakWhere(leak), how, if player then `, {player.Name}` else "")
	if how ~= "Gone" then
		announce("Info", `THE RADIATION IS GONE FROM {leakWhere(leak)}{if player then ` · {string.upper(player.DisplayName)}` else ""}`)
	end
	DisasterService.Ended:Fire(leak.Id, "Radiation", how)
end

-- The door is sealed, or went up a level, or the storm has passed: nothing more comes in and
-- the radiation fades.
function DisasterService:SealLeak(id: string, how: string, player: Player?): boolean
	local leak = leaks[id]
	if not leak or not leak.Leaking then
		return false
	end
	leak.Leaking = false
	if leak.Prop then
		leak.Prop:Destroy()
		leak.Prop = nil
	end
	publishLeak(leak)
	log:Info("radiation leak %s shut (%s%s) at strength %.0f", id, how, if player then `, {player.Name}` else "", leak.Strength)
	if how == "Upgraded" then
		announce("Info", "THE NEW BLAST DOOR HOLDS: THE RADIATION IS FADING")
	elseif how ~= "Expired" then
		announce("Info", `{if leak.Room then "SEAM" else "BLAST DOOR"} SEALED{if player then ` · {string.upper(player.DisplayName)}` else ""}: THE RADIATION IS FADING`)
	end
	return true
end

-- Clears a room's radiation at once (the Hazmat Tech's Decon Field): a leak that is shut is gone;
-- one still leaking starts to fill again. The irradiated residents in the room are cleared too.
function DisasterService:ClearRadiation(roomId: string, how: string, player: Player?): boolean
	local any = false
	for _, leak in table.clone(leaks) do
		if leak.Units[roomId] then
			any = true
			if leak.Leaking then
				leak.Strength = 1
				publishLeak(leak)
			else
				endLeak(leak, how, player)
			end
		end
	end
	for _, c in (occupants())[roomId] or {} do
		if c.Kind == "Resident" and c.ResidentId and residents:SetCondition(c.ResidentId, "Irradiated", false, how) then
			any = true
		end
	end
	return any
end

-- The radiation in a unit (nil: none).
function DisasterService:Irradiated(unit: string): number?
	return Hazards.Radiation(unit)
end

-- A radiation leak: the Blast Door's (roomId nil: "Floor 1 fills with radiation"), or one room's
-- (a hazard pocket in the Crystal Hollows).
function DisasterService:StartRadiationLeak(cause: string, roomId: string?, strength: number?): string?
	local r = Disasters.Tuning().Radiation
	local door = grid:RoomsOfType("BlastDoor")[1]
	local room = if roomId then grid:Room(roomId) else door
	if not room then
		return nil
	end
	local id = if roomId then `R:{roomId}` else "R:Door"
	if leaks[id] then
		return nil
	end
	local leak: Leak = {
		Id = id, Floor = room.Floor, Room = roomId, Strength = math.clamp(strength or (if roomId then r.PocketStrength else r.StartStrength), 1, 100),
		Leaking = true, EndsAt = now() + Disasters.RadiationSeconds(), Cause = cause, Sent = -1, SentLeaking = true,
		Units = {}, DoorLevel = if roomId then nil else room.Level,
	}
	leak.Units = leakUnits(leak)
	leaks[id] = leak
	-- what a player seals: the Blast Door's seal, or the crystal seam in the room's back wall
	local g = Grid.Tuning()
	local at: CFrame
	if roomId then
		at = seamSpot(room)
	else
		local model = grid:RoomModel(room.Id)
		local socket = if model then BunkerKit.Socket(model, "Door") else nil
		at = if socket then CFrame.new(socket.Position + Vector3.new(DOOR_SEAL_SIDE, 3, 1.2))
			else CFrame.new(Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, 4, -(g.CellDepth / 2 - 1.5)))
	end
	local prop = fitting(if roomId then `RadSeam:{roomId}` else "DoorSeal", if roomId then "Kit_CrystalSeam" else "Kit_DoorSeal", at,
		Vector3.new(4, 4, 0.8), Color3.fromRGB(124, 255, 155))
	leak.Prop = prop
	local base = if prop and prop:IsA("Model") then prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true) else prop
	if prop and base and base:IsA("BasePart") then
		prop:SetAttribute("Leak", id)
		local p = prompt(base, "SealLeak", if roomId then "Seal the seam" else "Seal the door", "Radiation leak", r.SealSeconds, 14)
		p.Triggered:Connect(function(player: Player)
			DisasterService:SealLeak(id, "Sealed", player)
		end)
	end
	for unit in leak.Units do
		Hazards.SetRadiation(unit, leak.Strength)
	end
	publishLeak(leak)
	publishCounts()
	log:Info("radiation leak %s (%s)", id, cause)
	if roomId then
		announce("Danger", `RADIATION IN {nameOf(roomId)}: SEAL THE CRYSTAL SEAM OR GET OUT`)
	else
		announce("Danger", `THE STORM IS THROUGH THE BLAST DOOR: RADIATION ON FLOOR {room.Floor} · SEAL THE DOOR`)
	end
	DisasterService.Started:Fire(id, "Radiation")
	return id
end

-- Section 10: "Surface storms against a weak Blast Door". Rolled as each Surge's storm hits.
local function stormAtTheDoor()
	local door = grid:RoomsOfType("BlastDoor")[1]
	if not door or leaks["R:Door"] then
		return
	end
	local era = table.find(Config.Ids("Eras"), clock:Era()) or 1
	local chance = Disasters.DoorLeakChance(era, door.Level, if door.MaxHP > 0 then door.HP / door.MaxHP else 0, door.Wrecked == true)
	local roll = rng:NextNumber()
	log:Info("the storm at the Blast Door (level %d, %d/%d HP): leak chance %.2f, rolled %.2f", door.Level, door.HP, door.MaxHP, chance, roll)
	if roll < chance then
		DisasterService:StartRadiationLeak("Storm")
	end
end

local function tickRadiation(dt: number, t: number, inside: { [string]: { any } })
	if next(leaks) == nil then
		return
	end
	local r = Disasters.Tuning().Radiation
	local slow = if workingDecon() then r.DeconSlow else 1
	for id, leak in table.clone(leaks) do
		local units = leakUnits(leak)
		if next(units) == nil then
			endLeak(leak, "Gone")
			continue
		end
		for unit in leak.Units do
			if not units[unit] then
				Hazards.SetRadiation(unit, nil)
			end
		end
		leak.Units = units
		if leak.Leaking then
			local door = if leak.DoorLevel then grid:RoomsOfType("BlastDoor")[1] else nil
			if door and leak.DoorLevel and door.Level > leak.DoorLevel then
				DisasterService:SealLeak(id, "Upgraded") -- Section 10: "Seal or upgrade the door"
			elseif t >= leak.EndsAt then
				DisasterService:SealLeak(id, "Expired")
			end
		end
		leak.Strength = Disasters.RadiationStep(leak.Strength, dt, leak.Leaking, slow)
		if leak.Strength <= 0 then
			endLeak(leak, "Faded")
			continue
		end
		for unit in units do
			Hazards.SetRadiation(unit, leak.Strength)
			for _, c in inside[unit] or {} do
				if c.Kind == "Resident" then
					combat:Damage(c.Id, Disasters.RadiationResidentDamage(leak.Strength, dt), nil, "radiation")
					if leak.Strength >= r.IrradiateAt and c.ResidentId then
						residents:SetCondition(c.ResidentId, "Irradiated", true, "the leak")
					end
				end
			end
		end
		if math.ceil(leak.Strength) ~= leak.Sent or leak.Leaking ~= leak.SentLeaking then
			publishLeak(leak)
		end
	end
end

-- Outbreaks (Prompt 24) ------------------------------------------------------------------------------

local function sickResidents(): { any }
	local list = {}
	for _, resident in residents:All() do
		if resident.Sick and (resident.State == "Alive" or resident.State == "Down") then
			table.insert(list, resident)
		end
	end
	table.sort(list, function(a, b)
		return (tonumber(string.match(a.Id, "%d+")) or 0) < (tonumber(string.match(b.Id, "%d+")) or 0)
	end)
	return list
end

local function residentName(resident: any): string
	return string.upper(`{resident.First} {resident.Last}`)
end

-- Medbays that can treat: standing, lit and staffed.
local function workingMedbays(): number
	local n = 0
	for _, room in grid:RoomsOfType("Medbay") do
		if not room.Wrecked and not power:IsDark(room.Id) and #residents:Workers(room.Id) > 0 then
			n += 1
		end
	end
	return n
end

-- The team's best OutbreakCureSpeed (the Hazmat Tech's level 3: "Outbreaks cured twice as fast").
local function cureSpeed(): number
	local best = 1
	for _, player in session:ReadyPlayers() do
		local value = Modifiers.PlayerValue(player, "OutbreakCureSpeed")
		if type(value) == "number" and value > best then
			best = value
		end
	end
	return best
end

local function publishOutbreak(o: Outbreak, sick: { any }, treating: boolean)
	local quarantined = 0
	for _, resident in sick do
		if resident.Job == nil then
			quarantined += 1
		end
	end
	local patient = if o.Patient then residents:Get(o.Patient) else nil
	local fraction = math.clamp(o.Cure / Disasters.CureSeconds(cureSpeed()), 0, 1)
	local sent = `{#sick}|{quarantined}|{o.Patient or ""}|{math.floor(fraction * 20)}|{treating}`
	if sent == o.Sent then
		return
	end
	o.Sent = sent
	collection:Set(o.Id, {
		Kind = "Outbreak", Sick = #sick, Quarantined = quarantined, Patient = if patient then `{patient.First} {patient.Last}` else nil,
		Cure = fraction, Treating = treating, Cause = o.Cause,
	})
end

local function endOutbreak(how: string)
	local o = outbreak
	if not o then
		return
	end
	outbreak = nil
	collection:Remove(o.Id)
	publishCounts()
	log:Info("the outbreak is over (%s)", how)
	if how ~= "Gone" then
		announce("Info", "THE OUTBREAK IS OVER: NOBODY IS SICK")
	end
	DisasterService.Ended:Fire(o.Id, "Outbreak", how)
end

-- A resident is cured (the Medbay, a level 3 Medic's Triage Pulse; DevTools). They can't catch
-- this outbreak again.
function DisasterService:Cure(residentId: string, how: string, player: Player?): boolean
	if not residents:SetCondition(residentId, "Sick", false, how) then
		return false
	end
	local o = outbreak
	if o then
		o.Immune[residentId] = true
		if o.Patient == residentId then
			o.Patient, o.Cure = nil, 0
		end
	end
	local resident = residents:Get(residentId)
	local left = #sickResidents()
	if resident and left > 0 then
		announce("Info", `{residentName(resident)} IS CURED{if player then ` · {string.upper(player.DisplayName)}` else ""} ({left} STILL SICK)`)
	end
	return true
end

-- An outbreak begins with one carrier (given, or picked from the residents who are well).
function DisasterService:StartOutbreak(cause: string, residentId: string?): string?
	local carrier = if residentId then residents:Get(residentId) else nil
	if not carrier then
		local well = {}
		for _, resident in residents:All() do
			if resident.State == "Alive" and not resident.Sick then
				table.insert(well, resident)
			end
		end
		if #well == 0 then
			return nil
		end
		table.sort(well, function(a, b)
			return a.Id < b.Id
		end)
		carrier = well[rng:NextInteger(1, #well)]
	end
	if carrier.State ~= "Alive" or carrier.Sick then
		return nil
	end
	local o = outbreak
	if not o then
		counter += 1
		o = { Id = `O:{counter}`, Cause = cause, NextSpread = now() + Disasters.Tuning().Outbreak.SpreadSeconds, Cure = 0, Patient = nil, Immune = {}, Sent = "" }
		outbreak = o
		log:Info("an outbreak (%s): %s is sick", cause, carrier.Id)
		announce("Danger", `OUTBREAK: {residentName(carrier)} IS SICK · TAKE THE SICK OFF WORK TO QUARANTINE THEM`)
		DisasterService.Started:Fire(o.Id, "Outbreak")
	end
	residents:SetCondition(carrier.Id, "Sick", true, if cause == "TheDeep" then "brought up from the Deep" else nil)
	publishCounts()
	return o.Id
end

-- Someone has come in from the Deep (a rescue, a Lost Crew, an expedition home; Section 10: the
-- Deep causes outbreaks): CarrierChance of the time, from era FromEra, they carry the sickness.
function DisasterService:FromTheDeep(residentId: string, why: string): boolean
	local era = table.find(Config.Ids("Eras"), clock:Era()) or 1
	local resident = residents:Get(residentId)
	if not resident or resident.State ~= "Alive" or resident.Sick then
		return false
	end
	local roll = rng:NextNumber()
	local carries = Disasters.CarriesSickness(era, roll)
	log:Info("%s came in from the Deep (%s): rolled %.2f, %s", residentId, why, roll, if carries then "a carrier" else "well")
	if not carries then
		return false
	end
	return DisasterService:StartOutbreak("TheDeep", residentId) ~= nil
end

local function tickOutbreak(dt: number, t: number, inside: { [string]: { any } })
	local sick = sickResidents()
	local o = outbreak
	if not o then
		if #sick > 0 then
			-- someone is sick with no outbreak on record (a dev command): give them one
			counter += 1
			o = { Id = `O:{counter}`, Cause = "Unknown", NextSpread = t + Disasters.Tuning().Outbreak.SpreadSeconds, Cure = 0, Patient = nil, Immune = {}, Sent = "" }
			outbreak = o
		else
			return
		end
	end
	if #sick == 0 then
		endOutbreak("Cured")
		return
	end
	local tuning = Disasters.Tuning().Outbreak
	-- where everyone is
	local where: { [string]: string } = {}
	for unit, list in inside do
		for _, c in list do
			if c.Kind == "Resident" and c.ResidentId then
				where[c.ResidentId] = unit
			end
		end
	end
	if t >= o.NextSpread then
		o.NextSpread = t + tuning.SpreadSeconds
		local people = {}
		for _, resident in residents:All() do
			if resident.State == "Alive" then
				local unit = where[resident.Id]
				local room = if unit then grid:Room(unit) else nil
				table.insert(people, {
					Id = resident.Id, Room = unit, Sick = resident.Sick == true, Immune = o.Immune[resident.Id] == true,
					-- quarantine: off work and in Quarters
					Quarantined = resident.Sick == true and resident.Job == nil and room ~= nil and room.Type == "Quarters",
				})
			end
		end
		local caught: { [string]: boolean } = {}
		for _, person in people do
			if person.Sick and not caught[person.Id] then
				local targets = Disasters.OutbreakTargets(people, person)
				local open = {}
				for _, id in targets do
					if not caught[id] then
						table.insert(open, id)
					end
				end
				if #open > 0 and rng:NextNumber() < tuning.SpreadChance then
					local id = open[rng:NextInteger(1, #open)]
					caught[id] = true
					if residents:SetCondition(id, "Sick", true, "caught it at work") then
						local resident = residents:Get(id)
						if resident then
							announce("Warning", `{residentName(resident)} CAUGHT THE SICKNESS ({#sick + 1} SICK)`)
						end
						table.insert(sick, resident)
					end
				end
			end
		end
	end
	-- Medbay treatment: one patient at a time for each working Medbay's share
	local medbays = workingMedbays()
	if medbays > 0 then
		if not o.Patient or not residents:HasCondition(o.Patient, "Sick") then
			o.Patient, o.Cure = sick[1].Id, 0
		end
		o.Cure += dt * medbays
		if o.Cure >= Disasters.CureSeconds(cureSpeed()) then
			DisasterService:Cure(o.Patient :: string, "the Medbay")
			sick = sickResidents()
			if #sick == 0 then
				endOutbreak("Cured")
				return
			end
		end
	end
	publishOutbreak(o, sick, medbays > 0)
end

-- What players stand in, for their own screen and legs: the Wading, InGas and InRadiation
-- attributes (SurfaceService adds a leak's radiation to the player's own from InRadiation).
local function markPlayers(inside: { [string]: { any } })
	local wading: { [Player]: number } = {}
	local breathing: { [Player]: number } = {}
	local glowing: { [Player]: number } = {}
	for _, leak in leaks do
		for unit in leak.Units do
			for _, c in inside[unit] or {} do
				if c.Kind == "Player" and c.Player then
					glowing[c.Player] = math.max(glowing[c.Player] or 0, math.ceil(leak.Strength))
				end
			end
		end
	end
	for roomId, flood in floods do
		for _, c in inside[roomId] or {} do
			if c.Kind == "Player" and c.Player then
				wading[c.Player] = math.ceil(flood.Level)
			end
		end
	end
	for roomId, gas in gases do
		for _, c in inside[roomId] or {} do
			if c.Kind == "Player" and c.Player then
				breathing[c.Player] = math.ceil(gas.Strength)
			end
		end
	end
	for _, player in session:ReadyPlayers() do
		if player:GetAttribute("Wading") ~= wading[player] then
			player:SetAttribute("Wading", wading[player])
		end
		if player:GetAttribute("InGas") ~= breathing[player] then
			player:SetAttribute("InGas", breathing[player])
		end
		if player:GetAttribute("InRadiation") ~= glowing[player] then
			player:SetAttribute("InRadiation", glowing[player])
		end
	end
end

-- A hazard pocket found by digging (Section 7: "Gas or water bursts out"; DigService): into the
-- room the digger stands in, else the nearest room on that floor. Returns what burst out.
function DisasterService:HazardPocket(floor: number, column: number, player: Player?): string?
	local band = nil
	for _, id in Config.Ids("DepthBands") do
		local b = Config.Get("DepthBands", id)
		if floor >= b.Floors.From and floor <= b.Floors.To then
			band = b
		end
	end
	local kind = if band then Disasters.HazardKind(band.Hazards, rng) else nil
	if not kind then
		return nil
	end
	local target: string? = nil
	local root = if player and player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
	local standing = if root and root:IsA("BasePart") then unitAt(root.Position) else nil
	if standing and grid:Room(standing) then
		target = standing
	else
		local best = math.huge
		for _, room in grid:Rooms() do
			if room.Floor == floor then
				local d = math.min(math.abs(room.Column - column), math.abs(room.Column + room.Span - 1 - column))
				if d < best then
					best, target = d, room.Id
				end
			end
		end
	end
	if player then
		local c = combat:PlayerCombatant(player)
		if c then
			combat:Damage(c.Id, Disasters.Tuning().HazardPocket.Damage, nil,
				if kind == "Flood" then "flood" elseif kind == "RadiationLeak" then "radiation" else "gas")
		end
	end
	if not target then
		log:Info("a hazard pocket at %d,%d burst into bare rock: no room on that floor", floor, column)
		return kind
	end
	if kind == "Flood" then
		DisasterService:StartFlood(target, "HazardPocket")
	elseif kind == "RadiationLeak" then
		DisasterService:StartRadiationLeak("HazardPocket", target) -- the Crystal Hollows (Prompt 24)
	else
		DisasterService:StartGasLeak(target, "HazardPocket")
	end
	return kind
end

-- The Surge disasters this service can start (Landon, Prompt 13: cave-ins too, and floods and gas
-- leaks from Era II, built with Prompt 23).
local SURGE_STARTS: { [string]: boolean } = { Fire = true, Blackout = true, CaveIn = true, Flood = true, GasLeak = true }

local function startKind(kind: string, cause: string): string?
	if kind == "Fire" then
		local options = {}
		for _, room in grid:Rooms() do
			if Disasters.Burns(room.Type) and not fires[room.Id] then
				table.insert(options, room.Id)
			end
		end
		if #options == 0 then
			return nil
		end
		return DisasterService:StartFire(options[rng:NextInteger(1, #options)], cause)
	elseif kind == "CaveIn" then
		-- Landon (Prompt 13): a Surge can bring a cave-in, at any doorway in the bunker
		local doorways = Disasters.Doorways(grid:Bunker())
		if #doorways == 0 then
			return nil
		end
		local pick = doorways[rng:NextInteger(1, #doorways)]
		local id = DisasterService:CaveIn(pick.Floor, pick.Column, pick.Side, cause)
		return id
	elseif kind == "Flood" or kind == "GasLeak" then
		local options = {}
		for _, room in grid:Rooms() do
			-- a pipe bursts or a vent leaks in a room people use (the Shaft only carries water down)
			if room.Type ~= "Shaft" and not floods[room.Id] and not gases[room.Id] then
				table.insert(options, room.Id)
			end
		end
		if #options == 0 then
			return nil
		end
		local roomId = options[rng:NextInteger(1, #options)]
		return if kind == "Flood" then DisasterService:StartFlood(roomId, cause) else DisasterService:StartGasLeak(roomId, cause)
	elseif kind == "Blackout" then
		local floors: { number } = {}
		for _, room in grid:Rooms() do
			if not table.find(floors, room.Floor) then
				table.insert(floors, room.Floor)
			end
		end
		table.sort(floors)
		return DisasterService:StartBlackout(Disasters.BlackoutFloor(floors, rng), cause)
	end
	log:Warn("no Surge start for the disaster %s yet", kind)
	return nil
end

-- ThreatDirector: picks and pays for the Surge's one disaster; returns its ThreatCost (0: none).
function DisasterService:SurgeDisaster(budget: number, pick: Random?): number
	local era = table.find(Config.Ids("Eras"), clock:Era()) or 1
	local kind = Disasters.SurgePick(era, budget, pick or rng, SURGE_STARTS)
	if not kind then
		return 0
	end
	local entry = { Kind = kind, Id = nil :: string?, Cycle = clock:Cycle() }
	surgeDisaster = entry
	task.delay(Disasters.Tuning().SurgeDelaySeconds, function()
		if surgeDisaster ~= entry then
			return
		end
		if clock:Phase() ~= "Surge" or director:Phase() ~= "Playing" then
			surgeDisaster = nil
			return
		end
		entry.Id = startKind(kind, "Surge")
		if not entry.Id then
			surgeDisaster = nil
		end
	end)
	return Config.Get("Disasters", kind).ThreatCost
end

local function isActive(id: string): boolean
	return collection:Get(id) ~= nil
end

function DisasterService:HoldsSurge(): boolean
	if meltdown or next(fires) then
		return true
	end
	for _, flood in floods do
		if flood.Pipe then
			return true -- a burst pipe nobody has patched
		end
	end
	local entry = surgeDisaster
	if entry then
		return entry.Id == nil or isActive(entry.Id)
	end
	return false
end

-- Modifiers and queries --------------------------------------------------------------------------------

function DisasterService:SetModifier(source: string, key: string, value: number?)
	assert(key == "FireSpread" or key == "BlackoutDuration" or key == "FloodDrainSpeed" or key == "GasStrength",
		`DisasterService:SetModifier: {key} isn't a disaster modifier`)
	modifiers[key] = modifiers[key] or {}
	modifiers[key][source] = value
end

function DisasterService:Active(): { [string]: any }
	return collection:All()
end

-- The tick --------------------------------------------------------------------------------------------

local function tick(dt: number)
	if director:Phase() ~= "Playing" then
		return
	end
	local t = now()
	local inside = occupants()
	tickFires(dt, t, inside)
	tickFloods(dt, t, inside)
	tickGas(dt, t, inside)
	tickRadiation(dt, t, inside)
	tickOutbreak(dt, t, inside)
	markPlayers(inside)
	if blackout and t >= blackout.EndsAt then
		DisasterService:EndBlackout("Expired")
	end
	tickMeltdown(t)
	tickSurges(dt, t)
	publishCounts()
end

-- The world changed: rubble re-reads the passages it blocks; a blackout takes in new rooms on
-- its floor; fires in rooms that went are out.
local function onGridChanged()
	for id, r in table.clone(rubble) do
		if r.Shape == "Tunnel" and grid:Bunker():State(r.Floor, r.Column) ~= "Dug" then
			DisasterService:ClearRubble(id, "Gone")
		else
			blockEdges(r)
			publishRubble(r)
		end
	end
	if blackout then
		local units = Disasters.BlackoutUnits(grid:Bunker(), blackout.Floor)
		blackout.Units = units
		power:SetBlackout(units)
	end
end

-- DevTools --------------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	local t = now()
	for roomId, fire in fires do
		local room = grid:Room(roomId)
		table.insert(lines, string.format("fire %s %s: strength %.1f, spreads in %.0f s, HP %s (%s)", roomId,
			if room then room.Type else "?", fire.Strength, math.max(fire.NextSpread - t, 0),
			if room then `{room.HP}/{room.MaxHP}` else "?", fire.Cause))
	end
	if blackout then
		local n = 0
		for _ in blackout.Units do
			n += 1
		end
		table.insert(lines, string.format("blackout %s: %s, %d units, %.0f s left (%s)", blackout.Id,
			if blackout.Floor then `floor {blackout.Floor}` else "the whole grid", n, blackout.EndsAt - t, blackout.Cause))
	end
	for id, r in rubble do
		local edges = {}
		for _, edge in r.Edges do
			table.insert(edges, `{edge[1]}|{edge[2]}`)
		end
		table.insert(lines, string.format("rubble %s: %s at %d,%d%s, %d/%d HP, blocks %s (%s)", id, r.Shape, r.Floor, r.Column,
			if r.Side then ` {r.Side}` else "", math.ceil(r.HP), r.MaxHP, table.concat(edges, " "), r.Cause))
	end
	if meltdown then
		local valves = {}
		for i, value in meltdown.Valves do
			valves[i] = if value == Disasters.HELD then "held" elseif value > t then string.format("%.1fs", value - t) else "open"
		end
		table.insert(lines, string.format("meltdown %s in %s: %.1f s left, valves %s, %d players (%s)", meltdown.Id, meltdown.Room,
			meltdown.EndsAt - t, table.concat(valves, " "), playerCount(), meltdown.Cause))
	end
	for roomId, s in surges do
		table.insert(lines, string.format("electrical surge %s: %.0f s left (%s)", roomId, s.EndsAt - t, s.Cause))
	end
	for roomId, flood in floods do
		local room = grid:Room(roomId)
		table.insert(lines, string.format("flood %s %s: level %.1f, %s, pours on in %.0f s (%s)", roomId, if room then room.Type else "?",
			flood.Level, if flood.Pipe then "the pipe is running" else "no pipe", math.max(flood.NextSpread - t, 0), flood.Cause))
	end
	for roomId, gas in gases do
		local room = grid:Room(roomId)
		table.insert(lines, string.format("gas %s %s: strength %.1f, %s (%s)", roomId, if room then room.Type else "?", gas.Strength,
			if gas.Leaking then string.format("leaking for %.0f s more", gas.EndsAt - t) else "airing out", gas.Cause))
	end
	for id, leak in leaks do
		local count = 0
		for _ in leak.Units do
			count += 1
		end
		table.insert(lines, string.format("radiation %s: %s, strength %.1f over %d units, %s%s (%s)", id, leakWhere(leak), leak.Strength, count,
			if leak.Leaking then string.format("leaking for %.0f s more", leak.EndsAt - t) else "fading",
			if workingDecon() then ", a Decon Room slows it" else "", leak.Cause))
	end
	if outbreak then
		local names = {}
		for _, resident in sickResidents() do
			table.insert(names, `{resident.Id} {resident.First}{if resident.Job == nil then " (off work)" else ""}`)
		end
		table.insert(lines, string.format("outbreak %s (%s): %d sick: %s; patient %s, cure %.0f of %.0f s, %d working Medbays, spreads in %.0f s",
			outbreak.Id, outbreak.Cause, #names, table.concat(names, ", "), tostring(outbreak.Patient), outbreak.Cure,
			Disasters.CureSeconds(cureSpeed()), workingMedbays(), math.max(outbreak.NextSpread - t, 0)))
	end
	do
		local door = grid:RoomsOfType("BlastDoor")[1]
		local era = table.find(Config.Ids("Eras"), clock:Era()) or 1
		if door then
			table.insert(lines, string.format("the Blast Door: level %d, %d/%d HP: a storm leaks %.0f%% of the time in era %d", door.Level, door.HP,
				door.MaxHP, Disasters.DoorLeakChance(era, door.Level, if door.MaxHP > 0 then door.HP / door.MaxHP else 0, door.Wrecked == true) * 100, era))
		end
	end
	if surgeDisaster then
		table.insert(lines, `this Surge's disaster: {surgeDisaster.Kind} {surgeDisaster.Id or "(starting)"}`)
	end
	table.insert(lines, `holds the Surge: {DisasterService:HoldsSurge()}`)
	return table.concat(lines, "\n")
end

local function roomArg(arg: any): string?
	local text = tostring(arg or "")
	if grid:Room(text) then
		return text
	end
	local ofType = grid:RoomsOfType(text)[1]
	return if ofType then ofType.Id else nil
end

local function registerCommands(dev: any)
	dev:Register("flood", {
		Description = "Burst a pipe in a room (by id or type), or just pour water in (nopipe).",
		Usage = "flood <roomId|RoomType> [level] [nopipe]",
		Run = function(_player, args): string?
			local roomId = roomArg(args[1])
			if not roomId then
				return "usage: flood <roomId|RoomType> [level] [nopipe]"
			end
			local id = DisasterService:StartFlood(roomId, "DevTools", tonumber(args[2]), args[3] ~= "nopipe" and args[2] ~= "nopipe")
			return if id then describe() else "no such room"
		end,
	})
	dev:Register("flood.patch", {
		Description = "Patch a room's burst pipe, or every pipe.",
		Usage = "flood.patch [roomId|RoomType]",
		Run = function(player, args): string?
			local only = if args[1] then roomArg(args[1]) else nil
			for roomId in table.clone(floods) do
				if only == nil or roomId == only then
					DisasterService:PatchPipe(roomId, "DevTools", player)
				end
			end
			return describe()
		end,
	})
	dev:Register("flood.drain", {
		Description = "Dry a room at once, or every room.",
		Usage = "flood.drain [roomId|RoomType]",
		Run = function(_player, args): string?
			local only = if args[1] then roomArg(args[1]) else nil
			for roomId in table.clone(floods) do
				if only == nil or roomId == only then
					DisasterService:Drain(roomId, "DevTools")
				end
			end
			return describe()
		end,
	})
	dev:Register("gas", {
		Description = "A gas leak in a room (by id or type).",
		Usage = "gas <roomId|RoomType> [strength]",
		Run = function(_player, args): string?
			local roomId = roomArg(args[1])
			if not roomId then
				return "usage: gas <roomId|RoomType> [strength]"
			end
			local id = DisasterService:StartGasLeak(roomId, "DevTools", tonumber(args[2]))
			return if id then describe() else "no such room, or it is already leaking there"
		end,
	})
	dev:Register("gas.seal", {
		Description = "Seal a room's leaking vent, or every one.",
		Usage = "gas.seal [roomId|RoomType]",
		Run = function(player, args): string?
			local only = if args[1] then roomArg(args[1]) else nil
			for roomId in table.clone(gases) do
				if only == nil or roomId == only then
					DisasterService:SealVent(roomId, "DevTools", player)
				end
			end
			return describe()
		end,
	})
	dev:Register("gas.clear", {
		Description = "Clear a room's gas at once, or every room's.",
		Usage = "gas.clear [roomId|RoomType]",
		Run = function(_player, args): string?
			local only = if args[1] then roomArg(args[1]) else nil
			for roomId in table.clone(gases) do
				if only == nil or roomId == only then
					DisasterService:ClearGas(roomId, "DevTools")
				end
			end
			return describe()
		end,
	})
	dev:Register("pocket", {
		Description = "A hazard pocket bursts at a cell (gas or water by its depth band), as if the invoking player dug it.",
		Usage = "pocket <floor> <column>",
		Run = function(player, args): string?
			local floor, column = tonumber(args[1]), tonumber(args[2])
			if not floor or not column then
				return "usage: pocket <floor> <column>"
			end
			local kind = DisasterService:HazardPocket(floor, column, player)
			return `a hazard pocket at {floor},{column}: {kind or "nothing (no gas or water in that band)"}\n{describe()}`
		end,
	})
	dev:Register("leak", {
		Description = "A radiation leak: with no room, the storm through the Blast Door (its whole floor); with a room, a crystal seam there.",
		Usage = "leak [roomId|RoomType] [strength]",
		Run = function(_player, args): string?
			local roomId = if args[1] and args[1] ~= "door" then roomArg(args[1]) else nil
			if args[1] and args[1] ~= "door" and not roomId then
				return `no room {args[1]}`
			end
			local id = DisasterService:StartRadiationLeak("Dev", roomId, tonumber(args[2]))
			return `{id or "no leak (one is on there already, or no Blast Door)"}\n{describe()}`
		end,
	})
	dev:Register("leak.storm", {
		Description = "Roll the storm against the Blast Door now, as each Surge does.",
		Run = function(): string?
			stormAtTheDoor()
			return describe()
		end,
	})
	dev:Register("leak.seal", {
		Description = "Seal every radiation leak (as a player at the door or the seam).",
		Run = function(player): string?
			local n = 0
			for id in table.clone(leaks) do
				if DisasterService:SealLeak(id, "Sealed", player) then
					n += 1
				end
			end
			return `{n} sealed\n{describe()}`
		end,
	})
	dev:Register("leak.clear", {
		Description = "End every radiation leak at once.",
		Run = function(): string?
			local n = 0
			for _, leak in table.clone(leaks) do
				endLeak(leak, "Dev")
				n += 1
			end
			return `{n} cleared`
		end,
	})
	dev:Register("outbreak", {
		Description = "Start an outbreak (or add a carrier): a resident id, or one picked for you.",
		Usage = "outbreak [residentId]",
		Run = function(_player, args): string?
			local id = DisasterService:StartOutbreak("Dev", if args[1] then tostring(args[1]) else nil)
			return `{id or "no outbreak (nobody well to carry it)"}\n{describe()}`
		end,
	})
	dev:Register("outbreak.cure", {
		Description = "Cure a sick resident, or all of them.",
		Usage = "outbreak.cure [residentId|all]",
		Run = function(player, args): string?
			local n = 0
			for _, resident in sickResidents() do
				if args[1] == nil or args[1] == "all" or args[1] == resident.Id then
					if DisasterService:Cure(resident.Id, "Dev", player) then
						n += 1
					end
				end
			end
			return `{n} cured\n{describe()}`
		end,
	})
	dev:Register("outbreak.deep", {
		Description = "A resident comes in from the Deep: roll for the sickness (force: a carrier for sure).",
		Usage = "outbreak.deep <residentId> [force]",
		Run = function(_player, args): string?
			local id = tostring(args[1] or "")
			if args[2] == "force" then
				return `{DisasterService:StartOutbreak("TheDeep", id) or "no"}\n{describe()}`
			end
			return `carrier: {DisasterService:FromTheDeep(id, "Dev")}\n{describe()}`
		end,
	})
	dev:Register("disasters", {
		Description = "Every disaster now: fires, the blackout, rubble, the meltdown, electrical surges.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("fire", {
		Description = "Start a fire in a room (by id or type).",
		Usage = "fire <roomId|RoomType> [strength]",
		Run = function(_player, args): string?
			local roomId = roomArg(args[1])
			if not roomId then
				return "usage: fire <roomId|RoomType> [strength]"
			end
			local id = DisasterService:StartFire(roomId, "DevTools", tonumber(args[2]))
			return if id then describe() else "it can't burn there (no such room, fireproof, or already burning)"
		end,
	})
	dev:Register("fire.out", {
		Description = "Put out a room's fire, or every fire.",
		Usage = "fire.out [roomId|RoomType]",
		Run = function(_player, args): string?
			local only = if args[1] then roomArg(args[1]) else nil
			for roomId, fire in table.clone(fires) do
				if only == nil or roomId == only then
					putOut(fire, "DevTools")
				end
			end
			return describe()
		end,
	})
	dev:Register("blackout", {
		Description = "A blackout on a floor, or the whole grid.",
		Usage = "blackout [floor|grid]",
		Run = function(_player, args): string?
			local floor = tonumber(args[1])
			if not floor and args[1] ~= "grid" then
				floor = (grid:RoomsOfType("ReactorCore")[1] or { Floor = 2 }).Floor
			end
			local id = DisasterService:StartBlackout(floor, "DevTools")
			return if id then describe() else "nothing to darken there"
		end,
	})
	dev:Register("blackout.end", {
		Description = "End the blackout, as if the fuse box were reset.",
		Run = function(): string?
			DisasterService:EndBlackout("DevTools")
			return describe()
		end,
	})
	dev:Register("cavein", {
		Description = "Rubble falls: in a doorway (side Left or Right of the cell) or filling a dug cell.",
		Usage = "cavein <floor> <column> [Left|Right]",
		Run = function(_player, args): string?
			local floor, column = tonumber(args[1]), tonumber(args[2])
			if not floor or not column then
				return "usage: cavein <floor> <column> [Left|Right]"
			end
			local side = if args[3] then tostring(args[3]) else nil
			if side then
				side = string.upper(string.sub(side, 1, 1)) .. string.lower(string.sub(side, 2))
			end
			local id, why = DisasterService:CaveIn(floor, column, side, "DevTools")
			return if id then describe() else `no cave-in: {why}`
		end,
	})
	dev:Register("rubble.clear", {
		Description = "Clear rubble (by id, or all of it).",
		Usage = "rubble.clear [id]",
		Run = function(_player, args): string?
			for id in table.clone(rubble) do
				if args[1] == nil or id == tostring(args[1]) then
					DisasterService:ClearRubble(id, "DevTools")
				end
			end
			return describe()
		end,
	})
	dev:Register("meltdown", {
		Description = "Start a Reactor meltdown (as if the Reactor Core reached 0 HP, without the damage).",
		Run = function(): string?
			return if DisasterService:StartMeltdown("DevTools") then describe() else "no meltdown (one is on, no Reactor Core, or the run isn't playing)"
		end,
	})
	dev:Register("meltdown.stop", {
		Description = "Stop the meltdown, as if the valves were turned.",
		Run = function(): string?
			endMeltdown("DevTools")
			return describe()
		end,
	})
	dev:Register("valve", {
		Description = "Turn a meltdown valve as a player would (held: a team keeps holding it).",
		Usage = "valve <1|2|3> [held|release]",
		Run = function(_player, args): string?
			local m = meltdown
			local i = tonumber(args[1])
			if not m or not i or not m.Valves[i] then
				return "usage: valve <1|2|3> [held|release] during a meltdown"
			end
			if args[2] == "release" then
				m.Valves[i] = Disasters.ValveReleased(m.Valves[i], playerCount(), now())
			else
				m.Valves[i] = Disasters.ValveTurned(playerCount(), now())
			end
			publishMeltdown(m)
			return describe()
		end,
	})
	dev:Register("esurge", {
		Description = "An electrical surge in a room (by id or type).",
		Usage = "esurge <roomId|RoomType>",
		Run = function(_player, args): string?
			local roomId = roomArg(args[1])
			local id = if roomId then DisasterService:StartElectricalSurge(roomId, "DevTools") else nil
			return if id then describe() else "usage: esurge <roomId|RoomType> (not the Shaft, one per room)"
		end,
	})
	dev:Register("disaster.surge", {
		Description = "Start a Surge's disaster now (Fire or Blackout; random when not given).",
		Usage = "disaster.surge [Fire|Blackout]",
		Run = function(_player, args): string?
			local kind = if args[1] then tostring(args[1]) else Disasters.SurgePick(1, math.huge, rng) or "Fire"
			local id = startKind(kind, "Surge")
			return if id then describe() else `couldn't start {kind}`
		end,
	})
end

-- Lifecycle ---------------------------------------------------------------------------------------------

function DisasterService:Init(registry)
	grid = registry.BunkerGrid
	power = registry.PowerService
	clock = registry.CycleClock
	director = registry.RunDirector
	combat = registry.CombatService
	weapons = registry.WeaponService
	residents = registry.ResidentService
	builds = registry.BuildService
	session = registry.SessionService
	collection = registry.ReplicationService:Collection("Disasters")
	set = RunState.Writer("DisasterService")
	registerCommands(registry.DevService)
end

function DisasterService:Start()
	Hazards.Clear()
	-- Section 10 (Landon, 2026-11-08): a Reactor Core at 0 HP starts the meltdown
	grid.Wrecked:Connect(function(roomId: string)
		local room = grid:Room(roomId)
		if room and room.Type == "ReactorCore" then
			DisasterService:StartMeltdown("ReactorDestroyed")
		end
	end)
	grid.RoomChanged:Connect(function(roomId: string)
		if not grid:Room(roomId) then
			local fire = fires[roomId]
			if fire then
				putOut(fire, "Gone")
			end
			local s = surges[roomId]
			if s then
				endSurge(s, "Gone")
			end
			local flood = floods[roomId]
			if flood then
				endFlood(flood, "Gone")
			end
			local gas = gases[roomId]
			if gas then
				endGas(gas, "Gone")
			end
		end
	end)
	grid.Changed:Connect(onGridChanged)
	-- Prompt 24: the storm that comes with every Surge may get through a weak Blast Door
	clock.SurgeStarted:Connect(function()
		local ok, err = pcall(stormAtTheDoor)
		if not ok then
			log:Warn("storm at the door: %s", tostring(err))
		end
	end)
	weapons.ToolTick:Connect(onToolTick)
	weapons.Foamed:Connect(onFoamed)
	weapons.Swung:Connect(onSwung)
	builds.Repaired:Connect(function(roomId: string, _amount: number, how: string, player: Player?)
		local s = surges[roomId]
		if s and how == "Welder" then
			endSurge(s, "Fixed", player)
		end
	end)
	clock.SurgeEnded:Connect(function()
		surgeDisaster = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		local step = Disasters.Tuning().TickSeconds
		if acc >= step then
			local elapsed = math.min(acc, 1)
			acc = 0
			local ok, err = pcall(tick, elapsed)
			if not ok then
				log:Warn("tick: %s", tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if meltdown then
			meltdown.Sent = "" -- the solo rule may change: send the valves again
		end
	end)
	publishCounts()
	log:Info("disasters ready")
end

return DisasterService
