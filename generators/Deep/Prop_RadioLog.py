"""Prop_RadioLog: a radio log, found in the Deep and on the surface (A6; bible Sections 3 and 12: the
company's cover-up comes out piece by piece; logs hint where the Lost Crews are). A field
recorder in a leather case: two tape reels, a brass dial and a hazard-tagged label. 1.4 x 0.9 x
0.7; pivot its foot, front (-Y) the reels.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    sf.tag(sf.box((1.4, 0.9, 0.55), loc=(0, 0, 0.28), bevel=0.0), "Case", "leather", collision="box")
    sf.tag(sf.box((1.3, 0.8, 0.1), loc=(0, 0, 0.6), bevel=0.0), "Deck", "gunmetal")
    for x in (-0.35, 0.35):
        sf.tag(sf.cyl(0.24, 0.06, loc=(x, -0.05, 0.68), verts=8, bevel=0.0), "Reels", "chrome")
        sf.tag(sf.cyl(0.08, 0.08, loc=(x, -0.05, 0.71), verts=6, bevel=0.0), "Hubs", "navy")
    sf.tag(sf.cyl(0.09, 0.08, loc=(0.5, 0.3, 0.68), verts=6, bevel=0.0), "Dial", "brass")
    sf.tag(sf.box((0.5, 0.05, 0.22), loc=(-0.2, -0.47, 0.3)), "Label", "hazard")
    sf.tag(sf.cyl(0.05, 0.2, loc=(0.6, 0.3, 0.8), verts=6, bevel=0.0), "Antenna", "steel")
    sf.tag(sf.sphere(0.05, loc=(0.55, -0.35, 0.62), segs=4, rings=2), "Lamp", "glow", "Neon", cast_shadow=False)
    return {"export": {"budget": 300, "step": "A6", "pivot": (0, 0, 0), "meta": {"find": "RadioLog"}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_RadioLog", "Props")
