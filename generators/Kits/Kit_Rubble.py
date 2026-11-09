"""Kit_Rubble: cave-in rubble (Prompt 13; bible Section 24: a cave-in drops rubble that blocks a
doorway or a tunnel until it is dug out with a Drill or a Pickaxe or smashed with melee).

    Kit_Rubble_Doorway  plugs a room's 8 x 10 doorway (kitlib DOOR_W x DOOR_H): a heap of
                        rock wedged up under the header, a broken concrete ceiling slab with
                        rusty rebar leaning on each face, a fallen steel beam across the
                        front, a snapped conduit and gravel spilling into both rooms.
    Kit_Rubble_Tunnel   fills a tunnel's whole cross-section (32 deep x 16 high): a rockfall of
                        big boulders up to the ceiling, flat slabs that sheared off the roof
                        and a gravel skirt. DisasterService also uses it for a blocked opening
                        between two dug cells (the same 32 x 16 face).

DisasterService places each at a blocked face: pivot = the face's centre on the floor, width
along Blender X (it turns the copy so the width lies along the wall), thickness along Y, the
pile spilling a few studs into the cells on both sides. Both faces are seen (one from each
side), so both are dressed. The game makes every part non-colliding and fades it for the
camera; an invisible block does the blocking, and the pile sinks as it is broken up.

Rock is band-neutral (stone, basalt and ash), since a cave-in can happen at any depth.

    python3 generators/Kits/Kit_Rubble.py              preview of both
    SF_EXPORT=1 python3 generators/Kits/Kit_Rubble.py  exports both
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
import steadfast as sf  # noqa: E402
from kitlib import DOOR_H, DOOR_W, D, H, rock_block, t  # noqa: E402

CATEGORY = "Kit"
BUDGETS = {"Kit_Rubble_Doorway": 1500, "Kit_Rubble_Tunnel": 2500}


def mottle(obj, seed, dark=0.28, light=0.12):
    """Some faces darker (basalt) and a few lighter (ash), so the rock isn't one flat colour."""
    rnd = random.Random(seed)
    picks = {}

    def pick(c):
        key = (round(c.x, 2), round(c.y, 2), round(c.z, 2))
        if key not in picks:
            r = rnd.random()
            picks[key] = "light" if r < light else ("dark" if r < light + dark else "")
        return picks[key]
    sf.paint(obj, "basalt", lambda c, n: pick(c) == "dark")
    sf.paint(obj, "ash", lambda c, n: pick(c) == "light")


def lump(part, loc, r, seed, segs=6, rings=4, swatch="stone", rough=0.16, resting=False):
    """A rock: a squat low-poly sphere with its points pushed in and out (seeded), turned a little.
    resting=True sits it on the floor (its lowest point just under z = 0) at loc's x and y."""
    rnd = random.Random(seed)
    o = sf.sphere(r, scale=(rnd.uniform(0.9, 1.3), rnd.uniform(0.8, 1.15), rnd.uniform(0.62, 0.88)), segs=segs, rings=rings)
    for v in o.data.vertices:
        v.co *= 1.0 + rnd.uniform(-rough, rough)
    o.rotation_euler = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, math.tau))
    o.location = loc
    if resting:
        bpy.context.view_layer.update()
        low = min((o.matrix_world @ v.co).z for v in o.data.vertices)
        o.location.z += -0.12 - low
    t(o, part, swatch, smooth_angle=None)
    mottle(o, seed + 7)
    return o


def slab_chunk(part, swatch, size, loc, rot, seed):
    """A broken flat block (a ceiling slab or a sheared roof rock): a box with its corners nudged."""
    rnd = random.Random(seed)
    o = sf.box(size, bevel=0.0)
    for v in o.data.vertices:
        v.co.x += rnd.uniform(-0.18, 0.18) * size[0]
        v.co.z += rnd.uniform(-0.12, 0.12) * size[2]
    o.location = loc
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    return t(o, part, swatch, smooth_angle=None)


