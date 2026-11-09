"""Weapon_PocketPistol: light ammo, quick (bible Section 27); the Survivor's starting gun, and the
Medic's, Cook's, Radio Operator's and Marksman's sidearm. A compact 1950s automatic: a steel slide
with gunmetal serrations over a gunmetal frame, a short barrel showing at the muzzle, a teal
enamel stripe on the slide (Steadfast's colour), and a grip that rakes BACK from the frame
(its butt behind its top, about 16 degrees, like a real pistol's): a gunmetal grip frame showing
as straps round the front, back and butt, hard-rubber panels with brass medallions, a small
beavertail under the hammer and a flush steel magazine base.

v2 (Nov 8, 2026, Landon: "you keep messing up the gun handles"): v1's grip leaned the wrong
way (its butt pointed forward, toward the muzzle) and its magazine heel stuck out behind like
a foot. The grip is now a side profile, like the revolver's v2 grip, checked from the side.

Pivot = the grip, where the hand closes (a third of the way down the grip, on its axis), so
the grip offset is zero. Sockets: Grip (the pivot) and Muzzle (barrel tip, facing forward, for
tracers and flashes). Front (the muzzle) faces Blender -Y, so in Roblox the gun points down
LookVector.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_PocketPistol.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Weapon_PocketPistol", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.28, 0.15)          # where the hand closes: on the grip's axis, a third of the way down
MUZZLE_Y, BORE_Z = -0.92, 0.58


def build():
    q = "query"   # held weapons: no collision, but raycasts and taps can find them
    # slide: steel, with gunmetal serrations at the back and a teal enamel stripe
    sf.tag(sf.box((0.3, 1.22, 0.3), loc=(0, -0.26, 0.6), bevel=0.06, segments=1), "Pistol", "steel", collision=q)
    for i in range(4):
        sf.tag(sf.box((0.32, 0.04, 0.2), loc=(0, 0.2 + i * 0.075 - 0.11, 0.62), bevel=0.0), "Pistol", "gunmetal", collision=q)
    sf.tag(sf.box((0.31, 0.62, 0.06), loc=(0, -0.42, 0.62), bevel=0.0), "Pistol", "teal", collision=q)
    # sights
    sf.tag(sf.box((0.06, 0.08, 0.08), loc=(0, MUZZLE_Y + 0.12, 0.78), bevel=0.0), "Pistol", "gunmetal", collision=q)
    sf.tag(sf.box((0.18, 0.06, 0.08), loc=(0, 0.28, 0.78), bevel=0.0), "Pistol", "gunmetal", collision=q)
    # barrel showing at the muzzle
    sf.tag(sf.cyl(0.1, 0.08, loc=(0, MUZZLE_Y + 0.03, BORE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Pistol", "chrome", collision=q)
    sf.tag(sf.cyl(0.05, 0.06, loc=(0, MUZZLE_Y - 0.01, BORE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Pistol", "rubber", collision=q)
    # frame: under the slide, the dust cover and trigger guard
    sf.tag(sf.box((0.26, 0.8, 0.16), loc=(0, -0.2, 0.38), bevel=0.04, segments=1), "Pistol", "gunmetal", collision=q)
    sf.tag(sf.torus(0.16, 0.035, loc=(0, -0.08, 0.22), rot=(0, 90, 0), major_segs=10, minor_segs=4), "Pistol", "gunmetal", collision=q)
    sf.tag(sf.box((0.05, 0.06, 0.16), loc=(0, -0.05, 0.24), rot=(14, 0, 0), bevel=0.0), "Pistol", "steel", collision=q)
    # hammer spur
    sf.tag(sf.box((0.1, 0.12, 0.12), loc=(0, 0.38, 0.72), rot=(-25, 0, 0), bevel=0.02, segments=1), "Pistol", "gunmetal", collision=q)
    # grip: a side profile (Y back, Z up). It hangs from the frame behind the trigger guard and
    # rakes BACK, so the butt is behind the top (+Y = toward the shooter), about 16 degrees.
    def side(points, thickness):
        # profile_slab extrudes along local Z; rot (90, 0, 90) maps local X->Y, Y->Z, Z->X
        return sf.profile_slab(points, thickness, loc=(-thickness / 2, 0, 0), rot=(90, 0, 90), bevel=0.04, segments=2)

    grip = [(0.00, 0.44), (0.03, 0.24), (0.09, 0.02), (0.16, -0.20), (0.22, -0.38), (0.25, -0.45),
            (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.56, -0.20), (0.49, 0.04), (0.43, 0.26),
            (0.41, 0.40), (0.47, 0.48), (0.40, 0.53), (0.10, 0.50)]

    def grown(points, d):
        cy = sum(p[0] for p in points) / len(points)
        cz = sum(p[1] for p in points) / len(points)
        out = []
        for y, z in points:
            vy, vz = y - cy, z - cz
            n = math.hypot(vy, vz) or 1.0
            out.append((y + vy / n * d, z + vz / n * d))
        return out

    # the gunmetal grip frame shows round the edges (thin, a little bigger); the rubber panels
    # cover both sides (thick, the plain outline)
    sf.tag(side(grown(grip, 0.025), 0.16), "Pistol", "gunmetal", collision=q)
    sf.tag(side(grip, 0.27), "Pistol", "rubber", collision=q)
    for sx in (-1, 1):
        sf.tag(sf.cyl(0.05, 0.03, loc=(sx * 0.14, 0.3, 0.12), rot=(0, 90, 0), verts=10, bevel=0.0), "Pistol", "brass", collision=q)
    # the magazine base: a steel plate flush with the butt, square to the grip
    base = [(0.25, -0.45), (0.29, -0.49), (0.55, -0.42), (0.59, -0.36), (0.585, -0.33), (0.255, -0.415)]
    sf.tag(side(grown(base, 0.012), 0.24), "Pistol", "steel", collision=q)
    return {"export": {
        "budget": BUDGET, "step": "P11", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
        "meta": {"kind": "Gun", "ammoPerShot": 1, "class": ["Survivor", "Medic", "Cook", "RadioOperator", "Marksman"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
