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

	Disasters run while the run is playing (like monsters and residents, they go on when DevTools
	pause the cycle clock).

	Replication: the Disasters collection, id -> one of
	  { Kind = "Fire", Room, Strength, Cause }                       id "F:<room>"
	  { Kind = "Blackout", Floor?, Rooms, EndsAt, Cause }             id "B:<n>" (Floor nil: the grid)
	  { Kind = "Rubble", Shape, Floor, Column, Side?, HP, MaxHP, Cause, Edges }  id "C:<n>"
	  { Kind = "Meltdown", Room, EndsAt, Valves, Solo, Cause }        id "M:<n>"; Valves: 0 open,
	                                                                  -1 held, else turned until
	  { Kind = "Surge", Room, EndsAt, Cause }                         id "S:<room>"
	and RunState Fires, BlackoutRooms, Rubble, Meltdown, MeltdownEndsAt, ValvesTurned.
	workspace.Bunker.Disasters holds the fuse box and valve prompts and the rubble.

	API:
		DisasterService:StartFire(roomId, cause, strength?): string?
		DisasterService:Extinguish(roomId, amount, how, player?): boolean   -- true when it went out
		DisasterService:StartBlackout(floor?, cause): string?             -- floor nil: the whole grid
		DisasterService:EndBlackout(how, player?)
		DisasterService:CaveIn(floor, column, side?, cause): (string?, string?) -- side "Left"/"Right": a doorway
		DisasterService:ClearRubble(id, how, player?)
		DisasterService:StartMeltdown(cause): boolean
		DisasterService:StartElectricalSurge(roomId, cause): string?
		DisasterService:SurgeDisaster(budget, rng): number   -- ThreatDirector: the ThreatCost spent
		DisasterService:HoldsSurge(): boolean                -- ThreatDirector: don't end the Surge yet
		DisasterService:SetModifier(source, key, value?)     -- FireSpread, BlackoutDuration
		DisasterService:Active(): { [string]: any }          -- the collection's entries
		DisasterService.Started: Signal<string, string>      -- id, kind
		DisasterService.Ended: Signal<string, string, string> -- id, kind, how
	Dev: disasters, fire, fire.out, blackout, blackout.end, cavein, rubble.clear, meltdown,
	meltdown.stop, valve, esurge, disaster.surge.
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
	local fireCount, rubbleCount = 0, 0
	for _ in fires do
		fireCount += 1
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

-- The Surge disasters this service can start (Landon, Prompt 13: cave-ins too; floods and gas
-- leaks join with Prompt 23).
local SURGE_STARTS: { [string]: boolean } = { Fire = true, Blackout = true, CaveIn = true }

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
	local entry = surgeDisaster
	if entry then
		return entry.Id == nil or isActive(entry.Id)
	end
	return false
end

-- Modifiers and queries --------------------------------------------------------------------------------

function DisasterService:SetModifier(source: string, key: string, value: number?)
	assert(key == "FireSpread" or key == "BlackoutDuration", `DisasterService:SetModifier: {key} isn't a disaster modifier`)
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
		end
	end)
	grid.Changed:Connect(onGridChanged)
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
