"""townlib: walls, roofs and dressing the Brightwater Ruins generators share (A5; bible Section 12;
STYLE.md). Prompt 16's map (game/server/Lib/BrightwaterMap.luau) places each building at its pivot.

Space: X across the building, -Y its front (it faces the street), +Y its back, Z up from the
ground; the pivot is the footprint's centre on the ground (export with pivot=(0, 0, 0)).
Sockets use the same space: Container1.. (a container's spot, yaw 0 faces the front),
Survivor1.. (a trapped survivor), BigFind (a big find) and, for signs, parts with Role "Sign"
(the map writes the place's name on their front). Keep every socket at least 8 studs from
every other one (the nearest prompt per key wins in game).

Everything is a ruin: walls stop at broken heights, roofs have holes, windows are empty. Parts
that block players get collision "box" (their own part names), the rest is decoration that
export_asset(merge="room") pools into one MeshPart per material.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Rooms"))
import steadfast as sf  # noqa: E402
import roomlib as R  # noqa: E402
from roomlib import bx, cy, t, uid  # noqa: E402,F401

BUDGET = 6000  # surface building (bible Section 19)


def reset():
    R.reset_ids()


def wall_x(swatch, x0, x1, y, z0, z1, holes=(), thick=1.0, collision="box", part=None, jag=None, trim=None):
    """A wall along X (its face centred on y) from x0 to x1, z0 to z1, with rectangular holes
    [(xa, xb, za, zb)]. jag: a list of (x, height) points for a broken top instead of z1."""
    base = _base(part)
    xs = sorted({x0, x1} | {h[0] for h in holes} | {h[1] for h in holes})
    for a, b in zip(xs, xs[1:]):
        mid = (a + b) / 2
        top = z1 if jag is None else _jag_height(jag, mid, z1)
        cuts = sorted((h[2], h[3]) for h in holes if h[0] <= mid <= h[1])
        z = z0
        for za, zb in cuts + [(top, top)]:
            if za > z + 0.01:
                bx(_segment(base, collision), swatch, (b - a, thick, min(za, top) - z), ((a + b) / 2, y, (z + min(za, top)) / 2),
                   collision=collision)
            z = max(z, zb)
    if trim:
        bx("Decor", trim, (x1 - x0 + 0.2, thick + 0.3, 0.6), ((x0 + x1) / 2, y, z0 + 0.3))


def wall_y(swatch, y0, y1, x, z0, z1, holes=(), thick=1.0, collision="box", part=None, jag=None):
    """The same along Y at x (holes [(ya, yb, za, zb)])."""
    base = _base(part)
    ys = sorted({y0, y1} | {h[0] for h in holes} | {h[1] for h in holes})
    for a, b in zip(ys, ys[1:]):
        mid = (a + b) / 2
        top = z1 if jag is None else _jag_height(jag, mid, z1)
        cuts = sorted((h[2], h[3]) for h in holes if h[0] <= mid <= h[1])
        z = z0
        for za, zb in cuts + [(top, top)]:
            if za > z + 0.01:
                bx(_segment(base, collision), swatch, (thick, b - a, min(za, top) - z), (x, (a + b) / 2, (z + min(za, top)) / 2),
                   collision=collision)
            z = max(z, zb)


def _base(part):
    """A wall's part name without its number: every colliding segment gets its own (Wall3, Wall4...)."""
    return (part or "Wall").rstrip("0123456789") or "Wall"


def _segment(base, collision):
    """Each colliding segment is its own MeshPart: merged, their Box collision would be the whole
    wall's bounding box and fill every door and window (A5 playtest: the diner's door was solid)."""
    return uid(base) if collision != "none" else "Decor"


def _jag_height(jag, at, default):
    best = default
    for (x, h) in jag:
        if abs(at - x) < 1e-6 or (at >= x):
            best = h
    return best


def facade(swatch, pts, y, thick=1.0, part=None, collision="box", bevel=0.05):
    """A false front or gable: a vertical slab whose outline pts [(x, z), ...] is drawn as seen
    from the street; its street face sits at y - thick (it extrudes towards -Y from y)."""
    part = part or uid("Facade")
    ob = sf.profile_slab(pts, thick, loc=(0, y, 0), rot=(90, 0, 0), bevel=bevel, segments=1)
    return t(ob, part, swatch, collision=collision)


