"""Monster_TideCrab: the Flooded Caverns tank (bible Section 10: "Armoured front, weak point
on its back"). A cave crab as wide as a doorway that walks at you front on, behind two shield
claws it holds together like a boxer's guard: rust-red plate crusted with barnacles, a spiked
brow, two eyes on stalks peering over the top. Nothing gets through the front. Round the back
the shell has split around the Source growth that made it this big, and the soft glowing
sacs between the plates are where it dies. Scary, never gory.

About 10 studs across the legs, 8 long and 4.6 high.

Rig: Body (root), two eye stalks, two three-bone claws (Arm, Claw, Pincer), six one-bone
legs. Clips: Idle (guard up, breathing), Walk (a heavy six-legged march), Attack (the right
claw lifts and hammers down, Hit at 0.55 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_TideCrab.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, shell, eye, vein, web  # noqa: E402,F401

ASSET, CATEGORY = "Monster_TideCrab", "Monsters"
HIT_TIME = 0.55
SIDES = (("Left", 1), ("Right", -1))
C = sf.Vector((0, 0.4, 2.1))                 # the body's middle
LEG_Y = (-0.7, 0.5, 1.7)
JOINTS = [("Body", None, tuple(C))]
for _side, _sx in SIDES:
    JOINTS += [(f"{_side}Eye", "Body", (_sx * 0.7, -1.7, 2.9)),
               (f"{_side}Arm", "Body", (_sx * 2.0, -1.3, 1.9)),
               (f"{_side}Claw", f"{_side}Arm", (_sx * 3.1, -2.7, 2.3)),
               (f"{_side}Pincer", f"{_side}Claw", (_sx * 1.9, -4.0, 3.2))]
    for _i, _y in enumerate(LEG_Y, 1):
        JOINTS.append((f"{_side}Leg{_i}", "Body", (_sx * 2.2, _y, 1.7)))


def barnacles(b, bone, spots, seed=0):
    """Clusters of little pale cones, each with a dark mouth."""
    for i, (x, y, z, r, d) in enumerate(spots):
        d = sf.Vector(d).normalized()
        o = sf.cyl(r, r * 1.3, loc=sf.Vector((x, y, z)) + d * r * 0.4, verts=6, radius_top=r * 0.5, bevel=0.0)
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        b.part(o, bone, "sandstone")


def build(b):
    # ---- the body: a murk underside under a rust carapace that covers the front two thirds
    b.part(blob(1.0, C + sf.Vector((0, 0, -0.3)), scale=(2.7, 2.5, 0.95), segs=14, rings=7, noise=0.02, seed=101),
           "Body", "murk")
    b.part(blob(1.0, C + sf.Vector((0, 0.1, -0.75)), scale=(2.3, 2.1, 0.55), segs=12, rings=5, seed=102), "Body", "sandstone")
    b.part(shell((3.05, 2.85, 1.85), C, -1.0, 0.18, z_from=-0.12, thickness=0.2, segs=14, rings=8), "Body", "rust")
    b.part(shell((3.12, 2.9, 1.9), C, -0.52, -0.3, z_from=-0.1, thickness=0.16, segs=14, rings=8), "Body", "basalt")   # a dark ridge
    b.part(shell((2.9, 2.75, 1.7), C, 0.3, 0.52, z_from=0.25, thickness=0.16, segs=12, rings=6), "Body", "rust")       # a cracked plate
    b.part(shell((2.5, 2.8, 1.45), C, 0.66, 0.84, z_from=0.3, thickness=0.14, segs=10, rings=6), "Body", "basalt")
    # the brow: a row of stone spikes along the front rim, the middle ones longest
    for i, a in enumerate(range(205, 340, 15)):
        x, y = 3.0 * math.cos(math.radians(a)), C.y + 2.8 * math.sin(math.radians(a))
        k = 1 - abs(i - 4) / 6
        b.part(spike((x * 0.97, y * 0.97, 2.25), (x * 0.5, -1.0 + abs(x) * 0.2, 0.55), 0.5 + 0.55 * k, 0.16, verts=4),
               "Body", "stone")
    for (x, y, z, ln) in ((0.0, -0.9, 3.85, 0.9), (1.2, -0.3, 3.72, 0.7), (-1.2, -0.3, 3.72, 0.7), (2.1, 0.1, 3.2, 0.6),
                          (-2.1, 0.1, 3.2, 0.6), (0.6, -1.9, 3.3, 0.5), (-0.6, -1.9, 3.3, 0.5)):
        b.part(spike((x, y, z - 0.15), (x * 0.25, -0.25, 1), ln, 0.17, verts=4), "Body", "stone")
    barnacles(b, "Body", ((1.7, -1.3, 3.2, 0.2, (0.5, -0.4, 1)), (1.95, -1.05, 3.05, 0.14, (0.6, -0.3, 1)),
                          (-1.5, -1.6, 3.1, 0.18, (-0.5, -0.5, 1)), (-1.8, -0.9, 3.2, 0.22, (-0.5, -0.3, 1)),
                          (0.4, 0.2, 3.95, 0.2, (0, 0, 1)), (-0.3, -0.2, 3.98, 0.15, (0, 0, 1)),
                          (2.5, -0.6, 2.6, 0.18, (1, -0.2, 0.5)), (-2.55, -0.3, 2.6, 0.2, (-1, -0.1, 0.5))))
    # ---- the weak point: round the back the shell has split, and the sacs between the plates glow
    for i, (x, y, z, r) in enumerate(((0.0, 2.35, 2.75, 0.8), (0.95, 2.0, 2.6, 0.62), (-0.95, 2.0, 2.6, 0.62),
                                      (0.5, 2.75, 2.2, 0.5), (-0.5, 2.75, 2.2, 0.5), (0.0, 1.6, 3.2, 0.52))):
        b.glow(blob(r, (x, y, z), scale=(1, 1, 0.9), segs=7, rings=4, noise=0.05, seed=110 + i), "Body", "BackGlow")
    for sx in (-1, 1):
        b.part(limb([(sx * 0.4, 1.3, 3.5), (sx * 1.5, 2.1, 3.1), (sx * 1.7, 2.9, 2.3)], [0.14, 0.12, 0.08], sides=4,
                    resolution=2), "Body", "plum")
        b.part(limb([(sx * 1.9, 1.2, 2.9), (sx * 1.7, 2.4, 2.3), (sx * 1.0, 3.1, 1.9)], [0.12, 0.1, 0.07], sides=4,
                    resolution=2), "Body", "plum")
    b.part(limb([(0, 1.1, 3.75), (0, 2.0, 3.6), (0, 3.0, 2.6), (0, 3.2, 1.9)], [0.13, 0.11, 0.09, 0.06], sides=4,
                resolution=2), "Body", "plum")

    # ---- the face, tucked under the brow: mouthparts and two eyes on stalks
    b.part(blob(0.8, (0, -2.0, 1.75), scale=(1.4, 0.7, 0.62), segs=10, rings=5, seed=103), "Body", "murk")
    for sx in (-1, 1):
        b.part(limb([(sx * 0.35, -2.4, 1.75), (sx * 0.5, -2.8, 1.45), (sx * 0.2, -2.95, 1.15)], [0.14, 0.11, 0.05], sides=4,
                    resolution=2), "Body", "plum")
        b.part(limb([(sx * 0.8, -2.3, 1.6), (sx * 1.0, -2.7, 1.3), (sx * 0.7, -2.9, 1.0)], [0.1, 0.08, 0.04], sides=4,
                    resolution=2), "Body", "plum")
    for side, sx in SIDES:
        root = sf.Vector((sx * 0.7, -1.7, 2.9))
        tip = sf.Vector((sx * 0.95, -2.5, 4.25))
        b.part(limb([root, (root + tip) / 2 + sf.Vector((0, -0.2, 0)), tip], [0.14, 0.1, 0.09], sides=6, resolution=2),
               f"{side}Eye", "rust")
        b.part(sf.sphere(0.26, loc=tip, segs=8, rings=5), f"{side}Eye", "basalt")
        b.glow(sf.sphere(0.18, loc=tip + sf.Vector((sx * 0.03, -0.14, 0.02)), segs=8, rings=5), f"{side}Eye", f"{side}EyeGlow")

    # ---- the claws: a short thick arm to a shield as tall as the crab, held across its front
    for side, sx in SIDES:
        sh = sf.Vector((sx * 2.0, -1.3, 1.9))
        el = sf.Vector((sx * 3.1, -2.7, 2.3))
        b.part(blob(0.62, sh, segs=8, rings=5, seed=120), f"{side}Arm", "murk")
        b.part(limb([sh, (sh + el) / 2 + sf.Vector((sx * 0.2, 0, 0.15)), el], [0.6, 0.56, 0.5], sides=8, resolution=2),
               f"{side}Arm", "rust")
        b.part(spike(el + sf.Vector((sx * 0.3, 0.2, 0.2)), (sx, 0.3, 0.6), 0.7, 0.2, verts=4), f"{side}Arm", "stone")
        # the shield: the claw's palm, a thick slab leaning in toward the other one
        palm_c = sf.Vector((sx * 1.95, -3.75, 2.25))
        palm = blob(1.0, palm_c, scale=(1.5, 0.72, 1.95), segs=10, rings=6, noise=0.02, seed=121)
        palm.rotation_euler = (math.radians(-8), 0, math.radians(sx * 16))
        b.part(palm, f"{side}Claw", "rust")
        face = shell((1.62, 0.84, 2.05), palm_c, -1.0, -0.25, z_from=-0.85, thickness=0.12, segs=10, rings=8,
                     rot=(-8, 0, sx * 16))
        b.part(face, f"{side}Claw", "basalt")
        for k, (dx, dz) in enumerate(((0.55, 1.0), (-0.5, 0.7), (0.7, -0.2), (-0.6, -0.5), (0.0, 0.25), (0.15, -1.0))):
            at = palm_c + sf.Vector((sx * dx, -0.66 - 0.1 * abs(dx), dz))
            if k % 2 == 0:
                b.part(spike(at, (sx * dx * 0.3, -1, dz * 0.2), 0.5, 0.17, verts=4), f"{side}Claw", "stone")
            else:
                barnacles(b, f"{side}Claw", ((at.x, at.y + 0.1, at.z, 0.2, (0, -1, 0.1)),))
        # the fixed finger, pointing in and down, and the pincer that closes on it from above
        tip = palm_c + sf.Vector((-sx * 1.6, -0.55, -1.55))
        b.part(claw(palm_c + sf.Vector((-sx * 0.5, -0.2, -1.5)), (-sx * 1.0, -0.3, -0.25), 1.7, 0.42, bend=(0, 0, 1),
                    curl=0.3, sides=5, resolution=1), f"{side}Claw", "cream")
        hinge = sf.Vector((sx * 1.9, -4.0, 3.2))
        b.part(claw(hinge + sf.Vector((-sx * 0.3, 0, 0.35)), (-sx * 1.0, -0.4, -0.05), 2.3, 0.44, bend=(0, 0, -1), curl=0.55,
                    sides=5, resolution=2), f"{side}Pincer", "cream")
        b.part(blob(0.5, hinge + sf.Vector((0, 0, 0.3)), scale=(1.1, 0.8, 0.8), segs=8, rings=5, seed=122),
               f"{side}Pincer", "rust")
        for k in (0.3, 0.5, 0.7):                                              # teeth along the pincer's edge
            at = hinge + sf.Vector((-sx * (0.3 + 1.8 * k), -0.15 - 0.3 * k, 0.1 - 0.5 * k * k))
            b.part(spike(at, (0, 0, -1), 0.26, 0.09, verts=3), f"{side}Pincer", "cream")
        _ = tip

    # ---- six legs: up to a high knee, down to a point
    for side, sx in SIDES:
        for i, y in enumerate(LEG_Y, 1):
            spread = (i - 2) * 0.9
            hip = sf.Vector((sx * 2.2, y, 1.7))
            knee = sf.Vector((sx * 3.9, y + spread * 0.7, 3.3 - 0.15 * abs(i - 2)))
            foot = sf.Vector((sx * 5.0, y + spread * 1.3, 0.05))
            bone = f"{side}Leg{i}"
            b.part(limb([hip, (hip + knee) / 2 + sf.Vector((0, 0, 0.25)), knee], [0.36, 0.3, 0.24], sides=6, resolution=1),
                   bone, "rust")
            b.part(blob(0.3, knee, segs=5, rings=3, seed=130 + i), bone, "basalt")
            b.part(limb([knee, (knee + foot) / 2 + sf.Vector((sx * 0.35, 0, 0.1)), foot], [0.25, 0.19, 0.05], sides=6,
                        resolution=1), bone, "rust")
            b.part(spike(knee + sf.Vector((0, 0, 0.15)), (sx * 0.4, spread * 0.2, 1), 0.5, 0.1, verts=4), bone, "stone")
            b.part(spike(foot + sf.Vector((-sx * 0.12, 0, 0.5)), (sx * 0.25, 0, -1), 0.55, 0.11, verts=4), bone, "cream")


def guard(b, f, lift_l=0.0, lift_r=0.0, open_l=4.0, open_r=4.0, ease="SINE"):
    """The claws: lift raises a claw (degrees, + up and back), open parts its pincer."""
    for side, lift, opened in (("Left", lift_l, open_l), ("Right", lift_r, open_r)):
        b.key(f"{side}Arm", f, (-lift * 0.55, 0, 0), ease=ease)
        b.key(f"{side}Claw", f, (-lift * 0.45, 0, 0), ease=ease)
        b.key(f"{side}Pincer", f, (-opened, 0, 0), ease=ease)


def legs(b, f, k, lift=14):
    """A tripod march: legs 1 and 3 of one side move with leg 2 of the other."""
    for side, sx in SIDES:
        for i in (1, 2, 3):
            phase = k if (i % 2 == 1) == (sx == 1) else -k
            b.key(f"{side}Leg{i}", f, (0, sx * 12 * phase, sx * lift * max(phase, 0)))


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 80, loop=True, priority="Idle")
    for f, k, s in ((0, 0, 0), (20, 1, 1), (40, 0, 0), (60, 1, -1), (80, 0, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, 0.08 * k, 0))
        guard(b, f, 3 * k, 3 * k, 4 + 6 * k, 4 + 6 * (1 - k))
        b.key("LeftEye", f, (-6 * k, 0, 10 * s))
        b.key("RightEye", f, (-6 * (1 - k), 0, 10 * s))
        legs(b, f, 0)
    return act


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 40, loop=True, priority="Movement")
    for f, k in ((0, 1), (10, 0), (20, -1), (30, 0), (40, 1)):
        legs(b, f, k)
        b.key("Body", f, (0, 0, 2.5 * k), loc=(0, 0.1 * (1 - abs(k)), 0))
        guard(b, f, 4 * max(k, 0), 4 * max(-k, 0))
        b.key("LeftEye", f, (0, 0, -4 * k))
        b.key("RightEye", f, (0, 0, -4 * k))
    return act


def attack(b):
    """The right claw comes up and back, the pincer gaping, and hammers down (0.55 s)."""
    act = sf.new_action(b.arm, "Attack", 0, 38, loop=False, priority="Action")
    b.rest(0)
    guard(b, 0)
    b.key("Body", 11, (-9, -7, 4), loc=(0, 0.2, -0.2), ease="QUAD")
    guard(b, 11, 6, 62, 4, 34, ease="QUAD")
    b.key("RightEye", 11, (-14, 0, 0))
    b.key("LeftEye", 11, (-14, 0, 0))
    b.key("Body", 16, (9, 6, -3), loc=(0, -0.1, 0.5), ease="QUAD")       # the blow lands at frame 16.5
    guard(b, 16, 0, -26, 4, 10, ease="QUAD")
    b.key("Body", 19, (10, 6, -3), loc=(0, -0.15, 0.55))
    guard(b, 19, 0, -30, 4, -4)
    b.key("Body", 28, (2, 0, 0), loc=(0, 0, 0.15))
    guard(b, 28, 0, -6, 4, 6)
    b.rest(38)
    guard(b, 38)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("TideCrab", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.4, 2.1), hrp_size=(4.0, 2.4, 4.4), step="A8",
          meta={"role": "Tank", "band": "FloodedCaverns", "hitTime": HIT_TIME},
          sockets={"Smash": ((-1.6, -5.6, 0.2), 0.0), "Back": ((0, 2.6, 2.8), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
