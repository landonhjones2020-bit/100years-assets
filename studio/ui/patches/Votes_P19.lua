-- In-place patch for the vote telegram (Prompt 19): the blueprint draft's cards (Votes.Draft) and
-- the free reroll button (VoteBanner.Reroll). Adds them and changes nothing else, so an AutoScale
-- Lite pass on the telegram is kept.
local sg = game:GetService("StarterGui"):WaitForChild("Votes")
local vote = sg:WaitForChild("VoteBanner")
for _, old in { sg:FindFirstChild("Draft"), vote:FindFirstChild("Reroll") } do
	if old then
		old:Destroy()
	end
end
--@include ../Votes_Draft.lua
return "Votes patched: Draft (" .. #sg.Draft:GetDescendants() .. " instances), VoteBanner.Reroll"
