# Prompt 23: The Flooded Caverns (floods, gas, four monsters, The Deluge)

Era II now has its threats. Rooms flood and fill with gas, digging can hit a hazard pocket, the
four Flooded Caverns monsters each do what the bible's one line says they do, and Year 50's boss,
The Deluge, swims under the floors, floods the rooms it passes and comes up to bite. Built and
tested on 2026-11-11. The final build is `p23-2c5a6ae` (code asset 95026446991297, revision 103),
installed in Run and Lobby: StructureCheck 0 errors (Run 577 checks, Lobby 356), 126 data tests.

What is in it:

* **Floods** (Section 10: "Water rises in a room and pours down the Shaft. Patch the burst pipe,
  then the room drains."). A burst pipe hangs on the room's back wall and sprays; the water rises
  2.5 a second to 100, pours into the rooms beside it and down the Shaft, slows whoever wades in
  it, hurts people and the room once it is deep, and drains at 4 a second once the pipe is patched
  (hold Interact 3 s). Residents leave a room before the water is deep.
* **Gas leaks** ("Poison gas fills a room, hurting everyone inside. Seal the vent or air the room
  out."). A blown vent on the wall leaks; the gas builds to 100, hurts everyone in the room (6 a
  second to a player at full strength), tints the screen of whoever stands in it, and clears once
  the vent is sealed (3 s) or, left alone, after the 90 seconds in `Config.Disasters`.
* **Hazard pockets** (Section 6's 6% of dug cells: "Gas or water bursts out"): gas in the Mines,
  gas or water in the Flooded Caverns, into the room the digger stands in or the nearest room on
  that floor.
* **Surges** bring floods and gas leaks from Era II (Landon, Prompt 13), and Era II's Surges send
  the four new monsters.
* **Murkling** (swarmer, "Pours out of water"): a room flooded to 30 or more becomes a breach
  point of its own, and a Surge's Murklings come out of it.
* **Bloat Toad** (exploder, "Bursts on death or contact and floods the room"): it reaches
  something, swells for 0.7 s and goes off: 40 damage within 9 studs and 35 of water in the room.
* **Lurker** (ambusher, "Hides in water or dark rooms and grabs residents"): it walks to the
  nearest flooded or dark room, fades to almost nothing (its lure stays lit), strikes whoever
  comes within reach, and holds a resident it grabs until it is hit hard enough.
* **Tide Crab** (tank, "Armoured front, weak point on its back"): a quarter damage from in front,
  double from behind, and it turns slowly when it stands to fight so its back can be reached.
* **The Deluge** (Year 50: "A giant eel surging up the flooded tunnels. Floods every room it
  passes; strike its head when it surfaces and drain the rooms behind it."): 12,000 health, three
  phases. Design Notes 6 has the fight.
* **Class and draft effects that were waiting on this**: Foam Burst dries a flood, the Hazmat Tech
  is immune to gas, Decon Field clears it, Sump Pumps double the drain, Gas Filters halve the gas.
* **Art (step A8), made in Blender here**: Monster_Murkling (2,776 triangles), Monster_BloatToad
  (3,468), Monster_Lurker (3,880), Monster_TideCrab (3,972), Boss_Deluge (11,408 of 15,000),
  Kit_BurstPipe (1,732), Kit_GasVent (1,040), and 19 clips.

Captures from the playtests: `previews/Game/P23_*.jpg` (The Deluge up, staggered and under the
floor; the flooded Quarters; the gassed Medbay; the Lurker hidden and striking; the four monsters
under a lamp). Blender sheets: `previews/Monsters/` (each monster and its clips),
`previews/Bosses/Boss_Deluge*.png` and `Deluge_*_sheet.png`, `previews/Kit/Kit_BurstPipe.png` and
`Kit_GasVent.png`.

**Not in it: sound.** The spray, the hiss, the toad's burst and The Deluge's roar come with
Prompt 32 (the client already asks for `WaterSpray` and `GasHiss`).

## Design Notes

**Decisions**
1. **Water is a level per room, 0 to 100** (`Rules.Disasters`), like a fire's strength. A burst
   pipe raises it; a patched room drains; a room beside or below a deep one fills from it but
   never above it. Up to 25 it is ankle deep and does nothing; from there people wade (75% speed
   falling to 45% at 100) and take damage that grows with depth (5 a second to a player at 100, a
   Firefighter a quarter of that). At 50 it starts to pour on every 20 seconds
   (`Config.Disasters`): down the Shaft first, else sideways into rooms on its floor, never up and
   never into bare tunnels.
2. **Gas is a strength per room.** It fills 5 a second while the vent leaks and clears 12 a second
   once it is sealed. "Or air the room out" is the vent stopping by itself after
   `DurationSeconds` (90): the leak runs out and the room clears.
3. **The fittings are real things on the wall.** DisasterService hangs `Kit_BurstPipe` or
   `Kit_GasVent` on the room's back wall with the prompt on it, so what the alert names is
   something to look for and run to. The Shaft floods with no pipe: water arrives there from
   elsewhere.
4. **Residents get out.** ResidentBrain treats a room flooded to 25 or gassed to 10 like a burning
   one: they leave, wait outside, and wade slowly if caught in it.
5. **The four monsters are four traits** in MonsterService, on the rows `Config.Monsters`
   already had: `FromWater` (new), `Explodes` and `Floods`, `Hides` and `Grabs`, `ArmoredFront`
   and `WeakPointBack`. The Lurker gives up waiting after 25 seconds (a Surge can't wait on it for
   ever) and hunts like anything else. The Tide Crab's arcs are 130 degrees of shell and 110 of
   back; standing to fight it turns 80 degrees a second and only strikes at what is in front of
   it, so one player can get round it and two can do it easily.
6. **The Deluge is BossService's second fight.** It arrives like the Brood Mother (warning, rise,
   roar) in the deepest tunnel, but it doesn't stay there:
   * **Up**: it stands out of the floor, turns to whoever is near and bites (35 within 7 studs of
     where its jaws land, every 3 s, faster in later phases). Its head is the weak point: the
     glowing crown on its skull and its glowing gullet. 4% of its health dealt there within 3 s
     staggers it: its head drops to the floor for 3 s.
   * **Under**: after 12 s up (10, then 8; sooner with nobody near) it dives and swims the
     bunker's cells to the nearest standing player it can reach, up and down the Shaft too. Only
     its crest cuts the floor, with spray and a light to follow; hits on it do a quarter. Every
     room it passes bursts a pipe and takes 30 of water. Patching those pipes is "drain the rooms
     behind it".
   * **Phases**: at each third of its health it roars and gets faster; from the second, Murklings
     come up with it (3, then 5).
   It moves every frame (an anchored model isn't smoothed between ticks) and decides ten times a
   second.
7. **The Deluge's model stands on the floor it comes through.** Its pivot is the floor under its
   neck; the coil behind it and its tail are modelled down through the floor. Sunk 10 studs with
   its head tucked under the arch of its neck (the Swim clip), only the crest stands above the
   floor (2.5 to 3.3 studs, measured in play).
8. **It lights its own face.** A boss's own light was behind the Brood Mother's head; The
   Deluge's is in front of its face and low, so in a dark room players see what is looking at
   them. The first build's capture was a black shape with green lines.

**Things the bible doesn't say, decided here and open to change (see Bible Questions)**: the water
and gas numbers; that The Deluge bursts pipes (not just leaves water); that it hunts the nearest
player; that a Lurker also strikes players; the Tide Crab's turn rate.

**A bug found and fixed that wasn't this prompt's: monsters never climbed the Shaft's stairs.**
Every 2.5 s a monster plans its route again, and a plan starts from the aisle of the floor it is
on. A monster at the foot of the stairs, or on them, was sent back to the aisle each time, so a
Surge that came in on floor 2 stood at the bottom of the Shaft for good (the first Era II wave I
ran: most of its 23 monsters lined up there). Now a monster about to climb keeps its plan, and one planned
again part-way to its next point carries on from where it is. Tracked in play: a Murkling from
the Water Purifier's vent reached the foot of the stairs in 7.0 s, was on floor 1 at 9.8 s and
attacking residents at 12 s. It still doesn't walk up the ramp: it stands at the foot for 2.5 s
and is then stepped to the top (the existing rule for anything stuck, which residents use too).
Small rigs can't climb that ramp; see Suggestions.

**Suggestions (not built)**
* A way up the stairs that is seen: move a monster along the ramp between the two waypoints
  instead of the 2.5 s wait and the step.
* A sound and a ripple a moment before The Deluge comes up, so the room has a beat to scatter.
* The Lurker's lure could sway toward the nearest resident: a tell for careful players.
* A solo player has a lot to patch in the boss fight (Bible Question 5).

## Delivery Report

**Overview.** Two disasters, hazard pockets, four monster behaviours, one boss fight, their art,
and the class and draft effects that were waiting for them. The rules are pure
(`Rules.Disasters`, `Rules.Threat`, `Rules.Bunker`, `Rules.Boss`) and data-tested; the numbers are
`Tuning.Disasters.Flood`, `.Gas`, `.HazardPocket`, `Tuning.MonsterAI` and `Tuning.Deluge`, all
provisional.

**Files created**
* Art: `generators/Monsters/Monster_Murkling.py`, `Monster_BloatToad.py`, `Monster_Lurker.py`,
  `Monster_TideCrab.py`, `generators/Bosses/Boss_Deluge.py`, `generators/Kits/Kit_Hazards.py`
  (the burst pipe and the vent). `_beast.py` gained `web` (fins and frills), `along`, and a
  `pivot` argument.
* `game/reports/P23_FloodedCaverns.md` (this).

**Files modified**
* `Rules/Disasters.luau`: `FloodStep`, `FloodDepth`, `WadeSpeed`, the flood damage functions,
  `FloodSpreadTargets`, `FloodFed`, `GasStep`, `GasSeconds`, the gas damage functions,
  `HazardKind`.
* `Rules/Bunker.luau`: `CellPath` (the shortest way between two open cells). `Rules/Boss.luau`:
  `Title`. `Rules/Threat.luau`: `Shell` (a shelled monster's hit by where it comes from).
* `Config/Tuning.luau`: `Disasters.Flood`, `.Gas`, `.HazardPocket`; `MonsterAI`'s burst, hide,
  grab and shell numbers; `Deluge`. `Config/Monsters.luau`: the `FromWater` trait.
  `Config/Animations.luau`: 19 clips, five rigs, the `Swim` activity. `RunState`: `Floods`,
  `GasLeaks`.
* `Lib/Hazards.luau`: floods and gas, `Unsafe`.
* `DisasterService`: `StartFlood`, `PatchPipe`, `Drain`, `Flooded`, `StartGasLeak`, `SealVent`,
  `ClearGas`, `Gassed`, `HazardPocket`; the fittings and their prompts; Surges may start either;
  the `FloodDrainSpeed` and `GasStrength` modifiers. Dev: `flood`, `flood.patch`, `flood.drain`,
  `gas`, `gas.seal`, `gas.clear`, `pocket`.
* `MonsterService`: the four behaviours, the `Burst` signal, the Shell damage filter, the slow
  turn, the stairs fix. Dev: `monster.hit <Type> <amount> [front|back|side]`; `monsters` now says
  hidden, holding and lair.
* `ThreatDirector`: flooded rooms as breach points for `FromWater` groups; a Bloat Toad's burst
  floods its room.
* `BossService`: The Deluge (the header says how), a look per boss, `DisasterService` as a
  dependency. Dev: `boss.start Deluge`, `boss.dive`, `boss.surface`.
* `ResidentBrain`: unsafe rooms, wading, standing still while grabbed. `DigService`: hazard
  pockets. `DraftService` and `Lib/ClassAbilities`: the two cards, Foam Burst, Decon Field.
* Client: `DisasterController` (water with a surface and an underwater tint, gas clouds, the
  spray and hiss at the fittings' sockets, wading, the gas tint, the Command View's statuses),
  `ThreatController` (a hiding Lurker, shell sparks, the burst), `BossController` (the bar says
  UNDER THE FLOOR or UP: HIT ITS HEAD; one THE in "THE DELUGE"; a shake when it surfaces).
* `DataTests`: 5 new tests (floods; where water goes; gas and hazard pockets; The Deluge and the
  cell path; the four monsters and the shell), and the dig and clip tests extended.

**Architecture.** `BossService` now depends on `DisasterService` (no cycle: DisasterService
depends on neither BossService nor ThreatDirector). Everything else sits where it did.

**Integration notes**
* A place needs the art in `ServerStorage.Assets` (`Monsters`, `Bosses`, `Kit`). Without
  `Kit_BurstPipe` or `Kit_GasVent` the fitting is a plain block; without `Boss_Deluge` the boss is
  a graybox.
* `Tuning.Deluge.SwimDepth` (10) belongs to the model: its Swim pose tops out 9.5 studs up and
  its crest 12.8. Change the model and it changes.
* A model whose lower part is meant to stay under the floor passes `pivot=` to `B.run`
  (The Deluge's first upload stood 1.9 studs high and 1.4 off-centre: its pivot was the bottom
  centre of its bounds).

**Changing it**
* Any number: `Config/Tuning.luau`. A monster's line of stats: `Config/Monsters.luau`.
* A monster's look or clips: its generator, then `SF_EXPORT=1`, PATCH the model (a new clip is a
  new asset: put its id in `Config/Animations.luau`).

**Testing checklist** (Run playtests on 2026-11-11, builds p23-79d3cc8 to p23-2c5a6ae, unless
marked)
* [x] Boots clean: 34 services, 23 controllers, no script errors or warnings from the game's code.
* [x] A flood rises (15 to 100 at 2.5 a second), spreads to the next room, drains once patched
  (100 to 68 in 8 s). (The first increment's playtest, build p22-6b3042e.)
* [x] Water hurts and slows: a player in a room at 100 lost 13 health in 3 s; `Wading` set.
* [x] Gas hurts: 6.0 health a second at strength 100, exactly Tuning's number.
* [x] The water and the gas look right in play (captures).
* [x] Six residents left the flooded Quarters ("Flee").
* [x] A hazard pocket on floor 2 leaked gas into the room the player stood in.
* [x] Foam Burst dried the Medbay; Decon Field cleared its gas.
* [x] Sump Pumps taken in a draft: the drain went from 4.2 to 8.2 a second.
* [x] Year 30: the Surge's roster has the four; Murklings came out of the flooded Kitchen.
* [x] A Bloat Toad burst within a second of reaching the player and left 35 of water.
* [x] A Lurker hid in a dark room and faded (capture), struck when the player came close
  (capture), and in a Surge grabbed a resident (124 health down to 19 while it held them).
* [x] A Tide Crab took 25, 100 and 200 from a 100 hit to its front, side and back; turned away,
  it faced the player again in 2.0 s.
* [x] The Deluge by its own Surge: Year 49's cycle ended, the next Surge was "Boss (Deluge)" with
  no timer, and the fight began.
* [x] The Deluge: warning, rise, roar; three bites downed a 100-health player; it dived when
  nobody stood near; swam to the player's cell, down and up the Shaft; burst a pipe in each room
  it passed, with the alert; came up beside the player; at two thirds health roared as it
  surfaced with 3 Murklings; 500 to its head staggered it (its crown 4 studs off the floor).
* [x] Real gunfire: one pistol shot (12) at its crown took 24, one at its neck took 6.
* [x] Beaten: it died where it was, the Surge ended, the next cycle began at 2 years a cycle.
* [x] 126 data tests pass in both places.
* [ ] Not tested: two or more players; a phone; the Hazmat Tech's immunity in play (the test ran
  under the dev god mode; the arithmetic is data-tested); Gas Filters in play; a Surge picking a
  flood or a gas leak by itself (data-tested); breaking a Lurker's grab; the quarter damage while
  The Deluge is under (my two shots landed as it came up); the shell sparks and the toad's burst
  as seen on screen; patching a pipe and sealing a vent by hand (the dev commands call the same
  functions the prompts do).

**Technical risks**
* The boss fight floods fast. With nobody patching, every room it passed was at 100 within two
  minutes. That is the fight ("drain the rooms behind it"), but the numbers are first guesses and
  a solo player is stretched (Bible Question 5).
* The Deluge comes up in the middle of a cell, through whatever furniture stands there.
* Monsters and the Shaft's ramp (above).
* Unpowered rooms are dark and these monsters are dark by design; they are seen by their glow.
  Two captures were taken with the client's ambient light raised, and one under a review lamp, to
  judge the art; the report's other captures are the game's own light.
* Roblox reported one failed fetch of the Lurker's Latched clip (HTTP 502) in the first session
  and of a UI atlas (108416061266181) once; neither appeared in the later session whose log I
  read in full.

## Bible Questions

(Landon answered these on 2026-11-12: `game/reports/Answers_2026-11-12.md`.)


1. **"Air the room out"**: I read it as the leak running out after 90 seconds if nobody seals the
   vent. Is there meant to be something players do (open a door, run a fan)?
2. **Water stays out of bare tunnels** (dug cells with no room). Should it fill them too?
3. **The Lurker grabs residents only**; it strikes players but doesn't hold them. Should it hold a
   player (mash to break free)?
4. **Murklings come from flooded rooms when there are any**, and from vents like the rest when
   there are none. Should they only ever come from water?
5. **The Deluge bursts a pipe in every room it passes.** The other reading is that it leaves water
   that drains by itself. And should what it floods scale with the party's size, as its health
   does?
6. **The Deluge hunts the nearest player.** Should it go for the Reactor Core or the residents
   instead, as other monsters choose targets?
7. **The Tide Crab turns 80 degrees a second** when it stands to fight, so its back can be
   reached. Faster, slower, or as fast as any monster (two players needed)?
8. **Residents' Hardy trait and the gas-proof outfit** (Section 11) do nothing to floods and gas
   yet: residents have no traits or outfits in play until their prompts.
9. **Flood and gas numbers** (rise 2.5, drain 4, wading at 25, damage 5; gas fill 5, clear 12,
   damage 6): any you want changed before a real team tries them?
