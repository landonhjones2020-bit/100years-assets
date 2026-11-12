# 100 Years Below: handoff for the next chat

Written 2026-11-12 (afternoon, Chicago), after Prompt 26. The game was called 100 Years Of
Fallout until 2026-11-09; the Project and its docs keep that name. The game bible (live doc
https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU and the two project parts) wins over everything
here. It is in step with Landon's decisions up to Nov 10 (live doc rev 174; both project parts
refreshed from it the same day). **Landon answered every open Bible Question of Prompts 19 to 26
on Nov 12 (78 answers): `game/reports/Answers_2026-11-12.md`** (also in the Project as
`claude/100-years-of-fallout-answers-2026-11-12.md`). None of them is in the bible yet.

## Landon's instruction for the next chat

Nov 12, 12:59: "just finish your testing and wrapp up. Create the handoff with the context for
prompt 27,28,29 and building the new outside city for when my fable limit resets". Prompt 26 is
finished and wrapped up; Prompt 27 was **not** started. The next chat's work is the four items
below under "Next". At 13:07 Landon chose the order: **the new outside city first** (Brightwater
Ruins as a large, real town), **then Prompts 27, 28 and 29**. Keep this file current as each lands.

## Start here

1. Clone the repo `landonhjones2020-bit/100years-assets` (private) and read `CLAUDE.md` (the
   runbook) and `BUILD_LOG.md` (status, every id, what is open).
2. Read `game/reports/Answers_2026-11-12.md` (Landon's 78 answers of Nov 12, and what each one
   changes, grouped by where it gets built). Put them into the live bible first, as small edits
   marked "(Landon)" (`CLAUDE.md` 4d), then refresh the Project's two parts.
3. Start installing Blender in the background (`pip install --break-system-packages bpy==5.2.3`).
   The city needs it from the first hour; the prompts need it for icons and Legend art.
4. Studio: `list_roblox_studios` shows "100 Years Of Fallout" (the Lobby) and "run" (the Run
   place). Their ids change when a Studio restarts or reconnects: list them again instead of
   using a remembered id (on Nov 12 they were Lobby `a1743569-516c-4130-a698-4861fafeaf05`, Run
   `f2a97815-9af1-451e-827f-f7b3c078b796`). Never touch the Night Shift studio. Ask Landon to
   restart Studio if tools misbehave.
5. Tool schemas: after a long chat, load the Studio tools again with ToolSearch
   (`select:mcp__remote-devices__Roblox_Studio__execute_luau,...open_cloud_invoke,...start_stop_play,...screen_capture,...get_console_output,...list_roblox_studios,...user_mouse_input,...user_keyboard_input,mcp__remote-devices__device_commit_files`).
6. No local Luau linter: a download of the Luau tools was refused on Nov 12 and must not be worked
   around. Syntax and types are checked by installing the build in Studio (the installer's
   StructureCheck and data tests) and reading the first playtest's console.

## Where things stand

* **Prompts 0 to 26 are built and tested in Studio.** Code build `p26-1cd0910` (code asset
  95026446991297, revision 122) is installed in both places: StructureCheck 0 errors (Lobby 356
  checks, Run 580), 133 data tests. `game/BUILD.json` says prompt 26.
* **Prompt 26 (residents, phase 2).** Every resident rolls two traits (a Common one good and one
  bad, a Rare two good); traits act through `Config.Modifiers` keys on output, health, meals,
  rest, morale, panic, fights, fires and expeditions. Gear: one bunker-wide **gear locker** (the
  `Gear` replication collection) and three slots on each resident (Weapon, Outfit, Tool); found
  gear (every loot table's `Gear` line, skipped until now) goes into the locker; outfits give +1
  to +3 by rarity (the Security Vest +20 health, the Hazmat Suit ignores gas), tools +20% in
  their room, the Wrench mends its room; armed and Brave residents fight in their room and their
  guns use the shared Ammo pool. Conditions: Injured (under 35% health or after a revive, 60%
  output, the Medbay treats it) and Panicked (while fleeing and 12 s after, no work). Morale's
  bottom: a Miserable resident may refuse work, start a fight, or after 3 cycles leave for good
  (recorded as left, not died). The Residents screen's card is now a personnel file (small photo,
  the file below it, three gear slot buttons in the card). Report:
  `game/reports/P26_ResidentsPhase2.md` (10 decisions, a "not tested" list, 13 Bible Questions);
  captures `previews/Game/P26_PersonnelFile.jpg`, `P26_GearSlots.jpg`. The last build's two small
  changes (no experience while refusing work, larger card labels) passed the installer's checks
  and were not played again.
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
  a Quarters bed, a working Medbay cures one patient in 45 s. The four monsters: Shardlings, the
  Prism Stalker, the Geode Golem and the Resonator. The Crystal Colossus (Year 75, 20,000
  health). The Crystal Hollows' eight cave pieces. Report: `game/reports/P24_CrystalHollows.md`
  (13 Bible Questions); captures `previews/Game/P24_*.jpg`.
