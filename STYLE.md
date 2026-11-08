# 100 Years Of Fallout: art contract

Every generator follows this file, and the bible (Sections 3, 18 and 19) wins where they
differ. Library: `generators/lib/steadfast.py`. Treat the dimensions as an interface: the
bunker grid, the camera and the gameplay code rely on them.

## 1. Look: Atomic Diorama

**Quality bar (Landon, 2026-11-07):** our biggest competitor is 99 Nights in the Forest
(lobby shots in `reference/99nights/`). Every asset and screen should clearly beat it on
finish: real materials, lighting that sells the room, UI that is ours and not a template.

* **Chunky low-poly, mostly hard-surface**, bevelled edges, slightly exaggerated proportions,
  strong silhouettes that read on a phone. If a 256 px preview is mush, simplify.
* **1950s Americana**: rounded appliances, chrome trim, pastel enamel, riveted steel,
  Bakelite knobs, stencilled crates. Steadfast Shelter Co. made everything in the bunker.
* **Cheerful on top, creeping horror underneath.** Anything the Source has touched glows
  green (`glow` swatch, Neon parts for real light). Spooky and fun, never gory.
* Lighting is Roblox Future: warm interiors, an ashy orange-grey surface, a cold Deep lit by
  crystal. Colours are chosen to survive all three.
* Never ship something that looks like a default primitive. Add the one or two features
  that make it recognisable (a rim, a rivet row, a handle, a label plate).
* Nothing from Fallout: no vault-door gears with numbers, no blue-and-yellow jumpsuits, no
  thumbs-up mascot (bible Section 3 has the full list).
* **Rarity shows in the look (Landon, 2026-11-08; bible Section 19).** The rarer the
  character, the more creative it gets, and nothing rare is ever a recolour. Common: a
  clean work outfit. Rare: its own outfit, one signature piece (a hat, tool or pack) and an
  accent colour. Epic: a new silhouette (a coat, armour or harness), two or more signature
  pieces, brass or chrome detailing and a small effect. Legendary: one of a kind, with a
  silhouette nothing else has, a hand-made head or hair, glowing or moving parts and its
  own idle. Applies to residents, every Legend, class outfits and cards, and cosmetics.
  The four A0 classes in `generators/Residents/outfits.py` set the bar for each tier;
  check a new look with `python3 generators/UI/UI_Portraits.py --check <Class>`.

## 2. Palette

* Colour comes **only** from the 32 swatches in `palette/` (`palette_sheet.png` shows them).
  `sf.tag(obj, "Part", "teal")` sets every face; `sf.paint(obj, "cream", where)` overrides
  chosen faces. Never add another texture to a model.
* Metalness and roughness come from the palette too (chrome, steel, gunmetal, copper and
  brass are metal), so parts stay `SmoothPlastic` unless they must glow (`Neon`) or be
  see-through (`Glass`). Those keep their own MeshPart and take their swatch colour.
* `tint` is transparent: faces on it show the MeshPart's `Color`. Use it for skin, hair and
  anything recoloured at runtime, and pass `tint=` to `tag` for the preview colour.
* Rarity colours (Common grey, Rare blue, Epic purple, Legendary gold) are UI colours,
  not model swatches.
* Changing a swatch: edit `generators/palette/build_palette.py`, rebuild, upload the new
  maps, and update the three `Palette*` attributes on `ServerStorage.Assets`.

## 3. UI: themed, never generic (Landon, 2026-11-07)

Roblox players spot template UI instantly. Every screen must look like it was built for
this game, by Steadfast Shelter Co., in 1958.

* **Materials, not flat boxes.** Panels are enamel-painted steel with chrome bezels and
  rivets; content sits on cream catalog cards and paper forms; buttons are Bakelite or
  enamel push-buttons with real pressed states; tabs are stamped metal plates.
* **Instruments, not bars.** Health, stamina and radiation read as gauges or tube meters,
  the year as a mechanical flip counter, Disturbance as the seismograph, votes as a
  telegram or ticker strip.
* **Period type.** Titles in a 1950s display face, logs and radio in a typewriter face,
  numbers and small text in a clean readable face, all chosen in the UI style test from
  Roblox's font library. Text never drops below 12 px on phones. No Fredoka One: it is the
  default simulator look.
* **Our own icons**, rendered from the real models (bible Section 18) or drawn as
  Steadfast stamps and stencils. No emoji, no stock icon packs.
* **Mechanical motion.** Drawers slide, buttons depress, counters flip, needles swing,
  stamps thump. No generic pop-and-bounce on everything.
* **Banned**: a plain rounded rectangle with a flat fill and drop shadow as a panel,
  glossy bubble buttons, gradient-on-everything buttons, neon outlines, a bare "X" close
  button, default Gotham or Builder Sans titles.
