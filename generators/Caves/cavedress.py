"""cavedress: each band's look on the eight cave layouts (A6; bible Section 6: the Mines are timber
props, lanterns and old carts, the Flooded Caverns dripping rock, standing water and burst pipes).
Find, Spawn, Nest and Crew spots stay clear: the game puts ore veins, crates, people and nests there.

    python3 generators/Caves/Cave_Mines_Tunnel.py        (each asset's script calls main)
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import cavelib as C  # noqa: E402
from cavelib import bx, cy, uid  # noqa: E402


def lights(layout, band):
    for name, value in layout["sockets"].items():
        if name.startswith("Light"):
            x, y, z = value
            C.lantern(x, y, z, band)


def plate(shell, band):
    """The Entry's rock face: it stands where the dug cell's back wall was (the cell's 34 x 20
    back), with the tunnel's 14 x 12 opening, rock bulging up to 2.5 studs into the cell."""
    b = C.BANDS[band]
    y = 0.75
    bx(uid("Plate"), b["wall"], (10, 1.5, 20), (-12, y, 8), collision="box")
    bx(uid("Plate"), b["wall"], (10, 1.5, 20), (12, y, 8), collision="box")
    bx(uid("Plate"), b["wall"], (14, 1.5, 6), (0, y, 15), collision="box")
    rnd = shell.rnd
    for k in range(16):
        x = rnd.uniform(-16, 16)
        z = rnd.uniform(1.5, 16.5)
        if abs(x) < 8.2 and z < 13:
            x = math.copysign(rnd.uniform(9, 16), x if x != 0 else 1)
        shell.rock((x, 1.5 + rnd.uniform(0.2, 0.8), z), rnd.uniform(1.6, 2.6))
    # a ragged rim round the hole
    for k in range(9):
        a = math.radians(-8 + k * 196 / 8)
        shell.rock((math.cos(a) * 8.2, 2.0, 6 + math.sin(a) * 6.8 if a < math.pi else 0.9), 1.7)


# The Mines --------------------------------------------------------------------------------------

def mines(kind):
    def dress(shell, rnd):
        lay = shell.layout
        h = lay["h"]
        lights(lay, "Mines")
        if kind == "Entry":
            plate(shell, "Mines")
            C.timber_frame(-3, C.TH)
            C.timber_frame(-15, C.TH, leaning=4)
            C.rails(0, -24)
            shell.rubble(5, (-6, 6, -22, -3))
        elif kind == "Tunnel":
            for y, lean in ((-5, 0), (-17, 5), (-28, -3)):
                C.timber_frame(y, C.TH, leaning=lean)
            C.rails(0, -32)
            shell.rubble(6, (-6, 6, -30, -2))
            bx("Decor", "walnut", (0.9, 6.5, 0.9), (4.5, -22, 0.6), rot=(0, 0, 20))           # a fallen prop
        elif kind == "Junction":
            C.timber_frame(-4, C.TH)
            C.rails(0, -12)
            for x in (-18, 18):
                bx("Decor", "pine", (1.0, 15.5, 1.0), (x, -19, C.TH - 0.9))
                for yy in (-12.5, -25.5):
                    bx("Decor", "walnut", (0.9, 0.9, C.TH - 0.4), (x, yy, (C.TH - 0.4) / 2))
            C.ore_cart(-17, -21.5, rot=10, tipped=True)
            C.crate_stack(19, -15.5, n=2, seed=3)
            shell.rubble(5, (-24, 24, -25, -13))
        elif kind == "Pocket":
            C.timber_frame(-2.5, C.TH, leaning=3)
            C.crate_stack(-8.5, -7, n=2, seed=5)
            bx("Decor", "walnut", (0.9, 0.9, 7), (8, -8, 0.5), rot=(0, 75, 30))              # a broken prop
            shell.rubble(7, (-10, 10, -23, -5))
        elif kind == "Chamber":
            C.timber_frame(-2.5, C.TH)
            C.rails(0, -36)
            C.ore_cart(-9, -27, rot=-8)
            C.crate_stack(15, -19.5, n=3, seed=7)
            for (x, y) in ((-10, -15), (8, -14)):
                bx("Decor", "walnut", (1.1, 1.1, h - 0.4), (x, y, (h - 0.4) / 2))
                bx("Decor", "pine", (6, 1.1, 1.1), (x, y, h - 1.0))
            shell.rubble(8, (-16, 16, -34, -3))
        elif kind == "Cavern":
            C.timber_frame(-2, C.TH)
            # a scaffold up the left wall where the old crew worked the seam
            for yy in (-18, -28, -38):
                bx("Decor", "walnut", (0.9, 0.9, 12), (-22, yy, 6))
            bx("Decor", "pine", (4, 22, 0.6), (-23.5, -28, 6.5))
            bx("Decor", "pine", (4, 22, 0.6), (-23.5, -28, 11.5))
            C.ore_cart(11, -22, rot=25, tipped=True)
            C.ore_cart(-9, -47.5, rot=90)
            C.crate_stack(22, -28, n=2, seed=11)
            shell.rubble(12, (-24, 24, -50, -6))
        elif kind == "Drop":
            C.timber_frame(-3, C.TH)
            C.timber_frame(-31, C.TH, z0=-9)
            bx("Decor", "walnut", (0.6, 19.5, 0.3), (-5.5, -17, -4.2), rot=(math.degrees(math.atan2(9, 18)), 0, 0))
            bx("Decor", "walnut", (0.6, 19.5, 0.3), (5.5, -17, -4.2), rot=(math.degrees(math.atan2(9, 18)), 0, 0))
            shell.rubble(4, (-6, 6, -33, -27))
        elif kind == "CrewPocket":
            crew_camp(shell, rnd, "Mines")
            C.timber_frame(-2, C.TH)
    return dress


