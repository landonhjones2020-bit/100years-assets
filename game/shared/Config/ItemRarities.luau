--!strict
--[[
	ItemRarities: weapon and gear rarities (bible Section 9: Rusty, Standard, Reinforced,
	Prototype, Legendary; higher rarity adds damage and one extra perk). Resident outfits give
	+1 to +3 by rarity (Section 11). Multipliers are provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Rank = Check.integer(1, 5),
		DamageMultiplier = F.NonNegative,
		Perks = Check.integer(0, 4),
		OutfitBonus = Check.integer(0, 3),
		Color = F.Hex,
	}),
	Order = { "Rusty", "Standard", "Reinforced", "Prototype", "Legendary" },
	Entries = {
		Rusty = { Name = "Rusty", Rank = 1, DamageMultiplier = 0.85, Perks = 0, OutfitBonus = 0, Color = "#8C5B3B" },
		Standard = { Name = "Standard", Rank = 2, DamageMultiplier = 1, Perks = 0, OutfitBonus = 1, Color = "#8E8C88" },
		Reinforced = { Name = "Reinforced", Rank = 3, DamageMultiplier = 1.15, Perks = 1, OutfitBonus = 2, Color = "#3F79B5" },
		Prototype = { Name = "Prototype", Rank = 4, DamageMultiplier = 1.3, Perks = 2, OutfitBonus = 3, Color = "#7D4C9E" },
		Legendary = { Name = "Legendary", Rank = 5, DamageMultiplier = 1.5, Perks = 3, OutfitBonus = 3, Color = "#D9A93A" },
	},
}
