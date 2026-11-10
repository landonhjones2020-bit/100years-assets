"""Item_Medkit: heals a player or revives a resident (bible Appendix). The Steadfast first-aid
case, as on the HUD's icon: a teal enamel box with a cream cross on its front, a brass carry
handle and brass latches, and a rubber seal line.

Pivot = bottom-centre (it sits on shelves and floors). Sockets: Grip (the handle). Faces
Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Item_Medkit.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Item_Medkit", "Weapons"
BUDGET = 300


def build():
    K = "Medkit"
    G.t(sf.box((0.95, 0.42, 0.68), loc=(0, 0, 0.34), bevel=0.06, segments=1), K, "teal", collision="box")
    G.t(sf.box((0.97, 0.44, 0.03), loc=(0, 0, 0.5), bevel=0.0), K, "rubber", collision="box")
    # the cross: one slab (two overlapping boxes flickered where they met)
    a, w = 0.2, 0.065
    cross = [(-w, a), (w, a), (w, w), (a, w), (a, -w), (w, -w), (w, -a), (-w, -a), (-w, -w), (-a, -w), (-a, w), (-w, w)]
    G.t(sf.profile_slab(cross, 0.03, loc=(0, -0.2, 0.3), rot=(90, 0, 0), bevel=0.0), K, "cream", collision="box")
    G.t(sf.tube([(-0.2, 0, 0.68), (-0.16, 0, 0.82), (0.16, 0, 0.82), (0.2, 0, 0.68)], [0.035] * 4, sides=4, resolution=2),
        K, "brass", collision="box")
    for x in (-0.3, 0.3):
        G.t(sf.box((0.1, 0.04, 0.1), loc=(x, -0.22, 0.52), bevel=0.0), K, "brass", collision="box")
    return G.exports(BUDGET, "P20", (0, 0, 0.82), {}, {"kind": "Consumable"}, pivot=(0, 0, 0))


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
