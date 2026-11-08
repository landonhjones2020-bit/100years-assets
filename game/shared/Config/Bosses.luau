--!strict
--[[
	Bosses: each era ends with one (bible Section 10). Beating one adds 1 to Years per Cycle
	(Tuning.Clock). Health and phases are provisional, for Prompts 15, 23, 24 and 25.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Year = Check.integer(1, 100),
		Arrives = F.Text,
		Fight = F.Text,
		Health = F.PositiveInt,
		Phases = Check.integer(1, 5),
		Minions = Check.optional(Check.array(Check.ref("Monsters"), 4)),
		Badge = Check.optional(Check.ref("Badges")),
		Asset = F.Asset,
	}),
	Order = { "BroodMother", "Deluge", "CrystalColossus", "Source" },
	Entries = {
		BroodMother = {
			Name = "Brood Mother",
			Year = 25,
			Arrives = "Bursts up through the deepest tunnel.",
			Fight = "Lays egg sacs that hatch Burrow Ticks; break or burn the sacs and hit her glowing belly.",
			Health = 6000,
			Phases = 2,
			Minions = { "BurrowTick" },
			Badge = "BeatBroodMother",
			Asset = "Boss_BroodMother",
		},
		Deluge = {
			Name = "The Deluge",
			Year = 50,
			Arrives = "A giant eel surging up the flooded tunnels.",
			Fight = "Floods every room it passes; strike its head when it surfaces and drain the rooms behind it.",
			Health = 12000,
			Phases = 3,
			Minions = { "Murkling" },
			Badge = "BeatDeluge",
			Asset = "Boss_Deluge",
		},
		CrystalColossus = {
			Name = "Crystal Colossus",
			Year = 75,
			Arrives = "Tears out of the crystal rock.",
			Fight = "Huge, slow and armoured; flares show its weak points; its shards stun.",
			Health = 20000,
			Phases = 3,
			Minions = { "Shardling" },
			Badge = "BeatCrystalColossus",
			Asset = "Boss_CrystalColossus",
		},
		Source = {
			Name = "The Source",
			Year = 100,
			Arrives = "Rises into the bunker, or is fought earlier in its chamber at depth 10.",
			Fight = "Several phases: tendrils in many rooms at once, then the core, so the team has to split up and regroup.",
			Health = 40000,
			Phases = 4,
			Badge = "BeatSource",
			Asset = "Boss_Source",
		},
	},
}
