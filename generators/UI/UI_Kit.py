"""The themed UI kit, A0 sample (bible Section 18; STYLE.md section 3).

Steadfast Shelter Co., 1958: enamel-painted steel panels with chrome bezels and rivets,
cream catalog cards, Bakelite and enamel push-buttons with real pressed states, stamped
steel tab plates, gauge faces and needles, flip-counter tiles, a radio-dial cycle strip,
telegram strips, pilot lamps and stamps.

Each piece renders to ui/sprites/<Name>.png at 2x its 1080p size. SPECS below records each
piece's 9-slice margins (left, top, right, bottom, in sprite pixels) or None for pieces
that only scale uniformly. tools/pack_ui.py packs the sprites into atlases and writes
ui/kit.json.

Run:  python3 generators/UI/UI_Kit.py [Name ...]     (no names: every piece)
"""
import bpy  # noqa: F401
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import uikit as K  # noqa: E402
import uiprint as P  # noqa: E402
from uikit import C, RARITY, mat, shade_hex, mix_hex  # noqa: E402

SPECS: dict = {}       # name -> {"size": [w, h], "slice": [l, t, r, b] | None, "note": str}
PIECES: dict = {}      # name -> function that builds and renders it


def piece(name, w, h, slice_=None, note=""):
    def deco(fn):
        SPECS[name] = {"size": [w, h], "slice": slice_, "note": note}
        PIECES[name] = (fn, w, h)
        return fn
    return deco


def register(name, w, h, slice_, note, fn):
    SPECS[name] = {"size": [w, h], "slice": slice_, "note": note}
    PIECES[name] = (fn, w, h)


# ------------------------------------------------------------------------------------------
# Panels
# ------------------------------------------------------------------------------------------

def enamel_panel(colour):
    """192 px: chrome bezel with corner rivets around an enamel plate."""
    def build():
        W = 178
        K.rr_ring(W, W, 30, 15, 0, 11, mat("chrome"), bevel=6.5, seg=5)
        K.rr_slab(W - 26, W - 26, 17, 0, 6.5, mat("enamel", colour), bevel=1.4, seg=2)
        d = W / 2 - 30 + (30 - 7.5) * math.cos(math.radians(45))
        for sx in (-1, 1):
            for sy in (-1, 1):
                K.rivet(sx * d, sy * d, 11, 4.6)
    return build


for _n, _c, _note in (("Panel_Teal", C["teal"], "Frame cabinet, headers"),
                      ("Panel_Navy", C["navy"], "HUD instrument housings, dark cabinets"),
                      ("Panel_Cream", C["cream"], "light enamel panels")):
    register(_n, 192, 192, [60, 60, 60, 60], _note, enamel_panel(_c))


@piece("Well_Teal", 160, 160, [44, 44, 44, 44], "recessed content well (zone C)")
def well():
    W = 150
    K.rr_ring(W, W, 20, 6, 0, 7, mat("chrome", rough=0.16), bevel=2.4, seg=3)
    K.rr_slab(W - 10, W - 10, 15, 0, 1.0, mat("enamel", C["well"], rough=0.5, coat=0.4), bevel=0.4, seg=1)


@piece("Paper", 160, 160, [44, 44, 44, 44], "cream catalog card: detail panel, lists")
def paper():
    W = 150
    K.rr_slab(W, W, 10, 0, 2.2, mat("paper", C["paper"]), bevel=0.9, seg=2)
    ink = mat("ink", C["ink"])
    K.rr_ring(W - 18, W - 18, 6, 2.2, 2.2, 2.45, ink)
    K.rr_ring(W - 27, W - 27, 3, 1.1, 2.2, 2.45, ink)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box(5.5, 5.5, 2.2, 2.45, ink, cx=sx * (W / 2 - 13.5), cy=sy * (W / 2 - 13.5), rot=45)


@piece("Plate_Cream", 256, 96, [56, 40, 56, 40], "nameplate for screen titles")
def plate_cream():
    K.rr_ring(244, 84, 16, 7, 0, 9, mat("chrome"), bevel=3.2, seg=4)
    K.rr_slab(232, 72, 10, 0, 6, mat("enamel", C["cream"]), bevel=1.2, seg=2)
    for sx in (-1, 1):
        K.screw(sx * 102, 0, 6, 6.5, rot=35 * sx)


# ------------------------------------------------------------------------------------------
# Push-buttons: enamel caps in chrome bezels. Up sits proud and throws a shadow; Down sits
# almost flush and darker; Hover is a touch lighter; Disabled is grey and flush.
# ------------------------------------------------------------------------------------------

def push_button(colour, state):
    def build():
        K.rr_ring(182, 102, 28, 10, 0, 9, mat("chrome"), bevel=4.0, seg=4)
        K.rr_slab(166, 86, 19, 0, 4, mat("rubber", "#15181B"), bevel=0)   # dark gap under the cap
        cap = {"Up": colour, "Hover": shade_hex(colour, 1.12), "Down": shade_hex(colour, 0.82),
               "Disabled": "#8E8C88"}[state]
        top = {"Up": 19.0, "Hover": 19.0, "Down": 10.5, "Disabled": 10.5}[state]
        K.rr_slab(158, 78, 16, 0, top, mat("enamel", cap, rough=0.3), bevel=5.5, seg=5)
    return build


