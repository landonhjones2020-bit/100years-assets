-- The moment of a victory (bible Section 5: "Century Victory ... The blast door opens on a clearing
-- sky."; "Deep Victory: dig to depth 10 and destroy the Source in its chamber"; Prompt 25), Run
-- place. VictoryController drives it.
--
-- One ScreenGui over the HUD and under the results (no insets, so the bars reach every edge on a
-- notched phone): two letterbox bars, a wash that takes the picture to the Century's sky or the
-- Deep's dark, and the card: a navy Steadfast panel with the year, the victory's name and its
-- line typed out beneath a hazard rule.
local sg = screen("Victory", 19)
sg.ScreenInsets = Enum.ScreenInsets.None
sg.Enabled = false
new("Frame", sg, "Wash", { pos = { 0, 0 }, size = { 1, 1 }, bg = Color3.fromHex("#FFF6E4"), bgT = 1, z = 1 })
new("Frame", sg, "Top", { pos = { 0, 0 }, anchor = { 0, 1 }, size = { 1, 0.11 }, bg = Color3.new(0, 0, 0), bgT = 0, z = 2 })
new("Frame", sg, "Bottom", { pos = { 0, 1 }, anchor = { 0, 0 }, size = { 1, 0.11 }, bg = Color3.new(0, 0, 0), bgT = 0, z = 2 })
local card = new("ImageLabel", sg, "Card", { pos = { 0.5, 0.27 }, anchor = { 0.5, 0.5 }, size = { 0.44, 0.22 }, aspect = 3.7,
	sprite = "Panel_Navy", visible = false, z = 3 })
text(card, "Kicker", "YEAR 100 · THE BUNKER HELD", { pos = { 0.06, 0.1 }, size = { 0.88, 0.16 }, font = F.label, color = COL.hazard,
	alignX = CENTER, z = 4, max = 44 })
text(card, "Title", "CENTURY VICTORY", { pos = { 0.06, 0.26 }, size = { 0.88, 0.4 }, font = F.title, color = COL.cream,
	alignX = CENTER, z = 4, max = 160 })
local rule = new("Frame", card, "Rule", { pos = { 0.5, 0.69 }, anchor = { 0.5, 0.5 }, size = { 0.5, 0.012 }, bg = COL.hazard, z = 4 })
rule.BorderSizePixel = 0
text(card, "Line", "", { pos = { 0.06, 0.73 }, size = { 0.88, 0.17 }, font = F.typed, color = COL.cream, alignX = CENTER, z = 4, max = 80 })

sg.Parent = game:GetService("StarterGui")
return "Victory built: " .. #sg:GetDescendants() .. " instances"
