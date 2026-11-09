--!strict
--[[
	CombatService: everyone who can be hurt, in one place (bible Section 23: one loop for every
	combatant: players, armed residents, monsters, turrets, bosses). Run place only; Prompt 11.

	Combatants
	* Register(model, spec) -> id. A combatant has a team ("Survivors" or "Monsters"), health,
	  a reach (how far its body goes from its root) and a second of position history at
	  Tuning.Combat.HistoryHz, for Section 23's checks against where a target was over the last
	  250 ms. Get(id), OfInstance(part), All(team?), History(id).
	* Players register when they spawn and residents' bodies when ResidentBrain makes them
	  (their health stays with ResidentService). Monsters come with Prompt 12; until then a dev
	  dummy stands in.
	* Damage(targetId, amount, sourceId?, how?): no friendly fire (Section 9), and a dodge's
	  invulnerable moment takes nothing. Heal(id, amount).
	* Signals: Damaged(id, amount, sourceId?, how?), Downed(id), Revived(id, byUserId?),
	  Died(id). Dead monsters dissolve into glowing dust (Section 3).

	Players (Section 9)
	* Health: Tuning.Player.Health (classes add theirs with Prompt 20). Roblox's own
	  regeneration is removed: health comes back only by healing.
	* At 0 health a player is Downed for DownedSeconds and crawls (CrawlSpeed). Teammates see a
	  revive prompt: hold Interact for ReviveSeconds (the Medic's 1 s comes with Prompt 20). A
	  revived player gets up with ReviveHealthFraction of their health.
	* Not revived in time: dead. RespawnSeconds later they come back at the nearest working
	  Medbay (not wrecked, not dark), or in the Blast Door hall when no Medbay works.
	* Each player's life shows as attributes on the Player: Life ("Alive", "Downed", "Dead"),
	  LifeEndsAt (when the downed or respawn wait ends, server time) and InvulnerableUntil.
	* A player's Humanoid never reaches 0 health: the hit that would take it there leaves it at
	  1 and downs the player (at 0 the server kills a Humanoid whatever the client does). The
	  client also turns the Dead state off for its own character, and Died is still handled as a
	  fallback.

	Dev: combat, hurt, heal, down, revive, kill, dummy, dummy.attack, dummy.clear.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Combat = require(Shared.Rules.Combat)
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("CombatService")

export type Team = "Survivors" | "Monsters"
export type Kind = "Player" | "Resident" | "Monster"
export type Combatant = {
	Id: string,
	Kind: Kind,
	Team: Team,
	Model: Model,
	Root: BasePart,
	Reach: number,
	Health: number, -- monsters' own; players and residents keep theirs where they live
	MaxHealth: number,
	State: "Alive" | "Downed" | "Dead",
	History: { Combat.Sample },
	InvulnerableUntil: number,
	Player: Player?,
	ResidentId: string?,
	MonsterType: string?,
}
export type Spec = {
	Kind: Kind,
	Team: Team,
	Root: BasePart?,
	Health: number?,
	Player: Player?,
	ResidentId: string?,
	MonsterType: string?,
	Id: string?,
}

local CombatService = {
	Name = "CombatService",
	Dependencies = { "SessionService", "BunkerGrid", "PowerService", "ResidentService", "DevService" },
	Damaged = Signal.new() :: Signal.Signal<string, number, string?, string?>,
	Downed = Signal.new() :: Signal.Signal<string>,
	Revived = Signal.new() :: Signal.Signal<string, number?>,
	Died = Signal.new() :: Signal.Signal<string>,
}

local grid: any = nil
local power: any = nil
local residents: any = nil
local dev: any = nil

local combatants: { [string]: Combatant } = {}
local byModel: { [Model]: string } = {}
local monsterCount = 0
local fellAt: { [Player]: Vector3 } = {} -- where a player went down, for the respawn choice
local respawnAt: { [Player]: CFrame } = {}
local lifeTask: { [Player]: thread } = {}
local dummyAttack = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function playerId(player: Player): string
	return `P{player.UserId}`
end

-- The model's reach: half its widest side, so a hit anywhere on its body is near its root.
local function reachOf(model: Model): number
	local _, size = model:GetBoundingBox()
	return math.max(size.X, size.Y, size.Z) / 2
end

local function setLife(player: Player, life: string, endsAt: number?)
	player:SetAttribute("Life", life)
	player:SetAttribute("LifeEndsAt", endsAt)
end

local function humanoidOf(c: Combatant): Humanoid?
	return c.Model:FindFirstChildOfClass("Humanoid")
end

-- Combatants -----------------------------------------------------------------------------

function CombatService:Register(model: Model, spec: Spec): string?
	local root = spec.Root or model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		log:Warn("%s has no root part to register", model:GetFullName())
		return nil
	end
	local id = spec.Id
	if not id then
		monsterCount += 1
		id = `M{monsterCount}`
	end
	local health = spec.Health or 100
	local record: Combatant = {
		Id = id :: string,
		Kind = spec.Kind,
		Team = spec.Team,
		Model = model,
		Root = root,
		Reach = reachOf(model),
		Health = health,
		MaxHealth = health,
		State = "Alive",
		History = {},
		InvulnerableUntil = 0,
		Player = spec.Player,
		ResidentId = spec.ResidentId,
		MonsterType = spec.MonsterType,
	}
	combatants[record.Id] = record
	byModel[model] = record.Id
	model:SetAttribute("CombatantId", record.Id)
	model:SetAttribute("Team", record.Team)
	if record.Kind == "Monster" then
		model:SetAttribute("Health", health)
		model:SetAttribute("MaxHealth", health)
	end
	return record.Id
end

function CombatService:Unregister(id: string)
	local record = combatants[id]
	if not record then
		return
	end
	combatants[id] = nil
	if byModel[record.Model] == id then
		byModel[record.Model] = nil
	end
end

function CombatService:Get(id: string): Combatant?
	return combatants[id]
end

-- The combatant a part belongs to (its model, or a model above it).
function CombatService:OfInstance(instance: Instance?): Combatant?
	local node = instance
	while node and node ~= workspace do
		if node:IsA("Model") then
			local id = byModel[node]
			if id then
				return combatants[id]
			end
		end
		node = node.Parent
	end
	return nil
end

function CombatService:All(team: Team?): { Combatant }
	local list = {}
	for _, c in combatants do
		if team == nil or c.Team == team then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

function CombatService:History(id: string): { Combat.Sample }
	local record = combatants[id]
	return if record then record.History else {}
end

function CombatService:PlayerCombatant(player: Player): Combatant?
	return combatants[playerId(player)]
end

function CombatService:SetInvulnerable(id: string, untilTime: number)
	local record = combatants[id]
	if record then
		record.InvulnerableUntil = math.max(record.InvulnerableUntil, untilTime)
		if record.Player then
			record.Player:SetAttribute("InvulnerableUntil", record.InvulnerableUntil)
		end
	end
end

function CombatService:HealthOf(id: string): (number, number)
	local record = combatants[id]
	if not record then
		return 0, 0
	end
	if record.Kind == "Player" then
		local h = humanoidOf(record)
		return if h then h.Health else 0, if h then h.MaxHealth else 0
	elseif record.Kind == "Resident" and record.ResidentId then
		local resident = residents:Get(record.ResidentId)
		return if resident then resident.Health else 0, if resident then resident.MaxHealth else 0
	end
	return record.Health, record.MaxHealth
end

-- Monsters' death: glowing dust, then gone (Section 3) --------------------------------------

local function dissolve(model: Model)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if root then
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "Dust"
		dust.Color = ColorSequence.new(Color3.fromRGB(124, 255, 155), Color3.fromRGB(46, 120, 70))
		dust.LightEmission = 0.9
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.6, 1.2)
		dust.Speed = NumberRange.new(2, 6)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Acceleration = Vector3.new(0, 4, 0)
		dust.Rate = 0
		dust.Parent = root
		dust:Emit(60)
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.Anchored = true
			TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		elseif part:IsA("Decal") or part:IsA("Texture") then
			TweenService:Create(part, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.4, function()
		model:Destroy()
	end)
end

-- Players: down, revive, die, respawn ---------------------------------------------------------

local function clearLifeTask(player: Player)
	local running = lifeTask[player]
	lifeTask[player] = nil
	if running and coroutine.status(running) == "suspended" then
		task.cancel(running)
	end
end

local function removePrompt(record: Combatant)
	local prompt = record.Root:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
end

-- The working Medbays' respawn points (Section 9), nearest first is Combat.Nearest's job.
local function respawnPlaces(): { Combat.Place }
	local places = {}
	for _, room in grid:RoomsOfType("Medbay") do
		if not room.Wrecked and not power:IsDark(room.Id) then
			local model = grid:RoomModel(room.Id)
			local respawn = model and model:FindFirstChild("Respawn", true)
			local position = if respawn and respawn:IsA("Attachment")
				then respawn.WorldPosition
				else Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, 0, 4)
			table.insert(places, { Id = room.Id, Position = position })
		end
	end
	return places
end

-- The Blast Door hall, where players come back when no Medbay works.
local function blastDoorHall(): Vector3
	local doors = grid:RoomsOfType("BlastDoor")
	local door = doors[1]
	if door then
		local column = door.Column + (door.Span - 1) / 2
		return Grid.CellPosition(door.Floor, column) + Vector3.new(0, 0, 8)
	end
	return Grid.CellPosition(1, 0) + Vector3.new(0, 0, 8)
end

local function respawnPoint(from: Vector3?): (CFrame, string)
	local place = Combat.Nearest(from or Vector3.zero, respawnPlaces())
	local position = if place then place.Position else blastDoorHall()
	return CFrame.new(position + Vector3.new(0, 3, 0)), if place then `Medbay {place.Id}` else "the Blast Door hall"
end

local function die(player: Player, why: string)
	local record = CombatService:PlayerCombatant(player)
	clearLifeTask(player)
	if record then
		fellAt[player] = record.Root.Position
		removePrompt(record)
		record.State = "Dead"
		CombatService:Unregister(record.Id)
		CombatService.Died:Fire(record.Id)
	end
	local seconds = Config.Get("Tuning", "Player").RespawnSeconds
	setLife(player, "Dead", now() + seconds)
	log:Info("%s died (%s); back in %d s", player.Name, why, seconds)
	local character = player.Character
	if character then
		character:Destroy()
	end
	lifeTask[player] = task.delay(seconds, function()
		lifeTask[player] = nil
		if player.Parent ~= Players then
			return
		end
		local cframe, where = respawnPoint(fellAt[player])
		respawnAt[player] = cframe
		fellAt[player] = nil
		log:Info("%s respawns at %s", player.Name, where)
		player:LoadCharacter()
	end)
end

function CombatService:Revive(player: Player, by: Player?): (boolean, string?)
	local record = CombatService:PlayerCombatant(player)
	if not record or record.State ~= "Downed" then
		return false, "not downed"
	end
	local h = humanoidOf(record)
	if not h then
		return false, "no character"
	end
	clearLifeTask(player)
	removePrompt(record)
	record.State = "Alive"
	local fraction = Combat.Tuning().ReviveHealthFraction
	h.Health = math.max(1, math.floor(h.MaxHealth * fraction + 0.5))
	setLife(player, "Alive", nil)
	CombatService.Revived:Fire(record.Id, if by then by.UserId else nil)
	log:Info("%s was revived%s", player.Name, if by then ` by {by.Name}` else "")
	return true, nil
end

local function down(player: Player, record: Combatant)
	if record.State ~= "Alive" then
		return
	end
	local p = Config.Get("Tuning", "Player")
	record.State = "Downed"
	setLife(player, "Downed", now() + p.DownedSeconds)
	CombatService.Downed:Fire(record.Id)
	log:Info("%s is down", player.Name)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = p.ReviveSeconds
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Owner", player.UserId)
	prompt:SetAttribute("Kind", "Revive")
	prompt.Triggered:Connect(function(by: Player)
		if by == player then
			return
		end
		local helper = CombatService:PlayerCombatant(by)
		if not helper or helper.State ~= "Alive" then
			return
		end
		CombatService:Revive(player, by)
	end)
	prompt.Parent = record.Root

	clearLifeTask(player)
	lifeTask[player] = task.delay(p.DownedSeconds, function()
		lifeTask[player] = nil
		if record.State == "Downed" then
			die(player, "not revived in time")
		end
	end)
end

local function watchCharacter(player: Player, character: Model)
	local h = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not root or character.Parent == nil then
		return
	end
	-- No regeneration: Roblox's Health script goes (Section 9: health comes back by healing)
	local function dropRegen(child: Instance)
		if child.Name == "Health" and child:IsA("Script") then
			child:Destroy()
		end
	end
	local regen = character:FindFirstChild("Health")
	if regen then
		dropRegen(regen)
	end
	character.ChildAdded:Connect(dropRegen)

	local p = Config.Get("Tuning", "Player")
	h.BreakJointsOnDeath = false
	h.RequiresNeck = false
	h.MaxHealth = p.Health
	h.Health = p.Health
	local spawnAt = respawnAt[player]
	respawnAt[player] = nil
	if spawnAt then
		task.defer(function()
			if character.Parent then
				character:PivotTo(spawnAt)
			end
		end)
	end

	local old = CombatService:PlayerCombatant(player)
	if old then
		CombatService:Unregister(old.Id)
	end
	local id = CombatService:Register(character, {
		Kind = "Player",
		Team = "Survivors",
		Root = root,
		Health = p.Health,
		Player = player,
		Id = playerId(player),
	})
	if not id then
		return
	end
	local record = combatants[id]
	setLife(player, "Alive", nil)
	player:SetAttribute("InvulnerableUntil", 0)

	h.HealthChanged:Connect(function(health: number)
		if health <= 0 and record.State == "Alive" and combatants[id] == record then
			down(player, record)
		end
	end)
	h.Died:Connect(function()
		if combatants[id] == record and record.State ~= "Dead" then
			die(player, "the character died")
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil and combatants[id] == record then
			CombatService:Unregister(id)
		end
	end)
end

-- Damage and healing ---------------------------------------------------------------------------

-- Hurts a combatant; returns the damage done (0 for a teammate, an invulnerable dodge, or a
-- combatant already down).
function CombatService:Damage(targetId: string, amount: number, sourceId: string?, how: string?): number
	local target = combatants[targetId]
	if not target or amount <= 0 or target.State ~= "Alive" then
		return 0
	end
	local source = if sourceId then combatants[sourceId] else nil
	if source and source.Team == target.Team then
		return 0 -- no friendly fire (Section 9)
	end
	if now() < target.InvulnerableUntil then
		return 0
	end
	local done = amount
	if target.Kind == "Player" then
		local h = humanoidOf(target)
		if not h then
			return 0
		end
		if h.Health - amount <= 0 then
			-- A player's Humanoid never reaches 0: at 0 the server kills it whatever the client's
			-- states (playtest, Nov 8, 2026). It stays at 1 and the player is Downed instead; the
			-- HUD shows 0 while down (CombatController).
			done = h.Health
			h.Health = 1
			CombatService.Damaged:Fire(targetId, done, sourceId, how)
			if target.Player then
				down(target.Player, target)
			end
			return done
		end
		h.Health -= amount
	elseif target.Kind == "Resident" then
		if target.ResidentId then
			residents:Hurt(target.ResidentId, amount, how or "attacked")
		end
	else
		done = math.min(amount, target.Health)
		target.Health = math.max(target.Health - amount, 0)
		target.Model:SetAttribute("Health", target.Health)
		if target.Health <= 0 then
			target.State = "Dead"
			CombatService:Unregister(target.Id)
			CombatService.Damaged:Fire(targetId, done, sourceId, how)
			CombatService.Died:Fire(targetId)
			dissolve(target.Model)
			return done
		end
	end
	CombatService.Damaged:Fire(targetId, done, sourceId, how)
	return done
end

function CombatService:Heal(id: string, amount: number): number
	local target = combatants[id]
	if not target or target.State ~= "Alive" or amount <= 0 then
		return 0
	end
	if target.Kind == "Player" then
		local h = humanoidOf(target)
		if not h then
			return 0
		end
		local before = h.Health
		h.Health = math.min(h.Health + amount, h.MaxHealth)
		return h.Health - before
	end
	local before = target.Health
	target.Health = math.min(target.Health + amount, target.MaxHealth)
	target.Model:SetAttribute("Health", target.Health)
	return target.Health - before
end

-- Residents' bodies ------------------------------------------------------------------------------

local function watchResidents()
	local bunkerRoot = grid:Root()
	if not bunkerRoot then
		log:Warn("no bunker yet: residents aren't combatants")
		return
	end
	local function attach(folder: Instance)
		if not folder:IsA("Folder") or folder.Name ~= "Residents" then
			return
		end
		local function add(body: Instance)
			if body:IsA("Model") then
				local residentId = body:GetAttribute("ResidentId") or body.Name
				if type(residentId) == "string" and string.match(residentId, "^N%d+$") then
					CombatService:Register(body, { Kind = "Resident", Team = "Survivors", ResidentId = residentId, Id = residentId })
				end
			end
		end
		for _, body in folder:GetChildren() do
			add(body)
		end
		folder.ChildAdded:Connect(add)
		folder.ChildRemoved:Connect(function(body: Instance)
			local id = if body:IsA("Model") then byModel[body] else nil
			if id then
				CombatService:Unregister(id)
			end
		end)
	end
	local existing = bunkerRoot:FindFirstChild("Residents")
	if existing then
		attach(existing)
	end
	bunkerRoot.ChildAdded:Connect(attach)
end

-- History --------------------------------------------------------------------------------------

local function record(t: number, keep: number)
	for _, c in combatants do
		local root = c.Root
		if root.Parent then
			local history = c.History
			table.insert(history, { T = t, P = root.Position })
			while #history > 0 and history[1].T < t - keep do
				table.remove(history, 1)
			end
		end
	end
end

-- Dev: a target dummy until Prompt 12's monsters ----------------------------------------------

local function spawnDummy(player: Player?, monsterId: string, health: number?): (string?, string?)
	player = player or Players:GetPlayers()[1] -- run from Studio's command bar: the first player
	local monster = Config.Find("Monsters", monsterId)
	if not monster then
		return nil, `no monster {monsterId}`
	end
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild(monster.Asset)
	if not (template and template:IsA("Model")) then
		return nil, `no model {monster.Asset} in ServerStorage.Assets.Monsters`
	end
	local model = template:Clone()
	model.Name = `Dummy_{monsterId}`
	local at = CFrame.new(Grid.CellPosition(2, 2) + Vector3.new(0, 0, 6))
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		local spot = root.Position + look * 12
		at = CFrame.lookAt(spot, Vector3.new(root.Position.X, spot.Y, root.Position.Z))
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end
	local primary = model.PrimaryPart
	if primary then
		primary.Anchored = true
	end
	-- stand it on the floor under the spot
	local hit = workspace:Raycast(at.Position + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0))
	local floorY = if hit then hit.Position.Y else at.Position.Y - 3
	model:PivotTo(at)
	local cf, size = model:GetBoundingBox()
	model:PivotTo(at + Vector3.new(0, floorY - (cf.Position.Y - size.Y / 2), 0))
	local holder = workspace:FindFirstChild("Dummies") or Instance.new("Folder")
	holder.Name = "Dummies"
	holder.Parent = workspace
	model.Parent = holder
	local id = CombatService:Register(model, {
		Kind = "Monster",
		Team = "Monsters",
		Health = health or monster.Health,
		MonsterType = monsterId,
	})
	return id, nil
