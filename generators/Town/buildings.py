"""buildings: Brightwater's Main Street, piece by piece (A9 and the town rebuild; bible Sections 12
and 21; STYLE.md). Built on townkit.

Every building is drawn in its own frame: x across (0 at its centre), its street front on y = 0,
its body running back to y = +d, z up. A block places several side by side with Kit.at.

commercial() is the two-part commercial block every American Main Street is made of: a shopfront
(bulkhead, plate glass over a real display window 2.4 studs deep, a recessed door, transom, the
sign band, an awning) under one or two floors of sash windows, belt courses, pilasters, a cornice
and a parapet, with the clutter roofs collect. Its parameters are data (BRIGHTWATER below), so a
street is a list.
"""
from __future__ import annotations

import math
import random

import townkit as T
from lobbylib_shim import starburst
from townkit import Face, Kit

GH = 13.0            # ground floor: floor to the top of the sign band
UH = 10.5            # an upper floor
RECESS = 2.4         # the display window's depth
BULK = 1.5           # bulkhead (kick plate) height
GLASS_TOP = 8.9      # top of the plate glass
TRANSOM_TOP = 10.3   # top of the transom lights; the sign band runs from here to GH


# ---------------------------------------------------------------------------------------------
# Window displays: what a shop sells, seen through its glass
# ---------------------------------------------------------------------------------------------

def _stand(k: Kit, x, y, z, w=1.6, h=0.9, sw="walnut"):
    k.box(sw, (w, 1.0, h), (x, y, z + h / 2))
    return z + h


def display(k: Kit, kind: str, x0: float, x1: float, y0: float, y1: float, z: float, top: float, rng: random.Random) -> None:
    """Fill a display window (floor at z, back at y1) with a few readable things."""
    w = x1 - x0
    cy = (y0 + y1) / 2
    n = max(2, int(w / 3.2))
    xs = [x0 + w * (i + 0.5) / n for i in range(n)]
    if kind == "hardware":
        for i, x in enumerate(xs):
            pick = (i + rng.randint(0, 2)) % 4
            if pick == 0:       # paint tins in a pyramid
                for j, (dx, dz) in enumerate(((-0.5, 0), (0.5, 0), (0, 0.9))):
                    k.cyl(("signal", "teal", "hazard")[j], 0.45, 0.9, (x + dx, cy, z + 0.45 + dz), verts=7)
                    k.cyl("steel", 0.47, 0.1, (x + dx, cy, z + 0.9 + dz), verts=7)
            elif pick == 1:     # a step ladder
                for sx in (-0.5, 0.5):
                    k.pole("pine", 0.09, (x + sx, cy - 0.5, z), (x + sx * 0.6, cy + 0.2, z + 4.6), verts=4)
                    k.pole("pine", 0.09, (x + sx, cy + 0.9, z), (x + sx * 0.6, cy + 0.2, z + 4.6), verts=4)
                for r in range(4):
                    k.box("pine", (1.0 - r * 0.08, 0.5, 0.1), (x, cy - 0.38 + r * 0.14, z + 0.9 + r * 0.95))
            elif pick == 2:     # a tool board
                k.box("pine", (2.4, 0.15, 3.4), (x, y1 - 0.2, z + 2.6))
                for j, sw in enumerate(("steel", "rust", "chrome", "signal")):
                    k.box(sw, (0.18, 0.1, 1.6 - j * 0.25), (x - 0.8 + j * 0.55, y1 - 0.32, z + 2.9), rot=(0, 12 - j * 8, 0))
            else:               # a lawn mower-ish machine: a deck, wheels, a handle
                k.box("signal", (1.6, 1.1, 0.5), (x, cy, z + 0.55))
                for sx in (-0.7, 0.7):
                    k.cyl("rubber", 0.38, 0.2, (x + sx, cy - 0.6, z + 0.38), rot=(90, 0, 0), verts=8)
                k.pole("chrome", 0.06, (x, cy + 0.5, z + 0.8), (x, cy + 1.4, z + 2.9), verts=4)
    elif kind == "bakery":
        for i, x in enumerate(xs):
            t = _stand(k, x, cy, z, 1.8, 0.7, "porcelain")
            if i % 2 == 0:      # a tiered cake
                for j, (r, sw) in enumerate(((0.8, "cream"), (0.58, "blush"), (0.38, "cream"))):
                    k.cyl(sw, r, 0.5, (x, cy, t + 0.25 + j * 0.5), verts=10)
                k.bulb("signal", 0.14, (x, cy, t + 1.62))
            else:               # loaves and a pie
                for j in range(3):
                    k.blob("pine", 0.42, (x - 0.5 + j * 0.5, cy, t + 0.3), scale=(0.9, 1.5, 0.75), detail=1, faceted=False)
                k.cyl("leather", 0.5, 0.18, (x, cy - 0.9, z + 0.09), verts=9)
    elif kind == "tv":
        for i, x in enumerate(xs):
            t = _stand(k, x, cy, z, 2.0, 0.5 + (i % 2) * 0.9, "walnut")
            k.box("walnut", (2.1, 1.3, 1.7), (x, cy, t + 0.85))
            k.box("mint", (1.3, 0.1, 1.05), (x - 0.25, cy - 0.66, t + 0.95), mat="Neon", shadow=False)
            for j in range(2):
                k.cyl("brass", 0.12, 0.1, (x + 0.75, cy - 0.68, t + 0.6 + j * 0.5), rot=(90, 0, 0), verts=6)
            k.pole("chrome", 0.03, (x, cy, t + 1.7), (x - 0.5, cy, t + 2.6), verts=3)
            k.pole("chrome", 0.03, (x, cy, t + 1.7), (x + 0.5, cy, t + 2.6), verts=3)
    elif kind == "dress":
        for i, x in enumerate(xs):
            sw = ("blush", "teal", "hazard", "skyblue", "signal")[(i + rng.randint(0, 4)) % 5]
            k.cyl("gunmetal", 0.5, 0.1, (x, cy, z + 0.05), verts=8)
            k.pole("chrome", 0.05, (x, cy, z), (x, cy, z + 1.2), verts=4)
            k.lathe(sw, [(1.15, 1.0), (0.42, 3.1), (0.5, 3.3), (0.62, 4.3), (0.3, 4.6)], (x, cy, z), verts=9)
            k.lathe("porcelain", [(0.16, 4.6), (0.16, 4.9), (0.3, 5.1), (0.3, 5.45), (0.0, 5.6)], (x, cy, z), verts=7)
            if i % 2 == 0:
                k.cyl(sw, 0.62, 0.08, (x, cy, z + 5.5), verts=9)
    elif kind == "drugs":
        for i, x in enumerate(xs):
            t = _stand(k, x, cy, z, 1.9, 1.2, "porcelain")
            for j in range(4):
                sw = ("teal", "rust", "hazard", "skyblue")[(i + j) % 4]
                h = 0.7 + (j % 2) * 0.3
                k.cyl(sw, 0.2, h, (x - 0.6 + j * 0.4, cy - 0.1, t + h / 2), verts=6)
                k.cyl("cream", 0.12, 0.16, (x - 0.6 + j * 0.4, cy - 0.1, t + h + 0.08), verts=5)
            if i % 2 == 1:
                k.box("cream", (1.5, 0.1, 1.5), (x, y1 - 0.25, z + 4.5))
                k.box("rust", (1.0, 0.12, 0.28), (x, y1 - 0.3, z + 4.5))
                k.box("rust", (0.28, 0.12, 1.0), (x, y1 - 0.3, z + 4.5))
    elif kind == "toys":
        for i, x in enumerate(xs):
            pick = (i + rng.randint(0, 3)) % 4
            if pick == 0:       # a ball and blocks
                k.sphere("signal", 0.7, (x, cy, z + 0.7), segs=8, rings=5)
                k.box("teal", (0.6, 0.6, 0.6), (x + 1.0, cy + 0.2, z + 0.3), rot=(0, 0, 20))
                k.box("hazard", (0.6, 0.6, 0.6), (x + 1.05, cy + 0.2, z + 0.9), rot=(0, 0, -15))
            elif pick == 1:     # a rocket
                k.lathe("porcelain", [(0.0, 0.5), (0.4, 0.8), (0.42, 2.6), (0.0, 3.6)], (x, cy, z), verts=8)
                for a in range(3):
                    ang = a * 2.094
                    k.box("signal", (0.08, 0.7, 0.9), (x + math.cos(ang) * 0.5, cy + math.sin(ang) * 0.5, z + 0.75), rot=(0, 0, math.degrees(ang) + 90))
            elif pick == 2:     # a wagon
                k.box("rust", (1.8, 0.9, 0.4), (x, cy, z + 0.6))
                for sx in (-0.6, 0.6):
                    k.cyl("rubber", 0.3, 1.1, (x + sx, cy, z + 0.3), rot=(90, 0, 0), verts=7)
            else:               # a teddy-ish robot
                k.box("steel", (0.9, 0.7, 1.1), (x, cy, z + 0.95))
                k.box("steel", (0.6, 0.55, 0.55), (x, cy, z + 1.8))
                k.bulb("signal", 0.1, (x - 0.14, cy - 0.3, z + 1.85))
                k.bulb("signal", 0.1, (x + 0.14, cy - 0.3, z + 1.85))
    elif kind == "news":
        for i, x in enumerate(xs):
            for j in range(3 + (i % 2) * 2):
                k.box("cream" if j % 2 else "porcelain", (1.5, 1.1, 0.16), (x + (j % 2) * 0.06, cy, z + 0.08 + j * 0.16), rot=(0, 0, (j * 37) % 9 - 4))
            k.box("cream", (2.0, 0.1, 2.6), (x, y1 - 0.25, z + 4.0))
            k.box("navy", (1.7, 0.12, 0.45), (x, y1 - 0.3, z + 4.9))
            for r in range(4):
                k.box("ash", (1.6, 0.12, 0.1), (x, y1 - 0.3, z + 4.3 - r * 0.34))
    elif kind == "records":
        for i, x in enumerate(xs):
            if i % 2 == 0:      # a jukebox
                k.box("walnut", (1.7, 1.1, 2.6), (x, cy, z + 1.3))
                k.cyl("hazard", 0.85, 1.12, (x, cy, z + 2.6), rot=(90, 0, 0), verts=12, mat="Neon", shadow=False)
                k.cyl("walnut", 0.6, 1.16, (x, cy, z + 2.6), rot=(90, 0, 0), verts=12)
                k.box("signal", (1.2, 0.08, 0.5), (x, cy - 0.57, z + 1.2), mat="Neon", shadow=False)
            else:               # records on a rack
                for j in range(4):
                    k.cyl("rubber", 0.62, 0.05, (x - 0.9 + j * 0.6, y1 - 0.4, z + 3.4 + (j % 2) * 1.5), rot=(90, 0, 0), verts=12)
                    k.cyl(("signal", "teal", "hazard", "blush")[j], 0.2, 0.07, (x - 0.9 + j * 0.6, y1 - 0.42, z + 3.4 + (j % 2) * 1.5), rot=(90, 0, 0), verts=8)
    elif kind == "grocery":
        for i, x in enumerate(xs):
            k.box("pine", (2.2, 1.4, 0.9), (x, cy, z + 0.45), rot=(-14, 0, 0))
            sw = ("signal", "leaf", "hazard", "rust", "avocado")[(i + rng.randint(0, 4)) % 5]
            for a in range(3):
                for b in range(2):
                    k.blob(sw, 0.34, (x - 0.65 + a * 0.65, cy - 0.3 + b * 0.6, z + 1.05 + b * 0.16), detail=0, faceted=False)
    elif kind == "barber":
        for i, x in enumerate(xs):
            if i % 2 == 0:      # a chair
                k.cyl("chrome", 0.7, 0.2, (x, cy + 0.3, z + 0.1), verts=9)
                k.pole("chrome", 0.14, (x, cy + 0.3, z), (x, cy + 0.3, z + 1.5), verts=6)
                k.box("rust", (1.5, 1.4, 0.4), (x, cy + 0.3, z + 1.7))
                k.box("rust", (1.5, 0.35, 1.8), (x, cy + 0.95, z + 2.7))
                k.box("chrome", (0.2, 1.3, 0.2), (x - 0.8, cy + 0.3, z + 2.3))
                k.box("chrome", (0.2, 1.3, 0.2), (x + 0.8, cy + 0.3, z + 2.3))
            else:               # bottles on a shelf
                k.box("walnut", (2.0, 0.6, 0.12), (x, y1 - 0.5, z + 3.2))
                for j in range(4):
                    k.cyl(("teal", "hazard", "blush", "skyblue")[j], 0.16, 0.7, (x - 0.7 + j * 0.45, y1 - 0.5, z + 3.6), verts=5)
    elif kind == "bank":
        return
    else:                       # general goods: boxes on steps
        for i, x in enumerate(xs):
            t = _stand(k, x, cy, z, 2.0, 0.6 + (i % 3) * 0.5, "cream")
            for j in range(3):
                sw = ("teal", "signal", "hazard", "rust", "skyblue", "blush")[(i * 3 + j + rng.randint(0, 5)) % 6]
                s = 0.5 + ((i + j) % 3) * 0.12
                k.box(sw, (s, s, s * 1.3), (x - 0.6 + j * 0.6, cy, t + s * 0.65), rot=(0, 0, (i * 23 + j * 31) % 30 - 15))


