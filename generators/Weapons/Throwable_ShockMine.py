"""Throwable_ShockMine: stuns whatever steps on it (bible Appendix). A flat disc mine: a
gunmetal base with a hazard-striped rim, a copper coil, a pale green capacitor dome and four
chrome contact prongs. One MeshPart (the dome is the glow swatch, not Neon).

Pivot = the grip (the disc's centre). Sockets: Grip. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Throwable_ShockMine.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Throwable_ShockMine", "Weapons"
BUDGET = 300
GRIP = (0.0, 0.0, 0.05)


def build():
    M = "Mine"
    G.t(sf.cyl(0.4, 0.1, loc=(0, 0, 0.05), verts=10, bevel=0.0), M, "gunmetal")
    G.t(sf.cyl(0.42, 0.04, loc=(0, 0, 0.02), verts=10, bevel=0.0), M, "hazard")
    G.t(sf.torus(0.25, 0.035, loc=(0, 0, 0.11), major_segs=8, minor_segs=3), M, "copper")
    G.t(sf.sphere(0.14, loc=(0, 0, 0.1), scale=(1, 1, 0.7), segs=8, rings=4), M, "glow")
    for i in range(4):
        a = math.radians(45 + i * 90)
        G.t(sf.cyl(0.025, 0.16, loc=(math.cos(a) * 0.33, math.sin(a) * 0.33, 0.17), verts=4, bevel=0.0), M, "chrome")
    return G.exports(BUDGET, "P20", GRIP, {}, {"kind": "Throwable", "class": ["Engineer"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
