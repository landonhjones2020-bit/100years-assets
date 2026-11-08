# Prompt 4: Bunker grid with a graybox room kit and the starting bunker

The grid, its rules, a graybox kit and the starting bunker (bible Sections 6 and 23). Built and
tested in Studio on 2026-11-08, build `p4-da8fe59`, Run place (the Lobby got the shared
modules and tests).

## Design Notes

**Decisions**
1. **Model, service and kit are separate.**
   * `Shared.Rules.Bunker` holds the data and the grid's rules. It is pure, so the server, the
     Command View's previews and the data tests share it.
   * `Shared.Rules.Grid` holds the geometry: cell to world and back, bands, keys.
   * `BunkerGrid` (service) keeps the run's bunker, replicates it and rebuilds the world.
   * `Lib.BunkerKit` builds the world. It is graybox now, and the A1 art replaces its parts
     behind the same calls.
2. **The starting bunker matches the bible's diagram.** The Shafts are in column 0, the middle
   of the 13 columns, with rock at -3 and the dug cells at +3. Prompt 1's data had everything
   one column to the left; it now follows the diagram.
3. **The rules come from Section 6.**
   * Digging: a Rock cell left of, right of or below an open cell.
   * Placing a room:
     * only on Dug cells;
     * at most its MaxCells (`Config.Rooms`: Blast Door 2; Shaft, Reactor Core and Memorial
       1; the rest 3);
     * one of a Unique room;
     * on its own Floor if it has one (the Blast Door on floor 1);
     * never in the Source Chamber (`DepthBands.Buildable`).
   * Merging: matching rooms side by side, at most MaxCells together.
   * Fixed rooms never merge or go.
   * Levels 1 to 3, with HP from `Tuning.Rooms.HP`; HP keeps its share when the level
     changes.
4. **The room graph counts Dug cells as nodes**, because players walk through them. Edges are
   doorways (side-by-side open cells of different units) and stacked Shafts.
5. **World layout.**
   * `Tuning.Grid.Origin` (0, -120, 0) is the interior floor centre of floor 1, column 0.
   * Columns grow along +X, and the front (the Command View's side) faces +Z.
   * Cells repeat every 34 × 18 studs: the A0 cell shell's 1-stud walls (new
     `Tuning.Grid.WallThickness`) and the bible's 2-stud slabs.
   * Art models face -Z, so `Grid.CellCFrame` turns them half a turn.
