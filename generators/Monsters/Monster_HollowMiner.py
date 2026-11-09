"""Monster_HollowMiner: the Mines brute (bible Section 27: slow and tough, smashes machines
and doors). A Steadfast miner the Source hollowed out: hunched, huge-armed, hard hat with a
headlamp that now burns green, a dark empty face with two green eyes, Source crystals
growing out of the back and a glowing rift in the chest. Never gory: it reads as a husk.

Segmented rig with Motor6Ds (bible Section 19): 11 bones, fists and boots merged into the
lower limbs, the pickaxe rides on RightLowerArm. Glow pieces are Neon MeshParts welded to
their bone part. Also authors HollowMiner_Attack, an overhead pickaxe smash with a Hit marker.

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_HollowMiner.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

ASSET, CATEGORY = "Monster_HollowMiner", "Monsters"
BUDGET = 4000
HIT_TIME = 0.7

JOINTS = [  # bone, parent, joint (Blender, ground z = 0, facing -Y)
    ("Pelvis", None, (0, 0.1, 2.9)),
    ("Torso", "Pelvis", (0, 0.05, 3.45)),
    ("Head", "Torso", (0, -1.15, 5.35)),
    ("LeftUpperArm", "Torso", (1.75, -0.4, 5.2)),
    ("LeftLowerArm", "LeftUpperArm", (2.15, -0.6, 3.75)),
    ("RightUpperArm", "Torso", (-1.75, -0.4, 5.2)),
    ("RightLowerArm", "RightUpperArm", (-2.15, -0.6, 3.75)),
    ("LeftUpperLeg", "Pelvis", (0.85, 0.15, 2.75)),
    ("LeftLowerLeg", "LeftUpperLeg", (0.95, 0.0, 1.45)),
    ("RightUpperLeg", "Pelvis", (-0.85, 0.15, 2.75)),
    ("RightLowerLeg", "RightUpperLeg", (-0.95, 0.0, 1.45)),
]
HRP_CENTER, HRP_SIZE = (0, 0.1, 3.6), (3.0, 2.0, 2.0)   # HRP size in Roblox axes (x, y, z)

arm = None


def part(obj, bone, swatch, collision="query", bind=True, **kw):
    sf.tag(obj, bone, swatch, collision=collision, **kw)
    if bind:
        sf.bind(obj, arm, bone)
    return obj


def glow(obj, bone, name):
    """A Source-green Neon piece: its own MeshPart, welded to the bone part in Studio."""
    sf.tag(obj, name, "glow", "Neon", collision="none", cast_shadow=False)
    obj["sf_bone"] = bone
    sf.bind(obj, arm, bone)
    return obj


def rod(p1, p2, radius, verts=8, name="Rod"):
    """A cylinder from p1 to p2."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    o = sf.cyl(radius, d.length, loc=(p1 + p2) / 2, verts=verts, bevel=0.0, name=name)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def crystal(base, direction, length, radius, name="Crystal"):
    """A six-sided Source crystal growing from base along direction."""
    d = Vector(direction).normalized()
    o = sf.cyl(radius, length, loc=Vector(base) + d * length / 2, verts=6, radius_top=radius * 0.15,
               bevel=0.0, name=name)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def left_and_right(make):
    for o in make("Left"):
        twin = sf.mirror_x(o)
        twin["sf_part"] = o["sf_part"].replace("Left", "Right")
        if "sf_bone" in o:
            twin["sf_bone"] = o["sf_bone"].replace("Left", "Right")
        sf.bind(o, arm, o.get("sf_bone", o["sf_part"]))
        sf.bind(twin, arm, twin.get("sf_bone", twin["sf_part"]))