# The Flooded Caverns ----------------------------------------------------------------------------

def flooded(kind):
    def dress(shell, rnd):
        lay = shell.layout
        h = lay["h"]
        lights(lay, "Flooded")
        rect = lay["rects"][-1]
        if kind == "Entry":
            plate(shell, "Flooded")
            C.pool(0, -15, 10, 12)
            C.pipe_run(-2, -22, -6.2, 9.5, burst_at=-14)
            C.stalactites(rnd, rect, h, 6)
            C.algae(rnd, 6.4, -10, 4)
        elif kind == "Tunnel":
            C.pool(0, -18, 11, 18)
            C.pipe_run(-1, -31, -6.2, 9.0, burst_at=-21)
            C.stalactites(rnd, rect, h, 8)
            C.algae(rnd, 6.6, -8, 5)
            C.algae(rnd, -6.6, -27, 3)
            C.glow_caps(rnd, 5, -28, 4)
        elif kind == "Junction":
            C.pool(-12, -19, 18, 10)
            C.pipe_run(-13, -25, 25.4, 9.5, burst_at=None)
            C.stalactites(rnd, rect, h, 10)
            C.glow_caps(rnd, 20, -24, 5)
            C.algae(rnd, -25.4, -16, 4)
        elif kind == "Pocket":
            C.pool(0, -17, 14, 10)
            C.stalactites(rnd, rect, h, 7)
            C.glow_caps(rnd, -8, -8, 5)
            C.algae(rnd, 10.6, -14, 4)
        elif kind == "Chamber":
            C.pool(-6, -22, 16, 18)
            C.pipe_run(-3, -34, 17.4, 12.0, burst_at=-17)
            C.stalactites(rnd, rect, h, 14)
            C.glow_caps(rnd, -14, -31, 6)
            C.algae(rnd, -17.6, -12, 5)
        elif kind == "Cavern":
            C.pool(0, -28, 30, 26)
            C.pool(-16, -46, 12, 8)
            C.stalactites(rnd, rect, h, 20)
            C.pipe_run(-6, -48, 25.4, 14.0, burst_at=-30)
            C.glow_caps(rnd, -20, -24, 7)
            C.glow_caps(rnd, 20, -48, 5)
            C.algae(rnd, -25.6, -40, 5)
            shell.rubble(6, (-24, 24, -50, -6))
        elif kind == "Drop":
            # water running down the slope into a pool at the bottom
            ang = math.degrees(math.atan2(9, 18))
            bx("Water", "skyblue", (6, 19.8, 0.1), (0, -17, -4.0), rot=(ang, 0, 0), mat="Glass", transparency=0.55,
               cast_shadow=False)
            C.pool(0, -30, 12, 7)
            C.pipe_run(-1, -12, 6.2, 9.0, burst_at=-8)
            C.stalactites(rnd, rect, h, 6)
        elif kind == "CrewPocket":
            crew_camp(shell, rnd, "Flooded")
            C.pool(-9, -16, 8, 8)
            C.stalactites(rnd, rect, h, 8)
    return dress


# The Lost Crew's camp (both bands) ------------------------------------------------------------------

def crew_camp(shell, rnd, band):
    """Where a Steadfast work crew holed up after the cave-in: a teal tarp over the back, bedrolls,
    crates of their kit, hard hats, a notice board, a work lamp, and the rock fall that shut them in."""
    # the tarp, slung from the back wall over the crew
    bx("Decor", "teal", (26, 7, 0.3), (0, -28.5, 8.5), rot=(-28, 0, 0))
    for x in (-12, 12):
        bx("Decor", "walnut", (0.6, 0.6, 9), (x, -25.5, 4.5))
    for (x, y) in ((-8, -22.5), (0, -25.0), (8, -22.5)):
        bx("Decor", "cream", (2.4, 5.0, 0.35), (x, y + 2.5, 0.18))               # bedrolls in front of each crew spot
    C.crate_stack(-12.5, -12.5, n=2, seed=13)
    C.crate_stack(12.5, -22, n=1, seed=14)
    for (x, y, r) in ((-4.5, -15, 30), (5, -17, -50), (-11, -19, 10)):
        C.hard_hat(x, y, r)
    C.steadfast_board(-13.6, -27, 3.2, w=3.6, h=2.0, rot=90)
    # a work lamp on a tripod
    for a in (0, 120, 240):
        bx("Decor", "gunmetal", (0.15, 0.15, 3.4), (11 + 0.5 * math.cos(math.radians(a)), -8 + 0.5 * math.sin(math.radians(a)), 1.6),
           rot=(10 * math.cos(math.radians(a)), 10 * math.sin(math.radians(a)), 0))
    cy("DecorNeon", "hazard", 0.45, 0.4, (11, -8, 3.5), rot=(90, 0, 0), mat="Neon", cast_shadow=False)
    # the rock fall in the corner that shut them in
    for k in range(9):
        shell.rock((rnd.uniform(-14, -6), rnd.uniform(-31, -27), rnd.uniform(1.5, 8.5)), rnd.uniform(1.6, 2.8))


def main(band, kind, seed=7):
    dress = mines(kind) if band == "Mines" else flooded(kind)
    C.run(band, kind, dress, seed=seed + (0 if band == "Mines" else 101) + sum(map(ord, kind)))
