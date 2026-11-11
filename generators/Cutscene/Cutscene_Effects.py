"""The intro cutscene's blast, as models the game's CutsceneController scales and moves (A9;
bible Section 4: "The flash, blast and cloud use Roblox particles, beams and tweened meshes"):

    Cutscene_Bomb            the bomb that crosses the sky; its nose is the front (-Y)
    Cutscene_Shockwave       the ring that crosses the town: a rolling wall of dust, built 100
                             studs across (the game sets its size to the ring's)
    Cutscene_MushroomCloud   the cloud at its full height (cutscene_plan.CLOUD), standing on its
                             own origin. Its parts keep their names for the game: Base (the dust
                             at its foot, which spreads), Stem (which grows), and Cap, CapGlow
                             and Skirt (which ride the top as it climbs and spreads)

    python3 generators/Cutscene/Cutscene_Effects.py [Bomb|Shockwave|MushroomCloud ...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import cutscene_plan as CP  # noqa: E402
import townkit as T  # noqa: E402


def bomb(k):
    """Fat, finned, a hazard band round its middle: the kind every 1958 poster drew."""
    body = [(0.0, 0.0), (0.55, 0.5), (1.05, 1.5), (1.3, 3.0), (1.3, 5.6), (1.0, 7.4), (0.5, 8.6), (0.32, 9.2)]
    with k.at((0, 4.6, 0)):
        k.lathe("gunmetal", body, rot=(90, 0, 0), verts=10)                      # nose at -Y
        k.lathe("hazard", [(1.34, 3.4), (1.34, 4.4)], rot=(90, 0, 0), verts=10)
        k.lathe("rust", [(0.0, -0.02), (0.57, 0.5), (0.9, 1.15)], rot=(90, 0, 0), verts=10)
        k.lathe("rubber", [(0.4, 9.0), (0.4, 9.5)], rot=(90, 0, 0), verts=8)
    for i in range(4):                                                         # fins and the ring round them
        a = math.radians(45 + i * 90)
        with k.at((0, 0, 0), 0):
            pts = [(0.35, 2.4), (1.75, 4.0), (1.75, 5.2), (0.35, 5.0)]
            m = T.Matrix.Rotation(a, 4, "Y") @ T.Matrix.Translation((0, 0, -0.06))
            k.prism("steel", [(x, y) for x, y in pts], 0.12, m)
    k.lathe("steel", [(1.7, 0.0), (1.82, 0.0), (1.82, 1.3), (1.7, 1.3)], (0, 5.2, 0), rot=(90, 0, 0), verts=10)
    k.socket("Tail", (0, 5.4, 0), 0)
    return {"views": [("side", (-16.0, -2.0, 4.0), (0.0, 0.5, 0.0), 40), ("nose", (-6.0, -14.0, 5.0), (0.0, 0.0, 0.0), 40)]}


def _noise(a, z, seed=0.0):
    """Lumps round a turned shape: a few waves of different counts, different at each height."""
    return (math.sin(a * 5 + z * 0.045 + seed) * 0.5 + math.sin(a * 9 - z * 0.07 + seed * 2.3) * 0.3 + math.sin(a * 3 + z * 0.11 + seed * 0.7) * 0.2)


def revolve(k, profile, segs, swatch, lumps=0.0, seed=0.0, twist=0.0, at=(0, 0, 0), jitter=0.0, **kw):
    """Turn a profile [(radius, z), ...] about Z into a faceted skin, pushed in and out by `lumps`
    studs so it billows, each triangle coloured by swatch(centre, normal). Open at both ends unless
    the profile starts or ends on the axis."""
    import bmesh
    rng = random.Random(int(seed * 1000) + 5)
    bm = bmesh.new()
    rings = []
    for i, (r, z) in enumerate(profile):
        if r < 1e-4:
            rings.append([bm.verts.new((at[0], at[1], at[2] + z))])
            continue
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs + twist * z
            rr = r + lumps * _noise(a, z, seed) + rng.uniform(-jitter, jitter)
            ring.append(bm.verts.new((at[0] + rr * math.cos(a), at[1] + rr * math.sin(a), at[2] + z + rng.uniform(-jitter, jitter) * 0.6)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        lo, hi = rings[i], rings[i + 1]
        for j in range(segs):
            j2 = (j + 1) % segs
            if len(lo) == 1 and len(hi) > 1:
                bm.faces.new((lo[0], hi[j], hi[j2]))
            elif len(hi) == 1 and len(lo) > 1:
                bm.faces.new((lo[j], lo[j2], hi[0]))
            elif len(lo) > 1 and len(hi) > 1:
                if (i + j) % 2 == 0:
                    bm.faces.new((lo[j], lo[j2], hi[j2]))
                    bm.faces.new((lo[j], hi[j2], hi[j]))
                else:
                    bm.faces.new((lo[j], lo[j2], hi[j]))
                    bm.faces.new((lo[j2], hi[j2], hi[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    groups: dict = {}
    for f in bm.faces:
        c = f.calc_center_median()
        groups.setdefault(swatch(c, f.normal), []).append(tuple(v.index for v in f.verts))
    verts = [tuple(v.co) for v in bm.verts]
    bm.free()
    for sw, faces in groups.items():
        used = sorted({n for f in faces for n in f})
        remap = {n: m for m, n in enumerate(used)}
        k.add(sw, [verts[n] for n in used], [tuple(remap[n] for n in f) for f in faces], smooth=-1.0, shadow=False, **kw)


def lit(top="cream", side="sandstone", under="leather", flecks=None, hi=0.5, lo=-0.15):
    """Colours by the way a face looks: up, out or down. flecks: (swatch, share) scattered over the top."""
    def pick(c, n):
        if n.z > hi:
            if flecks and (math.sin(c.x * 0.37 + c.y * 0.61 + c.z * 0.29) * 0.5 + 0.5) < flecks[1]:
                return flecks[0]
            return top
        return side if n.z > lo else under
    return pick


def shockwave(k):
    """A ring of rolling dust, 50 studs in radius here: a billowing wall with a bright front."""
    R = 50.0
    wall = [(R * 0.84, 0.0), (R * 0.855, 3.2), (R * 0.9, 6.4), (R * 0.95, 7.4), (R * 0.985, 5.6), (R, 2.6), (R, 0.0)]
    revolve(k, wall, 72, lit("cream", "sandstone", "stone", flecks=("porcelain", 0.3)), lumps=1.5, seed=1.0, jitter=0.5)
    inner = [(R * 0.7, 0.0), (R * 0.72, 2.0), (R * 0.79, 3.6), (R * 0.85, 2.8), (R * 0.86, 0.0)]
    revolve(k, inner, 56, lit("sandstone", "stone", "stone"), lumps=1.8, seed=2.0, jitter=0.5)
    # the pressure front itself: a thin bright band just ahead of the dust
    revolve(k, [(R * 1.012, 0.0), (R * 1.012, 1.5), (R * 1.0, 3.0)], 72, lambda c, n: "porcelain", mat="Neon")
    return {"views": [("from above", (-80.0, -90.0, 70.0), (0.0, 0.0, 0.0), 50), ("the wall", (0.0, -90.0, 6.0), (0.0, -46.0, 4.0), 40)]}


def cloud(k):
    """The mushroom cloud, faceted like everything else: a boiling cap with a lit underside, a
    collar, a roped stem, the dust it stands in."""
    rng = random.Random(9)
    top, capr, stemr = CP.CLOUD["Top"], CP.CLOUD["CapRadius"], CP.CLOUD["StemRadius"]
    cap_z = top - capr * 0.5                   # the cap's widest height
    under = cap_z - capr * 0.3                 # where the stem meets it
    c = capr
    # the cap: a boiling dome over a rolled lip
    cap = [(0.8 * c, -0.31 * c), (0.95 * c, -0.2 * c), (1.0 * c, -0.03 * c), (0.96 * c, 0.13 * c),
           (0.84 * c, 0.27 * c), (0.66 * c, 0.38 * c), (0.44 * c, 0.455 * c), (0.2 * c, 0.492 * c), (0.0, 0.5 * c)]
    revolve(k, cap, 30, lit("cream", "sandstone", "leather", flecks=("porcelain", 0.28)), lumps=c * 0.14, seed=3.0, jitter=c * 0.02, at=(0, 0, cap_z),
            part="Cap", role="Cap")
    for i in range(14):                        # billows round the rim, high and low
        a = 2 * math.pi * i / 14 + rng.uniform(-0.12, 0.12)
        r = c * rng.uniform(0.7, 0.88)
        s = c * rng.uniform(0.2, 0.29)
        z = cap_z + c * (rng.uniform(0.08, 0.2) if i % 2 else rng.uniform(-0.16, -0.02))
        k.blob(("cream", "sandstone", "cream", "leather")[i % 4] if i % 2 else ("sandstone", "leather")[(i // 2) % 2], s, (r * math.cos(a), r * math.sin(a), z),
               scale=(1.0, 1.0, 0.84), detail=2, jitter=0.16, seed=210 + i, part="Cap", role="Cap", shadow=False)
    for i in range(7):                         # and over the top
        a = 2 * math.pi * i / 7 + 0.4
        r = c * (0.36 if i else 0.0)
        k.blob("cream" if i % 2 else "porcelain", c * rng.uniform(0.22, 0.28), (r * math.cos(a), r * math.sin(a), cap_z + c * (0.36 if i else 0.4)),
               scale=(1.0, 1.0, 0.8), detail=2, jitter=0.16, seed=240 + i, part="Cap", role="Cap", shadow=False)
    # the lip's underside, dark at the rim, and the fire inside it round the stem
    revolve(k, [(0.52 * c, -0.37 * c), (0.8 * c, -0.31 * c)], 30, lambda cc, n: "rust" if math.sin(math.atan2(cc.y, cc.x) * 7) > 0 else "leather",
            lumps=c * 0.05, seed=3.0, at=(0, 0, cap_z), part="Cap", role="Cap")
    revolve(k, [(stemr * 1.5, -0.3 * c), (0.52 * c, -0.37 * c)], 20, lambda cc, n: "signal", lumps=c * 0.03, seed=5.0, at=(0, 0, cap_z),
            mat="Neon", part="CapGlow", role="CapGlow")
    # the collar: a ring of cloud part-way up the stem
    cz = under - c * 0.42
    ring = []
    for i in range(9):
        a = math.pi * 2 * i / 8
        ring.append((stemr * 2.25 + c * 0.1 * math.cos(a), c * 0.075 * math.sin(a)))
    revolve(k, ring, 22, lit("cream", "sandstone", "leather"), lumps=c * 0.055, seed=7.0, jitter=c * 0.014, at=(0, 0, cz), part="Skirt", role="Skirt")
    # the stem: a twisted rope of smoke, flaring into the cap and out at its foot
    stem = [(stemr * 1.9, 0.0), (stemr * 1.3, under * 0.07), (stemr * 1.02, under * 0.2), (stemr * 0.92, under * 0.4), (stemr * 0.95, under * 0.6),
            (stemr * 1.08, under * 0.78), (stemr * 1.4, under * 0.92), (stemr * 1.9, under + c * 0.03)]

    def rope(cc, n):
        a = math.atan2(cc.y, cc.x) - 0.011 * cc.z
        v = math.sin(a * 5) * 0.6 + math.sin(a * 2 + cc.z * 0.05) * 0.4
        return "sandstone" if v > 0.1 else "leather"
    revolve(k, stem, 20, rope, lumps=stemr * 0.34, seed=9.0, twist=0.011, jitter=stemr * 0.05, part="Stem", role="Stem")
    # the foot: dust rolling outward over the ground
    base = [(0.0, c * 0.2), (c * 0.34, c * 0.2), (c * 0.62, c * 0.15), (c * 0.86, c * 0.08), (c * 1.02, 0.0)]
    revolve(k, base, 26, lit("sandstone", "stone", "stone", flecks=("cream", 0.25)), lumps=c * 0.07, seed=11.0, jitter=c * 0.012, part="Base", role="Base")
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.1, 0.1)
        r = c * rng.uniform(0.6, 0.86)
        s = c * rng.uniform(0.16, 0.22)
        k.blob("sandstone" if i % 2 else "stone", s, (r * math.cos(a), r * math.sin(a), s * 0.3), scale=(1.15, 1.15, 0.6), detail=2, jitter=0.14, seed=i,
               part="Base", role="Base", shadow=False)
    return {"views": [("whole", (-420.0, -200.0, 90.0), (0.0, 0.0, 120.0), 44), ("from the town", (-380.0, 0.0, 40.0), (0.0, 0.0, 130.0), 50),
                      ("under the cap", (-150.0, -80.0, 60.0), (0.0, 0.0, 170.0), 60)]}


WHICH = {
    "Bomb": (bomb, "Cutscene_Bomb", 600),
    "Shockwave": (shockwave, "Cutscene_Shockwave", 6500),
    "MushroomCloud": (cloud, "Cutscene_MushroomCloud", 9000),
}

if __name__ == "__main__":
    for name in ([a for a in sys.argv[1:] if a in WHICH] or list(WHICH)):
        fn, asset, budget = WHICH[name]
        T.run(fn, asset, "Cutscene", budget=budget, step="A9", sun=(40, -70), ground=None if name != "MushroomCloud" else "#6F9B4C",
              ground_size=1600.0, sun_strength=3.2)
