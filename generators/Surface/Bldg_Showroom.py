"""Bldg_Showroom: the Steadfast Shelter Co. showroom, ruined (A5; bible Section 12: blueprints and
the company's secrets). The lobby's showroom after the bomb: teal and cream with a great curved
glass front (empty now), the company sign half fallen, a display bunker hatch inside, sales desks
and posters. 54 x 38 studs, front (-Y) on Main Street.
"""
import math

import townlib as T
from townlib import bx, cy

W, D, H = 54.0, 38.0, 15.0


def build():
    T.storefront(W, D, H, "teal", trim="chrome", kick="navy", door=(-6, 6), windows=((-24, -9), (9, 24)),
                 win_z=(1.8, 11.5),
                 front_top=[(-W / 2, H + 5), (-12, H + 7), (12, H + 7), (18, H + 3), (W / 2 - 4, H + 1)],
                 fallen=(6, W / 2, -D / 2, 4), roof_holes=[(-18, -10, 8, 14)], floor_swatch="porcelain")
    bx("Decor", "cream", (W + 0.4, 1.4, 1.2), (0, -D / 2, H - 1.0))
    # the company sign, one end dropped
    T.sign(-2, -D / 2 - 0.3, H + 3.5, 22, 4.2, swatch="cream", rim="brass")
    bx("Decor", "teal", (8, 0.5, 1.6), (16, -D / 2 - 1.8, H - 2), rot=(0, 24, 0))              # the bit that fell
    # inside: the display bunker's round hatch on a plinth, sales desks, posters on the back wall
    cy("Plinth", "navy", 5.5, 1.2, (-12, 6, 0.6), collision="box", verts=16)
    cy("Hatch", "steel", 4.2, 0.8, (-12, 6, 4.8), rot=(90, 0, 0), collision="box", verts=16)
    cy("Decor", "hazard", 4.6, 0.3, (-12, 6.3, 4.8), rot=(90, 0, 0), verts=16)
    for a in range(0, 360, 60):
        r = math.radians(a)
        bx("Decor", "chrome", (0.5, 0.4, 2.4), (-12 + 2.2 * math.cos(r), 5.4, 4.8 + 2.2 * math.sin(r)), rot=(0, -a, 0))
    for x in (6.0, 16.0):
        T.R.desk(x, 6, w=6, d=2.6, body="cream", top="walnut")
        T.R.chair(x, 8.6, yaw=180, seat="teal")
    for i, x in enumerate((-20, -6, 8, 20)):
        T.R.poster(x, 8, band=("teal", "signal", "navy", "hazard")[i], accent=("signal", "cream", "hazard", "teal")[i],
                   w=4, h=5, y=D / 2 - 0.6)
    T.rubble(10, -8, n=8, spread=7, seed=17, swatch="sandstone")
    T.rubble(-20, -10, n=4, spread=3, seed=19)

    sockets = T.back_row(4, W, D, inset=2.6, margin=6)
    sockets["Survivor1"] = ((22, -13, 0.5), 0)
    sockets["BigFind"] = ((-21, -12, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "Showroom", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_Showroom")
