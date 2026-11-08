"""Kit_BlastDoor: the Blast Door room's door and guard post, by level (A1; bible Section 6:
the entrance from the surface; holds off raids and storms; guards (Grit) stand watch here).

For the 2-cell Blast Door room on floor 1: pivot at the room's interior floor centre, between
its two cells (x -33 to 33 inside). The door sits in the back wall's middle; the lift to the
surface is behind it (Prompt 16, the SurfaceExit socket).

Not a Fallout vault door (STYLE.md): no cog, no number. A Steadfast bulkhead: two riveted
leaves that part in the middle, a hatch wheel across the seam, hydraulic rams, hazard chevrons
and a beacon.

    L1  riveted gunmetal leaves, steel frame, one beacon, a guard desk with a radio
    L2  steel X-bracing on the leaves, a heavier frame, twin beacons, a periscope at the desk
    L3  chrome-bezelled armoured leaves, a brass wheel, floodlights and a green status board

Sockets: Door (the door's foot), SurfaceExit (ceiling above the door), WorkSpot1..n (guard
spots: 2 per cell at level 1, 3 at level 2, 4 at level 3; bible Section 6), Light1-2.

    python3 generators/Kits/Kit_BlastDoor.py              preview of the three levels
    SF_EXPORT=1 python3 generators/Kits/Kit_BlastDoor.py  exports Kit_BlastDoor_L1..L3
"""
import math
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402
from kitlib import D, H, T, W, t  # noqa: E402

CATEGORY = "Kit"
BACK = D / 2
DOOR_W, DOOR_H = 14.0, 11.0      # the opening the leaves close
FRAME = 1.6


def frame(level: int):
    fw = DOOR_W + 2 * FRAME + (0.6 if level >= 2 else 0.0)
    fh = DOOR_H + FRAME
    depth = 1.4 if level < 2 else 2.0
    y = BACK - depth / 2
    sw = "steel" if level < 3 else "gunmetal"
    t(sf.box((FRAME, depth, fh), loc=(-(DOOR_W + FRAME) / 2, y, fh / 2), bevel=0.12, segments=1), "Frame", sw, collision="box")
    t(sf.box((FRAME, depth, fh), loc=((DOOR_W + FRAME) / 2, y, fh / 2), bevel=0.12, segments=1), "Frame", sw, collision="box")
    t(sf.box((fw, depth, FRAME), loc=(0, y, DOOR_H + FRAME / 2), bevel=0.12, segments=1), "Frame", sw, collision="box")
    # hazard chevrons down both jambs and across the header
    for side in (-1, 1):
        x = side * (DOOR_W + FRAME) / 2
        for i in range(5):
            z = 1.2 + i * 2.1
            t(sf.box((FRAME * 0.9, 0.1, 0.8), loc=(x, BACK - depth - 0.02, z), rot=(0, 35 * side, 0), bevel=0.0),
              "Chevrons", "hazard")
            t(sf.box((FRAME * 0.9, 0.1, 0.8), loc=(x, BACK - depth - 0.03, z + 1.05), rot=(0, 35 * side, 0), bevel=0.0),
              "Chevrons", "rubber")
    if level >= 3:      # a chrome bezel inside the frame
        for side in (-1, 1):
            t(sf.box((0.35, 0.3, DOOR_H), loc=(side * (DOOR_W / 2 + 0.15), BACK - depth - 0.1, DOOR_H / 2), bevel=0.0),
              "Bezel", "chrome")
        t(sf.box((DOOR_W + 0.6, 0.3, 0.35), loc=(0, BACK - depth - 0.1, DOOR_H + 0.15), bevel=0.0), "Bezel", "chrome")
    return depth


