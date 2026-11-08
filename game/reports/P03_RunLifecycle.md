# Prompt 3: Run lifecycle and CycleClock

Cycles, phases, the year counter, Years per Cycle, skips, win and lose stubs (bible Sections 4,
5 and 23). Built and tested in Studio on 2026-11-08, builds `p3-ba1c9d7` and `p3-f551fd9`, Run
place (the Lobby only got the shared changes).

## Design Notes

**Decisions**
1. **Three services, named by the bible's service table.** `RunDirector` (the lifecycle, win
   and lose, Endless), `CycleClock` (cycles, day and Surge phases, the year counter, Years per
   Cycle, skips) and `ObjectiveService` (Lost Crews rescued, era bosses beaten, their Years per
   Cycle bonuses). ObjectiveService is only a record for now, so Years per Cycle has its real
   owner from the start; the prompts that rescue crews and beat bosses call it.
2. **The arithmetic is pure and tested against the bible** (`Shared.Rules.Clock`). With nothing
   done a century takes exactly 100 cycles, with boss Surges in cycles 25, 50 and 75. Rescuing a
   crew every 2 to 4 cycles and beating the bosses takes 15 to 19 cycles, inside the bible's
   "about 13 to 20".
3. **"Passes 25" means reaches or passes it**, since the boss table says "Brood Mother, Year 25".
4. **The boss Surge comes once.** A boss that isn't beaten by the end of its Surge gives no +1
   and doesn't come back. The pace line ("a team that completes nothing needs 100 cycles") only
   works if a boss can go unbeaten. This is Bible Question 1.
5. **Every Surge lasts 1:30 or ends early when cleared**, boss and final Surges included (bible:
   "A Surge ends as soon as its last monster dies and its disaster is fixed"). Surviving the
   final Surge to its end is a Century Victory. See Bible Question 2.
6. **One source for the numbers.** Years per Cycle = 1 + the `YearsPerCycle` of each objective
   done (`Config.Objectives`). The copies in `Tuning.Clock` (`LostCrewBonus`, `BossBonus`,
   `EraEnds`) were removed; era ends come from `Config.Eras`. A data test checks +2 a crew, +1 a
   boss and 12 with everything done (the cap).
7. **Skips.** When every player whose session is ready has pressed Ready or is resting in a
   Quarters bed, the day jumps to the siren (20 s left). Ready resets at the siren and at the
   start of each day. Resting lasts until the bed interaction clears it. Players still loading
   don't count. Ready outside a day before the siren is ignored.
8. **Times are server time.** RunState carries when the phase ends (`PhaseEndsAt`, from
   `workspace:GetServerTimeNow()`), so clients count down themselves. Attributes change only at
   phase changes, never once a second.
9. **Small values replicate as attributes** (bible Section 23) on `Shared.RunState`: one list
   with types and allowed values, and one writer per value.
10. **Endless.** Keep Going after a victory removes the year cap and the era bosses, and every
    Surge becomes an Endless one. There are no more wins in Endless; the run ends on a defeat.
11. **The run starts** when the first player's session is ready, after the 30 s intro. The run
    clock starts at the 30-second mark for everyone (skipping the cutscene is personal).
12. **Place-only code and remotes.** Run services live in `game/places/Run`. `SetReady` has
    `Place = "Run"`, so the Lobby never creates it. StructureCheck fails a place that has the
    other place's services or remotes.

**Design Risks**
* With Decision 4, surviving 90 s gets a team past an era boss without beating it. If Bible
  Question 1 goes the other way, the change is in `Rules.Clock` (StartSurge/EndCycle) and its
  data tests.
* A solo player who stays in a Quarters bed sleeps through days, because a resting player
  counts as ready the moment a day starts (Bible Question 4).

