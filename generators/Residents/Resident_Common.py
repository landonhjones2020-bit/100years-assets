"""Resident_Common: a Common resident in Work Overalls, on the standard R15 rig.

Bible Sections 11 and 19: residents use the standard R15 rig with segmented visuals; each
body segment is its own mesh on its bone, and only the left side is modelled (the right is
mirrored). Skin and hair sit on the palette's "tint" swatch, so the game picks each
resident's skin and hair colour through MeshPart.Color. The hair is its own MeshPart (role
Hair) because it needs a second colour. The face is a decal (decals/Face_Resident_*.png).

Also authors the resident walk (R15_ResidentWalk) on the same rig and renders a contact sheet.

Run:  SF_EXPORT=1 python3 generators/Residents/Resident_Common.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

ASSET, CATEGORY = "Resident_Common", "Residents"
BUDGET = 2500
SKIN, HAIR = "#C58F6A", "#5B3A24"          # preview colours only; the game sets MeshPart.Color
OUTFIT = "teal"                            # Work Overalls: teal Steadfast coveralls

arm = None


def J(bone: str) -> Vector:
    return arm.data.bones[bone].head_local.copy()


def part(obj, bone, swatch, collision="query", bind=True, **kw):
    """Tag a piece with its bone's name and (unless bind=False) bind it to that bone."""
    sf.tag(obj, bone, swatch, collision=collision, **kw)
    if bind:
        sf.bind(obj, arm, bone)
    return obj


def skin(obj, bone, collision="query"):
    return part(obj, bone, sf.TINT, collision=collision, tint=SKIN)


def left_and_right(make):
    """Build the left-side pieces (character's left = +X, unbound), mirror each across X for
    the right side, then bind both to their bones."""
    for o in make("Left"):
        twin = sf.mirror_x(o)
        twin["sf_part"] = o["sf_part"].replace("Left", "Right")
        sf.bind(o, arm, o["sf_part"])
        sf.bind(twin, arm, twin["sf_part"])


