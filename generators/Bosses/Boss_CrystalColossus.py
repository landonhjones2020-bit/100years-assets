"""Boss_CrystalColossus: the Era III boss (bible Section 10: "Tears out of the crystal rock. Huge,
slow and armored; flares show its weak points; its shards stun"). The rock of the Crystal
Hollows, standing up. A hunched titan of basalt slabs with crystal grown through every joint:
no neck, a helm of a head sunk between its shoulders with five small eyes burning in a slot and
a jaw of crystal teeth that hangs open on the light inside it; a back like a mountain ridge,
crowned with spires as long as a resident is tall; a left hand of three crystal talons; and for
a right arm one great crystal, a club the size of a doorway, that it drags and brings down.
Four cores sit in sockets on its chest, its shoulders and its back: dull stone until a flare
finds them, then they burn orange, and those are where it can be hurt. Scary, never gory.

About 14.6 studs to the tips of its spires (a cell is 16 high) and 14 across the arms.

Rig: Body (the hips, root), Chest, Spines (the crown on its back), Head, Jaw, LeftArm,
LeftForearm, LeftHand, RightArm, RightClub, thighs and shins. Clips: Idle, Walk, Attack (the
club comes down in front of it, Hit at 1.0 s), Volley (it braces and its spires flare: the
shards leave at 0.9 s), Roar, Stagger, Death. Parts code needs: CoreChest, CoreLeft, CoreRight
and CoreBack (role WeakPoint, raycasts hit them), socket Slam (where the club lands).

Run:  SF_EXPORT=1 python3 generators/Bosses/Boss_CrystalColossus.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Monsters"))
import _beast as B  # noqa: E402
from _beast import sf, spike, limb, blob, shard, cluster  # noqa: E402,F401

ASSET, CATEGORY = "Boss_CrystalColossus", "Bosses"
HIT_TIME = 1.0
VOLLEY_TIME = 0.9
JOINTS = [
    ("Body", None, (0, 0.3, 4.6)),
    ("Chest", "Body", (0, 0.2, 5.6)),
    ("Spines", "Chest", (0, 1.7, 10.0)),
    ("Head", "Chest", (0, -1.9, 10.0)),
    ("Jaw", "Head", (0, -2.7, 9.75)),
    ("LeftArm", "Chest", (4.6, -0.3, 10.0)),
    ("LeftForearm", "LeftArm", (6.0, -0.8, 6.6)),
    ("LeftHand", "LeftForearm", (6.3, -1.5, 3.3)),
    ("RightArm", "Chest", (-4.6, -0.3, 10.0)),
    ("RightClub", "RightArm", (-6.0, -0.8, 6.6)),
    ("LeftLeg", "Body", (2.3, 0.3, 4.4)),
    ("LeftShin", "LeftLeg", (2.6, -0.3, 2.3)),
    ("RightLeg", "Body", (-2.3, 0.3, 4.4)),
    ("RightShin", "RightLeg", (-2.6, -0.3, 2.3)),
]


def chunk(size, loc, seed, rot=(0, 0, 0), segs=7, rings=5, noise=0.16):
    """A block of rock: a coarse, knocked-about stone `size` across."""
    o = blob(0.5, (0, 0, 0), scale=size, segs=segs, rings=rings, noise=noise, seed=seed)
    o.location = loc
    o.rotation_euler = rot
    return o


def seam(b, bone, pts, r, name="SeamGlow"):
    """A crack with the crystal's light in it."""
    return b.neon(limb(pts, [r * 0.6] + [r] * (len(pts) - 2) + [r * 0.5], sides=3, resolution=1), bone, name)


def core(b, bone, name, at, facing, radius):
    """A weak point: a faceted core in a socket of stone, with crystal teeth round the rim."""
    f = sf.Vector(facing).normalized()
    at = sf.Vector(at)
    side = f.cross(sf.Vector((0, 0, 1)))
    if side.length < 0.1:
        side = f.cross(sf.Vector((1, 0, 0)))
    side.normalize()
    up = f.cross(side).normalized()
    ring = sf.torus(radius * 1.25, radius * 0.34, loc=at - f * radius * 0.25, major_segs=10, minor_segs=5)
    ring.rotation_euler = f.to_track_quat("Z", "Y").to_euler()
    b.part(ring, bone, "stone")
    bowl = blob(radius * 1.2, at - f * radius * 0.7, scale=(1, 1, 1), segs=8, rings=5, seed=3)
    b.part(bowl, bone, "rubber")
    for i in range(7):
        a = math.tau * i / 7
        out = side * math.cos(a) + up * math.sin(a)
        b.part(shard(at + out * radius * 1.3 - f * radius * 0.2, out * 0.75 + f * 0.75, radius * (0.85 + 0.25 * (i % 2)),
                     radius * 0.2, sides=4, tip=0.05), bone, "crystal")
    orb = blob(radius, at, scale=(1, 1, 1), segs=8, rings=6, noise=0.06, seed=5)
    sf.tag(orb, name, "signal", "Neon", collision="queryhull", cast_shadow=False, role="WeakPoint")
    orb["sf_bone"] = bone
    sf.bind(orb, b.arm, bone)
    return orb


