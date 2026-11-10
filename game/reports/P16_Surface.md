# Prompt 16: The surface (Brightwater Ruins, storms, loot, hauling, rescues)

The elevator behind the Blast Door goes up to Brightwater Ruins (bible Sections 9, 12 and 13). Players
search the town's buildings into a 10-slot backpack, carry big finds home with both hands, free
trapped survivors and walk them home, and only what reaches the Blast Door hall or a Storage room
counts. Radiation builds the whole time; every Surge brings a storm, and Ash Jackals, Ash Raiders and
Ash Wraiths hunt the town. The A5 surface kit (11 buildings, props, the three surface monsters and
their clips) is in Studio and builds the town. Built and tested on 2026-11-09. The final install is
noted in `BUILD_LOG.md` (code asset 95026446991297), in Run and Lobby.

## Design Notes

**Decisions**
1. **Three services, a rule module and a controller** (Section 23: rules in Shared, state on the
   server).
   * `Shared.Rules.Surface` has no state: zones, the radiation rate, backpacks (stacks, slots, fit,
     merge, unload, summaries, the attribute encoding), carry speed, picking a spawn spot and a
     survivor's tier.
   * `SurfaceService`: the map, zones, the elevator, containers, storms, radiation and the surface
     creatures. `InventoryService`: backpacks, hauling and unloading, big finds, dropped bags,
     Clear-Rad pills and monster drops. `RescueService` (new; Bible Question 1): trapped people,
     freeing, the escort and joining the bunker (Prompt 17's trapped miners and Lost Crews use it).
   * `SurfaceController` (client): the surface's light and weather, the elevator fade, the HUD's
     radiation gauge and backpack chip, prompt gating, the carry speed and the Scout's outline.
2. **The map is part of the place** (Section 23: the surface map high above, the bunker in the
   middle). `workspace.Surface` sits at Y = 200, far above the bunker (floor 1 at -120); the old
   baseplate and the A0 showroom stay at 0. `Lib.BrightwaterMap.Build()`, run once in Studio, builds
   it from the A5 art (a graybox stand-in for any piece without art). A rebuild keeps every place
   where it was moved and never touches `workspace.Surface.Decor`, so Landon can dress the town.
   * The layout: Main Street along X, the bunker entrance in the north hill, 11 places (the
     entrance, Main Street diner, hardware store, gas station, grocery, Steadfast showroom, motel,
     radio tower, water tower, rail yard, military checkpoint), 43 containers, 11 survivor spots, 8
     find spots, 18 creature spawn points, 23 wrecks and trees. The builder letters each art sign
     with its place's name (the entrance: STEADFAST SHELTER CO.; the water tower: BRIGHTWATER).
   * Prompts stand at least 8 studs apart: with Roblox's one-prompt-per-key rule the nearest wins.
3. **The elevator** (Section 12). RIDE UP stands at the Blast Door's door, RIDE DOWN at the call box
   by the surface door; hold 1 s. The screen fades for 0.35 s each way and the server moves the
   rider, the survivors following them and what they carry. The camera turns to face out of the
   elevator.
4. **Zones.** Everything above Y = -60 is the surface. Each player carries a `Zone` attribute.
5. **Containers** (Section 12; `Config.SurfaceLocations`, `Config.LootTables`). SEARCH (hold 1.5 s)
   rolls the place's loot table (plus the Scavenger's extra rolls) into the searcher's backpack;
   what doesn't fit stays in the container (TAKE THE REST). Containers refill every era; the
   checkpoint's five are locked, and its barrier closed, until Era III.
6. **Backpacks** (Sections 9 and 12). 10 slots (+8 Scavenger, +5 Big Backpack through the
   `BackpackSlots` modifier). A slot holds a stack of one resource: Food 10, Water 10, Scrap 50,
   Iron, Copper and Crystal 20, Medkits 3, Ammo 60 (Bible Question 2). Throwables go to the hotbar,
   Clear-Rad pills into their own pocket. Loot counts only once unloaded at the Blast Door hall (15
   studs from the elevator) or a Storage room; what the stockpile has no room for stays in the pack.
