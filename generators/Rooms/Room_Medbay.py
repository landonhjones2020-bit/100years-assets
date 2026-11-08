"""Room_Medbay: the Medbay's furniture for one cell, by level (A1; bible Section 6: Medkits,
worker stat Smarts; the players' respawn point; revives residents).

Porcelain-and-chrome 1950s clinic: treatment beds with curtains, an IV stand, a medicine
cabinet with a teal plus (no red cross), and the respawn pad: a hazard-ringed platform with
a lamp where players come back.

    L1  one treatment bed, the cabinet, the respawn pad
    L2  two beds, a medkit bench (where Medkits are made)
    L3  a glass recovery pod and an X-ray light box

Sockets: Respawn (the pad), Bed1..n (patients), WorkSpot1..n (2 / 3 / 4), Light1.
"""
import roomlib as R
import steadfast as sf

BACK = R.BACK


def treatment_bed(x, y, sockets, n):
    R.bx(R.uid("Bed"), "porcelain", (3.6, 7.0, 0.5), (x, y, 2.4), collision="box", bevel=0.1)
    R.bx("Decor", "cream", (3.3, 6.6, 0.5), (x, y, 2.85), bevel=0.15)
    R.bx("Decor", "skyblue", (3.4, 4.0, 0.55), (x, y - 1.2, 2.95))
    R.bx("Decor", "porcelain", (2.6, 1.2, 0.5), (x, y + 2.6, 3.3), bevel=0.15)
    for dx in (-1.6, 1.6):
        for dy in (-3.2, 3.2):
            R.cy("Decor", "chrome", 0.1, 2.2, (x + dx, y + dy, 1.1), verts=6)
    R.bx("Decor", "chrome", (3.6, 0.15, 1.6), (x, y + 3.5, 3.6))          # headboard rail
    # IV stand
    R.cy("Decor", "chrome", 0.07, 7.0, (x + 2.4, y + 2.0, 3.5), verts=6)
    R.bx("Decor", "skyblue", (0.6, 0.3, 0.9), (x + 2.4, y + 2.0, 6.8), mat="Glass", transparency=0.3)
    sockets[f"Bed{n}"] = ((x, y, 3.2), 0.0)


def cabinet(x):
    y = BACK - 0.9
    R.bx(R.uid("Cabinet"), "porcelain", (5.0, 1.8, 8.0), (x, y, 4.0), collision="box", bevel=0.2)
    R.bx("Decor", "skyblue", (2.0, 0.1, 5.0), (x - 1.2, y - 0.92, 5.2), mat="Glass", transparency=0.4)
    R.bx("Decor", "skyblue", (2.0, 0.1, 5.0), (x + 1.2, y - 0.92, 5.2), mat="Glass", transparency=0.4)
    for z in (3.6, 5.2, 6.8):
        R.tins(x, y - 0.3, z - 0.4, n=4, w=4.2, swatches=("cream", "signal", "skyblue", "porcelain"))
    R.bx("Decor", "teal", (1.4, 0.12, 0.45), (x, y - 0.95, 8.6))          # the plus
    R.bx("Decor", "teal", (0.45, 0.12, 1.4), (x, y - 0.95, 8.6))


def respawn_pad(x, y):
    R.cy("RespawnPad", "gunmetal", 3.2, 0.5, (x, y, 0.25), collision="box", verts=12)
    R.cy("Decor", "hazard", 3.25, 0.12, (x, y, 0.52), verts=12)
    R.cy("Decor", "porcelain", 2.6, 0.14, (x, y, 0.56), verts=12)
    R.bx("Decor", "teal", (2.2, 0.7, 0.05), (x, y, 0.64))
    R.bx("Decor", "teal", (0.7, 2.2, 0.05), (x, y, 0.64))
    R.cy("Decor", "gunmetal", 1.4, 0.4, (x, y, R.H - 0.2), verts=10)               # lamp over it
    R.cy("DecorNeon", "cream", 1.1, 0.12, (x, y, R.H - 0.46), mat="Neon", verts=10, cast_shadow=False)
    return (x, y, 0.5)


def build(level: int) -> dict:
    sockets: dict = {"Respawn": (respawn_pad(0.0, -7.0), 0.0)}
    cabinet(-10.5)
    treatment_bed(5.0, 10.5, sockets, 1)
    work = [(-10.5, 11.5, 0.0), (5.0, 6.0, 0.0)]
    # curtain rail and a half-drawn curtain beside the bed
    R.bx("Decor", "chrome", (0.12, 9.0, 0.12), (8.2, 10.5, 12.0))
    R.bx("Decor", "mint", (0.12, 3.6, 8.5), (8.2, 13.0, 7.6))
    if level >= 2:
        treatment_bed(-1.5, 10.5, sockets, 2)
        R.desk(10.5, -11.0, w=5.0, d=2.6, body="porcelain", top="steel")     # the medkit bench
        for i in range(3):
            R.bx("Decor", "porcelain", (1.2, 0.8, 0.7), (9.0 + i * 1.4, -11.0, 3.4), bevel=0.1)
            R.bx("Decor", "teal", (0.6, 0.82, 0.18), (9.0 + i * 1.4, -11.0, 3.4))
        R.stool(10.5, -13.3)
        work.append((10.5, -13.0, 180.0))
    if level >= 3:
        px, py = -10.5, -10.0                                               # recovery pod
        R.bx(R.uid("Pod"), "porcelain", (4.0, 6.5, 1.6), (px, py, 0.8), collision="box", bevel=0.3)
        R.t(sf.sphere(1.0, loc=(px, py, 2.6), scale=(1.7, 3.0, 1.1), segs=10, rings=5), "Decor", "skyblue", mat="Glass",
            transparency=0.45, cast_shadow=False)
        R.bx("DecorNeon", "leaf", (0.8, 0.1, 0.4), (px + 1.5, py - 3.3, 1.2), mat="Neon", cast_shadow=False)
        sockets["Bed3"] = ((px, py, 1.8), 0.0)
        R.bx("Decor", "gunmetal", (4.2, 0.2, 3.0), (-1.5, BACK - 0.12, 11.5))  # X-ray light box
        R.bx("DecorNeon", "porcelain", (3.6, 0.1, 2.4), (-1.5, BACK - 0.25, 11.5), mat="Neon", cast_shadow=False)
        work.append((-8.0, -10.0, 90.0))
    R.poster(-11.0, 9.0, band="teal", accent="porcelain", w=2.6, h=3.4, side="left")
    R.work_sockets(work, sockets)
    sockets["Light1"] = ((0.0, 4.0, 12.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_Medbay", "Rooms", build, {"room": "Medbay", "shell": "Kit_Shell"})
