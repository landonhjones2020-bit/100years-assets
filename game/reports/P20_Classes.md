# Prompt 20: All 18 classes plus the Survivor

Every class now plays as the bible's Section 14 describes it: its kit, its passive, its ability on
Q (LB on a controller, the Ability button on touch) and its level 2 and 3 effects. Class experience
is paid with a run's results and raises the class to level 2 at about 3 runs and level 3 at about
10. The rest of the class kits' art (A2) is made and in the game: 27 models, 6 player clips for
two-handed weapons and throws, and 26 icons. Built and tested on 2026-11-09 and 2026-11-10. The
final build is `p20-92251ef` (code asset 95026446991297, revision 87), installed in Run and Lobby:
StructureCheck 0 errors (Run 526 checks, Lobby 258), 113 data tests.

Two things Landon asked for during the prompt are at the end: the Fire Axe's clip sheet, and the Ash
Raider's detail pass.

## Design Notes

**Decisions**
1. **A service for who has which class, a library for what abilities do.**
   * `ClassService` (Run) owns each player's class, level, cooldowns, uses and options, the
     remotes, the bunker-wide passives, the damage filter, class experience and the dev commands.
   * `Lib.ClassAbilities` is what each ability does in the world and the devices that stay in it
     (turrets, barricades, crates, napalm, traps, the beacon, the gravity well, the drone).
   * `Shared.Rules.Classes` (pure): an ability's cooldown, uses, options and duration, and levels
     from experience. Numbers are `Config.Classes` (the bible's) and `Tuning.Classes` (new ones,
     all marked provisional).
2. **Which class a player brings** (Sections 21 and 23). The Lobby writes the run's record to
   MemoryStore before the teleport; the Run server reads it and never trusts teleport data.
   `Lib.RunRecord` is that record: one hash map, `RunRecords`, keyed by the reserved server's id,
   `{ Version, Party, Difficulty, Loadouts = { [userId] = { Class, Trial } }, CreatedAt }`.
   ClassService gives a player the record's class if their profile owns it or it is their free
   trial (a trial plays at level 1 and earns no experience); otherwise they are the Survivor.
   Prompt 21 only has to write the record. In Studio the key is "Studio" (dev `record`).
3. **The ability key.** A tap uses the selected option, aimed where the camera looks. A hold
   (0.4 s) picks the next option: the Quartermaster's two requisitions, the Mad Scientist's three
   gadgets (each on its own 40 s cooldown, as the bible's note says), the drone's three modes.
   The server checks the run is playing, the player stands and isn't carrying, and the ability is
   ready. An ability that can't do anything says why and costs nothing ("YOU'RE AT FULL HEALTH",
   "NO ROCK TO DIG THAT WAY", "NO LOOT WITHIN 30 STUDS").
