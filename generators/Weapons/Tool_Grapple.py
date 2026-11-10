"""Tool_Grapple: zip lines (bible Appendix); the Spelunker's tool. A grapple gun: a gunmetal
body, a steel barrel with a hazard band, a brass three-tine hook on the muzzle, a leather rope
spool with a crank under the barrel, and a rubber pistol grip.

Pivot = the grip. Sockets: Grip and Muzzle (the hook's tip, where the line leaves). Faces
Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Tool_Grapple.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Tool_Grapple", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
BORE_Z = 0.6


def build():
    R = "Grapple"
    G.t(sf.box((0.3, 0.8, 0.38), loc=(0, -0.12, 0.54), bevel=0.06, segments=1), R, "gunmetal")
    G.barrel(R, 0.11, -1.2, -0.5, BORE_Z, "steel", verts=10)
    G.band(R, 0.115, -0.9, BORE_Z, w=0.12, swatch="hazard", verts=10)
    # the hook: a brass shaft and three tines curling back
    G.t(sf.cyl(0.06, 0.4, loc=(0, -1.38, BORE_Z), rot=(90, 0, 0), verts=6, bevel=0.0), R, "brass")
    G.t(sf.lathe([(0.08, 0.0), (0.0, 0.2)], verts=6, loc=(0, -1.58, BORE_Z), rot=(90, 0, 0)), R, "brass")
    for i in range(3):
        a = math.radians(90 + i * 120)
        c, s = math.cos(a), math.sin(a)
        pts = [(0, -1.5, BORE_Z), (c * 0.2, -1.46, BORE_Z + s * 0.2), (c * 0.3, -1.3, BORE_Z + s * 0.3), (c * 0.26, -1.18, BORE_Z + s * 0.26)]
        G.t(sf.tube(pts, [0.045, 0.045, 0.04, 0.02], sides=4, resolution=2), R, "brass")
    # rope spool and crank
    G.t(sf.cyl(0.22, 0.26, loc=(0, -0.72, 0.26), rot=(0, 90, 0), verts=10, bevel=0.03, segments=1), R, "leather")
    for x in (-0.14, 0.14):
        G.t(sf.cyl(0.25, 0.03, loc=(x, -0.72, 0.26), rot=(0, 90, 0), verts=10, bevel=0.0), R, "steel")
    G.t(sf.box((0.04, 0.3, 0.06), loc=(-0.18, -0.6, 0.26), bevel=0.0), R, "steel")
    G.t(sf.cyl(0.04, 0.12, loc=(-0.24, -0.47, 0.26), rot=(0, 90, 0), verts=6, bevel=0.0), R, "rubber")
    G.trigger_guard(R, 0.05, 0.24, r=0.15)
    G.pistol_grip(R, GRIP, frame="gunmetal", panel="rubber", medallion="brass")
    return G.exports(BUDGET, "P20", GRIP, {"Muzzle": ((0, -1.62, BORE_Z), 0.0)}, {"kind": "Tool", "class": ["Spelunker"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
