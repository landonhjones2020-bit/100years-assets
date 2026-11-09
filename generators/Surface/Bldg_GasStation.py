"""Bldg_GasStation: the Main Street gas station, after the bomb (A5; bible Section 12: scrap and
flares). A cream canopy with a signal-orange fascia over two bowser pumps, the kiosk behind with
its door hanging, oil drums and a tyre stack. 56 x 44 studs, front (-Y) on Main Street.
"""
import townlib as T
from townlib import bx, cy

W, D = 56.0, 44.0


def pump(x, y):
    bx(T.uid("Pump"), "signal", (2.6, 2.0, 5.2), (x, y, 2.9), collision="box", bevel=0.3)
    cy("Decor", "cream", 1.0, 0.4, (x, y - 1.05, 4.6), rot=(90, 0, 0), verts=12)               # the dial
    cy("Decor", "chrome", 1.15, 0.3, (x, y, 5.7), verts=12)
    bx("Decor", "rubber", (0.25, 0.25, 3), (x + 1.4, y, 2.8), rot=(0, 18, 0))                  # the hose
    bx("Decor", "stone", (4, 3.2, 0.3), (x, y, 0.55))  # the island


def build():
    bx("Apron", "stone", (W, D, 0.4), (0, 0, 0.2), collision="box")
    for x in (-W / 2 + 8, W / 2 - 30):
        bx("Decor", "hazard", (0.4, 14, 0.06), (x, -10, 0.43))
    # the canopy on two posts over the pumps, its fascia half torn off
    for x in (-22, 10):
        bx(T.uid("Post"), "cream", (1.4, 1.4, 15), (x, -8, 7.5), collision="box")
        pump(x + 5, -8)
    bx("Canopy", "cream", (40, 18, 1.0), (-6, -8, 15.4), collision="box", rot=(0, 2, 0))
    bx("Decor", "signal", (40.4, 18.4, 1.4), (-6, -8, 16.4), rot=(0, 2, 0))
    bx("Decor", "signal", (12, 0.6, 1.4), (14, -17.5, 13.0), rot=(0, 30, 0))                 # the torn-off bit
    T.sign(-6, -17.6, 16.4, 10, 1.2, swatch="cream", rim="signal")
    # the kiosk: walls round x 3..25, y 4..20, its door hanging
    T.wall_x("cream", 3, 25, 4, 0, 12, holes=[(5, 9, 0, 8.5), (12, 22, 3.5, 9)], part="Kiosk")
    T.wall_x("cream", 3, 25, 20, 0, 12, part="Kiosk")
    T.wall_y("cream", 4, 20, 3, 0, 12, part="Kiosk")
    T.wall_y("cream", 4, 20, 25, 0, 12, jag=[(4, 9), (12, 12)], part="Kiosk")
    T.roof("stone", 3, 25, 4, 20, 12, holes=[(15, 21, 9, 15)], rim="signal")
    bx("Decor", "signal", (4, 0.3, 8.5), (10.2, 2.4, 4.3), rot=(0, 0, -55))                    # the door, hanging open
    T.window_frame(12, 22, 3.9, 3.5, 9)
    bx("Counter", "signal", (8, 2.2, 3), (16, 9, 1.5), collision="box", bevel=0.1)
    # drums, tyres and an air pump at the side
    for i, (x, y) in enumerate(((-24, 10), (-21.5, 11.5), (-24, 13.5))):
        T.R.barrel(x, y, r=1.2, h=3.2, body=("signal", "olive", "rust")[i])
    for i in range(4):
        T.t(T.sf.torus(1.3, 0.45, loc=(-14, 14, 0.45 + i * 0.85), major_segs=12, minor_segs=4), "Decor", "rubber")
    bx("AirPump", "hazard", (1.4, 1.2, 4.2), (-6, 15, 2.1), collision="box", bevel=0.2)
    T.rubble(-4, 4, n=6, spread=5, seed=23)

    sockets = {f"Container{i + 1}": ((6 + i * 7, 17.5, 0.4), 0.0) for i in range(3)}
    sockets["Survivor1"] = ((8, 7, 0.4), 0)
    sockets["BigFind"] = ((-20, 6, 0.4), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "GasStation", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_GasStation")
