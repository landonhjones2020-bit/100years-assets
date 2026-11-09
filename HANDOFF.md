# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-09 (night), at the end of Prompt 15. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 130, and the two project parts, which match
it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.

## Where things stand

* Prompts 0 to 15 are built and tested in Studio: the First Playable milestone's prompts are all
  done. Code build `p15-c2fc8a4` (code asset 95026446991297, revision 57) is installed in both
  places; 99 data tests pass.
* Prompt 15 (the Brood Mother and the results screen): Year 25's boss Surge brings her up through
  the deepest tunnel after an 8 s warning; she slams, lays egg sacs that hatch Burrow Ticks (break
  or burn them), takes double damage on her glowing belly and half on armour, staggers, shrieks
  into phase 2 at half health, and her death ends the Surge. The HUD has a boss bar. When a run
  ends, every player is paid (Glowshards, account experience, profile stats, `FirstRunDone`) and
  the Run Report shows the summary, the story, the residents, the rewards and the MVP, with Play
  Again (a vote), Keep Going and Return to Lobby. Report: `game/reports/P15_BroodMother_Results.md`.
* Prompt 14 (digging, depth bands, Disturbance, Push Deeper) and Prompt 13 (disasters and
  repairs): reports in `game/reports/`.
* Art: the Brood Mother's body parts now use Hull raycast shapes (the new `queryhull` collision
  kind), set in Studio; her uploaded model is unchanged.

## Landon's latest decisions (all in the bible)

* A Reactor Core at 0 HP starts a 60-second meltdown (built in Prompt 13).
* Every dug cell touching rock is a breach point, on any floor.
* Throwables: crafted, found exploring, and bought before a run as supplies with Glowshards.

## Next, in order

1. Prompt 16: the surface (Brightwater Ruins, storms, loot, hauling, rescues). Add hauls and
   rescues to the run's stats and story (`ResultsService`: `bump`, `story`).

## Waiting on Landon

* His answers to the six Prompt 15, eight Prompt 14 and six Prompt 13 Bible Questions (in the
  reports).
* His look at the Brood Mother in action (`previews/Game/P15_*.jpg`) and the rebuilt monsters
  (`previews/Game/A4_Studio_*.jpg`).

## Testing tips

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
