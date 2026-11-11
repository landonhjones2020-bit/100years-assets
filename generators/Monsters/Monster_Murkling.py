"""Monster_Murkling: the Flooded Caverns swarmer (bible Section 10: "Pours out of water; weak
alone"). A cave newt the Source got into: a head that is mostly mouth, an underbite of needle
teeth, two bulging glowing eyes set on top like a frog's, plum feathered gills, a pale belly
under a wet murk back with a row of glowing spots down each flank, four splayed webbed legs
and a finned tail that whips as it runs. One is nothing; ten out of a flooded room is a
problem. Scary, never gory.

About 4.3 studs nose to tail and 1.5 high: a resident's shin.

Rig: Body (root), Head, Jaw, Tail, TailTip, four one-bone legs. Clips: Idle (breathing, the
gills and tail drifting), Walk (a fast splayed scuttle, the body and tail snaking), Attack (a
lunge and snap, Hit at 0.25 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_Murkling.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, web  # noqa: E402,F401

ASSET, CATEGORY = "Monster_Murkling", "Monsters"
HIT_TIME = 0.25
LEGS = (("LeftArm", 1, -0.3), ("RightArm", -1, -0.3), ("LeftLeg", 1, 0.72), ("RightLeg", -1, 0.72))
JOINTS = [
    ("Body", None, (0, 0.2, 0.62)),
    ("Head", "Body", (0, -0.5, 0.68)),
    ("Jaw", "Head", (0, -0.72, 0.5)),
    ("Tail", "Body", (0, 1.0, 0.6)),
    ("TailTip", "Tail", (0, 1.85, 0.56)),
] + [(name, "Body", (sx * 0.4, y, 0.52)) for name, sx, y in LEGS]


def build(b):
    # ---- the body: a wet murk back over a pale belly, glowing spots down each flank
    b.part(blob(0.6, (0, 0.2, 0.7), scale=(0.95, 1.55, 0.74), segs=12, rings=7, noise=0.03, seed=11), "Body", "murk")
    b.part(blob(0.52, (0, 0.18, 0.5), scale=(0.9, 1.5, 0.6), segs=10, rings=5, seed=12), "Body", "sandstone")
    for i, (x, y, r) in enumerate(((0.2, -0.3, 0.13), (-0.24, 0.0, 0.15), (0.22, 0.34, 0.14), (-0.18, 0.68, 0.11),
                                   (0.3, 0.05, 0.09), (-0.34, 0.4, 0.09))):
        z = 0.7 + 0.44 * (1 - (x / 0.57) ** 2 - ((y - 0.2) / 0.93) ** 2) ** 0.5
        b.part(blob(r, (x, y, z - 0.03), scale=(1.2, 1.5, 0.45), segs=6, rings=4, seed=20 + i), "Body", "basalt")  # blotches
    for sx in (-1, 1):
        for i, y in enumerate((-0.25, 0.15, 0.55)):
            b.glow(sf.sphere(0.07 - i * 0.008, loc=(sx * 0.535, y, 0.66), segs=6, rings=4), "Body", "BodyGlow")
    # the back fin: spines with a plum membrane between them
    ridge = [(0, -0.45, 1.1), (0, -0.1, 1.2), (0, 0.3, 1.2), (0, 0.7, 1.1), (0, 1.05, 0.92)]
    tips = [(0, -0.4, 1.3), (0, 0.0, 1.62), (0, 0.42, 1.68), (0, 0.84, 1.5), (0, 1.2, 1.12)]
    b.part(web(ridge, tips, 0.04), "Body", "plum")
    for base, tip in zip(ridge[1:4], tips[1:4]):
        d = sf.Vector(tip) - sf.Vector(base)
        b.part(spike(sf.Vector(base) - d * 0.1, d, d.length * 1.18, 0.035, verts=3), "Body", "basalt")

    # ---- the head: mostly mouth
    b.part(blob(0.56, (0, -1.02, 0.78), scale=(1.14, 1.3, 0.62), segs=12, rings=7, noise=0.03, seed=13), "Head", "murk")
    b.part(blob(0.3, (0, -1.6, 0.74), scale=(1.5, 0.8, 0.5), segs=8, rings=5, seed=14), "Head", "murk")      # the snout
    b.glow(blob(0.3, (0, -1.0, 0.58), scale=(1.3, 1.5, 0.3), segs=8, rings=4, seed=15), "Head", "HeadGlow")  # its throat
    for sx in (-1, 1):
        # frog eyes, high and wide, each in a dark socket with a brow ridge
        eye(b, "Head", (sx * 0.36, -1.14, 1.1), 0.15, facing=(sx * 0.45, -0.5, 0.75), segs=8)
        b.part(limb([(sx * 0.14, -1.3, 1.08), (sx * 0.4, -1.0, 1.24), (sx * 0.56, -0.8, 1.06)], [0.05, 0.07, 0.04],
                    sides=4, resolution=2), "Head", "basalt")
        b.part(sf.sphere(0.03, loc=(sx * 0.14, -1.86, 0.84), segs=5, rings=3), "Head", "basalt")              # nostril
        # feathered gills: three plum stalks fanning back, each with its fronds
        for i, (dy, dz, ln) in enumerate(((0.0, 0.34, 0.62), (0.08, 0.1, 0.72), (0.02, -0.14, 0.56))):
            root = sf.Vector((sx * 0.52, -0.62 + dy, 0.78 + dz * 0.4))
            tip = root + sf.Vector((sx * 0.42, 0.5, dz)).normalized() * ln
            mid = (root + tip) / 2 + sf.Vector((sx * 0.08, 0, 0.05))
            b.part(limb([root, mid, tip], [0.06, 0.045, 0.015], sides=4, resolution=2), "Head", "plum")
            for k in (0.35, 0.6, 0.85):
                at = root + (tip - root) * k
                b.part(spike(at, (sx * 0.3, 0.2, 1.0), 0.16 * (1.1 - k * 0.5), 0.022, verts=3), "Head", "plum")
                b.part(spike(at, (sx * 0.3, 0.2, -1.0), 0.14 * (1.1 - k * 0.5), 0.022, verts=3), "Head", "plum")
    # upper teeth along the lip, pointing down and a little in
    lip = B.arc((0, -1.2, 0.6), 0.62, 200, 340, 11)
    for i, p in enumerate(lip):
        p = sf.Vector((p.x * 0.92, p.y * 1.0 - 0.02, 0.62))
        b.part(spike(p, (-p.x * 0.15, 0.1, -1.0), 0.17 if i % 2 == 0 else 0.11, 0.03, verts=3), "Head", "cream")

    # ---- the jaw: a pale underbite, its needles standing past the top lip
    b.part(blob(0.5, (0, -1.16, 0.44), scale=(1.16, 1.42, 0.3), segs=10, rings=5, seed=16), "Jaw", "sandstone")
    b.part(shell((0.6, 0.74, 0.18), (0, -1.16, 0.4), -1.0, 0.5, z_from=-1.0, thickness=0.03, segs=10, rings=4),
           "Jaw", "murk")
    under = B.arc((0, -1.22, 0.5), 0.66, 205, 335, 9)
    for i, p in enumerate(under):
        p = sf.Vector((p.x * 0.9, p.y * 1.04, 0.5))
        b.part(spike(p, (-p.x * 0.1, 0.05, 1.0), 0.26 if i % 2 == 0 else 0.16, 0.034, verts=3), "Jaw", "cream")
    b.part(limb([(0, -0.9, 0.5), (0, -1.3, 0.56), (0, -1.6, 0.52)], [0.12, 0.1, 0.05], sides=4, resolution=1),
           "Jaw", "plum")                                                                                    # tongue

    # ---- the tail: two bones, a fin above and below
    b.part(limb([(0, 0.85, 0.66), (0, 1.3, 0.62), (0, 1.85, 0.56)], [0.36, 0.27, 0.18], sides=8, resolution=2),
           "Tail", "murk")
    b.part(limb([(0, 0.9, 0.5), (0, 1.35, 0.5), (0, 1.8, 0.5)], [0.24, 0.18, 0.1], sides=6, resolution=1),
           "Tail", "sandstone")
    b.part(web([(0, 1.0, 0.9), (0, 1.4, 0.84), (0, 1.85, 0.72)], [(0, 1.1, 1.1), (0, 1.5, 1.14), (0, 1.9, 1.0)], 0.04),
           "Tail", "plum")
    b.part(limb([(0, 1.8, 0.56), (0, 2.25, 0.54), (0, 2.7, 0.6)], [0.18, 0.11, 0.02], sides=6, resolution=2),
           "TailTip", "murk")
    b.part(web([(0, 1.85, 0.7), (0, 2.25, 0.63), (0, 2.7, 0.6)], [(0, 1.9, 1.0), (0, 2.45, 1.02), (0, 2.85, 0.74)], 0.04),
           "TailTip", "plum")
    b.part(web([(0, 1.85, 0.42), (0, 2.25, 0.45), (0, 2.7, 0.6)], [(0, 1.95, 0.2), (0, 2.45, 0.16), (0, 2.85, 0.5)], 0.04),
           "TailTip", "plum")
    for sx in (-1, 1):
        b.glow(sf.sphere(0.05, loc=(sx * 0.27, 1.25, 0.64), segs=6, rings=4), "Tail", "TailGlow")
        b.glow(sf.sphere(0.04, loc=(sx * 0.2, 1.65, 0.6), segs=6, rings=4), "Tail", "TailGlow")

    # ---- four splayed legs: out to an elbow, down to a webbed foot
    for name, sx, y in LEGS:
        front = -1 if "Arm" in name else 1
        hip = sf.Vector((sx * 0.4, y, 0.52))
        elbow = sf.Vector((sx * 0.98, y + front * 0.1, 0.5))
        foot = sf.Vector((sx * 1.16, y - 0.2, 0.06))
        b.part(limb([hip, (hip + elbow) / 2 + sf.Vector((0, 0, 0.08)), elbow], [0.2, 0.17, 0.13], sides=6,
                    resolution=1), name, "murk")
        b.part(limb([elbow, (elbow + foot) / 2 + sf.Vector((sx * 0.08, 0, 0.02)), foot], [0.13, 0.1, 0.08], sides=6,
                    resolution=1), name, "murk")
        toes = [foot + sf.Vector((sx * 0.3 * c, -0.4 * s, -0.03)) for c, s in ((1.0, 0.0), (0.75, 0.7), (0.15, 1.0))]
        for t in toes:
            b.part(spike(foot, t - foot, (t - foot).length * 1.2, 0.04, verts=3), name, "cream")
        b.part(web([foot, foot, foot], toes, 0.025), name, "plum")


def gait(b, f, k, sway):
    """One moment of the scuttle: k swings the diagonal leg pairs, sway snakes the spine."""
    b.key("LeftArm", f, (0, 26 * k, 8 * max(k, 0)))
    b.key("RightLeg", f, (0, 22 * k, -8 * max(k, 0)))
    b.key("RightArm", f, (0, 26 * k, -8 * max(-k, 0)))
    b.key("LeftLeg", f, (0, 22 * k, 8 * max(-k, 0)))
    b.key("Body", f, (0, sway * 7, 0), loc=(0, 0.04 * abs(k), 0))
    b.key("Head", f, (2, -sway * 9, 0))
    b.key("Tail", f, (0, -sway * 20, 0))
    b.key("TailTip", f, (0, -sway * 26, 0))


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 16, loop=True, priority="Movement")
    for f, k, sway in ((0, 1, 0), (4, 0, 1), (8, -1, 0), (12, 0, -1), (16, 1, 0)):
        gait(b, f, k, sway)
        b.key("Jaw", f, (8 + 6 * abs(sway), 0, 0))
    return act


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 60, loop=True, priority="Idle")
    for f, k in ((0, 0), (15, 1), (30, 0), (45, -1), (60, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, 0.03 * abs(k), 0))
        b.key("Head", f, (-3 * abs(k), 6 * k, 0))
        b.key("Jaw", f, (6 + 8 * abs(k), 0, 0))
        b.key("Tail", f, (0, 12 * k, 0))
        b.key("TailTip", f, (0, 18 * k, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 18, loop=False, priority="Action")
    b.rest(0)
    b.key("Jaw", 0, (6, 0, 0))
    b.key("Body", 4, (-8, 0, 0), loc=(0, 0.05, -0.25))                 # gathers back
    b.key("Head", 4, (-22, 0, 0))
    b.key("Jaw", 4, (48, 0, 0))
    b.key("Tail", 4, (-14, 0, 0))
    b.key("Body", 7, (6, 0, 0), loc=(0, 0.0, 0.55), ease="QUAD")       # lunges; the snap lands at 0.25 s
    b.key("Head", 7, (10, 0, 0), ease="QUAD")
    b.key("Jaw", 7, (40, 0, 0), ease="QUAD")
    b.key("Jaw", 9, (-2, 0, 0))
    b.key("Tail", 8, (10, 0, 0))
    b.key("Body", 12, (2, 0, 0), loc=(0, 0, 0.2))
    b.rest(18)
    b.key("Jaw", 18, (6, 0, 0))
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("Murkling", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=3000, hrp_center=(0, 0.2, 0.62), hrp_size=(1.6, 1.0, 2.6), step="A8",
          meta={"role": "Swarmer", "band": "FloodedCaverns", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -1.8, 0.6), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