4. **Cooldowns and uses** follow `Config.Classes`: seconds (scaled with the dev clock), cycles
   (the Cook's Hearty Meal, every 2 cycles), or uses that come back each Surge (Second Wind), each
   cycle (Emergency Requisition) or each era (Supply Call; two at level 2).
5. **What the HUD shows.** The class plate (name and level) and the ability gauge: the seconds or
   cycles left over a shade, uses or Steady Shot's shots in a chip, the selected option's name, and
   a ring while an effect is in play (Hold the Line, a drone mode). The Teleport Beacon has its
   own chip with its key while it stands.
6. **Passives and levels apply where they act.** Every system reads a class effect through
   `Modifiers.PlayerValue`, so a level's value replaces the passive's (the Quartermaster's level 3
   build cost of -20% replaces -10%). Bunker-wide effects (stockpile caps, build cost and speed,
   resident experience, a room type's output, all output, food use, fire spread, Blast Door
   health) use the strongest holder's value: two Quartermasters don't stack. They follow whoever
   is in the run as classes change and players leave.
7. **The abilities** (the bible's numbers; the rest in `Tuning.Classes`):

   | Class | Ability | Built as |
   |---|---|---|
   | Survivor | Second Wind | Heals 25% of max health, once a Surge |
   | Engineer | Deploy Turret | A turret in front of you for 45 s (90 s at level 3, and every 4th shot shocks). Barricades: every room vent has a prompt only Engineers see |
   | Medic | Triage Pulse | 40 health to players, residents and rescued survivors within 24 studs; level 3 also clears radiation and goo slow. Touch heal: residents within 6 studs heal 4 a second |
   | Firefighter | Foam Burst | The fire in your room (else the nearest within 40 studs) goes out at once |
   | Cook | Hearty Meal | Team max health and stamina +20% for a cycle, residents +15 morale; level 2 heals everyone |
   | Security | Hold the Line | Monsters within 40 studs come for you and you take half damage, 8 s |
   | Scout | Flare Ping | Enemies (red), loot (amber) and survivors (green) within 60 studs outlined for the team, 10 s |
   | Quartermaster | Emergency Requisition | +100 Scrap, or +10 Food and Water, once a cycle |
   | Radio Operator | Supply Call | A crate lands in front of you; opened, its loot goes to the stockpile (in the bunker) or your pack |
   | Hazmat Tech | Decon Field | Radiation off everyone in your room (within 22 studs away from rooms) |
   | Exterminator | Napalm Line | A burning strip 24 by 6 studs ahead of you for 6 s |
   | Marksman | Steady Shot | The next 3 shots pierce and crit (x2) |
   | Driller | Overdrive | 3 rock cells in a line the way you look (left, right or down), each adding its Disturbance, not past the dig limit |
   | Scavenger | Magnet Sweep | Containers, cave caches and dropped packs within 30 studs are searched and picked up at once |
   | Warden | Rally Call | Armed residents within 2 floors come and fight beside you, +30% damage, 15 s |
   | Demolitionist | Breaching Charge | A blast where you aim (within 40 studs); a rock cell there is cleared |
   | Spelunker | Grapple Line | Zip to where you aim (within 60 studs), or pull the teammate you aim at |
   | Mad Scientist | Gadget Belt | Shock Trap (stuns what steps in), Teleport Beacon (45 s; the team teleports to it) or Gravity Well (holds and pulls monsters for 4 s) |
   | Tinkerer | Drone Mode | The drone always follows, shoots and picks up dropped packs; Guard (half damage to you), Assault (double damage) or Repair (it fixes the nearest damaged room), 12 s |

8. **Burning** (the Exterminator, flame guns, napalm): a burning monster takes 6 a second for 3 s.
   The Exterminator's fire spreads to monsters within 7 studs, and never to rooms. A monster burns
   once per fire (two side by side passed it back and forth for good in a playtest).
9. **Bosses.** A crit (Marksman 3) or a blast (Demolitionist 3) staggers a boss, at most once every
   few seconds. The hit's own kind rides along with it, so a crit on the Brood Mother's belly (which
   the boss calls a weak-point hit) still staggers her.
10. **Class experience** (Section 14: "about 3 runs for level 2 and 10 for level 3"). A run pays 1
    experience for each year it reached, with the Glowshards. A level is that many runs of 50
    years: level 2 at 150, level 3 at 500. A new level applies at once. Only owned classes keep
    experience.
11. **The Warden.** A tied vote or draft goes the way the Warden voted. A level 2 Warden picks the
    stat residents raise when they level, on the Residents screen.
12. **Two-handed weapons** (A2). Classic R15 arms are short (about 1.9 studs from shoulder to palm),
    so every long gun's support point sits 1 stud ahead of its grip and one pair of clips fits them
    all: both arms are solved onto the weapon. `Config.Items` gained `Hold`: TwoHanded (Pump
    Shotgun, Lever Rifle, Rivet SMG, Grenade Launcher, Arc Rifle), Hip (the Flamethrower) and Heavy
    (Fire Axe, Sledgehammer: their own two swings). Throwables have a throw clip.

**Design Risks**
* Flare Ping spends its 40 s cooldown even when nothing is in range ("NOTHING WITHIN 60 STUDS").
  Bible Question 14.
* Hold the Line pulls every monster within 40 studs for 8 s; in a big Surge that is a lot of
  monsters on one player taking half damage. Playtests with a team will say if 8 s is right.
* Overdrive and the Breaching Charge add Disturbance as the bible says; a careless Driller can set
  off a Tremor.

**Scope Risks**
* Effects that wait for later systems stay data and do nothing yet: the Hazmat Tech's gas immunity
  and Decon Field on gas, Foam Burst on floods (Prompt 23), the Scavenger's rare-gear odds and the
  Warden's armed residents (Prompt 26's gear), the Quartermaster's trader prices (Prompt 30), the
  Hazmat Tech's outbreak cures, the Medic's condition clearing on residents (Prompt 26).
* Talents are Prompt 27. Class outfits on the player are optional cosmetics (Section 19); the
  remaining 15 class looks are made with Prompt 21's Class Shop.

**Bible Questions**
1. **Armed residents.** Rally Call needs armed residents, and residents get weapons with Prompt
   26's gear. Until then nobody answers a rally in a real run (dev `resident.arm` arms them for
   tests). Right to wait, or should founders start with a weapon?