def build():
    global arm
    arm, meta = sf.r15_rig("R15")
    t = 0.0

    # ---- LowerTorso: pelvis, belt, buckle, tool pouch
    pelvis = sf.box((1.9, 1.04, 0.66), loc=(0, 0, 2.07), bevel=0.14, segments=1)
    part(pelvis, "LowerTorso", OUTFIT, collision="query")
    belt = sf.box((1.98, 1.12, 0.17), loc=(0, 0, 2.33), bevel=0.04, segments=1)
    part(belt, "LowerTorso", "leather", collision="query")
    buckle = sf.box((0.32, 0.08, 0.24), loc=(0, -0.58, 2.33), bevel=0.03, segments=1)
    part(buckle, "LowerTorso", "brass", collision="query")
    pouch = sf.box((0.36, 0.52, 0.44), loc=(0.98, -0.02, 2.12), bevel=0.06, segments=1)
    part(pouch, "LowerTorso", "leather", collision="query")

    # ---- UpperTorso: tapered chest, V-neck undershirt, zip, gopher patch, name tag
    chest = sf.box((1.92, 1.06, 1.52), loc=(0, 0, 3.15), bevel=0.0)
    for v in chest.data.vertices:          # broaden the shoulders: a chunky worker's wedge
        if v.co.z > 0:
            v.co.x *= 1.1
            v.co.y *= 1.04
    sf.bevel(chest, 0.16, 2)
    part(chest, "UpperTorso", OUTFIT, collision="query")
    # a 3-sided cylinder's first corner starts at +Y; tipping it -90 about X points it down
    vneck = sf.cyl(0.34, 0.1, loc=(0, -0.53, 3.72), rot=(-90, 0, 0), verts=3, bevel=0.0)
    part(vneck, "UpperTorso", "cream", collision="query")
    collar = sf.box((1.0, 0.9, 0.16), loc=(0, 0.02, 3.93), bevel=0.06, segments=1)
    part(collar, "UpperTorso", OUTFIT, collision="query")
    zipline = sf.box((0.06, 0.05, 1.16), loc=(0, -0.55, 3.0), bevel=0.0)
    part(zipline, "UpperTorso", "navy", collision="query")
    patch = sf.cyl(0.21, 0.06, loc=(0.47, -0.55, 3.45), rot=(90, 0, 0), verts=12, bevel=0.0)
    part(patch, "UpperTorso", "cream", collision="query")
    patch_in = sf.cyl(0.11, 0.04, loc=(0.47, -0.585, 3.45), rot=(90, 0, 0), verts=10, bevel=0.0)
    part(patch_in, "UpperTorso", "navy", collision="query")
    tagp = sf.box((0.48, 0.05, 0.15), loc=(-0.47, -0.55, 3.5), bevel=0.0)
    part(tagp, "UpperTorso", "cream", collision="query")

    # ---- Head: neck, rounded head, ears, nose (skin); hair is its own part
    skin(sf.cyl(0.3, 0.34, loc=(0, 0, 4.06), verts=10, bevel=0.0), "Head", collision="query")
    head = sf.box((1.34, 1.24, 1.38), loc=(0, -0.02, 4.82), bevel=0.34, segments=2)
    skin(head, "Head", collision="query")
    nose = sf.sphere(0.15, loc=(0, -0.65, 4.7), scale=(1, 0.8, 0.95), segs=8, rings=6)
    skin(nose, "Head", collision="query")
    for sx in (-1, 1):
        ear = sf.sphere(0.18, loc=(sx * 0.68, 0.05, 4.8), scale=(0.55, 1, 1.25), segs=8, rings=6)
        skin(ear, "Head", collision="query")
    hair_cap = sf.box((1.42, 1.32, 0.52), loc=(0, 0.05, 5.34), bevel=0.22, segments=2)
    hair_back = sf.box((1.4, 0.44, 0.84), loc=(0, 0.46, 5.02), bevel=0.16, segments=1)
    quiff = sf.box((1.08, 0.6, 0.38), loc=(0.06, -0.42, 5.58), rot=(-14, 0, 6), bevel=0.15, segments=2)
    burns = [sf.box((0.1, 0.2, 0.36), loc=(sx * 0.69, -0.08, 4.94), bevel=0.0) for sx in (-1, 1)]
    for h in [hair_cap, hair_back, quiff] + burns:
        part(h, "Head", sf.TINT, role="Hair", tint=HAIR)

    # preview-only face decal (not exported: untagged); follows the Head bone in poses
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, -0.66, 4.7), rotation=(math.radians(90), 0, 0))
    face = bpy.context.active_object
    face.name = "FacePreview"
    face.scale = (1.5, 1.62, 1)
    mat = bpy.data.materials.new("FaceDecal")
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(sf.REPO, "decals", "Face_Resident_Smile.png"))
    bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    face.data.materials.append(mat)
    mw = face.matrix_world.copy()
    face.parent, face.parent_type, face.parent_bone = arm, "BONE", "Head"
    bpy.context.view_layer.update()
    face.matrix_world = mw

    # ---- Arms (left; the right is mirrored)
    def make_arm(side):
        sx = 1.0
        out = []
        ua = f"{side}UpperArm"
        out.append(part(sf.sphere(0.43, loc=(sx * 1.5, 0, 3.68), scale=(1, 1, 0.78), segs=10, rings=5), ua, OUTFIT, bind=False))
        out.append(part(sf.cyl(0.42, 0.72, loc=(sx * 1.5, 0, 3.33), verts=10, radius_top=0.44, bevel=0.0), ua, OUTFIT, bind=False))
        out.append(part(sf.cyl(0.47, 0.2, loc=(sx * 1.5, 0, 3.02), verts=10, bevel=0.04, segments=1), ua, OUTFIT, bind=False))
        la = f"{side}LowerArm"
        out.append(part(sf.cyl(0.32, 0.8, loc=(sx * 1.5, 0, 2.58), verts=10, radius_top=0.36, bevel=0.0), la, sf.TINT, tint=SKIN, bind=False))
        hd = f"{side}Hand"
        out.append(part(sf.box((0.5, 0.56, 0.52), loc=(sx * 1.53, -0.02, 1.98), bevel=0.15, segments=1), hd, sf.TINT, tint=SKIN, bind=False))
        out.append(part(sf.box((0.2, 0.2, 0.32), loc=(sx * 1.4, -0.3, 2.06), rot=(0, -12, 0), bevel=0.06, segments=1), hd, sf.TINT, tint=SKIN, bind=False))
        return out

    # ---- Legs (left; the right is mirrored)
    def make_leg(side):
        sx = 1.0
        out = []
        ul = f"{side}UpperLeg"
        out.append(part(sf.box((0.9, 0.96, 0.98), loc=(sx * 0.5, 0, 1.6), bevel=0.2, segments=1), ul, OUTFIT, bind=False))
        ll = f"{side}LowerLeg"
        out.append(part(sf.box((0.8, 0.88, 0.64), loc=(sx * 0.5, 0, 0.88), bevel=0.16, segments=1), ll, OUTFIT, bind=False))
        out.append(part(sf.box((0.9, 0.98, 0.17), loc=(sx * 0.5, 0, 0.61), bevel=0.05, segments=1), ll, OUTFIT, bind=False))
        out.append(part(sf.box((0.74, 0.82, 0.34), loc=(sx * 0.5, 0, 0.42), bevel=0.08, segments=1), ll, "leather", bind=False))
        ft = f"{side}Foot"
        out.append(part(sf.box((0.74, 1.14, 0.36), loc=(sx * 0.5, -0.17, 0.21), bevel=0.14, segments=1), ft, "leather", bind=False))
        out.append(part(sf.box((0.78, 1.18, 0.1), loc=(sx * 0.5, -0.17, 0.05), bevel=0.03, segments=1), ft, "rubber", bind=False))
        return out

    left_and_right(make_arm)
    left_and_right(make_leg)
    return meta


