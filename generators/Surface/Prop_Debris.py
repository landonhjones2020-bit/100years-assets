"""Prop_Debris: a heap of rubble in the street (A5): broken masonry, a beam, a bent sign post.
About 8 x 6 studs.
"""
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    rng = random.Random(7)
    sf.tag(sf.box((7.0, 5.0, 1.2), loc=(0, 0, 0.6), bevel=0.5, segments=1), "Heap", "stone", collision="box")
    for i in range(7):
        s = rng.uniform(0.9, 1.8)
        sf.tag(sf.box((s, s * 1.2, s * 0.7), loc=(rng.uniform(-3, 3), rng.uniform(-2, 2), 1.0 + s * 0.3),
                      rot=(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 90)), bevel=0.15, segments=1),
               "Chunks", "sandstone" if i % 2 else "stone")
    sf.tag(sf.box((8.0, 0.8, 0.6), loc=(0.5, 0.4, 1.6), rot=(0, 12, 28), bevel=0.05, segments=1), "Beam", "walnut")
    sf.tag(sf.tube([(-2.5, -1.5, 0.5), (-2.8, -1.2, 4.0), (-1.6, -1.0, 5.4)], [0.12, 0.12, 0.12], sides=4, resolution=1), "Post", "steel")
    sf.tag(sf.box((1.8, 0.1, 1.2), loc=(-1.2, -1.0, 5.6), rot=(0, 30, 0)), "Plate", "hazard")
    return {"export": {"budget": 800, "step": "Setup", "meta": {"decor": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_Debris", "Surface")
