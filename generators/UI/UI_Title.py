"""The game's title for the intro cutscene's title card (bible Section 4: "Title card and the line
Survive. Dig. Don't wake it."; Section 18: themed, never generic).

Two sprites in the kit's own materials, one above the other on screen:
    Title_Years   "100 YEARS" as a Steadfast marquee: a teal enamel plate in a chrome bezel, cream letters
    Title_Below   "BELOW" on its own underneath, bigger, cream at the top and the Source's green
                  rising through it from underneath

Each is 1016 px wide (the atlas's width) and is shown about that wide on a 1080p screen. They
pack into their own atlas ("title"): python3 tools/pack_ui.py.

Run:  python3 generators/UI/UI_Title.py [Title_Years] [Title_Below]
"""
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uikit as K  # noqa: E402
from uikit import C, mat  # noqa: E402

TOWN_FONTS = os.path.join(HERE, "..", "Town", "fonts")
W = 1016
SPECS = {
    "Title_Years": {"size": [W, 236], "slice": None, "note": "title card, upper line", "group": "title"},
    "Title_Below": {"size": [W, 336], "slice": None, "note": "title card, lower line", "group": "title"},
}


def slab_font():
    return bpy.data.fonts.load(os.path.join(TOWN_FONTS, "AlfaSlabOne-Regular.ttf"))


def letters(s, x, y, z, size, m, depth, bevel=0.0, spacing=1.0):
    cu = bpy.data.curves.new("Text", "FONT")
    cu.body = s
    cu.font = slab_font()
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.space_character = spacing
    ob = K.link(bpy.data.objects.new("Text", cu))
    ob.location = (x, y, z)
    cu.materials.append(m)
    return ob


def rising_glow(top_hex, bottom_hex, y0, y1):
    """Enamel that turns from top_hex to a glowing bottom_hex between heights y1 and y0 (object Y)."""
    m = bpy.data.materials.new("Rising")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.34
    b.inputs["Coat Weight"].default_value = 0.85
    b.inputs["Coat Roughness"].default_value = 0.06
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = y0
    mr.inputs["From Max"].default_value = y1
    mr.interpolation_type = "SMOOTHSTEP"
    ramp = nt.nodes.new("ShaderNodeMixRGB")
    ramp.inputs["Color1"].default_value = K.lin(bottom_hex)
    ramp.inputs["Color2"].default_value = K.lin(top_hex)
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "SUBTRACT"
    em.inputs[0].default_value = 1.0
    gain = nt.nodes.new("ShaderNodeMath")
    gain.operation = "MULTIPLY"
    gain.inputs[1].default_value = 0.55
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(mr.outputs["Result"], em.inputs[1])
    nt.links.new(em.outputs["Value"], gain.inputs[0])
    b.inputs["Emission Color"].default_value = K.lin(bottom_hex)
    nt.links.new(gain.outputs["Value"], b.inputs["Emission Strength"])
    return m


def burst(cx, cy, z, r, m_spike, m_ball):
    """Steadfast's starburst: eight spikes, long and short by turns, a ball at the heart."""
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        ln = r if i % 2 == 0 else r * 0.62
        w = r * 0.13
        pts = [(cx + math.cos(a + math.pi / 2) * w, cy + math.sin(a + math.pi / 2) * w),
               (cx + math.cos(a - math.pi / 2) * w, cy + math.sin(a - math.pi / 2) * w),
               (cx + math.cos(a) * ln, cy + math.sin(a) * ln)]
        K.poly(pts, z, z + 4, m_spike, bevel=0.8, seg=1)
    K.dome(cx, cy, z + 2, r * 0.24, m_ball, flat=0.7)


def years():
    w, h = SPECS["Title_Years"]["size"]
    K.rr_slab(988, 208, 34, 0, 10, mat("chrome"), bevel=3.0, seg=3)
    K.rr_slab(962, 182, 24, 6, 13, mat("enamel", C["teal"]), bevel=1.6, seg=2)
    K.rr_ring(934, 154, 14, 3, 13, 14.2, mat("enamel", C["cream"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.rivet(sx * 468, sy * 78, 13, r=5.5, m=mat("chrome"))
        burst(sx * 404, 0, 13, 44, mat("enamel", C["hazard"]), mat("chrome"))
    letters("100 YEARS", 8, -7, 12.5, 142, mat("ink", C["navy"]), 1.0)                 # the hard shadow
    letters("100 YEARS", 0, 0, 14, 142, mat("enamel", C["cream"]), 5.0, bevel=2.2)


def below():
    w, h = SPECS["Title_Below"]["size"]
    letters("BELOW", 10, -4, 1.0, 286, mat("ink", C["navy"]), 1.0, spacing=1.04)        # the hard shadow
    letters("BELOW", 0, 6, 6, 286, rising_glow(C["cream"], C["glow"], -96, 24), 8.0, bevel=3.2, spacing=1.04)
    # the Source's light seeping up under the word: one line, running out to nothing at its ends
    K.poly([(-452, -139), (0, -134.5), (452, -139), (0, -143.5)], 0, 3, mat("glow", C["glow"], strength=1.2))


PIECES = {"Title_Years": years, "Title_Below": below}


def run(names):
    for n in names:
        w, h = SPECS[n]["size"]
        K.stage(w, h)
        PIECES[n]()
        p = K.shoot(n)
        print(f"[UI_Title] {n} -> {os.path.relpath(p, K.sf.REPO)}")
    spec_path = os.path.join(K.UI, "specs.json")
    old = json.load(open(spec_path)) if os.path.exists(spec_path) else {}
    old.update(SPECS)
    with open(spec_path, "w") as f:
        json.dump(old, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    run(sys.argv[1:] or list(PIECES))
