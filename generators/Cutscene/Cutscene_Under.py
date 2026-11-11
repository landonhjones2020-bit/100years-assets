"""What the intro cutscene's plunge passes on its way down (A9; bible Section 4: "The camera plunges
down through the rock, past the bunker's rooms, deeper, to something glowing that opens its eyes";
"rock layers and the glimpse of the Source"):

    Cutscene_Strata          the ground between Mine Hill and the bunker's top row, cut open the way
                             the Command View cuts the bunker open: topsoil and roots, the water
                             main and Steadfast's conduit in the clay, fossils in the sandstone, an
                             old gallery of the Brightwater mine in the stone, the Mines' own rock
                             at the foot, and the shelter's lift shaft down the middle of it all
    Cutscene_SourceGlimpse   a mouth in the Source Chamber's rock: the living cavern, a dark mass
                             with glowing veins, and its eyes. Each eye is two parts of its own,
                             Eye<n> (the glow) and Eye<n>Pupil, which the game opens by their height

Both are reliefs a few studs deep, seen square on from the front (-Y) by a long lens, and stand in
front of the game's own rock (their backs are y = 0). Strata's origin is the middle of its foot;
SourceGlimpse's is the middle of the great eye.

    python3 generators/Cutscene/Cutscene_Under.py [Strata|SourceGlimpse ...]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import cutscene_plan as CP  # noqa: E402
import townkit as T  # noqa: E402

W = CP.STRATA["HalfWidth"]                       # 260: the title's wide view sees this much of the foot
H = CP.STRATA["Top"] - CP.STRATA["Bottom"]       # 128
SHAFT = 7.0                                      # the lift shaft's half width


# ---------------------------------------------------------------------------------------------
# Strata
# ---------------------------------------------------------------------------------------------

LAYERS = [  # (top at x = 0, main swatch, accents, how much its top wanders)
    (20.0, "basalt", ("rubber", "rubber", "stone"), 2.0),          # the Mines' rock, as the game draws it
    (46.0, "stone", ("ash", "basalt", "sandstone"), 2.6),
    (72.0, "sandstone", ("pine", "ash", "cream"), 3.0),
    (98.0, "leather", ("walnut", "copper", "sandstone"), 2.6),
    (H, "walnut", ("leather", "basalt", "walnut"), 0.0),
]


def _front(k, swatch, pts, **kw):
    """One facet of the cut face: (x, z, y) points given counter-clockwise as seen from the front."""
    k.add(swatch, [(x, y, z) for x, z, y in pts], [tuple(range(len(pts)))], **kw)


def layers(k):
    rng = random.Random(22)
    xs = [-W + i * 20.0 for i in range(int(2 * W / 20) + 1)]
    tops = [[-2.0 for _ in xs]]
    for top, _sw, _acc, wander in LAYERS:
        tops.append([top + (rng.uniform(-wander, wander) if wander else 0.0) for _ in xs])
    for li, (_top, main, accents, _w) in enumerate(LAYERS):
        lo, hi = tops[li], tops[li + 1]
        mid = [(a + b) / 2 + rng.uniform(-2.2, 2.2) for a, b in zip(lo, hi)]
        dep = [[rng.uniform(-0.7, 0.0) for _ in xs] for _ in range(3)]
        for row, (za, zb) in enumerate(((lo, mid), (mid, hi))):
            for i in range(len(xs) - 1):
                a = (xs[i], za[i], dep[row][i])
                b = (xs[i + 1], za[i + 1], dep[row][i + 1])
                c = (xs[i + 1], zb[i + 1], dep[row + 1][i + 1])
                d = (xs[i], zb[i], dep[row + 1][i])
                tris = ((a, b, c), (a, c, d)) if rng.random() < 0.5 else ((a, b, d), (b, c, d))
                for tri in tris:
                    sw = main if rng.random() < 0.72 else rng.choice(accents)
                    _front(k, sw, tri, smooth=-1.0)
    # specks in the Mines' rock, as in the game's; pebbles in the layers above
    for _ in range(34):
        x, z = rng.uniform(-W + 4, W - 4), rng.uniform(1.0, 17.0)
        if abs(x) > SHAFT + 2:
            k.box("rust", (0.7, 0.3, 0.7), (x, -0.8, z), rot=(0, rng.uniform(0, 90), 0))
    for _ in range(70):
        x, z = rng.uniform(-150, 150), rng.uniform(22.0, H - 3)
        if abs(x) < SHAFT + 3 or 26.0 < z < 40.0:
            continue
        sw = rng.choice(("stone", "basalt", "ash", "sandstone"))
        k.blob(sw, rng.uniform(0.7, 2.2), (x, -0.5, z), scale=(1.3, 0.4, rng.uniform(0.6, 1.0)), jitter=0.25, seed=rng.randrange(999))


def shaft(k):
    """The shelter's lift shaft: steel lining, ring beams, guide rails, the cables, and the car on its way down."""
    k.span("gunmetal", -SHAFT, SHAFT, -1.0, -0.3, -2.0, H)
    for side in (-1, 1):
        k.span("steel", side * SHAFT - 0.6, side * SHAFT + 0.6, -2.0, -0.3, -2.0, H)
        k.span("chrome", side * 3.4 - 0.16, side * 3.4 + 0.16, -1.5, -1.0, -2.0, H)               # guide rails
        k.pole("rubber", 0.11, (side * 0.7, -1.3, -2.0), (side * 0.7, -1.3, H), verts=4)             # cables
    z = 6.0
    n = 0
    while z < H - 2:
        k.span("steel", -SHAFT - 0.9, SHAFT + 0.9, -2.2, -0.3, z, z + 0.9)                           # a ring beam
        if n % 2 == 0:                                                                            # a hazard plate pointing down
            k.span("hazard", -2.2, 2.2, -1.25, -1.0, z + 4.0, z + 7.6)
            k.prism_y("rubber", [(-1.5, z + 6.9), (1.5, z + 6.9), (0.0, z + 4.7)], -1.4, -1.25)
        for side in (-1, 1):                                                                      # a lamp on the lining
            k.box("navy", (0.9, 0.5, 0.5), (side * 5.6, -1.2, z + 9.3))
            k.box("cream", (0.6, 0.3, 0.8), (side * 5.6, -1.4, z + 8.7), mat="Neon", shadow=False)
        z += 14.0
        n += 1
    # the car, part way down
    cz = 50.0
    k.span("teal", -5.2, 5.2, -2.6, -1.0, cz, cz + 10.5)
    k.span("navy", -5.5, 5.5, -2.8, -1.0, cz - 0.7, cz)
    k.span("navy", -5.5, 5.5, -2.8, -1.0, cz + 10.5, cz + 11.3)
    k.span("cream", -4.4, 4.4, -2.75, -2.6, cz + 8.0, cz + 9.9)
    k.text("teal", "STEADFAST", (0.0, -2.78, cz + 8.95), 1.15, depth=0.06, flat=True)
    for x in (-2.7, 0.0, 2.7):
        k.span("cream", x - 1.0, x + 1.0, -2.72, -2.6, cz + 2.6, cz + 7.0, mat="Neon", shadow=False)   # lit windows
        k.span("navy", x - 0.08, x + 0.08, -2.8, -2.7, cz + 2.6, cz + 7.0)
    k.span("hazard", -5.2, 5.2, -2.72, -2.6, cz + 0.2, cz + 1.4)
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        k.prism_y("rubber", [(x - 0.9, cz + 0.2), (x - 0.2, cz + 0.2), (x + 0.5, cz + 1.4), (x - 0.2, cz + 1.4)], -2.8, -2.72)
    k.cyl("steel", 1.3, 0.5, (0.0, -1.8, cz + 12.4), rot=(90, 0, 0), verts=10)                    # the sheave over it
    k.box("navy", (3.4, 0.8, 0.6), (0.0, -1.8, cz + 11.6))


