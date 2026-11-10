"""props: what stands on Brightwater's pavements and at its kerbs (A9 and the town rebuild; bible
Sections 12 and 21; STYLE.md). Built on townkit. Each is drawn at its own origin (its foot on
the ground, its front to -Y unless said) and gets a small collider, so a block can scatter them
with Kit.at; cars, trees, the bunting and the barricade are also assets of their own
(generators/Town/Town_*.py).
"""
from __future__ import annotations

import math
import random

from townkit import Kit


def street_lamp(k: Kit, banner: str | None = "teal", lit: bool = False) -> None:
    """A twin-arm lamp: a fluted iron foot, a tall post, two acorn globes, a Founders' Day banner."""
    k.lathe("gunmetal", [(0.95, 0), (0.95, 0.5), (0.6, 1.0), (0.5, 2.6), (0.34, 3.2), (0.28, 3.4)], (0, 0, 0), verts=8)
    k.pole("gunmetal", 0.26, (0, 0, 3.3), (0, 0, 17.0), verts=6, r_top=0.18)
    k.sphere("gunmetal", 0.34, (0, 0, 17.2), segs=6, rings=4)
    for sx in (-1, 1):
        k.wire("gunmetal", [(0, 0, 15.6), (sx * 1.2, 0, 16.6), (sx * 2.6, 0, 16.5)], r=0.1, verts=4)
        k.wire("gunmetal", [(0, 0, 14.2), (sx * 1.6, 0, 15.6), (sx * 2.6, 0, 16.3)], r=0.06, verts=3)
        k.cyl("gunmetal", 0.5, 0.25, (sx * 2.6, 0, 16.2), verts=8)
        k.lathe("cream", [(0.3, 0), (0.62, -0.5), (0.6, -1.2), (0.25, -1.75), (0.0, -1.8)], (sx * 2.6, 0, 16.1), verts=8, mat="Neon", shadow=False)
        k.cyl("gunmetal", 0.2, 0.3, (sx * 2.6, 0, 16.45), verts=6, r_top=0.05)
    if banner:
        k.pole("gunmetal", 0.07, (0, 0, 13.2), (0, -2.9, 13.2), verts=4)
        k.pole("gunmetal", 0.07, (0, 0, 8.2), (0, -2.9, 8.2), verts=4)
        k.span(banner, -0.05, 0.05, -2.8, -0.35, 8.3, 13.1)
        k.span("cream", -0.07, 0.07, -2.8, -0.35, 12.1, 12.5)
        k.span("cream", -0.07, 0.07, -2.8, -0.35, 8.9, 9.3)
        for sx in (-1, 1):
            k.cyl("hazard", 0.75, 0.04, (sx * 0.08, -1.58, 10.7), rot=(0, 90, 0), verts=10)
    k.collider((1.6, 1.6, 12.0), (0, 0, 6.0), name="Lamp")
    if lit:
        k.light((0, 0, 15.0), colour="cream", brightness=1.0, range_=40)


