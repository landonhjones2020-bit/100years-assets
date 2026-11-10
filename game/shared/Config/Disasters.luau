--!strict
--[[
	Disasters: one comes with every Surge (bible Section 10). Numbers are provisional, for
	Prompts 13, 23 and 24. BestClass names the class built to stop it. SurgeWeight: how often a
	Surge picks it as its one disaster (Section 10's "Caused by": only Surges' own disasters have
	one); a Surge picks among the weighted disasters of its era and before that its budget can
	pay for (ThreatCost). The rule numbers of each disaster are Tuning.Disasters.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

return {
	Schema = Check.shape({
		Name = F.Name,
		CausedBy = F.Short,
		Effect = F.Text,
		Fix = F.Text,
		BestClass = Check.ref("Classes"),
		Era = Check.integer(1, 4),
		ThreatCost = F.PositiveInt,
		RoomDamagePerSecond = Check.optional(F.NonNegative),
		SpreadSeconds = Check.optional(F.Seconds),
		TimerSeconds = Check.optional(F.Seconds),
		DurationSeconds = Check.optional(F.Seconds),
		SurgeWeight = Check.optional(F.NonNegative),
	}),
	Order = { "Fire", "Flood", "Blackout", "CaveIn", "GasLeak", "ReactorOverload", "RadiationLeak", "Outbreak", "ElectricalSurge" },
	Entries = {
		Fire = {
			Name = "Fire",
			CausedBy = "Surges, Reactor overload, Clumsy residents, electrical surges",
			Effect = "Spreads to the next room every 15 seconds, burning room HP and residents.",
			Fix = "Extinguisher, Foam Grenade, residents in the room.",
			BestClass = "Firefighter",
			Era = 1, ThreatCost = 10, RoomDamagePerSecond = 6, SpreadSeconds = 15, SurgeWeight = 1,
		},
		Flood = {
			Name = "Flood",
			CausedBy = "Flooded Caverns hazards, Bloat Toads, The Deluge, Surges", -- Surges: Landon, Prompt 13
			Effect = "Water rises in a room and pours down the Shaft.",
			Fix = "Patch the burst pipe, then the room drains.",
			BestClass = "Firefighter",
			Era = 2, ThreatCost = 10, RoomDamagePerSecond = 3, SpreadSeconds = 20, SurgeWeight = 1, -- Surges start it from Prompt 23
		},
		Blackout = {
			Name = "Blackout",
			CausedBy = "Surges, electrical surges",
			Effect = "A floor or the whole grid goes dark.",
			Fix = "Reset the fuse box in the Reactor Core.",
			BestClass = "Engineer",
			Era = 1, ThreatCost = 8, DurationSeconds = 60, SurgeWeight = 1,
		},
		CaveIn = {
			Name = "Cave-in",
			CausedBy = "Digging, Tremors, Surges", -- Surges: Landon, Prompt 13 (from Era I)
			Effect = "Rubble blocks a doorway or cell and can trap residents.",
			Fix = "Dig or smash through the rubble.",
			BestClass = "Driller",
			Era = 1, ThreatCost = 8, SurgeWeight = 1,
		},
		GasLeak = {
			Name = "Gas leak",
			CausedBy = "Hazard pockets in the Mines, Surges", -- Surges: Landon, Prompt 13
			Effect = "Poison gas fills a room, hurting everyone inside.",
			Fix = "Seal the vent or air the room out.",
			BestClass = "HazmatTech",
			Era = 2, ThreatCost = 10, DurationSeconds = 90, SurgeWeight = 1, -- Surges start it from Prompt 23
		},
		ReactorOverload = {
			Name = "Reactor overload",
			CausedBy = "A Reactor Core at 0 HP, or an overclocked one",
			Effect = "A 60-second meltdown timer.",
			Fix = "Three valves turned at the same time, so it takes teamwork; with 1 or 2 players each turned valve stays turned for 10 seconds.",
			BestClass = "Engineer",
			Era = 1, ThreatCost = 14, TimerSeconds = 60,
		},
		RadiationLeak = {
			Name = "Radiation leak",
			CausedBy = "Surface storms against a weak Blast Door",
			Effect = "Floor 1 fills with radiation.",
			Fix = "Seal or upgrade the door; Decon Room.",
			BestClass = "HazmatTech",
			Era = 3, ThreatCost = 12, DurationSeconds = 120,
		},
		Outbreak = {
			Name = "Outbreak",
			CausedBy = "Wanderers, the Deep",
			Effect = "A sickness spreads between residents.",
			Fix = "Medbay treatment and quarantine in Quarters.",
			BestClass = "Medic",
			Era = 3, ThreatCost = 12,
		},
		ElectricalSurge = {
			Name = "Electrical surge",
			CausedBy = "Random, more often in Era III",
			Effect = "Sparks damage the machines in one room.",
			Fix = "Repair with the Welder.",
			BestClass = "Engineer",
			Era = 1, ThreatCost = 6, RoomDamagePerSecond = 10, DurationSeconds = 20,
		},
	},
}
