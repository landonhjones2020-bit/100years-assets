-- The HUD's combat pieces (Prompt 11, bible Section 9). Included by HUD.lua and by
-- patches/HUD_P11.lua; needs `sg` (the HUD) and `T` (its Templates folder).
--
-- * Downed: a telegram across the upper middle while the player is down ("YOU'RE DOWN", how
--   long a teammate has to revive) or out ("YOU'RE OUT", the wait for the Medbay).
-- * Templates for world-space feedback, cloned by code (CombatController, PromptController):
--   the interaction prompt (an enamel plate with its key chip and a hold gauge: Section 18,
--   nothing generic), damage numbers and a monster's health bar.

local downed = new("ImageLabel", sg, "Downed", { pos = { 0.5, 0.37 }, anchor = { 0.5, 0.5 }, size = { 0.36, 0.13 }, aspect = 4.1,
	sprite = "Telegram", visible = false, z = 5 })
text(downed, "Title", "YOU'RE DOWN", { pos = { 0.07, 0.17 }, size = { 0.6, 0.34 }, font = F.title, color = COL.rust, z = 6 })
text(downed, "Text", "A TEAMMATE CAN REVIVE YOU. HOLD ON.", { pos = { 0.07, 0.55 }, size = { 0.6, 0.22 }, font = F.typed,
	color = COL.navy, z = 6 })
new("ImageLabel", downed, "Tally", { pos = { 0.83, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.24, 0.64 }, sprite = "Chip_Navy",
	z = 6 })
text(downed, "Count", "0:20", { pos = { 0.83, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.18, 0.44 }, font = F.num, color = COL.cream,
	alignX = CENTER, z = 7 })

-- The interaction prompt: a BillboardGui on the prompt's part (sized in studs, always on top).
local prompt = new("BillboardGui", T, "Prompt", {})
prompt.Size = UDim2.fromScale(5.6, 1.5)
prompt.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
prompt.AlwaysOnTop = true
prompt.LightInfluence = 0
prompt.ResetOnSpawn = false
prompt.Enabled = false
local plate = new("ImageButton", prompt, "Plate", { pos = { 0, 0 }, size = { 1, 1 }, sprite = "Plate_Cream" })
local key = new("ImageLabel", plate, "Key", { pos = { 0.12, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.17, 0.66 }, sprite = "Chip_Navy", z = 2 })
text(key, "Text", "E", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.7, 0.6 }, font = F.num, color = COL.cream, alignX = CENTER,
	z = 3 })
text(plate, "Action", "REVIVE", { pos = { 0.25, 0.14 }, size = { 0.7, 0.42 }, font = F.title, color = COL.navy, z = 2 })
text(plate, "Object", "Resident", { pos = { 0.25, 0.54 }, size = { 0.7, 0.28 }, font = F.typed, color = COL.ink, z = 2 })
local gauge = new("Frame", plate, "Gauge", { pos = { 0.25, 0.83 }, size = { 0.68, 0.07 }, bg = COL.navy, bgT = 0.2, z = 2 })
new("Frame", gauge, "Fill", { pos = { 0, 0 }, size = { 0, 1 }, bg = COL.signal, z = 3 })

-- A damage number: risen and faded by code.
local number = new("BillboardGui", T, "DamageNumber", {})
number.Size = UDim2.fromScale(3, 1.4)
number.AlwaysOnTop = true
number.LightInfluence = 0
number.Enabled = false
local value = text(number, "Value", "0", { pos = { 0, 0 }, size = { 1, 1 }, font = F.title, color = COL.cream, alignX = CENTER })
stroke(value, 2, COL.navy)

-- A monster's health bar: shown for a few seconds after a hit.
local bar = new("BillboardGui", T, "HealthBar", {})
bar.Size = UDim2.fromScale(4, 0.45)
bar.AlwaysOnTop = true
bar.LightInfluence = 0
bar.Enabled = false
local back = new("Frame", bar, "Back", { pos = { 0, 0 }, size = { 1, 1 }, bg = COL.navy, bgT = 0.1 })
stroke(back, 2, COL.cream, 0.1)
new("Frame", back, "Fill", { pos = { 0, 0 }, size = { 1, 1 }, bg = COL.rust })
