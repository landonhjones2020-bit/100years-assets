"""Boss_BroodMother: the Era I boss, Year 25 (bible Section 10: bursts up through the deepest
tunnel; lays egg sacs that hatch Burrow Ticks; break or burn the sacs and hit her glowing
belly). The mother of every Burrow Tick, grown huge in the dark: a spider-tick queen whose
eight armoured legs arch higher than a resident's head, a crown of Source crystals over a
cluster of eight burning eyes, two great pale fangs, grasping palps, a glowing maw, and a
vast abdomen banded in wet black armour with light leaking from every seam and a swollen,
glowing belly full of eggs. Bosses must be the scariest thing in their era (Landon,
2026-11-08: "the bosses need to really stand out, they should be scary"); never gory.

About 16 studs nose to tail, legs spanning about 21, knees about 10 high (a resident is 5).

Rig: Thorax (root), Head, two Fangs, two Palps, Abdomen, eight two-bone legs (LeftLeg1 is the
front left upper leg, LeftFoot1 its lower leg). Clips: Idle, Walk, Attack (rear and slam,
Hit 0.8 s), Roar (the entrance scream), LayEggs (Lay 1.4 s), Stagger (her belly is hit),
Death. Parts code needs: Belly (role WeakPoint, raycasts hit it), sockets Ovipositor (where
egg sacs drop), Maw and Slam.

Run:  SF_EXPORT=1 python3 generators/Bosses/Boss_BroodMother.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Monsters"))
import _beast as B  # noqa: E402
from _beast import sf, crystal, spike, claw, limb, blob, shell, eye  # noqa: E402

ASSET, CATEGORY = "Boss_BroodMother", "Bosses"
HIT_TIME = 0.8
LAY_TIME = 1.4
SIDES = (("Left", 1), ("Right", -1))
LEGS = (  # hip y, knee (x, y, z), foot (x, y)
    (-1.9, (5.6, -6.0, 9.2), (8.6, -9.4)),
    (-0.7, (6.6, -2.5, 10.0), (10.3, -3.9)),
    (0.5, (6.6, 1.5, 10.0), (10.3, 2.4)),
    (1.6, (5.8, 4.6, 9.2), (9.2, 7.0)),
)
JOINTS = [
    ("Thorax", None, (0, -0.4, 5.0)),
    ("Head", "Thorax", (0, -3.0, 5.0)),
    ("LeftFang", "Head", (0.85, -4.9, 4.5)),
    ("RightFang", "Head", (-0.85, -4.9, 4.5)),
    ("LeftPalp", "Head", (1.55, -4.4, 4.3)),
    ("RightPalp", "Head", (-1.55, -4.4, 4.3)),
    ("Abdomen", "Thorax", (0, 2.4, 5.3)),
]
for _i, (_hy, _knee, _foot) in enumerate(LEGS, 1):
    for _side, _sx in SIDES:
        JOINTS.append((f"{_side}Leg{_i}", "Thorax", (_sx * 2.3, _hy, 5.0)))
        JOINTS.append((f"{_side}Foot{_i}", f"{_side}Leg{_i}", (_sx * _knee[0], _knee[1], _knee[2])))
ABDOMEN_C, ABDOMEN_R = sf.Vector((0, 7.2, 6.0)), sf.Vector((4.2, 5.2, 3.7))


def mannequin():
    """A 5-stud grey resident stand-in for the previews only (untagged: never exported)."""
    for size, loc in (((0.5, 0.5, 2.2), (-0.35, 0, 1.1)), ((0.5, 0.5, 2.2), (0.35, 0, 1.1)),
                      ((1.5, 0.75, 1.9), (0, 0, 3.15)), ((0.95, 0.95, 0.95), (0, 0, 4.55))):
        o = sf.box(size, loc=(sf.Vector(loc) + sf.Vector((3.2, -10.5, 0))), bevel=0.08, name="Mannequin")
        o.data.materials.append(sf._flat_material("#B9B4A8", roughness=0.7))


def seam(rx, rz, y, z0, radius, name):
    """A glowing seam over the abdomen's back at a band gap (an arc of the cross-section)."""
    pts = []
    for k in range(9):
        a = math.radians(-12 + 204 * k / 8)
        pts.append((rx * math.cos(a), y, z0 + rz * math.sin(a)))
    return limb(pts, [radius] * len(pts), sides=4, resolution=2, name=name)


