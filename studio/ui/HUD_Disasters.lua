-- The HUD's disaster pieces (Prompt 13, bible Section 10). Included by HUD.lua and by
-- patches/HUD_P13.lua; needs `sg` (the HUD) and `T` (its Templates folder).
--
-- * Meltdown: a telegram in the banner's place while the Reactor Core melts down (the banner
--   holds while it shows): REACTOR MELTDOWN, what to do, the three valves' lamps and the
--   countdown. DisasterController fills it in; it hides while the player is down.
-- * Templates.Valve: a plate over each valve in the Reactor Core during a meltdown: the
--   valve's number, its lamp (red open, green turned) and what it is doing, with a gauge that
--   runs down while a turned valve holds (alone or in two: 10 s).

local melt = new("ImageLabel", sg, "Meltdown", { pos = { 0.5, 0.29 }, anchor = { 0.5, 0 }, size = { 0.42, 0.12 }, aspect = 5.2,
	sprite = "Telegram", visible = false, z = 5 })
text(melt, "Title", "REACTOR MELTDOWN", { pos = { 0.05, 0.12 }, size = { 0.62, 0.3 }, font = F.title, color = COL.rust, z = 6 })
text(melt, "Text", "TURN ALL THREE VALVES IN THE REACTOR CORE AT ONCE", { pos = { 0.05, 0.44 }, size = { 0.64, 0.17 },
	font = F.typed, color = COL.navy, z = 6 })
local valves = new("Frame", melt, "Valves", { pos = { 0.05, 0.66 }, size = { 0.62, 0.22 }, z = 6 })
for i = 1, 3 do
	local v = new("Frame", valves, "Valve" .. i, { pos = { (i - 1) * 0.34, 0 }, size = { 0.31, 1 }, z = 6 })
	new("ImageLabel", v, "Lamp", { pos = { 0, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.95 }, aspect = 1, dom = "H",
		sprite = "Lamp_Red", z = 7 })
	text(v, "Label", "VALVE " .. i, { pos = { 0.3, 0.08 }, size = { 0.7, 0.84 }, font = F.label, color = COL.navy, z = 7 })
end
new("ImageLabel", melt, "Tally", { pos = { 0.845, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.21, 0.62 }, sprite = "Chip_Navy", z = 6 })
text(melt, "Count", "1:00", { pos = { 0.845, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.16, 0.44 }, font = F.num, color = COL.cream,
	alignX = CENTER, z = 7 })

-- A valve's plate in the world (sized in studs, always on top).
local valve = new("BillboardGui", T, "Valve", {})
valve.Size = UDim2.fromScale(3.6, 1.35)
valve.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
valve.AlwaysOnTop = true
valve.LightInfluence = 0
valve.MaxDistance = 80
valve.ResetOnSpawn = false
valve.Enabled = false
local vp = new("ImageLabel", valve, "Plate", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Plate_Cream" })
new("ImageLabel", vp, "Lamp", { pos = { 0.14, 0.45 }, anchor = { 0.5, 0.5 }, size = { 1, 0.56 }, aspect = 1, dom = "H",
	sprite = "Lamp_Red", z = 2 })
text(vp, "Label", "VALVE 1", { pos = { 0.27, 0.14 }, size = { 0.66, 0.4 }, font = F.title, color = COL.navy, z = 2 })
text(vp, "State", "OPEN", { pos = { 0.27, 0.54 }, size = { 0.66, 0.26 }, font = F.typed, color = COL.rust, z = 2 })
local vg = new("Frame", vp, "Gauge", { pos = { 0.27, 0.83 }, size = { 0.64, 0.07 }, bg = COL.navy, bgT = 0.2, z = 2 })
new("Frame", vg, "Fill", { pos = { 0, 0 }, size = { 0, 1 }, bg = COL.leaf, z = 3 })
