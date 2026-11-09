# Prompt 12: Threats and monsters

Monsters come for the bunker (bible Section 10, with Sections 6, 11 and 23): a Threat Director
spends a danger budget on monster groups at breach points, warnings give the team 10 seconds,
monsters go for residents, machines and the players who hit them, rooms take damage, residents
flee, and a cleared Surge ends early. The four Mines monsters (art step A4) are in, rebuilt with
much more detail at Landon's request, and the first boss, the Brood Mother, is modelled and
animated for Prompt 15. Built and tested on 2026-11-08. The final install is `p12-25453ec`
(code asset 95026446991297 revision 42), in Run and Lobby.

## Design Notes

**Decisions**
1. **A pure rule module and three services** (Section 23: rules in Shared, state on the server).
   * `Shared.Rules.Threat` has no state: the threat level, budgets, the era's roster, buying
     groups, weighted picks and target order. The data tests run it directly.
   * `ThreatDirector` decides when and how much, `BreachService` where, `MonsterService` what
     the monsters do. Each can be tested and replaced on its own.
2. **The threat level** (Section 10 lists the inputs; the weights are provisional, in
   `Tuning.Threat`): `(12 + 1.2 × year + 4 × deepest floor + 0.25 × Disturbance + 1 × rooms) ×
   PlayerScale[players]` (1, 1.6, 2.1, 2.5, 2.8, 3 for 1 to 6 players).
   * A normal Surge spends the level; between Surges, 10% of it on single monsters, checked
     every 15 s from the second day.
   * The Tutorial Surge has its own small budget (6). Boss and Final Surges spend nothing here:
     the boss prompts own them.
   * An account's first run is 30% easier in Era I (Section 22).
3. **Who comes**: the era's roster is every monster introduced up to the current era (Era I:
   Burrow Ticks, Tunnel Hounds, Hollow Miners, Spitter Grubs), never Surface-only ones.
   Groups are bought with each type's Threat Cost and group size, preferring variety.
4. **Waves.** A Surge's groups open in up to four waves 14 s apart, at up to three different
   breach points, each after the bible's 10-second warning. At most 25 monsters are on the map
   (Section 23); the rest queue and come as others die.