**Scope Risks**
* Left to their prompts:
  * the intro is a timer only (cutscene playback, Prompt 22);
  * the results screen (Prompt 15) and the Keep Going vote (Prompt 8);
  * waiting for the whole party, the run's difficulty from the pad, Play Again and Return to
    Lobby (Prompt 21);
  * the easier Era I on a first run (Prompt 31).
* Profile stats (Runs, Wins, BestYear) are not written yet; the results prompt (15) should
  write them from `RunDirector:Summary()`.

**Bible Questions**
1. An era boss that survives its 1:30 Surge: Prompt 3 lets it go (no +1, the era carries on),
   which the pace line implies. Should it come back at the next Surge instead, or should a boss
   Surge last until the boss dies?
2. Does the final Surge (the Source rising) end on the 1:30 timer like the others, so that
   surviving it is the Century Victory? Or does it end only when the Source is beaten?
3. Keep Going after an early Deep Victory (say in Year 40): as built, Endless starts at once
   (no more era bosses, no final Surge at Year 100). Or should the century carry on to Year 100
   first?
4. Should a player still lying in a Quarters bed when a day starts count as ready at once? Or
   should resting reset at the siren, like the Ready button?

**Recommended Improvements**
* HUD (Prompt 6): show Years per Cycle with its parts (base, crews, bosses), the way 99 Nights
  shows its day speed; a siren banner; "2 of 4 ready" beside the Ready button.
* AudioController: play the Surge siren on `SirenStarted` (Section 20 lists it), heard on the
  surface too.

**Technical Risks**
* Clients count down against `workspace:GetServerTimeNow()`, which can be a few tens of
  milliseconds off just after joining. That is harmless for a HUD timer.
* Signal handlers run on recycled threads. After firing, CycleClock checks whether it is still
  running, so a handler that ends the run in the middle of a step can't leave the clock
  half-changed (a Surge ending into a defeat, say).

## Delivery Report

**Overview.** The Run place now plays a century. The 30 s intro leads into 4:30 cycles (a 3:00
day with the siren 20 s before the Surge, then a 1:30 Surge), and the year jumps by Years per
Cycle at the end of each one. Brood Mother, The Deluge and the Crystal Colossus arrive when the
counter reaches 25, 50 and 75. Year 100 brings the final Surge and a Century Victory, and Keep
Going leads into Endless. Win and lose hooks are ready for the systems that will call them.

**Files created**
* `game/shared/Rules/Clock.luau`: the century's arithmetic, pure.
* `game/shared/RunState.luau`: the run's replicated values.
* `game/places/Run/server/Services/RunDirector.luau`, `CycleClock.luau` and
  `ObjectiveService.luau`.
* `game/reports/P03_RunLifecycle.md`.

**Files modified**
* `game/shared/Remotes.luau`: the `Place` field, `Remotes.InPlace`, the `SetReady` remote.
* `game/shared/Config/Tuning.luau`: removed the duplicated clock numbers.
* `game/server/DevTools/StructureCheck.luau`: per-place skeleton, place-only remotes, RunState
  checks.
* `game/server/DevTools/DataTests.luau`: 6 new tests, 49 in all.
* `game/client/Controllers/DevController.luau`: the client commands `clock` and `ready`.
* `tools/game_sync.py`: place folders merge into shared folders.
* `game/docs/ARCHITECTURE.md` (The run section, services, DevTools) and `game/BUILD.json`.

**Architecture**
* Services, in order: ObjectiveService ← CycleClock ← RunDirector, each also depending on
  DevService; CycleClock and RunDirector depend on SessionService.
* RunDirector drives CycleClock (Begin, Halt, Resume, SetEndless). CycleClock reports the end
  of the century through `CenturySurvived` and never calls RunDirector, so there is no cycle.
* Each value in RunState has one writer.

