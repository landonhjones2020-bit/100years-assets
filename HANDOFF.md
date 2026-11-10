# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-09 (late night), after Landon's answers to the Prompt 18 questions. The game bible
(live doc https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 137, and the two project parts,
which match it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.
4. Next is Prompt 19, then 20, then 21: the prep for each is under "Next" below.

## Where things stand

* Prompts 0 to 18 are built and tested in Studio, and Landon's eight Prompt 18 answers are built,
  tested and in the bible. Code build `p18-9e6cd5a` (code asset 95026446991297, revision 76) is
  installed in both places: StructureCheck 0 errors (Run 461 checks, Lobby 254), 107 data tests.
* Prompt 18 (expeditions): from the EXPEDITIONS console on the Blast Door guard's radio or in a
  Radio Room, 1 to 3 residents go to the surface or the Deep for 1 to 3 cycles with Food, Water
  and Medkits. They walk out through the Blast Door and leave the map. Each dawn they find loot,
  and someone may be hurt or lost, or the team radios a distress call. A team averaging Speed 8+
  comes home a cycle early with the whole trip's finds. A call is heard only with a working Radio
  Room (staffed and powered); unheard, the team is lost. A heard call puts a red flare and a plate
  where they're pinned down (a town survivor spot, or a cave); players have until the next day's
  end to reach them (hold HELP) and lead them home. The Radio Room brings recruits and Lost Crew
  calls. Report: `game/reports/P18_Expeditions.md` (the answers in its addendum).
* Prompt 17 (the Deep): a dug cave opening breaks into a cave put together behind the bunker from
  the band's A6 pieces (`workspace.Deep`): ore veins, caches, radio logs, trapped miners, cryo
  pods, Glowshard chests, guards and cave nests. The Lost Crews: one in a cave in the Mines and one
  in the Flooded Caverns (their cells' rolls fixed each run), and one in a raider camp on the
  surface. Cryo pods thaw in a Cryo Bay. Report: `game/reports/P17_Deep.md`.
* Prompt 16 (the surface): the elevator behind the Blast Door goes up to Brightwater Ruins
  (`workspace.Surface`, Y 200, built in Studio by `Lib.BrightwaterMap.Build()` from the A5 art):
  containers, a 10-slot backpack, unloading, generator parts carried home, survivors freed and
  walked home, radiation, a storm every Surge, Ash Jackals, Raiders (Era II) and Wraiths (storms).
  Report: `game/reports/P16_Surface.md`.
* Art in Studio: A1 bunker kit, A4 Mines monsters and the Brood Mother, A5 surface kit, A6 cave
  pieces and props, and 7 of A2's weapons and tools (Pocket Pistol, Service Revolver, Wrench,
  Extinguisher, Welder, Drill, Pickaxe). Class looks: 4 of 19 (Security, Quartermaster, Warden,
  Mad Scientist).

## Landon's latest decisions (all in the bible)

* Prompt 18 (Section 12): supplies are Food and Water for every member for every cycle plus up to
  3 Medkits; a team averaging Speed 8+ comes home a cycle early (never under 1) with the whole
  trip's finds; a distress call needs a working Radio Room, or the team and its finds are lost;
  the deadline is the end of the day of the cycle after the call; players hold Help and lead them
  home; Deep calls come from an opened cave, else the rock face; a lost resident is gone at once,
  with no revive; at most one recruit a trip; the Radio Room's recruits (15% Rare) and its Lost
  Crew call every 2 cycles stay.
* Earlier: a Reactor Core at 0 HP starts a 60-second meltdown; every dug cell touching rock is a
  breach point, on any floor; throwables are crafted, found, and bought before a run with
  Glowshards.

## Next: Prompts 19, 20 and 21

Standing rules (bible Section 24): one system per prompt, the bible wins, never invent gameplay
(suggest it in the Design Notes), content is data, a real playtest for timing, permissions and
saved data, Design Notes and a Delivery Report in `game/reports/P##_*.md`.

### Prompt 19: the blueprint draft (Run)

* Bible: Section 8 (votes, Blueprint draft), the Appendix's "Blueprint card pool" (part 2),
  Section 6 (rooms "Unlocked by: Blueprint draft"), Section 14 (the Mad Scientist's free reroll per
  era at level 3), Section 17 (the paid Blueprint Reroll, 49 Robux: the shop is Prompt 28).
* Already in the code:
  * `Config.DraftCards`: 9 room cards, 7 bunker perks, 4 resident boons, 4 player boons, 5 risk
    deals, each with its modifiers and a weight (room cards weigh more in Era I: `EarlyWeight`).
  * `Config.Votes.Draft` (20 s, MostVotes) and `Rules.Votes.Winner` (ties picked at random).
    `VoteService` runs yes/no votes only, and the vote banner is yes/no: the draft needs three
    options.
  * `CycleClock.SurgeEnded` (the draft opens after every Surge); `BuildService:Unlock(roomType)`
    and the `Unlocked` collection (dev `unlock <roomType>`); `ExpeditionService:Recruit(tier,
    how)` for Radio Booster and Veteran Recruit; DisasterService's overload for Overclock.
  * Modifier keys Prompt 19 implements (13): MedkitsPerPlayer, WeaponRarityUp, BlastDoorLevel,
    ReactorOverloadChance, FreeDraftRerollsPerEra, NextTripLoot, NextStormEarlySeconds,
    RecruitsNow, RareRecruitNow, BountyKills, BountyScrap, ResidentLevels, MoraleNow.
  * Keys of earlier systems, with a way in for a card: `BunkerGrid:SetHPModifier` (RoomHP),
    `DisasterService:SetModifier` (FireSpread, BlackoutDuration), `EconomyService:SetModifier`
    (RoomOutput, with a room), `DigService:SetModifier` (DigSpeed, DigDisturbance). No code reads
    DarkSpawnBonus (Deep Lamps: `BreachService`'s `DarkRoomWeight`) or StaminaMult (Field Rations:
    stamina is in `WeaponService` and `Rules.Combat`) yet. FloodDrainSpeed and GasStrength (Prompt
    23), AmmoCraftCost and the trader's keys (Prompt 30) stay data until their systems exist.
  * Blueprint finds are skipped until this prompt: the `SKIP` sets in `SurfaceService`,
    `DeepService`, `DigService`, `InventoryService` and `ExpeditionService`.
* For the Design Notes, not to invent: what a blueprint found in loot or on an expedition does
  (the bible lists blueprints as finds and the trader sells blueprint cards, but never says);
  whether the draft also follows a boss Surge; the draft's screen (Section 18 lists no draft
  screen and the banner "never blocks the screen").
