"""Room_Kitchen_L1: the Kitchen's furniture at level 1, for one cell (bible Section 6: the
Kitchen makes Food, worker stat Speed, 2 worker slots per cell at level 1).

A 1950s Steadfast kitchen: rounded porcelain fridge, an enamel range with four burners and
orange knobs, a mint counter run with a steel sink, wall cabinets, a pantry rack of ration
tins, and a diner table with chrome chairs on a checkered rug under two pendant lamps.

Each piece of furniture is its own MeshPart (merge="part"), so each gets its own collision
box. Pivot = the centre of the cell's interior floor, the same as Kit_CellShell, so the room
is the shell plus this at one CFrame. Sockets: WorkSpot1-2 (where residents work, facing
their station), Seat1-4, Table, Light1-2.

Run:  SF_EXPORT=1 python3 generators/Rooms/Room_Kitchen_L1.py
"""
import math
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Kits"))
import steadfast as sf  # noqa: E402
import bmesh  # noqa: E402

ASSET, CATEGORY = "Room_Kitchen_L1", "Rooms"
BUDGET = 3000
BACK = 16.0          # interior face of the back wall (Blender +Y)
H = 16.0


def t(obj, part, swatch, collision="box", mat="SmoothPlastic", **kw):
    return sf.tag(obj, part, swatch, mat, collision=collision, **kw)


def fridge():
    x, y = -13.4, BACK - 1.6
    t(sf.box((3.6, 3.0, 7.0), loc=(x, y, 3.6), bevel=0.55, segments=1), "Fridge", "porcelain")
    t(sf.box((3.4, 2.8, 0.25), loc=(x, y, 0.12), bevel=0.04, segments=1), "Fridge", "rubber")
    t(sf.box((3.62, 3.02, 0.08), loc=(x, y - 0.02, 5.1), bevel=0.0), "Fridge", "steel")         # door split
    for z0, z1 in ((5.4, 6.6), (2.0, 4.6)):                                                     # chrome handles
        t(sf.box((0.22, 0.34, z1 - z0), loc=(x + 1.3, y - 1.62, (z0 + z1) / 2), bevel=0.08, segments=1), "Fridge", "chrome")
    t(sf.box((1.2, 0.1, 0.35), loc=(x, y - 1.52, 6.55), bevel=0.04, segments=1), "Fridge", "chrome")  # badge


def stove():
    x, y = -8.6, BACK - 1.55
    t(sf.box((4.0, 2.9, 3.3), loc=(x, y, 1.75), bevel=0.25, segments=1), "Stove", "mint")
    t(sf.box((4.1, 3.0, 0.2), loc=(x, y, 3.45), bevel=0.06, segments=1), "Stove", "porcelain")
    t(sf.box((4.0, 0.5, 1.25), loc=(x, BACK - 0.35, 4.15), bevel=0.12, segments=1), "Stove", "porcelain")
    for i in range(4):                                                                           # knobs
        t(sf.cyl(0.17, 0.2, loc=(x - 1.35 + i * 0.9, BACK - 0.65, 4.15), rot=(90, 0, 0), verts=8, bevel=0.0), "Stove", "signal")
    for dx in (-0.95, 0.95):                                                                     # burners
        for dy in (-0.75, 0.55):
            t(sf.cyl(0.55, 0.08, loc=(x + dx, y + dy, 3.59), verts=8, bevel=0.0), "Stove", "navy")
    t(sf.box((3.2, 0.12, 2.0), loc=(x, y - 1.47, 1.65), bevel=0.06, segments=1), "Stove", "porcelain")  # oven door
    t(sf.box((1.8, 0.1, 0.8), loc=(x, y - 1.53, 1.75), bevel=0.03, segments=1), "Stove", "rubber")      # window
    t(sf.box((2.4, 0.22, 0.16), loc=(x, y - 1.62, 2.75), bevel=0.05, segments=1), "Stove", "chrome")     # handle


