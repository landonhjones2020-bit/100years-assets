"""Class outfits on the resident rig: bible Section 19, "rarity shows in the look".

Every outfit adds pieces bound to the R15 bones of the resident that Resident_Common.build()
made, so they pose and animate with it. The rarer the class, the further it goes, and
nothing rare is ever a recolour:

* Common (Security): a clean work outfit. Padded vest, soft cap, brass badge.
* Rare (Quartermaster): its own outfit (canvas apron, flat cap), one signature piece (the
  supply pack, with its bedroll, lantern and requisition pennant) and an accent colour
  (hazard yellow).
* Epic (Warden): a new silhouette (a caped greatcoat with a high collar), several signature
  pieces (peaked cap, fringed epaulettes, the Rally Call megaphone), brass detailing and a
  small effect (the glowing Steadfast Star).
* Legendary (Mad Scientist): one of a kind. Wild hand-made hair and moustache, glowing
  goggles, a brass mechanical arm with a claw, the Gadget Belt, and a Glowshard reactor pack
  whose Tesla coil sparks over his head.

OUTFITS[name] holds the base outfit swatch and preview skin and hair (set on Resident_Common
before build()), the worn pieces ("build"), and the class card's pose, held props and
framing (used by generators/UI/UI_Portraits.py). Held props are card-only: in a run the
hands hold the player's tools.

Usage:
    R.OUTFIT, R.SKIN, R.HAIR = o["base"], o["skin"], o["hair"]; R.build(); o["build"]()
    pose(R.arm, o["pose"]); o["props"](Body(R.arm, o["pose"]))
"""
import math

import bpy
from mathutils import Euler, Matrix, Vector

import Resident_Common as R

sf = R.sf

LEGS = ("LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg")
ARMS = ("LeftUpperArm", "RightUpperArm")


# ------------------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------------------

def P(obj, bone, swatch, **kw):
    """A worn piece: decoration (no collision) bound to a bone of the resident."""
    kw.setdefault("collision", "none")
    sf.tag(obj, f"Outfit{bone}", swatch, **kw)
    sf.bind(obj, R.arm, bone)
    return obj


def glow(obj, bone, swatch="glow"):
    """A glowing piece: its own Neon MeshPart, welded to the bone's part in Studio."""
    sf.tag(obj, f"Glow{bone}", swatch, mat="Neon", cast_shadow=False)
    sf.bind(obj, R.arm, bone)
    return obj


def drop(pred):
    """Remove base pieces an outfit replaces."""
    for o in list(bpy.context.scene.objects):
        if o.get("sf_part") and pred(o):
            bpy.data.objects.remove(o, do_unlink=True)


def recolor(parts, frm, to):
    for o in bpy.context.scene.objects:
        if o.get("sf_part") in parts and o.get("sf_swatch") == frm:
            o["sf_swatch"] = to


def _aim(obj, p0, p1, normal=None):
    """Put obj (built around its origin along local +Z) on the segment p0 -> p1. With
    `normal`, its local Y (the thin side of a band) faces that way."""
    p0, p1 = Vector(p0), Vector(p1)
    z = (p1 - p0).normalized()
    if normal is None:
        obj.rotation_euler = z.to_track_quat("Z", "Y").to_euler()
    else:
        n = Vector(normal)
        y = (n - z * n.dot(z)).normalized()
        x = y.cross(z)
        obj.rotation_euler = Matrix((x, y, z)).transposed().to_euler()
    obj.location = (p0 + p1) / 2
    return obj


def rod(p0, p1, r, verts=8, r_end=None):
    """A cylinder (or a cone with r_end) from p0 to p1."""
    o = sf.cyl(r, (Vector(p1) - Vector(p0)).length, verts=verts, radius_top=r_end, bevel=0.0)
    return _aim(o, p0, p1)


def spike(p0, p1, r, verts=6):
    """A tuft or spike: a cone from a base at p0 to a point at p1."""
    return rod(p0, p1, r, verts, r_end=0.02)


def band(p0, p1, width, thick, normal=(0, -1, 0)):
    """A flat strap from p0 to p1, its face toward `normal`."""
    o = sf.box((width, thick, (Vector(p1) - Vector(p0)).length), bevel=0.0)
    return _aim(o, p0, p1, normal)


def flat(points_xz, thick, y, bevel=0.012):
    """A slab from an outline in the XZ plane (x across, z up), `thick` deep, centred on y."""
    return sf.profile_slab(points_xz, thick, loc=(0, y + thick / 2, 0), rot=(90, 0, 0),
                           bevel=bevel, segments=1)


def star_xz(cx, cz, r_out, r_in, n=5):
    return [(cx + math.cos(math.radians(90 + i * 180 / n)) * (r_out if i % 2 == 0 else r_in),
             cz + math.sin(math.radians(90 + i * 180 / n)) * (r_out if i % 2 == 0 else r_in))
            for i in range(n * 2)]


