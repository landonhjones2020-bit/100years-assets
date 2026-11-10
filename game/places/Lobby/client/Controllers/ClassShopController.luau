--!strict
--[[
	ClassShopController: the Class Shop and Loadout screens (bible Section 18: "Class Shop | Today's
	shop, owned, all | Class cards | Kit, levels, price; Buy" and "Loadout | Class, talents, Legend,
	cosmetics | Owned items | Selected item; Equip"; the rules are Section 14's). Lobby only; Prompt
	21. Both are pages of The Frame (UIController); the server decides everything (ClassShopService).

	Class Shop
	* TODAY: today's four classes. A card shows its price; one the player bought since is stamped
	  OWNED, today's free trial FREE TRIAL, the wish WISHLIST. The main action buys (greyed out with
	  the Glowshards still needed), or TRY IT FREE equips the trial.
	* OWNED: every class the player owns, with its level. The main action equips.
	* ALL: the whole catalogue. A class not in today's shop can be wishlisted (the main action).
	* Chips: Glowshards, and the time to the daily reset. Footer: REROLL (free while one is left,
	  then the Robux price) and LOADOUT.

	Loadout (class only until talents, Legends and cosmetics arrive with their prompts)
	* The classes the player can bring: owned ones, and today's free trial. EQUIP sets it
	  (SetLoadoutClass); the equipped one's lamp is lit.

	Everything shown comes from the player's own profile (the Profiles collection: Classes,
	ClassShop, Loadout, Glowshards) and the Player's ShopDay and VIP attributes; the screens refill
	whenever the profile changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClassShop = require(Shared.Rules.ClassShop)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Lib = script.Parent.Parent:WaitForChild("Lib")
local ClassArt = require(Lib:WaitForChild("ClassArt"))

local player = Players.LocalPlayer

local ClassShopController = {
	Name = "ClassShopController",
	Dependencies = { "UIController", "ReplicaController" },
}

local ui: any = nil
local replica: any = nil

local selected: { [string]: string? } = {} -- per screen: the class whose detail shows

local function profile(): any
	local found = replica:Get("Profiles", tostring(player.UserId))
	return if type(found) == "table" and type(found.Classes) == "table" and type(found.ClassShop) == "table" then found else nil
end

local function shopDay(): number
	local day = player:GetAttribute("ShopDay")
	return if type(day) == "number" then day else ClassShop.Day(workspace:GetServerTimeNow())
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
end

local function resetIn(): number
	local at = ReplicatedStorage:GetAttribute("ShopResetAt")
	return if type(at) == "number" then at - workspace:GetServerTimeNow() else ClassShop.SecondsToReset(workspace:GetServerTimeNow())
end

local function chips()
	local data = profile()
	ui:SetChips({
		{ Icon = "Icon_Glowshard", Text = if data then tostring(data.Glowshards) else "—" },
		{ Icon = "Icon_Route", Text = clock(resetIn()) }, -- to the daily reset
	})
end

local function showDetail(page: Frame, classId: string, level: number?, sub: string)
	local class = Config.Get("Classes", classId)
	local detail: any = page:FindFirstChild("Detail")
	local hero = ClassArt.Portrait(classId, true)
	local heroImage: any = detail.Hero:FindFirstChild("Image")
	heroImage.Visible = true
	ui:SetSprite(heroImage, hero or ClassArt.Icon(classId))
	heroImage.ScaleType = if hero then Enum.ScaleType.Stretch else Enum.ScaleType.Fit
	ui:SetRarity(detail, ClassArt.Rarity(classId))
	detail:FindFirstChild("Name").Text = string.upper(class.Name)
	detail.Sub.Text = sub
	local body = ui:Clear(detail.Body)
	for i, section in ClassArt.Sections(classId, level) do
		local s = ui:Clone("Section")
		s.LayoutOrder = i
		s.Label.Text = string.upper(section.Label)
		s.Body.Text = section.Text
		s.Parent = body
	end
end

local function makeCard(grid: Instance, classId: string, order: number, stamp: string?, price: number?, sub: string): any
	local class = Config.Get("Classes", classId)
	local card: any = ui:Clone("Card")
	card.Name = classId
	card.LayoutOrder = order
	ui:SetRarity(card, ClassArt.Rarity(classId))
	local face = ClassArt.Portrait(classId, false)
	card.Portrait.Visible = true
	ui:SetSprite(card.Portrait, face or ClassArt.Icon(classId))
	card.Portrait.ScaleType = if face then Enum.ScaleType.Stretch else Enum.ScaleType.Fit -- an icon until its look is made
	card:FindFirstChild("Name").Text = string.upper(class.Name)
	card.Sub.Text = sub
	card.Price.Visible = price ~= nil
	if price then
		card.Price.Amount.Text = tostring(price)
	end
	card.Stamp.Visible = stamp ~= nil
	if stamp then
		ui:SetSprite(card.Stamp, stamp)
	end
	card.Parent = grid
	return card
end

-- The Class Shop ------------------------------------------------------------------------------------

local function shopAction(page: Frame, classId: string)
	local data = profile()
	if not data then
		return
	end
	local class = Config.Get("Classes", classId)
	local day = shopDay()
	local shop = data.ClassShop
	local owned = data.Classes[classId]
	local trial = ClassShop.Trial(shop, data.Classes, day)
	local inShop = shop.Day == day and table.find(shop.Slots, classId) ~= nil
	local sub = string.format("%s  ·  %s", string.upper(class.Tier), if owned then `LEVEL {owned.Level}` elseif class.Price > 0 then `{class.Price} GLOWSHARDS` else "FREE")
	showDetail(page, classId, if owned then owned.Level else nil, sub)
	if owned then
		local equipped = data.Loadout and data.Loadout.Class == classId
		ui:SetMainAction({
			Label = if equipped then "Equipped" else "Equip",
			Enabled = not equipped,
			OnPress = function()
				Remotes.FireServer("SetLoadoutClass", classId)
			end,
		})
	elseif inShop then
		local short = class.Price - data.Glowshards
		ui:SetMainAction({
			Label = if short > 0 then `{short} more` else "Buy",
			Icon = "Icon_Glowshard",
			Price = tostring(class.Price),
			Enabled = short <= 0,
			OnPress = function()
				Remotes.FireServer("ShopBuy", classId)
			end,
		})
	else
		local wished = shop.Wishlist == classId
		ui:SetMainAction({
			Label = if wished then "Wishlisted" else "Wishlist",
			Enabled = class.Price > 0,
			OnPress = function()
				Remotes.FireServer("ShopWish", if wished then "" else classId)
			end,
		})
	end
	local footer = {} -- three at most: the footer has room for no more
	if trial == classId then
		local equipped = data.Loadout and data.Loadout.Class == classId
		table.insert(footer, {
			Label = if equipped then "TRIAL EQUIPPED" else "TRY IT FREE TODAY",
			OnPress = function()
				Remotes.FireServer("SetLoadoutClass", classId)
			end,
		})
	elseif inShop and not owned and shop.Wishlist ~= classId then
		table.insert(footer, { Label = "WISHLIST", OnPress = function()
			Remotes.FireServer("ShopWish", classId)
		end })
	end
	local free = ClassShop.FreeLeft(shop, player:GetAttribute("VIP") == true)
	table.insert(footer, {
		Label = if free > 0 then `REROLL · {free} FREE` else `REROLL · R$ {Config.Get("Tuning", "ClassShop").RerollRobux}`,
		OnPress = function()
			Remotes.FireServer("ShopReroll")
		end,
	})
	table.insert(footer, { Label = "LOADOUT", OnPress = function()
		ui:Open("Loadout")
	end })
	ui:SetFooterActions(footer)
end

local function fillShop(page: Frame, tabId: string)
	local data = profile()
	local content: any = page:FindFirstChild("Content")
	local grid = ui:Clear(content.Grid)
	if not data then
		content.Empty.Visible = true
		return
	end
	local day = shopDay()
	local shop = data.ClassShop
	local trial = ClassShop.Trial(shop, data.Classes, day)
	local ids: { string } = {}
	if tabId == "Today" then
		ids = if shop.Day == day then table.clone(shop.Slots) else {}
	elseif tabId == "Owned" then
		for _, id in Config.Ids("Classes") do
			if data.Classes[id] then
				table.insert(ids, id)
			end
		end
	else
		ids = table.clone(Config.Ids("Classes"))
	end
	local cards: { [string]: any } = {}
	for i, classId in ids do
		local class = Config.Get("Classes", classId)
		local owned = data.Classes[classId]
		local stamp = if owned then "Stamp_Owned" elseif trial == classId then "Stamp_FreeTrial"
			elseif shop.Wishlist == classId then "Stamp_Wishlist" else nil
		local sub = if owned then `LEVEL {owned.Level}  ·  {class.Ability.Name}` else class.Ability.Name
		local card = makeCard(grid, classId, i, stamp, if owned or class.Price <= 0 then nil else class.Price, sub)
		cards[classId] = card
		card.Activated:Connect(function()
			selected.ClassShop = classId
			for id, other in cards do
				ui:SetSprite(other.Lamp, if id == classId then "Lamp_Orange" else "Lamp_Off")
			end
			shopAction(page, classId)
		end)
	end
	content.Empty.Visible = #ids == 0
	local pick = selected.ClassShop
	if not pick or not cards[pick] then
		pick = ids[1]
	end
	selected.ClassShop = pick
	if pick then
		ui:SetSprite(cards[pick].Lamp, "Lamp_Orange")
		shopAction(page, pick)
	else
		ui:SetMainAction({ Label = "Buy", Enabled = false })
		ui:SetFooterActions({ { Label = "LOADOUT", OnPress = function()
			ui:Open("Loadout")
		end } })
	end
end

-- The Loadout ---------------------------------------------------------------------------------------

local function loadoutAction(page: Frame, classId: string)
	local data = profile()
	if not data then
		return
	end
	local class = Config.Get("Classes", classId)
	local owned = data.Classes[classId]
	local equipped = data.Loadout and data.Loadout.Class == classId
	showDetail(page, classId, if owned then owned.Level else 1, if owned then `LEVEL {owned.Level}  ·  {string.upper(class.Tier)}`
		else "TODAY'S FREE TRIAL  ·  LEVEL 1")
	ui:SetMainAction({
		Label = if equipped then "Equipped" else "Equip",
		Enabled = not equipped,
		OnPress = function()
			Remotes.FireServer("SetLoadoutClass", classId)
		end,
	})
end

local function fillLoadout(page: Frame)
	local data = profile()
	local content: any = page:FindFirstChild("Content")
	local grid = ui:Clear(content.Grid)
	if not data then
		content.Empty.Visible = true
		return
	end
	local trial = ClassShop.Trial(data.ClassShop, data.Classes, shopDay())
	local ids: { string } = {}
	for _, id in Config.Ids("Classes") do
		if data.Classes[id] or id == trial then
			table.insert(ids, id)
		end
	end
	local equippedId = data.Loadout and data.Loadout.Class
	local cards: { [string]: any } = {}
	for i, classId in ids do
		local owned = data.Classes[classId]
		local class = Config.Get("Classes", classId)
		local card = makeCard(grid, classId, i, if owned then nil else "Stamp_FreeTrial", nil,
			if owned then `LEVEL {owned.Level}  ·  {class.Ability.Name}` else class.Ability.Name)
		cards[classId] = card
		ui:SetSprite(card.Lamp, if classId == equippedId then "Lamp_Green" else "Lamp_Off")
		card.Activated:Connect(function()
			selected.Loadout = classId
			loadoutAction(page, classId)
		end)
	end
	content.Empty.Visible = #ids == 0
	local pick = selected.Loadout
	if not pick or not cards[pick] then
		pick = if equippedId and cards[equippedId] then equippedId else ids[1]
	end
	selected.Loadout = pick
	if pick then
		loadoutAction(page, pick)
	end
	ui:SetFooterActions({ { Label = "CLASS SHOP", OnPress = function()
		ui:Open("ClassShop")
	end } })
end

local function refill()
	local current = ui:Current()
	local page = ui:Page()
	if not page then
		return
	end
	if current == "ClassShop" then
		chips()
		fillShop(page, ui:CurrentTab() or "Today")
	elseif current == "Loadout" then
		chips()
		fillLoadout(page)
	end
end

function ClassShopController:Init(registry)
	ui = registry.UIController
	replica = registry.ReplicaController
end

function ClassShopController:Start()
	ui:Register("ClassShop", {
		Title = "Class Shop",
		Subtitle = "STEADFAST SHELTER CO.  ·  TODAY'S SPECIALISTS",
		Tabs = {
			{ Id = "Today", Label = "Today", Icon = "Icon_Tag" },
			{ Id = "Owned", Label = "Owned", Icon = "Icon_Check" },
			{ Id = "All", Label = "All", Icon = "Icon_Grid" },
		},
		Layout = "Grid",
		Hint = "Four classes you don't own, new every day at 00:00 UTC. Wishlist one and it turns up within 3 days.",
		OnOpen = function()
			chips()
		end,
		OnTab = function(tabId: string, page: Frame)
			fillShop(page, tabId)
		end,
	})
	ui:Register("Loadout", {
		Title = "Loadout",
		Subtitle = "STEADFAST SHELTER CO.  ·  WHO GOES DOWN TODAY",
		Tabs = { { Id = "Class", Label = "Class", Icon = "Icon_Crew" } },
		Layout = "Grid",
		Hint = "Your class comes with its kit. Talents, Legends and outfits join the loadout later.",
		OnOpen = function()
			chips()
		end,
		OnTab = function(_tabId: string, page: Frame)
			fillLoadout(page)
		end,
	})
	replica:Changed("Profiles"):Connect(function()
		refill()
	end)
	player:GetAttributeChangedSignal("ShopDay"):Connect(refill)
	task.spawn(function()
		while true do
			task.wait(1)
			local current = ui:Current()
			if current == "ClassShop" or current == "Loadout" then
				chips()
			end
		end
	end)
end

return ClassShopController
