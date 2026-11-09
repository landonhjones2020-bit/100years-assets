# Prompt 9: Economy and power

The team's economy (bible Sections 5 and 13): rooms make things all the time from the residents
working in them, everyone eats and drinks at the start of each cycle, and the live power balance
turns the rooms farthest from the power dark when there isn't enough (Section 6). Built and
tested on 2026-11-08. The final install is `p9-4a34bb5` (code asset 95026446991297 revision
27), in Run and Lobby. The economy runs in the Run place.

This prompt also built Landon's answers to the Prompt 8 questions (addendum in
`P08_VotesConstruction.md`), and his answer to this prompt's own question:

* Do the Reactor Core and Generators need residents to make power? Landon answered "A": yes,
  like every other room.

## Design Notes

**Decisions**
1. **Section 13's formula runs as written.** Output per cycle = B × (worker stat sum / 10) × L
   × M × R × P (`Rules.Economy.Output`).
   * B is per room, not per cell. A bigger room makes more because it holds more workers (more
     stat), and M adds the merge bonus on top. "Output per cell raised to 1.1x for two" comes
     out exactly.
   * Bunker-wide multipliers sit on top: RoomOutput and AllOutput from classes and draft cards,
     and the difficulty's ResourceMultiplier on stock (Hard ×0.8, Nightmare ×0.65; Section 5
     says Hard has "fewer resources").
   * The crew's own multiplier (traits) comes from ResidentService in Prompt 10.
2. **"Rooms produce all the time" (Section 5)**: a room's output per cycle is spread over a full
   cycle (270 s).
   * Whole units go into the stockpile as they are made; the fractions carry over.
   * Production follows the run clock: it stops when the clock stops, and speeds up with
     DevTools' time scale.
   * A skipped day therefore makes less. That is the cost of skipping.
3. **Power needs crew (Landon: A).** The Reactor Core and Generators make PowerOutput[level] ×
   (stat / 10) × M × R. PowerOutput already has the level in it (24, 36, 48).
