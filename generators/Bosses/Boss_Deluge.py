"""Boss_Deluge: the Era II boss, Year 50 (bible Section 10: "A giant eel surging up the flooded
tunnels. Floods every room it passes; strike its head when it surfaces and drain the rooms
behind it."). What comes up through the floor is only the front of it: a neck as thick as a
doorway rising to the ceiling and arching over, a head longer than a resident is tall, three
burning eyes down each side, fangs that don't fit inside its mouth, a second jaw that slides
out of its throat when it screams, and a hood of spined frills that opens when it does. The
top of its skull has split around the Source: that glowing crown and its glowing gullet are
where it can be hurt. Behind it a coil of its body humps out of the floor and its tail whips;
the rest is still down in the dark. Bosses must be the scariest thing in their era (Landon,
2026-11-08); never gory.

About 14 studs high to the crest, the head 10 up; 20 from snout to the coil behind (a
resident is 5). It stands in the middle of a 32 by 32 cell under a 16-stud ceiling.

Rig: Coil (root: where it leaves the floor), Neck1 to Neck3, Head, Jaw, InnerJaw, two head
frills, two neck fins, Hump, Tail1, Tail2. Clips: Idle, Swim (the head tucked under the arch
of the neck, so that sunk Tuning.Deluge.SwimDepth only the crest shows, cutting the floor),
Attack (rears and strikes down at the floor in front, Hit 0.7 s), Roar, Stagger (the head
drops to the floor and lies there: 3 s, Tuning.Deluge.StaggerSeconds), Death. Parts code
needs: Crown and Maw (role WeakPoint, raycasts hit them), socket Bite (where the strike lands).

Run:  SF_EXPORT=1 python3 generators/Bosses/Boss_Deluge.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Monsters"))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, vein, web  # noqa: E402,F401

V = sf.Vector
ASSET, CATEGORY = "Boss_Deluge", "Bosses"
HIT_TIME = 0.7
SIDES = (("Left", 1), ("Right", -1))
X = V((1, 0, 0))

# The neck's centreline (it lies in the YZ plane) and its radius at each point.
SPINE = [V(p) for p in ((0, 1.5, -1.2), (0, 1.8, 1.2), (0, 2.4, 3.0), (0, 2.4, 4.8), (0, 1.9, 6.6), (0, 0.9, 8.3),
                        (0, -0.4, 9.7), (0, -1.8, 10.5), (0, -3.0, 10.7))]
RADII = [2.55, 2.5, 2.4, 2.3, 2.15, 2.0, 1.85, 1.72, 1.6]
CUTS = {"Coil": (0, 1), "Neck1": (1, 3), "Neck2": (3, 5), "Neck3": (5, 8)}       # spine points of each bone
HEAD = V((0, -1.8, 10.5))
JAW = V((0, -2.4, 9.55))
FRILL = (1.5, -1.3, 10.9)
HUMP = [V(p) for p in ((2.7, 4.6, -1.4), (2.4, 5.4, 1.5), (1.3, 6.8, 3.5), (-0.4, 8.2, 3.7), (-1.8, 9.4, 1.9), (-2.5, 10.3, -1.4))]
HUMP_R = [1.95, 1.9, 1.85, 1.8, 1.7, 1.6]
TAIL = [V(p) for p in ((-5.0, 3.3, -1.2), (-5.5, 3.7, 2.0), (-6.2, 4.4, 4.6), (-6.2, 5.2, 6.6), (-5.4, 5.9, 8.0), (-4.3, 6.2, 8.5))]
TAIL_R = [1.15, 1.0, 0.8, 0.55, 0.3, 0.06]

JOINTS = [
    ("Coil", None, (0, 1.6, 0.4)),
    ("Neck1", "Coil", tuple(SPINE[1])),
    ("Neck2", "Neck1", tuple(SPINE[3])),
    ("Neck3", "Neck2", tuple(SPINE[5])),
    ("Head", "Neck3", tuple(HEAD)),
    ("Jaw", "Head", tuple(JAW)),
    ("InnerJaw", "Head", (0, -3.2, 9.8)),
    ("Hump", "Coil", (0.3, 7.4, 0.3)),
    ("Tail1", "Coil", (-5.1, 3.4, 0.2)),
    ("Tail2", "Tail1", tuple(TAIL[2])),
]
for _side, _sx in SIDES:
    JOINTS += [(f"{_side}Frill", "Head", (_sx * FRILL[0], FRILL[1], FRILL[2])),
               (f"{_side}Fin", "Neck2", (_sx * 2.1, 2.2, 5.6))]

_LEN = [0.0]
for _a, _b in zip(SPINE, SPINE[1:]):
    _LEN.append(_LEN[-1] + (_b - _a).length)


def at(d):
    """The neck at distance d along its centreline: position, tangent, back normal, radius."""
    d = max(0.0, min(_LEN[-1], d))
    for i in range(len(SPINE) - 1):
        if d <= _LEN[i + 1] or i == len(SPINE) - 2:
            k = (d - _LEN[i]) / (_LEN[i + 1] - _LEN[i])
            lo, hi = SPINE[max(i - 1, 0)], SPINE[min(i + 2, len(SPINE) - 1)]
            t = ((SPINE[i + 1] - SPINE[i]) * 0.6 + (hi - lo) * 0.2).normalized()
            return SPINE[i].lerp(SPINE[i + 1], k), t, V((0, t.z, -t.y)).normalized(), RADII[i] + (RADII[i + 1] - RADII[i]) * k
    raise ValueError(d)


def bone_at(d):
    for bone, (i0, i1) in CUTS.items():
        if d <= _LEN[i1] + 1e-6:
            return bone
    return "Neck3"


def mannequin():
    """A 5-stud grey resident stand-in for the previews only (untagged: never exported)."""
    for size, loc in (((0.5, 0.5, 2.2), (-0.35, 0, 1.1)), ((0.5, 0.5, 2.2), (0.35, 0, 1.1)),
                      ((1.5, 0.75, 1.9), (0, 0, 3.15)), ((0.95, 0.95, 0.95), (0, 0, 4.55))):
        o = sf.box(size, loc=(V(loc) + V((4.6, -8.5, 0))), bevel=0.08, name="Mannequin")
        o.data.materials.append(sf._flat_material("#B9B4A8", roughness=0.7))


def plate(b, bone, pos, normal, size, swatch="basalt", seed=1):
    """A bony scute lying on the skin: a flattened lump whose thin axis is `normal`."""
    o = blob(1.0, (0, 0, 0), scale=size, segs=6, rings=4, noise=0.06, seed=seed)
    o.rotation_euler = V(normal).to_track_quat("Z", "Y").to_euler()
    o.location = V(pos)
    return b.part(o, bone, swatch)


def crest(b, bone, stations, lengths, sweep=0.3, thick=0.07, spine_r=0.1):
    """A fin: spines standing off the body with a plum membrane between them.
    stations = [(base point, normal, tangent)]."""
    bases = [p for p, _n, _t in stations]
    tips = [p + n * ln - t * ln * sweep for (p, n, t), ln in zip(stations, lengths)]
    if len(stations) > 1:
        b.part(web(bases, tips, thick), bone, "plum")
    for (p, _n, _t), tip in zip(stations, tips):
        d = tip - p
        b.part(spike(p - d.normalized() * 0.35, d, d.length * 1.14 + 0.35, spine_r, verts=4), bone, "basalt")


def fan(b, bone, root, spines, thick=0.06, spine_r=0.1, spread=(0, 0, 0)):
    """A frill: spines fanning from one root (each (direction, length)), webbed together.
    spread shifts each spine's root a little, so the frill has a base instead of a point."""
    root = V(root)
    n = len(spines)
    roots = [root + V(spread) * ((i / (n - 1)) - 0.5) for i in range(n)]
    tips = [r + V(d).normalized() * ln for r, (d, ln) in zip(roots, spines)]
    # the membrane stops short of the spine tips and sags between them
    edge = [r + (t - r) * 0.86 for r, t in zip(roots, tips)]
    b.part(web(roots, edge, thick), bone, "plum")
    for r, t in zip(roots, tips):
        b.part(spike(r, t - r, (t - r).length, spine_r, verts=4), bone, "basalt")


