"""Cutscene_Hill: Mine Hill, at the east end of Main Street, the morning the bomb fell (A9; bible
Sections 3 and 4: "the hillside path into the Steadfast blast door"; the bunker "was dug into the
hillside above the old Brightwater mine").

The hill's west face with the stepped path up the street's axis, its landings and lamps, the
terrace in front of the shelter's door, STEADFAST in letters on the slope above it, and the old
mine's headframe on the south shoulder. The door itself is Cutscene_BlastDoor. Built in the
set's own space (generators/Cutscene/cutscene_plan.py), so its pivot is the set's origin.

    python3 generators/Cutscene/Cutscene_Hill.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import cutscene_plan as CP  # noqa: E402
import props as P  # noqa: E402
import townkit as T  # noqa: E402

AX = CP.AXIS
GRASS = ("leaf", "leaf", "avocado", "leaf", "forest")


def _noise(x, y, s=1.0):
    return math.sin(x * 0.037 * s + y * 0.051 * s) * 0.5 + math.sin(x * 0.083 * s - y * 0.029 * s + 2.1) * 0.3 + math.sin(y * 0.13 * s + 0.4) * 0.2


def terrain(k):
    """The ground: a faceted sheet over the hill, its lines snapped to the path's breaks, the
    terrace's edges and the headwall, so the cut is exact where concrete meets it."""
    rng = random.Random(7)
    gx0, gx1, gy0, gy1 = CP.GROUND
    x_start = CP.HILL_ROAD[1] - 6.0
    special_x = set(CP.stair_breaks()) | {CP.STAIR_TOP_X, CP.DOOR_X, CP.DOOR_X + 0.01, x_start, gx1}
    regular_x = {round(x_start + i * 10.0, 2) for i in range(int((gx1 - x_start) / 10.0) + 1)}
    xs = sorted(special_x | {x for x in regular_x if all(abs(x - s) >= 2.4 for s in special_x)})
    ys = {round(gy0 + j * 10.0, 2) for j in range(int((gy1 - gy0) / 10.0) + 1)}
    special_y = {AX - 58.0, AX - 51.0, AX - 44.0, AX - 37.0, AX - 30.0, AX - 20.0, AX - 10.6, AX, AX + 10.6, AX + 20.0, AX + 30.0, AX + 37.0, AX + 44.0, AX + 51.0, AX + 58.0, gy0, gy1}
    ys = sorted(y for y in ys | special_y if y in special_y or not any(abs(y - s) < 3.0 for s in special_y))
    fixed_x = special_x
    verts, index = [], {}
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            near = abs(y - AX) < 60.0 and x <= CP.DOOR_X + 12.0
            jx = 0.0 if (x in fixed_x or near) else rng.uniform(-3.0, 3.0)
            jy = 0.0 if (y in special_y or near) else rng.uniform(-3.0, 3.0)
            px, py = x + jx, y + jy
            z = CP.ground_z(min(px, CP.DOOR_X) if x <= CP.DOOR_X else max(px, CP.DOOR_X + 0.01), py)
            if x <= xs[0] + 0.01:
                z = min(z, 0.0) - 0.3          # tucked under the pavement
            elif not near:
                z += rng.uniform(-0.9, 0.9)
            index[i, j] = len(verts)
            verts.append((px, py, z))
    buckets: dict[str, list] = {}
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            a, b, c, d = index[i, j], index[i + 1, j], index[i + 1, j + 1], index[i, j + 1]
            tris = ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d))
            for t in tris:
                p0, p1, p2 = (T.Vector(verts[n]) for n in t)
                n = (p1 - p0).cross(p2 - p0)
                if n.length < 1e-6:
                    continue
                n.normalize()
                cx, cy = (p0.x + p1.x + p2.x) / 3, (p0.y + p1.y + p2.y) / 3
                slope = math.degrees(math.acos(max(-1.0, min(1.0, n.z))))
                if slope > 70.0:
                    continue                    # the cut the headwall hides
                v = _noise(cx, cy) + rng.uniform(-0.18, 0.18)
                if slope > 44.0:
                    sw = "sandstone" if v > -0.1 else "stone"
                elif v > 0.42:
                    sw = "avocado"
                elif v < -0.38:
                    sw = "forest"
                else:
                    sw = "leaf"
                buckets.setdefault(sw, []).append(t)
    for sw, faces in buckets.items():
        used = sorted({n for f in faces for n in f})
        remap = {n: m for m, n in enumerate(used)}
        k.add(sw, [verts[n] for n in used], [tuple(remap[n] for n in f) for f in faces], smooth=-1.0)


