"""lobbylib: pieces the Steadfast showroom and its fittings share (A9; bible Section 21; STYLE.md).

Built on generators/Town/townkit.py: every function takes the Kit and adds decoration at a spot.
Steadfast Shelter Co., 1958: teal enamel, cream, chrome, walnut, signal orange for what you press,
brass for what is precious. Googie shapes: boomerangs, starbursts, mushroom columns.
"""
from __future__ import annotations

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import townkit as T  # noqa: E402
from townkit import Kit  # noqa: E402,F401


def starburst(k: Kit, loc, r: float = 3.0, spikes: int = 12, core: str = "brass", spike: str = "chrome", ball: str = "hazard",
              neon: bool = True, flat: bool = False) -> None:
    """The atomic starburst: a core, long and short spikes, a bead on every long one.
    flat: spikes fan in the XZ plane only (a wall or sign ornament); else in every direction."""
    x, y, z = loc
    k.sphere(core, r * 0.2, loc, segs=8, rings=5)
    dirs = []
    if flat:
        for i in range(spikes):
            a = 2 * math.pi * i / spikes
            dirs.append((math.cos(a), 0.0, math.sin(a), i % 2 == 0))
    else:
        # a ring in each of three planes, offset, so it reads from any side
        for i in range(spikes):
            a = 2 * math.pi * i / spikes
            long_ = i % 2 == 0
            dirs.append((math.cos(a), 0.0, math.sin(a), long_))
            dirs.append((math.cos(a) * 0.7, 0.7 * (1 if i % 2 else -1), math.sin(a) * 0.7, not long_))
    for dx, dy, dz, long_ in dirs:
        ln = r * (1.0 if long_ else 0.62)
        tip = (x + dx * ln, y + dy * ln, z + dz * ln)
        k.pole(spike, r * 0.035, (x + dx * r * 0.15, y + dy * r * 0.15, z + dz * r * 0.15), tip, verts=4, r_top=r * 0.012)
        if long_:
            if neon:
                k.sphere(ball, r * 0.075, tip, segs=6, rings=4, mat="Neon", shadow=False)
            else:
                k.sphere(ball, r * 0.075, tip, segs=6, rings=4)


def sputnik_lamp(k: Kit, loc, drop: float = 4.0, r: float = 2.6, arms: int = 10, light: bool = True) -> None:
    """A ceiling lamp: a rod down from loc, a brass ball, arms out to glowing bulbs."""
    x, y, z = loc
    k.pole("brass", 0.12, (x, y, z), (x, y, z - drop), verts=6)
    c = (x, y, z - drop)
    k.sphere("brass", r * 0.2, c, segs=8, rings=5)
    for i in range(arms):
        a = 2 * math.pi * i / arms
        el = (-0.55, 0.05, -0.25, 0.35, -0.75)[i % 5]
        d = (math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el))
        tip = (c[0] + d[0] * r, c[1] + d[1] * r, c[2] + d[2] * r)
        k.pole("brass", 0.06, c, tip, verts=4)
        k.sphere("cream", r * 0.14, tip, segs=6, rings=4, mat="Neon", shadow=False)
    if light:
        k.light((x, y, z - drop - 0.5), colour="cream", brightness=1.3, range_=46)


def mushroom_column(k: Kit, x: float, y: float, z0: float, z1: float, r: float = 1.25, body: str = "teal", trim: str = "chrome") -> None:
    """A round column that flares into the ceiling, with chrome bands and a walnut-and-chrome foot."""
    h = z1 - z0
    k.lathe("gunmetal", [(r * 1.5, 0), (r * 1.5, 0.5), (r * 1.15, 0.9)], (x, y, z0), verts=12)
    k.lathe(body, [(r, 0.9), (r, h * 0.62), (r * 1.25, h * 0.8), (r * 2.1, h * 0.93), (r * 3.4, h)], (x, y, z0), verts=12)
    for zz in (1.3, h * 0.62):
        k.cyl(trim, r * 1.06, 0.3, (x, y, z0 + zz), verts=12)
    k.collider((r * 2.2, r * 2.2, h), (x, y, z0 + h / 2), name="Column")


