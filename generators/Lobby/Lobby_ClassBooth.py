"""Lobby_ClassBooth: the Class Shop's booth in the Steadfast showroom (A9; bible Section 21: "class
booths (Class Shop)"; Section 14: the Daily Class Shop). A counter under a lit sign, with four
of the day's specialists on catalog cards behind it. The screen itself is The Frame's Class Shop
(ClassShopController); the builder puts the prompt at the Prompt socket.

Origin: the middle of its back, on the floor; front -Y. It stands against a wall.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lobbylib as L  # noqa: E402
import townkit as T  # noqa: E402

W = 20.0
DEPTH = 7.4
H = 12.6
RARITY = (("ash", "steel"), ("skyblue", "navy"), ("plum", "blush"), ("hazard", "brass"))     # Common, Rare, Epic, Legendary


def card(k, f, u, z, sun, ray, w=3.3, h=4.4):
    """A catalog class card on the wall: chrome rim, cream paper, a sunburst window, a bust, print lines."""
    f.on("chrome", u - w / 2 - 0.14, u + w / 2 + 0.14, z - h / 2 - 0.14, z + h / 2 + 0.14, 0.16)
    f.on("cream", u - w / 2, u + w / 2, z - h / 2, z + h / 2, 0.22)
    wz0, wz1 = z - h * 0.06, z + h / 2 - 0.25
    f.on(sun, u - w / 2 + 0.25, u + w / 2 - 0.25, wz0, wz1, 0.27)
    cz = (wz0 + wz1) / 2
    for i in range(8):          # rays
        a = 2 * math.pi * i / 8 + 0.2
        f.box(ray, (0.16, 0.05, 1.5), (u + math.cos(a) * 0.62, 0.3, cz + math.sin(a) * 0.62), roll=-math.degrees(a) + 90)
    f.cyl("navy", 0.46, 0.1, (u, 0.36, cz + 0.32), axis="n", verts=10)                         # a head
    f.outline("navy", [(u - 0.95, wz0), (u - 0.7, wz0 + 0.75), (u, wz0 + 0.98), (u + 0.7, wz0 + 0.75), (u + 0.95, wz0)], 0.3, 0.38)
    f.on(sun, u - w / 2 + 0.3, u - w / 2 + 1.7, wz0 - 0.62, wz0 - 0.2, 0.28)                    # the rarity tag
    for i, ln in enumerate((w - 0.9, w - 1.6, w - 1.2)):
        f.on("navy", u - w / 2 + 0.35, u - w / 2 + 0.35 + ln, z - h / 2 + 0.3 + i * 0.36, z - h / 2 + 0.44 + i * 0.36, 0.25)


def cash_register(k, x, y, z, yaw=0):
    with k.at((x, y, z), yaw):
        k.box("brass", (2.2, 1.9, 1.0), (0, 0, 0.5))
        k.prism_x("brass", [(-0.95, 1.0), (0.95, 1.0), (0.95, 2.3), (0.2, 2.3), (-0.95, 1.4)], -1.1, 1.1)
        k.box("cream", (1.5, 0.06, 0.5), (0, 0.25, 2.5), rot=(0, 0, 0))
        k.box("gunmetal", (1.7, 0.2, 0.7), (0, 0.4, 2.55))
        for i in range(3):
            for j in range(3):
                k.cyl("cream" if (i + j) % 2 else "signal", 0.12, 0.12, (-0.55 + i * 0.55, -0.55 + j * 0.3, 1.32 + j * 0.2), rot=(35, 0, 0), verts=5)
        k.pole("chrome", 0.06, (1.15, 0.2, 1.4), (1.5, 0.2, 2.2), verts=4)
        k.sphere("walnut", 0.16, (1.52, 0.2, 2.25), segs=5, rings=3)


def service_bell(k, x, y, z):
    k.cyl("walnut", 0.5, 0.12, (x, y, z + 0.06), verts=10)
    k.lathe("brass", [(0.42, 0.12), (0.4, 0.3), (0.22, 0.5), (0, 0.55)], (x, y, z), verts=10)
    k.cyl("chrome", 0.07, 0.12, (x, y, z + 0.6), verts=5)


def build(k):
    wall = k.face((-W / 2, -0.5, 0), 0)          # the back panel's front: u = x + W / 2
    # the back: a walnut-framed cream panel on a teal base, two swept fins at its ends
    k.span("walnut", -W / 2, W / 2, -0.5, 0.0, 0, H)
    wall.on("cream", 0.5, W - 0.5, 4.4, H - 0.5, 0.12)
    wall.on("teal", 0.5, W - 0.5, 0.0, 4.4, 0.12)
    wall.on("chrome", 0.5, W - 0.5, 4.3, 4.5, 0.2)
    k.collide_span(-W / 2, W / 2, -0.6, 0.0, 0, H + 3)
    for sx in (-1, 1):
        fin = [(0.0, 0.0), (0.0, H + 2.8), (-2.2, H + 2.8), (-DEPTH + 0.6, 6.5), (-DEPTH + 1.4, 0.0)]
        x0, x1 = (sx * W / 2 - 0.3, sx * W / 2 + 0.3)
        k.prism_x("teal", fin, min(x0, x1), max(x0, x1))
        k.prism_x("cream", [(-0.4, 5.6), (-0.4, 6.4), (-DEPTH + 0.9, 6.4), (-DEPTH + 1.0, 5.6)], sx * W / 2 - 0.36, sx * W / 2 + 0.36)
        k.collide_span(sx * W / 2 - 0.3, sx * W / 2 + 0.3, -DEPTH + 1.0, 0, 0, 7)
    # the cards: today's four, one per rarity, under their names' rule
    for i, (sun, ray) in enumerate(RARITY):
        card(k, wall, 3.4 + i * 4.4, 7.4, sun, ray)
    wall.text("signal", "Today's Specialists", W / 2, 11.1, 1.25, n=0.14, depth=0.12, font="Lobster-Regular", max_w=13)
    for u in (2.0, W - 2.0):
        L.starburst(k, wall.p(u, 0.3, 11.1), r=0.85, spikes=8, flat=True, neon=False, ball="signal")
    # the sign: a lit box over the front, bulbs along its lower edge
    k.span("teal", -W / 2 - 0.6, W / 2 + 0.6, -2.6, 0.0, H, H + 3.0)
    k.span("chrome", -W / 2 - 0.7, W / 2 + 0.7, -2.7, 0.05, H - 0.2, H)
    k.span("chrome", -W / 2 - 0.7, W / 2 + 0.7, -2.7, 0.05, H + 3.0, H + 3.2)
    sign = k.face((-W / 2, -2.6, 0), 0)
    sign.on("cream", 1.0, W - 1.0, H + 0.45, H + 2.55, 0.12)
    sign.text("signal", "CLASS SHOP", W / 2, H + 1.5, 1.55, n=0.12, depth=0.22, font="AlfaSlabOne-Regular", max_w=15, res=2)
    for i in range(15):
        k.bulb("cream", 0.2, sign.p(1.0 + i * (W - 2.0) / 14, 0.05, H - 0.32))
    k.light((0, -4.5, H - 1.5), colour="cream", brightness=0.8, range_=18)
    # the counter: teal enamel front with chrome strips, a walnut top, a kick plate
    cy0, cy1, ch = -DEPTH + 0.4, -DEPTH + 3.0, 3.5
    k.span("teal", -W / 2 + 2.2, W / 2 - 2.2, cy0, cy1, 0.3, ch)
    k.span("gunmetal", -W / 2 + 2.4, W / 2 - 2.4, cy0 + 0.25, cy1, 0, 0.3)
    k.span("walnut", -W / 2 + 1.9, W / 2 - 1.9, cy0 - 0.3, cy1 + 0.15, ch, ch + 0.28)
    k.collide_span(-W / 2 + 2.2, W / 2 - 2.2, cy0, cy1, 0, ch + 0.3, name="Counter")
    front = k.face((-W / 2 + 2.2, cy0, 0), 0)
    cw = W - 4.4
    for zz in (0.9, 2.9):
        front.on("chrome", 0.0, cw, zz, zz + 0.14, 0.1)
    front.on("cream", cw / 2 - 3.6, cw / 2 + 3.6, 1.3, 2.6, 0.08)
    front.text("teal", "STEADFAST", cw / 2, 1.95, 0.72, n=0.08, depth=0.06, flat=True, max_w=6.4)
    for u in (1.6, cw - 1.6):
        front.cyl("brass", 0.42, 0.1, (u, 0.1, 1.95), axis="n", verts=12)
        front.cyl("teal", 0.3, 0.1, (u, 0.14, 1.95), axis="n", verts=12)
    top = ch + 0.28
    cash_register(k, 4.6, cy0 + 1.4, top, yaw=180)
    service_bell(k, -1.2, cy0 + 0.9, top)
    for i, sw in enumerate(("cream", "teal", "signal", "cream")):         # a stack of catalogs
        k.box(sw, (1.7, 2.3, 0.14), (-5.4 + i * 0.05, cy0 + 1.35, top + 0.07 + i * 0.14), rot=(0, 0, 6 - i * 5))
    k.box("walnut", (2.2, 0.2, 1.3), (1.6, cy0 + 1.9, top + 0.7), rot=(-12, 0, 0))                # a little easel card
    k.box("cream", (1.9, 0.22, 1.0), (1.6, cy0 + 1.86, top + 0.72), rot=(-12, 0, 0))
    # a half-round mat where customers stand
    k.cyl("signal", 4.6, 0.04, (0, cy0 - 0.2, 0.02), verts=20, caps=(False, True))
    k.cyl("cream", 3.9, 0.04, (0, cy0 - 0.2, 0.035), verts=20, caps=(False, True))
    k.cyl("signal", 3.5, 0.04, (0, cy0 - 0.2, 0.05), verts=20, caps=(False, True))
    k.socket("Prompt", (0, cy0 - 0.6, 3.6), 0)
    return {"views": [
        ("front", (5, -34, 9), (0, -2, 7.4), 42),
        ("counter", (-9, -14, 7), (0, -4, 5), 52),
    ]}


if __name__ == "__main__":
    T.run(build, "Lobby_ClassBooth", "Lobby", budget=6000, res=(900, 620), ground="#EFE3C4", sun_strength=2.6, sky=False, ambient=2.4)
