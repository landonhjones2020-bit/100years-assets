"""Lobby_Showroom: the Steadfast Shelter Co. showroom on Main Street, Brightwater, the day before
the bomb (A9; bible Section 21: "the hub building"). Its outside and its structure: forecourt,
stone piers, the glass front and its doors, the canopy, the pylon, the fascia's name, the roof
and its billboard, the side walls' painted advertisements, and the floor, walls and roof slabs.
Lobby_ShowroomHall is the hall inside (columns, the elevator bays, lights), Lobby_ShowroomFit its
displays and furniture; Lobby_ElevatorPad, Lobby_ClassBooth, Lobby_LoadoutBooth and
Lobby_BunkerCutaway stand in it (sockets Bay1..Bay6, ClassBooth, LoadoutBooth, Cutaway; Spawn is
where a player arrives, on the street, facing the door).

Front faces -Y (the street). Pivot: the footprint's centre on the ground.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402
from showroom_dims import *  # noqa: E402,F401,F403


def door_leaf(k, hinge, yaw, w=7.6, h=11.6, z0=FLOOR):
    """A glass door leaf standing open: hinge (x, y), swung to yaw (degrees from +X)."""
    with k.at((hinge[0], hinge[1], z0), yaw):
        fr = 0.35
        k.span("chrome", 0, w, -0.14, 0.14, 0, fr)
        k.span("chrome", 0, w, -0.14, 0.14, h - fr, h)
        k.span("chrome", 0, fr, -0.14, 0.14, 0, h)
        k.span("chrome", w - fr, w, -0.14, 0.14, 0, h)
        k.glass((w - 2 * fr, 0.1, h - 2 * fr), (w / 2, 0, h / 2), transparency=0.6)
        for sy in (-1, 1):       # a long pull, both sides
            k.pole("brass", 0.1, (w - 1.1, sy * 0.4, 3.2), (w - 1.1, sy * 0.4, 7.4), verts=5)
            for zz in (3.5, 7.1):
                k.pole("brass", 0.07, (w - 1.1, sy * 0.4, zz), (w - 1.1, 0, zz), verts=4)


def exterior(k):
    # -- forecourt: big paving squares, a star at the door ------------------------------------
    fy0 = Y0 - 14.0
    k.span("ash", X0 - 3, X1 + 3, fy0, Y0, -0.3, 0.05)
    n = 19
    step = (W + 6) / n
    for i in range(n):
        for j in range(2):
            if (i + j) % 2 == 0:
                k.span("sandstone", X0 - 3 + i * step + 0.12, X0 - 3 + (i + 1) * step - 0.12, fy0 + j * 7 + 0.12, fy0 + (j + 1) * 7 - 0.12,
                       0.05, 0.09, open_=("z-",))
    k.cyl("teal", 6.2, 0.08, (0, Y0 - 7, 0.1), verts=24)
    k.cyl("cream", 5.6, 0.08, (0, Y0 - 7, 0.13), verts=24)
    star = []
    for i in range(16):
        a = math.pi / 2 + 2 * math.pi * i / 16
        r = 5.2 if i % 2 == 0 else 1.7
        star.append((math.cos(a) * r, Y0 - 7 + math.sin(a) * r))
    k.prism_z("brass", star, 0.17, 0.21)
    k.cyl("teal", 1.1, 0.06, (0, Y0 - 7, 0.24), verts=12)

    # -- floor, walls, roof ---------------------------------------------------------------------
    k.span("cream", X0, X1, Y0, Y1, 0.0, FLOOR)
    k.collide_span(X0, X1, Y0, Y1, -1.0, FLOOR, name="Floor")
    k.span("cream", X0, X0 + WT, Y0, Y1, 0, ROOF)              # west
    k.span("cream", X1 - WT, X1, Y0, Y1, 0, ROOF)              # east
    k.span("cream", X0, X1, Y1 - WT, Y1, 0, ROOF)              # back
    k.collide_span(X0, X0 + WT, Y0, Y1, 0, ROOF)
    k.collide_span(X1 - WT, X1, Y0, Y1, 0, ROOF)
    k.collide_span(X0, X1, Y1 - WT, Y1, 0, ROOF)
    k.span("porcelain", X0 + WT, X1 - WT, Y0 + 0.2, Y1 - WT, CEIL, CEIL + 0.5)      # ceiling
    k.span("basalt", X0 + 0.5, X1 - 0.5, Y0, Y1 - 0.5, ROOF - 0.5, ROOF)            # roof deck
    k.span("cream", X0, X1, Y0 + 0.2, Y1, CEIL + 0.5, ROOF - 0.5)
    k.collide_span(X0, X1, Y0, Y1, CEIL, ROOF, name="Roof")
    # parapet on three sides, chrome coping
    for (a, b, c, d) in ((X0, X0 + 1.0, Y0, Y1), (X1 - 1.0, X1, Y0, Y1), (X0, X1, Y1 - 1.0, Y1)):
        k.span("cream", a, b, c, d, ROOF, PARAPET)
        k.span("chrome", a - 0.15, b + 0.15, c - 0.15, d + 0.15, PARAPET, PARAPET + 0.3)

    # -- the front: stone piers, bulkhead, glass, mullions --------------------------------------
    front = k.face((X0, Y0, 0), 0)                # u = x - X0
    for (a, b, seed) in ((X0, X0 + PIER, 3), (X1 - PIER, X1, 8)):
        k.span("stone", a, b, Y0 - 1.0, Y0 + 1.2, 0, GLASS_TOP)
        k.collide_span(a, b, Y0 - 1.0, Y0 + 1.2, 0, GLASS_TOP)
        T.ashlar(k.face((a, Y0 - 1.0, 0), 0), 0, PIER, 0, GLASS_TOP, row=1.45, seed=seed)
    T.ashlar(k.face((X0 + PIER, Y0 + 1.2, 0), 270), 0, 2.2, 0, GLASS_TOP, row=1.45, seed=5, min_w=1.0, max_w=2.2)
    T.ashlar(k.face((X1 - PIER, Y0 - 1.0, 0), 90), 0, 2.2, 0, GLASS_TOP, row=1.45, seed=6, min_w=1.0, max_w=2.2)
    for (a, b) in ((X0 + PIER, -DOOR), (DOOR, X1 - PIER)):
        k.span("teal", a, b, Y0 - 0.55, Y0 + 0.55, 0, 1.8)                       # bulkhead
        k.span("chrome", a, b, Y0 - 0.7, Y0 + 0.7, 1.8, 2.05)
        k.glass((b - a, 0.22, GLASS_TOP - 2.05), ((a + b) / 2, Y0, (2.05 + GLASS_TOP) / 2), transparency=0.62)
        k.collide_span(a, b, Y0 - 0.5, Y0 + 0.5, 0, GLASS_TOP, name="Glass")
        nm = 5
        for i in range(nm + 1):
            x = a + (b - a) * i / nm
            k.span("chrome", x - 0.2, x + 0.2, Y0 - 0.45, Y0 + 0.45, 2.05, GLASS_TOP)
        k.span("chrome", a, b, Y0 - 0.35, Y0 + 0.35, 12.3, 12.7)                 # transom bar
        # a teal kick stripe of small tiles along the bulkhead
        for i in range(int((b - a) / 1.8)):
            k.span("mint" if i % 2 else "porcelain", a + 0.3 + i * 1.8, a + 1.5 + i * 1.8, Y0 - 0.62, Y0 - 0.55, 0.55, 1.25, open_=("y+",))
    # the entrance: chrome posts and header, a glass transom over the doors, the leaves standing open
    for sx in (-1, 1):
        k.span("chrome", sx * DOOR - 0.35, sx * DOOR + 0.35, Y0 - 0.6, Y0 + 0.6, 0, GLASS_TOP)
    k.span("chrome", -DOOR, DOOR, Y0 - 0.6, Y0 + 0.6, DOOR_H, DOOR_H + 0.6)
    k.glass((2 * DOOR - 0.7, 0.22, GLASS_TOP - DOOR_H - 0.6), (0, Y0, (DOOR_H + 0.6 + GLASS_TOP) / 2), transparency=0.62)
    k.span("chrome", -0.2, 0.2, Y0 - 0.4, Y0 + 0.4, DOOR_H + 0.6, GLASS_TOP)
    door_leaf(k, (-DOOR + 0.35, Y0 + 0.5), 84)
    door_leaf(k, (DOOR - 0.35, Y0 + 0.5), 96)
    # a brass threshold
    k.span("brass", -DOOR, DOOR, Y0 - 0.7, Y0 + 0.7, 0.0, FLOOR + 0.04)

    # -- fascia: the name ---------------------------------------------------------------------
    fy = Y0 - 1.8
    k.span("cream", X0 - 0.8, X1 + 0.8, fy, Y0 + 1.2, GLASS_TOP, PARAPET)
    k.span("teal", X0 - 0.95, X1 + 0.95, fy - 0.15, Y0 + 1.3, GLASS_TOP, GLASS_TOP + 1.3)
    k.span("chrome", X0 - 1.0, X1 + 1.0, fy - 0.2, Y0 + 1.35, GLASS_TOP + 1.3, GLASS_TOP + 1.55)
    k.span("chrome", X0 - 1.0, X1 + 1.0, fy - 0.2, Y0 + 1.35, PARAPET, PARAPET + 0.35)
    fascia = k.face((0, fy, 0), 0)
    fascia.text("teal", "STEADFAST SHELTER CO.", 6, 22.6, 4.3, n=0.0, depth=0.5, max_w=86, res=2)
    fascia.text("cream", "FAMILY BUNKERS   ·   SUPPLIES   ·   PEACE OF MIND   ·   EASY TERMS", 0, GLASS_TOP + 0.66, 0.72, n=0.16,
                depth=0.05, flat=True, max_w=110)
    k.span("signal", -37, 49, fy - 0.3, fy, 19.55, 19.85)
    for x in (-39.5, 51.5):
        L.starburst(k, (x, fy - 0.5, 19.7), r=1.5, spikes=8, flat=True, neon=False, ball="signal")

    # -- canopy -------------------------------------------------------------------------------
    cz = 13.3
    plan = [(-17, Y0 - 1.8), (17, Y0 - 1.8), (20.5, Y0 - 9), (13, Y0 - 15.5), (0, Y0 - 13.2), (-13, Y0 - 15.5), (-20.5, Y0 - 9)]
    k.prism_z("teal", plan, cz, cz + 1.1)
    grow = [(x * 1.012, Y0 - 1.8 + (y - (Y0 - 1.8)) * 1.02) for x, y in plan]
    k.prism_z("chrome", grow, cz + 0.38, cz + 0.72)
    k.prism_z("porcelain", [(x * 0.97, Y0 - 1.8 + (y - (Y0 - 1.8)) * 0.96) for x, y in plan], cz - 0.12, cz)
    for (x, y) in ((-11, Y0 - 6), (0, Y0 - 5), (11, Y0 - 6), (-9, Y0 - 11.2), (9, Y0 - 11.2), (0, Y0 - 10)):
        k.cyl("chrome", 1.0, 0.16, (x, y, cz - 0.16), verts=10)
        k.cyl("cream", 0.85, 0.1, (x, y, cz - 0.24), verts=10, mat="Neon", shadow=False)
    k.light((0, Y0 - 8, cz - 2), colour="cream", brightness=0.9, range_=30)
    for sx in (-1, 1):          # V struts down to stone feet
        foot = (sx * 15.5, Y0 - 12.2, 0.0)
        k.box("stone", (2.4, 2.4, 1.2), (foot[0], foot[1], 0.6))
        k.box("sandstone", (2.0, 2.0, 0.3), (foot[0], foot[1], 1.35))
        k.pole("chrome", 0.3, (foot[0], foot[1], 1.4), (sx * 12.0, Y0 - 14.0, cz), verts=6, r_top=0.18)
        k.pole("chrome", 0.3, (foot[0], foot[1], 1.4), (sx * 18.6, Y0 - 9.6, cz), verts=6, r_top=0.18)
        k.collider((2.4, 2.4, 6.0), (foot[0], foot[1], 3.0), name="Strut")
    # the script standing on the canopy's edge
    k.text("signal", "Family Shelters", (0, Y0 - 13.6, cz + 3.0), 3.8, depth=0.45, font="Lobster-Regular", back=True, res=2)
    for x in (-9, -3, 3, 9):
        k.pole("gunmetal", 0.08, (x, Y0 - 13.2, cz + 1.0), (x, Y0 - 13.2, cz + 2.2), verts=4)

    # -- pylon --------------------------------------------------------------------------------
    px, py = -57.0, Y0 - 6.5
    k.box("stone", (10.5, 5.0, 2.2), (px, py, 1.1))
    T.ashlar(k.face((px - 5.25, py - 2.5, 0), 0), 0, 10.5, 0, 2.2, row=1.1, seed=11, min_w=1.4, max_w=2.8)
    k.box("sandstone", (11.0, 5.5, 0.35), (px, py, 2.37))
    k.collider((10.5, 5.0, 30.0), (px, py, 15.0), name="Pylon")
    fin = [(px - 3.3, 2.5), (px + 3.3, 2.5), (px + 5.4, 66.0), (px - 4.6, 61.0)]
    k.prism_y("teal", fin, py - 1.1, py + 1.1)
    for sgn, (a, b) in ((-1, (fin[0], fin[3])), (1, (fin[1], fin[2]))):
        k.pole("chrome", 0.32, (a[0], py, a[1]), (b[0], py, b[1]), verts=6)
    zz = 56.0
    for ch in "STEADFAST":
        k.text("porcelain", ch, (px + 0.2 + (zz - 30) * 0.012, py - 1.1, zz), 4.3, depth=0.35, font="Oswald-Bold", res=2)
        zz -= 5.6
    L.starburst(k, (px + 0.6, py, 73.5), r=6.0, spikes=12)
    k.pole("chrome", 0.22, (px + 0.6, py, 62.5), (px + 0.6, py, 73.5), verts=6)

    # -- roof: billboard, plant ---------------------------------------------------------------
    bx0, bx1, by = 12.0, 60.0, Y0 + 8.0
    k.span("cream", bx0, bx1, by - 0.3, by + 0.3, 31.0, 44.0)
    k.span("teal", bx0 - 0.5, bx1 + 0.5, by - 0.45, by + 0.45, 30.3, 31.0)
    k.span("teal", bx0 - 0.5, bx1 + 0.5, by - 0.45, by + 0.45, 44.0, 44.7)
    k.span("teal", bx0 - 0.5, bx0, by - 0.45, by + 0.45, 31.0, 44.0)
    k.span("teal", bx1, bx1 + 0.5, by - 0.45, by + 0.45, 31.0, 44.0)
    board = k.face((0, by - 0.3, 0), 0)
    board.cyl("hazard", 5.2, 0.12, (19.5, 0.05, 37.5), verts=20)
    for i in range(9):          # sun rays
        a = math.radians(-50 + i * 25)
        board.box("hazard", (0.5, 0.1, 2.4), (19.5 + math.sin(a) * 7.4, 0.05, 37.5 + math.cos(a) * 7.4), roll=-math.degrees(a))
    board.outline("forest", [(13, 31.2), (27.5, 31.2), (24.5, 34.6), (20.5, 35.6), (15.6, 34.2)], 0.05, 0.2)
    board.cyl("gunmetal", 1.25, 0.12, (20.4, 0.26, 33.4), verts=12)
    board.cyl("chrome", 0.8, 0.12, (20.4, 0.32, 33.4), verts=12)
    board.text("signal", "Built to Last", 43.5, 39.6, 4.7, n=0.05, depth=0.3, font="Lobster-Regular", max_w=30)
    board.text("navy", "A CENTURY", 43.5, 34.2, 3.5, n=0.05, depth=0.3, font="AlfaSlabOne-Regular", max_w=29)
    for x in (bx0 + 3, (bx0 + bx1) / 2, bx1 - 3):     # lattice legs and back braces
        k.pole("gunmetal", 0.22, (x, by + 0.4, ROOF), (x, by + 0.4, 44.0), verts=5)
        k.pole("gunmetal", 0.16, (x, by + 9.0, ROOF), (x, by + 0.4, 40.0), verts=4)
        k.pole("gunmetal", 0.12, (x, by + 4.6, ROOF + 7.3), (x, by + 0.4, ROOF + 3.0), verts=4)
    for zz in (ROOF + 3.0, ROOF + 6.0):
        k.pole("gunmetal", 0.12, (bx0 + 3, by + 0.4, zz), (bx1 - 3, by + 0.4, zz), verts=4)
    for x in (bx0 + 6, bx0 + 18, bx1 - 18, bx1 - 6):   # goosenecks along the top
        k.wire("gunmetal", [(x, by, 44.7), (x, by - 0.3, 46.2), (x, by - 2.6, 46.3), (x, by - 3.0, 45.6)], r=0.09, verts=4)
        k.cyl("gunmetal", 0.5, 0.6, (x, by - 3.0, 45.3), verts=8, r_top=0.2)
    # air handlers, vents, a hatch
    for (x, y, s) in ((-30.0, 6.0, 1.0), (-18.0, 22.0, 0.8), (-44.0, 26.0, 0.8)):
        k.box("steel", (7 * s, 5 * s, 3.2 * s), (x, y, ROOF + 1.6 * s + 0.4))
        k.box("gunmetal", (7.4 * s, 5.4 * s, 0.4), (x, y, ROOF + 0.2))
        k.cyl("gunmetal", 1.7 * s, 0.3, (x - 1.3 * s, y, ROOF + 3.2 * s + 0.5), verts=12)
        k.cyl("rubber", 1.4 * s, 0.1, (x - 1.3 * s, y, ROOF + 3.2 * s + 0.68), verts=12)
        for i in range(5):
            k.span("gunmetal", x + 1.0 * s, x + 3.3 * s, y - 2.55 * s, y - 2.5 * s, ROOF + 0.9 + i * 0.5 * s, ROOF + 1.1 + i * 0.5 * s)
    for (x, y) in ((-52.0, -20.0), (-8.0, 30.0), (30.0, 34.0)):
        k.cyl("steel", 0.7, 3.0, (x, y, ROOF + 1.5), verts=8)
        k.cyl("steel", 1.2, 0.5, (x, y, ROOF + 3.2), verts=8, r_top=0.3)
    k.box("steel", (4, 4, 1.2), (48.0, 30.0, ROOF + 0.6))
    k.box("gunmetal", (4.4, 4.4, 0.25), (48.0, 30.0, ROOF + 1.3))

    # -- side and back walls, outside ---------------------------------------------------------
    east = k.face((X1, Y0, 0), 90)             # u runs to the back (+Y)
    west = k.face((X0, Y1, 0), 270)            # u runs to the front (-Y)
    back = k.face((X1, Y1, 0), 180)
    for f, ln in ((east, D), (west, D), (back, W)):
        T.ashlar(f, 0, ln, 0, 3.0, row=1.5, seed=int(ln) + int(f.yaw), mortar="stone", proud=0.2)
        f.on("sandstone", 0, ln, 3.0, 3.35, 0.4)
        f.on("teal", 0, ln, ROOF - 1.2, ROOF - 0.5, 0.12)
    # east: the painted advertisement, a service door, high windows, a drainpipe
    east.on("teal", 14, 84, 7.0, 20.5, 0.08)
    east.on("cream", 15, 83, 7.9, 19.6, 0.12)
    east.text("teal", "SLEEP SOUND", 49, 16.0, 4.6, n=0.14, depth=0.05, font="AlfaSlabOne-Regular", max_w=62, flat=True)
    east.text("signal", "Underground", 49, 10.6, 4.2, n=0.14, depth=0.05, font="Lobster-Regular", max_w=50, flat=True)
    east.on("gunmetal", 3.5, 9.5, 0.0, 10.4, 0.25)
    east.on("teal", 4.0, 9.0, 0.3, 9.9, 0.4)
    east.on("chrome", 8.2, 8.6, 4.4, 5.6, 0.55)
    east.prism("signal", [(0, 12.0), (3.4, 10.9), (3.4, 10.6), (0, 11.6)], 2.8, 10.2)
    east.cyl("gunmetal", 0.5, 0.5, (6.5, 0.9, 11.2), axis="n", verts=8)
    k.light(east.p(6.5, 2.2, 10.2), colour="cream", brightness=0.6, range_=14)
    for f, ln in ((east, D), (west, D)):
        k.pole("gunmetal", 0.28, f.p(ln - 1.2, 0.4, 0.2), f.p(ln - 1.2, 0.4, ROOF - 0.6), verts=6)
        for zz in (4.0, 12.0, 20.0):
            f.on("gunmetal", ln - 1.6, ln - 0.8, zz, zz + 0.3, 0.55)
    west.on("teal", 20, 76, 9.0, 18.5, 0.08)
    west.on("cream", 21, 75, 9.9, 17.6, 0.12)
    west.text("teal", "PARKING IN REAR", 44, 15.2, 2.6, n=0.14, depth=0.05, max_w=46, flat=True)
    west.outline("signal", [(28, 11.9), (56, 11.9), (56, 11.1), (60, 12.4), (56, 13.7), (56, 12.9), (28, 12.9)], 0.12, 0.22)
    # back: a loading door, a caged light
    back.on("gunmetal", 52, 80, 0, 14.4, 0.3)
    for i in range(11):
        back.on("steel", 53, 79, 0.5 + i * 1.22, 1.5 + i * 1.22, 0.42)
    back.on("hazard", 51, 52, 0, 5, 0.5)
    back.on("hazard", 80, 81, 0, 5, 0.5)
    back.cyl("gunmetal", 0.6, 0.6, (66, 0.9, 16.2), axis="n", verts=8)

    # -- bunting: Founders' Day, from the pylon's shoulder to the far end of the fascia ---------
    a, b = T.Vector((px + 3.0, py, 50.0)), T.Vector((X1 - 2.0, Y0 - 2.4, PARAPET + 1.6))
    k.pole("chrome", 0.12, (X1 - 2.0, Y0 - 2.4, PARAPET), (X1 - 2.0, Y0 - 2.4, PARAPET + 1.7), verts=4)
    n, sag = 26, 7.0
    prev = a
    for i in range(1, n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * 4 * t * (1 - t)
        k.pole("rubber", 0.05, prev, p, verts=3)
        mid = (prev + p) / 2
        d = (p - prev).normalized()
        sw = ("signal", "porcelain", "teal", "hazard")[i % 4]
        # a pennant hanging from the middle of this stretch (a thin triangle in the line's plane)
        ha = prev.lerp(p, 0.15)
        hb = prev.lerp(p, 0.85)
        tip = T.Vector((mid.x, mid.y, mid.z - 2.4))
        k.add(sw, [ha, hb, tip, ha + T.Vector((0, 0.06, 0)), hb + T.Vector((0, 0.06, 0)), tip + T.Vector((0, 0.06, 0))],
              [(0, 2, 1), (3, 4, 5)], shadow=False)
        prev = p

    # -- where things stand -------------------------------------------------------------------
    for i, bx_ in enumerate(BAYS):
        k.socket(f"Bay{i + 1}", (bx_, BAY_Y, FLOOR))
    k.socket("ClassBooth", (X0 + WT + 0.2, -2.0, FLOOR), 90)       # against the west wall, facing east
    k.socket("LoadoutBooth", (X1 - WT - 0.2, -2.0, FLOOR), 270)    # against the east wall, facing west
    k.socket("Cutaway", (CUTAWAY[0], CUTAWAY[1], FLOOR), 0)
    k.socket("Spawn", (0.0, Y0 - 30.0, 0.0), 180)


def build(k):
    exterior(k)
    return {"views": [
        ("street", (34, -190, 14), (-4, -40, 26), 50),
        ("pylon", (-112, -120, 8), (-34, -44, 30), 52),
        ("door", (5, -88, 6.5), (0, -10, 10), 66),
        ("east", (150, -80, 22), (62, -4, 12), 44),
    ]}


if __name__ == "__main__":
    import Lobby_ShowroomHall as Hall
    import Lobby_ShowroomFit as Fit
    T.run(build, "Lobby_Showroom", "Lobby", budget=20000, context=(Hall.hall, Fit.fit), res=(1100, 620))
