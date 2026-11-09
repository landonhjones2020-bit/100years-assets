-- Part of the vote telegram, included by Votes.lua (a full build) and patches/Votes_P09.lua (in
-- place). Needs `vote`, the VoteBanner. Votes on a controller (Landon, 2026-11-08): tap Y for
-- yes, hold Y for no. A cream key chip sits on top of each button; VoteController shows them
-- only while the player is on a gamepad.
for _, k in { { "Yes", "Y" }, { "No", "HOLD Y" } } do
	local b = vote:FindFirstChild(k[1])
	local chip = new("ImageLabel", b, "Key", { pos = { 0.5, 0.06 }, anchor = { 0.5, 1 }, size = { 0.86, 0.38 },
		sprite = "Chip_Cream", z = 6, visible = false })
	text(chip, "Text", k[2], { pos = { 0.1, 0.14 }, size = { 0.8, 0.72 }, font = F.num, color = COL.navy, alignX = CENTER, z = 7 })
end
