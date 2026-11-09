"""Monster_TunnelHound: the Mines runner (bible Section 27: sprints past defenders to reach
residents). A starved digging hound the Source changed: a deep chest caged in stone ribs over
a tucked waist, a ridge of Source crystals down the spine, a long skull with no eyes, only a
burning slit under a heavy brow, swept-back horns, a hinged jaw full of pale fangs and a
glowing throat, long digging claws and a whip tail tipped with a crystal. Scary, never gory.

Rig: Pelvis (root), Chest, Head, Jaw, Tail, four two-bone legs. Clips: Walk (a gallop,
looped: MonsterService calls all moving Walk), Attack (a lunging bite, Hit at 0.45 s).
Detail pass 2026-11-08 (Landon: "make the monsters more detailed").

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_TunnelHound.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, rod, crystal, spike, claw, limb, blob, eye, teeth, vein  # noqa: E402,F401

ASSET, CATEGORY = "Monster_TunnelHound", "Monsters"
HIT_TIME = 0.45
JOINTS = [
    ("Pelvis", None, (0, 1.0, 1.75)),
    ("Chest", "Pelvis", (0, -0.4, 1.9)),
    ("Head", "Chest", (0, -1.55, 2.2)),
    ("Jaw", "Head", (0, -1.8, 2.0)),
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
SIDES = (("Left", 1), ("Right", -1))


def flatten(o, sx=1.0, sy=1.0, sz=1.0):
    """Squash a finished mesh about its own origin (tubes come out round)."""
    c = sum((v.co for v in o.data.vertices), sf.Vector()) / max(1, len(o.data.vertices))
    for v in o.data.vertices:
        d = v.co - c
        v.co = c + sf.Vector((d.x * sx, d.y * sy, d.z * sz))
    return o


def build(b):
    # ---- Chest: a deep starved chest caged in raised stone ribs, hunched shoulder blades
    b.part(blob(1.0, (0, -0.62, 2.02), scale=(0.74, 1.0, 0.86), segs=12, rings=8, noise=0.035, seed=11),
           "Chest", "basalt")
    for sx in (-1, 1):
        b.part(blob(0.42, (sx * 0.42, -0.95, 2.62), scale=(0.8, 1.25, 0.55), segs=8, rings=5, noise=0.05,
                    seed=12 + sx), "Chest", "stone")
        for i, y in enumerate((-1.2, -0.88, -0.56, -0.24)):
            k = 1.0 - i * 0.07
            b.part(limb([(sx * 0.22, y, 2.8 * k + 0.2), (sx * 0.74 * k, y + 0.05, 2.25), (sx * 0.62 * k, y + 0.16, 1.5)],
                        [0.075, 0.085, 0.05], sides=4), "Chest", "sandstone")
    # the neck and a mane of stone spines down it
    b.part(limb([(0, -0.95, 2.35), (0, -1.35, 2.42), (0, -1.65, 2.35)], [0.48, 0.44, 0.4], sides=8), "Chest", "basalt")
    for i, (y, z) in enumerate(((-1.45, 2.78), (-1.2, 2.86), (-0.95, 2.95))):
        for sx in (-1, 0, 1):
            ln = 0.42 if sx == 0 else 0.3
            b.part(spike((sx * 0.16, y, z - 0.08), (sx * 0.5, 0.9, 0.6), ln, 0.075, verts=4), "Chest", "stone")
    # Source crystals along the spine, biggest over the shoulders
    for (y, z, ln, r, lean) in ((-0.62, 2.72, 1.0, 0.17, 0.3), (-0.25, 2.62, 0.78, 0.14, 0.4),
                                (0.08, 2.48, 0.55, 0.11, 0.5), (-0.9, 2.82, 0.62, 0.11, 0.1)):
        b.glow(crystal((0, y, z - 0.18), (0, lean, 1.0), ln, r), "Chest", "ChestGlow")
    for sx in (-1, 1):
        b.glow(crystal((sx * 0.3, -0.45, 2.55), (sx * 0.8, 0.35, 0.9), 0.42, 0.08), "Chest", "ChestGlow")
    vein(b, "Chest", [(0.62, -0.95, 2.05), (0.7, -0.6, 1.85), (0.6, -0.2, 1.72)], 0.03, "ChestGlow")

    # ---- Pelvis: a tucked waist into narrow haunches, a spined back
    b.part(limb([(0, -0.15, 2.05), (0, 0.35, 1.98), (0, 0.75, 1.98)], [0.5, 0.36, 0.44], sides=8), "Pelvis", "basalt")
    b.part(blob(0.72, (0, 1.05, 1.98), scale=(0.84, 1.15, 0.78), segs=12, rings=7, noise=0.04, seed=21),
           "Pelvis", "basalt")
    for (y, z, ln) in ((0.3, 2.3, 0.4), (0.62, 2.42, 0.48), (0.95, 2.48, 0.42), (1.28, 2.36, 0.32)):
        b.part(spike((0, y, z - 0.08), (0, 0.55, 0.85), ln, 0.09, verts=4), "Pelvis", "stone")
    b.glow(crystal((0.18, 0.75, 2.38), (0.4, 0.4, 0.85), 0.4, 0.08), "Pelvis", "PelvisGlow")

    # ---- Head: a long eyeless skull, a heavy brow over a burning slit, swept-back horns
    skull = limb([(0, -1.45, 2.38), (0, -1.95, 2.36), (0, -2.55, 2.24), (0, -2.98, 2.12)],
                 [0.44, 0.4, 0.3, 0.17], sides=8, name="Skull")
    b.part(flatten(skull, sx=0.92, sz=0.8), "Head", "sandstone")
    b.part(blob(0.36, (0, -1.98, 2.6), scale=(1.45, 0.9, 0.45), segs=10, rings=5, noise=0.06, seed=31), "Head", "stone")
    for sx in (-1, 1):
        slit = sf.box((0.4, 0.14, 0.1), loc=(sx * 0.25, -2.16, 2.45), rot=(0, sx * 18, sx * -8), bevel=0.0)
        b.glow(slit, "Head", "HeadGlow")
        b.part(blob(0.2, (sx * 0.34, -1.9, 2.3), scale=(0.7, 1.4, 0.8), segs=8, rings=5, seed=33), "Head", "sandstone")
        b.part(claw((sx * 0.26, -1.62, 2.62), (sx * 0.35, 1.0, 0.45), 1.05, 0.12, bend=(0, 0.2, -1), curl=0.4,
                    sides=6, resolution=2), "Head", "basalt")
        b.part(claw((sx * 0.36, -1.72, 2.45), (sx * 0.7, 1.0, 0.1), 0.55, 0.07, bend=(0, 0, -1), curl=0.3,
                    sides=4), "Head", "basalt")
    # upper fangs, two long canines in front
    for sx in (-1, 1):
        pts = [sf.Vector((sx * (0.26 - t * 0.12), -1.95 - t * 0.95, 2.04 - t * 0.08)) for t in (0.0, 0.2, 0.4, 0.6, 0.8)]
        teeth(b, "Head", pts, (sx * 0.15, -0.15, -1.0), 0.2, 0.045, seed=40 + sx)
        b.part(claw((sx * 0.14, -2.86, 2.02), (0, -0.25, -1.0), 0.42, 0.06, bend=(0, 1, 0), curl=0.25, sides=4),
               "Head", "cream")
    b.glow(blob(0.2, (0, -1.85, 2.12), scale=(1.0, 1.4, 0.7), segs=8, rings=5), "Head", "HeadGlow")   # the throat

    # ---- Jaw: hinged, a little open even at rest, with its own fangs and a glowing tongue
    jaw = limb([(0, -1.78, 1.98), (0, -2.35, 1.8), (0, -2.82, 1.74)], [0.3, 0.24, 0.13], sides=8, name="JawBone")
    b.part(flatten(jaw, sx=1.0, sz=0.62), "Jaw", "sandstone")
    for sx in (-1, 1):
        pts = [sf.Vector((sx * (0.2 - t * 0.1), -2.05 - t * 0.7, 1.86 - t * 0.05)) for t in (0.0, 0.3, 0.6, 0.9)]
        teeth(b, "Jaw", pts, (sx * 0.12, -0.1, 1.0), 0.18, 0.04, seed=50 + sx)
        b.part(spike((sx * 0.1, -2.72, 1.8), (0, -0.2, 1.0), 0.3, 0.05, verts=4), "Jaw", "cream")
    b.glow(blob(0.16, (0, -2.25, 1.9), scale=(0.9, 2.6, 0.32), segs=8, rings=4), "Jaw", "JawGlow")

    # ---- Tail: a whip of stone plates tipped with a crystal
    tail_pts = [(0, 1.6, 1.98), (0, 2.25, 2.02), (0, 2.85, 1.72), (0, 3.3, 1.18)]
    b.part(limb(tail_pts, [0.2, 0.15, 0.09, 0.05], sides=6), "Tail", "basalt")
    for (y, z, ln) in ((2.0, 2.2, 0.26), (2.42, 2.12, 0.22), (2.8, 1.9, 0.18), (3.1, 1.55, 0.15)):
        b.part(spike((0, y, z - 0.05), (0, 0.6, 0.8), ln, 0.06, verts=4), "Tail", "stone")
    b.glow(crystal((0, 3.28, 1.2), (0, 0.55, -0.75), 0.45, 0.09), "Tail", "TailGlow")

    # ---- Legs: corded front legs with elbow spurs, digitigrade hind legs, long pale claws
    for side, sx in SIDES:
        fl, fp = f"Front{side}Leg", f"Front{side}Paw"
        b.part(limb([(sx * 0.58, -1.0, 2.2), (sx * 0.66, -0.98, 1.5), (sx * 0.6, -1.15, 0.85)], [0.33, 0.26, 0.19]),
               fl, "basalt")
        b.part(blob(0.26, (sx * 0.7, -0.98, 1.72), scale=(0.7, 1.0, 1.35), segs=8, rings=5, seed=60), fl, "stone")
        b.part(claw((sx * 0.64, -0.88, 1.08), (0, 1.0, 0.35), 0.42, 0.07, bend=(0, 0, 1), curl=0.3, sides=4), fl, "cream")
        b.part(limb([(sx * 0.6, -1.15, 0.85), (sx * 0.62, -1.2, 0.35), (sx * 0.62, -1.3, 0.14)], [0.19, 0.15, 0.16]),
               fp, "basalt")
        b.part(blob(0.24, (sx * 0.62, -1.38, 0.12), scale=(1.15, 1.35, 0.55), segs=8, rings=4, seed=61), fp, "stone")
        for dx in (-0.14, 0.0, 0.14):
            b.part(claw((sx * 0.62 + dx, -1.55, 0.16), (dx * 0.6, -1.0, -0.15), 0.42, 0.055, bend=(0, 0, -1),
                        curl=0.55, sides=4), fp, "cream")
        bl, bp = f"Back{side}Leg", f"Back{side}Paw"
        b.part(blob(0.46, (sx * 0.6, 1.0, 1.6), scale=(0.62, 1.0, 1.25), segs=10, rings=6, noise=0.04, seed=70), bl, "basalt")
        b.part(limb([(sx * 0.6, 1.05, 1.4), (sx * 0.62, 1.15, 0.8)], [0.27, 0.2]), bl, "basalt")
        b.part(spike((sx * 0.62, 1.2, 1.9), (sx * 0.3, 0.7, 0.6), 0.3, 0.07, verts=4), bl, "stone")
        b.part(limb([(sx * 0.62, 1.2, 0.8), (sx * 0.62, 1.42, 0.38), (sx * 0.62, 1.15, 0.12)], [0.19, 0.14, 0.15]),
               bp, "basalt")
        b.part(blob(0.22, (sx * 0.62, 1.0, 0.1), scale=(1.1, 1.35, 0.55), segs=8, rings=4, seed=71), bp, "stone")
        for dx in (-0.12, 0.0, 0.12):
            b.part(claw((sx * 0.62 + dx, 0.82, 0.13), (dx * 0.6, -1.0, -0.15), 0.32, 0.05, bend=(0, 0, -1),
                        curl=0.5, sides=4), bp, "cream")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 15, loop=True, priority="Movement")
    # a rotary gallop: fronts reach while backs push, then the other way; the jaw hangs and snaps
    for f, fl, fr, bl, br, spine, bob, jaw in ((0, 28, 22, -30, -24, -6, 0.0, 10), (4, 0, -8, 4, 10, 0, 0.18, 4),
                                              (8, -34, -28, 30, 26, 7, 0.05, 12), (12, -10, -2, 12, 4, 2, 0.15, 5),
                                              (15, 28, 22, -30, -24, -6, 0.0, 10)):
        b.key("FrontLeftLeg", f, (fl, 0, 0))
        b.key("FrontRightLeg", f, (fr, 0, 0))
        b.key("BackLeftLeg", f, (bl, 0, 0))
        b.key("BackRightLeg", f, (br, 0, 0))
        for paw, swing in (("FrontLeftPaw", fl), ("FrontRightPaw", fr), ("BackLeftPaw", bl), ("BackRightPaw", br)):
            b.key(paw, f, (max(0, -swing) * 0.8 + 6, 0, 0))   # the paw folds as the leg reaches
        b.key("Chest", f, (spine, 0, 0))
        b.key("Pelvis", f, (-spine * 0.5, 0, 0), loc=(0, bob, 0))
        b.key("Head", f, (-spine, 0, 0))
        b.key("Jaw", f, (jaw, 0, 0))
        b.key("Tail", f, (-12 - spine, 0, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 27, loop=False, priority="Action")
    b.rest(0)
    b.key("Pelvis", 8, (0, 0, 0), loc=(0, -0.22, -0.2))
    b.key("Chest", 8, (12, 0, 0))
    b.key("Head", 8, (-26, 0, 0))
    b.key("Jaw", 8, (42, 0, 0))                       # the jaw drops wide on the windup
    b.key("Pelvis", 13, (-6, 0, 0), loc=(0, 0.05, 0.6), ease="QUAD")
    b.key("Chest", 13, (-6, 0, 0), ease="QUAD")
    b.key("Head", 13, (28, 0, 0), ease="QUAD")
    b.key("Jaw", 12, (46, 0, 0))
    b.key("Jaw", 14, (-2, 0, 0), ease="QUAD")        # and snaps shut on the hit
    for leg, ang in (("FrontLeftLeg", -30), ("FrontRightLeg", -30), ("BackLeftLeg", 25), ("BackRightLeg", 25)):
        b.key(leg, 13, (ang, 0, 0))
    b.key("Jaw", 20, (8, 0, 0))
    b.rest(27)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("TunnelHound", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=3500, hrp_center=(0, 0.0, 1.8), hrp_size=(1.6, 1.4, 3.6),
          meta={"role": "Runner", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Bite": ((0, -2.7, 1.9), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