for _c, _hex in (("Signal", C["signal"]), ("Teal", C["teal"]), ("Leaf", C["leaf"]), ("Rust", C["rust"])):
    for _s in (("Up", "Hover", "Down", "Disabled") if _c == "Signal" else ("Up", "Down")):
        register(f"Button_{_c}_{_s}", 192, 112, [50, 50, 50, 50],
                 {"Signal": "main action (Buy, Equip, Claim)", "Teal": "secondary actions",
                  "Leaf": "vote yes", "Rust": "vote no, danger"}[_c], push_button(_hex, _s))


def close_button(state):
    def build():
        K.annulus(58, 45, 0, 10, K.mat("chrome"), bevel=4.0, seg=4, n=72)
        K.disc(46, 0, 4, mat("rubber", "#15181B"), n=72)
        top = 20.0 if state == "Up" else 11.5
        cap = C["rust"] if state == "Up" else shade_hex(C["rust"], 0.82)
        K.disc(43, 0, top, mat("enamel", cap, rough=0.3), bevel=6, seg=5, n=72)
        arm, half = 23.0, 5.8
        pts = [(half, half), (half, arm), (-half, arm), (-half, half), (-arm, half), (-arm, -half),
               (-half, -half), (-half, -arm), (half, -arm), (half, -half), (arm, -half), (arm, half)]
        c45 = math.cos(math.radians(45))
        pts = [(x * c45 - y * c45, x * c45 + y * c45) for x, y in pts]
        K.poly(pts, top - 1, top + 3.5, mat("enamel", C["cream"], rough=0.3), bevel=1.6, seg=2)
    return build


for _s in ("Up", "Down"):
    register(f"Close_{_s}", 128, 128, None, "close button: red enamel push-button with a cross",
             close_button(_s))


# ------------------------------------------------------------------------------------------
# Tabs: stamped steel plates. On = teal enamel inlay (bible: teal for tabs).
# ------------------------------------------------------------------------------------------

def tab(state):
    def build():
        K.rr_slab(214, 100, 12, 0, 6, mat("steel", rough=0.38), bevel=2.0, seg=3)
        K.rr_ring(184, 80, 9, 5, 6, 8.6, mat("steel", rough=0.3), bevel=2.0, seg=3, cx=10)
        if state == "On":
            K.rr_slab(176, 72, 6, 6, 7.2, mat("enamel", C["teal"]), bevel=0.8, seg=2, cx=10)
        for sy in (-1, 1):
            K.screw(-92, sy * 30, 6, 5.5, rot=20 + 40 * sy)
    return build


for _s in ("Off", "On"):
    register(f"Tab_{_s}", 224, 112, [60, 50, 50, 50], "tab rail plate (zone B)", tab(_s))


# ------------------------------------------------------------------------------------------
# Small parts
# ------------------------------------------------------------------------------------------

def lamp(kind):
    def build():
        K.annulus(21, 14, 0, 7, mat("chrome"), bevel=2.4, seg=3, n=48)
        if kind == "Off":
            K.dome(0, 0, 4, 14.5, mat("glass_dark", "#3B2420"), flat=0.62)
        else:
            col = {"Orange": C["signal"], "Green": C["shard"], "Red": "#FF4A3A", "Amber": C["hazard"]}[kind]
            K.dome(0, 0, 4, 14.5, mat("glow", col, strength={"Green": 1.1, "Amber": 1.3}.get(kind, 2.2)), flat=0.62)
    return build


for _k in ("Off", "Orange", "Green", "Red", "Amber"):
    register(f"Lamp_{_k}", 48, 48, None, "pilot lamp", lamp(_k))


@piece("Chip_Navy", 160, 80, [40, 36, 40, 36], "resource and currency plate")
def chip():
    K.rr_ring(150, 70, 33, 5, 0, 8, mat("chrome"), bevel=2.2, seg=3)
    K.rr_slab(142, 62, 29, 0, 5.5, mat("enamel", C["navy"]), bevel=1.0, seg=2)


@piece("Chip_Cream", 160, 80, [40, 36, 40, 36], "light plate for prices on cards")
def chip_cream():
    K.rr_ring(150, 70, 33, 5, 0, 8, mat("chrome"), bevel=2.2, seg=3)
    K.rr_slab(142, 62, 29, 0, 5.5, mat("enamel", C["cream"]), bevel=1.0, seg=2)


# ------------------------------------------------------------------------------------------
# Catalog cards, one frame per rarity (1:1.25, bible Section 18). The window shows the
# portrait on a rarity sunburst; the class name, kit line and price sit on the paper below.
# ------------------------------------------------------------------------------------------

WIN_W, WIN_H, WIN_CY = 340, 290, 81      # portrait window (sprite px, centre y from card centre)


def card(rarity):
    def build():
        dark, light, txt = RARITY[rarity]
        K.rr_ring(384, 484, 24, 10, 0, 9, mat("chrome"), bevel=4.0, seg=4)
        K.rr_slab(368, 468, 15, 0, 4, mat("paper", C["paper"]), bevel=0.8, seg=2)
        img = P.sunburst(os.path.join(K.TMP, f"sun_{rarity}.png"), WIN_W, WIN_H, dark, light)
        K.plane_image(img, WIN_W, WIN_H, 4.3, cy=WIN_CY, rough=0.7)
        K.rr_ring(WIN_W + 8, WIN_H + 8, 13, 4.5, 3.6, 6.8, mat("chrome"), bevel=1.6, seg=3, cy=WIN_CY)
        # rarity tag straddling the window's bottom edge
        tx, ty = -172 + 14 + 80, WIN_CY - WIN_H / 2
        K.rr_ring(166, 50, 11, 3.5, 6, 9.5, mat("chrome"), bevel=1.4, seg=3, cx=tx, cy=ty)
        K.rr_slab(160, 44, 9, 6, 9.0, mat("enamel", dark), bevel=1.2, seg=2, cx=tx, cy=ty)
        K.text(rarity.upper(), tx, ty - 1, 9.05, 27, mat("ink", txt), spacing=1.12)
        # printed dotted rule above the price line
        ink = mat("ink", C["ink"])
        for i in range(43):
            K.box(3.2, 3.2, 4, 4.25, ink, cx=-168 + i * 8, cy=-170)
    return build