* The kit is made in this pipeline (rendered in Blender, so bevels, rivets and chrome are
  real) and exported as 9-slice PNGs to `ui/`: panels, button states, tabs, card frames per
  rarity, gauge faces and needles, ticker strips, stamps, Digby stickers.
* The Frame's zones and every AutoScale Lite rule in bible Section 18 stay exactly as they
  are; the kit only skins them.
* The kit's look is approved in the A0 style test, with the models and clips.

**How the kit is made** (A0, 2026-11-08)

* `generators/UI/UI_Kit.py` builds every piece as real geometry and renders it straight
  down in Cycles: soft sun from the upper left, a dark studio ceiling so enamel keeps its
  true colour, soft boxes so chrome shows bright lines and dark bands, shadows caught in
  the PNG's alpha. Flat print (dial faces, seismograph paper, sunbursts, stamps, gauge
  glass) is drawn with PIL in `uiprint.py`. Portraits and item icons come from the real
  models (`UI_Portraits.py`).
* Sprites are drawn at **2x their 1080p size** into `ui/sprites/`, then
  `tools/pack_ui.py` packs them into 1024 px atlases (`ui/atlas_*.png`, 4 px gutters) and
  writes `ui/kit.json`: atlas, rect, 9-slice margins, uploaded image ids. 9-slice works
  straight from an atlas rect; `SliceScale` = 0.5 x screen height / 1080 (the
  `SliceScaler` script keeps it right).
* Icons that tabs tint (`Icon_Tag`, `Icon_Check`, `Icon_Grid`) are white enamel, coloured
  with `ImageColor3`.
* Gauge needles point up at Rotation 0; the sweep runs from -135 (empty) to +135 (full).
* Type (proposed in A0): **Oswald** for titles, plates and labels; **Special Elite** for
  anything typed (logs, telegrams, bylines); **Roboto Condensed** for numbers and body
  text. The same font files are in `ui/fonts/` (OFL/Apache) for baked text.
* Rarity enamels (proposed in A0): Common #8E8C88, Rare #3F79B5, Epic #7D4C9E,
  Legendary #D9A93A.
* In Luau: set `TextWrapped` before `TextScaled` (setting it after turns scaling off), and
  give lines that sit together the same box height so they scale to the same size.

## 4. Technical rules

* 1 Blender unit = 1 stud. Z up. **Front faces Blender −Y** (lands on Roblox −Z).
  Pivot = bottom-centre unless the object hinges (doors, lids: `pivot=` at the hinge line).
* Asset names `Category_Name` or `Category_Name_Variant`, PascalCase. Categories so far:
  `Prop`, `Room`, `Kit` (bunker kit), `Weapon`, `Tool`, `Monster`, `Boss`, `Resident`,
  `Surface`, `Cave`, `Lobby`, `Cutscene`, `Digby`, `Cosmetic`, `UI`.
* Part names unique per asset. Parts that code must find get `role=` (they stay separate
  MeshParts); everything else that shares settings is merged into one MeshPart on export.
* Collision (`collision=`): `none` for decoration (collision and queries off), `query` for
  rig body parts and held items (no collision, but raycasts hit them), `box` for props,
  `hull` for large pieces, `precise` only where players walk.
* Rigs: one MeshPart per bone, named for the bone; parts that ride on a bone (glow, hair)
  are separate parts with `bone=` and get welded to it. `AssetSetup.rig` builds the
  HumanoidRootPart, Motor6Ds named for the clips, the Humanoid and the face decal.
* Gameplay points are sockets (`export_asset(..., sockets={...})`); Studio stores them as
  `Socket_<Name>` CFrame attributes on the Model, relative to its pivot.
* Triangle budgets (bible Section 19; `budget=` makes the export fail when over):

| Asset | Budget |
|---|---|
| Small prop | 300 |
| Medium prop | 800 |
| Room shell per cell (walls, floor, ceiling) | 2,000 |
| Room furniture per cell | 3,000 |
| Weapon | 1,500 |
| Resident | 2,500 |
| Monster | 4,000 |
| Surface building | 6,000 |
| Cave piece | 8,000 |
| Boss | 15,000 |

Phones should see no more than about 150,000 triangles at once.

## 5. Dimensions (bible Section 6; provisional until the bunker kit, A1)

| Thing | Studs |
|---|---|
| Bunker cell, inside | 32 wide × 16 tall × 32 deep |
| Slab between floors | 2 |
| Player avatar (R15) | about 5 tall |
| Doorway between rooms | proposed 8 wide × 10 tall, fixed in A1 |
| Supply crate (`Prop_SupplyCrate`) | 4.2 × 2.65 × 2.75 |

## 6. Review loop (every asset)

1. Run the generator and look at the preview (two angles plus a 1-stud cube).
2. Recognisable at phone size? Chunky, bevelled, on-palette, inside budget, front at −Y,
   pivot right? Fix and re-render until yes.
3. Export, commit, import (CLAUDE.md section 4), then look at it in Studio too.
