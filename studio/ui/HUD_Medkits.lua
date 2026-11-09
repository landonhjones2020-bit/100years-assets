-- The HUD's Medkits pieces (Landon's answer to the Prompt 11 questions, 2026-11-08: the Heal
-- button uses a carried Medkit over 1.5 s). Included by HUD.lua and by patches/HUD_P11b.lua;
-- needs `sg` (the HUD).
--
-- * Medkits: a navy chip under the vitals panel: the Medkit icon, "x2", the Heal key (H, or UP
--   for a hold of the D-pad's up) and a fill along its foot while a Medkit is working.
-- * Touch.Heal: the touch cluster's Heal button, above the Melee button.

local med = new("ImageLabel", sg, "Medkits", { pos = { 0.008, 0.214 }, size = { 0.098, 0.058 }, aspect = 2.7, sprite = "Chip_Navy" })
new("ImageLabel", med, "Icon", { pos = { 0.06, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.84 }, aspect = 1, dom = "H",
	sprite = "Icon_Medkit", z = 2 })
text(med, "Count", "x0", { pos = { 0.38, 0.2 }, size = { 0.3, 0.6 }, font = F.num, color = COL.cream, z = 2 })
local mk = new("ImageLabel", med, "Key", { pos = { 0.84, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.6 }, aspect = 1.6, dom = "H",
	sprite = "Chip_Cream", z = 3 })
text(mk, "Text", "H", { pos = { 0.1, 0.15 }, size = { 0.8, 0.7 }, font = F.num, color = COL.navy, alignX = CENTER, z = 4 })
new("Frame", med, "Fill", { pos = { 0.06, 0.8 }, size = { 0, 0.1 }, bg = COL.leaf, z = 3, visible = false })

local touchCluster = sg:FindFirstChild("Touch")
if touchCluster then
	local hb = button(touchCluster, "Heal", { pos = { 0.6, 0.13 }, anchor = { 0.5, 0.5 }, size = { 1, 0.17 }, aspect = 1, dom = "H" },
		{ "Touch_Up", "Touch_Down" })
	new("ImageLabel", hb.Content, "Icon", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.56, 0.56 }, sprite = "Icon_Medkit" })
end
