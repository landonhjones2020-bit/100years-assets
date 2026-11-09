-- In-place patch for the HUD (Prompt 15): the boss bar. Adds it and changes nothing else, so an
-- AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local old = sg:FindFirstChild("BossBar")
if old then
	old:Destroy()
end
--@include ../HUD_Boss.lua
return "HUD patched: BossBar (" .. #sg:GetDescendants() .. " instances in HUD)"
