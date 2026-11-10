# Prompt 21: The Lobby

The Lobby place is now Brightwater's Main Street on a sunny morning, with the Steadfast Shelter Co.
showroom in the middle of it. Players spawn on the pavement in front of the showroom, walk in, pick
a class at the Class Shop or Loadout booth and step onto one of six elevator pads to start a run.
Built and tested on 2026-11-10. The final build is `p21-a5fb2fb` (code asset 95026446991297,
revision 90), installed in Lobby and Run: StructureCheck 0 errors (Lobby 352 checks, Run 534), 116
data tests.

What is in it:

* **The Daily Class Shop**: four classes you don't own each day (00:00 UTC), bought with
  Glowshards, one free reroll a day (two with VIP), then the 99 Robux reroll (a real developer
  product), the wishlist and the day's free trial.
* **The Loadout**: the class you bring (owned classes and today's trial).
* **Six elevator pads**: three public (Normal, Hard, Nightmare), two private (a leader, invites, a
  difficulty choice, Start) and one solo.
* **Launching a run**: the pad reserves a Run server, writes the run's record (party, difficulty,
  loadouts) and each rider's rejoin record to MemoryStore, then teleports the party. The Run
  server reads the record, sets the difficulty and classes, and lets in only that party.
* **Rejoin your run**: a card in the lobby while your run is still going.
* **The lobby itself (art step A9, the lobby half)**: 28 models made in Blender, 330,000 triangles
  in the place, built by one script.

Captures: `previews/Game/P21_*.jpg`. Blender sheets: `previews/Lobby/` and `previews/Town/`.

**Not done: the 15 class looks.** Class cards show the class's signature item until its portrait
exists (4 of 19 exist: Security, Quartermaster, Warden, Mad Scientist). Portraits drop in with no
code change (`Lib.ClassArt` uses `Portrait_<Class>` when the UI kit has it).

**Needs Landon: a live test.** Studio can't reserve servers or teleport, so the trip from a pad to
a Run server and back has only been tested up to the record (see "Live test" below).

## Design Notes

**Decisions**
1. **The shop is the profile's record, the rules are shared.** `Rules.ClassShop` (pure) rolls the
   day's slots, rerolls, the wish and the trial; `ClassShopService` (Lobby) applies them to the
   profile's `ClassShop` and `Loadout` records, so they are saved and the player's own client sees
   them. The paid reroll's grant is the same rule, so a receipt that arrives in the Run place still
   rerolls.
2. **Only today's four can be bought.** A class not in today's shop can't be bought, whatever it
   costs. The roll is even: every class you don't own is as likely as any other.
3. **The wishlist.** A wished class that hasn't been in your shop for 3 shop days is put in the
   next roll and stays through that day's rerolls. Seeing it, by luck or not, starts the count
   again, so a wish you couldn't afford comes back.
4. **The free trial** is one of the day's four, picked with the roll. A reroll moves it to one of
   the new four. It is used up when a pad leaves with it. A trial class plays at level 1 and earns
   no class experience (Prompt 20).
5. **The loadout settles itself.** After a new day, a reroll or a trial run, a loadout left on a
   class that can no longer be played goes back to the last owned class (`ClassShop.Settle`).
6. **Pads are data and a part.** `Config.Pads` lists them; a pad in the world is a model with a
   `PadId` attribute and a `Floor` part. Standing on the floor is riding the pad. The art's pads
   and the test blockout's pads used the same code unchanged.
7. **Public pads** count 20 s from the first rider and leave when full (6) or on time. **Private
   pads**: the first rider leads, their Roblox friends may board and so may anyone they invite
   from the lobby (up to 12); the leader picks the difficulty and starts. A leader who steps off
   hands on to the next rider. **The solo pad** leaves 3 s after you step on and waits while you
   have the Loadout open.
8. **Difficulty.** Normal is open; Hard after a victory; Nightmare after a Hard win (Section 5).
   Every rider needs the pad's difficulty: a rider without it is refused and told why, and a locked
   pad's sign says how to unlock it.
9. **Launching** (`Lib.RunLaunch`, used by the pads and by Play Again): reserve the server, write
   the run's record under its id, write each rider's rejoin record, teleport. Any step failing
   stops the launch, says why on the riders' screens, and frees the pad after 6 s.
10. **Who gets into a run** (`PartyService`, Run place): only the record's party. A stranger, or
    anyone in a Run server that isn't a reserved one, is sent back to the lobby. The record's
    difficulty is set before the first player is ready.
11. **Rejoin.** The rejoin record (the server's id and access code, under the player's id) is
    written for 5 minutes when the pad leaves; the Run server then renews it every 60 s for 180 s
    while the run is on and removes it when the run ends. So a run whose server died stops being
    offered within 3 minutes. Access codes never go to a client.