# ---------------------------------------------------------------------------------------------
# Pieces of a front
# ---------------------------------------------------------------------------------------------

def sash_window(k: Kit, f: Face, u: float, z: float, w: float = 3.4, h: float = 5.6, frame: str = "porcelain", sill: str = "sandstone",
                lintel: str | None = "sandstone", shade: str | None = None, lit: bool = False, box: bool = False, arched: bool = False,
                rng: random.Random | None = None, shutters: str | None = None) -> None:
    """A double-hung window on a wall face: centre u, sill at z. Dark glass over a blind or curtains."""
    u0, u1 = u - w / 2, u + w / 2
    f.on("navy", u0, u1, z, z + h, 0.05)
    blind = shade or "cream"
    drop = (rng.choice((0.25, 0.4, 0.55, 0.0)) if rng else 0.3) * h
    if drop > 0:
        f.on(blind, u0 + 0.15, u1 - 0.15, z + h - drop, z + h - 0.1, 0.09, n0=0.04)
    else:           # curtains at the sides
        for a, b in ((u0 + 0.12, u0 + w * 0.26), (u1 - w * 0.26, u1 - 0.12)):
            f.on(blind, a, b, z + 0.1, z + h - 0.1, 0.09, n0=0.04)
    if lit:
        f.on("hazard", u0 + 0.2, u1 - 0.2, z + 0.2, z + h * 0.45, 0.07, n0=0.05, mat="Neon", shadow=False)
    f.glass(u0, u1, z, z + h, n=0.16, thick=0.08, transparency=0.4)
    fr = 0.28
    for a, b, c, d in ((u0 - fr, u0, z, z + h), (u1, u1 + fr, z, z + h), (u0 - fr, u1 + fr, z + h, z + h + fr),
                       (u0, u1, z + h / 2 - 0.1, z + h / 2 + 0.1), (u - 0.07, u + 0.07, z + h / 2, z + h)):
        f.on(frame, a, b, c, d, 0.3, n0=0.02)
    f.on(sill, u0 - 0.5, u1 + 0.5, z - 0.4, z, 0.55, n0=0.0)
    if lintel:
        if arched:
            pts = [(u0 - 0.5, z + h + fr), (u0 - 0.5, z + h + 0.9), (u - w * 0.25, z + h + 1.45), (u + w * 0.25, z + h + 1.45), (u1 + 0.5, z + h + 0.9),
                   (u1 + 0.5, z + h + fr)]
            f.outline(lintel, pts, 0.0, 0.42)
            f.on(lintel, u - 0.35, u + 0.35, z + h + fr, z + h + 1.75, 0.55, n0=0.0)       # keystone
        else:
            f.on(lintel, u0 - 0.6, u1 + 0.6, z + h + fr, z + h + fr + 0.75, 0.42, n0=0.0)
    if shutters:
        for a, b in ((u0 - fr - 1.25, u0 - fr - 0.08), (u1 + fr + 0.08, u1 + fr + 1.25)):
            f.on(shutters, a, b, z, z + h, 0.2, n0=0.0)
            for i in range(4):
                f.on("navy", a + 0.15, b - 0.15, z + 0.5 + i * (h - 0.6) / 4, z + 0.62 + i * (h - 0.6) / 4, 0.24, n0=0.18)
    if box:         # a flower box
        f.on("walnut", u0 - 0.2, u1 + 0.2, z - 1.1, z - 0.4, 1.0, n0=0.4)
        for i in range(4):
            k.blob(("signal", "blush", "hazard", "leaf")[i % 4], 0.36, f.p(u0 + 0.4 + i * (w - 0.8) / 3, 0.75, z - 0.2), detail=0, seed=i)
        k.blob("leaf", 0.5, f.p(u, 0.7, z - 0.35), scale=(w * 0.9, 0.7, 0.5), detail=0, seed=9)


def awning(k: Kit, f: Face, u0: float, u1: float, z: float, out: float = 4.6, drop: float = 1.9, stripes=("signal", "porcelain"),
           valance: float = 0.75, poles: bool = False) -> None:
    """A canvas awning: striped, sloping out and down from z, a scalloped valance along its lip."""
    w = u1 - u0
    n = max(4, round(w / 2.2))
    step = w / n
    zl = z - drop
    for i in range(n):
        a, b = u0 + i * step, u0 + (i + 1) * step
        sw = stripes[i % len(stripes)]
        f.prism(sw, [(0.0, z), (out, zl), (out, zl - 0.12), (0.0, z - 0.14)], a, b, caps=(i == 0, i == n - 1))
        # the valance: a flap with a pointed foot
        f.outline(sw, [(a, zl), (b, zl), (b, zl - valance * 0.6), ((a + b) / 2, zl - valance), (a, zl - valance * 0.6)], out - 0.06, out, shadow=False)
    f.box("gunmetal", (w + 0.2, 0.14, 0.14), ((u0 + u1) / 2, out - 0.04, zl))
    for u in (u0 + 0.2, u1 - 0.2):
        k.pole("gunmetal", 0.07, f.p(u, 0.0, z - drop - 1.6), f.p(u, out - 0.1, zl), verts=4)
        if poles:
            k.pole("gunmetal", 0.09, f.p(u, out - 0.2, 0.0), f.p(u, out - 0.2, zl), verts=5)


def flat_canopy(k: Kit, f: Face, u0: float, u1: float, z: float, out: float = 5.0, body: str = "porcelain", edge: str = "teal",
                rods: bool = True, bulbs: bool = False) -> None:
    """A flat metal canopy on tie rods, with a coloured edge."""
    f.box(body, (u1 - u0, out, 0.5), ((u0 + u1) / 2, out / 2, z + 0.25))
    f.box(edge, (u1 - u0 + 0.3, 0.3, 0.9), ((u0 + u1) / 2, out + 0.05, z + 0.3))
    for u in (u0 - 0.15, u1 + 0.15):
        f.box(edge, (0.3, out + 0.2, 0.9), (u, out / 2, z + 0.3))
    if rods:
        for u in (u0 + 1.0, u1 - 1.0):
            k.pole("chrome", 0.08, f.p(u, out - 0.6, z + 0.5), f.p(u, 0.1, z + 3.6), verts=4)
    if bulbs:
        n = max(3, int((u1 - u0) / 1.6))
        for i in range(n):
            k.bulb("cream", 0.2, f.p(u0 + (i + 0.5) * (u1 - u0) / n, out * 0.55, z - 0.12))


def cornice(k: Kit, f: Face, u0: float, u1: float, z: float, style: str = "bracket", swatch: str = "porcelain", out: float = 1.2,
            h: float = 1.6) -> float:
    """A cornice along the wall's top edge at z. Returns the height it adds."""
    if style == "simple":
        f.prism(swatch, [(0, z), (out * 0.5, z + h * 0.5), (out * 0.5, z + h), (0, z + h)], u0 - 0.3, u1 + 0.3)
        return h
    if style == "deco":       # stepped bands
        for i in range(3):
            f.on(swatch, u0 - 0.2, u1 + 0.2, z + i * h / 3, z + (i + 1) * h / 3, 0.25 + i * 0.28, n0=0.0)
        return h
    prof = [(0, z), (out * 0.35, z), (out * 0.55, z + h * 0.35), (out, z + h * 0.6), (out, z + h), (0, z + h)]
    f.prism(swatch, prof, u0 - 0.35, u1 + 0.35)
    if style == "bracket":
        n = max(2, round((u1 - u0) / 3.0))
        for i in range(n + 1):
            u = u0 + (u1 - u0) * i / n
            f.prism(swatch, [(0, z - 1.3), (0.25, z - 1.3), (out * 0.85, z + h * 0.45), (0, z + h * 0.45)], u - 0.22, u + 0.22)
    elif style == "dentil":
        n = max(4, round((u1 - u0) / 1.1))
        for i in range(n):
            u = u0 + (u1 - u0) * (i + 0.5) / n
            f.on(swatch, u - 0.2, u + 0.2, z - 0.5, z, 0.42, n0=0.0)
    return h


def blade_sign(k: Kit, f: Face, u: float, z: float, text: str, h: float = 9.0, w: float = 2.6, out: float = 0.9, body: str = "teal",
               ink: str = "cream", trim: str = "chrome", neon: str | None = None, font: str = "Oswald-Bold") -> None:
    """A vertical sign standing out from the wall, lettered down both sides."""
    c = out + w / 2 + 0.2
    f.box(body, (0.5, w, h), (u, c, z + h / 2))
    f.box(trim, (0.62, w + 0.25, 0.25), (u, c, z + h + 0.1))
    f.box(trim, (0.62, w + 0.25, 0.25), (u, c, z - 0.1))
    for zz in (z + h * 0.2, z + h * 0.8):
        k.pole("gunmetal", 0.08, f.p(u, 0.0, zz), f.p(u, out + 0.3, zz), verts=4)
    n = len(text)
    lh = min(w * 0.72, (h - 0.8) / n * 0.8)
    step = (h - 0.8) / n
    for side in (-1, 1):
        yaw = f.yaw + (90 if side > 0 else -90)
        for i, ch in enumerate(text):
            p = f.p(u + side * 0.26, c, z + h - 0.4 - (i + 0.5) * step)
            if neon:
                k.text(neon, ch, p, lh, depth=0.08, yaw=yaw, font=font, mat="Neon", shadow=False, flat=True)
            else:
                k.text(ink, ch, p, lh, depth=0.06, yaw=yaw, font=font, flat=True)


