"""Weapon_ArcRifle: arcs jump between enemies (bible Appendix); the Mad Scientist's gun
(Legendary), held two-handed. A 1950s ray rifle: a streamlined porcelain body with plum fins, a
glowing coil core wound with copper rings between chrome rails, a brass dish and three chrome
prongs round a crystal emitter (Neon), a brass gauge, a rubber foregrip and grip, and a
porcelain skeleton stock with a plum pad.

Pivot = the right hand's grip. Sockets: Grip, Support (the foregrip) and Muzzle (the emitter).
Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_ArcRifle.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_ArcRifle", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.58, -1.98


def build():
    A = "ArcRifle"
    # streamlined body along -Y (a lathe from the back forward)
    G.t(sf.lathe([(0.0, 0.0), (0.16, 0.0), (0.27, 0.22), (0.31, 0.55), (0.27, 0.9), (0.17, 1.2), (0.0, 1.2)], verts=10,
                 loc=(0, 0.5, BORE_Z), rot=(90, 0, 0)), A, "porcelain")
    G.band(A, 0.315, -0.05, BORE_Z, w=0.08, swatch="chrome", verts=12)
    # fins: a dorsal fin and two side fins at the back
    G.t(G.side([(0.3, 0.8), (-0.2, 0.86), (-0.35, 0.82), (0.05, 1.12), (0.42, 1.18), (0.5, 1.12)], 0.06, bevel=0.015, segments=1), A, "plum")
    for sx in (-1, 1):
        fin = sf.profile_slab([(0.25, 0.0), (-0.15, 0.0), (0.15, 0.32), (0.4, 0.34)], 0.05,
                              loc=(sx * 0.24, 0.0, BORE_Z - 0.05), rot=(0, 0, 0), bevel=0.015, segments=1)
        fin.rotation_euler = (math.radians(sx * 12), 0, math.radians(-sx * 90))
        fin.location = (sx * 0.26, 0.05, BORE_Z - 0.02)
        G.t(fin, A, "plum")
    # the coil core between two chrome rails
    G.t(sf.cyl(0.09, 0.82, loc=(0, -1.16, BORE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Core", "glow", "Neon")
    for i in range(4):
        G.t(sf.torus(0.15, 0.03, loc=(0, -0.92 - i * 0.16, BORE_Z), rot=(90, 0, 0), major_segs=8, minor_segs=3), A, "copper")
    for dz in (0.19, -0.19):
        G.t(sf.box((0.08, 1.1, 0.06), loc=(0, -1.13, BORE_Z + dz), bevel=0.02, segments=1), A, "chrome")
    # emitter: a brass dish, a chrome ring, three prongs and the crystal
    G.t(sf.lathe([(0.06, 0.0), (0.2, 0.1), (0.24, 0.16), (0.0, 0.12)], verts=10, loc=(0, -1.6, BORE_Z), rot=(90, 0, 0)), A, "brass")
    G.t(sf.torus(0.2, 0.03, loc=(0, -1.78, BORE_Z), rot=(90, 0, 0), major_segs=8, minor_segs=3), A, "chrome")
    for i in range(3):
        a = math.radians(90 + i * 120)
        G.t(sf.box((0.04, 0.3, 0.04), loc=(math.cos(a) * 0.17, -1.86, BORE_Z + math.sin(a) * 0.17), bevel=0.0), A, "chrome")
    G.t(sf.sphere(0.09, loc=(0, -1.88, BORE_Z), segs=6, rings=4), "Emitter", "crystal", "Neon")
    # a brass gauge on the right side of the body
    G.t(sf.cyl(0.11, 0.05, loc=(0.29, -0.2, BORE_Z + 0.06), rot=(0, 90, 0), verts=8, bevel=0.0), A, "brass")
    G.t(sf.cyl(0.09, 0.02, loc=(0.315, -0.2, BORE_Z + 0.06), rot=(0, 90, 0), verts=8, bevel=0.0), A, "cream")
    # foregrip under the lower rail, trigger guard and grip
    G.t(sf.cyl(0.085, 0.42, loc=(0, SUPPORT[1], 0.19), verts=8, bevel=0.03, segments=1), A, "rubber")
    G.trigger_guard(A, 0.05, 0.24, r=0.15, swatch="chrome")
    G.pistol_grip(A, GRIP, frame="chrome", panel="rubber", medallion="brass")
    # skeleton stock
    stock = [(0.45, 0.66), (1.42, 0.58), (1.55, 0.54), (1.55, 0.02), (1.42, -0.04), (1.22, 0.16), (1.26, 0.42), (0.62, 0.4)]
    G.t(G.side(stock, 0.18, bevel=0.04, segments=1), A, "porcelain")
    G.t(G.side([(1.55, 0.56), (1.63, 0.56), (1.65, 0.0), (1.55, 0.0)], 0.22, bevel=0.03, segments=1), A, "plum")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 2, "class": ["MadScientist"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
