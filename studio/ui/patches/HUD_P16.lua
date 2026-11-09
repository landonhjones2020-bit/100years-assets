-- In-place patch for the HUD (Prompt 16): the backpack chip and the elevator's fade. Adds them and
-- changes nothing else, so an AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
for _, name in { "Backpack", "Fade" } do
	local old = sg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
--@include ../HUD_Surface.lua
return "HUD patched: Backpack, Fade (" .. #sg:GetDescendants() .. " instances in HUD)"
