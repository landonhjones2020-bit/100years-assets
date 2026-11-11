"""R15_IntroSprint: the sprint the party's avatars and the founders run in the intro cutscene
(bible Section 4, shot 2: "The party's avatars sprint up the hillside path into the Steadfast
blast door, with six residents"; Prompt 22). On the standard R15 skeleton, so it plays on any
avatar and on the residents (Resident_Common is the preview body).

One stride cycle (two steps) in 0.4 s, looped, Action priority: made for the cutscene's run speed
(cutscene_plan.RUN_SPEED, 27 studs a second), where it is played at speed 1. A flat-out, frightened
sprint: knees high, heels up behind, the arms pumping bent, the body thrown forward, the head up
to see the door.

Angles follow steadfast.make_rig's upright bones (see R15_PlayerCombat): a limb's forward swing
is -X, the torso's forward lean +X.

Run:  SF_EXPORT=1 python3 generators/Clips/R15_IntroSprint.py      (SF_NORENDER=1: no sheet)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
sys.path.insert(0, os.path.join(HERE, "..", "Residents"))
sys.path.insert(0, HERE)
import steadfast as sf  # noqa: E402
import Resident_Common as rc  # noqa: E402
import R15_PlayerCombat as pc  # noqa: E402

FRAMES = 12


def sprint(arm):
    act = pc.action(arm, "IntroSprint", FRAMES, True, "Action")

    def pose(f, leg_l, knee_l, foot_l, leg_r, knee_r, foot_r, arm_l, arm_r, elb_l, elb_r, twist, bob):
        pc.keys(arm, f, {
            "LeftUpperLeg": (-leg_l, 0, 0), "LeftLowerLeg": (knee_l, 0, 0), "LeftFoot": (-foot_l, 0, 0),
            "RightUpperLeg": (-leg_r, 0, 0), "RightLowerLeg": (knee_r, 0, 0), "RightFoot": (-foot_r, 0, 0),
            "LeftUpperArm": (-arm_l, 0, 7), "RightUpperArm": (-arm_r, 0, -7),
            "LeftLowerArm": (-elb_l, 0, 0), "RightLowerArm": (-elb_r, 0, 0),
            "UpperTorso": (15, twist, 0), "LowerTorso": ((11, -twist * 0.6, 0), (0, bob, 0)),
            "Head": (-17, -twist * 0.7, 0),
        }, ease="LINEAR")

    #    frame leg_l knee_l foot_l leg_r knee_r foot_r arm_l arm_r elb_l elb_r twist  bob
    pose(0, 58, 18, 14, -38, 78, -30, -52, 62, 80, 104, 13, -0.14)        # the left foot reaches; the right heel is up behind
    pose(3, 8, 14, 0, 34, 112, 6, -4, 8, 92, 92, 0, 0.16)                 # over the left foot; the right knee comes through high
    pose(6, -38, 78, -30, 58, 18, 14, 62, -52, 104, 80, -13, -0.14)       # the same, mirrored
    pose(9, 34, 112, 6, 8, 14, 0, 8, -4, 92, 92, 0, 0.16)
    pose(12, 58, 18, 14, -38, 78, -30, -52, 62, 80, 104, 13, -0.14)
    return act


if __name__ == "__main__":
    sf.reset()
    rc.build()
    arm = rc.arm
    act = sprint(arm)
    if os.environ.get("SF_EXPORT") == "1":
        for path in sf.export_clips(arm, "R15", [act], root="HumanoidRootPart"):
            print(path)
    if os.environ.get("SF_NORENDER") != "1":
        print(pc.sheet(arm, act, [0, 2, 3, 5, 6, 9], "R15_IntroSprint_sheet", yaws=(90, 35)))
