"""Prop_Turret: the Engineer's Deploy Turret (bible Section 14; Prompt 20): it shoots the nearest
monster in range, and shocks at level 3. A Steadfast sentry gun on a tripod: gunmetal legs with
rubber feet, a steel swivel post, an olive housing with a hazard stripe and a teal plate, twin
chrome barrels in a gunmetal shroud, an ammo box with a brass belt, a crystal sensor eye (Neon)
and a red status lamp (Neon).

Pivot = bottom-centre. Sockets: Muzzle (between the barrels' tips). Faces Blender -Y: the code
turns the whole model to face its target.

Run:  SF_EXPORT=1 python3 generators/Props/Prop_Turret.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Weapons"))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Prop_Turret", "Props"
BUDGET = 1500
GUN_Z = 2.15


def build():
    T = "Turret"
    c = "box"
    for i in range(3):
        a = math.radians(90 + i * 120)
        foot = (math.cos(a) * 1.15, math.sin(a) * 1.15, 0.08)
        G.t(sf.tube([(0, 0, 1.3), ((foot[0]) * 0.55, foot[1] * 0.55, 0.75), foot], [0.07, 0.065, 0.06], sides=6, resolution=1), T, "gunmetal", collision=c)
        G.t(sf.cyl(0.13, 0.12, loc=(foot[0], foot[1], 0.06), verts=8, bevel=0.0), T, "rubber", collision=c)
    G.t(sf.cyl(0.32, 0.14, loc=(0, 0, 1.3), verts=10, bevel=0.03, segments=1), T, "gunmetal", collision=c)
    G.t(sf.cyl(0.14, 0.5, loc=(0, 0, 1.6), verts=8, bevel=0.0), T, "steel", collision=c)
    # the housing
    G.t(sf.box((0.95, 1.35, 0.72), loc=(0, 0.05, GUN_Z), bevel=0.12, segments=1), T, "olive", collision=c)
    G.t(sf.box((0.97, 0.16, 0.74), loc=(0, 0.45, GUN_Z), bevel=0.0), T, "hazard", collision=c)
    G.t(sf.box((0.02, 0.36, 0.2), loc=(0.48, 0.05, GUN_Z + 0.08), bevel=0.0), T, "teal", collision=c)
    # twin barrels in a shroud
    G.t(sf.box((0.6, 0.4, 0.42), loc=(0, -0.75, GUN_Z), bevel=0.06, segments=1), T, "gunmetal", collision=c)
    for x in (-0.15, 0.15):
        G.barrel(T, 0.085, -1.75, -0.9, GUN_Z, "chrome", x=x, verts=8)
        G.t(sf.cyl(0.05, 0.05, loc=(x, -1.77, GUN_Z), rot=(90, 0, 0), verts=6, bevel=0.0), T, "rubber", collision=c)
    G.band(T, 0.1, -1.4, GUN_Z, w=0.08, swatch="gunmetal", x=-0.15, verts=8)
    G.band(T, 0.1, -1.4, GUN_Z, w=0.08, swatch="gunmetal", x=0.15, verts=8)
    # ammo box and belt
    G.t(sf.box((0.36, 0.6, 0.46), loc=(-0.66, 0.15, GUN_Z - 0.12), bevel=0.04, segments=1), T, "olive", collision=c)
    for i in range(4):
        G.t(sf.box((0.08, 0.08, 0.2), loc=(-0.48 + 0.0, -0.1 + i * 0.12, GUN_Z + 0.16), bevel=0.0), T, "brass", collision=c)
    # sensor eye and status lamp
    G.t(sf.cyl(0.17, 0.08, loc=(0, -0.42, GUN_Z + 0.42), rot=(90, 0, 0), verts=10, bevel=0.0), T, "chrome", collision=c)
    G.t(sf.sphere(0.12, loc=(0, -0.47, GUN_Z + 0.42), segs=8, rings=5), "SensorEye", "crystal", "Neon", collision="none")
    G.t(sf.sphere(0.06, loc=(0.3, 0.3, GUN_Z + 0.4), segs=6, rings=4), "StatusLamp", "signal", "Neon", collision="none")
    return {"export": {"budget": BUDGET, "step": "P20", "sockets": {"Muzzle": ((0, -1.8, GUN_Z), 0.0)},
                       "meta": {"kind": "Device", "class": ["Engineer"]}}}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
