"""Stage exported files for the import folder on Landon's PC.

    python3 tools/stage_import.py exports/Props/Prop_SupplyCrate.fbx animations/R15/TestWave.rbxmx

Each file is copied to /mnt/user-data/outputs/import/<subdir>/<stem>__<sha8>.<ext> and the
matching device path in the import folder is printed as JSON, ready for device_commit_files.

Names carry the content hash on purpose: on 2026-11-07 a second device_commit_files to the
same staged path left the PC with the first version of the file. A new name per version
can't be stale, and it shows in the import folder which version went up.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUTBOX = "/mnt/user-data/outputs/import"
IMPORT_DIR = r"C:\Users\lando\OneDrive\Documentos\100Years-Import"


def stage(path: str) -> dict:
    src = os.path.abspath(path)
    rel = os.path.relpath(src, REPO)
    top, rest = rel.split(os.sep, 1)
    sub = os.path.dirname(rest) if top in ("exports", "palette", "icons", "ui") else os.path.join(top, os.path.dirname(rest))
    with open(src, "rb") as f:
        sha = hashlib.sha1(f.read()).hexdigest()[:8]
    stem, ext = os.path.splitext(os.path.basename(src))
    name = f"{stem}__{sha}{ext}"
    out_dir = os.path.join(OUTBOX, sub)
    os.makedirs(out_dir, exist_ok=True)
    staged = os.path.join(out_dir, name)
    shutil.copyfile(src, staged)
    device = IMPORT_DIR + "\\" + "\\".join(p for p in sub.split(os.sep) if p) + ("\\" if sub else "") + name
    return {"stagedPath": staged, "devicePath": device.replace("\\\\", "\\"), "sha8": sha}


if __name__ == "__main__":
    print(json.dumps([stage(p) for p in sys.argv[1:]], indent=1))
