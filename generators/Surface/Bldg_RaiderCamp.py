"""Bldg_RaiderCamp: the Ash Raiders' camp where the surface's Lost Crew is held (A6 with Prompt 17;
bible Section 12: every run hides a trapped Steadfast work crew on the surface, guarded by a raider
camp). A ring of junk barricades (sheet metal, a car door, oil drums) round a burning drum, a
patched tarp lean-to, and a pen of welded bars at the back where the crew are held. The way in
faces the street (-Y). Sockets: Crew1..3 (in the pen), Guard1..4 (raider posts), Light1 (the
fire). The pivot is the footprint's centre on the ground.
"""
import math
import random

import townlib as T
from townlib import bx, cy

W, D = 32, 30


def drum(x, y, colour, r=0.9, h=2.6, tipped=False):
    if tipped:
        cy("Decor", colour, r, h, (x, y, r), rot=(90, 0, 30), verts=10)
    else:
        cy(T.uid("Drum"), colour, r, h, (x, y, h / 2), collision="box", verts=10)


def build():
    rnd = random.Random(23)
    bx("Ground", "stone", (W, D, 0.3), (0, 0, 0.15), collision="box")
    # the barricade: sheet-metal panels on posts, leaving the way in at the front
    panels = []
    for x0, x1 in ((-W / 2, -5), (5, W / 2)):
        panels.append(("x", x0, x1, -D / 2))
    panels.append(("y", -D / 2, D / 2, -W / 2))
    panels.append(("y", -D / 2, D / 2, W / 2))
    colours = ("rust", "steel", "olive", "gunmetal")
    for k, (axis, a, b, c) in enumerate(panels):
        n = int(abs(b - a) // 4)
        for i in range(n):
            s0 = a + (b - a) * i / n
            s1 = a + (b - a) * (i + 1) / n
            h = 5.5 + rnd.uniform(-1.2, 1.2)
            col = colours[(i + k) % len(colours)]
            tilt = rnd.uniform(-6, 6)
            if axis == "x":
                bx(T.uid("Barricade"), col, (s1 - s0 + 0.3, 0.4, h), ((s0 + s1) / 2, c, h / 2), rot=(tilt, 0, 0), collision="box")
            else:
                bx(T.uid("Barricade"), col, (0.4, s1 - s0 + 0.3, h), (c, (s0 + s1) / 2, h / 2), rot=(0, tilt, 0), collision="box")
    for (x, y) in ((-W / 2, -D / 2), (W / 2, -D / 2), (-W / 2, D / 2), (W / 2, D / 2), (-5, -D / 2), (5, -D / 2)):
        bx("Decor", "walnut", (0.6, 0.6, 7.5), (x, y, 3.75))
    # a car door and spikes at the way in
    bx("Decor", "skyblue", (3.4, 0.3, 2.4), (-6.5, -D / 2 - 0.6, 1.6), rot=(0, 8, 14))
    for k in range(5):
        bx("Decor", "walnut", (0.3, 0.3, 3.0), (-9 + k * 1.2, -D / 2 - 1.6, 1.1), rot=(-35, 0, 0))
    # the fire in a drum, middle of the camp
    cy(T.uid("FireDrum"), "rust", 1.0, 2.4, (0, -2, 1.2), collision="box", verts=10)
    for k in range(5):
        a = k * math.tau / 5
        T.t(T.sf.cyl(0.25, 1.2 + rnd.uniform(0, 0.6), loc=(math.cos(a) * 0.4, -2 + math.sin(a) * 0.4, 2.8), verts=5, bevel=0.0,
                     rot=(rnd.uniform(-15, 15), rnd.uniform(-15, 15), 0)), "DecorNeon", "signal", mat="Neon", cast_shadow=False)
    # the tarp lean-to on the left
    bx("Decor", "olive", (10, 8, 0.25), (-10.5, 4, 4.6), rot=(0, 24, 0))
    for (x, y) in ((-6, 0.5), (-6, 7.5)):
        bx("Decor", "walnut", (0.4, 0.4, 6.4), (x, y, 3.2))
    bx("Decor", "leather", (3, 5, 0.4), (-12, 4, 0.5))
    # drums and loot crates round the walls
    for (x, y, c) in ((13, -10, "signal"), (13.2, -7.6, "olive"), (-13, -11, "rust")):
        drum(x, y, c)
    drum(10, -12.5, "steel", tipped=True)
    T.R.crate(12, 2, size=2.6)
    T.R.crate(12.4, 5, size=2.2)
    # the pen at the back: welded bars round three sides, an open gate
    PY0, PY1 = 6, D / 2 - 0.6
    for x in [-13 + i * 1.3 for i in range(21)]:
        if -2.0 < x < 2.0:
            continue                                                        # the gate, hanging open
        cy("Decor", "gunmetal", 0.12, 6.0, (x, PY0, 3.0), verts=5)
    bx("Decor", "gunmetal", (26.5, 0.25, 0.25), (0, PY0, 5.9))
    bx("Decor", "gunmetal", (26.5, 0.25, 0.25), (0, PY0, 1.0))
    for x in (-13, 13):
        bx("Decor", "gunmetal", (0.3, PY1 - PY0, 0.3), (x, (PY0 + PY1) / 2, 5.9))
    bx("Decor", "gunmetal", (3.8, 0.2, 5.4), (3.6, PY0 - 1.6, 3.0), rot=(0, 0, 55))                # the gate
    for (x, y) in ((-8, 11), (0, 12.5), (8, 11)):
        bx("Decor", "cream", (2.0, 3.6, 0.3), (x, y, 0.3))                  # sacking where the crew sleep
    # a raider banner on a pole
    bx("Decor", "walnut", (0.4, 0.4, 11), (14.5, 13.5, 5.5))
    bx("Decor", "rust", (0.15, 3.4, 2.6), (14.5, 11.6, 9.4))
    bx("Decor", "hazard", (0.18, 3.4, 0.4), (14.5, 11.6, 8.6))
    sockets = {
        "Crew1": ((-8, 11, 0.3), 0), "Crew2": ((0, 12.5, 0.3), 0), "Crew3": ((8, 11, 0.3), 0),
        "Guard1": ((-6, -10, 0.3), 0), "Guard2": ((6, -9, 0.3), 0), "Guard3": ((-11, 0, 0.3), 0), "Guard4": ((10, 1, 0.3), 0),
        "Light1": ((0, -2, 4.0), 0),
    }
    return {"export": {"sockets": sockets, "pivot": (0, 0, 0), "step": "A6", "meta": {"place": "RaiderCamp"}}}


if __name__ == "__main__":
    T.export(build, "Bldg_RaiderCamp")
