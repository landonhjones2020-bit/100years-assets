"""R15_LongGuns: the players' clips for A2's two-handed weapons and throwables (bible Sections 9
and 19; Prompt 20), on the standard R15 skeleton like R15_PlayerCombat.

Both hands are on the weapon here, so the poses are solved, not typed in: a pose names where the
right hand's grip is and which way the weapon points; the right arm is solved to hold it there
(position and direction) and the left arm to reach the weapon's Support socket (_gunkit.SUPPORT:
one stud ahead of the grip and 0.2 up on every long gun; 0.6 behind the grip on the two-handed
melee weapons). The solver is a damped least-squares fit over the arm's Euler angles with the
skeleton's forward kinematics in plain maths (checked against Blender's own pose evaluation).

A classic R15 arm is short for its shoulders (about 1.9 studs from shoulder to palm, shoulders 2
apart), so both hands only meet on a gun with the torso bladed: the upper torso turns right and
the head turns back to the front.

Clips (Config.Animations activities; CombatController plays them by the held item's Hold):
  RifleHold    loop, Action:  both hands, the gun level in front of the right hip
  RifleAim     loop, Action:  shouldered in a bladed stance, the gun level at chest height
  RifleReload  Action2:       the gun stays at the hip; the left hand works the action
  HeavySwing1  Action3:       two-handed chop from the right shoulder down to the left
  HeavySwing2  Action3:       two-handed sweep back from the left to the right
  Throw        Action3:       an overhand throw (the release at 40%)

Run:  SF_EXPORT=1 python3 generators/Clips/R15_LongGuns.py      (SF_NORENDER=1: no sheets)
      SF_GUN=Weapon_PumpShotgun: the gun shown in the sheets (default Weapon_LeverRifle)
"""
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Residents"))
sys.path.insert(0, os.path.join(HERE, "..", "Weapons"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402
import Resident_Common as rc  # noqa: E402
import _gunkit as G  # noqa: E402
import R15_PlayerCombat as pc  # noqa: E402

keys, action, sheet = pc.keys, pc.action, pc.sheet

# The hand: RightGripAttachment sits 0.15 under the hand part's centre, 0.275 under the wrist.
# A held model's axes are the hand bone's: front = -Y (down the fingers), top = +Z, and the
# model's grip lies on this point.
PALM = Vector((0.0, -0.275, 0.0))
# bone-local axes in armature space (make_rig: X = left, Y = up, Z = forward)
B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
CHAINS = {
    "R": ["LowerTorso", "UpperTorso", "RightUpperArm", "RightLowerArm", "RightHand"],
    "L": ["LowerTorso", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand"],
}
FORWARD, UP = Vector((0, -1, 0)), Vector((0, 0, 1))


def rb(x, y, z):
    """A point given as Roblox studs from the HumanoidRootPart (x right, y up, z back) in Blender space."""
    return Vector((-x, z, y + 3.0))


def _local(pose, bone):
    value = pose.get(bone, (0.0, 0.0, 0.0))
    rot, loc = (value[0], value[1]) if isinstance(value[0], (tuple, list)) else (value, (0.0, 0.0, 0.0))
    m = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    m.translation = Vector(loc)
    return m


def hand(arm, pose, side):
    """(palm point, forward, up) of a hand in armature space for a pose {bone: euler or (euler, loc)}."""
    chain = CHAINS[side]
    heads = [arm.data.bones[b].head_local for b in chain]
    m = Matrix.Translation(heads[0]) @ B.to_4x4() @ _local(pose, chain[0])
    for i in range(1, len(chain)):
        offset = B.inverted() @ (heads[i] - heads[i - 1])
        m = m @ Matrix.Translation(offset) @ _local(pose, chain[i])
    r = m.to_3x3()
    return m @ PALM, -(r @ Vector((0, 1, 0))), r @ Vector((0, 0, 1))


def check_fk(arm):
    """The plain-maths skeleton must agree with Blender's (or every solved pose is wrong)."""
    pose = {"UpperTorso": (4, -30, 2), "RightUpperArm": (-70, 20, -15), "RightLowerArm": (-50, 0, 0),
            "RightHand": (10, 20, -30), "LowerTorso": ((5, 0, 0), (0, -0.2, 0))}
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for bone, value in pose.items():
        rot, loc = (value[0], value[1]) if isinstance(value[0], (tuple, list)) else (value, None)
        pb = arm.pose.bones[bone]
        pb.rotation_quaternion = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_quaternion()
        if loc is not None:
            pb.location = Vector(loc)
    bpy.context.view_layer.update()
    theirs = arm.pose.bones["RightHand"].matrix @ PALM
    mine, _f, _u = hand(arm, pose, "R")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    error = (theirs - mine).length
    assert error < 1e-4, f"the solver's skeleton is off Blender's by {error:.5f} studs"
    return error


def fit(residual, x0, iterations=80):
    """Damped least squares (Levenberg-Marquardt) with a numeric Jacobian. x in degrees."""
    x = np.array(x0, dtype=float)
    lam = 1e-2
    r = residual(x)
    cost = float(r @ r)
    for _ in range(iterations):
        jac = np.zeros((len(r), len(x)))
        for i in range(len(x)):
            step = np.zeros(len(x))
            step[i] = 0.5
            jac[:, i] = (residual(x + step) - r) / 0.5
        a = jac.T @ jac
        g = jac.T @ r
        improved = False
        for _try in range(8):
            try:
                dx = np.linalg.solve(a + lam * np.eye(len(x)), -g)
            except np.linalg.LinAlgError:
                lam *= 10
                continue
            r2 = residual(x + dx)
            cost2 = float(r2 @ r2)
            if cost2 < cost:
                x, r, cost, lam, improved = x + dx, r2, cost2, max(lam / 3, 1e-6), True
                break
            lam *= 4
        if not improved or cost < 1e-10:
            break
    return x


def hold(arm, base, grip, forward=FORWARD, up=UP, support=(0.0, -1.0, 0.2), guess_r=None, guess_l=None,
         up_weight=1.0, name=""):
    """base (torso, head...) plus both arms solved onto a weapon: the right palm at `grip` with the
    weapon pointing `forward` and its top toward `up`; the left palm at the weapon's support point
    (given in the weapon's own axes: x left, y back, z up)."""
    f = Vector(forward).normalized()
    u = Vector(up)
    u = (u - f * u.dot(f)).normalized()
    left = u.cross(f)                               # the weapon's left side: f = -y, u = z
    gr = guess_r or {"RightUpperArm": (-55, 15, -15), "RightLowerArm": (-60, 0, 0), "RightHand": (0, 0, 0)}
    gl = guess_l or {"LeftUpperArm": (-70, -40, 0), "LeftLowerArm": (-30, 0, 0), "LeftHand": (0, 0, 0)}
    x0 = list(gr["RightUpperArm"]) + [gr["RightLowerArm"][0]] + list(gr["RightHand"])

    def pose_r(x):
        p = dict(base)
        p["RightUpperArm"], p["RightLowerArm"], p["RightHand"] = tuple(x[0:3]), (x[3], 0.0, 0.0), tuple(x[4:7])
        return p

    def res_r(x):
        at, fw, upv = hand(arm, pose_r(x), "R")
        soft = (np.array(x) - np.array(x0)) * 2e-4
        return np.concatenate([np.array(at - Vector(grip)) * 4.0, np.array(fw - f), np.array(upv - u) * up_weight, soft])

    xr = fit(res_r, x0)
    out = pose_r(xr)
    at, fw, upv = hand(arm, out, "R")
    target = at + left * support[0] - f * support[1] + u * support[2]
    y0 = list(gl["LeftUpperArm"]) + [gl["LeftLowerArm"][0]]

    def pose_l(y):
        p = dict(out)
        p["LeftUpperArm"], p["LeftLowerArm"], p["LeftHand"] = tuple(y[0:3]), (y[3], 0.0, 0.0), gl["LeftHand"]
        return p

    def res_l(y):
        la, _f, _u = hand(arm, pose_l(y), "L")
        soft = (np.array(y) - np.array(y0)) * 2e-4
        return np.concatenate([np.array(la - target) * 4.0, soft])

    yl = fit(res_l, y0)
    out = pose_l(yl)
    la, _f, _u = hand(arm, out, "L")
    miss_r = (at - Vector(grip)).length
    miss_l = (la - target).length
    angle = math.degrees(math.acos(max(-1.0, min(1.0, fw.dot(f)))))
    roll = math.degrees(math.acos(max(-1.0, min(1.0, upv.dot(u)))))
    print(f"[R15_LongGuns] {name}: right hand {miss_r:.3f} off, barrel {angle:.2f} deg off, roll {roll:.2f}; "
          f"left hand {miss_l:.3f} off; elbows {xr[3]:.0f} / {yl[3]:.0f}")
    for bone in ("RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand"):
        out[bone] = tuple(round(float(a), 2) for a in out[bone])
    out["_miss"] = max(miss_r, miss_l)
    return out


def clean(pose):
    return {k: v for k, v in pose.items() if not k.startswith("_")}


# Poses -----------------------------------------------------------------------------------------------

HIP_BASE = {"UpperTorso": (0, -38, 0), "Head": (0, 38, 0)}
AIM_BASE = {"UpperTorso": (0, -44, 0), "Head": (4, 44, 0)}
HIP_GRIP = rb(0.45, -0.28, -0.52)      # in front of the right hip
AIM_GRIP = rb(0.42, 0.5, -0.82)        # in front of the right chest


def rifle_hold(arm):
    p = clean(hold(arm, HIP_BASE, HIP_GRIP, name="RifleHold",
                   guess_r={"RightUpperArm": (-10, 10, -25), "RightLowerArm": (-75, 0, 0), "RightHand": (0, 0, 0)},
                   guess_l={"LeftUpperArm": (-55, -45, 0), "LeftLowerArm": (-35, 0, 0), "LeftHand": (0, 0, 0)}))
    breathe = clean(hold(arm, {"UpperTorso": (1.2, -38, 0), "Head": (-1.2, 38, 0)}, HIP_GRIP + Vector((0, 0, 0.03)),
                         name="RifleHold breath", guess_r=p, guess_l=p))
    act = action(arm, "RifleHold", 36, True, "Action")
    keys(arm, 0, p)
    keys(arm, 18, breathe)
    keys(arm, 36, p)
    return act, p


def rifle_aim(arm):
    p = clean(hold(arm, AIM_BASE, AIM_GRIP, name="RifleAim",
                   guess_r={"RightUpperArm": (-50, 20, -30), "RightLowerArm": (-85, 0, 0), "RightHand": (0, 0, 0)},
                   guess_l={"LeftUpperArm": (-80, -40, 0), "LeftLowerArm": (-25, 0, 0), "LeftHand": (0, 0, 0)}))
    breathe = clean(hold(arm, {"UpperTorso": (0.8, -44, 0), "Head": (3.2, 44, 0)}, AIM_GRIP + Vector((0, 0, 0.02)),
                         name="RifleAim breath", guess_r=p, guess_l=p))
    act = action(arm, "RifleAim", 40, True, "Action")
    keys(arm, 0, p)
    keys(arm, 20, breathe)
    keys(arm, 40, p)
    return act, p


def rifle_reload(arm, hip):
    """The gun stays at the hip; the left hand leaves the forend, works the action at the receiver
    (back and forward) and returns. Sped to the gun's ReloadSeconds."""
    act = action(arm, "RifleReload", 40, False, "Action2")   # 1.33 s at 30 fps
    base = {"UpperTorso": (5, -38, 0), "Head": (12, 30, 0)}  # looking down at the gun

    def at(support, label):
        return clean(hold(arm, base, HIP_GRIP + Vector((0, 0, 0.06)), forward=(0.0, -1.0, 0.14), support=support,
                          name=f"RifleReload {label}", guess_r=hip, guess_l=hip))

    forend = at((0.0, -1.0, 0.2), "forend")
    receiver = at((0.16, -0.5, 0.42), "receiver")
    pulled = at((0.16, -0.18, 0.42), "pulled")
    keys(arm, 0, hip)
    keys(arm, 6, forend)
    keys(arm, 13, receiver)
    keys(arm, 18, pulled, ease="QUAD", direction="EASE_IN")
    keys(arm, 23, receiver, ease="QUAD", direction="EASE_OUT")
    keys(arm, 27, receiver)
    keys(arm, 34, forend)
    keys(arm, 40, hip)
    return act


def heavy_swings(arm):
    """Two-handed swings for the Fire Axe and the Sledgehammer: the right hand at the grip, the left
    0.6 behind it toward the end of the handle. The weapon's top (+Z) trails the swing, so its
    edge (-Z) leads."""
    support = (0.0, 0.6, 0.0)

    def pose(label, torso, grip, forward, lead, lower=None, guess=None):
        base = {"UpperTorso": torso, "Head": (0, -torso[1] * 0.6, 0)}
        if lower:
            base["LowerTorso"] = lower
        p = hold(arm, base, grip, forward=forward, up=-Vector(lead), support=support, up_weight=0.35,
                 name=f"HeavySwing {label}",
                 guess_r=guess or {"RightUpperArm": (-90, 10, -10), "RightLowerArm": (-50, 0, 0), "RightHand": (0, 0, 0)},
                 guess_l=guess or {"LeftUpperArm": (-80, -30, 0), "LeftLowerArm": (-60, 0, 0), "LeftHand": (0, 0, 0)})
        return clean(p)

    ready = pose("ready", (4, -14, 0), rb(0.2, -0.25, -0.72), (0.25, -0.8, 0.55), (0, -0.5, -1))
    # 1: from over the right shoulder down across to the left
    w1 = pose("1 wind", (-8, -34, 0), rb(0.85, 1.35, -0.1), (-0.25, 0.55, 0.8), (0.4, -1, -0.3),
              guess={"RightUpperArm": (-150, 0, -20), "RightLowerArm": (-80, 0, 0), "RightHand": (0, 0, 0),
                     "LeftUpperArm": (-120, -60, 0), "LeftLowerArm": (-70, 0, 0), "LeftHand": (0, 0, 0)})
    i1 = pose("1 impact", (16, 22, 0), rb(-0.1, 0.25, -1.25), (0.35, -0.85, -0.4), (0.3, -0.3, -1),
              lower=((0, 0, 0), (0, -0.2, 0)), guess=ready)
    f1 = pose("1 follow", (22, 40, 0), rb(-0.75, -0.3, -0.8), (0.75, -0.35, -0.55), (0.6, 0.2, -0.8),
              lower=((0, 0, 0), (0, -0.3, 0)), guess=i1)
    s1 = action(arm, "HeavySwing1", 14, False, "Action3")
    keys(arm, 0, w1, ease="QUAD", direction="EASE_IN")
    keys(arm, 6, i1, ease="QUAD", direction="EASE_OUT")
    keys(arm, 10, f1)
    keys(arm, 14, {**ready, "LowerTorso": ((0, 0, 0), (0, 0, 0))})
    # 2: back from the left hip, level, out to the right
    w2 = pose("2 wind", (10, 42, 0), rb(-0.8, -0.2, -0.55), (0.75, 0.35, 0.35), (-1, -0.4, 0),
              lower=((0, 0, 0), (0, -0.15, 0)), guess=f1)
    i2 = pose("2 impact", (8, -12, 0), rb(0.15, 0.1, -1.3), (-0.4, -0.9, 0.05), (-1, 0.2, 0),
              lower=((0, 0, 0), (0, -0.15, 0)), guess=ready)
    f2 = pose("2 follow", (4, -40, 0), rb(0.95, 0.3, -0.7), (-0.85, -0.2, 0.3), (-0.6, 0.8, 0), guess=i2)
    s2 = action(arm, "HeavySwing2", 14, False, "Action3")
    keys(arm, 0, w2, ease="QUAD", direction="EASE_IN")
    keys(arm, 6, i2, ease="QUAD", direction="EASE_OUT")
    keys(arm, 10, f2)
    keys(arm, 14, {**ready, "LowerTorso": ((0, 0, 0), (0, 0, 0))})
    return [s1, s2]


def throw(arm):
    """An overhand throw with the right arm: wound back at 0, the release at 40%."""
    act = action(arm, "Throw", 12, False, "Action3")
    keys(arm, 0, {"RightUpperArm": (-155, -28, -24), "RightLowerArm": (-95, 0, 0), "RightHand": (-20, 0, 0),
                  "LeftUpperArm": (-50, -10, 10), "LeftLowerArm": (-30, 0, 0), "UpperTorso": (-10, -28, 0),
                  "Head": (4, 22, 0)}, ease="QUAD", direction="EASE_IN")
    keys(arm, 5, {"RightUpperArm": (-112, 6, -6), "RightLowerArm": (-12, 0, 0), "RightHand": (25, 0, 0),
                  "LeftUpperArm": (-20, 0, 8), "LeftLowerArm": (-45, 0, 0), "UpperTorso": (12, 16, 0),
                  "Head": (-6, -12, 0)}, ease="QUAD", direction="EASE_OUT")
    keys(arm, 8, {"RightUpperArm": (-48, 28, 0), "RightLowerArm": (-14, 0, 0), "RightHand": (30, 0, 0),
                  "LeftUpperArm": (-6, 0, 8), "LeftLowerArm": (-40, 0, 0), "UpperTorso": (18, 26, 0),
                  "Head": (-10, -20, 0)})
    keys(arm, 12, {"RightUpperArm": (-18, 6, -4), "RightLowerArm": (-24, 0, 0), "RightHand": (0, 0, 0),
                   "LeftUpperArm": (0, 0, 6), "LeftLowerArm": (-12, 0, 0), "UpperTorso": (3, 5, 0),
                   "Head": (0, -4, 0)})
    return act


# Preview: the weapon in the right hand -----------------------------------------------------------------

def in_hand(arm, module_name):
    """Build a weapon and bind it to the right hand (rest pose: front down the fingers, top
    forward), so the sheets show it where the game's GripWeld puts it. Returns its objects."""
    mod = importlib.import_module(module_name)
    before = set(bpy.context.scene.objects)
    extra = mod.build() or {}
    made = [o for o in bpy.context.scene.objects if o not in before]
    bpy.context.view_layer.update()   # every part's matrix_world current before it is moved (Landon,
    # Nov 9: the axe's head showed off its handle in the sheet: its last move wasn't applied yet)
    grip = Vector(extra["export"]["sockets"]["Grip"][0])
    wrist = arm.data.bones["RightHand"].head_local
    place = Matrix.Translation(wrist + B @ PALM) @ B.to_4x4() @ Matrix.Translation(-grip)
    for o in made:
        o.matrix_world = place @ o.matrix_world
    bpy.context.view_layer.update()
    for o in made:
        sf.bind(o, arm, "RightHand")
    return made


if __name__ == "__main__":
    sf.reset()
    rc.build()
    arm = rc.arm
    print(f"[R15_LongGuns] skeleton check: {check_fk(arm):.6f} studs off Blender's")
    hold_act, hip = rifle_hold(arm)
    aim_act, _aim = rifle_aim(arm)
    acts = [hold_act, aim_act, rifle_reload(arm, hip)]
    heavy = heavy_swings(arm)
    acts += heavy + [throw(arm)]
    if os.environ.get("SF_EXPORT") == "1":
        for path in sf.export_clips(arm, "R15", acts, root="HumanoidRootPart"):
            print(path)
    if os.environ.get("SF_NORENDER") != "1":
        only = os.environ.get("SF_ONLY")
        shown = None
        for act in acts:
            if only and act.name not in only.split(","):
                continue
            want = None if act.name == "Throw" else ("Weapon_FireAxe" if act in heavy else os.environ.get("SF_GUN", "Weapon_LeverRifle"))
            if want != shown:
                for o in list(bpy.context.scene.objects):
                    if o.get("sf_preview_weapon"):
                        bpy.data.objects.remove(o, do_unlink=True)
                if want:
                    for pb in arm.pose.bones:
                        pb.rotation_quaternion = (1, 0, 0, 0)
                        pb.location = (0, 0, 0)
                    arm.animation_data.action = None
                    bpy.context.view_layer.update()
                    for o in in_hand(arm, want):
                        o["sf_preview_weapon"] = True
                shown = want
            end = act["sf_end"]
            frames = sorted({0, round(end * 0.25), round(end * 0.45), round(end * 0.7), end})
            print(sheet(arm, act, frames, f"R15_{act.name}_sheet", yaws=(-25, -90, -160)))
