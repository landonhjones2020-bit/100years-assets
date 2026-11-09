# Prompt 15: The Brood Mother and the results screen

Year 25's Surge brings the Era I boss (bible Sections 5, 10 and 22). The Brood Mother bursts up
through the deepest tunnel, lays egg sacs that hatch Burrow Ticks, and takes real damage only on
her glowing belly. When she dies the boss Surge ends and the year moves on. When a run ends, the
Run Report (Section 18) tells its story, pays every player (Section 16) and offers Play Again,
Keep Going and Return to Lobby (Section 21). Built and tested on 2026-11-09. The final install is
`p15-c2fc8a4` (code asset 95026446991297 revision 57), in Run and Lobby.

## Design Notes

**Decisions**
1. **Two rule modules, two services, two controllers** (Section 23: rules in Shared, state on the
   server).
   * `Shared.Rules.Boss` has no state: a boss's health, its phase, the arena, how far it may walk,
     hit multipliers, the weak-point test and the stagger test.
   * `Shared.Rules.Results` has no state: the payout lines, a ledger of what a run has paid,
     account experience and levels, the score and the MVP.
   * `BossService` runs the fight; `ResultsService` counts the run, pays and runs the results
     screen's buttons. `BossController` draws the HUD's boss bar and shakes the camera;
     `ResultsController` is the Run Report. Section 23 gives results to RunDirector and has no
     boss service (Bible Question 1).
2. **Arrival** (Section 10: she bursts up through the deepest tunnel).
   * The arena is the longest run of dug cells side by side on the deepest floor. With none, it
     is the widest room there that isn't the Reactor Core or a Shaft; with none, any open cell.
     In the starting bunker it is floor 2's dug cell (column 3).
   * 8 seconds of warning: dust rising from the floor, a blinking red light, and a HUD alert
     with the floor and column. The HUD's boss bar reads BREAKING THROUGH.
   * She rises out of the floor over 2 seconds in a burst of rock and roars. Players near her
     feel the camera shake.
3. **Her health** (Section 22: weaker on an account's first run). 6,000 (`Config.Bosses`) times
   the team's size (`Threat.PlayerScale`: x1 solo to x3 for six), times 0.7 if anyone in the
   run is on their first run.
4. **Hits.** Her armour takes half damage. Her glowing belly takes double (the Sharpshooter's
   own 2.5x). A blast within 4 studs of the belly and a melee swing within 3 count as belly hits.
   Fire on an egg sac does double.
5. **The fight**, ticked 10 times a second while she lives.
   * She turns towards the nearest standing player (players on her floor first) at 60 degrees a
     second, slower than a player circling her, so her flanks can be reached.
   * She walks along her arena towards them. She is too big for a doorway, so she never leaves
     it.
   * Within 18 studs she rears and slams: 30 damage to players and residents within 9 studs of
     the blow, every 3.2 s (2.4 s in phase 2). In a one-cell arena nowhere in front of her is
     safe.
   * Every 16 s (10 s in phase 2) she lays one egg sac (two in phase 2) behind her, up to six. A
     sac has 90 HP and hatches 3 Burrow Ticks after 14 s unless broken or burned first.
   * 5% of her health dealt to her belly within 3 s staggers her for 2.5 s.
   * At half health she shrieks and phase 2 starts: she lays faster and hits harder.
6. **Her death.** Her death clip plays and holds, her sacs wither, and the alert says who
   finished her. `ObjectiveService:BossBeaten` ends the boss Surge (+1 Years per Cycle) and the
   year moves on; after 4 s she dissolves into Source dust. She counts as a kill; a broken sac
   doesn't.
7. **Readable in the dark.** A green light above her lights the tunnel around her, so her body
   reads against the rock (the art has no lights of its own).
8. **Her clips play on the server**, not on clients as Section 23 says for monsters (Bible
   Question 2). The server judges belly hits against her parts, and her LayEggs clip moves the
   belly 2.6 studs, so the server must see the pose players see. They replicate; `NPCAnimator`
   skips a model marked `ServerAnimated`.
9. **Shots can reach her belly.** Her body parts' raycast shape is a Hull instead of a Box: with
   Boxes, the abdomen's box swallowed the belly and the legs' boxes caught most shots. Her
   invisible root no longer collides or catches shots, so players can step in under her.
10. **The HUD's boss bar**, under the cycle bar: THE BROOD MOTHER on a navy plate, BREAKING
    THROUGH, PHASE 1 OF 2 or DEAD, and her health draining in rust red.
11. **What a run counts.** For each player: damage to monsters, kills, damage to bosses,
    revives, cells dug and HP repaired. For the team: monsters killed, cells dug, rooms built,
    residents alive and lost, disasters and bosses beaten. And the run's story, each line with
    its year: a resident's death, a nest dug into, a meltdown and three valves stopping it, a
    boss struck down, a Push Deeper, a Tremor, and how it ended.
12. **Payouts** (Section 16), to every player in the run when it ends:
    * 1 Glowshard per 4 years survived, 3 per depth band reached, 15 for a Century Victory or 30
      for a Deep Victory, 2 per boss killed;
    * the difficulty's payout multiplier as its own line (Hard x1.5, Nightmare x2);
    * the first win of the day (UTC) doubles a victory's payout;
    * account experience: 10 per year survived, with level ups;
    * the profile's Stats (Runs, Wins, BestYear, Deepest, BossesKilled, MonstersKilled,
      LastWinDay) and `FirstRunDone`, saved at once.
    A ledger per player means a run that ends again after Keep Going pays only what is new.
