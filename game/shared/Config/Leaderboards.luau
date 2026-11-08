--!strict
--[[
	Leaderboards on lobby billboards (bible Section 16), weekly and all-time.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Stat = Check.enum({ "DeepVictorySeconds", "EndlessYears", "ResidentsAtYear100" }),
		LowerIsBetter = F.Flag,
		Periods = Check.array(Check.enum({ "Weekly", "AllTime" }), 2),
	}),
	Order = { "FastestDeepVictory", "MostYearsEndless", "MostResidentsAtYear100" },
	Entries = {
		FastestDeepVictory = { Name = "Fastest Deep Victory", Stat = "DeepVictorySeconds", LowerIsBetter = true, Periods = { "Weekly", "AllTime" } },
		MostYearsEndless = { Name = "Most years in Endless", Stat = "EndlessYears", Periods = { "Weekly", "AllTime" } },
		MostResidentsAtYear100 = { Name = "Most residents alive at Year 100", Stat = "ResidentsAtYear100", Periods = { "Weekly", "AllTime" } },
	},
}