def planter(k: Kit, x: float, y: float, z: float = 0.0, r: float = 2.2, h: float = 2.2, body: str = "porcelain", plant: str = "leaf",
            seed: int = 1, tall: bool = False, legs: bool = True) -> None:
    """A cone planter on brass legs with a shrub (or a tall rubber plant)."""
    base = 0.8 if legs else 0.0
    if legs:
        for i in range(3):
            a = 2 * math.pi * i / 3 + 0.4
            k.pole("brass", 0.1, (x + math.cos(a) * r * 0.75, y + math.sin(a) * r * 0.75, z),
                   (x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.5, z + base + 0.3), verts=4)
    k.lathe(body, [(r * 0.55, base), (r, base + h), (r * 0.9, base + h), (r * 0.85, base + h - 0.25)], (x, y, z), verts=10)
    k.cyl("walnut", r * 0.86, 0.1, (x, y, z + base + h - 0.3), verts=10)
    top = z + base + h
    if tall:
        k.pole("walnut", 0.14, (x, y, top - 0.3), (x + 0.2, y, top + 5.5), verts=5)
        import random as _r
        rng = _r.Random(seed)
        for i in range(7):
            a = rng.uniform(0, 6.28)
            zz = top + 1.2 + i * 0.7
            ln = 1.7 - i * 0.08
            k.blob("forest" if i % 2 else plant, ln, (x + math.cos(a) * ln * 0.75, y + math.sin(a) * ln * 0.75, zz),
                   scale=(1.0, 0.55, 0.22), detail=1, seed=seed + i)
    else:
        k.blob(plant, r * 0.95, (x, y, top + r * 0.45), scale=(1, 1, 0.75), detail=1, jitter=0.12, seed=seed)
        k.blob("forest", r * 0.6, (x + r * 0.35, y - r * 0.25, top + r * 0.75), scale=(1, 1, 0.8), detail=1, jitter=0.1, seed=seed + 5)


def stanchion(k: Kit, x: float, y: float, z: float = 0.0, h: float = 3.4) -> tuple:
    """A brass post for a velvet rope; returns its top (for the rope)."""
    k.cyl("brass", 0.55, 0.2, (x, y, z + 0.1), verts=10)
    k.pole("brass", 0.12, (x, y, z + 0.2), (x, y, z + h), verts=6)
    k.sphere("brass", 0.26, (x, y, z + h + 0.15), segs=6, rings=4)
    return (x, y, z + h - 0.2)


def rope(k: Kit, a, b, swatch: str = "rust", sag: float = 0.7) -> None:
    k.wire(swatch, [a, b], r=0.11, verts=5, sag=sag, steps=5)


def rope_ring(k: Kit, cx: float, cy: float, z: float, r: float, n: int = 6, gap: int | None = None) -> None:
    """Stanchions in a ring with ropes between (gap: leave that stretch open)."""
    tops = []
    for i in range(n):
        a = 2 * math.pi * i / n + math.pi / n
        tops.append(stanchion(k, cx + math.cos(a) * r, cy + math.sin(a) * r, z))
    for i in range(n):
        if gap is not None and i == gap:
            continue
        rope(k, tops[i], tops[(i + 1) % n])


def crate(k: Kit, x: float, y: float, z: float = 0.0, s: float = 2.8, yaw: float = 0.0, wood: str = "pine", band: str = "walnut",
          label: str = "teal") -> None:
    """A Steadfast supply crate (the bunker's, new)."""
    with k.at((x, y, z), yaw):
        k.box(wood, (s, s, s), (0, 0, s / 2))
        e = 0.14
        for sx in (-1, 1):
            for sy in (-1, 1):
                k.box(band, (e * 2, e * 2, s + 0.1), (sx * (s / 2 - e + 0.05), sy * (s / 2 - e + 0.05), s / 2))
        for zz in (e, s - e):
            k.box(band, (s + 0.1, s + 0.1, e * 2), (0, 0, zz))
        k.box(label, (s * 0.5, 0.06, s * 0.3), (0, -s / 2 - 0.03, s * 0.55))
        k.box("cream", (s * 0.36, 0.08, s * 0.08), (0, -s / 2 - 0.05, s * 0.55))


