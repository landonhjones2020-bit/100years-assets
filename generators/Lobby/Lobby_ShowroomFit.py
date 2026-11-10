"""Lobby_ShowroomFit: what stands in the Steadfast showroom (A9; bible Section 21): the blast door
on show, supply stacks and shelves, the rope round the bunker model, the directory, a lounge,
banners, posters, a clock and plants. Decoration only (its few colliders are the big pieces).
Lobby_Showroom is the building, Lobby_ShowroomHall the hall (same origin and pivot).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402
from showroom_dims import *  # noqa: E402,F401,F403


def placard(k, x, y, z, yaw, lines, w=3.4, h=2.2):
    """A small sign on a brass stand, read from the side it faces (yaw 0: from -Y)."""
    with k.at((x, y, z), yaw):
        k.cyl("brass", 0.7, 0.16, (0, 0, 0.08), verts=10)
        k.pole("brass", 0.1, (0, 0, 0.1), (0, 0, 3.3), verts=5)
        k.box("brass", (w + 0.3, 0.16, h + 0.3), (0, 0, 4.0), rot=(-12, 0, 0))
        k.box("cream", (w, 0.2, h), (0, -0.04, 4.0), rot=(-12, 0, 0))
        f = k.face((-w / 2, -0.16, 4.0 - h / 2), 0)
        zz = h - 0.55
        for i, s in enumerate(lines):
            f.text("teal" if i == 0 else "navy", s, w / 2, zz, 0.46 if i == 0 else 0.3, n=0.02, depth=0.03, flat=True, max_w=w * 0.88)
            zz -= 0.62 if i == 0 else 0.46


def blast_door_sample(k, x, y, z, yaw):
    """The Steadfast door, on a plinth, standing ajar: what the brochure promises."""
    with k.at((x, y, z), yaw):
        k.box("walnut", (12.0, 6.0, 0.7), (0, 0, 0.35))
        k.box("brass", (12.2, 6.2, 0.12), (0, 0, 0.7))
        k.collider((12.0, 6.0, 12.0), (0, 0, 6.0), name="Display")
        # the frame: a thick steel ring of four members with bolted corners
        for (a, b, c, d) in ((-4.8, -3.8, 0.7, 11.3), (3.8, 4.8, 0.7, 11.3)):
            k.span("gunmetal", a, b, -0.9, 0.9, c, d)
        k.span("gunmetal", -4.8, 4.8, -0.9, 0.9, 10.3, 11.3)
        k.span("gunmetal", -4.8, 4.8, -0.9, 0.9, 0.7, 1.2)
        for sx in (-1, 1):
            for zz in (1.5, 4.4, 7.4, 10.3):
                k.cyl("steel", 0.22, 0.2, (sx * 4.3, -0.95, zz), rot=(90, 0, 0), verts=6)
        for i in range(7):
            k.span("hazard" if i % 2 == 0 else "rubber", -4.8 + i * 9.6 / 7, -4.8 + (i + 1) * 9.6 / 7, -0.96, -0.9, 0.7, 1.2)
        # the door: hinged on the right, swung out 28 degrees
        with k.at((3.8, -0.6, 1.2), -152):
            w, h, t = 7.6, 9.1, 1.1
            k.span("steel", 0, w, -t / 2, t / 2, 0, h)
            k.span("gunmetal", 0.5, w - 0.5, -t / 2 - 0.12, t / 2 + 0.12, 0.5, h - 0.5)
            k.span("teal", 0.9, w - 0.9, t / 2 + 0.1, t / 2 + 0.2, 5.6, h - 0.9)           # the enamel maker's panel
            k.text("cream", "STEADFAST", (w / 2, t / 2 + 0.2, 7.2), 0.9, depth=0.05, yaw=180, flat=True, max_w=5.2)
            k.text("cream", "4 TONS OF PEACE OF MIND", (w / 2, t / 2 + 0.2, 6.25), 0.36, depth=0.05, yaw=180, flat=True, max_w=5.2)
            for (ux, uz) in ((1.0, 1.0), (w - 1.0, 1.0), (1.0, h - 1.0), (w - 1.0, h - 1.0), (1.0, h / 2), (w - 1.0, h / 2)):
                for sy in (-1, 1):
                    k.cyl("chrome", 0.2, 0.16, (ux, sy * (t / 2 + 0.16), uz), rot=(90, 0, 0), verts=6)
            for sy in (-1, 1):     # the wheel, both faces
                c = (w / 2, sy * (t / 2 + 0.7), 3.3)
                k.cyl("gunmetal", 0.45, 0.9, (w / 2, sy * (t / 2 + 0.4), 3.3), rot=(90, 0, 0), verts=8)
                ring = [(c[0] + math.cos(a) * 1.5, c[1], c[2] + math.sin(a) * 1.5) for a in [i * math.pi / 5 for i in range(11)]]
                k.wire("chrome", ring, r=0.14, verts=5)
                for a in (0.3, 0.3 + 2.094, 0.3 + 4.188):
                    k.pole("chrome", 0.1, c, (c[0] + math.cos(a) * 1.5, c[1], c[2] + math.sin(a) * 1.5), verts=4)
            for zz in (1.4, h - 1.4):   # hinges
                k.cyl("gunmetal", 0.35, 1.6, (-0.1, 0, zz), verts=8)
    k.light((x - 4, y - 5, z + 12), colour="cream", brightness=0.8, range_=22)


def barrel(k, x, y, z=0.0, body="olive", r=1.25, h=3.3):
    k.cyl(body, r, h, (x, y, z + h / 2), verts=10)
    for zz in (0.12, h * 0.36, h * 0.66, h - 0.12):
        k.cyl("gunmetal", r + 0.07, 0.16, (x, y, z + zz), verts=10)
    k.cyl("gunmetal", 0.22, 0.12, (x + r * 0.45, y, z + h + 0.03), verts=6)


def tin_shelf(k, x, y, z, yaw, w=9.0, h=10.0, d=2.0, levels=4):
    """An open shelf of tins, jars and packets: a year of dinners."""
    with k.at((x, y, z), yaw):
        for sx in (-1, 1):
            k.span("gunmetal", sx * w / 2 - 0.15, sx * w / 2 + 0.15, -d / 2, d / 2, 0, h)
        k.span("steel", -w / 2, w / 2, d / 2 - 0.1, d / 2, 0, h)
        rng = k.rng
        tins = ("rust", "hazard", "teal", "cream", "signal", "leaf", "blush", "mint")
        for lv in range(levels):
            zz = 0.5 + lv * (h - 1.0) / levels
            k.span("steel", -w / 2, w / 2, -d / 2, d / 2, zz - 0.14, zz)
            u = -w / 2 + 0.6
            while u < w / 2 - 0.8:
                kind = rng.random()
                if kind < 0.55:
                    sw = rng.choice(tins)
                    rr = rng.uniform(0.36, 0.5)
                    hh = rng.uniform(0.9, 1.3)
                    for row in range(2):
                        k.cyl(sw, rr, hh, (u + rr, -d / 2 + 0.6 + row * 0.95, zz + hh / 2), verts=6, caps=(False, True))
                        k.cyl("cream", rr + 0.02, hh * 0.45, (u + rr, -d / 2 + 0.6 + row * 0.95, zz + hh / 2), verts=6, caps=(False, False))
                    u += rr * 2 + 0.16
                elif kind < 0.85:
                    sw = rng.choice(tins)
                    bw, bh = rng.uniform(0.9, 1.5), rng.uniform(1.1, 1.7)
                    k.box(sw, (bw, 1.4, bh), (u + bw / 2, -d / 2 + 0.9, zz + bh / 2), open_=("z-",))
                    k.box("cream", (bw * 0.7, 0.04, bh * 0.4), (u + bw / 2, -d / 2 + 0.18, zz + bh * 0.55), open_=("y+",))
                    u += bw + 0.14
                else:
                    u += 0.7
        k.span("teal", -w / 2 - 0.2, w / 2 + 0.2, -d / 2 - 0.1, d / 2, h, h + 1.5)
        k.text("cream", "STOCKED FOR A CENTURY", (0, -d / 2 - 0.1, h + 0.75), 0.72, depth=0.05, flat=True, max_w=w * 0.9)


def directory(k, x, y, z):
    """The showroom's directory: a teal totem with three arrows."""
    with k.at((x, y, z), 0):
        k.box("walnut", (5.0, 2.2, 0.5), (0, 0, 0.25))
        k.span("teal", -2.0, 2.0, -0.45, 0.45, 0.5, 8.2)
        k.span("chrome", -2.15, 2.15, -0.55, 0.55, 8.2, 8.45)
        k.span("chrome", -2.15, 2.15, -0.55, 0.55, 0.5, 0.75)
        k.collider((5.0, 2.2, 9.0), (0, 0, 4.5), name="Directory")
        L.starburst(k, (0, 0, 9.9), r=1.3, spikes=8, flat=True, neon=False, ball="signal")
        for sy, yaw in ((-1, 0), (1, 180)):
            f = k.face((-2.0 * (1 if sy < 0 else -1), sy * 0.45, 0), yaw)
            rows = (("CLASS SHOP", 6.9, -1), ("ELEVATORS", 4.9, 0), ("LOADOUT", 2.9, 1))
            for label, zz, way in rows:
                # read from the street side, CLASS SHOP is to the left (west); from the hall side the arrows swap
                side = way if sy < 0 else -way
                f.on("cream", 0.3, 3.7, zz - 0.62, zz + 0.62, 0.1)
                f.text("teal", label, 2.0, zz + 0.12, 0.5, n=0.1, depth=0.04, flat=True, max_w=2.5)
                if side == 0:
                    pts = [(2.0, zz - 0.52), (1.72, zz - 0.3), (2.28, zz - 0.3)] if sy > 0 else [(2.0, zz - 0.2), (1.72, zz - 0.46), (2.28, zz - 0.46)]
                else:
                    ux = 2.0 + side * 1.35
                    pts = [(ux + side * 0.28, zz - 0.38), (ux - side * 0.1, zz - 0.2), (ux - side * 0.1, zz - 0.56)]
                f.outline("signal", pts, 0.1, 0.16)