* **Prompt 23 (the Flooded Caverns).** Era II plays: floods, gas leaks, hazard pockets, the four
  monsters (Murklings, Bloat Toad, Lurker, Tide Crab) and The Deluge (Year 50). Report:
  `game/reports/P23_FloodedCaverns.md` (9 Bible Questions); captures `previews/Game/P23_*.jpg`.
* **Prompt 22 (the intro cutscene).** Every run opens with the 30 seconds of bible Section 4,
  played by each client from data made in Blender. Report: `game/reports/P22_IntroCutscene.md`
  (9 Bible Questions). How to change it is in `CLAUDE.md` section 4e.
* **Prompt 21 (the Lobby).** The Lobby place is Brightwater's Main Street on a sunny morning with
  the Steadfast showroom in the middle (`workspace.Lobby`, built by the script
  `tools/lobby_world.py` prints): six elevator pads, the Class Shop and Loadout booths, the
  bunker cutaway, the Daily Class Shop (Glowshards, one free reroll, the 99 Robux reroll as a real
  developer product, the wishlist, the free trial), the loadout (class only so far), pads that
  reserve a Run server and write the run's record, the Run place's party gate, "Rejoin your run".
  Report: `game/reports/P21_Lobby.md` (15 Bible Questions, a live-test list).
* **Prompts 19 and 20.** The blueprint draft (`P19_BlueprintDraft.md`, 7 questions); all 19
  classes with kits, passives, the ability on Q, levels 2 and 3, class experience
  (`P20_Classes.md`, 15 questions).
