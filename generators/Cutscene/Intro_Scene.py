"""Intro_Scene: the intro cutscene's set and camera in Blender (bible Section 4: "Opus animates the
camera in the same Blender, exports the path as keyframes (time, position, rotation) into a Luau
data module and commits it to the art repo").

It puts the set together from the repo's exported models exactly as the game does (the plan is
generators/Cutscene/cutscene_plan.py), keys the camera shot by shot (SHOTS below: real keyframes
on a camera, its target and its up, with Blender's own curves between them), renders a storyboard
through that camera, and writes what the game needs:

    python3 generators/Cutscene/Intro_Scene.py              # previews/Cutscene/Storyboard.png
    python3 generators/Cutscene/Intro_Scene.py --data       # cutscene/IntroPath.luau (tools/cutscene_config.py copies it into the game)
    SF_AT=6.5,12 python3 generators/Cutscene/Intro_Scene.py     # only those moments, full size, in /tmp/cs

Shots 1 to 4 and the dive are in the set's space. The plunge past the bunker, the Source and the
title are in the bunker's: the grid's origin (floor 1, column 0, the centre of its floor), Roblox
axes, the camera on +Z as in the Command View. Here that space is drawn far off to one side
(BUNKER_AT) with stand-ins for the rooms and the rock, so the path can be seen; the game plays it
in front of the run's real bunker. What moves in the storyboard (the door, the runners, the bomb,
the cloud, the flash) is a stand-in for what the game's CutsceneController does at the same times
(cutscene_plan.BEATS).
"""
from __future__ import annotations

import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import cutscene_plan as CP  # noqa: E402
import scenelib as SL  # noqa: E402
import steadfast as sf  # noqa: E402

AX = CP.AXIS
B = CP.BEATS
DOOR_AT = (CP.DOOR_X, AX, CP.TERRACE_Z)
DOOR_YAW = -90.0
FPS = 30.0
RATE = 15                                   # keys a second in the data module
BUNKER_AT = Vector((0.0, 4000.0, 0.0))      # where the bunker's space is drawn in this scene
TO_ROBLOX = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))      # (x, y, z) -> (-x, z, y): a rotation, so yaws carry over
UP = (0.0, 0.0, 1.0)


def G(x: float, y: float, z: float) -> tuple[float, float, float]:
    """A point of the bunker's space (Roblox axes from the grid's origin) in this scene."""
    return (-x + BUNKER_AT.x, z + BUNKER_AT.y, y + BUNKER_AT.z)


# -- the camera, shot by shot -----------------------------------------------------------------------
# Each key: (seconds, where the camera is, what it looks at, vertical field of view[, up]).
# "linear" shots drift at a steady pace (a cut lands on a camera already moving); "smooth" ones ease.
CMD_DIST = 440.0                            # the Command View's distance (Tuning.CommandView.MaxDistance)
ROCK_FACE = 19.2                            # how far the game's rock cells stand out from the grid's plane (measured in Studio)
PLUNGE_H = 72.0                             # studs of the bunker the plunge shows top to bottom: four floors
SOURCE_X, SOURCE_Y = CP.SOURCE_AT
MEDBAY = (2 * CP.GRID_PITCH[0], -CP.GRID_PITCH[1] + 3.0)      # where players stand at the start: column 2, floor 2


def fov_for(height: float, distance: float = CMD_DIST) -> float:
    return math.degrees(2 * math.atan(height / 2 / distance))


def cmd(x: float, y: float, height: float):
    """A Command View style key: straight at the bunker's front from CMD_DIST, showing `height` studs."""
    return G(x, y, CMD_DIST), G(x, y, 0.0), fov_for(height)


def plunge(t0: float, t1: float, y0: float, y1: float, n: int = 28, power: float = 1.5):
    """The fall: already at speed as the shot begins (it is cut from the dive), past the ground and the
    bunker's rooms at an even rush, braking to a stop over the Source. power 1.5: half as fast again as
    its average at the start, still by the end; the bunker's two floors are in the picture for a second."""
    keys = []
    for i in range(n + 1):
        u = i / n
        keys.append((t0 + (t1 - t0) * u, *cmd(SOURCE_X, y0 + (y1 - y0) * (1 - (1 - u) ** power), PLUNGE_H)))
    return keys