def build(b):
    rnd = random.Random(50)
    # ================= the neck: Coil (at the floor), Neck1, Neck2, Neck3 =================
    for bone, (i0, i1) in CUTS.items():
        pts, rr = SPINE[i0:i1 + 1], RADII[i0:i1 + 1]
        seg = limb(pts, rr, sides=14, resolution=3 if bone != "Coil" else 2, name=bone)
        mid_n = at((_LEN[i0] + _LEN[i1]) / 2)[2]
        b.part(seg, bone, "murk")
        sf.paint(seg, "sandstone", lambda c, nrm, mid_n=mid_n: nrm.dot(-mid_n) > 0.55)       # the pale belly
        if bone != "Coil":
            ball = blob(rr[0] * 0.985, pts[0], segs=14, rings=8, seed=i0)                      # fills the joint
            b.part(ball, bone, "murk")
            joint_n = at(_LEN[i0])[2]
            sf.paint(ball, "sandstone", lambda c, nrm, joint_n=joint_n: nrm.dot(-joint_n) > 0.55)
    # the crest down its back: tallest over the arch, where it cuts the floor when it swims
    stations = {}
    d = _LEN[1] + 0.3
    while d < _LEN[7] - 0.1:
        p, t, n, r = at(d)
        k = (d - _LEN[1]) / (_LEN[7] - _LEN[1])
        ln = 1.5 + 1.7 * math.sin(math.pi * min(1.0, k * 1.15)) ** 1.4
        stations.setdefault(bone_at(d), []).append(((p + n * r * 0.9, n, t), ln))
        d += 1.05
    order = ["Neck1", "Neck2", "Neck3"]
    for i, bone in enumerate(order):
        st = stations[bone]
        if i + 1 < len(order):
            st = st + [stations[order[i + 1]][0]]            # joined to the next bone's first spine
        crest(b, bone, [s for s, _ln in st], [ln for _s, ln in st], spine_r=0.11)
    # scutes either side of the crest, glowing veins up each flank, barnacles low down
    d, i = _LEN[1] + 0.8, 0
    while d < _LEN[7] - 0.3:
        p, t, n, r = at(d)
        bone = bone_at(d)
        for sx in (-1, 1):
            plate(b, bone, p + n * r * 0.86 + X * sx * r * 0.42, n + X * sx * 0.45, (0.62, 0.78, 0.16), seed=200 + i)
            plate(b, bone, p + n * r * 0.52 + X * sx * r * 0.8, n * 0.6 + X * sx, (0.5, 0.66, 0.14), seed=230 + i)
        d += 1.25
        i += 1
    d = _LEN[1] + 0.45                                                # the belly's plates: a dark seam between each
    while d < _LEN[7] - 0.6:
        p, t, n, r = at(d)
        ring = [p + (X * math.sin(a) - n * math.cos(a)) * r * 1.012 for a in (math.radians(v) for v in (-56, -28, 0, 28, 56))]
        b.part(sf.tube([tuple(q) for q in ring], [0.05, 0.09, 0.1, 0.09, 0.05], sides=4, resolution=2), bone_at(d), "stone")
        d += 0.92
    for sx in (-1, 1):
        for bone, (i0, i1) in list(CUTS.items())[1:]:
            pts = []
            steps = 5
            for k in range(steps + 1):
                dd = _LEN[i0] + (_LEN[i1] - _LEN[i0]) * k / steps
                p, t, n, r = at(dd)
                pts.append(p + X * sx * r * 0.985 + n * r * (0.12 + 0.1 * math.sin(dd * 1.7)))
            vein(b, bone, pts, 0.085, f"{bone}Glow")
            low = []
            for k in range(steps + 1):
                dd = _LEN[i0] + (_LEN[i1] - _LEN[i0]) * k / steps
                p, t, n, r = at(dd)
                low.append(p + X * sx * r * 0.86 - n * r * (0.5 + 0.06 * math.cos(dd * 2.1)))
            vein(b, bone, low, 0.05, f"{bone}Glow")
        # gill slits behind the head: four glowing slashes
        for j in range(4):
            p, t, n, r = at(_LEN[7] - 0.9 - 0.62 * j)
            arc_pts = [p + (X * sx * math.cos(a) + n * math.sin(a)) * r * 1.0 for a in (math.radians(-58), math.radians(-30), math.radians(-4))]
            vein(b, "Neck3", arc_pts, 0.09, "GillGlow")
            b.part(sf.tube([tuple(q + t * 0.16) for q in arc_pts], [0.07, 0.1, 0.07], sides=4, resolution=2), "Neck3", "basalt")
    for i in range(16):                                               # barnacles and stone where it leaves the floor
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.2, 2.6)
        p, t, n, r = at(_LEN[1] + z - 1.0 if z > 1.0 else _LEN[1])
        base = V((p.x, p.y, max(z, 0.1))) + V((math.cos(a), math.sin(a), 0)) * r * 0.97
        d3 = V((math.cos(a), math.sin(a), 0.5))
        rr = rnd.uniform(0.16, 0.3)
        o = sf.cyl(rr, rr * 1.4, loc=base + d3.normalized() * rr * 0.4, verts=6, radius_top=rr * 0.5, bevel=0.0)
        o.rotation_euler = d3.to_track_quat("Z", "Y").to_euler()
        b.part(o, "Coil" if z < 1.0 else "Neck1", "sandstone")
    for i, a in enumerate((20, 75, 140, 200, 250, 310)):              # weed trailing from it
        p = V((0, 1.7, 0.3)) + V((math.cos(math.radians(a)), math.sin(math.radians(a)), 0)) * 2.5
        out = V((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        b.part(limb([p + V((0, 0, 1.6)), p + out * 0.7 + V((0, 0, 0.6)), p + out * 1.9 + V((0, 0, 0.06))],
                    [0.16, 0.12, 0.04], sides=4, resolution=2), "Coil", "plum")
    # the fins on the sides of its neck
    for side, sx in SIDES:
        p, t, n, r = at(_LEN[3] + 0.8)
        root = p + X * sx * r * 0.9 + n * 0.2
        fan(b, f"{side}Fin", root, [((X * sx * 0.8 + t * 1.0 + n * 0.5), 3.0), ((X * sx * 1.2 + t * 0.4 + n * 0.5), 3.7),
                                    ((X * sx * 1.25 - t * 0.2 + n * 0.5), 3.5), ((X * sx * 1.0 - t * 0.8 + n * 0.45), 2.7)],
            spread=tuple(t * 1.5), spine_r=0.1)

    # ================= the head =================
    b.part(blob(1.0, (0, -3.6, 10.85), scale=(1.78, 2.65, 1.3), segs=16, rings=9, noise=0.02, seed=301), "Head", "murk")   # cranium
    snout = blob(1.0, (0, -6.35, 10.32), scale=(1.36, 2.6, 0.74), segs=14, rings=7, noise=0.02, seed=302)
    snout.rotation_euler = (math.radians(-4), 0, 0)
    b.part(snout, "Head", "murk")
    b.part(blob(1.0, (0, -3.0, 9.3), scale=(1.4, 1.9, 0.95), segs=10, rings=6, seed=303), "Head", "sandstone")             # throat
    b.part(blob(1.0, (0, -6.0, 9.86), scale=(1.14, 2.3, 0.2), segs=10, rings=4, seed=304), "Head", "plum")                 # palate
    # the crown: the skull split around the Source (a weak point), ringed with horns of bone
    crown = blob(1.0, (0, -3.2, 11.95), scale=(1.0, 1.75, 0.62), segs=12, rings=7, noise=0.05, seed=305, name="Crown")
    sf.tag(crown, "Crown", "glow", "Neon", collision="queryhull", cast_shadow=False, role="WeakPoint")
    sf.bind(crown, b.arm, "Head")
    for sx in (-1, 1):
        for j, (y, ln, out) in enumerate(((-4.7, 1.5, 0.75), (-3.9, 2.1, 0.95), (-3.0, 2.5, 1.0), (-2.1, 2.2, 0.9), (-1.4, 1.6, 0.7))):
            base = V((sx * (0.95 + 0.12 * j), y, 11.75 - 0.05 * j))
            b.part(claw(base, (sx * out, 0.55, 1.0), ln, 0.26, bend=(-sx * 0.7, 0.9, 0), curl=0.42, sides=5, resolution=2),
                   "Head", "stone")
        plate(b, "Head", (sx * 0.95, -4.3, 11.72), (sx * 0.7, -0.2, 1), (0.6, 1.0, 0.17), seed=310)
        plate(b, "Head", (sx * 1.28, -3.0, 11.55), (sx * 0.9, 0, 1), (0.55, 1.1, 0.17), seed=311)
        plate(b, "Head", (sx * 1.0, -1.7, 11.5), (sx * 0.7, 0.4, 1), (0.6, 0.8, 0.17), seed=312)
        # three eyes down each side, the first the biggest, under one long brow
        for j, (ex, ey, ez, er) in enumerate(((1.42, -5.35, 11.1, 0.33), (1.62, -4.45, 11.28, 0.25), (1.7, -3.65, 11.36, 0.19))):
            eye(b, "Head", (sx * ex, ey, ez), er, facing=(sx * 1.0, -0.45, 0.25), segs=8)
        b.part(limb([(sx * 0.9, -6.3, 11.0), (sx * 1.5, -5.3, 11.62), (sx * 1.85, -4.2, 11.78), (sx * 1.8, -3.0, 11.6)],
                    [0.16, 0.24, 0.22, 0.14], sides=6, resolution=2), "Head", "basalt")
        b.part(sf.sphere(0.13, loc=(sx * 0.42, -8.72, 10.6), segs=6, rings=4), "Head", "basalt")                           # nostril
        # cheek spines and the corner of the mouth
        for j, (y, z, ln) in enumerate(((-2.6, 10.2, 1.5), (-2.3, 9.6, 1.2), (-2.9, 10.8, 1.3))):
            b.part(spike((sx * 1.5, y, z), (sx * 1.0, 0.8, -0.1 + 0.2 * j), ln, 0.16, verts=4), "Head", "stone")
    for j, (y, ln) in enumerate(((-8.3, 0.5), (-7.5, 0.7), (-6.7, 0.9), (-5.9, 1.0))):                                     # a ridge down the snout
        b.part(spike((0, y, 10.9 + 0.06 * j), (0, 0.35, 1), ln, 0.14, verts=4), "Head", "stone")
    # the upper teeth: needles round the lip, the four at the front too long to fit inside
    lip = []
    for a in range(200, 341, 14):
        lip.append(V((1.28 * math.cos(math.radians(a)), -6.35 + 2.5 * math.sin(math.radians(a)), 9.92)))
    for i, p in enumerate(lip):
        front = abs(p.x) < 0.95
        big = front and i in (3, 4, 6, 7)
        ln = 2.0 if big else (1.1 if i % 2 == 0 else 0.75)
        if big:
            b.part(claw(p + V((0, 0, 0.2)), (p.x * 0.12, -0.12, -1), ln, 0.19, bend=(0, 1, 0), curl=0.22, sides=5, resolution=2),
                   "Head", "cream")
        else:
            b.part(spike(p + V((0, 0, 0.15)), (p.x * 0.1, -0.05, -1), ln, 0.13, verts=4), "Head", "cream")
    for sx in (-1, 1):
        for j, y in enumerate((-5.6, -5.0, -4.4, -3.8)):
            b.part(spike((sx * 1.3, y, 10.0), (sx * 0.12, 0, -1), 0.95 - 0.12 * j, 0.12, verts=4), "Head", "cream")
    # its gullet glows (a weak point too: a shot down its throat counts)
    maw = blob(1.0, (0, -4.9, 9.72), scale=(0.95, 1.9, 0.32), segs=10, rings=5, seed=306, name="Maw")
    sf.tag(maw, "Maw", "glow", "Neon", collision="queryhull", cast_shadow=False, role="WeakPoint")
    sf.bind(maw, b.arm, "Head")

    # ================= the jaw =================
    jaw = blob(1.0, (0, -5.65, 8.98), scale=(1.26, 3.1, 0.56), segs=14, rings=6, noise=0.02, seed=320)
    b.part(jaw, "Jaw", "murk")
    sf.paint(jaw, "sandstone", lambda c, nrm: nrm.z < -0.35)
    b.part(blob(1.0, (0, -5.6, 9.42), scale=(1.06, 2.7, 0.16), segs=10, rings=4, seed=321), "Jaw", "plum")                 # the floor of the mouth
    b.part(claw((0, -8.45, 9.0), (0, -0.7, 1), 1.3, 0.3, bend=(0, 1, 0), curl=0.3, sides=5, resolution=2), "Jaw", "stone")  # the chin hook
    for i, a in enumerate(range(206, 335, 16)):
        p = V((1.18 * math.cos(math.radians(a)), -5.65 + 2.9 * math.sin(math.radians(a)), 9.4))
        big = i in (3, 5)
        if big:
            b.part(claw(p, (p.x * 0.14, -0.1, 1), 1.9, 0.18, bend=(0, 1, 0), curl=0.2, sides=5, resolution=2), "Jaw", "cream")
        else:
            b.part(spike(p, (p.x * 0.12, -0.04, 1), 1.25 if i % 2 == 0 else 0.8, 0.13, verts=4), "Jaw", "cream")
    for sx in (-1, 1):
        for j, y in enumerate((-4.9, -4.3, -3.7)):
            b.part(spike((sx * 1.2, y, 9.4), (sx * 0.1, 0, 1), 0.85 - 0.1 * j, 0.11, verts=4), "Jaw", "cream")
        # ribs of plum under the jaw, and two long barbels with a light at the end of each
        for j, y in enumerate((-7.2, -6.2, -5.2, -4.2)):
            b.part(limb([(sx * 0.15, y, 8.42), (sx * 0.8, y + 0.1, 8.56), (sx * 1.22, y + 0.2, 8.95)], [0.09, 0.1, 0.06],
                        sides=4, resolution=2), "Jaw", "plum")
        root = V((sx * 0.75, -7.3, 8.6))
        pts = [root, root + V((sx * 0.5, 0.3, -1.3)), root + V((sx * 0.9, 1.1, -2.8)), root + V((sx * 0.7, 1.6, -4.2))]
        b.part(limb(pts, [0.13, 0.1, 0.07, 0.05], sides=5, resolution=3), "Jaw", "plum")
        b.glow(blob(0.3, pts[-1] + V((0, 0, -0.22)), scale=(0.85, 0.85, 1.3), segs=8, rings=5, seed=322), "Jaw", "BarbelGlow")
    # ================= the inner jaw: it slides out of the throat when the mouth gapes =================
    b.part(limb([(0, -2.6, 9.72), (0, -3.6, 9.7), (0, -4.6, 9.66)], [0.5, 0.46, 0.42], sides=8, resolution=2), "InnerJaw", "plum")
    b.glow(sf.sphere(0.3, loc=(0, -4.75, 9.66), segs=8, rings=5), "InnerJaw", "InnerGlow")
    for i in range(8):
        a = i * math.tau / 8
        ring = V((math.cos(a) * 0.4, -4.62, 9.66 + math.sin(a) * 0.36))
        b.part(claw(ring, (math.cos(a) * 0.5, -1, math.sin(a) * 0.5), 0.8, 0.09, bend=(-math.cos(a), 0, -math.sin(a)),
                    curl=0.5, sides=4), "InnerJaw", "cream")

    # ================= the hood: a spined frill each side of the head =================
    for side, sx in SIDES:
        fan(b, f"{side}Frill", (sx * FRILL[0], FRILL[1], FRILL[2]),
            [((sx * 0.45, 0.72, 1.0), 3.3), ((sx * 0.85, 0.7, 0.5), 4.0), ((sx * 1.0, 0.62, 0.0), 4.3),
             ((sx * 0.85, 0.66, -0.5), 3.9), ((sx * 0.5, 0.72, -1.0), 3.0)], spread=(0, 0.2, -1.9), spine_r=0.13, thick=0.07)
        for j, z in enumerate((0.6, 0.0, -0.6)):
            vein(b, f"{side}Frill", [(sx * FRILL[0], FRILL[1] + 0.1, FRILL[2] - 0.2 + z * 0.6),
                                     (sx * (FRILL[0] + 1.3), FRILL[1] + 1.05, FRILL[2] + z * 1.2),
                                     (sx * (FRILL[0] + 2.3), FRILL[1] + 1.7, FRILL[2] + z * 2.0)], 0.05, f"{side}FrillGlow")

    # ================= the coil behind it: a hump of body out of the floor =================
    seg = limb(HUMP, HUMP_R, sides=14, resolution=3, name="Hump")
    b.part(seg, "Hump", "murk")
    sf.paint(seg, "sandstone", lambda c, nrm: nrm.z < -0.5)
    hump_st = []
    for k in (0.24, 0.36, 0.48, 0.6, 0.72):
        p, t = B.along(HUMP, k)
        n = (V((0, 0, 1)) - t * t.z).normalized()
        hump_st.append((p + n * 1.7, n, t))
    crest(b, "Hump", hump_st, [1.3, 1.9, 2.2, 1.9, 1.3], spine_r=0.1)
    for i, k in enumerate((0.22, 0.34, 0.46, 0.58, 0.7, 0.8)):
        p, t = B.along(HUMP, k)
        n = (V((0, 0, 1)) - t * t.z).normalized()
        s = t.cross(n).normalized()
        for sgn in (-1, 1):
            plate(b, "Hump", p + n * 1.55 + s * sgn * 0.85, n + s * sgn * 0.5, (0.55, 0.7, 0.15), seed=400 + i)
    for sgn in (-1, 1):
        pts = []
        for k in (0.14, 0.3, 0.46, 0.62, 0.78, 0.9):
            p, t = B.along(HUMP, k)
            n = (V((0, 0, 1)) - t * t.z).normalized()
            s = t.cross(n).normalized()
            pts.append(p + s * sgn * 1.82 + n * 0.25)
        vein(b, "Hump", pts, 0.08, "HumpGlow")

    # ================= the tail: up out of the floor to a ragged paddle =================
    for bone, i0, i1 in (("Tail1", 0, 2), ("Tail2", 2, 5)):
        b.part(limb(TAIL[i0:i1 + 1], TAIL_R[i0:i1 + 1], sides=10, resolution=3), bone, "murk")
    b.part(blob(TAIL_R[2] * 0.98, TAIL[2], segs=8, rings=5, seed=420), "Tail2", "murk")
    for sgn in (-1, 1):
        side_v = V((0.55, -0.83, 0)) * sgn
        bases = [TAIL[2], TAIL[3], TAIL[4], TAIL[5]]
        tips = [TAIL[2] + side_v * 1.4, TAIL[3] + side_v * 2.3 + V((0, 0, 0.3)), TAIL[4] + side_v * 2.2 + V((0, 0, 0.8)),
                TAIL[5] + side_v * 0.9 + V((0.4, 0, 0.9))]
        b.part(web(bases, tips, 0.06), "Tail2", "plum")
        for base, tip in zip(bases[:3], tips[:3]):
            b.part(spike(base, tip - base, (tip - base).length * 1.1, 0.08, verts=4), "Tail2", "basalt")
    vein(b, "Tail1", [TAIL[0] + V((0.9, -0.5, 0.8)), TAIL[1] + V((0.85, -0.5, 0)), TAIL[2] + V((0.6, -0.45, -0.3))], 0.06, "Tail1Glow")
    vein(b, "Tail2", [TAIL[2] + V((0.62, -0.45, 0.2)), TAIL[3] + V((0.45, -0.3, 0)), TAIL[4] + V((0.22, -0.2, 0))], 0.05, "Tail2Glow")


# ---- clips --------------------------------------------------------------------------------------

def neck(b, f, n1=(0, 0, 0), n2=(0, 0, 0), n3=(0, 0, 0), head=(0, 0, 0), ease="SINE"):
    b.key("Neck1", f, n1, ease=ease)
    b.key("Neck2", f, n2, ease=ease)
    b.key("Neck3", f, n3, ease=ease)
    b.key("Head", f, head, ease=ease)


def mouth(b, f, gape, inner=0.0, ease="SINE"):
    """gape opens the jaw (degrees); inner slides the second jaw out (studs)."""
    b.key("Jaw", f, (gape, 0, 0), ease=ease)
    b.key("InnerJaw", f, (0, 0, 0), loc=(0, 0, inner), ease=ease)


def hood(b, f, flare, shake=0.0, ease="SINE"):
    """flare opens the head frills (degrees, + out); the neck fins follow at half."""
    for side, sx in SIDES:
        b.key(f"{side}Frill", f, (0, -sx * (flare + sx * shake), 0), ease=ease)
        b.key(f"{side}Fin", f, (0, -sx * (flare * 0.5 - sx * shake * 0.6), sx * flare * 0.25), ease=ease)


def rear(b, f, hump=0.0, tail=0.0, tail_roll=0.0, ease="SINE"):
    b.key("Hump", f, (0, 0, 0), loc=(0, hump, 0), ease=ease)
    b.key("Tail1", f, (tail * 0.5, tail_roll * 0.5, tail), ease=ease)
    b.key("Tail2", f, (tail, tail_roll, tail * 1.4), ease=ease)


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 96, loop=True, priority="Idle")
    for f, k, s in ((0, 0, 0), (24, 1, 1), (48, 0, 0), (72, 1, -1), (96, 0, 0)):
        b.key("Coil", f, (0, 0, 0), loc=(0, 0.12 * k, 0))
        neck(b, f, (1 * k, 3 * s, 2 * s), (-2 * k, 3 * s, 0), (2 * k, 4 * s, 0), (3 - 2 * k, 7 * s, -3 * s))
        mouth(b, f, 7 + 7 * k, 0.15 * k)
        hood(b, f, 4 + 8 * k)
        rear(b, f, 0.2 * k, 7 * s, 9 * s)
    return act


def swim(b):
    """The head tucked down under the arch of the neck: sunk, only the crest cuts the floor."""
    act = sf.new_action(b.arm, "Swim", 0, 40, loop=True, priority="Movement")
    for f, s, c in ((0, 0, 1), (10, 1, 0), (20, 0, -1), (30, -1, 0), (40, 0, 1)):
        b.key("Coil", f, (0, 4 * s, 0), loc=(0, 0.15 * abs(c), 0))
        neck(b, f, (4, 6 * s, 3 * s), (16, 7 * c, 0), (40, -6 * s, 0), (52, -5 * c, 0))
        mouth(b, f, 3)
        hood(b, f, -30)
        rear(b, f, -0.3 + 0.3 * c, 10 * s, 12 * c)
    return act


def attack(b):
    """It draws back, the hood wide, then throws its head at the floor in front (0.7 s)."""
    act = sf.new_action(b.arm, "Attack", 0, 54, loop=False, priority="Action")
    b.rest(0)
    mouth(b, 0, 7)
    hood(b, 0, 4)
    neck(b, 12, (-6, 0, 0), (-8, 0, 0), (6, 0, 0), (-10, 0, 0), ease="QUAD")       # as far back as the ceiling allows
    mouth(b, 12, 58, 1.6, ease="QUAD")
    hood(b, 12, 36, ease="QUAD")
    rear(b, 12, 0.5, -10)
    neck(b, 21, (36, 0, 0), (26, 0, 0), (8, 0, 0), (-56, 0, 0), ease="QUAD")            # the strike lands
    mouth(b, 20, 50, 2.4, ease="QUAD")
    mouth(b, 23, 2, 0.2)
    hood(b, 21, 10)
    rear(b, 21, -0.3, 12)
    neck(b, 30, (36, 0, 0), (27, 0, 0), (8, 0, 0), (-54, 0, 0))
    neck(b, 44, (10, 0, 0), (8, 0, 0), (2, 0, 0), (-10, 0, 0))
    mouth(b, 44, 12)
    b.rest(54)
    mouth(b, 54, 7)
    hood(b, 54, 4)
    return act


def roar(b):
    """Up to the ceiling, the hood wide open and shaking, both jaws out."""
    act = sf.new_action(b.arm, "Roar", 0, 66, loop=False, priority="Action")
    b.rest(0)
    mouth(b, 0, 7)
    hood(b, 0, 4)
    neck(b, 10, (-6, 0, 0), (-10, 0, 0), (-16, 0, 0), (-30, 0, 0), ease="QUAD")
    mouth(b, 10, 30, 0.4)
    hood(b, 10, 20)
    for f, s in ((18, 1), (24, -1), (30, 1), (36, -1), (42, 1), (48, -1)):
        neck(b, f, (4, 3 * s, 2 * s), (2, 3 * s, 0), (-4, 4 * s, 0), (-16, 6 * s, 5 * s))
        mouth(b, f, 66 + 3 * s, 2.6)
        hood(b, f, 46, 7 * s)
        rear(b, f, 0.4, 10 * s, 14 * s)
        b.key("Coil", f, (0, 0, 0), loc=(0, 0.25, 0))
    neck(b, 58, (2, 0, 0), (0, 0, 0), (0, 0, 0), (-4, 0, 0))
    mouth(b, 58, 16, 0.3)
    b.rest(66)
    mouth(b, 66, 7)
    hood(b, 66, 4)
    return act


def stagger(b):
    """Its head is hit hard enough: it drops to the floor and lies there, mouth slack."""
    act = sf.new_action(b.arm, "Stagger", 0, 90, loop=False, priority="Action")
    b.rest(0)
    mouth(b, 0, 7)
    hood(b, 0, 4)
    neck(b, 6, (-4, 0, 6), (-6, 0, 0), (2, 0, 8), (-8, 10, 12), ease="QUAD")               # the blow
    mouth(b, 6, 40, 0.8)
    hood(b, 6, 30)
    down = ((30, 4, 6), (28, 0, 0), (20, 0, 4), (-66, 8, 14))
    neck(b, 18, *down, ease="QUAD")
    mouth(b, 18, 26, 0.3)
    hood(b, 18, -14)
    rear(b, 18, -0.5, 14, 8)
    for f, k in ((34, 1), (50, -1), (64, 1)):                                              # it lies there, heaving
        neck(b, f, (down[0][0] + k, 4, 6), (down[1][0] - k, 0, 0), down[2], (down[3][0] + 2 * k, 8, 14))
        mouth(b, f, 24 + 5 * k, 0.3)
        hood(b, f, -14 + 4 * k)
    neck(b, 80, (8, 0, 0), (6, 0, 0), (2, 0, 0), (-6, 0, 0))
    mouth(b, 80, 20)
    hood(b, 80, 16)
    b.rest(90)
    mouth(b, 90, 7)
    hood(b, 90, 4)
    return act


def death(b):
    """A last scream at the ceiling, then all of it comes down and doesn't get up."""
    act = sf.new_action(b.arm, "Death", 0, 110, loop=False, priority="Action")
    b.rest(0)
    mouth(b, 0, 7)
    hood(b, 0, 4)
    for f, s in ((10, 1), (18, -1), (26, 1), (34, -1)):
        neck(b, f, (-4, 6 * s, 4 * s), (-4, 5 * s, 0), (6, 6 * s, 0), (-12, 8 * s, 6 * s), ease="QUAD")
        mouth(b, f, 62, 2.2)
        hood(b, f, 44, 8 * s)
        rear(b, f, 0.5, 14 * s, 16 * s)
    neck(b, 58, (31, 6, 8), (29, 0, 0), (20, 0, 6), (-66, 10, 20), ease="QUAD")
    mouth(b, 58, 30, 0.4)
    hood(b, 58, -20)
    rear(b, 58, -1.2, 20, 10)
    b.key("Coil", 58, (0, 0, 0), loc=(0, -0.4, 0))
    neck(b, 66, (28, 6, 8), (27, 0, 0), (20, 0, 6), (-62, 10, 20))                          # it bounces once
    neck(b, 76, (31, 6, 8), (29, 0, 0), (20, 0, 6), (-67, 10, 22))
    mouth(b, 76, 22, 0.1)
    rear(b, 80, -2.2, 34, 12)
    neck(b, 110, (31, 6, 8), (29, 0, 0), (20, 0, 6), (-67, 10, 22))
    mouth(b, 110, 20, 0.0)
    hood(b, 110, -24)
    rear(b, 110, -2.4, 36, 12)
    b.key("Coil", 110, (0, 0, 0), loc=(0, -0.6, 0))
    return act


def clips(b):
    return [idle(b), swim(b), attack(b), roar(b), stagger(b), death(b)]


def measure(b, acts):
    """Where the snout is at the strike, and how high the model stands when it swims."""
    import bpy
    out = {}
    for act in acts:
        if act.name not in ("Attack", "Swim", "Stagger", "Death"):
            continue
        b.arm.animation_data.action = act
        if hasattr(b.arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
            b.arm.animation_data.action_slot = act.slots[0]
        frame = {"Attack": 21, "Swim": 10, "Stagger": 34, "Death": 110}[act.name]
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        pb = b.arm.pose.bones["Head"]
        rest = b.arm.data.bones["Head"].matrix_local
        snout = b.arm.matrix_world @ pb.matrix @ rest.inverted() @ V((0, -8.9, 10.2))
        top = b.arm.matrix_world @ pb.matrix @ rest.inverted() @ V((0, -3.2, 12.4))
        out[act.name] = (tuple(round(v, 2) for v in snout), tuple(round(v, 2) for v in top))
    bpy.context.scene.frame_set(0)
    return out


def hero_view():
    """A third preview from where a resident stands: low, in front, looking up at it."""
    sf.render_preview(ASSET, CATEGORY, views=[(-20, 3, False)], out_name=f"{ASSET}_hero")


if __name__ == "__main__":
    if os.environ.get("SF_EXPORT") != "1" and os.environ.get("SF_NORENDER") != "1":
        _build = build

        def build(b):                                    # noqa: F811
            _build(b)
            mannequin()
    acts_out = []

    def all_clips(b):
        acts = clips(b)
        acts_out.extend(acts)
        print("[Boss_Deluge] snout, crown:", measure(b, acts))
        return acts

    B.run(ASSET, CATEGORY, lambda: B.Beast("Deluge", JOINTS, collision="queryhull"), build, all_clips,
          budget=15000, hrp_center=(0, 1.6, 4.0), hrp_size=(5.0, 4.0, 5.0), step="A8",
          meta={"role": "Boss", "band": "FloodedCaverns", "era": 2, "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -12.5, 0.3), 0.0), "Maw": ((0, -6.0, 9.7), 0.0)},
          markers={"Attack": {"Hit": HIT_TIME}},
          pivot=(0.0, 0.0, 0.0))        # the floor under where its neck comes up: its coils stay below it
    if os.environ.get("SF_NORENDER") != "1":
        hero_view()