def build(b):
    rnd = random.Random(75)

    # ---- the hips and legs: two pillars of stacked stone, plates over the knees, crystal toes
    b.part(chunk((5.6, 3.6, 2.6), (0, 0.3, 4.7), 2, segs=9, rings=6), "Body", "basalt", smooth_angle=None)
    b.part(chunk((3.4, 1.2, 2.0), (0, -1.5, 4.3), 3, rot=(0.2, 0, 0)), "Body", "stone", smooth_angle=None)                 # a loin plate
    b.part(chunk((2.2, 1.0, 1.6), (0, -1.7, 3.2), 4, rot=(0.1, 0, 0)), "Body", "basalt", smooth_angle=None)
    seam(b, "Body", [(-1.9, -1.72, 5.2), (-0.8, -1.95, 4.9), (0.5, -1.92, 5.05), (1.9, -1.7, 4.8)], 0.07)
    for o in cluster((0, 1.9, 4.6), (0, 1.0, 0.35), 5, 1.5, 0.3, seed=6):
        b.part(o, "Body", "crystal")
    for side, sx in (("Left", 1), ("Right", -1)):
        leg, shin = f"{side}Leg", f"{side}Shin"
        b.part(chunk((2.7, 2.9, 2.9), (sx * 2.45, 0.05, 3.4), 10 + sx, segs=9, rings=6), leg, "basalt", smooth_angle=None)  # thigh
        b.part(chunk((2.4, 1.0, 2.0), (sx * 2.55, -1.35, 3.5), 13 + sx, rot=(0.15, 0, sx * 0.1)), leg, "stone", smooth_angle=None)
        b.part(chunk((1.0, 2.2, 1.9), (sx * 3.75, 0.1, 3.5), 16 + sx), leg, "stone", smooth_angle=None)
        seam(b, leg, [(sx * 1.6, -1.42, 4.2), (sx * 2.4, -1.75, 3.6), (sx * 3.3, -1.5, 3.0)], 0.06)
        b.part(chunk((2.3, 2.5, 2.4), (sx * 2.6, -0.2, 1.5), 19 + sx, segs=9, rings=6), shin, "basalt", smooth_angle=None)
        b.part(chunk((2.1, 1.1, 1.6), (sx * 2.6, -1.4, 2.35), 22 + sx, rot=(0.25, 0, 0)), shin, "stone", smooth_angle=None)  # knee plate
        b.part(shard((sx * 2.6, -1.75, 2.6), (0, -0.7, 1.0), 1.3, 0.28, sides=5), shin, "crystal")        # knee spike
        b.part(chunk((3.0, 3.9, 1.3), (sx * 2.65, -0.7, 0.62), 25 + sx, segs=9, rings=5), shin, "stone", smooth_angle=None)  # foot
        for i, dx in enumerate((-0.95, 0.0, 0.95)):
            b.part(shard((sx * 2.65 + dx, -2.3, 0.35), (dx * 0.3, -1.0, 0.12), 1.25 - 0.2 * abs(dx), 0.36, sides=5, tip=0.08),
                   shin, "crystal")
        b.part(shard((sx * 2.65, 1.2, 0.5), (0, 1.0, 0.25), 0.9, 0.3, sides=5), shin, "crystal")          # heel spur
        for o in cluster((sx * 3.6, 0.6, 1.6), (sx * 1.0, 0.5, 0.6), 4, 1.1, 0.22, seed=28 + sx):
            b.part(o, shin, "crystal")

    # ---- the torso: a wedge of great slabs, wide at the shoulders, hunched forward
    b.part(chunk((7.4, 4.8, 4.2), (0, 0.3, 7.0), 30, segs=10, rings=7, noise=0.12), "Chest", "plum", smooth_angle=None)   # the belly mass
    b.part(chunk((10.0, 5.2, 4.4), (0, 0.1, 9.4), 31, segs=10, rings=7, noise=0.12), "Chest", "basalt", smooth_angle=None)  # the shoulders' mass
    for sx in (-1, 1):
        # breast slabs either side of the chest core, rib plates under them
        b.part(chunk((3.3, 1.5, 3.2), (sx * 2.45, -2.25, 8.9), 33 + sx, rot=(0.18, 0, sx * 0.22)), "Chest", "stone", smooth_angle=None)
        b.part(chunk((2.6, 1.2, 1.9), (sx * 2.2, -2.2, 6.75), 36 + sx, rot=(-0.1, 0, sx * 0.25)), "Chest", "basalt", smooth_angle=None)
        b.part(chunk((2.2, 1.1, 1.5), (sx * 1.7, -1.95, 5.6), 39 + sx, rot=(-0.2, 0, sx * 0.2)), "Chest", "stone", smooth_angle=None)
        # flank plates and the shoulder caps
        b.part(chunk((1.5, 3.4, 3.0), (sx * 3.9, 0.3, 7.3), 42 + sx, rot=(0, sx * 0.15, 0)), "Chest", "stone", smooth_angle=None)
        b.part(chunk((4.0, 4.4, 2.2), (sx * 4.3, -0.1, 11.0), 45 + sx, rot=(0.1, sx * 0.28, 0), segs=9, rings=6), "Chest", "stone", smooth_angle=None)
        b.part(chunk((2.6, 3.0, 1.4), (sx * 5.6, 0.1, 10.5), 48 + sx, rot=(0.0, sx * 0.7, 0)), "Chest", "basalt", smooth_angle=None)
        for o in cluster((sx * 5.2, 0.9, 11.6), (sx * 0.7, 0.4, 1.0), 5, 2.2, 0.4, seed=51 + sx):
            b.part(o, "Chest", "crystal")                                                                # shoulder spires
        seam(b, "Chest", [(sx * 0.9, -2.6, 9.9), (sx * 1.3, -2.95, 8.9), (sx * 1.05, -2.8, 6.9), (sx * 0.7, -2.4, 5.9)], 0.09)
        seam(b, "Chest", [(sx * 3.4, -2.0, 10.3), (sx * 3.9, -2.3, 9.2), (sx * 3.6, -1.9, 7.8)], 0.07)
        seam(b, "Chest", [(sx * 4.6, 0.6, 8.9), (sx * 4.75, 1.3, 7.6), (sx * 4.2, 1.6, 6.3)], 0.07)
        for i in range(4):                                                                               # crystal in the joints
            z = 6.0 + i * 1.15
            b.part(shard((sx * (3.3 + 0.15 * i), -1.9 + 0.1 * i, z), (sx * 1.0, -0.9, rnd.uniform(-0.2, 0.4)),
                         rnd.uniform(0.8, 1.3), 0.2, sides=5, twist=rnd.uniform(-1, 1)), "Chest", "crystal")
    b.part(chunk((6.6, 3.0, 5.2), (0, 2.1, 8.6), 54, segs=9, rings=6), "Chest", "basalt", smooth_angle=None)                # the back
    b.part(chunk((3.6, 1.4, 2.6), (0, 3.2, 6.6), 55, rot=(-0.2, 0, 0)), "Chest", "stone", smooth_angle=None)
    for sx in (-1, 1):
        b.part(chunk((2.4, 1.3, 2.8), (sx * 2.5, 3.0, 9.3), 56 + sx, rot=(-0.1, 0, -sx * 0.2)), "Chest", "stone", smooth_angle=None)

    # ribs of stone across the belly, a ridge of plates down the spine, crystal in every joint
    for i in range(4):
        z = 5.55 + i * 0.62
        for sx in (-1, 1):
            b.part(limb([(sx * 0.5, -2.35 - 0.05 * i, z), (sx * 1.7, -2.3, z + 0.12), (sx * 3.0, -1.6, z + 0.3)],
                        [0.2, 0.26, 0.16], sides=5, resolution=1), "Chest", "stone", smooth_angle=None)
    for i in range(5):
        b.part(chunk((2.0 - 0.15 * i, 1.0, 1.1), (0, 3.55 - 0.06 * i, 9.7 - i * 1.0), 200 + i, rot=(-0.25, 0, 0)), "Chest", "stone", smooth_angle=None)
    for i, (x, y, z, dx, dy, dz, n, ln) in enumerate(((3.2, 2.6, 7.6, 0.8, 1.0, 0.3, 5, 1.7), (-3.2, 2.6, 7.6, -0.8, 1.0, 0.3, 5, 1.7),
                                                      (2.6, 2.9, 10.2, 0.5, 1.0, 0.6, 4, 1.5), (-2.6, 2.9, 10.2, -0.5, 1.0, 0.6, 4, 1.5),
                                                      (4.3, -1.2, 6.3, 1.0, -0.5, -0.2, 4, 1.3), (-4.3, -1.2, 6.3, -1.0, -0.5, -0.2, 4, 1.3),
                                                      (1.6, 3.4, 5.6, 0.4, 1.0, -0.1, 4, 1.2), (-1.6, 3.4, 5.6, -0.4, 1.0, -0.1, 4, 1.2))):
        for o in cluster((x, y, z), (dx, dy, dz), n, ln, 0.26, seed=210 + i, sides=5):
            b.part(o, "Chest", "crystal")
    for sx in (-1, 1):
        # a second, lower pauldron under each shoulder cap
        b.part(chunk((2.6, 3.6, 1.2), (sx * 5.7, -0.2, 9.5), 220 + sx, rot=(0.0, sx * 1.0, 0)), "Chest", "stone", smooth_angle=None)
        b.part(chunk((3.0, 1.4, 1.5), (sx * 4.4, -2.3, 10.2), 223 + sx, rot=(0.35, 0, sx * 0.15)), "Chest", "basalt", smooth_angle=None)

    # ---- the four cores
    core(b, "Chest", "CoreChest", (0, -3.05, 7.9), (0, -1, 0.05), 0.95)
    core(b, "Chest", "CoreLeft", (3.7, -2.15, 11.25), (0.35, -0.75, 0.55), 0.62)
    core(b, "Chest", "CoreRight", (-3.7, -2.15, 11.25), (-0.35, -0.75, 0.55), 0.62)
    core(b, "Chest", "CoreBack", (0, 3.95, 8.6), (0, 1, 0.1), 0.85)

    # ---- the crown of spires on its back: one bone, so it can flare when it throws
    for i, (x, y, ln, r, lean) in enumerate(((0.0, 2.2, 4.7, 0.62, 0.0), (1.5, 2.0, 3.9, 0.52, 0.22), (-1.6, 2.1, 4.1, 0.54, -0.24),
                                             (2.9, 1.6, 3.0, 0.42, 0.42), (-3.0, 1.7, 3.2, 0.44, -0.44), (0.8, 3.1, 3.2, 0.46, 0.1),
                                             (-0.9, 3.2, 3.0, 0.44, -0.12), (2.1, 2.9, 2.4, 0.36, 0.34), (-2.2, 3.0, 2.5, 0.38, -0.36),
                                             (0.0, 1.2, 2.6, 0.4, 0.0))):
        b.part(shard((x, y, 10.0), (lean, 0.28 + 0.1 * (i % 3), 1.0), ln, r, twist=0.5 * i), "Spines", "crystal")
    for i, (x, y) in enumerate(((0.7, 1.6), (-0.8, 1.7), (1.9, 2.4), (-2.0, 2.5), (0.0, 3.6), (3.4, 2.3), (-3.5, 2.4))):
        b.part(shard((x, y, 10.2), (x * 0.2, 0.5, 1.0), rnd.uniform(1.2, 1.9), 0.24, sides=5, twist=0.7 * i), "Spines", "crystal")
    b.part(chunk((6.4, 2.6, 1.3), (0, 2.3, 10.5), 60, segs=9, rings=5), "Spines", "basalt", smooth_angle=None)              # the ridge they stand in
    b.neon(shard((0.0, 3.45, 14.25), (0, 0.28, 1.0), 0.42, 0.13, sides=5), "Spines", "SpineGlow")
    b.neon(shard((0.82, 2.98, 13.55), (0.22, 0.38, 1.0), 0.34, 0.11, sides=5), "Spines", "SpineGlow")
    b.neon(shard((-0.92, 3.1, 13.8), (-0.24, 0.3, 1.0), 0.34, 0.11, sides=5), "Spines", "SpineGlow")

    # ---- the head: a helm sunk between the shoulders, five eyes in a slot, a crown of spikes
    b.part(chunk((3.7, 3.2, 2.9), (0, -2.3, 10.6), 62, segs=9, rings=6, noise=0.1), "Head", "basalt", smooth_angle=None)
    b.part(chunk((4.2, 1.9, 1.3), (0, -3.25, 11.4), 63, rot=(0.42, 0, 0)), "Head", "stone", smooth_angle=None)              # the brow
    for sx in (-1, 1):
        b.part(chunk((1.1, 2.4, 2.2), (sx * 1.85, -2.8, 10.3), 64 + sx, rot=(0, 0, sx * 0.18)), "Head", "stone", smooth_angle=None)  # cheek guards
        b.part(shard((sx * 1.3, -2.2, 11.6), (sx * 0.55, -0.1, 1.0), 1.7, 0.3, sides=5), "Head", "crystal")         # horns
        b.part(shard((sx * 0.75, -2.5, 11.75), (sx * 0.25, -0.2, 1.0), 1.15, 0.22, sides=5), "Head", "crystal")
    b.part(shard((0, -2.6, 11.8), (0, -0.25, 1.0), 1.5, 0.26, sides=5), "Head", "crystal")
    b.part(sf.box((2.3, 0.5, 0.55), loc=(0, -3.72, 10.75), rot=(0.1, 0, 0), bevel=0.04, segments=1), "Head", "rubber")  # the slot
    for i, x in enumerate((-0.8, -0.4, 0.0, 0.4, 0.8)):
        r = 0.17 if i == 2 else 0.13 if i in (1, 3) else 0.1
        b.glow(sf.sphere(r, loc=(x, -3.98, 10.75 + 0.02 * (2 - abs(i - 2))), scale=(1.0, 0.6, 1.0), segs=7, rings=5),
               "Head", "HeadGlow")
    for i, x in enumerate((-1.0, -0.6, -0.2, 0.2, 0.6, 1.0)):                                            # upper teeth
        b.part(shard((x, -3.6, 10.2), (0, -0.25, -1.0), 0.55 + 0.15 * (i % 2), 0.15, sides=4, tip=0.05), "Head", "crystal")
    b.neon(blob(0.75, (0, -2.9, 9.75), scale=(1.4, 1.0, 0.55), segs=8, rings=5, seed=66), "Head", "MawGlow")  # the light in its throat

    # ---- the jaw: a slab that hangs open, crystal teeth standing up from it
    b.part(chunk((2.9, 2.4, 1.0), (0, -3.0, 9.2), 67, rot=(0.12, 0, 0), segs=8, rings=5), "Jaw", "stone", smooth_angle=None)
    b.part(chunk((1.6, 1.0, 0.9), (0, -3.9, 8.9), 68, rot=(0.3, 0, 0)), "Jaw", "basalt", smooth_angle=None)                 # chin
    for i, x in enumerate((-1.1, -0.7, -0.3, 0.1, 0.5, 0.9, 1.25)):
        b.part(shard((x - 0.08, -3.75 - 0.12 * (3 - abs(i - 3)) * 0.3, 9.45), (x * 0.08, -0.15, 1.0), 0.7 + 0.22 * (i % 2), 0.16,
                     sides=4, tip=0.05), "Jaw", "crystal")
    for sx in (-1, 1):
        b.part(shard((sx * 1.35, -3.3, 9.3), (sx * 0.5, -0.5, 1.0), 1.25, 0.24, sides=5, tip=0.05), "Jaw", "crystal")  # tusks

    # ---- the left arm: slabs to the elbow, a forearm like a pillar, a hand of three talons
    b.part(chunk((2.9, 3.0, 4.4), (5.2, -0.5, 8.3), 70, rot=(0, 0.3, 0), segs=9, rings=6), "LeftArm", "basalt", smooth_angle=None)
    b.part(chunk((1.3, 2.6, 3.0), (6.4, -0.5, 8.6), 71, rot=(0, 0.3, 0)), "LeftArm", "stone", smooth_angle=None)
    b.part(chunk((2.2, 1.2, 2.4), (5.3, -1.9, 8.4), 72, rot=(0.1, 0.3, 0)), "LeftArm", "stone", smooth_angle=None)
    seam(b, "LeftArm", [(4.6, -1.95, 9.6), (5.4, -2.2, 8.5), (5.9, -1.9, 7.2)], 0.07)
    b.part(chunk((3.0, 3.1, 4.4), (6.15, -1.1, 4.9), 73, rot=(0.15, 0.08, 0), segs=9, rings=6), "LeftForearm", "basalt", smooth_angle=None)
    b.part(chunk((1.4, 2.8, 3.2), (7.45, -1.0, 5.1), 74), "LeftForearm", "stone", smooth_angle=None)
    b.part(chunk((2.6, 1.3, 2.6), (6.1, -2.6, 5.2), 75, rot=(0.15, 0, 0)), "LeftForearm", "stone", smooth_angle=None)
    for o in cluster((6.3, 0.4, 6.4), (0.5, 1.0, 0.5), 5, 1.9, 0.34, seed=76):
        b.part(o, "LeftForearm", "crystal")                                                              # elbow growth
    seam(b, "LeftForearm", [(5.2, -2.6, 6.2), (5.9, -2.85, 5.0), (6.6, -2.6, 3.9)], 0.07)
    b.part(chunk((2.9, 2.7, 2.0), (6.3, -1.6, 2.6), 77, segs=9, rings=6), "LeftHand", "stone", smooth_angle=None)            # the fist
    for i, (dx, ln) in enumerate(((-1.0, 2.6), (0.0, 3.0), (1.0, 2.6))):
        b.part(shard((6.3 + dx, -2.2, 2.3), (dx * 0.22, -0.72, -0.7), ln, 0.42, sides=5, tip=0.04, waist=0.25), "LeftHand", "crystal")
    b.part(shard((7.6, -1.2, 2.6), (0.8, -0.5, -0.5), 1.8, 0.34, sides=5, tip=0.04), "LeftHand", "crystal")  # thumb
    b.neon(sf.sphere(0.26, loc=(6.3, -2.75, 2.75), segs=6, rings=4), "LeftHand", "HandGlow")
    for i, dx in enumerate((-1.0, 0.0, 1.0)):                                                            # knuckle plates
        b.part(chunk((0.95, 1.0, 0.8), (6.3 + dx, -2.5, 3.2), 230 + i), "LeftHand", "basalt", smooth_angle=None)
    b.part(chunk((2.8, 1.2, 1.6), (6.15, -2.75, 3.9), 234, rot=(0.25, 0, 0)), "LeftForearm", "basalt", smooth_angle=None)   # wrist guard
    b.part(chunk((1.2, 2.4, 1.8), (4.75, -1.0, 4.6), 235), "LeftForearm", "stone", smooth_angle=None)
    for o in cluster((7.6, -0.6, 4.2), (1.0, 0.2, 0.3), 4, 1.4, 0.26, seed=236, sides=5):
        b.part(o, "LeftForearm", "crystal")

    # ---- the right arm: slabs to the elbow, and from the elbow one great crystal
    b.part(chunk((2.9, 3.0, 4.4), (-5.2, -0.5, 8.3), 80, rot=(0, -0.3, 0), segs=9, rings=6), "RightArm", "basalt", smooth_angle=None)
    b.part(chunk((1.3, 2.6, 3.0), (-6.4, -0.5, 8.6), 81, rot=(0, -0.3, 0)), "RightArm", "stone", smooth_angle=None)
    b.part(chunk((2.2, 1.2, 2.4), (-5.3, -1.9, 8.4), 82, rot=(0.1, -0.3, 0)), "RightArm", "stone", smooth_angle=None)
    seam(b, "RightArm", [(-4.6, -1.95, 9.6), (-5.4, -2.2, 8.5), (-5.9, -1.9, 7.2)], 0.07)
    b.part(chunk((3.0, 3.0, 2.6), (-6.05, -0.9, 6.3), 83, segs=9, rings=6), "RightClub", "basalt", smooth_angle=None)       # the elbow it grows from
    b.part(chunk((1.5, 2.6, 2.0), (-7.3, -0.9, 6.4), 84), "RightClub", "stone", smooth_angle=None)
    club_d = sf.Vector((-0.1, -0.42, -1.0))
    b.part(shard((-6.1, -0.8, 6.9), club_d, 7.2, 1.45, sides=6, tip=0.3, waist=0.55, twist=0.3), "RightClub", "crystal")
    for i, (t, a, ln, r) in enumerate(((0.12, 0.3, 2.8, 0.55), (0.2, 2.2, 3.2, 0.6), (0.3, 4.1, 2.6, 0.5), (0.45, 1.2, 2.2, 0.46),
                                       (0.5, 3.3, 2.4, 0.5), (0.62, 5.2, 1.9, 0.42), (0.7, 0.2, 1.7, 0.4), (0.78, 2.6, 1.5, 0.36))):
        at = sf.Vector((-6.1, -0.8, 6.9)) + club_d.normalized() * 7.2 * t
        outward = sf.Vector((math.cos(a), math.sin(a) * 0.9, 0.0))
        b.part(shard(at + outward * 0.6, outward * 0.85 + club_d.normalized() * 0.75, ln, r, sides=5, twist=0.4 * i), "RightClub", "crystal")
    for o in cluster((-6.2, 0.5, 6.6), (-0.5, 1.0, 0.6), 5, 2.0, 0.36, seed=86):
        b.part(o, "RightClub", "crystal")
    for i in range(6):                                                                                   # a collar of rock where crystal meets arm
        a = math.tau * i / 6
        b.part(chunk((1.3, 1.3, 1.1), (-6.1 + math.cos(a) * 1.35, -1.0 + math.sin(a) * 1.25, 5.6), 240 + i),
               "RightClub", "stone" if i % 2 else "basalt", smooth_angle=None)
    b.neon(blob(0.5, (-6.75, -3.55, 0.6), scale=(1.0, 1.0, 1.3), segs=7, rings=5, seed=87), "RightClub", "ClubGlow")  # its lit tip
    seam(b, "RightClub", [(-6.9, -1.7, 6.2), (-7.2, -2.4, 4.6), (-7.1, -3.0, 2.9)], 0.1, name="ClubGlow")


