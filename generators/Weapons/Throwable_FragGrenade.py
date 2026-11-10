"""Throwable_FragGrenade: area damage (bible Appendix). A 1950s pineapple grenade: an olive
body with forest-green grooves, a gunmetal fuse, a steel spoon down its side and a brass pull
ring. One MeshPart (no Neon), so the thrown copy is the whole grenade.

Pivot = the grip (the body's middle). Sockets: Grip. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Throwable_FragGrenade.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Throwable_FragGrenade", "Weapons"
BUDGET = 300
GRIP = (0.0, 0.0, 0.0)


def build():
    N = "Grenade"
    G.t(sf.lathe([(0.0, -0.25), (0.15, -0.23), (0.22, -0.13), (0.24, 0.0), (0.22, 0.13), (0.15, 0.21), (0.09, 0.24), (0.0, 0.24)],
                 verts=10), N, "olive")
    for z in (-0.09, 0.08):
        G.t(sf.cyl(0.235, 0.035, loc=(0, 0, z), verts=10, bevel=0.0), N, "forest")
    G.t(sf.cyl(0.08, 0.14, loc=(0, 0, 0.3), verts=6, bevel=0.0), N, "gunmetal")
    G.t(sf.box((0.1, 0.04, 0.42), loc=(0, -0.2, 0.12), rot=(-12, 0, 0), bevel=0.0), N, "steel")
    G.t(sf.torus(0.07, 0.016, loc=(0.12, 0, 0.33), rot=(0, 90, 0), major_segs=6, minor_segs=3), N, "brass")
    return G.exports(BUDGET, "P20", GRIP, {}, {"kind": "Throwable", "class": ["Demolitionist"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
