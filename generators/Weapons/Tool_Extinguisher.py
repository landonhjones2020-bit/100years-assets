"""Tool_Extinguisher: puts out fires (bible Section 27); the Firefighter's kit and the Fire Chief
Legend's gear, and anyone can carry one (Prompt 13: ExtinguisherPerSecond, the Firefighter 3x).
A chunky 1950s CO2 extinguisher: a Rust Red tank with a domed top and bottom on a gunmetal foot
ring, a cream instruction band with navy trim and a teal Steadfast diamond, a brass neck, a
chrome valve head with a squeeze lever and carry handle, a brass pressure gauge with a cream
face, a safety pin with a Hazard Yellow tag, and the period's big black horn on a swivel arm,
pointing forward.

v2 (Prompt 13 playtest, Nov 9): built at 0.8 scale (SCALE), so on a classic avatar the tank
hangs to mid-shin instead of the floor and clears the right thigh.

How it is held: tools use the gun's hold pose (CombatController, forearm forward at the hip),
so the fist's grip runs vertically. The hand closes round the brass neck under the valve
head, the tank hangs below the fist (its bottom near the knee, clear of the legs: the hand is
about 1.8 studs in front of the shoulder) and the horn points forward over the fist, like
carrying an extinguisher by its top and aiming the horn.

Pivot = the grip, where the hand closes (on the neck's axis). Sockets: Grip (the pivot) and
Muzzle (the horn's mouth, facing forward: DisasterController sprays the foam from it). Front
(the horn) faces Blender -Y, so in Roblox it points down LookVector.

Run:  SF_EXPORT=1 python3 generators/Weapons/Tool_Extinguisher.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Tool_Extinguisher", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.0, 0.0)            # on the brass neck's axis, where the fist closes
HORN_Z = 0.33                     # the horn's axis, just over the fist
MOUTH_Y = -1.5
R = 0.48                          # the tank's radius (before SCALE)
SCALE = 0.8                       # the whole tool, about the grip (v2: the first build was too big in hand)


def build():
    q = "query"   # held tools: no collision, but raycasts and taps can find them
    # the tank: a Rust Red cylinder with domed ends (lathe profile, radius by height)
    tank = [(0.0, -2.22), (0.22, -2.2), (0.38, -2.14), (R, -2.03), (R, -0.86), (R - 0.03, -0.68),
            (R - 0.11, -0.53), (0.28, -0.42), (0.17, -0.36)]
    sf.tag(sf.lathe(tank, verts=16), "Tank", "rust", collision=q)
    sf.tag(sf.cyl(R + 0.03, 0.16, loc=(0, 0, -2.11), verts=16, bevel=0.03, segments=1), "Tank", "gunmetal", collision=q)
    # the instruction band: cream, navy trim, a teal Steadfast diamond on the right (-X) side
    sf.tag(sf.cyl(R + 0.012, 0.6, loc=(0, 0, -1.4), verts=16, bevel=0.0), "Tank", "cream", collision=q)
    for z in (-1.72, -1.08):
        sf.tag(sf.cyl(R + 0.018, 0.05, loc=(0, 0, z), verts=16, bevel=0.0), "Tank", "navy", collision=q)
    sf.tag(sf.box((0.04, 0.24, 0.24), loc=(-R - 0.02, 0.0, -1.4), rot=(45, 0, 0), bevel=0.0), "Tank", "teal", collision=q)
    sf.tag(sf.box((0.05, 0.1, 0.1), loc=(-R - 0.03, 0.0, -1.4), rot=(45, 0, 0), bevel=0.0), "Tank", "cream", collision=q)
    # the neck (the fist closes here) and a chrome collar where it meets the tank
    sf.tag(sf.cyl(0.17, 0.56, loc=(0, 0, -0.08), verts=12, bevel=0.0), "Valve", "brass", collision=q)
    sf.tag(sf.cyl(0.22, 0.08, loc=(0, 0, -0.34), verts=12, bevel=0.0), "Valve", "chrome", collision=q)
    # the valve head: chrome, with the horn's swivel arm out of its front
    sf.tag(sf.box((0.36, 0.5, 0.28), loc=(0, -0.02, HORN_Z), bevel=0.06, segments=1), "Valve", "chrome", collision=q)
    sf.tag(sf.cyl(0.08, 0.36, loc=(0, -0.42, HORN_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Valve", "chrome", collision=q)
    sf.tag(sf.sphere(0.12, loc=(0, -0.6, HORN_Z), segs=8, rings=4), "Valve", "brass", collision=q)
    # the horn: a big black cone, flaring forward, with a rim at the mouth
    sf.tag(sf.cyl(0.1, 0.84, loc=(0, -0.66 - 0.42, HORN_Z), rot=(90, 0, 0), verts=14, bevel=0.0, radius_top=0.33),
           "Horn", "rubber", collision=q)
    sf.tag(sf.torus(0.32, 0.04, loc=(0, MOUTH_Y + 0.02, HORN_Z), rot=(90, 0, 0), major_segs=14, minor_segs=4),
           "Horn", "gunmetal", collision=q)
    # the squeeze lever over the head (rubber tip at the back) and the carry handle behind it
    sf.tag(sf.box((0.13, 0.78, 0.07), loc=(0, 0.12, HORN_Z + 0.2), rot=(-7, 0, 0), bevel=0.02, segments=1),
           "Valve", "gunmetal", collision=q)
    sf.tag(sf.box((0.16, 0.24, 0.1), loc=(0, 0.42, HORN_Z + 0.24), rot=(-7, 0, 0), bevel=0.03, segments=1),
           "Valve", "rubber", collision=q)
    sf.tag(sf.box((0.14, 0.5, 0.07), loc=(0, 0.42, HORN_Z - 0.04), bevel=0.02, segments=1), "Valve", "gunmetal", collision=q)
    # the pressure gauge on the right (-X) side of the head: brass bezel, cream face, red needle
    sf.tag(sf.cyl(0.12, 0.05, loc=(-0.2, 0.02, HORN_Z), rot=(0, 90, 0), verts=12, bevel=0.0), "Gauge", "brass", collision=q)
    sf.tag(sf.cyl(0.095, 0.05, loc=(-0.215, 0.02, HORN_Z), rot=(0, 90, 0), verts=12, bevel=0.0), "Gauge", "cream", collision=q)
    sf.tag(sf.box((0.02, 0.02, 0.08), loc=(-0.243, 0.0, HORN_Z + 0.02), rot=(35, 0, 0), bevel=0.0), "Gauge", "rust", collision=q)
    # the safety pin on the left (+X) side, with its Hazard Yellow tag
    sf.tag(sf.torus(0.07, 0.016, loc=(0.2, 0.12, HORN_Z + 0.04), rot=(0, 90, 0), major_segs=8, minor_segs=3),
           "Valve", "chrome", collision=q)
    sf.tag(sf.box((0.025, 0.16, 0.2), loc=(0.21, 0.14, HORN_Z - 0.16), rot=(8, 0, 0), bevel=0.0), "Tag", "hazard", collision=q)
    for o in bpy.context.scene.objects:   # everything about the grip (the origin)
        if o.get("sf_part"):
            o.location = o.location * SCALE
            o.scale = o.scale * SCALE
    return {"export": {
        "budget": BUDGET, "step": "P13", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Muzzle": ((0, (MOUTH_Y - 0.02) * SCALE, HORN_Z * SCALE), 0.0)},
        "meta": {"kind": "Tool", "item": "Extinguisher", "class": ["Firefighter"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