def leaves(level: int, depth: float):
    y = BACK - depth * 0.55
    sw = "gunmetal" if level < 3 else "steel"
    for side in (-1, 1):
        cx = side * DOOR_W / 4
        t(sf.box((DOOR_W / 2 - 0.1, 0.9, DOOR_H), loc=(cx, y, DOOR_H / 2), bevel=0.1, segments=1), "Leaves", sw, collision="box")
        for z in (2.0, 5.5, 9.0):           # steel bands with rivets
            t(sf.box((DOOR_W / 2 - 0.4, 0.2, 0.6), loc=(cx, y - 0.5, z), bevel=0.04, segments=1), "Bands", "steel")
            for k in range(4):
                x = cx - DOOR_W / 4 + 0.8 + k * (DOOR_W / 2 - 1.6) / 3
                t(sf.cyl(0.12, 0.12, loc=(x, y - 0.62, z), rot=(90, 0, 0), verts=6, bevel=0.0), "Rivets", "chrome")
        if level >= 2:                       # X-bracing
            ln = math.hypot(DOOR_W / 2 - 1.0, DOOR_H - 2.0)
            ang = math.degrees(math.atan2(DOOR_H - 2.0, DOOR_W / 2 - 1.0))
            for s2 in (-1, 1):
                t(sf.box((ln, 0.25, 0.45), loc=(cx, y - 0.55, DOOR_H / 2), rot=(0, s2 * ang, 0), bevel=0.04, segments=1),
                  "Bracing", "steel")
    # the seam and the hatch wheel across it (a ring and four spokes)
    t(sf.box((0.15, 0.2, DOOR_H), loc=(0, y - 0.46, DOOR_H / 2), bevel=0.0), "Seam", "rubber")
    wheel_sw = "steel" if level < 3 else "brass"
    t(sf.torus(1.6, 0.22, loc=(0, y - 0.9, DOOR_H * 0.52), rot=(90, 0, 0), major_segs=14, minor_segs=4), "Wheel", wheel_sw)
    t(sf.cyl(0.45, 0.6, loc=(0, y - 0.8, DOOR_H * 0.52), rot=(90, 0, 0), verts=8, bevel=0.0), "Wheel", wheel_sw)
    for a in range(4):
        t(sf.box((3.1, 0.14, 0.22), loc=(0, y - 0.88, DOOR_H * 0.52), rot=(0, 45 + a * 45, 0), bevel=0.0), "Wheel", wheel_sw)


def rams(level: int):
    """Hydraulic rams beside the door, one per side (two at level 2+)."""
    zs = (3.5,) if level < 2 else (3.0, 8.0)
    for side in (-1, 1):
        x = side * (DOOR_W / 2 + FRAME + 1.4)
        for z in zs:
            t(sf.cyl(0.55, 3.6, loc=(x, BACK - 0.9, z), rot=(0, 90, 0), verts=8, bevel=0.0), "Rams", "signal")
            t(sf.cyl(0.25, 2.4, loc=(x - side * 2.6, BACK - 0.9, z), rot=(0, 90, 0), verts=8, bevel=0.0), "Rams", "chrome")
            t(sf.box((0.6, 1.2, 1.4), loc=(x + side * 1.9, BACK - 0.6, z), bevel=0.08, segments=1), "Rams", "gunmetal")


def beacons(level: int):
    xs = (0.0,) if level == 1 else ((-4.0, 4.0) if level == 2 else (-6.0, 0.0, 6.0))
    for x in xs:
        z = DOOR_H + FRAME + 0.9
        t(sf.cyl(0.55, 0.5, loc=(x, BACK - 0.9, z - 0.55), verts=8, bevel=0.0), "BeaconBase", "gunmetal")
        t(sf.sphere(0.55, loc=(x, BACK - 0.9, z), scale=(1, 1, 1.2), segs=8, rings=4), "Beacons", "signal", mat="Neon",
          cast_shadow=False)
    # Steadfast badge plate above the door
    t(sf.box((7.0, 0.3, 1.6), loc=(0, BACK - 0.2, DOOR_H + FRAME + 2.6), bevel=0.06, segments=1), "Badge", "teal")
    t(sf.cyl(0.6, 0.12, loc=(-2.6, BACK - 0.4, DOOR_H + FRAME + 2.6), rot=(90, 0, 0), verts=10, bevel=0.0), "Badge", "signal")
    t(sf.box((4.0, 0.12, 0.35), loc=(0.6, BACK - 0.4, DOOR_H + FRAME + 2.8), bevel=0.0), "Badge", "cream")
    t(sf.box((3.0, 0.12, 0.25), loc=(0.6, BACK - 0.4, DOOR_H + FRAME + 2.3), bevel=0.0), "Badge", "cream")


