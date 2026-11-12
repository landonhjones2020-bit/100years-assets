# Prompt 25: The Source (its chamber, the final Surge, both victories, Endless)

The century now has an end. The Source sleeps in a chamber behind floor 10 and can be killed
there at any point for the Deep Victory; left alone, it rises into the bunker at Year 100 and the
final Surge lasts until it is beaten, which is the Century Victory. Its fight is the bible's one
line: tendrils in many rooms at once, then the core, twice over. Each victory has its moment
before the run report, and Keep Going carries either one into Endless. Built and tested on
2026-11-12. The final build is `p25-33ee455` (code asset 95026446991297, revision 117), installed
in Run and Lobby: StructureCheck 0 errors (Run 580 checks, Lobby 356), 132 data tests.

What is in it:

* **The Source Chamber** (Section 6: floor 10, "A living cavern around the Source"). The first
  floor 10 cell the team digs opens on it. The old mine's last gallery breaks through high in the
  wall of a hall 72 studs across, 90 deep and 28 high: a ledge to look out from, a ramp of rock
  down to the floor, ribs of bone over where the Source sits, roots as thick as a resident, veins
  of its light running to a web on the roof, eyes in the rock.
* **The Source asleep.** It is there when the chamber opens, eye shut. It wakes when a player
  comes within 44 studs of it or hurts it (a shot from the ledge wakes it).
* **The fight** (Section 10: "Several phases: tendrils in many rooms at once, then the core, so
  the team has to split up and regroup."): 40,000 health, four stages.
  1. **Tendrils.** Its eye is shut (hits do 5%). Three tendrils (one more for each player after
     the first) rise in rooms spread over the bunker's floors. Each has 900 health, slams whoever
     comes within 12 studs (22 to a player, 8 to a resident) and, with nobody in reach, slams its
     room for 10. Each one cut down takes an even share of 15% of the Source's health; the last
     one opens the eye.
  2. **The core.** The eye opens: it is the weak point (twice the damage; the rest is armour at
     half). It slams whoever is within 17 studs of its front for 50, and every 8 seconds two roots
     burst up under survivors (a ring on the floor 1.3 seconds before, then 20 damage). Until 50%.
  3. **Tendrils again:** five of them (plus one a player), and an extra breach opens.
  4. **The core again**, to its death: faster slams, three roots every 6 seconds, and a tendril
     grows back every 14 seconds (never more than two standing).
* **In its chamber** two of the tendrils (four in stage 3) rise round it and the rest in the
  deepest rooms above, so most of the fight is in the hall and somebody still has to go back up.
* **Century Victory** (Section 5). At Year 100 the next Surge is the final one: the Source rises
  through the floor of the bunker's deepest tunnel (if it was still asleep in its chamber it
  leaves it first) and the Surge has no timer. Beating it ends the Surge and wins.
* **Deep Victory** (Section 5: "at any point in the run. The run ends at once"). Killing it in its
  chamber wins at once, in any year, including during the final Surge.
