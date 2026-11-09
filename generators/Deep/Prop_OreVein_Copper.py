"""Prop_OreVein_Copper: an ore vein of Copper (A6; see orevein.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import orevein  # noqa: E402

if __name__ == "__main__":
    orevein.run("Copper", 57)