def counter():
    x0, x1, y = -6.4, 5.8, BACK - 1.35
    cx, ln = (x0 + x1) / 2, x1 - x0
    t(sf.box((ln, 2.5, 3.1), loc=(cx, y, 1.6), bevel=0.12, segments=1), "Counter", "mint")
    t(sf.box((ln, 2.5, 0.3), loc=(cx, y - 0.05, 0.15), bevel=0.0), "Counter", "teal")            # toe kick
    t(sf.box((ln + 0.3, 2.8, 0.28), loc=(cx, y - 0.1, 3.3), bevel=0.06, segments=1), "Counter", "porcelain")
    for i in range(5):                                                                          # door seams, handles
        xi = x0 + (i + 1) * ln / 6
        t(sf.box((0.06, 0.08, 2.4), loc=(xi, y - 1.27, 1.75), bevel=0.0), "Counter", "teal")
        t(sf.box((0.5, 0.18, 0.14), loc=(xi - ln / 12, y - 1.33, 2.6), bevel=0.0), "Counter", "chrome")
    sx = -0.6                                                                                   # sink and faucet
    t(sf.box((2.6, 1.9, 0.12), loc=(sx, y - 0.1, 3.47), bevel=0.04, segments=1), "Counter", "steel")
    t(sf.box((2.1, 1.4, 0.06), loc=(sx, y - 0.1, 3.54), bevel=0.0), "Counter", "gunmetal")
    t(sf.cyl(0.12, 1.2, loc=(sx, BACK - 0.35, 4.0), verts=8, bevel=0.0), "Counter", "chrome")
    t(sf.box((0.22, 1.0, 0.2), loc=(sx, BACK - 0.8, 4.55), bevel=0.05, segments=1), "Counter", "chrome")


def wall_cabinets():
    x0, x1 = -6.4, 5.8
    cx, ln = (x0 + x1) / 2, x1 - x0
    t(sf.box((ln, 1.6, 2.6), loc=(cx, BACK - 0.8, 9.3), bevel=0.12, segments=1), "WallCabinets", "mint", collision="none")
    for i in range(5):
        xi = x0 + (i + 1) * ln / 6
        t(sf.box((0.06, 0.08, 2.2), loc=(xi, BACK - 1.62, 9.3), bevel=0.0), "WallCabinets", "teal", collision="none")
    for i in range(6):
        xi = x0 + (i + 0.5) * ln / 6
        t(sf.box((0.45, 0.16, 0.12), loc=(xi, BACK - 1.68, 8.3), bevel=0.0), "WallCabinets", "chrome", collision="none")


def shelves():
    cx, y, w, d = 11.6, BACK - 0.85, 6.0, 1.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            t(sf.box((0.18, 0.18, 8.0), loc=(cx + sx * (w / 2 - 0.1), y + sy * (d / 2 - 0.1), 4.0), bevel=0.0), "Shelves", "gunmetal")
    for z in (0.5, 2.9, 5.3, 7.7):
        t(sf.box((w, d, 0.14), loc=(cx, y, z), bevel=0.0), "Shelves", "steel")
    tins = ["brass", "cream", "rust", "teal", "brass"]
    for row, z in enumerate((3.0, 5.4, 7.8)):
        for i in range(4):
            sw = tins[(i + row) % len(tins)]
            t(sf.cyl(0.38, 0.85, loc=(cx - 2.1 + i * 1.4, y - 0.1, z + 0.45), verts=6, bevel=0.0), "Shelves", sw)
    for i in range(2):                                                                          # sacks of flour
        t(sf.box((2.2, 1.3, 1.7), loc=(cx - 1.4 + i * 2.6, y - 0.05, 1.45), bevel=0.35, segments=1), "Shelves", "cream")


