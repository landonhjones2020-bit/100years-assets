# Prompt 10: Residents, phase 1

Residents (bible Section 11, phase 1): identity, stats, jobs, levels, needs, the routine and
death, with residents walking the bunker and a roster to manage them. Built and tested on
2026-11-08. The final install is `p10-b80edc7` (code asset 95026446991297 revision 32), in Run
and Lobby. Residents live in the Run place.

## Design Notes

**Decisions**
1. **The six founders** (Tuning.StartingBunker: Common, levels 1 to 3) arrive when the run
   starts, and Auto-Assign gives them jobs, so the reactor runs from the first second.
   * Stats roll StatMin to StatMax (1 to 10); founders above level 1 put each level into their
     best stat.
   * Names come from Config.ResidentNames, with no repeats in a run. Ages roll 18 to 50.
2. **Max health grows with Grit** (Section 11: Grit affects max health): HealthBase 70 + Grit ×
   6, provisional (Grit 5 gives 100).
3. **Auto-Assign** ("fills empty slots by best stat"):
   * It picks which empty slots to fill in `Tuning.Residents.AutoAssignOrder`: the Reactor Core
     and Generators first (the bunker is dark without them), then Water, Food, the Medbay, the
     other working rooms, and Blast Door guards last.
   * It then fills those slots with the best matches by stat across all of them. A fast cook ends
     up in the Kitchen, not at the reactor.
   * The first version filled the rooms one by one and wasted good stats (Speed 10 at the reactor,
     Speed 2 in the Kitchen); the playtest showed it.
4. **Assigning** happens in the Command View (a room's panel lists its workers and the idle
   residents best at its job) and on the Residents screen. Neither is a vote (Section 8).
   * Dragging a resident onto a room (Section 7) needs the portraits in the Command View, which
     come with A3's resident portraits. Picking from the room's list does the same job for now.
5. **Once a cycle, after the meal**, each resident's needs move (`Rules.Residents.Cycle`):
   * Rest: −60 for working, +100 in a Quarters bed (×0.4 without one).
   * Hunger: −10 health and −10 morale for each missed meal.
   * Morale: +2 for a job on their best stat, −2 for one on their worst, +1 fed, −5 if their job
     room is dark, −5 with no bed. +5 after surviving a Surge.
   * Experience: workers gain 30 XP a cycle, and each level adds 1 to their job's stat
     (Section 11).
   * A staffed, lit Medbay heals the hurt 20 a cycle (provisional).
   * Exhausted residents (rest 0) count half in their room's crew (Config.Conditions).
6. **Who goes hungry** when the stockpile runs short: the newest arrivals first, one per missing
   meal. This is my default while Landon's answer is pending (Bible Question 3 of Prompt 9).
7. **The routine** (Section 11: work a shift, eat at the Kitchen, rest in Quarters), timed by
   me:
   * the first 20 s of each day at a Kitchen seat (standing when seats run out);
   * the rest of the day at a work spot in their job's room;
   * the Surge in bed.
   * Idle residents wait by their bed. The Lounge's socialising comes once there's a Lounge.
8. **Walking** follows the room graph, as Section 23 says (`Lib.PathGraph`):
   * the front aisle inside rooms;
   * the middle of each doorway;
   * the Shaft's stairs by its Bottom and Top sockets.
   * Humanoid:MoveTo at 8 + Speed × 0.6 studs a second.
   * A resident stuck on furniture for 2.5 s steps to the next waypoint.
   * Residents pass through each other and through players (collision groups).
9. **Death** (Section 11):
   * at 0 health a resident is down for 20 s, lying where they fell with a "Revive (1 Medkit)"
     prompt;
   * then they are gone for the run, and their run log says how;
   * the last one gone loses the run (RunDirector, "ResidentsLost").
   * The Medkit comes from the team's stockpile until players carry their own (Prompt 11).
     Carrying a downed resident to the Medbay comes with Prompt 11's carrying.
10. **Animations** play on clients from the body's Activity attribute (Section 23), through a new
    content type, `Config.Animations`. Today only the A0 walk exists. Working, eating and sleeping
    clips come with A3, with no code change. Sleeping residents lie on their bed.
11. **Portraits** on cards are the sunburst windows until A3's resident portraits.

**Design Risks**
* Hunger costs 10 health a cycle. A Grit-1 resident has 76 health, so they die after about 8
  missed meals. Tune once food pressure is real.
