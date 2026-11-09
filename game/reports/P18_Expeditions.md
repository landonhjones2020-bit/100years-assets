# Prompt 18: Resident expeditions and distress calls

Residents can now be sent out of the bunker (bible Sections 6, 8, 11, 12 and 18). From the Blast Door
guard's radio or a Radio Room, 1 to 3 residents set out for the surface or the Deep for 1, 2 or 3
cycles, with Food, Water and Medkits from the stockpile. They walk out through the Blast Door and
leave the map. Every cycle their log gets a line, they find Scrap, Food, Water or the band's ore,
and something may happen: someone hurt, someone lost, or a distress call. A distress call puts a
marker in the town or a cave, and the team has until the end of the next day phase to reach them.
The Radio Room also brings in recruits and picks up the Lost Crews' calls. Built and tested on
2026-11-09. The final install is in `BUILD_LOG.md` (code asset 95026446991297), in Run and Lobby.

## Design Notes

**Decisions**
1. **One service, one rule module, one controller** (Section 23: ExpeditionService owns "resident
   expeditions and distress calls").
   * `Shared.Rules.Expeditions` has no state: who can go, the supplies, the risk and odds, what
     happens in a cycle, the team's carrying and finds, harm, the deadline, recruit tiers and the
     log lines' words.
   * `ExpeditionService` (server): the consoles, sending, each cycle away, coming home, distress
     calls, the Radio Room. `ExpeditionsController` (client): the Expeditions screen and the
     distress markers.
   * Content is data: the log lines are `Config.ExpeditionLogs` (draft text, Landon's to change),
     the numbers `Tuning.Expeditions`, the finds the existing `LootTables` ExpeditionSurface and
     ExpeditionDeep.
2. **Where they leave from** (Section 12: "From the Radio Room or the Blast Door").
   * An EXPEDITIONS prompt sits on the radio on the Blast Door guard's desk (the A1 kit's
     `GuardDesk`), and on a radio set in every Radio Room. The Radio Room has no art until A7, so its
     set is the A6 radio recorder on the floor.
   * The server checks that the sender is within 30 studs of a console (`UseRange`).
   * Sending is never voted (Section 8).
3. **The team, length and supplies** (Section 12: "send 1 to 3 residents ... for 1, 2 or 3 cycles,
   with gear and supplies").
   * Alive residents in the bunker, not cut off by rubble.
   * Food and Water for every member for every cycle come out of the stockpile: what they would
     have eaten at home.
   * Up to 3 Medkits.
   * Whatever isn't used comes home with them.
   * Gear waits for resident gear (Prompt 26).
4. **They leave the map.**
   * Each member leaves their job and walks to the Blast Door. Their body goes when they reach it,
     or after 40 s whatever is in the way.
   * While away they have no body, eat nothing from the stockpile, don't work, and nothing in the
     bunker can hurt them.
   * Deep expeditions leave through the Blast Door too: they leave the map.
   * In the Residents screen they are on the new AWAY tab.
5. **Time away is counted in dawns.** At each dawn after they set out, an expedition lives one
   cycle. After its last cycle it comes home at dawn. A trip sent late in a day has a short first
   cycle (a Design Risk).
6. **Each cycle away:**
   * They eat their packed Food and Water.
   * They gain 40 experience (`XPPerExpeditionCycle`; Section 11). With no job, a level goes into
     their best stat.
   * They find the loot of the day (Decision 8).
   * One thing happens, and its line goes in the expedition's log and every member's run log.
7. **Danger** (Section 12: "length and danger depend on Speed, Grit, gear and supplies"; Section 11:
   Grit resists harm, Speed is fleeing).
   * The team's Risk: its average of Grit and Speed against 5, 0.08 less for each point above and
     more for each point below, kept between 0.4 and 1.5.
   * The chances each cycle are someone hurt 20%, a distress call 15% and someone lost 5%. The
     bible's provisional 15% and 5% are kept; hurt is ours. Each is multiplied by the destination
     (surface 1, Deep 1.3) and the Risk.
   * Someone hurt loses 20 to 45% of their max health, never below 1 ("they can come back hurt").
     A packed Medkit halves it.
   * Someone lost is gone at once. If a Medkit is packed, it is used and they come back badly hurt
     instead.
   * Gear will lower the Risk in Prompt 26.
8. **Finds** (Section 12: "Scrap, ore, gear, blueprints and sometimes a recruit").
   * Each cycle the destination's loot table is rolled once (its 2 rolls). The resources are
     multiplied by the team's carrying: each member carries 0.5 + Strength x 0.1 (Section 11:
     Strength is carrying on expeditions). Two average residents carry twice what one does.
   * A member's own `ExpeditionCarry`, `ExpeditionLoot` and `ExpeditionScrap` count too. That
     covers the Strong Back, Lucky and Scrounger traits and Lucky Lou. No resident has traits or a
     Legend yet (Prompts 26 and 27), so the code is in place but nothing uses it yet.
   * A Deep expedition goes to the band of the bunker's deepest floor and finds its ore.
   * A trip brings home at most one recruit, Rare 20% of the time.
   * Gear and blueprints are skipped until Prompts 26 and 19.
9. **Coming home.**
   * They step into the Blast Door hall at dawn after their last cycle.
   * The finds go into the stockpile (the caps apply), with the supplies left.
   * Any recruit joins in the hall.
   * Each goes back to the job they left if it still has room, else they wait for one (an alert
     says who).
10. **Distress calls** (Section 12: "a marker appears and players have until the end of the next
    day phase to reach them, or they are lost along with their loot").
    * The call is rolled at dawn and comes 40 to 140 seconds into that day of running clock
      (`CallDelay`). The Radio Operator's `DistressCallLeadSeconds` makes it come 30 seconds sooner.
    * Everyone gets the radio card (the caller's message, from `ExpeditionLogs`) and an alert.
    * Where the team is pinned down:
      * on the surface, a free survivor spot in Brightwater Ruins;
      * in the Deep, a piece of a cave the bunker has opened;
      * with no cave open, the rock face of the deepest floor's outermost dug cell.
    * Each member waits with a HELP prompt (hold 3 s, RescueService Kind Expedition, with their
      own name and health).
    * The marker is a red flare column (220 studs over the town, 12 in a cave) with a plate that
      shows through walls from anywhere: DISTRESS CALL, the time left, who and where. An arrow at
      the screen's edge points to it while it's off screen.
    * Reached, they follow home like rescued survivors. The first one home brings the finds.
    * The deadline is when the Surge of the cycle after the call starts, which is the end of the
      next day phase. Whoever is still pinned down then is lost. If nobody else made it home, the
      finds are lost too.
11. **The Radio Room** (Section 6: "Recruits survivors, places supply calls, hears distress
    calls"; Charm).
    * Its Recruits output (0.15 a cycle at base, by the Section 13 formula) times the team's best
      `RecruitRate` adds up while the clock runs. Each whole point brings a recruit to the Blast
      Door: level 1 to 3, Rare 15% of the time times `RareRecruitChance`.
    * While a Lost Crew is still out and a Radio Room is staffed and lit, it picks up that crew's
      own call every 2 cycles (Section 12: "radio logs and the Radio Room give hints").
    * No recruit comes past the resident cap of 40.
    * Why here: `Config.Modifiers` tags RecruitRate and RareRecruitChance for Prompt 18, and the
      Radio Room is where the radio lives. The Supply Call is the Radio Operator's ability
      (Prompt 20).
    * `ExpeditionService:Recruit(tier, how)` is ready for Prompt 19's Radio Booster and Veteran
      Recruit cards.
12. **Bunker-wide modifiers.** RecruitRate, RareRecruitChance and DistressCallLeadSeconds use the
    best value any player's class gives (the Radio Operator: x1.3 recruits, 30 s sooner, x1.5 Rare
    at level 3), plus anything set through `SetModifier` (draft cards, Legends).
13. **The Expeditions screen** (Section 18: "Surface, Deep, active | Teams and destinations |
    Supplies and risk; Send").
    * SURFACE and DEEP: the residents who can go, as cards showing Grit, Speed, Strength and their
      job. A card joins or leaves the team (three at most). The footer sets the length and the
      Medkits.
    * Zone D: the destination, the team, when they'd be back, the supplies against the stockpile
      (the top bar has Food, Water and Medkits), the risk each cycle in words and percents, and a
      cycle's average finds. SEND (or Enter, or Y) sends them.
    * ACTIVE: a card for each trip out (green away, red pinned down, amber on the way home). Zone D
      shows its team, return or deadline, finds, supplies and log.
14. **Results.** Trips home (with what they brought), distress calls answered and recruits go in
    the run's story. Residents lost away appear through their deaths.

**Design Risks**
* A trip sent just before dawn gets a full cycle's finds for a short cycle. It still costs a cycle
  of the members' work and their supplies.
* Expeditions are a strong Scrap source. In tests a 2-resident surface trip found 89 to 120 Scrap a
  cycle, and a 3-resident Deep trip 53 Scrap and 35 Iron in two cycles. Tune against the
  Section 13 income targets.
* Losses can be heavy. Three residents lost at once to a missed distress call is a big hit in
  Era I. Grit, Speed and Medkits lower it, but a careless player can lose a third of the bunker.
* With no cave open, a Deep call is answered by walking to the bottom of the bunker.
* A call that comes during a day gives the rest of that day, the Surge and the whole next day, up
  to about 7:30. A call that comes during a Surge gives less.
* Answering a surface call during a Surge means going out in the storm.

**Scope Risks**
* Gear (Prompt 26): there is no gear on the screen, no armed residents and no Ammo as a supply.
  Blueprints from expeditions wait for the draft (Prompt 19).
* Traits and Legends: the expedition effects (Strong Back, Lucky, Scrounger, Lucky Lou) are wired
  through `Rules.Expeditions.Team`, but residents don't carry effects until Prompts 26 and 27.
* Quests (Prompt 29): "finish 2 resident expeditions" can listen to `Returned`.
* The Radio Room's art is A7. Until then it is a graybox room with the radio recorder on the floor.
* Not tested: four players, touch, and a surface trip answered during a storm.

**Bible Questions**
1. **Speed and length.** Section 11 says Speed affects "expedition length". Built: the players
   choose the length, Speed and Grit lower the danger, and Strength carries the finds. Should a
   fast team come home sooner, or go further?
2. **Supplies.** Built: Food and Water for every member for every cycle are required, and Medkits
   are optional (they patch people up). Should anything else count as supplies, such as Ammo once
   residents carry guns?
3. **The deadline.** Built: "the end of the next day phase" is the end of the day of the cycle
   after the call. A call during day 4 can be answered until day 5's Surge. Or is it the current
   day when the call comes during a day?
4. **Reaching them.** Built: hold HELP at the marker, then lead them home like rescued survivors.
   Anyone still pinned down at the deadline is lost. Or should reaching the marker bring them home
   by itself?
5. **Deep calls.** Built: in a cave the bunker has opened, else at the rock face of the deepest
   floor. OK?
6. **The Radio Room.** Built here: recruits from its output (Rare 15%), a Lost Crew's call every 2
   cycles, and distress calls that come through with or without a Radio Room. Should a distress
   call need a Radio Room to be heard?
7. **Losses.** Built: a resident lost on an expedition is gone at once, with no revive window
   (Section 11's 20 seconds is for the fallen in the bunker). OK?
8. **Finds and recruits.** Built: a trip brings home at most one recruit. Should a long trip bring
   more?

**Recommended Improvements**
* Guards at a distress spot: a few jackals or raiders, asleep until a player comes near (the raider
  camp's code), so answering a call is a fight.
* An EXPEDITIONS button in the Command View's footer, and a "same team again" action.
* A HUD chip counting expeditions out.
* A7's Radio Room with a `Console` socket. The code already uses one if the room's art has it.

**Technical Risks**
* "Away" is a new `State` for residents. Code that checks `State == "Alive"` treats them as gone
  from the bunker, which is intended. Code that checks `State ~= "Dead"` counts them as in the run
  (the cap, Workers).
* Pinned members are placed side by side, 2.2 studs apart. In a tight survivor spot one could stand
  up inside a wall.
* The marker's countdown is worked out on the client from the clock's phase lengths, so skipping a
  day (Ready) makes it jump.
* A resident was seen at 0 health in the first playtest (Yuki Gallo), before this prompt's code
  set 0 for the lost. A repeat with Vera Foster showed the expedition code doesn't change health.
  The cause was probably the monsters loose in the bunker after a skipped Surge; not reproduced.

## Delivery Report

**Overview**: resident expeditions (sending, cycles away, finds, harm, losses, coming home),
distress calls with world markers, the Radio Room's recruits and crew calls, the Expeditions
screen, and the Residents screen's AWAY tab.

**Files created**
* `game/shared/Rules/Expeditions.luau`: the pure rules.
* `game/shared/Config/ExpeditionLogs.luau`: the log lines and radio calls.
* `game/places/Run/server/Services/ExpeditionService.luau`.
* `game/places/Run/client/Controllers/ExpeditionsController.luau`.
* `studio/ui/HUD_Expeditions.lua` and `studio/ui/patches/HUD_P18.lua`: `HUD.Templates.Distress`,
  the marker's plate (applied in Run).
* `game/reports/P18_Expeditions.md` (this report).

**Files modified**
* `Config/Tuning.luau`: Tuning.Expeditions' schema and numbers.
* `Remotes.luau`: `SendExpedition`; the `RadioLog` doc.
* `UIContract.luau`: the Distress plate.
* `Rules/Residents.luau`: the State type gains Away.
* `ResidentService`:
  * `SetAway`, `Wound`, `GainXP`, `Note`, `Lose`, `Count`;
  * Assign refuses the away;
  * a quiet death for the lost.
* `ResidentBrain`: walking out through the Blast Door; no body while away.
* `RescueService`:
  * residents already in the run (Options Resident, Health, Label, Action);
  * the Expedition kind;
  * arrivals with HealthLeft and HomeAt.
* `SurfaceService`: `DistressSpot`.
* `DeepService`: `DistressSpot`, `CrewCall`, `PlayLog`.
* `ResultsService`: expedition stories.
* `ResidentsController`: the AWAY tab.
* DevTools: DataTests (2 tests, 107 in all) and StructureCheck.
* `BUILD.json` (prompt 18), `docs/ARCHITECTURE.md` and `studio/ui/HUD.lua`.

**Architecture**: `game/docs/ARCHITECTURE.md`, section "Expeditions and the radio".

**Integration notes**
* Prompt 19 (draft):
  * Radio Booster calls `ExpeditionService:Recruit` twice; Veteran Recruit calls it with "Rare".
  * Blueprint finds can stop being skipped (`SKIP` in ExpeditionService).
  * Cards that change recruits use `ExpeditionService:SetModifier`.
* Prompt 20 (classes): the Radio Operator's Supply Call. Its passive and level 3 already apply here
  (read from the player's Class and ClassLevel).
* Prompt 26 (residents, phase 2): gear on the screen and in the Risk; Ammo for armed members;
  members' trait effects through `effectsOf` in ExpeditionService.
* Prompt 27 (Legends): Lucky Lou through `effectsOf`; Wren Holloway's RecruitRate through
  `SetModifier`.
* Prompt 29 (quests): `ExpeditionService.Returned` for "finish 2 resident expeditions".

**Testing checklist (done in Studio, 2026-11-09, three Run playtests)**
* Starting up: the Run server starts with 29 services and the client with 21 controllers.
  StructureCheck (461 checks in Edit, 551 at play start) and the 107 data tests pass, in Run and
  Lobby.
* The hall's console on the guard's desk:
  * EXPEDITIONS / Blast Door radio shows within reach;
  * E (real key) opens the screen.
* The Expeditions screen, with real clicks and keys:
  * resident cards join and leave the team;
  * the footer sets the length (1 to 2) and Medkits (0 to 1);
  * risk and finds show (hurt 16%, distress 12%, lost 4% for Grit 6 and Speed 9);
  * SEND by mouse, and Enter from the DEEP tab, sent both trips;
  * the screen moves to ACTIVE;
  * the stockpile chips dropped by the supplies.
* Leaving: both members walked to the Blast Door and their bodies went (about 20 s from floor 2).
  `residents` showed AWAY with no job. The Residents screen's AWAY tab listed them.
* A dawn on the real clock (`clock.next`): E1 lived a cycle ("searched the grocery from top to
  bottom", +5 Food +43 Scrap). The members gained 40 XP.
* A distress call:
  * `exp.call`;
  * the natural roll: a forced Distress, then the call came 104 game seconds later with the clock
    at x10;
  * the radio card ("Rita Garza calling the bunker. Raiders all round the water tower...");
  * the alert;
  * the red flare column over the water tower, seen from the elevator exit 218 studs away;
  * the plate's text and countdown (5:19 = the day's rest + the Surge + the next day);
  * the edge arrow at the screen's edge, drawn over the HUD.
* Reaching them, on the surface:
  * held E on HELP (Rita Garza, then Yuki Gallo);
  * the marker went;
  * rode down with both following; both stepped in home;
  * the finds and the supplies left went into the stockpile (+43 Scrap, +5 Food, +2 Food, +2 Water,
    +1 Medkit);
  * the story: "IHateTheLogInPuzzles answered a distress call".
* The deadline on the real clock: still pinned at cycle 3's Surge (the deadline was cycle 4), lost
  at cycle 4's Surge. Both died ("lost waiting for help"), the expedition was lost, and the rescue
  models were removed.
* A normal return (`exp.cycle`): they stepped into the hall, went back to the Water Purifier
  they'd left, and +16 Water +89 Scrap went into the stockpile.
* The Deep:
  * a team sent from the Radio Room's console found Iron;
  * a forced Hurt with a Medkit halved the harm (Irving Bell 82 to 73);
  * the trip brought a recruit;
  * a call put them in a cave piece ("a cave off the Mines, floor 2, three cells east of the
    shaft"), with the flare in the cave;
  * freed all three (E);
  * led them out of the cave on a pathfinding walk;
  * all three home, back to their jobs (Reactor Core, Water Purifier, Kitchen);
  * the recruit (Marvin Cobb) joined.
* The Deep with no cave: the team waited at the rock face of floor 2's outermost dug cell (after
  the fix; before it they were in the Shaft).
* Losses (`exp.cycle Lost`, three times):
  * a packed Medkit made the first a bad hurt ("a Medkit kept them going");
  * the second lost Ida Rhodes;
  * the third lost Gus Riley and the expedition;
  * both are dead at 0 health.
* The Radio Room:
  * built at 1,3 with a radio set on its floor and its EXPEDITIONS / Radio Room prompt;
  * two Charm workers made 0.105 recruits a cycle;
  * 120 game seconds added 0.05 (x40 clock);
  * as a Radio Operator: x1.30, a 30 s lead;
  * `recruit Rare` brought Woody Bishop (Rare, Charm 14) to the hall;
  * `radio call` played the raider camp crew's call with "Last heard from: Brightwater Ruins, a
    raider camp behind the motel, by the rail yard."
* Refusals: a downed resident ("Someone in the team is down or gone.") and an unknown id.
* The run's story listed:
  * the recruit;
  * the answered calls;
  * "Irving Bell, Lou Hooper and Ida Dunn came back from the Deep (+53 scrap · +35 iron · a
    recruit)".
* No errors on the server or the client.
* Not tested: four players, touch, a call answered in a storm, two calls at once, and the dawn crew
  call on the real clock (`radio call` played the same code path).

**Future extension notes**
* Distress-spot guards (see Recommended Improvements) can use `MonsterService:Spawn(type, at, tag,
  { Guard = range })` from SurfaceService's camp.
* New expedition events (a cache found, a trader met) are a new `Event`, log lines in
  `ExpeditionLogs`, and a branch in `live`.
* New destinations (Update 2's Interstate 9, Update 3's Fungal Depths) mean a loot table, a
  `Danger` entry, log lines and a distress spot source.