def tree(k: Kit, seed: int = 1, h: float = 15.0, grate: bool = True) -> None:
    """A street tree: a trunk, two boughs, a crown of leafy lumps, an iron grate round its foot."""
    rng = random.Random(seed)
    if grate:
        k.cyl("gunmetal", 2.6, 0.12, (0, 0, 0.06), verts=12, caps=(False, True))
        k.cyl("walnut", 1.1, 0.14, (0, 0, 0.08), verts=8, caps=(False, True))
    k.pole("walnut", 0.55, (0, 0, 0), (0.2, 0.1, h * 0.52), verts=6, r_top=0.36)
    boughs = []
    for i in range(3):
        a = rng.uniform(0, 6.28)
        tip = (0.2 + math.cos(a) * 2.4, 0.1 + math.sin(a) * 2.4, h * 0.7 + rng.uniform(-0.5, 0.8))
        k.pole("walnut", 0.3, (0.2, 0.1, h * 0.48), tip, verts=5, r_top=0.14)
        boughs.append(tip)
    greens = ("leaf", "forest", "avocado")
    r0 = h * 0.26
    k.blob(greens[seed % 2], r0 * 1.15, (0.2, 0.1, h * 0.8), scale=(1, 1, 0.82), detail=1, jitter=0.14, seed=seed)
    for i, tip in enumerate(boughs):
        k.blob(greens[(seed + i) % 3], r0 * rng.uniform(0.7, 0.95), (tip[0] * 1.35, tip[1] * 1.35, tip[2] + rng.uniform(0.2, 1.4)), scale=(1, 1, 0.8), detail=1,
               jitter=0.16, seed=seed * 7 + i)
    k.blob(greens[(seed + 1) % 3], r0 * 0.75, (0.3, -0.4, h * 0.98), scale=(1, 1, 0.8), detail=1, jitter=0.14, seed=seed + 31)
    k.collider((1.4, 1.4, h * 0.5), (0, 0, h * 0.25), name="Tree")


def bench(k: Kit) -> None:
    """A park bench: iron ends, wooden slats."""
    for sx in (-1, 1):
        k.prism_x("gunmetal", [(-1.0, 0), (-0.7, 0), (-0.5, 1.5), (0.6, 1.5), (0.95, 0), (1.25, 0), (0.95, 1.7), (1.25, 3.4), (1.0, 3.5), (0.55, 1.85), (-0.75, 1.85)],
                  sx * 3.1 - 0.12, sx * 3.1 + 0.12)
    for i in range(4):
        k.span("walnut", -3.3, 3.3, -0.7 + i * 0.42, -0.4 + i * 0.42, 1.78, 1.92)
    for i in range(3):
        k.span("walnut", -3.3, 3.3, 0.92 + i * 0.1, 1.06 + i * 0.1, 2.3 + i * 0.44, 2.62 + i * 0.44)
    k.collider((6.6, 2.2, 2.2), (0, 0.2, 1.1), name="Bench")


def hydrant(k: Kit, body: str = "rust") -> None:
    k.lathe(body, [(0.62, 0), (0.62, 0.25), (0.42, 0.4), (0.42, 1.9), (0.55, 2.0), (0.55, 2.2), (0.36, 2.55), (0.0, 2.75)], (0, 0, 0), verts=8)
    for sx in (-1, 1):
        k.cyl(body, 0.24, 0.5, (sx * 0.6, 0, 1.5), rot=(0, 90, 0), verts=6)
        k.cyl("chrome", 0.16, 0.12, (sx * 0.88, 0, 1.5), rot=(0, 90, 0), verts=5)
    k.cyl(body, 0.3, 0.45, (0, -0.55, 1.3), rot=(90, 0, 0), verts=6)
    k.cyl("chrome", 0.14, 0.2, (0, 0, 2.8), verts=5)
    k.collider((1.3, 1.3, 2.8), (0, 0, 1.4), name="Hydrant")


def mailbox(k: Kit) -> None:
    """A street letter box: a round-topped steel box on four legs."""
    for sx in (-0.8, 0.8):
        for sy in (-0.7, 0.7):
            k.pole("navy", 0.1, (sx, sy, 0), (sx * 0.9, sy * 0.9, 1.0), verts=4)
    k.box("navy", (2.2, 2.0, 2.4), (0, 0, 2.2))
    k.cyl("navy", 1.0, 2.2, (0, 0, 3.4), rot=(0, 90, 0), verts=12)
    k.box("porcelain", (1.5, 0.06, 0.5), (0, -1.02, 2.2))
    k.box("rust", (1.5, 0.06, 0.2), (0, -1.02, 2.75))
    k.box("navy", (1.9, 0.3, 0.14), (0, -1.0, 3.5), rot=(20, 0, 0))
    k.text("navy", "U.S. MAIL", (0, -1.06, 2.2), 0.26, depth=0.02, flat=True, max_w=1.3)
    k.collider((2.2, 2.0, 4.4), (0, 0, 2.2), name="Mailbox")


