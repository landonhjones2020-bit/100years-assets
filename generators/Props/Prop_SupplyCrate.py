"""Prop_SupplyCrate: the Steadfast supply crate (Supply Drop boost, surface caches).

Also the pipeline test asset: palette swatches from every row of palette.png (teal, steel,
pine, cream, navy, hazard, leather, brass), so a flipped or shifted UV shows at a glance.
Front (stencil plate, latch) faces Blender -Y, which lands on Roblox -Z (LookVector).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

W, D, H = 4.0, 2.6, 2.6   # outer size (x, y, z) in studs
SKID = 0.25               # runner height
LID = 0.45                # lid height
BUDGET = 800              # medium prop (bible Section 19)


def build():
    body_h = H - SKID - LID
    body = sf.box((W - 0.12, D - 0.12, body_h), loc=(0, 0, SKID + body_h / 2), bevel=0.06, segments=1)
    sf.tag(body, "Crate", "teal", collision="box")
    lid = sf.box((W, D, LID), loc=(0, 0, H - LID / 2), bevel=0.06, segments=1, name="Lid")
    sf.tag(lid, "Crate", "teal", collision="box")
    seam = sf.box((W - 0.06, D - 0.06, 0.07), loc=(0, 0, H - LID), bevel=0.0, name="Seam")
    sf.tag(seam, "Crate", "navy", collision="box")

    # two pine skids under the crate, along X
    for sy in (-1, 1):
        skid = sf.box((W - 0.3, 0.5, SKID), loc=(0, sy * (D / 2 - 0.38), SKID / 2), bevel=0.04, segments=1, name="Skid")
        sf.tag(skid, "Crate", "pine", collision="box")

    # steel corner caps, top and bottom
    c = 0.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (SKID + c / 2 - 0.02, H - c / 2 + 0.01):
                cap = sf.box((c, c, c), loc=(sx * (W / 2 - c / 2 + 0.03), sy * (D / 2 - c / 2 + 0.03), z),
                             bevel=0.0, name="Cap")
                sf.tag(cap, "Crate", "steel", collision="box")

    # steel straps over the lid and down the front and back
    for sx in (-1, 1):
        x = sx * 1.0
        top = sf.box((0.32, D + 0.06, 0.06), loc=(x, 0, H + 0.02), bevel=0.0, name="Strap")
        sf.tag(top, "Crate", "steel", collision="box")
        for sy in (-1, 1):
            side = sf.box((0.32, 0.06, H - SKID), loc=(x, sy * (D / 2 + 0.02), SKID + (H - SKID) / 2), bevel=0.0, name="Strap")
            sf.tag(side, "Crate", "steel", collision="box")

    # front: cream stencil plate with a navy emblem, hazard stripe on the lid, brass latch
    plate = sf.box((1.3, 0.06, 0.8), loc=(0, -D / 2 - 0.035, SKID + body_h * 0.5), bevel=0.02, segments=1, name="Plate")
    sf.tag(plate, "Crate", "cream", collision="box")
    emblem = sf.cyl(0.24, 0.04, loc=(0, -D / 2 - 0.075, SKID + body_h * 0.5), rot=(90, 0, 0), verts=12, bevel=0.0, name="Emblem")
    sf.tag(emblem, "Crate", "navy", collision="box")
    stripe = sf.box((W - 0.9, 0.04, 0.14), loc=(0, -D / 2 - 0.015, H - LID / 2), bevel=0.0, name="Stripe")
    sf.tag(stripe, "Crate", "hazard", collision="box")
    latch = sf.box((0.32, 0.1, 0.34), loc=(0, -D / 2 - 0.04, H - LID - 0.02), bevel=0.0, name="Latch")
    sf.tag(latch, "Crate", "brass", collision="box")

    # rope handles on both ends
    for sx in (-1, 1):
        rope = sf.torus(0.36, 0.07, loc=(sx * (W / 2 + 0.05), 0, SKID + body_h * 0.62), rot=(0, 90, 0),
                        major_segs=10, minor_segs=5, name="Rope")
        sf.tag(rope, "Crate", "leather", collision="box")

    return {"export": {
        "budget": BUDGET, "step": "Setup",
        "sockets": {"Prompt": ((0, -D / 2 - 1.2, 1.4), 0.0), "Top": (0, 0, H + 0.05)},
        "meta": {"use": "Supply Drop crate and surface caches", "pipeline_test": True},
    }}


if __name__ == "__main__":
    sf.run_main(build, "Prop_SupplyCrate", "Props")
