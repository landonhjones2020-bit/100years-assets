--!strict
--[[
	UIController: The Frame (bible Section 18), the one layout every menu screen uses.

	The layout is StarterGui.Frame, built in Studio (studio/ui/Frame.lua) and given the
	AutoScale Lite pass; this controller only shows pages, clones templates and sets text and
	images. A screen registers once and opens by name:

		UIController:Register("Residents", {
			Title = "RESIDENTS",
			Subtitle = "STEADFAST SHELTER CO.  ·  PERSONNEL FILE",
			Tabs = { { Id = "All", Label = "ALL", Icon = "Icon_Grid" }, ... },  -- zone B, up to 7
			Layout = "Grid",       -- zone C: "Grid" (cards, always 1:1.25) or "List" (rows)
			Page = nil,            -- a page built for this screen under Cabinet.Pages; default: a clone of Templates.Page
			Docked = false,        -- the Command View: zone C shows the live bunker
			Hint = "...",          -- zone E
			OnOpen = function(page, args) end,
			OnTab = function(tabId, page) end,
			OnClose = function() end,
		})
		UIController:Open("Residents", args)

	Zone A shows the title and SetChips; zone D's main action is SetMainAction (the same place
	on every screen); zone E is SetHint and SetFooterActions. Code fills zones B to D with
	Clone("Card"), Clone("Row"), Clone("Section") and the Fill helpers.

	While a screen is open the mouse cursor is free, gameplay input is held off, and the HUD
	hides (HUDController listens to Opened and Closed). Keys: Backspace or the gamepad's B
	closes; Enter or Y presses the main action; L1 and R1 switch tabs.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)
local UIContract = require(Shared.UIContract)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local log = Log.new("UIController")

export type Tab = { Id: string, Label: string, Icon: string? }
export type Screen = {
	Title: string,
	Subtitle: string?,
	Tabs: { Tab }?,
	Layout: string?,
	Page: string?,
	Docked: boolean?,
	Hint: string?,
	GamepadSelect: boolean?, -- false: no gamepad selection (the screen uses A itself)
	OnOpen: ((page: Frame, args: any) -> ())?,
	OnTab: ((tabId: string, page: Frame) -> ())?,
	OnClose: (() -> ())?,
}
export type MainAction = { Label: string, Price: string?, Icon: string?, Enabled: boolean?, OnPress: (() -> ())? }
export type Chip = { Icon: string, Text: string }
export type FooterAction = { Label: string, OnPress: () -> () }

local CLOSE_ACTION = "100Y_UIClose"
local MAIN_ACTION = "100Y_UIMain"
local TAB_ACTION = "100Y_UITab"
local PRIORITY = Enum.ContextActionPriority.High.Value + 20
local RARITIES = { Common = true, Rare = true, Epic = true, Legendary = true }

local UIController = {
	Name = "UIController",
	Dependencies = { "InputController", "CameraController" },
	Opened = Signal.new() :: Signal.Signal<string>,
	Closed = Signal.new() :: Signal.Signal<string>,
	TabChanged = Signal.new() :: Signal.Signal<string>,
}

local input: any = nil
local camera: any = nil
local gui: ScreenGui? = nil
local screens: { [string]: Screen } = {}
local pages: { [string]: Frame } = {}
local current: string? = nil
local currentTab: string? = nil
local mainPress: (() -> ())? = nil
local tabButtons: { [string]: ImageButton } = {}
local footerConnections: { RBXScriptConnection } = {}
local tabConnections: { RBXScriptConnection } = {}

