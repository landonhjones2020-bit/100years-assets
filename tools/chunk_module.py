"""Wrap a Luau chunk too big to paste (over about 20 KB) as a ModuleScript model, and stage it.

    python3 tools/setup_batch.py A=1 B=2 > /tmp/batch.lua
    python3 tools/chunk_module.py ArtSetupBatch_A5walls /tmp/batch.lua

Writes exports/Tooling/<Name>.rbxmx (one ModuleScript, Source `return function() <chunk> end`)
and prints its stagedPath/devicePath pair (tools/stage_import.py). Upload it as a Model
(contentType model/x-rbxm), then run it in Studio (execute_luau, Edit):

    return require(game:GetService("InsertService"):LoadAsset(<id>):FindFirstChildWhichIsA("ModuleScript", true))()

(CLAUDE.md section 4, 2026-11-08: ArtSetupBatch_A4detail.)
"""
from __future__ import annotations

import json
import os
import sys
from xml.sax.saxutils import escape

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
from stage_import import stage  # noqa: E402


def main(name: str, chunk_path: str) -> dict:
    chunk = open(chunk_path).read()
    source = "return function()\n" + chunk + "\nend\n"
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
        '<Item class="ModuleScript" referent="RBX0">\n<Properties>\n'
        f'<string name="Name">{escape(name)}</string>\n'
        f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>\n'
        '</Properties>\n</Item>\n</roblox>\n'
    )
    assert "]]>" not in source, "the chunk can't contain ]]>"
    out_dir = os.path.join(REPO, "exports", "Tooling")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{name}.rbxmx")
    with open(path, "w") as f:
        f.write(xml)
    return stage(path)


if __name__ == "__main__":
    print(json.dumps(main(sys.argv[1], sys.argv[2]), indent=1))
