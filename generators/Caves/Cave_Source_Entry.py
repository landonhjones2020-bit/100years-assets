"""Cave_Source_Entry: the Source Chamber (A10; bible Section 6: floor 10, "A living cavern around the
Source", never built on; Section 3: "Miners there found a glowing mass deep underground that
changed every living thing near it. Steadfast knew, and built anyway."). The band's one cave
piece: the rock face that replaces a floor 10 cell's back wall, the last yards of the old
Brightwater mine's gallery, and where the gallery breaks through: a ledge high in the wall of a
hall 72 studs across, 90 deep and 28 high, with a ramp of rock down to its floor. The hall's walls
are dark red rock grown through with roots as thick as a resident, ribs of bone arch over where
the Source sits, veins of its light run up every wall to a web on the roof, and the eyes in the
rock are open when you come in.

The hall is sunk under the gallery (its floor is D studs lower, its roof no higher than the
gallery's), so the whole piece stays inside floor 10's own height: caves on floor 9 can lie over
it, and the planner never has to refuse the chamber its place (2026-11-12).

The Source (Boss_Source) stands on the Core socket and its tendrils can rise at Tendril1 to 4; the
floor is flat and clear between them. Sockets: Entry, Core (yaw 180: it faces the way in),
Tendril1..4, Light1..5 (Light1 is the miners' lantern in the gallery; the rest are the chamber's
own glow). The planner treats it as the band's Entry with no way on.

Run:  SF_EXPORT=1 python3 generators/Caves/Cave_Source_Entry.py
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, HERE)
import cavelib as C  # noqa: E402
import cavedress  # noqa: E402
from cavelib import bx, sf, t, uid  # noqa: E402
from Kit_Rubble import lump, slab_chunk  # noqa: E402
import bmesh  # noqa: E402  (after bpy, which cavelib brings in)

ASSET = "Cave_Source_Entry"
BUDGET = 15000   # one piece the size of three: the band has no other
D = 16           # the hall's floor is this far under the gallery's
HC = 12          # both ceilings: an opening's height, so nothing stands over floor 10's own cell
FLOOR = -D
TOP = 16.3       # no rock above this (the planner's box ends at 16.5)
GALLERY = (-7, 7, -14, 0)
HALL = (-36, 36, -104, -14)
LEDGE = (-10, 10, -22, -14)     # where the miners broke through, level with the gallery
RAMP = (-8, 8, -50, -22)        # from the ledge's lip down to the hall's floor
CORE = (0.0, -78.0)

C.BANDS["Source"] = {"rock": "rust", "dark": "rubber", "floor": "basalt", "wall": "rubber", "ceiling": "rubber"}
C.BAND_ID["Source"] = "SourceChamber"
C.LAYOUTS["Sanctum"] = dict(
    rects=[GALLERY, HALL], h=HC, drop=D, weight=0, plate=True,
    openings=[("+Y", 0, 0)],
    sockets={"Core": ((CORE[0], CORE[1], FLOOR), 180),
             "Tendril1": ((-22, -46, FLOOR), 180), "Tendril2": ((22, -46, FLOOR), 180),
             "Tendril3": ((-26, -92, FLOOR), 180), "Tendril4": ((26, -92, FLOOR), 180),
             "Light1": (0, -5, 10.4), "Light2": (-22, -40, 6.0), "Light3": (22, -40, 6.0),
             "Light4": (-20, -88, 6.0), "Light5": (20, -88, 6.0)})


def tube(points, radii, swatch, sides=6, resolution=2, part="Decor", **kw):
    return t(sf.tube([tuple(p) for p in points], radii, sides=sides, resolution=resolution), part, swatch, **kw)


def vein(points, r=0.16):
    return tube(points, [r * 0.6] + [r] * (len(points) - 2) + [r * 0.5], "glow", sides=3, resolution=1, part="DecorNeon",
                mat="Neon", cast_shadow=False)


def wall_eye(at, facing, r, rnd):
    """An eye in the rock: a dark socket, the Source's light, a slit, and a brow of rock over it."""
    f = sf.Vector(facing).normalized()
    at = sf.Vector(at)
    lump("Decor", tuple(at - f * r * 0.7), r * 1.7, rnd.randint(0, 10 ** 6), segs=6, rings=4, swatch="rubber")
    ball = sf.sphere(r, loc=at, segs=8, rings=5)
    t(ball, "DecorNeon", "glow", mat="Neon", cast_shadow=False)
    slit = sf.sphere(1.0, loc=at + f * r * 0.86, scale=(r * 0.2, r * 0.2, r * 0.78), segs=5, rings=4)
    slit.rotation_euler = f.to_track_quat("Y", "Z").to_euler()
    t(slit, "Decor", "rubber")
    side = f.cross(sf.Vector((0, 0, 1))).normalized()
    for sgn, sw in ((1, "rust"), (-1, "basalt")):                       # lids of rock, half open
        lid = sf.sphere(r * 1.12, loc=at + sf.Vector((0, 0, sgn * r * 0.62)) + f * r * 0.12, scale=(1.0, 1.0, 0.5), segs=6, rings=3)
        lid.rotation_euler = side.to_track_quat("X", "Z").to_euler()
        t(lid, "Decor", sw, smooth_angle=None)


