--!strict
--[[
	DepthBands: the Deep in bands of floors (bible Sections 6 and 12). Opening a band's first
	floor needs a Push Deeper vote. DigSeconds is per cell for a player with a Drill or Pickaxe.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Floors = Check.shape({ From = Check.integer(1, 10), To = Check.integer(1, 10) }),
		Look = F.Text,
		Ore = Check.optional(Check.ref("Resources")),
		DigSeconds = Check.optional(F.Seconds),
		CavePieces = F.Count,
		Monsters = Check.array(Check.ref("Monsters"), 8),
		Hazards = Check.array(Check.ref("Disasters"), 6),
		LostCrew = F.Flag,
		Buildable = Check.boolean(),
	}),
	Order = { "Mines", "FloodedCaverns", "CrystalHollows", "SourceChamber" },
	Entries = {
		Mines = {
			Name = "Mines",
			Floors = { From = 1, To = 3 },
			Look = "Timber props, lanterns, old carts",
			Ore = "Iron",
			DigSeconds = 20,
			CavePieces = 8,
			Monsters = { "BurrowTick", "TunnelHound", "HollowMiner", "SpitterGrub" },
			Hazards = { "GasLeak", "CaveIn" },
			LostCrew = true,
			Buildable = true,
		},
		FloodedCaverns = {
			Name = "Flooded Caverns",
			Floors = { From = 4, To = 6 },
			Look = "Dripping rock, standing water, burst pipes",
			Ore = "Copper",
			DigSeconds = 30,
			CavePieces = 8,
			Monsters = { "Murkling", "BloatToad", "Lurker", "TideCrab" },
			Hazards = { "Flood", "GasLeak", "CaveIn" },
			LostCrew = true,
			Buildable = true,
		},
		CrystalHollows = {
			Name = "Crystal Hollows",
			Floors = { From = 7, To = 9 },
			Look = "Glowing crystal, radiation",
			Ore = "Crystal",
			DigSeconds = 45,
			CavePieces = 8,
			Monsters = { "Shardling", "PrismStalker", "GeodeGolem", "Resonator" },
			Hazards = { "RadiationLeak", "CaveIn" },
			LostCrew = true,
			Buildable = true,
		},
		SourceChamber = {
			Name = "Source Chamber",
			Floors = { From = 10, To = 10 },
			Look = "A living cavern around the Source",
			DigSeconds = 45,
			CavePieces = 1,
			Monsters = {},
			Hazards = {},
			Buildable = false,
		},
	},
}
