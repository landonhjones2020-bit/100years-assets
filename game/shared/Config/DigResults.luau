--!strict
--[[
	DigResults: what a newly dug cell holds, rolled when it opens (bible Section 6). Chances
	are weights out of 100 (provisional). MinEra keeps cryo pods to Era II onward.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Chance = F.NonNegative,
		MinEra = Check.optional(Check.integer(1, 4)),
		Effect = F.Text,
		Loot = Check.optional(Check.ref("LootTables")),
	}),
	Order = { "Empty", "OrePocket", "CaveOpening", "HazardPocket", "Cache", "CryoPod", "Nest" },
	Entries = {
		Empty = { Name = "Empty", Chance = 60, Effect = "Ready to build on" },
		OrePocket = { Name = "Ore pocket", Chance = 20, Effect = "Bonus ore", Loot = "OrePocket" },
		CaveOpening = { Name = "Cave opening", Chance = 8, Effect = "Opens a 3D cave area" },
		HazardPocket = { Name = "Hazard pocket", Chance = 6, Effect = "Gas or water bursts out" },
		Cache = { Name = "Cache", Chance = 4, Effect = "Scrap, gear or a radio log", Loot = "Cache" },
		CryoPod = { Name = "Cryo pod", Chance = 1, MinEra = 2, Effect = "A frozen survivor" },
		Nest = { Name = "Nest", Chance = 1, Effect = "Monsters pour out at once; destroying it pays well", Loot = "Nest" },
	},
}
