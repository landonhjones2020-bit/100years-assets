"""Throwable_FoamGrenade: puts out fires (bible Appendix). A little Steadfast foam canister: a
white enamel body with teal bands and a cream label, a brass valve with a red pull ring and a
black nozzle, and a rubber foot. One MeshPart.

Pivot = the grip (the canister's middle). Sockets: Grip. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Throwable_FoamGrenade.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Throwable_FoamGrenade", "Weapons"
BUDGET = 300
GRIP = (0.0, 0.0, 0.0)


def build():
    C = "Foam"
    G.t(sf.cyl(0.18, 0.5, loc=(0, 0, 0), verts=10, bevel=0.03, segments=1), C, "porcelain")
    for z in (-0.17, 0.17):
        G.t(sf.cyl(0.185, 0.06, loc=(0, 0, z), verts=10, bevel=0.0), C, "teal")
    G.t(sf.box((0.2, 0.02, 0.16), loc=(0, -0.18, 0.0), bevel=0.0), C, "cream")
    G.t(sf.cyl(0.07, 0.1, loc=(0, 0, 0.3), verts=6, bevel=0.0), C, "brass")
    G.t(sf.torus(0.06, 0.015, loc=(0.1, 0, 0.32), rot=(0, 90, 0), major_segs=6, minor_segs=3), C, "rust")
    G.t(sf.cyl(0.035, 0.16, loc=(0, -0.1, 0.32), rot=(90, 0, 0), verts=6, bevel=0.0), C, "rubber")
    G.t(sf.cyl(0.17, 0.04, loc=(0, 0, -0.27), verts=10, bevel=0.0), C, "rubber")
    return G.exports(BUDGET, "P20", GRIP, {}, {"kind": "Throwable", "class": ["Firefighter"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