def gallery(k):
    """An old gallery of the Brightwater mine in the stone, cut through by the shaft: timber sets, a cart on its rails."""
    rng = random.Random(31)
    z0, z1 = 27.0, 38.5
    for x0, x1 in ((-156.0, -SHAFT - 0.6), (SHAFT + 0.6, 118.0)):
        k.span("rubber", x0, x1, -0.5, -0.35, z0, z1)                                             # the dark of it
        k.span("basalt", x0, x1, -0.9, -0.35, z0 - 0.5, z0)                                         # its floor
        k.span("steel", x0, x1, -1.1, -0.9, z0, z0 + 0.22)                                          # the rail
        x = x0 + 5.0
        i = 0
        while x < x1 - 3:
            lean = rng.uniform(-2.5, 2.5)
            k.box("walnut", (1.0, 0.9, z1 - z0 - 1.0), (x, -1.2, (z0 + z1) / 2 - 0.5), rot=(0, lean, 0))
            k.box("pine", (0.5, 0.5, 0.35), (x, -1.0, z0 + 0.1))                                    # a sleeper end
            if i % 2 == 0 and x + 12 < x1:
                k.box("walnut", (13.4, 1.0, 1.1), (x + 6.0, -1.3, z1 - 0.9), rot=(0, rng.uniform(-1.5, 1.5), 0))   # the cap
            if i % 4 == 1:                                                                        # a lantern on a nail
                k.pole("rubber", 0.06, (x + 3.0, -1.2, z1 - 1.4), (x + 3.0, -1.2, z1 - 3.2), verts=4)
                k.box("brass", (0.7, 0.6, 0.9), (x + 3.0, -1.2, z1 - 3.7))
                k.box("hazard", (0.42, 0.5, 0.5), (x + 3.0, -1.5, z1 - 3.7), mat="Neon", shadow=False)
            x += 12.0
            i += 1
    # the cart
    cx = -52.0
    k.prism_y("rust", [(cx - 3.8, z0 + 4.4), (cx + 3.8, z0 + 4.4), (cx + 3.0, z0 + 1.3), (cx - 3.0, z0 + 1.3)], -2.0, -1.2)
    k.span("gunmetal", cx - 4.0, cx + 4.0, -2.1, -1.2, z0 + 4.2, z0 + 4.7)
    for dx in (-2.0, 2.0):
        k.cyl("rubber", 0.95, 0.5, (cx + dx, -1.9, z0 + 1.15), rot=(90, 0, 0), verts=10)
        k.cyl("steel", 0.35, 0.56, (cx + dx, -1.92, z0 + 1.15), rot=(90, 0, 0), verts=6)
    for dx, r in ((-1.8, 1.3), (0.2, 1.7), (2.0, 1.2)):
        k.blob("stone", r, (cx + dx, -1.7, z0 + 5.0), scale=(1.0, 0.5, 0.75), jitter=0.3, seed=int(dx * 10) + 40)
    # crates, a barrel, a pick against the wall
    k.box("pine", (3.2, 1.6, 3.0), (-96.0, -1.4, z0 + 1.5))
    k.box("walnut", (3.3, 1.7, 0.3), (-96.0, -1.4, z0 + 1.5))
    k.box("pine", (2.4, 1.4, 2.2), (-93.6, -1.5, z0 + 4.1), rot=(0, 8, 0))
    k.cyl("leather", 1.3, 3.4, (40.0, -1.6, z0 + 1.7), verts=10)
    for dz in (0.6, 2.9):
        k.cyl("steel", 1.36, 0.24, (40.0, -1.6, z0 + dz), verts=10)
    k.pole("pine", 0.16, (70.0, -1.3, z0), (72.4, -1.3, z0 + 5.6), verts=5)
    k.prism_y("steel", [(70.2, z0 + 5.2), (72.5, z0 + 5.0), (75.2, z0 + 6.2), (72.6, z0 + 5.9), (70.0, z0 + 6.0)], -1.5, -1.2)
    # where it fell in
    for i in range(9):
        k.blob(rng.choice(("stone", "basalt", "ash")), rng.uniform(1.4, 3.0), (104.0 + i * 1.9 + rng.uniform(-1, 1), -1.2, z0 + rng.uniform(0.6, 2.0 + i * 0.9)),
               scale=(1.0, 0.45, 0.8), jitter=0.3, seed=60 + i)