def pose_arms(b, f, left=(0, 0, 0), lfore=(0, 0, 0), lhand=(0, 0, 0), right=(0, 0, 0), club=(0, 0, 0), ease="SINE"):
    b.key("LeftArm", f, left, ease=ease)
    b.key("LeftForearm", f, lfore, ease=ease)
    b.key("LeftHand", f, lhand, ease=ease)
    b.key("RightArm", f, right, ease=ease)
    b.key("RightClub", f, club, ease=ease)


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 120, loop=True, priority="Idle")
    for f, k in ((0, 0), (30, 1), (60, 0), (90, -1), (120, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, -0.1 * abs(k), 0))
        b.key("Chest", f, (2.5 * abs(k), 2 * k, 0))
        b.key("Spines", f, (-2 * abs(k), 0, 0))
        b.key("Head", f, (3 * abs(k), 7 * k, 0))
        b.key("Jaw", f, (8 + 7 * abs(k), 0, 0))
        pose_arms(b, f, left=(0, 0, 2 * abs(k)), lfore=(-4 * abs(k), 0, 0), lhand=(-6 * k, 0, 0),
                  right=(0, 0, -2 * abs(k)), club=(-3 * abs(k), 0, 2 * k))
    return act


def walk(b):
    act = sf.new_action(b.arm, "Walk", 0, 72, loop=True, priority="Movement")
    for f, k in ((0, 1), (18, 0), (36, -1), (54, 0), (72, 1)):
        up = 1 - abs(k)
        b.key("Body", f, (3, 0, 4 * k), loc=(0, -0.22 * abs(k), 0))
        b.key("Chest", f, (5, -5 * k, -3 * k))
        b.key("Spines", f, (-2 * abs(k), 0, 2 * k))
        b.key("Head", f, (2, 5 * k, 0))
        b.key("Jaw", f, (10 + 5 * abs(k), 0, 0))
        b.key("LeftLeg", f, (-15 * k, 0, 0), loc=(0, 0.35 * up * (k <= 0), 0))
        b.key("LeftShin", f, (9 * max(k, 0) + 8 * up * (k <= 0), 0, 0))
        b.key("RightLeg", f, (15 * k, 0, 0), loc=(0, 0.35 * up * (k >= 0), 0))
        b.key("RightShin", f, (9 * max(-k, 0) + 8 * up * (k >= 0), 0, 0))
        pose_arms(b, f, left=(11 * k, 0, 2), lfore=(-8 + 5 * k, 0, 0), lhand=(-6, 0, 0),
                  right=(-9 * k, 0, -2), club=(-4 - 4 * k, 0, 0))
    return act


