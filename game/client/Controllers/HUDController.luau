--!strict
--[[
	HUDController: the run HUD (bible Section 18), StarterGui.HUD in the Run place. Fixed
	positions, separate from The Frame; this controller only fills the layout in.

	Live now:
	* Top centre: the year flip counter (the tiles flip when the year changes), the era, the
	  cycle dial (day, then Surge) with the phase and the time left, and the Ready button with
	  the team's count (the SetReady remote). A boss Surge has no timer.
	* Banners under the vote telegram: the siren and the start of each Surge.
	* Top left: health from the character; the class and its ability (the Survivor until the
	  loadout arrives); stamina and radiation rest until combat.
	* Top right: the stockpile chips (values come with the economy, Prompt 9), the seismograph
	  at rest (Disturbance, Prompt 14) and the Command View button.
	* Bottom centre: the hotbar's selection (1 to 5, the D-pad, a tap).
	* Bottom right on touch: Fire, Aim, Melee, Ability, Interact, Jump, Dodge, Sprint (a
	  toggle), Ping and Shoulder, bound through InputController. Roblox's own jump button is
	  hidden while ours shows.

	On PC the camera locks the mouse; a click of the mouse wheel frees the cursor to click HUD
	buttons, and another click locks it again. Ready has its own key (Z, D-pad down).

	For later systems: Alert(kind, text) for the alert feed, Banner(text, kind) for
	announcements, SetVital, SetClass, SetResource, SetSlot and the HotbarSelected signal.

	The HUD hides during the intro and while a Frame screen is open.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Grid = require(Shared.Rules.Grid)
local Hud = require(Shared.Rules.Hud)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local Signal = require(Shared.Utilities.Signal)
local UIContract = require(Shared.UIContract)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))
local UIKit = require(Lib:WaitForChild("UIKit"))

local log = Log.new("HUDController")

export type AlertKind = "Danger" | "Warning" | "Info"

local COLORS = {
	cream = Color3.fromHex("#F2E6C9"),
	navy = Color3.fromHex("#1B2A3A"),
	hazard = Color3.fromHex("#F2C14E"),
	signal = Color3.fromHex("#E8743B"),
	leaf = Color3.fromHex("#7CC26A"),
}
-- The stockpile chips: Section 18 lists power, Food, Water, Scrap, ore and Ammo.
local STOCK = {
	{ Id = "Power", Icon = "Icon_Power" },
	{ Id = "Food", Icon = "Icon_Food" },
	{ Id = "Water", Icon = "Icon_Water" },
	{ Id = "Scrap", Icon = "Icon_Scrap" },
	{ Id = "Iron", Icon = "Icon_Iron" },
	{ Id = "Copper", Icon = "Icon_Copper" },
	{ Id = "Crystal", Icon = "Icon_Crystal" },
	{ Id = "Ammo", Icon = "Icon_Ammo" },
}
-- Touch buttons and the actions they drive (Jump and the Sprint toggle are handled here).
local TOUCH_ACTIONS = {
	Fire = "Fire",
	Aim = "Aim",
	Melee = "Melee",
	Ability = "Ability",
	Interact = "Interact",
	Dodge = "Dodge",
	Ping = "Ping",
	Shoulder = "SwapShoulder",
}
local ABILITY_ICONS: { [string]: string } = { Security = "Icon_Shield" } -- more with the class icons (A11)
local MAX_ALERTS = 3
local FLIP_SECONDS = 0.07
local TICK_SECONDS = 0.1

local HUDController = {
	Name = "HUDController",
	Dependencies = { "InputController", "UIController", "CameraController", "ReplicaController" },
	HotbarSelected = Signal.new() :: Signal.Signal<number>,
}

local input: any = nil
local replica: any = nil
local ui: any = nil
local camera: any = nil
local gui: ScreenGui? = nil
local inRun = false
local hidden: { [string]: boolean } = {}
local forceTouch = false
local sprintOn = false
local selectedSlot = 1
local alertCount = 0
local bannerToken = 0
local shownYear: number? = nil
local digitHome: { [Instance]: { UDim2 } } = {}
local resourceChips: { [string]: any } = {}
local jumpGuard: RBXScriptConnection? = nil
local classId = "Survivor"
local classLevel = 1

