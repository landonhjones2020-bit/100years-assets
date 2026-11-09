-- Part of the Command View, included by Frame_CommandView.lua (a full build) and
-- patches/Frame_P09.lua (in place). Needs `rl`, the RoomLabel template. Under each room's label
-- chip hangs a cream reading chip for the overlay that is on (Prompt 9): "+8 FOOD" on
-- Production, "DRAWS 2" or "MAKES 24" on Power, "DARK", "NO CREW". Hidden when there's nothing to read.
local reading = new("ImageLabel", rl, "Reading", { pos = { 0.5, 0.96 }, anchor = { 0.5, 0 }, size = { 0.82, 0.78 },
	sprite = "Chip_Cream", z = 2, visible = false })
text(reading, "Text", "", { pos = { 0.08, 0.14 }, size = { 0.84, 0.72 }, font = F.num, color = COL.navy, alignX = CENTER, z = 3 })
