-- A0 sample: the run HUD (bible Section 18) with sample values. Fixed positions, Scale-only,
-- instruments instead of bars: gauges, a flip counter, the cycle dial, the seismograph.
local sg = screen("A0_HUD")

local function gauge(parent: Instance, name: string, face: string, value: number, pos: { number }, h: number, readout: string?)
	local f = new("Frame", parent, name, { pos = pos, size = { 1, h }, aspect = 1, dom = "H" })
	new("ImageLabel", f, "Face", { pos = { 0, 0 }, size = { 1, 1 }, sprite = face })
	-- the needle points up at Rotation 0; the sweep runs from -135 (empty) to +135 (full)
	new("ImageLabel", f, "Needle", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Gauge_Needle", rot = -135 + 270 * value, z = 2 })
	new("ImageLabel", f, "Glass", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Gauge_Glass", z = 3 })
	if readout then
		text(f, "Value", readout, { pos = { 0.5, 0.8 }, anchor = { 0.5, 0.5 }, size = { 0.3, 0.1 }, font = F.num, color = COL.navy, alignX = CENTER, z = 4 })
	end
	f:SetAttribute("Value", value)
	return f
end

-- top left: health, stamina, radiation and the class ability
local vit = new("ImageLabel", sg, "Vitals", { pos = { 0.008, 0.012 }, size = { 0.255, 0.19 }, aspect = 2.39, sprite = "Panel_Navy" })
gauge(vit, "Health", "Gauge_Health", 0.72, { 0.03, 0.07 }, 0.86, "72")
gauge(vit, "Stamina", "Gauge_Stamina", 0.55, { 0.405, 0.07 }, 0.43)
gauge(vit, "Radiation", "Gauge_Rad", 0.12, { 0.405, 0.5 }, 0.43)
local ab = new("ImageButton", vit, "Ability", { pos = { 0.79, 0.05 }, anchor = { 0.5, 0 }, size = { 1, 0.66 }, aspect = 1, dom = "H", sprite = "Ability_Button" })
new("ImageLabel", ab, "Icon", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.5, 0.5 }, aspect = 1, sprite = "Icon_Shield", z = 2 })
local key = new("ImageLabel", ab, "Key", { pos = { 0.92, 0.08 }, anchor = { 0.5, 0.5 }, size = { 0.34, 0.22 }, aspect = 1.6, sprite = "Chip_Cream", z = 3 })
text(key, "Text", "Q", { pos = { 0.2, 0.15 }, size = { 0.6, 0.7 }, font = F.num, color = COL.navy, alignX = CENTER, z = 4 })
text(vit, "AbilityName", "HOLD THE LINE", { pos = { 0.79, 0.74 }, anchor = { 0.5, 0 }, size = { 0.36, 0.11 }, font = F.label, color = COL.cream, alignX = CENTER })
text(vit, "Class", "SECURITY  ·  LV 1", { pos = { 0.79, 0.86 }, anchor = { 0.5, 0 }, size = { 0.36, 0.08 }, font = F.typed, color = COL.cream, alignX = CENTER, transp = 0.25 })

-- top centre: the year flip counter and era, the cycle dial, the vote telegram
local clock = new("ImageLabel", sg, "YearClock", { pos = { 0.5, 0.01 }, anchor = { 0.5, 0 }, size = { 0.2, 0.088 }, aspect = 4.04, sprite = "Panel_Navy" })
text(clock, "Label", "YEAR", { pos = { 0.06, 0.3 }, size = { 0.16, 0.4 }, font = F.label, color = COL.cream })
for i, d in { "0", "1", "7" } do
	local tile = new("ImageLabel", clock, "Tile" .. i, { pos = { 0.235 + (i - 1) * 0.148, 0.12 }, size = { 1, 0.76 }, aspect = 0.75, dom = "H", sprite = "Flip_Tile" })
	text(tile, "Digit", d, { pos = { 0.1, 0.06 }, size = { 0.8, 0.88 }, font = F.title, color = COL.cream, alignX = CENTER, z = 2 })
