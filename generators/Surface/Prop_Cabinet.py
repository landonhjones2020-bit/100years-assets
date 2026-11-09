"""Prop_Cabinet: a 1950s kitchen and store cabinet, a surface loot container (A5; bible Section 12:
containers refill every era). Pastel enamel with chrome handles, one door hanging open.
Front (-Y). 4 x 2.4 x 4 studs.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

W, D, H = 4.0, 2.4, 4.2


def build():
    sf.tag(sf.box((W, D, H - 0.3), loc=(0, 0, 0.3 + (H - 0.3) / 2), bevel=0.12, segments=1), "Cabinet", "mint", collision="box")
    sf.tag(sf.box((W - 0.2, D - 0.2, 0.3), loc=(0, 0.05, 0.15), bevel=0.0), "Cabinet", "navy", collision="box")
    sf.tag(sf.box((W + 0.2, D + 0.2, 0.25), loc=(0, 0, H + 0.1), bevel=0.06, segments=1), "Top", "chrome")
    sf.tag(sf.box((W / 2 - 0.2, 0.12, H - 1.0), loc=(-W / 4, -D / 2 - 0.05, 0.5 + (H - 1.0) / 2), bevel=0.04, segments=1), "Door", "cream")
    sf.tag(sf.box((W / 2 - 0.2, 0.12, H - 1.0), loc=(1.55, -D / 2 - 0.78, 0.5 + (H - 1.0) / 2), rot=(0, 0, 60),
                  bevel=0.04, segments=1), "Door", "cream")                                  # hanging open
    sf.tag(sf.box((0.15, 0.25, 0.9), loc=(-0.35, -D / 2 - 0.2, H * 0.55)), "Handle", "chrome")
    sf.tag(sf.box((W - 0.5, D - 0.6, 0.12), loc=(0, 0.1, H * 0.5)), "Shelf", "cream")
    for i, sw in enumerate(("signal", "hazard", "skyblue")):
        sf.tag(sf.cyl(0.32, 0.8, loc=(0.4 + i * 0.75, 0.1, H * 0.5 + 0.46), verts=8, bevel=0.0), "Tins", sw)
    return {"export": {"budget": 800, "step": "Setup", "meta": {"container": True}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_Cabinet", "Surface")
