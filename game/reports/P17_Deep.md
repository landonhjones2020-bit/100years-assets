# Prompt 17: The Deep (Mines and Flooded cave pieces, cryo pods, Lost Crews)

Digging into a cave opening now breaks into a real cave (bible Sections 6, 11, 12 and 14). Each cave
is put together behind the bunker from its band's hand-made pieces (A6: 8 for the Mines, 8 for the
Flooded Caverns), so no two runs match. Caves hold ore veins, caches, radio logs, trapped miners,
cryo pods and rare Glowshard chests, guarded by the band's monsters and sometimes a nest. Every run
hides the Lost Crews: one in a cave in the Mines, one in the Flooded Caverns, and one in a raider
camp on the surface; bringing a crew home adds 2 Years per Cycle. Cryo pods hauled home thaw in a
Cryo Bay into Rare or Legendary residents. Built and tested on 2026-11-09. The final install is in
`BUILD_LOG.md` (code asset 95026446991297), in Run and Lobby.

## Design Notes

**Decisions**
1. **One service, one rule module, one controller** (Section 23: DeepService owns "cave pieces,
   assembly, nests, cryo pods").
   * `Shared.Rules.Deep` has no state: the cave planner (`Plan`), where a cave's mouth is, piece
     boxes and overlaps, what a find spot holds (`RollFind`), a pod's tier, the crews' cells
     (`CrewCell`), hints in words, fall damage, a player's light and the guards' roster.
   * `DeepService` (server): caves, finds, guards, cave nests, the Lost Crews, radio logs, cryo pods,
     the players' light and falls. `DeepController` (client): the radio log sheet and the
     Spelunker's eye. The Deep's lighting is `SurfaceController`'s, like the other zones'.
   * Content is data: `Config.CavePieces` is generated from the A6 pieces' sidecars
     (`tools/cave_config.py`), so the planner and the art can't drift apart; `Config.RadioLogs`
     holds the logs; the numbers are `Tuning.Deep`.
2. **Caves sit behind the grid** (Section 23: the surface high above, the bunker in the middle). A
   cave's mouth is its dug cell's back wall; the cave grows into the rock behind (-Z), never in
   front of the grid's back (Z -17.5) or below the Source Chamber's floor. The dug cell's back rock
   steps aside for the Entry piece's own rock face with its opening (the Mines' timber frame stays,
   no longer solid), and the stand-in mouth from Prompt 14 goes. The cave's mouth stays a breach
   point, and monsters walk in and out through it.
3. **The planner** (Section 12: "put together from hand-made pieces for that band"). The band's
   Entry at the mouth, then 3 to 6 pieces grown from open exits, each piece's pivot on the exit of
   the one before, chosen by weight (tunnels 4, junctions, pockets and chambers 3, caverns and drops
   2), each clear of every piece already in the Deep. Pieces share the 4 studs of wall round the
   opening between them. With as many exits waiting as pieces left it closes them with dead ends;
   on the last way on it keeps going. Exits with no room left are plugged with rubble (the doorway
   rubble at 1.45 scale). A cell whose rock another cave already fills gets no cave of its own.