def trash_can(k: Kit) -> None:
    k.lathe("steel", [(0.75, 0), (0.95, 2.6), (1.0, 2.6), (1.0, 2.75)], (0, 0, 0), verts=10)
    k.cyl("basalt", 0.92, 0.05, (0, 0, 2.6), verts=10)
    for zz in (0.6, 1.4, 2.2):
        k.cyl("gunmetal", 0.8 + zz * 0.075, 0.1, (0, 0, zz), verts=10, caps=(False, False))
    k.box("teal", (1.2, 0.06, 0.7), (0, -0.92, 1.6))
    k.collider((2.0, 2.0, 2.8), (0, 0, 1.4), name="Bin")


def parking_meter(k: Kit) -> None:
    k.pole("steel", 0.11, (0, 0, 0), (0, 0, 3.6), verts=5)
    k.blob("steel", 0.42, (0, 0, 4.0), scale=(0.85, 0.55, 1.1), detail=1, faceted=False)
    k.cyl("cream", 0.26, 0.08, (0, -0.2, 4.1), rot=(90, 0, 0), verts=8)
    k.box("rust", (0.3, 0.06, 0.1), (0, -0.25, 4.14))
    k.collider((0.6, 0.6, 4.4), (0, 0, 2.2), name="Meter")


def newspaper_box(k: Kit, body: str = "hazard") -> None:
    for sx in (-0.6, 0.6):
        for sy in (-0.5, 0.5):
            k.pole("gunmetal", 0.07, (sx, sy, 0), (sx, sy, 1.2), verts=4)
    k.box(body, (1.7, 1.4, 2.0), (0, 0, 2.2))
    k.box("navy", (1.3, 0.05, 1.0), (0, -0.72, 2.4))
    k.box("cream", (1.1, 0.06, 0.8), (0, -0.74, 2.4))
    k.box("navy", (0.9, 0.07, 0.16), (0, -0.76, 2.62))
    k.box(body, (1.74, 1.44, 0.2), (0, 0, 3.3))
    k.text("navy", "GAZETTE", (0, -0.73, 1.55), 0.24, depth=0.02, flat=True, max_w=1.4)
    k.collider((1.7, 1.4, 3.4), (0, 0, 1.7), name="Box")


def phone_booth(k: Kit) -> None:
    """A glass telephone booth with a lit TELEPHONE head."""
    w, h = 3.4, 8.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.span("chrome", sx * w / 2 - 0.12 * (1 + sx), sx * w / 2 + 0.12 * (1 - sx), sy * w / 2 - 0.12 * (1 + sy), sy * w / 2 + 0.12 * (1 - sy), 0, h)
    k.span("teal", -w / 2, w / 2, -w / 2, w / 2, 0, 0.3)
    k.span("teal", -w / 2 - 0.1, w / 2 + 0.1, -w / 2 - 0.1, w / 2 + 0.1, h - 1.2, h)
    k.span("chrome", -w / 2 - 0.2, w / 2 + 0.2, -w / 2 - 0.2, w / 2 + 0.2, h, h + 0.2)
    for (a, b, c, e) in ((-w / 2, w / 2, w / 2 - 0.06, w / 2), (-w / 2, -w / 2 + 0.06, -w / 2, w / 2), (w / 2 - 0.06, w / 2, -w / 2, w / 2)):
        k.span("skyblue", a, b, c, e, 0.3, h - 1.2, mat="Glass", transparency=0.6, shadow=False)
    k.span("teal", -w / 2, w / 2, w / 2 - 0.12, w / 2 + 0.02, 0.3, 2.6)
    for yaw, (x, y) in ((0, (0, -w / 2 - 0.12)), (90, (w / 2 + 0.12, 0)), (270, (-w / 2 - 0.12, 0))):
        k.text("cream", "TELEPHONE", (x, y, h - 0.6), 0.5, depth=0.03, yaw=yaw, flat=True, max_w=w - 0.5, mat="Neon", shadow=False)
    k.box("rubber", (1.1, 0.7, 1.6), (0, w / 2 - 0.5, 4.6))
    k.box("chrome", (0.5, 0.2, 0.5), (0, w / 2 - 0.9, 4.9))
    k.wire("rubber", [(0.4, w / 2 - 0.85, 4.2), (0.7, w / 2 - 1.1, 3.2), (0.5, w / 2 - 0.9, 3.9)], r=0.05, verts=3)
    k.box("walnut", (1.6, 0.9, 0.12), (0, w / 2 - 0.55, 3.5))
    k.collider((w, w, h), (0, 0, h / 2), name="Booth")


