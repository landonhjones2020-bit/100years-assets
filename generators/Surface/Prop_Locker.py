"""Prop_Locker: a dented steel locker, a surface loot container (A5; bible Section 12). Olive drab
with vents and a stencilled number, its door ajar. Front (-Y). 2.6 x 2.2 x 6 studs.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

W, D, H = 2.6, 2.2, 6.0


def build():
    sf.tag(sf.box((W, D, H), loc=(0, 0, H / 2), bevel=0.1, segments=1), "Locker", "olive", collision="box")
    sf.tag(sf.box((W - 0.3, 0.12, H - 0.5), loc=(0.33, -D / 2 - 0.6, H / 2), rot=(0, 0, 32), bevel=0.0), "Door", "olive")
    for i in range(3):
        sf.tag(sf.box((1.2, 0.14, 0.12), loc=(0.1, -D / 2 - 0.55, H - 1.0 - i * 0.3), rot=(0, 0, 32)), "Vents", "gunmetal")
    sf.tag(sf.box((0.6, 0.12, 0.5), loc=(0.6, -D / 2 - 0.62, 2.6), rot=(0, 0, 32)), "Number", "cream")
    sf.tag(sf.box((W - 0.3, D - 0.4, 0.12), loc=(0, 0.1, H * 0.62)), "Shelf", "gunmetal")
    sf.tag(sf.box((0.9, 0.9, 0.7), loc=(-0.3, 0.1, H * 0.62 + 0.4)), "Box", "pine")
    return {"export": {"budget": 800, "step": "Setup", "meta": {"container": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_Locker", "Surface")
