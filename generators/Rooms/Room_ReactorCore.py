"""Room_ReactorCore: the Reactor Core's furniture for one cell, by level (A1; bible Section 6:
power; unique; if it is destroyed the run is lost. Section 10: a Reactor overload is stopped by
three valves turned at the same time; a Blackout by resetting the fuse box here).

The bunker's heart, so it reads from across the Command View: a riveted reactor vessel on a
plinth with a glowing core band, coolant pipes to three red valve wheels (left wall, right
wall, front), a fuse box, and a control console.

    L1  steel vessel, one console, the three valves, the fuse box
    L2  adds twin coolant tanks, a gauge board and a second console
    L3  chrome vessel with a glass dome over the glowing core, an atom sign, glowing conduits

Sockets: Core, Valve1-3, FuseBox, WorkSpot1..n (2 / 3 / 4 by level), Light1.

    python3 generators/Rooms/Room_ReactorCore.py [1 2 3]   preview
    SF_EXPORT=1 python3 generators/Rooms/Room_ReactorCore.py
"""
import math

import roomlib as R
import steadfast as sf

BACK = R.BACK
CORE = (0.0, 6.0)      # vessel centre (x, y)


def vessel(level: int):
    cx, cy = CORE
    body = "steel" if level < 3 else "chrome"
    R.cy("Plinth", "gunmetal", 6.4, 1.0, (cx, cy, 0.5), collision="box", verts=12)
    R.cy("Decor", "hazard", 6.45, 0.25, (cx, cy, 0.9), verts=12)
    R.cy("Vessel", body, 5.0, 10.0, (cx, cy, 1.0 + 5.0), collision="box", verts=12)
    for z in (2.6, 9.6):                               # riveted bands
        sf_t = sf.torus(5.05, 0.28, loc=(cx, cy, z), major_segs=12, minor_segs=3)
        R.t(sf_t, "Decor", "gunmetal")
    # the glowing core band, behind a cage of bars
    R.cy("DecorNeon", "crystal", 5.08, 2.0, (cx, cy, 6.0), mat="Neon", verts=12, cast_shadow=False)
    for i in range(12):
        a = i * math.pi / 6
        R.bx("Decor", "gunmetal", (0.28, 0.28, 2.4), (cx + 5.25 * math.cos(a), cy + 5.25 * math.sin(a), 6.0))
    if level < 3:
        t = sf.sphere(5.0, loc=(cx, cy, 11.0), scale=(1, 1, 0.45), segs=12, rings=5)
        R.t(t, "Decor", body)
    else:                                              # a glass dome over the core
        R.t(sf.sphere(2.0, loc=(cx, cy, 12.0), segs=8, rings=4), "DecorNeon", "crystal", mat="Neon", cast_shadow=False)
        R.t(sf.sphere(4.3, loc=(cx, cy, 11.0), scale=(1, 1, 0.75), segs=12, rings=5), "Dome", "skyblue", mat="Glass",
            transparency=0.55, cast_shadow=False)
        R.t(sf.torus(4.4, 0.32, loc=(cx, cy, 11.0), major_segs=12, minor_segs=4), "Decor", "brass")
    # pipes up into the ceiling and back into the wall
    for dx in (-2.2, 2.2):
        R.pipe_up(cx + dx, cy + 1.5, 12.0, R.H, r=0.45, swatch="copper")
    R.pipe_run(-12.0, 12.0, BACK - 0.8, 13.0, r=0.45, swatch="steel")
    return (cx, cy, 0.0)


def valves(level: int):
    """The three overload valves: left wall, right wall, front of the vessel."""
    spots = []
    for side in (-1, 1):
        x = side * 13.0
        R.pipe_up(x, BACK - 0.8, 0.0, 13.0, r=0.4, swatch="copper")
        R.cy("Decor", "gunmetal", 0.65, 1.0, (x, BACK - 0.8, 6.0), verts=8)
        R.valve(x, BACK - 1.6, 6.0, r=0.95)
        spots.append((x, BACK - 3.0))
    # the third valve on a standpipe in front of the vessel
    vx, vy = 0.0, CORE[1] - 7.4
    R.cy("Standpipe", "copper", 0.4, 4.5, (vx, vy, 2.25), collision="box", verts=8)
    R.valve(vx, vy - 0.6, 4.0, r=0.95)
    spots.append((vx, vy - 2.0))
    return spots