12. **Play Again** takes the party's owned classes with it. A trial isn't carried into a second
    run.
13. **Purchases** (`PurchaseService`, both places): ProcessReceipt grants first, records the
    receipt id in the profile, then confirms; a repeated receipt is not granted twice. The Class
    Shop Reroll (product 3730189637, 99 Robux) is its first row.
14. **The lobby's controls.** The camera is the run's (the mouse is locked), so every button
    shows its key: K Class Shop, L Loadout, and on a pad H Difficulty, G Invite, Y Start (D-pad
    and Y on a controller). A mouse-wheel click frees the cursor. The booths' prompts (E) open
    the same screens.
15. **The pad's sign** is a SurfaceGui on the pad's own board: its kind, riders, difficulty band,
    and its countdown or what it waits for.
16. **Later hub features aren't faked.** The showroom has no Legends Hall, talent board,
    boutique, Glowshard counter, mailbox, codes terminal, badge wall, leaderboards, VIP lounge or
    Digby yet. Each arrives with its prompt (27 to 31).

**The lobby's art (A9)**
17. **Main Street is ten blocks**, about 21 buildings, 444 studs from Elm St to Oak St, with the
    showroom between the Hardware and Atomic blocks on the north side. Each block is one model: two
    or three buildings and their pavement furniture. Beyond the barricades the same blocks stand
    again, then trees, hills and the water tower, so the town goes on in every direction.
18. **Buildings are decoration; what you bump into is invisible boxes.** Each model is merged into
    a few MeshParts with no collision. Its sidecar lists collider boxes and lights, and
    `AssetSetup` builds them inside the model, so a clone brings its own collisions. Shop fronts
    and building bodies are raised out of reach in the lobby, so nobody gets onto a roof.
19. **Lettering is geometry** (signs, the marquee, painted wall ads), from five open-licence
    fonts. No textures: everything stays on the 32-swatch palette.
20. **The same kit makes the ruined town.** `generators/Town/buildings.py` builds each building
    from parameters, so the Run place's Brightwater can be these blocks after 100 years.
21. **One script builds the place**: `tools/lobby_world.py` prints the Luau that makes
    `workspace.Lobby` (the showroom, pads, booths, blocks, road, cars, bunting, the town beyond,
    the walls, the spawns and the daylight). Re-running it replaces the lobby.

**Scope Risks**
* The 15 class looks (see the top).
* The Loadout has only its Class tab until talents, Legends and cosmetics exist (Prompt 27).
* The lobby has no people in it but players: no townsfolk, no Digby (Prompt 31), no sound
  (Prompt 32).
* VIP's second free reroll reads the player's `VIP` attribute, which nothing sets until the shop
  (Prompt 28).

**Bible Questions**
1. **Buying.** Built: only today's four can be bought. Right, or should every class always be
   buyable with the shop only choosing what is on show?
2. **The roll's odds.** Built: even. Should rarer classes turn up less often?
3. **The wishlist.** Built: forced into the shop after 3 shop days unseen; seeing it restarts the
   count. Right?
4. **The free trial.** Built: one of the day's four, moved by a reroll, spent when a pad leaves
   with it. Right?
5. **Hard's unlock.** The bible says "a Century Victory". Built: any victory unlocks Hard. Should
   it be only one of the two endings?
6. **A whole party's unlocks.** Built: every rider needs the pad's difficulty. Or may a leader
   who has Hard bring friends who don't?
7. **Private pads.** Built: the leader's Roblox friends board freely; others need an invite from
   the lobby. Right?
8. **The solo pad** leaves after 3 s and waits while the Loadout is open. Right?
9. **Play Again** brings owned classes only, never a trial again. Right?
10. **The pads' order** in the showroom, left to right: Solo, Private, Public Normal, Public Hard,
    Public Nightmare, Private. Right?
11. **The town's names.** Main Street needed names, so the art has them: Brightwater Savings Bank
    (1908), a barber, Rosie's Bakery, a hardware store (1921), the Atomic cinema ("It Came From
    Below"), Rexford Drugs, The Brightwater Gazette (est. 1889), Brightwater 5 & 10, Starlite
    gas, the Comet diner, Brightwater Market, Vista television, Dot's Dresses, Hi-Fi Records, The
    Brightwater Hotel (1912), Toyland, Kline's Shoes, Fizzy Pop soda fountain, Elm St and Oak St.
    The showroom says "Family Shelters", "Built to Last a Century" and "Open House Today". The
    same buildings would be the ruins players loot. Keep them, or do you have names?
