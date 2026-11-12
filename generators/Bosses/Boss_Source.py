"""Boss_Source: the Source itself (bible Section 3: "a glowing mass deep underground that changed
every living thing near it"; Section 10: "Rises into the bunker, or is fought earlier in its
chamber at depth 10. Several phases: tendrils in many rooms at once, then the core"). The intro
cutscene ends on its eyes opening in the dark, and this is what they belong to: a mound of plum
and basalt flesh, veined with its own light, around one Great Eye as tall as a resident. The
Great Eye is the core. Shut, it is behind two armoured lids that close like jaws, with a row of
fangs each; open, it is the only soft thing on it. Two arms like tree roots plant on the floor
beside it and hammer down; lesser eyes look out of its brow and shoulders the whole time.

About 21 studs across the arms, 12.5 tall and 15 deep: it fills a dug cell.

Rig: Body (root), Eye and Pupil, LidUpper, LidLower, LeftArm/LeftFore, RightArm/RightFore,
LeftBack, RightBack. Clips: Idle (shut), Open, OpenIdle, Close, Attack (both arms come down:
Hit at 0.9 s, eye open), Slam (the same blow with the lids shut), Roar, Stagger (the lids clamp
half shut), Death.

Run:  SF_EXPORT=1 python3 generators/Bosses/Boss_Source.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Monsters"))
import _beast as B  # noqa: E402
from _beast import sf, limb, blob, shard, claw, shell, cluster  # noqa: E402,F401

ASSET, CATEGORY = "Boss_Source", "Bosses"
HIT_TIME = 0.9
E = sf.Vector((0.0, -4.2, 6.0))          # the Great Eye's centre
LID = (3.55, 2.25, 3.05)                 # the lids' ellipsoid about it
OPEN_UP, OPEN_DOWN = -58.0, 46.0         # how far each lid swings open (bone X)

SHOULDER = {1: sf.Vector((5.6, -1.2, 5.4)), -1: sf.Vector((-5.6, -1.2, 5.4))}
ELBOW = {1: sf.Vector((8.9, -3.4, 7.0)), -1: sf.Vector((-8.9, -3.4, 7.0))}
HAND = {1: sf.Vector((9.9, -6.8, 0.5)), -1: sf.Vector((-9.9, -6.8, 0.5))}
BACK = {1: sf.Vector((4.6, 3.6, 3.6)), -1: sf.Vector((-4.6, 3.6, 3.6))}

JOINTS = [
    ("Body", None, (0, 0, 3.0)),
    ("Eye", "Body", tuple(E)),
    ("Pupil", "Eye", tuple(E + sf.Vector((0, -1.2, 0)))),
    ("LidUpper", "Body", tuple(E)),
    ("LidLower", "Body", tuple(E)),
    ("LeftArm", "Body", tuple(SHOULDER[1])), ("LeftFore", "LeftArm", tuple(ELBOW[1])),
    ("RightArm", "Body", tuple(SHOULDER[-1])), ("RightFore", "RightArm", tuple(ELBOW[-1])),
    ("LeftBack", "Body", tuple(BACK[1])), ("RightBack", "Body", tuple(BACK[-1])),
]


def lid_edge(t_deg, z=0.0):
    """A point on the lids' meeting line (the eye's equator, front half): t 0 = its left corner
    (+X), 90 = dead front, 180 = its right corner."""
    t = math.radians(t_deg)
    return E + sf.Vector((LID[0] * math.cos(t), -LID[1] * math.sin(t), z))


def small_eye(b, at, r, facing, name):
    f = sf.Vector(facing).normalized()
    b.part(sf.sphere(r * 1.55, loc=sf.Vector(at) - f * r * 0.5, segs=8, rings=5), "Body", "rubber")
    b.glow(sf.sphere(r, loc=sf.Vector(at) + f * r * 0.25, segs=8, rings=5), "Body", name)
    slit = sf.box((r * 0.3, r * 0.3, r * 1.5), loc=sf.Vector(at) + f * r * 1.12, bevel=0.02, segments=1)
    slit.rotation_euler = f.to_track_quat("-Y", "Z").to_euler()
    b.part(slit, "Body", "rubber")


def build(b):
    rnd = random.Random(100)

    # ---- the mass: lumps of plum and basalt flesh heaped round the eye
    lumps = [  # (radius, centre, scale, swatch)
        (5.6, (0.0, 0.6, 5.3), (1.3, 1.08, 0.98), "plum"),          # the heart of it
        (3.9, (4.9, 0.2, 4.3), (1.05, 1.1, 1.0), "basalt"),         # shoulders
        (3.9, (-4.9, 0.2, 4.3), (1.05, 1.1, 1.0), "basalt"),
        (4.2, (0.0, 3.6, 7.0), (1.2, 1.0, 0.95), "basalt"),         # the hump behind the brow
        (3.1, (3.3, -1.6, 9.0), (1.0, 0.95, 0.85), "plum"),         # brow, left and right
        (3.1, (-3.3, -1.6, 9.0), (1.0, 0.95, 0.85), "plum"),
        (2.9, (0.0, -3.3, 2.0), (1.5, 0.9, 0.8), "basalt"),         # the chin under the eye
        (3.2, (5.6, 3.8, 2.6), (1.1, 1.0, 0.85), "plum"),           # haunches
        (3.2, (-5.6, 3.8, 2.6), (1.1, 1.0, 0.85), "plum"),
        (3.0, (0.0, 6.2, 3.2), (1.3, 0.9, 0.9), "plum"),
        (2.4, (6.9, -2.6, 2.0), (1.0, 1.0, 0.8), "plum"),           # where it meets the floor
        (2.4, (-6.9, -2.6, 2.0), (1.0, 1.0, 0.8), "plum"),
    ]
    for i, (r, c, sc, sw) in enumerate(lumps):
        b.part(blob(r, c, scale=sc, segs=13, rings=8, noise=0.085, seed=200 + i), "Body", sw, smooth_angle=None)
    # warts and nodules over it, so no lump is a balloon
    for i in range(34):
        r, c, sc, _sw = lumps[i % len(lumps)]
        d = sf.Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.9), rnd.uniform(-0.1, 1))).normalized()
        at = sf.Vector(c) + sf.Vector((d.x * r * sc[0], d.y * r * sc[1], d.z * r * sc[2])) * 0.97
        if at.z < 0.6 or (abs(at.x) < 4.6 and at.y < -2.6 and 2.2 < at.z < 9.8):
            continue                                                                        # not under the floor, not across the eye
        b.part(blob(rnd.uniform(0.45, 0.95), at, scale=(1.0, 1.0, 0.7), segs=6, rings=4, noise=0.12, seed=700 + i), "Body",
               ("rubber", "murk", "basalt", "plum")[i % 4], smooth_angle=None)
    # folds between the lumps, dark
    for i, (c, r) in enumerate((((2.9, -0.4, 6.6), 1.5), ((-2.9, -0.4, 6.6), 1.5), ((0.0, 1.6, 9.6), 1.9), ((4.4, 2.6, 5.4), 1.6),
                                ((-4.4, 2.6, 5.4), 1.6))):
        b.part(blob(r, c, scale=(1.0, 1.0, 0.8), segs=8, rings=5, noise=0.08, seed=260 + i), "Body", "rubber")

    # ---- the socket: a heavy brow ring the lids hinge in
    b.part(sf.torus(3.75, 0.82, loc=E + sf.Vector((0, 0.9, 0)), rot=(90, 0, 0), major_segs=18, minor_segs=7), "Body", "basalt")
    for i in range(10):                                                                     # scutes round the socket
        a = math.tau * (i + 0.5) / 10
        at = E + sf.Vector((math.cos(a) * 4.3, 0.55, math.sin(a) * 3.75))
        plate = blob(0.95, at, scale=(1.0, 0.5, 0.75), segs=7, rings=4, noise=0.07, seed=300 + i)
        plate.rotation_euler = (0, -a + math.pi / 2, 0)
        b.part(plate, "Body", "gunmetal" if i % 2 else "rubber")
    b.part(sf.torus(3.15, 0.5, loc=E + sf.Vector((0, 0.15, 0)), rot=(90, 0, 0), major_segs=16, minor_segs=5), "Body", "rust")   # the raw rim
    for sx in (-1, 1):                                                                      # the hinges at its corners
        b.part(blob(1.0, E + sf.Vector((sx * 3.7, 0.5, 0)), scale=(0.8, 1.0, 1.0), segs=8, rings=5, seed=320), "Body", "gunmetal")

    # ---- the Great Eye: the core
    eye = sf.sphere(2.75, loc=E + sf.Vector((0, 0.35, 0)), scale=(1.18, 0.62, 0.98), segs=20, rings=12)
    sf.tag(eye, "Eye", "glow", "Neon", collision="queryhull", cast_shadow=False, role="WeakPoint")
    eye["sf_bone"] = "Eye"
    sf.bind(eye, b.arm, "Eye")
    b.part(sf.torus(1.55, 0.2, loc=E + sf.Vector((0, -1.22, 0)), rot=(90, 0, 0), major_segs=14, minor_segs=4), "Eye", "forest")   # iris
    b.part(sf.sphere(1.0, loc=E + sf.Vector((0, -1.36, 0)), scale=(0.46, 0.22, 1.85), segs=10, rings=8), "Pupil", "rubber")   # the slit

    # ---- the lids: two armoured shells that shut like jaws
    for bone, flip, swatch in (("LidUpper", 0, "basalt"), ("LidLower", 180, "basalt")):
        b.part(shell(LID, E, -1.0, -0.06, z_from=0.02, thickness=0.42, segs=18, rings=12, rot=(0, flip, 0)), bone, swatch)
        sgn = 1 if flip == 0 else -1
        # ridges banding the lid, and a keel down its middle
        for k, zf in enumerate((0.3, 0.58, 0.82)):
            zz = sgn * LID[2] * zf
            shrink = math.sqrt(max(1.0 - zf * zf, 0.05))
            pts = [E + sf.Vector(((LID[0] + 0.3) * shrink * math.cos(math.radians(t)), -(LID[1] + 0.34) * shrink * math.sin(math.radians(t)), zz))
                   for t in range(16, 165, 21)]
            b.part(limb(pts, [0.2] + [0.3 - 0.04 * k] * (len(pts) - 2) + [0.2], sides=5, resolution=1), bone, "gunmetal" if k % 2 == 0 else "rubber")
        keel = [E + sf.Vector((0, -(LID[1] + 0.42) * math.sqrt(max(1 - zf * zf, 0.02)), sgn * LID[2] * zf)) for zf in (0.12, 0.4, 0.66, 0.88)]
        b.part(limb(keel, [0.34, 0.38, 0.3, 0.2], sides=5, resolution=1), bone, "gunmetal")
        for zf in (0.34, 0.62):
            at = E + sf.Vector((0, -(LID[1] + 0.5) * math.sqrt(1 - zf * zf), sgn * LID[2] * zf))
            b.part(shard(at, sf.Vector((0, -1.0, sgn * 0.55)), 1.3, 0.26, sides=4, tip=0.06), bone, "cream")
        # fangs along its edge; the two rows mesh when it shuts
        for i in range(8):
            t = 24 + i * 19 + (0 if flip == 0 else 9.5)
            if t > 160:
                continue
            p = lid_edge(t, z=sgn * 0.3)
            ln = 2.3 - 1.0 * abs(math.cos(math.radians(t)))
            out = sf.Vector((math.cos(math.radians(t)) * 0.1, -math.sin(math.radians(t)) * 0.34, -sgn * 1.0))
            b.part(shard(p + sf.Vector((0, -0.12 * math.sin(math.radians(t)), sgn * 0.2)), out, ln, 0.34, sides=4, tip=0.05, waist=0.16), bone, "cream")
        # gum under the lid's edge
        gum = [lid_edge(t, z=sgn * 0.42) + sf.Vector((0, 0.16 * math.sin(math.radians(t)), 0)) for t in range(14, 167, 19)]
        b.part(limb(gum, [0.26] * len(gum), sides=5, resolution=1), bone, "rust")
        # a seam of light where it meets the eye
        pts = [lid_edge(t, z=sgn * 0.34) + sf.Vector((0, -0.05, 0)) for t in range(20, 161, 20)]
        b.glow(limb(pts, [0.07] * len(pts), sides=3, resolution=1), bone, "LidGlow")

    # ---- the arms: roots as thick as a resident, planted either side
    for sx, upper, fore in ((1, "LeftArm", "LeftFore"), (-1, "RightArm", "RightFore")):
        sh, el, hd = SHOULDER[sx], ELBOW[sx], HAND[sx]
        b.part(blob(2.0, sh, segs=10, rings=6, noise=0.05, seed=400), upper, "basalt")
        mid = (sh + el) / 2 + sf.Vector((0, 0, 0.5))
        b.part(limb([sh, mid, el], [1.55, 1.42, 1.2], sides=9, resolution=2), upper, "plum")
        for k in range(3):                                                                  # thorns along the top of it
            at, d = B.along([sh, mid, el], 0.3 + 0.25 * k)
            b.part(shard(at + sf.Vector((0, 0, 1.1)), sf.Vector((sx * 0.3, 0.2, 1.0)), 1.3 - 0.2 * k, 0.24, sides=4, tip=0.06), upper, "cream")
        b.part(blob(1.5, el, segs=9, rings=6, noise=0.06, seed=410), fore, "basalt")
        knee = el + (hd - el) * 0.5 + sf.Vector((sx * 0.5, -0.3, 0.2))
        b.part(limb([el, knee, hd + sf.Vector((0, 0, 0.5))], [1.2, 1.05, 0.95], sides=9, resolution=2), fore, "plum")
        b.part(shard(el + sf.Vector((sx * 0.4, 0.3, 0.9)), sf.Vector((sx * 0.5, 0.6, 1.0)), 2.3, 0.4, sides=4, tip=0.06), fore, "cream")   # elbow spur
        for k in range(3):                                                                  # bands of hide down the forearm
            at, d = B.along([el, knee, hd + sf.Vector((0, 0, 0.5))], 0.25 + 0.24 * k)
            band = sf.torus(1.14 - 0.05 * k, 0.2, loc=at, major_segs=9, minor_segs=4)
            band.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            b.part(band, fore, "rubber" if k % 2 else "gunmetal")
        b.part(blob(1.25, hd + sf.Vector((0, 0, 0.5)), scale=(1.1, 1.2, 0.75), segs=9, rings=5, noise=0.06, seed=420), fore, "basalt")
        for k, a in enumerate((-55, -15, 25)):                                              # three claws dug into the floor
            ar = math.radians(a) * sx
            d = sf.Vector((math.sin(ar) * 1.0 + sx * 0.25, -math.cos(ar), 0.1))
            b.part(claw(hd + sf.Vector((d.x * 0.7, d.y * 0.7, 0.75)), d, 2.5, 0.42, bend=(0, 0, -1), curl=0.42, sides=6, resolution=2), fore, "cream")
        for k in range(2):                                                                  # light running down it
            a0, _ = B.along([sh, mid, el], 0.15)
            a1, _ = B.along([sh, mid, el], 0.85)
            off = sf.Vector((0, -1.25 if k == 0 else 1.2, 0.5))
            b.glow(limb([a0 + off, (a0 + a1) / 2 + off * 1.08, a1 + off * 0.8], [0.09, 0.11, 0.08], sides=3, resolution=1), upper, "ArmGlow")
        b.glow(limb([el + sf.Vector((0, -1.0, 0.2)), knee + sf.Vector((0, -0.95, 0)), hd + sf.Vector((0, -0.6, 1.0))], [0.09, 0.1, 0.07],
                    sides=3, resolution=1), fore, "ArmGlow")

    # ---- two lesser roots behind, feeling over the floor
    for sx, bone in ((1, "LeftBack"), (-1, "RightBack")):
        p = BACK[sx]
        pts = [p, p + sf.Vector((sx * 2.6, 1.6, -0.6)), p + sf.Vector((sx * 4.9, 2.9, -2.4)), p + sf.Vector((sx * 6.6, 3.5, -3.3))]
        b.part(limb(pts, [1.3, 1.05, 0.7, 0.3], sides=8, resolution=2), bone, "plum" if sx > 0 else "basalt")
        for k in range(3):
            at, d = B.along(pts, 0.25 + 0.22 * k)
            b.part(shard(at + sf.Vector((0, 0, 0.75 - 0.15 * k)), sf.Vector((0, 0.3, 1.0)), 0.9 - 0.15 * k, 0.17, sides=4, tip=0.06), bone, "cream")
        b.glow(limb([pts[0] + sf.Vector((0, 0, 1.1)), pts[1] + sf.Vector((0, 0, 0.95)), pts[2] + sf.Vector((0, 0, 0.65))], [0.08, 0.09, 0.06],
                    sides=3, resolution=1), bone, "BackGlow")

    # ---- a crown of bone on the hump, and scutes down its back
    for o in cluster((0.0, 2.8, 10.2), (0.0, 0.3, 1.0), 7, 3.4, 0.6, spread=0.7, seed=5, sides=5):
        b.part(o, "Body", "cream")
    for sx in (-1, 1):
        for o in cluster((sx * 3.7, 1.0, 10.5), (sx * 0.5, 0.25, 1.0), 4, 2.3, 0.42, spread=0.7, seed=6 + sx, sides=4):
            b.part(o, "Body", "cream")
    # eye-stalks: four of its lesser eyes stand up out of it to look over the room
    for i, (root, top) in enumerate((((6.4, 1.8, 5.6), (8.2, 0.2, 10.6)), ((-6.4, 1.8, 5.6), (-8.0, 0.6, 11.0)),
                                     ((3.0, 5.0, 8.2), (4.6, 5.6, 12.2)), ((-3.2, 5.0, 8.2), (-4.4, 6.2, 11.6)))):
        r0, t0 = sf.Vector(root), sf.Vector(top)
        mid = (r0 + t0) / 2 + sf.Vector((0, 1.0, 0.4))
        b.part(limb([r0, mid, t0], [0.62, 0.42, 0.3], sides=6, resolution=2), "Body", "plum" if i % 2 else "murk")
        facing = sf.Vector((t0.x * 0.06, -1.0, -0.25))
        small_eye(b, t0, 0.6, facing, "StalkGlow")
    for i in range(6):
        at = (rnd.uniform(-3.2, 3.2), 5.2 + i * 0.5, 8.4 - i * 1.15)
        plate = blob(1.3, at, scale=(1.3, 0.55, 0.7), segs=7, rings=4, noise=0.07, seed=500 + i)
        plate.rotation_euler = (math.radians(-38), 0, 0)
        b.part(plate, "Body", "gunmetal" if i % 2 else "rubber")

    # ---- its lesser eyes: seven, never shut
    for i, (at, r, facing) in enumerate((
            ((2.6, -3.9, 10.2), 0.62, (0.25, -1.0, 0.45)), ((-2.9, -3.8, 10.0), 0.5, (-0.3, -1.0, 0.4)),
            ((5.3, -3.0, 7.2), 0.55, (0.6, -1.0, 0.15)), ((-5.4, -2.9, 7.0), 0.66, (-0.6, -1.0, 0.1)),
            ((6.6, -2.4, 4.3), 0.45, (0.7, -1.0, -0.1)), ((-6.4, -2.6, 4.6), 0.4, (-0.7, -1.0, 0.0)),
            ((0.6, -4.6, 10.9), 0.42, (0.0, -1.0, 0.6)))):
        small_eye(b, at, r, facing, "HeadGlow")

    # ---- veins of its own light, from the socket out over the mass
    for i in range(12):
        a = math.tau * i / 12 + rnd.uniform(-0.12, 0.12)
        c, s = math.cos(a), math.sin(a)
        p0 = E + sf.Vector((c * 4.55, 0.75, s * 3.95))
        p1 = E + sf.Vector((c * 6.3 + rnd.uniform(-0.5, 0.5), 2.2, s * 5.0 + rnd.uniform(-0.4, 0.4)))
        p2 = E + sf.Vector((c * 7.2 + rnd.uniform(-0.6, 0.6), 4.6, s * 5.3 + rnd.uniform(-0.5, 0.5)))
        if p2.z < 0.5:
            p2.z = 0.5
        if p1.z < 0.6:
            p1.z = 0.6
        b.glow(limb([p0, p1, p2], [0.12, 0.1, 0.06], sides=3, resolution=1), "Body", "VeinGlow")

    # ---- the floor it came up through
    for i in range(16):
        a = math.tau * i / 16 + rnd.uniform(-0.1, 0.1)
        rx, ry = 9.4 + rnd.uniform(-0.6, 0.8), 7.4 + rnd.uniform(-0.5, 0.7)
        if abs(math.cos(a)) > 0.86 and math.sin(a) < 0.2:
            continue                                                                        # the arms plant there
        slab = sf.box((rnd.uniform(1.6, 2.4), rnd.uniform(1.6, 2.3), 0.4), loc=(math.cos(a) * rx, math.sin(a) * ry + 0.8, 0.4), bevel=0.04, segments=1)
        slab.rotation_euler = (math.radians(rnd.uniform(18, 40)), 0, a - math.pi / 2)
        b.part(slab, "Body", "stone" if i % 3 else "ash")
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        b.part(blob(rnd.uniform(0.4, 0.7), (math.cos(a) * 10.6, math.sin(a) * 8.6 + 0.8, 0.25), scale=(1.2, 1.0, 0.6), segs=5, rings=3,
                    noise=0.2, seed=600 + i), "Body", "basalt" if i % 2 else "stone")


# ---- clips --------------------------------------------------------------------------------------

def lids(b, f, k, ease="SINE"):
    """k = 0 shut, 1 wide open."""
    b.key("LidUpper", f, (OPEN_UP * k, 0, 0), ease=ease)
    b.key("LidLower", f, (OPEN_DOWN * k, 0, 0), ease=ease)


def arms(b, f, lift=0.0, fold=0.0, spread=0.0, ease="SINE"):
    """lift: the upper arms swing up and back (degrees); fold: the forearms bend in under them."""
    b.key("LeftArm", f, (-lift, 0, spread), ease=ease)
    b.key("RightArm", f, (-lift, 0, -spread), ease=ease)
    b.key("LeftFore", f, (-fold, 0, 0), ease=ease)
    b.key("RightFore", f, (-fold, 0, 0), ease=ease)


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 100, loop=True, priority="Idle")
    for f, k in ((0, 0), (25, 1), (50, 0), (75, -1), (100, 0)):
        b.key("Body", f, (0.8 * k, 0, 0), loc=(0, 0.16 * abs(k), 0))
        lids(b, f, 0.03 * abs(k))
        arms(b, f, lift=2.5 * abs(k), fold=-2 * abs(k))
        b.key("LeftBack", f, (0, 7 * k, 3 * abs(k)))
        b.key("RightBack", f, (0, 6 * k, -3 * abs(k)))
        b.key("Eye", f, (0, 0, 0))
    return act


def open_(b):
    act = sf.new_action(b.arm, "Open", 0, 36, loop=False, priority="Action")
    b.rest(0)
    lids(b, 6, -0.03)                                                    # clamps
    b.key("Body", 6, (2, 0, 0), loc=(0, -0.2, 0))
    lids(b, 12, 0.18, ease="QUAD")                                       # a crack of light
    lids(b, 16, 0.14)
    lids(b, 26, 1.08, ease="QUAD")                                       # then all the way
    b.key("Body", 26, (-4, 0, 0), loc=(0, 0.35, 0))
    arms(b, 26, lift=7, fold=-4)
    lids(b, 36, 1.0)
    b.key("Body", 36, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 36, lift=3, fold=-2)
    b.key("Eye", 36, (0, 0, 0))
    return act


def open_idle(b):
    act = sf.new_action(b.arm, "OpenIdle", 0, 90, loop=True, priority="Idle")
    looks = ((0, 0, 0), (12, 9, 3), (26, 9, 3), (34, -11, -2), (52, -11, -2), (60, 3, 6), (76, 3, 6), (90, 0, 0))
    for f, yaw, pitch in looks:
        b.key("Eye", f, (pitch, yaw, 0), ease="QUAD")                    # the eye hunts about the room
        b.key("Pupil", f, (0, 0, 0), loc=(yaw * -0.02, 0, 0))
    for f, k in ((0, 0), (22, 1), (45, 0), (68, -1), (90, 0)):
        b.key("Body", f, (-2 + 0.8 * k, 0, 0), loc=(0, 0.2 + 0.12 * abs(k), 0))
        lids(b, f, 1.0 - 0.05 * abs(k))
        arms(b, f, lift=3 + 2 * abs(k), fold=-2)
        b.key("LeftBack", f, (0, 8 * k, 4 * abs(k)))
        b.key("RightBack", f, (0, 7 * k, -4 * abs(k)))
    return act


def close(b):
    act = sf.new_action(b.arm, "Close", 0, 30, loop=False, priority="Action")
    lids(b, 0, 1.0)
    b.key("Body", 0, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 0, lift=3, fold=-2)
    lids(b, 5, 1.08)
    lids(b, 11, -0.05, ease="QUAD")                                      # snaps shut
    b.key("Body", 11, (3, 0, 0), loc=(0, -0.25, 0), ease="QUAD")
    arms(b, 11, lift=-2, fold=3)
    lids(b, 16, 0.03)
    lids(b, 30, 0.0)
    b.key("Body", 30, (0, 0, 0), loc=(0, 0, 0))
    arms(b, 30)
    return act


def attack(b, name="Attack", lid=1.0):
    """It heaves up, both arms come off the floor and hammer down together (Hit 0.9 s). Attack is
    with the eye open; Slam (lid=0) the same blow from behind shut lids."""
    act = sf.new_action(b.arm, name, 0, 54, loop=False, priority="Action")
    lids(b, 0, 1.0 * lid)
    b.key("Body", 0, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 0, lift=3, fold=-2)
    b.key("Body", 18, (-9, 0, 0), loc=(0, 1.0, 0.3))                     # heaves back
    arms(b, 18, lift=34, fold=24, spread=6)
    lids(b, 18, 1.1 * lid)
    b.key("Body", 23, (-10, 0, 0), loc=(0, 1.1, 0.3))                    # hangs
    arms(b, 23, lift=37, fold=26, spread=7)
    b.key("Body", 27, (7, 0, 0), loc=(0, -0.35, -0.3), ease="QUAD")      # down: Hit at 0.9 s (frame 27)
    arms(b, 27, lift=-7, fold=-9, spread=-3, ease="QUAD")
    lids(b, 27, 0.8 * lid, ease="QUAD")
    b.key("Body", 31, (5, 0, 0), loc=(0, -0.2, -0.2))
    arms(b, 31, lift=-5, fold=-6, spread=-2)
    lids(b, 31, 0.9 * lid)
    b.key("Body", 44, (0, 0, 0), loc=(0, 0.1, 0))
    arms(b, 44, lift=1, fold=-1)
    lids(b, 54, 1.0 * lid)
    b.key("Body", 54, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 54, lift=3, fold=-2)
    return act


def roar(b):
    """Waking: the lids crack, light pours out, the whole mass shudders with its arms up; it ends shut."""
    act = sf.new_action(b.arm, "Roar", 0, 78, loop=False, priority="Action")
    b.rest(0)
    lids(b, 10, 0.3, ease="QUAD")
    b.key("Body", 10, (-6, 0, 0), loc=(0, 0.6, 0.2))
    arms(b, 10, lift=24, fold=10, spread=10)
    for f in range(14, 56, 4):
        k = 1 if (f // 4) % 2 == 0 else -1
        lids(b, f, 0.42 + 0.06 * k)
        b.key("Body", f, (-7 + 1.5 * k, 2.0 * k, 1.2 * k), loc=(0.08 * k, 0.7 + 0.08 * k, 0.2))
        arms(b, f, lift=28 + 3 * k, fold=12 - 2 * k, spread=12 + 2 * k)
        b.key("LeftBack", f, (0, 10 * k, 8))
        b.key("RightBack", f, (0, -10 * k, -8))
    lids(b, 62, 0.2)
    b.key("Body", 62, (-2, 0, 0), loc=(0, 0.3, 0))
    arms(b, 62, lift=8, fold=2, spread=3)
    lids(b, 68, -0.04, ease="QUAD")
    b.rest(78)
    return act


def stagger(b):
    """Hit hard in the eye: the lids clamp half shut over it and the mass recoils; it ends open again."""
    act = sf.new_action(b.arm, "Stagger", 0, 96, loop=False, priority="Action")
    lids(b, 0, 1.0)
    b.key("Body", 0, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 0, lift=3, fold=-2)
    lids(b, 5, 0.3, ease="QUAD")
    b.key("Body", 5, (-12, 0, 0), loc=(0, 0.4, 0.8), ease="QUAD")
    arms(b, 5, lift=18, fold=14, spread=8)
    for f in range(12, 76, 8):
        k = 1 if (f // 8) % 2 == 0 else -1
        lids(b, f, 0.36 + 0.08 * k)
        b.key("Body", f, (-9 + 2 * k, 3 * k, 2 * k), loc=(0, 0.3, 0.6))
        b.key("Eye", f, (6 * k, -14 * k, 0))
        arms(b, f, lift=12 + 4 * k, fold=10, spread=6)
    lids(b, 86, 0.8)
    b.key("Body", 86, (-3, 0, 0), loc=(0, 0.2, 0.1))
    arms(b, 86, lift=5, fold=0)
    lids(b, 96, 1.0)
    b.key("Body", 96, (-2, 0, 0), loc=(0, 0.2, 0))
    b.key("Eye", 96, (0, 0, 0))
    arms(b, 96, lift=3, fold=-2)
    return act


def death(b):
    """The eye rolls up, the lids fall slack, the arms give and the mass settles on the floor."""
    act = sf.new_action(b.arm, "Death", 0, 96, loop=False, priority="Action")
    lids(b, 0, 1.0)
    b.key("Body", 0, (-2, 0, 0), loc=(0, 0.2, 0))
    arms(b, 0, lift=3, fold=-2)
    b.key("Eye", 0, (0, 0, 0))
    for f, k in ((8, 1), (16, -1), (24, 1), (32, -1)):                   # it thrashes
        b.key("Body", f, (-8 + 3 * k, 5 * k, 3 * k), loc=(0.15 * k, 0.6, 0.3))
        arms(b, f, lift=30 + 8 * k, fold=16, spread=12)
        lids(b, f, 0.7 + 0.25 * k)
        b.key("Eye", f, (10 * k, 18 * k, 0))
    b.key("Eye", 52, (-34, 6, 0))                                        # rolls up under its lid
    lids(b, 52, 0.55)
    b.key("Body", 52, (4, 0, 0), loc=(0, -0.3, 0))
    arms(b, 52, lift=6, fold=-4, spread=-2)
    b.key("Body", 80, (9, 0, 2), loc=(0, -1.1, -0.4), ease="QUAD")       # and down
    arms(b, 80, lift=-12, fold=-14, spread=-6, ease="QUAD")
    b.key("LidUpper", 80, (OPEN_UP * 0.35, 0, 0))
    b.key("LidLower", 80, (OPEN_DOWN * 1.25, 0, 0))                      # the jaw hangs
    b.key("LeftBack", 80, (0, 0, 12))
    b.key("RightBack", 80, (0, 0, -12))
    b.key("Body", 96, (9, 0, 2), loc=(0, -1.15, -0.4))
    arms(b, 96, lift=-12, fold=-14, spread=-6)
    b.key("LidUpper", 96, (OPEN_UP * 0.33, 0, 0))
    b.key("LidLower", 96, (OPEN_DOWN * 1.25, 0, 0))
    b.key("Eye", 96, (-34, 6, 0))
    return act


def hero(b):
    """Two more previews with the Great Eye open: from where a resident stands, and from the side."""
    import bpy
    act = bpy.data.actions.get("OpenIdle")
    if act:
        b.arm.animation_data.action = act
        if hasattr(b.arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
            b.arm.animation_data.action_slot = act.slots[0]
        bpy.context.scene.frame_set(34)
    print(sf.render_preview(ASSET, CATEGORY, res=640, views=[(-10, 3, False), (-48, 14, False)], out_name=f"{ASSET}_hero"))
    bpy.context.scene.frame_set(0)


if __name__ == "__main__":
    beast = B.run(ASSET, CATEGORY, lambda: B.Beast("Source", JOINTS, collision="queryhull"), build,
                  lambda b: [idle(b), open_(b), open_idle(b), close(b), attack(b), attack(b, "Slam", 0.0), roar(b), stagger(b), death(b)],
                  budget=15000, hrp_center=(0, 0, 3.0), hrp_size=(8.0, 6.0, 8.0), step="A10",
                  meta={"role": "Boss", "band": "SourceChamber", "hitTime": HIT_TIME, "weakPoint": "Eye"},
                  sockets={"Eye": (tuple(E + sf.Vector((0, -1.6, 0))), 0.0), "Slam": ((0.0, -8.5, 0.3), 0.0),
                           "SlamLeft": (tuple(HAND[1]), 0.0), "SlamRight": (tuple(HAND[-1]), 0.0)},
                  markers={"Attack": {"Hit": HIT_TIME}, "Slam": {"Hit": HIT_TIME}}, pivot=(0, 0, 0))
    if os.environ.get("SF_NORENDER") != "1" or os.environ.get("SF_HERO") == "1":
        hero(beast)
