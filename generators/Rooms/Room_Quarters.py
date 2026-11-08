"""Room_Quarters: the Quarters' furniture for one cell, by level (A1; bible Section 6: beds, 4
per cell at level 1, 6 at level 2, 8 at level 3. Section 5: players resting in a Quarters bed
can skip the day to the Surge siren).

Steadfast bunk beds against the back wall (two beds each), foot lockers, a rag rug, a radio
table and pin-ups of Brightwater.

    L1  2 bunks (4 beds), olive blankets, a radio table
    L2  3 bunks (6 beds), teal blankets, reading lamps
    L3  4 bunks (8 beds), navy blankets with chrome rails, a jukebox

Sockets: Bed1..n (where a sleeper lies: lower bunks first), WorkSpot? none (no workers),
Light1.
"""
import roomlib as R
import steadfast as sf

BACK = R.BACK
BEDS = {1: 4, 2: 6, 3: 8}
BLANKET = {1: "olive", 2: "teal", 3: "navy"}
BUNK_W, BUNK_L = 4.0, 7.4


def bunk(x, level, sockets, index):
    y = BACK - 0.3 - BUNK_L / 2
    frame = "gunmetal" if level < 3 else "chrome"
    for dx in (-BUNK_W / 2, BUNK_W / 2):
        for dy in (-BUNK_L / 2, BUNK_L / 2):
            R.bx("Decor", frame, (0.3, 0.3, 8.6), (x + dx, y + dy, 4.3))
    for z, n in ((1.5, 0), (6.0, 1)):
        R.bx(R.uid("Bunk"), frame, (BUNK_W, BUNK_L, 0.3), (x, y, z - 0.45), collision="box")
        R.bx("Decor", "cream", (BUNK_W - 0.3, BUNK_L - 0.3, 0.6), (x, y, z))
        R.bx("Decor", BLANKET[level], (BUNK_W - 0.2, BUNK_L * 0.62, 0.7), (x, y - BUNK_L * 0.17, z + 0.05))
        R.bx("Decor", "porcelain", (BUNK_W - 0.8, 1.2, 0.5), (x, y + BUNK_L / 2 - 1.0, z + 0.45), bevel=0.15)
        sockets[f"Bed{index + n * 100}"] = ((x, y, z + 0.4), 0.0)
    for k in range(4):                     # a ladder at the foot
        R.bx("Decor", frame, (BUNK_W - 0.6, 0.12, 0.12), (x, y - BUNK_L / 2 - 0.1, 2.4 + k * 1.1))
    if level == 3:
        R.bx("Decor", "chrome", (0.15, BUNK_L - 0.6, 0.15), (x - BUNK_W / 2, y, 7.2))


def build(level: int) -> dict:
    sockets: dict = {}
    beds = BEDS[level]
    bunks = beds // 2
    span = 28.0
    pitch = span / bunks
    raw = {}
    for i in range(bunks):
        x = -span / 2 + pitch * (i + 0.5)
        bunk(x, level, raw, i + 1)
        R.footlocker(x, BACK - BUNK_L - 1.4, swatch="olive" if i % 2 else "teal")
    # number beds lower bunks first: Bed1..Bed<bunks> lower, then upper
    lower = sorted((k, v) for k, v in raw.items() if int(k[3:]) < 100)
    upper = sorted((k, v) for k, v in raw.items() if int(k[3:]) >= 100)
    for n, (_, v) in enumerate(lower + upper):
        sockets[f"Bed{n + 1}"] = v
    R.rug(0.0, -4.0, w=12.0, d=7.0, main="rust" if level < 3 else "navy", edge="cream")
    R.desk(-11.0, -10.5, w=4.0, d=2.4, body="walnut", top="walnut")
    R.bx("Decor", "olive", (1.8, 1.2, 1.3), (-11.6, -10.4, 3.7), bevel=0.15)          # radio
    for i in range(2):
        R.cy("Decor", "cream", 0.17, 0.12, (-12.0 + i * 0.6, -11.05, 3.6), rot=(90, 0, 0), verts=8)
    R.chair(-11.0, -13.0, yaw=0.0)
    R.poster(-11.0, 8.6, band="skyblue", accent="leaf", w=2.6, h=3.4, side="left")      # Brightwater pin-up
    R.clock(0.0, 12.6)
    if level >= 2:
        for i in range(bunks):            # reading lamps on the frames
            x = -span / 2 + pitch * (i + 0.5)
            R.cy("DecorNeon", "cream", 0.25, 0.4, (x + BUNK_W / 2, BACK - 1.0, 9.0), mat="Neon", verts=6, cast_shadow=False)
    if level == 3:                         # a jukebox by the right-hand front corner
        jx, jy = 11.5, -11.5
        R.bx("Jukebox", "walnut", (3.4, 2.4, 5.0), (jx, jy, 2.5), collision="box", bevel=0.3)
        R.t(sf.sphere(1.7, loc=(jx, jy, 5.0), scale=(1, 0.7, 0.6), segs=10, rings=4), "Decor", "walnut")
        R.bx("DecorNeon", "signal", (2.6, 0.12, 2.0), (jx, jy - 1.22, 3.4), mat="Neon", cast_shadow=False)
        R.bx("Decor", "chrome", (2.8, 0.15, 0.3), (jx, jy - 1.25, 2.1))
    sockets["Light1"] = ((0.0, -2.0, 12.0), 0.0)
    return sockets


if __name__ == "__main__":
    R.main("Room_Quarters", "Rooms", build, {"room": "Quarters", "shell": "Kit_Shell", "beds": BEDS})
