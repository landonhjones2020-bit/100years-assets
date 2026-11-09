"""Weapon_Wrench: fast and light (bible Section 27); the Survivor's and Quartermaster's melee
weapon. A big 1950s combination wrench: a chrome I-beam shaft with a teal enamel stripe, an open
jaw at the head (the striking end), a box-end ring behind the grip, and a rubber handle wrap with
a brass ferrule.

Pivot = the grip, where the hand closes. Sockets: Grip (the pivot) and Tip (the jaw, for swing
trails). The head faces Blender -Y, so in Roblox the wrench extends down LookVector from the
hand: along the fingers, and forward in a swing.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_Wrench.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Weapon_Wrench", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.25, 0.0)
HEAD_Y = -1.95


def build():
    q = "query"
    # shaft: chrome I-beam with a teal stripe on each side
    sf.tag(sf.box((0.12, 2.1, 0.32), loc=(0, -0.9, 0), bevel=0.04, segments=1), "Wrench", "chrome", collision=q)
    sf.tag(sf.box((0.2, 1.4, 0.08), loc=(0, -0.95, 0.14), bevel=0.02), "Wrench", "chrome", collision=q)
    sf.tag(sf.box((0.2, 1.4, 0.08), loc=(0, -0.95, -0.14), bevel=0.02), "Wrench", "chrome", collision=q)
    for sx in (-1, 1):
        sf.tag(sf.box((0.02, 1.0, 0.14), loc=(sx * 0.07, -1.0, 0), bevel=0.0), "Wrench", "teal", collision=q)
    # open jaw at the head: a broad plate with a U cut, two prongs
    jaw = sf.box((0.18, 0.6, 0.78), loc=(0, HEAD_Y, 0), bevel=0.06, segments=1)
    cut = sf.box((0.4, 0.5, 0.36), loc=(0, HEAD_Y - 0.2, 0), bevel=0.0)
    sf.boolean(jaw, cut)
    sf.tag(jaw, "Wrench", "chrome", collision=q)
    sf.tag(sf.cyl(0.05, 0.2, loc=(0, HEAD_Y + 0.12, 0.0), rot=(0, 90, 0), verts=8, bevel=0.0), "Wrench", "steel", collision=q)
    # box-end ring behind the grip
    sf.tag(sf.ring(0.12, 0.26, 0.16, loc=(0, 0.9, 0), rot=(0, 90, 0), verts=12), "Wrench", "chrome", collision=q)
    # rubber handle wrap and a brass ferrule
    sf.tag(sf.box((0.2, 0.62, 0.38), loc=(0, 0.3, 0), bevel=0.07, segments=1), "Wrench", "rubber", collision=q)
    sf.tag(sf.box((0.22, 0.08, 0.4), loc=(0, -0.04, 0), bevel=0.02), "Wrench", "brass", collision=q)
    sf.tag(sf.box((0.22, 0.08, 0.4), loc=(0, 0.64, 0), bevel=0.02), "Wrench", "brass", collision=q)
    return {"export": {
        "budget": BUDGET, "step": "P11", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Tip": ((0, HEAD_Y - 0.3, 0), 0.0)},
        "meta": {"kind": "Melee", "class": ["Survivor", "Quartermaster"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
