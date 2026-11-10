"""Weapon_Sledgehammer: slow, big knockback, breaks rubble (bible Appendix); the
Demolitionist's melee weapon, swung two-handed. A demolition sledge: a walnut handle with a
rubber grip and a teal Steadfast band, and a big gunmetal head with chrome striking faces,
hazard stripes round its middle and brass rivets.

Pivot = the right hand's grip. Sockets: Grip, Support (the left hand, toward the end of the
handle) and Tip (the head). The head faces Blender -Y; its faces are on +Z and -Z, so the -Z
face leads an overhead smash.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_Sledgehammer.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_Sledgehammer", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.25, 0.0)
SUPPORT = (0.0, 0.85, 0.0)
HEAD_Y = -2.0


def build():
    H = "Sledge"
    G.t(sf.cyl(0.12, 2.6, loc=(0, -0.7, 0), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), H, "walnut")
    G.wrap(H, 0.135, 0.4, 1.05, 0.0, rings=4, swatch="rubber")
    G.t(sf.cyl(0.18, 0.12, loc=(0, 1.11, 0), rot=(90, 0, 0), verts=8, bevel=0.04, segments=1), H, "rubber")
    G.band(H, 0.14, 0.3, 0.0, w=0.12, swatch="teal")
    G.band(H, 0.14, -1.52, 0.0, w=0.16, swatch="steel")
    # the head: a bevelled block standing on Z, chrome faces at both ends
    G.t(sf.box((0.62, 0.62, 1.2), loc=(0, HEAD_Y, 0), bevel=0.08, segments=1), H, "gunmetal")
    for sz in (-1, 1):
        G.t(sf.cyl(0.33, 0.14, loc=(0, HEAD_Y, sz * 0.64), verts=8, bevel=0.04, segments=1), H, "chrome")
        G.t(sf.cyl(0.3, 0.08, loc=(0, HEAD_Y, sz * 0.54), verts=8, bevel=0.0), H, "steel")
    # hazard stripes round the middle
    for i in range(4):
        G.t(sf.box((0.64, 0.64, 0.07), loc=(0, HEAD_Y, -0.18 + i * 0.12), rot=(0, 0, 0), bevel=0.0), H,
            "hazard" if i % 2 == 0 else "rubber")
    G.rivets(H, [(sx * 0.315, HEAD_Y + dy, dz) for sx in (-1, 1) for dy in (-0.18, 0.18) for dz in (-0.38, 0.38)], r=0.045)
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Tip": ((0, HEAD_Y, -0.7), 0.0)},
                     {"kind": "Melee", "hold": "Heavy", "class": ["Demolitionist"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
