"""Kit_Shell: the bunker kit's room shell, one piece per job (A1; bible Section 6).

A room is built from these per cell, all pivoted at the cell's interior floor centre
(see kitlib): a floor and a ceiling (or the versions with the Shaft opening), a back wall and
a front wall per cell, and a side wall at each end of the room, solid or with the doorway
when the cell beyond is open. The look is the approved A0 shell (Kit_CellShell): teal
wainscot with a chrome rail, cream steel panels, steel ribs, a pipe run along the back,
sandstone tiles, a ceiling with steel beams and two glowing light housings.

Side walls are made for the right-hand end (+X); the left-hand end uses the same piece
turned half a turn about the cell centre.

    python3 generators/Kits/Kit_Shell.py              preview of an assembled 2-cell room
    SF_EXPORT=1 python3 generators/Kits/Kit_Shell.py  exports every piece (no preview)
    SF_EXPORT=1 python3 generators/Kits/Kit_Shell.py Kit_Floor Kit_WallBack   some pieces
"""
import math
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402
from kitlib import (D, DOOR_H, DOOR_W, H, HOLE, S, T, W, cut, floor_tiles, slab, t,  # noqa: E402
                    wall_x, wall_y)

CATEGORY = "Kit"
BUDGET = 900     # per piece; a cell's shell (floor, ceiling, 4 walls) stays inside the 2,000 of Section 19


def floor(hole: bool):
    rect = (-W / 2 - T, W / 2 + T, -D / 2 - T, D / 2 + T)
    if not hole:
        slab("Floor", "basalt", rect, -S, 0.0, collision="box")
        floor_tiles()
        return {}
    for r in cut(rect, HOLE):
        slab("Floor", "basalt", r, -S, 0.0, collision="precise")
    floor_tiles(hole=HOLE)
    x0, x1, y0, y1 = HOLE
    # a hazard-striped lip around the opening
    for (a, b, c, d) in ((x0 - 0.5, x0, y0 - 0.5, y1), (x0 - 0.5, x1, y0 - 0.5, y0)):
        slab("HoleLip", "hazard", (a, b, c, d), 0.0, 0.12, collision="none")
    for i in range(4):           # black chevrons on the front lip
        xc = x0 + 1.0 + i * 1.6
        t(sf.box((0.6, 0.52, 0.04), loc=(xc, y0 - 0.25, 0.13), rot=(0, 0, 35), bevel=0.0), "HoleLip", "rubber")
    # a chrome rail along the left edge and the left part of the front edge; the stair's top
    # (the right part of the front edge) stays open
    rail_z = 3.2
    posts = [(x0 - 0.25, y1 - 0.4), (x0 - 0.25, (y0 + y1) / 2), (x0 - 0.25, y0 - 0.25), (x0 + 3.5, y0 - 0.25), (x0 + 7.0, y0 - 0.25)]
    for (px, py) in posts:
        t(sf.cyl(0.14, rail_z, loc=(px, py, rail_z / 2), verts=8, bevel=0.0), "HoleRail", "chrome", collision="precise")
    t(sf.cyl(0.12, y1 - 0.4 - (y0 - 0.25), loc=(x0 - 0.25, (y1 - 0.4 + y0 - 0.25) / 2, rail_z), rot=(90, 0, 0), verts=8, bevel=0.0),
      "HoleRail", "chrome", collision="precise")
    t(sf.cyl(0.12, 7.25, loc=(x0 - 0.25 + 7.25 / 2, y0 - 0.25, rail_z), rot=(0, 90, 0), verts=8, bevel=0.0),
      "HoleRail", "chrome", collision="precise")
    t(sf.cyl(0.1, 7.25, loc=(x0 - 0.25 + 7.25 / 2, y0 - 0.25, rail_z / 2), rot=(0, 90, 0), verts=8, bevel=0.0),
      "HoleRail", "chrome", collision="precise")
    return {}


def ceiling(hole: bool):
    rect = (-W / 2, W / 2, -D / 2, D / 2)
    for r in (cut(rect, HOLE) if hole else [rect]):
        slab("Ceiling", "cream", r, H - 0.5, H, collision="none")
    for y in (-10.5, 0.0, 10.5):  # steel beams, stopped short of the opening
        x_end = W / 2
        if hole and y > HOLE[2] - 0.5:
            x_end = HOLE[0] - 0.2
        ln = x_end + W / 2
        t(sf.box((ln, 0.9, 0.8), loc=(-W / 2 + ln / 2, y, H - 0.9), bevel=0.06, segments=1), "CeilingBeams", "steel")
    lights = {}
    for i, x in enumerate((-8.0, 8.0)):
        y = 5.25
        t(sf.box((4.0, 1.6, 0.5), loc=(x, y, H - 0.75), bevel=0.06, segments=1), "LightHousings", "gunmetal")
        t(sf.box((4.3, 1.9, 0.12), loc=(x, y, H - 0.52), bevel=0.0), "LightHousings", "chrome")
        t(sf.box((3.4, 1.0, 0.1), loc=(x, y, H - 1.03), bevel=0.0), "CeilingLight", "cream", mat="Neon",
          cast_shadow=False, role="CeilingLight")
        lights[f"Light{i + 1}"] = ((x, y, H - 1.2), 0.0)
    if hole:
        x0, x1, y0, y1 = HOLE
        t(sf.box(((x1 - x0) + 0.6, 0.3, 0.6), loc=((x0 + x1) / 2, y0 - 0.15, H - 0.3), bevel=0.0), "HoleTrim", "hazard")
        t(sf.box((0.3, (y1 - y0), 0.6), loc=(x0 - 0.15, (y0 + y1) / 2, H - 0.3), bevel=0.0), "HoleTrim", "hazard")
    return {"sockets": lights}


