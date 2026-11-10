"""Weapon_PowerWrench: the Tinkerer's melee weapon (bible Appendix: heavy hits). A motorised
Steadfast wrench: a chrome I-beam with an open jaw, a teal enamel motor on the shaft with copper
windings and cooling fins, a hazard-yellow battery pack at the pommel, a rubber grip and a red
trigger.

Pivot = the grip. Sockets: Grip and Tip (the jaw). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_PowerWrench.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_PowerWrench", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.35, 0.0)
TIP_Y = -2.4


def build():
    W = "PowerWrench"
    # shaft: chrome I-beam
    G.t(sf.box((0.13, 2.0, 0.34), loc=(0, -0.95, 0), bevel=0.04, segments=1), W, "chrome")
    for sz in (-1, 1):
        G.t(sf.box((0.22, 1.5, 0.08), loc=(0, -1.0, sz * 0.15), bevel=0.02, segments=1), W, "chrome")
    # the jaw: an open crescent at the head
    jaw = [(-1.85, 0.32), (-2.35, 0.55), (-2.48, 0.32), (-2.2, 0.16), (-2.2, -0.16), (-2.48, -0.32),
           (-2.35, -0.55), (-1.85, -0.32), (-1.95, 0.0)]
    G.t(G.side(jaw, 0.22, bevel=0.03, segments=1), W, "steel")
    G.t(sf.cyl(0.08, 0.26, loc=(0, -2.02, 0), rot=(0, 90, 0), verts=8, bevel=0.0), W, "brass")   # worm screw
    # the motor: a teal can on the shaft with copper windings and fins
    G.t(sf.cyl(0.27, 0.7, loc=(0, -1.25, 0.32), rot=(90, 0, 0), verts=12, bevel=0.05, segments=1), W, "teal")
    for i in range(3):
        G.t(sf.torus(0.275, 0.03, loc=(0, -1.48 + i * 0.23, 0.32), rot=(90, 0, 0), major_segs=8, minor_segs=3), W, "copper")
    for i in range(5):
        G.t(sf.box((0.5, 0.04, 0.12), loc=(0, -1.5 + i * 0.12, 0.6), bevel=0.0), W, "gunmetal")
    G.t(sf.cyl(0.12, 0.1, loc=(0, -1.62, 0.32), rot=(90, 0, 0), verts=8, bevel=0.0), W, "chrome")
    # grip, trigger and battery
    G.wrap(W, 0.15, 0.05, 0.75, 0.0, rings=5, swatch="rubber")
    G.t(sf.box((0.07, 0.1, 0.16), loc=(0, -0.02, -0.18), rot=(16, 0, 0), bevel=0.02, segments=1), W, "signal")
    G.t(sf.box((0.38, 0.46, 0.44), loc=(0, 1.0, 0), bevel=0.06, segments=1), W, "hazard")
    for i in range(2):
        G.t(sf.box((0.4, 0.06, 0.46), loc=(0, 0.88 + i * 0.24, 0), bevel=0.0), W, "rubber")
    G.t(sf.cyl(0.05, 0.05, loc=(0.2, 1.0, 0.08), rot=(0, 90, 0), verts=6, bevel=0.0), W, "glow", "Neon")   # charge lamp
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, 0), 0.0)}, {"kind": "Melee", "class": ["Tinkerer"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
