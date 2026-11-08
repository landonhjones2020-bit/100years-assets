"""Shared helpers for rendering the themed UI kit in Blender (bible Section 18, STYLE.md 3).

Every kit piece is real geometry rendered straight down through an orthographic camera:
enamel-painted steel, chrome bezels and rivets, Bakelite caps, brushed steel, paper. One
Blender unit is one pixel of the sprite. Sprites are drawn at 2x their size on a 1080p
screen ("@2x"), so they stay sharp on big screens; SliceScale brings them back down.

A soft sun from the upper left casts real shadows (caught on a shadow-catcher plane, so they
land in the PNG's alpha), and a studio environment that only glossy rays see gives chrome its
bright and dark bands.
"""
import bpy  # noqa: F401  (bpy before bmesh)
import bmesh
import math
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import steadfast as sf  # noqa: E402

UI = os.path.join(sf.REPO, "ui")
SPRITES = os.path.join(UI, "sprites")
FONTS = os.path.join(UI, "fonts")
TMP = "/tmp/uikit"
os.makedirs(SPRITES, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

SAMPLES = int(os.environ.get("UI_SAMPLES", "64"))

# Bible Section 18 colours plus the palette swatches.
C = {s: sf.swatch(s)["hex"] for s in sf.SWATCHES if s != sf.TINT}
C.update({"text": "#1B2A3A", "panel": "#F2E6C9", "action": "#E8743B", "warn": "#F2C14E",
          "danger": "#B5412B", "shard": "#7CFF9B", "paper": "#F4EBD3", "teal_dark": "#235457",
          "well": "#1E4547", "ink": "#1B2A3A"})
# Rarity enamels (bible: Common grey, Rare blue, Epic purple, Legendary gold):
# (enamel, light ray, text on the enamel)
RARITY = {"Common": ("#8E8C88", "#B9B6AE", "#1B2A3A"),
          "Rare": ("#3F79B5", "#73A6D8", "#F2E6C9"),
          "Epic": ("#7D4C9E", "#A97FC8", "#F2E6C9"),
          "Legendary": ("#D9A93A", "#F3D27A", "#1B2A3A")}


def lin(h, a=1.0):
    r, g, b = sf.hex_rgb(h)
    return (sf.srgb_to_linear(r), sf.srgb_to_linear(g), sf.srgb_to_linear(b), a)


def mix_hex(h1, h2, t):
    a, b = sf.hex_rgb(h1), sf.hex_rgb(h2)
    return "#" + "".join(f"{round((x + (y - x) * t) * 255):02X}" for x, y in zip(a, b))


def shade_hex(h, k):
    """k < 1 darkens, k > 1 lightens toward white."""
    return mix_hex(h, "#000000", 1 - k) if k <= 1 else mix_hex(h, "#FFFFFF", k - 1)


# ------------------------------------------------------------------------------------------
# Materials
# ------------------------------------------------------------------------------------------

_M: dict = {}


def mat(kind: str, hexc: str | None = None, **kw):
    key = (kind, hexc, tuple(sorted(kw.items())))
    if key in _M and _M[key].name in bpy.data.materials:
        return _M[key]
    m = bpy.data.materials.new(f"{kind}_{hexc}")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]

    def p(name, v):
        b.inputs[name].default_value = v

    base = hexc
    if kind == "enamel":          # painted steel or Bakelite: glossy colour under a clear coat
        p("Roughness", kw.get("rough", 0.34))
        p("Coat Weight", kw.get("coat", 0.85))
        p("Coat Roughness", kw.get("coat_rough", 0.06))
    elif kind == "chrome":
        base = hexc or "#E4E8EB"
        p("Metallic", 1.0)
        p("Roughness", kw.get("rough", 0.12))
    elif kind == "steel":         # brushed: roughness streaks along X
        base = hexc or "#C9D0D5"
        p("Metallic", 1.0)
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (0.02, 1.4, 1.0)
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 6.0
        nz.inputs["Detail"].default_value = 8.0
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["To Min"].default_value = kw.get("rough", 0.36) - 0.08
        mr.inputs["To Max"].default_value = kw.get("rough", 0.36) + 0.1
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
        nt.links.new(nz.outputs["Fac"], mr.inputs["Value"])
        nt.links.new(mr.outputs["Result"], b.inputs["Roughness"])
    elif kind == "metal":         # brass, copper, gunmetal
        p("Metallic", 1.0)
        p("Roughness", kw.get("rough", 0.24))
    elif kind == "paper":
        p("Roughness", 0.9)
        p("Specular IOR Level", 0.25)
    elif kind == "ink":           # printed: flat and matte
        p("Roughness", 0.8)
        p("Specular IOR Level", 0.2)
    elif kind == "rubber":
        p("Roughness", kw.get("rough", 0.62))
    elif kind == "glow":          # lit lamp glass, Glowshards
        p("Roughness", 0.2)
        p("Coat Weight", 0.6)
        p("Emission Color", lin(kw.get("emit", hexc)))
        p("Emission Strength", kw.get("strength", 4.0))
    elif kind == "glass_dark":    # unlit lamp glass
        p("Roughness", 0.08)
        p("Coat Weight", 1.0)
    else:
        raise ValueError(kind)
    p("Base Color", lin(base))
    _M[key] = m
    return m


