"""Bldg_Motel: the Brightwater motel, after the bomb (A5; bible Section 12: rooms to search;
sometimes a survivor). Six rooms in a row off a covered walkway, doors kicked in, the MOTEL sign
on its pole at the end. 76 x 26 studs, front (-Y) on Main Street.
"""
import townlib as T
from townlib import bx, cy

W, D, H = 76.0, 26.0, 11.0
ROOMS = 6


def build():
    T.floor("stone", W, D)
    bx("Walkway", "sandstone", (W, 6, 0.4), (0, -D / 2 - 3, 0.2), collision="box")
    rw = W / ROOMS
    holes = []
    for i in range(ROOMS):
        x = -W / 2 + rw * (i + 0.5)
        holes += [(x - 4.5, x - 1.5, 0, 8.5), (x + 1, x + 5, 3.5, 8)]
    T.wall_x("skyblue", -W / 2, W / 2, -D / 2, 0, H, holes=holes, jag=[(-W / 2, H), (W / 2 - 14, H - 3), (W / 2 - 6, H - 5)])
    bx("Decor", "cream", (W + 0.3, 1.3, 1.1), (0, -D / 2, 0.55))
    for i in range(ROOMS):
        x = -W / 2 + rw * (i + 0.5)
        T.window_frame(x + 1, x + 5, -D / 2 - 0.1, 3.5, 8, swatch="cream")
        bx("Decor", ("signal", "teal", "hazard", "signal", "mint", "teal")[i], (3.2, 0.3, 8.4),
           (x - 3, -D / 2 - 0.9 - (0.8 if i % 2 else 0), 4.3), rot=(0, 0, 35 if i % 2 else -15))   # doors kicked in
        bx("Decor", "brass", (1.0, 0.2, 0.7), (x - 3, -D / 2 - 0.6, 9.4))                        # room numbers
        if 0 < i < ROOMS:
            T.wall_y("skyblue", -D / 2, D / 2 - 6, -W / 2 + rw * i, 0, H - 1, thick=0.8)
        # a bed and a nightstand in each room
        bx(T.uid("Bed"), "cream", (5, 7, 1.6), (x - 1.5, 2, 0.8), collision="box", bevel=0.2)
        bx("Decor", ("plum", "teal", "signal")[i % 3], (5.2, 4.6, 0.4), (x - 1.5, 1.2, 1.7))
        bx("Decor", "walnut", (1.6, 1.6, 2), (x + 2.6, 4.5, 1))
    T.wall_y("skyblue", -D / 2, D / 2, -W / 2, 0, H)
    T.wall_y("skyblue", -D / 2, D / 2, W / 2, 0, H, jag=[(-D / 2, H - 5), (0, H - 3)])
    T.wall_x("skyblue", -W / 2, W / 2, D / 2, 0, H)
    T.roof("stone", -W / 2, W / 2, -D / 2 - 6, D / 2, H, holes=[(10, 22, -16, -4), (-30, -24, 2, 8)], rim="cream")
    for i in range(ROOMS + 1):
        bx(T.uid("Post"), "cream", (0.8, 0.8, H), (-W / 2 + rw * i, -D / 2 - 5.6, H / 2), collision="box")
    # the sign on its pole by the road
    bx("Decor", "steel", (1.0, 1.0, 22), (-W / 2 - 4, -D / 2 - 9, 11))
    T.sign(-W / 2 - 4, -D / 2 - 9.4, 19, 10, 4.4, swatch="signal", rim="cream")
    bx("Decor", "glow", (6, 0.3, 1.2), (-W / 2 - 4, -D / 2 - 9.8, 15.4), mat="Neon")            # VACANCY, still lit
    T.rubble(16, -10, n=7, spread=6, seed=31, swatch="skyblue")

    sockets = {}
    for i in range(ROOMS):
        sockets[f"Container{i + 1}"] = ((-W / 2 + rw * (i + 0.5) + 2.4, D / 2 - 2.5, 0.5), 0.0)
    sockets["Survivor1"] = ((-W / 2 + rw * 1.5 - 1.5, -6, 0.5), 0)
    sockets["Survivor2"] = ((-W / 2 + rw * 4.5 - 1.5, -6, 0.5), 0)
    return {"export": {"sockets": sockets, "meta": {"place": "Motel", "w": W, "d": D}}}


if __name__ == "__main__":
    T.export(build, "Bldg_Motel")
