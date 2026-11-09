"""Print the Luau that builds a map in Studio (Prompt 16: studio/map/Surface.lua builds
workspace.Surface, Brightwater Ruins): the file with `--@include <file>` lines inlined and
whole-line comments dropped (to stay under execute_luau's size). Send it with execute_luau (Edit).

    python3 tools/map_luau.py                         # studio/map/Surface.lua
    python3 tools/map_luau.py studio/map/Surface.lua
"""
import os
import re
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def expand(path):
    out = []
    for line in open(path).read().splitlines():
        m = re.match(r"^\s*--@include\s+(\S+)\s*$", line)
        if m:
            out.append(expand(os.path.normpath(os.path.join(os.path.dirname(path), m.group(1)))))
        elif not line.strip().startswith("--"):
            out.append(line)
    return "\n".join(out)


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "studio", "map", "Surface.lua")
    code = expand(path)
    sys.stderr.write(f"{len(code)} bytes\n")
    print(code)
