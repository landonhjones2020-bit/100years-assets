-- The HUD's surface pieces (Prompt 16; SurfaceController). Included by HUD.lua and by
-- patches/HUD_P16.lua; needs `sg` (the HUD).
--
-- * Backpack: a navy chip under the Medkits chip: the backpack icon, "3/10" (slots used of the
--   pack's slots) and a fill along its foot as the pack fills.
-- * Fade: a black sheet over the whole screen, shown while the elevator moves the player (it
--   runs past the safe area so the top bar's strip goes dark too).

local pack = new("ImageLabel", sg, "Backpack", { pos = { 0.008, 0.278 }, size = { 0.098, 0.058 }, aspect = 2.7, sprite = "Chip_Navy" })
new("ImageLabel", pack, "Icon", { pos = { 0.06, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.84 }, aspect = 1, dom = "H",
	sprite = "Icon_Backpack", z = 2 })
text(pack, "Count", "0/10", { pos = { 0.4, 0.2 }, size = { 0.52, 0.6 }, font = F.num, color = COL.cream, z = 2 })
new("Frame", pack, "Fill", { pos = { 0.06, 0.8 }, size = { 0, 0.1 }, bg = COL.leaf, z = 3, visible = false })

new("Frame", sg, "Fade", { pos = { -0.05, -0.15 }, size = { 1.1, 1.3 }, bg = Color3.new(0, 0, 0), bgT = 1, z = 50, visible = false })
