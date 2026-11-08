"""Room_WaterPurifier: the Water Purifier's furniture for one cell, by level (A1; bible
Section 6: Water, worker stat Smarts).

A riveted storage tank with a sight glass, filter columns fed by copper pipes, a hand pump and
a tap over a trough with buckets.

    L1  the tank, two filter columns, the tap and trough
    L2  adds a second tank and an electric pump with a gauge
    L3  adds a UV purifier: glass tubes glowing sky blue in a chrome frame

Sockets: WorkSpot1..n (2 / 3 / 4), Tap, Light1.
"""
import roomlib as R
import steadfast as sf

BACK = R.BACK


def tank(x, y, r=3.0, h=9.0, body="skyblue"):
    R.cy(R.uid("Tank"), body, r, h, (x, y, h / 2 + 0.6), collision="box", verts=12)
    R.cy("Decor", "gunmetal", r + 0.3, 0.6, (x, y, 0.3), verts=12)
    R.t(sf.sphere(r, loc=(x, y, h + 0.6), scale=(1, 1, 0.35), segs=12, rings=4), "Decor", body)
    for z in (2.5, h - 1.2):
        R.t(sf.torus(r + 0.05, 0.18, loc=(x, y, z), major_segs=12, minor_segs=3), "Decor", "steel")
    R.bx("Decor", "murk", (0.5, 0.3, h * 0.6), (x, y - r - 0.05, h * 0.55), mat="Glass", transparency=0.3)  # sight glass
    R.bx("Decor", "chrome", (0.7, 0.2, h * 0.62), (x, y - r + 0.05, h * 0.55))


def filters(x0, y, n=2):
    for i in range(n):
        x = x0 + i * 2.4
        R.cy(R.uid("Filter"), "porcelain", 0.9, 6.5, (x, y, 3.25), collision="box", verts=10)
        R.cy("Decor", "teal", 0.95, 0.5, (x, y, 6.6), verts=10)
        R.cy("Decor", "teal", 0.95, 0.5, (x, y, 0.25), verts=10)
        R.pipe_up(x, y + 0.5, 6.8, 12.5, r=0.25, swatch="copper")
    R.pipe_run(x0 - 1.0, x0 + 2.4 * (n - 1) + 1.0, y + 0.5, 12.5, r=0.3, swatch="copper")


def tap_and_trough(x, y):
    R.bx(R.uid("Trough"), "steel", (6.0, 2.2, 2.2), (x, y, 1.1), collision="box", bevel=0.15)
    R.bx("Decor", "murk", (5.4, 1.6, 0.1), (x, y, 2.0), mat="Glass", transparency=0.2)
    R.pipe_up(x, BACK - 0.5, 2.2, 6.0, r=0.25, swatch="chrome")
    R.bx("Decor", "chrome", (0.3, 2.2, 0.3), (x, BACK - 1.5, 5.6))
    R.valve(x + 0.8, BACK - 0.7, 5.0, r=0.45, swatch="teal")
    for i, dx in enumerate((-4.2, 4.0)):
        R.cy("Decor", "steel" if i else "teal", 0.8, 1.4, (x + dx, y - 1.4, 0.7), verts=10)
        R.t(sf.torus(0.8, 0.07, loc=(x + dx, y - 1.4, 1.5), rot=(90, 0, 0), major_segs=8, minor_segs=3), "Decor", "chrome")
    return (x, y - 2.4, 0.0)


def build(level: int) -> dict:
    sockets: dict = {}
    tank(-9.5, 10.0)
    filters(-3.5, 13.0, n=2)
    tap = tap_and_trough(6.5, BACK - 2.2)
    sockets["Tap"] = (tap, 0.0)
    work = [(-9.5, 5.5, 0.0), tap]
    R.pipe_run(-9.5, -3.5, 13.5, 9.0, r=0.35, swatch="copper")
    if level >= 2:
        tank(11.0, -10.5, r=2.4, h=7.0, body="teal")
        R.bx(R.uid("Pump"), "olive", (3.4, 2.4, 2.6), (-11.0, -11.0, 1.3), collision="box", bevel=0.2)
        R.cy("Decor", "gunmetal", 1.0, 0.8, (-11.0, -12.4, 1.6), rot=(90, 0, 0), verts=10)
        R.gauge(-11.0, 3.6, y=-11.0 - 1.25, r=0.55)
        work.append((-11.0, -8.6, 180.0))
    if level >= 3:
        ux, uy = 2.0, -11.5                                     # UV purifier
        R.bx(R.uid("UVFrame"), "chrome", (7.0, 2.4, 0.4), (ux, uy, 0.2), collision="box")
        R.bx("Decor", "chrome", (7.0, 2.4, 0.4), (ux, uy, 5.8))
        for i in range(4):
            x = ux - 2.6 + i * 1.75
            R.cy("DecorNeon", "skyblue", 0.42, 5.2, (x, uy, 3.0), mat="Neon", verts=8, cast_shadow=False)
        for dx in (-3.4, 3.4):
            R.bx("Decor", "chrome", (0.3, 2.4, 5.6), (ux + dx, uy, 3.0))
        work.append((ux, uy + 2.6, 180.0))
    R.poster(-11.0, 9.0, band="skyblue", accent="teal", w=2.6, h=3.4, side="left")
    R.work_sockets(work, sockets)
    sockets["Light1"] = ((0.0, 2.0, 12.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_WaterPurifier", "Rooms", build, {"room": "WaterPurifier", "shell": "Kit_Shell"})
