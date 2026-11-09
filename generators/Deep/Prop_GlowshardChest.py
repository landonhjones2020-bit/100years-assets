"""Prop_GlowshardChest: a Glowshard chest in the Deep (A6; bible Sections 12 and 16: 1 to 3
Glowshards, rare). A Steadfast strongbox, teal enamel and gunmetal with chrome corners, its lid
sprung open on a heap of glowing green shards. 2.6 x 1.7 x 2.0; pivot its foot, front (-Y)."""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Monsters"))
import steadfast as sf  # noqa: E402
from mathutils import Vector  # noqa: E402
from _beast import crystal  # noqa: E402


def build():
    rnd = random.Random(5)
    sf.tag(sf.box((2.4, 1.5, 1.1), loc=(0, 0, 0.6), bevel=0.0), "Box", "teal", collision="box")
    sf.tag(sf.box((2.5, 1.6, 0.12), loc=(0, 0, 0.1), bevel=0.0), "Base", "gunmetal")
    for sx in (-1, 1):
        for sy in (-1, 1):
            sf.tag(sf.box((0.32, 0.32, 1.15), loc=(sx * 1.1, sy * 0.66, 0.6), bevel=0.0), "Corners", "chrome")
    # the lid, sprung open backwards
    lid = sf.box((2.4, 1.5, 0.18), loc=(0, 0.95, 1.65), rot=(-62, 0, 0), bevel=0.0)
    sf.tag(lid, "Lid", "teal")
    sf.tag(sf.box((0.5, 0.08, 0.3), loc=(0, -0.78, 0.95), bevel=0.0), "Latch", "brass")
    sf.tag(sf.box((1.2, 0.05, 0.22), loc=(0, -0.77, 0.45), bevel=0.0), "Plate", "cream")
    # the shards
    for k in range(4):
        base = Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.4, 0.4), 1.05))
        d = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.3, 0.3), 1.0)).normalized()
        sf.tag(crystal(base, d, rnd.uniform(0.5, 0.9), rnd.uniform(0.12, 0.2)), "Shards", "glow", "Neon", cast_shadow=False)
    return {"export": {"budget": 800, "step": "A6", "pivot": (0, 0, 0), "meta": {"find": "GlowshardChest"}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_GlowshardChest", "Props")
