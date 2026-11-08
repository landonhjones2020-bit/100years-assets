-- In-place patch for the HUD (Prompt 8, with Landon's answers): Ready's key chip. Adds it and
-- changes nothing else, so an AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local ready = sg:WaitForChild("Ready")
local old = ready:FindFirstChild("Key")
if old then
	old:Destroy()
end
--@include ../HUD_ReadyKey.lua
return "HUD patched: Ready.Key (" .. #ready:GetDescendants() .. " instances in Ready)"
