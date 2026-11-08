"""Room_Generator: the Generator's furniture for one cell, by level (A1; bible Section 6: extra
power, worker stat Strength).

A Steadfast diesel set: a long engine block with cooling fins and a flywheel under a guard,
an exhaust stack up into the ceiling, fuel drums and a breaker panel.

    L1  one diesel set, fuel drums, the breaker panel
    L2  a second, smaller set and a fuel tank with a gauge
    L3  the diesel replaced by an atomic turbine: a chrome drum with glowing rings

Sockets: WorkSpot1..n (2 / 3 / 4), Breaker, Light1.
"""
import math

import roomlib as R
import steadfast as sf

BACK = R.BACK


def diesel(x, y, scale=1.0):
    L, Wd, Hh = 10.0 * scale, 4.2 * scale, 4.6 * scale
    R.bx(R.uid("Engine"), "olive", (L, Wd, Hh), (x, y, Hh / 2 + 0.4), collision="box", bevel=0.3)
    R.bx("Decor", "gunmetal", (L + 0.6, Wd + 0.6, 0.4), (x, y, 0.2))
    for i in range(7):                               # cooling fins
        R.bx("Decor", "steel", (0.25, Wd + 0.3, Hh * 0.6), (x - L / 2 + 1.2 + i * 0.9 * scale, y, Hh * 0.55 + 0.4))
    fx = x + L / 2 + 0.6 * scale                     # flywheel and its guard
    R.cy("Decor", "gunmetal", 1.7 * scale, 0.6, (fx, y, Hh * 0.55 + 0.4), rot=(0, 90, 0), verts=12)
    R.t(sf.torus(1.9 * scale, 0.18, loc=(fx + 0.1, y, Hh * 0.55 + 0.4), rot=(0, 90, 0), major_segs=12, minor_segs=3), "Decor", "hazard")
    R.bx("Decor", "signal", (1.6 * scale, 1.2 * scale, 1.0 * scale), (x - L / 4, y - Wd / 2 - 0.3, Hh + 0.1), bevel=0.1)
    return (x, y - Wd / 2 - 1.6, 0.0)


def exhaust(x, y, top=R.H):
    R.pipe_up(x, y, 4.0, top, r=0.55, swatch="gunmetal")
    R.t(sf.torus(0.62, 0.12, loc=(x, y, 8.0), major_segs=8, minor_segs=3), "Decor", "steel")


def breaker(x):
    y = BACK - 0.6
    R.bx(R.uid("Breaker"), "gunmetal", (4.0, 1.2, 5.0), (x, y, 6.5), collision="box", bevel=0.12)
    for i in range(4):
        R.bx("Decor", "cream", (0.4, 0.15, 1.2), (x - 1.35 + i * 0.9, y - 0.65, 6.8))
        R.bx("Decor", "rubber", (0.25, 0.25, 0.5), (x - 1.35 + i * 0.9, y - 0.8, 7.0))
    R.bx("DecorNeon", "leaf", (0.5, 0.1, 0.3), (x + 1.4, y - 0.66, 8.5), mat="Neon", cast_shadow=False)
    R.bx("Decor", "hazard", (3.6, 0.12, 0.35), (x, y - 0.66, 4.4))
    return (x, y - 2.4, 0.0)


def turbine(x, y):
    R.cy(R.uid("Turbine"), "chrome", 3.4, 9.0, (x, y, 4.0), rot=(0, 90, 0), collision="box", verts=12)
    for dx in (-3.0, 0.0, 3.0):
        R.t(sf.torus(3.5, 0.22, loc=(x + dx, y, 4.0), rot=(0, 90, 0), major_segs=12, minor_segs=3), "DecorNeon", "crystal",
            mat="Neon", cast_shadow=False)
    for dx in (-4.0, 4.0):
        R.bx("Decor", "gunmetal", (1.4, 6.0, 1.2), (x + dx, y, 0.6))
    R.cy("Decor", "brass", 1.4, 1.0, (x - 5.0, y, 4.0), rot=(0, 90, 0), verts=10)
    R.cy("Decor", "brass", 1.4, 1.0, (x + 5.0, y, 4.0), rot=(0, 90, 0), verts=10)


def build(level: int) -> dict:
    sockets: dict = {}
    work = []
    if level < 3:
        work.append(diesel(-3.0, 10.5))
        exhaust(-6.5, 12.0)
    else:
        turbine(-3.0, 10.5)
        work.append((-3.0, 5.6, 0.0))
        exhaust(-9.5, 13.5)
    sockets["Breaker"] = (breaker(10.5), 0.0)
    work.append((10.5, BACK - 3.0, 0.0))
    for i, (x, y) in enumerate(((-12.0, -10.0), (-9.4, -11.2), (-12.2, -12.8))):    # fuel drums
        R.barrel(x, y, body="signal" if i == 1 else "olive")
    if level >= 2:
        work.append(diesel(4.0, -10.0, scale=0.7))
        R.cy(R.uid("FuelTank"), "hazard", 1.8, 7.0, (12.0, 9.0, 3.9), collision="box", verts=10)
        R.t(sf.sphere(1.8, loc=(12.0, 9.0, 7.4), scale=(1, 1, 0.45), segs=10, rings=4), "Decor", "hazard")
        R.gauge(12.0, 5.5, y=9.0 - 1.8, r=0.7)
        R.pipe_run(12.0, 3.0, 9.0, 1.5, r=0.3, swatch="copper")
    if level >= 3:
        work.append((-6.5, 5.6, 0.0))
    R.poster(-11.0, 9.0, band="hazard", accent="signal", w=2.6, h=3.4, side="left")
    R.work_sockets([(x, y, 0.0) for (x, y, _) in work], sockets)
    sockets["Light1"] = ((0.0, 2.0, 12.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_Generator", "Rooms", build, {"room": "Generator", "shell": "Kit_Shell"})
