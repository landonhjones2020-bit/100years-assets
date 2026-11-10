"""Weapon_Flamethrower: a short cone of fire (bible Appendix); the Exterminator's gun, held
two-handed. A 1950s pest-control flame gun: a rust-red fuel tank strapped on top with hazard
stripes and a brass pressure gauge facing the player, a gunmetal valve body with a brass wheel,
a steel wand with a perforated heat shield, a brass nozzle and an orange pilot flame (Neon),
a rubber foregrip and a rubber pistol grip.

Pivot = the right hand's grip. Sockets: Grip, Support (the foregrip) and Muzzle (the nozzle).
Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_Flamethrower.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_Flamethrower", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
SUPPORT = G.support_from(GRIP)
BORE_Z, MUZZLE_Y = 0.55, -2.6


def build():
    F = "Flamer"
    # valve body and wheel
    G.t(sf.box((0.3, 0.8, 0.36), loc=(0, -0.12, 0.52), bevel=0.06, segments=1), F, "gunmetal")
    G.t(sf.torus(0.13, 0.03, loc=(0.2, -0.3, 0.52), rot=(0, 90, 0), major_segs=8, minor_segs=3), F, "brass")
    G.t(sf.box((0.03, 0.24, 0.03), loc=(0.2, -0.3, 0.52), bevel=0.0), F, "brass")
    # the wand, heat shield and nozzle
    G.barrel(F, 0.085, -2.28, -0.5, BORE_Z, "steel")
    G.barrel(F, 0.15, -1.98, -1.22, BORE_Z, "gunmetal", verts=10)
    for sx in (-1, 1):
        for i in range(3):
            G.t(sf.cyl(0.035, 0.02, loc=(sx * 0.15, -1.8 + i * 0.24, BORE_Z), rot=(0, 90, 0), verts=6, bevel=0.0), F, "rubber")
    G.t(sf.lathe([(0.09, 0.0), (0.14, 0.18), (0.17, 0.32), (0.12, 0.32), (0.0, 0.3)], verts=10,
                 loc=(0, -2.28, BORE_Z), rot=(90, 0, 0)), F, "brass")
    # pilot light under the nozzle
    G.t(sf.box((0.1, 0.16, 0.12), loc=(0, -2.38, BORE_Z - 0.2), bevel=0.02, segments=1), F, "chrome")
    G.t(sf.sphere(0.07, loc=(0, -2.5, BORE_Z - 0.2), scale=(1, 1.4, 1.2), segs=6, rings=4), "PilotFlame", "signal", "Neon")
    # the fuel tank on top: rust red, chrome caps, hazard bands, straps and a gauge at the back
    G.t(sf.cyl(0.21, 0.95, loc=(0, -0.62, 0.95), rot=(90, 0, 0), verts=12, bevel=0.06, segments=1), F, "rust")
    for y in (-1.1, -0.14):
        G.t(sf.cyl(0.17, 0.06, loc=(0, y, 0.95), rot=(90, 0, 0), verts=12, bevel=0.0), F, "chrome")
    G.t(sf.cyl(0.215, 0.1, loc=(0, -0.95, 0.95), rot=(90, 0, 0), verts=12, bevel=0.0), F, "hazard")
    for y in (-0.85, -0.38):
        G.t(sf.box((0.1, 0.08, 0.3), loc=(0, y, 0.73), bevel=0.0), F, "gunmetal")
    G.t(sf.cyl(0.12, 0.05, loc=(0, -0.1, 1.06), rot=(90, 0, 0), verts=12, bevel=0.0), F, "brass")
    G.t(sf.cyl(0.1, 0.02, loc=(0, -0.07, 1.06), rot=(90, 0, 0), verts=12, bevel=0.0), F, "cream")
    G.t(sf.box((0.015, 0.01, 0.08), loc=(0.02, -0.05, 1.08), rot=(0, 30, 0), bevel=0.0), F, "rust")
    # foregrip, trigger guard, grip
    G.t(sf.cyl(0.09, 0.5, loc=(0, SUPPORT[1], 0.17), verts=8, bevel=0.03, segments=1), F, "rubber")
    G.t(sf.box((0.14, 0.18, 0.08), loc=(0, SUPPORT[1], 0.43), bevel=0.02, segments=1), F, "gunmetal")
    G.trigger_guard(F, 0.05, 0.24, r=0.15)
    G.pistol_grip(F, GRIP, frame="gunmetal", panel="rubber", medallion="brass")
    return G.exports(BUDGET, "P20", GRIP, {"Support": (SUPPORT, 0.0), "Muzzle": ((0, MUZZLE_Y, BORE_Z), 0.0)},
                     {"kind": "Gun", "hold": "TwoHanded", "ammoPerShot": 1, "class": ["Exterminator"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
