"""Room_Workshop: the Workshop's furniture for one cell, by level (A1; bible Section 6: the
crafting station for gear, ammo, turrets and tools; worker stat Smarts).

A long workbench with a vise under a pegboard of tools, a lathe, parts bins, and a work lamp.

    L1  the workbench and pegboard, a lathe, parts bins
    L2  adds a welding station: gas bottles on a cart, a mask on a hook, a welding table
    L3  adds a drill press and the Steadfast Fabricator: a cabinet with a glowing window

Sockets: Bench (the crafting spot players use), WorkSpot1..n (2 / 3 / 4), Light1.
"""
import roomlib as R
import steadfast as sf

BACK = R.BACK


def bench(x, y, w=12.0):
    R.bx(R.uid("Workbench"), "walnut", (w, 3.0, 0.5), (x, y, 3.0), collision="box", bevel=0.08)
    for dx in (-w / 2 + 0.4, w / 2 - 0.4):
        for dy in (-1.2, 1.2):
            R.bx("Decor", "gunmetal", (0.35, 0.35, 2.8), (x + dx, y + dy, 1.4))
    R.bx("Decor", "gunmetal", (w - 0.6, 2.4, 0.2), (x, y, 0.9))
    # the vise
    R.bx("Decor", "teal", (1.4, 1.2, 0.9), (x - w / 2 + 1.4, y - 1.0, 3.7), bevel=0.1)
    R.cy("Decor", "chrome", 0.1, 1.6, (x - w / 2 + 1.4, y - 2.0, 3.6), rot=(90, 0, 0), verts=6)
    # tools on the bench
    R.bx("Decor", "signal", (1.6, 0.5, 0.5), (x + 1.0, y - 0.5, 3.5), bevel=0.1)
    R.bx("Decor", "steel", (0.3, 1.8, 0.2), (x - 1.2, y - 0.4, 3.35), rot=(0, 0, 25))
    R.cy("Decor", "hazard", 0.35, 0.9, (x + 3.0, y, 3.7), verts=8)
    return (x, y - 2.6, 0.0)


def pegboard(x, w=12.0):
    y = BACK - 0.12
    R.bx("Decor", "pine", (w, 0.2, 4.6), (x, y, 7.6))
    tools = (("steel", 0.25, 2.2), ("signal", 0.6, 1.0), ("chrome", 0.2, 1.8), ("teal", 0.8, 0.8), ("steel", 0.3, 2.6),
             ("hazard", 0.5, 1.2), ("chrome", 0.25, 2.0), ("rust", 0.9, 0.6))
    for i, (sw, tw, th) in enumerate(tools):
        R.bx("Decor", sw, (tw, 0.2, th), (x - w / 2 + 0.9 + i * (w - 1.8) / 7, y - 0.2, 7.8 - (i % 2) * 0.6))
    R.bx("Decor", "gunmetal", (2.0, 0.6, 0.6), (x + w / 2 - 1.2, y - 0.4, 10.6), rot=(-20, 0, 0))         # work lamp
    R.bx("DecorNeon", "cream", (1.6, 0.1, 0.3), (x + w / 2 - 1.2, y - 0.75, 10.4), mat="Neon", cast_shadow=False)


def lathe(x, y):
    R.bx(R.uid("Lathe"), "mint", (6.0, 2.4, 2.6), (x, y, 1.3), collision="box", bevel=0.2)
    R.bx("Decor", "gunmetal", (6.4, 1.6, 0.6), (x, y, 2.9))
    R.bx("Decor", "mint", (1.6, 2.0, 2.2), (x - 2.2, y, 4.1), bevel=0.2)            # headstock
    R.cy("Decor", "chrome", 0.3, 3.4, (x, y, 3.8), rot=(0, 90, 0), verts=8)
    R.bx("Decor", "mint", (1.0, 1.6, 1.4), (x + 2.4, y, 3.8), bevel=0.15)            # tailstock
    return (x, y - 2.2, 0.0)


