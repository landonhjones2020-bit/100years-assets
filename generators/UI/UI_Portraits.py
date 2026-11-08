"""Class portraits and item icons rendered from the real models (bible Section 18: icons are
rendered from the 3D models, so they always match).

A0 sample: the four classes in the sample Class Shop, one per rarity, each the Resident
model in a class outfit colour; a larger portrait for the detail panel; the Service
Revolver icon for the hotbar and the kit list.

Outputs ui/sprites/Portrait_<Class>.png (340x290, the card window at 2x),
Portrait_<Class>_Large.png (480x408) and Icon_ServiceRevolver.png (256x256).

Run:  python3 generators/UI/UI_Portraits.py
"""
import bpy  # noqa: F401
import json
import math
import os
import sys

from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "Residents"))
sys.path.insert(0, os.path.join(HERE, "..", "Weapons"))
import uikit as K  # noqa: E402

sf = K.sf

# class -> outfit swatch, skin and hair preview colours (the game tints these per resident)
CLASSES = {
    "Security": ("navy", "#8D5A3B", "#1E1A17"),
    "Quartermaster": ("olive", "#E0AC86", "#A0522D"),
    "Warden": ("rust", "#C58F6A", "#9A9890"),
    "MadScientist": ("porcelain", "#F1C7A5", "#E8E4DA"),
}
POSES = {   # bone -> (x, y, z) degrees, upright-bone convention (see steadfast.make_rig)
    "Security": {"LeftUpperArm": (-8, 0, 14), "RightUpperArm": (-6, 0, -14), "LeftLowerArm": (-28, 0, 0),
                 "RightLowerArm": (-22, 0, 0), "Head": (0, -10, 0), "UpperTorso": (0, -6, 0)},
    "Quartermaster": {"LeftUpperArm": (-4, 0, 10), "RightUpperArm": (-30, 0, -8), "RightLowerArm": (-60, 0, 0),
                      "LeftLowerArm": (-14, 0, 0), "Head": (4, -14, 0), "UpperTorso": (0, -4, 0)},
    "Warden": {"LeftUpperArm": (-2, 0, 20), "RightUpperArm": (-2, 0, -20), "LeftLowerArm": (-70, 0, 0),
               "RightLowerArm": (-70, 0, 0), "Head": (-4, -8, 0), "UpperTorso": (0, -8, 0)},
    "MadScientist": {"LeftUpperArm": (-40, 0, 16), "RightUpperArm": (-10, 0, -12), "LeftLowerArm": (-55, 0, 0),
                     "RightLowerArm": (-16, 0, 0), "Head": (8, -18, 6), "UpperTorso": (0, -10, 0)},
}


def _render_setup(w, h, samples=96):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.32, 0.32, 0.34, 1)
    bg.inputs[1].default_value = 1.0
    return sc


def _area(name, loc, target, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(loc)
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()
    return ob


def _camera(loc, target, lens=85.0):
    cd = bpy.data.cameras.new("PCam")
    cd.lens = lens
    cd.sensor_fit = "VERTICAL"
    cd.sensor_height = 24.0
    co = bpy.data.objects.new("PCam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = Vector(loc)
    co.rotation_euler = (Vector(target) - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    return co


def _export_view():
    """Swap the tagged parts for the export meshes (palette UVs, tint preview colours)."""
    objs = sf._tagged_objects()
    built = sf._build_export_meshes(objs, Vector((0, 0, 0)), True)
    for o in objs:
        o.hide_render = True
    for b in built:
        tint = b["src"][0].get("sf_tint")
        if tint:
            me = b["obj"].data
            me.materials.append(sf._flat_material(tint, roughness=0.6))
            ti = sf.swatch(sf.TINT)["uv"]
            uvl = me.uv_layers.active.data
            for poly in me.polygons:
                u = uvl[poly.loop_start].uv
                if abs(u[0] - ti[0]) < 1e-4 and abs(u[1] - ti[1]) < 1e-4:
                    poly.material_index = 1
    return built


def portrait(cls, w, h, out_name, framing):
    import Resident_Common as R
    outfit, skin, hair = CLASSES[cls]
    sf.reset()
    R.OUTFIT, R.SKIN, R.HAIR = outfit, skin, hair
    R.build()
    arm = R.arm
    for bone, (x, y, z) in POSES[cls].items():
        pb = arm.pose.bones[bone]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = Euler((math.radians(x), math.radians(y), math.radians(z))).to_quaternion()
    bpy.context.view_layer.update()
    _export_view()
    _render_setup(w, h)
    tz, half_h, yaw = framing          # look-at height, half the visible height, camera yaw
    lens = 85.0
    dist = half_h / math.tan(math.atan(12.0 / lens))
    a = math.radians(yaw)
    target = Vector((0, 0, tz))
    cam = target + Vector((math.sin(a), -math.cos(a), 0.06)) * dist
    _camera(cam, target, lens)
    _area("Key", target + Vector((-6, -7, 6)), target, 900, 5)
    _area("Fill", target + Vector((7, -5, 1)), target, 260, 6)
    _area("Rim", target + Vector((5, 6, 5)), target + Vector((0, 0, 0.6)), 1100, 3)
    p = os.path.join(K.SPRITES, f"{out_name}.png")
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print(f"[UI_Portraits] {out_name}")
    return p


def revolver_icon(size=256):
    import Weapon_ServiceRevolver as W
    sf.reset()
    W.build()
    _export_view()
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.hide_render]
    lo, hi = sf.bbox_world(objs)
    ctr = (lo + hi) / 2
    root = bpy.data.objects.new("IconRoot", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = ctr
    for o in objs:
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = (math.radians(-18), 0, math.radians(12))   # muzzle up and a little toward us
    bpy.context.view_layer.update()
    _render_setup(size, size, samples=96)
    cd = bpy.data.cameras.new("ICam")
    cd.type = "ORTHO"
    cd.ortho_scale = 3.0
    co = bpy.data.objects.new("ICam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = ctr + Vector((-10, 0, 0.6))
    co.rotation_euler = (ctr - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    _area("Key", ctr + Vector((-6, -3, 6)), ctr, 500, 4)
    _area("Fill", ctr + Vector((-5, 5, 0)), ctr, 160, 5)
    _area("Rim", ctr + Vector((4, 0, 4)), ctr, 450, 3)
    p = os.path.join(K.SPRITES, "Icon_ServiceRevolver.png")
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print("[UI_Portraits] Icon_ServiceRevolver")
    return p


SPECS = {f"Portrait_{c}": {"size": [340, 290], "slice": None, "note": f"{c} class portrait (card window)"}
         for c in CLASSES}
SPECS["Portrait_Security_Large"] = {"size": [480, 408], "slice": None, "note": "detail panel portrait"}
SPECS["Icon_ServiceRevolver"] = {"size": [256, 256], "slice": None, "note": "Service Revolver icon from the model"}

if __name__ == "__main__":
    want = set(sys.argv[1:])
    for c in CLASSES:
        if not want or f"Portrait_{c}" in want:
            portrait(c, 340, 290, f"Portrait_{c}", (4.42, 1.74, -24))
    if not want or "Portrait_Security_Large" in want:
        portrait("Security", 480, 408, "Portrait_Security_Large", (4.2, 1.95, -24))
    if not want or "Icon_ServiceRevolver" in want:
        revolver_icon()
    spec_path = os.path.join(K.UI, "specs.json")
    old = json.load(open(spec_path)) if os.path.exists(spec_path) else {}
    old.update(SPECS)
    with open(spec_path, "w") as f:
        json.dump(old, f, indent=1, sort_keys=True)