end

local function dummyAttackLoop()
	while true do
		task.wait(0.25)
		if dummyAttack then
			for _, c in combatants do
				if c.Kind == "Monster" and c.State == "Alive" and not c.Model:GetAttribute("Attacking") then
					local monster = Config.Find("Monsters", c.MonsterType)
					if monster then
						-- the nearest standing player in range
						local best, bestDistance = nil, math.huge
						for _, other in combatants do
							if other.Kind == "Player" and other.State == "Alive" then
								local distance = (other.Root.Position - c.Root.Position).Magnitude - c.Reach
								if distance <= monster.Range and distance < bestDistance then
									best, bestDistance = other, distance
								end
							end
						end
						if best then
							local target = best
							c.Model:SetAttribute("Attacking", true)
							task.spawn(function()
								local look = Vector3.new(target.Root.Position.X, c.Root.Position.Y, target.Root.Position.Z)
								if (look - c.Root.Position).Magnitude > 0.1 then
									c.Model:PivotTo(CFrame.lookAt(c.Root.Position, look) * (c.Root.CFrame:Inverse() * c.Model:GetPivot()))
								end
								-- the rig's attack clip (its Anim_Attack attribute, from the art pipeline)
								local animator = c.Model:FindFirstChildWhichIsA("Animator", true)
								local clipId = c.Model:GetAttribute("Anim_Attack")
								local hitAt = 0.7
								if animator and type(clipId) == "string" then
									local clip = Instance.new("Animation")
									clip.AnimationId = clipId
									local ok, track = pcall(function()
										return (animator :: Animator):LoadAnimation(clip)
									end)
									if ok and track then
										track:Play()
									end
								end
								task.wait(hitAt) -- the windup; the hit is checked again when it lands
								if combatants[c.Id] and target.State == "Alive" then
									local distance = (target.Root.Position - c.Root.Position).Magnitude - c.Reach
									if distance <= monster.Range + 1 then
										CombatService:Damage(target.Id, monster.Damage, c.Id, "struck")
									end
								end
								task.wait(math.max(monster.AttackSeconds - hitAt, 0.2))
								if c.Model.Parent then
									c.Model:SetAttribute("Attacking", nil)
								end
							end)
						end
					end
				end
			end
		end
	end
