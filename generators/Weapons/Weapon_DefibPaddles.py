"""Weapon_DefibPaddles: the Medic's melee weapon (bible Appendix: a jolt that stuns). One
Steadfast defibrillator paddle, held like a fist weapon: a mint enamel handle with a red thumb
button and a cream grip, a round chrome contact plate on a mint backing facing forward, and a
coiled rubber lead out of the back.

Pivot = the grip. Sockets: Grip and Tip (the plate's face). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_DefibPaddles.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_DefibPaddles", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.1, 0.0)
PLATE_Y = -0.62


def build():
    D = "Paddle"
    # handle: a cream grip in a mint enamel housing, flaring into the plate's back
    G.t(sf.cyl(0.13, 0.62, loc=(0, 0.12, 0), rot=(90, 0, 0), verts=10, bevel=0.03, segments=1), D, "cream")
    for i in range(3):
        G.t(sf.torus(0.135, 0.025, loc=(0, -0.02 + i * 0.14, 0), rot=(90, 0, 0), major_segs=8, minor_segs=3), D, "mint")
    G.t(sf.lathe([(0.0, 0.0), (0.15, 0.0), (0.17, 0.14), (0.2, 0.26), (0.0, 0.26)], verts=14,
                 loc=(0, -0.2, 0), rot=(90, 0, 0)), D, "mint")
    G.t(sf.cyl(0.47, 0.14, loc=(0, -0.53, 0), rot=(90, 0, 0), verts=16, bevel=0.04, segments=1), D, "mint")
    G.t(sf.cyl(0.43, 0.06, loc=(0, PLATE_Y + 0.02, 0), rot=(90, 0, 0), verts=16, bevel=0.015, segments=1), D, "chrome")
    G.t(sf.box((0.1, 0.12, 0.08), loc=(0, -0.16, 0.2), bevel=0.02, segments=1), D, "signal")   # discharge button
    # a hazard-yellow lightning bolt on the back of the plate, where the player sees it
    bolt = [(0.06, 0.34), (-0.16, 0.02), (-0.02, 0.02), (-0.1, -0.32), (0.16, 0.04), (0.02, 0.04)]
    for sx in (-1, 1):   # one either side of the neck
        pts = [(sx * 0.31 + x * 0.42, z * 0.42) for x, z in bolt]
        G.t(sf.profile_slab(pts, 0.04, loc=(0, -0.44, 0), rot=(90, 0, 0), bevel=0.0), D, "hazard")
    G.t(sf.box((0.02, 0.22, 0.12), loc=(0.135, 0.12, 0), bevel=0.0), D, "rust")              # a red stencil stripe
    # the coiled lead out of the back
    pts, radii = [], []
    for i in range(22):
        a = i * 0.9
        pts.append((math.cos(a) * 0.09, 0.44 + i * 0.045, -0.05 + math.sin(a) * 0.09 - i * 0.012))
        radii.append(0.035)
    G.t(sf.tube(pts, radii, sides=4, resolution=2), D, "rubber")
    G.t(sf.cyl(0.09, 0.1, loc=(0, 0.45, 0), rot=(90, 0, 0), verts=8, bevel=0.0), D, "gunmetal")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, PLATE_Y, 0), 0.0)}, {"kind": "Melee", "class": ["Medic"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
