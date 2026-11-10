"""townkit: fast geometry for Brightwater, clean (the lobby: the day before the bomb) or ruined
(the Run's surface). STYLE.md sections 1, 2 and 4; bible Sections 12 and 21.

Why not steadfast's box() and cyl(): a building is thousands of pieces, and one Blender object per
piece (bpy.ops) takes minutes. A Kit collects raw vertices and faces in buckets, one per swatch and
part setting, and makes a handful of tagged objects at the end, which steadfast then exports and
previews as usual.

Space (as townlib): X across the building, -Y its front (the street), +Y its back, Z up; the pivot
is the footprint's centre on the ground.

Architecture is decoration: every mesh is "Decor" (no collision), merged per material, and the
walls players touch are invisible boxes (Kit.collider) the Studio builder makes from the sidecar's
meta.colliders. A box per wall is cheaper than a collision mesh per segment, and exact.

    k = Kit()
    k.box("rust", (40, 30, 24), (0, 0, 12))            # a brick body
    f = k.face((-20, -15, 0), 0)                        # its street face: u runs along +X
    f.on("porcelain", 2, 38, 22, 23, 0.6)               # a band proud of the wall
    k.finish()                                          # tagged objects, export kwargs

Neon and Glass MeshParts take one colour each in Studio (AssetSetup), so those buckets are split
per swatch on export (steadfast.SPLIT_UNTEXTURED).
"""
from __future__ import annotations

import contextlib
import math
import os
import random
import sys

import bpy  # noqa: I001  (bpy first: it provides bmesh and mathutils)
import bmesh
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import steadfast as sf  # noqa: E402

sf.SPLIT_UNTEXTURED = True
sf.DECOR_CAP = 12000          # a merged decoration mesh over this is cut in pieces (Roblox refuses meshes much over 20,000 triangles)
FONTS = os.path.join(HERE, "fonts")
GLASS_T = 0.45


def R(deg: float) -> float:
    return math.radians(deg)


def rot_matrix(rot) -> Matrix:
    return Euler((R(rot[0]), R(rot[1]), R(rot[2])), "XYZ").to_matrix().to_4x4()


class Bucket:
    __slots__ = ("verts", "faces", "smooth")

    def __init__(self):
        self.verts: list = []
        self.faces: list = []


