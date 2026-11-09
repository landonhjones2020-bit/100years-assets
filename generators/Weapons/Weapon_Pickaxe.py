"""Weapon_Pickaxe: a melee weapon that also digs (bible Sections 6 and 27: "Also digs."); in the
Driller's kit, and a find. Prompt 14: holding Interact at a rock face with a Pickaxe (or a
Drill) digs the cell.

A Steadfast miner's pick-mattock: a long pine haft with a leather grip wrap bound by rubber
bands, a brass ferrule and a walnut butt knob; a forged steel head on a gunmetal eye collar
painted with a Steadfast Teal band, a brass wedge showing through the top of the eye; a
curved pick that sweeps down and back to a chrome point, and a broad adze blade that curls up
and back to a chrome edge.

Pivot = the grip, where the hand closes. Sockets: Grip (the pivot) and Tip (the pick's point,
for swing trails and hits). The head is at Blender -Y and the pick points down (-Z), so in
Roblox the pickaxe extends down LookVector from the hand, along the fingers, and the point
leads a downward chop.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_Pickaxe.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
from mathutils import Vector  # noqa: E402

ASSET, CATEGORY = "Weapon_Pickaxe", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.25, 0.0)
HEAD_Y = -2.3
BUTT_Y = 0.78


def build():
    q = "query"
    axis = (90, 0, 0)   # a cylinder's +Z end towards -Y (the head)

    # the haft: pine, a slim oval swelling a little towards the head
    length = BUTT_Y - (HEAD_Y - 0.12)
    haft = sf.cyl(0.1, length, loc=(0, (BUTT_Y + HEAD_Y - 0.12) / 2, 0), rot=axis, verts=8, bevel=0.0, radius_top=0.125)
    haft.scale = (0.8, 1, 1)
    sf.tag(haft, "Haft", "pine", collision=q)
    # the grip: a leather wrap held by three rubber bands, a brass ferrule and a walnut knob
    sf.tag(sf.cyl(0.125, 0.7, loc=(0, 0.27, 0), rot=axis, verts=8, bevel=0.0), "Grip", "leather", collision=q)
    for y in (0.58, 0.27, -0.04):
        sf.tag(sf.cyl(0.138, 0.06, loc=(0, y, 0), rot=axis, verts=8, bevel=0.0), "Grip", "rubber", collision=q)
    sf.tag(sf.cyl(0.13, 0.1, loc=(0, -0.13, 0), rot=axis, verts=8, bevel=0.0), "Grip", "brass", collision=q)
    sf.tag(sf.cyl(0.15, 0.16, loc=(0, BUTT_Y + 0.02, 0), rot=axis, verts=8, bevel=0.03, segments=1, radius_top=0.11),
           "Grip", "walnut", collision=q)

    # the eye collar: gunmetal round the haft, a teal band, the brass wedge on top
    sf.tag(sf.box((0.32, 0.42, 0.5), loc=(0, HEAD_Y, 0), bevel=0.06, segments=1), "Head", "gunmetal", collision=q)
    sf.tag(sf.box((0.35, 0.16, 0.53), loc=(0, HEAD_Y, 0), bevel=0.03, segments=1), "Head", "teal", collision=q)
    sf.tag(sf.box((0.12, 0.26, 0.05), loc=(0, HEAD_Y - 0.02, 0.27), bevel=0.0), "Head", "brass", collision=q)
    sf.tag(sf.box((0.16, 0.3, 0.03), loc=(0, HEAD_Y - 0.02, -0.26), bevel=0.0), "Head", "pine", collision=q)

    # the pick: forged steel sweeping down and back (towards the haft) to a chrome point
    pick = [(0, HEAD_Y - 0.02, -0.22), (0, HEAD_Y + 0.02, -0.62), (0, HEAD_Y + 0.15, -1.0),
            (0, HEAD_Y + 0.36, -1.3)]
    sf.tag(sf.tube(pick, [0.16, 0.13, 0.09, 0.05], sides=6, resolution=2, name="Pick"), "Head", "steel", collision=q)
    tip_from = Vector(pick[-1])
    tip_to = tip_from + Vector((0.0, 0.2, -0.16))
    point = sf.cyl(0.055, (tip_to - tip_from).length, loc=(tip_from + tip_to) / 2, verts=6, bevel=0.0, radius_top=0.0)
    point.rotation_euler = (tip_to - tip_from).to_track_quat("Z", "Y").to_euler()
    sf.tag(point, "Head", "chrome", collision=q)

    # the adze: a broad blade curling up and back to a chrome edge
    def side(points, thickness, x=0.0):
        # profile_slab extrudes along local Z; rot (90, 0, 90) maps local X->Y, Y->Z, Z->X
        return sf.profile_slab(points, thickness, loc=(x - thickness / 2, 0, 0), rot=(90, 0, 90), bevel=0.03, segments=1)

    y0 = HEAD_Y
    blade = [(y0 - 0.16, 0.2), (y0 - 0.15, 0.48), (y0 - 0.08, 0.74), (y0 + 0.05, 0.96), (y0 + 0.2, 1.1),
             (y0 + 0.31, 0.98), (y0 + 0.18, 0.84), (y0 + 0.11, 0.62), (y0 + 0.13, 0.36), (y0 + 0.16, 0.2)]
    sf.tag(side(blade, 0.2), "Head", "steel", collision=q)
    flare = [(y0 - 0.08, 0.74), (y0 + 0.05, 0.96), (y0 + 0.2, 1.1), (y0 + 0.31, 0.98), (y0 + 0.18, 0.84),
             (y0 + 0.11, 0.66)]
    sf.tag(side(flare, 0.36), "Head", "steel", collision=q)
    edge = [(y0 + 0.17, 1.12), (y0 + 0.31, 1.0), (y0 + 0.27, 0.96), (y0 + 0.15, 1.06)]
    sf.tag(side(edge, 0.38), "Head", "chrome", collision=q)

    tip = (0.0, round(tip_to.y, 3), round(tip_to.z, 3))
    return {"export": {
        "budget": BUDGET, "step": "P14", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Tip": (tip, 0.0)},
        "meta": {"kind": "Melee", "item": "Pickaxe", "class": ["Driller"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