2. **The Security's level 3** ("Armed residents answer your rally at once"). The bible's rally is
   the Rally ping, which isn't built as a resident order yet. Built: the modifier is data and does
   nothing until the ping orders residents. Which prompt should that be?
3. **Barricades.** Built: a prompt at every room vent that only Engineers see; it costs the
   Barricade recipe from the stockpile (half at level 2), takes the recipe's seconds, and a
   barricaded vent opens less often. Right?
4. **Drone Mode's length.** The bible gives no time; built at 12 s with a 20 s cooldown. Right?
5. **Class experience.** Built: 1 experience per year reached, level 2 at 150 and level 3 at 500
   (3 and 10 runs of 50 years). A run lost in Year 10 pays 10. Right?
6. **Hearty Meal at level 2** ("Meals also heal"). Built: everyone is healed to full. Or a part?
7. **Supply Call.** Built: the crate lands 5 studs in front of the Radio Operator, anywhere (the
   bunker, the surface, a cave). Right, or only up top?
8. **The Teleport Beacon's key.** Built: T on a keyboard, a hold of D-pad down on a controller, a
   tap on its chip on touch. Right?
9. **The turret's shock** (Engineer 3). Built: every 4th shot stuns for 0.6 s (every shot held a
   monster still for good). Right?
10. **The Flamethrower** is held at the hip, the other long guns at the shoulder. Right?
11. **The ability gauge's icon.** Built: the class's signature item icon (the turret, the paddles,
    the flare...) until each ability has its own art. Should abilities get their own icons (19)?
12. **A trial's level.** Built: a free-trial class plays at level 1 and earns no experience.
13. **Two Quartermasters.** Built: bunker-wide class effects don't stack; the strongest counts.
14. **Flare Ping with nothing in range.** Built: it still spends the cooldown. Should it cost
    nothing, like the other abilities that find nothing to do?
15. **The Ash Raiders' lantern and red.** The detail pass gave raiders a storm lantern on the pack
    (an orange light from behind, like their lenses from the front) and a red hood and pennant as
    their colour. They are art, not rules, but a lit lantern makes raiders easier to see at night.
    Keep both?

**Recommended Improvements**
* Each ability its own icon and a short sound.
* The turret, the drone and the crate could arrive with a small effect (a parachute, a spark).
* A "class level up" card on the results screen when a run's experience reaches a new level.
* Raiders could carry what their kind drops (the Raider loot table) visibly on the belt.

**Technical Risks**
* The run record's key is the reserved server's id: it only exists in the published game. Studio
  uses a "Studio" key, so the real read is first seen in Prompt 21's live test.
* Two-player effects (the Medic's 1 s revive of a player, the Spelunker pulling a teammate, team
  teleports to the beacon) need a second person.
* The Grapple moves the character on the client; a laggy client could land short. It is capped by
  range and speed on the server.

## Delivery Report

**Overview.** All 19 classes: kits, passives, abilities on Q with cooldowns, uses and options,
level 2 and 3 effects, class experience and levels, the run record's reader, and the HUD. The A2
art: 27 models, 6 player clips, 26 icons.

**Files created**
* `game/places/Run/server/Services/ClassService.luau`, `game/places/Run/server/Lib/ClassAbilities.luau`
* `game/places/Run/client/Controllers/ClassController.luau`
* `game/shared/Rules/Classes.luau`, `game/server/Lib/RunRecord.luau`
* `studio/ui/HUD_Classes.lua`, `studio/ui/patches/HUD_P20.lua` (applied in Run)
* Art: `generators/Weapons/_gunkit.py` and 23 generators there, `generators/Props/Prop_Turret.py`,
  `Prop_Barricade.py`, `Prop_Lamp.py`, `Prop_CombatDrone.py`, `generators/Clips/R15_LongGuns.py`,
  `generators/Monsters/Monster_AshRaider_Melee.py`, 26 `ui/sprites/Icon_*.png`
* `game/reports/P20_Classes.md`

