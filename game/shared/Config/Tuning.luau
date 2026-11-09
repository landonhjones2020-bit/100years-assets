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
		CellWidth = N, CellHeight = N, CellDepth = N, SlabThickness = N, WallThickness = N, SourceFloor = I,
		Origin = shape({ X = F.Number, Y = F.Number, Z = F.Number }),
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
		DarkSpawnMultiplier = N, DarkMoralePerCycle = F.Number, TearDownRefund = Fr, PowerWarnAt = Fr,
	}),
	Votes = shape({
		TiesFail = Check.boolean(), BigSpendFraction = Fr, OpenProposalsPerPlayer = I, FailedCooldownSeconds = S,
		PassEarlyWhenAllYes = Check.boolean(), SoloSkipsVotes = Check.boolean(), RecheckCostsOnPass = Check.boolean(),
		ResultSeconds = S,
	}),
	Player = shape({
		Health = I, Stamina = I, SprintStaminaPerSecond = N, DodgeStamina = N, HeavySwingStamina = N,
		StaminaRegenPerSecond = N, RadiationMax = I, RadiationHealthDrainPerSecond = N,
		Loadout = shape({ Guns = I, Melee = I, Tool = I, Throwables = I, Medkits = I }),
		BackpackSlots = I, AimFieldOfView = list(N, 2), DownedSeconds = S, ReviveSeconds = S,
		RespawnSeconds = S, AimAssistDegrees = N, MedkitHeal = N, MedkitSeconds = S, HealWalkMultiplier = Fr,
	}),
	Combat = shape({
		LagSeconds = S, HistorySeconds = S, HistoryHz = N, HitTolerance = N, RayTolerance = N,
		OriginTolerance = N, RateTolerance = Fr,
		SprintMultiplier = N, StaminaRegenDelay = S,
		DodgeSeconds = S, DodgeInvulnerableSeconds = S, DodgeDistance = N, DodgeCooldownSeconds = S,
		MeleeReach = N, MeleeArcDegrees = N, MeleeReachTolerance = N, MeleeWindupFraction = Fr,
		ComboWindowSeconds = S, ComboSteps = I, HeavyChargeSeconds = S, HeavySwingMultiplier = N,
		CrawlSpeed = N, ReviveHealthFraction = Fr,
		CarriedAmmo = shape({ Start = I, Max = I }), RestockSeconds = S,
		ProjectileSpeed = N, ProjectileGravity = N, AssistPullPerSecond = N,
		Unarmed = shape({ Damage = N, HeavyDamage = N, SwingSeconds = S }),
		ThrowSpeed = N, ThrowGravity = N, ThrowCooldownSeconds = S, ThrowableStack = I, MineArmSeconds = S,
		MineLifetimeSeconds = S, TapHoldSeconds = S,
	}),
	Camera = shape({
		FieldOfView = N, PivotHeight = N, ShoulderOffset = N, ShoulderRaise = F.Number,
		Distance = shape({ Min = N, Max = N, Default = N }), IndoorMax = N, AimDistance = N, AimShoulder = N,
		PitchMin = F.Number, PitchMax = F.Number, StartPitch = F.Number,
		MouseDegreesPerPixel = N, TouchDegreesPerPixel = N, GamepadDegreesPerSecond = N, StickDeadzone = Fr,
		AimSensitivity = Fr, AimWalkSpeed = Fr, ZoomStep = N, PinchStudsPerPixel = N,
		CollisionRadius = N, WallMargin = N, FloorMargin = N, CeilingMargin = N, NearestDistance = N,
		EaseOutPerSecond = N, PivotFollowPerSecond = N, ShoulderSwapSeconds = S, AimBlendSeconds = S,
		FadeTransparency = Fr, FrontWallTransparency = Fr, FadeSeconds = S, NearFadeRadius = N,
		CharacterFadeDistance = N, ErrorsBeforeFallback = I,
	}),
	CommandView = shape({
		FieldOfView = N, MaxDistance = N, StartFloors = N, MinFloors = N, MaxFloors = N, MoveSeconds = S, ZoomStep = Fr,
		PanFloorsPerSecond = N, DragPixels = N, StickDeadzone = Fr,
		Ambient = F.Hex, OutdoorAmbient = F.Hex, ExposureCompensation = F.Number,
	}),
	Ping = shape({ Seconds = S }),
	Digging = shape({
		DisturbancePerCell = N, StackPlayers = Check.boolean(), PushDeeperFloors = list(I, 3),
		ResidentDigMultiplier = N,
		-- Prompt 14
		Tools = list(Check.ref("Items"), 4), PromptReach = N, TickSeconds = S, CaveInChance = Fr,
		NestHealth = N, NestBudget = N, NestPerCycle = N, CacheOpenSeconds = S, VoteRetrySeconds = S,
	}),
	Disturbance = shape({
		Max = N, DecayPerCycle = N, NestDestroyed = N, Explosive = N, ExtraBreachAt = N, TremorAt = N, AfterTremor = N,
	}),
	Threat = shape({
		Base = N, PerYear = N, PerDeepestFloor = N, PerDisturbance = N, PerRoom = N,
		PlayerScale = list(N, 6), BetweenSurgesFraction = N, BreachWarningSeconds = S,
		TutorialSurgeBudget = N, FirstRunEraIMultiplier = N,
		MaxMonsters = I, WaveSpacingSeconds = S, SpawnSpacingSeconds = S, TrickleCheckSeconds = S, DarkRoomWeight = N,
		BarricadeWeight = Fr, MaxBreachPointsPerSurge = I,
	}),
	Disasters = shape({
		TickSeconds = S, SurgeDelaySeconds = S, FuseSeconds = S, ValveSeconds = S,
		Fire = shape({
			StartStrength = N, GrowPerSecond = N, SpreadMinStrength = N,
			ResidentPerSecond = N, ExtinguisherPerSecond = N, ExtinguisherReach = N,
			PlayerDamagePerSecond = N, ResidentDamagePerSecond = N, ResidentFleeHealth = Fr,
			Fireproof = list(Check.ref("Rooms"), 21),
		}),
		Blackout = shape({ WholeGridChance = Fr }),
		CaveIn = shape({
			DoorwayHP = N, TunnelHP = N, BreakerMultiplier = N, DigSeconds = S, TunnelDigSeconds = S, Damage = N,
			DigItems = list(Check.ref("Items"), 4),
		}),
		Meltdown = shape({ SoloPlayers = I, SoloValveSeconds = S, HeldGraceSeconds = S, StartsFire = Check.boolean() }),
		ElectricalSurge = shape({ EraChance = list(Fr, 4), FireChance = Fr, BlackoutChance = Fr }),
	}),
	Repairs = shape({ RepairedAt = Fr, WelderPerSecond = N, WelderReach = N, ResidentSmartsBase = N, ToolTickSeconds = S }),
	MonsterAI = shape({
		TickSeconds = S, AggroSeconds = S, ProximityAggro = N, SmashMultiplier = N, StuckSeconds = S, KeepDistanceFraction = Fr,
		RoomDamageMultiplier = N, LatchDamageMultiplier = N, LatchIntervalMultiplier = N,
		GooSpeed = N, GooSlowSeconds = S, GooSlowMultiplier = Fr, WindupFraction = Fr,
		ResidentFleeRadius = N, ResidentCalmSeconds = S, ResidentSwatDamage = N, ResidentSwatSeconds = S,
	}),
	Residents = shape({
		StatMin = I, StatMax = I, StatCap = I, LevelMax = I, MoraleStart = N, FoodPerCycle = N, WaterPerCycle = N,
		ShortfallHealth = N, ShortfallMorale = N, RestDrainPerShift = N, RestRefillPerCycle = N,
		NoBedRestMultiplier = N, FriendsMax = I, FriendThreshold = N, GrievingMorale = N, GrievingCycles = I,
		SurgeSurvivedMorale = N, DeathReviveSeconds = S, XPPerWorkCycle = N, XPPerKill = N,
		XPPerExpeditionCycle = N, XPToLevelBase = N, XPToLevelStep = N,
		RareStatBonus = I, HealthBase = N, HealthPerGrit = N, MedbayHealPerCycle = N,
		AutoAssignOrder = list(Check.ref("Rooms"), 21), MealSeconds = S, WalkSpeedBase = N, WalkSpeedPerSpeed = N,
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
		Grid = { -- Section 6; walls (the A0 kit's) and where the grid sits in the Run place are ours
			ColumnMin = -6, ColumnMax = 6, FloorMin = 1, FloorMax = 10,
			CellWidth = 32, CellHeight = 16, CellDepth = 32, SlabThickness = 2, WallThickness = 1, SourceFloor = 10,
			Origin = { X = 0, Y = -120, Z = 0 }, -- the interior floor centre of floor 1, column 0
		},
		StartingBunker = { -- Section 6 and its diagram: the shafts in the middle column (0), rock at -3
			Cells = {
				{ Floor = 1, Column = -2, Room = "BlastDoor", Span = 2 },
				{ Floor = 1, Column = 0, Room = "Shaft" },
				{ Floor = 1, Column = 1, Room = "Quarters", Span = 2 },
				{ Floor = 1, Column = 3, Dug = true },
				{ Floor = 2, Column = -2, Room = "Kitchen" },
				{ Floor = 2, Column = -1, Room = "WaterPurifier" },
				{ Floor = 2, Column = 0, Room = "Shaft" },
				{ Floor = 2, Column = 1, Room = "ReactorCore" },
				{ Floor = 2, Column = 2, Room = "Medbay" },
				{ Floor = 2, Column = 3, Dug = true },
			},
			Residents = 6,
			ResidentLevels = { Min = 1, Max = 3 },
			ResidentTier = "Common",
		},
		Rooms = { -- Section 6; build helpers, repair and dark-room morale prov.
			WorkerSlotsPerCell = { 2, 3, 4 }, HP = { 500, 800, 1200 }, LevelMultiplier = { 1, 1.5, 2 },
			MergeMultiplier = { 1, 1.1, 1.2 }, BuildSecondsPerCell = 20, HelperBuildSpeed = 0.25,
			ResidentRepairPerSecond = 2, DarkSpawnMultiplier = 2, DarkMoralePerCycle = -5,
			-- Landon, 2026-11-08: tearing a room down gives part of its cost back (half, prov.)
			TearDownRefund = 0.5,
			PowerWarnAt = 0.85, -- prov.: the HUD's power lamp turns amber past this share of the power made
		},
		Votes = { -- Section 8
			TiesFail = true, BigSpendFraction = 0.4, OpenProposalsPerPlayer = 1, FailedCooldownSeconds = 20,
			PassEarlyWhenAllYes = true, SoloSkipsVotes = true, RecheckCostsOnPass = true,
			ResultSeconds = 3, -- prov.: how long the banner shows PASSED or FAILED
		},
		Player = { -- Section 9; stamina costs, radiation drain, aim assist and Medkit heal prov.
			Health = 100, Stamina = 100, SprintStaminaPerSecond = 12, DodgeStamina = 20, HeavySwingStamina = 20,
			StaminaRegenPerSecond = 18, RadiationMax = 100, RadiationHealthDrainPerSecond = 2,
			Loadout = { Guns = 2, Melee = 1, Tool = 1, Throwables = 2, Medkits = 3 },
			BackpackSlots = 10, AimFieldOfView = { 70, 50 }, DownedSeconds = 20, ReviveSeconds = 3,
			RespawnSeconds = 15, AimAssistDegrees = 6, MedkitHeal = 60,
			MedkitSeconds = 1.5, HealWalkMultiplier = 0.6, -- Landon, 2026-11-08: the Heal button uses one Medkit over 1.5 s
		},
		Combat = { -- Section 23 (the server checks shots against where targets were over the last 250 ms); the rest prov.
			LagSeconds = 0.25, HistorySeconds = 1, HistoryHz = 20, HitTolerance = 2.5, RayTolerance = 1.5,
			OriginTolerance = 8, RateTolerance = 0.15,
			SprintMultiplier = 1.45, StaminaRegenDelay = 0.8,
			DodgeSeconds = 0.45, DodgeInvulnerableSeconds = 0.35, DodgeDistance = 14, DodgeCooldownSeconds = 0.6,
			MeleeReach = 6, MeleeArcDegrees = 110, MeleeReachTolerance = 2, MeleeWindupFraction = 0.4,
			ComboWindowSeconds = 0.6, ComboSteps = 3, HeavyChargeSeconds = 0.35, HeavySwingMultiplier = 1.6,
			CrawlSpeed = 3, ReviveHealthFraction = 0.3,
			CarriedAmmo = { Start = 60, Max = 150 }, RestockSeconds = 1.5,
			ProjectileSpeed = 90, ProjectileGravity = 30, AssistPullPerSecond = 4,
			Unarmed = { Damage = 8, HeavyDamage = 14, SwingSeconds = 0.4 }, -- a fallback: every kit has a melee weapon (Landon, 2026-11-08)
			-- Landon, 2026-11-08: a throwable is thrown with Fire while its slot is held; the gamepad's
			-- D-pad up pings on a tap and heals on a hold (TapHoldSeconds). Numbers provisional.
			ThrowSpeed = 55, ThrowGravity = 60, ThrowCooldownSeconds = 0.8, ThrowableStack = 3, MineArmSeconds = 0.8,
			MineLifetimeSeconds = 120, TapHoldSeconds = 0.35,
		},
		Camera = { -- Section 9 (right shoulder, aim narrows Player.AimFieldOfView, wall fade, zoom capped indoors); numbers prov.
			FieldOfView = 70, PivotHeight = 1.6, ShoulderOffset = 2.2, ShoulderRaise = 0.3,
			Distance = { Min = 4, Max = 16, Default = 9 }, IndoorMax = 11, AimDistance = 6, AimShoulder = 1.25,
			PitchMin = -70, PitchMax = 60, StartPitch = -12,
			MouseDegreesPerPixel = 0.22, TouchDegreesPerPixel = 0.3, GamepadDegreesPerSecond = 220, StickDeadzone = 0.15,
			AimSensitivity = 0.6, AimWalkSpeed = 0.6, ZoomStep = 1.5, PinchStudsPerPixel = 0.04,
			CollisionRadius = 0.6, WallMargin = 0.25, FloorMargin = 1.2, CeilingMargin = 1.9, NearestDistance = 0.8,
			EaseOutPerSecond = 6, PivotFollowPerSecond = 18, ShoulderSwapSeconds = 0.18, AimBlendSeconds = 0.15,
			FadeTransparency = 0.8, FrontWallTransparency = 1, FadeSeconds = 0.12, NearFadeRadius = 1.4,
			CharacterFadeDistance = 2.2, ErrorsBeforeFallback = 5,
		},
		CommandView = { -- Section 7 (a far camera with a narrow field of view, a 0.3 s move in and out); the rest prov.
			-- MaxDistance: at the lowest graphics level Roblox stops drawing parts about 500 studs from
			-- the camera (measured in Studio, 2026-11-08), so the camera never backs off further; past
			-- it the field of view widens instead (Rules.CommandView.Lens).
			FieldOfView = 8, MaxDistance = 440, StartFloors = 6, MinFloors = 1.5, MaxFloors = 11, MoveSeconds = 0.3, ZoomStep = 0.12,
			PanFloorsPerSecond = 2.5, DragPixels = 6, StickDeadzone = 0.2,
			Ambient = "#6E7680", OutdoorAmbient = "#8C949E", ExposureCompensation = 0.4,
		},
		Ping = { Seconds = 6 }, -- Section 7: a pinged cell shows on every player's mini-map; prov.
		Digging = { -- Section 6 (dig times are Config.DepthBands' DigSeconds), Section 10 (Disturbance)
			DisturbancePerCell = 5, StackPlayers = true, PushDeeperFloors = { 4, 7, 10 }, ResidentDigMultiplier = 0.25,
			-- Prompt 14, prov. A Drill or a Pickaxe digs; a dig prompt answers within PromptReach. A Drill
			-- Bay digs the queue at ResidentDigMultiplier of a player's speed for each unit of its crew's
			-- output (two average workers are one unit). A dug cell's passage caves in CaveInChance of the
			-- time (Section 10: digging causes cave-ins). A nest: NestHealth, NestBudget of the threat
			-- level in monsters pouring out when it opens, NestPerCycle Disturbance each cycle it lives
			-- (Section 10: nests left alive raise it). A cache opens after CacheOpenSeconds of holding
			-- Interact. A failed Push Deeper vote can be asked again after VoteRetrySeconds.
			Tools = { "Drill", "Pickaxe" }, PromptReach = 8, TickSeconds = 0.25, CaveInChance = 0.05,
			NestHealth = 600, NestBudget = 0.5, NestPerCycle = 10, CacheOpenSeconds = 1, VoteRetrySeconds = 30,
		},
		Disturbance = { -- Section 10
			Max = 100, DecayPerCycle = 10, NestDestroyed = 20, Explosive = 10, ExtraBreachAt = 50, TremorAt = 100, AfterTremor = 40,
		},
		Threat = { -- Section 10 lists the inputs; weights prov. First-run Era I is 30% easier (Section 22)
			Base = 12, PerYear = 1.2, PerDeepestFloor = 4, PerDisturbance = 0.25, PerRoom = 1,
			PlayerScale = { 1, 1.6, 2.1, 2.5, 2.8, 3 }, BetweenSurgesFraction = 0.1, BreachWarningSeconds = 10,
			TutorialSurgeBudget = 6, FirstRunEraIMultiplier = 0.7,
			-- Prompt 12: Section 23's cap of 25 monsters (the rest queue); a Surge's groups open
			-- WaveSpacingSeconds apart, each after its BreachWarningSeconds; dark rooms' vents are
			-- picked DarkRoomWeight times as often (Section 6: dark rooms spawn monsters twice as
			-- often); a barricaded point less often (Section 10). Spacing and counts provisional.
			MaxMonsters = 25, WaveSpacingSeconds = 14, SpawnSpacingSeconds = 0.45, TrickleCheckSeconds = 15,
			DarkRoomWeight = 2, BarricadeWeight = 0.25, MaxBreachPointsPerSurge = 3,
		},
		Disasters = { -- Prompt 13 (Section 10's disasters; each disaster's own numbers are in Config.Disasters); prov.
			-- The Surge's one disaster starts SurgeDelaySeconds into the Surge; a fuse box resets after
			-- FuseSeconds of holding Interact, a valve turns after ValveSeconds.
			TickSeconds = 0.25, SurgeDelaySeconds = 8, FuseSeconds = 2, ValveSeconds = 1,
			-- Fire (Section 10: spreads to the next room every 15 s, burning room HP and residents; put out
			-- by an Extinguisher, a Foam Grenade, or residents in the room). Strength runs 0 to 100: it
			-- starts at StartStrength and grows; residents in the room beat it down ResidentPerSecond each,
			-- an Extinguisher ExtinguisherPerSecond (the Firefighter 3x); at 0 it is out. A fire weaker
			-- than SpreadMinStrength doesn't spread. Damage scales with strength. Fires stay on their floor:
			-- the Shaft's bare steel doesn't burn. Residents fight it until their health falls below
			-- ResidentFleeHealth, then flee.
			Fire = {
				StartStrength = 40, GrowPerSecond = 1, SpreadMinStrength = 30,
				ResidentPerSecond = 2, ExtinguisherPerSecond = 14, ExtinguisherReach = 16,
				PlayerDamagePerSecond = 5, ResidentDamagePerSecond = 3, ResidentFleeHealth = 0.4,
				Fireproof = { "Shaft" },
			},
			Blackout = { WholeGridChance = 0.3 }, -- Section 10: a floor or the whole grid
			-- Cave-in (Section 10: rubble blocks a doorway or cell and can trap residents; dig or smash
			-- through it). Melee smashes it (BreaksRubble weapons, the Fire Axe and Sledgehammer, do
			-- BreakerMultiplier times their damage); a Drill or a Pickaxe digs through it in one hold.
			CaveIn = {
				DoorwayHP = 300, TunnelHP = 600, BreakerMultiplier = 3, DigSeconds = 5, TunnelDigSeconds = 8, Damage = 15,
				DigItems = { "Drill", "Pickaxe" },
			},
			-- The meltdown (Section 10's Reactor overload; Landon, 2026-11-08): the three valves turned
			-- together stop it. With SoloPlayers or fewer each turned valve stays turned SoloValveSeconds;
			-- with more, a valve counts while its player holds it (HeldGraceSeconds of slack for the
			-- network). Section 10: a Reactor overload causes a fire (StartsFire).
			Meltdown = { SoloPlayers = 2, SoloValveSeconds = 10, HeldGraceSeconds = 0.6, StartsFire = true },
			-- Electrical surges (Section 10: random, more often in Era III; they cause fires and blackouts):
			-- a day's chance by era; an unwelded one may end in a fire or a blackout of its floor.
			ElectricalSurge = { EraChance = { 0.2, 0.25, 0.45, 0.35 }, FireChance = 0.3, BlackoutChance = 0.25 },
		},
		Repairs = { -- Prompt 13 (Section 6: a wrecked room stops until repaired with the Welder; residents slowly
			-- repair the room they work in; Section 11: Smarts is repair speed). prov.
			-- A wrecked room works again once it is back to RepairedAt of its HP. The Welder repairs
			-- the room it points at, WelderPerSecond (the Engineer twice as fast); a worker repairs
			-- Tuning.Rooms.ResidentRepairPerSecond, scaled by Smarts over ResidentSmartsBase.
			RepairedAt = 0.25, WelderPerSecond = 25, WelderReach = 10, ResidentSmartsBase = 5, ToolTickSeconds = 0.1,
		},
		MonsterAI = { -- Prompt 12 (Section 10: residents first, then machines, then players who hit them); prov.
			-- Playtest, Nov 8: one Hollow Miner wrecked a 500-HP room in 12 s at full damage, and three
			-- latched ticks downed a resident in 5 s; rooms now take half a monster's damage (the Hollow
			-- Miner 1.25x that) and a latched tick bites at 0.4x, half as often.
			TickSeconds = 0.2, AggroSeconds = 10, ProximityAggro = 9, SmashMultiplier = 1.25, StuckSeconds = 2.5,
			RoomDamageMultiplier = 0.5, LatchDamageMultiplier = 0.4, LatchIntervalMultiplier = 2,
			KeepDistanceFraction = 0.7, GooSpeed = 60, GooSlowSeconds = 3, GooSlowMultiplier = 0.6, WindupFraction = 0.45,
			-- Section 11: the unarmed flee to the nearest safe room; a lone Burrow Tick they swat themselves
			ResidentFleeRadius = 22, ResidentCalmSeconds = 6, ResidentSwatDamage = 6, ResidentSwatSeconds = 1,
		},
		Residents = { -- Section 11; needs and experience prov.
			StatMin = 1, StatMax = 10, StatCap = 15, LevelMax = 20, MoraleStart = 60, FoodPerCycle = 1, WaterPerCycle = 1,
			ShortfallHealth = 10, ShortfallMorale = 10, RestDrainPerShift = 60, RestRefillPerCycle = 100,
			NoBedRestMultiplier = 0.4, FriendsMax = 3, FriendThreshold = 100, GrievingMorale = 20, GrievingCycles = 2,
			SurgeSurvivedMorale = 5, DeathReviveSeconds = 20, XPPerWorkCycle = 30, XPPerKill = 5,
			XPPerExpeditionCycle = 40, XPToLevelBase = 100, XPToLevelStep = 40, RareStatBonus = 2,
			-- Prompt 10, prov.: max health = HealthBase + Grit x HealthPerGrit (Grit 5: 100); a staffed, lit
			-- Medbay heals every hurt resident this much a cycle; Auto-Assign fills rooms in this order
			-- (power first, so the lights stay on), then any other room with a job
			HealthBase = 70, HealthPerGrit = 6, MedbayHealPerCycle = 20,
			AutoAssignOrder = { "ReactorCore", "Generator", "WaterPurifier", "Kitchen", "Medbay", "Greenhouse",
				"Armory", "Workshop", "Lab", "DrillBay", "RadioRoom", "Lounge", "DeconRoom", "CryoBay", "TradingPost",
				"BlastDoor" },
			-- the routine (Section 11: work a shift, eat at the Kitchen, rest in Quarters), prov.: the first
			-- MealSeconds of each day at the Kitchen, the rest of the day at work, the Surge in bed; walking
			-- speed grows with Speed (Section 11: Speed affects moving)
			MealSeconds = 20, WalkSpeedBase = 8, WalkSpeedPerSpeed = 0.6,
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
