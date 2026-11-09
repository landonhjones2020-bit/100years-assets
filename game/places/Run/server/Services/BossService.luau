--!strict
--[[
	BossService: boss fights (bible Sections 5, 10 and 22). Run place only; Prompt 15 brings the
	Era I boss, the Brood Mother. The arithmetic is Shared.Rules.Boss; the numbers are
	Config.Bosses, Tuning.Bosses and Tuning.BroodMother (provisional).

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

	Replication: the Boss collection, "Fight" -> { Id, Name, Health, Max, Phase, Phases, State,
	At = { X, Y, Z } (where she breaks in), ArriveAt (server time), Sacs } while a fight is on.
	The model is in workspace.Monsters with Rig, Activity and AttackAt attributes. Unlike other
	monsters (Section 23: clips play on clients), her clips play here on the server and replicate
	(ServerAnimated, which NPCAnimator skips): one model, and the server must see her belly where
	players see it when it judges a hit.

	API:
		BossService:BeginFight(bossId): (boolean, string?) -- a fight now (CycleClock's boss Surge; DevTools)
		BossService:Active(): string?
		BossService:IsBoss(combatId): boolean           -- the boss itself, not an egg sac
		BossService:IsEggSac(combatId): boolean         -- one of its egg sacs (a broken sac isn't a kill)
		BossService.Started: Signal<string>             -- bossId
		BossService.Defeated: Signal<string, Player?>   -- bossId, who struck the last blow
	Dev: boss, boss.start, boss.hurt, boss.lay, boss.end.
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
		"ObjectiveService", "ThreatDirector", "ReplicationService", "DevService",
	},
	Started = Signal.new() :: Signal.Signal<string>,
	Defeated = Signal.new() :: Signal.Signal<string, Player?>,
}

local RISE_DEPTH = 13 -- how far under the floor she starts
local HATCH_TAG_PREFIX = "Boss:"

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
local collection: any = nil

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
	return CFrame.new(f.X, f.Y, f.Z) * CFrame.Angles(0, f.Yaw, 0)
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
	local sent = `{math.ceil(health)}|{f.Phase}|{f.State}|{count}`
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
		At = { X = f.X, Y = at.Y, Z = f.Z },
		ArriveAt = f.ArriveAt,
		Sacs = count,
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

local function rockBurst(at: Vector3, chips: number)
	local part = effectPart(at + Vector3.new(0, 0.5, 0), "BossBurst")
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(140, 128, 112))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.5, 3)
	dust.Speed = NumberRange.new(8, 18)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Acceleration = Vector3.new(0, -4, 0)
	dust.Rate = 0
	dust.Parent = part
	local rocks = Instance.new("ParticleEmitter")
	rocks.Color = ColorSequence.new(Color3.fromRGB(70, 64, 58))
	rocks.Size = NumberSequence.new(0.6)
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
	dust.Color = ColorSequence.new(Color3.fromRGB(140, 128, 112))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.4)
	dust.Speed = NumberRange.new(1, 4)
	dust.SpreadAngle = Vector2.new(90, 90)
	dust.Rate = 18
	dust.Parent = part
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(232, 80, 59)
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

local function makeModel(f: Fight): (Model, BasePart)
	local entry = Config.Get("Bosses", f.BossId)
	local template = art(entry.Asset)
	local model = if template then template:Clone() else graybox(f.BossId)
	model.Name = f.BossId
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
			part.Anchored = part == root
		end
	end
	root.CanQuery = false -- her invisible root box mustn't catch shots meant for her belly
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
	glowAt.Position = root.CFrame:PointToObjectSpace(model:GetPivot() * Vector3.new(0, 10, 2))
	glowAt.Parent = root
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(124, 255, 155)
	glow.Range = 24
	glow.Brightness = 1.2
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
	table.clear(f.Hits)
	if f.Model then
		f.Model:SetAttribute("StaggeredAt", now())
	end
	log:Info("%s staggered", f.Name)
end

local function tick(dt: number)
	local f = fight
	if not f or f.State ~= "Fighting" or not f.Model or not f.CombatId then
		return
	end
	local health, max = combat:HealthOf(f.CombatId)
	local phase = Boss.Phase(f.BossId, if max > 0 then health / max else 0)
	if phase > f.Phase then
		f.Phase = phase
		setActivity("Roar")
		f.Busy = os.clock() + f.T.RoarSeconds
		f.NextLay = math.min(f.NextLay, os.clock() + f.T.RoarSeconds + 1)
		announce("Danger", `THE {string.upper(f.Name)} SHRIEKS: SHE LAYS FASTER AND HITS HARDER`)
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
	model:PivotTo(finalPivot - Vector3.new(0, RISE_DEPTH, 0))
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
	play(f, "Roar", true)
	for _, activity in { "Idle", "Walk", "Attack", "LayEggs", "Stagger", "Death" } do
		track(f, activity) -- loaded now, so each is ready (and its length known) when she needs it
	end
	rockBurst(Vector3.new(f.X, f.Y, f.Z), 40)
	publish(true)
	announce("Danger", `THE {string.upper(f.Name)} BREAKS THROUGH! HIT HER GLOWING BELLY, BREAK HER EGG SACS`)
	local seconds = Boss.Tuning().RiseSeconds
	local started = os.clock()
	while fight == f and os.clock() - started < seconds do
		local k = math.clamp((os.clock() - started) / seconds, 0, 1)
		local eased = 1 - (1 - k) * (1 - k)
		model:PivotTo(finalPivot - Vector3.new(0, RISE_DEPTH * (1 - eased), 0))
		task.wait()
	end
	if fight ~= f then
		return
	end
	model:PivotTo(finalPivot)
	f.State = "Fighting"
	f.Busy = os.clock() + f.T.RoarSeconds
	f.NextAttack = f.Busy + 1
	f.NextLay = os.clock() + Boss.ByPhase(f.T.LaySeconds, 1) * 0.5
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
	}
	fight = f
	warning(f, warningSeconds)
	publish(true)
	announce("Danger", `THE {string.upper(entry.Name)} IS BREAKING THROUGH: {where(arena)} · {warningSeconds} S`)
	log:Info("%s breaks in at %s in %d s (%d health, %d players)", entry.Name, where(arena), warningSeconds, f.Max, players)
	BossService.Started:Fire(bossId)
	task.delay(warningSeconds, rise, f)
	return true, nil
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
	announce("Info", `THE {string.upper(f.Name)} IS DEAD{if killer then ` · {string.upper(killer.DisplayName)} STRUCK THE LAST BLOW` else ""}`)
	log:Info("%s is dead (last blow: %s)", f.Name, if killer then killer.Name else "-")
	objectives:BossBeaten(f.BossId)
	BossService.Defeated:Fire(f.BossId, killer)
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
	if how == "weakpoint" and f.State == "Fighting" then
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
		local classValue = Modifiers.ClassValue(player:GetAttribute("Class") :: string?, "WeakPointMultiplier")
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
	return string.format("%s: %s, %d/%d health, phase %d, arena floor %d columns %d to %d (x %.0f to %.0f), at x %.1f, %d egg sacs, %s",
		f.Name, f.State, math.ceil(health), max, f.Phase, f.Arena.Floor, f.Arena.From, f.Arena.To, f.Left, f.Right, f.X, count,
		tostring(f.Model and f.Model:GetAttribute("Activity")))
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
		Usage = "boss.start [BroodMother]",
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
