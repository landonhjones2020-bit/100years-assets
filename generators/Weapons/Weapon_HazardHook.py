"""Weapon_HazardHook: the Hazmat Tech's melee weapon (bible Appendix: long reach). A
hazardous-material pole hook: a hazard-yellow pole with black bands, a rubber grip and an end
knob, a brass collar, and a steel head with a straight spike and a curved hook.

Pivot = the grip. Sockets: Grip and Tip (the spike). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Weapon_HazardHook.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Weapon_HazardHook", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.45, 0.0)
TIP_Y = -2.9


def build():
    H = "Hook"
    G.barrel(H, 0.09, -2.25, 0.95, 0.0, "hazard", verts=8)
    for i in range(5):
        G.band(H, 0.096, -1.95 + i * 0.36, 0.0, w=0.14, swatch="rubber", verts=8)
    G.wrap(H, 0.11, 0.1, 0.9, 0.0, rings=4, swatch="rubber")
    G.t(sf.sphere(0.15, loc=(0, 0.98, 0), segs=8, rings=5), H, "rubber")
    G.band(H, 0.12, -2.23, 0.0, w=0.14, swatch="brass")
    # the head: a steel socket, a straight spike forward and a hook curling up and back
    G.shifted(0.45, hook_head)
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, TIP_Y, 0), 0.0)}, {"kind": "Melee", "class": ["HazmatTech"]})


def hook_head():
    H = "Hook"
    G.t(sf.cyl(0.11, 0.3, loc=(0, -2.88, 0), rot=(90, 0, 0), verts=8, bevel=0.02, segments=1), H, "steel")
    G.t(sf.lathe([(0.075, 0.0), (0.06, 0.25), (0.0, 0.42)], verts=8, loc=(0, -3.0, 0), rot=(90, 0, 0)), H, "chrome")
    hook = [(0, -2.98, 0.08), (0, -3.08, 0.3), (0, -3.0, 0.55), (0, -2.78, 0.62), (0, -2.62, 0.48), (0, -2.64, 0.36)]
    G.t(sf.tube(hook, [0.06, 0.055, 0.05, 0.045, 0.04, 0.025], sides=6, resolution=3), H, "chrome")


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
