# 100 Years Below: handoff for the next chat

Written 2026-11-10 (late afternoon, Chicago), after Prompt 21. The game was called 100 Years Of
Fallout until 2026-11-09; the Project and its docs keep that name. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU and the two project parts) wins over everything
here. It is in step with Landon's decisions up to Nov 10 (live doc rev 174; both project parts
refreshed from it the same day).

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio. Studio asked for a restart on Nov 10 (its Assistant
   plugin changed version): ask Landon to restart it if tools misbehave.
4. Work in this order unless Landon says otherwise: the open work below, then Prompt 22, 23, 24.

## Where things stand

* **Prompts 0 to 21 are built and tested in Studio.** Code build `p21-2c777a7` (code asset
  95026446991297, revision 91) is installed in both places: StructureCheck 0 errors (Lobby 352
  checks, Run 534), 116 data tests.
* **Prompt 21 (the Lobby).** The Lobby place is Brightwater's Main Street on a sunny morning with
  the Steadfast showroom in the middle (`workspace.Lobby`, built by the script
  `tools/lobby_world.py` prints). Inside: six elevator pads (Solo, Private, Public Normal, Public
  Hard, Public Nightmare, Private), the Class Shop and Loadout booths, the bunker cutaway. The
  Daily Class Shop (four classes a day, Glowshards, one free reroll, the 99 Robux reroll as a real
  developer product, the wishlist, the free trial), the loadout, pads that reserve a Run server
  and write the run's record and rejoin records to MemoryStore, the Run place's party gate, and
  "Rejoin your run". Every class card shows its portrait. Report: `game/reports/P21_Lobby.md`
  (15 Bible Questions, a live-test list).
* **Prompt 20 (classes).** All 19 classes play: kits, passives, the ability on Q, levels 2 and 3,
  class experience. Report: `game/reports/P20_Classes.md` (15 Bible Questions).
* **Prompt 19 (the blueprint draft).** A three-card draft after every Surge, voted under the
  clock; found blueprints join the next draft. Report: `game/reports/P19_BlueprintDraft.md` (7
  Bible Questions).
* **Art in Studio.** Run place: A1 bunker kit, A2 (all 34 weapons, tools and devices), A4 Mines
  monsters and the Brood Mother, A5 surface kit, A6 cave pieces, both Ash Raiders after their
  detail pass. Lobby place: A9's lobby half, 28 models (`ServerStorage.Assets.Lobby` and `.Town`).
  Class looks: all 19 (outfits on the resident rig in `generators/Residents/outfits.py`,
  portraits on the class cards; `previews/Residents/Class_Portraits.jpg`). They are portraits
  only: nothing is worn in a run yet (class cosmetics are art step A11).
* **The art kit for towns.** `generators/Town/townkit.py`, `buildings.py` and `props.py` build
  1950s Main Street buildings from parameters, as merged decoration with collider boxes and
  lights in the sidecar. STYLE.md ("Buildings and streets") has the rules. This is the kit for the
  Run place's town too.

## Open work, in order