def build(b):
    if os.environ.get("SF_EXPORT") != "1":
        mannequin()
    # ---- Thorax: an armoured shield ringed with spines, a crest of crystals down the middle
    b.part(blob(2.8, (0, -0.5, 5.3), scale=(0.95, 1.1, 0.55), segs=18, rings=10, noise=0.03, seed=101), "Thorax", "basalt")
    b.part(shell((2.85, 3.2, 1.75), (0, -0.5, 5.45), -0.95, 0.9, z_from=0.25, thickness=0.22, segs=18, rings=10),
           "Thorax", "navy")
    for k in range(12):                                # spines around the shield's edge, front and sides
        a = math.radians(160 + 220 * k / 11)
        p = sf.Vector((2.75 * math.cos(a), -0.5 + 3.1 * math.sin(a), 5.75))
        b.part(spike(p, (math.cos(a), math.sin(a) * 0.8, 0.55), 0.95, 0.19, verts=4), "Thorax", "stone")
    for (y, ln, r, lean) in ((-1.6, 2.2, 0.36, 0.45), (-0.2, 2.8, 0.42, 0.55), (1.2, 2.0, 0.32, 0.7)):
        b.glow(crystal((0, y, 6.4), (0, lean, 1.0), ln, r), "Thorax", "ThoraxGlow")
    for sx in (-1, 1):
        b.glow(crystal((sx * 0.9, -0.4, 6.2), (sx * 0.7, 0.5, 1.0), 1.5, 0.26), "Thorax", "ThoraxGlow")

    # ---- Head: eight burning eyes under a crown of crystals, a glowing maw
    b.part(blob(2.2, (0, -3.95, 5.1), scale=(1.1, 0.85, 0.72), segs=16, rings=9, noise=0.04, seed=102), "Head", "basalt")
    b.part(shell((2.42, 1.98, 1.64), (0, -3.95, 5.2), -0.95, 0.75, z_from=0.3, thickness=0.16, segs=14, rings=8),
           "Head", "navy")
    for (x, y, z, r, fx) in ((0.7, -5.7, 5.6, 0.52, 0.25), (0.28, -5.55, 6.32, 0.33, 0.15), (1.36, -5.25, 6.12, 0.33, 0.6),
                             (1.85, -4.7, 5.6, 0.25, 0.9)):
        for sx in (-1, 1):
            eye(b, "Head", (sx * x, y, z), r, facing=(sx * fx, -1, 0.25), segs=10)
    for (x, ln, lean) in ((0.0, 3.4, 0.15), (0.8, 2.5, 0.3), (-0.8, 2.5, 0.3), (1.45, 1.7, 0.45), (-1.45, 1.7, 0.45)):
        b.glow(crystal((x, -4.5, 6.45), (x * 0.45, lean, 1.0), ln, 0.34 if x == 0 else 0.26), "Head", "HeadGlow")
    for sx in (-1, 1):
        for (x, y, z) in ((1.0, -5.6, 6.5), (1.85, -5.1, 6.35), (2.25, -4.35, 5.95)):
            b.part(spike((sx * x, y, z), (sx * 0.5, -0.6, 0.9), 0.65, 0.12, verts=4), "Head", "stone")
    b.glow(blob(0.62, (0, -5.35, 4.4), scale=(1.2, 0.7, 0.8), segs=10, rings=6), "Head", "HeadGlow")   # the maw
    b.part(sf.torus(0.72, 0.16, loc=(0, -5.32, 4.4), rot=(90, 0, 0), major_segs=14, minor_segs=4), "Head", "plum")

    # ---- Fangs and palps
    for side, sx in SIDES:
        fang = f"{side}Fang"
        b.part(blob(0.6, (sx * 0.85, -5.05, 4.55), scale=(0.8, 1.0, 1.15), segs=10, rings=6, seed=103), fang, "murk")
        base, d, n = sf.Vector((sx * 0.85, -5.35, 4.15)), sf.Vector((-sx * 0.12, -0.4, -1.0)), sf.Vector((-sx * 0.3, 1, 0))
        b.part(claw(base, d, 3.2, 0.44, bend=n, curl=0.4, sides=8, resolution=2), fang, "cream")
        tip = base + d.normalized() * 3.2 * 0.92 + n.normalized() * 3.2 * 0.4
        b.glow(spike(tip + sf.Vector((0, 0, 0.05)), (0, 0, -1), 0.4, 0.07, verts=4), fang, f"{side}FangGlow")
        palp = f"{side}Palp"
        b.part(limb([(sx * 1.55, -4.4, 4.3), (sx * 2.25, -5.6, 3.95), (sx * 2.05, -6.6, 2.75)], [0.34, 0.28, 0.2]),
               palp, "basalt")
        b.part(blob(0.32, (sx * 2.25, -5.6, 3.95), segs=8, rings=5, seed=104), palp, "stone")
        b.part(claw((sx * 2.05, -6.6, 2.75), (sx * -0.2, -0.5, -1.0), 0.9, 0.16, bend=(-sx, 1, 0), curl=0.4, sides=6),
               palp, "cream")

    # ---- Abdomen: banded wet-black armour over a plum hide, light leaking from every seam
    c, r = ABDOMEN_C, ABDOMEN_R
    b.part(blob(1.0, c, scale=(r.x, r.y, r.z), segs=22, rings=13, noise=0.012, seed=105), "Abdomen", "plum")
    bands = ((-0.86, -0.5), (-0.38, -0.02), (0.1, 0.46), (0.58, 0.88))
    for i, (y0, y1) in enumerate(bands):
        b.part(shell((r.x * 1.05, r.y * 1.03, r.z * 1.06), c, y0, y1, z_from=-0.05, thickness=0.2, segs=22, rings=12),
               "Abdomen", "murk" if i % 2 == 0 else "navy")
    for (y0, y1) in zip([b1 for _a, b1 in bands[:-1]], [a2 for a2, _b in bands[1:]]):
        f = (y0 + y1) / 2
        k = math.sqrt(max(0.0, 1 - f * f))
        b.glow(seam(r.x * k * 1.0, r.z * k * 1.0, c.y + r.y * f, c.z, 0.13, "Seam"), "Abdomen", "AbdomenGlow")
    # spines down the ridge and along the band edges, crystals bursting from the rear
    for i, f in enumerate((-0.68, -0.2, 0.28, 0.73)):
        k = math.sqrt(1 - f * f)
        top = c + sf.Vector((0, r.y * f, r.z * k * 1.06))
        b.part(spike(top, (0, 0.35, 1.0), 1.25 - i * 0.12, 0.26, verts=4), "Abdomen", "stone")
        for sx in (-1, 1):
            side = c + sf.Vector((sx * r.x * k * 0.78, r.y * f, r.z * k * 0.72))
            b.part(spike(side, (sx * 0.8, 0.2, 0.7), 0.8, 0.18, verts=4), "Abdomen", "stone")
    for (x, y, z, d, ln, rr) in ((0.0, 11.0, 8.2, (0, 0.6, 1.0), 2.4, 0.4), (1.1, 10.6, 7.6, (0.6, 0.5, 0.9), 1.7, 0.3),
                                 (-1.1, 10.6, 7.6, (-0.6, 0.5, 0.9), 1.7, 0.3), (0.5, 11.9, 6.6, (0.3, 1.0, 0.4), 1.3, 0.24)):
        b.glow(crystal((x, y, z), d, ln, rr), "Abdomen", "AbdomenGlow")
    # the glowing belly (the weak point) with plum ribs across it and eggs pressing out of the sides
    belly = blob(1.0, (c.x, c.y + 0.2, 3.55), scale=(3.2, 4.3, 1.75), segs=18, rings=9, noise=0.02, seed=106, name="Belly")
    sf.tag(belly, "Belly", "glow", "Neon", collision="queryhull", cast_shadow=False, role="WeakPoint")
    belly["sf_bone"] = "Abdomen"
    sf.bind(belly, b.arm, "Abdomen")
    for f in (-0.55, -0.15, 0.25, 0.62):
        k = math.sqrt(1 - f * f)
        pts = [(3.25 * k * math.cos(math.radians(a)), c.y + 0.2 + 4.3 * f, 3.55 + 1.8 * k * math.sin(math.radians(a)))
               for a in range(190, 351, 20)]
        b.part(limb(pts, [0.2] * len(pts), sides=4, resolution=1), "Abdomen", "plum")
    for (x, y, z, rr) in ((2.9, 5.2, 4.1, 0.62), (3.2, 7.4, 4.4, 0.7), (2.7, 9.6, 4.3, 0.55), (-2.9, 5.6, 4.2, 0.6),
                          (-3.15, 8.0, 4.5, 0.72), (-2.6, 10.0, 4.2, 0.52)):
        b.glow(blob(rr, (x, y, z), scale=(0.9, 1.1, 0.95), segs=8, rings=5), "Abdomen", "AbdomenGlow")
    # the ovipositor at the tip
    b.part(limb([(0, 11.9, 4.6), (0, 12.9, 4.0), (0, 13.4, 3.0)], [0.75, 0.5, 0.25], sides=8), "Abdomen", "plum")
    b.glow(blob(0.32, (0, 13.45, 2.85), segs=8, rings=5), "Abdomen", "AbdomenGlow")

    # ---- Legs: armoured upper legs arching above everything, long wet-black lower legs, hooks
    for i, (hy, knee, foot) in enumerate(LEGS, 1):
        for side, sx in SIDES:
            up, low = f"{side}Leg{i}", f"{side}Foot{i}"
            hip = sf.Vector((sx * 2.3, hy, 5.0))
            kn = sf.Vector((sx * knee[0], knee[1], knee[2]))
            ft = sf.Vector((sx * foot[0], foot[1], 0.95))
            mid = hip.lerp(kn, 0.5) + sf.Vector((0, 0, 0.7))
            b.part(limb([hip, mid, kn], [0.72, 0.62, 0.5], sides=8, resolution=3), up, "basalt")
            b.part(limb([hip.lerp(kn, 0.15) + sf.Vector((0, 0, 0.45)), mid + sf.Vector((0, 0, 0.4)),
                         kn + sf.Vector((0, 0, 0.3))], [0.55, 0.5, 0.36], sides=6, resolution=2), up, "navy")
            for t in (0.3, 0.55, 0.8):
                p = hip.lerp(kn, t) + sf.Vector((0, 0, 0.7 + 0.5 * math.sin(math.pi * t)))
                b.part(spike(p, (sx * 0.35, (kn.y - hip.y) * 0.05, 1.0), 0.7, 0.14, verts=4), up, "stone")
            b.part(blob(0.62, kn, scale=(1.0, 1.0, 0.9), segs=8, rings=6, seed=110 + i), up, "stone")
            b.glow(crystal(kn + sf.Vector((0, 0, 0.35)), (sx * 0.5, 0.2, 1.0), 1.1, 0.2), up, f"{up}Glow")
            bend = kn + sf.Vector((sx * 1.7, (ft.y - kn.y) * 0.35, -3.6))
            b.part(limb([kn, bend, ft], [0.46, 0.32, 0.17], sides=8, resolution=3), low, "murk")
            for t in (0.25, 0.5):
                p = kn.lerp(bend, t * 2) if t < 0.5 else bend
                b.part(spike(p, (sx * 1.0, 0, 0.35), 0.45, 0.08, verts=3), low, "stone")
            b.part(claw(ft, (sx * 0.25, (ft.y - kn.y) * 0.04, -1.0), 1.0, 0.2, bend=(-sx, 0, 0), curl=0.35, sides=6),
                   low, "cream")


