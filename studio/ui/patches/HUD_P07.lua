-- Patch for a HUD already in StarterGui: the mini-map's ping marker template (Prompt 7).
local sg = game:GetService("StarterGui"):WaitForChild("HUD")
local old = sg.Templates:FindFirstChild("MapPing")
if old then
	old:Destroy()
end
--@include ../HUD_MapPing.lua
return "HUD patched: " .. #sg:GetDescendants() .. " instances"
