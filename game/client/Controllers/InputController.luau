--!strict
--[[
	InputController: turns PC, touch and gamepad input into the game's actions (bible Section 9,
	Controls; Section 23).

	* Device: "Keyboard" (mouse and keyboard), "Gamepad" or "Touch", from the last input used;
	  DeviceChanged fires when it changes.
	* Actions: the bible's controls table (BINDINGS). A controller listens with
	  InputController:On(action, began, ended?); the action is bound with ContextActionService
	  above Roblox's own bindings the first time someone listens. Touch buttons from the HUD
	  join with InputController:BindButton(action, button). Jump and moving stay Roblox's.
	* Look and zoom: mouse movement (while the mouse is locked), the right stick, a one-finger
	  drag on open screen and a two-finger pinch are gathered between frames; the camera takes
	  them with TakeLook(dt) (degrees) and TakeZoom() (studs, positive = farther).
	* Touches that start on a GUI or Roblox's thumbstick are the GUI's, never the camera's.
	* Block(reason, true) holds gameplay actions off while a menu is open: new presses are
	  ignored and anything held is released. Command View still passes, so its key can close
	  the docked Frame.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraRig = require(Shared.Rules.CameraRig)
local Log = require(Shared.Utilities.Log)
local Signal = require(Shared.Utilities.Signal)

local log = Log.new("InputController")

export type Device = "Keyboard" | "Gamepad" | "Touch"

-- Section 9's controls table. Touch buttons come from the HUD (BindButton).
local BINDINGS: { [string]: { Enum.KeyCode | Enum.UserInputType } } = {
	Fire = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Aim = { Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2 },
	Melee = { Enum.KeyCode.F, Enum.KeyCode.ButtonR1 },
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonX }, -- a tap of X on console
	Interact = { Enum.KeyCode.E, Enum.KeyCode.ButtonX }, -- a hold of X on console
	Ability = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1 },
	Sprint = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 },
	Dodge = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB },
	SwapShoulder = { Enum.KeyCode.V, Enum.KeyCode.ButtonR3 },
	HotbarNext = { Enum.KeyCode.DPadRight },
	HotbarPrevious = { Enum.KeyCode.DPadLeft },
	Hotbar1 = { Enum.KeyCode.One },
	Hotbar2 = { Enum.KeyCode.Two },
	Hotbar3 = { Enum.KeyCode.Three },
	Hotbar4 = { Enum.KeyCode.Four },
	Hotbar5 = { Enum.KeyCode.Five },
	Ping = { Enum.KeyCode.G, Enum.KeyCode.DPadUp },
	CommandView = { Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect },
}
local PRIORITY = Enum.ContextActionPriority.High.Value + 10
local NEVER_BLOCKED: { [string]: boolean } = { CommandView = true }
-- Keys the engine marks as processed before ContextActionService sees them begin (Tab: Roblox
-- keeps it for its player list and UI navigation; the gamepad's View button: Roblox's own UI
-- selection, which Init turns off). These are read from UserInputService too, unless a text box
-- has focus or Roblox's menu is open.
local PROCESSED_KEYS: { [Enum.KeyCode]: string } =
	{ [Enum.KeyCode.Tab] = "CommandView", [Enum.KeyCode.ButtonSelect] = "CommandView" }

type Listener = { Began: (() -> ())?, Ended: (() -> ())? }

local InputController = {
	Name = "InputController",
	Dependencies = {},
	DeviceChanged = Signal.new(),
}

local device: Device = "Keyboard"
local listeners: { [string]: { Listener } } = {}
local held: { [string]: { [any]: boolean } } = {}
local bound: { [string]: boolean } = {}
local blocked: { [string]: boolean } = {}

local mouseLook = Vector2.zero -- pixels since the last TakeLook
local touchLook = Vector2.zero
local stick = Vector2.zero -- the right stick, -1 to 1
local zoom = 0 -- studs since the last TakeZoom
local touches: { [InputObject]: Vector2 } = {} -- camera touches and where they were last
local pinchGap: number? = nil

-- The player's own Roblox camera sensitivity (Settings menu), read each frame.
local gameSettings: any = nil
local function robloxSensitivity(key: string): number
	if not gameSettings then
		return 1
	end
	local ok, value = pcall(function()
		return gameSettings[key]
	end)
	return if ok and type(value) == "number" and value > 0 then value else 1
end

local function deviceOf(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(inputType.Name, "^Gamepad") then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "^Mouse") then
		return "Keyboard"
	end
	return nil
end

local function setDevice(inputType: Enum.UserInputType)
	local found = deviceOf(inputType)
	if found and found ~= device then
		device = found
		InputController.DeviceChanged:Fire(device)
	end
end

-- An action's state from one source (a key, a button); began on the first, ended on the last.
local function press(action: string, source: any, down: boolean)
	local sources = held[action]
	if not sources then
		sources = {}
		held[action] = sources
	end
	local wasDown = next(sources) ~= nil
	if down and not wasDown and next(blocked) ~= nil and not NEVER_BLOCKED[action] then
		return
	end
	sources[source] = if down then true else nil
	local isDown = next(sources) ~= nil
	if isDown == wasDown then
		return
	end
	for _, listener in listeners[action] or {} do
		local handler = if isDown then listener.Began else listener.Ended
		if handler then
			task.spawn(handler)
		end
	end
end