SHOTS = [
    {"Name": "MainStreet", "From": 0.0, "To": 5.0, "Space": "Set", "Ease": "smooth", "Text": "Sunny Main Street: the billboard's promise, the siren, then the hill it points at.",
     "Keys": [
         (0.0, (30.0, AX - 13.0, 7.6), (37.0, -54.0, 37.4), 36.0),
         (1.5, (31.5, AX - 12.6, 7.7), (40.0, -54.0, 37.5), 35.0),
         (3.5, (40.0, AX - 8.0, 7.2), (330.0, AX, 33.0), 29.0),
         (5.0, (52.0, AX - 7.5, 7.4), (345.0, AX, 37.0), 27.0),
     ]},
    {"Name": "Path", "From": 5.0, "To": 7.6, "Space": "Set", "Ease": "linear", "Text": "From the path's head: the party and the founders sprint up, the town behind them.",
     "Keys": [
         (5.0, (CP.STAIR_TOP_X - 1.0, AX, CP.TERRACE_Z + 6.4), (278.0, AX, 3.0), 36.0),
         (7.6, (CP.STAIR_TOP_X + 0.6, AX, CP.TERRACE_Z + 6.0), (316.0, AX, 17.0), 39.0),
     ]},
    {"Name": "Door", "From": 7.6, "To": 10.0, "Space": "Set", "Ease": "linear", "Text": "From the bank beside the path: they take the top flight and cross the terrace into the open door.",
     "Keys": [
         (7.6, (332.5, AX + 14.0, CP.TERRACE_Z + 5.2), (355.0, AX - 2.0, CP.TERRACE_Z + 5.4), 48.0),
         (10.0, (334.5, AX + 13.0, CP.TERRACE_Z + 5.0), (355.5, AX - 1.4, CP.TERRACE_Z + 5.8), 45.0),
     ]},
    {"Name": "Bomb", "From": 10.0, "To": 12.5, "Space": "Set", "Ease": "linear", "Text": "From the terrace: a bomb crosses the sky over the town.",
     "Keys": [
         (10.0, (CP.STAIR_TOP_X - 0.5, AX + 2.0, CP.TERRACE_Z + 6.5), (-30.0, AX + 66.0, 140.0), 56.0),
         (12.5, (CP.STAIR_TOP_X - 1.5, AX + 1.5, CP.TERRACE_Z + 6.5), (-60.0, AX + 46.0, 118.0), 53.0),
     ]},
    {"Name": "Sealed", "From": 12.5, "To": 15.0, "Space": "Set", "Ease": "linear", "Text": "The blast door rolls shut and locks.",
     "Keys": [
         (12.5, (328.4, AX, 21.0 + 5.2), (CP.DOOR_X, AX, CP.TERRACE_Z + 11.0), 50.0),
         (15.0, (331.4, AX, 21.0 + 5.8), (CP.DOOR_X, AX, CP.TERRACE_Z + 10.8), 48.0),
     ]},
    {"Name": "Blast", "From": 15.0, "To": 21.0, "Space": "Set", "Ease": "smooth", "Text": "White. The shockwave crosses the town; the cloud climbs.",
     "Keys": [
         (15.0, (262.0, AX, 66.0), (-150.0, AX, 46.0), 54.0),
         (18.4, (286.0, AX, 76.0), (-150.0, AX, 86.0), 56.0),
         (21.0, (318.0, AX, 92.0), (-150.0, AX, 142.0), 58.0),
     ]},
    {"Name": "Dive", "From": 21.0, "To": 22.2, "Space": "Set", "Ease": "smooth", "Text": "The camera turns down and drops into the hill.",
     "Keys": [
         (21.0, (318.0, AX, 92.0), (-150.0, AX, 142.0), 58.0, UP),
         (21.55, (330.0, AX, 86.0), (296.0, AX, 8.0), 60.0, (-0.7, 0.0, 0.7)),
         (22.2, (348.0, AX, CP.TERRACE_Z + 3.0), (348.5, AX, CP.TERRACE_Z), 62.0, (-1.0, 0.0, 0.0)),
     ]},
    {"Name": "Plunge", "From": 22.2, "To": 25.7, "Space": "Bunker", "Ease": "linear", "Text": "Down through the rock, past the bunker's rooms, deeper.",
     "Keys": plunge(22.2, 25.7, CP.STRATA["Top"] - 42.0, SOURCE_Y + 6.0)},
    {"Name": "Source", "From": 25.7, "To": 27.0, "Space": "Bunker", "Ease": "linear", "Text": "Something glowing opens its eyes.",
     "Keys": [
         (25.7, *cmd(SOURCE_X, SOURCE_Y + 6.0, PLUNGE_H)),
         (27.0, *cmd(SOURCE_X, SOURCE_Y + 1.0, 46.0)),
     ]},
    # The game ends this shot itself: it settles on the player's own character, wherever they stand
    # and whatever the screen's shape, then hands over to the over-the-shoulder camera. These keys
    # are the same move for someone standing in the Medbay.
    {"Name": "Title", "From": 27.0, "To": 30.0, "Space": "Bunker", "Ease": "smooth", "Handover": True, "Text": "The title; the camera settles into the Command View, then drops to the player.",
     "Keys": [
         (27.0, *cmd(MEDBAY[0], MEDBAY[1] + 6.0, 84.0)),
         (28.4, *cmd(MEDBAY[0], MEDBAY[1] + 6.0, 108.0)),
         (28.7, *cmd(MEDBAY[0], MEDBAY[1] + 6.0, 108.0)),
         (30.0, G(MEDBAY[0] + 2.4, MEDBAY[1] + 5.4, 9.0), G(MEDBAY[0] + 1.6, MEDBAY[1] + 4.6, 0.0), 70.0),
     ]},
]
STORYBOARD = [0.4, 2.3, 4.4, 5.3, 6.6, 7.9, 8.9, 9.7, 10.6, 12.0, 13.3, 14.7, 15.3, 16.5, 17.5, 18.6, 19.6, 20.8, 21.6, 22.9, 23.9, 25.0, 26.7, 28.2]


