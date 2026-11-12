# Prompt 24: The Crystal Hollows (radiation leaks, outbreaks, four monsters, the Crystal Colossus)

Era III now has its threats. A storm can leak radiation through the Blast Door, a sickness can
come up from the Deep and spread between residents, the four Crystal Hollows monsters each do what
the bible's one line says they do, the band's caves are built and glow hot, and Year 75's boss,
the Crystal Colossus, tears out of the rock: armoured all over until a flare shows its cores.
Built and tested on 2026-11-11. The final build is `p24-968bd49` (code asset 95026446991297,
revision 113), installed in Run and Lobby: StructureCheck 0 errors (Run 577 checks, Lobby 356),
131 data tests.

What is in it:

* **Radiation leaks** (Section 10: "Surface storms against a weak Blast Door. Floor 1 fills with
  radiation. Seal or upgrade the door; Decon Room."). From Era III each Surge's storm is rolled
  against the door: 60% at level 1, 30% at level 2, never at level 3, plus 40% times the share of
  its HP the door has lost (a wrecked door always leaks). A clamp appears on the door's jamb, and
  radiation fills every open cell of floor 1: from 15 it rises 2.5 a second to 100. A player in it
  gains radiation (3 a second at full strength); residents leave at 10, lose health in it and are
  **Irradiated** from 40. It ends when someone seals the door (hold Interact 4 s at the clamp),
  when the door goes up a level, or after 120 seconds; then it fades. A working Decon Room halves
  how fast it fills and clears Irradiated residents at the next cycle.
* **Hazard pockets in the Crystal Hollows** leak radiation into one room, through a crystal seam
  that splits its back wall (sealed the same way).
* **Outbreaks** ("Wanderers, the Deep. A sickness spreads between residents. Medbay treatment and
  quarantine in Quarters."). From Era III someone rescued in the Deep, or a Deep expedition coming
  home, carries it 10% of the time. A **Sick** resident coughs, works at 70%, loses 5 health a
  cycle, and every 20 seconds has a 25% chance to pass it to someone in the same room. A sick
  resident with no job keeps to a Quarters bed (quarantine). A working Medbay treats one patient
  at a time: 45 seconds each.
* **Shardling** (swarmer, "Crystal bugs that shatter into stinging shards"): when one dies, its
  shards do 6 to everyone within 7 studs.
* **Prism Stalker** (ambusher, "Invisible until lit by a flare or lamp"): a glint in the air until
  it is within a flare's 40 studs, a cave lantern or the Scout's Flare Ping, or for 1.5 seconds
  after it strikes or is hit.
* **Geode Golem** (tank, "Very slow with huge health; shrugs off small guns"): the Pocket Pistol
  and the Rivet SMG do a fifth of their damage, with a ricochet.
* **Resonator** (support, "Hums to heal and speed up nearby monsters; kill it first"): it follows
  the pack and never strikes; every 4 seconds its hum gives each monster within 30 studs 8% of its
  health back and 35% more speed for 5 seconds.
* **The Crystal Colossus** (Year 75: "Tears out of the crystal rock. Huge, slow and armoured;
  flares show its weak points; its shards stun."): 20,000 health, three phases. Design Notes 7 has
  the fight.
* **The Crystal Hollows' caves**: eight pieces (floors 7 to 9), the band's Lost Crew hidden in one
  with its own radio log, and "radiation in the Crystal Hollows" (Section 12): a player's
  radiation climbs 0.2 a second inside them.
* **Class effects that were waiting on this**: Decon Field clears a leak's radiation, a level 3
  Triage Pulse cures the sick and the irradiated, the Hazmat Tech at level 3 doubles a Medbay's
  cure, Flare Ping shows Stalkers and the Colossus's cores.
* **Art (step A10), made in Blender here**: Monster_Shardling (3,176 triangles),
  Monster_PrismStalker (3,104), Monster_GeodeGolem (3,860), Monster_Resonator (3,030),
  Boss_CrystalColossus (12,736 of 15,000), Kit_DoorSeal (1,612), Kit_CrystalSeam (1,124), eight
  cave pieces (4,252 to 7,998 of 8,000) and 19 clips.

Captures from the playtests: `previews/Game/P24_*.jpg` (the Colossus through a doorway, lit by its
own charge, and lit by a flare in its Year 75 Surge; the four monsters; the door's leak and its
clamp; a crystal seam in the Medbay and in the Kitchen; the Command View in two leaks; a Crystal
Hollows cave's mouth and chamber). Blender sheets: `previews/Monsters/`, `previews/Bosses/Boss_CrystalColossus*.png`,
`previews/Kit/Kit_DoorSeal.png` and `Kit_CrystalSeam.png`, `previews/Caves/Cave_Crystal_*.png`.

**Not in it: sound** (Prompt 32), **wanderers** as a source of outbreaks (Prompt 30), and the
other conditions (Prompt 26: only Sick and Irradiated exist).

## Design Notes

**Decisions**
1. **Radiation is a strength per graph unit, 0 to 100** (`Rules.Disasters.RadiationStep`), like
   gas. A door leak covers every open cell of floor 1; a seam covers its room. A player's own
   radiation is the one meter the surface already fills (`SurfaceService`), so pills, the Decon
   Room and the sickness at 100 all work as they did.
2. **The door's clamp stands on the jamb, 8 studs along the wall.** The first build put it at the
   door's middle, where the lift's RIDE UP prompt is. Of two prompts on one key Roblox shows the
   one nearer the middle of the screen, so the seal could not be reached.
3. **A crystal seam looks for wall nobody will hide.** It tries seven spots along the back wall at
   three heights and takes the first with nothing standing within 5 studs in front of it (the
   first seam grew behind the Medbay's cabinet, the second behind the Kitchen's stove). In a
   furnished room it ends up above the shelves; the prompt reaches 14 studs.
4. **An outbreak is one event with a list of the sick.** Sick and Irradiated are fields on the
   resident (`ResidentService:SetCondition`), so Prompt 26's conditions have a place to go. A sick
   resident at work keeps working (and can infect the room); taken off the job, they quarantine
   themselves. Curing the last one ends the outbreak.
5. **The four monsters are four traits** in MonsterService on the rows `Config.Monsters` already
   had: `Shatters`, `Invisible`, `ShrugsSmallGuns`, `Heals` and `Hastes`. A light that shows a
   Stalker is any part tagged `RevealLight` with a `Radius` (flares, cave lanterns, a Flare Ping).
   "Small guns" are the two that fire light ammo (`Config.Items`' `Small` flag). The Resonator's
   hum was first every second, which gave a Geode Golem 72 health a second, more than a revolver
   takes off; it is every 4 seconds now.
6. **Radiation in the caves is the surface's calm rate** (0.2 a second, 100 in about 8 minutes),
   so a trip into the Crystal Hollows has the same kind of limit a trip to the surface has.
7. **The Colossus is BossService's third fight.**
   * **Arrival**: the warning, then it strides out of the rock at the back of its arena and roars.
   * **Armour**: every hit does a fifth, anywhere on it, until its four cores are lit. Lit, a hit
     on a core does double (a revolver's 34 does 6.8 on rock and 68 on a lit core). A flare lights
     them for as long as it burns within 40 studs, a Flare Ping for 10 seconds, and its own charge
     for 2.5 seconds each time it throws its shards, so a team with no flare still has an opening.
   * **Slam**: 45 within 10 studs of where its club lands, at whoever is within 16 studs of its
     front, every 4.5 seconds (4, then 3.2).
   * **Shards**: every 11 seconds (9, then 7) it plants itself and throws 2 (3, then 4). Each
     shows a closing ring for 1.2 seconds, then does 15 and stuns for 1.5 seconds within 6 studs
     (residents are slowed). From its second phase 2 (then 4) Shardlings crawl out of the broken
     shards, never more than 8 of them alive at once.
   * **Stagger**: 4% of its health dealt to lit cores within 4 seconds drops it for 3.5.
   It walks its arena at 3 studs a second (3.5, then 4.5) and turns 35 degrees a second: slower at
   its fastest than the Brood Mother at her slowest.

**Things the bible doesn't say, decided here and open to change (see Bible Questions)**: which
lights show a Stalker; which guns are small; the hum's numbers; that a hazard pocket in the Crystal
Hollows is radiation; where outbreaks come from until wanderers exist; how quarantine works; the
Colossus lighting its own cores; the cap on its Shardlings; the caves' radiation; every number.

**Two bugs found and fixed that weren't this prompt's**
* **A wide monster could not get through a doorway.** The walking line through a doorway was 2
  studs in front of its middle, and the opening is 7 studs clear. A root 4 studs wide (the Geode
  Golem, and Prompt 23's Tide Crab) caught the jamb and walked into it for good. The line is at
  0.5 now. Tracked in play: a Golem and a Tide Crab both went from the Medbay into the Reactor
  Core; residents still walk to work through the same doorways.
* **A dev command registered twice stopped six services.** My first build named a command `rad`,
  which SurfaceService already had; DevService refused it and SurfaceService's Init failed, and
  with it everything that depends on it. The installer's StructureCheck doesn't run Init, so it
  passed. `tools/game_sync.py build` now fails on a command name registered in two files.

**Suggestions (not built)**
* A Geiger tick and a counter on the HUD in a leak (Prompt 32 has the sound).
* The Colossus could break crystal out of the walls of its arena as it passes: cover from its
  shards, and something for the Driller to do.
* A sick resident could be told from across a room by more than the cough: a mask on the model
  would read at phone size.
* The stun followed by the slam does 75 in two seconds to one player standing in front of it
  (Bible Question 10).

## Delivery Report

**Overview.** Two disasters, two resident conditions, four monster behaviours, one boss fight, the
band's caves and crew, their art, and the class effects that were waiting for them. The rules are
pure (`Rules.Disasters`, `Rules.Threat`, `Rules.Residents`, `Rules.Deep`, `Rules.Boss`) and
data-tested; the numbers are `Tuning.Disasters.Radiation`, `.Outbreak`, `Tuning.MonsterAI`,
`Tuning.CrystalColossus` and `Tuning.Deep`, all provisional.

**Files created**
* Art: `generators/Monsters/Monster_Shardling.py`, `Monster_PrismStalker.py`,
  `Monster_GeodeGolem.py`, `Monster_Resonator.py`, `generators/Bosses/Boss_CrystalColossus.py`,
  `generators/Kits/Kit_Radiation.py` (the door's clamp and the seam),
  `generators/Caves/Cave_Crystal_*.py` (eight). `_beast.py` gained `shard`, `cluster` and
  `Beast.neon`; `cavelib.py` the Crystal band, `crystal_at`, `crystal_cluster`, `crystal_seam`,
  `rad_sign` and `hot_rock`; `cavedress.py` the band's dressing.
* `game/reports/P24_CrystalHollows.md` (this).

**Files modified**
* `Rules/Disasters.luau`: `RadiationStep`, `RadiationSeconds`, `RadiationPlayerRate`,
  `RadiationResidentDamage`, `DoorLeakChance`, `CarriesSickness`, `OutbreakTargets`,
  `CureSeconds`; `HazardKind` gives `RadiationLeak` for a band with neither gas nor water.
* `Rules/Threat.luau`: `Lit`, `StalkerSeen`, `SmallGunMultiplier`, `HumHeal`, `ShatterDamage`.
  `Rules/Residents.luau`: `Sick` and `Irradiated`, `ConditionHealth`, `Quarantined`, a sick
  worker's output. `Rules/Deep.luau`: `CaveRadiation`.
* `Config/Tuning.luau`: `Disasters.Radiation`, `.Outbreak`; `MonsterAI`'s shatter, reveal, small
  gun and hum numbers; `CrystalColossus`; `Deep.CaveRadiationPerSecond` and the Crystal crew's
  floors. `Config/Items.luau`: the `Small` flag. `Config/Monsters.luau`: the Resonator hums every
  4 s. `Config/Animations.luau`: 19 clips, five rigs, the `Volley` activity.
  `Config/CavePieces.luau` (generated): 24 pieces. `Config/RadioLogs.luau`: the Crystal crew's
  log. `RunState`: `RadiationLeaks`, `Sick`.
* `Lib/Hazards.luau`: radiation, `Unsafe`'s fourth argument. `Lib/PathGraph.luau`: the doorway's
  line. `Lib/ClassAbilities.luau`: Decon Field, Triage Pulse, Flare Ping.
* `DisasterService`: `StartRadiationLeak`, `SealLeak`, `ClearRadiation`, `Irradiated`,
  `StartOutbreak`, `Cure`, `FromTheDeep`; the storm at the door on every Surge; the clamp and the
  seam with their prompts. Dev: `leak`, `leak.storm`, `leak.seal`, `leak.clear`, `outbreak`,
  `outbreak.cure`, `outbreak.deep`.
* `MonsterService`: the four behaviours, `Lit(position)`. `WeaponService`: flares are reveal
  lights, hit modifiers are told the gun, a stunned player can't use their hands; dev `flare`.
* `BossService`: the Colossus (the header says how). Dev: `boss.start CrystalColossus`,
  `boss.volley`, `boss.light`.
* `ResidentService` (conditions, their cost each cycle, the Decon Room's cure; the dev listing
  says SICK and IRRADIATED), `ResidentBrain` (leaving radiation, quarantine), `RescueService` and
  `ExpeditionService` (who comes up from the Deep), `SurfaceService` (radiation from a leak and
  from a cave), `DeepService` (reveal lights on cave lanterns, the caves' radiation).
* Client: `DisasterController` (motes, haze and light per irradiated cell, the leak's glow at the
  fitting, the picture's tint, coughs on the sick; in the Command View a room in a leak says
  RADIATION and its strength, its note says what to do, and the room to seal blinks),
  `ThreatController` (the shatter, the ricochet, the hum's ring, a hidden Stalker's glints, the
  stun), `BossController` (LIT or ARMOURED on its bar, the shard's closing ring),
  `ResidentsController` (Sick, quarantined and Irradiated on the card).
* `DataTests`: 5 new tests (radiation; outbreaks; the four monsters; the Colossus; the caves'
  radiation and crew), and the hazard pocket, crew and Brood Mother tests extended.
* `tools/game_sync.py`: the dev command check. `tools/cave_config.py`: the Crystal band.

**Architecture.** `RescueService` and `ExpeditionService` now depend on `DisasterService`, and
`MonsterService` on `WeaponService` (no cycles). DeepService tells SurfaceService who stands in a
hot cave through a player attribute (`CaveRadiation`), as DisasterService does with `InRadiation`.

**Integration notes**
* A place needs the art in `ServerStorage.Assets` (`Monsters`, `Bosses`, `Kit`, `Caves`). Without
  `Kit_DoorSeal` or `Kit_CrystalSeam` the fitting is a plain block; without the Crystal cave
  pieces the band has no caves and no Lost Crew.
* Studio's importer drops geometry with no area. A spike that ends in a point, or a fin whose two
  edges end on the same point, comes in smaller than its sidecar says and fails the setup's size
  check (the Prism Stalker's blades did). `_beast.shard` ends in a small flat tip for that reason.
* The Colossus's club is cocked beside its shoulder in its Attack clip so it stays under a
  16-stud ceiling.

**Changing it**
* Any number: `Config/Tuning.luau`. A monster's line of stats: `Config/Monsters.luau`. Which guns
  are small: `Small = true` in `Config/Items.luau`. What shows a Stalker: tag a part
  `RevealLight` and give it a `Radius`.
* A cave piece: its generator, `SF_EXPORT=1`, PATCH the model, then `python3 tools/cave_config.py`.

**Testing checklist** (Run playtests on 2026-11-11, builds p24-570f2eb to p24-968bd49)
* [x] Boots clean: 34 services, 23 controllers, 3 Lost Crews hidden (the Crystal crew behind
  7,-1), no script errors from the game's code.
* [x] A Shardling's death set off its shards: a player 5.1 studs away went from 12 health to 6.
* [x] A Prism Stalker: all 35 of its parts hidden on the client and its six glints faint; a flare
  showed every part; it showed itself as it struck.
* [x] A Geode Golem, real gunfire: three Pocket Pistol shots took 7.2 (2.4 each), two Service
  Revolver shots took 68 (34 each).
* [x] A Resonator healed a hurt Shardling 3.2 (8% of 40) every 4.1 to 4.2 seconds and kept it
  hasted.
* [x] A door leak: 15 rising 2.5 a second over floor 1's four units; a player in it gained about
  2 radiation a second at strength 65; the clamp on the jamb, its prompt shown, sealed by holding
  E; then it faded.
* [x] A Decon Room halved the fill (1.25 a second, measured over 8 s).
* [x] A seam's leak in the Kitchen: both cooks left, lost health, were IRRADIATED, and were clear
  after the next cycle with a Decon Room built.
* [x] Seams placed in five rooms: each took a spot the search called clear; I looked at two (the
  Medbay's between the cabinet and the bed, the Kitchen's above the shelves; captures).
* [x] The Command View: rooms in a leak say RADIATION and its strength under a red lamp, and the
  Medbay's panel says what to do about its seam (capture).
* [x] The storm at the door: Year 75's Surge rolled a leak ("a storm leaks 60% of the time in
  era 3").
* [x] An outbreak: one sick resident; it spread to the other worker in the room at the second
  roll; taken off the job, the sick resident walked to a Quarters bed and stayed; a staffed Medbay
  cured them in 45 seconds and the outbreak ended.
* [x] A Crystal Hollows cave at 7,1: six pieces (Entry, Chamber, two Tunnels, Drop, Cavern), its
  guards (Shardlings) and finds; a player inside gained 1.0 radiation in 5 s; none back in the
  bunker.
* [x] The Colossus by its own Surge: Year 74's cycle ended, the next Surge was "Boss
  (CrystalColossus)" with no timer, and the fight began on floor 7.
* [x] The Colossus: walked 14 studs in 5 s to reach a player; a slam did 45; a volley's two shards
  did 30 and stunned for 1.5 s; unlit, a revolver shot did 6.8; lit, a shot at its chest core did
  68; 900 to its cores staggered it; at two thirds health it roared, threw 3 shards and hatched 2
  Shardlings a volley; a flare lit its cores (capture).
* [x] The stun on the client: walk speed 0 while it lasts, 16 after.
* [x] Beaten: it died where it was, the Surge ended, the next cycle began at 2 years a cycle.
* [x] Clips: Idle, Walk and Attack read on the Animator for the Shardling, Prism Stalker and Geode
  Golem; Idle and Attack for the Resonator; all seven of the Colossus's on the server.
* [x] A Geode Golem and a Tide Crab walked through a doorway (they couldn't before).
* [x] 131 data tests pass in both places.
* [ ] Not tested: two or more players; a phone; the Scout's Flare Ping in play; Decon Field on a
  leak; a level 3 Triage Pulse and the Hazmat Tech's faster cure; a carrier coming up from the
  Deep by its 10% roll (the dev command calls the same function), and a Deep expedition's; a
  hazard pocket dug on floors 7 to 9 (data-tested); a door upgrade ending a leak (the leak was
  gone after the door went to level 2 in the Year 75 run, but I didn't watch it happen); freeing
  the Crystal crew; the cap of 8 Shardlings over a long fight (data-tested; the uncapped fight
  reached 12 in 40 s); the Resonator's Walk clip (it stood by its pack); the Junction, Pocket and
  Crew Pocket pieces (set up and measured, not walked; the Tunnel, Drop and Cavern were placed in
  a cave I didn't walk to the end of).

**Technical risks**
* The stun is the client's (walk speed 0 for 1.5 s); the server only refuses a stunned player's
  hands. A cheat could walk through it, to their own gain only.
* A radiation leak's green is strong at full strength. I took a third off the room's light and
  the picture's tint after the first capture; `previews/Game/P24_DoorLeak.jpg` is the result at
  88.
* The seam's spot is found by boxes, not by looking: a room whose back wall is full puts it under
  the ceiling, across whatever pipes run there.
* The Colossus's arena is the deepest tunnel. In a small bunker that can be one cell (14 studs to
  walk in, as in my first test); a Year 75 bunker has more.
* Three captures were taken with the client's ambient light raised to judge art (the Colossus lit
  in its cell, the flare shot, the four monsters); the rest are the game's own light.

## Bible Questions

(Landon answered these on 2026-11-12: `game/reports/Answers_2026-11-12.md`.)


1. **What lights show a Prism Stalker?** Built: a flare, a cave lantern, the Scout's Flare Ping,
   and it shows for 1.5 s when it strikes or is hit. A room's own lights don't. The placeable Lamp
   will count once players can carry one. Should a powered room's lights show it?
2. **Which guns are "small"?** Built: the Pocket Pistol and the Rivet SMG (the light-ammo guns),
   at a fifth of their damage, players' shots only. Turrets and armed residents aren't counted.
3. **The Resonator**: 8% of a monster's health and 35% more speed every 4 seconds within 30 studs;
   it never heals a boss. Right size?
4. **Radiation leaks only come from the storm** at each Surge from Era III (60%, 30% and 0% by the
   door's level, more for a damaged door). Should the Threat Director also be able to buy one as
   a Surge's disaster, as it buys fires and floods?
5. **A hazard pocket in the Crystal Hollows leaks radiation into one room.** Section 6 says "Gas
   or water bursts out"; the band's config has neither.
6. **Where outbreaks come from** until wanderers exist (Prompt 30): someone rescued in the Deep or
   a Deep expedition coming home, 10% of the time from Era III. Should Surges bring them too?
7. **Quarantine**: a sick resident with no job keeps to a Quarters bed; one with a job keeps
   working at 70% and can infect the room, so the player's move is to take them off the job.
   Should the sick stop work on their own, or should there be a Quarantine button?
8. **The Medbay treats one patient at a time, 45 seconds each**, whether or not the patient is in
   the room. Should the patient have to walk there?
9. **The Colossus lights its own cores for 2.5 seconds as it throws**, so a team with no flare can
   still hurt it. Keep, or flares only?
10. **Its stun and its slam together** do 75 to one player in two seconds. Too much for a solo
    player? And its Shardlings are capped at 8 alive (my number).
11. **Radiation in the Crystal Hollows' caves** is 0.2 a second everywhere inside. Should it be
    only near the glowing rock, or stronger deeper in?
12. **The Crystal crew hides on floors 7 to 9**, like the other two on their bands' floors, and has
    a radio log of its own (draft text in `Config/RadioLogs.luau`).
13. **The numbers** (leak 15 rising 2.5 a second, 3 radiation a second to a player at 100,
    Irradiated from 40, seal 4 s; spread 25% every 20 s; shards 6 within 7 studs): any you want
    changed before a real team tries them?
