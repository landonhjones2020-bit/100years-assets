"""Pack ui/sprites/*.png into 1024x1024 atlases and write ui/kit.json.

    python3 tools/pack_ui.py            # pack, keep uploaded ids for unchanged atlases
    python3 tools/pack_ui.py --luau     # also print the UIKit ModuleScript source

Groups: a piece's "group" in specs.json (the HUD additions are "hud"), else cards (Card_*),
portraits (Portrait_*) and everything else (kit_a, kit_b, ...).
Each sprite gets a 4 px transparent gutter so bilinear filtering never bleeds across.
kit.json records, per sprite: atlas, offset, size, 9-slice margins [l, t, r, b] (or null)
and a note; per atlas: file, sha1 and, once uploaded, decalId and imageId. Sprites are drawn
at 2x their 1080p size ("scale": 2).
Also renders previews/UI/UI_Kit_sheet.jpg, every sprite on a mid-tone background.
"""
import hashlib
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
UI = os.path.join(REPO, "ui")
SPRITES = os.path.join(UI, "sprites")
KIT = os.path.join(UI, "kit.json")
ATLAS = 1024
GUTTER = 4


def group_of(name, spec=None):
    if spec and spec.get("group"):
        return spec["group"]
    if name.startswith("Card_"):
        return "cards"
    if name.startswith("Portrait_"):
        return "portraits"
    return "kit"


def shelf_pack(items):
    """items: [(name, w, h)] -> list of atlases, each {name: (x, y)}."""
    items = sorted(items, key=lambda t: (-t[2], -t[1], t[0]))
    atlases, cur = [], {}
    x = y = shelf_h = 0
    for name, w, h in items:
        W, H = w + 2 * GUTTER, h + 2 * GUTTER
        if x + W > ATLAS:
            x, y, shelf_h = 0, y + shelf_h, 0
        if y + H > ATLAS:
            atlases.append(cur)
            cur, x, y, shelf_h = {}, 0, 0, 0
        cur[name] = (x + GUTTER, y + GUTTER)
        x += W
        shelf_h = max(shelf_h, H)
    if cur:
        atlases.append(cur)
    return atlases


def main():
    specs = json.load(open(os.path.join(UI, "specs.json")))
    old = json.load(open(KIT)) if os.path.exists(KIT) else {"atlases": {}}
    groups: dict = {}
    for name, spec in sorted(specs.items()):
        path = os.path.join(SPRITES, f"{name}.png")
        if not os.path.exists(path):
            print(f"missing sprite: {name}", file=sys.stderr)
            continue
        im = Image.open(path)
        if list(im.size) != spec["size"]:
            print(f"size mismatch {name}: {im.size} vs {spec['size']}", file=sys.stderr)
        groups.setdefault(group_of(name, spec), []).append((name, im.width, im.height))
    kit = {"version": 1, "scale": 2, "atlases": {}, "sprites": {}}
    for g, items in sorted(groups.items()):
        packs = shelf_pack(items)
        for i, pack in enumerate(packs):
            aname = g if len(packs) == 1 and g != "kit" else f"{g}_{chr(ord('a') + i)}"
            sheet = Image.new("RGBA", (ATLAS, ATLAS), (0, 0, 0, 0))
            for name, (x, y) in pack.items():
                im = Image.open(os.path.join(SPRITES, f"{name}.png")).convert("RGBA")
                sheet.paste(im, (x, y))
                spec = specs[name]
                kit["sprites"][name] = {"atlas": aname, "offset": [x, y], "size": [im.width, im.height],
                                        "slice": spec.get("slice"), "note": spec.get("note", "")}
            # crop unused rows so the upload is smaller (Roblox keeps the exact size)
            bbox = sheet.getbbox() or (0, 0, 1, 1)
            hgt = min(ATLAS, bbox[3] + GUTTER)
            sheet = sheet.crop((0, 0, ATLAS, hgt))
            fn = f"atlas_{aname}.png"
            sheet.save(os.path.join(UI, fn), optimize=True)
            sha = hashlib.sha1(open(os.path.join(UI, fn), "rb").read()).hexdigest()
            entry = {"file": f"ui/{fn}", "size": [ATLAS, hgt], "sha1": sha, "decalId": None, "imageId": None}
            prev = old.get("atlases", {}).get(aname)
            if prev and prev.get("sha1") == sha:
                entry["decalId"], entry["imageId"] = prev.get("decalId"), prev.get("imageId")
            kit["atlases"][aname] = entry
    with open(KIT, "w") as f:
        json.dump(kit, f, indent=1, sort_keys=True)
    for a, e in kit["atlases"].items():
        n = sum(1 for s in kit["sprites"].values() if s["atlas"] == a)
        print(f"{a}: {n} sprites, {e['size'][0]}x{e['size'][1]}, image {e['imageId']}")
    contact_sheet(kit)
    return kit