def sandwich_board(k: Kit, lines=("TODAY", "PIE 15"), body: str = "cream", ink: str = "rust") -> None:
    """An A-board on the pavement: two leaning panels, a line of lettering and a price on each."""
    lean = 14.0
    c, sn = math.cos(math.radians(lean)), math.sin(math.radians(lean))
    for side, yaw in ((-1, 0), (1, 180)):
        yc = side * 0.46
        k.box("walnut", (2.0, 0.12, 3.2), (0, yc, 1.55), rot=(side * lean, 0, 0))
        k.box(body, (1.7, 0.14, 2.6), (0, yc * 1.02, 1.6), rot=(side * lean, 0, 0))
        for text, t, h, sw in ((lines[0], 0.62, 0.5, ink), (lines[1], -0.28, 0.42, "navy")):
            # a point t up the panel from its centre, just proud of its face
            y = side * (0.469 - t * sn + 0.085 * c)
            z = 1.6 + t * c + 0.085 * sn
            k.text(sw, text, (0, y, z), h, depth=0.02, yaw=yaw, tilt=90 - lean, flat=True, max_w=1.5)
    k.collider((2.0, 1.2, 3.2), (0, 0, 1.6), name="Board")


def flower_tub(k: Kit, seed: int = 1) -> None:
    k.lathe("leather", [(0.9, 0), (1.25, 1.5), (1.35, 1.5), (1.35, 1.7), (1.15, 1.7)], (0, 0, 0), verts=9)
    for zz in (0.4, 1.2):
        k.cyl("gunmetal", 1.0 + zz * 0.22, 0.1, (0, 0, zz), verts=9, caps=(False, False))
    k.blob("leaf", 1.2, (0, 0, 1.9), scale=(1, 1, 0.55), detail=1, jitter=0.1, seed=seed)
    rng = random.Random(seed)
    for i in range(7):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0.2, 0.9)
        k.blob(("signal", "blush", "hazard", "porcelain")[i % 4], 0.28, (math.cos(a) * r, math.sin(a) * r, 2.35 + rng.uniform(0, 0.25)), detail=0, seed=i)
    k.collider((2.6, 2.6, 2.2), (0, 0, 1.1), name="Tub")


def street_sign(k: Kit, a: str = "MAIN ST", b: str = "ELM ST") -> None:
    """A corner's street names: two blades crossed on top of a post."""
    k.pole("steel", 0.14, (0, 0, 0), (0, 0, 9.6), verts=5)
    k.cyl("steel", 0.24, 0.3, (0, 0, 9.7), verts=6)
    for text, yaw, z in ((a, 0, 10.35), (b, 90, 11.3)):
        with k.at((0, 0, z), yaw):
            k.box("forest", (4.8, 0.12, 0.85), (0, 0, 0))
            k.box("porcelain", (4.8, 0.14, 0.06), (0, 0, 0.4))
            k.box("porcelain", (4.8, 0.14, 0.06), (0, 0, -0.4))
            for side, yw in ((-1, 0), (1, 180)):
                k.text("porcelain", text, (0, side * 0.07, 0), 0.46, depth=0.02, yaw=yw, flat=True, max_w=4.2)
    k.sphere("steel", 0.2, (0, 0, 11.9), segs=5, rings=3)
    k.collider((0.6, 0.6, 11.0), (0, 0, 5.5), name="Sign")


