"""Print the Luau to send through execute_luau to finish an inserted asset.

    python3 tools/setup_code.py Prop_SupplyCrate <assetId> [model path in Studio]
    python3 tools/setup_code.py Resident_Common <assetId> --rig --face <imageId> --clip Walk=<animId>

The model path defaults to ServerStorage.Assets.Pipeline.<asset> (where insert_asset puts
new uploads). The printed code is studio/AssetSetup.lua followed by the call with the
asset's sidecar JSON from exports/.
"""
from __future__ import annotations

import glob
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def main(asset: str, asset_id: str, path: str | None = None, rig: bool = False, face: str | None = None,
         clips: dict | None = None) -> str:
    hits = glob.glob(os.path.join(REPO, "exports", "*", f"{asset}.json"))
    assert hits, f"no sidecar for {asset} under exports/"
    sidecar = open(hits[0]).read()
    pal = json.load(open(os.path.join(REPO, "palette", "palette.json")))
    hexes = {s["name"]: s["hex"] for s in pal["swatches"] if s["hex"]}
    module = open(os.path.join(REPO, "studio", "AssetSetup.lua")).read()
    module = module.replace("--!strict\n", "", 1)
    body = module.rsplit("return AssetSetup", 1)[0]
    path = path or f"ServerStorage.Assets.Pipeline.{asset}"
    parts = ", ".join(f'"{p}"' for p in path.split("."))
    return (body
            + "\nlocal HttpService = game:GetService(\"HttpService\")\n"
            + f"local node: Instance = game\nfor _, n in {{{parts}}} do node = node:FindFirstChild(n) :: Instance end\n"
            + f"local doc = HttpService:JSONDecode([==[{sidecar}]==])\n"
            + f"local hexes = HttpService:JSONDecode([==[{json.dumps(hexes)}]==])\n"
            + (f'return AssetSetup.run(node :: Model, doc, {{ assetId = "{asset_id}", swatchHex = hexes }})\n'
               if not rig else
               f'return AssetSetup.rig(node :: Model, doc, {{ assetId = "{asset_id}", swatchHex = hexes, '
               + (f'faceImage = "rbxassetid://{face}", ' if face else "")
               + "clips = {" + ", ".join(f'{k} = "rbxassetid://{v}"' for k, v in (clips or {}).items()) + "} })\n"))


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("asset")
    ap.add_argument("asset_id")
    ap.add_argument("path", nargs="?")
    ap.add_argument("--rig", action="store_true", help="segmented rig: run AssetSetup.rig")
    ap.add_argument("--face", help="face image id for the Head's front")
    ap.add_argument("--clip", action="append", default=[], help="Name=animationId, written as Anim_<Name>")
    a = ap.parse_args()
    print(main(a.asset, a.asset_id, a.path, a.rig, a.face, dict(c.split("=", 1) for c in a.clip)))
