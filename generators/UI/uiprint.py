"""Flat printed artwork for the UI kit, drawn with PIL: things that are ink on paper or a
painted dial face (sunburst card windows, the cycle dial, seismograph paper, blueprint grid,
ink stamps, gauge glass). Kit pieces map these onto real geometry in Blender, except the
stamps and the glass, which are used as they are."""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.normpath(os.path.join(HERE, "..", "..", "ui", "fonts"))


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name + ".ttf"), size)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def sunburst(path, w, h, dark, light, cx=0.5, cy=0.42, rays=28, ss=2):
    """Atomic-age sunburst: alternating rays, a warm glow behind the figure, a vignette and an
    inner shadow along the top and left edges (the window is recessed)."""
    W, H = w * ss, h * ss
    d, l = rgb(dark), rgb(light)
    im = Image.new("RGB", (W, H), d)
    dr = ImageDraw.Draw(im)
    ox, oy = W * cx, H * cy
    R = math.hypot(W, H)
    for i in range(rays):
        if i % 2:
            continue
        a0 = 2 * math.pi * i / rays
        a1 = 2 * math.pi * (i + 1) / rays
        dr.polygon([(ox, oy), (ox + R * math.cos(a0), oy + R * math.sin(a0)),
                    (ox + R * math.cos(a1), oy + R * math.sin(a1))], fill=l)
    # glow: blend toward a pale version of the light colour near the centre
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    for k in range(40, 0, -1):
        r = R * 0.42 * k / 40
        gd.ellipse([ox - r, oy - r, ox + r, oy + r], fill=int(150 * (1 - k / 40) ** 1.2))
    pale = Image.new("RGB", (W, H), lerp(l, (255, 250, 235), 0.55))
    im = Image.composite(pale, im, glow.filter(ImageFilter.GaussianBlur(10 * ss)))
    # vignette
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    for k in range(30):
        t = k / 30
        vd.rounded_rectangle([t * W * 0.18, t * H * 0.18, W - t * W * 0.18, H - t * H * 0.18],
                             radius=20 * ss, outline=int(110 * (1 - t) ** 2), width=int(W * 0.006) + 1)
    vig = vig.filter(ImageFilter.GaussianBlur(14 * ss))
    im = Image.composite(Image.new("RGB", (W, H), lerp(d, (10, 14, 20), 0.6)), im, vig)
    # inner shadow (light comes from the upper left, so the top and left lips shade the window)
    sh = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(sh)
    sd.rectangle([0, 0, W, 9 * ss], fill=150)
    sd.rectangle([0, 0, 7 * ss, H], fill=120)
    sh = sh.filter(ImageFilter.GaussianBlur(5 * ss))
    im = Image.composite(Image.new("RGB", (W, H), (12, 16, 22)), im, sh)
    im.resize((w * 2, h * 2), Image.LANCZOS).save(path)
    return path