4. **Finds** (Section 12). Every Find socket (0 to 4 a piece) rolls: ore vein 30, cache 18, radio
   log 10, trapped miner 8, cryo pod 4 (Era II on), Glowshard chest 2, nothing 28 (weights).
   * Ore vein: MINE (hold 3 s): 20 to 35 of the band's ore into the miner's pack (an ore pocket
     gives 8 to 15: "much richer than digging alone"). Anyone can mine (Bible Question 2).
   * Cache: OPEN (1.5 s): the Cache loot into the pack. Throwables go to the hotbar; a radio log
     in it plays.
   * Radio log: LISTEN (1 s): the recorder plays its log to whoever listens.
   * Trapped miner: freed and brought home like a surface survivor; 25% Rare, level 1 to 4.
   * Cryo pod: a big find, carried home with both hands (Prompt 16's hauling).
   * Glowshard chest: OPEN (2 s): 1 to 3 Glowshards to everyone in the run, straight into their
     profiles; the results show them as a line already paid (Bible Question 1).
   * Like the surface's containers, what doesn't fit in a pack stays: TAKE THE REST. Loot from the
     Deep counts once unloaded, like the surface's.
5. **Guards and nests** (Section 12: monsters; nests pay Scrap and ore, drop Disturbance by 20 and
   stop feeding breaches). Pieces with spawn spots hold guards 60% of the time, worth 4 of the
   band's monsters' threat cost (the Threat Director's own group rules); a cavern holds a nest half
   the time (else a cache). Guards come out when a player first comes within 60 studs of their
   piece and sleep at their posts until one comes within 30, or hits them; awake, they only chase
   what is within 48 studs of their post, and with nothing left they walk back and sleep.
   A cave nest is a monster combatant (600 health): while it lives it adds Disturbance every cycle
   like a dug nest and is a breach point at the cave's mouth; destroyed, it pays the Nest loot into
   the killer's pack and drops Disturbance by 20.
6. **Lost Crews** (Section 12: one on the surface and one in each band of the Deep; their spots
   change each run; guarded by a raider camp on the surface, by a nest below; +2 Years per Cycle and
   three residents, one Rare).
   * The Mines' and the Flooded Caverns' crews: at the start each is put in a rock cell on its
     band's crew floors (the Mines 2 to 3, the Flooded Caverns 4 to 6), at least 2 cells from
     anything open. That cell's roll becomes a cave opening (`DigService:SetRoll`; RunState
     `DigOverrides` carries it, so the Driller's eye sees the cave). Its cave ends in the band's
     crew pocket: the three trapped, one Rare, level 2 to 5, a nest and 6 of guards round it. A
     crew whose pocket finds no room is trapped at the end of the cave, still with a nest.
   * The surface's crew: a raider camp (A6's `Bldg_RaiderCamp`) at one of four spots on the map
     (`CampSpot`, picked each run), the crew in its pen and four Ash Raiders at its posts from Era I.
     The raiders come out when a player comes within 110 studs, sleep at their posts until one is
     within 30, and go back in when nobody has been near for 60 s; the ones killed stay dead.
   * The crew's members are freed one at a time (hold 3 s) and follow like survivors. When the
     first of them is home, the objective is done (Bible Question 3); if all three are lost, the
     crew is lost for the run. The Crystal Hollows' crew waits for its band's pieces (A10).
7. **Radio logs** (Section 12: radio logs give hints about where each crew is; Section 3's story).
   Ten logs tell the Brightwater mine and Steadfast's century in order (`Config.RadioLogs`, draft
   text). Three are a Lost Crew's own call (the Mines' foreman, the Flooded survey crew, the raiders'
   broadcast); while that crew is still lost, 60% of logs found are a lost crew's own call, ending
   with where they were last heard from ("the Mines, floor 3, five cells east of the shaft";
   "Brightwater Ruins, a raider camp behind the motel, by the rail yard"). The log types out on a
   sheet of Steadfast paper at the bottom of the screen (Special Elite; a click or tap closes it).
   Logs come from recorders in caves and from loot (caches, surface containers).
8. **Cryo pods** (Section 6: 1% of dug cells from Era II; Section 11: Rare or Legendary; the Cryo
   Bay unlocks with the first pod found). Pods turn up in dug cells and caves; the first one found
   unlocks the Cryo Bay. Carried home and unloaded (the hall or a Storage room), a pod waits
   (RunState `CryoPods`). Cryo Bays thaw waiting pods with their Thawing output, 2 points a pod
   (with two average workers, about 2 cycles), while the clock runs; each pod becomes a Rare (85%)
   or Legendary (15%) resident of level 2 to 5 who steps out in the Cryo Bay.
9. **Darkness and drops** (Section 12: darkness, drops). The caves' light is their lanterns (warm in
   the Mines, teal in the Flooded Caverns) and each player's own light in the Deep (18 studs; the
   Spelunker's 36). The client's Deep preset is dark and cool. A fall in the Deep past 14 studs
   hurts 4 a stud, up to 80; the Spelunker takes none. The server reads falls from the
   character's speed (a client's Humanoid states don't reach it).