def fuse_box():
    x, y, z = -15.6, -9.0, 6.0          # on the left wall, in front of the doorway
    R.bx("FuseBox", "gunmetal", (0.9, 3.2, 4.2), (x, y, z), collision="box", bevel=0.1)
    R.bx("Decor", "hazard", (0.12, 2.8, 0.4), (x + 0.5, y, z + 1.6))
    for i in range(4):
        R.bx("Decor", "cream", (0.12, 0.35, 0.9), (x + 0.5, y - 1.05 + i * 0.7, z - 0.2))
    R.bx("Decor", "signal", (0.3, 0.4, 1.2), (x + 0.6, y + 1.2, z - 1.2))       # the reset lever
    return (x + 2.0, y, 0.0)


def build(level: int) -> dict:
    core = vessel(level)
    valve_spots = valves(level)
    fuse = fuse_box()
    sockets = {"Core": (core, 0.0), "FuseBox": (fuse, 90.0)}
    for i, (x, y) in enumerate(valve_spots):
        sockets[f"Valve{i + 1}"] = ((x, y, 0.0), 0.0)
    work = [(-9.0, -9.5, 180.0)]
    R.console(-9.0, -7.6, w=5.0)
    R.stool(-9.0, -10.6)
    work.append((-2.5, -4.0, 0.0))
    R.bx("Decor", "hazard", (14.0, 14.0, 0.05), (CORE[0], CORE[1] - 0.5, 0.03))  # keep-out square
    R.bx("Decor", "rubber", (13.0, 13.0, 0.06), (CORE[0], CORE[1] - 0.5, 0.04))
    R.poster(10.5, 9.5, band="hazard", accent="rubber", w=3.0, h=3.6)         # radiation notice
    if level >= 2:
        for side in (-1, 1):                     # twin coolant tanks at the back corners
            x = side * 10.5
            R.cy(R.uid("Tank"), "mint", 1.9, 7.0, (x, 9.5, 3.5 + 0.4), collision="box", verts=10)
            R.t(sf.sphere(1.9, loc=(x, 9.5, 7.4), scale=(1, 1, 0.5), segs=10, rings=4), "Decor", "mint")
            R.t(sf.sphere(1.9, loc=(x, 9.5, 0.4), scale=(1, 1, 0.3), segs=10, rings=3), "Decor", "teal")
            R.bx("Decor", "chrome", (0.3, 0.3, 6.0), (x + side * -1.9, 9.5, 4.0))
            R.pipe_run(x, side * 4.2, 9.5, 6.5, r=0.35, swatch="copper")
        for i in range(4):                       # a gauge board on the back wall
            R.gauge(-6.0 + i * 4.0, 11.5, r=0.85)
        R.console(9.0, -7.6, w=4.4, lights=("leaf", "leaf", "signal"))
        work.append((9.0, -9.5, 180.0))
    if level >= 3:
        R.bx("Decor", "navy", (5.0, 0.15, 5.0), (0.0, BACK - 0.1, 12.0))          # atom sign
        R.t(sf.sphere(0.5, loc=(0.0, BACK - 0.35, 12.0), segs=8, rings=4), "DecorNeon", "signal", mat="Neon", cast_shadow=False)
        for a in (0, 60, 120):
            o = sf.torus(1.9, 0.09, loc=(0.0, BACK - 0.3, 12.0), rot=(90, a, 0), major_segs=10, minor_segs=3)
            R.t(o, "Decor", "chrome")
        for side in (-1, 1):                     # glowing power conduits out to the doorways
            R.bx("DecorNeon", "crystal", (9.0, 0.35, 0.08), (side * 10.5, -1.0, 0.06), mat="Neon", cast_shadow=False)
        work.append((2.5, -4.0, 0.0))
    R.work_sockets(work, sockets)
    sockets["Light1"] = ((CORE[0], CORE[1] - 4.5, 6.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_ReactorCore", "Rooms", build, {"room": "ReactorCore", "shell": "Kit_Shell"})