# -- keyframes -----------------------------------------------------------------------------------------

def _frame(i: int, shot: dict, t: float) -> float:
    return i * 10000.0 + (t - shot["From"]) * FPS


def key_camera():
    """The camera, its target and its up as three keyed objects; returns them with their curves."""
    rig = {}
    for name in ("Cam", "CamTarget", "CamUp"):
        o = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(o)
        rig[name] = o
    lens = bpy.data.objects.new("CamFov", None)       # its X is the field of view
    bpy.context.scene.collection.objects.link(lens)
    rig["CamFov"] = lens
    for i, shot in enumerate(SHOTS):
        for k in shot["Keys"]:
            t, at, look, fov = k[0], k[1], k[2], k[3]
            up = k[4] if len(k) > 4 else UP
            f = _frame(i, shot, t)
            for name, value in (("Cam", at), ("CamTarget", look), ("CamUp", up), ("CamFov", (fov, 0.0, 0.0))):
                rig[name].location = Vector(value)
                rig[name].keyframe_insert("location", frame=f)
    curves = {}
    for name, o in rig.items():
        fcs = sorted(sf._action_fcurves(o.animation_data.action), key=lambda fc: fc.array_index)
        for fc in fcs:
            for kp in fc.keyframe_points:
                shot = SHOTS[int(round(kp.co.x)) // 10000] if kp.co.x >= 0 else SHOTS[0]
                ease = shot.get("Ease", "linear")
                if ease == "linear":
                    kp.interpolation = "LINEAR"
                elif ease == "plunge":                   # already falling when the shot begins, braking at its end
                    kp.interpolation = "QUAD"
                    kp.easing = "EASE_OUT"
                else:
                    kp.interpolation = "BEZIER"
                    kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
            fc.update()
        curves[name] = fcs
    return curves


def pose_at(curves, t: float):
    """The camera at t seconds: (position, rotation matrix, field of view, shot)."""
    i = len(SHOTS) - 1
    for n, shot in enumerate(SHOTS):
        if t < shot["To"] or n == len(SHOTS) - 1:
            i = n
            break
    shot = SHOTS[i]
    f = _frame(i, shot, min(max(t, shot["From"]), shot["To"]))

    def ev(name):
        return Vector([fc.evaluate(f) for fc in curves[name]])

    at, look, up = ev("Cam"), ev("CamTarget"), ev("CamUp")
    back = (at - look).normalized()
    right = up.cross(back)
    if right.length < 1e-5:
        right = Vector((0, 1, 0)).cross(back)
    right.normalize()
    true_up = back.cross(right)
    rot = Matrix((right, true_up, back)).transposed()          # columns: right, up, back (the camera looks down -Z)
    return at, rot, ev("CamFov").x, shot


def to_game(at: Vector, rot: Matrix, space: str):
    """Position and rotation in the game's axes, from the space's own origin."""
    p = at - BUNKER_AT if space == "Bunker" else at
    pr = TO_ROBLOX @ p
    q = (TO_ROBLOX @ rot).to_quaternion()
    return (pr.x, pr.y, pr.z), (q.x, q.y, q.z, q.w)


# -- the set ---------------------------------------------------------------------------------------------

def placements() -> list[dict]:
    """Everything that stands on the set: asset, category, where, how it is turned, and what the
    blast does to it (Kind). The game's set is built from this list."""
    out = []

    def put(asset, category, x, y, z, yaw, scale=1.0, kind="Still", paint=None, name=None):
        out.append({"Asset": asset, "Category": category, "P": (round(x, 3), round(y, 3), round(z, 3)), "Yaw": round(yaw, 3),
                    "Scale": round(scale, 4), "Kind": kind, "Paint": paint, "Name": name or asset.split("_", 1)[1]})

    for a in CP.SHOWROOM:
        put(a, "Lobby", 0, 0, 0, 0, kind="Block", name=a.replace("Lobby_", ""))
    for n, x, y, yaw in CP.BLOCKS:
        put("Lobby_Block" + n, "Lobby", x, y, 0, yaw, kind="Block", name=n)
    for kind, x, y, z, yaw, paint in CP.cars():
        put("Town_" + kind, "Town", x, y, z, yaw, kind="Car", paint=paint)
    for x, y, z, yaw, sc in CP.bunting():
        put("Town_Bunting", "Town", x, y, z, yaw, sc, kind="Bunting")
    for a, x, y, z, yaw, sc in CP.far():
        put("Town_" + a, "Town", x, y, z, yaw, sc, kind="Tree" if a.startswith("Tree") else ("Tower" if a == "WaterTower" else "Still"))
    for a, x, y, z, yaw, sc in CP.hill_trees():
        put("Town_" + a, "Town", x, y, z, yaw, sc, kind="Tree")
    put("Cutscene_Hill", "Cutscene", 0, 0, 0, 0, name="MineHill")
    put("Cutscene_BlastDoor", "Cutscene", *DOOR_AT, DOOR_YAW, name="Door")
    return out


def exported(asset: str, category: str) -> bool:
    return os.path.exists(os.path.join(sf.REPO, "exports", category, asset + ".fbx"))


def flat(hexcolor: str, emission: float = 0.0, roughness: float = 0.8):
    return sf._flat_material(hexcolor, roughness=roughness, emission=emission)


def prim(kind: str, name: str, loc, scale=(1, 1, 1), hexcolor="#888888", emission=0.0, rot=(0, 0, 0), **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("detail", 2), radius=1.0, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 16), radius=1.0, depth=1.0, location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=kw.get("minor", 0.03), major_segments=48, minor_segments=6, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    o.data.materials.append(flat(hexcolor, emission))
    return o


class Scene:
    """The set and the stand-ins, and how they stand at a moment of the cutscene."""

    def __init__(self):
        SL.reset()
        self.groups: dict[str, list] = {}
        self.blocks = []            # (objects, centre x, centre y, rest matrices)
        for p in placements():
            if not exported(p["Asset"], p["Category"]):
                print("  (not exported yet:", p["Asset"] + ")")
                continue
            objs = SL.place(p["Asset"], p["Category"], p["P"], p["Yaw"], p["Scale"], paint=sf.swatch(p["Paint"])["hex"] if p["Paint"] else None, name=p["Name"])
            self.groups.setdefault(p["Name"], []).append(objs)
            if p["Kind"] in ("Block", "Car", "Tree", "Bunting", "Tower"):
                lo, hi = sf.bbox_world(objs)
                self.blocks.append((objs, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, [o.matrix_world.copy() for o in objs], p["Kind"]))
        for g in CP.ground():
            SL.slab(*g)
        # the door's moving parts
        self.door = []
        if "Door" in self.groups:
            doc, _ = SL.load("Cutscene_BlastDoor", "Cutscene")
            travel = doc["meta"]["leafTravel"]
            for o in self.groups["Door"][0]:
                side = -1 if o["cs_part"] == "LeafLeft" else (1 if o["cs_part"] in ("LeafRight", "Wheel") else 0)
                if side:
                    # the door's X runs along the wall: with its yaw of -90 that is the set's -Y
                    self.door.append((o, o.matrix_world.copy(), Vector((0, -side * travel, 0))))
        # runners: stand-ins five studs tall, the party in orange, the founders in Steadfast teal
        self.runners = []
        for i, (delay, side) in enumerate(CP.RUNNERS):
            col = "#E8743B" if i < 6 else "#2F6F73"
            body = prim("cube", f"Runner{i}", (0, 0, 0), (1.9, 1.1, 3.6), col)
            head = prim("sphere", f"RunnerHead{i}", (0, 0, 0), (0.75, 0.75, 0.75), "#E8C8A8")
            self.runners.append((body, head, delay, side))
        # the bomb, its trail, the fireball, the cloud, the ring
        self.bomb = prim("cyl", "Bomb", (0, 0, 0), (1.6, 1.6, 7.0), "#4A5259")
        self.trail = prim("cyl", "Trail", (0, 0, 0), (0.5, 0.5, 1.0), "#F7F5EE", emission=1.5, verts=6)
        bx, by, _ = CP.BLAST
        self.fireball = prim("sphere", "Fireball", (bx, by, 30), (1, 1, 1), "#F2C14E", emission=12.0, detail=3)
        self.stem = prim("cyl", "Stem", (bx, by, 0), (1, 1, 1), "#C8AE90", verts=14)
        self.cap = prim("sphere", "Cap", (bx, by, 0), (1, 1, 1), "#D8BEA0", detail=3)
        self.skirt = prim("torus", "Skirt", (bx, by, 0), (1, 1, 1), "#B89878", minor=0.22)
        self.ring = prim("torus", "Ring", (bx, by, 3.0), (1, 1, 1), "#E8D8C0", emission=1.2, minor=0.02)
        self.sun = SL.sun(52, 250)
        SL.sky()
        self.bunker()
        self.cam = SL.camera()
        self.curves = key_camera()

    # .. the bunker's space: stand-ins for the run's real bunker and the two pieces that dress it ..
    def bunker(self):
        px, py = CP.GRID_PITCH
        band = {1: "#6F665C", 2: "#6F665C", 3: "#6F665C", 4: "#2D4A57", 5: "#2D4A57", 6: "#2D4A57", 7: "#6E4766", 8: "#6E4766", 9: "#6E4766", 10: "#7A2A1E"}
        rooms = {(1, -2), (1, -1), (1, 0), (1, 1), (1, 2), (1, 3), (2, -2), (2, -1), (2, 0), (2, 1), (2, 2), (2, 3)}
        for f in range(0, 12):
            for c in range(-7, 8):
                y0 = -(f - 1) * py
                edge = f in (0, 11) or abs(c) == 7
                if (f, c) in rooms:
                    prim("cube", "Room", G(c * px, y0 + 8.0, -17.0), (32.0, 1.0, 16.0), "#F2E6C9", emission=0.6)
                    prim("cube", "Dado", G(c * px, y0 + 2.0, -16.4), (32.0, 0.5, 4.0), "#2F6F73")
                else:
                    prim("cube", "Rock", G(c * px, y0 + 8.0, 15.5), (33.6, 1.0, 17.6), "#403B37" if edge else band.get(f, "#403B37"))
        # the rock above (Cutscene_Strata) and the Source's hollow (Cutscene_SourceGlimpse): stand-ins until they are made
        if not exported("Cutscene_Strata", "Cutscene"):
            n = 7
            cols = ("#5E6A44", "#6B4630", "#8C5B3B", "#6F665C", "#A39A8C", "#6F665C", "#403B37")
            h = (CP.STRATA["Top"] - CP.STRATA["Bottom"]) / n
            for i in range(n):
                prim("cube", "Strata", G(0.0, CP.STRATA["Top"] - h * (i + 0.5), 16.0), (CP.STRATA["HalfWidth"] * 2, 1.0, h), cols[i])
        else:
            SL.place("Cutscene_Strata", "Cutscene", G(0.0, CP.STRATA["Bottom"], ROCK_FACE + 0.2), 180.0, name="Strata")
        if not exported("Cutscene_SourceGlimpse", "Cutscene"):
            prim("cube", "Hollow", G(SOURCE_X, SOURCE_Y, 17.0), (150.0, 1.0, 60.0), "#16100E")
            self.eye = prim("sphere", "Eye", G(SOURCE_X, SOURCE_Y, 19.0), (9.0, 1.0, 4.5), "#7CFF9B", emission=6.0)
        else:
            SL.place("Cutscene_SourceGlimpse", "Cutscene", G(SOURCE_X, SOURCE_Y, ROCK_FACE + 0.4), 180.0, name="Source")
            self.eye = None

    def at(self, t: float):
        """Stand everything as it is t seconds in; returns the frame's overlays (white, dust, black)."""
        ease = lambda x: max(0.0, min(1.0, x)) ** 2 * (3 - 2 * max(0.0, min(1.0, x)))  # noqa: E731
        # the door
        shut = ease((t - B["DoorFrom"]) / (B["DoorTo"] - B["DoorFrom"]))
        for o, rest, slide in self.door:
            o.matrix_world = Matrix.Translation(slide * (1 - shut)) @ rest
        # the runners
        path = CP.run_path()
        length = CP.path_length(path)
        for body, head, delay, side in self.runners:
            s = max(0.0, (t - CP.RUN_START - delay) * CP.RUN_SPEED)
            (x, y, z), d = CP.path_at(min(s, length), path)
            spread = 1.0 + 1.6 * max(0.0, 1.0 - s / 60.0)             # they start scattered and close up
            gone = s >= length - 1.0
            yaw = math.atan2(d[1], d[0])
            for o, dz in ((body, 2.3), (head, 4.75)):
                o.location = (x - math.sin(yaw) * side * spread, y + math.cos(yaw) * side * spread, z + dz)
                o.rotation_euler = (0, 0, yaw + math.pi / 2)
                o.hide_render = gone
        # the bomb
        u = (t - B["BombFrom"]) / (B["BombTo"] - B["BombFrom"])
        a, b = Vector(CP.BOMB_FROM), Vector(CP.BOMB_TO)
        flying = 0.0 <= u < 1.0
        self.bomb.hide_render = self.trail.hide_render = not flying
        if flying:
            p = a.lerp(b, u)
            d = (b - a).normalized()
            q = d.to_track_quat("Z", "Y")
            self.bomb.location = p
            self.bomb.rotation_euler = q.to_euler()
            tail = min(150.0, (p - a).length)
            self.trail.location = p - d * (tail / 2 + 3.5)
            self.trail.rotation_euler = q.to_euler()
            self.trail.scale = (0.45, 0.45, tail)
        # the blast
        after = t >= B["Flash"]
        bx, by, _ = CP.BLAST
        fb = ease((t - B["FireballFrom"]) / 1.2) if after else 0.0
        dim = 1.0 - ease((t - B["FireballTo"] + 0.8) / 1.6)
        self.fireball.hide_render = not after or dim <= 0.02
        self.fireball.scale = (60 * fb * (0.5 + 0.5 * dim),) * 3
        self.fireball.location = (bx, by, 26 + 30 * fb)
        c = ease((t - B["CloudFrom"]) / (B["CloudTo"] - B["CloudFrom"])) if after else 0.0
        for o in (self.stem, self.cap, self.skirt):
            o.hide_render = c <= 0.0
        top = CP.CLOUD["Top"] * (0.25 + 0.75 * c)
        capr = CP.CLOUD["CapRadius"] * (0.4 + 0.6 * c)
        self.stem.scale = (CP.CLOUD["StemRadius"] * (0.8 + 0.3 * c), CP.CLOUD["StemRadius"] * (0.8 + 0.3 * c), top * 0.8)
        self.stem.location = (bx, by, top * 0.4)
        self.cap.scale = (capr, capr, capr * 0.5)
        self.cap.location = (bx, by, top - capr * 0.3)
        self.skirt.scale = (capr * 0.8, capr * 0.8, capr * 0.8)
        self.skirt.location = (bx, by, top - capr * 0.62)
        w = (t - B["WaveFrom"]) / (B["WaveTo"] - B["WaveFrom"])
        reach = CP.WAVE_REACH * max(0.0, w)
        self.ring.hide_render = not (0.0 < w < 1.0)
        self.ring.scale = (max(reach, 1.0), max(reach, 1.0), max(reach, 1.0))
        for objs, cx, cy, rests, kind in self.blocks:
            hit = after and math.hypot(cx - bx, cy - by) < reach
            for o, rest in zip(objs, rests):
                if hit and kind in ("Block", "Tower", "Tree", "Car"):
                    away = Vector((cx - bx, cy - by, 0)).normalized()
                    tilt = Matrix.Rotation(math.radians(24 if kind == "Block" else 80), 4, away.cross(Vector((0, 0, 1))))
                    pivot = Matrix.Translation((cx, cy, 0))
                    squash = Matrix.Diagonal((1, 1, 0.38 if kind == "Block" else 1.0, 1))
                    o.matrix_world = pivot @ tilt.inverted() @ squash @ pivot.inverted() @ rest
                else:
                    o.matrix_world = rest
                o.hide_render = hit and kind == "Bunting"
        # the light: a sunny morning, then the blast's
        world = bpy.context.scene.world.node_tree
        if after:
            heat = 1.0 - ease((t - B["Flash"]) / 2.5)
            self.sun.data.energy = 1.2
            self.sun.data.color = (1.0, 0.55, 0.3)
            world.nodes["Background"].inputs[0].default_value = (0.9, 0.42 + 0.3 * heat, 0.2 + 0.4 * heat, 1)
            world.nodes["Background"].inputs[1].default_value = 0.7 + 1.8 * heat
            world.nodes["SF_CamBG"].inputs[0].default_value = (0.55 + 0.4 * heat, 0.3 + 0.5 * heat, 0.16 + 0.6 * heat, 1)
        else:
            self.sun.data.energy = 3.4
            self.sun.data.color = (1.0, 0.96, 0.88)
            world.nodes["Background"].inputs[0].default_value = (0.42, 0.60, 0.92, 1)
            world.nodes["Background"].inputs[1].default_value = 0.95
            world.nodes["SF_CamBG"].inputs[0].default_value = (0.36, 0.58, 0.92, 1)
        if t >= B["DiveTo"]:                          # the bunker's space: its own dark
            self.sun.data.energy = 0.0
            world.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.56, 1)
            world.nodes["Background"].inputs[1].default_value = 0.9
            world.nodes["SF_CamBG"].inputs[0].default_value = (0.01, 0.01, 0.012, 1)
        if self.eye is not None:
            op = ease((t - B["EyesFrom"]) / (B["EyesTo"] - B["EyesFrom"]))
            self.eye.scale = (9.0, 1.0, 0.2 + 4.3 * op)
            self.eye.hide_render = t < B["PlungeTo"] - 0.4
        # the camera
        at, rot, fov, shot = pose_at(self.curves, t)
        m = rot.to_4x4()
        m.translation = at
        self.cam.matrix_world = m
        self.cam.data.lens = self.cam.data.sensor_height / (2 * math.tan(math.radians(fov) / 2))
        self.cam.data.clip_end = 9000
        white = 1.0 if B["Flash"] <= t < B["Flash"] + 0.25 else max(0.0, 1.0 - (t - B["Flash"] - 0.25) / 1.1) if t >= B["Flash"] else max(0.0, (t - B["Flash"] + 0.12) / 0.12)
        d = (t - B["DustFrom"]) / (B["DustTo"] - B["DustFrom"])
        dust = 0.0 if d < 0 or d > 1 else math.sin(d * math.pi) ** 0.6 * 0.86
        black = max(0.0, 1.0 - t / 0.9) if t < 0.9 else (1.0 - min(1.0, (t - B["Title"]) / 1.0) if B["Title"] <= t < B["Title"] + 1.0 else 0.0)
        return shot, white, dust, black


