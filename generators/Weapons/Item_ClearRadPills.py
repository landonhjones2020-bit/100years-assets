"""Item_ClearRadPills: clear radiation (bible Appendix). A 1950s tin of Clear-Rad tablets: a
white enamel tin with a chrome screw lid, a cream label with a mint stripe, and a hazard-yellow
radiation badge on its front.

Pivot = bottom-centre. Sockets: Grip (the tin's middle). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Item_ClearRadPills.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Item_ClearRadPills", "Weapons"
BUDGET = 300


def build():
    P = "Pills"
    G.t(sf.cyl(0.17, 0.44, loc=(0, 0, 0.22), verts=10, bevel=0.02, segments=1), P, "porcelain", collision="box")
    G.t(sf.cyl(0.175, 0.22, loc=(0, 0, 0.22), verts=10, bevel=0.0), P, "cream", collision="box")
    G.t(sf.cyl(0.178, 0.05, loc=(0, 0, 0.3), verts=10, bevel=0.0), P, "mint", collision="box")
    G.t(sf.cyl(0.18, 0.1, loc=(0, 0, 0.48), verts=10, bevel=0.02, segments=1), P, "chrome", collision="box")
    # the badge: a hazard disc with three dark blades
    G.t(sf.cyl(0.08, 0.02, loc=(0, -0.175, 0.2), rot=(90, 0, 0), verts=8, bevel=0.0), P, "hazard", collision="box")
    for i in range(3):
        a = math.radians(90 + i * 120)
        G.t(sf.box((0.035, 0.012, 0.05), loc=(math.cos(a) * 0.04, -0.188, 0.2 + math.sin(a) * 0.04),
                   rot=(0, -math.degrees(a) + 90, 0), bevel=0.0), P, "navy", collision="box")
    return G.exports(BUDGET, "P20", (0, 0, 0.22), {}, {"kind": "Consumable"}, pivot=(0, 0, 0))


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