7. **Big finds** (Section 12: generator parts carried with both hands, slowly; two carriers move
   faster). Each day may place generator parts (40%) at a find spot. CARRY (hold 1 s) lifts them:
   the carrier walks at half speed and can't shoot, swing, throw, roll or heal; a teammate within
   10 studs can HELP CARRY and both walk at 0.8. PUT DOWN, being downed or riding the elevator keep
   them with the carrier or on the ground. Unloading delivers them: two draws of Scrap 50 to 90 or
   Iron 5 to 10 into the stockpile (Bible Question 4).
8. **Downed on the surface** (Section 9): the backpack drops as a bag (`Prop_LootBag`) where the
   player fell, unless their class keeps it. Anyone can PICK UP (hold 0.5 s); what doesn't fit stays
   in the bag.
9. **Storms** (Section 12). The storm is over the town for every Surge (RunState `Storm`). The siren's
   alert reaches players on the surface 20 s before the Surge, and the Scout hears it 20 s earlier
   still. Players on the surface see a dark ash storm with lightning; in a storm radiation builds
   ten times faster and Ash Wraiths hunt; they fade when it passes.
10. **Radiation** (Section 9). 0 to 100: 0.2 a second on the surface, 2 in a storm, +8 per Wraith
    hit, times the class's `RadiationGain`. At 100 a carried Clear-Rad pill is taken by itself
    (Bible Question 5); with none, health drains 2 a second. A powered Decon Room clears 10 a
    second. A respawn starts clean (Bible Question 6). The HUD's third gauge shows it.
11. **Survivors** (Section 12: free them, escort them home, each becomes a resident, sometimes Rare).
    Each day may trap one (60%, at most two at once) at a survivor spot under rubble. FREE (hold
    3 s); they follow the freer 6 studs behind, walking round walls (PathfindingService). A leader
    downed, gone or more than 30 studs away hands them to the nearest standing player; with none
    they wait. On the way they are combatants that monsters hunt like residents (60 health). In the
    bunker they join as a resident (20% Rare, level 1 to 3), and the alert names the rescuer. They
    follow, they are not carried (Bible Question 3).
12. **Surface creatures** (Section 12; `Config.Monsters` with Where Surface). While players are up:
    Ash Jackal packs every 30 to 55 s, Ash Raiders every 50 to 80 s from Era II, Ash Wraiths every
    10 to 18 s in storms only, at spawn points 70 to 160 studs from the players (wraiths 35 to 70),
    at most 8 at once. They hunt players anywhere in the town (aggro 300 studs), walk round
    buildings (PathfindingService), jackals circle 11 studs out between bites ("circle and dart in"),
    raiders shoot (a hitscan with a tracer, 45% of shots hit; Bible Question 7). Everything fades 20 s
    after the last player goes down. A creature that falls out of the town is removed.
13. **Monster drops** (Section 13). A monster's `Drops` table is rolled when it dies: a surface kill
    goes into the pack of the last player who hit it (only hauled loot counts), a bunker kill
    straight into the stockpile (Bible Question 8).
14. **The run's story** (Prompt 15's results). Hauled counts every unit unloaded and delivered; a
    rescue counts too (MVP weights 0.3 a unit hauled, 40 a rescue). The story gets "X hauled
    generator parts home" and "NAME joins the bunker: rescued by X".

**Design Risks**
* Radiation is the trip timer: 0.2 a second gives about 8 minutes up top outside storms, longer
  than a day phase, so the storm is the real deadline. If trips feel endless, raise the rate.
* The town is about 600 by 480 studs. On foot at 16 studs a second the far corners are 30 s from
  the elevator; carrying generator parts at half speed doubles that. Good tension, but slow solo.
* Players on the surface during a Surge are not defending the bunker: the intended pull between
  the two, but a team that all goes up can lose rooms.
* Jackals were too lethal at first (a pack downed a lone player in 10 s at 9 a bite); now 5 a bite,
  packs of 3 to 5, circling 2 to 3.5 s. Needs real players.

**Scope Risks**
* Raids on the Blast Door and wanderers (Section 12) are Prompt 30's (the bible's build order).
* Loot specials that need later systems are skipped when rolled: gear, radio logs and blueprints
  (Prompts 17 to 19 and 26), recruits, Glowshards and the placeable lamp.
* The First Playable gate (four players on phone and PC) and Help Carry with two real players
  aren't tested.

**Bible Questions**
1. **RescueService.** Section 23 has no service for rescues. Built: `RescueService`, used by the
   surface's survivors now and the Deep's trapped miners and Lost Crews next. Add it to Section 23?
