-- A0 sample: the Class Shop in The Frame (bible Section 18), skinned with the UI kit.
-- Static sample content from bible Section 14 (four classes you don't own, one per rarity).
-- Zones: A top bar, B tab rail, C content, D detail panel with the main action, E footer.
local sg = screen("A0_ClassShop")
new("Frame", sg, "Dim", { pos = { 0, 0 }, size = { 1, 1 }, bg = Color3.fromHex("#0B121A"), bgT = 0.3 })
local cab = new("ImageLabel", sg, "Cabinet", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.975, 0.955 }, sprite = "Panel_Teal" })

-- A. top bar: title plate, Glowshards, close
local top = new("Frame", cab, "TopBar", { pos = { 0.014, 0.024 }, size = { 0.972, 0.086 } })
local plate = new("ImageLabel", top, "Title", { pos = { 0, 0.04 }, size = { 0.235, 0.92 }, sprite = "Plate_Cream" })
text(plate, "Text", "CLASS SHOP", { pos = { 0.1, 0.15 }, size = { 0.8, 0.7 }, font = F.title, color = COL.navy, alignX = CENTER })
text(top, "Byline", "STEADFAST SHELTER CO.  ·  CLASS CATALOG  ·  ISSUE 1958-04",
	{ pos = { 0.252, 0.32 }, size = { 0.42, 0.38 }, font = F.typed, color = COL.cream, transp = 0.15 })
local chip = new("ImageLabel", top, "Glowshards", { pos = { 0.895, 0.5 }, anchor = { 1, 0.5 }, size = { 0.13, 0.78 }, sprite = "Chip_Navy" })
new("ImageLabel", chip, "Icon", { pos = { 0.05, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.95 }, aspect = 1, dom = "H", sprite = "Icon_Glowshard" })
text(chip, "Amount", "165", { pos = { 0.38, 0.17 }, size = { 0.52, 0.66 }, font = F.num, color = COL.cream })
text(top, "CloseHint", "CLOSE", { pos = { 0.947, 0.5 }, anchor = { 1, 0.5 }, size = { 0.045, 0.3 }, font = F.label, color = COL.cream, alignX = RIGHT, transp = 0.1 })
new("ImageButton", top, "Close", { pos = { 1, 0.5 }, anchor = { 1, 0.5 }, size = { 1, 0.98 }, aspect = 1, dom = "H",
	sprite = "Close_Up", states = { "Close_Up", "Close_Down" } })