def barricade(k: Kit, w: float = 9.0, text: str = "ROAD CLOSED") -> None:
    """A parade barricade: a striped board on two trestles, a lamp on top."""
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.9)
        k.pole("pine", 0.14, (x, -1.1, 0), (x, 0, 3.6), verts=4)
        k.pole("pine", 0.14, (x, 1.1, 0), (x, 0, 3.6), verts=4)
        k.pole("pine", 0.1, (x, -0.7, 1.2), (x, 0.7, 1.2), verts=4)
    k.span("porcelain", -w / 2, w / 2, -0.12, 0.12, 2.5, 3.9)
    n = int(w / 1.1)
    for i in range(n):
        if i % 2 == 0:
            xa = -w / 2 + i * w / n
            for sy in (-1, 1):
                k.prism_y("signal", [(xa, 2.5), (xa + w / n, 2.5), (xa + w / n + 0.8, 3.9), (xa + 0.8, 3.9)] if xa + w / n + 0.8 <= w / 2 else
                          [(xa, 2.5), (w / 2, 2.5), (w / 2, 3.9), (xa + 0.8, 3.9)], sy * 0.13 - 0.015, sy * 0.13 + 0.015)
    k.span("porcelain", -w / 2 + 0.6, w / 2 - 0.6, -0.1, 0.1, 1.0, 1.9)
    for sy, yw in ((-1, 0), (1, 180)):
        k.text("navy", text, (0, sy * 0.11, 1.45), 0.56, depth=0.02, yaw=yw, flat=True, max_w=w - 2.0)
    for sx in (-1, 1):
        k.cyl("gunmetal", 0.3, 0.3, (sx * (w / 2 - 0.9), 0, 4.05), verts=6)
        k.sphere("hazard", 0.36, (sx * (w / 2 - 0.9), 0, 4.45), segs=6, rings=4, mat="Neon", shadow=False)
    k.collider((w, 2.4, 4.2), (0, 0, 2.1), name="Barricade")


def bunting(k: Kit, span: float = 44.0, sag: float = 3.0, n: int = 16, colours=("signal", "porcelain", "teal", "hazard")) -> None:
    """A string of pennants across a street: from (0, 0, 0) to (span, 0, 0), sagging in the middle."""
    prev = (0.0, 0.0, 0.0)
    for i in range(1, n + 1):
        t = i / n
        p = (span * t, 0.0, -sag * 4 * t * (1 - t))
        k.pole("rubber", 0.05, prev, p, verts=3)
        ax, az = prev[0] + (p[0] - prev[0]) * 0.12, prev[2] + (p[2] - prev[2]) * 0.12
        bx, bz = prev[0] + (p[0] - prev[0]) * 0.88, prev[2] + (p[2] - prev[2]) * 0.88
        mx, mz = (ax + bx) / 2, (az + bz) / 2 - span / n * 0.95
        sw = colours[i % len(colours)]
        k.add(sw, [(ax, -0.03, az), (bx, -0.03, bz), (mx, -0.03, mz), (ax, 0.03, az), (bx, 0.03, bz), (mx, 0.03, mz)], [(0, 1, 2), (5, 4, 3)], shadow=False)
        prev = p


def _wheel(k: Kit, x: float, y: float, r: float = 1.25, w: float = 0.8) -> None:
    k.cyl("rubber", r, w, (x, y, r), rot=(0, 90, 0), verts=12)
    k.cyl("porcelain", r * 0.74, w + 0.06, (x, y, r), rot=(0, 90, 0), verts=10)
    k.cyl("chrome", r * 0.42, w + 0.14, (x, y, r), rot=(0, 90, 0), verts=8)


