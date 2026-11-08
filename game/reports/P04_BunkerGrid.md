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
