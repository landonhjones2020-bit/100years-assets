"""Monster_TunnelHound: the Mines runner (bible Section 27: sprints past defenders to reach
residents). A lean, eyeless digging hound the Source changed: a hunched stone back with a
ridge of Source crystals, a long wedge of a head split by a glowing seam, gunmetal claws for
tunnelling, a whip of a tail. Never gory.

Rig: Pelvis (root), Chest, Head, Tail, four two-bone legs. Clips: Walk (a gallop, looped:
MonsterService calls all moving Walk), Attack (a lunging bite, Hit at 0.45 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_TunnelHound.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, rod, crystal  # noqa: E402

ASSET, CATEGORY = "Monster_TunnelHound", "Monsters"
HIT_TIME = 0.45
JOINTS = [
    ("Pelvis", None, (0, 1.0, 1.75)),
    ("Chest", "Pelvis", (0, -0.4, 1.9)),
    ("Head", "Chest", (0, -1.55, 2.2)),
    ("Tail", "Pelvis", (0, 1.65, 1.9)),
    ("FrontLeftLeg", "Chest", (0.55, -1.05, 1.7)),
    ("FrontLeftPaw", "FrontLeftLeg", (0.6, -1.15, 0.85)),
    ("FrontRightLeg", "Chest", (-0.55, -1.05, 1.7)),
    ("FrontRightPaw", "FrontRightLeg", (-0.6, -1.15, 0.85)),
    ("BackLeftLeg", "Pelvis", (0.58, 1.05, 1.6)),
    ("BackLeftPaw", "BackLeftLeg", (0.62, 1.2, 0.8)),
    ("BackRightLeg", "Pelvis", (-0.58, 1.05, 1.6)),
    ("BackRightPaw", "BackRightLeg", (-0.62, 1.2, 0.8)),
]


def build(b):
    # back half and the hunched chest
    hips = sf.box((1.25, 1.6, 0.95), loc=(0, 1.0, 1.95), bevel=0.0)
    sf.bevel(hips, 0.3, 2)
    b.part(hips, "Pelvis", "basalt")
    chest = sf.box((1.55, 1.75, 1.3), loc=(0, -0.55, 2.05), bevel=0.0)
    for v in chest.data.vertices:
        if v.co.z > 0:
            v.co.z += 0.12 if v.co.y > 0 else 0.0   # the hunch rises toward the shoulders
    sf.bevel(chest, 0.35, 2)
    b.part(chest, "Chest", "stone")
    for (y, ln, r, bone) in ((-0.9, 0.75, 0.15, "Chest"), (-0.35, 0.95, 0.18, "Chest"), (0.25, 0.7, 0.14, "Chest"),
                             (0.9, 0.55, 0.12, "Pelvis")):
        base = (0, y, 2.6 if bone == "Chest" else 2.35)
        b.glow(crystal(base, (0, 0.35, 1.0), ln, r), bone, f"{bone}Glow")
    # head: an eyeless wedge, a gunmetal jaw, a glowing seam across the face
    head = sf.box((0.85, 1.35, 0.75), loc=(0, -2.05, 2.2), bevel=0.0)
    for v in head.data.vertices:
        if v.co.y < 0:
            v.co.x *= 0.6
            v.co.z *= 0.65
    sf.bevel(head, 0.18, 2)
    b.part(head, "Head", "stone")
    b.part(sf.box((0.6, 1.0, 0.24), loc=(0, -2.05, 1.83), bevel=0.06, segments=1), "Head", "gunmetal")
    b.glow(sf.box((0.7, 0.08, 0.1), loc=(0, -2.5, 2.25), bevel=0.0), "Head", "HeadGlow")
    for sx in (-1, 1):
        b.part(sf.sphere(0.16, loc=(sx * 0.36, -1.65, 2.6), scale=(0.8, 1.2, 1.4), segs=6, rings=4), "Head", "basalt")
    # tail
    b.part(rod((0, 1.7, 1.95), (0, 2.85, 1.35), 0.18, verts=6, radius_top=0.04), "Tail", "basalt")
    # legs: upper to the paw joint, lower to the ground with a claw
    for front, y0, y1 in ((True, -1.05, -1.15), (False, 1.05, 1.2)):
        for side, sx in (("Left", 1), ("Right", -1)):
            leg = f"{'Front' if front else 'Back'}{side}Leg"
            paw = f"{'Front' if front else 'Back'}{side}Paw"
            b.part(rod((sx * 0.55, y0, 1.85), (sx * 0.6, y1, 0.85), 0.26, verts=8, radius_top=0.2), leg,
                   "stone" if front else "basalt")
            b.part(rod((sx * 0.6, y1, 0.85), (sx * 0.62, y1 - 0.12, 0.18), 0.18, verts=8), paw, "basalt")
            b.part(sf.box((0.42, 0.62, 0.2), loc=(sx * 0.62, y1 - 0.3, 0.1), bevel=0.06, segments=1), paw, "gunmetal")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 15, loop=True, priority="Movement")
    # a rotary gallop: fronts reach while backs push, then the other way
    for f, fl, fr, bl, br, spine, bob in ((0, 28, 22, -30, -24, -6, 0.0), (4, 0, -8, 4, 10, 0, 0.18),
                                         (8, -34, -28, 30, 26, 7, 0.05), (12, -10, -2, 12, 4, 2, 0.15),
                                         (15, 28, 22, -30, -24, -6, 0.0)):
        b.key("FrontLeftLeg", f, (fl, 0, 0))
        b.key("FrontRightLeg", f, (fr, 0, 0))
        b.key("BackLeftLeg", f, (bl, 0, 0))
        b.key("BackRightLeg", f, (br, 0, 0))
        for paw, swing in (("FrontLeftPaw", fl), ("FrontRightPaw", fr), ("BackLeftPaw", bl), ("BackRightPaw", br)):
            b.key(paw, f, (max(0, -swing) * 0.8 + 6, 0, 0))   # the paw folds as the leg reaches
        b.key("Chest", f, (spine, 0, 0))
        b.key("Pelvis", f, (-spine * 0.5, 0, 0), loc=(0, bob, 0))
        b.key("Head", f, (-spine, 0, 0))
        b.key("Tail", f, (-12 - spine, 0, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 27, loop=False, priority="Action")
    b.rest(0)
    b.key("Pelvis", 8, (0, 0, 0), loc=(0, -0.22, -0.2))
    b.key("Chest", 8, (12, 0, 0))
    b.key("Head", 8, (-20, 0, 0))
    b.key("Pelvis", 13, (-6, 0, 0), loc=(0, 0.05, 0.6), ease="QUAD")
    b.key("Chest", 13, (-6, 0, 0), ease="QUAD")
    b.key("Head", 13, (28, 0, 0), ease="QUAD")
    for leg, ang in (("FrontLeftLeg", -30), ("FrontRightLeg", -30), ("BackLeftLeg", 25), ("BackRightLeg", 25)):
        b.key(leg, 13, (ang, 0, 0))
    b.rest(27)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("TunnelHound", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=2500, hrp_center=(0, 0.0, 1.8), hrp_size=(1.6, 1.4, 3.6),
          meta={"role": "Runner", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -2.7, 1.9), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