def dial_face(path, w, h, ss=2, day_frac=2 / 3):
    """The cycle dial: a cream DAY scale with minute ticks, then the SURGE in rust with hazard
    hatching. Printed, with a soft glass sheen across the top."""
    W, H = w * ss, h * ss
    im = Image.new("RGB", (W, H), rgb("#F2E6C9"))
    dr = ImageDraw.Draw(im)
    xs = int(W * day_frac)
    # surge segment with hatching
    surge = Image.new("RGB", (W - xs, H), rgb("#B5412B"))
    sdr_ = ImageDraw.Draw(surge)
    step = 26 * ss
    for x in range(-H, W - xs + H, step):
        sdr_.polygon([(x, H), (x + step // 2, H), (x + step // 2 + H, 0), (x + H, 0)], fill=rgb("#9A3624"))
    im.paste(surge, (xs, 0))
    dr.rectangle([xs - 2 * ss, 0, xs + 2 * ss, H], fill=rgb("#1B2A3A"))
    # day ticks: 3 minutes in 15 s steps, majors on the minute (time runs left to right)
    n = 12
    for i in range(n + 1):
        x = int((xs - 24 * ss) * i / n) + 12 * ss
        major = i % 4 == 0
        th = (H * 0.42) if major else (H * 0.24)
        dr.rectangle([x - (2 if major else 1) * ss, H - th - 6 * ss, x + (2 if major else 1) * ss, H - 6 * ss],
                     fill=rgb("#1B2A3A"))
    f = font("Oswald-Bold", int(H * 0.36))
    dr.text((16 * ss, 7 * ss), "DAY", fill=rgb("#1B2A3A"), font=f)
    for i, lab in enumerate(("3", "2", "1")):
        x = int((xs - 24 * ss) * (i * 4) / n) + 12 * ss
        if i:
            dr.text((x + 6 * ss, 7 * ss), lab, fill=rgb("#1B2A3A"), font=font("Oswald-SemiBold", int(H * 0.3)))
    tw = dr.textlength("SURGE", font=f)
    dr.text((xs + (W - xs - tw) / 2, 7 * ss), "SURGE", fill=rgb("#F2E6C9"), font=f)
    # glass sheen on the upper half
    sheen = Image.new("L", (W, H), 0)
    sdr = ImageDraw.Draw(sheen)
    for y in range(int(H * 0.5)):
        sdr.line([(0, y), (W, y)], fill=int(48 * (1 - y / (H * 0.5)) ** 1.5))
    im = Image.composite(Image.new("RGB", (W, H), (255, 255, 255)), im, sheen)
    im.resize((w * 2, h * 2), Image.LANCZOS).save(path)
    return path


def seismo_paper(path, w, h, ss=2):
    W, H = w * ss, h * ss
    im = Image.new("RGB", (W, H), rgb("#F4EBD3"))
    dr = ImageDraw.Draw(im)
    for x in range(0, W, 10 * ss):
        dr.line([(x, 0), (x, H)], fill=rgb("#C9D9CF") if (x // (10 * ss)) % 5 else rgb("#9DBFAF"), width=ss)
    for y in range(H // 2 % (10 * ss), H, 10 * ss):
        dr.line([(0, y), (W, y)], fill=rgb("#C9D9CF"), width=ss)
    dr.line([(0, H // 2), (W, H // 2)], fill=rgb("#7FA897"), width=2 * ss)
    im.resize((w * 2, h * 2), Image.LANCZOS).save(path)
    return path


def grid_tile(path, size=64, paper="#23476B", line="#4F78A0"):
    """Blueprint paper, one cell; tile it (ScaleType Tile) for the side-view mini-map."""
    im = Image.new("RGBA", (size, size), rgb(paper) + (255,))
    dr = ImageDraw.Draw(im)
    dr.line([(0, 0), (size, 0)], fill=rgb(line) + (255,), width=2)
    dr.line([(0, 0), (0, size)], fill=rgb(line) + (255,), width=2)
    for k in (1, 2, 3):
        p = size * k // 4
        dr.line([(p, 0), (p, size)], fill=rgb(line) + (110,), width=1)
        dr.line([(0, p), (size, p)], fill=rgb(line) + (110,), width=1)
    im.save(path)
    return path


def glass(path, size=256, r_frac=0.41):
    """Gauge glass: a crescent reflection at the upper left and a faint tint."""
    S = size * 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    r = S * r_frac
    c = S / 2
    tint = Image.new("L", (S, S), 0)
    ImageDraw.Draw(tint).ellipse([c - r, c - r, c + r, c + r], fill=10)
    cres = Image.new("L", (S, S), 0)
    cd = ImageDraw.Draw(cres)
    cd.ellipse([c - r * 0.92, c - r * 0.92, c + r * 0.92, c + r * 0.92], fill=72)
    cd.ellipse([c - r * 0.80 + r * 0.16, c - r * 0.80 + r * 0.22, c + r * 0.80 + r * 0.16 + r * 0.1,
                c + r * 0.80 + r * 0.22 + r * 0.1], fill=0)
    cres = cres.filter(ImageFilter.GaussianBlur(S * 0.012))
    alpha = ImageChops.add(tint, cres)
    im.putalpha(alpha)
    white = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    white.putalpha(alpha)
    white.resize((size, size), Image.LANCZOS).save(path)
    return path


def stamp(path, text, colour, w=256, h=128, rot=-7, seed=3):
    """A rubber stamp: double border, condensed caps, uneven ink."""
    S = 3
    W, H = w * S, h * S
    ink = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(ink)
    m = 14 * S
    dr.rounded_rectangle([m, m, W - m, H - m], radius=12 * S, outline=255, width=6 * S)
    dr.rounded_rectangle([m + 11 * S, m + 11 * S, W - m - 11 * S, H - m - 11 * S], radius=6 * S,
                         outline=255, width=2 * S)
    size = int(H * 0.42)
    f = font("Oswald-Bold", size)
    while dr.textlength(text, font=f) > W - 2 * m - 34 * S and size > 10:
        size -= 2
        f = font("Oswald-Bold", size)
    tw = dr.textlength(text, font=f)
    bbox = dr.textbbox((0, 0), text, font=f)
    dr.text(((W - tw) / 2, (H - (bbox[3] - bbox[1])) / 2 - bbox[1]), text, fill=255, font=f)
    # uneven ink: speckled gaps and a lighter patch
    rnd = random.Random(seed)
    noise = Image.new("L", (W // 6, H // 6), 255)
    nd = noise.load()
    for y in range(H // 6):
        for x in range(W // 6):
            nd[x, y] = 255 if rnd.random() > 0.16 else rnd.randint(40, 160)
    noise = noise.resize((W, H), Image.BILINEAR)
    ink = ImageChops.multiply(ink, noise)
    patch = Image.new("L", (W, H), 255)
    ImageDraw.Draw(patch).ellipse([W * 0.55, -H * 0.3, W * 1.2, H * 0.7], fill=170)
    ink = ImageChops.multiply(ink, patch.filter(ImageFilter.GaussianBlur(20 * S)))
    ink = ink.rotate(rot, resample=Image.BICUBIC, expand=False)
    col = Image.new("RGBA", (W, H), rgb(colour) + (0,))
    col.putalpha(ink.point(lambda v: int(v * 0.92)))
    col.resize((w, h), Image.LANCZOS).save(path)
    return path
