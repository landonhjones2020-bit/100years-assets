# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-09 (night), at the end of Prompt 13. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 130, and the two project parts, which match
it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.

## Where things stand

* Prompts 0 to 13 are built and tested in Studio. Code build `p13-7d05592` (code asset
  95026446991297, revision 46) is installed in both places; 90 data tests pass.
* Prompt 13 (disasters and repairs): fires that spread and are put out by residents, the
  Extinguisher and Foam Grenades; blackouts and the fuse box; cave-ins that block, trap and are
  dug or smashed through; the Reactor meltdown (a Reactor Core at 0 HP: 60 s, three valves,
  solo turns last 10 s, a lost meltdown loses the run); electrical surges; each Normal Surge
  buys one disaster; wrecked rooms repaired by the Welder and their workers. Report:
  `game/reports/P13_Disasters.md`.
* Art: the Extinguisher (v2, 0.8 scale), the Welder, doorway and tunnel rubble, and their hotbar
  icons, all in the Run place's `ServerStorage.Assets`.

## Landon's latest decisions (all in the bible)

* A Reactor Core at 0 HP starts a 60-second meltdown (built in Prompt 13).
* Every dug cell touching rock is a breach point, on any floor.
* Throwables: crafted, found exploring, and bought before a run as supplies with Glowshards.

## Next, in order

1. Prompt 14: digging, depth bands, Disturbance, Push Deeper. Digging and Tremors call
   `DisasterService:CaveIn`; Disturbance 50 calls `ThreatDirector:ExtraBreach()`, 100
   `ThreatDirector:Tremor()`. The Drill and Pickaxe need models and icons.
2. Prompt 15: the Brood Mother's fight (her art, clips, sockets and weak point are ready) and
   the results screen.

## Waiting on Landon

* His answers to the six Prompt 13 Bible Questions (in the report).
* His look at the rebuilt monsters and the Brood Mother (`previews/Game/A4_Studio_*.jpg`).

## Small bugs seen, for later prompts

* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* Studio's screen captures leave out billboards (prompts, plates), so check those by using them.
