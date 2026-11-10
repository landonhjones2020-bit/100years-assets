"""Monster_AshRaider_Melee: the raiders who charge in with a club (Landon, Prompt 16: "melee or
rifles", about a third of raiders; Config.Monsters.AshRaiderMelee). The same raider as
Monster_AshRaider without the rifle: a scrap club in the right hand, a leather-wrapped pipe with
a rusty flange for a head, two rows of steel spikes and barbed wire wound round it.

Rig AshRaiderMelee: the raider's bones; the club rides on RightLowerArm. Clips: Idle (waiting, the
club up and tapping, the mask sweeping the ash, looped), Walk (the club up and ready, looped),
Attack (an overhead blow, Hit 0.5 s: when MonsterService checks the swing).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_AshRaider_Melee.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, rod  # noqa: E402
import Monster_AshRaider as raider  # noqa: E402

ASSET, CATEGORY = "Monster_AshRaider_Melee", "Monsters"
HIT_TIME = 0.5
HAND = (-1.12, -0.22, 2.3)        # the right glove
HEAD_Y = -2.0                     # the club's head, forward of the hand


def build(b):
    raider.build(b, weapon="club")
    x, _y, z = HAND
    # the handle: a pipe through the fist, wrapped in leather at the grip
    b.part(rod((x, 0.45, z), (x, HEAD_Y, z), 0.08, verts=6), "RightLowerArm", "gunmetal")
    b.part(rod((x, 0.3, z), (x, -0.5, z), 0.11, verts=6), "RightLowerArm", "leather")
    b.part(sf.cyl(0.14, 0.1, loc=(x, 0.48, z), rot=(90, 0, 0), verts=6, bevel=0.0), "RightLowerArm", "rust")
    # the head: a rusty flange and a collar, two rows of spikes (long ones, and short ones between)
    b.part(sf.cyl(0.36, 0.28, loc=(x, HEAD_Y + 0.1, z), rot=(90, 0, 0), verts=8, bevel=0.04, segments=1), "RightLowerArm", "rust")
    b.part(sf.cyl(0.2, 0.56, loc=(x, HEAD_Y + 0.1, z), rot=(90, 0, 0), verts=8, bevel=0.0), "RightLowerArm", "steel")
    for i in range(8):
        a = math.radians(45 + i * 45)
        long = i % 2 == 0
        b.part(spike((x + math.cos(a) * 0.3, HEAD_Y + (0.04 if long else 0.2), z + math.sin(a) * 0.3), (math.cos(a), 0, math.sin(a)),
                     0.44 if long else 0.28, 0.09 if long else 0.07, verts=4), "RightLowerArm", "chrome")
    # barbed wire wound round the head, and a ring swinging from the pommel
    b.part(sf.torus(0.4, 0.028, loc=(x, HEAD_Y + 0.12, z), rot=(90 + 28, 0, 0), major_segs=8, minor_segs=3), "RightLowerArm", "gunmetal")
    b.part(sf.torus(0.1, 0.03, loc=(x, 0.56, z - 0.1), rot=(0, 90, 0), major_segs=6, minor_segs=3), "RightLowerArm", "steel")


READY = {"RightUpperArm": (-10, -30, -30), "RightLowerArm": (-95, 0, 0)}     # the club cocked beside its head, clear of the mask


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, s in ((0, 1), (15, -1), (30, 1)):
        b.key("LeftUpperLeg", f, (-26 * s, 0, 0))
        b.key("RightUpperLeg", f, (26 * s, 0, 0))
        b.key("LeftLowerLeg", f, (10 if s > 0 else 34, 0, 0))
        b.key("RightLowerLeg", f, (34 if s > 0 else 10, 0, 0))
        b.key("LeftUpperArm", f, (18 * s, 0, 6))
        b.key("LeftLowerArm", f, (-20, 0, 0))
        b.key("RightUpperArm", f, (-10 + 5 * s, -30, -30))                 # the club up and ready
        b.key("RightLowerArm", f, (-92 - 4 * s, 0, 0))
        b.key("Torso", f, (12, -6 * s, 0))                                 # leaning into the charge
        b.key("Head", f, (-10, 6 * s, 0))
        b.key("Pelvis", f, (0, 4 * s, 0), loc=(0, 0, 0))
    for f in (7, 22):
        b.key("Pelvis", f, (0, 0, 0), loc=(0, 0.14, 0))
    return act


def idle(b):
    """Waiting for someone to hit: the club cocked and tapping, the mask sweeping the ash."""
    act = sf.new_action(b.arm, "Idle", 0, 90, loop=True, priority="Idle")
    for f, k in ((0, 0.0), (45, 1.0), (90, 0.0)):
        b.key("Pelvis", f, (0, 5 - 10 * k, 0), loc=(0, 0, 0))
        b.key("Torso", f, (5 + 2 * k, 5 - 10 * k, 0))
        b.key("Head", f, (-4 + 2 * k, -18 + 36 * k, 0))
        b.key("LeftUpperArm", f, (10 - 5 * k, 0, 10))
        b.key("LeftLowerArm", f, (-28 - 6 * k, 0, 0))
        for side in ("Left", "Right"):
            b.key(f"{side}UpperLeg", f, (0, 0, 0))
            b.key(f"{side}LowerLeg", f, (0, 0, 0))
    for f in range(0, 91, 15):                                            # three slow taps of the club
        up = (f // 15) % 2 == 0
        b.key("RightUpperArm", f, READY["RightUpperArm"])
        b.key("RightLowerArm", f, (-95 if up else -74, 0, 0), ease="QUAD")
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 30, loop=False, priority="Action")
    for f in (0, 30):                                                     # from the ready stance, and back to it
        b.rest(f)
        b.key("RightUpperArm", f, READY["RightUpperArm"])
        b.key("RightLowerArm", f, READY["RightLowerArm"])
    b.key("RightUpperArm", 8, (-165, 0, -18), ease="QUAD")   # wound up over the shoulder
    b.key("RightLowerArm", 8, (-70, 0, 0))
    b.key("LeftUpperArm", 8, (-40, 0, 20))
    b.key("Torso", 8, (-12, -14, 0))
    b.key("Head", 8, (8, 10, 0))
    b.key("RightUpperArm", 15, (-62, 0, -6), ease="QUAD")     # the blow lands (Hit 0.5 s)
    b.key("RightLowerArm", 15, (-8, 0, 0))
    b.key("LeftUpperArm", 15, (20, 0, 12))
    b.key("Torso", 15, (22, 12, 0))
    b.key("Head", 15, (-14, -8, 0))
    b.key("RightUpperArm", 20, (-40, 0, -4))                                       # through and down
    b.key("RightLowerArm", 20, (-4, 0, 0))
    b.key("Torso", 20, (26, 14, 0))
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("AshRaiderMelee", raider.JOINTS), build,
          lambda b: [idle(b), walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.0, 2.9), hrp_size=(2.0, 2.0, 1.0), step="P20",
          meta={"role": "Fighter", "band": "Surface", "hitTime": HIT_TIME},
          sockets={"Tip": ((HAND[0], HEAD_Y, HAND[2]), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
