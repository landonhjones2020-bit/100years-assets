"""Bldg_Diner: the Main Street diner, after the bomb (A5; bible Section 12: soda fountain,
booths, a kitchen out back). A streamline false front in pastel enamel with chrome bands and a
rounded corner, the blade sign still up, the front windows blown in and the front half of the
roof fallen in. 44 x 30 studs, front (-Y) on Main Street.
"""
import townlib as T
from townlib import bx, cy

W, D, H = 44.0, 30.0, 12.0


def build():
    T.plank_floor(W, D, swatch="cream")
    bx("Decor", "navy", (W - 1, 2.0, 0.06), (0, -D / 2 + 3, 0.53))                     # entrance mat
    front_holes = [(-5, 5, 0, 9.5), (-19, -8, 3.2, 9.0), (8, 19, 3.2, 9.0)]
    T.wall_x("blush", -W / 2, W / 2, -D / 2, 0, H, holes=front_holes, jag=[(-W / 2, H), (13, H - 3), (18, H - 6)])
    bx("Decor", "teal", (W + 0.3, 1.25, 1.3), (0, -D / 2, 0.65))                         # kick plate
    for z in (3.0, 10.2):
        bx("Decor", "chrome", (W + 0.4, 1.35, 0.35), (0, -D / 2, z))                     # chrome bands
    for (a, b) in ((-19, -8), (8, 19)):
        T.window_frame(a, b, -D / 2 - 0.1, 3.2, 9.0)
    # the streamline false front: tall and stepped on the left, snapped off on the right
    T.facade("blush", [(-W / 2, H), (12, H), (12, H + 2.2), (6, H + 3.6), (0, H + 3), (-8, H + 4.6), (-14, H + 7),
                       (-W / 2, H + 7)], -D / 2 + 0.5, thick=1.0, part="FalseFront")
    for z in (H + 1.0, H + 2.4):
        bx("Decor", "chrome", (26, 0.3, 0.3), (-9, -D / 2 - 0.55, z))
    cy("Corner", "blush", 2.2, H + 7, (-W / 2, -D / 2 + 0.5, (H + 7) / 2), collision="box", verts=12)
    cy("Decor", "chrome", 2.3, 0.4, (-W / 2, -D / 2 + 0.5, H + 7.1), verts=12)
    T.wall_y("blush", -D / 2, D / 2, -W / 2, 0, H, holes=[(-6, 2, 3.5, 9)])
    T.wall_y("blush", -D / 2, D / 2, W / 2, 0, H, holes=[(-4, 4, 3.5, 9)], jag=[(-D / 2, H - 6), (-2, H - 4), (6, H)])
    T.wall_x("cream", -W / 2, W / 2, D / 2, 0, H, holes=[(-3, 3, 0, 8)])                # the kitchen door out back
    # the roof: the back and the counter side stand, the front right fell in
    T.roof("stone", -W / 2, W / 2, -2, D / 2, H, holes=[(-14, -7, 6, 11)], rim="chrome")
    T.roof("stone", -W / 2, 2, -D / 2, -2, H, holes=[(-10, -4, -12, -7)])
    for i, (x, y, rz) in enumerate(((8, -6, 18), (15, -11, -30), (4, -12, 70))):
        bx("Decor", "stone", (7, 3.5, 0.5), (x, y, 0.9 + i * 0.4), rot=(12, -9 + i * 6, rz))   # fallen roof slabs
    # the blade sign over the door and the name board
    bx("Decor", "steel", (0.6, 0.6, 8), (-15, -D / 2 - 1.5, H + 5))
    T.sign(-15, -D / 2 - 2.2, H + 6, 12, 4, swatch="cream", rim="signal")
    bx("Decor", "glow", (12.6, 0.2, 0.2), (-15, -D / 2 - 2.6, H + 3.6), mat="Neon")    # what's left of the neon
    # inside: the counter with stools and the soda fountain, booths by the windows
    bx("Counter", "teal", (16, 2.6, 3.4), (-10, 1.5, 1.7), collision="box")
    bx("Decor", "chrome", (16.4, 3.0, 0.3), (-10, 1.5, 3.55))
    for i in range(5):
        T.R.stool(-16 + i * 3, -1.4, seat="signal")
    cy("Decor", "chrome", 0.6, 1.6, (-4, 1.6, 4.5), verts=10)                              # the fountain
    for i in range(3):
        cy("Decor", ("signal", "mint", "cream")[i], 0.35, 1.2, (-15 + i * 1.2, 2.2, 4.3), verts=8)
    for y in (-11.0, -5.0):
        bx("Booth", "signal", (10, 1.0, 3.6), (14, y - 2.2, 1.8), collision="box")            # seat backs
        bx("Decor", "signal", (10, 2.2, 1.6), (14, y - 1.0, 0.8))
        bx("Decor", "cream", (8, 2.4, 0.3), (14, y + 0.6, 2.8))                               # table
        cy("Decor", "chrome", 0.2, 2.6, (14, y + 0.6, 1.3), verts=6)
    T.rubble(10, -4, n=7, spread=5, seed=3)
    T.rubble(-10, 7, n=5, spread=4, seed=5)
    bx("Jukebox", "plum", (2.6, 2.2, 4.4), (-20, -12, 2.2), collision="box", bevel=0.4)
    cy("Decor", "hazard", 0.9, 0.3, (-20, -13.2, 3.4), rot=(90, 0, 0), verts=12)
    # outside: trash cans and a newspaper box by the door
    T.can(8, -D / 2 - 3)
    T.can(10.5, -D / 2 - 2.2, swatch="olive")
    bx("NewsBox", "signal", (1.8, 1.6, 3.2), (-8, -D / 2 - 2.2, 1.6), collision="box", bevel=0.15)
    T.scorch(0, -D / 2, 10.8, 10, 1.5)

    sockets = T.back_row(4, W, D, inset=2.8, margin=6)
    sockets["Survivor1"] = ((17, 4, 0.5), 0)
    sockets["BigFind"] = ((-16, -9, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "Diner", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_Diner")