local function part(path: string): any
	assert(gui, "HUDController: no HUD")
	local found = UIContract.Find(gui, path)
	assert(found, `HUDController: HUD.{path} is missing (see Shared.UIContract)`)
	return found
end

local function clone(template: string): any
	local copy = part("Templates." .. template):Clone()
	copy.Visible = true
	return copy
end

local function humanoid(): Humanoid?
	local character = Players.LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function refreshVisible()
	if not gui then
		return
	end
	local phase = RunState.Get("RunPhase")
	local live = inRun and (phase == "Playing" or phase == "Ended")
	gui.Enabled = live and next(hidden) == nil
end

-- Top centre --------------------------------------------------------------------------------

local function flip(digit: TextLabel, value: string)
	local home = digitHome[digit]
	if not home then
		home = { digit.Size, digit.Position }
		digitHome[digit] = home
	end
	if digit.Text == value then
		return
	end
	local size, position = home[1], home[2]
	local squash = TweenService:Create(digit, TweenInfo.new(FLIP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(size.X.Scale, 0, 0, 0),
		Position = UDim2.new(position.X.Scale, 0, position.Y.Scale + size.Y.Scale / 2, 0),
	})
	squash.Completed:Once(function()
		digit.Text = value
		TweenService:Create(digit, TweenInfo.new(FLIP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = size,
			Position = position,
		}):Play()
	end)
	squash:Play()
end

local function showYear()
	local year = RunState.Get("Year")
	if type(year) ~= "number" then
		return
	end
	local digits = Hud.YearDigits(year)
	for i = 1, 3 do
		local digit = part(`YearClock.Tile{i}.Digit`)
		if shownYear == nil then
			digit.Text = digits[i]
		else
			flip(digit, digits[i])
		end
	end
	shownYear = year
end

local function showEra()
	local id = RunState.Get("Era")
	local era = if type(id) == "string" then Config.Find("Eras", id) else nil
	if not era then
		part("YearClock.Era").Text = ""
		part("YearClock.EraName").Text = ""
		return
	end
	local index = table.find(Config.Ids("Eras"), id)
	part("YearClock.Era").Text = "ERA " .. Hud.Numeral(index or 1)
	part("YearClock.EraName").Text = string.upper(era.Name)
end

local function bossName(): string
	local id = RunState.Get("SurgeBoss")
	local boss = if type(id) == "string" then Config.Find("Bosses", id) else nil
	return if boss then string.upper(boss.Name) else "THE BOSS"
end

local function tickClock()
	local phase = RunState.Get("CyclePhase")
	local open = RunState.Get("PhaseOpen") == true
	local siren = RunState.Get("Siren") == true
	local left = RunState.TimeLeft()
	local scale = RunState.Get("TimeScale")
	local length = RunState.Get("PhaseLength")
	local realLength = if type(length) == "number" then length / (if type(scale) == "number" and scale > 0 then scale else 1) else nil
	local clock = Config.Get("Tuning", "Clock")
	local pointer = part("CycleDial.Pointer")
	pointer.Position = UDim2.fromScale(
		Hud.DialPosition(phase, realLength, left, open, clock.DaySeconds, clock.SurgeSeconds),
		pointer.Position.Y.Scale
	)
	local phaseText, phaseColor = "", COLORS.cream
	if phase == "Day" then
		phaseText = if siren then "SIREN" else `DAY {RunState.Get("Cycle") or 1}`
		phaseColor = if siren then COLORS.hazard else COLORS.cream
	elseif phase == "Surge" then
		local kind = RunState.Get("SurgeKind")
		phaseText = if kind == "Boss" or kind == "Final" then "BOSS" else "SURGE"
		phaseColor = COLORS.signal
	end
	local phaseLabel = part("Phase.Text")
	phaseLabel.Text = phaseText
	phaseLabel.TextColor3 = phaseColor
	local timeLabel = part("TimeLeft.Text")
	timeLabel.Text = if open then "--:--" else Hud.Clock(left)
	timeLabel.TextColor3 = if siren and (os.clock() % 1) < 0.5 then COLORS.hazard else COLORS.cream

	local ready = part("Ready")
	local canReady = RunState.Get("RunPhase") == "Playing" and phase == "Day" and not siren
		and (RunState.Get("ReadyNeeded") or 0) > 0
	ready.Visible = canReady
	if canReady then
		local mine = Players.LocalPlayer:GetAttribute("Ready") == true
		KitRuntime.SetSprite(part("Ready.Content.Lamp"), if mine then "Lamp_Green" else "Lamp_Off")
		part("Ready.Content.Count").Text = `{RunState.Get("ReadyCount") or 0} OF {RunState.Get("ReadyNeeded") or 0}`
	end
