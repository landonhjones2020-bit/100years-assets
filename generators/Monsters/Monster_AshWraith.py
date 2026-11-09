"""Monster_AshWraith: the storm's stalker (bible Sections 12 and 27: appears only in storms; each
hit adds radiation). A hunched shape of blown ash taller than a resident: a deep hood with two
burning green eyes and a glowing maw, long arms ending in pale hooked claws, a radiation core
throbbing green in its open chest, its body trailing away into tattered wisps instead of legs. It
floats a hand's width over the ground. Scary, never gory.

Rig: Pelvis (root), Chest, Head, Jaw, LeftArm, LeftHand, RightArm, RightHand, Tail (the trailing
wisps). Clips: Walk (a drifting glide, looped), Attack (rears and rakes with both hands, Hit 0.55 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_AshWraith.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, eye, teeth, vein  # noqa: E402,F401

ASSET, CATEGORY = "Monster_AshWraith", "Monsters"
HIT_TIME = 0.55
JOINTS = [
    ("Pelvis", None, (0, 0.2, 2.6)),
    ("Chest", "Pelvis", (0, 0.1, 3.6)),
    ("Head", "Chest", (0, -0.7, 6.2)),
    ("Jaw", "Head", (0, -1.1, 5.9)),
    ("LeftArm", "Chest", (1.25, -0.2, 5.6)),
    ("LeftHand", "LeftArm", (1.9, -1.0, 3.4)),
    ("RightArm", "Chest", (-1.25, -0.2, 5.6)),
    ("RightHand", "RightArm", (-1.9, -1.0, 3.4)),
    ("Tail", "Pelvis", (0, 0.4, 2.2)),
]


def build(b):
    # ---- Chest: a hunched torso of packed ash, ribs of cinder, the radiation core in an open chest
    b.part(blob(1.15, (0, 0.0, 4.4), scale=(1.0, 0.85, 1.25), segs=12, rings=8, noise=0.08, seed=5), "Chest", "basalt")
    b.part(blob(0.95, (0, 0.45, 5.4), scale=(1.15, 0.8, 0.7), segs=10, rings=6, noise=0.08, seed=6), "Chest", "ash")
    for sx in (-1, 1):
        for i, z in enumerate((3.8, 4.3, 4.8)):
            b.part(limb([(sx * 0.25, -0.9, z + 0.1), (sx * 0.85, -0.6, z), (sx * 1.0, 0.0, z - 0.15)],
                        [0.07, 0.08, 0.05], sides=4), "Chest", "stone")
    b.glow(blob(0.42, (0, -0.72, 4.35), segs=10, rings=6), "Chest", "CoreGlow")                 # the core
    vein(b, "Chest", [(0, -0.75, 4.3), (0.5, -0.6, 4.9), (0.9, -0.3, 5.4)], 0.04, "CoreGlow")
    vein(b, "Chest", [(0, -0.75, 4.3), (-0.55, -0.6, 3.8), (-0.8, -0.3, 3.3)], 0.04, "CoreGlow")
    for (x, z, ln) in ((0.6, 5.9, 0.8), (-0.5, 6.0, 0.7), (0.0, 6.1, 0.9), (0.9, 5.4, 0.6), (-0.9, 5.5, 0.6)):
        b.part(spike((x, 0.5, z - 0.2), (x * 0.4, 0.8, 0.6), ln, 0.12, verts=4), "Chest", "basalt")   # tatters
    # a ragged mantle off the shoulders: long tatters hanging down its back
    for i, x in enumerate((-1.3, -0.8, -0.25, 0.3, 0.85, 1.35)):
        b.part(spike((x, 0.75, 5.7 - abs(x) * 0.3), (x * 0.15, 0.35, -1.0), 2.4 + (i % 3) * 0.5, 0.32, verts=4),
               "Chest", "ash" if i % 2 else "basalt")

    # ---- Head: a deep cowl hanging over a dark hollow, two burning slits, a glowing maw
    b.part(blob(1.05, (0, -0.4, 6.6), scale=(1.05, 1.15, 1.15), segs=12, rings=8, noise=0.07, seed=9), "Head", "ash")
    b.part(limb([(0, -0.6, 7.55), (0, -1.45, 7.25), (0, -1.75, 6.75)], [0.55, 0.42, 0.16], sides=6), "Head", "ash")  # the brim
    b.part(blob(0.78, (0, -1.0, 6.4), scale=(0.85, 0.6, 0.95), segs=10, rings=6, seed=10), "Head", "basalt")   # the hollow
    b.part(spike((0, 0.1, 7.3), (0, 1.0, 0.25), 1.5, 0.3, verts=5), "Head", "ash")              # the cowl's tail
    for sx in (-1, 1):
        slit = sf.box((0.42, 0.12, 0.11), loc=(sx * 0.27, -1.5, 6.62), rot=(0, sx * 16, sx * -10), bevel=0.0)
        b.glow(slit, "Head", "HeadGlow")
    b.glow(blob(0.2, (0, -1.38, 6.15), scale=(1.4, 0.5, 0.8), segs=8, rings=5), "Head", "HeadGlow")      # the maw
    pts = [sf.Vector((x, -1.42, 6.32)) for x in (-0.24, -0.08, 0.08, 0.24)]
    teeth(b, "Head", pts, (0, -0.2, -1.0), 0.16, 0.035, seed=4)
    b.part(blob(0.3, (0, -1.25, 5.92), scale=(1.2, 0.8, 0.5), segs=8, rings=5, seed=12), "Jaw", "basalt")
    pts = [sf.Vector((x, -1.45, 6.0)) for x in (-0.2, 0.0, 0.2)]
    teeth(b, "Jaw", pts, (0, -0.2, 1.0), 0.14, 0.03, seed=5)

    # ---- Arms: long and thin, pale hooked claws
    for side, sx in (("Left", 1), ("Right", -1)):
        b.part(limb([(sx * 1.2, -0.15, 5.65), (sx * 1.65, -0.55, 4.6), (sx * 1.9, -1.0, 3.45)], [0.26, 0.2, 0.15]),
               f"{side}Arm", "ash")
        b.part(blob(0.32, (sx * 1.15, 0.0, 5.75), scale=(1.1, 0.9, 0.7), segs=8, rings=5, seed=14), f"{side}Arm", "basalt")
        b.part(limb([(sx * 1.9, -1.0, 3.4), (sx * 2.0, -1.25, 2.7)], [0.15, 0.13]), f"{side}Hand", "basalt")
        for i, dx in enumerate((-0.18, 0.0, 0.18)):
            b.part(claw((sx * 2.0 + dx, -1.3, 2.7), (dx, -0.4, -1.0), 0.75, 0.06, bend=(0, -1, 0), curl=0.5, sides=4),
                   f"{side}Hand", "cream")

    # ---- Pelvis and Tail: the body thins into wisps that trail behind and below
    b.part(blob(0.85, (0, 0.2, 3.0), scale=(0.9, 0.9, 0.9), segs=10, rings=7, noise=0.1, seed=16), "Pelvis", "ash")
    for i, a in enumerate(range(0, 360, 60)):
        r = math.radians(a)
        b.part(spike((0.45 * math.cos(r), 0.3 + 0.45 * math.sin(r), 2.4), (0.3 * math.cos(r), 0.5, -1.0),
                     1.6 + (i % 3) * 0.4, 0.22, verts=4), "Tail", "basalt" if i % 2 else "ash")
    b.part(limb([(0, 0.35, 2.4), (0, 1.0, 1.4), (0, 1.9, 0.75)], [0.5, 0.32, 0.08], sides=6), "Tail", "ash")
    b.glow(blob(0.12, (0.4, 0.6, 2.2), segs=6, rings=4), "Tail", "TailGlow")                     # embers in the ash


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, s in ((0, 1), (15, -1), (30, 1)):
        b.key("Pelvis", f, (0, 0, 0), loc=(0, 0.25 if s > 0 else 0.05, 0))      # bobbing as it drifts
        b.key("Chest", f, (12, 4 * s, 0))
        b.key("Head", f, (-8, -6 * s, 0))
        b.key("LeftArm", f, (25 + 8 * s, 0, 10))                                 # arms trailing back
        b.key("RightArm", f, (25 - 8 * s, 0, -10))
        b.key("LeftHand", f, (10, 0, 0))
        b.key("RightHand", f, (10, 0, 0))
        b.key("Tail", f, (20 + 10 * s, 6 * s, 0))
        b.key("Jaw", f, (6, 0, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 30, loop=False, priority="Action")
    b.rest(0)
    b.key("Chest", 10, (-18, 0, 0))                                               # rears back
    b.key("Head", 10, (-12, 0, 0))
    b.key("Jaw", 10, (30, 0, 0))                                                  # the maw opens
    b.key("LeftArm", 10, (-110, 0, 25))
    b.key("RightArm", 10, (-110, 0, -25))
    b.key("Pelvis", 10, (0, 0, 0), loc=(0, 0.4, 0.2))
    b.key("Chest", 16, (30, 0, 0), ease="QUAD")                                   # and rakes down
    b.key("Head", 16, (16, 0, 0), ease="QUAD")
    b.key("LeftArm", 16, (40, 0, 5), ease="QUAD")
    b.key("RightArm", 16, (40, 0, -5), ease="QUAD")
    b.key("Pelvis", 16, (0, 0, 0), loc=(0, -0.1, -0.6), ease="QUAD")
    b.key("Jaw", 16, (8, 0, 0))
    b.rest(30)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("AshWraith", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.1, 3.0), hrp_size=(2.0, 2.0, 1.6), step="A5",
          meta={"role": "Stalker", "band": "Surface", "hitTime": HIT_TIME},
          sockets={"Rake": ((0, -1.6, 3.0), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