12. **Where the later hub features go.** The showroom's east half (the displays, the lounge) and
    the street's buildings have room. Should the Legends Hall, boutique and the rest be inside the
    showroom, or in buildings along the street (the hotel as the VIP lounge, the Gazette's window
    for leaderboards)?
13. **The street is closed to cars** (barricades at both ends, cars parked). Right for a lobby,
    or should traffic drive through?

**Recommended Improvements**
* Townsfolk: a few residents walking the pavements and sitting at the diner would make the street
  live. The resident rig and its walk clip exist.
* The Atomic's marquee could show something live (the shop's reset countdown, an event).
* A short elevator ride when a pad leaves: the cage's gate closing and the floor dropping, before
  the teleport screen.
* The pads' cages could light in their difficulty's colour.

**Technical Risks**
* **The teleport is untested** until the live test: reserving a server, the Run server reading a
  real record, the party gate, rejoin and Play Again.
* **Phone performance.** The lobby is about 330,000 triangles and 1,000 parts. Fine on a PC; on a
  phone it needs measuring (Prompt 34). Roblox lowers far meshes on its own; if that isn't enough,
  the town beyond the barricades (a third of the triangles) can be cut down.
* **MemoryStore limits** scale with players online; the records are small (one per run, one per
  rider, renewed once a minute).
* Studio said its Assistant plugin changed version during this session and asked for a restart.
  Nothing failed, but restart Studio before the next session.

## Delivery Report

**Overview.** The lobby's systems (Class Shop, loadout, pads, launch, the party gate, rejoin,
purchases) and the lobby's world (A9).

**Files created**
* Lobby: `game/places/Lobby/server/Services/ClassShopService.luau`, `PadService.luau`,
  `RejoinService.luau`; `game/places/Lobby/client/Controllers/ClassShopController.luau`,
  `LobbyController.luau`, `PadController.luau`
* Run: `game/places/Run/server/Services/PartyService.luau`
* Both: `game/server/Services/PurchaseService.luau`, `game/server/Lib/RunLaunch.luau`,
  `game/server/Lib/Rejoin.luau`, `game/client/Lib/ClassArt.luau`
* Shared: `game/shared/Rules/ClassShop.luau`, `game/shared/Rules/Lobby.luau`,
  `game/shared/Config/Pads.luau`
* UI: `studio/ui/Lobby.lua` (the Lobby screen, 234 instances), `generators/UI/UI_Products.py`,
  `ui/products/Product_ClassShopReroll.png`
* Art: `generators/Town/townkit.py`, `buildings.py`, `props.py`, `Town_Props.py`, `fonts/`;
  `generators/Lobby/lobbylib.py`, `showroom_dims.py`, `street_plan.py`, `Lobby_Showroom.py`,
  `Lobby_ShowroomHall.py`, `Lobby_ShowroomFit.py`, `Lobby_ElevatorPad.py`, `Lobby_ClassBooth.py`,
  `Lobby_LoadoutBooth.py`, `Lobby_BunkerCutaway.py`, `Lobby_Blocks.py`; `tools/lobby_world.py`
* `game/reports/P21_Lobby.md`

