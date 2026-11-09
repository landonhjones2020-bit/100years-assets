-- In-place patch for The Frame (Prompt 9): the Command View's room labels get a reading chip
-- underneath for the Power and Production overlays. Adds it and changes nothing else, so an
-- AutoScale Lite pass on The Frame is kept.
local sg = game:GetService("StarterGui"):WaitForChild("Frame")
local rl = sg.Templates.RoomLabel
local old = rl:FindFirstChild("Reading")
if old then
	old:Destroy()
end
--@include ../Frame_RoomReading.lua
return "Frame patched: RoomLabel.Reading (" .. #rl:GetDescendants() .. " instances in RoomLabel)"