def poster(k: Kit, f: "T.Face", u: float, z: float, w: float = 6.0, h: float = 8.0, bg: str = "teal", band: str = "cream",
           accent: str = "signal", title: str | None = None, sub: str | None = None, font: str = "Oswald-Bold", motif: str = "bunker") -> None:
    """A framed Steadfast advertisement on a wall face (centre u, z)."""
    f.on("walnut", u - w / 2 - 0.25, u + w / 2 + 0.25, z - h / 2 - 0.25, z + h / 2 + 0.25, 0.2)
    f.on(bg, u - w / 2, u + w / 2, z - h / 2, z + h / 2, 0.28)
    f.on(band, u - w / 2, u + w / 2, z - h / 2, z - h / 2 + h * 0.26, 0.32)
    if motif == "bunker":      # a hill, a door in it, a sun
        f.outline("forest", [(u - w / 2, z - h * 0.24), (u - w * 0.1, z + h * 0.12), (u + w / 2, z - h * 0.24)], 0.3, 0.36)
        f.cyl("gunmetal", w * 0.11, 0.1, (u - w * 0.08, 0.38, z - h * 0.13), verts=10)
        f.cyl("chrome", w * 0.07, 0.1, (u - w * 0.08, 0.42, z - h * 0.13), verts=10)
        f.cyl("hazard", w * 0.1, 0.08, (u + w * 0.26, 0.34, z + h * 0.28), verts=12)
    elif motif == "family":    # three figures under a roof line
        for i, (dx, hh) in enumerate(((-0.2, 0.3), (0.0, 0.36), (0.2, 0.22))):
            f.on("cream", u + dx * w - w * 0.05, u + dx * w + w * 0.05, z - h * 0.24, z - h * 0.24 + hh * h, 0.36)
            f.cyl("cream", w * 0.06, 0.08, (u + dx * w, 0.37, z - h * 0.24 + hh * h + w * 0.07), verts=8)
        f.outline(accent, [(u - w * 0.42, z + h * 0.2), (u, z + h * 0.4), (u + w * 0.42, z + h * 0.2), (u + w * 0.42, z + h * 0.16),
                           (u, z + h * 0.36), (u - w * 0.42, z + h * 0.16)], 0.3, 0.38)
    elif motif == "atom":
        f.cyl(accent, w * 0.09, 0.1, (u, 0.36, z + h * 0.12), verts=10)
        for a in (0, 60, 120):
            f.box("cream", (w * 0.62, 0.06, w * 0.035), (u, 0.36, z + h * 0.12), roll=a)
    if title:
        f.text("navy" if band in ("cream", "porcelain") else "cream", title, u, z - h / 2 + h * 0.17, h * 0.1, n=0.34, depth=0.08,
               font=font, max_w=w * 0.9, flat=True)
    if sub:
        f.text(accent, sub, u, z - h / 2 + h * 0.06, h * 0.05, n=0.34, depth=0.08, flat=True, max_w=w * 0.9)


def banner(k: Kit, x: float, y: float, z_top: float, w: float = 5.0, h: float = 12.0, yaw: float = 0.0, body: str = "teal",
           stripe: str = "cream", emblem: str = "brass") -> None:
    """A cloth banner hanging from a brass rod: Steadfast colours, a swallow-tail foot, the S ring."""
    with k.at((x, y, z_top), yaw):
        k.pole("brass", 0.12, (-w / 2 - 0.5, 0, 0), (w / 2 + 0.5, 0, 0), verts=6)
        for sx in (-1, 1):
            k.sphere("brass", 0.22, (sx * (w / 2 + 0.5), 0, 0), segs=6, rings=4)
        pts = [(-w / 2, 0), (w / 2, 0), (w / 2, -h), (0, -h + w * 0.45), (-w / 2, -h)]
        k.prism_y(body, [(px, pz - 0.15) for px, pz in pts], -0.06, 0.06)
        k.span(stripe, -w / 2, w / 2, -0.09, 0.09, -h * 0.2 - 0.15, -h * 0.14 - 0.15)
        k.span(stripe, -w / 2, w / 2, -0.09, 0.09, -h * 0.74, -h * 0.71)
        for sy in (-1, 1):
            k.cyl(emblem, w * 0.3, 0.06, (0, sy * 0.1, -h * 0.45), rot=(90, 0, 0), verts=14)
            k.cyl(body, w * 0.23, 0.06, (0, sy * 0.13, -h * 0.45), rot=(90, 0, 0), verts=14)
            k.text(stripe, "S", (0, sy * 0.17, -h * 0.45), w * 0.3, depth=0.04, yaw=0 if sy < 0 else 180, font="AlfaSlabOne-Regular")