6. **The graybox kit.**
   * Every room has walls, a ceiling and a lamp per cell, and a label with its name, level
     and id.
   * A side wall gets an 8 × 10 doorway (the A0 kit's size) when the cell beyond is open.
     Cells of one room have no wall between them.
   * Front walls carry the `FrontWall` tag.
   * Stacked Shafts get a hole at the back right of the slab between them, and a stair (18
     up over 28 across).
   * Rooms with a marker:
     * the Reactor Core: a glowing core;
     * the Blast Door: a door disc, plus a `SurfaceExit` attachment for the surface lift;
     * the Quarters: `Beds[level]` beds per cell;
     * the Medbay: the players' spawn.
   * Every model streams as Persistent.
   * Rock is one band-coloured block per cell, with a crust above floor 1, bedrock under
     floor 10 and walls at both ends.
7. **Players spawn in the Medbay**, their respawn point in Section 6. The place's other
   SpawnLocations are disabled when the server starts; this happens at runtime only, and the
   place file is unchanged.
8. **Replication.** The `Cells` collection maps "floor,column" to `{ Room = id }`, or `{}`
   for a Dug cell. The `Rooms` collection carries each room's type, place, level and HP.
   Clients can rebuild a `Rules.Bunker` from these for previews.

**Design Risks**
* A room's wall faces the rock it borders, so digging from a room (Prompt 14) has to target
  that wall. The cell beyond is known from the wall's side and the room's cells.
* The shaft stair is steep (33°). Players walk it both ways; residents (Prompt 10) may want a
  gentler stair or a lift.

**Scope Risks**
* There are no interactions yet: building (Prompt 8), beds (Prompt 10) and digging (Prompt 14)
  come later.
* The Blast Door doesn't lead anywhere yet; the surface lift is Prompt 16, at the
  `SurfaceExit` attachment.
* Lights are always on; dark rooms come with power in Prompt 9.

**Bible Questions**
1. Is room HP per room (500, 800 or 1,200 by level for the whole room, as built) or per cell
   (a 3-cell room would have 1,500 at level 1)?
2. Should two matching rooms of different levels merge? As built they must be at the same
   level. The alternative is that they merge at the lower level.
3. Players can walk through dug cells, and the room graph counts them. When power picks the
   rooms "farthest from a Reactor Core or Generator, counted in steps along the room graph"
   (Section 6), does a dug cell count as a step?

**Recommended Improvements**
* A1: the A0 cell shell already matches the grid pitch and the doorway size. BunkerKit can
  swap its graybox parts for kit pieces with the same roles (Floor, Ceiling, BackWall,
  FrontWall, side walls).
* Command View (Prompt 7): listen for the `FrontWall` tag being added, because a rebuilt room
  gets new walls.

**Technical Risks**
* A change rebuilds the units around it: tens of parts, a few milliseconds. The A1 models will
  be heavier; clone prefabs then.
* The bunker spans Y -98 to -296. `FallenPartsDestroyHeight` is -500, so caves below floor 10
  must stay above it, or that setting must go lower.
* Studio's navigation tool found no route up the shaft stair, though a walking character
  climbs it. Resident paths are Prompt 10's and run on the room graph's nodes.

## Delivery Report

**Overview.** The Run place builds the starting bunker at server start (8 rooms, 12 open cells,
245 parts, 3 ms). Players spawn in the Medbay and can walk every room on both floors, through
doorways and up the shaft stair. The grid takes digging, building, merging, levels and
teardown by the bible's rules, rebuilds the world around each change, and replicates cells and
rooms to clients.

**Files created**
* `game/shared/Rules/Grid.luau`, `game/shared/Rules/Bunker.luau`.
* `game/places/Run/server/Lib/BunkerKit.luau`.
* `game/places/Run/server/Services/BunkerGrid.luau`.
* `game/reports/P04_BunkerGrid.md`.
* `previews/Game/P04_StartingBunker_side.jpg` and `P04_GridChanges_side.jpg`.

**Files modified**
* `game/shared/Config/Tuning.luau`: Grid `WallThickness` and `Origin`; the starting bunker
  centred on column 0.
* `game/server/DevTools/DataTests.luau`: 6 new tests and the starting bunker test, 55 in all.
* `game/server/DevTools/StructureCheck.luau`: the grid modules, BunkerGrid and BunkerKit, and
  `workspace.Bunker` checked in a running Run server.
* `game/docs/ARCHITECTURE.md` (The bunker) and `game/BUILD.json`.

**Architecture.** BunkerGrid depends on ReplicationService and DevService. Every change goes
through one path: change the data, publish the changed cells and rooms, re-sync the world
around the changed cells, then fire `Changed` and `RoomChanged`.

**Integration notes**
* BuildService (Prompt 8):
  * check proposals with `BunkerGrid:Bunker():CanPlace(...)` / `CanMerge` / `CanRemove`;
  * after the vote, the cost and the build time, call `PlaceRoom`, `MergeRooms`, `SetLevel` or
    `RemoveRoom`.
* DigService (Prompt 14): `CanDig` / `Dig`, `Grid.IsBandStart(floor)` for Push Deeper, and
  `Grid.BandOf(floor).DigSeconds`.
* PowerService (Prompt 9): `BunkerGrid:Graph()` and `RoomChanged`.
* Residents (Prompt 10): room models carry RoomId, RoomType, Floor, Column, Span and Level.
  Quarters beds are parts named `Bed` with a `Bed` number.
* Damage (Prompts 12 and 13): `BunkerGrid:SetHP(id, hp)`; 0 means Wrecked.
* Command View (Prompt 7):
  * `Rules.Grid` maps cells to the world and back;
  * read the `Cells` and `Rooms` collections;
  * hide parts tagged `FrontWall`;
  * place art with `Grid.CellCFrame`.
* Surface lift (Prompt 16): the Blast Door model's `SurfaceExit` attachment.

**Testing checklist (done in Studio, 2026-11-08)**
* [x] Data tests, all 55 passing in both places. New:
  * grid geometry: world positions map back to their cells, keys, bands, Push Deeper floors;
  * the starting bunker matches the diagram, is all connected, and its Shafts join floors 1
    and 2;
  * digging: left, right or down only;
  * placing: refused on rock, on a room, for a second Unique room, off a room's Floor, past
    MaxCells, and in the Source Chamber;
  * merging, including the left room's id surviving, and fixed rooms staying;
  * levels and HP.
* [x] StructureCheck: Run 116 checks at install and 142 in a playtest (including the bunker
  world), Lobby 106, no errors. The only error in playtests was NS_Pipeline, which I deleted
  again.
* [x] Run playtest:
  * the map and the room graph match the diagram;
  * the player spawned in the Medbay at (68, -134, 6);
  * a side view with the front walls hidden is in `previews/Game/P04_StartingBunker_side.jpg`.
* [x] Changes in the playtest, with the world rebuilt each time
  (`previews/Game/P04_GridChanges_side.jpg`):
  * dug under the floor-2 Shaft and built a Shaft there: the stair and the slab hole appeared;
  * built two Generators and merged them into one 2-cell room, then set it to level 2 (800 HP);
  * dug a cell and built a 2-cell Storage;
  * three requests were refused: building on a room, tearing down the Blast Door, digging away
    from open cells;
  * the client's Rooms and Cells mirrors matched the server.
* [x] Walking:
  * up and down the shaft stairs from floor 2 to 1 and from floor 3 to 2;
  * along floor 2 through every doorway, Medbay to Kitchen;
  * stopped by the Kitchen's wall where rock lies beyond, by the rock past the dug cell, and by
    a dug cell's front wall.

**Future extension notes**
* The A1 kit pieces plug into BunkerKit's builders one by one: shell, doorway walls, Shaft,
  Blast Door, room interiors by level.
* Cave openings (Prompt 17) attach outside the grid's edge walls at matching depths;
  `Grid.CellPosition` gives their anchor points.

---

# Addendum (2026-11-08, night): the A1 art kit in the bunker

BunkerKit now builds the bunker from the A1 models in `ServerStorage.Assets` (bible Section
19) instead of the graybox, behind the same `BunkerKit.Sync` call. A piece the place lacks
falls back to the graybox, so the code still builds anywhere.

## Design Notes

**Decisions**
- Each cell gets its shell from the kit: `Kit_Floor`/`Kit_FloorHole`, `Kit_Ceiling`/`Kit_CeilingHole`,
  `Kit_WallBack`, `Kit_WallFront` and, at a room's two ends, `Kit_WallSide`/`Kit_WallSideDoor`
  (the left one is the right-hand piece turned half a turn). Furniture is
  `Room_<Type>_L<level>` once per cell; the Blast Door is `Kit_BlastDoor_L<level>` at the
  centre of its two cells; a Shaft with a Shaft above gets `Kit_Shaft_L<level>`.
- Rock cells are `Kit_Rock_<Band>`, turned half a turn on alternate cells so the faces don't
  repeat; dug cells are `Kit_Dug_<Band>`.
- The frame (around the grid) is now a ring of rock cells: the Mines' rock above floor 1,
  the Source Chamber's rock below floor 10, and each floor's band at the two sides. It was
  6 studs of plain parts; it is now 18 studs of rock that matches the cells.
- Gameplay points: each room has an invisible `Sockets` part with an Attachment per socket
  in its art (WorkSpot, Bed, Seat, Core, Valve, FuseBox, Breaker, Tap, Bench, Respawn, Door,
  SurfaceExit, Vent, Lift, Chute, Top, Bottom, Light). Numbered sockets count up across a
  room's cells from left to right (a 2-cell Workshop L2 has WorkSpot1 to 6 and Bench, Bench2).
  `BunkerKit.Socket(model, name)` and `BunkerKit.Sockets(model, pattern)` read them. The graybox
  fallback writes the same sockets.
- Lights: two PointLights per room cell on the ceiling strip (Range 18, Brightness 1), a
  lantern per dug cell in its band's colour, the Reactor core's glow and the Kitchen's
  pendants. Shadows are off (phone budget). Each light has the `RoomLight` tag and a `Unit`
  attribute (room id or dug node) so the power system can darken rooms and floors (Section 10).
- The Medbay spawn now sits on the art respawn pad, invisible; the pad is the visual.
- Front walls: every part of `Kit_WallFront` and the `FrontWall` part of a dug cell carry
  the `FrontWall` tag for the Command View.
- One vent per room (in its first cell), none in the Shaft or the Blast Door (provisional:
  see Bible Questions).

**Design Risks**
- The rock reads almost black under the Run place's current lighting (ClockTime 19.5, dark
  ambient). The Command View's lighting preset (bible Section 23: a preset per zone) should
  lift it a little so the cliff face reads.