for _r in RARITY:
    register(f"Card_{_r}", 400, 500, None, f"class card frame, {_r}; window {WIN_W}x{WIN_H} at y {WIN_CY}",
             card(_r))


# ------------------------------------------------------------------------------------------
# Instruments
# ------------------------------------------------------------------------------------------

SWEEP = (225.0, -45.0)        # gauge needle sweep: 270 degrees, clockwise from lower left


def gauge_face(face_hex, label, danger=None, caution=None, trefoil=False, ink_hex=None):
    def build():
        ink = mat("ink", ink_hex or C["ink"])
        K.annulus(124, 104, 0, 14, mat("chrome"), bevel=6.0, seg=5, n=96)
        K.disc(106, 0, 5.5, mat("paper", face_hex), n=96)
        for i in range(41):
            a = SWEEP[0] - 6.75 * i
            major = i % 4 == 0
            ln, wd = (17, 4.2) if major else (9, 2.2)
            r = 95 - ln / 2
            K.box(ln, wd, 5.5, 5.8, ink, cx=r * math.cos(math.radians(a)), cy=r * math.sin(math.radians(a)), rot=a)
        for rng, col in ((danger, C["rust"]), (caution, C["hazard"])):
            if rng:
                K.sector(97, 86, rng[0], rng[1], 5.5, 5.75, mat("ink", col), n=32)
        if trefoil:
            cy = -40
            for k in range(3):
                a = 90 + 120 * k
                K.sector(19, 6.5, a - 30, a + 30, 5.5, 5.8, ink, cy=cy, n=12)
            K.disc(4.2, 5.5, 5.8, ink, cy=cy, n=24)
            K.text(label, 0, -72, 5.8, 21, ink, fontname="Oswald-SemiBold", spacing=1.15)
        else:
            K.text(label, 0, -50, 5.8, 24, ink, fontname="Oswald-SemiBold", spacing=1.15)
    return build


register("Gauge_Health", 256, 256, None, "health gauge face: needle sweep 225 to -45 degrees",
         gauge_face(C["cream"], "HEALTH", danger=(SWEEP[0] - 54, SWEEP[0])))
register("Gauge_Stamina", 256, 256, None, "stamina gauge face",
         gauge_face(C["mint"], "STAMINA", caution=(SWEEP[0] - 40.5, SWEEP[0])))
register("Gauge_Rad", 256, 256, None, "radiation gauge face",
         gauge_face(C["hazard"], "RADS", danger=(SWEEP[1], SWEEP[1] + 67.5), trefoil=True))


@piece("Gauge_Needle", 256, 256, None, "gauge needle, pivot at the centre, points up at Rotation 0")
def needle():
    body = [(0, 92), (3.2, 72), (6.5, 0), (5.5, -24), (-5.5, -24), (-6.5, 0), (-3.2, 72)]
    K.poly(body, 9, 11.5, mat("enamel", C["navy"]), bevel=0.8, seg=2)
    K.poly([(0, 92), (3.2, 72), (4.0, 62), (-4.0, 62), (-3.2, 72)], 11.4, 12.2, mat("enamel", C["signal"]))
    K.dome(0, 0, 11, 12.5, mat("metal", C["brass"]), flat=0.55)
    K.dome(0, 0, 15.5, 4.5, mat("chrome"), flat=0.6)


@piece("Flip_Tile", 96, 128, None, "flip-counter tile (year): digit drawn live on top")
def flip_tile():
    K.rr_slab(86, 58, 9, 0, 8, mat("rubber", "#2C3036", rough=0.45), bevel=3.0, seg=3, cy=29.5)
    K.rr_slab(86, 58, 9, 0, 8, mat("rubber", "#202327", rough=0.45), bevel=3.0, seg=3, cy=-29.5)
    for sx in (-1, 1):
        K.box(6, 10, 0, 7, mat("chrome"), cx=sx * 44, cy=0, bevel=1.2, seg=2)


@piece("Dial_Cycle", 768, 112, None, "cycle dial: DAY 3:00 then SURGE 1:30; face spans x 18..750")
def dial():
    face = P.dial_face(os.path.join(K.TMP, "dial.png"), 732, 82)
    K.rr_ring(756, 100, 20, 9, 0, 9.5, mat("chrome"), bevel=3.8, seg=4)
    K.rr_slab(742, 86, 12, 0, 2.5, mat("rubber", "#15181B"))
    K.plane_image(face, 732, 82, 2.6, rough=0.5)


@piece("Dial_Pointer", 48, 128, None, "cycle dial pointer: slides along the face, tip at the bottom")
def dial_pointer():
    K.poly([(-15, 58), (15, 58), (0, 34)], 12, 15, mat("enamel", C["signal"]), bevel=1.0, seg=2)
    K.box(4, 92, 12, 13.5, mat("enamel", C["signal"]), cy=-12)
    K.dome(0, 52, 15, 4, mat("chrome"), flat=0.6)