1. **Brightwater Ruins as a large, real town** (Landon, Nov 9: "The town is a fine place holder
   right now but needs to be much more detailed. I want it to feel like a large town that was
   actually real"; "make the town parts in your own blender environment it needs to actually look
   good"). His numbers: about 1,400 by 1,100 studs, about 120 buildings, about 25 to enter. The
   lobby's ten blocks are the same town before the bomb; the Run place needs them after 100 years
   (`Lib.BrightwaterMap` builds today's placeholder from the A5 kit; SurfaceService's containers,
   survivors, the raider camp, the checkpoint and the storms all hang off that map).
2. **Prompts 22, 23 and 24** (prep below).

The bible was brought up to date on Nov 10 (it had been behind since Nov 9): the title, Landon's
30 answers to the Prompt 13, 14, 16 and 17 questions, RescueService and the nests' split in
Section 23, and his Prompt 19 to 21 answers (the draft's cards under the year clock, found
blueprints, the size of the surface town, the lobby's Main Street). The doc is now named "100
Years Below — Game Bible v1.0".

## Landon's decisions since the last handoff

* Nov 9: 43 answers (all in the bible now), and the title: **100 Years Below**, on his
  lawyer's advice. `Constants.GAME_NAME` and the repo's docs carry it.
* Nov 9: the Fire Axe's clip sheet looked broken (it was the sheet's renderer, fixed); the Ash
  Raider needed more detail ("Not up to our standards"). Nov 10, after the detail pass: "looks
  good". The raider at about 3,700 of 4,000 triangles is the bar for a human enemy.
* Nov 10: he left for classes with "finish up prompt 20 and 21", then "IF you finish before I
  return I want you to create the recap and handoff and then begin on the next 3 prompts".
* His standing bar: beat 99 Nights in the Forest on finish; UI themed, never generic; monsters
  detailed, bosses scary; art made in Blender here and it has to actually look good.

## Next: Prompts 22, 23 and 24

Standing rules (bible Section 24): one system per prompt, the bible wins, never invent gameplay
(suggest it in the Design Notes), content is data, a real playtest for timing, permissions and
saved data, Design Notes and a Delivery Report in `game/reports/P##_*.md`.

### Prompt 22: the intro cutscene (Run)

* Bible: Section 4 (the six shots over 30 seconds, the rules, how it is built), Section 19 (the
  set is modelled here), Section 23 (the cutscene pre-streams the bunker).
* The shots: 0 to 5 s sunny Main Street, sirens, a radio bulletin scrolling; 5 to 10 s the party's
  avatars sprint up the hillside path into the Steadfast blast door with six residents; 10 to 15 s
  a bomb crosses the sky, the door rolls shut; 15 to 21 s white flash, a shockwave flattens the
  town, a mushroom cloud; 21 to 27 s the camera plunges through the rock past the bunker's rooms to
  something glowing that opens its eyes; 27 to 30 s the title card and "Survive. Dig. Don't wake
  it.", then the camera settles into the Command View and zooms down to your character.
* Rules: an account's first run plays it in full; after that each player can skip after 2 s;
  skipping is personal and the run clock starts at the 30 s mark for everyone; letterbox bars, the
  HUD hidden, a small Skip button bottom right; text and sound only (sound is Prompt 32).
* Already in the code: `RunDirector`'s Intro phase (`IntroEndsAt`, 30 s; Studio's `SkipIntro`
  DevTools attribute and dev `run.skipintro`), `Tuning.Clock.IntroSeconds` and
  `IntroSkipAfterSeconds`, the profile's `FirstRunDone` (ResultsService sets it),
  `CameraController:Suspend(reason)` and `Resume` for a view that takes the camera, the Command
  View's camera to hand over to.
* To build: a client `CutsceneController` that plays a camera path from a Luau data module
  (keyframes of time, position, rotation, exported from Blender and committed), rebuilds each
  party member's avatar from their avatar description and runs them along a path, shows the
  bulletin, the bars, the title card and Skip, and hands the camera to the Command View at 30 s.
