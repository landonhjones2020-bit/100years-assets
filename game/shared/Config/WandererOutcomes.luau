--!strict
--[[
	WandererOutcomes: who is really knocking (bible Section 10). Every 2 to 3 cycles someone
	knocks and the team votes Let them in? The Warden, or a resident with Charm 7 or more, can
	inspect newcomers (Tuning.Wanderers). Odds provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({ Name = F.Name, Chance = F.Fraction, Text = F.Text }),
	Order = { "Survivor", "Raider", "Carrier" },
	Entries = {
		Survivor = { Name = "Survivor", Chance = 0.7, Text = "A real survivor who becomes a resident, sometimes a Rare one." },
		Raider = {
			Name = "Raider in disguise",
			Chance = 0.2,
			Text = "Later steals supplies or opens the door during a raid, unless unmasked first.",
		},
		Carrier = { Name = "Carrier", Chance = 0.1, Text = "Starts an Outbreak." },
	},
}
