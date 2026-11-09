"""Cave_Flooded_Pocket: the Flooded band's Pocket cave piece (A6; see cavelib.py and cavedress.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import cavedress  # noqa: E402

if __name__ == "__main__":
    cavedress.main("Flooded", "Pocket")