10. **Realms.** Zones are Surface, Bunker or Deep (behind the grid's back); the bunker and the Deep
    are one realm, underground. Monsters, rescues and followers compare realms, so a miner follows
    their rescuer out of a cave and a monster chases a player in. In a cave there are no machines;
    paths come from PathfindingService and a target in the bunker is reached through the mouth.
    Monster drops and a downed player's pack in the Deep go into packs and bags, as on the surface.
11. **The Spelunker** (Section 14). Double light, no fall damage, and "reveals cave layouts": built
    as an outline through rock of every find, nest, cryo pod and trapped person within 90 studs,
    underground (Bible Question 7). Level 2's FindChance (cryo pods and caches more often) is read
    at the class level, which arrives with Prompt 20.
12. **A6 art.** 16 cave pieces (Entry, Tunnel, Junction, Pocket, Chamber, Cavern, Drop and Crew
    Pocket for each band; 3,400 to 7,350 triangles under an 8,000 budget), the cryo pod, the radio
    log recorder, iron and copper ore veins, the Glowshard chest and the raider camp, all set up in
    Run (`ServerStorage.Assets.Caves`, `Props`, `Surface`).

**Design Risks**
* Guards can overwhelm a lone player. At first (6 of budget, waking at 45 studs) a Survivor walking
  into a crew cave was downed by a swarm of Burrow Ticks in about 3 s. Now 4 of budget, waking at
  30 studs; crew pockets keep 6 round their nest. Needs real teams.
* A cave can't open where another cave already fills the rock behind the cell: that cell keeps the
  dark stand-in mouth (still a breach point). A crew whose cave can't open is trapped in the dug
  cell itself, so it is never lost to that.
* Caves vary from 3 to about 7 pieces; two long caves from neighbouring cells can crowd each other
  and end early in rubble.
* A cave nest feeds breaches through the cave's mouth and adds Disturbance like a dug nest. Several
  open cave nests raise Disturbance quickly.
* The crew's members are 8 studs apart: Roblox shows one prompt per key, so the FREE prompt can
  switch between them while held (seen once). They're freed one by one on purpose (Section 12:
  free them).

**Scope Risks**
* Gas pockets, deep water, floods and the Flooded monsters are Prompt 23 (A8); until then the
  Flooded Caverns' caves are guarded by the Mines' monsters. Radiation and the Crystal Hollows'
  pieces and crew are Prompt 24 (A10).
* "A nest or a mini-boss" guards each crew below: only nests are built; mini-bosses aren't in the
  bible's monster tables yet.
* The Radio Room's crew hints (Section 12) wait for the Radio Room's system; the Codex keeps logs
  later (Prompt 29). Placeable lamps (Section 12: darkness) wait for placeables (Prompt 30); flares
  already light caves.
* Rare gear from caves (Section 12's finds) waits for gear (Prompt 26): caches skip it.

**Bible Questions**
1. **Glowshard chests.** Built: a chest pays its 1 to 3 Glowshards to everyone in the run, at once,
   into their profiles. Or only to the player who opens it?
2. **Ore veins.** Built: anyone can mine a vein (hold 3 s). Or only with a Drill or a Pickaxe, as
   digging needs?
3. **A Lost Crew home.** Built: the objective is done when the first of the three reaches the
   bunker; the other two still join when they arrive; losing all three loses the crew for the run.
   Right?
4. **Cave nests.** Built: a nest in a cave adds Disturbance every cycle like a dug nest and is a
   breach point at its cave's mouth until destroyed. Right?
5. **Cryo pods.** Built: the first pod found unlocks the Cryo Bay; a hauled-home pod waits until a
   Cryo Bay thaws it (2 points of Thawing output a pod, about 2 cycles with two average workers);
   85% Rare, 15% Legendary, level 2 to 5. Right?
6. **Where the crews hide.** Built: the Mines' crew on floors 2 or 3, the Flooded Caverns' on 4 to
   6, at least 2 cells from anything open; the surface's camp at one of four spots. Right?
7. **The Spelunker's "reveals cave layouts".** Built: an outline through rock of every find, nest,
   cryo pod and trapped person within 90 studs. Or should it show the caves' shape (on the Command
   View or the mini-map)?
8. **Falls.** Built: fall damage only in the Deep (past 14 studs, 4 a stud, up to 80). In the
   bunker too?

**Recommended Improvements**
* Show caves on the Command View and the mini-map as the rock they fill behind the grid, and the
  Spelunker's view of whole caves there.