def down(o):
    """A piece made resting on z = 0 goes to the hall's floor."""
    o.location.z += FLOOR
    return o


def dress(shell, rnd):
    cavedress.plate(shell, "Source")
    cx, cy0 = CORE

    # ---- the last yards of the old mine: what the miners left when they broke through
    C.lantern(0, -5, 10.4, "Mines")
    C.timber_frame(-3.2, HC, leaning=3.0)
    C.timber_frame(-9.6, HC, leaning=-5.0)
    C.rails(0.0, -20.5)
    C.ore_cart(-6.4, -19.4, rot=38, tipped=True)
    C.steadfast_board(4.9, -9.2, 3.4, w=4.2, h=2.2, rot=-8)
    C.rad_sign(-5.2, -7.4, rot=10)
    C.hard_hat(2.6, -12.0, rot=40)
    C.hard_hat(6.2, -19.0, rot=-25)
    C.crate_stack(5.2, -3.6, n=2, size=2.2, seed=3)

    # ---- the ledge and the ramp: rock heaped against them, so neither reads as a block
    x0, x1, y0, y1 = RAMP
    for sx in (-1, 1):
        for k in range(5):
            k_ = (k + 0.5) / 5
            y = y1 + (y0 - y1) * k_
            top = -D * k_
            lump("Decor", (sx * (x1 + 1.6 + rnd.uniform(-0.4, 0.8)), y, top - 2.2), rnd.uniform(2.6, 3.6), rnd.randint(0, 10 ** 6),
                 segs=5, rings=4, swatch=("basalt", "rubber", "rust")[k % 3])
        for (lx, ly, lz, r) in ((11.4, -19.5, -3.5, 4.0), (10.6, -16.0, -10.5, 4.4), (12.0, -22.5, -12.0, 3.8)):
            lump("Decor", (sx * lx, ly, lz), r, rnd.randint(0, 10 ** 6), segs=5, rings=4, swatch="rubber" if lz < -8 else "basalt")
    for k in range(4):                                                                     # the ramp's foot runs out into rubble
        down(lump("Decor", (rnd.uniform(-9, 9), y0 - rnd.uniform(0.5, 3.0), 0), rnd.uniform(0.7, 1.5), rnd.randint(0, 10 ** 6),
                  segs=5, rings=4, swatch="basalt", resting=True))

    # ---- ribs: five pairs of bone arching over where it sits, open at the top like a chest
    for k, y in enumerate((-36, -53, -70, -87, -101)):
        lean = (k - 2) * 1.3
        for sx in (-1, 1):
            pts = [(sx * 32.5, y, FLOOR - 0.5), (sx * 33.5, y + lean * 0.3, FLOOR + 8.4), (sx * 29.0, y + lean * 0.7, FLOOR + 17.7),
                   (sx * 20.5, y + lean, FLOOR + 23.9), (sx * 12.0, y + lean, FLOOR + 25.8)]
            tube(pts, [1.9, 1.7, 1.35, 0.95, 0.4], "cream", sides=6, resolution=1)
            lump("Decor", (sx * 32.2, y, FLOOR + 0.6), 2.6, rnd.randint(0, 10 ** 6), segs=6, rings=4, swatch="basalt")   # where it leaves the floor

    # ---- the mound it grows out of: a ring of its own flesh round the Core (the middle is the Source's)
    for k in range(18):
        a = math.tau * k / 18 + rnd.uniform(-0.1, 0.1)
        rx, ry = 15.5 + rnd.uniform(-1.0, 1.6), 13.0 + rnd.uniform(-0.8, 1.4)
        if math.sin(a) < -0.8:
            continue                                                                       # open at its front (toward the mine): it looks out that way
        down(lump("Decor", (cx + math.cos(a) * rx, cy0 - math.sin(a) * ry, 0), rnd.uniform(2.0, 3.2), rnd.randint(0, 10 ** 6), segs=6, rings=4,
                  swatch=("plum", "basalt", "plum", "rubber")[k % 4], resting=True))

    # ---- roots: from the mound out over the floor and up the walls
    ends = [(-35.0, -30.0), (-35.0, -58.0), (-35.0, -86.0), (-24.0, -103.0), (-6.0, -103.0), (10.0, -103.0), (26.0, -103.0), (35.0, -88.0),
            (35.0, -60.0), (35.0, -32.0)]
    for k, (ex, ey) in enumerate(ends):
        d = sf.Vector((ex - cx, ey - cy0, 0))
        n = sf.Vector((-d.y, d.x, 0)).normalized()
        start = sf.Vector((cx, cy0, FLOOR)) + d.normalized() * 15.0
        bend = rnd.uniform(-5, 5)
        mid = start + (sf.Vector((ex, ey, FLOOR)) - start) * 0.5 + n * bend
        foot = sf.Vector((ex, ey, FLOOR + 0.4))
        up1 = sf.Vector((ex * 1.0, ey * 1.0, FLOOR + 9.0 + rnd.uniform(-2, 3)))
        up2 = sf.Vector((ex * 0.985, ey * 0.99, FLOOR + 18.0 + rnd.uniform(-2, 4)))
        sw = "plum" if k % 2 else "basalt"
        tube([start + sf.Vector((0, 0, 0.9)), mid + sf.Vector((0, 0, 0.5)), foot, up1, up2], [2.3, 1.9, 1.6, 1.15, 0.5], sw, sides=6, resolution=1)
        vein([start + sf.Vector((0, 0, 3.0)), mid + sf.Vector((0, 0, 2.35)), foot + sf.Vector((0, 0, 1.9)) - d.normalized() * 1.2,
              up1 - d.normalized() * 1.25, up2 - d.normalized() * 0.7], r=0.2)
        if k % 2 == 0:                                                                     # sacs where a root meets the wall
            for j in range(3):
                at = (foot.x - d.normalized().x * (2.2 + j * 1.3) + n.x * (1.6 - j), foot.y - d.normalized().y * (2.2 + j * 1.3) + n.y * (1.6 - j), 0)
                down(lump("Decor", at, rnd.uniform(1.0, 1.6), rnd.randint(0, 10 ** 6), segs=6, rings=4, swatch="blush" if j % 2 == 0 else "plum",
                          resting=True))
    for sx in (-1, 1):                                                                     # two have grown up the ramp to the mine: they found the way out first
        pts = [(sx * 10.5, cy0 + 17.0, FLOOR + 0.8), (sx * 12.0, y0 - 2.0, FLOOR + 0.6), (sx * 9.4, (y0 + y1) / 2, -D / 2 + 0.7),
               (sx * 9.2, y1, 0.7), (sx * 8.0, -15.5, 3.2), (sx * 6.9, -10.5, 8.2)]
        tube(pts, [1.8, 1.5, 1.2, 1.0, 0.75, 0.3], "plum" if sx > 0 else "basalt", sides=6, resolution=1)
        vein([(p[0] - sx * 0.2, p[1], p[2] + r) for p, r in zip(pts, (1.7, 1.45, 1.2, 1.0, 0.75, 0.35))], r=0.18)

    # ---- the web on the roof: every vein in the chamber runs to the point over its eye
    hub = sf.Vector((cx, cy0, HC - 0.6))
    for k in range(12):
        a = math.tau * k / 12 + rnd.uniform(-0.15, 0.15)
        far = sf.Vector((cx + math.cos(a) * rnd.uniform(26, 34), cy0 + math.sin(a) * rnd.uniform(22, 34), HC - 0.5))
        far.x = max(HALL[0] + 1.0, min(HALL[1] - 1.0, far.x))
        far.y = max(HALL[2] + 1.0, min(HALL[3] - 1.0, far.y))
        m1 = hub + (far - hub) * 0.35 + sf.Vector((rnd.uniform(-2, 2), rnd.uniform(-2, 2), -rnd.uniform(0.2, 0.9)))
        m2 = hub + (far - hub) * 0.7 + sf.Vector((rnd.uniform(-2.5, 2.5), rnd.uniform(-2.5, 2.5), -rnd.uniform(0.1, 0.6)))
        vein([hub, m1, m2, far], r=0.26)
    for k in range(5):                                                                     # and hangs down toward it
        a = math.tau * k / 5 + 0.3
        top = hub + sf.Vector((math.cos(a) * 3.2, math.sin(a) * 3.2, 0.2))
        tube([top, top + sf.Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, -4.5)), top + sf.Vector((math.cos(a) * -0.4, math.sin(a) * -0.4, -8.5 - k * 0.6))],
             [0.9, 0.6, 0.22], "plum" if k % 2 else "basalt", sides=5, resolution=2)
    t(sf.sphere(2.2, loc=tuple(hub + sf.Vector((0, 0, 0.3))), scale=(1.0, 1.0, 0.5), segs=9, rings=5), "DecorNeon", "glow", mat="Neon", cast_shadow=False)
    C.stalactites(rnd, HALL, HC, 12, swatch="plum")

    # ---- eyes in the rock
    for at, facing, r in (((-35.0, -34.0, -7.5), (1, 0, 0), 1.7), ((-35.0, -62.0, -1.0), (1, 0.1, -0.2), 2.3), ((-35.0, -92.0, -9.5), (1, 0.2, 0), 1.4),
                          ((35.0, -42.0, -3.0), (-1, 0, -0.15), 2.0), ((35.0, -70.0, -9.0), (-1, 0.1, 0), 1.6), ((35.0, -95.0, 1.0), (-1, 0.2, -0.3), 1.9),
                          ((-17.0, -103.0, -5.0), (0.15, 1, -0.1), 2.1), ((15.0, -103.0, -9.0), (-0.1, 1, 0), 1.5), ((0.0, -103.0, 4.5), (0, 1, -0.3), 2.6),
                          ((-26.0, -15.0, -1.0), (0.3, -1, -0.2), 1.6), ((27.0, -15.0, -6.5), (-0.3, -1, 0), 1.8)):
        wall_eye(at, facing, r, rnd)

    # ---- veins up the walls between the roots
    for k in range(10):
        side = rnd.choice(("-X", "+X", "-Y"))
        if side == "-Y":
            x, y, nx, ny = rnd.uniform(-30, 30), HALL[2] + 0.7, 0, 1
        else:
            x, y = (-35.3 if side == "-X" else 35.3), rnd.uniform(HALL[2] + 4, HALL[3] - 4)
            nx, ny = (1 if side == "-X" else -1), 0
        pts = []
        for j, z in enumerate((1.0, 8.0, 15.0, 22.0, 26.8)):
            w = rnd.uniform(-2.2, 2.2)
            pts.append((x + (w if ny else 0) + nx * rnd.uniform(0.0, 0.5), y + (w if nx else 0) + ny * rnd.uniform(0.0, 0.5), FLOOR + z))
        vein(pts, r=0.2)
    for k in range(12):                                                                    # rubble on the hall's floor, clear of the ramp and the Source
        x, y = rnd.uniform(-31, 31), rnd.uniform(HALL[2] + 4, HALL[3] - 4)
        if abs(x) < 11 and y > RAMP[2] - 4:
            x = math.copysign(rnd.uniform(13, 30), x or 1)
        if math.hypot(x - cx, y - cy0) < 19:
            continue
        down(lump("Decor", (x, y, 0), rnd.uniform(0.5, 1.2), rnd.randint(0, 10 ** 6), segs=5, rings=4, swatch="rubber", resting=True))


