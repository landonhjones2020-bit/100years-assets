# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-09 (night), at the end of Prompt 17. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 133, and the two project parts, which match
it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.

## Where things stand

* Prompts 0 to 17 are built and tested in Studio. Code build `p17-5901951` (code asset
  95026446991297, revision 70) is installed in both places; 105 data tests pass.
* Prompt 17 (the Deep): a dug cave opening breaks into a cave put together behind the bunker from
  the band's A6 pieces (`workspace.Deep`): ore veins, caches, radio logs, trapped miners, cryo
  pods, Glowshard chests, guards and cave nests. The Lost Crews: one in a cave in the Mines and one
  in the Flooded Caverns (their cells' rolls fixed each run), and one in a raider camp on the
  surface. Cryo pods thaw in a Cryo Bay. The Deep's darkness, the players' own light, falls, the
  Spelunker's eye. Report: `game/reports/P17_Deep.md`.
* Prompt 16 (the surface): the elevator behind the Blast Door goes up to Brightwater Ruins
  (`workspace.Surface`, Y 200, built in Studio by `Lib.BrightwaterMap.Build()` from the A5 art).
  Search containers into a 10-slot backpack, unload at the Blast Door hall or a Storage room, carry
  generator parts home with both hands, free survivors and walk them home (they join as residents),
  radiation (Decon Room, Clear-Rad pills), a storm every Surge, Ash Jackals, Raiders (Era II) and
  Wraiths (storms). Report: `game/reports/P16_Surface.md`.
* A5 surface kit in Studio: 11 buildings, props, the loot bag, generator parts, three monsters
  with clips (`previews/Game/P16_A5_*.jpg`). A6 in Studio: 16 cave pieces, five props and the
  raider camp (`previews/Caves/`, `previews/Game/P17_*.jpg`).

## Landon's latest decisions (all in the bible)

* A Reactor Core at 0 HP starts a 60-second meltdown (built in Prompt 13).
* Every dug cell touching rock is a breach point, on any floor.
* Throwables: crafted, found exploring, and bought before a run as supplies with Glowshards.

## Next, in order

1. Prompt 18: resident expeditions and distress calls.
2. Prompt 19: the blueprint draft.

## Waiting on Landon

* His answers to the eight Prompt 17, eight Prompt 16, eight Prompt 14 and six Prompt 13 Bible
  Questions (in the reports). The six Prompt 15 answers are approved and in the bible.
* His look at the town, the surface monsters and the caves (`previews/Game/P16_*.jpg`,
  `P17_*.jpg`).

## Testing tips

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
  `instance_path`.
* Studio's screen captures leave out billboards (prompts, plates), so check those by using them.
* The simulated mouse doesn't move `GetMouseLocation`: pick Command View cells with the
  `cv.select <floor> <column>` dev command.
* `execute_luau` requires its own copy of a module, so call services through dev commands
  (`DevTools.Invoke`), not `require`.
* Two playtests at once (Run and Lobby) share one profile lock: the second is kicked.

## Small bugs seen, for later prompts

* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* The HUD's class plate still says SURVIVOR after the `class` dev command.
* The Pump Shotgun and Frag Grenade show placeholder icons in the hotbar.
* A monster after a target on another floor can stand in a room or under the Shaft stair (its
  stuck check restarts with every re-plan); seen in the Prompt 17 playtest.