# ---- clips ----------------------------------------------------------------------------------

LEG_A = {"LeftLeg1", "RightLeg2", "LeftLeg3", "RightLeg4"}   # the tetrapod gait groups


def legs(b, frame, swing, lift_a, lift_b, ease="SINE"):
    """Swing group A forward by `swing` (group B back by it) and lift each group."""
    for i in (1, 2, 3, 4):
        for side, sx in SIDES:
            bone = f"{side}Leg{i}"
            a = bone in LEG_A
            fwd = swing if a else -swing
            lift = lift_a if a else lift_b
            b.key(bone, frame, (0, -fwd * sx, lift * sx), ease=ease)
            b.key(f"{side}Foot{i}", frame, (0, 0, -lift * sx * 0.6), ease=ease)


def all_legs(b, frame, rots, ease="SINE"):
    """rots: {i: (upper (x, y, z) for the left side, lower (x, y, z))}, mirrored to the right."""
    for i, (upper, lower) in rots.items():
        for side, sx in SIDES:
            b.key(f"{side}Leg{i}", frame, (upper[0], upper[1] * sx, upper[2] * sx), ease=ease)
            b.key(f"{side}Foot{i}", frame, (lower[0], lower[1] * sx, lower[2] * sx), ease=ease)


def fangs(b, frame, spread, raise_=0, ease="SINE"):
    b.key("LeftFang", frame, (-raise_, spread, 0), ease=ease)
    b.key("RightFang", frame, (-raise_, -spread, 0), ease=ease)