class SourceShell(C.Shell):
    """The chamber's rock: dark, with the Source's red through it (the bunker kit's Source rock)."""

    def rock(self, loc, r, swatch=None):
        self.rocks += 1
        k = self.rnd.random()
        pick = swatch or ("rubber" if k < 0.42 else "basalt" if k < 0.72 else "rust")
        return lump("Decor", loc, r, self.rnd.randint(0, 10 ** 6), segs=getattr(self, "segs", 5), rings=getattr(self, "rings", 4), swatch=pick)

    def collision(self):
        """A level gallery, then a hall sunk D under it: floors, walls and roofs as boxes, the ledge a
        block and the ramp one solid wedge (a hull), so nobody gets under it."""
        b = self.band
        gx0, gx1, gy0, gy1 = GALLERY
        hx0, hx1, hy0, hy1 = HALL
        bx(uid("Floor"), b["floor"], (gx1 - gx0, gy1 - gy0, 1), (0, (gy0 + gy1) / 2, -0.5), collision="box")
        bx(uid("Ceiling"), b["ceiling"], (gx1 - gx0, gy1 - gy0, 1), (0, (gy0 + gy1) / 2, HC + 0.5), collision="box")
        bx(uid("Floor"), b["floor"], (hx1 - hx0, hy1 - hy0, 1), (0, (hy0 + hy1) / 2, FLOOR - 0.5), collision="box")
        bx(uid("Ceiling"), b["ceiling"], (hx1 - hx0, hy1 - hy0, 1), (0, (hy0 + hy1) / 2, HC + 0.5), collision="box")
        self.walls = C._cut(C._runs(self.layout["rects"]), self.layout["openings"])
        for (side, fixed, a, c) in self.walls:
            nx, ny = C.NORMAL[side]
            mx, my = C._along(side, fixed, (a + c) / 2)
            z0 = 0 if self.in_gallery(side, fixed) else FLOOR
            size = (c - a, 1, HC - z0) if side in ("+Y", "-Y") else (1, c - a, HC - z0)
            bx(uid("Wall"), b["wall"], size, (mx + nx * 0.5, my + ny * 0.5, (HC + z0) / 2), collision="box")
        bx(uid("Wall"), b["wall"], (gx1 - gx0, 1, D), (0, hy1 + 0.5, FLOOR / 2), collision="box")           # the rock under the gallery's mouth
        lx0, lx1, ly0, ly1 = LEDGE
        bx("Ledge", b["floor"], (lx1 - lx0, ly1 - ly0, D), (0, (ly0 + ly1) / 2, FLOOR / 2), collision="box")
        rx0, rx1, ry0, ry1 = RAMP
        bm = bmesh.new()
        v = [bm.verts.new(p) for p in ((rx0, ry1, 0), (rx1, ry1, 0), (rx1, ry1, FLOOR), (rx0, ry1, FLOOR), (rx0, ry0, FLOOR), (rx1, ry0, FLOOR))]
        for face in ((0, 1, 2, 3), (0, 4, 5, 1), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2)):
            bm.faces.new([v[i] for i in face])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        t(sf.from_bmesh(bm, "Ramp"), "Ramp", b["floor"], collision="hull", smooth_angle=None)

    @staticmethod
    def in_gallery(side, fixed):
        return side in ("+X", "-X") and abs(fixed) == GALLERY[1]


