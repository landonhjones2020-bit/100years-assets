"""Monster_BurrowTick: the Mines swarmer (bible Section 27: fast and weak, comes in packs,
latches onto residents). A dog-sized tick the Source warped: a banded wet-black shield over
an abdomen swollen with Source light that leaks through the seams, stone spines, four
burning eyes, two hooked pale fangs, twitching palps and six spiny legs ending in hooks.
Scary, never gory (detail pass 2026-11-08).

Rig: Body (root), Head, six one-bone legs. Clips: Walk (a quick tripod scuttle, looped),
Attack (a lunge bite, Hit at 0.3 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_BurrowTick.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, rod, crystal, spike, claw, limb, blob, shell, eye  # noqa: E402,F401

ASSET, CATEGORY = "Monster_BurrowTick", "Monsters"
HIT_TIME = 0.3
LEG_Y = (-0.55, 0.05, 0.62)          # front, middle, back
JOINTS = [("Body", None, (0, 0.1, 0.72)), ("Head", "Body", (0, -0.95, 0.72))]
for i, y in enumerate(LEG_Y, 1):
    JOINTS.append((f"LeftLeg{i}", "Body", (0.72, y, 0.7)))
    JOINTS.append((f"RightLeg{i}", "Body", (-0.72, y, 0.7)))


def build(b):
    # ---- Body: a hard tick shield over a Source-swollen abdomen that leaks light at the seams
    b.part(blob(0.98, (0, 0.12, 0.66), scale=(0.98, 1.22, 0.3), segs=10, rings=4, seed=5), "Body", "plum")   # belly
    b.glow(blob(0.8, (0, 0.42, 0.9), scale=(0.92, 0.78, 0.6), segs=10, rings=6, seed=6), "Body", "BodyGlow")
    bands = (((1.02, 1.3, 0.62), -1.0, -0.02, "basalt"), ((1.05, 1.34, 0.64), 0.06, 0.36, "murk"),
             ((1.0, 1.3, 0.6), 0.44, 0.78, "murk"))
    for radii, y0, y1, sw in bands:
        b.part(shell(radii, (0, 0.12, 0.72), y0, y1, z_from=0.05, thickness=0.08, segs=12, rings=8), "Body", sw)
    # a stone rim and spines along the ridges
    b.part(flat_ring(1.0, 1.26, 0.07, (0, 0.12, 0.74)), "Body", "stone")
    for (x, y, z, ln) in ((0.0, -0.55, 1.22, 0.42), (0.45, -0.35, 1.14, 0.36), (-0.45, -0.35, 1.14, 0.36),
                          (0.66, 0.1, 1.06, 0.34), (-0.66, 0.1, 1.06, 0.34), (0.0, -0.1, 1.32, 0.46)):
        b.part(spike((x, y, z - 0.08), (x * 0.9, 0.35, 1.0), ln, 0.085, verts=4), "Body", "stone")
    for (x, y, z, ln) in ((0.0, 0.5, 1.22, 0.6), (0.38, 0.72, 1.06, 0.45), (-0.38, 0.72, 1.06, 0.45)):
        b.glow(crystal((x, y, z - 0.12), (x * 0.8, 0.45, 1.0), ln, 0.12), "Body", "BodyGlow")

    # ---- Head: an armoured knob, four eyes, two hooked pale fangs and twitching palps
    b.part(blob(0.4, (0, -1.1, 0.7), scale=(1.15, 0.95, 0.72), segs=8, rings=5, noise=0.05, seed=8), "Head", "basalt")
    b.part(shell((0.48, 0.42, 0.34), (0, -1.08, 0.74), -1.0, 0.6, z_from=0.0, thickness=0.06, segs=10, rings=6),
           "Head", "murk")
    for sx in (-1, 1):
        eye(b, "Head", (sx * 0.17, -1.42, 0.86), 0.075, facing=(sx * 0.3, -1, 0.3), segs=6)
        eye(b, "Head", (sx * 0.32, -1.3, 0.92), 0.05, facing=(sx * 0.8, -0.6, 0.3), segs=6)
        b.part(claw((sx * 0.14, -1.42, 0.6), (sx * 0.15, -1.0, -0.25), 0.5, 0.075, bend=(-sx, 0, 0), curl=0.45,
                    sides=4), "Head", "cream")
        b.part(limb([(sx * 0.3, -1.3, 0.62), (sx * 0.45, -1.55, 0.5), (sx * 0.4, -1.72, 0.3)], [0.06, 0.045, 0.03],
                    sides=4), "Head", "basalt")

    # ---- Legs: up to a spiny knee, down to a hooked foot
    for i, y in enumerate(LEG_Y, 1):
        for side, sx in (("Left", 1), ("Right", -1)):
            spread = (i - 2) * 0.28   # front legs reach forward, back legs back
            hip = (sx * 0.72, y, 0.7)
            knee = (sx * 1.32, y + spread * 0.6, 1.12)
            foot = (sx * 1.66, y + spread, 0.06)
            bone = f"{side}Leg{i}"
            b.part(limb([hip, ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, 1.02), knee], [0.13, 0.11, 0.09],
                        sides=4), bone, "basalt")
            b.part(limb([knee, (sx * 1.55, y + spread * 0.85, 0.6), foot], [0.08, 0.06, 0.03], sides=4), bone, "murk")
            b.part(spike(knee, (sx * 0.5, spread * 0.4, 1.0), 0.3, 0.06, verts=4), bone, "stone")
            b.part(spike((sx * 1.48, y + spread * 0.8, 0.72), (sx * 1.0, 0, 0.3), 0.14, 0.03, verts=3), bone, "stone")
            b.part(claw(foot, (sx * 0.3, -0.2 + spread * 0.3, -0.2), 0.16, 0.035, bend=(-sx, 0, -1), curl=0.4,
                        sides=4), bone, "cream")


def flat_ring(r_in, r_out_y, thickness, loc):
    """An oval stone rim under the shield (x radius r_in, y radius r_out_y)."""
    o = sf.ring(r_in * 0.86, r_in, thickness, loc=loc, verts=14)
    for v in o.data.vertices:
        v.co.y *= r_out_y / r_in
    return o


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
          budget=2100, hrp_center=(0, 0.1, 0.75), hrp_size=(1.8, 1.0, 2.4),
          meta={"role": "Swarmer", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -1.6, 0.55), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
