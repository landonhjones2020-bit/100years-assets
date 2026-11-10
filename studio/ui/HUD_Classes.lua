-- The HUD's class ability pieces (Prompt 20, bible Section 14; Section 18: the class ability sits
-- top left with health, stamina and radiation). Included by HUD.lua and by patches/HUD_P20.lua;
-- needs `sg` (the HUD).
--
-- * Vitals.Ability.Wait: the seconds (or cycles) left, over the cooldown shade.
-- * Vitals.Ability.Uses: a navy chip at the button's foot: uses left ("1/2") or Steady Shot's shots.
-- * Vitals.Ability.Active: a glowing ring while the ability's effect is in play (Hold the Line, a
--   drone mode, Rally Call).
-- * Beacon: a chip under the vitals while a teammate's Teleport Beacon stands: its key (T, or a
--   hold of the D-pad's down) teleports you there; on touch the chip is the button.

local vit = sg:WaitForChild("Vitals")
local ab = vit:WaitForChild("Ability")
for _, name in { "Wait", "Uses", "Active" } do
	local old = ab:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
text(ab, "Wait", "", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.6, 0.34 }, font = F.num, color = COL.cream,
	alignX = CENTER, z = 4, visible = false })
local uses = new("ImageLabel", ab, "Uses", { pos = { 0.12, 0.9 }, anchor = { 0.5, 0.5 }, size = { 0.42, 0.24 }, aspect = 1.75,
	sprite = "Chip_Navy", z = 5, visible = false })
text(uses, "Text", "", { pos = { 0.1, 0.14 }, size = { 0.8, 0.72 }, font = F.num, color = COL.cream, alignX = CENTER, z = 6 })
local ring = new("Frame", ab, "Active", { pos = { 0.5, 0.5 }, anchor = { 0.5, 0.5 }, size = { 0.86, 0.86 }, z = 1, visible = false })
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = ring
stroke(ring, 3, COL.glow, 0)

local oldBeacon = sg:FindFirstChild("Beacon")
if oldBeacon then
	oldBeacon:Destroy()
end
local bc = new("ImageButton", sg, "Beacon", { pos = { 0.112, 0.214 }, size = { 0.122, 0.058 }, aspect = 3.4, sprite = "Chip_Navy",
	visible = false })
new("ImageLabel", bc, "Icon", { pos = { 0.05, 0.5 }, anchor = { 0, 0.5 }, size = { 1, 0.8 }, aspect = 1, dom = "H",
	sprite = "Icon_Ping", tint = COL.glow, z = 2 })
text(bc, "Text", "TELEPORT", { pos = { 0.3, 0.2 }, size = { 0.46, 0.6 }, font = F.label, color = COL.cream, z = 2 })
local bk = new("ImageLabel", bc, "Key", { pos = { 0.88, 0.5 }, anchor = { 0.5, 0.5 }, size = { 1, 0.6 }, aspect = 1.6, dom = "H",
	sprite = "Chip_Cream", z = 3 })
text(bk, "Text", "T", { pos = { 0.1, 0.15 }, size = { 0.8, 0.7 }, font = F.num, color = COL.navy, alignX = CENTER, z = 4 })
