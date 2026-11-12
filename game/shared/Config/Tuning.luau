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
	Cutscene = shape({
		SetOrigin = shape({ X = F.Number, Y = F.Number, Z = F.Number }),
		BarFraction = Fr, FadeInSeconds = S, PreloadSeconds = S, LateJoinSeconds = S, KeepSetSeconds = S,
		DoorShake = N, WaveShake = N, WaveShakeSeconds = S, PlungeShake = N,
		AvatarSeconds = S, SkipHoldSeconds = S,
	}),
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
	-- Prompt 15: boss fights in general, the Brood Mother's, and the results screen
	Bosses = shape({
		ArrivalWarningSeconds = S, RiseSeconds = S, FirstRunHealth = Fr, ArmourMultiplier = Fr, WeakPointMultiplier = N,
		WeakPointTolerance = N, PublishSeconds = S, DeathSeconds = S, TickSeconds = S,
	}),
	BroodMother = shape({
		MoveSpeed = list(N, 4), AttackSeconds = list(S, 4), SlamDamage = N, SlamRadius = N, SlamReach = N,
		LaySeconds = list(S, 4), SacsPerLay = list(I, 4), MaxSacs = I, SacHealth = N, HatchSeconds = S, HatchCount = I,
		BurnMultiplier = N, StaggerFraction = Fr, StaggerWindowSeconds = S, StaggerSeconds = S, RoarSeconds = S,
		ArenaMargin = N, TurnDegreesPerSecond = N,
	}),
	CrystalColossus = shape({
		MoveSpeed = list(N, 3), AttackSeconds = list(S, 3), SlamDamage = N, SlamRadius = N, SlamReach = N,
		VolleySeconds = list(S, 3), Shards = list(I, 3), ShardWarnSeconds = S, ShardDamage = N, ShardRadius = N,
		StunSeconds = S, VolleyRange = N, Shardlings = list(I, 3), MaxShardlings = I, ArmourMultiplier = Fr, LitSeconds = S, FlashSeconds = S,
		StaggerFraction = Fr, StaggerWindowSeconds = S, StaggerSeconds = S, RoarSeconds = S, ArenaMargin = N,
		TurnDegreesPerSecond = N, EmergeSeconds = S,
	}),
	Source = shape({
		Stages = list(Check.enum({ "Tendrils", "Core" }), 4), StageUntil = list(Fr, 4),
		Tendrils = list(I, 4), TendrilsPerPlayer = I, TendrilsMax = I, ChamberTendrils = list(I, 4),
		TendrilHealth = N, TendrilDamage = N, TendrilResidentDamage = N, TendrilRadius = N, TendrilReach = N, TendrilSense = N, TendrilAttackSeconds = S,
		TendrilRoomDamage = N, TendrilTurnDegreesPerSecond = N, TendrilRiseSeconds = S, TendrilRiseDepth = N,
		RegrowSeconds = list(N, 4), RegrowMax = I,
		ClosedMultiplier = Fr, AttackSeconds = list(S, 4), SlamDamage = N, SlamRadius = N, SlamReach = N,
		EruptSeconds = list(N, 4), Eruptions = list(I, 4), EruptWarnSeconds = S, EruptDamage = N, EruptRadius = N, EruptRange = N,
		Breaches = list(I, 4), StaggerFraction = Fr, StaggerWindowSeconds = S, StaggerSeconds = S, RoarSeconds = S,
		OpenSeconds = S, CloseSeconds = S, ArenaMargin = N, TurnDegreesPerSecond = N, WakeRange = N, LeaveSeconds = S,
	}),
	Deluge = shape({
		SwimSpeed = list(N, 4), SwimSeconds = list(S, 4), SurfaceSeconds = list(S, 4), SurfaceRiseSeconds = S, DiveSeconds = S,
		AttackSeconds = list(S, 4), BiteDamage = N, BiteRadius = N, BiteReach = N, Murklings = list(I, 4),
		FloodLevel = N, SubmergedMultiplier = Fr, SwimDepth = N, StaggerFraction = Fr, StaggerWindowSeconds = S,
		StaggerSeconds = S, RoarSeconds = S, ArenaMargin = N, TurnDegreesPerSecond = N, AloneSeconds = S,
	}),
	Results = shape({
		OpenDelaySeconds = S, VictoryDelaySeconds = S, StoriesMax = I,
		MVP = shape({ Damage = N, Kills = N, Revives = N, CellsDug = N, Repairs = N, BossDamage = N, Hauled = N, Rescues = N }),
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
		Flood = shape({
			StartLevel = N, RisePerSecond = N, OverflowStartLevel = N, OverflowPerSecond = N, DrainPerSecond = N,
			SpreadMinLevel = N, WadeLevel = N, WadeSpeed = Fr, DeepSpeed = Fr,
			PlayerDamagePerSecond = N, ResidentDamagePerSecond = N, ResidentFleeLevel = N,
			PatchSeconds = S, BurstLevel = N, WaterHeight = Fr, MurklingLevel = N,
		}),
		Gas = shape({
			StartStrength = N, FillPerSecond = N, ClearPerSecond = N,
			PlayerDamagePerSecond = N, ResidentDamagePerSecond = N, ResidentFleeStrength = N,
			SealSeconds = S,
		}),
		HazardPocket = shape({ GasChance = Fr, Damage = N }),
		-- Prompt 24
		Radiation = shape({
			StartStrength = N, FillPerSecond = N, FadePerSecond = N, PlayerPerSecond = N, ResidentDamagePerSecond = N,
			ResidentFleeStrength = N, IrradiateAt = N, SealSeconds = S, DeconSlow = Fr, DoorLeakChance = list(Fr, 3),
			DoorDamagedChance = Fr, PocketStrength = N, FromEra = I,
		}),
		Outbreak = shape({
			SpreadSeconds = S, SpreadChance = Fr, CureSeconds = S, CarrierChance = Fr, FromEra = I, MoraleNow = F.Number,
		}),
	}),
	Repairs = shape({ RepairedAt = Fr, WelderPerSecond = N, WelderReach = N, ResidentSmartsBase = N, ToolTickSeconds = S }),
	MonsterAI = shape({
		TickSeconds = S, AggroSeconds = S, ProximityAggro = N, SmashMultiplier = N, StuckSeconds = S, KeepDistanceFraction = Fr,
		RoomDamageMultiplier = N, LatchDamageMultiplier = N, LatchIntervalMultiplier = N,
		GooSpeed = N, GooSlowSeconds = S, GooSlowMultiplier = Fr, WindupFraction = Fr,
		ResidentFleeRadius = N, ResidentCalmSeconds = S, ResidentSwatDamage = N, ResidentSwatSeconds = S,
		-- Prompt 16: the surface
		SurfaceAggro = N, PathSeconds = S, CircleRadius = N, CircleSeconds = F.Range, ShotAccuracy = Fr,
		-- Prompt 23: the Flooded Caverns' monsters
		BurstRadius = N, BurstSwellSeconds = S, HideSeconds = S, AmbushReach = N, RevealSeconds = S,
		GrabBreakDamage = N, GrabBreakStun = S, GrabDamageMultiplier = N,
		ArmorFront = Fr, ArmorArcDegrees = N, WeakBack = N, WeakArcDegrees = N,
		ShellTurnDegreesPerSecond = N, ShellFaceDegrees = N,
		-- Prompt 24: the Crystal Hollows' monsters
		ShatterRadius = N, ShatterDamage = N, StalkerRevealSeconds = S, LightHeight = N, SmallGunMultiplier = Fr,
		HumHealFraction = Fr, HasteMultiplier = N, HasteSeconds = S, HumFollow = N,
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
		-- Prompt 18
		HurtChance = Fr, Danger = Check.map(Check.enum({ "Surface", "Deep" }), N, 2),
		StatPivot = N, StatStep = N, RiskMin = N, RiskMax = N, HurtShare = F.Range, MedkitsMax = I, MedkitHurtKept = Fr,
		CarryBase = N, CarryPerStrength = N, CallDelay = F.Range, UseRange = N, LeaveSeconds = S,
		RecruitRareChance = Fr, RecruitLevel = F.Range, RecruitsMax = I,
		RadioRareChance = Fr, RadioLevel = F.Range, RadioHintCycles = I, FastSpeed = N,
	}),
	Surface = shape({
		StormSirenSeconds = S, RadiationPerSecond = N, StormRadiationPerSecond = N, RefillEvery = Check.enum({ "Era" }),
		-- Prompt 16
		ZoneY = F.Number, TickSeconds = S, RadiationWarnAt = Fr, WraithRadiationPerHit = N, DeconPerSecond = N,
		PillUseAt = N, PillsMax = I, ElevatorHoldSeconds = S, FadeSeconds = S, EscortRange = N,
		SearchSeconds = S, Stacks = Check.map(Check.ref("Resources"), I, 9), ItemStack = I,
		CarryWalkMultiplier = Fr, TeamCarryWalkMultiplier = Fr, HelpRange = N, PickUpSeconds = S,
		BigFindChancePerDay = Fr, MaxBigFinds = I, BigFindLoot = Check.ref("LootTables"),
		FreeSeconds = S, SurvivorChancePerDay = Fr, MaxTrapped = I, RareSurvivorChance = Fr, SurvivorLevel = F.Range,
		SurvivorHealth = I, FollowDistance = N, SurvivorWalkSpeed = N,
		MaxMonsters = I, SpawnDistance = F.Range, JackalEverySeconds = F.Range, RaiderEverySeconds = F.Range,
		RaiderMinEra = Check.integer(1, 4), RaiderMeleeShare = Fr, WraithEverySeconds = F.Range, WraithDistance = F.Range, DespawnSeconds = S,
	}),
	Deep = shape({ -- Prompt 17
		CavePieces = F.Range, PlannerTries = I, Margin = N, GridBack = F.Number, LowestY = F.Number,
		FindOdds = Check.map(Check.string(20), N, 12), NestChance = Fr, GuardChance = Fr, GuardBudget = N,
		WakeRange = N, GuardRange = N, DeepAggro = N, MineSeconds = S, OpenSeconds = S, ListenSeconds = S, ChestSeconds = S,
		FallDamageFrom = N, FallDamagePerStud = N, FallDamageMax = N, LightRange = N, LightBrightness = N,
		LampRange = N, LampBrightness = N,
		ThawPoints = N, LegendaryChance = Fr, CryoLevel = F.Range, MinerRareChance = Fr, MinerLevel = F.Range,
		CrewLevel = F.Range, CrewFloors = Check.map(Check.ref("DepthBands"), F.Range, 4), CrewMinDepth = I,
		CaveRadiationPerSecond = Check.map(Check.ref("DepthBands"), N, 4),
		HintChance = Fr, NestBudget = N, RevealRange = N, CampWakeRange = N, CampSleepSeconds = S,
	}),
	Draft = shape({ -- Prompt 19
		Cards = I, FoundPerDraft = I, RerollRestartsTimer = Check.boolean(), OverloadDelay = F.Range,
		BountyAlertEvery = I, StormEarlyWarnSeconds = S,
	}),
	Classes = shape({ -- Prompt 20
		XPPerYear = N, TypicalRunYears = N, LevelMax = I, HoldSeconds = S, AimRange = N,
		OwnCooldownClasses = Check.map(Check.ref("Classes"), Check.boolean(), 19),
		SecondWindFraction = Fr,
		Turret = shape({ Range = N, Damage = N, FireSeconds = S, ShockSeconds = S, ShockEvery = I, PlaceDistance = N }),
		TouchHealRange = N, TouchHealPerSecond = N, TriageRadius = N, TriageHeal = N,
		FoamRange = N, MealHealFraction = Fr,
		TauntRadius = N, HoldDamageTaken = Fr, NearbyResidentRange = N,
		FlareRadius = N,
		RequisitionScrap = I, RequisitionFoodWater = I,
		CrateDistance = N, CrateLoot = Check.ref("LootTables"),
		DeconRadius = N,
		Napalm = shape({ Length = N, Width = N, DamagePerSecond = N }),
		Burn = shape({ Seconds = S, DamagePerSecond = N, SpreadRadius = N }),
		KillDisturbance = N,
		SteadyShots = I, CritMultiplier = N,
		OverdriveCells = I,
		MagnetRadius = N,
		RallyFloors = I, RallyDamage = N, RallyReach = N,
		Breaching = shape({ Damage = N, Radius = N, Range = N }),
		Grapple = shape({ Range = N, Speed = N }),
		Trap = shape({ Radius = N, StunSeconds = S, Seconds = S }),
		BeaconSeconds = S,
		GravityWell = shape({ Radius = N, Seconds = S, Pull = N }),
		Drone = shape({
			Range = N, Damage = N, FireSeconds = S, GuardDamageTaken = Fr, AssaultMultiplier = N, RepairPerSecond = N,
			RepairRange = N, PickupRange = N, ReviveSeconds = S,
		}),
		BossStunCooldown = S, ArcChainRange = N, ArcChainFalloff = Fr,
	}),
	Legends = shape({ StartLevel = I, RenownMax = I, RenownStatBonus = I, StarterLegend = Check.ref("Legends") }),
	ClassShop = shape({
		Slots = I, ResetHourUTC = I, FreeRerolls = I, VIPFreeRerolls = I, RerollRobux = I, WishlistDays = I,
		FreeTrialRunsPerDay = I, RerollProductId = Check.optional(F.PositiveInt), ClassLevelRuns = list(I, 2),
	}),
	Account = shape({ LevelMax = I, XPPerYear = N, XPToLevelBase = N, XPToLevelStep = N, VIPGlowshardBonus = N }),
	Lobby = shape({
		PadCountdownSeconds = S, PartyMax = I, SoloCountdownSeconds = S, PrivateInvites = I, LaunchRetrySeconds = S,
		RecordSeconds = N, RejoinStartSeconds = S, RejoinSeconds = S, RejoinRefreshSeconds = S,
	}),
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
		Cutscene = { -- Section 4 (its length and the skip rule are Clock.IntroSeconds and IntroSkipAfterSeconds); the rest prov.
			-- Where the set is put up: far above the run's world, over the bunker, where only the
			-- cutscene's camera goes. Its own ground hides everything below it.
			SetOrigin = { X = 0, Y = 1400, Z = 0 },
			BarFraction = 0.11, -- each letterbox bar's share of the screen's height
			-- The picture comes up out of black over FadeInSeconds, or when the set's meshes have
			-- loaded if that takes longer, but never later than PreloadSeconds.
			FadeInSeconds = 0.9, PreloadSeconds = 3,
			LateJoinSeconds = 3, -- arriving with less than this left: no cutscene, straight to the character
			KeepSetSeconds = 10, -- the server keeps the set for the clients this long into the run
			DoorShake = 0.35, WaveShake = 1.8, WaveShakeSeconds = 1.5, PlungeShake = 0.1, -- studs the camera is thrown about
			AvatarSeconds = 4, -- how long a party member's avatar may take to arrive before their stand-in runs instead
			SkipHoldSeconds = 0, -- 0: one press skips (Landon may want a hold)
		},
		Digging = { -- Section 6 (dig times are Config.DepthBands' DigSeconds), Section 10 (Disturbance)
			DisturbancePerCell = 5, StackPlayers = true, PushDeeperFloors = { 4, 7, 10 }, ResidentDigMultiplier = 0.25,
			-- Prompt 14, prov. A Drill or a Pickaxe digs; a dig prompt answers within PromptReach. A Drill
			-- Bay digs the queue at ResidentDigMultiplier of a player's speed for each unit of its crew's
			-- output (two average workers are one unit). A dug cell's passage caves in CaveInChance of the
			-- time (Section 10: digging causes cave-ins). A nest: NestHealth, NestBudget of a normal
			-- Surge's budget in monsters pouring out when it opens, NestPerCycle Disturbance each cycle it lives
			-- (Section 10: nests left alive raise it). A cache opens after CacheOpenSeconds of holding
			-- Interact. A failed Push Deeper vote can be asked again after VoteRetrySeconds.
			Tools = { "Drill", "Pickaxe" }, PromptReach = 8, TickSeconds = 0.25, CaveInChance = 0.05,
			NestHealth = 600, NestBudget = 0.35, NestPerCycle = 10, CacheOpenSeconds = 1, VoteRetrySeconds = 30,
		},
		Disturbance = { -- Section 10
			Max = 100, DecayPerCycle = 10, NestDestroyed = 20, Explosive = 10, ExtraBreachAt = 50, TremorAt = 100, AfterTremor = 40,
		},
		Bosses = { -- Prompt 15, prov. (Section 10's boss table; Section 22: the first run's Brood Mother is weaker)
			-- A boss Surge's boss breaks in ArrivalWarningSeconds after the Surge starts (cracks, dust, an
			-- alert) and rises out of the floor over RiseSeconds. Its health is Config.Bosses' Health times
			-- Threat.PlayerScale for the team, times FirstRunHealth on an account's first run. Hits on its
			-- armour do ArmourMultiplier; hits within WeakPointTolerance of a WeakPoint part do
			-- WeakPointMultiplier (the Sharpshooter's WeakPointMultiplier replaces it). Its bar updates
			-- every PublishSeconds; dead, it collapses for DeathSeconds before it dissolves.
			ArrivalWarningSeconds = 8, RiseSeconds = 2, FirstRunHealth = 0.7, ArmourMultiplier = 0.5, WeakPointMultiplier = 2,
			WeakPointTolerance = 1, PublishSeconds = 0.25, DeathSeconds = 4, TickSeconds = 0.1,
		},
		BroodMother = { -- Section 10: lays egg sacs that hatch Burrow Ticks; break or burn the sacs and hit her
			-- glowing belly. Prompt 15, prov. Lists are by phase (Config.Bosses' Phases: 2, the second
			-- from half health). She slams whoever is within SlamReach of her front (SlamDamage within
			-- SlamRadius of the blow), every AttackSeconds; every LaySeconds she lays SacsPerLay egg sacs
			-- behind her (MaxSacs at once). A sac has SacHealth (fire does BurnMultiplier) and hatches
			-- HatchCount Burrow Ticks after HatchSeconds. StaggerFraction of her health dealt to her belly
			-- within StaggerWindowSeconds staggers her for StaggerSeconds. She roars RoarSeconds as she
			-- arrives and as her second phase starts. She stays ArenaMargin from her arena's ends and
			-- turns TurnDegreesPerSecond, slower than a player circling her (so her flanks and belly
			-- can be reached); SlamReach covers her whole cell, so nowhere in front of her is safe.
			MoveSpeed = { 5, 7 }, AttackSeconds = { 3.2, 2.4 }, SlamDamage = 30, SlamRadius = 9, SlamReach = 18,
			LaySeconds = { 16, 10 }, SacsPerLay = { 1, 2 }, MaxSacs = 6, SacHealth = 90, HatchSeconds = 14, HatchCount = 3,
			BurnMultiplier = 2, StaggerFraction = 0.05, StaggerWindowSeconds = 3, StaggerSeconds = 2.5, RoarSeconds = 2.5,
			ArenaMargin = 10, TurnDegreesPerSecond = 60,
		},
		CrystalColossus = { -- Section 10: "Tears out of the crystal rock. Huge, slow and armored; flares
			-- show its weak points; its shards stun." Prompt 24, prov. Lists are by phase (Config.Bosses'
			-- Phases: 3). It strides out of the rock at the back of its arena over EmergeSeconds and walks
			-- its arena at MoveSpeed, turning TurnDegreesPerSecond. Every hit does ArmourMultiplier
			-- unless its cores are lit: by a flare or a lamp (for as long as the light lasts), by the
			-- Scout's Flare Ping (LitSeconds), or by its own charge (FlashSeconds as it throws its
			-- shards, so a team with no flare still has an opening). Lit, a hit on a core does the
			-- weak point's multiplier. It slams whoever is within SlamReach of its front every
			-- AttackSeconds (SlamDamage within SlamRadius). Every VolleySeconds it throws Shards crystal
			-- shards at survivors within VolleyRange: each lands ShardWarnSeconds after its mark shows,
			-- for ShardDamage and a stun of StunSeconds within ShardRadius, and from its second phase
			-- Shardlings crawl out of the broken shards (never more than MaxShardlings of its own alive
			-- at once: the playtest's fight reached 12 in 40 s without it). StaggerFraction of its health dealt to lit
			-- cores within StaggerWindowSeconds drops it for StaggerSeconds.
			MoveSpeed = { 3, 3.5, 4.5 }, AttackSeconds = { 4.5, 4, 3.2 }, SlamDamage = 45, SlamRadius = 10, SlamReach = 16,
			VolleySeconds = { 11, 9, 7 }, Shards = { 2, 3, 4 }, ShardWarnSeconds = 1.2, ShardDamage = 15, ShardRadius = 6,
			StunSeconds = 1.5, VolleyRange = 70, Shardlings = { 0, 2, 4 }, MaxShardlings = 8, ArmourMultiplier = 0.2, LitSeconds = 10, FlashSeconds = 2.5,
			StaggerFraction = 0.04, StaggerWindowSeconds = 4, StaggerSeconds = 3.5, RoarSeconds = 2.6, ArenaMargin = 9,
			TurnDegreesPerSecond = 35, EmergeSeconds = 3,
		},
		Source = { -- Section 10: "Rises into the bunker, or is fought earlier in its chamber at depth 10.
			-- Several phases: tendrils in many rooms at once, then the core, so the team has to split up
			-- and regroup." Prompt 25, prov. Lists are by stage (Config.Bosses' Phases: 4): Stages says
			-- what each is. In a Tendrils stage its eye is shut (hits on it do ClosedMultiplier) and
			-- Tendrils of them (TendrilsPerPlayer more for each player after the first, at most
			-- TendrilsMax) stand in rooms all over the bunker; in its chamber ChamberTendrils of them
			-- rise round it instead. Each tendril cut down takes an even share of the health between the
			-- stage's start and StageUntil off the Source, so the last one ends the stage. A tendril
			-- (TendrilHealth, scaled like the Source's for the team) rises over TendrilRiseSeconds, turns
			-- (TendrilTurnDegreesPerSecond) to whoever comes within TendrilSense and slams every
			-- TendrilAttackSeconds: TendrilDamage within TendrilRadius of the blow when someone is within
			-- TendrilReach (TendrilResidentDamage to a resident: the first playtest's three tendrils,
			-- left alone, downed four of six in four minutes at a player's 22), else TendrilRoomDamage to
			-- its room (10: a 500 HP room is wrecked in under three minutes, not one and a half). In a Core stage its eye opens (the weak
			-- point; the rest of it is armour) until its health reaches StageUntil: it slams whoever is
			-- within SlamReach of its front every AttackSeconds (SlamDamage within SlamRadius), and every
			-- EruptSeconds Eruptions roots burst up under survivors within EruptRange, EruptWarnSeconds
			-- after their mark shows, for EruptDamage within EruptRadius. In a stage with RegrowSeconds it
			-- grows a tendril back that often (never more than RegrowMax standing; those take nothing off
			-- it). A stage with Breaches opens that many extra breaches as it starts. StaggerFraction of
			-- its health dealt to its eye within StaggerWindowSeconds drops it for StaggerSeconds. It
			-- turns TurnDegreesPerSecond and never walks. In its chamber it sleeps until someone comes
			-- within WakeRange of it or hurts it; left asleep until Year 100, it leaves the chamber over
			-- LeaveSeconds and rises in the bunker.
			Stages = { "Tendrils", "Core", "Tendrils", "Core" }, StageUntil = { 0.85, 0.5, 0.35, 0 },
			Tendrils = { 3, 0, 5, 0 }, TendrilsPerPlayer = 1, TendrilsMax = 10, ChamberTendrils = { 2, 0, 4, 0 },
			TendrilHealth = 900, TendrilDamage = 22, TendrilResidentDamage = 8, TendrilRadius = 5, TendrilReach = 12, TendrilSense = 30,
			TendrilAttackSeconds = 3.2, TendrilRoomDamage = 10, TendrilTurnDegreesPerSecond = 120, TendrilRiseSeconds = 1.5,
			TendrilRiseDepth = 13, RegrowSeconds = { 0, 0, 0, 14 }, RegrowMax = 2,
			ClosedMultiplier = 0.05, AttackSeconds = { 6, 5, 5, 3.8 }, SlamDamage = 50, SlamRadius = 10, SlamReach = 17,
			EruptSeconds = { 0, 8, 0, 6 }, Eruptions = { 0, 2, 0, 3 }, EruptWarnSeconds = 1.3, EruptDamage = 20, EruptRadius = 5.5,
			EruptRange = 60, Breaches = { 0, 0, 1, 0 }, StaggerFraction = 0.04, StaggerWindowSeconds = 4, StaggerSeconds = 3.2,
			RoarSeconds = 2.6, OpenSeconds = 1.2, CloseSeconds = 1.0, ArenaMargin = 12, TurnDegreesPerSecond = 30, WakeRange = 44,
			LeaveSeconds = 3,
		},
		Deluge = { -- Section 10: "A giant eel surging up the flooded tunnels. Floods every room it passes;
			-- strike its head when it surfaces and drain the rooms behind it." Prompt 23, prov. Lists are
			-- by phase (Config.Bosses' Phases: 3, a new one at each third of its health). It swims under
			-- the floors at SwimSpeed (only its crest shows: SwimDepth under, which suits Boss_Deluge's
			-- Swim clip, whose body tops out 9.5 studs up and whose crest 12.8; hits on it do
			-- SubmergedMultiplier) towards the nearest standing player, for at most SwimSeconds, and every
			-- room it passes bursts a pipe and takes FloodLevel of water. Then it surfaces
			-- (SurfaceRiseSeconds) for SurfaceSeconds, Murklings pouring out with it: its head is its
			-- weak point, and it bites whoever is within BiteReach of it (BiteDamage within BiteRadius of
			-- the bite) every AttackSeconds. StaggerFraction of its health dealt to its head within
			-- StaggerWindowSeconds drops it for StaggerSeconds (and it stays up that much longer). Then
			-- it dives (DiveSeconds), sooner with nobody within twice BiteReach for AloneSeconds. It roars
			-- RoarSeconds as it arrives and at each new phase.
			SwimSpeed = { 14, 17, 21 }, SwimSeconds = { 9, 8, 6 }, SurfaceSeconds = { 12, 10, 8 }, SurfaceRiseSeconds = 1.2,
			DiveSeconds = 1.4, AttackSeconds = { 3, 2.5, 2 }, BiteDamage = 35, BiteRadius = 7, BiteReach = 17,
			Murklings = { 0, 3, 5 }, FloodLevel = 30, SubmergedMultiplier = 0.25, SwimDepth = 10,
			StaggerFraction = 0.04, StaggerWindowSeconds = 3, StaggerSeconds = 3, RoarSeconds = 2.2,
			ArenaMargin = 10, TurnDegreesPerSecond = 80, AloneSeconds = 4,
		},
		Results = { -- Prompt 15, prov. (Section 18: Results; Section 16's payouts are Config.GlowshardRewards)
			-- The screen opens OpenDelaySeconds after the run ends; StoriesMax lines of the run's story.
			-- MVP: a player's score adds each stat times its weight.
			OpenDelaySeconds = 4, VictoryDelaySeconds = 7, StoriesMax = 8, -- a victory's moment (VictoryController) plays first
			MVP = { Damage = 0.1, Kills = 10, Revives = 25, CellsDug = 15, Repairs = 0.05, BossDamage = 0.1, Hauled = 0.3, Rescues = 40 }, -- Hauled, Rescues: Prompt 16
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
			-- Floods (Prompt 23; Section 10: "Water rises in a room and pours down the Shaft"; "Patch the
			-- burst pipe, then the room drains"). A flood's level runs 0 to 100. A burst pipe starts a
			-- room at StartLevel and raises it RisePerSecond until it is patched (hold Interact
			-- PatchSeconds at the pipe). Every Config.Disasters.Flood.SpreadSeconds, water at
			-- SpreadMinLevel or higher pours into one more room: through a doorway on its floor, or down
			-- the Shaft (never up). A room with no pipe of its own is fed by a higher neighbour and
			-- rises OverflowPerSecond towards it; with nothing feeding it, it drains DrainPerSecond
			-- (FloodDrainSpeed multiplies). Below WadeLevel water is ankle deep; from there people wade
			-- (WadeSpeed, down to DeepSpeed at 100) and are hurt, more the deeper it is. Residents leave
			-- a room at ResidentFleeLevel. A Bloat Toad's burst adds BurstLevel (no pipe: it drains).
			-- WaterHeight: how much of a cell's height level 100 fills. Murklings pour out of water at
			-- MurklingLevel or deeper.
			Flood = {
				StartLevel = 15, RisePerSecond = 2.5, OverflowStartLevel = 10, OverflowPerSecond = 1.5, DrainPerSecond = 4,
				SpreadMinLevel = 50, WadeLevel = 25, WadeSpeed = 0.75, DeepSpeed = 0.45,
				PlayerDamagePerSecond = 5, ResidentDamagePerSecond = 3, ResidentFleeLevel = 25,
				PatchSeconds = 3, BurstLevel = 35, WaterHeight = 0.55, MurklingLevel = 30,
			},
			-- Gas leaks (Prompt 23; Section 10: "Poison gas fills a room, hurting everyone inside"; "Seal
			-- the vent or air the room out"). Strength runs 0 to 100: it starts at StartStrength and
			-- fills FillPerSecond while the vent leaks, for Config.Disasters.GasLeak.DurationSeconds
			-- unless someone seals the vent first (hold Interact SealSeconds); after that the room airs
			-- out, ClearPerSecond. Damage scales with strength and the bunker's GasStrength; players
			-- with GasImmune (the Hazmat Tech) take none. Residents leave at ResidentFleeStrength.
			Gas = {
				StartStrength = 20, FillPerSecond = 5, ClearPerSecond = 12,
				PlayerDamagePerSecond = 6, ResidentDamagePerSecond = 4, ResidentFleeStrength = 10,
				SealSeconds = 3,
			},
			-- A hazard pocket found by digging (Section 7: "Gas or water bursts out"): gas in the Mines;
			-- in the bands where both can come, gas GasChance of the time. The burst hurts the digger.
			HazardPocket = { GasChance = 0.5, Damage = 10 },
			-- Radiation leaks (Prompt 24; Section 10: "Surface storms against a weak Blast Door. Floor 1
			-- fills with radiation. Seal or upgrade the door; Decon Room."), prov. From era FromEra, the
			-- storm of each Surge may get through the Blast Door: DoorLeakChance by the door's level,
			-- plus DoorDamagedChance times the share of its HP it has lost (a wrecked door always leaks).
			-- Strength runs 0 to 100 on every open cell of the floor: it starts at StartStrength and
			-- fills FillPerSecond (times DeconSlow while a Decon Room works: "slows leaks") until someone
			-- seals the door (hold Interact SealSeconds), the door goes up a level, or
			-- Config.Disasters.RadiationLeak.DurationSeconds pass; then it fades, FadePerSecond. Players
			-- in it take PlayerPerSecond radiation at strength 100 (times their RadiationGain); residents
			-- lose ResidentDamagePerSecond, leave at ResidentFleeStrength and are Irradiated from
			-- IrradiateAt. A hazard pocket in the Crystal Hollows leaks into one room, from PocketStrength.
			Radiation = {
				StartStrength = 15, FillPerSecond = 2.5, FadePerSecond = 6, PlayerPerSecond = 3, ResidentDamagePerSecond = 2,
				ResidentFleeStrength = 10, IrradiateAt = 40, SealSeconds = 4, DeconSlow = 0.5, DoorLeakChance = { 0.6, 0.3, 0 },
				DoorDamagedChance = 0.4, PocketStrength = 40, FromEra = 3,
			},
			-- Outbreaks (Prompt 24; Section 10: "A sickness spreads between residents. Medbay treatment
			-- and quarantine in Quarters."), prov. From era FromEra, someone who comes in from the Deep
			-- (a rescue, a Lost Crew, a deep expedition home) carries it CarrierChance of the time (the
			-- wanderers' carrier odds, Section 10). Every SpreadSeconds each sick resident who isn't
			-- quarantined passes it to one other in their room, SpreadChance of the time. A sick
			-- resident with no job keeps to a Quarters bed: that is quarantine. A working Medbay cures
			-- one patient every CureSeconds (divided by the team's best OutbreakCureSpeed). Falling sick
			-- costs MoraleNow.
			Outbreak = { SpreadSeconds = 20, SpreadChance = 0.25, CureSeconds = 45, CarrierChance = 0.1, FromEra = 3, MoraleNow = -5 },
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
			-- Prompt 16 (Section 23: PathfindingService on the surface): surface creatures hunt players
			-- anywhere in the town (SurfaceAggro; playtest: at 90 a pack spawned out of range stood idle),
			-- plan a path this often, Ash Jackals circle at CircleRadius between bites ("circle and
			-- dart in"), and an Ash Raider's rifle hits this often
			SurfaceAggro = 300, PathSeconds = 1.5, CircleRadius = 11, CircleSeconds = { Min = 2, Max = 3.5 }, ShotAccuracy = 0.45,
			-- Prompt 23 (the Appendix's Flooded Caverns rows); prov. A Bloat Toad swells BurstSwellSeconds
			-- on contact, then hurts everyone within BurstRadius. A Lurker lies in wait HideSeconds
			-- before it goes hunting, strikes at its Range plus AmbushReach, is seen for RevealSeconds
			-- after a hit, and lets go of a resident when hit for GrabBreakDamage (stunned
			-- GrabBreakStun); held, the resident takes GrabDamageMultiplier of its bite each attack.
			-- A Tide Crab takes ArmorFront of a blow from within ArmorArcDegrees of its front and
			-- WeakBack times a blow from within WeakArcDegrees of its back. Standing to fight it turns
			-- only ShellTurnDegreesPerSecond (a player circling at its reach goes round at about 170), and
			-- it strikes only at what is within ShellFaceDegrees of dead ahead.
			BurstRadius = 9, BurstSwellSeconds = 0.7, HideSeconds = 25, AmbushReach = 5, RevealSeconds = 1.2,
			GrabBreakDamage = 45, GrabBreakStun = 1.5, GrabDamageMultiplier = 0.6,
			ArmorFront = 0.25, ArmorArcDegrees = 130, WeakBack = 2, WeakArcDegrees = 110,
			ShellTurnDegreesPerSecond = 80, ShellFaceDegrees = 40,
			-- Prompt 24 (the Appendix's Crystal Hollows rows); prov. A dead Shardling's shards sting
			-- everyone within ShatterRadius for ShatterDamage. A Prism Stalker is unseen unless a flare
			-- or a lamp lights it (within the light's Radius and LightHeight of its floor) and for
			-- StalkerRevealSeconds after it strikes or is hit. A Geode Golem takes SmallGunMultiplier
			-- of a small gun's shot (Config.Items: Gun.Small). A Resonator hums every AttackSeconds:
			-- monsters within its Range heal HumHealFraction of their health and move HasteMultiplier
			-- as fast for HasteSeconds; it keeps HumFollow studs from the monster it follows.
			ShatterRadius = 7, ShatterDamage = 6, StalkerRevealSeconds = 1.5, LightHeight = 10, SmallGunMultiplier = 0.2,
			HumHealFraction = 0.08, HasteMultiplier = 1.35, HasteSeconds = 5, HumFollow = 12,
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
		Expeditions = { -- Section 12; distress and loss odds prov. The rest is Prompt 18, prov.
			Size = { Min = 1, Max = 3 }, Cycles = { Min = 1, Max = 3 }, DistressChance = 0.15, BaseLossChance = 0.05,
			SurfaceLoot = "ExpeditionSurface", DeepLoot = "ExpeditionDeep",
			-- each cycle away: someone hurt this often, all of it times the destination's Danger and the
			-- team's Risk (1 at an average Grit and Speed of StatPivot, StatStep less a point above, within
			-- RiskMin..RiskMax: Grit 8 and Speed 8 make it 0.76)
			HurtChance = 0.2, Danger = { Surface = 1, Deep = 1.3 },
			StatPivot = 5, StatStep = 0.08, RiskMin = 0.4, RiskMax = 1.5,
			-- the hurt lose this share of their max health; a packed Medkit leaves MedkitHurtKept of it,
			-- and turns someone lost into someone badly hurt
			HurtShare = { Min = 0.2, Max = 0.45 }, MedkitsMax = 3, MedkitHurtKept = 0.5,
			-- finds: each member carries CarryBase + Strength x CarryPerStrength of the table (Strength 5: 1)
			CarryBase = 0.5, CarryPerStrength = 0.1,
			-- a distress call comes this many seconds into the day (the Radio Operator's lead earlier);
			-- they are sent from within UseRange of the Blast Door's or a Radio Room's console, and walk
			-- out through the Blast Door (gone after LeaveSeconds even if their way is blocked)
			CallDelay = { Min = 40, Max = 140 }, UseRange = 30, LeaveSeconds = 40,
			-- a recruit they bring home (one at most each trip): Rare this often
			RecruitRareChance = 0.2, RecruitLevel = { Min = 1, Max = 3 }, RecruitsMax = 1,
			-- the Radio Room (Charm): its Recruits output brings a recruit to the Blast Door at each whole
			-- point (Rare this often); while a Lost Crew is out and a Radio Room is staffed and lit, it
			-- picks up a crew's call every RadioHintCycles cycles (Section 12: crew hints)
			RadioRareChance = 0.15, RadioLevel = { Min = 1, Max = 3 }, RadioHintCycles = 2,
			-- Landon (Prompt 18): a team averaging this Speed comes home a cycle early (never under 1
			-- cycle) with the full trip's finds; a distress call needs a working Radio Room to be heard
			FastSpeed = 8,
		},
		Draft = { -- Section 8 (three cards after every Surge); the rest is Prompt 19, prov.
			Cards = 3,
			-- Landon (Prompt 19): a found blueprint joins the next draft as an extra choice, this many a draft
			FoundPerDraft = 1,
			-- a reroll (the Mad Scientist's free one, the paid boost) starts the 20 s over with no votes cast
			RerollRestartsTimer = true,
			-- Overclock: when its chance comes up, the overload starts this many seconds into the Surge
			OverloadDelay = { Min = 10, Max = 50 },
			-- Bounty Contract: a progress alert every this many kills
			BountyAlertEvery = 10,
			-- Salvage Rights: players on the surface hear the early storm coming this long before it hits
			StormEarlyWarnSeconds = 10,
		},
		Surface = { -- Section 12; rates prov. The rest is Prompt 16, prov.
			StormSirenSeconds = 20, RadiationPerSecond = 0.2, StormRadiationPerSecond = 2, RefillEvery = "Era",
			-- the surface is everything above ZoneY (the bunker's floor 1 is at -120, the town's ground at 200)
			ZoneY = -60, TickSeconds = 0.5, RadiationWarnAt = 0.75, WraithRadiationPerHit = 8, DeconPerSecond = 10,
			-- Clear-Rad pills are taken by themselves when radiation reaches PillUseAt (a Bible Question)
			PillUseAt = 100, PillsMax = 3, ElevatorHoldSeconds = 1, FadeSeconds = 0.35, EscortRange = 30,
			SearchSeconds = 1.5, ItemStack = 5,
			Stacks = { Food = 10, Water = 10, Scrap = 50, Iron = 20, Copper = 20, Crystal = 20, Medkits = 3, Ammo = 60 },
			-- Section 12: big finds are carried with both hands, slowly; two carriers move faster
			CarryWalkMultiplier = 0.5, TeamCarryWalkMultiplier = 0.8, HelpRange = 10, PickUpSeconds = 1,
			BigFindChancePerDay = 0.4, MaxBigFinds = 1, BigFindLoot = "GeneratorParts",
			-- trapped survivors: hold to free, then they follow you home
			FreeSeconds = 3, SurvivorChancePerDay = 0.6, MaxTrapped = 2, RareSurvivorChance = 0.2,
			SurvivorLevel = { Min = 1, Max = 3 }, SurvivorHealth = 60, FollowDistance = 6, SurvivorWalkSpeed = 15,
			-- creatures: jackal packs by day, raiders from RaiderMinEra, wraiths only in storms
			MaxMonsters = 8, SpawnDistance = { Min = 70, Max = 160 }, JackalEverySeconds = { Min = 30, Max = 55 },
			RaiderEverySeconds = { Min = 50, Max = 80 }, RaiderMinEra = 2, WraithEverySeconds = { Min = 10, Max = 18 },
			RaiderMeleeShare = 0.33, -- Landon (Prompt 16): a third of raiders fight hand to hand
			WraithDistance = { Min = 35, Max = 70 }, DespawnSeconds = 20,
		},
		Deep = { -- Section 12 (Prompt 17), all prov.
			-- caves: pieces after the mouth, tries per exit, the gap kept between pieces; nothing in front of
			-- the grid's back (z -17) and nothing below the Source Chamber's floor
			CavePieces = { Min = 3, Max = 6 }, PlannerTries = 6, Margin = 1, GridBack = -17.5, LowestY = -330,
			-- what a Find spot holds (weights; cryo pods from Era II, as in DigResults)
			FindOdds = { OreVein = 30, Cache = 18, RadioLog = 10, TrappedMiner = 8, CryoPod = 4, GlowshardChest = 2, Nothing = 28 },
			-- a cavern holds a nest (else a cache); guards come out when a player is WakeRange from their piece,
			-- asleep at their posts until one is GuardRange from them, then stay near their post (playtest: 6 of
			-- budget woken at 45 studs downed a lone Survivor in 3 s)
			NestChance = 0.5, GuardChance = 0.6, GuardBudget = 4, WakeRange = 60, GuardRange = 30, DeepAggro = 60,
			MineSeconds = 3, OpenSeconds = 1.5, ListenSeconds = 1, ChestSeconds = 2,
			-- drops (Section 12): a fall past FallDamageFrom studs hurts (the Spelunker's NoFallDamage)
			FallDamageFrom = 14, FallDamagePerStud = 4, FallDamageMax = 80,
			-- darkness (Section 12): a player's own light in the Deep (LightRadius doubles it), the lanterns
			LightRange = 18, LightBrightness = 1.4, LampRange = 22, LampBrightness = 1.6,
			-- cryo pods (Section 6): a Cryo Bay's Thawing output per pod; Rare or Legendary
			ThawPoints = 2, LegendaryChance = 0.15, CryoLevel = { Min = 2, Max = 5 },
			-- trapped miners and the Lost Crews (Section 12)
			MinerRareChance = 0.25, MinerLevel = { Min = 1, Max = 4 }, CrewLevel = { Min = 2, Max = 5 },
			CrewFloors = { Mines = { Min = 2, Max = 3 }, FloodedCaverns = { Min = 4, Max = 6 }, CrystalHollows = { Min = 7, Max = 9 } }, CrewMinDepth = 2,
			-- Section 12's "radiation in the Crystal Hollows" (Prompt 24, prov.): a player's radiation
			-- climbs this fast in that band's caves, the surface's calm rate, so a trip has its limit
			CaveRadiationPerSecond = { CrystalHollows = 0.2 },
			-- a radio log found while a crew is still lost is a crew's log this often (with where they were heard)
			HintChance = 0.6, NestBudget = 6,
			-- the Spelunker's RevealCaveLayouts: finds, nests and the trapped show through rock this close
			RevealRange = 90,
			-- the surface crew's raider camp: its guards come out when a player is this close, and go back
			-- in when nobody has been near for CampSleepSeconds
			CampWakeRange = 110, CampSleepSeconds = 60,
		},
		Classes = { -- Section 14's abilities, passives and levels; every number here is Prompt 20's, prov.
			-- class levels: a year reached is 1 experience; a level is ClassShop.ClassLevelRuns runs of this many years
			XPPerYear = 1, TypicalRunYears = 50, LevelMax = 3,
			-- holding the ability key this long picks the next option instead of using it
			HoldSeconds = 0.4,
			-- aimed abilities (Grapple Line, Breaching Charge, the gadgets) reach this far from the camera
			AimRange = 80,
			OwnCooldownClasses = { MadScientist = true }, -- "Gadget Belt: 40 s each"
			SecondWindFraction = 0.25, -- Section 14: heal 25%
			-- level 3's shock: every ShockEvery-th shot stuns (every shot held a monster still for good: playtest)
			Turret = { Range = 50, Damage = 9, FireSeconds = 0.3, ShockSeconds = 0.6, ShockEvery = 4, PlaceDistance = 4 },
			TouchHealRange = 6, TouchHealPerSecond = 4, TriageRadius = 24, TriageHeal = 40, -- TriageHeal: Section 14
			FoamRange = 40, -- Foam Burst: the room you stand in, else the nearest burning room this close
			MealHealFraction = 1, -- the Cook's level 2: Hearty Meal heals everyone fully
			TauntRadius = 40, HoldDamageTaken = 0.5, NearbyResidentRange = 20, -- HoldDamageTaken: Section 14
			FlareRadius = 60, -- Section 14
			RequisitionScrap = 100, RequisitionFoodWater = 10, -- Section 14
			CrateDistance = 5, CrateLoot = "SupplyCall",
			DeconRadius = 22, -- Decon Field away from rooms (the surface, the caves)
			Napalm = { Length = 24, Width = 6, DamagePerSecond = 18 },
			Burn = { Seconds = 3, DamagePerSecond = 6, SpreadRadius = 7 },
			KillDisturbance = 1, -- the Exterminator's level 3: Disturbance off for each kill
			SteadyShots = 3, CritMultiplier = 2, -- SteadyShots: Section 14
			-- Section 14: Overdrive digs 3 cells (each adds its Disturbance, Section 10); a Breaching Charge's blast
			-- adds an explosive's and the cell it clears a dug cell's
			OverdriveCells = 3,
			MagnetRadius = 30, -- Section 14
			RallyFloors = 2, RallyDamage = 1.3, RallyReach = 7, -- RallyFloors and RallyDamage: Section 14
			Breaching = { Damage = 220, Radius = 16, Range = 40 },
			Grapple = { Range = 60, Speed = 90 },
			Trap = { Radius = 8, StunSeconds = 3, Seconds = 30 },
			BeaconSeconds = 45,
			GravityWell = { Radius = 16, Seconds = 4, Pull = 30 },
			Drone = {
				Range = 45, Damage = 7, FireSeconds = 0.4, GuardDamageTaken = 0.5, AssaultMultiplier = 2, RepairPerSecond = 40,
				RepairRange = 30, PickupRange = 20, ReviveSeconds = 2,
			},
			-- a crit (Marksman 3) or an explosion (Demolitionist 3) staggers a boss at most this often
			BossStunCooldown = 8,
			ArcChainRange = 18, ArcChainFalloff = 0.7, -- the Arc Rifle's arc jumps this far, each jump this much weaker
		},
		Legends = { StartLevel = 5, RenownMax = 5, RenownStatBonus = 1, StarterLegend = "RosieKowalski" }, -- Section 15
		ClassShop = { -- Section 14
			Slots = 4, ResetHourUTC = 0, FreeRerolls = 1, VIPFreeRerolls = 2, RerollRobux = 99, WishlistDays = 3,
			FreeTrialRunsPerDay = 1, ClassLevelRuns = { 3, 10 },
			-- the "Class Shop Reroll" developer product (made 2026-11-10 through Open Cloud, 99 Robux; its icon is
			-- ui/products/Product_ClassShopReroll.png). nil would turn the paid reroll off.
			RerollProductId = 3730189637,
		},
		Account = { LevelMax = 100, XPPerYear = 10, XPToLevelBase = 200, XPToLevelStep = 50, VIPGlowshardBonus = 0.25 }, -- Section 16; XP prov.
		Lobby = { -- Section 21; the times below the first line are Prompt 21's, prov.
			PadCountdownSeconds = 20, PartyMax = 6,
			SoloCountdownSeconds = 3, -- "a solo pad starts at once": long enough to step back off
			PrivateInvites = 12, -- how many players a private pad's leader can have invited at once
			LaunchRetrySeconds = 6, -- a pad whose launch failed can try again after this
			RecordSeconds = 43200, -- how long MemoryStore keeps a run's record (a run is shorter than this)
			RejoinStartSeconds = 300, -- the rejoin record's first life (the Run server takes it over when it starts)
			RejoinSeconds = 180, RejoinRefreshSeconds = 60, -- then kept alive by the Run server, so a dead run's offer ends
		},
	},
}
