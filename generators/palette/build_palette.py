"""Builds the shared 32-swatch palette (bible Section 19, Atomic Diorama).

Run:  python3 generators/palette/build_palette.py

Writes to palette/:
  palette.json            swatch list (index, name, hex, metalness, roughness, UV centre)
  palette.png             colour map, 8 x 4 swatches of 64 px (512 x 256). Swatch 31 "tint"
                          is fully transparent, so the MeshPart's own Color shows through
                          (skin, hair and anything recoloured at runtime).
  palette_metalness.png   same layout, greyscale metalness (SurfaceAppearance.MetalnessMap)
  palette_roughness.png   same layout, greyscale roughness (SurfaceAppearance.RoughnessMap)
  palette_sheet.png       labelled sheet for people

Every model's faces point their UVs at the centre of one swatch, so the whole game shares
one tiny texture set and every asset stays on-palette. Change a colour here, rebuild, and
re-upload palette.png: every model updates at once.
"""
from __future__ import annotations

import json
import os

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "palette")
COLS, ROWS, CELL = 8, 4, 64

# (name, hex, metalness, roughness, what it is for). Order = index = layout (row-major).
SWATCHES = [
    # Row 0: Steadfast enamel and brand colours
    ("teal",      "#2F6F73", 0.0, 0.40, "Steadfast Teal: coveralls, signage, room trim"),
    ("mint",      "#8CC2B5", 0.0, 0.40, "pastel enamel: appliances, Medbay"),
    ("cream",     "#F2E6C9", 0.0, 0.50, "walls, panels, paper"),
    ("porcelain", "#F7F5EE", 0.0, 0.30, "white enamel, tiles, the Lab"),
    ("signal",    "#E8743B", 0.0, 0.40, "Signal Orange: buttons, the Blast Door, warning stripes"),
    ("hazard",    "#F2C14E", 0.0, 0.40, "Hazard Yellow: warning paint, lamp shades"),
    ("blush",     "#E8A09A", 0.0, 0.40, "pastel pink enamel: diner, kitchen"),
    ("skyblue",   "#9DC4DB", 0.0, 0.40, "baby blue enamel"),
    # Row 1: metals and paint
    ("chrome",    "#DADFE3", 1.0, 0.18, "chrome trim, appliance handles"),
    ("steel",     "#8D969D", 1.0, 0.38, "steel, pipes, shelving"),
    ("gunmetal",  "#4A5259", 1.0, 0.45, "dark steel, machinery, guns"),
    ("rubber",    "#23262A", 0.0, 0.85, "rubber, tyres, black plastic"),
    ("navy",      "#1B2A3A", 0.0, 0.50, "Deep Navy: dark paint, lettering"),
    ("copper",    "#B8743A", 1.0, 0.35, "copper pipes, copper ore"),
    ("brass",     "#C8A23E", 1.0, 0.30, "brass fittings, gauges"),
    ("olive",     "#5E6A44", 0.0, 0.65, "army paint, military crates"),
    # Row 2: wood, fabric, plants
    ("pine",      "#C49A63", 0.0, 0.75, "timber props, crates"),
    ("walnut",    "#6B4630", 0.0, 0.70, "mid-century furniture"),
    ("leather",   "#8C5B3B", 0.0, 0.60, "leather, belts, Digby's fur"),
    ("rust",      "#B5412B", 0.0, 0.60, "Rust Red: danger, rust, red vinyl"),
    ("plum",      "#6E4766", 0.0, 0.80, "curtains, upholstery accents, odd things from the Deep"),
    ("avocado",   "#8A9A46", 0.0, 0.75, "avocado fabric and appliances"),
    ("leaf",      "#6F9B4C", 0.0, 0.80, "plants"),
    ("forest",    "#3D5C35", 0.0, 0.85, "dark foliage, moss"),
    # Row 3: rock, ash, water, glow
    ("sandstone", "#A39A8C", 0.0, 0.95, "light rock, concrete"),
    ("stone",     "#6F665C", 0.0, 0.95, "rock"),
    ("basalt",    "#403B37", 0.0, 0.95, "deep rock, soot"),
    ("ash",       "#8E8C88", 0.0, 0.90, "surface ash, rubble"),
    ("murk",      "#2D4A57", 0.0, 0.25, "Flooded Caverns water, wet stone"),
    ("crystal",   "#8FE3E0", 0.0, 0.15, "Crystal Hollows crystal"),
    ("glow",      "#7CFF9B", 0.0, 0.30, "Glow Green: anything the Source touched (Neon parts for real glow)"),
    ("tint",      None,      0.0, 0.60, "transparent: shows the MeshPart's Color (skin, hair, runtime recolours)"),
]
assert len(SWATCHES) == COLS * ROWS


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def build() -> dict:
    os.makedirs(OUT, exist_ok=True)
    w, h = COLS * CELL, ROWS * CELL
    color = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    metal = Image.new("L", (w, h), 0)
    rough = Image.new("L", (w, h), 128)
    dc, dm, dr = ImageDraw.Draw(color), ImageDraw.Draw(metal), ImageDraw.Draw(rough)
    swatches = []
    for i, (name, hx, m, r, use) in enumerate(SWATCHES):
        col, row = i % COLS, i // COLS
        box = (col * CELL, row * CELL, (col + 1) * CELL - 1, (row + 1) * CELL - 1)
        if hx is not None:
            dc.rectangle(box, fill=hex_rgb(hx) + (255,))
        dm.rectangle(box, fill=round(m * 255))
        dr.rectangle(box, fill=round(r * 255))
        swatches.append({
            "index": i, "name": name, "hex": hx, "metalness": m, "roughness": r, "use": use,
            # UV origin bottom-left (Blender / FBX). Image row 0 is the top row.
            "uv": [round((col + 0.5) / COLS, 6), round(1 - (row + 0.5) / ROWS, 6)],
        })
    color.save(os.path.join(OUT, "palette.png"))
    metal.save(os.path.join(OUT, "palette_metalness.png"))
    rough.save(os.path.join(OUT, "palette_roughness.png"))
    doc = {"version": 1, "cols": COLS, "rows": ROWS, "cell_px": CELL, "size_px": [w, h],
           "swatches": swatches}
    with open(os.path.join(OUT, "palette.json"), "w") as f:
        json.dump(doc, f, indent=1)
    _sheet(swatches)
    return doc


