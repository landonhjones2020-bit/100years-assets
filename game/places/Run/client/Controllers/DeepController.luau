--!strict
--[[
	DeepController: what a player sees of the Deep (bible Sections 12, 14 and 18; Run place,
	Prompt 17). DeepService decides everything; the caves' darkness is SurfaceController's lighting.

	* Radio logs (Section 12): the RadioLog remote plays a log on a typed sheet of Steadfast paper
	  (Section 18: anything typed is Special Elite on paper) at the bottom of the screen: its title,
	  who it is from, the text typed out a few letters at a time, and, from a Lost Crew's log, where
	  they were last heard from. It goes after a while, or at once with a click or a tap on it.
	* The Spelunker's RevealCaveLayouts (Section 14: reveals cave layouts): underground, the finds
	  in the caves (ore veins, caches, radio logs, Glowshard chests, nests, cryo pods) and the
	  trapped (miners, Lost Crews) within Tuning.Deep.RevealRange show through the rock.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local Surface = require(Shared.Rules.Surface)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local UIKit = require(Lib:WaitForChild("UIKit"))

local log = Log.new("DeepController")
local player = Players.LocalPlayer

local DeepController = {
	Name = "DeepController",
	Dependencies = { "HUDController" },
}

local FONT = {
	title = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	typed = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	small = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold),
}
local COLOR = {
	navy = Color3.fromHex("#1B2A3A"),
	ink = Color3.fromHex("#2A3B4C"),
	teal = Color3.fromHex("#2F6F73"),
	signal = Color3.fromHex("#E8743B"),
	glow = Color3.fromHex("#7CFF9B"),
}
local TYPE_RATE = 70 -- letters a second
local READ_SECONDS = 9 -- on screen after the typing, plus a little a line

local hud: any = nil
local card: ImageButton? = nil
local showing = 0 -- the log being shown (a newer one replaces it)
local revealed: { [Instance]: Highlight } = {}

-- Radio logs ------------------------------------------------------------------------------------

local function label(parent: Instance, name: string, font: Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Position = position
	l.Size = size
	l.Text = ""
	l.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = 40
	limit.Parent = l
	return l
end

local function makeCard(gui: ScreenGui): ImageButton
	local paper = Instance.new("ImageButton")
	paper.Name = "RadioLog"
	paper.AutoButtonColor = false
	paper.AnchorPoint = Vector2.new(0.5, 1)
	paper.Position = UDim2.fromScale(0.5, 0.86)
	paper.Size = UDim2.fromScale(0.42, 0.25)
	paper.ZIndex = 40
	UIKit.apply(paper, "Paper")
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 2.8
	ratio.Parent = paper
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromScale(0.03, 0.08)
	icon.Size = UDim2.fromScale(0.09, 0.28)
	icon.ZIndex = 41
	UIKit.apply(icon, "Icon_Radio")
	icon.ImageColor3 = COLOR.teal
	icon.Parent = paper
	local title = label(paper, "Title", FONT.title, COLOR.navy, UDim2.fromScale(0.14, 0.08), UDim2.fromScale(0.8, 0.16))
	title.ZIndex = 41
	local from = label(paper, "From", FONT.small, COLOR.teal, UDim2.fromScale(0.14, 0.25), UDim2.fromScale(0.8, 0.1))
	from.ZIndex = 41
	local body = label(paper, "Body", FONT.typed, COLOR.ink, UDim2.fromScale(0.05, 0.38), UDim2.fromScale(0.9, 0.36))
	body.ZIndex = 41
	local hint = label(paper, "Hint", FONT.typed, COLOR.signal, UDim2.fromScale(0.05, 0.76), UDim2.fromScale(0.9, 0.17))
	hint.ZIndex = 41
	paper.Visible = false
	paper.Parent = gui
	paper.Activated:Connect(function()
		showing += 1
		paper.Visible = false
	end)
	return paper
end

local function onRadioLog(title: any, from: any, text: any, hint: any)
	local gui = hud:Gui()
	if not gui then
		return
	end
	local paper = card
	if not paper or not paper.Parent then
		paper = makeCard(gui)
		card = paper
	end
	local p = paper :: ImageButton
	showing += 1
	local mine = showing
	local body = p:FindFirstChild("Body") :: TextLabel
	local hintLabel = p:FindFirstChild("Hint") :: TextLabel
	;(p:FindFirstChild("Title") :: TextLabel).Text = string.upper(tostring(title))
	;(p:FindFirstChild("From") :: TextLabel).Text = `RADIO LOG · {string.upper(tostring(from))}`
	body.Text = tostring(text)
	body.MaxVisibleGraphemes = 0
	hintLabel.Text = if type(hint) == "string" and hint ~= "" then `Last heard from: {hint}.` else ""
	hintLabel.Visible = false
	p.Visible = true
	p.Position = UDim2.fromScale(0.5, 0.92)
	TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.86) }):Play()
	task.spawn(function()
		local total = utf8.len(body.Text) or #body.Text
		local typed = 0
		while typed < total and showing == mine do
			typed = math.min(typed + math.ceil(TYPE_RATE / 20), total)
			body.MaxVisibleGraphemes = typed
			task.wait(0.05)
		end
		if showing ~= mine then
			return
		end
		body.MaxVisibleGraphemes = -1
		hintLabel.Visible = hintLabel.Text ~= ""
		task.wait(READ_SECONDS + total / 60)
		if showing == mine then
			p.Visible = false
		end
	end)
	log:Info("radio log: %s", tostring(title))
