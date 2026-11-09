-- The HUD's boss bar (Prompt 15, bible Sections 10 and 18). Included by HUD.lua and by
-- patches/HUD_P15.lua; needs `sg` (the HUD).
--
-- * BossBar: under the cycle bar while a boss fight is on: THE BROOD MOTHER on the left, the
--   phase (or BREAKING THROUGH, DEAD) on the right, and her health as a Rust Red bar with a Hazard
--   Yellow edge on a dark well. BossController fills it in.

local boss = new("ImageLabel", sg, "BossBar", { pos = { 0.5, 0.247 }, anchor = { 0.5, 0 }, size = { 0.38, 0.046 }, aspect = 12.5,
	sprite = "Panel_Navy", visible = false, z = 4 })
text(boss, "Name", "THE BROOD MOTHER", { pos = { 0.035, 0.1 }, size = { 0.55, 0.42 }, font = F.title, color = COL.hazard, z = 5 })
text(boss, "Phase", "PHASE 1 OF 2", { pos = { 0.6, 0.12 }, size = { 0.365, 0.38 }, font = F.label, color = COL.cream,
	alignX = RIGHT, z = 5 })
local well = new("Frame", boss, "Back", { pos = { 0.035, 0.6 }, size = { 0.93, 0.24 }, bg = COL.night, bgT = 0.05, z = 5 })
stroke(well, 1.5, COL.hazard, 0.25)
new("Frame", well, "Fill", { pos = { 0, 0 }, size = { 1, 1 }, bg = COL.rust, z = 6 })
