"""kitlib: shared measurements and builders for the A1 bunker kit (bible Section 6).

Every kit piece has its pivot at the centre of a cell's interior floor, like Kit_CellShell
(A0) and the room furniture, so a cell is its pieces placed at one CFrame (Rules.Grid's
Grid.CellCFrame in game). In Blender:

    X  runs with the grid's columns (screen right in the Command View),
    -Y is the front (the Command View's side; +Y is the back wall),
    Z  is up, the floor's top at 0.

These must match the graybox in game/places/Run/server/Lib/BunkerKit.luau: the 8 x 10 doorway
in the middle of each side wall, and the opening between stacked Shafts at the back right
(x 2 to 16, y 8 to 16).
"""
import steadfast as sf

W, D, H = 32.0, 32.0, 16.0        # cell interior
T = 1.0                           # each cell's share of a wall
S = 2.0                           # slab between floors
DOOR_W, DOOR_H = 8.0, 10.0
HOLE = (2.0, W / 2, D / 2 - 8.0, D / 2)     # x0, x1, y0, y1: the Shaft opening
WAINSCOT = 4.5
BAND_SWATCHES = {                  # rock, darker rock, accent per depth band (Section 6)
    "Mines": ("stone", "basalt", "pine"),            # timber props, lanterns, old carts
    "FloodedCaverns": ("murk", "navy", "teal"),      # dripping rock, standing water
    "CrystalHollows": ("plum", "basalt", "crystal"), # glowing crystal
    "SourceChamber": ("rust", "basalt", "glow"),     # a living cavern: Source green
}


def t(obj, part, swatch, collision="none", mat="SmoothPlastic", **kw):
    return sf.tag(obj, part, swatch, mat, collision=collision, **kw)


def cut(rect, hole):
    """A rectangle (x0, x1, y0, y1) minus a hole inside it, as up to four rectangles."""
    x0, x1, y0, y1 = rect
    hx0, hx1, hy0, hy1 = hole
    out = [(x0, hx0, y0, y1), (hx1, x1, y0, y1), (hx0, hx1, y0, hy0), (hx0, hx1, hy1, y1)]
    return [r for r in out if r[1] - r[0] > 1e-3 and r[3] - r[2] > 1e-3]


def slab(part, swatch, rect, z0, z1, collision="box", bevel=0.0):
    x0, x1, y0, y1 = rect
    return t(sf.box((x1 - x0, y1 - y0, z1 - z0), loc=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), bevel=bevel),
             part, swatch, collision=collision)


def overlaps(rect, hole) -> bool:
    x0, x1, y0, y1 = rect
    hx0, hx1, hy0, hy1 = hole
    return x0 < hx1 and x1 > hx0 and y0 < hy1 and y1 > hy0


def wall_x(part, x_face, inward, door: bool, collision, role=None):
    """A side wall on the plane x = x_face (interior face), thickness T going outward."""
    xc = x_face - inward * T / 2
    pieces = []
    if door:
        side = (D - DOOR_W) / 2
        for sy in (-1, 1):
            pieces.append(sf.box((T, side, H), loc=(xc, sy * (DOOR_W / 2 + side / 2), H / 2), bevel=0.0))
        pieces.append(sf.box((T, DOOR_W, H - DOOR_H), loc=(xc, 0, DOOR_H + (H - DOOR_H) / 2), bevel=0.0))
    else:
        pieces.append(sf.box((T, D, H), loc=(xc, 0, H / 2), bevel=0.0))
    for pc in pieces:
        t(pc, part, "cream", collision=collision, role=role)
    xi = x_face + inward * 0.08
    spans = [(-D / 2, -DOOR_W / 2), (DOOR_W / 2, D / 2)] if door else [(-D / 2, D / 2)]
    for y0, y1 in spans:
        ln, yc = y1 - y0, (y0 + y1) / 2
        t(sf.box((0.16, ln, WAINSCOT), loc=(xi, yc, WAINSCOT / 2), bevel=0.0), part + "Trim", "teal")
        t(sf.box((0.3, ln, 0.22), loc=(x_face + inward * 0.15, yc, WAINSCOT), bevel=0.04, segments=1), part + "Trim", "chrome")
    for y in (-12.0, 12.0):        # steel ribs
        t(sf.box((0.35, 0.7, H), loc=(x_face + inward * 0.17, y, H / 2), bevel=0.06, segments=1), part + "Trim", "steel")
    if door:
        # a chunky bulkhead frame: steel jambs, a Signal Orange header, hazard-yellow sill
        for sy in (-1, 1):
            t(sf.box((0.7, 0.7, DOOR_H), loc=(x_face + inward * 0.3, sy * (DOOR_W / 2 + 0.35), DOOR_H / 2),
                     bevel=0.08, segments=1), part + "Frame", "steel")
            for z in (2.0, 5.0, 8.0):  # rivets on the jambs
                t(sf.cyl(0.13, 0.12, loc=(x_face + inward * 0.68, sy * (DOOR_W / 2 + 0.35), z), rot=(0, 90, 0),
                         verts=6, bevel=0.0), part + "Frame", "chrome")
        t(sf.box((0.7, DOOR_W + 1.4, 0.9), loc=(x_face + inward * 0.3, 0, DOOR_H + 0.45), bevel=0.08, segments=1),
          part + "Frame", "signal")
        t(sf.box((0.8, DOOR_W, 0.12), loc=(x_face, 0, 0.06), bevel=0.0), part + "Frame", "hazard")


