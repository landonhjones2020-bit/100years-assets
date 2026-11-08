"""roomlib: furniture and fittings the room generators share (A1; STYLE.md).

Every room set is one cell's furniture, pivoted at the cell's interior floor centre like the
kit (see generators/Kits/kitlib.py): X with the columns, -Y the front (the Command View side),
+Y the back wall (its face at y = 16), Z up from the floor. Keep the doorways clear: nothing
within 6 studs of either side wall's middle (y -6 to 6 at x = +-16), and leave a walkway
across the front half.

Parts that players or residents bump into get collision "box" and a name of their own;
everything else is decoration (collision "none"), which export_asset(merge="room") pools
into one MeshPart per material.
"""
import math
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Kits"))
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402

W, D, H = 32.0, 32.0, 16.0
BACK = D / 2
_counts: dict = {}


def uid(base: str) -> str:
    """A fresh part name (Crate1, Crate2...): pieces that collide each keep their own box."""
    _counts[base] = _counts.get(base, 0) + 1
    return f"{base}{_counts[base]}"


def reset_ids():
    _counts.clear()


def t(obj, part, swatch, collision="none", mat="SmoothPlastic", **kw):
    return sf.tag(obj, part, swatch, mat, collision=collision, **kw)


def bx(part, swatch, size, loc, collision="none", rot=(0, 0, 0), bevel=0.0, mat="SmoothPlastic", **kw):
    return t(sf.box(size, loc=loc, rot=rot, bevel=bevel, segments=1), part, swatch, collision=collision, mat=mat, **kw)


def cy(part, swatch, r, depth, loc, collision="none", rot=(0, 0, 0), verts=10, mat="SmoothPlastic", **kw):
    return t(sf.cyl(r, depth, loc=loc, rot=rot, verts=verts, bevel=0.0), part, swatch, collision=collision, mat=mat, **kw)


# Props --------------------------------------------------------------------------------------

def crate(x, y, z=0.0, size=2.8, wood="pine", band="walnut", label="teal", part=None):
    part = part or uid("Crate")
    h = size * 0.9
    bx(part, wood, (size, size, h), (x, y, z + h / 2), collision="box", bevel=0.1)
    bx("Decor", band, (size + 0.04, 0.3, h + 0.04), (x, y, z + h / 2))
    bx("Decor", band, (0.3, size + 0.04, h + 0.04), (x, y, z + h / 2))
    bx("Decor", label, (size * 0.45, 0.06, h * 0.3), (x, y - size / 2 - 0.02, z + h * 0.62))


def barrel(x, y, z=0.0, r=1.2, h=3.0, body="olive", rim="gunmetal", part=None):
    part = part or uid("Barrel")
    cy(part, body, r, h, (x, y, z + h / 2), collision="box", verts=10)
    for zz in (0.35, h - 0.35):
        t(sf.torus(r + 0.02, 0.1, loc=(x, y, z + zz), major_segs=10, minor_segs=3), "Decor", rim)
    cy("Decor", "hazard", r * 0.55, 0.05, (x, y, z + h + 0.02), verts=8)


def shelf(x, y, w=6.0, d=1.8, h=8.0, levels=4, part=None, frame="gunmetal", board="steel"):
    part = part or uid("Shelf")
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx("Decor", frame, (0.2, 0.2, h), (x + sx * (w / 2 - 0.1), y + sy * (d / 2 - 0.1), h / 2))
    zs = [0.4 + i * (h - 0.6) / (levels - 1) for i in range(levels)]
    for z in zs:
        bx(part if z == zs[0] else "Decor", board, (w, d, 0.15), (x, y, z), collision="box" if z == zs[0] else "none")
    # one collision box for the whole rack
    bx(part, frame, (w, d, 0.01), (x, y, h), collision="box")
    return zs


def tins(x, y, z, n=4, w=5.0, swatches=("brass", "cream", "rust", "teal")):
    for i in range(n):
        cy("Decor", swatches[i % len(swatches)], 0.35, 0.8, (x - w / 2 + (i + 0.5) * w / n, y, z + 0.4), verts=6)


def boxes_row(x, y, z, n=3, w=5.0, swatch="pine"):
    for i in range(n):
        bx("Decor", swatch, (w / n - 0.3, 1.2, 1.0), (x - w / 2 + (i + 0.5) * w / n, y, z + 0.5), bevel=0.06)


def desk(x, y, w=5.0, d=2.6, part=None, body="teal", top="walnut"):
    part = part or uid("Desk")
    bx(part, body, (w, d, 2.8), (x, y, 1.4), collision="box", bevel=0.15)
    bx("Decor", top, (w + 0.3, d + 0.3, 0.22), (x, y, 2.9), bevel=0.05)
    for i in range(2):
        bx("Decor", "chrome", (0.6, 0.1, 0.15), (x - w / 4 + i * w / 2, y - d / 2 - 0.05, 2.1))


