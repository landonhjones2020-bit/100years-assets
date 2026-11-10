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

All 19 classes have a look (Prompt 21): the free Survivor is the coveralls as issued; the
Commons add a trade's outfit; the Rares a signature piece each (the Radio Operator's field set,
the Hazmat Tech's suit, the Exterminator's tanks, the Driller's lamp helmet, the Scavenger's
pack); the Epics a new silhouette (the Demolitionist's blast collar, the Spelunker's pack of
glowshards); the Tinkerer is the second Legendary (arms of his own making, his drone).

OUTFITS[name] holds the base outfit swatch and preview skin and hair (set on Resident_Common
before build()), the worn pieces ("build"), and the class card's pose, held props and
framing (used by generators/UI/UI_Portraits.py; framing is (height, half height[, shift to
image right])). Held props are card-only: in a run the hands hold the player's tools. A class
holds its real item on its card: item() and held_item() build the model the game uses
(generators/Weapons, generators/Props), so the card and the hotbar icon show the same thing.

Place a piece before binding it: P(), glow() and Body.prop() parent it to a bone, and a
location set afterwards is in that bone's space (flat_at() places a slab in one go).

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
# Pieces the other class looks share
# ------------------------------------------------------------------------------------------

def squash(o, sx=1.0, sy=1.0, sz=1.0):
    """Scale a fresh primitive's vertices (before its bevel is applied)."""
    for v in o.data.vertices:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    return o


def hair(obj, colour):
    return P(obj, "Head", sf.TINT, role="Hair", tint=colour)


def dome(swatch, r=0.82, z=5.4, flat_=0.7, deep=1.06, y=0.02, verts=18):
    """The crown of a helmet or a cap: half a ball standing on z and closed underneath, so
    none of it shows below the brim."""
    h = r * flat_
    prof = [(r * math.cos(math.radians(a)), h * math.sin(math.radians(a))) for a in (0, 15, 30, 45, 60, 75)] + [(0.0, h)]
    return P(squash(sf.lathe(prof, verts=verts, loc=(0, y, z)), sy=deep), "Head", swatch)


def flat_at(points_xz, thick, centre, yaw=0.0, bevel=0.012):
    """A slab from an outline (x across, z up) standing at `centre` and turned `yaw` about Z
    (0 faces the front, 90 a side). Place a piece BEFORE binding it: P() parents it to its
    bone, and a location set afterwards is in the bone's space."""
    a = math.radians(yaw)
    c = Vector(centre) + Vector((-math.sin(a), math.cos(a), 0.0)) * (thick / 2)
    return sf.profile_slab(points_xz, thick, loc=tuple(c), rot=(90, 0, yaw), bevel=bevel, segments=1)


def crest(swatch, r=0.82, z=5.4, flat_=0.7, deep=1.06, y=0.02, width=0.18, lift=0.04, yaw=90.0):
    """A stripe over a dome() of the same numbers, front to back (yaw 90) or side to side
    (yaw 0); with more lift, a comb."""
    a = r * (deep if abs(yaw) > 45 else 1.0) + lift
    h = r * flat_ + lift
    pts = [(a * math.cos(math.radians(t)), h * math.sin(math.radians(t))) for t in range(0, 181, 15)]
    return P(flat_at(pts, width, (0, y, z), yaw=yaw), "Head", swatch)


def arc_wall(r, thick, a0, a1, height, n=8, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
    """Part of a cylinder's wall from angle a0 to a1 (degrees; 270 is the front), `height`
    tall and centred on loc: a visor, a collar."""
    def ring(rad, frm, to):
        return [(rad * math.cos(math.radians(frm + (to - frm) * i / n)), rad * math.sin(math.radians(frm + (to - frm) * i / n))) for i in range(n + 1)]
    o = sf.profile_slab(ring(r + thick, a0, a1) + ring(r, a1, a0), height, bevel=bevel, segments=1)
    for v in o.data.vertices:
        v.co.z -= height / 2
    o.location, o.rotation_euler = loc, [math.radians(d) for d in rot]
    return o


def visor(swatch, frame, pivot=(0, 0.02, 5.3), r=0.86, tilt=55.0, height=0.6, a0=205, a1=335, bone="Head"):
    """A face shield pushed up over a helmet: it turns about the ears' line."""
    rx = Matrix.Rotation(math.radians(-tilt), 3, "X")
    P(arc_wall(r, 0.05, a0, a1, height, loc=pivot, rot=(-tilt, 0, 0)), bone, swatch)
    for dz, h in ((-height / 2, 0.1), (height / 2, 0.06)):
        P(arc_wall(r - 0.012, 0.085, a0, a1, h, loc=tuple(Vector(pivot) + rx @ Vector((0, 0, dz))), rot=(-tilt, 0, 0)), bone, frame)


def brim(swatch, r=0.98, z=5.36, deep=1.0, y=0.02, thick=0.07):
    return P(squash(sf.cyl(r, thick, loc=(0, y, z), verts=22, bevel=0.02, segments=1), sy=deep), "Head", swatch)


def peak(swatch, z=5.4, w=1.12, d=0.5, tilt=9.0, y=-0.74):
    """A cap's visor."""
    return P(sf.box((w, d, 0.07), loc=(0, y, z), rot=(tilt, 0, 0), bevel=0.03, segments=1), "Head", swatch)


def gloves(swatch, cuff=None):
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.box((0.57, 0.63, 0.58), loc=(sx * 1.53, -0.02, 1.98), bevel=0.16, segments=1), f"{side}Hand", swatch)
        P(sf.box((0.24, 0.24, 0.36), loc=(sx * 1.38, -0.3, 2.06), rot=(0, -12, 0), bevel=0.07, segments=1), f"{side}Hand", swatch)
        if cuff:
            P(sf.cyl(0.4, 0.22, loc=(sx * 1.5, 0, 2.32), verts=10, radius_top=0.44, bevel=0.02, segments=1), f"{side}LowerArm", cuff)


def neckerchief(swatch, knot=None):
    P(sf.torus(0.47, 0.11, loc=(0, 0.02, 4.02), major_segs=14, minor_segs=5), "UpperTorso", swatch)
    P(flat([(-0.42, 3.98), (0.42, 3.98), (0.0, 3.42)], 0.07, -0.6), "UpperTorso", swatch)
    if knot:
        P(sf.sphere(0.1, loc=(0, -0.62, 3.9), segs=8, rings=5), "UpperTorso", knot)


def moustache(colour, w=0.3, droop=14.0, z=4.52):
    for sx in (-1, 1):
        hair(sf.box((w, 0.12, 0.14), loc=(sx * (w / 2 - 0.01), -0.68, z), rot=(0, sx * -droop, 0), bevel=0.05, segments=1), colour)


def goggles(z=5.3, y=-0.68, frame="rubber", lens="navy", r=0.21, gap=0.29, glowing=None, strap="leather", around=(1.42, 1.34)):
    """A pair of round goggles on the head: on the forehead or a hat at the default height, over the eyes at z 4.93."""
    if strap:
        P(sf.box((around[0], around[1], 0.12), loc=(0, -0.02, z), bevel=0.05, segments=1), "Head", strap)
    P(sf.box((0.2, 0.1, 0.1), loc=(0, y - 0.03, z), bevel=0.02, segments=1), "Head", frame)
    for sx in (-1, 1):
        P(sf.cyl(r, 0.2, loc=(sx * gap, y - 0.04, z), rot=(90, 0, 0), verts=12, bevel=0.03, segments=1), "Head", frame)
        lens_o = sf.cyl(r * 0.74, 0.06, loc=(sx * gap, y - 0.13, z), rot=(90, 0, 0), verts=12, bevel=0.0)
        if glowing:
            glow(lens_o, "Head", glowing)
        else:
            P(lens_o, "Head", lens)


def straps(swatch="leather", width=0.2, x=0.74):
    """A pack's shoulder straps, over the shoulders and down the chest."""
    for sx in (-1, 1):
        P(band((sx * x, -0.57, 2.7), (sx * (x + 0.06), -0.6, 3.78), width, 0.06, (0, -1, 0)), "UpperTorso", swatch)
        P(band((sx * (x + 0.06), -0.6, 3.78), (sx * x, 0.6, 4.06), width, 0.06, (0, 0, 1)), "UpperTorso", swatch)


def shin_bands(swatch, z=0.98, h=0.14):
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.box((0.86, 0.94, h), loc=(sx * 0.5, 0, z), bevel=0.02, segments=1), f"{side}LowerLeg", swatch)


def arm_bands(swatch, z=3.22, h=0.16):
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.cyl(0.47, h, loc=(sx * 1.5, 0, z), verts=10, bevel=0.02, segments=1), f"{side}UpperArm", swatch)


def held(H, side, obj, swatch, p0, p1, normal=None):
    """A prop built along local +Z, laid on p0 -> p1 and bound to that hand."""
    return H.prop(side, _aim(obj, p0, p1, normal), swatch)


CAM_RIGHT = Vector((math.cos(math.radians(CAM_YAW)), math.sin(math.radians(CAM_YAW)), 0.0))     # image right on the card
TO_CAM = Vector((math.sin(math.radians(CAM_YAW)), -math.cos(math.radians(CAM_YAW)), 0.0))       # from the resident to the card's camera
UP = Vector((0.0, 0.0, 1.0))


def item(module, at, forward, up, bone, part, glow_part, scale=1.0, grip=None, category="Weapons"):
    """An item's own model (generators/<category>/<module>.py: what the player holds in a
    run), worn or held: its pivot (the grip) at `at`, its front along `forward`, its top
    toward `up`, bound to `bone`. Returns the matrix from the model's space to the world (for
    a flame at its muzzle)."""
    import importlib
    import os
    import sys
    for d in ("Weapons", category):
        folder = os.path.join(sf.REPO, "generators", d)
        if folder not in sys.path:
            sys.path.insert(0, folder)
    W = importlib.import_module(module)
    before = set(bpy.context.scene.objects)
    W.build()
    f = Vector(forward).normalized()
    u = Vector(up)
    u = (u - f * u.dot(f)).normalized()
    turn = Matrix(((-f).cross(u), -f, u)).transposed().to_4x4()       # the model faces -Y, its top is +Z
    g = Vector(grip if grip is not None else getattr(W, "GRIP", (0, 0, 0)))
    M = Matrix.Translation(Vector(at)) @ turn @ Matrix.Diagonal((scale, scale, scale, 1.0)) @ Matrix.Translation(-g)
    bpy.context.view_layer.update()
    for o in [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]:
        o.matrix_world = M @ o.matrix_world
        o["sf_part"] = glow_part if o.get("sf_material") == "Neon" else part
        o["sf_collision"] = "none"
        if "sf_role" in o:
            del o["sf_role"]
        sf.bind(o, R.arm, bone)
    return M


def held_item(H, side, module, forward, up, off=(0, 0, 0), **kw):
    """An item's own model in a hand (card only)."""
    return item(module, H.hand(side) + Vector(off), forward, up, f"{side}Hand", f"Prop{side}Hand", f"PropGlow{side}Hand", **kw)


def flame(put, base, direction, length=0.7, r=0.14, outer="signal", core="hazard", sparks=(), spark=None):
    """A lit flame from `base`: a bright bulb and a tail. put(obj, swatch) binds each glowing
    piece; sparks are offsets from the flame's tip."""
    d = Vector(direction).normalized()
    base = Vector(base)
    put(sf.sphere(r * 1.1, loc=base + d * r * 0.7, segs=10, rings=6), core)
    put(rod(base + d * r, base + d * length, r, 8, r_end=0.012), outer)
    for i, off in enumerate(sparks):
        put(sf.sphere(0.055 - 0.012 * (i % 3), loc=base + d * length + Vector(off), segs=6, rings=3), spark or core)



# ------------------------------------------------------------------------------------------
# Free: Survivor
# ------------------------------------------------------------------------------------------

def survivor():
    # the Steadfast coveralls as issued, a red neckerchief, a canvas satchel on its strap
    neckerchief("rust", knot="rust")
    P(band((-0.86, -0.6, 3.86), (0.98, -0.58, 2.5), 0.2, 0.05, (0, -1, 0)), "UpperTorso", "leather")
    P(band((-0.86, 0.6, 3.86), (0.98, 0.58, 2.5), 0.2, 0.05, (0, 1, 0)), "UpperTorso", "leather")
    P(sf.box((0.5, 0.86, 0.72), loc=(1.22, 0.0, 2.08), bevel=0.08, segments=1), "LowerTorso", "sandstone")
    P(sf.box((0.54, 0.9, 0.3), loc=(1.22, 0.0, 2.34), bevel=0.06, segments=1), "LowerTorso", "stone")
    P(sf.box((0.06, 0.2, 0.2), loc=(1.5, 0.0, 2.26), bevel=0.02, segments=1), "LowerTorso", "brass")
    # sleeves rolled to the elbow, a pencil and a folded map in the chest pocket
    arm_bands("mint", z=3.0, h=0.24)
    P(sf.box((0.5, 0.06, 0.4), loc=(-0.47, -0.57, 3.3), bevel=0.02, segments=1), "UpperTorso", "teal")
    P(sf.box((0.3, 0.05, 0.3), loc=(-0.52, -0.6, 3.52), rot=(0, 8, 0), bevel=0.0), "UpperTorso", "cream")
    P(rod((-0.3, -0.6, 3.36), (-0.3, -0.6, 3.72), 0.035, 6), "UpperTorso", "hazard")


