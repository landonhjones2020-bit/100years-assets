"""Tool_Drill: digs rock (bible Sections 6 and 27); the Driller's signature tool, and a find.
Prompt 14: holding Interact at a rock face with a Drill (or a Pickaxe) digs the cell; the
Driller digs twice as fast.

A heavy 1950s Steadfast rock drill: a Signal Orange enamel motor drum with gunmetal cooling
rings, a chrome trim band and a domed chrome back cap with vent slots, a Steadfast Teal badge,
a rubber carry handle on top, an amber pilot lamp, a gunmetal gearbox with a side handle
(rubber, on the item's left, for the other hand), a steel chuck with a knurled ring, and a
long auger bit (a steel core wrapped in a spiral flute) ending in a gunmetal carbide point.
The grip is the Pocket Pistol's (as the Welder's), with rubber panels, brass medallions, a
trigger guard and a Signal Orange trigger.

Pivot = the grip, where the hand closes (as the Welder). Sockets: Grip (the pivot) and Muzzle
(the bit's point, facing forward: DigController puts the rock dust there). Front (the bit)
faces Blender -Y, so in Roblox it points down LookVector.

Run:  SF_EXPORT=1 python3 generators/Weapons/Tool_Drill.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Tool_Drill", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.28, 0.15)          # as the Welder: on the grip's axis, a third of the way down
BODY_Z = 0.68                     # the motor drum's axis
BIT_FROM, BIT_TO = -0.98, -2.12   # the auger's flute
TIP_Y = -2.36


def build():
    q = "query"   # held tools: no collision, but raycasts and taps can find them
    axis = (90, 0, 0)

    # the motor drum: Signal Orange enamel, cooling rings at the back, a chrome trim band
    def band(radius, depth, y, verts=14):
        # a ring round the drum or the gearbox: a plain short cylinder (its inside never shows)
        return sf.cyl(radius, depth, loc=(0, y, BODY_Z), rot=axis, verts=verts, bevel=0.0)

    sf.tag(sf.cyl(0.31, 0.92, loc=(0, 0.2, BODY_Z), rot=axis, verts=14, bevel=0.0), "Motor", "signal", collision=q)
    for y in (0.3, 0.46):
        sf.tag(band(0.355, 0.07, y), "Motor", "gunmetal", collision=q)
    sf.tag(band(0.345, 0.1, -0.2), "Motor", "chrome", collision=q)
    # the domed chrome back cap with three vent slots
    sf.tag(sf.sphere(0.31, loc=(0, 0.66, BODY_Z), scale=(1, 0.45, 1), segs=12, rings=4), "Motor", "chrome", collision=q)
    for dz in (-0.1, 0.0, 0.1):
        sf.tag(sf.box((0.3 - abs(dz) * 0.8, 0.06, 0.035), loc=(0, 0.79, BODY_Z + dz), bevel=0.0), "Motor", "rubber", collision=q)
    # the Steadfast badge on the left side, held by two brass rivets
    sf.tag(sf.box((0.05, 0.36, 0.2), loc=(0.31, 0.05, BODY_Z), bevel=0.02, segments=1), "Badge", "teal", collision=q)
    sf.tag(sf.box((0.03, 0.26, 0.05), loc=(0.34, 0.05, BODY_Z), bevel=0.0), "Badge", "cream", collision=q)
    # the carry handle on top: rubber over chrome posts
    for y in (0.48, -0.08):
        sf.tag(sf.cyl(0.05, 0.24, loc=(0, y, BODY_Z + 0.38), verts=6, bevel=0.0), "Handle", "chrome", collision=q)
    handle = sf.tube([(0, 0.52, BODY_Z + 0.48), (0, 0.4, BODY_Z + 0.56), (0, 0.0, BODY_Z + 0.56), (0, -0.12, BODY_Z + 0.48)],
                     [0.065, 0.07, 0.07, 0.065], sides=6, resolution=2, name="Handle")
    sf.tag(handle, "Handle", "rubber", collision=q)
    # the amber pilot lamp in a chrome cup, on the drum's right shoulder
    sf.tag(sf.cyl(0.075, 0.06, loc=(-0.2, 0.42, BODY_Z + 0.22), rot=(0, -40, 0), verts=8, bevel=0.0), "Motor", "chrome", collision=q)
    sf.tag(sf.sphere(0.058, loc=(-0.23, 0.42, BODY_Z + 0.25), segs=6, rings=4), "PilotLamp", "hazard", "Neon",
           collision=q, cast_shadow=False)

    # the gearbox: gunmetal, narrowing to the chuck; a chrome collar holds the side handle
    sf.tag(band(0.25, 0.34, -0.42, verts=12), "Gearbox", "gunmetal", collision=q)
    sf.tag(sf.cyl(0.22, 0.16, loc=(0, -0.66, BODY_Z), rot=axis, verts=12, bevel=0.0, radius_top=0.15), "Gearbox", "steel", collision=q)
    sf.tag(band(0.3, 0.12, -0.44, verts=12), "Gearbox", "chrome", collision=q)
    sf.tag(sf.cyl(0.07, 0.32, loc=(0.42, -0.44, BODY_Z), rot=(0, 90, 0), verts=6, bevel=0.0), "SideHandle", "chrome", collision=q)
    sf.tag(sf.cyl(0.095, 0.46, loc=(0.78, -0.44, BODY_Z), rot=(0, 90, 0), verts=8, bevel=0.0), "SideHandle", "rubber", collision=q)
    sf.tag(sf.cyl(0.1, 0.06, loc=(1.03, -0.44, BODY_Z), rot=(0, 90, 0), verts=8, bevel=0.0), "SideHandle", "signal", collision=q)

    # the chuck: steel with a knurled gunmetal ring
    sf.tag(band(0.15, 0.26, -0.86, verts=10), "Chuck", "steel", collision=q)
    sf.tag(band(0.18, 0.08, -0.8, verts=10), "Chuck", "gunmetal", collision=q)

    # the auger: a steel core wrapped in a spiral flute, and the carbide point
    sf.tag(sf.cyl(0.06, BIT_FROM - BIT_TO + 0.1, loc=(0, (BIT_FROM + BIT_TO) / 2, BODY_Z), rot=axis, verts=6, bevel=0.0),
           "Bit", "steel", collision=q)
    turns, per_turn = 3.5, 6
    n = int(turns * per_turn) + 1
    pts, radii = [], []
    for i in range(n):
        f = i / (n - 1)
        a = f * turns * math.tau
        y = BIT_FROM + (BIT_TO - BIT_FROM) * f
        r = 0.085 if f < 0.92 else 0.085 * (1 - (f - 0.92) / 0.08 * 0.5)
        pts.append((r * math.cos(a), y, BODY_Z + r * math.sin(a)))
        radii.append(0.045)
    sf.tag(sf.tube(pts, radii, sides=3, resolution=1, name="Flute"), "Bit", "chrome", collision=q)
    sf.tag(sf.cyl(0.11, 0.26, loc=(0, BIT_TO - 0.11, BODY_Z), rot=axis, verts=6, bevel=0.0, radius_top=0.0),
           "Point", "gunmetal", collision=q)
    sf.tag(sf.cyl(0.115, 0.05, loc=(0, BIT_TO + 0.02, BODY_Z), rot=axis, verts=6, bevel=0.0), "Point", "brass", collision=q)

    # the grip: the Pocket Pistol's side profile (Y back, Z up), raking BACK about 16 degrees
    def side(points, thickness, bevel=0.04):
        # profile_slab extrudes along local Z; rot (90, 0, 90) maps local X->Y, Y->Z, Z->X
        return sf.profile_slab(points, thickness, loc=(-thickness / 2, 0, 0), rot=(90, 0, 90), bevel=bevel, segments=1)

    grip = [(0.00, 0.44), (0.03, 0.24), (0.09, 0.02), (0.16, -0.20), (0.22, -0.38), (0.25, -0.45),
            (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.56, -0.20), (0.49, 0.04), (0.43, 0.26),
            (0.41, 0.40), (0.47, 0.48), (0.40, 0.53), (0.10, 0.50)]

    def grown(points, d):
        cy = sum(p[0] for p in points) / len(points)
        cz = sum(p[1] for p in points) / len(points)
        out = []
        for y, z in points:
            vy, vz = y - cy, z - cz
            m = math.hypot(vy, vz) or 1.0
            out.append((y + vy / m * d, z + vz / m * d))
        return out

    sf.tag(side(grown(grip, 0.025), 0.16, bevel=0.0), "Grip", "gunmetal", collision=q)
    sf.tag(side(grip, 0.27), "Grip", "rubber", collision=q)
    for sx in (-1, 1):
        sf.tag(sf.cyl(0.05, 0.03, loc=(sx * 0.14, 0.3, 0.12), rot=(0, 90, 0), verts=8, bevel=0.0), "Grip", "brass", collision=q)
    base = [(0.25, -0.45), (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.585, -0.33), (0.255, -0.415)]
    sf.tag(side(grown(base, 0.012), 0.24, bevel=0.0), "Grip", "steel", collision=q)
    # the frame under the drum, the trigger guard and the trigger
    sf.tag(sf.box((0.26, 0.56, 0.16), loc=(0, 0.14, 0.42), bevel=0.03, segments=1), "Grip", "gunmetal", collision=q)
    sf.tag(sf.torus(0.16, 0.035, loc=(0, -0.08, 0.22), rot=(0, 90, 0), major_segs=10, minor_segs=3), "Grip", "gunmetal", collision=q)
    sf.tag(sf.box((0.06, 0.07, 0.18), loc=(0, -0.05, 0.25), rot=(14, 0, 0), bevel=0.0), "Grip", "signal", collision=q)
    tip = (0.0, TIP_Y + 0.02, BODY_Z)
    return {"export": {
        "budget": BUDGET, "step": "P14", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Muzzle": (tip, 0.0)},
        "meta": {"kind": "Tool", "item": "Drill", "class": ["Driller"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
