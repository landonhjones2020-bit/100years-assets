# 100 Years Below: handoff for the next chat

Written 2026-11-12 (morning, Chicago), after Prompt 25. The game was called 100 Years Of
Fallout until 2026-11-09; the Project and its docs keep that name. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU and the two project parts) wins over everything
here. It is in step with Landon's decisions up to Nov 10 (live doc rev 174; both project parts
refreshed from it the same day). Nothing of Prompts 23, 24 and 25 is in the bible yet: their 9, 13 and
11 questions wait for Landon in the reports.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
3. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Their ids change when a Studio restarts or reconnects (the Lobby's did on Nov 10): list
   them again instead of using a remembered id. Never touch the Night Shift studio. Studio asked
   for a restart on Nov 10 (its Assistant plugin changed version): ask Landon to restart it if
   tools misbehave.
4. Work in this order unless Landon says otherwise: Prompt 26, Prompt 27, then the open work below.

## Where things stand

* **Prompts 0 to 25 are built and tested in Studio.** Code build `p25-33ee455` (code asset
  95026446991297, revision 117) is installed in both places: StructureCheck 0 errors (Lobby 356
  checks, Run 580), 132 data tests.
* **Prompt 25 (the Source).** The century has an end, two ways. The first floor 10 cell dug opens
  on the Source Chamber (one cave piece: the old mine's gallery comes out on a ledge high in a
  hall 72 by 90 by 28 studs, sunk under the gallery so floor 9's caves can lie over it). The
  Source sleeps there and wakes when a player comes within 44 studs or hurts it. Its fight
  (40,000 health, four stages): tendrils in rooms spread over the floors with its eye shut (3,
  then 5, one more a player; each cut down takes an even share of 15% of its health), then the
  core with its eye open (the weak point; slams for 50, roots bursting up under survivors with a
  ring 1.3 s before), twice. In its chamber some tendrils rise round it and the rest in the
  deepest rooms. Killed in its chamber: the Deep Victory at once, in any year. Left alone: at
  Year 100 the final Surge has no timer, it rises in the bunker's deepest tunnel (leaving its
  chamber if it still slept there), and killing it is the Century Victory. Each victory has a
  7-second moment before the report (the Blast Door lifting on daylight; the Source dying as its
  light leaves the rock), and Keep Going carries either into Endless. Report:
  `game/reports/P25_TheSource.md` (14 decisions, a "not tested" list, 11 Bible Questions);
  captures `previews/Game/P25_*.jpg`.
* **Prompt 24 (the Crystal Hollows).** Era III plays. Radiation leaks: from Era III each Surge's
  storm is rolled against the Blast Door (60%, 30%, 0% by its level, more when damaged); a clamp
  appears on the door's jamb and floor 1 fills with radiation (15 rising 2.5 a second) until a
  player seals it (hold 4 s), the door is upgraded, or 120 seconds pass; a Decon Room halves the
  fill; residents leave and the ones caught are Irradiated until a Decon Room clears them at the
  next cycle. A hazard pocket in the Crystal Hollows leaks into one room through a crystal seam.
  Outbreaks: someone rescued in the Deep or home from a Deep expedition carries a sickness 10% of
  the time; it spreads within a room (25% every 20 s), a sick resident with no job quarantines in
  a Quarters bed, a working Medbay cures one patient in 45 s. The four monsters: Shardlings (their
  shards do 6 within 7 studs when one dies), the Prism Stalker (a glint until a flare, a cave
  lantern or a Flare Ping lights it), the Geode Golem (a fifth of the damage from the Pocket
  Pistol and Rivet SMG) and the Resonator (every 4 s it heals 8% and hastes the pack). The Crystal
  Colossus (Year 75, 20,000 health): armoured everywhere (a fifth) until its four cores are lit
  by a flare, a Flare Ping, or its own charge as it throws; it slams (45), throws marked shards
  that stun for 1.5 s, and from phase 2 Shardlings crawl out of them (8 at most). The Crystal
  Hollows' eight cave pieces are in: caves on floors 7 to 9, their radiation (0.2 a second on a
  player), and the band's Lost Crew with its radio log. Report:
  `game/reports/P24_CrystalHollows.md` (7 decisions, a "not tested" list, 13 Bible Questions);
  captures `previews/Game/P24_*.jpg`.
