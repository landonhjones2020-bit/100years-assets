"""Kit_Rock: rock and dug cells for each depth band (A1; bible Section 6).

    Kit_Rock_<Band>  a whole Rock cell: one faceted block filling the cell's pitch (34 x 18 x 34,
                     the slab under it included). Its front bulges toward the Command View; the
                     sides and underside are seen from dug cells next to and below it.
    Kit_Dug_<Band>   a Dug cell: rough floor, a rock face at the back and the front (FrontWall,
                     hidden in the Command View) and the band's dressing. Its sides and ceiling
                     come from whatever is next to it.

Bands (Section 6): Mines (timber props, lanterns, old carts; iron), Flooded Caverns (dripping
rock, standing water, burst pipes; copper), Crystal Hollows (glowing crystal, radiation),
Source Chamber (a living cavern around the Source; Source green).

Sockets: Kit_Dug_* has Light (where the game hangs a PointLight).

    python3 generators/Kits/Kit_Rock.py              preview of every band (rock, dug, rock)
    SF_EXPORT=1 python3 generators/Kits/Kit_Rock.py  exports all eight
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402
from kitlib import BAND_SWATCHES, D, H, S, T, W, nugget, rock_block, shard, slab, t  # noqa: E402

CATEGORY = "Kit"
BANDS = ("Mines", "FloodedCaverns", "CrystalHollows", "SourceChamber")
SEEDS = {"Mines": 11, "FloodedCaverns": 23, "CrystalHollows": 37, "SourceChamber": 53}
X0, X1 = -W / 2 - T, W / 2 + T
Y0, Y1 = -D / 2 - T, D / 2 + T


def mottle(obj, dark_sw, seed, share=0.3, accent_sw=None, accent_share=0.0):
    """Paint some faces darker (and a few in an accent swatch) so rock isn't one flat colour."""
    rnd = random.Random(seed)
    picks = {}

    def pick(c, n):
        key = (round(c.x, 2), round(c.y, 2), round(c.z, 2))
        if key not in picks:
            r = rnd.random()
            picks[key] = "accent" if r < accent_share else ("dark" if r < accent_share + share else "")
        return picks[key]
    sf.paint(obj, dark_sw, lambda c, n: pick(c, n) == "dark")
    if accent_sw:
        sf.paint(obj, accent_sw, lambda c, n: pick(c, n) == "accent")


def boulder(part, swatch, loc, r, seed):
    o = nugget(part, swatch, loc, r, seed, collision="none")
    return o


def rock(band: str):
    """One Rock cell: a chunky faceted block. Front and back are both detailed (different
    seeds), so the game can turn alternate cells half a turn and the grid doesn't repeat."""
    rock_sw, dark_sw, accent = BAND_SWATCHES[band]
    seed = SEEDS[band]
    rnd = random.Random(seed)
    block = rock_block("Rock", rock_sw, (X0, Y0, -S), (X1, Y1, H), segs=(6, 3, 4), seed=seed, collision="box",
                       jitter={(1, -1): (-1.4, 2.4), (1, 1): (-1.4, 2.4), (0, -1): (-1.0, 0.0), (0, 1): (-1.0, 0.0),
                               (2, -1): (-1.0, 0.0), (2, 1): (-0.4, 0.0)})
    mottle(block, dark_sw, seed, share=0.22)
    ore = {"Mines": "rust", "FloodedCaverns": "copper"}.get(band)
    for side in (-1, 1):       # boulders bulging out of the front and the back, ore in the cracks
        y = Y0 if side < 0 else Y1
        for i in range(2):
            r = rnd.uniform(2.0, 3.0)
            o = boulder("Boulders", rock_sw, (rnd.uniform(-12, 12), y + side * 0.6, rnd.uniform(r - 1.2, 7.0)),
                        r, seed + i + (10 if side > 0 else 0))
            mottle(o, dark_sw, seed + 40 + i, share=0.4)
        if ore:
            for i in range(2):
                nugget("Ore", ore, (rnd.uniform(-14, 14), y + side * 0.9, rnd.uniform(1.0, 14.0)), rnd.uniform(0.45, 0.8),
                       seed + 70 + i + (10 if side > 0 else 0))
        if band == "CrystalHollows":
            for i in range(2):
                shard("Crystals", "crystal", (rnd.uniform(-12, 12), y - side * 0.3, rnd.uniform(3, 13)),
                      rnd.uniform(2.0, 3.2), rnd.uniform(0.45, 0.7), tilt=rnd.uniform(65, 95) * -side,
                      yaw=rnd.uniform(-20, 20), mat="Neon")
        elif band == "SourceChamber":
            for i in range(2):
                z = 3.0 + i * 6.0 + rnd.uniform(-1, 1)
                pts = [(X0 + 1 + j * (X1 - X0 - 2) / 3, y + side * 0.3, z + rnd.uniform(-1.4, 1.4)) for j in range(4)]
                for a, b in zip(pts, pts[1:]):
                    mid = ((a[0] + b[0]) / 2, a[1], (a[2] + b[2]) / 2)
                    ang = math.degrees(math.atan2(b[2] - a[2], b[0] - a[0]))
                    t(sf.box((math.dist(a, b), 0.6, 0.4), loc=mid, rot=(0, -ang, 0), bevel=0.0), "Veins", "glow",
                      mat="Neon", cast_shadow=False)
    return {}


