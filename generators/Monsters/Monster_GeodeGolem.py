"""Monster_GeodeGolem: the Crystal Hollows tank (bible Section 10: "Very slow with huge health;
shrugs off small guns"). A boulder that stood up. Its torso is a geode: a rough basalt and plum
rind split down the chest by a crack as wide as a hand, the hollow behind it lined with crystal
that lights the room in front of it. A small head-stone sits sunk between shoulders heaped with
slabs, two eyes burning in a slot. Its arms hang to the floor, each forearm a boulder ending in
a fist of crystal, and its legs are two short pillars. It doesn't hurry and it doesn't flinch.

About 8.6 studs tall and 8 across the fists: it fills a doorway.

Rig: Body (the pelvis, root), Chest, Head, upper arms and forearms, two legs. Clips: Idle (a
slow heave of the chest, the fists settling), Walk (a lumbering sway), Attack (both fists up
and down together, Hit at 0.6 s; Smash socket where they land).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_GeodeGolem.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, limb, blob, shell, eye, shard, cluster  # noqa: E402,F401

ASSET, CATEGORY = "Monster_GeodeGolem", "Monsters"
HIT_TIME = 0.6
JOINTS = [
    ("Body", None, (0, 0.2, 2.9)),
    ("Chest", "Body", (0, 0.1, 4.2)),
    ("Head", "Chest", (0, -0.75, 6.75)),
    ("LeftArm", "Chest", (2.45, 0.0, 6.3)),
    ("LeftForearm", "LeftArm", (3.35, -0.3, 3.9)),
    ("RightArm", "Chest", (-2.45, 0.0, 6.3)),
    ("RightForearm", "RightArm", (-3.35, -0.3, 3.9)),
    ("LeftLeg", "Body", (1.15, 0.2, 2.6)),
    ("RightLeg", "Body", (-1.15, 0.2, 2.6)),
]


def rock(radius, loc, scale, seed, segs=8, rings=5, noise=0.12):
    """A boulder: a coarse sphere pushed about, flat-shaded by its own facets."""
    return blob(radius, loc, scale=scale, segs=segs, rings=rings, noise=noise, seed=seed)


def slab(size, loc, rot, seed):
    """A broken plate of rind lying on the body: a flattened, chipped stone."""
    o = blob(0.5, (0, 0, 0), scale=(size[0] * 1.15, size[1] * 1.15, size[2] * 1.15), segs=6, rings=4, noise=0.16, seed=seed)
    o.location = loc
    o.rotation_euler = rot
    return o


def build(b):
    # ---- the pelvis and legs: two short pillars under a boulder
    b.part(rock(1.5, (0, 0.25, 2.9), (1.25, 1.0, 0.7), 2), "Body", "basalt", smooth_angle=None)
    b.part(slab((2.6, 0.7, 0.9), (0, -1.05, 2.75), (0.25, 0, 0), 3), "Body", "plum", smooth_angle=None)                  # a belt of rind
    for o in cluster((0.9, -1.2, 2.5), (0.3, -1.0, -0.3), 3, 0.7, 0.16, seed=4, sides=5):
        b.part(o, "Body", "crystal")
    for name, sx in (("LeftLeg", 1), ("RightLeg", -1)):
        b.part(rock(0.95, (sx * 1.15, 0.2, 1.8), (0.95, 1.05, 1.25), 5 + sx, noise=0.1), name, "basalt", smooth_angle=None)
        b.part(rock(1.1, (sx * 1.2, 0.05, 0.62), (1.05, 1.3, 0.58), 8 + sx, noise=0.1), name, "stone", smooth_angle=None)  # the foot
        b.part(slab((1.2, 0.55, 1.0), (sx * 1.2, -0.85, 1.75), (0.15, 0, sx * 0.1), 11 + sx), name, "stone", smooth_angle=None)  # a knee plate
        for i, x in enumerate((-0.4, 0.4)):
            b.part(shard((sx * 1.2 + x, -1.2, 0.2), (x * 0.4, -1.0, 0.25), 0.6, 0.2, sides=4), name, "crystal")  # toes

    # ---- the chest: a geode. The rind in two halves, the hollow between them lined with crystal
    for sx in (-1, 1):
        b.part(rock(2.0, (sx * 1.45, 0.2, 5.0), (0.72, 1.05, 1.14), 20 + sx, segs=9, rings=6, noise=0.1), "Chest", "basalt", smooth_angle=None)
        b.part(slab((1.5, 0.6, 2.1), (sx * 1.9, -1.5, 5.3), (0.12, 0.0, sx * 0.4), 23 + sx), "Chest", "stone", smooth_angle=None)
        b.part(slab((1.3, 0.5, 1.2), (sx * 1.75, -1.45, 3.8), (-0.2, 0.0, sx * 0.35), 26 + sx), "Chest", "basalt", smooth_angle=None)
        # the lips of the crack: a ragged pale edge
        b.part(limb([(sx * 0.62, -1.6, 6.35), (sx * 0.95, -2.0, 5.3), (sx * 0.72, -2.0, 4.3), (sx * 0.85, -1.65, 3.4)],
                    [0.12, 0.2, 0.18, 0.1], sides=4, resolution=2), "Chest", "stone")
    b.part(rock(1.9, (0, 0.9, 5.1), (1.25, 0.8, 1.15), 30, noise=0.1), "Chest", "basalt", smooth_angle=None)             # the back
    b.part(rock(1.5, (0, 0.2, 4.9), (0.8, 0.9, 1.1), 31, segs=8, rings=5, noise=0.04), "Chest", "plum", smooth_angle=None)   # the hollow's wall
    b.neon(blob(0.62, (0, -1.2, 4.9), scale=(0.95, 0.5, 1.8), segs=7, rings=5, seed=32), "Chest", "ChestGlow")  # its heart of light
    rnd = random.Random(33)
    for i in range(10):                                                                               # crystal lining
        z = 3.55 + i * 0.3
        sx = -1 if i % 2 else 1
        b.part(shard((sx * 0.8, -1.5, z), (-sx * 1.0, -0.35 + rnd.uniform(-0.2, 0.2), rnd.uniform(-0.3, 0.3)),
                     rnd.uniform(0.5, 0.8), 0.17, sides=4, twist=rnd.uniform(-1, 1)), "Chest", "crystal")
    # shoulders heaped with slabs, and a crest of crystal up the back
    for sx in (-1, 1):
        b.part(rock(1.3, (sx * 2.3, 0.1, 6.5), (1.15, 1.1, 0.85), 40 + sx, noise=0.12), "Chest", "basalt", smooth_angle=None)
        b.part(slab((2.0, 1.6, 0.55), (sx * 2.35, 0.0, 7.3), (0.1, sx * 0.3, 0.2 * sx), 43 + sx), "Chest", "stone", smooth_angle=None)
        b.part(slab((1.3, 1.3, 0.5), (sx * 3.0, 0.3, 6.9), (0.2, sx * 0.55, 0.0), 46 + sx), "Chest", "plum", smooth_angle=None)
    for i, (x, y, ln, r) in enumerate(((0.0, 1.5, 2.9, 0.44), (0.9, 1.35, 2.0, 0.34), (-0.95, 1.4, 2.2, 0.36),
                                       (1.8, 0.9, 1.5, 0.28), (-1.85, 0.95, 1.6, 0.3), (0.4, 1.9, 1.6, 0.28),
                                       (-0.45, 1.95, 1.4, 0.26))):
        b.part(shard((x, y, 6.2), (x * 0.25, 0.45, 1.0), ln, r, twist=0.5 * i), "Chest", "crystal")
    b.neon(shard((0.0, 2.72, 8.82), (0, 0.45, 1.0), 0.5, 0.14, sides=5), "Chest", "ChestGlow")

    # ---- the head: a stone sunk between the shoulders, two eyes in a slot
    b.part(rock(0.95, (0, -0.95, 7.0), (1.05, 0.95, 0.8), 50, noise=0.1), "Head", "basalt", smooth_angle=None)
    b.part(slab((1.8, 0.9, 0.55), (0, -1.25, 7.5), (0.3, 0, 0), 51), "Head", "stone", smooth_angle=None)                 # brow
    b.part(slab((1.4, 0.8, 0.6), (0, -1.45, 6.55), (-0.2, 0, 0), 52), "Head", "stone", smooth_angle=None)                # jaw
    b.part(sf.box((1.25, 0.3, 0.3), loc=(0, -1.72, 7.05), bevel=0.03, segments=1), "Head", "rubber")  # the slot
    for sx in (-1, 1):
        b.glow(sf.sphere(0.14, loc=(sx * 0.34, -1.84, 7.05), scale=(1.3, 0.6, 0.9), segs=7, rings=5), "Head", "HeadGlow")
        b.part(shard((sx * 0.55, -0.7, 7.55), (sx * 0.5, 0.2, 1.0), 0.8, 0.16, sides=5), "Head", "crystal")

    # ---- the arms: an upper arm of rock, a forearm like a boulder, a fist of crystal
    for side, sx in (("Left", 1), ("Right", -1)):
        arm, fore = f"{side}Arm", f"{side}Forearm"
        b.part(rock(1.0, (sx * 2.85, -0.1, 5.2), (0.9, 0.95, 1.45), 60 + sx, noise=0.1), arm, "basalt", smooth_angle=None)
        b.part(slab((0.6, 1.4, 1.7), (sx * 3.6, -0.15, 5.3), (0, sx * 0.15, 0), 63 + sx), arm, "stone", smooth_angle=None)
        b.part(rock(1.3, (sx * 3.45, -0.5, 2.7), (0.98, 1.05, 1.5), 66 + sx, segs=9, rings=6, noise=0.1), fore, "basalt", smooth_angle=None)
        b.part(slab((0.7, 1.6, 1.8), (sx * 4.35, -0.5, 2.9), (0, sx * 0.12, 0), 69 + sx), fore, "stone", smooth_angle=None)
        b.part(slab((1.5, 0.6, 1.4), (sx * 3.45, -1.55, 3.0), (0.1, 0, 0), 72 + sx), fore, "plum", smooth_angle=None)
        b.part(rock(1.0, (sx * 3.5, -0.75, 1.0), (1.0, 1.05, 0.85), 75 + sx, noise=0.1), fore, "stone", smooth_angle=None)   # the fist
        for o in cluster((sx * 3.5, -1.2, 0.85), (0, -1.0, -0.1), 5, 1.7, 0.38, spread=0.65, seed=78 + sx, sides=5):
            b.part(o, fore, "crystal")
        for i, (dx, dz) in enumerate(((0.85, 0.3), (-0.85, 0.25), (0.0, 0.95))):
            b.part(shard((sx * 3.5 + dx, -0.7, 1.0 + dz), (dx, -0.45, dz), 1.0, 0.24, sides=5), fore, "crystal")
        b.neon(sf.sphere(0.24, loc=(sx * 3.5, -1.5, 0.95), segs=6, rings=4), fore, "FistGlow")
        # a seam of light in the forearm's cracks
        b.neon(limb([(sx * 3.0, -1.45, 3.6), (sx * 3.3, -1.72, 2.9), (sx * 3.1, -1.6, 2.1)], [0.05, 0.08, 0.05],
                    sides=3, resolution=1), fore, "FistGlow")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 48, loop=True, priority="Movement")
    for f, k in ((0, 1), (12, 0), (24, -1), (36, 0), (48, 1)):
        up = 1 - abs(k)
        b.key("Body", f, (3, 0, 4 * k), loc=(0, -0.12 * abs(k), 0))
        b.key("Chest", f, (4, -5 * k, -3 * k))
        b.key("Head", f, (2, 4 * k, 0))
        b.key("LeftLeg", f, (-16 * k, 0, 0), loc=(0, 0.25 * up * (k <= 0), 0))
        b.key("RightLeg", f, (16 * k, 0, 0), loc=(0, 0.25 * up * (k >= 0), 0))
        b.key("LeftArm", f, (12 * k, 0, 2))
        b.key("RightArm", f, (-12 * k, 0, -2))
        b.key("LeftForearm", f, (-8 + 6 * k, 0, 0))
        b.key("RightForearm", f, (-8 - 6 * k, 0, 0))
    return act


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 90, loop=True, priority="Idle")
    for f, k in ((0, 0), (22, 1), (45, 0), (68, -1), (90, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, -0.05 * abs(k), 0))
        b.key("Chest", f, (2 * abs(k), 2 * k, 0))
        b.key("Head", f, (3 * abs(k), 8 * k, 0))
        b.key("LeftArm", f, (0, 0, 2 * abs(k)))
        b.key("RightArm", f, (0, 0, -2 * abs(k)))
        b.key("LeftForearm", f, (-3 * abs(k), 0, 0))
        b.key("RightForearm", f, (-3 * abs(k), 0, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 36, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 12, (-8, 0, 0), loc=(0, 0.1, -0.2))                   # rears back, both fists overhead
    b.key("Chest", 12, (-20, 0, 0))
    b.key("Head", 12, (-10, 0, 0))
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 12, (-150, 0, sx * 12))
        b.key(f"{side}Forearm", 12, (-30, 0, 0))
    b.key("Body", 18, (14, 0, 0), loc=(0, -0.25, 0.3), ease="QUAD")     # down they come: the blow lands at 0.6 s
    b.key("Chest", 18, (26, 0, 0), ease="QUAD")
    b.key("Head", 18, (-12, 0, 0), ease="QUAD")
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 18, (-62, 0, -sx * 6), ease="QUAD")
        b.key(f"{side}Forearm", 18, (-14, 0, 0), ease="QUAD")
    b.key("Body", 24, (12, 0, 0), loc=(0, -0.2, 0.25))                  # holds in the dust
    b.key("Chest", 24, (22, 0, 0))
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 24, (-58, 0, -sx * 6))
        b.key(f"{side}Forearm", 24, (-12, 0, 0))
    b.rest(36)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("GeodeGolem", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.2, 2.9), hrp_size=(4.0, 2.0, 3.0), step="A10",
          meta={"role": "Tank", "band": "CrystalHollows", "hitTime": HIT_TIME},
          sockets={"Smash": ((0, -4.6, 0.3), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
