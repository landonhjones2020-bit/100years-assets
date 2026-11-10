--!strict
--[[
	Classes: 18 buyable classes plus the free Survivor (bible Section 14). Each is a row of data
	so new ones ship without code. Kit is the starting gear; Passive, Ability, Level2 and
	Level3 carry the text players read and the modifiers systems apply (Config.Modifiers).
	Talents reuse another class's Passive; TalentExclude lists the keys that can't be
	borrowed (the Warden's tie-break), and Talentable = false shuts a passive out entirely
	(the Tinkerer's drone). Numbers the bible leaves open are marked "provisional" in Notes.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local Ability = Check.shape({
	Name = F.Name,
	Text = F.Text,
	CooldownSeconds = Check.optional(F.Seconds),
	CooldownCycles = Check.optional(F.PositiveInt),
	DurationSeconds = Check.optional(F.Seconds),
	Uses = Check.optional(Check.shape({ Per = Check.enum({ "Surge", "Cycle", "Era" }), Count = F.PositiveInt })),
	Options = Check.optional(Check.array(F.Name, 4)),
	Modifiers = Check.optional(F.Modifiers),
})

local function mod(key: string, value: number, extra: { [string]: any }?): { [string]: any }
	local t: { [string]: any } = { Key = key, Value = value }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

return {
	Schema = Check.shape({
		Name = F.Name,
		Tier = Check.ref("Tiers"),
		Price = F.Count, -- Glowshards
		Kit = F.ItemStacks,
		Companion = Check.optional(F.Name),
		Passive = F.Effect,
		Ability = Ability,
		Level2 = Check.optional(F.Effect),
		Level3 = Check.optional(F.Effect),
		Talentable = Check.boolean(),
		TalentExclude = Check.optional(Check.array(Check.ref("Modifiers"), 4)),
		Notes = Check.optional(F.Short),
	}),
	Order = {
		"Survivor", "Engineer", "Medic", "Firefighter", "Cook", "Security", "Scout",
		"Quartermaster", "RadioOperator", "HazmatTech", "Exterminator", "Marksman", "Driller", "Scavenger",
		"Warden", "Demolitionist", "Spelunker", "MadScientist", "Tinkerer",
	},
	Entries = {
		Survivor = {
			Name = "Survivor", Tier = "Free", Price = 0,
			Kit = { { Item = "Wrench" }, { Item = "PocketPistol" } },
			Passive = { Text = "None." },
			Ability = { Name = "Second Wind", Text = "Heal 25%, once per Surge.", Uses = { Per = "Surge", Count = 1 } },
			Talentable = false,
		},
		Engineer = {
			Name = "Engineer", Tier = "Common", Price = 40,
			Kit = { { Item = "Welder" }, { Item = "RivetSMG" }, { Item = "Wrench" } },
			Passive = { Text = "Repairs twice as fast.", Modifiers = { mod("RepairSpeed", 2) } },
			Ability = { Name = "Deploy Turret", Text = "An auto-turret for 45 s.", CooldownSeconds = 90, DurationSeconds = 45 },
			Level2 = { Text = "Barricades cost half.", Modifiers = { mod("BarricadeCost", 0.5) } },
			Level3 = { Text = "Turrets last twice as long and shock.", Modifiers = { mod("TurretDuration", 2), mod("TurretShock", 1) } },
			Talentable = true,
		},
		Medic = {
			Name = "Medic", Tier = "Common", Price = 40,
			Kit = { { Item = "Medkit", Count = 5 }, { Item = "PocketPistol" }, { Item = "DefibPaddles" } },
			Passive = { Text = "Revives in 1 s; heals residents by touch.", Modifiers = { mod("ReviveSeconds", 1), mod("TouchHeal", 1) } },
			Ability = { Name = "Triage Pulse", Text = "Heals 40 to everyone nearby.", CooldownSeconds = 60 },
			Level2 = { Text = "Medbay +25%.", Modifiers = { mod("RoomOutput", 1.25, { Room = "Medbay" }) } },
			Level3 = { Text = "Pulse also clears conditions.", Modifiers = { mod("TriagePulseClears", 1) } },
			Talentable = true,
		},
		Firefighter = {
			Name = "Firefighter", Tier = "Common", Price = 40,
			Kit = { { Item = "Extinguisher" }, { Item = "FireAxe" } },
			Passive = {
				Text = "Fire and flood damage -75%; puts out fires 3x faster.",
				Modifiers = { mod("FireFloodDamageTaken", 0.25), mod("ExtinguishSpeed", 3) },
			},
			Ability = { Name = "Foam Burst", Text = "Ends a room's fire or flood at once.", CooldownSeconds = 75 },
			Level2 = { Text = "Fire spreads 50% slower everywhere.", Modifiers = { mod("FireSpread", 0.5, { Scope = "Bunker" }) } },
			Level3 = { Text = "Fire Axe clears rubble instantly.", Modifiers = { mod("RubbleClearInstant", 1) } },
			Talentable = true,
		},
		Cook = {
			Name = "Cook", Tier = "Common", Price = 40,
			Kit = { { Item = "LeadPipe" }, { Item = "PocketPistol" } },
			Passive = {
				Text = "Kitchen +25% while you are in it.",
				Modifiers = { mod("RoomOutput", 1.25, { Room = "Kitchen", Scope = "Presence" }) },
			},
			Ability = {
				Name = "Hearty Meal",
				Text = "Team +20% max health and stamina for one cycle, residents +15 morale.",
				CooldownCycles = 2,
				Modifiers = { mod("MaxHealthMult", 1.2, { Scope = "Team" }), mod("StaminaMult", 1.2), mod("MoraleNow", 15) },
			},
			Level2 = { Text = "Meals also heal.", Modifiers = { mod("MealsHeal", 1) } },
			Level3 = { Text = "Bunker food use -20%.", Modifiers = { mod("FoodUse", 0.8, { Scope = "Bunker" }) } },
			Talentable = true,
		},
		Security = {
			Name = "Security", Tier = "Common", Price = 40,
			Kit = { { Item = "ShockBaton" }, { Item = "ServiceRevolver" } },
			Passive = {
				Text = "+30 health; residents near you deal +25% damage.",
				Modifiers = { mod("MaxHealth", 30), mod("NearbyResidentDamage", 1.25) },
			},
			Ability = { Name = "Hold the Line", Text = "Draws monsters to you and halves damage taken for 8 s.", CooldownSeconds = 45, DurationSeconds = 8 },
			Level2 = { Text = "Blast Door +20% health.", Modifiers = { mod("BlastDoorHealth", 1.2) } },
			Level3 = { Text = "Armed residents answer your rally at once.", Modifiers = { mod("InstantRally", 1) } },
			Talentable = true,
		},
		Scout = {
			Name = "Scout", Tier = "Common", Price = 40,
			Kit = { { Item = "LeverRifle" }, { Item = "LeadPipe" } },
			Passive = {
				Text = "+20% speed on the surface; hears the storm siren 20 s early; loot is outlined.",
				Modifiers = { mod("SurfaceMoveSpeed", 1.2), mod("StormWarningSeconds", 20), mod("LootOutline", 1) },
			},
			Ability = { Name = "Flare Ping", Text = "Shows enemies, loot and survivors within 60 studs for 10 s.", CooldownSeconds = 40, DurationSeconds = 10 },
			Level2 = { Text = "Backpack +5.", Modifiers = { mod("BackpackSlots", 5) } },
			Level3 = { Text = "Radiation builds 50% slower.", Modifiers = { mod("RadiationGain", 0.5) } },
			Talentable = true,
		},
		Quartermaster = {
			Name = "Quartermaster", Tier = "Rare", Price = 120,
			Kit = { { Item = "PumpShotgun" }, { Item = "Wrench" } },
			Passive = {
				Text = "Stockpile caps +25%; build costs -10%.",
				Modifiers = { mod("StockpileCaps", 1.25), mod("BuildCost", 0.9) },
			},
			Ability = {
				Name = "Emergency Requisition",
				Text = "+100 Scrap or +10 Food and Water now.",
				Uses = { Per = "Cycle", Count = 1 },
				Options = { "Scrap", "Food and Water" },
			},
			Level2 = { Text = "Trader prices -20%.", Modifiers = { mod("TraderPrices", 0.8) } },
			Level3 = { Text = "Build costs -20%.", Modifiers = { mod("BuildCost", 0.8) } },
			Talentable = true,
			Notes = "Level 3's -20% replaces the passive's -10% (bible question)",
		},
		RadioOperator = {
			Name = "Radio Operator", Tier = "Rare", Price = 120,
			Kit = { { Item = "PocketPistol" }, { Item = "RadioHeadset" }, { Item = "AntennaWhip" } },
			Passive = {
				Text = "Recruits +30%; distress calls arrive 30 seconds sooner.",
				Modifiers = { mod("RecruitRate", 1.3), mod("DistressCallLeadSeconds", 30) },
			},
			Ability = { Name = "Supply Call", Text = "A free supply crate, once per era.", Uses = { Per = "Era", Count = 1 } },
			Level2 = { Text = "Two calls per era.", Modifiers = { mod("SupplyCallsPerEra", 2) } },
			Level3 = { Text = "Recruits are more often Rare.", Modifiers = { mod("RareRecruitChance", 1.5) } },
			Talentable = true,
			Notes = "Level 3 Rare odds x1.5 is provisional",
		},
		HazmatTech = {
			Name = "Hazmat Tech", Tier = "Rare", Price = 120,
			Kit = { { Item = "RivetSMG" }, { Item = "GeigerCounter" }, { Item = "HazmatSuit" }, { Item = "HazardHook" } },
			Passive = { Text = "Immune to gas; radiation -70%.", Modifiers = { mod("GasImmune", 1), mod("RadiationGain", 0.3) } },
			Ability = { Name = "Decon Field", Text = "Clears radiation and gas from a room and everyone in it.", CooldownSeconds = 60 },
			Level2 = { Text = "Decon Room +50%.", Modifiers = { mod("RoomOutput", 1.5, { Room = "DeconRoom" }) } },
			Level3 = { Text = "Outbreaks cured twice as fast.", Modifiers = { mod("OutbreakCureSpeed", 2) } },
			Talentable = true,
		},
		Exterminator = {
			Name = "Exterminator", Tier = "Rare", Price = 120,
			Kit = { { Item = "Flamethrower" }, { Item = "LeadPipe" } },
			Passive = {
				Text = "+30% damage to creatures; burning spreads between monsters, never to rooms.",
				Modifiers = { mod("CreatureDamage", 1.3), mod("BurnSpreadsBetweenMonsters", 1) },
			},
			Ability = { Name = "Napalm Line", Text = "A burning strip on the floor for 6 s.", CooldownSeconds = 50, DurationSeconds = 6 },
			Level2 = { Text = "Fuel use -30%.", Modifiers = { mod("FuelUse", 0.7) } },
			Level3 = { Text = "Kills lower Disturbance.", Modifiers = { mod("KillsLowerDisturbance", 1) } },
			Talentable = true,
		},
		Marksman = {
			Name = "Marksman", Tier = "Rare", Price = 120,
			Kit = { { Item = "LeverRifle" }, { Item = "PocketPistol" }, { Item = "HuntingKnife" } },
			Passive = { Text = "Weak-point hits deal 2.5x.", Modifiers = { mod("WeakPointMultiplier", 2.5) } },
			Ability = { Name = "Steady Shot", Text = "The next 3 shots pierce and crit.", CooldownSeconds = 30 },
			Level2 = { Text = "Longer aim zoom.", Modifiers = { mod("AimZoom", 1.3) } },
			Level3 = { Text = "Crits stagger bosses.", Modifiers = { mod("CritsStaggerBosses", 1) } },
			Talentable = true,
			Notes = "Level 2 zoom x1.3 is provisional",
		},
		Driller = {
			Name = "Driller", Tier = "Rare", Price = 120,
			Kit = { { Item = "Drill" }, { Item = "Pickaxe" }, { Item = "PumpShotgun" } },
			Passive = {
				Text = "Digs twice as fast; sees ore and caves 2 cells into rock.",
				Modifiers = { mod("DigSpeed", 2), mod("OreSightCells", 2) },
			},
			Ability = { Name = "Overdrive", Text = "Digs 3 cells in a line at once, adding Disturbance.", CooldownSeconds = 60 },
			Level2 = { Text = "Dug cells give +25% ore.", Modifiers = { mod("DugOre", 1.25) } },
			Level3 = { Text = "Digging Disturbance -40%.", Modifiers = { mod("DigDisturbance", 0.6) } },
			Talentable = true,
		},
		Scavenger = {
			Name = "Scavenger", Tier = "Rare", Price = 120,
			Kit = { { Item = "RivetSMG" }, { Item = "FireAxe" } },
			Passive = { Text = "Backpack +8; an extra loot roll on containers.", Modifiers = { mod("BackpackSlots", 8), mod("ExtraLootRolls", 1) } },
			Ability = { Name = "Magnet Sweep", Text = "Pulls loot within 30 studs to you.", CooldownSeconds = 30 },
			Level2 = { Text = "Better rare-gear odds.", Modifiers = { mod("RareGearOdds", 1.5) } },
			Level3 = { Text = "Keeps the backpack when downed.", Modifiers = { mod("KeepBackpackWhenDowned", 1) } },
			Talentable = true,
			Notes = "Level 2 rare-gear odds x1.5 is provisional",
		},
		Warden = {
			Name = "Warden", Tier = "Epic", Price = 300,
			Kit = { { Item = "ServiceRevolver" }, { Item = "ShockBaton" } },
			Passive = {
				Text = "Breaks vote ties; +15% build speed; residents +20% experience.",
				Modifiers = { mod("BreaksVoteTies", 1), mod("BuildSpeed", 1.15), mod("ResidentXP", 1.2, { Scope = "Bunker" }) },
			},
			Ability = {
				Name = "Rally Call",
				Text = "Armed residents within 2 floors come to you with +30% damage for 15 s.",
				CooldownSeconds = 60,
				DurationSeconds = 15,
			},
			Level2 = { Text = "Chooses residents' level-up stat.", Modifiers = { mod("ChoosesLevelStat", 1) } },
			Level3 = { Text = "+10% output across the bunker.", Modifiers = { mod("AllOutput", 1.1, { Scope = "Bunker" }) } },
			Talentable = true,
			TalentExclude = { "BreaksVoteTies" },
		},
		Demolitionist = {
			Name = "Demolitionist", Tier = "Epic", Price = 300,
			Kit = { { Item = "GrenadeLauncher" }, { Item = "Sledgehammer" } },
			Passive = { Text = "Explosives +40% damage and radius.", Modifiers = { mod("ExplosiveDamage", 1.4), mod("ExplosiveRadius", 1.4) } },
			Ability = {
				Name = "Breaching Charge",
				Text = "A huge blast that also clears a rock cell, adding Disturbance.",
				CooldownSeconds = 45,
			},
			Level2 = { Text = "+2 Frag Grenades.", Modifiers = { mod("ExtraFragGrenades", 2) } },
			Level3 = { Text = "Explosions stun bosses.", Modifiers = { mod("ExplosionsStunBosses", 1) } },
			Talentable = true,
		},
		Spelunker = {
			Name = "Spelunker", Tier = "Epic", Price = 300,
			Kit = { { Item = "Grapple" }, { Item = "Pickaxe" }, { Item = "PumpShotgun" } },
			Passive = {
				Text = "Double light radius; no fall damage; reveals cave layouts.",
				Modifiers = { mod("LightRadius", 2), mod("NoFallDamage", 1), mod("RevealCaveLayouts", 1) },
			},
			Ability = { Name = "Grapple Line", Text = "Zip to a point or pull a teammate.", CooldownSeconds = 12 },
			Level2 = { Text = "Finds cryo pods and caches more often.", Modifiers = { mod("FindChance", 1.5) } },
			Level3 = {
				Text = "Rescued people follow faster and take less damage.",
				Modifiers = { mod("RescuedFollowSpeed", 1.25), mod("RescuedDamageTaken", 0.75) },
			},
			Talentable = true,
			Notes = "Level 2 and 3 multipliers are provisional",
		},
		MadScientist = {
			Name = "Mad Scientist", Tier = "Legendary", Price = 500,
			Kit = { { Item = "ArcRifle" }, { Item = "ShockBaton" } },
			Passive = { Text = "Lab +50%.", Modifiers = { mod("RoomOutput", 1.5, { Room = "Lab" }) } },
			Ability = {
				Name = "Gadget Belt",
				Text = "Shock Trap, Teleport Beacon (the team can teleport to it) or Gravity Well.",
				CooldownSeconds = 40,
				Options = { "Shock Trap", "Teleport Beacon", "Gravity Well" },
			},
			Level2 = { Text = "Arc Rifle chains to 3 enemies.", Modifiers = { mod("ArcChainTargets", 3) } },
			Level3 = { Text = "One free blueprint reroll per era.", Modifiers = { mod("FreeDraftRerollsPerEra", 1) } },
			Talentable = true,
			Notes = "Gadget Belt: 40 s each",
		},
		Tinkerer = {
			Name = "Tinkerer", Tier = "Legendary", Price = 500,
			Kit = { { Item = "Welder" }, { Item = "RivetSMG" }, { Item = "PowerWrench" } },
			Companion = "Combat Drone",
			Passive = { Text = "A drone companion that shoots and picks up loot." },
			Ability = {
				Name = "Drone Mode",
				Text = "Guard (shields you), Assault (damage) or Repair (fixes rooms).",
				CooldownSeconds = 20,
				DurationSeconds = 12,
				Options = { "Guard", "Assault", "Repair" },
			},
			Level2 = { Text = "The drone gets a second gun.", Modifiers = { mod("DroneGuns", 2) } },
			Level3 = { Text = "The drone revives you once per Surge.", Modifiers = { mod("DroneRevivesPerSurge", 1) } },
			Talentable = false,
			Notes = "Drone Mode's 12 s is provisional",
		},
	},
}