def fossils(k):
    """In the sandstone: a coiled shell, and the long bones of something that swam here."""
    # the shell: rings stepping forward to its middle
    sx, sz = -74.0, 60.0
    for i, (r, sw) in enumerate(((5.6, "cream"), (4.3, "sandstone"), (3.3, "cream"), (2.3, "sandstone"), (1.4, "cream"), (0.6, "sandstone"))):
        k.cyl(sw, r, 0.3, (sx + i * 0.35, -0.6 - i * 0.12, sz - i * 0.3), rot=(90, 0, 0), verts=14, round_=False)
    for i in range(11):
        a = math.radians(20 + i * 30)
        k.pole("ash", 0.11, (sx + math.cos(a) * 4.4, -0.75, sz + math.sin(a) * 4.4), (sx + math.cos(a) * 5.6, -0.75, sz + math.sin(a) * 5.6), verts=4)
    # the swimmer: skull, a long spine, ribs, paddles
    bx, bz = 34.0, 58.0
    spine = [(bx + i * 3.4, bz + math.sin(i * 0.5) * 2.6 + i * 0.25) for i in range(17)]
    for (xa, za), (xb, zb) in zip(spine, spine[1:]):
        k.pole("cream", 0.5, (xa, -0.8, za), (xb, -0.8, zb), verts=5)
    for i, (x, z) in enumerate(spine[3:11]):
        ln = 4.6 - abs(i - 3.5) * 0.7
        k.pole("cream", 0.22, (x, -0.8, z), (x + 0.9, -0.8, z - ln), verts=4, r_top=0.08)
        k.pole("cream", 0.22, (x, -0.8, z), (x + 0.5, -0.8, z + ln * 0.35), verts=4, r_top=0.08)
    hx, hz = spine[0]
    k.prism_y("cream", [(hx - 7.4, hz - 0.6), (hx - 6.8, hz + 1.0), (hx - 2.2, hz + 2.2), (hx + 0.6, hz + 1.3), (hx + 0.6, hz - 1.2), (hx - 2.6, hz - 1.9)], -1.2, -0.6)
    k.cyl("sandstone", 0.6, 0.2, (hx - 1.8, -1.25, hz + 0.7), rot=(90, 0, 0), verts=8, round_=False)        # its eye socket
    for i in range(6):
        k.prism_y("ash", [(hx - 6.6 + i * 0.8, hz - 0.5), (hx - 6.1 + i * 0.8, hz - 0.5), (hx - 6.35 + i * 0.8, hz - 1.3)], -1.25, -1.1)   # teeth
    for px, pz, turn in ((spine[4][0], spine[4][1] - 4.6, -30), (spine[9][0], spine[9][1] - 3.4, -40)):
        k.prism_y("cream", [(px, pz), (px + 1.4, pz - 0.4), (px + 3.4, pz - 5.2), (px + 1.2, pz - 6.0), (px - 0.8, pz - 2.0)], -1.0, -0.6)


