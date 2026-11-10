"""Monster_AshRaider: a raider of the Ash (bible Sections 10, 12 and 27: melee or rifles; collapses
and fades when beaten; raids the Blast Door from Era II). A scavenger in a long split dust coat
and a black gas mask with round orange lenses, a dust-cloth hood under a welded scrap helmet, a
road sign for a chest plate, half a whitewall tyre and spiked plates for shoulder armour, a hubcap
buckler, a pack with a looted Steadfast blanket, a rope, a storm lantern and a torn pennant, and
a rusty bolt-action rifle with a bayonet. Human, so no Source glow: menace comes from the mask,
the armour and the silhouette; its only lights are orange (the lenses and the lantern).

Rig: Pelvis (root), Torso, Head, two-bone arms and legs (the Hollow Miner's layout at human size),
and Rifle, jointed at the grip in the right fist. Clips: Idle (standing guard, the mask sweeping the ash, looped),
Walk (a wary prowl, looped), Attack (shoulders the rifle and fires, Hit 0.45 s: when MonsterService
checks the shot).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_AshRaider.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import _beast as B  # noqa: E402
from _beast import sf, spike, claw, limb, blob, rod  # noqa: E402,F401
from mathutils import Matrix  # noqa: E402

ASSET, CATEGORY = "Monster_AshRaider", "Monsters"
HIT_TIME = 0.45
HOOD, HOOD_EDGE, BROW = "rust", "walnut", "steel"      # the raiders' red: hood, pennant, plates
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
# The rifle turns in the fist (its own bone, jointed at the grip), so the raider can shoulder it and
# still point it at what it shoots: fixed to the forearm it aimed at the sky whenever the arm came up.
RIFLE_JOINTS = JOINTS + [("Rifle", "RightLowerArm", (-1.12, -0.22, 2.3))]


def ragged(width, top, bottom, teeth, depth=0.28, seed=1):
    """A coat panel's outline (x, z): a straight top and a torn zigzag hem."""
    rnd = random.Random(seed)
    pts = [(-width / 2, top), (width / 2, top)]
    n = teeth * 2
    for i in range(n + 1):
        x = width / 2 - width * i / n
        z = bottom + (depth * rnd.uniform(0.55, 1.0) if i % 2 == 1 else rnd.uniform(0.0, 0.07))
        pts.append((x, z))
    return pts


def stud(b, bone, at, facing, swatch="brass", r=0.05, h=0.05):
    """A pyramid rivet: 6 triangles where a round one takes 20."""
    return b.part(spike(at, facing, h, r, verts=4), bone, swatch)


def panel(b, outline, thickness, at, yaw, flare, swatch="leather"):
    """A coat-skirt panel hanging from the belt at `at`. `outline` is (across, down from the belt);
    the outer face looks along +Y turned `yaw` degrees about Z, and the hem swings `flare`
    degrees outward. Returns the panel's matrix, for the pieces sewn onto it."""
    m = (Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
         @ Matrix.Rotation(math.radians(90 + flare), 4, "X"))
    slab = sf.profile_slab(outline, thickness, bevel=0.0)
    slab.matrix_world = m
    b.part(slab, "Pelvis", swatch)
    return m


def sewn(b, m, obj, u, v, swatch, tilt=0.0, out=0.02, offset=(0.0, 0.0)):
    """Put a flat piece on a panel's outer face at (across, down), turned `tilt` degrees about
    that point; `offset` moves it along its own turned axes."""
    obj.matrix_world = (m @ Matrix.Translation((u, v, -out)) @ Matrix.Rotation(math.radians(tilt), 4, "Z")
                        @ Matrix.Translation((offset[0], offset[1], 0.0)))
    return b.part(obj, "Pelvis", swatch)


