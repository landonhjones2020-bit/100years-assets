--!strict
--[[
	ClassService: the class each player brings and what it does (bible Section 14; Section 9: Q is
	the class ability). Run place only; Prompt 20. The rules are Shared.Rules.Classes and
	Rules.Modifiers; what each ability does in the world is Lib.ClassAbilities.

	Which class
	* The lobby writes the run's record to MemoryStore before the teleport (Lib.RunRecord, keyed by
	  this reserved server's PrivateServerId; Prompt 21 writes it). When a player's session is ready
	  their class is the record's, if their profile owns it (Classes) or it is their free trial;
	  their class level is the profile's (a trial plays at level 1). With no record, or a class they
	  don't own, they are the Survivor. In Studio the record's key is "Studio" (dev `record`).
	* The class goes on the player (Class, ClassLevel, ClassTrial attributes: every system reads
	  effects through Modifiers.PlayerValue, so level 2 and 3 apply everywhere) and the kit into
	  their hands (WeaponService:SetClass).

	The ability (Q, LB, the touch Ability button; Rules.Classes)
	* UseAbility(option, camera position, look) from the client. The server checks the run is
	  playing, the player stands, and the ability is ready: its cooldown in seconds or cycles, or a
	  use left (uses come back when each Surge starts, each cycle, each era). Lib.ClassAbilities runs
	  it; one that can't do anything says why and costs nothing. A hold of the key picks the next
	  option (PickAbilityOption); the Mad Scientist's gadgets each keep their own cooldown.
	* What the HUD reads, on the Player: AbilityReadyAt (server time; nil = ready), AbilityReadyCycle,
	  AbilityUses and AbilityMax, AbilityOption (the option's name), AbilityOptionReadyAt (that
	  option's own cooldown), AbilityEffect and AbilityActiveUntil (an effect in play: Hold the Line,
	  a drone mode), SteadyShots.

	Passives and levels (Config.Classes' modifiers)
	* Effects on the holder are read where they apply (PlayerValue): the Medic's revive time (the
	  client's prompt), the Security's +30 health (CombatService:SetMaxHealthFn), the Exterminator's
	  CreatureDamage (WeaponService:AddHitModifier), the Demolitionist's explosives, the Marksman's
	  zoom, and the passives of earlier prompts.
	* Effects on the whole bunker (Scope Bunker: StockpileCaps, BuildCost, BuildSpeed, ResidentXP,
	  RoomOutput of a room type, AllOutput, FoodUse, FireSpread, BlastDoorHealth) go to their systems
	  as the strongest holder's value: two Quartermasters don't stack. They follow whoever is in the
	  run as classes change and players leave.
	* The damage filter (CombatService:AddDamageFilter): Hold the Line and the drone's Guard cut what
	  their player takes; residents hit harder near a Security (NearbyResidentDamage, the strongest
	  one in NearbyResidentRange), armed (ArmedResidentDamage), and rallied (RallyDamage).
	* Hits (WeaponService.Hit): flame hits set monsters burning; a crit (Marksman 3) or a blast
	  (Demolitionist 3) staggers a boss (BossService:Stun); a kill by a level 3 Exterminator lowers
	  Disturbance by KillDisturbance.
	* The Warden breaks tied votes and drafts with their own ballot (VoteService:SetTieBreaker); a
	  level 2 Warden picks the stat residents raise when they level (ChooseLevelStat; RunState
	  LevelStat, cleared when no such Warden is left).

	Class experience (Section 14: about 3 runs for level 2 and 10 for level 3)
	* ResultsService pays it with the run's Glowshards: RunXP(player, years, paidYears) is the class
	  and the experience the run earned (Rules.Classes.RunXP; none for a trial); the level follows
	  the experience (Rules.Classes.LevelFor) and Refresh(player) puts a new level in play at once.

	API: Get(player): State?, SetClass(player, classId, level?, trial?, why?), RunXP(player, years,
	paidYears?): (string?, number), Refresh(player).
	Dev: class <Id> [level], class.level <1-3>, class.own <Id> [level] [xp], ability [option],
	ability.ready, classes, classxp <years>, resident.arm <id> [item], record <Class> [trial].
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Classes = require(Shared.Rules.Classes)
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Abilities = require(ServerScriptService.Lib.ClassAbilities)
local RunRecord = require(ServerScriptService.Lib.RunRecord)

local log = Log.new("ClassService")
local set = RunState.Writer("ClassService")
local IS_STUDIO = RunService:IsStudio()

export type State = {
	Player: Player,
	Class: string,
	Level: number,
	Trial: boolean,
	Option: number,
	ReadyAt: number, -- server time the shared cooldown ends
	ReadyCycle: number?, -- the cycle a cycle cooldown ends on (Hearty Meal)
	OptionReadyAt: { [number]: number }, -- own cooldowns (the Mad Scientist's gadgets)
	Uses: number?, -- uses left this Surge, cycle or era
	Effect: string?, -- an effect in play: "Hold", "Rally", a drone mode
	EffectUntil: number, -- os.clock()
	EffectEndsAt: number, -- the same, server time (for the HUD)
	Shots: number, -- Steady Shot shots left
	DroneRevives: number, -- the drone's revives left this Surge
}

local ClassService = {
	Name = "ClassService",
	Dependencies = {
		"SessionService", "ProfileService", "RunDirector", "CycleClock", "CombatService", "WeaponService", "MonsterService",
		"BossService", "BunkerGrid", "EconomyService", "BuildService", "DisasterService", "DigService", "ResidentService",
		"ResidentBrain", "BreachService", "SurfaceService", "DeepService", "InventoryService", "RescueService", "VoteService",
		"DevService",
	},
}

local session: any = nil
local profiles: any = nil
local director: any = nil
local clock: any = nil
local combat: any = nil
local weapons: any = nil
local boss: any = nil
local grid: any = nil
local economy: any = nil
local build: any = nil
local disasters: any = nil
local dig: any = nil
local residents: any = nil
local brain: any = nil
local votes: any = nil

local states: { [Player]: State } = {}
local record: RunRecord.Record? = nil
local recordRead = false
local lastHit: { [string]: string } = {} -- monster combatant id -> "P<user id>" who hit it last

local function now(): number
	return workspace:GetServerTimeNow()
end

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function alertAll(kind: string, text: string)
	for _, player in session:ReadyPlayers() do
		alert(player, kind, text)
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The HUD's attributes --------------------------------------------------------------------------------

local function publish(state: State)
	local player = state.Player
	local ability = Classes.Ability(state.Class)
	player:SetAttribute("Class", state.Class)
	player:SetAttribute("ClassLevel", state.Level)
	player:SetAttribute("ClassTrial", if state.Trial then true else nil)
	player:SetAttribute("AbilityReadyAt", if state.ReadyAt > now() then state.ReadyAt else nil)
	player:SetAttribute("AbilityReadyCycle", if state.ReadyCycle and state.ReadyCycle > clock:Cycle() then state.ReadyCycle else nil)
	player:SetAttribute("AbilityUses", state.Uses)
	player:SetAttribute("AbilityMax", Classes.UsesFor(state.Class, state.Level))
	player:SetAttribute("AbilityOption", Classes.OptionName(state.Class, state.Option))
	local own = state.OptionReadyAt[state.Option]
	player:SetAttribute("AbilityOptionReadyAt", if own and own > now() then own else nil)
	local active = state.Effect ~= nil and os.clock() < state.EffectUntil
	player:SetAttribute("AbilityEffect", if active then state.Effect else nil)
	player:SetAttribute("AbilityActiveUntil", if active then state.EffectEndsAt else nil)
	player:SetAttribute("SteadyShots", if state.Shots > 0 then state.Shots else nil)
	player:SetAttribute("AbilityName", if ability then ability.Name else nil)
end

-- Bunker-wide class effects ---------------------------------------------------------------------------

-- The systems that take a bunker-wide key: fn(value or nil, room?).
local BUNKER: { [string]: (number?, string?) -> () } = {
	StockpileCaps = function(v)
		economy:SetModifier("class", "StockpileCaps", v)
	end,
	AllOutput = function(v)
		economy:SetModifier("class", "AllOutput", v)
	end,
	FoodUse = function(v)
		economy:SetModifier("class", "FoodUse", v)
	end,
	RoomOutput = function(v, room)
		economy:SetModifier("class", "RoomOutput", v, room)
	end,
	BuildCost = function(v)
		build:SetModifier("class", "BuildCost", v)
	end,
	BuildSpeed = function(v)
		build:SetModifier("class", "BuildSpeed", v)
	end,
	ResidentXP = function(v)
		residents:SetModifier("class", "ResidentXP", v)
	end,
	FireSpread = function(v)
		disasters:SetModifier("class", "FireSpread", v)
	end,
	BlastDoorHealth = function(v)
		grid:SetHPModifier("class", "BlastDoorHealth", v)
	end,
}

local applied: { [string]: number } = {} -- "key|room" -> value in play

-- How strong a value is, by its key's unit: the farthest from neutral wins.
local function strength(key: string, value: number): number
	local info = Config.Find("Modifiers", key)
	if info and (info.Unit == "Multiplier" or info.Unit == "Chance") then
		return math.abs(math.log(math.max(value, 1e-6)))
	end
	return math.abs(value)
end

local function refreshBunker()
	local best: { [string]: { Key: string, Room: string?, Value: number } } = {}
	for _, state in states do
		if state.Player.Parent == Players then
			for _, modifier in Modifiers.ClassModifiers(state.Class, state.Level) do
				local info = Config.Find("Modifiers", modifier.Key)
				local scope = modifier.Scope or (if info then info.Scope else nil)
				if scope == "Bunker" and BUNKER[modifier.Key] then
					local id = `{modifier.Key}|{modifier.Room or ""}`
					local have = best[id]
					if not have or strength(modifier.Key, modifier.Value) > strength(modifier.Key, have.Value) then
						best[id] = { Key = modifier.Key, Room = modifier.Room, Value = modifier.Value }
					end
				end
			end
		end
	end
	for id, entry in best do
		if applied[id] ~= entry.Value then
			BUNKER[entry.Key](entry.Value, entry.Room)
			applied[id] = entry.Value
		end
	end
	for id in table.clone(applied) do
		if not best[id] then
			local key, room = string.match(id, "^([^|]+)|(.*)$")
			if key and BUNKER[key] then
				BUNKER[key](nil, if room ~= "" then room else nil)
			end
			applied[id] = nil
		end
	end
	-- a level 2 Warden's stat choice ends when none is left
	if RunState.Get("LevelStat") ~= nil then
		local any = false
		for _, state in states do
			if state.Player.Parent == Players and Modifiers.PlayerValue(state.Player, "ChoosesLevelStat") then
				any = true
			end
		end
		if not any then
			residents:SetLevelStat(nil)
			set("LevelStat", nil)
		end
	end
end

-- Setting a class ---------------------------------------------------------------------------------------

function ClassService:Get(player: Player): State?
	return states[player]
end

function ClassService:SetClass(player: Player, classId: string, level: number?, trial: boolean?, why: string?)
	local class = Config.Find("Classes", classId)
	if not class then
		classId = "Survivor"
	end
	local lvl = math.clamp(math.floor(level or 1), 1, Classes.Tuning().LevelMax)
	local old = states[player]
	local state: State = {
		Player = player,
		Class = classId,
		Level = lvl,
		Trial = trial == true,
		Option = 1,
		ReadyAt = 0,
		ReadyCycle = nil,
		OptionReadyAt = {},
		Uses = Classes.UsesFor(classId, lvl),
		Effect = nil,
		EffectUntil = 0,
		EffectEndsAt = 0,
		Shots = 0,
		DroneRevives = math.floor(Modifiers.ClassValue(classId, "DroneRevivesPerSurge", lvl) or 0),
	}
	-- the same class at a new level keeps its cooldowns
	if old and old.Class == classId then
		state.ReadyAt, state.ReadyCycle, state.OptionReadyAt, state.Option = old.ReadyAt, old.ReadyCycle, old.OptionReadyAt, old.Option
		local newMax, oldMax = Classes.UsesFor(classId, lvl), Classes.UsesFor(classId, old.Level)
		if newMax and old.Uses then
			state.Uses = math.clamp(old.Uses + newMax - (oldMax or newMax), 0, newMax)
		end
		state.Shots = old.Shots
	end
	states[player] = state
	player:SetAttribute("Class", classId)
	player:SetAttribute("ClassLevel", lvl)
	weapons:SetClass(player, classId, lvl)
	publish(state)
	Abilities.ClassChanged(player, state)
	combat:RefreshMaxHealth(player)
	refreshBunker()
	log:Info("%s is a level %d %s%s (%s)", player.Name, lvl, classId, if trial then " (trial)" else "", why or "set")
end

local function readRecord()
	if recordRead then
		return
	end
	recordRead = true
	local key = RunRecord.Key()
	if not key then
		log:Info("no run record: not a reserved Run server")
		return
	end
	local found, why = RunRecord.Read(key)
	record = found
	if found then
		log:Info("run record %s: %d loadouts", key, (function()
			local n = 0
			for _ in found.Loadouts do
				n += 1
			end
			return n
		end)())
	else
		log:Info("no run record under %s (%s)", key, tostring(why))
	end
end

-- The class a player brings: the record's, if they own it or it is their trial; else the Survivor.
local function chosen(player: Player): (string, number, boolean)
	readRecord()
	local loadout = RunRecord.Loadout(record, player.UserId)
	local profile = profiles:Get(player)
	if loadout and Config.Find("Classes", loadout.Class) then
		local owned = profile and profile.Classes[loadout.Class]
		if owned then
			return loadout.Class, owned.Level, false
		elseif loadout.Trial then
			return loadout.Class, 1, true
		end
		log:Warn("%s's record names %s, which they don't own: the Survivor", player.Name, loadout.Class)
	end
	local survivor = profile and profile.Classes.Survivor
	return "Survivor", if survivor then survivor.Level else 1, false
end

-- Class experience ----------------------------------------------------------------------------------------

function ClassService:RunXP(player: Player, years: number, paidYears: number?): (string?, number)
	local state = states[player]
	if not state or state.Trial then
		return nil, 0
	end
	return state.Class, Classes.RunXP(years, paidYears)
end

-- The profile's level for the player's class put in play (after the run paid a level up).
function ClassService:Refresh(player: Player)
	local state = states[player]
	local profile = profiles:Get(player)
	local entry = if state and profile then profile.Classes[state.Class] else nil
	if state and entry and not state.Trial and entry.Level ~= state.Level then
		ClassService:SetClass(player, state.Class, entry.Level, false, "a class level up")
	end
end

-- The ability ----------------------------------------------------------------------------------------------

local function perText(per: string?): string
	return if per == "Surge" then "THE NEXT SURGE" elseif per == "Cycle" then "THE NEXT CYCLE" elseif per == "Era" then "THE NEXT ERA" else "LATER"
end

local function ready(state: State, option: number): (boolean, string?)
	local ability = Classes.Ability(state.Class)
	if not ability then
		return false, "THIS CLASS HAS NO ABILITY"
	end
	if state.Uses ~= nil and state.Uses <= 0 then
		return false, `NO USES LEFT: MORE AT {perText(Classes.UsesPer(state.Class))}`
	end
	if state.ReadyCycle and clock:Cycle() < state.ReadyCycle then
		local left = state.ReadyCycle - clock:Cycle()
		return false, `{string.upper(ability.Name)} IS READY IN {left} CYCLE{if left == 1 then "" else "S"}`
	end
	local waitUntil = if Classes.OwnCooldowns(state.Class) then state.OptionReadyAt[option] or 0 else state.ReadyAt
	if waitUntil > now() + 0.05 then
		return false, `{string.upper(Classes.OptionName(state.Class, option) or ability.Name)} IS READY IN {math.ceil(waitUntil - now())} S`
	end
	return true, nil
end

local function spend(state: State, option: number)
	local ability = Classes.Ability(state.Class)
	if not ability then
		return
	end
	if state.Uses ~= nil then
		state.Uses = math.max(state.Uses - 1, 0)
	end
	if ability.CooldownCycles then
		state.ReadyCycle = clock:Cycle() + ability.CooldownCycles
	end
	if ability.CooldownSeconds then
		local seconds = ability.CooldownSeconds / math.max(clock:TimeScale(), 0.01)
		if Classes.OwnCooldowns(state.Class) then
			state.OptionReadyAt[option] = now() + seconds
		else
			state.ReadyAt = now() + seconds
		end
	end
end

local function use(player: Player, optionArg: number, origin: Vector3, look: Vector3): (boolean, string?)
	local state = states[player]
	if not state then
		return false, "YOU HAVE NO CLASS YET"
	end
	if director:Phase() ~= "Playing" then
		return false, "THE RUN ISN'T UNDER WAY"
	end
	if player:GetAttribute("Life") ~= "Alive" or not rootOf(player) then
		return false, "YOU NEED TO BE STANDING"
	end
	if player:GetAttribute("Carrying") then
		return false, "YOUR HANDS ARE FULL"
	end
	local option = if optionArg > 0 then Classes.OptionIndex(state.Class, optionArg) else state.Option
	local ok, why = ready(state, option)
	if not ok then
		return false, why
	end
	local used, text, effect, seconds = Abilities.Use(state, option, origin, look)
	if not used then
		return false, text
	end
	spend(state, option)
	if effect and seconds and seconds > 0 then
		state.Effect = effect
		state.EffectUntil = os.clock() + seconds
		state.EffectEndsAt = now() + seconds
	end
	publish(state)
	local optionName = Classes.OptionName(state.Class, option)
	log:Info("%s used %s%s", player.Name, (Classes.Ability(state.Class) :: any).Name, if optionName then ` ({optionName})` else "")
	return true, text
end

local function onUseAbility(player: Player, option: number, origin: Vector3, look: Vector3)
	local ok, text = use(player, option, origin, look)
	if text then
		alert(player, if ok then "Info" else "Warning", text)
	end
end

local function onPickOption(player: Player, index: number)
	local state = states[player]
	if not state or #Classes.Options(state.Class) == 0 then
		return
	end
	state.Option = Classes.OptionIndex(state.Class, index)
	publish(state)
end

local function onTeleport(player: Player)
	local ok, why = Abilities.Teleport(player)
	if not ok and why then
		alert(player, "Warning", why)
	end
end

local function onChooseStat(player: Player, stat: string)
	if not Modifiers.PlayerValue(player, "ChoosesLevelStat") then
		alert(player, "Warning", "ONLY A LEVEL 2 WARDEN CHOOSES THE LEVEL-UP STAT")
		return
	end
	local id: string? = nil
	if stat ~= "" then
		id = Config.Find("Stats", stat) and stat or nil
		if not id then
			return
		end
	end
	residents:SetLevelStat(id)
	set("LevelStat", id)
	alertAll("Info", if id then `{string.upper(player.DisplayName)}: RESIDENTS' LEVELS NOW RAISE {string.upper(id)}`
		else `{string.upper(player.DisplayName)}: RESIDENTS' LEVELS RAISE THEIR JOB'S STAT AGAIN`)
end

-- Uses come back ------------------------------------------------------------------------------------------

local function refill(per: string)
	for _, state in states do
		if Classes.UsesPer(state.Class) == per then
			state.Uses = Classes.UsesFor(state.Class, state.Level)
			publish(state)
		end
		if per == "Surge" then
			state.DroneRevives = math.floor(Modifiers.ClassValue(state.Class, "DroneRevivesPerSurge", state.Level) or 0)
		end
	end
end

-- Damage ----------------------------------------------------------------------------------------------------

local function damageFilter(target: any, amount: number, source: any, _how: string?): number
	local tt = Classes.Tuning()
	if target.Kind == "Player" and target.Player then
		local state = states[target.Player]
		if state and state.Effect and os.clock() < state.EffectUntil then
			if state.Effect == "Hold" then
				amount *= tt.HoldDamageTaken
			elseif state.Effect == "Guard" then
				amount *= tt.Drone.GuardDamageTaken
			end
		end
	end
	if source and source.Kind == "Resident" and target.Team == "Monsters" and source.ResidentId then
		local nearby = 1
		for _, p in session:ReadyPlayers() do
			local v = Modifiers.PlayerValue(p, "NearbyResidentDamage")
			local root = rootOf(p)
			if v and v > nearby and root and p:GetAttribute("Life") == "Alive"
				and (root.Position - source.Root.Position).Magnitude <= tt.NearbyResidentRange then
				nearby = v
			end
		end
		amount *= nearby
		local resident = residents:Get(source.ResidentId)
		if resident and resident.Weapon then
			local armed = 1
			for _, p in session:ReadyPlayers() do
				local v = Modifiers.PlayerValue(p, "ArmedResidentDamage")
				if v and v > armed then
					armed = v
				end
			end
			amount *= armed
		end
		amount *= brain:RallyBonus(source.ResidentId)
	end
	return amount
end

local function hitModifier(target: any, _point: Vector3?, _how: string, player: Player): number
	if target.Kind == "Monster" then
		return Modifiers.PlayerValue(player, "CreatureDamage") or 1
	end
	return 1
end

local function onHit(player: Player, targetId: string, _done: number, how: string, _point: Vector3?)
	if how == "burned" then
		Abilities.Burn(targetId, player)
	elseif how == "crit" and boss:IsBoss(targetId) and Modifiers.PlayerValue(player, "CritsStaggerBosses") then
		boss:Stun(targetId, `{player.Name}'s crit`)
	elseif how == "blast" and boss:IsBoss(targetId) and Modifiers.PlayerValue(player, "ExplosionsStunBosses") then
		boss:Stun(targetId, `{player.Name}'s explosion`)
	end
end

-- DevTools ---------------------------------------------------------------------------------------------------

local function describe(state: State): string
	local ability = Classes.Ability(state.Class)
	local parts = { `{state.Player.Name}: {state.Class} L{state.Level}{if state.Trial then " (trial)" else ""}` }
	if ability then
		table.insert(parts, ability.Name)
	end
	local option = Classes.OptionName(state.Class, state.Option)
	if option then
		table.insert(parts, `option {option}`)
	end
	if state.Uses ~= nil then
		table.insert(parts, `uses {state.Uses}/{Classes.UsesFor(state.Class, state.Level)}`)
	end
	local waitUntil = if Classes.OwnCooldowns(state.Class) then state.OptionReadyAt[state.Option] or 0 else state.ReadyAt
	table.insert(parts, if waitUntil > now() then string.format("ready in %.0f s", waitUntil - now()) else "ready")
	if state.ReadyCycle and state.ReadyCycle > clock:Cycle() then
		table.insert(parts, `ready at cycle {state.ReadyCycle}`)
	end
	if state.Effect and os.clock() < state.EffectUntil then
		table.insert(parts, string.format("%s for %.0f s", state.Effect, state.EffectUntil - os.clock()))
	end
	if state.Shots > 0 then
		table.insert(parts, `steady shots {state.Shots}`)
	end
	return table.concat(parts, " · ")
end

local function target(player: Player?, arg: any): Player?
	if type(arg) == "string" and arg ~= "" then
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == string.lower(arg) or tostring(p.UserId) == arg then
				return p
			end
		end
	end
	return player
end

local function registerCommands(dev: any)
	dev:Register("classes", {
		Description = "Every player's class, level, ability and cooldown, and the class devices in play.",
		Usage = "classes",
		Run = function(): string?
			local lines = {}
			for _, state in states do
				table.insert(lines, describe(state))
			end
			table.sort(lines)
			local applied_ = {}
			for id, v in applied do
				table.insert(applied_, `{id}={v}`)
			end
			table.sort(applied_)
			table.insert(lines, `bunker-wide: {if #applied_ > 0 then table.concat(applied_, ", ") else "none"}`)
			table.insert(lines, Abilities.Describe())
			return table.concat(lines, "\n")
		end,
	})
	dev:Register("class", {
		Description = "Take a class (its kit and ability) at a level, for testing (Prompt 21's loadouts set it for real).",
		Usage = "class <ClassId> [level] [player]",
		Run = function(player, args): string?
			local who = target(player, args[3])
			if not who then
				return "players only"
			end
			local id = tostring(args[1] or "")
			if not Config.Find("Classes", id) then
				return `no class {id}`
			end
			ClassService:SetClass(who, id, tonumber(args[2]) or 1, false, "dev")
			return describe(states[who])
		end,
	})
	dev:Register("class.level", {
		Description = "Set your class level (1 to 3) for this run.",
		Usage = "class.level <1-3> [player]",
		Run = function(player, args): string?
			local who = target(player, args[2])
			local state = who and states[who]
			if not who or not state then
				return "players only"
			end
			ClassService:SetClass(who, state.Class, tonumber(args[1]) or 1, state.Trial, "dev")
			return describe(states[who])
		end,
	})
	dev:Register("class.own", {
		Description = "Put a class in your profile (Studio only), with a level and experience.",
		Usage = "class.own <ClassId> [level] [xp]",
		Run = function(player, args): string?
			if not IS_STUDIO then
				return "Studio only"
			end
			if not player then
				return "players only"
			end
			local id = tostring(args[1] or "")
			if not Config.Find("Classes", id) then
				return `no class {id}`
			end
			local level = math.clamp(math.floor(tonumber(args[2]) or 1), 1, 3)
			local xp = math.max(0, tonumber(args[3]) or Classes.LevelXP(level))
			local ok = profiles:Update(player, function(data: any)
				data.Classes[id] = { Level = level, XP = xp }
			end)
			return if ok then `{id} is in your profile at level {level} ({xp} experience)` else "the profile couldn't be written"
		end,
	})
	dev:Register("ability", {
		Description = "Use your class ability as Q would, aimed where your character faces.",
		Usage = "ability [option] [player]",
		Run = function(player, args): string?
			local who = target(player, args[2])
			local root = who and rootOf(who)
			if not who or not root then
				return "players only"
			end
			local origin = root.Position + Vector3.new(0, 2, 0)
			local ok, text = use(who, math.floor(tonumber(args[1]) or 0), origin, root.CFrame.LookVector)
			return `{if ok then "used" else "refused"}: {text or ""}`
		end,
	})
	dev:Register("ability.ready", {
		Description = "Make your ability ready now (cooldowns and uses back).",
		Usage = "ability.ready [player]",
		Run = function(player, args): string?
			local who = target(player, args[1])
			local state = who and states[who]
			if not state then
				return "players only"
			end
			state.ReadyAt, state.ReadyCycle, state.OptionReadyAt = 0, nil, {}
			state.Uses = Classes.UsesFor(state.Class, state.Level)
			publish(state)
			return describe(state)
		end,
	})
	dev:Register("classxp", {
		Description = "Pay your class's experience for a run that reached this many years, as the results would (saved).",
		Usage = "classxp <years>",
		Run = function(player, args): string?
			if not player then
				return "players only"
			end
			local classId, xp = ClassService:RunXP(player, tonumber(args[1]) or 50, 0)
			if not classId then
				return "no class experience (no class, or a trial)"
			end
			local result = ""
			local ok = profiles:Update(player, function(data: any)
				local entry = data.Classes[classId]
				if not entry then
					result = `{classId} isn't in your profile (class.own)`
					return
				end
				entry.XP += xp
				local level = math.max(entry.Level, Classes.LevelFor(entry.XP))
				result = `{classId}: +{xp} experience, {entry.XP} in all, level {entry.Level} -> {level}`
				entry.Level = level
			end)
			if ok then
				task.spawn(function()
					profiles:SaveNow(player)
				end)
				ClassService:Refresh(player)
			end
			return if ok then result else "the profile couldn't be written"
		end,
	})
	dev:Register("resident.arm", {
		Description = "Give a resident a weapon (gear is Prompt 26), so they answer the Warden's Rally Call; none disarms.",
		Usage = "resident.arm <id|all> [ItemId|none]",
		Run = function(_, args): string?
			local item: string? = tostring(args[2] or "LeadPipe")
			if item == "none" then
				item = nil
			elseif not Config.Find("Items", item :: string) then
				return `no item {item}`
			end
			local which = tostring(args[1] or "")
			local n = 0
			for _, resident in residents:All() do
				if (which == "all" or resident.Id == which) and residents:Arm(resident.Id, item) then
					n += 1
				end
			end
			return `{n} resident{if n == 1 then "" else "s"} {if item then `armed with {item}` else "disarmed"}`
		end,
	})
	dev:Register("record", {
		Description = "Write a test run record in Studio (MemoryStore, key \"Studio\") with your class, and read it back as a new player would.",
		Usage = "record <ClassId> [trial]",
		Run = function(player, args): string?
			if not IS_STUDIO or not player then
				return "Studio players only"
			end
			local id = tostring(args[1] or "")
			if not Config.Find("Classes", id) then
				return `no class {id}`
			end
			local entry: RunRecord.Record = {
				Version = RunRecord.VERSION,
				Party = { player.UserId },
				Difficulty = director:Difficulty(),
				Loadouts = { [tostring(player.UserId)] = { Class = id, Trial = args[2] == "trial" } },
				CreatedAt = os.time(),
			}
			local ok, why = RunRecord.Write(RunRecord.STUDIO_KEY, entry, 600)
			if not ok then
				return `couldn't write: {why}`
			end
			recordRead = false
			record = nil
			local class, level, trial = chosen(player)
			ClassService:SetClass(player, class, level, trial, "the run record")
			return `record written and read: {describe(states[player])}`
		end,
	})
end

-- Lifecycle -------------------------------------------------------------------------------------------------

function ClassService:Init(registry)
	session = registry.SessionService
	profiles = registry.ProfileService
	director = registry.RunDirector
	clock = registry.CycleClock
	combat = registry.CombatService
	weapons = registry.WeaponService
	boss = registry.BossService
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	build = registry.BuildService
	disasters = registry.DisasterService
	dig = registry.DigService
	residents = registry.ResidentService
	brain = registry.ResidentBrain
	votes = registry.VoteService
	Abilities.Init({
		Combat = combat,
		Weapons = weapons,
		Monsters = registry.MonsterService,
		Boss = boss,
		Grid = grid,
		Economy = economy,
		Build = build,
		Disasters = disasters,
		Dig = dig,
		Residents = residents,
		Brain = brain,
		Breaches = registry.BreachService,
		Surface = registry.SurfaceService,
		Deep = registry.DeepService,
		Inventory = registry.InventoryService,
		Rescue = registry.RescueService,
		Clock = clock,
		Session = session,
		State = function(player: Player): any
			return states[player]
		end,
		SetBeacon = function(untilAt: number?, by: string?)
			set("BeaconUntil", untilAt)
			set("BeaconBy", by)
		end,
	})
	registerCommands(registry.DevService)
end

function ClassService:Start()
	combat:SetMaxHealthFn(function(player: Player): number
		local base = Config.Get("Tuning", "Player").Health + (Modifiers.PlayerValue(player, "MaxHealth") or 0)
		return base * Abilities.MealMultiplier()
	end)
	combat:AddDamageFilter("classes", damageFilter)
	weapons:AddHitModifier("classes", hitModifier)
	weapons:SetShotHook(Abilities.ShotHook)
	weapons.Hit:Connect(onHit)
	-- the Warden's ballot breaks ties (Section 14); the first Warden by user id who voted
	votes:SetTieBreaker(function(_voteId: string, ballots: { [number]: string }): string?
		local wardens = {}
		for _, p in session:ReadyPlayers() do
			if Modifiers.PlayerValue(p, "BreaksVoteTies") then
				table.insert(wardens, p.UserId)
			end
		end
		table.sort(wardens)
		for _, userId in wardens do
			if ballots[userId] then
				return ballots[userId]
			end
		end
		return nil
	end)

	session.PlayerReady:Connect(function(player: Player)
		local class, level, trial = chosen(player)
		ClassService:SetClass(player, class, level, trial, "joined")
	end)
	for _, player in session:ReadyPlayers() do
		if not states[player] then
			local class, level, trial = chosen(player)
			ClassService:SetClass(player, class, level, trial, "joined")
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
		Abilities.ClassChanged(player, nil)
		task.defer(refreshBunker)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			Abilities.Spawned(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	combat.Downed:Connect(function(id: string)
		local c = combat:Get(id)
		if c and c.Player then
			Abilities.Downed(c.Player)
		end
	end)
	combat.Damaged:Connect(function(targetId: string, _amount: number, sourceId: string?)
		if sourceId and string.sub(sourceId, 1, 1) == "P" then
			local c = combat:Get(targetId)
			if c == nil or c.Team == "Monsters" then
				lastHit[targetId] = sourceId
			end
		end
	end)
	combat.Died:Connect(function(id: string)
		local by = lastHit[id]
		lastHit[id] = nil
		local userId = if by then tonumber(string.sub(by, 2)) else nil
		local player = if userId then Players:GetPlayerByUserId(userId) else nil
		if player and Modifiers.PlayerValue(player, "KillsLowerDisturbance") then
			dig:AddDisturbance(-Classes.Tuning().KillDisturbance, "Exterminator")
		end
	end)

	clock.SurgeStarted:Connect(function()
		refill("Surge")
	end)
	clock.CycleStarted:Connect(function()
		refill("Cycle")
		for _, state in states do
			publish(state) -- a cycle cooldown may be over
		end
	end)
	clock.EraChanged:Connect(function()
		refill("Era")
	end)

	local syncQueued = false
	grid.RoomChanged:Connect(function()
		if not syncQueued then
			syncQueued = true
			task.delay(0.5, function()
				syncQueued = false
				local ok, err = pcall(Abilities.SyncBarricades)
				if not ok then
					log:Warn("barricades: %s", tostring(err))
				end
			end)
		end
	end)
	task.defer(function()
		local ok, err = pcall(Abilities.SyncBarricades)
		if not ok then
			log:Warn("barricades: %s", tostring(err))
		end
	end)

	Remotes.OnServer("UseAbility", onUseAbility)
	Remotes.OnServer("PickAbilityOption", onPickOption)
	Remotes.OnServer("TeleportToBeacon", onTeleport)
	Remotes.OnServer("ChooseLevelStat", onChooseStat)

	local fast, slow = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		fast += dt
		slow += dt
		if fast >= 0.1 then
			local step = math.min(fast, 0.5)
			fast = 0
			Abilities.Tick(step)
		end
		if slow >= 1 then
			local step = math.min(slow, 2)
			slow = 0
			Abilities.Slow(step)
			for _, state in states do
				if state.Effect and os.clock() >= state.EffectUntil then
					state.Effect = nil
					publish(state)
				end
			end
		end
	end)
	log:Info("classes ready: %d classes, the run record %s", #Config.Ids("Classes"), tostring(RunRecord.Key()))
end

return ClassService
