"""Prop_Nest: a monster nest dug into (bible Section 6: "Nest: monsters pour out at once;
destroying it pays well"). Prompt 14: DigService puts one at the back of the dug cell, makes it a
combatant (Tuning.Digging.NestHealth) and a breach point, and adds Disturbance every cycle
until it is destroyed.

A hive grown out of the rock by something from the Deep: a lumpy plum mound mottled with
basalt, a tall chimney behind it crowned with cream spines round a glowing vent, a fanged maw
at the front with a Source-green heart bulging out of it, cream ribs arching over the mound
like a cage, glowing eggs strapped down by dark sinew, Source veins crawling from the maw to
the eggs, and dark roots creeping out across the floor with glowing buds. Never gory: the
horror is the shape, the teeth and the light.

Pivot = bottom centre. The maw faces Blender -Y (the room). The mound and the chimney collide
(hull) and take hits; everything else is decoration.

Run:  SF_EXPORT=1 python3 generators/Props/Prop_Nest.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Monsters"))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402
import steadfast as sf  # noqa: E402
from _beast import blob, claw, spike  # noqa: E402

ASSET, CATEGORY = "Prop_Nest", "Props"
BUDGET = 3000   # a feature that fills a dug cell's back: the room-furniture budget (bible Section 19)

CENTRE = Vector((0.0, 0.5, 0.0))
RADII = Vector((4.3, 3.3, 3.1))
MAW = Vector((0.0, -2.62, 1.45))
SCALE = 1.2


def cut_below(obj, z=0.0):
    """Drops everything under the floor (the mound sits on it)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z - obj.location.z), plane_no=(0, 0, 1),
                           clear_inner=True, clear_outer=False)
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def surf(theta, elev, out=0.0):
    """A point on the mound's surface: theta degrees round from the front (-Y), elev up from the
    floor; out pushes it off the surface along the normal."""
    t, e = math.radians(theta), math.radians(elev)
    d = Vector((math.sin(t) * math.cos(e), -math.cos(t) * math.cos(e), math.sin(e)))
    p = CENTRE + Vector((RADII.x * d.x, RADII.y * d.y, RADII.z * d.z))
    n = Vector((d.x / RADII.x, d.y / RADII.y, d.z / RADII.z)).normalized()
    return p + n * out, n


def mottle(obj, seed, dark="basalt", share=0.25, accent=None, accent_share=0.0, grime=0.0):
    """Some faces darker (and a few in an accent), and every face under `grime` studs dark, so
    the hive looks grown up out of the dirt."""
    rnd = random.Random(seed)
    picks = {}

    def pick(c):
        key = (round(c.x, 2), round(c.y, 2), round(c.z, 2))
        if key not in picks:
            r = rnd.random()
            if c.z + obj.location.z < grime:
                picks[key] = "dark"
            else:
                picks[key] = "accent" if r < accent_share else ("dark" if r < accent_share + share else "")
        return picks[key]
    sf.paint(obj, dark, lambda c, n: pick(c) == "dark")
    if accent:
        sf.paint(obj, accent, lambda c, n: pick(c) == "accent")


