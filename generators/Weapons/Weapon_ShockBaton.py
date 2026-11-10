"""Weapon_ShockBaton: stuns (bible Appendix); the Security's, Warden's and Mad Scientist's melee
weapon. A 1950s riot baton turned electric: a navy shaft wound with copper coils near the tip,
two chrome prongs with a green spark between them (a Neon part), a chrome hand guard, a rubber
grip with a red thumb switch and a hazard-striped battery at the pommel.

Pivot = the grip. Sockets: Grip and Tip (the prongs). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_ShockBaton.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_ShockBaton", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.45, 0.0)
TIP_Y = -2.0


def build():
    B = "Baton"
    G.t(sf.cyl(0.1, 1.95, loc=(0, -0.83, 0), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), B, "navy")
    # copper coils toward the tip
    for i in range(5):
        G.t(sf.torus(0.115, 0.03, loc=(0, -1.15 - i * 0.12, 0), rot=(90, 0, 0), major_segs=8, minor_segs=3), B, "copper")
    G.band(B, 0.13, -1.72, 0.0, w=0.12, swatch="chrome")
    # the prongs and the spark
    for sx in (-1, 1):
        G.t(sf.box((0.045, 0.24, 0.045), loc=(sx * 0.07, -1.88, 0), bevel=0.0), B, "chrome")
    G.t(sf.sphere(0.06, loc=(0, -1.97, 0), segs=8, rings=5), "Spark", "glow", "Neon")
    # hand guard, grip, thumb switch
    G.t(sf.cyl(0.19, 0.06, loc=(0, 0.12, 0), rot=(90, 0, 0), verts=12, bevel=0.0), B, "chrome")
    G.wrap(B, 0.125, 0.16, 0.86, 0.0, rings=5, swatch="rubber")
    G.t(sf.box((0.08, 0.12, 0.06), loc=(0, 0.22, 0.13), bevel=0.02, segments=1), B, "signal")
    # battery at the pommel: hazard can with a rubber band and a brass contact
    G.t(sf.cyl(0.15, 0.3, loc=(0, 1.02, 0), rot=(90, 0, 0), verts=10, bevel=0.03, segments=1), B, "hazard")
    G.band(B, 0.155, 1.02, 0.0, w=0.08, swatch="rubber")
    G.t(sf.cyl(0.06, 0.06, loc=(0, 1.19, 0), rot=(90, 0, 0), verts=6, bevel=0.0), B, "brass")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, 0), 0.0)},
                     {"kind": "Melee", "class": ["Security", "Warden", "MadScientist"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
