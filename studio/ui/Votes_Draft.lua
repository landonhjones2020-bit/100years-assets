-- The blueprint draft (Prompt 19), part of the vote telegram's ScreenGui: included by Votes.lua
-- (a full build) and patches/Votes_P19.lua (in place). Needs `sg` (the Votes ScreenGui) and
-- `vote` (its VoteBanner). Landon (Prompt 19): "3 small catalog cards drop under the clock; tap
-- one to vote; you can still move and fight." While a draft is live the telegram names it and
-- runs its timer, and the cards hang below it: up to four (three drawn, and a found blueprint).
-- VoteController fills them and swaps each card's sprite to its kind (Draft_<Kind>).
local draft = new("Frame", sg, "Draft", { pos = { 0.5, 0.282 }, anchor = { 0.5, 0 }, size = { 0.6, 0.205 }, visible = false })
local row = new("Frame", draft, "Cards", { pos = { 0, 0 }, size = { 1, 1 } })
list(row, "H", 0.012, "Center", "Top")
for i = 1, 4 do
	local card = new("ImageButton", row, "Card" .. i, { size = { 0.2, 1 }, order = i, sprite = "Draft_Room",
		aspect = 400 / 440, dom = "H" })
	text(card, "Title", "CARD NAME", { pos = { 0.07, 0.585 }, size = { 0.86, 0.1 }, font = F.title, color = COL.navy,
		alignX = CENTER, max = 30 })
	text(card, "Text", "What the card does.", { pos = { 0.08, 0.705 }, size = { 0.84, 0.17 }, font = F.body,
		color = COL.ink, alignX = CENTER, alignY = Enum.TextYAlignment.Top, wrap = true, max = 22 })
	-- picks so far: a navy chip in the window's top right corner
	local chip = new("ImageLabel", card, "Votes", { pos = { 0.93, 0.06 }, anchor = { 1, 0 }, size = { 0.24, 0.1 },
		sprite = "Chip_Navy", z = 3 })
	text(chip, "Count", "0", { pos = { 0.12, 0.12 }, size = { 0.76, 0.76 }, font = F.num, color = COL.cream,
		alignX = CENTER, z = 4 })
	-- your pick: an orange frame round the card and a ribbon over the window
	local pick = new("Frame", card, "Pick", { pos = { 0, 0 }, size = { 1, 1 }, visible = false, z = 5 })
	stroke(pick, 5, COL.signal)
	local ribbon = new("Frame", pick, "Ribbon", { pos = { 0.5, 0.505 }, anchor = { 0.5, 0.5 }, size = { 0.62, 0.075 },
		bg = COL.signal, z = 6 })
	text(ribbon, "Label", "YOUR PICK", { pos = { 0.05, 0.1 }, size = { 0.9, 0.8 }, font = F.title, color = COL.cream,
		alignX = CENTER, z = 7 })
	-- the winner, once the draft closes
	local won = new("Frame", card, "Won", { pos = { 0, 0 }, size = { 1, 1 }, visible = false, z = 5 })
	stroke(won, 6, COL.glow)
	-- a found blueprint: the FOUND stamp across the window and the finder's name under the text
	new("ImageLabel", card, "Found", { pos = { 0.05, 0.16 }, size = { 0.54, 0.27 }, sprite = "Stamp_Found", rot = -10,
		visible = false, z = 4 })
	text(card, "FoundBy", "LANDON", { pos = { 0.06, 0.885 }, size = { 0.88, 0.075 }, font = F.typed, color = COL.rust,
		alignX = CENTER, visible = false })
end
-- the Mad Scientist's free reroll (level 3, one per era): where YES and NO are during other votes,
-- shown only to a player who has one
local reroll = button(vote, "Reroll", { pos = { 0.65, 0.22 }, size = { 0.315, 0.62 }, visible = false },
	{ "Button_Teal_Up", "Button_Teal_Down" })
text(reroll.Content, "Label", "REROLL · FREE", { pos = { 0.08, 0.22 }, size = { 0.84, 0.56 }, font = F.title,
	color = COL.cream, alignX = CENTER })