end
text(clock, "Era", "ERA I", { pos = { 0.705, 0.14 }, size = { 0.26, 0.4 }, font = F.title, color = COL.hazard })
text(clock, "EraName", "SETTLING IN", { pos = { 0.705, 0.55 }, size = { 0.26, 0.28 }, font = F.label, color = COL.cream })
local dial = new("ImageLabel", sg, "CycleDial", { pos = { 0.5, 0.104 }, anchor = { 0.5, 0 }, size = { 0.3, 0.078 }, aspect = 768 / 112, sprite = "Dial_Cycle" })
-- 1:18 into the 3:00 day: the day scale covers 2/3 of the face (x 0.023 to 0.977)
new("ImageLabel", dial, "Pointer", { pos = { 0.023 + 0.954 * (2 / 3) * (78 / 180), 0.44 }, anchor = { 0.5, 0.5 }, size = { 1, 1.28 }, aspect = 48 / 128, dom = "H", sprite = "Dial_Pointer", z = 2 })
local tl = new("ImageLabel", sg, "TimeLeft", { pos = { 0.653, 0.111 }, size = { 0.06, 0.055 }, aspect = 1.94, sprite = "Chip_Navy" })
text(tl, "Text", "1:42", { pos = { 0.18, 0.18 }, size = { 0.64, 0.64 }, font = F.num, color = COL.cream, alignX = CENTER })
local vote = new("ImageLabel", sg, "VoteBanner", { pos = { 0.5, 0.19 }, anchor = { 0.5, 0 }, size = { 0.36, 0.088 }, aspect = 7.28, sprite = "Telegram" })
text(vote, "Proposal", "SAM PROPOSES:  BUILD MEDBAY  ·  120 SCRAP", { pos = { 0.045, 0.36 }, size = { 0.58, 0.26 }, font = F.typed, color = COL.navy })
text(vote, "Tally", "YES 2    NO 1    ·    0:11", { pos = { 0.045, 0.63 }, size = { 0.4, 0.2 }, font = F.num, color = COL.ink })
local function voteButton(name: string, label: string, x: number, up: string, down: string)
	local b = new("ImageButton", vote, name, { pos = { x, 0.22 }, size = { 0.15, 0.62 }, sprite = up, states = { up, down } })
	local c = new("Frame", b, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
	text(c, "Label", label, { pos = { 0.15, 0.22 }, size = { 0.7, 0.56 }, font = F.title, color = COL.cream, alignX = CENTER })
end
voteButton("Yes", "YES", 0.65, "Button_Leaf_Up", "Button_Leaf_Down")
voteButton("No", "NO", 0.815, "Button_Rust_Up", "Button_Rust_Down")

-- top right: the team stockpile, the Disturbance seismograph, the Command View button
local stock = new("ImageLabel", sg, "Stockpile", { pos = { 0.992, 0.012 }, anchor = { 1, 0 }, size = { 0.25, 0.13 }, aspect = 3.42, sprite = "Panel_Navy" })
local cells = new("Frame", stock, "Resources", { pos = { 0.05, 0.13 }, size = { 0.9, 0.74 } })
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.fromScale(0.315, 0.44)
gl.CellPadding = UDim2.fromScale(0.0275, 0.12)
gl.FillDirectionMaxCells = 3
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = cells
for i, r in { { "Power", "Icon_Power", "ON" }, { "Food", "Icon_Food", "42" }, { "Water", "Icon_Water", "38" },
	{ "Scrap", "Icon_Scrap", "260" }, { "Iron", "Icon_Iron", "14" }, { "Ammo", "Icon_Ammo", "120" } } do
	local c = new("ImageLabel", cells, r[1], { sprite = "Chip_Cream" })
	c.LayoutOrder = i
	new("ImageLabel", c, "Icon", { pos = { 0.04, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 1.12 }, aspect = 1, dom = "H", sprite = r[2], z = 2 })
	text(c, "Value", r[3], { pos = { 0.42, 0.17 }, size = { 0.38, 0.66 }, font = F.num, color = COL.navy, z = 2 })
	if r[1] == "Power" then
		new("ImageLabel", c, "Lamp", { pos = { 0.86, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.62 }, aspect = 1, dom = "H", sprite = "Lamp_Green", z = 2 })
	end
end
local seis = new("ImageLabel", sg, "Disturbance", { pos = { 0.992, 0.152 }, anchor = { 1, 0 }, size = { 0.17, 0.101 }, aspect = 3, sprite = "Seismograph" })
-- a sample trace, rising toward the pen (x 0.86); segments are measured in a 3:1 box
local rng = Random.new(7)
local pts = {}
for i = 0, 46 do
	local x = 0.05 + 0.81 * i / 46
	local amp = 0.04 + 0.26 * (i / 46) ^ 2.2
	table.insert(pts, { x, 0.5 + amp * (rng:NextNumber() * 2 - 1) })
end
for i = 1, #pts - 1 do
	local a, b = pts[i], pts[i + 1]
	local dx, dy = (b[1] - a[1]) * 3, (b[2] - a[2])
	local len = math.sqrt(dx * dx + dy * dy)
	local seg = new("Frame", seis, "Trace" .. i, { pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }, anchor = { 0.5, 0.5 },
		size = { len / 3 + 0.004, 0.022 }, bg = COL.navy, z = 2 })
	seg.Rotation = math.deg(math.atan2(dy, dx))
