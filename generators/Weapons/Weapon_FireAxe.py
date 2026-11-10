"""Weapon_FireAxe: heavy, breaks rubble (bible Appendix); the Firefighter's and Scavenger's
melee weapon, swung two-handed. A 1950s fire-station axe: a red enamel head with a polished
edge and a back spike, on a long pine handle with a rubber grip, a brass ferrule and a cream
stencil plate.

Pivot = the right hand's grip. Sockets: Grip, Support (where the left hand closes, below it
toward the end of the handle) and Tip (the blade). The head faces Blender -Y; the edge is on -Z,
so it leads an overhead chop.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_FireAxe.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_FireAxe", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.25, 0.0)
SUPPORT = (0.0, 0.85, 0.0)
HEAD_Y = -1.85
PULL = 0.7   # the head sits this much closer than it was first drawn (it was 4.4 studs long)


def build():
    A = "Axe"
    # handle: pine, slightly oval, with a rubber grip at the end and a flared knob
    G.t(sf.cyl(0.115, 2.45, loc=(0, -0.72, 0), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), A, "pine")
    G.wrap(A, 0.13, 0.45, 1.0, 0.0, rings=4, swatch="rubber")
    G.t(sf.cyl(0.17, 0.12, loc=(0, 1.06, 0), rot=(90, 0, 0), verts=8, bevel=0.04, segments=1), A, "rubber")
    G.t(sf.box((0.02, 0.45, 0.14), loc=(0.115, -0.45, 0), bevel=0.0), A, "cream")      # stencil plate
    G.band(A, 0.135, -1.4, 0.0, w=0.14, swatch="brass")
    G.shifted(PULL, head)
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Tip": ((0, HEAD_Y, -0.72), 0.0)},
                     {"kind": "Melee", "hold": "Heavy", "class": ["Firefighter", "Scavenger"]})


def head():
    A = "Axe"
    # head: a red enamel slab (side profile in y, z). The eye wraps the handle; the blade flares
    # down to a curved edge on -Z; the pick tapers up the back with a slight hook toward the front
    import math
    edge_pts = []
    for i in range(7):                       # the edge: an arc from the far corner to the near one
        a = math.radians(-35 + i * 70 / 6)
        edge_pts.append((-2.52 + math.sin(a) * 0.62, -0.72 - math.cos(a) * 0.22))
    head = [(-2.3, 0.22), (-2.3, -0.2), (-2.08, -0.52)] + list(reversed(edge_pts)) + [
        (-2.98, -0.52), (-2.78, -0.2), (-2.78, 0.22), (-2.7, 0.42), (-2.62, 0.82), (-2.52, 0.9), (-2.54, 0.42)]
    head = [(y, z * 0.75) for y, z in head]            # a compact head: the handle stays the long part
    edge_pts = [(y, z * 0.75) for y, z in edge_pts]
    G.t(G.side(head, 0.2, bevel=0.035, segments=1), A, "rust")
    # the ground edge: a polished steel strip following the arc
    strip = [(y, z + 0.09) for y, z in edge_pts] + [(y, z - 0.035) for y, z in reversed(edge_pts)]
    G.t(G.side(strip, 0.12, bevel=0.0), A, "chrome")
    # the eye: the handle's end shows through the top of the head, and a steel wedge
    G.t(sf.box((0.24, 0.26, 0.06), loc=(0, -2.54, 0.22), bevel=0.0), A, "pine")
    G.t(sf.box((0.06, 0.2, 0.065), loc=(0, -2.54, 0.25), bevel=0.0), A, "steel")
    G.rivets(A, [(sx * 0.1, -2.42, -0.1) for sx in (-1, 1)] + [(sx * 0.1, -2.66, -0.1) for sx in (-1, 1)], r=0.04)


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
