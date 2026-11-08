-- Part of The Frame, included by Frame.lua (a full build) and patches/Frame_P07.lua (a patch
-- that keeps the AutoScale Lite pass on everything else). Needs `sg`, the Frame ScreenGui.
-- The Command View's page (bible Section 7: the Frame in docked mode, the live bunker in
-- zone C), the red edge that flashes when the player is hit, and the view's templates.
local cabinet = sg:FindFirstChild("Cabinet")
local templates = sg:FindFirstChild("Templates")
for _, old in { cabinet.Pages:FindFirstChild("CommandView"), sg:FindFirstChild("DamageEdge"),
	templates:FindFirstChild("RoomLabel"), templates:FindFirstChild("CellMark"),
	templates:FindFirstChild("PingMark"), templates:FindFirstChild("OptionRow") } do
	if old then
		old:Destroy()
	end
end

local cv = new("Frame", cabinet.Pages, "CommandView", { pos = { 0, 0 }, size = { 1, 1 }, visible = false })
local cvTabs = new("Frame", cv, "Tabs", { pos = { 0.014, 0.13 }, size = { 0.152, 0.785 } })
list(cvTabs, "V", 0.02)
-- zone C: open, so the bunker shows through; marks and labels sit over it (clipped to the zone,
-- so a label at the edge doesn't spill over the tab rail)
local view = new("Frame", cv, "View", { pos = { 0.172, 0.122 }, size = { 0.52, 0.79 }, clip = true })
new("Frame", view, "Marks", { pos = { 0, 0 }, size = { 1, 1 }, z = 2 })
new("Frame", view, "Labels", { pos = { 0, 0 }, size = { 1, 1 }, z = 3 })
new("ImageLabel", view, "Cursor", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.08 }, aspect = 1, dom = "H",
	sprite = "Icon_Aim", tint = COL.hazard, z = 4, visible = false })
local help = new("ImageLabel", view, "Help", { pos = { 0.5, 0.975 }, anchor = { 0.5, 1 }, size = { 0.86, 0.055 },
	sprite = "Chip_Navy", z = 4 })
text(help, "Text", "", { pos = { 0.04, 0.2 }, size = { 0.92, 0.6 }, font = F.label, color = COL.cream, alignX = CENTER, z = 5 })
-- zone D: the selected cell, room or resident
local cvDet = new("ImageLabel", cv, "Detail", { pos = { 0.7, 0.13 }, size = { 0.286, 0.785 }, sprite = "Paper" })
text(cvDet, "Name", "", { pos = { 0.07, 0.035 }, size = { 0.86, 0.06 }, font = F.title, color = COL.navy })
text(cvDet, "Sub", "", { pos = { 0.07, 0.1 }, size = { 0.86, 0.032 }, font = F.typed, color = COL.ink })
local cvBody = scroller(cvDet, "Body", { pos = { 0.07, 0.15 }, size = { 0.86, 0.3 } })
cvBody.ScrollBarImageColor3 = COL.teal
list(cvBody, "V", 0.03)
local options = scroller(cvDet, "Options", { pos = { 0.05, 0.465 }, size = { 0.9, 0.39 } })
options.ScrollBarImageColor3 = COL.teal
list(options, "V", 0.02, "Center")

-- the red edge: four strips that fade toward the middle
local edge = new("Frame", sg, "DamageEdge", { pos = { 0, 0 }, size = { 1, 1 }, z = 10, visible = false })
for _, e in { { "Top", { 0, 0 }, { 1, 0.045 }, 90 }, { "Bottom", { 0, 0.955 }, { 1, 0.045 }, -90 },
	{ "Left", { 0, 0 }, { 0.03, 1 }, 0 }, { "Right", { 0.97, 0 }, { 0.03, 1 }, 180 } } do
	local strip = new("Frame", edge, e[1], { pos = e[2], size = e[3], bg = COL.rust, bgT = 0 })
	local g = Instance.new("UIGradient")
	g.Rotation = e[4]
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = strip
end

-- templates the Command View clones
local rl = new("ImageLabel", templates, "RoomLabel", { anchor = { 0.5, 0 }, size = { 0.16, 0.045 }, sprite = "Chip_Navy",
	visible = false })
text(rl, "Name", "", { pos = { 0.08, 0.16 }, size = { 0.72, 0.68 }, font = F.label, color = COL.cream, alignX = CENTER, z = 2 })
new("ImageLabel", rl, "Lamp", { pos = { 0.9, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.56 }, aspect = 1, dom = "H",
	sprite = "Lamp_Off", z = 2, visible = false })
local mark = new("Frame", templates, "CellMark", { bg = COL.signal, bgT = 0.82, visible = false })
stroke(mark, 3, COL.signal, 0)
text(mark, "Label", "", { pos = { 0.05, 0.06 }, size = { 0.9, 0.22 }, font = F.label, color = COL.cream, alignX = CENTER,
	z = 2, visible = false })
new("ImageLabel", templates, "PingMark", { anchor = { 0.5, 1 }, size = { 1, 0.08 }, aspect = 1, dom = "H",
	sprite = "Icon_Ping", tint = COL.hazard, z = 4, visible = false })
local row = new("ImageButton", templates, "OptionRow", { size = { 1, 0.17 }, sprite = "Paper", visible = false })
text(row, "Name", "", { pos = { 0.06, 0.12 }, size = { 0.78, 0.42 }, font = F.label, color = COL.navy, z = 2 })
text(row, "Value", "", { pos = { 0.06, 0.56 }, size = { 0.78, 0.32 }, font = F.typed, color = COL.ink, z = 2 })
new("ImageLabel", row, "Lamp", { pos = { 0.92, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.34 }, aspect = 1, dom = "H",
	sprite = "Lamp_Off", z = 2 })