13. **The MVP.** A player's score adds their numbers times weights (`Tuning.Results.MVP`); the
    highest score is the MVP (a tie goes to the lower user id, so every server agrees).
14. **The Run Report** (Section 18's Results row: summary, residents, rewards; stats, stories,
    payouts; MVP card; Play Again).
    * Summary: how the run ended, the year and era, the deepest floor and band, the time and
      cycles, the team's numbers, then the story.
    * Residents: everyone who lived in the bunker, alive (level and job) or how they died.
    * Rewards: your payout line by line, your total, your account experience and level, and the
      team's payouts.
    * The MVP card: their avatar, class, score, and their fighting and helping numbers.
    * Play Again is the main action; the footer has Keep Going (after a victory, not in Endless)
      and Return to Lobby. It opens 4 s after the run ends and comes back 10 s after it is
      closed while the run is over.
15. **The buttons** (Section 21).
    * Play Again opens a team vote (`Config.Votes.PlayAgain`: 20 s, a majority of the whole
      team; solo it passes at once). A pass reserves a fresh Run server and sends everyone there.
      Studio can't teleport, so there it says so.
    * Keep Going opens the Keep Going vote (Section 5); a pass starts Endless and closes the
      screen.
    * Return to Lobby sends that player to the lobby.
    Prompt 21 adds the party list and loadouts through MemoryStore.

**Design Risks**
* **Her belly hides under her.** It is the underside of her abdomen, towards her back, and her
  head guards it from in front. From beside her, 27 of the spots tried (24 directions at 9, 11
  and 13 studs, inside her cell) had a clear line from a player's gun to the belly. A lone player
  has to flank her while she lays eggs or step in under her chin. Armour takes half damage, so
  the fight can still be won without it.
* **A long solo fight.** The Service Revolver does 68 a belly hit and 17 on armour: 62 belly
  shots or 247 armour shots on a first run (4,200), 89 or 353 after it (6,000). By Year 25 the
  team should have better guns.
* **Egg sacs pile up.** Unbroken sacs hatch 3 ticks each; in one test 15 ticks hatched while
  nobody broke the sacs.
