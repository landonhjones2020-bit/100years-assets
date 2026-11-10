# BUILD LOG: 100 Years Of Fallout art

Newest first. Every "verified" line says how it was checked.

## Status

| Step | State | Verified how |
|---|---|---|
| Setup: workspace, repo, places, import folder, uploads | ✅ done 2026-11-07 | See the session below: every link of the pipeline was run once for real |
| A0 style test (4 models, 2 clips, UI kit look) | ✅ approved by Landon 2026-11-08 | Revolver grip fixed after his note (v2, revision 2) |
| Class looks by rarity (Landon's rule, bible Section 19) | ✅ first four done 2026-11-08 | Portraits rendered from the rig, Class Shop checked in Studio |
| Prompt 0: architecture foundation (both places) | ✅ done 2026-11-08 | Playtests in Run and Lobby; `game/reports/P00_Architecture.md` |
| Prompt 1: content definitions (36 Config types) | ✅ done 2026-11-08 | Installed in both places, 39 data tests; `game/reports/P01_Content.md` |
| Prompt 2: saved data (profiles, locks, receipts) | ✅ done 2026-11-08 | Real DataStore playtests in both places; `game/reports/P02_SavedData.md` |
| Prompt 3: run lifecycle and cycle clock (Run) | ✅ done 2026-11-08 | Two Run playtests (intro, skips, bosses, Year 100, Endless, defeat) and a Lobby playtest; `game/reports/P03_RunLifecycle.md` |
| Prompt 4: bunker grid, graybox kit, starting bunker (Run) | ✅ done 2026-11-08 | Playtest: built at start, changes rebuilt, stairs and doorways walked; `game/reports/P04_BunkerGrid.md`, `previews/Game/P04_*.jpg` |
| A1 bunker kit and starting rooms | ✅ in Studio 2026-11-08 | 46 models set up (size and pivot checked), the bunker builds from them; walked in a playtest; `previews/Game/A1_Studio_sheet.jpg`, addendum in `game/reports/P04_BunkerGrid.md` |
| Prompt 5: over-the-shoulder camera, wall fade, zoom caps (both places) | ✅ done 2026-11-08 | Run and Lobby playtests with real key and mouse-button presses; mouse, stick and touch look still need a person; `game/reports/P05_Camera.md`, `previews/Game/P05_*.jpg` |
| Landon's answers to the Prompt 3 and 4 questions | ✅ built and in the bible 2026-11-08 | Run playtest (boss and final Surges, resting) and data tests (HP per cell); addenda in `P03_RunLifecycle.md` and `P04_BunkerGrid.md` |
| Prompt 6: The Frame and HUD skeleton (Frame both places, HUD in Run) | ✅ built 2026-11-08, waiting for Landon's AutoScale Lite pass | Run and Lobby playtests with real clicks and keys; `game/reports/P06_FrameHUD.md`, `previews/Game/P06_Studio_sheet.jpg` |
| Prompt 7: Command View (Run) | ✅ done 2026-11-08 | Run playtests with real keys, clicks, drags and the wheel, plus graphics level 1; Lobby start check; gamepad and touch still need a person; `game/reports/P07_CommandView.md`, `previews/Game/P07_Studio_sheet.jpg` |
| Prompt 8: votes and construction (Run), with Landon's answers to the Prompt 6 and 7 questions | ✅ done 2026-11-08 | Run playtests with real clicks and keys, a team of three with pretend voters; two real players, gamepad, touch and the wheel click still need a person; `game/reports/P08_VotesConstruction.md`, `previews/Game/P08_Studio_sheet.jpg` |
| Prompt 9: economy and power (Run), with Landon's answers to the Prompt 8 questions | ✅ done 2026-11-08 | Run playtests with pretend crews and eaters, the dark order, refunds, a Nightmare upgrade site, Y voting sent by the test tool; a real controller, two real players and touch still need a person; `game/reports/P09_EconomyPower.md`, `previews/Game/P09_Studio_sheet.jpg` |
| Prompt 10: residents, phase 1 (Run) | ✅ done 2026-11-08 | Run playtests: founders at work, the routine (meal, work, Shaft stairs to bed), assigning with real clicks, the Residents screen, revive and death, defeat; `game/reports/P10_Residents.md`, `previews/Game/P10_Studio_sheet.jpg` |
| Landon's answers to the Prompt 9 and 10 questions | ✅ built 2026-11-08 | Data tests (dark ties by draw, wrecked rooms) in both places; a Run playtest (founders idle, the jobs alert on the real client, idle residents to a Lounge); addenda in `P09_EconomyPower.md` and `P10_Residents.md` |
| Prompt 11: combat core (Run) | ✅ done 2026-11-08 | Run playtests with real clicks and keys: server-checked shots, reload, the combo and heavy swings, the roll, sprint, aim, restock, downed, out and respawn, a resident revive; all 11 clips seen playing; the guns held, checked from the side; two real players, a real controller and touch still need a person; `game/reports/P11_Combat.md`, `previews/Game/P11_Studio_sheet.jpg`, `previews/Game/P11_Handles_sheet.jpg` |
| Landon's answers to the Prompt 11 questions; the crooked aim | ✅ built 2026-11-08 | A Run playtest (a Medkit heal, a Frag throw, the Medbay's Medkits), the aim measured in Studio (about 3.5° at the hip); addendum in `game/reports/P11_Combat.md` |
| Prompt 12: threats and monsters (Run) | ✅ done 2026-11-08 | Run playtests: breach warnings, monsters from vents and the rock edge, rooms smashed, ticks latching, residents fleeing, a cleared Tutorial Surge ending early, a player killing a monster; Lobby start check; `game/reports/P12_Threats.md`, `previews/Game/P12_*.jpg` |
| Landon's answers to the Prompt 12 questions | ✅ built 2026-11-08 (the meltdown goes to Prompt 13) | Every rock-edge tunnel a breach point (Run playtest, floors 1 to 4); throwables in loot tables with a data test; the bible updated (live doc rev 128); addendum in `game/reports/P12_Threats.md` |
| Prompt 13: disasters and repairs (Run) | ✅ done 2026-11-09 | Run playtests with real keys, clicks and holds: fires put out by residents, the Extinguisher and a Foam Grenade, spreading; blackouts and the fuse box; cave-ins dug, smashed, trapping a resident, cutting off a monster; the meltdown stopped by three valves and lost when left; the Welder's repairs and an electrical surge welded; a Surge's disaster bought from its budget; Command View statuses; Lobby start check; `game/reports/P13_Disasters.md`, `previews/Game/P13_*.jpg` |
| Prompt 14: digging, depth bands, Disturbance, Push Deeper (Run) | ✅ done 2026-11-09 | Run playtests with real E holds, clicks and throws: digging with the Drill (the Driller, dust at the face), a Push Deeper vote with a pretend voter, a cache opened, a nest destroyed by grenades and shotgun, the Drill Bay digging a cell queued with real Command View clicks, the extra breach at 50, a Tremor (cave-in, wave, camera shake), the cycle's decay, the Driller's eye; Lobby start check; `game/reports/P14_Digging.md`, `previews/Game/P14_*.jpg` |
| Prompt 15: the Brood Mother and the results screen (Run) | ✅ done 2026-11-09 | Run playtests with real shots, clicks and a real boss Surge: her warning, rise and roar, slams, egg sacs laid and hatching, a sac broken by Revolver shots and one burned by the Flamethrower, belly hits for double, a stagger, phase 2, her death ending the Surge (Year 25 to 27, Era II); the Run Report with payouts saved to the profile, Play Again, Keep Going and Return to Lobby clicked; Lobby start check; `game/reports/P15_BroodMother_Results.md`, `previews/Game/P15_*.jpg` |
| Prompt 16: the surface (Run) | ✅ done 2026-11-09 | Run playtests with real E holds, presses and clicks: the elevator both ways, searching, a survivor freed, followed home and joined, generator parts carried and delivered, unloading at the hall, a jackal shot dead into the pack, raider rifle hits, a dropped bag picked up, radiation death and a clean respawn, a Decon Room, the checkpoint opening in Era III, the Scout's outline and storm warning; Lobby start check; `game/reports/P16_Surface.md`, `previews/Game/P16_*.jpg` |
| Prompt 17: the Deep (Run) | ✅ done 2026-11-09 | Run playtests with real W, E holds and presses and shotgun clicks: walking into a cave through the opened back wall, the Deep's lighting and the player's light, a radio log and its crew hint, an ore vein mined, a cache and a Glowshard chest opened (the profile and the results), the Mines' crew freed and led out of its cave (Lost Crew done), the raider camp's guards waking and going back to sleep and the surface crew riding home (Lost Crew done), a cryo pod found, carried, delivered and thawed into a Rare resident, a fall's damage and the Spelunker's none, the Spelunker's eye, a cave nest destroyed into the pack, a monster's drop in a cave, a monster walking out of a cave; Lobby start check; `game/reports/P17_Deep.md`, `previews/Game/P17_*.jpg` |
| Prompt 18: resident expeditions and distress calls (Run) | ✅ done 2026-11-09 | Run playtests with real E presses and holds, clicks and Enter: the Expeditions screen opened at the Blast Door guard's radio and a Radio Room, teams sent to the surface and the Deep, residents walking out and coming home to their jobs, a real dawn's cycle away, distress calls (forced and rolled) with the radio card, alert, flare, plate countdown and edge arrow, members reached and led home from the town and from a cave, the deadline on the real clock losing the pinned, losses and a Medkit's save, the Radio Room's recruits (rate, the Radio Operator, a Rare recruit) and a crew call, the Residents screen's AWAY tab, the run's stories; Lobby start check; `game/reports/P18_Expeditions.md`, `previews/Game/P18_*.jpg` |
| Landon's answers to the Prompt 18 questions | ✅ built and in the bible 2026-11-09 | Run playtests with real clicks and Enter: a fast team home a cycle early at a real dawn with the full trip's finds, unheard calls losing the team with no Radio Room, the screen's warning gone live when a Radio Room started working, a heard call with one; 107 data tests in both places; addendum in `game/reports/P18_Expeditions.md`, `previews/Game/P18_FastTeam*.jpg`, `P18_UnheardCall.jpg`, `P18_NoRadioWarning.jpg`, `P18_HeardCall.jpg` |
| A6 Mines and Flooded cave pieces | ✅ in Studio 2026-11-09 | 22 models set up in Run (size and pivot measured): 16 cave pieces, the cryo pod, the radio log recorder, two ore veins, the Glowshard chest and the raider camp; six of the Mines' pieces, the camp and four of the props walked, opened and fought round in playtests (the Mines' Drop and Cavern placed in playtests, not walked); the Flooded Caverns' pieces planned in the data tests, not yet walked; `previews/Caves/*.png`, `previews/Game/P17_*.jpg` |
| A5 surface kit | ✅ in Studio 2026-11-09 | 22 models set up in Run (size and pivot measured; three rigs with Motor6Ds), the town built from them (`Lib.BrightwaterMap`), walked and fought in a playtest; the six clips wired in `Config.Animations`; `previews/Game/P16_A5_*.jpg` |
| A4 Mines monsters and the Brood Mother | ✅ in Studio 2026-11-08, waiting for Landon's look | Detail pass after Landon's note; six models set up in Run (sizes, Motor6Ds, attributes), the monsters' new clips seen playing in the bunker, the Brood Mother captured from a resident's height; her clips play from Prompt 15; `previews/Game/A4_*.jpg` |
| A2 weapons and tools | started 2026-11-08 | Pocket Pistol (v2, the grip rakes back) and Wrench in Studio and held in a Run playtest; the 11 player combat clips; the Extinguisher (v2, 0.8 scale) and the Welder held and used in a Run playtest (Prompt 13); the Drill held and digging (Prompt 14); the Pickaxe in Studio, not yet swung; the rest of the class kits to come |
| Rubble kit (Prompt 13) | ✅ in Studio 2026-11-09 | `Kit_Rubble_Doorway` and `Kit_Rubble_Tunnel` set up in Run (size and pivot measured), placed by real cave-ins in a playtest |
| Dig finds (Prompt 14) | ✅ in Studio 2026-11-09 | `Prop_Nest` and `Kit_CaveMouth` set up in Run (size and pivot measured), placed by dug cells in a playtest |
| A3, A7 to A11 | not started | |

