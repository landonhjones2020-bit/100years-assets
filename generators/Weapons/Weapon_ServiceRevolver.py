"""Weapon_ServiceRevolver: heavy single shots (bible Section 27); the Security and Warden
starting gun. A chunky 1950s service revolver: gunmetal frame and barrel, a chrome cylinder
with its six chambers showing, walnut grip with brass medallions.

Pivot = the grip, where the hand closes, so the Tool's grip offset is zero. Sockets: Grip
(the pivot) and Muzzle (barrel tip, facing forward, for tracers and flashes).
Front (the muzzle) faces Blender -Y, so in Roblox the gun points down LookVector.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_ServiceRevolver.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

ASSET, CATEGORY = "Weapon_ServiceRevolver", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.16)          # where the hand closes
MUZZLE_Y, BORE_Z = -1.5, 0.68


def build():
    q = "query"   # held weapons: no collision, but raycasts and taps can find them
    sf.tag(sf.box((0.34, 0.86, 0.44), loc=(0, -0.04, 0.6), bevel=0.07, segments=1), "Revolver", "gunmetal", collision=q)
    sf.tag(sf.box((0.26, 0.5, 0.16), loc=(0, -0.08, 0.86), bevel=0.05, segments=1), "Revolver", "gunmetal", collision=q)
    # cylinder: chrome, with six chamber mouths on its front face
    sf.tag(sf.cyl(0.26, 0.52, loc=(0, -0.24, 0.62), rot=(90, 0, 0), verts=12, bevel=0.04, segments=1), "Revolver", "chrome", collision=q)
    for i in range(6):
        a = math.radians(30 + 60 * i)
        sf.tag(sf.cyl(0.055, 0.06, loc=(math.cos(a) * 0.15, -0.51, 0.62 + math.sin(a) * 0.15), rot=(90, 0, 0),
                      verts=6, bevel=0.0), "Revolver", "rubber", collision=q)
    # barrel, rib, front sight, muzzle ring, ejector rod
    sf.tag(sf.cyl(0.13, 1.0, loc=(0, -1.0, BORE_Z), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), "Revolver", "gunmetal", collision=q)
    sf.tag(sf.box((0.1, 1.0, 0.08), loc=(0, -1.0, BORE_Z + 0.13), bevel=0.0), "Revolver", "gunmetal", collision=q)
    sf.tag(sf.box((0.06, 0.12, 0.12), loc=(0, MUZZLE_Y + 0.08, BORE_Z + 0.2), bevel=0.0), "Revolver", "steel", collision=q)
    sf.tag(sf.cyl(0.15, 0.08, loc=(0, MUZZLE_Y + 0.04, BORE_Z), rot=(90, 0, 0), verts=10, bevel=0.0), "Revolver", "chrome", collision=q)
    sf.tag(sf.cyl(0.05, 0.08, loc=(0, MUZZLE_Y - 0.01, BORE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), "Revolver", "rubber", collision=q)
    sf.tag(sf.cyl(0.065, 0.7, loc=(0, -0.85, 0.48), rot=(90, 0, 0), verts=6, bevel=0.0), "Revolver", "steel", collision=q)
    # hammer, trigger guard, trigger
    sf.tag(sf.box((0.12, 0.2, 0.22), loc=(0, 0.42, 0.86), rot=(-30, 0, 0), bevel=0.03, segments=1), "Revolver", "steel", collision=q)
    sf.tag(sf.torus(0.2, 0.04, loc=(0, -0.02, 0.32), rot=(0, 90, 0), major_segs=12, minor_segs=4), "Revolver", "gunmetal", collision=q)
    sf.tag(sf.box((0.05, 0.07, 0.2), loc=(0, 0.02, 0.33), rot=(16, 0, 0), bevel=0.0), "Revolver", "steel", collision=q)
    # walnut grip, angled back, with brass medallions and a gunmetal butt cap
    sf.tag(sf.box((0.3, 0.44, 0.9), loc=GRIP, rot=(-18, 0, 0), bevel=0.1, segments=1), "Revolver", "walnut", collision=q)
    for sx in (-1, 1):
        sf.tag(sf.cyl(0.07, 0.04, loc=(sx * 0.16, 0.3, 0.22), rot=(0, 90, 0), verts=8, bevel=0.0), "Revolver", "brass", collision=q)
    sf.tag(sf.box((0.32, 0.46, 0.1), loc=(0, 0.155, -0.31), rot=(-18, 0, 0), bevel=0.03, segments=1), "Revolver", "gunmetal", collision=q)
    return {"export": {
        "budget": BUDGET, "step": "A0", "pivot": GRIP,
        "sockets": {"Grip": (GRIP, 0.0), "Muzzle": ((0, MUZZLE_Y - 0.06, BORE_Z), 0.0)},
        "meta": {"kind": "Gun", "ammoPerShot": 1, "class": ["Security", "Warden"]},
    }}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