def walk_action():
    """R15_ResidentWalk: one stride cycle (two steps) in 1.0 s, looped, Movement priority.
    Angles use the upright-bone convention from steadfast.make_rig: forward swing = -X."""
    act = sf.new_action(arm, "ResidentWalk", 0, 30, loop=True, priority="Movement")

    def pose(f, leg_l, knee_l, foot_l, leg_r, knee_r, foot_r, arm_l, arm_r, elb_l, elb_r, twist, bob):
        k = lambda b, rot, loc=None: sf.key(arm, b, f, rot=rot, loc=loc)  # noqa: E731
        k("LeftUpperLeg", (-leg_l, 0, 0)); k("LeftLowerLeg", (knee_l, 0, 0)); k("LeftFoot", (-foot_l, 0, 0))
        k("RightUpperLeg", (-leg_r, 0, 0)); k("RightLowerLeg", (knee_r, 0, 0)); k("RightFoot", (-foot_r, 0, 0))
        k("LeftUpperArm", (-arm_l, 0, 4)); k("RightUpperArm", (-arm_r, 0, -4))
        k("LeftLowerArm", (-elb_l, 0, 0)); k("RightLowerArm", (-elb_r, 0, 0))
        k("UpperTorso", (4, twist, 0)); k("LowerTorso", (0, -twist * 0.6, 0), loc=(0, bob, 0))
        k("Head", (-3, -twist * 0.8, 0))

    #     frame leg_l knee_l foot_l leg_r knee_r foot_r arm_l arm_r elb_l elb_r twist bob
    pose(0, 26, 6, 12, -22, 26, -14, -20, 22, 14, 26, 6, -0.07)
    pose(8, 2, 4, 0, 8, 52, 6, -2, 4, 18, 18, 0, 0.07)
    pose(15, -22, 26, -14, 26, 6, 12, 22, -20, 26, 14, -6, -0.07)
    pose(23, 8, 52, 6, 2, 4, 0, 4, -2, 18, 18, 0, 0.07)
    pose(30, 26, 6, 12, -22, 26, -14, -20, 22, 14, 26, 6, -0.07)
    return act


def contact_sheet(act, frames, name):
    from PIL import Image
    arm.animation_data.action = act
    paths = []
    for f in frames:
        bpy.context.scene.frame_set(f)
        paths.append(sf.render_preview(ASSET, CATEGORY, res=384, samples=16,
                                       views=[(80, 8, False)], out_name=f"_{name}_{f}"))
    ims = [Image.open(p) for p in paths]
    sheet = Image.new("RGB", (384 * len(ims), 384))
    for i, im in enumerate(ims):
        sheet.paste(im, (i * 384, 0))
    out = os.path.join(sf.REPO, "previews", CATEGORY, f"{name}.png")
    sheet.save(out)
    for p in paths:
        os.remove(p)
    bpy.context.scene.frame_set(0)
    return out


if __name__ == "__main__":
    sf.reset()
    meta = build()
    print(f"[{ASSET}] triangles before merge: {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(sf.render_preview(ASSET, CATEGORY))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(ASSET, CATEGORY, rig=arm, rig_meta=meta, budget=BUDGET, step="A0",
                              meta={"outfit": "Work Overalls", "face": "Face_Resident_Smile",
                                    "faceDecalFace": "Front"})
        print(f"[{ASSET}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    act = walk_action()
    if os.environ.get("SF_EXPORT") == "1":
        print(sf.export_clips(arm, "R15", [act], root="HumanoidRootPart"))
    if os.environ.get("SF_NORENDER") != "1":
        print(contact_sheet(act, [0, 8, 15, 23], "R15_ResidentWalk_sheet"))
