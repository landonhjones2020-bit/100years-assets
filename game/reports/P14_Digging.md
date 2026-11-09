# Prompt 14: Digging, depth bands, Disturbance, Push Deeper

The bunker grows down into the Deep (bible Sections 6, 7, 10 and 14). Players dig rock with a
Drill or a Pickaxe, residents dig the Command View's queue from a Drill Bay, and every dug cell
rolls what it holds: ore, a cave opening, a cache or a nest. Opening a new depth band takes a
Push Deeper vote. Digging, explosions and living nests raise Disturbance, shown on the HUD's
seismograph; at 50 an extra breach comes, at 100 a Tremor. Built and tested on 2026-11-09. The
final install is `p14-1803b8e` (code asset 95026446991297 revision 50), in Run and Lobby.

## Design Notes

**Decisions**
1. **Two rule modules, one service, one controller** (Section 23: rules in Shared, state on the
   server).
   * `Shared.Rules.Dig` has no state: faces and prompt spots, dig seconds, stacking, the Drill
     Bay's speed, Push Deeper floors, the roll, the Driller's hints, Disturbance thresholds and
     the seismograph's levels. `Shared.Rules.Loot` rolls `Config.LootTables`. The data tests run
     both directly.
   * `DigService` owns digging, what dug cells hold, Push Deeper, the Drill Bay's queue and
     Disturbance; `DigController` draws them. Section 23 gives nests and cryo pods to
     DeepService (Prompt 17); nests found by digging live in DigService until then (Bible
     Question 8).
2. **Digging** (Section 6: any rock cell left of, right of or under a dug cell or room; hold
   interact with a Drill or a Pickaxe; 20, 30 and 45 seconds by band; the Driller twice as fast;
   players on one cell stack).
   * Every diggable rock cell has a prompt at each face it can be dug from: on the wall line at
     chest height beside an open cell, or on the floor of the cell above for digging down.
   * Only players carrying a Drill or a Pickaxe see it. Holding Interact digs; letting go keeps
     the progress, so a cell can be dug in turns or by several players at once.
   * Dust and stone chips fly at the face while it is dug, and a cloud bursts out when it opens.
3. **Push Deeper** (Section 6: opening the first cell of floor 4, 7 or 10 needs a vote).
   * The team can dig down to floor 3 from the start. Trying to dig a cell past the limit opens
     the vote (`Config.Votes.PushDeeper`: 20 s, a majority of the whole team); solo it passes at
     once (Section 8, rule 6).
   * A pass opens the whole band (floors 4 to 6, then 7 to 9, then 10). A failed vote can be
     asked again after 30 s.