* **Two bugs older than Prompt 24, fixed in it:** wide monsters (the Geode Golem, the Tide Crab)
  jammed in doorways (the walking line was off the doorway's middle), and a dev command
  registered twice could stop six services at start without the installer noticing (the build
  checks now).
* **Prompt 23 (the Flooded Caverns).** Era II plays. Floods: a burst pipe fills a room (rise 2.5
  a second, wading from 25, drowning damage at the top), water pours down the Shaft to the rooms
  below, a player patches the pipe and the room drains; residents leave a flooded room. Gas leaks:
  a vent fills a room, 6 damage a second, sealed at the vent or gone after 90 seconds. Hazard
  pockets found by digging now let water or gas into the room beside them. Surges pick floods and
  gas from Era II. The four monsters: Murklings (a swarm, out of flooded rooms when there are
  any), the Bloat Toad (bursts and floods the room it dies in), the Lurker (unseen in water or
  the dark, strikes and holds a resident) and the Tide Crab (a quarter damage from the front,
  double from the back; it turns slowly). The Deluge (Year 50): rises through the floor, bites,
  dives, swims under the bunker along a real path through the Shaft, bursts the pipe of every room
  it passes, surfaces beside a player with Murklings in phases 2 and 3; its crown and maw are the
  weak points when it is up, and it takes a quarter damage under the floor. Class effects that
  waited on this: Foam Burst, Decon Field, the Hazmat Tech's immunity, the draft's Sump Pumps and
  Gas Filters. Report: `game/reports/P23_FloodedCaverns.md` (8 decisions, a "not tested" list, 9
  Bible Questions); captures `previews/Game/P23_*.jpg`.
* **A bug older than Prompt 23, fixed in it:** monsters never climbed the Shaft's stairs (a plan
  made again every 2.5 seconds sent them back to the aisle). They climb now; small rigs still wait
  at the foot and are stepped up by the stuck rule.
* **Prompt 22 (the intro cutscene).** Every run opens with the 30 seconds of bible Section 4,
  played by each client from data made in Blender: the billboard and Main Street, the party's
  avatars and the six founders sprinting up Mine Hill into the blast door, the bomb, the door
  sealing, the flash, the shockwave flattening the town, the cloud, the plunge down the lift shaft
  past the run's real rooms to the Source opening its eyes, the title and "Survive. Dig. Don't wake
  it.", then a push-in to the player's own camera. First run in full; Skip from 2 s after that,
  personal, with a telegram counting down to the run. No sound yet (Prompt 32). Report:
  `game/reports/P22_IntroCutscene.md` (9 Bible Questions); captures
  `previews/Game/P22_Intro_sheet.jpg`. How to change it is in `CLAUDE.md` section 4e.
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
  detail pass, A8 (Murkling, Bloat Toad, Lurker, Tide Crab, The Deluge at 11,408 triangles with
  six clips, the burst pipe and the gas vent; ids in `exports/A8_ids.json` and `BUILD_LOG.md`;
  sheets in `previews/Monsters`, `previews/Bosses`, `previews/Kit`), A10 except the Source
  (Shardling, Prism Stalker, Geode Golem, Resonator, the Crystal Colossus at 12,736 triangles with
  seven clips, the door's clamp and the crystal seam, eight Crystal Hollows cave pieces; ids in
  `exports/A10_ids.json`; sheets in the same folders and `previews/Caves`), and A9's cutscene set (the lobby's blocks and the town's cars and trees again, plus
  seven new models in `ServerStorage.Assets.Cutscene`). Lobby place: A9's lobby half, 28 models
  (`ServerStorage.Assets.Lobby` and `.Town`).
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
2. **Prompts 26 and 27** (prep below) come first: Landon's instruction of Nov 12 (06:31) was the
   recap and handoff, then the next three prompts: 25 is done, 26 and 27 are left.
3. **Digby the Gopher** (the mascot: the lobby's greeter and Prompt 31's tips) is still unmade.

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
* Nov 11, 10:56: the same instruction again as he left for afternoon classes. Read as: finish
  Prompt 22 with its recap and handoff, then Prompts 23, 24 and on, keeping this file current.
* Nov 11, 16:02: "I have to go to my afternoon classes. IF you finish before I return I want you
  to create the recap and handoff and then begin on the next 3 prompts". Read as: Prompt 23's
  recap and handoff (done), then Prompts 24, 25 and 26, keeping this file current.
* Nov 12, 06:31: the same words again as he left for afternoon classes. Read as: Prompt 24's
  recap and handoff were done, so Prompts 25, 26 and 27, keeping this file current.
* His standing bar: beat 99 Nights in the Forest on finish; UI themed, never generic; monsters
  detailed, bosses scary; art made in Blender here and it has to actually look good.

## Next: Prompts 26 and 27

Standing rules (bible Section 24): one system per prompt, the bible wins, never invent gameplay
(suggest it in the Design Notes), content is data, a real playtest for timing, permissions and
saved data, Design Notes and a Delivery Report in `game/reports/P##_*.md`.

### Prompt 26: Residents, phase 2: traits, gear, conditions, morale extremes (Run)

