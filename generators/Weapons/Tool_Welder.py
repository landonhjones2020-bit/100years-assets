"""Tool_Welder: repairs rooms (bible Section 27); the Engineer's and the Tinkerer's kit, and
craftable (Recipes: Welder). Prompt 13: it repairs the room it points at, WelderPerSecond (the
Engineer twice as fast), with sparks and a blue-white light at its nozzle.

A chunky 1950s arc-welding gun: a rounded teal enamel housing (Steadfast's colour) with a
chrome trim band, gunmetal cooling fins and a glowing pilot lamp, a chrome back cap, a copper
swan neck that dips to a brass nozzle with a gunmetal contact tip, a round chrome spark shield
where the neck leaves the housing, and a Hazard Yellow power cell slung under the front with
gunmetal end caps and a brass valve. The grip is the Pocket Pistol's (its v2 side profile:
it rakes BACK about 16 degrees, the butt behind its top), with rubber panels, brass
medallions, a trigger guard and a trigger.

Pivot = the grip, where the hand closes (a third of the way down the grip, on its axis).
Sockets: Grip (the pivot) and Muzzle (the contact tip, facing forward: DisasterController puts
the sparks and the light there). Front (the nozzle) faces Blender -Y, so in Roblox it points
down LookVector.

Run:  SF_EXPORT=1 python3 generators/Weapons/Tool_Welder.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Tool_Welder", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.28, 0.15)          # as the Pocket Pistol: on the grip's axis, a third of the way down
BODY_Z = 0.64
TIP = (0.0, -1.78, 0.42)


def build():
    q = "query"   # held tools: no collision, but raycasts and taps can find them
    # the housing: rounded teal enamel, a chrome trim band, fins on top, a chrome back cap
    sf.tag(sf.box((0.46, 1.05, 0.5), loc=(0, -0.12, BODY_Z), bevel=0.14, segments=2), "Body", "teal", collision=q)
    sf.tag(sf.box((0.5, 0.1, 0.54), loc=(0, -0.38, BODY_Z), bevel=0.04, segments=1), "Body", "chrome", collision=q)
    for i in range(3):
        sf.tag(sf.box((0.32, 0.06, 0.1), loc=(0, 0.02 + i * 0.13, BODY_Z + 0.27), bevel=0.0), "Body", "gunmetal", collision=q)
    sf.tag(sf.cyl(0.19, 0.1, loc=(0, 0.43, BODY_Z), rot=(90, 0, 0), verts=12, bevel=0.0), "Body", "chrome", collision=q)
    sf.tag(sf.cyl(0.08, 0.06, loc=(0, 0.49, BODY_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Body", "gunmetal", collision=q)
    # the pilot lamp: a blue-white bulb in a chrome cup on top at the back
    sf.tag(sf.cyl(0.08, 0.06, loc=(0, 0.33, BODY_Z + 0.27), verts=8, bevel=0.0), "Body", "chrome", collision=q)
    sf.tag(sf.sphere(0.065, loc=(0, 0.33, BODY_Z + 0.32), segs=8, rings=4), "PilotLamp", "crystal", "Neon",
           collision=q, cast_shadow=False)
    # the spark shield: a round chrome disc round the neck's root
    sf.tag(sf.cyl(0.3, 0.04, loc=(0, -0.7, BODY_Z - 0.02), rot=(90, 0, 0), verts=16, bevel=0.0), "Shield", "chrome", collision=q)
    sf.tag(sf.cyl(0.13, 0.12, loc=(0, -0.68, BODY_Z - 0.02), rot=(90, 0, 0), verts=10, bevel=0.0), "Shield", "gunmetal", collision=q)
    # the swan neck: copper, dipping forward to the nozzle
    neck = sf.tube([(0, -0.62, BODY_Z - 0.02), (0, -1.0, BODY_Z - 0.02), (0, -1.32, 0.56), (0, -1.55, 0.47)],
                   [0.085, 0.085, 0.085, 0.085], sides=8, resolution=2, name="Neck")
    sf.tag(neck, "Neck", "copper", collision=q)
    # the nozzle: a brass cone along the neck's last stretch, and the gunmetal contact tip
    dy, dz = TIP[1] - (-1.55), TIP[2] - 0.47
    tilt = math.degrees(math.atan2(-dz, -dy))           # how far the nozzle dips below level
    sf.tag(sf.cyl(0.14, 0.26, loc=(0, -1.6, 0.455), rot=(90 + tilt, 0, 0), verts=12, bevel=0.0, radius_top=0.1),
           "Nozzle", "brass", collision=q)
    sf.tag(sf.cyl(0.04, 0.16, loc=(0, -1.72, 0.435), rot=(90 + tilt, 0, 0), verts=6, bevel=0.0), "Nozzle", "gunmetal", collision=q)
    # the power cell, slung under the front: Hazard Yellow, gunmetal end caps, a brass valve
    sf.tag(sf.cyl(0.16, 0.66, loc=(0, -0.66, 0.26), rot=(90, 0, 0), verts=14, bevel=0.03, segments=1), "Cell", "hazard", collision=q)
    for y in (-0.33, -0.99):
        sf.tag(sf.cyl(0.17, 0.07, loc=(0, y, 0.26), rot=(90, 0, 0), verts=14, bevel=0.0), "Cell", "gunmetal", collision=q)
    sf.tag(sf.box((0.12, 0.5, 0.1), loc=(0, -0.66, 0.42), bevel=0.0), "Cell", "gunmetal", collision=q)
    sf.tag(sf.cyl(0.05, 0.12, loc=(-0.2, -0.85, 0.26), rot=(0, 90, 0), verts=8, bevel=0.0), "Cell", "brass", collision=q)

    # the grip: the Pocket Pistol's side profile (Y back, Z up), raking BACK about 16 degrees
    def side(points, thickness):
        # profile_slab extrudes along local Z; rot (90, 0, 90) maps local X->Y, Y->Z, Z->X
        return sf.profile_slab(points, thickness, loc=(-thickness / 2, 0, 0), rot=(90, 0, 90), bevel=0.04, segments=1)

    grip = [(0.00, 0.44), (0.03, 0.24), (0.09, 0.02), (0.16, -0.20), (0.22, -0.38), (0.25, -0.45),
            (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.56, -0.20), (0.49, 0.04), (0.43, 0.26),
            (0.41, 0.40), (0.47, 0.48), (0.40, 0.53), (0.10, 0.50)]

    def grown(points, d):
        cy = sum(p[0] for p in points) / len(points)
        cz = sum(p[1] for p in points) / len(points)
        out = []
        for y, z in points:
            vy, vz = y - cy, z - cz
            n = math.hypot(vy, vz) or 1.0
            out.append((y + vy / n * d, z + vz / n * d))
        return out

    sf.tag(side(grown(grip, 0.025), 0.16), "Grip", "gunmetal", collision=q)
    sf.tag(side(grip, 0.27), "Grip", "rubber", collision=q)
    for sx in (-1, 1):
        sf.tag(sf.cyl(0.05, 0.03, loc=(sx * 0.14, 0.3, 0.12), rot=(0, 90, 0), verts=10, bevel=0.0), "Grip", "brass", collision=q)
    base = [(0.25, -0.45), (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.585, -0.33), (0.255, -0.415)]
    sf.tag(side(grown(base, 0.012), 0.24), "Grip", "steel", collision=q)
    # the frame under the housing, the trigger guard and the trigger
    sf.tag(sf.box((0.26, 0.5, 0.14), loc=(0, 0.12, 0.4), bevel=0.03, segments=1), "Grip", "gunmetal", collision=q)
    sf.tag(sf.torus(0.16, 0.035, loc=(0, -0.08, 0.22), rot=(0, 90, 0), major_segs=10, minor_segs=4), "Grip", "gunmetal", collision=q)
    sf.tag(sf.box((0.06, 0.07, 0.18), loc=(0, -0.05, 0.25), rot=(14, 0, 0), bevel=0.0), "Grip", "signal", collision=q)
    return {"export": {
        "budget": BUDGET, "step": "P13", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Muzzle": (TIP, 0.0)},
        "meta": {"kind": "Tool", "item": "Welder", "class": ["Engineer", "Tinkerer"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
