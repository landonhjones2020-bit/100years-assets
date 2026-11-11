"""scenelib: a Blender scene put together from the repo's exported models (exports/<Category>/*.fbx
and their sidecars), for the intro cutscene's storyboard and camera (bible Section 4).

It reads back exactly what Studio gets: the FBX's meshes with their palette UVs, glass and Neon
from the sidecar, a car's paint as a flat colour. An asset is imported once; place() makes linked
copies. Blender space is the set's space (cutscene_plan.py).
"""
from __future__ import annotations

import json
import math
import os
import re
import sys

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import steadfast as sf  # noqa: E402

_SOURCES: dict[str, tuple[dict, list]] = {}
_HIDDEN = None


def _hidden():
    """A collection outside the scene for the imported sources."""
    global _HIDDEN
    if _HIDDEN is None or _HIDDEN.name not in bpy.data.collections:
        _HIDDEN = bpy.data.collections.new("Sources")
    return _HIDDEN


def reset():
    sf.reset()
    _SOURCES.clear()
    global _HIDDEN
    _HIDDEN = None


def glass(hexcolor: str, alpha: float):
    key = f"glass|{hexcolor}|{alpha:.2f}"
    if key in sf._MATS:
        return sf._MATS[key]
    m = bpy.data.materials.new("Glass_" + hexcolor.lstrip("#"))
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    r, g, bl = (sf.srgb_to_linear(c) for c in sf.hex_rgb(hexcolor))
    b.inputs["Base Color"].default_value = (r, g, bl, 1)
    b.inputs["Roughness"].default_value = 0.05
    b.inputs["Alpha"].default_value = alpha
    sf._MATS[key] = m
    return m


def load(asset: str, category: str) -> tuple[dict, list]:
    """The asset's sidecar and its meshes [(mesh data, part spec)], in the asset's own frame."""
    if asset in _SOURCES:
        return _SOURCES[asset]
    base = os.path.join(sf.REPO, "exports", category, asset)
    doc = json.load(open(base + ".json"))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=base + ".fbx", global_scale=100.0)
    parts = {p["name"]: p for p in doc["parts"]}
    meshes = []
    for o in [o for o in bpy.data.objects if o not in before]:
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        name = re.sub(r"\.\d{3}$", "", o.name)
        spec = parts.get(name)
        assert spec, f"{asset}: the FBX has {name}, the sidecar doesn't"
        me = o.data
        me.transform(o.matrix_world)
        me.name = f"{asset}:{name}"
        me.materials.clear()
        mat = spec["material"]
        hexc = sf.swatch(spec["swatches"][0])["hex"] if spec["swatches"] and spec["swatches"][0] != "tint" else "#C8C8C8"
        if mat == "Glass":
            me.materials.append(glass(hexc, 1.0 - spec.get("transparency", 0.5)))
        elif mat == "Neon":
            me.materials.append(sf._flat_material(hexc, emission=3.0))
        elif spec.get("role") == "Paint" or spec["swatches"] == ["tint"]:
            me.materials.append(sf._flat_material(spec.get("tint") or "#C8C8C8", roughness=0.4))
        else:
            me.materials.append(sf.palette_material())
        meshes.append((me, spec))
        bpy.data.objects.remove(o, do_unlink=True)
    _SOURCES[asset] = (doc, meshes)
    return _SOURCES[asset]


def place(asset: str, category: str, loc=(0, 0, 0), yaw: float = 0.0, scale: float = 1.0, paint: str | None = None, name: str | None = None,
          collection=None) -> list:
    """A copy of the asset with its pivot at loc, turned yaw degrees about Z. paint: the hex of a
    car's body. Returns its objects (one per MeshPart, named <name>:<part>)."""
    doc, meshes = load(asset, category)
    m = Matrix.Translation(Vector(loc)) @ Euler((0, 0, math.radians(yaw))).to_matrix().to_4x4() @ Matrix.Scale(scale, 4)
    out = []
    col = collection or bpy.context.scene.collection
    for me, spec in meshes:
        o = bpy.data.objects.new(f"{name or asset}:{spec['name']}", me)
        o.matrix_world = m
        o["cs_asset"] = asset
        o["cs_part"] = spec["name"]
        col.objects.link(o)
        if paint and (spec.get("role") == "Paint" or spec["swatches"] == ["tint"]):
            o.material_slots[0].link = "OBJECT"
            o.material_slots[0].material = sf._flat_material(paint, roughness=0.4)
        out.append(o)
    return out


def slab(name: str, x0, x1, y0, y1, z0, z1, swatch: str):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    o.data.materials.append(sf._flat_material(sf.swatch(swatch)["hex"], roughness=0.85))
    return o


# -- light and camera -------------------------------------------------------------------------

def sun(elevation: float, azimuth: float, strength: float = 3.4, colour=(1.0, 0.96, 0.88)):
    """A sun shining FROM the compass direction azimuth (0 = north, 90 = east), elevation degrees up."""
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = strength
    ld.angle = math.radians(2.0)
    ld.color = colour
    o = bpy.data.objects.new("Sun", ld)
    bpy.context.scene.collection.objects.link(o)
    el, az = math.radians(elevation), math.radians(azimuth)
    to_sun = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    o.rotation_euler = to_sun.to_track_quat("Z", "Y").to_euler()
    return o


def sky(colour=(0.36, 0.58, 0.92), ambient: float = 0.95, light=(0.42, 0.60, 0.92)):
    sf._setup_render(512, 16)
    nt = bpy.context.scene.world.node_tree
    nt.nodes["Background"].inputs[0].default_value = (*light, 1)
    nt.nodes["Background"].inputs[1].default_value = ambient
    nt.nodes["SF_CamBG"].inputs[0].default_value = (*colour, 1)
    nt.nodes["SF_CamBG"].inputs[1].default_value = 1.0


def camera(name: str = "Camera"):
    cd = bpy.data.cameras.new(name)
    cd.sensor_fit = "VERTICAL"          # Roblox's FieldOfView is vertical
    cd.clip_start = 0.5
    cd.clip_end = 6000
    cam = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def aim(cam, at, look, fov: float, roll: float = 0.0):
    cam.location = Vector(at)
    q = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y")
    cam.rotation_euler = (q.to_matrix() @ Euler((0, 0, math.radians(roll))).to_matrix()).to_euler()
    cam.data.lens = cam.data.sensor_height / (2 * math.tan(math.radians(fov) / 2))     # fov is vertical, like Roblox's FieldOfView


def render(path: str, res=(960, 540), samples: int = 16):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    return path
