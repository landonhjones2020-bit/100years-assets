# 100years-assets

Art for **100 Years Of Fallout** (working title), the Roblox co-op bunker game. Every
model, clip, icon and UI texture here is made by a Python generator running Blender
headless, then uploaded to Roblox and set up in Studio by Claude (bible Section 19).
Generated files are committed; Blender files are not, because the generators rebuild them.

## Pinned versions

| What | Version | How it's installed |
|---|---|---|
| Blender | **5.2.3 LTS**, as the `bpy` module | `pip install --break-system-packages bpy==5.2.3` (Python 3.13) |
| Pillow | any recent | already in the workspace (`pip install pillow` if not) |

## Export settings (pinned by the pipeline test, see BUILD_LOG.md)

| Setting | Value | Why |
|---|---|---|
| Units | 1 Blender unit = 1 stud | Roblox reads one raw FBX unit as one stud. Blender writes centimetres, so the FBX `global_scale` is **0.01** |
| Axes | `axis_forward="Z"`, `axis_up="Y"` | the asset's front (Blender −Y) lands on Roblox −Z, `CFrame.LookVector` |
| Pivot | bottom-centre of the bounds, unless a generator passes `pivot=` | the FBX origin becomes the Model's `WorldPivot` |
| Colour | UVs on the centres of `palette/palette.png` swatches, one `Palette` material | one shared texture set for the whole game |
| Faces | triangulated, smoothing per part (`smooth_angle`) | |
| Names | `Category_Name` or `Category_Name_Variant` | MeshPart names come from the Blender object names |

## Running a generator

```bash
python3 generators/Props/Prop_SupplyCrate.py                 # preview only -> previews/Props/
SF_EXPORT=1 python3 generators/Props/Prop_SupplyCrate.py     # also exports/Props/*.fbx + .json and manifest.csv
SF_NORENDER=1 SF_EXPORT=1 python3 generators/Props/...       # export without rendering
python3 generators/palette/build_palette.py                  # rebuild the palette files
python3 tools/fbx_inspect.py exports/Props/Prop_SupplyCrate.fbx   # what the FBX really contains
```

## Layout

| Path | What goes there |
|---|---|
| `CLAUDE.md` | The runbook a Claude session follows: setup, export, import into Studio |
| `STYLE.md` | Look, palette rules, UI theme rules, dimensions and budgets: the art contract |
| `BUILD_LOG.md` | Status, ids, findings and what's still unverified, newest first |
| `manifest.csv` | One row per asset: category, kind, art step, size, budget, triangles, swatches, status, Roblox asset id |
| `palette/` | The 32-swatch palette: colour, metalness and roughness maps, `palette.json`, a labelled sheet |
| `generators/lib/steadfast.py` | Shared library: primitives, tagging, export, previews, rigs, clips, KeyframeSequence writer |
| `generators/<Category>/` | One script per asset, kit, clip or icon set |
| `exports/<Category>/` | FBX models plus a JSON sidecar each (collision, materials, roles, sockets, rig joints) |
| `animations/<Rig>/` | Each clip's keys (JSON) and its KeyframeSequence (.rbxmx) |
| `previews/<Category>/` | Rendered previews to check any time; `previews/Pipeline/` has the Studio test shots |
| `icons/`, `ui/` | Item icons and the themed UI kit, as PNGs |
| `cutscene/` | The intro camera path as a Luau data module |
| `studio/AssetSetup.lua` | Finishes an inserted model in Studio: checks, collision, palette, attributes, folder |
| `tools/` | `stage_import.py` (copy files for the import folder), `setup_code.py` (Luau for AssetSetup), `fbx_inspect.py` |

## The pipeline in one line

Generator → `exports/` → commit → copy to the import folder on Landon's PC
(`C:\Users\lando\OneDrive\Documentos\100Years-Import`) → upload with Open Cloud through
the Studio connector → insert into `ServerStorage.Assets.Pipeline` → `AssetSetup` moves it
to `ServerStorage.Assets.<Category>` → asset id into `manifest.csv`. Details in `CLAUDE.md`.

Nothing secret belongs in this repo. Game code lives in the place, not here.
