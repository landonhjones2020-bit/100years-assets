"""Lobby_Blocks: Main Street, Brightwater, the day before the bomb (A9; bible Section 21: "Main
Street in sunshine: the same town players later see in ruins"). Ten blocks of two or three
buildings with the pavement's furniture in front of them; the Steadfast showroom stands between
the Hardware and Atomic blocks on the north side.

    python3 generators/Lobby/Lobby_Blocks.py Bank            # one block: Lobby_BlockBank
    python3 generators/Lobby/Lobby_Blocks.py                 # every block
    python3 generators/Lobby/Lobby_Blocks.py Frontage        # Lobby_Frontage: the showroom's pavement
    python3 generators/Lobby/Lobby_Blocks.py --street        # previews/Lobby/Lobby_Street.png: all of it

A block's frame: its buildings stand side by side from x = 0 (its left end, seen from the street)
with their fronts on y = 0; the pavement is y -12..0; the pivot is that front-left corner on the
ground. PLAN gives each block's place in the lobby (the showroom's frame: its footprint's centre
is the origin, the street is -Y); blocks on the south side are turned half round.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Town"))
import buildings as B  # noqa: E402
import props as P  # noqa: E402
import townkit as T  # noqa: E402

from street_plan import NORTH_Y, PLAN, SOUTH_Y, STREET_X, WALK, WIDTHS  # noqa: E402

FIZZY = [("Drink", "signal", "Lobster-Regular", 0.8), ("FIZZY POP", "teal", "AlfaSlabOne-Regular", 1.3), ("5 CENTS A BOTTLE", "navy", "Oswald-Bold", 0.5)]


def furnish(k, x0, x1, seed=1, lamps=True, meters=True, extras=()):
    """The pavement in front of x0..x1: a lamp and a tree by the kerb every 30 to 44 studs (lamp,
    tree, lamp, tree down the street), parking meters, and the listed extras
    [(name, x, y, yaw, kwargs)]. Things with a front (benches, boxes) face -Y, the street, at yaw 0."""
    rng = random.Random(seed)
    n = max(1, round((x1 - x0) / 36.0))          # street_plan.lamp_xs(): the bunting hangs from these lamps
    seg = (x1 - x0) / n
    if lamps:
        for i in range(n):
            xm = x0 + seg * (i + 0.5)
            with k.at((xm, -WALK + 1.6, 0), 90):
                P.street_lamp(k, banner=("teal", "signal")[(seed + i) % 2])
            with k.at((xm + seg * 0.36, -WALK + 2.6, 0), rng.uniform(0, 360)):
                P.tree(k, seed=seed * 5 + i * 3, h=rng.uniform(14.5, 17.0))
    if meters:
        x = x0 + 6.0
        while x < x1 - 4.0:
            with k.at((x, -WALK + 0.8, 0), 0):
                P.parking_meter(k)
            x += 14.0
    for name, x, y, yaw, kw in extras:
        with k.at((x, y, 0), yaw):
            getattr(P, name)(k, **kw)


def row(k, specs):
    """Buildings side by side from x = 0. specs: [(function name, width, kwargs)]. Returns the total width."""
    x = 0.0
    for fn, w, kw in specs:
        with k.at((x + w / 2, 0, 0)):
            if fn == "commercial":
                B.commercial(k, w, **kw)
            else:
                getattr(B, fn)(k, w, **kw)
        x += w
    return x


# -- the ten blocks ----------------------------------------------------------------------------

def block_bank(k):
    w = row(k, [
        ("bank", 44.0, dict(left_open=True)),
        ("commercial", 22.0, dict(floors=2, wall="cream", trim="porcelain", base="rust", band="rust", name="BARBER SHOP", font="Oswald-Bold", shop="barber",
                                  cover=None, door="left", top="simple", roof=("vents",), seed=11, courses=None, date="1934", upper="sash")),
    ])
    f = k.face((44.0, 0.0, 0.0), 0)
    B.barber_pole(k, f, 21.0, z=3.4)
    furnish(k, 0.0, w, seed=2, extras=[
        ("mailbox", 7.5, -9.2, 0, {}), ("bench", 58.5, -2.2, 0, {}), ("trash_can", 40.0, -9.6, 0, {}), ("hydrant", 3.6, -10.2, 0, {}),
        ("street_sign", 1.4, -10.8, 0, dict(a="MAIN ST", b="ELM ST")),
    ])
    return w


def block_hardware(k):
    w = row(k, [
        ("commercial", 24.0, dict(floors=1, wall="blush", trim="porcelain", base="mint", band="porcelain", name="Rosie's Bakery", name_sw="signal",
                                  font="Lobster-Regular", shop="bakery", shade=("blush", "porcelain"), top="simple", roof=("vents", "chimney"), seed=5, courses=None)),
        ("commercial", 38.0, dict(floors=2, wall="rust", name="HARDWARE", sub="TOOLS  ·  PAINT  ·  SEED", shop="hardware", shade=("signal", "porcelain"),
                                  top="bracket", roof=("tank", "vents"), right_open=True, side_ad=FIZZY, seed=3, date="1921", parapet="stepped", door="centre",
                                  lit=0.1)),
    ])
    furnish(k, 0.0, w, seed=4, extras=[
        ("sandwich_board", 6.0, -3.4, 12, dict(lines=("FRESH", "PIES 15"))), ("flower_tub", 2.4, -1.8, 0, dict(seed=3)), ("flower_tub", 21.6, -1.8, 0, dict(seed=5)),
        ("bench", 31.0, -2.2, 0, {}), ("trash_can", 58.0, -9.4, 0, {}), ("newspaper_box", 48.4, -2.0, 0, {}),
    ])
    return w


def block_atomic(k):
    w = row(k, [
        ("cinema", 54.0, dict(left_open=True)),
        ("commercial", 34.0, dict(floors=3, wall="sandstone", trim="porcelain", base="navy", band="navy", name="REXFORD DRUGS", sub="PRESCRIPTIONS  ·  SODA FOUNTAIN",
                                  font="Oswald-Bold", shop="drugs", cover="canopy", shade=("teal", "porcelain"), top="dentil", roof=("unit", "antenna"),
                                  blade=("DRUGS", "navy", "cream"), seed=8, courses="stone", upper="arched", lit=0.2)),
    ])
    furnish(k, 0.0, w, seed=6, extras=[
        ("phone_booth", 58.5, -2.6, 0, {}), ("bench", 80.0, -2.2, 0, {}), ("trash_can", 50.0, -9.6, 0, {}), ("hydrant", 84.0, -10.2, 0, {}),
    ])
    return w


def block_gazette(k):
    w = row(k, [
        ("commercial", 36.0, dict(floors=2, wall="leather", trim="sandstone", base="gunmetal", band="cream", name="THE BRIGHTWATER GAZETTE", name_sw="navy",
                                  font="Oswald-Bold", shop="news", cover=None, top="dentil", roof=("chimney", "antenna"), seed=13, courses="walnut",
                                  upper="arched", date="EST. 1889", parapet="gable", lit=0.3)),
        ("commercial", 40.0, dict(floors=2, wall="cream", trim="porcelain", base="rust", band="rust", name="BRIGHTWATER 5 & 10", sub="NOTHING OVER ONE DOLLAR",
                                  font="AlfaSlabOne-Regular", shop="goods", shade=("rust", "hazard"), top="deco", roof=("unit", "vents"), right_open=True,
                                  side_ad=[("SHOP", "navy", "Oswald-Bold", 0.5), ("Main Street", "signal", "Lobster-Regular", 1.2), ("BRIGHTWATER", "teal", "AlfaSlabOne-Regular", 0.9)],
                                  seed=17, courses=None, door="double", escape="right")),
    ])
    furnish(k, 0.0, w, seed=8, extras=[
        ("newspaper_box", 8.0, -2.0, 0, {}), ("newspaper_box", 10.2, -2.0, 0, dict(body="teal")), ("mailbox", 30.0, -9.2, 0, {}),
        ("bench", 56.0, -2.2, 0, {}), ("street_sign", 74.8, -10.8, 0, dict(a="MAIN ST", b="OAK ST")), ("trash_can", 70.0, -9.6, 0, {}),
    ])
    return w


def block_gas(k):
    w = 72.0
    with k.at((w / 2, 0, 0)):
        B.gas_station(k, w)
    # the lot's sides: a low enamel wall, a hedge along the back, a shade tree in the corner
    for (a, b) in ((0.2, 1.4), (w - 1.4, w - 0.2)):
        k.span("porcelain", a, b, 3.0, 61.0, 0.0, 1.2)
        k.span("teal", a - 0.08, b + 0.08, 2.92, 61.08, 1.2, 1.45)
        k.collide_span(a, b, 3.0, 61.0, 0.0, 3.0, name="Wall")
    k.span("forest", 53.0, w - 1.5, 59.2, 61.0, 0.0, 2.6)
    k.collide_span(53.0, w - 1.5, 59.2, 61.0, 0.0, 3.0, name="Hedge")
    with k.at((63.0, 50.0, 0), 40, scale=1.5):
        P.tree(k, seed=21, h=15.0, grate=False)
    for x, banner in ((12.0, "teal"), (46.0, "signal")):
        with k.at((x, -WALK + 1.6, 0), 90):
            P.street_lamp(k, banner=banner)
    furnish(k, 0.0, w, seed=10, lamps=False, meters=False, extras=[("street_sign", 70.6, -10.8, 0, dict(a="MAIN ST", b="ELM ST")), ("hydrant", 67.0, -10.2, 0, {}),
                                                                    ("mailbox", 3.0, -9.2, 0, {}), ("bench", 30.0, 35.6, 0, {}), ("trash_can", 4.6, 36.0, 0, {})])
    return w


def block_diner(k):
    w = 66.0
    with k.at((w / 2, 9.0, 0)):
        B.diner(k, 58.0)
    # the diner stands back: a strip of lawn and a low hedge either side of its walk
    for (a, b) in ((2.0, w / 2 - 5.0), (w / 2 + 5.0, w - 2.0)):
        k.span("leaf", a, b, 0.6, 8.2, 0.0, 0.25)
        k.span("forest", a, b, 0.6, 1.8, 0.25, 2.0)
        k.collide_span(a, b, 0.6, 1.8, 0.0, 2.0, name="Hedge")
    k.span("ash", w / 2 - 5.0, w / 2 + 5.0, 0.0, 9.0, 0.0, 0.08)
    furnish(k, 0.0, w, seed=12, extras=[
        ("sandwich_board", w / 2 - 7.0, -2.8, -10, dict(lines=("TODAY", "MEATLOAF"))), ("bench", 14.0, -1.6, 0, {}), ("trash_can", 54.0, -9.6, 0, {}),
        ("flower_tub", w / 2 - 6.4, 2.4, 0, dict(seed=7)), ("flower_tub", w / 2 + 6.4, 2.4, 0, dict(seed=9)),
    ])
    return w


def block_market(k):
    w = 60.0
    with k.at((w / 2, 0, 0)):
        B.market(k, w)
    furnish(k, 0.0, w, seed=14, extras=[("trash_can", 4.0, -9.6, 0, {}), ("mailbox", 55.0, -9.2, 0, {})])
    return w


def block_vista(k):
    w = row(k, [
        ("commercial", 32.0, dict(floors=2, wall="skyblue", trim="porcelain", base="navy", band="navy", name="VISTA", sub="TELEVISION  ·  RADIO  ·  HI-FI",
                                  font="BebasNeue-Regular", shop="tv", cover="canopy", shade=("signal", "porcelain"), top="deco", roof=("antenna", "unit"),
                                  blade=("TV", "signal", "cream"), seed=19, courses=None, upper="wide", lit=0.3)),
        ("commercial", 26.0, dict(floors=2, wall="blush", trim="porcelain", base="plum", band="plum", name="Dot's Dresses", font="Lobster-Regular", shop="dress",
                                  shade=("plum", "blush"), top="simple", roof=("vents",), seed=23, courses=None, parapet="stepped")),
        ("commercial", 28.0, dict(floors=1, wall="mint", trim="porcelain", base="teal", band="teal", name="HI-FI RECORDS", font="BebasNeue-Regular", shop="records",
                                  shade=("teal", "hazard"), top="deco", roof=("vents", "antenna"), seed=29, courses=None)),
    ])
    furnish(k, 0.0, w, seed=16, extras=[
        ("bench", 7.0, -2.2, 0, {}), ("flower_tub", 33.5, -1.8, 0, dict(seed=11)), ("flower_tub", 56.5, -1.8, 0, dict(seed=13)), ("trash_can", 60.0, -9.6, 0, {}),
        ("phone_booth", 82.0, -2.6, 0, {}),
    ])
    return w


def block_hotel(k):
    w = row(k, [
        ("commercial", 52.0, dict(floors=4, wall="rust", trim="sandstone", base="gunmetal", band="navy", name="THE BRIGHTWATER HOTEL", font="Oswald-Bold",
                                  shop="goods", cover="canopy", shade=("navy", "porcelain"), top="bracket", roof=("tank", "chimney", "vents"),
                                  blade=("HOTEL", "navy", "hazard"), seed=31, courses="leather", upper="arched", lit=0.35, door="centre", date="1912",
                                  parapet="stepped", stone_base=True)),
        ("commercial", 30.0, dict(floors=2, wall="hazard", trim="porcelain", base="signal", band="signal", name="TOYLAND", font="AlfaSlabOne-Regular", shop="toys",
                                  shade=("signal", "hazard"), top="simple", roof=("vents",), seed=37, courses=None)),
    ])
    furnish(k, 0.0, w, seed=18, extras=[
        ("bench", 12.0, -2.2, 0, {}), ("flower_tub", 20.0, -1.8, 0, dict(seed=15)), ("flower_tub", 32.0, -1.8, 0, dict(seed=17)), ("mailbox", 46.0, -9.2, 0, {}),
        ("trash_can", 76.0, -9.6, 0, {}),
    ])
    return w


def block_soda(k):
    w = row(k, [
        ("commercial", 30.0, dict(floors=2, wall="sandstone", trim="porcelain", base="walnut", band="walnut", name="KLINE'S SHOES", font="Oswald-Bold", shop="goods",
                                  shade=("leaf", "porcelain"), top="dentil", roof=("chimney",), seed=41, courses="stone")),
        ("commercial", 48.0, dict(floors=2, wall="porcelain", trim="teal", base="signal", band="signal", name="Fizzy Pop", sub="SODA FOUNTAIN  ·  ICE CREAM  ·  MALTS",
                                  font="Lobster-Regular", shop="drugs", cover="awning", shade=("signal", "porcelain"), top="deco", roof=("unit", "tank"), right_open=True,
                                  side_ad=FIZZY, seed=43, courses=None, door="double", upper="wide", blade=("SODA", "signal", "cream"), lit=0.2)),
    ])
    furnish(k, 0.0, w, seed=20, extras=[
        ("sandwich_board", 50.0, -3.2, 8, dict(lines=("MALTS", "20 CENTS"))), ("bench", 55.2, -2.2, 0, {}), ("trash_can", 30.0, -9.6, 0, {}),
        ("street_sign", 76.6, -10.8, 0, dict(a="MAIN ST", b="OAK ST")), ("hydrant", 72.0, -10.2, 0, {}),
    ])
    return w


def frontage(k):
    """Lobby_Frontage: the pavement in front of the showroom (its frame: the showroom's origin), from
    alley to alley: four lamps, trees clear of the door, benches facing the street, tubs by the way in."""
    y0 = NORTH_Y
    for i, x in enumerate((-49.5, -16.5, 16.5, 49.5)):
        with k.at((x, y0 - WALK + 1.6, 0), 90):
            P.street_lamp(k, banner=("teal", "signal")[i % 2])
    for i, x in enumerate((-62.0, -33.0, 33.0, 62.0)):
        with k.at((x, y0 - WALK + 2.6, 0), 40.0 * i):
            P.tree(k, seed=40 + i * 3, h=15.5 + (i % 2))
    for x in (-58.0, -44.0, -26.0, 26.0, 44.0, 58.0):
        with k.at((x, y0 - WALK + 0.8, 0), 0):
            P.parking_meter(k)
    for x in (-26.0, 26.0):
        with k.at((x, y0 - 1.9, 0), 0):
            P.bench(k)
    for i, x in enumerate((-11.5, 11.5, -40.0, 40.0)):
        with k.at((x, y0 - 1.8, 0), 0):
            P.flower_tub(k, seed=20 + i)
    with k.at((16.5, y0 - 3.2, 0), -8):
        P.sandwich_board(k, lines=("OPEN HOUSE", "TODAY"), ink="teal")
    with k.at((-55.0, y0 - WALK + 1.8, 0), 0):
        P.hydrant(k)
    with k.at((55.0, y0 - WALK + 2.8, 0), 0):
        P.mailbox(k)
    for x, body in ((-48.0, "hazard"), (-45.8, "teal")):
        with k.at((x, y0 - 2.0, 0), 0):
            P.newspaper_box(k, body=body)
    for x in (-8.0, 8.0):
        with k.at((x, y0 - WALK + 2.4, 0), 0):
            P.trash_can(k)
    return {"views": [("front", (0, -150, 26), (0, -66, 8), 50), ("walk", (-60, -70, 6), (0, -66, 6), 70)]}


BLOCKS = {
    "Bank": block_bank, "Hardware": block_hardware, "Atomic": block_atomic, "Gazette": block_gazette,
    "Gas": block_gas, "Diner": block_diner, "Market": block_market, "Vista": block_vista, "Hotel": block_hotel, "Soda": block_soda,
}

def views_for(w, name):
    return [
        ("front", (w / 2 + 4, -84, 9), (w / 2, 0, 13), 54),
        ("left", (-30, -46, 20), (w * 0.4, 6, 11), 54),
        ("walk", (w * 0.16, -8.5, 5.5), (w * 0.8, -1, 8), 70),
        ("right", (w + 32, -46, 20), (w * 0.6, 6, 11), 54),
    ]


def street(k):
    """The whole street in one scene (review only): every block where PLAN puts it."""
    for name, x, y, yaw in PLAN:
        with k.at((x, y, 0), yaw):
            BLOCKS[name](k)
    # the roadway and pavements, as the Studio builder lays them (tools/lobby_world.py), and grass
    x0, x1 = STREET_X
    k.span("gunmetal", x0 - 60, x1 + 60, SOUTH_Y + WALK, NORTH_Y - WALK, -0.7, -0.5)
    for (a, b) in ((NORTH_Y - WALK, NORTH_Y), (SOUTH_Y, SOUTH_Y + WALK)):
        k.span("ash", x0 - 60, x1 + 60, a, b, -0.7, 0.0)
    k.span("leaf", x0 - 300, x1 + 300, SOUTH_Y - 400, NORTH_Y + 400, -0.9, -0.71)
    for kind, x, y, yaw, paint in (("sedan", -92.0, -78.3, 270, "teal"), ("pickup", -52.0, -113.7, 90, "cream"), ("sedan", 34.0, -113.7, 90, "signal"),
                                   ("sedan", 96.0, -78.3, 270, "blush"), ("sedan", 150.0, -113.7, 90, "skyblue")):
        with k.at((x, y, -0.5), yaw):
            (P.car_sedan if kind == "sedan" else P.pickup)(k, paint=paint)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:]]
    if "--street" in args:
        import Lobby_Showroom as Show
        import Lobby_ShowroomHall as Hall

        def build(k):
            street(k)
            return {"views": [
                ("west", (-150, -100, 9), (40, -92, 16), 62),
                ("east", (190, -92, 9), (0, -98, 16), 62),
                ("spawn", (0, -112, 8), (0, -40, 18), 70),
                ("air", (60, -330, 190), (10, -80, 0), 44),
            ]}
        T.run(build, "Lobby_Street", "Lobby", context=(Show.exterior, Hall.hall, frontage), res=(1200, 660), ground=None)
        sys.exit(0)
    if "Frontage" in args:
        import Lobby_Showroom as Show
        T.run(frontage, "Lobby_Frontage", "Lobby", budget=8000, context=(Show.exterior,), res=(1000, 600))
        args.remove("Frontage")
        if not args:
            sys.exit(0)
    for name in (args or list(BLOCKS)):
        w = WIDTHS[name]

        def build(k, name=name, w=w):
            got = BLOCKS[name](k)
            assert abs(got - w) < 0.01, (name, got, w)
            return {"views": views_for(w, name), "meta": {"width": w}}
        T.run(build, f"Lobby_Block{name}", "Lobby", budget=30000, res=(1000, 600))