def dug(band: str):
    """One Dug cell: rough floor, rock faces back and front, the band's dressing."""
    rock_sw, dark_sw, accent = BAND_SWATCHES[band]
    seed = SEEDS[band] + 100
    rnd = random.Random(seed)
    slab("Floor", dark_sw, (X0, X1, Y0, Y1), -S, 0.0, collision="box")
    back = rock_block("BackRock", rock_sw, (X0, D / 2, 0.0), (X1, Y1, H), segs=(6, 1, 4),
                      jitter={(1, -1): (0.0, 2.0)}, seed=seed + 1, collision="box")
    mottle(back, dark_sw, seed + 1, share=0.22)
    front = rock_block("FrontWall", rock_sw, (X0, Y0, 0.0), (X1, -D / 2, H), segs=(6, 1, 4),
                       jitter={(1, -1): (-0.2, 1.2), (1, 1): (0.0, 1.0)}, seed=seed + 2, collision="box")
    mottle(front, dark_sw, seed + 2, share=0.22)
    front["sf_role"] = "FrontWall"
    for i in range(5):
        o = nugget("Rubble", rock_sw, (rnd.uniform(-14, 14), rnd.uniform(-12, 12), 0.4), rnd.uniform(0.6, 1.3), seed + 10 + i)
        mottle(o, dark_sw, seed + 60 + i)
    light = (0.0, 6.0, 11.0)
    if band == "Mines":
        # timber props against the back face, an iron-strapped cap beam and a hanging lantern
        for x in (-11.5, 11.5):
            t(sf.box((1.3, 1.3, H - 0.4), loc=(x, 13.2, (H - 0.4) / 2), bevel=0.15, segments=1), "Timber", "pine", collision="box")
            t(sf.box((1.45, 1.45, 0.35), loc=(x, 13.2, H - 2.6), bevel=0.0), "TimberStraps", "gunmetal")
        t(sf.box((25.0, 1.5, 1.3), loc=(0, 13.2, H - 1.0), bevel=0.15, segments=1), "Timber", "pine", collision="box")
        t(sf.cyl(0.05, 2.6, loc=(0, 12.9, H - 2.95), verts=4, bevel=0.0), "Lantern", "rubber")
        t(sf.cyl(0.75, 0.25, loc=(0, 12.9, H - 4.3), verts=8, bevel=0.0), "Lantern", "brass")
        t(sf.cyl(0.75, 0.25, loc=(0, 12.9, H - 6.1), verts=8, bevel=0.0), "Lantern", "brass")
        for a in range(4):
            ang = a * math.pi / 2
            t(sf.box((0.12, 0.12, 1.8), loc=(0.65 * math.cos(ang), 12.9 + 0.65 * math.sin(ang), H - 5.2), bevel=0.0), "Lantern", "brass")
        t(sf.cyl(0.5, 1.6, loc=(0, 12.9, H - 5.2), verts=8, bevel=0.0), "LanternGlow", "cream", mat="Neon", cast_shadow=False)
        light = (0.0, 12.9, H - 5.2)
        # mine rails running the width of the cell (they line up with the next dug cell's), and
        # an old ore cart
        for y in (-5.5, -2.5):
            t(sf.box((W + 2 * T, 0.3, 0.3), loc=(0, y, 0.25), bevel=0.0), "Rail", "gunmetal")
        for x in range(-15, 17, 3):
            t(sf.box((0.8, 4.6, 0.2), loc=(x, -4.0, 0.1), bevel=0.0), "Rail", "walnut")
        t(sf.box((6.4, 4.0, 2.6), loc=(-4.0, -4.0, 2.2), bevel=0.35, segments=1), "Cart", "rust", collision="box")
        t(sf.box((6.6, 4.2, 0.35), loc=(-4.0, -4.0, 3.45), bevel=0.06, segments=1), "Cart", "gunmetal", collision="box")
        for x in (-6.2, -1.8):
            for y in (-5.6, -2.4):
                t(sf.cyl(0.8, 0.35, loc=(x, y, 0.85), rot=(90, 0, 0), verts=8, bevel=0.0), "CartWheels", "gunmetal")
        for i in range(4):
            o = nugget("CartOre", "stone", (-5.6 + i * 1.1, -4.0 + (i % 2) * 0.8, 3.9), 0.85, seed + 30 + i)
            sf.paint(o, "rust", lambda c, n, i=i: i % 2 == 0 and n.z > 0.5)
    elif band == "FloodedCaverns":
        t(sf.box((24.0, 18.0, 0.08), loc=(1.0, -1.0, 0.1), bevel=0.0), "Water", "murk", mat="Glass",
          transparency=0.3, cast_shadow=False)
        t(sf.cyl(0.9, 5.0, loc=(-9.0, 13.2, 12.0), rot=(90, 0, 0), verts=8, bevel=0.0), "Pipe", "copper", collision="box")
        t(sf.torus(0.95, 0.22, loc=(-9.0, 10.8, 12.0), rot=(90, 0, 0), major_segs=8, minor_segs=4), "Pipe", "gunmetal")
        t(sf.box((0.25, 0.25, 1.8), loc=(-9.3, 10.5, 10.4), rot=(0, 25, 0), bevel=0.0), "Pipe", "copper")
        for z in (9.4, 6.6, 3.5):
            t(sf.sphere(0.22, loc=(-9.0, 10.5, z), segs=6, rings=3), "Drips", "crystal", mat="Glass", transparency=0.3)
        for i in range(4):
            shard("Stalactites", rock_sw, (rnd.uniform(-12, 12), rnd.uniform(-8, 10), H), rnd.uniform(1.6, 3.2), 0.6,
                  tilt=180, yaw=0)
        light = (1.0, 0.0, 11.0)
    elif band == "CrystalHollows":
        for cx, cy in ((-11.5, 10.0), (11.0, 10.5), (-10.5, -10.5), (10.5, -9.0)):
            for i in range(4):
                shard("Crystals", "crystal", (cx + rnd.uniform(-1.5, 1.5), cy + rnd.uniform(-1.5, 1.5), 0.0),
                      rnd.uniform(2.6, 5.5), rnd.uniform(0.55, 0.9), tilt=rnd.uniform(-28, 28), yaw=rnd.uniform(0, 360),
                      mat="Neon")
        light = (0.0, 2.0, 10.0)
    elif band == "SourceChamber":
        for i in range(4):
            z = 2.0 + i * 3.5
            pts = [(X0 + 1 + j * (X1 - X0 - 2) / 4, D / 2 - 1.2, z + rnd.uniform(-1.0, 1.0)) for j in range(5)]
            for a, b in zip(pts, pts[1:]):
                mid = ((a[0] + b[0]) / 2, a[1], (a[2] + b[2]) / 2)
                ang = math.degrees(math.atan2(b[2] - a[2], b[0] - a[0]))
                t(sf.box((math.dist(a, b), 0.6, 0.45), loc=mid, rot=(0, -ang, 0), bevel=0.0), "Veins", "glow", mat="Neon",
                  cast_shadow=False)
        for i in range(5):
            o = nugget("Growths", "rust", (rnd.uniform(-13, 13), rnd.uniform(-10, 12), 0.8), rnd.uniform(1.2, 2.2), seed + 50 + i)
            sf.paint(o, "glow", lambda c, n: n.z > 0.85)
        light = (0.0, 4.0, 9.0)
    return {"sockets": {"Light": (light, 0.0)}}