**Integration notes**
* Economy (Prompt 9): residents eat and drink on `CycleClock.CycleStarted`.
* Aging (Prompts 26 and 36): `CycleClock.YearChanged(year, previous)`.
* ThreatDirector (Prompt 12):
  * read the coming Surge with `CycleClock:Surge()` or `SurgeKind` / `SurgeBoss`;
  * spend on `SurgeStarted(kind, boss)`;
  * call `CycleClock:EndSurge()` when the last monster is dead and the disaster is fixed.
* Blueprint draft (Prompt 19): `CycleClock.SurgeEnded(kind, how)`.
* Objectives:
  * bosses (Prompts 15, 23, 24): `ObjectiveService:BossBeaten(bossId)`;
  * Lost Crews (Prompts 16, 17): `ObjectiveService:Complete("CrewMines")` and the others.
* Defeat:
  * `RunDirector:Lose("ReactorDestroyed")` when the Reactor Core falls (Prompts 8 and 13);
  * `RunDirector:Lose("ResidentsLost")` when the last resident dies (Prompt 10).
* Deep Victory (Prompt 25): `RunDirector:Win("Deep")`.
* Keep Going vote (Prompt 8): `RunDirector:KeepGoing()`.
* Results (Prompt 15): `RunDirector.RunEnded(summary)` and `RunDirector:Summary()`.
* Quarters beds (Prompts 8 and 10): `CycleClock:SetResting(player, true/false)`.
* HUD Ready button (Prompt 6): `Remotes.FireServer("SetReady", true/false)`; show `ReadyCount` /
  `ReadyNeeded` and the time from `RunState.TimeLeft()`.
* Studio: the attribute `SkipIntro = true` on `ServerScriptService.DevTools` starts runs without
  the intro.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Data tests:
  * Years per Cycle: 1, +2 a crew, +1 a boss, 12 with everything;
  * bosses due on reaching or passing 25, beaten bosses not due, a boss Surge once;
  * the year capped at 100 with the final Surge next, and Endless past 100;
  * eras by year and the tutorial wave;
  * the century pace (100 cycles with nothing done, 15 to 19 with crews and bosses);
  * RunState checks and owners;
  * remotes by place.
* [x] All 49 tests pass in both places (install) and when a Run playtest starts.
* [x] StructureCheck: Run 108 and Lobby 102 checks pass with no errors. The only error during
  playtests is NS_Pipeline, which the Night Shift plugin keeps recreating; I deleted it again in
  both places.
* [x] Run playtest 1:
  * the intro ran 30 s, then the run moved to Playing by itself (Day 1: 180 s, Tutorial Surge
    next);
  * the client's `clock` matched the server;
  * Ready through the real remote skipped the day to the siren (20 s left) and Ready reset;
  * at 20× speed: siren, Surge (4.5 s), then Year 2, cycle 2, a Normal Surge next;
  * Year 24 to 25 made the Brood Mother due; the boss Surge came; beating it gave 2 Years per
    Cycle; clearing the Surge early jumped to Year 27 (Expansion);
  * Year 99 plus a Lost Crew (4 a cycle) stopped at 100; the final Surge (Source) ended in a
    Century Victory with the clock halted;
  * Keep Going: Endless, Year 104, an Endless Surge next;
  * winning in Endless was refused; losing (reactor) gave a Defeat; Keep Going after the defeat
    was refused;
  * SetReady: a bad argument and an extra argument were rejected, and 6 of 8 spam calls were
    rate-limited.
* [x] Run playtest 2:
  * every player resting skipped the day;
  * a pause held the time on the server and the client;
  * Ready during a Surge was ignored;
  * resume went on from 90 s to 89 s;
  * a final Surge cleared early gave a Century Victory with nothing left on the clock.
* [x] Lobby playtest:
  * 4 services, with no SetReady remote, no RunState values and no clock commands;
  * on the client, `clock` and `ready` say there is no run in this place.
* [ ] Two players: skipping only when all are ready, and a player leaving completing a skip.
  This needs Team Test, also wanted for Prompt 8's votes.