@piece("Telegram", 256, 128, [72, 40, 72, 40], "telegram strip: vote banner, alerts")
def telegram():
    pts = [(-108, 46), (108, 46)]
    for i in range(10):
        pts.append((108 + (6 if i % 2 == 0 else 0), 46 - (i + 1) * 9.2))
    pts.append((-108, -46))
    for i in range(10):
        pts.append((-108 - (6 if i % 2 == 0 else 0), -46 + (i + 1) * 9.2))
    pts = pts[:-1]
    K.poly(pts, 0, 2.0, mat("paper", C["paper"]), bevel=0.6, seg=1)
    K.box(214, 12, 2.0, 2.2, mat("ink", C["teal"]), cy=33)
    K.box(214, 2, 2.0, 2.2, mat("ink", C["ink"]), cy=-36)


def hotbar(selected):
    def build():
        if selected:
            K.rr_ring(116, 116, 20, 9, 0, 10, mat("enamel", C["signal"], rough=0.3), bevel=3.5, seg=4)
            K.rr_ring(98, 98, 12, 2.4, 2.5, 3.4, mat("glow", C["signal"], strength=2.5))
        else:
            K.rr_ring(116, 116, 20, 9, 0, 10, mat("chrome"), bevel=3.5, seg=4)
        K.rr_slab(100, 100, 13, 0, 2.5, mat("rubber", "#2A2E33", rough=0.7))
        K.rr_slab(28, 24, 6, 2.5, 6.5, mat("enamel", C["cream"]), bevel=1.0, seg=2, cx=-30, cy=30)
    return build


register("Hotbar_Slot", 128, 128, None, "hotbar socket; number plate at the top left", hotbar(False))
register("Hotbar_Selected", 128, 128, None, "selected hotbar socket", hotbar(True))


@piece("Ability_Button", 160, 160, None, "class ability push-button (Bakelite); icon on top")
def ability_button():
    K.annulus(76, 62, 0, 10, mat("chrome"), bevel=4.0, seg=4, n=80)
    K.disc(63, 0, 4, mat("rubber", "#15181B"), n=80)
    K.disc(60, 0, 18, mat("enamel", C["navy"], rough=0.25), bevel=7, seg=5, n=80)


@piece("Seismograph", 384, 128, None, "Disturbance seismograph; paper spans x 14..346, pen at x 330")
def seismograph():
    pap = P.seismo_paper(os.path.join(K.TMP, "seismo.png"), 330, 94)
    K.rr_ring(372, 116, 16, 9, 0, 9.5, mat("chrome"), bevel=3.6, seg=4)
    K.rr_slab(356, 100, 9, 0, 2.5, mat("rubber", "#15181B"))
    K.plane_image(pap, 330, 94, 2.6, cx=-4, rough=0.8)
    K.box(22, 40, 0, 15, mat("chrome"), cx=170, bevel=2.5, seg=3)
    K.box(30, 4, 14, 16, mat("metal", C["brass"]), cx=150)
    K.dome(136, 0, 15, 4, mat("enamel", C["navy"]), flat=0.7)


# ------------------------------------------------------------------------------------------
# Icons: 128 px, real objects in the kit's materials. Tilted ones are 3D objects seen from
# above and in front; flat ones are stamped badges.
# ------------------------------------------------------------------------------------------

def prism(r, h, tip, m, n=6):
    import bmesh
    bm = bmesh.new()
    bot = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), 0)) for i in range(n)]
    top = [bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), h)) for i in range(n)]
    apex = bm.verts.new((0, 0, h + tip))
    bm.faces.new(list(reversed(bot)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
        bm.faces.new((top[i], top[j], apex))
    ob = K._finish(bm, "Prism", m, 0, 1, 0.5)
    for p_ in ob.data.polygons:
        p_.use_smooth = False
    return ob


def rock(r, m, seed=1, subdiv=1, jitter=0.22, scale=(1, 1, 0.7)):
    import bmesh
    import random
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    for v in bm.verts:
        v.co *= 1 + rnd.uniform(-jitter, jitter)
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
    ob = K._finish(bm, "Rock", m, 0, 1, 0.5)
    for p_ in ob.data.polygons:
        p_.use_smooth = False
    return ob


def lathe(profile, m, n=48):
    """profile: [(radius, z), ...] from bottom to top, around Z."""
    import bmesh
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-4:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z))
                          for i in range(n)])
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            for i in range(n):
                bm.faces.new((a[0], b[i], b[(i + 1) % n]))
        elif len(b) == 1:
            for i in range(n):
                bm.faces.new((a[i], a[(i + 1) % n], b[0]))
        else:
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((a[i], a[j], b[j], b[i]))
    return K._finish(bm, "Lathe", m, 0, 1, 0.5)


def place(ob, loc=(0, 0, 0), rot=(0, 0, 0)):
    ob.location = loc
    ob.rotation_euler = tuple(math.radians(a) for a in rot)
    return ob


def icon(name, note, tilt=0.0):
    def deco(fn):
        def build():
            fn()
        register(name, 128, 128, None, note, build)
        TILT[name] = tilt
        return fn
    return deco


TILT: dict = {}