# -- storyboard -------------------------------------------------------------------------------------------

def frame_image(scene: Scene, t: float, res, samples: int):
    from PIL import Image, ImageDraw, ImageFont
    shot, white, dust, black = scene.at(t)
    path = SL.render(f"/tmp/cs/frame_{t:05.2f}.png", res=res, samples=samples)
    im = Image.open(path).convert("RGB")
    w, h = im.size
    for colour, alpha in (((246, 240, 226), white), ((150, 112, 78), dust), ((0, 0, 0), black)):
        if alpha > 0.01:
            im = Image.blend(im, Image.new("RGB", im.size, colour), min(1.0, alpha))
    d = ImageDraw.Draw(im)
    bar = int(h * 0.105)
    d.rectangle([0, 0, w, bar], fill=(0, 0, 0))
    d.rectangle([0, h - bar, w, h], fill=(0, 0, 0))
    font_path = os.path.join(HERE, "..", "Town", "fonts", "Oswald-Bold.ttf")
    font = ImageFont.truetype(font_path, max(12, int(h * 0.055)))
    d.text((int(w * 0.015), int(bar * 0.16)), f"{t:4.1f} s   {shot['Name']}", fill=(242, 230, 201), font=font)
    if t >= B["Title"]:
        big = ImageFont.truetype(os.path.join(HERE, "..", "Town", "fonts", "AlfaSlabOne-Regular.ttf"), int(h * 0.15))
        d.text((w / 2, h * 0.44), "100 YEARS BELOW", fill=(242, 230, 201), font=big, anchor="mm")
        small = ImageFont.truetype(os.path.join(HERE, "..", "Town", "fonts", "SpecialElite-Regular.ttf"), int(h * 0.05))
        d.text((w / 2, h * 0.6), "Survive. Dig. Don't wake it.", fill=(242, 230, 201), font=small, anchor="mm")
    return im


