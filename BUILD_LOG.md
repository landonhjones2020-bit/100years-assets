# BUILD LOG: 100 Years Of Fallout art

Newest first. Every "verified" line says how it was checked.

## Status

| Step | State | Verified how |
|---|---|---|
| Setup: workspace, repo, places, import folder, uploads | ✅ done 2026-11-07 | See the session below: every link of the pipeline was run once for real |
| A0 style test (4 models, 2 clips, UI kit look) | ✅ approved by Landon 2026-11-08 | Revolver grip fixed after his note (v2, revision 2) |
| Class looks by rarity (Landon's rule, bible Section 19) | ✅ first four done 2026-11-08 | Portraits rendered from the rig, Class Shop checked in Studio |
| Prompt 0: architecture foundation (both places) | ✅ done 2026-11-08 | Playtests in Run and Lobby; `game/reports/P00_Architecture.md` |
| A1 bunker kit and starting rooms | ⏳ next | |
| A2 to A11 | not started | |

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
| Game code (Model, a version per build) | 95026446991297 (`game/BUILD.json`) |
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

## 2026-11-08 (evening): A0 approved, revolver v2, class looks by rarity

Landon approved the A0 style test ("I love the style") with one fix: the revolver's handle.
He also set a rule for every character: the rarer it is, the more creative its look
(bible Section 19, "Rarity shows in the look").

| Asset | Id | Status | Notes |
|---|---|---|---|
| Weapon_ServiceRevolver v2 | 86157197359329 (revision 2) | verified | 1,308 tris (1,500); size 0.52 × 1.49 × 2.271 checked in Studio; back on the showroom table |
| UI atlas: kit_a | decal 128192097302269, image 85214114089895 | verified | new revolver icon (`previews/A0/Studio_Revolver_v2.jpg`) |
| UI atlas: portraits | decal 96645914120696, image 120657029267813 | verified | class outfits; the five Class Shop images repointed |

**Done**
* Revolver: the forward-raked box grip is now a raked walnut grip in a gunmetal frame with
  brass medallions, steel screws and a lanyard ring, PATCHed as revision 2 of the same
  model (id unchanged).
* Bible (live doc rev 95, Project part 2): A0 approved, the three fonts, the rarity enamels,
  the class card, the rarity rule, and the Section 24 note.
* `generators/Residents/outfits.py`: class outfits built on the resident rig, bound to its
  bones. Security (Common): padded vest, soft cap, brass star. Quartermaster (Rare): canvas
  apron, flat cap, the supply pack (crate, bedroll, lantern), hazard-yellow accents, the
  requisition clipboard. Warden (Epic): caped greatcoat with a high collar, peaked cap,
  fringed epaulettes, the Rally Call megaphone, a glowing Steadfast Star. Mad Scientist
  (Legendary): wild hand-made hair and moustache, glowing goggles, a brass mechanical arm
  with a claw, the Gadget Belt, a Glowshard reactor pack with a sparking Tesla coil, a
  boiling flask. Held props are card-only (in a run the hands hold the player's tools);
  `Body.reach` bends an arm so a hand lands on a target.
* `generators/UI/UI_Portraits.py` dresses, poses and renders each class with bloom on Neon;
  `--check` writes review sheets (`previews/Residents/Outfit_<Class>.png`: card view,
  front, back). Class Shop in Studio: `previews/UI/Studio_ClassShop_Outfits.jpg`.
* `Resident_Common.py` marks its chest details (`sf_detail = "chest"`) so a vest or coat
  can remove them; the exported model is unchanged.
* `AssetSetup` now lives in `ServerStorage.ArtPipeline.AssetSetup` in Run;
  `tools/setup_batch.py --install` reinstalls it.
* `manifest.csv`: A0 rows `approved`, except the revolver and kit_a (`verified`: Landon
  hasn't seen v2 yet). The file is LF now, as `steadfast.manifest_upsert` writes it.

**Findings**
1. Blender 5.2 compositing: a `CompositorNodeTree` node group on
   `scene.compositing_node_group`, ending in a Group Output (the Composite node is gone).
   The Glare node's `Glare` output is the halo alone, so it can be added to the render and
   written into alpha; the halo then shows on the card behind the transparent sprite.
2. Bloom also caught specular highlights on brass under the rim light. Threshold 2.0 with
   Neon emission 8 keeps it on the Neon parts.
3. `ServerStorage.NS_Pipeline` showed up in Run again; deleted (third time).

**Open**
* Landon hasn't seen the class looks yet; any of them can change.
* The outfits exist as portraits only. In game they become cosmetic accessories on the
  player's own avatar (A11), and the other 15 classes need theirs.

## 2026-11-08: A0 style test built and in Studio (waiting for Landon's approval)

Everything below is in Run (studio "run", place 72892455946761). Nothing after A0 starts
until Landon approves the four models, two clips and the UI kit look (bible Section 19).

| Asset | Asset id | Status | Notes |
|---|---|---|---|
| Room_Kitchen_L1 | 96540501294464 | verified | 13 MeshParts, 2,992 tris (budget 3,000); `ServerStorage.Assets.Rooms` |
| Kit_CellShell | 134174776264272 | verified | 7 MeshParts, 1,636 tris (2,000); `ServerStorage.Assets.Kit` |
| Weapon_ServiceRevolver | 86157197359329 | verified | 796 tris (1,500); Grip and Muzzle sockets; `ServerStorage.Assets.Weapons` |
| Resident_Common | 118658215913755 | verified | 16 MeshParts, 2,268 tris (2,500); 15 Motor6Ds, hair welded; face decal |
| Monster_HollowMiner | 83503998043819 | verified | 15 MeshParts, 2,142 tris (4,000); 11 Motor6Ds, 4 glow parts welded |
| R15_ResidentWalk (clip) | 125264708961546 | verified | 1.00 s loop, Movement priority |
| HollowMiner_Attack (clip) | 99038102545112 | verified | 1.47 s, Action priority, `Hit` marker at 0.7 s |
| Face_Resident_Smile | decal 87390877749448, image 103176016141485 | in_studio | on Resident_Common's Head (front) |
| UI atlas: cards | decal 110523717816719, image 75110860144472 | verified | `ui/atlas_cards.png` |
| UI atlas: kit_a | decal 86421992183940, image 74779239339407 | verified | `ui/atlas_kit_a.png` |
| UI atlas: kit_b | decal 125432561809946, image 102495471404574 | verified | `ui/atlas_kit_b.png` |
| UI atlas: portraits | decal 112354578662230, image 76558516830406 | verified | `ui/atlas_portraits.png` |

In Studio:
* `ServerStorage.Assets.<Category>`: the five models, finished by `AssetSetup` (static) and
  `AssetSetup.rig` (rigs). Every MeshPart passed the size and offset check (0.01 studs).
* `Workspace.A0_Showroom`: the kitchen in a cell (front wall removed for the camera), a
  walking resident, a cook at the stove, the Hollow Miner at the side door, the revolver on
  the table, PointLights at the Light sockets.
* `ServerScriptService.A0_ShowroomAnimations`: plays Walk and Attack on the showroom NPCs
  in a playtest (ids from the models' `Anim_<Clip>` attributes).
* `StarterGui.A0_HUD` (enabled) and `StarterGui.A0_ClassShop` (disabled): toggle `Enabled`
  to look at either. Both carry `SliceScaler` and `KitButtons` LocalScripts.
* Screenshots: `previews/A0/` (Studio) and `previews/UI/UI_Kit_sheet.jpg` (every kit piece).

**Findings (verified in Studio)**
1. **Rig pivot.** Setting `Model.PrimaryPart` moved the model's pivot to the root part's
   centre, and assigning `Model.WorldPivot` afterwards did not move it back, so both rigs
   were stored 3 studs low and sank into the floor. Fix (in `AssetSetup.rig`): set
   `root.PivotOffset = root.CFrame:ToObjectSpace(feetPivot)`. Both stored rigs repaired.
2. **Custom-rig clips upload and play.** The Python-written KeyframeSequence for the Hollow
   Miner (custom joint names) uploaded as an Animation and drove all 11 Motor6Ds in a
   playtest; the `Hit` marker fired on every swing. The bible's fallback (Studio-built
   clips) is not needed.
3. **Server NPC animation** replicates to the client; the play-mode `screen_capture` shows
   the client. A freeze (`TimePosition`, `AdjustSpeed(0)`) catches a pose for screenshots.
4. **9-slice from an atlas works:** `ScaleType.Slice` with `ImageRectOffset/Size` slices the
   sub-rect (`SliceCenter` is relative to the rect). `ScaleType.Tile` tiles a sub-rect too.
5. **TextScaled is linked to TextWrapped:** setting `TextWrapped = false` after
   `TextScaled = true` turned scaling off (every label rendered at size 8). Set TextWrapped
   first, TextScaled last.
6. **First image load** in Studio took 3 to 4 s per new atlas; a screenshot straight after
   building shows the UI without images.
7. **Lighting.Technology** can't be read or set through the connector (needs RobloxScript
   capability). The showroom shots look right as the place is set; Landon can switch it
   to Future in the Lighting properties if it isn't already.
8. Night Shift's importer plugin recreated `ServerStorage.NS_Pipeline` twice today; deleted
   both times.

**Not verified yet**
* The AutoScale Lite pass (Landon) and the Device Emulator check on a phone, a tablet, a
  1080p monitor and a 4K TV (bible Section 18 rules 8 and 9). The sample was built
  Scale-only with aspect constraints, but only seen at 1919 x 1079.
* `KitButtons` pressed states and the `SliceScaler` at other screen sizes (written, not
  exercised in play).
* Touch buttons (bottom right on touch) aren't in the sample.
* `Lighting.Technology` (see finding 7).

**Proposed for approval (bible Section 18 leaves these to the style test)**
* Type: Oswald (titles, plates, labels), Special Elite (typed text: logs, telegrams,
  bylines), Roboto Condensed (numbers and body). All three are Roblox font families, and
  the same files are in `ui/fonts/` so baked stamps match live text. No Fredoka One.
* Rarity enamels: Common #8E8C88, Rare #3F79B5, Epic #7D4C9E, Legendary #D9A93A.
* Class cards: catalog card with a chrome rim, a sunburst window in the rarity colour, a
  rarity tag on the window edge, a pilot lamp for the selected card.