end

-- Banners and alerts ----------------------------------------------------------------------

local function bannerStyle(kind: AlertKind): (string, Color3)
	if kind == "Danger" then
		return "Alert_Danger", COLORS.signal
	elseif kind == "Info" then
		return "Alert_Info", COLORS.cream
	end
	return "Alert_Warning", COLORS.hazard
end

function HUDController:Banner(text: string, kind: AlertKind?, seconds: number?)
	if not gui then
		return
	end
	local sprite, color = bannerStyle(kind or "Warning")
	local banner = part("Banner")
	KitRuntime.SetSprite(part("Banner.Icon"), sprite)
	local label = part("Banner.Text")
	label.Text = string.upper(text)
	label.TextColor3 = color
	banner.Visible = true
	bannerToken += 1
	local token = bannerToken
	task.delay(seconds or 4, function()
		if token == bannerToken then
			banner.Visible = false
		end
	end)
end

function HUDController:Alert(kind: AlertKind, text: string, seconds: number?)
	if hidden.Frame and ui then
		ui:Notice(text, kind) -- a screen hides the HUD: say it in the screen's footer instead
	end
	if not gui then
		return
	end
	local holder = part("Alerts")
	local slips = {}
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(slips, child)
		end
	end
	table.sort(slips, function(a, b)
		return a.LayoutOrder > b.LayoutOrder -- oldest last
	end)
	while #slips >= MAX_ALERTS do
		local oldest = table.remove(slips) :: GuiObject
		oldest:Destroy()
	end
	alertCount += 1
	local slip = clone("AlertSlip")
	slip.Name = "Alert" .. alertCount
	slip.LayoutOrder = -alertCount -- newest on top
	KitRuntime.SetSprite(slip.Icon, (bannerStyle(kind)))
	slip.Text.Text = string.upper(text)
	slip.Parent = holder
	task.delay(seconds or 8, function()
		if slip.Parent then
			slip:Destroy()
		end
	end)
end

local function onSiren()
	if RunState.Get("Siren") ~= true then
		return
	end
	local kind = RunState.Get("SurgeKind")
	local who = if kind == "Boss" or kind == "Final" then bossName() else "SURGE"
	HUDController:Banner(`SIREN  ·  {who} IN 0:20`, "Warning", 5)
end

local function onPhase()
	if RunState.Get("CyclePhase") ~= "Surge" then
		return
	end
	if RunState.Get("PhaseOpen") == true then
		HUDController:Banner(`{bossName()}  ·  THE SURGE ENDS WHEN IT FALLS`, "Danger", 6)
	else
		HUDController:Banner("SURGE  ·  HOLD THE BUNKER", "Danger", 4)
	end
end

-- Top left --------------------------------------------------------------------------------

function HUDController:SetVital(name: string, fraction: number, text: string?)
	if not gui then
		return
	end
	part(`Vitals.{name}.Needle`).Rotation = Hud.NeedleRotation(fraction)
	if text then
		local value: any = UIContract.Find(gui, `Vitals.{name}.Value`)
		if value then
			value.Text = text
		end
	end
end