## Ids

| What | Id |
|---|---|
| Universe | 10775267993 (owner: user 9768530298) |
| Lobby place (start) | 135073046693952 |
| Run place | 72892455946761 |
| Palette colour | decal 117311354483821, image 131636360909441 |
| Palette metalness | decal 110154044758914, image 92929300444943 |
| Palette roughness | decal 137250713243017, image 133306500207344 |
| Prop_SupplyCrate | model 126356214563544 (version 2 is the right scale) |
| R15_TestWave | animation 106072736219880 |
| Game code (Model, a version per build) | 95026446991297 (`game/BUILD.json`) |
| Weapon_PocketPistol | model 132352458683098 (revision 2: the v2 grip) |
| Weapon_Wrench | model 73400938739387 |
| UI atlas: items | decal 75294353899571, image 111680310007713 (Prompt 14: six icons; Prompt 13's was decal 116109976139787, image 99377896545998) |
| Tool_Extinguisher | model 76126163117722 (revision 2: 0.8 scale) |
| Tool_Welder | model 128082564413732 |
| Kit_Rubble_Doorway, Kit_Rubble_Tunnel | models 122746670882128, 120681518972920 |
| Tool_Drill, Weapon_Pickaxe | models 112271409940762, 90008781885000 |
| Prop_Nest, Kit_CaveMouth | models 135960876275147, 104679667911320 |
| Player combat clips (11) | `manifest.csv`, rows `R15_GunHold` to `R15_Revive` |
| Mines monsters (rigs, revision 2 after the detail pass) | Burrow Tick 90784985441642, Tunnel Hound 111045663637462, Spitter Grub 70536165729662, Hollow Miner 83503998043819; their clips in `manifest.csv` and `Config.Animations` |
| Boss_BroodMother | model 132844909378352; clips Idle 116082078619476, Walk 105510410741576, Attack 87449889032585, Roar 104063099850529, LayEggs 125795678354746, Stagger 121846906504911, Death 115302160037147 |
| Boss_BroodMother_EggSac | model 98283751054755 |
| A5 buildings | Bldg_BunkerEntrance 136471216640058 (revision 2: the sign above the ring), Bldg_Checkpoint 99960013965832, Bldg_Diner 90817408363257, Bldg_GasStation 94452141526135, Bldg_Grocery 75037755291525, Bldg_HardwareStore 74921566661365, Bldg_Motel 109378714490689, Bldg_RadioTower 115435627788663, Bldg_RailYard 97376228075003, Bldg_Showroom 127482590185586, Bldg_WaterTower 76988598885900 |
| A5 props | Prop_BurntTree 109228472383503, Prop_Cabinet 103949699846399, Prop_CarWreck_A 75526591155472, Prop_CarWreck_B 105808061470942, Prop_Debris 83482976617480, Prop_Locker 118990684990389, Prop_GeneratorParts 92467000818852, Prop_LootBag 72177580542444 |
| A5 monsters (rigs) | Monster_AshJackal 121226055816229 (Walk 84332717499460, Attack 119698905968735), Monster_AshWraith 86571623522715 (Walk 101978077102714, Attack 95768211145275), Monster_AshRaider 89393935264400 (Walk 92909841950988, Attack 71659501687501) |
| UI atlas: surface | decal 134611993314949, image 83031843710701 (eight surface icons) |
| A6 cave pieces (Mines) | Entry 140717306990902, Tunnel 125627570956077, Junction 110936005050325, Pocket 126495354568524, Chamber 118404370996473, Cavern 104525632291205, Drop 76505454786857, CrewPocket 133491070274137 |
| A6 cave pieces (Flooded Caverns) | Entry 88005799323610, Tunnel 105408170372431, Junction 75060404030395, Pocket 75206193324335, Chamber 114211170875518, Cavern 119297962809184, Drop 130513581479117, CrewPocket 95172140422209 |
| A6 props and the camp | Prop_CryoPod 132623260035104, Prop_RadioLog 98835439143608, Prop_OreVein_Iron 115510368510470, Prop_OreVein_Copper 95549982504888, Prop_GlowshardChest 86151759055326, Bldg_RaiderCamp 122967926196969 |
| Tooling (one-off Studio setup batches as a Model) | ArtSetupBatch_A4detail 135542687260691, ArtSetupBatch_A5walls 126694463530516, ArtSetupBatch_A6 84423211905560 |
| Unused | model 131439621755660: a duplicate crate upload at 100x scale, left in Landon's inventory |

## 2026-11-09 (late night): Landon's answers to the Prompt 18 questions; the bible; ready for Prompts 19 to 21

Game code builds `p18-ce988e5` and `p18-9e6cd5a` (final): code asset 95026446991297 revisions 75
and 76, installed in Run and Lobby: StructureCheck 0 errors (Run 461 checks, Lobby 254), 107 data
tests passed in each.

**Done**
* Landon answered the eight Prompt 18 Bible Questions. Six approve what was built (supplies, the
  deadline, hold HELP and lead home, Deep call spots, losses with no revive, one recruit a trip).
  Two changed the build:
  * Speed and length: a team averaging Speed 8+ (`Tuning.Expeditions.FastSpeed`) comes home a
    cycle early, never under 1, with the full trip's finds (`Rules.Expeditions.Fast` and `Trip`).
  * The Radio Room: a distress call needs a working Radio Room (staffed and powered); unheard, the
    team and its finds are lost (`RunState.RadioWorks`; the screen warns before SEND).
* Playtest fixes: the unheard alert shortened (the names ran past the alert box); the screen's
  no-Radio-Room warning in its own section (appended to the risk line it shrank to unreadable).
* All eight answers in the bible's Section 12, marked "(Landon, Prompt 18)": the live doc and the
  project's part 1.
* The handoff for a new chat and Prompts 19 to 21: `HANDOFF.md` and the project doc.

**Verified in Studio**: the addendum in `game/reports/P18_Expeditions.md`.

## 2026-11-09 (night): Prompt 18, resident expeditions and distress calls

Game code builds `p18-0c0e847` to `p18-9427693` (final): code asset 95026446991297 revision 74,
installed in Run and Lobby: StructureCheck 0 errors (Run 461 checks, Lobby 254), 107 data tests
passed in each. The HUD got `Templates.Distress` in Run (`studio/ui/patches/HUD_P18.lua`).

**Done**
* Prompt 18:
  * Rules.Expeditions (who goes, supplies, risk and odds, events, carrying and finds, harm, the
    deadline, recruit tiers, log line words).
  * ExpeditionService:
    * the EXPEDITIONS consoles, on the Blast Door guard's desk radio and a radio set in each Radio
      Room;
    * sending, each cycle away, finds, harm and losses, coming home;
    * distress calls with markers and the deadline;
    * the Radio Room's recruits and Lost Crew calls.
  * ExpeditionsController: the Expeditions screen, the distress markers and edge arrows.
  * Config.ExpeditionLogs (draft lines).
  * Residents Away (ResidentService, ResidentBrain); residents already in the run as rescues
    (RescueService); distress spots (SurfaceService, DeepService).
  * The Residents screen's AWAY tab; expedition stories in the results.
  * Report: `game/reports/P18_Expeditions.md` (eight Bible Questions).
* No new art: the Radio Room's set is the A6 radio recorder until A7.
* Fixes from the playtests:
  * the hall's console moved to the guard desk's radio (it floated by the crates);
  * the detail panel's titles shortened (they ran into the subtitle);
  * two footer actions (a third ran under the hint);
  * the edge arrow drawn over the HUD (it hid under the year counter);
  * the Deep's no-cave spot at the rock face (it was in the Shaft);
  * a lost resident shows 0 health;
  * a shorter distress alert;
  * `exp.cycle` can force an event.

**Verified in Studio**: see the testing checklist in `game/reports/P18_Expeditions.md`. Captures:
`previews/Game/P18_*.jpg`.

**Open**
* Landon's answers to the eight Prompt 18 Bible Questions, and the earlier open ones (Prompts 13,
  14, 16 and 17).