def pipes(k):
    """In the clay: the town's water main, Steadfast's own conduit down to the shelter, an old footing."""
    rng = random.Random(44)
    z = 84.0
    for x0, x1 in ((-W, -SHAFT - 0.7), (SHAFT + 0.7, W)):
        k.cyl("steel", 1.7, x1 - x0, ((x0 + x1) / 2, -2.0, z), rot=(0, 90, 0), verts=8, caps=(False, False))
        x = x0 + 10.0
        while x < x1 - 4 and abs(x) < 170:
            k.cyl("gunmetal", 2.2, 0.8, (x, -2.0, z), rot=(0, 90, 0), verts=8)                      # a flange
            x += 26.0
    k.cyl("rust", 1.9, 0.3, (-22.0, -4.0, z), rot=(90, 0, 0), verts=10)                             # the stop valve's wheel
    k.cyl("gunmetal", 0.35, 2.0, (-22.0, -3.0, z), rot=(90, 0, 0), verts=6)
    k.box("gunmetal", (3.2, 3.0, 3.8), (-22.0, -2.0, z))
    for dz in (0.0, 1.8, 3.4):                                                                    # it drips
        k.blob("skyblue", 0.32, (-18.4, -2.2, z - 2.8 - dz * 1.4), scale=(0.7, 0.7, 1.3), seed=3)
    # Steadfast's conduit: along under the topsoil, then down beside the shaft
    cz = 93.0
    k.cyl("teal", 0.75, 96.0, (-SHAFT - 1.9 - 48.0, -2.6, cz), rot=(0, 90, 0), verts=8, caps=(False, False))
    k.cyl("teal", 0.75, cz + 2.0, (-SHAFT - 1.9, -2.6, cz / 2 - 1.0), verts=8, caps=(False, False))
    k.sphere("teal", 0.95, (-SHAFT - 1.9, -2.6, cz), segs=8, rings=5)
    for x in (-24.0, -44.0, -64.0, -84.0, -103.0):
        k.box("brass", (0.6, 2.0, 2.0), (x, -2.6, cz))
    for zz in (20.0, 44.0, 68.0):
        k.box("brass", (2.0, 2.0, 0.6), (-SHAFT - 1.9, -2.6, zz))
    k.span("cream", -60.0, -34.0, -3.42, -3.3, cz - 0.55, cz + 0.55)
    k.text("teal", "STEADFAST SHELTER CO.", (-47.0, -3.45, cz), 0.72, depth=0.05, flat=True)
    # an old footing: dressed blocks
    for row in range(3):
        for col in range(6 - row):
            k.box(rng.choice(("sandstone", "ash", "stone")), (5.6, 1.2, 3.0), (96.0 + col * 5.9 + row * 2.9, -1.2, 99.0 - 3.2 - row * 3.15),
                  rot=(0, rng.uniform(-1.2, 1.2), 0))