local function watchHealth(character: Model)
	local h = character:WaitForChild("Humanoid", 10)
	if not h or not h:IsA("Humanoid") then
		return
	end
	local function update()
		local max = math.max(h.MaxHealth, 1)
		HUDController:SetVital("Health", h.Health / max, tostring(math.max(0, math.ceil(h.Health))))
	end
	h.HealthChanged:Connect(update)
	h:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

local function keyText(): string
	local device = input:Device()
	return if device == "Gamepad" then "LB" elseif device == "Keyboard" then "Q" else ""
end

-- Ready's own key (Landon, 2026-11-08): Z on PC, the D-pad's down on console (InputController).
local function readyKeyText(): string
	local device = input:Device()
	return if device == "Gamepad" then "DOWN" elseif device == "Keyboard" then "Z" else ""
end

function HUDController:SetClass(id: string, level: number?)
	local class = Config.Find("Classes", id)
	if not class or not gui then
		return
	end
	classId = id
	classLevel = level or 1
	part("Vitals.AbilityName").Text = string.upper(class.Ability.Name)
	part("Vitals.Class").Text = `{string.upper(class.Name)}  ·  LV {classLevel}`
	local icon = part("Vitals.Ability.Icon")
	local sprite = ABILITY_ICONS[id]
	icon.Visible = sprite ~= nil
	if sprite then
		KitRuntime.SetSprite(icon, sprite)
	end
	local touchIcon = part("Touch.Ability.Content.Icon")
	if sprite then
		KitRuntime.SetSprite(touchIcon, sprite)
	end
end

-- Top right -------------------------------------------------------------------------------

function HUDController:SetResource(id: string, text: string, lamp: string?)
	local chip = resourceChips[id]
	if not chip then
		return
	end
	chip.Value.Text = text
	chip.Lamp.Visible = lamp ~= nil
	if lamp then
		KitRuntime.SetSprite(chip.Lamp, lamp)
	end
end

local cursorFree = false -- PC: the mouse wheel freed the cursor for the HUD

-- Copper and Crystal chips stay hidden until the team digs into their bands (Config.DepthBands).
local function refreshOreChips()
	local deepest = 1 -- the run starts with floors 1 and 2 built
	for key in replica:All("Cells") do
		local floor = Grid.Parse(key)
		if floor and floor > deepest then
			deepest = floor
		end
	end
	for _, band in Config.All("DepthBands") do
		local chip = if band.Ore then resourceChips[band.Ore] else nil
		if chip then
			chip.Visible = deepest >= band.Floors.From
		end
	end
end

local function buildStockpile()
	local holder = part("Stockpile.Resources")
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, entry in STOCK do
		if Config.Find("Resources", entry.Id) and UIKit.Sprites[entry.Icon] then
			local chip = clone("ResourceChip")
			chip.Name = entry.Id
			chip.LayoutOrder = i
			KitRuntime.SetSprite(chip.Icon, entry.Icon)
			chip.Value.Text = "—"
			chip.Parent = holder
			resourceChips[entry.Id] = chip
		end
	end
	HUDController:SetResource("Power", "—", "Lamp_Off")
end

-- Hotbar ----------------------------------------------------------------------------------

function HUDController:SelectSlot(index: number)
	if not gui or index < 1 or index > 5 then
		return
	end
	selectedSlot = index
	for i = 1, 5 do
		KitRuntime.SetSprite(part(`Hotbar.Slot{i}`), if i == index then "Hotbar_Selected" else "Hotbar_Slot")
	end
	HUDController.HotbarSelected:Fire(index)
end

function HUDController:SelectedSlot(): number
	return selectedSlot
end

-- A hotbar slot's item icon (a kit sprite) and ammo text; nil empties it.
function HUDController:SetSlot(index: number, icon: string?, ammo: string?)
	if not gui then
		return
	end
	local item = part(`Hotbar.Slot{index}.Item`)
	item.Visible = icon ~= nil
	if icon then
		KitRuntime.SetSprite(item, icon)
	end
	local count = part(`Hotbar.Slot{index}.Ammo`)
	count.Visible = ammo ~= nil
	count.Text = ammo or ""
