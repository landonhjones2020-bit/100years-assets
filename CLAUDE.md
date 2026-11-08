# Runbook for Claude sessions: 100 Years Of Fallout art

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
| Asset folders in Run | `ServerStorage.Assets.Pipeline` (landing zone) → `ServerStorage.Assets.<Category>` |

## 3. Making an asset

1. Write `generators/<Category>/<Asset>.py` with `steadfast` (see `Prop_SupplyCrate.py`), following `STYLE.md`.
2. Run it, look at `previews/<Category>/<Asset>.png`, fix and repeat until it reads at phone size, sits on the palette and fits its budget.
3. `SF_EXPORT=1 python3 generators/<Category>/<Asset>.py`, then commit and push. Nothing waits for approval (bible Section 19, step 6).

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
6. `python3 tools/setup_code.py <Asset> <assetId>` prints Luau; send it with `execute_luau` (Edit). It checks size and pivot (0.01 studs), removes the PackageLink, sets collision and the palette SurfaceAppearance, writes attributes and sockets, and moves the model to `ServerStorage.Assets.<Category>`. Rigs (`doc.rig`) are refused there; the rig step builds Motor6Ds.
7. Put the id and `status` (`uploaded`, `in_studio`, `verified`, `approved`) in `manifest.csv`, commit, push, add a line to `BUILD_LOG.md`.

## 5. Rules

* Never claim a Studio check that didn't happen. Size, pivot and orientation are measured in Studio, not assumed; clips are played in a playtest.
* Previews and contact sheets go in `previews/`; Landon looks at them whenever he likes.
* The style test (A0) gates production: nothing after it until Landon approves the four models, two clips and the UI kit look.
* Keep the Night Shift importer plugin out of this game: it creates `ServerStorage.NS_Pipeline` in every place it sees. Delete that folder if it shows up.
