"""Prop_GeneratorParts: a big find on the surface (A5; bible Section 12: big finds such as generator
parts are carried with both hands, slowly). A generator's engine block lashed to a little steel
pallet with hazard-striped ends, coils of copper wire and a fuel tank on top. Front (-Y).
3.2 x 2.4 x 2.4 studs; its pivot is its foot (InventoryService welds it in front of the carrier).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402


def build():
    sf.tag(sf.box((3.2, 2.4, 0.35), loc=(0, 0, 0.18), bevel=0.05, segments=1), "Pallet", "steel", collision="box")
    for sx in (-1, 1):
        sf.tag(sf.box((0.3, 2.4, 0.4), loc=(sx * 1.45, 0, 0.2)), "Stripe", "hazard")
    sf.tag(sf.box((2.4, 1.8, 1.3), loc=(0, 0, 1.0), bevel=0.2, segments=1), "Block", "teal")
    for x in (-0.7, 0, 0.7):
        sf.tag(sf.cyl(0.32, 0.5, loc=(x, 0, 1.85), verts=8, bevel=0.0), "Heads", "gunmetal")
    sf.tag(sf.cyl(0.55, 0.5, loc=(1.3, -0.4, 1.0), rot=(0, 90, 0), verts=10, bevel=0.0), "Pulley", "chrome")
    sf.tag(sf.torus(0.45, 0.15, loc=(-0.9, 0.6, 2.25), major_segs=10, minor_segs=4), "Wire", "copper")
    sf.tag(sf.cyl(0.4, 1.4, loc=(0.4, 0.55, 2.35), rot=(0, 90, 0), verts=10, bevel=0.0), "Tank", "signal")
    sf.tag(sf.box((3.3, 0.1, 0.12), loc=(0, -0.95, 1.4)), "Strap", "leather")
    return {"export": {"budget": 800, "step": "Setup", "pivot": (0, 0, 0), "meta": {"bigFind": "GeneratorParts"}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_GeneratorParts", "Props")
