# BUILD LOG: 100 Years Of Fallout art

Newest first. Every "verified" line says how it was checked.

## Status

| Step | State | Verified how |
|---|---|---|
| Setup: workspace, repo, places, import folder, uploads | ✅ done 2026-11-07 | See the session below: every link of the pipeline was run once for real |
| A0 style test (4 models, 2 clips, UI kit look) | ⏳ next | Gates everything else (bible Section 19) |
| A1 to A11 | not started | |

## Ids

| What | Id |
|---|---|
| Universe | 10775267993 (owner: user 9768530298) |
| Lobby place (start) | 135073046693952 |
| Run place | 72892455946761 |
| Palette colour | decal 117311354483821, image 131636360909441 |
| Palette metalness | decal 110154044758914, image 92929300444943 |
| Palette roughness | decal 137250713243017, image 133306500207344 |
| Prop_SupplyCrate | model 126356214563544 (version 2 is the right scale) |
| R15_TestWave | animation 106072736219880 |
| Unused | model 131439621755660: a duplicate crate upload at 100x scale, left in Landon's inventory |

## Session 2026-11-07: setup

**Done**
* Workspace: `bpy` 5.2.3 (Blender 5.2.3 LTS) on Python 3.13. Verified: a cube exported to
  FBX and rendered with Cycles, then the crate's preview rendered with the palette.
* Repo `landonhjones2020-bit/100years-assets` (private) created by Landon, attached with
  push access, scaffolded per bible Section 19.
* Experience created by Landon under his own account: Lobby (start place) and Run, both
  open in Studio. Studio access to API services turned on by Landon (not tested yet;
  first used by Prompt 2).
* Import folder `C:\Users\lando\OneDrive\Documentos\100Years-Import` connected to the
  Claude desktop app and approved in Studio's MCP Permissions. Verified: five uploads
  from it succeeded.
* Palette v0 (32 swatches) built and uploaded: colour, metalness and roughness maps. Ids
  are attributes on `ServerStorage.Assets` in Run.
* `Prop_SupplyCrate` generated, uploaded, inserted and set up with `studio/AssetSetup.lua`;
  it sits in `ServerStorage.Assets.Props`.
* `R15_TestWave` written as a KeyframeSequence by Python, uploaded as an Animation.

**Findings (all verified in Studio unless marked)**
1. **Scale.** Roblox reads one raw FBX unit as one stud; Blender writes centimetres. The
   first upload came in 100x too big (423 × 265 × 274.5). With `global_scale = 0.01` the
   crate measures exactly 4.233 × 2.650 × 2.745, matching the export.
2. **Orientation.** `axis_forward="Z"`, `axis_up="Y"` puts the front on −Z. Verified by
   raycasts: the front emblem was hit at z = −1.372 (expected −1.373), the back at +1.263.
3. **Pivot.** The FBX origin becomes the Model's `WorldPivot`: the crate's part sat at
   (0, 1.325, 0) from it, the sidecar's offset. Bottom-centre pivots survive the trip.
4. **Packages.** FBX models arrive as packages (`PackageLink`); AssetSetup removes it.
5. **Stable model ids.** `PATCH /assets/v1/assets/<id>` with a changed FBX made version 2
   of the same asset. A PATCH with identical content makes no new version.
6. **Stale files.** A second `device_commit_files` to an already-used staged path reported
   success but left the PC with the old file. `tools/stage_import.py` now names every
   staged file with its content hash.
7. **Images.** A Decal upload returns the decal id; `InsertService:LoadAsset(decalId)`
   gives the image id (the Decal's `Texture`).
8. **Palette rendering.** Both `TextureID` and a `SurfaceAppearance` (colour, metalness,
   roughness maps) can be set through the connector and show the right swatches (no
   flipped or shifted UVs, no visible bleeding at swatch borders close up). Standard:
   SurfaceAppearance with AlphaMode Overlay. Screenshot: `previews/Pipeline/`.
9. **Clips.** The Python-written `.rbxmx` uploaded as an Animation and played on an R15
   avatar in a Run playtest: length 2.00, looped, right shoulder at 2.60 rad at t = 0.4 as
   keyed, elbow swinging between keys. Screenshot: `previews/Pipeline/studio_testwave_playtest.jpg`.
10. **Metadata PATCH** (`?updateMask=displayName,description`, no file) returned 404
    through the connector, so the 100x duplicate couldn't be renamed.
11. **Night Shift's importer plugin** creates `ServerStorage.NS_Pipeline` in every place
    Studio opens. Removed from Run; Landon can disable the plugin while on this game.

**Not verified yet (A0 covers them)**
* `tint` faces showing `MeshPart.Color` through AlphaMode Overlay on a real tinted mesh.
* Segmented rigs: Motor6Ds built from the sidecar's joints, and Blender-rig clips
  (`export_clips`) playing on them.
* Icons and UI kit textures through the pipeline; anything in the Lobby place.

**Decisions**
* SurfaceAppearance with the palette maps is the standard material for every model.
* Models keep their asset id across revisions (PATCH); clips and images get a new id per
  revision, and `manifest.csv` holds the current one.
* UI must be themed to the game, never generic Roblox UI (Landon). Rules in `STYLE.md`
  section 3; the kit's look joins the A0 style test.