def wall_y(part, y_face, inward, pipes: bool, collision, role=None):
    """A back or front wall on the plane y = y_face, spanning the cell's full width."""
    yc = y_face - inward * T / 2
    t(sf.box((W + 2 * T, T, H), loc=(0, yc, H / 2), bevel=0.0), part, "cream", collision=collision, role=role)
    yi = y_face + inward * 0.08
    t(sf.box((W, 0.16, WAINSCOT), loc=(0, yi, WAINSCOT / 2), bevel=0.0), part + "Trim", "teal")
    t(sf.box((W, 0.3, 0.22), loc=(0, y_face + inward * 0.15, WAINSCOT), bevel=0.04, segments=1), part + "Trim", "chrome")
    for x in (-12, -4, 4, 12):     # steel ribs with a rivet cap
        t(sf.box((0.7, 0.35, H), loc=(x, y_face + inward * 0.17, H / 2), bevel=0.06, segments=1), part + "Trim", "steel")
        t(sf.cyl(0.22, 0.14, loc=(x, y_face + inward * 0.38, H - 1.2), rot=(90, 0, 0), verts=6, bevel=0.0), part + "Trim", "chrome")
    if pipes:
        for z, r, sw in ((13.6, 0.32, "copper"), (14.5, 0.26, "steel")):
            t(sf.cyl(r, W + 2 * T, loc=(0, y_face + inward * 0.75, z), rot=(0, 90, 0), verts=8, bevel=0.0), part + "Pipes", sw)
        for x in (-12, -4, 4, 12):
            t(sf.box((0.3, 0.9, 1.4), loc=(x, y_face + inward * 0.5, 14.05), bevel=0.0), part + "Pipes", "gunmetal")


def floor_tiles(hole=None, swatch="sandstone"):
    """4 x 4 tiles across the cell's full pitch (so the tiles of merged cells meet with the same
    grout line) and its interior depth."""
    n, gap = 4, 0.25
    across = W + 2 * T
    tile_x = (across - gap * n) / n
    tile_y = (D - gap * (n + 1)) / n
    for i in range(n):
        for j in range(n):
            x = -across / 2 + gap / 2 + tile_x / 2 + i * (tile_x + gap)
            y = -D / 2 + gap + tile_y / 2 + j * (tile_y + gap)
            tile = tile_x
            rect = (x - tile / 2, x + tile / 2, y - tile_y / 2, y + tile_y / 2)
            if hole and overlaps(rect, hole):
                continue
            t(sf.box((tile, tile_y, 0.06), loc=(x, y, 0.03), bevel=0.0), "FloorTiles", swatch)


def rock_block(part, swatch, lo, hi, segs=(6, 6, 3), jitter=None, seed=1, collision="box", smooth=None):
    """A box of rock between corners lo and hi, its faces cut into a grid whose inner points
    are pushed in or out at random (seeded, so the same rock comes back every run). Edges stay
    straight so neighbouring blocks meet cleanly.

    jitter maps a face, (axis, sign) with axis 0 = x, 1 = y, 2 = z and sign -1 or +1, to the
    (min, max) offset along its outward normal; faces left out stay flat. The default pushes
    every face in by up to 0.8 and lets the front (-Y) bulge out by up to 0.9.
    """
    import random
    import bmesh
    rnd = random.Random(seed)
    if jitter is None:
        jitter = {(0, -1): (-0.8, 0.0), (0, 1): (-0.8, 0.0), (1, -1): (-0.6, 0.9),
                  (2, -1): (-0.8, 0.0), (2, 1): (-0.5, 0.0)}
    bm = bmesh.new()
    for axis in (0, 1, 2):
        a, b = [i for i in range(3) if i != axis]
        na, nb = segs[a], segs[b]
        for sign in (-1, 1):
            fixed = lo[axis] if sign < 0 else hi[axis]
            rng = jitter.get((axis, sign))
            grid = []
            for i in range(na + 1):
                row = []
                for j in range(nb + 1):
                    p = [0.0, 0.0, 0.0]
                    p[axis] = fixed
                    p[a] = lo[a] + (hi[a] - lo[a]) * i / na
                    p[b] = lo[b] + (hi[b] - lo[b]) * j / nb
                    if rng and 0 < i < na and 0 < j < nb:
                        p[axis] += sign * rnd.uniform(*rng)
                        # and sideways, so the facets don't read as a grid
                        p[a] += rnd.uniform(-0.3, 0.3) * (hi[a] - lo[a]) / na
                        p[b] += rnd.uniform(-0.3, 0.3) * (hi[b] - lo[b]) / nb
                    row.append(bm.verts.new(p))
                grid.append(row)
            for i in range(na):
                for j in range(nb):
                    bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="ALTERNATE")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = sf.from_bmesh(bm, part)
    return t(obj, part, swatch, collision=collision, smooth_angle=smooth)


def nugget(part, swatch, loc, r, seed, mat="SmoothPlastic", collision="none"):
    """A small faceted lump (ore, rubble)."""
    import random
    rnd = random.Random(seed)
    o = sf.sphere(r, loc=loc, scale=(rnd.uniform(0.8, 1.3), rnd.uniform(0.7, 1.1), rnd.uniform(0.6, 1.0)), segs=5, rings=3)
    o.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3))
    return t(o, part, swatch, collision=collision, mat=mat, smooth_angle=None)


def shard(part, swatch, base, length, radius, tilt, yaw, mat="SmoothPlastic", collision="none"):
    """A six-sided crystal shard standing on `base`, tilted `tilt` degrees toward `yaw`."""
    import math
    o = sf.cyl(radius, length, verts=6, bevel=0.0)
    for v in o.data.vertices:           # stand it on its base and pull the top ring to a point
        top = v.co.z > 0
        v.co.z += length / 2
        if top:
            v.co.x *= 0.15
            v.co.y *= 0.15
    o.location = base
    o.rotation_euler = (math.radians(tilt), 0.0, math.radians(yaw))
    return t(o, part, swatch, collision=collision, mat=mat, smooth_angle=None)