def googie_chair(k: Kit, x: float, y: float, z: float = 0.0, yaw: float = 0.0, shell: str = "signal", legs: str = "chrome") -> None:
    """A moulded shell chair on hairpin legs."""
    with k.at((x, y, z), yaw):
        k.blob(shell, 1.25, (0, 0, 1.9), scale=(1.0, 0.95, 0.28), detail=2, faceted=False)
        k.blob(shell, 1.15, (0, 0.95, 3.0), scale=(1.0, 0.28, 0.85), detail=2, faceted=False)
        for sx in (-1, 1):
            for sy in (-1, 1):
                k.pole(legs, 0.07, (sx * 0.55, sy * 0.5, 1.7), (sx * 0.95, sy * 0.9, 0), verts=4)


def coffee_table(k: Kit, x: float, y: float, z: float = 0.0, r: float = 2.0) -> None:
    """A kidney-ish walnut table on brass legs with a magazine and an ashtray-free bowl of fruit."""
    k.blob("walnut", r, (x, y, z + 1.5), scale=(1.25, 0.8, 0.08), detail=2, faceted=False)
    for a in (0.5, 2.6, 4.4):
        k.pole("brass", 0.07, (x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.4, z + 1.45),
               (x + math.cos(a) * r * 0.85, y + math.sin(a) * r * 0.6, z), verts=4)
    k.box("cream", (1.1, 0.8, 0.06), (x - 0.6, y + 0.1, z + 1.7), rot=(0, 0, 20))
    k.box("signal", (1.1, 0.8, 0.05), (x - 0.5, y + 0.15, z + 1.76), rot=(0, 0, 8))
    k.lathe("mint", [(0.2, 0), (0.55, 0.3), (0.5, 0.3)], (x + 0.9, y - 0.1, z + 1.66), verts=8)


def wall_clock(k: Kit, f: "T.Face", u: float, z: float, r: float = 2.0) -> None:
    """A starburst wall clock."""
    for i in range(12):
        a = 2 * math.pi * i / 12
        ln = r * (1.9 if i % 2 == 0 else 1.45)
        c = f.p(u, 0.25, z)
        tip = f.p(u + math.cos(a) * ln, 0.25, z + math.sin(a) * ln)
        k.pole("brass", 0.07, c, tip, verts=4, r_top=0.03)
        if i % 2 == 0:
            k.sphere("walnut", 0.2, tip, segs=6, rings=4)
    f.cyl("walnut", r, 0.3, (u, 0.25, z), verts=16)
    f.cyl("cream", r * 0.86, 0.3, (u, 0.3, z), verts=16)
    f.box("navy", (0.14, 0.1, r * 0.62), (u, 0.5, z + r * 0.28))
    f.box("navy", (0.14, 0.1, r * 0.45), (u + r * 0.18, 0.5, z - r * 0.08), roll=-60)
    f.cyl("signal", 0.16, 0.12, (u, 0.55, z), verts=8)


def ceiling_light(k: Kit, x: float, y: float, z: float, r: float = 1.5, light: bool = False) -> None:
    """A round recessed light: a chrome ring and a glowing lens just under the ceiling."""
    k.cyl("chrome", r * 1.12, 0.22, (x, y, z - 0.11), verts=12)
    k.cyl("cream", r, 0.12, (x, y, z - 0.25), verts=12, mat="Neon", shadow=False)
    if light:
        k.light((x, y, z - 1.2), colour="cream", brightness=1.0, range_=36)


def hazard_stripes(k: Kit, x0: float, x1: float, y0: float, y1: float, z: float, n: int | None = None, a: str = "hazard", b: str = "rubber") -> None:
    """A band of diagonal warning stripes on the floor (a thin slab from x0..x1, y0..y1)."""
    w = x1 - x0
    d = y1 - y0
    k.span(a, x0, x1, y0, y1, z, z + 0.05)
    n = n or max(2, int(w / (d * 1.4)))
    step = w / n
    for i in range(n):
        xa = x0 + i * step
        pts = [(xa, y0), (xa + step * 0.5, y0), (xa + step * 0.5 + d * 0.6, y1), (xa + d * 0.6, y1)]
        pts = [(min(max(px, x0), x1), py) for px, py in pts]
        k.prism_z(b, pts, z + 0.05, z + 0.08)