@icon("Icon_Glowshard", "Glowshards (premium currency)", tilt=34)
def ic_glowshard():
    gm = mat("glow", "#3FBF73", emit=C["shard"], strength=1.7)
    rock(30, mat("rubber", C["basalt"], rough=0.8), seed=4, scale=(1.25, 1.0, 0.45))
    for (x, y, rx, ry, r, h, t) in ((0, 0, 0, 0, 13, 44, 16), (-17, 4, 0, -24, 9, 28, 11), (16, -3, 4, 26, 10, 32, 12),
                                     (4, 15, -22, 6, 7, 20, 8)):
        place(prism(r, h, t, gm), (x, y, 2), (rx, ry, 15))


@icon("Icon_Power", "Power", tilt=0)
def ic_power():
    pts = [(8, 54), (-24, -2), (-3, -2), (-14, -54), (25, 8), (4, 8), (19, 54)]
    K.poly([(x * 1.12, y * 1.08) for x, y in pts], 0, 4, mat("enamel", C["navy"]), bevel=1.0, seg=1)
    K.poly(pts, 4, 13, mat("enamel", C["hazard"], rough=0.3), bevel=2.6, seg=3)


@icon("Icon_Food", "Food", tilt=20)
def ic_food():
    K.disc(30, 0, 56, mat("chrome", rough=0.22), n=48)
    for z in (3, 53):
        K.annulus(31.2, 27, z - 2.6, z + 2.6, mat("chrome", rough=0.18), bevel=1.6, seg=2, n=48)
    K.disc(30.8, 6, 50, mat("enamel", C["signal"]), n=48)
    K.disc(31.0, 19, 37, mat("enamel", C["cream"]), n=48)
    K.disc(26.5, 56, 57.2, mat("chrome", rough=0.3), n=48)


@icon("Icon_Water", "Water", tilt=0)
def ic_water():
    # teardrop: tip at the top, circle below; the arc runs from the right tangent point
    # clockwise round the bottom to the left one
    tip, cy, r = 54.0, -12.0, 34.0
    th = math.degrees(math.acos(r / (tip - cy)))
    a0, a1 = 90 - th, 90 + th - 360
    pts = [(0, tip)] + [(r * math.cos(math.radians(a0 + (a1 - a0) * i / 28)),
                         cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / 28))) for i in range(29)]
    K.poly([(x * 1.1, y * 1.07 - 1) for x, y in pts], 0, 4, mat("enamel", C["navy"]), bevel=1.0, seg=1)
    K.poly(pts, 4, 22, mat("enamel", "#4E9CCB", rough=0.1, coat=1.0), bevel=12, seg=6)


@icon("Icon_Scrap", "Scrap", tilt=30)
def ic_scrap():
    st = mat("steel", rough=0.3)
    K.annulus(34, 13, 0, 14, st, bevel=2.0, seg=2, n=40)
    for i in range(10):
        a = 360 * i / 10
        K.box(15, 13, 0, 14, st, cx=39 * math.cos(math.radians(a)), cy=39 * math.sin(math.radians(a)), rot=a,
              bevel=2.0, seg=2)
    hexn = K.circ_pts(14, 6, 26, -24, a0=0.3)
    K.ring(hexn, K.circ_pts(6.5, 6, 26, -24, a0=0.3), 0, 26, mat("metal", C["brass"]), bevel=1.6, seg=2)


@icon("Icon_Iron", "Iron ore", tilt=30)
def ic_iron():
    rock(42, mat("rubber", "#7A3E2A", rough=0.85), seed=7, scale=(1.1, 0.95, 0.62))
    for (x, y, z, r, sd) in ((-14, -16, 20, 11, 3), (16, -10, 18, 9, 5), (2, 12, 24, 8, 8), (-24, 8, 12, 6, 2)):
        place(rock(r, mat("metal", "#C9CFD4", rough=0.28), seed=sd, subdiv=0, scale=(1, 1, 0.8)), (x, y, z))


@icon("Icon_Ammo", "Ammo", tilt=62)
def ic_ammo():
    for x, y in ((-15, 8), (15, -6)):
        ob = lathe([(0, 0), (12, 0), (12, 2), (10.5, 3), (11.5, 4.5), (11.5, 44), (10.5, 46), (0, 46)],
                   mat("metal", C["brass"], rough=0.2))
        place(ob, (x, y, 0))
        tip = lathe([(10.4, 0), (10.4, 6), (9.0, 12), (6.5, 17), (3.0, 21), (0, 22)], mat("metal", C["copper"], rough=0.25))
        place(tip, (x, y, 46))


@icon("Icon_Command", "Command View (the bunker in section)", tilt=0)
def ic_command():
    cr = mat("enamel", C["cream"], rough=0.3)
    K.poly([(-46, 30), (46, 30), (40, 40), (-40, 40)], 0, 6, cr, bevel=1.2, seg=1)
    for row in range(3):
        for col in range(3):
            if col == 1:
                continue
            K.rr_slab(30, 18, 3, 0, 8, cr, cx=-31 + col * 31, cy=16 - row * 24, bevel=1.2, seg=1)
    K.box(10, 76, 0, 8, mat("enamel", C["hazard"]), cy=-6, bevel=1.2, seg=1)
    K.box(100, 5, 0, 5, cr, cy=-50)