5. **Breach points** (Section 10): room vents (not the Shaft or the Blast Door) and dug cells at
   the rock edge of the deepest band.
   * Dark rooms are picked twice as often (Section 6: dark rooms spawn monsters twice as often).
   * A barricaded point a quarter as often (the Engineer's barricade, Prompt 20, sets the
     attribute).
   * The warning: dust and a pulsing red light at the point, an alert on the HUD ("BREACH IN
     10 S: KITCHEN · 4 MONSTERS"), a blink on the mini-map, a countdown in the Command View's
     Threat overlay.
6. **What monsters go for** (Section 10: residents first, then machines, then players who hit
   them; each type its own priorities, Appendix).
   * Each type's `Targets` order from `Config.Monsters`; the Hollow Miner goes for machines
     first.
   * A monster that is hit turns on the player for 10 s. A player who walks right up to a
     monster (9 studs) gets attacked, except by Tunnel Hounds, which sprint past defenders
     (Appendix: Runner).
7. **Attacks.**
   * Damage lands after a windup, at the clip's Hit marker (the model's `HitTime` attribute),
     so what you see is when you get hurt.
   * Rooms: a monster attacking a machine damages its room through BunkerGrid, at half its
     damage (the Hollow Miner 1.25× that). A room at 0 HP is wrecked (Prompt 4's rules).
   * The Spitter Grub spits a glowing goo ball that damages and slows (60% speed for 3 s).
   * Burrow Ticks latch onto residents (Appendix): a weld, a bite every 1.2 s at 40% damage,
     until hit off.
   * A stunned monster (melee stuns, Shock Mines) stops.
8. **Residents** (Section 11: the unarmed flee to the nearest safe room): a resident near a
   monster runs to the nearest room with no monster in or next to it and stays 6 s after it is
   safe. A lone Burrow Tick they swat themselves.
9. **The Surge ends when it is cleared**: every wave out, none of its monsters left, no disaster
   running (Prompt 13 will report disasters). The siren's timer still ends it otherwise.
10. **The Reactor Core at 0 HP loses the run at once** (`RunDirector:Lose("ReactorDestroyed")`).
    Section 10's 60-second meltdown is a disaster for Prompt 13 (a Bible Question below).

**The A4 detail pass (Landon, mid-prompt: "make the monsters more detailed and the bosses need
to really stand out, they should be scary")**
* All four Mines monsters were rebuilt with the same rigs and much more detail, inside their
  triangle budgets, never gory:
  * **Burrow Tick** (2,028 tris): a banded wet-black shield over an abdomen that leaks Source
    light through the seams, stone spines, four burning eyes, hooked pale fangs, palps, six spiny
    legs ending in hooks.
  * **Tunnel Hound** (3,414): a pale skull with a burning slit under a heavy brow, swept-back
    horns, a hinged jaw full of fangs (a new Jaw bone: the bite opens and snaps), stone ribs over
    a starved chest, spine crystals, long digging claws, a crystal-tipped whip tail.
  * **Spitter Grub** (3,474): a pale banded larva with plum plates, three swollen glowing goo
    sacs with veins to the head, six pinprick eyes, a lamprey mouth of four toothed petals (new
    bones: they peel open on the spit).
  * **Hollow Miner** (3,734, the A0 model): a cracked helmet leaking light, a caged lamp, glowing
    streaks from the eyes and a wider shard grin, a crystal cluster bursting from the back, claw
    fingers, a lantern, rope and canteen on the belt, a cracked glowing pickaxe.
* **The Brood Mother** (9,924 of the boss's 15,000): a spider-tick queen about 16 studs long,
  her legs arching about 10 studs high over a 5-stud resident; a crown of Source crystals over
  eight burning eyes, two great pale fangs dripping light, grasping palps, a glowing maw, an
  abdomen banded in wet-black armour with light leaking from every seam, and a swollen glowing
  belly full of eggs (the bible's weak point: a separate `Belly` part with Role `WeakPoint` that
  raycasts hit). Seven clips: Idle, Walk (an eight-legged creep), Attack (rear and slam, Hit
  0.8 s), Roar (her entrance), LayEggs (Lay 1.4 s), Stagger (her belly is hit), Death.
* **The egg sac** she lays: three half-see-through glowing eggs with an unborn tick curled in
  each, on a plum mound pinned by web strands.
* `STYLE.md` now has the monster and boss rules, so the later eras follow them.

**Design Risks**
* Monsters may be too strong for an undefended bunker. In playtests, two residents died in the
  Tutorial Surge with nobody fighting. Room damage was halved after the first test; Landon will
  judge the numbers in play (all provisional, in `Tuning.MonsterAI`).
* Ticks latching onto residents is frightening but can feel unfair if nobody is near. A latched
  tick is easy to hit off, and residents swat a lone one.
* A big spider is a common fear. She is a fantasy creature (a tick-spider of glowing crystal and
  armour, no hair, no gore), and the Studio shots read as a monster, not a real spider.

**Scope Risks**
* No pathfinding beyond the bunker's PathGraph: monsters walk doorways and Shaft stairs like
  residents. Climbing over rubble or through dug tunnels waits for Prompt 14's digging.
* Spawning 25 rigged monsters at once is the worst case for phones (25 × up to 3,700 triangles
  plus the bunker). It ran smoothly in Studio; phones are untested.

**Bible Questions**
1. **The Reactor Core at 0 HP.** Built: the run is lost at once ("ReactorDestroyed"). Section 10
   also describes a Reactor overload: a 60-second meltdown that three valves stop. Should a
   destroyed Reactor Core start that meltdown instead of losing at once?
2. **Breach points on dug cells**: built as cells at the rock edge of the deepest band only.
   Should every dug cell at the rock edge count, or only the deepest band?
3. **Targeting a player who walks up** (9 studs). The bible says monsters go for players who hit
   them. Built: a player who walks right up to a monster also becomes its target, except for
   Tunnel Hounds. Keep?
4. **Room damage.** Built: rooms take half a monster's damage (the Hollow Miner 1.25× that),
   after one Hollow Miner wrecked a room in 12 s. Is that right, or should rooms be sturdier
   still?
5. **Residents' flee and swat.** Built: residents run to a safe room within 22 studs of a
   monster and swat a lone Burrow Tick (6 damage a second). Armed residents fighting is later.
   Keep?
6. **Throwables have no source yet.** They come in kits (the Demolitionist's +2 Frags). Should
   they also be crafted, bought or found? (Prompt 19's crafting or Prompt 18's loot?)

**Recommended Improvements**
* A short camera shake and a rumble on a breach near the player.
* A Latched clip for Burrow Ticks (they hold the rest pose while latched) and a Stunned clip for
  every monster.
* A kill counter per run for the results screen (Prompt 15) and the Monsters1000 badge.

**Technical Risks**
* Monster AI runs on the server at 5 Hz. With 25 monsters that is fine; bosses with many parts
  (the Brood Mother has 37 MeshParts) should keep their own loop.
* NPCAnimator replays Attack on each `AttackAt` change; a dropped attribute update would skip
  one swing's clip but not its damage.

## Delivery Report

**Overview.** Threats run end to end in the Run place: the director spends budgets, breach
points warn and spawn, monsters walk, attack rooms, residents and players, residents flee,
players kill monsters, a cleared Surge ends early. The four Mines monsters animate in the
bunker and the Brood Mother waits in `ServerStorage.Assets.Bosses` for Prompt 15.

**Files created**
* `game/shared/Rules/Threat.luau`
* `game/places/Run/server/Services/MonsterService.luau`, `BreachService.luau`,
  `ThreatDirector.luau`
* `game/places/Run/client/Controllers/ThreatController.luau`
* `generators/Monsters/Monster_BurrowTick.py`, `Monster_TunnelHound.py`,
  `Monster_SpitterGrub.py`, `_beast.py` (the A4 monster kit and detail helpers)
* `generators/Bosses/Boss_BroodMother.py`, `Boss_BroodMother_EggSac.py`
* `previews/Monsters/*`, `previews/Bosses/*`, `previews/Game/P12_*.jpg`, `previews/Game/A4_*.jpg`

**Files modified**
* `Config`: `Tuning` (Threat, MonsterAI), `Animations` (monster and boss clips, Rig and Activity
  enums).
* `RunState` (Threat, Monsters), `ResidentBrain` (flee, swat, slowed), `NPCAnimator` (monsters),
  `StructureCheck`, `DataTests` (81 tests: threat level and budgets, groups, picks, targets, the
  clips every Mines monster and the Brood Mother need).
* `generators/Monsters/Monster_HollowMiner.py` (walk clip, detail pass),
  `generators/lib/steadfast.py` (4-sided tubes).
* `tools/setup_batch.py`, `studio/AssetSetup.lua`: the generator's scalar meta becomes model
  attributes (`HitTime`, `LayTime`, `Role`), so re-imports no longer lose them.

**Architecture**: `game/docs/ARCHITECTURE.md`, section "Threats and monsters".

**Integration notes**
* **Prompt 13 (disasters)**: `ThreatDirector:SetDisasterCheck(fn)` keeps a Surge open while a
  disaster runs; each Surge's budget should also buy one disaster (Section 10). The Reactor's
  meltdown replaces the instant loss if Landon says so (Bible Question 1).
* **Prompt 14 (digging, Disturbance)**: call `ThreatDirector:ExtraBreach()` at 50 and
  `ThreatDirector:Tremor()` at 100. Newly dug cells become breach points automatically.
* **Prompt 15 (the Brood Mother)**: her model, sockets, `Belly` weak point, `HitTime`, `LayTime`
  and seven clips are ready; `Config.Bosses.BroodMother` has her health (6,000) and phases (2);
  the egg sac is `Boss_BroodMother_EggSac` (its eggs are hittable, socket `Hatch`).
* **Prompt 20 (classes)**: the Engineer's barricade sets `Barricaded` on a breach point's room.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Installed `p12-25453ec` in both places: StructureCheck 0 errors (Run 372 checks, Lobby
  232), 81 data tests passed in each; the Lobby starts cleanly with it.
- [x] Breach warnings: the HUD alert, the mini-map blink, dust and the red light; monsters came
  out of vents and the rock edge.
- [x] A Hollow Miner smashed rooms; ticks latched onto residents; residents fled and swatted.
- [x] The Tutorial Surge (6 monsters in 2 groups): clearing every monster ended it early
  ("Tutorial Surge over (Cleared)"), then cycle 2.
- [x] A player killed an AI monster: three revolver hits took a Tunnel Hound from 60 to 24, a
  reload and three more killed it, and it left the map (`previews/Game/P12_Studio_ShootHound.jpg`).
- [x] The rebuilt monsters in the bunker with their new clips playing (checked on the client:
  the Spitter Grub's attack 122661270451993, the Tunnel Hound's walk 87238019294136, the Hollow
  Miner's attack) (`previews/Game/A4_Studio_InBunker.jpg`).
- [x] The six models set up in Studio (size, Motor6Ds, welds, HitTime and LayTime attributes);
  the Brood Mother seen from a resident's height (`previews/Game/A4_Studio_BroodMother.jpg`,
  `A4_Studio_Lineup.jpg`).
- [ ] The Spitter's goo slowing a real player; the Brood Mother's clips on her model (Prompt 15
  plays them); phones with 25 monsters; two real players.

**Future extension notes**
* A new monster is data plus art: an entry in `Config.Monsters`, a generator in
  `generators/Monsters/` using `_beast.py`, and its Walk and Attack clips in
  `Config.Animations` (the data test asks for them).
* A new breach point kind is a new id prefix in `BreachService` and a weight.

---

## Addendum: Landon's answers to the Prompt 12 questions (2026-11-08)

| # | Question | Landon | Built |
|---|---|---|---|
| 1 | A Reactor Core at 0 HP: lose at once, or start Section 10's 60-second meltdown? | Yes, the meltdown | Not yet: it is the bible's Reactor overload disaster, so Prompt 13 builds it with the other disasters (`DisasterService`): at 0 HP a 60-second countdown starts, three valves in the Reactor Core turned together stop it, otherwise the run is lost. Until then the run is still lost at once. A solo player needs a rule for "together" (a Prompt 13 question) |
| 2 | Every dug cell at the rock edge a breach point, not only the deepest band's? | Yes | `BreachService`: every floor. Checked in a Run playtest: after digging into floor 4, the rock-edge cells on floors 1 to 3 stayed breach points |
| 3 | Monsters attack a player who walks right up to them (not Tunnel Hounds)? | Yes, keep | unchanged |
| 4 | Rooms take half a monster's damage: sturdy enough? | Yes | unchanged |
| 5 | Residents flee and swat a lone Burrow Tick? | Yes, keep | unchanged |
| 6 | Where do throwables come from? | Craft them, find them exploring, and buy them as supplies before a run | Crafting: the Workshop recipes were already in `Config.Recipes` (built in Prompt 30). Exploring: Deep caches now hold Frag Grenades and Flares, the hardware store Foam Grenades, the checkpoint Shock Mines (with the gas station's Flares and the checkpoint's Frags; looted from Prompts 16 and 17). A data test checks every throwable has a recipe and a loot source. Pre-run supplies: in the bible; the Lobby's loadout and shop prompts (21, 28) build them. Proposed currency Glowshards, to confirm |

Built in `p12-c202004` (code revision 43), installed in Run and Lobby: StructureCheck 0 errors,
82 data tests passed. The bible (live doc rev 128) has all six answers.
