"""Print the Luau for an A0 UI screen: studio/ui/A0_Builder.lua with the sprite table filled in
(only the sprites the screen names, from ui/kit.json), followed by the screen file.

    python3 tools/ui_luau.py studio/ui/A0_ClassShop.lua
"""
import json
import os
import re
import sys

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def main(screen_path):
    kit = json.load(open(os.path.join(REPO, "ui", "kit.json")))
    builder = open(os.path.join(REPO, "studio", "ui", "A0_Builder.lua")).read()
    screen = open(screen_path).read()
    names = set(re.findall(r'"([A-Za-z0-9_]+)"', screen))
    # names built from pieces in the screen, e.g. "Card_" .. rarity
    for prefix in re.findall(r'"([A-Za-z]+_)"\s*\.\.', screen):
        names |= {n for n in kit["sprites"] if n.startswith(prefix)}
    used = sorted(n for n in names if n in kit["sprites"])
    rows = []
    for n in used:
        s = kit["sprites"][n]
        a = kit["atlases"][s["atlas"]]
        assert a.get("imageId"), f"atlas {s['atlas']} has no imageId yet"
        sl = s.get("slice")
        extra = f", {sl[0]}, {sl[1]}, {sl[2]}, {sl[3]}" if sl else ""
        rows.append(f'\t{n} = {{"rbxassetid://{a["imageId"]}", {s["offset"][0]}, {s["offset"][1]}, '
                    f'{s["size"][0]}, {s["size"][1]}{extra}}},')
    code = builder.replace("--@SPRITES@", "\n" + "\n".join(rows))
    code = "\n".join(l for l in code.splitlines() if not l.strip().startswith("--") or "@" in l)
    return code + "\n" + screen


if __name__ == "__main__":
    print(main(sys.argv[1]))