def palps(b, frame, spread, raise_=0, ease="SINE"):
    b.key("LeftPalp", frame, (-raise_, spread, 0), ease=ease)
    b.key("RightPalp", frame, (-raise_, -spread, 0), ease=ease)


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 60, loop=True, priority="Idle")
    for f, breath, head, fang, palp in ((0, 0.0, 0, 0, 0), (15, 0.12, 4, 5, 10), (30, 0.18, 0, 2, -4),
                                        (45, 0.08, -4, 6, 8), (60, 0.0, 0, 0, 0)):
        b.key("Thorax", f, (0, 0, 0), loc=(0, breath * 0.8, 0))
        b.key("Abdomen", f, (breath * 18, 0, 0))
        b.key("Head", f, (0, head, 0))
        fangs(b, f, fang)
        palps(b, f, palp, raise_=palp)
    all_legs(b, 0, {i: ((0, 0, 0), (0, 0, 0)) for i in (1, 2, 3, 4)})
    all_legs(b, 30, {1: ((0, 0, 2), (0, 0, -1)), 2: ((0, 0, 0), (0, 0, 0)), 3: ((0, 0, 1), (0, 0, 0)), 4: ((0, 0, 0), (0, 0, 0))})
    all_legs(b, 60, {i: ((0, 0, 0), (0, 0, 0)) for i in (1, 2, 3, 4)})
    return act


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 32, loop=True, priority="Movement")
    legs(b, 0, 12, 0, 0)
    legs(b, 8, 0, 0, 12)
    legs(b, 16, -12, 0, 0)
    legs(b, 24, 0, 12, 0)
    legs(b, 32, 12, 0, 0)
    for f, z, roll in ((0, 0.0, 0), (8, 0.25, 2), (16, 0.0, 0), (24, 0.25, -2), (32, 0.0, 0)):
        b.key("Thorax", f, (0, 0, roll), loc=(0, z, 0))
        b.key("Abdomen", f, (-z * 8, -roll * 1.5, 0))
        b.key("Head", f, (0, -roll * 2, 0))
    for f, spread in ((0, 0), (16, 8), (32, 0)):
        fangs(b, f, spread)
        palps(b, f, spread * 1.5, raise_=spread)
    return act


