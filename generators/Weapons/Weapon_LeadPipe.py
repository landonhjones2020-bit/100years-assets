"""Weapon_LeadPipe: balanced (bible Appendix); the Cook's, Scout's and Exterminator's melee
weapon. A length of bunker plumbing pulled off a wall: a steel pipe with two rusted bands, a
hazard-taped rubber grip, and a cast tee at the head with brass hex caps and a red valve wheel.

Pivot = the grip, where the hand closes. Sockets: Grip (the pivot) and Tip (the tee, for swing
trails). The head faces Blender -Y, so in Roblox the pipe extends down LookVector from the hand.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_LeadPipe.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_LeadPipe", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.55, 0.0)
TIP_Y = -2.5


def build():
    P = "Pipe"
    G.barrel(P, 0.13, -1.62, 1.0, 0.0, "steel", verts=10)
    for y in (-1.15, -0.5):
        G.band(P, 0.138, y, 0.0, w=0.16, swatch="rust")
    # the grip: rubber wrapped in hazard tape, a gunmetal end cap
    G.wrap(P, 0.155, 0.2, 0.95, 0.0, rings=5, swatch="rubber", tape="hazard")
    G.t(sf.cyl(0.18, 0.12, loc=(0, 1.02, 0), rot=(90, 0, 0), verts=8, bevel=0.03, segments=1), P, "gunmetal")
    # the head: a brass union nut, then a cast tee standing upright with brass hex caps
    G.t(sf.cyl(0.21, 0.26, loc=(0, -1.6, 0), rot=(90, 0, 0), verts=6, bevel=0.02, segments=1), P, "brass")
    G.t(sf.cyl(0.16, 0.24, loc=(0, -1.83, 0), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), P, "gunmetal")
    G.t(sf.cyl(0.21, 0.8, loc=(0, -2.06, 0), verts=10, bevel=0.03, segments=1), P, "gunmetal")
    for sz in (-1, 1):
        G.t(sf.cyl(0.24, 0.12, loc=(0, -2.06, sz * 0.43), verts=6, bevel=0.0), P, "brass")
    # the valve: a stem out the front of the tee and a red wheel
    G.t(sf.cyl(0.05, 0.26, loc=(0, -2.33, 0), rot=(90, 0, 0), verts=6, bevel=0.0), P, "steel")
    G.t(sf.torus(0.17, 0.04, loc=(0, -2.46, 0), rot=(90, 0, 0), major_segs=8, minor_segs=3), P, "rust")
    for a in (0, 60, 120):
        G.t(sf.box((0.34, 0.035, 0.035), loc=(0, -2.46, 0), rot=(0, a, 0), bevel=0.0), P, "rust")
    G.t(sf.cyl(0.06, 0.06, loc=(0, -2.5, 0), rot=(90, 0, 0), verts=6, bevel=0.0), P, "brass")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, 0), 0.0)},
                     {"kind": "Melee", "class": ["Cook", "Scout", "Exterminator"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
