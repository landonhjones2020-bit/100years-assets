"""Lobby_ElevatorPad: an elevator to the bunker (A9; bible Section 21: "players start runs by
stepping onto elevator pads"). One stands in each of the showroom's six bays.

A cage lift of the kind a mine or a 1950s department store had: a steel floor (the part named
Floor: PadService counts whoever stands over it), corner posts, enamel panels and a scissor
lattice on three sides, a domed cap with its lamp, the driver's lever panel, and over the bay's
portal the sign (the part named Sign: PadController draws the pad's kind, riders, difficulty and
countdown on its front, the -Y face).

Origin: the pad's centre on the hall floor; front -Y (the hall). The sign hangs 8.2 studs in
front of the centre, on the hall side of the bay's partition (showroom_dims: BAY_Y - (PART - 0.6)
is 8.15).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402

HALF = 6.3          # the floor is 12.6 square
TOP = 12.6          # the cage's top ring (above the hall floor)
STEP = 0.5          # the floor's height
SIGN_Y = -8.75      # the sign's front, in front of the portal's frame
SIGN_Z = 16.9       # its centre above the hall floor (world 17.3)
SIGN_W, SIGN_H = 12.0, 4.4


def lattice(k, f, u0, u1, z0, z1, cells, swatch="gunmetal", r=0.06):
    """A scissor gate: crossing diagonals between u0..u1 and z0..z1."""
    w = (u1 - u0) / cells
    rows = max(1, round((z1 - z0) / (w * 1.6)))
    h = (z1 - z0) / rows
    for i in range(cells):
        for j in range(rows):
            a, b = u0 + i * w, u0 + (i + 1) * w
            c, d = z0 + j * h, z0 + (j + 1) * h
            k.pole(swatch, r, f.p(a, 0, c), f.p(b, 0, d), verts=3)
            k.pole(swatch, r, f.p(a, 0, d), f.p(b, 0, c), verts=3)
    for i in range(cells + 1):
        k.pole(swatch, r * 1.3, f.p(u0 + i * w, 0, z0), f.p(u0 + i * w, 0, z1), verts=4)


def build(k):
    # the floor: the one part players stand on (Role Floor) and a brass sill up to it
    k.role("Floor", "steel", (2 * HALF, 2 * HALF, STEP), (0, 0, STEP / 2), collision="box")
    k.span("gunmetal", -HALF - 0.2, HALF + 0.2, -HALF - 0.2, HALF + 0.2, 0, STEP - 0.12)
    for i in range(6):          # tread bars across the floor
        k.span("gunmetal", -HALF + 0.6, HALF - 0.6, -HALF + 1.2 + i * 2.05, -HALF + 1.5 + i * 2.05, STEP, STEP + 0.04, open_=("z-",))
    k.prism_x("brass", [(-HALF - 1.5, 0), (-HALF - 0.2, 0), (-HALF - 0.2, STEP), (-HALF - 0.5, STEP)], -HALF, HALF)
    # corner posts, the top ring, mid rails
    for sx in (-1, 1):
        for sy in (-1, 1):
            k.pole("chrome", 0.24, (sx * HALF, sy * HALF, STEP), (sx * HALF, sy * HALF, TOP), verts=6)
            k.cyl("gunmetal", 0.4, 0.3, (sx * HALF, sy * HALF, STEP + 0.15), verts=6)
    for (a, b) in (((-HALF, HALF, HALF), (HALF, HALF, HALF)), ((-HALF, -HALF, HALF), (-HALF, HALF, HALF)), ((HALF, -HALF, HALF), (HALF, HALF, HALF)),
                   ((-HALF, -HALF, HALF), (HALF, -HALF, HALF))):
        k.pole("gunmetal", 0.2, (a[0], a[1], TOP), (b[0], b[1], TOP), verts=5)
    # three sides: an enamel panel below, a lattice above
    sides = ((k.face((HALF, HALF, 0), 180), 2 * HALF), (k.face((-HALF, HALF, 0), 270), 2 * HALF), (k.face((HALF, -HALF, 0), 90), 2 * HALF))
    for f, ln in sides:
        f.box("teal", (ln - 0.5, 0.22, 4.2), (ln / 2, 0, STEP + 2.3))
        f.box("chrome", (ln - 0.3, 0.3, 0.22), (ln / 2, 0, STEP + 4.5))
        f.box("cream", (ln - 2.4, 0.26, 0.5), (ln / 2, 0, STEP + 3.1))
        lattice(k, f, 0.4, ln - 0.4, STEP + 4.7, TOP - 0.2, 6)
    # the folded gates at the front's two sides
    for sx in (-1, 1):
        for i in range(4):
            k.pole("gunmetal", 0.08, (sx * (HALF - 0.3 - i * 0.22), -HALF, STEP), (sx * (HALF - 0.3 - i * 0.22), -HALF, TOP - 0.2), verts=4)
        k.pole("brass", 0.1, (sx * (HALF - 1.25), -HALF - 0.2, STEP + 3.6), (sx * (HALF - 1.25), -HALF - 0.2, STEP + 5.0), verts=5)
    # the cap: a shallow enamel dome with a chrome rim and its lamp
    k.lathe("teal", [(HALF * 1.32, TOP), (HALF * 1.3, TOP + 0.5), (HALF * 0.9, TOP + 1.5), (HALF * 0.3, TOP + 2.0), (0, TOP + 2.05)], (0, 0, 0), verts=4,
            rot=(0, 0, 45), smooth=20.0)
    k.span("chrome", -HALF - 0.35, HALF + 0.35, -HALF - 0.35, HALF + 0.35, TOP - 0.1, TOP + 0.12)
    k.cyl("chrome", 1.6, 0.3, (0, 0, TOP - 0.2), verts=10)
    k.cyl("cream", 1.3, 0.16, (0, 0, TOP - 0.42), verts=10, mat="Neon", shadow=False)
    # the driver's panel on the back wall: a brass plate, a lever in its slot, two buttons, a dial
    back = k.face((-HALF, HALF - 0.12, 0), 0)        # the back wall, seen from inside the car
    back.on("brass", 4.3, 8.3, STEP + 5.2, STEP + 8.6, 0.3, n0=0.1)
    back.on("rubber", 5.0, 5.5, STEP + 5.7, STEP + 8.1, 0.36, n0=0.3)
    k.pole("chrome", 0.11, back.p(5.25, 0.3, STEP + 7.4), back.p(5.25, 1.3, STEP + 7.9), verts=5)
    k.sphere("signal", 0.26, back.p(5.25, 1.4, STEP + 7.95), segs=6, rings=4)
    back.cyl("leaf", 0.26, 0.2, (6.6, 0.42, STEP + 6.1), axis="n", verts=8)
    back.cyl("rust", 0.26, 0.2, (7.5, 0.42, STEP + 6.1), axis="n", verts=8)
    back.cyl("cream", 0.62, 0.1, (7.05, 0.36, STEP + 7.6), axis="n", verts=12)
    back.box("navy", (0.08, 0.06, 0.5), (7.05, 0.44, STEP + 7.8), roll=-35)
    # the sign over the portal (Role Sign: its front shows the pad's state), framed, on brass arms
    k.role("Sign", "navy", (SIGN_W, 0.3, SIGN_H), (0, SIGN_Y + 0.15, SIGN_Z))
    fz0, fz1 = SIGN_Z - SIGN_H / 2, SIGN_Z + SIGN_H / 2
    k.span("chrome", -SIGN_W / 2 - 0.3, SIGN_W / 2 + 0.3, SIGN_Y - 0.05, SIGN_Y + 0.5, fz0 - 0.3, fz0)
    k.span("chrome", -SIGN_W / 2 - 0.3, SIGN_W / 2 + 0.3, SIGN_Y - 0.05, SIGN_Y + 0.5, fz1, fz1 + 0.3)
    for sx in (-1, 1):
        k.span("chrome", sx * (SIGN_W / 2 + 0.15) - 0.15, sx * (SIGN_W / 2 + 0.15) + 0.15, SIGN_Y - 0.05, SIGN_Y + 0.5, fz0, fz1)
        k.sphere("brass", 0.3, (sx * (SIGN_W / 2 + 0.15), SIGN_Y + 0.2, fz1 + 0.5), segs=6, rings=4)
    k.span("teal", -SIGN_W / 2 - 0.2, SIGN_W / 2 + 0.2, SIGN_Y + 0.3, SIGN_Y + 0.62, fz0 - 0.2, fz1 + 0.2)
    k.socket("Rider", (0, 0, STEP), 180)
    return {"views": [
        ("front", (9, -30, 9), (0, 0, 8.6), 44),
        ("inside", (-2.5, -11, 6.5), (2, 6, 6.5), 70),
        ("top", (16, -18, 26), (0, 0, 6), 40),
    ], "meta": {"signFace": "Front"}}


if __name__ == "__main__":
    T.run(build, "Lobby_ElevatorPad", "Lobby", budget=3000, res=(800, 620), ground="#EFE3C4", sun_strength=2.6, sky=False, ambient=2.4)
