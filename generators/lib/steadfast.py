"""
steadfast — the shared Blender library for 100 Years Below (bible Section 19).

Every generator in generators/<Category>/ imports this module:

    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
    import steadfast as sf

It provides:
  * scene reset and soft-bevelled primitive builders (box, cyl, sphere, lathe, tube, ...)
  * tagging: which Roblox MeshPart a Blender object becomes, its palette swatch, Roblox
    material and collision
  * the exporter: one FBX per asset (palette UVs, pivot at the origin) plus a JSON sidecar
    with everything FBX can't carry (materials, collision, roles, sockets, rig joints),
    and the asset's row in manifest.csv
  * previews: two angles, a 1-stud reference cube, rendered with the real palette
  * rigid-part rigs and clips: keys in Roblox axes (JSON) and a KeyframeSequence (.rbxmx)

Conventions (checked by the pipeline test, see BUILD_LOG.md):
  * 1 Blender unit = 1 stud. Z is up in Blender.
  * Model the FRONT of every asset facing Blender -Y (Blender's Front view). It lands facing
    Roblox -Z, which is CFrame.LookVector.
  * Pivot = bottom-centre of the asset's bounds, unless the generator passes pivot= (hinges).
  * Colour only comes from the palette: every face points its UVs at the centre of one
    swatch of palette/palette.png. Never add another texture to a model.
  * Roblox axes: x_r = -x_b, y_r = z_b, z_r = y_b (a proper rotation).

Environment switches for generators (run_main):
  SF_EXPORT=1    export FBX + sidecar and update manifest.csv
  SF_NORENDER=1  skip the preview render
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import os
import re

import bpy  # must come first: importing bpy makes bmesh and mathutils available
import bmesh
from mathutils import Euler, Matrix, Vector

LIB_DIR = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("SF_REPO") or os.path.abspath(os.path.join(LIB_DIR, "..", ".."))

BLENDER_PIN = "5.2.3"
# FBX settings, pinned by the pipeline test of 2026-11-07 (BUILD_LOG.md). Roblox reads one
# raw FBX unit as one stud, and Blender writes centimetres (1 BU = 100), so 0.01 makes
# 1 Blender unit land as exactly 1 stud. Change these only after re-measuring an upload.
FBX_GLOBAL_SCALE = 0.01
FBX_AXIS_FORWARD = "Z"   # Blender +Y -> FBX +Z, so the asset front (Blender -Y) faces Roblox -Z
FBX_AXIS_UP = "Y"

ASSET_NAME = re.compile(r"^[A-Z][A-Za-z0-9]*_[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)?$")
MATERIALS = {"SmoothPlastic", "Plastic", "Metal", "DiamondPlate", "Wood", "WoodPlanks", "Fabric",
             "Glass", "Neon", "Concrete", "Brick", "Slate", "Granite", "Pebble", "Cobblestone",
             "Rock", "Sand", "Ice", "Foil", "Marble", "CorrodedMetal", "ForceField"}
COLLISION = {"none", "query", "queryhull", "box", "hull", "precise"}

# ------------------------------------------------------------------------------------------
# Palette
# ------------------------------------------------------------------------------------------

with open(os.path.join(REPO, "palette", "palette.json")) as _f:
    PALETTE = json.load(_f)
SWATCHES = {s["name"]: s for s in PALETTE["swatches"]}
TINT = "tint"


def swatch(name: str) -> dict:
    if name not in SWATCHES:
        raise KeyError(f"unknown swatch '{name}'. Swatches: {', '.join(SWATCHES)}")
    return SWATCHES[name]


def hex_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))  # type: ignore[return-value]


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ------------------------------------------------------------------------------------------
# Scene
# ------------------------------------------------------------------------------------------

def reset() -> None:
    """Start every generator from an empty scene so scripts are re-runnable."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


_MATS: dict[str, bpy.types.Material] = {}


def _flat_material(hexcolor: str, name: str | None = None, metallic=0.0, roughness=0.6,
                   emission: float = 0.0) -> bpy.types.Material:
    key = f"{hexcolor}|{metallic}|{roughness}|{emission}"
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name or f"M_{hexcolor.lstrip('#')}")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    r, g, b = (srgb_to_linear(c) for c in hex_rgb(hexcolor))
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (r, g, b, 1.0)
    _MATS[key] = m
    return m


def palette_material() -> bpy.types.Material:
    """The one material every exported mesh carries: palette colour, metalness and roughness
    maps sampled with Closest filtering (what SurfaceAppearance shows in Studio)."""
    if "Palette" in _MATS:
        return _MATS["Palette"]
    m = bpy.data.materials.new("Palette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    pdir = os.path.join(REPO, "palette")

    def tex(file: str, non_color: bool):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(pdir, file), check_existing=True)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        n.interpolation = "Closest"
        return n

    col = tex("palette.png", False)
    met = tex("palette_metalness.png", True)
    rou = tex("palette_roughness.png", True)
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(met.outputs["Color"], bsdf.inputs["Metallic"])
    nt.links.new(rou.outputs["Color"], bsdf.inputs["Roughness"])
    _MATS["Palette"] = m
    return m


# ------------------------------------------------------------------------------------------
# Primitive builders: everything gets soft bevels so nothing reads as a default primitive
# ------------------------------------------------------------------------------------------

def _finish(obj, loc, rot, bevel_w: float, segments: int, angle: float = 40.0):
    obj.location = Vector(loc)
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    if bevel_w > 0:
        bevel(obj, bevel_w, segments, angle)
    return obj


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.08, segments=2, name="Box"):
    """Box centred at loc. size = (x, y, z) in studs."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, loc, rot, bevel, segments)


def cyl(radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), verts=16, bevel=0.05, segments=2,
        radius_top=None, name="Cyl"):
    """Cylinder (or frustum with radius_top) along Blender Z, centred at loc."""
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius_top, depth=depth)
    obj = bpy.context.active_object
    obj.name = name
    return _finish(obj, loc, rot, bevel, segments)


def sphere(radius, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), segs=16, rings=10, name="Sphere"):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, loc, rot, 0, 0)


def torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), major_segs=20, minor_segs=8, name="Torus"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=major_segs, minor_segments=minor_segs)
    obj = bpy.context.active_object
    obj.name = name
    return _finish(obj, loc, rot, 0, 0)


def from_bmesh(bm: bmesh.types.BMesh, name: str, loc=(0, 0, 0), rot=(0, 0, 0), bevel_w=0.0, segments=2):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return _finish(obj, loc, rot, bevel_w, segments)


def profile_slab(points2d, thickness, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.04, segments=2, name="Slab"):
    """Extrude a closed 2D outline (Blender XY) upward by `thickness` along Z."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0)) for x, y in points2d]
    face = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    if face.normal.z < 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, thickness))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return from_bmesh(bm, name, loc, rot, bevel, segments)


