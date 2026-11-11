"""Monster_PrismStalker: the Crystal Hollows ambusher (bible Section 10: "Invisible until lit by
a flare or lamp"). A hunting thing made of glass. Under the light it is a gaunt, long-necked
stalker on four thin limbs: a dark spine and ribs like wire, and over them overlapping prism
plates of clear crystal that bend what is behind them. Its head is a narrow wedge with one
bright slit for an eye and a jaw of needles; its forelimbs are two long crystal scythes held
folded like a mantis's; its tail is a whip ending in a prism. Out of the light nearly all of it
is gone: only the slit, the scythes' edges and a few facets (the Glint parts) still catch it.

About 8 studs nose to tail and 4.8 high at the folded scythes: taller than a resident's waist,
and longer than they are tall.

Rig: Body (the hips, root), Chest, Neck, Head, Jaw, arms and blades, thighs and shins, Tail,
TailTip. Clips: Idle (a slow sway, the scythes flexing), Walk (a low prowl), Attack (both
scythes whip down and across, Hit at 0.3 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_PrismStalker.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, limb, blob, shell, shard, web  # noqa: E402,F401

ASSET, CATEGORY = "Monster_PrismStalker", "Monsters"
HIT_TIME = 0.3
JOINTS = [
    ("Body", None, (0, 0.7, 2.55)),
    ("Chest", "Body", (0, -0.45, 2.8)),
    ("Neck", "Chest", (0, -1.3, 3.15)),
    ("Head", "Neck", (0, -2.05, 3.95)),
    ("Jaw", "Head", (0, -2.3, 3.72)),
    ("LeftArm", "Chest", (0.5, -1.0, 3.0)),
    ("LeftBlade", "LeftArm", (1.25, -1.35, 4.35)),
    ("RightArm", "Chest", (-0.5, -1.0, 3.0)),
    ("RightBlade", "RightArm", (-1.25, -1.35, 4.35)),
    ("LeftLeg", "Body", (0.55, 0.85, 2.45)),
    ("LeftShin", "LeftLeg", (0.95, 1.75, 1.35)),
    ("RightLeg", "Body", (-0.55, 0.85, 2.45)),
    ("RightShin", "RightLeg", (-0.95, 1.75, 1.35)),
    ("Tail", "Body", (0, 1.5, 2.55)),
    ("TailTip", "Tail", (0, 3.0, 2.35)),
]
GLASS = {"mat": "Glass", "transparency": 0.3, "smooth_angle": None}


def plate(b, bone, base, direction, length, radius, twist=0.0):
    """A clear prism plate: a three-sided crystal lying along the body."""
    return b.part(shard(base, direction, length, radius, sides=3, tip=0.08, waist=0.35, twist=twist), bone, "crystal", **GLASS)


def build(b):
    # ---- the frame: a dark spine, hips and a cage of wire ribs
    b.part(limb([(0, 1.5, 2.55), (0, 0.7, 2.62), (0, -0.45, 2.85), (0, -1.3, 3.15)], [0.16, 0.22, 0.24, 0.17], sides=6,
                resolution=2), "Body", "basalt")
    b.part(blob(0.42, (0, 0.75, 2.5), scale=(1.25, 1.3, 0.8), segs=8, rings=5, seed=2), "Body", "basalt")      # hips
    b.part(blob(0.5, (0, -0.6, 2.75), scale=(1.05, 1.5, 0.95), segs=8, rings=5, seed=3), "Chest", "basalt")    # chest
    for i, y in enumerate((-1.05, -0.7, -0.35, 0.0)):
        for sx in (-1, 1):
            b.part(limb([(0, y, 3.0 - i * 0.03), (sx * 0.5, y + 0.06, 2.72), (sx * 0.42, y + 0.12, 2.25),
                         (sx * 0.12, y + 0.1, 2.02)], [0.05, 0.045, 0.04, 0.03], sides=4, resolution=2),
                   "Chest", "rubber")
    b.neon(blob(0.2, (0, -0.55, 2.55), scale=(0.9, 1.6, 0.8), segs=6, rings=4, seed=4), "Chest", "GlintHeart")  # seen through the ribs

    # ---- the prism plates: clear crystal lying back along the spine, overlapping like scales
    for i, (y, z, ln, r) in enumerate(((-1.25, 3.2, 1.3, 0.34), (-0.7, 3.12, 1.5, 0.4), (-0.1, 2.95, 1.6, 0.42),
                                       (0.55, 2.82, 1.5, 0.38), (1.15, 2.72, 1.2, 0.3))):
        bone = "Chest" if y < 0.2 else "Body"
        plate(b, bone, (0, y, z), (0, 0.72, 0.62), ln, r, twist=0.2 * i)
        for sx in (-1, 1):
            plate(b, bone, (sx * 0.34, y + 0.15, z - 0.28), (sx * 0.75, 0.6, 0.12), ln * 0.72, r * 0.72, twist=sx * 0.5)
    b.neon(shard((0, 0.48, 3.82), (0, 0.72, 0.62), 0.3, 0.06, sides=3), "Body", "GlintSpine")
    # a second, lower row down each flank, and plates over the shoulders and the hips
    for i, (y, z, ln) in enumerate(((-0.95, 2.62, 0.95), (-0.45, 2.52, 1.05), (0.1, 2.44, 1.0), (0.6, 2.4, 0.85))):
        bone = "Chest" if y < 0.2 else "Body"
        for sx in (-1, 1):
            plate(b, bone, (sx * 0.46, y, z), (sx * 0.55, 0.8, -0.25), ln, 0.24, twist=sx * (0.3 + 0.2 * i))
    for sx in (-1, 1):
        plate(b, "Chest", (sx * 0.42, -1.25, 3.05), (sx * 0.9, 0.35, 0.45), 1.15, 0.36, twist=sx * 0.8)       # shoulder
        plate(b, "Chest", (sx * 0.4, -1.3, 2.75), (sx * 0.8, -0.3, -0.5), 0.8, 0.24, twist=sx * 0.4)
        plate(b, "Body", (sx * 0.45, 0.95, 2.7), (sx * 0.85, 0.5, 0.35), 1.0, 0.32, twist=sx * 0.6)           # hip
    for i in range(7):                                                                                        # vertebrae
        y = -1.1 + i * 0.42
        z = 3.14 - i * 0.085
        b.part(spike((0, y, z - 0.05), (0, 0.25, 1.0), 0.34, 0.06, verts=4), "Chest" if y < 0.2 else "Body", "rubber")

    # ---- the neck and the head: a narrow wedge, one slit, a jaw of needles
    b.part(limb([(0, -1.3, 3.15), (0, -1.6, 3.55), (0, -2.05, 3.92)], [0.17, 0.13, 0.12], sides=6, resolution=2),
           "Neck", "basalt")
    for i, t in enumerate((0.25, 0.6)):
        at = sf.Vector((0, -1.3 - 0.75 * t, 3.2 + 0.72 * t))
        plate(b, "Neck", at, (0, 0.55, 0.9), 0.75 - i * 0.15, 0.2)
    b.part(shard((0, -1.7, 4.02), (0, -1.0, -0.12), 1.75, 0.46, sides=3, tip=0.06, waist=0.22, twist=3.14159),
           "Head", "basalt")                                                                                  # the skull wedge
    for sx in (-1, 1):
        # cheek facets and a brow ridge over the slit
        b.part(shard((sx * 0.2, -1.85, 3.86), (sx * 0.25, -1.0, -0.2), 0.95, 0.17, sides=3, tip=0.05), "Head", "crystal", **GLASS)
        b.part(limb([(sx * 0.05, -2.7, 4.1), (sx * 0.34, -2.4, 4.16), (sx * 0.42, -2.05, 4.08)], [0.03, 0.05, 0.03],
                    sides=3, resolution=1), "Head", "rubber")
    b.part(shard((0, -1.8, 4.16), (0, 1.0, 0.5), 0.9, 0.24, sides=3, tip=0.05), "Head", "crystal", **GLASS)    # a crest swept back
    for sx in (-1, 1):
        b.part(shard((sx * 0.2, -1.9, 4.08), (sx * 0.5, 0.9, 0.55), 0.7, 0.13, sides=3, tip=0.05), "Head", "crystal", **GLASS)
    b.neon(sf.box((0.66, 0.09, 0.09), loc=(0, -2.62, 4.0), rot=(0.12, 0, 0), bevel=0.0), "Head", "GlintEye")    # the slit
    b.part(sf.box((0.8, 0.14, 0.18), loc=(0, -2.56, 4.0), rot=(0.12, 0, 0), bevel=0.0), "Head", "rubber")
    for i, x in enumerate((-0.2, -0.1, 0.0, 0.1, 0.2)):
        b.part(spike((x, -2.9 - 0.08 * (2 - abs(i - 2)), 3.86), (0, -0.2, -1.0), 0.24, 0.035, verts=3), "Head", "cream")
    b.part(limb([(0, -2.25, 3.72), (0, -2.7, 3.62), (0, -3.15, 3.66)], [0.12, 0.09, 0.03], sides=4, resolution=1),
           "Jaw", "basalt")
    for i, y in enumerate((-2.55, -2.75, -2.95, -3.1)):
        for sx in (-1, 1):
            b.part(spike((sx * (0.09 - i * 0.015), y, 3.68), (sx * 0.2, -0.1, 1.0), 0.2 - i * 0.02, 0.026, verts=3),
                   "Jaw", "cream")

    # ---- the scythes: an arm up to a high elbow, a long clear blade folded forward and down
    for side, sx in (("Left", 1), ("Right", -1)):
        arm, blade = f"{side}Arm", f"{side}Blade"
        shoulder = sf.Vector((sx * 0.5, -1.0, 3.0))
        elbow = sf.Vector((sx * 1.25, -1.35, 4.35))
        b.part(limb([shoulder, (shoulder + elbow) / 2 + sf.Vector((sx * 0.1, 0.05, 0)), elbow], [0.14, 0.1, 0.09],
                    sides=5, resolution=1), arm, "basalt")
        b.part(blob(0.15, elbow, segs=6, rings=4, seed=6), arm, "rubber")
        plate(b, arm, shoulder + sf.Vector((sx * 0.1, 0.1, 0.25)), (sx * 0.5, 0.5, 0.8), 0.8, 0.18)
        spine = [elbow, elbow + sf.Vector((sx * 0.1, -1.0, -0.55)), elbow + sf.Vector((sx * 0.05, -1.9, -1.6)),
                 elbow + sf.Vector((-sx * 0.1, -2.35, -2.85))]
        edge = [elbow + sf.Vector((0, 0.1, -0.5)), elbow + sf.Vector((sx * 0.08, -0.6, -1.15)),
                elbow + sf.Vector((sx * 0.03, -1.45, -2.05)), elbow + sf.Vector((-sx * 0.1, -2.27, -2.93))]   # not the spine's last point: a web that closes to a line is trimmed by Studio's importer
        b.part(limb(spine, [0.1, 0.085, 0.06, 0.012], sides=4, resolution=2), blade, "basalt")
        b.part(web(spine, edge, 0.045), blade, "crystal", **GLASS)
        b.neon(limb([e + sf.Vector((0, 0.02, -0.02)) for e in edge], [0.02, 0.03, 0.025, 0.008], sides=3, resolution=2),
               blade, "GlintBlade")
        # (shards, not spikes: a spike's tip is a point, and Studio's importer trims it, which fails the size check)
        b.part(shard(elbow, (sx * 0.2, 0.8, 0.6), 0.5, 0.075, sides=4, tip=0.12), blade, "crystal", **GLASS)   # elbow spur
        for k in (0.18, 0.34, 0.5, 0.66, 0.8):                                                                 # serrations
            at, d = B.along(edge, k)
            b.part(shard(at, (0, 0.55, -1.0), 0.22 * (1.1 - k * 0.5), 0.05, sides=3, tip=0.12), blade, "crystal", **GLASS)
        for k in (0.3, 0.6):                                                                                   # ridges on the back
            at, d = B.along(spine, k)
            b.part(spike(at, (sx * 0.3, -0.4, 1.0), 0.26, 0.05, verts=3), blade, "rubber")

    # ---- the hind legs: thigh back to a high hock, shin down to two crystal claws
    for side, sx in (("Left", 1), ("Right", -1)):
        leg, shin = f"{side}Leg", f"{side}Shin"
        hip = sf.Vector((sx * 0.55, 0.85, 2.45))
        hock = sf.Vector((sx * 0.95, 1.75, 1.35))
        foot = sf.Vector((sx * 1.0, 1.05, 0.06))
        b.part(limb([hip, (hip + hock) / 2 + sf.Vector((sx * 0.08, -0.1, 0.1)), hock], [0.22, 0.17, 0.1], sides=6,
                    resolution=1), leg, "basalt")
        plate(b, leg, hip + sf.Vector((sx * 0.16, 0.0, 0.1)), (sx * 0.35, 0.75, -0.6), 1.3, 0.26)
        b.part(blob(0.13, hock, segs=6, rings=4, seed=7), leg, "rubber")
        b.part(limb([hock, (hock + foot) / 2 + sf.Vector((0, 0.12, 0)), foot], [0.1, 0.075, 0.07], sides=5, resolution=1),
               shin, "basalt")
        for dx in (-0.2, 0.0, 0.2):
            b.part(shard(foot + sf.Vector((dx, 0.05, 0.02)), (dx * 1.4, -1.0, -0.03), 0.66 - abs(dx), 0.075, sides=3, tip=0.03),
                   shin, "crystal")
        b.part(shard(foot + sf.Vector((0, 0.1, 0.1)), (0, 1.0, 0.1), 0.3, 0.06, sides=3, tip=0.03), shin, "crystal")
        plate(b, shin, hock + sf.Vector((0, -0.05, -0.15)), (0, -0.45, -1.0), 0.8, 0.14)
        b.part(spike(hock, (0, 0.9, 0.5), 0.45, 0.06, verts=4), shin, "crystal", **GLASS)                      # hock spur

    # ---- the tail: a whip ending in a prism
    b.part(limb([(0, 1.5, 2.55), (0, 2.25, 2.5), (0, 3.0, 2.35)], [0.16, 0.11, 0.08], sides=5, resolution=2), "Tail", "basalt")
    for i, y in enumerate((1.7, 2.2, 2.7)):
        plate(b, "Tail", (0, y, 2.62 - i * 0.05), (0, 0.85, 0.5), 0.6 - i * 0.08, 0.16 - i * 0.02)
    b.part(limb([(0, 3.0, 2.35), (0, 3.7, 2.3), (0, 4.3, 2.42)], [0.08, 0.055, 0.04], sides=5, resolution=2), "TailTip", "basalt")
    for i, y in enumerate((1.6, 1.95, 2.3, 2.65)):
        b.part(spike((0, y, 2.6 - i * 0.04), (0, 0.3, 1.0), 0.26 - i * 0.03, 0.045, verts=4), "Tail", "rubber")
    for i, y in enumerate((3.2, 3.55, 3.9)):
        b.part(spike((0, y, 2.36), (0, 0.3, 1.0), 0.16, 0.035, verts=4), "TailTip", "rubber")
        for sx in (-1, 1):
            plate(b, "TailTip", (sx * 0.03, y, 2.34), (sx * 0.8, 0.7, 0.15), 0.34, 0.08)
    b.part(shard((0, 4.2, 2.4), (0, 1.0, 0.25), 1.15, 0.24, sides=3, tip=0.05, waist=0.4), "TailTip", "crystal", **GLASS)
    b.neon(shard((0, 5.2, 2.65), (0, 1.0, 0.25), 0.22, 0.05, sides=3), "TailTip", "GlintTail")


def prowl(b, f, k, sway):
    b.key("Body", f, (0, sway * 4, 0), loc=(0, -0.06 * abs(k), 0))
    b.key("Chest", f, (3, -sway * 6, 0))
    b.key("Neck", f, (8, -sway * 5, 0))
    b.key("Head", f, (-6, sway * 6, 0))
    b.key("LeftLeg", f, (22 * k, 0, 0))
    b.key("LeftShin", f, (-18 * k - 6, 0, 0))
    b.key("RightLeg", f, (-22 * k, 0, 0))
    b.key("RightShin", f, (18 * k - 6, 0, 0))
    b.key("LeftArm", f, (-10 * k, 0, 0))
    b.key("RightArm", f, (10 * k, 0, 0))
    b.key("LeftBlade", f, (8 * k, 0, 0))
    b.key("RightBlade", f, (-8 * k, 0, 0))
    b.key("Tail", f, (0, -sway * 16, 0))
    b.key("TailTip", f, (0, -sway * 22, 0))


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 24, loop=True, priority="Movement")
    for f, k, sway in ((0, 1, 0), (6, 0, 1), (12, -1, 0), (18, 0, -1), (24, 1, 0)):
        prowl(b, f, k, sway)
        b.key("Jaw", f, (6, 0, 0))
    return act


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 72, loop=True, priority="Idle")
    for f, k in ((0, 0), (18, 1), (36, 0), (54, -1), (72, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, -0.05 * abs(k), 0))
        b.key("Chest", f, (2 * abs(k), 3 * k, 0))
        b.key("Neck", f, (-4 * abs(k), 8 * k, 0))
        b.key("Head", f, (4 * abs(k), 10 * k, 4 * k))
        b.key("Jaw", f, (5 + 7 * abs(k), 0, 0))
        b.key("LeftBlade", f, (-8 * max(k, 0), 0, 0))
        b.key("RightBlade", f, (-8 * max(-k, 0), 0, 0))
        b.key("Tail", f, (0, 12 * k, 0))
        b.key("TailTip", f, (4 * abs(k), 18 * k, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 24, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 5, (-8, 0, 0), loc=(0, 0.1, -0.2))                    # coils: scythes high and wide
    b.key("Chest", 5, (-14, 0, 0))
    b.key("Neck", 5, (-14, 0, 0))
    b.key("Jaw", 5, (30, 0, 0))
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 5, (-28, 0, sx * 22))
        b.key(f"{side}Blade", 5, (-58, 0, 0))
    b.key("Tail", 5, (-10, 0, 0))
    b.key("Body", 9, (10, 0, 0), loc=(0, -0.12, 0.7), ease="QUAD")      # springs: both blades down and across at 0.3 s
    b.key("Chest", 9, (16, 0, 0), ease="QUAD")
    b.key("Neck", 9, (10, 0, 0), ease="QUAD")
    b.key("Head", 9, (-12, 0, 0), ease="QUAD")
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 9, (34, 0, -sx * 20), ease="QUAD")
        b.key(f"{side}Blade", 9, (30, 0, 0), ease="QUAD")
    b.key("Jaw", 10, (-2, 0, 0))
    b.key("Tail", 10, (12, 0, 0))
    b.key("Body", 15, (6, 0, 0), loc=(0, -0.06, 0.4))
    for side, sx in (("Left", 1), ("Right", -1)):
        b.key(f"{side}Arm", 15, (24, 0, -sx * 14))
        b.key(f"{side}Blade", 15, (20, 0, 0))
    b.rest(24)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("PrismStalker", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=3400, hrp_center=(0, 0.7, 2.55), hrp_size=(2.0, 2.0, 3.6), step="A10",
          meta={"role": "Ambusher", "band": "CrystalHollows", "hitTime": HIT_TIME},
          sockets={"Slash": ((0, -3.6, 1.6), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