def car_sedan(k: Kit, paint: str = "tint", roof: str = "porcelain", shown: str = "teal") -> None:
    """A two-tone 1950s sedan, 17 studs long, nose to -Y: pontoon wings, a hood ridge, tail fins, a
    chrome grin. The body is its own part on the tint swatch (Role Paint): the builder colours each one."""
    hw = 3.1
    kw = dict(part="Paint", role="Paint", tint=shown) if paint == "tint" else {}
    # the body between the wings, the hood's ridge, the boot
    k.prism_x(paint, [(-8.3, 1.5), (-8.4, 2.5), (-7.9, 3.3), (-3.2, 3.7), (3.6, 3.65), (7.9, 3.7), (8.4, 3.2), (8.45, 2.4), (8.2, 1.5), (6.6, 1.1), (-6.9, 1.1)],
              -hw, hw, **kw)
    k.prism_x(paint, [(-8.2, 3.25), (-7.6, 3.62), (-3.1, 4.0), (-3.1, 3.66)], -1.5, 1.5, **kw)
    k.box("chrome", (0.14, 4.6, 0.1), (0, -5.5, 3.86), rot=(4.5, 0, 0))
    k.prism_x("chrome", [(-8.25, 3.4), (-7.5, 3.75), (-7.0, 3.95), (-7.7, 3.6)], -0.09, 0.09)          # the mascot
    for sx in (-1, 1):
        xa, xb = (sx * hw - 0.02, sx * (hw + 0.42)) if sx > 0 else (sx * (hw + 0.42), sx * hw + 0.02)
        # the front wing: a pontoon over the wheel, its lamp in a chrome ring
        k.prism_x(paint, [(-8.5, 1.55), (-8.62, 2.7), (-8.0, 3.62), (-5.5, 3.92), (-2.9, 3.62), (-2.4, 2.9), (-2.4, 1.3), (-3.9, 1.3), (-4.2, 2.3), (-5.4, 2.75),
                          (-6.6, 2.3), (-6.9, 1.3)], xa, xb, **kw)
        # the rear wing, rising to a fin
        k.prism_x(paint, [(2.4, 1.3), (2.4, 3.0), (3.4, 3.72), (6.4, 3.95), (8.7, 4.75), (8.72, 2.6), (8.3, 1.55), (6.9, 1.3), (6.6, 2.3), (5.4, 2.75), (4.2, 2.3),
                          (3.9, 1.3)], xa, xb, **kw)
        k.box("chrome", (0.1, 4.6, 0.14), (sx * (hw + 0.45), 0.0, 2.95))                                # the side spear
        k.box(roof, (0.08, 4.4, 0.62), (sx * (hw + 0.02), 0.0, 2.45))                                   # the two-tone flash on the doors
        k.cyl("chrome", 0.56, 0.36, (sx * (hw - 0.45), -8.38, 2.95), rot=(90, 0, 0), verts=10)
        k.cyl("cream", 0.43, 0.4, (sx * (hw - 0.45), -8.43, 2.95), rot=(90, 0, 0), verts=8, mat="Neon", shadow=False)
        k.cyl("rust", 0.3, 0.5, (sx * (hw + 0.2), 8.5, 3.9), rot=(90, 0, 0), verts=7, mat="Neon", shadow=False)
        k.cyl("chrome", 0.38, 0.36, (sx * (hw + 0.2), 8.46, 3.9), rot=(90, 0, 0), verts=7)
        _wheel(k, sx * (hw - 0.02), -5.4)
        _wheel(k, sx * (hw - 0.02), 5.4)
        k.box("gunmetal", (0.05, 0.08, 1.9), (sx * (hw + 0.01), 1.0, 2.5))                               # the door's seam
        k.box("chrome", (0.1, 0.5, 0.1), (sx * (hw + 0.06), 0.2, 3.1))                                  # its handle
    # the cabin: glass under a rounded roof, pillars, a split screen
    k.prism_x("skyblue", [(-3.0, 3.66), (-1.7, 5.7), (3.4, 5.8), (5.5, 3.66)], -hw + 0.3, hw - 0.3, mat="Glass", transparency=0.45, shadow=False)
    k.prism_x(roof, [(-2.0, 5.6), (-1.5, 5.98), (0.8, 6.16), (3.1, 6.06), (3.8, 5.72)], -hw + 0.2, hw - 0.2)
    for sx in (-1, 1):
        for (ya, yb) in ((-2.95, -1.75), (1.0, 1.0), (5.4, 3.55)):
            k.pole(roof, 0.14, (sx * (hw - 0.3), ya, 3.66), (sx * (hw - 0.3), yb, 5.7), verts=4)
        k.box(roof, (0.12, 8.3, 0.16), (sx * (hw - 0.3), 1.2, 3.72))
    k.pole("chrome", 0.07, (0, -3.0, 3.7), (0, -1.75, 5.7), verts=3)
    # chrome: bumpers with overriders, the grille's grin, the number plates
    for y, z in ((-8.85, 1.75), (8.85, 1.85)):
        k.box("chrome", (2 * hw + 1.0, 0.5, 0.55), (0, y, z))
        for sx in (-1, 1):
            k.box("chrome", (0.5, 0.75, 0.95), (sx * 1.8, y - (0.1 if y < 0 else -0.1), z + 0.12))
        k.box("cream", (1.5, 0.08, 0.6), (0, y - (0.27 if y < 0 else -0.27), z + 0.02))
    k.box("chrome", (4.3, 0.3, 0.95), (0, -8.42, 2.62))
    for i in range(5):
        k.box("gunmetal", (4.1, 0.34, 0.07), (0, -8.44, 2.27 + i * 0.17))
    k.box("chrome", (3.4, 0.1, 0.12), (0, 8.5, 3.0))
    k.box("basalt", (2 * hw - 1.2, 15.0, 0.4), (0, 0, 1.15))
    k.collider((2 * hw + 0.9, 17.6, 5.6), (0, 0, 2.8), name="Car")


