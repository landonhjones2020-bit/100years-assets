"""Lobby_BunkerCutaway: "A cutaway model of the bunker in the showroom window" (bible Section 21;
A9). A slice of Brightwater on a walnut plinth: a lawn, a house and the shelter's hatch on top;
under them three floors of rooms cut open (quarters, kitchen, lounge; workshop, garden, storage;
water, reactor, pumps), the lift in its shaft, people the size of a thumb.

Origin: the plinth's centre on the floor; the open side faces -Y (the street's window).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402

PL = 2.0                     # the plinth's top
BX, BY = 6.6, 2.6            # the block's half width and half depth
Z0 = PL                      # the block's foot
ROOM_H = 2.4
SLAB = 0.3
FLOORS = [Z0 + 0.7 + i * (ROOM_H + SLAB) for i in (2, 1, 0)]     # floor 1 (top) .. floor 3: each room's floor level
TOP = FLOORS[0] + ROOM_H + 0.6                                     # the lawn
COLS = [(-6.1, -2.9), (-2.7, 0.5), (0.7, 3.9)]
SHAFT = (4.1, 6.1)
CUT = 0.2                    # the rooms' back wall (y)


def person(k, x, y, z, shirt="teal", h=0.95):
    k.cyl(shirt, 0.16, h * 0.62, (x, y, z + h * 0.31), verts=5)
    k.sphere("pine", 0.15, (x, y, z + h * 0.78), segs=5, rings=3)


def room(k, col, floor, wall, build_props):
    x0, x1 = COLS[col]
    z = FLOORS[floor]
    k.span(wall, x0, x1, CUT - 0.05, CUT + 0.1, z, z + ROOM_H)                    # its back wall
    k.span("steel", x0, x1, -BY, CUT, z - 0.08, z, open_=("z-",))                  # its floor
    k.cyl("cream", 0.16, 0.06, ((x0 + x1) / 2, -1.0, z + ROOM_H - 0.04), verts=6, mat="Neon", shadow=False)
    build_props(k, x0, z)


def quarters(k, x, z):
    for i, sw in enumerate(("blush", "skyblue")):
        k.box("walnut", (1.25, 0.7, 0.12), (x + 0.85, -0.5 - i * 0.0, z + 0.45 + i * 0.95))
        k.box(sw, (0.9, 0.66, 0.1), (x + 1.0, -0.5, z + 0.56 + i * 0.95))
        k.box("porcelain", (0.3, 0.6, 0.12), (x + 0.4, -0.5, z + 0.58 + i * 0.95))
    for sx in (0.22, 1.48):
        k.box("walnut", (0.08, 0.7, 1.6), (x + sx, -0.5, z + 0.8))
    k.box("teal", (0.6, 0.5, 0.9), (x + 2.6, -0.2, z + 0.45))
    person(k, x + 2.1, -1.4, z, "blush")


def kitchen(k, x, z):
    k.box("porcelain", (1.5, 0.6, 0.85), (x + 0.95, -0.15, z + 0.42))
    k.box("steel", (0.7, 0.62, 0.9), (x + 2.2, -0.15, z + 0.45))
    k.box("rubber", (0.5, 0.04, 0.3), (x + 2.2, -0.47, z + 0.5))
    k.box("mint", (1.5, 0.3, 0.6), (x + 0.95, -0.02, z + 1.6))
    k.cyl("rust", 0.5, 0.06, (x + 1.5, -1.5, z + 0.62), verts=8)
    k.cyl("walnut", 0.08, 0.6, (x + 1.5, -1.5, z + 0.3), verts=4)
    person(k, x + 0.9, -1.5, z, "cream")
    person(k, x + 2.3, -1.6, z, "signal", h=0.7)


def lounge(k, x, z):
    k.box("teal", (1.5, 0.6, 0.45), (x + 1.0, -0.25, z + 0.3))
    k.box("teal", (1.5, 0.18, 0.5), (x + 1.0, -0.02, z + 0.7))
    k.box("walnut", (0.6, 0.4, 0.75), (x + 2.5, -0.15, z + 0.38))
    k.cyl("cream", 0.16, 0.05, (x + 2.5, -0.37, z + 0.5), rot=(90, 0, 0), verts=6)
    k.cyl("signal", 0.8, 0.02, (x + 1.5, -1.5, z + 0.012), verts=10, caps=(False, True))
    k.box("hazard", (0.5, 0.04, 0.7), (x + 1.0, CUT - 0.08, z + 1.6))
    person(k, x + 1.9, -1.3, z, "navy")


def workshop(k, x, z):
    k.box("walnut", (1.8, 0.6, 0.12), (x + 1.1, -0.2, z + 0.85))
    for sx in (0.3, 1.9):
        k.box("gunmetal", (0.1, 0.5, 0.8), (x + sx, -0.2, z + 0.4))
    k.box("pine", (1.9, 0.05, 0.8), (x + 1.1, CUT - 0.09, z + 1.6))
    for i, sw in enumerate(("signal", "steel", "chrome", "rust")):
        k.box(sw, (0.12, 0.06, 0.5), (x + 0.45 + i * 0.42, CUT - 0.13, z + 1.6), rot=(0, 20 - i * 12, 0))
    k.box("pine", (0.55, 0.55, 0.55), (x + 2.6, -1.3, z + 0.28))
    person(k, x + 1.3, -1.2, z, "teal")


def garden(k, x, z):
    for i in range(3):
        k.box("walnut", (0.8, 1.7, 0.35), (x + 0.55 + i * 1.05, -1.1, z + 0.18))
        for j in range(3):
            k.blob("leaf" if (i + j) % 2 else "avocado", 0.26, (x + 0.55 + i * 1.05, -1.7 + j * 0.6, z + 0.55), detail=0, seed=i * 3 + j)
    k.box("blush", (2.8, 1.5, 0.06), (x + 1.6, -1.1, z + ROOM_H - 0.25), mat="Neon", shadow=False)
    k.box("steel", (2.9, 1.6, 0.08), (x + 1.6, -1.1, z + ROOM_H - 0.18))


def storage(k, x, z):
    for lv in range(3):
        k.box("steel", (1.6, 0.5, 0.06), (x + 0.95, -0.1, z + 0.55 + lv * 0.6))
        for i in range(4):
            k.cyl(("rust", "hazard", "teal", "cream")[(i + lv) % 4], 0.14, 0.34, (x + 0.4 + i * 0.37, -0.15, z + 0.75 + lv * 0.6), verts=5)
    for sx in (0.2, 1.7):
        k.box("gunmetal", (0.07, 0.5, 1.9), (x + sx, -0.1, z + 0.95))
    k.cyl("olive", 0.36, 0.95, (x + 2.5, -0.5, z + 0.48), verts=8)
    k.cyl("teal", 0.36, 0.95, (x + 2.3, -1.5, z + 0.48), verts=8)
    k.box("pine", (0.6, 0.6, 0.6), (x + 1.2, -1.6, z + 0.3))


def water(k, x, z):
    k.cyl("skyblue", 0.75, 1.7, (x + 1.0, -0.8, z + 0.95), verts=10)
    k.cyl("steel", 0.8, 0.14, (x + 1.0, -0.8, z + 0.1), verts=10)
    k.cyl("steel", 0.8, 0.14, (x + 1.0, -0.8, z + 1.85), verts=10)
    k.wire("copper", [(x + 1.75, -0.8, z + 1.5), (x + 2.6, -0.8, z + 1.5), (x + 2.6, -0.8, z + 0.5), (x + 3.2, -0.8, z + 0.5)], r=0.08, verts=4)
    k.cyl("signal", 0.2, 0.08, (x + 2.6, -0.92, z + 1.0), rot=(90, 0, 0), verts=6)
    k.box("gunmetal", (0.7, 0.6, 0.6), (x + 2.6, -1.6, z + 0.3))


def reactor(k, x, z):
    k.cyl("gunmetal", 0.95, 0.3, (x + 1.6, -1.0, z + 0.15), verts=10)
    k.cyl("steel", 0.7, 1.5, (x + 1.6, -1.0, z + 1.05), verts=10)
    k.cyl("crystal", 0.74, 0.3, (x + 1.6, -1.0, z + 1.05), verts=10, mat="Neon", shadow=False, caps=(False, False))
    k.cyl("gunmetal", 0.85, 0.2, (x + 1.6, -1.0, z + 1.9), verts=10)
    k.box("teal", (0.7, 0.4, 0.8), (x + 0.5, -0.1, z + 0.4))
    k.box("hazard", (0.5, 0.04, 0.5), (x + 2.8, CUT - 0.08, z + 1.5))
    person(k, x + 0.6, -1.3, z, "hazard")


def pumps(k, x, z):
    k.box("teal", (1.2, 0.8, 0.9), (x + 0.9, -0.5, z + 0.45))
    k.cyl("steel", 0.36, 1.0, (x + 0.9, -0.5, z + 1.15), rot=(0, 90, 0), verts=8)
    k.box("gunmetal", (0.9, 0.7, 1.3), (x + 2.4, -0.4, z + 0.65))
    k.wire("copper", [(x + 1.5, -0.5, z + 1.15), (x + 2.0, -0.5, z + 1.15), (x + 2.0, -0.5, z + 2.3)], r=0.08, verts=4)
    k.cyl("signal", 0.18, 0.06, (x + 2.4, -0.78, z + 0.9), rot=(90, 0, 0), verts=6)


def build(k):
    # the plinth
    k.lathe("walnut", [(8.6, 0), (8.6, 0.5), (8.2, 0.7), (8.2, PL - 0.5), (8.5, PL - 0.3)], (0, 0, 0), verts=24)
    k.cyl("brass", 8.55, 0.2, (0, 0, PL - 0.2), verts=24)
    k.cyl("cream", 8.3, 0.12, (0, 0, PL - 0.04), verts=24)
    k.collider((16.4, 16.4, 13.0), (0, 0, 6.5), name="Display")
    plq = k.face((-3.4, -8.28, 0), 0)
    plq.on("brass", 0.0, 6.8, 0.75, 1.55, 0.14, n0=-0.2)
    plq.text("navy", "YOUR FAMILY SHELTER", 3.4, 1.15, 0.36, n=0.14, depth=0.03, flat=True, max_w=6.2)

    # the earth: a frame round the rooms, solid behind them, strata on its flanks
    k.span("walnut", -BX, BX, CUT + 0.1, BY, Z0, TOP)
    k.span("walnut", -BX, COLS[0][0], -BY, CUT + 0.1, Z0, TOP)
    k.span("walnut", SHAFT[1], BX, -BY, CUT + 0.1, Z0, TOP)
    k.span("basalt", COLS[0][0], SHAFT[1], -BY, CUT + 0.1, Z0, FLOORS[2] - 0.08)
    k.span("leather", COLS[0][0], SHAFT[1], -BY, CUT + 0.1, FLOORS[0] + ROOM_H + 0.3, TOP)
    for f in (k.face((-BX, BY, 0), 270), k.face((BX, -BY, 0), 90), k.face((BX, BY, 0), 180)):
        ln = 2 * BY if f.yaw != 180 else 2 * BX
        f.on("basalt", 0, ln, Z0, Z0 + 1.6, 0.04)
        f.on("stone", 0, ln, Z0 + 1.6, Z0 + 3.4, 0.04)
        f.on("leather", 0, ln, TOP - 1.7, TOP, 0.04)
        for i in range(5):
            f.on("stone", ln * (0.1 + 0.17 * i), ln * (0.1 + 0.17 * i) + 0.5, Z0 + 3.9 + (i * 37 % 20) * 0.1, Z0 + 4.25 + (i * 37 % 20) * 0.1, 0.07)
    # concrete: slabs between the floors and over the top one, walls between the rooms, the shaft's wall
    for fl in range(3):
        k.span("ash", COLS[0][0], SHAFT[1], -BY, CUT + 0.1, FLOORS[fl] + ROOM_H, FLOORS[fl] + ROOM_H + SLAB)
    for (x0, x1) in ((COLS[0][1], COLS[1][0]), (COLS[1][1], COLS[2][0]), (COLS[2][1], SHAFT[0])):
        k.span("ash", x0, x1, -BY, CUT + 0.1, FLOORS[2] - 0.08, FLOORS[0] + ROOM_H)
    rooms = ((quarters, "blush"), (kitchen, "mint"), (lounge, "cream"), (workshop, "sandstone"), (garden, "porcelain"), (storage, "steel"),
             (water, "skyblue"), (reactor, "hazard"), (pumps, "teal"))
    for i, (fn, wall) in enumerate(rooms):
        room(k, i % 3, i // 3, wall, fn)
    # the shaft: guide rails, the car between floors 1 and 2, its cables, rungs
    sx0, sx1 = SHAFT
    k.span("gunmetal", sx0, sx1, CUT - 0.05, CUT + 0.1, FLOORS[2] - 0.08, TOP + 1.2)
    for x in (sx0 + 0.15, sx1 - 0.15):
        k.span("steel", x - 0.05, x + 0.05, -0.2, 0.0, FLOORS[2], TOP + 1.2)
    cz = FLOORS[1] + 0.9
    k.box("teal", (1.5, 1.4, 1.7), ((sx0 + sx1) / 2, -0.95, cz + 0.85))
    k.box("chrome", (1.6, 1.5, 0.1), ((sx0 + sx1) / 2, -0.95, cz + 1.75))
    k.box("rubber", (1.0, 0.05, 1.3), ((sx0 + sx1) / 2, -1.66, cz + 0.8))
    for dx in (-0.3, 0.3):
        k.pole("rubber", 0.03, ((sx0 + sx1) / 2 + dx, -0.95, cz + 1.8), ((sx0 + sx1) / 2 + dx, -0.95, TOP + 1.9), verts=3)
    for i in range(12):
        k.box("steel", (0.5, 0.05, 0.05), (sx1 - 0.45, CUT - 0.1, FLOORS[2] + 0.4 + i * 0.75))

    # the surface: a lawn, the house, a tree, a fence, the shelter's hatch over the shaft
    k.span("leaf", -BX - 0.2, BX + 0.2, -BY - 0.2, BY + 0.2, TOP, TOP + 0.2)
    k.span("ash", -1.3, 3.2, -1.6, -0.9, TOP + 0.2, TOP + 0.24)                               # a path to the hatch
    hx, hy = -3.7, 0.4
    k.box("cream", (2.9, 2.2, 1.5), (hx, hy, TOP + 0.95))
    k.prism_x("rust", [(hy - 1.35, TOP + 1.7), (hy + 1.35, TOP + 1.7), (hy, TOP + 2.7)], hx - 1.65, hx + 1.65)
    k.box("rust", (0.4, 0.4, 0.9), (hx + 0.8, hy + 0.4, TOP + 2.5))
    k.box("teal", (0.5, 0.06, 0.95), (hx - 0.5, hy - 1.12, TOP + 0.7))
    for dx in (0.5, 1.05):
        k.box("skyblue", (0.4, 0.06, 0.5), (hx + dx - 0.2, hy - 1.12, TOP + 1.1))
    k.pole("walnut", 0.12, (-0.6, 1.2, TOP + 0.2), (-0.6, 1.2, TOP + 1.5), verts=5)
    k.blob("forest", 0.95, (-0.6, 1.2, TOP + 2.2), detail=1, jitter=0.12, seed=4)
    k.blob("leaf", 0.6, (-0.2, 0.9, TOP + 2.7), detail=1, jitter=0.1, seed=7)
    for i in range(16):
        k.box("porcelain", (0.12, 0.05, 0.5), (-6.3 + i * 0.36, -2.3, TOP + 0.45))
    k.box("porcelain", (5.6, 0.04, 0.08), (-3.6, -2.3, TOP + 0.5))
    for (fx, fy, sw) in ((-5.6, -1.5, "blush"), (-5.1, -1.2, "hazard"), (-2.2, -1.7, "blush"), (-1.6, -1.9, "signal")):
        k.blob(sw, 0.16, (fx, fy, TOP + 0.36), detail=0)
    # the head-house: concrete, a round steel door, the name over it
    ex = (sx0 + sx1) / 2
    k.box("ash", (2.6, 2.4, 1.9), (ex, -0.6, TOP + 1.15))
    k.prism_x("stone", [(-1.9, TOP + 2.1), (0.7, TOP + 2.1), (0.7, TOP + 2.35), (-1.9, TOP + 2.25)], ex - 1.4, ex + 1.4)
    k.cyl("gunmetal", 0.75, 0.16, (ex, -1.84, TOP + 1.0), rot=(90, 0, 0), verts=12)
    k.cyl("steel", 0.55, 0.16, (ex, -1.9, TOP + 1.0), rot=(90, 0, 0), verts=12)
    k.cyl("chrome", 0.18, 0.16, (ex, -1.98, TOP + 1.0), rot=(90, 0, 0), verts=6)
    k.box("teal", (2.0, 0.06, 0.34), (ex, -1.84, TOP + 1.9))
    person(k, 1.9, -1.25, TOP + 0.2, "signal")
    person(k, 2.5, -1.3, TOP + 0.2, "teal", h=0.7)
    # the case's glass over the cut
    k.glass((2 * BX + 0.1, 0.06, TOP - Z0), (0, -BY - 0.05, (Z0 + TOP) / 2), transparency=0.82)
    k.span("chrome", -BX - 0.1, BX + 0.1, -BY - 0.12, -BY + 0.02, Z0, Z0 + 0.14)
    k.light((0, -7.5, 9.5), colour="cream", brightness=0.9, range_=20)
    return {"views": [
        ("front", (3.5, -27, 9.5), (0, 0, 7.6), 44),
        ("top", (10, -20, 20), (0, 0, 9), 44),
    ]}


if __name__ == "__main__":
    T.run(build, "Lobby_BunkerCutaway", "Lobby", budget=5000, res=(900, 700), ground="#EFE3C4", sun_strength=2.6, sky=False, ambient=2.4)