def chair(x, y, yaw=0.0, seat="rust", frame="chrome"):
    a = math.radians(yaw)
    fx, fy = math.sin(a), -math.cos(a)        # the way the sitter faces
    bx("Decor", seat, (1.5, 1.5, 0.32), (x, y, 1.6), bevel=0.1)
    bx("Decor", seat, (1.5, 0.3, 1.4), (x - fx * 0.65, y - fy * 0.65, 2.5), rot=(0, 0, yaw))
    cy("Decor", frame, 0.1, 1.5, (x, y, 0.75), verts=6)
    cy("Decor", frame, 0.6, 0.1, (x, y, 0.05), verts=8)


def stool(x, y, seat="rust"):
    cy("Decor", seat, 0.85, 0.32, (x, y, 2.0), verts=10)
    cy("Decor", "chrome", 0.11, 1.9, (x, y, 1.0), verts=6)
    cy("Decor", "chrome", 0.65, 0.1, (x, y, 0.05), verts=8)


def poster(x, z, band="teal", accent="signal", w=3.0, h=4.0, side="back", y=None):
    """A framed Steadfast poster on the back wall (or a side wall: side='left'/'right')."""
    if side == "back":
        yy = BACK - 0.07 if y is None else y
        bx("Decor", "walnut", (w + 0.4, 0.14, h + 0.4), (x, yy, z), bevel=0.04)
        bx("Decor", "cream", (w, 0.1, h), (x, yy - 0.08, z))
        bx("Decor", band, (w, 0.12, h * 0.22), (x, yy - 0.1, z + h * 0.32))
        cy("Decor", accent, w * 0.2, 0.1, (x, yy - 0.13, z - h * 0.05), rot=(90, 0, 0), verts=10)
        bx("Decor", "rubber", (w * 0.7, 0.12, 0.25), (x, yy - 0.1, z - h * 0.36))
    else:
        s = -1 if side == "left" else 1
        xx = s * (W / 2 - 0.07)
        bx("Decor", "walnut", (0.14, w + 0.4, h + 0.4), (xx, x, z), bevel=0.04)
        bx("Decor", "cream", (0.1, w, h), (xx - s * 0.08, x, z))
        bx("Decor", band, (0.12, w, h * 0.22), (xx - s * 0.1, x, z + h * 0.32))
        cy("Decor", accent, w * 0.2, 0.1, (xx - s * 0.13, x, z - h * 0.05), rot=(0, 90, 0), verts=10)


def clock(x, z, y=BACK):
    cy("Decor", "cream", 1.0, 0.14, (x, y - 0.1, z), rot=(90, 0, 0), verts=12)
    t(sf.torus(1.0, 0.12, loc=(x, y - 0.15, z), rot=(90, 0, 0), major_segs=12, minor_segs=3), "Decor", "chrome")
    bx("Decor", "navy", (0.12, 0.06, 0.7), (x, y - 0.24, z + 0.3))
    bx("Decor", "navy", (0.5, 0.06, 0.1), (x + 0.2, y - 0.24, z))


def pendant(x, y, z_shade=11.5, shade="hazard"):
    """A ceiling pendant lamp; returns the light point (for a Light socket)."""
    cy("Decor", "rubber", 0.05, H - z_shade - 0.3, (x, y, (H + z_shade) / 2), verts=4, cast_shadow=False)
    t(sf.sphere(0.95, loc=(x, y, z_shade), scale=(1, 1, 0.55), segs=8, rings=4), "Decor", shade, cast_shadow=False)
    t(sf.sphere(0.32, loc=(x, y, z_shade - 0.45), segs=6, rings=3), "DecorNeon", "cream", mat="Neon", cast_shadow=False)
    return (x, y, z_shade - 0.7)


def gauge(x, z, y=BACK, r=0.9, face="cream", rim="chrome", needle="signal"):
    cy("Decor", face, r, 0.15, (x, y - 0.1, z), rot=(90, 0, 0), verts=8)
    cy("Decor", rim, r + 0.12, 0.1, (x, y - 0.04, z), rot=(90, 0, 0), verts=8)
    bx("Decor", needle, (0.08, 0.06, r * 0.8), (x + r * 0.2, y - 0.25, z + r * 0.25), rot=(0, 30, 0))


def pipe_run(x0, x1, y, z, r=0.3, swatch="copper"):
    cy("Decor", swatch, r, abs(x1 - x0), ((x0 + x1) / 2, y, z), rot=(0, 90, 0), verts=8)


