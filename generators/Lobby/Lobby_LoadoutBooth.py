"""Lobby_LoadoutBooth: the outfitting booth in the Steadfast showroom (A9; bible Sections 14 and
21: the Loadout, "set in the lobby"). Lockers, a coverall on its hanger, hard hats on pegs, a
mirror and a bench under a lit sign. The screen is The Frame's Loadout (ClassShopController); the
builder puts the prompt at the Prompt socket.

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


def locker(k, f, u, w=3.0, h=9.2, d=2.2, door="teal", open_door=False, number="1"):
    """A steel locker against the wall face (its left edge at u)."""
    f.on("gunmetal", u, u + w, 0.3, h, d, n0=0.0)
    f.on("gunmetal", u + 0.1, u + w - 0.1, 0.0, 0.3, d - 0.2, n0=0.0)
    if open_door:
        # the inside: a shelf with a hard hat, the coverall on its hanger
        f.on("rubber", u + 0.2, u + w - 0.2, 0.5, h - 0.2, d + 0.02, n0=d - 0.02)
        f.on("steel", u + 0.2, u + w - 0.2, h - 2.3, h - 2.15, d + 0.25, n0=d)
        k.blob("hazard", 0.72, f.p(u + w / 2, d + 0.15, h - 1.75), scale=(1, 1, 0.72), detail=1, faceted=False)
        f.box("hazard", (1.7, 0.9, 0.1), (u + w / 2, d + 0.3, h - 2.05))
        cz = h - 3.3
        k.pole("chrome", 0.05, f.p(u + 0.6, d + 0.2, cz + 0.3), f.p(u + w - 0.6, d + 0.2, cz + 0.3), verts=4)
        f.outline("teal", [(u + 0.45, cz), (u + w - 0.45, cz), (u + w - 0.3, cz - 2.6), (u + w - 0.75, cz - 2.6), (u + w - 0.85, cz - 0.9),
                           (u + w - 0.85, cz - 5.6), (u + w / 2 + 0.1, cz - 5.6), (u + w / 2, cz - 3.4), (u + w / 2 - 0.1, cz - 5.6),
                           (u + 0.85, cz - 5.6), (u + 0.85, cz - 0.9), (u + 0.75, cz - 2.6), (u + 0.3, cz - 2.6)], d + 0.08, d + 0.4)
        f.cyl("hazard", 0.3, 0.06, (u + w * 0.68, d + 0.42, cz - 1.0), axis="n", verts=8)          # the gopher patch
        f.on("cream", u + 0.9, u + w - 0.9, cz - 3.3, cz - 3.05, d + 0.42, n0=d + 0.38)            # a belt
        # its door, swung wide
        with k.at(f.p(u + w, d, 0), f.yaw - 118):
            k.span(door, -w + 0.1, 0, -0.08, 0.08, 0.3, h)
            for i in range(4):
                k.span("gunmetal", -w + 0.6, -0.5, -0.1, 0.1, h - 1.0 - i * 0.32, h - 0.86 - i * 0.32)
    else:
        f.on(door, u + 0.12, u + w - 0.12, 0.42, h - 0.12, d + 0.14, n0=d)
        for i in range(4):
            f.on("gunmetal", u + 0.6, u + w - 0.6, h - 1.0 - i * 0.32, h - 0.86 - i * 0.32, d + 0.18, n0=d + 0.1)
        f.on("chrome", u + w - 0.7, u + w - 0.45, h * 0.45, h * 0.45 + 0.9, d + 0.3, n0=d + 0.1)
        f.on("cream", u + w / 2 - 0.45, u + w / 2 + 0.45, h - 2.9, h - 2.2, d + 0.2, n0=d + 0.12)
        f.text("navy", number, u + w / 2, h - 2.55, 0.46, n=d + 0.2, depth=0.03, flat=True)


def build(k):
    wall = k.face((-W / 2, -0.5, 0), 0)
    k.span("walnut", -W / 2, W / 2, -0.5, 0.0, 0, H)
    wall.on("cream", 0.5, W - 0.5, 0.0, H - 0.5, 0.12)
    k.collide_span(-W / 2, W / 2, -0.6, 0.0, 0, H + 3)
    for sx in (-1, 1):
        fin = [(0.0, 0.0), (0.0, H + 2.8), (-2.2, H + 2.8), (-DEPTH + 0.6, 6.5), (-DEPTH + 1.4, 0.0)]
        k.prism_x("teal", fin, sx * W / 2 - 0.3, sx * W / 2 + 0.3)
        k.prism_x("cream", [(-0.4, 5.6), (-0.4, 6.4), (-DEPTH + 0.9, 6.4), (-DEPTH + 1.0, 5.6)], sx * W / 2 - 0.36, sx * W / 2 + 0.36)
        k.collide_span(sx * W / 2 - 0.3, sx * W / 2 + 0.3, -DEPTH + 1.0, 0, 0, 7)
    # the sign
    k.span("teal", -W / 2 - 0.6, W / 2 + 0.6, -2.6, 0.0, H, H + 3.0)
    k.span("chrome", -W / 2 - 0.7, W / 2 + 0.7, -2.7, 0.05, H - 0.2, H)
    k.span("chrome", -W / 2 - 0.7, W / 2 + 0.7, -2.7, 0.05, H + 3.0, H + 3.2)
    sign = k.face((-W / 2, -2.6, 0), 0)
    sign.on("cream", 1.0, W - 1.0, H + 0.45, H + 2.55, 0.12)
    sign.text("teal", "LOADOUT", W / 2 - 3.2, H + 1.5, 1.55, n=0.12, depth=0.22, font="AlfaSlabOne-Regular", max_w=9.5, res=2)
    sign.text("signal", "Suit up!", W / 2 + 5.4, H + 1.45, 1.5, n=0.12, depth=0.2, font="Lobster-Regular", max_w=6)
    for i in range(15):
        k.bulb("cream", 0.2, sign.p(1.0 + i * (W - 2.0) / 14, 0.05, H - 0.32))
    k.light((0, -4.5, H - 1.5), colour="cream", brightness=0.8, range_=18)
    # lockers: three shut, one open with the Steadfast coverall
    locker(k, wall, 0.9, number="1")
    locker(k, wall, 4.0, number="2", door="mint")
    locker(k, wall, 7.1, open_door=True)
    locker(k, wall, 10.2, number="4")
    k.collide_span(-W / 2 + 0.9, -W / 2 + 13.2, -2.8, -0.5, 0, 9.4, name="Lockers")
    wall.on("teal", 0.9, 13.2, 9.2, 9.5, 2.4, n0=0.0)
    # hard hats on pegs over the lockers
    for i, sw in enumerate(("porcelain", "signal", "hazard", "teal")):
        u = 2.4 + i * 3.1
        k.blob(sw, 0.78, wall.p(u, 1.3, 9.95), scale=(1, 1, 0.7), detail=1, faceted=False)
        wall.box(sw, (1.9, 1.9, 0.1), (u, 1.4, 9.62))
    # the mirror: a chrome frame, a glass over a pale back
    mu0, mu1 = 14.3, 18.9
    wall.on("chrome", mu0 - 0.25, mu1 + 0.25, 1.0, 10.9, 0.2)
    wall.on("porcelain", mu0, mu1, 1.25, 10.65, 0.26)
    wall.glass(mu0, mu1, 1.25, 10.65, n=0.34, thick=0.08, swatch="mint", transparency=0.35)
    L.starburst(k, wall.p((mu0 + mu1) / 2, 0.3, 11.5), r=0.7, spikes=8, flat=True, neon=False, ball="signal")
    # a bench of walnut slats on chrome legs, boots under it, a duffel on it
    by = -DEPTH + 1.9
    for i in range(4):
        k.span("walnut", -8.2, 4.8, by - 0.95 + i * 0.5, by - 0.6 + i * 0.5, 1.55, 1.75)
    for x in (-7.4, -1.7, 4.0):
        for sy in (-0.8, 0.8):
            k.pole("chrome", 0.09, (x, by + sy, 1.55), (x, by + sy * 1.2, 0), verts=4)
        k.pole("chrome", 0.07, (x, by - 0.9, 1.5), (x, by + 0.9, 1.5), verts=4)
    k.collide_span(-8.2, 4.8, by - 1.0, by + 1.0, 0, 1.8, name="Bench")
    k.blob("olive", 1.35, (1.6, by, 2.45), scale=(1.55, 0.72, 0.6), detail=2, faceted=False)
    k.pole("leather", 0.07, (0.5, by - 0.5, 3.0), (2.7, by - 0.5, 3.0), verts=4)
    for x in (-6.2, -5.1):
        k.box("rubber", (0.8, 1.7, 0.5), (x, by - 0.15, 0.25))
        k.box("rubber", (0.8, 0.9, 1.3), (x, by + 0.3, 0.9))
        k.box("hazard", (0.84, 0.94, 0.14), (x, by + 0.3, 1.5))
    # a mat
    k.cyl("teal", 4.6, 0.04, (0, -DEPTH + 0.2, 0.02), verts=20, caps=(False, True))
    k.cyl("cream", 3.9, 0.04, (0, -DEPTH + 0.2, 0.035), verts=20, caps=(False, True))
    k.cyl("teal", 3.5, 0.04, (0, -DEPTH + 0.2, 0.05), verts=20, caps=(False, True))
    k.socket("Prompt", (0, -DEPTH - 0.2, 3.6), 0)
    return {"views": [
        ("front", (5, -34, 9), (0, -2, 7.4), 42),
        ("locker", (2, -13, 6.5), (-1, -2, 5.5), 58),
    ]}


if __name__ == "__main__":
    T.run(build, "Lobby_LoadoutBooth", "Lobby", budget=5000, res=(900, 620), ground="#EFE3C4", sun_strength=2.6, sky=False, ambient=2.4)
