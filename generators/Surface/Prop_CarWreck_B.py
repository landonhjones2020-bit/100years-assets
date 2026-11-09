"""Prop_CarWreck_B: a rusted pickup truck on its side rims (A5). A square cab, a bed full of junk,
a bent grille. Front (-Y). About 7 x 15 studs.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    sf.tag(sf.box((6.6, 6.0, 2.6), loc=(0, -4.4, 1.9), bevel=0.6, segments=2), "Hood", "rust", collision="box")
    sf.tag(sf.box((6.4, 4.6, 4.6), loc=(0, 0.4, 3.0), bevel=0.5, segments=2), "Cab", "rust", collision="box")
    sf.tag(sf.box((5.0, 0.3, 2.0), loc=(0, -1.9, 4.4), bevel=0.0), "Window", "basalt")
    sf.tag(sf.box((6.6, 7.0, 0.5), loc=(0, 6.0, 1.4), bevel=0.1, segments=1), "Bed", "gunmetal", collision="box")
    for sx in (-1, 1):
        sf.tag(sf.box((0.4, 7.0, 1.6), loc=(sx * 3.1, 6.0, 2.3), bevel=0.1, segments=1), "Bed", "rust", collision="box")
    sf.tag(sf.box((6.6, 0.4, 1.6), loc=(0, 9.4, 2.3), bevel=0.1, segments=1), "Bed", "rust", collision="box")
    sf.tag(sf.box((6.2, 0.4, 1.6), loc=(0, -7.5, 1.7), rot=(0, 0, 6), bevel=0.15, segments=1), "Grille", "chrome")
    for sx in (-1, 1):
        for y in (-4.6, 6.4):
            sf.tag(sf.cyl(1.2, 0.9, loc=(sx * 3.1, y, 1.0), rot=(0, 90, 0), verts=10, bevel=0.0), "Rims", "gunmetal")
    for i, sw in enumerate(("pine", "olive", "steel")):
        sf.tag(sf.box((1.6, 1.4, 1.2), loc=(-1.6 + i * 1.6, 6.2 + (i % 2), 2.3), rot=(0, 0, i * 25), bevel=0.0), "Junk", sw)
    return {"export": {"budget": 800, "step": "Setup", "meta": {"decor": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_CarWreck_B", "Surface")