**Scope Risks**
- None new. Room types without art yet (Armory, Lab and the rest) use the graybox until their
  art step.

**Bible Questions**
1. How many vents does a room have? Section 10 lists room vents as breach points but not a
   count. I placed one per room; the breach system can open any subset.

**Recommended Improvements**
- Mirror alternate cells of multi-cell rooms so a 3-cell Quarters doesn't repeat exactly.
- A lit "surface" strip above the frame for the Command View once Prompt 16 defines the
  surface.

**Technical Risks**
- Light count: 25 in the starting bunker, about 2.2 per open cell. A full bunker (around 60
  open cells) would carry about 130 lights; the phone pass (Prompt 34) should measure this.
- Socket facing (yaw) is copied as authored; only positions were checked. Residents (later
  prompts) are the first to use the facing.

## Delivery Report

**Overview.** The starting bunker builds from the art kit at server start: 8 rooms, 12 open
cells, 613 parts in 15.5 ms (the graybox was 245 parts in 3 ms), 25 lights.

**Files modified**
- `game/places/Run/server/Lib/BunkerKit.luau`: art placement, sockets, lights, frame ring,
  graybox fallback, `HasArt`, `Socket`, `Sockets`.
- `game/places/Run/server/Services/BunkerGrid.luau`: `grid.sockets <roomId>` and `grid.art`
  dev commands; the start log says which kit built the bunker.
