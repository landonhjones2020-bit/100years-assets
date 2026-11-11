"""Monster_Lurker: the Flooded Caverns ambusher (bible Section 10: "Hides in water or dark
rooms and grabs residents"). Something between a giant salamander and an anglerfish, flat as
a rug so a hand's depth of water covers it: a broad blind head with milky eyes and a mouth
that runs ear to ear, a glowing lure on a stalk that is all you see of it in the dark, a long
finned tail, and two folded arms, each longer than a resident is tall, that end in three
hooked fingers. It lies still until someone walks past the light. Scary, never gory.

About 12 studs from fingertips to tail, 2 high lying flat, its elbows 3.4 up.

Rig: Body (root), Chest, Head, Jaw, Lure1, Lure2, two three-bone arms (Arm, Fore, Claw),
Tail1 to Tail3, two hind legs. Clips: Idle (flat, the lure swaying), Walk (it drags itself on
its arms, the tail snaking), Attack (rears and both arms shoot out and close, Hit at 0.5 s),
Latched (it has someone: the arms hold, the head worries at them).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_Lurker.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, vein, web  # noqa: E402,F401

ASSET, CATEGORY = "Monster_Lurker", "Monsters"
HIT_TIME = 0.5
SIDES = (("Left", 1), ("Right", -1))
SHOULDER, ELBOW, WRIST = (1.15, -1.3, 1.1), (2.0, -0.2, 3.3), (1.55, -3.0, 1.9)
LURE = ((0, -2.1, 1.75), (0, -2.9, 3.0), (0, -4.2, 2.9))      # the stalk's root, its bend, the bulb
JOINTS = [
    ("Body", None, (0, 0.6, 0.8)),
    ("Chest", "Body", (0, -0.6, 0.85)),
    ("Head", "Chest", (0, -1.9, 0.9)),
    ("Jaw", "Head", (0, -2.2, 0.62)),
    ("Lure1", "Head", LURE[0]),
    ("Lure2", "Lure1", LURE[1]),
    ("Tail1", "Body", (0, 1.9, 0.75)),
    ("Tail2", "Tail1", (0, 3.5, 0.6)),
    ("Tail3", "Tail2", (0, 5.0, 0.5)),
]
for _side, _sx in SIDES:
    JOINTS += [(f"{_side}Arm", "Chest", (_sx * SHOULDER[0], SHOULDER[1], SHOULDER[2])),
               (f"{_side}Fore", f"{_side}Arm", (_sx * ELBOW[0], ELBOW[1], ELBOW[2])),
               (f"{_side}Claw", f"{_side}Fore", (_sx * WRIST[0], WRIST[1], WRIST[2])),
               (f"{_side}Leg", "Body", (_sx * 1.0, 1.5, 0.7))]


def build(b):
    # ---- the body: flat and wide, a murk back mottled with basalt over a pale underside
    b.part(blob(1.0, (0, 0.6, 0.85), scale=(1.5, 1.9, 0.7), segs=14, rings=7, noise=0.03, seed=71), "Body", "murk")
    b.part(blob(1.0, (0, 0.6, 0.55), scale=(1.4, 1.8, 0.42), segs=12, rings=5, seed=72), "Body", "sandstone")
    b.part(blob(1.0, (0, -1.1, 0.95), scale=(1.45, 1.2, 0.74), segs=12, rings=7, noise=0.03, seed=73), "Chest", "murk")
    b.part(blob(1.0, (0, -1.1, 0.6), scale=(1.34, 1.1, 0.42), segs=10, rings=5, seed=74), "Chest", "sandstone")
    for i, (x, y, r) in enumerate(((0.5, -0.2, 0.34), (-0.6, 0.5, 0.4), (0.4, 1.2, 0.36), (-0.3, -1.0, 0.3), (0.75, 0.6, 0.26),
                                   (-0.8, -0.5, 0.24), (0.2, 1.9, 0.26), (0.7, -1.3, 0.24))):
        bone = "Chest" if y < -0.5 else "Body"
        b.part(blob(r, (x, y, 1.42 - abs(x) * 0.22 - abs(y - 0.3) * 0.06), scale=(1.2, 1.5, 0.3), segs=5, rings=3,
                    seed=80 + i), bone, "basalt")
    # the skin frill along each flank: a wavy plum skirt that hides its edge in water
    for sx in (-1, 1):
        edge = [(sx * 1.25, -1.9, 0.75), (sx * 1.45, -1.0, 0.72), (sx * 1.5, 0.0, 0.7), (sx * 1.5, 1.0, 0.68),
                (sx * 1.2, 2.1, 0.66)]
        skirt = [(sx * 1.5, -2.0, 0.3), (sx * 2.0, -1.1, 0.12), (sx * 1.85, -0.1, 0.3), (sx * 2.15, 0.9, 0.1),
                 (sx * 1.5, 2.3, 0.22)]
        b.part(web(edge[:3], skirt[:3], 0.05), "Chest", "plum")
        b.part(web(edge[2:], skirt[2:], 0.05), "Body", "plum")
        for i, y in enumerate((-0.6, 0.0, 0.6, 1.2)):                         # a lateral line of small lights
            b.glow(sf.sphere(0.07, loc=(sx * (1.36 - 0.03 * i), y, 1.0), segs=5, rings=3), "Body", "BodyGlow")
    # the back fin, low, from shoulders to tail
    ridge = [(0, -0.9, 1.66), (0, 0.0, 1.55), (0, 1.0, 1.45), (0, 1.9, 1.2)]
    crest = [(0, -0.8, 1.84), (0, 0.2, 2.05), (0, 1.2, 1.95), (0, 2.1, 1.48)]
    b.part(web(ridge[:2], crest[:2], 0.05), "Chest", "plum")
    b.part(web(ridge[1:], crest[1:], 0.05), "Body", "plum")
    for base, tip in zip(ridge[1:3], crest[1:3]):
        b.part(spike((base[0], base[1], base[2] - 0.1), (0, 0.25, 1), 0.66, 0.05, verts=3), "Body", "basalt")

    # ---- the head: broad, flat, blind; the mouth runs ear to ear
    b.part(blob(1.0, (0, -2.75, 1.0), scale=(1.5, 1.3, 0.46), segs=14, rings=6, noise=0.025, seed=75), "Head", "murk")
    b.part(blob(0.6, (0, -3.75, 0.96), scale=(1.5, 0.8, 0.4), segs=10, rings=5, seed=76), "Head", "murk")
    for sx in (-1, 1):
        # milky blind eyes under heavy lids; nothing in them
        b.part(sf.sphere(0.2, loc=(sx * 0.95, -3.2, 1.3), segs=8, rings=5), "Head", "cream")
        b.part(shell((0.27, 0.27, 0.25), (sx * 0.95, -3.18, 1.32), -1.0, 1.0, z_from=0.1, thickness=0.05, segs=8, rings=5),
               "Head", "basalt")
        b.part(sf.sphere(0.06, loc=(sx * 0.3, -4.22, 1.06), segs=5, rings=3), "Head", "basalt")
        # barbels trailing from the corners of the mouth
        b.part(limb([(sx * 1.35, -3.1, 0.8), (sx * 1.95, -3.5, 0.6), (sx * 2.2, -4.2, 0.2)], [0.07, 0.05, 0.02], sides=4,
                    resolution=2), "Head", "plum")
        b.part(limb([(sx * 0.6, -4.1, 0.82), (sx * 0.8, -4.7, 0.6), (sx * 0.7, -5.2, 0.25)], [0.05, 0.04, 0.015], sides=4,
                    resolution=2), "Head", "plum")
    for i, p in enumerate(B.arc((0, -2.9, 0.86), 1.3, 198, 342, 17)):          # needle teeth, long and uneven
        p = sf.Vector((p.x * 1.08, -2.9 + (p.y + 2.9) * 1.02, 0.88))
        b.part(spike(p, (-p.x * 0.05, 0.12, -1), 0.34 if i % 3 == 0 else 0.2, 0.045, verts=3), "Head", "cream")
    # ---- the jaw
    b.part(blob(1.0, (0, -2.9, 0.6), scale=(1.44, 1.3, 0.2), segs=12, rings=4, seed=77), "Jaw", "sandstone")
    b.part(shell((1.5, 1.36, 0.26), (0, -2.9, 0.56), -1.0, 0.5, z_from=-1.0, thickness=0.04, segs=12, rings=4),
           "Jaw", "murk")
    for i, p in enumerate(B.arc((0, -2.9, 0.7), 1.28, 204, 336, 13)):
        p = sf.Vector((p.x * 1.04, -2.9 + (p.y + 2.9) * 1.0, 0.7))
        b.part(spike(p, (-p.x * 0.04, 0.08, 1), 0.38 if i % 2 == 0 else 0.22, 0.05, verts=3), "Jaw", "cream")
    b.glow(blob(0.7, (0, -2.6, 0.66), scale=(1.3, 1.0, 0.16), segs=8, rings=4, seed=78), "Jaw", "JawGlow")

    # ---- the lure: a stalk from the brow, bent forward, a glowing bulb and its trailing threads
    b.part(limb([LURE[0], (0, -2.3, 2.6), LURE[1]], [0.12, 0.09, 0.07], sides=6, resolution=2), "Lure1", "basalt")
    b.part(limb([LURE[1], (0, -3.6, 3.2), LURE[2]], [0.07, 0.055, 0.045], sides=6, resolution=2), "Lure2", "basalt")
    bulb = sf.Vector(LURE[2]) + sf.Vector((0, -0.2, -0.22))
    b.glow(blob(0.3, bulb, scale=(0.9, 0.9, 1.25), segs=8, rings=6, seed=79), "Lure2", "LureGlow")
    b.part(sf.torus(0.2, 0.06, loc=bulb + sf.Vector((0, 0, 0.28)), major_segs=8, minor_segs=3), "Lure2", "plum")
    for dx, dy, ln in ((0.14, 0.0, 0.7), (-0.14, 0.05, 0.6), (0.0, -0.16, 0.85)):
        root = bulb + sf.Vector((dx, dy, -0.3))
        vein(b, "Lure2", [root, root + sf.Vector((dx * 0.6, dy, -ln * 0.5)), root + sf.Vector((dx * 0.2, dy * 2, -ln))],
             0.03, "LureGlow")

    # ---- the arms: up to a spined elbow, down and forward to a three-hooked hand
    for side, sx in SIDES:
        sh = sf.Vector((sx * SHOULDER[0], SHOULDER[1], SHOULDER[2]))
        el = sf.Vector((sx * ELBOW[0], ELBOW[1], ELBOW[2]))
        wr = sf.Vector((sx * WRIST[0], WRIST[1], WRIST[2]))
        b.part(blob(0.5, sh, scale=(1, 1.1, 0.9), segs=8, rings=5, seed=90), f"{side}Arm", "murk")
        b.part(limb([sh, (sh + el) / 2 + sf.Vector((sx * 0.2, 0.15, 0.1)), el], [0.36, 0.3, 0.22], sides=8, resolution=2),
               f"{side}Arm", "murk")
        b.part(spike(el - sf.Vector((0, 0, 0.1)), (sx * 0.3, 0.5, 1), 0.6, 0.11, verts=4), f"{side}Arm", "basalt")
        b.part(blob(0.26, el, segs=6, rings=4, seed=91), f"{side}Fore", "basalt")
        b.part(limb([el, (el + wr) / 2 + sf.Vector((sx * 0.12, 0, 0.12)), wr], [0.22, 0.2, 0.15], sides=8, resolution=2),
               f"{side}Fore", "murk")
        # a web of skin in the crook of the arm
        b.part(web([sh, sh + (el - sh) * 0.5, el], [sh, sh + (el - sh) * 0.5 + sf.Vector((0, -0.7, -0.5)),
                                                    el + (wr - el) * 0.35], 0.04), f"{side}Arm", "plum")
        for k in (0.3, 0.55, 0.8):                                           # spines along the forearm
            at = el + (wr - el) * k
            b.part(spike(at, (sx * 0.2, 0.3, 1), 0.3, 0.05, verts=3), f"{side}Fore", "basalt")
        # the hand: a knuckle and three long hooks, the middle one longest
        b.part(blob(0.22, wr, scale=(1.1, 1.2, 0.9), segs=6, rings=4, seed=92), f"{side}Claw", "murk")
        for dx, ln in ((0.3, 1.45), (0.0, 1.8), (-0.3, 1.4)):
            b.part(claw(wr + sf.Vector((sx * dx * 0.5, -0.1, 0)), (sx * dx * 0.4 - sx * 0.25, -1.0, -0.62), ln, 0.1,
                        bend=(0, 0.35, -1), curl=0.42, sides=4, resolution=2), f"{side}Claw", "cream")
        b.part(claw(wr + sf.Vector((-sx * 0.1, 0.1, -0.05)), (-sx * 0.9, -0.3, -0.5), 0.8, 0.08, bend=(0, -0.5, -1),
                    curl=0.5, sides=4), f"{side}Claw", "cream")                # the thumb hook

    # ---- the tail: three bones, a fin above and below, ending in a ragged paddle
    spine = [(0, 1.9, 0.78), (0, 2.7, 0.7), (0, 3.5, 0.62), (0, 4.3, 0.55), (0, 5.0, 0.5), (0, 5.9, 0.46), (0, 6.9, 0.5)]
    radii = [0.72, 0.6, 0.48, 0.38, 0.3, 0.2, 0.05]
    for bone, i0, i1 in (("Tail1", 0, 2), ("Tail2", 2, 4), ("Tail3", 4, 6)):
        pts, rr = spine[i0:i1 + 1], radii[i0:i1 + 1]
        seg = limb(pts, rr, sides=8, resolution=1)
        seg.scale = (1.5, 1, 0.82) if bone == "Tail1" else (1.2, 1, 0.9)
        b.part(seg, bone, "murk")
        top = [(0, p[1], p[2] + r * 0.7) for p, r in zip(pts, rr)]
        tips = [(0, p[1] + 0.25, p[2] + r * 0.7 + 0.42 + 0.2 * math.sin(p[1] * 2.2)) for p, r in zip(pts, rr)]
        low = [(0, p[1], p[2] - r * 0.6) for p, r in zip(pts, rr)]
        lows = [(0, p[1] + 0.2, max(0.03, p[2] - r * 0.6 - 0.3)) for p, r in zip(pts, rr)]
        b.part(web(top, tips, 0.04), bone, "plum")
        if bone != "Tail1":
            b.part(web(low, lows, 0.04), bone, "plum")
        for sx in (-1, 1):
            b.glow(sf.sphere(0.055, loc=(sx * rr[1] * (1.4 if bone == "Tail1" else 1.1), pts[1][1], pts[1][2] + 0.05),
                             segs=5, rings=3), bone, f"{bone}Glow")
    # ---- small hind legs, splayed, more fin than foot
    for side, sx in SIDES:
        hip = sf.Vector((sx * 1.0, 1.5, 0.7))
        foot = sf.Vector((sx * 2.0, 2.1, 0.08))
        b.part(limb([hip, (hip + foot) / 2 + sf.Vector((sx * 0.1, -0.1, 0.25)), foot], [0.3, 0.22, 0.12], sides=6,
                    resolution=2), f"{side}Leg", "murk")
        toes = [foot + sf.Vector((sx * 0.55 * c, 0.55 * s, -0.03)) for c, s in ((1.0, -0.3), (0.85, 0.5), (0.2, 0.95))]
        for t in toes:
            b.part(spike(foot, t - foot, (t - foot).length * 1.15, 0.06, verts=3), f"{side}Leg", "cream")
        b.part(web([foot] * 3, toes, 0.03), f"{side}Leg", "plum")


def arms(b, f, left, right=None, ease="SINE"):
    """Each arm: (upper swing, upper spread, forearm, hand) in degrees. Upper swing forward is +,
    spread outward is +, the forearm opens with +, the hand curls in with +."""
    right = right or left
    for side, sx, (swing, spread, fore, hand) in (("Left", 1, left), ("Right", -1, right)):
        b.key(f"{side}Arm", f, (swing, 0, sx * spread), ease=ease)
        b.key(f"{side}Fore", f, (-fore, 0, 0), ease=ease)
        b.key(f"{side}Claw", f, (hand, 0, 0), ease=ease)


def tail(b, f, sway, ease="SINE"):
    b.key("Tail1", f, (0, sway * 8, 0), ease=ease)
    b.key("Tail2", f, (0, sway * 14, 0), ease=ease)
    b.key("Tail3", f, (0, sway * 20, 0), ease=ease)


def lure(b, f, nod, side=0.0):
    b.key("Lure1", f, (nod, side, 0))
    b.key("Lure2", f, (nod * 1.4, side * 1.5, 0))


def idle(b):
    """Flat and still: only the lure moves much."""
    act = sf.new_action(b.arm, "Idle", 0, 90, loop=True, priority="Idle")
    for f, k, s in ((0, 0, 0), (22, 1, 1), (45, 0, 0), (67, 1, -1), (90, 0, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, -0.12 + 0.03 * k, 0))
        b.key("Chest", f, (3 - k, 0, 0))
        b.key("Head", f, (2, 0, 0))
        b.key("Jaw", f, (3 + 3 * k, 0, 0))
        lure(b, f, -6 + 10 * k, 9 * s)
        tail(b, f, 0.5 * s)
        arms(b, f, (-6, 4, -4, 6 * k))
    return act


def walk(b):
    """It drags itself: one arm reaches and plants, the body follows, the tail snakes."""
    act = sf.new_action(b.arm, "Walk", 0, 36, loop=True, priority="Movement")
    reach, plant, pull = (34, 10, 42, -14), (22, 4, 24, 16), (-14, 2, -10, 24)
    for f, left, right, sway in ((0, reach, pull, 1), (9, plant, reach, 0.2), (18, pull, reach, -1), (27, reach, plant, -0.2),
                                 (36, reach, pull, 1)):
        arms(b, f, left, right)
        b.key("Body", f, (0, 5 * sway, 0), loc=(0, 0.1 * abs(sway), 0))
        b.key("Chest", f, (-6, -7 * sway, 3 * sway))
        b.key("Head", f, (4, -5 * sway, 0))
        b.key("Jaw", f, (8, 0, 0))
        tail(b, f, -sway * 1.6)
        lure(b, f, 6 * abs(sway), -8 * sway)
        b.key("LeftLeg", f, (0, 14 * sway, 0))
        b.key("RightLeg", f, (0, 14 * sway, 0))
    return act


def attack(b):
    """It rears, the arms cock back, then shoot out and close on whoever is there (0.5 s)."""
    act = sf.new_action(b.arm, "Attack", 0, 34, loop=False, priority="Action")
    b.rest(0)
    arms(b, 0, (-6, 4, -4, 0))
    b.key("Chest", 8, (-30, 0, 0), ease="QUAD")                         # rears, arms cocked wide
    b.key("Head", 8, (-10, 0, 0))
    b.key("Jaw", 8, (30, 0, 0))
    arms(b, 8, (-28, 26, -30, -30), ease="QUAD")
    lure(b, 8, -30)
    tail(b, 8, 0.6)
    b.key("Body", 8, (0, 0, 0), loc=(0, 0.2, -0.3))
    b.key("Chest", 15, (4, 0, 0), ease="QUAD")                          # the strike lands (0.5 s)
    b.key("Head", 15, (8, 0, 0))
    b.key("Jaw", 15, (44, 0, 0))
    arms(b, 15, (58, -2, 72, 10), ease="QUAD")
    b.key("Body", 15, (0, 0, 0), loc=(0, 0.1, 0.7), ease="QUAD")
    lure(b, 15, 24)
    arms(b, 19, (50, -14, 60, 48))                                      # the hooks close
    b.key("Jaw", 20, (6, 0, 0))
    arms(b, 26, (20, -6, 26, 30))
    b.key("Body", 26, (0, 0, 0), loc=(0, 0.05, 0.2))
    b.rest(34)
    arms(b, 34, (-6, 4, -4, 0))
    return act


def latched(b):
    """It has someone: the arms hold them close and the head worries at them."""
    act = sf.new_action(b.arm, "Latched", 0, 24, loop=True, priority="Action")
    for f, k in ((0, 0), (6, 1), (12, 0), (18, -1), (24, 0)):
        arms(b, f, (40 + 3 * abs(k), -14, 46, 46))
        b.key("Body", f, (0, 0, 0), loc=(0, 0.1, 0.3))
        b.key("Chest", f, (-8 + 4 * abs(k), 5 * k, 0))
        b.key("Head", f, (6 + 8 * abs(k), 8 * k, 6 * k))
        b.key("Jaw", f, (34 - 26 * abs(k), 0, 0))
        tail(b, f, 1.2 * k)
        lure(b, f, 18, 10 * k)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("Lurker", JOINTS), build,
          lambda b: [idle(b), walk(b), attack(b), latched(b)],
          budget=4000, hrp_center=(0, 0.3, 0.9), hrp_size=(2.6, 1.4, 4.0), step="A8",
          meta={"role": "Ambusher", "band": "FloodedCaverns", "hitTime": HIT_TIME},
          sockets={"Grab": ((0, -6.2, 1.2), 0.0), "Lure": (tuple(LURE[2]), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
