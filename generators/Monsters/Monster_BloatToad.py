"""Monster_BloatToad: the Flooded Caverns exploder (bible Section 10: "Bursts on death or
contact and floods the room"). A cave toad the Source pumped full of water: a squat warty murk
body carrying a bladder on its back three times its own size, stretched thin enough to see the
glowing core floating inside, plum veins standing out across it. A pale throat sac pulses as
it waddles at you. When it reaches something it swells, the bladder's three lobes straining
apart, and goes off. Scary, never gory.

About 5 studs long, 4.4 wide and 4.6 high: it fills a doorway to a resident's chest.

Rig: Body (root), Jaw, Throat, three bladder lobes (SacTop, SacLeft, SacRight: they slide
apart to swell it), four one-bone legs. Clips: Idle (breathing, the throat pulsing), Walk (a
heavy waddle), Attack (the swell, held at its fullest at 0.7 s: Tuning.MonsterAI's
BurstSwellSeconds, when MonsterService bursts it).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_BloatToad.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, vein, web  # noqa: E402,F401

ASSET, CATEGORY = "Monster_BloatToad", "Monsters"
SWELL_TIME = 0.7
SAC = sf.Vector((0, 0.7, 2.75))            # the bladder's middle
LEGS = (("LeftArm", 1, -1.05, 0.95), ("RightArm", -1, -1.05, 0.95), ("LeftLeg", 1, 1.0, 1.0), ("RightLeg", -1, 1.0, 1.0))
JOINTS = [
    ("Body", None, (0, 0.0, 1.15)),
    ("Jaw", "Body", (0, -1.0, 1.05)),
    ("Throat", "Body", (0, -1.2, 0.8)),
    ("SacTop", "Body", (0, 0.7, 2.6)),
    ("SacLeft", "Body", (0.8, 0.8, 2.1)),
    ("SacRight", "Body", (-0.8, 0.8, 2.1)),
] + [(name, "Body", (sx * 1.1, y, z)) for name, sx, y, z in LEGS]


def wart(b, bone, at, r, seed, swatch="basalt"):
    b.part(blob(r, at, scale=(1, 1, 0.6), segs=5, rings=3, seed=seed), bone, swatch)


def build(b):
    # ---- the body: a squat warty toad, pale underneath
    b.part(blob(1.5, (0, 0.05, 1.2), scale=(1.12, 1.25, 0.66), segs=14, rings=8, noise=0.035, seed=31), "Body", "murk")
    b.part(blob(1.3, (0, 0.0, 0.86), scale=(1.1, 1.22, 0.5), segs=12, rings=6, seed=32), "Body", "sandstone")
    # the head is the front of the body: a wide blunt muzzle, eyes on stalks of skin
    b.part(blob(1.0, (0, -1.5, 1.42), scale=(1.34, 0.9, 0.52), segs=12, rings=6, noise=0.03, seed=33), "Body", "murk")
    for sx in (-1, 1):
        b.part(blob(0.36, (sx * 0.78, -1.4, 1.92), scale=(1, 1, 0.9), segs=8, rings=5, seed=34), "Body", "murk")
        eye(b, "Body", (sx * 0.86, -1.6, 2.02), 0.2, facing=(sx * 0.35, -0.9, 0.3), segs=8)
        b.part(limb([(sx * 0.5, -1.65, 2.02), (sx * 0.84, -1.5, 2.3), (sx * 1.14, -1.25, 2.0)], [0.07, 0.1, 0.06],
                    sides=4, resolution=2), "Body", "basalt")                                    # brow
        b.part(sf.sphere(0.05, loc=(sx * 0.28, -2.33, 1.56), segs=5, rings=3), "Body", "basalt")  # nostril
    rnd_spots = ((1.2, -0.6, 1.62, 0.22), (-1.3, -0.3, 1.58, 0.2), (1.5, 0.3, 1.4, 0.24), (-1.45, 0.5, 1.42, 0.2),
                 (0.9, -1.3, 1.82, 0.15), (-0.5, -1.7, 1.88, 0.13), (0.2, -1.9, 1.84, 0.12), (1.3, 1.1, 1.36, 0.2),
                 (-1.2, 1.2, 1.4, 0.22), (0.0, 1.75, 1.3, 0.2), (1.62, -0.2, 1.1, 0.16), (-1.62, 0.1, 1.1, 0.16))
    for i, (x, y, z, r) in enumerate(rnd_spots):
        wart(b, "Body", (x, y, z), r, 40 + i)
    # upper lip teeth: short and blunt, a toad's
    for i, p in enumerate(B.arc((0, -1.5, 1.2), 1.0, 205, 335, 13)):
        p = sf.Vector((p.x * 1.3, -1.5 + (p.y + 1.5) * 0.86, 1.22))
        b.part(spike(p, (0, 0.1, -1), 0.2 if i % 2 else 0.13, 0.05, verts=3), "Body", "cream")

    # ---- the jaw: a wide pale shovel; the throat sac hangs under it
    b.part(blob(1.0, (0, -1.5, 1.02), scale=(1.3, 0.92, 0.24), segs=12, rings=4, seed=35), "Jaw", "sandstone")
    b.part(shell((1.34, 0.95, 0.3), (0, -1.5, 0.98), -1.0, 0.4, z_from=-1.0, thickness=0.04, segs=12, rings=4),
           "Jaw", "murk")
    for i, p in enumerate(B.arc((0, -1.5, 1.1), 1.0, 210, 330, 9)):
        p = sf.Vector((p.x * 1.22, -1.5 + (p.y + 1.5) * 0.84, 1.12))
        b.part(spike(p, (0, 0.05, 1), 0.2, 0.05, verts=3), "Jaw", "cream")
    b.glow(blob(0.6, (0, -1.3, 1.1), scale=(1.4, 1.0, 0.2), segs=8, rings=4, seed=36), "Jaw", "JawGlow")   # its gullet
    b.part(blob(0.72, (0, -1.38, 0.6), scale=(1.25, 0.9, 0.62), segs=10, rings=6, seed=37), "Throat", "sandstone")
    for sx in (-1, 1):
        vein(b, "Throat", [(sx * 0.2, -1.95, 0.72), (sx * 0.5, -1.86, 0.5), (sx * 0.62, -1.55, 0.28)], 0.03, "ThroatGlow")

    # ---- the bladder: three see-through lobes around a glowing core, plum veins over them
    core = blob(0.62, SAC + sf.Vector((0, 0, -0.1)), scale=(1, 1.05, 0.95), segs=10, rings=6, noise=0.06, seed=38)
    b.glow(core, "Body", "Core")
    lobes = (("SacTop", (0, 0.1, 0.42), (1.5, 1.62, 1.42), 51), ("SacLeft", (0.72, -0.05, -0.2), (1.3, 1.5, 1.28), 52),
             ("SacRight", (-0.72, -0.05, -0.2), (1.3, 1.5, 1.28), 53))
    for bone, off, scale, seed in lobes:
        lobe = blob(1.0, SAC + sf.Vector(off), scale=scale, segs=12, rings=7, noise=0.02, seed=seed, name="Sac")
        sf.tag(lobe, bone, "skyblue", collision="query", transparency=0.45, cast_shadow=False)
        sf.bind(lobe, b.arm, bone)
    # veins: from the collar up and over each lobe
    for bone, pts in (
        ("SacTop", [(0.0, -0.9, 3.25), (0.25, -0.5, 4.22), (0.1, 0.3, 4.62), (-0.2, 1.2, 4.42), (0.0, 2.0, 3.6)]),
        ("SacTop", [(-0.9, 0.0, 3.9), (-0.45, 0.5, 4.5), (0.5, 0.9, 4.5), (1.05, 1.3, 3.9)]),
        ("SacLeft", [(1.3, -0.7, 1.9), (1.92, -0.3, 2.6), (2.04, 0.6, 2.9), (1.7, 1.6, 2.8), (1.2, 2.1, 2.2)]),
        ("SacLeft", [(1.9, 0.3, 1.75), (2.06, 0.5, 2.4), (1.6, 0.4, 3.4)]),
        ("SacRight", [(-1.3, -0.7, 1.9), (-1.92, -0.3, 2.6), (-2.04, 0.6, 2.9), (-1.7, 1.6, 2.8), (-1.2, 2.1, 2.2)]),
        ("SacRight", [(-1.9, 0.3, 1.75), (-2.06, 0.5, 2.4), (-1.6, 0.4, 3.4)]),
    ):
        b.part(sf.tube([tuple(p) for p in pts], [0.07] + [0.055] * (len(pts) - 2) + [0.03], sides=4, resolution=2),
               bone, "plum")
    # the collar the bladder grows out of: a ring of thick skin and warts
    b.part(sf.torus(1.32, 0.3, loc=(0, 0.62, 1.68), major_segs=12, minor_segs=4), "Body", "murk")
    for i, a in enumerate(range(0, 360, 45)):
        x, y = 1.42 * math.cos(math.radians(a)), 0.62 + 1.42 * math.sin(math.radians(a))
        wart(b, "Body", (x, y, 1.86), 0.17, 60 + i, "plum")

    # ---- legs: short bowed arms in front, big folded thighs behind
    for name, sx, y, z in LEGS:
        hip = sf.Vector((sx * 1.1, y, z))
        if "Arm" in name:
            elbow = hip + sf.Vector((sx * 0.62, -0.25, -0.28))
            foot = sf.Vector((sx * 1.55, y - 0.75, 0.08))
            b.part(limb([hip, elbow, foot], [0.4, 0.3, 0.2], sides=8, resolution=2), name, "murk")
            fan = ((1.0, -0.15), (0.6, -0.75), (0.0, -0.95), (-0.5, -0.7))
        else:
            knee = hip + sf.Vector((sx * 0.75, -0.75, 0.3))
            foot = sf.Vector((sx * 1.7, y + 0.35, 0.08))
            b.part(limb([hip, hip + sf.Vector((sx * 0.5, -0.4, 0.3)), knee], [0.62, 0.56, 0.36], sides=8, resolution=2),
                   name, "murk")
            b.part(limb([knee, (knee + foot) / 2 + sf.Vector((sx * 0.25, 0.1, 0)), foot], [0.34, 0.28, 0.2], sides=8,
                        resolution=2), name, "murk")
            wart(b, name, knee + sf.Vector((sx * 0.1, 0, 0.26)), 0.16, 70)
            fan = ((1.0, 0.1), (0.85, -0.6), (0.3, -1.0), (-0.3, -0.95))
        toes = [foot + sf.Vector((sx * 0.62 * c, 0.62 * s, -0.04)) for c, s in fan]
        for t in toes:
            b.part(spike(foot + sf.Vector((0, 0, 0.04)), t - foot, (t - foot).length * 1.12, 0.1, verts=4), name, "murk")
        b.part(web([foot] * len(toes), toes, 0.03), name, "plum")


def breathe(b, f, k):
    """k from 0 (in) to 1 (out): the bladder's lobes ease apart and the throat fills."""
    b.key("SacTop", f, (0, 0, 0), loc=(0, 0.12 * k, 0))
    b.key("SacLeft", f, (0, 0, 0), loc=(0.1 * k, 0.03 * k, 0))
    b.key("SacRight", f, (0, 0, 0), loc=(-0.1 * k, 0.03 * k, 0))


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 72, loop=True, priority="Idle")
    for f, k, throat in ((0, 0, 0), (18, 1, 1), (36, 0.3, 0.2), (54, 1, 1), (72, 0, 0)):
        breathe(b, f, k)
        b.key("Body", f, (0, 0, 0), loc=(0, 0.05 * k, 0))
        b.key("Throat", f, (0, 0, 0), loc=(0, -0.12 * throat, 0.22 * throat))
        b.key("Jaw", f, (3 * throat, 0, 0))
    return act


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 32, loop=True, priority="Movement")
    for f, k, roll in ((0, 1, 0), (8, 0, 1), (16, -1, 0), (24, 0, -1), (32, 1, 0)):
        b.key("LeftArm", f, (0, 20 * k, 6 * max(k, 0)))
        b.key("RightLeg", f, (0, 16 * k, -5 * max(k, 0)))
        b.key("RightArm", f, (0, 20 * k, -6 * max(-k, 0)))
        b.key("LeftLeg", f, (0, 16 * k, 5 * max(-k, 0)))
        b.key("Body", f, (2 * abs(roll), 3 * roll, 5 * roll), loc=(0, 0.1 * abs(roll), 0))
        breathe(b, f, 0.5 + 0.5 * abs(roll))            # the bladder sloshes with each step
        b.key("SacTop", f, (0, 0, -6 * roll), loc=(0, 0.06 + 0.06 * abs(roll), 0))
        b.key("Throat", f, (0, 0, 0), loc=(0, -0.08 * abs(k), 0.14 * abs(k)))
        b.key("Jaw", f, (4, 0, 0))
    return act