* Not seen: four players, gamepad and touch on the new screen, a call answered in a storm, two
  calls at once, a Radio Room's crew call at a real dawn.
* Seen in the first playtest, not reproduced: a resident at 0 health after coming home and setting
  out again. The likely cause is the monsters left in the bunker after `clock.next` skipped a
  Surge. A repeat showed the expedition code keeps health.

## 2026-11-09 (night): Prompt 17, the Deep; A6 cave pieces

Game code builds `p16-eca3ce9` to `p17-5901951` (final): code asset 95026446991297 revision 70,
installed in Run and Lobby: StructureCheck 0 errors (Run 448 checks, Lobby 251), 105 data tests
passed in each.

**Done**
* Prompt 17: Rules.Deep (the cave planner, finds, crews, hints, falls, light, guards),
  DeepService (caves, finds, guards and cave nests, the Lost Crews, radio logs, Glowshard chests,
  cryo pods and the Cryo Bay's thawing, the Deep's light and falls), DeepController (the radio log
  sheet, the Spelunker's eye), `Config.CavePieces` (from `tools/cave_config.py`) and
  `Config.RadioLogs`. Realms (Surface, or underground: the bunker and the Deep) in monsters and
  rescues; monsters walk in and out of caves, guards sleep at their posts; the raider camp and the
  surface's crew (SurfaceService, four `CampSpot`s on the map, rebuilt in Studio); DigService's
  fixed rolls (the crews' caves), result handlers (cryo pods) and FeatureAdded; InventoryService's
  loot specials (radio logs, Glowshards). Report: `game/reports/P17_Deep.md` (eight Bible
  Questions).
* A6: 16 cave pieces (8 a band), the cryo pod, the radio log recorder, iron and copper ore veins,
  the Glowshard chest and the raider camp, uploaded and set up in Run with one tooling batch
  (`ArtSetupBatch_A6`, through the new `tools/chunk_module.py`).
* A5's walls: walls with a door or window cut in them were one solid box each (the diner's door
  was shut). Each colliding wall segment now has its own name, and the rail yard's cars, kiosk and
  sheds collide per part; nine buildings re-uploaded at their next revision and the town rebuilt
  (`ArtSetupBatch_A5walls`), the doors checked clear by raycast.
* Fixes from the playtests: falls are read from the root's speed (a client's Humanoid states never
  reached the server); a crew's own log carries its hint (the Mines' foreman pointed at the raider
  camp); thawing runs with the clock; guards 4 of budget waking at 30 studs (6 at 45 downed a
  Survivor in 3 s); a cave keeps going on its last way on (one cave ended after its first piece);
  a crew without room for its pocket is still guarded by a nest; pieces share the 4 studs of wall
  round their openings (every piece clashed with its parent at first).

**Verified in Studio**: see the testing checklist in `game/reports/P17_Deep.md`. Captures:
`previews/Game/P17_*.jpg`.

**Open**
* Landon's answers to the eight Prompt 17 Bible Questions, and the earlier open ones (Prompts 13,
  14 and 16).
* Not seen: four players, gamepad and touch, a run's Flooded Caverns caves, a crew member killed on
  the way, a cave mouth blocked by another cave.
* Seen, not changed (Prompt 12's walking): a monster after a target on another floor can stand in
  a room or under the Shaft stair.

## 2026-11-09 (night): Prompt 16, the surface; the A5 surface kit

Game code builds `p16-effb6c4` to `p16-2e4b703` (final): code asset 95026446991297 revision 64,
installed in Run and Lobby: StructureCheck 0 errors (Run 439 checks, Lobby 247), 102 data tests
passed in each.

**Done**
* Prompt 16: Rules.Surface, SurfaceService (map, zones, elevator, containers, storms, radiation,
  surface creatures), InventoryService (backpacks, unloading, big finds and carrying, dropped bags,
  Clear-Rad pills, monster drops), RescueService (trapped survivors, the escort, joining),
  SurfaceController, Lib.BrightwaterMap (the town at Y 200, built in Studio). MonsterService zones,
  pathing, circling and shooting; busy hands in WeaponService and CombatController; hauls and
  rescues in the results. Report: `game/reports/P16_Surface.md` (eight Bible Questions).
* The HUD's backpack chip and fade (`studio/ui/HUD_Surface.lua`, patch `HUD_P16.lua`; 358
  instances); eight surface icons in a new atlas.
* A5: 11 buildings, 6 props, the loot bag and generator parts, the Ash Jackal, Ash Wraith and Ash
  Raider with walk and attack clips, all uploaded, set up in Run (`ServerStorage.Assets.Surface`,
  `.Props`, `.Monsters`) and built into `workspace.Surface` (11 places from the art, 10 signs
  lettered, 43 containers).
* Fixes from the playtests: survivors stand at their feet and path round walls; PUT DOWN steps
  aside near a station; the camera looks out of the elevator; the Ash's colour grade and a lighter
  storm; creatures hunt the whole town (aggro 300); softer jackals and slower raider shots; four
  creature spawn points out of the north hill (creatures fell through it to the old baseplate) and
  a fall guard; the hall's drop-off 15 studs from the elevator (RIDE UP won the E press at 9);
  Scouts' outline read the flag modifier wrongly; the entrance sign moved above the door ring
  (revision 2); stand-in containers face the room; the haul story line.

**Verified in Studio**: see the testing checklist in `game/reports/P16_Surface.md`. Captures:
`previews/Game/P16_*.jpg`.

**Open**
* Landon's answers to the eight Prompt 16 Bible Questions, the eight from Prompt 14 and the six
  from Prompt 13.
* Not seen: four players, Help Carry with two players, a Storage room's drop-off, gamepad and touch.
* The test account now has the Scout's kit only through the dev tool (`class`).

## 2026-11-09 (night): Prompt 15, the Brood Mother's fight and the results screen

Game code builds `p15-141fd7c` to `p15-c2fc8a4` (final): code asset 95026446991297 revision 57,
installed in Run and Lobby: StructureCheck 0 errors (Run 422 checks, Lobby 244), 99 data tests
passed in each. The Run place boots cleanly with it.

**Done**
* Prompt 15: Rules.Boss and Rules.Results, BossService (the arena, warning and rise, slams, egg
  sacs, the belly, staggers, phases, death; her clips played on the server), ResultsService
  (stats, the story, payouts, account experience, profile stats, the MVP, Play Again, Keep Going,
  Return to Lobby), BossController (the HUD's boss bar, camera shakes), ResultsController (the
  Run Report). Report: `game/reports/P15_BroodMother_Results.md` (six Bible Questions).
* The HUD's boss bar (`studio/ui/HUD_Boss.lua`, patched into `StarterGui.HUD` in Run).
* The Brood Mother in Studio (`ServerStorage.Assets.Bosses.Boss_BroodMother`, Run): her 24
  queryable MeshParts' `CollisionFidelity` set to Hull (was Box), so shots reach her belly. The
  pipeline has a new collision kind for this, `queryhull` (steadfast, `STYLE.md`, `AssetSetup`
  reinstalled in Run, the Beast rig, her generator and sidecar), so a re-export keeps it. Her
  uploaded model (132844909378352) is unchanged.
* Fixes from the playtests: her fight's own tuning has no `PublishSeconds` (the tick stopped
  after her first eggs); her root box caught shots meant for her belly (a colliding part is
  always hit by raycasts, so it stops colliding too); armour takes half (a quarter made a solo
  fight hopeless); her slam reaches 18 studs (players at the front of her cell were safe) and she
  turns 60 degrees a second (a circling player can reach her flanks); the run's story names a
  dead resident; the story gets the year she fell; a shorter last-blow alert; the results rows'
  outcome icon, plurals and icons. Dev commands `god` (CombatService) and `boss.freeze`.

**Verified in Studio**: see the testing checklist in `game/reports/P15_BroodMother_Results.md`.
Captures: `previews/Game/P15_*.jpg`.

**Open**
* Landon approved all six Prompt 15 answers (2026-11-09, "All of that is ok"); the bible (live doc
  rev 133, project part 2) has them. Still open: the eight from Prompt 14 and the six from
  Prompt 13.