def bins(x, y):
    R.bx(R.uid("Bins"), "gunmetal", (4.0, 2.0, 6.0), (x, y, 3.0), collision="box", bevel=0.1)
    for i in range(3):
        for j in range(2):
            R.bx("Decor", ("signal", "teal", "hazard")[(i + j) % 3], (1.6, 0.4, 1.2), (x - 0.9 + j * 1.8, y - 1.05, 1.4 + i * 1.8),
                 bevel=0.08)


def welding(x, y):
    R.bx(R.uid("WeldTable"), "steel", (5.0, 3.0, 0.4), (x, y, 2.8), collision="box")
    for dx in (-2.2, 2.2):
        R.bx("Decor", "gunmetal", (0.3, 2.6, 2.6), (x + dx, y, 1.3))
    for i, sw in enumerate(("leaf", "signal")):                                   # gas bottles on a cart
        R.cy(R.uid("Bottle"), sw, 0.55, 4.2, (x + 3.6 + i * 1.2, y + 0.5, 2.5), collision="box", verts=10)
        R.t(sf.sphere(0.55, loc=(x + 3.6 + i * 1.2, y + 0.5, 4.6), scale=(1, 1, 0.6), segs=8, rings=3), "Decor", sw)
    R.bx("Decor", "rubber", (1.1, 0.5, 1.3), (x - 2.6, y + 1.6, 4.4), bevel=0.2)   # welding mask
    R.bx("DecorNeon", "skyblue", (0.6, 0.1, 0.25), (x - 2.6, y + 1.32, 4.6), mat="Neon", cast_shadow=False)
    return (x, y - 2.4, 0.0)


def drill_press(x, y):
    R.bx(R.uid("DrillBase"), "teal", (2.6, 2.6, 0.6), (x, y, 0.3), collision="box")
    R.cy("Decor", "chrome", 0.3, 7.5, (x, y + 0.6, 4.0), verts=8)
    R.bx("Decor", "teal", (2.0, 2.6, 1.6), (x, y, 7.4), bevel=0.2)
    R.cy("Decor", "chrome", 0.12, 1.6, (x, y - 0.6, 6.0), verts=6)
    R.bx("Decor", "gunmetal", (1.8, 1.8, 0.3), (x, y - 0.2, 3.4))


def fabricator(x, y):
    R.bx(R.uid("Fabricator"), "cream", (5.0, 3.2, 8.0), (x, y, 4.0), collision="box", bevel=0.4)
    R.bx("Decor", "chrome", (5.1, 3.3, 0.4), (x, y, 8.1), bevel=0.1)
    R.bx("DecorNeon", "crystal", (3.0, 0.1, 2.2), (x, y - 1.65, 5.2), mat="Neon", cast_shadow=False)
    R.bx("Decor", "chrome", (3.4, 0.15, 2.6), (x, y - 1.62, 5.2))
    for i in range(3):
        R.cy("Decor", ("signal", "hazard", "leaf")[i], 0.22, 0.15, (x - 0.9 + i * 0.9, y - 1.68, 2.6), rot=(90, 0, 0), verts=8)
    R.bx("Decor", "teal", (4.0, 0.12, 0.6), (x, y - 1.66, 7.2))
    return (x, y - 3.0, 0.0)


def build(level: int) -> dict:
    sockets: dict = {}
    spot = bench(-4.0, BACK - 2.0)
    pegboard(-4.0)
    sockets["Bench"] = (spot, 0.0)
    work = [spot, lathe(-9.5, -11.0)]
    bins(10.5, BACK - 1.1)
    if level >= 2:
        work.append(welding(4.5, -11.0))
    if level >= 3:
        work.append(fabricator(11.0, 8.5))
        drill_press(-12.5, 10.5)
    R.poster(-11.0, 9.0, band="signal", accent="teal", w=2.6, h=3.4, side="left")
    R.work_sockets(work, sockets)
    sockets["Light1"] = ((0.0, 2.0, 12.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_Workshop", "Rooms", build, {"room": "Workshop", "shell": "Kit_Shell"})
