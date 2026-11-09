"""Bldg_Grocery: the Brightwater grocery, after the bomb (A5; bible Section 12: canned food and
bottled water). A wide cream-and-teal front under a tall pylon sign, aisles of empty shelves, the
checkouts by the windows, carts in the lot. 50 x 36 studs, front (-Y) on Main Street.
"""
import townlib as T
from townlib import bx, cy

W, D, H = 50.0, 36.0, 14.0


def cart(x, y, rz=0.0):
    bx("Decor", "chrome", (2.4, 3.4, 1.8), (x, y, 2.4), rot=(0, 0, rz))
    bx("Decor", "chrome", (2.6, 0.2, 1.6), (x, y, 1.0), rot=(0, 0, rz))
    for dx in (-0.9, 0.9):
        cy("Decor", "rubber", 0.35, 0.3, (x + dx, y, 0.35), rot=(0, 90, rz), verts=8)


def build():
    T.storefront(W, D, H, "cream", trim="chrome", kick="teal", door=(-5, 5), windows=((-22, -8), (8, 22)),
                 win_z=(2.4, 10.0),
                 front_top=[(-W / 2, H + 2), (-10, H + 2), (-10, H + 3.4), (10, H + 3.4), (10, H + 2), (W / 2 - 9, H + 1.5)],
                 fallen=(-W / 2, -6, -D / 2, -1), roof_holes=[(8, 16, 4, 10)], floor_swatch="porcelain")
    bx("Decor", "teal", (W + 0.4, 1.4, 1.6), (0, -D / 2, H + 0.2))                          # the teal fascia
    # the pylon sign at the left corner
    for dx in (-1.4, 1.4):
        bx("Decor", "steel", (0.7, 0.7, 24), (-W / 2 - 2 + dx, -D / 2 - 3, 12))
    T.sign(-W / 2 - 2, -D / 2 - 3.4, 21, 9, 5, swatch="cream", rim="teal")
    bx("Decor", "signal", (9.4, 0.4, 1.2), (-W / 2 - 2, -D / 2 - 3.6, 17.6))
    # aisles of shelves, the checkouts by the windows
    for x in (-8.0, 2.0, 12.0):
        T.R.shelf(x, 4, w=2.2, d=16, h=7, levels=4, frame="steel", board="porcelain")
        T.R.tins(x, 4, 2.3, n=3, w=1.6, swatches=("signal", "hazard", "cream"))
    for x in (-18.0, -12.0):
        bx("Checkout", "teal", (2.6, 6, 3.0), (x, -10, 1.5), collision="box", bevel=0.1)
        bx("Decor", "chrome", (2.8, 6.2, 0.2), (x, -10, 3.1))
        bx("Decor", "cream", (1.4, 1.2, 1.2), (x, -12, 3.8))
    for x, y, rz in ((-14, -D / 2 - 6, 20), (6, -D / 2 - 5, -35), (18, -D / 2 - 8, 80)):
        cart(x, y, rz)
    T.rubble(-14, -8, n=7, spread=6, seed=13)
    T.can(W / 2 - 3, -D / 2 - 3)

    sockets = T.back_row(5, W, D, inset=2.6, margin=5)
    sockets["Survivor1"] = ((20, -9, 0.5), 0)
    sockets["BigFind"] = ((-4, -10, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "Grocery", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_Grocery")