* Bible: Section 11 (residents: traits, gear, conditions, morale). `Config.Traits`,
  `Config.Conditions` and `Config.Gear` rows exist from Prompt 1 (each has a `Phase`).
* Already in the code: `Sick` and `Irradiated` as fields on a resident with
  `ResidentService:SetCondition` and `HasCondition`, their cost each cycle
  (`Rules.Residents.ConditionHealth`) and the quarantine goal (Prompt 24); `Exhausted` (Prompt
  10); the Residents screen's card shows conditions. Prompt 23's question 8 (the Hardy trait and
  the gas-proof outfit against floods and gas) and Prompt 24's question 7 (quarantine) wait here.

### Prompt 27: Talents and Legends

* Bible: Section 15 and the talents section. `Config.TalentSlots`, `Config.Legends` and the
  classes' `Talentable` and `TalentExclude` fields exist from Prompt 1; the Lobby's pads already
  say "pick a class, talents and a Legend" (Section 5's flow). Read `ClassService` (how a class's
  passive reaches `Rules.Modifiers`), `PartyService` and the run record (what the lobby writes for
  a run) and the Class Shop's screen before starting.

## Waiting on Landon

* **The live test of Prompt 21** in the published game (the list is in `game/reports/P21_Lobby.md`):
  a pad to a real Run server, rejoin, Play Again, Return to Lobby, a friend on a private pad, one
  real 99 Robux reroll.
* His answers to the Bible Questions of Prompt 19 (7), Prompt 20 (15), Prompt 21 (15) and
  Prompt 22 (9: the path, the door's design, the names on the set, the bulletin's words, the
  Source's eyes, what a skipper sees, press or hold, the Run place's leftovers).
* His look at the intro (`previews/Game/P22_Intro_sheet.jpg`, or press Play in the Run place), and
  the things only the live game can show: two or more players in it, someone joining during it, a
  phone.
* A Studio restart: the Run studio kept a failed download of the title's atlas on Nov 10, so the
  title card showed its typed fallback there (BUILD_LOG, finding 3).
* His look at the lobby (`previews/Game/P21_*.jpg`, or the Lobby place itself), at the town's
  names (Prompt 21, question 11) and at the 15 new class looks
  (`previews/Residents/Class_Portraits.jpg`; questions 14 and 15).
* The AutoScale Lite pass on The Frame and HUD (Prompt 6).
* **Prompt 25**: his answers to its 11 Bible Questions (the four stages; a tendril in the Reactor
  Core; whether the chamber fight sends tendrils up into the bunker; whether it can sleep again;
  a Deep Victory during the final Surge; monsters dying with it; minions of its own; what else
  floor 10 holds; residents walking out at the Century Victory; a reward for finding the chamber;
  how strong an early Endless is), and his look at the Source, its tendril and its chamber
  (`previews/Game/P25_*.jpg`, `previews/Bosses/Boss_Source*.png`,
  `previews/Monsters/Monster_SourceTendril.png`, `previews/Caves/Cave_Source_Entry*.png`). Not
  tested by me, his to try: two or more players, a phone, a whole fight by real damage, digging
  to floor 10 by hand with its vote, an era boss's Surge starting during the chamber fight.
* **Prompt 24**: his answers to its 13 Bible Questions (what lights show a Prism Stalker; which
  guns are small; the Resonator's numbers; whether Surges may buy radiation leaks and outbreaks;
  radiation from a Crystal Hollows hazard pocket; quarantine by button or by itself; whether a
  patient must walk to the Medbay; the Colossus lighting its own cores; its stun and slam on a
  solo player; where the caves' radiation is; the Crystal crew's floors and radio log; the
  numbers), and his look at the A10 art (`previews/Game/P24_*.jpg`, `previews/Monsters/*.png`,
  `previews/Bosses/Boss_CrystalColossus*.png`, `previews/Caves/Cave_Crystal_*.png`). Not tested
  by me, his to try: two or more players, a phone, Flare Ping, Decon Field on a leak, a level 3
  Triage Pulse, freeing the Crystal crew, a long Colossus fight.
* **Prompt 23**: his answers to its 9 Bible Questions (what "air the room out" asks of players;
  water in bare tunnels; whether the Lurker holds players; Murklings only from water; whether The
  Deluge bursts pipes or leaves water, and whether that scales with the party; what it hunts; how
  fast the Tide Crab turns; residents' Hardy trait and gas-proof outfit; the flood and gas
  numbers), and his look at the A8 art (`previews/Game/P23_*.jpg`, `previews/Monsters/*.png`,
  `previews/Bosses/Boss_Deluge*.png`). Not tested by me, his to try: two or more players, a phone,
  Hazmat immunity and Gas Filters in play, a Surge picking flood or gas by itself, breaking a
  Lurker's grab, gunfire on The Deluge under the floor, patching and sealing by hand.

