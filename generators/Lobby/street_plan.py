"""Main Street's plan: where each block of the lobby stands (shared by Lobby_Blocks, which draws
them, and tools/lobby_world.py, which prints the Studio builder). Blender space, the showroom's
frame: its footprint's centre is the origin, the street is -Y, +X is east. Studio: (x, y, z) ->
(-x, z, y), the same yaw."""

NORTH_Y = -62.0          # the north side's building line (the showroom's forecourt reaches it)
SOUTH_Y = -130.0         # the south side's
WALK = 12.0              # pavement depth
ROAD = (SOUTH_Y + WALK, NORTH_Y - WALK)      # the roadway, y from -118 to -74
ROAD_TOP = -0.5          # the roadway lies half a stud under the pavements
WIDTHS = {"Bank": 66.0, "Hardware": 62.0, "Atomic": 88.0, "Gazette": 76.0, "Gas": 72.0, "Diner": 66.0, "Market": 60.0, "Vista": 86.0, "Hotel": 82.0,
          "Soda": 78.0}
# Each block's front-left corner (seen from the street) and which way it faces: 0 looks south onto
# the street from the north side, 180 north from the south side. West to east.
PLAN = [
    ("Bank", -204.0, NORTH_Y, 0), ("Hardware", -138.0, NORTH_Y, 0), ("Atomic", 76.0, NORTH_Y, 0), ("Gazette", 164.0, NORTH_Y, 0),
    ("Gas", -132.0, SOUTH_Y, 180), ("Diner", -66.0, SOUTH_Y, 180), ("Market", -6.0, SOUTH_Y, 180), ("Vista", 80.0, SOUTH_Y, 180),
    ("Hotel", 162.0, SOUTH_Y, 180), ("Soda", 240.0, SOUTH_Y, 180),
]
STREET_X = (-204.0, 240.0)       # the part players walk: Elm St to Oak St
CROSS = 40.0                     # a cross street's width, building line to building line
# Beyond the cross streets the town goes on (nobody walks there): the same blocks again.
BEYOND = [
    ("Gazette", -320.0, NORTH_Y, 0), ("Vista", -244.0, SOUTH_Y, 180),
    ("Hardware", 280.0, NORTH_Y, 0), ("Bank", 346.0, SOUTH_Y, 180),
]
# Lamps by the kerb: a block's are at these fractions of its width (furnish()); the gas station's
# are its own. The showroom's frontage (Lobby_Frontage) has four.
GAS_LAMPS = (12.0, 46.0)
FRONTAGE_LAMPS = (-49.5, -16.5, 16.5, 49.5)
LAMP_TOP = 17.0


def lamp_xs(name: str) -> list[float]:
    """A block's lamps, as distances along its front from its left end."""
    if name == "Gas":
        return list(GAS_LAMPS)
    w = WIDTHS[name]
    n = max(1, round(w / 36.0))
    return [w / n * (i + 0.5) for i in range(n)]


def lamps() -> tuple[list, list]:
    """Every lamp on the walked street: ([(x, y)] on the north kerb, [(x, y)] on the south)."""
    north = [(x, NORTH_Y - WALK + 1.6) for x in FRONTAGE_LAMPS]
    south = []
    for name, ox, oy, yaw in PLAN:
        for lx in lamp_xs(name):
            if yaw == 0:
                north.append((ox + lx, oy - WALK + 1.6))
            else:
                south.append((ox - lx, oy + WALK - 1.6))
    return sorted(north), sorted(south)