def guard_post(level: int):
    """A guard desk with a radio on the left, facing the door."""
    cx, cy = -22.0, 2.0
    t(sf.box((7.0, 3.2, 2.9), loc=(cx, cy, 1.45), bevel=0.2, segments=1), "GuardDesk", "teal", collision="box")
    t(sf.box((7.3, 3.5, 0.25), loc=(cx, cy, 3.0), bevel=0.06, segments=1), "GuardDesk", "walnut", collision="box")
    t(sf.box((2.2, 1.4, 1.4), loc=(cx - 1.8, cy + 0.6, 3.8), bevel=0.15, segments=1), "Radio", "olive")
    for i in range(3):
        t(sf.cyl(0.18, 0.15, loc=(cx - 2.4 + i * 0.6, cy - 0.15, 3.6), rot=(90, 0, 0), verts=8, bevel=0.0), "Radio", "cream")
    t(sf.box((1.0, 0.1, 0.6), loc=(cx - 1.8, cy - 0.12, 4.15), bevel=0.0), "Radio", "hazard", mat="Neon", cast_shadow=False)
    t(sf.cyl(0.05, 2.0, loc=(cx - 1.0, cy + 1.0, 5.4), verts=4, bevel=0.0), "Radio", "chrome")
    t(sf.box((1.6, 1.1, 0.5), loc=(cx + 1.6, cy, 3.4), bevel=0.06, segments=1), "Logbook", "cream")
    # stool
    t(sf.cyl(0.9, 0.35, loc=(cx, cy - 3.2, 2.0), verts=10, bevel=0.0), "Stool", "rust")
    t(sf.cyl(0.12, 2.0, loc=(cx, cy - 3.2, 1.0), verts=6, bevel=0.0), "Stool", "chrome")
    t(sf.cyl(0.7, 0.12, loc=(cx, cy - 3.2, 0.06), verts=10, bevel=0.0), "Stool", "chrome")
    if level >= 2:      # a periscope up through the ceiling, to watch the surface
        t(sf.cyl(0.35, H - 4.0, loc=(cx + 2.8, cy + 0.9, 3.0 + (H - 4.0) / 2), verts=8, bevel=0.0), "Periscope", "gunmetal")
        t(sf.box((0.9, 1.4, 0.7), loc=(cx + 2.8, cy + 0.4, 5.6), bevel=0.08, segments=1), "Periscope", "gunmetal")
        t(sf.box((0.7, 0.4, 0.35), loc=(cx + 3.0, cy - 0.3, 5.6), bevel=0.0), "Periscope", "chrome")
    if level >= 3:      # a green status board on the right, and floodlights
        bx = 22.0
        t(sf.box((7.0, 0.5, 4.2), loc=(bx, BACK - 0.25, 7.0), bevel=0.08, segments=1), "StatusBoard", "gunmetal")
        for i in range(3):
            for j in range(4):
                t(sf.box((1.1, 0.12, 0.6), loc=(bx - 2.4 + j * 1.6, BACK - 0.55, 8.2 - i * 1.1), bevel=0.0),
                  "StatusLights", "glow" if (i + j) % 3 else "hazard", mat="Neon", cast_shadow=False)
        for x in (-12.0, 12.0):
            t(sf.box((1.8, 1.4, 1.2), loc=(x, BACK - 1.2, H - 2.2), rot=(25, 0, 0), bevel=0.1, segments=1), "Floodlights", "gunmetal")
            t(sf.box((1.4, 0.1, 0.9), loc=(x, BACK - 1.95, H - 2.5), rot=(25, 0, 0), bevel=0.0), "FloodlightLens", "cream",
              mat="Neon", cast_shadow=False)


def suit_up(level: int):
    """The way topside: lockers, hazmat suits on hooks, a bench and supply crates."""
    x0 = 22.6
    for i in range(3):          # lockers against the back wall
        x = x0 + i * 3.1
        t(sf.box((2.9, 2.2, 7.2), loc=(x, BACK - 1.1, 3.6), bevel=0.12, segments=1), "Lockers", "teal", collision="box")
        t(sf.box((2.5, 0.1, 6.6), loc=(x, BACK - 2.22, 3.7), bevel=0.0), "LockerDoors", "mint")
        for z in (6.4, 6.0, 5.6):
            t(sf.box((1.6, 0.12, 0.12), loc=(x, BACK - 2.3, z), bevel=0.0), "LockerDoors", "gunmetal")
        t(sf.box((0.2, 0.18, 0.9), loc=(x + 0.9, BACK - 2.32, 3.8), bevel=0.0), "LockerDoors", "chrome")
    suits = {1: 2, 2: 3, 3: 4}[level]
    for i in range(suits):      # hazmat suits on a hook rail
        x = 12.8 + i * 2.2
        t(sf.box((0.15, 0.6, 0.15), loc=(x, BACK - 0.4, 8.6), bevel=0.0), "Hooks", "chrome")
        t(sf.box((1.9, 1.0, 3.6), loc=(x, BACK - 0.85, 6.6), bevel=0.4, segments=1), "Suits", "hazard")
        t(sf.box((0.7, 0.8, 2.4), loc=(x - 0.55, BACK - 0.85, 3.6), bevel=0.25, segments=1), "Suits", "hazard")
        t(sf.box((0.7, 0.8, 2.4), loc=(x + 0.55, BACK - 0.85, 3.6), bevel=0.25, segments=1), "Suits", "hazard")
        t(sf.sphere(0.75, loc=(x, BACK - 0.9, 8.9), scale=(1, 1, 1.1), segs=8, rings=4), "Masks", "olive")
        t(sf.cyl(0.32, 0.4, loc=(x, BACK - 1.6, 8.7), rot=(90, 0, 0), verts=8, bevel=0.0), "Masks", "gunmetal")
        t(sf.box((1.2, 0.12, 0.5), loc=(x, BACK - 1.66, 9.1), bevel=0.0), "Masks", "rubber")
    t(sf.box((8.0, 1.6, 0.4), loc=(25.7, BACK - 5.0, 1.8), bevel=0.08, segments=1), "Bench", "walnut", collision="box")
    for dx in (-3.4, 3.4):
        t(sf.box((0.3, 1.4, 1.6), loc=(25.7 + dx, BACK - 5.0, 0.8), bevel=0.0), "Bench", "chrome", collision="box")
    for (x, y, z) in ((-12.5, BACK - 2.0, 1.3), (-12.5, BACK - 5.2, 1.3), (-12.5, BACK - 3.6, 3.9), (-16.0, BACK - 2.0, 1.3)):
        t(sf.box((3.0, 2.9, 2.6), loc=(x, y, z), bevel=0.12, segments=1), "Crates", "pine", collision="box")
        t(sf.box((3.04, 0.35, 2.64), loc=(x, y, z), bevel=0.0), "CrateBands", "walnut")
        t(sf.box((1.4, 0.08, 0.8), loc=(x, y - 1.47, z), bevel=0.0), "CrateBands", "teal")
    # a stencilled arrow on the floor pointing to the door
    for i in range(3):
        t(sf.box((1.0, 2.6, 0.04), loc=(-0.9, -4.0 + i * 3.6, 0.05), rot=(0, 0, -35), bevel=0.0), "FloorArrows", "hazard")
        t(sf.box((1.0, 2.6, 0.04), loc=(0.9, -4.0 + i * 3.6, 0.05), rot=(0, 0, 35), bevel=0.0), "FloorArrows", "hazard")


