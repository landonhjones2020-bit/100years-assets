-- In-place patch for the vote telegram (Prompt 9, with Landon's answers): the controller's key
-- chips on YES ("Y") and NO ("HOLD Y"). Adds them and changes nothing else, so an AutoScale Lite
-- pass on the telegram is kept.
local vote = game:GetService("StarterGui"):WaitForChild("Votes"):WaitForChild("VoteBanner")
for _, name in { "Yes", "No" } do
	local old = vote:WaitForChild(name):FindFirstChild("Key")
	if old then
		old:Destroy()
	end
end
--@include ../Votes_Keys.lua
return "Votes patched: Yes.Key, No.Key (" .. #vote:GetDescendants() .. " instances in VoteBanner)"
