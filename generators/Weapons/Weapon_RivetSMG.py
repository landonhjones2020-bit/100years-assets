"""Weapon_RivetSMG: fast fire, light ammo (bible Appendix); the Engineer's, Hazmat Tech's,
Scavenger's and Tinkerer's gun, held two-handed. A Steadfast rivet gun turned submachine gun: a
teal enamel body with a chrome trim strip and brass rivets, a chrome cooling shroud, a flat
brass rivet pan on top with a chrome hub, a rubber vertical foregrip, a red cocking knob and a
steel wire stock.

Pivot = the right hand's grip. Sockets: Grip, Support (the left hand, on the foregrip) and
Muzzle. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_RivetSMG.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_RivetSMG", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.58, -2.05


def build():
    M = "RivetSMG"
    G.t(sf.box((0.36, 1.25, 0.46), loc=(0, -0.32, 0.56), bevel=0.1, segments=1), M, "teal")
    for sx in (-1, 1):
        G.t(sf.box((0.02, 1.05, 0.06), loc=(sx * 0.18, -0.3, 0.66), bevel=0.0), M, "chrome")
    G.rivets(M, [(sx * 0.18, -0.8 + i * 0.36, 0.44) for sx in (-1, 1) for i in range(3)], r=0.03)
    G.t(sf.cyl(0.07, 0.12, loc=(-0.24, 0.0, 0.62), rot=(0, 90, 0), verts=8, bevel=0.0), M, "signal")   # cocking knob
    # shroud with cooling slots, then the barrel tip
    G.barrel(M, 0.15, -1.85, -0.92, BORE_Z, "chrome", verts=10)
    for sx in (-1, 1):
        for i in range(3):
            G.t(sf.box((0.02, 0.14, 0.08), loc=(sx * 0.15, -1.7 + i * 0.3, BORE_Z), bevel=0.0), M, "rubber")
    G.barrel(M, 0.07, MUZZLE_Y, -1.85, BORE_Z, "gunmetal", verts=8, bevel=0.0)
    G.muzzle(M, 0.07, MUZZLE_Y, BORE_Z)
    G.t(sf.torus(0.08, 0.02, loc=(0, 0.22, 0.93), rot=(90, 0, 0), major_segs=8, minor_segs=3), M, "chrome")  # ring sight
    G.t(sf.box((0.04, 0.04, 0.14), loc=(0, 0.22, 0.84), bevel=0.0), M, "chrome")
    G.t(sf.box((0.05, 0.05, 0.12), loc=(0, -1.8, 0.78), bevel=0.0), M, "gunmetal")
    # the rivet pan: a flat brass drum on top (the left hand needs the underside), a chrome hub
    # and rivet heads round it
    G.t(sf.box((0.12, 0.3, 0.1), loc=(0, -0.38, 0.8), bevel=0.0), M, "gunmetal")
    G.t(sf.cyl(0.42, 0.16, loc=(0, -0.38, 0.9), verts=12, bevel=0.04, segments=1), M, "brass")
    G.t(sf.cyl(0.13, 0.08, loc=(0, -0.38, 1.0), verts=8, bevel=0.0), M, "chrome")
    for i in range(6):
        a = math.radians(i * 60)
        G.t(sf.cyl(0.035, 0.03, loc=(math.cos(a) * 0.28, -0.38 + math.sin(a) * 0.28, 0.985), verts=6, bevel=0.0), M, "gunmetal")
    # foregrip, trigger guard, pistol grip
    G.t(sf.cyl(0.09, 0.5, loc=(0, SUPPORT[1], 0.18), verts=8, bevel=0.03, segments=1), M, "rubber")
    G.t(sf.box((0.14, 0.18, 0.08), loc=(0, SUPPORT[1], 0.42), bevel=0.02, segments=1), M, "gunmetal")
    G.trigger_guard(M, 0.05, 0.24, r=0.15)
    G.pistol_grip(M, GRIP, frame=None, panel="rubber", medallion="brass")
    # wire stock: two steel rails and a lower strut to a rubber pad
    for sx in (-1, 1):
        G.t(sf.tube([(sx * 0.1, 0.3, 0.66), (sx * 0.1, 0.8, 0.62), (sx * 0.1, 1.25, 0.58)], [0.035] * 3, sides=4, resolution=1), M, "steel")
    G.t(sf.tube([(0, 0.62, 0.18), (0, 0.95, 0.26), (0, 1.25, 0.3)], [0.035] * 3, sides=4, resolution=1), M, "steel")
    G.t(sf.box((0.28, 0.08, 0.5), loc=(0, 1.29, 0.44), bevel=0.03, segments=1), M, "rubber")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 1,
                      "class": ["Engineer", "HazmatTech", "Scavenger", "Tinkerer"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
