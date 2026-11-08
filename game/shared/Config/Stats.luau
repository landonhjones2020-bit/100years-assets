--!strict
--[[
	Stats: the five resident stats (bible Section 11). 1 to 10 on arrival; gear and training
	can push a stat to 15. Which rooms use a stat is on each room (Rooms.WorkerStat).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({ Name = F.Name, AlsoAffects = F.Text }),
	Order = { "Strength", "Smarts", "Grit", "Speed", "Charm" },
	Entries = {
		Strength = { Name = "Strength", AlsoAffects = "Melee damage, building speed, carrying on expeditions" },
		Smarts = { Name = "Smarts", AlsoAffects = "Repair speed, crafting" },
		Grit = { Name = "Grit", AlsoAffects = "Max health, resisting radiation and gas" },
		Speed = { Name = "Speed", AlsoAffects = "Moving, fleeing, expedition length" },
		Charm = { Name = "Charm", AlsoAffects = "Roommates' morale, recruiting, trade prices" },
	},
}
