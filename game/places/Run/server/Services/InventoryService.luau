--!strict
--[[
	InventoryService: what players carry besides their loadout (bible Sections 9, 12 and 13; Run
	place, Prompt 16).

	* Backpacks (Section 9: a 10-slot backpack for loot; Section 12: Scavenger +8, Big Backpack
	  +5 through the BackpackSlots modifier): each player's pack is a Rules.Surface pack, stacks of
	  resources (Tuning.Surface.Stacks to a slot). Give(player, drops) puts loot in: resources into
	  the pack (what doesn't fit comes back as left over), throwables onto the hotbar
	  (WeaponService:GiveThrowable), Clear-Rad pills into the player's pills. The Player attributes
	  PackUsed, PackSlots, Pack ("Scrap:50,Food:8") and ClearRad carry it to the HUD.
	* Hauling (Section 12): loot only counts once dropped at the Blast Door hall or a Storage room.
	  An Unload prompt stands in the hall, 15 studs from the elevator, and in every Storage room: the stockpile takes
	  what it has room for (EconomyService caps) and the rest stays in the pack.
	* A player downed on the surface drops their pack where they fell (Section 9) unless their class
	  keeps it (KeepBackpackWhenDowned): a bag anyone can pick up (what doesn't fit stays in it).
	* Big finds (Section 12: generator parts, cryo pods; carried with both hands, slowly; two
	  carrying together move faster): PlaceFind(kind, at) puts one in workspace.Finds with a Carry
	  prompt. The carrier's hands are busy (the Carrying attribute: WeaponService refuses guns,
	  swings, throws, tools, rolls and Medkits); a teammate within HelpRange can hold Help Carry, and
	  both then walk at TeamCarryWalkMultiplier (the Carriers attribute; each client slows its own
	  character). Put Down drops it, and so does being downed. Unloading delivers it: the handler for
	  its kind (SetDelivery) or else the LootTables entry of that name (Tuning.Surface.BigFindLoot
	  when there is none), straight into the stockpile.
	* Clear-Rad pills (Section 9): up to PillsMax carried; TakePill (SurfaceService takes one when
	  radiation reaches PillUseAt).
	* Monster drops (Section 13: Scrap from monster drops, ore from each band's monsters): a monster's
	  Drops table is rolled when it dies; a kill on the surface or in the Deep goes into the pack of
	  the last player who hit it (only hauled loot counts), a kill in the bunker straight into the
	  stockpile. A player downed in the Deep drops their pack too (Prompt 17).
	* Loot specials (Prompt 17): Give hands a Special to the handler its owner set (SetSpecial:
	  DeepService plays radio logs and pays Glowshard chests); the rest are left over.
	* Blueprints (Prompt 19): DraftService's Blueprint special draws a card and GiveCard puts it in
	  the pack as a stack of its own (the card's id, one a slot). Unloading hands the cards home
	  (CardsHome) for the next draft, like any loot that only counts once hauled.

	CollectBags(player, position, radius) (Prompt 20: Magnet Sweep, the drone) picks up dropped packs nearby.
	Signals: Unloaded(player, delivered: { [resource]: number }), Delivered(player, kind, given),
	CardsHome(player, card ids).
	Dev: pack, pack.add <resource> <n>, pack.clear, pills <n>, find [kind], finds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Loot = require(Shared.Rules.Loot)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Utilities.Signal)
local Surface = require(Shared.Rules.Surface)
local BunkerKit = require(ServerScriptService.Lib.BunkerKit)

local log = Log.new("InventoryService")

local InventoryService = {
	Name = "InventoryService",
	Dependencies = {
		"SessionService", "BunkerGrid", "EconomyService", "CombatService", "WeaponService", "MonsterService", "RunDirector",
		"ResidentService", "DevService",
	},
	Unloaded = Signal.new() :: Signal.Signal<Player, { [string]: number }>,
	Delivered = Signal.new() :: Signal.Signal<Player, string, { Loot.Drop }>,
	CardsHome = Signal.new() :: Signal.Signal<Player, { string }>,
}

-- Loot nothing hands out yet: gear (Prompt 26), recruits (18), the Lamp (placeables). Radio
-- logs, Glowshards (Prompt 17) and blueprints (Prompt 19) go to their handlers (SetSpecial).
local SKIP: { [string]: boolean } = { Gear = true, Recruit = true, Lamp = true }
local HALL_UNLOAD = Vector3.new(15, 0, 1) -- from the Blast Door's Door socket, towards the shaft: far enough from
-- RIDE UP (at the socket) that one prompt never hides the other (playtest: at 9 studs the elevator won the E press)
local UNLOAD_RANGE = 8
local CARRY_OFFSET = CFrame.new(0, -0.9, -2.3) -- its foot at the carrier's waist, in front
local FULL_WARN_SECONDS = 8

type Find = {
	Id: string,
	Kind: string,
	Model: Model,
	Root: BasePart,
	Carrier: Player?,
	Helpers: { [Player]: boolean },
	Weld: WeldConstraint?,
	Carry: ProximityPrompt,
	Help: ProximityPrompt,
	Put: ProximityPrompt,
	Tag: string?,
}
type Bag = { Id: string, Model: Model, Pack: Surface.Pack, Prompt: ProximityPrompt, Owner: string }
type Hit = { Player: Player?, Zone: string, At: number }

local residentService: any = nil
local grid: any = nil
local economy: any = nil
local combat: any = nil
local weapons: any = nil
local monsterService: any = nil
local director: any = nil

local packs: { [Player]: Surface.Pack } = {}
local pills: { [Player]: number } = {}
local finds: { [string]: Find } = {}
local carrying: { [Player]: string } = {} -- player -> the find they carry or help with
local bags: { [string]: Bag } = {}
local deliveries: { [string]: (Player, string) -> { Loot.Drop } } = {}
local specials: { [string]: (Player, number) -> number } = {} -- a loot Special -> its handler (how many it took)
local lastHit: { [string]: Hit } = {}
local fullWarnedAt: { [Player]: number } = {}
local counter = 0
local rng = Random.new()

local function alert(player: Player, kind: string, text: string)
	Remotes.FireClient("Alert", player, kind, text)
end

local function alertAll(kind: string, text: string)
	for _, player in Players:GetPlayers() do
		alert(player, kind, text)
	end
end

local function alive(player: Player): boolean
	return player:GetAttribute("Life") == "Alive"
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function slotsOf(player: Player): number
	return Surface.Slots(Modifiers.PlayerValue(player, "BackpackSlots") or 0) -- the Scout's level 2 too (Prompt 20)
end

local function publish(player: Player)
	local pack = packs[player] or {}
	player:SetAttribute("PackUsed", Surface.Used(pack))
	player:SetAttribute("PackSlots", slotsOf(player))
	player:SetAttribute("Pack", Surface.Encode(pack))
	player:SetAttribute("ClearRad", pills[player] or 0)
end

local function holder(name: string): Folder
	local folder = workspace:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end
	return folder :: Folder
end

local function makePrompt(parent: Instance, kind: string, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = kind .. "Prompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Kind", kind)
	prompt.Parent = parent
	return prompt
end

-- The ground under a point (a big find or a bag lands on it).
local function groundBelow(at: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	table.insert(list, holder("Finds"))
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(list, monsters)
	end
	params.FilterDescendantsInstances = list
	local hit = workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at
end

-- Packs -----------------------------------------------------------------------------------------

function InventoryService:Pack(player: Player): Surface.Pack
	return table.clone(packs[player] or {})
end

function InventoryService:Slots(player: Player): number
	return slotsOf(player)
end

function InventoryService:Pills(player: Player): number
	return pills[player] or 0
end

function InventoryService:TakePill(player: Player): boolean
	if (pills[player] or 0) <= 0 then
		return false
	end
	pills[player] -= 1
	publish(player)
	return true
end

-- Puts loot on a player; returns what they took and what is left over (the pack was full, the
-- pills at PillsMax, the throwable slots full, or nothing carries it yet).
function InventoryService:Give(player: Player, drops: { Loot.Drop }): ({ Loot.Drop }, { Loot.Drop })
	local given: { Loot.Drop } = {}
	local left: { Loot.Drop } = {}
	local pack = packs[player] or {}
	local slots = slotsOf(player)
	for _, drop in drops do
		local took = 0
		if drop.Resource then
			pack, took = Surface.Fit(pack, slots, drop.Resource, drop.Count)
		elseif drop.Item == "ClearRadPills" then
			local have = pills[player] or 0
			took = math.min(drop.Count, math.max(Surface.Tuning().PillsMax - have, 0))
			pills[player] = have + took
		elseif drop.Item then
			local item = Config.Find("Items", drop.Item)
			if item and item.Kind == "Throwable" then
				took = weapons:GiveThrowable(player, drop.Item, drop.Count)
			end
		elseif drop.Special then
			-- a handler may put something in the pack itself (Prompt 19: a blueprint's card), so it
			-- sees the pack as it is now, and this loop carries on from what it left
			packs[player] = pack
			took = InventoryService:GiveSpecial(player, drop.Special, drop.Count)
			pack = packs[player] or pack
		end
		if took > 0 then
			table.insert(given, { Resource = drop.Resource, Item = drop.Item, Special = drop.Special, Count = took })
		end
		if took < drop.Count then
			table.insert(left, { Resource = drop.Resource, Item = drop.Item, Special = drop.Special, Count = drop.Count - took })
		end
	end
	packs[player] = pack
	publish(player)
	return given, left
end

-- A blueprint's card into the player's pack (Prompt 19): its own slot; false when the pack is full.
function InventoryService:GiveCard(player: Player, cardId: string): boolean
	if not Config.Find("DraftCards", cardId) then
		return false
	end
	local pack, took = Surface.Fit(packs[player] or {}, slotsOf(player), cardId, 1)
	if took < 1 then
		return false
	end
	packs[player] = pack
	publish(player)
	return true
end

-- Loot specials (Prompt 17): who handles a Special, and handing one over (how many were taken).
function InventoryService:SetSpecial(special: string, fn: ((Player, number) -> number)?)
	specials[special] = fn
end

function InventoryService:GiveSpecial(player: Player, special: string, count: number): number
	local handler = specials[special]
	if not handler or count <= 0 then
		return 0
	end
	local ok, took = pcall(handler, player, count)
	if not ok then
		log:Warn("special %s for %s: %s", special, player.Name, tostring(took))
		return 0
	end
	return math.clamp(math.floor(tonumber(took) or 0), 0, count)
end

local function packLine(player: Player): string
	return `PACK {Surface.Used(packs[player] or {})}/{slotsOf(player)}`
end

function InventoryService:PackLine(player: Player): string
	return packLine(player)
end

-- Big finds -------------------------------------------------------------------------------------

local function setCarriers(f: Find)
	local n = if f.Carrier then 1 else 0
	for _ in f.Helpers do
		n += 1
	end
	if f.Carrier then
		f.Carrier:SetAttribute("Carriers", n)
	end
	for helper in f.Helpers do
		helper:SetAttribute("Carriers", n)
	end
	f.Model:SetAttribute("Carriers", n)
end

local function freeHands(player: Player)
	carrying[player] = nil
	player:SetAttribute("Carrying", nil)
	player:SetAttribute("Carriers", nil)
	weapons:RefreshHeld(player)
end

local function releaseHelper(f: Find, player: Player, why: string?)
	if not f.Helpers[player] then
		return
	end
	f.Helpers[player] = nil
	freeHands(player)
	setCarriers(f)
	if why then
		alert(player, "Info", why)
	end
end

-- The prompts stay enabled on the server; each client shows the one that is for it (CarriedBy:
-- Carry when nobody carries it, Put Down for the carrier, Help Carry for everyone else).
local function setPrompts(f: Find)
	local by = if f.Carrier then f.Carrier.UserId else nil
	f.Model:SetAttribute("CarriedBy", by)
	for _, prompt in { f.Carry, f.Help, f.Put } do
		prompt:SetAttribute("CarriedBy", by)
	end
end

local function settle(f: Find, at: Vector3)
	local ground = groundBelow(at, { f.Model })
	local rotation = CFrame.Angles(0, select(2, f.Root.CFrame:ToEulerAnglesYXZ()), 0)
	f.Model:PivotTo(CFrame.new(ground) * rotation)
	f.Root.Anchored = true
	for _, part in f.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = part:GetAttribute("Collides") == true
			part.Massless = false
		end
	end
end

local function putDown(f: Find, why: string?)
	local carrier = f.Carrier
	if f.Weld then
		f.Weld:Destroy()
		f.Weld = nil
	end
	f.Carrier = nil
	for helper in table.clone(f.Helpers) do
		releaseHelper(f, helper, nil)
	end
	if carrier then
		freeHands(carrier)
		if why then
			alert(carrier, "Info", why)
		end
	end
	settle(f, f.Root.Position)
	setPrompts(f)
	setCarriers(f)
end

local function pickUp(f: Find, player: Player)
	if f.Carrier or carrying[player] or not alive(player) or player:GetAttribute("Riding") then
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - f.Root.Position).Magnitude > 14 then
		return
	end
	f.Root.Anchored = false
	for _, part in f.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
		end
	end
	f.Model:PivotTo(root.CFrame * CARRY_OFFSET)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = f.Root
	weld.Parent = f.Root
	f.Weld = weld
	f.Carrier = player
	carrying[player] = f.Id
	player:SetAttribute("Carrying", f.Kind)
	weapons:RefreshHeld(player)
	setPrompts(f)
	setCarriers(f)
	log:Info("%s picked up %s (%s)", player.Name, f.Id, f.Kind)
end

local function help(f: Find, player: Player)
	if not f.Carrier or f.Carrier == player or carrying[player] or not alive(player) then
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - f.Root.Position).Magnitude > Surface.Tuning().HelpRange + 2 then
		return
	end
	f.Helpers[player] = true
	carrying[player] = f.Id
	player:SetAttribute("Carrying", f.Kind)
	weapons:RefreshHeld(player)
	setCarriers(f)
	alert(f.Carrier :: Player, "Info", `{string.upper(player.DisplayName)} IS HELPING YOU CARRY IT`)
end

local function findName(kind: string): string
	local entry = Config.Find("LootTables", kind) or Config.Find("DigResults", kind) -- generator parts; a cryo pod
	return if entry then entry.Text or entry.Name else kind
end

local function makeFindModel(kind: string): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local source = props and props:FindFirstChild(`Prop_{kind}`)
	if source and source:IsA("Model") then
		return source:Clone()
	end
	-- graybox: a crate of parts with a hazard band
	local model = Instance.new("Model")
	model.Name = `Prop_{kind}`
	local box = Instance.new("Part")
	box.Name = "Root"
	box.Size = Vector3.new(3, 2.2, 2.2)
	box.Color = Color3.fromRGB(96, 102, 110)
	box.Material = Enum.Material.Metal
	box.PivotOffset = CFrame.new(0, -1.1, 0) -- the pivot at the foot, like the art's
	box.Parent = model
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = Vector3.new(3.1, 0.5, 2.3)
	band.Color = Color3.fromHex("#F2C14E")
	band.CFrame = box.CFrame * CFrame.new(0, 0.5, 0)
	band.Parent = model
	model.PrimaryPart = box
	return model
end

-- Puts a big find in the world; returns its id.
function InventoryService:PlaceFind(kind: string, at: CFrame, tag: string?): string
	counter += 1
	local id = `F{counter}`
	local model = makeFindModel(kind)
	model.Name = `{kind}_{id}`
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	assert(root, "a big find needs a part")
	model.PrimaryPart = root
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part:SetAttribute("Collides", part.CanCollide)
			part.CanQuery = false
			part.CanTouch = false
			if part ~= root then
				part.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	root.Anchored = true
	model:PivotTo(at)
	model:SetAttribute("FindId", id)
	model:SetAttribute("BigFind", kind)
	model.Parent = holder("Finds")
	local name = findName(kind)
	local t = Surface.Tuning()
	local f: Find = {
		Id = id,
		Kind = kind,
		Model = model,
		Root = root :: BasePart,
		Carrier = nil,
		Helpers = {},
		Weld = nil,
		Carry = makePrompt(root, "Carry", "CARRY", name, t.PickUpSeconds),
		Help = makePrompt(root, "HelpCarry", "HELP CARRY", name, 0.5),
		Put = makePrompt(root, "PutDown", "PUT DOWN", name, 0),
		Tag = tag,
	}
	f.Carry.Triggered:Connect(function(player: Player)
		pickUp(f, player)
	end)
	f.Help.Triggered:Connect(function(player: Player)
		help(f, player)
	end)
	f.Put.Triggered:Connect(function(player: Player)
		if f.Carrier == player then
			putDown(f, nil)
		end
	end)
	finds[id] = f
	settle(f, at.Position)
	setPrompts(f)
	log:Info("%s placed (%s)", id, kind)
	return id
end

function InventoryService:RemoveFind(id: string)
	local f = finds[id]
	if not f then
		return
	end
	if f.Carrier then
		putDown(f, nil)
	end
	finds[id] = nil
	f.Model:Destroy()
end

function InventoryService:Finds(tag: string?): { { Id: string, Kind: string, Position: Vector3, Carried: boolean } }
	local list = {}
	for id, f in finds do
		if tag == nil or f.Tag == tag then
			table.insert(list, { Id = id, Kind = f.Kind, Position = f.Root.Position, Carried = f.Carrier ~= nil })
		end
	end
	return list
end

-- What a player has in their hands: the find's id and kind, and whether they lead (carry) it.
function InventoryService:Carrying(player: Player): (string?, string?, boolean)
	local id = carrying[player]
	local f = id and finds[id]
	if not f then
		return nil, nil, false
	end
	return f.Id, f.Kind, f.Carrier == player
end

-- How a kind of find pays when hauled home (cryo pods thaw instead: Prompt 17).
function InventoryService:SetDelivery(kind: string, fn: (Player, string) -> { Loot.Drop })
	deliveries[kind] = fn
end

local function deliverFind(player: Player): (string?, { Loot.Drop })
	local id = carrying[player]
	local f = id and finds[id]
	if not f or f.Carrier ~= player then
		return nil, {}
	end
	local kind = f.Kind
	local given: { Loot.Drop } = {}
	local handler = deliveries[kind]
	finds[f.Id] = nil
	if f.Weld then
		f.Weld:Destroy()
	end
	for helper in table.clone(f.Helpers) do
		releaseHelper(f, helper, nil)
	end
	freeHands(player)
	f.Model:Destroy()
	if handler then
		given = handler(player, kind)
	else
		local tableId = if Config.Find("LootTables", kind) then kind else Surface.Tuning().BigFindLoot
		for _, drop in Loot.Roll(tableId, rng, { Skip = SKIP }) do
			if drop.Resource then
				local added = economy:Add(drop.Resource, drop.Count, `{kind} hauled by {player.Name}`)
				if added > 0 then
					table.insert(given, { Resource = drop.Resource, Count = added })
				end
			end
		end
	end
	InventoryService.Delivered:Fire(player, kind, given)
	return kind, given
end

-- Unloading -------------------------------------------------------------------------------------

function InventoryService:Unload(player: Player): { [string]: number }
	-- blueprints (Prompt 19) come out first: home, they join the next draft
	local cards: { string } = {}
	local kept = {}
	for _, stack in packs[player] or {} do
		if Config.Find("DraftCards", stack.Id) then
			for _ = 1, stack.Count do
				table.insert(cards, stack.Id)
			end
		else
			table.insert(kept, stack)
		end
	end
	if #cards > 0 then
		packs[player] = kept
		InventoryService.CardsHome:Fire(player, cards)
	end
	local pack = packs[player] or {}
	local room: { [string]: number } = {}
	for _, stack in pack do
		if room[stack.Id] == nil then
			local resource = Config.Find("Resources", stack.Id)
			room[stack.Id] = if resource and resource.Kind == "Stock"
				then math.max(economy:Cap(stack.Id) - economy:Get(stack.Id), 0)
				else 0
		end
	end
	local delivered, leftover = Surface.Unload(pack, room)
	local drops: { Loot.Drop } = {}
	for _, stack in Surface.Totals(pack) do
		local n = delivered[stack.Id]
		if n and n > 0 then
			economy:Add(stack.Id, n, `hauled by {player.Name}`)
			table.insert(drops, { Resource = stack.Id, Count = n })
		end
	end
	packs[player] = leftover
	publish(player)
	local kind, given = deliverFind(player)
	if #drops > 0 then
		local text = `UNLOADED {Loot.Text(drops)}`
		if #leftover > 0 then
			text ..= ` · NO ROOM FOR {Surface.Summary(leftover)}: IT STAYS IN YOUR PACK`
		end
		alert(player, "Info", text)
		InventoryService.Unloaded:Fire(player, delivered)
	elseif #leftover > 0 and not kind then
		alert(player, "Warning", `THE STOCKPILE IS FULL: {Surface.Summary(leftover)} STAYS IN YOUR PACK`)
	end
	if kind then
		alertAll("Info", `{string.upper(player.DisplayName)} HAULED HOME {string.upper(findName(kind))}{if #given > 0 then `: {Loot.Text(given)}` else ""}`)
	end
	return delivered
end

local function unloadAnchor(folder: Folder, name: string, at: Vector3, object: string)
	local anchor = folder:FindFirstChild(name) :: BasePart?
	if not anchor then
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = folder
		local prompt = makePrompt(part, "Unload", "UNLOAD", object, 0)
		prompt.MaxActivationDistance = UNLOAD_RANGE
		prompt.Triggered:Connect(function(player: Player)
			InventoryService:Unload(player)
		end)
		anchor = part
	end
	(anchor :: BasePart).CFrame = CFrame.new(at)
	anchor:SetAttribute("Seen", true)
end

local function syncUnloadPoints()
	local root = grid:Root()
	if not root then
		return
	end
	local folder = root:FindFirstChild("Hauling") :: Folder?
	if not folder then
		local made = Instance.new("Folder")
		made.Name = "Hauling"
		made.Parent = root
		folder = made
	end
	local hauling = folder :: Folder
	for _, child in hauling:GetChildren() do
		child:SetAttribute("Seen", nil)
	end
	for _, room in grid:RoomsOfType("BlastDoor") do
		local model = grid:RoomModel(room.Id)
		local door = model and BunkerKit.Socket(model, "Door")
		local at = if door then door.Position + HALL_UNLOAD
			else Grid.CellPosition(room.Floor, room.Column) + Vector3.new(0, 0, -8)
		unloadAnchor(hauling, "Hall", at + Vector3.new(0, 2.5, 0), "Blast Door hall")
	end
	for _, room in grid:RoomsOfType("Storage") do
		local cell = Grid.CellPosition(room.Floor, room.Column + (room.Span - 1) / 2)
		unloadAnchor(hauling, `Storage {room.Id}`, cell + Vector3.new(0, 2.5, 6), "Storage")
	end
	for _, child in hauling:GetChildren() do
		if not child:GetAttribute("Seen") then
			child:Destroy()
		end
	end
end

-- Bags ------------------------------------------------------------------------------------------

local function makeBagModel(): Model
	local assets = ServerStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local source = props and props:FindFirstChild("Prop_LootBag")
	if source and source:IsA("Model") then
		return source:Clone()
	end
	local model = Instance.new("Model")
	local sack = Instance.new("Part")
	sack.Name = "Root"
	sack.Shape = Enum.PartType.Ball
	sack.Size = Vector3.new(2, 2, 2)
	sack.Color = Color3.fromRGB(122, 92, 60)
	sack.Material = Enum.Material.Fabric
	sack.PivotOffset = CFrame.new(0, -1, 0)
	sack.Parent = model
	model.PrimaryPart = sack
	return model
end

local function updateBag(bag: Bag)
	bag.Prompt.ObjectText = `{bag.Owner}'s pack: {Surface.Summary(bag.Pack)}`
end

local function pickUpBag(bag: Bag, player: Player)
	if not bags[bag.Id] or not alive(player) then
		return
	end
	local merged, leftover = Surface.Merge(packs[player] or {}, bag.Pack, slotsOf(player))
	packs[player] = merged
	bag.Pack = leftover
	publish(player)
	if #leftover == 0 then
		bags[bag.Id] = nil
		bag.Model:Destroy()
		alert(player, "Info", `PICKED UP {string.upper(bag.Owner)}'S PACK · {packLine(player)}`)
	else
		updateBag(bag)
		alert(player, "Warning", `YOUR PACK IS FULL: {Surface.Summary(leftover)} STAYS IN THE BAG`)
	end
end

-- Magnet Sweep and the Tinkerer's drone (Prompt 20): dropped packs within `radius` of `position`
-- go into the player's pack (what doesn't fit stays in the bag). Returns how many were reached.
function InventoryService:CollectBags(player: Player, position: Vector3, radius: number): number
	local n = 0
	for _, bag in table.clone(bags) do
		if (bag.Model:GetPivot().Position - position).Magnitude <= radius then
			pickUpBag(bag, player)
			n += 1
		end
	end
	return n
end

local function dropBag(player: Player, at: Vector3)
	local pack = packs[player]
	if not pack or #pack == 0 then
		return
	end
	counter += 1
	local id = `B{counter}`
	local model = makeBagModel()
	model.Name = `LootBag_{id}`
	model:SetAttribute("Bag", id) -- the Scout's Flare Ping outlines it (Prompt 20)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model:PivotTo(CFrame.new(groundBelow(at, {})) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = holder("Finds")
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	local bag: Bag = {
		Id = id,
		Model = model,
		Pack = pack,
		Prompt = makePrompt(root, "PickUp", "PICK UP", "", 0.5),
		Owner = player.DisplayName,
	}
	bag.Prompt.Triggered:Connect(function(by: Player)
		pickUpBag(bag, by)
	end)
	updateBag(bag)
	bags[id] = bag
	packs[player] = {}
	publish(player)
	alert(player, "Warning", "YOU DROPPED YOUR PACK WHERE YOU FELL: GO BACK FOR IT")
	log:Info("%s dropped %s (%s)", player.Name, id, Surface.Summary(pack))
end

-- Monster drops ---------------------------------------------------------------------------------

local function onMonsterDied(id: string, monsterType: string)
	local hit = lastHit[id]
	lastHit[id] = nil
	local spec = Config.Find("Monsters", monsterType)
	if not spec or not spec.Drops then
		return
	end
	local drops = Loot.Roll(spec.Drops, rng, { Skip = SKIP })
	if hit and hit.Zone ~= "Bunker" then
		local player = hit.Player
		if player and player.Parent == Players and alive(player) then
			local _, left = InventoryService:Give(player, drops)
			if #left > 0 and os.clock() - (fullWarnedAt[player] or 0) > FULL_WARN_SECONDS then
				fullWarnedAt[player] = os.clock()
				alert(player, "Warning", `PACK FULL: {packLine(player)}`)
			end
		end
		return
	end
	for _, drop in drops do
		if drop.Resource then
			economy:Add(drop.Resource, drop.Count, `{monsterType} {id}`)
		end
	end
end

-- Life ------------------------------------------------------------------------------------------

local function letGo(player: Player, why: string?)
	local id = carrying[player]
	local f = id and finds[id]
	if not f then
		carrying[player] = nil
		return
	end
	if f.Carrier == player then
		putDown(f, why)
	else
		releaseHelper(f, player, why)
	end
end

local function onDowned(combatantId: string)
	local c = combat:Get(combatantId)
	local player = c and c.Player
	if not player then
		return
	end
	letGo(player, nil)
	local root = rootOf(player)
	if root and Surface.Zone(root.Position) ~= "Bunker" and not Modifiers.PlayerValue(player, "KeepBackpackWhenDowned") then
		dropBag(player, root.Position)
	end
end

local function helperLoop()
	while true do
		task.wait(0.5)
		local range = Surface.Tuning().HelpRange + 4
		for _, f in finds do
			for helper in table.clone(f.Helpers) do
				local root = rootOf(helper)
				if not root or not alive(helper) or (root.Position - f.Root.Position).Magnitude > range then
					releaseHelper(f, helper, "YOU LET GO")
				end
			end
		end
		local cutoff = os.clock() - 120
		for id, hit in lastHit do
			if hit.At < cutoff then
				lastHit[id] = nil
			end
		end
	end
end

local function clearAll()
	for id in table.clone(finds) do
		InventoryService:RemoveFind(id)
	end
	for id, bag in bags do
		bag.Model:Destroy()
		bags[id] = nil
	end
	for _, player in Players:GetPlayers() do
		packs[player] = {}
		publish(player)
	end
end

-- Dev -------------------------------------------------------------------------------------------

local function target(player: Player?): Player?
	return player or Players:GetPlayers()[1]
end

local function registerCommands(dev: any)
	dev:Register("pack", {
		Description = "Your backpack, Clear-Rad pills and what you carry (Prompt 16).",
		Usage = "pack",
		Run = function(player): string?
			local p = target(player)
			if not p then
				return "no player"
			end
			local id, kind, lead = InventoryService:Carrying(p)
			return `{packLine(p)}: {Surface.Summary(packs[p] or {})} · Clear-Rad {pills[p] or 0}`
				.. (if id then ` · carrying {kind} ({id}{if lead then "" else ", helping"})` else "")
				.. ` · {#InventoryService:Finds()} finds, bags: {(function()
					local n = 0
					for _ in bags do
						n += 1
					end
					return n
				end)()}`
		end,
	})
	dev:Register("pack.add", {
		Description = "Put resources in your backpack, or Blueprint (found as loot is: a card drawn for the draft, Prompt 19).",
		Usage = "pack.add <resource|Blueprint> <n>",
		Run = function(player, args): string?
			local p = target(player)
			local id = tostring(args[1] or "")
			if p and id == "Blueprint" then
				local _, left = InventoryService:Give(p, { { Special = "Blueprint", Count = math.max(math.floor(tonumber(args[2]) or 1), 1) } })
				return `{packLine(p)}: {Surface.Summary(packs[p] or {})}{if #left > 0 then ` (left over {Loot.Text(left)})` else ""}`
			end
			if not p or not Config.Find("Resources", id) then
				return "pack.add <resource|Blueprint> <n>"
			end
			local _, left = InventoryService:Give(p, { { Resource = id, Count = math.max(math.floor(tonumber(args[2]) or 10), 1) } })
			return `{packLine(p)}: {Surface.Summary(packs[p] or {})}{if #left > 0 then ` (left over {Loot.Text(left)})` else ""}`
		end,
	})
	dev:Register("pack.clear", {
		Description = "Empty your backpack.",
		Usage = "pack.clear",
		Run = function(player): string?
			local p = target(player)
			if not p then
				return "no player"
			end
			packs[p] = {}
			publish(p)
			return packLine(p)
		end,
	})
	dev:Register("pills", {
		Description = "Set your Clear-Rad pills.",
		Usage = "pills <n>",
		Run = function(player, args): string?
			local p = target(player)
			if not p then
				return "no player"
			end
			pills[p] = math.clamp(math.floor(tonumber(args[1]) or 1), 0, Surface.Tuning().PillsMax)
			publish(p)
			return `Clear-Rad {pills[p]}`
		end,
	})
	dev:Register("find", {
		Description = "Put a big find (generator parts) in front of you.",
		Usage = "find [kind]",
		Run = function(player, args): string?
			local p = target(player)
			local root = p and rootOf(p)
			if not root then
				return "no player"
			end
			local kind = tostring(args[1] or Surface.Tuning().BigFindLoot)
			local id = InventoryService:PlaceFind(kind, root.CFrame * CFrame.new(0, 0, -7), "Dev")
			return `{id} ({kind})`
		end,
	})
end

function InventoryService:Init(registry)
	residentService = registry.ResidentService
	grid = registry.BunkerGrid
	economy = registry.EconomyService
	combat = registry.CombatService
	weapons = registry.WeaponService
	monsterService = registry.MonsterService
	director = registry.RunDirector
	registerCommands(registry.DevService)
end

function InventoryService:Start()
	-- Prompt 26: gear found in a container or on a raider goes to the bunker's gear locker
	InventoryService:SetSpecial("Gear", function(player: Player, count: number): number
		return residentService:FindGear(player, count)
	end)
	local function joined(player: Player)
		packs[player] = packs[player] or {}
		pills[player] = pills[player] or 0
		publish(player)
		player:GetAttributeChangedSignal("Class"):Connect(function()
			publish(player)
		end)
		-- a new character (a respawn) has free hands
		player.CharacterAdded:Connect(function()
			letGo(player, nil)
		end)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player: Player)
		letGo(player, nil)
		local root = rootOf(player)
		if root and Surface.Zone(root.Position) ~= "Bunker" then
			dropBag(player, root.Position)
		end
		packs[player] = nil
		pills[player] = nil
		fullWarnedAt[player] = nil
	end)
	combat.Downed:Connect(onDowned)
	combat.Died:Connect(function(id: string)
		local c = combat:Get(id)
		local player = c and c.Player
		if player then
			letGo(player, nil)
		end
	end)
	combat.Damaged:Connect(function(targetId: string, _amount: number, sourceId: string?)
		if string.sub(targetId, 1, 1) ~= "M" then
			return
		end
		local zone = monsterService:ZoneOf(targetId)
		if not zone then
			return
		end
		local previous = lastHit[targetId]
		local player: Player? = if previous then previous.Player else nil
		if sourceId and string.sub(sourceId, 1, 1) == "P" then
			player = Players:GetPlayerByUserId(tonumber(string.sub(sourceId, 2)) or 0) or player
		end
		lastHit[targetId] = { Player = player, Zone = zone, At = os.clock() }
	end)
	monsterService.Died:Connect(onMonsterDied)
	grid.Changed:Connect(syncUnloadPoints)
	syncUnloadPoints()
	director.RunEnded:Connect(clearAll)
	task.spawn(helperLoop)
	log:Info("backpacks ready: %d slots, unload points at the Blast Door hall and Storage", Config.Get("Tuning", "Player").BackpackSlots)
end

return InventoryService