end

-- The Spelunker's eye ---------------------------------------------------------------------------

local function revealing(): boolean
	local value = Modifiers.PlayerValue(player, "RevealCaveLayouts")
	return value ~= nil and value ~= 0
end

local function candidates(): { Model }
	local list = {}
	local deep = workspace:FindFirstChild("Deep")
	if deep then
		for _, d in deep:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Find") ~= nil then
				table.insert(list, d)
			end
		end
	end
	local rescues = workspace:FindFirstChild("Rescues")
	if rescues then
		for _, m in rescues:GetChildren() do
			local kind = m:GetAttribute("RescueKind")
			if m:IsA("Model") and (kind == "Miner" or kind == "Crew") and m:GetAttribute("State") == "Trapped" then
				table.insert(list, m)
			end
		end
	end
	local found = workspace:FindFirstChild("Finds")
	if found then
		for _, m in found:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("BigFind") == "CryoPod" then
				table.insert(list, m)
			end
		end
	end
	return list
end

local function revealTick()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local on = root ~= nil and root:IsA("BasePart") and revealing() and Surface.Zone((root :: BasePart).Position) ~= "Surface"
	local keep: { [Instance]: boolean } = {}
	if on then
		local at = (root :: BasePart).Position
		local range = Config.Get("Tuning", "Deep").RevealRange
		for _, model in candidates() do
			if (model:GetPivot().Position - at).Magnitude <= range then
				keep[model] = true
				if not revealed[model] then
					local h = Instance.new("Highlight")
					h.Name = "SpelunkerEye"
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.FillTransparency = 1
					h.OutlineColor = COLOR.glow
					h.OutlineTransparency = 0.15
					h.Adornee = model
					h.Parent = model
					revealed[model] = h
				end
			end
		end
	end
	for model, h in revealed do
		if not keep[model] or not model.Parent then
			h:Destroy()
			revealed[model] = nil
		end
	end
end

function DeepController:Init(registry)
	hud = registry.HUDController
end

function DeepController:Start()
	Remotes.OnClient("RadioLog", onRadioLog)
	task.spawn(function()
		while true do
			task.wait(0.75)
			local ok, err = pcall(revealTick)
			if not ok then
				log:Warn("reveal: %s", tostring(err))
			end
		end
	end)
	log:Info("the Deep's view ready")
end

return DeepController