class Kit:
    """Collects one asset's geometry."""

    def __init__(self, seed: int = 1):
        self.buckets: dict[tuple, Bucket] = {}
        self.stack: list[Matrix] = [Matrix.Identity(4)]
        self.colliders: list[list[float]] = []
        self.sockets: dict = {}
        self.lights: list[dict] = []
        self.rng = random.Random(seed)
        self._ids: dict[str, int] = {}
        self._fonts: dict[str, object] = {}
        self.tris = 0

    # -- placement ---------------------------------------------------------------------------
    @property
    def M(self) -> Matrix:
        return self.stack[-1]

    @contextlib.contextmanager
    def at(self, loc=(0, 0, 0), yaw: float = 0.0, scale: float = 1.0, rot=None):
        """Everything built inside is moved to loc and turned (yaw about Z, or a full rot)."""
        m = Matrix.Translation(Vector(loc)) @ (rot_matrix(rot) if rot else Matrix.Rotation(R(yaw), 4, "Z"))
        if scale != 1.0:
            m = m @ Matrix.Scale(scale, 4)
        self.stack.append(self.M @ m)
        try:
            yield self
        finally:
            self.stack.pop()

    def uid(self, base: str) -> str:
        self._ids[base] = self._ids.get(base, 0) + 1
        return f"{base}{self._ids[base]}"

    def world(self, p) -> Vector:
        return self.M @ Vector(p)

    # -- buckets -----------------------------------------------------------------------------
    def _bucket(self, swatch: str, mat: str = "SmoothPlastic", part: str = "Decor", collision: str = "none",
                shadow: bool = True, transparency: float = 0.0, role: str | None = None, smooth: float = 35.0,
                tint: str | None = None) -> Bucket:
        """tint: the colour (a swatch name) a part on the "tint" swatch gets until the game sets its own."""
        sf.swatch(swatch)
        key = (part, swatch, mat, collision, shadow, round(transparency, 3), role, smooth, tint)
        b = self.buckets.get(key)
        if b is None:
            b = self.buckets[key] = Bucket()
        return b

    def add(self, swatch: str, verts, faces, m: Matrix | None = None, **kw) -> None:
        """Raw geometry: verts in local space, faces as index tuples (counter-clockwise from outside)."""
        b = self._bucket(swatch, **kw)
        mm = self.M @ m if m is not None else self.M
        base = len(b.verts)
        flip = mm.determinant() < 0
        b.verts.extend(mm @ Vector(v) for v in verts)
        for f in faces:
            b.faces.append(tuple(base + i for i in (reversed(f) if flip else f)))
            self.tris += len(f) - 2

    def add_bm(self, swatch: str, bm: bmesh.types.BMesh, m: Matrix | None = None, skip=None, **kw) -> None:
        """A temporary bmesh's geometry (freed here). skip(face) drops faces (hidden backs)."""
        bm.verts.index_update()
        verts = [v.co.copy() for v in bm.verts]
        faces = [tuple(v.index for v in f.verts) for f in bm.faces if not (skip and skip(f))]
        bm.free()
        self.add(swatch, verts, faces, m, **kw)

    # -- primitives --------------------------------------------------------------------------
    def box(self, swatch: str, size, loc=(0, 0, 0), rot=(0, 0, 0), open_=(), **kw) -> None:
        """A box centred at loc. open_: faces to leave out, of "x-", "x+", "y-", "y+", "z-", "z+"."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
             (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        all_faces = {"z-": (0, 3, 2, 1), "z+": (4, 5, 6, 7), "y-": (0, 1, 5, 4), "x+": (1, 2, 6, 5),
                     "y+": (2, 3, 7, 6), "x-": (3, 0, 4, 7)}
        faces = [f for name, f in all_faces.items() if name not in open_]
        m = Matrix.Translation(Vector(loc))
        if rot != (0, 0, 0):
            m = m @ rot_matrix(rot)
        self.add(swatch, v, faces, m, **kw)

    def span(self, swatch: str, x0, x1, y0, y1, z0, z1, **kw) -> None:
        """A box by its extents."""
        self.box(swatch, (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), **kw)

    def cyl(self, swatch: str, r: float, depth: float, loc=(0, 0, 0), rot=(0, 0, 0), verts: int = 10,
            r_top: float | None = None, caps=(True, True), round_: bool = True, **kw) -> None:
        """A cylinder (or cone frustum) along local Z, centred at loc. round_: shade its side smooth."""
        rt = r if r_top is None else r_top
        hz = depth / 2
        v = []
        for i in range(verts):
            a = 2 * math.pi * i / verts
            v.append((r * math.cos(a), r * math.sin(a), -hz))
        for i in range(verts):
            a = 2 * math.pi * i / verts
            v.append((rt * math.cos(a), rt * math.sin(a), hz))
        faces = []
        for i in range(verts):
            j = (i + 1) % verts
            faces.append((i, j, verts + j, verts + i))
        if caps[0] and r > 1e-4:
            faces.append(tuple(reversed(range(verts))))
        if caps[1] and rt > 1e-4:
            faces.append(tuple(range(verts, 2 * verts)))
        m = Matrix.Translation(Vector(loc))
        if rot != (0, 0, 0):
            m = m @ rot_matrix(rot)
        if round_:
            kw.setdefault("smooth", 62.0)
        self.add(swatch, v, faces, m, **kw)

    def pole(self, swatch: str, r: float, p0, p1, verts: int = 8, r_top: float | None = None, **kw) -> None:
        """A cylinder between two points."""
        a, b = Vector(p0), Vector(p1)
        d = b - a
        ln = d.length
        if ln < 1e-5:
            return
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
        rt = r if r_top is None else r_top
        hz = ln / 2
        v = [(r * math.cos(2 * math.pi * i / verts), r * math.sin(2 * math.pi * i / verts), -hz) for i in range(verts)]
        v += [(rt * math.cos(2 * math.pi * i / verts), rt * math.sin(2 * math.pi * i / verts), hz) for i in range(verts)]
        faces = [(i, (i + 1) % verts, verts + (i + 1) % verts, verts + i) for i in range(verts)]
        faces.append(tuple(reversed(range(verts))))
        faces.append(tuple(range(verts, 2 * verts)))
        kw.setdefault("smooth", 62.0)
        self.add(swatch, v, faces, m, **kw)

    def wire(self, swatch: str, pts, r: float = 0.08, verts: int = 4, sag: float = 0.0, steps: int = 6, **kw) -> None:
        """A thin run through points; sag > 0 hangs each stretch like a cable."""
        pts = [Vector(p) for p in pts]
        for a, b in zip(pts, pts[1:]):
            if sag > 0:
                prev = a
                for i in range(1, steps + 1):
                    t = i / steps
                    p = a.lerp(b, t)
                    p.z -= sag * 4 * t * (1 - t)
                    self.pole(swatch, r, prev, p, verts=verts, **kw)
                    prev = p
            else:
                self.pole(swatch, r, a, b, verts=verts, **kw)

    def sphere(self, swatch: str, r: float, loc=(0, 0, 0), scale=(1, 1, 1), segs: int = 10, rings: int = 6,
               rot=(0, 0, 0), **kw) -> None:
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
        m = Matrix.Translation(Vector(loc)) @ rot_matrix(rot) @ Matrix.Diagonal(Vector((*scale, 1)))
        kw.setdefault("smooth", 75.0)
        self.add_bm(swatch, bm, m, **kw)

    def blob(self, swatch: str, r: float, loc=(0, 0, 0), scale=(1, 1, 1), detail: int = 1, jitter: float = 0.0,
             seed: int = 0, faceted: bool = True, **kw) -> None:
        """An icosphere, optionally lumpy: tree crowns, bushes, rocks, smoke."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=r)
        if jitter > 0:
            rng = random.Random(seed)
            for v in bm.verts:
                v.co *= 1 + rng.uniform(-jitter, jitter)
        m = Matrix.Translation(Vector(loc)) @ Matrix.Diagonal(Vector((*scale, 1)))
        kw.setdefault("smooth", -1.0 if faceted else 75.0)
        self.add_bm(swatch, bm, m, **kw)

    def prism(self, swatch: str, outline, depth: float, m: Matrix | None = None, caps=(True, True), **kw) -> None:
        """A 2D outline (local XY, any winding, may be concave) extruded from z = 0 to depth."""
        pts = list(outline)
        area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
        if area < 0:
            pts.reverse()
        n = len(pts)
        v = [(x, y, 0.0) for x, y in pts] + [(x, y, depth) for x, y in pts]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        if caps[0]:
            faces.append(tuple(reversed(range(n))))
        if caps[1]:
            faces.append(tuple(range(n, 2 * n)))
        if depth < 0:
            faces = [tuple(reversed(f)) for f in faces]
        self.add(swatch, v, faces, m, **kw)

    def prism_x(self, swatch: str, profile_yz, x0: float, x1: float, **kw) -> None:
        """A (y, z) profile swept along X from x0 to x1: cornices, kerbs, awnings, gable roofs."""
        # local X -> world Y, local Y -> world Z, local Z -> world X
        m = Matrix(((0, 0, 1, x0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
        self.prism(swatch, profile_yz, x1 - x0, m, **kw)

    def prism_y(self, swatch: str, profile_xz, y0: float, y1: float, **kw) -> None:
        """An (x, z) outline, as seen from the front, extruded along Y from y0 to y1."""
        # local X -> world X, local Y -> world Z, local Z -> world -Y (so the outline keeps its winding)
        m = Matrix(((1, 0, 0, 0), (0, 0, -1, y1), (0, 1, 0, 0), (0, 0, 0, 1)))
        self.prism(swatch, profile_xz, y1 - y0, m, **kw)

    def prism_z(self, swatch: str, outline_xy, z0: float, z1: float, **kw) -> None:
        self.prism(swatch, outline_xy, z1 - z0, Matrix.Translation((0, 0, z0)), **kw)

    def lathe(self, swatch: str, profile, loc=(0, 0, 0), verts: int = 12, rot=(0, 0, 0), **kw) -> None:
        """Revolve a profile [(radius, z), ...] (bottom to top) about local Z."""
        v, faces = [], []
        for (r, z) in profile:
            for i in range(verts):
                a = 2 * math.pi * i / verts
                v.append((r * math.cos(a), r * math.sin(a), z))
        for k in range(len(profile) - 1):
            for i in range(verts):
                j = (i + 1) % verts
                a, b, c, d = k * verts + i, k * verts + j, (k + 1) * verts + j, (k + 1) * verts + i
                if profile[k][0] < 1e-5:
                    faces.append((a, c, d))
                elif profile[k + 1][0] < 1e-5:
                    faces.append((a, b, d))
                else:
                    faces.append((a, b, c, d))
        if profile[0][0] > 1e-5:
            faces.append(tuple(reversed(range(verts))))
        if profile[-1][0] > 1e-5:
            faces.append(tuple(range((len(profile) - 1) * verts, len(profile) * verts)))
        m = Matrix.Translation(Vector(loc)) @ rot_matrix(rot)
        kw.setdefault("smooth", 50.0)
        self.add(swatch, v, faces, m, **kw)

    def bulb(self, swatch: str, r: float, loc, **kw) -> None:
        """A small glowing bulb (a 6 by 3 sphere: 24 triangles)."""
        self.sphere(swatch, r, loc, segs=6, rings=3, mat="Neon", shadow=False, **kw)

    def glass(self, size, loc, rot=(0, 0, 0), swatch: str = "skyblue", transparency: float = GLASS_T, **kw) -> None:
        self.box(swatch, size, loc, rot, mat="Glass", transparency=transparency, shadow=False, **kw)

    def neon(self, swatch: str, size, loc, rot=(0, 0, 0), **kw) -> None:
        self.box(swatch, size, loc, rot, mat="Neon", shadow=False, **kw)

    # -- lettering ---------------------------------------------------------------------------
    def _font(self, name: str):
        f = self._fonts.get(name)
        if f is None:
            path = os.path.join(FONTS, name + ".ttf")
            f = self._fonts[name] = bpy.data.fonts.load(path, check_existing=True)
        return f

    def text(self, swatch: str, s: str, loc, height: float, depth: float = 0.25, font: str = "Oswald-Bold",
             yaw: float = 0.0, tilt: float = 90.0, max_w: float | None = None, spacing: float = 1.0, res: int = 1,
             back: bool = False, lean: float = 0.0, flat: bool = False, **kw) -> float:
        """Raised letters centred on loc, reading left to right for someone facing the wall
        (yaw 0: on a wall that faces -Y). height is the lettering's real height; max_w squeezes
        a long name to fit. tilt 90 stands the text up; 0 lays it flat, reading from above.
        Letters cost triangles (about 45 a letter in Oswald or Bebas, 60 in Alfa Slab, 75 in
        Lobster at res 1; never Special Elite: 500): res 2 only for a hero sign, flat=True
        (fronts only) for lettering painted on a wall. Returns its width."""
        cu = bpy.data.curves.new("T", "FONT")
        cu.body = s
        cu.font = self._font(font)
        cu.size = 1.0
        cu.extrude = 0.5
        cu.resolution_u = res
        cu.space_character = spacing
        cu.shear = lean
        ob = bpy.data.objects.new("T", cu)
        bpy.context.scene.collection.objects.link(ob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), depsgraph=dg)
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.curves.remove(cu)
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        if not xs:
            bm.free()
            return 0.0
        w0, h0 = max(xs) - min(xs), max(ys) - min(ys)
        k = height / h0
        kx = k
        if max_w is not None and w0 * k > max_w:
            kx = max_w / w0
        cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        for v in bm.verts:
            v.co = Vector(((v.co.x - cx) * kx, (v.co.y - cy) * k, (v.co.z) * depth))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(R(yaw), 4, "Z") @ Matrix.Rotation(R(tilt), 4, "X")
        kw.setdefault("smooth", 30.0)
        if flat:
            skip = lambda f: f.normal.z < 0.9  # noqa: E731
        else:
            skip = None if back else (lambda f: f.normal.z < -0.9)
        self.add_bm(swatch, bm, m, skip=skip, **kw)
        return w0 * kx

    # -- walls -------------------------------------------------------------------------------
    def face(self, origin, yaw: float = 0.0) -> "Face":
        return Face(self, origin, yaw)

    def collider(self, size, loc, yaw: float = 0.0, name: str = "Wall") -> None:
        """An invisible box players and shots hit (made in Studio from the sidecar)."""
        p = self.M @ Vector(loc)
        yaw_w = yaw + math.degrees(math.atan2(self.M[1][0], self.M[0][0]))
        sc = self.M.to_scale().x
        self.colliders.append([name, round(p.x, 3), round(p.y, 3), round(p.z, 3),
                               round(size[0] * sc, 3), round(size[1] * sc, 3), round(size[2] * sc, 3), round(yaw_w, 2)])

    def collide_span(self, x0, x1, y0, y1, z0, z1, name: str = "Wall") -> None:
        self.collider((abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), name=name)

    def socket(self, name: str, loc, yaw: float = 0.0) -> None:
        p = self.M @ Vector(loc)
        self.sockets[name] = ((p.x, p.y, p.z), yaw + math.degrees(math.atan2(self.M[1][0], self.M[0][0])))

    def light(self, loc, kind: str = "Point", colour: str = "cream", brightness: float = 1.0, range_: float = 24.0,
              face: str = "Bottom", angle: float = 90.0, shadows: bool = False) -> None:
        """A light for the Studio builder to add (sidecar meta.lights)."""
        p = self.M @ Vector(loc)
        self.lights.append({"p": [round(p.x, 2), round(p.y, 2), round(p.z, 2)], "kind": kind, "colour": colour,
                            "brightness": brightness, "range": range_, "face": face, "angle": angle, "shadows": shadows})

    def role(self, name: str, swatch: str, size, loc, rot=(0, 0, 0), collision: str = "none", mat: str = "SmoothPlastic",
             transparency: float = 0.0, shadow: bool = True) -> None:
        """A box that stays its own MeshPart with a Role (code finds it)."""
        self.box(swatch, size, loc, rot, part=name, role=name, collision=collision, mat=mat, transparency=transparency,
                 shadow=shadow)

    # -- finish ------------------------------------------------------------------------------
    def finish(self) -> list:
        """Make one tagged Blender object per bucket; returns them."""
        out = []
        for (part, swatch, mat, collision, shadow, transparency, role, smooth, tint), b in self.buckets.items():
            if not b.faces:
                continue
            me = bpy.data.meshes.new(part)
            me.from_pydata([tuple(v) for v in b.verts], [], b.faces)
            me.update()
            ob = bpy.data.objects.new(part, me)
            bpy.context.scene.collection.objects.link(ob)
            sf.tag(ob, part, swatch, mat, collision=collision, cast_shadow=shadow, transparency=transparency,
                   smooth_angle=None if smooth < 0 else smooth, role=role, tint=sf.swatch(tint)["hex"] if tint else None)
            out.append(ob)
        return out

    def export_kwargs(self, **extra) -> dict:
        meta = dict(extra.pop("meta", {}))
        if self.colliders:
            meta["colliders"] = self.colliders
        if self.lights:
            meta["lights"] = self.lights
        kw = {"merge": "room", "pivot": (0, 0, 0), "meta": meta}
        if self.sockets:
            kw["sockets"] = self.sockets
        kw.update(extra)
        return kw


class Face:
    """One wall face. u runs along it to the right as seen from outside, n points out of it, z is up.
    yaw 0 faces -Y (the street), 90 faces +X, 180 faces +Y, 270 faces -X."""

    def __init__(self, kit: Kit, origin, yaw: float = 0.0):
        self.k = kit
        self.o = Vector(origin)
        self.yaw = yaw
        a = R(yaw)
        self.U = Vector((math.cos(a), math.sin(a), 0))
        self.N = Vector((math.sin(a), -math.cos(a), 0))

    def p(self, u: float, n: float, z: float) -> Vector:
        return self.o + self.U * u + self.N * n + Vector((0, 0, z))

    def box(self, swatch: str, size, at, tilt: float = 0.0, roll: float = 0.0, **kw) -> None:
        """size (along u, out of the wall, up), centred at (u, n, z). tilt leans its top out of the wall."""
        self.k.box(swatch, size, self.p(*at), rot=(tilt, roll, self.yaw), **kw)

    def on(self, swatch: str, u0: float, u1: float, z0: float, z1: float, depth: float, sink: float = 0.06, n0: float | None = None,
           **kw) -> None:
        """A slab on the wall from u0..u1, z0..z1, standing `depth` proud of it (n0: its inner face).
        Its wall-side face is left out (nobody sees it); pass open_=() to keep it."""
        inner = -sink if n0 is None else n0
        kw.setdefault("open_", ("y+",))
        self.box(swatch, (abs(u1 - u0), depth - inner, abs(z1 - z0)), ((u0 + u1) / 2, (depth + inner) / 2, (z0 + z1) / 2), **kw)

    def glass(self, u0, u1, z0, z1, n: float = 0.1, thick: float = 0.12, swatch: str = "skyblue", transparency: float = GLASS_T) -> None:
        self.k.glass((abs(u1 - u0), thick, abs(z1 - z0)), self.p((u0 + u1) / 2, n, (z0 + z1) / 2), rot=(0, 0, self.yaw),
                     swatch=swatch, transparency=transparency)

    def cyl(self, swatch: str, r: float, depth: float, at, axis: str = "n", **kw) -> None:
        """A cylinder whose axis is u, n (out of the wall) or z."""
        rot = {"z": (0, 0, self.yaw), "n": (90, 0, self.yaw), "u": (0, 90, self.yaw)}[axis]
        self.k.cyl(swatch, r, depth, self.p(*at), rot=rot, **kw)

    def text(self, swatch: str, s: str, u: float, z: float, height: float, n: float = 0.12, depth: float = 0.25, **kw) -> float:
        return self.k.text(swatch, s, self.p(u, n, z), height, depth=depth, yaw=self.yaw, **kw)

    def prism(self, swatch: str, profile_nz, u0: float, u1: float, **kw) -> None:
        """An (n, z) profile (n out of the wall) swept along the wall from u0 to u1."""
        a = self.p(u0, 0, 0)
        # local X -> N, local Y -> Z, local Z -> U
        m = Matrix((
            (self.N.x, 0, self.U.x, a.x),
            (self.N.y, 0, self.U.y, a.y),
            (0, 1, 0, a.z),
            (0, 0, 0, 1)))
        self.k.prism(swatch, profile_nz, u1 - u0, m, **kw)

    def outline(self, swatch: str, pts_uz, n0: float, n1: float, **kw) -> None:
        """A (u, z) outline as seen from outside, extruded from n0 to n1 (out of the wall)."""
        a = self.p(0, n1, 0)
        # local X -> U, local Y -> Z, local Z -> -N
        m = Matrix((
            (self.U.x, 0, -self.N.x, a.x),
            (self.U.y, 0, -self.N.y, a.y),
            (0, 1, 0, a.z),
            (0, 0, 0, 1)))
        self.k.prism(swatch, pts_uz, n1 - n0, m, **kw)

    def sub(self, u: float, n: float = 0.0, z: float = 0.0) -> "Face":
        return Face(self.k, self.p(u, n, z), self.yaw)


# ---------------------------------------------------------------------------------------------
# Review renders: a sunny street look, cameras anywhere
# ---------------------------------------------------------------------------------------------

def _glass_material(hexcolor: str, alpha: float):
    key = f"glass|{hexcolor}|{alpha}"
    if key in sf._MATS:
        return sf._MATS[key]
    m = bpy.data.materials.new("Glass_" + hexcolor.lstrip("#"))
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    r, g, bl = (sf.srgb_to_linear(c) for c in sf.hex_rgb(hexcolor))
    b.inputs["Base Color"].default_value = (r, g, bl, 1)
    b.inputs["Roughness"].default_value = 0.04
    b.inputs["Alpha"].default_value = alpha
    b.inputs["Specular IOR Level"].default_value = 1.0
    sf._MATS[key] = m
    return m


def shots(asset: str, category: str, views, res=(960, 540), samples: int = 24, sun=(55, 35), ground: str | None = "#7A7A78",
          sky: bool = True, ground_size: float = 600.0, sun_strength: float = 3.2, ambient: float = 1.0, name: str | None = None,
          lights: list | None = None) -> str:
    """Render review views of the tagged scene as it exports. views: [(label, cam_xyz, look_xyz, fov_deg)].
    sun = (elevation, azimuth) in degrees (azimuth 0 shines from -Y, the street side). lights: the
    kit's lights (shown as point lamps, for interiors). One strip image: previews/<category>/<asset>[_name].png."""
    from PIL import Image
    objs = sf._tagged_objects()
    built = sf._build_export_meshes(objs, Vector((0, 0, 0)), "room")
    for o in objs:
        o.hide_render = True
    for b in built:
        src = b["src"][0]
        mat = src["sf_material"]
        me = b["obj"].data
        hexc = sf.swatch(src["sf_swatch"])["hex"]
        if mat == "Glass":
            me.materials.clear()
            me.materials.append(_glass_material(hexc, 1.0 - src["sf_transparency"]))
        elif mat == "Neon":
            me.materials.clear()
            me.materials.append(sf._flat_material(hexc, emission=4.0))
        elif src.get("sf_tint") and src["sf_swatch"] == sf.TINT:
            me.materials.clear()
            me.materials.append(sf._flat_material(src["sf_tint"], roughness=0.45))
    sf._setup_render(res[0], samples)
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = res
    nt = sc.world.node_tree
    if sky:
        nt.nodes["Background"].inputs[0].default_value = (0.42, 0.60, 0.92, 1)
        nt.nodes["Background"].inputs[1].default_value = 0.95 * ambient
        nt.nodes["SF_CamBG"].inputs[0].default_value = (0.36, 0.58, 0.92, 1)
        nt.nodes["SF_CamBG"].inputs[1].default_value = 1.0
    else:
        nt.nodes["Background"].inputs[1].default_value = 0.35 * ambient
    made = []
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=ground_size, location=(0, 0, -0.02))
        g = bpy.context.active_object
        g.name = "Floor"
        g.data.materials.append(sf._flat_material(ground, roughness=0.95))
        made.append(g)
    if sun:
        ld = bpy.data.lights.new("Key", "SUN")
        ld.energy = sun_strength
        ld.angle = R(2.5)
        so = bpy.data.objects.new("Key", ld)
        sc.collection.objects.link(so)
        el, az = R(sun[0]), R(sun[1])
        d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
        so.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        made.append(so)
    for i, L in enumerate(lights or []):
        ld = bpy.data.lights.new(f"Fill{i}", "POINT")
        ld.energy = 900 * L.get("brightness", 1.0) * (L.get("range", 24.0) / 24.0) ** 2
        ld.shadow_soft_size = 1.0
        r, g, bl = (sf.srgb_to_linear(c) for c in sf.hex_rgb(sf.swatch(L.get("colour", "cream"))["hex"]))
        ld.color = (r, g, bl)
        lo = bpy.data.objects.new(f"Fill{i}", ld)
        sc.collection.objects.link(lo)
        lo.location = Vector(L["p"])
        made.append(lo)
    out_dir = os.path.join(sf.REPO, "previews", category)
    os.makedirs(out_dir, exist_ok=True)
    paths = []
    for i, (label, cam_at, look, fov) in enumerate(views):
        cd = bpy.data.cameras.new("PreviewCam")
        cd.angle = R(fov)
        cd.clip_start = 0.1
        cd.clip_end = 4000
        cam = bpy.data.objects.new("PreviewCam", cd)
        sc.collection.objects.link(cam)
        cam.location = Vector(cam_at)
        cam.rotation_euler = (Vector(look) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.camera = cam
        p = os.path.join(out_dir, f"_{asset}_{os.getpid()}_{i}.png")
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
        bpy.data.objects.remove(cam, do_unlink=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    for b in built:
        bpy.data.objects.remove(b["obj"], do_unlink=True)
    for o in objs:
        o.hide_render = False
    ims = [Image.open(p).convert("RGB") for p in paths]
    cols = 2 if len(ims) > 1 else 1
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (res[0] * cols, res[1] * rows), (30, 32, 36))
    for i, im in enumerate(ims):
        sheet.paste(im, ((i % cols) * res[0], (i // cols) * res[1]))
    out = os.path.join(out_dir, f"{asset}{'_' + name if name else ''}.png")
    sheet.save(out)
    for p in paths:
        os.remove(p)
    return out


def run(build, asset: str, category: str, views=None, budget: int | None = None, step: str = "Setup", context=(),
        **shot_kw) -> dict:
    """A generator's entry: build(kit) -> render review views -> export when SF_EXPORT=1.
    build returns None or extra export kwargs (meta...). context: other build functions drawn
    around it in the review renders only (the rest of a building). The kits' lights light the
    renders. SF_NORENDER=1 skips the renders; SF_VIEW=a,b renders only those views; SF_FAST=1
    renders them small and rough."""
    sf.reset()
    kit = Kit()
    extra = build(kit) or {}
    objs = kit.finish()
    by_mat: dict = {}
    for (part, swatch, mat, *_rest), b in kit.buckets.items():
        name = "SmoothPlastic" if mat == "SmoothPlastic" else f"{mat} {swatch}"
        by_mat[name] = by_mat.get(name, 0) + sum(len(f) - 2 for f in b.faces)
    print(f"[{asset}] {kit.tris} triangles ({', '.join(f'{n} {t}' for n, t in sorted(by_mat.items(), key=lambda x: -x[1])[:4])}), "
          f"{len(kit.colliders)} colliders, {len(kit.lights)} lights")
    if os.environ.get("SF_NORENDER") != "1":
        v = views or extra.pop("views", None)
        around = []
        lights = list(kit.lights)
        if context and v:
            ctx = Kit()
            for fn in context:
                fn(ctx)
            around = ctx.finish()
            lights += ctx.lights
        if v:
            only = os.environ.get("SF_VIEW")
            if only:
                v = [x for x in v if x[0] in only.split(",")]
            shot_kw.setdefault("lights", lights)
            if os.environ.get("SF_FAST") == "1":          # a quick look while iterating
                r = shot_kw.get("res", (960, 540))
                shot_kw["res"] = (int(r[0] * 0.7), int(r[1] * 0.7))
                shot_kw["samples"] = 10
            print(f"[{asset}] preview: {shots(asset, category, v, **shot_kw)}")
        else:
            print(f"[{asset}] preview: {sf.render_preview(asset, category, merge='room')}")
        for o in around:
            bpy.data.objects.remove(o, do_unlink=True)
    extra.pop("views", None)
    doc = {}
    if os.environ.get("SF_EXPORT") == "1":
        kw = kit.export_kwargs(**extra)
        if budget is not None:
            kw["budget"] = budget
        kw.setdefault("step", step)
        doc = sf.export_asset(asset, category, **kw)
        print(f"[{asset}] exported: {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    return doc


# ---------------------------------------------------------------------------------------------
# Wall dressing shared by the town and the lobby
# ---------------------------------------------------------------------------------------------

def parapet(k: Kit, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, swatch: str, t: float = 0.8) -> None:
    """A roof's low wall on four sides, its corners not doubled (coincident faces flicker)."""
    k.span(swatch, x0, x1, y0, y0 + t, z0, z1)
    k.span(swatch, x0, x1, y1 - t, y1, z0, z1)
    k.span(swatch, x0, x0 + t, y0 + t, y1 - t, z0, z1, open_=("y-", "y+"))
    k.span(swatch, x1 - t, x1, y0 + t, y1 - t, z0, z1, open_=("y-", "y+"))


def ashlar(f: Face, u0: float, u1: float, z0: float, z1: float, row: float = 1.5, stones=("sandstone", "sandstone", "ash", "cream"),
           mortar: str | None = "stone", proud: float = 0.22, gap: float = 0.14, seed: int = 1, min_w: float = 1.6, max_w: float = 3.6) -> None:
    """Coursed stonework: rows of stones of random lengths standing proud of a mortar backing."""
    rng = random.Random(seed)
    if mortar:
        f.on(mortar, u0, u1, z0, z1, 0.06)
    rows = max(1, round((z1 - z0) / row))
    rh = (z1 - z0) / rows
    for r in range(rows):
        u = u0
        za, zb = z0 + r * rh + gap / 2, z0 + (r + 1) * rh - gap / 2
        while u < u1 - 0.01:
            w = rng.uniform(min_w, max_w)
            if u1 - (u + w) < min_w * 0.7:
                w = u1 - u
            f.on(rng.choice(stones), u + gap / 2, u + w - gap / 2, za, zb, proud * rng.uniform(0.75, 1.15), n0=0.04, open_=("y+",))
            u += w


def brick_bands(f: Face, u0: float, u1: float, z0: float, z1: float, swatch: str = "leather", every: float = 3.0, h: float = 0.28,
                proud: float = 0.1) -> None:
    """Brickwork hinted with thin proud courses every few studs (palette-only: no brick texture)."""
    z = z0 + every
    while z < z1 - 0.3:
        f.on(swatch, u0, u1, z, z + h, proud, n0=0.02, open_=("y+",))
        z += every


def quoins(f: Face, u: float, z0: float, z1: float, swatch: str = "sandstone", w: float = 1.6, h: float = 1.3, proud: float = 0.2, side: int = 1) -> None:
    """Corner stones up a wall's edge at u (side +1: they sit to the right of u, -1 to the left)."""
    z = z0
    i = 0
    while z < z1 - h * 0.5:
        ww = w if i % 2 == 0 else w * 0.62
        a, b = (u, u + ww) if side > 0 else (u - ww, u)
        f.on(swatch, a, b, z + 0.06, min(z + h, z1) - 0.06, proud, n0=0.02, open_=("y+",))
        z += h
        i += 1
