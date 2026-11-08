--!strict
--[[
	Tiers: the rarity tiers of classes, residents, Legends and cosmetics (bible Sections 11,
	14, 15, 19). The colours are UI enamels (STYLE.md), never model swatches. Rarity shows in
	the look (Section 19): the Look line says how far a character's design goes.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Rank = Check.integer(0, 4),
		Color = Check.optional(F.Hex),
		Look = F.Text,
	}),
	Order = { "Free", "Common", "Rare", "Epic", "Legendary" },
	Entries = {
		Free = { Name = "Free", Rank = 0, Color = "#8E8C88", Look = "The Survivor: whatever they ran in with." },
		Common = { Name = "Common", Rank = 1, Color = "#8E8C88", Look = "A clean work outfit." },
		Rare = {
			Name = "Rare",
			Rank = 2,
			Color = "#3F79B5",
			Look = "Its own outfit, one signature piece (a hat, tool or pack) and an accent colour.",
		},
		Epic = {
			Name = "Epic",
			Rank = 3,
			Color = "#7D4C9E",
			Look = "A new silhouette (a coat, armour or harness), two or more signature pieces, brass or chrome detailing and a small effect.",
		},
		Legendary = {
			Name = "Legendary",
			Rank = 4,
			Color = "#D9A93A",
			Look = "One of a kind: a silhouette nothing else has, a hand-made head or hair, glowing or moving parts and its own idle.",
		},
	},
}
