"""R15_PlayerCombat: the players' combat clips on the standard R15 rig (bible Sections 9 and
19; Prompt 11). Players keep their own Roblox avatars, so these clips move the standard R15
skeleton (rigs/R15.json); the preview body is Resident_Common's.

Angles follow steadfast.make_rig's upright bones (degrees, XYZ):
  limbs: forward swing = -X; a hanging arm goes outward with +Z (left) or -Z (right);
         a raised arm turns toward the character's left with +Y.
  torso: lean forward = +X; turn toward the character's left = +Y.
Only the bones a clip moves are keyed, so a gun pose leaves the legs to Roblox's walk.

Clips (Config.Animations activities; CombatController plays them, sped to fit):
  GunHold      loop, Action:   a one-handed gun held forward at the hip
  GunAim       loop, Action:   both hands up, the gun at eye line
  Reload       Action2:        the free hand works the gun (sped to the gun's ReloadSeconds)
  Melee1/2/3   Action3:        forehand, backhand, overhead (sped to the weapon's swing; the
                               hit lands at 40%, Tuning.Combat.MeleeWindupFraction)
  MeleeHeavy   Action3:        a two-handed smash from overhead
  MeleeCharge  loop, Action2:  the heavy swing's wind-up, held
  Dodge        Action4:        a forward roll
  Downed       loop, Action4:  prone, crawling
  Revive       loop, Action3:  kneeling over someone, working

Run:  SF_EXPORT=1 python3 generators/Clips/R15_PlayerCombat.py      (SF_NORENDER=1: no sheets)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Residents"))
import steadfast as sf  # noqa: E402
import bpy  # noqa: E402
import Resident_Common as rc  # noqa: E402

FPS = 30


def keys(arm, frame, poses: dict, ease="SINE", direction="EASE_IN_OUT"):
    """poses: bone -> (rx, ry, rz) or ((rx, ry, rz), (lx, ly, lz))."""
    for bone, value in poses.items():
        if isinstance(value[0], (tuple, list)):
            sf.key(arm, bone, frame, rot=value[0], loc=value[1], ease=ease, direction=direction)
        else:
            sf.key(arm, bone, frame, rot=value, ease=ease, direction=direction)


def action(arm, name, frames, loop, priority):
    return sf.new_action(arm, name, 0, frames, loop=loop, priority=priority)


# Poses -----------------------------------------------------------------------------------

HOLD = {"RightUpperArm": (-25, 10, -8), "RightLowerArm": (-65, 0, 0), "RightHand": (0, 0, 0)}
AIM = {"RightUpperArm": (-88, 22, 0), "RightLowerArm": (-6, 0, 0), "RightHand": (0, 0, 0),
       "LeftUpperArm": (-76, -40, 0), "LeftLowerArm": (-28, 0, 0), "UpperTorso": (2, 6, 0), "Head": (0, -6, 0)}


def finger_direction(arm, pose: dict):
    """Where the right hand's fingers point (the held gun's barrel: RightGripAttachment's -Z runs
    along the fingers) in a pose: (yaw, pitch) in degrees, yaw + toward the character's left,
    0 = straight ahead (the rig faces -Y)."""
    import math
    from mathutils import Euler, Vector
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
    m = arm.matrix_world.to_3x3() @ arm.pose.bones["RightHand"].matrix.to_3x3()
    d = -(m @ Vector((0, 1, 0)))
    d.normalize()
    side = (m @ Vector((1, 0, 0))).normalized()   # the hand's lateral axis: level when the gun is upright
    roll = math.degrees(math.asin(max(-1.0, min(1.0, side.z))))
    return math.degrees(math.atan2(d.x, -d.y)), math.degrees(math.asin(max(-1.0, min(1.0, d.z)))), roll


def straighten(arm, pose: dict) -> dict:
    """The pose with the right wrist turned so the gun points straight ahead and level (Landon,
    Nov 8: the aim was crooked: the barrel pointed 27 degrees left of the crosshair). The wrist's
    Z turns the gun left and right (its Z axis is vertical when the forearm is raised) and X
    tips it up and down."""
    out = dict(pose)
    rx, ry, rz = out.get("RightHand", (0, 0, 0))
    # the wrist's twist (Y) levels the gun's roll; find which way it turns it first
    out["RightHand"] = (rx, ry, rz)
    _y, _p, r0 = finger_direction(arm, out)
    out["RightHand"] = (rx, ry + 1.0, rz)
    _y, _p, r1 = finger_direction(arm, out)
    twist = 1.0 if r1 < r0 else -1.0
    for _ in range(8):
        out["RightHand"] = (rx, ry, rz)
        yaw, pitch, roll = finger_direction(arm, out)
        if abs(yaw) < 0.2 and abs(pitch) < 0.2 and abs(roll) < 0.3:
            break
        rz -= yaw
        rx += pitch
        ry += twist * roll
    out["RightHand"] = (round(rx, 2), round(ry, 2), round(rz, 2))
    yaw, pitch, roll = finger_direction(arm, out)
    print(f"[R15_PlayerCombat] straightened RightHand {out['RightHand']}: barrel yaw {yaw:.2f}, pitch {pitch:.2f}, roll {roll:.2f}")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return out
RAISED = {"RightUpperArm": (-168, 14, -4), "RightLowerArm": (-38, 0, 0),
          "LeftUpperArm": (-162, -20, 4), "LeftLowerArm": (-42, 0, 0),
          "UpperTorso": (-14, 0, 0), "LowerTorso": ((0, 0, 0), (0, -0.12, 0))}


def gun_hold(arm):
    hold = straighten(arm, HOLD)
    act = action(arm, "GunHold", 30, True, "Action")
    keys(arm, 0, hold)
    rx, ry, rz = hold["RightHand"]
    keys(arm, 15, {"RightUpperArm": (-27, 10, -8), "RightLowerArm": (-64, 0, 0), "RightHand": (rx - 2, ry, rz)})
    keys(arm, 30, hold)
    return act


def gun_aim(arm):
    aim = straighten(arm, AIM)
    act = action(arm, "GunAim", 30, True, "Action")
    keys(arm, 0, aim)
    breathe = dict(aim)
    breathe["RightUpperArm"] = (-89, 22, 0)
    breathe["LeftUpperArm"] = (-77, -40, 0)
    keys(arm, 15, breathe)
    keys(arm, 30, aim)
    return act


def reload_(arm):
    act = action(arm, "Reload", 36, False, "Action2")   # 1.2 s at 30 fps
    keys(arm, 0, {**HOLD, "LeftUpperArm": (0, 0, 4), "LeftLowerArm": (0, 0, 0)})
    keys(arm, 8, {"RightUpperArm": (-40, 28, -4), "RightLowerArm": (-72, 0, 0), "RightHand": (0, 0, 45),
                  "LeftUpperArm": (-42, -34, 0), "LeftLowerArm": (-72, 0, 0)})
    keys(arm, 18, {"RightUpperArm": (-42, 28, -4), "RightLowerArm": (-74, 0, 0), "RightHand": (0, 0, 45),
                   "LeftUpperArm": (-30, -26, 0), "LeftLowerArm": (-60, 0, 0)})
    keys(arm, 26, {"RightUpperArm": (-40, 28, -4), "RightLowerArm": (-72, 0, 0), "RightHand": (0, 0, 40),
                   "LeftUpperArm": (-46, -36, 0), "LeftLowerArm": (-76, 0, 0)})
    keys(arm, 36, {**HOLD, "LeftUpperArm": (0, 0, 4), "LeftLowerArm": (0, 0, 0)})
    return act


def melee(arm, name, wind, impact, follow, settle, frames=11):
    """A swing: wind-up at 0, the hit at 40%, follow-through at 70%, settling at the end."""
    act = action(arm, name, frames, False, "Action3")
    keys(arm, 0, wind, ease="QUAD", direction="EASE_IN")
    keys(arm, round(frames * 0.4), impact, ease="QUAD", direction="EASE_OUT")
    keys(arm, round(frames * 0.7), follow)
    keys(arm, frames, settle)
    return act


def melee_clips(arm):
    m1 = melee(arm, "Melee1",
               {"RightUpperArm": (-55, -62, 0), "RightLowerArm": (-62, 0, 0), "UpperTorso": (0, -26, 0)},
               {"RightUpperArm": (-82, 8, 0), "RightLowerArm": (-14, 0, 0), "UpperTorso": (5, 6, 0)},
               {"RightUpperArm": (-72, 56, 0), "RightLowerArm": (-30, 0, 0), "UpperTorso": (6, 26, 0)},
               {"RightUpperArm": (-36, 20, 0), "RightLowerArm": (-50, 0, 0), "UpperTorso": (0, 8, 0)})
    m2 = melee(arm, "Melee2",
               {"RightUpperArm": (-66, 56, 0), "RightLowerArm": (-72, 0, 0), "UpperTorso": (0, 22, 0)},
               {"RightUpperArm": (-86, 0, 0), "RightLowerArm": (-10, 0, 0), "UpperTorso": (3, 0, 0)},
               {"RightUpperArm": (-70, -56, 0), "RightLowerArm": (-22, 0, 0), "UpperTorso": (3, -22, 0)},
               {"RightUpperArm": (-36, -10, 0), "RightLowerArm": (-50, 0, 0), "UpperTorso": (0, -6, 0)})
    m3 = melee(arm, "Melee3",
               {"RightUpperArm": (-165, 4, -10), "RightLowerArm": (-42, 0, 0), "UpperTorso": (-8, 0, 0)},
               {"RightUpperArm": (-96, 4, 0), "RightLowerArm": (-10, 0, 0), "UpperTorso": (12, 0, 0)},
               {"RightUpperArm": (-46, 4, 0), "RightLowerArm": (-16, 0, 0), "UpperTorso": (16, 0, 0)},
               {"RightUpperArm": (-30, 10, 0), "RightLowerArm": (-45, 0, 0), "UpperTorso": (4, 0, 0)},
               frames=12)
    heavy = melee(arm, "MeleeHeavy", RAISED,
                  {"RightUpperArm": (-80, 18, 0), "RightLowerArm": (-6, 0, 0),
                   "LeftUpperArm": (-78, -24, 0), "LeftLowerArm": (-10, 0, 0),
                   "UpperTorso": (24, 0, 0), "LowerTorso": ((0, 0, 0), (0, -0.4, 0))},
                  {"RightUpperArm": (-40, 18, 0), "RightLowerArm": (-10, 0, 0),
                   "LeftUpperArm": (-38, -24, 0), "LeftLowerArm": (-12, 0, 0),
                   "UpperTorso": (28, 0, 0), "LowerTorso": ((0, 0, 0), (0, -0.45, 0))},
                  {"RightUpperArm": (-20, 4, 0), "RightLowerArm": (-30, 0, 0),
                   "LeftUpperArm": (-8, 0, 4), "LeftLowerArm": (-18, 0, 0),
                   "UpperTorso": (5, 0, 0), "LowerTorso": ((0, 0, 0), (0, 0, 0))},
                  frames=17)
    charge = action(arm, "MeleeCharge", 18, True, "Action2")
    keys(arm, 0, RAISED)
    keys(arm, 9, {**RAISED, "RightUpperArm": (-171, 14, -4), "LeftUpperArm": (-165, -20, 4)})
    keys(arm, 18, RAISED)
    return [m1, m2, m3, heavy, charge]


def dodge(arm):
    act = action(arm, "Dodge", 14, False, "Action4")   # 0.47 s; played at DodgeSeconds
    tuck_legs = {"LeftUpperLeg": (-95, 0, 4), "RightUpperLeg": (-95, 0, -4),
                 "LeftLowerLeg": (110, 0, 0), "RightLowerLeg": (110, 0, 0)}
    tuck_arms = {"LeftUpperArm": (-70, -10, 0), "RightUpperArm": (-70, 10, 0),
                 "LeftLowerArm": (-90, 0, 0), "RightLowerArm": (-90, 0, 0)}
    neutral = {"LowerTorso": ((0, 0, 0), (0, 0, 0)), "UpperTorso": (0, 0, 0), "Head": (0, 0, 0),
               "LeftUpperLeg": (0, 0, 0), "RightUpperLeg": (0, 0, 0), "LeftLowerLeg": (0, 0, 0), "RightLowerLeg": (0, 0, 0),
               "LeftUpperArm": (0, 0, 0), "RightUpperArm": (0, 0, 0), "LeftLowerArm": (0, 0, 0), "RightLowerArm": (0, 0, 0)}
    keys(arm, 0, neutral, ease="LINEAR")
    keys(arm, 3, {"LowerTorso": ((70, 0, 0), (0, -0.9, 0)), "UpperTorso": (30, 0, 0), "Head": (20, 0, 0),
                  **tuck_legs, **tuck_arms}, ease="LINEAR")
    keys(arm, 6, {"LowerTorso": ((160, 0, 0), (0, -1.3, 0)), "UpperTorso": (30, 0, 0), "Head": (20, 0, 0),
                  **tuck_legs, **tuck_arms}, ease="LINEAR")
    keys(arm, 9, {"LowerTorso": ((250, 0, 0), (0, -1.2, 0)), "UpperTorso": (28, 0, 0), "Head": (20, 0, 0),
                  **tuck_legs, **tuck_arms}, ease="LINEAR")
    keys(arm, 12, {"LowerTorso": ((330, 0, 0), (0, -0.5, 0)), "UpperTorso": (12, 0, 0), "Head": (6, 0, 0),
                   "LeftUpperLeg": (-40, 0, 4), "RightUpperLeg": (-40, 0, -4),
                   "LeftLowerLeg": (50, 0, 0), "RightLowerLeg": (50, 0, 0),
                   "LeftUpperArm": (-30, 0, 6), "RightUpperArm": (-30, 0, -6),
                   "LeftLowerArm": (-30, 0, 0), "RightLowerArm": (-30, 0, 0)})
    keys(arm, 14, {**neutral, "LowerTorso": ((360, 0, 0), (0, 0, 0))})
    return act


def downed(arm):
    act = action(arm, "Downed", 36, True, "Action4")   # 1.2 s crawl cycle
    body = {"LowerTorso": ((86, 0, 0), (0, -1.5, 0)), "UpperTorso": (-12, 0, 0), "Head": (-30, 0, 0)}
    reach_l = {"LeftUpperArm": (-165, 0, 12), "LeftLowerArm": (-18, 0, 0),
               "RightUpperArm": (-100, 0, -18), "RightLowerArm": (-70, 0, 0),
               "LeftUpperLeg": (4, 0, 6), "LeftLowerLeg": (12, 0, 0),
               "RightUpperLeg": (-24, 0, -8), "RightLowerLeg": (46, 0, 0)}
    reach_r = {"RightUpperArm": (-165, 0, -12), "RightLowerArm": (-18, 0, 0),
               "LeftUpperArm": (-100, 0, 18), "LeftLowerArm": (-70, 0, 0),
               "RightUpperLeg": (4, 0, -6), "RightLowerLeg": (12, 0, 0),
               "LeftUpperLeg": (-24, 0, 8), "LeftLowerLeg": (46, 0, 0)}
    keys(arm, 0, {**body, **reach_l})
    keys(arm, 18, {**body, "UpperTorso": (-10, 3, 0), **reach_r})
    keys(arm, 36, {**body, **reach_l})
    return act


def revive(arm):
    act = action(arm, "Revive", 30, True, "Action3")
    base = {"LowerTorso": ((8, 0, 0), (0, -1.05, 0)), "UpperTorso": (24, 0, 0), "Head": (6, 0, 0),
            "RightUpperLeg": (-92, 0, -6), "RightLowerLeg": (92, 0, 0), "RightFoot": (-4, 0, 0),
            "LeftUpperLeg": (-6, 0, 6), "LeftLowerLeg": (96, 0, 0), "LeftFoot": (40, 0, 0)}
    up = {"RightUpperArm": (-58, 16, 0), "RightLowerArm": (-14, 0, 0),
          "LeftUpperArm": (-58, -16, 0), "LeftLowerArm": (-14, 0, 0)}
    down = {"RightUpperArm": (-48, 16, 0), "RightLowerArm": (-6, 0, 0),
            "LeftUpperArm": (-48, -16, 0), "LeftLowerArm": (-6, 0, 0)}
    keys(arm, 0, {**base, **up})
    keys(arm, 15, {**base, "UpperTorso": (30, 0, 0), **down})
    keys(arm, 30, {**base, **up})
    return act


def sheet(arm, act, frames, name, yaws=(20, 90)):
    """Frames across, one row per view; every bone the clip doesn't key stays at rest."""
    from PIL import Image
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and len(getattr(act, "slots", [])) > 0:
        arm.animation_data.action_slot = act.slots[0]
    size = 300
    out_img = Image.new("RGB", (size * len(frames), size * len(yaws)))
    for row, yaw in enumerate(yaws):
        for col, f in enumerate(frames):
            bpy.context.scene.frame_set(f)
            path = sf.render_preview(rc.ASSET, rc.CATEGORY, res=size, samples=10,
                                     views=[(yaw, 8, False)], out_name=f"_{name}_{f}_{yaw}")
            im = Image.open(path).convert("RGB")
            out_img.paste(im.resize((size, size)), (col * size, row * size))
            im.close()
            os.remove(path)
    os.makedirs(os.path.join(sf.REPO, "previews", "Clips"), exist_ok=True)
    out = os.path.join(sf.REPO, "previews", "Clips", f"{name}.png")
    out_img.save(out)
    bpy.context.scene.frame_set(0)
    return out


if __name__ == "__main__":
    sf.reset()
    rc.build()
    arm = rc.arm
    acts = [gun_hold(arm), gun_aim(arm), reload_(arm)] + melee_clips(arm) + [dodge(arm), downed(arm), revive(arm)]
    if os.environ.get("SF_EXPORT") == "1":
        for path in sf.export_clips(arm, "R15", acts, root="HumanoidRootPart"):
            print(path)
    if os.environ.get("SF_NORENDER") != "1":
        only = os.environ.get("SF_ONLY")
        for act in acts:
            if only and act.name not in only.split(","):
                continue
            end = act["sf_end"]
            frames = sorted({0, round(end * 0.25), round(end * 0.5), round(end * 0.75), end})
            print(sheet(arm, act, frames, f"R15_{act.name}_sheet"))
