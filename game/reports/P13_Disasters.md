# Prompt 13: Disasters and repairs

Things go wrong inside the bunker (bible Section 10, with Sections 5, 6, 11 and 23): fires that
spread room to room, blackouts on a floor or the whole grid, cave-ins that block doorways and
tunnels and can trap residents, the Reactor meltdown Landon chose for a destroyed Reactor Core,
and electrical surges. Every Surge buys one disaster from its budget. Wrecked rooms stop until
they are repaired with the Welder; residents slowly repair the room they work in. Built and
tested on 2026-11-08 and 9. The final install is `p13-7d05592` (code asset 95026446991297
revision 46), in Run and Lobby.

## Design Notes

**Decisions**
1. **One rule module, one service, one controller** (Section 23: rules in Shared, state on the
   server).
   * `Shared.Rules.Disasters` has no state: fire growth and damage, spread targets, the Surge's
     pick, blackout units, the valves, rubble HP, dig times and edges, electrical surge odds,
     repair rates. The data tests run it directly.
   * `DisasterService` owns every disaster; `DisasterController` draws them. Repairs live in
     `BuildService`, which already owned room HP changes.
   * `Shared.Rules.Modifiers` folds a class's passive modifiers (the Firefighter's 3x
     extinguishing and -75% fire damage, the Engineer's 2x repairs; level 2 and 3 effects are
     read when Prompt 20 adds class levels).
2. **Fire** (Section 10: spreads to the next room every 15 seconds, burning room HP and
   residents; Extinguisher, Foam Grenade, residents in the room). All numbers provisional, in
   `Tuning.Disasters.Fire`.
   * A fire has a strength from 0 to 100. It starts at 40 and grows 1 a second. At 0 it is out.
   * Every 15 s a fire stronger than 30 spreads through a doorway to a room next to it on the
     same floor. The Shaft's bare steel doesn't burn, so fires stay on their floor (Bible
     Question 2).
   * Room damage scales with strength, up to `Config.Disasters.Fire.RoomDamagePerSecond` (6).
     Players in the room take up to 5 a second (the Firefighter a quarter), residents 3.
   * Residents in a burning room beat it down 2 a second each, until their health falls below
     40%; then they leave and keep out of burning rooms.
   * The Extinguisher sprays 14 a second (the Firefighter 3x) at a fire within 16 studs ahead.
     A Foam Grenade puts out every fire in its burst.
   * Nobody respawns into a burning Medbay.