def attack(b):
    """The club: cocked up and out beside its shoulder (never through the roof: a cell is 16 high), then
    down in front of it. The blow lands at 1.0 s."""
    act = sf.new_action(b.arm, "Attack", 0, 60, loop=False, priority="Action")
    b.rest(0)
    b.key("Jaw", 0, (8, 0, 0))
    b.key("Body", 20, (-6, 8, 0), loc=(0, 0.15, -0.3))                  # winds up: turns away, club high
    b.key("Chest", 20, (-14, 12, 4))
    b.key("Spines", 20, (4, 0, 0))
    b.key("Head", 20, (-6, -10, 0))
    b.key("Jaw", 20, (30, 0, 0))
    pose_arms(b, 20, left=(14, 0, 12), lfore=(-18, 0, 0), lhand=(-10, 0, 0), right=(-100, 0, -30), club=(-20, 0, -10))
    b.key("Body", 26, (-8, 9, 0), loc=(0, 0.2, -0.35))                  # hangs there a beat
    b.key("Chest", 26, (-16, 13, 4))
    pose_arms(b, 26, left=(14, 0, 12), lfore=(-18, 0, 0), lhand=(-10, 0, 0), right=(-104, 0, -30), club=(-24, 0, -10))
    b.key("Body", 30, (12, -6, 0), loc=(0, -0.35, 0.5), ease="QUAD")    # down
    b.key("Chest", 30, (24, -12, -3), ease="QUAD")
    b.key("Spines", 30, (-6, 0, 0), ease="QUAD")
    b.key("Head", 30, (-10, 6, 0), ease="QUAD")
    b.key("Jaw", 30, (4, 0, 0), ease="QUAD")
    pose_arms(b, 30, left=(-10, 0, 16), lfore=(-10, 0, 0), lhand=(0, 0, 0), right=(-56, 0, 22), club=(-12, 0, 8), ease="QUAD")
    b.key("Body", 40, (10, -5, 0), loc=(0, -0.3, 0.45))                 # holds in the dust
    b.key("Chest", 40, (20, -10, -3))
    pose_arms(b, 40, left=(-8, 0, 14), lfore=(-10, 0, 0), lhand=(0, 0, 0), right=(-52, 0, 20), club=(-10, 0, 8))
    b.rest(60)
    b.key("Jaw", 60, (8, 0, 0))
    return act


