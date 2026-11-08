"""Kit_Shaft: the Shaft's stair up to the Shaft above, by level (A1; bible Section 6: stairs,
resident lift and drop chute between floors).

Goes in a Shaft cell that has a Shaft above it, with Kit_CeilingHole over it and
Kit_FloorHole in the cell above. The stair climbs along the back wall from the left (x -14,
the floor) to the right (x +14, the next floor up, 18 higher), under the opening at the back
right. It walks on an invisible ramp (hull collision); the steps, stringers and rails are
decoration.

    L1  steel stair with a chrome handrail, a floor-number plate and a hazard-striped landing
    L2  adds the resident lift: a caged platform on rails in the front-left corner
    L3  adds the drop chute (a chrome tube with a landing pad) and running lights

Sockets: Bottom, Top (the stair's ends, for resident paths), Lift (L2+), Chute (L3).

    python3 generators/Kits/Kit_Shaft.py              preview of the three levels
    SF_EXPORT=1 python3 generators/Kits/Kit_Shaft.py  exports Kit_Shaft_L1..L3
"""
import math
import os
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import steadfast as sf  # noqa: E402
from kitlib import D, H, HOLE, S, T, W, t  # noqa: E402

CATEGORY = "Kit"
RISE = H + S                    # 18: to the next floor up
X_LOW, X_HIGH = -14.0, 14.0
Y0, Y1 = HOLE[2], HOLE[3]       # the stair runs along the back strip (y 8 to 16)
STEPS = 12


def ramp():
    """The walking surface: one thin convex slab from the floor to the floor above."""
    run = X_HIGH - X_LOW
    ln = math.hypot(run, RISE)
    ang = math.degrees(math.atan2(RISE, run))
    lift_by = RISE / STEPS / 2  # through the middle of each step's tread, so feet land on the steps
    o = sf.box((ln, Y1 - Y0, 0.6), loc=(0, (Y0 + Y1) / 2, RISE / 2 + lift_by - 0.3 / math.cos(math.radians(ang))),
               rot=(0, -ang, 0), bevel=0.0)
    t(o, "StairRamp", "steel", collision="hull", transparency=1.0, cast_shadow=False)


def stair(level: int):
    run = (X_HIGH - X_LOW) / STEPS
    rise = RISE / STEPS
    tread = "gunmetal" if level < 3 else "steel"
    for i in range(STEPS):
        x = X_LOW + run * (i + 0.5)
        z = rise * (i + 1)
        t(sf.box((run + 0.3, Y1 - Y0 - 0.6, 0.35), loc=(x, (Y0 + Y1) / 2, z - 0.175), bevel=0.05, segments=1),
          "Steps", tread)
        t(sf.box((0.25, Y1 - Y0 - 0.8, 0.12), loc=(x - run / 2 + 0.2, (Y0 + Y1) / 2, z - 0.02), bevel=0.0),
          "StepNosing", "hazard")
    # stringers under the front edge and against the back wall
    run_all = X_HIGH - X_LOW
    ln = math.hypot(run_all, RISE)
    ang = math.degrees(math.atan2(RISE, run_all))
    for y in (Y0 + 0.25, Y1 - 0.4):
        t(sf.box((ln, 0.5, 1.4), loc=(0, y, RISE / 2 - 0.9), rot=(0, -ang, 0), bevel=0.08, segments=1), "Stringers", "steel")
    # a support post under the high end
    t(sf.box((0.8, 0.8, RISE - 2.0), loc=(X_HIGH - 1.0, Y0 + 0.6, (RISE - 2.0) / 2), bevel=0.08, segments=1), "Stringers", "steel",
      collision="box")
    # chrome handrail on the open (front) side, on posts
    for i in range(0, STEPS + 1, 3):
        x = X_LOW + (X_HIGH - X_LOW) * i / STEPS
        z = RISE * i / STEPS
        t(sf.cyl(0.11, 3.2, loc=(x, Y0 + 0.25, z + 1.6), verts=6, bevel=0.0), "Handrail", "chrome")
    t(sf.cyl(0.13, ln, loc=(0, Y0 + 0.25, RISE / 2 + 3.2), rot=(0, 90 - ang, 0), verts=8, bevel=0.0), "Handrail", "chrome")
    # landing at the foot: hazard plate and a floor plate on the back wall
    t(sf.box((4.0, Y1 - Y0, 0.08), loc=(X_LOW - 0.5, (Y0 + Y1) / 2, 0.04), bevel=0.0), "Landing", "hazard")
    for i in range(4):
        t(sf.box((0.7, Y1 - Y0 - 0.4, 0.04), loc=(X_LOW - 2.0 + i * 1.1, (Y0 + Y1) / 2, 0.1), rot=(0, 0, 30), bevel=0.0),
          "Landing", "rubber")
    t(sf.box((3.2, 0.15, 1.8), loc=(X_LOW + 1.0, D / 2 - 0.08, 6.0), bevel=0.04, segments=1), "FloorPlate", "navy")
    t(sf.box((2.8, 0.1, 0.25), loc=(X_LOW + 1.0, D / 2 - 0.16, 6.6), bevel=0.0), "FloorPlate", "hazard")
    t(sf.box((0.5, 0.12, 0.9), loc=(X_LOW + 1.0, D / 2 - 0.18, 5.7), rot=(0, 0, 0), bevel=0.0), "FloorPlate", "cream")


