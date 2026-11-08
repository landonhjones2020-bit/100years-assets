--!strict
--[[
	MoraleStates: what a resident's morale (0 to 100, starting at 60) does (bible Section 11).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		From = Check.integer(0, 100),
		To = Check.integer(0, 100),
		OutputMultiplier = F.NonNegative,
		Text = F.Short,
	}),
	Order = { "Miserable", "Unhappy", "Settled", "Happy", "Inspired" },
	Entries = {
		Miserable = { Name = "Miserable", From = 0, To = 19, OutputMultiplier = 0.85, Text = "May refuse work, start fights or leave the bunker for good" },
		Unhappy = { Name = "Unhappy", From = 20, To = 39, OutputMultiplier = 0.85, Text = "-15% output" },
		Settled = { Name = "Settled", From = 40, To = 74, OutputMultiplier = 1, Text = "Normal" },
		Happy = { Name = "Happy", From = 75, To = 89, OutputMultiplier = 1.1, Text = "+10% output" },
		Inspired = { Name = "Inspired", From = 90, To = 100, OutputMultiplier = 1.2, Text = "+20% output" },
	},
}
