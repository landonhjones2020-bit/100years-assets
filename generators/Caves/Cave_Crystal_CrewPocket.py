"""Cave_Crystal_CrewPocket: the Crystal Hollows band's CrewPocket cave piece (A10; see cavelib.py and cavedress.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cavedress  # noqa: E402

if __name__ == "__main__":
    cavedress.main("Crystal", "CrewPocket")