def can(x, y, swatch="steel", h=2.6, r=0.9, lid="gunmetal"):
    """A dented trash can with its lid knocked aside."""
    cy(uid("Can"), swatch, r, h, (x, y, h / 2), collision="box", verts=10)
    cy("Decor", lid, r + 0.1, 0.2, (x + 0.9, y - 0.6, 0.1), rot=(0, 0, 0), verts=10)


def floor(swatch, w, d, z=0.0, thick=0.5, part="Floor"):
    bx(part, swatch, (w, d, thick), (0, 0, z + thick / 2), collision="box")


def roof(swatch, x0, x1, y0, y1, z, holes=(), thick=0.6, rim=None):
    """A flat roof slab with ragged holes [(xa, xb, ya, yb)] (broken through), as strips."""
    xs = sorted({x0, x1} | {h[0] for h in holes} | {h[1] for h in holes})
    for a, b in zip(xs, xs[1:]):
        mid = (a + b) / 2
        cuts = sorted((h[2], h[3]) for h in holes if h[0] <= mid <= h[1])
        y = y0
        for ya, yb in cuts + [(y1, y1)]:
            if ya > y + 0.01:
                bx("Roof", swatch, (b - a, ya - y, thick), ((a + b) / 2, (y + ya) / 2, z + thick / 2), collision="box")
            y = max(y, yb)
    if rim:
        for yy in (y0, y1):
            bx("Decor", rim, (x1 - x0 + 0.4, 0.5, 0.8), ((x0 + x1) / 2, yy, z + 0.6))


def awning(x0, x1, y, z, depth=4.0, stripes=("signal", "cream"), n=8, tilt=14):
    """A striped canvas awning over a shopfront (its back edge at y, sloping out to -Y)."""
    w = (x1 - x0) / n
    for i in range(n):
        bx("Decor", stripes[i % len(stripes)], (w, depth, 0.2), (x0 + w * (i + 0.5), y - depth / 2, z),
           rot=(tilt, 0, 0))
    bx("Decor", "chrome", (x1 - x0 + 0.3, 0.25, 0.25), ((x0 + x1) / 2, y - depth + 0.1, z - depth * math.sin(math.radians(tilt)) / 2))


def sign(x, y, z, w, h, swatch="cream", rim="chrome", part=None):
    """A sign plate facing -Y with a rim; Role Sign: the map writes the place's name on it."""
    part = part or uid("Sign")
    bx("Decor", rim, (w + 0.5, 0.4, h + 0.5), (x, y + 0.15, z), bevel=0.1)
    sf.tag(sf.box((w, 0.3, h), loc=(x, y, z), bevel=0.05, segments=1), part, swatch, role="Sign")


def window_frame(x0, x1, y, za, zb, swatch="chrome", bar=0.3):
    """A thin frame round an empty window (the glass is long gone)."""
    for z in (za, zb):
        bx("Decor", swatch, (x1 - x0 + bar, bar + 0.2, bar), ((x0 + x1) / 2, y, z))
    for x in (x0, x1):
        bx("Decor", swatch, (bar, bar + 0.2, zb - za), (x, y, (za + zb) / 2))


def rubble(x, y, n=6, spread=3.0, seed=1, swatch="stone", big=1.2):
    """A heap of broken masonry and a plank or two (decoration)."""
    rng = random.Random(seed)
    for i in range(n):
        s = big * rng.uniform(0.45, 1.0)
        bx("Decor", swatch if i % 3 else "sandstone", (s, s * rng.uniform(0.7, 1.2), s * 0.6),
           (x + rng.uniform(-spread, spread) / 2, y + rng.uniform(-spread, spread) / 2, s * 0.25),
           rot=(rng.uniform(-15, 15), rng.uniform(-15, 15), rng.uniform(0, 90)))
    bx("Decor", "walnut", (spread * 1.3, 0.5, 0.25), (x, y, 0.5), rot=(0, rng.uniform(-20, 20), rng.uniform(0, 180)))


def scorch(x, y, z, w, h, side="front"):
    """A soot stain over a window or door (decoration on the wall's face)."""
    yy = y - 0.55 if side == "front" else y + 0.55
    bx("Decor", "basalt", (w, 0.08, h), (x, yy, z))