def mat_image(path: str, rough=0.8, emit=0.0):
    m = bpy.data.materials.new(os.path.basename(path))
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path, check_existing=False)
    tex.interpolation = "Cubic"
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.3
    if emit:
        nt.links.new(tex.outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emit
    return m


# ------------------------------------------------------------------------------------------
# Stage: camera, light, environment, shadow catcher
# ------------------------------------------------------------------------------------------

def _world():
    wd = bpy.data.worlds.new("UIWorld")
    bpy.context.scene.world = wd
    wd.use_nodes = True
    nt = wd.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    L = nt.links.new
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(tc.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    L(sep.outputs["Z"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    L(mr.outputs["Result"], ramp.inputs["Fac"])
    els = ramp.color_ramp.elements
    # Elevation bands: a dark ceiling (flat enamel reflects it and keeps its true colour), a
    # bright strip at the horizon for the bottom lip of every bezel, dim in between.
    stops = [(0.0, 0.02), (0.495, 0.03), (0.505, 0.55), (0.535, 0.30), (0.6, 0.12), (0.75, 0.07),
             (0.88, 0.04), (1.0, 0.03)]
    els[0].position, els[0].color = stops[0][0], (stops[0][1],) * 3 + (1,)
    els[1].position, els[1].color = stops[-1][0], (stops[-1][1],) * 3 + (1,)
    for pos, v in stops[1:-1]:
        e = els.new(pos)
        e.color = (v, v, v, 1)
    sepc = nt.nodes.new("ShaderNodeSeparateColor")
    L(ramp.outputs["Color"], sepc.inputs["Color"])
    total = sepc.outputs["Red"]
    # Soft boxes: key at the upper left (matches the sun), a weaker fill at the upper right
    # and a low rim at the bottom, so chrome shows bright lines and dark bands.
    for vec, lo, hi, strength in (((-0.5, 0.6, 0.62), 0.80, 0.965, 3.2),
                                  ((0.75, 0.35, 0.5), 0.86, 0.975, 1.3),
                                  ((0.0, -0.9, 0.42), 0.88, 0.98, 0.9)):
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        L(tc.outputs["Generated"], dot.inputs[0])
        dot.inputs[1].default_value = tuple(Vector(vec).normalized())
        lobe = nt.nodes.new("ShaderNodeMapRange")
        lobe.inputs["From Min"].default_value = lo
        lobe.inputs["From Max"].default_value = hi
        lobe.inputs["To Max"].default_value = strength
        L(dot.outputs["Value"], lobe.inputs["Value"])
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        L(total, add.inputs[0])
        L(lobe.outputs["Result"], add.inputs[1])
        total = add.outputs[0]
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for ch in ("Red", "Green", "Blue"):
        L(total, comb.inputs[ch])
    gloss = nt.nodes.new("ShaderNodeBackground")
    L(comb.outputs["Color"], gloss.inputs["Color"])
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs["Color"].default_value = (0.30, 0.30, 0.31, 1)
    amb.inputs["Strength"].default_value = 1.0
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    L(lp.outputs["Is Glossy Ray"], mix.inputs[0])
    L(amb.outputs[0], mix.inputs[1])
    L(gloss.outputs[0], mix.inputs[2])
    L(mix.outputs[0], out.inputs["Surface"])


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def stage(w: int, h: int, *, tilt: float = 0.0, sun: float = 2.6, shadow=True, samples=None):
    """Fresh scene with a w x h orthographic camera. tilt (degrees) leans the camera so it
    looks down at (90 - tilt) degrees from the front, for icons of 3D objects."""
    sf.reset()
    _M.clear()
    _FONT_CACHE.clear()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples or SAMPLES
    sc.cycles.use_denoising = True
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    _world()
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(w, h)
    cam.clip_start = 1
    cam.clip_end = 5000
    co = link(bpy.data.objects.new("Cam", cam))
    t = math.radians(tilt)
    co.location = (0, -1500 * math.sin(t), 1500 * math.cos(t))
    co.rotation_euler = (t, 0, 0)
    sc.camera = co
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = sun
    ld.angle = math.radians(7)
    so = link(bpy.data.objects.new("Sun", ld))
    so.rotation_euler = Vector((-0.45, 0.55, 1.0)).to_track_quat("Z", "Y").to_euler()
    if shadow:
        me = bpy.data.meshes.new("Catcher")
        s = max(w, h) * 3
        me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
        cat = link(bpy.data.objects.new("Catcher", me))
        cat.is_shadow_catcher = True
    return sc


def shoot(name: str) -> str:
    p = os.path.join(SPRITES, f"{name}.png")
    bpy.context.scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    return p


# ------------------------------------------------------------------------------------------
# Geometry (1 unit = 1 sprite pixel; +Y is up in the image)
# ------------------------------------------------------------------------------------------

def rr_pts(w, h, r, seg=10, cx=0.0, cy=0.0):
    """Rounded rectangle outline, counter-clockwise, seg+1 points per corner."""
    r = max(0.6, min(r, w / 2 - 0.01, h / 2 - 0.01))
    pts = []
    for qx, qy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90),
                       (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + qx + r * math.cos(a), cy + qy + r * math.sin(a)))
    return pts


def circ_pts(r, n=48, cx=0.0, cy=0.0, a0=0.0):
    return [(cx + r * math.cos(a0 + 2 * math.pi * i / n), cy + r * math.sin(a0 + 2 * math.pi * i / n))
            for i in range(n)]


def _finish(bm, name, m, bevel, seg, profile, angle=50):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    me.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = True
    if bevel > 0:
        md = ob.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = seg
        md.limit_method = "ANGLE"
        md.angle_limit = math.radians(angle)
        md.profile = profile
        md.harden_normals = True
        md.miter_outer = "MITER_ARC"
        md.use_clamp_overlap = True
    return ob


def slab(pts, z0, z1, m, *, bevel=0.0, seg=3, profile=0.5, name="Slab"):
    """Extrude a CCW outline from z0 to z1."""
    bm = bmesh.new()
    bot = [bm.verts.new((x, y, z0)) for x, y in pts]
    top = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return _finish(bm, name, m, bevel, seg, profile)


def ring(outer, inner, z0, z1, m, *, bevel=0.0, seg=3, profile=0.5, name="Ring"):
    """A frame between two CCW outlines with the same number of points."""
    assert len(outer) == len(inner), (len(outer), len(inner))
    bm = bmesh.new()
    ob_ = [bm.verts.new((x, y, z0)) for x, y in outer]
    ot = [bm.verts.new((x, y, z1)) for x, y in outer]
    ib = [bm.verts.new((x, y, z0)) for x, y in inner]
    it = [bm.verts.new((x, y, z1)) for x, y in inner]
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((ob_[j], ob_[i], ib[i], ib[j]))
        bm.faces.new((ob_[i], ob_[j], ot[j], ot[i]))
        bm.faces.new((ib[j], ib[i], it[i], it[j]))
    return _finish(bm, name, m, bevel, seg, profile)


def rr_slab(w, h, r, z0, z1, m, cx=0.0, cy=0.0, **kw):
    return slab(rr_pts(w, h, r, cx=cx, cy=cy), z0, z1, m, **kw)


def rr_ring(w, h, r, width, z0, z1, m, cx=0.0, cy=0.0, **kw):
    return ring(rr_pts(w, h, r, cx=cx, cy=cy),
                rr_pts(w - 2 * width, h - 2 * width, max(r - width, 1.0), cx=cx, cy=cy), z0, z1, m, **kw)


def disc(r, z0, z1, m, cx=0.0, cy=0.0, n=64, **kw):
    return slab(circ_pts(r, n, cx, cy), z0, z1, m, **kw)


def annulus(r_out, r_in, z0, z1, m, cx=0.0, cy=0.0, n=64, **kw):
    return ring(circ_pts(r_out, n, cx, cy), circ_pts(r_in, n, cx, cy), z0, z1, m, **kw)


def sector(r_out, r_in, a_from, a_to, z0, z1, m, cx=0.0, cy=0.0, n=24, **kw):
    """Annular sector between angles a_from..a_to (degrees, counter-clockwise from +X)."""
    if a_to < a_from:
        a_from, a_to = a_to, a_from
    angs = [math.radians(a_from + (a_to - a_from) * i / n) for i in range(n + 1)]
    pts = [(cx + r_out * math.cos(a), cy + r_out * math.sin(a)) for a in angs]
    pts += [(cx + r_in * math.cos(a), cy + r_in * math.sin(a)) for a in reversed(angs)]
    return slab(pts, z0, z1, m, **kw)


def box(w, h, z0, z1, m, cx=0.0, cy=0.0, rot=0.0, **kw):
    pts = [(w / 2, h / 2), (-w / 2, h / 2), (-w / 2, -h / 2), (w / 2, -h / 2)]
    a = math.radians(rot)
    pts = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    return slab(pts, z0, z1, m, **kw)


def poly(pts, z0, z1, m, **kw):
    """Any simple polygon; points are made counter-clockwise."""
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
               for i in range(len(pts)))
    if area < 0:
        pts = list(reversed(pts))
    return slab(pts, z0, z1, m, **kw)


def dome(x, y, z, r, m, flat=0.55, segs=24):
    me = bpy.data.meshes.new("Dome")
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=r)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new("Dome", me))
    ob.location = (x, y, z)
    ob.scale = (1, 1, flat)
    me.materials.append(m)
    for poly_ in me.polygons:
        poly_.use_smooth = True
    return ob


