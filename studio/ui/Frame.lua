-- The Frame (bible Section 18): the one layout every menu screen uses, built in both places.
-- Zones: A top bar, B tab rail, C content, D detail panel, E footer. A screen is a page that
-- fills B, C and D (Templates.Page, or a page built for it under Cabinet.Pages);
-- UIController.Open(screen) shows it and sets the title. The main action and the close button
-- never move. Docked mode (the Command View) hides the dim and the backplate and shows the dock
-- plates, so zone C shows the live bunker.
local sg = screen("Frame", 5)
sg.Enabled = false
new("Frame", sg, "Dim", { pos = { 0, 0 }, size = { 1, 1 }, bg = COL.night, bgT = 0.3 })
local cab = new("Frame", sg, "Cabinet", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.975, 0.955 } })
new("ImageLabel", cab, "Backplate", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Panel_Teal" })
local dock = new("Frame", cab, "DockPlates", { pos = { 0, 0 }, size = { 1, 1 }, visible = false })
new("ImageLabel", dock, "Top", { pos = { 0, 0 }, size = { 1, 0.122 }, sprite = "Panel_Teal" })
new("ImageLabel", dock, "Bottom", { pos = { 0, 0.912 }, size = { 1, 0.088 }, sprite = "Panel_Teal" })
new("ImageLabel", dock, "Left", { pos = { 0, 0.1 }, size = { 0.172, 0.83 }, sprite = "Panel_Teal" })
new("ImageLabel", dock, "Right", { pos = { 0.692, 0.1 }, size = { 0.308, 0.83 }, sprite = "Panel_Teal" })

-- A. top bar: the title plate, the screen's byline, currency or resource chips, close
local top = new("Frame", cab, "TopBar", { pos = { 0.014, 0.024 }, size = { 0.972, 0.086 }, z = 3 })
local plate = new("ImageLabel", top, "Title", { pos = { 0, 0.04 }, size = { 0.235, 0.92 }, sprite = "Plate_Cream" })
text(plate, "Text", "SCREEN", { pos = { 0.1, 0.15 }, size = { 0.8, 0.7 }, font = F.title, color = COL.navy, alignX = CENTER })
text(top, "Subtitle", "STEADFAST SHELTER CO.", { pos = { 0.252, 0.32 }, size = { 0.36, 0.38 }, font = F.typed,
	color = COL.cream, transp = 0.15 })
local chips = new("Frame", top, "Chips", { pos = { 0.9, 0.5 }, anchor = { 1, 0.5 }, size = { 0.28, 0.78 } })
list(chips, "H", 0.03, "Right", "Center")
text(top, "CloseHint", "CLOSE", { pos = { 0.947, 0.5 }, anchor = { 1, 0.5 }, size = { 0.045, 0.3 }, font = F.label,
	color = COL.cream, alignX = RIGHT, transp = 0.1 })
button(top, "Close", { pos = { 1, 0.5 }, anchor = { 1, 0.5 }, size = { 1, 0.98 }, aspect = 1, dom = "H" },
	{ "Close_Up", "Close_Down" })

-- B, C, D: pages go here
new("Frame", cab, "Pages", { pos = { 0, 0 }, size = { 1, 1 }, z = 2 })

-- D, bottom: the main action, in the same place on every screen
local main = button(cab, "MainAction", { pos = { 0.843, 0.9 }, anchor = { 0.5, 1 }, size = { 0.2517, 0.0675 }, z = 4 },
	{ "Button_Signal_Up", "Button_Signal_Down", "Button_Signal_Hover", "Button_Signal_Disabled" })
text(main.Content, "Label", "ACTION", { pos = { 0.1, 0.2 }, size = { 0.46, 0.58 }, font = F.title, color = COL.cream })
new("ImageLabel", main.Content, "Icon", { pos = { 0.58, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.86 }, aspect = 1, dom = "H",
	sprite = "Icon_Glowshard", visible = false })
text(main.Content, "Price", "", { pos = { 0.72, 0.2 }, size = { 0.2, 0.58 }, font = F.num, color = COL.cream })

-- E. footer: secondary actions, a hint, the keys
local foot = new("Frame", cab, "Footer", { pos = { 0.014, 0.93 }, size = { 0.972, 0.048 }, z = 3 })
local acts = new("Frame", foot, "Actions", { pos = { 0, 0 }, size = { 0.3, 1 } })
list(acts, "H", 0.03)
text(foot, "Hint", "", { pos = { 0.31, 0.22 }, size = { 0.46, 0.56 }, font = F.typed, color = COL.cream, transp = 0.1 })
text(foot, "Keys", "", { pos = { 0.78, 0.25 }, size = { 0.22, 0.5 }, font = F.label, color = COL.cream, alignX = RIGHT,
	transp = 0.3 })

-- Templates: code clones these and fills them in; it never builds layout
local T = folder(sg, "Templates")

local page = new("Frame", T, "Page", { pos = { 0, 0 }, size = { 1, 1 }, visible = false })
local tabs = new("Frame", page, "Tabs", { pos = { 0.014, 0.13 }, size = { 0.152, 0.785 } })
list(tabs, "V", 0.02)
local well = new("ImageLabel", page, "Content", { pos = { 0.176, 0.13 }, size = { 0.514, 0.785 }, sprite = "Well_Teal" })
local grid = scroller(well, "Grid", { pos = { 0.03, 0.035 }, size = { 0.94, 0.93 } })
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.fromScale(0.31, 0.5)
gl.CellPadding = UDim2.fromScale(0.025, 0.02)
gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
gl.SortOrder = Enum.SortOrder.LayoutOrder
aspect(gl, 0.8) -- cards are always 1:1.25
gl.Parent = grid
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0.012, 0)
pad.PaddingBottom = UDim.new(0.012, 0)
pad.Parent = grid
local rows = scroller(well, "List", { pos = { 0.03, 0.035 }, size = { 0.94, 0.93 }, visible = false })
list(rows, "V", 0.012, "Center")
text(well, "Empty", "NOTHING HERE YET", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.7, 0.06 }, font = F.typed,
	color = COL.cream, alignX = CENTER, transp = 0.2, visible = false })
