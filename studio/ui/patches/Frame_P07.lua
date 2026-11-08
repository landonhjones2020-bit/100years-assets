-- Patch for a Frame already in StarterGui (keeps the AutoScale Lite pass on everything else):
-- adds the Command View's page, the damage edge and the view's templates (Prompt 7).
local sg = game:GetService("StarterGui"):WaitForChild("Frame")
--@include ../Frame_CommandView.lua
return "Frame patched for the Command View: " .. #sg:GetDescendants() .. " instances"
