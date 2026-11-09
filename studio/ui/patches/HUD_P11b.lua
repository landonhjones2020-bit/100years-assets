-- In-place patch for the HUD (Landon's answers to the Prompt 11 questions, 2026-11-08): the
-- Medkits chip and the touch Heal button. Adds them and changes nothing else, so an AutoScale
-- Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
for _, item in { sg:FindFirstChild("Medkits"), sg:FindFirstChild("Touch") and sg.Touch:FindFirstChild("Heal") } do
	if item then
		item:Destroy()
	end
end
--@include ../HUD_Medkits.lua
return "HUD patched: Medkits, Touch.Heal (" .. #sg:GetDescendants() .. " instances in HUD)"