end

-- Touch -----------------------------------------------------------------------------------

local function robloxJumpButton(): GuiObject?
	local touchGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	touchGui = touchGui and touchGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	return if jump and jump:IsA("GuiObject") then jump else nil
end

local function guardRobloxJump(on: boolean)
	if jumpGuard then
		jumpGuard:Disconnect()
		jumpGuard = nil
	end
	local jump = robloxJumpButton()
	if not jump then
		return
	end
	if on then
		jump.Visible = false
		jumpGuard = jump:GetPropertyChangedSignal("Visible"):Connect(function()
			if jump.Visible then
				jump.Visible = false
			end
		end)
	end
end

local function refreshDevice()
	if not gui then
		return
	end
	local device = input:Device()
	local touch = forceTouch or device == "Touch"
	part("Touch").Visible = touch
	guardRobloxJump(touch and device == "Touch")
	local key = keyText()
	part("Vitals.Ability.Key").Visible = key ~= ""
	part("Vitals.Ability.Key.Text").Text = key
	local readyKey = readyKeyText()
	part("Ready.Key").Visible = readyKey ~= ""
	part("Ready.Key.Text").Text = readyKey
	local viewKey = part("CommandView.Content.Key")
	viewKey.Text = if device == "Gamepad" then "VIEW" elseif device == "Keyboard" then "TAB" else ""
	for i = 1, 5 do
		part(`Hotbar.Slot{i}.Key`).Visible = device == "Keyboard"
	end
end

local function setSprintToggle(on: boolean)
	sprintOn = on
	input:Press("Sprint", on, "TouchToggle")
	local button = part("Touch.Sprint")
	local up, down = button:GetAttribute("RectUp"), button:GetAttribute("RectDown")
	if on and not button:GetAttribute("RestUp") then
		button:SetAttribute("RestUp", up)
		button:SetAttribute("RectUp", down) -- stays pressed while on
	elseif not on and button:GetAttribute("RestUp") then
		button:SetAttribute("RectUp", button:GetAttribute("RestUp"))
		button:SetAttribute("RestUp", nil)
	end
	button.ImageRectOffset = button:GetAttribute("RectUp")
end

local function bindTouch()
	for name, action in TOUCH_ACTIONS do
		input:BindButton(action, part("Touch." .. name))
	end
	part("Touch.Sprint").Activated:Connect(function()
		setSprintToggle(not sprintOn)
	end)
	local jump = part("Touch.Jump")
	jump.MouseButton1Down:Connect(function()
		local h = humanoid()
		if h then
			h.Jump = true
		end
	end)
end

-- Lifecycle -------------------------------------------------------------------------------

function HUDController:SetForceTouch(on: boolean)
	forceTouch = on
	refreshDevice()
end

function HUDController:Hide(reason: string, on: boolean)
	hidden[reason] = if on then true else nil
	refreshVisible()
end

function HUDController:State(): { [string]: any }
	return {
		Present = gui ~= nil,
		Enabled = gui ~= nil and gui.Enabled,
		Year = shownYear,
		Phase = if gui then part("Phase.Text").Text else nil,
		TimeLeft = if gui then part("TimeLeft.Text").Text else nil,
		Ready = if gui then part("Ready").Visible else nil,
		Slot = selectedSlot,
		Touch = if gui then part("Touch").Visible else nil,
		Class = classId,
		Hidden = next(hidden) ~= nil,
	}
end

function HUDController:Gui(): ScreenGui?
	return gui
end

function HUDController:Init(registry)
	input = registry.InputController
	replica = registry.ReplicaController
	ui = registry.UIController
	camera = registry.CameraController
	inRun = Constants.PlaceKind() == "Run"
end