def tyre_arch(b, bone="Torso"):
    """Half a whitewall tyre strapped over its left shoulder, tread out (a whole tyre read as a
    drum): an arch from the collar over the shoulder and down the outside of the arm."""
    cx, cz, wide = 1.0, 4.45, 0.74

    def ring(r_in, r_out, n):
        angles = [math.radians(-25 + 165 * i / (n - 1)) for i in range(n)]
        return ([(cx + r_out * math.cos(a), cz + r_out * math.sin(a)) for a in angles]
                + [(cx + r_in * math.cos(a), cz + r_in * math.sin(a)) for a in reversed(angles)])

    b.part(sf.profile_slab(ring(0.42, 0.64, 7), wide, loc=(0, wide / 2, 0), rot=(90, 0, 0), bevel=0.0), bone, "rubber")
    for y in (-wide / 2, wide / 2 + 0.03):                                     # the whitewall, on both sides
        b.part(sf.profile_slab(ring(0.48, 0.57, 5), 0.03, loc=(0, y, 0), rot=(90, 0, 0), bevel=0.0), bone, "cream")
    for i in range(8):                                                         # the tread: staggered lugs
        a = math.radians(-18 + i * 21.5)
        b.part(sf.box((0.2, 0.36, 0.1), loc=(cx + math.cos(a) * 0.66, -0.19 if i % 2 else 0.19, cz + math.sin(a) * 0.66),
                      rot=(0, -math.degrees(a) + 90, 0), bevel=0.0), bone, "basalt")