4. **What a dug cell holds** (Section 6's table, rolled when it opens). The roll is fixed per
   cell for the run, so the Driller's eye (Section 14: sees ore and caves 2 cells into rock)
   shows what digging will find.
   * **Ore pocket**: 8 to 15 of the band's ore into the stockpile (the Driller's level 2: +25%).
     A band with no ore (the Source Chamber) gives nothing.
   * **Cave opening**: a dark cave mouth at the back of the cell and a breach point (Section 10:
     cave openings are breach points). The cave behind it is Prompt 17's.
   * **Cache**: a supply crate. Holding Interact 1 s opens it: resources go to the stockpile,
     throwables (Frag, Flare) to the player who opened it. Gear (Prompt 26) and radio logs (the
     Codex) are left out of the draw until they exist; the rest keep their odds.
   * **Nest**: monsters pour out at once (35% of what a normal Surge would spend now). The nest
     is a monster with 600 HP and a breach point while it lives, and adds 10 Disturbance every
     cycle. Destroyed, it pays its loot (Scrap and the band's ore) and drops Disturbance by 20.
   * **Hazard pocket** (gas and water, Prompt 23) and **cryo pod** (Era II, Prompt 17) count as
     Empty until their systems exist, so the other results keep the bible's odds.
   * Nothing can be built on a cell with a nest (destroy it first), a cache (open it first) or a
     cave opening.
5. **Cave-ins from digging** (Section 10: digging and Tremors cause cave-ins). 5% of sideways
   digs cave in the passage that was dug through. A Tremor caves in a doorway near the deepest
   floor. Both use Prompt 13's `DisasterService:CaveIn`.
6. **Disturbance** (Section 10). A 0 to 100 meter.
   * Raised by every dug cell (+5; the Driller's level 3: -40%), every explosion (+10) and each
     living nest (+10 a cycle).
   * Falls 10 each cycle and 20 when a nest is destroyed.
   * At 50 an extra small breach comes: a quarter of a normal Surge at one point.
   * At 100 a Tremor: a full wave (a normal Surge's budget) at up to three points at once, a
     cave-in, the camera shakes, and the meter drops to 40.
   * Both breaches are priced like a normal Surge, so the first run's Era I is 30% easier for
     them too (Section 22).
7. **The Drill Bay** (Sections 6 and 7: residents dig slowly through the Drill Bay queue; the
   queue is set in the Command View).
   * Any player queues rock cells in the Command View (no vote; up to 12).
   * Each working Drill Bay digs the first diggable queued cell at a quarter of a player's speed
     for each unit of its crew's output. Two average workers took about a minute for a Mines
     cell in the playtest. It still makes its band ore as before.
8. **The HUD seismograph** (Section 10). The word under DISTURBANCE reads CALM, RISING,
   UNSETTLED or DANGER in green, yellow, orange or red. The trace swings harder as the meter
   rises, blinks at DANGER and jumps at a Tremor.
9. **The Command View** (Section 7). A rock cell lists its dig time, how far it is dug, its
   place in the queue, whether it needs a Push Deeper vote, and, for the Driller, what it holds.
   Its option queues it or takes it off. A dug cell says what it holds. A cell being dug or
   queued has a Hazard Yellow frame with a Signal Orange bar that fills as it is dug.
10. **Art** (STYLE.md: chunky, on-palette, scary where it should be).
    * **Tool_Drill** (1,462 tris): a heavy Steadfast rock drill. A Signal Orange motor drum with
      gunmetal cooling rings, a chrome trim band and a domed chrome back cap with vents, a teal
      badge, a rubber carry handle, an amber pilot lamp, a gunmetal gearbox with a side handle, a
      steel chuck, and a long auger bit with a spiral flute and a carbide point. The Welder's
      pistol grip.
    * **Weapon_Pickaxe** (658): a miner's pick-mattock. A pine haft with a leather wrap, rubber
      bands, a brass ferrule and a walnut knob; a forged steel head on a teal-banded collar, the
      pick sweeping down to a chrome point, the adze curling up to a chrome edge.
    * **Prop_Nest** (2,918): a hive grown out of the rock. A plum mound dark at its base, a
      chimney crowned with cream spines round a glowing vent, a fanged maw with a Source-green
      heart bulging out, cream ribs arching over it, glowing eggs strapped down by sinew, Source
      veins, and roots creeping across the floor with glowing buds.
    * **Kit_CaveMouth** (1,612): a funnel of dark rock dropping into a black void, two green
      eyes watching from inside, a rim of broken boulders, Source crystals and spilled rubble.
    * **Icon_Drill** and **Icon_Pickaxe** for the hotbar, rendered from the models.

**Design Risks**
* A nest dug next to the bunker's rooms is dangerous. In the first playtest a nest placed next
  to the Quarters poured out half a normal Surge (8 monsters) in cycle 1 and killed all six
  founders, which lost the run. It is now 35% of a normal Surge with the first run's easing
  (2 monsters in the final check on a first run's cycle 1), but it grows with the threat level.
* A Tremor is a whole Surge wave at once on top of the cycle's own Surge (18 and 19 monsters at
  threat 42 in the playtest, before the easing). That's Section 10's design, and the seismograph
  warns from 50.
* Residents treat a living nest as a monster in its unit: they flee it and stay away from rooms
  next to it until it is destroyed.
* 600 HP took 3 Frag Grenades and about 15 Pump Shotgun shots from one player. Fine for a team;
  slow for a lone player with a pistol.
* The extra breach at 50 is a quarter of a normal Surge: about 5 monsters at threat 42 in Era I,
  "small" next to a Surge but bigger than the Tutorial Surge.

**Scope Risks**
* Hazard pockets (Prompt 23), cryo pods and the caves behind cave openings (Prompt 17), cache
  gear (Prompt 26) and radio logs (the Codex) aren't built. Their rolls count as Empty or are
  left out of the draw.
* The Driller's Overdrive and Deep Charges (Prompt 20) and Breaching Charges call
  `DigService:DigNow` and `AddDisturbance`.
* A Tremor's rumble and the dig sounds wait for Prompt 32.

**Bible Questions**
1. **Cave-ins from digging.** Built: 5% of sideways digs cave in the passage dug through, and a
   Tremor drops one doorway cave-in near the deepest floor. Should digging down cave in too, and
   are the numbers right?
2. **Nests.** Built: 35% of a normal Surge's budget pours out (2 monsters in a first run's
   cycle 1, about 7 at threat 60), 600 HP, +10 Disturbance each cycle alive. Section 10 says
   nests raise Disturbance but gives no number. Right?
3. **Cache loot.** Built: resources to the team's stockpile, throwables to the player who opened
   it, gear and radio logs once their systems exist. Right?
4. **Building on what digging found.** Built: no building on a nest (destroy it first) or a cache
   (open it first); a cave opening blocks building for good. Should a cave opening be sealable?
5. **Hazard pockets and cryo pods** count as Empty until Prompts 23 and 17, and the other results
   keep their odds. OK?
6. **The Drill Bay's speed.** Built: a quarter of a player per unit of crew output, about a
   minute for a Mines cell with two average workers. Right?
7. **The extra breach and the Tremor's size.** Built: a quarter of a normal Surge and a whole
   one, with the first run's Era I easing. Right?
8. **Nests and DeepService.** Section 23 gives nests to DeepService (Prompt 17). Built in
   DigService for now; Prompt 17 can move them with the caves. OK?

**Recommended Improvements**
* A nest that pulses: the heart and eggs swelling and dimming on the client.
* A cold draught and blinking eyes at the cave mouth.
* The Driller's eye as small icons on rock cells in the Command View, without selecting each.
* A nest health bar in the Command View and over the nest.
* A rumble and a short shake when a cell opens near the player.

**Technical Risks**
* Studio's simulated mouse doesn't move `UserInputService:GetMouseLocation`, which the Command
  View uses to pick cells. In the test the cell was picked with the `cv.select` dev command; the
  option and the main action were real clicks.
* Studio's screen captures leave out billboards, so the dig prompts were checked by using them
  (real E holds) and their gauges by the server's progress.
* DigService ticks 4 times a second over the cells being dug (at most 12 queued plus the ones
  being dug by hand): cheap. The dust lives on Terrain attachments and is removed when digging
  stops.

## Delivery Report

**Overview.** Digging runs end to end in the Run place. Players dig with real E holds (stacking,
the Driller twice as fast, dust at the face). Dug cells roll ore pockets, cave openings, caches
and nests, each with its art and effect. The first cell of a new band asks the team to Push
Deeper. Residents dig the Command View's queue from a Drill Bay. Disturbance rises and falls,
brings an extra breach at 50 and a Tremor at 100 (wave, cave-in, camera shake), and shows on the
HUD's seismograph. The Drill, the Pickaxe, the nest and the cave mouth are modelled, in Studio
and in the hotbar.

**Files created**
* `game/shared/Rules/Dig.luau`, `game/shared/Rules/Loot.luau`
* `game/places/Run/server/Services/DigService.luau`
* `game/places/Run/client/Controllers/DigController.luau`
* `generators/Weapons/Tool_Drill.py`, `Weapon_Pickaxe.py`, `generators/Props/Prop_Nest.py`,
  `generators/Kits/Kit_CaveMouth.py`
* `ui/sprites/Icon_Drill.png`, `Icon_Pickaxe.png`
* `previews/Weapons/Tool_Drill.png`, `Weapon_Pickaxe.png`, `previews/Props/Prop_Nest.png`,
  `previews/Kit/Kit_CaveMouth.png`, `previews/Game/P14_*.jpg`

**Files modified**
* `Config.Tuning`: `Digging` (Tools, PromptReach, TickSeconds, CaveInChance, NestHealth,
  NestBudget, NestPerCycle, CacheOpenSeconds, VoteRetrySeconds).
* `RunState` (Disturbance, DigLimit, DigSeed, TremorAt, Nests), `Remotes` (`MarkDig`).
* Services: `WeaponService` (`Exploded`, `GiveThrowable`), `BreachService` (`SetExtraPoint`:
  cave openings and nests), `ThreatDirector` (`Burst`; the extra breach and the Tremor priced as
  a normal Surge), `BuildService` (`SetCellCheck`).
* Client: `CameraController` (`Shake`), `HUDController` (the seismograph),
  `CommandViewController` (cell notes, rock options, the dig queue's choices, kept on refresh),
  `PromptController` (a shared `Progress` attribute drives the gauge), `Lib.UIKit` (the new
  icons).
* DevTools: `StructureCheck`, `DataTests` (95 tests; 5 new: dig times and stacking, faces and
  Push Deeper, the roll's odds, Disturbance's thresholds, loot tables).
* `generators/UI/UI_Portraits.py` (two icons), `ui/atlas_items.png`, `ui/kit.json`,
  `manifest.csv`, `game/BUILD.json` (prompt 14).

**Architecture**: `game/docs/ARCHITECTURE.md`, section "Digging, Disturbance and Push Deeper".

**Integration notes**
* **Prompt 15 (the Brood Mother)**: Section 11 has her burst up through the deepest tunnel;
  `Grid`/`BunkerGrid:DeepestFloor()` and `Rules.Dig.Faces` find it. A boss Surge isn't Normal,
  so it buys no disaster.
* **Prompt 17 (the Deep)**: a cave opening's breach point is `O:<floor>,<column>`
  (`BreachService:SetExtraPoint`); the cave behind it hangs off the `F:` entry. Add `CryoPod` to
  `AVAILABLE` in DigService (and DigController) when cryo pods exist.
* **Prompt 20 (classes)**: Overdrive calls `DigService:DigNow(floor, column, "Overdrive", player)`
  for 3 cells in a line and `AddDisturbance`; the Driller's level 2 (`DugOre`) and 3
  (`DigDisturbance`) are read through `Modifiers.ClassValue` (pass the class level when it
  exists). Breaching Charges call `AddDisturbance`. `DigService:SetModifier(source,
  "DigSpeed" | "DigDisturbance", x)` for team-wide effects (Deep Charges).
* **Prompt 23 (Flooded Caverns)**: add `HazardPocket` to `AVAILABLE` and start a gas leak or a
  flood in `applyRoll`.
* **Prompt 26 (gear)** and the Codex: take `Gear` and `RadioLog` out of `SKIP_SPECIALS` and hand
  them out in `giveDrops`.
* **Prompt 32 (sound)**: a dig loop at the face, a rumble on a Tremor, a crack when a cell opens.

**Testing checklist (done in Studio, 2026-11-09)**
- [x] Installed `p14-1803b8e` in both places: StructureCheck 0 errors (Run 403 checks, Lobby
  240), 95 data tests passed in each; the Lobby starts cleanly with it.
- [x] Digging with the Drill by real E holds: floor 2's rock beside the dug cell (the Driller,
  about 10 s, a cache), floor 4 from above after the vote, floor 4 sideways in the Flooded
  Caverns with dust and chips at the bit (`P14_Drill_Held_DugThrough.jpg`,
  `P14_Dig_Dust_FloodedCaverns.jpg`). Each cell opened within one hold of the Driller's time
  (10 s in the Mines, 15 s in the Flooded Caverns).
- [x] Push Deeper: with a pretend second voter, a hold at floor 4 opened "PUSH DEEPER: THE
  FLOODED CAVERNS" (`P14_PushDeeper_Vote.jpg`); it passed and the dig limit went to floor 6.
- [x] Rolls: a cache opened with a real 1 s hold (+38 Ammo, +71 Scrap), an ore pocket (+14 Iron),
  Empty cells; `dig.roll` matched what opened.
- [x] A nest: its burst, its art in place (`P14_Nest_Burst.jpg`), 3 real Frag Grenades (+10
  Disturbance each, 90 damage each) and real shotgun shots destroyed it: dissolved, +208 Scrap,
  Disturbance -20. The first try showed FireWeapon refusing the nest's custom id; it now takes an
  ordinary monster id.
- [x] A cave mouth and a cache in place (`P14_CaveMouth.jpg`, `P14_Cache.jpg`).
- [x] The Drill Bay: two residents at work, power on; (1,4) picked in the Command View, its
  option and the main action clicked for real ("QUEUE FOR THE DRILL BAY",
  `P14_CommandView_QueueChoice.jpg`); the marker frame and progress bar
  (`P14_CommandView_DrillBayQueue.jpg`); the Drill Bay dug it ("dug 1,4 (DrillBay)"). The first
  try found the choice cleared on refresh; fixed.
- [x] Disturbance: 45 to 50 brought an extra breach ("breach at V:R4 ... (Extra)"); the
  seismograph at 82 read DANGER (`P14_Seismograph_Danger.jpg`); 100 was a Tremor: a cave-in
  ("Doorway at 2,-2 Right (Tremor)"), a wave at three points, the meter to 40, and the camera
  turned up to about 3 degrees a frame for 2 s on the client. A new cycle took it from 40 to 30.
- [x] The Command View's notes: dig time, the Driller's eye matching the server's roll ("An ore
  pocket is in this rock." at 3,2 and 2,-3; nothing past 2 cells), the cache and cave notes on
  dug cells (`P14_CommandView_Rock.jpg`).
- [x] The new tools: the Drill held and digging, both icons on the hotbar.
- [ ] Two real players digging one cell together (stacking is in the data tests and the server
  sums the diggers' speeds); the dig prompt's gauge seen on screen (captures leave out
  billboards); the Pickaxe swung as a melee weapon in a fight.

**Future extension notes**
* A new dig result: a `Config.DigResults` entry (with `Loot` if it pays), its name in
  `AVAILABLE` (DigService and DigController), its effect in `applyRoll`, and a note in
  DigController's `FEATURE_NOTES` if it stays in the cell.
* A new dig tool: add the item to `Tuning.Digging.Tools`.
* A new depth band: a `Config.DepthBands` entry with its `DigSeconds`; add its first floor to
  `Tuning.Digging.PushDeeperFloors`.