def build():
    global arm
    arm = sf.make_rig("HollowMiner", JOINTS)

    # ---- Pelvis: hips in faded olive coveralls, a leather belt with an iron buckle
    part(sf.box((2.3, 1.5, 0.95), loc=(0, 0.1, 2.85), bevel=0.22, segments=1), "Pelvis", "olive", collision="query")
    part(sf.box((2.42, 1.62, 0.22), loc=(0, 0.1, 3.18), bevel=0.05, segments=1), "Pelvis", "leather", collision="query")
    part(sf.box((0.42, 0.1, 0.32), loc=(0, -0.72, 3.18), bevel=0.03, segments=1), "Pelvis", "gunmetal", collision="query")

    # ---- Torso: a hunched barrel of a chest leaning forward over the hips
    chest = sf.box((3.1, 2.0, 2.1), loc=(0, -0.15, 4.35), bevel=0.0)
    for v in chest.data.vertices:
        if v.co.z > 0:
            v.co.y -= 0.45          # hunch: the top leans forward
            v.co.x *= 1.08          # and broadens into the shoulders
    sf.bevel(chest, 0.38, 2)
    part(chest, "Torso", "olive", collision="query")
    # leather braces over the shoulders
    for sx in (-1, 1):
        part(sf.box((0.36, 2.2, 0.16), loc=(sx * 0.85, -0.45, 5.45), rot=(-12, 0, 0), bevel=0.04, segments=1), "Torso", "leather")
    # rock growths on the shoulders and back (the Source turning him to stone)
    for (x, y, z, s) in ((1.25, 0.25, 5.25, 0.55), (-1.1, 0.45, 5.05, 0.5), (0.2, 0.75, 5.45, 0.62)):
        part(sf.sphere(s, loc=(x, y, z), scale=(1.1, 0.9, 0.8), segs=7, rings=4), "Torso", "stone")
    # Source crystals out of the back, and a glowing rift in the chest
    for (b, d, ln, r) in (((0.25, 0.85, 5.6), (0.15, 0.8, 0.9), 1.4, 0.24),
                          ((0.8, 0.7, 5.3), (0.6, 0.7, 0.6), 1.0, 0.18),
                          ((-0.45, 0.9, 5.35), (-0.5, 0.75, 0.75), 1.1, 0.2),
                          ((-1.25, 0.6, 5.1), (-0.8, 0.45, 0.6), 0.7, 0.14)):
        glow(crystal(b, d, ln, r), "Torso", "TorsoGlow")
    rift = sf.box((0.26, 0.2, 1.3), loc=(0.15, -1.38, 4.35), rot=(-14, 0, 9), bevel=0.0)
    glow(rift, "Torso", "TorsoGlow")
    rift2 = sf.box((0.14, 0.2, 0.6), loc=(-0.35, -1.25, 4.05), rot=(-14, 0, -25), bevel=0.0)
    glow(rift2, "Torso", "TorsoGlow")

    # ---- Head: a dented hard hat over an empty dark face; the headlamp and eyes burn green
    part(sf.box((1.25, 1.05, 1.05), loc=(0, -1.5, 5.72), bevel=0.3, segments=1), "Head", "basalt", collision="query")
    dome = sf.sphere(0.88, loc=(0, -1.5, 6.18), scale=(1, 1.05, 0.7), segs=12, rings=6)
    part(dome, "Head", "hazard", collision="query")
    part(sf.cyl(1.0, 0.09, loc=(0, -1.45, 6.16), verts=14, bevel=0.0), "Head", "hazard", collision="query")
    part(sf.cyl(0.24, 0.26, loc=(0, -2.38, 6.32), rot=(90, 0, 0), verts=10, bevel=0.0), "Head", "steel")
    glow(sf.cyl(0.19, 0.06, loc=(0, -2.52, 6.32), rot=(90, 0, 0), verts=10, bevel=0.0), "Head", "HeadGlow")
    for sx in (-1, 1):
        glow(sf.sphere(0.17, loc=(sx * 0.28, -2.04, 5.8), scale=(1.35, 0.55, 0.9), segs=8, rings=4), "Head", "HeadGlow")
    for i, (x, z) in enumerate(((-0.32, 5.42), (-0.12, 5.36), (0.08, 5.41), (0.28, 5.35))):  # a jagged glowing grin
        glow(sf.box((0.2, 0.12, 0.09), loc=(x, -2.03, z), rot=(0, (-1) ** i * 18, 0), bevel=0.0), "Head", "HeadGlow")

    # ---- Arms (left; mirrored to the right): rolled sleeve, ash-grey forearm, huge fist
    def make_arm(side):
        out = []
        ua, la = f"{side}UpperArm", f"{side}LowerArm"
        out.append(part(sf.sphere(0.75, loc=(1.8, -0.4, 5.05), scale=(1, 1, 0.9), segs=10, rings=5), ua, "olive", bind=False))
        out.append(part(rod((1.85, -0.45, 5.0), (2.12, -0.58, 3.85), 0.56, verts=10), ua, "olive", bind=False))
        out.append(part(rod((2.12, -0.58, 4.05), (2.15, -0.6, 3.82), 0.62, verts=10), ua, "olive", bind=False))
        out.append(part(rod((2.15, -0.6, 3.8), (2.22, -0.72, 2.85), 0.46, verts=10), la, "stone", bind=False))
        out.append(part(sf.box((1.05, 1.15, 1.0), loc=(2.25, -0.8, 2.42), bevel=0.26, segments=1), la, "stone", bind=False))
        out.append(part(sf.box((1.0, 0.32, 0.34), loc=(2.25, -1.32, 2.62), bevel=0.1, segments=1), la, "stone", bind=False))
        o = sf.box((0.1, 0.12, 0.5), loc=(2.42, -1.02, 3.3), rot=(0, 20, 0), bevel=0.0)   # glowing crack in the forearm
        sf.tag(o, f"{side}ArmGlow", "glow", "Neon", collision="none", cast_shadow=False)
        o["sf_bone"] = la
        out.append(o)
        return out

    # ---- Legs (left; mirrored): stumpy trouser legs, steel-toed boots
    def make_leg(side):
        out = []
        ul, ll = f"{side}UpperLeg", f"{side}LowerLeg"
        out.append(part(sf.box((1.05, 1.15, 1.45), loc=(0.9, 0.08, 2.1), bevel=0.25, segments=1), ul, "olive", bind=False))
        out.append(part(sf.box((0.95, 1.05, 0.95), loc=(0.95, 0.0, 1.05), bevel=0.2, segments=1), ll, "olive", bind=False))
        out.append(part(sf.box((1.1, 1.65, 0.62), loc=(0.98, -0.22, 0.33), bevel=0.2, segments=1), ll, "leather", bind=False))
        out.append(part(sf.box((1.12, 0.5, 0.4), loc=(0.98, -0.95, 0.24), bevel=0.12, segments=1), ll, "steel", bind=False))
        out.append(part(sf.box((1.16, 1.7, 0.12), loc=(0.98, -0.22, 0.06), bevel=0.03, segments=1), ll, "rubber", bind=False))
        return out

    left_and_right(make_arm)
    left_and_right(make_leg)

    # ---- Pickaxe in the right fist: a long pine handle, an iron head pointing forward
    rf = "RightLowerArm"
    part(rod((-2.27, -0.82, 3.15), (-2.45, -1.95, 0.62), 0.17, verts=8), rf, "pine")
    head_c = Vector((-2.46, -2.0, 0.58))
    pick = sf.cyl(0.32, 2.2, loc=head_c + Vector((0, -0.8, 0)), rot=(90, 0, 0), verts=6, radius_top=0.05, bevel=0.0)
    part(pick, rf, "gunmetal")
    part(sf.box((0.5, 0.62, 0.56), loc=head_c + Vector((0, 0.15, 0.0)), bevel=0.08, segments=1), rf, "steel")
    part(sf.box((0.62, 0.55, 0.42), loc=head_c + Vector((0, 0.68, 0.0)), bevel=0.06, segments=1), rf, "gunmetal")

    return {"rig_type": "Custom", "root": "HumanoidRootPart", "hrp_size": HRP_SIZE,
            "hrp_center": HRP_CENTER, "hip_height": HRP_CENTER[2] - HRP_SIZE[1] / 2}


