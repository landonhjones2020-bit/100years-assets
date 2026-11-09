"""Prop_BurntTree: a tree burnt to a black snag by the blast (A5). A leaning trunk and three bare
broken limbs, ash at its foot. About 3 x 14 studs.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    sf.tag(sf.tube([(0, 0, 0), (0.3, 0.2, 6), (0.9, -0.2, 11), (1.2, 0, 14)], [0.9, 0.7, 0.45, 0.2], sides=7, resolution=2),
           "Trunk", "basalt", collision="hull")
    for (a, b, r) in (((0.3, 0.1, 6), (-3.0, 0.8, 9.5), 0.3), ((0.8, -0.1, 9.5), (3.4, -1.2, 12.5), 0.25),
                      ((1.0, 0, 12), (0.2, 2.6, 14.2), 0.18)):
        sf.tag(sf.tube([a, b], [r, r * 0.4], sides=5, resolution=1), "Limbs", "basalt")
    sf.tag(sf.cyl(2.2, 0.3, loc=(0, 0, 0.15), verts=10, bevel=0.0), "Ash", "ash")
    return {"export": {"budget": 300, "step": "Setup", "meta": {"decor": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_BurntTree", "Surface")
