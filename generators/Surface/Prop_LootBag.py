"""Prop_LootBag: a dropped backpack's bag (A5; bible Section 9: a player downed on the surface drops
their backpack where they fell). A canvas rucksack slumped on its side, straps loose. About 2 x 2.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    sf.tag(sf.sphere(1.0, loc=(0, 0, 0.75), scale=(1.0, 0.8, 0.75), segs=10, rings=6), "Sack", "olive", collision="box")
    sf.tag(sf.box((1.2, 0.5, 0.8), loc=(0, -0.75, 0.6), bevel=0.15, segments=1), "Pocket", "olive")
    sf.tag(sf.box((1.4, 1.6, 0.3), loc=(0, 0.1, 1.4), rot=(10, 0, 0), bevel=0.1, segments=1), "Flap", "leather")
    for x in (-0.4, 0.4):
        sf.tag(sf.box((0.15, 1.8, 0.08), loc=(x, 0.3, 0.12), rot=(0, 0, 20 if x > 0 else -15)), "Straps", "leather")
    sf.tag(sf.box((0.3, 0.12, 0.2), loc=(0, -1.0, 0.75)), "Buckle", "brass")
    return {"export": {"budget": 800, "step": "Setup", "meta": {"bag": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_LootBag", "Props")