def build(b, weapon="rifle"):
    """Detail pass (Landon, Nov 9: "I need more detail for that character. Not up to our
    standards"): a welded scrap helmet with a crest of spikes, a gas mask with a brow plate, cheek
    filters and a hose to a chest canister, a road-sign chest plate, half a whitewall tyre over one
    shoulder and spiked plates on the other, a split coat with flared, torn hems and patches, a
    machete through the belt, wrapped forearms, a hubcap buckler, studded knee pads, strapped
    steel-toed boots, and a pack with a blanket roll, a rope, a lantern and a torn pennant."""
    T, P, H = "Torso", "Pelvis", "Head"
    # ---- Torso: the dust coat, its collar and lapels, the shirt showing down the front
    b.part(sf.box((1.7, 1.0, 1.9), loc=(0, 0.0, 3.85), bevel=0.25, segments=1), T, "leather")
    b.part(sf.box((0.5, 0.1, 1.5), loc=(0, -0.5, 3.8), bevel=0.0), T, "sandstone")
    for sx in (-1, 1):
        b.part(sf.box((0.5, 0.1, 1.15), loc=(sx * 0.42, -0.54, 4.2), rot=(0, sx * 10, 0), bevel=0.0), T, "walnut")   # lapels
        b.part(sf.box((0.2, 0.75, 0.5), loc=(sx * 0.62, 0.05, 4.95), rot=(0, sx * -18, 0), bevel=0.0), T, "leather")  # collar
        b.part(sf.box((0.2, 1.06, 1.25), loc=(sx * 0.6, 0.0, 4.2), bevel=0.0), T, "walnut")                                         # pack straps
    b.part(sf.box((1.1, 0.2, 0.5), loc=(0, 0.42, 4.95), bevel=0.0), T, "leather")
    # ---- the road sign strapped to the chest: hazard yellow, a black edge, a black bang
    b.part(sf.box((1.12, 0.06, 1.12), loc=(0, -0.6, 3.95), rot=(0, 45, 0), bevel=0.0), T, "rubber")
    b.part(sf.box((0.96, 0.07, 0.96), loc=(0, -0.63, 3.95), rot=(0, 45, 0), bevel=0.0), T, "hazard")
    b.part(sf.box((0.13, 0.05, 0.42), loc=(0, -0.68, 4.03), bevel=0.0), T, "rubber")
    b.part(sf.box((0.13, 0.05, 0.13), loc=(0, -0.68, 3.68), bevel=0.0), T, "rubber")
    for dx, dz in ((0, 0.62), (0, -0.62), (0.62, 0), (-0.62, 0)):
        stud(b, T, (dx, -0.665, 3.95 + dz), (0, -1, 0), "steel", r=0.06, h=0.05)
    b.part(sf.box((0.5, 0.05, 0.3), loc=(0.3, -0.675, 3.62), rot=(0, 45, 0), bevel=0.0), T, "rust")      # a rusted corner
    # ---- the bandolier across it, with shells
    b.part(sf.box((0.22, 1.12, 2.2), loc=(0.32, 0.0, 3.85), rot=(0, 30, 0), bevel=0.0), T, "walnut")
    for i in range(4):
        b.part(sf.cyl(0.07, 0.26, loc=(0.74 - i * 0.2, -0.6, 4.62 - i * 0.34), rot=(0, 30, 0), verts=5, bevel=0.0), T, "brass")
    # ---- the filter canister on the right chest and its hose up to the mask
    b.part(sf.cyl(0.19, 0.5, loc=(-0.58, -0.62, 3.35), verts=8, bevel=0.0), T, "steel")
    b.part(sf.cyl(0.2, 0.1, loc=(-0.58, -0.62, 3.35), verts=8, bevel=0.0), T, "hazard")
    b.part(limb([(-0.58, -0.62, 3.6), (-0.62, -0.82, 4.15), (-0.34, -0.9, 4.7), (-0.12, -0.9, 4.92)], [0.075] * 4, sides=4, resolution=2), T, "rubber")
    # ---- shoulders: half a whitewall tyre on its left, layered spiked plates on its right
    tyre_arch(b, T)
    b.part(sf.box((0.85, 1.15, 0.2), loc=(-0.98, 0.0, 4.78), rot=(0, 20, 0), bevel=0.06, segments=1), T, "rust")
    b.part(sf.box((0.6, 0.95, 0.16), loc=(-1.22, 0.0, 4.52), rot=(0, 42, 0), bevel=0.0), T, "gunmetal")
    for y in (-0.38, 0.0, 0.38):
        b.part(spike((-1.12, y, 4.9), (-0.55, 0.0, 1.0), 0.5, 0.11, verts=4), T, "steel")
    for y in (-0.42, 0.42):
        stud(b, T, (-0.78, y, 4.82), (0.34, 0.0, 0.94), "brass", r=0.06, h=0.06)
    # ---- the pack: a looted Steadfast blanket rolled on top, a rope, a storm lantern, a pennant
    b.part(sf.box((1.3, 0.6, 0.95), loc=(0, 0.78, 4.15), bevel=0.15, segments=1), T, "olive")
    b.part(sf.box((1.0, 0.1, 0.4), loc=(0, 1.1, 3.95), bevel=0.0), T, "forest")                       # a pocket
    for sx in (-1, 1):
        b.part(sf.box((0.12, 0.06, 0.62), loc=(sx * 0.3, 1.1, 4.34), bevel=0.0), T, "walnut")         # its straps
        stud(b, T, (sx * 0.3, 1.13, 4.2), (0, 1, 0), "brass", r=0.07, h=0.05)
    b.part(sf.cyl(0.29, 1.55, loc=(0, 0.82, 4.9), rot=(0, 90, 0), verts=8, bevel=0.0), T, "teal")
    for sx in (-1, 1):
        b.part(sf.cyl(0.305, 0.1, loc=(sx * 0.42, 0.82, 4.9), rot=(0, 90, 0), verts=8, bevel=0.0), T, "walnut")
    for i in range(2):                                                                                 # the rope, coiled
        b.part(sf.torus(0.25, 0.075, loc=(0.72 + i * 0.13, 0.8, 4.0 - i * 0.04), rot=(i * 14, 90, 0), major_segs=12, minor_segs=3),
               T, "pine")
    b.part(sf.box((0.3, 0.14, 0.16), loc=(0.78, 0.8, 4.26), bevel=0.0), T, "walnut")
    lx, ly, lz = -0.82, 0.92, 3.7                                                                      # the lantern
    b.part(sf.cyl(0.13, 0.07, loc=(lx, ly, lz - 0.17), verts=6, bevel=0.0), T, "gunmetal")
    b.part(sf.cyl(0.14, 0.12, loc=(lx, ly, lz + 0.19), verts=6, radius_top=0.05, bevel=0.0), T, "gunmetal")
    b.part(sf.box((0.04, 0.04, 0.3), loc=(lx, ly, lz + 0.38), bevel=0.0), T, "steel")
    flame = sf.cyl(0.1, 0.28, loc=(lx, ly, lz), verts=6, bevel=0.0)
    sf.tag(flame, "Lantern", "signal", "Neon", collision="none", cast_shadow=False)    # orange, like the lenses
    flame["sf_bone"] = T
    sf.bind(flame, b.arm, T)
    b.part(rod((-0.5, 1.05, 4.3), (-0.62, 1.2, 6.75), 0.035, verts=4), T, "gunmetal")
    flag = sf.profile_slab([(0.0, 0.0), (0.0, 0.5), (0.5, 0.42), (0.95, 0.52), (0.72, 0.3), (1.0, 0.12), (0.55, 0.14), (0.3, -0.04)],
                           0.03, bevel=0.0)
    flag.rotation_euler = (math.radians(90), 0, math.radians(100))
    flag.location = (-0.6, 1.2, 6.15)
    sun = sf.cyl(0.13, 0.07, verts=6, bevel=0.0)                                                       # its black sun
    bpy.context.view_layer.update()
    sun.matrix_world = flag.matrix_world @ Matrix.Translation((0.42, 0.27, 0.015))
    b.part(flag, T, "rust")
    b.part(sun, T, "rubber")

    # ---- Pelvis: the belt and the coat's split skirt with torn hems and patches
    b.part(sf.box((1.75, 1.08, 0.3), loc=(0, 0.0, 3.0), bevel=0.0), P, "walnut")
    b.part(sf.box((0.34, 0.08, 0.26), loc=(0, -0.56, 3.0), bevel=0.0), P, "brass")
    b.part(sf.box((0.36, 0.3, 0.42), loc=(0.62, -0.5, 2.82), bevel=0.0), P, "olive")                  # pouch
    b.part(sf.box((0.38, 0.06, 0.14), loc=(0.62, -0.66, 2.96), bevel=0.0), P, "forest")
    b.part(sf.cyl(0.17, 0.42, loc=(-0.72, -0.5, 2.78), verts=8, bevel=0.0), P, "steel")               # canteen
    b.part(sf.cyl(0.07, 0.1, loc=(-0.72, -0.5, 3.03), verts=6, bevel=0.0), P, "brass")
    back = panel(b, ragged(1.8, 0.0, -1.45, 5, seed=5), 0.14, (0, 0.62, 3.0), 0, 7)
    sewn(b, back, sf.box((0.07, 1.2, 0.04), bevel=0.0), 0.0, -0.6, "walnut")                          # the back seam
    sewn(b, back, sf.box((0.34, 0.3, 0.04), bevel=0.0), 0.5, -0.72, "olive", tilt=-10)                # patches
    sewn(b, back, sf.box((0.4, 0.34, 0.04), bevel=0.0), 0.46, -1.0, "sandstone", tilt=7)
    # a machete tucked through the belt at the back
    blade = sf.profile_slab([(-0.09, 0.0), (0.09, 0.0), (0.11, -0.74), (0.0, -0.98), (-0.09, -0.8)], 0.04, bevel=0.0)
    sewn(b, back, blade, -0.5, -0.12, "steel", tilt=24, out=0.08)
    sewn(b, back, sf.box((0.32, 0.07, 0.09), bevel=0.0), -0.5, -0.12, "brass", tilt=24, out=0.06)
    sewn(b, back, sf.box((0.13, 0.36, 0.09), bevel=0.0), -0.5, -0.12, "rubber", tilt=24, out=0.06, offset=(0.0, 0.2))
    for sx in (-1, 1):
        side = panel(b, ragged(1.1, 0.0, -1.3, 3, seed=7 + sx), 0.14, (sx * 0.97, 0.05, 3.0), -90 * sx, 6)
        front = panel(b, ragged(0.68, 0.0, -1.15, 2, seed=11 + sx), 0.12, (sx * 0.56, -0.58, 3.0), 180, 5)
        if sx > 0:
            sewn(b, front, sf.box((0.4, 0.36, 0.04), bevel=0.0), -0.04, -0.66, "sandstone", tilt=-8)
            sewn(b, side, sf.box((0.36, 0.34, 0.04), bevel=0.0), -0.05, -0.8, "rust", tilt=6)

    # ---- Head: the hood, a welded scrap helmet with a crest, the gas mask
    b.part(blob(0.62, (0, 0.05, 5.35), scale=(1.0, 1.05, 1.1), segs=10, rings=7, seed=3), H, HOOD)
    b.part(sf.torus(0.5, 0.09, loc=(0, -0.3, 5.3), rot=(80, 0, 0), major_segs=10, minor_segs=3), H, HOOD_EDGE)     # the hood's edge
    helmet = blob(0.66, (0, 0.12, 5.62), scale=(1.0, 1.08, 0.72), segs=10, rings=6, seed=6)
    b.part(helmet, H, "gunmetal")
    b.part(sf.box((0.5, 0.36, 0.1), loc=(0.22, -0.28, 5.98), rot=(-24, 10, 0), bevel=0.0), H, "rust")              # a welded patch
    for i in range(4):
        y = -0.3 + i * 0.3
        b.part(spike((0, y, 6.02 - abs(i - 1.2) * 0.05), (0, 0.25, 1.0), 0.5 - i * 0.05, 0.1, verts=4), H, "steel")  # the crest
    for i in range(6):
        a = math.radians(i * 60 + 30)
        stud(b, H, (math.cos(a) * 0.63, 0.12 + math.sin(a) * 0.68, 5.64), (math.cos(a), math.sin(a), 0.15), "brass", r=0.06, h=0.07)
    b.part(blob(0.5, (0, -0.32, 5.25), scale=(0.95, 0.7, 0.95), segs=10, rings=6, seed=4), H, "rubber")
    for sx in (-1, 1):
        b.part(sf.box((0.46, 0.16, 0.15), loc=(sx * 0.23, -0.78, 5.63), rot=(18, -16 * sx, 0), bevel=0.0), H, BROW)   # a scowling brow plate
        b.part(sf.cyl(0.23, 0.14, loc=(sx * 0.23, -0.72, 5.42), rot=(90, 0, 0), verts=10, bevel=0.0), H, "chrome")
        lens = sf.cyl(0.16, 0.1, loc=(sx * 0.23, -0.8, 5.42), rot=(90, 0, 0), verts=10, bevel=0.0)
        sf.tag(lens, "Lenses", "signal", "Neon", collision="none", cast_shadow=False)     # orange lenses, not Source green
        lens["sf_bone"] = H
        sf.bind(lens, b.arm, H)
        b.part(sf.cyl(0.15, 0.24, loc=(sx * 0.47, -0.56, 5.05), rot=(90, 0, sx * -40), verts=8, bevel=0.0), H, "steel")   # cheek filters
        b.part(sf.cyl(0.16, 0.06, loc=(sx * 0.55, -0.66, 5.05), rot=(90, 0, sx * -40), verts=8, bevel=0.0), H, "hazard")
        b.part(sf.box((0.08, 0.5, 0.1), loc=(sx * 0.5, -0.2, 5.5), rot=(0, 0, sx * 12), bevel=0.0), H, "walnut")             # mask straps
    b.part(sf.cyl(0.24, 0.45, loc=(0, -0.85, 5.0), rot=(70, 0, 0), verts=8, bevel=0.0), H, "steel")                # the snout filter
    b.part(sf.cyl(0.26, 0.08, loc=(0, -1.06, 4.93), rot=(70, 0, 0), verts=8, bevel=0.0), H, "hazard")
    for dz in (-0.08, 0.06):
        b.part(sf.box((0.3, 0.03, 0.035), loc=(0, -1.1, 4.92 + dz), rot=(-20, 0, 0), bevel=0.0), H, "rubber")     # its grille

    # ---- Arms: coat sleeves, elbow pads, wrapped forearms, gloves
    for side, sx in (("Left", 1), ("Right", -1)):
        b.part(limb([(sx * 0.95, 0.0, 4.55), (sx * 1.05, -0.05, 3.95), (sx * 1.1, -0.1, 3.4)], [0.3, 0.27, 0.24]),
               f"{side}UpperArm", "leather")
        b.part(limb([(sx * 1.1, -0.1, 3.4), (sx * 1.12, -0.15, 2.75), (sx * 1.12, -0.2, 2.35)], [0.24, 0.2, 0.19]),
               f"{side}LowerArm", "leather")
        b.part(sf.cyl(0.21, 0.12, loc=(sx * 1.12, 0.16, 3.38), rot=(90, 0, 0), verts=6, bevel=0.0), f"{side}LowerArm", "steel")   # elbow pad
        for z in (3.05, 2.86, 2.67):
            b.part(sf.cyl(0.235, 0.09, loc=(sx * 1.115, -0.14, z), verts=6, bevel=0.0), f"{side}LowerArm", "sandstone")          # wraps
        b.part(blob(0.22, (sx * 1.12, -0.22, 2.2), scale=(0.9, 1.0, 1.1), segs=6, rings=4, seed=8), f"{side}LowerArm", "rubber")
    b.part(sf.cyl(0.31, 0.14, loc=(-1.02, -0.03, 4.08), verts=6, bevel=0.0), "RightUpperArm", "rust")              # a rag tied on
    b.part(sf.box((0.1, 0.05, 0.42), loc=(-1.3, 0.05, 3.9), rot=(0, 14, 0), bevel=0.0), "RightUpperArm", "rust")
    for i in range(3):
        stud(b, "RightLowerArm", (-1.12 + (i - 1) * 0.11, -0.4, 2.24), (0, -1, 0), "brass", r=0.055, h=0.09)      # knuckles
    # the hubcap buckler on its left forearm
    b.part(sf.cyl(0.56, 0.07, loc=(1.4, -0.15, 2.9), rot=(0, 90, 0), verts=12, bevel=0.0), "LeftLowerArm", "chrome")
    b.part(sf.cyl(0.2, 0.12, loc=(1.43, -0.15, 2.9), rot=(0, 90, 0), verts=8, bevel=0.0), "LeftLowerArm", "gunmetal")
    for i in range(5):
        a = math.radians(i * 72 + 18)
        stud(b, "LeftLowerArm", (1.435, -0.15 + math.cos(a) * 0.38, 2.9 + math.sin(a) * 0.38), (1, 0, 0), "rubber", r=0.07, h=0.04)
    b.part(sf.box((0.03, 0.34, 0.2), loc=(1.445, -0.3, 3.12), rot=(20, 0, 0), bevel=0.0), "LeftLowerArm", "rust")
    for z in (3.1, 2.7):
        b.part(sf.box((0.3, 0.1, 0.08), loc=(1.26, -0.15, z), bevel=0.0), "LeftLowerArm", "walnut")                # its straps

    if weapon == "rifle":
        # ---- the rifle in the right fist: a taped stock, a wooden fore-end with a brass band,
        # a scope on two mounts, a bayonet under the muzzle and a red rag tied to the barrel
        R = "Rifle"
        b.part(sf.box((0.22, 1.1, 0.38), loc=(-1.12, 0.25, 2.3), bevel=0.0), R, "walnut")
        for y in (0.05, 0.5):
            b.part(sf.box((0.24, 0.12, 0.4), loc=(-1.12, y, 2.3), bevel=0.0), R, "sandstone")
        b.part(sf.box((0.2, 1.4, 0.26), loc=(-1.12, -0.95, 2.3), bevel=0.0), R, "gunmetal")
        b.part(sf.box((0.25, 0.95, 0.2), loc=(-1.12, -1.78, 2.22), bevel=0.0), R, "walnut")
        b.part(sf.box((0.27, 0.1, 0.25), loc=(-1.12, -2.1, 2.25), bevel=0.0), R, "brass")
        b.part(sf.box((0.14, 0.3, 0.36), loc=(-1.12, -0.75, 2.04), rot=(-12, 0, 0), bevel=0.0), R, "rust")
        b.part(rod((-1.12, -0.4, 2.57), (-1.12, -1.45, 2.57), 0.1, verts=6), R, "steel")
        b.part(sf.cyl(0.115, 0.06, loc=(-1.12, -1.47, 2.57), rot=(90, 0, 0), verts=6, bevel=0.0), R, "chrome")
        for y in (-0.6, -1.25):
            b.part(sf.box((0.08, 0.1, 0.12), loc=(-1.12, y, 2.45), bevel=0.0), R, "gunmetal")
        b.part(sf.box((0.1, 0.1, 0.1), loc=(-0.98, -0.45, 2.38), bevel=0.0), R, "steel")              # the bolt handle
        b.part(rod((-1.12, -1.6, 2.36), (-1.12, -3.1, 2.36), 0.08, verts=6), R, "steel")
        b.part(sf.box((0.06, 0.08, 0.14), loc=(-1.12, -3.0, 2.47), bevel=0.0), R, "gunmetal")         # the front sight
        b.part(spike((-1.12, -3.0, 2.26), (0, -1, 0), 0.65, 0.06, verts=4), R, "chrome")
        b.part(sf.box((0.05, 0.16, 0.36), loc=(-1.04, -2.55, 2.16), rot=(0, 0, 12), bevel=0.0), R, "rust")

    # ---- Legs: studded knee pads, wrapped shins, strapped steel-toed boots
    for side, sx in (("Left", 1), ("Right", -1)):
        b.part(limb([(sx * 0.45, 0.0, 2.55), (sx * 0.47, -0.03, 1.9), (sx * 0.47, -0.05, 1.3)], [0.32, 0.28, 0.24], resolution=1),
               f"{side}UpperLeg", "olive")
        b.part(limb([(sx * 0.47, -0.05, 1.3), (sx * 0.47, -0.05, 0.6)], [0.24, 0.22]), f"{side}LowerLeg", "sandstone")
        b.part(sf.box((0.44, 0.2, 0.44), loc=(sx * 0.47, -0.3, 1.3), bevel=0.06, segments=1), f"{side}LowerLeg", "gunmetal")     # knee pad
        stud(b, f"{side}LowerLeg", (sx * 0.47, -0.4, 1.3), (0, -1, 0), "brass", r=0.09, h=0.1)
        for z in (0.98, 0.76):
            b.part(sf.cyl(0.25, 0.07, loc=(sx * 0.47, -0.05, z), verts=6, bevel=0.0), f"{side}LowerLeg", "walnut")              # straps
        b.part(sf.box((0.55, 1.0, 0.5), loc=(sx * 0.47, -0.2, 0.31), bevel=0.12, segments=1), f"{side}LowerLeg", "rubber")
        b.part(sf.box((0.57, 0.34, 0.3), loc=(sx * 0.47, -0.56, 0.24), bevel=0.0), f"{side}LowerLeg", "steel")     # toe cap
        b.part(sf.box((0.6, 1.06, 0.1), loc=(sx * 0.47, -0.2, 0.05), bevel=0.0), f"{side}LowerLeg", "basalt")                    # sole
        b.part(sf.box((0.6, 0.12, 0.1), loc=(sx * 0.47, -0.05, 0.5), bevel=0.0), f"{side}LowerLeg", "walnut")
        b.part(sf.box((0.1, 0.03, 0.1), loc=(sx * 0.47 + sx * 0.2, -0.12, 0.5), bevel=0.0), f"{side}LowerLeg", "brass")          # buckle


