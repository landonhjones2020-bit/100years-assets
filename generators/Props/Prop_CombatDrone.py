"""Prop_CombatDrone: the Tinkerer's drone (bible Section 14: a companion that shoots and picks up
loot; Drone Mode Guard, Assault or Repair; a second gun at level 3). A 1950s flying saucer
drone: a brass dome over a teal enamel rim with a chrome band, four gunmetal arms to steel
rotor rings with rubber blades, a crystal eye in a chrome bezel at the front (Neon), twin
gunmetal guns under the chin, and a chrome aerial with a red ball.

Pivot = the body's centre (it flies). Sockets: Muzzle and Muzzle2 (the guns' tips), Eye.
Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Props/Prop_CombatDrone.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Weapons"))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Prop_CombatDrone", "Props"
BUDGET = 1500


def build():
    D = "Drone"
    c = "query"
    G.t(sf.lathe([(0.0, -0.22), (0.5, -0.2), (0.72, -0.06), (0.72, 0.04), (0.0, 0.04)], verts=12), D, "teal", collision=c)
    G.t(sf.lathe([(0.56, 0.0), (0.5, 0.12), (0.3, 0.3), (0.0, 0.34)], verts=12), D, "brass", collision=c)
    G.t(sf.cyl(0.735, 0.06, loc=(0, 0, -0.01), verts=12, bevel=0.0), D, "chrome", collision=c)
    G.t(sf.cyl(0.24, 0.06, loc=(0, 0, -0.24), verts=10, bevel=0.0), D, "gunmetal", collision=c)
    # arms and rotors
    for i in range(4):
        a = math.radians(45 + i * 90)
        cx, cy = math.cos(a), math.sin(a)
        G.t(sf.box((0.5, 0.12, 0.08), loc=(cx * 0.85, cy * 0.85, 0.0), rot=(0, 0, math.degrees(a)), bevel=0.0), D, "gunmetal", collision=c)
        G.t(sf.torus(0.3, 0.04, loc=(cx * 1.15, cy * 1.15, 0.02), major_segs=10, minor_segs=3), D, "steel", collision=c)
        G.t(sf.cyl(0.05, 0.1, loc=(cx * 1.15, cy * 1.15, 0.02), verts=6, bevel=0.0), D, "rubber", collision=c)
        for k in (0, 90):
            G.t(sf.box((0.5, 0.06, 0.015), loc=(cx * 1.15, cy * 1.15, 0.06), rot=(0, 0, math.degrees(a) + k + 20), bevel=0.0),
                D, "rubber", collision=c)
    # the eye
    G.t(sf.cyl(0.17, 0.08, loc=(0, -0.66, -0.06), rot=(90, 0, 0), verts=10, bevel=0.0), D, "chrome", collision=c)
    G.t(sf.sphere(0.12, loc=(0, -0.7, -0.06), segs=8, rings=5), "Eye", "crystal", "Neon", collision="none")
    # twin guns under the chin
    for x in (-0.18, 0.18):
        G.t(sf.box((0.14, 0.3, 0.14), loc=(x, -0.35, -0.3), bevel=0.02, segments=1), D, "gunmetal", collision=c)
        G.barrel(D, 0.05, -0.85, -0.45, -0.3, "gunmetal", x=x, verts=6, bevel=0.0)
    # aerial
    G.t(sf.cyl(0.02, 0.4, loc=(0.18, 0.2, 0.45), verts=4, bevel=0.0), D, "chrome", collision=c)
    G.t(sf.sphere(0.05, loc=(0.18, 0.2, 0.66), segs=6, rings=4), D, "signal", collision=c)
    return {"export": {"budget": BUDGET, "step": "P20", "pivot": (0, 0, 0),
                       "sockets": {"Muzzle": ((0.18, -0.87, -0.3), 0.0), "Muzzle2": ((-0.18, -0.87, -0.3), 0.0),
                                   "Eye": ((0, -0.8, -0.06), 0.0)},
                       "meta": {"kind": "Device", "class": ["Tinkerer"]}}}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