* Morale only climbs in a well-run bunker (+1 fed, +2 fit, +5 a Surge), so most residents reach
  Happy within a few cycles. Phase 2's morale extremes and costs will need a counterweight.
* With no clips yet, residents stand still while working and eating.

**Scope Risks**
* Phase 2 (traits, gear, conditions, morale extremes, expeditions) and phase 3 (relationships,
  aging) build on these records; nothing here blocks them.
* Residents fighting and fleeing come with combat (Prompt 11) and monsters (Prompt 12).

**Bible Questions**
1. **Who goes hungry** when food runs short (asked with Prompt 9): the newest arrivals for now.
2. **The founders' start**: do they start at work (Auto-Assign, as built), or idle so the first-run
   objective "assign a resident to the Kitchen" (Section 22) has something to do? Prompt 31 can
   leave the Kitchen empty on a first run either way.
3. **The routine's timing**: 20 s of eating, the day at work, the Surge in bed. Should idle
   residents and those off shift use the Lounge when there is one?

**Recommended Improvements**
* Resident portraits rendered from the rig (A3), then dragging portraits onto rooms in the
  Command View (Section 7).
* A3's clips (working, eating, sleeping, panicking) and a few walk styles.
* Speech bubbles about meals, beds and dark rooms (Section 11, phase 2).

**Technical Risks**
* ResidentBrain runs at 5 Hz for every resident (`pcall`ed). Path planning happens only when a
  goal changes. At 40 residents, check the server's frame time in Prompt 12's full-load test.
* The stuck fallback teleports a resident to their next waypoint. Rooms whose furniture blocks
  the aisle will show it. The A7 room art should keep the front aisle (8 studs in front of
  centre) clear.

## Delivery Report

**Overview.**
* The six founders arrive with names, ages, stats and levels, are put to work, eat at the
  Kitchen, work their shifts, sleep through the Surge, level up, get hungry or tired, and can be
  revived or die.