def plank_floor(w, d, swatch="walnut", z=0.0):
    floor(swatch, w, d, z=z)
    for i in range(int(w // 4)):
        bx("Decor", "stone", (0.12, d - 0.4, 0.04), (-w / 2 + 4 * (i + 1), 0, z + 0.52))


def back_row(n, w, d, inset=2.5, margin=4.0, z=0.5):
    """Container sockets along the back wall, facing the front."""
    s = {}
    for i in range(n):
        x = -w / 2 + margin + (w - 2 * margin) * (0.5 if n == 1 else i / (n - 1))
        s[f"Container{i + 1}"] = ((x, d / 2 - inset, z), 0.0)
    return s


def export(build_fn, asset):
    """Standard entry for a building: preview, then export with the footprint-centre pivot."""
    def build():
        reset()
        out = build_fn()
        out.setdefault("export", {})
        out["export"].setdefault("budget", BUDGET)
        out["export"].setdefault("merge", "room")
        out["export"].setdefault("pivot", (0, 0, 0))
        out["export"].setdefault("step", "Setup")
        return out
    sf.run_main(build, asset, "Surface")


def storefront(w, d, h, wall, trim="chrome", kick="teal", door=(-5, 5), windows=((-17, -8), (8, 17)), win_z=(3.2, 9.0),
               front_top=None, jag_right=True, back_door=(-3, 3), roof_holes=(), fallen=None, floor_swatch="stone",
               roof_swatch="stone"):
    """The shell most Main Street shops share: a floor, a front wall with a door and two empty
    windows, a kick plate and chrome bands, a false front (front_top: its outline above h as
    [(x, z)...] from the left end to the right), side walls (the right one broken), a back wall
    with a back door, and a roof with holes; fallen=(x0, x1, y0, y1) leaves that part of the
    roof down on the floor."""
    floor(floor_swatch, w, d)
    holes = [(door[0], door[1], 0, 9.5)] + [(a, b, win_z[0], win_z[1]) for (a, b) in windows]
    wall_x(wall, -w / 2, w / 2, -d / 2, 0, h, holes=holes,
           jag=[(-w / 2, h), (w / 2 - 7, h - 3), (w / 2 - 3, h - 6)] if jag_right else None)
    bx("Decor", kick, (w + 0.3, 1.25, 1.3), (0, -d / 2, 0.65))
    bx("Decor", trim, (w + 0.4, 1.35, 0.35), (0, -d / 2, win_z[1] + 1.0))
    for (a, b) in windows:
        window_frame(a, b, -d / 2 - 0.1, win_z[0], win_z[1], swatch=trim)
    if front_top:
        facade(wall, [(-w / 2, h)] + list(front_top) + [(front_top[-1][0], h)], -d / 2 + 0.5, thick=1.0, part="FalseFront")
    wall_y(wall, -d / 2, d / 2, -w / 2, 0, h, holes=[(-6, 2, 3.5, 9)])
    wall_y(wall, -d / 2, d / 2, w / 2, 0, h, holes=[(-4, 4, 3.5, 9)],
           jag=[(-d / 2, h - 6), (-2, h - 4), (6, h)] if jag_right else None)
    wall_x(wall, -w / 2, w / 2, d / 2, 0, h, holes=[(back_door[0], back_door[1], 0, 8)] if back_door else ())
    if fallen:
        x0, x1, y0, y1 = fallen
        roof(roof_swatch, -w / 2, w / 2, y1, d / 2, h, holes=list(roof_holes), rim=trim)
        if x0 > -w / 2:
            roof(roof_swatch, -w / 2, x0, -d / 2, y1, h)
        for i in range(3):
            bx("Decor", roof_swatch, (min(8, x1 - x0), (y1 - y0) * 0.45, 0.5),
               (x0 + (x1 - x0) * (0.3 + i * 0.25), y0 + (y1 - y0) * (0.3 + 0.2 * i), 0.9 + i * 0.35),
               rot=(10 - i * 6, -8 + i * 7, 15 + i * 40))
    else:
        roof(roof_swatch, -w / 2, w / 2, -d / 2, d / 2, h, holes=list(roof_holes), rim=trim)
