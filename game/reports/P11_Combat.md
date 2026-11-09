# Prompt 11: Combat core

Players fight (bible Section 9, with Section 23's networking): guns with magazines and carried
ammo, server-checked shots, melee combos and heavy swings, dodging, sprinting and stamina,
going down, being revived, dying and respawning. Built and tested on 2026-11-08. The final
install is `p11-2e6632c` (code asset 95026446991297 revision 35), in Run and Lobby. Combat lives
in the Run place.

## Design Notes

**Decisions**
1. **One place for everyone who can be hurt** (Section 23: one loop for every combatant).
   `CombatService` registers players, residents' bodies and (from Prompt 12) monsters, each
   with a team, health, a reach and a second of position history at 20 Hz.
   * No friendly fire (Section 9): Survivors never hurt Survivors, so shots pass through
     teammates and residents.
   * Residents' health stays with ResidentService (Prompt 10); CombatService only routes it.
2. **The client fires, the server checks** (Section 23).
   * The client draws the shot at once (tracer, sparks, hit marker) and sends what it hit.
   * The server checks each claimed hit: the shot number must be the next one, the gun held,
     loaded and past its fire interval, the origin near the player. Each pellet's direction
     comes from the shot's seed (`Rules.Combat.Spread`), so a client can't choose its spread.
   * Each hit must lie on its pellet's ray, within range, in the server's own line of sight and
     near where the target was over the last 250 ms (Section 23's number).
   * The server answers with `HitConfirmed`: the damage number and the kill marker.
3. **Loadouts** follow Section 9's shape: two guns, one melee weapon, one tool, two
   throwables.
   * The hotbar holds the guns (slots 1 and 2), the tool (3) and the throwables (4 and 5).
   * The melee weapon has its own button (F, the right bumper, the Melee button), so a gun
     never has to be put away to swing.
   * Each player carries their class kit (the Survivor's is the Wrench and the Pocket Pistol)
     until the Lobby sends a loadout (Prompt 21). Kit items are Standard rarity.
   * A kit with no melee weapon punches (8 damage light, 14 heavy).
4. **Ammo.**
   * Each gun has its own magazine.
   * Each player carries spare ammo: 60 at their first spawn in a run, at most 150.
   * A reload moves whole shots from carried ammo into the magazine over the gun's
     ReloadSeconds; changing slots cancels it.
   * At a Workshop or an Armory, holding Interact for 1.5 s fills carried ammo from the team's
     Ammo stockpile (Section 9: players restock at the Armory or Workshop).
5. **Melee.**
   * Light swings chain into a three-hit combo (forehand, backhand, overhead chop) when each
     comes within 0.6 s of the last.
   * Holding Melee past 0.35 s charges a heavy swing: 20 stamina, 1.6 × as long, the weapon's
     HeavyDamage.
   * The hit lands at the end of the wind-up (40% of the swing). It is checked then: 6 studs of
     reach and a 110° arc in front, as Monster Lab's rule says.
   * Knockback and stun go on the monster (`StunnedUntil`) for Prompt 12's AI.
6. **Dodge**: a roll the way the player moves (backward when standing still): 14 studs in
   0.45 s, 0.35 s of invulnerability, 20 stamina, a 0.6 s cooldown.
7. **Sprint and stamina**: 1.45 × walking speed. It drains 12 stamina a second while moving and
   comes back at 18 a second after 0.8 s without spending.
   * Hold Shift on a keyboard. On a controller the left stick click toggles it, and on touch the
     Sprint button does.
   * No sprinting while aiming or downed.
8. **Going down** (Section 9).
   * At 0 health a player is downed for 20 s. They crawl at 3 studs a second and can't jump.
   * Teammates see a revive prompt: hold Interact for 3 s. The revived player gets up with 30% of
     their health.
   * Not revived in time, the player is out. 15 s later they come back at the nearest working
     Medbay (not wrecked, not dark), or in the Blast Door hall when no Medbay works.
   * Health never regrows by itself: it comes back only by healing (Medkits, the Medbay).
9. **Aim assist** (Section 9) works on a gamepad and touch only. While aiming or firing, the
   camera is pulled softly toward the monster nearest the aim, within 6°.
10. **The UI** is themed, never stock Roblox (Section 18):
    * the hotbar's slots show item icons and "loaded/carried" rounds;
    * the stamina gauge on the HUD;
    * a hit marker and a kill marker on the reticle;
    * damage numbers and monster health bars;
    * the downed and out telegrams with their countdowns;
    * every interaction prompt drawn as a cream enamel plate with the key's chip and a hold
      gauge (`PromptController`). E shows on a keyboard and X on a controller; on touch the
      plate itself is the button.
11. **Clips** (A2's first part, made for this prompt):
    * holding a gun at the hip, aiming with both hands, reloading;
    * three combo swings, the heavy swing and its wind-up;
    * the roll, lying downed, kneeling to revive.
    * They play from `Config.Animations`. Without a clip the game still works.
12. **Weapons** (A2's first part): the Pocket Pistol and the Wrench, with hotbar icons. They are
    held from the hand's grip at their Grip socket; the Muzzle and Tip sockets become
    attachments on the held copy.

**Landon's note: "you keep messing up the gun handles"**
* The Pocket Pistol's first grip leaned the wrong way: the butt pointed forward and its heel
  stuck out like a foot. The Service Revolver had the same fault at the style test (fixed then
  as its v2).
* The pistol is now v2 (asset 132352458683098, revision 2). The grip is drawn as a side profile
  raked back about 16°, like a real pistol's: a gunmetal strap, rubber panels, a brass medallion
  and a flush magazine base.
* Checked three ways:
  1. a side view in Blender;
  2. a side view in Studio with the hand see-through, held in a Run playtest;
  3. aiming in the same playtest.
  In the playtest the gun stands upright, the barrel points forward and the grip sits in the
  palm. The revolver and the Wrench were checked the same way in the playtest.
* `previews/Game/P11_Handles_sheet.jpg` shows all of it.

**Design Risks**
* Carried ammo of 60 is six reloads of the Pocket Pistol. Ammo pressure depends on how much
  Ammo the Workshop makes (Prompt 9): tune with real Surges in Prompt 12.
* No natural regeneration makes Medkits and the Medbay matter, but a solo player with no Medkits
  can only heal at the Medbay. Watch first runs.
* The dodge's 0.35 s of invulnerability is generous next to its 20 stamina. Tune it against
  Prompt 12's monsters.

**Scope Risks**
* Only two of the 30-odd weapons, tools and throwables have models. The others work in code
  (their numbers are in `Config.Items`) and show a fallback icon. A2 brings their models and
  icons.
* Flame guns (a burning cone) and launchers (rounds that fly and burst) are coded, but they have
  no model, effects or test yet.
* Throwables, tools and Medkits have slots but no use yet: tools come with Prompt 13, and
  throwables and Medkits need a Bible answer (question 3).

**Bible Questions**
1. **Ammo**: each player carries spare ammo (60 at the start, at most 150) and restocks from the
   team's Ammo at a Workshop or an Armory. Is a per-player carry right, or should every shot
   come straight from the team stockpile?
2. **The hotbar**: guns on 1 and 2, the tool on 3, throwables on 4 and 5, the melee weapon on its
   own button (F, the right bumper). Is that the layout you want?
3. **Medkits and throwables**: how does a player use a Medkit (60 health) or throw a grenade? My
   proposal: a Heal button (H, D-pad up, a touch button) uses one Medkit over 1.5 s; a throwable
   is thrown with Fire while its slot is held.
4. **Healing**: health never regrows by itself, and a revive brings a player back at 30%. Right?
5. **Unarmed**: kits with no melee weapon (the Engineer's, the Medic's) punch for 8, or 14 held.
   Keep the punch, or give every kit a melee weapon?
6. **The numbers I picked** (all provisional): heavy swing on a held Melee button; a 14-stud roll
   with 0.35 s of invulnerability; sprint 1.45× at 12 stamina a second; crawling at 3 studs a
   second; respawning at the nearest Medbay that isn't wrecked or dark.

**Recommended Improvements**
* A2: the rest of the class kits' weapons, tools and throwables, with icons; flame and launcher
  effects.
* A carry pose for a melee weapon held at rest. Today that only happens when the hotbar is empty,
  and then the Wrench hangs head-down with its jaw in the floor.
* Shot sounds, muzzle flashes and impact sounds, with the audio pass.
* The roll leaves the floor for about 0.2 s mid-roll (Roblox's fall clip flickers). Keep the
  Humanoid in its running state during a roll.

**Technical Risks**
* Hits are checked against 250 ms of history with 2.5 studs of tolerance. Players on high ping
  may see hits refused; tune `LagSeconds` and `HitTolerance` with real players.
* A player's Humanoid never reaches 0 health: `CombatService:Damage` leaves it at 1 and downs the
  player, because at 0 the server kills a Humanoid whatever the client does. Any future damage
  must go through `Damage`, never set `Health` directly.
* CombatService records 20 positions a second for every combatant. With 40 residents, six
  players and a Surge of monsters, check the server's frame time in Prompt 12's load test.

## Delivery Report

**Overview.**
* Players shoot, reload, swing, combo, charge heavy swings, dodge and sprint.
* Every hit is checked by the server, and every number comes from `Tuning.Combat`,
  `Tuning.Player` and `Config.Items`.
* Downed players crawl and can be revived. The dead respawn at a working Medbay.
* Ammo restocks at the Workshop or Armory.
* A dev dummy (the Hollow Miner) stands in for monsters until Prompt 12.

**Files created**
* `game/shared/Rules/Combat.luau`: the pure rules: guns and melee weapons by rarity, damage,
  fire intervals, pellets, seeded spread, reloads, hit checks against history, cones and arcs,
  aim assist, combos, swing timing, stamina, the nearest respawn point.
* `game/places/Run/server/Services/CombatService.luau`: combatants and their history, damage
  and healing, down, revive, death and respawn, the revive prompt, monsters dissolving, the dev
  dummy; `/dev combat`, `hurt`, `heal`, `down`, `revive`, `kill`, `dummy`, `dummy.attack`,
  `dummy.clear`.
* `game/places/Run/server/Services/WeaponService.luau`: loadouts from the class kit, the hotbar,
  held models, shots and their checks, flame cones and launcher rounds, reloads, melee swings,
  dodges, sprint and stamina, restock points; `/dev loadout`, `class`, `give`, `ammo`, `stamina`.
* `game/places/Run/client/Controllers/CombatController.luau`: input for all of it, the shot's
  feedback, recoil, aim assist, the roll, sprint, the hotbar and stamina on the HUD, the downed
  and out overlays, hit markers, damage numbers and health bars, the clips.
* `game/places/Run/client/Controllers/PromptController.luau`: the themed prompts.
* `game/client/Lib/Movement.luau`: one walk speed from several reasons (aiming, sprinting,
  crawling).
* `generators/Clips/R15_PlayerCombat.py` and `animations/R15/*`: the 11 player clips.
* `generators/Weapons/Weapon_PocketPistol.py` (v2), `generators/Weapons/Weapon_Wrench.py`;
  `ui/atlas_items.png` and their icons.
* `studio/ui/HUD_Combat.lua`, `studio/ui/Reticle_Hit.lua`, `studio/ui/patches/HUD_P11.lua`,
  `studio/ui/patches/Reticle_P11.lua`: the downed telegram, the prompt, damage number and health
  bar templates, and the reticle's hit and kill markers.
* `game/reports/P11_Combat.md`.
* `previews/Game/P11_Studio_*.jpg`, the sheet `P11_Studio_sheet.jpg` and
  `P11_Handles_sheet.jpg`.

**Files modified**
* `shared/Remotes.luau`:
  * client to server (Run only): `SelectSlot`, `FireWeapon`, `ReloadWeapon`, `MeleeSwing`,
    `Dodge`, `Sprint`, each with typed, bounded arguments;
  * server to client: `HitConfirmed`.
* `shared/Config/Tuning.luau`: the `Combat` entry.
* `shared/Config/Animations.luau`: the players' activities and their 11 clips.
* `shared/UIContract.luau`: the HUD's new paths.
* `client/Controllers/CameraController.luau`: walk speed through Lib.Movement; `Face`, `Nudge`,
  `AimRay`.
* `client/Lib/UIKit.luau`: the item icons.
* `places/Run/server/Services/ResidentBrain.luau`: the resident revive prompt uses the themed
  style.
* `server/DevTools/StructureCheck.luau`, `server/DevTools/DataTests.luau`: three combat tests (77
  in all).
* `game/BUILD.json`: prompt 11.

**Architecture**
* Rules.Combat is pure, so the client predicts with the same numbers the server checks with.
* CombatService owns health and life; WeaponService owns what players carry and do. Monsters
  (Prompt 12) only need CombatService.
* Everything the client shows comes from attributes on the Player (Life, Slot, Item1 to Item5,
  Mag1 and Mag2, CarriedAmmo, Stamina, ReloadEndsAt, SwingEndsAt) and from `HitConfirmed`.

**Integration notes**
* **Monsters (Prompt 12).**
  * `CombatService:Register(model, { Kind = "Monster", Team = "Monsters", Health = ...,
    MonsterType = ... })` makes a monster hittable.
  * `CombatService:Damage(playerId, amount, monsterId, how)` hurts players.
  * Read `StunnedUntil` for melee stuns. Dead monsters already dissolve.
* **Classes (Prompt 20).** Class health, the Medic's 1 s revive and the Engineer's turret plug
  into `Tuning.Player` and CombatService.
* **Loadouts (Prompt 21).** The Lobby's loadout replaces the class kit in WeaponService.
* **Residents.** Armed residents are already Survivors in CombatService; fighting and fleeing are
  new ResidentBrain states.

**Testing checklist (done in Studio, 2026-11-08)**
- [x] Installed `p11-2e6632c` in both places: StructureCheck 0 errors (Run 357 checks, Lobby
  230), 77 data tests passed. The combat tests cover damage by rarity, spread, reloads, hit
  checks, cones, arcs, combos, stamina and respawn points.
- [x] The Lobby starts cleanly with the new code: 11 controllers, the camera on.
- [x] Run playtests with real clicks and keys:
  * three shots at the dummy: a hit marker each time, 12 damage each (320 → 284), the
    magazine 10 → 7, a health bar on the dummy;
  * reload with R: the magazine filled from carried ammo (1 → 10 loaded, 60 → 51 carried);
  * F three times: the combo's three swings for 14 each; F held: the charge, then a heavy swing
    for 26;
  * Ctrl: a 15-stud roll on a flat floor (14 pushed, then a slide), 20 stamina, invulnerable;
  * Shift and W: 23.2 studs a second (16 × 1.45), stamina 100 → 85.6, then back to 100;
  * the right mouse button: the two-handed aim clip and the zoom to 50°;
  * restock, holding the controller's X at a restock point: 60 → 150 carried, the team's Ammo
    200 → 110.
- [x] Every one of the 11 clips was seen playing from real input: the gun hold, aim, reload,
  three swings, charge and heavy swing, roll, downed, and the revive kneel (holding E on a
  downed resident: Ida Garza got up with 22 of 88 health).
- [x] Going down: the downed telegram and countdown, crawling, still at 1 health. Out: the
  respawn countdown, then the Blast Door hall with the Medbay dark, and the Medbay when it was
  powered. A dev revive brought the player back at 30/100.
- [x] The guns in the hand from the side (the hand see-through): the Pocket Pistol v2 and the
  Service Revolver upright, barrels forward, grips raked back in the palm.
- [ ] Two real players (a teammate's revive), aim assist on a real controller, the touch
  buttons, flame and launcher guns (no models yet).

**Future extension notes**
* New weapons are data: an entry in `Config.Items` with `Gun` or `Melee` numbers and a model with
  Grip and Muzzle (or Tip) sockets.
* Throwables and Medkits need only their use: the slots, icons and counts are there.
