"""Prop_CarWreck_A: a burnt-out 1950s sedan on Main Street (A5). Rounded fenders, chrome bumpers
and a bonnet sprung open; scorched paint, no glass, no tyres. Front (-Y). About 7 x 14 studs.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    body = sf.tag(sf.box((6.6, 13.5, 2.4), loc=(0, 0, 1.9), bevel=0.9, segments=2), "Body", "skyblue", collision="box")
    sf.paint(body, "basalt", lambda c, n: c.z > 2.6 and c.y > -2)                                   # scorched
    sf.tag(sf.box((5.8, 6.0, 2.2), loc=(0, 1.2, 4.0), bevel=0.8, segments=2), "Cabin", "basalt", collision="box")
    sf.tag(sf.box((6.0, 4.4, 0.25), loc=(0, -5.0, 3.6), rot=(-35, 0, 0), bevel=0.2, segments=1), "Bonnet", "skyblue")
    for y in (-6.9, 6.9):
        sf.tag(sf.box((7.0, 0.5, 0.6), loc=(0, y, 1.2), bevel=0.2, segments=1), "Bumper", "chrome")
    for sx in (-1, 1):
        for y in (-4.2, 4.0):
            sf.tag(sf.cyl(1.1, 0.8, loc=(sx * 3.0, y, 0.9), rot=(0, 90, 0), verts=10, bevel=0.0), "Rims", "gunmetal")
    sf.tag(sf.cyl(0.45, 0.3, loc=(-2.2, -6.8, 2.3), rot=(90, 0, 0), verts=8, bevel=0.0), "Lamp", "cream")
    return {"export": {"budget": 800, "step": "Setup", "meta": {"decor": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_CarWreck_A", "Surface")