def _font(size: int):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def _sheet(swatches: list) -> None:
    cw, ch = 200, 150
    img = Image.new("RGB", (COLS * cw, ROWS * ch), (58, 61, 66))
    d = ImageDraw.Draw(img)
    f1, f2 = _font(18), _font(13)
    for s in swatches:
        col, row = s["index"] % COLS, s["index"] // COLS
        x, y = col * cw, row * ch
        if s["hex"]:
            d.rounded_rectangle((x + 8, y + 8, x + cw - 8, y + ch - 44), radius=10, fill=hex_rgb(s["hex"]))
        else:  # tint: checkerboard = transparent
            for cx in range(x + 8, x + cw - 8, 12):
                for cy in range(y + 8, y + ch - 44, 12):
                    shade = 200 if ((cx - x) // 12 + (cy - y) // 12) % 2 else 150
                    d.rectangle((cx, cy, min(cx + 11, x + cw - 9), min(cy + 11, y + ch - 45)), fill=(shade,) * 3)
        tag = " metal" if s["metalness"] > 0.5 else ""
        d.text((x + 10, y + ch - 40), f"{s['index']:>2} {s['name']}", font=f1, fill=(242, 230, 201))
        d.text((x + 10, y + ch - 19), f"{s['hex'] or 'transparent'}  R{s['roughness']:.2f}{tag}", font=f2, fill=(160, 175, 185))
    img.save(os.path.join(OUT, "palette_sheet.png"))


if __name__ == "__main__":
    d = build()
    print(f"palette: {len(d['swatches'])} swatches -> {OUT}")