end

-- Lifecycle --------------------------------------------------------------------------------------

local function describe(): string
	local lines = {}
	for _, c in CombatService:All() do
		local health, max = CombatService:HealthOf(c.Id)
		table.insert(lines, string.format("%s %s %s (%s): %d/%d %s, history %d", c.Id, c.Kind, c.Model.Name, c.Team,
			math.ceil(health), math.ceil(max), c.State, #c.History))
	end
	return if #lines > 0 then table.concat(lines, "\n") else "no combatants"
end

local function target(player: Player?, name: any): Player?
	if type(name) == "string" and name ~= "" then
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
				return p
			end
		end
		return nil
	end
	return player
end

function CombatService:Init(registry)
	grid = registry.BunkerGrid
	power = registry.PowerService
	residents = registry.ResidentService
	dev = registry.DevService

	dev:Register("combat", {
		Description = "Every combatant: health, state and position history.",
		Usage = "combat",
		Run = function(): string?
			return describe()
		end,
	})
	dev:Register("hurt", {
		Description = "Hurt a player (you by default), as a monster would.",
		Usage = "hurt [amount] [player]",
		Run = function(player, args): string?
			local who = target(player, args[2])
			local c = who and CombatService:PlayerCombatant(who)
			if not c then
				return "no such player in the fight"
			end
			local done = CombatService:Damage(c.Id, tonumber(args[1]) or 25, nil, "dev")
			local health, max = CombatService:HealthOf(c.Id)
			return `{who and who.Name}: -{done}, {math.ceil(health)}/{max}`
		end,
	})
	dev:Register("heal", {
		Description = "Heal a player (you by default).",
		Usage = "heal [amount] [player]",
		Run = function(player, args): string?
			local who = target(player, args[2])
			local c = who and CombatService:PlayerCombatant(who)
			if not c then
				return "no such player in the fight"
			end
			local done = CombatService:Heal(c.Id, tonumber(args[1]) or 100)
			return `{who and who.Name}: +{done}`
		end,
	})
	dev:Register("down", {
		Description = "Down a player (you by default).",
		Usage = "down [player]",
		Run = function(player, args): string?
			local who = target(player, args[1])
			local c = who and CombatService:PlayerCombatant(who)
			if not c then
				return "no such player in the fight"
			end
			CombatService:Damage(c.Id, 10000, nil, "dev")
			return `{who and who.Name}: {who and who:GetAttribute("Life")}`
		end,
	})
	dev:Register("revive", {
		Description = "Revive a downed player (you by default), as a teammate would.",
		Usage = "revive [player]",
		Run = function(player, args): string?
			local who = target(player, args[1])
			if not who then
				return "no such player"
			end
			local ok, why = CombatService:Revive(who, nil)
			return if ok then `{who.Name} is up` else `can't: {why}`
		end,
	})
	dev:Register("kill", {
		Description = "Skip a downed player's wait: dead now, back after the respawn time.",
		Usage = "kill [player]",
		Run = function(player, args): string?
			local who = target(player, args[1])
			if not who then
				return "no such player"
			end
			die(who, "dev")
			return `{who.Name} is dead`
		end,
	})
	dev:Register("dummy", {
		Description = "A monster that stands still to be hit, in front of you (until Prompt 12's monsters).",
		Usage = "dummy [MonsterId] [health]",
		Run = function(player, args): string?
			local id, why = spawnDummy(player, tostring(args[1] or "HollowMiner"), tonumber(args[2]))
			return if id then `{id} is up` else `can't: {why}`
		end,
	})
	dev:Register("dummy.attack", {
		Description = "Dummies strike the nearest standing player in reach (on or off).",
		Usage = "dummy.attack [on|off]",
		Run = function(_player, args): string?
			dummyAttack = if args[1] == nil then not dummyAttack else args[1] == "on"
			return `dummies attack: {dummyAttack}`
		end,
	})
	dev:Register("dummy.clear", {
		Description = "Remove every dummy.",
		Usage = "dummy.clear",
		Run = function(): string?
			local count = 0
			for _, c in CombatService:All("Monsters") do
				if string.match(c.Model.Name, "^Dummy_") then
					CombatService:Unregister(c.Id)
					c.Model:Destroy()
					count += 1
				end
			end
			return `{count} removed`
		end,
	})
end

function CombatService:Start()
	local t = Combat.Tuning()
	Players.RespawnTime = Config.Get("Tuning", "Player").RespawnSeconds
	local function joined(player: Player)
		setLife(player, "Alive", nil)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		clearLifeTask(player)
		local c = CombatService:PlayerCombatant(player)
		if c then
			CombatService:Unregister(c.Id)
		end
		fellAt[player] = nil
		respawnAt[player] = nil
	end)

	watchResidents()

	local step = 1 / math.max(t.HistoryHz, 1)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= step then
			acc = 0
			record(now(), t.HistorySeconds + 0.2)
		end
	end)
	task.spawn(dummyAttackLoop)
	log:Info("combat ready: players %d health, downed %d s, respawn %d s", Config.Get("Tuning", "Player").Health,
		Config.Get("Tuning", "Player").DownedSeconds, Config.Get("Tuning", "Player").RespawnSeconds)
end

return CombatService