2. **Backpack slots.** A slot holds one resource up to its stack (Food 10, Water 10, Scrap 50, ores
   20, Medkits 3, Ammo 60); throwables go to the hotbar and Clear-Rad pills (up to 3) into their own
   pocket, not into slots. Right?
3. **Survivors follow, they aren't carried.** Section 12 lists rescued survivors among the big finds
   carried with both hands, and also says they follow you home. Built: they walk behind you (so
   your hands stay free to protect them). Right?
4. **Generator parts.** The bible names them as a big find but not what they give. Built: two draws
   of Scrap 50 to 90 or Iron 5 to 10. Should they do something else (repair or boost a generator)?
5. **Clear-Rad pills.** Carried up to 3, found in surface loot, taken by themselves at 100
   radiation (each clears it). Or should players take them by hand?
6. **Radiation and death.** A respawn starts with no radiation. Right?
7. **Ash Raiders.** On the surface from Era II (they raid the Blast Door from Era II), and every
   raider shoots (the bible says "melee or rifles"): 12 a shot, a shot every 1.6 s, 45% hit. Some
   with melee only?
8. **Monster drops.** Surface kills go into the killer's backpack (only hauled loot counts), kills
   in the bunker straight into the stockpile. Right?

**Recommended Improvements**
* A marker for the elevator on the HUD's compass edge while on the surface, and markers for freed
  survivors left behind.
* A pocket on the backpack chip that lists what's inside (the chip only shows slots used).
* Let Landon dress `workspace.Surface.Decor` (fences, signs, cars) to give cover from raider shots
  and break up the long sightlines on Main Street.