def attack_action():
    """HollowMiner_Attack: overhead pickaxe smash, 1.47 s, Hit at 0.7 s. Keys stay under 180
    degrees apart so Roblox's shortest-path blending can't swing the arm the wrong way."""
    act = sf.new_action(arm, "Attack", 0, 44, loop=False, priority="Action")
    k = lambda b, f, rot, loc=None, ease="SINE": sf.key(arm, b, f, rot=rot, loc=loc, ease=ease)  # noqa: E731
    rest = {b: (0, 0, 0) for b, _p, _j in JOINTS}
    for b in rest:
        k(b, 0, (0, 0, 0))
    # windup: right arm swings forward and up past the head, body coils back
    k("RightUpperArm", 7, (-95, 0, -10)); k("RightUpperArm", 15, (-178, 0, -12)); k("RightUpperArm", 18, (-182, 0, -12))
    k("RightLowerArm", 7, (-30, 0, 0)); k("RightLowerArm", 15, (-65, 0, 0)); k("RightLowerArm", 18, (-70, 0, 0))
    k("Torso", 15, (-14, -18, 0)); k("Torso", 18, (-16, -20, 0))
    k("Head", 15, (-14, 6, 0)); k("Head", 18, (-14, 6, 0))
    k("LeftUpperArm", 15, (-45, 0, 12)); k("LeftUpperArm", 18, (-48, 0, 14))
    k("LeftLowerArm", 15, (-35, 0, 0)); k("LeftLowerArm", 18, (-35, 0, 0))
    k("Pelvis", 15, (0, -6, 0), loc=(0, 0.1, 0)); k("Pelvis", 18, (0, -6, 0), loc=(0, 0.12, 0))
    # strike: everything comes down hard
    k("RightUpperArm", 21, (-55, 0, -6), ease="QUAD"); k("RightLowerArm", 21, (-12, 0, 0), ease="QUAD")
    k("Torso", 21, (30, 12, 0), ease="QUAD"); k("Head", 21, (12, 0, 0), ease="QUAD")
    k("LeftUpperArm", 21, (20, 0, 10)); k("LeftLowerArm", 21, (-15, 0, 0))
    k("Pelvis", 21, (0, 4, 0), loc=(0, -0.3, 0), ease="QUAD")
    k("LeftUpperLeg", 21, (-22, 0, 0)); k("LeftLowerLeg", 21, (26, 0, 0))
    k("RightUpperLeg", 21, (10, 0, 0)); k("RightLowerLeg", 21, (18, 0, 0))
    # impact recoil, then a slow brute recovery
    k("RightUpperArm", 27, (-62, 0, -6)); k("Torso", 27, (26, 10, 0)); k("Pelvis", 27, (0, 3, 0), loc=(0, -0.24, 0))
    for b in rest:
        k(b, 44, (0, 0, 0), loc=(0, 0, 0) if b == "Pelvis" else None)
    return act


