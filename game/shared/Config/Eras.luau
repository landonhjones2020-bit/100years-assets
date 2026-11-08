--!strict
--[[
	Eras: the century in quarters, each ended by a boss (bible Section 5). When the year
	counter passes an era's last year, the next Surge is that era's boss.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Number = Check.integer(1, 4),
		Name = F.Name,
		Years = Check.shape({ From = Check.integer(1, 100), To = Check.integer(1, 100) }),
		Band = Check.ref("DepthBands"),
		NewMonsters = Check.array(Check.ref("Monsters"), 8),
		NewDisasters = Check.array(Check.ref("Disasters"), 8),
		Raids = F.Flag,
		Boss = Check.ref("Bosses"),
		Text = F.Short,
	}),
	Order = { "SettlingIn", "Expansion", "Upheaval", "Reckoning" },
	Entries = {
		SettlingIn = {
			Number = 1,
			Name = "Settling In",
			Years = { From = 1, To = 25 },
			Band = "Mines",
			NewMonsters = { "BurrowTick", "TunnelHound", "HollowMiner", "SpitterGrub" },
			NewDisasters = { "Fire", "Blackout", "CaveIn" },
			Boss = "BroodMother",
			Text = "Mines, depth 1 to 3",
		},
		Expansion = {
			Number = 2,
			Name = "Expansion",
			Years = { From = 26, To = 50 },
			Band = "FloodedCaverns",
			NewMonsters = { "Murkling", "BloatToad", "Lurker", "TideCrab", "AshRaider" },
			NewDisasters = { "Flood", "GasLeak" },
			Raids = true,
			Boss = "Deluge",
			Text = "Flooded Caverns, depth 4 to 6; raids on the blast door",
		},
		Upheaval = {
			Number = 3,
			Name = "Upheaval",
			Years = { From = 51, To = 75 },
			Band = "CrystalHollows",
			NewMonsters = { "Shardling", "PrismStalker", "GeodeGolem", "Resonator" },
			NewDisasters = { "RadiationLeak", "Outbreak" },
			Raids = true,
			Boss = "CrystalColossus",
			Text = "Crystal Hollows, depth 7 to 9",
		},
		Reckoning = {
			Number = 4,
			Name = "Reckoning",
			Years = { From = 76, To = 100 },
			Band = "SourceChamber",
			NewMonsters = {},
			NewDisasters = {},
			Raids = true,
			Boss = "Source",
			Text = "Source Chamber, depth 10: everything before, stronger",
		},
	},
}
