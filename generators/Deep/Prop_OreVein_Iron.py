"""Prop_OreVein_Iron: an ore vein of Iron (A6; see orevein.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import orevein  # noqa: E402

if __name__ == "__main__":
    orevein.run("Iron", 41)