# Two-handed poses, solved so both fists stay on the rifle (the right on the grip, the left under
# the fore-end) with the rifle where it should point; angles in degrees, relative to the torso.
CARRY = {            # patrol carry: across the body, muzzle down and to its left (solved with the torso leaning 8)
    "RightUpperArm": (23.2, 1.5, 39.2), "RightLowerArm": (-115.0, 0, 0), "Rifle": (132.0, 30.1, 54.4),
    "LeftUpperArm": (-2.2, -0.2, -46.2), "LeftLowerArm": (-58.0, 0, 0),
}
AIM = {              # shouldered and level, its body bladed, the mask behind the scope
    "Pelvis": (0, -14, 0), "Torso": (4, -24, 0), "Head": (4, 34, -10),
    "RightUpperArm": (-92.2, 1.8, -75.4), "RightLowerArm": (-91.5, 0, 0), "Rifle": (-5.8, -146.2, 108.2),
    "LeftUpperArm": (-41.7, -12.9, -48.1), "LeftLowerArm": (-83.0, 0, 0),
}


def pose(b, frame, keys, ease="SINE", **over):
    for bone, rot in {**keys, **over}.items():
        if bone == "Pelvis":
            b.key(bone, frame, rot, loc=(0, 0, 0), ease=ease)
        else:
            b.key(bone, frame, rot, ease=ease)


