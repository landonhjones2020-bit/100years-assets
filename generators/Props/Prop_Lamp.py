"""Prop_Lamp: a placeable lamp for dark rooms and caves (bible Appendix; crafted or found). A
Steadfast work light on a tripod: steel legs with rubber feet, a chrome pole, an olive battery
box with a brass terminal and a rubber lead up the pole, and a hazard-yellow shade over a caged
warm bulb (Neon).

Pivot = bottom-centre. Sockets: Light (the bulb, for a PointLight). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Props/Prop_Lamp.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Weapons"))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Prop_Lamp", "Props"
BUDGET = 800
TOP = 3.9


def build():
    L = "Lamp"
    c = "box"
    for i in range(3):
        a = math.radians(30 + i * 120)
        foot = (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.05)
        G.t(sf.tube([(0, 0, 1.5), foot], [0.05, 0.05], sides=4, resolution=1), L, "steel", collision=c)
        G.t(sf.cyl(0.09, 0.08, loc=(foot[0], foot[1], 0.04), verts=6, bevel=0.0), L, "rubber", collision=c)
    G.t(sf.cyl(0.055, TOP - 1.4, loc=(0, 0, 1.4 + (TOP - 1.4) / 2), verts=6, bevel=0.0), L, "chrome", collision=c)
    G.t(sf.cyl(0.1, 0.16, loc=(0, 0, 1.5), verts=6, bevel=0.0), L, "brass", collision=c)
    # battery box between the legs, a lead up the pole
    G.t(sf.box((0.6, 0.4, 0.4), loc=(0, 0.25, 0.2), bevel=0.04, segments=1), L, "olive", collision=c)
    G.t(sf.cyl(0.04, 0.08, loc=(0.18, 0.25, 0.44), verts=6, bevel=0.0), L, "brass", collision=c)
    G.t(sf.tube([(0.18, 0.25, 0.46), (0.12, 0.12, 0.9), (0.07, 0.03, 1.6), (0.07, 0.0, 2.4)], [0.03] * 4, sides=4, resolution=2),
        L, "rubber", collision=c)
    # the head: a yoke, a hazard shade tipped forward and down, a caged bulb
    tilt = 35
    head = (0, -0.1, TOP + 0.1)
    G.t(sf.box((0.6, 0.08, 0.08), loc=(0, 0, TOP), bevel=0.0), L, "gunmetal", collision=c)
    shade = sf.lathe([(0.12, 0.0), (0.2, 0.05), (0.42, 0.42), (0.36, 0.42), (0.14, 0.08), (0.0, 0.08)], verts=12)
    shade.location = head
    shade.rotation_euler = (math.radians(90 + tilt), 0, 0)
    G.t(shade, L, "hazard", collision=c)
    d = (0, -math.cos(math.radians(tilt)), -math.sin(math.radians(tilt)))
    bulb = (head[0], head[1] + d[1] * 0.3, head[2] + d[2] * 0.3)
    G.t(sf.sphere(0.15, loc=bulb, segs=8, rings=5), "Bulb", "hazard", "Neon", collision="none")
    for k in (0.36, 0.46):
        ring = sf.torus(0.2, 0.015, loc=(head[0], head[1] + d[1] * k, head[2] + d[2] * k), major_segs=8, minor_segs=3)
        ring.rotation_euler = (math.radians(90 + tilt), 0, 0)
        G.t(ring, L, "steel", collision=c)
    return {"export": {"budget": BUDGET, "step": "P20", "sockets": {"Light": (bulb, 0.0)}, "meta": {"kind": "Placeable"}}}


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
