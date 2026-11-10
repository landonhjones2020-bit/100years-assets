"""Weapon_GrenadeLauncher: explosive rounds (bible Appendix); the Demolitionist's gun, held
two-handed. A revolver-drum launcher in army olive: a six-shot drum with brass chamber caps and a
hazard band, a fat olive barrel with hazard stripes, a chrome muzzle and a folding ladder sight,
a gunmetal frame, a rubber foregrip and grip, a cream stencil plate and a folding steel stock.

Pivot = the right hand's grip. Sockets: Grip, Support (the foregrip) and Muzzle. Faces
Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_GrenadeLauncher.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_GrenadeLauncher", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.6, -2.1


def build():
    L = "Launcher"
    # the drum: six chambers, brass caps on its face, a hazard band
    G.t(sf.cyl(0.37, 0.56, loc=(0, -0.3, 0.5), rot=(90, 0, 0), verts=12, bevel=0.05, segments=1), L, "olive")
    G.t(sf.cyl(0.375, 0.1, loc=(0, -0.3, 0.5), rot=(90, 0, 0), verts=12, bevel=0.0), L, "hazard")
    for i in range(6):
        a = math.radians(30 + i * 60)
        G.t(sf.cyl(0.08, 0.04, loc=(math.cos(a) * 0.22, -0.59, 0.5 + math.sin(a) * 0.22), rot=(90, 0, 0), verts=8, bevel=0.0),
            L, "brass")
    G.t(sf.cyl(0.07, 0.72, loc=(0, -0.3, 0.5), rot=(90, 0, 0), verts=8, bevel=0.0), L, "chrome")   # the axle
    # frame: a top strap over the drum and a spine back to the grip
    G.t(sf.box((0.22, 1.1, 0.12), loc=(0, -0.3, 0.92), bevel=0.03, segments=1), L, "gunmetal")
    G.t(sf.box((0.26, 0.5, 0.34), loc=(0, 0.12, 0.5), bevel=0.05, segments=1), L, "gunmetal")
    # barrel, stripes, muzzle, ladder sight, stencil plate
    G.barrel(L, 0.18, MUZZLE_Y, -0.56, BORE_Z, "olive", verts=12)
    for y in (-1.85, -1.66):
        G.band(L, 0.185, y, BORE_Z, w=0.09, swatch="hazard", verts=12)
    G.t(sf.cyl(0.21, 0.12, loc=(0, MUZZLE_Y + 0.06, BORE_Z), rot=(90, 0, 0), verts=12, bevel=0.02, segments=1), L, "chrome")
    G.t(sf.cyl(0.14, 0.1, loc=(0, MUZZLE_Y - 0.0, BORE_Z), rot=(90, 0, 0), verts=10, bevel=0.0), L, "rubber")
    for sx in (-1, 1):
        G.t(sf.box((0.03, 0.04, 0.3), loc=(sx * 0.08, -1.0, 0.92), rot=(-20, 0, 0), bevel=0.0), L, "steel")
    for i in range(3):
        G.t(sf.box((0.19, 0.03, 0.03), loc=(0, -1.0 + 0.03 * i, 0.82 + i * 0.09), bevel=0.0), L, "steel")
    G.t(sf.box((0.02, 0.36, 0.14), loc=(0.18, -1.3, BORE_Z), bevel=0.0), L, "cream")
    # foregrip, trigger guard, grip
    G.t(sf.cyl(0.09, 0.5, loc=(0, SUPPORT[1], 0.17), verts=8, bevel=0.03, segments=1), L, "rubber")
    G.t(sf.box((0.14, 0.2, 0.1), loc=(0, SUPPORT[1], 0.43), bevel=0.02, segments=1), L, "gunmetal")
    G.trigger_guard(L, 0.08, 0.24, r=0.15)
    G.pistol_grip(L, GRIP, frame="gunmetal", panel="rubber", medallion="brass")
    # folding stock: steel rails to a rubber pad, a brass hinge
    G.t(sf.cyl(0.06, 0.24, loc=(0, 0.42, 0.62), rot=(0, 90, 0), verts=8, bevel=0.0), L, "brass")
    for z0, z1 in ((0.62, 0.6), (0.48, 0.2)):
        G.t(sf.tube([(0, 0.42, z0), (0, 0.9, (z0 + z1) / 2), (0, 1.3, z1)], [0.04] * 3, sides=4, resolution=1), L, "steel")
    G.t(sf.box((0.28, 0.09, 0.52), loc=(0, 1.33, 0.42), bevel=0.03, segments=1), L, "rubber")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 3, "class": ["Demolitionist"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
