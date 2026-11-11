"""The intro cutscene's set: where everything stands (bible Section 4; A9). Shared by the set's
generators, the Blender scene that holds the camera (Intro_Scene.py) and the data module the game
reads (tools/cutscene_config.py), so the art, the camera path and the game can't drift apart.

Blender space, the lobby's frame (generators/Lobby/street_plan.py): the Steadfast showroom's
footprint centre is the origin, Main Street runs east (+X) to west along y = -96, north is +Y.
Studio turns it over like the lobby, (x, y, z) -> (-x, z, y), from the set's origin
(Tuning.Cutscene.SetOrigin), high above the run's world where nothing else shows.

The set is Main Street from the showroom east to Hill Road, and Mine Hill beyond it with the
Steadfast shelter's door at the top of a stepped path on the street's axis. The bomb falls
beyond the west end. Everything the camera needs stays within about 450 studs of it: at the
lowest graphics level Roblox draws nothing farther than about 500.
"""
from __future__ import annotations

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "Lobby"))
import street_plan as SP  # noqa: E402

N, S, WALK = SP.NORTH_Y, SP.SOUTH_Y, SP.WALK       # building lines -62 and -130, pavements 12 deep
R0, R1 = SP.ROAD                                   # the roadway: y from -118 to -74
AXIS = (R0 + R1) / 2                               # -96: Main Street's centre line
ROAD_TOP = SP.ROAD_TOP
X0, X1 = -66.0, 240.0                              # the street shown: the showroom's west end to Hill Road
CROSS = SP.CROSS                                   # a cross street, building line to building line
ELM = (X0 - CROSS, X0)                             # the cross street at the west end
HILL_ROAD = (X1, X1 + CROSS)                       # the road along the foot of Mine Hill
GROUND = (-250.0, 480.0, -360.0, 170.0)            # how far the ground goes: x0, x1, y0, y1

# -- Main Street: (block, front-left corner x, building line y, yaw) ---------------------------
BLOCKS = [
    ("Atomic", 76.0, N, 0), ("Gazette", 164.0, N, 0),
    ("Market", -6.0, S, 180), ("Vista", 80.0, S, 180), ("Hotel", 162.0, S, 180), ("Soda", 240.0, S, 180),
]
SHOWROOM = ("Lobby_Showroom", "Lobby_ShowroomHall", "Lobby_Frontage")      # at the origin, as in the lobby

# -- Mine Hill ------------------------------------------------------------------------------------
HILL_X = HILL_ROAD[1]                              # 280: the hill's foot
STAIR_FOOT_X = 286.0                               # the stepped path starts here ...
STAIR_TOP_X = 342.0                                # ... and reaches the terrace here
TERRACE_Z = 28.0
STAIR_W = 18.0                                     # the path's width
FLIGHTS, STEPS = 4, 8                              # four flights of eight steps with three landings between
DOOR_X = 356.0                                     # the portal's face: the door leaves hang just west of it
DOOR_W, DOOR_H = 20.0, 15.0                        # the opening
WALL_HALF = 30.0                                   # the headwall's half width; lower shoulders run on to CORRIDOR[1]
TERRACE = (STAIR_TOP_X, DOOR_X, AXIS - WALL_HALF, AXIS + WALL_HALF)   # the apron in front of the door: x0, x1, y0, y1
HALL_DEPTH = 26.0                                  # the hall behind the door (seen while it stands open)
LETTERS_X, LETTER_H = 370.0, 13.0                  # STEADFAST on the hillside above the portal
HEADWALL_H = 27.0                                  # the portal's headwall, above the terrace

# -- the bomb and what it does ------------------------------------------------------------------------
BLAST = (-150.0, AXIS, 0.0)                        # where the cloud stands: beyond the west end, on the street's axis
BOMB_FROM = (70.0, 70.0, 255.0)                    # the bomb's flight, seen from the terrace: high in the north-east ...
BOMB_TO = (-150.0, AXIS, 6.0)                      # ... down to the blast
RIDGE_X = -118.0                                   # the tree line that hides the cloud's foot


