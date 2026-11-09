-- In-place patch for the Reticle (Prompt 11): the hit and kill markers. Adds them and changes
-- nothing else.
local sight = game:GetService("StarterGui"):WaitForChild("Reticle"):WaitForChild("Sight")
for _, name in { "Hit", "Kill" } do
	local old = sight:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
--@include ../Reticle_Hit.lua
return "Reticle patched: Sight.Hit, Sight.Kill"