def nose(x):
    return CP.stair_z(x)


def path(k):
    """The stepped path: four flights of eight broad steps, three landings, low concrete walls
    either side with a lamp at each landing, and the arch at its foot."""
    w = CP.STAIR_W / 2
    top = [(CP.HILL_ROAD[1] - 6.0, 0.06), (CP.STAIR_FOOT_X, 0.06)]
    x, z = CP.STAIR_FOOT_X, 0.0
    for f in range(CP.FLIGHTS):
        for s in range(CP.STEPS):
            z += CP.STEP_RISE
            top.append((x, z))
            x += CP.STEP_TREAD
            top.append((x, z))
        if f < CP.FLIGHTS - 1:
            x += CP.LANDING
            top.append((x, z))
    under = [(CP.STAIR_TOP_X, CP.TERRACE_Z - 3.0), (CP.STAIR_FOOT_X + 3.0, -3.0), (CP.HILL_ROAD[1] - 6.0, -3.0)]
    k.prism_y("ash", top + under, AX - w, AX + w, smooth=-1.0)
    # the steps' noses: a pale line on each, so the flights read from Main Street
    x, z = CP.STAIR_FOOT_X, 0.0
    for f in range(CP.FLIGHTS):
        for s in range(CP.STEPS):
            z += CP.STEP_RISE
            k.span("porcelain", x - 0.02, x + 0.22, AX - w + 0.02, AX + w - 0.02, z - 0.16, z + 0.02)
            x += CP.STEP_TREAD
        x += CP.LANDING
    # a brass handrail up the middle, on posts
    posts = []
    for b0, b1 in list(zip(CP.stair_breaks()[0::2], CP.stair_breaks()[1::2]))[:-1]:      # not the top flight: the door is seen up it
        z0, z1 = nose(b0 + 0.01), nose(b1)
        k.pole("gunmetal", 0.16, (b0 + 0.6, AX, z0), (b0 + 0.6, AX, z0 + 3.3), verts=5)
        k.pole("gunmetal", 0.16, (b1 - 0.3, AX, z1), (b1 - 0.3, AX, z1 + 3.3), verts=5)
        k.pole("gunmetal", 0.16, ((b0 + b1) / 2, AX, (z0 + z1) / 2 + 0.4), ((b0 + b1) / 2, AX, (z0 + z1) / 2 + 3.3), verts=5)
        k.pole("brass", 0.2, (b0 + 0.2, AX, z0 + 3.3), (b1 + 0.1, AX, z1 + 3.3), verts=6)
        posts.append((b0, b1))
    # cheek walls: concrete, a darker coping, a globe lamp at each landing's end
    for sy in (-1, 1):
        y0, y1 = AX + sy * w, AX + sy * (w + 1.6)
        prof_top, prof_bot = [], []
        xs = [CP.HILL_ROAD[1] - 2.0] + CP.stair_breaks() + [CP.STAIR_TOP_X + 0.0]
        for x in xs:
            prof_top.append((x, nose(x) + 3.0))
            prof_bot.append((x, nose(x) - 3.0))
        k.prism_y("sandstone", prof_top + prof_bot[::-1], min(y0, y1), max(y0, y1), smooth=-1.0)
        cope_top = [(x, z + 0.45) for x, z in prof_top]
        k.prism_y("stone", cope_top + prof_top[::-1], min(y0, y1) - 0.25, max(y0, y1) + 0.25, smooth=-1.0)
        ym = (y0 + y1) / 2
        for b in CP.stair_breaks()[1:-1:2] + [CP.STAIR_FOOT_X - 1.0]:
            zb = nose(b) + 3.45
            k.box("stone", (2.2, 2.2, 1.0), (b + (CP.LANDING / 2 if b > CP.STAIR_FOOT_X else 0.0), ym, zb + 0.5))
            lx = b + (CP.LANDING / 2 if b > CP.STAIR_FOOT_X else 0.0)
            k.lathe("gunmetal", [(0.55, 0), (0.55, 0.3), (0.3, 0.6), (0.22, 5.2), (0.42, 5.4), (0.42, 5.6)], (lx, ym, zb + 1.0), verts=6)
            k.sphere("porcelain", 1.05, (lx, ym, zb + 7.5), segs=8, rings=5)
            k.cyl("gunmetal", 0.5, 0.3, (lx, ym, zb + 8.55), verts=6, r_top=0.12)
    # the arch at the foot: two posts and the shelter's name over the way up
    ax = CP.STAIR_FOOT_X - 3.2
    for sy in (-1, 1):
        k.box("stone", (2.6, 2.6, 2.2), (ax, AX + sy * 12.2, 1.1))
        k.box("teal", (1.3, 1.3, 15.5), (ax, AX + sy * 12.2, 9.9))
        k.box("cream", (1.5, 1.5, 0.5), (ax, AX + sy * 12.2, 5.0))
        k.sphere("brass", 0.95, (ax, AX + sy * 12.2, 18.3), segs=8, rings=5)
    k.box("teal", (1.0, 27.0, 5.4), (ax, AX, 14.9))
    k.box("cream", (1.1, 25.8, 4.3), (ax - 0.08, AX, 14.9))
    k.box("signal", (1.2, 25.8, 0.3), (ax - 0.1, AX, 12.95))
    with k.at((ax - 0.66, AX, 15.5), -90):
        k.text("navy", "STEADFAST SHELTER", (0, 0, 0), 2.1, depth=0.22, font="AlfaSlabOne-Regular", max_w=23.5, flat=True)
        k.text("signal", "Built to Last a Century", (0, 0, -1.85), 1.15, depth=0.22, font="Lobster-Regular", max_w=18.0, flat=True)
    # the same on its back, for those looking down from the door
    k.box("cream", (0.2, 25.8, 4.3), (ax + 0.52, AX, 14.9))
    with k.at((ax + 0.66, AX, 15.0), 90):
        k.text("teal", "BRIGHTWATER", (0, 0, 0), 2.0, depth=0.22, font="AlfaSlabOne-Regular", max_w=22.0, flat=True)