- `game/server/DevTools/StructureCheck.luau`: every room has a Sockets part; with the art kit
  present every room is built from art; the Medbay has its spawn and the Blast Door its
  SurfaceExit.
- `tools/setup_batch.py`: leaves out sidecar fields AssetSetup never reads (smaller chunks).

**Integration notes**
- Services that need a gameplay point ask the room model: `BunkerKit.Socket(model, "Core")`,
  `BunkerKit.Sockets(model, "^WorkSpot%d+$")`. Positions are in the world.
- The power system finds lights with `CollectionService:GetTagged("RoomLight")` and their
  `Unit` attribute; the ceiling strips are MeshParts with the `Role` attribute `CeilingLight`.
- The assets live only in the Run place's `ServerStorage.Assets`; the Lobby builds nothing.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] 46 A1 models inserted and set up; every one passed AssetSetup's size and pivot check
  (0.01 studs) and moved to `ServerStorage.Assets.Kit` / `.Rooms`.
- [x] Installed (build p4-1f57849): StructureCheck 0 errors in Edit, data tests 55 passed.
- [x] Playtest: "bunker built from the art kit", StructureCheck at start passed everything
  but the Night Shift folder (plugin still on), `grid.art` lists every unit as art.
- [x] Walked with `Humanoid:MoveTo` on the server: Medbay → Reactor Core → Shaft → up the stair
  → floor 1 → Quarters → dug cell 1,3 → Shaft → Blast Door (both cells, the door) → down the
  stair → Water Purifier → Kitchen → dug cell 2,3. Every move arrived except the Kitchen's
  centre, where the A0 dining table stands (the player stopped inside the room).
- [x] Changes: digging 1,-3 turned the Blast Door's left wall into the doorway piece; a
  2-cell Workshop L2 and a Storage L3 built from art; digging floors 4 to 8 gave Flooded
  Caverns and Crystal Hollows dug cells.
- [x] Sockets: Blast Door (Door, SurfaceExit, WorkSpot1-4), Quarters (Bed1-8, lower bunks
  first in each cell), Kitchen (Seat1-4, Table, WorkSpot1-2, Light1-2), Medbay (Respawn, Bed1),
  Shaft (Bottom, Top), 2-cell Workshop (WorkSpot1-6, Bench, Bench2).
- [x] Screenshots (front walls hidden on the client): `previews/Game/A1_Studio_*.jpg`, sheet
  `previews/Game/A1_Studio_sheet.jpg`.
- [ ] Phone frame rate with the art (Device Emulator), Landon's look at the screenshots.

# Addendum (2026-11-08, night): Landon's answers, built in Prompt 5's builds

Landon answered the three Bible Questions. The live bible (Section 6) and the project copies
now say the same. Built in `p5-7f68919`; the latest install is `p5-d690a7c`.

| # | Question | Landon's answer | What changed |
|---|---|---|---|
| 1 | Room HP per room or per cell | Per cell | `MaxHP = Tuning.Rooms.HP[level] × span` (`Bunker.MaxHP`). Placing, merging (the two rooms' HP add up) and level changes all use it |
| 2 | Merging rooms of different levels | No | No change: only rooms at the same level merge |
| 3 | Does a dug cell count as a power step? | Yes | No change now: the room graph already has dug cells as nodes. Power (Prompt 9) counts steps along it, dug cells included |

## Design Notes

**Decisions**
- A merge keeps both rooms' current HP (a damaged room stays damaged) and raises the maximum to
  the new span.
- A level change keeps the room's share of its HP (half stays half), as before, now per cell.

**Bible Questions**
- Still open from the A1 addendum: how many vents a room has.

## Delivery Report

**Files modified**
- `game/shared/Rules/Bunker.luau`: `maxHP(level, span)`, exported as `Bunker.MaxHP`; Place,
  Merge and SetLevel use it. The header records the three answers.
- `game/server/DevTools/DataTests.luau`: "Bunker: HP is per cell; a merged room keeps both
  rooms' HP", ending with Landon's example `Bunker.MaxHP(1, 3) == 1500`.

**Integration notes**
- Power (Prompt 9): the dark order is steps from a Reactor Core or Generator along
  `Bunker:Graph()`, dug cells included.
- Damage and repairs (Prompts 12 and 13): `Bunker:SetHP` clamps to the per-cell maximum.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Data tests: the 2-cell Quarters has 1,000 at level 1. A 2-cell Storage merged with a
  damaged 1-cell one has 300 + 1,000 of 1,500. At level 2 its maximum is 2,400. Different
  levels don't merge.
- [x] Run playtest: the Blast Door (2 cells) and the Quarters (2 cells) start at 1,000 of
  1,000.
