"""Throwable_Flare: lights an area and reveals Prism Stalkers (bible Appendix). A road flare: a
rust-red tube with a cream label and a hazard stripe, a gunmetal cap at the back and a dark
striker tip with an orange igniter. One MeshPart (no Neon): the thrown flare's light is code's.

Pivot = the grip. Sockets: Grip and Tip (the striker). Faces Blender -Y.

Run:  SF_EXPORT=1 python3 generators/Weapons/Throwable_Flare.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _gunkit as G  # noqa: E402

sf = G.sf
ASSET, CATEGORY = "Throwable_Flare", "Weapons"
BUDGET = 300
GRIP = (0.0, 0.2, 0.0)


def build():
    F = "Flare"
    G.barrel(F, 0.1, -0.48, 0.48, 0.0, "rust", verts=8, bevel=0.0)
    G.band(F, 0.104, 0.12, 0.0, w=0.32, swatch="cream", verts=8)
    G.band(F, 0.106, 0.02, 0.0, w=0.06, swatch="hazard", verts=8)
    G.t(sf.cyl(0.115, 0.1, loc=(0, 0.5, 0), rot=(90, 0, 0), verts=8, bevel=0.0), F, "gunmetal")
    G.t(sf.cyl(0.09, 0.08, loc=(0, -0.52, 0), rot=(90, 0, 0), verts=8, bevel=0.0), F, "rubber")
    G.t(sf.cyl(0.05, 0.05, loc=(0, -0.58, 0), rot=(90, 0, 0), verts=6, bevel=0.0), F, "signal")
    return G.exports(BUDGET, "P20", GRIP, {"Tip": ((0, -0.6, 0), 0.0)}, {"kind": "Throwable", "class": ["Scout"]})


if __name__ == "__main__":
    sf.run_main(build, ASSET, CATEGORY)
