"""Monster_AshJackal: the surface's pack runner (bible Sections 12 and 27: mutated animals that
circle and dart in). A starved jackal the Ash changed: a narrow ribcage under ash-grey fur tufts,
huge ragged ears, a long snout split into a grin of pale fangs, two burning green eyes, Source
sores glowing along its flank and a bristling tail. Smaller than a Tunnel Hound; it comes in
packs (about 2,000 triangles). Scary, never gory.

Rig: Pelvis (root), Chest, Head, Jaw, Tail, four two-bone legs (the Tunnel Hound's layout,
smaller). Clips: Walk (a fast lope, looped), Attack (a darting snap, Hit at 0.35 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_AshJackal.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, eye, teeth, vein  # noqa: E402,F401

ASSET, CATEGORY = "Monster_AshJackal", "Monsters"
HIT_TIME = 0.35
S = 0.78  # the Tunnel Hound's frame, smaller
JOINTS = [
    ("Pelvis", None, (0, 1.0 * S, 1.75 * S)),
    ("Chest", "Pelvis", (0, -0.4 * S, 1.9 * S)),
    ("Head", "Chest", (0, -1.55 * S, 2.25 * S)),
    ("Jaw", "Head", (0, -1.8 * S, 2.05 * S)),
    ("Tail", "Pelvis", (0, 1.65 * S, 1.95 * S)),
    ("FrontLeftLeg", "Chest", (0.5 * S, -1.05 * S, 1.7 * S)),
    ("FrontLeftPaw", "FrontLeftLeg", (0.55 * S, -1.15 * S, 0.85 * S)),
    ("FrontRightLeg", "Chest", (-0.5 * S, -1.05 * S, 1.7 * S)),
    ("FrontRightPaw", "FrontRightLeg", (-0.55 * S, -1.15 * S, 0.85 * S)),
    ("BackLeftLeg", "Pelvis", (0.52 * S, 1.05 * S, 1.6 * S)),
    ("BackLeftPaw", "BackLeftLeg", (0.55 * S, 1.2 * S, 0.8 * S)),
    ("BackRightLeg", "Pelvis", (-0.52 * S, 1.05 * S, 1.6 * S)),
    ("BackRightPaw", "BackRightLeg", (-0.55 * S, 1.2 * S, 0.8 * S)),
]
SIDES = (("Left", 1), ("Right", -1))


def P(x, y, z):
    return (x * S, y * S, z * S)


def build(b):
    # ---- Chest: a narrow ribcage, ash fur tufts along the back
    b.part(blob(0.82 * S, P(0, -0.6, 2.0), scale=(0.62, 1.05, 0.82), segs=10, rings=7, noise=0.05, seed=3), "Chest", "ash")
    for sx in (-1, 1):
        for i, y in enumerate((-1.0, -0.7, -0.4)):
            b.part(limb([P(sx * 0.15, y, 2.55), P(sx * 0.58, y + 0.05, 2.05), P(sx * 0.5, y + 0.12, 1.5)],
                        [0.05 * S, 0.06 * S, 0.04 * S], sides=4), "Chest", "sandstone")
    for i, (y, z) in enumerate(((-1.1, 2.6), (-0.8, 2.66), (-0.5, 2.62), (-0.2, 2.5))):
        for sx in (-1, 1):
            b.part(spike(P(sx * 0.12, y, z - 0.1), (sx * 0.4, 0.8, 0.7), 0.38 * S, 0.06 * S, verts=4), "Chest", "basalt")
    b.part(limb([P(0, -0.95, 2.3), P(0, -1.3, 2.42), P(0, -1.6, 2.38)], [0.36 * S, 0.33 * S, 0.3 * S], sides=8), "Chest", "ash")
    b.glow(blob(0.16 * S, P(0.5, -0.55, 2.05), scale=(0.4, 1.3, 0.8), segs=8, rings=5), "Chest", "ChestGlow")   # sores
    b.glow(blob(0.12 * S, P(-0.48, -0.85, 1.9), scale=(0.4, 1.0, 0.8), segs=8, rings=5), "Chest", "ChestGlow")
    vein(b, "Chest", [P(0.52, -0.9, 2.1), P(0.58, -0.4, 1.95), P(0.5, -0.05, 1.8)], 0.025 * S, "ChestGlow")

    # ---- Pelvis: a tucked waist, bony haunches
    b.part(limb([P(0, -0.15, 2.0), P(0, 0.4, 1.95), P(0, 0.8, 1.98)], [0.4 * S, 0.28 * S, 0.36 * S], sides=8), "Pelvis", "ash")
    b.part(blob(0.58 * S, P(0, 1.05, 1.98), scale=(0.8, 1.1, 0.75), segs=10, rings=6, noise=0.05, seed=7), "Pelvis", "ash")
    for (y, z) in ((0.45, 2.25), (0.85, 2.35), (1.2, 2.25)):
        b.part(spike(P(0, y, z - 0.08), (0, 0.6, 0.8), 0.32 * S, 0.07 * S, verts=4), "Pelvis", "basalt")

    # ---- Head: a long split snout, huge ragged ears, burning eyes
    b.part(limb([P(0, -1.45, 2.45), P(0, -2.0, 2.4), P(0, -2.6, 2.24), P(0, -3.0, 2.12)],
                [0.38 * S, 0.32 * S, 0.22 * S, 0.12 * S], sides=8), "Head", "ash")
    for sx in (-1, 1):
        b.part(claw(P(sx * 0.24, -1.6, 2.7), (sx * 0.45, 0.35, 1.0), 1.1 * S, 0.22 * S, bend=(0, 1, 0), curl=0.25,
                    sides=4, resolution=1), "Head", "basalt")                                   # the ears
        b.glow(blob(0.11 * S, P(sx * 0.24, -2.05, 2.58), segs=8, rings=5), "Head", "HeadGlow")  # the eyes
        b.part(blob(0.16 * S, P(sx * 0.25, -2.0, 2.62), scale=(1.2, 0.8, 0.5), segs=6, rings=4, seed=11), "Head", "basalt")
        pts = [sf.Vector(P(sx * (0.18 - t * 0.1), -2.05 - t * 0.85, 2.05 - t * 0.05)) for t in (0.0, 0.3, 0.6, 0.9)]
        teeth(b, "Head", pts, (sx * 0.15, -0.1, -1.0), 0.17 * S, 0.035 * S, seed=20 + sx)
    b.glow(blob(0.15 * S, P(0, -1.9, 2.15), scale=(1.0, 1.5, 0.6), segs=8, rings=4), "Head", "HeadGlow")      # the throat

    # ---- Jaw
    b.part(limb([P(0, -1.8, 2.0), P(0, -2.4, 1.85), P(0, -2.85, 1.8)], [0.24 * S, 0.18 * S, 0.1 * S], sides=8), "Jaw", "ash")
    for sx in (-1, 1):
        pts = [sf.Vector(P(sx * (0.15 - t * 0.08), -2.1 - t * 0.6, 1.92 - t * 0.04)) for t in (0.0, 0.35, 0.7)]
        teeth(b, "Jaw", pts, (sx * 0.1, -0.1, 1.0), 0.15 * S, 0.03 * S, seed=30 + sx)

    # ---- Tail: a bristling brush
    b.part(limb([P(0, 1.6, 2.0), P(0, 2.2, 2.1), P(0, 2.75, 1.85)], [0.16 * S, 0.2 * S, 0.1 * S], sides=6), "Tail", "ash")
    for (y, z) in ((1.95, 2.25), (2.3, 2.25), (2.6, 2.05)):
        for sx in (-1, 0, 1):
            b.part(spike(P(sx * 0.1, y, z - 0.05), (sx * 0.5, 0.6, 0.7), 0.3 * S, 0.06 * S, verts=4), "Tail", "basalt")

    # ---- Legs: thin and long, pale claws
    for side, sx in SIDES:
        fl, fp = f"Front{side}Leg", f"Front{side}Paw"
        b.part(limb([P(sx * 0.52, -1.0, 2.15), P(sx * 0.58, -0.98, 1.5), P(sx * 0.55, -1.15, 0.85)],
                    [0.24 * S, 0.17 * S, 0.13 * S]), fl, "ash")
        b.part(limb([P(sx * 0.55, -1.15, 0.85), P(sx * 0.56, -1.2, 0.35), P(sx * 0.56, -1.32, 0.14)],
                    [0.13 * S, 0.1 * S, 0.12 * S]), fp, "basalt")
        for dx in (-0.1, 0.1):
            b.part(claw(P(sx * 0.56 + dx, -1.48, 0.15), (dx, -1.0, -0.2), 0.32 * S, 0.04 * S, bend=(0, 0, -1),
                        curl=0.5, sides=4), fp, "cream")
        bl, bp = f"Back{side}Leg", f"Back{side}Paw"
        b.part(blob(0.36 * S, P(sx * 0.55, 1.0, 1.6), scale=(0.6, 1.0, 1.2), segs=8, rings=5, seed=40), bl, "ash")
        b.part(limb([P(sx * 0.55, 1.05, 1.4), P(sx * 0.56, 1.15, 0.8)], [0.2 * S, 0.14 * S]), bl, "ash")
        b.part(limb([P(sx * 0.55, 1.2, 0.8), P(sx * 0.56, 1.4, 0.38), P(sx * 0.56, 1.15, 0.12)],
                    [0.13 * S, 0.1 * S, 0.11 * S]), bp, "basalt")
        for dx in (-0.1, 0.1):
            b.part(claw(P(sx * 0.56 + dx, 1.0, 0.13), (dx, -1.0, -0.2), 0.26 * S, 0.035 * S, bend=(0, 0, -1),
                        curl=0.5, sides=4), bp, "cream")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 12, loop=True, priority="Movement")
    for f, fl, fr, bl, br, spine, bob, jaw in ((0, 30, 24, -32, -26, -5, 0.0, 8), (3, 0, -8, 4, 10, 0, 0.14, 4),
                                              (6, -34, -28, 32, 28, 6, 0.04, 10), (9, -10, -2, 12, 4, 2, 0.12, 5),
                                              (12, 30, 24, -32, -26, -5, 0.0, 8)):
        b.key("FrontLeftLeg", f, (fl, 0, 0))
        b.key("FrontRightLeg", f, (fr, 0, 0))
        b.key("BackLeftLeg", f, (bl, 0, 0))
        b.key("BackRightLeg", f, (br, 0, 0))
        for paw, swing in (("FrontLeftPaw", fl), ("FrontRightPaw", fr), ("BackLeftPaw", bl), ("BackRightPaw", br)):
            b.key(paw, f, (max(0, -swing) * 0.8 + 6, 0, 0))
        b.key("Chest", f, (spine, 0, 0))
        b.key("Pelvis", f, (-spine * 0.5, 0, 0), loc=(0, bob, 0))
        b.key("Head", f, (-spine, 0, 0))
        b.key("Jaw", f, (jaw, 0, 0))
        b.key("Tail", f, (-18 - spine, 0, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 21, loop=False, priority="Action")
    b.rest(0)
    b.key("Pelvis", 6, (0, 0, 0), loc=(0, -0.16, -0.15))
    b.key("Chest", 6, (10, 0, 0))
    b.key("Head", 6, (-22, 0, 0))
    b.key("Jaw", 6, (40, 0, 0))
    b.key("Pelvis", 10, (-6, 0, 0), loc=(0, 0.04, 0.5), ease="QUAD")
    b.key("Chest", 10, (-6, 0, 0), ease="QUAD")
    b.key("Head", 10, (24, 0, 0), ease="QUAD")
    b.key("Jaw", 9, (44, 0, 0))
    b.key("Jaw", 11, (-2, 0, 0), ease="QUAD")
    for leg, ang in (("FrontLeftLeg", -30), ("FrontRightLeg", -30), ("BackLeftLeg", 25), ("BackRightLeg", 25)):
        b.key(leg, 10, (ang, 0, 0))
    b.key("Jaw", 15, (8, 0, 0))
    b.rest(21)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("AshJackal", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=2500, hrp_center=(0, 0.0, 1.8 * S), hrp_size=(1.3, 1.2, 2.8), step="A5",
          meta={"role": "PackRunner", "band": "Surface", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -2.7 * S, 1.9 * S), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
