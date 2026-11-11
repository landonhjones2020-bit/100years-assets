--!strict
--[[
	BossService: boss fights (bible Sections 5, 10 and 22). Run place only; Prompt 15 brings the
	Era I boss, the Brood Mother, Prompt 23 the Era II boss, The Deluge, Prompt 24 the Era III
	boss, the Crystal Colossus. The arithmetic is
	Shared.Rules.Boss; the numbers are Config.Bosses, Tuning.Bosses and Tuning.<BossId> (provisional).

	* A boss Surge (CycleClock.SurgeStarted with kind Boss) starts its boss's fight. Section 5: the
	  Surge has no timer and ends when the boss dies (ObjectiveService:BossBeaten, which also adds
	  1 to Years per Cycle).
	* Arrival (Section 10: the Brood Mother bursts up through the deepest tunnel): the arena is
	  Rules.Boss.Arena. Cracks, dust, a red light and an alert give ArrivalWarningSeconds of
	  warning; then she rises out of the floor in a burst of rock and roars.
	* Health: Rules.Boss.Health (the team's size; weaker on an account's first run, Section 22).
	  Hits on her armour do ArmourMultiplier; hits on her glowing belly (the model's WeakPoint part)
	  WeakPointMultiplier, the Sharpshooter's own if they have it (WeaponService:SetHitModifier;
	  such hits are Damaged with how "weakpoint").
	* The fight, ticked every TickSeconds while she lives:
	  - she turns to the nearest standing player and walks along her arena towards them (she is
	    too big for a doorway, so she never leaves it);
	  - within SlamReach she rears and slams (the Attack clip's HitTime): SlamDamage to players and
	    residents within SlamRadius of the blow;
	  - every LaySeconds she lays SacsPerLay egg sacs behind her (her Ovipositor socket), up to
	    MaxSacs; a sac (SacHealth; fire does BurnMultiplier) hatches HatchCount Burrow Ticks after
	    HatchSeconds unless it is broken or burned first;
	  - StaggerFraction of her health dealt to her belly within StaggerWindowSeconds staggers her
	    for StaggerSeconds;
	  - each new phase (Config.Bosses' Phases) she roars, lays more often and moves faster.
	* Death: the Death clip, her sacs wither, BossBeaten ends the Surge, Defeated fires; after
	  DeathSeconds she dissolves.
	* The Deluge (Section 10: "A giant eel surging up the flooded tunnels. Floods every room it
	  passes; strike its head when it surfaces and drain the rooms behind it."; Tuning.Deluge). It
	  arrives like any boss, in Rules.Boss.Arena, but it doesn't stay there. The fight's Mode:
	  - Up: it stands out of the floor, turns to whoever is near and bites (the Attack clip's
	    HitTime: BiteDamage within BiteRadius of its Bite socket). Its head is the model's WeakPoint
	    part; enough damage to it staggers it. After SurfaceSeconds (sooner with nobody near for
	    AloneSeconds) it dives;
	  - Diving, Swim: it sinks SwimDepth so only its back fin cuts the floor (hits on it do
	    SubmergedMultiplier), and swims Rules.Bunker.CellPath to the nearest standing player it can
	    reach, re-aimed at every cell, for at most SwimSeconds. Every room it passes bursts a pipe
	    and takes FloodLevel of water (DisasterService:StartFlood, cause "Deluge"; the Shaft takes the
	    water but has no pipe): patching those pipes is "drain the rooms behind it";
	  - Surfacing: it comes up where it is (never in a Shaft), and from its second phase Murklings
	    pour out with it (Config.Bosses' Minions).
	  It moves every frame (an anchored model isn't smoothed between server ticks); it decides every
	  TickSeconds like the Brood Mother.
	* The Crystal Colossus (Prompt 24; Section 10: "Tears out of the crystal rock. Huge, slow and
	  armored; flares show its weak points; its shards stun."; Tuning.CrystalColossus). It strides
	  out of the rock behind its arena's back wall and walks its arena like the Brood Mother, slower.
	  Every hit does its ArmourMultiplier until its cores are Lit: a flare, a lamp or the Scout's
	  Flare Ping within reach (parts tagged RevealLight; MonsterService:Lit), or its own charge for
	  FlashSeconds as it throws its shards. Lit, its cores (the model's WeakPoint parts) glow and a
	  hit on one is a weak-point hit. It slams like the Brood Mother (its Slam socket). Every
	  VolleySeconds it throws Shards crystal shards: each has a mark on the floor (a ShardMark part
	  in workspace.Monsters with Radius and LandsAt, which clients draw) and lands ShardWarnSeconds
	  later for ShardDamage and a stun (players: the StunnedUntil attribute, which stops their
	  movement and their hands; residents are slowed); from its second phase Shardlings crawl out
	  of the first Shardlings of them.

	Replication: the Boss collection, "Fight" -> { Id, Name, Health, Max, Phase, Phases, State,
	At = { X, Y, Z } (where it breaks in; The Deluge: where it is), ArriveAt (server time), Sacs,
	Mode (The Deluge: Up, Diving, Swim, Surfacing), Lit (the Crystal Colossus: its cores show) }
	while a fight is on.
	The model is in workspace.Monsters with Rig, Activity and AttackAt attributes. Unlike other
	monsters (Section 23: clips play on clients), her clips play here on the server and replicate
	(ServerAnimated, which NPCAnimator skips): one model, and the server must see her belly where
	players see it when it judges a hit.

	API:
		BossService:BeginFight(bossId): (boolean, string?) -- a fight now (CycleClock's boss Surge; DevTools)
		BossService:Active(): string?
		BossService:Stun(combatId, why): boolean       -- Prompt 20: crits and explosions of the class levels
		BossService:IsBoss(combatId): boolean           -- the boss itself, not an egg sac
		BossService:IsEggSac(combatId): boolean         -- one of its egg sacs (a broken sac isn't a kill)
		BossService.Started: Signal<string>             -- bossId
		BossService.Defeated: Signal<string, Player?>   -- bossId, who struck the last blow
	Dev: boss, boss.start, boss.hurt, boss.lay, boss.freeze, boss.end, boss.dive, boss.surface,
	boss.volley, boss.light.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Boss = require(Shared.Rules.Boss)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("BossService")

local BossService = {
	Name = "BossService",
	Dependencies = {
		"CycleClock", "RunDirector", "BunkerGrid", "SessionService", "CombatService", "MonsterService", "WeaponService",
		"ObjectiveService", "ThreatDirector", "DisasterService", "ReplicationService", "DevService",
	},
	Started = Signal.new() :: Signal.Signal<string>,
	Defeated = Signal.new() :: Signal.Signal<string, Player?>,
}

local RISE_DEPTH = 13 -- how far under the floor she starts
local DELUGE_RISE_DEPTH = 15 -- The Deluge stands 14.5 studs to the tips of its hood
local HATCH_TAG_PREFIX = "Boss:"

-- How each boss's arrival and glow look, and the words for it. Water: its bursts are water, not rock.
local LOOK: { [string]: {
	Glow: Color3, GlowAt: Vector3, GlowRange: number, GlowBrightness: number, -- its own light, about its pivot
	Dust: Color3, Chips: Color3, Water: boolean, Clips: { string }, Up: string, Phase: string,
} } = {
	BroodMother = {
		Glow = Color3.fromRGB(124, 255, 155), GlowAt = Vector3.new(0, 10, 2), GlowRange = 24, GlowBrightness = 1.2,
		Dust = Color3.fromRGB(140, 128, 112), Chips = Color3.fromRGB(70, 64, 58), Water = false,
		Clips = { "Idle", "Walk", "Attack", "LayEggs", "Stagger", "Death" },
		Up = "BREAKS THROUGH! HIT HER GLOWING BELLY, BREAK HER EGG SACS",
		Phase = "SHRIEKS: SHE LAYS FASTER AND HITS HARDER",
	},
	Deluge = {
		-- in front of its face and low, so the players it looks down at see what is looking
		Glow = Color3.fromRGB(150, 232, 226), GlowAt = Vector3.new(0, 7, -10), GlowRange = 40, GlowBrightness = 2.6,
		Dust = Color3.fromRGB(150, 196, 204), Chips = Color3.fromRGB(196, 232, 238), Water = true,
		Clips = { "Idle", "Swim", "Attack", "Stagger", "Death" },
		Up = "SURFACES! STRIKE ITS HEAD WHEN IT IS UP, PATCH THE PIPES IT BURSTS",
		Phase = "ROARS: IT SWIMS FASTER AND BRINGS MORE WITH IT",
	},
	CrystalColossus = {
		Glow = Color3.fromRGB(143, 227, 224), GlowAt = Vector3.new(0, 8, -6), GlowRange = 34, GlowBrightness = 1.8,
		Dust = Color3.fromRGB(150, 132, 160), Chips = Color3.fromRGB(176, 238, 234), Water = false,
		Clips = { "Idle", "Walk", "Attack", "Volley", "Stagger", "Death" },
		Up = "TEARS OUT OF THE ROCK! LIGHT IT WITH A FLARE, THEN HIT ITS GLOWING CORES",
		Phase = "CRACKS: MORE SHARDS, AND SHARDLINGS CRAWL OUT OF THEM",
	},
}

-- Where a boss starts from as it arrives, from where it will stand: under the floor, or (the
-- Crystal Colossus: "Tears out of the crystal rock") inside the rock behind its cell's back wall.
local EMERGE: { [string]: Vector3 } = {
	BroodMother = Vector3.new(0, -RISE_DEPTH, 0),
	Deluge = Vector3.new(0, -DELUGE_RISE_DEPTH, 0),
	CrystalColossus = Vector3.new(0, 0, -22),
}

type Sac = { CombatId: string, Model: Model, HatchAt: number }
type Fight = {
	BossId: string,
	Name: string,
	T: { [string]: any },
	Arena: Boss.Arena,
	Left: number,
	Right: number,
	X: number,
	Y: number,
	Z: number,
	Yaw: number,
	Model: Model?,
	Root: BasePart?,
	CombatId: string?,
	Max: number,
	Phase: number,
	State: string, -- "Warning" | "Rising" | "Fighting" | "Dying"
	ArriveAt: number,
	Busy: number,
	NextAttack: number,
	NextLay: number,
	Sacs: { [string]: Sac },
	Hits: { { At: number, Amount: number } },
	LastHitBy: string?,
	PublishedAt: number,
	Sent: string,
	Effects: { Instance },
	Tracks: { [string]: AnimationTrack },
	Playing: AnimationTrack?,
	-- The Deluge
	Mode: string, -- "" | "Up" | "Diving" | "Swim" | "Surfacing"
	ModeUntil: number,
	SwimFrom: number,
	Sink: number, -- studs under the floor
	Floor: number,
	Column: number,
	Path: { { number } },
	PathIndex: number,
	Passed: { [string]: boolean }, -- rooms flooded on this swim
	Face: Vector3?,
	AloneSince: number?,
	Roar: boolean, -- a phase began under water: it roars as it comes up
	Wake: Part?,
	-- The Crystal Colossus
	Lit: boolean, -- its cores show (a flare, a lamp, its own charge)
	LitUntil: number, -- shown until then whatever the light (os.clock)
	NextVolley: number,
	WantX: number,
	Moving: boolean,
}

local clock: any = nil
local director: any = nil
local grid: any = nil
local session: any = nil
local combat: any = nil
local monsters: any = nil
local weapons: any = nil
local objectives: any = nil
local threat: any = nil
local disasters: any = nil
local collection: any = nil
local rng = Random.new()

local fight: Fight? = nil
local sacIds: { [string]: boolean } = {} -- every egg sac's combatant id this run (ids aren't reused)

-- Helpers --------------------------------------------------------------------------------------------

local function now(): number
	return workspace:GetServerTimeNow()
end

local function announce(kind: string, text: string)
	Remotes.FireClients("Alert", session:ReadyPlayers(), kind, text)
end

local function holder(): Instance
	local f = workspace:FindFirstChild("Monsters")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Monsters"
		f.Parent = workspace
	end
	return f :: Instance
end

local function art(asset: string): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local bosses = assets and assets:FindFirstChild("Bosses")
	local found = bosses and bosses:FindFirstChild(asset)
	return if found and found:IsA("Model") then found else nil
end

local function socket(model: Model, name: string): CFrame
	local value = model:GetAttribute(`Socket_{name}`)
	return model:GetPivot() * (if typeof(value) == "CFrame" then value else CFrame.identity)
end

-- Her clips, played here (see the header); Config.Animations' clips for her Rig.
local function track(f: Fight, activity: string): AnimationTrack?
	local cached = f.Tracks[activity]
	if cached then
		return cached
	end
	local model = f.Model
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	for _, clip in Config.All("Animations") do
		if clip.Rig == f.BossId and clip.Activity == activity then
			local animation = Instance.new("Animation")
			animation.AnimationId = clip.AssetId
			local ok, loaded = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok and loaded then
				loaded.Looped = clip.Looped
				f.Tracks[activity] = loaded
				return loaded
			end
			log:Warn("couldn't load her %s clip: %s", activity, tostring(loaded))
		end
	end
	return nil
end

local function play(f: Fight, activity: string, restart: boolean?)
	local wanted = track(f, activity)
	if f.Playing and f.Playing ~= wanted then
		f.Playing:Stop(0.2)
		f.Playing = nil
	end
	if wanted and (restart or not wanted.IsPlaying) then
		wanted:Play(0.15)
		f.Playing = wanted
	end
end

local function setActivity(activity: string, restart: boolean?)
	local f = fight
	if not f or not f.Model then
		return
	end
	if f.Model:GetAttribute("Activity") ~= activity or restart then
		f.Model:SetAttribute("Activity", activity)
		play(f, activity, restart)
	end
end

local function pivot(f: Fight): CFrame
	return CFrame.new(f.X, f.Y - f.Sink, f.Z) * CFrame.Angles(0, f.Yaw, 0)
end

local function look(f: Fight)
	return LOOK[f.BossId] or LOOK.BroodMother
end

local function where(arena: Boss.Arena): string
	return `FLOOR {arena.Floor} · COLUMN {Boss.ArenaMiddle(arena)}`
end

local function publish(force: boolean?)
	local f = fight
	if not f then
		collection:Remove("Fight")
		return
	end
	local health = 0
	if f.CombatId then
		health = (combat:HealthOf(f.CombatId))
	elseif f.State == "Warning" or f.State == "Rising" then
		health = f.Max
	end
	local count = 0
	for _ in f.Sacs do
		count += 1
	end
	local sent = `{math.ceil(health)}|{f.Phase}|{f.State}|{count}|{f.Mode}|{f.Floor}|{f.Column}|{f.Lit}`
	if not force and (sent == f.Sent or os.clock() - f.PublishedAt < Boss.Tuning().PublishSeconds) then
		return
	end
	f.Sent = sent
	f.PublishedAt = os.clock()
	local at = Grid.CellPosition(f.Arena.Floor, Boss.ArenaMiddle(f.Arena))
	collection:Set("Fight", {
		Id = f.BossId,
		Name = f.Name,
		Health = math.ceil(health),
		Max = f.Max,
		Phase = f.Phase,
		Phases = Config.Get("Bosses", f.BossId).Phases,
		State = f.State,
		At = { X = f.X, Y = if f.Mode ~= "" then f.Y else at.Y, Z = f.Z },
		ArriveAt = f.ArriveAt,
		Sacs = count,
		Mode = if f.Mode ~= "" then f.Mode else nil,
		Lit = if f.BossId == "CrystalColossus" then f.Lit else nil,
	})
end

-- Effects ---------------------------------------------------------------------------------------------

local function effectPart(at: Vector3, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(14, 1, 14)
	part.CFrame = CFrame.new(at)
	part.Parent = holder()
	return part
end

local function rockBurst(at: Vector3, chips: number, f: Fight?)
	local colours = if f then LOOK[f.BossId] or LOOK.BroodMother else LOOK.BroodMother
	local part = effectPart(at + Vector3.new(0, 0.5, 0), "BossBurst")
	part:SetAttribute("Water", colours.Water)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(colours.Dust)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.5, 3)
	dust.Speed = NumberRange.new(8, 18)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Acceleration = Vector3.new(0, -4, 0)
	dust.Rate = 0
	dust.Parent = part
	local rocks = Instance.new("ParticleEmitter")
	rocks.Color = ColorSequence.new(colours.Chips)
	rocks.Size = NumberSequence.new(if colours.Water then 0.35 else 0.6)
	rocks.Lifetime = NumberRange.new(1, 1.6)
	rocks.Speed = NumberRange.new(20, 34)
	rocks.SpreadAngle = Vector2.new(45, 45)
	rocks.Acceleration = Vector3.new(0, -60, 0)
	rocks.Rate = 0
	rocks.Parent = part
	dust:Emit(60)
	rocks:Emit(chips)
	task.delay(4, function()
		part:Destroy()
	end)
end

-- Cracks, dust and a blinking red light where she will break in (like a breach's warning).
local function warning(f: Fight, seconds: number)
	local at = Vector3.new(f.X, f.Y + 0.2, f.Z)
	local part = effectPart(at, "BossWarning")
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(look(f).Dust)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.4)
	dust.Speed = NumberRange.new(1, 4)
	dust.SpreadAngle = Vector2.new(90, 90)
	dust.Rate = 18
	dust.Parent = part
	local light = Instance.new("PointLight")
	light.Color = if look(f).Water then Color3.fromRGB(70, 150, 232) else Color3.fromRGB(232, 80, 59)
	light.Range = 26
	light.Brightness = 2
	light.Parent = part
	table.insert(f.Effects, part)
	task.spawn(function()
		local endsAt = os.clock() + seconds
		while os.clock() < endsAt and part.Parent do
			dust.Rate = 18 + 40 * (1 - (endsAt - os.clock()) / seconds)
			light.Brightness = if light.Brightness > 1 then 0.4 else 3
			task.wait(0.4)
		end
		part:Destroy()
	end)
end

-- The fight's model ---------------------------------------------------------------------------------

local function graybox(bossId: string): Model
	local model = Instance.new("Model")
	model.Name = bossId
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(5, 4, 7)
	root.Transparency = 1
	root.Anchored = true
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(16, 8, 18)
	body.Color = Color3.fromHex("#403B37")
	body.CFrame = CFrame.new(0, 5, 0)
	body.CanCollide = false
	body.Parent = model
	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Size = Vector3.new(6, 3, 8)
	belly.Color = Color3.fromHex("#7CFF9B")
	belly.Material = Enum.Material.Neon
	belly.CFrame = CFrame.new(0, 2.5, 5)
	belly.CanCollide = false
	belly:SetAttribute("Role", "WeakPoint")
	belly.Parent = model
	root.CFrame = CFrame.new(0, 4.95, 0)
	for _, part in { body, belly } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = root
	root.PivotOffset = CFrame.new(0, -4.95, 0)
	model:SetAttribute("Graybox", true)
	return model
end

-- The Deluge before its art: a neck standing out of the floor, a head (its weak point), a back fin.
local function grayboxEel(bossId: string): Model
	local model = Instance.new("Model")
	model.Name = bossId
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(5, 4, 5)
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new(0, 4, 0)
	root.Parent = model
	local function block(name: string, size: Vector3, at: Vector3, colour: string, weak: boolean)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = Color3.fromHex(colour)
		part.Material = if weak then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(at)
		part.CanCollide = false
		if weak then
			part:SetAttribute("Role", "WeakPoint")
		end
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	block("Neck", Vector3.new(5, 12, 5), Vector3.new(0, 4, 0), "#2F4A52", false)
	block("Head", Vector3.new(5, 4, 8), Vector3.new(0, 11, -2), "#58D6E8", true)
	block("Fin", Vector3.new(0.6, 5, 14), Vector3.new(0, 11.5, 8), "#3B6A72", false)
	block("Back", Vector3.new(5, 5, 16), Vector3.new(0, 6.5, 9), "#2F4A52", false)
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	model.PrimaryPart = root
	root.PivotOffset = CFrame.new(0, -4, 0)
	model:SetAttribute("Graybox", true)
	return model
end

local function makeModel(f: Fight): (Model, BasePart)
	local entry = Config.Get("Bosses", f.BossId)
	local template = art(entry.Asset)
	local model = if template then template:Clone() elseif f.BossId == "Deluge" then grayboxEel(f.BossId) else graybox(f.BossId)
	model.Name = f.BossId
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
			part.Anchored = part == root
		end
	end
	-- Her invisible root box mustn't catch shots meant for her belly (a part that collides is
	-- always queryable, so it stops colliding too: players can step under her).
	root.CanCollide = false
	root.CanQuery = false
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.MaxHealth = math.huge -- CombatService keeps her health; the Humanoid only animates
		humanoid.Health = math.huge
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid.PlatformStand = true
	end
	-- Her glow lights the tunnel around her, so her body reads in the dark (the art has no lights).
	local glowAt = Instance.new("Attachment")
	glowAt.Name = "BossGlow"
	glowAt.Position = root.CFrame:PointToObjectSpace(model:GetPivot() * look(f).GlowAt)
	glowAt.Parent = root
	local glow = Instance.new("PointLight")
	glow.Color = look(f).Glow
	glow.Range = look(f).GlowRange
	glow.Brightness = look(f).GlowBrightness
	glow.Shadows = false
	glow.Parent = glowAt
	model:SetAttribute("Rig", f.BossId)
	model:SetAttribute("MonsterType", f.BossId)
	model:SetAttribute("Boss", f.BossId)
	model:SetAttribute("Activity", "Roar")
	model:SetAttribute("ServerAnimated", true) -- NPCAnimator leaves her to the server
	return model, root
end

local function weakParts(model: Model): { BasePart }
	local list = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Role") == "WeakPoint" then
			table.insert(list, part)
		end
	end
	return list
end

-- Egg sacs ---------------------------------------------------------------------------------------------

local function removeSac(f: Fight, id: string, how: string)
	local sac = f.Sacs[id]
	if not sac then
		return
	end
	f.Sacs[id] = nil
	if how ~= "Broken" then -- a broken sac is dissolved by CombatService
		combat:Unregister(sac.CombatId)
		if sac.Model.Parent then
			combat:Dissolve(sac.Model)
		end
	end
	publish(true)
end

local function sacModel(): Model
	local template = art("Boss_BroodMother_EggSac")
	if template then
		return template:Clone()
	end
	local model = Instance.new("Model")
	model.Name = "EggSac"
	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Size = Vector3.new(3.6, 1, 3.2)
	mound.Color = Color3.fromHex("#6E4766")
	mound.Parent = model
	local eggs = Instance.new("Part")
	eggs.Name = "Eggs"
	eggs.Shape = Enum.PartType.Ball
	eggs.Size = Vector3.new(2.4, 2.4, 2.4)
	eggs.Material = Enum.Material.Neon
	eggs.Color = Color3.fromHex("#7CFF9B")
	eggs.CFrame = CFrame.new(0, 1.2, 0)
	eggs.Parent = model
	model.PrimaryPart = mound
	mound.CFrame = CFrame.new(0, 0.5, 0)
	model.WorldPivot = CFrame.identity
	return model
end

local function laySac(f: Fight, at: Vector3)
	local model = sacModel()
	local x = math.clamp(at.X, f.Left - f.T.ArenaMargin + 3, f.Right + f.T.ArenaMargin - 3)
	local z = math.clamp(at.Z, f.Z - 11, f.Z + 11)
	model:PivotTo(CFrame.new(x, f.Y, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	local root: BasePart? = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanTouch = false
			if part.Name == "Mound" or (not root and part.CanQuery) then
				root = part
			end
		end
	end
	model.Name = "EggSac"
	model:SetAttribute("Boss", f.BossId)
	model.Parent = holder()
	local id = combat:Register(model, {
		Kind = "Monster", Team = "Monsters", Health = f.T.SacHealth, MonsterType = "EggSac", Root = root,
	})
	if not id then
		model:Destroy()
		return
	end
	model.Name = `EggSac_{id}`
	sacIds[id] = true
	f.Sacs[id] = { CombatId = id, Model = model, HatchAt = os.clock() + f.T.HatchSeconds }
	rockBurst(Vector3.new(x, f.Y, z), 6)
end

local function hatch(f: Fight, id: string)
	local sac = f.Sacs[id]
	if not sac then
		return
	end
	local entry = Config.Get("Bosses", f.BossId)
	local kind = if entry.Minions then entry.Minions[1] else "BurrowTick"
	local hatches = sac.Model:GetAttribute("Hatches")
	if type(hatches) == "string" and Config.Find("Monsters", hatches) then
		kind = hatches
	end
	local base = sac.Model:GetPivot()
	for i = 1, f.T.HatchCount do
		local angle = (i / f.T.HatchCount) * math.pi * 2
		local spot = base * CFrame.new(math.cos(angle) * 2, 0.5, math.sin(angle) * 2)
		monsters:Spawn(kind, CFrame.new(spot.Position), HATCH_TAG_PREFIX .. f.BossId)
	end
	removeSac(f, id, "Hatched")
	log:Info("an egg sac hatched %d %s", f.T.HatchCount, kind)
end

-- The fight -----------------------------------------------------------------------------------------------

local function nearestPlayer(f: Fight): (Player?, Vector3?)
	local best, bestPosition, bestScore = nil, nil, math.huge
	for _, player in session:ReadyPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("Life") == "Alive" then
			local position = root.Position
			local floor = Grid.CellAt(position)
			-- players on her floor first (she can reach them), then anyone
			local score = (position - Vector3.new(f.X, f.Y, f.Z)).Magnitude + (if floor == f.Arena.Floor then 0 else 1000)
			if score < bestScore then
				best, bestPosition, bestScore = player, position, score
			end
		end
	end
	return best, bestPosition
end

local function turnTowards(f: Fight, target: Vector3, dt: number)
	local flat = Vector3.new(target.X - f.X, 0, target.Z - f.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	-- her front is -Z: the yaw that looks along flat
	local want = math.atan2(-flat.X, -flat.Z)
	local delta = (want - f.Yaw + math.pi) % (math.pi * 2) - math.pi
	local step = math.rad(f.T.TurnDegreesPerSecond) * dt
	f.Yaw += math.clamp(delta, -step, step)
end

local function slamPoint(f: Fight): Vector3
	local model = f.Model
	if model and model:GetAttribute("Socket_Slam") == nil then
		return (pivot(f) * CFrame.new(0, 0, -f.T.SlamReach * 0.55)).Position -- no socket: in front of it
	end
	return if model then socket(model, "Slam").Position else Vector3.new(f.X, f.Y, f.Z)
end

local function attack(f: Fight)
	local model = f.Model :: Model
	local hitTime = (model:GetAttribute("HitTime") :: number?) or 0.8
	setActivity("Attack", true)
	model:SetAttribute("AttackAt", now())
	f.Busy = os.clock() + hitTime + 0.8
	f.NextAttack = os.clock() + Boss.ByPhase(f.T.AttackSeconds, f.Phase)
	task.delay(hitTime, function()
		if fight ~= f or f.State ~= "Fighting" or not f.CombatId then
			return
		end
		local at = slamPoint(f)
		local hit = 0
		for _, c in combat:All("Survivors") do
			local offset = c.Root.Position - at
			if c.State == "Alive" and Vector3.new(offset.X, 0, offset.Z).Magnitude <= f.T.SlamRadius and math.abs(offset.Y) < 9 then
				if combat:Damage(c.Id, f.T.SlamDamage, f.CombatId, "slammed") > 0 then
					hit += 1
				end
			end
		end
		rockBurst(at, 10)
		if hit > 0 then
			log:Debug("slam hit %d", hit)
		end
	end)
end

local function lay(f: Fight)
	local model = f.Model :: Model
	local layTime = (model:GetAttribute("LayTime") :: number?) or 1.4
	setActivity("LayEggs")
	f.Busy = os.clock() + layTime + 0.8
	f.NextLay = os.clock() + Boss.ByPhase(f.T.LaySeconds, f.Phase)
	task.delay(layTime, function()
		if fight ~= f or f.State ~= "Fighting" or not f.Model then
			return
		end
		local at = socket(f.Model, "Ovipositor").Position
		local count = 0
		for _ in f.Sacs do
			count += 1
		end
		for i = 1, Boss.ByPhase(f.T.SacsPerLay, f.Phase) do
			if count >= f.T.MaxSacs then
				break
			end
			local spread = if i == 1 then Vector3.zero else Vector3.new((i % 2 == 0 and 1 or -1) * 4, 0, 2)
			laySac(f, at + spread)
			count += 1
		end
		log:Info("%s laid eggs (%d sacs now)", f.Name, count)
	end)
end

local function stagger(f: Fight)
	setActivity("Stagger")
	f.Busy = os.clock() + f.T.StaggerSeconds
	f.NextAttack = math.max(f.NextAttack, f.Busy + 0.5)
	if f.Mode == "Up" then
		f.ModeUntil += f.T.StaggerSeconds -- it stays up that much longer
	end
	table.clear(f.Hits)
	if f.Model then
		f.Model:SetAttribute("StaggeredAt", now())
	end
	log:Info("%s staggered", f.Name)
end

local function tickBroodMother(f: Fight, dt: number)
	if not f.Model or not f.CombatId then
		return
	end
	local health, max = combat:HealthOf(f.CombatId)
	local phase = Boss.Phase(f.BossId, if max > 0 then health / max else 0)
	if phase > f.Phase then
		f.Phase = phase
		setActivity("Roar")
		f.Busy = os.clock() + f.T.RoarSeconds
		f.NextLay = math.min(f.NextLay, os.clock() + f.T.RoarSeconds + 1)
		announce("Danger", `{Boss.Title(f.Name)} {look(f).Phase}`)
		log:Info("%s phase %d", f.Name, phase)
	end
	for id, sac in table.clone(f.Sacs) do
		if os.clock() >= sac.HatchAt then
			hatch(f, id)
		end
	end
	publish()
	if os.clock() < f.Busy then
		return
	end
	local target, position = nearestPlayer(f)
	if not target or not position then
		setActivity("Idle")
		return
	end
	turnTowards(f, position, dt)
	local count = 0
	for _ in f.Sacs do
		count += 1
	end
	if os.clock() >= f.NextLay and count < f.T.MaxSacs then
		f.Model:PivotTo(pivot(f))
		lay(f)
		return
	end
	local flat = Vector3.new(position.X - f.X, 0, position.Z - f.Z)
	if flat.Magnitude <= f.T.SlamReach and os.clock() >= f.NextAttack then
		local facing = (pivot(f)).LookVector
		if flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit) > 0.7 then
			f.Model:PivotTo(pivot(f))
			attack(f)
			return
		end
	end
	local wantX = math.clamp(position.X, f.Left, f.Right)
	local gap = wantX - f.X
	if math.abs(gap) > 1 and flat.Magnitude > f.T.SlamReach * 0.6 then
		local speed = Boss.ByPhase(f.T.MoveSpeed, f.Phase)
		f.X += math.clamp(gap, -speed * dt, speed * dt)
		setActivity("Walk")
	else
		setActivity("Idle")
	end
	f.Model:PivotTo(pivot(f))
end

-- The Deluge ------------------------------------------------------------------------------------------------

local function wakeRate(f: Fight, rate: number)
	local wake = f.Wake
	local emitter = wake and wake:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Rate = rate
	end
	local light = wake and wake:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = rate > 0
	end
end

-- The spray and the light where its crest cuts the floor: what players follow while it is under.
local function makeWake(f: Fight)
	local part = effectPart(Vector3.new(f.X, f.Y + 0.4, f.Z), "DelugeWake")
	part.Size = Vector3.new(6, 0.4, 6)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(look(f).Chips)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.6) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(0.6, 1.2)
	spray.Speed = NumberRange.new(8, 16)
	spray.SpreadAngle = Vector2.new(40, 40)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.LightEmission = 0.4
	spray.Rate = 0
	spray.Parent = part
	local light = Instance.new("PointLight")
	light.Color = look(f).Glow
	light.Range = 20
	light.Brightness = 2.2
	light.Shadows = false
	light.Enabled = false
	light.Parent = part
	f.Wake = part
	table.insert(f.Effects, part)
end

-- Every room it passes bursts a pipe and takes water (the Shaft takes the water, with no pipe).
local function floodPassed(f: Fight)
	local room = grid:Bunker():RoomAt(f.Floor, f.Column)
	if room and not f.Passed[room.Id] then
		f.Passed[room.Id] = true
		disasters:StartFlood(room.Id, "Deluge", f.T.FloodLevel, room.Type ~= "Shaft")
	end
end

-- Where it comes up for someone in this cell: the cell itself, or the nearest open cell on that
-- floor that isn't a Shaft.
local function surfaceCell(bunker: any, floor: number, column: number): (number, number)
	if not bunker:IsShaft(floor, column) then
		return floor, column
	end
	for reach = 1, 4 do
		for _, c in { column - reach, column + reach } do
			if bunker:IsOpen(floor, c) and not bunker:IsShaft(floor, c) then
				return floor, c
			end
		end
	end
	return floor, column
end

-- The way to the nearest standing player it can reach; with nobody, to a room picked at random.
local function delugeRoute(f: Fight)
	local bunker = grid:Bunker()
	local here = Vector3.new(f.X, f.Y, f.Z)
	local wanted: { { Distance: number, Floor: number, Column: number } } = {}
	for _, player in session:ReadyPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("Life") == "Alive" then
			local floor, column = Grid.CellAt(root.Position)
			if floor and column and bunker:IsOpen(floor, column) then
				table.insert(wanted, { Distance = (root.Position - here).Magnitude, Floor = floor, Column = column })
			end
		end
	end
	table.sort(wanted, function(a, b)
		return a.Distance < b.Distance
	end)
	for _, w in wanted do
		local floor, column = surfaceCell(bunker, w.Floor, w.Column)
		local path = bunker:CellPath(f.Floor, f.Column, floor, column)
		if path then
			f.Path, f.PathIndex = path, 2
			return
		end
	end
	if f.PathIndex <= #f.Path then
		return -- nobody to hunt: it carries on where it was going
	end
	local rooms = {}
	for _, room in bunker:AllRooms() do
		if room.Type ~= "Shaft" then
			table.insert(rooms, room)
		end
	end
	if #rooms > 0 then
		local room = rooms[rng:NextInteger(1, #rooms)]
		local path = bunker:CellPath(f.Floor, f.Column, room.Floor, room.Column)
		if path then
			f.Path, f.PathIndex = path, 2
			return
		end
	end
	f.Path, f.PathIndex = {}, 1
end

local function delugeDive(f: Fight)
	f.Mode = "Diving"
	f.ModeUntil = os.clock() + f.T.DiveSeconds
	f.Face = nil
	f.AloneSince = nil
	table.clear(f.Passed)
	local room = grid:Bunker():RoomAt(f.Floor, f.Column)
	if room then
		f.Passed[room.Id] = true -- it flooded this one as it came up
	end
	setActivity("Swim")
	if f.Model then
		f.Model:SetAttribute("DivedAt", now())
	end
	publish(true)
	log:Info("%s dives at floor %d column %d", f.Name, f.Floor, f.Column)
end

local function delugeSurface(f: Fight)
	f.Mode = "Surfacing"
	f.ModeUntil = os.clock() + f.T.SurfaceRiseSeconds
	wakeRate(f, 0)
	floodPassed(f)
	local at = Vector3.new(f.X, f.Y, f.Z)
	rockBurst(at, 60, f)
	if f.Roar then
		setActivity("Roar", true)
	else
		setActivity("Idle")
	end
	if f.Model then
		f.Model:SetAttribute("SurfacedAt", now())
	end
	-- Murklings pour out with it (Config.Bosses' Minions)
	local entry = Config.Get("Bosses", f.BossId)
	local kind = if entry.Minions then entry.Minions[1] else nil
	local count = Boss.ByPhase(f.T.Murklings, f.Phase)
	if kind and count > 0 then
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local spot = at + Vector3.new(math.cos(angle) * 7, 0.5, math.sin(angle) * 7)
			monsters:Spawn(kind, CFrame.new(spot), HATCH_TAG_PREFIX .. f.BossId)
		end
	end
	publish(true)
	log:Info("%s surfaces at floor %d column %d (%d %s with it)", f.Name, f.Floor, f.Column, count, tostring(kind))
end

-- Its bite: whoever is within BiteRadius of where its jaws come down.
local function bite(f: Fight)
	local model = f.Model :: Model
	local hitTime = (model:GetAttribute("HitTime") :: number?) or 0.7
	setActivity("Attack", true)
	model:SetAttribute("AttackAt", now())
	f.Busy = os.clock() + hitTime + 0.8
	f.NextAttack = os.clock() + Boss.ByPhase(f.T.AttackSeconds, f.Phase)
	task.delay(hitTime, function()
		if fight ~= f or f.State ~= "Fighting" or f.Mode ~= "Up" or not f.CombatId or not f.Model then
			return
		end
		local at = if f.Model:GetAttribute("Socket_Bite") ~= nil
			then socket(f.Model, "Bite").Position
			else (pivot(f) * CFrame.new(0, 1, -f.T.BiteReach * 0.7)).Position
		local hit = 0
		for _, c in combat:All("Survivors") do
			local offset = c.Root.Position - at
			if c.State == "Alive" and Vector3.new(offset.X, 0, offset.Z).Magnitude <= f.T.BiteRadius and math.abs(offset.Y) < 9 then
				if combat:Damage(c.Id, f.T.BiteDamage, f.CombatId, "bitten") > 0 then
					hit += 1
				end
			end
		end
		rockBurst(at, 14, f)
		if hit > 0 then
			log:Debug("bite hit %d", hit)
		end
	end)
end

-- The nearest standing survivor (players and residents) on its floor, and how far.
local function nearestSurvivor(f: Fight): (Vector3?, number)
	local best, bestDistance = nil, math.huge
	for _, c in combat:All("Survivors") do
		if c.State == "Alive" then
			local offset = c.Root.Position - Vector3.new(f.X, f.Y, f.Z)
			local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if math.abs(offset.Y) < 9 and flat < bestDistance then
				best, bestDistance = c.Root.Position, flat
			end
		end
	end
	return best, bestDistance
end

-- Its decisions, every TickSeconds.
local function tickDeluge(f: Fight, _dt: number)
	if not f.Model or not f.CombatId then
		return
	end
	local at0 = os.clock()
	local health, max = combat:HealthOf(f.CombatId)
	local phase = Boss.Phase(f.BossId, if max > 0 then health / max else 0)
	if phase > f.Phase then
		f.Phase = phase
		announce("Danger", `{Boss.Title(f.Name)} {look(f).Phase}`)
		log:Info("%s phase %d", f.Name, phase)
		if f.Mode == "Up" then
			setActivity("Roar", true)
			f.Busy = at0 + f.T.RoarSeconds
			f.ModeUntil += f.T.RoarSeconds
		else
			f.Roar = true
		end
	end
	publish()
	if f.Mode ~= "Up" or at0 < f.Busy then
		return
	end
	if at0 >= f.ModeUntil then
		delugeDive(f)
		return
	end
	local position, distance = nearestSurvivor(f)
	f.Face = position
	if not position or distance > f.T.BiteReach * 2 then
		-- nobody near: it doesn't wait about
		f.AloneSince = f.AloneSince or at0
		if at0 - f.AloneSince >= f.T.AloneSeconds then
			delugeDive(f)
			return
		end
	else
		f.AloneSince = nil
	end
	if position and distance <= f.T.BiteReach and at0 >= f.NextAttack then
		local flat = Vector3.new(position.X - f.X, 0, position.Z - f.Z)
		local facing = pivot(f).LookVector
		if flat.Magnitude < 1 or flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit) > 0.75 then
			bite(f)
			return
		end
	end
	setActivity("Idle")
end

-- Its movement, every frame.
local function frameDeluge(f: Fight, dt: number)
	local model = f.Model
	if not model or f.State ~= "Fighting" or f.Mode == "" then
		return
	end
	local t = f.T
	local at0 = os.clock()
	if f.Mode == "Up" then
		if f.Face and at0 >= f.Busy then
			local before = f.Yaw
			turnTowards(f, f.Face, dt)
			if f.Yaw ~= before then
				model:PivotTo(pivot(f))
			end
		end
		return
	end
	if f.Mode == "Diving" then
		f.Sink = math.min(t.SwimDepth, f.Sink + t.SwimDepth / t.DiveSeconds * dt)
		if f.Sink >= t.SwimDepth then
			f.Mode = "Swim"
			f.SwimFrom = at0
			f.ModeUntil = at0 + Boss.ByPhase(t.SwimSeconds, f.Phase)
			delugeRoute(f)
			wakeRate(f, 60)
			publish(true)
		end
	elseif f.Mode == "Swim" then
		local remaining = Boss.ByPhase(t.SwimSpeed, f.Phase) * dt
		local bunker = grid:Bunker()
		while remaining > 0 and f.Mode == "Swim" do
			local cell = f.Path[f.PathIndex]
			local late = at0 >= f.ModeUntil
			if not cell then
				-- there: up it comes (after a breath under, so a dive is never a blink), or on to the next
				if at0 - f.SwimFrom >= 2 or late then
					delugeSurface(f)
				end
				break
			end
			local goal = Grid.CellPosition(cell[1], cell[2])
			local offset = goal - Vector3.new(f.X, f.Y, f.Z)
			local distance = offset.Magnitude
			if math.abs(offset.X) > 0.05 then
				-- its front is -Z
				local want = math.atan2(-offset.X, -offset.Z)
				local delta = (want - f.Yaw + math.pi) % (math.pi * 2) - math.pi
				local step = math.rad(360) * dt
				f.Yaw += math.clamp(delta, -step, step)
			end
			if distance <= remaining then
				f.X, f.Y, f.Z = goal.X, goal.Y, goal.Z
				f.Floor, f.Column = cell[1], cell[2]
				f.PathIndex += 1
				remaining -= distance
				floodPassed(f)
				if late and not bunker:IsShaft(f.Floor, f.Column) then
					delugeSurface(f)
				else
					delugeRoute(f) -- whoever it hunts has moved
				end
			else
				local step = offset.Unit * remaining
				f.X += step.X
				f.Y += step.Y
				f.Z += step.Z
				remaining = 0
			end
		end
	elseif f.Mode == "Surfacing" then
		f.Sink = math.max(0, f.Sink - t.SwimDepth / t.SurfaceRiseSeconds * dt)
		if f.Sink <= 0 then
			f.Mode = "Up"
			f.ModeUntil = at0 + Boss.ByPhase(t.SurfaceSeconds, f.Phase)
			f.NextAttack = at0 + 0.8
			f.AloneSince = nil
			if f.Roar then
				f.Roar = false
				f.Busy = at0 + t.RoarSeconds
				f.ModeUntil += t.RoarSeconds
			end
			publish(true)
		end
	end
	model:PivotTo(pivot(f))
	if f.Wake then
		f.Wake.CFrame = CFrame.new(f.X, f.Y + 0.4, f.Z)
	end
end

-- The Crystal Colossus (Prompt 24) ----------------------------------------------------------------------------

local CORE_DARK = Color3.fromRGB(46, 40, 52)
local CORE_LIT = Color3.fromRGB(232, 116, 59) -- Signal Orange: shoot here

-- Its cores (the model's WeakPoint parts): dark stone until a light shows them, then they glow.
local function setLit(f: Fight, lit: boolean)
	if f.Lit == lit then
		return
	end
	f.Lit = lit
	local model = f.Model
	if not model then
		return
	end
	for _, part in weakParts(model) do
		part.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
		part.Color = if lit then CORE_LIT else CORE_DARK
	end
	model:SetAttribute("Lit", if lit then true else nil)
	publish(true)
	log:Debug("%s cores %s", f.Name, if lit then "lit" else "dark")
end

-- A flare or a lamp on it (Section 10: "flares show its weak points"), or its own charge.
local function colossusLit(f: Fight): boolean
	if os.clock() < f.LitUntil then
		return true
	end
	return monsters:Lit(Vector3.new(f.X, f.Y + 6, f.Z))
end

-- A shard's mark on the floor: it lands ShardWarnSeconds later (the client draws the ring and the
-- falling shard from the mark's attributes), hurting and stunning whoever is still inside.
local function shardMark(f: Fight, at: Vector3, hatch: boolean)
	local t = f.T
	local mark = effectPart(Vector3.new(at.X, f.Y + 0.15, at.Z), "ShardMark")
	mark.Size = Vector3.new(t.ShardRadius * 2, 0.3, t.ShardRadius * 2)
	mark:SetAttribute("Radius", t.ShardRadius)
	mark:SetAttribute("LandsAt", now() + t.ShardWarnSeconds)
	table.insert(f.Effects, mark)
	task.delay(t.ShardWarnSeconds, function()
		if fight ~= f or not mark.Parent then
			mark:Destroy()
			return
		end
		local centre = mark.Position
		local hit = 0
		for _, c in combat:All("Survivors") do
			local offset = c.Root.Position - centre
			if c.State == "Alive" and Vector3.new(offset.X, 0, offset.Z).Magnitude <= t.ShardRadius + c.Reach and math.abs(offset.Y) < 9 then
				if f.CombatId and combat:Damage(c.Id, t.ShardDamage, f.CombatId, "shard") > 0 then
					hit += 1
					-- "its shards stun"
					if c.Kind == "Player" and c.Player then
						c.Player:SetAttribute("StunnedUntil", now() + t.StunSeconds)
					elseif c.Model then
						c.Model:SetAttribute("SlowedUntil", now() + t.StunSeconds)
					end
				end
			end
		end
		rockBurst(centre, 16, f)
		mark:SetAttribute("Landed", true)
		task.delay(0.6, function()
			mark:Destroy()
		end)
		if hatch and f.State == "Fighting" then
			local entry = Config.Get("Bosses", f.BossId)
			local kind = if entry.Minions then entry.Minions[1] else nil
			if kind then
				monsters:Spawn(kind, CFrame.new(centre + Vector3.new(0, 0.5, 0)), HATCH_TAG_PREFIX .. f.BossId)
			end
		end
		if hit > 0 then
			log:Debug("a shard hit %d", hit)
		end
	end)
end

-- It plants itself and throws its shards at whoever it can see on its floor: players first.
local function volley(f: Fight)
	local model = f.Model :: Model
	local t = f.T
	local throwTime = (model:GetAttribute("VolleyTime") :: number?) or 0.9
	setActivity("Volley", true)
	model:SetAttribute("VolleyAt", now())
	f.Moving = false
	f.Busy = os.clock() + throwTime + 1
	f.NextVolley = os.clock() + Boss.ByPhase(t.VolleySeconds, f.Phase)
	f.NextAttack = math.max(f.NextAttack, f.Busy + 0.5)
	f.LitUntil = math.max(f.LitUntil, os.clock() + throwTime + t.FlashSeconds) -- its charge shows its cores
	task.delay(throwTime, function()
		if fight ~= f or f.State ~= "Fighting" then
			return
		end
		local here = Vector3.new(f.X, f.Y, f.Z)
		local players, others = {}, {}
		for _, c in combat:All("Survivors") do
			local offset = c.Root.Position - here
			if c.State == "Alive" and math.abs(offset.Y) < 9 and Vector3.new(offset.X, 0, offset.Z).Magnitude <= t.VolleyRange then
				table.insert(if c.Kind == "Player" then players else others, c)
			end
		end
		local targets = {}
		for _, list in { players, others } do
			while #list > 0 do
				table.insert(targets, table.remove(list, rng:NextInteger(1, #list)))
			end
		end
		local count = Boss.ByPhase(t.Shards, f.Phase)
		local hatches = Boss.ByPhase(t.Shardlings, f.Phase)
		for i = 1, count do
			local c = targets[(i - 1) % math.max(#targets, 1) + 1]
			local at: Vector3
			if c then
				-- the first shard at each target lands on them; the rest fall around them
				local spread = if i <= #targets then 0 else t.ShardRadius * 1.4
				local angle = rng:NextNumber() * math.pi * 2
				at = c.Root.Position + Vector3.new(math.cos(angle) * spread, 0, math.sin(angle) * spread)
			else
				at = here + Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(2, 12))
			end
			-- shards land inside its arena's floor
			at = Vector3.new(math.clamp(at.X, f.Left - t.ArenaMargin + 2, f.Right + t.ArenaMargin - 2), f.Y,
				math.clamp(at.Z, f.Z - 12, f.Z + 15))
			shardMark(f, at, i <= hatches)
		end
		log:Info("%s threw %d shards (%d will hatch)", f.Name, count, math.min(hatches, count))
	end)
end

-- Its decisions, every TickSeconds.
local function tickColossus(f: Fight, _dt: number)
	if not f.Model or not f.CombatId then
		return
	end
	local at0 = os.clock()
	local health, max = combat:HealthOf(f.CombatId)
	local phase = Boss.Phase(f.BossId, if max > 0 then health / max else 0)
	if phase > f.Phase then
		f.Phase = phase
		f.Moving = false
		setActivity("Roar", true)
		f.Busy = at0 + f.T.RoarSeconds
		f.NextVolley = math.min(f.NextVolley, f.Busy + 1)
		announce("Danger", `{Boss.Title(f.Name)} {look(f).Phase}`)
		log:Info("%s phase %d", f.Name, phase)
	end
	setLit(f, colossusLit(f))
	publish()
	if at0 < f.Busy then
		f.Moving = false
		return
	end
	local target, position = nearestPlayer(f)
	if not target or not position then
		f.Moving = false
		f.Face = nil
		setActivity("Idle")
		return
	end
	f.Face = position
	if at0 >= f.NextVolley then
		volley(f)
		return
	end
	local flat = Vector3.new(position.X - f.X, 0, position.Z - f.Z)
	if flat.Magnitude <= f.T.SlamReach and at0 >= f.NextAttack then
		local facing = pivot(f).LookVector
		if flat.Magnitude < 1 or flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit) > 0.7 then
			f.Moving = false
			attack(f)
			return
		end
	end
	f.WantX = math.clamp(position.X, f.Left, f.Right)
	f.Moving = math.abs(f.WantX - f.X) > 1 and flat.Magnitude > f.T.SlamReach * 0.6
	setActivity(if f.Moving then "Walk" else "Idle")
end

-- Its stride and its turn, every frame.
local function frameColossus(f: Fight, dt: number)
	local model = f.Model
	if not model or f.State ~= "Fighting" or os.clock() < f.Busy then
		return
	end
	local moved = false
	if f.Face then
		local before = f.Yaw
		turnTowards(f, f.Face, dt)
		moved = f.Yaw ~= before
	end
	if f.Moving then
		local gap = f.WantX - f.X
		local speed = Boss.ByPhase(f.T.MoveSpeed, f.Phase)
		local step = math.clamp(gap, -speed * dt, speed * dt)
		if math.abs(step) > 1e-4 then
			f.X += step
			moved = true
		end
	end
	if moved then
		model:PivotTo(pivot(f))
	end
end

local function tick(dt: number)
	local f = fight
	if not f or f.State ~= "Fighting" then
		return
	end
	if f.BossId == "Deluge" then
		tickDeluge(f, dt)
	elseif f.BossId == "CrystalColossus" then
		tickColossus(f, dt)
	else
		tickBroodMother(f, dt)
	end
end

local function cleanup(f: Fight)
	for _, t in f.Tracks do
		t:Stop(0)
	end
	for id in table.clone(f.Sacs) do
		removeSac(f, id, "Gone")
	end
	for _, effect in f.Effects do
		effect:Destroy()
	end
	if f.CombatId then
		combat:Unregister(f.CombatId)
		f.CombatId = nil
	end
	if f.Model and f.Model.Parent then
		combat:Dissolve(f.Model)
	end
end

local function rise(f: Fight)
	if fight ~= f then
		return
	end
	local model, root = makeModel(f)
	f.Model = model
	f.Root = root
	f.State = "Rising"
	local finalPivot = pivot(f)
	local from = EMERGE[f.BossId] or EMERGE.BroodMother
	model:PivotTo(finalPivot + from)
	model.Parent = holder()
	local id = combat:Register(model, {
		Kind = "Monster", Team = "Monsters", Health = f.Max, MonsterType = f.BossId, Root = root, KeepModel = true,
	})
	if not id then
		log:Warn("%s couldn't register", f.Name)
		model:Destroy()
		fight = nil
		publish(true)
		return
	end
	f.CombatId = id
	model.Name = `{f.BossId}_{id}`
	local colossus = f.BossId == "CrystalColossus"
	play(f, if colossus then "Walk" else "Roar", true)
	for _, activity in look(f).Clips do
		track(f, activity) -- loaded now, so each is ready (and its length known) when she needs it
	end
	local wall = Vector3.new(f.X, f.Y + 6, f.Z - 13)
	rockBurst(if colossus then wall else Vector3.new(f.X, f.Y, f.Z), 40, f)
	if colossus then
		setLit(f, false) -- its cores are dark until a light finds them
	end
	publish(true)
	announce("Danger", `{Boss.Title(f.Name)} {look(f).Up}`)
	local seconds = if colossus then f.T.EmergeSeconds else Boss.Tuning().RiseSeconds
	local started = os.clock()
	local bursts = 1
	while fight == f and os.clock() - started < seconds do
		local k = math.clamp((os.clock() - started) / seconds, 0, 1)
		-- she bursts up and slows; the Colossus strides out at its own pace
		local eased = if colossus then k else 1 - (1 - k) * (1 - k)
		model:PivotTo(finalPivot + from * (1 - eased))
		if colossus and k * 3 >= bursts then
			bursts += 1
			rockBurst(wall + Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-4, 3), 0), 24, f) -- the wall coming apart
		end
		task.wait()
	end
	if fight ~= f then
		return
	end
	model:PivotTo(finalPivot)
	if colossus then
		play(f, "Roar", true)
	end
	f.State = "Fighting"
	f.Busy = os.clock() + f.T.RoarSeconds
	f.NextAttack = f.Busy + 1
	if f.BossId == "Deluge" then
		f.Mode = "Up"
		f.ModeUntil = f.Busy + Boss.ByPhase(f.T.SurfaceSeconds, 1)
		makeWake(f)
		floodPassed(f)
	elseif colossus then
		f.NextVolley = f.Busy + Boss.ByPhase(f.T.VolleySeconds, 1) * 0.5
	else
		f.NextLay = os.clock() + Boss.ByPhase(f.T.LaySeconds, 1) * 0.5
	end
	publish(true)
	log:Info("%s is up (%d health, arena floor %d, columns %d to %d)", f.Name, f.Max, f.Arena.Floor, f.Arena.From, f.Arena.To)
end

function BossService:BeginFight(bossId: string): (boolean, string?)
	if fight then
		return false, `{fight.Name} is already here`
	end
	local entry = Config.Find("Bosses", bossId)
	local t = Boss.Fight(bossId)
	if not entry or not t then
		return false, `no fight for {bossId} yet`
	end
	local arena = Boss.Arena(grid:Bunker())
	if not arena then
		return false, "no open cell for her to break into"
	end
	local left, right = Boss.ArenaSpan(arena, t.ArenaMargin)
	local cell = Grid.CellPosition(arena.Floor, Boss.ArenaMiddle(arena))
	local players = math.max(#session:ReadyPlayers(), 1)
	local warningSeconds = Boss.Tuning().ArrivalWarningSeconds
	local f: Fight = {
		BossId = bossId,
		Name = entry.Name,
		T = t,
		Arena = arena,
		Left = left,
		Right = right,
		X = math.clamp(cell.X, left, right),
		Y = cell.Y,
		Z = cell.Z - 2, -- a little towards the back of the cell, so her front has room
		Yaw = math.pi, -- facing the front of the bunker
		Model = nil,
		Root = nil,
		CombatId = nil,
		Max = Boss.Health(bossId, players, threat:IsFirstRun()),
		Phase = 1,
		State = "Warning",
		ArriveAt = now() + warningSeconds,
		Busy = 0,
		NextAttack = 0,
		NextLay = 0,
		Sacs = {},
		Hits = {},
		LastHitBy = nil,
		PublishedAt = 0,
		Sent = "",
		Effects = {},
		Tracks = {},
		Playing = nil,
		Mode = "",
		ModeUntil = 0,
		SwimFrom = 0,
		Sink = 0,
		Floor = arena.Floor,
		Column = Boss.ArenaMiddle(arena),
		Path = {},
		PathIndex = 1,
		Passed = {},
		Face = nil,
		AloneSince = nil,
		Roar = false,
		Wake = nil,
		Lit = true, -- as the art has them; rise() darkens them
		LitUntil = 0,
		NextVolley = 0,
		WantX = cell.X,
		Moving = false,
	}
	if bossId == "Deluge" then
		f.X, f.Z = cell.X, cell.Z -- it comes up in the middle of its cell
	end
	fight = f
	warning(f, warningSeconds)
	publish(true)
	announce("Danger", `{Boss.Title(entry.Name)} IS BREAKING THROUGH: {where(arena)} · {warningSeconds} S`)
	log:Info("%s breaks in at %s in %d s (%d health, %d players)", entry.Name, where(arena), warningSeconds, f.Max, players)
	BossService.Started:Fire(bossId)
	task.delay(warningSeconds, rise, f)
	return true, nil
end

-- Crits (the Marksman's level 3) and explosions (the Demolitionist's level 3) stagger the boss
-- (Prompt 20), at most every Tuning.Classes.BossStunCooldown seconds and never while she is busy.
local lastStun = -math.huge
function BossService:Stun(combatId: string, why: string): boolean
	local f = fight
	if not f or f.CombatId ~= combatId or f.State ~= "Fighting" or os.clock() < f.Busy then
		return false
	end
	if f.Mode ~= "" and f.Mode ~= "Up" then
		return false -- under water
	end
	if os.clock() - lastStun < Config.Get("Tuning", "Classes").BossStunCooldown then
		return false
	end
	lastStun = os.clock()
	stagger(f)
	log:Info("%s staggered by %s", f.Name, why)
	return true
end

function BossService:Active(): string?
	return if fight then fight.BossId else nil
end

-- Is this combatant the boss (not one of its egg sacs)? True for the killing blow too: Damaged
-- fires before Died.
function BossService:IsBoss(combatId: string): boolean
	return fight ~= nil and fight.CombatId == combatId
end

-- Was this combatant one of a boss's egg sacs (alive or not)?
function BossService:IsEggSac(combatId: string): boolean
	return sacIds[combatId] == true
end

local function onDied(id: string)
	local f = fight
	if not f then
		return
	end
	if f.Sacs[id] then
		removeSac(f, id, "Broken")
		log:Info("an egg sac was broken")
		return
	end
	if id ~= f.CombatId or f.State == "Dying" then
		return
	end
	f.State = "Dying"
	f.CombatId = nil -- CombatService unregistered her
	if f.Mode ~= "" then
		-- The Deluge dies where it is, out of the floor
		f.Mode = "Up"
		f.Sink = 0
		wakeRate(f, 0)
		if f.Model then
			f.Model:PivotTo(pivot(f))
		end
	end
	setActivity("Death")
	local death = f.Tracks.Death
	if death then
		-- hold the last frame until she dissolves
		task.spawn(function()
			while death.IsPlaying and fight == f do
				if death.Length > 0 and death.TimePosition >= death.Length - 0.1 then
					death:AdjustSpeed(0)
					break
				end
				task.wait()
			end
		end)
	end
	for sacId in table.clone(f.Sacs) do
		removeSac(f, sacId, "Withered")
	end
	publish(true)
	local killer: Player? = nil
	for _, player in Players:GetPlayers() do
		if `P{player.UserId}` == f.LastHitBy then
			killer = player
		end
	end
	announce("Info", `{Boss.Title(f.Name)} IS DEAD{if killer then ` · FINISHED BY {string.upper(killer.DisplayName)}` else ""}`)
	log:Info("%s is dead (last blow: %s)", f.Name, if killer then killer.Name else "-")
	-- Defeated first: BossBeaten ends the Surge and the year moves on, and the run's story
	-- should say the year she fell.
	BossService.Defeated:Fire(f.BossId, killer)
	objectives:BossBeaten(f.BossId)
	task.delay(Boss.Tuning().DeathSeconds, function()
		if fight == f then
			cleanup(f)
			fight = nil
			publish(true)
		end
	end)
end

local function onDamaged(id: string, amount: number, source: string?, how: string?)
	local f = fight
	if not f or id ~= f.CombatId then
		return
	end
	if source then
		f.LastHitBy = source
	end
	if how == "weakpoint" and f.State == "Fighting" and (f.Mode == "" or f.Mode == "Up") then
		table.insert(f.Hits, { At = os.clock(), Amount = amount })
		while #f.Hits > 0 and os.clock() - f.Hits[1].At > f.T.StaggerWindowSeconds do
			table.remove(f.Hits, 1)
		end
		if os.clock() >= f.Busy and Boss.Staggers(f.Hits, os.clock(), f.T.StaggerWindowSeconds, f.T.StaggerFraction * f.Max) then
			stagger(f)
		end
	end
	publish()
end

-- Armour, weak points and burning sacs (WeaponService's hit modifier).
local function hitModifier(target: any, point: Vector3?, how: string, player: Player): (number, string?)
	local f = fight
	if not f then
		return 1, nil
	end
	if target.Id == f.CombatId and f.Model then
		if f.Mode == "Swim" or f.Mode == "Diving" then
			return f.T.SubmergedMultiplier, nil -- only its back fin shows
		end
		if f.BossId == "CrystalColossus" and not f.Lit then
			return f.T.ArmourMultiplier, nil -- all armour until a light shows its cores
		end
		local weak = false
		if point then
			local tolerance = Boss.Tuning().WeakPointTolerance + (if how == "struck" or how == "smashed" then 2 else 0)
				+ (if how == "blast" then 3 else 0)
			for _, part in weakParts(f.Model) do
				if Boss.OnPart(point, part.CFrame, part.Size, tolerance) then
					weak = true
					break
				end
			end
		end
		local classValue = Modifiers.PlayerValue(player, "WeakPointMultiplier")
		if f.BossId == "CrystalColossus" and not weak then
			return f.T.ArmourMultiplier, nil -- "Huge, slow and armored"
		end
		return Boss.HitMultiplier(weak, classValue), if weak then "weakpoint" else nil
	end
	if f.Sacs[target.Id] and how == "burned" then
		return f.T.BurnMultiplier, nil
	end
	return 1, nil
end

-- DevTools ---------------------------------------------------------------------------------------------------

local function describe(): string
	local f = fight
	if not f then
		return "no boss fight"
	end
	local health, max = 0, f.Max
	if f.CombatId then
		health, max = combat:HealthOf(f.CombatId)
	end
	local count = 0
	for _ in f.Sacs do
		count += 1
	end
	if f.Mode ~= "" then
		return string.format("%s: %s (%s, %.0f s left), %d/%d health, phase %d, floor %d column %d (%.0f, %.0f, %.0f), %.1f under, path %d of %d, %s",
			f.Name, f.State, f.Mode, math.max(f.ModeUntil - os.clock(), 0), math.ceil(health), max, f.Phase, f.Floor, f.Column,
			f.X, f.Y, f.Z, f.Sink, f.PathIndex, #f.Path, tostring(f.Model and f.Model:GetAttribute("Activity")))
	end
	local line = string.format("%s: %s, %d/%d health, phase %d, arena floor %d columns %d to %d (x %.0f to %.0f), at x %.1f, %d egg sacs, %s",
		f.Name, f.State, math.ceil(health), max, f.Phase, f.Arena.Floor, f.Arena.From, f.Arena.To, f.Left, f.Right, f.X, count,
		tostring(f.Model and f.Model:GetAttribute("Activity")))
	if f.BossId == "CrystalColossus" then
		line ..= string.format(", cores %s, next volley in %.0f s", if f.Lit then "LIT" else "dark", math.max(f.NextVolley - os.clock(), 0))
	end
	return line
end

local function registerCommands(dev: any)
	dev:Register("boss", {
		Description = "The boss fight now: state, health, phase, arena, egg sacs.",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("boss.start", {
		Description = "Start a boss's fight now, outside its Surge (Studio testing).",
		Usage = "boss.start [BroodMother|Deluge|CrystalColossus]",
		Run = function(_player, args): string?
			local ok, why = BossService:BeginFight(tostring(args[1] or "BroodMother"))
			return if ok then describe() else `can't: {why}`
		end,
	})
	dev:Register("boss.hurt", {
		Description = "Take health off the boss (weak: as belly hits, which can stagger her).",
		Usage = "boss.hurt <amount> [weak]",
		Run = function(player, args): string?
			local f = fight
			local amount = tonumber(args[1])
			if not f or not f.CombatId or not amount then
				return "usage: boss.hurt <amount> [weak] (during a fight)"
			end
			local source = if player then `P{player.UserId}` else nil
			combat:Damage(f.CombatId, amount, source, if args[2] == "weak" then "weakpoint" else "dev")
			return describe()
		end,
	})
	dev:Register("boss.lay", {
		Description = "The boss lays eggs now.",
		Run = function(): string?
			local f = fight
			if not f or f.State ~= "Fighting" then
				return "no boss fighting"
			end
			f.Busy = 0
			f.NextLay = 0
			return describe()
		end,
	})
	dev:Register("boss.freeze", {
		Description = "The boss stands still (no turning, walking, slams or eggs; sacs still hatch) for a while (Studio testing).",
		Usage = "boss.freeze [seconds]",
		Run = function(_player, args): string?
			local f = fight
			if not f or f.State ~= "Fighting" then
				return "no boss fighting"
			end
			local seconds = tonumber(args[1]) or 20
			f.Busy = os.clock() + seconds
			if f.Mode == "Up" then
				f.ModeUntil = f.Busy + 1
			end
			setActivity("Idle")
			return `frozen for {seconds} s\n{describe()}`
		end,
	})
	dev:Register("boss.volley", {
		Description = "The Crystal Colossus throws its shards now (Studio testing).",
		Run = function(): string?
			local f = fight
			if not f or f.State ~= "Fighting" or f.BossId ~= "CrystalColossus" then
				return "the Crystal Colossus isn't fighting"
			end
			f.Busy = 0
			f.NextVolley = 0
			return describe()
		end,
	})
	dev:Register("boss.light", {
		Description = "Show the Crystal Colossus's cores for a while, as a flare would (Studio testing).",
		Usage = "boss.light [seconds]",
		Run = function(_player, args): string?
			local f = fight
			if not f or f.BossId ~= "CrystalColossus" then
				return "no Crystal Colossus"
			end
			f.LitUntil = os.clock() + (tonumber(args[1]) or f.T.LitSeconds)
			return describe()
		end,
	})
	dev:Register("boss.dive", {
		Description = "The Deluge dives now (Studio testing).",
		Run = function(): string?
			local f = fight
			if not f or f.State ~= "Fighting" or f.Mode ~= "Up" then
				return "The Deluge isn't up"
			end
			f.Busy = 0
			delugeDive(f)
			return describe()
		end,
	})
	dev:Register("boss.surface", {
		Description = "The Deluge comes up at the next cell it reaches (Studio testing).",
		Run = function(): string?
			local f = fight
			if not f or f.State ~= "Fighting" or f.Mode ~= "Swim" then
				return "The Deluge isn't swimming"
			end
			f.ModeUntil = 0
			f.SwimFrom = 0
			return describe()
		end,
	})
	dev:Register("boss.end", {
		Description = "Take the boss away without beating her (cleanup).",
		Run = function(): string?
			local f = fight
			if not f then
				return "no boss fight"
			end
			cleanup(f)
			fight = nil
			publish(true)
			return "the boss is gone"
		end,
	})
end

-- Lifecycle ----------------------------------------------------------------------------------------------------

function BossService:Init(registry)
	clock = registry.CycleClock
	director = registry.RunDirector
	grid = registry.BunkerGrid
	session = registry.SessionService
	combat = registry.CombatService
	monsters = registry.MonsterService
	weapons = registry.WeaponService
	objectives = registry.ObjectiveService
	threat = registry.ThreatDirector
	disasters = registry.DisasterService
	collection = registry.ReplicationService:Collection("Boss")
	registerCommands(registry.DevService)
end

function BossService:Start()
	clock.SurgeStarted:Connect(function(kind: string, bossId: string?)
		if kind == "Boss" and bossId then
			local ok, why = BossService:BeginFight(bossId)
			if not ok then
				log:Warn("the %s Surge has no fight: %s", bossId, tostring(why))
			end
		end
	end)
	director.PhaseChanged:Connect(function(new: string)
		if new == "Ended" and fight then
			cleanup(fight)
			fight = nil
			publish(true)
		end
	end)
	combat.Died:Connect(onDied)
	combat.Damaged:Connect(onDamaged)
	weapons:SetHitModifier(hitModifier)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local f = fight
		if f and f.Mode ~= "" then
			local ok, err = pcall(frameDeluge, f, math.min(dt, 0.1))
			if not ok then
				log:Warn("frame: %s", tostring(err))
			end
		elseif f and f.BossId == "CrystalColossus" then
			local ok, err = pcall(frameColossus, f, math.min(dt, 0.1))
			if not ok then
				log:Warn("frame: %s", tostring(err))
			end
		end
		acc += dt
		local step = Boss.Tuning().TickSeconds
		if acc >= step then
			local elapsed = math.min(acc, 0.5)
			acc = 0
			local ok, err = pcall(tick, elapsed)
			if not ok then
				log:Warn("tick: %s", tostring(err))
			end
		end
	end)
	log:Info("boss fights ready")
end

return BossService