def stair_z(x: float) -> float:
    """The stepped path's height at x (the line through the steps' noses; landings are level)."""
    if x <= STAIR_FOOT_X:
        return 0.0
    if x >= STAIR_TOP_X:
        return TERRACE_Z
    run = STAIR_TOP_X - STAIR_FOOT_X
    landing = (run - FLIGHTS * STEPS * STEP_TREAD) / (FLIGHTS - 1)
    d = x - STAIR_FOOT_X
    z = 0.0
    for _ in range(FLIGHTS):
        flight = STEPS * STEP_TREAD
        if d <= flight:
            return z + d / STEP_TREAD * STEP_RISE
        d -= flight
        z += STEPS * STEP_RISE
        if d <= landing:
            return z
        d -= landing
    return TERRACE_Z


STEP_RISE = TERRACE_Z / (FLIGHTS * STEPS)          # 0.875
STEP_TREAD = 1.25
LANDING = ((STAIR_TOP_X - STAIR_FOOT_X) - FLIGHTS * STEPS * STEP_TREAD) / (FLIGHTS - 1)


def hill_z(x: float, y: float) -> float:
    """Mine Hill's ground height (before the terrace and the path are cut into it): it rises from
    Hill Road to a rounded top, lower towards its north and south ends."""
    if x <= HILL_X:
        return 0.0
    t = min(1.0, (x - HILL_X) / 170.0)
    rise = 96.0 * (t * t * (3 - 2 * t)) ** 0.9            # steep at first, rounding off at the top
    along = (y - (AXIS - 30.0)) / 260.0                   # the top stands a little south of the street's axis
    fall = math.exp(-along * along * 1.25)
    bumps = 3.2 * math.sin(x * 0.045 + y * 0.031) + 2.4 * math.sin(x * 0.021 - y * 0.052 + 1.7) + 1.3 * math.sin(y * 0.11 + 0.6)
    return max(0.0, rise * (0.34 + 0.66 * fall) + bumps * min(1.0, (x - HILL_X) / 40.0))


def stair_breaks() -> list[float]:
    """Where the path's slope changes: each flight's foot and head."""
    xs, x = [], STAIR_FOOT_X
    for i in range(FLIGHTS):
        xs.append(x)
        x += STEPS * STEP_TREAD
        xs.append(x)
        x += LANDING
    return xs


def _smooth(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


CORRIDOR = (30.0, 58.0)          # within 30 studs of the axis the ground is the path's; by 58 it is the hill's own


def ground_z(x: float, y: float) -> float:
    """Mine Hill's ground as built: hill_z, tapering to nothing at its north and south ends, with the
    path's corridor and the terrace laid into its west face. The cut ends at the door's line: a
    retaining wall holds it, tallest at the portal and running out to nothing at the corridor's edge."""
    gx0, gx1, gy0, gy1 = GROUND
    taper = _smooth((y - gy0) / 90.0) * _smooth((gy1 - y) / 90.0)
    nat = hill_z(x, y) * taper
    if x > DOOR_X:
        return nat
    d = abs(y - AXIS)
    w = 1.0 if d <= CORRIDOR[0] else _smooth((CORRIDOR[1] - d) / (CORRIDOR[1] - CORRIDOR[0]))
    target = max(stair_z(x) - 1.2, -0.4) if x < STAIR_TOP_X else TERRACE_Z - 1.2
    return nat + (target - nat) * w


def hill_trees() -> list[list]:
    """Pines and shade trees on Mine Hill, clear of the path and the sign: [asset, x, y, z, yaw, scale]."""
    rng = random.Random(24)
    out = []
    tries = 0
    while len(out) < 26 and tries < 2000:
        tries += 1
        x = rng.uniform(HILL_X + 14.0, 440.0)
        y = rng.uniform(GROUND[2] + 40.0, GROUND[3] - 30.0)
        if abs(y - AXIS) < 74.0 and x < 420.0:
            continue
        if any(math.hypot(x - o[1], y - o[2]) < 22.0 for o in out):
            continue
        if math.hypot(x - MINE[0], y - MINE[1]) < 40.0:
            continue
        z = ground_z(x, y) - 0.8
        out.append(["TreePine" if rng.random() < 0.62 else "TreeBig", round(x, 2), round(y, 2), round(z, 2), round(rng.uniform(0, 360), 1), round(rng.uniform(0.8, 1.15), 3)])
    return out


MINE = (388.0, AXIS - 128.0)     # the old Brightwater mine's headframe, on the hill's south shoulder

# -- the people's way: Main Street, across Hill Road, up the path, through the door --------------
RUN_FROM_X = 176.0               # where they stand when the siren starts
RUN_SPEED = 27.0                 # studs a second: a flat-out sprint
RUN_START = 1.6                  # the first of them bolts


def run_path() -> list[tuple[float, float, float]]:
    """The centre line they run: down Main Street, over Hill Road, up the path, across the terrace
    and into the hall. The steps are followed along their noses."""
    pts = [(RUN_FROM_X, AXIS, ROAD_TOP), (HILL_ROAD[1] - 7.0, AXIS, ROAD_TOP), (HILL_ROAD[1] - 6.0, AXIS, 0.06), (STAIR_FOOT_X, AXIS, 0.06)]
    for b in stair_breaks()[1:]:
        pts.append((b, AXIS, stair_z(b)))
    pts += [(DOOR_X + 3.0, AXIS, TERRACE_Z), (DOOR_X + HALL_DEPTH - 3.0, AXIS, TERRACE_Z)]
    return pts


def path_length(pts=None) -> float:
    pts = pts or run_path()
    return sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))