def survivor_props(H):
    # the Wrench every resident is issued, up and ready
    H.reach("Right", (-1.5, -0.72, 3.8))
    held_item(H, "Right", "Weapon_Wrench", UP - CAM_RIGHT * 0.1, CAM_RIGHT, scale=0.9)


# ------------------------------------------------------------------------------------------
# Common: Engineer, Medic, Firefighter, Cook, Scout
# ------------------------------------------------------------------------------------------

def engineer():
    short_hair("#3B2A1E")
    bare_chest()
    # hi-vis vest over grey coveralls
    P(sf.box((2.16, 1.16, 1.3), loc=(0, 0, 3.24), bevel=0.14, segments=2), "UpperTorso", "signal")
    for sx in (-1, 1):
        P(sf.box((0.2, 1.2, 1.32), loc=(sx * 0.58, 0, 3.24), bevel=0.04, segments=1), "UpperTorso", "cream")
    P(sf.box((2.2, 1.2, 0.16), loc=(0, 0, 2.86), bevel=0.03, segments=1), "UpperTorso", "cream")
    P(sf.box((0.07, 0.05, 1.3), loc=(0, -0.6, 3.24), bevel=0.0), "UpperTorso", "gunmetal")
    P(sf.box((0.44, 0.06, 0.36), loc=(-0.28, -0.62, 3.5), bevel=0.02, segments=1), "UpperTorso", "rust")
    for i, x in enumerate((-0.38, -0.28, -0.18)):
        P(rod((x, -0.64, 3.5), (x, -0.64, 3.78 + (i % 2) * 0.06), 0.03, 6), "UpperTorso", ("hazard", "steel", "teal")[i])
    # the tool belt: pouches, a hammer in its loop
    for x in (-0.6, 0.55):
        P(sf.box((0.5, 0.26, 0.5), loc=(x, -0.64, 2.1), bevel=0.06, segments=1), "LowerTorso", "leather")
        P(sf.box((0.52, 0.28, 0.14), loc=(x, -0.65, 2.3), bevel=0.03, segments=1), "LowerTorso", "walnut")
    P(rod((-1.06, -0.2, 2.5), (-1.06, -0.2, 1.7), 0.05, 6), "LowerTorso", "pine")
    P(sf.box((0.2, 0.46, 0.2), loc=(-1.06, -0.2, 2.56), bevel=0.03, segments=1), "LowerTorso", "steel")
    # hard hat with a lamp and a ridge
    dome("hazard", r=0.84, z=5.36, flat_=0.72)
    brim("hazard", r=0.96, z=5.32, deep=1.06, y=-0.04)
    crest("hazard", r=0.84, z=5.36, flat_=0.72, width=0.22, lift=0.06)
    P(sf.box((1.0, 0.5, 0.07), loc=(0, -0.86, 5.34), rot=(6, 0, 0), bevel=0.03, segments=1), "Head", "hazard")
    P(sf.cyl(0.2, 0.2, loc=(0, -0.86, 5.6), rot=(78, 0, 0), verts=10, bevel=0.03, segments=1), "Head", "gunmetal")
    glow(sf.cyl(0.15, 0.05, loc=(0, -0.97, 5.58), rot=(78, 0, 0), verts=10, bevel=0.0), "Head", "cream")
    gloves("leather", cuff="walnut")


def engineer_props(H):
    # the Welder, lit, and a roll of blueprints under the other arm
    H.reach("Right", (-1.3, -0.85, 3.7))
    f = (UP * 0.96 - CAM_RIGHT * 0.28).normalized()
    M = held_item(H, "Right", "Tool_Welder", f, -CAM_RIGHT, scale=0.9)
    flame(lambda o, sw: H.glow("Right", o, sw), M @ Vector((0.0, -1.8, 0.42)), f, length=0.6, r=0.11, outer="crystal", core="cream",
          sparks=((0.24, -0.1, 0.06), (-0.2, -0.2, -0.1), (0.12, -0.3, 0.26), (-0.3, 0.0, 0.16), (0.3, 0.1, -0.2)), spark="hazard")
    roll_a, roll_b = H.at("UpperTorso", (1.05, -0.9, 2.5)), H.at("UpperTorso", (1.25, 0.9, 3.0))
    H.prop("Left", rod(roll_a, roll_b, 0.2, 10), "skyblue")
    for q in (roll_a, roll_b):
        H.prop("Left", rod(q, q + (roll_b - roll_a).normalized() * 0.03, 0.14, 10), "porcelain")