def wall_rocks(shell, walls, spacing, rmin, rmax, step, z0, top):
    """Boulders over these walls, their inner faces on the wall line (cavelib's own rule, a size per wall)."""
    rnd = shell.rnd
    for (side, fixed, a, c) in walls:
        nx, ny = C.NORMAL[side]
        n = max(1, int(round((c - a) / spacing)))
        for k in range(n + 1):
            s_ = a + (c - a) * k / n
            z = z0 + rmax * 0.55
            while z < top + 0.5:
                r = rnd.uniform(rmin, rmax)
                x, y = C._along(side, fixed, s_ + rnd.uniform(-0.6, 0.6))
                out = r * rnd.uniform(0.5, 0.62)
                shell.rock((x + nx * out, y + ny * out, min(z, TOP - r)), r)
                z += r * step


def roof(shell):
    """Sheared slabs over the hall and the gallery, and rock hanging through them: all under TOP."""
    rnd = shell.rnd
    x0, x1, y0, y1 = HALL
    nx, ny = 6, 8
    for i in range(nx):
        for j in range(ny):
            w, d = (x1 - x0) / nx, (y1 - y0) / ny
            at = (x0 + w * (i + 0.5) + rnd.uniform(-1, 1), y0 + d * (j + 0.5) + rnd.uniform(-1, 1), HC + 1.5 + rnd.uniform(-0.5, 0.6))
            slab_chunk("Decor", ("rubber", "basalt", "rubber", "rust")[(i * 3 + j) % 4], (w * 1.12, d * 1.12, 2.6), at,
                       (rnd.uniform(-5, 5), rnd.uniform(-5, 5), rnd.uniform(-8, 8)), rnd.randint(0, 10 ** 6))
    for k in range(26):
        r = rnd.uniform(2.4, 3.2)
        shell.rock((rnd.uniform(x0 + 3, x1 - 3), rnd.uniform(y0 + 3, y1 - 3), HC + r * 0.35), r)
    for k in range(4):
        r = rnd.uniform(2.6, 3.2)
        shell.rock((rnd.uniform(-4.5, 4.5), -1.5 - k * 3.4, HC + r * 0.4), r)


