--!strict
--[[
	PadController: the elevator pads on this client (bible Section 21: "Each pad shows its
	difficulty ... and opens the loadout screen while you wait"). Lobby only; Prompt 21. The server
	decides everything (PadService); this shows the Pads collection and sends what the rider wants.

	* Signs: every pad model (a `PadId` attribute) with a `Sign` part gets a board over it
	  (Lobby.Templates.PadSign): its kind, how many are on it, its difficulty (a band in the
	  difficulty's colour) and its countdown, or what it is waiting for. A pad whose difficulty this
	  player hasn't unlocked says how to unlock it instead.
	* The panel (Lobby.Pad) shows while the Player's `Pad` attribute names a pad: the title, the
	  countdown, the riders (the leader's lamp is orange; each rider's class), and the buttons this
	  rider can use: LOADOUT (L, D-pad down: LobbyController's key), DIFFICULTY (H, D-pad right: a
	  private pad's leader, a solo rider), INVITE (G, D-pad left) and START (Y: a private pad's
	  leader). The camera holds the mouse, so each button carries its key.
	* Stepping onto a pad opens the Loadout once (not on the solo pad, whose count is short). While
	  the Loadout or the Class Shop covers the panel, the pad's countdown is the Frame's footer
	  hint. While a solo rider has the Loadout open the pad's count waits (PadHold).
	* Invite (Lobby.Invite): the other players in this lobby, each with a lamp (invited or not); a
	  press sends PadInvite. INVITE ROBLOX FRIENDS opens Roblox's invite prompt. The cursor is free
	  while the list is open (a controller gets a selection).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Lobby = require(Shared.Rules.Lobby)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local KitRuntime = require(Lib:WaitForChild("KitRuntime"))

local player = Players.LocalPlayer

local PadController = {
	Name = "PadController",
	Dependencies = { "UIController", "ReplicaController", "CameraController", "InputController", "LobbyController" },
}

local ui: any = nil
local replica: any = nil
local camera: any = nil
local input: any = nil
local lobby: any = nil
local gui: ScreenGui? = nil

local signs: { [string]: BillboardGui } = {}
local inviteRows: { [number]: number } = {} -- row index -> user id
local inviteOpen = false
local lastPad: string? = nil
local greeted: string? = nil -- the pad whose boarding has opened the Loadout
local holding = false
local hinted = false -- the Frame's footer hint is the pad's countdown

local BAND: { [string]: Color3 } = {
	Normal = Color3.fromHex("#2F6F73"), Hard = Color3.fromHex("#E8743B"), Nightmare = Color3.fromHex("#B5412B"),
}

local function part(path: string): any
	local at: Instance = gui :: ScreenGui
	for _, name in string.split(path, ".") do
		at = at:WaitForChild(name)
	end
	return at
end

local function padOf(id: string?): any
	local found = if id then replica:Get("Pads", id) else nil
	return if type(found) == "table" then found else nil
end

local function myPad(): (string?, any)
	local id = player:GetAttribute("Pad")
	if type(id) ~= "string" then
		return nil, nil
	end
	return id, padOf(id)
end

local function capacity(kind: string): number
	return if kind == "Solo" then 1 else Config.Get("Tuning", "Lobby").PartyMax
end

-- This player's own stats (difficulty unlocks), from their profile.
local function myStats(): { [string]: number }?
	local found = replica:Get("Profiles", tostring(player.UserId))
	return if type(found) == "table" and type(found.Stats) == "table" then found.Stats else nil
end

-- What a pad is doing, in a few words (`mine`: for the pad's own riders, not its sign).
local function timerText(pad: any, mine: boolean?): string
	local riders = #pad.Riders
	if pad.Phase == "Launching" then
		return "GOING DOWN"
	elseif pad.Phase == "Counting" and type(pad.LeavesAt) == "number" then
		if pad.Hold then
			return if mine then "WAITING FOR YOUR LOADOUT" else "WAITING"
		end
		return string.format("LEAVES IN %d", math.max(0, math.ceil(pad.LeavesAt - workspace:GetServerTimeNow())))
	elseif pad.Phase == "Waiting" then
		return if mine and pad.Leader == player.UserId then "START WHEN YOU'RE READY" else "ITS LEADER STARTS IT"
	elseif riders == 0 then
		if not mine and not Lobby.Unlocked(myStats(), pad.Difficulty) then
			local difficulty = Config.Find("Difficulties", pad.Difficulty)
			return string.upper(if difficulty then `Unlocks {string.lower(difficulty.Unlock)}` else "Locked")
		end
		return if pad.Kind == "Private" then "STEP ON TO LEAD" else "STEP ON TO START"
	end
	return ""
end

local function fillSign(id: string, sign: BillboardGui)
	local pad = padOf(id)
	local spec = Config.Find("Pads", id)
	local board: any = sign:FindFirstChild("Board")
	if not pad or not spec or not board then
		return
	end
	board.Kind.Text = string.upper(spec.Name)
	board.Count.Text = `{#pad.Riders}/{capacity(pad.Kind)}`
	board.Band.BackgroundColor3 = BAND[pad.Difficulty] or BAND.Normal
	board.Band.Difficulty.Text = string.upper(pad.Difficulty)
	board.Timer.Text = timerText(pad)
end

local function adoptSign(model: Instance)
	local id = model:GetAttribute("PadId")
	local anchor = model:FindFirstChild("Sign")
	if type(id) ~= "string" or signs[id] or not (anchor and anchor:IsA("BasePart")) or not gui then
		return
	end
	local sign = (part("Templates.PadSign") :: BillboardGui):Clone()
	sign.Name = "PadSign_" .. id
	sign.Adornee = anchor
	sign.Enabled = true
	sign.Parent = player:WaitForChild("PlayerGui")
	signs[id] = sign
	fillSign(id, sign)
end

-- The panel -----------------------------------------------------------------------------------------

local function closeInvite()
	if not inviteOpen then
		return
	end
	inviteOpen = false
	camera:FreeCursor("PadInvite", false)
	if gui then
		local list = part("Invite")
		list.Visible = false
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(list) then
			GuiService.SelectedObject = nil
		end
	end
end

local function openInvite()
	inviteOpen = true
	camera:FreeCursor("PadInvite", true)
	if input:Device() == "Gamepad" and gui then
		local first = part("Invite.Rows.Row1")
		GuiService.SelectedObject = if first.Visible then first else part("Invite.Friends")
	end
end

local function refreshKeys()
	if not gui then
		return
	end
	lobby:SetKey(part("Pad.Buttons.Loadout.Content.Key"), "L", "DOWN")
	lobby:SetKey(part("Pad.Buttons.Difficulty.Content.Key"), "H", "RIGHT")
	lobby:SetKey(part("Pad.Buttons.Invite.Content.Key"), "G", "LEFT")
	lobby:SetKey(part("Pad.Buttons.Start.Content.Key"), "Y", "Y")
end

local function fillInvite(pad: any)
	local invited: { [number]: boolean } = {}
	for _, userId in pad.Invited or {} do
		invited[userId] = true
	end
	table.clear(inviteRows)
	local index = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and index < 8 then
			index += 1
			inviteRows[index] = other.UserId
			local row = part(`Invite.Rows.Row{index}`)
			row.Visible = true
			row:FindFirstChild("Name").Text = string.upper(other.DisplayName)
			local on = invited[other.UserId] == true
			row.State.Text = if on then "INVITED" else "INVITE"
			KitRuntime.SetSprite(row.Lamp, if on then "Lamp_Green" else "Lamp_Off")
		end
	end
	for i = index + 1, 8 do
		part(`Invite.Rows.Row{i}`).Visible = false
	end
	part("Invite.Empty").Visible = index == 0
end

local function fillPanel()
	if not gui then
		return
	end
	local id, pad = myPad()
	local panel = part("Pad")
	local shown = id ~= nil and pad ~= nil and not ui:IsOpen()
	panel.Visible = shown
	if not id or not pad then
		closeInvite()
		return
	end
	local spec = Config.Find("Pads", id)
	local leader = pad.Leader == player.UserId
	part("Pad.Title").Text = string.upper(`{if spec then spec.Name else pad.Kind} PAD  ·  {pad.Difficulty}`)
	part("Pad.Timer").Text = timerText(pad, true)
	for i = 1, 6 do
		local slot = part(`Pad.Riders.Slot{i}`)
		local rider = pad.Riders[i]
		slot.Visible = i <= capacity(pad.Kind)
		if rider then
			local class = Config.Find("Classes", rider.Class)
			slot:FindFirstChild("Name").Text = string.upper(rider.Name)
			slot.Class.Text = string.upper((if class then class.Name else rider.Class) .. (if rider.Trial then "  ·  TRIAL" else ""))
			KitRuntime.SetSprite(slot.Lamp, if rider.UserId == pad.Leader and pad.Kind == "Private" then "Lamp_Orange" else "Lamp_Green")
		else
			slot:FindFirstChild("Name").Text = "OPEN"
			slot.Class.Text = ""
			KitRuntime.SetSprite(slot.Lamp, "Lamp_Off")
		end
	end
	local busy = pad.Phase == "Launching"
	local canPick = (pad.Kind == "Private" and leader) or pad.Kind == "Solo"
	part("Pad.Buttons.Loadout").Visible = not busy
	part("Pad.Buttons.Difficulty").Visible = canPick and not busy
	part("Pad.Buttons.Invite").Visible = pad.Kind == "Private" and leader and not busy
	part("Pad.Buttons.Start").Visible = pad.Kind == "Private" and leader and not busy
	if inviteOpen and shown and pad.Kind == "Private" and leader and not busy then
		part("Invite").Visible = true
		fillInvite(pad)
	else
		closeInvite()
	end
end

-- While a Frame screen covers the panel, its footer hint is the pad's countdown.
local function fillHint()
	local id, pad = myPad()
	if id and pad and ui:IsOpen() then
		local spec = Config.Find("Pads", id)
		local line = timerText(pad, true)
		hinted = true
		ui:SetHint(string.upper(`{if spec then spec.Name else pad.Kind} pad  ·  {pad.Difficulty}  ·  {#pad.Riders}/{capacity(pad.Kind)} aboard`
			.. (if line ~= "" then `  ·  {line}` else "")))
	elseif hinted then
		hinted = false
		if ui:IsOpen() then
			ui:ResetHint()
		end
	end
end

-- The loadout opens while you wait: once per boarding, when the pad's own record has arrived
-- (the attribute and the collection replicate apart). Not on the solo pad: its count is short.
local function greet()
	local id, pad = myPad()
	if not id then
		greeted = nil
	elseif pad and greeted ~= id then
		greeted = id
		if pad.Kind ~= "Solo" and pad.Phase ~= "Launching" and not ui:IsOpen() then
			ui:Open("Loadout")
		end
	end
end

local function onPadChanged()
	local id = myPad()
	if id ~= lastPad then
		lastPad = id
		closeInvite()
	end
	greet()
	fillPanel()
end

local function setHold()
	local _id, pad = myPad()
	local want = pad ~= nil and pad.Kind == "Solo" and ui:Current() == "Loadout"
	if want ~= holding then
		holding = want
		Remotes.FireServer("PadHold", want)
	end
end

local function act(name: string)
	local id, pad = myPad()
	if not id or not pad or pad.Phase == "Launching" then
		return
	end
	local leader = pad.Leader == player.UserId
	if name == "Loadout" then
		ui:Open("Loadout")
	elseif name == "Difficulty" and ((pad.Kind == "Private" and leader) or pad.Kind == "Solo") then
		Remotes.FireServer("PadDifficulty")
	elseif name == "Start" and pad.Kind == "Private" and leader then
		Remotes.FireServer("PadStart")
	elseif name == "Invite" and pad.Kind == "Private" and leader then
		if inviteOpen then
			closeInvite()
		else
			openInvite()
		end
		fillPanel()
	end
end

-- LOADOUT's key is LobbyController's (L, D-pad down: it opens the Loadout anywhere in the lobby).
local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.H] = "Difficulty", [Enum.KeyCode.DPadRight] = "Difficulty",
	[Enum.KeyCode.G] = "Invite", [Enum.KeyCode.DPadLeft] = "Invite",
	[Enum.KeyCode.Y] = "Start", [Enum.KeyCode.ButtonY] = "Start",
}

function PadController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
	camera = registry.CameraController
	input = registry.InputController
	lobby = registry.LobbyController
end

function PadController:Start()
	if Constants.PlaceKind() ~= "Lobby" then
		return
	end
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local found = playerGui:WaitForChild("Lobby", 30)
		if not found or not found:IsA("ScreenGui") then
			return
		end
		gui = found
		for _, name in { "Loadout", "Difficulty", "Invite", "Start" } do
			part(`Pad.Buttons.{name}`).Activated:Connect(function()
				act(name)
			end)
		end
		part("Invite.Close").Activated:Connect(function()
			closeInvite()
		end)
		refreshKeys()
		input.DeviceChanged:Connect(refreshKeys)
		part("Invite.Friends").Activated:Connect(function()
			pcall(function()
				if SocialService:CanSendGameInviteAsync(player) then
					SocialService:PromptGameInvite(player)
				end
			end)
		end)
		for i = 1, 8 do
			part(`Invite.Rows.Row{i}`).Activated:Connect(function()
				local userId = inviteRows[i]
				local _id, pad = myPad()
				if userId and pad then
					local on = table.find(pad.Invited or {}, userId) ~= nil
					Remotes.FireServer("PadInvite", userId, not on)
				end
			end)
		end
		for _, item in workspace:GetDescendants() do
			if item:GetAttribute("PadId") ~= nil then
				adoptSign(item)
			end
		end
		workspace.DescendantAdded:Connect(function(item: Instance)
			task.defer(function()
				if item:GetAttribute("PadId") ~= nil then
					adoptSign(item)
				end
			end)
		end)
		replica:Changed("Pads"):Connect(function()
			for id, sign in signs do
				fillSign(id, sign)
			end
			greet()
			fillPanel()
			fillHint()
		end)
		player:GetAttributeChangedSignal("Pad"):Connect(onPadChanged)
		ui.Opened:Connect(function()
			hinted = false -- a new screen starts with its own hint
			fillPanel()
			fillHint()
			setHold()
		end)
		ui.Closed:Connect(function()
			hinted = false
			fillPanel()
			setHold()
		end)
		onPadChanged()
		-- countdowns tick
		while true do
			task.wait(0.25)
			for id, sign in signs do
				fillSign(id, sign)
			end
			local _id, pad = myPad()
			if pad and gui then
				part("Pad.Timer").Text = timerText(pad, true)
			end
			fillHint()
		end
	end)
	ContextActionService:BindAction("100Y_PadKeys", function(_name: string, state: Enum.UserInputState, io: InputObject)
		local action = KEYS[io.KeyCode]
		-- the rejoin card's Y comes first (LobbyController)
		if state == Enum.UserInputState.Begin and action and player:GetAttribute("Pad") ~= nil and not ui:IsOpen()
			and not (action == "Start" and type(player:GetAttribute("RejoinOffer")) == "string") then
			act(action)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H, Enum.KeyCode.G, Enum.KeyCode.Y, Enum.KeyCode.DPadRight, Enum.KeyCode.DPadLeft, Enum.KeyCode.ButtonY)
end

return PadController
