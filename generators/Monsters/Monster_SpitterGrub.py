"""Monster_SpitterGrub: the Mines ranged monster (bible Section 27: spits glowing goo that
slows from range). A bloated cave larva the Source filled with goo: pale segmented flesh
banded with plum plates, three swollen glowing goo sacs on its back with veins running to
the head, stubby prolegs and side bristles, a ring of six pinprick eyes, and a lamprey mouth
of four toothed petals that peel open to spit. Scary, never gory (detail pass 2026-11-08).

Rig: Body (root), Tail, Front, Head, four mouth petals. Clips: Walk (an inchworm crawl,
looped), Attack (rears up, the mouth peels open and spits; the goo leaves at 0.85 s,
Tuning.MonsterAI via the HitTime attribute).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_SpitterGrub.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, vein  # noqa: E402,F401

ASSET, CATEGORY = "Monster_SpitterGrub", "Monsters"
HIT_TIME = 0.85
MOUTH = sf.Vector((0, -2.5, 1.3))          # the centre of the mouth ring
PETALS = (("MouthTop", 0), ("MouthLeft", 90), ("MouthBottom", 180), ("MouthRight", 270))


def radial(deg):
    a = math.radians(deg)
    return sf.Vector((math.sin(a), 0, math.cos(a)))


JOINTS = [
    ("Body", None, (0, 0.45, 1.0)),
    ("Tail", "Body", (0, 1.45, 0.9)),
    ("Front", "Body", (0, -0.7, 1.05)),
    ("Head", "Front", (0, -1.7, 1.25)),
] + [(name, "Head", tuple(MOUTH + radial(deg) * 0.36 + sf.Vector((0, 0.08, 0)))) for name, deg in PETALS]


def segment(b, bone, loc, r, plate=True, seed=1):
    """One fat larva segment: pale flesh, a plum plate over the top, a ring of bristles."""
    b.part(blob(r, loc, scale=(1.0, 0.72, 0.86), segs=10, rings=6, noise=0.03, seed=seed), bone, "sandstone")
    if plate:
        b.part(shell((r * 1.04, r * 0.66, r * 0.9), loc, -0.75, 0.75, z_from=0.15, thickness=0.07, segs=10, rings=6),
               bone, "plum")
    for sx in (-1, 1):
        b.part(spike((sx * r * 0.92, loc[1], loc[2] - r * 0.15), (sx, 0.2, -0.35), r * 0.32, r * 0.05, verts=3),
               bone, "basalt")


def build(b):
    # ---- the segments, front to back
    segment(b, "Head", (0, -1.98, 1.3), 0.66, seed=1)
    segment(b, "Front", (0, -1.4, 1.18), 0.82, seed=2)
    segment(b, "Front", (0, -0.72, 1.12), 0.98, seed=3)
    segment(b, "Body", (0, 0.0, 1.06), 1.1, seed=4)
    segment(b, "Body", (0, 0.72, 1.0), 1.05, seed=5)
    segment(b, "Tail", (0, 1.42, 0.86), 0.86, seed=6)
    segment(b, "Tail", (0, 2.02, 0.72), 0.64, seed=7)
    b.part(limb([(0, 2.3, 0.7), (0, 2.65, 0.6), (0, 2.95, 0.42)], [0.38, 0.22, 0.04], sides=6), "Tail", "sandstone")
    b.part(spike((0, 2.85, 0.48), (0, 0.8, -0.3), 0.45, 0.08, verts=4), "Tail", "basalt")
    # ---- the goo sacs: swollen glowing bulbs in plum collars, veins running to the head
    for bone, (y, z, r) in (("Front", (-0.75, 1.98, 0.42)), ("Body", (0.0, 2.02, 0.5)), ("Body", (0.72, 1.92, 0.4))):
        b.glow(blob(r, (0, y, z), scale=(1.0, 0.95, 0.9), segs=8, rings=6, noise=0.04, seed=int(r * 100)),
               bone, f"{bone}Glow")
        b.part(sf.torus(r * 0.82, r * 0.16, loc=(0, y, z - r * 0.45), major_segs=10, minor_segs=3), bone, "plum")
    for sx in (-1, 1):
        vein(b, "Front", [(sx * 0.3, -0.75, 1.8), (sx * 0.55, -1.15, 1.72), (sx * 0.42, -1.5, 1.68)], 0.04, "FrontGlow")
        vein(b, "Body", [(sx * 0.35, 0.05, 1.85), (sx * 0.75, -0.25, 1.7), (sx * 0.8, -0.5, 1.55)], 0.04, "BodyGlow")
    # ---- prolegs under the body
    for bone, ys in (("Front", (-1.35, -0.7)), ("Body", (0.0, 0.72)), ("Tail", (1.42,))):
        for y in ys:
            for sx in (-1, 1):
                b.part(limb([(sx * 0.55, y, 0.55), (sx * 0.68, y - 0.05, 0.22), (sx * 0.7, y - 0.12, 0.04)],
                            [0.16, 0.12, 0.1], sides=4, resolution=1), bone, "basalt")
    # ---- the head: six pinprick eyes and a glowing throat behind the petals
    for i, (x, y, z) in enumerate(((0.16, -2.32, 1.78), (-0.16, -2.32, 1.78), (0.36, -2.22, 1.68),
                                   (-0.36, -2.22, 1.68), (0.27, -2.08, 1.88), (-0.27, -2.08, 1.88))):
        eye(b, "Head", (x, y, z), 0.055 if i < 2 else 0.042, facing=(x, -0.6, 0.8), segs=6)
    b.glow(sf.cyl(0.3, 0.12, loc=MOUTH + sf.Vector((0, 0.18, 0)), rot=(90, 0, 0), verts=10, bevel=0.0), "Head", "HeadGlow")
    b.part(sf.torus(0.42, 0.1, loc=MOUTH + sf.Vector((0, 0.12, 0)), rot=(90, 0, 0), major_segs=14, minor_segs=4),
           "Head", "plum")
    # ---- the mouth: four petals, each lined with inward hooked teeth
    for name, deg in PETALS:
        r = radial(deg)
        petal = sf.sphere(1.0, scale=(0.3, 0.36, 0.09), segs=8, rings=5)
        petal.location = MOUTH + r * 0.3 + sf.Vector((0, -0.18, 0))
        petal.rotation_euler = (0, math.radians(deg), 0)
        b.part(petal, name, "plum")
        tangent = sf.Vector((math.cos(math.radians(deg)), 0, -math.sin(math.radians(deg))))
        for k, t in ((0, -0.13), (1, 0.0), (2, 0.13)):
            base = MOUTH + r * 0.24 + tangent * t + sf.Vector((0, -0.12 - 0.08 * (k % 2), 0))
            b.part(spike(base, -r + sf.Vector((0, 0.35, 0)), 0.17, 0.035, verts=3), name, "cream")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, front, tail, head, bob, mouth in ((0, -6, 6, 4, 0.0, 4), (8, 4, -4, -2, 0.18, 10), (15, 8, -8, -6, 0.05, 2),
                                             (23, -2, 2, 2, 0.15, 8), (30, -6, 6, 4, 0.0, 4)):
        b.key("Front", f, (front, 0, 0))
        b.key("Tail", f, (tail, 0, 0))
        b.key("Head", f, (head, 0, 0))
        b.key("Body", f, (0, 0, 0), loc=(0, bob, 0))
        petals(b, f, mouth)
    return act


def petals(b, f, deg, ease="SINE"):
    """Open the mouth by deg: each petal swings out about its hinge."""
    b.key("MouthTop", f, (-deg, 0, 0), ease=ease)
    b.key("MouthBottom", f, (deg, 0, 0), ease=ease)
    b.key("MouthLeft", f, (0, deg, 0), ease=ease)
    b.key("MouthRight", f, (0, -deg, 0), ease=ease)


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 48, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 18, (0, 0, 0), loc=(0, 0.25, 0.1))
    b.key("Front", 18, (-28, 0, 0))
    b.key("Head", 18, (-24, 0, 0))
    b.key("Tail", 18, (10, 0, 0))
    petals(b, 18, 20)
    b.key("Front", 26, (22, 0, 0), ease="QUAD")
    b.key("Head", 26, (26, 0, 0), ease="QUAD")
    b.key("Body", 26, (0, 0, 0), loc=(0, 0.05, -0.1), ease="QUAD")
    petals(b, 24, 62, ease="QUAD")       # peeled wide as the goo leaves (0.85 s)
    petals(b, 32, 55)
    petals(b, 40, 8)
    b.rest(48)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("SpitterGrub", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=3500, hrp_center=(0, 0.0, 1.05), hrp_size=(2.0, 1.4, 4.2),
          meta={"role": "Ranged", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Mouth": ((0, -2.8, 1.3), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