def table_and_chairs():
    cx, cy = 0.0, -1.0
    t(sf.box((6.0, 3.6, 0.22), loc=(cx, cy, 2.62), bevel=0.06, segments=1), "Table", "teal")
    t(sf.box((6.12, 3.72, 0.12), loc=(cx, cy, 2.47), bevel=0.0), "Table", "chrome")
    t(sf.cyl(0.3, 2.3, loc=(cx, cy, 1.3), verts=8, bevel=0.0), "Table", "chrome")
    t(sf.cyl(1.2, 0.18, loc=(cx, cy, 0.09), verts=10, bevel=0.0), "Table", "chrome")
    seats = []
    for sy in (-1, 1):
        for sx in (-1, 1):
            x, y = cx + sx * 1.6, cy + sy * 2.75
            t(sf.box((1.5, 1.5, 0.34), loc=(x, y, 1.62), bevel=0.12, segments=1), "Chairs", "rust", collision="none")
            t(sf.box((1.5, 0.3, 1.3), loc=(x, y + sy * 0.7, 2.6), bevel=0.0), "Chairs", "rust", collision="none")
            for lx in (-0.62, 0.62):     # chrome sled frames: a floor runner and an upright each side
                t(sf.box((0.12, 1.5, 0.12), loc=(x + lx, y, 0.06), bevel=0.0), "Chairs", "chrome", collision="none")
                t(sf.box((0.12, 0.12, 1.5), loc=(x + lx, y + sy * 0.55, 0.8), bevel=0.0), "Chairs", "chrome", collision="none")
            seats.append(((x, y, 0.0), 180.0 if sy < 0 else 0.0))   # yaw 0 faces Roblox -Z (the camera side)
    return seats


