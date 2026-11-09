-- The run HUD (bible Section 18): fixed positions, separate from The Frame, built in the Run
-- place. Instruments, not bars: gauges, a flip counter, the cycle dial, the seismograph.
-- Every value starts empty or at rest; HUDController (and later MiniMapController,
-- VoteController, AlertController) fill them in. Templates are cloned by code.
local sg = screen("HUD", 1)

local function gauge(parent: Instance, name: string, face: string, pos: { number }, h: number, readout: boolean)
	local f = new("Frame", parent, name, { pos = pos, size = { 1, h }, aspect = 1, dom = "H" })
	new("ImageLabel", f, "Face", { pos = { 0, 0 }, size = { 1, 1 }, sprite = face })
	-- the needle points up at Rotation 0; the sweep runs from -135 (empty) to +135 (full)
	new("ImageLabel", f, "Needle", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Gauge_Needle", rot = 135, z = 2 })
	new("ImageLabel", f, "Glass", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Gauge_Glass", z = 3 })
	if readout then
		text(f, "Value", "", { pos = { 0.5, 0.8 }, anchor = { 0.5, 0.5 }, size = { 0.34, 0.1 }, font = F.num, color = COL.navy,
			alignX = CENTER, z = 4 })
	end
	return f
end

local function chipText(parent: Instance, name: string, pos: { number }, anchor: { number }?): ImageLabel
	local c = new("ImageLabel", parent, name, { pos = pos, anchor = anchor, size = { 0.06, 0.055 }, aspect = 1.94, sprite = "Chip_Navy" })
	text(c, "Text", "", { pos = { 0.12, 0.18 }, size = { 0.76, 0.64 }, font = F.num, color = COL.cream, alignX = CENTER })
	return c
end

-- Top left: health, stamina, radiation and the class ability
local vit = new("ImageLabel", sg, "Vitals", { pos = { 0.008, 0.012 }, size = { 0.255, 0.19 }, aspect = 2.39, sprite = "Panel_Navy" })
gauge(vit, "Health", "Gauge_Health", { 0.03, 0.07 }, 0.86, true)
gauge(vit, "Stamina", "Gauge_Stamina", { 0.405, 0.07 }, 0.43, false)
gauge(vit, "Radiation", "Gauge_Rad", { 0.405, 0.5 }, 0.43, false)
local ab = new("ImageButton", vit, "Ability", { pos = { 0.79, 0.05 }, anchor = { 0.5, 0 }, size = { 1, 0.66 }, aspect = 1, dom = "H",
	sprite = "Ability_Button" })
new("ImageLabel", ab, "Icon", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.5, 0.5 }, aspect = 1, sprite = "Icon_Shield", z = 2,
	visible = false })
new("Frame", ab, "Cooldown", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.76, 0.76 }, bg = COL.night, bgT = 0.35, z = 3,
	visible = false })
local key = new("ImageLabel", ab, "Key", { pos = { 0.92, 0.08 }, anchor = { 0.5, 0.5 }, size = { 0.34, 0.22 }, aspect = 1.6,
	sprite = "Chip_Cream", z = 4 })
text(key, "Text", "Q", { pos = { 0.2, 0.15 }, size = { 0.6, 0.7 }, font = F.num, color = COL.navy, alignX = CENTER, z = 5 })
text(vit, "AbilityName", "", { pos = { 0.79, 0.74 }, anchor = { 0.5, 0 }, size = { 0.36, 0.11 }, font = F.label, color = COL.cream,
	alignX = CENTER })
text(vit, "Class", "", { pos = { 0.79, 0.86 }, anchor = { 0.5, 0 }, size = { 0.36, 0.08 }, font = F.typed, color = COL.cream,
	alignX = CENTER, transp = 0.25 })

-- Top centre: the year flip counter and era (Ready beside it), the cycle dial with the phase and
-- the time left
local clock = new("ImageLabel", sg, "YearClock", { pos = { 0.5, 0.01 }, anchor = { 0.5, 0 }, size = { 0.2, 0.088 }, aspect = 4.04,
	sprite = "Panel_Navy" })