def lathe(profile, verts=20, loc=(0, 0, 0), rot=(0, 0, 0), name="Lathe"):
    """Revolve a profile [(radius, z), ...] (bottom to top) around Blender Z."""
    bm = bmesh.new()
    rings = []
    for i in range(verts):
        a = 2 * math.pi * i / verts
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for i in range(verts):
        r0, r1 = rings[i], rings[(i + 1) % verts]
        for j in range(len(profile) - 1):
            quad = [r0[j], r1[j], r1[j + 1], r0[j + 1]]
            if len({v.co.to_tuple(5) for v in quad}) >= 3:
                try:
                    bm.faces.new(quad)
                except ValueError:
                    pass
    if profile[0][0] > 1e-4:
        bm.faces.new([rings[i][0] for i in reversed(range(verts))])
    if profile[-1][0] > 1e-4:
        bm.faces.new([rings[i][-1] for i in range(verts)])
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return from_bmesh(bm, name, loc, rot)


def ring(r_in: float, r_out: float, depth: float, loc=(0, 0, 0), rot=(0, 0, 0), verts=24, name="Ring"):
    """Flat annulus (washer) of given radii and thickness, centred at loc."""
    bm = bmesh.new()
    rows = []
    for z in (-depth / 2, depth / 2):
        rows.append([bm.verts.new((r * math.cos(2 * math.pi * i / verts), r * math.sin(2 * math.pi * i / verts), z))
                     for r in (r_in, r_out) for i in range(verts)])
    (bi, bo), (ti, to) = [(row[:verts], row[verts:]) for row in rows]
    for i in range(verts):
        j = (i + 1) % verts
        bm.faces.new([bo[i], bo[j], to[j], to[i]])
        bm.faces.new([bi[j], bi[i], ti[i], ti[j]])
        bm.faces.new([to[i], to[j], ti[j], ti[i]])
        bm.faces.new([bo[j], bo[i], bi[i], bi[j]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return from_bmesh(bm, name, loc, rot)


def tube(points, radii, sides=8, resolution=4, name="Tube"):
    """Smooth tapered tube through `points` (Blender xyz) with a radius per point."""
    cd = bpy.data.curves.new(name, "CURVE")
    cd.dimensions = "3D"
    cd.resolution_u = resolution
    cd.bevel_depth = 1.0
    cd.bevel_resolution = max(0, round(sides / 4) - 1)   # 4 sides: a diamond, 8: round
    cd.use_fill_caps = True
    sp = cd.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p, r in zip(sp.bezier_points, points, radii):
        bp.co = Vector(p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = r
    ob = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def bevel(obj, width=0.03, segments=2, angle=40.0):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.profile = 0.5
    mod.use_clamp_overlap = True
    mod.harden_normals = False
    return obj


def apply_all(obj) -> None:
    """Apply modifiers and transforms (before booleans and joins)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def join(objs, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    return obj


def join_applied(objs, name: str):
    for o in objs:
        apply_all(o)
    return join(objs, name)


def boolean(target, cutter, op="DIFFERENCE", keep_cutter=False):
    """Apply a boolean to target. The cutter is deleted unless keep_cutter."""
    mod = target.modifiers.new("Bool", "BOOLEAN")
    mod.operation = op
    mod.object = cutter
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if not keep_cutter:
        bpy.data.objects.remove(cutter, do_unlink=True)
    return target


def mirror_x(obj, name: str | None = None):
    """Duplicate an object mirrored across Blender X = 0 (left/right pairs)."""
    dup = obj.copy()
    dup.data = obj.data.copy()
    for k in list(obj.keys()):
        dup[k] = obj[k]
    bpy.context.scene.collection.objects.link(dup)
    dup.location.x = -obj.location.x
    dup.scale.x = -obj.scale.x
    dup.rotation_euler.y = -obj.rotation_euler.y
    dup.rotation_euler.z = -obj.rotation_euler.z
    if name:
        dup.name = name
    apply_all(dup)
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(dup.data)
    bm.free()
    return dup


# ------------------------------------------------------------------------------------------
# Tagging
# ------------------------------------------------------------------------------------------

def tag(obj, part: str, swatch_name: str, mat: str = "SmoothPlastic", *, collision: str = "none",
        cast_shadow: bool = True, transparency: float = 0.0, smooth_angle: float | None = 35.0,
        role: str | None = None, tint: str | None = None):
    """Mark a Blender object as (part of) a Roblox MeshPart.

    part          MeshPart name (PascalCase). Objects with the same material, collision,
                  shadow, transparency, bone and no role are merged into one MeshPart on
                  export; the first one's name wins.
    swatch_name   palette swatch for all its faces (paint() overrides chosen faces).
    mat           Roblox Enum.Material. Use SmoothPlastic unless the part must glow (Neon)
                  or be see-through (Glass): roughness and metalness come from the palette.
    collision     "none" (decoration: no collision, no queries) | "query" (no collision,
                  but raycasts hit it: rig body parts, so guns and taps can find them) |
                  "queryhull" (the same with a Hull shape for raycasts: a boss, whose
                  weak point must not hide inside its neighbours' boxes) |
                  "box" | "hull" | "precise" (CanCollide with that CollisionFidelity).
    smooth_angle  edges sharper than this stay hard; None = fully faceted.
    role          runtime role so code can find the part (keeps it a separate MeshPart).
    tint          preview colour for faces on the "tint" swatch (their real colour is set in
                  game through MeshPart.Color).
    """
    swatch(swatch_name)
    if mat not in MATERIALS:
        raise ValueError(f"{part}: material {mat} not allowed")
    if collision not in COLLISION:
        raise ValueError(f"{part}: collision must be one of {sorted(COLLISION)}")
    obj["sf_part"] = part
    obj["sf_swatch"] = swatch_name
    obj["sf_material"] = mat
    obj["sf_collision"] = collision
    obj["sf_cast_shadow"] = bool(cast_shadow)
    obj["sf_transparency"] = float(transparency)
    obj["sf_smooth_angle"] = -1.0 if smooth_angle is None else float(smooth_angle)
    if role:
        obj["sf_role"] = role
    if tint:
        obj["sf_tint"] = tint.upper()
    if not obj.name.startswith(part):
        obj.name = part
    return obj


def paint(obj, swatch_name: str, where) -> int:
    """Give chosen faces of a tagged object another swatch.

    where(center, normal) -> bool, both in world space, evaluated on the object's base mesh
    (before modifiers; bevel faces inherit from the face they grew from). Returns the
    number of faces painted.
    """
    idx = swatch(swatch_name)["index"]
    me = obj.data
    attr = me.attributes.get("sf_face") or me.attributes.new("sf_face", "INT", "FACE")
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    n = 0
    for poly in me.polygons:
        c = mw @ poly.center
        nrm = (nm @ poly.normal).normalized()
        if where(c, nrm):
            attr.data[poly.index].value = idx + 1
            n += 1
    obj["sf_painted"] = True
    return n


def _tagged_objects() -> list:
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and "sf_part" in o]


# ------------------------------------------------------------------------------------------
# Export
# ------------------------------------------------------------------------------------------

M_B2R = Matrix(((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, 1.0, 0.0)))


def to_roblox(v) -> tuple[float, float, float]:
    """Blender (x, y, z) -> Roblox (x, y, z)."""
    return (-v[0], v[2], v[1])


def _r3(x: float) -> float:
    v = round(x, 3)
    return 0.0 if v == 0 else v


def bbox_world(objs) -> tuple[Vector, Vector]:
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(dg)
        for c in ev.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def _set_sharp_by_angle(bm: bmesh.types.BMesh, angle_deg: float) -> None:
    if angle_deg < 0:
        for f in bm.faces:
            f.smooth = False
        return
    lim = math.radians(angle_deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if e.is_manifold and e.calc_face_angle(0.0) > lim:
            e.smooth = False


def _evaluated_bmesh(obj) -> bmesh.types.BMesh:
    """World-space bmesh of an object with modifiers applied, its own smoothing rule
    applied, and an int face layer 'sw' = palette index of every face."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    me.transform(obj.matrix_world)
    if obj.matrix_world.determinant() < 0:
        me.flip_normals()
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    base = swatch(obj["sf_swatch"])["index"]
    painted = bm.faces.layers.int.get("sf_face") if obj.get("sf_painted") else None
    sw = bm.faces.layers.int.new("sw")
    for f in bm.faces:
        v = f[painted] if painted is not None else 0
        f[sw] = (v - 1) if v > 0 else base
    _set_sharp_by_angle(bm, obj.get("sf_smooth_angle", 35.0))
    return bm


# Neon and Glass MeshParts show one colour each in Studio (AssetSetup gives them their first
# swatch). With this on (generators/Town/townkit.py), parts of those materials are grouped per
# swatch as well, so a sign's orange and teal tubes stay two MeshParts: DecorNeonSignal,
# DecorNeonTeal. Off by default: assets exported before it keep their part names.
SPLIT_UNTEXTURED = False
_UNTEXTURED = ("Neon", "Glass", "ForceField")
# Roblox refuses a mesh much over 20,000 triangles. With a cap set (townkit: 12,000), a merged
# decoration group over it is cut into pieces along its longer side: Decor, Decor2, Decor3...
DECOR_CAP: int | None = None


def _group_key(o) -> tuple:
    if o.get("sf_role"):
        return ("__role__", o["sf_part"])
    key = (o["sf_material"], round(o["sf_transparency"], 3), o["sf_collision"],
           o["sf_cast_shadow"], o.get("sf_bone"), o.get("sf_tint"))
    if SPLIT_UNTEXTURED and o["sf_material"] in _UNTEXTURED:
        key += (o["sf_swatch"],)
    return key


def _build_export_meshes(objs, pv: Vector, merge: bool) -> list[dict]:
    """Merge tagged objects into export groups. Each group becomes one temporary mesh
    object named after its MeshPart, in world space with the pivot moved to the origin,
    UVs on its swatch centres and a single 'Palette' material."""
    # Source objects step aside so each export mesh can carry its exact MeshPart name
    # (Blender would otherwise call it "Crate.025", and that name lands in Studio).
    for i, o in enumerate(objs):
        if not o.name.startswith("_src_"):
            o.name = f"_src_{i:03d}_{o['sf_part']}"
    groups: dict[tuple, list] = {}
    order: list[tuple] = []
    for o in objs:
        if merge == "part":       # rooms and kits: one MeshPart per named piece of furniture
            k = (o["sf_part"],) + _group_key(o)
        elif merge == "room":     # as "part", but every non-colliding decoration shares a MeshPart
            if o["sf_collision"] == "none" and not o.get("sf_role"):
                k = ("__decor__",) + _group_key(o)
            else:
                k = (o["sf_part"],) + _group_key(o)
        elif merge:
            k = _group_key(o)
        else:
            k = ("__solo__", o.name)
        if k not in groups:
            groups[k] = []
            order.append(k)
        groups[k].append(o)
    out = []
    taken: set[str] = set()
    pal = palette_material()
    for k in order:
        grp = groups[k]
        bm = bmesh.new()
        sw_out = bm.faces.layers.int.new("sw")
        cut_layer = bm.faces.layers.int.new("cut")
        for o in grp:
            src = _evaluated_bmesh(o)
            sw_in = src.faces.layers.int.get("sw")
            vmap = [bm.verts.new(v.co) for v in src.verts]
            for f in src.faces:
                try:
                    nf = bm.faces.new([vmap[v.index] for v in f.verts])
                except ValueError:
                    continue
                nf.smooth = f.smooth
                nf[sw_out] = f[sw_in]
            for e in src.edges:
                if not e.smooth:
                    ne = bm.edges.get([vmap[e.verts[0].index], vmap[e.verts[1].index]])
                    if ne is not None:
                        ne.smooth = False
            src.free()
        bmesh.ops.translate(bm, verts=bm.verts[:], vec=-pv)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            s = PALETTE["swatches"][f[sw_out]]
            for loop in f.loops:
                loop[uv].uv = s["uv"]
        # A bone's main group (plain material, no role) takes the bone's name, so it becomes
        # the rig part itself; glowing or see-through extras keep their own part names and
        # are welded to that bone part in Studio.
        first = grp[0]
        main = (first.get("sf_bone") and not first.get("sf_role")
                and first["sf_material"] not in ("Neon", "Glass", "ForceField")
                and first["sf_transparency"] == 0)
        base = first["sf_bone"] if main else first["sf_part"]
        if k[0] == "__decor__":   # merged decoration: Decor, DecorNeon, DecorGlass...
            base = "Decor" + ("" if first["sf_material"] == "SmoothPlastic" else first["sf_material"])
            if SPLIT_UNTEXTURED and first["sf_material"] in _UNTEXTURED:
                base += first["sf_swatch"].capitalize()
        # A merged decoration group over the cap is cut into pieces along its longer side.
        pieces = [bm]
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        if DECOR_CAP and k[0] == "__decor__" and tris > DECOR_CAP:
            n = -(-tris // DECOR_CAP)
            xs = [v.co.x for v in bm.verts]
            ys = [v.co.y for v in bm.verts]
            axis = 0 if (max(xs) - min(xs)) >= (max(ys) - min(ys)) else 1
            ordered = sorted(bm.faces, key=lambda f: f.calc_center_median()[axis])
            run = 0
            for f in ordered:
                f[cut_layer] = min(n - 1, run * n // tris)
                run += len(f.verts) - 2
            pieces = []
            for c in range(n):
                piece = bm.copy()
                layer = piece.faces.layers.int.get("cut")
                bmesh.ops.delete(piece, geom=[f for f in piece.faces if f[layer] != c], context="FACES")
                loose = [v for v in piece.verts if not v.link_faces]
                if loose:
                    bmesh.ops.delete(piece, geom=loose, context="VERTS")
                pieces.append(piece)
            bm.free()
        for c, piece in enumerate(pieces):
            name = base if c == 0 else f"{base}{c + 1}"
            while name in taken:
                name += "_"
            taken.add(name)
            layer = piece.faces.layers.int.get("sw")
            used = {PALETTE["swatches"][f[layer]]["name"] for f in piece.faces}
            me = bpy.data.meshes.new(name)
            piece.to_mesh(me)
            piece.free()
            me.materials.append(pal)
            tmp = bpy.data.objects.new(name, me)
            bpy.context.scene.collection.objects.link(tmp)
            assert tmp.name == name, f"export mesh got renamed to {tmp.name}"
            tmp["sf_export_tmp"] = True
            out.append({"obj": tmp, "src": grp, "swatches": sorted(used)})
    return out


def _tri_count_mesh(me) -> int:
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def tri_count(objs=None) -> int:
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in objs or _tagged_objects():
        me = o.evaluated_get(dg).to_mesh()
        total += _tri_count_mesh(me)
        o.evaluated_get(dg).to_mesh_clear()
    return total


def _export_fbx(temps: list, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for t in temps:
        t.select_set(True)
    bpy.context.view_layer.objects.active = temps[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE", global_scale=FBX_GLOBAL_SCALE,
        axis_forward=FBX_AXIS_FORWARD, axis_up=FBX_AXIS_UP, bake_space_transform=True,
        use_mesh_modifiers=True, mesh_smooth_type="FACE", use_triangles=True,
        add_leaf_bones=False, bake_anim=False, path_mode="STRIP", embed_textures=False)


def export_asset(asset: str, category: str, *, pivot=None, sockets: dict | None = None,
                 meta: dict | None = None, rig=None, rig_meta: dict | None = None,
                 merge: bool = True, budget: int | None = None, step: str = "") -> dict:
    """Export every tagged object in the scene as one Roblox asset.

    asset     Category_Name[_Variant], e.g. "Prop_SupplyCrate". Studio Model name too.
    category  folder under exports/ and previews/; ServerStorage.Assets.<category> in Studio.
    pivot     Blender-space point used as the asset pivot. Default: bottom-centre of bounds.
    sockets   named gameplay points {name: (x, y, z)} or {name: ((x, y, z), yaw_deg)} in
              Blender world space. Studio stores each as a CFrame attribute "Socket_<name>".
    rig       armature for rigid-part rigs: parts export in the rest pose, and the sidecar
              gets the joints so Studio can build the Motor6Ds.
    merge     True: merge parts that share settings into one MeshPart (fewest parts; props,
              weapons, rigs). "room": like "part" for anything with collision, but all
              non-colliding decoration with the same settings becomes one MeshPart ("Decor",
              "DecorNeon"...): fewer draw calls for kits and rooms. "part": merge only pieces with the same part name, so each named
              piece of furniture keeps its own collision box (rooms, kits). False: no merging.
    budget    triangle budget from the bible (Section 19); exceeding it is an error.
    """
    if not ASSET_NAME.match(asset):
        raise ValueError(f"asset name '{asset}' must be Category_Name or Category_Name_Variant")
    if rig is not None:
        rig.data.pose_position = "REST"
        bpy.context.view_layer.update()
    objs = _tagged_objects()
    assert objs, f"{asset}: no tagged objects"
    lo, hi = bbox_world(objs)
    pv = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z)) if pivot is None else Vector(pivot)
    bottom_centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))

    built = _build_export_meshes(objs, pv, merge)
    parts = []
    total = 0
    swatches_used: set[str] = set()
    for b in built:
        t, src = b["obj"], b["src"][0]
        me = t.data
        tris = _tri_count_mesh(me)
        total += tris
        swatches_used.update(b["swatches"])
        xs = [to_roblox(v.co) for v in me.vertices]
        mn = [min(p[i] for p in xs) for i in range(3)]
        mx = [max(p[i] for p in xs) for i in range(3)]
        parts.append({
            "name": t.name,
            "material": src["sf_material"],
            "transparency": src["sf_transparency"],
            "collision": src["sf_collision"],
            "castShadow": src["sf_cast_shadow"],
            "role": src.get("sf_role"),
            "bone": src.get("sf_bone"),
            "tint": src.get("sf_tint"),
            "swatches": b["swatches"],
            "offset": [_r3((mn[i] + mx[i]) / 2) for i in range(3)],
            "size": [_r3(mx[i] - mn[i]) for i in range(3)],
            "tris": tris,
        })
    if budget is not None and total > budget:
        for b in built:
            bpy.data.objects.remove(b["obj"], do_unlink=True)
        raise AssertionError(f"{asset}: {total} triangles is over its budget of {budget}")

    rlo, rhi = to_roblox(lo - pv), to_roblox(hi - pv)
    size = [_r3(abs(rhi[i] - rlo[i])) for i in range(3)]
    fdir = os.path.join(REPO, "exports", category)
    os.makedirs(fdir, exist_ok=True)
    fbx_path = os.path.join(fdir, f"{asset}.fbx")
    _export_fbx([b["obj"] for b in built], fbx_path)

    doc = {
        "asset": asset,
        "category": category,
        "format": 1,
        "size": size,
        "tris": total,
        # pivot relative to the bottom-centre of the bounds, Roblox axes (0,0,0 = default)
        "pivot": [_r3(c) for c in to_roblox(pv - bottom_centre)],
        "parts": parts,
        "meta": meta or {},
        "export": {"blender": bpy.app.version_string, "fbx_scale": FBX_GLOBAL_SCALE,
                   "forward": FBX_AXIS_FORWARD, "up": FBX_AXIS_UP},
    }
    if sockets:
        out = {}
        for sname, spec in sockets.items():
            if len(spec) == 2 and not isinstance(spec[0], (int, float)):
                loc, yaw = spec
            else:
                loc, yaw = spec, 0.0
            out[sname] = {"p": [_r3(c) for c in to_roblox(Vector(loc) - pv)], "yaw": _r3(float(yaw))}
        doc["sockets"] = dict(sorted(out.items()))
    if rig is not None:
        doc["rig"] = _rig_info(rig, pv, rig_meta or {})
        rig.data.pose_position = "POSE"
        bpy.context.view_layer.update()
    with open(fbx_path, "rb") as f:
        doc["fbx_sha1"] = hashlib.sha1(f.read()).hexdigest()[:16]
    with open(os.path.join(fdir, f"{asset}.json"), "w") as f:
        json.dump(doc, f, indent=1)

    manifest_upsert(asset, category=category, kind="model", step=step or None,
                    size_studs="x".join(f"{s:g}" for s in size), tris=total,
                    tri_budget=budget if budget is not None else None,
                    swatches=";".join(sorted(swatches_used)), status="exported")
    for b in built:
        bpy.data.objects.remove(b["obj"], do_unlink=True)
    return doc


# ------------------------------------------------------------------------------------------
# Manifest (manifest.csv: one row per asset, bible Section 19)
# ------------------------------------------------------------------------------------------

MANIFEST_FIELDS = ["name", "category", "kind", "step", "size_studs", "tri_budget", "tris",
                   "swatches", "status", "asset_id", "notes"]


def manifest_read() -> list[dict]:
    path = os.path.join(REPO, "manifest.csv")
    if not os.path.exists(path):
        return []
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def manifest_upsert(name: str, **fields) -> dict:
    """Insert or update one manifest row. Fields given as None are left unchanged."""
    rows = manifest_read()
    row = next((r for r in rows if r["name"] == name), None)
    if row is None:
        row = {k: "" for k in MANIFEST_FIELDS}
        row["name"] = name
        rows.append(row)
    for k, v in fields.items():
        if k not in MANIFEST_FIELDS:
            raise KeyError(k)
        if v is not None:
            row[k] = str(v)
    with open(os.path.join(REPO, "manifest.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=MANIFEST_FIELDS, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    return row


# ------------------------------------------------------------------------------------------
# Previews
# ------------------------------------------------------------------------------------------

def _setup_render(res=512, samples=24, transparent=False):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = transparent
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.use_nodes = True
    nt = sc.world.node_tree
    bg = nt.nodes.get("Background")
    bg.inputs[0].default_value = (0.30, 0.31, 0.34, 1)
    bg.inputs[1].default_value = 0.9
    # Camera rays that miss everything see the floor colour, so wide room shots show no
    # horizon; every other ray still gets the grey ambient light.
    if "SF_CamBG" not in nt.nodes:
        cam_bg = nt.nodes.new("ShaderNodeBackground")
        cam_bg.name = "SF_CamBG"
        lp = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMixShader")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
        nt.links.new(bg.outputs[0], mix.inputs[1])
        nt.links.new(cam_bg.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
    nt.nodes["SF_CamBG"].inputs[0].default_value = (0.042, 0.047, 0.054, 1)
    nt.nodes["SF_CamBG"].inputs[1].default_value = 1.0


def _light(name, kind, loc, energy, size=2.0, target=(0, 0, 0)):
    ld = bpy.data.lights.new(name, type=kind)
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()
    return ob


def _camera_fit(lo: Vector, hi: Vector, yaw_deg: float, pitch_deg: float, fov_deg=30.0, margin=1.15):
    ctr = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.05)
    dist = radius * margin / math.sin(math.radians(fov_deg) / 2)
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    off = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))) * dist
    cd = bpy.data.cameras.new("PreviewCam")
    cd.angle = math.radians(fov_deg)
    cd.clip_start = 0.01
    cd.clip_end = dist * 10
    cam = bpy.data.objects.new("PreviewCam", cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = ctr + off
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam, ctr, dist


def _clear_preview_rig():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(("PreviewCam", "Key", "Fill", "Rim", "RefCube", "Floor")) or o.get("sf_export_tmp"):
            bpy.data.objects.remove(o, do_unlink=True)


def render_preview(asset: str, category: str, res=512, samples=24, merge=True,
                   views=None, out_name: str | None = None) -> str:
    """Preview of exactly what exports, one panel per view: by default (1) front 3/4 view,
    (2) rear 3/4 view with a 1-stud reference cube. Built from the export meshes in the
    current pose, so palette UVs (and a rig's pose) are what you see. views = [(yaw, pitch,
    with_ref_cube), ...]; out_name overrides the file name (e.g. "<asset>_walk")."""
    from PIL import Image
    views = views or ((-35, 26, False), (150, 22, True))
    out_dir = os.path.join(REPO, "previews", category)
    os.makedirs(out_dir, exist_ok=True)
    objs = _tagged_objects()
    lo, hi = bbox_world(objs)
    built = _build_export_meshes(objs, Vector((0, 0, 0)), merge)
    for o in objs:
        o.hide_render = True
    # tint faces show their preview colour
    for b in built:
        tint = b["src"][0].get("sf_tint")
        if tint:
            me = b["obj"].data
            me.materials.append(_flat_material(tint, roughness=0.6))
            ti = swatch(TINT)["uv"]
            uvl = me.uv_layers.active.data
            for poly in me.polygons:
                u = uvl[poly.loop_start].uv
                if abs(u[0] - ti[0]) < 1e-4 and abs(u[1] - ti[1]) < 1e-4:
                    poly.material_index = 1
    span = max(hi.x - lo.x, hi.y - lo.y, 0.5)
    bpy.ops.mesh.primitive_plane_add(size=max(span * 8, 8), location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - 0.001))
    floor = bpy.context.active_object
    floor.name = "Floor"
    floor.data.materials.append(_flat_material("#3A3D42", roughness=0.9))
    _setup_render(res, samples)
    paths = []
    for i, (yaw, pitch, with_ref) in enumerate(views):
        for o in list(bpy.context.scene.objects):
            if o.name.startswith(("PreviewCam", "Key", "Fill", "Rim", "RefCube")):
                bpy.data.objects.remove(o, do_unlink=True)
        fit = [b["obj"] for b in built]
        if with_ref:
            ref = box((1, 1, 1), loc=(lo.x - 0.7, (lo.y + hi.y) / 2, lo.z + 0.5), bevel=0.0, name="RefCube")
            ref.data.materials.append(_flat_material("#9A9AA6"))
            fit.append(ref)
        flo, fhi = bbox_world(fit)
        cam, ctr, dist = _camera_fit(flo, fhi, yaw, pitch)
        k = math.radians(yaw)
        _light("Key", "AREA", ctr + Vector((math.sin(k - 0.8), -math.cos(k - 0.8), 0.9)) * dist, 60 * dist ** 2 / 9, size=dist * 0.6, target=ctr)
        _light("Fill", "AREA", ctr + Vector((math.sin(k + 1.2), -math.cos(k + 1.2), 0.3)) * dist, 20 * dist ** 2 / 9, size=dist * 0.8, target=ctr)
        _light("Rim", "AREA", ctr + Vector((-math.sin(k), math.cos(k), 0.8)) * dist, 35 * dist ** 2 / 9, size=dist * 0.4, target=ctr)
        p = os.path.join(out_dir, f"{asset}_{i}.png")
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    _clear_preview_rig()
    for o in objs:
        o.hide_render = False
    ims = [Image.open(p).convert("RGB") for p in paths]
    combo = Image.new("RGB", (res * len(ims), res))
    for i, im in enumerate(ims):
        combo.paste(im, (i * res, 0))
    out = os.path.join(out_dir, f"{out_name or asset}.png")
    combo.save(out)
    for p in paths:
        os.remove(p)
    return out


# ------------------------------------------------------------------------------------------
# Rigid-part rigs (segmented residents, monsters, bosses)
# ------------------------------------------------------------------------------------------

def make_armature(name: str, bones: list[tuple]):
    """Create an armature. bones = [(name, parent_or_None, head_xyz, tail_xyz), ...].
    Bone names are Roblox part names (the Motor6D's Part1)."""
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    for bname, parent, head, tail in bones:
        b = eb.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.roll = 0.0
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def bind(obj, arm, bone: str):
    """Rigidly attach a tagged part to a bone (no skinning), keeping its world transform."""
    obj["sf_bone"] = bone
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    bpy.context.view_layer.update()
    obj.matrix_world = mw
    return obj


def _rig_info(arm, pv: Vector, meta: dict) -> dict:
    """Joints for Studio, Roblox axes relative to the pivot. meta may carry:
    joint_names {bone: Motor6D name} (default "<bone>Joint"), root (root part name, default
    "HumanoidRootPart"), hrp_size [x, y, z] and hrp_center (Blender xyz) for the root part,
    hip_height, rig_type ("R15" or "Custom")."""
    names = meta.get("joint_names", {})
    bones = []
    for b in arm.data.bones:  # parents come before children
        head_w = arm.matrix_world @ b.head_local
        bones.append({"name": b.name, "parent": b.parent.name if b.parent else None,
                      "jointName": names.get(b.name, f"{b.name}Joint"),
                      "joint": [_r3(c) for c in to_roblox(head_w - pv)]})
    info = {"bones": bones, "root": meta.get("root", "HumanoidRootPart"),
            "rigType": meta.get("rig_type", "Custom")}
    if "hrp_size" in meta:
        info["hrpSize"] = [_r3(v) for v in meta["hrp_size"]]
        info["hrpCenter"] = [_r3(c) for c in to_roblox(Vector(meta["hrp_center"]) - pv)]
    if "hip_height" in meta:
        info["hipHeight"] = _r3(meta["hip_height"])
    return info


def make_rig(name: str, joints: list[tuple]):
    """Armature whose bones all point straight up from their joint, roll 0.

    joints = [(bone, parent_or_None, (x, y, z) joint in Blender space), ...]. With every bone
    upright, a bone's local axes are: X = world X (character's left), Y = up, Z = forward
    (world -Y). So for limbs hanging down: forward swing = negative X rotation, knee bend =
    positive X, left-arm raise outward = positive Z (right arm: negative Z), twist = Y.
    """
    return make_armature(name, [(b, p, h, (h[0], h[1], h[2] + 0.3)) for b, p, h in joints])


R15_JOINTS = {  # joint name -> (part1/bone, parent bone)
    "Root": ("LowerTorso", None), "Waist": ("UpperTorso", "LowerTorso"), "Neck": ("Head", "UpperTorso"),
    "LeftShoulder": ("LeftUpperArm", "UpperTorso"), "LeftElbow": ("LeftLowerArm", "LeftUpperArm"),
    "LeftWrist": ("LeftHand", "LeftLowerArm"), "RightShoulder": ("RightUpperArm", "UpperTorso"),
    "RightElbow": ("RightLowerArm", "RightUpperArm"), "RightWrist": ("RightHand", "RightLowerArm"),
    "LeftHip": ("LeftUpperLeg", "LowerTorso"), "LeftKnee": ("LeftLowerLeg", "LeftUpperLeg"),
    "LeftAnkle": ("LeftFoot", "LeftLowerLeg"), "RightHip": ("RightUpperLeg", "LowerTorso"),
    "RightKnee": ("RightLowerLeg", "RightUpperLeg"), "RightAnkle": ("RightFoot", "RightLowerLeg"),
}


def r15_rig(name: str = "R15"):
    """The standard R15 skeleton measured in Studio (rigs/R15.json), in Blender space with
    the ground at z = 0. Returns (armature, rig_meta for export_asset)."""
    with open(os.path.join(REPO, "rigs", "R15.json")) as f:
        r15 = json.load(f)
    hip = r15["hipHeight"]
    ground = -(hip + r15["hrp"]["size"][1] / 2)          # y of the ground, relative to the HRP centre

    def to_b(p):                                         # Roblox (rel. HRP) -> Blender (ground z = 0)
        return (-p[0], p[2], p[1] - ground)

    joints = [(bone, parent, to_b(r15["joints"][jn]["pos"])) for jn, (bone, parent) in R15_JOINTS.items()]
    arm = make_rig(name, joints)
    meta = {"rig_type": "R15", "root": "HumanoidRootPart", "hip_height": hip,
            "joint_names": {bone: jn for jn, (bone, _p) in R15_JOINTS.items()},
            "hrp_size": r15["hrp"]["size"], "hrp_center": (0.0, 0.0, -ground)}
    return arm, meta


_EASE_STYLE = {"LINEAR": 0, "CONSTANT": 1, "ELASTIC": 2, "CUBIC": 3, "BOUNCE": 4, "BEZIER": 5,
               "SINE": 5, "QUAD": 5, "QUART": 5, "QUINT": 5, "EXPO": 5, "CIRC": 5, "BACK": 5}
_EASE_DIR = {"EASE_IN": 0, "EASE_OUT": 1, "EASE_IN_OUT": 2, "AUTO": 2}


def key(arm, bone: str, frame: int, rot=(0, 0, 0), loc=None, ease="SINE", direction="EASE_IN_OUT"):
    """Key one bone at a frame. rot = Euler degrees (XYZ) in the bone's local rest frame,
    loc = local offset in studs (bone frame) or None. ease applies to the segment that
    starts at this key."""
    pb = arm.pose.bones[bone]
    pb.rotation_quaternion = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_quaternion()
    pb.keyframe_insert("rotation_quaternion", frame=frame)
    if loc is not None:
        pb.location = Vector(loc)
        pb.keyframe_insert("location", frame=frame)
    for fc in _action_fcurves(arm.animation_data.action):
        if fc.data_path.startswith(f'pose.bones["{bone}"]'):
            for kp in fc.keyframe_points:
                if int(round(kp.co.x)) == frame:
                    kp.interpolation = ease
                    kp.easing = direction


def _action_fcurves(act):
    """F-curves of an action (layered actions in Blender 4.4+ and the legacy API)."""
    if hasattr(act, "fcurves") and len(getattr(act, "fcurves", [])) > 0:
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                out.extend(bag.fcurves)
    return out


def new_action(arm, name: str, start: int, end: int, loop: bool = True, fps: int = 30,
               priority: str = "Action"):
    act = bpy.data.actions.new(name)
    act["sf_loop"], act["sf_start"], act["sf_end"], act["sf_fps"] = loop, start, end, fps
    act["sf_priority"] = priority
    act.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and arm.animation_data.action_slot is None:
        try:
            arm.animation_data.action_slot = act.slots.new(id_type="OBJECT", name=arm.name)
        except Exception:
            pass
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return act


def _euler_for_roblox(R) -> tuple[float, float, float]:
    """(rx, ry, rz) so that CFrame.Angles(rx, ry, rz) == R (R = Rx * Ry * Rz)."""
    e = R.to_euler("ZYX")
    return (e.x, e.y, e.z)


def export_clips(arm, rig_name: str, actions: list, root: str | None = None,
                 markers: dict | None = None) -> list[str]:
    """Write each action as animations/<rig>/<clip>.json (keys in Roblox axes, relative to
    rest) and animations/<rig>/<clip>.rbxmx (KeyframeSequence for the Assets API).

    root     name of the root part (e.g. "HumanoidRootPart") when it is not a bone itself;
             it becomes the outer Pose that every bone hangs under.
    markers  {clip name: {marker name: seconds}}, e.g. {"Attack": {"Hit": 0.667}}: written as
             KeyframeMarkers (GetMarkerReachedSignal) and kept in the JSON for Config.
    """
    markers = markers or {}
    scene = bpy.context.scene
    bones = [b.name for b in arm.data.bones]
    parent = {b.name: (b.parent.name if b.parent else root) for b in arm.data.bones}
    out_dir = os.path.join(REPO, "animations", rig_name)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for act in actions:
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
            arm.animation_data.action_slot = act.slots[0]
        fps = act.get("sf_fps", 30)
        start, end = act["sf_start"], act["sf_end"]
        fcs = _action_fcurves(act)
        per_bone: dict[str, list] = {}
        for bname in bones:
            path = f'pose.bones["{bname}"]'
            bfcs = [fc for fc in fcs if fc.data_path.startswith(path)]
            if not bfcs:
                continue
            frames = sorted({int(round(kp.co.x)) for fc in bfcs for kp in fc.keyframe_points})
            ease_at = {}
            for fc in bfcs:
                for kp in fc.keyframe_points:
                    f = int(round(kp.co.x))
                    if fc.data_path.endswith("rotation_quaternion") or f not in ease_at:
                        ease_at[f] = (_EASE_STYLE.get(kp.interpolation, 5), _EASE_DIR.get(kp.easing, 2))
            bone = arm.data.bones[bname]
            B = bone.matrix_local.copy()
            h = B.translation.copy()
            keys = []
            for f in frames:
                scene.frame_set(f)
                L = arm.pose.bones[bname].matrix_basis.copy()
                D = B @ L @ B.inverted()
                T = Matrix.Translation(-h) @ D @ Matrix.Translation(h)
                R = M_B2R @ T.to_3x3() @ M_B2R
                t = M_B2R @ T.translation
                rx, ry, rz = _euler_for_roblox(R)
                style, direction = ease_at.get(f, (5, 2))
                keys.append({"t": _r3((f - start) / fps), "pos": [_r3(t.x), _r3(t.y), _r3(t.z)],
                             "rot": [_r3(rx), _r3(ry), _r3(rz)], "style": style, "dir": direction})
            per_bone[bname] = keys
        clip = {"rig": rig_name, "clip": act.name, "length": _r3((end - start) / fps),
                "loop": bool(act.get("sf_loop", True)), "priority": act.get("sf_priority", "Action"),
                "root": root, "parents": parent, "markers": markers.get(act.name, {}), "keys": per_bone}
        jpath = os.path.join(out_dir, f"{act.name}.json")
        with open(jpath, "w") as f:
            json.dump(clip, f, indent=1)
        xpath = os.path.join(out_dir, f"{act.name}.rbxmx")
        write_keyframe_sequence(xpath, clip)
        manifest_upsert(f"{rig_name}_{act.name}", category=f"Animations/{rig_name}", kind="clip",
                        status="exported")
        written += [jpath, xpath]
    scene.frame_set(0)
    return written


# ------------------------------------------------------------------------------------------
# KeyframeSequence writer (.rbxmx)
# ------------------------------------------------------------------------------------------

_PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4, "Action4": 5, "Core": 1000}


def _cframe_xml(pos, rot) -> str:
    rx, ry, rz = rot
    R = (Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z"))
    vals = [("X", pos[0]), ("Y", pos[1]), ("Z", pos[2])]
    for i in range(3):
        for j in range(3):
            vals.append((f"R{i}{j}", R[i][j]))
    inner = "".join(f"<{k}>{_num(v)}</{k}>" for k, v in vals)
    return f'<CoordinateFrame name="CFrame">{inner}</CoordinateFrame>'


def _num(v: float) -> str:
    r = round(float(v), 6)
    if r == 0:
        return "0"
    return repr(r)


def write_keyframe_sequence(path: str, clip: dict) -> str:
    """Write a clip (the JSON format from export_clips) as a KeyframeSequence .rbxmx.

    Each keyframe holds a Pose for every keyed part at that time; poses nest along the
    rig hierarchy (clip["parents"]), with plain pass-through poses for unkeyed parents.
    """
    from xml.sax.saxutils import escape
    ref = [0]

    def nref() -> str:
        ref[0] += 1
        return f"RBX{ref[0]:08X}"

    parents: dict = clip["parents"]
    times = sorted({k["t"] for keys in clip["keys"].values() for k in keys})

    def chain(b):
        c = []
        while b is not None:
            c.append(b)
            b = parents.get(b)
        return list(reversed(c))

    frames = []
    for t in times:
        keyed = {b: k for b, keys in clip["keys"].items() for k in keys if abs(k["t"] - t) < 1e-6}
        needed: set = set()
        for b in keyed:
            needed.update(chain(b))
        children: dict = {}
        roots = []
        for b in needed:
            p = parents.get(b)
            if p is None or p not in needed:
                roots.append(b)
            else:
                children.setdefault(p, []).append(b)

        def pose_xml(b) -> str:
            k = keyed.get(b)
            pos, rot = (k["pos"], k["rot"]) if k else ((0, 0, 0), (0, 0, 0))
            style, direction = (k["style"], k["dir"]) if k else (0, 0)
            weight = 1 if k else 0
            kids = "".join(pose_xml(c) for c in sorted(children.get(b, [])))
            return (f'<Item class="Pose" referent="{nref()}"><Properties>{_cframe_xml(pos, rot)}'
                    f'<token name="EasingDirection">{direction}</token>'
                    f'<token name="EasingStyle">{style}</token>'
                    f'<string name="Name">{escape(b)}</string>'
                    f'<float name="Weight">{weight}</float></Properties>{kids}</Item>')

        poses = "".join(pose_xml(r) for r in sorted(roots))
        marks = "".join(
            f'<Item class="KeyframeMarker" referent="{nref()}"><Properties>'
            f'<string name="Name">{escape(m)}</string><string name="Value"></string></Properties></Item>'
            for m, mt in clip.get("markers", {}).items() if abs(mt - t) < 1e-3)
        frames.append(f'<Item class="Keyframe" referent="{nref()}"><Properties>'
                      f'<string name="Name">Keyframe</string><float name="Time">{_num(t)}</float>'
                      f'</Properties>{poses}{marks}</Item>')
    for m, mt in clip.get("markers", {}).items():   # a marker between keys gets its own keyframe
        if not any(abs(mt - t) < 1e-3 for t in times):
            frames.append(f'<Item class="Keyframe" referent="{nref()}"><Properties>'
                          f'<string name="Name">{escape(m)}</string><float name="Time">{_num(mt)}</float>'
                          f'</Properties><Item class="KeyframeMarker" referent="{nref()}"><Properties>'
                          f'<string name="Name">{escape(m)}</string><string name="Value"></string>'
                          f'</Properties></Item></Item>')
    # make sure the clip lasts its full length
    if times and clip["length"] - times[-1] > 1e-6:
        frames.append(f'<Item class="Keyframe" referent="{nref()}"><Properties>'
                      f'<string name="Name">End</string><float name="Time">{_num(clip["length"])}</float>'
                      f'</Properties></Item>')
    seq_ref = nref()
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           '<External>null</External><External>nil</External>'
           f'<Item class="KeyframeSequence" referent="{seq_ref}"><Properties>'
           f'<float name="AuthoredHipHeight">{_num(clip.get("hip_height", 2.0))}</float>'
           f'<bool name="Loop">{"true" if clip["loop"] else "false"}</bool>'
           f'<string name="Name">{escape(clip["clip"])}</string>'
           f'<token name="Priority">{_PRIORITY.get(clip.get("priority", "Action"), 2)}</token>'
           f'</Properties>{"".join(frames)}</Item></roblox>')
    with open(path, "w") as f:
        f.write(xml)
    return path


# ------------------------------------------------------------------------------------------
# Generator entry point
# ------------------------------------------------------------------------------------------

def run_main(build, asset: str, category: str, **export_kw):
    """Standard generator entry: build -> preview -> export (SF_EXPORT=1)."""
    reset()
    extra = build() or {}
    print(f"[{asset}] triangles (before merge): {tri_count()}")
    kw = dict(export_kw)
    kw.update(extra.get("export", {}))
    if os.environ.get("SF_NORENDER") != "1":
        prev = render_preview(asset, category, merge=kw.get("merge", True))
        print(f"[{asset}] preview: {prev}")
    if os.environ.get("SF_EXPORT") == "1":
        doc = export_asset(asset, category, **kw)
        print(f"[{asset}] exported: {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    return extra