end
text(sg, "DisturbanceLabel", "DISTURBANCE", { pos = { 0.818, 0.165 }, anchor = { 1, 0 }, size = { 0.07, 0.026 }, font = F.label, color = COL.cream, alignX = RIGHT })
text(sg, "DisturbanceLevel", "RISING", { pos = { 0.818, 0.193 }, anchor = { 1, 0 }, size = { 0.07, 0.03 }, font = F.title, color = COL.hazard, alignX = RIGHT })
local cmd = new("ImageButton", sg, "CommandView", { pos = { 0.992, 0.262 }, anchor = { 1, 0 }, size = { 0.17, 0.058 }, aspect = 5.2,
	sprite = "Button_Teal_Up", states = { "Button_Teal_Up", "Button_Teal_Down" } })
local cc = new("Frame", cmd, "Content", { pos = { 0, 0 }, size = { 1, 1 } })
new("ImageLabel", cc, "Icon", { pos = { 0.07, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.62 }, aspect = 1, dom = "H", sprite = "Icon_Command" })
text(cc, "Label", "COMMAND VIEW", { pos = { 0.26, 0.25 }, size = { 0.56, 0.5 }, font = F.label, color = COL.cream })
text(cc, "Key", "C", { pos = { 0.84, 0.25 }, size = { 0.1, 0.5 }, font = F.num, color = COL.cream, alignX = CENTER, transp = 0.3 })

-- left middle: the bunker in section on blueprint paper, an alert cell lit
local map = new("ImageLabel", sg, "MiniMap", { pos = { 0.008, 0.33 }, size = { 0.14, 0.36 }, aspect = 0.69, sprite = "Panel_Navy" })
text(map, "Title", "BUNKER  ·  SIDE VIEW", { pos = { 0.08, 0.045 }, size = { 0.84, 0.05 }, font = F.label, color = COL.cream, alignX = CENTER })
local paper = new("ImageLabel", map, "Paper", { pos = { 0.07, 0.11 }, size = { 0.86, 0.82 }, sprite = "Grid_Blueprint" })
paper.ScaleType = Enum.ScaleType.Tile
paper.TileSize = UDim2.fromScale(0.2, 0.14)
local STROKE = 2 * VH / 1080
local function cell(name: string, x: number, y: number, w: number, h: number, label: string?, alert: boolean?)
	local f = new("Frame", paper, name, { pos = { x, y }, size = { w, h }, bg = alert and COL.rust or COL.navy, bgT = alert and 0.15 or 0.55, z = 2 })
	local s = Instance.new("UIStroke")
	s.Color = COL.cream
	s.Thickness = STROKE
	s.Transparency = 0.15
	s.Parent = f
	if label then
		text(f, "Label", label, { pos = { 0.08, 0.3 }, size = { 0.84, 0.4 }, font = F.label, color = COL.cream, alignX = CENTER, z = 3 })
	end
	return f