def rod(part, swatch, start, direction, length, radius):
    """A thin bar from start along direction (rebar)."""
    o = sf.cyl(radius, length, verts=5, bevel=0.0)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = direction.to_track_quat("Z", "Y")
    o.location = start + direction * (length / 2)
    return t(o, part, swatch, smooth_angle=None)


def lay(obj, centre, up, normal):
    """Place obj with its local Z along `up` and its local Y along `normal` (both world vectors)."""
    from mathutils import Matrix
    z = up.normalized()
    y = (normal - z * normal.dot(z)).normalized()
    x = y.cross(z)
    obj.matrix_world = Matrix.Translation(centre) @ Matrix((x, y, z)).transposed().to_4x4()
    return obj


def on_slope(surface, u, tt, side):
    """A point on a spill's slope, the way up the slope there and the slope's outward normal."""
    p = surface(u, tt)
    up = (surface(u, min(tt + 0.12, 1.0)) - surface(u, max(tt - 0.12, 0.0))).normalized()
    across = Vector((1.0, 0.0, 0.0))
    normal = up.cross(across) if side > 0 else across.cross(up)
    return p, up, normal.normalized()


def bar(part, swatch, p0, p1, w, h, bevel=0.05):
    """A beam from p0 to p1, w wide and h deep."""
    p0, p1 = Vector(p0), Vector(p1)
    o = sf.box((w, h, (p1 - p0).length), bevel=bevel, segments=1)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (p1 - p0).normalized().to_track_quat("Z", "Y")
    o.location = (p0 + p1) / 2
    return t(o, part, swatch)


def spill(part, xc, half_w, y_face, side, depth, height, seed, nx=8, nt=4, swatch="stone"):
    """A mound of broken rock leaning on the face y = y_face and spreading `depth` toward `side`
    (-1 or +1), `height` high at the middle, tapering to nothing at x = xc +- half_w. Open at the
    back (against the core) and the bottom (on the floor); its slope is jittered (seeded).
    Returns surface(u, t) -> point: u -1..1 along the face, t 0 (toe) to 1 (top)."""
    import bmesh
    rnd = random.Random(seed)

    def surface(u, t):
        f = max(0.0, 1.0 - abs(u) ** 3)
        return Vector((xc + u * half_w, y_face + side * f * depth * (1.0 - t) ** 0.75,
                       f * height * (1.0 - (1.0 - t) ** 1.6)))
    bm = bmesh.new()
    grid = []
    for i in range(nx + 1):
        u = -1.0 + 2.0 * i / nx
        row = []
        for j in range(nt + 1):
            p = surface(u, j / nt)
            if 0 < i < nx and 0 < j < nt:
                push = rnd.uniform(-0.25, 0.6) * min(depth, height) / nt
                p += Vector((rnd.uniform(-0.3, 0.3) * half_w / nx, side * push, push * 0.6))
            row.append(bm.verts.new(p))
        grid.append(row)
    for i in range(nx):
        for j in range(nt):
            quad = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
            if side < 0:
                quad.reverse()
            if len({v.co.to_tuple(4) for v in quad}) >= 3:
                bm.faces.new(quad)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="ALTERNATE")
    obj = sf.from_bmesh(bm, part)
    # outward normals: the mound is seen from outside (side, up)
    for poly in obj.data.polygons:
        if poly.normal.y * side < -0.05 or poly.normal.z < -0.5:
            poly.flip()
    t(obj, part, swatch, smooth_angle=None)
    mottle(obj, seed + 3, dark=0.3, light=0.15)
    return surface


def core(part, lo, hi, segs, seed, bulge):
    """The plug itself: a block of rock filling the face, its two faces (y) bulging out craggily."""
    o = rock_block(part, "stone", lo, hi, segs=segs, seed=seed, collision="none",
                   jitter={(1, -1): bulge, (1, 1): bulge, (0, -1): (-0.7, 0.0), (0, 1): (-0.7, 0.0)})
    mottle(o, seed + 5, dark=0.32, light=0.1)
    return o


