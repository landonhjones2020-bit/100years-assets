--!strict
--[[
	Recipes: Workshop crafting (bible Section 13): weapon upgrades one rarity at a time (Scrap
	and ore), ammo (Scrap), throwables, tools, and the Engineer's turrets, barricades and traps.
	Residents working in the Workshop speed crafting and cut costs. Costs are provisional.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "Upgrade", "Ammo", "Throwable", "Tool", "Placeable", "Consumable" }),
		Costs = F.Costs,
		Seconds = F.Seconds,
		Gives = Check.optional(F.ItemStack),
		GivesResource = Check.optional(Check.shape({ Resource = Check.ref("Resources"), Count = F.PositiveInt })),
		ToRarity = Check.optional(Check.ref("ItemRarities")),
		EngineerOnly = F.Flag,
	}),
	Order = {
		"UpgradeStandard", "UpgradeReinforced", "UpgradePrototype", "UpgradeLegendary", "Ammo",
		"FragGrenade", "Flare", "FoamGrenade", "ShockMine", "Drill", "Welder", "Lamp", "Medkit",
		"Barricade", "Turret", "Trap",
	},
	Entries = {
		UpgradeStandard = { Name = "Upgrade to Standard", Kind = "Upgrade", ToRarity = "Standard", Costs = { Scrap = 60 }, Seconds = 15 },
		UpgradeReinforced = { Name = "Upgrade to Reinforced", Kind = "Upgrade", ToRarity = "Reinforced", Costs = { Scrap = 150, Iron = 15 }, Seconds = 25 },
		UpgradePrototype = { Name = "Upgrade to Prototype", Kind = "Upgrade", ToRarity = "Prototype", Costs = { Scrap = 300, Copper = 20 }, Seconds = 40 },
		UpgradeLegendary = { Name = "Upgrade to Legendary", Kind = "Upgrade", ToRarity = "Legendary", Costs = { Scrap = 500, Crystal = 20 }, Seconds = 60 },
		Ammo = { Name = "Ammo", Kind = "Ammo", Costs = { Scrap = 20 }, Seconds = 5, GivesResource = { Resource = "Ammo", Count = 30 } },
		FragGrenade = { Name = "Frag Grenade", Kind = "Throwable", Costs = { Scrap = 40, Iron = 2 }, Seconds = 8, Gives = { Item = "FragGrenade", Count = 1 } },
		Flare = { Name = "Flare", Kind = "Throwable", Costs = { Scrap = 15 }, Seconds = 4, Gives = { Item = "Flare", Count = 2 } },
		FoamGrenade = { Name = "Foam Grenade", Kind = "Throwable", Costs = { Scrap = 30 }, Seconds = 6, Gives = { Item = "FoamGrenade", Count = 1 } },
		ShockMine = { Name = "Shock Mine", Kind = "Throwable", Costs = { Scrap = 45, Copper = 2 }, Seconds = 8, Gives = { Item = "ShockMine", Count = 1 } },
		Drill = { Name = "Drill", Kind = "Tool", Costs = { Scrap = 120, Iron = 10 }, Seconds = 20, Gives = { Item = "Drill", Count = 1 } },
		Welder = { Name = "Welder", Kind = "Tool", Costs = { Scrap = 100, Iron = 8 }, Seconds = 20, Gives = { Item = "Welder", Count = 1 } },
		Lamp = { Name = "Lamp", Kind = "Placeable", Costs = { Scrap = 25 }, Seconds = 6, Gives = { Item = "Lamp", Count = 1 } },
		Medkit = { Name = "Medkit", Kind = "Consumable", Costs = { Scrap = 50 }, Seconds = 10, GivesResource = { Resource = "Medkits", Count = 1 } },
		Barricade = { Name = "Barricade", Kind = "Placeable", Costs = { Scrap = 80, Iron = 5 }, Seconds = 10, Gives = { Item = "Barricade", Count = 1 }, EngineerOnly = true },
		Turret = { Name = "Turret", Kind = "Placeable", Costs = { Scrap = 200, Iron = 15 }, Seconds = 30, Gives = { Item = "Turret", Count = 1 }, EngineerOnly = true },
		Trap = { Name = "Shock Trap", Kind = "Placeable", Costs = { Scrap = 60, Copper = 3 }, Seconds = 10, Gives = { Item = "ShockMine", Count = 2 }, EngineerOnly = true },
	},
}