local function bind(action: string)
	local inputs = BINDINGS[action]
	if bound[action] or not inputs then
		return
	end
	bound[action] = true
	ContextActionService:BindActionAtPriority(
		"100Y_" .. action,
		function(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				press(action, input.KeyCode.Name .. input.UserInputType.Name, true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				press(action, input.KeyCode.Name .. input.UserInputType.Name, false)
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		PRIORITY,
		table.unpack(inputs)
	)
end

-- Listens to an action. Returns a function that stops listening.
function InputController:On(action: string, began: (() -> ())?, ended: (() -> ())?): () -> ()
	assert(BINDINGS[action], `InputController: unknown action {action}`)
	local list = listeners[action]
	if not list then
		list = {}
		listeners[action] = list
	end
	local listener: Listener = { Began = began, Ended = ended }
	table.insert(list, listener)
	bind(action)
	return function()
		local index = table.find(list, listener)
		if index then
			table.remove(list, index)
		end
	end
end

-- Is the action held right now (by any key, button or touch button)?
function InputController:IsDown(action: string): boolean
	local sources = held[action]
	return sources ~= nil and next(sources) ~= nil
end

-- A HUD touch button drives an action while it is pressed. Returns a cleanup function.
function InputController:BindButton(action: string, button: GuiButton): () -> ()
	assert(BINDINGS[action], `InputController: unknown action {action}`)
	local down = button.MouseButton1Down:Connect(function()
		press(action, button, true)
	end)
	local up = button.MouseButton1Up:Connect(function()
		press(action, button, false)
	end)
	local left = button.MouseLeave:Connect(function()
		press(action, button, false)
	end)
	return function()
		down:Disconnect()
		up:Disconnect()
		left:Disconnect()
		press(action, button, false)
	end
end

-- Presses or releases an action from code (DevTools, tests, a toggle on touch).
function InputController:Press(action: string, down: boolean, source: string?)
	assert(BINDINGS[action], `InputController: unknown action {action}`)
	press(action, source or "code", down)
end

function InputController:Device(): Device
	return device
end

-- Holds gameplay actions off while a menu is open (reason: the menu's name).
function InputController:Block(reason: string, on: boolean)
	blocked[reason] = if on then true else nil
	if on then
		for action, sources in held do
			if not NEVER_BLOCKED[action] then
				for source in sources do
					press(action, source, false)
				end
			end
		end
	end
end

function InputController:IsBlocked(): boolean
	return next(blocked) ~= nil
end

-- Look input since the last call, in degrees (X turns, Y tilts; positive = right and down).
function InputController:TakeLook(dt: number): Vector2
	local t = CameraRig.Tuning()
	local degrees = mouseLook * t.MouseDegreesPerPixel * robloxSensitivity("MouseSensitivity")
		+ touchLook * t.TouchDegreesPerPixel * robloxSensitivity("MouseSensitivity")
		+ CameraRig.Stick(stick, t.StickDeadzone) * Vector2.new(1, -1) * t.GamepadDegreesPerSecond * dt
			* robloxSensitivity("GamepadCameraSensitivity")
	mouseLook = Vector2.zero
	touchLook = Vector2.zero
	return degrees
end

-- Zoom input since the last call, in studs (positive = farther).
function InputController:TakeZoom(): number
	local value = zoom
	zoom = 0
	return value
end

function InputController:Init()
	local ok, settings = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)
	gameSettings = if ok then settings else nil
	device = deviceOf(UserInputService:GetLastInputType())
		or (if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch" else "Keyboard")
	-- The View button opens the Command View (bible Section 7); with this on, Roblox takes that
	-- button for its own UI selection. Our screens select for the gamepad themselves (UIController).
	GuiService.AutoSelectGuiEnabled = false
end

function InputController:Start()
	UserInputService.LastInputTypeChanged:Connect(setDevice)
	UserInputService.InputBegan:Connect(function(io: InputObject, processed: boolean)
		local action = PROCESSED_KEYS[io.KeyCode]
		if action and processed and bound[action] and not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen then
			press(action, "Processed" .. io.KeyCode.Name, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(io: InputObject)
		local action = PROCESSED_KEYS[io.KeyCode]
		if action then
			press(action, "Processed" .. io.KeyCode.Name, false)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				mouseLook += Vector2.new(input.Delta.X, input.Delta.Y)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			if not processed then
				zoom -= input.Position.Z * CameraRig.Tuning().ZoomStep
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.zero
		end
	end)

	-- Touch: a drag on open screen looks around; two fingers pinch to zoom.
	UserInputService.TouchStarted:Connect(function(touch: InputObject, processed: boolean)
		if not processed then
			touches[touch] = Vector2.new(touch.Position.X, touch.Position.Y)
			pinchGap = nil
		end
	end)
	UserInputService.TouchMoved:Connect(function(touch: InputObject)
		local last = touches[touch]
		if not last then
			return
		end
		local now = Vector2.new(touch.Position.X, touch.Position.Y)
		touches[touch] = now
		local live = {}
		for other, at in touches do
			table.insert(live, at)
		end
		if #live >= 2 then
			local gap = (live[1] - live[2]).Magnitude
			if pinchGap then
				zoom -= (gap - pinchGap) * CameraRig.Tuning().PinchStudsPerPixel
			end
			pinchGap = gap
		else
			touchLook += now - last
		end
	end)
	UserInputService.TouchEnded:Connect(function(touch: InputObject)
		touches[touch] = nil
		pinchGap = nil
	end)
	log:Debug("input ready (%s)", device)
end

return InputController