def rug():
    """A checkered diner rug: one mesh, faces painted navy and porcelain."""
    nx, ny, s = 8, 6, 1.5
    bm = bmesh.new()
    verts = [[bm.verts.new((-nx * s / 2 + i * s, -ny * s / 2 + j * s, 0)) for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            bm.faces.new([verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1]])
    o = sf.from_bmesh(bm, "Rug", loc=(0, -1.0, 0.08))
    t(o, "Rug", "porcelain", collision="none")
    sf.paint(o, "navy", lambda c, n: (int(math.floor((c.x + 6) / s)) + int(math.floor((c.y + 5.5) / s))) % 2 == 0)
    edge = sf.box((nx * s + 0.6, ny * s + 0.6, 0.05), loc=(0, -1.0, 0.04), bevel=0.0)
    t(edge, "Rug", "navy", collision="none")


def lamps():
    out = []
    for x in (-2.0, 2.0):
        t(sf.cyl(0.05, H - 11.9, loc=(x, -1.0, (H + 11.9) / 2 - 0.25), verts=6, bevel=0.0), "Lamps", "rubber", collision="none", cast_shadow=False)
        t(sf.sphere(0.95, loc=(x, -1.0, 11.6), scale=(1, 1, 0.55), segs=8, rings=4), "Lamps", "hazard", collision="none", cast_shadow=False)
        t(sf.sphere(0.32, loc=(x, -1.0, 11.15), segs=6, rings=3), "LampBulbs", "cream", mat="Neon", collision="none", cast_shadow=False)
        out.append((x, -1.0, 10.9))
    return out


def clock_and_poster():
    # a wall clock on the -X side wall (screen left in the Command View)
    x = -15.85
    t(sf.cyl(1.05, 0.14, loc=(x, 6.0, 10.5), rot=(0, 90, 0), verts=12, bevel=0.0), "Clock", "cream", collision="none")
    t(sf.torus(1.05, 0.12, loc=(x + 0.05, 6.0, 10.5), rot=(0, 90, 0), major_segs=12, minor_segs=3), "Clock", "chrome", collision="none")
    t(sf.box((0.06, 0.12, 0.7), loc=(x + 0.12, 6.0, 10.8), bevel=0.0), "Clock", "navy", collision="none")
    t(sf.box((0.06, 0.55, 0.1), loc=(x + 0.12, 6.2, 10.5), rot=(30, 0, 0), bevel=0.0), "Clock", "navy", collision="none")
    # a Steadfast poster above the fridge: walnut frame, cream sheet, teal band, gopher badge
    px, pz = -13.4, 11.0
    t(sf.box((3.4, 0.14, 4.4), loc=(px, BACK - 0.07, pz), bevel=0.04, segments=1), "Poster", "walnut", collision="none")
    t(sf.box((3.0, 0.1, 4.0), loc=(px, BACK - 0.15, pz), bevel=0.0), "Poster", "cream", collision="none")
    t(sf.box((3.0, 0.12, 0.9), loc=(px, BACK - 0.17, pz + 1.3), bevel=0.0), "Poster", "teal", collision="none")
    t(sf.cyl(0.75, 0.1, loc=(px, BACK - 0.2, pz - 0.2), rot=(90, 0, 0), verts=10, bevel=0.0), "Poster", "signal", collision="none")
    t(sf.cyl(0.42, 0.1, loc=(px, BACK - 0.24, pz - 0.2), rot=(90, 0, 0), verts=10, bevel=0.0), "Poster", "navy", collision="none")
    t(sf.box((2.2, 0.12, 0.3), loc=(px, BACK - 0.17, pz - 1.45), bevel=0.0), "Poster", "rust", collision="none")


def crates():
    for (x, y, z) in ((12.6, -12.2, 1.25), (12.6, -9.1, 1.25), (12.6, -10.6, 3.75)):
        t(sf.box((2.9, 2.9, 2.5), loc=(x, y, z), bevel=0.1, segments=1), "Crates", "pine")
        t(sf.box((2.94, 0.3, 2.54), loc=(x, y, z), bevel=0.0), "Crates", "walnut")
        t(sf.box((1.3, 0.06, 0.7), loc=(x, y - 1.47, z), bevel=0.0), "Crates", "teal")


def build():
    fridge(); stove(); counter(); wall_cabinets(); shelves()
    seats = table_and_chairs()
    rug()
    lights = lamps()
    clock_and_poster(); crates()
    sockets = {"WorkSpot1": ((-8.6, BACK - 4.0, 0.0), 180.0), "WorkSpot2": ((-0.6, BACK - 3.6, 0.0), 180.0),
               "Table": ((0.0, -1.0, 0.0), 0.0)}
    for i, s in enumerate(seats):
        sockets[f"Seat{i + 1}"] = s
    for i, p in enumerate(lights):
        sockets[f"Light{i + 1}"] = (p, 0.0)
    return sockets


def preview_with_shell():
    """Render the furniture inside the cell shell with the front wall and ceiling removed,
    as the Command View sees it, then take the shell away again before export."""
    import bpy
    import Kit_CellShell as shell
    before = set(bpy.context.scene.objects)
    furniture = set(before)
    shell.build()
    shell_objs = [o for o in bpy.context.scene.objects if o not in before]
    for o in shell_objs:
        if o.get("sf_part") in ("FrontWall", "Ceiling", "CeilingLight"):
            bpy.data.objects.remove(o, do_unlink=True)
    shell_objs = [o for o in bpy.context.scene.objects if o not in before]
    out = sf.render_preview(ASSET, CATEGORY, res=640, samples=24, merge="part",
                            views=[(0, 24, False), (-38, 34, False)])
    for o in list(bpy.context.scene.objects):
        if o not in furniture:
            bpy.data.objects.remove(o, do_unlink=True)
    return out


if __name__ == "__main__":
    sf.reset()
    sockets = build()
    print(f"[{ASSET}] triangles before merge: {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(preview_with_shell())
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(ASSET, CATEGORY, pivot=(0, 0, 0), merge="part", budget=BUDGET, step="A0",
                              sockets=sockets, meta={"room": "Kitchen", "level": 1, "workers": 2,
                                                     "shell": "Kit_CellShell"})
        print(f"[{ASSET}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