* Not seen: a fight with several players, real teleports (Play Again, Return to Lobby: live
  servers only), the Run Report coming back after being closed.
* The test account (`PlayerProfiles_Studio`) now has `FirstRunDone` true and 112 Glowshards.

## 2026-11-09 (night): Prompt 14, digging, Disturbance and Push Deeper; the Drill, the Pickaxe, the nest and the cave mouth

Game code builds `p13-e38e8ce` to `p14-1803b8e` (final): code asset 95026446991297 revision 50,
installed in Run and Lobby: StructureCheck 0 errors (Run 403 checks, Lobby 240), 95 data tests
passed in each. The Lobby starts cleanly with it.

**Done**
* Prompt 14: Rules.Dig and Rules.Loot, DigService (dig prompts at every face, stacking, the
  roll and what dug cells hold, Push Deeper votes, the Drill Bay's queue, Disturbance with its
  extra breach and Tremor), DigController (prompt gating, dust, the Tremor's shake, the Command
  View's notes and queue), the HUD's seismograph, `ThreatDirector:Burst`. Report:
  `game/reports/P14_Digging.md` (eight Bible Questions).
* Art: `Tool_Drill`, `Weapon_Pickaxe`, `Prop_Nest`, `Kit_CaveMouth`, and the Drill and Pickaxe
  icons in a new items atlas.
* Fixes from the playtests: FireWeapon only takes `M<n>` hits, so a nest takes an ordinary
  monster id; a nest's burst is 35% of a normal Surge (50% lost a first run's six founders in
  cycle 1); the extra breach and the Tremor are priced like a normal Surge (the first run's
  easing); the cache stands clear of the Mines' ore cart; a dig-queue choice survives the rock
  cell's refresh in the Command View; `disturbance.add` (the dev parser turns "+5" into 5).

**Verified in Studio**: see the testing checklist in `game/reports/P14_Digging.md`. Captures:
`previews/Game/P14_*.jpg`.

**Open**
* Landon's answers to the eight Prompt 14 Bible Questions (cave-ins from digging, nests, cache
  loot, building on finds, hazard pockets and cryo pods as Empty, the Drill Bay's speed, the
  extra breach and Tremor sizes, nests and DeepService) and the six from Prompt 13.
* Not seen: two real players on one cell, the dig gauge on screen (captures leave billboards
  out), the Pickaxe swung in a fight.
* Studio's simulated mouse doesn't move `GetMouseLocation`, so Command View cells are picked with
  `cv.select` in tests; buttons take real clicks through `instance_path`.

## 2026-11-09 (night): Prompt 13, disasters and repairs; the Extinguisher, the Welder and rubble

Game code builds `p13-a760abc` to `p13-7d05592` (final): code asset 95026446991297 revision 46,
installed in Run and Lobby: StructureCheck 0 errors (Run 394 checks, Lobby 236), 90 data tests
passed in each. The Lobby starts cleanly with it.

**Done**
* Prompt 13: Rules.Disasters and Rules.Modifiers, DisasterService (fires, blackouts and the fuse
  box, cave-ins with Lib.Hazards, the Reactor meltdown with Landon's valve rules, electrical
  surges, the Surge's one disaster), DisasterController, wrecked rooms and repairs (the Welder,
  residents), trapped residents, monsters skipping blocked targets. Report:
  `game/reports/P13_Disasters.md` (six Bible Questions).
* A destroyed Reactor Core now starts the 60-second meltdown instead of losing at once
  (Landon's Prompt 12 answer).
* Art: `Tool_Extinguisher` (v2 at 0.8 scale after the playtest: v1's tank reached the floor on
  Landon's avatar), `Tool_Welder` (the Pocket Pistol's raked grip), `Kit_Rubble_Doorway`,
  `Kit_Rubble_Tunnel`, and their hotbar icons in a new items atlas.
* Fixes from the playtests: disasters keep running while the dev clock is paused; the Welder's
  HP bar at eye height; bigger flames and smoke; no respawn into a burning Medbay; a filled
  tunnel's rubble stays inside the tunnel (it spilled 7 studs into the Medbay,
  `previews/Game/P13_Rubble_Tunnel_v1_spill.jpg`); weapon icons centre on the model.

**Verified in Studio**: see the testing checklist in `game/reports/P13_Disasters.md`. Captures:
`previews/Game/P13_*.jpg`.

**Open**
* Landon's answers to the six Prompt 13 Bible Questions (blackouts ending on their own, fire and
  the Shaft, the repaired threshold, a Surge's disaster kinds, rubble numbers, electrical
  surges).
* Not seen: the billboard plates on screen (Studio's captures leave billboards out, even a plain
  test one), two real players on the valves, phones with several fires.
* The Drill and Pickaxe have no models or icons yet (done in Prompt 14).

## 2026-11-08 (night): Prompt 12, threats and monsters; the A4 detail pass and the Brood Mother

Game code builds `p12-fc9aed6` to `p12-25453ec` (final): code asset 95026446991297 revision 42,
installed in Run and Lobby: StructureCheck 0 errors (Run 372 checks, Lobby 232), 81 data tests
passed in each. The Lobby starts cleanly with it. `ServerStorage.Documentation.ARCHITECTURE` in
Studio picks up the new "Threats and monsters" section with the next code build. The bible
(live doc rev 119 and both project parts) has Landon's Prompt 11 answers (kits, Heal, throwing,
the five new melee weapons) and the monster and boss look rule in Section 19.

**Done**
* Landon's Prompt 11 answers (build `p11-6d59dcb`): a melee weapon in every kit (five new
  items), Medkits with a Heal button (H, hold D-pad up, a touch button) and Medbay restocks,
  throwables thrown with Fire. His crooked-aim note: the gun clips' wrists solved (v3 clips) and
  the waist follows the aim (his avatar uses AnimationConstraint joints). Addendum in
  `game/reports/P11_Combat.md`.
* Prompt 12: Rules.Threat, ThreatDirector (budgets, waves, the trickle, a cleared Surge ends),
  BreachService (vents and rock-edge cells, 10 s warnings), MonsterService (spawning, the cap of
  25, the AI, room damage, goo, latching, stuns), residents fleeing and swatting,
  ThreatController (alerts, the Threat overlay). Report: `game/reports/P12_Threats.md`.
* Art A4 (first pass, then Landon's note "make the monsters more detailed and the bosses need
  to really stand out, they should be scary"): the Burrow Tick, Tunnel Hound (new Jaw bone) and
  Spitter Grub (four mouth petals) rebuilt, the Hollow Miner's detail pass (it needs Landon's
  look again), the Brood Mother (9,924 tris, 23 Motor6Ds, a `Belly` weak point, seven clips)
  and her egg sac. Rules for monsters and bosses are in `STYLE.md` section 1.
* Tooling: `setup_batch.py` writes the generator's scalar meta as model attributes (`HitTime`,
  `LayTime`), so re-imports keep them. A 39 KB setup chunk went to Studio as a ModuleScript
  Model asset (`InsertService:LoadAsset` + `require`) instead of being pasted.

**Verified in Studio**: see the testing checklist in `game/reports/P12_Threats.md`. Captures:
`previews/Game/P12_Studio_ShootHound.jpg`, `A4_Studio_BroodMother.jpg`, `A4_Studio_Lineup.jpg`,
`A4_Studio_InBunker.jpg`.

**Open**
* Landon's look at the rebuilt monsters and the Brood Mother; his answers to the six Prompt 12
  Bible Questions.
* Not seen yet: the Spitter's goo slowing a real player, the Brood Mother's clips on her model
  (Prompt 15), phones with 25 monsters, two real players.
* Seen in playtests, for later prompts: the out telegram says "BACK AT THE MEDBAY" even when the
  respawn is at the Blast Door hall; the roll leaves the floor for a moment; a melee weapon held
  with an empty hotbar hangs into the floor; the A0 sample scripts still print "reached the Hit
  marker" every swing (remove them once Landon is happy with the monsters).

**Landon's answers to the Prompt 12 questions (same night)**: all six "yes" (details in the
addendum of `game/reports/P12_Threats.md`). Built in `p12-c202004` (code revision 43, Run and
Lobby, 82 data tests): every dug cell at the rock edge on any floor is a breach point; Deep
caches, the hardware store and the checkpoint now hold throwables. The live doc (rev 128) has
the answers in Sections 5, 6, 10, 12, 14 and 16.

Landon then settled the two follow-ups: with 1 or 2 players each turned valve stays turned for
10 seconds (with 3 or more the three are turned together), and pre-run throwables cost
Glowshards. Both are in the live doc (rev 130) and in both project bible parts, which now match
the live doc.

**Next session, in order** (also in the project doc `claude/100-years-of-fallout-handoff.md`)
1. Prompt 13, disasters (fire, blackout, cave-in) and repairs, and with them the Reactor
   overload: at 0 HP the Reactor Core starts a 60-second meltdown instead of losing at once;
   three valves in the Reactor Core turned together stop it; with 1 or 2 players each turned
   valve stays turned for 10 seconds. A meltdown that runs out loses the run.
