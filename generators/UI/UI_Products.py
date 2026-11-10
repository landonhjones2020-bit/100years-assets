"""Product icons: what Roblox shows in a purchase prompt (bible Section 17; STYLE.md section 3).

Each is a 512 x 512 PNG in the UI kit's look (enamel steel, chrome, cream catalog cards), rendered
to ui/products/<Name>.png. They are uploaded with the developer product itself (Open Cloud), not
packed into the UI atlases.

Run:  python3 generators/UI/UI_Products.py [Name ...]     (no names: every icon)
"""
import bpy  # noqa: F401
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uikit as K  # noqa: E402
import uiprint as P  # noqa: E402
from uikit import C, RARITY, mat  # noqa: E402

OUT = os.path.join(K.UI, "products")
SIZE = 512
ICONS: dict = {}


def product(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


def plate(dark, light):
    """The square every icon sits on: a chrome bezel with corner rivets round a sunburst."""
    W = 500
    K.rr_ring(W, W, 64, 30, 0, 24, mat("chrome"), bevel=11, seg=5)
    img = P.sunburst(os.path.join(K.TMP, f"product_sun_{dark[1:]}.png"), 448, 448, dark, light, cy=0.5, rays=32)
    K.rr_slab(W - 52, W - 52, 40, 0, 12, mat("enamel", dark), bevel=2, seg=2)
    K.plane_image(img, 432, 432, 12.4, rough=0.55)
    K.rr_ring(W - 56, W - 56, 38, 9, 10, 15, mat("enamel", dark), bevel=2.5, seg=3)
    d = W / 2 - 64 + (64 - 17) * math.cos(math.radians(45))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.rivet(sx * d, sy * d, 24, 8.5)


def turned(obs, deg, dx, dy, dz=0.0):
    """Turn a group of pieces about the plate's centre, then move it."""
    a = math.radians(deg)
    for ob in obs:
        x, y, z = ob.location
        ob.location = (x * math.cos(a) - y * math.sin(a) + dx, x * math.sin(a) + y * math.cos(a) + dy, z + dz)
        ob.rotation_euler = (0, 0, ob.rotation_euler[2] + a)


def class_card(rarity, z):
    """A small class card (the kit's card, simplified): chrome rim, paper, a sunburst window, a tag."""
    dark, light, _txt = RARITY[rarity]
    w, h = 170, 222
    obs = [
        K.rr_ring(w, h, 14, 6, z, z + 7, mat("chrome"), bevel=2.6, seg=4),
        K.rr_slab(w - 10, h - 10, 9, z, z + 3.4, mat("paper", C["paper"]), bevel=0.6, seg=2),
    ]
    img = P.sunburst(os.path.join(K.TMP, f"product_card_{rarity}.png"), 280, 240, dark, light)
    obs.append(K.plane_image(img, 140, 120, z + 3.7, cy=36, rough=0.7))
    obs.append(K.rr_ring(146, 126, 8, 3.2, z + 3, z + 5.6, mat("chrome"), bevel=1.0, seg=3, cy=36))
    obs.append(K.rr_slab(74, 22, 5, z + 3.4, z + 6.2, mat("enamel", dark), bevel=0.8, seg=2, cx=-28, cy=-28))
    ink = mat("ink", C["ink"])
    for i, wide in enumerate((120, 96, 108)):
        obs.append(K.box(wide, 7, z + 3.4, z + 3.75, ink, cx=-70 + wide / 2, cy=-56 - i * 17))
    return obs


def cycle_arrow(r, width, a_from, a_to, z, m, head=1.9):
    """An arc with an arrowhead at its a_to end (degrees, counter-clockwise from +X)."""
    obs = [K.sector(r + width / 2, r - width / 2, a_from, a_to, z, z + 13, m, n=40, bevel=3.2, seg=3)]
    a = math.radians(a_to)
    step = 1 if a_to > a_from else -1
    tx, ty = -math.sin(a) * step, math.cos(a) * step     # the way the arrow points
    nx, ny = math.cos(a), math.sin(a)
    cx, cy = r * nx, r * ny
    hw, hl = width * head / 2 + width * 0.4, width * 1.55
    pts = [(cx + nx * hw, cy + ny * hw), (cx - nx * hw, cy - ny * hw), (cx + tx * hl, cy + ty * hl)]
    obs.append(K.poly(pts, z, z + 13, m, bevel=3.2, seg=3))
    return obs


@product("Product_ClassShopReroll")
def class_shop_reroll():
    """Three class cards fanned out under a pair of orange arrows going round: new cards."""
    plate("#2F6F73", "#63A3A6")
    for rarity, deg, dx, dy, z in (("Rare", 17, -78, 4, 16), ("Legendary", -17, 78, 4, 25), ("Epic", 0, 0, 14, 34)):
        turned(class_card(rarity, z), deg, dx, dy)
    orange = mat("enamel", C["signal"] if "signal" in C else "#E8743B")
    cycle_arrow(176, 30, 205, 318, 46, orange)
    cycle_arrow(176, 30, 25, 138, 46, orange)


def run(names):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(K.TMP, exist_ok=True)
    for n in names:
        K.stage(SIZE, SIZE, shadow=True)
        ICONS[n]()
        p = os.path.join(OUT, f"{n}.png")
        bpy.context.scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        print(f"[UI_Products] {n} -> {os.path.relpath(p, K.sf.REPO)}")


if __name__ == "__main__":
    run(sys.argv[1:] or list(ICONS))
