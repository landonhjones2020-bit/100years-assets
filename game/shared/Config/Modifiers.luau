--!strict
--[[
	Modifiers: the vocabulary of effects. Classes, traits, Legends, draft cards and passes
	describe what they do as a list of { Key, Value, Scope?, Room? }; the system that owns a
	key applies it. Prompt says which build prompt (bible Section 24) implements the key, so
	every effect in the data has a home.

	Unit: Multiplier (x Value), Add (+ Value), Set (becomes Value), Flag (1 = on),
	Chance (0 to 1). Scope (default here, can be overridden): Self (the holder), Presence
	(while the holder is in the room), Room (everyone in the holder's room), Nearby (around
	the holder), Floor, Team (all players), Bunker (the whole run).
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local function m(unit: string, scope: string, prompt: number, text: string)
	return { Unit = unit, Scope = scope, Prompt = prompt, Text = text }
end

return {
	Schema = Check.shape({
		Unit = Check.enum({ "Multiplier", "Add", "Set", "Flag", "Chance" }),
		Scope = F.Scope,
		Prompt = Check.integer(0, 40),
		Text = F.Short,
	}),
	Entries = {
		-- Player combat and survival (Prompts 11, 20)
		MaxHealth = m("Add", "Self", 11, "Max health"),
		MaxHealthMult = m("Multiplier", "Self", 11, "Max health"),
		StaminaMult = m("Multiplier", "Team", 11, "Max stamina"),
		SurfaceMoveSpeed = m("Multiplier", "Self", 16, "Move speed on the surface"),
		ReviveSeconds = m("Set", "Self", 11, "Seconds to revive a downed player"),
		TouchHeal = m("Flag", "Self", 20, "Heals residents by touch"),
		FireFloodDamageTaken = m("Multiplier", "Self", 13, "Damage taken from fire and floods"),
		NearbyResidentDamage = m("Multiplier", "Nearby", 20, "Damage dealt by residents near the holder"),
		ArmedResidentDamage = m("Multiplier", "Bunker", 20, "Damage dealt by armed residents"),
		CreatureDamage = m("Multiplier", "Self", 11, "Damage to monsters"),
		GunDamage = m("Multiplier", "Self", 11, "Gun damage"),
		FireRate = m("Multiplier", "Self", 11, "Gun fire rate"),
		WeakPointMultiplier = m("Set", "Self", 20, "Damage multiplier on weak-point hits"),
		AimZoom = m("Multiplier", "Self", 20, "Aim zoom"),
		CritsStaggerBosses = m("Flag", "Self", 20, "Critical hits stagger bosses"),
		BurnSpreadsBetweenMonsters = m("Flag", "Self", 20, "Burning spreads between monsters, never to rooms"),
		FuelUse = m("Multiplier", "Self", 20, "Flamethrower fuel use"),
		ExplosiveDamage = m("Multiplier", "Self", 20, "Explosive damage"),
		ExplosiveRadius = m("Multiplier", "Self", 20, "Explosive radius"),
		ExtraFragGrenades = m("Add", "Self", 20, "Extra Frag Grenades in the loadout"),
		ExplosionsStunBosses = m("Flag", "Self", 20, "Explosions stun bosses"),
		ArcChainTargets = m("Set", "Self", 20, "Enemies the Arc Rifle chains to"),
		DroneGuns = m("Set", "Self", 20, "Guns on the combat drone"),
		DroneRevivesPerSurge = m("Add", "Self", 20, "Times per Surge the drone revives its owner"),
		TurretDuration = m("Multiplier", "Self", 20, "How long turrets last"),
		TurretShock = m("Flag", "Self", 20, "Turrets shock"),
		BarricadeCost = m("Multiplier", "Self", 20, "Barricade cost"),
		TriagePulseClears = m("Flag", "Self", 20, "Triage Pulse also clears conditions"),
		InstantRally = m("Flag", "Self", 20, "Armed residents answer the holder's rally at once"),
		DefendsAnyRoom = m("Flag", "Self", 27, "Defends whatever room they stand in"),
		LightRadius = m("Multiplier", "Self", 17, "Light radius"),
		NoFallDamage = m("Flag", "Self", 17, "No fall damage"),
		RadiationGain = m("Multiplier", "Self", 16, "How fast radiation builds"),
		GasImmune = m("Flag", "Self", 23, "Immune to gas"),
		GasDamageTaken = m("Multiplier", "Self", 23, "Damage taken from gas"),
		StormWarningSeconds = m("Add", "Self", 16, "Seconds of extra warning before the storm siren"),
		KillsLowerDisturbance = m("Flag", "Self", 20, "Kills lower Disturbance"),
		MedkitsPerPlayer = m("Add", "Team", 19, "Medkits given to every player now"),
		WeaponRarityUp = m("Add", "Team", 19, "Every player's weapons go up this many rarities now"),

		-- Loot and backpack (Prompts 16, 20)
		BackpackSlots = m("Add", "Self", 16, "Backpack slots"),
		LootOutline = m("Flag", "Self", 16, "Loot is outlined"),
		ExtraLootRolls = m("Add", "Self", 16, "Extra loot rolls on containers"),
		RareGearOdds = m("Multiplier", "Self", 16, "Odds of rare gear"),
		KeepBackpackWhenDowned = m("Flag", "Self", 16, "Keeps the backpack when downed"),

		-- Building, rooms and economy (Prompts 8, 9)
		RoomOutput = m("Multiplier", "Bunker", 9, "Output of one room type (set Room)"),
		AllOutput = m("Multiplier", "Self", 9, "Output in any job"),
		DoubleOutputChance = m("Chance", "Self", 26, "Chance each cycle of double output"),
		StockpileCaps = m("Multiplier", "Bunker", 9, "Every stockpile cap"),
		BuildCost = m("Multiplier", "Bunker", 8, "Build and upgrade costs"),
		BuildSpeed = m("Multiplier", "Bunker", 8, "Construction speed"),
		RepairSpeed = m("Multiplier", "Self", 13, "Repair speed"),
		RepairsRooms = m("Flag", "Room", 26, "Slowly repairs rooms in scope"),
		FoodUse = m("Multiplier", "Self", 9, "Food eaten each cycle"),
		MealsHeal = m("Flag", "Self", 20, "Hearty Meal also heals"),
		RoomHP = m("Multiplier", "Bunker", 13, "Room HP"),
		BlastDoorHealth = m("Multiplier", "Bunker", 13, "Blast Door health"),
		BlastDoorDamageTaken = m("Multiplier", "Self", 27, "Damage the Blast Door takes while the holder guards it"),
		BlastDoorLevel = m("Add", "Bunker", 19, "Blast Door levels"),
		ReactorOverloadChance = m("Chance", "Bunker", 19, "Chance per Surge of a Reactor overload"),
		ResearchSpeed = m("Multiplier", "Self", 26, "Lab research speed"),
		CraftSpeed = m("Multiplier", "Self", 30, "Workshop crafting speed"),
		AmmoCraftCost = m("Multiplier", "Bunker", 30, "Cost of crafting ammo"),
		ScrapPerCycle = m("Add", "Self", 26, "Scrap found each cycle"),
		TraderPrices = m("Multiplier", "Bunker", 30, "Trader prices"),
		TraderNow = m("Flag", "Bunker", 30, "The trader arrives now"),
		TraderRareStock = m("Flag", "Bunker", 30, "The trader brings rare stock"),
		BreaksVoteTies = m("Flag", "Self", 8, "Breaks tied votes"),
		FreeDraftRerollsPerEra = m("Add", "Self", 19, "Free blueprint rerolls per era"),

		-- Disasters (Prompts 13, 23, 24)
		FireSpread = m("Multiplier", "Bunker", 13, "How fast fire spreads"),
		ExtinguishSpeed = m("Multiplier", "Self", 13, "How fast fires are put out"),
		FireContained = m("Flag", "Room", 27, "Fires can't spread out of the holder's room"),
		RubbleClearInstant = m("Flag", "Self", 20, "The Fire Axe clears rubble instantly"),
		FloodDrainSpeed = m("Multiplier", "Bunker", 23, "How fast floods drain"),
		BlackoutDuration = m("Multiplier", "Bunker", 13, "How long blackouts last"),
		GasStrength = m("Multiplier", "Bunker", 23, "Gas leak strength"),
		OutbreakCureSpeed = m("Multiplier", "Self", 24, "How fast outbreaks are cured"),
		DarkSpawnBonus = m("Multiplier", "Bunker", 12, "Extra monster spawns in dark rooms"),
		AccidentChance = m("Chance", "Self", 26, "Chance each cycle of a minor fire or flood in their room"),

		-- Digging (Prompt 14)
		DigSpeed = m("Multiplier", "Self", 14, "Digging speed"),
		DigDisturbance = m("Multiplier", "Self", 14, "Disturbance added by digging"),
		OreSightCells = m("Set", "Self", 14, "Cells into the rock where ore and caves show"),
		DugOre = m("Multiplier", "Self", 14, "Ore from dug cells"),
		OrePocketGuaranteed = m("Flag", "Self", 27, "Every cell dug holds at least an ore pocket"),

		-- Exploration, recruits and expeditions (Prompts 16, 17, 18)
		RevealCaveLayouts = m("Flag", "Self", 17, "Reveals cave layouts"),
		FindChance = m("Multiplier", "Self", 17, "Chance of finding cryo pods and caches"),
		RescuedFollowSpeed = m("Multiplier", "Self", 16, "Speed of rescued people following the holder"),
		RescuedDamageTaken = m("Multiplier", "Self", 16, "Damage rescued people take while following"),
		ExpeditionLoot = m("Multiplier", "Self", 18, "Expedition loot"),
		ExpeditionScrap = m("Multiplier", "Self", 18, "Scrap from expeditions"),
		ExpeditionCarry = m("Multiplier", "Self", 18, "How much they carry on expeditions"),
		NextTripLoot = m("Multiplier", "Team", 19, "Loot on the next surface trip"),
		NextStormEarlySeconds = m("Add", "Bunker", 19, "The next storm hits this many seconds early"),
		RecruitRate = m("Multiplier", "Bunker", 18, "How often radio recruits arrive"),
		RareRecruitChance = m("Multiplier", "Bunker", 18, "Odds a recruit is Rare"),
		DistressCallLeadSeconds = m("Add", "Bunker", 18, "Distress calls arrive this many seconds sooner"),
		SupplyCallsPerEra = m("Set", "Self", 20, "Supply Calls per era"),
		RecruitsNow = m("Add", "Bunker", 19, "Recruits who arrive now"),
		RareRecruitNow = m("Add", "Bunker", 19, "Rare residents who join now"),
		BountyKills = m("Set", "Team", 19, "Monsters to kill before the next Surge"),
		BountyScrap = m("Set", "Team", 19, "Scrap paid when the bounty is met"),

		-- Residents (Prompts 10, 26, 36)
		ResidentXP = m("Multiplier", "Self", 10, "Resident experience"),
		ChoosesLevelStat = m("Flag", "Self", 20, "Chooses the stat residents raise when they level"),
		ResidentLevels = m("Add", "Bunker", 19, "Levels every resident gains now"),
		MoraleNow = m("Add", "Bunker", 19, "Morale every resident gains now"),
		SurgeSurvivedMorale = m("Add", "Bunker", 27, "Morale for everyone after each Surge survived"),
		RoommateMorale = m("Add", "Room", 26, "Roommates' morale each cycle"),
		TreatedHealSpeed = m("Multiplier", "Self", 27, "Healing speed of residents the holder treats"),
		NeverPanics = m("Flag", "Self", 26, "Never panics"),
		DefendsUnarmed = m("Flag", "Self", 26, "Defends their room even without a weapon"),
		CalmsRoommates = m("Flag", "Room", 26, "Calms panicked roommates"),
		PanicChance = m("Multiplier", "Self", 26, "Chance to panic"),
		FleesBreaches = m("Flag", "Self", 26, "Flees breaches"),
		RunsIntoHazards = m("Flag", "Self", 26, "May run into hazards when panicked"),
		RestNeed = m("Multiplier", "Self", 10, "Rest needed"),
		NoDarkPenalty = m("Flag", "Self", 26, "No penalty in dark rooms"),
		Claustrophobic = m("Flag", "Self", 26, "Morale drops at depth 4 and below"),
		AfraidOfDark = m("Flag", "Self", 26, "Morale crashes in dark rooms and refuses to work there"),
		Hothead = m("Flag", "Self", 36, "Starts fights with rivals"),
		Homesick = m("Flag", "Self", 26, "Morale slowly drains unless they spend time in the Lounge"),
	},
}
