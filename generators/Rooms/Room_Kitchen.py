"""Room_Kitchen: the Kitchen's furniture at levels 2 and 3 for one cell (A1; bible Section 6:
Food, worker stat Speed). Level 1 is the approved A0 set, Room_Kitchen_L1.py; these keep its
fridge, range, counter, cabinets and pantry so an upgrade reads as the same kitchen, better.

    L2  a second range, a serving counter with a cash register, a pie case and stools
    L3  chrome diner: the Automat wall (glowing glass hatches), a milkshake machine, a booth

Sockets: WorkSpot1..n (3 / 4), Seat1..n, Table, Light1-2.

    python3 generators/Rooms/Room_Kitchen.py [2 3]   preview
    SF_EXPORT=1 python3 generators/Rooms/Room_Kitchen.py
"""
import os
import sys

import roomlib as R
import steadfast as sf

sys.path.insert(0, os.path.dirname(__file__))
import Room_Kitchen_L1 as K1  # noqa: E402

BACK = R.BACK


def second_range():
    """A second range in the front-left corner, facing the front."""
    x, y = -11.5, -11.0
    R.bx(R.uid("Range"), "mint", (4.0, 2.9, 3.3), (x, y, 1.65), collision="box", bevel=0.25)
    R.bx("Decor", "porcelain", (4.1, 3.0, 0.2), (x, y, 3.35), bevel=0.06)
    for dx in (-0.95, 0.95):
        for dy in (-0.7, 0.6):
            R.cy("Decor", "navy", 0.55, 0.08, (x + dx, y + dy, 3.49), verts=8)
    R.bx("Decor", "porcelain", (3.2, 0.12, 2.0), (x, y - 1.47, 1.6))
    R.bx("Decor", "chrome", (2.4, 0.22, 0.16), (x, y - 1.6, 2.7))
    return (x, y - 2.2, 0.0)


def serving_counter():
    x, y, w = 3.5, -10.0, 10.0
    R.bx(R.uid("ServeCounter"), "teal", (w, 2.2, 3.2), (x, y, 1.6), collision="box", bevel=0.15)
    R.bx("Decor", "porcelain", (w + 0.4, 2.6, 0.25), (x, y, 3.3), bevel=0.05)
    R.bx("Decor", "chrome", (w + 0.1, 0.12, 0.3), (x, y - 1.15, 2.6))
    R.bx("Decor", "chrome", (2.2, 1.6, 1.4), (x - 4.0, y, 4.1), bevel=0.2)                         # cash register
    R.bx("Decor", "cream", (1.6, 0.1, 0.5), (x - 4.0, y - 0.82, 4.4))
    R.bx("Decor", "skyblue", (3.0, 1.8, 1.6), (x + 3.0, y, 4.25), mat="Glass", transparency=0.45)  # pie case
    for i in range(3):
        R.cy("Decor", "pine", 0.55, 0.3, (x + 2.1 + i * 0.9, y, 3.65), verts=8)
    return (x, y + 2.2, 0.0)


def automat():
    x, y = 11.5, BACK - 0.8
    R.bx(R.uid("Automat"), "chrome", (7.0, 1.6, 9.0), (x, y, 4.5), collision="box", bevel=0.2)
    for i in range(3):
        for j in range(3):
            hx, hz = x - 2.2 + j * 2.2, 2.6 + i * 2.4
            R.bx("DecorNeon", "hazard", (1.6, 0.1, 1.6), (hx, y - 0.82, hz), mat="Neon", cast_shadow=False)
            R.bx("Decor", "brass", (1.9, 0.12, 0.2), (hx, y - 0.86, hz - 0.95))
    R.bx("Decor", "signal", (6.6, 0.15, 1.0), (x, y - 0.84, 8.6))
    return (x, y - 2.2, 0.0)


def milkshake(x, y):
    R.bx("Decor", "porcelain", (1.4, 1.0, 2.2), (x, y, 4.5), bevel=0.25)
    for i in range(3):
        R.cy("Decor", "chrome", 0.2, 1.0, (x - 0.45 + i * 0.45, y - 0.6, 3.9), verts=6)


def booth():
    x, y = -10.5, -9.0
    R.bx(R.uid("BoothTable"), "signal", (5.0, 3.0, 0.3), (x, y, 2.8), collision="box", bevel=0.08)
    R.bx("Decor", "chrome", (5.1, 3.1, 0.15), (x, y, 2.62))
    R.cy("Decor", "chrome", 0.3, 2.6, (x, y, 1.3), verts=8)
    seats = []
    for sy in (-1, 1):
        R.bx(R.uid("BoothSeat"), "rust", (5.0, 1.8, 1.8), (x, y + sy * 2.6, 0.9), collision="box", bevel=0.3)
        R.bx("Decor", "rust", (5.0, 0.6, 2.6), (x, y + sy * 3.4, 2.4), bevel=0.25)
        seats.append(((x, y + sy * 2.4, 0.0), 180.0 if sy < 0 else 0.0))
    return seats


def build(level: int) -> dict:
    K1.fridge()
    K1.stove()
    K1.counter()
    K1.wall_cabinets()
    sockets: dict = {}
    work = [(-8.6, BACK - 4.0, 180.0), (-0.6, BACK - 3.6, 180.0)]
    if level == 2:
        K1.shelves()
        work.append(second_range())
        work.append(serving_counter())
        seats = []
        for i in range(3):                    # stools along the serving counter
            sx = 0.5 + i * 3.0
            R.stool(sx, -12.6)
            seats.append(((sx, -12.6, 0.0), 0.0))
        lights = K1.lamps()
    else:
        work.append(automat())
        milkshake(4.0, BACK - 1.2)
        work.append(serving_counter())
        seats = booth()
        lights = K1.lamps()
        work.append((4.0, BACK - 3.0, 180.0))
    for i, s in enumerate(seats):
        sockets[f"Seat{i + 1}"] = s
    for i, p in enumerate(lights):
        sockets[f"Light{i + 1}"] = (p, 0.0)
    R.work_sockets(work, sockets)
    return sockets


if __name__ == "__main__":
    if os.environ.get("SF_EXPORT") == "1":
        R.export_levels("Room_Kitchen", "Rooms", build, {"room": "Kitchen", "shell": "Kit_Shell"}, levels=(2, 3))
    else:
        picked = tuple(int(a) for a in sys.argv[1:] if a.isdigit()) or (2, 3)
        print(R.preview_in_shell("Room_Kitchen", "Rooms", build, picked, name="Room_Kitchen_L" + "".join(map(str, picked))))