def path_at(s: float, pts=None) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    """The point s studs along the path and the way it heads there."""
    pts = pts or run_path()
    for a, b in zip(pts, pts[1:]):
        ln = math.dist(a, b)
        if s <= ln or b is pts[-1]:
            t = max(0.0, min(1.0, s / ln)) if ln > 0 else 0.0
            d = tuple((b[i] - a[i]) / ln for i in range(3))
            return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)), d
        s -= ln
    return pts[-1], (1.0, 0.0, 0.0)


# Who runs where in the pack: (seconds after the first, studs to the side of the centre line; + is north).
# Two files, one either side of the path's handrail. The game puts the player first, then the
# rest of the party, then the six founders.
RUNNERS = [(0.0, -3.4), (0.22, 3.6), (0.4, -6.0), (0.55, 5.8), (0.72, -2.8), (0.84, 3.0),
           (0.98, -5.6), (1.08, 5.4), (1.2, -3.2), (1.3, 3.4), (1.42, -6.2), (1.5, 6.0)]


# -- the ground: [name, x0, x1, y0, y1, z0, z1, swatch] ------------------------------------------------
def ground() -> list[list]:
    g = []
    gx0, gx1, gy0, gy1 = GROUND
    road, walk, kerb, grass = "gunmetal", "ash", "sandstone", "leaf"
    g.append(["Road", gx0, HILL_ROAD[1] - 6.0, R0, R1, -2.5, ROAD_TOP, road])
    for name, (a, b) in (("Elm", ELM), ("HillRoad", HILL_ROAD)):
        g.append([f"{name}North", a + 6, b - 6, R1, gy1, -2.5, ROAD_TOP, road])
        g.append([f"{name}South", a + 6, b - 6, gy0, R0, -2.5, ROAD_TOP, road])
        for j, (c, e) in enumerate(((a, a + 6), (b - 6, b))):
            if name == "HillRoad" and j == 1:
                g.append([f"{name}Walk{j + 1}", c, e, gy0, gy1, -2.5, 0.0, walk])       # the hill side's pavement runs unbroken
                continue
            g.append([f"{name}Walk{j + 1}N", c, e, N, gy1, -2.5, 0.0, walk])
            g.append([f"{name}Walk{j + 1}S", c, e, gy0, S, -2.5, 0.0, walk])
            g.append([f"{name}Corner{j + 1}N", c, e, R1, N, -2.5, 0.0, walk])
            g.append([f"{name}Corner{j + 1}S", c, e, S, R0, -2.5, 0.0, walk])
    for i, (a, b) in enumerate(((gx0, ELM[0]), (X0, X1))):
        g.append([f"WalkNorth{i + 1}", a, b, R1, N, -2.5, 0.0, walk])
        g.append([f"WalkSouth{i + 1}", a, b, S, R0, -2.5, 0.0, walk])
        g.append([f"KerbNorth{i + 1}", a, b, R1, R1 + 0.9, -2.4, 0.03, kerb])
        g.append([f"KerbSouth{i + 1}", a, b, R0 - 0.9, R0, -2.4, 0.03, kerb])
    g.append(["GroundNorth", gx0, HILL_ROAD[1], N, gy1, -3.0, -0.06, grass])
    g.append(["GroundSouth", gx0, HILL_ROAD[1], gy0, S, -3.0, -0.06, grass])
    x = gx0 + 8.0
    while x < HILL_ROAD[0] - 4.0:                            # the centre line
        if not (ELM[0] - 2 < x < ELM[1] + 2) and not (-12.0 < x < 12.0):
            g.append(["Dash", x, x + 6.0, AXIS - 0.25, AXIS + 0.25, -0.6, ROAD_TOP + 0.02, "cream"])
        x += 16.0
    for i in range(7):                                       # the crossing to the showroom's door
        xa = -9.1 + i * 2.6
        g.append(["Crossing", xa, xa + 1.5, R0 + 1.2, R1 - 1.2, -0.6, ROAD_TOP + 0.02, "porcelain"])
    for i in range(8):                                       # the crossing to the shelter's path
        ya = AXIS - 10.4 + i * 2.6
        g.append(["Crossing", HILL_ROAD[0] + 7.2, HILL_ROAD[1] - 7.2, ya, ya + 1.5, -0.6, ROAD_TOP + 0.02, "porcelain"])
    return g


