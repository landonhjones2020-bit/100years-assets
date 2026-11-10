"""The starburst lives in generators/Lobby/lobbylib.py; the town's buildings use it too."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Lobby"))
from lobbylib import starburst  # noqa: E402,F401