def lift():
    """The resident lift: a caged platform on two rails, front-left corner."""
    cx, cy = -10.5, -9.5
    for dx in (-2.6, 2.6):
        t(sf.box((0.5, 0.5, H), loc=(cx + dx, cy + 3.0, H / 2), bevel=0.06, segments=1), "LiftRails", "gunmetal", collision="box")
    t(sf.box((5.6, 5.6, 0.4), loc=(cx, cy, 0.2), bevel=0.06, segments=1), "LiftCar", "steel", collision="box")
    t(sf.box((5.6, 5.6, 0.3), loc=(cx, cy, 7.4), bevel=0.06, segments=1), "LiftCar", "steel")
    for (dx, dy) in ((-2.6, -2.6), (2.6, -2.6), (-2.6, 2.6), (2.6, 2.6)):
        t(sf.cyl(0.12, 7.0, loc=(cx + dx, cy + dy, 3.8), verts=6, bevel=0.0), "LiftCage", "chrome")
    for z in (2.4, 4.8):
        for (dx, dy, lx, ly) in ((0, -2.6, 5.2, 0.12), (0, 2.6, 5.2, 0.12), (-2.6, 0, 0.12, 5.2)):
            t(sf.box((lx, ly, 0.12), loc=(cx + dx, cy + dy, z), bevel=0.0), "LiftCage", "chrome")
    t(sf.box((1.0, 0.4, 1.4), loc=(cx + 2.9, cy - 2.9, 4.2), bevel=0.08, segments=1), "LiftControl", "teal")
    t(sf.cyl(0.18, 0.2, loc=(cx + 2.9, cy - 3.15, 4.5), rot=(90, 0, 0), verts=8, bevel=0.0), "LiftControl", "signal")
    t(sf.cyl(0.18, 0.2, loc=(cx + 2.9, cy - 3.15, 3.9), rot=(90, 0, 0), verts=8, bevel=0.0), "LiftControl", "leaf")
    return (cx, cy, 0.0)


def chute():
    """The drop chute: a chrome tube from the ceiling to a cushioned landing pad."""
    cx, cy = 9.0, -9.0
    t(sf.cyl(2.2, H - 6.0, loc=(cx, cy, 6.0 + (H - 6.0) / 2), verts=12, bevel=0.0), "Chute", "chrome")
    t(sf.torus(2.25, 0.25, loc=(cx, cy, 6.0), major_segs=12, minor_segs=4), "Chute", "brass")
    t(sf.cyl(1.9, 0.6, loc=(cx, cy, H - 0.6), verts=12, bevel=0.0), "Chute", "gunmetal")
    t(sf.cyl(3.0, 0.8, loc=(cx, cy, 0.4), verts=12, bevel=0.0), "ChutePad", "signal", collision="box")
    t(sf.cyl(2.6, 0.82, loc=(cx, cy, 0.42), verts=12, bevel=0.0), "ChutePad", "hazard")
    for i in range(6):
        a = i * math.pi / 3
        t(sf.box((0.6, 0.3, 0.3), loc=(cx + 2.45 * math.cos(a), cy + 2.45 * math.sin(a), 6.8), bevel=0.0),
          "ChuteLights", "signal", mat="Neon", cast_shadow=False)
    return (cx, cy, 0.0)


def build(level: int) -> dict:
    sf.reset()
    ramp()
    stair(level)
    sockets = {"Bottom": ((X_LOW - 1.0, (Y0 + Y1) / 2, 0.0), 0.0), "Top": ((X_HIGH, (Y0 + Y1) / 2, RISE), 0.0)}
    if level >= 2:
        sockets["Lift"] = (lift(), 0.0)
    if level >= 3:
        sockets["Chute"] = (chute(), 0.0)
        for i in range(STEPS):           # running lights under the step nosing
            x = X_LOW + (X_HIGH - X_LOW) * (i + 0.5) / STEPS
            t(sf.box((0.6, 0.18, 0.12), loc=(x, Y0 + 0.1, RISE * (i + 1) / STEPS - 0.45), bevel=0.0),
              "RunningLights", "hazard", mat="Neon", cast_shadow=False)
    return sockets


def preview():
    sf.reset()
    import Kit_Shell as shell
    pitch = W + 2 * T
    for i, level in enumerate((1, 2, 3)):
        before = set(bpy.context.scene.objects)
        ramp()
        stair(level)
        if level >= 2:
            lift()
        if level >= 3:
            chute()
        shell.floor(False)
        shell.wall_y("BackWall", D / 2, -1, True, "box")
        for o in [o for o in bpy.context.scene.objects if o not in before]:
            o.location.x += (i - 1) * pitch
    print(sf.render_preview("Kit_Shaft", CATEGORY, res=640, samples=24, merge="part",
                            views=[(0, 16, False), (-30, 26, False)]))


if __name__ == "__main__":
    if os.environ.get("SF_EXPORT") == "1":
        for level in (1, 2, 3):
            sockets = build(level)
            doc = sf.export_asset(f"Kit_Shaft_L{level}", CATEGORY, pivot=(0, 0, 0), merge="room", budget=3000,
                                  step="A1", sockets=sockets, meta={"kit": "shaft", "level": level, "rise": RISE,
                                                                     "ramp": [X_LOW, X_HIGH, Y0, Y1]})
            print(f"[Kit_Shaft_L{level}] {len(doc['parts'])} MeshParts, {doc['tris']} tris, size {doc['size']}")
    else:
        preview()