* **The victories' moments.** Century: the camera stands in the Blast Door hall, the door lifts,
  daylight pours in and the picture goes up into white. Deep: the camera stands in front of the
  Source as it dies and the light goes out of the chamber's rock. Both: letterbox bars and a card
  (the year, the victory's name, its line typed out), 7 seconds, then the run report.
* **Endless.** Keep Going after either victory carries on: no final Surge, no era bosses, Endless
  Surges. This was Prompt 3's; this prompt makes it reachable by play and closes a Surge left
  open by a Deep Victory.
* **On the HUD.** The boss bar says EYE SHUT: CUT DOWN ITS TENDRILS (3 LEFT) or EYE OPEN: HIT THE
  EYE. Rooms with a tendril blink on the mini-map, and every tendril shows through the walls as a
  green outline, so a team that has to split up knows where to go.
* **Art (step A10's last part), made in Blender here:** Boss_Source (13,236 of 15,000 triangles,
  nine clips), Monster_SourceTendril (3,904 of 4,000, three clips), Cave_Source_Entry (14,678 of
  15,000). Kit_BlastDoor_L1 to L3 were re-exported so the door's bands, bracing and wheel are part
  of its leaves and lift with them.

Captures from the playtests: `previews/Game/P25_*.jpg` (the chamber from the ledge with the Source
asleep; the fight in the chamber; its eye open; a tendril in the Medbay; the Source risen into the
bunker; both victories' moments; the Deep Victory's report). Blender sheets:
`previews/Bosses/Boss_Source*.png` and `Source_*_sheet.png`, `previews/Monsters/Monster_SourceTendril.png`
and `SourceTendril_*_sheet.png`, `previews/Caves/Cave_Source_Entry*.png`.

**Not in it: sound** (Prompt 32); **Hard and Nightmare** unlocking from a Century Victory (Section
5; the meta is Prompt 29); the **BeatSource badge** (Prompt 29).

## Design Notes

The bible gives the Source two sentences and the victories three. These are the decisions I made
to turn them into a fight, each one a suggestion Landon can overrule.

1. **Four stages: tendrils, core, tendrils, core.** `Config.Bosses.Source` already said four
   phases, and "tendrils in many rooms at once, then the core" twice is the smallest thing that
   makes a team split up and regroup more than once. The stage is the fight's Phase.
2. **Tendrils are the Source's health in their stages.** With its eye shut the Source takes 5% of
   a hit, so the bar moves when a tendril falls: each takes an even share of the health between
   the stage's start and its end (15% over three tendrils, then 15% over five). The bar never
   stalls and the last tendril always ends the stage.
3. **A tendril stands still.** It rises through the floor of a room, one to a room, never a Shaft
   or the Reactor Core (a tendril on the reactor is a meltdown nobody can reach in time). It is
   spread across floors first. It turns to whoever is near and slams them; with nobody in reach it
   slams its room, so an ignored tendril wrecks a 500 HP room in under three minutes.
4. **Residents take 8 from a tendril, players 22.** The first playtest left three tendrils alone
   for four minutes and lost four residents of six. Residents already flee a room with a monster
   in it, but a starting bunker has nowhere left to flee to with tendrils on both floors.
5. **Roots reach the whole chamber.** At 60 studs a player could shoot the open eye from the
   ledge with nothing able to touch them. 90 covers the hall.
6. **The Source never walks.** It is "a glowing mass" (Section 3) with arms: it turns to the
   nearest player (30 degrees a second) and slams within reach. Everything else it does comes up
   through the floor.
7. **Its eye is its only weak point.** The Great Eye behind two armoured lids: shut in the
   tendril stages, open in the core stages. 4% of its health dealt to the eye within 4 seconds
   staggers it, like every boss.
8. **The chamber is sunk under the gallery.** As first built, the hall stood 30 studs above floor
   10's floor, into the height where floor 9's caves lie, and the cave planner would have refused
   the chamber its place whenever a floor 9 cave was already behind those columns. Now the hall's
   floor is 16 studs below the gallery and its roof no higher than a tunnel's, so the whole piece
   stays inside floor 10's own height. It also gives the entrance its view: you come out on a
   ledge and look down at it.
9. **Every floor 10 cell opens on the chamber until one does.** A floor 9 cave with a Drop can
   still reach down into the chamber's place; that cell then gets a dark mouth and the next floor
   10 cell tries again. After the chamber stands, the rest of floor 10 is plain rock.
10. **Asleep, it is not a fight.** No boss bar, and an era boss can still arrive while it sleeps.
    Once woken it stays awake. If an era boss's Surge starts during the chamber fight, that boss
    waits and comes when the fight is over (two bosses never fight at once).
11. **Killed in its chamber is always the Deep Victory,** even during the final Surge: the bible
    gives the Deep Victory "the biggest payout" and says the run ends at once.
12. **Every monster dies with the Source.** In the second playtest a resident died to a Shardling
    while the Century Victory's report was open, where nobody can do anything about it.
13. **The Century moment is seen from inside.** "The blast door opens on a clearing sky": the hall
    the team has defended for a century, the door lifting, light. No outside set was built.
14. **The run report waits 7 seconds after a victory** (4 after a defeat), for the moment.

## Delivery Report

### Files

New:

* `game/places/Run/server/Lib/SourceFight.luau`: the stages, tendrils and roots.
* `game/places/Run/client/Controllers/VictoryController.luau`: the two moments.
* `studio/ui/Victory.lua`: the moment's screen (StarterGui.Victory in the Run place).
* `generators/Bosses/Boss_Source.py`, `generators/Monsters/Monster_SourceTendril.py`,
  `generators/Caves/Cave_Source_Entry.py`.

Changed:

* `BossService.luau`: the Source's look, its tick, the sleeper (`placeSleeper`, `wake`,
  `leaveChamber`), the final Surge, a boss that waits, the Deep Victory, the hit rules, dev
  commands (`boss.wake`, `boss.tendrils`, `boss.cut`, `boss.roots`, `boss.regrow`).
