-- The vote telegram (bible Section 8: "a slim banner under the year clock shows who proposed
-- what, the cost, the tally and a timer, with large yes and no buttons. It never blocks the
-- screen."), Run place. Its own ScreenGui above The Frame (DisplayOrder 6), so a vote can be
-- answered while the Command View or another Frame screen hides the HUD. VoteController fills it.
local sg = screen("Votes", 6)
local vote = new("ImageLabel", sg, "VoteBanner", { pos = { 0.5, 0.19 }, anchor = { 0.5, 0 }, size = { 0.36, 0.088 }, aspect = 7.28,
	sprite = "Telegram", visible = false })
text(vote, "Proposal", "", { pos = { 0.045, 0.36 }, size = { 0.58, 0.26 }, font = F.typed, color = COL.navy })
text(vote, "Tally", "", { pos = { 0.045, 0.63 }, size = { 0.58, 0.2 }, font = F.num, color = COL.ink })
-- the vote's time left: a strip along the telegram's foot that runs down
local voteTimer = new("Frame", vote, "Timer", { pos = { 0.045, 0.86 }, size = { 0.58, 0.05 }, bg = COL.navy, bgT = 0.8 })
new("Frame", voteTimer, "Fill", { pos = { 0, 0 }, size = { 1, 1 }, bg = COL.signal, bgT = 0 })
for _, v in { { "Yes", "YES", 0.65, "Button_Leaf_Up", "Button_Leaf_Down" }, { "No", "NO", 0.815, "Button_Rust_Up", "Button_Rust_Down" } } do
	local b = button(vote, v[1], { pos = { v[3], 0.22 }, size = { 0.15, 0.62 } }, { v[4], v[5] })
	text(b.Content, "Label", v[2], { pos = { 0.15, 0.22 }, size = { 0.7, 0.56 }, font = F.title, color = COL.cream, alignX = CENTER })
end
--@include Votes_Keys.lua
--@include Votes_Draft.lua

sg.Parent = game:GetService("StarterGui")
return "Votes built: " .. #sg:GetDescendants() .. " instances"