2. Then Prompt 14 (digging, depth bands, Disturbance, Push Deeper) and Prompt 15 (the Brood
   Mother's fight, her art and clips are ready, and the results screen).
* Waiting on Landon: his look at the rebuilt monsters (the Hollow Miner changed after its A0
  approval) and the Brood Mother.
* For the Lobby and shop prompts (21, 28): throwables bought before a run as supplies, paid in
  Glowshards (Landon), prices provisional.

## 2026-11-08 (night): Prompt 11, combat core; the gun handles

Game code builds `p11-5f1b558` to `p11-2e6632c` (final). The final is code asset 95026446991297
revision 35, installed in Run and Lobby: StructureCheck 0 errors (Run 357 checks, Lobby 230), 77
data tests passed. The Lobby starts cleanly with it (11 controllers, the camera on).
`ServerStorage.Documentation.ARCHITECTURE` in Studio picks up this prompt's section with the next
code build.

**Done**
* Rules.Combat, CombatService and WeaponService: combatants with position history, damage with
  no friendly fire, server-checked shots (seeded spread, 250 ms of history), magazines and
  carried ammo, reloads, restocking at the Workshop and Armory, melee combos and heavy swings,
  the roll, sprint and stamina, downed, revive, out and respawn at a working Medbay.
* CombatController, PromptController and Lib.Movement on the client: the inputs, the shot's
  feedback, aim assist on gamepad and touch, the hotbar, the stamina gauge, hit and kill markers,
  damage numbers, health bars, the downed and out telegrams, themed prompts.
* Art (A2's first part): the 11 player clips; the Pocket Pistol and the Wrench with their hotbar
  icons (items atlas).
* **Landon's note, "you keep messing up the gun handles":** the Pocket Pistol's grip leaned
  forward with a foot-like heel. v2 (revision 2) draws the grip as a side profile raked back
  about 16°. Checked from the side in Blender and in Studio, held in a Run playtest (the hand
  made see-through to show the grip in the palm), and aimed. The Service Revolver (v2 since A0)
  and the Wrench were checked the same way: `previews/Game/P11_Handles_sheet.jpg`.

**Verified in Studio** (Run playtests, real clicks and keys)
* Three shots at the dev dummy: a hit marker each, 12 damage each (320 → 284), the magazine
  10 → 7, a health bar on the dummy.
* R reloads from carried ammo (1 → 10 loaded, 60 → 51 carried). F three times: three swings
  for 14 each; F held: the charge, then a heavy swing for 26.
* Ctrl: a 15-stud roll on a flat floor (14 pushed, then a slide), 20 stamina, invulnerable for
  its first 0.35 s. Shift with W: 23.2 studs a second (16 × 1.45), stamina 100 → 85.6, back to
  100 after the 0.8 s delay. The right mouse button: the aim clip and the zoom to 50°.
* Restocking (the controller's X held at a restock point): 60 → 150 carried, the team's Ammo
  200 → 110.
* Every clip seen playing from real input: gun hold, aim, reload, three swings, charge, heavy
  swing, roll, downed, and the revive kneel (E held on a downed resident: Ida Garza up with 22
  of 88 health).
* Downed: the telegram and countdown, crawling, the Humanoid kept at 1 health. Out: the respawn
  countdown, then the Blast Door hall while the Medbay was dark, and the Medbay when powered.

**Findings**
1. **The server kills a Humanoid at 0 health**, even with the client's Dead state turned off,
   so the first downed player died at once. A lethal hit now leaves the Humanoid at 1 and downs
   the player; the HUD shows 0.
2. **Weapon models carry their sockets as `Socket_<Name>` attributes** (relative to the pivot),
   not as Attachments. The held copy is welded from the Grip socket, and Muzzle and Tip become
   attachments on it.
3. **The HUD wasn't built when CombatController started**, so the hotbar stayed empty. The
   controller now waits for it.
4. **Prompts follow the last input device.** Landon's PC has a controller connected, so the
   prompts sometimes show X, and then holding E does nothing; X works.
5. **Billboards drawn from PlayerGui show in Studio captures** (the revive plate and its hold
   gauge in `previews/Game/P11_Studio_revive_prompt.jpg`).
6. **The roll leaves the floor for about 0.2 s** mid-roll, and Roblox's fall clip flickers.
   Polish later (keep the Humanoid running during a roll).
7. **A melee weapon held at rest hangs head-down.** It only happens with an empty hotbar, and
   then the Wrench's jaw goes into the floor. A carry pose comes with A2.

**Landon to do**
* Answer the six Bible Questions in `game/reports/P11_Combat.md` (ammo, the hotbar, Medkits and
  throwables, healing, unarmed, the provisional numbers).
* Play it with a friend: a teammate's revive needs two real players.
* Try a real controller (aim assist, Y, X to restock) and touch.
* The AutoScale Lite pass on the new HUD pieces (the downed telegram, the prompt and damage
  number templates).

## 2026-11-08 (late night): Landon's answers to the Prompt 9 and 10 questions

Game code build `p10-0a6f76b`, code asset 95026446991297 revision 33, installed in Run and
Lobby: StructureCheck 0 errors (Run 332 checks, Lobby 226), 74 data tests passed.

**Done**
* Dark order: at the same distance from power the room drawing the most goes dark first, then
  the newest. A wrecked room (0 HP) draws nothing until it is repaired.
* The founders arrive idle. Two seconds into the run the alert feed says how many residents are
  waiting for jobs (only at the run start). The first-run tutorial (Prompt 31) will place them.
* Idle residents go to a Lounge seat when there is a Lounge, else by their bed.
* No change, as Landon chose: the newest arrivals go hungry first, and the routine keeps its timing.

**Verified in Studio**
* The data tests in both places, with new checks:
  * the Quarters at level 3 (draw 4) go dark before the newer Kitchen (draw 2) at the same
    distance;
  * a wrecked Kitchen takes "needed" from 10 to 8.
* Run playtest:
  * six founders with no job; 0 power made and 10 needed, five rooms dark, the chip "10/0" in red;
  * the alert slip on the real client (`previews/Game/P10_Answers_IdleStart.jpg`);
  * after `/dev grid.build Lounge 1 3`, all six walked to the Lounge and stood idle there
    (`previews/Game/P10_Answers_LoungeIdle.jpg`).

**Not checked by playing**: the new tie-break and wrecked-room power. The starting bunker has no
ties with different draws, and rooms can't be damaged until Prompt 13. The data tests cover both.

## 2026-11-08 (late night): Prompt 10, residents phase 1

Game code builds `p9-e4d9a53` to `p10-b80edc7` (final). The final is code asset 95026446991297
revision 32, installed in Run and Lobby: StructureCheck 0 errors (Run 332 checks, Lobby 226),
74 data tests passed.

**Done**
* Rules.Residents and ResidentService:
  * the six founders, put to work by Auto-Assign (best matches, power first);
  * needs, levels and Medbay healing each cycle; who goes hungry;
  * death, revival and defeat.
* ResidentBrain and Lib.PathGraph: the routine (meal, work, bed) walked through doorways and up
  the Shaft stairs. NPCAnimator and Config.Animations (the A0 walk).
* The Residents screen; workers and assigning in the Command View; the Morale overlay.

**Verified in Studio**
* The economy now runs on real crews (31 to 38 power, food and water from stats).
* The routine, in a Run playtest:
  * all six went to the Kitchen at the day's start, then to work;
  * at the Surge they climbed to the Quarters and lay in their bunks.
* Assigning with real clicks in the Command View; the Residents screen.
* Death: revive (a Medkit spent), death after 20 s, the run lost when everyone was gone.

**Findings**
1. **Filling rooms one by one wasted stats**: a Speed 10 resident ran the reactor while a Speed 2
   one cooked. Auto-Assign now picks slots by priority and fills them by best match.
2. **Config adds `Id` to every entry**, so the clip's own id field is `AssetId`.

**Landon to do**
* ~~Answer the three Bible Questions in `game/reports/P10_Residents.md`~~ (answered; see the
  entry above).

## 2026-11-08 (late night): Prompt 9, economy and power; Landon's Prompt 8 answers

Game code builds `p8-941af25` (the first Prompt 9 install, before the build label moved to 9)
and `p9-4a34bb5` (final). The final is code asset 95026446991297 revision 27, installed in Run
and Lobby: StructureCheck 0 errors (Run 317 checks, Lobby 217), 73 data tests passed.

**Done**
* Code:
  * Rules.Economy: Section 13's formula, the power balance and dark order, eating;
  * EconomyService: production, meals, a resident source for Prompt 10, modifiers;
  * PowerService: dark rooms in emergency red, their Neon fittings dulled, alerts;
  * the HUD's Power chip;
  * the Command View's Power and Production overlays, with a reading chip under each room
    label;
  * a room panel's live power and output lines.
* Landon's answers:
  * Prompt 8, built:
    * tear-down refunds half (provisional);
    * upgrades take construction time on Nightmare only (scaffold-only sites);
    * controllers vote with Y: tap for yes, hold for no, bound above The Frame's Y while your
      ballot is open;
    * the proposer stays a yes.
  * Prompt 9's question, built: power needs crew (A).
* Studio (in-place patches): `RoomLabel.Reading` (Frame, both places) and the vote key chips
  (`VoteBanner.Yes/No.Key`, Run).

**Verified in Studio**
* Power:
  * no crew: 0 made, 5 rooms dark;
  * a stat-10 reactor crew: 24 made, all lit;
  * a stat-4 crew: 9.6 made against 10 drawn, and the Kitchen went dark (the newest room 3 steps
    away).
* The economy:
  * pretend crews make 8 Food and 8 Water a cycle;
  * the meal took 6 of each, by command and again by itself at cycle 2;
  * a shortfall was alerted.
* Refunds: 75 back from a 150 Workshop; 60 back through a team vote, with the telegram showing
  it.
* Nightmare: an upgrade became a site, with its room panel, greyed options and level-up on
  finishing.
* The HUD chip in green, amber and red; the blackout in the world.
* Y tap (yes) and hold (no), sent as the Y input by the test tool with the Command View open.
* Screenshots: `previews/Game/P09_Studio_*.jpg`, sheet `P09_Studio_sheet.jpg`.

**Findings**
1. **The ceiling light strips are Neon parts.** They kept glowing white in a dark room, so dark
   rooms now dull every Neon part and restore it from attributes.
2. **The Frame's main action uses Y on a controller**, so Y can't simply be "vote". While your
   ballot is open, VoteController binds Y above The Frame; once you've voted, Y is the main
   action again on screens.
3. **The test tool's Y arrives as a keyboard input**, so the controller key chips (gamepad only)
   could not be seen.

**Landon to do**
* Answer the three Bible Questions in `game/reports/P09_EconomyPower.md`:
  1. ties in the dark order;
  2. whether a wrecked room draws power;
  3. who goes hungry when food runs short.
* Try Y on a real controller (tap and hold), and a vote with a friend.
* The AutoScale Lite pass covers the new parts too: the reading chip under the Command View's
  room labels, and the vote key chips.

## 2026-11-08 (late night): Prompt 8, votes and construction; Landon's answers

Game code builds `p8-eacefa6` to `p8-5de5ef5` (the last adds only the docs). It is code asset
95026446991297 revision 25, installed in Run and Lobby: StructureCheck 0 errors (Run 307
checks, Lobby 213), 71 data tests passed.

**Done**
* Code:
  * EconomyService (the stockpile, caps from Storage, research);
  * VoteService (Section 8's rules, a queue, solo, cooldowns, pretend voters for Studio);
  * BuildService (proposals, construction sites with helpers, upgrades, merges, teardown,
    unlocks);
  * Rules.Votes and Rules.Construction;
  * VoteController, with the vote telegram in its own ScreenGui above The Frame;
  * the stockpile on the HUD, and alerts in the Frame's footer while the HUD is hidden.
* Studio (in-place patches):
  * StarterGui.Votes, the telegram moved out of the HUD with a timer strip;
  * Ready's key chip (HUD);
  * ghost labels outlined and low in the cell (Frame, both places).
* Landon's answers:
  * Prompt 6: Ready on Z and D-pad down; a mouse-wheel click frees the cursor; Copper and
    Crystal chips only once the team digs into their bands.
  * Prompt 7: no team list, and the Command View pans.
* The Night Shift plugin: Landon can't remove it (not in Manage Plugins, its file deleted). Its
  `ServerStorage.NS_Pipeline` folder holds only an empty Jobs folder and MeshCache, so it is
  now a StructureCheck warning, as Landon said ("just ignore it"). A full Studio restart may
  clear it.

**Verified in Studio**
* Solo, with real clicks: a Workshop built (150 Scrap, a 20 s site, 1.25x with a helper), a
  merge into a 2-cell Workshop, a Kitchen torn down, a Storage raising every cap.
* A team of three (pretend voters):
  * a vote passing on time;
  * a tie failing, then the cooldown;
  * the 40% rule ("2 OF 3 MUST SAY YES") failing, and passing at once when everyone said yes;
  * the cost re-check failing a passed vote;
  * the queue;
  * real clicks on YES and NO, with a vote changed.
* Ready on a real Z press; the HUD's stock; a construction site in the world.
* Screenshots: `previews/Game/P08_Studio_*.jpg`, sheet `P08_Studio_sheet.jpg`.

**Findings**
1. **The telegram's first layout put everything on one line**, which shrank to 12 px. It now
   reads what and its cost, then who, the tally and the time.
2. **A ghost's label sat under the room's label chip**, and cream on cream. It is now outlined
   in navy and sits low in the cell.
3. **The HUD hides under every Frame screen**, so the telegram moved to its own ScreenGui. Alerts
   show in the Frame's footer while the HUD is hidden.
4. **The device reads as a gamepad at the start of a playtest on Landon's PC** (the HUD shows LB
   and DOWN until the first key press). Is a controller plugged in? If not, InputController's
   first guess needs a look.

**Landon to do**
* Answer the four Bible Questions in `game/reports/P08_VotesConstruction.md`:
  1. tear-down refunds;
  2. upgrade time;
  3. vote keys;
  4. the proposer's yes.
* Try a vote with a friend (two real players), and the mouse-wheel click to free the cursor.
* The AutoScale Lite pass now includes StarterGui.Votes (Run).

## 2026-11-08 (late night): Prompt 7, the Command View

Game code builds `p7-009237e` to `p7-719607b`. The last one is code asset 95026446991297
revision 21, installed in Run and Lobby: StructureCheck 0 errors (Run 282 checks, Lobby 206),
68 data tests passed. The Frame's Command View page went in as a patch (both places), plus an
in-place patch that clips zone C.

**Done**
* Code:
  * CommandViewController (docked Frame, camera, pan, zoom, picking, room, open-cell and rock
    details, the build menu, overlays, ghosts, blinking labels, the damage edge);
  * PingService with the `PingCell` and `CellPinged` remotes, and pings on the mini-map;
  * Rules.CommandView and Bunker.FromSnapshot;
  * `cv.*` and `cell.ping` dev commands.
* Studio: `Cabinet.Pages.CommandView`, `DamageEdge` and the view's templates in both places'
  Frame; `Templates.MapPing` in the HUD (Run).

**Verified in Studio**
* Opening and closing:
  * a real Tab, and a real click on the HUD button (Left Alt held), opened it;
  * Tab and Backspace closed it, and the camera came back to the shoulder.
* Picking a room, an open cell and rock with real clicks gave the right panels. A real click on
  Upgrade armed "PROPOSE LEVEL 2", greyed out.
* Moving the view: drag, D and the wheel move it, and the held character didn't move.
* Pings: the Ping button and G both reached the server, and the pin showed in the view and on
  the mini-map.
* Two hits flashed the edge twice.
* Graphics level 1 draws the bunker (see Findings 1).
* Screenshots: `previews/Game/P07_Studio_*.jpg`, sheet `P07_Studio_sheet.jpg`.

**Findings**
1. **Draw distance.** At the lowest graphics level Roblox draws parts only to about 500 studs
   (level 2: about 800). The first camera, 794 studs out, showed an empty view there. The
   camera now stops at 440 studs and widens its field of view when zooming out.
2. **Studio's input tool** gives y below the 87-pixel top bar (y 400 arrived as 487 in
   `GetMouseLocation`). The code was right; tests click at GUI coordinates.
3. Marks, labels and pings had been centred on the cell's floor line (`Grid.CellPosition` is
   the interior floor). They now cover the interior, floor to ceiling.
4. The overlay legend sat under the build menu's 19 rows; it now heads the detail panel.
5. **Roblox's Select button.** Roblox takes the gamepad's Select (View) button for its own UI
   selection unless `GuiService.AutoSelectGuiEnabled` is off. It is now off; this still needs
   a real controller.

**Landon to do**
* Answer the two Bible Questions in `game/reports/P07_CommandView.md`:
  1. Tab and the player list;
  2. the widest view: pan, or zoom out to the full width with perspective.
* On a phone with graphics at 1, open the Command View and check that the bunker draws and
  that a drag pans without walking the character.
* With a controller: the View button opens it; the sticks, A and D-pad up work.
* The AutoScale Lite pass now covers the Command View page too (Frame, both places).

## 2026-11-08 (late night): Prompt 6, The Frame and the HUD

Game code builds `p6-265bbea` to `p6-c29648b`. The last one is code asset 95026446991297
revision 15, installed in Run and Lobby: StructureCheck 0 errors (Run 257 checks, Lobby 184),
64 data tests passed.

**Done**
* UI kit: 16 new sprites in their own atlas, `ui/atlas_hud.png` (decal 113747766925760, image
  129337851835347): touch buttons, action icons, Copper and Crystal. The A0 atlases kept their
  ids.
* Studio: StarterGui.Frame built in both places and StarterGui.HUD in Run, from
  `studio/ui/Frame.lua` and `studio/ui/HUD.lua`. The A0 sample screens moved to
  `ServerStorage.UIArchive` (Run).
* Code: UIController, HUDController, MiniMapController, Lib.KitRuntime, Lib.UIKit (generated
  by `pack_ui.py`), Lib.UISamples, Shared.UIContract, Rules.Hud, and StructureCheck's UI rules.

**Verified in Studio**
* The HUD shows the year, era, phase, time left and the dial. It covered the siren, a Surge
  and the Brood Mother's open-ended Surge, and the year tiles flipped at 24 to 25.
* A real Left Alt plus a click on Ready skipped the day. A real 3 key press picked hotbar
  slot 3.
* The mini-map followed the character. The touch buttons, alerts and banner render.
* The Frame: the class catalog sample (a real click selected Security, then BUY 40), a real
  Backspace closed it, and the list and docked samples work. The Lobby opens the same Frame.
* Screenshots: `previews/Game/P06_Studio_*.jpg`, sheet `P06_Studio_sheet.jpg`.

**Findings**
1. A gamepad selection inside the Frame swallowed the keyboard's Enter (Roblox clicks the
   selected button). The Frame now clears the selection when the device changes away from
   the gamepad.
