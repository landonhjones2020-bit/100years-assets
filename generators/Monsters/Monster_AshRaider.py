"""Monster_AshRaider: a raider of the Ash (bible Sections 10, 12 and 27: melee or rifles; collapses
and fades when beaten; raids the Blast Door from Era II). A scavenger in a long dust coat and a
gas mask with round orange lenses, scrap-metal shoulder plates and a rusty bolt-action rifle with a
bayonet. Human, so no Source glow: menace comes from the mask, the plates and the silhouette.

Rig: Pelvis (root), Torso, Head, two-bone arms and legs (the Hollow Miner's layout at human size);
the rifle rides on RightLowerArm. Clips: Walk (a wary prowl, looped), Attack (shoulders the rifle
and fires, Hit 0.45 s: when MonsterService checks the shot).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_AshRaider.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, rod  # noqa: E402,F401

ASSET, CATEGORY = "Monster_AshRaider", "Monsters"
HIT_TIME = 0.45
JOINTS = [
    ("Pelvis", None, (0, 0.0, 2.6)),
    ("Torso", "Pelvis", (0, 0.0, 3.0)),
    ("Head", "Torso", (0, -0.1, 4.75)),
    ("LeftUpperArm", "Torso", (0.95, 0.0, 4.5)),
    ("LeftLowerArm", "LeftUpperArm", (1.1, -0.1, 3.4)),
    ("RightUpperArm", "Torso", (-0.95, 0.0, 4.5)),
    ("RightLowerArm", "RightUpperArm", (-1.1, -0.1, 3.4)),
    ("LeftUpperLeg", "Pelvis", (0.45, 0.0, 2.5)),
    ("LeftLowerLeg", "LeftUpperLeg", (0.47, -0.05, 1.3)),
    ("RightUpperLeg", "Pelvis", (-0.45, 0.0, 2.5)),
    ("RightLowerLeg", "RightUpperLeg", (-0.47, -0.05, 1.3)),
]


def build(b):
    # ---- Torso: a long dust coat, a bandolier, scrap plates on the shoulders
    b.part(sf.box((1.7, 1.0, 1.9), loc=(0, 0.0, 3.85), bevel=0.25, segments=1), "Torso", "leather")
    b.part(sf.box((1.5, 0.12, 1.6), loc=(0, -0.52, 3.9), bevel=0.05, segments=1), "Torso", "sandstone")      # the coat's front
    b.part(sf.box((0.25, 1.1, 2.2), loc=(0.3, 0.0, 3.85), rot=(0, 30, 0), bevel=0.0), "Torso", "walnut")      # bandolier
    for i in range(4):
        b.part(sf.box((0.18, 0.2, 0.3), loc=(0.42 - i * 0.18, -0.55, 4.4 - i * 0.3), rot=(0, 30, 0), bevel=0.0), "Torso", "brass")
    for sx in (-1, 1):
        b.part(sf.box((0.8, 1.1, 0.25), loc=(sx * 0.95, 0.0, 4.75), rot=(0, sx * -20, 0), bevel=0.06, segments=1),
               "Torso", "rust")                                                                            # shoulder plates
        b.part(spike((sx * 1.15, 0.0, 4.85), (sx * 0.6, 0.0, 1.0), 0.5, 0.12, verts=4), "Torso", "steel")
    b.part(sf.box((1.3, 0.6, 0.9), loc=(0, 0.75, 4.2), bevel=0.15, segments=1), "Torso", "olive")             # a pack
    # the coat's skirt hanging from the waist
    b.part(sf.box((1.8, 1.1, 1.4), loc=(0, 0.05, 2.45), bevel=0.15, segments=1), "Pelvis", "leather")
    b.part(sf.box((1.75, 0.4, 0.3), loc=(0, 0.0, 3.0), bevel=0.0), "Pelvis", "walnut")                        # the belt

    # ---- Head: a hood, a gas mask with round orange lenses and a filter snout
    b.part(blob(0.62, (0, 0.05, 5.35), scale=(1.0, 1.05, 1.1), segs=10, rings=7, seed=3), "Head", "olive")
    b.part(blob(0.5, (0, -0.32, 5.25), scale=(0.95, 0.7, 0.95), segs=10, rings=6, seed=4), "Head", "gunmetal")
    for sx in (-1, 1):
        b.part(sf.cyl(0.2, 0.12, loc=(sx * 0.22, -0.72, 5.42), rot=(90, 0, 0), verts=10, bevel=0.0), "Head", "chrome")
        lens = sf.cyl(0.15, 0.1, loc=(sx * 0.22, -0.79, 5.42), rot=(90, 0, 0), verts=10, bevel=0.0)
        sf.tag(lens, "Lenses", "signal", "Neon", collision="none", cast_shadow=False)     # orange lenses, not Source green
        lens["sf_bone"] = "Head"
        sf.bind(lens, b.arm, "Head")
    b.part(sf.cyl(0.24, 0.45, loc=(0, -0.85, 5.0), rot=(70, 0, 0), verts=8, bevel=0.0), "Head", "steel")    # the filter
    b.part(sf.cyl(0.26, 0.08, loc=(0, -1.06, 4.93), rot=(70, 0, 0), verts=8, bevel=0.0), "Head", "hazard")

    # ---- Arms: coat sleeves, gloves
    for side, sx in (("Left", 1), ("Right", -1)):
        b.part(limb([(sx * 0.95, 0.0, 4.55), (sx * 1.05, -0.05, 3.95), (sx * 1.1, -0.1, 3.4)], [0.3, 0.27, 0.24]),
               f"{side}UpperArm", "leather")
        b.part(limb([(sx * 1.1, -0.1, 3.4), (sx * 1.12, -0.15, 2.75), (sx * 1.12, -0.2, 2.35)], [0.24, 0.2, 0.19]),
               f"{side}LowerArm", "leather")
        b.part(blob(0.22, (sx * 1.12, -0.22, 2.2), scale=(0.9, 1.0, 1.1), segs=8, rings=5, seed=8), f"{side}LowerArm", "rubber")
    # ---- the rifle on the right forearm: stock, receiver, barrel, bayonet
    b.part(sf.box((0.22, 1.1, 0.38), loc=(-1.12, 0.25, 2.3), bevel=0.06, segments=1), "RightLowerArm", "walnut")
    b.part(sf.box((0.2, 1.4, 0.26), loc=(-1.12, -0.95, 2.3), bevel=0.04, segments=1), "RightLowerArm", "gunmetal")
    b.part(rod((-1.12, -1.6, 2.36), (-1.12, -3.1, 2.36), 0.07, verts=6), "RightLowerArm", "steel")
    b.part(spike((-1.12, -3.0, 2.28), (0, -1, 0), 0.6, 0.05, verts=4), "RightLowerArm", "chrome")

    # ---- Legs: boots and wraps
    for side, sx in (("Left", 1), ("Right", -1)):
        b.part(limb([(sx * 0.45, 0.0, 2.55), (sx * 0.47, -0.03, 1.9), (sx * 0.47, -0.05, 1.3)], [0.32, 0.28, 0.24]),
               f"{side}UpperLeg", "olive")
        b.part(limb([(sx * 0.47, -0.05, 1.3), (sx * 0.47, -0.05, 0.6)], [0.24, 0.22]), f"{side}LowerLeg", "sandstone")
        b.part(sf.box((0.55, 1.0, 0.55), loc=(sx * 0.47, -0.2, 0.28), bevel=0.12, segments=1), f"{side}LowerLeg", "rubber")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, s in ((0, 1), (15, -1), (30, 1)):
        b.key("LeftUpperLeg", f, (-24 * s, 0, 0))
        b.key("RightUpperLeg", f, (24 * s, 0, 0))
        b.key("LeftLowerLeg", f, (10 if s > 0 else 32, 0, 0))
        b.key("RightLowerLeg", f, (32 if s > 0 else 10, 0, 0))
        b.key("LeftUpperArm", f, (14 * s, 0, 4))
        b.key("RightUpperArm", f, (-30, 0, -6))                          # the rifle held low and ready
        b.key("RightLowerArm", f, (-40, 0, 0))
        b.key("Torso", f, (8, -5 * s, 0))
        b.key("Head", f, (-6, 6 * s, 0))
        b.key("Pelvis", f, (0, 4 * s, 0), loc=(0, 0, 0))
    for f in (7, 22):
        b.key("Pelvis", f, (0, 0, 0), loc=(0, 0.12, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 27, loop=False, priority="Action")
    b.rest(0)
    for f in (6, 13):                                                    # shoulders the rifle and aims
        b.key("RightUpperArm", f, (-85, 0, -20))
        b.key("RightLowerArm", f, (-20, 0, 0))
        b.key("LeftUpperArm", f, (-75, 0, 35))
        b.key("LeftLowerArm", f, (-30, 0, 0))
        b.key("Torso", f, (4, 10, 0))
        b.key("Head", f, (6, -6, 0))
    b.key("Torso", 14, (-6, 10, 0), ease="QUAD")                          # the kick of the shot
    b.key("RightUpperArm", 14, (-100, 0, -20), ease="QUAD")
    b.key("Torso", 18, (4, 10, 0))
    b.key("RightUpperArm", 18, (-85, 0, -20))
    b.rest(27)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("AshRaider", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.0, 2.9), hrp_size=(2.0, 2.0, 1.0), step="A5",
          meta={"role": "Fighter", "band": "Surface", "hitTime": HIT_TIME},
          sockets={"Muzzle": ((-1.12, -3.1, 2.36), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
