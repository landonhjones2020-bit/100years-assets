"""Bldg_RailYard: the wrecked train in the rail yard and the depot shed (A5; bible Section 12: a
wrecked train full of salvage). A streamlined diesel locomotive and two boxcars thrown off true on
the rails, their doors open with ramps up, and the depot shed north of the tracks. The pivot is
the track's centre (the map's rails run along X at Y = +-4).
"""
import townlib as T
from townlib import bx, cy

CARS = [("Loco", -48.0, 34.0, "navy"), ("Boxcar", -8.0, 34.0, "rust"), ("Boxcar", 34.0, 34.0, "teal")]
FLOOR = 3.1


def bogies(x, length):
    for dx in (-length / 2 + 5, length / 2 - 5):
        bx("Decor", "gunmetal", (6, 7, 1.6), (x + dx, 0, 1.3))
        for wx in (-1.8, 1.8):
            for wy in (-3.6, 3.6):
                cy("Decor", "steel", 1.1, 0.5, (x + dx + wx, wy, 1.1), rot=(90, 0, 0), verts=10)


def boxcar(x, length, colour, tilt):
    """A boxcar players climb into: every wall its own collision box (merged, one box would fill
    the car: the A5 playtest's solid boxcars), the roof per car, the ramp a hull (a box would be a
    3-stud step)."""
    bogies(x, length)
    bx(T.uid("Car"), "gunmetal", (length, 10, 1.0), (x, 0, FLOOR - 0.5), collision="box")
    bx(T.uid("Car"), colour, (length, 1.0, 10), (x, 4.5, FLOOR + 5), collision="hull", rot=(tilt, 0, 0))      # back wall
    bx(T.uid("Car"), colour, (length * 0.4, 1.0, 10), (x - length * 0.3, -4.5, FLOOR + 5), collision="box")
    bx(T.uid("Car"), colour, (length * 0.25, 1.0, 10), (x + length * 0.375, -4.5, FLOOR + 5), collision="box")
    for sx in (-1, 1):
        bx(T.uid("Car"), colour, (1.0, 10, 10), (x + sx * length / 2, 0, FLOOR + 5), collision="box")
    bx(T.uid("Roof"), colour, (length + 0.6, 11, 0.6), (x, 0, FLOOR + 10.3), collision="hull", rot=(tilt * 0.5, 0, 0))
    for i in range(int(length // 4)):
        bx("Decor", "steel", (0.25, 10.4, 0.25), (x - length / 2 + 2 + i * 4, 0, FLOOR + 10.7))
    bx("Decor", colour, (length * 0.32, 0.4, 9.4), (x + length * 0.07, -6.2, FLOOR + 4.7), rot=(0, 0, 8))  # the door, slid off
    T.t(T.sf.profile_slab([(0, 0), (6, 0), (6, 0.6)], 5, loc=(x + 4 - 2.5, -5.0, 0), rot=(0, 0, 0)), "Decor", "walnut")
    bx(T.uid("Ramp"), "walnut", (5, 7, 0.6), (x + 4, -7.2, 1.5), rot=(-24, 0, 0), collision="hull")


def loco(x, length):
    bogies(x, length)
    part = T.uid("Loco")
    bx(part, "gunmetal", (length, 10, 1.0), (x, 0, FLOOR - 0.5), collision="box")
    bx(part, "navy", (length - 8, 9.4, 8.5), (x + 3, 0, FLOOR + 4.25), collision="box", bevel=0.8)      # the hood
    T.t(T.sf.lathe([(4.7, 0), (4.7, 4), (3.6, 7.5), (0, 8.4)], verts=12, loc=(x - length / 2 + 4, 0, FLOOR + 4.5),
                   rot=(0, -90, 0)), part, "navy", collision="box")                                       # the streamlined nose
    bx("Decor", "hazard", (length - 4, 9.6, 0.8), (x + 1, 0, FLOOR + 1.0))                               # the stripe
    bx(part, "navy", (8, 9.4, 4), (x - length / 2 + 9, 0, FLOOR + 10), collision="box")                   # the cab
    for wy in (-4.75, 4.75):
        bx("Decor", "cream", (5, 0.2, 2.2), (x - length / 2 + 9, wy, FLOOR + 10.2))
    cy("Decor", "brass", 1.0, 0.3, (x - length / 2 + 0.4, 0, FLOOR + 6.4), rot=(0, 90, 0), verts=12)       # the headlamp


def build():
    bx("Ballast", "stone", (150, 14, 0.4), (-10, 0, 0.2), collision="box")
    for x, (kind, cx, length, colour) in enumerate(CARS):
        if kind == "Loco":
            loco(cx, length)
        else:
            boxcar(cx, length, colour, tilt=4 if x == 1 else -3)
    for i in range(6):                                                                                     # spilled salvage
        bx("Decor", ("pine", "steel", "rust")[i % 3], (2.2, 2.0, 1.6), (-24 + i * 9, -9 - (i % 2) * 2, 0.8),
           rot=(0, 0, i * 35))
    # the depot shed north of the tracks (x -159..-141, y -32..-20)
    T.wall_x("walnut", -159, -141, -32, 0, 10, holes=[(-153, -147, 0, 7.5)], part="Depot")
    T.wall_x("walnut", -159, -141, -20, 0, 10, part="Depot")
    T.wall_y("walnut", -32, -20, -159, 0, 10, part="Depot")
    T.wall_y("walnut", -32, -20, -141, 0, 10, jag=[(-32, 6), (-26, 10)], part="Depot")
    bx("DepotFloor", "stone", (18, 12, 0.5), (-150, -26, 0.25), collision="box")
    T.roof("rust", -159.5, -140.5, -32.5, -19.5, 10, holes=[(-149, -144, -28, -24)])
    T.sign(-150, -32.6, 11.6, 9, 2.4, swatch="cream", rim="walnut")
    T.R.crate(-156, -22, size=2.6)

    # three containers against the back of each boxcar (the locomotive is shut), 10 studs apart;
    # the big find out on the ground, clear of them
    sockets = {}
    i = 0
    for kind, cx, length, colour in CARS:
        if kind != "Boxcar":
            continue
        for dx in (-10, 0, 10):
            i += 1
            sockets[f"Container{i}"] = ((cx + dx, 2.4, FLOOR), 0.0)
    sockets["Survivor1"] = ((-150, -24, 0.5), 0)
    sockets["BigFind"] = ((14, -12, 0.4), 0)
    return {"export": {"sockets": sockets, "pivot": (0, 0, 0), "meta": {"place": "RailYard", "floor": FLOOR}}}


if __name__ == "__main__":
    T.export(build, "Bldg_RailYard")
