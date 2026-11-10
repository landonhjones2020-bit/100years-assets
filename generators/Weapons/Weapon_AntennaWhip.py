"""Weapon_AntennaWhip: the Radio Operator's melee weapon (bible Appendix: long reach). A
telescoping radio aerial on a spring base: four chrome sections with brass collars, a red
ball at the tip, a copper spring, and a rubber grip with a brass ferrule and a little navy
junction box at the pommel.

Pivot = the grip. Sockets: Grip and Tip (the ball). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_AntennaWhip.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_AntennaWhip", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.4, 0.0)
TIP_Y = -3.05


def build():
    W = "Whip"
    G.wrap(W, 0.13, 0.05, 0.8, 0.0, rings=5, swatch="rubber")
    G.t(sf.box((0.3, 0.26, 0.3), loc=(0, 0.95, 0), bevel=0.05, segments=1), W, "navy")
    G.t(sf.cyl(0.05, 0.08, loc=(0, 0.95, 0.17), verts=6, bevel=0.0), W, "brass")              # a terminal
    G.band(W, 0.15, 0.02, 0.0, w=0.1, swatch="brass")
    # the spring base
    for i in range(6):
        G.t(sf.torus(0.1, 0.03, loc=(0, -0.08 - i * 0.07, 0), rot=(90, 0, 0), major_segs=8, minor_segs=3), W, "copper")
    G.band(W, 0.11, -0.52, 0.0, w=0.08, swatch="brass")
    # telescoping sections, thinner toward the tip, each with a collar
    sections = [(0.095, -0.55, -1.15), (0.078, -1.15, -1.75), (0.063, -1.75, -2.35), (0.05, -2.35, -2.95)]
    for r, y0, y1 in sections:
        G.barrel(W, r, y1, y0, 0.0, "chrome", verts=8, bevel=0.0)
        G.band(W, r + 0.022, y1 + 0.03, 0.0, w=0.06, swatch="brass", verts=8)
    G.t(sf.sphere(0.12, loc=(0, TIP_Y + 0.06, 0), segs=10, rings=6), W, "signal")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, 0), 0.0)}, {"kind": "Melee", "class": ["RadioOperator"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
