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
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
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


# ---- detail helpers (2026-11-08: Landon asked for more detailed monsters and scary bosses) ----

def spike(base, direction, length, radius, verts=5, name="Spike"):
    """A straight cone from base along direction (spines, teeth, horns, bristles)."""
    d = Vector(direction).normalized()
    o = sf.cyl(radius, length, loc=Vector(base) + d * length / 2, verts=verts, radius_top=0.0, bevel=0.0,
               name=name)
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    return o


def claw(base, direction, length, radius, bend=(0, 0, -1), curl=0.35, sides=6, resolution=1, name="Claw"):
    """A curved, tapering hook (claws, fangs, horns): bends toward `bend` as it grows."""
    d = Vector(direction).normalized()
    n = Vector(bend).normalized()
    p0 = Vector(base)
    pts = [p0, p0 + d * length * 0.4 + n * length * curl * 0.12,
           p0 + d * length * 0.75 + n * length * curl * 0.45, p0 + d * length * 0.92 + n * length * curl]
    return sf.tube(pts, [radius, radius * 0.72, radius * 0.38, 0.004], sides=sides, resolution=resolution, name=name)


def limb(points, radii, sides=8, resolution=2, name="Limb"):
    """A smooth tapered limb, tail or tentacle through points."""
    return sf.tube([tuple(p) for p in points], radii, sides=sides, resolution=resolution, name=name)


def blob(radius, loc, scale=(1, 1, 1), segs=12, rings=8, noise=0.0, seed=1, name="Blob"):
    """A sphere, optionally lumpy (noise as a fraction of the radius, seeded so it never changes)."""
    o = sf.sphere(radius, loc=(0, 0, 0), scale=scale, segs=segs, rings=rings, name=name)
    if noise > 0:
        rnd = random.Random(seed)
        for v in o.data.vertices:
            n = Vector(v.co).normalized()
            v.co += n * rnd.uniform(-noise, noise) * radius
    o.location = Vector(loc)
    return o


def shell(radii, loc, y_from, y_to, z_from=-0.2, thickness=0.12, segs=18, rings=12, rot=(0, 0, 0), name="Shell"):
    """An armour band: the slice of an ellipsoid shell between y_from and y_to (fractions of
    its Y radius, -1 front to +1 back) above z_from, given a thickness outward."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))

    def cut(co, no, clear_inner):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=clear_inner,
                               clear_outer=not clear_inner)

    cut((0, y_to * radii[1], 0), (0, 1, 0), False)
    cut((0, y_from * radii[1], 0), (0, 1, 0), True)
    cut((0, 0, z_from * radii[2]), (0, 0, 1), True)
    o = sf.from_bmesh(bm, name, loc, rot)
    mod = o.modifiers.new("Solid", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    return o


def eye(b, bone, loc, r, facing=(0, -1, 0), socket="basalt", name="HeadGlow", segs=8):
    """A glowing eye set in a dark socket rim, looking along `facing`."""
    f = Vector(facing).normalized()
    rings = 4 if segs <= 6 else 5
    b.part(sf.sphere(r * 1.5, loc=Vector(loc) - f * r * 0.35, segs=segs, rings=rings), bone, socket)
    return b.glow(sf.sphere(r, loc=Vector(loc) + f * r * 0.4, segs=segs, rings=rings), bone, name)


def arc(center, radius, a0, a1, n, plane="xy", z=0.0):
    """n points on an arc (degrees) around center in a plane: xy (around Z) or xz (around Y)."""
    c = Vector(center)
    out = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * (i / max(1, n - 1)))
        if plane == "xy":
            out.append(c + Vector((radius * math.cos(a), radius * math.sin(a), z)))
        else:
            out.append(c + Vector((radius * math.cos(a), z, radius * math.sin(a))))
    return out


def teeth(b, bone, points, direction, length, radius, swatch="cream", verts=4, jitter=0.25, seed=3):
    """A row of fangs along points, all pointing roughly along direction."""
    rnd = random.Random(seed)
    for p in points:
        k = 1.0 + rnd.uniform(-jitter, jitter)
        b.part(spike(p, direction, length * k, radius * k, verts=verts), bone, swatch)


def vein(b, bone, points, radius, name):
    """A thin glowing Source vein (a Neon tube) along points."""
    return b.glow(sf.tube([tuple(p) for p in points], [radius] * len(points), sides=4, resolution=2,
                          name="Vein"), bone, name)


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
    if os.environ.get("SF_NORENDER") != "1" and os.environ.get("SF_NOSHEETS") != "1":
        for act in acts:
            end = act["sf_end"]
            frames = sorted({0, round(end * 0.25), round(end * 0.5), round(end * 0.75)})
            print(contact_sheet(asset, category, b.arm, act, frames, f"{b.name}_{act.name}_sheet"))
    return b