def water_tank(k: Kit, x: float, y: float, z: float, r: float = 3.0, h: float = 5.5) -> None:
    """A wooden roof tank on a steel frame, with its cone lid."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.pole("gunmetal", 0.18, (x + sx * r * 0.7, y + sy * r * 0.7, z), (x + sx * r * 0.6, y + sy * r * 0.6, z + 3.2), verts=4)
    for a, b in (((-1, -1), (1, 1)), ((-1, 1), (1, -1))):
        k.pole("gunmetal", 0.08, (x + a[0] * r * 0.7, y + a[1] * r * 0.7, z + 0.3), (x + b[0] * r * 0.6, y + b[1] * r * 0.6, z + 3.0), verts=3)
    k.cyl("gunmetal", r * 1.02, 0.3, (x, y, z + 3.3), verts=12)
    k.cyl("leather", r, h, (x, y, z + 3.4 + h / 2), verts=12)
    for zz in (0.8, h * 0.5, h - 0.8):
        k.cyl("gunmetal", r + 0.06, 0.16, (x, y, z + 3.4 + zz), verts=12)
    k.lathe("walnut", [(r * 1.08, 0), (0.0, r * 0.62)], (x, y, z + 3.4 + h), verts=12)


def roof_unit(k: Kit, x: float, y: float, z: float, s: float = 1.0) -> None:
    k.box("steel", (4.4 * s, 3.2 * s, 2.2 * s), (x, y, z + 1.1 * s + 0.3))
    k.box("gunmetal", (4.7 * s, 3.5 * s, 0.3), (x, y, z + 0.15))
    k.cyl("gunmetal", 1.1 * s, 0.25, (x, y, z + 2.2 * s + 0.4), verts=10)
    for i in range(4):
        k.box("gunmetal", (4.42 * s, 0.05, 0.14), (x, y - 1.62 * s, z + 0.7 + i * 0.42 * s))


def chimney(k: Kit, x: float, y: float, z: float, h: float = 4.0, sw: str = "rust") -> None:
    k.box(sw, (2.0, 2.0, h), (x, y, z + h / 2))
    k.box("sandstone", (2.4, 2.4, 0.35), (x, y, z + h + 0.17))
    k.box("basalt", (1.2, 1.2, 0.5), (x, y, z + h + 0.55))


def vent_pipe(k: Kit, x: float, y: float, z: float, h: float = 2.4) -> None:
    k.cyl("steel", 0.35, h, (x, y, z + h / 2), verts=6)
    k.cyl("steel", 0.65, 0.4, (x, y, z + h + 0.1), verts=6, r_top=0.15)


def antenna(k: Kit, x: float, y: float, z: float, h: float = 6.0) -> None:
    k.pole("steel", 0.07, (x, y, z), (x, y, z + h), verts=4)
    for i, zz in enumerate((h * 0.6, h * 0.75, h * 0.9)):
        w = 1.6 - i * 0.35
        k.pole("steel", 0.04, (x - w, y, z + zz), (x + w, y, z + zz), verts=3)


def drainpipe(k: Kit, f: Face, u: float, z0: float, z1: float, sw: str = "gunmetal") -> None:
    k.pole(sw, 0.22, f.p(u, 0.35, z0), f.p(u, 0.35, z1), verts=5)
    z = z0 + 3.0
    while z < z1:
        f.on(sw, u - 0.35, u + 0.35, z, z + 0.22, 0.5)
        z += 7.0
    f.on(sw, u - 0.5, u + 0.5, z1 - 0.1, z1 + 0.6, 0.75)


def fire_escape(k: Kit, f: Face, u0: float, u1: float, floors_z: list[float], out: float = 3.0, sw: str = "gunmetal") -> None:
    """Balconies at each upper floor with ladders between them."""
    for i, z in enumerate(floors_z):
        f.box(sw, (u1 - u0, out, 0.14), ((u0 + u1) / 2, out / 2 + 0.1, z))
        for u in (u0, u1):
            k.pole(sw, 0.06, f.p(u, out, z), f.p(u, out, z + 3.0), verts=3)
            k.pole(sw, 0.06, f.p(u, 0.1, z + 3.0), f.p(u, out, z + 3.0), verts=3)
        k.pole(sw, 0.06, f.p(u0, out, z + 3.0), f.p(u1, out, z + 3.0), verts=3)
        k.pole(sw, 0.05, f.p(u0, out, z + 1.5), f.p(u1, out, z + 1.5), verts=3)
        n = int((u1 - u0) / 0.9)
        for j in range(1, n):
            k.pole(sw, 0.035, f.p(u0 + j * (u1 - u0) / n, out, z), f.p(u0 + j * (u1 - u0) / n, out, z + 3.0), verts=3)
        for u in (u0 + 0.4, u1 - 0.4):
            k.pole(sw, 0.07, f.p(u, 0.1, z - 0.9), f.p(u, out * 0.8, z - 0.05), verts=3)
        # the ladder down (the lowest one stops short of the ground)
        lz0 = (floors_z[i - 1] if i > 0 else z - 6.0)
        lu = u0 + 1.0 + (i % 2) * (u1 - u0 - 2.6)
        for du in (0.0, 0.9):
            k.pole(sw, 0.05, f.p(lu + du, out * 0.75, lz0), f.p(lu + du, out * 0.75, z + 0.1), verts=3)
        r = lz0 + 0.5
        while r < z:
            k.pole(sw, 0.04, f.p(lu, out * 0.75, r), f.p(lu + 0.9, out * 0.75, r), verts=3)
            r += 0.9


def wall_ad(k: Kit, f: Face, u0: float, u1: float, z0: float, z1: float, lines, bg: str = "cream", border: str = "teal") -> None:
    """An advertisement painted on a side wall. lines: [(text, swatch, font, height share)]."""
    f.on(border, u0, u1, z0, z1, 0.18)
    f.on(bg, u0 + 0.5, u1 - 0.5, z0 + 0.5, z1 - 0.5, 0.24)
    total = sum(s for *_x, s in lines)
    z = z1 - 0.9
    hh = (z1 - z0 - 1.8)
    for text, sw, font, share in lines:
        lh = hh * share / total
        f.text(sw, text, (u0 + u1) / 2, z - lh / 2, lh * 0.74, n=0.26, depth=0.04, font=font, flat=True, max_w=(u1 - u0) - 2.2)
        z -= lh


# ---------------------------------------------------------------------------------------------
# The commercial block
# ---------------------------------------------------------------------------------------------

def commercial(k: Kit, w: float, d: float = 46.0, floors: int = 2, *, wall: str = "rust", trim: str = "porcelain", base: str = "teal",
               band: str | None = None, name: str = "SHOP", name_sw: str = "cream", font: str = "AlfaSlabOne-Regular", sub: str | None = None,
               shade=("signal", "porcelain"), cover: str = "awning", door: str = "centre", shop: str = "goods", top: str = "bracket",
               upper: str = "sash", roof=("tank",), blade: tuple | None = None, left_open: bool = False, right_open: bool = False,
               side_ad=None, escape: str | None = None, seed: int = 1, courses: str | None = "leather", stone_base: bool = False,
               lit: float = 0.0, parapet: str = "flat", date: str | None = None, frame: str = "chrome", back_detail: bool = True) -> dict:
    """One Main Street building: a shop under `floors - 1` floors of windows. Returns its size.

    wall/trim/base/band  swatches: the masonry, its stone and woodwork, the bulkhead's tile, the sign band.
    name, font, sub      the shop's name on the sign band (raised letters) and a smaller line.
    cover                "awning" (canvas, `shade` stripes), "canopy" (flat metal), or None.
    door                 "centre", "left", "right" or "double" (two shops' worth of glass).
    shop                 what its window shows (display()).
    top                  cornice style: bracket, dentil, simple, deco. parapet: flat, stepped, gable.
    roof                 clutter: any of tank, unit, chimney, vents, antenna, skylight, billboard.
    blade                (text, body swatch, ink swatch) for a vertical sign, or None.
    left_open/right_open that side wall is exposed (an alley or a corner): it gets windows and pipes.
    side_ad              wall_ad() lines for the exposed side.
    escape               "left" or "right": a fire escape on that exposed side.
    lit                  the share of upper windows with a lamp on.
    """
    rng = random.Random(seed * 7919 + int(w * 10))
    band = band or base
    upper_n = floors - 1
    body_h = GH + upper_n * UH
    par = 2.6
    H = body_h + par
    x0, x1 = -w / 2, w / 2
    # -- the body: upper floors over a ground floor set back behind the display window ----------
    if upper_n > 0:
        k.span(wall, x0, x1, 0.0, d, TRANSOM_TOP, body_h)
    else:
        k.span(wall, x0, x1, 0.0, d, TRANSOM_TOP, body_h)
    k.span(wall, x0, x1, RECESS, d, 0.0, TRANSOM_TOP)
    k.span("basalt", x0 + 0.8, x1 - 0.8, 0.8, d - 0.8, body_h - 0.2, body_h + 0.25)           # the roof's deck
    T.parapet(k, x0, x1, 0.0, d, body_h, H, wall)
    f = k.face((x0, 0.0, 0.0), 0)          # the street front: u = x - x0
    # -- piers either end of the shopfront --------------------------------------------------------
    pw = 1.7
    for (a, b) in ((0.0, pw), (w - pw, w)):
        k.span(wall, x0 + a, x0 + b, 0.0, RECESS, 0.0, TRANSOM_TOP)
        f.on(trim, a, b, 0.0, 0.9, 0.25)
        f.on(trim, a, b, TRANSOM_TOP - 0.7, TRANSOM_TOP, 0.25)
        if stone_base:
            T.ashlar(f, a, b, 0.9, TRANSOM_TOP - 0.7, row=1.2, seed=seed + int(a), min_w=0.8, max_w=1.7, proud=0.16)
    # -- the shopfront ------------------------------------------------------------------------------
    dw = 5.2                         # the door recess's width
    if door == "left":
        doors = [pw + dw / 2 + 0.6]
    elif door == "right":
        doors = [w - pw - dw / 2 - 0.6]
    elif door == "double":
        doors = [w * 0.27, w * 0.73]
    else:
        doors = [w / 2]
    edges = [pw] + [v for c in doors for v in (c - dw / 2, c + dw / 2)] + [w - pw]
    spans = [(edges[i], edges[i + 1]) for i in range(0, len(edges), 2) if edges[i + 1] - edges[i] > 1.2]
    for (a, b) in spans:                       # each display window
        f.on(base, a, b, 0.0, BULK, 0.22, n0=-RECESS)
        f.on(frame, a, b, BULK, BULK + 0.22, 0.3, n0=-0.2)
        for i in range(max(1, int((b - a) / 1.5))):          # tiles on the bulkhead
            if i % 2 == 0:
                ta = a + 0.2 + i * (b - a - 0.4) / max(1, int((b - a) / 1.5))
                f.on(trim, ta, ta + (b - a - 0.4) / max(1, int((b - a) / 1.5)) - 0.12, 0.35, BULK - 0.3, 0.26, n0=0.2, open_=("y+",))
        k.span("cream", x0 + a, x0 + b, 0.05, RECESS, BULK - 0.1, BULK)                       # the window's floor
        k.span("navy" if shop in ("tv", "records") else "cream", x0 + a, x0 + b, RECESS - 0.07, RECESS + 0.02, BULK, GLASS_TOP)   # its back
        k.span("porcelain", x0 + a + 0.3, x0 + b - 0.3, 0.5, 1.0, GLASS_TOP - 0.3, GLASS_TOP - 0.12, mat="Neon", shadow=False)      # its strip light
        f.glass(a, b, BULK + 0.22, GLASS_TOP, n=0.0, thick=0.14, transparency=0.74)
        n = max(1, round((b - a) / 5.5))
        for i in range(n + 1):
            u = a + (b - a) * i / n
            f.on(frame, u - 0.13, u + 0.13, BULK + 0.22, GLASS_TOP, 0.2, n0=-0.2)
        with k.at((0, 0, 0)):
            display(k, shop, x0 + a + 0.3, x0 + b - 0.3, 0.3, RECESS, BULK, GLASS_TOP, rng)
        k.collide_span(x0 + a, x0 + b, 0.0, RECESS, 0.0, GLASS_TOP)
    for c in doors:                            # each recessed door
        a, b = c - dw / 2, c + dw / 2
        k.span("cream", x0 + a, x0 + b, 0.0, RECESS, 0.0, 0.12)                                # the entry's floor
        for i in range(3):
            k.span(base if i % 2 == 0 else trim, x0 + a + 0.2 + i * (dw - 0.4) / 3, x0 + a + 0.2 + (i + 1) * (dw - 0.4) / 3, 0.15, RECESS - 0.1,
                   0.12, 0.15, open_=("z-",))
        for u in (a, b):                       # glass returns either side of the entry
            k.glass((0.14, RECESS, GLASS_TOP - BULK - 0.22), (x0 + u, RECESS / 2, (BULK + 0.22 + GLASS_TOP) / 2), transparency=0.74)
            k.span(base, x0 + u - 0.11, x0 + u + 0.11, 0.0, RECESS, 0.0, BULK)
            k.span(frame, x0 + u - 0.13, x0 + u + 0.13, -0.05, 0.2, BULK, GLASS_TOP)
        back = k.face((x0, RECESS, 0.0), 0)    # the door itself, at the back of the recess
        back.on(trim, a + 0.25, b - 0.25, 0.12, GLASS_TOP, 0.2)
        back.on("walnut" if shop != "bank" else "brass", c - 1.9, c + 1.9, 0.12, 8.0, 0.36)
        back.on("navy", c - 1.45, c + 1.45, 2.0, 7.4, 0.4)
        back.glass(c - 1.45, c + 1.45, 2.0, 7.4, n=0.46, thick=0.06, transparency=0.45)
        back.on("brass", c + 1.5, c + 1.72, 3.6, 4.9, 0.6, n0=0.4)
        back.on("cream", c - 0.9, c + 0.9, 5.4, 6.3, 0.48, n0=0.44)                             # an OPEN card
        back.text("rust", "OPEN", c, 5.85, 0.5, n=0.5, depth=0.02, flat=True, font="Oswald-Bold")
        k.collide_span(x0 + a, x0 + b, RECESS - 0.1, RECESS + 0.6, 0.0, GLASS_TOP, name="Door")
    # transom lights and the sign band
    f.on(frame, pw, w - pw, GLASS_TOP, GLASS_TOP + 0.22, 0.28, n0=-0.2)
    f.on("navy", pw, w - pw, GLASS_TOP + 0.22, TRANSOM_TOP, -0.3, n0=-0.6)
    f.glass(pw, w - pw, GLASS_TOP + 0.22, TRANSOM_TOP, n=-0.1, thick=0.1, swatch="mint", transparency=0.4)
    n = max(2, round((w - 2 * pw) / 2.0))
    for i in range(n + 1):
        u = pw + (w - 2 * pw) * i / n
        f.on(frame, u - 0.08, u + 0.08, GLASS_TOP + 0.22, TRANSOM_TOP, 0.12, n0=-0.15)
    k.span(wall, x0 + pw, x1 - pw, 0.0, RECESS, TRANSOM_TOP - 0.02, TRANSOM_TOP + 0.3)        # the soffit over the window
    f.on(band, 0.0, w, TRANSOM_TOP, GH, 0.45)
    f.on(trim, -0.15, w + 0.15, GH - 0.3, GH + 0.25, 0.75)
    f.on(trim, -0.1, w + 0.1, TRANSOM_TOP - 0.05, TRANSOM_TOP + 0.3, 0.62)
    name_h = 1.45 if sub else 1.7
    f.text(name_sw, name, w / 2, (TRANSOM_TOP + GH) / 2 + (0.32 if sub else 0.0), name_h, n=0.45, depth=0.22, font=font, max_w=w - 4.5)
    if sub:
        f.text(name_sw, sub, w / 2, TRANSOM_TOP + 0.72, 0.42, n=0.45, depth=0.04, flat=True, max_w=w - 5.0)
    # the cover over the pavement
    if cover == "awning":
        awning(k, f, pw - 0.6, w - pw + 0.6, TRANSOM_TOP + 0.05, stripes=shade)
    elif cover == "canopy":
        flat_canopy(k, f, pw - 0.6, w - pw + 0.6, TRANSOM_TOP - 0.55, edge=shade[0], bulbs=True)
    # -- the upper floors ---------------------------------------------------------------------------
    if courses:
        T.brick_bands(f, 0.0, w, GH + 0.4, body_h, swatch=courses, every=UH / 3.5)
    nwin = max(2, int((w - 4.0) / 6.4))
    for fl in range(upper_n):
        zs = GH + fl * UH
        f.on(trim, 0.0, w, zs + UH - 0.45, zs + UH, 0.4, n0=0.0)                              # belt course
        for i in range(nwin):
            u = 2.0 + (w - 4.0) * (i + 0.5) / nwin
            ww = min(3.6, (w - 4.0) / nwin - 2.0)
            if upper == "wide" and nwin >= 2:
                ww = (w - 4.0) / nwin - 1.4
            sash_window(k, f, u, zs + 3.0, w=ww, h=5.4, frame=trim, sill="sandstone", lintel=trim if upper != "plain" else None,
                        arched=upper == "arched", lit=rng.random() < lit, box=rng.random() < 0.18, rng=rng)
        for (a, b) in ((0.0, 1.2), (w - 1.2, w)):                                               # pilasters
            f.on(wall, a, b, zs, zs + UH - 0.45, 0.35, n0=0.0)
    # -- the top --------------------------------------------------------------------------------------
    ch = cornice(k, f, 0.0, w, body_h + 0.2, style=top, swatch=trim)
    f.on(trim, -0.2, w + 0.2, H - 0.05, H + 0.3, 0.3, n0=-1.0)                                 # coping
    if parapet == "stepped":
        f.on(wall, w * 0.28, w * 0.72, H, H + 2.2, 0.2, n0=-0.8)
        f.on(trim, w * 0.28 - 0.2, w * 0.72 + 0.2, H + 2.2, H + 2.55, 0.35, n0=-0.95)
        if date:
            f.on(trim, w / 2 - 2.6, w / 2 + 2.6, H + 0.35, H + 1.85, 0.3, n0=0.1)
            f.text("navy", date, w / 2, H + 1.1, 0.9, n=0.3, depth=0.03, flat=True)
    elif parapet == "gable":
        f.outline(wall, [(w * 0.2, H), (w * 0.8, H), (w / 2, H + 4.0)], -0.8, 0.2)
        f.outline(trim, [(w * 0.2 - 0.4, H), (w * 0.2, H), (w / 2, H + 4.0), (w * 0.8, H), (w * 0.8 + 0.4, H), (w / 2, H + 4.5)], -0.9, 0.4)
        if date:
            f.text(trim, date, w / 2, H + 1.4, 1.0, n=0.2, depth=0.04, flat=True)
    elif date:
        f.on(trim, w / 2 - 2.6, w / 2 + 2.6, body_h + ch + 0.25, H - 0.2, 0.25, n0=0.0)
        f.text("navy", date, w / 2, body_h + ch + 0.55, 0.42, n=0.25, depth=0.03, flat=True)
    # -- the roof's clutter -----------------------------------------------------------------------------
    rz = body_h + 0.25
    spots = [(x0 + w * 0.3, d * 0.62), (x0 + w * 0.7, d * 0.4), (x0 + w * 0.5, d * 0.8), (x0 + w * 0.25, d * 0.25), (x0 + w * 0.75, d * 0.75)]
    for i, item in enumerate(roof):
        x, y = spots[i % len(spots)]
        if item == "tank":
            water_tank(k, x, y, rz, r=min(3.0, w * 0.09))
        elif item == "unit":
            roof_unit(k, x, y, rz)
        elif item == "chimney":
            chimney(k, x1 - 2.2 if i % 2 else x0 + 2.2, y, rz, sw=wall)
        elif item == "vents":
            vent_pipe(k, x, y, rz)
            vent_pipe(k, x + 2.5, y + 3.0, rz, h=1.8)
        elif item == "antenna":
            antenna(k, x, y, rz)
        elif item == "skylight":
            k.box("gunmetal", (5.0, 7.0, 0.5), (x, y, rz + 0.25))
            k.prism_x("skyblue", [(y - 3.3, rz + 0.5), (y + 3.3, rz + 0.5), (y, rz + 2.0)], x - 2.3, x + 2.3, mat="Glass", transparency=0.4, shadow=False)
    # -- a blade sign ---------------------------------------------------------------------------------
    if blade:
        text, bsw, ink = blade
        blade_sign(k, f, w - 2.4 if doors[0] < w / 2 else 2.4, GH + 1.0, text, h=min(UH * upper_n + 1.5, 1.5 * len(text) + 1.5) if upper_n else 6.5,
                   body=bsw, ink=ink)
    # -- exposed sides and the back ---------------------------------------------------------------------
    sides = []
    if left_open:
        sides.append((k.face((x0, d, 0.0), 270), "left"))        # u runs from the back to the front
    if right_open:
        sides.append((k.face((x1, 0.0, 0.0), 90), "right"))      # u runs from the front to the back
    for sf_, which in sides:
        if courses:
            T.brick_bands(sf_, 0.0, d, 0.6, body_h, swatch=courses, every=UH / 3.5)
        sf_.on(trim, 0.0, d, 0.0, 0.9, 0.2)
        sf_.on(trim, 0.35, d - 0.35, H - 0.07, H + 0.27, 0.3, n0=-1.0)
        front_u = d - 2.0 if which == "left" else 2.0             # the end nearest the street
        T.quoins(sf_, d if which == "left" else 0.0, 0.9, body_h, swatch=trim, side=-1 if which == "left" else 1)
        drainpipe(k, sf_, d * 0.5, 0.2, body_h)
        ad_done = False
        if side_ad:
            a, b = (d * 0.52, d - 4.0) if which == "left" else (4.0, d * 0.48)
            if upper_n > 0:
                wall_ad(k, sf_, a, b, GH + 0.8, body_h - 0.8, side_ad)
            else:
                wall_ad(k, sf_, a, b, 3.2, body_h - 0.8, side_ad)
            ad_done = True
        for fl in range(upper_n):
            zs = GH + fl * UH
            for i in range(3):
                u = d * (0.14 + i * 0.13) if which == "left" else d * (0.6 + i * 0.13)
                if not ad_done or True:
                    sash_window(k, sf_, u, zs + 3.0, w=3.0, h=5.2, frame=trim, lintel=trim, lit=rng.random() < lit, rng=rng)
        # a side door and a meter at the back end
        du = d * 0.2 if which == "left" else d * 0.82
        sf_.on(trim, du - 2.1, du + 2.1, 0.0, 8.3, 0.2)
        sf_.on("teal" if base != "teal" else "walnut", du - 1.7, du + 1.7, 0.0, 7.9, 0.34)
        sf_.on("brass", du + 1.1, du + 1.3, 3.6, 4.4, 0.5)
        sf_.box("gunmetal", (0.5, 0.5, 0.4), (du, 0.5, 9.2))
        sf_.box("steel", (1.2, 0.5, 1.6), (du + 4.0, 0.3, 4.0))
        if escape == which and upper_n > 0:
            a, b = (d * 0.1, d * 0.42) if which == "left" else (d * 0.56, d * 0.9)
            fire_escape(k, sf_, a, b, [GH + fl * UH + 2.4 for fl in range(upper_n)])
        _ = front_u
    if back_detail:
        bf = k.face((x1, d, 0.0), 180)
        bf.on(trim, w * 0.4, w * 0.4 + 4.0, 0.0, 8.2, 0.2)
        bf.on("gunmetal", w * 0.4 + 0.4, w * 0.4 + 3.6, 0.0, 7.8, 0.3)
        drainpipe(k, bf, w * 0.85, 0.2, body_h)
        for fl in range(upper_n):
            for i in range(2):
                sash_window(k, bf, w * (0.2 + i * 0.5), GH + fl * UH + 3.0, w=3.0, h=5.0, frame=trim, lintel=None, rng=rng)
    # -- what players bump into: the body behind the shop window ----------------------------------------
    k.collide_span(x0, x1, RECESS, d, 0.0, H, name="Building")
    for (a, b) in ((0.0, pw), (w - pw, w)):
        k.collide_span(x0 + a, x0 + b, 0.0, RECESS, 0.0, GH)
    return {"w": w, "d": d, "h": H, "body": body_h}


def barber_pole(k: Kit, f: Face, u: float, z: float = 4.0, h: float = 4.2) -> None:
    """A barber's pole on a bracket: red, white and blue turns under a globe."""
    c = 1.1
    for i in range(7):
        sw = ("rust", "porcelain", "skyblue")[i % 3]
        k.cyl(sw, 0.5, h / 7 + 0.01, f.p(u, c, z + (i + 0.5) * h / 7), verts=8)
    for zz in (z - 0.2, z + h + 0.2):
        k.cyl("chrome", 0.62, 0.4, f.p(u, c, zz), verts=8)
        k.pole("chrome", 0.08, f.p(u, 0.0, zz), f.p(u, c, zz), verts=4)
    k.sphere("cream", 0.5, f.p(u, c, z + h + 0.85), segs=8, rings=5, mat="Neon", shadow=False)


# ---------------------------------------------------------------------------------------------
# The bank
# ---------------------------------------------------------------------------------------------

def bank(k: Kit, w: float = 44.0, d: float = 48.0, *, name: str = "BRIGHTWATER SAVINGS BANK", left_open: bool = True, right_open: bool = False,
         seed: int = 2) -> dict:
    """A small-town temple of thrift: a stone base, four columns, tall arched windows, a pediment, a street clock."""
    H = 30.0
    x0, x1 = -w / 2, w / 2
    k.span("sandstone", x0, x1, 1.6, d, 0.0, H)
    k.span("basalt", x0 + 0.8, x1 - 0.8, 2.4, d - 0.8, H - 0.2, H + 0.2)
    k.collide_span(x0, x1, 1.6, d, 0.0, H, name="Building")
    f = k.face((x0, 1.6, 0.0), 0)
    # the steps and the porch floor
    for i, (out, top) in enumerate(((4.2, 0.5), (3.2, 1.0), (2.2, 1.5))):
        k.span("ash", x0 + 3.0 - i * 0.0, x1 - 3.0, 1.6 - out, 1.6, 0.0, top)
    k.collide_span(x0 + 3.0, x1 - 3.0, -1.6, 1.6, 0.0, 1.0, name="Steps")
    k.collide_span(x0 + 3.0, x1 - 3.0, -0.6, 1.6, 1.0, 1.5, name="Steps")
    T.ashlar(f, 0.0, w, 0.0, 5.0, row=1.25, seed=seed, stones=("sandstone", "sandstone", "ash", "stone"), mortar="stone", proud=0.3)
    f.on("porcelain", 0.0, w, 5.0, 5.6, 0.55)
    # columns on pedestals, an entablature across them
    cols = [w * 0.14, w * 0.38, w * 0.62, w * 0.86]
    for u in cols:
        p = f.p(u, 1.5, 0.0)
        k.box("porcelain", (2.6, 2.6, 2.2), (p.x, p.y, 1.5 + 1.1))
        k.lathe("porcelain", [(1.15, 3.7), (1.2, 4.1), (0.98, 4.5), (0.9, 20.6), (1.0, 21.0), (1.3, 21.3), (1.3, 21.7)], (p.x, p.y, 0), verts=10)
        k.box("porcelain", (2.8, 2.8, 0.5), (p.x, p.y, 21.95))
    f.on("porcelain", -0.3, w + 0.3, 22.2, 25.4, 3.0, n0=0.0)                 # the frieze
    f.text("navy", name, w / 2, 23.8, 1.25, n=3.0, depth=0.1, font="Oswald-Bold", max_w=w - 6)
    f.prism("porcelain", [(0, 25.4), (3.5, 25.4), (3.9, 26.0), (3.9, 26.5), (0, 26.5)], -0.5, w + 0.5)
    f.outline("porcelain", [(-0.5, 26.5), (w + 0.5, 26.5), (w / 2, 33.0)], 0.2, 3.6)
    f.outline("sandstone", [(3.5, 27.2), (w - 3.5, 27.2), (w / 2, 31.4)], 3.6, 3.75)
    f.cyl("brass", 1.3, 0.2, (w / 2, 3.85, 28.6), axis="n", verts=14)
    f.text("navy", "1908", w / 2, 28.6, 0.8, n=3.96, depth=0.03, flat=True)
    # between the columns: the door in the middle, tall arched windows either side
    for i, u in enumerate((w * 0.26, w * 0.74)):
        f.on("navy", u - 2.3, u + 2.3, 7.0, 18.6, 0.1)
        f.glass(u - 2.3, u + 2.3, 7.0, 18.6, n=0.22, thick=0.1, transparency=0.4)
        f.outline("porcelain", [(u - 2.9, 18.6), (u - 2.9, 19.6), (u - 1.5, 20.8), (u + 1.5, 20.8), (u + 2.9, 19.6), (u + 2.9, 18.6)], 0.0, 0.5)
        for a, b, c, e in ((u - 2.9, u - 2.3, 7.0, 18.6), (u + 2.3, u + 2.9, 7.0, 18.6), (u - 2.9, u + 2.9, 6.4, 7.0), (u - 0.1, u + 0.1, 7.0, 18.6),
                           (u - 2.3, u + 2.3, 12.6, 12.85), (u - 2.3, u + 2.3, 15.6, 15.85)):
            f.on("porcelain", a, b, c, e, 0.42, n0=0.0)
    c = w / 2
    f.on("porcelain", c - 3.6, c + 3.6, 1.5, 13.2, 0.5, n0=0.0)
    f.on("brass", c - 2.9, c + 2.9, 1.5, 11.6, 0.7, n0=0.4)
    f.on("walnut", c - 0.08, c + 0.08, 1.5, 11.6, 0.76, n0=0.6)
    for sx in (-1, 1):
        f.on("navy", c + sx * 1.5 - 0.95, c + sx * 1.5 + 0.95, 5.2, 10.4, 0.76, n0=0.6)
        f.cyl("walnut", 0.2, 0.5, (c + sx * 0.5, 1.0, 5.6), axis="n", verts=6)
    f.outline("porcelain", [(c - 3.6, 13.2), (c + 3.6, 13.2), (c, 15.4)], 0.0, 0.7)
    f.text("navy", "BANK", c, 12.35, 0.62, n=0.5, depth=0.04, flat=True)
    # the night depository, a plaque
    f.on("brass", 2.2, 4.6, 6.2, 8.4, 0.4)
    f.on("navy", 2.6, 4.2, 7.0, 7.3, 0.46)
    f.on("brass", w - 5.0, w - 2.0, 6.4, 8.2, 0.4)
    # the street clock on its bracket at the corner
    cu = -0.6 if left_open else w + 0.6
    cp = f.p(cu, 3.4, 15.5)
    k.pole("gunmetal", 0.18, f.p(cu if left_open else cu, 0.4, 15.5), cp, verts=5)
    k.cyl("gunmetal", 1.9, 0.9, cp, rot=(0, 90, 0), verts=14)
    for sx in (-1, 1):
        k.cyl("cream", 1.65, 0.06, (cp.x + sx * 0.47, cp.y, cp.z), rot=(0, 90, 0), verts=14)
        k.box("navy", (0.06, 0.14, 1.2), (cp.x + sx * 0.52, cp.y, cp.z + 0.5))
        k.box("navy", (0.06, 0.9, 0.14), (cp.x + sx * 0.52, cp.y + 0.35 * sx, cp.z))
    k.cyl("gunmetal", 0.5, 0.5, (cp.x, cp.y, cp.z + 2.05), verts=6, r_top=0.1)
    # exposed sides: stone base, tall windows, a coping
    open_sides = ([(k.face((x0, d, 0.0), 270), d - 1.6)] if left_open else []) + ([(k.face((x1, 1.6, 0.0), 90), d - 1.6)] if right_open else [])
    for sf_, ln in open_sides:
        T.ashlar(sf_, 0.0, ln, 0.0, 5.0, row=1.25, seed=seed + 4, stones=("sandstone", "sandstone", "ash", "stone"), mortar="stone", proud=0.3)
        sf_.on("porcelain", 0.0, ln, 5.0, 5.6, 0.55)
        sf_.on("porcelain", 0.0, ln, 25.4, 26.5, 0.7)
        for i in range(4):
            u = ln * (0.14 + i * 0.24)
            sf_.on("navy", u - 2.0, u + 2.0, 8.0, 19.5, 0.1)
            sf_.glass(u - 2.0, u + 2.0, 8.0, 19.5, n=0.22, thick=0.1, transparency=0.4)
            for a, b, c2, e in ((u - 2.5, u - 2.0, 8.0, 19.5), (u + 2.0, u + 2.5, 8.0, 19.5), (u - 2.5, u + 2.5, 7.4, 8.0), (u - 2.5, u + 2.5, 19.5, 20.3),
                                (u - 0.1, u + 0.1, 8.0, 19.5), (u - 2.0, u + 2.0, 13.6, 13.85)):
                sf_.on("porcelain", a, b, c2, e, 0.42, n0=0.0)
            sf_.on("sandstone", u - 3.4, u - 2.9, 5.6, 25.4, 0.3, n0=0.0)
        drainpipe(k, sf_, ln * 0.5, 0.2, H)
    T.parapet(k, x0, x1, 1.6, d, H, H + 2.2, "sandstone")
    return {"w": w, "d": d, "h": H + 2.2}


# ---------------------------------------------------------------------------------------------
# The picture house
# ---------------------------------------------------------------------------------------------

def cinema(k: Kit, w: float = 54.0, d: float = 62.0, *, name: str = "ATOMIC", feature=("NOW SHOWING", "IT CAME FROM BELOW"),
           left_open: bool = True, right_open: bool = False, seed: int = 4) -> dict:
    """The Atomic: a stucco front with fins, a wedge marquee crowded with bulbs, a ticket booth, a tower sign."""
    H = 30.0
    x0, x1 = -w / 2, w / 2
    rec = 7.0                                    # the open lobby's depth
    k.span("blush", x0, x1, rec, d, 0.0, 12.0)
    k.span("blush", x0, x1, 0.0, d, 12.0, H)
    k.span("basalt", x0 + 0.8, x1 - 0.8, 0.8, d - 0.8, H - 0.2, H + 0.2)
    T.parapet(k, x0, x1, 0.0, d, H, H + 2.0, "blush")
    for (a, b) in ((x0, x0 + 7.0), (x1 - 7.0, x1)):          # the lobby's side walls
        k.span("blush", a, b, 0.0, rec, 0.0, 12.0)
        k.collide_span(a, b, 0.0, rec, 0.0, 12.0)
    k.collide_span(x0, x1, rec, d, 0.0, H, name="Building")
    f = k.face((x0, 0.0, 0.0), 0)
    # stucco fins and stripes up the front, a teal base
    f.on("teal", 0.0, 7.0, 0.0, 2.4, 0.25)
    f.on("teal", w - 7.0, w, 0.0, 2.4, 0.25)
    for i in range(9):
        u = 3.0 + i * (w - 6.0) / 8
        if abs(u - w / 2) < 5.0:
            continue
        f.on("porcelain", u - 0.5, u + 0.5, 16.0, H + 1.0 + (2.5 if i in (2, 6) else 0.0), 0.7, n0=0.0)
    for zz in (16.6, 18.0):
        f.on("teal", 0.0, w, zz, zz + 0.5, 0.3, n0=0.0)
    f.on("porcelain", -0.2, w + 0.2, H + 2.0, H + 2.4, 0.4, n0=-1.0)
    # poster cases on the side walls of the lobby
    lf = k.face((x0 + 7.0, 0.3, 0.0), 90)       # the west side wall, facing into the lobby
    rf = k.face((x1 - 7.0, rec - 0.3, 0.0), 270)
    for sidef, sw in ((lf, "signal"), (rf, "teal")):
        sidef.on("chrome", 0.9, 5.5, 3.0, 9.6, 0.25)
        sidef.on(sw, 1.2, 5.2, 3.3, 9.3, 0.32)
        sidef.on("cream", 1.2, 5.2, 3.3, 4.7, 0.36)
        sidef.cyl("hazard", 0.9, 0.06, (3.2, 0.38, 7.2), axis="n", verts=10)
        sidef.glass(1.2, 5.2, 3.3, 9.3, n=0.45, thick=0.05, transparency=0.6)
    for (a, b, sw) in ((1.0, 6.0, "teal"), (w - 6.0, w - 1.0, "signal")):        # and on the street face of the side wings
        f.on("chrome", a, b, 2.8, 10.2, 0.25)
        f.on(sw, a + 0.3, b - 0.3, 3.1, 9.9, 0.32)
        f.on("cream", a + 0.3, b - 0.3, 3.1, 4.6, 0.36)
        f.outline("navy", [(a + 0.9, 4.6), (b - 0.9, 4.6), ((a + b) / 2, 8.6)], 0.34, 0.4)
        f.glass(a + 0.3, b - 0.3, 3.1, 9.9, n=0.45, thick=0.05, transparency=0.6)
    # the lobby: terrazzo, the doors, the ticket booth
    k.span("cream", x0 + 7.0, x1 - 7.0, 0.0, rec, 0.0, 0.14)
    n = 8
    for i in range(n):
        if i % 2 == 0:
            a = x0 + 7.0 + i * (w - 14.0) / n
            k.span("teal", a + 0.1, a + (w - 14.0) / n - 0.1, 0.2, rec - 0.2, 0.14, 0.17, open_=("z-",))
    k.span("blush", x0 + 7.0, x1 - 7.0, 0.0, rec, 11.2, 12.0)                     # its ceiling
    back = k.face((x0, rec, 0.0), 0)
    for c in (w * 0.3, w * 0.7):                 # two pairs of doors
        back.on("porcelain", c - 4.3, c + 4.3, 0.14, 9.6, 0.2)
        for sx in (-1, 1):
            u = c + sx * 2.0
            back.on("walnut", u - 1.85, u + 1.85, 0.14, 9.0, 0.36)
            back.cyl("navy", 0.95, 0.06, (u, 0.4, 6.4), axis="n", verts=12)
            back.cyl("skyblue", 0.8, 0.06, (u, 0.44, 6.4), axis="n", verts=12, mat="Glass", transparency=0.4, shadow=False)
            back.on("brass", u - sx * 1.3 - 0.12, u - sx * 1.3 + 0.12, 3.2, 5.6, 0.6, n0=0.4)
    k.collide_span(x0 + 7.0, x1 - 7.0, rec - 0.1, rec + 0.5, 0.0, 12.0, name="Doors")
    bx_, by_ = 0.0, rec - 3.0                    # the booth
    k.lathe("teal", [(2.4, 0.14), (2.4, 3.4), (2.55, 3.5), (2.55, 3.8)], (bx_, by_, 0), verts=8)
    k.lathe("skyblue", [(2.35, 3.8), (2.35, 7.6)], (bx_, by_, 0), verts=8, mat="Glass", transparency=0.55, shadow=False)
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.pole("chrome", 0.09, (bx_ + math.cos(a) * 2.38, by_ + math.sin(a) * 2.38, 3.8), (bx_ + math.cos(a) * 2.38, by_ + math.sin(a) * 2.38, 7.6), verts=4)
    k.lathe("teal", [(2.9, 7.6), (2.9, 8.2), (1.6, 8.9), (0.0, 9.0)], (bx_, by_, 0), verts=8)
    k.box("cream", (2.6, 0.1, 0.9), (bx_, by_ - 2.5, 8.3))
    k.text("rust", "TICKETS", (bx_, by_ - 2.56, 8.3), 0.52, depth=0.03, flat=True, max_w=2.3)
    k.collider((5.0, 5.0, 9.0), (bx_, by_, 4.5), name="Booth")
    # the marquee: a wedge over the pavement, a letter board on each face, bulbs everywhere
    mz0, mz1, out = 12.0, 17.0, 10.0
    plan = [(-w / 2 + 5.0, 0.0), (w / 2 - 5.0, 0.0), (7.0, -out), (-7.0, -out)]
    with k.at((0, 0, 0)):
        k.prism_z("teal", [(x, y) for x, y in plan], mz0, mz1)
        k.prism_z("chrome", [(x * 1.01, y * 1.02 if y < 0 else y) for x, y in plan], mz0 - 0.25, mz0)
        k.prism_z("chrome", [(x * 1.01, y * 1.02 if y < 0 else y) for x, y in plan], mz1, mz1 + 0.25)
    boards = [((-7.0, -out), (7.0, -out)), ((-w / 2 + 5.0, 0.0), (-7.0, -out)), ((7.0, -out), (w / 2 - 5.0, 0.0))]
    for bi, (a, b) in enumerate(boards):
        ax, ay = a
        bx2, by2 = b
        ln = math.hypot(bx2 - ax, by2 - ay)
        yaw = math.degrees(math.atan2(by2 - ay, bx2 - ax))
        bf = Face(k, (ax, ay, 0.0), yaw)
        bf.on("cream", 1.0, ln - 1.0, mz0 + 0.9, mz1 - 0.9, 0.2)
        if bi == 0:
            bf.text("rust", feature[0], ln / 2, mz1 - 1.75, 0.8, n=0.2, depth=0.04, flat=True, max_w=ln - 3)
            bf.text("navy", feature[1], ln / 2, mz0 + 1.9, 1.25, n=0.2, depth=0.04, flat=True, max_w=ln - 2.6)
        else:
            bf.text("navy", feature[1], ln / 2, (mz0 + mz1) / 2 + 0.3, 1.0, n=0.2, depth=0.04, flat=True, max_w=ln - 3)
            bf.text("rust", "TONIGHT 7 AND 9", ln / 2, mz0 + 1.5, 0.55, n=0.2, depth=0.04, flat=True, max_w=ln - 4)
        nb = max(4, int(ln / 1.5))
        for i in range(nb):
            for zz in (mz0 + 0.45, mz1 - 0.45):
                k.bulb("cream", 0.2, bf.p(0.6 + i * (ln - 1.2) / (nb - 1), 0.12, zz))
    for i in range(5):                           # under the marquee
        for j in range(3):
            xx = -12.0 + i * 6.0
            yy = -1.6 - j * 2.6
            if abs(xx) < (w / 2 - 5.0) - (-yy) * ((w / 2 - 12.0) / out) - 1.0:
                k.bulb("cream", 0.26, (xx, yy, mz0 - 0.32))
    k.light((0, -5.0, mz0 - 2.0), colour="cream", brightness=1.2, range_=32)
    # the tower sign: a fin with the name down it in lights, a starburst on top
    tz0, tz1 = mz1, 47.0
    f.outline("teal", [(w / 2 - 2.8, tz0), (w / 2 + 2.8, tz0), (w / 2 + 3.6, tz1), (w / 2 - 3.6, tz1 - 2.5)], -1.0, 1.6)
    for sx in (-1, 1):
        k.pole("chrome", 0.25, f.p(w / 2 + sx * 2.8, 0.3, tz0), f.p(w / 2 + sx * 3.6, 0.3, tz1 - (2.5 if sx < 0 else 0.0)), verts=5)
    step = (tz1 - tz0 - 5.0) / len(name)
    for i, ch in enumerate(name):
        f.text("hazard", ch, w / 2, tz1 - 3.6 - (i + 0.5) * step, min(3.6, step * 0.82), n=1.6, depth=0.3, font="Oswald-Bold", mat="Neon", shadow=False)
    sp = f.p(w / 2, 0.3, tz1 + 4.6)
    k.pole("chrome", 0.2, f.p(w / 2, 0.3, tz1 - 1.0), sp, verts=5)
    starburst(k, (sp.x, sp.y, sp.z), r=4.0, spikes=12)
    # an exposed side
    open_sides = ([(k.face((x0, d, 0.0), 270), d)] if left_open else []) + ([(k.face((x1, 0.0, 0.0), 90), d)] if right_open else [])
    for sf_, ln in open_sides:
        sf_.on("teal", 0.0, ln, 0.0, 2.4, 0.2)
        sf_.on("porcelain", 0.3, ln - 0.3, H + 1.98, H + 2.38, 0.4, n0=-1.0)
        for zz in (16.6, 18.0):
            sf_.on("teal", 0.0, ln, zz, zz + 0.5, 0.3, n0=0.0)
        a, b = (ln * 0.5, ln - 5.0) if sf_.yaw == 270 else (5.0, ln * 0.5)
        wall_ad(k, sf_, a, b, 4.0, 15.0, [("THE ATOMIC", "teal", "AlfaSlabOne-Regular", 1.2), ("Air Cooled", "signal", "Lobster-Regular", 1.0),
                                           ("TWO FEATURES NIGHTLY", "navy", "Oswald-Bold", 0.5)])
        du = ln * 0.2 if sf_.yaw == 270 else ln * 0.8
        sf_.on("porcelain", du - 2.4, du + 2.4, 0.0, 8.6, 0.2)
        sf_.on("gunmetal", du - 2.0, du + 2.0, 0.0, 8.2, 0.34)
        sf_.on("rust", du - 1.4, du + 1.4, 8.8, 9.9, 0.3)
        sf_.text("cream", "EXIT", du, 9.35, 0.6, n=0.3, depth=0.03, flat=True)
        drainpipe(k, sf_, ln * 0.42, 0.2, H)
    roof_unit(k, x0 + w * 0.3, d * 0.6, H + 0.2, s=1.3)
    vent_pipe(k, x0 + w * 0.7, d * 0.4, H + 0.2)
    return {"w": w, "d": d, "h": H + 2.0}


# ---------------------------------------------------------------------------------------------
# The diner
# ---------------------------------------------------------------------------------------------

def diner(k: Kit, w: float = 58.0, d: float = 26.0, *, name: str = "COMET", seed: int = 6) -> dict:
    """The Comet: a streamlined dining car: stainless below, enamel bands, a ribbon of glass, a roof sign."""
    H = 12.5
    x0, x1 = -w / 2, w / 2
    r = d / 2
    # the body: a box between two half-round ends
    k.span("porcelain", x0 + r, x1 - r, 0.0, d, 0.0, H)
    for sx in (-1, 1):
        k.cyl("porcelain", r, H, (sx * (w / 2 - r), r, H / 2), verts=20)
        k.cyl("chrome", r + 0.12, 3.2, (sx * (w / 2 - r), r, 1.6), verts=20, caps=(False, False))
        k.cyl("signal", r + 0.1, 0.5, (sx * (w / 2 - r), r, 9.3), verts=20, caps=(False, False))
        k.cyl("signal", r + 0.1, 0.5, (sx * (w / 2 - r), r, 10.3), verts=20, caps=(False, False))
        k.cyl("chrome", r + 0.45, 0.6, (sx * (w / 2 - r), r, H + 0.1), verts=20)
        k.cyl("gunmetal", r - 0.3, 0.5, (sx * (w / 2 - r), r, H + 0.55), verts=20)
        # the end's windows: glass round the curve
        k.cyl("navy", r + 0.03, 4.2, (sx * (w / 2 - r), r, 6.0), verts=20, caps=(False, False))
        k.cyl("skyblue", r + 0.1, 4.2, (sx * (w / 2 - r), r, 6.0), verts=20, caps=(False, False), mat="Glass", transparency=0.45, shadow=False)
        for i in range(11):
            a = math.pi / 2 + sx * (-math.pi / 2 + i * math.pi / 10) if sx > 0 else math.pi / 2 + (i * math.pi / 10)
            px, py = sx * (w / 2 - r) + math.cos(a) * (r + 0.16), r + math.sin(a) * (r + 0.16)
            k.pole("chrome", 0.12, (px, py, 3.9), (px, py, 8.1), verts=4)
    k.span("chrome", x0 + r, x1 - r, -0.45, d + 0.45, H - 0.2, H + 0.4)
    k.span("gunmetal", x0 + r, x1 - r, 0.3, d - 0.3, H + 0.3, H + 0.8)
    k.collide_span(x0 + r, x1 - r, 0.0, d, 0.0, H, name="Building")
    for sx in (-1, 1):
        k.collider((r * 1.6, d * 0.92, H), (sx * (w / 2 - r * 0.6), r, H / 2), name="Building")
    for f, ln in ((k.face((x0 + r, 0.0, 0.0), 0), w - 2 * r), (k.face((x1 - r, d, 0.0), 180), w - 2 * r)):
        f.on("chrome", 0.0, ln, 0.0, 3.2, 0.14)
        for i in range(int(ln / 1.4)):                 # the stainless's flutes
            f.on("steel", 0.3 + i * 1.4, 0.42 + i * 1.4, 0.3, 2.9, 0.18, n0=0.12)
        for zz in (9.05, 10.05):
            f.on("signal", 0.0, ln, zz, zz + 0.5, 0.12)
        f.on("navy", 0.0, ln, 3.9, 8.1, 0.04)
        f.glass(0.0, ln, 3.9, 8.1, n=0.12, thick=0.08, transparency=0.5)
        n = int(ln / 4.2)
        for i in range(n + 1):
            f.on("chrome", i * ln / n - 0.14, i * ln / n + 0.14, 3.9, 8.1, 0.24, n0=0.0)
        f.on("chrome", 0.0, ln, 3.6, 3.9, 0.3, n0=0.0)
        f.on("chrome", 0.0, ln, 8.1, 8.4, 0.3, n0=0.0)
    f = k.face((x0 + r, 0.0, 0.0), 0)
    ln = w - 2 * r
    # inside, seen through the glass: a counter, stools, booth backs, pendant lamps
    k.span("porcelain", x0 + r + 1, x1 - r - 1, d * 0.62, d * 0.7, 0.0, 4.4)
    k.span("rust", x0 + r + 1, x1 - r - 1, d * 0.6, d * 0.72, 4.4, 4.6)
    for i in range(int(ln / 4.0)):
        x = x0 + r + 2.4 + i * 4.0
        k.cyl("chrome", 0.2, 3.0, (x, d * 0.5, 1.5), verts=5)
        k.cyl("rust", 0.75, 0.4, (x, d * 0.5, 3.1), verts=8)
        k.box("rust", (3.0, 0.5, 4.2), (x + 2.0, 1.2, 4.0)) if i % 2 == 0 else None
        k.bulb("hazard", 0.3, (x, d * 0.4, 9.2))
    # the vestibule: a glazed porch with the door, steps, the name over it
    c = ln * 0.5
    f.on("chrome", c - 4.2, c + 4.2, 0.0, 10.6, 2.6, n0=0.0)
    f.on("porcelain", c - 3.9, c + 3.9, 0.3, 10.3, 2.66, n0=2.5)
    f.on("rust", c - 1.9, c + 1.9, 0.6, 8.4, 2.74, n0=2.6)
    f.on("navy", c - 1.4, c + 1.4, 3.4, 7.8, 2.8, n0=2.7)
    f.glass(c - 1.4, c + 1.4, 3.4, 7.8, n=2.86, thick=0.06, transparency=0.45)
    f.on("chrome", c + 1.45, c + 1.7, 3.6, 5.2, 3.0, n0=2.74)
    f.cyl("signal", 0.75, 0.1, (c, 2.72, 9.3), axis="n", verts=12, mat="Neon", shadow=False)
    for i, (out, top) in enumerate(((5.2, 0.3), (4.0, 0.6))):
        k.span("ash", x0 + r + c - 3.6, x0 + r + c + 3.6, -out, 0.0, 0.0, top)
    k.collide_span(x0 + r + c - 4.2, x0 + r + c + 4.2, -2.6, 0.0, 0.0, 10.6, name="Porch")
    # the roof sign: the name in lights on a trussed board, a comet over it
    sz = H + 0.8
    for u in (c - 9.0, c, c + 9.0):
        k.pole("gunmetal", 0.2, f.p(u, -3.0, sz), f.p(u, -3.0, sz + 7.4), verts=4)
        k.pole("gunmetal", 0.12, f.p(u, -8.0, sz), f.p(u, -3.0, sz + 5.0), verts=3)
    sign = Face(k, f.p(0, -2.8, 0), 0)
    sign.on("teal", c - 11.5, c + 11.5, sz + 2.2, sz + 7.6, 0.4, n0=0.0, open_=())
    sign.on("chrome", c - 11.8, c + 11.8, sz + 7.6, sz + 7.9, 0.5, n0=-0.1, open_=())
    sign.on("chrome", c - 11.8, c + 11.8, sz + 1.9, sz + 2.2, 0.5, n0=-0.1, open_=())
    sign.text("signal", name, c - 2.0, sz + 5.0, 3.6, n=0.4, depth=0.35, font="Lobster-Regular", max_w=15.5, mat="Neon", shadow=False, res=2)
    sign.text("cream", "DINER", c + 7.6, sz + 3.6, 1.5, n=0.4, depth=0.2, font="Oswald-Bold", mat="Neon", shadow=False)
    # the comet: a star and its tail sweeping back
    star = sign.p(c - 12.6, 0.6, sz + 9.6)
    starburst(k, (star.x, star.y, star.z), r=2.2, spikes=10, flat=True, ball="hazard")
    for i in range(4):
        a, b = sign.p(c - 11.0 + i * 0.3, 0.5, sz + 9.3 - i * 0.35), sign.p(c + 2.0 + i * 2.6, 0.5, sz + 8.3 - i * 0.1)
        k.pole("hazard", 0.09, a, b, verts=3, mat="Neon", shadow=False)
    k.light(f.p(c, 5.0, 9.0), colour="hazard", brightness=0.8, range_=26)
    # the kitchen's flue and a roof fan at the back
    vent_pipe(k, x0 + w * 0.7, d * 0.7, H + 0.8, h=3.2)
    roof_unit(k, x0 + w * 0.3, d * 0.6, H + 0.8, s=0.8)
    return {"w": w, "d": d, "h": H + 9.0}


# ---------------------------------------------------------------------------------------------
# The gas station
# ---------------------------------------------------------------------------------------------

def gas_pump(k: Kit, x: float, y: float, z: float = 0.0, yaw: float = 0.0, body: str = "rust") -> None:
    """A 1950s pump: an enamel body, a dial window, a hose, a glowing globe."""
    with k.at((x, y, z), yaw):
        k.box("gunmetal", (2.4, 1.7, 0.4), (0, 0, 0.2))
        k.box(body, (2.1, 1.4, 5.2), (0, 0, 3.0))
        k.box("porcelain", (2.14, 1.44, 0.5), (0, 0, 4.4))
        k.box("chrome", (2.2, 1.5, 0.2), (0, 0, 5.7))
        for sy in (-1, 1):
            k.box("cream", (1.5, 0.06, 1.3), (0, sy * 0.72, 3.4))
            k.box("navy", (1.2, 0.07, 0.36), (0, sy * 0.74, 3.7))
            k.box("navy", (1.2, 0.07, 0.36), (0, sy * 0.74, 3.15))
        k.cyl("chrome", 0.3, 0.5, (0, 0, 6.05), verts=8)
        k.sphere("cream", 0.95, (0, 0, 7.0), segs=10, rings=6, mat="Neon", shadow=False)
        k.cyl(body, 0.98, 0.3, (0, 0, 7.0), verts=10, caps=(False, False))
        k.wire("rubber", [(1.05, 0.3, 4.6), (1.5, 0.3, 3.2), (1.4, 0.3, 1.4), (1.1, 0.3, 2.6)], r=0.09, verts=4)
        k.box("chrome", (0.2, 0.5, 0.7), (1.1, 0.3, 2.9))
        k.collider((2.4, 1.7, 7.5), (0, 0, 3.75), name="Pump")


def gas_station(k: Kit, w: float = 72.0, d: float = 62.0, *, name: str = "STARLITE", seed: int = 7) -> dict:
    """Starlite Gas: an enamel-panel office and two service bays at the back of its lot, a canopy over the pumps, a star on a pole."""
    x0 = -w / 2
    # the lot's apron
    k.span("ash", x0, -x0, 0.0, d, -0.2, 0.06)
    ow, od, oh = 46.0, 22.0, 13.0
    ox0, oy0 = x0 + 6.0, d - od - 2.0
    k.span("porcelain", ox0, ox0 + ow, oy0, oy0 + od, 0.0, oh)
    k.span("basalt", ox0 + 0.6, ox0 + ow - 0.6, oy0 + 0.6, oy0 + od - 0.6, oh - 0.1, oh + 0.2)
    k.collide_span(ox0, ox0 + ow, oy0, oy0 + od, 0.0, oh, name="Building")
    f = k.face((ox0, oy0, 0.0), 0)
    for sf_, ln in ((f, ow), (k.face((ox0 + ow, oy0, 0.0), 90), od), (k.face((ox0, oy0 + od, 0.0), 270), od)):
        sf_.on("teal", 0.0, ln, 0.0, 1.4, 0.16)
        for zz in (10.3, 11.1):
            sf_.on("teal", 0.0, ln, zz, zz + 0.45, 0.14)
        sf_.on("chrome", -0.3, ln + 0.3, oh - 0.1, oh + 0.5, 0.5, n0=-0.6)
        n = int(ln / 3.2)
        for i in range(1, n):                         # the enamel panels' joints
            sf_.on("ash", i * ln / n - 0.04, i * ln / n + 0.04, 1.4, 10.3, 0.08, n0=0.02)
    # the office: a corner of plate glass, its door
    f.on("navy", 1.2, 15.0, 1.6, 9.0, 0.06)
    f.glass(1.2, 15.0, 1.6, 9.0, n=0.16, thick=0.1, transparency=0.6)
    for u in (1.2, 5.8, 10.4, 15.0):
        f.on("chrome", u - 0.14, u + 0.14, 1.6, 9.0, 0.28, n0=0.0)
    f.on("chrome", 1.2, 15.0, 9.0, 9.3, 0.3, n0=0.0)
    f.on("teal", 6.2, 10.0, 0.1, 8.6, 0.22, n0=0.1)
    f.on("navy", 6.9, 9.3, 3.0, 8.0, 0.26, n0=0.2)
    f.on("chrome", 9.5, 9.75, 4.0, 5.4, 0.5, n0=0.2)
    f.text("teal", "OFFICE", 8.1, 9.75, 0.55, n=0.1, depth=0.04, flat=True)
    # two service bays: roll doors with glass lights
    for i, u in enumerate((19.0, 32.5)):
        f.on("chrome", u - 0.3, u + 11.3, 0.0, 10.0, 0.2)
        f.on("porcelain", u, u + 11.0, 0.0, 9.7, 0.3, n0=0.1)
        for j in range(5):
            f.on("ash", u, u + 11.0, 1.9 + j * 1.9, 1.98 + j * 1.9, 0.34, n0=0.28)
        for j in range(4):
            f.on("navy", u + 0.8 + j * 2.5, u + 2.6 + j * 2.5, 5.9, 7.4, 0.36, n0=0.28)
        f.text("teal", ("LUBRICATION", "TIRES  ·  BATTERIES")[i], u + 5.5, 9.75 + 0.35 - 0.35, 0.5, n=0.14, depth=0.04, flat=True, max_w=10)
    # the name along the roof's edge
    f.text("signal", name, ow / 2, oh + 2.3, 3.2, n=-1.2, depth=0.5, font="AlfaSlabOne-Regular", max_w=30, back=True)
    for u in (ow / 2 - 13, ow / 2, ow / 2 + 13):
        k.pole("gunmetal", 0.1, f.p(u, -1.5, oh + 0.2), f.p(u, -1.5, oh + 1.0), verts=4)
    # the canopy over the island, on two columns
    cx, cy0, cw, cd, cz = x0 + 38.0, 12.0, 34.0, 20.0, 13.5
    k.span("porcelain", cx - cw / 2, cx + cw / 2, cy0, cy0 + cd, cz, cz + 1.3)
    k.span("teal", cx - cw / 2 - 0.2, cx + cw / 2 + 0.2, cy0 - 0.2, cy0 + cd + 0.2, cz + 0.35, cz + 0.95)
    k.span("chrome", cx - cw / 2 - 0.3, cx + cw / 2 + 0.3, cy0 - 0.3, cy0 + cd + 0.3, cz + 1.3, cz + 1.5)
    for i in range(4):
        for j in range(2):
            k.cyl("cream", 0.9, 0.1, (cx - cw / 2 + 5 + i * 8.0, cy0 + 6 + j * 8.0, cz - 0.05), verts=8, mat="Neon", shadow=False)
    k.light((cx, cy0 + cd / 2, cz - 2.0), colour="cream", brightness=1.1, range_=34)
    isl_y = cy0 + cd / 2
    k.span("ash", cx - 11.0, cx + 11.0, isl_y - 2.0, isl_y + 2.0, 0.0, 0.55)
    k.collide_span(cx - 11.0, cx + 11.0, isl_y - 2.0, isl_y + 2.0, 0.0, 0.55, name="Island")
    for sx in (-1, 1):
        k.cyl("porcelain", 0.7, cz - 0.55, (cx + sx * 9.5, isl_y, 0.55 + (cz - 0.55) / 2), verts=10)
        k.cyl("teal", 0.76, 1.6, (cx + sx * 9.5, isl_y, 1.35), verts=10)
        k.collider((1.5, 1.5, cz), (cx + sx * 9.5, isl_y, cz / 2), name="Column")
    gas_pump(k, cx - 4.2, isl_y, 0.55)
    gas_pump(k, cx + 4.2, isl_y, 0.55, body="teal")
    # an oil rack, a stack of tyres, the air tower
    with k.at((cx, isl_y, 0.55)):
        k.box("gunmetal", (1.6, 0.9, 0.12), (0, 0, 1.3))
        for sx in (-0.6, 0.6):
            k.pole("gunmetal", 0.06, (sx, 0, 0), (sx, 0, 1.3), verts=4)
        for i in range(4):
            k.cyl(("signal", "hazard")[i % 2], 0.22, 0.6, (-0.55 + i * 0.37, 0, 1.66), verts=6)
    for i in range(4):
        k.cyl("rubber", 1.3, 0.55, (ox0 + ow + 3.0, oy0 + 4.0, 0.3 + i * 0.56), verts=10)
        k.cyl("ash", 0.7, 0.57, (ox0 + ow + 3.0, oy0 + 4.0, 0.3 + i * 0.56), verts=8)
    k.box("rust", (1.3, 1.1, 4.4), (ox0 - 2.2, oy0 + 3.0, 2.2))
    k.cyl("cream", 0.5, 0.1, (ox0 - 2.2, oy0 + 2.42, 3.4), rot=(90, 0, 0), verts=10)
    k.text("cream", "AIR", (ox0 - 2.2, oy0 + 2.44, 1.9), 0.5, depth=0.03, flat=True)
    # the sign: a pole at the kerb, the name, a star that turns the head
    sx_, sy_ = -x0 - 7.0, 6.0
    k.box("stone", (3.0, 3.0, 1.2), (sx_, sy_, 0.6))
    k.pole("porcelain", 0.45, (sx_, sy_, 1.2), (sx_, sy_, 34.0), verts=8)
    k.collider((3.0, 3.0, 20.0), (sx_, sy_, 10.0), name="Sign")
    sgn = Face(k, (sx_ - 6.0, sy_ - 0.5, 0.0), 0)
    for (sf2, yaw2) in ((sgn, 0), (Face(k, (sx_ + 6.0, sy_ + 0.5, 0.0), 180), 180)):
        sf2.on("teal", 0.0, 12.0, 22.0, 27.4, 0.5, n0=0.0)
        sf2.text("cream", name, 6.0, 25.3, 1.7, n=0.5, depth=0.12, font="AlfaSlabOne-Regular", max_w=10.6)
        sf2.text("hazard", "GAS  25 CENTS", 6.0, 23.0, 0.85, n=0.5, depth=0.05, flat=True, max_w=10)
    k.span("chrome", sx_ - 6.2, sx_ + 6.2, sy_ - 0.6, sy_ + 0.6, 27.4, 27.7)
    k.span("chrome", sx_ - 6.2, sx_ + 6.2, sy_ - 0.6, sy_ + 0.6, 21.7, 22.0)
    star = []
    for i in range(10):
        a = math.pi / 2 + 2 * math.pi * i / 10
        rr = 4.2 if i % 2 == 0 else 1.7
        star.append((sx_ + math.cos(a) * rr, 32.6 + math.sin(a) * rr))
    k.prism_y("hazard", star, sy_ - 0.35, sy_ + 0.35, mat="Neon", shadow=False)
    k.prism_y("chrome", [(sx_ + (px - sx_) * 1.12, 32.6 + (pz - 32.6) * 1.12) for px, pz in star], sy_ - 0.2, sy_ + 0.2)
    return {"w": w, "d": d, "h": 37.0}


# ---------------------------------------------------------------------------------------------
# The market
# ---------------------------------------------------------------------------------------------

def market(k: Kit, w: float = 60.0, d: float = 52.0, *, name: str = "MARKET", over: str = "Brightwater", seed: int = 9) -> dict:
    """The Brightwater Market: a low wide store, glass from end to end, produce on the pavement, big letters on the roof."""
    H = 15.0
    x0, x1 = -w / 2, w / 2
    rng = random.Random(seed)
    k.span("cream", x0, x1, RECESS, d, 0.0, H)
    k.span("cream", x0, x1, 0.0, RECESS, 10.2, H)
    k.span("basalt", x0 + 0.8, x1 - 0.8, 0.8, d - 0.8, H - 0.2, H + 0.2)
    T.parapet(k, x0, x1, 0.0, d, H, H + 1.8, "cream")
    k.collide_span(x0, x1, RECESS, d, 0.0, H, name="Building")
    f = k.face((x0, 0.0, 0.0), 0)
    for (a, b) in ((0.0, 2.2), (w - 2.2, w)):
        k.span("leaf", x0 + a, x0 + b, 0.0, RECESS, 0.0, 10.2)
        k.collide_span(x0 + a, x0 + b, 0.0, RECESS, 0.0, 10.2)
    doors = [w * 0.5]
    dw = 9.0
    for (a, b) in ((2.2, w / 2 - dw / 2), (w / 2 + dw / 2, w - 2.2)):
        f.on("leaf", a, b, 0.0, BULK, 0.2, n0=-RECESS)
        f.on("chrome", a, b, BULK, BULK + 0.22, 0.3, n0=-0.2)
        k.span("cream", x0 + a, x0 + b, 0.05, RECESS, BULK - 0.1, BULK)
        k.span("porcelain", x0 + a, x0 + b, RECESS - 0.07, RECESS + 0.02, BULK, 9.6)
        k.span("porcelain", x0 + a + 0.3, x0 + b - 0.3, 0.5, 1.0, 9.3, 9.48, mat="Neon", shadow=False)
        f.glass(a, b, BULK + 0.22, 9.6, n=0.0, thick=0.14, transparency=0.74)
        n = max(1, round((b - a) / 5.6))
        for i in range(n + 1):
            f.on("chrome", a + (b - a) * i / n - 0.13, a + (b - a) * i / n + 0.13, BULK + 0.22, 9.6, 0.2, n0=-0.2)
        display(k, "grocery", x0 + a + 0.3, x0 + b - 0.3, 0.3, RECESS, BULK, 9.6, rng)
        # sale bills on the glass
        for i in range(int((b - a) / 7.0)):
            u = a + 3.0 + i * 7.0
            sw = ("hazard", "porcelain", "signal")[i % 3]
            f.on(sw, u - 1.5, u + 1.5, 5.6, 7.9, 0.12, n0=0.08)
            f.text("rust" if sw != "signal" else "cream", ("EGGS 39", "FRESH PIES", "COFFEE 69", "HAMS")[i % 4], u, 6.75, 0.62, n=0.12, depth=0.02, flat=True,
                   max_w=2.6)
        k.collide_span(x0 + a, x0 + b, 0.0, RECESS, 0.0, 9.6)
    a, b = w / 2 - dw / 2, w / 2 + dw / 2
    k.span("cream", x0 + a, x0 + b, 0.0, RECESS, 0.0, 0.12)
    back = k.face((x0, RECESS, 0.0), 0)
    back.on("chrome", a, b, 0.12, 9.6, 0.2)
    for sx in (-1, 1):
        u = w / 2 + sx * 2.1
        back.on("navy", u - 1.9, u + 1.9, 0.4, 8.8, 0.3)
        back.glass(u - 1.9, u + 1.9, 0.4, 8.8, n=0.36, thick=0.06, transparency=0.5)
        back.on("chrome", u - sx * 1.5 - 0.1, u - sx * 1.5 + 0.1, 3.4, 5.4, 0.55, n0=0.3)
        back.text("leaf", ("IN", "OUT")[sx > 0], u, 7.6, 0.6, n=0.44, depth=0.02, flat=True)
    k.collide_span(x0 + a, x0 + b, RECESS - 0.1, RECESS + 0.5, 0.0, 9.6, name="Door")
    f.on("chrome", 2.2, w - 2.2, 9.6, 9.9, 0.28, n0=-0.2)
    # a long flat canopy with the store's script on its edge
    flat_canopy(k, f, 1.0, w - 1.0, 10.3, out=6.0, edge="leaf", bulbs=True)
    f.on("leaf", 0.0, w, 11.6, 12.4, 0.2, n0=0.0)
    f.on("porcelain", -0.2, w + 0.2, H + 1.75, H + 2.1, 0.3, n0=-1.0)
    # the roof letters on their frame
    step = 6.6
    total = step * (len(name) - 1)
    for i, ch in enumerate(name):
        u = w / 2 - total / 2 + i * step
        f.text("rust", ch, u, H + 6.4, 5.6, n=-2.0, depth=0.7, font="AlfaSlabOne-Regular", back=True, res=2)
        k.pole("gunmetal", 0.14, f.p(u, -2.4, H + 0.2), f.p(u, -2.4, H + 4.0), verts=4)
        k.pole("gunmetal", 0.1, f.p(u, -6.0, H + 0.2), f.p(u, -2.5, H + 6.5), verts=3)
    k.pole("gunmetal", 0.12, f.p(w / 2 - total / 2 - 2, -2.4, H + 3.7), f.p(w / 2 + total / 2 + 2, -2.4, H + 3.7), verts=4)
    f.text("leaf", over, w / 2 - total / 2 + 5.0, H + 11.2, 2.6, n=-2.0, depth=0.4, font="Lobster-Regular", back=True)
    # produce on the pavement: slanted crates of fruit either side of the door
    for i, u in enumerate((6.0, 10.5, 15.0, w - 15.0, w - 10.5, w - 6.0)):
        p = f.p(u, 1.6, 0.0)
        k.box("pine", (3.6, 2.4, 1.6), (p.x, p.y, 0.8))
        k.box("pine", (3.6, 2.6, 0.5), (p.x, p.y - 0.2, 1.9), rot=(18, 0, 0))
        sw = ("signal", "leaf", "hazard", "rust", "avocado", "blush")[i]
        for aa in range(5):
            for bb in range(3):
                k.blob(sw, 0.36, (p.x - 1.4 + aa * 0.7, p.y - 0.95 + bb * 0.7, 2.25 + bb * 0.24), detail=0, faceted=False)
        k.collider((3.6, 2.6, 2.6), (p.x, p.y, 1.3), name="Stand")
    roof_unit(k, x0 + w * 0.3, d * 0.6, H + 0.2, s=1.2)
    roof_unit(k, x0 + w * 0.7, d * 0.5, H + 0.2, s=1.0)
    return {"w": w, "d": d, "h": H + 14.0}