* **Art in Studio.** Run place: A1 bunker kit, A2 (all 34 weapons, tools and devices), A4 Mines
  monsters and the Brood Mother, A5 surface kit (the placeholder town's buildings), A6 cave
  pieces, both Ash Raiders after their detail pass, A8 (the Flooded monsters, The Deluge, the
  burst pipe and gas vent; ids in `exports/A8_ids.json`), A10 (the Crystal Hollows monsters, the
  Crystal Colossus, eight cave pieces, the Source with nine clips, its tendril, the Source
  Chamber; ids in `exports/A10_ids.json`), and A9's cutscene set. Lobby place: A9's lobby half,
  28 models (`ServerStorage.Assets.Lobby` and `.Town`). Class looks: all 19 as portraits on the
  class cards (`previews/Residents/Class_Portraits.jpg`); nothing is worn in a run yet (A11).
  Residents all show one portrait (`Portrait_Survivor`) on their cards.
* **The art kit for towns.** `generators/Town/townkit.py`, `buildings.py` and `props.py` build
  1950s Main Street buildings from parameters, as merged decoration with collider boxes and
  lights in the sidecar. STYLE.md ("Buildings and streets") has the rules. This is the kit for the
  new outside city.

## Next

Standing rules (bible Section 24): one system per prompt, the bible wins, never invent gameplay
(suggest it in the Design Notes), content is data, a real playtest for timing, permissions and
saved data, Design Notes and a Delivery Report in `game/reports/P##_*.md` with Bible Questions.
Every new screen is a page of The Frame (bible Section 18) and themed, never generic.

The three prompts lean on each other: talent slot 1 opens at account level 5 (Prompt 29), slot 2
can come from the Extra Talent Slot pass (Prompt 28), eight Legends come from badges (Prompt 29).
Build each prompt's side of a link and give the other side a dev command until its prompt lands.

### First: the new outside city, Brightwater Ruins as a large, real town (Run place)

Landon, Nov 9: "The town is a fine place holder right now but needs to be much more detailed. I
want it to feel like a large town that was actually real"; "make the town parts in your own
blender environment it needs to actually look good". Bible Section 12: the map is the lobby's
town after the bomb, so players recognise it; about 1,400 by 1,100 studs with about 25 places to
enter (his number for buildings in all was about 120). Places to search: Main Street diner,
hardware store, grocery, gas station, motel, radio tower, water tower, rail yard with a wrecked
train, the ruined Steadfast showroom, a military checkpoint that opens in Era III. Reached by the
elevator behind the Blast Door; trips happen in the 3-minute day (the storm comes with every
Surge); threats are Ash Raiders, Ash Jackals and storm-only Ash Wraiths.

What exists:

* **Today's placeholder**: `game/server/Lib/BrightwaterMap.luau`, a tool run in Studio (Edit:
  `require(game.ServerScriptService.Lib.BrightwaterMap).Build()`), builds `workspace.Surface`
  about 640 by 520 studs at `GROUND` = 200, from `ServerStorage.Assets.Surface.<Asset>` (the A5
  buildings, `generators/Surface/Bldg_*.py` on `townlib.py`, much plainer than the town kit) or
  graybox stand-ins. Main Street runs along X at Z = 0, -Z is north, the bunker entrance is in the
  north hill, the rail bed at Z = 168. A rebuild keeps places where they were moved in Studio and
  leaves `workspace.Surface.Decor` alone (Landon's dressing).
* **The contract SurfaceService reads** (keep it, or change both sides together): markers
  `ElevatorExit`, `ElevatorCall`, `SurvivorSpot`, `BigFindSpot`, `SpawnPoint`, `CampSpot` (where
  the raider camp may stand, each with a `Hint` for the radio logs); containers with `Container`
  and `Location` attributes; gates with `MinEra` (the checkpoint). Today: 43 containers, 11
  survivor spots, 8 find spots, 18 spawn points, 4 camp spots, 1 gate.
  `Config.SurfaceLocations` has the bible's ten places, each with a loot table in
  `Config.LootTables`; the other fifteen places to enter need rows of their own (amounts
  provisional, said so in the report).
* **The town kit** (`generators/Town/`): `buildings.py` has `commercial`, `bank`, `cinema`,
  `diner`, `gas_station`, `market` and the details (sash windows, awnings, cornices, blade signs,
  fire escapes, wall ads, roof units), `props.py` the street furniture and cars, `townkit.py` the
  merge, colliders, lights, lettering and renders. The lobby's clean Main Street
  (`generators/Lobby/Lobby_Blocks.py`, `street_plan.py`: ten blocks between Elm St and Oak St
  and four beyond) is the same street before the bomb.
* **The pipeline for a scripted world**: `tools/lobby_world.py` prints the Luau that builds the
  lobby from a plan in Blender space ((x, y, z) to Studio (-x, z, y)), sent as a module through
  `tools/chunk_module.py` and one PATCHed Model asset (`CLAUDE.md` 4a). The city should work the
  same way.

**Landon's answers for the city (Nov 12)**: **heavily ruined** (fallen roofs and walls, rubble
everywhere, few buildings intact); **an ash wasteland** (grey ash, dead and burnt trees, nothing
green); **full size, simpler far away** (about 1,400 by 1,100 studs and 120 buildings, detailed
where players walk, plain shells beyond, streamed in); **all four districts** beyond Main Street
and the bible's places: houses and side streets (yards, porches, a school or church), an
industrial edge (warehouses, a factory, the rail yard, a power substation), a waterfront (a lake
or river, docks, a bridge: the town is Brightwater) and outskirts (farms, a drive-in, a highway
out of town). The shelter entrance on Mine Hill matches the intro's blast door (two steel leaves
on an overhead rail, sunburst, "STEAD / FAST", "SHELTER / No. 1", a wheel, a SEALED lamp; the
steps, arch, landings and terrace of the intro's hill path). The names on the lobby's street and
the intro's set are canon (Brightwater Savings Bank, the Atomic, the Comet diner, Starlite gas,
the Gazette, the Hotel, Elm St and Oak St, "Brightwater Community Shelter", "BRIGHTWATER RADIO",
"BRIGHTWATER MINE, CLOSED 1931"), so the ruins carry them, half-burnt. He also wants the residents
to walk out of the Blast Door at the Century Victory, which needs the outside of the door: build
it with the city.