def export(name: str, build, meta: dict, budget: int):
    sf.reset()
    extra = build() or {}
    doc = sf.export_asset(name, CATEGORY, pivot=(0, 0, 0), merge="room", budget=budget, step="A1",
                          sockets=extra.get("sockets"), meta=meta)
    print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


def preview():
    """Each band as a row of the grid: rock, a dug cell (front face off), rock."""
    sf.reset()
    pitch_x, pitch_z = W + 2 * T, H + S
    for row, band in enumerate(BANDS):
        for col, maker in ((-1, rock), (0, dug), (1, rock)):
            before = set(bpy.context.scene.objects)
            maker(band)
            for o in [o for o in bpy.context.scene.objects if o not in before]:
                if o.get("sf_role") == "FrontWall":
                    bpy.data.objects.remove(o, do_unlink=True)
                    continue
                o.location.x += col * pitch_x
                o.location.z -= row * pitch_z
    print(sf.render_preview("Kit_Rock", CATEGORY, res=720, samples=24, merge="part",
                            views=[(0, 6, False), (-30, 20, False)]))


if __name__ == "__main__":
    if os.environ.get("SF_EXPORT") == "1":
        for band in BANDS:
            export(f"Kit_Rock_{band}", lambda b=band: rock(b), {"kit": "rock", "band": band}, 1200)
            export(f"Kit_Dug_{band}", lambda b=band: dug(b), {"kit": "dug", "band": band}, 2500)
    else:
        preview()
