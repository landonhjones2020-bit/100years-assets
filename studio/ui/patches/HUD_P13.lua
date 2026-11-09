-- In-place patch for the HUD (Prompt 13): the meltdown telegram and the valve plate template.
-- Adds them and changes nothing else, so an AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local T = sg:WaitForChild("Templates")
for _, item in { sg:FindFirstChild("Meltdown"), T:FindFirstChild("Valve") } do
	if item then
		item:Destroy()
	end
end
--@include ../HUD_Disasters.lua
return "HUD patched: Meltdown, Templates.Valve (" .. #sg:GetDescendants() .. " instances in HUD)"