text(clock, "Label", "YEAR", { pos = { 0.06, 0.3 }, size = { 0.16, 0.4 }, font = F.label, color = COL.cream })
for i = 1, 3 do
	local tile = new("ImageLabel", clock, "Tile" .. i, { pos = { 0.235 + (i - 1) * 0.148, 0.12 }, size = { 1, 0.76 }, aspect = 0.75,
		dom = "H", sprite = "Flip_Tile" })
	text(tile, "Digit", "0", { pos = { 0.1, 0.06 }, size = { 0.8, 0.88 }, font = F.title, color = COL.cream, alignX = CENTER, z = 2 })
end
text(clock, "Era", "", { pos = { 0.705, 0.14 }, size = { 0.26, 0.4 }, font = F.title, color = COL.hazard })
text(clock, "EraName", "", { pos = { 0.705, 0.55 }, size = { 0.26, 0.28 }, font = F.label, color = COL.cream })
local dial = new("ImageLabel", sg, "CycleDial", { pos = { 0.5, 0.104 }, anchor = { 0.5, 0 }, size = { 0.3, 0.078 }, aspect = 768 / 112,
	sprite = "Dial_Cycle" })
new("ImageLabel", dial, "Pointer", { pos = { 0.023, 0.44 }, anchor = { 0.5, 0.5 }, size = { 1, 1.28 }, aspect = 48 / 128, dom = "H",
	sprite = "Dial_Pointer", z = 2 })
chipText(sg, "Phase", { 0.347, 0.111 }, { 1, 0 })
chipText(sg, "TimeLeft", { 0.653, 0.111 })
local ready = button(sg, "Ready", { pos = { 0.606, 0.022 }, size = { 0.08, 0.064 }, aspect = 2.1, visible = false },
	{ "Button_Teal_Up", "Button_Teal_Down" })
new("ImageLabel", ready.Content, "Lamp", { pos = { 0.16, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.36 }, aspect = 1, dom = "H",
	sprite = "Lamp_Off" })
text(ready.Content, "Label", "READY", { pos = { 0.28, 0.2 }, size = { 0.44, 0.42 }, font = F.label, color = COL.cream })
--@include HUD_ReadyKey.lua
text(ready.Content, "Count", "", { pos = { 0.28, 0.58 }, size = { 0.44, 0.24 }, font = F.num, color = COL.cream, transp = 0.2 })

-- Under the clock: the full-width banner. The vote telegram sits between them in its own
-- ScreenGui (studio/ui/Votes.lua), so it stays up while a Frame screen hides the HUD.
local banner = new("ImageLabel", sg, "Banner", { pos = { 0.5, 0.29 }, anchor = { 0.5, 0 }, size = { 0.62, 0.066 }, sprite = "Panel_Navy",
	visible = false, z = 5 })
new("ImageLabel", banner, "Icon", { pos = { 0.02, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.62 }, aspect = 1, dom = "H",
	sprite = "Alert_Warning", z = 6 })
text(banner, "Text", "", { pos = { 0.08, 0.2 }, size = { 0.84, 0.6 }, font = F.title, color = COL.hazard, alignX = CENTER, z = 6 })

-- Top right: the team stockpile, the Disturbance seismograph, the Command View button
local stock = new("ImageLabel", sg, "Stockpile", { pos = { 0.992, 0.012 }, anchor = { 1, 0 }, size = { 0.3, 0.13 }, aspect = 4.1,
	sprite = "Panel_Navy" })
local cells = new("Frame", stock, "Resources", { pos = { 0.04, 0.13 }, size = { 0.92, 0.74 } })
local rg = Instance.new("UIGridLayout")
rg.CellSize = UDim2.fromScale(0.235, 0.44)
rg.CellPadding = UDim2.fromScale(0.02, 0.12)
rg.FillDirectionMaxCells = 4
rg.SortOrder = Enum.SortOrder.LayoutOrder
rg.Parent = cells
local seis = new("ImageLabel", sg, "Disturbance", { pos = { 0.992, 0.152 }, anchor = { 1, 0 }, size = { 0.17, 0.101 }, aspect = 3,
	sprite = "Seismograph" })
