"""cavelib: the Deep's cave pieces (A6; bible Sections 6, 12 and 19: "Caves are put together from
hand-made pieces for that band, so no two runs match"; "8 cave pieces at launch, from small
pockets to large caverns with a nest or a cache"; a cave piece is up to 8,000 triangles).

Every band has the same eight layouts, dressed in the band's look (Section 6: the Mines are timber
props, lanterns and old carts; the Flooded Caverns dripping rock, standing water and burst pipes):

    Entry       the mouth: a rock face that replaces the dug cell's back wall, and a short tunnel
    Tunnel      a straight run
    Junction    a T: the way splits left and right
    Pocket      a small dead end with two finds
    Chamber     a room with three finds, a way on and a way to the left
    Cavern      a big dead end with a nest spot and four finds
    Drop        the floor falls away down a slope (9 studs) to a lower tunnel
    CrewPocket  a dead end where a Steadfast work crew is trapped (three crew spots, a guard spot)

Space (STYLE.md): X across, -Y forward into the rock, Z up; the pivot is the entrance's floor
centre (0, 0, 0). Every piece is entered at y = 0 through a 14 x 12 opening and leaves through
the same size of opening at its exits, so any exit takes any piece's entrance.

Sockets (Studio: Socket_<name> CFrames): Entry (yaw 180: facing back out), Exit1.. (facing out of
the piece), Find1.. (loot, ore veins, people), Spawn1.. (guards), Nest, Crew1..3, Light1.. Find,
Crew and Nest spots stand at least 8 studs from each other (the nearest prompt per key wins).
meta: piece kind, band, weight, and the local box (Roblox space, from the pivot) the cave
planner (Shared.Rules.Deep) keeps pieces from overlapping with.

Collision: floors, walls and ceilings are boxes (players walk on flat floors; PathfindingService
plans on them), the Drop's slope a hull; the rock you see is boulders with no collision, set so
their inner faces sit on the walls.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Rooms"))
sys.path.insert(0, os.path.join(HERE, "..", "Kits"))
sys.path.insert(0, os.path.join(HERE, "..", "Monsters"))
import steadfast as sf  # noqa: E402
import roomlib as R  # noqa: E402
from roomlib import bx, cy, t, uid  # noqa: E402,F401
from Kit_Rubble import lump  # noqa: E402

BUDGET = 8000          # cave piece (bible Section 19)
TW, TH = 14, 12        # every opening: 14 wide, 12 tall

BANDS = {
    "Mines": {"rock": "sandstone", "dark": "stone", "floor": "stone", "wall": "basalt", "ceiling": "basalt"},
    "Flooded": {"rock": "stone", "dark": "murk", "floor": "basalt", "wall": "basalt", "ceiling": "basalt"},
    # the Crystal Hollows (A10; bible Section 6: "Glowing crystal, radiation"): the bunker kit's plum and basalt
    "Crystal": {"rock": "plum", "dark": "basalt", "floor": "basalt", "wall": "basalt", "ceiling": "basalt"},
}
BAND_ID = {"Mines": "Mines", "Flooded": "FloodedCaverns", "Crystal": "CrystalHollows"}

# The eight layouts: footprint rectangles (x0, x1, y0, y1) at floor z0, ceiling h, the openings
# (side, centre along that side, the side's coordinate), sockets and the planner's weight.
LAYOUTS = {
    "Entry": dict(rects=[(-7, 7, -24, 0)], h=TH, weight=0, plate=True,
                  openings=[("+Y", 0, 0), ("-Y", 0, -24)],
                  sockets={"Exit1": ((0, -24, 0), 0), "Light1": (0, -14, TH - 1.6)}),
    "Tunnel": dict(rects=[(-7, 7, -32, 0)], h=TH, weight=4,
                   openings=[("+Y", 0, 0), ("-Y", 0, -32)],
                   sockets={"Exit1": ((0, -32, 0), 0), "Find1": ((-4, -16, 0), 90), "Light1": (0, -9, TH - 1.6)}),
    "Junction": dict(rects=[(-7, 7, -12, 0), (-26, 26, -26, -12)], h=TH, weight=3,
                     openings=[("+Y", 0, 0), ("-X", -19, -26), ("+X", -19, 26)],
                     sockets={"Exit1": ((-26, -19, 0), -90), "Exit2": ((26, -19, 0), 90), "Find1": ((0, -23, 0), 180),
                              "Light1": (0, -19, TH - 1.6)}),
    "Pocket": dict(rects=[(-7, 7, -4, 0), (-11, 11, -24, -4)], h=TH, weight=3,
                   openings=[("+Y", 0, 0)],
                   sockets={"Find1": ((-6, -19, 0), 180), "Find2": ((6, -19, 0), 180), "Spawn1": (0, -12, 0),
                            "Light1": (0, -13, 10.4)}),
    "Chamber": dict(rects=[(-18, 18, -36, 0)], h=16, weight=3,
                    openings=[("+Y", 0, 0), ("-Y", 0, -36), ("-X", -24, -18)],
                    sockets={"Exit1": ((0, -36, 0), 0), "Exit2": ((-18, -24, 0), -90),
                             "Find1": ((12, -9, 0), 180), "Find2": ((13, -30, 0), 180), "Find3": ((-12, -8, 0), 180),
                             "Spawn1": (0, -18, 0), "Spawn2": (6, -24, 0), "Light1": (0, -10, 14.4), "Light2": (0, -27, 14.4)}),
    "Cavern": dict(rects=[(-7, 7, -4, 0), (-26, 26, -52, -4)], h=22, weight=2,
                   openings=[("+Y", 0, 0)],
                   sockets={"Nest": ((0, -42, 0), 180), "Find1": ((-18, -14, 0), 180), "Find2": ((18, -14, 0), 180),
                            "Find3": ((-19, -42, 0), 180), "Find4": ((19, -42, 0), 180),
                            "Spawn1": (0, -22, 0), "Spawn2": (-10, -30, 0), "Spawn3": (10, -30, 0),
                            "Light1": (0, -16, 20), "Light2": (0, -38, 20), "Light3": (-17, -28, 17), "Light4": (17, -28, 17)}),
    "Drop": dict(rects=[(-7, 7, -34, 0)], h=TH, weight=2, drop=9,
                 openings=[("+Y", 0, 0), ("-Y", 0, -34, -9)],
                 sockets={"Exit1": ((0, -34, -9), 0), "Find1": ((4, -30.5, -9), 180), "Light1": (0, -17, 8)}),
    "CrewPocket": dict(rects=[(-7, 7, -4, 0), (-15, 15, -32, -4)], h=14, weight=0,
                       openings=[("+Y", 0, 0)],
                       sockets={"Crew1": ((-8, -26, 0), 180), "Crew2": ((0, -28.5, 0), 180), "Crew3": ((8, -26, 0), 180),
                                "Nest": ((0, -11, 0), 180), "Find1": ((11.5, -13, 0), 180),
                                "Light1": (0, -21, 12.4), "Light2": (-9, -9, 12.4)}),
}


# Footprint -------------------------------------------------------------------------------------

def _cells(rects):
    filled = set()
    for (x0, x1, y0, y1) in rects:
        for i in range(int(x0), int(x1)):
            for j in range(int(y0), int(y1)):
                filled.add((i, j))
    return filled


def _runs(rects):
    """The footprint's outline as runs: (side, fixed, a, b). Side is the outward normal: +Y and -Y
    runs lie along X at y = fixed, +X and -X along Y at x = fixed."""
    filled = _cells(rects)
    edges = {"+Y": {}, "-Y": {}, "+X": {}, "-X": {}}
    for (i, j) in filled:
        if (i, j + 1) not in filled:
            edges["+Y"].setdefault(j + 1, []).append(i)
        if (i, j - 1) not in filled:
            edges["-Y"].setdefault(j, []).append(i)
        if (i + 1, j) not in filled:
            edges["+X"].setdefault(i + 1, []).append(j)
        if (i - 1, j) not in filled:
            edges["-X"].setdefault(i, []).append(j)
    runs = []
    for side, by in edges.items():
        for fixed, starts in by.items():
            starts.sort()
            a = prev = starts[0]
            for s in starts[1:] + [None]:
                if s is None or s != prev + 1:
                    runs.append((side, fixed, a, prev + 1))
                    if s is not None:
                        a = s
                if s is not None:
                    prev = s
    return runs


def _cut(runs, openings):
    """Take the openings out of the outline: each is TW wide, centred on its spot."""
    out = []
    for (side, fixed, a, b) in runs:
        pieces = [(a, b)]
        for (oside, centre, ofixed, *_) in openings:
            if oside != side or abs(ofixed - fixed) > 1e-6:
                continue
            lo, hi = centre - TW / 2, centre + TW / 2
            nxt = []
            for (p, q) in pieces:
                if hi <= p or lo >= q:
                    nxt.append((p, q))
                    continue
                if lo > p:
                    nxt.append((p, lo))
                if hi < q:
                    nxt.append((hi, q))
            pieces = nxt
        out += [(side, fixed, p, q) for (p, q) in pieces if q - p > 0.01]
    return out


NORMAL = {"+Y": (0, 1), "-Y": (0, -1), "+X": (1, 0), "-X": (-1, 0)}


def _along(side, fixed, s):
    """A point on a run: s along it."""
    return (s, fixed) if side in ("+Y", "-Y") else (fixed, s)


# The shell -----------------------------------------------------------------------------------------

class Shell:
    """Floors, walls and a ceiling to collide with, and boulders over them to look at."""

    def __init__(self, band, layout, seed):
        self.band = BANDS[band]
        self.layout = layout
        self.rnd = random.Random(seed)
        self.rocks = 0

    def collision(self):
        lay, b = self.layout, self.band
        h, drop = lay["h"], lay.get("drop", 0)
        for (x0, x1, y0, y1) in lay["rects"]:
            if drop:
                # the Drop: a high floor, a slope, a low floor, one tall space over them
                bx(uid("Floor"), b["floor"], (x1 - x0, 8, drop + 1), ((x0 + x1) / 2, -4, -drop / 2 - 0.5), collision="box")
                bx(uid("Floor"), b["floor"], (x1 - x0, y1 - y0 - 8, 1), ((x0 + x1) / 2, (y0 + y1 - 8) / 2 - 4 + 4, -drop - 0.5),
                   collision="box")
                run = 18.0
                ang = math.degrees(math.atan2(drop, run))
                length = math.hypot(drop, run)
                bx("Slope", b["floor"], (x1 - x0, length, 0.8), ((x0 + x1) / 2, -8 - run / 2, -drop / 2 - 0.35),
                   rot=(ang, 0, 0), collision="hull")
                bx(uid("Ceiling"), b["ceiling"], (x1 - x0, y1 - y0, 1), ((x0 + x1) / 2, (y0 + y1) / 2, h + 0.5), collision="box")
                continue
            bx(uid("Floor"), b["floor"], (x1 - x0, y1 - y0, 1), ((x0 + x1) / 2, (y0 + y1) / 2, -0.5), collision="box")
            bx(uid("Ceiling"), b["ceiling"], (x1 - x0, y1 - y0, 1), ((x0 + x1) / 2, (y0 + y1) / 2, h + 0.5), collision="box")
        z0 = -drop if drop else 0
        self.walls = _cut(_runs(lay["rects"]), lay["openings"])
        for (side, fixed, a, c) in self.walls:
            nx, ny = NORMAL[side]
            mx, my = _along(side, fixed, (a + c) / 2)
            size = (c - a, 1, h - z0) if side in ("+Y", "-Y") else (1, c - a, h - z0)
            bx(uid("Wall"), b["wall"], size, (mx + nx * 0.5, my + ny * 0.5, (h + z0) / 2), collision="box")
        # the lintel over each 12-tall opening in a taller wall (and the sill under one high
        # in it: the Drop's low exit)
        for (side, centre, fixed, *rest) in lay["openings"]:
            oz = rest[0] if rest else 0.0
            nx, ny = NORMAL[side]
            mx, my = _along(side, fixed, centre)
            if h > oz + TH + 0.25:
                size = (TW, 1, h - oz - TH) if side in ("+Y", "-Y") else (1, TW, h - oz - TH)
                bx(uid("Wall"), b["wall"], size, (mx + nx * 0.5, my + ny * 0.5, oz + TH + (h - oz - TH) / 2), collision="box")
            if oz > z0 + 0.25:
                size = (TW, 1, oz - z0) if side in ("+Y", "-Y") else (1, TW, oz - z0)
                bx(uid("Wall"), b["wall"], size, (mx + nx * 0.5, my + ny * 0.5, z0 + (oz - z0) / 2), collision="box")

    def boulders(self, spacing=3.8, rmin=2.0, rmax=3.2, step=1.45, segs=6, rings=4):
        """Rock over every wall: boulders whose inner faces sit on the wall line."""
        lay, b, rnd = self.layout, self.band, self.rnd
        self.segs, self.rings = segs, rings
        h, drop = lay["h"], lay.get("drop", 0)
        z0 = -drop if drop else 0
        for (side, fixed, a, c) in self.walls:
            nx, ny = NORMAL[side]
            n = max(1, int(round((c - a) / spacing)))
            for k in range(n + 1):
                s = a + (c - a) * k / n
                z = z0 + rmax * 0.55
                while z < h + 0.5:
                    r = rnd.uniform(rmin, rmax)
                    x, y = _along(side, fixed, s + rnd.uniform(-0.6, 0.6))
                    out = r * rnd.uniform(0.5, 0.62)       # about a third of each boulder bulges into the cave
                    self.rock((x + nx * out, y + ny * out, z), r)
                    z += r * step
        # the ceiling: a few big slabs of rock hanging down
        for (x0, x1, y0, y1) in lay["rects"]:
            area = (x1 - x0) * (y1 - y0)
            for k in range(max(3, int(area / 55))):
                r = rnd.uniform(rmin * 1.1, rmax * 1.35)
                self.rock((rnd.uniform(x0 + 2, x1 - 2), rnd.uniform(y0 + 2, y1 - 2), h + r * 0.45), r, swatch=b["dark"])

    def rock(self, loc, r, swatch=None):
        self.rocks += 1
        segs, rings = getattr(self, "segs", 6), getattr(self, "rings", 4)
        return lump("Decor", loc, r, self.rnd.randint(0, 10 ** 6), segs=segs, rings=rings,
                    swatch=swatch or (self.band["rock"] if self.rnd.random() < 0.7 else self.band["dark"]))

    def rubble(self, n, area, rmin=0.5, rmax=1.3):
        x0, x1, y0, y1 = area
        for k in range(n):
            lump("Decor", (self.rnd.uniform(x0, x1), self.rnd.uniform(y0, y1), 0), self.rnd.uniform(rmin, rmax),
                 self.rnd.randint(0, 10 ** 6), segs=5, rings=4, swatch=self.band["dark"], resting=True)

    def opening_rims(self):
        """Bigger boulders framing each way on, so the openings read from across the piece."""
        for (side, centre, fixed, *rest) in self.layout["openings"]:
            oz = rest[0] if rest else 0.0
            nx, ny = NORMAL[side]
            for sgn in (-1, 1):
                x, y = _along(side, fixed, centre + sgn * (TW / 2 + 1.2))
                self.rock((x + nx * 1.4, y + ny * 1.4, oz + 2.4), 2.8)
                self.rock((x + nx * 1.6, y + ny * 1.6, oz + 7.4), 2.6)
            x, y = _along(side, fixed, centre)
            self.rock((x + nx * 1.6, y + ny * 1.6, oz + TH + 1.8), 3.2)


# Dressing ------------------------------------------------------------------------------------------

def lantern(x, y, z, band):
    """A hanging lamp at a Light socket: brass cage, a glowing glass (the PointLight is added in game)."""
    glow = "hazard" if band == "Mines" else "crystal"   # the Flooded Caverns and the Crystal Hollows: pale cyan
    bx("Decor", "brass", (0.7, 0.7, 0.15), (x, y, z + 0.55))
    cy("DecorNeon", glow, 0.28, 0.75, (x, y, z), mat="Neon", cast_shadow=False)
    for (dx, dy) in ((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3)):
        bx("Decor", "brass", (0.08, 0.08, 0.9), (x + dx, y + dy, z))
    bx("Decor", "gunmetal", (0.08, 0.08, 1.4), (x, y, z + 1.3))


def timber_frame(y, h, half=TW / 2 - 0.9, z0=0.0, leaning=0.0):
    """A pit prop: two posts and a cap beam (the Mines' look), against the walls."""
    for sx in (-1, 1):
        bx("Decor", "walnut", (0.9, 0.9, h - z0 - 0.4), (sx * half, y, z0 + (h - z0 - 0.4) / 2), rot=(0, sx * leaning, 0))
    bx("Decor", "pine", (half * 2 + 1.6, 1.0, 1.0), (0, y, h - 0.9))


def rails(y0, y1, z=0.0):
    for sx in (-1.6, 1.6):
        bx("Decor", "steel", (0.25, abs(y1 - y0), 0.25), (sx, (y0 + y1) / 2, z + 0.32))
    n = int(abs(y1 - y0) // 2.5)
    for k in range(n):
        bx("Decor", "walnut", (4.4, 0.6, 0.2), (0, y0 - 1.2 - k * 2.5 if y1 < y0 else y0 + 1.2 + k * 2.5, z + 0.1))


def ore_cart(x, y, rot=0.0, tipped=False):
    rz = rot
    rx = 70 if tipped else 0
    bx(uid("Cart"), "rust", (3.0, 4.2, 2.2), (x, y, 1.9 if not tipped else 1.5), rot=(rx, 0, rz), collision="box")
    bx("Decor", "gunmetal", (3.2, 4.4, 0.3), (x, y, 3.0 if not tipped else 2.6), rot=(rx, 0, rz))
    if not tipped:
        for dx in (-1.4, 1.4):
            for dy in (-1.4, 1.4):
                ca, sa = math.cos(math.radians(rz)), math.sin(math.radians(rz))
                cy("Decor", "steel", 0.5, 0.3, (x + dx * ca - dy * sa, y + dx * sa + dy * ca, 0.55), rot=(0, 90, rz), verts=8)


def crate_stack(x, y, n=2, size=2.4, seed=1):
    rnd = random.Random(seed)
    for k in range(n):
        R.crate(x + rnd.uniform(-0.4, 0.4), y + rnd.uniform(-0.4, 0.4), z=k * size * 0.9, size=size)


def pool(x, y, w, d, band="Flooded"):
    """Standing water (the Flooded Caverns): a still sheet over a dark bed."""
    bx("Decor", "murk", (w, d, 0.12), (x, y, 0.06))
    bx("Water", "skyblue", (w - 0.6, d - 0.6, 0.1), (x, y, 0.2), mat="Glass", transparency=0.55, cast_shadow=False)


def stalactites(rnd, rect, h, n, swatch="stone"):
    x0, x1, y0, y1 = rect
    for k in range(n):
        x, y = rnd.uniform(x0 + 1.5, x1 - 1.5), rnd.uniform(y0 + 1.5, y1 - 1.5)
        length = rnd.uniform(1.6, 3.6)
        cone = sf.cyl(rnd.uniform(0.35, 0.6), length, loc=(x, y, h - length / 2), verts=6, bevel=0.0)
        for v in cone.data.vertices:
            if v.co.z < 0:
                v.co.x *= 0.15
                v.co.y *= 0.15
        t(cone, "Decor", swatch)


def pipe_run(y0, y1, x, z, burst_at=None, swatch="rust"):
    """An old water main along a wall, broken open somewhere (the Flooded Caverns' burst pipes)."""
    a, b = (y0, burst_at - 0.8) if burst_at else (y0, y1)
    cy("Decor", swatch, 0.55, abs(b - a), (x, (a + b) / 2, z), rot=(90, 0, 0), verts=10)
    if burst_at:
        cy("Decor", swatch, 0.55, abs(y1 - burst_at - 0.8), (x, (burst_at + 0.8 + y1) / 2, z - 0.5), rot=(80, 0, 12), verts=10)
        cy("Decor", "copper", 0.7, 0.4, (x, burst_at - 0.8, z), rot=(90, 0, 0), verts=10)
    for yy in [y0 + (y1 - y0) * f for f in (0.2, 0.6)]:
        bx("Decor", "gunmetal", (0.4, 0.3, 1.8), (x, yy, z - 0.9))


def algae(rnd, x, y, z, n=4):
    for k in range(n):
        bx("Decor", "avocado" if k % 2 else "forest", (rnd.uniform(0.8, 1.8), 0.12, rnd.uniform(0.6, 1.4)),
           (x + rnd.uniform(-1.5, 1.5), y, z + rnd.uniform(-1.0, 1.0)), rot=(0, rnd.uniform(-20, 20), 0))


def glow_caps(rnd, x, y, n=5):
    """Pale fungus with a faint Source glow on the wet rock (sparingly: Section 19's green accent)."""
    for k in range(n):
        r = rnd.uniform(0.18, 0.32)
        sf.tag(sf.sphere(r, loc=(x + rnd.uniform(-1.2, 1.2), y + rnd.uniform(-1.2, 1.2), r * 0.4), scale=(1, 1, 0.5),
                         segs=6, rings=3), "DecorNeon", "glow", "Neon", cast_shadow=False)


# The Crystal Hollows (A10) ----------------------------------------------------------------------------

def crystal_at(base, direction, length, radius, part="Decor", swatch="crystal", sides=6, mat="SmoothPlastic", low=False, **kw):
    """One crystal growing from `base` along `direction`. low: three rings instead of four (the
    small ones round a stand: a cave piece has 8,000 triangles for everything)."""
    if low:
        import bmesh
        from mathutils import Vector
        d = Vector(direction).normalized()
        bm = bmesh.new()
        loops = []
        for tt, r in ((0.0, 0.7), (0.5, 1.0), (1.0, 0.1)):
            loops.append([bm.verts.new((math.cos(math.tau * i / sides) * radius * r, math.sin(math.tau * i / sides) * radius * r,
                                        length * tt)) for i in range(sides)])
        for a, c in zip(loops, loops[1:]):
            for i in range(sides):
                bm.faces.new((a[i], a[(i + 1) % sides], c[(i + 1) % sides], c[i]))
        bm.faces.new(list(reversed(loops[0])))
        bm.faces.new(loops[-1])
        o = sf.from_bmesh(bm, "Crystal", Vector(base))
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    else:
        from _beast import shard
        o = shard(base, direction, length, radius, sides=sides)
    return t(o, part, swatch, mat=mat, **kw)


def crystal_cluster(rnd, x, y, z=0.0, n=6, size=3.0, up=(0, 0, 1), lit=True, detail=True):
    """A stand of crystals: the tallest in the middle, the rest leaning out of it; a lit tip or two
    so it reads in the dark (the lamps do the rest)."""
    ux, uy, uz = up
    crystal_at((x, y, z), up, size, size * 0.16, sides=6 if detail else 5, low=not detail)
    for k in range(n - 1):
        a = math.tau * k / max(n - 1, 1) + rnd.uniform(-0.3, 0.3)
        lean = rnd.uniform(0.35, 0.75)
        if abs(uz) > 0.5:
            d = (ux + math.cos(a) * lean, uy + math.sin(a) * lean, uz)
            at = (x + math.cos(a) * size * 0.14, y + math.sin(a) * size * 0.14, z)
        else:
            d = (ux + (0 if abs(ux) > 0.5 else math.cos(a) * lean), uy + (0 if abs(uy) > 0.5 else math.cos(a) * lean),
                 uz + math.sin(a) * lean)
            at = (x + (0 if abs(ux) > 0.5 else math.cos(a) * size * 0.14), y + (0 if abs(uy) > 0.5 else math.cos(a) * size * 0.14),
                  z + math.sin(a) * size * 0.14)
        ln = size * rnd.uniform(0.4, 0.78)
        crystal_at(at, d, ln, ln * rnd.uniform(0.13, 0.18), sides=4, low=True)
    if lit:
        tip = (x + ux * size * 0.98, y + uy * size * 0.98, z + uz * size * 0.98)
        crystal_at(tip, up, size * 0.12, size * 0.045, part="DecorNeon", sides=4, mat="Neon", low=True, cast_shadow=False)


def crystal_seam(points, r=0.12):
    """A crack in the rock with the crystal's light in it."""
    t(sf.tube([tuple(p) for p in points], [r * 0.5] + [r] * (len(points) - 2) + [r * 0.5], sides=3, resolution=1),
      "DecorNeon", "crystal", mat="Neon", cast_shadow=False)


def rad_sign(x, y, rot=0.0):
    """A Steadfast survey party's warning: a hazard-yellow plate on a leaning post (radiation here)."""
    bx("Decor", "gunmetal", (0.22, 0.22, 4.2), (x, y, 2.1), rot=(4, -6, rot))
    bx("Decor", "hazard", (2.0, 0.12, 1.6), (x, y - 0.14 * math.cos(math.radians(rot)), 3.6), rot=(4, -6, rot))
    bx("Decor", "rubber", (1.2, 0.14, 0.9), (x, y - 0.2 * math.cos(math.radians(rot)), 3.62), rot=(4, -6, rot))


def hot_rock(rnd, x, y, r=1.4):
    """A lump of the rock that glows the Source's green: the Crystal Hollows' radiation, seen."""
    t(sf.sphere(r, loc=(x, y, r * 0.35), scale=(1.0, 0.9, 0.55), segs=7, rings=4), "Decor", "basalt", smooth_angle=None)
    for k in range(4):
        a = math.tau * k / 4 + rnd.uniform(-0.4, 0.4)
        crystal_at((x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.4, r * 0.4), (math.cos(a) * 0.6, math.sin(a) * 0.6, 1.0),
                   r * rnd.uniform(0.5, 0.9), r * 0.11, part="DecorNeon", swatch="glow", sides=4, mat="Neon", low=True, cast_shadow=False)


def hard_hat(x, y, rot=0.0):
    o = sf.sphere(0.55, loc=(x, y, 0.25), scale=(1, 1.15, 0.7), segs=8, rings=4)
    t(o, "Decor", "hazard")
    bx("Decor", "hazard", (1.3, 1.5, 0.08), (x, y, 0.05), rot=(0, 0, rot))


def steadfast_board(x, y, z, w=4.0, h=2.0, rot=0.0):
    """A company notice board (teal enamel, cream card): STEADFAST SHELTER CO. on site."""
    bx("Decor", "teal", (w, 0.2, h), (x, y, z), rot=(0, 0, rot))
    bx("Decor", "cream", (w * 0.8, 0.25, h * 0.55), (x, y, z), rot=(0, 0, rot))
    bx("Decor", "walnut", (0.3, 0.3, z), (x - w * 0.42, y, z / 2), rot=(0, 0, rot))
    bx("Decor", "walnut", (0.3, 0.3, z), (x + w * 0.42, y, z / 2), rot=(0, 0, rot))


# Building a piece --------------------------------------------------------------------------------

def box_of(layout):
    """The piece's box in Roblox space from the pivot (x across, y up, z forward is -z): the cave
    planner's footprint, walls and boulders included."""
    xs = [r[0] for r in layout["rects"]] + [r[1] for r in layout["rects"]]
    ys = [r[2] for r in layout["rects"]] + [r[3] for r in layout["rects"]]
    pad = 4.0
    lo = (min(xs) - pad, -(layout.get("drop", 0)) - 1.5, min(ys) - pad)
    hi = (max(xs) + pad, layout["h"] + 4.5, max(ys) + (1.5 if layout.get("plate") else 0.0))
    # Blender (x, y, z) -> Roblox (-x, z, y): x flips, so swap the x bounds
    return {"min": [round(-hi[0], 3), round(lo[1], 3), round(lo[2], 3)],
            "max": [round(-lo[0], 3), round(hi[1], 3), round(hi[2], 3)]}


def build_piece(band, kind, dress, seed):
    """Shell, boulders and the band's dressing for one piece; returns the export settings."""
    R.reset_ids()
    layout = dict(LAYOUTS[kind])
    rnd = random.Random(seed)
    shell = Shell(band, layout, seed)
    shell.collision()
    big = layout["h"] >= 16
    if big:
        shell.boulders(spacing=5.8, rmin=2.9, rmax=4.6, step=1.8, segs=5, rings=4)
    else:
        shell.boulders(spacing=3.8, rmin=2.0, rmax=3.1, step=1.45, segs=6, rings=4)
    shell.opening_rims()
    dress(shell, rnd)
    sockets = {"Entry": ((0, 0, 0), 180)}
    for name, value in layout["sockets"].items():
        sockets[name] = value
    meta = {"band": BAND_ID[band], "kind": kind, "weight": layout["weight"], "box": box_of(layout)}
    return {"export": {"budget": BUDGET, "merge": "room", "pivot": (0, 0, 0), "step": "A6",
                       "sockets": sockets, "meta": meta}}


def interior_preview(asset, band, layout, res=640, samples=24):
    """What a player sees: from just inside the entrance, looking in, lit only by the piece's
    lanterns (warm in the Mines, pale cyan in the Flooded Caverns) and a little ambient."""
    import bpy
    from mathutils import Vector
    from PIL import Image
    objs = sf._tagged_objects()
    built = sf._build_export_meshes(objs, Vector((0, 0, 0)), "room")
    for o in objs:
        o.hide_render = True
    sf._setup_render(res, samples)
    world = bpy.context.scene.world.node_tree
    world.nodes["Background"].inputs[1].default_value = 0.05
    world.nodes["SF_CamBG"].inputs[0].default_value = (0.0, 0.0, 0.0, 1)
    colour = (1.0, 0.78, 0.45) if band == "Mines" else (0.5, 1.0, 0.62) if band == "Source" else (0.6, 0.95, 0.95)
    for name, value in layout["sockets"].items():
        if name.startswith("Light"):
            ld = bpy.data.lights.new(name, type="POINT")
            ld.energy = 900 if layout["h"] < 16 else 1800
            ld.color = colour
            ld.shadow_soft_size = 0.4
            ob = bpy.data.objects.new(name, ld)
            bpy.context.scene.collection.objects.link(ob)
            ob.location = Vector(value) - Vector((0, 0, 0.9))
    # the player's own light (Prompt 17: a light radius in the Deep)
    ld = bpy.data.lights.new("PlayerLight", type="POINT")
    ld.energy = 250
    ld.color = (1.0, 0.95, 0.85)
    ob = bpy.data.objects.new("PlayerLight", ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector((1.5, -3.0, 5.0))
    cd = bpy.data.cameras.new("PreviewCam")
    cd.angle = math.radians(75)
    cam = bpy.data.objects.new("PreviewCam", cd)
    bpy.context.scene.collection.objects.link(cam)
    ys = [r[2] for r in layout["rects"]]
    far = min(ys)
    cam.location = Vector((2.0, -1.5, 6.5))
    cam.rotation_euler = (Vector((0, far * 0.75, 3.0 - layout.get("drop", 0) * 0.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    out = os.path.join(sf.REPO, "previews", "Caves", f"{asset}_inside.png")
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(("PreviewCam", "Light", "PlayerLight")):
            bpy.data.objects.remove(o, do_unlink=True)
    for b in built:
        bpy.data.objects.remove(b["obj"], do_unlink=True)
    for o in objs:
        o.hide_render = False
    return out


def run(band, kind, dress, seed=7):
    asset = f"Cave_{band}_{kind}"

    def build():
        out = build_piece(band, kind, dress, seed)
        if os.environ.get("SF_NORENDER") != "1":
            print(f"[{asset}] inside: {interior_preview(asset, band, LAYOUTS[kind])}")
        return out
    sf.run_main(build, asset, "Caves")
