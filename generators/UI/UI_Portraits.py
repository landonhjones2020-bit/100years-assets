"""Class portraits and item icons rendered from the real models (bible Section 18: icons are
rendered from the 3D models, so they always match).

A0 sample: the four classes in the sample Class Shop, one per rarity, each the Resident
model dressed in its class outfit (generators/Residents/outfits.py: the rarer the class,
the more creative the look) and posed with its props; a larger portrait for the detail
panel; the Service Revolver icon for the hotbar and the kit list.

Outputs ui/sprites/Portrait_<Class>.png (340x290, the card window at 2x),
Portrait_<Class>_Large.png (480x408) and Icon_ServiceRevolver.png (256x256).

Run:  python3 generators/UI/UI_Portraits.py [Portrait_<Class> ...]
      python3 generators/UI/UI_Portraits.py --check [Class ...]   (previews/Residents/Outfit_<Class>.png)
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

import outfits as O  # noqa: E402

CLASSES = list(O.OUTFITS)          # the A0 class shop sample: one class per rarity


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


def _neon_material():
    """Neon parts glow in Roblox: in the render they emit their palette colour."""
    m = bpy.data.materials.get("PaletteNeon")
    if m:
        return m
    m = bpy.data.materials.new("PaletteNeon")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(sf.REPO, "palette", "palette.png"), check_existing=True)
    t.interpolation = "Closest"
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Color"], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 8.0
    return m


def _bloom(strength=0.9, size=7):
    """Studio's bloom on Neon: a glare pass whose halo also writes alpha, so it shows on the
    card behind the transparent sprite."""
    sc = bpy.context.scene
    ng = bpy.data.node_groups.new("CardComp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    sc.compositing_node_group = ng
    sc.render.use_compositing = True
    N, L = ng.nodes.new, ng.links.new
    rl = N("CompositorNodeRLayers")
    gl = N("CompositorNodeGlare")
    gl.inputs["Type"].default_value = "Bloom"
    gl.inputs["Threshold"].default_value = 2.0
    gl.inputs["Strength"].default_value = strength
    gl.inputs["Size"].default_value = size
    L(rl.outputs["Image"], gl.inputs["Image"])
    sep_i, sep_g = N("CompositorNodeSeparateColor"), N("CompositorNodeSeparateColor")
    L(rl.outputs["Image"], sep_i.inputs["Image"])
    L(gl.outputs["Glare"], sep_g.inputs["Image"])
    comb = N("CompositorNodeCombineColor")
    halo = None
    for ch in ("Red", "Green", "Blue"):
        add = N("ShaderNodeMath")
        add.operation = "ADD"
        L(sep_i.outputs[ch], add.inputs[0])
        L(sep_g.outputs[ch], add.inputs[1])
        L(add.outputs[0], comb.inputs[ch])
        if halo is None:
            halo = sep_g.outputs[ch]
        else:
            mx = N("ShaderNodeMath")
            mx.operation = "MAXIMUM"
            L(halo, mx.inputs[0])
            L(sep_g.outputs[ch], mx.inputs[1])
            halo = mx.outputs[0]
    a = N("ShaderNodeMath")
    a.operation = "MAXIMUM"
    a.use_clamp = True
    L(sep_i.outputs["Alpha"], a.inputs[0])
    L(halo, a.inputs[1])
    L(a.outputs[0], comb.inputs["Alpha"])
    out = N("NodeGroupOutput")
    L(comb.outputs["Image"], out.inputs[0])


def _export_view():
    """Swap the tagged parts for the export meshes (palette UVs, tint preview colours)."""
    objs = sf._tagged_objects()
    built = sf._build_export_meshes(objs, Vector((0, 0, 0)), True)
    for o in objs:
        o.hide_render = True
    for b in built:
        if b["src"][0].get("sf_material") == "Neon":
            b["obj"].data.materials[0] = _neon_material()
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


def dress(cls):
    """Build the resident in a class outfit, posed for its card, with its held props."""
    import Resident_Common as R
    o = O.OUTFITS[cls]
    sf.reset()
    R.OUTFIT, R.SKIN, R.HAIR = o["base"], o["skin"], o["hair"]
    R.build()
    o["build"]()
    O.pose(R.arm, o["pose"])
    if o["props"]:
        o["props"](O.Body(R.arm, o["pose"]))
    bpy.context.view_layer.update()
    _export_view()
    return o


def _shoot(path, w, h, tz, half_h, yaw, pitch=0.06, samples=96):
    """Place the card camera and lights for one view and render it."""
    sc = _render_setup(w, h, samples)
    for ob in [ob for ob in sc.objects if ob.type in ("CAMERA", "LIGHT")]:
        bpy.data.objects.remove(ob, do_unlink=True)
    lens = 85.0
    dist = half_h / math.tan(math.atan(12.0 / lens))
    a = math.radians(yaw)
    target = Vector((0, 0, tz))
    fwd = Vector((math.sin(a), -math.cos(a), pitch))
    _camera(target + fwd * dist, target, lens)
    side = Vector((math.cos(a), math.sin(a), 0))          # the camera's right
    _area("Key", target - side * 6 + fwd * 7 + Vector((0, 0, 6)), target, 900, 5)
    _area("Fill", target + side * 7 + fwd * 5 + Vector((0, 0, 1)), target, 260, 6)
    _area("Rim", target + side * 5 - fwd * 6 + Vector((0, 0, 5)), target + Vector((0, 0, 0.6)), 1100, 3)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def portrait(cls, w, h, out_name, framing=None, samples=96):
    o = dress(cls)
    _bloom()
    tz, half_h = framing or o["framing"]
    p = _shoot(os.path.join(K.SPRITES, f"{out_name}.png"), w, h, tz, half_h, O.CAM_YAW, samples=samples)
    print(f"[UI_Portraits] {out_name}")
    return p


def check_sheet(cls, samples=48):
    """previews/Residents/Outfit_<Class>.png: the card view, then the whole outfit from the
    front and from behind, on grey, for reviewing the look."""
    from PIL import Image
    o = dress(cls)
    _bloom()
    tmp = os.path.join(sf.REPO, "previews", "Residents", "_tmp")
    os.makedirs(tmp, exist_ok=True)
    tz, half_h = o["framing"]
    shots = [_shoot(os.path.join(tmp, "a.png"), 340 * 2, 290 * 2, tz, half_h, O.CAM_YAW, samples=samples),
             _shoot(os.path.join(tmp, "b.png"), 440, 580, 3.25, 3.55, -30, 0.1, samples),
             _shoot(os.path.join(tmp, "c.png"), 440, 580, 3.25, 3.55, 150, 0.1, samples)]
    ims = [Image.open(p).convert("RGBA") for p in shots]
    sheet = Image.new("RGBA", (680 + 440 * 2 + 40, 600), (74, 76, 80, 255))
    x = 10
    for im in ims:
        sheet.alpha_composite(im, (x, (600 - im.height) // 2))
        x += im.width + 10
    out = os.path.join(sf.REPO, "previews", "Residents", f"Outfit_{cls}.png")
    sheet.convert("RGB").save(out)
    for p in shots:
        os.remove(p)
    os.rmdir(tmp)
    print(f"[UI_Portraits] {out}")
    return out


def revolver_icon(size=256):
    return weapon_icon("Weapon_ServiceRevolver", "Icon_ServiceRevolver", size=size)


# Hotbar icons rendered from the weapon models (bible Section 18: item icons come from the real
# models). Each: (generator module, rotation of the model in degrees (x, z), camera ortho scale).
WEAPON_ICONS = {
    "Icon_ServiceRevolver": ("Weapon_ServiceRevolver", (-18, 12), 3.0),
    "Icon_PocketPistol": ("Weapon_PocketPistol", (-18, 12), 2.5),
    "Icon_Wrench": ("Weapon_Wrench", (-38, 12), 4.4),
    "Icon_Extinguisher": ("Tool_Extinguisher", (-12, 14), 2.9),     # Prompt 13
    "Icon_Welder": ("Tool_Welder", (-14, 12), 3.0),
    "Icon_Drill": ("Tool_Drill", (-16, 12), 3.7),                  # Prompt 14
    "Icon_Pickaxe": ("Weapon_Pickaxe", (-40, 12), 4.3),
}


def weapon_icon(module, sprite, size=256):
    import importlib
    W = importlib.import_module(module)
    _, (rx, rz), ortho = WEAPON_ICONS[sprite]
    sf.reset()
    W.build()
    _export_view()
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.hide_render]
    lo, hi = sf.bbox_world(objs)
    ctr = (lo + hi) / 2
    root = bpy.data.objects.new("IconRoot", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = ctr
    bpy.context.view_layer.update()   # (Prompt 13) or the parent inverse below misses ctr and the model drops off-centre
    for o in objs:
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()
    root.rotation_euler = (math.radians(rx), 0, math.radians(rz))   # front up and a little toward us
    bpy.context.view_layer.update()
    _render_setup(size, size, samples=96)
    cd = bpy.data.cameras.new("ICam")
    cd.type = "ORTHO"
    cd.ortho_scale = ortho
    co = bpy.data.objects.new("ICam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = ctr + Vector((-10, 0, 0.6))
    co.rotation_euler = (ctr - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    _area("Key", ctr + Vector((-6, -3, 6)), ctr, 500, 4)
    _area("Fill", ctr + Vector((-5, 5, 0)), ctr, 160, 5)
    _area("Rim", ctr + Vector((4, 0, 4)), ctr, 450, 3)
    p = os.path.join(K.SPRITES, f"{sprite}.png")
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print(f"[UI_Portraits] {sprite}")
    return p


SPECS = {f"Portrait_{c}": {"size": [340, 290], "slice": None, "note": f"{c} class portrait (card window)"}
         for c in CLASSES}
SPECS["Portrait_Security_Large"] = {"size": [480, 408], "slice": None, "note": "detail panel portrait"}
SPECS["Icon_ServiceRevolver"] = {"size": [256, 256], "slice": None, "note": "Service Revolver icon from the model"}
SPECS["Icon_PocketPistol"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Pocket Pistol icon from the model (hotbar)"}
SPECS["Icon_Wrench"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Wrench icon from the model (hotbar)"}
SPECS["Icon_Extinguisher"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Extinguisher icon from the model (hotbar)"}
SPECS["Icon_Welder"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Welder icon from the model (hotbar)"}
SPECS["Icon_Drill"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Drill icon from the model (hotbar)"}
SPECS["Icon_Pickaxe"] = {"size": [256, 256], "slice": None, "group": "items", "note": "Pickaxe icon from the model (hotbar)"}

if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--check":           # outfit review sheets only
        for c in args[1:] or CLASSES:
            check_sheet(c)
        sys.exit(0)
    want = set(args)
    for c in CLASSES:
        if not want or f"Portrait_{c}" in want:
            portrait(c, 340, 290, f"Portrait_{c}")
    if not want or "Portrait_Security_Large" in want:
        tz, half_h = O.OUTFITS["Security"]["framing"]
        portrait("Security", 480, 408, "Portrait_Security_Large", (tz - 0.22, half_h + 0.21))
    if not want or "Icon_ServiceRevolver" in want:
        revolver_icon()
    for sprite, (module, _rot, _ortho) in WEAPON_ICONS.items():
        if sprite != "Icon_ServiceRevolver" and (not want or sprite in want):
            weapon_icon(module, sprite)
    spec_path = os.path.join(K.UI, "specs.json")
    old = json.load(open(spec_path)) if os.path.exists(spec_path) else {}
    old.update(SPECS)
    with open(spec_path, "w") as f:
        json.dump(old, f, indent=1, sort_keys=True)