def walk_action():
    """HollowMiner_Walk (A4, Prompt 12): a heavy, lumbering walk, 1.2 s a cycle; the pickaxe
    arm swings low and the torso rolls with each step."""
    act = sf.new_action(arm, "Walk", 0, 36, loop=True, priority="Movement")
    k = lambda b, f, rot, loc=None: sf.key(arm, b, f, rot=rot, loc=loc)  # noqa: E731
    for f, s in ((0, 1), (18, -1), (36, 1)):
        k("LeftUpperLeg", f, (-22 * s, 0, 0)); k("RightUpperLeg", f, (22 * s, 0, 0))
        k("LeftLowerLeg", f, (12 if s > 0 else 30, 0, 0)); k("RightLowerLeg", f, (30 if s > 0 else 12, 0, 0))
        k("LeftUpperArm", f, (16 * s, 0, 4)); k("RightUpperArm", f, (-14 * s, 0, -4))
        k("Torso", f, (6, -7 * s, 0)); k("Head", f, (-4, 5 * s, 0))
        k("Pelvis", f, (0, 5 * s, 0), loc=(0, 0, 0))
    for f in (9, 27):
        k("Pelvis", f, (0, 0, 0), loc=(0, 0.16, 0))
    return act


def contact_sheet(act, frames, name):
    from PIL import Image
    arm.animation_data.action = act
    paths = []
    for f in frames:
        bpy.context.scene.frame_set(f)
        paths.append(sf.render_preview(ASSET, CATEGORY, res=384, samples=16,
                                       views=[(-60, 12, False)], out_name=f"_{name}_{f}"))
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
        print(sf.render_preview(ASSET, CATEGORY, views=[(-30, 10, False), (150, 14, True)]))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(ASSET, CATEGORY, rig=arm, rig_meta=meta, budget=BUDGET, step="A0",
                              meta={"role": "Brute", "band": "Mines", "hitTime": HIT_TIME},
                              sockets={"Strike": ((-2.43, -2.6, 0.2), 0.0)})
        print(f"[{ASSET}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    act = attack_action()
    walk = walk_action()
    if os.environ.get("SF_EXPORT") == "1":
        print(sf.export_clips(arm, "HollowMiner", [act, walk], root="HumanoidRootPart",
                              markers={"Attack": {"Hit": HIT_TIME}}))
    if os.environ.get("SF_NORENDER") != "1":
        print(contact_sheet(act, [0, 15, 21, 27], "HollowMiner_Attack_sheet"))
        print(contact_sheet(walk, [0, 9, 18, 27], "HollowMiner_Walk_sheet"))