def bench(k, x, y, z, yaw, w=9.0):
    """A long vinyl bench on chrome legs."""
    with k.at((x, y, z), yaw):
        k.span("teal", -w / 2, w / 2, -1.1, 1.1, 1.3, 1.9)
        k.span("teal", -w / 2, w / 2, 0.75, 1.15, 1.9, 3.9)
        for i in range(1, 4):
            k.span("cream", -w / 2 + i * w / 4 - 0.05, -w / 2 + i * w / 4 + 0.05, -1.12, 1.16, 1.3, 3.92)
        for sx in (-1, 1):
            for sy in (-0.8, 0.8):
                k.pole("chrome", 0.09, (sx * (w / 2 - 0.7), sy, 1.3), (sx * (w / 2 - 0.5), sy * 1.15, 0), verts=4)


def water_cooler(k, x, y, z, yaw=0):
    with k.at((x, y, z), yaw):
        k.box("porcelain", (1.9, 1.7, 3.6), (0, 0, 1.8))
        k.box("teal", (1.92, 0.06, 0.9), (0, -0.86, 2.7))
        k.cyl("chrome", 0.12, 0.4, (-0.4, -0.95, 2.3), rot=(90, 0, 0), verts=5)
        k.cyl("signal", 0.12, 0.4, (0.4, -0.95, 2.3), rot=(90, 0, 0), verts=5)
        k.lathe("skyblue", [(0.75, 3.6), (0.8, 5.2), (0.6, 5.7), (0.3, 5.9)], (0, 0, 0), verts=10, mat="Glass", transparency=0.4, shadow=False)
        k.lathe("porcelain", [(0.25, 3.6), (0.25, 3.9)], (0.95, -0.2, 0), verts=6)


