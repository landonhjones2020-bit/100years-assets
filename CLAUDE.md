# Runbook for Claude sessions: 100 Years Below (art and game code)

The game is **100 Years Below** (Landon renamed it on 2026-11-09; it was 100 Years Of Fallout).
The game bible (claude.ai Project "100 Years Of Fallout", docs
`claude/100-years-of-fallout-game-bible-part-1.md` and `part-2.md`, master copy in the live
Claude Doc) wins over everything here. Section 19 is the art pipeline, Section 24 the
build order. Read `BUILD_LOG.md` first: it says what's done, what's open and every id.

## 1. Start of every session (the workspace is wiped between sessions)

```bash
pip install --break-system-packages bpy==5.2.3      # Blender 5.2.3 LTS, about 400 MB, can take 10+ minutes
python3 -c "import bpy; print(bpy.app.version_string)"
```
Start the install in the background and do other work while it downloads.

## 2. Fixed facts

| Thing | Value |
|---|---|
| Experience | universe 10775267993, owned by user 9768530298 (IHateTheLogInPuzzles) |
| Places | Lobby (start place) 135073046693952; Run 72892455946761. Find their `studio_id` with `list_roblox_studios` (names "100 Years Of Fallout" and "run") |
| Upload creator | `{"creator": {"userId": "9768530298"}}`: everything is uploaded under the game's owner, or animations won't play |
| Import folder (Landon's PC) | `C:\Users\lando\OneDrive\Documentos\100Years-Import`, connected to the Claude desktop app and approved in Studio's Assistant Settings → MCP Permissions |
| Palette images | colour `rbxassetid://131636360909441`, metalness `rbxassetid://92929300444943`, roughness `rbxassetid://133306500207344` (also attributes on `ServerStorage.Assets` in Run) |
| Asset folders (Run and Lobby) | `ServerStorage.Assets.Pipeline` (landing zone) → `ServerStorage.Assets.<Category>`. The Lobby place has `Assets.Lobby` and `Assets.Town` |
| Developer products | Class Shop Reroll 3730189637 (99 Robux). New ones: `POST /developer-products/v2/universes/10775267993/developer-products` (multipart: name, description, isForSale, price, `imageFile`; scope `developer-product:write`) |

## 3. Making an asset

1. Write `generators/<Category>/<Asset>.py` with `steadfast` (see `Prop_SupplyCrate.py`), following `STYLE.md`.
2. Run it, look at `previews/<Category>/<Asset>.png`, fix and repeat until it reads at phone size, sits on the palette and fits its budget.
3. `SF_EXPORT=1 python3 generators/<Category>/<Asset>.py`, then commit and push. Nothing waits for approval (bible Section 19, step 6).

Monsters and bosses: `generators/Monsters/_beast.py` (a `Beast` rig plus detail helpers: spike,
claw, limb, blob, shell, eye, teeth, vein); bosses live in `generators/Bosses/` (the Brood
Mother also renders `<Asset>_hero.png`, a resident's-eye view). `SF_NOSHEETS=1` skips the clip
contact sheets while iterating. A monster uses most of its 4,000 triangles (Landon sent the Ash
Raider back at 1,500: `Monster_AshRaider.py` is the bar for a human enemy). A held weapon that
must be aimed gets its own bone, jointed at the grip (fixed to a forearm it points wherever the
arm does); solve two-handed poses instead of guessing angles. Give a rig an Idle clip: an attack
plays over it (NPCAnimator), so the monster keeps its stance between attacks. A model's `Rig`
attribute in play is its monster type (`Config.Monsters` key), so clips are keyed by that.
A model's pivot is the bottom centre of its bounds; one with parts meant to stay under the floor
(The Deluge's coil and tail) passes `pivot=(0, 0, 0)` to `B.run` (2026-11-11). `_beast.web` makes
fins and frills between two polylines; `_beast.shard` and `cluster` make crystal, `Beast.neon` a
glowing part on a bone. A `transparency` part previews opaque. Studio's importer drops geometry
with no area: end a spike in a small flat tip (`shard(..., tip=0.12)`) and a `web`'s two polylines
on different points, or the part comes in smaller than its sidecar and setup refuses it (2026-11-11).
Never run two preview renders at once into the same `previews/<Category>` folder. Re-exporting a model that is already in `manifest.csv` resets
its `status` to `exported`: put the real status back before committing.

Buildings, streets and rooms seen from inside (the town, the lobby): `generators/Town/townkit.py`.
A `Kit` collects boxes, prisms, lathes, lettering (`text`, fonts in `generators/Town/fonts/`) and
wall `Face`s and merges them into a few MeshParts per material with no collision; what players
bump into is `k.collider(...)` boxes and its lamps are `k.light(...)`, both in the sidecar
(`meta.colliders`, `meta.lights`), built in Studio by AssetSetup. `T.run(build, asset, category,
budget=...)` is the entry: `SF_FAST=1` renders small and rough, `SF_VIEW=a,b` only those views,
`SF_NORENDER=1` none. A merged mesh over 12,000 triangles is cut in pieces (`Decor`, `Decor2`).
`buildings.py` is Main Street's buildings by parameter, `props.py` its furniture and cars,
`generators/Lobby/street_plan.py` where the lobby's blocks stand. Letters cost triangles (about 45
each; `flat=True` for painted lettering). An FBX carries its export time: re-exporting an
unchanged model gives a new hash, so don't re-export what is already uploaded.

Class looks: `generators/Residents/outfits.py` holds every class's outfit (`build`), card pose,
held items (`props`) and framing (`OUTFITS`); `generators/UI/UI_Portraits.py --check <Class>`
writes `previews/Residents/Outfit_<Class>.png` (`SF_SAMPLES=12` for a rough one in 35 s) and
`UI_Portraits.py Portrait_<Class>` renders the card. A class holds its real item: `held_item()`
and `item()` build the game's own model (`generators/Weapons`, `generators/Props`) into the pose.
Place a piece before binding it (`P`, `glow` and `H.prop` parent it to a bone, and a location set
afterwards is in the bone's space: 2026-11-10); keep a held item clear of the face; keep Neon to
small pieces and seams (a wall of it blooms into one blob).

Weapons, tools and devices: `generators/Weapons/_gunkit.py` (the shared pieces, `exports(...)`,
`t(...)` to tag a part). Every long gun's `Support` socket is `_gunkit.SUPPORT` (1 stud ahead of
the `Grip`: R15 arms are short), so one pair of player clips fits them all; those clips are solved
in `generators/Clips/R15_LongGuns.py` (`SF_ONLY=<Clip>`, `SF_GUN=<Module>` for a sheet with a
weapon in hand). `Config.Items.Hold` (TwoHanded, Hip, Heavy) picks the clips. Item icons:
`UI_Portraits.py` `WEAPON_ICONS`, packed at 128 px into the one `items` atlas (`tools/pack_ui.py`).
A setup chunk over about 20 KB: `python3 tools/chunk_module.py <Name> <file.lua>`.

## 4. Importing into Studio (bible Section 19, steps 7 and 8)

1. `python3 tools/stage_import.py exports/<Category>/<Asset>.fbx` prints `stagedPath` / `devicePath` pairs.
   File names carry a content hash. **Never reuse a staged name for new content**: a second
   `device_commit_files` to the same path left the PC with the old file (2026-11-07).
2. `device_commit_files` with those pairs.
3. Upload with `open_cloud_invoke` (scopes `asset:read`, `asset:write`), field `fileContent`:
   * new model: `POST /assets/v1/assets`, body `{"request": {"assetType": "Model", "displayName": "<Asset>", "description": "...", "creationContext": {"creator": {"userId": "9768530298"}}}}`, `contentType` `model/fbx`
   * changed model that already has an id in `manifest.csv`: `PATCH /assets/v1/assets/<id>` with `{"request": {"assetId": "<id>", "assetType": "Model", "creationContext": {...}}}` and the new file. This makes a new version and keeps the id. Identical content makes no new version.
   * clip: `POST`, `assetType` `Animation`, the `.rbxmx`, `contentType` `model/x-rbxm` (a new id per revision)
   * image (icons, UI kit): `POST`, `assetType` `Decal`, `image/png`. The response id is the **decal**; get the image id with `InsertService:LoadAsset(decalId)` → the Decal's `Texture`. Decals can't be updated.
4. Poll `GET /assets/v1/operations/<operationId>` until `done`; the response has `assetId`.
5. `insert_asset` with `parentPath` `game.ServerStorage.Assets.Pipeline`. FBX models arrive as packages.
   For a batch, one `execute_luau` (Edit) does it: `InsertService:LoadAsset(id)` returns a Model
   holding the asset's model (no PackageLink); name it and parent it to `Pipeline` (2026-11-10, 27 at once).
6. `python3 tools/setup_code.py <Asset> <assetId>` prints Luau; send it with `execute_luau` (Edit). It checks size and pivot (0.01 studs), removes the PackageLink, sets collision and the palette SurfaceAppearance, writes attributes and sockets, and moves the model to `ServerStorage.Assets.<Category>`. Rigs (`doc.rig`) are refused there; the rig step builds Motor6Ds.
7. Put the id and `status` (`uploaded`, `in_studio`, `verified`, `approved`) in `manifest.csv`, commit, push, add a line to `BUILD_LOG.md`.

Batches: `python3 tools/setup_batch.py Asset=<id> Rig=<id>:rig:face=<imageId>:Walk=<animId> ...`
(monsters: `Monster_X=<id>:rig:Walk=<anim>:Attack=<anim>`; the generator's scalar meta, such as
`hitTime`, becomes a model attribute, `HitTime`). A chunk too big to paste (over about 20 KB):
wrap it as `return function() <chunk> end` in a ModuleScript `.rbxmx`, upload it as a Model,
then `require(InsertService:LoadAsset(id):FindFirstChildWhichIsA("ModuleScript", true))()`
(2026-11-08, `ArtSetupBatch_A4detail`).
prints one chunk that finishes several inserted models at once (static and rigs). It uses
`ServerStorage.ArtPipeline.AssetSetup`; add `--install` in a new place or after editing
`studio/AssetSetup.lua`.

## 4a. The lobby's world (Prompt 21)

`workspace.Lobby` in the Lobby place is built by a script, never by hand:
`python3 tools/lobby_world.py > /tmp/lobby_world.lua`, then
`python3 tools/chunk_module.py LobbyWorld_P21 /tmp/lobby_world.lua`, `device_commit_files`,
`PATCH /assets/v1/assets/104368016773499` (`model/x-rbxm`), and in the Lobby place (Edit):
`return require(game:GetService("InsertService"):LoadAsset(104368016773499):FindFirstChildWhichIsA("ModuleScript", true))()`.
It replaces `workspace.Lobby` (the showroom, pads with their `PadId`, booths and prompts, Main
Street's blocks, the ground, cars, bunting, the town beyond, the invisible `Bounds`, the spawns)
and sets the lighting. Where things stand is `generators/Lobby/street_plan.py` and the plan in
`tools/lobby_world.py` (Blender space; the Luau turns it over: (x, y, z) → (-x, z, y), same yaw).

## 4b. UI kit (bible Section 18, STYLE.md section 3)

1. `python3 generators/UI/UI_Kit.py [Piece ...]` and `python3 generators/UI/UI_Portraits.py`
   render sprites to `ui/sprites/` (class portraits are the resident dressed in its class
   outfit from `generators/Residents/outfits.py`; `UI_Portraits.py --check <Class>` writes a
   review sheet); `python3 tools/pack_ui.py` packs `ui/atlas_*.png` (portraits at 332 by 283,
   three across: `portraits_a` to `_c`), writes
   `ui/kit.json` (keeps ids of unchanged atlases) and `previews/UI/UI_Kit_sheet.jpg`.
2. Upload each changed atlas as a Decal (section 4, step 3), get the image ids with
   `InsertService:LoadAsset`, and put `decalId` and `imageId` in `ui/kit.json`.
   `python3 tools/pack_ui.py --luau` then prints the `UIKit` ModuleScript (`studio/ui/UIKit.lua`).
3. Screens: `python3 tools/ui_luau.py studio/ui/<Screen>.lua` prints the builder plus the
   screen with its sprite table; send it with `execute_luau` (Edit). Wait a few seconds
   before a screenshot: new atlases take 3 to 4 s to load.

## 4c. Game code (bible Sections 23 and 24)

The code lives in `game/` (Rojo naming) and goes into Studio as one Model asset, never by
pasting code through `execute_luau`. Map and rules: `game/docs/ARCHITECTURE.md`; per-prompt
Design Notes and Delivery Reports: `game/reports/`.

1. Edit `game/`, commit (the build label is the commit), then
   `python3 tools/game_sync.py build` → `exports/Code/GameCode.rbxmx` and a staged pair.
2. `device_commit_files`, then `PATCH /assets/v1/assets/95026446991297` (the id is in
   `game/BUILD.json`) with the `.rbxmx`, `contentType` `model/x-rbxm`; poll the operation.
3. Install in each place with one line (`execute_luau`, Edit):
   `return require(game:GetService("ServerStorage").Tooling.CodeInstaller)(95026446991297, "<Lobby|Run>", false)`
   (`python3 tools/game_sync.py install 95026446991297 <Place>` prints it). It refuses if a
   script was edited in Studio since the last install (bring that edit into the repo first)
   and returns StructureCheck and the data tests. `ServerStorage.Tooling.CodeInstaller` is in
   both places; after changing `studio/CodeInstaller.lua`, reinstall it with the Luau from
   `python3 tools/game_sync.py tooling`.
4. Playtest for real (`start_stop_play`, `get_console_output`). Read the console at the start of a
   build's first playtest: a service whose Init fails takes the ones after it down, and the Edit
   install's StructureCheck doesn't run Init (2026-11-11: a dev command registered twice; the
   build now checks for that). In a playtest:
   `ServerScriptService.DevTools.Invoke:Invoke("<command>")` (Server datamodel) and
   `PlayerScripts.DevInvoke:Invoke("<command>")` (Client) run `/dev` commands. `god <s> <player>`
   before spawning monsters by the player; it also stops effects that need damage (a stun). To
   check a short client effect, set a long one by hand and read the client at once: a tool call
   can take longer than 3 seconds. Hold a prompt's key a second and a half longer than it asks.
5. Profiles in Studio use the `PlayerProfiles_Studio` DataStore; `/dev profile`, `profile.raw`,
   `profile.add`, `profile.receipt`, `profile.locktest` test them.
6. Captures: `screen_capture` saves to `/tmp/claude-tool-results/<id>/...jpg`; copy the good ones
   to `previews/Game/`. To point the camera (and the aim, which is the screen centre) at
   something, bind a `ShotCam` render step on the client that sets `workspace.CurrentCamera`;
   unbind it after. Unpowered rooms are dark: to judge art in play, raise the client's
   `Lighting.Ambient` or add a review lamp, and say so in the report. Never teleport a character
   to a spot worked out from another model's position without keeping it inside the cell (a
   character put through a wall falls out of the bunker). `god` can't be shortened: measure damage
   before it. Landon's avatar uses AnimationConstraint joints (`Waist`), not Motor6Ds. A
   controller is plugged in on his PC, so the input type is often Gamepad (D-pad up: a tap
   pings, a hold heals). Review clones in `workspace` must be removed after the capture.
   Captures leave out AlwaysOnTop BillboardGuis and CoreGui. They are scaled down: in Edit as
   small as 270 by 151 (2026-11-10), in a playtest about 554 by 311, so judge art from the
   Blender sheets and play-mode captures. Roblox's purchase prompt is in CoreGui
   (`game.CoreGui.FoundationOverlay...Sheet.Content.Actions.1.BuyButton`, clickable by instance
   path; a Studio purchase is a test purchase).
7. Things put in a room by code: of two prompts on one key Roblox shows the one nearer the middle
   of the screen, so keep a new prompt well clear of any other (the Blast Door's middle has the
   lift's); furniture stands against back walls, so look for clear wall (`DisasterService`'s
   `seamSpot`) instead of a fixed offset. A cave piece changed: re-export, PATCH, then
   `python3 tools/cave_config.py` (it writes `Config/CavePieces.luau`).

## 4e. The intro cutscene (Prompt 22)

The cutscene is data made here. `generators/Cutscene/cutscene_plan.py` is the set's plan (where
the street, the hill, the door and the blast are; the runners; the beats). `Intro_Scene.py` puts
the exported models together in Blender, keys the camera (`SHOTS`: time, position, look-at, field
of view), and:
`python3 generators/Cutscene/Intro_Scene.py` renders `previews/Cutscene/Storyboard.png` (24
frames; `SF_AT=6.5,12` for single frames in `/tmp/cs`), and `--data` writes
`cutscene/IntroPath.luau`; `python3 tools/cutscene_config.py` copies it to
`game/shared/Config/CutscenePaths.luau` (never edit that by hand). Then the usual code build.
Words and lighting: `game/shared/Config/Cutscenes.luau`. Blender set space to the game:
(x, y, z) → (-x, z, y) from `Tuning.Cutscene.SetOrigin`; the plunge's shots are in the bunker's
space (`Grid.CellPosition(1, 0)`), whose rock stands 19.2 studs out from the grid's plane. The set's
models (`ServerStorage.Assets.Lobby`, `.Town`, `.Cutscene` in the Run place) are put together by
`CutsceneService` from that data: a new piece needs only its row in the plan and its model set up.
In a playtest `cutscene.at <seconds>` (client DevInvoke) holds a moment for a capture.
A part the game moves or scales keeps its own name through `part=` and `role=` (the door's leaves,
the cloud's parts, the eyes); a part of flat lettering alone fails the size check (give it depth).
A clip must be loaded after its model is in `workspace`, or it plays with no length for ever.

## 4d. The bible

The master copy is the live Claude Doc (https://claude.ai/artifact/MsqvLxaU96vVv127RyLtVU;
load the docs skill, then `guide`, before any docs call). Landon's answers go into the doc as
small edits marked "(Landon)", by quoting the words to change (`find` targets). Then refresh the
project's two parts: `tools/bible_parts.py` (its docstring has the steps). A report's Bible
Questions stay in the report until Landon answers them.

## 5. Rules

* Never claim a Studio check that didn't happen. Size, pivot and orientation are measured in Studio, not assumed; clips are played in a playtest.
* Previews and contact sheets go in `previews/`; Landon looks at them whenever he likes.
* The style test (A0) gates production: nothing after it until Landon approves the four models, two clips and the UI kit look.
* `ServerStorage.NS_Pipeline` (an empty `Jobs` folder and `MeshCache`) keeps coming back from an outside Night Shift importer plugin that Landon can't remove (2026-11-08: not in Manage Plugins, its file already deleted; a full Studio restart may clear it). Ignore it (his call): StructureCheck only warns, and errors if scripts ever appear inside it. The code installer still deletes it. Never touch the Night Shift studio itself.
* Rigs: never rely on `Model.WorldPivot` after setting `PrimaryPart`; set the root part's `PivotOffset` (BUILD_LOG 2026-11-08).
* `Lighting.Technology` can't be read or set through the connector; ask Landon.
