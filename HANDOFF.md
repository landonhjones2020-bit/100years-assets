# 100 Years Of Fallout: handoff for the next chat

Written 2026-11-08 (night), at the end of the Prompt 12 session. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU, rev 130, and the two project parts, which match
it) wins over everything here.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private; head `ce31d3e`) and read
   `CLAUDE.md` (the runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Never touch the Night Shift studio.

## Where things stand

* Prompts 0 to 12 are built and tested in Studio. Code build `p12-c202004` (code asset
  95026446991297, revision 43) is installed in both places; 82 data tests pass.
* Prompt 12 (threats and monsters): the Threat Director, breaches with 10-second warnings,
  monster AI, rooms taking damage, residents fleeing, a cleared Surge ending early, players
  killing monsters. Report: `game/reports/P12_Threats.md`.
* Art A4: the four Mines monsters rebuilt with much more detail after Landon asked for it
  (the Tunnel Hound has a jaw, the Spitter Grub a petal mouth), and the Brood Mother (the
  Year 25 boss, 9,924 triangles, seven clips, a glowing Belly weak point) with her egg sac, all
  in `ServerStorage.Assets` in the Run place. Landon's rule: monsters detailed, bosses the
  scariest thing in their era (bible Section 19, `STYLE.md`).

## Landon's latest decisions (all in the bible)

* A Reactor Core at 0 HP starts a 60-second meltdown instead of losing at once. Three valves
  turned together stop it; with 1 or 2 players each turned valve stays turned for 10 seconds.
* Every dug cell touching rock is a breach point, on any floor (built).
* Monsters attack a player who walks right up to them, except Tunnel Hounds; rooms take half
  a monster's damage; residents flee and swat a lone Burrow Tick (kept as built).
* Throwables: crafted at the Workshop, found exploring (in the loot tables now), and bought
  before a run as supplies with Glowshards.

## Next, in order

1. Prompt 13: disasters (fire, blackout, cave-in) and repairs, including the Reactor
   meltdown above (it is the bible's Reactor overload disaster). Until it is built, a destroyed
   Reactor Core still loses the run at once.
2. Prompt 14: digging, depth bands, Disturbance, Push Deeper.
3. Prompt 15: the Brood Mother's fight (her art, clips, sockets and weak point are ready) and
   the results screen.

## Waiting on Landon

* His look at the rebuilt monsters (the Hollow Miner changed after its A0 approval) and the
  Brood Mother: `previews/Game/A4_Studio_*.jpg` in the repo.

## Small bugs seen, for later prompts

* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