* Art (A9's other half): the set. Main Street before the bomb is the lobby's blocks
  (`Lobby_Block*`, already made; the Run place needs them inserted and set up). New: the hillside
  path and the blast door from outside, the bomb, the mushroom cloud, the shockwave ring, the rock
  layers, the glimpse of the Source, and Digby the Gopher (the mascot who waves a shovel: the
  lobby's greeter and Prompt 31's tips). The flash, blast and cloud are particles, beams and
  tweened meshes.
* For the Design Notes: where the set stands in the Run place (it must not be reachable in play),
  what the six residents are (the founders), what the radio bulletin says.

### Prompt 23: Flooded Caverns monsters, floods and gas, The Deluge (Run)

* Bible: Section 10 (the Flood and Gas leak rows, The Deluge's row), Section 5 (Era II), the
  Appendix's monster table, Section 11 (hazard pockets when digging).
* Already in the code: `Config.Monsters` rows for Murkling (swarmer, pours out of water), Bloat
  Toad (bursts on death or contact and floods the room), Lurker (hides in water or dark rooms and
  grabs residents) and Tide Crab (armoured front, weak point on its back), with stats, traits and
  `Asset` names; `Config.Disasters.Flood` and `GasLeak` (Surge weights already set: Landon wants
  Surges to bring them from Era II; `Rules.Disasters.SurgePick` takes them once DisasterService can
  start them); `Config.Bosses.Deluge` (Year 50, 12,000 health, 3 phases, Murkling minions);
  `Lib.Hazards` (what disasters do that pathing must see); hazard pockets found by digging are
  empty until this prompt (Landon); class effects waiting on it: Foam Burst on floods, the Hazmat
  Tech's gas immunity and Decon Field on gas (one call each in `Lib.ClassAbilities`); the draft's
  FloodDrainSpeed and GasStrength keys.
* To build: the four monsters' behaviours (MonsterService), floods (water rising in a room,
  pouring down the Shaft, the burst pipe to patch, draining) and gas leaks (a room fills, the vent
  to seal or airing out) in DisasterService, The Deluge in BossService (it floods every room it
  passes; its head is the weak point when it surfaces; rooms behind it need draining).
* Art (A8): Monster_Murkling, Monster_BloatToad, Monster_Lurker, Monster_TideCrab and Boss_Deluge
  with their clips (`generators/Monsters/_beast.py`; a monster uses most of its 4,000 triangles, a
  boss up to 15,000 and has to be scary), water and gas as effects, the burst pipe and vent seal.

### Prompt 24: Crystal Hollows monsters, radiation leaks, outbreaks, the Crystal Colossus (Run)

* Bible: Section 10 (Radiation leak and Outbreak rows, the Colossus's row), Section 5 (Era III),
  the Appendix's monsters.
* Already in the code: `Config.Monsters` rows for Shardling (shatters into stinging shards), Prism
  Stalker (invisible until lit by a flare or lamp), Geode Golem (very slow, huge health, shrugs off
  small guns) and Resonator (hums to heal and speed up nearby monsters); `Config.Disasters`
  RadiationLeak and Outbreak; `Config.Bosses.CrystalColossus` (Year 75: huge, slow, armoured;
  flares show its weak points; its shards stun). The Crystal Hollows' cave pieces are A10 (not
  made); the Deep builds caves from a band's pieces.
* Art (A10): the four monsters, the Colossus, Crystal Hollows cave pieces.

## Waiting on Landon

* **The live test of Prompt 21** in the published game (the list is in `game/reports/P21_Lobby.md`):
  a pad to a real Run server, rejoin, Play Again, Return to Lobby, a friend on a private pad, one
  real 99 Robux reroll.
* His answers to the Bible Questions of Prompt 19 (7), Prompt 20 (15) and Prompt 21 (15).
* His look at the lobby (`previews/Game/P21_*.jpg`, or the Lobby place itself), at the town's
  names (Prompt 21, question 11) and at the 15 new class looks
  (`previews/Residents/Class_Portraits.jpg`; questions 14 and 15).
* The AutoScale Lite pass on The Frame and HUD (Prompt 6).

## Testing tips

* **The lobby.** Server dev commands (`ServerScriptService.DevTools.Invoke:Invoke(cmd)`): `shop`,
  `shop.new`, `shop.day <n>`, `shop.rerolls <n>`, `shop.trial <used|unused>`, `pads`, `pad.go <id>`,
  `pad.fill <id> <n>`, `pad.unlock <Hard|Nightmare|none>`, `products`, `purchase.test <Product>`,
  `rejoin`, `rejoin.fake [Difficulty]`, `rejoin.clear`. Keys: K Class Shop, L Loadout, Backspace
  closes The Frame; on a pad H difficulty, G invite, Y start; E at a booth. Pads are at X 50, 30,
  10, -10, -30, -50 and Z 39.5 in the showroom; a character moved onto one (`root.CFrame`) rides
  it. To test a wall, `Humanoid:MoveTo` past it and read where the character stopped.
* **Captures.** In a playtest bind a `ShotCam` render step on the client that sets the camera
  every frame, then `screen_capture`. Edit-mode captures came back at 270 by 151 on Nov 10; play
  mode gives 554 by 311 to 1,096 by 617. Captures leave out AlwaysOnTop billboards (prompts) and CoreGui.
* **Lobby and Run records in Studio.** A pad that leaves in a Lobby playtest writes the run's
  record under the Studio key; a Run playtest started within 10 minutes reads it (`party`, `run`).
* Expeditions: `exp` (trips out, their logs, whether a Radio Room hears calls), `exp.send
  <surface|deep> <cycles> <medkits> <id...>` (no console needed), `exp.cycle
  [Quiet|Hurt|Lost|Distress]` (a dawn now, the event forced), `exp.call [id]`, `exp.home [id]`,
  `exp.deadline`, `recruit [tier]`, `radio call`. A fast team: `resident.set <id> speed 9`. A
  heard call needs a working Radio Room: `grid.build RadioRoom 1 3`, `residents.auto` (staffs the
  Reactor Core for power), `resident.assign <id> R9`. The screen: `ui.open Expeditions` from the
  client's DevInvoke, or E at a console; SEND from a dev-opened screen is refused away from a
  console, so move the character there first (`PivotTo` on the server).
* Classes: `classes`, `class <Id> [level] [player]`, `class.level`, `class.own`, `ability
  [option]`, `ability.ready`, `classxp <years>`, `resident.arm <id|all> [item|none]`, `record
  <Class> [trial]`. The draft: `draft`, `draft.open`, `draft.take`, `draft.found`, `draft.reroll`,
  `draft.cards`, `bounty`.
* The clock: `clock.next` refuses while paused (`clock.resume` first). Pause and `monsters.clear`
  after each step: `clock.next` through a Surge leaves its monsters loose in the bunker, and even
  at x10 the threat director's single day breaches still come.
* The alert box shows two lines (about 80 characters): keep alerts short and put names in logs.
* The Deep: `crews` (where each Lost Crew is), `deep.cave <floor> <column>` (dig a rock cell into
  a cave; dig a path to a crew's cell first with `dig`), `deep` (caves, + guards asleep, * woken),
  `deep.tp <floor> <column> [piece]`, `deep.find <kind>` (in front of you), `radiolog [id]`,
  `cryo.add [n]`, `rescues`, `rescue.free <id>`. Falls: a part under the player in the Deep
  (z < -17.5) and a teleport 30 studs up; move the player off before removing the part (a downed
  body on it falls out of the world).
* Surface: `surface.up`/`surface.down` (from the server Invoke they take the first player),
  `pack.add <resource> <n>` and `class <Id>` from the client's `DevInvoke` (they need the invoking
  player), `god <s> <player>` from the server. `god` can't be shortened: `kill <player>` and the
  respawn clear it. `surface.spawn <type> [n]`, `survivor`, `surface.find`, `find`, `storm on`,
  `year 51` (Era III opens the checkpoint), `grid.build DeconRoom 1 3`, `residents.auto` (power).
* Prompt visibility: Roblox shows one prompt per key, by distance and what the camera sees; a
  prompt on a small floor item shows only when the camera looks at it. Log
  `ProximityPromptService.PromptShown` on the client to see which prompt a key will press.
* `god [seconds] [player]` keeps a player alive through a boss fight; `boss.freeze [s]` holds her
  still so a shot can be lined up; `boss.start`, `boss.hurt <n> [weak]`, `boss.lay`, `boss.end`.
  A real boss Surge: `year 24`, then `clock.next` until cycle 2's Surge.
* Real shots: the gun fires from its muzzle towards where the reticle points. Put the character
  in place (the client can move its own character), bind a `ShotCam` render step with the camera
  just behind the muzzle, then click with `user_mouse_input`. Scan for a clear line first with a
  raycast from the muzzle.
* `user_mouse_input` x and y are measured below the top bar (the GUI inset): a button's
  `AbsolutePosition` plus half its size, with no inset added. Buttons with unique paths can use
  `instance_path` (also for scrolling a ScrollingFrame).
* The simulated mouse doesn't move `GetMouseLocation`: pick Command View cells with the
  `cv.select <floor> <column>` dev command.
* `execute_luau` requires its own copy of a module, so call services through dev commands
  (`DevTools.Invoke`), not `require`.
* Two playtests at once (Run and Lobby) share one profile lock: the second is kicked.
* A Luau chunk near 20 KB goes up as a ModuleScript model instead of a paste
  (`tools/chunk_module.py`, then `require(InsertService:LoadAsset(id)...)()`).
* The project's bible parts are markdown copies of the live doc. After editing the live doc:
  export its tab as markdown with the Docs `export` tool (the result is saved to a file),
  `python3 tools/bible_parts.py <file> "<what changed>"`, Read each part in full, then
  `project_write` it with `local_path` (the tool only takes a file this session has read).

## Small bugs seen, for later prompts

* After SEND, the Expeditions screen switches to ACTIVE even when the server refuses the trip
  (too far from a console): it shows NOBODY OUT beside the warning.
* The distress plate's countdown shows --:-- while the clock is paused (dev only).
* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* A monster after a target on another floor can stand in a room or under the Shaft stair (its
  stuck check restarts with every re-plan); seen in the Prompt 17 playtest.
* The lobby: the Loadout a pad opens stays open if the server moves the player off the pad (dev
  only; a player closes it with Backspace before walking off).
* The lobby is about 330,000 triangles, over the bible's 150,000 for phones: measure on a phone
  (Prompt 34) before cutting anything.