## Testing tips

* **The Source.** The chamber: `grid.dig 3 2` down to `grid.dig 10 2` (it digs without rolls),
  `deep.cave 10 2` (the chamber opens, the Source asleep), `deep.tp 10 2`, then walk down the ramp
  or `boss.wake`. The bunker: `year 100`, `clock.resume`, `clock.next`, wait 20 s for the siren
  and 8 for it to rise (or `boss.start Source`). In either: `boss.tendrils`, `boss.cut` (the
  stage moves on), `boss.hurt <n> [weak]`, `boss.roots`, `boss.regrow`; `run.keepgoing` after a
  victory. Client: `victory.play century|deep`. Tendrils left standing down residents: `boss.cut`
  or `boss.end` before looking at anything else.

* **Radiation, outbreaks and Era III.** `leak` (the door), `leak <room> [strength]` (a seam),
  `leak.storm` (the Surge's roll now), `leak.seal`, `leak.clear`; `outbreak [residentId]`,
  `outbreak.cure [id|all]`, `outbreak.deep <id> [force]`; `residents` says SICK and IRRADIATED;
  `flare` (a flare at your feet); `boss.start CrystalColossus` (11 s of warning before
  `boss.hurt` works), `boss.light [s]`, `boss.volley`. A real Colossus: `grid.dig` a shaft to
  floor 7 first (its arena is the deepest tunnel), `year 74`, `clock.resume`, `clock.next` three
  times to cycle 2, then twice more to the Surge. A Crystal cave: `grid.dig 3 0` to `7 0`,
  `grid.dig 7 1`, `deep.cave 7 1`, `deep.tp 7 1 [piece]`. Monsters wreck the Reactor Core in under
  a minute if left loose in a test bunker: `monsters.clear` before looking at anything else.

* **The intro.** It plays at the start of every Run playtest (the `SkipIntro` attribute on
  `ServerScriptService.DevTools` skips the phase). Client commands
  (`PlayerScripts.DevInvoke:Invoke(cmd)`): `cutscene` (state), `cutscene.at <seconds>` (holds that
  moment: wait a second, then `screen_capture`), `cutscene.play [from]`, `cutscene.stop`,
  `cutscene.skip`, `cutscene.comfort <flash> <shake>`. Server: `intro`, `intro.first <true|false>`
  (set it in the first second of a playtest to see a first run: no Skip). A dev replay is always
  skippable. A big `require` through `execute_luau` can come back "Target is not reachable"
  although it ran: look before running it twice.

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
* **Floods, gas and Era II.** `flood <room> [level] [nopipe]`, `flood.patch`, `flood.drain`,
  `gas [room]`, `gas.seal`, `gas.clear`, `pocket <floor> <column>` (a hazard pocket there),
  `disasters`. `monster <Type> [n]`, `monster.hit <Type> <amount> [front|back|side]` (turns the
  monster, then damages it as the player: the Tide Crab's 25, 100 and 200), `monsters` (also
  lists hidden, holding, lair). `boss.start [BroodMother|Deluge]`, `boss.dive`, `boss.surface`.
  A real Deluge: `year 49`, then `clock.next` to the Surge. `god` from the server needs the
  player's name and its time can't be shortened or ended (`god 0` does nothing): measure damage
  before turning it on. Unpowered rooms are dark: raise the client's `Lighting.Ambient` for an art
  capture and say so. Never move a character to a spot worked out from a monster's position
  without keeping it inside the cell: both fall out of the bunker.
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

* The Command View's condition note (what to do about a fire, a leak) is set in very small type.
* A crystal seam in a fully furnished room sits under the ceiling, across the pipe run.
* Founders idle on floor 1 at the start, so a door leak that starts strong irradiates all six at
  once (a real leak starts at 15 and they have about 10 seconds to leave).

* After SEND, the Expeditions screen switches to ACTIVE even when the server refuses the trip
  (too far from a console): it shows NOBODY OUT beside the warning.
* The distress plate's countdown shows --:-- while the clock is paused (dev only).
* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast
  Door hall.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* Small monster rigs can't walk the Shaft's ramp: they wait 2.5 seconds at its foot and the stuck
  rule steps them to the top (Prompt 23 fixed the worse half: they never climbed at all).
* The HUD's input hints flip between Gamepad and Keyboard in Studio when the mouse moves (a
  controller is plugged in on Landon's PC).
* The lobby: the Loadout a pad opens stays open if the server moves the player off the pad (dev
  only; a player closes it with Backspace before walking off).
* The lobby is about 330,000 triangles, over the bible's 150,000 for phones: measure on a phone
  (Prompt 34) before cutting anything.
