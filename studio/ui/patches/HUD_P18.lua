-- In-place patch for the HUD (Prompt 18): the distress call plate template. Adds it and changes
-- nothing else, so an AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local T = sg:WaitForChild("Templates")
local old = T:FindFirstChild("Distress")
if old then
	old:Destroy()
end
--@include ../HUD_Expeditions.lua
return "HUD patched: Templates.Distress (" .. #sg:GetDescendants() .. " instances in HUD)"
