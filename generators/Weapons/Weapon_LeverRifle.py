"""Weapon_LeverRifle: long range (bible Appendix); the Scout's and Marksman's gun, held
two-handed. A lever-action hunting rifle: an octagonal gunmetal barrel over a magazine tube with
brass bands, a gunmetal receiver with engraved brass side plates, a lever loop, a walnut forend
and pistol-grip stock with a rubber pad, and a steel scope with brass caps and crystal lenses.

Pivot = the right hand's grip. Sockets: Grip, Support (the left hand, under the forend) and
Muzzle. Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_LeverRifle.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_LeverRifle", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.32, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.6, -2.35


def build():
    R = "Rifle"
    # receiver with brass side plates
    G.t(sf.box((0.28, 0.86, 0.4), loc=(0, -0.06, 0.52), bevel=0.05, segments=1), R, "gunmetal")
    for sx in (-1, 1):
        G.t(sf.box((0.02, 0.5, 0.24), loc=(sx * 0.145, -0.12, 0.5), bevel=0.0), R, "brass")
    # barrel (octagonal), magazine tube, bands, sights
    G.barrel(R, 0.085, MUZZLE_Y, -0.48, BORE_Z, "gunmetal", verts=8)
    G.muzzle(R, 0.085, MUZZLE_Y, BORE_Z)
    G.barrel(R, 0.06, -2.05, -0.48, 0.44, "steel", verts=8)
    for y in (-2.15, -1.88):
        G.t(sf.box((0.2, 0.08, 0.3), loc=(0, y, 0.52), bevel=0.02, segments=1), R, "brass")
    G.bead(R, MUZZLE_Y + 0.1, BORE_Z + 0.11)
    # forend: walnut round the magazine tube (the left hand closes under it)
    G.t(sf.box((0.24, 1.28, 0.24), loc=(0, -1.16, 0.43), bevel=0.06, segments=1), R, "walnut")
    # lever loop and trigger
    G.t(sf.torus(0.17, 0.04, loc=(0, 0.08, 0.2), rot=(0, 90, 0), major_segs=8, minor_segs=3), R, "gunmetal")
    G.t(sf.box((0.06, 0.5, 0.06), loc=(0, 0.38, 0.06), rot=(-30, 0, 0), bevel=0.0), R, "gunmetal")
    G.t(sf.box((0.05, 0.06, 0.16), loc=(0, 0.1, 0.24), rot=(14, 0, 0), bevel=0.0), R, "steel")
    # grip and stock
    G.pistol_grip(R, GRIP, frame="walnut", panel="walnut", medallion=None, width=0.24)
    stock = [(0.36, 0.72), (1.22, 0.63), (1.3, 0.63), (1.33, -0.06), (1.2, -0.08), (0.66, 0.16), (0.5, 0.32)]
    G.t(G.side(stock, 0.24, bevel=0.05, segments=1), R, "walnut")
    G.t(G.side([(1.3, 0.63), (1.38, 0.63), (1.41, -0.06), (1.33, -0.06)], 0.26, bevel=0.03, segments=1), R, "rubber")
    # scope: steel tube on two mounts, brass caps, crystal lenses, a turret knob
    G.barrel(R, 0.085, -1.12, 0.26, 0.92, "steel", verts=10)
    G.t(sf.cyl(0.13, 0.26, loc=(0, -1.2, 0.92), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), R, "steel")
    G.t(sf.cyl(0.11, 0.18, loc=(0, 0.32, 0.92), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), R, "steel")
    for y, r in ((-1.34, 0.12), (0.42, 0.1)):
        G.t(sf.cyl(r, 0.04, loc=(0, y, 0.92), rot=(90, 0, 0), verts=10, bevel=0.0), R, "crystal")
        G.t(sf.torus(r, 0.02, loc=(0, y, 0.92), rot=(90, 0, 0), major_segs=8, minor_segs=3), R, "brass")
    for y in (-0.78, -0.12):
        G.t(sf.box((0.12, 0.12, 0.2), loc=(0, y, 0.8), bevel=0.02, segments=1), R, "gunmetal")
    G.t(sf.cyl(0.06, 0.1, loc=(0, -0.45, 1.02), verts=8, bevel=0.0), R, "brass")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 2, "class": ["Scout", "Marksman"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