def terrace(k):
    """The apron in front of the door: concrete, a hazard line at the threshold, low walls with
    rails either side of the path's head, a pennant mast at each corner."""
    tx0, tx1, ty0, ty1 = CP.TERRACE
    z = CP.TERRACE_Z
    k.span("ash", tx0, tx1 + 1.5, ty0, ty1, z - 3.0, z)
    k.span("sandstone", tx0 - 0.4, tx0 + 0.8, ty0, AX - CP.STAIR_W / 2 - 1.6, z - 3.2, z + 0.25)      # the lip either side of the stair head
    k.span("sandstone", tx0 - 0.4, tx0 + 0.8, AX + CP.STAIR_W / 2 + 1.6, ty1, z - 3.2, z + 0.25)
    # paving joints and a hazard line across the threshold
    for i in range(1, 4):
        k.span("stone", tx0 + i * 3.5 - 0.06, tx0 + i * 3.5 + 0.06, ty0 + 0.3, ty1 - 0.3, z, z + 0.03)
    for j in range(-4, 5):
        k.span("stone", tx0 + 0.3, tx1, AX + j * 6.0 - 0.06, AX + j * 6.0 + 0.06, z, z + 0.03)
    n = 14
    for i in range(n):
        y0 = AX - CP.DOOR_W / 2 - 1.0 + i * (CP.DOOR_W + 2.0) / n
        k.span("hazard" if i % 2 == 0 else "rubber", tx1 - 4.6, tx1 - 3.2, y0, y0 + (CP.DOOR_W + 2.0) / n, z, z + 0.05)
    # rails on the west edge
    for sy in (-1, 1):
        ya, yb = AX + sy * (CP.STAIR_W / 2 + 1.9), AX + sy * (ty1 - AX - 0.6)
        steps = 4
        for i in range(steps + 1):
            y = ya + (yb - ya) * i / steps
            k.pole("gunmetal", 0.18, (tx0 + 0.2, y, z + 0.25), (tx0 + 0.2, y, z + 3.6), verts=5)
        for h in (3.6, 2.0):
            k.pole("brass" if h > 3 else "gunmetal", 0.2 if h > 3 else 0.12, (tx0 + 0.2, ya, z + h), (tx0 + 0.2, yb, z + h), verts=6)
        # the pennant mast
        my = AX + sy * (ty1 - AX - 2.2)
        k.lathe("stone", [(1.3, 0), (1.3, 0.8), (0.9, 1.2)], (tx0 + 2.4, my, z), verts=8)
        k.pole("porcelain", 0.26, (tx0 + 2.4, my, z + 1.2), (tx0 + 2.4, my, z + 24.0), verts=6, r_top=0.16)
        k.sphere("brass", 0.5, (tx0 + 2.4, my, z + 24.3), segs=6, rings=4)
        pen = [(0.0, 0.0), (0.0, 4.4), (8.2, 2.2)]
        m = T.Matrix.Translation((tx0 + 2.55, my, z + 19.2)) @ T.Matrix.Rotation(T.R(90), 4, "X") @ T.Matrix.Rotation(T.R(180 if sy < 0 else 180), 4, "Y")
        k.prism("teal" if sy < 0 else "signal", pen, 0.12, m)
        k.prism("cream", [(0.0, 1.6), (0.0, 2.8), (5.2, 2.2)], 0.2, m @ T.Matrix.Translation((0, 0, -0.04)))
    # two benches with their backs to the walls, a trash can, flower tubs: an ordinary morning
    with k.at((tx1 - 7.0, ty0 + 2.2, z), 180):
        P.bench(k)
    with k.at((tx1 - 7.0, ty1 - 2.2, z), 0):
        P.bench(k)
    for sy in (-1, 1):
        with k.at((tx0 + 5.4, AX + sy * 24.0, z)):
            P.flower_tub(k, seed=3 + sy)