* **Stagger is hard alone.** 300 belly damage in 3 s at 6,000 health: one Revolver reaches it only
  with five belly hits at its full rate (340 in 2.9 s; the test's slower shots did 272). A team or
  a shotgun gets there easily.
* **Payouts go only to players in the run when it ends.** A player who drops loses their payout
  until Rejoin (Prompt 21).
* **The first win of the day** uses the UTC day, so it resets in the evening for players in the
  Americas.

**Scope Risks**
* Teleports (Play Again, Return to Lobby) can't run in Studio: the vote and the messages were
  tested, the teleport needs live servers. The party list and loadouts are Prompt 21's.
* The VIP bonus (`Tuning.Account.VIPGlowshardBonus`, +25%) waits for passes (Prompt 28); the boss
  badge (`Config.Bosses.Badge`) and quests wait for their services.
* The other bosses (Prompts 23 to 25) reuse BossService with their own behaviours.
* Her roar, slam and death sounds wait for Prompt 32.

**Bible Questions**
1. **Where results and bosses live.** Section 23 lists results under RunDirector and has no boss
   service. Built: `ResultsService`, because RunDirector is a dependency of most services, and
   results listen to combat, digging, building, disasters and bosses (that would be a dependency
   loop); and `BossService`, because a boss fight is a scripted encounter with an arena, phases
   and egg sacs, while MonsterService keeps the ordinary AI. Add both to Section 23?
2. **Bosses' clips on the server.** Section 23 plays animations on clients. Her clips play on the
   server so belly hits are judged against the pose players see. OK for bosses?
3. **Her numbers.** 6,000 health times the team's size, 0.7 on a first run; armour x0.5, belly
   x2; a 30-damage slam; sacs of 90 HP hatching 3 ticks after 14 s; a stagger at 5% of her
   health in 3 s. Right?
4. **The arena.** The longest dug run on the deepest floor, else the widest room that isn't the
   Reactor Core or a Shaft, else any open cell. Right?
5. **Payouts.** Only players in the run when it ends are paid; after Keep Going a later end pays
   only what is new; the first win of the day doubles victories only, by the UTC day. Right?
6. **The MVP.** Score weights: damage 0.1, kills 10, revives 25, cells dug 15, HP repaired 0.05,
   damage to bosses another 0.1. Right?

**Recommended Improvements**
* A clip where she rears up and shows her belly to the front for a moment, a window for lone
  players.
* Cracks spreading on the floor during her warning (decals), and her sounds (Prompt 32).
* A big boss nameplate over her instead of the ordinary monster health bar CombatController
  gives every monster it hits (billboards don't show in captures, so not seen yet).
* Egg sacs that pulse faster as they near hatching.
* Each player's payout in the Rewards tab for a team.

**Technical Risks**
* A part that collides is always hit by raycasts, whatever its `CanQuery`. Her root box caught
  shots meant for her belly until it stopped colliding (found in the playtest).
* Rig parts use the cheap Box raycast shape (`query`). A boss's body uses `queryhull`, a new
  collision kind in steadfast, `STYLE.md`, `AssetSetup` and the Beast rig. The Brood Mother in
  Studio was changed directly; her generator and sidecar now say `queryhull`, so the next export
  keeps it.
* Her clips on the server: one rig with 23 joints, cheap.
* The results are one table in the `Results` collection (a few KB for six players). Each player's
  profile is saved once when the run ends.

## Delivery Report

**Overview.** The Brood Mother's fight runs end to end in the Run place. Year 25's boss Surge
starts it; she breaks in at the deepest tunnel after a warning, slams, lays egg sacs that hatch
Burrow Ticks, staggers when her belly is hit, enters phase 2 at half health, and dies with her
death clip, ending the Surge. Real Revolver shots hit her belly for double, real shots broke a
sac, the Flamethrower burned one. The HUD has a boss bar. When the run ends, every player is paid
and their profile saved, and the Run Report shows the summary, the story, the residents, the
rewards and the MVP, with Play Again, Keep Going and Return to Lobby.

**Files created**
* `game/shared/Rules/Boss.luau`, `game/shared/Rules/Results.luau`
* `game/places/Run/server/Services/BossService.luau`, `ResultsService.luau`
* `game/places/Run/client/Controllers/BossController.luau`, `ResultsController.luau`
* `studio/ui/HUD_Boss.lua` (the boss bar), `studio/ui/patches/HUD_P15.lua`
* `previews/Game/P15_*.jpg`

**Files modified**
* `Config.Tuning`: `Bosses`, `BroodMother`, `Results`. `Config.Votes`: `PlayAgain`.
  `Remotes`: `PlayAgain`, `KeepGoing`, `ReturnToLobby`. `UIContract`: the HUD's `BossBar`.
* Services: `CombatService` (`KeepModel`: a boss plays its death before it dissolves;
  `Dissolve`; a `god` dev command), `WeaponService` (`SetHitModifier`: armour, weak points and
  burning sacs scale a hit), `ThreatDirector` (`IsFirstRun`), `DigService` (`Dug` passes who
  finished the cell).
* Client: `NPCAnimator` skips `ServerAnimated` models. `studio/ui/HUD.lua` includes the boss bar.
* DevTools: `StructureCheck` (the new modules and the boss bar), `DataTests` (99 tests; 4 new:
  her health, phases and hits; the arena; payouts and the ledger; experience, levels and the
  MVP).
* Art pipeline: `generators/lib/steadfast.py`, `STYLE.md`, `studio/AssetSetup.lua` (the
  `queryhull` kind; reinstalled in Run), `generators/Monsters/_beast.py`,
  `generators/Bosses/Boss_BroodMother.py`, `exports/Bosses/Boss_BroodMother.json`.
* `game/BUILD.json` (prompt 15), `manifest.csv`, `game/docs/ARCHITECTURE.md`, `BUILD_LOG.md`,
  `HANDOFF.md`.

**Architecture**: `game/docs/ARCHITECTURE.md`, section "Bosses and results".

**Integration notes**
* **Prompts 23 to 25 (The Deluge, the Crystal Colossus, the Source)**: a boss needs a
  `Config.Bosses` entry, a `Tuning.<BossId>` entry, its model in `ServerStorage.Assets.Bosses`
  (a `WeakPoint` part, sockets, `queryhull` body parts) and its clips in `Config.Animations` with
  its id as the Rig. Their fights differ (flooding rooms, flares, tendrils): give BossService a
  behaviour per boss when the Deluge comes. The final Surge's victory: `RunDirector:Win("Century")`
  after the Source's `BossBeaten`.
* **Prompt 16 to 18 (surface, the Deep, expeditions)**: add hauls, rescues and Lost Crews to the
  story with `story(text)` in ResultsService and to the stats with `bump`.
* **Prompt 20 (classes)**: the Sharpshooter's `WeakPointMultiplier` is already read
  (`Modifiers.ClassValue`). Class experience from runs goes in `pay`.
* **Prompt 21 (Lobby)**: Play Again's teleport and Return to Lobby are in ResultsService
  (`teleport`); write the party list and loadouts to MemoryStore first. Rejoin: pay players who
  come back (`RunDirector:Summary().Players` lists everyone who played).
* **Prompt 28 (shop)**: the VIP bonus as a payout line in `Rules.Results.Payout`.
* **Badges and quests**: `BossService.Defeated` and `RunDirector.RunEnded`.
* **Prompt 32 (sound)**: her roar (Rising, phase 2), the slam (`AttackAt` plus `HitTime`), egg
  sacs hatching, her death.

**Testing checklist (done in Studio, 2026-11-09)**
- [x] Installed `p15-c2fc8a4` in both places: StructureCheck 0 errors (Run 422 checks, Lobby
  244), 99 data tests passed in each. The Run place boots cleanly with it.
- [x] The HUD patch: `StarterGui.HUD.BossBar` in the Run place.
- [x] `boss.start`: the warning (dust, the red light, "THE BROOD MOTHER IS BREAKING THROUGH:
  FLOOR 2 · COLUMN 3 · 8 S", the bar BREAKING THROUGH; `P15_BroodMother_Warning.jpg`), the rise
  and roar (`P15_BroodMother_Roar.jpg`). The camera turned 2.75 degrees in one frame as she broke
  through (the shake), the player standing still.
- [x] The real boss Surge: from Year 24, cycle 2's Surge was "Boss (BroodMother)", "no timer,
  until BroodMother is beaten", and started her fight. Her death ended it ("Boss Surge over
  (Boss)"), the year went to 27 and Era II began (`P15_BossSurge_LastBlow_EraII.jpg`).
- [x] Health: 4,200 on the test account's first run (solo), 6,000 after `FirstRunDone`.
- [x] Real Service Revolver shots: 5 of 5 shots from beside her did 68 each (belly). Before the
  fixes, shots aimed at the belly hit her abdomen's box and then her root's box and did 17
  (armour); found by a ray scan, fixed (Hull shapes, the root stops colliding).
- [x] Slams hit the player for 30; sacs were laid behind her (one at a time in phase 1, two in
  phase 2) and hatched 3 Burrow Ticks after 14 s; real Revolver shots broke a sac (90 damage, not
  counted as a kill); the Flamethrower burned one inside a 1.4 s hold.
- [x] A stagger at 300 belly damage (`boss.hurt 300 weak`); phase 2 at half health with the
  shriek (`P15_BroodMother_Phase2_Ticks.jpg`).
- [x] Her death: the Death clip, the bar DEAD, the alert, the objective (+1 Years per Cycle),
  dissolved after 4 s (`P15_BroodMother_Death.jpg`); with a player's last blow, the alert names
  them (shortened after the capture showed it cut off) and the story says "... struck the Brood
  Mother down".
- [x] `run.win century` with the test account: 40 Glowshards (3 for the Mines, 15 for the win, 2
  for her, doubled as the first win of the day; Year 1 has no years to pay), +10 experience; the
  profile went from 70 to 110 Glowshards with `FirstRunDone` true, and was saved.
- [x] The Run Report: Summary, Residents and Rewards tabs clicked for real; the MVP card with the
  avatar (`P15_Results_Summary.jpg`, `P15_Results_Rewards.jpg`, `P15_Results_Residents.jpg`).
- [x] Real clicks: Play Again (solo, passed at once: "PLAY AGAIN PASSED · TELEPORTS DON'T WORK IN
  STUDIO", `P15_Results_PlayAgain_Studio.jpg`), Return to Lobby (the same message), Keep Going
  (Endless started and the screen closed, `P15_KeepGoing_Endless.jpg`).
- [x] After Keep Going, a defeat in Year 9 paid only the new years (2 Glowshards, +80
  experience), no second win, no second run counted (`P15_Results_Defeat_Endless.jpg`).
- [x] Stories: a meltdown starting, a Push Deeper, a Tremor, residents' deaths with their names
  (the first try said "A resident"; fixed).
- [ ] Not seen: a fight with several players (her targets, the MVP between players, a Play Again
  vote with others), real teleports (live servers only), the meltdown-stopped story (valves were
  tested in Prompt 13), the Run Report coming back 10 s after being closed, the slam's shake on
  screen.

**Future extension notes**
* A new boss: see Integration notes; its numbers in `Tuning.<BossId>` (the Brood Mother's keys
  are the template) and `Config.Bosses`.
* A new stat: add it to `STAT_KEYS` in ResultsService, give it a weight in
  `Tuning.Results.MVP`, and show it in ResultsController's MVP card.
* A new payout: a `Config.GlowshardRewards` entry and a line in `Rules.Results.Payout` (the
  ledger keeps it from paying twice).
* A new story line: call `story(text)` in ResultsService from the signal that marks the moment.

## Landon's answers (2026-11-09)

"All of that is ok": all six Bible Questions approved as built. BossService and ResultsService are
in the bible's Section 23 service table (RunDirector no longer owns results), bosses' clips play on
the server (Section 23, Residents and monsters), and the payout rules are a line under Section 16's
table. Live doc revision 133; project part 2 refreshed.