def rivet(x, y, z, r=4.5, m=None):
    return dome(x, y, z, r, m or mat("chrome"), flat=0.6)


def screw(x, y, z, r=6.0, rot=30.0):
    dome(x, y, z, r, mat("chrome"), flat=0.45)
    box(r * 1.5, r * 0.32, z + r * 0.2, z + r * 0.48, mat("ink", "#2A2E33"), cx=x, cy=y, rot=rot)


_FONT_CACHE: dict = {}


def font(name: str):
    f = _FONT_CACHE.get(name)
    try:
        alive = f is not None and f.name in bpy.data.fonts
    except ReferenceError:
        alive = False
    if not alive:
        f = bpy.data.fonts.load(os.path.join(FONTS, name + ".ttf"))
        _FONT_CACHE[name] = f
    return f


def text(s, x, y, z, size, m, fontname="Oswald-Bold", depth=0.0, align="CENTER",
         spacing=1.0, rot=0.0, bevel=0.0):
    cu = bpy.data.curves.new("Text", "FONT")
    cu.body = s
    cu.font = font(fontname)
    cu.size = size
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.space_character = spacing
    ob = link(bpy.data.objects.new("Text", cu))
    ob.location = (x, y, z)
    ob.rotation_euler = (0, 0, math.radians(rot))
    cu.materials.append(m)
    return ob


def plane_image(path, w, h, z, cx=0.0, cy=0.0, rough=0.8, emit=0.0):
    me = bpy.data.meshes.new("Img")
    me.from_pydata([(cx - w / 2, cy - h / 2, z), (cx + w / 2, cy - h / 2, z),
                    (cx + w / 2, cy + h / 2, z), (cx - w / 2, cy + h / 2, z)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    for i, c in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[i].uv = c
    ob = link(bpy.data.objects.new("Img", me))
    me.materials.append(mat_image(path, rough=rough, emit=emit))
    return ob
