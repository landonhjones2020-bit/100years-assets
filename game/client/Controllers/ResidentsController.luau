--!strict
--[[
	ResidentsController: the Residents screen (bible Section 18: "Residents (run) | All, by job,
	idle, injured, away | Resident cards | Resident card; Assign"), phase 1. Run place only. It
	opens from the Command View's footer (RESIDENTS) and from DevTools.

	* Tabs: All, Working (by job), Idle, Hurt (hurt or down), Away (on an expedition; Prompt 18).
	* A card per resident: the name, the job and level, the Common enamel. The portrait is the
	  Survivor's outfit until A3 brings the resident kit.
	* The resident card (zone D): job, stats, needs (health, rest, morale), experience to the next
	  level and the run log.
	* The main action: Assign (an idle resident goes to the free job that suits their best stat,
	  Section 7's Auto-Assign rule for one person) or Take off the job. The footer: Auto-Assign
	  (every idle resident), and for a level 2 Warden (Section 11: "a level 2 Warden chooses the stat
	  instead"; Prompt 20) LEVELS: the stat residents raise when they level, a press for the next
	  (their job's, then each stat in turn; ChooseLevelStat).
	Everything comes from the Residents and Rooms collections; the server checks every change.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Modifiers = require(Shared.Rules.Modifiers)
local Remotes = require(Shared.Remotes)
local ResidentRules = require(Shared.Rules.Residents)
local RunState = require(Shared.RunState)
local UIKit = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UIKit"))

local log = Log.new("ResidentsController")

local ResidentsController = {
	Name = "ResidentsController",
	Dependencies = { "UIController", "ReplicaController" },
}

local ui: any = nil
local replica: any = nil
local page: any = nil
local selected: string? = nil
local tab = "All"
local footer: () -> () -- below

local STATS = { "Strength", "Smarts", "Grit", "Speed", "Charm" }

local function roomName(roomType: string): string
	local info = Config.Find("Rooms", roomType)
	return if info then info.Name else roomType
end

local function jobOf(resident: any): (string?, string?)
	local room = if resident.Job then replica:Get("Rooms", resident.Job) else nil
	if not room then
		return nil, nil
	end
	return roomName(room.Type), Config.Get("Rooms", room.Type).WorkerStat
end

local function best(resident: any): string
	local id, value = "Strength", -1
	for _, stat in STATS do
		if (resident.Stats[stat] or 0) > value then
			id, value = stat, resident.Stats[stat] or 0
		end
	end
	return id
end

-- The free job that suits a resident: a room with a free slot whose job uses their highest stat.
local function bestJob(resident: any): string?
	local used: { [string]: number } = {}
	for _, other in replica:All("Residents") do
		if type(other) == "table" and other.Job and other.State ~= "Dead" then
			used[other.Job] = (used[other.Job] or 0) + 1
		end
	end
	local pick, pickValue = nil, -1
	for id, room in replica:All("Rooms") do
		local stat = Config.Get("Rooms", room.Type).WorkerStat
		if stat then
			local slots = Config.Get("Tuning", "Rooms").WorkerSlotsPerCell[room.Level] * room.Span
			local value = resident.Stats[stat] or 0
			if (used[id] or 0) < slots and value > pickValue then
				pick, pickValue = id, value
			end
		end
	end
	return pick
end

-- The card's text: one size for every line, from the card's height (never under the bible's 12).
local function lineSize(body: Instance): number
	local detail = body.Parent :: GuiObject
	return math.max(12, math.floor(detail.AbsoluteSize.Y * 0.027))
end

-- A titled block of the card, as tall as what it says (the kit's Section is two lines whatever it
-- holds, and its text scales to the box: a long trait would shrink and a short job line swell).
local function section(body: Instance, order: number, label: string, text: string): any
	local s: any = ui:Clone("Section")
	local holder = body :: GuiObject
	local line = lineSize(body)
	local width = math.max(1, holder.AbsoluteSize.X * s.Size.X.Scale)
	local lines = 0
	for _, paragraph in string.split(text, "\n") do
		lines += math.max(1, math.ceil(#paragraph * line * 0.36 / width))
	end
	local labelHeight = math.max(12, line * 0.8)
	local gap = line * 0.2
	local textHeight = lines * line * 1.15
	local total = labelHeight + gap + textHeight
	s.LayoutOrder = order
	s.Size = UDim2.fromScale(s.Size.X.Scale, total / math.max(1, holder.AbsoluteSize.Y))
	s.Label.Size = UDim2.fromScale(1, labelHeight / total)
	s.Label.Text = string.upper(label)
	s.Body.Position = UDim2.fromScale(0, (labelHeight + gap) / total)
	s.Body.Size = UDim2.fromScale(1, textHeight / total)
	s.Body.Text = text
	local limit = s.Body:FindFirstChildWhichIsA("UITextSizeConstraint")
	if limit then
		limit.MaxTextSize = line
	end
	s.Parent = body
	return s
end

-- The Residents page's own card: a personnel file. The photo sits small at the top left with the
-- name beside it, and the file below it takes the room (the kit's Detail gives half the card to
-- the picture, which left two lines of a resident's stats, traits, gear, needs and log in view).
local function arrange(p: Frame)
	local detail: any = p:FindFirstChild("Detail")
	if not detail or detail:GetAttribute("PersonnelFile") then
		return
	end
	detail:SetAttribute("PersonnelFile", true)
	detail.Hero.Position = UDim2.fromScale(0.07, 0.028)
	detail.Hero.Size = UDim2.fromScale(0.36, 0.225)
	local name: any = detail:FindFirstChild("Name")
	name.Position = UDim2.fromScale(0.47, 0.04)
	name.Size = UDim2.fromScale(0.46, 0.062)
	detail.Sub.Position = UDim2.fromScale(0.47, 0.108)
	detail.Sub.Size = UDim2.fromScale(0.46, 0.032)
	detail.Sub.TextXAlignment = Enum.TextXAlignment.Left
	detail.Tag.Position = UDim2.fromScale(0.47, 0.158)
	detail.Body.Position = UDim2.fromScale(0.07, 0.275)
	detail.Body.Size = UDim2.fromScale(0.86, 0.595)
end

-- The gear locker (the Gear collection's "Locker": piece key -> count), as names for the card.
local function locker(): { string }
	local stock = replica:Get("Gear", "Locker")
	local list = {}
	if type(stock) == "table" then
		for piece, count in stock do
			table.insert(list, if count > 1 then `{ResidentRules.PieceName(piece)} x{count}` else ResidentRules.PieceName(piece))
		end
		table.sort(list)
	end
	return list
end

-- The locker's pieces that go in a slot, in a steady order.
local function fitting(slot: string): { string }
	local stock = replica:Get("Gear", "Locker")
	local list = {}
	if type(stock) == "table" then
		for piece in stock do
			if ResidentRules.Slot((ResidentRules.Piece(piece))) == slot then
				table.insert(list, piece)
			end
		end
		table.sort(list)
	end
	return list
end

-- What a press of a slot's button asks for: the locker's next piece after the one they have, or
-- nothing ("") once they have had the last.
local function nextPiece(slot: string, current: string?): string
	local options = fitting(slot)
	for _, piece in options do
		if not current or piece > current then
			return piece
		end
	end
	return if current then "" else (options[1] or "")
end

local function portrait(): string?
	return if UIKit.Sprites["Portrait_Survivor"] then "Portrait_Survivor" else nil
end

local gearConnections: { RBXScriptConnection } = {}
local shown: string? = nil

local function showResident(id: string)
	for _, connection in gearConnections do
		connection:Disconnect()
	end
	table.clear(gearConnections)
	local resident = replica:Get("Residents", id)
	local detail: any = page:FindFirstChild("Detail")
	if not resident then
		shown = nil
		detail:FindFirstChild("Name").Text = "NOBODY"
		detail.Sub.Text = ""
		ui:Clear(detail.Body)
		ui:SetMainAction(nil)
		return
	end
	local hero = portrait()
	local heroImage: any = detail.Hero:FindFirstChild("Image")
	heroImage.Visible = hero ~= nil
	if hero then
		ui:SetSprite(heroImage, hero)
	end
	ui:SetRarity(detail, if resident.Tier == "Free" then "Common" else resident.Tier)
	detail:FindFirstChild("Name").Text = string.upper(resident.Name)
	detail.Sub.Text = `LEVEL {resident.Level}  ·  AGE {resident.Age}`
	-- the same card again (a gear button's answer): stay where the reader had scrolled to
	local scrolled = if shown == id then detail.Body.CanvasPosition else Vector2.zero
	shown = id
	local body = ui:Clear(detail.Body)
	task.defer(function()
		if shown == id and detail.Parent then
			detail.Body.CanvasPosition = scrolled
		end
	end)
	local job, stat = jobOf(resident)
	section(body, 10, "Job", if resident.State == "Down" then "Down: revive them with a Medkit before it's too late."
		elseif resident.State == "Away" then "Away on an expedition (the Expeditions screen's ACTIVE tab)."
		elseif job then `{job}, on {stat} {resident.Stats[stat or ""] or 0}.`
		else `Idle. Best at {best(resident)} ({resident.Stats[best(resident)]}).`)
	local outfitStat, bonus, vest, noGas = ResidentRules.OutfitBonus(resident.Outfit)
	local stats = {}
	for _, s in STATS do
		-- an outfit's bonus shows beside the stat it lifts (never past the cap)
		local worn = if s == outfitStat then math.min(bonus, Config.Get("Tuning", "Residents").StatCap - (resident.Stats[s] or 0)) else 0
		table.insert(stats, if worn > 0 then `{s} {resident.Stats[s]} +{worn}` else `{s} {resident.Stats[s]}`)
	end
	section(body, 20, "Stats", table.concat(stats, "  ·  "))
	section(body, 30, "Needs", `Health {resident.Health} of {resident.MaxHealth}  ·  Rest {resident.Rest}  ·  Morale {resident.Morale} ({resident.Mood})`
		.. (if resident.Hungry then "  ·  Hungry" else "")
		-- Prompt 26: the rest of Section 11's conditions
		.. (if resident.Injured then "  ·  INJURED: works slowly until a Medbay or a Medic treats them" else "")
		.. (if resident.Panicked then "  ·  Panicked: no work until they calm down" else "")
		.. (if resident.Refusing then "  ·  REFUSING TO WORK" else "")
		.. (if resident.Mood == "Miserable" then "  ·  Miserable: may refuse work, start fights or leave for good" else "")
		-- Prompt 24: an Outbreak's sickness and a leak's radiation
		.. (if resident.Sick then (if resident.Quarantined then "  ·  Sick, in quarantine" else "  ·  SICK: take them off work to quarantine them") else "")
		.. (if resident.Irradiated then "  ·  Irradiated: a Decon Room clears it" else ""))
	-- Prompt 26: their two traits, and their three gear slots (Section 11)
	local traits = {}
	for _, traitId in resident.Traits or {} do
		local trait = Config.Find("Traits", traitId)
		if trait then
			table.insert(traits, `{trait.Name}: {trait.Text}`)
		end
	end
	section(body, 40, "Traits", if #traits > 0 then table.concat(traits, "\n") else "None.")
	local stock = locker()
	section(body, 50, "Gear", if #stock > 0
		then `Press a slot to fit the next piece from the gear locker: {table.concat(stock, ", ")}.`
		else "The gear locker is empty. Gear is found on the surface and in the Deep.")
	local toolItem = if resident.Tool then Config.Find("Items", (ResidentRules.Piece(resident.Tool)) or "") else nil
	local weaponItem = if resident.Weapon then Config.Find("Items", (ResidentRules.Piece(resident.Weapon)) or "") else nil
	local wearing = {
		Weapon = if weaponItem then weaponItem.Name else nil,
		Outfit = if resident.Outfit
			then `{ResidentRules.PieceName(resident.Outfit)}  ·  {outfitStat} +{bonus}{if vest > 0 then `, health +{vest}` else ""}{if noGas then ", no gas" else ""}`
			else nil,
		Tool = if toolItem then `{toolItem.Name}{if toolItem.ResidentUse then `  ·  {toolItem.ResidentUse}` else ""}` else nil,
	}
	for i, slot in { "Weapon", "Outfit", "Tool" } do
		local button = ui:Clone("FooterButton") :: ImageButton
		button.Name = "Gear" .. slot
		button.LayoutOrder = 50 + i
		button.Size = UDim2.fromScale(0.97, lineSize(body) * 2.1 / math.max(1, (body :: GuiObject).AbsoluteSize.Y))
		local label = (button:FindFirstChild("Content") :: Frame):FindFirstChild("Label") :: TextLabel
		label.Text = string.upper(`{slot}  ·  {wearing[slot] or "none"}`)
		local ask = nextPiece(slot, resident[slot])
		local can = resident.State == "Alive" and (resident[slot] ~= nil or #fitting(slot) > 0)
		button.Active = can
		button.AutoButtonColor = false
		button.ImageTransparency = if can then 0 else 0.55
		label.TextTransparency = if can then 0 else 0.4
		if can then
			table.insert(gearConnections, button.Activated:Connect(function()
				Remotes.FireServer("EquipResident", id, slot, ask)
			end))
		end
		button.Parent = body
	end
	section(body, 60, "Experience", `{resident.XP} of {resident.XPNext} to level {resident.Level + 1}`)
	local history = resident.Log or {}
	local lines = {}
	for i = math.max(1, #history - 3), #history do
		table.insert(lines, history[i])
	end
	section(body, 70, "Run log", if #lines > 0 then table.concat(lines, "\n") else "Nothing yet.")
	if resident.State ~= "Alive" then
		ui:SetMainAction({ Label = if resident.State == "Away" then "Away" else "Down", Enabled = false })
	elseif resident.Job then
		ui:SetMainAction({
			Label = "Take off the job",
			Enabled = true,
			OnPress = function()
				Remotes.FireServer("AssignResident", id, "")
			end,
		})
	else
		local roomId = bestJob(resident)
		ui:SetMainAction({
			Label = "Assign",
			Enabled = roomId ~= nil,
			OnPress = function()
				if roomId then
					Remotes.FireServer("AssignResident", id, roomId)
				end
			end,
		})
	end
end

local function wanted(resident: any): boolean
	if resident.State == "Dead" then
		return false
	end
	if tab == "Working" then
		return resident.Job ~= nil
	elseif tab == "Idle" then
		return resident.Job == nil and resident.State == "Alive"
	elseif tab == "Hurt" then
		return resident.State == "Down" or resident.Health < resident.MaxHealth
	elseif tab == "Away" then
		return resident.State == "Away"
	end
	return true
end

local function fill()
	if not page then
		return
	end
	local content: any = page:FindFirstChild("Content")
	local grid = ui:Clear(content.Grid)
	local list = {}
	for id, resident in replica:All("Residents") do
		if type(resident) == "table" and wanted(resident) then
			table.insert(list, { Id = id, R = resident })
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		if tab == "Working" then
			local ja, jb = jobOf(a.R) or "", jobOf(b.R) or ""
			if ja ~= jb then
				return ja < jb
			end
		end
		return (tonumber(string.match(a.Id, "%d+")) or 0) < (tonumber(string.match(b.Id, "%d+")) or 0)
	end)
	local stillThere = false
	for i, entry in list do
		local resident = entry.R
		local card = ui:Clone("Card")
		card.Name = entry.Id
		card.LayoutOrder = i
		ui:SetRarity(card, if resident.Tier == "Free" then "Common" else resident.Tier)
		local face = portrait()
		card.Portrait.Visible = face ~= nil
		if face then
			ui:SetSprite(card.Portrait, face)
		end
		card:FindFirstChild("Name").Text = string.upper(resident.Name)
		local job = jobOf(resident)
		card.Sub.Text = (if resident.State == "Down" then "DOWN" elseif resident.State == "Away" then "AWAY" elseif job then job else "Idle")
			.. `  ·  L{resident.Level}`
		card.Price.Visible = false
		card.Stamp.Visible = false
		ui:SetSprite(card.Lamp, if entry.Id == selected then "Lamp_Orange" else "Lamp_Off")
		card.Activated:Connect(function()
			selected = entry.Id
			fill()
		end)
		card.Parent = grid
		if entry.Id == selected then
			stillThere = true
		end
	end
	content.Empty.Visible = #list == 0
	if not stillThere then
		selected = if list[1] then list[1].Id else nil
		if selected then
			local first = grid:FindFirstChild(selected)
			if first then
				ui:SetSprite(first.Lamp, "Lamp_Orange")
			end
		end
	end
	if selected then
		showResident(selected)
	else
		showResident("")
	end
	local alive = 0
	for _, resident in replica:All("Residents") do
		if type(resident) == "table" and resident.State ~= "Dead" then
			alive += 1
		end
	end
	ui:SetHint(`{alive} residents in the bunker`)
end

function ResidentsController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
end

-- The footer: Auto-Assign, and a level 2 Warden's LEVELS (Prompt 20).
footer = function()
	local actions = {
		{ Label = "Auto-Assign", OnPress = function()
			Remotes.FireServer("AutoAssign")
		end },
	}
	if Modifiers.PlayerValue(Players.LocalPlayer, "ChoosesLevelStat") then
		local current = RunState.Get("LevelStat")
		local order = { "" }
		for _, stat in STATS do
			table.insert(order, stat)
		end
		local at = table.find(order, if type(current) == "string" then current else "") or 1
		local nextStat = order[at % #order + 1]
		table.insert(actions, { Label = `Levels: {if at > 1 then order[at] else "Job"}`, OnPress = function()
			Remotes.FireServer("ChooseLevelStat", nextStat)
		end })
	end
	ui:SetFooterActions(actions)
end

function ResidentsController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	ui:Register("Residents", {
		Title = "RESIDENTS",
		Subtitle = "STEADFAST SHELTER CO.  ·  PERSONNEL FILE",
		Tabs = {
			{ Id = "All", Label = "ALL", Icon = "Icon_Grid" },
			{ Id = "Working", Label = "WORKING", Icon = "Icon_Scrap" },
			{ Id = "Idle", Label = "IDLE", Icon = "Icon_Grid" },
			{ Id = "Hurt", Label = "HURT", Icon = "Icon_Shield" },
			{ Id = "Away", Label = "AWAY", Icon = "Icon_Route" },
		},
		Layout = "Grid",
		Hint = "",
		OnOpen = function(p: Frame)
			page = p
			tab = "All"
			arrange(p)
			footer()
			fill()
		end,
		OnTab = function(tabId: string, p: Frame)
			page = p
			tab = tabId
			arrange(p)
			fill()
		end,
		OnClose = function()
			page = nil
			shown = nil
		end,
	})
	-- a level 2 Warden's LEVELS button follows the choice and the class
	for _, signal in { RunState.Changed("LevelStat"), Players.LocalPlayer:GetAttributeChangedSignal("Class"),
		Players.LocalPlayer:GetAttributeChangedSignal("ClassLevel") } do
		signal:Connect(function()
			if page then
				footer()
			end
		end)
	end
	replica:Changed("Gear"):Connect(function()
		if page then
			fill() -- the locker's line and the gear buttons
		end
	end)
	local pending = false
	replica:Changed("Residents"):Connect(function()
		if page and not pending then
			pending = true
			task.delay(0.3, function()
				pending = false
				fill()
			end)
		end
	end)
	log:Debug("Residents screen registered")
end

return ResidentsController
