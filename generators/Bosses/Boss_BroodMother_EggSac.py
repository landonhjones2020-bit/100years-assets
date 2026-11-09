"""Boss_BroodMother_EggSac: what the Brood Mother lays (bible Section 10: egg sacs that hatch
Burrow Ticks; break or burn the sacs). A cluster of three glowing, half-see-through eggs on a
mound of plum membrane and web strands, each with a curled Burrow Tick shape inside, veins
over the shells. Raycasts hit the eggs (collision query); the mound is a box.

Run:  SF_EXPORT=1 python3 generators/Bosses/Boss_BroodMother_EggSac.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Monsters"))
from _beast import sf, blob, limb, spike  # noqa: E402

ASSET, CATEGORY = "Boss_BroodMother_EggSac", "Bosses"
EGGS = ((0.0, -0.35, 1.25, 0.95), (0.85, 0.45, 1.0, 0.78), (-0.8, 0.5, 0.95, 0.72))


def build():
    sf.tag(blob(1.0, (0, 0.15, 0.2), scale=(1.9, 1.6, 0.55), segs=12, rings=6, noise=0.08, seed=1), "Mound", "plum",
           collision="box")
    for i, (x, y, z, r) in enumerate(EGGS):
        egg = blob(r, (x, y, z), scale=(0.9, 0.9, 1.15), segs=10, rings=7, noise=0.03, seed=10 + i, name="Egg")
        sf.tag(egg, "Eggs", "glow", "Neon", collision="query", cast_shadow=False, transparency=0.3)
        # the curled tick inside: a dark body and folded legs
        sf.tag(blob(r * 0.42, (x, y, z), scale=(1.0, 1.2, 0.7), segs=8, rings=5, seed=20 + i), "Unborn", "basalt")
        for k in range(2):
            for sx in (-1, 1):
                a = math.radians(-30 + 60 * k)
                p0 = (x + sx * r * 0.3, y + r * 0.3 * math.sin(a), z)
                sf.tag(limb([p0, (x + sx * r * 0.5, y + r * 0.35 * math.sin(a), z + r * 0.15),
                             (x + sx * r * 0.32, y + r * 0.4 * math.sin(a), z - r * 0.2)], [0.04, 0.035, 0.02],
                            sides=4, resolution=1), "Unborn", "basalt")
        # plum veins over the shell
        for a in (30, 150, 270):
            t = math.radians(a)
            pts = [(x + r * 0.97 * math.cos(t) * math.sin(math.radians(ph)), y + r * 0.97 * math.sin(t) * math.sin(math.radians(ph)),
                    z + r * 1.2 * math.cos(math.radians(ph))) for ph in (150, 110, 70, 30)]
            sf.tag(limb(pts, [0.05, 0.05, 0.04, 0.03], sides=4, resolution=1), "Veins", "plum")
    # web strands pinning it to the floor
    for a in range(0, 360, 60):
        t = math.radians(a + 15)
        sf.tag(limb([(0.4 * math.cos(t), 0.4 * math.sin(t), 1.6), (1.7 * math.cos(t), 1.6 * math.sin(t), 0.6),
                     (2.3 * math.cos(t), 2.1 * math.sin(t), 0.02)], [0.04, 0.035, 0.02], sides=4, resolution=1),
               "Web", "sandstone")
    for (x, y) in ((1.4, -0.9), (-1.5, -0.6), (0.2, 1.5)):
        sf.tag(spike((x, y, 0.15), (x * 0.3, y * 0.3, 1.0), 0.6, 0.12, verts=4), "Mound", "stone", collision="box")


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY, budget=1400, step="A4",
                meta={"role": "EggSac", "hatches": "BurrowTick"},
                sockets={"Hatch": ((0, 0, 0.5), 0.0)})
