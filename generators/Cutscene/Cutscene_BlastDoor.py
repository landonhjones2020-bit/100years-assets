"""Cutscene_BlastDoor: the Steadfast shelter's door in Mine Hill, the morning the bomb fell (A9;
bible Section 4: "the blast door rolls shut").

The portal's headwall, a steel frame with hazard chevrons, and two slab leaves hung from
trolleys on a rail: they roll together from either side and a wheel locks them. Each leaf, the
wheel, the two beacons and the SEALED lamp are MeshParts of their own (Roles) for the cutscene to
move and light; the model is built with the door shut. Behind it, the hall with the lift's gate,
seen while the door stands open.

Its own frame: the threshold's centre on the terrace is the origin, the front (-Y) faces the
town, X runs along the wall. meta.leafTravel: how far a leaf rolls from open to shut.

    python3 generators/Cutscene/Cutscene_BlastDoor.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import cutscene_plan as CP  # noqa: E402
import townkit as T  # noqa: E402

W, H = CP.DOOR_W, CP.DOOR_H            # the opening: 20 by 15
HALF = CP.WALL_HALF                    # the headwall: 60 wide
TOP = CP.HEADWALL_H                    # 22.5 above the terrace
THICK = 3.0
LEAF_W = W / 2 + 0.3                   # each leaf laps the frame a little
LEAF_Y = (-2.05, -0.55)                # the leaves hang in front of the wall
RAIL_Z = H + 1.75
TRAVEL = W / 2 + 0.6


def headwall(k):
    for sx in (-1, 1):
        k.span("sandstone", sx * W / 2, sx * HALF, 0, THICK, -3.0, TOP)
        k.span("sandstone", sx * (HALF - 2.4), sx * HALF, -0.9, 0, -3.0, TOP - 0.4)           # end pilasters
        k.span("sandstone", sx * (W / 2 + 4.6), sx * (W / 2 + 7.0), -0.6, 0, -3.0, TOP - 0.4)
    k.span("sandstone", -W / 2, W / 2, 0, THICK, H, TOP)
    k.span("stone", -HALF - 0.5, HALF + 0.5, -1.3, THICK + 0.5, TOP, TOP + 1.1)                # the coping
    k.span("sandstone", -HALF - 0.2, HALF + 0.2, -0.7, THICK + 0.2, TOP - 0.7, TOP)
    for z in (3.75, 7.5, 11.25, 15.0, 18.75, 22.5):                                           # form lines
        for sx in (-1, 1):
            k.span("stone", sx * (W / 2 + 7.0), sx * (HALF - 2.4), -0.05, 0.0, z - 0.07, z + 0.07)
    k.span("stone", -HALF, HALF, -1.0, 0.0, -3.0, 0.7)                                         # the plinth
    # the name over the door
    k.span("teal", -14.2, 14.2, -0.5, 0.0, 21.9, 26.1)
    k.span("cream", -13.7, 13.7, -0.62, -0.5, 22.35, 25.65)
    k.text("navy", "STEADFAST SHELTER CO.", (0, -0.64, 24.5), 1.6, depth=0.16, font="AlfaSlabOne-Regular", max_w=25.6, flat=True)
    k.text("signal", "Brightwater Community Shelter", (0, -0.64, 23.0), 0.86, depth=0.16, font="Lobster-Regular", max_w=18.0, flat=True)


def frame(k):
    """The steel surround, chevrons down both jambs, the rail the leaves hang from."""
    for sx in (-1, 1):
        k.span("gunmetal", sx * W / 2, sx * (W / 2 + 1.5), -0.5, 0.2, 0.0, H + 0.6)
        n = 10
        for i in range(n):
            z0 = i * (H + 0.6) / n
            k.prism_y("hazard" if i % 2 == 0 else "rubber",
                      [(sx * (W / 2 + 0.05), z0), (sx * (W / 2 + 1.45), z0 + 0.9), (sx * (W / 2 + 1.45), z0 + 0.9 + (H + 0.6) / n),
                       (sx * (W / 2 + 0.05), z0 + (H + 0.6) / n)], -0.56, -0.5, smooth=-1.0)
    k.span("gunmetal", -W / 2 - 1.5, W / 2 + 1.5, -0.5, 0.2, H, H + 0.6)
    # the rail: an I-beam on brackets, stops at both ends
    k.span("gunmetal", -W - 2.0, W + 2.0, -1.9, -0.7, RAIL_Z, RAIL_Z + 0.3)
    k.span("gunmetal", -W - 2.0, W + 2.0, -1.45, -1.15, RAIL_Z + 0.3, RAIL_Z + 1.2)
    k.span("gunmetal", -W - 2.0, W + 2.0, -1.9, -0.7, RAIL_Z + 1.2, RAIL_Z + 1.5)
    for x in (-W - 1.4, -W / 2 - 3.2, -3.4, 3.4, W / 2 + 3.2, W + 1.4):
        k.prism_x("steel", [(-1.9, RAIL_Z + 1.5), (0.0, RAIL_Z + 1.5), (0.0, RAIL_Z + 3.4)], x - 0.3, x + 0.3)
    for sx in (-1, 1):
        k.span("rust", sx * (W + 1.4), sx * (W + 2.0), -2.2, -0.4, RAIL_Z - 1.2, RAIL_Z + 1.5)
    # a guide track in the floor
    k.span("gunmetal", -W - 1.6, W + 1.6, -1.75, -0.85, -0.02, 0.09)
    k.span("rubber", -W - 1.6, W + 1.6, -1.45, -1.15, 0.05, 0.1)


def leaf(k, side: int):
    """One leaf, shut: side -1 covers x from -LEAF_W to 0, side 1 the other half."""
    part = "LeafLeft" if side < 0 else "LeafRight"
    kw = dict(part=part, role=part)
    x0, x1 = (-LEAF_W, 0.0) if side < 0 else (0.0, LEAF_W)
    y0, y1 = LEAF_Y
    k.span("gunmetal", x0, x1, y0, y1, 0.12, H + 0.5, **kw)
    # a raised border and three ribs
    for a, b, c, d in ((x0, x1, 0.12, 0.9), (x0, x1, H - 0.3, H + 0.5)):
        k.span("steel", a, b, y0 - 0.22, y0, c, d, **kw)
    outer = x0 if side < 0 else x1
    k.span("steel", min(outer, outer - side * 0.8), max(outer, outer - side * 0.8), y0 - 0.22, y0, 0.9, H - 0.3, **kw)
    for z in (4.2, 10.9):
        k.span("steel", x0 + 0.3, x1 - 0.3, y0 - 0.16, y0, z - 0.22, z + 0.22, **kw)
    # rivets along the border
    for i in range(7):
        xr = x0 + 0.8 + i * (LEAF_W - 1.6) / 6
        for z in (0.5, H + 0.1):
            k.box("chrome", (0.22, 0.12, 0.22), (xr, y0 - 0.26, z), **kw)
    # hazard chevrons down the meeting edge
    inner = x1 if side < 0 else x0
    n = 9
    zs = (H - 1.2) / n
    for i in range(n):
        z0 = 0.9 + i * zs
        xa, xb = inner + side * 0.12, inner + side * 1.5
        top = z0 + zs * (1.5 if i < n - 1 else 1.0)
        k.prism_y("hazard" if i % 2 == 0 else "rubber", [(xa, z0 + zs * 0.5), (xb, z0), (xb, z0 + zs), (xa, top)], y0 - 0.2, y0 - 0.14, smooth=-1.0, **kw)
    k.prism_y("hazard", [(inner + side * 0.12, 0.9), (inner + side * 1.5, 0.9), (inner + side * 0.12, 0.9 + zs * 0.5)], y0 - 0.2, y0 - 0.14, smooth=-1.0, **kw)
    # half of the Steadfast sunburst: it closes when the leaves meet
    cz, r, half_n = 7.55, 3.6, 8
    pts = []
    for i in range(half_n + 1):
        a = math.pi / 2 + side * (-1) * i * math.pi / half_n * -1.0
        rr = r * (1.0 if i % 2 == 0 else 0.5)
        pts.append((side * abs(rr * math.cos(a)), cz + rr * math.sin(a)))
    k.prism_y("cream", pts, y0 - 0.3, y0 - 0.2, smooth=-1.0, **kw)
    disc = [(side * abs(r * 0.42 * math.sin(math.radians(a))), cz + r * 0.42 * math.cos(math.radians(a))) for a in range(0, 181, 20)]
    k.prism_y("teal", disc, y0 - 0.36, y0 - 0.3, smooth=-1.0, **kw)
    # hangers up to the trolleys on the rail
    for xh in (x0 + 1.6, x1 - 1.6):
        k.span("steel", xh - 0.35, xh + 0.35, y0 + 0.5, y0 + 0.9, H + 0.5, RAIL_Z + 1.9, **kw)
        k.cyl("rubber", 0.72, 0.5, (xh, -1.3, RAIL_Z + 2.1), rot=(90, 0, 0), verts=10, **kw)
        k.cyl("chrome", 0.3, 0.56, (xh, -1.3, RAIL_Z + 2.1), rot=(90, 0, 0), verts=6, **kw)
    # stencilled number
    k.text("cream", "STEAD" if side < 0 else "FAST", ((x0 + x1) / 2 + side * 0.4, y0 - 0.02, 12.9), 1.25, depth=0.06, font="Oswald-Bold", flat=True, **kw)
    k.text("cream", "SHELTER" if side < 0 else "No. 1", ((x0 + x1) / 2 + side * 0.4, y0 - 0.02, 2.4), 0.95, depth=0.06, font="Oswald-Bold", flat=True, **kw)


def wheel(k):
    """The locking wheel on the right leaf: a hub, four spokes, a rim, turning about its centre."""
    cx, cz, y = 5.4, 7.55, LEAF_Y[0] - 0.75
    kw = dict(part="Wheel", role="Wheel")
    segs = 12
    r = 1.75
    for i in range(segs):
        a0, a1 = 2 * math.pi * i / segs, 2 * math.pi * (i + 1) / segs
        k.pole("brass", 0.2, (cx + r * math.cos(a0), y, cz + r * math.sin(a0)), (cx + r * math.cos(a1), y, cz + r * math.sin(a1)), verts=5, **kw)
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        k.pole("brass", 0.15, (cx, y, cz), (cx + r * math.cos(a), y, cz + r * math.sin(a)), verts=4, **kw)
    k.cyl("brass", 0.55, 0.5, (cx, y, cz), rot=(90, 0, 0), verts=8, **kw)
    k.cyl("gunmetal", 0.34, 0.8, (cx, y + 0.5, cz), rot=(90, 0, 0), verts=6, part="LeafRight", role="LeafRight")
    k.socket("Wheel", (cx, y, cz), 0)


def lamps(k):
    """A beacon over each end of the rail, the SEALED lamp over the door, a lamp either side."""
    for sx, name in ((-1, "BeaconLeft"), (1, "BeaconRight")):
        x = sx * (W / 2 + 9.6)
        k.span("gunmetal", x - 0.9, x + 0.9, -1.8, 0.0, 20.0, 20.4)
        k.cyl("gunmetal", 0.85, 0.5, (x, -0.9, 20.65), verts=8)
        k.lathe("hazard", [(0.72, 0.0), (0.72, 0.95), (0.52, 1.45), (0.0, 1.62)], (x, -0.9, 20.9), verts=8, mat="Neon", shadow=False, part=name, role=name)
        k.socket(name, (x, -0.9, 21.6), 0)
    k.span("gunmetal", -4.6, 4.6, -0.75, 0.0, 19.75, 21.55)                # clear of the trolleys, under the name
    k.box("rubber", (8.6, 0.1, 1.3), (0, -0.8, 20.65))
    k.text("rust", "SEALED", (0, -0.86, 20.65), 0.95, depth=0.08, font="Oswald-Bold", mat="Neon", shadow=False, part="Sealed", role="Sealed")
    k.socket("Sealed", (0, -1.2, 20.65), 0)
    for sx in (-1, 1):                                                   # goose-neck lamps on the piers
        x = sx * (W / 2 + 14.6)
        k.wire("gunmetal", [(x, 0.0, 12.4), (x, -1.6, 13.0), (x, -2.3, 12.4)], r=0.14, verts=4)
        k.cyl("teal", 1.0, 0.7, (x, -2.3, 12.1), verts=8, r_top=0.3)
        k.sphere("cream", 0.45, (x, -2.3, 11.7), segs=6, rings=3, mat="Neon", shadow=False)
    # the call box and a notice board
    k.span("teal", W / 2 + 3.0, W / 2 + 4.3, -0.5, 0.0, 3.2, 5.4)
    k.span("cream", W / 2 + 3.2, W / 2 + 4.1, -0.56, -0.5, 4.3, 5.1)
    k.box("signal", (0.3, 0.12, 0.3), (W / 2 + 3.65, -0.58, 3.7))
    k.span("walnut", -W / 2 - 9.6, -W / 2 - 3.4, -0.3, 0.0, 3.0, 7.6)
    k.span("cream", -W / 2 - 9.3, -W / 2 - 3.7, -0.36, -0.3, 3.3, 7.3)
    k.text("rust", "DRILL TODAY", (-W / 2 - 6.5, -0.38, 6.5), 0.62, depth=0.05, font="Oswald-Bold", max_w=5.0, flat=True)
    k.text("navy", "ALL RESIDENTS", (-W / 2 - 6.5, -0.38, 5.4), 0.5, depth=0.05, font="Oswald-Bold", max_w=5.0, flat=True)
    k.text("navy", "10 A.M. SHARP", (-W / 2 - 6.5, -0.38, 4.6), 0.5, depth=0.05, font="Oswald-Bold", max_w=5.0, flat=True)


def hall(k):
    """Behind the door: cream walls over a teal dado, a striped floor, lamps, the lift's gate."""
    d, hw, hh = CP.HALL_DEPTH, W / 2 + 2.0, H + 1.0
    y0 = THICK
    k.span("ash", -hw, hw, 0.0, y0 + d, -0.6, 0.0)
    k.span("cream", -hw, hw, y0, y0 + d, hh, hh + 0.6)
    for sx in (-1, 1):
        k.span("cream", sx * hw, sx * (hw + 0.6), y0, y0 + d, 0.0, hh)
        k.span("teal", sx * (hw - 0.12), sx * hw, y0, y0 + d, 0.0, 4.2)
        k.span("signal", sx * (hw - 0.14), sx * hw, y0, y0 + d, 4.2, 4.5)
    k.span("cream", -hw, hw, y0 + d, y0 + d + 0.6, 0.0, hh)
    k.span("teal", -hw, hw, y0 + d - 0.12, y0 + d, 0.0, 4.2)
    for i in range(4):
        k.span("hazard" if i % 2 == 0 else "rubber", -hw + 0.4, hw - 0.4, y0 + 1.0 + i * 0.8, y0 + 1.8 + i * 0.8, 0.0, 0.04)
    for j in range(3):                                                    # ceiling lamps
        k.span("porcelain", -3.4, 3.4, y0 + 4.0 + j * 8.0, y0 + 5.6 + j * 8.0, hh - 0.3, hh - 0.05, mat="Neon", shadow=False)
        k.light((0, y0 + 4.8 + j * 8.0, hh - 3.0), colour="cream", brightness=1.6, range_=34)
    # the lift: a cage gate, its sign, the arrow down
    gy = y0 + d - 0.5
    k.span("gunmetal", -6.4, 6.4, gy - 0.5, gy, 0.0, 12.4, open_=("y-",))
    k.span("basalt", -5.6, 5.6, gy - 0.56, gy - 0.5, 0.4, 11.6)
    for i in range(9):
        x = -5.2 + i * 1.3
        k.span("brass", x - 0.09, x + 0.09, gy - 0.75, gy - 0.6, 0.4, 11.6)
    for z in (3.2, 6.4, 9.6):
        k.span("brass", -5.6, 5.6, gy - 0.78, gy - 0.66, z - 0.09, z + 0.09)
    k.span("teal", -4.0, 4.0, gy - 0.7, gy - 0.4, 12.9, 14.9)
    k.text("cream", "TO THE BUNKER", (0, gy - 0.74, 13.9), 0.95, depth=0.06, font="Oswald-Bold", max_w=7.2, flat=True)
    k.prism_y("hazard", [(-1.1, 12.2), (1.1, 12.2), (0.0, 11.0)], gy - 0.85, gy - 0.72, mat="Neon", shadow=False)