def attack(b):
    """Rear up, fangs wide and front legs raised, then slam down (Hit at 0.8 s = frame 24)."""
    act = sf.new_action(b.arm, "Attack", 0, 48, loop=False, priority="Action")
    b.rest(0)
    b.key("Thorax", 16, (-22, 0, 0), loc=(0, 1.6, 0.6), ease="QUAD")
    b.key("Head", 16, (-12, 0, 0))
    b.key("Abdomen", 16, (14, 0, 0))
    fangs(b, 16, 24, raise_=18)
    palps(b, 16, 30, raise_=40)
    all_legs(b, 16, {1: ((0, -20, 48), (0, 0, -30)), 2: ((0, -8, 26), (0, 0, -16)), 3: ((0, 0, -4), (0, 0, 0)),
                     4: ((0, 6, -8), (0, 0, 4))})
    b.key("Thorax", 24, (14, 0, 0), loc=(0, -0.5, 1.0), ease="QUAD")
    b.key("Head", 24, (16, 0, 0), ease="QUAD")
    b.key("Abdomen", 24, (-8, 0, 0), ease="QUAD")
    fangs(b, 24, -6, raise_=-12, ease="QUAD")
    palps(b, 24, -10, raise_=-10, ease="QUAD")
    all_legs(b, 24, {1: ((0, -26, -14), (0, 0, 10)), 2: ((0, -10, -6), (0, 0, 6)), 3: ((0, 0, 0), (0, 0, 0)),
                     4: ((0, 4, 0), (0, 0, 0))}, ease="QUAD")
    b.key("Thorax", 30, (8, 0, 0), loc=(0, -0.3, 0.6))
    b.rest(48)
    return act


