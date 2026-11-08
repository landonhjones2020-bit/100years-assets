--!strict
--[[
	Objectives: what makes more years pass per cycle (bible Sections 5 and 12). Each Lost Crew
	rescued adds 2 to Years per Cycle and brings 3 residents, one of them Rare; each era boss
	beaten adds 1 (the cap is in Tuning.Clock).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "LostCrew", "Boss" }),
		Where = Check.enum({ "Surface", "Mines", "FloodedCaverns", "CrystalHollows", "Era" }),
		Guard = Check.optional(F.Short),
		Boss = Check.optional(Check.ref("Bosses")),
		YearsPerCycle = F.Count,
		Residents = F.Count,
		RareResidents = F.Count,
		Text = F.Text,
	}),
	Order = { "CrewSurface", "CrewMines", "CrewFlooded", "CrewCrystal", "BossBroodMother", "BossDeluge", "BossColossus" },
	Entries = {
		CrewSurface = {
			Name = "Lost Crew: the surface",
			Kind = "LostCrew",
			Where = "Surface",
			Guard = "A raider camp",
			YearsPerCycle = 2, Residents = 3, RareResidents = 1,
			Text = "A trapped Steadfast work crew in Brightwater Ruins. Free them and escort them home.",
		},
		CrewMines = {
			Name = "Lost Crew: the Mines",
			Kind = "LostCrew",
			Where = "Mines",
			Guard = "A nest or a mini-boss",
			YearsPerCycle = 2, Residents = 3, RareResidents = 1,
			Text = "A trapped Steadfast work crew somewhere in the Mines.",
		},
		CrewFlooded = {
			Name = "Lost Crew: the Flooded Caverns",
			Kind = "LostCrew",
			Where = "FloodedCaverns",
			Guard = "A nest or a mini-boss",
			YearsPerCycle = 2, Residents = 3, RareResidents = 1,
			Text = "A trapped Steadfast work crew somewhere in the Flooded Caverns.",
		},
		CrewCrystal = {
			Name = "Lost Crew: the Crystal Hollows",
			Kind = "LostCrew",
			Where = "CrystalHollows",
			Guard = "A nest or a mini-boss",
			YearsPerCycle = 2, Residents = 3, RareResidents = 1,
			Text = "A trapped Steadfast work crew somewhere in the Crystal Hollows.",
		},
		BossBroodMother = { Name = "Beat the Brood Mother", Kind = "Boss", Where = "Era", Boss = "BroodMother", YearsPerCycle = 1, Residents = 0, RareResidents = 0, Text = "Year 25." },
		BossDeluge = { Name = "Beat The Deluge", Kind = "Boss", Where = "Era", Boss = "Deluge", YearsPerCycle = 1, Residents = 0, RareResidents = 0, Text = "Year 50." },
		BossColossus = { Name = "Beat the Crystal Colossus", Kind = "Boss", Where = "Era", Boss = "CrystalColossus", YearsPerCycle = 1, Residents = 0, RareResidents = 0, Text = "Year 75." },
	},
}