3. **Blackouts** (Section 10: a floor or the whole grid goes dark; reset the fuse box in the
   Reactor Core). 30% of blackouts take the whole grid. The darkened rooms work like rooms
   without power (PowerService's emergency red, the monster spawn weight). Holding Interact 2 s
   at the fuse box in the Reactor Core ends it. Left alone, it ends after 60 s
   (`Config.Disasters.Blackout.DurationSeconds`; the Insulated Grid card halves it; Bible
   Question 1).
4. **Cave-ins** (Section 10: rubble blocks a doorway or cell and can trap residents; dig or
   smash through).
   * Two shapes: rubble in a doorway (300 HP), or a tunnel filled at both ends (600 HP).
   * Rubble blocks those passages in `Lib.Hazards`, so PathGraph routes go round it or say
     Blocked.
   * A resident whose way is blocked waits where they are, **trapped**: out of their room's
     crew until it is cleared. Their log says so.
   * A monster whose target is cut off picks another for a while instead of walking into the
     rubble.
   * Anyone standing under it when it falls takes 15.
   * A Drill or a Pickaxe digs through in one hold (5 s for a doorway, 8 s for a tunnel); the
     prompt only shows to players who carry one. Any melee weapon smashes it; the Fire Axe and
     the Sledgehammer hit it 3x as hard. The pile sinks as it is broken up.
   * Prompt 14's digging and Tremors call `CaveIn(floor, column, side?, cause)`.
5. **The Reactor meltdown** (Section 10's Reactor overload; Landon, 2026-11-08).
   * A Reactor Core at 0 HP starts a 60-second meltdown instead of losing at once. It also
     starts a fire in the Reactor Core (Section 10: Reactor overloads cause fires).
   * Three valves in the Reactor Core turned together stop it. With 1 or 2 players each turned
     valve stays turned for 10 seconds; with 3 or more a valve counts while its player holds it.
   * A meltdown that runs out loses the run ("ReactorDestroyed"). The Reactor stays wrecked
     until it is repaired.
   * The HUD shows a telegram with the countdown and three valve lamps. A red alarm light
     pulses in the Reactor Core, and a plate over each valve says whether it is turned.
6. **Electrical surges** (Section 10: random, more often in Era III; they cause fires and
   blackouts). Each day from the second has a chance by era (20%, 25%, 45%, 35%) of one in a
   random room. Sparks damage its machines 10 HP a second for 20 s. Welding the room ends it.
   Left alone it may end in a fire (30%) or a blackout of its floor (25%) (Bible Question 6).
7. **The Surge's disaster** (Section 5: a Surge brings a breach wave and one disaster). A Normal
   or Endless Surge pays for one disaster first, from its budget (`ThreatCost`), then buys
   monsters with the rest. It picks among the disasters Surges cause (Fire and Blackout; Section
   10's "Caused by"), of its era and before, that the budget can pay for. It starts 8 s into
   the Surge. A Surge can't end early while its disaster, any fire or a meltdown is on
   (`HoldsSurge`).
8. **Wrecked rooms and repairs** (Section 6: a room at 0 HP is wrecked and stops until repaired
   with the Welder; residents slowly repair the room they work in; Section 11: Smarts is repair
   speed).
   * Wrecked: no production, no power made or drawn, no crew. It works again once it is back to
     25% of its HP and keeps healing to full (Bible Question 3).
   * The Welder repairs the first damaged room in front of the player within 10 studs, 25 HP a
     second (the Engineer twice as fast), and shows the room's HP filling over it. Welding a
     room with an electrical surge ends the surge.
   * Residents at work in their own room repair it, faster with more Smarts.
   * The team hears when a room is wrecked and when it works again.
9. **Showing it** (Sections 7 and 18): flames, smoke, embers and a flickering light in every
   cell of a burning room, steam when it goes out, sparks in a surging room, dust when rubble
   falls and is hit. The Command View's room labels say ON FIRE 64%, MELTDOWN 0:42, SURGE,
   BLACKOUT, RUBBLE, WRECKED or DARK, and disaster rooms blink there and on the mini-map. HUD
   alerts name the room and what to do.

**The art (A2 tools and the rubble kit)**
* **Tool_Extinguisher** (1,246 tris): a 1950s CO2 extinguisher. A Rust Red tank on a gunmetal
  foot ring, a cream instruction band with navy trim and a teal Steadfast diamond, a chrome
  valve head with lever and gauge, a yellow safety tag, and the big black horn pointing forward.
  Tools use the gun's hold pose, so the fist closes round the brass neck and the tank hangs
  below it. Version 2 is 0.8 scale after the playtest: v1's tank reached the floor on Landon's
  avatar.
* **Tool_Welder** (1,408 tris): a 1950s arc-welding gun. A rounded teal enamel housing with a
  chrome band, fins and a glowing pilot lamp, a copper swan neck to a brass nozzle, a round
  chrome spark shield, and a Hazard Yellow power cell slung underneath. It has the Pocket
  Pistol's v2 grip (raked back).
* **Kit_Rubble_Doorway** (1,448) plugs a room's 8 x 10 doorway: craggy rock wedged under the
  header, a broken concrete slab with rusty rebar on each side, a fallen steel beam, a snapped
  conduit, gravel spilling into both rooms.
* **Kit_Rubble_Tunnel** (2,272) fills a tunnel's 32 x 16 face with a rockfall up to the roof,
  with roof slabs on its mounds. A filled tunnel gets one at each end, inside the tunnel.
* **Icon_Extinguisher** and **Icon_Welder** for the hotbar, rendered from the models.
* Everything is band-neutral (stone, basalt, ash), because cave-ins happen at any depth.

**Design Risks**
* A Surge can now bring a fire or a blackout on top of its monsters. A small team may lose
  rooms fast in Era I. Every number is provisional; the Tutorial Surge buys no disaster.
* Fires on an unattended floor spread every 15 s. Residents fight them, which keeps an early
  fire small but costs them health.
* The meltdown is the run's sharpest moment. The telegram, the alarm light and the alerts say
  what to do. Alone, a player has 10 seconds after the first valve to run to the other two
  (about 26 studs apart) and turn them.

**Scope Risks**
* The other disasters (Flood, Gas leak, Radiation leak, Outbreak) are in `Config.Disasters`
  for Eras II and III (Prompts 23 and 24).
* Sounds are named (FireBell, ReactorAlarm, Klaxon, CaveIn, Sparks) and play once Prompt 32
  adds them.
* The Drill and the Pickaxe have no models or icons yet. The dig prompt works with the items,
  so Prompt 14's digging is a good time to make them.
* The Firefighter's Foam Burst and the class level effects (fire spreads 50% slower, the Fire
  Axe clears rubble instantly) are data, read when Prompt 20 adds abilities and levels.

**Bible Questions**
1. **Does an unfixed blackout end on its own?** Built: after 60 s (the Insulated Grid card
   halves that); the fuse box ends it at once. Or should it last until someone resets the fuse
   box?
2. **Fire and the Shaft.** Built: fire spreads through doorways on its own floor only; the Shaft
   doesn't burn. Should fire be able to climb the Shaft to the floors above and below?
3. **When is a wrecked room repaired?** Built: it works again at 25% of its HP and keeps healing
   to full. Should it need its full HP back first?
4. **What a Surge's one disaster can be.** Built: Fire or Blackout, the two whose "Caused by"
   lists Surges, of the Surge's era or before. Should a Surge also be able to bring a cave-in
   (and, in later eras, a flood or a gas leak)?
5. **Rubble.** Built: a Drill or a Pickaxe digs through in one hold (5 s for a doorway, 8 s for
   a tunnel); smashing takes 300 HP (doorway) or 600 HP (tunnel) of melee hits, the Fire Axe and
   the Sledgehammer 3x as hard. Right?
6. **Electrical surges.** Built: a daily chance from the second day of 20%, 25%, 45% and 35%
   in Eras I to IV (most in Era III, as Section 10 says), 20 s of sparks at 10 HP a second,
   ended by welding; left alone, 30% start a fire and 25% black out the floor. Right?

**Recommended Improvements**
* A Drill and a Pickaxe model and icon with Prompt 14 (the dig prompt already works with them).
* A short camera shake and rumble when rubble falls near the player.
* Smoke that thickens with a fire's strength, so a big fire is harder to see through.
* A Foam Grenade icon and model (it shows the default hand icon today).

**Technical Risks**
* Disasters tick on the server 4 times a second. Fire effects are made on each client per
  burning cell (about 8 emitters a cell), which is fine for a few fires. A whole burning floor
  on a phone is untested.
* Billboard plates (prompts, the valve plates, the Welder's HP bar) don't show in Studio's
  screen captures. A plain test billboard didn't show either, so the prompts were checked by
  using them for real, not by sight.
* Roblox gives a key to one prompt at a time. In the Medbay the "Take Medkits" prompt takes E
  when the camera faces it, so a player digging there has to face the rubble. This is standard
  Roblox behaviour.

## Delivery Report

**Overview.** Every Section 10 disaster for Era I runs end to end in the Run place: fires spread
and are put out, blackouts darken and the fuse box resets them, cave-ins block, trap and are
dug or smashed through, the meltdown counts down and three valves stop it or the run is lost,
electrical surges spark until welded, and Surges buy their disaster. Wrecked rooms stop and are
repaired by the Welder and by their workers. The new tools and rubble are modelled, in Studio
and in the hotbar.

**Files created**
* `game/shared/Rules/Disasters.luau`, `game/shared/Rules/Modifiers.luau`
* `game/places/Run/server/Services/DisasterService.luau`, `game/places/Run/server/Lib/Hazards.luau`
* `game/places/Run/client/Controllers/DisasterController.luau`
* `studio/ui/HUD_Disasters.lua`, `studio/ui/patches/HUD_P13.lua` (the Meltdown telegram and the
  Valve plate template)
* `generators/Weapons/Tool_Extinguisher.py`, `Tool_Welder.py`, `generators/Kits/Kit_Rubble.py`
* `previews/Weapons/Tool_*.png`, `previews/Kit/Kit_Rubble_*.png`, `previews/Game/P13_*.jpg`

**Files modified**
* `Config`: `Tuning` (Disasters, Repairs), `Disasters` (SurgeWeight; the Reactor overload's text
  matches the bible).
* `Rules`: `Bunker` (Wrecked, RepairedAt, HP modifiers), `Economy` (wrecked rooms make and draw
  nothing), `Residents` (Trapped).
* `RunState` (Fires, BlackoutRooms, Rubble, Meltdown, MeltdownEndsAt, ValvesTurned), `Remotes`
  (`UseTool`), `UIContract` (Meltdown, Templates.Valve).
* Services: `BunkerGrid` (Wrecked and Repaired signals, HP modifiers), `PowerService`
  (`SetBlackout`), `BuildService` (repairs), `ResidentService` (`SetTrapped`), `ResidentBrain`
  (fighting fires, keeping out of them, trapped), `MonsterService` (no instant loss at the
  Reactor; blocked targets skipped), `WeaponService` (`UseTool`, `ToolTick`, `Swung`, `Foamed`),
  `ThreatDirector` (the Surge's disaster, the daily electrical surge, `HoldsSurge`),
  `CombatService` (no respawn into a fire), `EconomyService`, `Lib.PathGraph` (rubble).
* Client: `CombatController` (tools held and used), `CommandViewController` (statuses,
  conditions), `HUDController` (the banner yields to the meltdown), `NPCAnimator` (Extinguish),
  `Lib.UIKit` (the new icons).
* DevTools: `StructureCheck`, `DataTests` (90 tests; 8 new: fire, spread, the Surge's pick, the
  valves, blackouts, cave-ins and repairs, wrecked rooms, modifiers, routes round rubble).
* `generators/UI/UI_Portraits.py`: two new icons; weapon icons now centre on the model (the
  parent inverse was taken before the root moved).

**Architecture**: `game/docs/ARCHITECTURE.md`, section "Disasters and repairs".

**Integration notes**
* **Prompt 14 (digging, Disturbance)**: digging and Tremors call
  `DisasterService:CaveIn(floor, column, side?, cause)`; a filled tunnel blocks every passage
  into the cell. The Drill and Pickaxe already dig rubble (`Tuning.Disasters.CaveIn.DigItems`).
* **Prompt 15 (the Brood Mother)**: a boss Surge isn't Normal, so it buys no disaster; a fire or
  meltdown still holds it open.
* **Prompt 19 (the Reactor overclock)**: call `DisasterService:StartMeltdown("Overclock")`.
* **Prompt 20 (classes)**: the Foam Burst ability is `DisasterService:Extinguish(roomId,
  math.huge, "FoamBurst", player)`; the Firefighter's level 2 is
  `DisasterService:SetModifier(source, "FireSpread", 0.5)`; level 3's `RubbleClearInstant`
  goes in `onSwung`.
* **Prompts 23 and 24 (later eras)**: a new disaster is a `Config.Disasters` entry, its rules in
  `Rules.Disasters` and a kind in `DisasterService` (its own collection id prefix).
* **Prompt 32 (sound)**: put FireBell, ReactorAlarm, Klaxon, CaveIn and Sparks in SoundService.

**Testing checklist (done in Studio, 2026-11-08 and 9)**
- [x] Installed `p13-7d05592` in both places: StructureCheck 0 errors (Run 394 checks, Lobby
  236), 90 data tests passed in each; the Lobby starts cleanly with it.
- [x] Fire: residents put out a Kitchen fire (about 9.5 s); a Medbay fire spread to the Reactor
  and hurt the player; the Extinguisher, held down with the real mouse, put out two fires; a
  Foam Grenade thrown with a real click put out the Surge's Medbay fire ("Foam"); a Kitchen fire
  spread to the Water Purifier, shown in the Command View (`P13_Fire_Medbay.jpg`,
  `P13_CommandView_Fire_Spread.jpg`).
- [x] Blackouts on floors 1 and 2: red emergency light, BLACKOUT in the Command View; the fuse
  box reset by a real 2-second hold of E, the alert and the lights back
  (`P13_Blackout_FuseBox.jpg`, `P13_FuseBox_Reset.jpg`).
- [x] Cave-ins with the new art: a doorway plug and a tunnel rockfall that stays inside the tunnel
  (`P13_Rubble_Doorway.jpg`, `P13_Rubble_Tunnel.jpg`). Dug through with a Drill by a real
  5-second hold of E. Smashed with real F presses (300 to 244 HP, the pile sank about a stud).
- [x] A trapped resident: `Trapped` true and "trapped by a cave-in" in her log; free and walking
  once the rubble was cleared.
- [x] A Tunnel Hound shut in with the player tried each resident in turn (all blocked), then
  idled; it never walked into the rubble.
- [x] The meltdown: the HUD telegram, the red alarm light and the Reactor fire
  (`P13_Meltdown_HUD.jpg`). Three valves turned by real E holds within 4.5 s stopped it (a test
  script moved the player from valve to valve between the holds). Solo, a turned valve went back
  after 10 s. A meltdown left alone lost the run: "Defeat (ReactorDestroyed)".
- [x] Repairs: the Engineer's Welder (real mouse hold) repaired and un-wrecked the Medbay;
  residents repaired the Reactor; the wreck alert. The Welder ended an electrical surge in the
  Kitchen (467 to 500 HP, "THE SURGE IN THE KITCHEN IS WELDED") (`P13_Welder_ElectricalSurge.jpg`).
- [x] The Surge's disaster: a Normal Surge paid 10 of its budget for a fire, which started 8 s in
  and held the Surge open until put out; the Tutorial Surge bought none.
- [x] The Command View: ON FIRE with strength, BLACKOUT, WRECKED, the rockfall in the tunnel cell
  (`P13_CommandView_*.jpg`).
- [x] The new tools held (the Extinguisher v2 by its neck, the Welder by its grip) and their
  hotbar icons (`P13_Extinguisher_Held.jpg`, `P13_Welder_Held.jpg`).
- [ ] The billboard plates seen on screen (Studio's captures don't show billboards); two real
  players on the valves (3 or more hold them together); phones with several fires.

**Future extension notes**
* A new disaster: a `Config.Disasters` entry (with `SurgeWeight` if Surges cause it), its rules
  in `Rules.Disasters`, a kind in `DisasterService` (start, tick, end, describe) and its look in
  `DisasterController`.
* A new tool: an `Items` entry with Kind `Tool` and an `Asset`, a `ToolTick` listener on the
  server, an effect in `DisasterController`'s `startToolEffect`, and a model with Grip and Muzzle
  sockets.


## Addendum: Landon's answers (2026-11-09)

| # | Question | Landon's answer | Build |
|---|---|---|---|
| 1 | Blackouts | Ends after 60 s | as built |
| 2 | Fire and the Shaft | Own floor only | as built |
| 3 | Wrecked rooms | Works again at 25% | as built |
| 4 | A Surge's disaster | "Add cave-ins and more": cave-ins from Era I; floods and gas leaks from Era II | changed (Prompt 19) |
| 5 | Rubble | Keep | as built |
| 6 | Electrical surges | Keep | as built |

**What changed** (built with Prompt 19, `game/reports/P19_BlueprintDraft.md`): `Config.Disasters`
gives CaveIn, Flood and GasLeak a Surge weight and "Surges" in their causes;
`Rules.Disasters.SurgePick` takes the disasters a service can start (`DisasterService` starts Fire,
Blackout and CaveIn; floods and gas leaks join with Prompt 23); a Surge's cave-in falls in a random
doorway.
