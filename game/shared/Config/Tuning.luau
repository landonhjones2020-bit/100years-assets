--!strict
--[[
	Tuning: the rule numbers of every system, one entry per system, each with its own schema
	(Config.Schemas). Values come from the bible where it gives them (section noted); the rest
	are provisional starting points for playtests, marked "prov." in comments.

		local Clock = Config.Get("Tuning", "Clock")
		Clock.DaySeconds -- 180
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local N, I, S, Fr = F.NonNegative, F.Count, F.Seconds, F.Fraction
local function list(item: Check.Checker, max: number): Check.Checker
	return Check.array(item, max)
end
local function shape(fields: { [string]: Check.Checker }): Check.Checker
	return Check.shape(fields)
end

local Cell = Check.shape({
	Floor = Check.integer(1, 10),
	Column = Check.integer(-6, 6),
	Room = Check.optional(Check.ref("Rooms")),
	Span = Check.optional(Check.integer(1, 3)),
	Dug = F.Flag,
})

local Schemas: { [string]: Check.Checker } = {
	Clock = shape({
		CycleSeconds = S, DaySeconds = S, SurgeSeconds = S,
		YearsPerCycleStart = I, YearsPerCycleMax = I, -- the bonuses are Config.Objectives' YearsPerCycle
		FinalYear = I, IntroSeconds = S, IntroSkipAfterSeconds = S,
		SurgeSirenSeconds = S, TutorialFirstSurge = Check.boolean(),
	}),
	Grid = shape({
		ColumnMin = Check.integer(-20, 0), ColumnMax = Check.integer(0, 20), FloorMin = I, FloorMax = I,
		CellWidth = N, CellHeight = N, CellDepth = N, SlabThickness = N, SourceFloor = I,
	}),
	StartingBunker = shape({
		Cells = list(Cell, 20),
		Residents = I,
		ResidentLevels = F.Range,
		ResidentTier = Check.ref("Tiers"),
	}),
	Rooms = shape({
		WorkerSlotsPerCell = list(I, 3), HP = list(I, 3), LevelMultiplier = list(N, 3), MergeMultiplier = list(N, 3),
		BuildSecondsPerCell = S, HelperBuildSpeed = N, ResidentRepairPerSecond = N,
		DarkSpawnMultiplier = N, DarkMoralePerCycle = F.Number,
	}),
	Votes = shape({
		TiesFail = Check.boolean(), BigSpendFraction = Fr, OpenProposalsPerPlayer = I, FailedCooldownSeconds = S,
		PassEarlyWhenAllYes = Check.boolean(), SoloSkipsVotes = Check.boolean(), RecheckCostsOnPass = Check.boolean(),
	}),
	Player = shape({
		Health = I, Stamina = I, SprintStaminaPerSecond = N, DodgeStamina = N, HeavySwingStamina = N,
		StaminaRegenPerSecond = N, RadiationMax = I, RadiationHealthDrainPerSecond = N,
		Loadout = shape({ Guns = I, Melee = I, Tool = I, Throwables = I, Medkits = I }),
		BackpackSlots = I, AimFieldOfView = list(N, 2), DownedSeconds = S, ReviveSeconds = S,
		RespawnSeconds = S, AimAssistDegrees = N, MedkitHeal = N,
	}),
	Digging = shape({
		DisturbancePerCell = N, StackPlayers = Check.boolean(), PushDeeperFloors = list(I, 3),
		ResidentDigMultiplier = N,
	}),
	Disturbance = shape({
		Max = N, DecayPerCycle = N, NestDestroyed = N, Explosive = N, ExtraBreachAt = N, TremorAt = N, AfterTremor = N,
	}),
	Threat = shape({
		Base = N, PerYear = N, PerDeepestFloor = N, PerDisturbance = N, PerRoom = N,
		PlayerScale = list(N, 6), BetweenSurgesFraction = N, BreachWarningSeconds = S,
		TutorialSurgeBudget = N, FirstRunEraIMultiplier = N,
	}),
	Residents = shape({
		StatMin = I, StatMax = I, StatCap = I, LevelMax = I, MoraleStart = N, FoodPerCycle = N, WaterPerCycle = N,
		ShortfallHealth = N, ShortfallMorale = N, RestDrainPerShift = N, RestRefillPerCycle = N,
		NoBedRestMultiplier = N, FriendsMax = I, FriendThreshold = N, GrievingMorale = N, GrievingCycles = I,
		SurgeSurvivedMorale = N, DeathReviveSeconds = S, XPPerWorkCycle = N, XPPerKill = N,
		XPPerExpeditionCycle = N, XPToLevelBase = N, XPToLevelStep = N,
		RareStatBonus = I,
	}),
	Aging = shape({
		StartAge = F.Range, YoungUntil = I, YoungXP = N, VeteranFrom = I, VeteranSpeed = N,
		ElderFrom = I, ElderKeptOutput = N, DeathAge = F.Range,
	}),
	Morale = shape({
		JobFit = F.Number, PoorFit = F.Number, FriendInRoom = F.Number, FedCycle = F.Number, Hungry = F.Number,
		DarkRoom = F.Number, NoBed = F.Number, Injured = F.Number,
	}),
	Trader = shape({
		EveryCycles = I, EveryCyclesWithPost = I, PostDiscount = N,
		Buys = Check.map(Check.ref("Resources"), N, 9),
	}),
	Wanderers = shape({ EveryCycles = F.Range, InspectCharm = I }),
	Expeditions = shape({
		Size = F.Range, Cycles = F.Range, DistressChance = Fr, BaseLossChance = Fr,
		SurfaceLoot = Check.ref("LootTables"), DeepLoot = Check.ref("LootTables"),
	}),
	Surface = shape({
		StormSirenSeconds = S, RadiationPerSecond = N, StormRadiationPerSecond = N, RefillEvery = Check.enum({ "Era" }),
	}),
	Legends = shape({ StartLevel = I, RenownMax = I, RenownStatBonus = I, StarterLegend = Check.ref("Legends") }),
	ClassShop = shape({
		Slots = I, ResetHourUTC = I, FreeRerolls = I, VIPFreeRerolls = I, RerollRobux = I, WishlistDays = I,
		FreeTrialRunsPerDay = I, ClassLevelRuns = list(I, 2),
	}),
	Account = shape({ LevelMax = I, XPPerYear = N, XPToLevelBase = N, XPToLevelStep = N, VIPGlowshardBonus = N }),
	Lobby = shape({ PadCountdownSeconds = S, PartyMax = I }),
}

return {
	Schemas = Schemas,
	Entries = {
		Clock = { -- Section 5
			CycleSeconds = 270, DaySeconds = 180, SurgeSeconds = 90,
			YearsPerCycleStart = 1, YearsPerCycleMax = 12, -- +2 per Lost Crew, +1 per era boss: Config.Objectives
			FinalYear = 100, IntroSeconds = 30, IntroSkipAfterSeconds = 2, -- era ends: Config.Eras
			SurgeSirenSeconds = 20, TutorialFirstSurge = true,
		},
		Grid = { -- Section 6
			ColumnMin = -6, ColumnMax = 6, FloorMin = 1, FloorMax = 10,
			CellWidth = 32, CellHeight = 16, CellDepth = 32, SlabThickness = 2, SourceFloor = 10,
		},
		StartingBunker = { -- Section 6: the shaft is the third cell on both floors
			Cells = {
				{ Floor = 1, Column = -3, Room = "BlastDoor", Span = 2 },
				{ Floor = 1, Column = -1, Room = "Shaft" },
				{ Floor = 1, Column = 0, Room = "Quarters", Span = 2 },
				{ Floor = 1, Column = 2, Dug = true },
				{ Floor = 2, Column = -3, Room = "Kitchen" },
				{ Floor = 2, Column = -2, Room = "WaterPurifier" },
				{ Floor = 2, Column = -1, Room = "Shaft" },
				{ Floor = 2, Column = 0, Room = "ReactorCore" },
				{ Floor = 2, Column = 1, Room = "Medbay" },
				{ Floor = 2, Column = 2, Dug = true },
			},
			Residents = 6,
			ResidentLevels = { Min = 1, Max = 3 },
			ResidentTier = "Common",
		},
		Rooms = { -- Section 6; build helpers, repair and dark-room morale prov.
			WorkerSlotsPerCell = { 2, 3, 4 }, HP = { 500, 800, 1200 }, LevelMultiplier = { 1, 1.5, 2 },
			MergeMultiplier = { 1, 1.1, 1.2 }, BuildSecondsPerCell = 20, HelperBuildSpeed = 0.25,
			ResidentRepairPerSecond = 2, DarkSpawnMultiplier = 2, DarkMoralePerCycle = -5,
		},
		Votes = { -- Section 8
			TiesFail = true, BigSpendFraction = 0.4, OpenProposalsPerPlayer = 1, FailedCooldownSeconds = 20,
			PassEarlyWhenAllYes = true, SoloSkipsVotes = true, RecheckCostsOnPass = true,
		},
		Player = { -- Section 9; stamina costs, radiation drain, aim assist and Medkit heal prov.
			Health = 100, Stamina = 100, SprintStaminaPerSecond = 12, DodgeStamina = 20, HeavySwingStamina = 20,
			StaminaRegenPerSecond = 18, RadiationMax = 100, RadiationHealthDrainPerSecond = 2,
			Loadout = { Guns = 2, Melee = 1, Tool = 1, Throwables = 2, Medkits = 3 },
			BackpackSlots = 10, AimFieldOfView = { 70, 50 }, DownedSeconds = 20, ReviveSeconds = 3,
			RespawnSeconds = 15, AimAssistDegrees = 6, MedkitHeal = 60,
		},
		Digging = { DisturbancePerCell = 5, StackPlayers = true, PushDeeperFloors = { 4, 7, 10 }, ResidentDigMultiplier = 0.25 },
		Disturbance = { -- Section 10
			Max = 100, DecayPerCycle = 10, NestDestroyed = 20, Explosive = 10, ExtraBreachAt = 50, TremorAt = 100, AfterTremor = 40,
		},
		Threat = { -- Section 10 lists the inputs; weights prov. First-run Era I is 30% easier (Section 22)
			Base = 12, PerYear = 1.2, PerDeepestFloor = 4, PerDisturbance = 0.25, PerRoom = 1,
			PlayerScale = { 1, 1.6, 2.1, 2.5, 2.8, 3 }, BetweenSurgesFraction = 0.1, BreachWarningSeconds = 10,
			TutorialSurgeBudget = 6, FirstRunEraIMultiplier = 0.7,
		},
		Residents = { -- Section 11; needs and experience prov.
			StatMin = 1, StatMax = 10, StatCap = 15, LevelMax = 20, MoraleStart = 60, FoodPerCycle = 1, WaterPerCycle = 1,
			ShortfallHealth = 10, ShortfallMorale = 10, RestDrainPerShift = 60, RestRefillPerCycle = 100,
			NoBedRestMultiplier = 0.4, FriendsMax = 3, FriendThreshold = 100, GrievingMorale = 20, GrievingCycles = 2,
			SurgeSurvivedMorale = 5, DeathReviveSeconds = 20, XPPerWorkCycle = 30, XPPerKill = 5,
			XPPerExpeditionCycle = 40, XPToLevelBase = 100, XPToLevelStep = 40, RareStatBonus = 2,
		},
		Aging = { -- Section 11
			StartAge = { Min = 18, Max = 50 }, YoungUntil = 29, YoungXP = 1.1, VeteranFrom = 55, VeteranSpeed = 0.9,
			ElderFrom = 70, ElderKeptOutput = 0.7, DeathAge = { Min = 80, Max = 100 },
		},
		Morale = { -- Section 11 lists the causes; amounts prov. (Grieving is a Condition)
			JobFit = 2, PoorFit = -2, FriendInRoom = 2, FedCycle = 1, Hungry = -10, DarkRoom = -5, NoBed = -5, Injured = -5,
		},
		Trader = { -- Section 13; what he pays in Scrap per unit prov.
			EveryCycles = 3, EveryCyclesWithPost = 2, PostDiscount = 0.85,
			Buys = { Food = 2, Water = 2, Iron = 6, Copper = 10, Crystal = 16 },
		},
		Wanderers = { EveryCycles = { Min = 2, Max = 3 }, InspectCharm = 7 }, -- Section 10
		Expeditions = { -- Section 12; distress and loss odds prov.
			Size = { Min = 1, Max = 3 }, Cycles = { Min = 1, Max = 3 }, DistressChance = 0.15, BaseLossChance = 0.05,
			SurfaceLoot = "ExpeditionSurface", DeepLoot = "ExpeditionDeep",
		},
		Surface = { StormSirenSeconds = 20, RadiationPerSecond = 0.2, StormRadiationPerSecond = 2, RefillEvery = "Era" }, -- Section 12; rates prov.
		Legends = { StartLevel = 5, RenownMax = 5, RenownStatBonus = 1, StarterLegend = "RosieKowalski" }, -- Section 15
		ClassShop = { -- Section 14
			Slots = 4, ResetHourUTC = 0, FreeRerolls = 1, VIPFreeRerolls = 2, RerollRobux = 99, WishlistDays = 3,
			FreeTrialRunsPerDay = 1, ClassLevelRuns = { 3, 10 },
		},
		Account = { LevelMax = 100, XPPerYear = 10, XPToLevelBase = 200, XPToLevelStep = 50, VIPGlowshardBonus = 0.25 }, -- Section 16; XP prov.
		Lobby = { PadCountdownSeconds = 20, PartyMax = 6 }, -- Section 21
	},
}