A suggested way in (the next chat's call):

1. **A plan first**: a `generators/Surface/town_plan.py` (like `street_plan.py`) with the street
   grid over 1,400 by 1,100 (Main Street on the lobby's line, cross streets, a residential
   quarter, the rail yard and an industrial edge, the north hill with the bunker's door), every
   lot's building, whether it can be entered and which `SurfaceLocations` row it is. Render a top
   view and show Landon before modelling 120 buildings.
2. **A ruin pass on the town kit**: the same buildings 100 years after the bomb, heavily ruined
   but still recognisable from the lobby (seeded: roofs and upper floors fallen in, walls down to
   their first floor, glass gone to dark holes, signs with missing letters, scorch and grey ash on
   every swatch, rust, boarded doors, rubble mounds, dead and burnt trees, burnt-out cars). Do
   one block, render it beside the lobby's clean block, and hold it to the lobby's finish before
   doing the rest.
3. **Inside**: about 25 interiors that hold the containers, survivor spots and finds at sockets
   (`Socket_Container1..`, `Socket_Survivor1..`, `Socket_BigFind`), each one a real room (counters,
   shelves, stairs) that tells you what the place was.
4. **Triangles**: the bible's budget is 6,000 a surface building and about 150,000 seen at once on
   a phone; a lobby block is about 12,000 and the lobby is already about 330,000. Plan two levels
   of detail from the start (full fronts on the streets players walk, plain shells beyond), stream
   surface buildings as Atomic models (bible Section 23), and measure in Studio.
5. **Studio**: upload and set up through `setup_batch.py` (colliders and lights from the
   sidecar), build `workspace.Surface` from the plan with the markers above, and playtest the
   surface loop for real: ride up, loot, a rescue, the raider camp, a storm, the Era III gate,
   ride down.

### Prompt 27: Talents and Legends (Lobby and Run)

What the bible says:

* **Talents** (Section 14): a talent slot adds the passive of another class you own to your
  current one. Slot 1 at account level 5; slot 2 for 150 Glowshards or the Extra Talent Slot pass;
  slot 3 for 300 Glowshards. Passives only; the Warden's tie-break and the Tinkerer's drone can't
  be talents.
* **Legends** (Section 15): permanent legendary residents. Before each run every player picks one
  they own and it lives in the bunker for the whole run (a full team brings six). A Legend starts
  at level 5 with its signature trait, one good trait and signature gear; never ages; is never lost
  for good (one who dies sits out the rest of that run only). Renown 1 to 5 rises with every run
  the Legend survives and unlocks an alternate outfit and a small stat bonus. New players get one
  starter Legend free. 24 at launch: 8 from badges, 12 bought with Glowshards (150 to 400, never
  random), 4 limited-time event Legends. The bible names only the **first twelve** (their
  signature traits and how each is got are in its table).
* **Screens** (Section 18): the Loadout (tabs Class, talents, Legend, cosmetics; Equip) and the
  Legends Hall (tabs All, owned, events; Legend portraits; signature trait, renown, how to get;
  Buy or Equip). Rarity rule (Section 19): every Legend is a one-of-a-kind design at the Legendary
  bar (a silhouette nothing else has, a hand-made head or hair, glowing or moving parts, its own
  idle), never a recolour.

What exists:

* `Config.TalentSlots` (the three slots, their prices, the pass), `Config.Classes` (`Talentable`,
  17 of 19 true; `TalentExclude`), `Config.Legends` (the first twelve; its header says "the rest
  arrive with Prompt 27", but the bible doesn't name them: draft them for Landon's OK, below),
  `Tuning.Legends` (`StartLevel` 5, `RenownMax` 5, `RenownStatBonus` 1, `StarterLegend`
  RosieKowalski), `Config.GamePasses.ExtraTalentSlot` (no `PassId` yet).
* Saved data (`server/Lib/ProfileSchema.luau`): `Talents = { Slots, Equipped }` and
  `Legends = { [id] = { Renown } }`; a new profile gets the starter Legend.
  `ProfileService:SpendGlowshards`, `AddGlowshards`, `Update`.
* The Lobby: `ClassShopService` and `ClassShopController` hold the Daily Class Shop and the
  Loadout (class only; its hint says "Talents, Legends and outfits join the loadout later");
  `server/Lib/RunRecord.luau` and `RunLaunch.luau` write what the lobby sends to a run.
* The Run place: `ClassService` turns a class's passive into modifiers (`Rules.Modifiers`) and
  reads the run record; `ResidentService` (Prompt 26) has traits by `Config.Modifiers` keys, the
  gear locker and slots, and `Lose`/`die`; `ResultsService` pays at the run's end (where Renown
  would rise). Residents phase 3 (aging) is Prompt 36, so "never ages" costs nothing yet.

Landon's answers (Nov 12): **draft Legends 13 to 24** (names, signature traits, how to get each:
the bible says 8 from badges, 12 for Glowshards at 150 to 400, 4 from events) **for his OK** before
any goes in; **Rosie first**: the free starter Legend at full Legendary quality in Prompt 27, the
other eleven as an art step of their own after it.

To decide or ask: what a Legend's signature trait is in modifier keys (each of the twelve needs a
system that exists: Rosie repairs rooms on her floor, Big Earl guards the Blast Door, Ivy stops
fire spreading, Dutch's digs, Wren's radio recruits, Ingrid's Lab); how a Legend shows in the
bunker (a resident with `Legend = id`, its name, nickname and look); what "sits out" means on
screen; the Renown stat bonus and alternate outfit; Legend art (twelve unique designs and
portraits is an art step of its own: plan it with Landon, it is a lot of work at the Legendary
bar).

### Prompt 28: Shop: Glowshards, passes, team boosts, announcements (both places)

What the bible says (Section 17): five Glowshard packs (99 to 4,999 Robux), six game passes (VIP,
Big Backpack, Helper Drone, Extra Talent Slot, Quick Revive, Starter Pack), seven team boosts
bought during a run (Revive, Rush Construction, Blueprint Reroll, Storm Shield, Supply Drop,
Instant Recruit, Emergency Repair), cosmetics (A11 art), the Store screen (tabs Glowshards,
passes, cosmetics, bundles). Principles: paid power is fine in co-op, never a way around the team
vote, every purchase in a run gets a banner (and a chime: audio is Prompt 32) naming the buyer, no
paid random items. Compliance: ProcessReceipt grants, records the receipt id, then confirms.

What exists:

* `Config.GlowshardPacks`, `Config.GamePasses`, `Config.TeamBoosts` with the bible's prices and
  empty `ProductId`/`PassId`. `PurchaseService` (both places: `ProductId(name)`, `Prompt`, receipt
  handling) and `ProfileService:GrantPurchase` (grant once, record, confirm) are built and were
  proven with the Class Shop reroll (developer product 3730189637, made through Open Cloud).
* Creating a developer product: `POST /developer-products/v2/universes/10775267993/developer-products`
  (multipart: name, description, isForSale, price, `imageFile`; scope `developer-product:write`).
  Game passes have their own Open Cloud endpoint: read the reference with `http_get` from
  https://create.roblox.com/docs/cloud before the first call. Creating products and passes on his
  live game is outward-facing: tell Landon what will be created (names and prices) first. Icons:
  render them in Blender (`UI_Portraits.py`'s icon path), never placeholders.
* What each boost or pass touches, already built: Revive (CombatService), Rush Construction
  (BuildService), Blueprint Reroll (DraftService, `draft.reroll`), Storm Shield (SurfaceService's
  storm), Supply Drop (a crate at the Blast Door: InventoryService/EconomyService, and a model),
  Instant Recruit (`ExpeditionService:Recruit`), Emergency Repair (BuildService, DisasterService),
  Big Backpack (InventoryService's slots), Quick Revive (CombatService's downed timer), VIP (the
  run payout in ResultsService, the Class Shop's free rerolls, a lobby lounge and tag), Starter
  Pack (a Rare class of the player's choice, a cosmetic). The Helper Drone (picks up loot, lights
  dark rooms, never fights) is a new system with a model: the biggest piece of this prompt.
* The banner: the HUD's full-width banner under the vote banner (`hud.banner` dev command).
* Landon's answers (Nov 12): **create the products and passes through Open Cloud as needed**, and
  ask him before anything that costs Robux. **The Class Shop changes**: every class can be bought
  at any time; the daily shop becomes **four deals a day at 20 to 40% off** ("deals similar to 99
  nights", shown where classes are bought in the lobby); rarer classes turn up as deals less often;
  the 99 Robux reroll (after the free one) rerolls the deals; the wishlist and the free trial stay.
  **Hub features go along Main Street**: the Store in a shop, the Brightwater Hotel as the VIP
  lounge.
* Testing: a Studio purchase is a test purchase; Roblox's purchase prompt is in CoreGui and its
  Buy button is clickable by instance path (`CLAUDE.md` 4c.6).

### Prompt 29: Meta: badges, quests, account level, leaderboards, codes (both places)

What the bible says (Section 16): account level 1 to 100 from run experience (talent slot 1 at
level 5, titles, lobby flair, Codex pages, free cosmetics at milestones); badges (survival at
Years 25, 50, 75, 100; each depth band; Century, Deep, Hard and Nightmare victories; 30 residents
alive in one run, a run with no resident deaths, 50 survivors rescued in total; each boss, 1,000
monsters; hidden lore badges), some unlocking Legends; quests (3 daily at 3 to 5 Glowshards, 3
weekly at 15, both reset at 00:00 UTC); the Codex (lore, monsters, residents; unlocked by badges
and radio logs); leaderboards on lobby billboards (fastest Deep Victory, most years in Endless,
most residents alive at Year 100; weekly and all-time); codes (set per event). Screens: Quests
and rewards (Daily, weekly, badges, login), Codex, Leaderboards.

What exists:

* `Config.Badges` (only two rows: fill it from the bible's list), `Config.Quests` (a couple of
  rows; `Goal.Event` names the run event that counts, `Class` narrows it), `Config.Leaderboards`
  (the three), `Config.GlowshardRewards`, `Config.RadioLogs` (the Codex's lore source).
* Saved data: `Badges`, `Quests = { Daily, Weekly, LastReset }`, `AccountLevel`, `AccountXP`,
  `Stats = { Runs, Wins, BestYear, Deepest }`.
* `ResultsService` (Run) already counts a run's stats and stories and pays Glowshards at the end:
  quests and account experience hang off the same place. The results screen has a rewards tab.
* Roblox badges need `BadgeId`s: check what creating them costs and how (Open Cloud reference)
  before making any, and tell Landon. Leaderboards are OrderedDataStores (weekly keys by UTC week)
  shown on billboards in the lobby (`tools/lobby_world.py` builds the lobby's world). Codes must
  live on the server only (never in `ReplicatedStorage`), redeemed once per profile.
* Landon's answers (Nov 12): create the badges (ask him first if they cost Robux); finding the
  Source Chamber pays **a one-off Glowshard bonus** of its own (`Config.GlowshardRewards`);
  leaderboards in **the Gazette's window** and quests along Main Street.

### Landon's answers that change systems already built

Build them as one pass (as Prompt 19 built the Prompt 13 to 17 answers), after the city and before
Prompt 27 unless Landon says otherwise; numbers refer to `game/reports/Answers_2026-11-12.md`:

* **Residents**: residents swat Burrow Ticks in their room even two or more (10); an alert the cycle
  before a Miserable resident may leave (11); the personnel-file detail layout on the other
  screens too (12); Rares' second form, one good trait and +2 to every stat, for half of them (13);
  armed residents at half a player's damage (14); Hardy and the Hazmat Suit also cut drowning (16).
* **The Source**: a third round of tendrils before the end (18); a tendril may grow in the Reactor
  Core on Hard and Nightmare (19); it falls asleep again and heals fully if left alone (21); mixed
  monsters from every band pour out of it as its minions (24); floor 10's other cells hold rich
  Crystal and rare finds (25); the residents walk out at the Century Victory (26, with the city).
* **The Crystal Hollows**: a powered room's lights reveal a Prism Stalker (29); Surges can choose a
  radiation leak (32) and an outbreak (34); a Crystal hazard pocket leaks radiation or gas (33); a
  Quarantine button on the resident card (35); the sick walk to the Medbay (36); the Colossus's
  stun and slam scale with the number of players (38).
* **The Flooded Caverns**: a prompt at a gassed room's door vents it faster (42); bare tunnels flood
  (43); the Lurker grabs players too, mash to break free (44); The Deluge's flooding scales with the
  party (46).
* **The intro**: the Source's glimpse has one great eye (55); Skip is press and hold (58).
* **The lobby and classes**: a leader with Hard or Nightmare brings friends who lack it (65); about
  half of the 19 class looks become women (72: propose which, then re-render); the Cook's melee
  weapon is a frying pan (73: a new item and model).
* **The draft**: an Endless pool of cards for late and Endless runs (76): draft the cards for his
  OK first.

## Open work after that

1. **Digby the Gopher** (the mascot: the lobby's greeter and Prompt 31's tips) is still unmade.
2. Prompt 30 (crafting, trader, raids, wanderers, vote kick) follows 29; the Tinkerer trait's
   crafting speed waits for it.

## Landon's decisions since the last handoff

* Nov 9: 43 answers (all in the bible now), and the title: **100 Years Below**, on his lawyer's
  advice. `Constants.GAME_NAME` and the repo's docs carry it.
* Nov 9 and 10: the Ash Raider needed more detail ("Not up to our standards"); after the detail
  pass, "looks good". The raider at about 3,700 of 4,000 triangles is the bar for a human enemy.
* Nov 10 to 12: as he left for classes, "IF you finish before I return I want you to create the
  recap and handoff and then begin on the next 3 prompts" (Nov 10, Nov 11 twice, Nov 12 06:31 and
  12:47). Prompts 22 to 26 came out of those.
* Nov 12, 12:59: finish testing, wrap up, and write this handoff for Prompts 27, 28, 29 and the
  new outside city (above). 13:06: "finish where fable left off with the handoff". 13:07: "also
  ask me any questions fable had left open ended for me to answer so you can add it to the
  nesscary context": he answered all 78 open Bible Questions of Prompts 19 to 26 and chose the city
  first (`game/reports/Answers_2026-11-12.md`).
* His standing bar: beat 99 Nights in the Forest on finish; UI themed, never generic; monsters
  detailed, bosses scary; art made in Blender here and it has to actually look good.

## Waiting on Landon

* **Nothing is waiting on his answers**: every Bible Question of Prompts 19 to 26 was answered on
  Nov 12. Two things will need his OK when they are drafted: Legends 13 to 24 (Prompt 27) and the
  Endless draft cards.
* **His look at the art and screens**: the resident card (`previews/Game/P26_*.jpg`), the Source,
  its tendril and chamber (`previews/Game/P25_*.jpg`, `previews/Bosses/Boss_Source*.png`,
  `previews/Caves/Cave_Source_Entry*.png`), the A10 and A8 art (`previews/Monsters`,
  `previews/Bosses`, `previews/Caves`, `previews/Game/P23_*.jpg`, `P24_*.jpg`), the intro, the
  lobby and the class looks.
* **The live test of Prompt 21** in the published game (the list is in `game/reports/P21_Lobby.md`):
  a pad to a real Run server, rejoin, Play Again, Return to Lobby, a friend on a private pad, one
  real 99 Robux reroll.
* The AutoScale Lite pass on The Frame and HUD (Prompt 6).
* Things only he can test: two or more players, a phone, a gamepad on the screens, a whole boss
  fight by real damage.

## Testing tips

* **Residents, phase 2.** `gear` (the locker and who wears what), `gear.add <piece|random> [n]`,
  `pack.add Gear <n>` (the loot path), `resident.equip <id> <Weapon|Outfit|Tool> <piece|none>`,
  `resident.trait <id> <Trait> [Trait]`, `resident.morale <id|all> <0-100> [cycles low]`,
  `resident.hurt <id> <n>`, `resident.assign <id> <room|none>`, `production`, `brains`. A piece
  is `Item` or `Item:Rarity`. Rooms are dark (no output) until the Reactor Core has a crew. A cycle
  is three `clock.next` presses with the clock running (siren, Surge, next day): pause and
  `monsters.clear` between them, or the Surge's monsters kill the founders. The card's gear
  buttons are `LocalPlayer.PlayerGui.Frame.Cabinet.Pages.Residents.Detail.Body.GearOutfit` (and
  `GearWeapon`, `GearTool`); scroll the Body to them before clicking by instance path.
* **The Source.** The chamber: `grid.dig 3 2` down to `grid.dig 10 2` (it digs without rolls),
  `deep.cave 10 2` (the chamber opens, the Source asleep), `deep.tp 10 2`, then walk down the ramp
  or `boss.wake`. The bunker: `year 100`, `clock.resume`, `clock.next`, wait 20 s for the siren
  and 8 for it to rise (or `boss.start Source`). In either: `boss.tendrils`, `boss.cut`,
  `boss.hurt <n> [weak]`, `boss.roots`, `boss.regrow`; `run.keepgoing` after a victory. Client:
  `victory.play century|deep`.
* **Radiation, outbreaks and Era III.** `leak` (the door), `leak <room> [strength]`, `leak.storm`,
  `leak.seal`, `leak.clear`; `outbreak [residentId]`, `outbreak.cure [id|all]`,
  `outbreak.deep <id> [force]`; `flare`; `boss.start CrystalColossus`, `boss.light [s]`,
  `boss.volley`. A Crystal cave: `grid.dig 3 0` to `7 0`, `grid.dig 7 1`, `deep.cave 7 1`,
  `deep.tp 7 1 [piece]`.
* **Floods, gas and Era II.** `flood <room> [level] [nopipe]`, `flood.patch`, `flood.drain`,
  `gas [room]`, `gas.seal`, `gas.clear`, `pocket <floor> <column>`, `disasters`,
  `monster <Type> [n]`, `monster.hit <Type> <amount> [front|back|side]`, `monsters`,
  `boss.start [BroodMother|Deluge]`, `boss.dive`, `boss.surface`.
* **The intro.** It plays at the start of every Run playtest (`run.skipintro` skips it). Client
  commands (`PlayerScripts.DevInvoke:Invoke(cmd)`): `cutscene`, `cutscene.at <seconds>`,
  `cutscene.play [from]`, `cutscene.stop`, `cutscene.skip`. Server: `intro`, `intro.first`.
* **The lobby.** Server: `shop`, `shop.new`, `shop.day <n>`, `shop.rerolls <n>`,
  `shop.trial <used|unused>`, `pads`, `pad.go <id>`, `pad.fill <id> <n>`,
  `pad.unlock <Hard|Nightmare|none>`, `products`, `purchase.test <Product>`, `rejoin`,
  `rejoin.fake [Difficulty]`, `rejoin.clear`. Keys: K Class Shop, L Loadout, Backspace closes The
  Frame; on a pad H difficulty, G invite, Y start; E at a booth. A pad that leaves in a Lobby
  playtest writes the run's record under the Studio key; a Run playtest within 10 minutes reads it.
* **Surface.** `surface.up`/`surface.down`, `pack.add <resource> <n>`, `surface.spawn <type> [n]`,
  `survivor`, `surface.find`, `find`, `storm on`, `loot.refill`, `year 51` (Era III opens the
  checkpoint). `god <s> <player>` from the server; it can't be shortened.
* **Profiles.** Studio uses the `PlayerProfiles_Studio` DataStore: `profile`, `profile.raw`,
  `profile.add`, `profile.save`, `profile.receipt`, `profile.locktest`, `class.own`. Two playtests
  at once (Run and Lobby) share one profile lock: the second is kicked.
* **Expeditions, classes, the draft.** `exp`, `exp.send <surface|deep> <cycles> <medkits> <id...>`,
  `exp.cycle [Quiet|Hurt|Lost|Distress]`, `exp.call`, `exp.home`, `recruit [tier]`; `classes`,
  `class <Id> [level]`, `ability [option]`, `ability.ready`, `classxp <years>`,
  `resident.arm <id|all> [item|none]`, `record <Class> [trial]`; `draft`, `draft.open`,
  `draft.take`, `draft.reroll`, `bounty`.
* **Captures.** In a playtest bind a `ShotCam` render step on the client that sets the camera
  every frame, then `screen_capture`; a capture of an open Frame screen needs nothing more. Edit
  captures can be as small as 270 by 151. Captures leave out AlwaysOnTop billboards and CoreGui.
* `user_mouse_input` x and y are measured below the top bar; buttons with unique paths can use
  `instance_path`. `execute_luau` requires its own copy of a module, so call services through dev
  commands. `execute_luau` can answer "Target is not reachable" and still have run: look before
  sending it again. A Luau chunk near 20 KB goes up as a ModuleScript model instead of a paste.
* The project's bible parts are markdown copies of the live doc. After editing the live doc:
  export its tab as markdown with the Docs `export` tool, `python3 tools/bible_parts.py <file>
  "<what changed>"`, Read each part in full, then `project_write` it with `local_path`.

## Small bugs seen, for later prompts

* An undefended Tutorial Surge (a Spitter Grub and two Burrow Ticks) killed four of six founders
  in 90 seconds: two Ticks make a room flee, a latched Tick rides a fleeing resident, everyone
  keeps fleeing (Prompt 12's behaviour). Landon's fix (answer 10): residents swat Burrow Ticks in
  their room even when there are two or more.
* The Command View's condition note (what to do about a fire, a leak) is set in very small type.
* A crystal seam in a fully furnished room sits under the ceiling, across the pipe run.
* Founders idle on floor 1 at the start, so a door leak that starts strong irradiates all six at
  once.
* After SEND, the Expeditions screen switches to ACTIVE even when the server refuses the trip.
* The distress plate's countdown shows --:-- while the clock is paused (dev only).
* The "you're out" telegram says "back at the Medbay" even when the respawn is at the Blast Door.
* The dodge roll leaves the floor for a moment.
* A melee weapon held with an empty hotbar hangs into the floor.
* The A0 sample scripts print a line on every monster swing; remove them once Landon approves
  the monsters.
* Small monster rigs can't walk the Shaft's ramp: the stuck rule steps them to the top.
* The HUD's input hints flip between Gamepad and Keyboard in Studio when the mouse moves (a
  controller is plugged in on Landon's PC).
* The lobby: the Loadout a pad opens stays open if the server moves the player off the pad.
* The lobby is about 330,000 triangles, over the bible's 150,000 for phones: measure on a phone
  (Prompt 34) before cutting anything. The new city must plan for this from the start.
