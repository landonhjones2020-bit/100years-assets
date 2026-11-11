"""Monster_Resonator: the Crystal Hollows support (bible Section 10: "Hums to heal and speed up
nearby monsters; kill it first"). A walking bell. Three long stilt legs carry a basalt hub; on
the hub sits a plum bell with a cracked rim, and out of the bell's mouth stands a ring of six
long crystal tines like the prongs of a tuning fork around a core of light. Under the hub
hangs a clapper: a crystal on a stalk. It never fights. When it hums, the tines spread and
shiver, the clapper swings and every monster near it is mended and quickened, so the tines
are the loudest shape in any pack.

About 7.6 studs to the tips of the tines and 5 across the feet.

Rig: Body (the hub, root), Bell, six Tines, Clapper, three legs with shins. Clips: Idle (a
slow bob, the tines breathing), Walk (a three-legged stalk), Attack (the hum: tines spread and
shiver for most of a second, Hit at 0.2 s).

Run:  SF_EXPORT=1 python3 generators/Monsters/Monster_Resonator.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import _beast as B  # noqa: E402
from _beast import sf, spike, limb, blob, shell, shard  # noqa: E402,F401

ASSET, CATEGORY = "Monster_Resonator", "Monsters"
HIT_TIME = 0.2
HUB_Z = 3.5
TINES = [(f"Tine{i + 1}", math.radians(30 + 60 * i)) for i in range(6)]
LEGS = [("Leg1", math.radians(90)), ("Leg2", math.radians(210)), ("Leg3", math.radians(330))]  # one behind, two in front
JOINTS = [
    ("Body", None, (0, 0, HUB_Z)),
    ("Bell", "Body", (0, 0, HUB_Z + 0.45)),
    ("Clapper", "Body", (0, 0, HUB_Z - 0.4)),
] + [(name, "Bell", (math.cos(a) * 0.62, math.sin(a) * 0.62, HUB_Z + 1.75)) for name, a in TINES] \
  + [(name, "Body", (math.cos(a) * 0.55, math.sin(a) * 0.55, HUB_Z)) for name, a in LEGS] \
  + [(name.replace("Leg", "Shin"), name, (math.cos(a) * 2.0, math.sin(a) * 2.0, HUB_Z + 1.15)) for name, a in LEGS]


def out(a, tilt):
    """Bone-space Euler that tilts a bone at angle `a` around the ring outward by `tilt` degrees."""
    return (-tilt * math.sin(a), 0, -tilt * math.cos(a))


def build(b):
    # ---- the hub: a basalt knuckle the legs and the bell hang on, a collar of small shards
    b.part(blob(0.75, (0, 0, HUB_Z), scale=(1.0, 1.0, 0.62), segs=10, rings=6, noise=0.05, seed=2), "Body", "basalt")
    b.part(sf.torus(0.72, 0.1, loc=(0, 0, HUB_Z + 0.12), major_segs=12, minor_segs=5), "Body", "stone")
    for i in range(9):
        a = math.tau * i / 9
        b.part(shard((math.cos(a) * 0.62, math.sin(a) * 0.62, HUB_Z - 0.1), (math.cos(a), math.sin(a), -0.75),
                     0.5 + 0.12 * (i % 3), 0.085, sides=4, tip=0.05), "Body", "crystal")
    for sx in (-1, 1):
        b.glow(sf.sphere(0.1, loc=(sx * 0.3, -0.66, HUB_Z + 0.05), scale=(1.0, 0.6, 1.0), segs=6, rings=4), "Body", "HeadGlow")
    b.part(sf.box((0.95, 0.16, 0.2), loc=(0, -0.66, HUB_Z + 0.05), bevel=0.02, segments=1), "Body", "rubber")   # its eye slot

    # ---- the bell: a plum cup, mouth up, rim cracked, bands round it
    profile = [(0.0, 0.0), (0.5, 0.02), (0.72, 0.3), (0.82, 0.8), (0.98, 1.25), (1.12, 1.42), (1.02, 1.46), (0.82, 1.2),
               (0.7, 0.75), (0.5, 0.36), (0.0, 0.3)]
    b.part(sf.lathe(profile, verts=14, loc=(0, 0, HUB_Z + 0.4)), "Bell", "plum")
    b.part(sf.torus(0.8, 0.07, loc=(0, 0, HUB_Z + 1.15), major_segs=14, minor_segs=4), "Bell", "basalt")
    b.part(sf.torus(1.07, 0.085, loc=(0, 0, HUB_Z + 1.82), major_segs=14, minor_segs=4), "Bell", "stone")
    for i in range(7):                                                                                 # chips of crystal in the rim
        a = math.tau * (i + 0.5) / 7
        b.part(shard((math.cos(a) * 1.05, math.sin(a) * 1.05, HUB_Z + 1.72), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.7),
                     0.36 + 0.1 * (i % 2), 0.075, sides=4, tip=0.05), "Bell", "crystal")
    for i in range(3):                                                                                 # cracks of light down its side
        a = math.tau * i / 3 + 0.5
        pts = [(math.cos(a + k * 0.1) * r, math.sin(a + k * 0.1) * r, HUB_Z + z)
               for k, (r, z) in enumerate(((1.1, 1.75), (0.99, 1.42), (0.9, 1.05), (0.84, 0.72)))]
        b.neon(limb(pts, [0.03, 0.045, 0.035, 0.02], sides=3, resolution=1), "Bell", "BellGlow")
    b.neon(blob(0.4, (0, 0, HUB_Z + 1.55), scale=(1.0, 1.0, 1.25), segs=8, rings=6, seed=3), "Bell", "CoreGlow")  # the hum's heart

    # ---- the tines: six long prongs standing out of the bell's mouth
    for i, (name, a) in enumerate(TINES):
        base = sf.Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, HUB_Z + 1.5))
        ln = 3.3 if i % 2 == 0 else 2.7
        d = sf.Vector((math.cos(a) * 0.1, math.sin(a) * 0.1, 1.0))
        b.part(shard(base, d, ln, 0.17, sides=6, tip=0.3, waist=0.12, twist=0.3 * i), name, "crystal")
        b.part(sf.torus(0.19, 0.045, loc=base + d * 0.35, major_segs=8, minor_segs=3), name, "basalt")   # a collar at its root
        b.neon(shard(base + d.normalized() * (ln - 0.05), d, 0.34, 0.07, sides=5), name, "TineGlow")

    # ---- the clapper: a stalk and a crystal, hanging between the legs
    b.part(limb([(0, 0, HUB_Z - 0.35), (0, 0, HUB_Z - 1.0), (0, 0, HUB_Z - 1.6)], [0.09, 0.06, 0.07], sides=5, resolution=1),
           "Clapper", "basalt")
    b.part(shard((0, 0, HUB_Z - 1.45), (0, 0, -1.0), 1.15, 0.3, sides=6, tip=0.1, waist=0.4), "Clapper", "crystal")
    b.neon(sf.sphere(0.1, loc=(0, 0, HUB_Z - 2.62), segs=6, rings=4), "Clapper", "ClapperGlow")

    # ---- three stilt legs: up and out to a knee above the hub, straight down to a crystal point
    for name, a in LEGS:
        shin = name.replace("Leg", "Shin")
        c, s = math.cos(a), math.sin(a)
        hip = sf.Vector((c * 0.55, s * 0.55, HUB_Z))
        knee = sf.Vector((c * 2.0, s * 2.0, HUB_Z + 1.15))
        foot = sf.Vector((c * 2.45, s * 2.45, 0.02))
        b.part(limb([hip, (hip + knee) / 2 + sf.Vector((0, 0, 0.18)), knee], [0.2, 0.15, 0.12], sides=6, resolution=2),
               name, "basalt")
        b.part(shard(hip + sf.Vector((c * 0.5, s * 0.5, 0.55)), (c * 0.6, s * 0.6, 1.0), 0.6, 0.1, sides=4), name, "crystal")
        b.part(blob(0.2, knee, scale=(1.0, 1.0, 1.1), segs=6, rings=4, seed=5), shin, "stone")
        b.part(shard(knee, (c * 0.5, s * 0.5, 1.0), 0.7, 0.11, sides=4, tip=0.05), shin, "crystal")              # knee spur
        mid = knee + (foot - knee) * 0.62
        b.part(limb([knee, knee + (foot - knee) * 0.3 + sf.Vector((c * 0.1, s * 0.1, 0)), mid], [0.12, 0.1, 0.09],
                    sides=5, resolution=1), shin, "basalt")
        b.part(shard(mid - (foot - mid) * 0.06, foot - mid, (foot - mid).length * 1.06, 0.12, sides=5, tip=0.03, waist=0.2),
               shin, "crystal")
        b.part(sf.torus(0.13, 0.04, loc=mid, major_segs=7, minor_segs=3), shin, "stone")


def pose_tines(b, f, spread, shiver=0.0):
    for i, (name, a) in enumerate(TINES):
        b.key(name, f, out(a, spread + shiver * (1 if i % 2 == 0 else -1)))


def idle(b):
    act = sf.new_action(b.arm, "Idle", 0, 80, loop=True, priority="Idle")
    for f, k in ((0, 0), (20, 1), (40, 0), (60, -1), (80, 0)):
        b.key("Body", f, (0, 0, 0), loc=(0, 0.1 * abs(k), 0))
        b.key("Bell", f, (2 * k, 0, 2 * abs(k)))
        b.key("Clapper", f, (7 * k, 0, 4 * k))
        pose_tines(b, f, 3 * abs(k))
        for name, a in LEGS:
            b.key(name, f, out(a, -2.5 * abs(k)))
            b.key(name.replace("Leg", "Shin"), f, out(a, 2.5 * abs(k)))
    return act


def walk(b):
    """Each leg in turn lifts, reaches forward (toward -Y) and plants; the bell sways on top."""
    act = sf.new_action(b.arm, "Walk", 0, 36, loop=True, priority="Movement")
    for f in range(0, 37, 4):
        t = f / 36.0
        b.key("Body", f, (3, 0, 3 * math.sin(math.tau * t)), loc=(0, 0.08 * math.sin(math.tau * t * 3), 0))
        b.key("Bell", f, (-4 + 3 * math.sin(math.tau * t * 3), 0, -4 * math.sin(math.tau * t)))
        b.key("Clapper", f, (-12 * math.sin(math.tau * t * 3), 0, 6 * math.sin(math.tau * t)))
        pose_tines(b, f, 2 + 2 * math.sin(math.tau * t * 3))
        for i, (name, a) in enumerate(LEGS):
            phase = math.tau * (t - i / 3.0)
            swing = 11 * math.cos(phase)                    # forward and back
            lift = 9 * max(math.sin(phase), 0)              # up as it comes forward
            ox, _oy, oz = out(a, lift)
            b.key(name, f, (ox + swing, 0, oz))
            sx, _sy, sz = out(a, -lift * 0.8)
            b.key(name.replace("Leg", "Shin"), f, (sx - swing * 0.5, 0, sz))
    return act


def attack(b):
    """The hum."""
    act = sf.new_action(b.arm, "Attack", 0, 30, loop=False, priority="Action")
    b.rest(0)
    b.key("Body", 4, (0, 0, 0), loc=(0, -0.3, 0))                        # squats
    b.key("Bell", 4, (0, 0, 0))
    pose_tines(b, 4, -4)
    b.key("Body", 6, (0, 0, 0), loc=(0, 0.25, 0), ease="QUAD")           # and rings: the hum goes out at 0.2 s
    pose_tines(b, 6, 20)
    b.key("Clapper", 6, (26, 0, 0), ease="QUAD")
    for f in range(8, 24, 2):                                            # the tines shiver, the clapper swings
        k = 1 if (f // 2) % 2 == 0 else -1
        pose_tines(b, f, 18, 4 * k)
        b.key("Clapper", f, (-20 * k, 0, 8 * k))
        b.key("Bell", f, (1.5 * k, 0, -1.5 * k))
        b.key("Body", f, (0, 0, 0), loc=(0, 0.2 + 0.03 * k, 0))
    for name, a in LEGS:
        b.key(name, 4, out(a, 6))
        b.key(name.replace("Leg", "Shin"), 4, out(a, -6))
        b.key(name, 6, out(a, -4))
        b.key(name.replace("Leg", "Shin"), 6, out(a, 4))
        b.key(name, 24, out(a, -3))
        b.key(name.replace("Leg", "Shin"), 24, out(a, 3))
    b.rest(30)
    return act


if __name__ == "__main__":
    B.run(ASSET, CATEGORY, lambda: B.Beast("Resonator", JOINTS), build, lambda b: [idle(b), walk(b), attack(b)],
          budget=3400, hrp_center=(0, 0, HUB_Z), hrp_size=(2.0, 2.0, 2.0), step="A10",
          meta={"role": "Support", "band": "CrystalHollows", "hitTime": HIT_TIME},
          sockets={"Hum": ((0, 0, HUB_Z + 1.55), 0.0)}, markers={"Attack": {"Hit": HIT_TIME}})
