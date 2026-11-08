--!strict
--[[
	Resources: the team's shared stockpile (bible Section 13). Power is a live balance, not a
	stock. Starting stock is bible Section 6; caps are provisional (each Storage cell raises
	every cap; the Quartermaster adds 25%).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "Live", "Stock" }),
		Start = F.Count,
		Cap = F.Count,
		CapPerStorageCell = F.Count,
		From = F.Text,
		SpentOn = F.Text,
	}),
	Order = { "Power", "Food", "Water", "Scrap", "Iron", "Copper", "Crystal", "Medkits", "Ammo" },
	Entries = {
		Power = {
			Name = "Power",
			Kind = "Live",
			Start = 0,
			Cap = 0,
			CapPerStorageCell = 0,
			From = "Reactor Core and Generators, as a live balance",
			SpentOn = "Every room, by level",
		},
		Food = {
			Name = "Food",
			Kind = "Stock",
			Start = 30,
			Cap = 100,
			CapPerStorageCell = 50,
			From = "Kitchen, Greenhouse, surface loot, expeditions",
			SpentOn = "1 per resident per cycle",
		},
		Water = {
			Name = "Water",
			Kind = "Stock",
			Start = 30,
			Cap = 100,
			CapPerStorageCell = 50,
			From = "Water Purifier, surface loot",
			SpentOn = "1 per resident per cycle",
		},
		Scrap = {
			Name = "Scrap",
			Kind = "Stock",
			Start = 300,
			Cap = 1000,
			CapPerStorageCell = 500,
			From = "Surface loot, monster drops, caches, expeditions, the trader",
			SpentOn = "Building, upgrades, repairs, crafting, the trader",
		},
		Iron = {
			Name = "Iron",
			Kind = "Stock",
			Start = 0,
			Cap = 100,
			CapPerStorageCell = 60,
			From = "Digging in the Mines, cave veins, the Drill Bay, Mines monsters",
			SpentOn = "Level 2 upgrades, crafting",
		},
		Copper = {
			Name = "Copper",
			Kind = "Stock",
			Start = 0,
			Cap = 60,
			CapPerStorageCell = 40,
			From = "Digging in the Flooded Caverns, cave veins, the Drill Bay, Flooded monsters",
			SpentOn = "Level 3 upgrades, crafting",
		},
		Crystal = {
			Name = "Crystal",
			Kind = "Stock",
			Start = 0,
			Cap = 40,
			CapPerStorageCell = 25,
			From = "Digging in the Crystal Hollows, cave veins, the Drill Bay, Crystal monsters",
			SpentOn = "Level 3 upgrades, crafting",
		},
		Medkits = {
			Name = "Medkits",
			Kind = "Stock",
			Start = 4,
			Cap = 20,
			CapPerStorageCell = 10,
			From = "Medbay, surface loot",
			SpentOn = "Healing players and residents",
		},
		Ammo = {
			Name = "Ammo",
			Kind = "Stock",
			Start = 200,
			Cap = 500,
			CapPerStorageCell = 250,
			From = "Armory, Workshop (from Scrap), surface loot",
			SpentOn = "Guns, for players and armed residents",
		},
	},
}
