--!strict
--[[
	GlowshardRewards: what a run and the meta pay (bible Section 16). A Normal Century Victory
	pays about 50 before quests. Badges, quests and chests carry their own amounts.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Text = F.Short,
		Per = Check.enum({ "YearsSurvived", "BandReached", "Win", "Boss", "Run" }),
		Amount = F.NonNegative,
		Every = Check.optional(F.PositiveInt), -- e.g. 1 per 4 years
		Victory = Check.optional(Check.enum({ "Century", "Deep" })),
		Multiplier = Check.optional(F.NonNegative),
	}),
	Entries = {
		Years = { Text = "1 per 4 years survived (25 for a full century)", Per = "YearsSurvived", Amount = 1, Every = 4 },
		Bands = { Text = "3 per depth band reached (12 for the Source Chamber)", Per = "BandReached", Amount = 3 },
		CenturyVictory = { Text = "Century Victory", Per = "Win", Amount = 15, Victory = "Century" },
		DeepVictory = { Text = "Deep Victory", Per = "Win", Amount = 30, Victory = "Deep" },
		Bosses = { Text = "2 per boss killed", Per = "Boss", Amount = 2 },
		FirstWinOfDay = { Text = "First win of the day doubles that run's payout", Per = "Run", Amount = 0, Multiplier = 2 },
	},
}