2. The first Ready spot was under the stockpile panel and the alert feed overlapped the touch
   cluster. Ready moved beside the year counter, the alerts moved up, and the shoulder button
   moved to the cluster's left.
3. A new atlas shows 3 to 4 s after joining (the ore icons popped in). Preloading during the
   intro is recommended.

**Landon to do**
* Run the AutoScale Lite pass on StarterGui.Frame (both places) and StarterGui.HUD (Run), then
  save and publish both places.
* Check the HUD and the Frame in the Device Emulator (small phone, tablet, 1080p, 4K TV).

## 2026-11-08 (late night): Prompt 5 camera, Landon's answers

Game code builds `p5-7f68919`, `p5-a1cd06b` and `p5-d690a7c`. The last one is code asset
95026446991297 revision 12, installed in Run and Lobby: StructureCheck 0 errors, 60 data
tests passed.

**Done**
* The camera (Prompt 5):
  * InputController and CameraController, `Lib.Fade`, `Rules.CameraRig` and `Tuning.Camera`;
  * `StarterGui.Reticle` built in both places by `studio/ui/Reticle.lua`;
  * StarterPlayer settings in both places: shift-lock off, Invisicam as the fallback.
* Seams: a steel ceiling beam and steel back and front posts between the cells of
  multi-cell rooms. The camera tests found the 2-stud gaps.