def topsoil(k):
    """Roots coming down from the hill, stones, and what people lose in the ground."""
    rng = random.Random(57)
    for i in range(15):
        x = -140.0 + i * 20.0 + rng.uniform(-6, 6)
        if abs(x) < SHAFT + 4:
            continue
        z = H
        r = rng.uniform(0.35, 0.6)
        pts = [(x, -1.0, z)]
        for _ in range(rng.randint(3, 5)):
            x += rng.uniform(-3.4, 3.4)
            z -= rng.uniform(3.5, 6.0)
            pts.append((x, -1.0, z))
        for j, (a, b) in enumerate(zip(pts, pts[1:])):
            k.pole("basalt" if i % 3 else "leather", r * (1 - j * 0.17), a, b, verts=4, r_top=r * (1 - (j + 1) * 0.17))
            if j >= 1 and rng.random() < 0.8:
                k.pole("basalt" if i % 3 else "leather", r * 0.4, a, (a[0] + rng.uniform(2, 5) * rng.choice((-1, 1)), -1.0, a[2] - rng.uniform(2, 4)), verts=3, r_top=0.05)
    # a time capsule the town buried, a boot, a bottle, bones a dog hid
    k.box("teal", (4.6, 2.0, 3.0), (-32.0, -1.6, 111.0), rot=(0, 9, 0))
    for dx in (-1.5, 1.5):
        k.box("brass", (0.4, 2.1, 3.1), (-32.0 + dx, -1.62, 111.0 + dx * 0.16), rot=(0, 9, 0))
    k.box("brass", (0.9, 0.3, 0.9), (-32.0, -2.7, 111.0), rot=(0, 9, 0))
    k.prism_y("rubber", [(52.0, 113.0), (55.6, 113.0), (55.8, 114.1), (54.0, 114.5), (53.6, 117.6), (52.0, 117.6)], -1.6, -0.8)
    k.cyl("mint", 0.7, 2.6, (-88.0, -1.3, 108.0), rot=(0, 62, 0), verts=7)
    k.cyl("mint", 0.3, 1.2, (-86.4, -1.3, 108.85), rot=(0, 62, 0), verts=6)
    for bx, bz, turn in ((84.0, 106.0, 20.0), (88.0, 104.4, -35.0)):
        a = math.radians(turn)
        p0 = (bx - math.cos(a) * 1.8, -1.0, bz - math.sin(a) * 1.8)
        p1 = (bx + math.cos(a) * 1.8, -1.0, bz + math.sin(a) * 1.8)
        k.pole("cream", 0.24, p0, p1, verts=5)
        for p in (p0, p1):
            k.sphere("cream", 0.42, p, segs=6, rings=4)