def wall_top(d: float) -> float:
    """The retaining wall's top at d studs from the axis: level over the portal, then down with the hill."""
    y = AX + d
    return max(CP.ground_z(CP.DOOR_X + 3.6, y), CP.ground_z(CP.DOOR_X + 0.02, y)) + 1.6


def retaining_wall(k):
    """The shoulders of the wall that holds the hill behind the terrace: from the portal's
    headwall (Cutscene_BlastDoor, 60 wide) out to where the cut runs to nothing."""
    x0, x1 = CP.DOOR_X, CP.DOOR_X + 3.0
    a, b = CP.WALL_HALF, CP.CORRIDOR[1] + 3.0
    for sy in (-1, 1):
        ds = [a + (b - a) * i / 7 for i in range(8)]
        top = [(AX + sy * d, max(wall_top(sy * d), CP.ground_z(CP.DOOR_X - 0.5, AX + sy * d) + 0.4)) for d in ds]
        bot = [(AX + sy * d, CP.ground_z(CP.DOOR_X - 0.5, AX + sy * d) - 2.5) for d in ds]
        k.prism_x("sandstone", top + bot[::-1], x0, x1, smooth=-1.0)
        cope = [(y, z + 0.9) for y, z in top]
        k.prism_x("stone", cope + top[::-1], x0 - 0.45, x1 + 0.45, smooth=-1.0)
        for i, d in enumerate(ds[1:-1]):                                  # buttresses, shorter and shorter
            y = AX + sy * d
            zt = top[i + 1][1] - 0.6
            zb = CP.ground_z(CP.DOOR_X - 2.0, y) - 1.0
            if zt - zb < 2.0:
                continue
            k.prism_x("sandstone", [(y - 0.9, zb), (y + 0.9, zb), (y + 0.9, zt), (y - 0.9, zt)], x0 - 0.9, x0)
            k.prism_y("stone", [(x0 - 2.6, zb), (x0 - 0.9, zb), (x0 - 0.9, zb + (zt - zb) * 0.55)], y - 0.9, y + 0.9)


def letters(k):
    """STEADFAST on the hillside, each letter on its own posts, like a name over a whole town."""
    word = "STEADFAST"
    h = CP.LETTER_H
    pitch = 10.6
    x = CP.LETTERS_X
    y0 = AX + (len(word) - 1) / 2 * pitch            # reading left to right from the town: north to south
    base = max(CP.ground_z(x, AX + d) for d in range(-52, 53, 4)) + 2.2
    for i, ch in enumerate(word):
        y = y0 - i * pitch
        with k.at((x, y, base + h / 2), -90):
            k.text("porcelain", ch, (0, 0, 0), h, depth=1.4, font="AlfaSlabOne-Regular", back=True)
        for dy in (-2.6, 2.6):
            g = CP.ground_z(x + 3.0, y + dy)
            k.pole("gunmetal", 0.3, (x + 1.0, y + dy, base + h * 0.72), (x + 5.5, y + dy, g - 1.0), verts=4)
            k.pole("gunmetal", 0.26, (x + 0.6, y + dy, base + 0.3), (x + 0.6, y + dy, CP.ground_z(x + 0.6, y + dy) - 1.0), verts=4)
    k.box("gunmetal", (0.5, pitch * len(word) + 2.0, 0.5), (x + 0.9, AX, base + 0.2))
    k.box("gunmetal", (0.5, pitch * len(word) + 2.0, 0.5), (x + 0.9, AX, base + h * 0.72))


