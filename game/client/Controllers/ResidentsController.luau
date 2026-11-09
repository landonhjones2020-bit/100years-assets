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
	  (every idle resident).
	Everything comes from the Residents and Rooms collections; the server checks every change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
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

local function section(body: Instance, order: number, label: string, text: string)
	local s = ui:Clone("Section")
	s.LayoutOrder = order
	s.Label.Text = string.upper(label)
	s.Body.Text = text
	s.Parent = body
end

local function portrait(): string?
	return if UIKit.Sprites["Portrait_Survivor"] then "Portrait_Survivor" else nil
end

local function showResident(id: string)
	local resident = replica:Get("Residents", id)
	local detail: any = page:FindFirstChild("Detail")
	if not resident then
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
	local body = ui:Clear(detail.Body)
	local job, stat = jobOf(resident)
	section(body, 1, "Job", if resident.State == "Down" then "Down: revive them with a Medkit before it's too late."
		elseif resident.State == "Away" then "Away on an expedition (the Expeditions screen's ACTIVE tab)."
		elseif job then `{job}, on {stat} {resident.Stats[stat or ""] or 0}.`
		else `Idle. Best at {best(resident)} ({resident.Stats[best(resident)]}).`)
	local stats = {}
	for _, s in STATS do
		table.insert(stats, `{s} {resident.Stats[s]}`)
	end
	section(body, 2, "Stats", table.concat(stats, "  ·  "))
	section(body, 3, "Needs", `Health {resident.Health} of {resident.MaxHealth}  ·  Rest {resident.Rest}  ·  Morale {resident.Morale} ({resident.Mood})`
		.. (if resident.Hungry then "  ·  Hungry" else ""))
	section(body, 4, "Experience", `{resident.XP} of {resident.XPNext} to level {resident.Level + 1}`)
	local history = resident.Log or {}
	local lines = {}
	for i = math.max(1, #history - 3), #history do
		table.insert(lines, history[i])
	end
	section(body, 5, "Run log", if #lines > 0 then table.concat(lines, "\n") else "Nothing yet.")
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
			ui:SetFooterActions({
				{ Label = "Auto-Assign", OnPress = function()
					Remotes.FireServer("AutoAssign")
				end },
			})
			fill()
		end,
		OnTab = function(tabId: string, p: Frame)
			page = p
			tab = tabId
			fill()
		end,
		OnClose = function()
			page = nil
		end,
	})
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