* Landon's answers:
  * boss and final Surges have no timer and end when the boss (or the Source) is beaten;
  * resting resets at the siren;
  * Endless after an early Deep Victory as built;
  * room HP per cell;
  * no merging across levels;
  * dug cells count as power steps.
* The answers are in the live bible (rev 102) and both project copies. Part 1 was rewritten;
  part 2 needed nothing.

**Verified in Studio**
* Shoulder: right by default; a real V press swapped it.
* Aim: holding the right mouse button gave field of view 50, distance 6, walk speed 9.6 and
  AutoRotate off; releasing it put everything back.
* Zoom and blocking:
  * scroll zoom is capped at 11 indoors;
  * walls pull the camera in;
  * the camera goes through doorways into the next room;
  * the front wall fades when the camera is outside it.
* Floor and ceiling limits held. 48 random looks put the camera in rock 0 times. The stair
  climb followed. The Lobby has no aim and a dot sight.
* Screenshots: `previews/Game/P05_Studio_shoulder.jpg`, `_aiming.jpg`, `_front_fade.jpg`,
  `_lobby.jpg`, `_seams.jpg`.
* Answers:
  * the Brood Mother's Surge ran 180 clock seconds with no end until `boss.beat` (then Year
    27, 2 Years per Cycle);
  * `boss.beat Source` in the final Surge gave the Century Victory;
  * resting was refused during a Surge;
  * the 2-cell rooms start at 1,000 HP.

**Findings**
1. Studio's synthetic mouse moves give no movement while the mouse is locked, and a synthetic
   stick press doesn't turn the camera. So mouse look and stick look can't be machine-tested.
2. The first aim framing put the head over the sight. The aim shoulder went from 0.8 to 1.25
   studs and the aim distance from 5.5 to 6.
3. Night Shift's `ServerStorage.NS_Pipeline` came back at every play start; deleted each
   time.

**Not verified yet**
* Mouse look, gamepad stick look, touch drag and pinch (Landon).
* Phone frame rate and the Device Emulator; the AutoScale Lite pass on the Reticle.
* Two players (Team Test).

**Landon to do**
* Save and publish both places. The Reticle, the StarterPlayer settings and the A1 assets
  live in the place files, not in the code asset.
