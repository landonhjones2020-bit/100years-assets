"""R15_TestWave: pipeline-test clip for the standard R15 rig (players' avatars).

Raises the right arm and waves the forearm. Used only to prove that a KeyframeSequence
written here uploads through the Assets API and plays in the Run place. It is written
straight in Roblox axes (Motor6D.Transform values), so it needs no Blender rig; production
clips come from Blender rigs through steadfast.export_clips().

Run: python3 generators/Clips/R15_TestWave.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import steadfast as sf  # noqa: E402

UP = 2.6  # shoulder roll about Z (radians): the arm swings out to the right and up


def key(t, shoulder, elbow):
    return {
        "RightUpperArm": {"t": t, "pos": [0, 0, 0], "rot": [0, 0, shoulder], "style": 3, "dir": 2},
        "RightLowerArm": {"t": t, "pos": [0, 0, 0], "rot": [0, 0, elbow], "style": 3, "dir": 2},
    }


def build() -> dict:
    frames = [key(0.0, 0, 0), key(0.4, UP, 0), key(0.7, UP, 0.5), key(1.0, UP, -0.5),
              key(1.3, UP, 0.5), key(1.6, UP, 0), key(2.0, 0, 0)]
    keys: dict = {}
    for fr in frames:
        for bone, k in fr.items():
            keys.setdefault(bone, []).append(k)
    return {
        "rig": "R15", "clip": "TestWave", "length": 2.0, "loop": True, "priority": "Action",
        "root": "HumanoidRootPart",
        "parents": {"HumanoidRootPart": None, "LowerTorso": "HumanoidRootPart",
                    "UpperTorso": "LowerTorso", "RightUpperArm": "UpperTorso",
                    "RightLowerArm": "RightUpperArm"},
        "keys": keys,
    }


if __name__ == "__main__":
    clip = build()
    out = os.path.join(sf.REPO, "animations", "R15")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "TestWave.json"), "w") as f:
        json.dump(clip, f, indent=1)
    sf.write_keyframe_sequence(os.path.join(out, "TestWave.rbxmx"), clip)
    sf.manifest_upsert("R15_TestWave", category="Animations/R15", kind="clip", step="Setup",
                       status="exported", notes="pipeline test clip")
    print("wrote", out)
