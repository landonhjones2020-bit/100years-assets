"""Kit_Hazards: the two fittings that fail in a room (Prompt 23; bible Section 10: a flood is
fixed by patching the burst pipe, a gas leak by sealing the vent). DisasterService hangs one
on the room's back wall while its disaster lasts and puts the prompt on it; the client adds
the spray or the gas at its socket.

    Kit_BurstPipe  a copper water main on two wall brackets, split at its coupling: the two
                   halves knocked out of line, the torn copper peeled back, the steel collar
                   hanging off one side, a stop valve and a gauge with its needle on the pin.
                   Pivot: the pipe's middle, 1.2 studs out from the wall. Socket Spray.
    Kit_GasVent    a square louvred vent whose grille has blown: two bolts gone, the bottom
                   louvres bent out, hazard stripes over it, a crust the colour of the gas
                   along its sill. Pivot: its middle, 0.6 studs out from the wall. Socket Leak.

Both face Blender +Y (the room: the fitting is placed unturned on the wall at Roblox -Z).

    python3 generators/Kits/Kit_Hazards.py              preview of both
    SF_EXPORT=1 python3 generators/Kits/Kit_Hazards.py  exports both
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import steadfast as sf  # noqa: E402
from mathutils import Vector as V  # noqa: E402

CATEGORY = "Kit"
BUDGETS = {"Kit_BurstPipe": 1800, "Kit_GasVent": 1100}


def t(obj, part, swatch, **kw):
    return sf.tag(obj, part, swatch, collision="none", **kw)


def along_x(radius, x0, x1, y, z, verts=10, bevel=0.0, tilt=0.0, drop=0.0):
    """A pipe from x0 to x1; tilt (degrees) turns it about Y around its x0 end, drop lowers it."""
    o = sf.cyl(radius, abs(x1 - x0), loc=((x0 + x1) / 2, y, z - drop), rot=(0, 90 + tilt, 0), verts=verts, bevel=bevel)
    return o


def bolt(part, loc, facing="y", r=0.09):
    rot = (90, 0, 0) if facing == "y" else (0, 90, 0) if facing == "x" else (0, 0, 0)
    return t(sf.cyl(r, 0.12, loc=loc, rot=rot, verts=6, bevel=0.0), part, "gunmetal")


def burst_pipe():
    y = -0.45                                    # the pipe's centre line: 0.75 off the wall
    # ---- the main: two lengths of copper that used to meet in the middle
    t(along_x(0.5, -3.0, -0.42, y, 0.0), "Pipe", "copper")
    t(along_x(0.5, 0.5, 3.0, y, 0.0, tilt=-5, drop=0.16), "Pipe", "copper")
    for x in (-3.0, 3.0):                         # where it runs on into the wall's own pipework
        t(sf.ring(0.5, 0.66, 0.22, loc=(x * 0.965, y, -0.02 if x < 0 else -0.3), rot=(0, 90, 0), verts=10), "Pipe", "steel")
    # ---- the tear: petals of copper peeled back from each broken end, dark inside
    rnd = random.Random(23)
    for x_end, sx, drop in ((-0.42, 1, 0.0), (0.5, -1, 0.12)):
        for i in range(7):
            a = i * math.tau / 7 + rnd.uniform(-0.2, 0.2)
            ln = rnd.uniform(0.34, 0.62)
            root = V((x_end, y + 0.5 * math.cos(a), 0.5 * math.sin(a) - drop))
            out = V((sx * 0.75, 0.8 * math.cos(a), 0.8 * math.sin(a)))
            petal = sf.cyl(0.19, ln, loc=root + out.normalized() * ln * 0.42, verts=3, radius_top=0.0, bevel=0.0)
            petal.rotation_euler = out.to_track_quat("Z", "Y").to_euler()
            petal.scale = (1.0, 0.3, 1.0)
            t(petal, "Pipe", "copper")
        t(sf.cyl(0.44, 0.06, loc=(x_end - sx * 0.05, y, -drop), rot=(0, 90, 0), verts=10, bevel=0.0), "Pipe", "rubber")
    # the coupling that failed: one half still on the left length, cracked; a bolt hanging out of it
    t(sf.ring(0.5, 0.84, 0.26, loc=(-0.72, y, 0.0), rot=(0, 90, 0), verts=10), "Coupling", "steel")
    for i in range(6):
        a = i * math.tau / 6
        if i != 1:
            bolt("Coupling", (-0.55, y + 0.68 * math.cos(a), 0.68 * math.sin(a)), "x")
    half = sf.ring(0.5, 0.84, 0.26, loc=(0.95, y + 0.08, -0.62), rot=(24, 78, 0), verts=10)
    t(half, "Coupling", "steel")
    t(sf.cyl(0.07, 0.6, loc=(0.2, y + 0.42, -0.86), rot=(12, 62, 0), verts=6, bevel=0.0), "Coupling", "gunmetal")
    # ---- wall brackets: a plate on the wall, a standoff, a strap round the pipe
    for x in (-2.2, 2.3):
        dz = 0.0 if x < 0 else -0.22
        t(sf.box((0.9, 0.12, 1.7), loc=(x, -1.14, dz), bevel=0.0), "Bracket", "gunmetal")
        t(sf.box((0.5, 0.42, 0.5), loc=(x, -0.93, dz), bevel=0.0), "Bracket", "gunmetal")
        t(sf.ring(0.5, 0.6, 0.34, loc=(x, y, dz), rot=(0, 90, 0), verts=10), "Bracket", "steel")
        for bz in (-0.66, 0.66):
            bolt("Bracket", (x, -1.06, dz + bz), "y")
    # ---- the stop valve: a body on the left length and an orange hand wheel standing off it
    t(sf.cyl(0.62, 0.7, loc=(-1.45, y, 0.0), rot=(0, 90, 0), verts=8, bevel=0.03), "Valve", "brass")
    t(sf.cyl(0.14, 0.9, loc=(-1.45, y + 0.2, 0.75), rot=(-12, 0, 0), verts=8, bevel=0.0), "Valve", "steel")
    wheel_c = V((-1.45, y + 0.3, 1.2))
    wheel = sf.torus(0.52, 0.08, loc=wheel_c, rot=(-12, 0, 0), major_segs=14, minor_segs=4)
    t(wheel, "Valve", "signal")
    for i in range(4):
        a = i * math.pi / 4
        spoke = sf.box((1.0, 0.09, 0.07), loc=wheel_c, rot=(-12, 0, math.degrees(a)), bevel=0.0)
        t(spoke, "Valve", "signal")
    t(sf.cyl(0.12, 0.16, loc=wheel_c + V((0, 0.01, 0.06)), rot=(-12, 0, 0), verts=6, bevel=0.0), "Valve", "gunmetal")
    # ---- the gauge on the right length: its needle hard over
    t(sf.cyl(0.1, 0.5, loc=(1.75, y + 0.15, 0.42), verts=6, bevel=0.0), "Gauge", "brass")
    t(sf.cyl(0.42, 0.2, loc=(1.75, y + 0.28, 0.98), rot=(90, 0, 0), verts=12, bevel=0.03), "Gauge", "brass")
    t(sf.cyl(0.34, 0.03, loc=(1.75, y + 0.39, 0.98), rot=(90, 0, 0), verts=12, bevel=0.0), "Gauge", "cream")
    t(sf.box((0.05, 0.03, 0.3), loc=(1.86, y + 0.41, 1.02), rot=(0, 62, 0), bevel=0.0), "Gauge", "rust")
    # rust where it has wept for years: a stained band on each length beside the split
    t(sf.ring(0.5, 0.53, 0.5, loc=(-0.05 - 1.0, y, 0.0), rot=(0, 90, 0), verts=10), "Rust", "rust")
    t(sf.ring(0.5, 0.53, 0.4, loc=(1.05, y, -0.21), rot=(0, 85, 0), verts=10), "Rust", "rust")
    return {"pivot": (0.0, 0.0, 0.0), "sockets": {"Spray": ((0.05, y + 0.1, -0.05), 0.0)}}


def gas_vent():
    back = -0.6                                   # the wall
    # ---- the duct collar and the dark of the duct behind the grille
    t(sf.box((3.3, 0.5, 3.3), loc=(0, back + 0.25, 0), bevel=0.04), "Collar", "gunmetal")
    t(sf.box((2.7, 0.06, 2.7), loc=(0, back + 0.52, 0), bevel=0.0), "Duct", "rubber")
    for x in (-1.0, 0.0, 1.0):                    # the duct's ribs, seen through the gap
        t(sf.box((0.08, 0.1, 2.6), loc=(x, back + 0.56, 0), bevel=0.0), "Duct", "basalt")
    # ---- the frame: four bars; the bottom one has come away at the right
    t(sf.box((3.3, 0.18, 0.3), loc=(0, back + 0.6, 1.5), bevel=0.0), "Frame", "steel")
    t(sf.box((0.3, 0.18, 3.3), loc=(-1.5, back + 0.6, 0), bevel=0.0), "Frame", "steel")
    t(sf.box((0.3, 0.18, 3.3), loc=(1.5, back + 0.64, 0.02), rot=(0, 0, 3), bevel=0.0), "Frame", "steel")
    t(sf.box((3.3, 0.18, 0.3), loc=(0.06, back + 0.86, -1.5), rot=(0, 3, 9), bevel=0.0), "Frame", "steel")
    for x, z in ((-1.5, 1.5), (1.5, 1.5), (-1.5, -1.5)):
        bolt("Frame", (x, back + 0.72, z), "y", r=0.1)
    # ---- the louvres: the top three sit square, the bottom three are blown outwards
    slats = ((1.05, 0.0, 28, 0, 0.0), (0.6, 0.0, 28, 0, 0.0), (0.15, 0.02, 30, 0, 1.0), (-0.3, 0.16, 52, 4, 6.0),
             (-0.75, 0.34, 74, -5, 11.0), (-1.18, 0.5, 96, 7, 15.0))
    for z, out, pitch, roll, yaw in slats:
        t(sf.box((2.7, 0.07, 0.42), loc=(0.04 * yaw, back + 0.62 + out, z), rot=(pitch, roll, yaw), bevel=0.0),
          "Louvres", "steel")
    # ---- hazard stripes over it and a dead warning lamp
    t(sf.box((3.3, 0.1, 0.5), loc=(0, back + 0.42, 2.02), bevel=0.0), "Sign", "hazard")
    for x in (-1.3, -0.65, 0.0, 0.65, 1.3):
        t(sf.box((0.26, 0.03, 0.62), loc=(x, back + 0.485, 2.02), rot=(0, 35, 0), bevel=0.0), "Sign", "navy")
    t(sf.box((3.34, 0.14, 0.08), loc=(0, back + 0.42, 2.3), bevel=0.0), "Sign", "gunmetal")
    t(sf.box((3.34, 0.14, 0.08), loc=(0, back + 0.42, 1.74), bevel=0.0), "Sign", "gunmetal")
    t(sf.cyl(0.2, 0.2, loc=(1.9, back + 0.2, 2.02), rot=(90, 0, 0), verts=8, bevel=0.02), "Lamp", "gunmetal")
    t(sf.sphere(0.17, loc=(1.9, back + 0.34, 2.02), segs=8, rings=5), "Lamp", "rust")
    # ---- what the gas has left: an avocado crust along the sill and down the wall under it
    rnd = random.Random(29)
    for i in range(9):
        x = -1.5 + i * 0.37 + rnd.uniform(-0.08, 0.08)
        ln = rnd.uniform(0.25, 0.85)
        t(sf.cyl(0.11, ln, loc=(x, back + 0.5, -1.68 - ln / 2), verts=4, radius_top=0.03, bevel=0.0), "Crust", "avocado")
    for x, z, r in ((-1.2, -1.62, 0.22), (-0.5, -1.7, 0.28), (0.3, -1.66, 0.24), (1.1, -1.72, 0.3), (1.62, -1.2, 0.2), (-1.62, -0.9, 0.16)):
        t(sf.sphere(r, loc=(x, back + 0.55, z), scale=(1.2, 0.5, 0.8), segs=6, rings=4), "Crust", "avocado")
    return {"pivot": (0.0, 0.0, 0.0), "sockets": {"Leak": ((0.0, back + 1.0, -0.7), 0.0)}}


VARIANTS = {"Kit_BurstPipe": (burst_pipe, {"kit": "hazard", "disaster": "Flood"}),
            "Kit_GasVent": (gas_vent, {"kit": "hazard", "disaster": "GasLeak"})}


def export(name: str):
    build, meta = VARIANTS[name]
    sf.reset()
    extra = build()
    print(f"[{name}] triangles (before merge): {sf.tri_count()}")
    if os.environ.get("SF_NORENDER") != "1":
        print(sf.render_preview(name, CATEGORY, res=640, samples=24, views=[(140, 14, False), (205, 22, True)]))
    if os.environ.get("SF_EXPORT") == "1":
        doc = sf.export_asset(name, CATEGORY, pivot=extra["pivot"], sockets=extra["sockets"], budget=BUDGETS[name],
                              step="A8", meta=meta)
        print(f"[{name}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")


if __name__ == "__main__":
    for variant in (sys.argv[1:] or list(VARIANTS)):
        export(variant)
