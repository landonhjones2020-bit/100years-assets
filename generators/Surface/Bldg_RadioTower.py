"""Bldg_RadioTower: Brightwater's radio mast and its transmitter shack (A5; bible Section 12:
radio logs and a view of the town). A tapering orange-and-white lattice mast with a red beacon,
guy wires, the shack at its foot with its door gone. 26 x 22 studs.
"""
import math

import townlib as T
from townlib import bx, cy

MAST_H = 84.0


def build():
    bx("Pad", "stone", (14, 14, 0.6), (0, -4, 0.3), collision="box")
    # the lattice mast: four legs leaning in, cross braces every 7 studs, bands of orange and white
    base, top = 4.0, 1.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            a = (sx * base, -4 + sy * base, 0.6)
            b = (sx * top, -4 + sy * top, MAST_H)
            T.t(T.sf.tube([a, b], [0.35, 0.25], sides=6, resolution=1), T.uid("Leg"), "steel", collision="box")
    n = int(MAST_H // 7)
    for i in range(n):
        z = 3 + i * 7
        half = base + (top - base) * (z / MAST_H)
        col = "signal" if (i // 2) % 2 == 0 else "porcelain"
        for (dx, dy, rz) in ((0, -half, 0), (0, half, 0), (-half, 0, 90), (half, 0, 90)):
            bx("Decor", col, (half * 2, 0.25, 0.25), (dx, -4 + dy, z), rot=(0, 0, rz))
    cy("Decor", "steel", 1.6, 0.6, (0, -4, MAST_H + 0.3), verts=8)
    bx("Beacon", "rust", (1.2, 1.2, 1.2), (0, -4, MAST_H + 1.4), mat="Neon")
    for (x, y) in ((-12, -14), (12, -14), (0, 10)):
        T.t(T.sf.tube([(0, -4, MAST_H * 0.6), (x, y, 0.2)], [0.06, 0.06], sides=4, resolution=1), "Decor", "gunmetal")
    # the shack: walls round x -8..8, y 2.5..13.5, the door gone
    T.wall_x("walnut", -8, 8, 2.5, 0, 9, holes=[(-6, -2, 0, 7), (2, 6, 3.5, 7)], part="Shack")
    T.wall_x("walnut", -8, 8, 13.5, 0, 9, part="Shack")
    T.wall_y("walnut", 2.5, 13.5, -8, 0, 9, part="Shack")
    T.wall_y("walnut", 2.5, 13.5, 8, 0, 9, jag=[(2.5, 7), (8, 9)], part="Shack")
    T.floor("stone", 16, 11, z=0)
    T.roof("rust", -8.5, 8.5, 2, 14, 9, holes=[(2, 6, 6, 10)])
    T.R.console(0, 12.4, w=6, body="navy", lights=("signal", "leaf", "hazard"))
    bx("Decor", "cream", (2.4, 0.2, 3), (6.2, 13.3, 5))                                           # a frequency chart
    T.rubble(-10, -12, n=4, spread=3, seed=37)

    sockets = {f"Container{i + 1}": ((-5 + i * 5, 11.6, 0.5), 0.0) for i in range(3)}
    sockets["Survivor1"] = ((-10, -3, 0.5), 0)
    sockets["BigFind"] = ((10, -6, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "RadioTower", "mast": MAST_H}}}


if __name__ == "__main__":
    T.export(build, "Bldg_RadioTower")
