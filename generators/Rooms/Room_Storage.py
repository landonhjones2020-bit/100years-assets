"""Room_Storage: the Storage room's furniture for one cell, by level (A1; bible Section 6:
raises stockpile caps; no workers).

Steel racking along the back wall full of stencilled crates, ration tins and boxes, drums
and sacks on the floor, a clipboard station.

    L1  two racks, a crate stack, drums
    L2  three racks, a second crate stack, sacks
    L3  four racks and a little 1950s forklift

Sockets: Light1 (no workers).
"""
import roomlib as R
import steadfast as sf

BACK = R.BACK


def rack(x, fill=0):
    zs = R.shelf(x, BACK - 1.1, w=6.2, d=2.0, h=9.0, levels=4)
    swatches = (("pine", "teal"), ("brass", "cream", "rust", "teal"), ("olive", "pine"))
    for k, z in enumerate(zs[:3]):
        kind = (k + fill) % 3
        if kind == 0:
            R.boxes_row(x, BACK - 1.1, z + 0.08, n=3, w=5.6, swatch="pine")
        elif kind == 1:
            R.tins(x, BACK - 1.1, z + 0.08, n=4, w=5.6, swatches=swatches[1])
        else:
            for i in range(2):
                R.bx("Decor", "cream", (2.2, 1.4, 1.5), (x - 1.4 + i * 2.8, BACK - 1.1, z + 0.85), bevel=0.4)


def forklift(x, y):
    R.bx(R.uid("Forklift"), "hazard", (3.6, 5.0, 2.4), (x, y, 1.7), collision="box", bevel=0.4)
    R.bx("Decor", "rubber", (3.0, 1.6, 1.6), (x, y + 1.2, 3.6), bevel=0.3)                      # seat back
    for dx in (-1.9, 1.9):
        for dy in (-1.6, 1.6):
            R.cy("Decor", "rubber", 0.75, 0.6, (x + dx, y + dy, 0.75), rot=(0, 90, 0), verts=8)
    for dx in (-1.2, 1.2):                                                               # mast and forks
        R.bx("Decor", "gunmetal", (0.35, 0.35, 6.5), (x + dx, y - 2.7, 3.4))
        R.bx("Decor", "steel", (0.4, 3.0, 0.2), (x + dx, y - 4.3, 0.6))
    R.bx("Decor", "gunmetal", (2.8, 0.3, 0.3), (x, y - 2.7, 6.5))
    R.cy("Decor", "signal", 0.9, 0.2, (x, y + 0.2, 4.4), rot=(30, 0, 0), verts=8)            # steering wheel
    R.bx("Decor", "pine", (2.6, 2.6, 2.3), (x, y - 4.3, 1.85), bevel=0.1)          # a crate on the forks


def build(level: int) -> dict:
    racks = {1: 2, 2: 3, 3: 4}[level]
    xs = {2: (-9.0, 9.0), 3: (-10.0, 0.0, 10.0), 4: (-11.5, -4.0, 3.5, 11.0)}[racks]
    for i, x in enumerate(xs):
        rack(x, fill=i)
    # a crate stack and drums near the front corners
    R.crate(-11.0, -10.5)
    R.crate(-11.0, -10.5, z=2.52)
    R.crate(-8.0, -11.5, size=2.4)
    for i, (x, y) in enumerate(((10.5, -11.5), (12.6, -9.5))[: 2 if level < 3 else 1]):
        R.barrel(x, y, body="olive" if i else "rust")
    R.desk(2.0, -12.5, w=4.0, d=2.0, body="steel", top="walnut")            # the clipboard station
    R.bx("Decor", "cream", (1.0, 1.4, 0.1), (2.6, -12.5, 3.08), rot=(0, 0, 10))
    if level >= 2:
        R.crate(-4.5, -11.5, size=2.6, wood="olive", band="gunmetal", label="hazard")
        for i in range(3):
            R.bx("Decor", "cream", (2.2, 1.6, 1.8), (6.5 + i * 0.4, -9.8 - i * 1.6, 0.9), rot=(0, 0, 12 * i), bevel=0.5)
    if level >= 3:
        forklift(7.5, -9.5)
    R.poster(-11.0, 9.0, band="teal", accent="hazard", w=2.6, h=3.4, side="left")
    return {"Light1": ((0.0, 0.0, 12.0), 0.0)}


if __name__ == "__main__":
    R.main("Room_Storage", "Rooms", build, {"room": "Storage", "shell": "Kit_Shell"})
