-- Part of the HUD, included by HUD.lua (a full build) and patches/HUD_P08.lua (in place).
-- Needs `ready`, the Ready button. Ready's own key (Landon, 2026-11-08): a cream chip on the
-- button's right, "Z" on PC, "DOWN" (the D-pad) on console; HUDController sets the text.
local readyKey = new("ImageLabel", ready, "Key", { pos = { 0.86, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.5 }, aspect = 1.6,
	dom = "H", sprite = "Chip_Cream", z = 4 })
text(readyKey, "Text", "Z", { pos = { 0.15, 0.15 }, size = { 0.7, 0.7 }, font = F.num, color = COL.navy, alignX = CENTER, z = 5 })
