--!strict
--[[
	ExpeditionsController: the Expeditions screen and the distress markers (bible Sections 12 and 18:
	"Expeditions (run) | Surface, Deep, active | Teams and destinations | Supplies and risk; Send").
	Run place only; Prompt 18.

	* It opens from the EXPEDITIONS consoles in the Blast Door hall and in each Radio Room (prompts
	  with Kind Expeditions; ExpeditionService) and from DevTools (ui.open Expeditions).
	* SURFACE and DEEP: the cards are the residents who can go (alive, in the bunker, not cut off by
	  rubble), with the stats an expedition leans on (Grit, Speed, Strength); a card joins or leaves
	  the team (three at most, lamp lit). The footer sets the length (1, 2 or 3 cycles) and the
	  Medkits packed (0 to 3). Zone D: the destination, the team, when they'd be
	  back, the supplies taken from the stockpile (the top bar shows what's in it), the risk each
	  cycle (Rules.Expeditions.Odds) and what a cycle finds on average; SEND fires SendExpedition
	  (the server checks it all again).
	* ACTIVE: a card per expedition out (lamp green away, red pinned down, amber on the way home);
	  zone D its team, when it's back or the distress call's deadline, finds so far, supplies left
	  and its log.
	* Distress markers (Section 12: "a marker appears"): an expedition pinned down shows as a red
	  flare column at its spot (a short one in the Deep) with a plate (HUD.Templates.Distress) that
	  reads through walls from anywhere: DISTRESS CALL, the time left to reach them, who and where;
	  while the spot is off screen an arrow at the screen's edge (HUD.Templates.EdgeArrow) points to
	  it. Everything comes from the Expeditions, Residents and Rooms collections.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Constants = require(Shared.Constants)
local Expeditions = require(Shared.Rules.Expeditions)
local Grid = require(Shared.Rules.Grid)
local Log = require(Shared.Utilities.Log)
local Remotes = require(Shared.Remotes)
local RunState = require(Shared.RunState)
local UIKit = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UIKit"))

local player = Players.LocalPlayer
local log = Log.new("ExpeditionsController")

local ExpeditionsController = {
	Name = "ExpeditionsController",
	Dependencies = { "UIController", "ReplicaController" },
}

local RUST = Color3.fromHex("#B5412B")
local SURFACE_FLARE, DEEP_FLARE = 220, 12 -- studs: a column over the town, a short one in a cave
local FLARE_WIDTH = 2.4
local ARROW_Z = 30 -- the edge arrow sits over the HUD's top bar
local STATUS_TEXT: { [string]: string } = { Away = "away", Pinned = "pinned down", Following = "on the way home", Home = "home", Lost = "lost" }

local ui: any = nil
local replica: any = nil
local page: any = nil
local tab = "Surface"
local team: { string } = {}
local cycles = 1
local medkits = 0
local selectedActive: string? = nil

type Marker = { Column: BasePart, Anchor: BasePart, Gui: BillboardGui, Arrow: GuiObject?, Data: any }
local markers: { [string]: Marker } = {}

-- Helpers ------------------------------------------------------------------------------------------

local function order(id: string): number
	return tonumber(string.match(id, "%d+")) or 0
end

local function section(body: Instance, n: number, label: string, text: string)
	local s = ui:Clone("Section")
	s.LayoutOrder = n
	s.Label.Text = string.upper(label)
	s.Body.Text = text
	s.Parent = body
end

local function roomName(roomId: string?): string?
	local room = if roomId then replica:Get("Rooms", roomId) else nil
	local info = room and Config.Find("Rooms", room.Type)
	return if info then info.Name else nil
end

local function stock(id: string): number
	return tonumber(RunState.Get(id)) or 0
end

local function percent(x: number): string
	return `{math.floor(x * 100 + 0.5)}%`
end

local function clock(seconds: number?): string
	if not seconds then
		return "--:--"
	end
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The band a Deep expedition would go to: that of the bunker's deepest floor.
local function deepBand(): any
	local deepest = 1
	for key in replica:All("Cells") do
		local floor = Grid.Parse(key)
		if floor and floor > deepest then
			deepest = floor
		end
	end
	return Grid.BandOf(deepest)
end

local function destinationName(destination: string, band: string?): string
	if destination == "Deep" then
		local entry = band and Config.Find("DepthBands", band)
		return if entry then string.upper(Expeditions.Place(entry.Name)) else "THE DEEP"
	end
	return "BRIGHTWATER RUINS"
end

--[[
	Seconds left to reach a team pinned down: until the end of the day phase of cycle `deadline`
	(the clock's provisional lengths for the phases still to come; nil while the clock is stopped).
]]
local function timeLeft(deadline: number): number?
	local cycle = tonumber(RunState.Get("Cycle")) or 0
	local phase = RunState.Get("CyclePhase")
	local endsAt = RunState.Get("PhaseEndsAt")
	if type(endsAt) ~= "number" or (phase ~= "Day" and phase ~= "Surge") then
		return nil
	end
	local rest = math.max(0, endsAt - workspace:GetServerTimeNow())
	if cycle > deadline or (cycle == deadline and phase ~= "Day") then
		return 0
	end
	if cycle == deadline then
		return rest
	end
	local t = Config.Get("Tuning", "Clock")
	local scale = math.max(tonumber(RunState.Get("TimeScale")) or 1, 0.01)
	local total = rest + (if phase == "Day" then t.SurgeSeconds / scale else 0)
	total += (deadline - cycle - 1) * (t.DaySeconds + t.SurgeSeconds) / scale
	return total + t.DaySeconds / scale
end

-- The residents who can set out now: alive, in the bunker, not cut off.
local function candidates(): { { Id: string, R: any } }
	local list = {}
	for id, resident in replica:All("Residents") do
		if type(resident) == "table" and resident.State == "Alive" and not resident.Trapped then
			table.insert(list, { Id = id, R = resident })
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		return order(a.Id) < order(b.Id)
	end)
	return list
end

local function teamRecords(): ({ any }, { Expeditions.Stats })
	local records, stats = {}, {}
	for _, id in team do
		local resident = replica:Get("Residents", id)
		if type(resident) == "table" then
			table.insert(records, resident)
			table.insert(stats, resident.Stats)
		end
	end
	return records, stats
end

-- Drops team members who can no longer go (sent, hurt, gone).
local function pruneTeam()
	local kept = {}
	for _, id in team do
		local resident = replica:Get("Residents", id)
		if type(resident) == "table" and resident.State == "Alive" and not resident.Trapped then
			table.insert(kept, id)
		end
	end
	team = kept
end

-- Planning a trip (SURFACE, DEEP) -------------------------------------------------------------------

local render: () -> () -- below

local function footer()
	local t = Expeditions.Tuning()
	if tab == "Active" then
		ui:SetFooterActions({})
		return
	end
	ui:SetFooterActions({
		{ Label = `Length: {cycles} cycle{if cycles == 1 then "" else "s"}`, OnPress = function()
			cycles = if cycles >= t.Cycles.Max then t.Cycles.Min else cycles + 1
			render()
		end },
		{ Label = `Medkits: {medkits}`, OnPress = function()
			medkits = if medkits >= t.MedkitsMax then 0 else medkits + 1
			render()
		end },
	})
end

local function showPlan(detail: any)
	local destination = tab
	local band = if destination == "Deep" then deepBand() else nil
	local hero = if destination == "Deep" then "Icon_Pickaxe" else "Icon_Route"
	local heroImage: any = detail.Hero:FindFirstChild("Image")
	heroImage.Visible = UIKit.Sprites[hero] ~= nil
	if UIKit.Sprites[hero] then
		ui:SetSprite(heroImage, hero)
	end
	ui:SetRarity(detail, "Common")
	detail:FindFirstChild("Name").Text = if destination == "Deep" then "THE DEEP" else "THE SURFACE"
	detail.Sub.Text = if band then `{destinationName("Deep", band.Id)}{if band.Ore then `  ·  {string.upper(band.Ore)}` else ""}`
		else destinationName("Surface")
	local body = ui:Clear(detail.Body)
	local records, stats = teamRecords()
	local names = {}
	for _, resident in records do
		table.insert(names, resident.Name)
	end
	section(body, 1, "Team", if #names > 0 then Expeditions.Names(names) .. "." else "Pick 1 to 3 residents from the list.")
	local cycle = tonumber(RunState.Get("Cycle")) or 1
	section(body, 2, "Length", `{cycles} cycle{if cycles == 1 then "" else "s"}: back at the start of cycle {cycle + cycles}.`)
	local supplies = Expeditions.Supplies(math.max(#records, 1), cycles)
	local food = if #records > 0 then supplies.Food else 0
	local water = if #records > 0 then supplies.Water else 0
	section(body, 3, "Supplies", `{food} Food · {water} Water · {medkits} Medkit{if medkits == 1 then "" else "s"}`
		.. ` (the stockpile has {stock("Food")} Food, {stock("Water")} Water, {stock("Medkits")} Medkits).`)
	if #records > 0 then
		local odds = Expeditions.Odds(destination, stats)
		section(body, 4, "Risk each cycle", `{Expeditions.RiskLabel(odds)}: hurt {percent(odds.Hurt)} · distress call {percent(odds.Distress)}`
			.. ` · lost {percent(odds.Lost)}. Grit and Speed lower it; Medkits patch them up.`)
		local expected = Expeditions.Expected(destination, Expeditions.Team(stats, nil), if band then band.Ore else nil,
			{ Gear = true, Blueprint = true })
		local parts = {}
		for _, id in Config.Ids("Resources") do
			local amount = expected[id]
			if amount and amount >= 0.5 then
				table.insert(parts, `{math.floor(amount + 0.5)} {Config.Get("Resources", id).Name}`)
			end
		end
		section(body, 5, "Finds each cycle", `About {if #parts > 0 then table.concat(parts, ", ") else "nothing"}; sometimes a recruit.`)
	else
		section(body, 4, "Risk each cycle", "Tougher, faster residents (Grit, Speed) run into less trouble; stronger ones carry more home.")
	end
	local candidatesNow = {}
	for _, record in records do
		table.insert(candidatesNow, { State = record.State, Trapped = record.Trapped })
	end
	local ok = Expeditions.Check(destination, candidatesNow, cycles, medkits)
	local affordable = #records == 0 or (stock("Food") >= food and stock("Water") >= water and stock("Medkits") >= medkits)
	ui:SetMainAction({
		Label = "Send",
		Price = if #records > 0 then `{food} FOOD · {water} WATER` else nil,
		Enabled = ok and affordable,
		OnPress = function()
			local ids = table.clone(team)
			Remotes.FireServer("SendExpedition", destination, ids, cycles, medkits)
			team = {}
			task.delay(0.4, function()
				if page then
					ui:SelectTab("Active")
				end
			end)
		end,
	})
end

local function fillPlan(content: any, detail: any)
	pruneTeam()
	local grid = ui:Clear(content.Grid)
	local list = candidates()
	for i, entry in list do
		local resident = entry.R
		local card = ui:Clone("Card")
		card.Name = entry.Id
		card.LayoutOrder = i
		ui:SetRarity(card, if resident.Tier == "Free" then "Common" else resident.Tier)
		local face = if UIKit.Sprites["Portrait_Survivor"] then "Portrait_Survivor" else nil
		card.Portrait.Visible = face ~= nil
		if face then
			ui:SetSprite(card.Portrait, face)
		end
		card:FindFirstChild("Name").Text = string.upper(resident.Name)
		local s = resident.Stats or {}
		card.Sub.Text = `GRT {s.Grit or 0} · SPD {s.Speed or 0} · STR {s.Strength or 0}  ·  {roomName(resident.Job) or "Idle"}`
		card.Price.Visible = false
		card.Stamp.Visible = false
		local inTeam = table.find(team, entry.Id) ~= nil
		ui:SetSprite(card.Lamp, if inTeam then "Lamp_Orange" else "Lamp_Off")
		card.Activated:Connect(function()
			local at = table.find(team, entry.Id)
			if at then
				table.remove(team, at)
			elseif #team >= Expeditions.Tuning().Size.Max then
				ui:Notice(`{Expeditions.Tuning().Size.Max} residents at most`, "Warning")
				return
			else
				table.insert(team, entry.Id)
			end
			render()
		end)
		card.Parent = grid
	end
	content.Empty.Visible = #list == 0
	showPlan(detail)
	ui:SetHint(if #list == 0 then "Nobody can set out now" else `{#team} of {Expeditions.Tuning().Size.Max} picked`)
end

-- Expeditions out (ACTIVE) ------------------------------------------------------------------------

local function stateText(e: any): (string, string)
	local pinned, following = 0, 0
	for _, m in e.Members do
		if m.Status == "Pinned" then
			pinned += 1
		elseif m.Status == "Following" then
			following += 1
		end
	end
	if pinned > 0 then
		return "DISTRESS CALL", "Lamp_Red"
	elseif following > 0 then
		return "ON THE WAY HOME", "Lamp_Amber"
	end
	return `AWAY · CYCLE {math.min(e.Done + 1, e.Cycles)} OF {e.Cycles}`, "Lamp_Green"
end

local function showActive(detail: any, id: string?)
	local e = if id then replica:Get("Expeditions", id) else nil
	local heroImage: any = detail.Hero:FindFirstChild("Image")
	if not e then
		heroImage.Visible = false
		detail:FindFirstChild("Name").Text = "NOBODY OUT"
		detail.Sub.Text = ""
		ui:Clear(detail.Body)
		ui:SetMainAction(nil)
		return
	end
	heroImage.Visible = UIKit.Sprites["Icon_Radio"] ~= nil
	if UIKit.Sprites["Icon_Radio"] then
		ui:SetSprite(heroImage, "Icon_Radio")
	end
	ui:SetRarity(detail, "Common")
	detail:FindFirstChild("Name").Text = if e.Destination == "Deep" then "THE DEEP" else "THE SURFACE"
	local state = stateText(e)
	detail.Sub.Text = state
	local body = ui:Clear(detail.Body)
	local who = {}
	for _, m in e.Members do
		table.insert(who, `{m.Name} ({STATUS_TEXT[m.Status] or string.lower(m.Status)})`)
	end
	section(body, 1, "Team", table.concat(who, ", ") .. ".")
	local pinned = false
	for _, m in e.Members do
		if m.Status == "Pinned" then
			pinned = true
		end
	end
	if pinned and e.Deadline then
		section(body, 2, "Distress call", `Pinned down at {e.Where or "?"}. Reach them before the end of cycle {e.Deadline}'s day:`
			.. ` {clock(timeLeft(e.Deadline))} left.`)
	elseif e.State == "Away" or e.State == "Calling" then
		section(body, 2, "Back", `At the start of cycle {e.Back}.`)
	else
		section(body, 2, "Back", "On the way home with whoever reached them.")
	end
	local finds = {}
	for _, resource in Config.Ids("Resources") do
		local amount = e.Finds and e.Finds[resource]
		if amount and amount > 0 then
			table.insert(finds, `{amount} {Config.Get("Resources", resource).Name}`)
		end
	end
	if (e.Recruits or 0) > 0 then
		table.insert(finds, "a recruit")
	end
	section(body, 3, "Finds so far", if #finds > 0 then table.concat(finds, ", ") .. "." else "Nothing yet.")
	section(body, 4, "Supplies left", `{e.Food} Food · {e.Water} Water · {e.Medkits} Medkits.`)
	local history = e.Log or {}
	local lines = {}
	for i = math.max(1, #history - 4), #history do
		table.insert(lines, history[i])
	end
	section(body, 5, "Log", if #lines > 0 then table.concat(lines, "\n") else "Nothing yet.")
	ui:SetMainAction({ Label = if pinned then "Go get them" elseif state == "ON THE WAY HOME" then "Coming home" else "Away", Enabled = false })
end

local function fillActive(content: any, detail: any)
	local grid = ui:Clear(content.Grid)
	local list = {}
	for id, e in replica:All("Expeditions") do
		if type(e) == "table" then
			table.insert(list, { Id = id, E = e })
		end
	end
	table.sort(list, function(a: any, b: any): boolean
		return order(a.Id) < order(b.Id)
	end)
	local still = false
	for i, entry in list do
		local e = entry.E
		local card = ui:Clone("Card")
		card.Name = entry.Id
		card.LayoutOrder = i
		ui:SetRarity(card, "Common")
		card.Portrait.Visible = UIKit.Sprites["Icon_Radio"] ~= nil
		if UIKit.Sprites["Icon_Radio"] then
			ui:SetSprite(card.Portrait, "Icon_Radio")
		end
		card:FindFirstChild("Name").Text = destinationName(e.Destination, e.Band)
		local names = {}
		for _, m in e.Members do
			table.insert(names, (string.match(m.Name, "^(%S+)") or m.Name))
		end
		local state, lamp = stateText(e)
		card.Sub.Text = `{string.upper(table.concat(names, ", "))}  ·  {state}`
		card.Price.Visible = false
		card.Stamp.Visible = false
		ui:SetSprite(card.Lamp, if entry.Id == selectedActive then "Lamp_Orange" else lamp)
		card.Activated:Connect(function()
			selectedActive = entry.Id
			render()
		end)
		card.Parent = grid
		if entry.Id == selectedActive then
			still = true
		end
	end
	if not still then
		selectedActive = if list[1] then list[1].Id else nil
	end
	content.Empty.Visible = #list == 0
	showActive(detail, selectedActive)
	ui:SetHint(if #list == 0 then "No expeditions out" else `{#list} expedition{if #list == 1 then "" else "s"} out`)
end

render = function()
	if not page then
		return
	end
	local content: any = page:FindFirstChild("Content")
	local detail: any = page:FindFirstChild("Detail")
	ui:SetChips({
		{ Icon = "Icon_Food", Text = tostring(stock("Food")) },
		{ Icon = "Icon_Water", Text = tostring(stock("Water")) },
		{ Icon = "Icon_Medkit", Text = tostring(stock("Medkits")) },
	})
	footer()
	if tab == "Active" then
		fillActive(content, detail)
	else
		fillPlan(content, detail)
	end
end

-- Distress markers --------------------------------------------------------------------------------

local function effectsFolder(): Folder
	local found = workspace:FindFirstChild("LocalEffects")
	if found and found:IsA("Folder") then
		return found
	end
	local folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = workspace
	return folder
end

local function hud(): ScreenGui?
	local gui = player:FindFirstChild("PlayerGui")
	local found = gui and gui:FindFirstChild("HUD")
	return if found and found:IsA("ScreenGui") then found else nil
end

local function template(name: string): Instance?
	local root = hud()
	local templates = root and root:FindFirstChild("Templates")
	local found = templates and templates:FindFirstChild(name)
	return if found then found:Clone() else nil
end

local function removeMarker(id: string)
	local m = markers[id]
	if not m then
		return
	end
	markers[id] = nil
	m.Column:Destroy()
	m.Anchor:Destroy()
	if m.Arrow then
		m.Arrow:Destroy()
	end
end

local function placeMarker(id: string, e: any)
	local at = Vector3.new(e.Marker.X, e.Marker.Y, e.Marker.Z)
	local m = markers[id]
	if not m then
		local gui = template("Distress") :: BillboardGui?
		if not gui then
			log:Warn("no HUD.Templates.Distress: run studio/ui/patches/HUD_P18.lua")
			return
		end
		local height = if e.Destination == "Deep" then DEEP_FLARE else SURFACE_FLARE
		local column = Instance.new("Part")
		column.Name = `Distress_{id}`
		column.Anchored = true
		column.CanCollide = false
		column.CanQuery = false
		column.CanTouch = false
		column.CastShadow = false
		column.Material = Enum.Material.Neon
		column.Color = RUST
		column.Transparency = 0.35
		column.Size = Vector3.new(FLARE_WIDTH, height, FLARE_WIDTH)
		column.Parent = effectsFolder()
		local anchor = Instance.new("Part")
		anchor.Name = `DistressPlate_{id}`
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Parent = effectsFolder()
		gui.Adornee = anchor
		gui.Enabled = true
		gui.Parent = anchor
		local arrow = template("EdgeArrow") :: GuiObject?
		local root = hud()
		if arrow and root then
			arrow.Name = `DistressArrow_{id}`
			arrow.Visible = false
			arrow.ZIndex = ARROW_Z
			arrow.Parent = root
		end
		m = { Column = column, Anchor = anchor, Gui = gui, Arrow = arrow, Data = e }
		markers[id] = m
	end
	local marker = m :: Marker
	marker.Data = e
	marker.Column.Position = at + Vector3.new(0, marker.Column.Size.Y / 2, 0)
	marker.Anchor.Position = at + Vector3.new(0, 3, 0)
	local plate: any = marker.Gui:FindFirstChild("Plate")
	if plate then
		local pinned = {}
		for _, member in e.Members do
			if member.Status == "Pinned" then
				table.insert(pinned, member.Name)
			end
		end
		plate.Names.Text = string.upper(Expeditions.Names(pinned))
		plate.Where.Text = tostring(e.Where or "")
	end
end

local function syncMarkers()
	local wanted: { [string]: boolean } = {}
	for id, e in replica:All("Expeditions") do
		if type(e) == "table" and e.Marker and e.Deadline then
			local pinned = false
			for _, member in e.Members do
				if member.Status == "Pinned" then
					pinned = true
				end
			end
			if pinned then
				wanted[id] = true
				placeMarker(id, e)
			end
		end
	end
	for id in table.clone(markers) do
		if not wanted[id] then
			removeMarker(id)
		end
	end
end

local function updateMarkers()
	if next(markers) == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local root = hud()
	local pulse = 0.3 + 0.2 * math.sin(os.clock() * 4)
	for _, m in markers do
		local left = timeLeft(m.Data.Deadline)
		local plate: any = m.Gui:FindFirstChild("Plate")
		if plate then
			plate.Count.Text = clock(left)
		end
		m.Column.Transparency = pulse
		local arrow = m.Arrow
		if arrow and camera and root then
			local point, visible = camera:WorldToViewportPoint(m.Anchor.Position)
			local size = camera.ViewportSize
			if visible and point.Z > 0 then
				arrow.Visible = false
			else
				local half = size / 2
				local v = Vector2.new(point.X, point.Y) - half
				if point.Z < 0 then
					v = -v
				end
				if v.Magnitude < 1 then
					v = Vector2.new(0, -1)
				end
				local nx, ny = v.X / half.X, v.Y / half.Y
				local edge = 1 / math.max(math.abs(nx), math.abs(ny))
				nx, ny = nx * edge, ny * edge
				arrow.Position = UDim2.fromScale(0.5 + nx * 0.44, 0.5 + ny * 0.42)
				arrow.Rotation = math.deg(math.atan2(nx * half.X, -ny * half.Y))
				arrow.Visible = true
			end
		end
	end
end

-- Lifecycle ---------------------------------------------------------------------------------------

function ExpeditionsController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
end

function ExpeditionsController:Start()
	if Constants.PlaceKind() ~= "Run" then
		return
	end
	ui:Register("Expeditions", {
		Title = "EXPEDITIONS",
		Subtitle = "STEADFAST SHELTER CO.  ·  FIELD OPERATIONS",
		Tabs = {
			{ Id = "Surface", Label = "SURFACE", Icon = "Icon_Route" },
			{ Id = "Deep", Label = "DEEP", Icon = "Icon_Pickaxe" },
			{ Id = "Active", Label = "ACTIVE", Icon = "Icon_Radio" },
		},
		Layout = "Grid",
		Hint = "",
		OnOpen = function(p: Frame, args: any)
			page = p
			tab = if type(args) == "table" and (args.Tab == "Deep" or args.Tab == "Active") then args.Tab else "Surface"
			if tab ~= "Surface" then
				ui:SelectTab(tab)
			end
			render()
		end,
		OnTab = function(tabId: string, p: Frame)
			page = p
			tab = tabId
			render()
		end,
		OnClose = function()
			page = nil
		end,
	})
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who == player and prompt:GetAttribute("Kind") == "Expeditions" then
			ui:Open("Expeditions", { Tab = "Surface" })
		end
	end)
	local pending = false
	local function changed()
		syncMarkers()
		if page and not pending then
			pending = true
			task.delay(0.3, function()
				pending = false
				render()
			end)
		end
	end
	replica:Changed("Expeditions"):Connect(changed)
	replica:Changed("Residents"):Connect(function()
		if page and not pending then
			pending = true
			task.delay(0.3, function()
				pending = false
				render()
			end)
		end
	end)
	syncMarkers()
	RunService.RenderStepped:Connect(updateMarkers)
	log:Debug("Expeditions screen registered")
end

return ExpeditionsController