def strata(k):
    layers(k)
    shaft(k)
    gallery(k)
    fossils(k)
    pipes(k)
    topsoil(k)
    k.socket("Foot", (0, 0, 0), 0)
    k.socket("Top", (0, 0, H), 0)
    return {"views": [("the shaft", (0.0, -260.0, 64.0), (0.0, 0.0, 64.0), 30), ("the gallery", (-50.0, -70.0, 36.0), (-50.0, 0.0, 34.0), 40),
                      ("the clay", (-30.0, -80.0, 96.0), (-30.0, 0.0, 96.0), 44), ("the bones", (50.0, -80.0, 58.0), (50.0, 0.0, 60.0), 44)],
            "meta": {"face": "front -Y; the game turns it to face the Command View's camera"}}


# ---------------------------------------------------------------------------------------------
# The glimpse of the Source
# ---------------------------------------------------------------------------------------------

RIM = -6.0            # the rock's face round the mouth (studs in front of the back wall)
SLAB = (130.0, 62.0)  # half width and half height of the rock round the mouth
EYES = [  # (number, x, z, half width, half height, tilt in degrees)
    (1, 0.0, 0.0, 9.6, 4.9, 0.0),
    (2, -15.0, 6.6, 3.2, 1.6, 14.0),
    (3, 14.0, 8.0, 3.8, 1.9, -12.0),
    (4, -9.0, -9.4, 2.6, 1.3, -10.0),
    (5, 17.5, -5.0, 2.9, 1.5, 16.0),
    (6, -21.5, -3.2, 2.2, 1.1, 6.0),
    (7, 5.5, 12.6, 2.0, 1.0, 4.0),
]


def _mouth(n=28):
    """The cave mouth's outline: an uneven oval round the great eye."""
    rng = random.Random(9)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = 1.0 + 0.11 * math.sin(a * 3 + 0.6) + 0.07 * math.sin(a * 5 + 2.0) + rng.uniform(-0.05, 0.05)
        pts.append((math.cos(a) * 44.0 * r, math.sin(a) * 25.0 * r + 1.0))
    return pts


def _edge(a: float):
    """Where the ray at angle a from the middle leaves the slab's rectangle."""
    c, s = math.cos(a), math.sin(a)
    t = min(SLAB[0] / abs(c) if abs(c) > 1e-6 else 1e9, SLAB[1] / abs(s) if abs(s) > 1e-6 else 1e9)
    return (c * t, s * t)


def _almond(hw: float, hh: float, n: int = 9):
    """An eye's outline: two arcs meeting in points at its corners."""
    top = [(-hw + 2 * hw * i / n, hh * math.sin(math.pi * i / n) ** 0.8) for i in range(n + 1)]
    return top + [(x, -z) for x, z in reversed(top[1:-1])]


