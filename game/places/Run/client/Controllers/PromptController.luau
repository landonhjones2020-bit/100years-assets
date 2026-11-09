--!strict
--[[
	PromptController: the game's interaction prompts in the Steadfast style (bible Section 18:
	nothing may look like generic Roblox UI). Run place only; Prompt 11.

	Every ProximityPrompt the game makes uses the Custom style (reviving a teammate or a
	resident, restocking ammo); this draws it from HUD.Templates.Prompt: a cream enamel plate
	with the key's chip (E on a keyboard, X on a controller, HOLD on touch), the action and what
	it acts on, and a gauge that fills while the key is held.

	* On touch the plate itself is the button: pressing it holds the prompt.
	* A prompt with an Owner attribute equal to this player's UserId isn't shown: your own
	  revive prompt is for your teammates.
	* Holding a Revive prompt plays the kneel clip, if it exists (CombatController.Kneel).
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local PromptController = {
	Name = "PromptController",
	Dependencies = { "HUDController", "CombatController" },
}

local combat: any = nil
local shown: { [ProximityPrompt]: { Gui: BillboardGui, Tween: Tween?, Connections: { RBXScriptConnection } } } = {}

local function template(): BillboardGui?
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HUD")
	local templates = hud and hud:FindFirstChild("Templates")
	local found = templates and templates:FindFirstChild("Prompt")
	return if found and found:IsA("BillboardGui") then found else nil
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (string.gsub(name, "^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return if prompt.HoldDuration > 0 then "HOLD" else "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function fillOf(gui: BillboardGui): Frame?
	local fill = gui:FindFirstChild("Fill", true)
	return if fill and fill:IsA("Frame") then fill else nil
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if not entry then
		return
	end
	shown[prompt] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	if entry.Tween then
		entry.Tween:Cancel()
	end
	entry.Gui:Destroy()
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	if prompt:GetAttribute("Owner") == player.UserId then
		return
	end
	hide(prompt)
	local base = template()
	if not base then
		return
	end
	local gui = base:Clone()
	gui.Name = "Prompt_" .. prompt.ActionText
	gui.Adornee = prompt.Parent :: any
	gui.Enabled = true
	local plate = gui:FindFirstChild("Plate") :: ImageButton?
	local key = gui:FindFirstChild("Key", true)
	local keyLabel = key and key:FindFirstChild("Text") :: TextLabel?
	local action = gui:FindFirstChild("Action", true) :: TextLabel?
	local object = gui:FindFirstChild("Object", true) :: TextLabel?
	local gauge = gui:FindFirstChild("Gauge", true) :: GuiObject?
	if keyLabel then
		keyLabel.Text = keyText(prompt, inputType)
	end
	if action then
		action.Text = string.upper(prompt.ActionText)
	end
	if object then
		object.Text = prompt.ObjectText
	end
	if gauge then
		gauge.Visible = prompt.HoldDuration > 0
	end
	local entry = { Gui = gui, Tween = nil :: Tween?, Connections = {} :: { RBXScriptConnection } }
	shown[prompt] = entry
	local fill = fillOf(gui)

	table.insert(entry.Connections, prompt.PromptButtonHoldBegan:Connect(function()
		if fill then
			fill.Size = UDim2.fromScale(0, 1)
			entry.Tween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			entry.Tween:Play()
		end
		if prompt:GetAttribute("Kind") == "Revive" or prompt:GetAttribute("Kind") == "ReviveResident" then
			combat:Kneel(true)
		end
	end))
	table.insert(entry.Connections, prompt.PromptButtonHoldEnded:Connect(function()
		if entry.Tween then
			entry.Tween:Cancel()
			entry.Tween = nil
		end
		if fill then
			fill.Size = UDim2.fromScale(0, 1)
		end
		combat:Kneel(false)
	end))
	if plate and inputType == Enum.ProximityPromptInputType.Touch then
		table.insert(entry.Connections, plate.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(entry.Connections, plate.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
	end
	gui.Parent = player:FindFirstChild("PlayerGui")
end

function PromptController:Init(registry)
	combat = registry.CombatController
end

function PromptController:Start()
	ProximityPromptService.PromptShown:Connect(show)
	ProximityPromptService.PromptHidden:Connect(hide)
end

return PromptController
