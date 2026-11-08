--!strict
--[[
	Conditions on residents (bible Section 11). Amounts are provisional, for Prompts 10 and 26.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Text = F.Text,
		OutputMultiplier = Check.optional(F.NonNegative),
		HealthPerCycle = Check.optional(F.Number),
		MoraleNow = Check.optional(F.Number),
		Cycles = Check.optional(F.PositiveInt), -- how long it lasts on its own
		Contagious = F.Flag,
		StopsWork = F.Flag,
		Phase = Check.integer(1, 3), -- resident build phase (Section 11)
	}),
	Order = { "Injured", "Irradiated", "Panicked", "Inspired", "Sick", "Grieving", "Exhausted" },
	Entries = {
		Injured = { Name = "Injured", Text = "Works slowly until treated.", OutputMultiplier = 0.6, Phase = 2 },
		Irradiated = { Name = "Irradiated", Text = "Loses health until cleared.", HealthPerCycle = -10, Phase = 2 },
		Panicked = {
			Name = "Panicked",
			Text = "Flees danger and stops working. Brave and Cool Head residents never panic.",
			StopsWork = true,
			Phase = 2,
		},
		Inspired = { Name = "Inspired", Text = "Morale 90 or more: +20% output.", OutputMultiplier = 1.2, Phase = 2 },
		Sick = { Name = "Sick", Text = "Contagious until treated.", OutputMultiplier = 0.7, HealthPerCycle = -5, Contagious = true, Phase = 2 },
		Grieving = { Name = "Grieving", Text = "A friend died: -20 morale for 2 cycles.", MoraleNow = -20, Cycles = 2, Phase = 3 },
		Exhausted = { Name = "Exhausted", Text = "Rest at 0: works at half speed.", OutputMultiplier = 0.5, Phase = 1 },
	},
}
