"""Weapon_HuntingKnife: fast (bible Appendix); the Marksman's melee weapon. A big bowie knife:
a steel clip-point blade with a polished edge and a fuller, a brass guard, a walnut handle with
brass rivets and a brass pommel with a lanyard hole.

Pivot = the grip. Sockets: Grip and Tip (the point). The point faces Blender -Y; the edge is on
-Z.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_HuntingKnife.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_HuntingKnife", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.22, 0.0)
TIP_Y = -1.42


def build():
    K = "Knife"
    # blade, side profile (y, z): straight spine, a clipped point, the belly curving up to it
    blade = [(-0.12, 0.13), (-0.95, 0.13), (-1.2, 0.07), (-1.42, -0.02), (-1.3, -0.1), (-1.05, -0.17),
             (-0.6, -0.2), (-0.12, -0.2)]
    G.t(G.side(blade, 0.06, bevel=0.012, segments=1), K, "steel")
    edge = [(-0.16, -0.16), (-0.6, -0.16), (-1.05, -0.13), (-1.28, -0.07), (-1.4, -0.02), (-1.3, -0.11),
            (-1.05, -0.19), (-0.6, -0.22), (-0.16, -0.22)]
    G.t(G.side(edge, 0.04, bevel=0.0), K, "chrome")
    G.t(sf.box((0.075, 0.6, 0.05), loc=(0, -0.6, 0.04), bevel=0.0), K, "gunmetal")   # fuller
    # guard and handle
    G.t(sf.box((0.16, 0.08, 0.5), loc=(0, -0.08, -0.03), bevel=0.025, segments=1), K, "brass")
    handle = [(-0.04, 0.12), (0.5, 0.11), (0.6, 0.06), (0.6, -0.16), (0.5, -0.2), (0.25, -0.17), (-0.04, -0.2)]
    G.t(G.side(handle, 0.17, bevel=0.035, segments=2), K, "walnut")
    G.rivets(K, [(sx * 0.087, y, -0.04) for sx in (-1, 1) for y in (0.06, 0.36)], r=0.035)
    G.t(sf.box((0.19, 0.12, 0.3), loc=(0, 0.64, -0.04), bevel=0.04, segments=1), K, "brass")
    G.t(sf.torus(0.06, 0.018, loc=(0, 0.7, -0.24), rot=(0, 90, 0), major_segs=8, minor_segs=4), K, "brass")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, -0.02), 0.0)}, {"kind": "Melee", "class": ["Marksman"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