def vent():
    """A wall vent on the back wall, upper left: one of the bunker's breach points (bible
    Section 10: room vents). Socket Vent: its mouth, facing into the room."""
    x, z, y = -12.0, 11.5, D / 2
    t(sf.box((4.6, 0.6, 3.4), loc=(x, y - 0.3, z), bevel=0.15, segments=1), "VentFrame", "gunmetal")
    t(sf.box((3.8, 0.3, 2.6), loc=(x, y - 0.5, z), bevel=0.0), "VentFrame", "rubber")
    for i in range(5):        # louvres
        t(sf.box((3.6, 0.18, 0.28), loc=(x, y - 0.75, z - 1.0 + i * 0.5), rot=(35, 0, 0), bevel=0.0), "VentLouvres", "steel")
    for dx in (-2.0, 2.0):    # corner bolts
        for dz in (-1.4, 1.4):
            t(sf.cyl(0.13, 0.15, loc=(x + dx, y - 0.65, z + dz), rot=(90, 0, 0), verts=6, bevel=0.0), "VentLouvres", "chrome")
    t(sf.box((3.4, 0.08, 0.35), loc=(x, y - 0.66, z - 2.1), bevel=0.0), "VentLouvres", "hazard")
    return {"sockets": {"Vent": ((x, y - 1.0, z), 180.0)}}


PIECES = {
    "Kit_Floor": (lambda: floor(False), "Floor slab with sandstone tiles; Box collision"),
    "Kit_FloorHole": (lambda: floor(True), "Floor with the Shaft opening at the back right, a hazard lip and a rail; Precise collision"),
    "Kit_Ceiling": (lambda: ceiling(False), "Ceiling panel, steel beams, two light housings (CeilingLight: Neon, light sockets)"),
    "Kit_CeilingHole": (lambda: ceiling(True), "Ceiling with the Shaft opening"),
    "Kit_WallBack": (lambda: wall_y("BackWall", D / 2, -1, True, "box") or {}, "Back wall, wainscot, ribs and the pipe run"),
    "Kit_WallFront": (lambda: wall_y("FrontWall", -D / 2, 1, False, "box", role="FrontWall") or {}, "Front wall; hidden in the Command View"),
    "Kit_WallSide": (lambda: wall_x("SideWall", W / 2, -1, False, "box") or {}, "Solid side wall at the room's right end (turn it for the left)"),
    "Kit_WallSideDoor": (lambda: wall_x("SideWall", W / 2, -1, True, "precise") or {},
                         f"Side wall with the {DOOR_W:.0f} x {DOOR_H:.0f} doorway and a bulkhead frame"),
    "Kit_Vent": (vent, "Wall vent on the back wall: a breach point (Vent socket)"),
}


def build_piece(name: str) -> dict:
    sf.reset()
    return PIECES[name][0]() or {}


def export_piece(name: str):
    extra = build_piece(name)
    doc = sf.export_asset(name, CATEGORY, pivot=(0, 0, 0), merge="room", budget=BUDGET, step="A1",
                          sockets=extra.get("sockets"), meta={"kit": "shell", "about": PIECES[name][1],
                                                               "interior": [W, H, D], "door": [DOOR_W, DOOR_H],
                                                               "hole": list(HOLE)})
    print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


def _moved(build, dx=0.0, turn=False):
    """Run a piece builder and move what it made by dx (turning it half a turn first)."""
    before = set(bpy.context.scene.objects)
    build()
    for o in [o for o in bpy.context.scene.objects if o not in before]:
        if turn:
            o.location = (-o.location.x, -o.location.y, o.location.z)
            o.rotation_euler.z += math.pi
        o.location.x += dx
    return before


def preview():
    """A 2-cell room as the Command View sees it (no front walls): a solid wall on the left,
    a doorway on the right, the Shaft opening in the right cell's floor."""
    sf.reset()
    pitch = W + 2 * T
    _moved(lambda: floor(False))
    _moved(lambda: floor(True), pitch)
    for dx in (0.0, pitch):
        _moved(lambda: wall_y("BackWall", D / 2, -1, True, "box"), dx)
    _moved(lambda: wall_x("SideWall", W / 2, -1, False, "box"), 0.0, turn=True)
    _moved(lambda: wall_x("SideWall", W / 2, -1, True, "precise"), pitch)
    out = sf.render_preview("Kit_Shell", CATEGORY, res=640, samples=24, merge="part",
                            views=[(0, 18, False), (-32, 30, False)])
    print(out)


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("-")] or list(PIECES)
    if os.environ.get("SF_EXPORT") == "1":
        for n in names:
            export_piece(n)
    else:
        preview()