* Turn off the Night Shift plugin for this game.
* Set `Lighting.Technology` to Future in both places (bible Section 19; the connector can't).

## 2026-11-08 (night): A1 bunker kit and starting rooms in Studio

46 A1 models uploaded (Model, creator 9768530298), inserted in Run, set up with
`setup_batch.py` and moved to `ServerStorage.Assets.Kit` (23) and `.Rooms` (23). Ids and
status (`in_studio`) are in `manifest.csv`. BunkerKit now builds the bunker from them (game
code build p4-1f57849, asset 95026446991297 revision 9).

**Verified in Studio**
* Every model passed AssetSetup's size and pivot check (0.01 studs) on the first try,
  including the `merge="room"` models with uid-named colliding parts.
* Playtest: the starting bunker built from the art (8 rooms, 12 open cells, 613 parts in
  15.5 ms, 25 lights); `grid.art` lists every unit as art; StructureCheck passed all but
  the Night Shift folder.
* Walking (`Humanoid:MoveTo`): through every doorway of floors 1 and 2, up and down the art
  stair between them (invisible hull ramp), into both dug cells and up to the Blast Door.
* Changes rebuild with art: a dug neighbour turned the Blast Door's left wall into the
  doorway piece; a 2-cell Workshop L2, a Storage L3 and dug cells down to floor 8 (Flooded
  Caverns, Crystal Hollows) built from art.
* Screenshots: `previews/Game/A1_Studio_*.jpg`, sheet `previews/Game/A1_Studio_sheet.jpg`.

**Findings**
1. Under the place's current lighting (ClockTime 19.5, dark ambient) the rock reads nearly
   black; the Command View lighting preset should lift it.
2. The A0 Kitchen L1's dining table stands at the cell centre, so a walk to the centre stops
   at the table (expected).
3. Night Shift's `ServerStorage.NS_Pipeline` came back again at play start; deleted.

**Not verified yet**
* Phone frame rate with the art (Device Emulator); light count on a full bunker.
* Socket facing (yaw): positions checked, facings not used yet.
* `Lighting.Technology` (Landon).

## Session 2026-11-07: setup

**Done**
* Workspace: `bpy` 5.2.3 (Blender 5.2.3 LTS) on Python 3.13. Verified: a cube exported to
  FBX and rendered with Cycles, then the crate's preview rendered with the palette.
* Repo `landonhjones2020-bit/100years-assets` (private) created by Landon, attached with
  push access, scaffolded per bible Section 19.
* Experience created by Landon under his own account: Lobby (start place) and Run, both
  open in Studio. Studio access to API services turned on by Landon (not tested yet;
  first used by Prompt 2).
* Import folder `C:\Users\lando\OneDrive\Documentos\100Years-Import` connected to the
  Claude desktop app and approved in Studio's MCP Permissions. Verified: five uploads
  from it succeeded.
* Palette v0 (32 swatches) built and uploaded: colour, metalness and roughness maps. Ids
  are attributes on `ServerStorage.Assets` in Run.
* `Prop_SupplyCrate` generated, uploaded, inserted and set up with `studio/AssetSetup.lua`;
  it sits in `ServerStorage.Assets.Props`.
* `R15_TestWave` written as a KeyframeSequence by Python, uploaded as an Animation.

**Findings (all verified in Studio unless marked)**
1. **Scale.** Roblox reads one raw FBX unit as one stud; Blender writes centimetres. The
   first upload came in 100x too big (423 × 265 × 274.5). With `global_scale = 0.01` the
   crate measures exactly 4.233 × 2.650 × 2.745, matching the export.
2. **Orientation.** `axis_forward="Z"`, `axis_up="Y"` puts the front on −Z. Verified by
   raycasts: the front emblem was hit at z = −1.372 (expected −1.373), the back at +1.263.
3. **Pivot.** The FBX origin becomes the Model's `WorldPivot`: the crate's part sat at
   (0, 1.325, 0) from it, the sidecar's offset. Bottom-centre pivots survive the trip.
4. **Packages.** FBX models arrive as packages (`PackageLink`); AssetSetup removes it.
5. **Stable model ids.** `PATCH /assets/v1/assets/<id>` with a changed FBX made version 2
   of the same asset. A PATCH with identical content makes no new version.
6. **Stale files.** A second `device_commit_files` to an already-used staged path reported
   success but left the PC with the old file. `tools/stage_import.py` now names every
   staged file with its content hash.
7. **Images.** A Decal upload returns the decal id; `InsertService:LoadAsset(decalId)`
   gives the image id (the Decal's `Texture`).
8. **Palette rendering.** Both `TextureID` and a `SurfaceAppearance` (colour, metalness,
   roughness maps) can be set through the connector and show the right swatches (no
   flipped or shifted UVs, no visible bleeding at swatch borders close up). Standard:
   SurfaceAppearance with AlphaMode Overlay. Screenshot: `previews/Pipeline/`.
9. **Clips.** The Python-written `.rbxmx` uploaded as an Animation and played on an R15
   avatar in a Run playtest: length 2.00, looped, right shoulder at 2.60 rad at t = 0.4 as
   keyed, elbow swinging between keys. Screenshot: `previews/Pipeline/studio_testwave_playtest.jpg`.
10. **Metadata PATCH** (`?updateMask=displayName,description`, no file) returned 404
    through the connector, so the 100x duplicate couldn't be renamed.
11. **Night Shift's importer plugin** creates `ServerStorage.NS_Pipeline` in every place
    Studio opens. Removed from Run; Landon can disable the plugin while on this game.

**Not verified yet (A0 covers them)**
* `tint` faces showing `MeshPart.Color` through AlphaMode Overlay on a real tinted mesh.
* Segmented rigs: Motor6Ds built from the sidecar's joints, and Blender-rig clips
  (`export_clips`) playing on them.
* Icons and UI kit textures through the pipeline; anything in the Lobby place.

**Decisions**
* SurfaceAppearance with the palette maps is the standard material for every model.
* Models keep their asset id across revisions (PATCH); clips and images get a new id per
  revision, and `manifest.csv` holds the current one.
* UI must be themed to the game, never generic Roblox UI (Landon). Rules in `STYLE.md`
  section 3; the kit's look joins the A0 style test.

## 2026-11-08 (evening): A0 approved, revolver v2, class looks by rarity

Landon approved the A0 style test ("I love the style") with one fix: the revolver's handle.
He also set a rule for every character: the rarer it is, the more creative its look
(bible Section 19, "Rarity shows in the look").

| Asset | Id | Status | Notes |
|---|---|---|---|
| Weapon_ServiceRevolver v2 | 86157197359329 (revision 2) | verified | 1,308 tris (1,500); size 0.52 × 1.49 × 2.271 checked in Studio; back on the showroom table |
| UI atlas: kit_a | decal 128192097302269, image 85214114089895 | verified | new revolver icon (`previews/A0/Studio_Revolver_v2.jpg`) |
| UI atlas: portraits | decal 96645914120696, image 120657029267813 | verified | class outfits; the five Class Shop images repointed |

**Done**
* Revolver: the forward-raked box grip is now a raked walnut grip in a gunmetal frame with
  brass medallions, steel screws and a lanyard ring, PATCHed as revision 2 of the same
  model (id unchanged).
* Bible (live doc rev 95, Project part 2): A0 approved, the three fonts, the rarity enamels,
  the class card, the rarity rule, and the Section 24 note.
* `generators/Residents/outfits.py`: class outfits built on the resident rig, bound to its
  bones. Security (Common): padded vest, soft cap, brass star. Quartermaster (Rare): canvas
  apron, flat cap, the supply pack (crate, bedroll, lantern), hazard-yellow accents, the
  requisition clipboard. Warden (Epic): caped greatcoat with a high collar, peaked cap,
  fringed epaulettes, the Rally Call megaphone, a glowing Steadfast Star. Mad Scientist
  (Legendary): wild hand-made hair and moustache, glowing goggles, a brass mechanical arm
  with a claw, the Gadget Belt, a Glowshard reactor pack with a sparking Tesla coil, a
  boiling flask. Held props are card-only (in a run the hands hold the player's tools);
  `Body.reach` bends an arm so a hand lands on a target.
* `generators/UI/UI_Portraits.py` dresses, poses and renders each class with bloom on Neon;
  `--check` writes review sheets (`previews/Residents/Outfit_<Class>.png`: card view,
  front, back). Class Shop in Studio: `previews/UI/Studio_ClassShop_Outfits.jpg`.
* `Resident_Common.py` marks its chest details (`sf_detail = "chest"`) so a vest or coat
  can remove them; the exported model is unchanged.
* `AssetSetup` now lives in `ServerStorage.ArtPipeline.AssetSetup` in Run;
  `tools/setup_batch.py --install` reinstalls it.
* `manifest.csv`: A0 rows `approved`, except the revolver and kit_a (`verified`: Landon
  hasn't seen v2 yet). The file is LF now, as `steadfast.manifest_upsert` writes it.

**Findings**
1. Blender 5.2 compositing: a `CompositorNodeTree` node group on
   `scene.compositing_node_group`, ending in a Group Output (the Composite node is gone).
   The Glare node's `Glare` output is the halo alone, so it can be added to the render and
   written into alpha; the halo then shows on the card behind the transparent sprite.
2. Bloom also caught specular highlights on brass under the rim light. Threshold 2.0 with
   Neon emission 8 keeps it on the Neon parts.
3. `ServerStorage.NS_Pipeline` showed up in Run again; deleted (third time).

**Open**
* Landon hasn't seen the class looks yet; any of them can change.
* The outfits exist as portraits only. In game they become cosmetic accessories on the
  player's own avatar (A11), and the other 15 classes need theirs.

## 2026-11-08: A0 style test built and in Studio (waiting for Landon's approval)

Everything below is in Run (studio "run", place 72892455946761). Nothing after A0 starts
until Landon approves the four models, two clips and the UI kit look (bible Section 19).

| Asset | Asset id | Status | Notes |
|---|---|---|---|
| Room_Kitchen_L1 | 96540501294464 | verified | 13 MeshParts, 2,992 tris (budget 3,000); `ServerStorage.Assets.Rooms` |
| Kit_CellShell | 134174776264272 | verified | 7 MeshParts, 1,636 tris (2,000); `ServerStorage.Assets.Kit` |
| Weapon_ServiceRevolver | 86157197359329 | verified | 796 tris (1,500); Grip and Muzzle sockets; `ServerStorage.Assets.Weapons` |
| Resident_Common | 118658215913755 | verified | 16 MeshParts, 2,268 tris (2,500); 15 Motor6Ds, hair welded; face decal |
| Monster_HollowMiner | 83503998043819 | verified | 15 MeshParts, 2,142 tris (4,000); 11 Motor6Ds, 4 glow parts welded |
| R15_ResidentWalk (clip) | 125264708961546 | verified | 1.00 s loop, Movement priority |
| HollowMiner_Attack (clip) | 99038102545112 | verified | 1.47 s, Action priority, `Hit` marker at 0.7 s |
| Face_Resident_Smile | decal 87390877749448, image 103176016141485 | in_studio | on Resident_Common's Head (front) |
| UI atlas: cards | decal 110523717816719, image 75110860144472 | verified | `ui/atlas_cards.png` |
| UI atlas: kit_a | decal 86421992183940, image 74779239339407 | verified | `ui/atlas_kit_a.png` |
| UI atlas: kit_b | decal 125432561809946, image 102495471404574 | verified | `ui/atlas_kit_b.png` |
| UI atlas: portraits | decal 112354578662230, image 76558516830406 | verified | `ui/atlas_portraits.png` |

In Studio:
* `ServerStorage.Assets.<Category>`: the five models, finished by `AssetSetup` (static) and
  `AssetSetup.rig` (rigs). Every MeshPart passed the size and offset check (0.01 studs).
* `Workspace.A0_Showroom`: the kitchen in a cell (front wall removed for the camera), a
  walking resident, a cook at the stove, the Hollow Miner at the side door, the revolver on
  the table, PointLights at the Light sockets.
* `ServerScriptService.A0_ShowroomAnimations`: plays Walk and Attack on the showroom NPCs
  in a playtest (ids from the models' `Anim_<Clip>` attributes).
* `StarterGui.A0_HUD` (enabled) and `StarterGui.A0_ClassShop` (disabled): toggle `Enabled`
  to look at either. Both carry `SliceScaler` and `KitButtons` LocalScripts.
* Screenshots: `previews/A0/` (Studio) and `previews/UI/UI_Kit_sheet.jpg` (every kit piece).

**Findings (verified in Studio)**
1. **Rig pivot.** Setting `Model.PrimaryPart` moved the model's pivot to the root part's
   centre, and assigning `Model.WorldPivot` afterwards did not move it back, so both rigs
   were stored 3 studs low and sank into the floor. Fix (in `AssetSetup.rig`): set
   `root.PivotOffset = root.CFrame:ToObjectSpace(feetPivot)`. Both stored rigs repaired.
2. **Custom-rig clips upload and play.** The Python-written KeyframeSequence for the Hollow
   Miner (custom joint names) uploaded as an Animation and drove all 11 Motor6Ds in a
   playtest; the `Hit` marker fired on every swing. The bible's fallback (Studio-built
   clips) is not needed.
3. **Server NPC animation** replicates to the client; the play-mode `screen_capture` shows
   the client. A freeze (`TimePosition`, `AdjustSpeed(0)`) catches a pose for screenshots.
4. **9-slice from an atlas works:** `ScaleType.Slice` with `ImageRectOffset/Size` slices the
   sub-rect (`SliceCenter` is relative to the rect). `ScaleType.Tile` tiles a sub-rect too.
5. **TextScaled is linked to TextWrapped:** setting `TextWrapped = false` after
   `TextScaled = true` turned scaling off (every label rendered at size 8). Set TextWrapped
   first, TextScaled last.
6. **First image load** in Studio took 3 to 4 s per new atlas; a screenshot straight after
   building shows the UI without images.
7. **Lighting.Technology** can't be read or set through the connector (needs RobloxScript
   capability). The showroom shots look right as the place is set; Landon can switch it
   to Future in the Lighting properties if it isn't already.
8. Night Shift's importer plugin recreated `ServerStorage.NS_Pipeline` twice today; deleted
   both times.

**Not verified yet**
* The AutoScale Lite pass (Landon) and the Device Emulator check on a phone, a tablet, a
  1080p monitor and a 4K TV (bible Section 18 rules 8 and 9). The sample was built
  Scale-only with aspect constraints, but only seen at 1919 x 1079.
* `KitButtons` pressed states and the `SliceScaler` at other screen sizes (written, not
  exercised in play).
* Touch buttons (bottom right on touch) aren't in the sample.
* `Lighting.Technology` (see finding 7).

**Proposed for approval (bible Section 18 leaves these to the style test)**
* Type: Oswald (titles, plates, labels), Special Elite (typed text: logs, telegrams,
  bylines), Roboto Condensed (numbers and body). All three are Roblox font families, and
  the same files are in `ui/fonts/` so baked stamps match live text. No Fredoka One.
* Rarity enamels: Common #8E8C88, Rare #3F79B5, Epic #7D4C9E, Legendary #D9A93A.
* Class cards: catalog card with a chrome rim, a sunburst window in the rarity colour, a
  rarity tag on the window edge, a pilot lamp for the selected card.
