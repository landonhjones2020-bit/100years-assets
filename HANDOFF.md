# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-09 (night), at the end of Prompt 14. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 130, and the two project parts, which match
it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.

## Where things stand

* Prompts 0 to 14 are built and tested in Studio. Code build `p14-1803b8e` (code asset
  95026446991297, revision 50) is installed in both places; 95 data tests pass.
* Prompt 14 (digging, depth bands, Disturbance, Push Deeper): dig prompts at every rock face
  for Drill and Pickaxe carriers (the Driller twice as fast, players stack); each dug cell rolls
  an ore pocket, a cave opening (a breach point), a cache or a nest (a monster with 600 HP that
  pours out monsters and raises Disturbance); Push Deeper votes at floors 4, 7 and 10; the Drill
  Bay digs the Command View's queue; Disturbance on the HUD's seismograph, an extra breach at 50
  and a Tremor at 100 (a wave, a cave-in, the camera shakes). Report:
  `game/reports/P14_Digging.md`.
* Prompt 13 (disasters and repairs): fires, blackouts, cave-ins, the Reactor meltdown, electrical
  surges, the Surge's disaster, repairs. Report: `game/reports/P13_Disasters.md`.
* Art: the Drill, the Pickaxe, the nest, the cave mouth and the two icons (Prompt 14); the
  Extinguisher, the Welder and rubble (Prompt 13); all in the Run place's
  `ServerStorage.Assets`.

## Landon's latest decisions (all in the bible)

* A Reactor Core at 0 HP starts a 60-second meltdown (built in Prompt 13).
* Every dug cell touching rock is a breach point, on any floor.
* Throwables: crafted, found exploring, and bought before a run as supplies with Glowshards.

## Next, in order

1. Prompt 15: the Brood Mother's fight (her art, clips, sockets and weak point are ready) and
   the results screen.

## Waiting on Landon

* His answers to the eight Prompt 14 and six Prompt 13 Bible Questions (in the reports).
* His look at the rebuilt monsters and the Brood Mother (`previews/Game/A4_Studio_*.jpg`).

## Testing tips

* Studio's screen captures leave out billboards (prompts, plates), so check those by using them.
* The simulated mouse doesn't move `GetMouseLocation`: pick Command View cells with the
  `cv.select <floor> <column>` dev command; click buttons with `instance_path`.
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