CAR_PAINTS = ["teal", "signal", "hazard", "mint", "blush", "cream", "skyblue", "rust", "navy", "leaf", "plum", "porcelain"]


def cars() -> list[list]:
    """Parked cars: [kind, x, y, z, yaw, paint]. A car's nose is -Y at yaw 0; they face the traffic's way.
    The road's middle stays clear: the people run down it."""
    rng = random.Random(22)
    out = []
    north = [-52.0, -28.0, 22.0, 46.0, 96.0, 122.0, 172.0, 198.0]
    south = [-46.0, -18.0, 34.0, 60.0, 104.0, 150.0, 176.0, 216.0]
    i = 0
    for x in north:
        out.append(["CarPickup" if i % 4 == 2 else "CarSedan", round(x + rng.uniform(-1.5, 1.5), 2), R1 - 4.3, ROAD_TOP, round(270 + rng.uniform(-2, 2), 2),
                    CAR_PAINTS[i % len(CAR_PAINTS)]])
        i += 1
    for x in south:
        out.append(["CarPickup" if i % 4 == 2 else "CarSedan", round(x + rng.uniform(-1.5, 1.5), 2), R0 + 4.3, ROAD_TOP, round(90 + rng.uniform(-2, 2), 2),
                    CAR_PAINTS[(i * 5 + 3) % len(CAR_PAINTS)]])
        i += 1
    out.append(["CarSedan", ELM[0] + 12.0, N + 44.0, ROAD_TOP, 0, "cream"])                 # on Elm St
    out.append(["CarPickup", HILL_ROAD[0] + 11.5, S - 52.0, ROAD_TOP, 180, "rust"])         # on Hill Road
    out.append(["CarSedan", HILL_ROAD[0] + 11.5, N + 58.0, ROAD_TOP, 180, "skyblue"])
    # left in a hurry, doors' worth of space apart, noses to the shelter's path
    out.append(["CarSedan", HILL_ROAD[0] + 16.0, AXIS + 15.0, ROAD_TOP, 288, "blush"])
    out.append(["CarPickup", HILL_ROAD[0] + 13.0, AXIS - 16.5, ROAD_TOP, 255, "teal"])
    return out


def bunting() -> list[list]:
    """Strings from lamp to lamp, zigzagging down the street: [x, y, z, yaw, scale] (68 studs at scale 1)."""
    north, south = [], []
    for x in SP.FRONTAGE_LAMPS:
        north.append((x, N - WALK + 1.6))
    for name, ox, oy, yaw in BLOCKS:
        for lx in SP.lamp_xs(name):
            (north if yaw == 0 else south).append((ox + lx, oy - WALK + 1.6) if yaw == 0 else (ox - lx, oy + WALK - 1.6))
    both = sorted([(x, y, "n") for x, y in north] + [(x, y, "s") for x, y in south])
    out, last = [], None
    for x, y, side in both:
        if last and last[2] != side:
            ln = math.hypot(x - last[0], y - last[1])
            if ln <= 76.0 and min(abs(x), abs(last[0])) > 66.0:          # none across the showroom's front: its name must show
                out.append([last[0], last[1], SP.LAMP_TOP - 0.1, round(math.degrees(math.atan2(y - last[1], x - last[0])), 2), round(ln / 68.0, 4)])
        last = (x, y, side)
    return out