* A storm siren sound on the surface (Prompt 32's audio).

**Technical Risks**
* Roblox picks which of two prompts on the same key to show by distance and by what the camera
  sees. Near a small floor item (a dropped bag) the prompt shows only when the camera looks at it.
  Stations are kept 15 studs apart because the elevator's prompt won the E press at 9.
* Surface creatures path with PathfindingService (a plan every 1.5 s each, eight at most); watch
  the server's frame time with four players and a full storm.
* `execute_luau` runs in its own Lua copy, so a test that requires a service gets a dead copy (one
  test call left a stray model); tests go through dev commands.
* Four creature spawn points sat inside the north hill and creatures fell 200 studs to the old
  baseplate. The points moved out, and a fall guard removes any creature 30 studs below the exit.

## Delivery Report

**Overview.** The surface runs end to end in the Run place: the elevator, the town built from the A5
art, searching, backpacks, hauling and unloading, generator parts, dropped bags, storms, radiation
and the Decon Room, Clear-Rad pills, survivors freed and escorted home, the three surface creatures,
the checkpoint opening in Era III, the Scout's outline and early warning, and hauls and rescues in
the run's results.

**Files created**
* `game/shared/Rules/Surface.luau`
* `game/places/Run/server/Services/SurfaceService.luau`, `InventoryService.luau`, `RescueService.luau`
* `game/places/Run/client/Controllers/SurfaceController.luau`
* `game/server/Lib/BrightwaterMap.luau` (the map builder, run in Studio)
* `studio/ui/HUD_Surface.lua`, `studio/ui/patches/HUD_P16.lua` (the backpack chip and the fade)
* A5 art: `generators/Surface/` (`townlib.py`, 11 `Bldg_*`, 6 `Prop_*`),
  `generators/Monsters/Monster_AshJackal.py`, `Monster_AshWraith.py`, `Monster_AshRaider.py`, their
  exports, previews and clips; `Prop_GeneratorParts` and `Prop_LootBag`
* UI: eight surface icons (`ui/sprites/Icon_*.png`) in `ui/atlas_surface.png`
* `game/reports/P16_Surface.md` (this file)

**Files modified**
* Config: `Tuning` (Surface, MonsterAI's surface values, Results' MVP weights), `LootTables`
  (Clear-Rad pills, generator parts), `Monsters` (the Shoots trait; jackal and raider numbers),
  `Animations` (six surface monster clips, three rigs)
* Shared: `Rules.Loot` (skipped ids, extra rolls), `RunState` (Storm, StormAt), `Remotes`
  (Elevator), `UIContract` (Backpack, Fade)
* Services: `MonsterService` (zones, surface pathing, circling, shooting, Despawn, ZoneOf),
  `WeaponService` (busy hands), `CombatService` (Survivor combatants), `ResultsService` (Hauled,
  Rescues)
* Client: `CombatController` (busy hands), `ResultsController` (two rows, the MVP), `NPCAnimator`
  (rescued survivors), `Lib.UIKit`
* DevTools: `StructureCheck`, `DataTests` (three surface tests: 102 in all)
* `generators/UI/UI_Kit.py`, `ui/kit.json`, `studio/ui/HUD.lua`, `manifest.csv`

**Architecture**: `game/docs/ARCHITECTURE.md`, section "The surface".

**Integration notes**
* The town is built once in Studio: `require(game.ServerScriptService.Lib.BrightwaterMap).Build()`
  (execute_luau, Edit). Run it again after new surface art; moved places and `Decor` survive.
* The Blast Door room's `Door` socket anchors RIDE UP; the hall's Unload point is 15 studs towards
  the Shaft. Storage rooms get an Unload point each.
* Prompt 17 uses `RescueService:Trap(at, { Kind = ... })` and `SetArrival(kind, fn)` for trapped
  miners and Lost Crews, and `InventoryService:PlaceFind(kind, at)` with `SetDelivery(kind, fn)`
  for cryo pods.
* Raids and wanderers (Prompt 30) belong to `SurfaceService` (Section 23).

**Testing checklist (done in Studio, 2026-11-09, Run playtests)**
* The elevator up and down with real E holds; the fade, the camera facing out.
* SEARCH with a real E hold (Food 12 into the pack); TAKE THE REST.
* A survivor freed with a real E hold, following round the showroom's wall, riding down and
  joining as a resident (N7) with the alert.
* Generator parts lifted with a real E hold (walk speed 8, the gun put away), carried to the hall
  and delivered with a real E press: Scrap 330 to 474; the story line.
* UNLOAD with a real E press: Food 24 to 32 and Scrap 300 to 330, the pack emptied. (At 9 studs the
  elevator's prompt won the press: the drop-off moved to 15 studs.)
* An Ash Jackal shot dead with real clicks: its drop (Scrap 3) went into the shooter's pack.
* An Ash Raider's rifle: three hits of 12 in 10 s on the player, its tracer seen.
* Downed on the surface: the pack dropped as a bag; picked up with a real E hold.
* Death from radiation; a respawn with radiation 0.
* A Decon Room built with the dev tool and powered: radiation 22.9 to 0 in 2.5 s.
* Year 51 (Era III): the checkpoint's barrier opened, its five containers unlocked.
* The Scout: the Diner's four containers outlined; the storm warning at 21 s before the siren.
* Storm: the light, wraiths spawning and fading after.
* The A5 art in place: 11 buildings, 10 signs lettered, the three monsters
  (`previews/Game/P16_A5_*.jpg`, `P16_scout_outline.jpg`).
* Not tested: four players, Help Carry with two players, a Storage room's drop-off, gamepad and
  touch, a survivor hurt on the way.

**Future extension notes**
* Prompt 17: trapped miners, Lost Crews (the surface's raider camp too) and cryo pods use this
  prompt's rescue and big-find plumbing.
* Prompt 18: expeditions leave from the Blast Door or the Radio Room and never walk the map.
* Prompt 30: raids on the Blast Door and wanderers go in `SurfaceService`.


## Addendum: Landon's answers (2026-11-09)

| # | Question | Landon's answer | Build |
|---|---|---|---|
| 1 | RescueService | Add it to Section 23 | as built |
| 2 | Backpack slots | Keep | as built |
| 3 | Survivors | They follow | as built |
| 4 | Generator parts | Scrap or Iron | as built |
| 5 | Clear-Rad pills | Automatic | as built |
| 6 | Radiation and death | "Keeps half": a respawn keeps half the radiation | changed (Prompt 19) |
| 7 | Ash Raiders | "A third melee" | changed (Prompt 19) |
| 8 | Monster drops | Keep | as built |

**What changed** (built with Prompt 19): `SurfaceService` keeps half a player's radiation through a
respawn; `Config.Monsters.AshRaiderMelee` and `Tuning.Surface.RaiderMeleeShare` (0.33) make about a
third of the town's raiders and the camp's guards fight hand to hand (the rifle raider's model until
the melee raider's art).
