"""Monster_Shardling: the Crystal Hollows swarmer (bible Section 10: "Crystal bugs that shatter
into stinging shards"). A cave louse the crystal grew through: a low basalt carapace in three
plates, split along the back by a ridge of crystal shards that has pushed up through it, six
thin jointed legs that end in crystal points, two crystal mandibles like tongs and four small
glowing eyes under the front plate. It skitters in packs and comes apart when it dies, so the
shards are the loudest thing on it. Scary, never gory.

About 3.4 studs long and 2 high to the tip of its tallest shard: a resident's knee.

Rig: Body (root), Head, LeftMandible, RightMandible, Tail (the rear plate and its shards), six
one-bone legs. Clips: Idle (plates breathing, mandibles ticking), Walk (a tripod skitter),
Attack (rears and snaps its mandibles shut, Hit at 0.2 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_Shardling.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, limb, blob, shell, eye, shard, cluster  # noqa: E402,F401

ASSET, CATEGORY = "Monster_Shardling", "Monsters"
HIT_TIME = 0.2
LEGS = (("LeftLeg1", 1, -0.55), ("RightLeg1", -1, -0.55), ("LeftLeg2", 1, 0.0), ("RightLeg2", -1, 0.0),
        ("LeftLeg3", 1, 0.55), ("RightLeg3", -1, 0.55))
JOINTS = [
    ("Body", None, (0, 0.0, 0.62)),
    ("Head", "Body", (0, -0.78, 0.6)),
    ("LeftMandible", "Head", (0.2, -1.2, 0.5)),
    ("RightMandible", "Head", (-0.2, -1.2, 0.5)),
    ("Tail", "Body", (0, 0.72, 0.62)),
] + [(name, "Body", (sx * 0.42, y, 0.52)) for name, sx, y in LEGS]


def build(b):
    # ---- the body: a pale underside, three overlapping basalt plates, a crystal ridge through them
    b.part(blob(0.5, (0, 0.0, 0.52), scale=(1.0, 1.75, 0.5), segs=10, rings=5, seed=3), "Body", "plum")
    b.part(shell((0.7, 0.62, 0.52), (0, -0.3, 0.5), -1.0, 0.95, z_from=0.0, thickness=0.07, segs=12, rings=8),
           "Body", "basalt")
    b.part(shell((0.76, 0.58, 0.56), (0, 0.28, 0.52), -1.0, 0.9, z_from=0.0, thickness=0.07, segs=12, rings=8),
           "Body", "basalt")
    for sx in (-1, 1):
        # the plates' rims: a lighter lip where one rides over the next
        b.part(limb([(sx * 0.68, -0.6, 0.52), (sx * 0.74, -0.25, 0.6), (sx * 0.7, 0.1, 0.52)], [0.035, 0.05, 0.035],
                    sides=4, resolution=2), "Body", "stone")
        b.part(limb([(sx * 0.74, 0.0, 0.54), (sx * 0.8, 0.3, 0.62), (sx * 0.74, 0.62, 0.54)], [0.035, 0.05, 0.035],
                    sides=4, resolution=2), "Body", "stone")
        # glowing seams where the crystal shows through the cracks
        b.neon(limb([(sx * 0.3, -0.62, 0.92), (sx * 0.22, -0.3, 1.0), (sx * 0.3, 0.02, 0.96)], [0.022, 0.03, 0.02],
                    sides=3, resolution=1), "Body", "BodyGlow")
    # the ridge: shards that have grown up through the back, the tallest in the middle
    for i, (y, ln, r, lean) in enumerate(((-0.5, 0.62, 0.13, -0.5), (-0.2, 0.95, 0.17, -0.2), (0.14, 1.22, 0.2, 0.05),
                                          (0.46, 0.86, 0.16, 0.35))):
        b.part(shard((0, y, 0.92), (0.06 * (-1) ** i, lean, 1.0), ln, r, twist=0.4 * i), "Body", "crystal")
    for i, (x, y, ln) in enumerate(((0.3, -0.34, 0.5), (-0.32, -0.08, 0.58), (0.34, 0.22, 0.62), (-0.3, 0.44, 0.46),
                                    (0.2, 0.02, 0.4), (-0.18, -0.5, 0.36))):
        b.part(shard((x, y, 0.84), (x * 1.6, 0.25 * (-1) ** i, 1.0), ln, 0.09, sides=5, twist=0.3 * i), "Body", "crystal")
    b.neon(shard((0, 0.14, 1.9), (0.02, 0.05, 1.0), 0.3, 0.07, sides=5), "Body", "BodyGlow")       # the tall one's lit tip
    b.neon(shard((0, -0.2, 1.72), (-0.02, -0.2, 1.0), 0.2, 0.055, sides=5), "Body", "BodyGlow")

    # ---- the rear plate, with its own fan of shards pointing back
    b.part(shell((0.62, 0.6, 0.46), (0, 0.9, 0.5), -0.8, 1.0, z_from=0.0, thickness=0.07, segs=12, rings=8),
           "Tail", "basalt")
    b.part(blob(0.36, (0, 0.95, 0.46), scale=(1.1, 1.3, 0.55), segs=8, rings=4, seed=5), "Tail", "plum")
    for o in cluster((0, 1.1, 0.74), (0, 0.75, 1.0), 6, 0.9, 0.15, spread=0.55, seed=8):
        b.part(o, "Tail", "crystal")
    for sx in (-1, 1):
        b.part(shard((sx * 0.3, 1.3, 0.46), (sx * 0.5, 1.0, 0.25), 0.5, 0.08, sides=5), "Tail", "crystal")
    b.neon(sf.sphere(0.07, loc=(0, 1.44, 0.5), segs=6, rings=4), "Tail", "TailGlow")

    # ---- the head: a wedge plate over four eyes, crystal feelers
    b.part(blob(0.4, (0, -0.95, 0.56), scale=(1.15, 1.1, 0.72), segs=10, rings=6, seed=7), "Head", "basalt")
    b.part(shell((0.5, 0.5, 0.36), (0, -0.92, 0.66), -1.0, 0.6, z_from=0.0, thickness=0.06, segs=10, rings=6),
           "Head", "stone")
    for sx in (-1, 1):
        eye(b, "Head", (sx * 0.2, -1.3, 0.62), 0.075, facing=(sx * 0.3, -1.0, 0.1), segs=6)
        eye(b, "Head", (sx * 0.36, -1.14, 0.7), 0.055, facing=(sx * 0.7, -0.7, 0.2), segs=6)
        b.part(shard((sx * 0.26, -1.08, 0.86), (sx * 0.45, -0.7, 1.0), 0.62, 0.05, sides=4), "Head", "crystal")  # feeler
    b.part(blob(0.2, (0, -1.22, 0.42), scale=(1.2, 0.9, 0.6), segs=6, rings=4, seed=9), "Head", "plum")          # mouthparts
    for i, x in enumerate((-0.12, 0.0, 0.12)):
        b.part(spike((x, -1.34, 0.4), (0, -0.4, -1.0), 0.14, 0.03, verts=3), "Head", "cream")

    # ---- the mandibles: crystal tongs that close across the front
    for name, sx in (("LeftMandible", 1), ("RightMandible", -1)):
        root = sf.Vector((sx * 0.2, -1.2, 0.5))
        elbow = sf.Vector((sx * 0.46, -1.52, 0.5))
        tip = sf.Vector((sx * 0.14, -1.98, 0.46))
        b.part(limb([root, (root + elbow) / 2, elbow], [0.09, 0.08, 0.07], sides=5, resolution=1), name, "basalt")
        b.part(shard(elbow - (tip - elbow) * 0.1, tip - elbow, (tip - elbow).length * 1.15, 0.085, sides=4, tip=0.05),
               name, "crystal")
        b.part(spike(elbow + (tip - elbow) * 0.45, (-sx * 1.0, -0.2, 0.0), 0.14, 0.035, verts=3), name, "crystal")

    # ---- six legs: up to a knee above the back, down to a crystal point
    for name, sx, y in LEGS:
        splay = (-0.32 if y < -0.1 else 0.3 if y > 0.1 else 0.0)
        hip = sf.Vector((sx * 0.42, y, 0.52))
        knee = sf.Vector((sx * 1.0, y + splay * 0.6, 0.98))
        foot = sf.Vector((sx * 1.34, y + splay, 0.03))
        b.part(limb([hip, (hip + knee) / 2 + sf.Vector((0, 0, 0.06)), knee], [0.11, 0.09, 0.075], sides=5, resolution=1),
               name, "basalt")
        b.part(blob(0.1, knee, segs=5, rings=3, seed=11), name, "stone")
        mid = (knee + foot) / 2 + sf.Vector((sx * 0.1, 0, 0))
        b.part(limb([knee, mid], [0.07, 0.055], sides=5, resolution=1), name, "basalt")
        b.part(shard(mid - (foot - mid) * 0.08, foot - mid, (foot - mid).length * 1.08, 0.065, sides=4, tip=0.04),
               name, "crystal")


def gait(b, f, k):
    """A tripod skitter: legs 1 and 3 on one side move with leg 2 on the other."""
    for name, sx, y in LEGS:
        tripod = 1 if (("1" in name or "3" in name) == (sx > 0)) else -1
        swing = 24 * k * tripod
        lift = 10 * max(k * tripod, 0)
        b.key(name, f, (0, swing * sx, lift * sx))
    b.key("Body", f, (1.5 * k, 0, 2.5 * k), loc=(0, 0.03 * abs(k), 0))
    b.key("Tail", f, (-3 * abs(k), 5 * k, 0))
    b.key("Head", f, (2 * abs(k), -4 * k, 0))


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 12, loop=True, priority="Movement")
    for f, k in ((0, 1), (3, 0), (6, -1), (9, 0), (12, 1)):
        gait(b, f, k)
        b.key("LeftMandible", f, (0, -6 * abs(k), 0))
        b.key("RightMandible", f, (0, 6 * abs(k), 0))
    return act


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 60, loop=True, priority="Idle")
    for f, k in ((0, 0), (15, 1), (30, 0), (45, -1), (60, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, 0.025 * abs(k), 0))
        b.key("Tail", f, (-4 * abs(k), 3 * k, 0))
        b.key("Head", f, (3 * k, 7 * k, 0))
    for f, k in ((0, 0), (6, 1), (12, 0), (30, 0), (36, 1), (42, 0), (60, 0)):
        b.key("LeftMandible", f, (0, -14 * k, 0))
        b.key("RightMandible", f, (0, 14 * k, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 16, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 3, (-16, 0, 0), loc=(0, 0.14, -0.15))                # rears, mandibles wide
    b.key("Head", 3, (-14, 0, 0))
    b.key("LeftMandible", 3, (0, -38, 0))
    b.key("RightMandible", 3, (0, 38, 0))
    b.key("LeftLeg1", 3, (0, 0, 26))
    b.key("RightLeg1", 3, (0, 0, -26))
    b.key("Tail", 3, (-12, 0, 0))
    b.key("Body", 6, (10, 0, 0), loc=(0, 0.0, 0.42), ease="QUAD")      # drives in; the snap lands at 0.2 s
    b.key("Head", 6, (8, 0, 0), ease="QUAD")
    b.key("LeftMandible", 6, (0, 26, 0), ease="QUAD")
    b.key("RightMandible", 6, (0, -26, 0), ease="QUAD")
    b.key("LeftLeg1", 6, (0, 14, 0))
    b.key("RightLeg1", 6, (0, -14, 0))
    b.key("Tail", 7, (8, 0, 0))
    b.key("Body", 10, (3, 0, 0), loc=(0, 0, 0.15))
    b.rest(16)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("Shardling", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=3300, hrp_center=(0, 0.0, 0.62), hrp_size=(1.6, 1.0, 2.4), step="A10",
          meta={"role": "Swarmer", "band": "CrystalHollows", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -1.9, 0.5), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
