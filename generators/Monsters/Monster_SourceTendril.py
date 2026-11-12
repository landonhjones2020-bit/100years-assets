"""Monster_SourceTendril: one arm of the Source (bible Section 10, the Source's fight: "tendrils in
many rooms at once, then the core, so the team has to split up and regroup"). It breaks up through
a room's floor and stays where it came up: a thick plum trunk in an S, armoured down its back
with basalt scutes and bone thorns, veined with the Source's light, ending in three hooks
around an eye like the ones the cutscene shows opening in the dark. It sways, turns to whoever
is near, rears and comes down like a tree.

About 10.5 studs tall at rest and 3.6 across its crater; its slam lands 8 to 9 studs in front.

Rig: Body (the crater, root), Seg1 to Seg7 up the trunk, Tip (the hooks' hub) and three Hooks.
Clips: Rise (it comes up out of the floor: 1.5 s, once), Idle (a slow travelling sway), Attack
(rears, then slams forward: Hit at 0.55 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_SourceTendril.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, limb, blob, shard, claw  # noqa: E402,F401

ASSET, CATEGORY = "Monster_SourceTendril", "Monsters"
HIT_TIME = 0.55
RISE_DEPTH = 11.0

# the trunk's spine at rest: an S, leaning toward the front (-Y) at the top
SPINE = [(0.0, 0.0, 0.35), (0.0, 0.30, 1.9), (0.0, 0.42, 3.5), (0.0, 0.22, 5.0), (0.0, -0.32, 6.4), (0.0, -1.0, 7.6),
         (0.0, -1.85, 8.55), (0.0, -2.75, 9.2)]
RADII = [1.28, 1.14, 1.0, 0.88, 0.76, 0.64, 0.52, 0.42]
SEGS = [f"Seg{i + 1}" for i in range(7)]
HOOKS = [("Hook1", math.radians(90)), ("Hook2", math.radians(210)), ("Hook3", math.radians(330))]
TIP = sf.Vector(SPINE[7])
TIP_DIR = (sf.Vector(SPINE[7]) - sf.Vector(SPINE[6])).normalized()

JOINTS = [("Body", None, (0, 0, 0.6))] \
    + [(name, "Body" if i == 0 else SEGS[i - 1], SPINE[i]) for i, name in enumerate(SEGS)] \
    + [("Tip", "Seg7", tuple(TIP))] \
    + [(name, "Tip", tuple(TIP + TIP_DIR * 0.25)) for name, _a in HOOKS]


def frame(direction):
    """Two unit vectors square to `direction` (side, back): side is world X where it can be."""
    d = sf.Vector(direction).normalized()
    side = sf.Vector((1, 0, 0))
    back = d.cross(side).normalized()        # for a trunk going up: +Y, the tendril's back
    if back.y < 0:
        back = -back
    return side, back


def build(b):
    rnd = random.Random(25)

    # ---- the crater: floor slabs tipped up around the hole, rubble, and root-threads feeling out
    b.part(blob(1.55, (0, 0, 0.0), scale=(1.0, 1.0, 0.3), segs=10, rings=5, noise=0.06, seed=4), "Body", "rubber")   # the dark it comes out of
    for i in range(9):
        a = math.tau * i / 9 + rnd.uniform(-0.12, 0.12)
        r = rnd.uniform(1.75, 2.05)
        w, ln = rnd.uniform(0.95, 1.35), rnd.uniform(1.0, 1.5)
        slab = sf.box((w, ln, 0.26), loc=(math.cos(a) * r, math.sin(a) * r, 0.24 + rnd.uniform(0, 0.12)), bevel=0.03, segments=1)
        slab.rotation_euler = (math.radians(rnd.uniform(24, 46)), 0, a - math.pi / 2)
        b.part(slab, "Body", "stone" if i % 3 else "ash")
    for i in range(7):
        a = math.tau * (i + 0.5) / 7 + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(2.3, 2.9)
        b.part(blob(rnd.uniform(0.2, 0.34), (math.cos(a) * r, math.sin(a) * r, 0.14), scale=(1.2, 0.9, 0.7), segs=5, rings=3,
                    noise=0.2, seed=40 + i), "Body", "basalt" if i % 2 else "stone")
    for i in range(6):                                                                       # root-threads
        a = math.tau * i / 6 + 0.4 + rnd.uniform(-0.2, 0.2)
        c, s = math.cos(a), math.sin(a)
        pts = [(c * 0.9, s * 0.9, 0.5), (c * 1.7, s * 1.7, 0.75), (c * 2.5 - s * 0.3, s * 2.5 + c * 0.3, 0.3),
               (c * 3.1 - s * 0.6, s * 3.1 + c * 0.6, 0.06)]
        b.part(limb(pts, [0.2, 0.16, 0.11, 0.05], sides=5, resolution=1), "Body", "plum" if i % 2 else "basalt")
    b.glow(sf.torus(1.18, 0.07, loc=(0, 0, 0.3), major_segs=14, minor_segs=3), "Body", "CraterGlow")      # light coming up round it

    # ---- the trunk: seven lengths, each lapping the next, a knuckle at every joint
    for i, name in enumerate(SEGS):
        p0, p1 = sf.Vector(SPINE[i]), sf.Vector(SPINE[i + 1])
        d = (p1 - p0).normalized()
        side, back = frame(d)
        r0, r1 = RADII[i], RADII[i + 1]
        swatch = "plum" if i % 2 == 0 else "basalt"
        start = p0 - d * (0.9 if i == 0 else 0.22)                                          # the first goes down into the dark
        b.part(limb([start, p0 + d * (p1 - p0).length * 0.5 + back * 0.05, p1 + d * 0.2], [r0, (r0 + r1) / 2 * 1.04, r1],
                    sides=8, resolution=2), name, swatch)
        b.part(blob(r0 * 1.06, p0, scale=(1.0, 1.0, 0.62), segs=8, rings=4, noise=0.05, seed=60 + i), name, "plum" if i % 2 else "basalt")
        # scutes down its back: two overlapping plates a length
        for k in range(2):
            at = p0 + d * (p1 - p0).length * (0.28 + 0.44 * k) + back * ((r0 + r1) / 2 * 0.86)
            plate = blob((r0 + r1) / 2 * 0.74, at, scale=(1.0, 0.36, 0.62), segs=7, rings=4, noise=0.06, seed=80 + i * 2 + k)
            plate.rotation_euler = (math.atan2(-d.y, d.z) + math.radians(14), 0, 0)
            b.part(plate, name, "rubber" if (i + k) % 2 else "gunmetal")
        # thorns: a pair off the back of each length, longer low down
        ln = 0.95 - i * 0.07
        for sx in (-1, 1):
            base = p0 + d * (p1 - p0).length * 0.55 + back * ((r0 + r1) / 2 * 0.8) + side * sx * ((r0 + r1) / 2 * 0.55)
            b.part(shard(base, back * 1.0 + side * sx * 0.75 + d * 0.5, ln, 0.13 - i * 0.008, sides=4, tip=0.06, waist=0.2),
                   name, "cream")
        # veins of the Source's light up its flanks
        for sx in (-1, 1):
            a0 = p0 + side * sx * (r0 * 0.93) - back * (r0 * 0.25)
            a1 = (p0 + p1) / 2 + side * sx * ((r0 + r1) / 2 * 1.0) - back * 0.05 + d * (0.1 * sx)
            a2 = p1 + side * sx * (r1 * 0.93) - back * (r1 * 0.25)
            b.glow(limb([a0, a1, a2], [0.055, 0.07, 0.05], sides=3, resolution=1), name, "VeinGlow")
        # pale sucker pads down its belly (the front), two rows, so the S reads from the room
        if i < 6:
            for k in range(2):
                for sx in (-1, 1):
                    rr = (r0 + r1) / 2
                    at = p0 + d * (p1 - p0).length * (0.26 + 0.44 * k + 0.1 * sx) - back * (rr * 0.86) + side * sx * (rr * 0.42)
                    pad = blob(rr * 0.27, at, scale=(1.0, 0.45, 1.0), segs=5, rings=3, seed=3)
                    pad.rotation_euler = (math.atan2(-d.y, d.z), 0, math.radians(-24 * sx))
                    b.part(pad, name, "blush")

    # ---- the tip: a hub, an eye looking where it leans, three hooks around it
    side, back = frame(TIP_DIR)
    b.part(blob(0.62, TIP + TIP_DIR * 0.12, scale=(1.0, 1.0, 0.85), segs=9, rings=6, noise=0.05, seed=7), "Tip", "basalt")
    rim = sf.torus(0.5, 0.11, loc=TIP + TIP_DIR * 0.52, major_segs=10, minor_segs=4)
    rim.rotation_euler = TIP_DIR.to_track_quat("Z", "Y").to_euler()
    b.part(rim, "Tip", "rubber")
    eye = sf.sphere(0.45, loc=TIP + TIP_DIR * 0.5, segs=9, rings=6)
    b.glow(eye, "Tip", "EyeGlow")
    pupil = sf.box((0.12, 0.16, 0.62), loc=TIP + TIP_DIR * 0.9, bevel=0.02, segments=1)
    pupil.rotation_euler = TIP_DIR.to_track_quat("Y", "Z").to_euler()
    b.part(pupil, "Tip", "rubber")
    for name, a in HOOKS:
        radial = (side * math.cos(a) + back * math.sin(a)).normalized()
        root = TIP + TIP_DIR * 0.25 + radial * 0.55
        b.part(blob(0.26, root, segs=6, rings=4, seed=9), name, "plum")
        b.part(claw(root, radial * 0.9 + TIP_DIR * 0.7, 1.9, 0.23, bend=TIP_DIR * 1.0 - radial * 1.1, curl=0.55, sides=5, resolution=2),
               name, "cream")


def hook_rot(a, open_deg):
    """Bone-space Euler opening a hook at ring angle `a` outward by open_deg."""
    return (open_deg * math.sin(a), 0, -open_deg * math.cos(a))


def pose(b, f, bends, sway=None, hooks=0.0, ease="SINE"):
    """Key the trunk: bends[i] degrees forward at Seg i+1, sway[i] sideways."""
    for i, name in enumerate(SEGS):
        b.key(name, f, (bends[i], 0, (sway[i] if sway else 0)), ease=ease)
    for name, a in HOOKS:
        b.key(name, f, hook_rot(a, hooks), ease=ease)


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 96, loop=True, priority="Idle")
    for f in range(0, 97, 8):
        t = f / 96.0
        bends = [3.5 * math.sin(math.tau * (t - i * 0.09)) for i in range(7)]
        sway = [4.5 * math.sin(math.tau * (t - i * 0.11) + 1.2) * (0.5 + i * 0.12) for i in range(7)]
        pose(b, f, bends, sway, hooks=8 + 8 * math.sin(math.tau * t * 2))
        b.key("Tip", f, (6 * math.sin(math.tau * t * 2), 10 * math.sin(math.tau * t), 0))
    return act


def attack(b):
    """Rears back and up, then comes down flat in front of it; the hooks open as it falls."""
    act = sf.new_action(b.arm, "Attack", 0, 38, loop=False, priority="Action")
    b.rest(0)
    pose(b, 9, [-7, -9, -10, -11, -12, -10, -8], hooks=34)                    # rears, hooks wide
    b.key("Tip", 9, (-16, 0, 0))
    pose(b, 13, [-8, -10, -11, -12, -13, -11, -9], hooks=38)                  # hangs there a beat
    b.key("Tip", 13, (-18, 0, 0))
    pose(b, 16, [12, 16, 17, 16, 12, 6, 2], hooks=10, ease="QUAD")            # the slam: Hit at 0.55 s (frame 16.5)
    b.key("Tip", 16, (10, 0, 0), ease="QUAD")
    pose(b, 18, [13, 17, 18, 17, 13, 7, 3], hooks=-4)                         # bites the floor
    b.key("Tip", 18, (14, 0, 0))
    pose(b, 24, [11, 15, 16, 15, 11, 6, 2], hooks=-2)                         # lies there
    b.key("Tip", 24, (10, 0, 0))
    pose(b, 32, [3, 4, 4, 3, 2, 1, 0], hooks=14)                              # drags itself back up
    b.key("Tip", 32, (-4, 0, 0))
    b.rest(38)
    return act


def rise(b):
    """Up out of the floor: the whole trunk comes from below, overshoots, shakes the dust off."""
    act = sf.new_action(b.arm, "Rise", 0, 45, loop=False, priority="Action")
    b.rest(0)
    b.key("Seg1", 0, (0, 0, 0), loc=(0, -RISE_DEPTH, 0))
    pose(b, 0, [0, 0, 6, 10, 14, 16, 12], hooks=-6)                           # hooks shut, bowed like a shoot
    b.key("Seg1", 0, (0, 0, 0), loc=(0, -RISE_DEPTH, 0))
    b.key("Seg1", 6, (0, 0, 0), loc=(0, -RISE_DEPTH * 0.86, 0))               # the floor heaves first
    b.key("Seg1", 20, (-4, 0, 0), loc=(0, 0.5, 0), ease="QUAD")               # then it is through
    pose(b, 20, [-4, -5, -4, -2, 2, 6, 6], hooks=30, ease="QUAD")
    b.key("Seg1", 20, (-4, 0, 0), loc=(0, 0.5, 0), ease="QUAD")
    for f, k in ((26, 1), (31, -1), (36, 0.5)):                               # shakes
        pose(b, f, [2 * k, 3 * k, 2 * k, 0, -2 * k, -3 * k, -2 * k], [5 * k, 7 * k, 8 * k, 8 * k, 7 * k, 5 * k, 3 * k], hooks=20 - 8 * k)
        b.key("Seg1", f, (2 * k, 0, 5 * k), loc=(0, 0, 0))
    b.rest(45)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("SourceTendril", JOINTS), build, lambda b: [idle(b), attack(b), rise(b)],
          budget=4000, hrp_center=(0, 0, 1.0), hrp_size=(2.4, 2.0, 2.4), step="A10",
          meta={"role": "Boss", "band": "SourceChamber", "hitTime": HIT_TIME, "riseTime": 1.5},
          sockets={"Slam": ((0, -8.5, 0.4), 0.0), "Eye": (tuple(TIP + TIP_DIR * 0.7), 0.0)},
          markers={"Attack": {"Hit": HIT_TIME}}, pivot=(0, 0, 0))
