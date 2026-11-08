"""Print one Luau chunk that finishes several inserted assets at once: studio/AssetSetup.lua
plus a call per asset with its minified sidecar.

    python3 tools/setup_batch.py Room_Kitchen_L1=96540501294464 \
        Resident_Common=118658215913755:rig:face=103176016141485:Walk=125264708961546

Each argument is <Asset>=<assetId>[:rig][:face=<imageId>][:<Clip>=<animationId>...]. Models are
read from ServerStorage.Assets.Pipeline.<Asset>.
"""
from __future__ import annotations

import glob
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
KEEP_PART = ("name", "material", "transparency", "collision", "castShadow", "role", "bone", "tint",
             "swatches", "offset", "size")


def sidecar(asset: str) -> dict:
    hits = glob.glob(os.path.join(REPO, "exports", "*", f"{asset}.json"))
    assert hits, f"no sidecar for {asset}"
    d = json.load(open(hits[0]))
    d["parts"] = [{k: p[k] for k in KEEP_PART if k in p} for p in d["parts"]]
    d["parts"] = [{k: v for k, v in p.items() if v is not None} for p in d["parts"]]
    for p in d["parts"]:
        p["swatches"] = p.get("swatches", [])[:1]
    d.pop("export", None)
    return d


def main(args: list[str]) -> str:
    pal = json.load(open(os.path.join(REPO, "palette", "palette.json")))
    hexes = {s["name"]: s["hex"] for s in pal["swatches"] if s["hex"]}
    import re
    module = open(os.path.join(REPO, "studio", "AssetSetup.lua")).read().replace("--!strict\n", "", 1)
    module = re.sub(r"--\[\[.*?\]\]", "", module, flags=re.S)          # block comments
    module = "\n".join(l for l in (re.sub(r"^\s*--.*$", "", x).rstrip() for x in module.splitlines()) if l)
    out = [module.rsplit("return AssetSetup", 1)[0],
           'local HttpService = game:GetService("HttpService")',
           f"local hexes = HttpService:JSONDecode([==[{json.dumps(hexes, separators=(',', ':'))}]==])",
           "local pipe = game:GetService(\"ServerStorage\").Assets.Pipeline",
           "local report = {}"]
    for a in args:
        head, *opts = a.split(":")
        asset, asset_id = head.split("=")
        doc = json.dumps(sidecar(asset), separators=(",", ":"))
        is_rig = "rig" in opts
        face = next((o.split("=", 1)[1] for o in opts if o.startswith("face=")), None)
        clips = {o.split("=", 1)[0]: o.split("=", 1)[1] for o in opts if "=" in o and not o.startswith("face=")}
        call = "AssetSetup.rig" if is_rig else "AssetSetup.run"
        extra = ""
        if is_rig:
            extra = (f', faceImage = "rbxassetid://{face}"' if face else "") + ", clips = {" + \
                ", ".join(f'{k} = "rbxassetid://{v}"' for k, v in clips.items()) + "}"
        out.append(f'do local m = pipe:FindFirstChild("{asset}") if not m then table.insert(report, "{asset}: not in Pipeline") else '
                   f'local ok, r = pcall({call}, m, HttpService:JSONDecode([==[{doc}]==]), '
                   f'{{ assetId = "{asset_id}", swatchHex = hexes{extra} }}) '
                   f'table.insert(report, "{asset}: " .. tostring(r)) end end')
    out.append('return table.concat(report, "\\n")')
    return "\n".join(out)


if __name__ == "__main__":
    print(main(sys.argv[1:]))
