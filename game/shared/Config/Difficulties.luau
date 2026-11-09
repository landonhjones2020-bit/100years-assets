--!strict
--[[
	Difficulties (bible Sections 5 and 16): Normal at first; Hard unlocks after a Century
	Victory, Nightmare after a Hard win. Threat and resource multipliers are provisional.
	UpgradesTakeTime: upgrades become construction sites instead of applying at once (Landon,
	Nov 8, 2026: "maybe construction time on the hardest mode").
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Unlock = F.Short,
		ThreatMultiplier = F.NonNegative,
		ResourceMultiplier = F.NonNegative,
		PayoutMultiplier = F.NonNegative,
		Badge = Check.optional(Check.ref("Badges")),
		UpgradesTakeTime = F.Flag,
	}),
	Order = { "Normal", "Hard", "Nightmare" },
	Entries = {
		Normal = { Name = "Normal", Unlock = "From the start", ThreatMultiplier = 1, ResourceMultiplier = 1, PayoutMultiplier = 1 },
		Hard = { Name = "Hard", Unlock = "After a Century Victory", ThreatMultiplier = 1.35, ResourceMultiplier = 0.8, PayoutMultiplier = 1.5, Badge = "HardVictory" },
		Nightmare = { Name = "Nightmare", Unlock = "After a Hard win", ThreatMultiplier = 1.75, ResourceMultiplier = 0.65, PayoutMultiplier = 2, Badge = "NightmareVictory", UpgradesTakeTime = true },
	},
}