def walk(b):
    """A wary prowl, the rifle carried across the body in both hands."""
    act = sf.new_action(b.arm, "Walk", 0, 30, loop=True, priority="Movement")
    for f, s in ((0, 1), (15, -1), (30, 1)):
        b.key("LeftUpperLeg", f, (-24 * s, 0, 0))
        b.key("RightUpperLeg", f, (24 * s, 0, 0))
        b.key("LeftLowerLeg", f, (10 if s > 0 else 32, 0, 0))
        b.key("RightLowerLeg", f, (32 if s > 0 else 10, 0, 0))
        pose(b, f, CARRY, Torso=(8, -5 * s, 0), Head=(-6, 6 * s, 0))
        b.key("Pelvis", f, (0, 4 * s, 0), loc=(0, 0, 0))
    for f in (7, 22):
        b.key("Pelvis", f, (0, 0, 0), loc=(0, 0.12, 0))
    return act


def idle(b):
    """Standing guard: the rifle across the body, breathing, the mask sweeping the ash."""
    act = sf.new_action(b.arm, "Idle", 0, 90, loop=True, priority="Idle")
    for f, k in ((0, 0.0), (45, 1.0), (90, 0.0)):
        pose(b, f, CARRY, Pelvis=(0, 5 - 10 * k, 0), Torso=(8 - 3 * k, 4 - 8 * k, 0), Head=(-5 + 2 * k, -18 + 36 * k, 0))
        for side in ("Left", "Right"):
            b.key(f"{side}UpperLeg", f, (0, 0, 0))
            b.key(f"{side}LowerLeg", f, (0, 0, 0))
    return act


def attack(b):
    """Shoulders the rifle, fires (Hit 0.45 s) with a kick, and lowers it again."""
    act = sf.new_action(b.arm, "Attack", 0, 27, loop=False, priority="Action")
    b.rest(0)
    pose(b, 0, CARRY, Torso=(8, 0, 0), Head=(-6, 0, 0))
    for f in (7, 13):
        pose(b, f, AIM)
    pose(b, 14, AIM, ease="QUAD", Torso=(-4, -24, 0), Head=(10, 34, -10))    # the kick of the shot
    pose(b, 19, AIM)
    b.rest(27)
    pose(b, 27, CARRY, Torso=(8, 0, 0), Head=(-6, 0, 0))
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("AshRaider", RIFLE_JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=4000, hrp_center=(0, 0.0, 2.9), hrp_size=(2.0, 2.0, 1.0), step="A5",
          meta={"role": "Fighter", "band": "Surface", "hitTime": HIT_TIME},
          sockets={"Muzzle": ((-1.12, -3.1, 2.36), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