def volley(b):
    """It braces, arms wide, and the crown on its back flares: the shards leave at 0.9 s."""
    act = sf.new_action(b.arm, "Volley", 0, 57, loop=False, priority="Action")
    b.rest(0)
    b.key("Jaw", 0, (8, 0, 0))
    b.key("Body", 15, (8, 0, 0), loc=(0, -0.55, 0))                     # crouches, gathering
    b.key("Chest", 15, (18, 0, 0))
    b.key("Spines", 15, (10, 0, 0))
    b.key("Head", 15, (12, 0, 0))
    b.key("Jaw", 15, (4, 0, 0))
    b.key("LeftLeg", 15, (-8, 0, 6))
    b.key("RightLeg", 15, (-8, 0, -6))
    pose_arms(b, 15, left=(-12, 0, 8), lfore=(-30, 0, 0), lhand=(-20, 0, 0), right=(-10, 0, -8), club=(-24, 0, 0))
    b.key("Body", 24, (10, 0, 0), loc=(0, -0.65, 0))
    b.key("Spines", 24, (14, 0, 0))
    b.key("Body", 27, (-10, 0, 0), loc=(0, 0.3, -0.2), ease="QUAD")     # throws its chest open
    b.key("Chest", 27, (-20, 0, 0), ease="QUAD")
    b.key("Spines", 27, (-24, 0, 0), ease="QUAD")
    b.key("Head", 27, (-22, 0, 0), ease="QUAD")
    b.key("Jaw", 27, (44, 0, 0), ease="QUAD")
    pose_arms(b, 27, left=(-34, 0, 44), lfore=(-22, 0, 0), lhand=(-30, 0, 0), right=(-28, 0, -40), club=(-18, 0, -8), ease="QUAD")
    for f in range(30, 45, 3):                                          # shaking as they fly
        k = 1 if (f // 3) % 2 == 0 else -1
        b.key("Chest", f, (-20 + 2 * k, 0, 2 * k))
        b.key("Spines", f, (-24 - 4 * k, 0, 0))
        b.key("Head", f, (-22, 5 * k, 0))
        b.key("Jaw", f, (44 + 4 * k, 0, 0))
    pose_arms(b, 44, left=(-32, 0, 42), lfore=(-22, 0, 0), lhand=(-28, 0, 0), right=(-26, 0, -38), club=(-18, 0, -8))
    b.rest(57)
    b.key("Jaw", 57, (8, 0, 0))
    return act


def roar(b):
    act = sf.new_action(b.arm, "Roar", 0, 78, loop=False, priority="Action")
    b.rest(0)
    b.key("Jaw", 0, (8, 0, 0))
    b.key("Body", 14, (6, 0, 0), loc=(0, -0.4, 0))                      # drops its weight
    b.key("Chest", 14, (14, 0, 0))
    b.key("Head", 14, (10, 0, 0))
    pose_arms(b, 14, left=(-6, 0, 6), lfore=(-16, 0, 0), lhand=(-10, 0, 0), right=(-6, 0, -6), club=(-14, 0, 0))
    b.key("Body", 24, (-8, 0, 0), loc=(0, 0.25, -0.2), ease="QUAD")     # and rears: arms out, jaw wide
    b.key("Chest", 24, (-16, 0, 0), ease="QUAD")
    b.key("Spines", 24, (-12, 0, 0), ease="QUAD")
    b.key("Head", 24, (-24, 0, 0), ease="QUAD")
    b.key("Jaw", 24, (48, 0, 0), ease="QUAD")
    pose_arms(b, 24, left=(-22, 0, 36), lfore=(-26, 0, 0), lhand=(-34, 0, 0), right=(-36, 0, -30), club=(-30, 0, -10), ease="QUAD")
    for f in range(28, 60, 4):
        k = 1 if (f // 4) % 2 == 0 else -1
        b.key("Chest", f, (-16 + 2 * k, 2 * k, 0))
        b.key("Head", f, (-24, 6 * k, 3 * k))
        b.key("Jaw", f, (48 + 5 * k, 0, 0))
        b.key("Spines", f, (-12 - 3 * k, 0, 0))
        b.key("RightClub", f, (-30 - 3 * k, 0, -10))
        b.key("LeftHand", f, (-34 + 6 * k, 0, 0))
    b.rest(78)
    b.key("Jaw", 78, (8, 0, 0))
    return act


def stagger(b):
    """Its cores are broken into: it drops to a knee on its club, head down, then heaves up."""
    act = sf.new_action(b.arm, "Stagger", 0, 105, loop=False, priority="Action")
    b.rest(0)
    b.key("Jaw", 0, (8, 0, 0))
    b.key("Body", 8, (-10, 0, 6), loc=(0, 0.2, -0.5), ease="QUAD")      # the jolt
    b.key("Chest", 8, (-16, -6, 4), ease="QUAD")
    b.key("Head", 8, (-20, -10, 0), ease="QUAD")
    b.key("Jaw", 8, (40, 0, 0), ease="QUAD")
    pose_arms(b, 8, left=(-20, 0, 30), lfore=(-10, 0, 0), right=(-16, 0, -24), club=(-10, 0, 0), ease="QUAD")
    b.key("Body", 26, (16, 0, -4), loc=(0, -1.5, 0.2))                  # down on its right knee
    b.key("Chest", 26, (24, 6, -4))
    b.key("Spines", 26, (6, 0, 0))
    b.key("Head", 26, (26, 4, 0))
    b.key("Jaw", 26, (24, 0, 0))
    b.key("RightLeg", 26, (-58, 0, 0))
    b.key("RightShin", 26, (88, 0, 0))
    b.key("LeftLeg", 26, (-34, 0, 4))
    b.key("LeftShin", 26, (30, 0, 0))
    pose_arms(b, 26, left=(-20, 0, 10), lfore=(-34, 0, 0), lhand=(-20, 0, 0), right=(-34, 0, -8), club=(-6, 0, 6))
    for f, k in ((44, 1), (62, -1), (80, 1)):                           # heaving
        b.key("Body", f, (16 + 1.5 * k, 0, -4), loc=(0, -1.5 - 0.08 * k, 0.2))
        b.key("Chest", f, (24 + 3 * k, 6, -4))
        b.key("Head", f, (26 + 4 * k, 4, 0))
        b.key("Jaw", f, (24 + 8 * k, 0, 0))
    for bone, rot in (("RightLeg", (-58, 0, 0)), ("RightShin", (88, 0, 0)), ("LeftLeg", (-34, 0, 4)), ("LeftShin", (30, 0, 0))):
        b.key(bone, 84, rot)
    pose_arms(b, 84, left=(-20, 0, 10), lfore=(-34, 0, 0), lhand=(-20, 0, 0), right=(-34, 0, -8), club=(-6, 0, 6))
    b.rest(105)
    b.key("Jaw", 105, (8, 0, 0))
    return act


def death(b):
    """It comes apart at the knees: down, forward onto its club, and the head drops."""
    act = sf.new_action(b.arm, "Death", 0, 96, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 12, (-12, 0, 5), loc=(0, 0.3, -0.5), ease="QUAD")     # thrown back
    b.key("Chest", 12, (-20, 0, 0), ease="QUAD")
    b.key("Head", 12, (-28, 0, 0), ease="QUAD")
    b.key("Jaw", 12, (50, 0, 0), ease="QUAD")
    pose_arms(b, 12, left=(-30, 0, 40), lfore=(-20, 0, 0), right=(-30, 0, -36), club=(-20, 0, 0), ease="QUAD")
    b.key("Body", 40, (14, 0, 0), loc=(0, -2.3, 0.3), ease="QUAD")      # both knees give
    b.key("Chest", 40, (20, 0, 0))
    b.key("Spines", 40, (8, 0, 0))
    b.key("Head", 40, (10, 0, 0))
    for side in ("Left", "Right"):
        b.key(f"{side}Leg", 40, (-66, 0, 0), ease="QUAD")
        b.key(f"{side}Shin", 40, (104, 0, 0), ease="QUAD")
    pose_arms(b, 40, left=(-10, 0, 14), lfore=(-30, 0, 0), lhand=(-20, 0, 0), right=(-26, 0, -10), club=(-8, 0, 4))
    b.key("Body", 66, (40, 0, 4), loc=(0, -2.6, 1.6), ease="QUAD")      # and it goes over forward
    b.key("Chest", 66, (34, 0, 3))
    b.key("Spines", 66, (16, 0, 0))
    b.key("Head", 66, (30, 6, 0))
    b.key("Jaw", 66, (20, 0, 0))
    pose_arms(b, 66, left=(-58, 0, 22), lfore=(-46, 0, 0), lhand=(-30, 0, 0), right=(-62, 0, -16), club=(-28, 0, 10))
    for side in ("Left", "Right"):
        b.key(f"{side}Leg", 66, (-88, 0, 0))
        b.key(f"{side}Shin", 66, (112, 0, 0))
    b.key("Body", 80, (44, 0, 5), loc=(0, -2.75, 1.7))                  # settles
    b.key("Head", 80, (38, 8, 0))
    b.key("Jaw", 80, (10, 0, 0))
    b.key("Body", 96, (44, 0, 5), loc=(0, -2.75, 1.7))
    return act


def all_clips(b):
    return [idle(b), walk(b), attack(b), volley(b), roar(b), stagger(b), death(b)]


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("CrystalColossus", JOINTS, collision="queryhull"), build, all_clips,
          budget=15000, hrp_center=(0, 0.3, 4.6), hrp_size=(5.0, 4.0, 5.0), step="A10",
          meta={"role": "Boss", "band": "CrystalHollows", "era": 3, "hitTime": HIT_TIME, "volleyTime": VOLLEY_TIME},
          sockets={"Slam": ((-1.5, -9.0, 0.3), 0.0)},
          markers={"Attack": {"Hit": HIT_TIME}, "Volley": {"Throw": VOLLEY_TIME}},
          pivot=(0.0, 0.0, 0.0))
