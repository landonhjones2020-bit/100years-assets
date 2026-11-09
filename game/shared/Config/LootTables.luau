--!strict
--[[
	LootTables: what containers, caches, nests, monsters, expeditions and crates give (bible
	Sections 6, 10, 12, 13, 17). Each roll picks one line by Weight and gives Min..Max of it.
	A line gives a Resource, an Item, or a Special: BandOre (the ore of the band it's in), Gear
	(a random weapon or outfit, rarity rolled), Blueprint (a draft card), RadioLog, Glowshards,
	Recruit. Every number is provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local Line = Check.shape({
	Resource = Check.optional(Check.ref("Resources")),
	Item = Check.optional(Check.ref("Items")),
	Special = Check.optional(Check.enum({ "BandOre", "Gear", "Blueprint", "RadioLog", "Glowshards", "Recruit" })),
	Min = F.Count,
	Max = F.Count,
	Weight = F.NonNegative,
})

local function r(resource: string, min: number, max: number, weight: number)
	return { Resource = resource, Min = min, Max = max, Weight = weight }
end
local function i(item: string, min: number, max: number, weight: number)
	return { Item = item, Min = min, Max = max, Weight = weight }
end
local function s(special: string, min: number, max: number, weight: number)
	return { Special = special, Min = min, Max = max, Weight = weight }
end

return {
	Schema = Check.shape({
		Text = F.Short,
		Rolls = F.PositiveInt,
		Lines = Check.array(Line, 16),
	}),
	Entries = {
		-- Digging and the Deep
		OrePocket = { Text = "A dug cell with an ore pocket", Rolls = 1, Lines = { s("BandOre", 8, 15, 1) } },
		Cache = {
			Text = "A cache in a dug cell or a cave",
			Rolls = 2,
			Lines = { r("Scrap", 40, 90, 5), s("Gear", 1, 1, 2), s("RadioLog", 1, 1, 2), r("Ammo", 20, 40, 2), r("Medkits", 1, 2, 1),
				i("FragGrenade", 1, 2, 1), i("Flare", 1, 2, 1) }, -- throwables found exploring (Landon, 2026-11-08)
		},
		Nest = {
			Text = "A destroyed nest",
			Rolls = 2,
			Lines = { r("Scrap", 80, 150, 3), s("BandOre", 10, 20, 3) },
		},
		GlowshardChest = { Text = "A Glowshard chest in the Deep (rare)", Rolls = 1, Lines = { s("Glowshards", 1, 3, 1) } },

		-- Monster drops
		MinesMonster = { Text = "A Mines monster", Rolls = 1, Lines = { r("Scrap", 2, 6, 6), r("Iron", 1, 3, 3), r("Ammo", 2, 6, 1) } },
		FloodedMonster = { Text = "A Flooded Caverns monster", Rolls = 1, Lines = { r("Scrap", 3, 8, 6), r("Copper", 1, 3, 3), r("Ammo", 3, 8, 1) } },
		CrystalMonster = { Text = "A Crystal Hollows monster", Rolls = 1, Lines = { r("Scrap", 4, 10, 6), r("Crystal", 1, 2, 3), r("Ammo", 4, 10, 1) } },
		SurfaceMonster = { Text = "A surface creature", Rolls = 1, Lines = { r("Scrap", 2, 5, 6), r("Food", 1, 2, 2) } },
		Raider = { Text = "A beaten Ash Raider", Rolls = 1, Lines = { r("Scrap", 5, 12, 5), r("Ammo", 5, 15, 4), s("Gear", 1, 1, 1) } },

		-- Surface containers (refill every era)
		Diner = { Text = "Main Street diner", Rolls = 2, Lines = { r("Food", 3, 8, 6), r("Water", 2, 6, 4), r("Scrap", 5, 15, 2) } },
		HardwareStore = {
			Text = "Hardware store",
			Rolls = 2,
			Lines = { r("Scrap", 15, 40, 6), s("Gear", 1, 1, 2), i("Lamp", 1, 1, 1), s("Blueprint", 1, 1, 1), i("FoamGrenade", 1, 2, 1) },
		},
		Grocery = { Text = "Grocery", Rolls = 2, Lines = { r("Food", 5, 12, 6), r("Water", 4, 10, 4) } },
		GasStation = { Text = "Gas station", Rolls = 2, Lines = { r("Scrap", 10, 25, 5), r("Water", 2, 6, 3), i("Flare", 1, 2, 2) } },
		Motel = { Text = "Motel", Rolls = 2, Lines = { r("Medkits", 1, 2, 3), r("Food", 2, 6, 3), s("RadioLog", 1, 1, 1), r("Scrap", 5, 15, 3) } },
		RadioTower = { Text = "Radio tower", Rolls = 2, Lines = { s("RadioLog", 1, 1, 3), r("Scrap", 10, 25, 4), s("Blueprint", 1, 1, 1) } },
		WaterTower = { Text = "Water tower", Rolls = 2, Lines = { r("Water", 8, 16, 7), r("Scrap", 5, 10, 2) } },
		RailYard = { Text = "Rail yard and wrecked train", Rolls = 3, Lines = { r("Scrap", 20, 50, 6), s("Gear", 1, 1, 2), r("Iron", 3, 8, 2) } },
		Showroom = {
			Text = "The ruined Steadfast showroom",
			Rolls = 3,
			Lines = { s("Blueprint", 1, 1, 3), s("RadioLog", 1, 1, 3), s("Gear", 1, 1, 2), r("Scrap", 15, 35, 3) },
		},
		Checkpoint = {
			Text = "Military checkpoint (Era III)",
			Rolls = 3,
			Lines = { r("Ammo", 30, 70, 5), s("Gear", 1, 1, 4), r("Medkits", 2, 4, 3), i("FragGrenade", 1, 2, 2), i("ShockMine", 1, 1, 1) },
		},

		-- Expeditions (per cycle away)
		ExpeditionSurface = {
			Text = "A resident expedition to the surface, per cycle",
			Rolls = 2,
			Lines = { r("Scrap", 20, 50, 6), r("Food", 3, 8, 3), r("Water", 3, 8, 3), s("Gear", 1, 1, 1), s("Blueprint", 1, 1, 1), s("Recruit", 1, 1, 1) },
		},
		ExpeditionDeep = {
			Text = "A resident expedition into the Deep, per cycle",
			Rolls = 2,
			Lines = { r("Scrap", 15, 40, 4), s("BandOre", 5, 12, 5), s("Gear", 1, 1, 1), s("Recruit", 1, 1, 1) },
		},

		-- Crates
		SupplyDrop = {
			Text = "Supply Drop team boost: Food, Water, Ammo and Medkits at the Blast Door",
			Rolls = 4,
			Lines = { r("Food", 20, 20, 1), r("Water", 20, 20, 1), r("Ammo", 100, 100, 1), r("Medkits", 3, 3, 1) },
		},
		SupplyCall = {
			Text = "The Radio Operator's Supply Call crate",
			Rolls = 3,
			Lines = { r("Food", 10, 15, 2), r("Water", 10, 15, 2), r("Ammo", 50, 80, 2), r("Medkits", 2, 3, 1), r("Scrap", 60, 100, 2) },
		},
	},
}
