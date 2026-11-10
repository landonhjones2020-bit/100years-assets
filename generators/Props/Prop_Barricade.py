"""Prop_Barricade: an Engineer's barricade nailed over a room's vent (bible Section 14; Prompt 20:
a barricaded vent is no breach point). Four pine planks, one painted with hazard stripes, held by
two crossed gunmetal straps with brass bolts.

Pivot = the centre (the code puts it on the vent's mouth). Faces Blender -Y (the code turns it
to the room).

Run:  SF_EXPORT=1 python3 generators/Props/Prop_Barricade.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Weapons"))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Prop_Barricade", "Props"
BUDGET = 800
H = 4.3


def build():
    B = "Barricade"
    c = "box"
    planks = [(0.55, 3.0, 5.6), (1.6, -2.0, 5.3), (2.65, 1.5, 5.5), (3.7, -3.0, 5.4)]
    for i, (z, tilt, w) in enumerate(planks):
        p = G.t(sf.box((w, 0.2, 0.85), loc=(0, 0.0, z), rot=(0, tilt, 0), bevel=0.04, segments=1), B, "pine", collision=c)
        if i == 1:   # the hazard plank: yellow paint with black diagonal stripes on its face
            G.t(sf.box((w - 0.1, 0.03, 0.8), loc=(0, -0.1, z), rot=(0, tilt, 0), bevel=0.0), B, "hazard", collision=c)
            for k in range(5):
                x0, hh, sw = -2.1 + k * 1.0, 0.38, 0.32
                dx = 2 * hh * math.tan(math.radians(35))
                stripe = sf.profile_slab([(x0, -hh), (x0 + sw, -hh), (x0 + sw + dx, hh), (x0 + dx, hh)], 0.02, bevel=0.0)
                stripe.rotation_euler = (math.radians(90), math.radians(tilt), 0)
                stripe.location = (0, -0.115, z)
                G.t(stripe, B, "rubber", collision=c)
        for x in (-w / 2 + 0.3, w / 2 - 0.3):   # nail heads
            dz = math.tan(math.radians(tilt)) * x
            G.t(sf.cyl(0.05, 0.04, loc=(x, -0.12, z - dz), rot=(90, 0, 0), verts=6, bevel=0.0), B, "steel", collision=c)
    # crossed straps with brass bolts at their ends
    for sgn in (-1, 1):
        G.t(sf.box((5.7, 0.08, 0.26), loc=(0, -0.15, H / 2), rot=(0, sgn * 33, 0), bevel=0.02, segments=1), B, "gunmetal", collision=c)
        for end in (-1, 1):
            ang = math.radians(sgn * 33)
            x = end * 2.6 * math.cos(ang)
            z = H / 2 - end * 2.6 * math.sin(ang)
            G.t(sf.cyl(0.09, 0.06, loc=(x, -0.2, z), rot=(90, 0, 0), verts=6, bevel=0.0), B, "brass", collision=c)
    return {"export": {"budget": BUDGET, "step": "P20", "pivot": (0, 0, H / 2), "meta": {"kind": "Device", "class": ["Engineer"]}}}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