local trace = new("Frame", seis, "Trace", { pos = { 0, 0 }, size = { 1, 1 }, z = 2 })
for i = 1, 46 do -- segments across the paper (x 0.05 to 0.86); Disturbance (Prompt 14) moves them
	local x = 0.05 + 0.81 * (i - 0.5) / 46
	new("Frame", trace, "S" .. i, { pos = { x, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.81 / 46 + 0.004, 0.022 }, bg = COL.navy })
end
text(sg, "DisturbanceLabel", "DISTURBANCE", { pos = { 0.818, 0.165 }, anchor = { 1, 0 }, size = { 0.07, 0.026 }, font = F.label,
	color = COL.cream, alignX = RIGHT })
text(sg, "DisturbanceLevel", "CALM", { pos = { 0.818, 0.193 }, anchor = { 1, 0 }, size = { 0.07, 0.03 }, font = F.title,
	color = COL.leaf, alignX = RIGHT })
local cmd = button(sg, "CommandView", { pos = { 0.992, 0.262 }, anchor = { 1, 0 }, size = { 0.17, 0.058 }, aspect = 5.2 },
	{ "Button_Teal_Up", "Button_Teal_Down" })
new("ImageLabel", cmd.Content, "Icon", { pos = { 0.07, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.62 }, aspect = 1, dom = "H",
	sprite = "Icon_Command" })
text(cmd.Content, "Label", "COMMAND VIEW", { pos = { 0.26, 0.25 }, size = { 0.56, 0.5 }, font = F.label, color = COL.cream })
text(cmd.Content, "Key", "TAB", { pos = { 0.83, 0.25 }, size = { 0.13, 0.5 }, font = F.num, color = COL.cream, alignX = CENTER,
	transp = 0.3 })

-- Left middle: the bunker in section on blueprint paper (MiniMapController draws the cells)
local map = new("ImageLabel", sg, "MiniMap", { pos = { 0.008, 0.33 }, size = { 0.14, 0.36 }, aspect = 0.69, sprite = "Panel_Navy" })
text(map, "Title", "BUNKER  ·  SIDE VIEW", { pos = { 0.08, 0.045 }, size = { 0.84, 0.05 }, font = F.label, color = COL.cream,
	alignX = CENTER })
local paper = new("ImageLabel", map, "Paper", { pos = { 0.07, 0.11 }, size = { 0.86, 0.77 }, sprite = "Grid_Blueprint" })
paper.ScaleType = Enum.ScaleType.Tile
paper.TileSize = UDim2.fromScale(0.2, 0.14)
new("Frame", paper, "Cells", { pos = { 0, 0 }, size = { 1, 1 }, z = 2 })
new("ImageLabel", paper, "You", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.07 }, aspect = 1, dom = "H",
	sprite = "Lamp_Orange", z = 4, visible = false })
text(map, "Depth", "", { pos = { 0.06, 0.9 }, size = { 0.88, 0.06 }, font = F.typed, color = COL.cream, alignX = CENTER })

-- Right middle: the alert feed (3 at most) and the screen-edge arrows (AlertController)
local alerts = new("Frame", sg, "Alerts", { pos = { 0.992, 0.335 }, anchor = { 1, 0 }, size = { 0.2, 0.22 } })
list(alerts, "V", 0.03, "Right")
new("Frame", sg, "Arrows", { pos = { 0, 0 }, size = { 1, 1 }, z = 6 })

-- Bottom centre: the hotbar
local bar = new("Frame", sg, "Hotbar", { pos = { 0.5, 0.985 }, anchor = { 0.5, 1 }, size = { 0.34, 0.1 }, aspect = 6.04 })
list(bar, "H", 0.02, "Center")
for i = 1, 5 do
	local s = new("ImageButton", bar, "Slot" .. i, { size = { 0.18, 1 }, aspect = 1, dom = "H", sprite = "Hotbar_Slot", order = i })
	text(s, "Key", tostring(i), { pos = { 0.266, 0.266 }, anchor = { 0.5, 0.5 }, size = { 0.2, 0.17 }, font = F.num, color = COL.navy,
		alignX = CENTER, z = 2 })
	new("ImageLabel", s, "Item", { pos = { 0.53, 0.55 }, anchor = { 0.5, 0.5 }, size = { 0.82, 0.82 }, z = 2, visible = false })
	text(s, "Ammo", "", { pos = { 0.9, 0.9 }, anchor = { 1, 1 }, size = { 0.6, 0.2 }, font = F.num, color = COL.cream, alignX = RIGHT,
		z = 3, visible = false })
