"""Shared parts for the A2 weapons, tools and throwables (Prompt 20).

Conventions (the A0 weapons'): Blender -Y is the front (the muzzle, the head), +Y runs back
toward the shooter, Z is up, X is the side. The pivot is the grip, where the right hand closes,
so the Tool's grip offset is zero. Held weapons use collision "query".

Two-handed guns share one hold (generators/Clips/R15_LongGuns.py): the left hand's Support socket
sits SUPPORT ahead of the Grip, so a single RifleHold/RifleAim pair fits every long gun. One stud:
a classic R15 arm is short for its shoulders (about 1.9 studs from shoulder to palm, shoulders 2
apart), so the left hand can't reach further with the gun at the right side, even with the torso
bladed 45 degrees.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402

Q = "query"
# the left hand's place on every two-handed gun, from the Grip: 1 forward, 0.2 up
SUPPORT = (0.0, -1.0, 0.2)


def support_from(grip):
    return (grip[0] + SUPPORT[0], grip[1] + SUPPORT[1], grip[2] + SUPPORT[2])


def t(obj, part, swatch, mat="SmoothPlastic", collision=Q, **kw):
    return sf.tag(obj, part, swatch, mat, collision=collision, **kw)


def side(points, thickness, x0=None, bevel=0.04, segments=1):
    """A slab from a side profile [(y, z), ...], centred on X unless x0 is given."""
    x0 = -thickness / 2 if x0 is None else x0
    return sf.profile_slab(points, thickness, loc=(x0, 0, 0), rot=(90, 0, 90), bevel=bevel, segments=segments)


def grown(points, d):
    cy = sum(p[0] for p in points) / len(points)
    cz = sum(p[1] for p in points) / len(points)
    out = []
    for y, z in points:
        vy, vz = y - cy, z - cz
        n = math.hypot(vy, vz) or 1.0
        out.append((y + vy / n * d, z + vz / n * d))
    return out


def moved(points, dy, dz, scale=1.0):
    return [(y * scale + dy, z * scale + dz) for y, z in points]


# The Pocket Pistol's raked grip (A0, after Landon's note on handles), around its own origin:
# the hand closes at (0.28, 0.15) of this outline.
PISTOL_GRIP = [(0.00, 0.44), (0.03, 0.24), (0.09, 0.02), (0.16, -0.20), (0.22, -0.38), (0.25, -0.45),
               (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.56, -0.20), (0.49, 0.04), (0.43, 0.26),
               (0.41, 0.40), (0.47, 0.48), (0.40, 0.53), (0.10, 0.50)]
PISTOL_HAND = (0.28, 0.15)


def pistol_grip(part, grip, frame="gunmetal", panel="rubber", scale=1.0, medallion="brass", width=0.27):
    """A raked pistol grip whose hand point lands on `grip` (x, y, z)."""
    dy = grip[1] - PISTOL_HAND[0] * scale
    dz = grip[2] - PISTOL_HAND[1] * scale
    pts = moved(PISTOL_GRIP, dy, dz, scale)
    if frame:
        t(side(grown(pts, 0.025), width * 0.6), part, frame)
    t(side(pts, width), part, panel)
    if medallion:
        for sx in (-1, 1):
            t(sf.cyl(0.05 * scale, 0.03, loc=(sx * width / 2, grip[1] + 0.02, grip[2] - 0.03), rot=(0, 90, 0), verts=10, bevel=0.0),
              part, medallion)
    return pts


def barrel(part, r, y_front, y_back, z, swatch="gunmetal", verts=10, x=0.0, bevel=0.02):
    length = y_back - y_front
    return t(sf.cyl(r, length, loc=(x, (y_front + y_back) / 2, z), rot=(90, 0, 0), verts=verts, bevel=bevel, segments=1),
             part, swatch)


def muzzle(part, r, y, z, ring="chrome", x=0.0, depth=0.1):
    """A ring at the barrel's mouth and the dark bore inside it."""
    t(sf.cyl(r * 1.25, depth, loc=(x, y + depth / 2, z), rot=(90, 0, 0), verts=10, bevel=0.0), part, ring)
    t(sf.cyl(r * 0.6, depth * 0.6, loc=(x, y - 0.005, z), rot=(90, 0, 0), verts=8, bevel=0.0), part, "rubber")


def band(part, r, y, z, w=0.08, swatch="brass", x=0.0, verts=10):
    return t(sf.cyl(r, w, loc=(x, y, z), rot=(90, 0, 0), verts=verts, bevel=0.0), part, swatch)


def trigger_guard(part, y, z, r=0.17, swatch="gunmetal"):
    t(sf.torus(r, 0.035, loc=(0, y, z), rot=(0, 90, 0), major_segs=8, minor_segs=3), part, swatch)
    t(sf.box((0.05, 0.06, 0.17), loc=(0, y + 0.02, z + 0.02), rot=(14, 0, 0), bevel=0.0), part, "steel")


def bead(part, y, z, swatch="brass"):
    t(sf.box((0.06, 0.1, 0.1), loc=(0, y, z), bevel=0.0), part, "gunmetal")
    t(sf.sphere(0.05, loc=(0, y, z + 0.06), segs=6, rings=4), part, swatch)


def rivets(part, points, r=0.035, swatch="brass", axis="x"):
    rot = {"x": (0, 90, 0), "y": (90, 0, 0), "z": (0, 0, 0)}[axis]
    for p in points:
        t(sf.cyl(r, 0.03, loc=p, rot=rot, verts=6, bevel=0.0), part, swatch)


def wrap(part, r, y_from, y_to, z, rings=4, swatch="rubber", tape=None, x=0.0):
    """A handle wrap: a sleeve and raised rings (tape: every other ring in that swatch)."""
    length = y_to - y_from
    t(sf.cyl(r, length, loc=(x, (y_from + y_to) / 2, z), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), part, swatch)
    for i in range(rings):
        y = y_from + length * (i + 0.5) / rings
        t(sf.cyl(r * 1.12, length / rings * 0.35, loc=(x, y, z), rot=(90, 0, 0), verts=8, bevel=0.0), part,
          tape if (tape and i % 2 == 0) else swatch)


def stencil_plate(part, y, z, w=0.3, h=0.16, x=None, swatch="cream", sx=1):
    """A small label plate on the right (+X) side (sx=-1: the left)."""
    x = x if x is not None else 0.0
    t(sf.box((0.02, w, h), loc=(x, y, z), bevel=0.0), part, swatch)


def shifted(dy, fn):
    """Build with fn() and move everything it made dy along Y (a head brought closer to the hand)."""
    before = set(bpy.context.scene.objects)
    fn()
    for o in bpy.context.scene.objects:
        if o not in before:
            o.location.y += dy
    bpy.context.view_layer.update()   # or matrix_world still says where they were (the clip sheets read it)


def exports(budget, step, grip, sockets, meta, pivot=None):
    socks = {"Grip": (grip, 0.0)}
    socks.update(sockets)
    return {"export": {"budget": budget, "step": step, "pivot": pivot or grip, "sockets": socks, "meta": meta}}
