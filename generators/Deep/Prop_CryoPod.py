"""Prop_CryoPod: a Steadfast cold-sleep capsule with someone frozen inside (A6; bible Sections 6 and
12: a cryo pod is a frozen survivor, found in dug cells from Era II and in the Deep; a big find
carried home with both hands; the Cryo Bay thaws it into a Rare or Legendary resident).
Cream enamel shell, chrome bands, a frosted window with a sleeper's outline, a teal company
stripe, frost at the seams and a green status lamp still on. 4.6 x 2.1 x 1.9; pivot its foot,
front (-Y) the window side.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

L, W, H = 4.6, 2.1, 1.9


def build():
    # the shell: a rounded capsule lying along X on two feet
    body = sf.cyl(W / 2, L - 0.9, loc=(0, 0, H / 2 + 0.05), rot=(0, 90, 0), verts=10, bevel=0.0)
    body.scale = (1.0, 1.0, (H - 0.1) / W)
    sf.tag(body, "Shell", "cream", collision="box")
    for sx in (-1, 1):
        cap = sf.sphere(W / 2, loc=(sx * (L - 0.9) / 2, 0, H / 2 + 0.05), scale=(0.45, 1.0, (H - 0.1) / W), segs=10, rings=4)
        sf.tag(cap, "Caps", "cream")
        sf.tag(sf.cyl(W / 2 + 0.05, 0.22, loc=(sx * (L - 1.0) / 2, 0, H / 2 + 0.05), rot=(0, 90, 0), verts=10, bevel=0.0),
               "Bands", "chrome")
        sf.tag(sf.box((0.5, W * 0.8, 0.25), loc=(sx * 1.3, 0, 0.12), bevel=0.0), "Feet", "gunmetal")
    # the window: frosted glass over the sleeper, a darker outline of head and shoulders
    sf.tag(sf.box((2.4, 0.08, 0.9), loc=(0, -W / 2 + 0.02, H * 0.58), bevel=0.0), "Window", "crystal", "Glass",
           transparency=0.25)
    sf.tag(sf.sphere(0.32, loc=(-0.75, -W / 2 + 0.16, H * 0.6), scale=(1.0, 0.4, 1.1), segs=6, rings=3), "Sleeper", "navy")
    sf.tag(sf.box((1.3, 0.12, 0.55), loc=(0.2, -W / 2 + 0.16, H * 0.55), bevel=0.0), "Sleeper", "navy")
    sf.tag(sf.box((2.7, 0.1, 1.15), loc=(0, -W / 2 + 0.05, H * 0.58), bevel=0.0), "Frame", "chrome")
    # the company stripe and the status lamp
    sf.tag(sf.box((L - 1.2, 0.06, 0.18), loc=(0, -W / 2 + 0.06, H * 0.22), bevel=0.0), "Stripe", "teal")
    sf.tag(sf.sphere(0.12, loc=(1.6, -W / 2 + 0.12, H * 0.6), segs=8, rings=4), "Lamp", "glow", "Neon", cast_shadow=False)
    # frost along the top seam
    for x in (-1.4, -0.6, 0.3, 1.1):
        sf.tag(sf.box((0.5, 0.35, 0.08), loc=(x, 0.4, H + 0.02), rot=(0, 0, 25), bevel=0.0), "Frost", "porcelain")
    return {"export": {"budget": 800, "step": "A6", "pivot": (0, 0, 0), "meta": {"bigFind": "CryoPod"}}}


if __name__ == "__main__":
    sf.run_main(build, "Prop_CryoPod", "Props")
