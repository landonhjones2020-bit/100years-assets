-- In-place patch for The Frame (Prompt 8): the Command View's cell marks get a navy outline on
-- their label, so a vote's ghost ("LEVEL 2?") reads over cream rooms and dark rock alike, and it
-- sits low in the cell, clear of the room's label chip.
-- Changes nothing else.
local sg = game:GetService("StarterGui"):WaitForChild("Frame")
local label = sg.Templates.CellMark.Label
label.TextStrokeColor3 = Color3.fromHex("#1B2A3A")
label.TextStrokeTransparency = 0.15
label.Position = UDim2.fromScale(0.05, 0.72) -- low in the cell: a room's own label chip hangs from the top
return "Frame patched: CellMark.Label outlined, low in the cell"
