"""Kit_Radiation: the two things that leak radiation (Prompt 24; bible Section 10: a radiation
leak is fixed by sealing the door; Section 12: radiation in the Crystal Hollows).
DisasterService hangs one where the leak is while it lasts and puts the prompt on it; the client
adds the glow and the drifting motes at its socket.

    Kit_DoorSeal     the Blast Door's seal where the storm got through: a steel jamb plate with
                     its row of bolts, the black gasket torn out of its channel and curling
                     into the hall, a sickly crust where the dust has blown in, a radiation
                     plate above it and the big orange hand wheel of the clamp that presses the
                     gasket back. Pivot: its middle, on the door's face. Socket Leak.
    Kit_CrystalSeam  a seam the dig opened: the rock split in a jagged mouth, crystals that glow
                     the Source's green pushing out of it, and the Steadfast patch plate that
                     was meant to cover it hanging by one bolt. Pivot: its middle, 0.8 studs
                     out from the wall. Socket Leak.

Both face Blender +Y (the room: the fitting is placed unturned on a wall at Roblox -Z).

    python3 generators/Kits/Kit_Radiation.py              preview of both
    SF_EXPORT=1 python3 generators/Kits/Kit_Radiation.py  exports both
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Monsters"))
import steadfast as sf  # noqa: E402
from _beast import shard, blob  # noqa: E402

CATEGORY = "Kit"
BUDGETS = {"Kit_DoorSeal": 1700, "Kit_CrystalSeam": 1500}


def t(obj, part, swatch, **kw):
    return sf.tag(obj, part, swatch, collision="none", **kw)


def bolt(part, loc, r=0.09):
    return t(sf.cyl(r, 0.1, loc=loc, rot=(90, 0, 0), verts=6, bevel=0.0), part, "chrome")


def door_seal():
    back = 0.0                                                    # the door's face
    # ---- the jamb plate and its channel
    t(sf.box((1.1, 0.22, 4.6), loc=(-0.9, back + 0.11, 0), bevel=0.03), "Jamb", "gunmetal")
    t(sf.box((0.34, 0.16, 4.4), loc=(-0.5, back + 0.3, 0), bevel=0.0), "Jamb", "rubber")          # the empty channel
    for i in range(7):
        bolt("Jamb", (-1.2, back + 0.26, -1.95 + i * 0.65))
    # ---- the gasket: seated at the top and bottom, torn out and curling into the hall between
    t(sf.tube([(-0.5, back + 0.36, 2.2), (-0.5, back + 0.36, 1.3)], [0.17, 0.17], sides=6, resolution=1), "Gasket", "rubber")
    t(sf.tube([(-0.5, back + 0.36, 1.3), (-0.42, back + 0.7, 0.8), (-0.2, back + 1.25, 0.3), (-0.3, back + 1.5, -0.3),
               (-0.55, back + 1.1, -0.9), (-0.5, back + 0.42, -1.5)], [0.17, 0.17, 0.16, 0.16, 0.17, 0.17], sides=5,
              resolution=2), "Gasket", "rubber")
    t(sf.tube([(-0.5, back + 0.36, -1.5), (-0.5, back + 0.36, -2.2)], [0.17, 0.17], sides=6, resolution=1), "Gasket", "rubber")
    # ---- what has blown in: a pale crust round the gap, a few motes of the Source's green
    rnd = random.Random(24)
    for i in range(8):
        z = -1.1 + i * 0.3 + rnd.uniform(-0.05, 0.05)
        t(sf.sphere(rnd.uniform(0.14, 0.26), loc=(-0.5 + rnd.uniform(-0.15, 0.3), back + 0.3, z), scale=(1.3, 0.45, 1.0),
                    segs=5, rings=3), "Crust", "avocado")
    for i, z in enumerate((-0.6, 0.0, 0.55)):
        t(sf.sphere(0.07, loc=(-0.42, back + 0.42, z), segs=5, rings=3), "LeakGlow", "glow", mat="Neon", cast_shadow=False)
    # ---- the clamp: a screw through a yoke, and the hand wheel that turns it
    t(sf.box((1.9, 0.3, 0.4), loc=(0.35, back + 0.5, 0.0), bevel=0.04), "Clamp", "steel")         # the yoke
    t(sf.box((0.4, 0.5, 0.9), loc=(1.25, back + 0.3, 0.0), bevel=0.04), "Clamp", "gunmetal")      # its anchor
    for z in (-0.3, 0.3):
        bolt("Clamp", (1.25, back + 0.58, z), r=0.08)
    t(sf.cyl(0.11, 1.1, loc=(0.35, back + 1.1, 0.0), rot=(90, 0, 0), verts=8, bevel=0.0), "Clamp", "chrome")   # the screw
    t(sf.box((0.5, 0.22, 0.7), loc=(-0.15, back + 0.52, 0.0), bevel=0.03), "Clamp", "gunmetal")   # the shoe on the gasket
    t(sf.torus(0.7, 0.085, loc=(0.35, back + 1.6, 0.0), rot=(90, 0, 0), major_segs=12, minor_segs=5), "Wheel", "signal")
    for a in (0, 60, 120):
        t(sf.box((1.34, 0.09, 0.09), loc=(0.35, back + 1.6, 0.0), rot=(0, a, 0), bevel=0.0), "Wheel", "signal")
    t(sf.cyl(0.17, 0.2, loc=(0.35, back + 1.6, 0.0), rot=(90, 0, 0), verts=8, bevel=0.02), "Wheel", "gunmetal")
    # ---- the radiation plate above
    t(sf.box((1.7, 0.1, 1.1), loc=(0.2, back + 0.08, 2.0), bevel=0.02), "Sign", "hazard")
    t(sf.cyl(0.16, 0.04, loc=(0.2, back + 0.15, 2.0), rot=(90, 0, 0), verts=8, bevel=0.0), "Sign", "navy")
    for a in (90, 210, 330):                                                                       # the trefoil's blades
        o = sf.cyl(0.4, 0.04, loc=(0.2 + math.cos(math.radians(a)) * 0.3, back + 0.15, 2.0 + math.sin(math.radians(a)) * 0.3),
                   rot=(90, 0, 0), verts=3, bevel=0.0)
        o.rotation_euler = (math.radians(90), math.radians(-a + 90), 0)
        t(o, "Sign", "navy")
    for x, z in ((-0.55, 2.45), (0.95, 2.45), (-0.55, 1.55), (0.95, 1.55)):
        bolt("Sign", (x, back + 0.16, z), r=0.05)
    return {"pivot": (0.0, 0.0, 0.0), "sockets": {"Leak": ((-0.35, back + 1.3, -0.2), 0.0)}}


def crystal_seam():
    back = -0.8                                                   # the wall
    rnd = random.Random(7)
    # ---- the broken rock: two lips of rind either side of a jagged mouth
    for sx in (-1, 1):
        for i in range(5):
            z = -1.7 + i * 0.85
            jag = 0.35 * (1 if i % 2 else -1)
            o = blob(0.5, (0, 0, 0), scale=(1.5 + rnd.uniform(0, 0.4), 0.9, 1.1), segs=6, rings=4, noise=0.18, seed=10 + i + sx)
            o.location = (sx * (1.15 + abs(jag) * 0.2) + jag * 0.6, back + 0.42, z)
            t(o, "Rock", "basalt" if (i + sx) % 2 else "plum", smooth_angle=None)
    t(sf.box((1.2, 0.2, 4.2), loc=(0.0, back + 0.14, 0), bevel=0.0), "Dark", "rubber")            # the dark inside the seam
    # ---- crystals pushing out of it, lit the Source's green
    pts = [(-0.25, 1.6), (0.3, 0.9), (-0.3, 0.2), (0.25, -0.5), (-0.2, -1.2), (0.1, -1.8)]
    for i, (x, z) in enumerate(pts):
        ln = rnd.uniform(0.8, 1.4)
        t(shard((x, back + 0.3, z), (x * 0.9, 1.0, rnd.uniform(-0.3, 0.4)), ln, 0.17, sides=5, twist=rnd.uniform(-1, 1)),
          "SeamGlow", "glow", mat="Neon", cast_shadow=False)
        for k in range(2):
            t(shard((x + rnd.uniform(-0.35, 0.35), back + 0.4, z + rnd.uniform(-0.3, 0.3)),
                    (rnd.uniform(-0.7, 0.7), 1.0, rnd.uniform(-0.5, 0.5)), ln * 0.6, 0.1, sides=4), "Crystals", "crystal")
    # ---- the Steadfast patch plate: one bolt still holding, swung down out of the way
    plate = sf.box((2.6, 0.12, 1.5), loc=(1.75, back + 0.95, -1.35), rot=(6, 58, 4), bevel=0.02)
    t(plate, "Plate", "teal")
    t(sf.box((2.2, 0.05, 0.3), loc=(1.75, back + 1.02, -1.35), rot=(6, 58, 4), bevel=0.0), "Plate", "cream")   # its stencil band
    bolt("Plate", (1.15, back + 1.0, -0.42), r=0.12)
    for x, z in ((-1.2, 1.95), (-1.25, -1.9), (1.3, 1.9)):                                         # the bolts it should hang on
        bolt("Rock", (x, back + 0.9, z), r=0.11)
    return {"pivot": (0.0, 0.0, 0.0), "sockets": {"Leak": ((0.0, back + 1.3, 0.0), 0.0)}}


VARIANTS = {"Kit_DoorSeal": (door_seal, {"kit": "hazard", "disaster": "RadiationLeak"}),
            "Kit_CrystalSeam": (crystal_seam, {"kit": "hazard", "disaster": "RadiationLeak"})}


def export(name: str):
    build, meta = VARIANTS[name]
    sf.reset()
    extra = build()
    print(f"[{name}] triangles (before merge): {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(sf.render_preview(name, CATEGORY, res=640, samples=24, views=[(140, 14, False), (205, 22, True)]))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(name, CATEGORY, pivot=extra["pivot"], sockets=extra["sockets"], budget=BUDGETS[name],
                              step="A10", meta=meta)
        print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


if __name__ == "__main__":
    for variant in (sys.argv[1:] or list(VARIANTS)):
        export(variant)