**Files modified**
* Homes for class effects: `CombatService` (the damage filter, max health per player),
  `WeaponService` (the kit per class, the shot hook, hit modifiers, the hit's own kind, a class
  change keeping the shot count), `MonsterService` (Taunt, stuns), `BossService` (Stun),
  `BuildService` and `Rules.Construction` (build cost and speed), `EconomyService`,
  `ResidentService` and `ResidentBrain` (rally, arming, touch heal, the level stat), `VoteService`
  and `Rules.Votes` (the tie breaker), `DisasterService`, `DigService`, `DeepService`,
  `SurfaceService`, `InventoryService`, `RescueService`, `ExpeditionService`, `DraftService`,
  `ResultsService` (class experience with the payout).
* Client: `HUDController` (the class plate, the ability gauge, item icons for abilities),
  `CombatController` (the hold clips by `Hold`, the throw), `CameraController` (the Marksman's aim
  zoom), `ResidentsController` (the Warden's stat choice), `InputController`, `NPCAnimator`.
* Shared: `Remotes` (UseAbility, PickAbilityOption, TeleportToBeacon, ChooseLevelStat, ArcZap,
  AbilityFx, Grapple), `RunState` (BuildCost, LevelStat, BeaconUntil, BeaconBy), `UIContract`,
  `Rules.Modifiers`, `Rules.Combat`, `Rules.Residents`, `Config.Tuning` (Classes), `Config.Items`
  (Hold), `Config.Animations` (6 player clips; the raiders' clips), `Config.Monsters`, `DataTests`.

**Architecture.** ClassService decides; ClassAbilities acts through each owning service's API (it
never reaches into another service's state); every passive is a modifier in `Config.Classes` read
where it applies. Abilities are rows of data plus one function each; a new class is a row, its
modifiers' handlers and, if it has an active, one function.

**Integration notes**
* Prompt 21 writes the run record: `RunRecord.Write(reservedServerId, record, seconds)` with
  `Loadouts[userId] = { Class, Trial }`. The Run server reads it when a player's session is ready.
* Prompt 26 (gear): arming a resident is `ResidentService:Arm(id, itemId)`; Rally Call and the
  Security's passive already read it.
* Prompt 23: Foam Burst on floods and Decon Field on gas need one call each in ClassAbilities.
* Prompt 27 (talents) reads and writes the same modifier keys.

**Testing checklist**

Final build `p20-92251ef`, Run playtests on 2026-11-10, with real Q presses:
* [x] Every class's ability fired from a real Q tap, with the server's answer read on the client:
      Second Wind (+25 health, 60 to 85), Deploy Turret (90 s at level 3), Triage Pulse (1 healed),
      Foam Burst (a Medbay fire out), Hearty Meal (+15 morale, +20% health and stamina, all healed,
      next in 2 cycles), Hold the Line, Flare Ping, Emergency Requisition (+100 Scrap, the use
      spent), Supply Call (a crate landed), Decon Field (radiation 50 to 0), Napalm Line, Steady
      Shot (3 shots), Overdrive (1 cell dug to floor 3, an ore pocket, "the rest is past the dig
      limit"), Magnet Sweep (three Radio Tower containers at once, a blueprint among them), Rally
      Call (6 armed residents), Breaching Charge, Grapple Line, Shock Trap, Drone Mode (Guard, 12 s).
* [x] Refusals cost nothing and say why: full health, nobody to heal, nobody to decontaminate, no
      rock that way, no loot within 30 studs; a second press shows the seconds left.
* [x] A real hold of Q picked the next gadget: Teleport Beacon (set for 45 s), then Gravity Well,
      each on its own cooldown.
* [x] Class experience and levels: 149 experience is level 1, 150 level 2, 499 level 2, 500 level
      3; the level applied at once and the profile saved it (Studio store).

Playtests on 2026-11-09 (captures in `previews/Game/P20_*.jpg`):
* [x] Steady Shot: three shots pierced three dummies in a line and each took three crits; the
      Marksman's level 2 zoom (the aim's field of view 39.5).
* [x] A crit on the Brood Mother's head and on her belly staggered her (Marksman 3); a Breaching
      Charge stunned her (Demolitionist 3).
* [x] Residents near a Security hit 25% harder (7.5 a swat against 6).
* [x] The Exterminator's fire spread between two monsters, each burning once for about 3 s; a
      Survivor's Flamethrower didn't spread.
* [x] An Engineer's barricade built with a real E hold at the Medbay vent (40 Scrap, 3 Iron); the
      level 3 turret shocked every 4th shot.
* [x] The Warden's level stat chosen on the Residents screen; the Quartermaster's option switch;
      the beacon's chip.
* [x] The A2 art in hand and as devices: the rifle hold and aim, the reload, the Fire Axe's heavy
      swing, a thrown grenade with its own mesh, the barricade, the turret and the drone, the new
      icons on the hotbar and the ability gauge.
* [ ] Not seen: anything that needs two players (the Medic's 1 s revive of a player, a pulled
      teammate, a teammate using the beacon, the Warden breaking a real tie), touch and a real
      controller, a real run's results paying class experience (the dev command pays it the same
      way), the run record read from a real reserved server (Prompt 21's live test).

The Studio profile was left with the Medic owned at level 3 from the experience test
(`class.own Medic 1 0` puts it back).

**Future extension notes.** Talents (Prompt 27) and gear (Prompt 26) use the same modifier keys.
Ability icons and sounds are named by the class id, so they can arrive with no code change.

## The A2 art (2026-11-09)

27 models made in Blender, uploaded and set up in Run (size and pivot measured, sockets written):
15 weapons (Lead Pipe, Fire Axe, Sledgehammer, Shock Baton, Defib Paddles, Antenna Whip, Hazard
Hook, Hunting Knife, Power Wrench, Pump Shotgun, Lever Rifle, Rivet SMG, Flamethrower, Grenade
Launcher, Arc Rifle), 4 throwables (Frag Grenade, Flare, Foam Grenade, Shock Mine), 2 tools (Geiger
Counter, Grapple), 2 items (Medkit, Clear-Rad Pills) and 4 devices (Lamp, Barricade, Turret, Combat
Drone). Six player clips (RifleHold, RifleAim, RifleReload, HeavySwing1, HeavySwing2, Throw) and 26
item icons packed into one atlas. Ids are in `manifest.csv` and `exports/_uploads/A2_P20.json`.

**The Fire Axe's clip sheet** (Landon, Nov 9: "in the animation with the axe the head is not
connected to the handle"). The model was always in one piece (Studio measured it at 3.39 studs);
the clip sheet had drawn the head before its move down the handle was applied. The sheet renderer
now updates the scene first; both heavy-swing sheets were rendered again.

## The Ash Raider's detail pass (2026-11-10)

Landon, on the raider with the club: "I need more detail for that character. Not up to our
standards." He was right: both raiders shared a body of about 1,500 triangles of a 4,000 budget.
* **The body** (both raiders), rebuilt at about 3,700 triangles: a black gas mask with a scowling
  steel brow, chrome-rimmed orange lenses, cheek filters and a hose to a chest canister; a red hood
  under a welded, spiked scrap helmet; a road-sign chest plate and a bandolier; half a whitewall
  tyre over one shoulder and spiked plates on the other; a split, flared coat with torn hems,
  patches and a machete through the belt; wrapped forearms, a hubcap buckler, studded knee pads,
  strapped steel-toed boots; a pack with a looted Steadfast blanket, a rope, a storm lantern and a
  torn pennant.
* **The club raider** has its own model (`Monster_AshRaider_Melee`: an eight-spiked scrap club
  wound with barbed wire) and clips. Until now the third of raiders that fight hand to hand used
  the rifle raider's model and had no clips at all (they slid).
* **The rifle** has its own joint. It is carried across the body in both hands and shouldered
  level when it fires. Fixed to the forearm, it pointed at the sky whenever the arm came up: the
  old Attack clip fired upward.
* **Idle clips** for both, and the attack now plays over the Idle (`NPCAnimator`), so a raider
  between two shots or blows keeps its stance instead of dropping to its rest pose.
* In Studio: both models set up in Run (sizes 3.21 x 6.75 x 5.84 and 3.42 x 6.75 x 4.37 studs,
  pivots at the feet, 12 and 11 joints), the three clips of each seen playing in a playtest, and
  both fighting the player. `previews/Monsters/Monster_AshRaider_review.jpg`,
  `previews/Game/P20_raiders_*.jpg`.
* Found on the way: every rig's `Category` attribute said "__RigStep" (the rig step's holding
  folder); fixed in `studio/AssetSetup.lua` and on the ten rigs in Run.