end

-- Bottom right on touch: the action buttons. Bottom left stays clear for Roblox's thumbstick.
local touch = new("Frame", sg, "Touch", { pos = { 0.995, 0.985 }, anchor = { 1, 1 }, size = { 1, 0.46 }, aspect = 1.15, dom = "H",
	visible = false })
local TOUCH = { -- name, centre x, centre y (in the cluster), diameter (of its height), icon
	{ "Fire", 0.79, 0.72, 0.4, "Icon_Fire" },
	{ "Aim", 0.47, 0.62, 0.22, "Icon_Aim" },
	{ "Jump", 0.52, 0.875, 0.2, "Icon_Jump" },
	{ "Melee", 0.6, 0.38, 0.22, "Icon_Melee" },
	{ "Ability", 0.86, 0.29, 0.24, "Icon_Shield" },
	{ "Interact", 0.24, 0.8, 0.22, "Icon_Interact" },
	{ "Dodge", 0.25, 0.53, 0.2, "Icon_Dodge" },
	{ "Sprint", 0.08, 0.66, 0.18, "Icon_Sprint" },
	{ "Ping", 0.38, 0.3, 0.17, "Icon_Ping" },
	{ "Shoulder", 0.12, 0.36, 0.16, "Icon_Shoulder" },
}
for _, b in TOUCH do
	local fire = b[1] == "Fire"
	local up, down = if fire then "Touch_Fire_Up" else "Touch_Up", if fire then "Touch_Fire_Down" else "Touch_Down"
	local btn = button(touch, b[1], { pos = { b[2], b[3] }, anchor = { 0.5, 0.5 }, size = { 1, b[4] }, aspect = 1, dom = "H" }, { up, down })
	new("ImageLabel", btn.Content, "Icon", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.54, 0.54 }, sprite = b[5],
		tint = if fire then COL.navy else COL.cream })
end

-- Templates (cloned by code)
local T = folder(sg, "Templates")
local rc = new("ImageLabel", T, "ResourceChip", { sprite = "Chip_Cream", visible = false })
new("ImageLabel", rc, "Icon", { pos = { 0.04, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 1.12 }, aspect = 1, dom = "H", sprite = "Icon_Food",
	z = 2 })
text(rc, "Value", "", { pos = { 0.42, 0.17 }, size = { 0.4, 0.66 }, font = F.num, color = COL.navy, z = 2 })
new("ImageLabel", rc, "Lamp", { pos = { 0.86, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.62 }, aspect = 1, dom = "H", sprite = "Lamp_Off",
	z = 2, visible = false })
local slip = new("ImageLabel", T, "AlertSlip", { size = { 1, 0.3 }, aspect = 5.73, sprite = "Telegram", visible = false })
new("ImageLabel", slip, "Icon", { pos = { 0.04, 0.52 }, anchor = { 0, 0.5 }, size = { 1, 0.74 }, aspect = 1, dom = "H",
	sprite = "Alert_Danger", z = 2 })
text(slip, "Text", "", { pos = { 0.19, 0.33 }, size = { 0.76, 0.4 }, font = F.typed, color = COL.navy, z = 2 })
new("ImageLabel", T, "EdgeArrow", { anchor = { 0.5, 0.5 }, size = { 1, 0.06 }, aspect = 1, dom = "H", sprite = "Icon_Arrow",
	tint = COL.rust, visible = false })
local mc = new("Frame", T, "MapCell", { bg = COL.navy, bgT = 0.55, visible = false })
stroke(mc, 2, COL.cream, 0.15)
text(mc, "Label", "", { pos = { 0.06, 0.25 }, size = { 0.88, 0.5 }, font = F.label, color = COL.cream, alignX = CENTER, z = 2 })

--@include HUD_MapPing.lua
--@include HUD_Combat.lua

sg.Parent = game:GetService("StarterGui")
return "HUD built: " .. #sg:GetDescendants() .. " instances"