def far() -> list[list]:
    """The town and country around the street: [asset, x, y, z, yaw, scale]. Trees behind the blocks,
    the tree line beyond Elm St that hides the cloud's foot, the hills, the water tower."""
    rng = random.Random(23)
    out = []
    x = X0 + 20.0
    k = 0
    while x < X1 - 10.0:                                                 # behind the blocks
        out.append(["TreeClump", x, (92.0 if -80.0 < x < 80.0 else 30.0) + rng.uniform(-8, 10), 0.0, rng.uniform(-12, 12) + (180 if k % 2 else 0), rng.uniform(0.9, 1.2)])
        out.append(["TreeClump", x + rng.uniform(-10, 10), S - 96.0 + rng.uniform(-10, 8), 0.0, rng.uniform(-12, 12) + (0 if k % 2 else 180), rng.uniform(0.9, 1.2)])
        x += rng.uniform(52.0, 64.0)
        k += 1
    for y in (-330.0, -268.0, -206.0, -150.0, -42.0, 10.0, 66.0, 126.0):   # the tree line beyond Elm St
        out.append(["TreeClump", RIDGE_X + rng.uniform(-6, 6), y + rng.uniform(-6, 6), 0.0, 90 + rng.uniform(-10, 10), rng.uniform(1.15, 1.4)])
    for y in (-176.0, -150.0, -40.0, -14.0, 40.0):                         # trees along Elm St
        out.append(["TreeBig", ELM[0] - 9.0, y + rng.uniform(-5, 5), 0.0, rng.uniform(0, 360), rng.uniform(0.9, 1.15)])
    for y in (-300.0, -236.0, -176.0, 20.0, 84.0, 140.0):                  # trees along Hill Road, town side
        out.append(["TreePine" if int(y) % 3 == 0 else "TreeBig", HILL_ROAD[0] - 10.0 + rng.uniform(-3, 3), y + rng.uniform(-6, 6), 0.0, rng.uniform(0, 360), rng.uniform(0.85, 1.1)])
    out += [["Hill", -236.0, 150.0, -4.0, 20, 1.5], ["Hill", -250.0, -330.0, -4.0, 170, 1.7], ["Hill", 60.0, 300.0, -4.0, -20, 2.6],
            ["Hill", 20.0, -520.0, -4.0, 200, 3.0], ["Hill", 300.0, -560.0, -4.0, 150, 2.6], ["Hill", 330.0, 330.0, -4.0, 40, 2.6]]
    out.append(["WaterTower", 30.0, S - 118.0, 0.0, 12, 1.0])
    return [[f[0]] + [round(v, 2) for v in f[1:]] for f in out]


# -- when things happen (seconds from the cutscene's start; bible Section 4's six shots) ------------
SECONDS = 30.0
BEATS = {
    "SirenFrom": 0.8,            # the siren's horn starts to turn
    "RunStart": RUN_START,
    "BombFrom": 10.0, "BombTo": 15.0,                # the bomb's flight
    "DoorFrom": 12.75, "DoorTo": 14.35,              # the leaves roll shut
    "WheelFrom": 14.35, "WheelTo": 14.95,            # the wheel locks them
    "Sealed": 14.5,              # the SEALED lamp
    "Flash": 15.0,               # white
    "FireballFrom": 15.15, "FireballTo": 17.4,       # the fireball swells, then dims into the cloud
    "CloudFrom": 15.5, "CloudTo": 21.5,              # the cloud climbs
    "WaveFrom": 16.1, "WaveTo": 18.9,                # the shockwave crosses the town to the camera
    "DustFrom": 18.45, "DustTo": 19.5,               # it hits: dust over everything, then thinning
    "DiveFrom": 21.0, "DiveTo": 22.2,                # down into the hill
    "PlungeFrom": 22.2, "PlungeTo": 25.7,            # past the bunker
    "EyesFrom": 25.95, "EyesTo": 26.6,               # the Source's eyes open
    "Title": 27.0,
    "SettleFrom": 27.0, "SettleTo": 28.4,            # into the Command View
    "ZoomFrom": 28.7, "ZoomTo": 30.0,                # down to the player's character
}
WAVE_REACH = 560.0               # how far the shockwave's ring has spread at WaveTo
CLOUD = {"StemRadius": 20.0, "CapRadius": 92.0, "Top": 232.0}

# -- the bunker's side of it: the grid's space (Roblox axes from floor 1, column 0's floor centre) ----
GRID_PITCH = (34.0, 18.0)        # a column's width and a floor's height with their walls and slabs
STRATA = {"Bottom": 34.0, "Top": 162.0, "HalfWidth": 260.0}        # the rock between the hill and the bunker's top row
SOURCE_AT = (0.0, -152.0)        # the Source's great eye: column 0, floor 10 (the Source Chamber)
