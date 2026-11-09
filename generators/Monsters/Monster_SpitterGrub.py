"""Monster_SpitterGrub: the Mines ranged monster (bible Section 27: spits glowing goo that
slows from range). A fat, segmented cave larva: avocado-green segments ringed in stone bands,
stubby rubbery legs, a round gunmetal mouth with a glowing throat, and a swollen Source-green
goo sac on its back. Never gory.

Rig: Body (root), Tail, Front, Head. Clips: Walk (an inchworm crawl, looped), Attack (rears
up and spits; the goo leaves at 0.85 s, Tuning.MonsterAI via the HitTime attribute).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_SpitterGrub.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, rod  # noqa: E402

ASSET, CATEGORY = "Monster_SpitterGrub", "Monsters"
HIT_TIME = 0.85
JOINTS = [
    ("Body", None, (0, 0.45, 1.0)),
    ("Tail", "Body", (0, 1.45, 0.9)),
    ("Front", "Body", (0, -0.7, 1.05)),
    ("Head", "Front", (0, -1.7, 1.25)),
]


def build(b):
    b.part(sf.sphere(1.15, loc=(0, 0.5, 1.0), scale=(1.0, 0.95, 0.85), segs=14, rings=8), "Body", "avocado")
    b.part(sf.sphere(0.85, loc=(0, 1.85, 0.72), scale=(0.95, 1.15, 0.8), segs=12, rings=6), "Tail", "avocado")
    b.part(sf.sphere(1.0, loc=(0, -0.85, 1.1), scale=(1.0, 0.9, 0.9), segs=14, rings=8), "Front", "avocado")
    b.part(sf.sphere(0.72, loc=(0, -1.95, 1.3), scale=(1.0, 0.95, 0.9), segs=12, rings=6), "Head", "olive")
    # stone bands between the segments
    for (y, z, r, bone) in ((1.25, 0.85, 0.9, "Tail"), (-0.15, 1.05, 1.08, "Body"), (-1.45, 1.22, 0.78, "Front")):
        ring = sf.torus(r, 0.12, loc=(0, y, z), rot=(90, 0, 0), major_segs=16, minor_segs=4)
        b.part(ring, bone, "stone")
    # the goo sac on its back and the mouth
    b.glow(sf.sphere(0.58, loc=(0, -0.55, 2.0), scale=(1.0, 1.1, 0.85), segs=10, rings=6), "Front", "FrontGlow")
    b.part(sf.cyl(0.42, 0.22, loc=(0, -2.62, 1.3), rot=(90, 0, 0), verts=12, bevel=0.04), "Head", "gunmetal")
    b.glow(sf.cyl(0.26, 0.08, loc=(0, -2.75, 1.3), rot=(90, 0, 0), verts=10, bevel=0.0), "Head", "HeadGlow")
    for sx in (-1, 1):
        b.glow(sf.sphere(0.1, loc=(sx * 0.32, -2.38, 1.72), segs=6, rings=4), "Head", "HeadGlow")
    # stubby legs under the body and the front
    for (y, bone) in ((0.9, "Body"), (0.1, "Body"), (-0.7, "Front"), (-1.25, "Front")):
        for sx in (-1, 1):
            b.part(rod((sx * 0.7, y, 0.5), (sx * 0.85, y, 0.0), 0.16, verts=6, radius_top=0.1), bone, "rubber")


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, front, tail, head, bob in ((0, -6, 6, 4, 0.0), (8, 4, -4, -2, 0.18), (15, 8, -8, -6, 0.05),
                                      (23, -2, 2, 2, 0.15), (30, -6, 6, 4, 0.0)):
        b.key("Front", f, (front, 0, 0))
        b.key("Tail", f, (tail, 0, 0))
        b.key("Head", f, (head, 0, 0))
        b.key("Body", f, (0, 0, 0), loc=(0, bob, 0))
    return act


def attack(b):
    act = sf.new_action(b.arm, "Attack", 0, 48, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 18, (0, 0, 0), loc=(0, 0.25, 0.1))
    b.key("Front", 18, (-28, 0, 0))
    b.key("Head", 18, (-24, 0, 0))
    b.key("Tail", 18, (10, 0, 0))
    b.key("Front", 26, (22, 0, 0), ease="QUAD")
    b.key("Head", 26, (26, 0, 0), ease="QUAD")
    b.key("Body", 26, (0, 0, 0), loc=(0, 0.05, -0.1), ease="QUAD")
    b.rest(48)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("SpitterGrub", JOINTS), build, lambda b: [walk(b), attack(b)],
          budget=2000, hrp_center=(0, 0.0, 1.05), hrp_size=(2.0, 1.4, 4.2),
          meta={"role": "Ranged", "band": "Mines", "hitTime": HIT_TIME},
          sockets={"Mouth": ((0, -2.8, 1.3), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