* `DeepService.luau`: floor 10's rolls, `SourceChamber()`, `DimChamber()`, the chamber's lamps.
* `CycleClock.luau`: Keep Going closes an open-ended Surge.
* `Rules/Boss.luau`: `SourceStage`, `SourceTendrils`, `TendrilHealth`, `SourceWound`,
  `SourceCoreOver`, `SourceRooms`.
* `Config/Tuning.luau` (`Source`, `Results.VictoryDelaySeconds`, `Deep.LowestY` -330),
  `Config/Animations.luau` (12 clips, five new activities), `Config/CavePieces.luau` (25 pieces).
* `BossController.luau` (the bar's words, the mini-map, tendril outlines, root marks),
  `ResultsController.luau` (the delay).
* `DataTests.luau`: 132 tests (new: "Boss: the Source's fight").
* `tools/cave_config.py` (the SourceChamber band, a piece's own name and words),
  `generators/Kits/Kit_BlastDoor.py` (the door's hardware is part of its leaves).

### Asset ids

| Asset | Id |
|---|---|
| Boss_Source | 133747379920334 |
| Monster_SourceTendril | 97585915789046 |
| Cave_Source_Entry | 104816413022471 (revision 2) |
| Source clips | Idle 92177314243693, Open 103624325457194, OpenIdle 120477812269121, Close 86623244783953, Attack 71429369736907, Slam 95808762165394, Roar 94451380198995, Stagger 101309093476984, Death 74449751138479 |
| SourceTendril clips | Idle 116697324036479, Attack 139666151004098, Rise 130729164866804 |
| Kit_BlastDoor_L1, L2, L3 | 113063578633543, 110643036646383, 106077377495492 (each revision 2) |
| Tooling | ArtSetupBatch_P25 130187891230908, ArtSetupBatch_P25Chamber 73772406016191, ArtSetupBatch_P25Door 122618651060779, UI_Victory_P25 116974707787806 |

### What was tested, and how

All in Studio playtests of the Run place (one player, the starting bunker, DevTools to move the
clock and to stand in for a team's damage). Size and pivot of every new model were checked by
`AssetSetup` in Studio.

| Checked | How | Result |
|---|---|---|
| The chamber opens from a floor 10 cell | `deep.cave 10 2` on a dug cell | one piece, the Source asleep on its Core socket |
| It wakes when a player comes close | walked down the ramp to 32 studs | Fighting, 40,000 health, stage 1 |
| It wakes when hurt | one pistol shot from the ledge, 61 studs away | Fighting at full health |
| Stage 1 in the chamber | `boss.tendrils` | two in the chamber, one in the Medbay (the deepest floor with rooms) |
| A tendril turns and slams | stood 8 studs in front of one | its AttackAt changed, facing me |
| A tendril slams its room | left the Medbay's alone 50 s | Medbay 500 to 248 HP (at the first build's 18 a slam) |
| Real shots on a tendril | three pistol shots | 900 to 864 (12 each) |
| Tendrils wound the Source | `boss.cut` in stages 1 and 3 | 40,000 to 34,000 (85%); 19,946 to 14,000 (35%) |
| The eye opens, real shots on it | three pistol shots at the eye | 54 damage: two weak-point hits at 24, one armour hit at 6 |
| Stagger | `boss.hurt 2000 weak` | the Stagger clip, StaggeredAt set |
| Stage 3 | `boss.hurt` past 50% | Close, Roar, five tendrils (four in the chamber), an extra breach (13 monsters) |
| Stage 4 | `boss.cut` | eye open, a regrown tendril after 14 s, root marks |
| Its slam | stood 14 studs in front | Attack clip twice in 6 s (god mode: no damage read) |
| Root marks on the client | a mark placed by hand with 7 s of warning | the ring, then 6 roots up to 9 studs |
| Deep Victory | its death in the chamber | run Ended, outcome DeepVictory, the moment, the report (88 Glowshards) |
| Keep Going after Deep | `run.keepgoing`, `year 99` | Endless; next Surge Endless, no final Surge |
| The final Surge | `year 100`, `clock.next` | "Final Surge Source"; the sleeper left its chamber; it rose at floor 10 after 8 s |
| Stage 1 in the bunker | `boss.tendrils` | Blast Door, Quarters (floor 1), Medbay (floor 2) |
| Stage 3 in the bunker | `boss` | all five rooms |
| Century Victory | its death in the bunker | "Final Surge over (Boss)", outcome CenturyVictory, the moment, the report |
| Keep Going after Century | `run.keepgoing` | Year 101, cycle 2, Endless |
| The Century moment | `victory.play century` after the door kit's fix | the camera faces the door, the door lifts with its wheel and bands, daylight, the wash |
| No errors | the console after each playtest | none |

### Not tested

* **A real team.** Every number is provisional: one player with DevTools can't tell whether three
  tendrils and 40,000 health are right for six players at Year 100.
* **A whole fight by real damage.** Stages were moved on with `boss.cut` and `boss.hurt`; only the
  pistol's hits on a tendril and on the eye were real shots.
* **Damage taken.** The player was in god mode throughout, so a tendril's 22, the slam's 50 and a
  root's 20 were not read off a health bar (a tendril downing residents was seen).
* **A boss that waits.** An era boss's Surge starting during the chamber fight was not played.
* **A floor 10 cell whose rock is another cave's.** The code path (a dark mouth, the next cell
  tries) exists but no floor 9 cave was built first.
* **Digging to floor 10 by hand** with the Push Deeper vote: the cell was dug with `grid.dig` and
  opened with `deep.cave`.
* **The Deep moment with other players in other places,** and both moments on a phone.
* **The Lobby place** has the build installed (StructureCheck and data tests) but nothing of this
  prompt runs there.

### Known rough edges

* The door lifts as one slab: its two leaves are one part in the kit.
* During the Century moment the hall is as lit as the bunker left it (red if it has no power).
* A tendril has no weak point (its clips play on clients, so the server doesn't see where its eye
  is).
* Monsters vanish at the Source's death instead of dissolving (the camera has already cut away).

## Bible Questions

1. **The stages.** Tendrils, core, tendrils, core, with the tendrils worth 15% of its health each
   time. Is that the fight you meant by "tendrils in many rooms at once, then the core"?
2. **Should a tendril ever stand in the Reactor Core?** I kept them out: one there is a meltdown
   while the team is split up. It would be the hardest version of "split up".
3. **The chamber fight sends one tendril (or more, with more players) back up into the bunker.**
   Should the chamber fight stay in the chamber instead?
4. **Waking it.** It wakes at 44 studs or when hurt, and never sleeps again. Should a team that
   retreats be able to let it sleep?
5. **A Deep Victory during the final Surge** counts as Deep (the bigger payout). Right?
6. **Every monster dies with the Source.** Right, or should the bunker still have to be cleared?
7. **Does the Source need its own minions?** The other bosses have one each (`Minions`); the
   Source has tendrils and an extra breach.
8. **Floor 10 is only the chamber.** After it opens, other floor 10 cells are bare rock with no
   ore and no finds. Should digging floor 10 be worth anything else?
9. **Century Victory: should the residents walk out?** The moment shows the door and the light.
   Residents leaving through it would need a walk-out and an outside.
10. **Reaching the chamber pays 3 Glowshards as a band reached** (Section 16 says 12 for the
    Source Chamber in total, which the four bands add up to). Should finding the chamber pay
    something of its own?
11. **Endless after an early Deep Victory** keeps the year where it was (Year 1 in my test) and
    counts up with Endless Surges. The bible says "stronger Surges past Year 100": should an early
    Endless jump to Year 100's strength, or grow from where it is?