OPEN = os.environ.get("SF_OPEN") == "1"       # a look at the door standing open (previews only: it exports shut)


def build(k):
    assert not (OPEN and os.environ.get("SF_EXPORT") == "1"), "the door exports shut"
    headwall(k)
    frame(k)
    with k.at((-TRAVEL if OPEN else 0.0, 0, 0)):
        leaf(k, -1)
    with k.at((TRAVEL if OPEN else 0.0, 0, 0)):
        leaf(k, 1)
        wheel(k)
    lamps(k)
    hall(k)
    k.socket("Threshold", (0, 0, 0), 0)
    k.socket("Inside", (0, THICK + CP.HALL_DEPTH - 5.0, 0), 0)
    return {"meta": {"leafTravel": TRAVEL}, "views": [
        ("the portal", (-20.0, -70.0, 7.0), (0.0, 0.0, 11.5), 50),
        ("from the path's head", (3.0, -34.0, 4.5), (0.0, 0.0, 9.0), 62),
        ("close", (9.0, -15.0, 9.0), (2.0, 0.0, 8.0), 50),
        ("the hall", (0.0, -9.0, 6.0), (0.0, 24.0, 7.0), 80),
    ]}


if __name__ == "__main__":
    T.run(build, "Cutscene_BlastDoor", "Cutscene", budget=7000, step="A9", sun=(50, -20), ground="#8E8C88", sun_strength=3.2)
