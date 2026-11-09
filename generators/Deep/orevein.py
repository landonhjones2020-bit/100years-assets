"""An ore vein in the Deep (A6; bible Section 12: ore veins, much richer than digging alone): a
rock outcrop shot through with chunks of the band's ore. 4.4 x 2.8 x 3.6; pivot its foot."""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Kits"))
import steadfast as sf  # noqa: E402
from Kit_Rubble import lump  # noqa: E402

ORES = {"Iron": ("rust", "copper"), "Copper": ("copper", "mint")}


def build(ore, seed):
    rnd = random.Random(seed)
    lump("Rock", (0, 0, 1.0), 2.0, seed, segs=7, rings=5, swatch="stone")
    lump("Rock", (-1.4, 0.3, 0.7), 1.3, seed + 1, segs=6, rings=4, swatch="basalt")
    lump("Rock", (1.5, -0.2, 0.6), 1.2, seed + 2, segs=6, rings=4, swatch="stone")
    main, glint = ORES[ore]
    for k in range(11):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(0.6, 2.6)
        r = 2.15 if z < 1.6 else 1.6               # out at the rock's skin, where they show
        o = sf.sphere(rnd.uniform(0.4, 0.62), loc=(math.cos(a) * r, math.sin(a) * r * 0.8, z), segs=5, rings=3)
        o.rotation_euler = (rnd.uniform(0, 3), rnd.uniform(0, 3), rnd.uniform(0, 3))
        sf.tag(o, "Ore", main if k % 3 else glint, smooth_angle=None)
    # the collision: one box round the outcrop
    sf.tag(sf.box((3.6, 2.4, 2.8), loc=(0, 0, 1.4), bevel=0.0), "Body", "stone", collision="box", transparency=1.0)
    return {"export": {"budget": 800, "step": "A6", "pivot": (0, 0, 0), "meta": {"find": "OreVein", "ore": ore}}}


def run(ore, seed):
    sf.run_main(lambda: build(ore, seed), f"Prop_OreVein_{ore}", "Props")