def source(k):
    rng = random.Random(77)
    mouth = _mouth()
    n = len(mouth)
    # the rock round the mouth, in the Source Chamber's colours, three rings of facets out to the slab's edge
    rings = [mouth]
    for f in (0.34, 0.68, 1.0):
        ring = []
        for i, (mx, mz) in enumerate(mouth):
            ex, ez = _edge(math.atan2(mz - 1.0, mx))
            j = 0.0 if f == 1.0 else 4.0
            ring.append((mx + (ex - mx) * f + rng.uniform(-j, j), mz + (ez - mz) * f + rng.uniform(-j, j)))
        rings.append(ring)
    deps = [[RIM + rng.uniform(-0.6, 0.4) for _ in range(n)] for _ in rings]
    for ri in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            a = (*rings[ri][i], deps[ri][i])
            b = (*rings[ri + 1][i], deps[ri + 1][i])
            c = (*rings[ri + 1][j], deps[ri + 1][j])
            d = (*rings[ri][j], deps[ri][j])
            tris = ((a, b, c), (a, c, d)) if rng.random() < 0.5 else ((a, b, d), (b, c, d))
            for tri in tris:
                sw = "rust" if rng.random() < 0.7 else rng.choice(("rubber", "rubber", "basalt"))
                _front(k, sw, tri, smooth=-1.0)
    # the mouth's lip, going back into the dark
    for i in range(n):
        j = (i + 1) % n
        a, d = mouth[i], mouth[j]
        ia = (a[0] * 0.9, (a[1] - 1.0) * 0.9 + 1.0)
        id_ = (d[0] * 0.9, (d[1] - 1.0) * 0.9 + 1.0)
        _front(k, "basalt" if i % 2 else "rubber", ((*a, deps[0][i]), (*d, deps[0][j]), (*id_, -1.0), (*ia, -1.0)), smooth=-1.0)
    # the back of the cavern: flesh-dark, lit from nowhere
    k.span("rubber", -50.0, 50.0, -0.4, 0.0, -30.0, 32.0)
    for i in range(16):                                                                           # folds in it
        x, z = rng.uniform(-40, 40), rng.uniform(-22, 24)
        k.blob("plum" if i % 3 else "basalt", rng.uniform(4.0, 8.0), (x, -0.6, z), scale=(1.5, 0.12, 0.9), jitter=0.3, seed=100 + i)
    # the mass
    for x, z, r, sw in ((0.0, 0.0, 17.0, "plum"), (-13.0, 3.0, 11.0, "basalt"), (13.5, 3.5, 11.5, "plum"), (-3.0, -9.0, 10.5, "basalt"),
                        (8.0, -8.0, 9.0, "plum"), (-22.0, -2.0, 7.0, "plum"), (21.0, -3.0, 7.5, "basalt"), (2.0, 12.0, 9.0, "basalt")):
        k.blob(sw, r, (x, -1.4, z), scale=(1.12, 0.14, 0.8), detail=2, jitter=0.16, seed=int(x * 7 + z * 3) + 300)
    # its limbs, out over the rock
    for i in range(11):
        a = math.radians(8 + i * 33 + rng.uniform(-8, 8))
        p = (math.cos(a) * 15.0, -2.2, math.sin(a) * 9.5)
        r = rng.uniform(1.5, 2.5)
        reach = rng.uniform(0.95, 1.35)
        for s in range(5):
            f = (s + 1) / 5
            bend = math.sin(f * math.pi) * rng.uniform(-5, 5)
            q = (math.cos(a) * (15.0 + (44.0 * reach - 15.0) * f) - math.sin(a) * bend, -2.2 - f * 5.6,
                 math.sin(a) * (9.5 + (25.0 * reach - 9.5) * f) + math.cos(a) * bend + 1.0 * f)
            k.pole("plum" if i % 2 else "basalt", r * (1 - s * 0.19), p, q, verts=5, r_top=r * (1 - (s + 1) * 0.19) + 0.05)
            p = q
    # veins: in the mass, running to the great eye, and out through the rock as the game's Source rock has them
    def vein(pts, r):
        for a, b in zip(pts, pts[1:]):
            k.pole("glow", r, a, b, verts=3, mat="Neon", shadow=False)

    for i in range(9):
        a = math.radians(i * 40 + rng.uniform(-12, 12))
        pts = [(math.cos(a) * 10.5, -3.9, math.sin(a) * 5.6)]
        for s in range(1, 4):
            d = 10.5 + s * rng.uniform(3.5, 5.5)
            pts.append((math.cos(a + rng.uniform(-0.25, 0.25)) * d, -3.9, math.sin(a + rng.uniform(-0.25, 0.25)) * d * 0.62))
        vein(pts, 0.2)
    for i in range(14):
        a = 2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / 14
        mx, mz = math.cos(a) * 47.0, math.sin(a) * 27.0 + 1.0
        ex, ez = _edge(a)
        pts = [(mx, RIM - 0.7, mz)]
        for s in range(1, 5):
            f = s / 4 * rng.uniform(0.75, 1.0)
            pts.append((mx + (ex - mx) * f + rng.uniform(-5, 5), RIM - 0.7, mz + (ez - mz) * f + rng.uniform(-5, 5)))
        vein(pts, 0.34)
    # the eyes: shut, the game opens them
    for num, x, z, hw, hh, tilt in EYES:
        m = T.Matrix.Translation((x, 0.0, z)) @ T.Matrix.Rotation(math.radians(tilt), 4, "Y")
        with k.at((0, 0, 0)):
            # local X -> X, local Y -> Z, local Z -> -Y (prism_y's own mapping), turned by the eye's tilt
            base = T.Matrix(((1, 0, 0, 0), (0, 0, -1, -4.0), (0, 1, 0, 0), (0, 0, 0, 1)))
            k.prism("glow", _almond(hw, hh), 0.5, m @ base, caps=(False, True), mat="Neon", shadow=False, part=f"Eye{num}", role=f"Eye{num}")
            slit = [(-hw * 0.11, -hh * 0.92), (hw * 0.11, -hh * 0.92), (hw * 0.2, 0.0), (hw * 0.11, hh * 0.92), (-hw * 0.11, hh * 0.92), (-hw * 0.2, 0.0)]
            lid = T.Matrix(((1, 0, 0, 0), (0, 0, -1, -4.5), (0, 1, 0, 0), (0, 0, 0, 1)))
            k.prism("rubber", slit, 0.22, m @ lid, caps=(False, True), part=f"Eye{num}Pupil", role=f"Eye{num}Pupil", shadow=False)
        # the socket it opens in
        k.blob("basalt", 1.0, (x, -3.2, z), scale=(hw * 1.22, 0.5, hh * 1.5), detail=2, jitter=0.05, seed=num)
    k.socket("Eye", (0, -4.5, 0), 0)
    return {"views": [("the mouth", (0.0, -300.0, 2.0), (0.0, 0.0, 2.0), 28), ("the mass", (0.0, -120.0, 0.0), (0.0, 0.0, 0.0), 34),
                      ("from the side", (-70.0, -90.0, 20.0), (0.0, 0.0, 0.0), 44)],
            "meta": {"face": "front -Y; origin the great eye; Eye<n> and Eye<n>Pupil open by their height"}}


ASSETS = {"Strata": (strata, "Cutscene_Strata", 8000), "SourceGlimpse": (source, "Cutscene_SourceGlimpse", 6000)}

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if a in ASSETS] or list(ASSETS)
    for name in names:
        fn, asset, budget = ASSETS[name]
        T.run(fn, asset, "Cutscene", budget=budget, step="A9", sun=(50, -20), ground=None)
