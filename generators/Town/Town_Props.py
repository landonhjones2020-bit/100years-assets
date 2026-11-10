"""Town_Props: Brightwater's free-standing pieces, each an asset of its own (A9 and the town
rebuild; bible Sections 12 and 21). Built on townkit and props.py.

    python3 generators/Town/Town_Props.py CarSedan       # one asset: Town_CarSedan
    python3 generators/Town/Town_Props.py                # all of them

The cars' bodies are their own MeshPart, Paint (Role Paint, on the tint swatch): whoever places
one sets that part's Color. The bunting is 68 studs from end to end (building line to building
line across Main Street); stretch its length to hang it at an angle.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import props as P  # noqa: E402
import townkit as T  # noqa: E402


def car_sedan(k):
    P.car_sedan(k)
    k.socket("Centre", (0, 0, 0))
    return {"views": [("front", (-13, -17, 6.5), (0, -1, 2.6), 46), ("rear", (13, 18, 7.5), (0, 1, 2.6), 46)]}


def car_pickup(k):
    P.pickup(k)
    return {"views": [("front", (-13, -17, 7), (0, -1, 3), 46), ("rear", (13, 18, 8), (0, 1, 3), 46)]}


def bunting(k):
    P.bunting(k, span=68.0, sag=5.0, n=26)
    return {"views": [("across", (34, -58, 4), (34, 0, -3), 64)]}


def barricade(k):
    P.barricade(k)
    return {"views": [("front", (-7, -11, 5), (0, 0, 2.2), 50)]}


def tree_big(k):
    """A full-grown shade tree, 30 studs: the hills and back yards behind Main Street."""
    with k.at((0, 0, 0), 0, scale=2.0):
        P.tree(k, seed=4, h=15.0, grate=False)
    return {"views": [("side", (0, -52, 14), (0, 0, 15), 46)]}


def conifer(k, seed=2, h=34.0):
    rng = random.Random(seed)
    k.pole("walnut", 0.9, (0, 0, 0), (0, 0, h * 0.3), verts=6, r_top=0.6)
    tiers = 5
    for i in range(tiers):
        t = i / (tiers - 1)
        z0 = h * (0.16 + 0.17 * i)
        r = h * 0.24 * (1.0 - 0.72 * t)
        k.lathe(("forest", "olive")[i % 2] if i < tiers - 1 else "forest", [(r * 0.25, 0.0), (r, -0.6), (r * 0.82, 0.8), (r * 0.3, h * 0.2), (0.0, h * 0.27 if i == tiers - 1 else h * 0.22)],
                (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), z0), verts=7, rot=(0, 0, rng.uniform(0, 50)), smooth=-1)
    k.collider((2.0, 2.0, h * 0.3), (0, 0, h * 0.15), name="Tree")


def tree_pine(k):
    conifer(k)
    return {"views": [("side", (0, -56, 16), (0, 0, 17), 46)]}


def tree_clump(k):
    """Five trees as one mesh: the far side of town is these, a few dozen times."""
    rng = random.Random(7)
    spots = [(-22, 3, 1.9, "t"), (-9, -4, 2.2, "t"), (3, 6, 1.0, "p"), (14, -2, 2.0, "t"), (25, 4, 0.85, "p")]
    for i, (x, y, s, kind) in enumerate(spots):
        with k.at((x, y, 0), rng.uniform(0, 360), scale=s):
            if kind == "t":
                P.tree(k, seed=10 + i * 3, h=rng.uniform(13.5, 16.5), grate=False)
            else:
                conifer(k, seed=i, h=rng.uniform(30, 36))
    k.colliders.clear()
    return {"views": [("side", (0, -80, 16), (0, 0, 15), 50)]}


def hill(k):
    """A low green hill, 200 studs across and 40 high: stretch it. Flat-shaded like the trees."""
    k.blob("leaf", 100.0, (0, 0, -6.0), scale=(1.0, 0.8, 0.46), detail=2, jitter=0.05, seed=3)
    return {"views": [("side", (0, -260, 50), (0, 0, 14), 50)]}


def water_tower(k):
    """Brightwater's water tower: a riveted tank on six legs, the town's name round it. 74 studs."""
    r, zb, zt = 12.0, 44.0, 60.0
    legs = 6
    for i in range(legs):
        a = math.radians(i * 360 / legs + 30)
        foot = (math.cos(a) * 17.0, math.sin(a) * 17.0, 0.0)
        top = (math.cos(a) * 11.2, math.sin(a) * 11.2, zb + 2.0)
        k.pole("steel", 0.55, foot, top, verts=5, r_top=0.42)
        k.box("stone", (2.6, 2.6, 0.9), (foot[0], foot[1], 0.45), rot=(0, 0, math.degrees(a)))
        b = math.radians((i + 1) * 360 / legs + 30)
        for (z0, z1) in ((1.0, 14.0), (15.0, 29.0), (30.0, 43.0)):
            def at(ang, z):
                rr = 17.0 + (11.2 - 17.0) * z / (zb + 2.0)
                return (math.cos(ang) * rr, math.sin(ang) * rr, z)
            k.pole("steel", 0.12, at(a, z0), at(b, z1), verts=3)
            k.pole("steel", 0.12, at(b, z0), at(a, z1), verts=3)
            k.pole("steel", 0.2, at(a, z1 + 0.5), at(b, z1 + 0.5), verts=4)
    k.cyl("steel", 1.7, zb, (0, 0, zb / 2), verts=8)
    k.cyl("stone", 3.0, 1.0, (0, 0, 0.5), verts=8)
    # the tank: a bowl, a drum of plates, a cone and a ball on top
    k.lathe("cream", [(0.0, zb - 4.5), (5.0, zb - 3.8), (9.6, zb - 1.6), (r, zb + 2.2), (r, zt), (r - 0.6, zt + 0.5)], (0, 0, 0), verts=18, smooth=50)
    k.lathe("teal", [(r + 0.5, zt - 0.2), (r + 0.5, zt + 0.5), (6.5, zt + 4.6), (0.0, zt + 7.4)], (0, 0, 0), verts=18, smooth=50)
    k.sphere("chrome", 0.7, (0, 0, zt + 7.9), segs=6, rings=4)
    k.pole("chrome", 0.08, (0, 0, zt + 8.4), (0, 0, zt + 11.5), verts=3)
    for z in (zb + 2.6, zt - 1.6):
        k.cyl("teal", r + 0.12, 1.1, (0, 0, z), verts=18, caps=(False, False))
    for i in range(18):
        a = math.radians(i * 20 + 10)
        k.box("ash", (0.18, 0.1, zt - zb - 5.6), (math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), (zb + zt) / 2 + 0.5), rot=(0, 0, math.degrees(a) + 90))
    # the catwalk and its rail
    k.cyl("gunmetal", r + 2.4, 0.3, (0, 0, zb + 1.9), verts=18)
    k.cyl("gunmetal", r + 2.3, 0.18, (0, 0, zb + 5.0), verts=18, caps=(False, False))
    k.cyl("gunmetal", r + 2.3, 0.12, (0, 0, zb + 3.5), verts=18, caps=(False, False))
    for i in range(18):
        a = math.radians(i * 20)
        k.pole("gunmetal", 0.1, (math.cos(a) * (r + 2.3), math.sin(a) * (r + 2.3), zb + 2.0), (math.cos(a) * (r + 2.3), math.sin(a) * (r + 2.3), zb + 5.0), verts=3)
    # a ladder up one leg and up the tank
    a = math.radians(30)
    for sx in (-0.5, 0.5):
        p0 = (math.cos(a) * 17.6 - math.sin(a) * sx, math.sin(a) * 17.6 + math.cos(a) * sx, 0.0)
        p1 = (math.cos(a) * 14.6 - math.sin(a) * sx, math.sin(a) * 14.6 + math.cos(a) * sx, zb + 2.0)
        k.pole("gunmetal", 0.08, p0, p1, verts=3)
    # the town's name, a letter at a time round the drum, on both sides
    name = "BRIGHTWATER"
    step = 9.4
    for facing in (0.0, 180.0):
        for i, ch in enumerate(name):
            ang = facing + (i - (len(name) - 1) / 2) * step
            ar = math.radians(ang)
            k.text("navy", ch, (math.sin(ar) * (r + 0.1), -math.cos(ar) * (r + 0.1), zb + 9.6), 3.1, depth=0.04, yaw=ang, flat=True, font="Oswald-Bold")
    k.collider((36.0, 36.0, 2.0), (0, 0, 1.0), name="Tower")
    return {"views": [("town", (30, -120, 22), (0, 0, 40), 50), ("near", (16, -44, 30), (0, 0, 52), 50)]}


def welcome_banner(k):
    """The banner over Main Street: WELCOME TO BRIGHTWATER on canvas between two poles, 68 studs apart."""
    span, z = 68.0, 22.0
    for sx in (-1, 1):
        x = sx * span / 2
        k.lathe("gunmetal", [(0.9, 0), (0.9, 0.5), (0.5, 1.2), (0.36, 2.6)], (x, 0, 0), verts=8)
        k.pole("gunmetal", 0.3, (x, 0, 2.4), (x, 0, z + 5.2), verts=6, r_top=0.2)
        k.sphere("brass", 0.42, (x, 0, z + 5.5), segs=6, rings=4)
        k.collider((1.6, 1.6, 12.0), (x, 0, 6.0), name="Pole")
    w, h = 52.0, 6.4
    k.span("cream", -w / 2, w / 2, -0.06, 0.06, z - h / 2, z + h / 2)
    for zz in (z - h / 2, z + h / 2 - 0.5):
        k.span("signal", -w / 2, w / 2, -0.08, 0.08, zz, zz + 0.5)
    for sx in (-1, 1):
        for zz in (z - h / 2 + 0.2, z + h / 2 - 0.2):
            k.pole("rubber", 0.06, (sx * w / 2, 0, zz), (sx * span / 2, 0, zz + (1.6 if zz > z else -0.6)), verts=3)
    for side, yaw in ((-1, 0), (1, 180)):
        k.text("teal", "WELCOME TO", (0, side * 0.09, z + 1.75), 1.25, depth=0.03, yaw=yaw, flat=True, font="Oswald-Bold", spacing=1.2)
        k.text("navy", "BRIGHTWATER", (0, side * 0.09, z - 0.75), 2.9, depth=0.03, yaw=yaw, flat=True, font="AlfaSlabOne-Regular", max_w=w - 6.0)
        for sx in (-1, 1):
            with k.at((sx * (w / 2 - 3.2), side * 0.1, z), yaw):
                for i in range(8):                                     # a little sunburst either end
                    a = math.radians(i * 45)
                    k.box("hazard", (0.22, 0.03, 1.5), (math.sin(a) * 1.25, 0, math.cos(a) * 1.25), rot=(0, -math.degrees(a), 0))
                k.cyl("signal", 0.72, 0.04, (0, 0, 0), rot=(90, 0, 0), verts=10)
    return {"views": [("street", (0, -70, 8), (0, 0, 19), 60)]}


ASSETS = {
    "CarSedan": (car_sedan, 1800), "CarPickup": (car_pickup, 1800), "Bunting": (bunting, 400), "Barricade": (barricade, 900),
    "TreeBig": (tree_big, 400), "TreePine": (tree_pine, 300), "TreeClump": (tree_clump, 1400), "Hill": (hill, 400),
    "WaterTower": (water_tower, 3000), "WelcomeBanner": (welcome_banner, 2500),
}

if __name__ == "__main__":
    for name in (sys.argv[1:] or list(ASSETS)):
        fn, budget = ASSETS[name]

        def build(k, fn=fn):
            out = fn(k) or {}
            return out
        kw = {"ground": None} if name == "Bunting" else {}        # it hangs below its ends: no floor in its picture
        T.run(build, f"Town_{name}", "Town", budget=budget, res=(800, 520), **kw)