local function part(path: string): any
	assert(gui, "UIController: StarterGui.Frame is missing")
	local found = UIContract.Find(gui, path)
	assert(found, `UIController: Frame.{path} is missing (see Shared.UIContract)`)
	return found
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function disconnectAll(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

local function keysText(screen: Screen): string
	local device = input:Device()
	local action = if mainPress then string.upper(part("Cabinet.MainAction.Content.Label").Text) else nil
	if device == "Gamepad" then
		local tabs = if screen.Tabs and #screen.Tabs > 1 then "     LB  RB  TABS" else ""
		return "B  CLOSE" .. (if action then `     Y  {action}` else "") .. tabs
	elseif device == "Keyboard" then
		return "BACKSPACE  CLOSE" .. (if action then `     ENTER  {action}` else "")
	end
	return ""
end

local function refreshKeys()
	if current then
		part("Cabinet.Footer.Keys").Text = keysText(screens[current])
	end
end

local function selectTab(id: string)
	if not current then
		return
	end
	local screen = screens[current]
	for tabId, button in tabButtons do
		local on = tabId == id
		KitRuntime.SetSprite(button, if on then "Tab_On" else "Tab_Off")
		local content = button:FindFirstChild("Content")
		if content then
			local icon = content:FindFirstChild("Icon") :: ImageLabel?
			local label = content:FindFirstChild("Label") :: TextLabel?
			local color = if on then Color3.fromHex("#F2E6C9") else Color3.fromHex("#1B2A3A")
			if icon then
				icon.ImageColor3 = color
			end
			if label then
				label.TextColor3 = color
			end
		end
	end
	currentTab = id
	UIController.TabChanged:Fire(id)
	local page = pages[current]
	if screen.OnTab and page then
		task.spawn(screen.OnTab, id, page)
	end
end

local function stepTab(step: number)
	local screen = if current then screens[current] else nil
	if not screen or not screen.Tabs or #screen.Tabs < 2 then
		return
	end
	local index = 1
	for i, tab in screen.Tabs do
		if tab.Id == currentTab then
			index = i
		end
	end
	index = (index - 1 + step) % #screen.Tabs + 1
	selectTab(screen.Tabs[index].Id)
end

local function pageFor(name: string, screen: Screen): Frame
	local existing = pages[name]
	if existing and existing.Parent then
		return existing
	end
	local holder = part("Cabinet.Pages")
	local built = holder:FindFirstChild(screen.Page or name)
	local page: Frame
	if built and built:IsA("Frame") then
		page = built
	else
		page = UIController:Clone("Page") :: any
		page.Name = name
		page.Parent = holder
	end
	page.Visible = false
	pages[name] = page
	return page
end

local function bindKeys(on: boolean)
	if not on then
		ContextActionService:UnbindAction(CLOSE_ACTION)
		ContextActionService:UnbindAction(MAIN_ACTION)
		ContextActionService:UnbindAction(TAB_ACTION)
		return
	end
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			UIController:Close()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority(MAIN_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			UIController:PressMainAction()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority(TAB_ACTION, function(_, state, inputObject)
		if state == Enum.UserInputState.Begin then
			stepTab(if inputObject.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
end

-- API -----------------------------------------------------------------------------------------

function UIController:Register(name: string, screen: Screen)
	assert(not screens[name], `UIController: {name} is registered twice`)
	assert(screen.Title, `UIController: {name} has no title`)
	assert(not screen.Tabs or #screen.Tabs <= 7, `UIController: {name} has more than 7 tabs`)
	screens[name] = screen
end

function UIController:IsRegistered(name: string): boolean
	return screens[name] ~= nil
end

function UIController:Open(name: string, args: any?): boolean
	local screen = screens[name]
	if not screen or not gui then
		log:Warn("can't open %s: %s", name, if gui then "not registered" else "no Frame")
		return false
	end
	if current == name then
		return true
	end
	if current then
		UIController:Close()
	end
	local page = pageFor(name, screen)
	current = name
	gui.Enabled = true
	local docked = screen.Docked == true
	part("Dim").Visible = not docked
	part("Cabinet.Backplate").Visible = not docked
	part("Cabinet.DockPlates").Visible = docked
	part("Cabinet.TopBar.Title.Text").Text = string.upper(screen.Title)
	part("Cabinet.TopBar.Subtitle").Text = screen.Subtitle or "STEADFAST SHELTER CO."
	UIController:SetChips({})
	UIController:SetHint(screen.Hint or "")
	UIController:SetFooterActions({})
	UIController:SetMainAction(nil)
	local content = page:FindFirstChild("Content")
	if content then
		local layout = screen.Layout or "Grid"
		local grid = content:FindFirstChild("Grid")
		local rows = content:FindFirstChild("List")
		if grid and grid:IsA("GuiObject") then
			grid.Visible = layout == "Grid"
		end
		if rows and rows:IsA("GuiObject") then
			rows.Visible = layout == "List"
		end
	end
	-- zone B
	disconnectAll(tabConnections)
	table.clear(tabButtons)
	local rail = page:FindFirstChild("Tabs")
	if rail then
		clear(rail)
		for i, tab in screen.Tabs or {} do
			local button = UIController:Clone("Tab") :: ImageButton
			button.Name = tab.Id
			button.LayoutOrder = i
			local tabContent = button:FindFirstChild("Content") :: Frame
			local label = tabContent:FindFirstChild("Label") :: TextLabel
			local icon = tabContent:FindFirstChild("Icon") :: ImageLabel
			label.Text = string.upper(tab.Label)
			if tab.Icon then
				KitRuntime.SetSprite(icon, tab.Icon)
			else
				icon.Visible = false
			end
			button.Parent = rail
			tabButtons[tab.Id] = button
			table.insert(tabConnections, button.Activated:Connect(function()
				selectTab(tab.Id)
			end))
		end
	end
	page.Visible = true
	input:Block("Frame", true)
	camera:FreeCursor("Frame", true)
	camera:SetAiming(false)
	bindKeys(true)
	if screen.OnOpen then
		local ok, err = pcall(screen.OnOpen, page, args)
		if not ok then
			log:Warn("%s OnOpen failed: %s", name, tostring(err))
		end
	end
	if screen.Tabs and #screen.Tabs > 0 then
		selectTab(screen.Tabs[1].Id)
	end
	refreshKeys()
	if input:Device() == "Gamepad" and screen.GamepadSelect ~= false then
		GuiService.SelectedObject = (if screen.Tabs and #screen.Tabs > 0 then tabButtons[screen.Tabs[1].Id] else nil)
			or part("Cabinet.TopBar.Close")
	end
	log:Debug("opened %s", name)
	UIController.Opened:Fire(name)
	return true
end

function UIController:Close()
	local name = current
	if not name or not gui then
		return
	end
	local screen = screens[name]
	local page = pages[name]
	if page then
		page.Visible = false
	end
	current = nil
	currentTab = nil
	mainPress = nil
	disconnectAll(tabConnections)
	disconnectAll(footerConnections)
	gui.Enabled = false
	bindKeys(false)
	input:Block("Frame", false)
	camera:FreeCursor("Frame", false)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if screen and screen.OnClose then
		task.spawn(screen.OnClose)
	end
	log:Debug("closed %s", name)
	UIController.Closed:Fire(name)
end

function UIController:IsOpen(): boolean
	return current ~= nil
end

function UIController:Current(): string?
	return current
end

function UIController:CurrentTab(): string?
	return currentTab
end

function UIController:Page(): Frame?
	return if current then pages[current] else nil
end

function UIController:SelectTab(id: string)
	if tabButtons[id] then
		selectTab(id)
	end
end

-- Zone D's main action (nil hides it). Enabled = false greys it out.
function UIController:SetMainAction(action: MainAction?)
	local button = part("Cabinet.MainAction") :: ImageButton
	if not action then
		button.Visible = false
		mainPress = nil
		refreshKeys()
		return
	end
	button.Visible = true
	part("Cabinet.MainAction.Content.Label").Text = string.upper(action.Label)
	local icon = part("Cabinet.MainAction.Content.Icon") :: ImageLabel
	local price = part("Cabinet.MainAction.Content.Price") :: TextLabel
	icon.Visible = action.Icon ~= nil
	if action.Icon then
		KitRuntime.SetSprite(icon, action.Icon)
	end
	price.Text = action.Price or ""
	price.Visible = action.Price ~= nil
	KitRuntime.SetEnabled(button, action.Enabled ~= false)
	mainPress = if action.Enabled ~= false then action.OnPress else nil
	refreshKeys()
end

function UIController:PressMainAction()
	local press = mainPress
	if press and current then
		task.spawn(press)
	end
end

-- Zone A's chips (currencies or resources), right to left as listed.
function UIController:SetChips(chips: { Chip })
	local holder = part("Cabinet.TopBar.Chips")
	clear(holder)
	for i, chip in chips do
		local item = UIController:Clone("Chip")
		item.LayoutOrder = i
		KitRuntime.SetSprite(item:FindFirstChild("Icon") :: ImageLabel, chip.Icon)
		local amount = item:FindFirstChild("Amount") :: TextLabel
		amount.Text = chip.Text
		item.Parent = holder
	end
end

local noticeToken = 0
local restingHint: { Text: string, Color: Color3 }? = nil -- the screen's own hint, under a notice
local NOTICE_SECONDS = 4
local NOTICE_COLORS: { [string]: Color3 } = { Warning = Color3.fromHex("#F2C14E"), Danger = Color3.fromHex("#F2C14E") }

function UIController:SetHint(text: string)
	if restingHint then
		restingHint.Text = text -- a notice is showing: the hint comes back after it
	else
		part("Cabinet.Footer.Hint").Text = text
	end
end

-- A message in the footer (zone E) for a few seconds, then the screen's hint again: the HUD's
-- alerts while a screen hides the HUD (a refused proposal in the Command View).
function UIController:Notice(text: string, kind: string?)
	local hint = part("Cabinet.Footer.Hint")
	if not restingHint then
		restingHint = { Text = hint.Text, Color = hint.TextColor3 }
	end
	noticeToken += 1
	local token = noticeToken
	hint.Text = string.upper(text)
	hint.TextColor3 = NOTICE_COLORS[kind or ""] or (restingHint :: any).Color
	task.delay(NOTICE_SECONDS, function()
		local resting = restingHint
		if token == noticeToken and resting then
			hint.Text = resting.Text
			hint.TextColor3 = resting.Color
			restingHint = nil
		end
	end)
end

-- Zone E's secondary actions (filters, sort, back).
function UIController:SetFooterActions(actions: { FooterAction })
	disconnectAll(footerConnections)
	local holder = part("Cabinet.Footer.Actions")
	clear(holder)
	for i, action in actions do
		local button = UIController:Clone("FooterButton") :: ImageButton
		button.LayoutOrder = i
		local label = (button:FindFirstChild("Content") :: Frame):FindFirstChild("Label") :: TextLabel
		label.Text = string.upper(action.Label)
		table.insert(footerConnections, button.Activated:Connect(function()
			task.spawn(action.OnPress)
		end))
		button.Parent = holder
	end
end

-- A visible copy of one of Frame.Templates (Page, Tab, Chip, Card, Row, Section, FooterButton).
function UIController:Clone(template: string): GuiObject
	local source = part("Templates." .. template)
	local copy = source:Clone() :: GuiObject
	copy.Visible = true
	return copy
end

function UIController:SetSprite(image: ImageLabel | ImageButton, name: string)
	KitRuntime.SetSprite(image, name)
end

-- A card, or a page's detail panel, in a rarity's colours (Common, Rare, Epic, Legendary).
function UIController:SetRarity(item: Instance, rarity: string)
	assert(RARITIES[rarity], `UIController: unknown rarity {rarity}`)
	local sprite = "Card_" .. rarity
	if item:IsA("ImageButton") or item:IsA("ImageLabel") then
		if item:GetAttribute("Sprite") and string.find(item:GetAttribute("Sprite") :: string, "^Card_") then
			KitRuntime.SetSprite(item, sprite)
		end
	end
	for _, name in { "Tag", "Hero" } do
		local child = item:FindFirstChild(name)
		if child and (child:IsA("ImageLabel") or child:IsA("ImageButton")) then
			KitRuntime.SetSprite(child, sprite)
		end
	end
end

-- Empties a container (zone B, C or D's Body) and returns it, for filling with clones.
function UIController:Clear(container: Instance): Instance
	clear(container)
	return container
end

function UIController:Gui(): ScreenGui?
	return gui
end

-- Lifecycle -----------------------------------------------------------------------------------

function UIController:Init(registry)
	input = registry.InputController
	camera = registry.CameraController
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local found = playerGui:WaitForChild("Frame", 20)
	if not found or not found:IsA("ScreenGui") then
		log:Warn("no Frame ScreenGui in this place; menu screens can't open")
		return
	end
	gui = found
	found.Enabled = false
	KitRuntime.Watch(found)
	local close = part("Cabinet.TopBar.Close") :: ImageButton
	close.Activated:Connect(function()
		UIController:Close()
	end)
	local main = part("Cabinet.MainAction") :: ImageButton
	main.Activated:Connect(function()
		UIController:PressMainAction()
	end)
	input.DeviceChanged:Connect(function(device: string)
		refreshKeys()
		-- a gamepad selection would swallow Enter on a keyboard (it clicks the selected button)
		local selected = GuiService.SelectedObject
		if device ~= "Gamepad" and selected and selected:IsDescendantOf(found) then
			GuiService.SelectedObject = nil
		elseif device == "Gamepad" and current and not selected and screens[current].GamepadSelect ~= false then
			local first = next(tabButtons)
			GuiService.SelectedObject = if first then tabButtons[first] else part("Cabinet.TopBar.Close")
		end
	end)
	log:Debug("the Frame is ready")
end

return UIController
