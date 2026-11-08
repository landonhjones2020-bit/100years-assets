--!strict
--[[
	SurfaceLocations: places to search in Brightwater Ruins, the launch region (bible Section
	12). The map is the lobby's town after the bomb. Containers refill every era.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Loot = Check.ref("LootTables"),
		Containers = F.PositiveInt,
		MinEra = Check.integer(1, 4),
		Text = F.Short,
	}),
	Order = { "Diner", "HardwareStore", "Grocery", "GasStation", "Motel", "RadioTower", "WaterTower", "RailYard", "Showroom", "Checkpoint" },
	Entries = {
		Diner = { Name = "Main Street diner", Loot = "Diner", Containers = 4, MinEra = 1, Text = "Soda fountain, booths, a kitchen out back." },
		HardwareStore = { Name = "Hardware store", Loot = "HardwareStore", Containers = 5, MinEra = 1, Text = "Tools, lamps and spare parts." },
		Grocery = { Name = "Grocery", Loot = "Grocery", Containers = 5, MinEra = 1, Text = "Canned food and bottled water." },
		GasStation = { Name = "Gas station", Loot = "GasStation", Containers = 3, MinEra = 1, Text = "Scrap and flares." },
		Motel = { Name = "Motel", Loot = "Motel", Containers = 6, MinEra = 1, Text = "Rooms to search; sometimes a survivor." },
		RadioTower = { Name = "Radio tower", Loot = "RadioTower", Containers = 3, MinEra = 1, Text = "Radio logs and a view of the town." },
		WaterTower = { Name = "Water tower", Loot = "WaterTower", Containers = 2, MinEra = 1, Text = "Water, if you can reach it." },
		RailYard = { Name = "Rail yard", Loot = "RailYard", Containers = 6, MinEra = 1, Text = "A wrecked train full of salvage." },
		Showroom = { Name = "Steadfast showroom", Loot = "Showroom", Containers = 4, MinEra = 1, Text = "The ruined showroom: blueprints and the company's secrets." },
		Checkpoint = { Name = "Military checkpoint", Loot = "Checkpoint", Containers = 5, MinEra = 3, Text = "Opens in Era III: ammo and military gear." },
	},
}