def pipe_up(x, y, z0, z1, r=0.3, swatch="copper"):
    cy("Decor", swatch, r, abs(z1 - z0), (x, y, (z0 + z1) / 2), verts=8)


def valve(x, y, z, r=0.8, swatch="signal", facing="front"):
    rot = (90, 0, 0) if facing == "front" else (0, 90, 0)
    t(sf.torus(r, 0.13, loc=(x, y, z), rot=rot, major_segs=10, minor_segs=3), "Decor", swatch)
    for a in (0, 90):
        bx("Decor", swatch, (r * 2, 0.1, 0.14) if facing == "front" else (0.1, r * 2, 0.14), (x, y, z), rot=(0, a, 0) if facing == "front" else (a, 0, 0))
    cy("Decor", "gunmetal", 0.22, 0.4, (x, y, z), rot=rot, verts=8)


def rug(x, y, w=8.0, d=6.0, main="navy", edge="cream"):
    bx("Decor", edge, (w + 0.5, d + 0.5, 0.05), (x, y, 0.03))
    bx("Decor", main, (w, d, 0.06), (x, y, 0.05))


def footlocker(x, y, swatch="olive"):
    bx(uid("Footlocker"), swatch, (2.6, 1.6, 1.3), (x, y, 0.65), collision="box", bevel=0.12)
    bx("Decor", "brass", (2.64, 1.64, 0.15), (x, y, 1.0))
    bx("Decor", "brass", (0.4, 0.08, 0.4), (x, y - 0.82, 0.8))


def console(x, y, w=4.0, part=None, body="teal", lights=("signal", "leaf", "hazard")):
    part = part or uid("Console")
    """A sloped Steadfast control console with dials and buttons."""
    bx(part, body, (w, 2.2, 2.8), (x, y, 1.4), collision="box", bevel=0.15)
    bx("Decor", "gunmetal", (w - 0.2, 1.4, 0.3), (x, y - 0.35, 3.05), rot=(-25, 0, 0))
    for i in range(3):
        gx = x - w / 2 + 0.8 + i * (w - 1.6) / 2
        cy("Decor", "cream", 0.38, 0.1, (gx, y - 0.55, 3.25), rot=(65, 0, 0), verts=10)
    for i, sw in enumerate(lights):
        cy("DecorNeon", sw, 0.15, 0.12, (x - 0.6 + i * 0.6, y - 1.05, 2.4), rot=(90, 0, 0), verts=8, mat="Neon",
           cast_shadow=False)
    return (x, y - 2.0, 0.0)


def work_sockets(spots, sockets=None):
    out = sockets if sockets is not None else {}
    for i, (x, y, yaw) in enumerate(spots):
        out[f"WorkSpot{i + 1}"] = ((x, y, 0.0), yaw)
    return out


# Preview ------------------------------------------------------------------------------------

def preview_in_shell(asset: str, category: str, build_levels, levels=(1, 2, 3), name=None):
    """Render each level inside the cell shell side by side, front wall and ceiling off (the
    Command View's look); build_levels(level) makes one level's furniture at the origin."""
    import Kit_Shell as shell
    sf.reset()
    reset_ids()
    pitch = W + 2.0 + 6.0
    for i, level in enumerate(levels):
        before = set(bpy.context.scene.objects)
        build_levels(level)
        shell.floor(False)
        shell.wall_y("BackWall", D / 2, -1, True, "box")
        shell.wall_x("SideWall", W / 2, -1, True, "precise")
        for o in [o for o in bpy.context.scene.objects if o not in before]:
            o.location.x += (i - (len(levels) - 1) / 2) * pitch
    return sf.render_preview(asset, category, res=720, samples=24, merge="room",
                             views=[(0, 18, False), (-30, 30, False)], out_name=name or asset)


def export_levels(prefix: str, category: str, build_levels, meta, budget=3000, levels=(1, 2, 3)):
    for level in levels:
        sf.reset()
        reset_ids()
        sockets = build_levels(level) or {}
        name = f"{prefix}_L{level}"
        doc = sf.export_asset(name, category, pivot=(0, 0, 0), merge="room", budget=budget, step="A1",
                              sockets=sockets, meta=dict(meta, level=level))
        print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


def main(prefix: str, category: str, build_levels, meta, budget=3000):
    if os.environ.get("SF_EXPORT") == "1":
        export_levels(prefix, category, build_levels, meta, budget)
    else:
        picked = tuple(int(a) for a in sys.argv[1:] if a.isdigit()) or (1, 2, 3)
        suffix = "" if picked == (1, 2, 3) else "_L" + "".join(map(str, picked))
        print(preview_in_shell(prefix, category, build_levels, picked, name=prefix + suffix))
