#!/usr/bin/env python3
"""Puts the intro cutscene's data module into the game (bible Section 4; Section 19's repo table:
`cutscene/` holds "the intro camera path as a Luau data module").

`python3 generators/Cutscene/Intro_Scene.py --data` writes cutscene/IntroPath.luau from the
Blender scene (the camera's keys, the set's layout, the beats). This copies it to
game/shared/Config/CutscenePaths.luau, the copy the game reads.

    python3 tools/cutscene_config.py            # copy
    python3 tools/cutscene_config.py --check    # exit 1 if the two differ
"""
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "cutscene", "IntroPath.luau")
DST = os.path.join(REPO, "game", "shared", "Config", "CutscenePaths.luau")


def main():
    src = open(SRC).read()
    if "--check" in sys.argv:
        same = os.path.exists(DST) and open(DST).read() == src
        print("the game's copy matches cutscene/IntroPath.luau" if same else "game/shared/Config/CutscenePaths.luau is out of date: run tools/cutscene_config.py")
        sys.exit(0 if same else 1)
    with open(DST, "w") as f:
        f.write(src)
    print(f"wrote {os.path.relpath(DST, REPO)} ({len(src) // 1024} KB)")


if __name__ == "__main__":
    main()