**Future extension notes**
* Bible answers to the four questions change only `Rules.Clock` (and its tests) or one rule in
  CycleClock's skip check.
* Endless Surge strength is ThreatDirector's job (Prompt 12/25), keyed on `SurgeKind ==
  "Endless"` and the year.

# Addendum (2026-11-08, night): Landon's answers, built in Prompt 5's builds

Landon answered the four Bible Questions. The live bible (Section 5) and the project copies
now say the same. Built in `p5-7f68919` and checked in a Run playtest; the latest install is
`p5-d690a7c`.

| # | Question | Landon's answer | What changed |
|---|---|---|---|
| 1 | An era boss that survives its Surge | The boss Surge lasts until the boss dies | A boss Surge has no timer: `PhaseOpen` is true and `PhaseEndsAt` is nil. `EndSurge()` refuses it; it ends only on `ObjectiveService.BossDefeated` for that boss |
| 2 | The final Surge | It lasts until the Source is beaten | The final Surge has no timer either. `BossBeaten("Source")` gives the Century Victory |
| 3 | Keep Going after an early Deep Victory | OK as built | No change: Endless starts at once |
| 4 | A player still in bed when a day starts | Resting resets at the siren | Resting clears at the siren and at day start, like Ready. `SetResting(player, true)` is refused outside the day before the siren |

## Design Notes

**Decisions**
- `Rules.Clock.IsOpenEnded(kind)`: Boss and Final Surges have no timer (tested).
- `ObjectiveService:BossBeaten(bossId)` is the one way to beat a boss. `Complete` routes boss
  objectives to it. It fires `BossDefeated(bossId)`, which also works for the Source (not an
  era objective). `IsBossBeaten(bossId)` reads it.
- CycleClock ends the open Surge when `BossDefeated` names its boss. Monsters still on the map
  when the boss dies are the Threat Director's business (Prompt 12).
- `RunState.PhaseOpen` tells clients there is no countdown. The client's `clock` dev command
  says "no timer (until its boss is beaten)".

**Bible Questions**
- None new.

## Delivery Report

**Files modified**
- `game/shared/Rules/Clock.luau` (`IsOpenEnded`), `game/shared/RunState.luau` (`PhaseOpen`).
- `game/places/Run/server/Services/ObjectiveService.luau`: `BossDefeated`, `BossBeaten`,
  `IsBossBeaten`.
- `game/places/Run/server/Services/CycleClock.luau`:
  - open-ended Surges;
  - resting cleared at the siren and day start;
  - `SetResting` returns false when refused;
  - `IsOpenEnded`;
  - `clock.clear` refuses a boss Surge;
  - the dev command `boss.beat [bossId]`.
- `game/server/DevTools/DataTests.luau`, `game/client/Controllers/DevController.luau`.

**Integration notes**
- Bosses (Prompts 15, 23, 24, 25): call `ObjectiveService:BossBeaten(bossId)` when the boss
  dies. That ends its Surge and adds its +1 Year per Cycle.
- Quarters beds (Prompts 8 and 10): call `CycleClock:SetResting(player, true)` when a player
  lies down. Call it again at `CycleClock.CycleStarted` for players still in a bed, because
  resting clears at day start.
- HUD (Prompt 6): when `PhaseOpen` is true, show the boss's name instead of a timer.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Data tests: Boss and Final are open-ended; Tutorial, Normal and Endless Surges are not.
- [x] Run playtest, Brood Mother:
  - 180 clock seconds into its Surge it was still running;
  - `clock.clear` refused it;
  - `boss.beat` ended it, and the next year was 27 with 2 Years per Cycle.
- [x] Run playtest, final Surge: open-ended; `boss.beat Source` gave the Century Victory.
- [x] Resting:
  - refused during a Surge;
  - `rest.all` during a day skipped to the siren, and resting was cleared there.
- [ ] A real bed: the Quarters beds come with Prompts 8 and 10.
