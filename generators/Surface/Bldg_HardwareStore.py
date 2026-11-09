"""Bldg_HardwareStore: Main Street's hardware store, after the bomb (A5; bible Section 12:
tools, lamps and spare parts). Red brick with a green-and-cream awning and a stepped false front,
shelves of tools and paint, the counter by the door. 40 x 32 studs, front (-Y) on Main Street.
"""
import townlib as T
from townlib import bx, cy

W, D, H = 40.0, 32.0, 13.0


def build():
    T.storefront(W, D, H, "rust", trim="steel", kick="gunmetal", door=(-4, 4), windows=((-16, -7), (7, 16)),
                 front_top=[(-W / 2, H + 4), (-6, H + 4), (-6, H + 6), (6, H + 6), (6, H + 4), (9, H + 4), (12, H + 1)],
                 fallen=(4, W / 2, -D / 2, 2), roof_holes=[(-12, -5, 6, 11)], floor_swatch="walnut")
    T.awning(-W / 2 + 1, W / 2 - 1, -D / 2 - 0.6, 9.8, depth=4.5, stripes=("forest", "cream"), n=10)
    T.sign(0, -D / 2 - 0.2, H + 3, 14, 3.6, swatch="cream", rim="forest")
    for x in (-W / 2 + 0.5, W / 2 - 0.5):
        bx("Decor", "sandstone", (1.6, 1.6, H + 0.4), (x, -D / 2, (H + 0.4) / 2))          # brick piers
    # shelves of tools and paint down the left, the counter by the door, a paint-can pyramid
    for y in (-6.0, 3.0):
        T.R.shelf(-12, y, w=10, d=2.0, h=7.5, levels=4, frame="gunmetal", board="walnut")
        T.R.tins(-12, y, 2.4, n=5, w=9, swatches=("signal", "skyblue", "hazard", "mint"))
        T.R.tins(-12, y, 4.6, n=5, w=9, swatches=("cream", "rust", "teal"))
    bx("Counter", "forest", (10, 2.4, 3.2), (8, -7, 1.6), collision="box", bevel=0.1)
    bx("Decor", "walnut", (10.4, 2.8, 0.25), (8, -7, 3.3))
    bx("Decor", "chrome", (1.6, 1.2, 1.0), (5, -7, 3.9))                                    # the till
    for i, (x, y, z) in enumerate(((2, 4, 0.9), (3.2, 4, 0.9), (4.4, 4, 0.9), (2.6, 4, 2.1), (3.8, 4, 2.1), (3.2, 4, 3.3))):
        cy("Decor", ("signal", "hazard", "skyblue")[i % 3], 0.55, 1.2, (x, y, z), verts=8)
    for i in range(4):                                                                          # hanging lamps
        cy("Decor", "brass", 0.7, 0.8, (-14 + i * 4, 9, 9.5), verts=8)
        bx("Decor", "steel", (0.08, 0.08, 2.6), (-14 + i * 4, 9, 11.2))
    T.rubble(12, -2, n=6, spread=5, seed=9, swatch="rust")
    T.can(-W / 2 + 3, -D / 2 - 3)

    sockets = T.back_row(5, W, D, inset=2.6, margin=4)
    sockets["Survivor1"] = ((14, 4, 0.5), 0)
    sockets["BigFind"] = ((-4, -10, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "HardwareStore", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_HardwareStore")