def mine(k):
    """The old Brightwater mine: a timber headframe with its wheel, a tin-roofed hoist shed, a
    boarded-up adit lower down with the company's sign, a cart left on a stub of track."""
    mx, my = CP.MINE
    g = CP.ground_z(mx, my)
    with k.at((mx, my, g - 1.0)):
        legs = [(-6.5, -5.0), (6.5, -5.0), (-6.5, 5.0), (6.5, 5.0)]
        top = 34.0
        for lx, ly in legs:
            k.pole("walnut", 0.75, (lx, ly, 0), (lx * 0.42, ly * 0.42, top), verts=5, r_top=0.55)
        for z in (9.0, 18.0, 27.0):
            f = 1.0 - 0.58 * z / top
            for a, b in ((0, 1), (2, 3), (0, 2), (1, 3)):
                k.pole("leather", 0.38, (legs[a][0] * f, legs[a][1] * f, z), (legs[b][0] * f, legs[b][1] * f, z), verts=4)
            f2 = 1.0 - 0.58 * (z - 9.0) / top
            k.pole("leather", 0.3, (legs[0][0] * f2, legs[0][1] * f2, z - 9.0), (legs[1][0] * f, legs[1][1] * f, z), verts=4)
            k.pole("leather", 0.3, (legs[3][0] * f2, legs[3][1] * f2, z - 9.0), (legs[2][0] * f, legs[2][1] * f, z), verts=4)
        k.box("walnut", (8.0, 6.6, 0.8), (0, 0, top + 0.2))
        for sy in (-1, 1):
            k.box("walnut", (0.7, 0.7, 5.0), (0, sy * 2.2, top + 2.8))
        k.pole("gunmetal", 0.3, (0, -2.8, top + 4.4), (0, 2.8, top + 4.4), verts=5)
        k.cyl("rust", 3.3, 0.5, (0, 0, top + 4.4), rot=(90, 0, 0), verts=12)
        k.cyl("basalt", 2.6, 0.56, (0, 0, top + 4.4), rot=(90, 0, 0), verts=12)
        for a in range(0, 180, 45):
            k.box("rust", (6.0, 0.3, 0.3), (0, 0, top + 4.4), rot=(0, a, 0))
        # the long back stay down to the hoist shed
        k.pole("walnut", 0.6, (-1.0, 0, top), (-26.0, 0, CP.ground_z(mx - 26.0, my) - g + 1.0), verts=5)
        k.pole("rubber", 0.1, (0.0, 0, top + 7.6), (-24.0, 0, CP.ground_z(mx - 24.0, my) - g + 8.0), verts=3)
    sx = mx - 28.0
    sg = CP.ground_z(sx, my)
    with k.at((sx, my, sg - 1.2)):
        k.box("leather", (12.0, 10.0, 9.0), (0, 0, 4.5))
        k.prism_x("rust", [(-5.8, 9.0), (0.0, 12.6), (5.8, 9.0)], -6.6, 6.6, smooth=-1.0)
        k.box("basalt", (0.2, 3.4, 5.6), (-6.05, -1.0, 2.8))
        k.box("pine", (0.25, 4.4, 0.5), (-6.1, -1.0, 6.2))
        for i in range(5):
            k.box("walnut" if i % 2 else "pine", (0.22, 0.9, 5.4), (-6.14, -2.6 + i * 0.85, 2.8), rot=(0, 0, 0))
        k.box("pine", (0.3, 4.6, 0.7), (-6.2, -1.0, 2.2), rot=(24, 0, 0))
    # the adit, low on the slope where Main Street can see it: timbers, boards, the sign
    ax_, ay = 322.0, AX - 66.0
    ag = CP.ground_z(ax_, ay)
    with k.at((ax_, ay, ag - 0.6), 0):
        k.box("basalt", (3.0, 9.0, 8.0), (2.2, 0, 4.0))
        for sy in (-1, 1):
            k.pole("walnut", 0.7, (-0.2, sy * 4.6, 0), (0.2, sy * 4.1, 9.0), verts=5)
        k.pole("walnut", 0.75, (0.2, -5.4, 9.3), (0.2, 5.4, 9.3), verts=5)
        for i, zz in enumerate((1.6, 3.5, 5.4, 7.2)):
            k.box("pine" if i % 2 == 0 else "leather", (0.3, 9.6, 1.25), (-0.5, 0, zz), rot=((i % 2) * 5 - 3, 0, 0))
        k.box("pine", (0.34, 10.4, 1.1), (-0.72, 0, 4.4), rot=(28, 0, 0))
        k.box("cream", (0.3, 8.4, 2.4), (-0.6, 0, 11.4))
        k.box("rust", (0.36, 8.8, 0.3), (-0.62, 0, 10.2))
        with k.at((-0.82, 0, 11.75), -90):
            k.text("rust", "BRIGHTWATER MINE", (0, 0, 0), 0.9, depth=0.12, font="Oswald-Bold", max_w=7.6, flat=True)
            k.text("navy", "CLOSED 1931", (0, 0, -1.05), 0.75, depth=0.12, font="Oswald-Bold", max_w=6.0, flat=True)
        # a cart on a stub of track
        for sy in (-1, 1):
            k.box("rust", (9.0, 0.3, 0.3), (-5.0, sy * 1.5, 0.75))
        for i in range(5):
            k.box("walnut", (0.7, 4.2, 0.3), (-8.6 + i * 1.9, 0, 0.5))
        k.box("rust", (4.4, 3.2, 2.2), (-5.4, 0, 2.6))
        k.box("basalt", (4.0, 2.8, 0.4), (-5.4, 0, 3.72))
        k.blob("stone", 1.2, (-5.8, 0.2, 3.9), scale=(1.4, 1.0, 0.6), detail=1, jitter=0.2, seed=5)
        for cx in (-6.8, -4.0):
            for sy in (-1, 1):
                k.cyl("basalt", 0.7, 0.3, (cx, sy * 1.5, 1.45), rot=(90, 0, 0), verts=8)


