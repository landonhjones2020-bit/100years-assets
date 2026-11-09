--!strict
--[[
	Items: weapons, throwables, tools, consumables and resident gear (bible Sections 9, 11 and
	the Appendix). Combat numbers are provisional starting points for the combat prompts
	(11 and 20); rarity scales damage (ItemRarities). AmmoPerShot follows bible Section 9.
	ClassKit marks items that only come in a class kit (Arc Rifle: or as a rare drop).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local Melee = Check.shape({
	Damage = F.NonNegative,
	HeavyDamage = F.NonNegative,
	SwingSeconds = F.Seconds,
	Knockback = Check.optional(F.NonNegative),
	StunSeconds = Check.optional(F.Seconds),
	BreaksRubble = F.Flag,
	Digs = F.Flag,
})

local Gun = Check.shape({
	Damage = F.NonNegative,
	Pellets = Check.optional(F.PositiveInt),
	FireRate = F.NonNegative, -- shots (or flame ticks) per second
	Range = F.NonNegative,
	Magazine = F.PositiveInt,
	ReloadSeconds = F.Seconds,
	AmmoPerShot = F.Count,
	SpreadDegrees = F.NonNegative,
	Cone = F.Flag, -- flamethrower: a short cone, not a ray
	Projectile = F.Flag, -- grenade launcher: a real projectile
	BlastRadius = Check.optional(F.NonNegative),
	ChainTargets = Check.optional(F.Count),
	Automatic = F.Flag,
})

local Throwable = Check.shape({
	Radius = F.NonNegative,
	Damage = Check.optional(F.NonNegative),
	StunSeconds = Check.optional(F.Seconds),
	LightSeconds = Check.optional(F.Seconds),
	Extinguishes = F.Flag,
	RevealsHidden = F.Flag,
	Trap = F.Flag,
})

return {
	Schema = Check.shape({
		Name = F.Name,
		Kind = Check.enum({ "Melee", "Gun", "Throwable", "Tool", "Consumable", "Outfit", "ResidentTool", "Placeable" }),
		Text = F.Short,
		Melee = Check.optional(Melee),
		Gun = Check.optional(Gun),
		Throwable = Check.optional(Throwable),
		Outfit = Check.optional(Check.shape({ Stat = Check.ref("Stats"), Health = Check.optional(F.Count), IgnoresGas = F.Flag })),
		ResidentUse = Check.optional(F.Short), -- what a resident does with it as gear
		UsesResource = Check.optional(Check.ref("Resources")),
		HasRarity = F.Flag,
		ClassKit = F.Flag,
		Asset = F.Asset,
	}),
	Entries = {
		-- Melee
		Wrench = {
			Name = "Wrench",
			Kind = "Melee",
			Text = "Fast and light.",
			Melee = { Damage = 14, HeavyDamage = 26, SwingSeconds = 0.35 },
			ResidentUse = "Repairs their room faster",
			HasRarity = true,
			Asset = "Weapon_Wrench",
		},
		LeadPipe = {
			Name = "Lead Pipe",
			Kind = "Melee",
			Text = "Balanced.",
			Melee = { Damage = 20, HeavyDamage = 36, SwingSeconds = 0.5 },
			HasRarity = true,
			Asset = "Weapon_LeadPipe",
		},
		FireAxe = {
			Name = "Fire Axe",
			Kind = "Melee",
			Text = "Heavy; breaks rubble.",
			Melee = { Damage = 32, HeavyDamage = 58, SwingSeconds = 0.8, BreaksRubble = true },
			HasRarity = true,
			Asset = "Weapon_FireAxe",
		},
		Sledgehammer = {
			Name = "Sledgehammer",
			Kind = "Melee",
			Text = "Slow, big knockback.",
			Melee = { Damage = 45, HeavyDamage = 80, SwingSeconds = 1.1, Knockback = 30, BreaksRubble = true },
			HasRarity = true,
			Asset = "Weapon_Sledgehammer",
		},
		ShockBaton = {
			Name = "Shock Baton",
			Kind = "Melee",
			Text = "Stuns.",
			Melee = { Damage = 16, HeavyDamage = 28, SwingSeconds = 0.5, StunSeconds = 1.2 },
			HasRarity = true,
			Asset = "Weapon_ShockBaton",
		},
		Pickaxe = {
			Name = "Pickaxe",
			Kind = "Melee",
			Text = "Also digs.",
			Melee = { Damage = 22, HeavyDamage = 40, SwingSeconds = 0.7, Digs = true },
			HasRarity = true,
			Asset = "Weapon_Pickaxe",
		},
		-- Landon, 2026-11-08: every class kit has a melee weapon that matches it. These five are
		-- the kits that had none (the Engineer takes the Wrench). Numbers provisional.
		DefibPaddles = {
			Name = "Defib Paddles",
			Kind = "Melee",
			Text = "Zaps and stuns briefly.",
			Melee = { Damage = 12, HeavyDamage = 22, SwingSeconds = 0.45, StunSeconds = 0.8 },
			HasRarity = true,
			Asset = "Weapon_DefibPaddles",
		},
		AntennaWhip = {
			Name = "Antenna Whip",
			Kind = "Melee",
			Text = "Very fast and light.",
			Melee = { Damage = 11, HeavyDamage = 20, SwingSeconds = 0.3 },
			HasRarity = true,
			Asset = "Weapon_AntennaWhip",
		},
		HazardHook = {
			Name = "Hazard Hook",
			Kind = "Melee",
			Text = "Balanced, with a shove.",
			Melee = { Damage = 18, HeavyDamage = 32, SwingSeconds = 0.5, Knockback = 12 },
			HasRarity = true,
			Asset = "Weapon_HazardHook",
		},
		HuntingKnife = {
			Name = "Hunting Knife",
			Kind = "Melee",
			Text = "Quick and light.",
			Melee = { Damage = 13, HeavyDamage = 24, SwingSeconds = 0.3 },
			HasRarity = true,
			Asset = "Weapon_HuntingKnife",
		},
		PowerWrench = {
			Name = "Power Wrench",
			Kind = "Melee",
			Text = "Motorised; heavy hits.",
			Melee = { Damage = 22, HeavyDamage = 40, SwingSeconds = 0.55, Knockback = 15 },
			HasRarity = true,
			Asset = "Weapon_PowerWrench",
		},

		-- Guns
		PocketPistol = {
			Name = "Pocket Pistol",
			Kind = "Gun",
			Text = "Light ammo, quick.",
			Gun = { Damage = 12, FireRate = 4, Range = 120, Magazine = 10, ReloadSeconds = 1.2, AmmoPerShot = 1, SpreadDegrees = 1.5 },
			UsesResource = "Ammo",
			HasRarity = true,
			Asset = "Weapon_PocketPistol",
		},
		ServiceRevolver = {
			Name = "Service Revolver",
			Kind = "Gun",
			Text = "Heavy single shots.",
			Gun = { Damage = 34, FireRate = 1.4, Range = 160, Magazine = 6, ReloadSeconds = 2.2, AmmoPerShot = 1, SpreadDegrees = 0.8 },
			UsesResource = "Ammo",
			HasRarity = true,
			Asset = "Weapon_ServiceRevolver",
		},
		PumpShotgun = {
			Name = "Pump Shotgun",
			Kind = "Gun",
			Text = "Close range.",
			Gun = { Damage = 9, Pellets = 8, FireRate = 1, Range = 40, Magazine = 6, ReloadSeconds = 3, AmmoPerShot = 2, SpreadDegrees = 7 },
			UsesResource = "Ammo",
			HasRarity = true,
			Asset = "Weapon_PumpShotgun",
		},
		LeverRifle = {
			Name = "Lever Rifle",
			Kind = "Gun",
			Text = "Long range.",
			Gun = { Damage = 45, FireRate = 1.2, Range = 300, Magazine = 7, ReloadSeconds = 2.5, AmmoPerShot = 2, SpreadDegrees = 0.3 },
			UsesResource = "Ammo",
			HasRarity = true,
			Asset = "Weapon_LeverRifle",
		},
		RivetSMG = {
			Name = "Rivet SMG",
			Kind = "Gun",
			Text = "Fast fire, light ammo.",
			Gun = { Damage = 9, FireRate = 10, Range = 90, Magazine = 30, ReloadSeconds = 1.8, AmmoPerShot = 1, SpreadDegrees = 3, Automatic = true },
			UsesResource = "Ammo",
			HasRarity = true,
			Asset = "Weapon_RivetSMG",
		},
		Flamethrower = {
			Name = "Flamethrower",
			Kind = "Gun",
			Text = "Exterminator's kit; short cone.",
			Gun = { Damage = 6, FireRate = 10, Range = 18, Magazine = 100, ReloadSeconds = 3, AmmoPerShot = 1, SpreadDegrees = 20, Cone = true, Automatic = true },
			UsesResource = "Ammo",
			HasRarity = true,
			ClassKit = true,
			Asset = "Weapon_Flamethrower",
		},
		GrenadeLauncher = {
			Name = "Grenade Launcher",
			Kind = "Gun",
			Text = "Demolitionist's kit; explosive rounds.",
			Gun = { Damage = 80, FireRate = 0.8, Range = 150, Magazine = 4, ReloadSeconds = 3, AmmoPerShot = 3, SpreadDegrees = 0, Projectile = true, BlastRadius = 10 },
			UsesResource = "Ammo",
			HasRarity = true,
			ClassKit = true,
			Asset = "Weapon_GrenadeLauncher",
		},
		ArcRifle = {
			Name = "Arc Rifle",
			Kind = "Gun",
			Text = "Mad Scientist's kit; rare drop otherwise. Arcs jump between enemies.",
			Gun = { Damage = 28, FireRate = 2, Range = 100, Magazine = 12, ReloadSeconds = 2.4, AmmoPerShot = 2, SpreadDegrees = 0.5, ChainTargets = 1 },
			UsesResource = "Ammo",
			HasRarity = true,
			ClassKit = true,
			Asset = "Weapon_ArcRifle",
		},

		-- Throwables
		FragGrenade = {
			Name = "Frag Grenade",
			Kind = "Throwable",
			Text = "Area damage.",
			Throwable = { Radius = 12, Damage = 90 },
			Asset = "Throwable_FragGrenade",
		},
		Flare = {
			Name = "Flare",
			Kind = "Throwable",
			Text = "Lights an area and reveals Prism Stalkers.",
			Throwable = { Radius = 40, LightSeconds = 20, RevealsHidden = true },
			Asset = "Throwable_Flare",
		},
		FoamGrenade = {
			Name = "Foam Grenade",
			Kind = "Throwable",
			Text = "Puts out fires.",
			Throwable = { Radius = 14, Extinguishes = true },
			Asset = "Throwable_FoamGrenade",
		},
		ShockMine = {
			Name = "Shock Mine",
			Kind = "Throwable",
			Text = "Stuns whatever steps on it.",
			Throwable = { Radius = 6, StunSeconds = 3, Trap = true },
			Asset = "Throwable_ShockMine",
		},

		-- Tools
		Drill = { Name = "Drill", Kind = "Tool", Text = "Digs rock.", HasRarity = true, Asset = "Tool_Drill" },
		Welder = { Name = "Welder", Kind = "Tool", Text = "Repairs rooms.", HasRarity = true, Asset = "Tool_Welder" },
		Extinguisher = { Name = "Extinguisher", Kind = "Tool", Text = "Puts out fires.", Asset = "Tool_Extinguisher" },
		GeigerCounter = { Name = "Geiger Counter", Kind = "Tool", Text = "Shows radiation and hazards nearby.", Asset = "Tool_GeigerCounter" },
		Grapple = { Name = "Grapple", Kind = "Tool", Text = "Spelunker's kit; zip lines.", ClassKit = true, Asset = "Tool_Grapple" },

		-- Consumables
		Medkit = {
			Name = "Medkit",
			Kind = "Consumable",
			Text = "Heals a player or revives a resident.",
			UsesResource = "Medkits",
			Asset = "Item_Medkit",
		},
		ClearRadPills = { Name = "Clear-Rad pills", Kind = "Consumable", Text = "Clear radiation.", Asset = "Item_ClearRadPills" },

		-- Placeables (crafted at the Workshop)
		Lamp = { Name = "Lamp", Kind = "Placeable", Text = "A placeable lamp for dark rooms and caves.", Asset = "Prop_Lamp" },
		Barricade = { Name = "Barricade", Kind = "Placeable", Text = "Seals a breach point, making it less likely to open again.", Asset = "Prop_Barricade" },
		Turret = { Name = "Turret", Kind = "Placeable", Text = "An auto-turret; the Engineer deploys one with Deploy Turret.", Asset = "Prop_Turret" },

		-- Resident outfits (+1 to +3 by rarity)
		WorkOveralls = { Name = "Work Overalls", Kind = "Outfit", Text = "Strength.", Outfit = { Stat = "Strength" } },
		LabCoat = { Name = "Lab Coat", Kind = "Outfit", Text = "Smarts.", Outfit = { Stat = "Smarts" } },
		SecurityVest = { Name = "Security Vest", Kind = "Outfit", Text = "Grit and health.", Outfit = { Stat = "Grit", Health = 20 } },
		TrackJacket = { Name = "Track Jacket", Kind = "Outfit", Text = "Speed.", Outfit = { Stat = "Speed" } },
		SundayBest = { Name = "Sunday Best", Kind = "Outfit", Text = "Charm.", Outfit = { Stat = "Charm" } },
		HazmatSuit = {
			Name = "Hazmat Suit",
			Kind = "Outfit",
			Text = "Grit; ignores gas. Part of the Hazmat Tech's kit.",
			Outfit = { Stat = "Grit", IgnoresGas = true },
		},

		-- Resident tools
		Stethoscope = { Name = "Stethoscope", Kind = "ResidentTool", Text = "Medbay.", ResidentUse = "Better Medbay output" },
		HandDrill = { Name = "Hand Drill", Kind = "ResidentTool", Text = "Digging.", ResidentUse = "Digs faster in the Drill Bay queue" },
		RadioHeadset = {
			Name = "Radio Headset",
			Kind = "ResidentTool",
			Text = "Recruiting. Part of the Radio Operator's kit.",
			ResidentUse = "Better recruiting in the Radio Room",
		},
		Ladle = { Name = "Ladle", Kind = "ResidentTool", Text = "Kitchen.", ResidentUse = "Better Kitchen output" },
	},
}