def shot(name, at, look, fov, layout):
    """One view from inside, lit by the chamber's own green."""
    import bpy
    from mathutils import Vector
    made = []
    for key, value in layout["sockets"].items():
        if key.startswith("Light"):
            ld = bpy.data.lights.new(key, type="POINT")
            ld.energy = 900 if key == "Light1" else 5200
            ld.color = (1.0, 0.78, 0.45) if key == "Light1" else (0.5, 1.0, 0.62)
            ld.shadow_soft_size = 0.5
            ob = bpy.data.objects.new(key, ld)
            bpy.context.scene.collection.objects.link(ob)
            ob.location = Vector(value) - Vector((0, 0, 0.9))
            made.append(ob)
    ld = bpy.data.lights.new("EyeLight", type="POINT")                  # where the Source's eye will be
    ld.energy, ld.color = 7000, (0.5, 1.0, 0.62)
    ob = bpy.data.objects.new("EyeLight", ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector((CORE[0], CORE[1] + 7, FLOOR + 7))
    made.append(ob)
    cd = bpy.data.cameras.new("PreviewCam")
    cd.angle = math.radians(fov)
    cam = bpy.data.objects.new("PreviewCam", cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = Vector(at)
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    made.append(cam)
    out = os.path.join(sf.REPO, "previews", "Caves", name)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
    return out


def preview(layout):
    """What a player sees: from the gallery's end over the ledge, and from the hall's floor back at it."""
    import bpy
    from mathutils import Vector
    objs = sf._tagged_objects()
    built = sf._build_export_meshes(objs, Vector((0, 0, 0)), "room")
    for o in objs:
        o.hide_render = True
    sf._setup_render(900, 28)
    bpy.context.scene.render.resolution_y = 560
    world = bpy.context.scene.world.node_tree
    world.nodes["Background"].inputs[1].default_value = 0.04
    world.nodes["SF_CamBG"].inputs[0].default_value = (0.0, 0.0, 0.0, 1)
    outs = [shot(f"{ASSET}_inside.png", (0.0, -12.5, 6.4), (0.0, CORE[1], FLOOR + 7.0), 84, layout),
            shot(f"{ASSET}_floor.png", (-27.0, -97.0, FLOOR + 5.5), (6.0, -30.0, FLOOR + 9.0), 84, layout)]
    for b in built:
        bpy.data.objects.remove(b["obj"], do_unlink=True)
    for o in objs:
        o.hide_render = False
    return outs


def build():
    C.R.reset_ids()
    layout = dict(C.LAYOUTS["Sanctum"])
    rnd = random.Random(2526)
    shell = SourceShell("Source", layout, 2526)
    shell.collision()
    shell.segs, shell.rings = 5, 4
    gallery = [w for w in shell.walls if shell.in_gallery(w[0], w[1])]
    hall = [w for w in shell.walls if w not in gallery]
    wall_rocks(shell, gallery, 3.6, 2.0, 2.9, 1.45, 0, HC)              # the mine's gallery: a tunnel's rock
    wall_rocks(shell, hall, 9.5, 4.6, 6.8, 1.6, FLOOR, HC)              # the chamber's: great blocks
    roof(shell)
    dress(shell, rnd)
    sockets = {"Entry": ((0, 0, 0), 180)}
    sockets.update(layout["sockets"])
    meta = {"band": C.BAND_ID["Source"], "kind": "Entry", "weight": 0, "box": C.box_of(layout)}
    if os.environ.get("SF_NORENDER") != "1":
        print(f"[{ASSET}] inside: {preview(layout)}")
    return {"export": {"budget": BUDGET, "merge": "room", "pivot": (0, 0, 0), "step": "A10", "sockets": sockets, "meta": meta}}


if __name__ == "__main__":
    sf.run_main(build, ASSET, "Caves")