def roar(b):
    """The entrance: she rears high, splays every front leg, fangs wide and shaking, then settles."""
    act = sf.new_action(b.arm, "Roar", 0, 84, loop=False, priority="Action")
    b.rest(0)
    b.key("Thorax", 18, (-30, 0, 0), loc=(0, 2.4, 0.8), ease="QUAD")
    b.key("Abdomen", 18, (20, 0, 0))
    b.key("Head", 18, (-16, 0, 0))
    all_legs(b, 18, {1: ((0, -30, 62), (0, 0, -40)), 2: ((0, -16, 44), (0, 0, -28)), 3: ((0, 4, -6), (0, 0, 2)),
                     4: ((0, 10, -12), (0, 0, 6))})
    for f in range(18, 66, 6):
        k = 1 if (f // 6) % 2 == 0 else -1
        fangs(b, f, 30 + 6 * k, raise_=20 + 4 * k)
        palps(b, f, 38 - 8 * k, raise_=50 + 6 * k)
        b.key("Head", f, (-16, 5 * k, 3 * k))
        b.key("Abdomen", f, (20 + 3 * k, 0, 0))
    b.key("Thorax", 60, (-28, 0, 0), loc=(0, 2.2, 0.8))
    all_legs(b, 60, {1: ((0, -32, 60), (0, 0, -40)), 2: ((0, -16, 42), (0, 0, -28)), 3: ((0, 4, -6), (0, 0, 2)),
                     4: ((0, 10, -12), (0, 0, 6))})
    b.rest(84)
    return act


def lay_eggs(b):
    """The abdomen tip drops to the floor and pulses; an egg sac leaves at 1.4 s (frame 42)."""
    act = sf.new_action(b.arm, "LayEggs", 0, 66, loop=False, priority="Action")
    b.rest(0)
    b.key("Thorax", 14, (6, 0, 0), loc=(0, -0.8, 0))
    b.key("Abdomen", 14, (-22, 0, 0))
    for f, k in ((22, 1), (30, -1), (38, 1)):
        b.key("Abdomen", f, (-22 - 4 * k, 0, 0))
        b.key("Thorax", f, (6, 0, 0), loc=(0, -0.8 - 0.15 * k, 0))
    b.key("Abdomen", 42, (-28, 0, 0), ease="QUAD")
    b.key("Abdomen", 48, (-18, 0, 0))
    fangs(b, 14, 10)
    palps(b, 14, 16, raise_=12)
    fangs(b, 48, 10)
    b.rest(66)
    return act


def stagger(b):
    """Her belly is hit: she jolts back and sideways, legs splay, then recovers."""
    act = sf.new_action(b.arm, "Stagger", 0, 36, loop=False, priority="Action")
    b.rest(0)
    b.key("Thorax", 6, (-14, 0, 8), loc=(0, 0.4, -0.8), ease="QUAD")
    b.key("Abdomen", 6, (12, 6, 0), ease="QUAD")
    b.key("Head", 6, (-18, -8, 0), ease="QUAD")
    fangs(b, 6, 28, raise_=14, ease="QUAD")
    palps(b, 6, 36, raise_=30, ease="QUAD")
    all_legs(b, 6, {1: ((0, -10, 24), (0, 0, -14)), 2: ((0, 0, 16), (0, 0, -8)), 3: ((0, 0, 10), (0, 0, -6)),
                    4: ((0, 6, 14), (0, 0, -8))}, ease="QUAD")
    b.key("Thorax", 16, (4, 0, -3), loc=(0, -0.2, 0.1))
    b.rest(36)
    return act


def death(b):
    """She collapses: the body drops, every leg curls in over her, the light shudders out."""
    act = sf.new_action(b.arm, "Death", 0, 90, loop=False, priority="Action")
    b.rest(0)
    b.key("Thorax", 12, (-20, 0, 6), loc=(0, 1.2, 0.4), ease="QUAD")
    fangs(b, 12, 32, raise_=22)
    palps(b, 12, 40, raise_=45)
    all_legs(b, 12, {1: ((0, -20, 40), (0, 0, -20)), 2: ((0, -10, 28), (0, 0, -16)), 3: ((0, 0, 18), (0, 0, -10)),
                     4: ((0, 8, 20), (0, 0, -10))})
    b.key("Thorax", 40, (6, 0, -8), loc=(0, -2.0, 0), ease="QUAD")
    b.key("Abdomen", 40, (-10, 0, 6), ease="QUAD")
    b.key("Head", 40, (14, 0, 0), ease="QUAD")
    all_legs(b, 70, {1: ((0, 10, 30), (0, 0, -62)), 2: ((0, 4, 34), (0, 0, -66)), 3: ((0, -4, 34), (0, 0, -66)),
                     4: ((0, -10, 30), (0, 0, -62))})
    fangs(b, 70, -10, raise_=-10)
    palps(b, 70, -20, raise_=-30)
    b.key("Thorax", 90, (6, 0, -8), loc=(0, -2.0, 0))
    b.key("Abdomen", 90, (-14, 0, 8))
    return act


def clips(b):
    return [idle(b), walk(b), attack(b), roar(b), lay_eggs(b), stagger(b), death(b)]


def hero_view():
    """A third preview from where a resident stands: low, in front, looking up at her."""
    sf.render_preview(ASSET, CATEGORY, views=[(-18, 2, False)], out_name=f"{ASSET}_hero")


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("BroodMother", JOINTS, collision="queryhull"), build, clips,
          budget=15000, hrp_center=(0, -0.4, 5.0), hrp_size=(5.0, 4.0, 7.0), step="A4",
          meta={"role": "Boss", "band": "Mines", "era": 1, "hitTime": HIT_TIME, "layTime": LAY_TIME},
          sockets={"Ovipositor": ((0, 13.4, 2.6), 0.0), "Maw": ((0, -5.6, 4.4), 0.0), "Slam": ((0, -8.5, 0.0), 0.0)},
          markers={"Attack": {"Hit": HIT_TIME}, "LayEggs": {"Lay": LAY_TIME}})
    if os.environ.get("SF_NORENDER") != "1":
        hero_view()
