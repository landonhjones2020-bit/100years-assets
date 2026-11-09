"""Kit_CaveMouth: a cave opening found by digging (bible Section 6: "Cave opening: opens a 3D cave
area"; Prompt 14: until the caves arrive (Prompt 21) it is a way in for monsters, a breach
point, at the back of the dug cell).

A ragged hole in the back rock: a funnel of dark basalt that narrows and drops away into a
black void, two Source-green eyes watching from deep inside, a rim of broken boulders heaped
higher at the base, Source crystals pushing out of the rim, and rubble spilled across the
floor in front. The rock is band-neutral (stone, basalt and ash) like the cave-in rubble.

Pivot = the bottom centre of its BACK, where it meets the rock face. DigService stands it
2 studs in front of the cell's back wall (the dug cell's rock face bulges up to 2 studs into
the room), so nothing of the wall shows through the funnel. Front = Blender -Y (the room);
everything is at y <= 0. Nothing collides: the rock behind it is the wall.

Run:  SF_EXPORT=1 python3 generators/Kits/Kit_CaveMouth.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Monsters"))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import steadfast as sf  # noqa: E402
from Kit_Rubble import lump, mottle  # noqa: E402
from _beast import crystal  # noqa: E402

ASSET, CATEGORY = "Kit_CaveMouth", "Kit"
BUDGET = 2000
N = 16                     # points round each ring of the funnel
FLOOR = 0.12               # the funnel's flat bottom
# the funnel's rings, front to back: (y, half width, half height, centre height)
RINGS = [(-3.1, 3.5, 3.9, 3.5), (-2.2, 3.0, 3.4, 3.25), (-1.2, 2.3, 2.7, 2.9), (-0.25, 1.5, 1.9, 2.45)]


def ring_point(k, ring, rnd):
    y, rx, rz, cz = ring
    a = math.tau * k / N
    jitter = 1.0 + rnd.uniform(-0.08, 0.08)
    x = math.cos(a) * rx * jitter
    z = max(FLOOR, cz + math.sin(a) * rz * jitter)
    return Vector((x, y, z))


def funnel(rnd):
    """The tunnel's inside: rings joined by quads facing inward (the camera looks into it)."""
    bm = bmesh.new()
    rings = [[bm.verts.new(ring_point(k, r, rnd)) for k in range(N)] for r in RINGS]
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(N):
            k2 = (k + 1) % N
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.normal_update()
    flip = []
    for f in bm.faces:
        c = f.calc_center_median()
        y = c.y
        # the axis point at this depth
        t = (y - RINGS[0][0]) / (RINGS[-1][0] - RINGS[0][0])
        cz = RINGS[0][3] + (RINGS[-1][3] - RINGS[0][3]) * t
        if f.normal.dot(c - Vector((0, y, cz))) > 0:
            flip.append(f)
    bmesh.ops.reverse_faces(bm, faces=flip)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="ALTERNATE")
    o = sf.from_bmesh(bm, "Funnel")
    sf.tag(o, "Funnel", "basalt", smooth_angle=None)
    # darker the deeper it goes
    sf.paint(o, "rubber", lambda c, n: c.y > -1.0)
    # the void at the back: a dark plate across the last ring
    y, rx, rz, cz = RINGS[-1]
    back = sf.cyl(1.0, 0.1, loc=(0, y + 0.08, cz), rot=(90, 0, 0), verts=N, bevel=0.0, name="Void")
    back.scale = (rx * 1.05, rz * 1.05, 1)
    sf.tag(back, "Void", "rubber", smooth_angle=None)
    return o


def build():
    rnd = random.Random(21)
    funnel(rnd)
    # eyes deep inside, low down, looking out
    for sx in (-1, 1):
        sf.tag(sf.sphere(0.13, loc=(sx * 0.36, -0.45, 1.55), scale=(1.25, 1, 0.8), segs=8, rings=4), "Eyes", "glow", "Neon",
               cast_shadow=False)

    # the rim: boulders round the opening, heaped higher at the base
    y, rx, rz, cz = RINGS[0]
    rim = []
    for k in range(14):
        a = math.radians(-12 + k * (204 / 13) + rnd.uniform(-4, 4))   # from low right, over the top, to low left
        x = math.cos(a) * (rx + 0.7 + rnd.uniform(-0.2, 0.3))
        z = max(0.8, cz + math.sin(a) * (rz + 0.6 + rnd.uniform(-0.2, 0.4)))
        r = (1.0 if z > 4 else 1.35) * rnd.uniform(0.75, 1.2)
        rim.append(lump("Rim", Vector((x, y - 0.1 + rnd.uniform(-0.3, 0.3), z)), r, 300 + k, segs=6, rings=5))
    for k, (x, r) in enumerate(((-4.7, 1.8), (4.6, 1.7), (-5.6, 1.2), (5.7, 1.3))):
        rim.append(lump("Rim", Vector((x, y + 0.4 - rnd.uniform(0, 0.6), 0)), r, 330 + k, segs=7, rings=5, resting=True))
    # rubble spilled across the floor in front
    for k in range(9):
        x = rnd.uniform(-4.2, 4.2)
        d = rnd.uniform(0.4, 1.9)
        r = rnd.uniform(0.35, 0.8) * (1.2 - d / 2.4)
        lump("Rubble", Vector((x, y - d, 0)), r, 360 + k, segs=6, rings=4, resting=True)
    # Source crystals pushing out of the rim
    for k, (a, n) in enumerate(((150, 3), (28, 2), (95, 2))):
        rad = math.radians(a)
        base = Vector((math.cos(rad) * (rx + 0.6), y - 0.6, cz + math.sin(rad) * (rz + 0.45)))
        out = Vector((math.cos(rad), -0.9, math.sin(rad) * 0.6))
        for j in range(n):
            d = (out + Vector((rnd.uniform(-0.35, 0.35), rnd.uniform(-0.2, 0.2), rnd.uniform(-0.3, 0.3)))).normalized()
            sf.tag(crystal(base + Vector((rnd.uniform(-0.25, 0.25), 0, rnd.uniform(-0.25, 0.25))), d,
                           rnd.uniform(1.5, 2.4), rnd.uniform(0.3, 0.42)), "Crystals", "glow", "Neon", cast_shadow=False)
    return {"export": {
        "budget": BUDGET, "step": "P14", "pivot": (0.0, 0.0, 0.0),
        "meta": {"kit": "cave", "feature": "CaveOpening", "wallOffset": 2.0},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
