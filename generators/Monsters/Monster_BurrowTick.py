"""Monster_BurrowTick: the Mines swarmer (bible Section 27: fast and weak, comes in packs,
latches onto residents). A fist-sized-to-a-dog tick the Source warped: a squat basalt
carapace with a stone rim, six jointed legs, small mandibles, two green eyes and Source
crystals growing out of its back. Never gory.

Rig: Body (root), Head, six one-bone legs. Clips: Walk (a quick tripod scuttle, looped),
Attack (a lunge bite, Hit at 0.3 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_BurrowTick.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, rod, crystal  # noqa: E402

ASSET, CATEGORY = "Monster_BurrowTick", "Monsters"
HIT_TIME = 0.3
LEG_Y = (-0.55, 0.05, 0.62)          # front, middle, back
JOINTS = [("Body", None, (0, 0.1, 0.72)), ("Head", "Body", (0, -0.95, 0.72))]
for i, y in enumerate(LEG_Y, 1):
    JOINTS.append((f"LeftLeg{i}", "Body", (0.72, y, 0.7)))
    JOINTS.append((f"RightLeg{i}", "Body", (-0.72, y, 0.7)))


def build(b):
    # carapace: a low dome over a stone rim and underbelly
    b.part(sf.sphere(1.0, loc=(0, 0.12, 0.82), scale=(0.95, 1.22, 0.52), segs=14, rings=7), "Body", "basalt")
    b.part(sf.sphere(0.98, loc=(0, 0.1, 0.66), scale=(0.98, 1.2, 0.3), segs=14, rings=5), "Body", "stone")
    for (x, y, z, rx) in ((0.0, -0.2, 1.22, -20), (0.32, 0.35, 1.12, 25), (-0.3, 0.4, 1.1, 30)):
        b.glow(crystal((x, y, z - 0.12), (x * 0.6, 0.25 + y * 0.2, 1.0), 0.55, 0.13), "Body", "BodyGlow")
    # head: a small stone knob with gunmetal mandibles and green eyes
    b.part(sf.sphere(0.42, loc=(0, -1.12, 0.7), scale=(1.1, 0.9, 0.75), segs=10, rings=6), "Head", "stone")
    for sx in (-1, 1):
        b.part(rod((sx * 0.18, -1.38, 0.58), (sx * 0.06, -1.72, 0.5), 0.07, verts=6, radius_top=0.02), "Head", "gunmetal")
        b.glow(sf.sphere(0.09, loc=(sx * 0.2, -1.42, 0.82), segs=8, rings=4), "Head", "HeadGlow")
    # legs: out and up to a knee, then down to the ground
    for i, y in enumerate(LEG_Y, 1):
        for side, sx in (("Left", 1), ("Right", -1)):
            spread = (i - 2) * 0.28   # front legs reach forward, back legs back
            knee = (sx * 1.32, y + spread * 0.6, 1.05)
            foot = (sx * 1.62, y + spread, 0.0)
            bone = f"{side}Leg{i}"
            b.part(rod((sx * 0.7, y, 0.7), knee, 0.09, verts=6), bone, "gunmetal")
            b.part(rod(knee, foot, 0.08, verts=6, radius_top=0.03), bone, "basalt")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 12, loop=True, priority="Movement")
    a = {"LeftLeg1", "RightLeg2", "LeftLeg3"}   # tripod A; the rest is tripod B

    def legs(frame, a_fwd, lift_a, lift_b):
        for i in (1, 2, 3):
            for side, sx in (("Left", 1), ("Right", -1)):
                bone = f"{side}Leg{i}"
                group_a = bone in a
                fwd = a_fwd if group_a else -a_fwd
                lift = lift_a if group_a else lift_b
                # forward: -Y on the left, +Y on the right; lift: +Z on the left, -Z on the right
                b.key(bone, frame, (0, -fwd * sx, lift * sx))
    legs(0, 22, 0, 0)
    legs(3, 0, 0, 16)
    legs(6, -22, 0, 0)
    legs(9, 0, 16, 0)
    legs(12, 22, 0, 0)
    for f, z, r in ((0, 0.0, 0), (3, 0.05, 3), (6, 0.0, 0), (9, 0.05, -3), (12, 0.0, 0)):
        b.key("Body", f, (0, 0, r), loc=(0, z, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 18, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 5, (-16, 0, 0), loc=(0, 0.12, -0.15))
    b.key("Head", 5, (-22, 0, 0))
    b.key("Body", 9, (18, 0, 0), loc=(0, -0.05, 0.45), ease="QUAD")
    b.key("Head", 9, (26, 0, 0), ease="QUAD")
    for i in (1, 2, 3):
        b.key(f"LeftLeg{i}", 9, (0, -10, 8))
        b.key(f"RightLeg{i}", 9, (0, 10, -8))
    b.rest(18)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("BurrowTick", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=1500, hrp_center=(0, 0.1, 0.75), hrp_size=(1.8, 1.0, 2.4),
          meta={"role": "Swarmer", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -1.6, 0.55), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