@icon("Icon_Shield", "Security ability: Hold the Line", tilt=0)
def ic_shield():
    def shield(s):
        pts = [(-40, 46), (40, 46), (40, 6)]
        for i in range(1, 12):
            t = i / 12
            pts.append((40 * math.cos(t * math.pi / 2), 6 - 52 * math.sin(t * math.pi / 2) ** 1.4))
        pts.append((0, -50))
        for i in range(11, 0, -1):
            t = i / 12
            pts.append((-40 * math.cos(t * math.pi / 2), 6 - 52 * math.sin(t * math.pi / 2) ** 1.4))
        pts.append((-40, 6))
        return [(x * s, y * s) for x, y in pts]
    K.poly(shield(1.0), 0, 9, mat("metal", C["brass"], rough=0.22), bevel=2.6, seg=3)
    K.poly(shield(0.78), 9, 10.5, mat("enamel", C["navy"]), bevel=0.8, seg=1)
    star = []
    for i in range(10):
        r = 22 if i % 2 == 0 else 9
        a = math.radians(90 + 36 * i)
        star.append((r * math.cos(a), r * math.sin(a) + 2))
    K.poly(star, 10.5, 15, mat("metal", C["brass"], rough=0.2), bevel=1.4, seg=2)


WHITE = "#EEEDE8"


@icon("Icon_Tag", "tab: today's shop (white, tint with ImageColor3)", tilt=0)
def ic_tag():
    pts = [(-30, 22), (40, 22), (40, -22), (-30, -22), (-52, 0)]
    c, s_ = math.cos(math.radians(-28)), math.sin(math.radians(-28))
    pts = [(x * c - y * s_, x * s_ + y * c) for x, y in pts]
    K.poly(pts, 0, 10, mat("enamel", WHITE), bevel=2.4, seg=3)
    hx, hy = -30 * c, -30 * s_
    K.annulus(7.5, 4, 10, 12.5, mat("chrome"), cx=hx, cy=hy, n=32, bevel=1.0, seg=2)


@icon("Icon_Check", "tab: owned (white, tint with ImageColor3)", tilt=0)
def ic_check():
    K.poly([(-44, 6), (-28, 22), (-10, 4), (30, 44), (46, 28), (-10, -28)], 0, 12, mat("enamel", WHITE), bevel=3.0, seg=3)


@icon("Icon_Grid", "tab: all (white, tint with ImageColor3)", tilt=0)
def ic_grid():
    for gx in (-1, 1):
        for gy in (-1, 1):
            K.rr_slab(36, 44, 6, 0, 10, mat("enamel", WHITE), cx=gx * 22, cy=gy * 26, bevel=2.0, seg=2)


def alert(shape, colour, mark_colour):
    def build():
        if shape == "triangle":
            pts = []
            for k in range(3):
                a = math.radians(90 + 120 * k)
                cx, cy = 44 * math.cos(a), 44 * math.sin(a) - 8
                for j in range(5):
                    b = a - math.radians(60) + math.radians(120) * j / 4
                    pts.append((cx + 9 * math.cos(b), cy + 9 * math.sin(b)))
            K.poly(pts, 0, 10, mat("enamel", colour), bevel=2.2, seg=3)
            K.text("!", 0, -10, 10.05, 52, mat("ink", mark_colour))
        elif shape == "diamond":
            c45 = math.cos(math.radians(45))
            pts = [(x * c45 - y * c45, x * c45 + y * c45) for x, y in K.rr_pts(70, 70, 10)]
            K.slab(pts, 0, 10, mat("enamel", colour), bevel=2.2, seg=3)
            K.text("!", 0, 0, 10.05, 52, mat("ink", mark_colour))
        else:
            K.disc(46, 0, 10, mat("enamel", colour), bevel=2.2, seg=3, n=64)
            K.text("i", 0, 0, 10.05, 54, mat("ink", mark_colour), fontname="Oswald-Bold")
    return build


register("Alert_Danger", 128, 128, None, "alert: danger (fire, breach): red triangle", alert("triangle", C["rust"], C["cream"]))
register("Alert_Warning", 128, 128, None, "alert: warning: yellow diamond", alert("diamond", C["hazard"], C["navy"]))
register("Alert_Info", 128, 128, None, "alert: info: teal circle", alert("circle", C["teal"], C["cream"]))
for _n in ("Alert_Danger", "Alert_Warning", "Alert_Info"):
    TILT[_n] = 0


# ------------------------------------------------------------------------------------------
# HUD additions (Prompt 6): touch push-buttons, action icons and the other two ores. They pack
# into their own atlas (group "hud") so the approved A0 atlases keep their ids.
# ------------------------------------------------------------------------------------------

HUD_GROUP: list = []


def touch_button(colour, state, size):
    """Round enamel push-button in a chrome bezel; the action's icon sits on the cap."""
    def build():
        r = size / 2 - 4
        K.annulus(r, r - 15, 0, 11, mat("chrome"), bevel=4.5, seg=4, n=96)
        K.disc(r - 14, 0, 4, mat("rubber", "#15181B"), n=96)
        top = 19.0 if state == "Up" else 10.0
        cap = colour if state == "Up" else shade_hex(colour, 0.8)
        K.disc(r - 18, 0, top, mat("enamel", cap, rough=0.25), bevel=8, seg=5, n=96)
    return build


for _s in ("Up", "Down"):
    register(f"Touch_{_s}", 192, 192, None, f"touch button ({_s.lower()}): navy cap, icon on top",
             touch_button(C["navy"], _s, 192))
    register(f"Touch_Fire_{_s}", 256, 256, None, f"touch Fire button ({_s.lower()}): signal cap",
             touch_button(C["signal"], _s, 256))
    HUD_GROUP += [f"Touch_{_s}", f"Touch_Fire_{_s}"]