def on_surface(surface, u, tt, side, r, seed, rough=0.16):
    """A rock half sunk into a spill's slope."""
    p = surface(u, tt) + Vector((0.0, side * r * 0.35, r * 0.2))
    return lump("Rubble", tuple(p), r, seed, rough=rough)


def gravel(part, xs, ys, count, seed):
    """Small stones scattered round the toes, on both sides."""
    rnd = random.Random(seed)
    for i in range(count):
        side = -1 if i % 2 == 0 else 1
        lump(part, (rnd.uniform(*xs), side * rnd.uniform(*ys), 0.0), rnd.uniform(0.28, 0.55), seed + 31 * i, segs=5, rings=3,
             swatch="ash" if i % 3 == 0 else "stone", resting=True)


def doorway():
    """A plug of rock in the 8 x 10 doorway, a mound spilling into the room on each side."""
    seed = 401
    half = DOOR_W / 2
    core("Rubble", (-half - 0.2, -1.0, 0.0), (half + 0.2, 1.0, DOOR_H + 0.3), (4, 1, 5), seed, (-0.2, 0.9))
    for side in (-1, 1):
        surface = spill("Rubble", 0.0, half + 1.6, side * 1.1, side, 3.2, 5.2, seed + 10 * side)
        for k, (u, tt, r) in enumerate(((-0.55, 0.35, 1.2), (0.15, 0.45, 1.35), (0.62, 0.3, 1.05), (-0.15, 0.85, 1.1),
                                         (0.45, 0.8, 1.0), (-0.75, 0.15, 0.8))):
            on_surface(surface, u * (1 if side < 0 else -1), tt, side, r, seed + 100 * side + 13 * k)
        # rocks stuck in the plug's face above the mound, wedged up under the header
        for k, (x, z, r) in enumerate(((-2.7, 6.0, 1.15), (0.3, 6.6, 1.3), (2.9, 5.8, 1.0), (-1.4, 8.6, 1.05), (1.9, 8.8, 1.1))):
            x = x * (1 if side < 0 else -1)
            lump("Rubble", (x, side * (1.25 + r * 0.3), z), r, seed + 200 * side + 17 * k)
        # a broken concrete ceiling slab lying on the mound, rusty rebar out of its broken top edge
        size = (3.0, 0.55, 2.3) if side < 0 else (2.5, 0.5, 1.9)
        p, up, normal = on_slope(surface, 0.3 * side, 0.42, side)
        o = slab_chunk("Concrete", "sandstone", size, (0, 0, 0), (0, 0, 0), seed + 90 + side)
        lay(o, p + normal * (size[1] / 2 + 0.25), up, normal)
        sf.paint(o, "ash", lambda c, n: n.z < -0.3)
        bpy.context.view_layer.update()
        top = (o.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()
        for k in range(3):
            edge = o.matrix_world @ Vector(((k - 1) * size[0] / 3, 0, size[2] / 2 - 0.05))
            bend = Vector((0.2 * (k - 1), side * 0.25, 0.2 if k == 1 else 0.0))
            rod("Rebar", "rust", edge, (top + bend).normalized(), 1.1 - 0.2 * abs(k - 1), 0.06)
    gravel("Rubble", (-half - 1.0, half + 1.0), (3.0, 4.6), 6, seed + 500)
    # a steel beam fallen across the front face, a lighter one across the back
    bar("Beam", "gunmetal", (-4.8, -4.0, 0.3), (3.3, -2.2, 7.9), 0.5, 0.36)
    bar("Beam", "steel", (4.6, 3.6, 0.3), (-2.4, 2.1, 6.6), 0.42, 0.3)
    # a snapped conduit hanging out of the top of the plug
    pipe = sf.tube([(-3.2, -0.6, 10.2), (-2.8, -1.7, 9.0), (-3.2, -2.4, 7.7)], [0.16, 0.16, 0.16], sides=6, resolution=3,
                   name="Conduit")
    t(pipe, "Conduit", "copper")
    t(sf.cyl(0.2, 0.18, loc=(-3.22, -2.45, 7.6), rot=(30, 0, 0), verts=6, bevel=0.0), "Conduit", "gunmetal")
    return {"pivot": (0.0, 0.0, 0.0)}


def tunnel():
    """A rockfall filling a tunnel's 32 x 16 cross-section to the roof, mounds on both sides."""
    seed = 733
    half = D / 2
    rnd = random.Random(seed)
    core("Rubble", (-half, -1.6, 0.0), (half, 1.6, H), (8, 1, 5), seed, (-0.3, 1.3))
    for side in (-1, 1):
        surface = spill("Rubble", 0.0, half + 0.6, side * 1.4, side, 5.2, 9.0, seed + 10 * side, nx=12, nt=5)
        for k in range(7):
            u = -0.85 + k * 0.28 + rnd.uniform(-0.08, 0.08)
            on_surface(surface, u, rnd.uniform(0.2, 0.75), side, rnd.uniform(1.4, 2.2), seed + 100 * side + 13 * k)
        # boulders stuck in the plug's face above the mound, up to the roof
        for k, x in enumerate((-13.0, -8.0, -3.0, 2.0, 7.0, 12.2)):
            for row, z in enumerate((10.4, 14.0)):
                r = rnd.uniform(1.8, 2.5)
                lump("Rubble", (x + rnd.uniform(-1.0, 1.0) + row * 2.2, side * (1.5 + r * 0.3), z + rnd.uniform(-0.6, 0.6)), r,
                     seed + 300 * side + 29 * k + 7 * row)
        # boulders low on the face at the ends, where the mound tapers away
        for k, x in enumerate((-14.2, 14.0)):
            r = rnd.uniform(2.2, 2.8)
            lump("Rubble", (x, side * (1.6 + r * 0.3), rnd.uniform(4.0, 6.5)), r, seed + 700 * side + 31 * k)
        # flat slabs that sheared off the roof, lying on the mound
        for i, (u, tt, size) in enumerate(((-0.42 * side, 0.4, (6.0, 1.1, 4.0)), (0.5 * side, 0.32, (4.6, 1.0, 3.2)))):
            p, up, normal = on_slope(surface, u, tt, side)
            o = slab_chunk("RoofSlabs", "stone", size, (0, 0, 0), (0, 0, 0), seed + 3000 + i + 10 * side)
            lay(o, p + normal * (size[1] / 2 + 0.2), up, normal)
            mottle(o, seed + 3100 + i + 10 * side, dark=0.35)
    gravel("Rubble", (-half + 1.0, half - 1.0), (5.2, 7.0), 14, seed + 1500)
    return {"pivot": (0.0, 0.0, 0.0)}


VARIANTS = {"Kit_Rubble_Doorway": (doorway, {"kit": "rubble", "shape": "Doorway", "face": [DOOR_W, DOOR_H]}),
            "Kit_Rubble_Tunnel": (tunnel, {"kit": "rubble", "shape": "Tunnel", "face": [D, H]})}


def export(name: str):
    build, meta = VARIANTS[name]
    sf.reset()
    extra = build() or {}
    print(f"[{name}] triangles (before merge): {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(sf.render_preview(name, CATEGORY, res=640, samples=24, merge="part",
                                views=[(-30, 18, False), (150, 18, True)]))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(name, CATEGORY, pivot=extra["pivot"], merge="room", budget=BUDGETS[name], step="P13",
                              meta=meta)
        print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


if __name__ == "__main__":
    for variant in (sys.argv[1:] or list(VARIANTS)):
        export(variant)
