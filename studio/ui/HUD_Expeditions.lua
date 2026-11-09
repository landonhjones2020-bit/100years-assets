-- The HUD's expedition pieces (Prompt 18, bible Section 12). Included by HUD.lua and by
-- patches/HUD_P18.lua; needs `sg` (the HUD) and `T` (its Templates folder).
--
-- * Templates.Distress: the plate over a distress call's marker in the world (ExpeditionsController):
--   a red lamp, DISTRESS CALL, the time left to reach them, who is pinned down and where. Sized in
--   pixels and always on top, so it reads from anywhere in the town or the caves.

local distress = new("BillboardGui", T, "Distress", {})
distress.Size = UDim2.fromOffset(260, 88)
distress.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
distress.AlwaysOnTop = true
distress.LightInfluence = 0
distress.MaxDistance = 100000
distress.ResetOnSpawn = false
distress.Enabled = false
local dp = new("ImageLabel", distress, "Plate", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Plate_Cream" })
new("ImageLabel", dp, "Lamp", { pos = { 0.1, 0.3 }, anchor = { 0.5, 0.5 }, size = { 1, 0.36 }, aspect = 1, dom = "H",
	sprite = "Lamp_Red", z = 2 })
text(dp, "Label", "DISTRESS CALL", { pos = { 0.19, 0.1 }, size = { 0.55, 0.32 }, font = F.title, color = COL.rust, z = 2 })
text(dp, "Count", "0:00", { pos = { 0.74, 0.1 }, size = { 0.2, 0.32 }, font = F.num, color = COL.navy, alignX = RIGHT, z = 2 })
text(dp, "Names", "WHO", { pos = { 0.07, 0.46 }, size = { 0.87, 0.22 }, font = F.label, color = COL.navy, z = 2 })
text(dp, "Where", "where", { pos = { 0.07, 0.7 }, size = { 0.87, 0.19 }, font = F.typed, color = COL.ink, z = 2 })
