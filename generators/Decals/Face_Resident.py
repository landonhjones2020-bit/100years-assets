"""Face decals for residents (bible Section 19: face decals painted for the resident kit).

Run: python3 generators/Decals/Face_Resident.py   -> decals/Face_Resident_<Name>.png

A Decal on the Head's front face covers the whole front of the Head MeshPart's bounds
(neck to crown, ear to ear), so features are placed in those fractions. Drawn at 4x and
downsampled for clean edges. 1950s print-cartoon style: solid navy shapes, a white glint,
soft blush, no outlines on skin (skin colour comes from MeshPart.Color underneath).
"""
from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "decals")
S = 512          # final size
K = 4            # supersampling
NAVY = (27, 42, 58, 255)
WHITE = (247, 245, 238, 255)
BLUSH = (232, 160, 154, 110)

# feature placement as fractions of the head's front face (x from its left edge as seen from
# the front, y from the crown down). Head MeshPart bounds: crown 5.38, neck base 3.88.
EYE_Y, EYE_DX, MOUTH_Y = 0.36, 0.165, 0.60


def px(fx: float, fy: float) -> tuple[float, float]:
    return fx * S * K, fy * S * K


def ellipse(d: ImageDraw.ImageDraw, cx, cy, rx, ry, fill):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)


def face(name: str, mood: str = "smile") -> str:
    big = Image.new("RGBA", (S * K, S * K), (0, 0, 0, 0))
    blush = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d, db = ImageDraw.Draw(big), ImageDraw.Draw(blush)
    u = S * K
    for side in (-1, 1):
        ex, ey = px(0.5 + side * EYE_DX, EYE_Y)
        ellipse(d, ex, ey, 0.042 * u, 0.062 * u, NAVY)                      # eye
        ellipse(d, ex + 0.014 * u, ey - 0.024 * u, 0.014 * u, 0.016 * u, WHITE)   # glint
        # brow: a thick arc, lifted at the outer end
        bx0, by = ex - 0.06 * u, ey - 0.115 * u
        d.line([(bx0, by + 0.01 * u * side * 0), (ex, by - 0.018 * u), (ex + 0.06 * u, by - 0.004 * u)][::side],
               fill=NAVY, width=int(0.022 * u), joint="curve")
        cx, cy = px(0.5 + side * (EYE_DX + 0.055), MOUTH_Y - 0.06)
        ellipse(db, cx, cy, 0.055 * u, 0.032 * u, BLUSH)                   # cheek
    mx, my = px(0.5, MOUTH_Y)
    if mood == "smile":
        d.arc((mx - 0.085 * u, my - 0.075 * u, mx + 0.085 * u, my + 0.05 * u), 20, 160,
              fill=NAVY, width=int(0.022 * u))
    else:  # "flat": a short line, for tired or unhappy residents
        d.line([(mx - 0.06 * u, my), (mx + 0.06 * u, my)], fill=NAVY, width=int(0.022 * u))
    blush = blush.filter(ImageFilter.GaussianBlur(0.012 * u))
    out = Image.alpha_composite(blush, big).resize((S, S), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"Face_Resident_{name}.png")
    out.save(path)
    return path


if __name__ == "__main__":
    print(face("Smile", "smile"))
    print(face("Flat", "flat"))