* A log book (the Codex, Prompt 29) so a heard log, and its hint, can be read again.
* Caves for the bands' crews could get a unique set dressing (the crew's lamps, a radio).
* Monster walking: a monster after a target on another floor sometimes stands in a room or under
  the Shaft stair (seen in this playtest; Prompt 12's walking); worth a look with the Prompt 34
  performance pass.

**Technical Risks**
* Falls are read from the root's vertical speed (falling past 8 studs a second), so a teleport while
  falling could count as a fall; the check needs the landing in the Deep, a drop under 120 studs
  and less than 80 studs sideways.
* RunState `DigOverrides` tells every client which cells hide crews, as `DigSeed` already tells
  every roll. Exploiters could find crews early; nothing else follows from it.
* Each cave lights 2 to 12 lanterns without shadows; the players' own lights cast shadows. Roblox
  draws at most 31 Highlights at once: the Spelunker's eye stays well under that.
* The cave pieces are 3,400 to 7,350 triangles each; a cave adds about 100 parts (its pieces'
  meshes, lanterns, finds and plugs), so a run with ten caves adds about 1,000.

## Delivery Report

**Overview**: The Deep's caves, finds, guards and nests, the Lost Crews (Mines, Flooded Caverns,
the surface's raider camp), radio logs, cryo pods and the Cryo Bay's thawing, the Deep's light and
falls, the Spelunker's passives, and A6 (16 cave pieces, 5 props, the raider camp).

**Files created**
* `game/places/Run/server/Services/DeepService.luau`
* `game/places/Run/client/Controllers/DeepController.luau`
* `game/shared/Rules/Deep.luau`
* `game/shared/Config/CavePieces.luau` (generated by `tools/cave_config.py`), `RadioLogs.luau`
* `tools/cave_config.py`, `tools/chunk_module.py` (a Luau chunk too big to paste, as a module)
* A6: `generators/Caves/` (`cavelib.py`, `cavedress.py`, 16 piece scripts), `generators/Deep/`
  (`Prop_CryoPod.py`, `Prop_RadioLog.py`, `orevein.py`, `Prop_OreVein_Iron.py`,
  `Prop_OreVein_Copper.py`, `Prop_GlowshardChest.py`), `generators/Surface/Bldg_RaiderCamp.py`;
  their exports and previews
* `previews/Game/P17_*.jpg`

**Files modified**
* Shared: `Rules.Dig` (a cell's fixed roll), `Rules.Surface` (the Deep zone, realms), `RunState`
  (DigOverrides, Caves, CryoPods), `Remotes` (RadioLog), `Config.Tuning` (Deep), `Config.LootTables`
  (OreVein)
* Server: `DigService` (FeatureAdded, SetRoll, SetResultHandler, OpenCave, cryo pods, radio logs in
  caches), `InventoryService` (loot specials, the Deep's drops and bags, a cryo pod's name),
  `RescueService` (realms, miners and crews, SetArrival after joining, Tagged), `MonsterService`
  (realms, the Deep, cave exits, guards), `SurfaceService` (the raider camp and the surface crew,
  CrewWhere), `ResultsService` (the Deep's stories, the chest line), `Lib.BrightwaterMap`
  (CampSpot), DevTools (`DataTests`: three Deep tests, 105 in all; `StructureCheck`)
* Client: `SurfaceController` (the Deep's lighting), `DigController` (the Driller sees crews' caves)
* `game/BUILD.json` (prompt 17), `manifest.csv` (A6), A5's walls (their doors were solid: each
  colliding wall segment now has its own name, and the rail yard's parts collide on their own)

**Architecture**: `game/docs/ARCHITECTURE.md`, section "The Deep".

**Integration notes**
* The surface map has four `CampSpot` markers (rebuilt in Studio with `BrightwaterMap.Build()`).
* `DigService.FeatureAdded(kind, floor, column)` fires for every cave opening, nest and cache, dug or
  put there by DevTools; DeepService builds caves on it.
* `InventoryService:SetSpecial(special, fn)` hands loot specials to their owner (DeepService:
  RadioLog, Glowshards); `GiveSpecial` for services that roll loot themselves (DigService's caches).
* `RescueService:SetArrival(kind, fn)` now runs after the resident joins: fn(rescue, leader,
  residentId). `Tagged(tag)` lists a crew's members.
* `MonsterService:Spawn(type, at, tag, { Guard = range })` makes a guard; `SetCaveExit(fn)`.
* A6 tooling batch: `ArtSetupBatch_A6` (asset 84423211905560) set up the 22 models.

**Testing checklist (done in Studio, 2026-11-09, Run playtests)**
* A cave behind dug cell 2,4 (Entry, Tunnel, Drop, Junction, Pocket; one exit plugged): walked in
  with a real W hold through the opened back wall; Zone Deep, the Deep's lighting, the player's
  light (`previews/Game/P17_cave_mouth.jpg`, `P17_cave_tunnel.jpg`).
* A radio log with a real E hold: typed out on its sheet, then the hint
  (`P17_radio_log.jpg`); each crew's own log carries its own crew's hint (dev `radiolog`).
* An ore vein mined with a real E hold: 32 Iron into the pack. A cache opened with a real E hold:
  128 Scrap. A Glowshard chest with a real E hold: the profile 112 to 115 Glowshards; another in a
  later run showed in the results as "Glowshard chests (paid when opened) +1"
  (`P17_results_chest.jpg`).
* The Mines' crew cave (Entry, Chamber, Cavern, Tunnel, Crew Pocket; `P17_crew_pocket.jpg`): the
  guards woke (the first tuning downed the player in 3 s: `P17_guards_downed.jpg`); all three freed
  with real E holds, led back through the cave round the junction by PathfindingService, joined
  as residents N7 (Rare), N8, N9; Lost Crew: the Mines done (+2 Years per Cycle).
* The raider camp behind the motel (`P17_raider_camp.jpg`): four raiders asleep at their posts,
  awake and shooting at 40 studs, back at their posts and asleep when the player left; the crew
  freed, rode the elevator down with the player and joined; Lost Crew: the surface done.
* A cryo pod: the Cryo Bay unlocked with its alert; carried with a real E hold, delivered at the
  hall with a real E press (1 waiting); a Cryo Bay built and staffed thawed it into N10 (Rare).
* A fall of 29.7 studs in the Deep: 63 damage. As a Spelunker: none, and a light of 36 studs.
* The Spelunker's eye: a cache, two ore veins and a trapped miner outlined through rock
  (`P17_spelunker_eye.jpg`).
* A cave nest destroyed with real shotgun clicks (`P17_cave_nest.jpg`): 11 Iron and 143 Scrap
  into the pack, Disturbance 50 to 30. A Hollow Miner killed in a cave with real clicks: 5 Ammo
  into the pack. Downed in a cave: the pack dropped as a bag.
* A Tunnel Hound spawned in a cave walked out through the mouth to a resident in the bunker.
* Data tests: 105 pass (the planner over 24 runs: the Entry first, every piece behind the grid and
  clear of the others, at least 3 pieces, the crew's pocket placed; a second mouth into the same
  rock refused).
* Not tested: four players, gamepad and touch, a run's Flooded Caverns caves (the pieces are in
  Studio and in the data tests), a crew member killed on the way, a cave mouth blocked by another
  cave.

**Future extension notes**
* Prompt 18: expeditions to the Deep never walk the caves; the Radio Room could also give crew hints
  (Section 12).
* Prompt 23: the Flooded Caverns' monsters, floods and gas fill these caves; guards pick them up
  as soon as their models are in (`Rules.Deep.Roster`).
* Prompt 24: the Crystal Hollows' 8 pieces (A10) and crew drop in through `tools/cave_config.py`
  and `Tuning.Deep.CrewFloors`; radiation in the Deep.
* Prompt 26: rare gear in caches; Prompt 29: the Codex keeps the radio logs; Prompt 30: placeable
  lamps.


## Addendum: Landon's answers (2026-11-09)

| # | Question | Landon's answer | Build |
|---|---|---|---|
| 1 | Glowshard chests | Everyone in the run | as built |
| 2 | Ore veins | "Drill or Pickaxe" | changed (Prompt 19) |
| 3 | A Lost Crew home | The first one home | as built |
| 4 | Cave nests | Keep | as built |
| 5 | Cryo pods | Keep | as built |
| 6 | Where the crews hide | Keep | as built |
| 7 | The Spelunker's eye | Outlines | as built |
| 8 | Falls | The Deep only | as built |

**What changed** (built with Prompt 19): `DeepService` mines an ore vein only for a player carrying a
Drill or a Pickaxe, and its prompt says so.