* Art: none needed. Room cards can show the room's graybox until A7 (remaining rooms); card
  frames per rarity are in the UI kit.
* Testing: real Surge ends on the clock, a vote with a pretend voter (Prompt 8's way), a solo
  pick, every card's effect seen working.

### Prompt 20: all 18 classes plus the Survivor (Run)

* Bible: Section 14 (the class table, class levels; talents are Prompt 27), Section 9 (controls:
  Q is the class ability), Section 19 (class outfits are optional cosmetics), the Appendix's items.
* Already in the code:
  * `Config.Classes` (19 rows: Kit, Passive, Ability with cooldown or uses per Surge, cycle or
    era, Level2, Level3 as modifiers) and `Modifiers.ClassValue(class, key, level)` with the
    player's `Class` and `ClassLevel` attributes. Passives already honoured by earlier prompts:
    the Driller's digging, the Scout's surface speed and siren, the Spelunker's light and falls,
    the Radio Operator's recruits and lead, and others: grep `ClassValue`.
  * `WeaponService` hands out the kit (dev `class <Id>` from the client's DevInvoke). The HUD's
    class plate and ability gauge show the class's ability name; no ability code yet, and Q isn't
    wired.
  * Modifier keys Prompt 20 implements (25): TouchHeal, NearbyResidentDamage, ArmedResidentDamage,
    WeakPointMultiplier, AimZoom, CritsStaggerBosses, BurnSpreadsBetweenMonsters, FuelUse,
    ExplosiveDamage, ExplosiveRadius, ExtraFragGrenades, ExplosionsStunBosses, ArcChainTargets,
    DroneGuns, DroneRevivesPerSurge, TurretDuration, TurretShock, BarricadeCost, TriagePulseClears,
    InstantRally, KillsLowerDisturbance, MealsHeal, RubbleClearInstant, SupplyCallsPerEra,
    ChoosesLevelStat.
  * The profile's `Classes[id] = { Level, XP }` (levels 1 to 3) and `Tuning.ClassShop.ClassLevelRuns`
    (3 and 10 runs).
* Which class a player brings: Prompt 21 writes the run's loadout record (MemoryStore); until
  then the class comes from the dev command. Build ClassService to read the record so Prompt 21
  only has to write it.
* Art (A2, the rest of the class kits): 26 models named in `Config.Items` (`Asset`) aren't made
  yet: Weapon_LeadPipe, FireAxe, Sledgehammer, ShockBaton, DefibPaddles, AntennaWhip, HazardHook,
  HuntingKnife, PowerWrench, PumpShotgun, LeverRifle, RivetSMG, Flamethrower, GrenadeLauncher,
  ArcRifle; Throwable_FragGrenade, Flare, FoamGrenade, ShockMine; Tool_GeigerCounter, Tool_Grapple;
  Item_Medkit, Item_ClearRadPills; Prop_Lamp, Prop_Barricade, Prop_Turret. Also the Tinkerer's
  combat drone (no Config asset yet), their icons, and player clips for the new weapon types
  (two-handed guns, the flamethrower, the grenade launcher, heavy melee).
* Testing: every ability with real Q presses, cooldowns and uses, class XP and levels saved in
  the Studio profile store, team effects with a pretend second player.

### Prompt 21: the Lobby (Lobby place)

* Bible: Section 21 (hub, elevator pads, teleport, rejoin, after a run), Section 14 (Daily Class
  Shop, wishlist, free trial), Section 18 (the Class Shop and Loadout screens in The Frame),
  Section 23 (places, MemoryStore, saved data), Section 17 (the 99 Robux reroll, VIP's second
  free reroll).
* Already in the code: the Lobby runs only the shared services (DevService, SessionService,
  ReplicationService, ProfileService): there is no `game/places/Lobby/` yet. The profile has
  `Glowshards`, `Classes`, `ClassShop = { Day, Slots, RerollsUsed, Wishlist }`, `FirstRunDone`.
  `Tuning.ClassShop` (4 slots, reset 00:00 UTC, rerolls, wishlist 3 days, one free trial a day)
  and `Tuning.Lobby` (20 s countdown, party of 6). `ResultsService` already sends Play Again and
  Return to Lobby teleports (Prompt 15). `studio/ui/A0_ClassShop.lua` is the A0 sample of the
  Class Shop screen.
* To build: `game/places/Lobby/` (pads: public with the countdown, private with invites, solo;
  difficulty per pad; the loadout screen while waiting, class only until Prompt 27), the run
  record in MemoryStore that the Run place reads, the rejoin record and "Rejoin your run", the
  Class Shop (daily slots, rerolls, wishlist, free trial, buying with Glowshards).
* Art (A9, the lobby part): Main Street in sunshine (the A5 buildings before the bomb), the
  Steadfast showroom with class booths and the elevator pads, signs (bible budget: about 25
  models). The cutscene set and Digby are A9's other half (Prompt 22). Class cards need the 15
  class looks still to make: Survivor, Engineer, Medic, Firefighter, Cook, Scout, Radio Operator,
  Hazmat Tech, Exterminator, Marksman, Driller, Scavenger, Demolitionist, Spelunker, Tinkerer
  (`generators/Residents/outfits.py`, `generators/UI/UI_Portraits.py`; rarity rule in Section 19).
* Testing limits: Studio can't reserve servers or teleport (seen in Prompt 15). Pads, countdowns,
  the screens, the MemoryStore records and the Class Shop can be tested in Studio; the teleport,
  the Run reading a real record and rejoining need the published game, played from the Roblox
  app: plan that live test with Landon.
* Open: the 99 Robux reroll needs a developer product (the shop is Prompt 28, product ids are
  Prompt 35): ask Landon whether Prompt 21 makes it or leaves the Robux reroll for later.

## Waiting on Landon

* His answers to the Bible Questions still open: Prompt 17 (8), Prompt 16 (8), Prompt 14 (8) and
  Prompt 13 (6), in `game/reports/`.
* The AutoScale Lite pass on The Frame and HUD (Prompt 6).
* His look at the town, the surface monsters and the caves (`previews/Game/P16_*.jpg`,
  `P17_*.jpg`) and the A4 monsters.
* For Prompt 21: a live test of lobby, run and back in the published game.

## Testing tips

* Expeditions: `exp` (trips out, their logs, whether a Radio Room hears calls), `exp.send
  <surface|deep> <cycles> <medkits> <id...>` (no console needed), `exp.cycle
  [Quiet|Hurt|Lost|Distress]` (a dawn now, the event forced), `exp.call [id]`, `exp.home [id]`,
  `exp.deadline`, `recruit [tier]`, `radio call`. A fast team: `resident.set <id> speed 9`. A
  heard call needs a working Radio Room: `grid.build RadioRoom 1 3`, `residents.auto` (staffs the
  Reactor Core for power), `resident.assign <id> R9`. The screen: `ui.open Expeditions` from the
  client's DevInvoke, or E at a console; SEND from a dev-opened screen is refused away from a
  console, so move the character there first (`PivotTo` on the server).
* The clock: `clock.next` refuses while paused (`clock.resume` first). Pause and `monsters.clear`
  after each step: `clock.next` through a Surge leaves its monsters loose in the bunker, and even
  at x10 the threat director's single day breaches still come.
* The alert box shows two lines (about 80 characters): keep alerts short and put names in logs.
* The Deep: `crews` (where each Lost Crew is), `deep.cave <floor> <column>` (dig a rock cell into
  a cave; dig a path to a crew's cell first with `dig`), `deep` (caves, + guards asleep, * woken),
  `deep.tp <floor> <column> [piece]`, `deep.find <kind>` (in front of you), `radiolog [id]`,
  `cryo.add [n]`, `rescues`, `rescue.free <id>`. Falls: a part under the player in the Deep
  (z < -17.5) and a teleport 30 studs up; move the player off before removing the part (a downed
  body on it falls out of the world).
* Surface: `surface.up`/`surface.down` (from the server Invoke they take the first player),
  `pack.add <resource> <n>` and `class <Id>` from the client's `DevInvoke` (they need the invoking
  player), `god <s> <player>` from the server. `god` can't be shortened: `kill <player>` and the
  respawn clear it. `surface.spawn <type> [n]`, `survivor`, `surface.find`, `find`, `storm on`,
  `year 51` (Era III opens the checkpoint), `grid.build DeconRoom 1 3`, `residents.auto` (power).
* Prompt visibility: Roblox shows one prompt per key, by distance and what the camera sees; a
  prompt on a small floor item shows only when the camera looks at it. Log
  `ProximityPromptService.PromptShown` on the client to see which prompt a key will press.
* `god [seconds] [player]` keeps a player alive through a boss fight; `boss.freeze [s]` holds her
  still so a shot can be lined up; `boss.start`, `boss.hurt <n> [weak]`, `boss.lay`, `boss.end`.
  A real boss Surge: `year 24`, then `clock.next` until cycle 2's Surge.
* Real shots: the gun fires from its muzzle towards where the reticle points. Put the character
  in place (the client can move its own character), bind a `ShotCam` render step with the camera
  just behind the muzzle, then click with `user_mouse_input`. Scan for a clear line first with a
  raycast from the muzzle.
* `user_mouse_input` x and y are measured below the top bar (the GUI inset): a button's
  `AbsolutePosition` plus half its size, with no inset added. Buttons with unique paths can use
  `instance_path` (also for scrolling a ScrollingFrame).
* Studio's screen captures leave out billboards (prompts, plates), so check those by using them.
* The simulated mouse doesn't move `GetMouseLocation`: pick Command View cells with the
  `cv.select <floor> <column>` dev command.
* `execute_luau` requires its own copy of a module, so call services through dev commands
  (`DevTools.Invoke`), not `require`.
* Two playtests at once (Run and Lobby) share one profile lock: the second is kicked.
* The project's bible parts are markdown copies of the live doc: after editing the live doc,
  rewrite the part that changed (`project_read` it first, then `project_write`).

## Small bugs seen, for later prompts

* After SEND, the Expeditions screen switches to ACTIVE even when the server refuses the trip
  (too far from a console): it shows NOBODY OUT beside the warning.
* The distress plate's countdown shows --:-- while the clock is paused (dev only).
* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* The HUD's class plate still says SURVIVOR after the `class` dev command.
* The Pump Shotgun and Frag Grenade show placeholder icons in the hotbar (no art yet: A2).
* A monster after a target on another floor can stand in a room or under the Shaft stair (its
  stuck check restarts with every re-plan); seen in the Prompt 17 playtest.
