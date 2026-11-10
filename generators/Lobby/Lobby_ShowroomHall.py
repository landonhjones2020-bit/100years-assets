"""Lobby_ShowroomHall: the hall inside the Steadfast showroom (A9; bible Section 21): the terrazzo
floor's inlays, the tiled dado, mushroom columns, ceiling beams and lights, the sputnik lamps, and
the elevator hall: a partition with six portals, each a bay where a Lobby_ElevatorPad stands.
Lobby_Showroom is the building round it (same origin and pivot).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402
from showroom_dims import *  # noqa: E402,F401,F403


def hall(k):
    # -- inside: wainscot, the elevator hall's partition and bays, ceiling beams --------------
    for f, ln in ((k.face((X0 + WT, Y0 + 1.2, 0), 90), D - 1.2 - WT), (k.face((X1 - WT, Y1 - WT, 0), 270), D - 1.2 - WT)):
        f.on("teal", 0, ln, FLOOR, 5.2, 0.14)
        f.on("chrome", 0, ln, 5.2, 5.45, 0.22)
        f.on("walnut", 0, ln, FLOOR, FLOOR + 0.6, 0.24)
    # the partition: piers between the bays, headers over them
    edges = [X0 + WT] + [v for b in BAYS for v in (b - BAY_HALF, b + BAY_HALF)] + [X1 - WT]
    for i in range(0, len(edges), 2):
        a, b = edges[i], edges[i + 1]
        k.span("cream", a, b, PART - 0.6, PART + 0.6, FLOOR, CEIL)
        k.collide_span(a, b, PART - 0.6, PART + 0.6, FLOOR, CEIL)
        k.span("teal", a, b, PART - 0.75, PART - 0.6, FLOOR, 5.2)
        k.span("chrome", a, b, PART - 0.82, PART - 0.6, 5.2, 5.45)
        k.span("walnut", a, b, PART - 0.85, PART - 0.6, FLOOR, FLOOR + 0.6)
    hall = k.face((X0, PART - 0.6, 0), 0)        # the partition's hall side: u = x - X0
    for b in BAYS:
        k.span("cream", b - BAY_HALF, b + BAY_HALF, PART - 0.6, PART + 0.6, BAY_H, CEIL)
        u = b - X0
        # the portal: a teal enamel frame, chrome inside it, bulbs along the top
        hall.on("teal", u - BAY_HALF - 1.3, u - BAY_HALF, FLOOR, BAY_H, 0.5)
        hall.on("teal", u + BAY_HALF, u + BAY_HALF + 1.3, FLOOR, BAY_H, 0.5)
        hall.on("teal", u - BAY_HALF - 1.3, u + BAY_HALF + 1.3, BAY_H, BAY_H + 1.3, 0.5)
        hall.on("chrome", u - BAY_HALF, u - BAY_HALF + 0.3, FLOOR, BAY_H, 0.62)
        hall.on("chrome", u + BAY_HALF - 0.3, u + BAY_HALF, FLOOR, BAY_H, 0.62)
        hall.on("chrome", u - BAY_HALF, u + BAY_HALF, BAY_H - 0.3, BAY_H, 0.62)
        for i in range(9):
            bxu = u - BAY_HALF + 0.9 + i * (2 * BAY_HALF - 1.8) / 8
            k.bulb("cream", 0.26, hall.p(bxu, 0.66, BAY_H + 0.65))
        # the bay: side walls, tiled dado, a soffit light
        for sx in (-1, 1):
            k.span("cream", b + sx * (BAY_HALF + 2.6), b + sx * (BAY_HALF + 3.0), PART + 0.6, Y1 - WT, FLOOR, CEIL)
            k.span("mint", b + sx * (BAY_HALF + 2.45), b + sx * (BAY_HALF + 2.6), PART + 0.6, Y1 - WT, FLOOR, 5.2)
        k.span("mint", b - BAY_HALF - 2.6, b + BAY_HALF + 2.6, Y1 - WT - 0.15, Y1 - WT, FLOOR, 5.2)
        k.span("chrome", b - BAY_HALF - 2.6, b + BAY_HALF + 2.6, Y1 - WT - 0.2, Y1 - WT, 5.2, 5.45)
        k.span("porcelain", b - BAY_HALF - 2.6, b + BAY_HALF + 2.6, PART + 0.6, Y1 - WT, 16.0, 16.5)       # the bay's own ceiling
    for (a, b) in zip(BAYS, BAYS[1:]):            # the walls between bays block, as a pair, the gap between them
        k.collide_span(a + BAY_HALF + 2.45, b - BAY_HALF - 2.45, PART + 0.6, Y1 - WT, FLOOR, CEIL)
    k.collide_span(X0 + WT, BAYS[0] - BAY_HALF - 2.45, PART + 0.6, Y1 - WT, FLOOR, CEIL)
    k.collide_span(BAYS[-1] + BAY_HALF + 2.45, X1 - WT, PART + 0.6, Y1 - WT, FLOOR, CEIL)
    # the hall's header: where the lifts go
    # (each pad's own sign hangs between the portal and this band: z 15.1 to 19.5)
    hall.on("teal", 6, W - 6, 19.9, 21.6, 0.3)
    hall.on("chrome", 6, W - 6, 19.7, 19.9, 0.42)
    hall.text("porcelain", "ELEVATORS  ·  TO YOUR SHELTER", W / 2, 20.75, 1.05, n=0.3, depth=0.1, max_w=60)
    for u in (30.0, W - 30.0):
        L.starburst(k, hall.p(u, 0.6, 20.75), r=0.8, spikes=8, flat=True, neon=False, ball="hazard", core="brass", spike="brass")
    # ceiling beams running front to back, dropped 0.9
    for x in (-55.0, -33.0, -11.0, 11.0, 33.0, 55.0):
        k.span("cream", x - 0.6, x + 0.6, Y0 + 1.2, PART - 0.6, CEIL - 0.9, CEIL)
    k.span("cream", X0 + WT, X1 - WT, Y0 + 1.2, Y0 + 2.4, CEIL - 0.9, CEIL)
    # the columns stand in the shell (they hold the roof up)
    for (x, y) in COLUMNS:
        L.mushroom_column(k, x, y, FLOOR, CEIL)


    # -- the floor: big terrazzo squares, brass aisle lines, a medallion, the elevator zone's band
    tile = 11.0
    nx, ny = int((W - 2 * WT) / tile), int((PART - 0.6 - Y0 - 1.2) / tile)
    ox, oy = -nx * tile / 2, Y0 + 1.2 + ((PART - 0.6 - Y0 - 1.2) - ny * tile) / 2
    for i in range(nx):
        for j in range(ny):
            if (i + j) % 2 == 0:
                k.span("porcelain", ox + i * tile + 0.1, ox + (i + 1) * tile - 0.1, oy + j * tile + 0.1, oy + (j + 1) * tile - 0.1,
                       FLOOR, FLOOR + 0.015, open_=("z-", "x-", "x+", "y-", "y+"))
    for sx in (-1, 1):
        k.span("brass", sx * 10.0 - 0.12, sx * 10.0 + 0.12, Y0 + 2.0, PART - 3.4, FLOOR, FLOOR + 0.03, open_=("z-",))
    mx, my = 0.0, -12.0
    k.cyl("teal", 9.0, 0.04, (mx, my, FLOOR + 0.02), verts=28, caps=(False, True))
    k.cyl("brass", 8.2, 0.04, (mx, my, FLOOR + 0.04), verts=28, caps=(False, True))
    k.cyl("cream", 7.9, 0.04, (mx, my, FLOOR + 0.06), verts=28, caps=(False, True))
    star = []
    for i in range(16):
        a = math.pi / 2 + 2 * math.pi * i / 16
        r = 7.4 if i % 4 == 0 else (4.6 if i % 2 == 0 else 1.9)
        star.append((mx + math.cos(a) * r, my + math.sin(a) * r))
    k.prism_z("teal", star, FLOOR + 0.07, FLOOR + 0.1, caps=(False, True))
    k.cyl("brass", 2.3, 0.04, (mx, my, FLOOR + 0.11), verts=16, caps=(False, True))
    k.text("teal", "S", (mx, my, FLOOR + 0.14), 2.6, depth=0.02, tilt=0, font="AlfaSlabOne-Regular", flat=True)
    L.hazard_stripes(k, X0 + WT + 0.3, X1 - WT - 0.3, PART - 3.2, PART - 1.9, FLOOR, n=44)

    # -- lights: lenses in a grid, three sputniks down the middle ------------------------------
    for i, x in enumerate((-44.0, -22.0, 0.0, 22.0, 44.0)):
        for j, y in enumerate((-38.0, -22.0, -6.0, 10.0, 24.0)):
            if x == 0.0 and j in (1, 2, 3):
                continue                      # the sputniks hang there
            L.ceiling_light(k, x, y, CEIL, r=1.5, light=i in (0, 4) and j in (0, 4))
    for y in (-22.0, -6.0, 10.0):
        L.sputnik_lamp(k, (0.0, y, CEIL), drop=4.6, r=2.9, arms=10)
    # every bay has its own lamp over the pad
    for b in BAYS:
        k.cyl("chrome", 1.5, 0.3, (b, BAY_Y, 16.0 - 0.15), verts=10)
        k.cyl("cream", 1.25, 0.14, (b, BAY_Y, 16.0 - 0.36), verts=10, mat="Neon", shadow=False)
        k.light((b, BAY_Y, 14.6), colour="cream", brightness=0.9, range_=20)


def build(k):
    hall(k)
    return {"views": [
        ("hall", (0, -46, 7.0), (0, 40, 9.5), 78),
        ("bays", (-34, -2, 7.0), (14, 40, 8), 70),
        ("west", (30, -30, 8.0), (-66, 6, 7), 72),
        ("floor", (0, -34, 20.0), (0, 8, 0), 70),
    ]}


if __name__ == "__main__":
    import Lobby_Showroom as Show
    import Lobby_ShowroomFit as Fit
    T.run(build, "Lobby_ShowroomHall", "Lobby", budget=20000, context=(Show.exterior, Fit.fit), res=(1100, 620), sun_strength=3.0)