end
new("Frame", paper, "Surface", { pos = { 0.04, 0.1 }, size = { 0.92, 0.012 }, bg = COL.cream, bgT = 0.2, z = 2 })
cell("BlastDoor", 0.44, 0.03, 0.12, 0.07, nil)
cell("Shaft", 0.45, 0.12, 0.1, 0.72, nil)
local rooms = { { "KITCHEN", "MEDBAY" }, { "QUARTERS", "POWER" }, { "STORAGE", nil } }
for f, pair in rooms do
	local y = 0.13 + (f - 1) * 0.24
	cell("L" .. f, 0.06, y, 0.36, 0.2, pair[1], f == 1)
	if pair[2] then cell("R" .. f, 0.58, y, 0.36, 0.2, pair[2]) end
end
new("ImageLabel", paper, "AlertIcon", { pos = { 0.24, 0.135 }, anchor = { 0.5, 1 }, size = { 0.16, 0.1 }, aspect = 1, sprite = "Alert_Danger", z = 4 })
text(paper, "Mines", "MINES  ·  DEPTH 3", { pos = { 0.06, 0.88 }, size = { 0.88, 0.07 }, font = F.typed, color = COL.cream, alignX = CENTER, z = 2 })

-- right middle: the alert feed (shape and colour both carry meaning)
for i, a in { { "Alert_Danger", "FIRE  ·  KITCHEN, FLOOR 1" }, { "Alert_Warning", "BREACH  ·  MINES, DEPTH 3" } } do
	local slip = new("ImageLabel", sg, "Alert" .. i, { pos = { 0.992, 0.43 + (i - 1) * 0.07 }, anchor = { 1, 0 }, size = { 0.2, 0.062 }, aspect = 5.73, sprite = "Telegram" })
	new("ImageLabel", slip, "Icon", { pos = { 0.04, 0.52 }, anchor = { 0, 0.5 }, size = { 1, 0.74 }, aspect = 1, dom = "H", sprite = a[1], z = 2 })
	text(slip, "Text", a[2], { pos = { 0.19, 0.33 }, size = { 0.76, 0.4 }, font = F.typed, color = COL.navy, z = 2 })
end

-- bottom centre: the hotbar
local bar = new("Frame", sg, "Hotbar", { pos = { 0.5, 0.985 }, anchor = { 0.5, 1 }, size = { 0.34, 0.1 }, aspect = 6.04 })
local hl = Instance.new("UIListLayout")
hl.FillDirection = Enum.FillDirection.Horizontal
hl.HorizontalAlignment = Enum.HorizontalAlignment.Center
hl.Padding = UDim.new(0.02, 0)
hl.SortOrder = Enum.SortOrder.LayoutOrder
hl.Parent = bar
for i = 1, 5 do
	local s = new("ImageButton", bar, "Slot" .. i, { size = { 0.18, 1 }, aspect = 1, dom = "H", sprite = i == 1 and "Hotbar_Selected" or "Hotbar_Slot" })
	s.LayoutOrder = i
	text(s, "Key", tostring(i), { pos = { 0.266, 0.266 }, anchor = { 0.5, 0.5 }, size = { 0.2, 0.17 }, font = F.num, color = COL.navy, alignX = CENTER, z = 2 })
	if i == 1 then
		new("ImageLabel", s, "Item", { pos = { 0.53, 0.55 }, anchor = { 0.5, 0.5 }, size = { 0.82, 0.82 }, sprite = "Icon_ServiceRevolver", z = 2 })
		text(s, "Ammo", "6 / 24", { pos = { 0.9, 0.9 }, anchor = { 1, 1 }, size = { 0.6, 0.2 }, font = F.num, color = COL.cream, alignX = RIGHT, z = 3 })
	end
end

sg.Parent = game:GetService("StarterGui")
return "A0_HUD built: " .. #sg:GetDescendants() .. " instances"
