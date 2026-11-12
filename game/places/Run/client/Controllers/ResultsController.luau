--!strict
--[[
	ResultsController: the results screen (bible Section 18: "Results (end of run) | Summary,
	residents, rewards | Stats, stories, payouts | MVP card; Play Again"; Section 21: Play Again or
	Return to Lobby). Run place only; Prompt 15. Everything comes from ResultsService's Results
	collection and the Residents collection; the buttons only ask the server.

	* It opens Tuning.Results.OpenDelaySeconds after the run ends (VictoryDelaySeconds after a victory,
	  whose moment VictoryController plays first) (and again a little after it is
	  closed while the run is over).
	* Tabs: Summary (how it ended, the year and era, depth, time, the team's numbers, then the
	  run's story), Residents (everyone who lived in the bunker: alive with their job and level, or
	  when and how they died), Rewards (your Glowshards line by line, your account experience and
	  level, and the team's payouts).
	* Zone D: the MVP card (their avatar, class, score and best numbers).
	* The main action: Play Again (a team vote). The footer: Keep Going after a victory (a team
	  vote for Endless) and Return to Lobby.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)

local log = Log.new("ResultsController")
local player = Players.LocalPlayer

local ResultsController = {
	Name = "ResultsController",
	Dependencies = { "UIController", "ReplicaController" },
}

local SCREEN = "Results"
local OUTCOMES: { [string]: string } = {
	CenturyVictory = "CENTURY VICTORY",
	DeepVictory = "DEEP VICTORY",
	Defeat = "THE BUNKER FELL",
}
local REASONS: { [string]: string } = {
	ReactorDestroyed = "The Reactor Core melted down",
	ResidentsLost = "The last resident died",
}

local ui: any = nil
local replica: any = nil
local page: any = nil
local tab = "Summary"
local opening = false

local function results(): any
	local r = replica:Get("Results", "Run")
	return if type(r) == "table" then r else nil
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

local function commas(n: number): string
	local text = tostring(math.floor(n + 0.5))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- "1 cycle", "3 cycles" (plural adds "s" unless given).
local function count(n: number, one: string, many: string?): string
	local whole = math.floor(n + 0.5)
	return `{commas(whole)} {if whole == 1 then one else many or one .. "s"}`
end

local function addRow(list: Instance, order: number, icon: string?, name: string, value: string, wide: boolean?): any
	local row = ui:Clone("Row")
	row.LayoutOrder = order
	row.Name = `Row{order}`
	local iconImage: any = row:FindFirstChild("Icon")
	if icon then
		ui:SetSprite(iconImage, icon)
		if icon == "Icon_Glowshard" or string.sub(icon, 1, 5) == "Lamp_" then
			iconImage.ImageColor3 = Color3.new(1, 1, 1)
		end
	else
		iconImage.Visible = false
	end
	local nameLabel: any = row:FindFirstChild("Name")
	nameLabel.Text = string.upper(name)
	if wide then
		nameLabel.Size = UDim2.fromScale(0.83, nameLabel.Size.Y.Scale)
	end
	row:FindFirstChild("Value").Text = string.upper(value)
	row.AutoButtonColor = false
	row.Parent = list
	return row
end

local function outcomeLine(r: any): (string, string)
	local title = OUTCOMES[r.Outcome or ""] or "THE RUN IS OVER"
	if r.Endless then
		title ..= " · ENDLESS"
	end
	local why = if r.DefeatReason then REASONS[r.DefeatReason] or "" else "The bunker held"
	return title, why
end

local function fillSummary(list: Instance, r: any)
	local title, why = outcomeLine(r)
	local order = 0
	local function add(icon: string?, name: string, value: string, wide: boolean?)
		order += 1
		addRow(list, order, icon, name, value, wide)
	end
	add(if r.Outcome == "Defeat" then "Alert_Danger" else "Icon_Check", title, why)
	local era = Config.Find("Eras", r.Era or "")
	add("Icon_Grid", "Year reached", `Year {r.Year} · {if era then era.Name else ""}`)
	add("Icon_Pickaxe", "Deepest floor", `Floor {r.DeepestFloor} · {r.Band}`)
	add("Icon_Command", "Time in the bunker", `{clock(r.Seconds or 0)} · {count(r.Cycle or 0, "cycle")}`)
	local team = r.Team or {}
	add("Icon_Aim", "Monsters killed", commas(team.MonstersKilled or 0))
	add("Icon_Drill", "Cells dug", commas(team.CellsDug or 0))
	add("Icon_Scrap", "Rooms built", commas(team.RoomsBuilt or 0))
	add("Icon_Medkit", "Residents", `{team.ResidentsAlive or 0} alive · {team.ResidentsLost or 0} lost`)
	add("Icon_Fire", "Disasters", commas(team.Disasters or 0))
	add("Icon_Scrap", "Hauled from the surface", commas(team.Hauled or 0)) -- Prompt 16
	add("Icon_Medkit", "Survivors rescued", commas(team.Rescued or 0))
	add("Icon_Shield", "Bosses beaten", if team.Bosses and #team.Bosses > 0 then table.concat(team.Bosses, ", ") else "None")
	add(nil, "The story of the run", "", true)
	for _, line in r.Stories or {} do
		add("Icon_Tag", line, "", true)
	end
end

local function fillResidents(list: Instance)
	local entries = {}
	for id, resident in replica:All("Residents") do
		if type(resident) == "table" then
			table.insert(entries, { Id = id, R = resident })
		end
	end
	table.sort(entries, function(a: any, b: any): boolean
		local deadA, deadB = a.R.State == "Dead", b.R.State == "Dead"
		if deadA ~= deadB then
			return not deadA
		end
		return (tonumber(string.match(a.Id, "%d+")) or 0) < (tonumber(string.match(b.Id, "%d+")) or 0)
	end)
	for i, entry in entries do
		local resident = entry.R
		local value
		if resident.State == "Dead" then
			local log_ = resident.Log or {}
			value = "Lost"
			for k = #log_, 1, -1 do
				if string.find(string.lower(log_[k]), "died") then
					value = log_[k]
					break
				end
			end
		else
			local job = if resident.Job then replica:Get("Rooms", resident.Job) else nil
			local jobName = if job then Config.Get("Rooms", job.Type).Name else "Idle"
			value = `Alive · L{resident.Level} · {jobName}`
		end
		addRow(list, i, if resident.State == "Dead" then "Lamp_Red" else "Lamp_Green", resident.Name, value)
	end
	if #entries == 0 then
		addRow(list, 1, nil, "Nobody lived here", "")
	end
end

local function fillRewards(list: Instance, r: any)
	local order = 0
	local function add(icon: string?, name: string, value: string, wide: boolean?)
		order += 1
		addRow(list, order, icon, name, value, wide)
	end
	local me = (r.Players or {})[tostring(player.UserId)]
	if me then
		for _, line in me.Lines or {} do
			add("Icon_Glowshard", line.Text, `+{line.Amount}`)
		end
		add("Icon_Glowshard", "Your Glowshards", commas(me.Glowshards or 0))
		add("Icon_Check", "Account experience", `+{commas(me.XP or 0)} · Level {me.Level or 1}{if me.LevelUp then " · Up!" else ""}`)
		if not me.Paid then
			add("Alert_Warning", "Your profile wasn't loaded: nothing was saved", "", true)
		end
	else
		add("Alert_Info", "You joined after the run ended", "", true)
	end
	add(nil, "The team", "", true)
	local rows = {}
	for userId, row in r.Players or {} do
		table.insert(rows, { Id = userId, Row = row })
	end
	table.sort(rows, function(a: any, b: any): boolean
		return (a.Row.Score or 0) > (b.Row.Score or 0)
	end)
	for _, entry in rows do
		add("Icon_Glowshard", `{entry.Row.Name} · {entry.Row.Class}`, `{commas(entry.Row.Glowshards or 0)}`)
	end
end

local function section(body: Instance, order: number, label: string, text: string)
	local s = ui:Clone("Section")
	s.LayoutOrder = order
	s.Label.Text = string.upper(label)
	s.Body.Text = text
	s.Parent = body
end

local function showMVP(r: any)
	local detail: any = page:FindFirstChild("Detail")
	if not detail then
		return
	end
	ui:SetRarity(detail, "Legendary")
	local hero: any = detail.Hero:FindFirstChild("Image")
	local body = ui:Clear(detail.Body)
	local mvp = if r.MVP then (r.Players or {})[r.MVP] else nil
	if not mvp then
		hero.Visible = false
		detail:FindFirstChild("Name").Text = "NO MVP"
		detail.Sub.Text = ""
		section(body, 1, "Most valuable player", "Nobody scored this run.")
		return
	end
	hero.Visible = true
	hero.Image = `rbxthumb://type=AvatarBust&id={r.MVP}&w=420&h=420`
	hero.ImageRectOffset = Vector2.zero
	hero.ImageRectSize = Vector2.zero
	hero.ScaleType = Enum.ScaleType.Fit
	detail:FindFirstChild("Name").Text = string.upper(mvp.Name)
	detail.Sub.Text = string.upper(mvp.Class or "")
	section(body, 1, "MVP · score", commas(mvp.Score or 0))
	section(body, 2, "Fighting", `{commas(mvp.Damage or 0)} damage · {count(mvp.Kills or 0, "kill")} · {commas(mvp.BossDamage or 0)} to bosses`)
	section(body, 3, "Helping", `{count(mvp.Revives or 0, "revive")} · {count(mvp.CellsDug or 0, "cell")} dug · {commas(mvp.Repairs or 0)} repaired`
		.. ` · {commas(mvp.Hauled or 0)} hauled · {count(mvp.Rescues or 0, "rescue")}`)
end

local function fill()
	local r = results()
	if not page or not r then
		return
	end
	local content: any = page:FindFirstChild("Content")
	local list = ui:Clear(content.List)
	content.Empty.Visible = false
	if tab == "Residents" then
		fillResidents(list)
	elseif tab == "Rewards" then
		fillRewards(list, r)
	else
		fillSummary(list, r)
	end
	showMVP(r)
	ui:SetMainAction({
		Label = "Play Again",
		Enabled = true,
		OnPress = function()
			Remotes.FireServer("PlayAgain")
		end,
	})
	local actions = {}
	if r.Victory and not r.Endless then
		table.insert(actions, { Label = "Keep Going", OnPress = function()
			Remotes.FireServer("KeepGoing")
		end })
	end
	table.insert(actions, { Label = "Return to Lobby", OnPress = function()
		Remotes.FireServer("ReturnToLobby")
	end })
	ui:SetFooterActions(actions)
	local me = (r.Players or {})[tostring(player.UserId)]
	local title = outcomeLine(r)
	ui:SetHint(if me then `{title}  ·  +{commas(me.Glowshards or 0)} GLOWSHARDS` else title)
end

local shown = false -- this ending's report has opened once
local function open()
	if opening or ui:Current() == SCREEN then
		return
	end
	opening = true
	-- a victory's moment plays first (VictoryController, Prompt 25), once for each ending
	local tuning = Config.Get("Tuning", "Results")
	local outcome = RunState.Get("Outcome")
	local moment = not shown and (outcome == "CenturyVictory" or outcome == "DeepVictory")
	task.delay(if moment then tuning.VictoryDelaySeconds else tuning.OpenDelaySeconds, function()
		opening = false
		if RunState.Get("RunPhase") == "Ended" and results() and ui:Current() ~= SCREEN then
			shown = true
			ui:Open(SCREEN)
		end
	end)
end

function ResultsController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
end

function ResultsController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	ui:Register(SCREEN, {
		Title = "RUN REPORT",
		Subtitle = "STEADFAST SHELTER CO.  ·  END OF THE RUN",
		Tabs = {
			{ Id = "Summary", Label = "SUMMARY", Icon = "Icon_Grid" },
			{ Id = "Residents", Label = "RESIDENTS", Icon = "Icon_Medkit" },
			{ Id = "Rewards", Label = "REWARDS", Icon = "Icon_Glowshard" },
		},
		Layout = "List",
		Hint = "",
		OnOpen = function(p: Frame)
			page = p
			tab = "Summary"
			fill()
		end,
		OnTab = function(tabId: string, p: Frame)
			page = p
			tab = tabId
			fill()
		end,
		OnClose = function()
			page = nil
			-- closed while the run is over: it comes back, the run's end has nowhere else to go
			if RunState.Get("RunPhase") == "Ended" then
				task.delay(10, open)
			end
		end,
	})
	replica:Changed("Results"):Connect(function()
		if page then
			fill()
		elseif RunState.Get("RunPhase") == "Ended" then
			open()
		end
	end)
	RunState.Changed("RunPhase"):Connect(function()
		if RunState.Get("RunPhase") ~= "Ended" then
			shown = false -- Keep Going: the next ending is a new one
		end
		if RunState.Get("RunPhase") == "Ended" then
			open()
		elseif ui:Current() == SCREEN then
			ui:Close() -- Keep Going: back to the run
		end
	end)
	if RunState.Get("RunPhase") == "Ended" then
		open()
	end
	log:Debug("results screen registered")
end

return ResultsController