-- B. tab rail: stamped steel plates, the open one with a teal enamel inlay
local tabs = new("Frame", cab, "Tabs", { pos = { 0.014, 0.13 }, size = { 0.152, 0.6 } })
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0.025, 0)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = tabs
for i, t in { { "TODAY'S SHOP", "Icon_Tag", true }, { "OWNED", "Icon_Check", false }, { "ALL CLASSES", "Icon_Grid", false } } do
	local b = new("ImageButton", tabs, "Tab" .. i, { size = { 1, 0.15 }, aspect = 3.1, sprite = t[3] and "Tab_On" or "Tab_Off" })
	b.LayoutOrder = i
	local c = new("Frame", b, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
	new("ImageLabel", c, "Icon", { pos = { 0.26, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.5 }, aspect = 1, dom = "H",
		sprite = t[2], tint = t[3] and COL.cream or COL.navy })
	text(c, "Label", t[1], { pos = { 0.37, 0.28 }, size = { 0.56, 0.44 }, font = F.label, color = t[3] and COL.cream or COL.navy })
end

-- C. content: a recessed well with the shop ticker and the cards
local well = new("ImageLabel", cab, "Content", { pos = { 0.176, 0.13 }, size = { 0.514, 0.785 }, sprite = "Well_Teal" })
local tick = new("ImageLabel", well, "Ticker", { pos = { 0.03, 0.025 }, size = { 0.94, 0.085 }, sprite = "Telegram" })
text(tick, "Text", "TODAY'S SHOP  ·  4 CLASSES YOU DON'T OWN  ·  NEW STOCK IN 06:42:10",
	{ pos = { 0.05, 0.38 }, size = { 0.9, 0.4 }, font = F.typed, color = COL.navy })
local grid = new("Frame", well, "Grid", { pos = { 0.03, 0.125 }, size = { 0.94, 0.86 } })
local g = Instance.new("UIGridLayout")
g.CellSize = UDim2.fromScale(0.32, 0.49)
g.CellPadding = UDim2.fromScale(0.03, 0.022)
g.FillDirectionMaxCells = 2
g.HorizontalAlignment = Enum.HorizontalAlignment.Center
g.VerticalAlignment = Enum.VerticalAlignment.Center
g.SortOrder = Enum.SortOrder.LayoutOrder
local ar = Instance.new("UIAspectRatioConstraint")
ar.AspectRatio = 0.8
ar.Parent = g
g.Parent = grid

local function card(i: number, cls: string, rarity: string, price: number, kit: string, portrait: string, opts: { [string]: any })
	local c = new("ImageButton", grid, "Card_" .. cls:gsub(" ", ""), { sprite = "Card_" .. rarity })
	c.LayoutOrder = i
	new("ImageLabel", c, "Portrait", { pos = { 0.075, 0.048 }, size = { 0.85, 0.58 }, sprite = portrait, z = 2 })
	new("ImageLabel", c, "Tag", { pos = { 39 / 400, 289 / 500 }, size = { 166 / 400, 50 / 500 }, sprite = "Card_" .. rarity,
		crop = { 39, 289, 166, 50 }, z = 3 })
	text(c, "Name", cls:upper(), { pos = { 0.075, 0.69 }, size = { 0.85, 0.08 }, font = F.title, color = COL.navy, z = 3 })
	text(c, "Kit", kit, { pos = { 0.075, 0.775 }, size = { 0.85, 0.05 }, font = F.body, color = COL.ink, z = 3 })
	new("ImageLabel", c, "Lamp", { pos = { 0.13, 0.91 }, anchor = { 0.5, 0.5 }, size = { 0.085, 0.068 }, aspect = 1,
		sprite = opts.selected and "Lamp_Orange" or "Lamp_Off", z = 3 })
	local pc = new("ImageLabel", c, "Price", { pos = { 0.925, 0.955 }, anchor = { 1, 1 }, size = { 0.44, 0.088 }, sprite = "Chip_Cream", z = 3 })
	new("ImageLabel", pc, "Icon", { pos = { 0.07, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 1.1 }, aspect = 1, dom = "H", sprite = "Icon_Glowshard", z = 4 })
	text(pc, "Amount", tostring(price), { pos = { 0.44, 0.15 }, size = { 0.46, 0.7 }, font = F.num, color = COL.navy, z = 4 })
	if opts.stamp then
		new("ImageLabel", c, "Stamp", { pos = { 0.27, 0.115 }, anchor = { 0.5, 0.5 }, size = { 0.44, 0.22 }, aspect = 2, sprite = opts.stamp, z = 5 })
	end
	return c
end
card(1, "Security", "Common", 40, "Shock Baton · Service Revolver", "Portrait_Security", { selected = true })
card(2, "Quartermaster", "Rare", 120, "Pump Shotgun · Wrench", "Portrait_Quartermaster", { stamp = "Stamp_FreeTrial" })
card(3, "Warden", "Epic", 300, "Service Revolver · Shock Baton", "Portrait_Warden", {})
card(4, "Mad Scientist", "Legendary", 500, "Arc Rifle · Shock Baton", "Portrait_MadScientist", {})

-- D. detail panel: a cream catalog page; the main action is pinned to the bottom
local det = new("ImageLabel", cab, "Detail", { pos = { 0.7, 0.13 }, size = { 0.286, 0.785 }, sprite = "Paper" })
local hero = new("ImageLabel", det, "Hero", { pos = { 0.11, 0.028 }, size = { 0.78, 0.44 }, aspect = 348 / 298,
	sprite = "Card_Common", crop = { 26, 20, 348, 298 } })
new("ImageLabel", hero, "Portrait", { pos = { 4 / 348, 4 / 298 }, size = { 340 / 348, 290 / 298 }, sprite = "Portrait_Security_Large", z = 2 })
new("ImageLabel", det, "Tag", { pos = { 0.135, 0.42 }, size = { 0.37, 0.0735 }, aspect = 166 / 50,
	sprite = "Card_Common", crop = { 39, 289, 166, 50 }, z = 3 })
text(det, "Name", "SECURITY", { pos = { 0.07, 0.505 }, size = { 0.55, 0.062 }, font = F.title, color = COL.navy })
text(det, "Catalog", "No. 05  ·  STARTER KIT", { pos = { 0.55, 0.518 }, size = { 0.38, 0.032 }, font = F.typed, color = COL.ink, alignX = RIGHT })
local function section(y: number, label: string, body: string)
	-- every body line has the same height, so TextScaled gives them all the same size
	text(det, label:gsub("%W", "") .. "Label", label, { pos = { 0.07, y }, size = { 0.86, 0.02 }, font = F.label, color = COL.teal })
	text(det, label:gsub("%W", ""), body, { pos = { 0.07, y + 0.023 }, size = { 0.86, 0.024 }, font = F.body, color = COL.navy })
end
text(det, "KitLabel", "KIT", { pos = { 0.07, 0.58 }, size = { 0.86, 0.02 }, font = F.label, color = COL.teal })
new("ImageLabel", det, "KitIcon", { pos = { 0.065, 0.598 }, size = { 0.1, 0.062 }, aspect = 1, sprite = "Icon_ServiceRevolver" })
text(det, "Kit", "Service Revolver  ·  Shock Baton", { pos = { 0.175, 0.616 }, size = { 0.76, 0.024 }, font = F.body, color = COL.navy })
section(0.672, "PASSIVE", "+30 health. Residents near you deal +25% damage.")
section(0.735, "ABILITY  ·  HOLD THE LINE  ·  45 S", "Draws monsters to you and halves the damage you take for 8 s.")
section(0.798, "LEVELS 2 AND 3", "Blast Door +20% health. Armed residents answer your rally at once.")
local buy = new("ImageButton", det, "MainAction", { pos = { 0.5, 0.968 }, anchor = { 0.5, 1 }, size = { 0.88, 0.086 },
	sprite = "Button_Signal_Up", states = { "Button_Signal_Up", "Button_Signal_Down", "Button_Signal_Hover" } })
local bc = new("Frame", buy, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
text(bc, "Label", "BUY", { pos = { 0.1, 0.2 }, size = { 0.4, 0.58 }, font = F.title, color = COL.cream })
new("ImageLabel", bc, "Icon", { pos = { 0.58, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.86 }, aspect = 1, dom = "H", sprite = "Icon_Glowshard" })
text(bc, "Price", "40", { pos = { 0.72, 0.2 }, size = { 0.2, 0.58 }, font = F.num, color = COL.cream })

-- E. footer: secondary actions and a hint
local foot = new("Frame", cab, "Footer", { pos = { 0.014, 0.93 }, size = { 0.972, 0.048 } })
local function footButton(name: string, label: string, x: number, w: number)
	local b = new("ImageButton", foot, name, { pos = { x, 0 }, size = { w, 1 }, sprite = "Button_Teal_Up",
		states = { "Button_Teal_Up", "Button_Teal_Down" } })
	local c = new("Frame", b, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
	text(c, "Label", label, { pos = { 0.08, 0.24 }, size = { 0.84, 0.52 }, font = F.label, color = COL.cream, alignX = CENTER })
end
footButton("Reroll", "REROLL  ·  1 FREE", 0, 0.15)
footButton("Wishlist", "WISHLIST", 0.16, 0.11)
text(foot, "Hint", "A class on your wishlist turns up in your shop within 3 days.",
	{ pos = { 0.3, 0.22 }, size = { 0.46, 0.56 }, font = F.typed, color = COL.cream, transp = 0.1 })
text(foot, "Keys", "ESC  CLOSE     ENTER  BUY", { pos = { 0.78, 0.25 }, size = { 0.22, 0.5 }, font = F.label,
	color = COL.cream, alignX = RIGHT, transp = 0.3 })

sg.Parent = game:GetService("StarterGui")
return "A0_ClassShop built: " .. #sg:GetDescendants() .. " instances"