def medic():
    short_hair("#7A4A2B")
    hair(sf.sphere(0.36, loc=(0, 0.52, 5.5), segs=12, rings=7), "#7A4A2B")           # a bun
    hair(sf.box((1.3, 0.34, 0.3), loc=(0, -0.5, 5.42), rot=(-12, 0, 0), bevel=0.12, segments=2), "#7A4A2B")   # a neat fringe
    bare_chest()
    # the white coat: lapels, mint buttons, a pocket of instruments
    P(sf.box((2.18, 1.18, 1.56), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "porcelain")
    long_sleeves("porcelain", "mint")
    for sx in (-1, 1):
        P(flat([(sx * 0.06, 3.94), (sx * 0.62, 3.94), (sx * 0.22, 3.22)], 0.06, -0.61), "UpperTorso", "cream")
    for z in (3.05, 2.75):
        P(sf.sphere(0.07, loc=(0.16, -0.62, z), segs=8, rings=5), "UpperTorso", "mint")
    P(sf.box((0.5, 0.06, 0.4), loc=(-0.52, -0.61, 3.3), bevel=0.02, segments=1), "UpperTorso", "cream")
    P(rod((-0.64, -0.63, 3.36), (-0.64, -0.63, 3.7), 0.03, 6), "UpperTorso", "rust")
    P(rod((-0.5, -0.63, 3.36), (-0.5, -0.63, 3.66), 0.03, 6), "UpperTorso", "chrome")
    P(sf.cyl(0.47, 0.3, loc=(1.5, 0, 3.36), verts=10, bevel=0.02, segments=1), "LeftUpperArm", "mint")
    for size in ((0.05, 0.3, 0.1), (0.05, 0.1, 0.3)):
        P(sf.box(size, loc=(1.98, 0, 3.36), bevel=0.0), "LeftUpperArm", "porcelain")
    # the stethoscope round the neck
    P(sf.torus(0.5, 0.05, loc=(0, 0.02, 4.0), major_segs=14, minor_segs=4), "UpperTorso", "rubber")
    for sx in (-1, 1):
        P(rod((sx * 0.4, -0.3, 4.0), (sx * 0.34, -0.63, 3.5), 0.045, 6), "UpperTorso", "rubber")
    P(rod((0.34, -0.63, 3.5), (0.36, -0.64, 3.12), 0.045, 6), "UpperTorso", "rubber")
    P(sf.cyl(0.14, 0.08, loc=(0.36, -0.67, 3.06), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), "UpperTorso", "chrome")
    P(rod((-0.34, -0.63, 3.5), (-0.34, -0.64, 3.3), 0.05, 6), "UpperTorso", "chrome")
    # the doctor's head mirror on its band
    P(sf.box((1.42, 1.34, 0.12), loc=(0, -0.02, 5.2), bevel=0.05, segments=1), "Head", "leather")
    P(sf.cyl(0.3, 0.06, loc=(0.16, -0.74, 5.34), rot=(72, 0, -8), verts=14, bevel=0.02, segments=1), "Head", "chrome")
    P(sf.cyl(0.07, 0.07, loc=(0.16, -0.76, 5.34), rot=(72, 0, -8), verts=8, bevel=0.0), "Head", "gunmetal")


def medic_props(H):
    # a Medkit, held up where the hurt can see it
    H.reach("Left", (1.12, -0.9, 3.5))
    held_item(H, "Left", "Item_Medkit", TO_CAM + CAM_RIGHT * 0.22, UP, off=(0.0, -0.06, 0.3), scale=1.12)


def firefighter():
    short_hair("#2A1E16")
    moustache("#2A1E16", w=0.36, droop=20)
    bare_chest()
    # turnout coat: reflective bands, brass clasps, a high collar
    P(sf.box((2.22, 1.22, 1.62), loc=(0, 0, 3.14), bevel=0.18, segments=2), "UpperTorso", "basalt")
    long_sleeves("basalt", "hazard")
    P(sf.box((2.26, 1.26, 0.26), loc=(0, 0, 2.78), bevel=0.03, segments=1), "UpperTorso", "hazard")
    P(sf.box((2.28, 1.28, 0.08), loc=(0, 0, 2.78), bevel=0.0), "UpperTorso", "chrome")
    arm_bands("hazard", z=3.2, h=0.22)
    P(sf.box((0.3, 0.07, 1.5), loc=(0, -0.62, 3.14), bevel=0.02, segments=1), "UpperTorso", "gunmetal")
    for z in (3.6, 3.2, 2.5):
        P(sf.box((0.5, 0.08, 0.14), loc=(0, -0.66, z), bevel=0.03, segments=1), "UpperTorso", "brass")
    P(sf.cyl(0.58, 0.4, loc=(0, 0.04, 4.06), verts=16, radius_top=0.64, bevel=0.03, segments=1), "UpperTorso", "basalt")
    P(sf.box((2.2, 1.2, 0.5), loc=(0, 0, 2.2), bevel=0.06, segments=1), "LowerTorso", "basalt")
    shin_bands("hazard")
    gloves("leather", cuff="basalt")
    # the helmet: red crown with ribs, a long back brim, a brass shield
    dome("rust", r=0.84, z=5.36, flat_=0.78)
    P(squash(sf.cyl(1.0, 0.07, loc=(0, 0.22, 5.3), verts=22, bevel=0.02, segments=1), sy=1.28), "Head", "rust")
    crest("rust", r=0.84, z=5.36, flat_=0.78, width=0.2, lift=0.1)
    crest("rust", r=0.84, z=5.36, flat_=0.78, width=0.12, lift=0.035, yaw=0)
    P(flat([(-0.26, 5.42), (0.26, 5.42), (0.3, 5.78), (0.0, 5.98), (-0.3, 5.78)], 0.07, -0.86), "Head", "brass")
    P(sf.box((0.26, 0.05, 0.2), loc=(0, -0.9, 5.66), bevel=0.0), "Head", "rust")
    for sx in (-1, 1):
        P(band((sx * 0.7, -0.2, 5.3), (sx * 0.62, -0.5, 4.3), 0.1, 0.04, (sx, 0, 0)), "Head", "leather")


def firefighter_props(H):
    # the Fire Axe, over the shoulder
    H.reach("Right", (-1.05, -0.8, 3.35))
    d = (UP * 0.8 - CAM_RIGHT * 0.34 - TO_CAM * 0.5).normalized()      # up, out and back over the shoulder
    held_item(H, "Right", "Weapon_FireAxe", d, CAM_RIGHT + UP * 0.3, scale=0.95)


def cook():
    short_hair("#1E1A17")
    moustache("#1E1A17", w=0.3, droop=-10, z=4.54)
    recolor(LEGS, "porcelain", "gunmetal")
    bare_chest()
    # double-breasted whites, two rows of buttons, a red neckerchief
    P(sf.box((2.18, 1.18, 1.56), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "porcelain")
    long_sleeves("porcelain", "porcelain")
    P(sf.box((1.0, 0.06, 1.3), loc=(0.1, -0.61, 3.1), bevel=0.03, segments=1), "UpperTorso", "cream")
    for sx in (-0.26, 0.46):
        for z in (3.5, 3.14, 2.78):
            P(sf.sphere(0.075, loc=(sx, -0.65, z), segs=8, rings=5), "UpperTorso", "navy")
    neckerchief("rust", knot="rust")
    # the apron, tied at the waist, a towel tucked in
    P(sf.box((2.04, 1.16, 0.12), loc=(0, 0, 2.46), bevel=0.02, segments=1), "LowerTorso", "cream")
    P(sf.box((1.7, 0.08, 1.3), loc=(0, -0.62, 1.86), rot=(4, 0, 0), bevel=0.03, segments=1), "LowerTorso", "cream")
    P(sf.box((0.4, 0.1, 0.7), loc=(-0.7, -0.68, 2.1), rot=(4, 0, 6), bevel=0.03, segments=1), "LowerTorso", "skyblue")
    # the toque: a band and a tall pleated crown
    P(sf.cyl(0.78, 0.36, loc=(0, 0.02, 5.5), verts=20, bevel=0.03, segments=1), "Head", "porcelain")
    P(sf.cyl(0.8, 0.9, loc=(0, 0.02, 6.05), verts=14, radius_top=0.98, bevel=0.0), "Head", "porcelain")
    P(sf.sphere(0.98, loc=(0, 0.02, 6.5), scale=(1, 1, 0.42), segs=14, rings=7), "Head", "porcelain")
    for i in range(14):
        a = math.radians(i * 360 / 14)
        P(rod((math.cos(a) * 0.81, 0.02 + math.sin(a) * 0.81, 5.66), (math.cos(a) * 0.98, 0.02 + math.sin(a) * 0.98, 6.46), 0.035, 4), "Head", "cream")


def cook_props(H):
    # a cast-iron pan, breakfast in it, and a pancake at the top of its flip
    H.reach("Left", (0.6, -1.0, 3.45))
    c = H.hand("Left")
    out = (CAM_RIGHT * 0.95 + TO_CAM * 0.25 + UP * 0.1).normalized()
    held(H, "Left", sf.cyl(0.085, 0.95, verts=8, bevel=0.0), "rubber", c - out * 0.25, c + out * 0.7)
    pan = c + out * 1.2
    n = (UP * 0.8 + TO_CAM * 0.6).normalized()                         # tipped toward us, to show what's in it
    e1, e2 = CAM_RIGHT, n.cross(CAM_RIGHT).normalized()
    held(H, "Left", sf.cyl(0.56, 0.06, verts=18, bevel=0.0), "gunmetal", pan - n * 0.03, pan + n * 0.03)
    H.prop("Left", _aim(sf.ring(0.5, 0.6, 0.22, verts=18), pan - n * 0.03, pan + n * 0.19), "rubber")
    egg = pan + e1 * -0.14 + e2 * 0.06 + n * 0.05
    H.prop("Left", _aim(squash(sf.sphere(0.2, segs=10, rings=6), 1.25, 1.0, 0.22), egg, egg + n * 0.01), "porcelain")
    H.prop("Left", sf.sphere(0.08, loc=egg + n * 0.05, segs=8, rings=5), "hazard")
    for i, (a, b) in enumerate(((0.2, 0.14), (0.26, -0.12))):
        q = pan + e1 * a + e2 * b + n * 0.06
        H.prop("Left", _aim(sf.box((0.12, 0.05, 0.4), bevel=0.02, segments=1), q - e2 * 0.2 + e1 * 0.05 * i, q + e2 * 0.2, n), "rust")
    cake = pan + UP * 1.3 - CAM_RIGHT * 0.1
    m = (UP * 0.55 + TO_CAM * 0.7 - CAM_RIGHT * 0.45).normalized()     # mid-turn
    held(H, "Left", sf.cyl(0.42, 0.1, verts=16, bevel=0.03, segments=1), "pine", cake - m * 0.05, cake + m * 0.05)
    held(H, "Left", sf.box((0.14, 0.14, 0.05), bevel=0.02, segments=1), "hazard", cake + m * 0.05, cake + m * 0.1)


def scout():
    short_hair("#C98A3C")
    bare_chest()
    # khaki shirt with two flapped pockets and shoulder tabs
    P(sf.box((2.16, 1.16, 1.54), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "pine")
    for sx in (-1, 1):
        P(sf.box((0.56, 0.06, 0.46), loc=(sx * 0.52, -0.6, 3.34), bevel=0.02, segments=1), "UpperTorso", "sandstone")
        P(flat([(sx * 0.24, 3.6), (sx * 0.8, 3.6), (sx * 0.52, 3.42)], 0.05, -0.63), "UpperTorso", "pine")
        P(sf.sphere(0.05, loc=(sx * 0.52, -0.66, 3.5), segs=6, rings=4), "UpperTorso", "brass")
        P(sf.box((0.5, 0.3, 0.06), loc=(sx * 1.2, 0, 3.96), rot=(0, sx * -10, 0), bevel=0.02, segments=1), "UpperTorso", "forest")
    P(sf.box((0.07, 0.05, 1.5), loc=(0, -0.6, 3.15), bevel=0.0), "UpperTorso", "sandstone")
    neckerchief("forest", knot="brass")
    # binoculars on their strap, a canteen at the hip
    for sx in (-1, 1):
        P(band((sx * 0.4, -0.2, 4.0), (sx * 0.3, -0.66, 3.1), 0.07, 0.04, (0, -1, 0)), "UpperTorso", "leather")
        P(sf.cyl(0.2, 0.5, loc=(sx * 0.24, -0.82, 2.96), rot=(90, 0, 0), verts=10, radius_top=0.16, bevel=0.02, segments=1), "UpperTorso", "rubber")
        P(sf.cyl(0.16, 0.05, loc=(sx * 0.24, -1.08, 2.96), rot=(90, 0, 0), verts=10, bevel=0.0), "UpperTorso", "skyblue")
    P(sf.box((0.24, 0.3, 0.2), loc=(0, -0.78, 2.98), bevel=0.03, segments=1), "UpperTorso", "rubber")
    P(sf.cyl(0.36, 0.26, loc=(-1.08, -0.1, 2.0), rot=(0, 90, 0), verts=14, bevel=0.06, segments=1), "LowerTorso", "olive")
    P(sf.cyl(0.1, 0.16, loc=(-1.08, -0.1, 2.42), verts=8, bevel=0.0), "LowerTorso", "chrome")
    # the campaign hat: a flat brim, a pinched crown, a leather band
    P(sf.cyl(1.22, 0.07, loc=(0, 0.0, 5.44), verts=24, bevel=0.02, segments=1), "Head", "leather")
    P(sf.cyl(0.74, 0.5, loc=(0, 0.02, 5.72), verts=18, radius_top=0.6, bevel=0.0), "Head", "leather")
    P(sf.sphere(0.6, loc=(0, 0.02, 5.96), scale=(1, 1, 0.5), segs=14, rings=7), "Head", "leather")
    P(sf.cyl(0.76, 0.14, loc=(0, 0.02, 5.54), verts=18, bevel=0.0), "Head", "forest")
    P(sf.box((0.16, 0.06, 0.16), loc=(0, -0.76, 5.54), bevel=0.02, segments=1), "Head", "brass")


def scout_props(H):
    # a Flare, struck and held high: the Flare Ping
    H.reach("Left", (1.4, -0.65, 4.15))
    up = (UP + CAM_RIGHT * 0.12).normalized()
    M = held_item(H, "Left", "Throwable_Flare", up, TO_CAM, scale=1.3)
    tip = M @ Vector((0.0, -0.6, 0.0))
    s0 = tip + up * 0.6
    H.glow("Left", sf.sphere(0.17, loc=s0, segs=10, rings=6), "signal")
    for i, t in enumerate((0.14, 0.32)):
        H.glow("Left", sf.sphere(0.07 - i * 0.02, loc=tip + up * t, segs=6, rings=4), "hazard")
    for a in range(6):
        r = math.radians(a * 60)
        ray = CAM_RIGHT * math.cos(r) + UP * math.sin(r)
        H.glow("Left", rod(s0 + ray * 0.24, s0 + ray * 0.46, 0.028, 4), "hazard")


# ------------------------------------------------------------------------------------------
# Rare: Radio Operator, Hazmat Tech, Exterminator, Marksman, Driller, Scavenger
# ------------------------------------------------------------------------------------------

RADIO_TIP = (-0.86, 1.1, 6.3)        # the top of the set's whip antenna (rest pose)


def radio_operator():
    bare_chest()
    # uniform shirt, an orange tie, a lightning flash on the sleeve
    P(sf.box((2.16, 1.16, 1.54), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "murk")
    P(flat([(-0.14, 3.92), (0.14, 3.92), (0.2, 3.0), (0.0, 2.78), (-0.2, 3.0)], 0.06, -0.61), "UpperTorso", "signal")
    P(sf.box((0.3, 0.08, 0.2), loc=(0, -0.63, 3.84), bevel=0.03, segments=1), "UpperTorso", "signal")
    for sx in (-1, 1):
        P(flat([(sx * 0.2, 3.96), (sx * 0.7, 3.96), (sx * 0.34, 3.6)], 0.06, -0.6), "UpperTorso", "navy")
        P(sf.box((0.5, 0.06, 0.4), loc=(sx * 0.6, -0.6, 3.2), bevel=0.02, segments=1), "UpperTorso", "navy")
        P(sf.sphere(0.05, loc=(sx * 0.6, -0.65, 3.34), segs=6, rings=4), "UpperTorso", "brass")
    P(flat_at([(0.08, 0.3), (-0.12, 0.02), (0.02, 0.02), (-0.08, -0.3), (0.14, 0.06), (0.0, 0.06)], 0.05, (-2.0, 0.0, 3.4), yaw=90),
      "RightUpperArm", "hazard")                                              # on the sleeve's outside
    # the headset: a band over the hair, two cups, a boom microphone
    P(sf.box((1.62, 0.2, 0.1), loc=(0, 0.06, 5.86), bevel=0.04, segments=1), "Head", "gunmetal")
    for sx in (-1, 1):
        P(sf.box((0.1, 0.2, 0.96), loc=(sx * 0.78, 0.06, 5.36), rot=(0, sx * 3, 0), bevel=0.03, segments=1), "Head", "gunmetal")
        P(sf.cyl(0.33, 0.26, loc=(sx * 0.8, 0.05, 4.84), rot=(0, 90, 0), verts=14, bevel=0.05, segments=1), "Head", "rubber")
        P(sf.cyl(0.24, 0.3, loc=(sx * 0.82, 0.05, 4.84), rot=(0, 90, 0), verts=12, bevel=0.02, segments=1), "Head", "signal")
    P(rod((0.84, -0.1, 4.7), (0.5, -0.72, 4.42), 0.035, 6), "Head", "gunmetal")
    P(sf.sphere(0.1, loc=(0.46, -0.76, 4.4), scale=(1, 1.3, 1), segs=8, rings=5), "Head", "rubber")
    # the field radio on his back: dials, a tuning window, a whip antenna with a pennant
    straps("leather")
    P(sf.box((1.6, 0.86, 1.8), loc=(0, 1.0, 3.3), bevel=0.08, segments=1), "UpperTorso", "olive")
    P(sf.box((1.64, 0.9, 0.16), loc=(0, 1.0, 4.14), bevel=0.03, segments=1), "UpperTorso", "gunmetal")
    P(sf.box((1.3, 0.06, 0.9), loc=(0, 1.45, 3.5), bevel=0.02, segments=1), "UpperTorso", "gunmetal")
    glow(sf.box((0.7, 0.05, 0.22), loc=(-0.2, 1.49, 3.74), bevel=0.0), "UpperTorso", "hazard")
    for i, x in enumerate((-0.42, -0.08, 0.26)):
        P(sf.cyl(0.11, 0.1, loc=(x, 1.5, 3.36), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), "UpperTorso", ("signal", "chrome", "signal")[i])
    for z in (2.76, 2.9, 3.04):
        P(sf.box((1.1, 0.05, 0.06), loc=(0, 1.46, z), bevel=0.0), "UpperTorso", "rubber")
    for i in range(4):
        P(sf.torus(0.1, 0.03, loc=(-0.6, 1.0, 4.28 + i * 0.07), major_segs=8, minor_segs=4), "UpperTorso", "chrome")
    tip = Vector(RADIO_TIP)
    P(rod((-0.6, 1.0, 4.5), tip, 0.035, 6, r_end=0.018), "UpperTorso", "chrome")
    P(flat_at([(0.0, 0.14), (-0.6, 0.0), (0.0, -0.14)], 0.03, tip + Vector((0.0, 0.0, -0.46)), yaw=CAM_YAW), "UpperTorso", "signal")
    P(sf.sphere(0.08, loc=tip, segs=6, rings=4), "UpperTorso", "signal")
    # the set's remote on his chest strap: a lit dial, two knobs, a coiled cord up to the headset
    P(sf.box((0.46, 0.2, 0.6), loc=(0.74, -0.7, 3.64), bevel=0.05, segments=1), "UpperTorso", "olive")
    glow(sf.cyl(0.13, 0.04, loc=(0.74, -0.81, 3.76), rot=(90, 0, 0), verts=10, bevel=0.0), "UpperTorso", "hazard")
    for i, x in enumerate((0.64, 0.84)):
        P(sf.cyl(0.06, 0.08, loc=(x, -0.82, 3.48), rot=(90, 0, 0), verts=8, bevel=0.0), "UpperTorso", ("chrome", "signal")[i])
    c0, c1 = Vector((0.86, -0.66, 3.96)), Vector((0.9, -0.2, 4.56))
    for i in range(7):
        q = c0.lerp(c1, i / 6.0)
        P(_aim(sf.torus(0.065, 0.022, major_segs=7, minor_segs=3), q, q + (c1 - c0).normalized() * 0.01), "UpperTorso", "rubber")
    P(rod((0.5, 1.0, 4.2), (0.5, 1.0, 4.6), 0.07, 6), "UpperTorso", "gunmetal")


def radio_operator_props(H):
    # a hand to the headset, and the set is transmitting
    H.reach("Left", (1.2, -0.25, 4.86))
    tip = H.at("UpperTorso", RADIO_TIP)
    for i in range(3):
        H.glow("Left", _aim(sf.torus(0.22 + i * 0.17, 0.022, major_segs=18, minor_segs=3), tip + TO_CAM * 0.02, tip + TO_CAM * 0.03), "signal")


def hazmat_tech():
    drop(lambda o: o.get("sf_role") == "Hair")
    bare_chest()
    # the suit: a bulky body with a taped front flap and a warning badge
    P(sf.box((2.26, 1.26, 1.64), loc=(0, 0, 3.14), bevel=0.2, segments=2), "UpperTorso", "hazard")
    long_sleeves("hazard", "teal")
    P(sf.box((0.5, 0.07, 1.56), loc=(0, -0.64, 3.14), bevel=0.03, segments=1), "UpperTorso", "hazard")
    for sx in (-1, 1):
        P(sf.box((0.07, 0.08, 1.56), loc=(sx * 0.25, -0.66, 3.14), bevel=0.0), "UpperTorso", "teal")
    P(sf.cyl(0.26, 0.06, loc=(0.6, -0.65, 3.42), rot=(90, 0, 0), verts=14, bevel=0.0), "UpperTorso", "rubber")
    P(sf.cyl(0.06, 0.08, loc=(0.6, -0.67, 3.42), rot=(90, 0, 0), verts=8, bevel=0.0), "UpperTorso", "hazard")
    for i in range(3):
        a = math.radians(90 + i * 120)
        P(sf.box((0.14, 0.05, 0.12), loc=(0.6 + math.cos(a) * 0.15, -0.68, 3.42 + math.sin(a) * 0.15), rot=(0, -(90 + i * 120 - 90), 0), bevel=0.0),
          "UpperTorso", "hazard")
    P(sf.box((2.2, 1.2, 0.2), loc=(0, 0, 2.36), bevel=0.04, segments=1), "LowerTorso", "teal")
    shin_bands("teal", z=0.72, h=0.16)
    gloves("rubber", cuff="teal")
    # the hood, open at the face, and a respirator with two canisters
    P(sf.box((1.66, 1.54, 0.4), loc=(0, 0.04, 5.5), bevel=0.14, segments=2), "Head", "hazard")
    P(sf.box((1.66, 0.4, 1.56), loc=(0, 0.62, 4.9), bevel=0.14, segments=2), "Head", "hazard")
    for sx in (-1, 1):
        P(sf.box((0.26, 1.42, 1.5), loc=(sx * 0.72, 0.0, 4.9), bevel=0.1, segments=1), "Head", "hazard")
        P(sf.box((0.1, 0.12, 0.96), loc=(sx * 0.6, -0.72, 4.9), bevel=0.02, segments=1), "Head", "rubber")
    P(sf.box((1.6, 0.34, 0.3), loc=(0, -0.58, 4.22), bevel=0.1, segments=1), "Head", "hazard")
    for z in (5.36, 4.42):
        P(sf.box((1.3, 0.12, 0.1), loc=(0, -0.72, z), bevel=0.02, segments=1), "Head", "rubber")
    P(sf.cyl(0.66, 0.5, loc=(0, 0.04, 4.02), verts=14, radius_top=0.8, bevel=0.03, segments=1), "UpperTorso", "hazard")
    P(sf.box((0.72, 0.34, 0.5), loc=(0, -0.76, 4.46), bevel=0.12, segments=2), "Head", "gunmetal")
    P(sf.cyl(0.13, 0.1, loc=(0, -0.96, 4.46), rot=(90, 0, 0), verts=10, bevel=0.02, segments=1), "Head", "chrome")
    for sx in (-1, 1):
        P(sf.cyl(0.22, 0.34, loc=(sx * 0.46, -0.8, 4.38), rot=(90, 0, sx * 38), verts=12, bevel=0.03, segments=1), "Head", "teal")
        P(sf.cyl(0.19, 0.05, loc=(sx * 0.57, -0.94, 4.38), rot=(90, 0, sx * 38), verts=12, bevel=0.0), "Head", "rubber")
    # the air tank and its hose
    P(sf.cyl(0.44, 1.5, loc=(0, 0.98, 3.25), verts=14, bevel=0.1, segments=2), "UpperTorso", "steel")
    P(sf.cyl(0.47, 0.14, loc=(0, 0.98, 3.25), verts=14, bevel=0.0), "UpperTorso", "teal")
    P(sf.cyl(0.14, 0.24, loc=(0, 0.98, 4.1), verts=8, bevel=0.02, segments=1), "UpperTorso", "chrome")
    P(rod((0, 0.98, 4.2), (-0.7, 0.5, 4.3), 0.07, 6), "UpperTorso", "rubber")
    P(rod((-0.7, 0.5, 4.3), (-0.62, -0.5, 4.3), 0.07, 6), "UpperTorso", "rubber")
    straps("rubber", width=0.16)


def hazmat_tech_props(H):
    # the Geiger counter, its lamp lit, the needle over
    H.reach("Left", (1.02, -0.95, 3.66))
    c = H.hand("Left") + Vector((0.0, -0.14, 0.52))
    rot = _rot_toward_camera(CAM_YAW + 16, 6)
    m = Euler([math.radians(a) for a in rot]).to_matrix()
    f = m @ Vector((0, -1, 0))
    H.prop("Left", sf.box((0.96, 0.46, 0.7), loc=c, rot=rot, bevel=0.06, segments=1), "olive")
    H.prop("Left", sf.box((0.6, 0.05, 0.36), loc=c + f * 0.24 + m @ Vector((-0.1, 0, 0.1)), rot=rot, bevel=0.02, segments=1), "cream")
    H.prop("Left", sf.box((0.04, 0.03, 0.3), loc=c + f * 0.27 + m @ Vector((-0.02, 0, 0.08)), rot=(rot[0], rot[1] - 40, rot[2]), bevel=0.0), "rust")
    H.glow("Left", sf.sphere(0.09, loc=c + f * 0.25 + m @ Vector((0.34, 0, 0.18)), segs=8, rings=5), "glow")
    H.prop("Left", sf.cyl(0.08, 0.06, loc=c + f * 0.26 + m @ Vector((0.34, 0, -0.14)), rot=(rot[0] + 90, rot[1], rot[2]), verts=8, bevel=0.0), "chrome")
    H.prop("Left", sf.torus(0.2, 0.04, loc=c + m @ Vector((0, 0, 0.42)), rot=(rot[0] + 90, rot[1], rot[2]), major_segs=10, minor_segs=4), "rubber")
    for i in range(3):
        H.glow("Left", sf.torus(0.5 + i * 0.22, 0.02, loc=c + f * 0.3, rot=(rot[0] + 90, rot[1], rot[2]), major_segs=20, minor_segs=3), "glow")


def exterminator():
    short_hair("#5B3A24")
    bare_chest()
    # grey coveralls with a red yoke, a zip, the firm's badge: a bug, struck out
    P(sf.box((2.2, 1.2, 0.36), loc=(0, 0, 3.76), bevel=0.1, segments=1), "UpperTorso", "rust")
    arm_bands("rust", z=3.62, h=0.3)
    P(sf.box((0.08, 0.05, 1.2), loc=(0, -0.57, 3.0), bevel=0.0), "UpperTorso", "gunmetal")
    P(sf.cyl(0.26, 0.06, loc=(0.56, -0.57, 3.3), rot=(90, 0, 0), verts=14, bevel=0.0), "UpperTorso", "cream")
    P(sf.sphere(0.12, loc=(0.56, -0.6, 3.3), scale=(0.8, 0.3, 1.1), segs=8, rings=5), "UpperTorso", "rubber")
    P(sf.box((0.52, 0.04, 0.08), loc=(0.56, -0.62, 3.3), rot=(0, 45, 0), bevel=0.0), "UpperTorso", "rust")
    P(sf.box((0.5, 0.05, 0.16), loc=(-0.52, -0.57, 3.4), bevel=0.0), "UpperTorso", "cream")
    # a half-mask hanging at the neck
    P(sf.box((0.6, 0.3, 0.4), loc=(0, -0.62, 3.98), rot=(-18, 0, 0), bevel=0.1, segments=2), "UpperTorso", "gunmetal")
    P(sf.cyl(0.18, 0.2, loc=(0, -0.8, 3.92), rot=(72, 0, 0), verts=10, bevel=0.03, segments=1), "UpperTorso", "rust")
    P(sf.torus(0.5, 0.04, loc=(0, 0.02, 4.04), major_segs=14, minor_segs=4), "UpperTorso", "rubber")
    # a red cap with goggles on it
    dome("rust", r=0.78, z=5.5, flat_=0.42)
    P(sf.cyl(0.77, 0.26, loc=(0, 0.02, 5.46), verts=20, bevel=0.0), "Head", "rust")
    peak("rust", z=5.36, w=1.16, d=0.62, y=-0.84)
    P(sf.sphere(0.1, loc=(0, -0.76, 5.56), scale=(1.4, 0.5, 1), segs=8, rings=5), "Head", "brass")
    goggles(z=5.62, y=-0.76, frame="gunmetal", lens="skyblue", r=0.19, gap=0.26, strap="rubber", around=(1.6, 1.62))
    gloves("rubber", cuff="rust")
    shin_bands("rust", z=0.72, h=0.14)
    # the tanks: two red cylinders, a gauge between them, the hose
    straps("leather")
    for sx in (-1, 1):
        P(sf.cyl(0.38, 1.6, loc=(sx * 0.42, 1.0, 3.3), verts=14, bevel=0.12, segments=2), "UpperTorso", "rust")
        P(sf.cyl(0.4, 0.16, loc=(sx * 0.42, 1.0, 3.7), verts=14, bevel=0.0), "UpperTorso", "hazard")
        P(sf.cyl(0.12, 0.2, loc=(sx * 0.42, 1.0, 4.2), verts=8, bevel=0.02, segments=1), "UpperTorso", "chrome")
    P(sf.box((1.0, 0.3, 0.16), loc=(0, 1.0, 2.6), bevel=0.03, segments=1), "UpperTorso", "gunmetal")
    P(sf.box((1.0, 0.3, 0.16), loc=(0, 1.0, 3.95), bevel=0.03, segments=1), "UpperTorso", "gunmetal")
    P(sf.cyl(0.2, 0.08, loc=(0, 1.42, 3.4), rot=(90, 0, 0), verts=12, bevel=0.0), "UpperTorso", "cream")
    P(sf.box((0.03, 0.03, 0.18), loc=(0.03, 1.47, 3.44), rot=(0, 30, 0), bevel=0.0), "UpperTorso", "rust")
    P(rod((-0.42, 1.0, 2.5), (-1.2, 0.5, 2.3), 0.08, 6), "UpperTorso", "rubber")
    P(rod((-1.2, 0.5, 2.3), (-1.3, -0.4, 2.5), 0.08, 6), "UpperTorso", "rubber")


def exterminator_props(H):
    # the Flamethrower, nozzle up, burning; its hose back to the tanks
    H.reach("Right", (-1.15, -0.9, 3.45))
    f = (UP * 0.97 - CAM_RIGHT * 0.24).normalized()
    M = held_item(H, "Right", "Weapon_Flamethrower", f, -CAM_RIGHT, scale=0.8)
    flame(lambda o, sw: H.glow("Right", o, sw), M @ Vector((0.0, -2.62, 0.55)), f - CAM_RIGHT * 0.1, length=0.95, r=0.2,
          sparks=((0.28, -0.1, 0.02), (-0.2, 0.0, 0.16), (0.1, 0.1, 0.3)), spark="signal")
    a, b = M @ Vector((0.0, 0.56, 0.3)), H.at("UpperTorso", (-1.3, -0.4, 2.5))
    pts = [a, a.lerp(b, 0.5) + Vector((-0.22, -0.12, -0.2)), b]
    for q0, q1 in zip(pts, pts[1:]):
        H.prop("Right", rod(q0, q1, 0.07, 6), "rubber")


def marksman():
    short_hair("#3B2F2A")
    recolor(LEGS, "forest", "walnut")
    bare_chest()
    # a hunting jacket: a fur collar, a leather shoulder pad, a row of cartridges
    P(sf.box((2.18, 1.18, 1.56), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "forest")
    long_sleeves("forest", "walnut")
    P(sf.torus(0.56, 0.16, loc=(0, 0.04, 4.0), major_segs=14, minor_segs=6), "UpperTorso", "walnut")
    P(sf.box((0.9, 0.5, 0.9), loc=(-0.68, -0.4, 3.52), bevel=0.14, segments=1), "UpperTorso", "leather")
    for i in range(3):
        P(sf.box((0.7, 0.03, 0.03), loc=(-0.66, -0.66, 3.3 + i * 0.2), bevel=0.0), "UpperTorso", "walnut")
    P(sf.box((0.07, 0.05, 1.5), loc=(0.1, -0.6, 3.15), bevel=0.0), "UpperTorso", "walnut")
    for z in (3.5, 3.1, 2.7):
        P(sf.sphere(0.06, loc=(0.1, -0.64, z), segs=6, rings=4), "UpperTorso", "brass")
    P(band((0.9, -0.62, 3.9), (-0.9, -0.62, 2.55), 0.26, 0.05, (0, -1, 0)), "UpperTorso", "leather")
    for i in range(6):
        t = 0.14 + i * 0.13
        p = Vector((0.9, -0.67, 3.9)).lerp(Vector((-0.9, -0.67, 2.55)), t)
        P(sf.cyl(0.055, 0.3, loc=p, rot=(0, -37, 0), verts=6, bevel=0.0), "UpperTorso", "brass")
    # the Hunting Knife, sheathed on the strap
    item("Weapon_HuntingKnife", (0.62, -0.76, 3.6), (0.1, 0.0, -1.0), (-1.0, 0.0, 0.0), "UpperTorso", "OutfitUpperTorso", "GlowUpperTorso", scale=0.8)
    P(sf.box((0.34, 0.13, 1.2), loc=(0.69, -0.74, 2.84), rot=(0, -6, 0), bevel=0.04, segments=1), "UpperTorso", "leather")
    P(sf.box((0.37, 0.15, 0.1), loc=(0.63, -0.74, 3.4), rot=(0, -6, 0), bevel=0.02, segments=1), "UpperTorso", "brass")
    P(sf.box((2.02, 1.14, 0.2), loc=(0, 0, 2.36), bevel=0.04, segments=1), "LowerTorso", "leather")
    P(sf.box((0.3, 0.3, 0.6), loc=(1.04, -0.1, 2.0), bevel=0.05, segments=1), "LowerTorso", "walnut")
    P(sf.box((0.12, 0.12, 0.3), loc=(1.04, -0.1, 2.44), bevel=0.03, segments=1), "LowerTorso", "steel")
    # the hunter's cap: red plaid, the ear flaps down, a feather in the band
    dome("rust", r=0.8, z=5.46, flat_=0.5)
    P(sf.cyl(0.78, 0.3, loc=(0, 0.02, 5.44), verts=20, bevel=0.0), "Head", "rust")
    peak("rust", z=5.34, w=1.1, d=0.56, y=-0.8)
    crest("basalt", r=0.8, z=5.46, flat_=0.5, width=0.07, lift=0.012)
    crest("basalt", r=0.8, z=5.46, flat_=0.5, width=0.07, lift=0.012, yaw=0)
    for a in (45, 135):
        P(sf.box((1.6, 0.05, 0.31), loc=(0, 0.02, 5.44), rot=(0, 0, a), bevel=0.0), "Head", "basalt")
    P(sf.sphere(0.09, loc=(0, 0.02, 5.88), segs=8, rings=5), "Head", "basalt")
    for sx in (-1, 1):
        P(sf.box((0.13, 0.84, 0.62), loc=(sx * 0.745, 0.12, 5.02), bevel=0.05, segments=1), "Head", "rust")
        P(sf.box((0.16, 0.88, 0.16), loc=(sx * 0.75, 0.12, 4.72), bevel=0.05, segments=1), "Head", "cream")
    P(sf.box((1.44, 0.13, 0.62), loc=(0, 0.7, 5.02), bevel=0.05, segments=1), "Head", "rust")
    P(flat_at([(0.0, 0.0), (0.11, 0.2), (0.07, 0.56), (-0.03, 0.66), (-0.08, 0.35)], 0.04, (0.6, -0.52, 5.5), yaw=-18), "Head", "signal")
    gloves("leather", cuff=None)


def marksman_props(H):
    # the Lever Rifle and its scope, carried upright
    H.reach("Right", (-1.2, -0.85, 3.7))
    M = held_item(H, "Right", "Weapon_LeverRifle", UP * 0.985 - CAM_RIGHT * 0.17, -CAM_RIGHT, scale=0.88)
    lens = M @ Vector((0.0, -1.4, 0.92)) + TO_CAM * 0.12                # a glint off the scope
    H.glow("Right", flat_at(star_xz(0, 0, 0.3, 0.06, 4), 0.02, tuple(lens), yaw=CAM_YAW), "cream")


def driller():
    short_hair("#2B2B2B")
    moustache("#2B2B2B", w=0.34, droop=18)
    hair(sf.box((1.24, 0.34, 0.56), loc=(0, -0.5, 4.3), bevel=0.14, segments=2), "#2B2B2B")           # a miner's beard
    for sx in (-1, 1):
        hair(sf.box((0.16, 0.5, 0.6), loc=(sx * 0.66, -0.3, 4.44), bevel=0.06, segments=1), "#2B2B2B")
    bare_chest()
    # canvas bib and braces, copper rivets, an orange bandana
    P(sf.box((1.36, 0.08, 1.1), loc=(0, -0.59, 3.1), bevel=0.03, segments=1), "UpperTorso", "leather")
    for sx in (-1, 1):
        P(band((sx * 0.56, -0.6, 3.6), (sx * 0.62, -0.5, 3.98), 0.22, 0.06, (0, -1, 0.3)), "UpperTorso", "leather")
        P(band((sx * 0.62, -0.5, 3.98), (sx * 0.5, 0.6, 3.9), 0.22, 0.06, (0, 0, 1)), "UpperTorso", "leather")
        P(sf.sphere(0.07, loc=(sx * 0.56, -0.65, 3.56), segs=8, rings=5), "UpperTorso", "copper")
    P(sf.box((0.8, 0.06, 0.4), loc=(0, -0.64, 3.0), bevel=0.02, segments=1), "UpperTorso", "walnut")
    neckerchief("signal", knot="signal")
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.box((0.92, 0.3, 0.5), loc=(sx * 0.5, -0.4, 1.22), bevel=0.1, segments=1), f"{side}LowerLeg", "steel")
    gloves("leather", cuff="walnut")
    # the helmet: copper, a big lamp, ear defenders
    dome("copper", r=0.84, z=5.36, flat_=0.76)
    brim("copper", r=0.94, z=5.32, deep=1.04)
    P(sf.box((0.14, 1.5, 0.1), loc=(0, 0.02, 5.94), bevel=0.04, segments=1), "Head", "brass")
    P(sf.cyl(0.3, 0.3, loc=(0, -0.84, 5.62), rot=(80, 0, 0), verts=14, radius_top=0.2, bevel=0.0), "Head", "chrome")
    glow(sf.cyl(0.24, 0.05, loc=(0, -1.0, 5.6), rot=(80, 0, 0), verts=14, bevel=0.0), "Head", "cream")
    P(sf.box((0.3, 0.3, 0.3), loc=(0, 0.84, 5.5), bevel=0.05, segments=1), "Head", "gunmetal")
    P(rod((0.1, -0.7, 5.74), (0.4, 0.3, 5.96), 0.03, 5), "Head", "rubber")
    P(rod((0.4, 0.3, 5.96), (0.1, 0.84, 5.6), 0.03, 5), "Head", "rubber")
    for sx in (-1, 1):
        P(sf.cyl(0.34, 0.28, loc=(sx * 0.82, 0.05, 4.84), rot=(0, 90, 0), verts=14, bevel=0.06, segments=1), "Head", "rubber")
        P(sf.cyl(0.2, 0.32, loc=(sx * 0.84, 0.05, 4.84), rot=(0, 90, 0), verts=10, bevel=0.02, segments=1), "Head", "copper")
        P(sf.box((0.08, 0.16, 0.5), loc=(sx * 0.86, 0.05, 5.2), bevel=0.02, segments=1), "Head", "steel")


def driller_props(H):
    # the Drill, bit up
    H.reach("Left", (0.8, -0.95, 3.5))
    held_item(H, "Left", "Tool_Drill", UP * 0.97 + CAM_RIGHT * 0.24, CAM_RIGHT, scale=0.82)


def scavenger():
    bare_chest()
    # a patched jacket
    P(sf.box((2.16, 1.16, 1.54), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "stone")
    P(sf.box((0.07, 0.05, 1.5), loc=(0, -0.6, 3.15), bevel=0.0), "UpperTorso", "basalt")
    for (x, z, w, h, sw, r) in ((-0.55, 3.45, 0.5, 0.44, "teal", 8), (0.5, 2.9, 0.56, 0.4, "blush", -10), (0.62, 3.6, 0.34, 0.3, "hazard", 14)):
        P(sf.box((w, 0.05, h), loc=(x, -0.61, z), rot=(0, r, 0), bevel=0.0), "UpperTorso", sw)
        for k in range(3):
            P(sf.box((0.03, 0.03, 0.1), loc=(x - w / 2 + 0.06 + k * (w - 0.12) / 2, -0.64, z + h / 2 - 0.02), rot=(0, r, 0), bevel=0.0), "UpperTorso", "cream")
    P(sf.box((0.5, 0.5, 0.36), loc=(1.5, 0, 3.0), rot=(0, 0, 6), bevel=0.06, segments=1), "LeftUpperArm", "signal")
    P(sf.box((0.5, 0.4, 0.4), loc=(-0.5, -0.36, 1.3), bevel=0.06, segments=1), "RightLowerLeg", "teal")
    # a long scarf, wound twice
    P(sf.torus(0.56, 0.2, loc=(0, 0.02, 4.04), major_segs=14, minor_segs=6), "UpperTorso", "plum")
    P(sf.torus(0.6, 0.16, loc=(0, 0.0, 3.9), rot=(8, 0, 0), major_segs=14, minor_segs=6), "UpperTorso", "plum")
    P(sf.box((0.4, 0.14, 1.0), loc=(0.5, -0.66, 3.4), rot=(4, 6, 0), bevel=0.05, segments=1), "UpperTorso", "plum")
    for i in range(4):
        P(sf.box((0.06, 0.1, 0.16), loc=(0.36 + i * 0.1, -0.68, 2.84), bevel=0.0), "UpperTorso", "plum")
    # goggles pushed up into the hair, fingerless gloves
    goggles(z=5.3, y=-0.7, frame="leather", lens="skyblue", r=0.2, gap=0.28, strap="walnut", around=(1.5, 1.44))
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.cyl(0.38, 0.4, loc=(sx * 1.5, 0, 2.36), verts=10, bevel=0.03, segments=1), f"{side}LowerArm", "leather")
    # the pack: taller than he is wide, and everything he ever found is tied to it
    straps("leather", width=0.24)
    P(sf.box((1.8, 1.0, 2.1), loc=(0, 1.06, 3.4), bevel=0.14, segments=2), "UpperTorso", "olive")
    P(sf.box((1.84, 1.04, 0.5), loc=(0, 1.06, 4.3), bevel=0.12, segments=1), "UpperTorso", "sandstone")
    P(sf.cyl(0.36, 2.1, loc=(0, 1.0, 4.82), rot=(0, 90, 0), verts=14, bevel=0.06, segments=1), "UpperTorso", "rust")
    for x in (-0.7, 0.7):
        P(sf.torus(0.37, 0.05, loc=(x, 1.0, 4.82), rot=(0, 90, 0), major_segs=14, minor_segs=4), "UpperTorso", "leather")
    for x, z in ((-0.5, 3.0), (0.5, 3.0)):
        P(sf.box((0.7, 0.2, 0.7), loc=(x, 1.6, z), bevel=0.06, segments=1), "UpperTorso", "sandstone")
        P(sf.box((0.74, 0.22, 0.2), loc=(x, 1.62, z + 0.3), bevel=0.04, segments=1), "UpperTorso", "leather")
    P(sf.cyl(0.46, 0.08, loc=(1.02, 1.1, 3.5), rot=(0, 90, 0), verts=16, bevel=0.0), "UpperTorso", "gunmetal")
    P(rod((1.02, 1.1, 3.96), (1.02, 1.1, 4.5), 0.05, 6), "UpperTorso", "gunmetal")
    P(sf.sphere(0.34, loc=(-1.1, 1.0, 3.3), scale=(1, 1, 0.9), segs=12, rings=7), "UpperTorso", "chrome")
    P(rod((-1.1, 1.0, 3.6), (-1.4, 0.8, 3.5), 0.06, 6), "UpperTorso", "chrome")
    P(sf.torus(0.3, 0.07, loc=(-1.04, 1.1, 4.0), rot=(0, 90, 0), major_segs=12, minor_segs=5), "UpperTorso", "pine")
    # somebody's bear rides on top
    P(sf.sphere(0.3, loc=(-0.9, 0.9, 5.34), segs=10, rings=6), "UpperTorso", "pine")
    for sx in (-1, 1):
        P(sf.sphere(0.12, loc=(-0.9 + sx * 0.24, 0.9, 5.6), segs=8, rings=5), "UpperTorso", "pine")
    P(sf.sphere(0.12, loc=(-0.9, 0.64, 5.28), segs=8, rings=5), "UpperTorso", "cream")
    P(sf.sphere(0.04, loc=(-0.9, 0.53, 5.3), segs=6, rings=4), "UpperTorso", "rubber")
    for sx in (-1, 1):
        P(sf.sphere(0.04, loc=(-0.9 + sx * 0.12, 0.62, 5.42), segs=6, rings=4), "UpperTorso", "rubber")


def scavenger_props(H):
    # the Magnet Sweep: a horseshoe magnet with scrap flying to it
    H.reach("Left", (1.18, -0.85, 3.9))
    c = H.hand("Left")
    up = Vector((0.1, -0.2, 1.0)).normalized()
    side = Vector((1.0, 0.1, -0.08)).normalized()
    front = side.cross(up).normalized()
    held(H, "Left", sf.box((0.9, 0.26, 0.3), bevel=0.08, segments=1), "rust", c + up * 0.0, c + up * 0.3, front)
    for s in (-1, 1):
        held(H, "Left", sf.box((0.26, 0.26, 0.7), bevel=0.04, segments=1), "rust", c + side * s * 0.32 + up * 0.24, c + side * s * 0.32 + up * 0.94, front)
        held(H, "Left", sf.box((0.28, 0.28, 0.24), bevel=0.03, segments=1), "chrome", c + side * s * 0.32 + up * 0.92, c + side * s * 0.32 + up * 1.16, front)
    tip = c + up * 1.2
    held(H, "Left", sf.cyl(0.05, 0.4, verts=6, bevel=0.0), "steel", tip + Vector((-0.5, -0.1, 0.5)), tip + Vector((-0.34, -0.06, 0.2)))
    held(H, "Left", sf.cyl(0.1, 0.06, verts=6, bevel=0.0), "steel", tip + Vector((-0.52, -0.1, 0.54)), tip + Vector((-0.5, -0.1, 0.5)))
    H.prop("Left", flat_at(star_xz(0, 0, 0.18, 0.11, 6), 0.05, tip + Vector((0.3, -0.1, 0.62)), yaw=CAM_YAW), "brass")
    held(H, "Left", sf.cyl(0.12, 0.26, verts=10, bevel=0.02, segments=1), "chrome", tip + Vector((0.0, -0.05, 0.95)), tip + Vector((0.12, -0.05, 1.18)))
    H.prop("Left", sf.torus(0.1, 0.03, loc=tip + Vector((-0.2, -0.1, 0.92)), rot=(70, 20, 0), major_segs=8, minor_segs=4), "steel")
    for i in range(2):
        H.glow("Left", sf.torus(0.42 + i * 0.2, 0.018, loc=tip + up * (0.1 + i * 0.16), rot=(8, 6, 0), major_segs=16, minor_segs=3), "crystal")


# ------------------------------------------------------------------------------------------
# Epic: Demolitionist, Spelunker
# ------------------------------------------------------------------------------------------

def demolitionist():
    drop(lambda o: o.get("sf_role") == "Hair")
    moustache("#8A4B22", w=0.4, droop=24, z=4.5)
    hair(sf.box((1.3, 0.3, 0.5), loc=(0, -0.52, 4.28), bevel=0.14, segments=2), "#8A4B22")
    bare_chest()
    # the blast suit: quilted armour, brass clasps, a collar that stands behind his head
    P(sf.box((2.5, 1.5, 1.72), loc=(0, 0, 3.12), bevel=0.26, segments=2), "UpperTorso", "olive")
    for z in (3.56, 3.12, 2.68):
        P(sf.box((2.54, 1.54, 0.05), loc=(0, 0, z), bevel=0.0), "UpperTorso", "gunmetal")
    for x in (-0.62, 0.62):
        P(sf.box((0.05, 0.08, 1.64), loc=(x, -0.74, 3.12), bevel=0.0), "UpperTorso", "gunmetal")
    for z in (3.5, 3.05, 2.6):
        P(sf.box((0.44, 0.1, 0.2), loc=(0, -0.78, z), bevel=0.04, segments=1), "UpperTorso", "brass")
    long_sleeves("olive", "hazard")
    P(open_shell(1.02, 1.26, 1.25, 4.5, -0.28, thick=0.16, y_scale=0.92, verts=22), "UpperTorso", "olive")
    P(open_shell(1.3, 1.3, 0.14, 5.14, -0.28, thick=0.08, y_scale=0.92, verts=22), "UpperTorso", "hazard")
    for i in range(5):
        a = math.radians(40 + i * 25)
        P(sf.sphere(0.07, loc=(math.cos(a) * 1.36, 0.92 * math.sin(a) * 1.36, 4.96), segs=6, rings=4), "UpperTorso", "brass")
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.box((0.98, 1.1, 0.7), loc=(sx * 1.52, 0, 3.72), rot=(0, sx * -8, 0), bevel=0.2, segments=2), f"{side}UpperArm", "olive")
        for k in range(2):
            P(flat_at([(-0.3, 0.0), (0.0, 0.2), (0.3, 0.0), (0.3, 0.12), (0.0, 0.32), (-0.3, 0.12)], 0.05, (sx * 1.52, -0.58, 3.44 + k * 0.24)),
              f"{side}UpperArm", "hazard")
        P(sf.box((0.94, 0.3, 0.9), loc=(sx * 0.5, -0.42, 1.0), bevel=0.1, segments=1), f"{side}LowerLeg", "gunmetal")
    shin_bands("hazard", z=0.72, h=0.14)
    gloves("rubber", cuff="olive")
    # dynamite across the chest, a round bomb at the hip with its fuse lit
    P(band((0.98, -0.78, 3.86), (-0.98, -0.78, 2.6), 0.3, 0.06, (0, -1, 0)), "UpperTorso", "leather")
    for i in range(5):
        p = Vector((0.98, -0.86, 3.86)).lerp(Vector((-0.98, -0.86, 2.6)), 0.14 + i * 0.17)
        P(sf.cyl(0.1, 0.56, loc=p, rot=(0, -33, 0), verts=8, bevel=0.0), "UpperTorso", "rust")
        tip = p + Vector((math.sin(math.radians(33)), 0, math.cos(math.radians(33)))) * 0.3
        P(sf.cyl(0.03, 0.14, loc=tip, rot=(0, -33, 0), verts=5, bevel=0.0), "UpperTorso", "cream")
    P(sf.box((2.3, 1.36, 0.26), loc=(0, 0, 2.34), bevel=0.05, segments=1), "LowerTorso", "leather")
    P(sf.box((0.5, 0.1, 0.36), loc=(0, -0.7, 2.34), bevel=0.04, segments=1), "LowerTorso", "brass")
    P(sf.sphere(0.36, loc=(1.24, -0.3, 1.9), segs=14, rings=8), "LowerTorso", "rubber")
    P(sf.cyl(0.1, 0.12, loc=(1.24, -0.3, 2.26), verts=8, bevel=0.0), "LowerTorso", "gunmetal")
    P(rod((1.24, -0.3, 2.3), (1.42, -0.42, 2.56), 0.03, 5), "LowerTorso", "pine")
    glow(sf.sphere(0.09, loc=(1.44, -0.44, 2.6), segs=8, rings=5), "LowerTorso", "hazard")
    for off in ((0.12, -0.04, 0.14), (-0.1, -0.08, 0.1), (0.04, 0.08, 0.2)):
        glow(sf.sphere(0.03, loc=(1.44 + off[0], -0.44 + off[1], 2.6 + off[2]), segs=5, rings=3), "LowerTorso", "signal")
    # a steel helmet, hazard stripes, the blast visor up
    dome("gunmetal", r=0.86, z=5.3, flat_=0.82, deep=1.08)
    brim("gunmetal", r=0.93, z=5.26, deep=1.08, thick=0.08)
    crest("hazard", r=0.86, z=5.3, flat_=0.82, deep=1.08, width=0.4, lift=0.025)
    crest("gunmetal", r=0.86, z=5.3, flat_=0.82, deep=1.08, width=0.1, lift=0.05)
    for sx in (-1, 1):
        P(sf.cyl(0.14, 0.12, loc=(sx * 0.9, 0.0, 5.36), rot=(0, 90, 0), verts=8, bevel=0.02, segments=1), "Head", "brass")
    visor("skyblue", "rubber", pivot=(0, 0.02, 5.32), r=0.88, tilt=50, height=0.6)


def demolitionist_props(H):
    # the plunger box, wired up, his hand on its handle
    H.reach("Right", (-1.25, -0.85, 3.2))
    held_item(H, "Right", "Weapon_GrenadeLauncher", UP * 0.985 - CAM_RIGHT * 0.17, -CAM_RIGHT, scale=0.85)
    H.reach("Left", (1.08, -0.95, 3.3))
    c = H.hand("Left") + Vector((0.0, -0.1, 0.56))
    rot = _rot_toward_camera(CAM_YAW + 14, 4)
    m = Euler([math.radians(a) for a in rot]).to_matrix()
    f = m @ Vector((0, -1, 0))
    H.prop("Left", sf.box((1.0, 0.7, 0.8), loc=c, rot=rot, bevel=0.06, segments=1), "rust")
    for sx in (-1, 1):
        for sz in (-1, 1):
            H.prop("Left", sf.box((0.2, 0.74, 0.2), loc=c + m @ Vector((sx * 0.42, 0, sz * 0.32)), rot=rot, bevel=0.03, segments=1), "brass")
    H.prop("Left", sf.box((0.6, 0.05, 0.3), loc=c + f * 0.36, rot=rot, bevel=0.0), "hazard")
    H.prop("Left", sf.box((0.5, 0.06, 0.06), loc=c + f * 0.38 + m @ Vector((0, 0, 0.04)), rot=rot, bevel=0.0), "rubber")
    H.prop("Left", sf.box((0.34, 0.06, 0.06), loc=c + f * 0.38 + m @ Vector((0, 0, -0.07)), rot=rot, bevel=0.0), "rubber")
    H.glow("Left", sf.sphere(0.075, loc=c + f * 0.37 + m @ Vector((0.0, 0, 0.27)), segs=8, rings=5), "signal")       # armed
    top = c + m @ Vector((0, 0, 0.4))
    H.prop("Left", rod(top, top + Vector((0, 0, 0.7)), 0.07, 8), "chrome")
    H.prop("Left", rod(top + m @ Vector((-0.42, 0, 0.72)), top + m @ Vector((0.42, 0, 0.72)), 0.1, 8), "rubber")
    w0 = c + m @ Vector((0.5, 0, -0.2))
    pts = [w0, w0 + Vector((0.4, 0.1, -0.3)), w0 + Vector((0.5, 0.3, -0.9)), w0 + Vector((0.2, 0.5, -1.5))]
    for a, b in zip(pts, pts[1:]):
        H.prop("Left", rod(a, b, 0.035, 5), "hazard")


def spelunker():
    short_hair("#D8B24A")
    for i, (x, y, z, r) in enumerate(((-0.5, 0.52, 4.56, 0.26), (-0.66, 0.1, 4.32, 0.23), (-0.66, -0.34, 4.06, 0.21),
                                      (-0.62, -0.62, 3.78, 0.19), (-0.6, -0.7, 3.5, 0.17), (-0.58, -0.72, 3.26, 0.14))):
        P(sf.sphere(r, loc=(x + (i % 2) * 0.05, y, z), segs=10, rings=6), "UpperTorso", sf.TINT, role="Hair", tint="#D8B24A")     # a braid over her shoulder
    P(sf.torus(0.16, 0.05, loc=(-0.59, -0.72, 3.38), major_segs=8, minor_segs=4), "UpperTorso", "crystal")
    bare_chest()
    # a climbing harness over the jumpsuit: brass rings and buckles, carabiners at the hip
    P(sf.box((2.16, 1.16, 1.54), loc=(0, 0, 3.15), bevel=0.16, segments=2), "UpperTorso", "plum")
    long_sleeves("plum", "brass")
    for sx in (-1, 1):
        P(band((sx * 0.5, -0.6, 2.5), (sx * 0.62, -0.6, 3.9), 0.2, 0.06, (0, -1, 0)), "UpperTorso", "leather")
        P(band((sx * 0.62, -0.6, 3.9), (sx * 0.56, 0.6, 3.96), 0.2, 0.06, (0, 0, 1)), "UpperTorso", "leather")
        P(sf.box((0.26, 0.08, 0.18), loc=(sx * 0.57, -0.65, 3.5), bevel=0.03, segments=1), "UpperTorso", "brass")
    P(sf.box((1.3, 0.07, 0.2), loc=(0, -0.61, 3.3), bevel=0.02, segments=1), "UpperTorso", "leather")
    P(sf.torus(0.16, 0.045, loc=(0, -0.66, 3.3), rot=(90, 0, 0), major_segs=10, minor_segs=4), "UpperTorso", "brass")
    P(sf.box((2.06, 1.2, 0.3), loc=(0, 0, 2.36), bevel=0.05, segments=1), "LowerTorso", "leather")
    for i, x in enumerate((-0.86, -0.62, 0.7)):
        P(sf.torus(0.13, 0.035, loc=(x, -0.66, 2.16), rot=(90, 0, 14 * (i - 1)), major_segs=8, minor_segs=4), "LowerTorso", "brass")
    P(sf.box((0.4, 0.3, 0.46), loc=(0.2, -0.7, 2.06), bevel=0.1, segments=1), "LowerTorso", "sandstone")
    for sx, side in ((1, "Left"), (-1, "Right")):
        P(sf.box((0.92, 0.3, 0.5), loc=(sx * 0.5, -0.4, 1.22), bevel=0.12, segments=1), f"{side}LowerLeg", "leather")
        P(sf.box((0.6, 0.6, 0.4), loc=(sx * 1.5, 0.1, 3.0), bevel=0.12, segments=1), f"{side}UpperArm", "leather")
    gloves("leather", cuff="brass")
    # the rope: three coils worn across the body
    for i in range(3):
        P(squash(sf.torus(1.22 + i * 0.07, 0.11, loc=(0.02 * i, 0, 3.3 + i * 0.03), rot=(0, -36.87, 0), major_segs=22, minor_segs=6), sy=0.64), "UpperTorso",
          ("pine", "cream", "pine")[i])
    # the pack: what she brought up from the deep rides on top of it, still glowing
    P(sf.box((1.5, 0.8, 1.7), loc=(0, 1.02, 3.3), bevel=0.12, segments=2), "UpperTorso", "leather")
    P(sf.box((1.54, 0.84, 0.3), loc=(0, 1.02, 4.1), bevel=0.08, segments=1), "UpperTorso", "sandstone")
    for x in (-0.45, 0.45):
        P(sf.box((0.12, 0.05, 1.3), loc=(x, 1.44, 3.4), bevel=0.0), "UpperTorso", "walnut")
        P(sf.box((0.18, 0.07, 0.14), loc=(x, 1.45, 3.9), bevel=0.02, segments=1), "UpperTorso", "brass")
    for (b, t, r) in (((-0.55, 1.0, 4.2), (-1.05, 1.0, 6.0), 0.28), ((-0.2, 1.12, 4.2), (-0.32, 1.16, 6.5), 0.3), ((-0.95, 0.9, 4.2), (-1.75, 0.9, 5.3), 0.22),
                      ((0.4, 1.0, 4.2), (0.75, 1.0, 6.3), 0.26), ((0.75, 1.2, 4.2), (1.5, 1.2, 5.2), 0.2), ((-0.75, 1.3, 4.2), (-1.1, 1.4, 5.0), 0.16)):
        b, t = Vector(b), Vector(t)
        mid = b.lerp(t, 0.72)
        P(rod(b, mid, r, 5), "UpperTorso", "crystal", smooth_angle=None)
        P(rod(mid, t, r, 5, r_end=0.02), "UpperTorso", "crystal", smooth_angle=None)
        front = Vector((0.0, -r * 0.8, 0.0))                              # the light inside shows as a seam down the front
        glow(rod(b.lerp(t, 0.2) + front, b.lerp(t, 0.66) + front, r * 0.3, 4), "UpperTorso", "crystal")
    # the helmet: a carbide lamp burning crystal-blue, a spare lamp, a shard for luck
    dome("cream", r=0.84, z=5.36, flat_=0.76)
    brim("cream", r=0.92, z=5.3, deep=1.04, thick=0.06)
    P(sf.box((1.74, 0.16, 0.1), loc=(0, 0.02, 5.48), bevel=0.03, segments=1), "Head", "plum")
    P(sf.box((0.16, 1.8, 0.1), loc=(0, 0.02, 5.48), bevel=0.03, segments=1), "Head", "plum")
    P(sf.cyl(0.16, 0.36, loc=(0, -0.82, 5.62), verts=10, bevel=0.03, segments=1), "Head", "brass")
    P(sf.cyl(0.34, 0.16, loc=(0, -0.96, 5.72), rot=(84, 0, 0), verts=16, radius_top=0.2, bevel=0.0), "Head", "chrome")
    glow(sf.cyl(0.2, 0.05, loc=(0, -1.05, 5.72), rot=(84, 0, 0), verts=12, bevel=0.0), "Head", "crystal")
    glow(rod((0, -1.06, 5.72), (0, -1.36, 5.82), 0.08, 6, r_end=0.01), "Head", "crystal")
    P(sf.cyl(0.14, 0.2, loc=(0.74, -0.42, 5.56), rot=(80, 0, -30), verts=10, bevel=0.02, segments=1), "Head", "brass")
    glow(sf.cyl(0.1, 0.04, loc=(0.8, -0.52, 5.56), rot=(80, 0, -30), verts=10, bevel=0.0), "Head", "cream")
    glow(rod((-0.74, 0.1, 5.5), (-0.98, 0.2, 6.02), 0.1, 5, r_end=0.02), "Head", "crystal")
    P(sf.torus(0.12, 0.03, loc=(-0.78, 0.12, 5.56), rot=(0, 62, 0), major_segs=8, minor_segs=3), "Head", "leather")
    for sx in (-1, 1):
        P(band((sx * 0.72, -0.1, 5.24), (sx * 0.56, -0.56, 4.26), 0.1, 0.04, (sx, 0, 0)), "Head", "leather")
    # a lantern at her hip
    P(sf.cyl(0.2, 0.36, loc=(-1.08, -0.2, 1.86), verts=10, bevel=0.02, segments=1), "LowerTorso", "brass")
    glow(sf.cyl(0.16, 0.24, loc=(-1.08, -0.2, 1.86), verts=10, bevel=0.0), "LowerTorso", "crystal")
    P(sf.cyl(0.22, 0.08, loc=(-1.08, -0.2, 2.06), verts=10, radius_top=0.1, bevel=0.0), "LowerTorso", "brass")


def spelunker_props(H):
    # the Grapple, aimed at the roof, its line paying out
    H.reach("Left", (0.85, -0.95, 3.6))
    f = (UP * 0.96 + CAM_RIGHT * 0.28).normalized()
    M = held_item(H, "Left", "Tool_Grapple", f, CAM_RIGHT, scale=0.9)
    a, b = M @ Vector((0.0, 0.5, 0.3)), H.at("UpperTorso", (0.9, -0.62, 2.95))
    pts = [a, a.lerp(b, 0.45) + Vector((0.3, -0.1, -0.25)), b]
    for q0, q1 in zip(pts, pts[1:]):
        H.prop("Left", rod(q0, q1, 0.045, 6), "pine")


# ------------------------------------------------------------------------------------------
# Legendary: Tinkerer
# ------------------------------------------------------------------------------------------

GINGER = "#D2691E"


def tinkerer():
    drop(lambda o: o.get("sf_role") == "Hair")
    bare_chest()
    # ginger hair standing up in spikes, sideburns
    hair(sf.sphere(0.74, loc=(0, 0.12, 5.26), scale=(1.0, 1.0, 0.5), segs=14, rings=7), GINGER)
    for (x, y, tx, ty, tz, r) in ((-0.42, -0.3, -0.7, -0.5, 6.1, 0.26), (0.0, -0.36, 0.1, -0.7, 6.24, 0.3), (0.42, -0.28, 0.76, -0.4, 6.06, 0.26),
                                  (-0.3, 0.3, -0.56, 0.5, 6.16, 0.26), (0.3, 0.34, 0.5, 0.62, 6.2, 0.26), (0.0, 0.0, 0.06, 0.04, 6.4, 0.3),
                                  (-0.64, 0.5, -0.98, 0.84, 5.5, 0.2), (0.64, 0.5, 0.98, 0.84, 5.5, 0.2)):
        hair(spike((x, y, 5.36), (tx, ty, tz), r), GINGER)
    for sx in (-1, 1):
        hair(sf.box((0.1, 0.24, 0.5), loc=(sx * 0.69, -0.1, 4.9), bevel=0.0), GINGER)
    # a welding mask tipped back on the head, its window glowing; a jeweller's loupe flipped up on its arm
    P(sf.box((1.48, 1.4, 0.14), loc=(0, -0.02, 5.24), bevel=0.05, segments=1), "Head", "leather")
    P(sf.box((1.3, 0.16, 1.16), loc=(0, -0.62, 5.94), rot=(58, 0, 0), bevel=0.12, segments=2), "Head", "gunmetal")
    glow(sf.box((0.8, 0.06, 0.24), loc=(0, -0.86, 6.02), rot=(58, 0, 0), bevel=0.0), "Head", "crystal")
    P(sf.box((0.9, 0.08, 0.34), loc=(0, -0.82, 6.0), rot=(58, 0, 0), bevel=0.02, segments=1), "Head", "brass")
    for sx in (-1, 1):
        P(sf.cyl(0.13, 0.12, loc=(sx * 0.74, -0.3, 5.26), rot=(0, 90, 0), verts=8, bevel=0.02, segments=1), "Head", "brass")
        P(sf.sphere(0.05, loc=(sx * 0.5, -1.02, 6.3), segs=6, rings=4), "Head", "brass")
    P(rod((0.72, -0.3, 5.22), (0.52, -0.74, 5.4), 0.035, 5), "Head", "brass")
    P(sf.torus(0.2, 0.045, loc=(0.36, -0.8, 5.46), rot=(72, 0, 0), major_segs=12, minor_segs=4), "Head", "brass")
    P(sf.cyl(0.17, 0.05, loc=(0.36, -0.8, 5.46), rot=(72, 0, 0), verts=12, bevel=0.0), "Head", "skyblue")
    # rolled shirt sleeves under a leather apron of tools: a gauge, a pocket of drivers, a belt of bits
    arm_bands("cream", z=3.02, h=0.26)
    P(sf.box((1.5, 0.09, 1.2), loc=(0, -0.59, 3.1), bevel=0.04, segments=1), "UpperTorso", "leather")
    P(sf.box((1.56, 0.08, 1.3), loc=(0, -0.64, 1.86), rot=(4, 0, 0), bevel=0.04, segments=1), "LowerTorso", "leather")
    for sx in (-1, 1):
        P(band((sx * 0.6, -0.62, 3.66), (sx * 0.46, -0.3, 4.04), 0.14, 0.05, (0, -1, 0.4)), "UpperTorso", "walnut")
        P(sf.sphere(0.06, loc=(sx * 0.62, -0.66, 3.6), segs=6, rings=4), "UpperTorso", "brass")
    P(sf.cyl(0.24, 0.1, loc=(-0.38, -0.66, 3.36), rot=(90, 0, 0), verts=14, bevel=0.02, segments=1), "UpperTorso", "brass")
    P(sf.cyl(0.19, 0.04, loc=(-0.38, -0.72, 3.36), rot=(90, 0, 0), verts=14, bevel=0.0), "UpperTorso", "cream")
    P(sf.box((0.03, 0.03, 0.17), loc=(-0.34, -0.75, 3.4), rot=(0, 40, 0), bevel=0.0), "UpperTorso", "rust")
    glow(sf.sphere(0.055, loc=(-0.38, -0.7, 3.04), segs=6, rings=4), "UpperTorso", "crystal")
    P(sf.box((0.7, 0.07, 0.44), loc=(0.34, -0.65, 3.16), bevel=0.02, segments=1), "UpperTorso", "walnut")
    for i, (sw, h) in enumerate((("rust", 0.42), ("teal", 0.34), ("hazard", 0.46), ("steel", 0.3))):
        x = 0.1 + i * 0.16
        P(rod((x, -0.68, 3.3), (x, -0.68, 3.3 + h), 0.045, 6), "UpperTorso", sw)
        P(rod((x, -0.68, 3.3 + h), (x, -0.68, 3.42 + h), 0.02, 4), "UpperTorso", "chrome")
    P(sf.box((2.06, 1.2, 0.24), loc=(0, 0, 2.36), bevel=0.05, segments=1), "LowerTorso", "walnut")
    for i, x in enumerate((-0.7, -0.44, 0.5, 0.76)):
        P(sf.box((0.18, 0.12, 0.5), loc=(x, -0.72, 2.1), bevel=0.03, segments=1), "LowerTorso", ("steel", "brass", "copper", "steel")[i])
    gloves("leather", cuff="brass")
    # the rig on his back: a boiler, a gear, a stack that glows, and two arms of his own making
    straps("walnut", width=0.24)
    P(sf.box((1.6, 0.9, 1.7), loc=(0, 1.05, 3.3), bevel=0.12, segments=2), "UpperTorso", "gunmetal")
    P(sf.cyl(0.42, 1.2, loc=(0, 1.55, 3.3), verts=14, bevel=0.1, segments=2), "UpperTorso", "copper")
    for z in (2.9, 3.3, 3.7):
        P(sf.torus(0.44, 0.04, loc=(0, 1.55, z), major_segs=14, minor_segs=4), "UpperTorso", "brass")
    P(flat_at(star_xz(0, 0, 0.42, 0.3, 8), 0.1, (-0.56, 1.56, 4.02), yaw=180), "UpperTorso", "brass")
    P(sf.cyl(0.12, 0.14, loc=(-0.56, 1.62, 4.02), rot=(90, 0, 0), verts=8, bevel=0.0), "UpperTorso", "gunmetal")
    P(sf.cyl(0.16, 0.9, loc=(0.52, 1.2, 4.5), verts=10, bevel=0.0), "UpperTorso", "copper")
    P(sf.cyl(0.21, 0.12, loc=(0.52, 1.2, 4.96), verts=10, bevel=0.02, segments=1), "UpperTorso", "brass")
    glow(sf.cyl(0.13, 0.06, loc=(0.52, 1.2, 5.02), verts=10, bevel=0.0), "UpperTorso", "crystal")
    for sx in (-1, 1):
        base = Vector((sx * 0.74, 1.0, 4.1))
        elbow = Vector((sx * 2.0, 0.7, 5.9))
        wrist = Vector((sx * 1.7, -0.1, 6.62))
        P(sf.sphere(0.24, loc=base, segs=10, rings=6), "UpperTorso", "brass")
        P(rod(base, elbow, 0.12, 8), "UpperTorso", "steel")
        a, b = base.lerp(elbow, 0.12) + Vector((0, 0.2, 0.0)), base.lerp(elbow, 0.86) + Vector((0, 0.2, 0.0))
        P(rod(a, a.lerp(b, 0.55), 0.075, 6), "UpperTorso", "copper")                 # the piston
        P(rod(a.lerp(b, 0.5), b, 0.04, 6), "UpperTorso", "chrome")
        P(sf.sphere(0.2, loc=elbow, segs=10, rings=6), "UpperTorso", "brass")
        P(rod(elbow, wrist, 0.1, 8), "UpperTorso", "steel")
        for t in (0.3, 0.6):
            q = elbow.lerp(wrist, t)
            P(rod(q, q + (wrist - elbow).normalized() * 0.1, 0.13, 8), "UpperTorso", "copper")
        P(sf.sphere(0.16, loc=wrist, segs=8, rings=5), "UpperTorso", "brass")
        tool = Vector((sx * -0.72, -0.5, 0.06)).normalized()
        if sx > 0:      # a claw, with a gear it has just made
            for k in (-1, 1):
                side = Vector((0.0, 0.0, 1.0)) * k
                P(rod(wrist, wrist + tool * 0.26 + side * 0.26, 0.05, 5), "UpperTorso", "steel")
                P(rod(wrist + tool * 0.26 + side * 0.26, wrist + tool * 0.62 + side * 0.1, 0.045, 5, r_end=0.012), "UpperTorso", "steel")
            g = wrist + tool * 0.66
            P(flat_at(star_xz(0, 0, 0.3, 0.21, 8), 0.07, g, yaw=CAM_YAW), "UpperTorso", "brass")
            P(_aim(sf.cyl(0.09, 0.09, verts=8, bevel=0.0), g + TO_CAM * 0.0, g + TO_CAM * 0.06), "UpperTorso", "gunmetal")
        else:           # a torch, lit
            P(rod(wrist, wrist + tool * 0.5, 0.08, 6), "UpperTorso", "copper")
            P(rod(wrist + tool * 0.42, wrist + tool * 0.56, 0.11, 6, r_end=0.06), "UpperTorso", "brass")
            flame(lambda o, sw: glow(o, "UpperTorso", sw), wrist + tool * 0.56, tool, length=0.6, r=0.1, outer="crystal", core="cream",
                  sparks=((0.1, -0.1, 0.2), (0.2, 0.0, -0.18), (-0.06, -0.1, -0.26), (0.26, -0.05, 0.08)), spark="hazard")


def tinkerer_props(H):
    # the Power Wrench in his hand, and the drone he built at his shoulder
    H.reach("Right", (-1.45, -0.78, 3.3))
    held_item(H, "Right", "Weapon_PowerWrench", UP - CAM_RIGHT * 0.16, CAM_RIGHT, scale=0.8)
    d = H.at("UpperTorso", (1.7, -0.6, 5.15))
    item("Prop_CombatDrone", d, TO_CAM * 0.9 - CAM_RIGHT * 0.45, UP + TO_CAM * 0.3 - CAM_RIGHT * 0.12, "LeftHand", "PropLeftHand", "PropGlowLeftHand",
         scale=0.58, category="Props")


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

NEW_OUTFITS = {
    "Survivor": {
        "rarity": "Common", "base": "teal", "skin": "#C58F6A", "hair": "#5B3A24",
        "build": survivor, "props": survivor_props,
        "pose": {"RightUpperArm": (-58, 20, 6), "RightLowerArm": (-70, 0, 0), "LeftUpperArm": (-4, 0, 12), "LeftLowerArm": (-24, 0, 0),
                 "Head": (-2, 4, -8), "UpperTorso": (0, 2, -4)},
        "framing": (4.6, 1.86),
    },
    "Engineer": {
        "rarity": "Common", "base": "gunmetal", "skin": "#A9744F", "hair": "#3B2A1E",
        "build": engineer, "props": engineer_props,
        "pose": {"RightUpperArm": (-58, 20, 6), "RightLowerArm": (-70, 0, 0), "LeftUpperArm": (-6, 0, 14), "LeftLowerArm": (-34, 0, 0),
                 "Head": (0, -4, -6), "UpperTorso": (0, -2, -4)},
        "framing": (4.6, 1.9, -0.12),
    },
    "Medic": {
        "rarity": "Common", "base": "porcelain", "skin": "#E8B893", "hair": "#7A4A2B",
        "build": medic, "props": medic_props,
        "pose": {"LeftUpperArm": (-38, -30, 0), "LeftLowerArm": (-112, 0, 0), "RightUpperArm": (-6, 0, -10), "RightLowerArm": (-30, 0, 0),
                 "Head": (-4, 6, 8), "UpperTorso": (0, 4, -2)},
        "framing": (4.5, 1.8),
    },
    "Firefighter": {
        "rarity": "Common", "base": "basalt", "skin": "#C98E66", "hair": "#2A1E16",
        "build": firefighter, "props": firefighter_props,
        "pose": {"RightUpperArm": (-40, 10, 0), "RightLowerArm": (-100, 0, 0), "LeftUpperArm": (-4, 0, 14), "LeftLowerArm": (-26, 0, 0),
                 "Head": (0, -4, -6), "UpperTorso": (0, -2, 0)},
        "framing": (4.62, 1.95, -0.15),
    },
    "Cook": {
        "rarity": "Common", "base": "porcelain", "skin": "#D9A679", "hair": "#1E1A17",
        "build": cook, "props": cook_props,
        "pose": {"LeftUpperArm": (-38, -30, 0), "LeftLowerArm": (-100, 0, 0), "RightUpperArm": (-8, 0, -12), "RightLowerArm": (-34, 0, 0),
                 "Head": (-2, 6, 8), "UpperTorso": (0, 4, -2)},
        "framing": (4.86, 2.16, 0.25),
    },
    "Scout": {
        "rarity": "Common", "base": "pine", "skin": "#F0C4A0", "hair": "#C98A3C",
        "build": scout, "props": scout_props,
        "pose": {"LeftUpperArm": (-50, -40, 0), "LeftLowerArm": (-96, 0, 0), "RightUpperArm": (-6, 0, -10), "RightLowerArm": (-30, 0, 0),
                 "Head": (-6, 6, 10), "UpperTorso": (0, 4, 0)},
        "framing": (4.6, 2.05),
    },
    "RadioOperator": {
        "rarity": "Rare", "base": "murk", "skin": "#B9825A", "hair": "#1E1A17",
        "build": radio_operator, "props": radio_operator_props,
        "pose": {"LeftUpperArm": (-38, -30, 0), "LeftLowerArm": (-112, 0, 0), "RightUpperArm": (-6, 0, -10), "RightLowerArm": (-30, 0, 0),
                 "Head": (-2, 6, 8), "UpperTorso": (0, 4, -2)},
        "framing": (4.84, 2.14),
    },
    "HazmatTech": {
        "rarity": "Rare", "base": "hazard", "skin": "#E0AC86", "hair": "#5B3A24",
        "build": hazmat_tech, "props": hazmat_tech_props,
        "pose": {"LeftUpperArm": (-38, -30, 0), "LeftLowerArm": (-112, 0, 0), "RightUpperArm": (-6, 0, -12), "RightLowerArm": (-30, 0, 0),
                 "Head": (0, 6, 8), "UpperTorso": (0, 4, -2)},
        "framing": (4.5, 1.84, 0.1),
    },
    "Exterminator": {
        "rarity": "Rare", "base": "ash", "skin": "#C58F6A", "hair": "#5B3A24",
        "build": exterminator, "props": exterminator_props,
        "pose": {"RightUpperArm": (-40, 10, 0), "RightLowerArm": (-90, 0, 0), "LeftUpperArm": (-4, 0, 14), "LeftLowerArm": (-28, 0, 0),
                 "Head": (0, -6, -6), "UpperTorso": (0, -4, 0)},
        "framing": (4.72, 2.0),
    },
    "Marksman": {
        "rarity": "Rare", "base": "forest", "skin": "#8D5A3B", "hair": "#3B2F2A",
        "build": marksman, "props": marksman_props,
        "pose": {"RightUpperArm": (-40, 10, 0), "RightLowerArm": (-100, 0, 0), "LeftUpperArm": (-4, 0, 12), "LeftLowerArm": (-26, 0, 0),
                 "Head": (0, -8, -8), "UpperTorso": (0, -4, 0)},
        "framing": (4.7, 1.96, -0.12),
    },
    "Driller": {
        "rarity": "Rare", "base": "walnut", "skin": "#D9A679", "hair": "#2B2B2B",
        "build": driller, "props": driller_props,
        "pose": {"LeftUpperArm": (-44, -10, 0), "LeftLowerArm": (-96, 0, 0), "RightUpperArm": (-4, 0, -14), "RightLowerArm": (-28, 0, 0),
                 "Head": (0, 4, 6), "UpperTorso": (0, 2, 0)},
        "framing": (4.68, 1.98, 0.22),
    },
    "Scavenger": {
        "rarity": "Rare", "base": "stone", "skin": "#E8B893", "hair": "#8A5A2B",
        "build": scavenger, "props": scavenger_props,
        "pose": {"LeftUpperArm": (-44, -34, 0), "LeftLowerArm": (-104, 0, 0), "RightUpperArm": (-6, 0, -10), "RightLowerArm": (-30, 0, 0),
                 "Head": (-4, 8, 10), "UpperTorso": (0, 4, -2)},
        "framing": (4.74, 2.0),
    },
    "Demolitionist": {
        "rarity": "Epic", "base": "olive", "skin": "#E0AC86", "hair": "#8A4B22",
        "build": demolitionist, "props": demolitionist_props,
        "pose": {"LeftUpperArm": (-36, -30, 0), "LeftLowerArm": (-100, 0, 0), "RightUpperArm": (-8, 0, -14), "RightLowerArm": (-34, 0, 0),
                 "Head": (0, 6, 8), "UpperTorso": (0, 4, -2)},
        "framing": (4.6, 1.96),
    },
    "Spelunker": {
        "rarity": "Epic", "base": "plum", "skin": "#F0C4A0", "hair": "#D8B24A",
        "build": spelunker, "props": spelunker_props,
        "pose": {"LeftUpperArm": (-44, -10, 0), "LeftLowerArm": (-96, 0, 0), "RightUpperArm": (-6, 0, -12), "RightLowerArm": (-30, 0, 0),
                 "Head": (-4, 6, 8), "UpperTorso": (0, 2, 0)},
        "framing": (4.76, 2.04, 0.1),
    },
    "Tinkerer": {
        "rarity": "Legendary", "base": "avocado", "skin": "#F1C7A5", "hair": GINGER,
        "build": tinkerer, "props": tinkerer_props,
        "pose": {"RightUpperArm": (-50, 18, 4), "RightLowerArm": (-84, 0, 0), "LeftUpperArm": (-6, 0, 16), "LeftLowerArm": (-40, 0, 0),
                 "Head": (-4, 4, 6), "UpperTorso": (0, 2, 0)},
        "framing": (4.95, 2.2, 0.12),
    },
}
OUTFITS.update(NEW_OUTFITS)