* Players assign them in the Command View or on the Residents screen.
* Production and power now come from real crews (Prompt 9's resident source).

**Files created**
* `game/shared/Rules/Residents.luau`: rolls, max health, levels, morale states, crews, the
  Auto-Assign matching, a cycle of needs.
* `game/places/Run/server/Services/ResidentService.luau`:
  * data, jobs, the crew and eater source for EconomyService, needs after each meal, Surge
    morale;
  * death and revival, defeat;
  * the `Residents` collection, the remotes;
  * `/dev residents`, `residents.auto`, `residents.add`, `resident.assign`, `resident.hurt`,
    `resident.revive`, `resident.set`.
* `game/places/Run/server/Services/ResidentBrain.luau`: bodies, the routine at 5 Hz, walking,
  lying down, the revive prompt, collision groups, and `/dev brains`.
* `game/places/Run/server/Lib/PathGraph.luau`: routes and waypoints on the room graph.
* `game/client/Controllers/NPCAnimator.luau`: clips from the Activity attribute.
* `game/client/Controllers/ResidentsController.luau`: the Residents screen.
* `game/shared/Config/Animations.luau`: the clip ids (the A0 walk).
* `game/reports/P10_Residents.md`.
* `previews/Game/P10_Studio_*.jpg`, plus the sheet `P10_Studio_sheet.jpg`.

**Files modified**
* `shared/Remotes.luau`: `AssignResident`, `AutoAssign`, `ReviveResident`.
* `shared/Config/Tuning.luau`: `Residents.HealthBase`, `HealthPerGrit`, `MedbayHealPerCycle`,
  `AutoAssignOrder`, `MealSeconds`, `WalkSpeedBase`, `WalkSpeedPerSpeed`.
* `places/Run/server/Services/EconomyService.luau`: `Ate` also carries what was missing.
* `client/Controllers/CommandViewController.luau`:
  * workers on a room's panel;
  * Assign, Take off the job and Auto-Assign options, applied at once;
  * the Morale overlay (workers' average);
  * a RESIDENTS footer button.
* `server/DevTools/StructureCheck.luau`, `server/DevTools/DataTests.luau`: one new test (74 in
  all).
* `game/BUILD.json`: prompt 10.

**Architecture**
* Rules.Residents is pure.
* ResidentService owns the records and plugs into EconomyService through `SetResidents`, so the
  economy never knows about residents.
* ResidentBrain reads ResidentService and moves the bodies; NPCAnimator animates them on
  clients.
* The Residents collection carries what the UI shows.

**Integration notes**
* **Combat (Prompt 11).** `ResidentService:Hurt(id, amount, how)`. Revival will use a player's
  own Medkit; carrying a downed resident to the Medbay arrives with carrying.
* **Monsters (Prompt 12).**
  * Residents' bodies are `workspace.Bunker.Residents.<id>`, with Humanoids.
  * Fleeing and fighting are new ResidentBrain states.
  * `PowerService:IsDark` already costs dark-room morale.
* **Onboarding (Prompt 31).** `ResidentService.Assigned` fires (resident, room) for the first-run
  objective.
* **Phase 2 (Prompt 26).** Traits go into the crew's Multiplier and each eater's FoodUse;
  conditions go into `Residents.Cycle` and `Residents.Crew`.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Installed `p10-b80edc7` in both places: StructureCheck 0 errors (Run 332 checks, Lobby
  226), 74 data tests passed. The residents test covers rolls, levels, morale, crews,
  Exhausted, Auto-Assign (the reactor first, and the fast cook in the Kitchen) and needs.
- [x] Run playtests:
  * six founders put to work, with power, food and water from their stats (31 to 38 power at
    the start);
  * two cycles at 60× speed: XP, morale and meals.
- [x] Residents walked to the Kitchen for the meal, then to work, crossing doorways. They were
  seen in the Command View working at the Water Purifier and the Reactor Core.
- [x] Auto-Assign on the final build put the Strength 9 and 7 residents on the reactor, Smarts 10
  on Water and Speed 8 in the Kitchen (38.4 power, 12 Water, 7.2 Food).
- [x] Real clicks:
  * the Medbay's panel showed "WORKERS · 0 OF 2", Assign Hank Chen and Auto-Assign;
  * picking Assign and pressing the main action put Hank in the Medbay (0.4 Medkits a cycle).
- [x] The Residents screen from the footer: six cards, a resident card, Take off the job, and
  Auto-Assign.
- [x] Death:
  * a downed resident lay down with the Revive prompt;
  * a revive cost one Medkit (4 → 3) and brought them back at 25% health;
  * an unrevived one died after 20 s;
  * losing every resident ended the run (Defeat, ResidentsLost).
- [x] The Surge on the final build: all six walked from floor 2 up the Shaft stairs to their
  beds in the Quarters on floor 1 (two on top bunks) and lay down.
- [ ] A3 clips; many residents at once; residents walking down to a job below the Quarters.

**Future extension notes**
* Every Activity can get its own clip through `Config.Animations`.
* PathGraph's routes suit monsters inside the bunker too (Section 23).

## Addendum: Landon's answers (2026-11-08)

| # | Question | Landon's answer | What changed |
|---|---|---|---|
| 1 | Who goes hungry | "Keep Newest Arrivals" | No change. |
| 2 | The founders' start | "Idle and have the first run tutorial put them in the apporiate spots" | The six founders arrive idle: no Auto-Assign at the start. Until someone works the Reactor Core the bunker is dark. Two seconds into the run, the alert feed says "6 RESIDENTS ARE WAITING FOR JOBS: OPEN THE COMMAND VIEW AND ASSIGN THEM" (only when the run starts, not after Keep Going). The first-run tutorial (Prompt 31) will place them. |
| 3 | The routine | "Sounds right" | The meal, work and bed times stay. Idle residents now go to a Lounge seat when the bunker has a Lounge (Section 11: they socialise in the Lounge), or stand by their bed otherwise. The Lounge has no model yet, so for now they stand in its shell; its seats come with the Lounge art. |

Tested in Studio (build `p10-0a6f76b`, code asset revision 33):
* All six founders spawned with no job. Power showed 0 made and 10 needed, with five rooms dark. The HUD chip read "10/0" in red.
* On the real client the alert slip read "6 RESIDENTS ARE WAITING FOR JOBS: OPEN THE COMMAND
  VIEW AND ASSIGN THEM" (`previews/Game/P10_Answers_IdleStart.jpg`).
* After the meal, idle residents walked to their beds in the Quarters. When a Lounge was placed
  (`/dev grid.build Lounge 1 3`), all six re-routed to it within a second and stood idle inside
  it (`previews/Game/P10_Answers_LoungeIdle.jpg`).

