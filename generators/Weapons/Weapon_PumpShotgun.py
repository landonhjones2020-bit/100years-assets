"""Weapon_PumpShotgun: close range, 8 pellets (bible Appendix); the Quartermaster's, Driller's
and Spelunker's gun, held two-handed. A riot pump gun: a gunmetal receiver with a teal Steadfast
plate and brass shells in a side saddle, a steel barrel over a magazine tube, a grooved walnut
pump, a brass bead, and a walnut stock and pistol grip with a rubber butt pad.

Pivot = the right hand's grip. Sockets: Grip, Support (the left hand, under the pump: the
shared long-gun offset in _gunkit) and Muzzle. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_PumpShotgun.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_PumpShotgun", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.6, -2.2


def build():
    S = "Shotgun"
    # receiver, ejection port, Steadfast plate, side saddle of shells
    G.t(sf.box((0.32, 0.86, 0.4), loc=(0, -0.05, 0.52), bevel=0.06, segments=1), S, "gunmetal")
    G.t(sf.box((0.02, 0.32, 0.14), loc=(0.16, -0.18, 0.6), bevel=0.0), S, "rubber")
    G.t(sf.box((0.02, 0.26, 0.1), loc=(0.16, 0.16, 0.48), bevel=0.0), S, "teal")
    G.t(sf.box((0.06, 0.5, 0.2), loc=(-0.18, -0.1, 0.5), bevel=0.02, segments=1), S, "rubber")
    for i in range(4):
        G.t(sf.cyl(0.045, 0.22, loc=(-0.22, -0.28 + i * 0.12, 0.5), verts=6, bevel=0.0), S, "rust")
        G.t(sf.cyl(0.048, 0.05, loc=(-0.22, -0.28 + i * 0.12, 0.38), verts=6, bevel=0.0), S, "brass")
    # barrel over the magazine tube, muzzle and bead
    G.barrel(S, 0.1, MUZZLE_Y, -0.46, BORE_Z, "steel")
    G.muzzle(S, 0.1, MUZZLE_Y, BORE_Z)
    G.barrel(S, 0.08, -1.95, -0.46, 0.39, "gunmetal")
    G.t(sf.cyl(0.085, 0.06, loc=(0, -1.97, 0.39), rot=(90, 0, 0), verts=8, bevel=0.0), S, "chrome")
    G.t(sf.box((0.12, 0.1, 0.24), loc=(0, -1.85, 0.5), bevel=0.0), S, "gunmetal")     # barrel clamp
    G.bead(S, MUZZLE_Y + 0.1, BORE_Z + 0.12)
    # the pump: walnut with rubber grooves, where the left hand closes
    G.t(sf.cyl(0.17, 0.66, loc=(0, -0.84, 0.38), rot=(90, 0, 0), verts=10, bevel=0.04, segments=1), S, "walnut")
    for i in range(4):
        G.t(sf.cyl(0.176, 0.05, loc=(0, -1.07 + i * 0.15, 0.38), rot=(90, 0, 0), verts=10, bevel=0.0), S, "rubber")
    # trigger guard, pistol grip and stock with a rubber pad
    G.trigger_guard(S, 0.06, 0.24, r=0.15)
    G.pistol_grip(S, GRIP, frame="gunmetal", panel="walnut", medallion="brass")
    stock = [(0.38, 0.7), (1.2, 0.65), (1.3, 0.65), (1.33, -0.06), (1.2, -0.1), (0.66, 0.16), (0.5, 0.3)]
    G.t(G.side(stock, 0.26, bevel=0.05, segments=1), S, "walnut")
    G.t(G.side([(1.3, 0.65), (1.39, 0.65), (1.42, -0.06), (1.33, -0.06)], 0.28, bevel=0.03, segments=1), S, "rubber")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 2, "class": ["Quartermaster", "Driller", "Spelunker"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