def rocks(k):
    rng = random.Random(11)
    n = 0
    while n < 16:
        x = rng.uniform(CP.HILL_X + 10.0, 446.0)
        y = rng.uniform(CP.GROUND[2] + 50.0, CP.GROUND[3] - 40.0)
        if abs(y - AX) < 34.0 and x < CP.DOOR_X + 40.0:
            continue
        r = rng.uniform(2.0, 5.5)
        k.blob("stone" if n % 3 else "sandstone", r, (x, y, CP.ground_z(x, y) + r * 0.15), scale=(rng.uniform(0.9, 1.6), rng.uniform(0.9, 1.5), rng.uniform(0.5, 0.8)),
               detail=1, jitter=0.22, seed=n)
        n += 1


def build(k):
    terrain(k)
    path(k)
    terrace(k)
    retaining_wall(k)
    letters(k)
    mine(k)
    rocks(k)
    k.socket("StairFoot", (CP.STAIR_FOOT_X, AX, 0.0), 90)
    k.socket("StairHead", (CP.STAIR_TOP_X, AX, CP.TERRACE_Z), 90)
    k.socket("Door", (CP.DOOR_X, AX, CP.TERRACE_Z), 90)
    return {"views": [
        ("from Main Street", (60.0, AX - 4.0, 7.0), (CP.DOOR_X, AX, 36.0), 24),
        ("the path", (CP.HILL_ROAD[0] + 6.0, AX - 30.0, 10.0), (CP.STAIR_TOP_X - 10.0, AX, 22.0), 46),
        ("the terrace", (CP.STAIR_TOP_X - 24.0, AX + 34.0, 48.0), (CP.DOOR_X, AX, 34.0), 50),
        ("from above", (180.0, AX - 190.0, 150.0), (372.0, AX - 30.0, 30.0), 44),
    ]}


if __name__ == "__main__":
    T.run(build, "Cutscene_Hill", "Cutscene", budget=14000, step="A9", sun=(50, -70), ground="#6F9B4C", ground_size=1600.0, sun_strength=3.4)
