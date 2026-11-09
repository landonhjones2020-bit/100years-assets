-- In-place patch for the HUD (Prompt 11): the downed telegram and the combat templates
-- (interaction prompt, damage number, health bar). Adds them and changes nothing else, so an
-- AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local T = sg:WaitForChild("Templates")
for _, item in { sg:FindFirstChild("Downed"), T:FindFirstChild("Prompt"), T:FindFirstChild("DamageNumber"), T:FindFirstChild("HealthBar") } do
	if item then
		item:Destroy()
	end
end
--@include ../HUD_Combat.lua
return "HUD patched: Downed, Templates.Prompt, Templates.DamageNumber, Templates.HealthBar (" .. #sg:GetDescendants() .. " instances in HUD)"
