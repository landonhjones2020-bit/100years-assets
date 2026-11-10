--!strict
--[[
	WeaponService: what players carry and how they use it (bible Section 9; Section 23: firing,
	reloads, ammo and the server's hit checks). Run place only; Prompt 11.

	Loadouts
	* Each player carries their class kit (Config.Classes): ClassService gives it (SetClass, Prompt
	  20: the run record's class, or /dev class), the Survivor's until then. Kit items are Standard
	  rarity; the Demolitionist's level 2 adds ExtraFragGrenades Frag Grenades.
	* Section 9's loadout is two guns, one melee weapon, one tool and two throwables. The hotbar
	  holds the guns (slots 1 and 2), the tool (3) and the throwables (4 and 5); the melee weapon
	  has its own button. A kit with no melee weapon punches (Tuning.Combat.Unarmed).
	* The selected slot's item is held: a clone of its model (ServerStorage.Assets.Weapons)
	  welded to the right hand at its Grip socket. Slot 0 holds the melee weapon. A swing holds
	  the melee weapon until it ends.
	* Ammo: each gun's magazine, and the player's carried ammo (Tuning.Combat.CarriedAmmo.Start
	  the first time they spawn in a run, up to .Max). A reload moves whole shots from carried
	  ammo into the magazine over the gun's ReloadSeconds; changing slots cancels it. At a
	  Workshop or an Armory, holding Interact for RestockSeconds fills carried ammo from the
	  team's Ammo stockpile (Section 9: players restock at the Armory or Workshop).

	Guns (Section 23: the client fires for instant feedback; the server checks)
	* FireWeapon(slot, shot, origin, aim, time, claims). The shot's number must be the next one,
	  the gun held, loaded, not reloading and past its fire interval (RateTolerance early at
	  most), and the origin near the player. Every pellet's direction comes from the shot's
	  seed (Rules.Combat.Spread), so the client can't choose its spread. Each claimed hit must
	  lie on its pellet's ray, within range, in the line of sight (the server's own raycast)
	  and near where the target was over the last LagSeconds. Only monsters can be hit.
	* A flame gun (Cone) burns every monster in its cone each tick; a Projectile gun's round
	  flies under gravity, run by the server, and bursts on what it touches (BlastRadius;
	  players' explosives never damage the bunker). Explosions take the thrower's ExplosiveDamage
	  and ExplosiveRadius (the Demolitionist, Prompt 20). An arc gun's hit jumps to ChainTargets
	  more monsters within Tuning.Classes.ArcChainRange, each jump ArcChainFalloff as strong (the
	  Mad Scientist's level 2: ArcChainTargets). Reloading a flame gun costs FuelUse of its ammo
	  (the Exterminator's level 2).
	* Steady Shot (Prompt 20): ClassService's shot hook (SetShotHook) may make a shot pierce (every
	  monster on the pellet's line, checked by the server) and crit (times CritMultiplier; how
	  "crit").
	* HitConfirmed tells the shooter what each hit did (hit markers, damage numbers).

	Melee, dodge, sprint, stamina (Section 9)
	* MeleeSwing(heavy, facing): light swings chain into ComboSteps hits; a heavy swing costs
	  HeavySwingStamina and takes HeavySwingMultiplier as long. The hit lands at the windup's
	  end and is checked then (reach and arc in front, Monster Lab's rule), with the weapon's
	  knockback and stun (StunnedUntil on the monster, for Prompt 12's AI).
	* Dodge(direction): DodgeStamina, then DodgeInvulnerableSeconds of invulnerability
	  (CombatService); the client moves the character.
	* Sprint(on): drains SprintStaminaPerSecond while moving; stamina grows back after
	  StaminaRegenDelay.

	Medkits and throwables (Landon, 2026-11-08)
	* Players carry up to Tuning.Player.Loadout.Medkits Medkits (the Medic's kit starts with 5
	  and may carry 5). UseMedkit heals MedkitHeal over MedkitSeconds; going down cancels it and
	  keeps the Medkit. A Medbay's restock point fills carried Medkits from the team's stockpile
	  (Section 13: Medkits come from the Medbay).
	* A throwable slot (4 or 5) holds a stack (Count). With it selected, Fire throws one
	  (ThrowItem): it flies under ThrowGravity and acts where it lands: a Frag Grenade bursts
	  (Radius, Damage, monsters only), a Flare lights the spot for LightSeconds, a Foam Grenade
	  sprays foam (Foamed fires for Prompt 13's fires) and a Shock Mine arms and stuns the
	  monsters that come near it.

	Tools (Prompt 13): with the tool slot (3) held, holding Fire uses the tool (UseTool on and
	off; the client faces where the camera looks). While a tool is in use, ToolTick fires
	ToolTickSeconds apart with the player's root CFrame: DisasterService sprays fires with the
	Extinguisher, BuildService repairs with the Welder. Changing slots, swinging or going down
	stops it. ToolInUse (the item id) shows the use to every client (spray, sparks).
	Swung fires when a melee swing lands (after its windup), for what else a swing can hit
	(DisasterService: cave-in rubble).

	Attributes on the Player (all replicate): Class, Slot, Item1 to Item5, Mag1 and Mag2,
	Count4 and Count5, MeleeItem, CarriedAmmo, Medkits, HealEndsAt, Stamina, ReloadEndsAt,
	ShotSalt, ShotNext, SwingEndsAt, ToolInUse.
	API: Loadout(player), Items(player): { string }, Carries(player, itemId): boolean,
	GiveThrowable(player, itemId, count): number (Prompt 14: caches); signals Foamed, ToolTick,
	Swung (Prompt 13) and Exploded (Prompt 14: explosives raise Disturbance);
	SetHitModifier(fn) (Prompt 15: a boss's armour and weak points scale hits and may rename them,
	"weakpoint"); Prompt 20: SetClass(player, classId, level), AddHitModifier(name, fn) (class
	damage: the Exterminator's CreatureDamage), SetShotHook(fn), Explode(player, at, radius, damage),
	and the Hit signal (player, target id, damage done, how, point) for what a hit sets off
	(burning, a boss stagger, a kill's Disturbance).
	Dev: give, ammo, medkits, loadout, stamina (class moved to ClassService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Rules.Combat)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("WeaponService")

local SLOTS = 5
local GUN_SLOTS = 2
local MOVING_SPEED = 2 -- studs/s: below this a sprinting player isn't moving
local STAMINA_HZ = 10

type Held = { Item: string, Rarity: string, Magazine: number?, Count: number? }
type Loadout = {
	Class: string,
	Slots: { [number]: Held? },
	Melee: Held,
	Selected: number,
	Carried: number,
	Stamina: number,
	SpentAt: number, -- os.clock() of the last stamina spend
	Sprinting: boolean,
	Salt: number,
	NextShot: number,
	LastShotAt: number,
	ReloadEndsAt: number,
	ReloadToken: number,
	SwingEndsAt: number,
	ComboStep: number,
	LastSwingAt: number,
	DodgeReadyAt: number,
	Medkits: number,
	MedkitCap: number,
	Level: number, -- the class level (Prompt 20)
	HealEndsAt: number,
	HealToken: number,
	LastThrowAt: number,
	ToolOn: string?, -- the tool in use (Prompt 13)
}

local WeaponService = {
	Name = "WeaponService",
	Dependencies = { "CombatService", "EconomyService", "BunkerGrid", "SessionService", "DevService" },
	-- A Foam Grenade burst: position, radius, the thrower (Prompt 13's fires listen).
	Foamed = Signal.new() :: Signal.Signal<Vector3, number, Player>,
	-- A tool in use (Prompt 13): the player, the tool, their root CFrame, the seconds since the last tick.
	ToolTick = Signal.new() :: Signal.Signal<Player, string, CFrame, number>,
	-- A melee swing landing: the player, where they stood facing, its reach, its arc in degrees,
	-- its damage, the weapon, heavy or not (Prompt 13: rubble).
	Swung = Signal.new() :: Signal.Signal<Player, CFrame, number, number, number, string, boolean>,
	-- A player's explosive went off: where, its radius, whose (Prompt 14: explosives raise Disturbance).
	Exploded = Signal.new() :: Signal.Signal<Vector3, number, Player>,
	-- A player's hit landed (Prompt 20): who, the target's combatant id, the damage done, how, where,
	-- and the hit's own kind before a boss renamed it (a crit or a blast on the belly is "weakpoint").
	Hit = Signal.new() :: Signal.Signal<Player, string, number, string, Vector3?, string>,
}

local combat: any = nil
local economy: any = nil
local grid: any = nil
local dev: any = nil

local loadouts: { [Player]: Loadout } = {}
local restockFolder: Folder? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Loadouts --------------------------------------------------------------------------------

-- Team modifiers from draft cards (Prompt 19): WeaponRarityUp (every player's weapons, now and in
-- every loadout made later) and StaminaMult (max stamina). Key -> source -> value.
local teamMods: { [string]: { [string]: number } } = {}

local function teamSum(key: string): number
	local total = 0
	for _, v in teamMods[key] or {} do
		total += v
	end
	return total
end

local function staminaMax(): number
	local value = Config.Get("Tuning", "Player").Stamina
	for _, v in teamMods.StaminaMult or {} do
		value *= v
	end
	return value
end

-- A rarity `steps` ranks up (or down), within Config.ItemRarities' order.
local function raised(rarity: string, steps: number): string
	local order = Config.Ids("ItemRarities")
	local at = table.find(order, rarity) or table.find(order, "Standard") or 1
	return order[math.clamp(at + math.floor(steps), 1, #order)]
end

local function kitOf(classId: string): (
	{ [number]: Held? },
	Held,
	number
)
	local class = Config.Find("Classes", classId) or Config.Get("Classes", "Survivor")
	local guns, throwables, counts = {}, {}, {}
	local tool: string? = nil
	local melee: string? = nil
	local medkits = 0
	for _, stack in class.Kit do
		local item = Config.Find("Items", stack.Item)
		if item then
			if item.Kind == "Gun" then
				table.insert(guns, stack.Item)
			elseif item.Kind == "Melee" then
				melee = melee or stack.Item
			elseif item.Kind == "Tool" then
				tool = tool or stack.Item
			elseif item.Kind == "Throwable" then
				table.insert(throwables, stack.Item)
				table.insert(counts, stack.Count or 1)
			elseif stack.Item == "Medkit" then
				medkits += stack.Count or 1
			end
		end
	end
	local slots: { [number]: Held? } = {}
	for i = 1, GUN_SLOTS do
		local id = guns[i]
		if id then
			local gun = Combat.Gun(id)
			slots[i] = { Item = id, Rarity = "Standard", Magazine = if gun then gun.Magazine else 0 }
		end
	end
	if tool then
		slots[3] = { Item = tool, Rarity = "Standard" }
	end
	for i = 1, 2 do
		if throwables[i] then
			slots[3 + i] = { Item = throwables[i], Rarity = "Standard", Count = counts[i] }
		end
	end
	-- Armory Shipment and the like (Prompt 19): kit weapons start that many rarities up
	local bonus = teamSum("WeaponRarityUp")
	if bonus ~= 0 then
		for i = 1, GUN_SLOTS do
			local held = slots[i]
			if held then
				held.Rarity = raised(held.Rarity, bonus)
			end
		end
	end
	local meleeRarity = if melee and bonus ~= 0 then raised("Standard", bonus) else "Standard"
	return slots, { Item = melee or Combat.UNARMED, Rarity = meleeRarity }, medkits
end

local function publish(player: Player, state: Loadout)
	player:SetAttribute("Class", state.Class)
	player:SetAttribute("Slot", state.Selected)
	for i = 1, SLOTS do
		local held = state.Slots[i]
		player:SetAttribute(`Item{i}`, if held then held.Item else nil)
		if i <= GUN_SLOTS then
			player:SetAttribute(`Mag{i}`, if held then held.Magazine else nil)
		end
	end
	for i = 4, SLOTS do
		local held = state.Slots[i]
		player:SetAttribute(`Count{i}`, if held then held.Count else nil)
	end
	player:SetAttribute("MeleeItem", state.Melee.Item)
	player:SetAttribute("CarriedAmmo", state.Carried)
	player:SetAttribute("Medkits", state.Medkits)
	player:SetAttribute("HealEndsAt", if state.HealEndsAt > now() then state.HealEndsAt else nil)
	player:SetAttribute("ShotSalt", state.Salt)
	player:SetAttribute("ShotNext", state.NextShot)
	player:SetAttribute("ReloadEndsAt", if state.ReloadEndsAt > now() then state.ReloadEndsAt else nil)
end

local function firstSlot(state: Loadout): number
	for i = 1, SLOTS do
		if state.Slots[i] then
			return i
		end
	end
	return 0
end

local function newLoadout(player: Player, classId: string, carried: number?, level: number?): Loadout
	local slots, melee, medkits = kitOf(classId)
	local p = Config.Get("Tuning", "Player")
	local state: Loadout = {
		Class = classId,
		Slots = slots,
		Melee = melee,
		Selected = 0,
		Carried = carried or Combat.Tuning().CarriedAmmo.Start,
		Stamina = staminaMax(),
		SpentAt = 0,
		Sprinting = false,
		Salt = Random.new():NextInteger(1, 2 ^ 30),
		NextShot = 1,
		LastShotAt = -math.huge,
		ReloadEndsAt = 0,
		ReloadToken = 0,
		SwingEndsAt = 0,
		ComboStep = 0,
		LastSwingAt = -math.huge,
		DodgeReadyAt = 0,
		Medkits = medkits,
		MedkitCap = math.max(p.Loadout.Medkits, medkits),
		HealEndsAt = 0,
		HealToken = 0,
		LastThrowAt = -math.huge,
		ToolOn = nil,
		Level = level or 1,
	}
	player:SetAttribute("ToolInUse", nil)
	state.Selected = firstSlot(state)
	loadouts[player] = state
	player:SetAttribute("Stamina", state.Stamina)
	player:SetAttribute("StaminaMax", if math.abs(staminaMax() - p.Stamina) > 1e-6 then staminaMax() else nil)
	publish(player, state)
	return state
end

-- Held models ------------------------------------------------------------------------------

local function modelOf(itemId: string): Model?
	local item = Config.Find("Items", itemId)
	if not item or not item.Asset then
		return nil
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local template = folder and folder:FindFirstChild(item.Asset)
	return if template and template:IsA("Model") then template else nil
end

local function holdItem(player: Player, itemId: string?)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("HeldItem")
	if old and old:GetAttribute("Item") == itemId then
		return
	end
	if old then
		old:Destroy()
	end
	if not itemId then
		return
	end
	local hand = character:FindFirstChild("RightHand")
	local template = modelOf(itemId)
	if not (hand and hand:IsA("BasePart") and template) then
		return
	end
	local model = template:Clone()
	model.Name = "HeldItem"
	model:SetAttribute("Item", itemId)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not primary then
		model:Destroy()
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	-- Sockets are the model's Socket_<Name> attributes, relative to its pivot (the art
	-- pipeline's AssetSetup). The Grip socket sits in the hand's grip with the item's front
	-- (-Z) along the fingers: forward when the forearm points forward. The Muzzle and Tip
	-- sockets become attachments, for the client's flashes and tracers.
	local pivot = model:GetPivot()
	local function socket(name: string): CFrame?
		local value = model:GetAttribute(`Socket_{name}`)
		return if typeof(value) == "CFrame" then pivot * value else nil
	end
	local gripWorld = socket("Grip") or pivot
	local gripInPrimary = primary.CFrame:ToObjectSpace(gripWorld)
	for _, name in { "Muzzle", "Tip" } do
		local at = socket(name)
		if at then
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = primary.CFrame:ToObjectSpace(at)
			attachment.Parent = primary
		end
	end
	local handGrip = hand:FindFirstChild("RightGripAttachment")
	local handCFrame = if handGrip and handGrip:IsA("Attachment") then handGrip.CFrame else CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = part
			weld.Parent = part
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = hand
	weld.Part1 = primary
	weld.C0 = handCFrame
	weld.C1 = gripInPrimary
	weld.Parent = primary
	model.Parent = character
end

-- What the player should be holding now.
local function refreshHeld(player: Player, state: Loadout)
	if player:GetAttribute("Carrying") ~= nil then
		holdItem(player, nil) -- both hands on a big find
		return
	end
	if now() < state.SwingEndsAt then
		holdItem(player, if state.Melee.Item ~= Combat.UNARMED then state.Melee.Item else nil)
		return
	end
	local held = state.Slots[state.Selected]
	if held then
		holdItem(player, held.Item)
	elseif state.Selected == 0 and state.Melee.Item ~= Combat.UNARMED then
		holdItem(player, state.Melee.Item)
	else
		holdItem(player, nil)
	end
end

local function alive(player: Player): boolean
	return player:GetAttribute("Life") == "Alive"
end

-- Both hands on a big find (Prompt 16, Section 12): no firing, swinging, throwing, tools, rolls or
-- Medkits until it is put down.
local function handsFree(player: Player): boolean
	return alive(player) and player:GetAttribute("Carrying") == nil
end

local function spend(state: Loadout, player: Player, amount: number): boolean
	if state.Stamina < amount then
		return false
	end
	state.Stamina -= amount
	state.SpentAt = os.clock()
	player:SetAttribute("Stamina", state.Stamina)
	return true
end

-- Line of sight: does the world block the way from `from` to `to`?
local function blocked(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local offset = to - from
	local distance = offset.Magnitude
	if distance < 0.5 then
		return false
	end
	local hit = workspace:Raycast(from, offset.Unit * (distance - 0.5), params)
	return hit ~= nil
end

-- Everything a shot passes through when judging the line of sight: people and monsters.
local function bodies(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, c in combat:All() do
		if c.Kind ~= "Player" then
			table.insert(list, c.Model)
		end
	end
	return list
end

local function confirm(player: Player, targetId: string, done: number, point: Vector3?, how: string?, kind: string?)
	local target = combat:Get(targetId)
	local killed = target == nil or target.State == "Dead"
	Remotes.FireClient("HitConfirmed", player, targetId, done, killed, point)
	WeaponService.Hit:Fire(player, targetId, done, how or "hit", point, kind or how or "hit")
end

-- Guns ---------------------------------------------------------------------------------------

-- A boss's armour and weak points (Prompt 15): BossService's hook scales a hit and may rename it.
local hitModifier: ((target: any, point: Vector3?, how: string, player: Player) -> (number, string?))? = nil

-- Steady Shot (Prompt 20): fn(player, itemId) -> { Pierce, Crit }? for each shot fired.
local shotHook: ((Player, string) -> any)? = nil

-- Class damage (Prompt 20): fn(target, point, how, player) -> multiplier, by name.
local hitModifiers: { { Name: string, Fn: (any, Vector3?, string, Player) -> number } } = {}

local function modified(target: any, amount: number, point: Vector3?, how: string, player: Player): (number, string)
	for _, entry in hitModifiers do
		local ok, multiplier = pcall(entry.Fn, target, point, how, player)
		if ok and type(multiplier) == "number" and multiplier == multiplier then
			amount *= multiplier
		elseif not ok then
			log:Warn("hit modifier %s: %s", entry.Name, tostring(multiplier))
		end
	end
	local fn = hitModifier
	if fn then
		local ok, multiplier, newHow = pcall(fn, target, point, how, player)
		if ok and type(multiplier) == "number" then
			return amount * multiplier, if type(newHow) == "string" then newHow else how
		elseif not ok then
			log:Warn("hit modifier: %s", tostring(multiplier))
		end
	end
	return amount, how
end

local function explode(player: Player, at: Vector3, radius: number, damage: number, shooterId: string)
	-- the Demolitionist's explosives (Prompt 20)
	radius *= Modifiers.PlayerValue(player, "ExplosiveRadius") or 1
	damage *= Modifiers.PlayerValue(player, "ExplosiveDamage") or 1
	WeaponService.Exploded:Fire(at, radius, player)
	local blast = Instance.new("Explosion")
	blast.BlastPressure = 0 -- visual only: players' explosives never damage the bunker (Section 9)
	blast.DestroyJointRadiusPercent = 0
	blast.BlastRadius = radius
	blast.Position = at
	blast.Parent = workspace
	local ignore = bodies()
	for _, c in combat:All("Monsters") do
		local distance = (c.Root.Position - at).Magnitude - c.Reach
		if distance <= radius and not blocked(at, c.Root.Position, ignore) then
			local scale = 1 - math.clamp(distance / radius, 0, 1) * 0.5
			local amount, how = modified(c, damage * scale, at, "blast", player)
			local done = combat:Damage(c.Id, amount, shooterId, how)
			if done > 0 then
				confirm(player, c.Id, done, c.Root.Position, how, "blast")
			end
		end
	end
end

local function launch(player: Player, origin: Vector3, direction: Vector3, gun: { [string]: any }, damage: number, shooterId: string)
	local t = Combat.Tuning()
	local round = Instance.new("Part")
	round.Name = "Round"
	round.Shape = Enum.PartType.Ball
	round.Size = Vector3.new(0.6, 0.6, 0.6)
	round.Material = Enum.Material.Neon
	round.Color = Color3.fromRGB(232, 116, 59)
	round.Anchored = true
	round.CanCollide = false
	round.CanQuery = false
	round.CanTouch = false
	round.CFrame = CFrame.new(origin)
	round.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { round, player.Character :: Instance }
	local velocity = direction.Unit * t.ProjectileSpeed
	local position = origin
	local travelled = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = velocity * dt
		local hit = workspace:Raycast(position, step, params)
		velocity -= Vector3.new(0, t.ProjectileGravity * dt, 0)
		travelled += step.Magnitude
		if hit or travelled > gun.Range then
			if connection then
				connection:Disconnect()
			end
			round:Destroy()
			explode(player, if hit then hit.Position else position + step, gun.BlastRadius or 8, damage, shooterId)
			return
		end
		position += step
		round.CFrame = CFrame.new(position)
	end)
end

-- Throwables (Landon, 2026-11-08: Fire throws the held one) ------------------------------------

local THROWN_COLOURS: { [string]: Color3 } = {
	FragGrenade = Color3.fromRGB(96, 104, 66),
	Flare = Color3.fromRGB(232, 92, 59),
	FoamGrenade = Color3.fromRGB(236, 232, 218),
	ShockMine = Color3.fromRGB(230, 182, 46),
}

local function thrownPart(itemId: string): BasePart
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local item = Config.Find("Items", itemId)
	local template = folder and item and item.Asset and folder:FindFirstChild(item.Asset)
	local primary = template and template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true)
	local part: BasePart
	if primary then
		part = (primary :: BasePart):Clone()
		for _, child in part:GetChildren() do
			if not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
	else -- graybox until A2 brings the model
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(0.7, 0.7, 0.7)
		ball.Color = THROWN_COLOURS[itemId] or Color3.fromRGB(200, 200, 200)
		ball.Material = if itemId == "Flare" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part = ball
	end
	part.Name = `Thrown_{itemId}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

local function burst(at: Vector3, colour: Color3, count: number, speed: number)
	local holder = Instance.new("Part")
	holder.Name = "Burst"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(count)
	Debris:AddItem(holder, 2)
end

local function placeMine(player: Player, at: Vector3, throwable: { [string]: any })
	local t = Combat.Tuning()
	local mine = thrownPart("ShockMine")
	mine.Name = "ShockMine"
	mine.Position = at + Vector3.new(0, mine.Size.Y / 2, 0) -- sitting on the ground, whatever its size
	mine:SetAttribute("Owner", player.UserId)
	mine.Parent = workspace
	local armedAt = os.clock() + t.MineArmSeconds
	local endsAt = os.clock() + t.MineLifetimeSeconds
	task.spawn(function()
		while mine.Parent and os.clock() < endsAt do
			task.wait(0.2)
			if os.clock() >= armedAt then
				local hit = {}
				for _, c in combat:All("Monsters") do
					if (c.Root.Position - mine.Position).Magnitude - c.Reach <= throwable.Radius then
						table.insert(hit, c)
					end
				end
				if #hit > 0 then
					for _, c in hit do
						c.Model:SetAttribute("StunnedUntil", now() + (throwable.StunSeconds or 2))
					end
					burst(mine.Position, Color3.fromRGB(120, 200, 255), 40, 18)
					break
				end
			end
		end
		mine:Destroy()
	end)
end

local function landed(player: Player, itemId: string, throwable: { [string]: any }, at: Vector3)
	local attacker = combat:PlayerCombatant(player)
	local shooterId = if attacker then attacker.Id else `P{player.UserId}`
	if itemId == "ShockMine" or throwable.Trap then
		placeMine(player, at, throwable)
	elseif throwable.Damage and throwable.Damage > 0 then
		explode(player, at, throwable.Radius, throwable.Damage, shooterId)
	elseif throwable.LightSeconds then
		local flare = thrownPart("Flare")
		flare.Name = "Flare"
		flare.Position = at + Vector3.new(0, flare.Size.Y / 2, 0)
		flare:SetAttribute("Radius", throwable.Radius)
		flare:SetAttribute("RevealsHidden", throwable.RevealsHidden == true)
		local light = Instance.new("PointLight")
		light.Range = math.min(throwable.Radius, 60)
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 128, 84)
		light.Shadows = true
		light.Parent = flare
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(Color3.fromRGB(255, 150, 90))
		sparks.LightEmission = 1
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Lifetime = NumberRange.new(0.3, 0.7)
		sparks.Speed = NumberRange.new(4, 9)
		sparks.SpreadAngle = Vector2.new(30, 30)
		sparks.Rate = 40
		sparks.Parent = flare
		flare.Parent = workspace
		Debris:AddItem(flare, throwable.LightSeconds)
	elseif throwable.Extinguishes then
		burst(at, Color3.fromRGB(240, 240, 232), 90, 22)
		WeaponService.Foamed:Fire(at, throwable.Radius, player)
	end
end

local function throwObject(player: Player, origin: Vector3, direction: Vector3, itemId: string, throwable: { [string]: any })
	local t = Combat.Tuning()
	local thrown = thrownPart(itemId)
	thrown.CFrame = CFrame.new(origin)
	thrown.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = bodies()
	local velocity = direction.Unit * t.ThrowSpeed
	local position = origin
	local flown = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt)
		local step = velocity * dt
		local hit = workspace:Raycast(position, step, params)
		velocity -= Vector3.new(0, t.ThrowGravity * dt, 0)
		flown += dt
		if hit or flown > 6 then
			if connection then
				connection:Disconnect()
			end
			thrown:Destroy()
			local at = if hit then hit.Position + hit.Normal * 0.2 else position
			local ok, err = pcall(landed, player, itemId, throwable, at)
			if not ok then
				log:Warn("%s landed badly: %s", itemId, tostring(err))
			end
			return
		end
		position += step
		thrown.CFrame = CFrame.new(position) * CFrame.Angles(flown * 9, flown * 5, 0)
	end)
end

local function onThrow(player: Player, slot: number, origin: Vector3, aim: Vector3)
	local state = loadouts[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not root or not handsFree(player) or state.Selected ~= slot or now() < state.SwingEndsAt then
		return
	end
	local held = state.Slots[slot]
	local item = held and Config.Find("Items", held.Item)
	if not held or not item or item.Kind ~= "Throwable" or not item.Throwable or (held.Count or 0) <= 0 then
		return
	end
	local t = Combat.Tuning()
	if os.clock() - state.LastThrowAt < t.ThrowCooldownSeconds * (1 - t.RateTolerance) then
		return
	end
	if (origin - root.Position).Magnitude > t.OriginTolerance or aim.Magnitude < 0.5 then
		return
	end
	state.LastThrowAt = os.clock()
	held.Count = (held.Count or 1) - 1
	local itemId = held.Item
	if held.Count <= 0 then
		state.Slots[slot] = nil
	end
	publish(player, state)
	if not state.Slots[slot] then
		refreshHeld(player, state)
	end
	throwObject(player, origin, aim, itemId, item.Throwable)
end

local function onFire(player: Player, slot: number, shot: number, origin: Vector3, aim: Vector3, time: number, claims: { any })
	local state = loadouts[player]
	local shooter = combat:PlayerCombatant(player)
	if not state or not shooter or not handsFree(player) then
		return
	end
	local held = state.Slots[slot]
	local gun = if held then Combat.Gun(held.Item) else nil
	if not held or not gun or state.Selected ~= slot then
		return
	end
	local t = Combat.Tuning()
	if shot ~= state.NextShot then
		player:SetAttribute("ShotNext", state.NextShot) -- the client resyncs from this
		return
	end
	local clock = os.clock()
	if now() < state.ReloadEndsAt or (held.Magazine or 0) < 1 then
		return
	end
	if clock - state.LastShotAt < Combat.Interval(held.Item) * (1 - t.RateTolerance) then
		return
	end
	if (origin - shooter.Root.Position).Magnitude > t.OriginTolerance or aim.Magnitude < 0.9 then
		return
	end
	held.Magazine = (held.Magazine or 0) - 1
	state.NextShot += 1
	state.LastShotAt = clock
	player:SetAttribute(`Mag{slot}`, held.Magazine)
	player:SetAttribute("ShotNext", state.NextShot)

	local damage = Combat.Damage(held.Item, held.Rarity)
	local serverNow = now()
	local from = math.clamp(time, serverNow - t.LagSeconds, serverNow) - 0.05
	local ignore = bodies()

	if gun.Projectile then
		launch(player, origin, aim, gun, damage, shooter.Id)
		return
	end
	if gun.Cone then
		for _, c in combat:All("Monsters") do
			if Combat.InCone(origin, aim, c.Root.Position, gun.Range, gun.SpreadDegrees, c.Reach)
				and not blocked(origin, c.Root.Position, ignore) then
				local amount, how = modified(c, damage, nil, "burned", player)
				local done = combat:Damage(c.Id, amount, shooter.Id, how)
				if done > 0 then
					confirm(player, c.Id, done, c.Root.Position, how)
				end
			end
		end
		return
	end
	-- Steady Shot (Prompt 20): this shot may pierce and crit
	local bonus: { Pierce: boolean?, Crit: number? }? = nil
	local hook = shotHook
	if hook then
		local ok, got = pcall(hook, player, held.Item)
		if ok and type(got) == "table" then
			bonus = got
		elseif not ok then
			log:Warn("shot hook: %s", tostring(got))
		end
	end
	local crit = if bonus and type(bonus.Crit) == "number" and bonus.Crit > 1 then bonus.Crit else nil
	local hitOnce: { [string]: boolean } = {}
	local function land(target: any, point: Vector3, scale: number)
		local kind = if crit then "crit" else "shot"
		local amount, how = modified(target, damage * scale * (crit or 1), point, kind, player)
		local done = combat:Damage(target.Id, amount, shooter.Id, how)
		if done > 0 then
			confirm(player, target.Id, done, point, how, kind)
		end
		hitOnce[target.Id] = true
	end
	local pellets = Combat.Spread(Combat.ShotSeed(state.Salt, shot), aim, held.Item)
	local used: { [number]: boolean } = {}
	for _, claim in claims do
		local direction = pellets[claim.Pellet]
		local target = combat:Get(claim.Id)
		if direction and not used[claim.Pellet] and target and target.Team == "Monsters" and target.State == "Alive" then
			used[claim.Pellet] = true
			local ok, why = Combat.CheckHit(origin, direction, claim.Point, gun.Range, target.History, from, serverNow, target.Reach)
			if ok and blocked(origin, claim.Point, ignore) then
				ok, why = false, "the line of sight is blocked"
			end
			if ok then
				land(target, claim.Point, 1)
				-- an arc jumps on to the nearest monsters (the Arc Rifle; the Mad Scientist's level 2)
				local chains = math.max(gun.ChainTargets or 0, if (gun.ChainTargets or 0) > 0
					then Modifiers.PlayerValue(player, "ArcChainTargets") or 0 else 0)
				if chains > 0 then
					local ct = Config.Get("Tuning", "Classes")
					local from_ = target.Root.Position
					local scale = 1
					for _ = 1, chains do
						local best, bestDistance = nil, ct.ArcChainRange
						for _, c in combat:All("Monsters") do
							if not hitOnce[c.Id] and c.State == "Alive" then
								local d = (c.Root.Position - from_).Magnitude - c.Reach
								if d <= bestDistance and not blocked(from_, c.Root.Position, ignore) then
									best, bestDistance = c, d
								end
							end
						end
						if not best then
							break
						end
						scale *= ct.ArcChainFalloff
						local zapFrom = from_
						from_ = best.Root.Position
						land(best, from_, scale)
						Remotes.FireAllClients("ArcZap", zapFrom, from_)
					end
				end
			else
				log:Debug("%s: a hit on %s refused: %s", player.Name, claim.Id, tostring(why))
			end
		end
	end
	-- a piercing shot hits everything on each pellet's line, past the first (the server's own check)
	if bonus and bonus.Pierce then
		for _, direction in pellets do
			local unit = direction.Unit
			for _, c in combat:All("Monsters") do
				if not hitOnce[c.Id] and c.State == "Alive" then
					local off, along = Combat.RayDistance(origin, unit, c.Root.Position)
					if along > 0 and along <= gun.Range and off <= c.Reach + 1 and not blocked(origin, c.Root.Position, ignore) then
						land(c, origin + unit * along, 1)
					end
				end
			end
		end
	end
end

local function onReload(player: Player)
	local state = loadouts[player]
	if not state or not alive(player) then
		return
	end
	local held = state.Slots[state.Selected]
	local gun = if held then Combat.Gun(held.Item) else nil
	if not held or not gun or now() < state.ReloadEndsAt then
		return
	end
	local perShot = gun.AmmoPerShot * (if gun.Cone then Modifiers.PlayerValue(player, "FuelUse") or 1 else 1)
	if (held.Magazine or 0) >= gun.Magazine or state.Carried < perShot then
		return
	end
	state.ReloadToken += 1
	local token = state.ReloadToken
	state.ReloadEndsAt = now() + gun.ReloadSeconds
	player:SetAttribute("ReloadEndsAt", state.ReloadEndsAt)
	task.delay(gun.ReloadSeconds, function()
		if loadouts[player] ~= state or state.ReloadToken ~= token then
			return
		end
		state.ReloadEndsAt = 0
		player:SetAttribute("ReloadEndsAt", nil)
		if state.Slots[state.Selected] == held then
			-- the Exterminator's level 2: a flame gun's tank costs FuelUse of its ammo (Prompt 20)
			local use = if gun.Cone then Modifiers.PlayerValue(player, "FuelUse") or 1 else 1
			held.Magazine, state.Carried = Combat.Reload(held.Magazine or 0, state.Carried, held.Item, use)
			player:SetAttribute(`Mag{state.Selected}`, held.Magazine)
			player:SetAttribute("CarriedAmmo", state.Carried)
		end
	end)
end

local function cancelReload(player: Player, state: Loadout)
	if state.ReloadEndsAt > 0 then
		state.ReloadToken += 1
		state.ReloadEndsAt = 0
		player:SetAttribute("ReloadEndsAt", nil)
	end
end

-- Tools (Prompt 13) -------------------------------------------------------------------------------

local function stopTool(player: Player, state: Loadout)
	if state.ToolOn then
		state.ToolOn = nil
		player:SetAttribute("ToolInUse", nil)
	end
end

local function onUseTool(player: Player, on: boolean)
	local state = loadouts[player]
	if not state then
		return
	end
	if not on then
		stopTool(player, state)
		return
	end
	local held = state.Slots[state.Selected]
	local item = held and Config.Find("Items", held.Item)
	if not held or not item or item.Kind ~= "Tool" or not handsFree(player) or now() < state.SwingEndsAt then
		return
	end
	state.ToolOn = held.Item
	player:SetAttribute("ToolInUse", held.Item)
end

local function toolLoop()
	local last = os.clock()
	while true do
		task.wait(Config.Get("Tuning", "Repairs").ToolTickSeconds)
		local dt = math.min(os.clock() - last, 0.5)
		last = os.clock()
		for player, state in loadouts do
			local tool = state.ToolOn
			if tool then
				local c = combat:PlayerCombatant(player)
				local held = state.Slots[state.Selected]
				if not c or not alive(player) or not held or held.Item ~= tool then
					stopTool(player, state)
				else
					WeaponService.ToolTick:Fire(player, tool, c.Root.CFrame, dt)
				end
			end
		end
	end
end

-- Bosses (Prompt 15): fn(target, point?, how, player) -> (multiplier, how?) for every hit on a
-- monster: its armour, its weak points, what burns.
function WeaponService:SetHitModifier(fn: ((target: any, point: Vector3?, how: string, player: Player) -> (number, string?))?)
	hitModifier = fn
end

-- Everything a player carries: hotbar items and the melee weapon.
function WeaponService:Items(player: Player): { string }
	local state = loadouts[player]
	local list = {}
	if state then
		for i = 1, SLOTS do
			local held = state.Slots[i]
			if held then
				table.insert(list, held.Item)
			end
		end
		table.insert(list, state.Melee.Item)
	end
	return list
end

function WeaponService:Carries(player: Player, itemId: string): boolean
	return table.find(WeaponService:Items(player), itemId) ~= nil
end

-- Throwables found (Prompt 14: a dug cell's cache): onto the slot that holds the same item, up to
-- ThrowableStack, then into an empty throwable slot. Returns how many the player took.
function WeaponService:GiveThrowable(player: Player, itemId: string, count: number): number
	local state = loadouts[player]
	local item = Config.Find("Items", itemId)
	if not state or not item or item.Kind ~= "Throwable" or count <= 0 then
		return 0
	end
	local cap = Combat.Tuning().ThrowableStack
	local left = count
	for _, pass in { "Same", "Empty" } do
		for slot = 4, SLOTS do
			local held = state.Slots[slot]
			if left > 0 and pass == "Same" and held and held.Item == itemId then
				local room = math.max(cap - (held.Count or 0), 0)
				local add = math.min(room, left)
				held.Count = (held.Count or 0) + add
				left -= add
			elseif left > 0 and pass == "Empty" and not held then
				local add = math.min(cap, left)
				state.Slots[slot] = { Item = itemId, Rarity = "Standard", Count = add }
				left -= add
			end
		end
	end
	if left < count then
		publish(player, state)
		refreshHeld(player, state)
	end
	return count - left
end

local function onSelect(player: Player, slot: number)
	local state = loadouts[player]
	if not state or state.Selected == slot then
		return
	end
	stopTool(player, state)
	cancelReload(player, state)
	state.Selected = slot
	player:SetAttribute("Slot", slot)
	refreshHeld(player, state)
end

-- Melee --------------------------------------------------------------------------------------

local function onSwing(player: Player, heavy: boolean, facing: Vector3)
	local state = loadouts[player]
	local attacker = combat:PlayerCombatant(player)
	if not state or not attacker or not handsFree(player) then
		return
	end
	local clock = now()
	if clock < state.SwingEndsAt - 0.08 then
		return -- still swinging (a little early is network jitter)
	end
	local item = state.Melee.Item
	local p = Config.Get("Tuning", "Player")
	if heavy and not spend(state, player, p.HeavySwingStamina) then
		return
	end
	local step = if heavy then 0 else Combat.NextCombo(state.ComboStep, clock - state.LastSwingAt)
	local windup, length = Combat.Swing(item, heavy)
	state.ComboStep = step
	state.LastSwingAt = clock + length
	state.SwingEndsAt = clock + length
	player:SetAttribute("SwingEndsAt", state.SwingEndsAt)
	cancelReload(player, state)
	stopTool(player, state)
	refreshHeld(player, state)

	local t = Combat.Tuning()
	local melee = Combat.Melee(item) or t.Unarmed
	local damage = Combat.Damage(item, state.Melee.Rarity, heavy)
	task.delay(windup, function()
		if not alive(player) or combat:PlayerCombatant(player) ~= attacker then
			return
		end
		local root = attacker.Root
		local look = Vector3.new(facing.X, 0, facing.Z)
		if look.Magnitude < 0.1 then
			look = root.CFrame.LookVector
		end
		local at = CFrame.lookAt(root.Position, root.Position + look)
		local ignore = bodies()
		for _, c in combat:All("Monsters") do
			if Combat.InArc(at, c.Root.Position, t.MeleeReach + t.MeleeReachTolerance, t.MeleeArcDegrees, c.Reach)
				and not blocked(root.Position, c.Root.Position, ignore) then
				local swingPoint = root.Position + look.Unit * t.MeleeReach * 0.6
				local amount, how = modified(c, damage, swingPoint, if heavy then "smashed" else "struck", player)
				local done = combat:Damage(c.Id, amount, attacker.Id, how)
				if done > 0 then
					confirm(player, c.Id, done, c.Root.Position, how)
					if melee.Knockback and not c.Root.Anchored then
						local push = (c.Root.Position - root.Position) * Vector3.new(1, 0, 1)
						if push.Magnitude > 0.1 then
							c.Root.AssemblyLinearVelocity += push.Unit * melee.Knockback + Vector3.new(0, melee.Knockback * 0.3, 0)
						end
					end
					if melee.StunSeconds then
						c.Model:SetAttribute("StunnedUntil", now() + melee.StunSeconds)
					end
				end
			end
		end
		WeaponService.Swung:Fire(player, at, t.MeleeReach + t.MeleeReachTolerance, t.MeleeArcDegrees, damage, item, heavy)
	end)
	task.delay(length, function()
		if loadouts[player] == state and now() >= state.SwingEndsAt - 0.01 then
			player:SetAttribute("SwingEndsAt", nil)
			refreshHeld(player, state)
		end
	end)
end

-- Dodge, sprint, stamina ------------------------------------------------------------------------

local function onDodge(player: Player, _direction: Vector3)
	local state = loadouts[player]
	local me = combat:PlayerCombatant(player)
	if not state or not me or not handsFree(player) then
		return
	end
	local clock = now()
	if clock < state.DodgeReadyAt then
		return
	end
	local t = Combat.Tuning()
	if not spend(state, player, Config.Get("Tuning", "Player").DodgeStamina) then
		return
	end
	state.DodgeReadyAt = clock + t.DodgeSeconds + t.DodgeCooldownSeconds
	combat:SetInvulnerable(me.Id, clock + t.DodgeInvulnerableSeconds)
end

local function onSprint(player: Player, on: boolean)
	local state = loadouts[player]
	if state then
		state.Sprinting = on and alive(player)
	end
end

local function staminaLoop()
	local dt = 1 / STAMINA_HZ
	while true do
		task.wait(dt)
		local max = staminaMax() -- Field Rations (Prompt 19) raises it
		for player, state in loadouts do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local moving = false
			if root then
				local v = root.AssemblyLinearVelocity
				moving = Vector3.new(v.X, 0, v.Z).Magnitude > MOVING_SPEED
			end
			local sprinting = state.Sprinting and moving and state.Stamina > 0
			local before = state.Stamina
			state.Stamina = Combat.Stamina(state.Stamina, max, dt, sprinting, os.clock() - state.SpentAt)
			if sprinting then
				state.SpentAt = os.clock()
			end
			if state.Stamina <= 0 then
				state.Sprinting = false
			end
			if math.abs(state.Stamina - before) > 1e-6 then
				local shown = player:GetAttribute("Stamina")
				if type(shown) ~= "number" or math.abs(shown - state.Stamina) >= 1 or state.Stamina == 0 or state.Stamina == max then
					player:SetAttribute("Stamina", math.floor(state.Stamina * 10 + 0.5) / 10)
				end
			end
		end
	end
end

-- Restocking at a Workshop or Armory -----------------------------------------------------------

local function restock(player: Player): (number, string?)
	local state = loadouts[player]
	if not state or not alive(player) then
		return 0, "not now"
	end
	local max = Combat.Tuning().CarriedAmmo.Max
	local want = max - state.Carried
	if want <= 0 then
		return 0, "you're full"
	end
	local have = economy:Get("Ammo")
	local take = math.min(want, have)
	if take <= 0 then
		return 0, "the stockpile has no Ammo"
	end
	local ok, why = economy:Spend({ Ammo = take }, `restock for {player.Name}`)
	if not ok then
		return 0, why
	end
	state.Carried += take
	player:SetAttribute("CarriedAmmo", state.Carried)
	return take, nil
end

-- Medkits (Landon, 2026-11-08: the Heal button uses one over MedkitSeconds) -------------------

local function cancelHeal(player: Player, state: Loadout)
	if state.HealEndsAt > 0 then
		state.HealEndsAt = 0
		state.HealToken += 1
		player:SetAttribute("HealEndsAt", nil)
	end
end

local function onMedkit(player: Player)
	local state = loadouts[player]
	local c = combat:PlayerCombatant(player)
	if not state or not c or not handsFree(player) or now() < state.HealEndsAt then
		return
	end
	if state.Medkits <= 0 then
		Remotes.FireClient("Alert", player, "Warning", "NO MEDKITS: TAKE SOME AT THE MEDBAY")
		return
	end
	local health, max = combat:HealthOf(c.Id)
	if health >= max then
		Remotes.FireClient("Alert", player, "Info", "ALREADY AT FULL HEALTH")
		return
	end
	local p = Config.Get("Tuning", "Player")
	state.HealToken += 1
	local token = state.HealToken
	state.HealEndsAt = now() + p.MedkitSeconds
	player:SetAttribute("HealEndsAt", state.HealEndsAt)
	task.delay(p.MedkitSeconds, function()
		if loadouts[player] ~= state or state.HealToken ~= token then
			return
		end
		state.HealEndsAt = 0
		player:SetAttribute("HealEndsAt", nil)
		local me = combat:PlayerCombatant(player)
		if not me or not alive(player) or state.Medkits <= 0 then
			return
		end
		state.Medkits -= 1
		player:SetAttribute("Medkits", state.Medkits)
		combat:Heal(me.Id, p.MedkitHeal)
	end)
end

local function restockMedkits(player: Player): (number, string?)
	local state = loadouts[player]
	if not state or not alive(player) then
		return 0, "not now"
	end
	local want = state.MedkitCap - state.Medkits
	if want <= 0 then
		return 0, "you're full"
	end
	local take = math.min(want, economy:Get("Medkits"))
	if take <= 0 then
		return 0, "the stockpile has no Medkits"
	end
	local ok, why = economy:Spend({ Medkits = take }, `Medkits for {player.Name}`)
	if not ok then
		return 0, why
	end
	state.Medkits += take
	player:SetAttribute("Medkits", state.Medkits)
	return take, nil
end

local function syncRestockPoints()
	local root = grid:Root()
	if not root then
		return
	end
	local folder = restockFolder
	if not folder or folder.Parent == nil then
		folder = Instance.new("Folder")
		folder.Name = "Restock"
		folder.Parent = root
		restockFolder = folder
	end
	local wanted: { [string]: Vector3 } = {}
	local kinds: { [string]: string } = {}
	for _, roomType in { "Workshop", "Armory", "Medbay" } do
		for _, room in grid:RoomsOfType(roomType) do
			local model = grid:RoomModel(room.Id)
			local medbay = roomType == "Medbay"
			local socket = model and model:FindFirstChild(if medbay then "MedkitCabinet" else "Restock", true)
			wanted[room.Id] = if socket and socket:IsA("Attachment")
				then socket.WorldPosition
				else Grid.CellPosition(room.Floor, room.Column) + (if medbay then Vector3.new(-5, 3, 2) else Vector3.new(0, 3, 2))
			kinds[room.Id] = if medbay then "RestockMedkits" else "Restock"
		end
	end
	for _, point in (folder :: Folder):GetChildren() do
		local roomId = point:GetAttribute("RoomId")
		if type(roomId) ~= "string" or not wanted[roomId] or point:GetAttribute("Kind") ~= kinds[roomId] then
			point:Destroy()
		end
	end
	for roomId, position in wanted do
		local point = (folder :: Folder):FindFirstChild(roomId)
		if not point then
			local part = Instance.new("Part")
			part.Name = roomId
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part:SetAttribute("RoomId", roomId)
			local kind = kinds[roomId]
			part:SetAttribute("Kind", kind)
			local medkits = kind == "RestockMedkits"
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "RestockPrompt"
			prompt.ActionText = if medkits then "Take Medkits" else "Restock ammo"
			local room = grid:Room(roomId)
			prompt.ObjectText = if room then Config.Get("Rooms", room.Type).Name else "Ammo"
			prompt.HoldDuration = Combat.Tuning().RestockSeconds
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("Kind", kind)
			prompt.Triggered:Connect(function(player: Player)
				local took, why = (if medkits then restockMedkits else restock)(player)
				local what = if medkits then (if took == 1 then "MEDKIT" else "MEDKITS") else "AMMO"
				Remotes.FireClient("Alert", player, if took > 0 then "Info" else "Warning",
					if took > 0 then `TOOK {took} {what} FROM THE STOCKPILE` else `CAN'T RESTOCK: {string.upper(why or "")}`)
			end)
			prompt.Parent = part
			part.Parent = folder
			point = part
		end
		(point :: BasePart).Position = position
	end
end

-- Lifecycle --------------------------------------------------------------------------------------

local function describe(player: Player): string
	local state = loadouts[player]
	if not state then
		return "no loadout"
	end
	local lines = { `{player.Name}: {state.Class}, slot {state.Selected}, carried {state.Carried}, Medkits {state.Medkits}/{state.MedkitCap}, stamina {math.floor(state.Stamina)}` }
	for i = 1, SLOTS do
		local held = state.Slots[i]
		if held then
			table.insert(lines, `  {i}: {held.Item} ({held.Rarity}){if held.Magazine then ` {held.Magazine} loaded` else ""}{if held.Count then ` x{held.Count}` else ""}`)
		end
	end
	table.insert(lines, `  melee: {state.Melee.Item}`)
	return table.concat(lines, "\n")
end

-- Shows the right thing in the player's hands again (after Carrying changes: Prompt 16).
function WeaponService:RefreshHeld(player: Player)
	local state = loadouts[player]
	if state then
		stopTool(player, state)
		cancelReload(player, state)
		refreshHeld(player, state)
	end
end

function WeaponService:Loadout(player: Player): Loadout?
	return loadouts[player]
end

-- Draft cards' team modifiers (Prompt 19): WeaponRarityUp raises every player's guns and melee
-- weapon now (and kits made later); StaminaMult raises max stamina. A nil value clears a source's.
function WeaponService:SetModifier(source: string, key: string, value: number?)
	assert(key == "WeaponRarityUp" or key == "StaminaMult", `WeaponService:SetModifier: {key} isn't a weapon modifier`)
	local before = teamSum("WeaponRarityUp")
	teamMods[key] = teamMods[key] or {}
	teamMods[key][source] = value
	if key == "WeaponRarityUp" then
		local delta = teamSum("WeaponRarityUp") - before
		if delta ~= 0 then
			for player, state in loadouts do
				for i = 1, GUN_SLOTS do
					local held = state.Slots[i]
					if held then
						held.Rarity = raised(held.Rarity, delta)
					end
				end
				if state.Melee.Item ~= Combat.UNARMED then
					state.Melee.Rarity = raised(state.Melee.Rarity, delta)
				end
				publish(player, state)
			end
		end
	else
		local max = staminaMax()
		local base = Config.Get("Tuning", "Player").Stamina
		for player in loadouts do
			player:SetAttribute("StaminaMax", if math.abs(max - base) > 1e-6 then max else nil)
		end
	end
end

-- Medkits handed to a player now (Prompt 19: Med Cache), on top of what they carry.
function WeaponService:AddMedkits(player: Player, count: number): number
	local state = loadouts[player]
	if not state or count <= 0 then
		return 0
	end
	state.Medkits += count
	publish(player, state)
	return count
end

-- The class kit (Prompt 20: ClassService, from the run record or /dev class): a fresh loadout of
-- the class at its level, keeping the carried ammo; the Demolitionist's level 2 adds Frag Grenades.
function WeaponService:SetClass(player: Player, classId: string, level: number?)
	local old = loadouts[player]
	local state = newLoadout(player, classId, if old then old.Carried else nil, level)
	if old then
		-- the shot count carries on: the client only ever catches up to a higher one (playtest,
		-- Prompt 20: a class change set it back to 1 and every later shot was refused)
		state.Salt, state.NextShot = old.Salt, old.NextShot
		player:SetAttribute("ShotSalt", state.Salt)
		player:SetAttribute("ShotNext", state.NextShot)
	end
	local extra = math.floor(Modifiers.ClassValue(classId, "ExtraFragGrenades", level) or 0)
	if extra > 0 then
		WeaponService:GiveThrowable(player, "FragGrenade", extra)
	end
	refreshHeld(player, state)
end

function WeaponService:AddHitModifier(name: string, fn: (any, Vector3?, string, Player) -> number)
	for i, entry in hitModifiers do
		if entry.Name == name then
			table.remove(hitModifiers, i)
			break
		end
	end
	table.insert(hitModifiers, { Name = name, Fn = fn })
end

function WeaponService:SetShotHook(fn: ((Player, string) -> any)?)
	shotHook = fn
end

-- A player's explosion (Prompt 20: the Breaching Charge): their explosive modifiers apply.
function WeaponService:Explode(player: Player, at: Vector3, radius: number, damage: number)
	local attacker = combat:PlayerCombatant(player)
	explode(player, at, radius, damage, if attacker then attacker.Id else `P{player.UserId}`)
end

-- The rarity of each weapon a player holds (guns by slot, then melee): dev and tests.
function WeaponService:Rarities(player: Player): { string }
	local state = loadouts[player]
	if not state then
		return {}
	end
	local out = {}
	for i = 1, GUN_SLOTS do
		local held = state.Slots[i]
		if held then
			table.insert(out, `{held.Item}:{held.Rarity}`)
		end
	end
	table.insert(out, `{state.Melee.Item}:{state.Melee.Rarity}`)
	return out
end

function WeaponService:Init(registry)
	combat = registry.CombatService
	economy = registry.EconomyService
	grid = registry.BunkerGrid
	dev = registry.DevService

	dev:Register("loadout", {
		Description = "Your loadout: class, hotbar, magazines, carried ammo and stamina.",
		Usage = "loadout",
		Run = function(player): string?
			return if player then describe(player) else "players only"
		end,
	})
	dev:Register("give", {
		Description = "Put an item in a hotbar slot (guns 1-2, tool 3, throwables 4-5) or as the melee weapon.",
		Usage = "give <ItemId> [slot|melee] [rarity] [count]",
		Run = function(player, args): string?
			local state = player and loadouts[player]
			if not player or not state then
				return "players only"
			end
			local itemId = tostring(args[1] or "")
			local item = Config.Find("Items", itemId)
			if not item then
				return `no item {itemId}`
			end
			local rarity = if Config.Find("ItemRarities", args[3]) then tostring(args[3]) else "Standard"
			if item.Kind == "Melee" or args[2] == "melee" then
				state.Melee = { Item = itemId, Rarity = rarity }
			else
				local slot = tonumber(args[2]) or (if item.Kind == "Gun" then 1 elseif item.Kind == "Tool" then 3 else 4)
				local gun = Combat.Gun(itemId)
				local count = if item.Kind == "Throwable"
					then math.clamp(math.floor(tonumber(args[4]) or Combat.Tuning().ThrowableStack), 1, 99)
					else nil
				state.Slots[slot] = { Item = itemId, Rarity = rarity, Magazine = if gun then gun.Magazine else nil, Count = count }
			end
			publish(player, state)
			refreshHeld(player, state)
			return describe(player)
		end,
	})
	dev:Register("ammo", {
		Description = "Set your carried ammo.",
		Usage = "ammo [amount]",
		Run = function(player, args): string?
			local state = player and loadouts[player]
			if not player or not state then
				return "players only"
			end
			state.Carried = math.max(0, math.floor(tonumber(args[1]) or Combat.Tuning().CarriedAmmo.Max))
			player:SetAttribute("CarriedAmmo", state.Carried)
			return describe(player)
		end,
	})
	dev:Register("medkits", {
		Description = "Set your carried Medkits.",
		Usage = "medkits [count]",
		Run = function(player, args): string?
			local state = player and loadouts[player]
			if not player or not state then
				return "players only"
			end
			state.Medkits = math.clamp(math.floor(tonumber(args[1]) or state.MedkitCap), 0, 99)
			player:SetAttribute("Medkits", state.Medkits)
			return describe(player)
		end,
	})
	dev:Register("stamina", {
		Description = "Set your stamina.",
		Usage = "stamina [amount]",
		Run = function(player, args): string?
			local state = player and loadouts[player]
			if not player or not state then
				return "players only"
			end
			state.Stamina = math.clamp(tonumber(args[1]) or 100, 0, staminaMax())
			player:SetAttribute("Stamina", state.Stamina)
			return describe(player)
		end,
	})
end

function WeaponService:Start()
	local function joined(player: Player)
		player.CharacterAdded:Connect(function()
			local state = loadouts[player] or newLoadout(player, "Survivor")
			state.SwingEndsAt = 0
			state.Sprinting = false
			cancelReload(player, state)
			cancelHeal(player, state)
			stopTool(player, state)
			task.defer(function()
				if player.Character then
					player.Character:WaitForChild("RightHand", 10)
					refreshHeld(player, state)
				end
			end)
		end)
		if player.Character then
			local state = loadouts[player] or newLoadout(player, "Survivor")
			task.defer(refreshHeld, player, state)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		loadouts[player] = nil
	end)

	Remotes.OnServer("SelectSlot", onSelect)
	Remotes.OnServer("FireWeapon", onFire)
	Remotes.OnServer("ReloadWeapon", onReload)
	Remotes.OnServer("MeleeSwing", onSwing)
	Remotes.OnServer("Dodge", onDodge)
	Remotes.OnServer("Sprint", onSprint)
	Remotes.OnServer("ThrowItem", onThrow)
	Remotes.OnServer("UseMedkit", onMedkit)
	Remotes.OnServer("UseTool", onUseTool)

	combat.Downed:Connect(function(id: string)
		local c = combat:Get(id)
		local player = c and c.Player
		local state = player and loadouts[player]
		if player and state then
			state.Sprinting = false
			cancelReload(player, state)
			cancelHeal(player, state)
			stopTool(player, state)
		end
	end)

	grid.RoomChanged:Connect(function()
		task.defer(syncRestockPoints)
	end)
	syncRestockPoints()
	task.spawn(staminaLoop)
	task.spawn(toolLoop)
	log:Info("weapons ready: the Survivor's kit by default, carried ammo %d", Combat.Tuning().CarriedAmmo.Start)
end

return WeaponService