def storyboard(scene: Scene):
    from PIL import Image
    only = os.environ.get("SF_AT")
    if only:
        for t in (float(x) for x in only.split(",")):
            im = frame_image(scene, t, (1280, 720), 20)
            out = f"/tmp/cs/at_{t:05.2f}.png"
            im.save(out)
            print("wrote", out)
        return
    res = (640, 360)
    cols = 4
    rows = (len(STORYBOARD) + cols - 1) // cols
    sheet = Image.new("RGB", (res[0] * cols, res[1] * rows), (12, 14, 18))
    for i, t in enumerate(STORYBOARD):
        sheet.paste(frame_image(scene, t, res, 10), ((i % cols) * res[0], (i // cols) * res[1]))
        print(f"  {t:5.2f} s done", flush=True)
    out = os.path.join(sf.REPO, "previews", "Cutscene", "Storyboard.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print("wrote", out)


# -- the data module -----------------------------------------------------------------------------------------

def num(v: float) -> str:
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v) -> str:
    return "{ " + ", ".join(num(x) for x in v) + " }"


def game_point(p) -> tuple[float, float, float]:
    """A point of the set in the game's axes, from the set's origin."""
    return (-p[0], p[2], p[1])


def data(curves) -> str:
    """cutscene/IntroPath.luau: the camera's keys, the set and what happens when."""
    L = []
    L.append("\t\t\tShots = {")
    total = 0
    for shot in SHOTS:
        # a whole number of keys from the shot's first instant to its last: at least RATE a second
        n = int(math.ceil((shot["To"] - shot["From"]) * RATE - 1e-6))
        rate = n / (shot["To"] - shot["From"])
        keys = []
        for i in range(n + 1):
            t = shot["From"] + i / rate
            at, rot, fov, _ = pose_at(curves, min(t, shot["To"] - 1e-4) if i == n else t)
            p, q = to_game(at, rot, shot["Space"])
            keys.append("{ " + ", ".join(num(x) for x in (*p, *q)) + f", {num(fov)} }}")
        total += len(keys)
        L.append(f"\t\t\t\t{{ Name = \"{shot['Name']}\", From = {num(shot['From'])}, To = {num(shot['To'])}, Space = \"{shot['Space']}\", Rate = {f'{rate:.6f}'.rstrip('0').rstrip('.')},"
                 f" Handover = {'true' if shot.get('Handover') else 'false'},")
        L.append(f"\t\t\t\t\tText = \"{shot['Text']}\",")
        L.append("\t\t\t\t\tKeys = {")
        for j in range(0, len(keys), 3):
            L.append("\t\t\t\t\t\t" + ", ".join(keys[j:j + 3]) + ",")
        L.append("\t\t\t\t\t} },")
    L.append("\t\t\t},")
    L.append("\t\t\tSet = {")
    for p in placements():
        paint = f", Paint = \"{sf.swatch(p['Paint'])['hex']}\"" if p["Paint"] else ""
        L.append(f"\t\t\t\t{{ Name = \"{p['Name']}\", Asset = \"{p['Asset']}\", Category = \"{p['Category']}\", P = {vec(game_point(p['P']))}, Yaw = {num(p['Yaw'])},"
                 f" Scale = {num(p['Scale'])}, Kind = \"{p['Kind']}\"{paint} }},")
    L.append("\t\t\t},")
    L.append("\t\t\tGround = {")
    for name, x0, x1, y0, y1, z0, z1, swatch in CP.ground():
        centre = game_point(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
        size = (abs(x1 - x0), abs(z1 - z0), abs(y1 - y0))
        L.append(f"\t\t\t\t{{ Name = \"{name}\", P = {vec(centre)}, Size = {vec(size)}, Hex = \"{sf.swatch(swatch)['hex']}\" }},")
    L.append("\t\t\t},")
    path = CP.run_path()
    L.append("\t\t\tRunPath = { " + ", ".join(vec(game_point(p)) for p in path) + " },")
    L.append("\t\t\tRunners = { " + ", ".join(f"{{ Delay = {num(d)}, Side = {num(-s)} }}" for d, s in CP.RUNNERS) + " },")
    L.append(f"\t\t\tRunSpeed = {num(CP.RUN_SPEED)},")
    anchors = {
        "Door": game_point(DOOR_AT), "StairFoot": game_point((CP.STAIR_FOOT_X, AX, 0.0)), "StairHead": game_point((CP.STAIR_TOP_X, AX, CP.TERRACE_Z)),
        "Blast": game_point(CP.BLAST), "BombFrom": game_point(CP.BOMB_FROM), "BombTo": game_point(CP.BOMB_TO),
        "StrataFoot": (0.0, CP.STRATA["Bottom"], ROCK_FACE + 0.2), "Source": (SOURCE_X, SOURCE_Y, ROCK_FACE + 0.4),
    }
    L.append("\t\t\tAnchors = {")
    for k, v in anchors.items():
        L.append(f"\t\t\t\t{k} = {vec(v)},")
    L.append("\t\t\t},")
    L.append("\t\t\tBeats = {")
    for k, v in B.items():
        L.append(f"\t\t\t\t{k} = {num(v)},")
    L.append("\t\t\t},")
    L.append(f"\t\t\tWaveReach = {num(CP.WAVE_REACH)},")
    L.append(f"\t\t\tCloud = {{ StemRadius = {num(CP.CLOUD['StemRadius'])}, CapRadius = {num(CP.CLOUD['CapRadius'])}, Top = {num(CP.CLOUD['Top'])} }},")
    body = "\n".join(L)
    src = f'''--!strict
--[[
	CutscenePaths: the intro cutscene as the art side made it (bible Section 4: "Opus animates the
	camera in the same Blender, exports the path as keyframes (time, position, rotation) into a
	Luau data module and commits it to the art repo"). Generated by
	generators/Cutscene/Intro_Scene.py --data from the Blender scene and its plan
	(generators/Cutscene/cutscene_plan.py): don't edit by hand, change those and run it again.
	The art repo's copy is cutscene/IntroPath.luau; tools/cutscene_config.py puts it here.

	* Shots: the camera, shot by shot. Keys are Rate a second ({RATE} or a little more, so that a whole number of them
	  fills the shot) from From to To, each
	  {{ x, y, z, qx, qy, qz, qw, field of view }} in the game's axes from the shot's Space: "Set" is
	  the cutscene's set (its origin is Tuning.Cutscene.SetOrigin), "Bunker" the grid's origin
	  (Rules.Grid.CellPosition(1, 0)). A shot never blends into the next: that is a cut. Handover:
	  the game ends that shot on the player's own character (CutsceneController).
	* Set: what stands on the set, from ServerStorage.Assets.<Category>.<Asset>, at P (studs from
	  the set's origin), turned Yaw degrees about Y. Kind says what the blast does to it; Paint is a
	  car's colour. Ground:
	  the roads, pavements and grass as plain blocks.
	* RunPath, Runners, RunSpeed: the line the party and the founders sprint along and each one's
	  place in the pack (Delay seconds after the first, Side studs to the right of the line).
	* Anchors: named points (Set space, but StrataFoot and Source: Bunker space). Beats: when
	  things happen, in seconds. WaveReach, Cloud: how big the blast gets.
]]

local Check = require(script.Parent.Parent.Utilities.Check)
local F = require(script.Parent._Fields)

local Vec = Check.array(Check.number(), 3)
local Key = Check.array(Check.number(), 8)

return {{
	Schema = Check.shape({{
		Seconds = F.Seconds,
		Shots = Check.array(Check.shape({{
			Name = F.Name, From = F.Seconds, To = F.Seconds, Space = Check.enum({{ "Set", "Bunker" }}), Rate = Check.number({{ min = 1 }}),
			Handover = Check.boolean(), Text = F.Short, Keys = Check.array(Key, 200),
		}}), 16),
		Set = Check.array(Check.shape({{
			Name = F.Name, Asset = Check.string(64), Category = Check.string(32), P = Vec, Yaw = F.Number, Scale = F.Number,
			Kind = Check.enum({{ "Still", "Block", "Car", "Tree", "Bunting", "Tower" }}), Paint = Check.optional(F.Hex),
		}}), 240),
		Ground = Check.array(Check.shape({{ Name = F.Name, P = Vec, Size = Vec, Hex = F.Hex }}), 120),
		RunPath = Check.array(Vec, 40),
		Runners = Check.array(Check.shape({{ Delay = F.Seconds, Side = F.Number }}), 12),
		RunSpeed = F.Number,
		Anchors = Check.map(Check.string(24), Vec, 24),
		Beats = Check.map(Check.string(24), F.Seconds, 48),
		WaveReach = F.Number,
		Cloud = Check.shape({{ StemRadius = F.Number, CapRadius = F.Number, Top = F.Number }}),
	}}),
	Entries = {{
		Intro = {{
			Seconds = {num(CP.SECONDS)},
{body}
		}},
	}},
}}
'''
    return src, total


def main():
    scene = Scene()
    if "--data" in sys.argv:
        src, total = data(scene.curves)
        out = os.path.join(sf.REPO, "cutscene", "IntroPath.luau")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w") as f:
            f.write(src)
        print(f"wrote {out}: {len(SHOTS)} shots, {total} keys, {len(placements())} placements, {len(src) // 1024} KB")
        return
    storyboard(scene)


if __name__ == "__main__":
    main()
