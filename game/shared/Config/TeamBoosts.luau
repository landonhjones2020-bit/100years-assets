--!strict
--[[
	TeamBoosts: developer products bought during a run (bible Section 17). Every one helps the
	whole team and is announced with the buyer's name. Never a way around the team vote.
	ProductId is set in Prompt 28; prices provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Robux = F.PositiveInt,
		Text = F.Text,
		Banner = F.Short, -- "{player} called a Supply Drop!"
		Loot = Check.optional(Check.ref("LootTables")),
		ProductId = Check.optional(F.PositiveInt),
	}),
	Order = { "Revive", "RushConstruction", "BlueprintReroll", "StormShield", "SupplyDrop", "InstantRecruit", "EmergencyRepair" },
	Entries = {
		Revive = { Name = "Revive", Robux = 49, Text = "Brings a downed player back at once, yourself or a teammate.", Banner = "{player} revived {target}!" },
		RushConstruction = { Name = "Rush Construction", Robux = 49, Text = "Finishes every build in progress.", Banner = "{player} rushed construction!" },
		BlueprintReroll = { Name = "Blueprint Reroll", Robux = 49, Text = "Redraws the three draft cards.", Banner = "{player} rerolled the blueprints!" },
		StormShield = { Name = "Storm Shield", Robux = 79, Text = "Calms the surface storm during the next Surge.", Banner = "{player} raised a Storm Shield!" },
		SupplyDrop = {
			Name = "Supply Drop",
			Robux = 99,
			Text = "A crate of Food, Water, Ammo and Medkits at the Blast Door.",
			Banner = "{player} called a Supply Drop!",
			Loot = "SupplyDrop",
		},
		InstantRecruit = { Name = "Instant Recruit", Robux = 99, Text = "A Rare resident arrives now.", Banner = "{player} brought in a recruit!" },
		EmergencyRepair = {
			Name = "Emergency Repair",
			Robux = 149,
			Text = "Repairs every room and ends every fire and flood.",
			Banner = "{player} called an Emergency Repair!",
		},
	},
}