def rotated(pts, deg, dx=0.0, dy=0.0):
    a = math.radians(deg)
    return [(dx + x * math.cos(a) - y * math.sin(a), dy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]


def hud_icon(name, note, tilt=0.0):
    HUD_GROUP.append(name)
    return icon(name, note, tilt)


def white():
    return mat("enamel", WHITE)


@hud_icon("Icon_Fire", "touch: fire (a cartridge; white, tint with ImageColor3)")
def ic_fire():
    side = [(14 * math.cos(t * math.pi / 2), 6 + 38 * math.sin(t * math.pi / 2) ** 0.75) for t in (i / 12 for i in range(13))]
    pts = [(-14, -34), (14, -34)] + side + [(-x, y) for x, y in reversed(side)][1:]
    K.poly(rotated(pts, -40), 0, 11, white(), bevel=2.4, seg=3)
    K.poly(rotated([(-17, -46), (17, -46), (17, -37), (-17, -37)], -40), 0, 11, white(), bevel=1.6, seg=2)


@hud_icon("Icon_Aim", "touch: aim (a scope ring; white, tint with ImageColor3)")
def ic_aim():
    K.annulus(40, 31, 0, 10, white(), bevel=1.8, seg=2, n=64)
    for a in (0, 90, 180, 270):
        K.box(30, 8, 0, 10, white(), cx=38 * math.cos(math.radians(a)), cy=38 * math.sin(math.radians(a)), rot=a,
              bevel=1.4, seg=2)
    K.disc(6, 0, 10, white(), n=32, bevel=1.0, seg=2)


@hud_icon("Icon_Melee", "touch: melee (a wrench; white, tint with ImageColor3)")
def ic_melee():
    place(K.sector(27, 12, 125, 415, 0, 11, white(), cy=30, n=40, bevel=1.8, seg=2), rot=(0, 0, -45))
    place(K.box(17, 62, 0, 11, white(), cy=-14, bevel=2.0, seg=2), rot=(0, 0, -45))
    place(K.disc(11, 0, 11, white(), cy=-44, n=32, bevel=1.8, seg=2), rot=(0, 0, -45))


@hud_icon("Icon_Interact", "touch: interact (an open hand; white, tint with ImageColor3)")
def ic_interact():
    K.rr_slab(48, 44, 12, 0, 11, white(), cy=-16, bevel=2.0, seg=2)
    for x, h in ((-17.5, 32), (-6, 42), (6, 40), (17.5, 30)):
        K.rr_slab(11, h, 5.4, 0, 11, white(), cx=x, cy=-2 + h / 2, bevel=1.6, seg=2)
    place(K.rr_slab(13, 34, 6.4, 0, 11, white(), cx=0, cy=0, bevel=1.6, seg=2), loc=(-27, -14, 0), rot=(0, 0, 38))


@hud_icon("Icon_Jump", "touch: jump (an arrow up off a line; white, tint with ImageColor3)")
def ic_jump():
    K.poly([(-32, 4), (32, 4), (0, 46)], 0, 11, white(), bevel=2.2, seg=2)
    K.box(18, 34, 0, 11, white(), cy=-10, bevel=1.6, seg=2)
    K.box(66, 10, 0, 11, white(), cy=-42, bevel=1.6, seg=2)


@hud_icon("Icon_Dodge", "touch: dodge (a roll arrow; white, tint with ImageColor3)")
def ic_dodge():
    K.sector(40, 26, 25, 286, 0, 11, white(), n=40, bevel=1.8, seg=2)
    th = math.radians(290)
    rad = (math.cos(th), math.sin(th))
    tan = (-math.sin(th), math.cos(th))
    p = (33 * rad[0], 33 * rad[1])
    head = [(p[0] + 19 * rad[0], p[1] + 19 * rad[1]), (p[0] - 19 * rad[0], p[1] - 19 * rad[1]),
            (p[0] + 26 * tan[0], p[1] + 26 * tan[1])]
    K.poly(head, 0, 11, white(), bevel=2.0, seg=2)


@hud_icon("Icon_Sprint", "touch: sprint (two chevrons; white, tint with ImageColor3)")
def ic_sprint():
    chevron = [(-12, 40), (8, 40), (36, 0), (8, -40), (-12, -40), (16, 0)]
    for dx in (-24, 12):
        K.poly([(x + dx, y) for x, y in chevron], 0, 11, white(), bevel=2.0, seg=2)


@hud_icon("Icon_Ping", "touch: ping (a map pin; white, tint with ImageColor3)")
def ic_ping():
    tip, cy, r = -50.0, 12.0, 30.0
    th = math.degrees(math.acos(r / (cy - tip)))
    a0, a1 = -90 + th, 270 - th
    pts = [(0, tip)] + [(r * math.cos(math.radians(a0 + (a1 - a0) * i / 32)),
                         cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / 32))) for i in range(33)]
    K.poly(pts, 0, 11, white(), bevel=2.4, seg=3)
    K.disc(11, 11, 12.5, mat("enamel", C["navy"]), cy=cy, n=40)