def open_shell(r_bot, r_top, height, z, front_y, thick=0.07, y_scale=1.0, verts=28):
    """A cape or mantle: a frustum shell around the body, open at the front (y < front_y)."""
    import bmesh
    o = sf.cyl(r_bot, height, verts=verts, radius_top=r_top, bevel=0.0)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for f in [f for f in bm.faces if abs(f.normal.z) > 0.95]:      # drop the caps
        bm.faces.remove(f)
    for v in bm.verts:
        v.co.y *= y_scale
    cut = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:],
                                 plane_co=(0, front_y, 0), plane_no=(0, 1, 0), clear_inner=True)
    del cut
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    bm.to_mesh(o.data)
    bm.free()
    o.location = (0, 0, z)
    sol = o.modifiers.new("Shell", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    return o


def short_hair(colour):
    """Hair that sits under a hat: a rounded block at the back and the sideburns."""
    drop(lambda o: o.get("sf_role") == "Hair")
    P(sf.box((1.4, 0.74, 0.78), loc=(0, 0.29, 5.07), bevel=0.32, segments=2), "Head", sf.TINT, role="Hair", tint=colour)
    for sx in (-1, 1):
        P(sf.box((0.1, 0.22, 0.4), loc=(sx * 0.69, -0.08, 4.96), bevel=0.0), "Head", sf.TINT, role="Hair", tint=colour)


def long_sleeves(swatch, cuff, sides=("Left", "Right")):
    """Coat sleeves down to the wrist over the bare forearms, with a cuff."""
    for side in sides:
        sx = 1 if side == "Left" else -1
        P(sf.cyl(0.38, 0.8, loc=(sx * 1.5, 0, 2.6), verts=10, radius_top=0.43, bevel=0.0), f"{side}LowerArm", swatch)
        P(sf.cyl(0.41, 0.14, loc=(sx * 1.5, 0, 2.27), verts=10, bevel=0.02, segments=1), f"{side}LowerArm", cuff)


def bare_chest():
    """Remove the overalls' V-neck, zip, patch and name tag under a vest, apron or coat."""
    drop(lambda o: o.get("sf_detail") == "chest")


def pose(arm, angles):
    """Card pose: bone -> (x, y, z) degrees in the upright-bone convention (steadfast.make_rig):
    -x swings a limb forward, -y lifts the left arm out (+y the right), +z turns the head
    toward the character's left."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        x, y, z = angles.get(pb.name, (0, 0, 0))
        pb.rotation_quaternion = Euler((math.radians(x), math.radians(y), math.radians(z))).to_quaternion()
    bpy.context.view_layer.update()


class Body:
    """The posed resident, for placing held props in world space: where a point on a bone
    went, and moving a hand to a target (IK on the arm) before building a prop there."""
    HAND = {"Left": Vector((1.53, -0.02, 1.98)), "Right": Vector((-1.53, -0.02, 1.98))}

    def __init__(self, arm, angles):
        self.arm = arm
        self.angles = dict(angles)

    def m(self, bone):
        """Rest-to-posed transform of a bone (world space)."""
        b, pb, mw = self.arm.data.bones[bone], self.arm.pose.bones[bone], self.arm.matrix_world
        return mw @ pb.matrix @ b.matrix_local.inverted() @ mw.inverted()

    def at(self, bone, rest_point):
        """Where a point given in the rest pose ended up."""
        return self.m(bone) @ Vector(rest_point)

    def hand(self, side, rest_offset=(0, 0, 0)):
        return self.at(f"{side}Hand", self.HAND[side] + Vector(rest_offset))

    def reach(self, side, target):
        """Bend the arm so the hand centre lands on `target`: coordinate descent on the
        upper arm (x, y, z) and the elbow, starting from the card pose."""
        ua, la = f"{side}UpperArm", f"{side}LowerArm"
        v = list(self.angles.get(ua, (0, 0, 0))) + [self.angles.get(la, (0, 0, 0))[0]]
        target = Vector(target)

        def cost(w):
            a = dict(self.angles)
            a[ua], a[la] = (w[0], w[1], w[2]), (w[3], 0, 0)
            pose(self.arm, a)
            return (self.hand(side) - target).length_squared + 2e-6 * (w[0] ** 2 + w[1] ** 2 + w[2] ** 2)
        best, step = cost(v), 16.0
        while step > 0.25:
            better = False
            for i in range(4):
                for d in (step, -step):
                    w = v[:]
                    w[i] += d
                    w[3] = max(-150.0, min(0.0, w[3]))
                    c = cost(w)
                    if c < best:
                        best, v, better = c, w, True
            if not better:
                step /= 2
        self.angles[ua], self.angles[la] = (v[0], v[1], v[2]), (v[3], 0, 0)
        pose(self.arm, self.angles)
        return math.sqrt(best)

    def prop(self, side, obj, swatch, **kw):
        """Bind a prop built in world space to the hand, so it would follow it."""
        kw.setdefault("collision", "none")
        sf.tag(obj, f"Prop{side}Hand", swatch, **kw)
        sf.bind(obj, self.arm, f"{side}Hand")
        return obj

    def glow(self, side, obj, swatch="glow"):
        sf.tag(obj, f"PropGlow{side}Hand", swatch, mat="Neon", cast_shadow=False)
        sf.bind(obj, self.arm, f"{side}Hand")
        return obj


def _rot_toward_camera(yaw_deg, tilt_deg=0.0):
    """Euler (degrees) that turns a board facing -Y toward the card camera at `yaw_deg`."""
    return (-tilt_deg, 0, yaw_deg)


CAM_YAW = -24.0     # the card camera sits in front and to the character's right


# ------------------------------------------------------------------------------------------
# Common: Security
# ------------------------------------------------------------------------------------------

def security():
    short_hair("#1E1A17")
    bare_chest()
    P(sf.cyl(0.25, 0.1, loc=(0, -0.53, 3.8), rot=(-90, 0, 0), verts=3, bevel=0.0), "UpperTorso", "cream")
    # padded vest: three quilted rolls over a core, a zip, a brass badge and a shoulder radio
    P(sf.box((2.12, 1.1, 1.12), loc=(0, 0, 3.3), bevel=0.12, segments=1), "UpperTorso", "ash")
    for i, z in enumerate((2.93, 3.3, 3.67)):
        P(sf.box((2.2 - i * 0.02, 1.18, 0.4), loc=(0, 0, z), bevel=0.15, segments=2), "UpperTorso", "ash")
    P(sf.box((0.1, 0.06, 1.12), loc=(0, -0.6, 3.3), bevel=0.0), "UpperTorso", "steel")
    P(flat(star_xz(0.55, 3.55, 0.2, 0.1, 6), 0.07, -0.62), "UpperTorso", "brass")
    P(sf.cyl(0.07, 0.08, loc=(0.55, -0.66, 3.55), rot=(90, 0, 0), verts=8, bevel=0.0), "UpperTorso", "navy")
    P(sf.box((0.32, 0.2, 0.46), loc=(-0.62, -0.62, 3.62), bevel=0.05, segments=1), "UpperTorso", "rubber")
    P(sf.box((0.2, 0.05, 0.14), loc=(-0.62, -0.73, 3.7), bevel=0.0), "UpperTorso", "gunmetal")
    P(rod((-0.72, -0.62, 3.84), (-0.72, -0.62, 4.24), 0.035, 6), "UpperTorso", "rubber")
    # soft navy cap with a brass shield
    P(sf.cyl(0.76, 0.3, loc=(0, 0.03, 5.56), verts=20, radius_top=0.74, bevel=0.04, segments=1), "Head", "navy")
    P(sf.sphere(0.75, loc=(0, 0.03, 5.7), scale=(1, 1, 0.26), segs=20, rings=8), "Head", "navy")
    P(sf.box((1.16, 0.5, 0.07), loc=(0, -0.72, 5.42), rot=(8, 0, 0), bevel=0.03, segments=1), "Head", "navy")
    P(flat([(-0.13, 5.5), (0.13, 5.5), (0.13, 5.68), (0, 5.74), (-0.13, 5.68)], 0.05, -0.75), "Head", "brass")


# ------------------------------------------------------------------------------------------
# Rare: Quartermaster
# ------------------------------------------------------------------------------------------

def quartermaster():
    short_hair("#A0522D")
    bare_chest()
    # tweed flat cap with a hazard-yellow button
    P(sf.sphere(0.8, loc=(0, -0.02, 5.47), scale=(1.0, 1.12, 0.42), segs=18, rings=8), "Head", "walnut")
    P(sf.box((1.0, 0.42, 0.07), loc=(0, -0.82, 5.38), rot=(10, 0, 0), bevel=0.03, segments=1), "Head", "walnut")
    P(sf.cyl(0.1, 0.06, loc=(0, -0.02, 5.81), verts=8, bevel=0.0), "Head", "hazard")
    # a stub of pencil behind the right ear
    P(rod((-0.76, 0.18, 5.17), (-0.7, -0.32, 4.83), 0.05, 6), "Head", "hazard")
    P(rod((-0.7, -0.32, 4.83), (-0.69, -0.39, 4.78), 0.05, 6, r_end=0.01), "Head", "pine")
    # canvas apron: bib with a pocket of pencils and a docket, neck straps, waist tie, skirt
    P(sf.box((1.3, 0.07, 0.95), loc=(0, -0.59, 3.25), bevel=0.03, segments=1), "UpperTorso", "sandstone")
    P(sf.box((0.6, 0.05, 0.36), loc=(0.26, -0.64, 3.1), bevel=0.02, segments=1), "UpperTorso", "stone")
    for x, h in ((0.1, 0.48), (0.2, 0.42)):
        P(rod((x, -0.64, 3.2), (x, -0.64, 3.2 + h), 0.035, 6), "UpperTorso", "hazard")
    P(sf.box((0.22, 0.04, 0.42), loc=(0.42, -0.65, 3.3), rot=(0, -8, 0), bevel=0.0), "UpperTorso", "porcelain")
    for sx in (-1, 1):
        P(band((sx * 0.58, -0.6, 3.68), (sx * 0.36, -0.2, 4.06), 0.13, 0.04, (0, -1, 0.4)), "UpperTorso", "leather")
    P(sf.box((2.0, 1.14, 0.1), loc=(0, 0, 2.47), bevel=0.02, segments=1), "LowerTorso", "sandstone")
    P(sf.box((1.62, 0.07, 1.25), loc=(0, -0.62, 1.9), rot=(5, 0, 0), bevel=0.03, segments=1), "LowerTorso", "sandstone")
    P(sf.box((1.1, 0.05, 0.42), loc=(0, -0.68, 2.0), rot=(5, 0, 0), bevel=0.02, segments=1), "LowerTorso", "stone")
    # the supply pack: steel frame and shoulder straps, a stencilled crate, a bedroll on top,
    # and a lantern hung off the right post
    for sx in (-1, 1):
        P(sf.box((0.11, 0.11, 2.45), loc=(sx * 0.7, 0.74, 3.42), bevel=0.0), "UpperTorso", "steel")
        P(band((sx * 0.72, -0.56, 2.75), (sx * 0.8, -0.6, 3.75), 0.2, 0.06, (0, -1, 0)), "UpperTorso", "leather")
        P(band((sx * 0.8, -0.6, 3.75), (sx * 0.74, 0.62, 4.1), 0.2, 0.06, (0, 0, 1)), "UpperTorso", "leather")
    for z in (2.24, 4.6):
        P(sf.box((1.51, 0.11, 0.11), loc=(0, 0.74, z), bevel=0.0), "UpperTorso", "steel")
    P(sf.box((1.5, 0.95, 1.05), loc=(0, 1.27, 3.0), bevel=0.06, segments=1), "UpperTorso", "pine")
    for z in (2.68, 3.32):
        P(sf.box((1.54, 0.99, 0.1), loc=(0, 1.27, z), bevel=0.0), "UpperTorso", "walnut")
    P(sf.box((0.6, 0.05, 0.32), loc=(0.3, 1.77, 3.0), bevel=0.0), "UpperTorso", "hazard")
    P(sf.box((0.5, 0.06, 0.1), loc=(0.3, 1.79, 3.0), bevel=0.0), "UpperTorso", "rubber")
    P(sf.cyl(0.38, 1.95, loc=(0, 1.15, 3.96), rot=(0, 90, 0), verts=14, bevel=0.05, segments=1), "UpperTorso", "rust")
    P(sf.cyl(0.24, 1.97, loc=(0, 1.15, 3.96), rot=(0, 90, 0), verts=12, bevel=0.0), "UpperTorso", "cream")
    for x in (-0.62, 0.62):
        P(sf.torus(0.39, 0.05, loc=(x, 1.15, 3.96), rot=(0, 90, 0), major_segs=14, minor_segs=4), "UpperTorso", "leather")
    # lantern
    P(sf.torus(0.1, 0.025, loc=(-0.98, 0.78, 4.62), rot=(0, 90, 0), major_segs=8, minor_segs=3), "UpperTorso", "steel")
    P(sf.cyl(0.21, 0.08, loc=(-0.98, 0.78, 4.47), verts=10, radius_top=0.1, bevel=0.0), "UpperTorso", "gunmetal")
    P(sf.cyl(0.17, 0.32, loc=(-0.98, 0.78, 4.27), verts=10, bevel=0.0), "UpperTorso", "cream")
    for a in range(4):
        r = math.radians(a * 90 + 45)
        P(sf.box((0.04, 0.04, 0.34), loc=(-0.98 + math.cos(r) * 0.18, 0.78 + math.sin(r) * 0.18, 4.27), bevel=0.0),
          "UpperTorso", "hazard")
    P(sf.cyl(0.22, 0.08, loc=(-0.98, 0.78, 4.08), verts=10, bevel=0.0), "UpperTorso", "hazard")


def quartermaster_props(H):
    # the requisition clipboard, held up beside the face
    c = H.hand("Left", (0, -0.1, 0)) + Vector((0.05, -0.18, 0.46))
    rot = _rot_toward_camera(CAM_YAW + 18, 8)
    board = sf.box((0.8, 0.07, 1.05), loc=c, rot=rot, bevel=0.03, segments=1)
    H.prop("Left", board, "pine")
    m = Euler([math.radians(a) for a in rot]).to_matrix()
    f = m @ Vector((0, -1, 0))

    def on(dx, dz, out):
        return c + m @ Vector((dx, 0, dz)) + f * out
    H.prop("Left", sf.box((0.66, 0.03, 0.84), loc=on(0, -0.05, 0.045), rot=rot, bevel=0.0), "porcelain")
    H.prop("Left", sf.box((0.66, 0.03, 0.16), loc=on(0, 0.28, 0.065), rot=rot, bevel=0.0), "hazard")
    for i in range(4):
        H.prop("Left", sf.box((0.5 - (i % 2) * 0.14, 0.02, 0.035), loc=on(-0.06 - (i % 2) * 0.07, 0.08 - i * 0.13, 0.065),
                              rot=rot, bevel=0.0), "stone")
    H.prop("Left", sf.box((0.34, 0.08, 0.12), loc=on(0, 0.5, 0.05), rot=rot, bevel=0.02, segments=1), "steel")


# ------------------------------------------------------------------------------------------
# Epic: Warden
# ------------------------------------------------------------------------------------------

def warden():
    recolor(LEGS, "rust", "navy")
    short_hair("#8A8680")
    bare_chest()
    # a clipped grey moustache, waxed out at the ends
    for sx in (-1, 1):
        P(sf.box((0.32, 0.11, 0.12), loc=(sx * 0.15, -0.68, 4.55), rot=(0, sx * -14, 0), bevel=0.04, segments=1),
          "Head", sf.TINT, role="Hair", tint="#8A8680")
    # greatcoat: body, double-breasted front with brass buttons, navy lapels, a wide belt
    P(sf.box((2.2, 1.22, 1.62), loc=(0, 0, 3.17), bevel=0.2, segments=2), "UpperTorso", "rust")
    long_sleeves("rust", "brass")
    for sx in (-1, 1):
        P(flat([(sx * 0.05, 3.94), (sx * 0.66, 3.94), (sx * 0.3, 3.0)], 0.06, -0.63), "UpperTorso", "navy")
        for z in (3.42, 3.1, 2.78):
            P(sf.sphere(0.075, loc=(sx * 0.3, -0.66, z), segs=8, rings=5), "UpperTorso", "brass")
    P(sf.box((2.24, 1.3, 0.24), loc=(0, 0, 2.42), bevel=0.04, segments=1), "LowerTorso", "rubber")
    P(sf.box((0.4, 0.08, 0.3), loc=(0, -0.67, 2.42), bevel=0.03, segments=1), "LowerTorso", "brass")
    P(band((0.86, -0.64, 3.9), (-0.86, -0.64, 2.5), 0.17, 0.05, (0, -1, 0)), "UpperTorso", "rubber")
    # skirts flare over the legs: front panels part at the middle, a back vent
    for sx in (-1, 1):
        P(sf.box((0.94, 0.13, 1.6), loc=(sx * 0.53, -0.62, 1.56), rot=(8, sx * -4, 0), bevel=0.04, segments=1), "LowerTorso", "rust")
        P(sf.box((0.13, 1.12, 1.6), loc=(sx * 1.04, 0.02, 1.56), rot=(0, sx * 7, 0), bevel=0.04, segments=1), "LowerTorso", "rust")
        P(sf.box((0.96, 0.13, 1.65), loc=(sx * 0.52, 0.63, 1.54), rot=(-8, sx * 3, 0), bevel=0.04, segments=1), "LowerTorso", "rust")
    # high navy collar with a brass edge
    P(sf.cyl(0.56, 0.36, loc=(0, 0.04, 4.08), verts=16, radius_top=0.6, bevel=0.03, segments=1), "UpperTorso", "navy")
    P(sf.torus(0.6, 0.035, loc=(0, 0.04, 4.26), major_segs=16, minor_segs=4), "UpperTorso", "brass")
    # a cloak falls from the collar to the knees behind him: the silhouette nobody else has
    P(open_shell(1.5, 1.02, 2.95, 2.62, 0.4, thick=0.08, y_scale=0.62), "UpperTorso", "rust")
    P(open_shell(1.53, 1.5, 0.12, 1.2, 0.4, thick=0.06, y_scale=0.63), "UpperTorso", "brass")
    for sx in (-1, 1):
        P(sf.sphere(0.11, loc=(sx * 0.62, 0.52, 4.08), segs=8, rings=4), "UpperTorso", "brass")
    P(rod((-0.56, -0.5, 3.98), (0.56, -0.5, 3.98), 0.03, 6), "UpperTorso", "brass")
    # fringed brass epaulettes
    for sx, bone in ((1, "LeftUpperArm"), (-1, "RightUpperArm")):
        P(sf.cyl(0.4, 0.1, loc=(sx * 1.38, 0.0, 4.02), rot=(0, sx * -20, 0), verts=16, bevel=0.03, segments=1), bone, "brass")
        P(sf.cyl(0.28, 0.1, loc=(sx * 1.39, 0.0, 4.07), rot=(0, sx * -20, 0), verts=14, bevel=0.0), bone, "navy")
        P(flat(star_xz(0, 0, 0.12, 0.05), 0.04, 0), bone, "brass").location = (sx * 1.4, 0.0, 4.12)
        for i in range(8):
            yy = -0.31 + i * 0.088
            P(rod((sx * 1.74, yy, 3.92), (sx * 1.8, yy, 3.56), 0.036, 5), bone, "brass")
    # the Steadfast Star: a brass star with a glowing heart, on a teal-and-rust ribbon
    P(sf.box((0.44, 0.05, 0.16), loc=(0.58, -0.65, 3.76), bevel=0.0), "UpperTorso", "teal")
    P(sf.box((0.12, 0.06, 0.16), loc=(0.58, -0.655, 3.76), bevel=0.0), "UpperTorso", "rust")
    P(band((0.58, -0.64, 3.68), (0.58, -0.64, 3.55), 0.1, 0.04), "UpperTorso", "teal")
    P(flat(star_xz(0.58, 3.38, 0.22, 0.1), 0.07, -0.66), "UpperTorso", "brass")
    glow(sf.sphere(0.075, loc=(0.58, -0.7, 3.38), segs=10, rings=5), "UpperTorso")
    # the bunker keys
    P(sf.torus(0.14, 0.03, loc=(0.94, -0.56, 2.24), rot=(90, 0, 0), major_segs=10, minor_segs=4), "LowerTorso", "brass")
    for i in range(3):
        P(sf.box((0.06, 0.03, 0.26), loc=(0.87 + i * 0.07, -0.58, 2.04), rot=(0, (i - 1) * 18, 0), bevel=0.0), "LowerTorso", "steel")
    # peaked officer's cap: navy band, rust crown flaring wide, black visor, brass cord and badge
    P(sf.cyl(0.74, 0.24, loc=(0, 0.02, 5.48), verts=22, bevel=0.0), "Head", "navy")
    P(sf.cyl(0.78, 0.26, loc=(0, 0.06, 5.72), verts=22, radius_top=0.96, bevel=0.06, segments=1), "Head", "rust")
    P(sf.cyl(0.96, 0.06, loc=(0, 0.06, 5.87), verts=22, bevel=0.03, segments=1), "Head", "rust")
    P(sf.box((1.16, 0.56, 0.06), loc=(0, -0.74, 5.38), rot=(14, 0, 0), bevel=0.03, segments=1), "Head", "rubber")
    P(sf.box((1.14, 0.05, 0.05), loc=(0, -0.76, 5.5), bevel=0.0), "Head", "brass")
    P(flat(star_xz(0, 5.66, 0.16, 0.07), 0.05, -0.8), "Head", "brass")


def warden_props(H):
    # the Rally Call megaphone at his mouth, bell turned out to his right; the right hand
    # holds its pistol grip
    mouth = H.at("Head", (0.0, -0.74, 4.5))
    out = (H.m("Head").to_3x3() @ Vector((-0.92, -0.34, 0.12))).normalized()
    up = Vector((0, 0, 1))
    side = out.cross(up).normalized()
    up = side.cross(out).normalized()
    grip_top = mouth + out * 0.42 - up * 0.14
    grip_bot = grip_top - up * 0.42 + out * 0.08
    H.reach("Right", grip_top.lerp(grip_bot, 0.5) - side * 0.02)
    neck, bell = mouth + out * 0.1, mouth + out * 1.3
    H.prop("Right", rod(neck, bell, 0.13, 16, r_end=0.46), "chrome")
    H.prop("Right", rod(bell - out * 0.02, bell + out * 0.1, 0.48, 16), "signal")
    H.prop("Right", rod(mouth - out * 0.05, neck + out * 0.04, 0.15, 12), "rubber")
    H.prop("Right", rod(grip_top, grip_bot, 0.1, 8), "rubber")
    H.prop("Right", rod(grip_top + out * 0.12 - up * 0.04, grip_top + out * 0.12 - up * 0.2, 0.035, 6), "steel")
    H.prop("Right", rod(neck + out * 0.55 + up * 0.25, neck + out * 0.95 + up * 0.4, 0.03, 6), "steel")
    H.prop("Right", rod(neck + out * 0.62 - up * 0.02, neck + out * 0.66 - up * 0.02, 0.29, 14), "hazard")


# ------------------------------------------------------------------------------------------
# Legendary: Mad Scientist
# ------------------------------------------------------------------------------------------

HAIR_WHITE = "#ECE9E1"
TUFTS = [   # (base, bend, tip, base radius): wild hair swept out and back from the sides,
            # the back and the crown, each tuft bent once
    ((0.62, -0.1, 5.2), (0.95, -0.16, 5.46), (1.28, -0.02, 5.86), 0.25),
    ((0.64, 0.12, 5.02), (1.0, 0.14, 5.1), (1.46, 0.32, 5.3), 0.27),
    ((0.6, 0.35, 5.28), (0.9, 0.56, 5.55), (1.04, 0.98, 5.95), 0.25),
    ((0.64, 0.05, 4.86), (0.95, 0.06, 4.8), (1.24, 0.22, 4.6), 0.21),
    ((0.6, 0.45, 4.96), (0.92, 0.72, 4.98), (1.14, 1.06, 4.86), 0.23),
    ((-0.62, -0.08, 5.24), (-0.98, -0.12, 5.52), (-1.36, 0.02, 5.94), 0.25),
    ((-0.64, 0.14, 5.0), (-1.04, 0.18, 5.06), (-1.5, 0.36, 5.2), 0.27),
    ((-0.6, 0.36, 5.3), (-0.88, 0.6, 5.62), (-0.98, 1.04, 6.02), 0.25),
    ((-0.64, 0.02, 4.84), (-0.98, 0.02, 4.76), (-1.28, 0.18, 4.52), 0.21),
    ((-0.6, 0.46, 4.98), (-0.94, 0.76, 5.0), (-1.2, 1.1, 4.92), 0.23),
    ((0.25, 0.55, 5.28), (0.36, 0.9, 5.5), (0.44, 1.26, 5.86), 0.26),
    ((-0.22, 0.55, 5.32), (-0.3, 0.88, 5.62), (-0.36, 1.16, 6.02), 0.26),
    ((0.0, 0.58, 5.02), (0.02, 0.96, 5.06), (0.1, 1.32, 4.94), 0.25),
    ((0.24, 0.12, 5.5), (0.32, 0.18, 5.82), (0.54, -0.02, 6.06), 0.21),
    ((-0.2, 0.26, 5.5), (-0.32, 0.36, 5.86), (-0.22, 0.62, 6.12), 0.21),
]


def tuft(base, bend, tip, r):
    """A bent tuft of hair: a tapering root to the bend, then a cone to the tip."""
    return [rod(base, bend, r, 6, r_end=r * 0.62), rod(bend, tip, r * 0.62, 6, r_end=0.02),
            sf.sphere(r * 0.62, loc=bend, segs=6, rings=3)]


def mad_scientist():
    recolor(LEGS, "porcelain", "gunmetal")
    drop(lambda o: o.get("sf_role") == "Hair")
    bare_chest()
    # wild white hair: a fluffed crown, tufts in every direction, a walrus moustache
    P(sf.sphere(0.74, loc=(0, 0.1, 5.3), scale=(1.0, 0.98, 0.55), segs=14, rings=7), "Head", sf.TINT, role="Hair", tint=HAIR_WHITE)
    for base, bend, tip, r in TUFTS:
        for piece in tuft(base, bend, tip, r):
            P(piece, "Head", sf.TINT, role="Hair", tint=HAIR_WHITE)
    P(sf.sphere(0.3, loc=(0, -0.7, 4.52), scale=(1.55, 0.5, 0.5), segs=12, rings=6), "Head", sf.TINT, role="Hair", tint=HAIR_WHITE)
    for sx in (-1, 1):
        P(spike((sx * 0.3, -0.7, 4.52), (sx * 0.66, -0.66, 4.38), 0.13), "Head", sf.TINT, role="Hair", tint=HAIR_WHITE)
    # brass goggles pushed up on the forehead, lenses glowing Source-green
    P(sf.box((1.42, 1.34, 0.13), loc=(0, -0.02, 5.36), bevel=0.06, segments=1), "Head", "leather")
    P(sf.box((0.24, 0.12, 0.12), loc=(0, -0.72, 5.36), bevel=0.02, segments=1), "Head", "brass")
    for sx in (-1, 1):
        P(sf.cyl(0.26, 0.22, loc=(sx * 0.33, -0.74, 5.38), rot=(68, 0, 0), verts=14, bevel=0.03, segments=1), "Head", "brass")
        glow(sf.cyl(0.19, 0.06, loc=(sx * 0.33, -0.85, 5.42), rot=(68, 0, 0), verts=14, bevel=0.0), "Head")
    # lab coat: cream lapels, a high collar, an orange bow tie, glowing test tubes in the pocket
    for sx in (-1, 1):
        P(flat([(sx * 0.07, 3.96), (sx * 0.68, 3.96), (sx * 0.26, 2.92)], 0.06, -0.58), "UpperTorso", "cream")
    P(sf.cyl(0.56, 0.32, loc=(0, 0.06, 4.05), verts=16, radius_top=0.62, bevel=0.03, segments=1), "UpperTorso", "porcelain")
    for sx in (-1, 1):
        P(flat([(0, 3.86), (sx * 0.27, 4.0), (sx * 0.27, 3.72)], 0.08, -0.66), "UpperTorso", "signal")
    P(sf.box((0.12, 0.1, 0.13), loc=(0, -0.67, 3.86), bevel=0.0), "UpperTorso", "signal")
    P(sf.box((0.5, 0.06, 0.32), loc=(0.56, -0.6, 3.28), bevel=0.02, segments=1), "UpperTorso", "cream")
    for x, sw, h in ((0.42, "glow", 0.5), (0.56, "hazard", 0.42), (0.7, "crystal", 0.48)):
        P(sf.cyl(0.06, h, loc=(x, -0.63, 3.3 + h / 2), verts=8, bevel=0.0), "UpperTorso", "chrome")
        glow(sf.cyl(0.05, h * 0.6, loc=(x, -0.63, 3.3 + h * 0.3), verts=8, bevel=0.0), "UpperTorso", sw)
        P(sf.cyl(0.065, 0.07, loc=(x, -0.63, 3.31 + h), verts=8, bevel=0.0), "UpperTorso", "walnut")
    for sx in (-1, 1):                 # long coat tails, split at the back
        P(sf.box((0.92, 0.12, 1.95), loc=(sx * 0.5, -0.6, 1.42), rot=(7, sx * -3, 0), bevel=0.04, segments=1), "LowerTorso", "porcelain")
        P(sf.box((0.12, 1.1, 1.95), loc=(sx * 1.0, 0.04, 1.42), rot=(0, sx * 6, 0), bevel=0.04, segments=1), "LowerTorso", "porcelain")
        P(sf.box((0.95, 0.12, 2.0), loc=(sx * 0.5, 0.62, 1.4), rot=(-10, sx * 5, 0), bevel=0.04, segments=1), "LowerTorso", "porcelain")
    # the Gadget Belt: Shock Trap, Teleport Beacon and Gravity Well
    P(sf.box((2.06, 1.18, 0.2), loc=(0, 0, 2.4), bevel=0.04, segments=1), "LowerTorso", "leather")
    P(sf.cyl(0.26, 0.1, loc=(1.06, -0.2, 2.3), rot=(0, 90, 0), verts=12, bevel=0.0), "LowerTorso", "gunmetal")
    P(sf.torus(0.2, 0.035, loc=(1.12, -0.2, 2.3), rot=(0, 90, 0), major_segs=12, minor_segs=3), "LowerTorso", "hazard")
    P(sf.cyl(0.11, 0.42, loc=(-0.62, -0.66, 2.36), verts=8, bevel=0.0), "LowerTorso", "chrome")
    glow(sf.sphere(0.08, loc=(-0.62, -0.66, 2.62), segs=8, rings=4), "LowerTorso", "crystal")
    P(sf.sphere(0.2, loc=(-1.05, 0.3, 2.3), segs=12, rings=6), "LowerTorso", "plum")
    glow(sf.torus(0.21, 0.03, loc=(-1.05, 0.3, 2.3), rot=(0, 90, 20), major_segs=12, minor_segs=3), "LowerTorso", "crystal")
    long_sleeves("porcelain", "cream", ("Left",))
    # orange rubber glove on the left hand
    P(sf.box((0.56, 0.62, 0.56), loc=(1.53, -0.02, 1.98), bevel=0.16, segments=1), "LeftHand", "signal")
    P(sf.cyl(0.35, 0.16, loc=(1.51, -0.01, 2.27), verts=10, radius_top=0.39, bevel=0.0), "LeftHand", "signal")
    # the mechanical right arm: a riveted brass pauldron, a forearm wound with copper coils
    # round a glowing core, and a chrome three-finger claw
    drop(lambda o: o.get("sf_part") in ("RightLowerArm", "RightHand"))
    P(sf.sphere(0.56, loc=(-1.5, 0, 3.78), scale=(1, 1, 0.72), segs=12, rings=6), "RightUpperArm", "brass")
    for a in range(5):
        r = math.radians(-60 + a * 30)
        P(sf.sphere(0.05, loc=(-1.5 + math.sin(r) * -0.5, -math.cos(r) * 0.36, 3.86), segs=6, rings=3), "RightUpperArm", "copper")
    P(sf.cyl(0.36, 0.84, loc=(-1.5, 0, 2.58), verts=10, radius_top=0.42, bevel=0.03, segments=1), "RightLowerArm", "brass")
    for z in (2.32, 2.52, 2.72):
        P(sf.torus(0.42, 0.055, loc=(-1.5, 0, z), major_segs=12, minor_segs=4), "RightLowerArm", "copper")
    glow(sf.cyl(0.15, 0.3, loc=(-1.5, -0.39, 2.52), rot=(90, 0, 0), verts=8, bevel=0.0), "RightLowerArm")
    P(sf.sphere(0.3, loc=(-1.53, 0, 2.06), segs=10, rings=5), "RightHand", "gunmetal")
    for a in (90, 210, 330):
        ra = math.radians(a)
        base = Vector((-1.53 + math.cos(ra) * 0.17, math.sin(ra) * 0.17, 1.9))
        mid = base + Vector((math.cos(ra) * 0.16, math.sin(ra) * 0.16, -0.28))
        tip = mid + Vector((-math.cos(ra) * 0.1, -math.sin(ra) * 0.1, -0.2))
        P(rod(base, mid, 0.06, 6), "RightHand", "chrome")
        P(spike(mid, tip, 0.06, 5), "RightHand", "chrome")
    # the Glowshard reactor pack
    P(sf.cyl(0.54, 0.5, loc=(0, 0.98, 2.72), verts=14, bevel=0.04, segments=1), "UpperTorso", "brass")
    glow(sf.cyl(0.44, 0.78, loc=(0, 0.98, 3.36), verts=14, bevel=0.0), "UpperTorso")
    for z in (3.05, 3.67):
        P(sf.torus(0.5, 0.05, loc=(0, 0.98, z), major_segs=14, minor_segs=4), "UpperTorso", "chrome")
    for th in range(6):
        a = math.radians(th * 60 + 30)
        P(sf.box((0.06, 0.06, 0.66), loc=(math.cos(a) * 0.49, 0.98 + math.sin(a) * 0.49, 3.36), bevel=0.0), "UpperTorso", "chrome")
    P(sf.cyl(0.54, 0.4, loc=(0, 0.98, 3.95), verts=14, radius_top=0.3, bevel=0.04, segments=1), "UpperTorso", "brass")
    for sx in (-1, 1):                 # copper pressure tanks rising over the shoulders
        top = Vector((sx * 0.95, 0.86, 4.5))
        P(rod((sx * 0.62, 0.92, 2.7), top, 0.22, 10), "UpperTorso", "copper")
        P(sf.sphere(0.22, loc=top, segs=10, rings=5), "UpperTorso", "copper")
        P(sf.cyl(0.07, 0.16, loc=top + Vector((0, 0, 0.26)), verts=8, bevel=0.0), "UpperTorso", "brass")
        P(sf.cyl(0.1, 0.06, loc=top + Vector((0, 0, 0.36)), verts=8, bevel=0.0), "UpperTorso", "signal")
        P(sf.torus(0.23, 0.04, loc=top + Vector((0, 0, -0.45)), rot=(0, sx * 13, 0), major_segs=10, minor_segs=3), "UpperTorso", "brass")
    # Tesla coil above his head, with prongs the arcs jump to
    P(rod((0, 0.98, 4.12), (0, 0.98, 6.0), 0.07, 8), "UpperTorso", "steel")
    for i in range(9):
        P(sf.torus(0.2 - i * 0.01, 0.045, loc=(0, 0.98, 4.4 + i * 0.16), major_segs=12, minor_segs=3), "UpperTorso", "copper")
    P(sf.torus(0.3, 0.09, loc=(0, 0.98, 6.0), major_segs=16, minor_segs=6), "UpperTorso", "chrome")
    P(sf.sphere(0.2, loc=(0, 0.98, 6.06), segs=12, rings=6), "UpperTorso", "chrome")
    prongs = []
    for sx in (-1, 1):
        tip = Vector((sx * 1.22, 0.98, 5.56))
        P(rod((sx * 0.5, 0.98, 4.12), tip, 0.04, 6), "UpperTorso", "steel")
        P(sf.sphere(0.1, loc=tip, segs=8, rings=4), "UpperTorso", "chrome")
        prongs.append(tip)
    # live arcs, ball to prong, in jagged Neon segments
    for tip, jag in zip(prongs, ([0.1, -0.12, 0.14, -0.06], [-0.12, 0.1, -0.1, 0.08])):
        a = Vector((0, 0.98, 6.0))
        pts = [a]
        for i, j in enumerate(jag, 1):
            t = i / (len(jag) + 1)
            p = a.lerp(tip, t)
            pts.append(p + Vector((0, 0, j)))
        pts.append(tip)
        for p0, p1 in zip(pts, pts[1:]):
            glow(rod(p0, p1, 0.035, 4), "UpperTorso", "crystal")
    # a cable from the pack into the mechanical arm
    cable = [(-0.5, 0.95, 2.95), (-1.05, 0.72, 3.1), (-1.5, 0.42, 3.06), (-1.62, 0.24, 2.82)]
    for p0, p1 in zip(cable, cable[1:]):
        P(rod(p0, p1, 0.075, 8), "UpperTorso", "rubber")


def mad_scientist_props(H):
    # EUREKA: a round flask held up on his fingertips, glowing, bubbles boiling out of it
    hand = H.hand("Left")
    bulb = hand + Vector((-0.04, -0.1, 0.62))
    neck_top = bulb + Vector((0.0, 0.0, 0.78))
    H.glow("Left", sf.sphere(0.4, loc=bulb, segs=18, rings=9))
    H.prop("Left", sf.torus(0.4, 0.035, loc=bulb, rot=(12, 0, 0), major_segs=18, minor_segs=4), "chrome")
    H.prop("Left", rod(bulb + Vector((0, 0, 0.3)), neck_top, 0.1, 10), "chrome")
    H.prop("Left", sf.cyl(0.14, 0.06, loc=neck_top, verts=10, bevel=0.0), "chrome")
    for off, r in (((0.08, 0.0, 0.18), 0.09), ((-0.1, -0.04, 0.42), 0.07), ((0.04, 0.02, 0.62), 0.05),
                   ((0.16, -0.02, 0.8), 0.04)):
        H.glow("Left", sf.sphere(r, loc=neck_top + Vector(off), segs=8, rings=4))


# ------------------------------------------------------------------------------------------
# The table the portrait script and the cosmetics work read
# ------------------------------------------------------------------------------------------

OUTFITS = {
    "Security": {
        "rarity": "Common", "base": "navy", "skin": "#8D5A3B", "hair": "#1E1A17",
        "build": security, "props": None,
        "pose": {"LeftUpperArm": (-8, 0, 14), "RightUpperArm": (-6, 0, -14), "LeftLowerArm": (-28, 0, 0),
                 "RightLowerArm": (-22, 0, 0), "Head": (0, -6, 4), "UpperTorso": (0, -4, 0)},
        "framing": (4.42, 1.74),
    },
    "Quartermaster": {
        "rarity": "Rare", "base": "olive", "skin": "#E0AC86", "hair": "#A0522D",
        "build": quartermaster, "props": quartermaster_props,
        "pose": {"LeftUpperArm": (-38, -30, 0), "LeftLowerArm": (-112, 0, 0), "LeftHand": (0, 0, -20),
                 "RightUpperArm": (-6, 0, -10), "RightLowerArm": (-30, 0, 0),
                 "Head": (-4, 8, 10), "UpperTorso": (0, 4, -4)},
        "framing": (4.5, 1.8),
    },
    "Warden": {
        "rarity": "Epic", "base": "rust", "skin": "#C58F6A", "hair": "#8A8680",
        "build": warden, "props": warden_props,
        "pose": {"RightUpperArm": (-58, 20, 6), "RightLowerArm": (-70, 0, 0),
                 "LeftUpperArm": (-2, 0, 12), "LeftLowerArm": (-30, 0, 0),
                 "Head": (-6, 0, -14), "UpperTorso": (0, 0, -6)},
        "framing": (4.55, 1.85),
    },
    "MadScientist": {
        "rarity": "Legendary", "base": "porcelain", "skin": "#F1C7A5", "hair": HAIR_WHITE,
        "build": mad_scientist, "props": mad_scientist_props,
        "pose": {"LeftUpperArm": (-50, -46, 0), "LeftLowerArm": (-96, 0, 0),
                 "RightUpperArm": (-40, 26, 0), "RightLowerArm": (-60, 0, 0),
                 "Head": (-10, 10, 16), "UpperTorso": (0, 6, 0)},
        "framing": (4.75, 1.95),
    },
}
