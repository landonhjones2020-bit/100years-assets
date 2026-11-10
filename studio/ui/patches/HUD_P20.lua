-- In-place patch for the HUD (Prompt 20): the class ability's wait, uses and active ring, and the
-- Teleport Beacon chip. Adds them and changes nothing else, so an AutoScale Lite pass on the HUD is kept.
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
--@include ../HUD_Classes.lua
return "HUD patched: Vitals.Ability.Wait/Uses/Active, Beacon (" .. #sg:GetDescendants() .. " instances in HUD)"