def threshold():
    t(sf.box((DOOR_W + 2.0, 3.0, 0.1), loc=(0, BACK - 3.0, 0.05), bevel=0.0), "Threshold", "hazard")
    for i in range(8):
        t(sf.box((0.9, 3.0, 0.04), loc=(-DOOR_W / 2 + 0.5 + i * 2.0, BACK - 3.0, 0.12), rot=(0, 0, 35), bevel=0.0),
          "Threshold", "rubber")


def build(level: int) -> dict:
    depth = frame(level)
    leaves(level, depth)
    rams(level)
    beacons(level)
    guard_post(level)
    suit_up(level)
    threshold()
    per_cell = {1: 2, 2: 3, 3: 4}[level]
    sockets = {"Door": ((0.0, BACK - 3.0, 0.0), 0.0), "SurfaceExit": ((0.0, BACK - 3.0, H), 0.0),
               "Light1": ((-17.0, 5.25, H - 1.2), 0.0), "Light2": ((17.0, 5.25, H - 1.2), 0.0)}
    spots = [(-12.0, BACK - 6.0), (12.0, BACK - 6.0), (-22.0, -2.6), (6.0, -6.0), (-6.0, -6.0), (22.0, -2.0),
             (-28.0, 8.0), (28.0, 8.0)]
    for i in range(per_cell * 2):
        x, y = spots[i]
        sockets[f"WorkSpot{i + 1}"] = ((x, y, 0.0), 0.0)
    return sockets


def preview(levels=(1, 2, 3)):
    sf.reset()
    import Kit_Shell as shell
    width = 2 * (W + 2 * T)
    for i, level in enumerate(levels):
        before = set(bpy.context.scene.objects)
        build(level)
        for dx in (-(W / 2 + T), W / 2 + T):
            b2 = set(bpy.context.scene.objects)
            shell.floor(False)
            shell.wall_y("BackWall", D / 2, -1, True, "box")
            for o in [o for o in bpy.context.scene.objects if o not in b2]:
                o.location.x += dx
        for o in [o for o in bpy.context.scene.objects if o not in before]:
            o.location.x += (i - (len(levels) - 1) / 2) * (width + 6)
    name = "Kit_BlastDoor" if len(levels) > 1 else f"Kit_BlastDoor_L{levels[0]}"
    print(sf.render_preview("Kit_BlastDoor", CATEGORY, res=720, samples=24, merge="part",
                            views=[(0, 14, False), (-28, 24, False)], out_name=name))


if __name__ == "__main__":
    if os.environ.get("SF_EXPORT") == "1":
        for level in (1, 2, 3):
            sf.reset()
            sockets = build(level)
            doc = sf.export_asset(f"Kit_BlastDoor_L{level}", CATEGORY, pivot=(0, 0, 0), merge="room", budget=6000,
                                  step="A1", sockets=sockets, meta={"kit": "blastdoor", "level": level, "cells": 2,
                                                                     "door": [DOOR_W, DOOR_H]})
            print(f"[Kit_BlastDoor_L{level}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    else:
        picked = tuple(int(a) for a in sys.argv[1:] if a.isdigit())
        preview(picked or (1, 2, 3))
