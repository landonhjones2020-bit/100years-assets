"""Shared pieces for the A4 monster generators (bible Section 19: segmented rigs with
Motor6Ds, Source-green Neon pieces welded to their bone part, clips made in Blender).

A monster generator defines JOINTS, build(b) and clips(b), then calls run(). Bones point
straight up from their joints (steadfast.make_rig): X = the character's left (world X),
Y = up, Z = forward (world -Y). Limbs hanging down: forward swing = -X, knee bend = +X; an
upright body: lean forward = +X; turn left = +Y; a leg sticking out sideways swings forward
with -Y (left legs) or +Y (right legs) and lifts with +Z (left) or -Z (right).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402


class Beast:
    def __init__(self, name: str, joints: list):
        self.name = name
        self.joints = joints
        self.arm = sf.make_rig(name, joints)

    def part(self, obj, bone: str, swatch: str, collision="query", **kw):
        """A piece of the bone's MeshPart (pieces of one bone merge)."""
        sf.tag(obj, bone, swatch, collision=collision, **kw)
        sf.bind(obj, self.arm, bone)
        return obj

    def glow(self, obj, bone: str, name: str):
        """A Source-green Neon piece: its own MeshPart, welded to the bone part in Studio."""
        sf.tag(obj, name, "glow", "Neon", collision="none", cast_shadow=False)
        obj["sf_bone"] = bone
        sf.bind(obj, self.arm, bone)
        return obj

    def key(self, bone, frame, rot=(0, 0, 0), loc=None, ease="SINE"):
        sf.key(self.arm, bone, frame, rot=rot, loc=loc, ease=ease)

    def rest(self, frame, bones=None):
        for b, _p, _j in self.joints:
            if bones is None or b in bones:
                self.key(b, frame, (0, 0, 0), loc=(0, 0, 0))


def rod(p1, p2, radius, verts=8, radius_top=None, name="Rod"):
    """A cylinder from p1 to p2 (radius_top tapers it toward p2)."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    kw = {} if radius_top is None else {"radius_top": radius_top}
    o = sf.cyl(radius, d.length, loc=(p1 + p2) / 2, verts=verts, bevel=0.0, name=name, **kw)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def crystal(base, direction, length, radius, name="Crystal"):
    """A six-sided Source crystal growing from base along direction."""
    d = Vector(direction).normalized()
    o = sf.cyl(radius, length, loc=Vector(base) + d * length / 2, verts=6, radius_top=radius * 0.15,
               bevel=0.0, name=name)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def contact_sheet(asset, category, arm, act, frames, name, yaw=-60):
    from PIL import Image
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
        arm.animation_data.action_slot = act.slots[0]
    paths = []
    for f in frames:
        bpy.context.scene.frame_set(f)
        paths.append(sf.render_preview(asset, category, res=320, samples=12,
                                       views=[(yaw, 12, False)], out_name=f"_{name}_{f}"))
    ims = [Image.open(p) for p in paths]
    sheet = Image.new("RGB", (320 * len(ims), 320))
    for i, im in enumerate(ims):
        sheet.paste(im.convert("RGB").resize((320, 320)), (i * 320, 0))
        im.close()
    out = os.path.join(sf.REPO, "previews", category, f"{name}.png")
    sheet.save(out)
    for p in paths:
        os.remove(p)
    bpy.context.scene.frame_set(0)
    return out


def run(asset, category, beast_factory, build, clips, *, budget, hrp_center, hrp_size, meta, sockets=None,
        markers=None, step="A4"):
    """Build, preview, export the rigged model (SF_EXPORT=1) and its clips, render clip sheets."""
    sf.reset()
    b = beast_factory()
    build(b)
    rig_meta = {"rig_type": "Custom", "root": "HumanoidRootPart", "hrp_size": hrp_size,
                "hrp_center": hrp_center, "hip_height": hrp_center[2] - hrp_size[1] / 2}
    print(f"[{asset}] triangles before merge: {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(sf.render_preview(asset, category, views=[(-35, 12, False), (130, 16, True)]))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(asset, category, rig=b.arm, rig_meta=rig_meta, budget=budget, step=step,
                              meta=meta, sockets=sockets or {})
        print(f"[{asset}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    acts = clips(b)
    if os.environ.get("SF_EXPORT") == "1":
        for path in sf.export_clips(b.arm, b.name, acts, root="HumanoidRootPart", markers=markers or {}):
            print(path)
    if os.environ.get("SF_NORENDER") != "1":
        for act in acts:
            end = act["sf_end"]
            frames = sorted({0, round(end * 0.25), round(end * 0.5), round(end * 0.75)})
            print(contact_sheet(asset, category, b.arm, act, frames, f"{b.name}_{act.name}_sheet"))
    return b