def build():
    rnd = random.Random(14)

    # the mound and the chimney behind it: lumpy plum, mottled darker
    mound = blob(1.0, CENTRE, scale=tuple(RADII), segs=14, rings=9, noise=0.28, seed=5, name="Mound")
    cut_below(mound)
    sf.tag(mound, "Mound", "plum", collision="hull", smooth_angle=50)
    mottle(mound, 21, share=0.12, accent="rubber", accent_share=0.05, grime=0.75)
    chimney = blob(1.0, (0.5, 1.4, 2.2), scale=(1.7, 1.6, 2.7), segs=12, rings=8, noise=0.22, seed=8, name="Chimney")
    sf.tag(chimney, "Mound", "plum", collision="hull", smooth_angle=50)
    mottle(chimney, 22, share=0.12, accent="rubber", accent_share=0.05)
    # the vent on top: a glowing pool in a dark lip, crowned with cream spines
    top = Vector((0.5, 1.4, 4.78))
    sf.tag(sf.torus(0.62, 0.22, loc=top, major_segs=10, minor_segs=4), "Mound", "basalt", collision="none")
    sf.tag(blob(0.55, top + Vector((0, 0, -0.02)), scale=(1, 1, 0.45), segs=10, rings=5),
           "Glow", "glow", "Neon", collision="none", cast_shadow=False)
    for k in range(7):
        a = math.radians(k * 360 / 7 + 10)
        base = top + Vector((0.75 * math.cos(a), 0.75 * math.sin(a), -0.15))
        out = Vector((math.cos(a), math.sin(a), 0))
        sf.tag(spike(base, out * 0.45 + Vector((0, 0, 1)), rnd.uniform(0.9, 1.5), 0.16, verts=5), "Bone", "cream")

    # the maw: a dark fanged ring, the glowing heart bulging out of it
    sf.tag(sf.torus(1.12, 0.36, loc=MAW, rot=(90, 0, 0), major_segs=12, minor_segs=4), "Maw", "basalt", collision="none")
    sf.tag(sf.cyl(1.0, 0.3, loc=MAW + Vector((0, 0.35, 0)), rot=(90, 0, 0), verts=12, bevel=0.0), "Maw", "rubber", collision="none")
    sf.tag(blob(0.78, MAW + Vector((0, -0.05, 0)), scale=(1, 0.8, 1), segs=12, rings=8, noise=0.04, seed=3),
           "Heart", "glow", "Neon", collision="none", cast_shadow=False)
    for k in range(10):
        a = math.radians(k * 36 + 8)
        rim = MAW + Vector((1.05 * math.cos(a), -0.2, 1.05 * math.sin(a)))
        inward = Vector((-math.cos(a), -0.55, -math.sin(a)))
        sf.tag(spike(rim, inward, rnd.uniform(0.55, 0.85), 0.13, verts=4), "Bone", "cream")
    # two big tusks either side of the maw, curling forward and in
    for sx in (-1, 1):
        base = MAW + Vector((sx * 1.5, 0.05, -0.55))
        sf.tag(claw(base, (sx * 0.35, -1.0, -0.25), 1.9, 0.24, bend=(-sx, -0.2, 0.6), curl=0.55, sides=6, resolution=1),
               "Bone", "cream")

    # ribs arching up out of the mound and over it, like a cage
    for theta, elev, length in ((-62, 18, 3.6), (62, 18, 3.6), (-105, 14, 3.9), (105, 14, 3.9), (-150, 16, 3.2), (150, 16, 3.2)):
        p, n = surf(theta, elev, -0.1)
        up = Vector((0, 0, 1))
        direction = (n * 0.55 + up).normalized()
        inward = Vector((-n.x, -n.y, 0.15)).normalized()
        sf.tag(claw(p, direction, length, 0.26, bend=inward, curl=0.8, sides=6, resolution=1), "Bone", "cream")
    # small spines on the mound
    for theta, elev in ((-35, 62), (28, 66), (-80, 45), (82, 48), (-125, 40), (130, 42), (175, 35), (-175, 50)):
        p, n = surf(theta, elev, -0.05)
        sf.tag(spike(p, n + Vector((0, 0, 0.4)), rnd.uniform(0.45, 0.8), 0.13, verts=4), "Bone", "cream")

    # eggs: glowing, held down by dark sinew straps
    for theta, elev, r in ((-48, 14, 0.82), (52, 22, 0.75), (-88, 30, 0.7), (92, 12, 0.85), (-20, 52, 0.62), (128, 34, 0.66)):
        p, n = surf(theta, elev, r * 0.55)
        egg = blob(r, p, scale=(0.85, 0.85, 1.12), segs=8, rings=6, noise=0.03, seed=int(theta + 400))
        egg.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
        sf.tag(egg, "Eggs", "glow", "Neon", collision="none", cast_shadow=False)
        side = n.cross(Vector((0, 0, 1)))
        if side.length < 0.1:
            side = Vector((1, 0, 0))
        side.normalize()
        a, b = p - side * r * 0.95 - n * r * 0.4, p + side * r * 0.95 - n * r * 0.4
        mid = p + n * r * 0.98
        sf.tag(sf.tube([tuple(a), tuple((a + mid) / 2 + n * r * 0.42), tuple(mid), tuple((b + mid) / 2 + n * r * 0.42), tuple(b)],
                       [0.1] * 5, sides=4, resolution=1, name="Sinew"), "Sinew", "rubber")

    # Source veins from the maw over the mound
    for th1, el1, th2, el2 in ((-12, 34, -46, 20), (14, 36, 50, 26), (0, 46, -20, 58), (-8, 20, -84, 30), (10, 18, 90, 16)):
        pts = []
        for i in range(5):
            f = i / 4
            th = th1 + (th2 - th1) * f + math.sin(f * math.pi * 2) * 5
            el = el1 + (el2 - el1) * f
            pts.append(tuple(surf(th, el, 0.04)[0]))
        sf.tag(sf.tube(pts, [0.09, 0.08, 0.07, 0.06, 0.05], sides=4, resolution=1, name="Veins"), "Veins", "glow", "Neon",
               collision="none", cast_shadow=False)

    # roots creeping across the floor, with glowing buds
    for k, theta in enumerate((-35, 30, -75, 72, -120, 118, 165)):
        p, n = surf(theta, 3, -0.2)
        flat = Vector((n.x, n.y, 0)).normalized()
        side = Vector((-flat.y, flat.x, 0))
        reach = rnd.uniform(2.0, 3.4)
        pts, radii = [], []
        for i in range(5):
            f = i / 4
            q = p + flat * reach * f + side * math.sin(f * 3.0 + k) * 0.5
            radius = 0.34 * (1 - f) + 0.05
            pts.append((q.x, q.y, radius * 0.8))
            radii.append(radius)
        sf.tag(sf.tube(pts, radii, sides=4, resolution=2, name="Roots"), "Roots", "plum")
        if k % 2 == 0:
            end = Vector(pts[-1])
            sf.tag(sf.sphere(0.17, loc=end + Vector((0, 0, 0.1)), segs=6, rings=4), "Buds", "glow", "Neon",
                   collision="none", cast_shadow=False)

    # rubble from the dig round the base
    for k, (theta, d) in enumerate(((-140, 0.6), (35, 0.7), (-28, 0.9), (160, 0.5))):
        p, n = surf(theta, 2, 0.4)
        rock = blob(d, (p.x, p.y, d * 0.45), scale=(1.2, 1.0, 0.75), segs=6, rings=4, noise=0.18, seed=70 + k)
        sf.tag(rock, "Rubble", "stone", smooth_angle=None)
        mottle(rock, 80 + k, dark="basalt", share=0.3)
    for o in bpy.context.scene.objects:   # the whole hive a size up, about the pivot
        if o.get("sf_part"):
            o.location = o.location * SCALE
            o.scale = o.scale * SCALE
    return {"export": {
        "budget": BUDGET, "step": "P14", "pivot": (0.0, 0.0, 0.0),
        "meta": {"kind": "Prop", "feature": "Nest"},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