def pickup(k: Kit, paint: str = "tint", shown: str = "leaf") -> None:
    """A farm pickup, 17 studs long, nose to -Y: a round-nosed cab, running boards, a wooden bed with
    crates in it. Role Paint as the sedan."""
    hw = 3.0
    kw = dict(part="Paint", role="Paint", tint=shown) if paint == "tint" else {}
    k.prism_x(paint, [(-8.2, 1.5), (-8.3, 2.7), (-7.7, 3.8), (-3.4, 4.25), (-3.4, 1.3)], -hw + 0.5, hw - 0.5, **kw)                 # the hood
    k.prism_x(paint, [(-3.4, 1.3), (-3.4, 4.25), (-2.5, 6.5), (-1.6, 6.85), (1.0, 6.85), (1.6, 6.5), (1.6, 1.3)], -hw, hw, **kw)      # the cab
    k.prism_x("skyblue", [(-3.2, 4.45), (-2.5, 6.25), (1.2, 6.3), (1.2, 4.45)], -hw - 0.04, hw + 0.04, mat="Glass", transparency=0.45, shadow=False)
    k.box("skyblue", (2 * hw - 0.9, 0.1, 1.75), (0, -2.92, 5.38), rot=(-22, 0, 0), mat="Glass", transparency=0.45, shadow=False)
    k.box("skyblue", (2 * hw - 1.6, 0.1, 1.2), (0, 1.62, 5.5), mat="Glass", transparency=0.45, shadow=False)
    for sx in (-1, 1):
        xa, xb = (sx * (hw - 0.55), sx * (hw + 0.4)) if sx > 0 else (sx * (hw + 0.4), sx * (hw - 0.55))
        k.prism_x(paint, [(-8.4, 1.5), (-8.5, 2.5), (-7.6, 3.5), (-5.3, 3.8), (-3.2, 3.2), (-2.6, 1.9), (-3.7, 1.3), (-4.0, 2.4), (-5.3, 2.9), (-6.6, 2.4), (-6.9, 1.3)],
                  xa, xb, **kw)                                                                                                  # the front wing
        xa, xb = (sx * hw - 0.02, sx * (hw + 0.4)) if sx > 0 else (sx * (hw + 0.4), sx * hw + 0.02)
        k.prism_x(paint, [(3.4, 1.3), (3.7, 2.6), (5.4, 3.3), (7.1, 2.6), (7.4, 1.3), (6.9, 1.3), (6.6, 2.3), (5.4, 2.8), (4.2, 2.3), (3.9, 1.3)], xa, xb, **kw)   # rear
        k.box("gunmetal", (0.9, 5.4, 0.16), (sx * (hw + 0.2), -0.4, 1.3))                                                        # running board
        k.cyl("chrome", 0.52, 0.5, (sx * (hw - 0.1), -8.25, 3.0), rot=(90, 0, 0), verts=10)
        k.cyl("cream", 0.4, 0.54, (sx * (hw - 0.1), -8.3, 3.0), rot=(90, 0, 0), verts=8, mat="Neon", shadow=False)
        k.box("rust", (0.4, 0.2, 0.5), (sx * (hw - 0.3), 8.5, 2.6), mat="Neon", shadow=False)
        _wheel(k, sx * (hw - 0.02), -5.3, r=1.4)
        _wheel(k, sx * (hw - 0.02), 5.4, r=1.4)
        k.box("gunmetal", (0.05, 0.08, 2.6), (sx * (hw + 0.01), -1.0, 3.0))
        k.box("chrome", (0.1, 0.5, 0.1), (sx * (hw + 0.06), -0.2, 4.0))
    for (a, b, c, e) in ((-hw, -hw + 0.25, 1.75, 8.4), (hw - 0.25, hw, 1.75, 8.4), (-hw, hw, 8.15, 8.4), (-hw, hw, 1.75, 2.0)):       # the bed's sides
        k.span(paint, a, b, c, e, 1.6, 3.9, **kw)
    for sx in (-1, 1):                                                                                                           # stake rails
        for y in (2.6, 5.1, 7.6):
            k.span("pine", sx * hw - 0.12 * (1 + sx), sx * hw + 0.12 * (1 - sx), y - 0.15, y + 0.15, 3.9, 5.2)
        k.span("pine", sx * hw - 0.1 * (1 + sx), sx * hw + 0.1 * (1 - sx), 2.0, 8.3, 4.5, 4.85)
    k.span("walnut", -hw + 0.25, hw - 0.25, 2.0, 8.15, 1.6, 1.85)
    for i, (x, y, s_) in enumerate(((-1.3, 3.4, 1.9), (1.2, 3.7, 1.7), (-0.3, 6.1, 2.0))):                                          # the load: crates
        k.box("pine", (s_, s_, s_), (x, y, 1.85 + s_ / 2), rot=(0, 0, i * 17))
        k.box("walnut", (s_ + 0.06, 0.2, s_ + 0.06), (x, y, 1.85 + s_ / 2), rot=(0, 0, i * 17))
    for y, z in ((-8.7, 1.7), (8.75, 1.8)):
        k.box("chrome", (2 * hw + 0.9, 0.45, 0.5), (0, y, z))
    k.box("chrome", (3.2, 0.3, 1.5), (0, -8.2, 2.95))
    for i in range(6):
        k.box("gunmetal", (0.1, 0.34, 1.3), (-1.25 + i * 0.5, -8.22, 2.95))
    k.box("basalt", (2 * hw - 1.2, 15.0, 0.4), (0, 0, 1.2))
    k.collider((2 * hw + 0.8, 17.4, 6.8), (0, 0, 3.4), name="Truck")
