"""Bldg_Checkpoint: the military checkpoint at the end of Main Street (A5; bible Section 12: it
opens in Era III; ammo and military gear). A sandbagged compound with a guard booth, a canvas tent,
a searchlight tower and stacked crates; across its front a striped barrier gate (Role Barrier: it
stays shut until Era III). Front (-Y) faces the town.
"""
import townlib as T
from townlib import bx, cy

GATE_Y = -4.0


def sandbags(x0, x1, y, h=5.5, along="x"):
    rows = int(h // 1.1)
    for r in range(rows):
        n = int(abs(x1 - x0) // 2.6)
        for i in range(n):
            off = 1.3 if r % 2 else 0
            p = x0 + 1.3 + i * 2.6 + off
            if p > max(x0, x1) - 0.8:
                continue
            size = (2.5, 1.5, 1.05) if along == "x" else (1.5, 2.5, 1.05)
            loc = (p, y, 0.55 + r * 1.05) if along == "x" else (y, p, 0.55 + r * 1.05)
            bx("Decor", "sandstone" if (i + r) % 3 else "stone", size, loc,
               bevel=0.3 if r == rows - 1 else 0.0)                                  # only the top row rounded
    if along == "x":
        bx(T.uid("Bags"), "sandstone", (abs(x1 - x0), 1.5, h), ((x0 + x1) / 2, y, h / 2), collision="box", transparency=1.0)
    else:
        bx(T.uid("Bags"), "sandstone", (1.5, abs(x1 - x0), h), (y, (x0 + x1) / 2, h / 2), collision="box", transparency=1.0)


def build():
    bx("Slab", "stone", (44, 36, 0.4), (0, 13, 0.2), collision="box")
    sandbags(-4, 30, -22, along="y")
    sandbags(-4, 30, 22, along="y")
    sandbags(-22, 22, 30, along="x")
    # the barrier gate: striped boards on posts, all of it Role Barrier (shut until Era III)
    for x in (-21.5, 21.5):
        bx(T.uid("GatePost"), "olive", (1.4, 1.4, 11), (x, GATE_Y, 5.5), collision="box")
    for i in range(8):
        T.sf.tag(T.sf.box((5.2, 0.9, 10), loc=(-18.2 + i * 5.2, GATE_Y, 5.2), bevel=0.05, segments=1),
                 "Barrier", "hazard" if i % 2 == 0 else "navy", collision="box", role="Barrier")
    T.sign(0, GATE_Y - 0.8, 12.2, 14, 2.4, swatch="cream", rim="olive")
    # the booth, the tent, a searchlight tower, crates of ammo
    bx("Booth", "olive", (7, 7, 8.5), (-15, 3, 4.25), collision="box", bevel=0.2)
    bx("Decor", "cream", (5, 0.3, 2.2), (-15, -0.6, 6))
    bx("Decor", "olive", (8, 8, 0.6), (-15, 3, 8.8))
    T.t(T.sf.profile_slab([(-8, 0), (8, 0), (0, 7)], 12, loc=(10, 22, 0.4), rot=(90, 0, 0)), "Tent", "olive", collision="box")
    for (x, y) in ((16, 26), (16, 20)):
        bx("Decor", "steel", (0.5, 0.5, 18), (x, y, 9))
    bx("Decor", "gunmetal", (4, 7, 0.6), (16, 23, 18))
    cy("Decor", "chrome", 1.6, 2.2, (16, 21.5, 19.5), rot=(80, 0, 0), verts=12)                       # the searchlight
    cy("Decor", "cream", 1.3, 0.2, (16, 20.4, 19.7), rot=(80, 0, 0), verts=12, mat="Neon")
    for i, (x, y, z) in enumerate(((-6, 18, 0), (-3.2, 18, 0), (-4.6, 18, 2.3), (6, 8, 0))):
        T.R.crate(x, y, z=z + 0.4, size=2.6, wood="olive", band="gunmetal", label="hazard")

    sockets = {f"Container{i + 1}": ((-16 + i * 8, 27, 0.4), 0.0) for i in range(5)}
    sockets["Survivor1"] = ((16, 8, 0.4), 0)
    sockets["BigFind"] = ((-6, 12, 0.4), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "Checkpoint", "gate": GATE_Y}}}


if __name__ == "__main__":
    T.export(build, "Bldg_Checkpoint")