@hud_icon("Icon_Shoulder", "touch: swap shoulder (arrows both ways; white, tint with ImageColor3)")
def ic_shoulder():
    K.box(50, 10, 0, 11, white(), cx=-8, cy=17, bevel=1.4, seg=2)
    K.poly([(16, 34), (16, 0), (44, 17)], 0, 11, white(), bevel=1.8, seg=2)
    K.box(50, 10, 0, 11, white(), cx=8, cy=-17, bevel=1.4, seg=2)
    K.poly([(-16, 0), (-16, -34), (-44, -17)], 0, 11, white(), bevel=1.8, seg=2)


@hud_icon("Icon_Arrow", "screen-edge arrow to a breach (points up; white, tint with ImageColor3)")
def ic_arrow():
    K.poly([(0, 50), (42, -38), (0, -16), (-42, -38)], 0, 12, white(), bevel=2.6, seg=3)


@hud_icon("Icon_Copper", "Copper ore", tilt=30)
def ic_copper():
    rock(42, mat("rubber", C["basalt"], rough=0.85), seed=11, scale=(1.1, 0.95, 0.6))
    for (x, y, z, r, sd) in ((-13, -14, 20, 12, 4), (15, -8, 18, 10, 6), (1, 13, 23, 8, 9), (-25, 9, 11, 6, 3)):
        place(rock(r, mat("metal", C["copper"], rough=0.3), seed=sd, subdiv=0, scale=(1, 1, 0.8)), (x, y, z))
    for (x, y, z, r, sd) in ((24, 10, 12, 5, 2), (-6, -26, 13, 4.5, 5)):
        place(rock(r, mat("enamel", C["mint"], rough=0.7), seed=sd, subdiv=0, scale=(1, 1, 0.6)), (x, y, z))


@hud_icon("Icon_Crystal", "Crystal ore", tilt=34)
def ic_crystal():
    cm = mat("glow", "#5FB9B6", emit=C["crystal"], strength=0.55)
    rock(30, mat("rubber", C["basalt"], rough=0.8), seed=6, scale=(1.25, 1.0, 0.45))
    for (x, y, rx, ry, r, h, t) in ((2, 0, 0, 0, 12, 46, 15), (-16, 5, 0, -26, 9, 30, 11), (17, -4, 5, 24, 9, 34, 12),
                                     (3, 16, -24, 4, 7, 22, 8), (-4, -15, 22, -6, 6, 18, 7)):
        place(prism(r, h, t, cm), (x, y, 2), (rx, ry, 30))


for _n in HUD_GROUP:
    SPECS[_n]["group"] = "hud"


# ------------------------------------------------------------------------------------------
# Printed pieces (no render): stamps, glass, blueprint grid
# ------------------------------------------------------------------------------------------

PRINTED = {
    "Stamp_FreeTrial": (256, 128, lambda p: P.stamp(p, "FREE TRIAL", C["rust"], rot=-7)),
    "Stamp_Owned": (256, 128, lambda p: P.stamp(p, "OWNED", C["teal"], rot=6, seed=5)),
    "Stamp_Wishlist": (256, 128, lambda p: P.stamp(p, "WISHLIST", C["navy"], rot=-5, seed=9)),
    "Gauge_Glass": (256, 256, lambda p: P.glass(p, 256)),
    "Grid_Blueprint": (64, 64, lambda p: P.grid_tile(p)),
}
for _n, (_w, _h, _fn) in PRINTED.items():
    SPECS[_n] = {"size": [_w, _h], "slice": None,
                 "note": {"Gauge_Glass": "glass over every gauge face", "Grid_Blueprint": "tile: ScaleType Tile, mini-map paper"}.get(_n, "ink stamp")}


# ------------------------------------------------------------------------------------------

def fit_icon(tilt, size, fill=0.86):
    """Scale and centre an icon's objects so it fills the frame as the camera sees it, then drop
    the shadow catcher under the lowest point."""
    from mathutils import Matrix, Vector
    bpy.context.view_layer.update()
    obs = [o for o in bpy.context.scene.objects if o.type in ("MESH", "FONT") and o.name != "Catcher"]
    t = math.radians(tilt)
    xs, ys = [], []
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            ys.append(w.y * math.cos(t) + w.z * math.sin(t))
    k = fill * size / max(max(xs) - min(xs), max(ys) - min(ys))
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    move = Matrix.Translation((-cx * k, -cy * k / max(math.cos(t), 0.2), 0)) @ Matrix.Scale(k, 4)
    for o in obs:
        if o.parent is None:
            o.matrix_world = move @ o.matrix_world
    bpy.context.view_layer.update()
    zmin = min((o.matrix_world @ Vector(c)).z for o in obs for c in o.bound_box)
    bpy.data.objects["Catcher"].location.z = zmin - 0.3


def run(names):
    for n in names:
        if n in PRINTED:
            w, h, fn = PRINTED[n]
            p = fn(os.path.join(K.SPRITES, f"{n}.png"))
        else:
            fn, w, h = PIECES[n]
            K.stage(w, h, tilt=TILT.get(n, 0.0))
            fn()
            if n.startswith("Icon_"):
                fit_icon(TILT.get(n, 0.0), w)
            p = K.shoot(n)
        print(f"[UI_Kit] {n} -> {os.path.relpath(p, K.sf.REPO)}")
    spec_path = os.path.join(K.UI, "specs.json")
    old = json.load(open(spec_path)) if os.path.exists(spec_path) else {}
    old.update({n: SPECS[n] for n in SPECS})
    with open(spec_path, "w") as f:
        json.dump(old, f, indent=1, sort_keys=True)


if __name__ == "__main__":
    want = sys.argv[1:] or (list(PIECES) + list(PRINTED))
    run(want)