4. **Which rooms go dark** (Section 6, with Landon's answer that dug cells count as steps):
   * Rooms go dark farthest first by steps along the room graph from the nearest Reactor Core
     or Generator.
   * A room nothing can reach goes dark before any reachable room.
   * Ties: the newest room first (my choice; the bible names none).
   * A room that draws nothing (a Shaft, Storage at level 1) never goes dark, since darkening it
     saves no power.
   * Every room draws by level, staffed or not, wrecked or not ("every room draws power by
     level").
5. **What "dark" looks like** (art direction, not a rule):
   * the room's lights drop to a dim red emergency glow at 18% brightness;
   * its Neon fittings (light strips, pendants) go dull;
   * the room model carries a `Dark` attribute.
   * Players can still see a little. Flares and lamps (Section 6) come with their prompts.
6. **Food and water**: at the start of each cycle (`CycleClock.CycleStarted`) every resident
   eats 1 Food and drinks 1 Water.
   * Food is multiplied by FoodUse: Iron Stomach ×0.5 and Glutton ×2 are per resident; the Cook
     at level 3 (×0.8) is bunker-wide.
   * Fractions carry over, so someone who eats half takes 1 every other cycle.
   * If the stockpile can't cover a meal, it gives what it has. The team gets a Danger alert
     ("THE STOCKPILE RAN SHORT: 12 FOOD AND 12 WATER MISSING"), and `Shortfall` fires with what
     was missing. Who goes hungry, and what it costs them, is ResidentService's (Prompt 10).
7. **What gets made now**: Food, Water, Medkits, Ammo, the Drill Bay's band ore (Iron in the
   Mines, Copper in the Flooded Caverns, Crystal in the Crystal Hollows) and Lab research.
   * The Lounge's morale, the Radio Room's recruits, training, crafting, thawing and decon get a
     rate (`EconomyService:Rate`) for the prompts that use them.
8. **Until residents arrive (Prompt 10), nobody works or eats.** The starting bunker is dark
   with the reactor unstaffed, as Landon expected when he chose A. DevTools has `staff` and
   `eaters` to stand in.
9. **The HUD's Power chip** reads what every room would draw against what is made ("9/10").
   * The lamp is red while rooms are dark.
   * It is amber when the draw passes 85% of the power made (`Tuning.Rooms.PowerWarnAt`,
     provisional).
   * It is green otherwise.
10. **The Command View's Power and Production overlays** have real readings now.
    * Each room's label gets a lamp, and a reading chip underneath: "MAKES 24", "DRAWS 2",
      "DARK", "+8 FOOD", "NO CREW", "WRECKED".
    * A room's panel says what it draws and whether it is lit, and what it makes a cycle with
      how many working (or why it makes nothing).
    * The Morale and Threat overlays wait for Prompts 10 and 12.

**Design Risks**
* **Power needs crew, so a Surge that hurts the reactor crew can black out the bunker**, and a
  blackout (Prompt 12) doubles monster spawns. That is a strong spiral. Play-test it once
  residents fight back. One soft fix to suggest then: armed residents defend the reactor first.
* **Production is spread over the whole cycle**, so teams that skip every day make less.
  Skipping may then feel punishing. Tune with Ready in playtests.
* **The 85% warning point is a guess**, so the amber lamp may come too early or too late.

**Scope Risks**
* Every rate waits on Prompt 10's crews; this prompt is tested with pretend crews only.
* Hunger's effects (health and morale) are Prompt 10's.
* Flares and lamps in dark rooms are later.

**Bible Questions**
1. **Ties in the dark order.** When two rooms are the same number of steps from the power, the
   newest goes dark first. Is that right, or should it be the one drawing the most?
2. **Wrecked rooms and power.** A wrecked room (0 HP) still draws power, since the bible says
   every room draws by level. Should a wrecked room draw nothing until it is repaired?
3. **Who goes hungry** when the stockpile can't feed everyone (Prompt 10 needs this): everyone a
   little, or the last to arrive?

**Recommended Improvements**
* A one-line "why it's dark" on the Power overlay legend: "short by 0.4: the Kitchen is
  farthest".
* A short flicker as a room goes dark, and a hum when it comes back (Prompt 32's audio).
* Once there is a Workshop, a "Power" card in the Command View showing each Generator's crew.

**Technical Risks**
* PowerService works the balance out again every second as well as on every change. That's
  cheap at today's size (under 60 graph nodes); revisit at 34 rooms plus dug cells.
* Dark rooms change their Neon fittings' material and colour on the server, and they are put
  back from attributes. An art pass that adds Neon parts to a room model is picked up
  automatically.

## Delivery Report

**Overview.**
* Rooms make Food, Water, Medkits, Ammo, ore and research all the time from their crews, by
  Section 13's formula, and stop when they are dark, wrecked or empty.
* Everyone eats and drinks at the start of each cycle.
* Power is a live balance: the Reactor Core and Generators make it from their crews, and the
  rooms farthest from them go dark first when it runs short. Dark rooms glow emergency red.
* The HUD shows the power balance. The Command View's Power and Production overlays read every
  room.
* Landon's Prompt 8 answers:
  * tearing a room down gives half its cost back;
  * upgrades take construction time on Nightmare;
  * controllers vote with Y (tap for yes, hold for no).

**Files created**
* `game/shared/Rules/Economy.luau`: pure rules, used by the server and the tests:
  * the output formula, power made and drawn, and steps along the room graph;
  * the dark order (`Shed`, `Balance`);
  * eating with carry (`Eat`) and accrual (`Accrue`);
  * what a room makes (`Makes`, `BandOre`).
* `game/places/Run/server/Services/PowerService.luau`: the balance, dark rooms and their lights
  and fittings, RunState power values, the `Power` collection, alerts, `IsDark`, `DarkChanged`,
  and `/dev power`.
* `studio/ui/Frame_RoomReading.lua` (with `patches/Frame_P09.lua`): the reading chip under
  each room label (Frame, both places).
* `studio/ui/Votes_Keys.lua` (with `patches/Votes_P09.lua`): the controller's key chips on YES
  ("Y") and NO ("HOLD Y") (Run).
* `game/reports/P09_EconomyPower.md`.
* `previews/Game/P09_Studio_*.jpg`, plus the sheet `P09_Studio_sheet.jpg`.

**Files modified**
* `places/Run/server/Services/EconomyService.luau`:
  * production and consumption;
  * the crew and eater source (`SetResidents`, `RefreshCrew`, `Crew`, `Eaters`);
  * `SetPowered`, `Rate`;
  * bunker-wide modifiers (`SetModifier`, `Multiplier`, `OutputMultiplier`) and StockpileCaps on
    caps;
  * the `Production` collection;
  * signals `CrewChanged`, `Ate`, `Shortfall`;
  * `/dev production`, `staff`, `staff.clear`, `eaters`, `eat`.
* `places/Run/server/Services/BuildService.luau`:
  * refunds on tear-down;
  * upgrade sites on difficulties with `UpgradesTakeTime`;
  * sites carry Kind, RoomId and Level.
* `places/Run/server/Services/VoteService.luau`: a vote's `Refund` shows on the telegram.
* `places/Run/server/Services/RunDirector.luau`: `Difficulty()`, `/dev run.difficulty`.
* `places/Run/server/Services/CycleClock.luau`: `TimeScale()`.
* `places/Run/server/Lib/BunkerKit.luau`: `Site(..., upgrade)` draws the scaffold alone.
* `shared/Rules/Construction.luau`: `Refund`, and a tear-down plan's `Refund`.
* `shared/RunState.luau`: PowerService writes PowerMade, PowerUsed, PowerNeeded and DarkRooms.
* `shared/Config/Tuning.luau`: `Rooms.TearDownRefund` (0.5) and `Rooms.PowerWarnAt` (0.85).
* `shared/Config/Difficulties.luau`: `UpgradesTakeTime` (Nightmare).
* `shared/UIContract.luau`: `Templates.RoomLabel.Reading`, `VoteBanner.Yes/No.Key`.
* `client/Controllers/HUDController.luau`: the Power chip and its lamp.
* `client/Controllers/CommandViewController.luau`:
  * the Power and Production overlay providers and their reading chips;
  * a room's live power and output lines;
  * upgrade sites on rooms;
  * the tear-down refund.
* `client/Controllers/VoteController.luau`:
  * Y to vote (tap yes, hold no), bound above The Frame's main action while your ballot is
    open;
  * key chips;
  * the refund on the telegram;
  * upgrade-site ghosts ("LEVEL 2 45%").
* `client/Controllers/InputController.luau`: the `Vote` action (ButtonY), never blocked.
* `server/DevTools/StructureCheck.luau`, `server/DevTools/DataTests.luau`: two new tests, 73
  in all.
* `studio/ui/Frame_CommandView.lua`, `studio/ui/Votes.lua`: they include the new parts.
* `game/BUILD.json`: prompt 9.

**Architecture**
* `Rules.Economy` is the arithmetic, and everything else asks it.
* PowerService depends on EconomyService (crews, output modifiers) and pushes the dark rooms
  back with `SetPowered`. That keeps the dependency one way: EconomyService never asks
  PowerService.
* Crews come through a source that ResidentService sets (`SetResidents`), so EconomyService
  doesn't know about residents.
* Replication:
  * small values as RunState: the stock, Research and the four power values;
  * per-room readings in two collections: `Production` (EconomyService) and `Power`
    (PowerService).

**Integration notes**
* **Residents (Prompt 10).**
  * `EconomyService:SetResidents({ Crew = function(roomId) return { Workers, StatSum, Morale, Multiplier } end, Eaters = function() return { { Id, FoodUse } } end })`.
  * Call `EconomyService:RefreshCrew()` whenever an assignment, a stat, morale or a condition
    changes.
  * Listen to `EconomyService.Shortfall` for hunger, and to `PowerService.DarkChanged` and
    `IsDark` for dark-room morale (`Tuning.Rooms.DarkMoralePerCycle`).
  * Morale's R comes from `Config.MoraleStates` (OutputMultiplier).
* **Threats (Prompt 12).** `PowerService:IsDark(roomId)` doubles spawns
  (`Tuning.Rooms.DarkSpawnMultiplier`).
* **Disasters (Prompt 13).** A blackout can set rooms dark on top of the balance; extend
  `Economy.Balance` with a forced-dark set rather than editing lights directly. Wrecked power
  rooms already make nothing.
* **Digging (Prompt 14).** The Drill Bay already makes its band's ore.
* **Classes, drafts, Legends (Prompts 19, 20, 27).**
  `EconomyService:SetModifier(source, "RoomOutput" | "AllOutput" | "StockpileCaps" | "FoodUse", value, room?)`.
  Per-resident effects go into the crew's Multiplier.
* **Difficulty (Prompt 21).** RunDirector's difficulty already drives ResourceMultiplier and
  Nightmare's upgrade sites.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Installed `p9-4a34bb5` in both places: StructureCheck 0 errors (Run 317 checks, Lobby
  217), 73 data tests passed. The two new tests cover the formula, power, eating, accrual,
  refunds, the dark order (with the bible's starting bunker), dug cells as steps, and an
  unreachable room going first.
- [x] Run playtest: with no crew, 0 power is made, the five rooms that draw go dark and 16
  lights dim. With a reactor crew (stat 10), 24 power is made, everything is lit and all 25
  lights are back.
- [x] With a crew of stat 4, 9.6 power is made against 10 drawn, and the Kitchen goes dark: the
  newest of the three rooms 3 steps away. It shows "idle: Dark" and makes nothing.
- [x] With pretend crews, the Kitchen and Water Purifier make 8 a cycle and the Medbay 1. At 20×
  clock speed, Food and Water rose by 3 in about half a cycle (4 expected; the last half-second
  tick hadn't landed when I read it).
- [x] Meals: 6 eaters took 6 Food and 6 Water, through `eat` and again by themselves when cycle
  2 started. 40 eaters emptied the stockpile and logged the shortfall.
- [x] Tear-down refunds:
  * a Workshop cost 150 Scrap and its tear-down gave 75 back;
  * a team vote showed "TEAR DOWN WATER PURIFIER · 60 SCRAP BACK" and paid 60 back when it
    passed.
- [x] Nightmare:
  * an upgrade became a site ("LEVEL 2 49%" in the cell, scaffold only);
  * the room panel showed "Upgrading: to level 3: 30% done. 1 helping." with its options
    greyed out;
  * the room's level went up when the site finished.
- [x] Production at Nightmare's 0.65 showed on the overlay (+5.2 Water, +7.8 Food at level 2).
- [x] HUD chip: "10/24" green, "9/10" amber, "9/0" and "11/0" red. The alert "NOT ENOUGH POWER:
  4 ROOMS WENT DARK" appeared.
- [x] The blackout in the world: red emergency glow, and the ceiling strips went dull after the
  fix.
- [x] Y as the Y input from the test tool (it arrives with a keyboard device type):
  * a tap voted yes with the Command View open;
  * holding it voted no, and releasing added nothing.
- [ ] A real controller: the key chips (hidden on keyboard), Y on a real pad.
- [ ] Two real players; touch.

**Future extension notes**
* Per-room power steps are already replicated (`Power` collection, Steps). A "why it's dark"
  line in the Power overlay can read them.
* `Economy.Balance` takes the crew and multiplier functions as arguments, so a forced blackout,
  a damaged reactor (Prompt 13) or Overclock's overload chance (Prompt 19) can be added without
  touching the services' shape.

## Addendum: Landon's answers (2026-11-08), built after Prompt 10

| # | Question | Landon's answer | What changed |
|---|---|---|---|
| 1 | Ties in the dark order | "One drawing the most" | At the same number of steps from the power, the room drawing the most goes dark first; equal draws still go newest first (`Rules.Economy.Shed`). |
| 2 | Wrecked rooms and power | "Yes" | A wrecked room (0 HP) draws nothing until it is repaired, so it never goes dark and isn't counted in "needed" (`Rules.Economy.Balance`). |
| 3 | Who goes hungry | "Keep Newest Arrivals" | No change: the newest arrivals go hungry first (built in Prompt 10). |

Tested (build `p10-0a6f76b`, code asset revision 33): the data tests pass in both places (74),
with two new checks. With a weak crew (9.6 made) and the Quarters at level 3 (12 needed), the
Quarters (draw 4) go dark before the newer Kitchen (draw 2) at the same distance. A wrecked
Kitchen takes "needed" from 10 to 8. Neither case has been played in Studio yet: the
starting bunker has no ties of different sizes, and rooms can't be damaged until the Surge's
attacks (Prompt 13).