def rug(k, x, y, z, r, rings=(("navy", 1.0), ("cream", 0.9), ("teal", 0.78), ("cream", 0.3), ("signal", 0.22))):
    for i, (sw, f) in enumerate(rings):
        k.cyl(sw, r * f, 0.03, (x, y, z + 0.015 + i * 0.012), verts=32, caps=(False, True))


def fit(k):
    wf = k.face((X0 + WT, Y0 + 1.2, 0), 90)        # the west wall, inside: u = y - (Y0 + 1.2)
    ef = k.face((X1 - WT, Y1 - WT, 0), 270)        # the east wall, inside: u = (Y1 - WT) - y

    def wu(y):
        return y - (Y0 + 1.2)

    def eu(y):
        return (Y1 - WT) - y

    # -- the bunker model's rope, its sign, plants by the glass --------------------------------
    cx, cy = CUTAWAY
    L.rope_ring(k, cx, cy, FLOOR, 10.6, n=8, gap=0)
    placard(k, cx + 12.4, cy + 3.4, FLOOR, 105, ["YOUR FAMILY SHELTER", "A cutaway model", "Scale 1 to 40"], w=4.0)
    L.planter(k, X0 + WT + 3.2, Y0 + 4.2, FLOOR, seed=3, tall=True)
    L.planter(k, X1 - WT - 3.2, Y0 + 4.2, FLOOR, seed=5, tall=True)
    for sx in (-1, 1):
        L.planter(k, sx * 11.6, Y0 + 3.4, FLOOR, r=1.8, h=1.9, seed=7 + sx)

    # -- the door on show, and a century of supplies -------------------------------------------
    dx, dy = DOOR_SAMPLE
    blast_door_sample(k, dx, dy, FLOOR, -32)
    placard(k, dx - 8.6, dy - 2.2, FLOOR, -32, ["THE STEADFAST DOOR", "Sealed in 9 seconds", "Guaranteed 100 years"], w=4.0)
    for (ax, ay, az, yaw) in ((55.0, -30.0, 0, 8), (58.2, -30.4, 0, -4), (56.4, -27.0, 0, 20), (56.4, -30.2, 2.8, 14), (59.6, -27.2, 0, -12)):
        L.crate(k, ax, ay, FLOOR + az, yaw=yaw)
    barrel(k, 58.5, -41.5, FLOOR)
    barrel(k, 55.4, -42.6, FLOOR, body="teal")
    barrel(k, 57.6, -38.4, FLOOR)
    k.collider((7.0, 7.5, 6.0), (57.2, -29.0, FLOOR + 3.0), name="Display")
    k.collider((5.5, 6.0, 4.0), (57.2, -40.8, FLOOR + 2.0), name="Display")
    tin_shelf(k, X1 - WT - 1.2, -20.5, FLOOR, 270, w=9.0)
    k.collider((2.4, 9.4, 11.5), (X1 - WT - 1.2, -20.5, FLOOR + 5.75), name="Display")

    # -- the directory inside the door ---------------------------------------------------------
    directory(k, 13.5, -38.5, FLOOR)

    # -- a lounge in the back corner, west -----------------------------------------------------
    rug(k, -52.0, 20.0, FLOOR, 7.6)
    L.coffee_table(k, -52.0, 20.0, FLOOR)
    L.googie_chair(k, -56.6, 21.4, FLOOR, yaw=100)
    L.googie_chair(k, -48.2, 23.8, FLOOR, yaw=-125, shell="teal")
    L.googie_chair(k, -51.6, 15.4, FLOOR, yaw=175, shell="hazard")
    L.planter(k, X0 + WT + 3.0, 28.0, FLOOR, seed=9, tall=True)
    L.poster(k, wf, wu(16.0), 11.6, title="SLEEP SOUND", sub="UNDERGROUND", motif="bunker")
    L.poster(k, wf, wu(25.0), 11.6, bg="navy", band="cream", title="ROOM FOR ALL", sub="THE FAMILY PLAN", motif="family")
    L.poster(k, wf, wu(-36.0), 11.6, bg="signal", band="cream", accent="teal", title="THE ATOMIC AGE", sub="IS A SAFE AGE", motif="atom")
    L.poster(k, wf, wu(-26.0), 11.6, title="BUILT TO LAST", sub="A CENTURY", motif="bunker")

    # -- the east wall: a bench, the clock, the water cooler -----------------------------------
    bench(k, X1 - WT - 1.5, 19.0, FLOOR, 270, w=11.0)
    L.wall_clock(k, ef, eu(19.0), 13.0, r=2.0)
    water_cooler(k, X1 - WT - 1.4, 9.5, FLOOR, 270)
    L.planter(k, X1 - WT - 3.0, 28.0, FLOOR, seed=11, tall=True)
    L.poster(k, ef, eu(-34.0), 11.6, bg="navy", band="cream", title="ROOM FOR ALL", sub="THE FAMILY PLAN", motif="family")
    L.poster(k, ef, eu(9.5), 12.4, w=5.0, h=6.6, bg="signal", band="cream", accent="teal", title="STAY CALM", sub="STAY STEADFAST", motif="atom")

    # -- banners under the beams ---------------------------------------------------------------
    for (x, y) in ((-33.0, -14.0), (33.0, -14.0), (-33.0, 14.0), (33.0, 14.0)):
        L.banner(k, x, y, CEIL - 0.9, w=5.2, h=10.5)


def build(k):
    fit(k)
    return {"views": [
        ("entry", (-6, -44, 7.0), (10, 30, 8), 78),
        ("door", (16, -22, 8.5), (40, -38, 5), 62),
        ("lounge", (-30, 4, 8.0), (-60, 24, 5), 62),
        ("east", (26, 30, 9.0), (64, 10, 7), 66),
    ]}


if __name__ == "__main__":
    import Lobby_Showroom as Show
    import Lobby_ShowroomHall as Hall
    T.run(build, "Lobby_ShowroomFit", "Lobby", budget=20000, context=(Show.exterior, Hall.hall), res=(1100, 620), sun_strength=3.0)
