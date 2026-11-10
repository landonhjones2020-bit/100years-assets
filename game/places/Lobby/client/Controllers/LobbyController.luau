--!strict
--[[
	LobbyController: what stays on screen in the lobby (bible Sections 18 and 21). Lobby only;
	Prompt 21. The layout is StarterGui.Lobby (studio/ui/Lobby.lua); this fills it.

	* Class: the equipped class (its icon, name and level, from the profile's Loadout); a press
	  opens the Loadout. Buttons under it open the Class Shop (K, D-pad up) and the Loadout (L,
	  D-pad down).
	* The camera holds the mouse, as in a run: every button carries its key (KEYS; the chips follow
	  the device), and a click of the mouse wheel frees the cursor to click instead (the HUD's rule,
	  Landon 2026-11-08).
	* Wallet: the profile's Glowshards.
	* Alert: the server's messages (the Alert remote: a purchase, a refusal, an invitation) for a
	  few seconds, with the lamp in the kind's colour; while a Frame screen is open the message
	  goes to its footer too (UIController:Notice).
	* The showroom's booths: a ProximityPrompt with a `LobbyAction` attribute ("ClassShop" or
	  "Loadout") is drawn in the Steadfast style (Lobby.Templates.Prompt) and opens that screen.
	* Rejoin: the card shows while the Player's RejoinOffer attribute is set (RejoinService): REJOIN
	  (R, Y on a controller) or NOT NOW (N, B).
	* While a Frame screen is open the lobby GUI hides, as the HUD does in a run.

	Gui(): the lobby's ScreenGui (PadController fills its Pad and Invite panels).
	SetKey(chip, keyboard, gamepad): a key chip's text for the device in use (hidden on touch).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local ClassArt = require(Lib:WaitForChild("ClassArt"))
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local log = Log.new("LobbyController")
local player = Players.LocalPlayer

local LobbyController = {
	Name = "LobbyController",
	Dependencies = { "UIController", "ReplicaController", "CameraController", "InputController", "ClassShopController" },
}

local ui: any = nil
local replica: any = nil
local camera: any = nil
local input: any = nil
local gui: ScreenGui? = nil
local cursorFree = false

local ALERT_SECONDS = 4.5
local LAMPS: { [string]: string } = { Danger = "Lamp_Red", Warning = "Lamp_Amber", Info = "Lamp_Green" }
local alertToken = 0
local prompts: { [ProximityPrompt]: BillboardGui } = {}

local function part(path: string): any
	local at: Instance = gui :: ScreenGui
	for _, name in string.split(path, ".") do
		at = at:WaitForChild(name)
	end
	return at
end

-- The lobby's ScreenGui, once it exists (PadController fills part of it).
function LobbyController:Gui(): ScreenGui?
	return gui
end

-- A button's key chip (an ImageLabel with a Text label) for the device in use.
function LobbyController:SetKey(chip: any, keyboard: string, gamepad: string)
	local device = input:Device()
	local label = if device == "Keyboard" then keyboard elseif device == "Gamepad" then gamepad else ""
	chip.Visible = label ~= ""
	chip.Text.Text = label
end

local function refreshKeys()
	if not gui then
		return
	end
	LobbyController:SetKey(part("Buttons.Shop.Content.Key"), "K", "UP")
	LobbyController:SetKey(part("Buttons.Loadout.Content.Key"), "L", "DOWN")
	LobbyController:SetKey(part("Rejoin.Yes.Content.Key"), "R", "Y")
	LobbyController:SetKey(part("Rejoin.No.Content.Key"), "N", "B")
end

local function profile(): any
	local found = replica:Get("Profiles", tostring(player.UserId))
	return if type(found) == "table" and type(found.Classes) == "table" then found else nil
end

local function fillPlate()
	if not gui then
		return
	end
	local data = profile()
	local classId = if data and data.Loadout and Config.Find("Classes", data.Loadout.Class) then data.Loadout.Class else "Survivor"
	local class = Config.Get("Classes", classId)
	local owned = data and data.Classes[classId]
	KitRuntime.SetSprite(part("Class.Well.Icon"), ClassArt.Icon(classId))
	part("Class.Name").Text = string.upper(class.Name)
	part("Class.Sub").Text = if owned then `LEVEL {owned.Level}  ·  EQUIPPED` else "FREE TRIAL  ·  EQUIPPED"
	part("Wallet.Amount").Text = if data then tostring(data.Glowshards) else "—"
end

local function showAlert(kind: string, text: string)
	if ui:IsOpen() then
		ui:Notice(text, kind)
	end
	if not gui then
		return
	end
	alertToken += 1
	local token = alertToken
	local strip = part("Alert")
	KitRuntime.SetSprite(part("Alert.Lamp"), LAMPS[kind] or "Lamp_Green")
	part("Alert.Text").Text = string.upper(text)
	strip.Visible = true
	task.delay(ALERT_SECONDS, function()
		if token == alertToken then
			strip.Visible = false
		end
	end)
end

-- Booth prompts -------------------------------------------------------------------------------------

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function hidePrompt(prompt: ProximityPrompt)
	local shown = prompts[prompt]
	if shown then
		prompts[prompt] = nil
		shown:Destroy()
	end
end

local function showPrompt(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or type(prompt:GetAttribute("LobbyAction")) ~= "string" or not gui then
		return
	end
	hidePrompt(prompt)
	local base = part("Templates.Prompt") :: BillboardGui
	local board = base:Clone()
	board.Name = "Prompt_" .. prompt.ActionText
	board.Adornee = prompt.Parent :: any
	board.Enabled = true
	local plate: any = board:FindFirstChild("Plate")
	plate.Key.Text.Text = keyText(prompt, inputType)
	plate.Action.Text = string.upper(prompt.ActionText)
	plate.Object.Text = prompt.ObjectText
	plate.Activated:Connect(function() -- on touch the plate is the button
		prompt:InputHoldBegin()
		prompt:InputHoldEnd()
	end)
	board.Parent = player:WaitForChild("PlayerGui")
	prompts[prompt] = board
end

local function onTriggered(prompt: ProximityPrompt)
	local action = prompt:GetAttribute("LobbyAction")
	if action == "ClassShop" or action == "Loadout" then
		ui:Open(action)
	end
end

local function fillRejoin()
	if not gui then
		return
	end
	local offer = player:GetAttribute("RejoinOffer")
	part("Rejoin").Visible = type(offer) == "string"
	if type(offer) == "string" then
		part("Rejoin.Sub").Text = string.upper(`{offer}  ·  YOUR CREW IS HOLDING THE BUNKER`)
	end
end

function LobbyController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
	camera = registry.CameraController
	input = registry.InputController
end

function LobbyController:Start()
	if Constants.PlaceKind() ~= "Lobby" then
		return
	end
	Remotes.OnClient("Alert", function(kind: any, text: any)
		if type(text) == "string" then
			showAlert(if type(kind) == "string" then kind else "Info", text)
		end
	end)
	ProximityPromptService.PromptShown:Connect(showPrompt)
	ProximityPromptService.PromptHidden:Connect(hidePrompt)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	task.spawn(function()
		local found = player:WaitForChild("PlayerGui"):WaitForChild("Lobby", 30)
		if not found or not found:IsA("ScreenGui") then
			log:Warn("StarterGui.Lobby is missing: build it with studio/ui/Lobby.lua")
			return
		end
		gui = found
		KitRuntime.Watch(found)
		part("Class").Activated:Connect(function()
			ui:Open("Loadout")
		end)
		part("Buttons.Shop").Activated:Connect(function()
			ui:Open("ClassShop")
		end)
		part("Buttons.Loadout").Activated:Connect(function()
			ui:Open("Loadout")
		end)
		part("Rejoin.Yes").Activated:Connect(function()
			Remotes.FireServer("RejoinRun")
		end)
		part("Rejoin.No").Activated:Connect(function()
			Remotes.FireServer("RejoinDismiss")
		end)
		fillPlate()
		fillRejoin()
		refreshKeys()
		input.DeviceChanged:Connect(refreshKeys)
		replica:Changed("Profiles"):Connect(fillPlate)
		player:GetAttributeChangedSignal("RejoinOffer"):Connect(fillRejoin)
		ui.Opened:Connect(function()
			found.Enabled = false
			if cursorFree then -- the menu frees its own
				cursorFree = false
				camera:FreeCursor("LobbyCursor", false)
			end
		end)
		ui.Closed:Connect(function()
			found.Enabled = true
		end)
		found.Enabled = not ui:IsOpen()
	end)
	-- the camera locks the mouse; a click of the wheel frees the cursor, another locks it again
	UserInputService.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.MouseButton3 and not ui:IsOpen() then
			cursorFree = not cursorFree
			camera:FreeCursor("LobbyCursor", cursorFree)
		end
	end)
	local SHOP: { [Enum.KeyCode]: boolean } = { [Enum.KeyCode.K] = true, [Enum.KeyCode.DPadUp] = true }
	ContextActionService:BindAction("100Y_LobbyScreens", function(_name: string, state: Enum.UserInputState, io: InputObject)
		if state == Enum.UserInputState.Begin and not ui:IsOpen() then
			ui:Open(if SHOP[io.KeyCode] then "ClassShop" else "Loadout")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.K, Enum.KeyCode.L, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown)
	local YES: { [Enum.KeyCode]: boolean } = { [Enum.KeyCode.R] = true, [Enum.KeyCode.ButtonY] = true }
	ContextActionService:BindAction("100Y_LobbyRejoin", function(_name: string, state: Enum.UserInputState, io: InputObject)
		if state == Enum.UserInputState.Begin and not ui:IsOpen() and type(player:GetAttribute("RejoinOffer")) == "string" then
			Remotes.FireServer(if YES[io.KeyCode] then "RejoinRun" else "RejoinDismiss")
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.N, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)
end

return LobbyController
