"""Kit_CellShell: one bunker cell's shell (bible Section 6: 32 wide x 16 tall x 32 deep inside,
2-stud slabs between floors; rooms connect sideways through doorways in shared walls; front
walls are solid while you play and hide in the Command View).

Every wall is its own MeshPart with a role, so code can fade the front wall, hide it in the
Command View, or swap a side wall for a sealed one. Walls are Steadfast two-tone: teal
wainscot with a chrome rail, cream steel panels above, steel ribs, a pipe run along the back.

Pivot = the centre of the interior floor (0, 0, 0), the same pivot every room's furniture
uses, so a room is the shell plus its furniture at one CFrame. Grid pitch: 34 x 18 studs
(32 interior + 1-stud walls each side; 16 interior + a 2-stud slab).

Run:  SF_EXPORT=1 python3 generators/Kits/Kit_CellShell.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Kit_CellShell", "Kit"
BUDGET = 2000
W, D, H = 32.0, 32.0, 16.0        # interior
T = 1.0                           # wall thickness owned by this cell (half of a shared wall)
DOOR_W, DOOR_H = 8.0, 10.0
WAINSCOT = 4.5


def wall_x(part, role, x_face, inward, door: bool, collision):
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
        sf.tag(pc, part, "cream", collision=collision, role=role)
    # teal wainscot and chrome rail on the interior face (split around the door)
    xi = x_face + inward * 0.08
    spans = [(-D / 2, -DOOR_W / 2), (DOOR_W / 2, D / 2)] if door else [(-D / 2, D / 2)]
    for y0, y1 in spans:
        ln, yc = y1 - y0, (y0 + y1) / 2
        sf.tag(sf.box((0.16, ln, WAINSCOT), loc=(xi, yc, WAINSCOT / 2), bevel=0.0), part, "teal", collision=collision, role=role)
        sf.tag(sf.box((0.3, ln, 0.22), loc=(x_face + inward * 0.15, yc, WAINSCOT), bevel=0.04, segments=1), part, "chrome", collision=collision, role=role)
    if door:
        # a chunky bulkhead frame: steel jambs, a Signal Orange header, hazard-yellow sills
        for sy in (-1, 1):
            sf.tag(sf.box((0.6, 0.7, DOOR_H), loc=(x_face + inward * 0.3, sy * (DOOR_W / 2 + 0.35), DOOR_H / 2),
                          bevel=0.08, segments=1), part, "steel", collision=collision, role=role)
        sf.tag(sf.box((0.6, DOOR_W + 1.4, 0.9), loc=(x_face + inward * 0.3, 0, DOOR_H + 0.45), bevel=0.08, segments=1),
               part, "signal", collision=collision, role=role)
        sf.tag(sf.box((0.7, DOOR_W, 0.12), loc=(x_face, 0, 0.06), bevel=0.0), part, "hazard", collision=collision, role=role)


def wall_y(part, role, y_face, inward, pipes: bool, collision):
    """A back or front wall on the plane y = y_face, spanning the full outer width."""
    yc = y_face - inward * T / 2
    sf.tag(sf.box((W + 2 * T, T, H), loc=(0, yc, H / 2), bevel=0.0), part, "cream", collision=collision, role=role)
    yi = y_face + inward * 0.08
    sf.tag(sf.box((W, 0.16, WAINSCOT), loc=(0, yi, WAINSCOT / 2), bevel=0.0), part, "teal", collision=collision, role=role)
    sf.tag(sf.box((W, 0.3, 0.22), loc=(0, y_face + inward * 0.15, WAINSCOT), bevel=0.04, segments=1), part, "chrome", collision=collision, role=role)
    for x in (-12, -4, 4, 12):   # steel ribs with a rivet cap
        sf.tag(sf.box((0.7, 0.35, H), loc=(x, y_face + inward * 0.17, H / 2), bevel=0.06, segments=1), part, "steel", collision=collision, role=role)
    if pipes:
        for z, r, sw in ((13.6, 0.32, "copper"), (14.5, 0.26, "steel")):
            sf.tag(sf.cyl(r, W, loc=(0, y_face + inward * 0.75, z), rot=(0, 90, 0), verts=8, bevel=0.0), part, sw, collision=collision, role=role)
        for x in (-12, -4, 4, 12):
            sf.tag(sf.box((0.3, 0.9, 1.4), loc=(x, y_face + inward * 0.5, 14.05), bevel=0.0), part, "gunmetal", collision=collision, role=role)


def build():
    # floor slab with raised sandstone tiles over dark grout
    sf.tag(sf.box((W + 2 * T, D + 2 * T, 2.0), loc=(0, 0, -1.0), bevel=0.0), "Floor", "basalt", collision="box", role="Floor")
    n, gap = 4, 0.25
    tile = (W - gap * (n + 1)) / n
    for i in range(n):
        for j in range(n):
            x = -W / 2 + gap + tile / 2 + i * (tile + gap)
            y = -D / 2 + gap + tile / 2 + j * (tile + gap)
            sf.tag(sf.box((tile, tile, 0.06), loc=(x, y, 0.03), bevel=0.0), "Floor", "sandstone", collision="box", role="Floor")
    # ceiling panel with three steel beams and two light housings (Neon lens = the visible light)
    sf.tag(sf.box((W, D, 0.5), loc=(0, 0, H - 0.25), bevel=0.0), "Ceiling", "cream", collision="box", role="Ceiling")
    for y in (-10.5, 0, 10.5):
        sf.tag(sf.box((W, 0.9, 0.8), loc=(0, y, H - 0.9), bevel=0.06, segments=1), "Ceiling", "steel", collision="box", role="Ceiling")
    for x in (-8, 8):
        sf.tag(sf.box((4.0, 1.6, 0.5), loc=(x, 5.25, H - 0.75), bevel=0.06, segments=1), "Ceiling", "gunmetal", collision="box", role="Ceiling")
        sf.tag(sf.box((3.4, 1.0, 0.1), loc=(x, 5.25, H - 1.03), bevel=0.0), "CeilingLight", "cream", "Neon", collision="none", cast_shadow=False, role="CeilingLight")
    # Side walls are named by Roblox axis so grid code can't mix them up: Blender +X is
    # Roblox -X. Seen from the front (the Command View), SideWallXNeg is on the right.
    wall_x("SideWallXNeg", "SideWallXNeg", W / 2, -1, door=True, collision="precise")
    wall_x("SideWallXPos", "SideWallXPos", -W / 2, 1, door=True, collision="precise")
    wall_y("BackWall", "BackWall", D / 2, -1, pipes=True, collision="box")
    wall_y("FrontWall", "FrontWall", -D / 2, 1, pipes=False, collision="box")
    return {"export": {
        "budget": BUDGET, "step": "A0", "pivot": (0, 0, 0), "merge": "part",
        "sockets": {"DoorXNeg": ((W / 2, 0, 0), 90.0), "DoorXPos": ((-W / 2, 0, 0), -90.0),
                    "Light1": ((-8, 5.25, H - 1.2), 0.0), "Light2": ((8, 5.25, H - 1.2), 0.0)},
        "meta": {"interior": [W, H, D], "gridPitch": [W + 2 * T, H + 2.0, D + 2 * T], "door": [DOOR_W, DOOR_H]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
