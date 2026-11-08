--!strict
--[[
	Lib.UISamples: two dev-only screens that exercise The Frame before the real screens arrive
	with their prompts (DevController's ui.sample and ui.list). They read real content from
	Config, so every template gets used: tabs, cards in each rarity, the detail panel with its
	sections, the main action, chips, footer buttons and list rows.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent:WaitForChild("UIKit"))

local UISamples = {}

local RARITY: { [string]: string } = { Free = "Common", Common = "Common", Rare = "Rare", Epic = "Epic", Legendary = "Legendary" }

local function itemNames(kit: { any }): string
	local names = {}
	for _, stack in kit do
		local item = Config.Find("Items", stack.Item)
		table.insert(names, if item then item.Name else tostring(stack.Item))
	end
	return table.concat(names, " · ")
end

local function rarityOf(classId: string): string
	local class = Config.Get("Classes", classId)
	return RARITY[class.Tier] or "Common"
end

local function portrait(classId: string, large: boolean): string?
	local name = `Portrait_{classId}` .. (if large then "_Large" else "")
	if UIKit.Sprites[name] then
		return name
	end
	return if large then portrait(classId, false) else nil
end

local function section(ui: any, body: Instance, order: number, label: string, text: string)
	local s = ui:Clone("Section")
	s.LayoutOrder = order
	s.Label.Text = string.upper(label)
	s.Body.Text = text
	s.Parent = body
end

local function showClass(ui: any, page: Frame, classId: string)
	local class = Config.Get("Classes", classId)
	local detail: any = page:FindFirstChild("Detail")
	local hero = portrait(classId, true)
	local heroImage: any = detail.Hero:FindFirstChild("Image") -- "Image" is also a property
	heroImage.Visible = hero ~= nil
	if hero then
		ui:SetSprite(heroImage, hero)
	end
	ui:SetRarity(detail, rarityOf(classId))
	detail:FindFirstChild("Name").Text = string.upper(class.Name) -- "Name" is also a property
	local index = table.find(Config.Ids("Classes"), classId) or 0
	detail.Sub.Text = string.format("No. %02d  ·  STARTER KIT", index)
	local body = ui:Clear(detail.Body)
	section(ui, body, 1, "Kit", itemNames(class.Kit))
	section(ui, body, 2, "Passive", class.Passive.Text)
	section(ui, body, 3, `Ability  ·  {class.Ability.Name}`, class.Ability.Text)
	if class.Level2 then
		section(ui, body, 4, "Levels 2 and 3", class.Level2.Text)
	end
	ui:SetMainAction({
		Label = if class.Price > 0 then "Buy" else "Owned",
		Icon = if class.Price > 0 then "Icon_Glowshard" else nil,
		Price = if class.Price > 0 then tostring(class.Price) else nil,
		Enabled = class.Price > 0,
		OnPress = function()
			print(`[UISamples] main action pressed for {classId}`)
		end,
	})
end

local function fillCards(ui: any, page: Frame, tabId: string)
	local content: any = page:FindFirstChild("Content")
	local grid = ui:Clear(content.Grid)
	local first: string? = nil
	local cards: { [string]: any } = {}
	for i, classId in Config.Ids("Classes") do
		local rarity = rarityOf(classId)
		if tabId == "All" or tabId == rarity then
			local class = Config.Get("Classes", classId)
			local card = ui:Clone("Card")
			card.Name = classId
			card.LayoutOrder = i
			ui:SetRarity(card, rarity)
			local face = portrait(classId, false)
			card.Portrait.Visible = face ~= nil
			if face then
				ui:SetSprite(card.Portrait, face)
			end
			card:FindFirstChild("Name").Text = string.upper(class.Name)
			card.Sub.Text = itemNames(class.Kit)
			card.Price.Visible = class.Price > 0
			card.Price.Amount.Text = tostring(class.Price)
			card.Stamp.Visible = class.Price == 0
			card.Parent = grid
			cards[classId] = card
			first = first or classId
			card.Activated:Connect(function()
				for id, other in cards do
					ui:SetSprite(other.Lamp, if id == classId then "Lamp_Orange" else "Lamp_Off")
				end
				showClass(ui, page, classId)
			end)
		end
	end
	content.Empty.Visible = first == nil
	if first then
		ui:SetSprite(cards[first].Lamp, "Lamp_Orange")
		showClass(ui, page, first)
	end
end

local function glowshards(replica: any): string
	local profile = replica and replica:Get("Profiles", tostring(Players.LocalPlayer.UserId))
	return if type(profile) == "table" and type(profile.Glowshards) == "number" then tostring(profile.Glowshards) else "—"
end

-- Registers the sample screens once (ui: UIController, replica: ReplicaController).
function UISamples.Register(ui: any, replica: any)
	if ui:IsRegistered("Sample") then
		return
	end
	ui:Register("Sample", {
		Title = "Class catalog",
		Subtitle = "STEADFAST SHELTER CO.  ·  THE FRAME  ·  DEV SAMPLE",
		Tabs = {
			{ Id = "All", Label = "All", Icon = "Icon_Grid" },
			{ Id = "Common", Label = "Common", Icon = "Icon_Tag" },
			{ Id = "Rare", Label = "Rare", Icon = "Icon_Tag" },
			{ Id = "Epic", Label = "Epic", Icon = "Icon_Tag" },
			{ Id = "Legendary", Label = "Legendary", Icon = "Icon_Tag" },
		},
		Layout = "Grid",
		Hint = "A dev sample of The Frame, filled from Config. Real screens come with their prompts.",
		OnOpen = function()
			ui:SetChips({ { Icon = "Icon_Glowshard", Text = glowshards(replica) } })
			ui:SetFooterActions({
				{ Label = "Sort", OnPress = function() print("[UISamples] sort pressed") end },
				{ Label = "Filter", OnPress = function() print("[UISamples] filter pressed") end },
			})
		end,
		OnTab = function(tabId: string, page: Frame)
			fillCards(ui, page, tabId)
		end,
	})
	ui:Register("SampleList", {
		Title = "Stockpile",
		Subtitle = "STEADFAST SHELTER CO.  ·  THE FRAME  ·  DEV SAMPLE (LIST)",
		Tabs = { { Id = "All", Label = "Resources", Icon = "Icon_Grid" } },
		Layout = "List",
		Hint = "Rows instead of cards: the layout for lists and settings.",
		OnTab = function(_tabId: string, page: Frame)
			local content: any = page:FindFirstChild("Content")
			local rows = ui:Clear(content.List)
			for i, id in Config.Ids("Resources") do
				local resource = Config.Get("Resources", id)
				local row = ui:Clone("Row")
				row.LayoutOrder = i
				local icon = `Icon_{id}`
				if UIKit.Sprites[icon] then
					ui:SetSprite(row.Icon, icon)
					row.Icon.ImageColor3 = Color3.new(1, 1, 1)
				end
				row:FindFirstChild("Name").Text = string.upper(resource.Name)
				row.Value.Text = if resource.Kind == "Live" then "LIVE" else `{resource.Start} / {resource.Cap}`
				row.Parent = rows
			end
			local detail: any = page:FindFirstChild("Detail")
			detail.Tag.Visible = false
			detail.Hero.Visible = false
			detail:FindFirstChild("Name").Text = "STOCKPILE"
			detail.Sub.Text = "START / CAP"
			local body = ui:Clear(detail.Body)
			section(ui, body, 1, "From the bible", "Section 13: the team shares one stockpile that rooms fill and residents drain.")
			ui:SetMainAction(nil)
		end,
	})
end

return UISamples
