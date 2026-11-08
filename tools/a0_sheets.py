"""Compose the A0 approval sheets in previews/A0/ from the Studio screenshots and the
Blender previews.  python3 tools/a0_sheets.py"""
import os

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
F = os.path.join(REPO, "ui", "fonts")
NAVY, CREAM, TEAL, SIGNAL, BG = (27, 42, 58), (242, 230, 201), (47, 111, 115), (232, 116, 59), (226, 220, 206)
HEAD = 118
PAD = 24


def font(n, s):
    return ImageFont.truetype(os.path.join(F, n + ".ttf"), s)


def header(sheet, title, sub):
    d = ImageDraw.Draw(sheet)
    d.rectangle([0, 0, sheet.width, HEAD - 6], fill=TEAL)
    d.rectangle([0, HEAD - 6, sheet.width, HEAD], fill=SIGNAL)
    d.text((32, 10), title, font=font("Oswald-Bold", 46), fill=CREAM)
    d.text((34, 76), sub, font=font("SpecialElite-Regular", 21), fill=CREAM)


def label(sheet, x, y, text):
    d = ImageDraw.Draw(sheet)
    f = font("Oswald-SemiBold", 26)
    w = d.textlength(text, font=f)
    d.rectangle([x, y, x + w + 24, y + 40], fill=NAVY)
    d.text((x + 12, y + 3), text, font=f, fill=CREAM)


def studio_sheet():
    shots = [("Studio_ClassShop.jpg", "CLASS SHOP  ·  THE FRAME"), ("Studio_HUD.jpg", "RUN HUD"),
             ("Studio_Showroom.jpg", "SHOWROOM  ·  KITCHEN L1 IN A CELL"),
             ("Studio_Playtest_Clips.jpg", "PLAYTEST  ·  ATTACK WINDUP + WALK")]
    ims = [Image.open(os.path.join(REPO, "previews", "A0", f)).convert("RGB") for f, _ in shots]
    W, H = ims[0].size
    CAP = 48
    sheet = Image.new("RGB", (2 * W + 3 * PAD, 2 * (H + CAP) + 3 * PAD + HEAD), BG)
    header(sheet, "100 YEARS OF FALLOUT  ·  A0 STYLE TEST  ·  IN STUDIO",
           "Run place, 2026-11-08. Every model, clip and UI image here came through the art repo and Open Cloud.")
    for i, ((f, t), im) in enumerate(zip(shots, ims)):
        x = PAD + (i % 2) * (W + PAD)
        y = HEAD + PAD + (i // 2) * (H + CAP + PAD)
        sheet.paste(im.resize((W, H)), (x, y))
        label(sheet, x, y + H + 6, t)
    sheet.save(os.path.join(REPO, "previews", "A0", "A0_Sheet_Studio.jpg"), quality=90)


def models_sheet():
    items = [("Rooms/Room_Kitchen_L1.png", "KITCHEN L1  ·  2,992 / 3,000 TRIS"),
             ("Monsters/Monster_HollowMiner.png", "HOLLOW MINER  ·  2,142 / 4,000"),
             ("Residents/Resident_Common.png", "RESIDENT  ·  2,268 / 2,500"),
             ("Weapons/Weapon_ServiceRevolver.png", "SERVICE REVOLVER  ·  796 / 1,500"),
             ("Residents/R15_ResidentWalk_sheet.png", "CLIP  ·  RESIDENT WALK (1.0 S LOOP)"),
             ("Monsters/HollowMiner_Attack_sheet.png", "CLIP  ·  HOLLOW MINER ATTACK (1.47 S, HIT AT 0.7 S)")]
    colw = 1100
    rows = []
    for f, t in items:
        im = Image.open(os.path.join(REPO, "previews", f)).convert("RGB")
        rows.append((im.resize((colw, int(im.height * colw / im.width))), t))
    left, right = rows[0:4:2], rows[1:4:2]
    h_models = max(sum(r[0].height + PAD for r in left), sum(r[0].height + PAD for r in right))
    full = 2 * colw + PAD
    clips = [(im.resize((full, int(im.height * full / im.width))), t) for im, t in rows[4:]]
    h_clips = sum(c[0].height + PAD for c in clips)
    sheet = Image.new("RGB", (2 * colw + 3 * PAD, HEAD + PAD + h_models + h_clips), BG)
    header(sheet, "A0 STYLE TEST  ·  MODELS AND CLIPS (BLENDER PREVIEWS)",
           "Rendered from the generators in the art repo; triangle counts against the bible's budgets.")
    for col, items_ in enumerate((left, right)):
        y = HEAD + PAD
        for im, t in items_:
            x = PAD + col * (colw + PAD)
            sheet.paste(im, (x, y))
            label(sheet, x + 12, y + 12, t)
            y += im.height + PAD
    y = HEAD + PAD + h_models
    for im, t in clips:
        sheet.paste(im, (PAD, y))
        label(sheet, PAD + 12, y + 12, t)
        y += im.height + PAD
    sheet.save(os.path.join(REPO, "previews", "A0", "A0_Sheet_Models.jpg"), quality=90)


if __name__ == "__main__":
    studio_sheet()
    models_sheet()
    print("previews/A0/A0_Sheet_Studio.jpg, previews/A0/A0_Sheet_Models.jpg")
