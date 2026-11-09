"""Bldg_WaterTower: Brightwater's water tower and its pump shed (A5; bible Section 12: water, if
you can reach it). A cream tank with a teal band and a conical cap on four braced legs, a ladder,
the pump shed underneath. 26 x 22 studs.
"""
import townlib as T
from townlib import bx, cy

LEG_H = 40.0


def build():
    bx("Pad", "stone", (18, 18, 0.5), (0, 0, 0.25), collision="box")
    for sx in (-1, 1):
        for sy in (-1, 1):
            T.t(T.sf.tube([(sx * 7, sy * 7, 0.5), (sx * 5.5, sy * 5.5, LEG_H)], [0.55, 0.45], sides=8, resolution=1),
                T.uid("Leg"), "steel", collision="box")
    for z in (12, 26):
        for (dx, dy, rz) in ((0, -6.6, 0), (0, 6.6, 0), (-6.6, 0, 90), (6.6, 0, 90)):
            bx("Decor", "gunmetal", (13.2, 0.3, 0.3), (dx * (1 - z / 140), dy * (1 - z / 140), z), rot=(0, 0, rz))
    cy("Tank", "cream", 10, 13, (0, 0, LEG_H + 6.5), collision="box", verts=16)
    cy("Decor", "teal", 10.15, 3.4, (0, 0, LEG_H + 6.5), verts=16)                               # the band
    T.t(T.sf.lathe([(10.3, 0), (6, 2.6), (1.2, 4.6), (0, 5)], verts=16, loc=(0, 0, LEG_H + 13)), "Decor", "rust")
    cy("Decor", "gunmetal", 10.6, 0.8, (0, 0, LEG_H), verts=16)                                    # the catwalk
    T.sign(0, -10.25, LEG_H + 6.5, 9, 3.0, swatch="teal", rim="cream")
    for z in range(1, int(LEG_H), 2):                                                              # the ladder
        bx("Decor", "steel", (1.6, 0.15, 0.15), (7.6, 0, z))
    for dx in (-0.8, 0.8):
        bx("Decor", "steel", (0.2, 0.2, LEG_H), (7.6 + dx, 0, LEG_H / 2))
    bx("Decor", "skyblue", (0.6, 0.6, 12), (-2, 3, LEG_H - 6), rot=(20, 0, 0))                    # a burst pipe
    # the pump shed: x -7..7, y 11..21
    T.wall_x("walnut", -7, 7, 11, 0, 8, holes=[(-2.5, 2.5, 0, 6.5)], part="Shed")
    T.wall_x("walnut", -7, 7, 21, 0, 8, part="Shed")
    T.wall_y("walnut", 11, 21, -7, 0, 8, part="Shed")
    T.wall_y("walnut", 11, 21, 7, 0, 8, jag=[(11, 5.5), (16, 8)], part="Shed")
    T.roof("rust", -7.5, 7.5, 10.5, 21.5, 8)
    cy("Decor", "teal", 1.6, 3, (4, 14, 1.5), verts=10)                                            # the pump
    T.rubble(9, -9, n=4, spread=3, seed=41)

    sockets = {f"Container{i + 1}": ((-3 + i * 6, 19.2, 0.5), 0.0) for i in range(2)}
    sockets["Survivor1"] = ((0, 1, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "WaterTower", "legs": LEG_H}}}


if __name__ == "__main__":
    T.export(build, "Bldg_WaterTower")