local det = new("ImageLabel", page, "Detail", { pos = { 0.7, 0.13 }, size = { 0.286, 0.785 }, sprite = "Paper" })
local hero = new("ImageLabel", det, "Hero", { pos = { 0.11, 0.028 }, size = { 0.78, 0.44 }, aspect = 348 / 298,
	sprite = "Card_Common", crop = { 26, 20, 348, 298 } })
new("ImageLabel", hero, "Image", { pos = { 4 / 348, 4 / 298 }, size = { 340 / 348, 290 / 298 }, z = 2 })
new("ImageLabel", det, "Tag", { pos = { 0.135, 0.42 }, size = { 0.37, 0.0735 }, aspect = 166 / 50,
	sprite = "Card_Common", crop = { 39, 289, 166, 50 }, z = 3 })
text(det, "Name", "", { pos = { 0.07, 0.505 }, size = { 0.55, 0.062 }, font = F.title, color = COL.navy })
text(det, "Sub", "", { pos = { 0.55, 0.518 }, size = { 0.38, 0.032 }, font = F.typed, color = COL.ink, alignX = RIGHT })
local body = new("Frame", det, "Body", { pos = { 0.07, 0.58 }, size = { 0.86, 0.29 } })
list(body, "V", 0.03)

local tab = new("ImageButton", T, "Tab", { size = { 1, 0.12 }, aspect = 3.1, sprite = "Tab_Off", visible = false })
local tc = new("Frame", tab, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
new("ImageLabel", tc, "Icon", { pos = { 0.26, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.5 }, aspect = 1, dom = "H",
	sprite = "Icon_Grid", tint = COL.navy })
text(tc, "Label", "TAB", { pos = { 0.37, 0.28 }, size = { 0.56, 0.44 }, font = F.label, color = COL.navy })

local chip = new("ImageLabel", T, "Chip", { size = { 0.46, 1 }, sprite = "Chip_Navy", visible = false })
new("ImageLabel", chip, "Icon", { pos = { 0.05, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.95 }, aspect = 1, dom = "H",
	sprite = "Icon_Glowshard" })
text(chip, "Amount", "0", { pos = { 0.38, 0.17 }, size = { 0.52, 0.66 }, font = F.num, color = COL.cream })

local card = new("ImageButton", T, "Card", { sprite = "Card_Common", visible = false })
new("ImageLabel", card, "Portrait", { pos = { 0.075, 0.048 }, size = { 0.85, 0.58 }, z = 2 })
new("ImageLabel", card, "Tag", { pos = { 39 / 400, 289 / 500 }, size = { 166 / 400, 50 / 500 }, sprite = "Card_Common",
	crop = { 39, 289, 166, 50 }, z = 3 })
text(card, "Name", "NAME", { pos = { 0.075, 0.69 }, size = { 0.85, 0.08 }, font = F.title, color = COL.navy, z = 3 })
text(card, "Sub", "", { pos = { 0.075, 0.775 }, size = { 0.85, 0.05 }, font = F.body, color = COL.ink, z = 3 })
new("ImageLabel", card, "Lamp", { pos = { 0.13, 0.91 }, anchor = { 0.5, 0.5 }, size = { 0.085, 0.068 }, aspect = 1,
	sprite = "Lamp_Off", z = 3 })
local price = new("ImageLabel", card, "Price", { pos = { 0.925, 0.955 }, anchor = { 1, 1 }, size = { 0.44, 0.088 },
	sprite = "Chip_Cream", z = 3 })
new("ImageLabel", price, "Icon", { pos = { 0.07, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 1.1 }, aspect = 1, dom = "H",
	sprite = "Icon_Glowshard", z = 4 })
text(price, "Amount", "0", { pos = { 0.44, 0.15 }, size = { 0.46, 0.7 }, font = F.num, color = COL.navy, z = 4 })
new("ImageLabel", card, "Stamp", { pos = { 0.27, 0.115 }, anchor = { 0.5, 0.5 }, size = { 0.44, 0.22 }, aspect = 2,
	sprite = "Stamp_Owned", z = 5, visible = false })

local row = new("ImageButton", T, "Row", { size = { 1, 0.11 }, sprite = "Paper", visible = false })
new("ImageLabel", row, "Icon", { pos = { 0.025, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.66 }, aspect = 1, dom = "H",
	sprite = "Icon_Grid", tint = COL.navy, z = 2 })
text(row, "Name", "", { pos = { 0.13, 0.22 }, size = { 0.55, 0.56 }, font = F.label, color = COL.navy, z = 2 })
text(row, "Value", "", { pos = { 0.7, 0.22 }, size = { 0.26, 0.56 }, font = F.num, color = COL.navy, alignX = RIGHT, z = 2 })

local section = new("Frame", T, "Section", { size = { 1, 0.3 }, visible = false })
text(section, "Label", "LABEL", { pos = { 0, 0 }, size = { 1, 0.36 }, font = F.label, color = COL.teal })
text(section, "Body", "", { pos = { 0, 0.4 }, size = { 1, 0.6 }, font = F.body, color = COL.navy, wrap = true,
	alignY = Enum.TextYAlignment.Top })

local fb = button(T, "FooterButton", { size = { 0.48, 1 }, visible = false }, { "Button_Teal_Up", "Button_Teal_Down" })
text(fb.Content, "Label", "ACTION", { pos = { 0.08, 0.24 }, size = { 0.84, 0.52 }, font = F.label, color = COL.cream,
	alignX = CENTER })

sg.Parent = game:GetService("StarterGui")
return "Frame built: " .. #sg:GetDescendants() .. " instances"