**Files modified**
* `RunRecord` (a Studio key, `Mine`), `ClassService` (reads through it), `ResultsService` (Play
  Again through `RunLaunch`; wins counted per difficulty), `RunDirector` (`SetDifficulty`),
  `ProfileSchema` (`Loadout`, the shop's wish and trial fields), `UIController` (`ResetHint`),
  `Remotes`, `UIContract` (the Lobby screen), `Config.Tuning` (`Lobby`, the reroll's product id),
  `DataTests` (3 new tests).
* Art pipeline: `generators/lib/steadfast.py` (Neon and Glass parts split per colour; merged
  meshes over 12,000 triangles cut in pieces), `studio/AssetSetup.lua` (colliders and lights from
  the sidecar), `tools/setup_batch.py`.

**Architecture.** The Lobby runs the shared services plus four of its own (ClassShopService,
PadService, RejoinService, and PurchaseService which both places run). Rules are pure and shared
with the client's screens and the data tests. The Run place gained PartyService, which reads what
the lobby wrote. Nothing in a run trusts teleport data: classes and difficulty come from the
MemoryStore record.

**Integration notes**
* Prompt 22 (the cutscene): the first run's cutscene can start from the record; the profile's
  `FirstRunDone` is already saved.
* Prompt 27: the Loadout's other tabs go beside Class; a run's record has room for talents and a
  Legend (`Loadouts[userId]`).
* Prompt 28: a product is one row in `PurchaseService` and an id in Config; VIP sets the player's
  `VIP` attribute.
* The Run place's town: `generators/Town/buildings.py` and `props.py` are ready for a ruined pass.
* A new lobby model: write its generator on `townkit`, export, upload, run `tools/setup_batch.py`,
  place it in `tools/lobby_world.py` and re-run that.

**Testing checklist**

Lobby playtests on 2026-11-10 in Studio, with real key presses:
* [x] The shop of the day: 4 classes not owned.
* [x] Buying with Glowshards (the Engineer, 122 to 82), saved in the Studio profile store.
* [x] The free reroll, then the 99 Robux reroll through Roblox's own purchase prompt (a Studio
      test purchase): ProcessReceipt granted it once; the same receipt again was not granted twice.
* [x] The wishlist: a wished class forced in after 3 shop days unseen (dev `shop.day`).
* [x] The free trial: equipped, then marked used as a pad leaving with it would (dev `shop.trial`);
      the loadout settled back on an owned class.
* [x] A public pad: 20 s from the first rider, leaving on time and when full (dev `pad.fill`).
* [x] A private pad: leading, the difficulty key, the invite list, Start.
* [x] The solo pad: 3 s, waiting while the Loadout is open.
* [x] A locked Hard pad refusing a rider and saying why.
* [x] The rejoin card (a made-up record): Rejoin tries, Not now dismisses.
* [x] The record chain: a private Hard pad with the Engineer wrote the record; a Run playtest read
      it ("1 in the party, Hard", "level 1 Engineer").
* [x] In the built lobby (build `p21-a5fb2fb`): all 6 art pads adopted; walking onto the Private
      pad made me its rider and opened the Loadout; the signs show on the pads' boards; E at the
      Class Shop booth opened the shop.
* [x] The walls: a character sent walking at both street ends, both end corners, both alleys, the
      gas station's back and side, the diner's side gap: stopped every time.
* [x] Every art model's size and position checked in Studio against its sidecar (0.01 studs).
* [ ] Not seen: reserved servers and teleports (see below), a second player (the party gate with
      a stranger, invites between two people, a leader handing on), touch, a real controller.

Studio captures in Edit came back at 270 by 151 pixels this session, so the art was judged from the
Blender sheets and from play-mode captures (554 by 311).

**Live test (needs the published game, played from the Roblox app)**
1. Publish both places. Join, step on the solo pad: you should land in a new run as your class.
2. In that run, leave the game. Join again: the lobby should offer "Rejoin your run"; take it.
3. Lose or win a run: Play Again should start a new run with the same party and classes; Return to
   Lobby should bring you back to Main Street.
4. With a friend: a private pad (you lead, they board, you pick Hard if both have it, Start), and
   a public pad's countdown with both aboard.
5. Buy a 99 Robux reroll for real once (after the free one).

**Future extension notes.** Pads, products and classes are rows of data. The lobby's world is
generated: change `street_plan.py` or a generator and re-run the builder.

## The A9 lobby art (2026-11-10)

| Model | Triangles | What it is |
|---|---|---|
| Lobby_Showroom | 17,061 | The shell: forecourt, glass front, canopy, pylon, fascia, roof billboard |
| Lobby_ShowroomHall | 11,636 | The hall: bays, columns, beams, terrazzo, lamps |
| Lobby_ShowroomFit | 17,256 | Displays, the lounge, the directory, posters |
| Lobby_Frontage | 6,834 | The showroom's pavement: lamps, trees, benches |
| Lobby_ElevatorPad | 1,826 | A pad: floor, cage, panel, sign board (6 placed) |
| Lobby_ClassBooth, Lobby_LoadoutBooth | 5,209 and 2,995 | The two booths |
| Lobby_BunkerCutaway | 3,894 | The model bunker on show |
| Lobby_Block Bank, Hardware, Atomic, Gazette | 10,563 to 15,905 | The north side |
| Lobby_Block Gas, Diner, Market, Vista, Hotel, Soda | 7,399 to 14,237 | The south side |
| Town_CarSedan, Town_CarPickup | 1,328 and 1,232 | Cars; the body takes any colour |
| Town_Bunting, Barricade, WelcomeBanner | 260, 714, 1,600 | Street dressing |
| Town_TreeBig, TreePine, TreeClump, Hill, WaterTower | 80 to 1,982 | The town beyond |

All 28 are in the Lobby place under `ServerStorage.Assets.Lobby` and `.Town`; ids are in
`manifest.csv`. The world builder is asset 104368016773499 (tooling); run it in the Lobby place
with `require(game:GetService("InsertService"):LoadAsset(104368016773499):FindFirstChildWhichIsA("ModuleScript", true))()`.