def attack(b):
    """The swell: it plants itself, the lobes strain apart, the jaw gapes; held at 0.7 s."""
    act = sf.new_action(b.arm, "Attack", 0, 30, loop=False, priority="Action")
    b.rest(0)
    for f, k in ((6, 0.35), (12, 0.6), (16, 0.52), (21, 1.0), (30, 1.08)):
        b.key("SacTop", f, (0, 0, 0), loc=(0, 1.0 * k, 0.15 * k), ease="QUAD")
        b.key("SacLeft", f, (0, 0, 5 * k), loc=(0.85 * k, 0.3 * k, 0), ease="QUAD")
        b.key("SacRight", f, (0, 0, -5 * k), loc=(-0.85 * k, 0.3 * k, 0), ease="QUAD")
        b.key("Body", f, (-10 * k, 0, 0), loc=(0, 0.35 * k, 0), ease="QUAD")
        b.key("Jaw", f, (38 * k, 0, 0), ease="QUAD")
        b.key("Throat", f, (0, 0, 0), loc=(0, -0.2 * k, 0.3 * k), ease="QUAD")
        for name, sx, _y, _z in LEGS:
            b.key(name, f, (0, 0, sx * 8 * k), ease="QUAD")
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("BloatToad", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.0, 1.15), hrp_size=(2.6, 1.6, 3.2), step="A8",
          meta={"role": "Exploder", "band": "FloodedCaverns", "hitTime": SWELL_TIME},
          sockets={"Burst": (tuple(SAC), 0.0)}, markers={"Attack": {"Hit": SWELL_TIME}})
