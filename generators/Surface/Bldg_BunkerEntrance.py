"""Bldg_BunkerEntrance: the Steadfast bunker's door in the north hill (A5; bible Sections 4 and 12:
the hillside path into the Steadfast blast door; the elevator behind it goes down to the bunker).
A concrete portal with wing walls into the hill, a great round door in a hazard-striped ring, the
Steadfast sign over it, lamps, and the call box beside it. Front (-Y) faces the town.
Sockets: Exit (where riders step out, facing the town) and Call (the call box's prompt).
"""
import math

import townlib as T
from townlib import bx, cy


def build():
    bx("Pad", "stone", (32, 18, 0.4), (0, -8, 0.2), collision="box")
    for i in range(6):
        bx("Decor", "hazard" if i % 2 == 0 else "navy", (2.5, 0.1, 0.06), (-6.25 + i * 2.5, -1.4, 0.43))
    # the portal: a headwall into the hill and wing walls angling out
    bx("Headwall", "sandstone", (44, 6, 22), (0, 3, 11), collision="box")
    for sx in (-1, 1):
        bx(T.uid("Wing"), "sandstone", (3, 14, 16), (sx * 23.5, -4, 8), rot=(0, 0, sx * 18), collision="box")
        bx("Decor", "stone", (3.4, 14.4, 0.8), (sx * 23.5, -4, 16.2), rot=(0, 0, sx * 18))
    bx("Decor", "stone", (46, 7, 1.4), (0, 3, 22.4))
    # the round door: a hazard-striped ring, the door itself, its hinge and wheel
    T.t(T.sf.ring(8.0, 10.0, 1.6, loc=(0, -0.2, 10.5), rot=(90, 0, 0), verts=24), "Ring", "steel", collision="box")
    for a in range(0, 360, 30):
        r = math.radians(a + 15)
        bx("Decor", "hazard" if (a // 30) % 2 == 0 else "navy", (2.2, 0.3, 1.4),
           (9.0 * math.cos(r), -1.05, 10.5 + 9.0 * math.sin(r)), rot=(0, -(a + 15), 0))
    cy("Door", "gunmetal", 7.9, 1.4, (0, 0.6, 10.5), rot=(90, 0, 0), collision="box", verts=24)
    cy("Decor", "steel", 3.0, 0.6, (0, -0.4, 10.5), rot=(90, 0, 0), verts=16)
    for a in range(0, 360, 60):
        r = math.radians(a)
        bx("Decor", "brass", (0.5, 0.5, 2.6), (2.0 * math.cos(r), -0.8, 10.5 + 2.0 * math.sin(r)), rot=(0, -a, 0))
    cy("Decor", "brass", 0.8, 0.8, (0, -0.9, 10.5), rot=(90, 0, 0), verts=10)
    bx("Decor", "gunmetal", (2.4, 2.0, 8), (9.6, -0.5, 10.5))                                           # the hinge
    # the sign over the door, lamps either side
    T.sign(0, -0.4, 19.6, 22, 3.4, swatch="cream", rim="teal")
    for sx in (-1, 1):
        bx("Decor", "steel", (0.6, 1.6, 0.6), (sx * 13, -0.6, 15))
        cy("Decor", "hazard", 0.9, 1.2, (sx * 13, -1.6, 14.5), verts=10, mat="Neon")
    # the call box: a teal post with a brass button
    bx("CallBox", "teal", (1.4, 1.0, 4.4), (5, -2.4, 2.2), collision="box", bevel=0.15)
    cy("Decor", "brass", 0.35, 0.3, (5, -2.95, 3.4), rot=(90, 0, 0), verts=10)
    bx("Decor", "cream", (0.9, 0.1, 0.6), (5, -2.95, 2.6))

    sockets = {"Exit": ((0, -10, 0.4), 0.0), "Call": ((5, -3.0, 3.0), 0.0)}
    return {"export": {"sockets": sockets, "meta": {"place": "Entrance"}}}


if __name__ == "__main__":
    T.export(build, "Bldg_BunkerEntrance")