function HUDController:Start()
	if not inRun then
		return -- the Lobby's own HUD comes with the lobby (Prompt 21)
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local found = playerGui:WaitForChild("HUD", 20)
	if not found or not found:IsA("ScreenGui") then
		log:Warn("no HUD ScreenGui in this place")
		return
	end
	gui = found
	KitRuntime.Watch(found)
	-- Tab opens the Command View (bible Section 7), so Roblox's player list (also on Tab) is off
	-- in the run.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	buildStockpile()
	HUDController:SetClass("Survivor", 1)
	HUDController:SetVital("Stamina", 1)
	HUDController:SetVital("Radiation", 0)
	HUDController:SelectSlot(1)
	bindTouch()
	refreshDevice()
	input.DeviceChanged:Connect(refreshDevice)

	-- the stockpile (EconomyService replicates the amounts as RunState values; Power is Prompt 9's)
	for _, entry in STOCK do
		if RunState.Fields[entry.Id] then
			local function show()
				local value = RunState.Get(entry.Id)
				HUDController:SetResource(entry.Id, if type(value) == "number" then tostring(value) else "—")
			end
			RunState.Changed(entry.Id):Connect(show)
			show()
		end
	end
	-- messages from the server for the alert feed (a refused proposal, a room built...)
	Remotes.OnClient("Alert", function(kind: any, text: any)
		if type(text) == "string" then
			HUDController:Alert(if kind == "Danger" or kind == "Warning" then kind else "Info", text)
		end
	end)

	-- the clock
	RunState.Changed("Year"):Connect(showYear)
	RunState.Changed("Era"):Connect(showEra)
	RunState.Changed("Siren"):Connect(onSiren)
	RunState.Changed("CyclePhase"):Connect(onPhase)
	RunState.Changed("RunPhase"):Connect(refreshVisible)
	showYear()
	showEra()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TICK_SECONDS and gui and gui.Enabled then
			elapsed = 0
			tickClock()
		end
	end)
	local function pressReady()
		if Remotes.InPlace("SetReady") and part("Ready").Visible then
			Remotes.FireServer("SetReady", Players.LocalPlayer:GetAttribute("Ready") ~= true)
		end
	end
	part("Ready").Activated:Connect(pressReady)
	input:On("Ready", pressReady)

	-- health, the ability, the hotbar, the Command View
	Players.LocalPlayer.CharacterAdded:Connect(watchHealth)
	if Players.LocalPlayer.Character then
		task.spawn(watchHealth, Players.LocalPlayer.Character)
	end
	part("Vitals.Ability").Activated:Connect(function()
		input:Press("Ability", true, "HudAbility")
		input:Press("Ability", false, "HudAbility")
	end)
	for i = 1, 5 do
		input:On(`Hotbar{i}`, function()
			HUDController:SelectSlot(i)
		end)
		part(`Hotbar.Slot{i}`).Activated:Connect(function()
			HUDController:SelectSlot(i)
		end)
	end
	input:On("HotbarNext", function()
		HUDController:SelectSlot(selectedSlot % 5 + 1)
	end)
	input:On("HotbarPrevious", function()
		HUDController:SelectSlot((selectedSlot - 2) % 5 + 1)
	end)
	input:BindButton("CommandView", part("CommandView"))
	-- PC: the camera locks the mouse; a click of the mouse wheel frees the cursor to click the
	-- HUD (and the vote telegram), and another click locks it again (Landon, 2026-11-08)
	UserInputService.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.MouseButton3 then
			cursorFree = not cursorFree
			camera:FreeCursor("HudCursor", cursorFree)
		end
	end)

	-- the ore chips show once the team has dug into that ore's band (Landon, 2026-11-08)
	replica:Changed("Cells"):Connect(refreshOreChips)
	refreshOreChips()

	-- menus hide the HUD (and take back a cursor the wheel freed: the menu frees its own)
	ui.Opened:Connect(function()
		HUDController:Hide("Frame", true)
		if cursorFree then
			cursorFree = false
			camera:FreeCursor("HudCursor", false)
		end
	end)
	ui.Closed:Connect(function()
		HUDController:Hide("Frame", false)
	end)
	refreshVisible()
	tickClock()
	log:Debug("HUD ready")
end

return HUDController