def contact_sheet(kit):
    order = sorted(kit["sprites"], key=lambda n: (group_of(n) != "kit", n))
    pad, lab = 18, 26
    try:
        f = ImageFont.truetype(os.path.join(UI, "fonts", "RobotoCondensed-Regular.ttf"), 15)
    except OSError:
        f = ImageFont.load_default()
    W = 2000
    x = y = pad
    row_h = 0
    places = []
    for n in order:
        w, h = kit["sprites"][n]["size"]
        if x + w + pad > W:
            x, y, row_h = pad, y + row_h + lab + pad, 0
        places.append((n, x, y))
        x += max(w, 120) + pad
        row_h = max(row_h, h)
    H = y + row_h + lab + pad
    sheet = Image.new("RGBA", (W, H), (110, 116, 120, 255))
    dr = ImageDraw.Draw(sheet)
    for n, x, y in places:
        im = Image.open(os.path.join(SPRITES, f"{n}.png")).convert("RGBA")
        sheet.alpha_composite(im, (x, y))
        dr.text((x, y + im.height + 4), n, fill=(245, 240, 228), font=f)
    out = os.path.join(REPO, "previews", "UI")
    os.makedirs(out, exist_ok=True)
    sheet.convert("RGB").save(os.path.join(out, "UI_Kit_sheet.jpg"), quality=90)


def luau(kit):
    lines = ["--!strict", "-- Generated by tools/pack_ui.py from ui/kit.json. Do not edit by hand.",
             "local UIKit = {}", "",
             "export type Sprite = {image: string, offset: Vector2, size: Vector2, slice: Rect?}", "",
             "UIKit.Scale = %d -- sprites are drawn at this multiple of their 1080p size" % kit["scale"], "",
             "UIKit.Sprites = {} :: {[string]: Sprite}"]
    for n, s in sorted(kit["sprites"].items()):
        a = kit["atlases"][s["atlas"]]
        img = f"rbxassetid://{a['imageId']}" if a.get("imageId") else ""
        x, y = s["offset"]
        w, h = s["size"]
        sl = s.get("slice")
        sl_s = f"Rect.new({sl[0]}, {sl[1]}, {w - sl[2]}, {h - sl[3]})" if sl else "nil"
        lines.append(f'UIKit.Sprites["{n}"] = {{image = "{img}", offset = Vector2.new({x}, {y}), '
                     f'size = Vector2.new({w}, {h}), slice = {sl_s}}}')
    lines += ["",
              "-- Point an ImageLabel or ImageButton at a sprite. sliceScale is the 9-slice corner scale",
              "-- (1080p: 1 / Scale; the SliceScaler script adjusts it to the screen height).",
              "function UIKit.apply(label: ImageLabel | ImageButton, name: string, sliceScale: number?)",
              "\tlocal s = UIKit.Sprites[name]",
              "\tassert(s, \"UIKit: no sprite \" .. name)",
              "\tlabel.Image = s.image",
              "\tlabel.ImageRectOffset = s.offset",
              "\tlabel.ImageRectSize = s.size",
              "\tlabel.BackgroundTransparency = 1",
              "\tif s.slice then",
              "\t\tlabel.ScaleType = Enum.ScaleType.Slice",
              "\t\tlabel.SliceCenter = s.slice",
              "\t\tlabel.SliceScale = sliceScale or (1 / UIKit.Scale)",
              "\telse",
              "\t\tlabel.ScaleType = Enum.ScaleType.Stretch",
              "\tend",
              "\tlabel:SetAttribute(\"Sprite\", name)",
              "end", "", "return UIKit", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    k = main()
    if "--luau" in sys.argv:
        print(luau(k))
    # the game code's copy (client Lib.UIKit), always kept in step with kit.json
    with open(os.path.join(REPO, "game", "client", "Lib", "UIKit.luau"), "w") as f:
        f.write(luau(k))
