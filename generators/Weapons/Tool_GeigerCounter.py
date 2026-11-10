"""Tool_GeigerCounter: shows radiation and hazards nearby (bible Appendix); the Hazmat Tech's
tool. A 1950s survey meter held like a pistol: a hazard-yellow case with a cream dial, brass
bezel and needle facing the player, two Bakelite knobs, a rubber speaker grille, a navy label
plate, and a steel probe forward on a coiled lead.

Pivot = the grip. Sockets: Grip and Muzzle (the probe's tip). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Tool_GeigerCounter.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Tool_GeigerCounter", "Weapons"
BUDGET = 1500
GRIP = (0.0, 0.3, 0.0)
PROBE_Z = 0.5


def build():
    C = "Geiger"
    G.t(sf.box((0.52, 0.95, 0.52), loc=(0, -0.05, 0.64), bevel=0.07, segments=1), C, "hazard")
    G.t(sf.box((0.53, 0.97, 0.08), loc=(0, -0.05, 0.42), bevel=0.0), C, "gunmetal")
    # the dial on the back face, toward the player
    G.t(sf.cyl(0.19, 0.04, loc=(0, 0.44, 0.68), rot=(90, 0, 0), verts=12, bevel=0.0), C, "cream")
    G.t(sf.torus(0.19, 0.025, loc=(0, 0.45, 0.68), rot=(90, 0, 0), major_segs=12, minor_segs=3), C, "brass")
    G.t(sf.box((0.02, 0.02, 0.16), loc=(0.04, 0.47, 0.72), rot=(0, 30, 0), bevel=0.0), C, "rust")
    for i in range(5):
        a = math.radians(-60 + i * 30)
        G.t(sf.box((0.015, 0.02, 0.04), loc=(math.sin(a) * 0.15, 0.465, 0.68 + math.cos(a) * 0.15), rot=(0, math.degrees(a), 0),
                   bevel=0.0), C, "navy")
    # knobs, grille, label
    for x in (-0.13, 0.13):
        G.t(sf.cyl(0.06, 0.07, loc=(x, 0.2, 0.93), verts=8, bevel=0.0), C, "rubber")
    for i in range(3):
        G.t(sf.box((0.02, 0.4, 0.04), loc=(0.26, -0.15, 0.56 + i * 0.09), bevel=0.0), C, "rubber")
    G.t(sf.box((0.02, 0.3, 0.12), loc=(-0.26, -0.1, 0.68), bevel=0.0), C, "navy")
    # the probe: a steel wand forward, a chrome cap, a coiled lead back into the case
    G.barrel(C, 0.07, -1.25, -0.5, PROBE_Z, "steel", verts=8)
    G.t(sf.cyl(0.085, 0.1, loc=(0, -1.27, PROBE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), C, "chrome")
    G.t(sf.cyl(0.08, 0.2, loc=(0, -0.6, PROBE_Z), rot=(90, 0, 0), verts=8, bevel=0.0), C, "rubber")
    pts = [(0.0, -0.52, PROBE_Z - 0.06), (0.06, -0.58, PROBE_Z - 0.2), (-0.06, -0.62, PROBE_Z - 0.3),
           (0.04, -0.66, PROBE_Z - 0.36), (0.0, -0.56, PROBE_Z - 0.12)]
    G.t(sf.tube(pts, [0.03] * len(pts), sides=4, resolution=2), C, "navy")
    G.trigger_guard(C, 0.05, 0.24, r=0.15)
    G.pistol_grip(C, GRIP, frame="gunmetal", panel="rubber", medallion="brass")
    return G.exports(BUDGET, "P20", GRIP, {"Muzzle": ((0, -1.33, PROBE_Z), 0.0)}, {"kind": "Tool", "class": ["HazmatTech"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
