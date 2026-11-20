"""Voxel Sea Companions (6 species x 3 stages) and Cursed Fruits (6), same voxel style as the monsters.

  python tools/blender/voxel_pets.py -- --out assets/models3d --preview [--only Gull_2,Fruit_Blaze]
Outputs <Species>_<stage>.glb and Fruit_<Id>.glb (the names AssetService already loads into Assets.Pets / Assets.Fruits).
Pets are cute (big shiny eyes, round shapes); every stage adds gear so evolutions read at a glance. Face -Y, stand on z=0.
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401
import gvkit as K
import voxel as V
from voxel import Grid
from voxel_monsters import Painter, rgb, shade, WHITE, BLACK

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv

GOLD = rgb(255, 205, 60)
STEEL = rgb(176, 186, 204)
PINK = rgb(255, 140, 170)


def cute_eyes(P, cx, y, z, gap, size=1.0, color=BLACK):
    """big round chibi eyes: dark 3x3-ish block with two white highlights, plus blush"""
    for sx in (-1, 1):
        P.box((cx + sx * gap, y, z), (1.4 * size, 0.6, 1.7 * size), color, 0)
        P.box((cx + sx * gap + 0.5 * size, y - 0.4, z + 0.7 * size), (0.5 * size, 0.4, 0.5 * size), WHITE, 0)
        P.box((cx + sx * gap - 0.5 * size, y - 0.4, z - 0.8 * size), (0.3 * size, 0.4, 0.3 * size), WHITE, 0)
        P.box((cx + sx * (gap + 2.2 * size), y + 0.2, z - 1.8 * size), (0.9 * size, 0.4, 0.5 * size), PINK, 0)


# ---------------------------------------------------------------- pets
def hermit(st):
    g = Grid(52, 48, 50)
    P = Painter(g)
    cx, cy = 26, 26
    body = rgb(255, 110, 84)
    shell = [rgb(246, 218, 168), rgb(222, 178, 120), rgb(196, 168, 140)][st - 1]
    P.ell((cx, cy - 3, 7), (9, 7, 5.5), body)
    k = [1.0, 1.25, 1.5][st - 1]
    for sx in (-1, 1):
        g.set_part("Leg" + ("L" if sx < 0 else "R"))
        for j in range(3):
            P.tube([(cx + sx * 7, cy - 4 + j * 3, 5), (cx + sx * 12, cy - 4 + j * 3, 6), (cx + sx * 14, cy - 5 + j * 3, 0.5)], [1.1, 0.9, 0.7], shade(body, 0.85))
        g.set_part("Arm" + ("L" if sx < 0 else "R"))
        P.tube([(cx + sx * 6, cy - 8, 7), (cx + sx * 10, cy - 13, 8)], [1.4, 1.8 * k], body)
        P.ell((cx + sx * 11, cy - 15, 9), (3.5 * k, 3.8 * k, 3.0 * k), shade(body, 1.1))
        P.box((cx + sx * 11.5, cy - 19 * (0.9 + 0.1 * k), 10), (1.2 * k, 1.8 * k, 0.8 * k), shade(body, 1.25))
        if st == 3:
            P.box((cx + sx * 11, cy - 13, 9), (3.6, 0.8, 3.2), GOLD, 0)
        # eye stalks
        g.set_part("Body")
        P.tube([(cx + sx * 3, cy - 8, 10), (cx + sx * 3.5, cy - 9, 15)], [0.7, 0.6], body)
        P.ball((cx + sx * 3.5, cy - 9.5, 16.5), 2.3, WHITE, 0)
        P.box((cx + sx * 3.5, cy - 11.4, 16.6), (1.1, 0.5, 1.3), BLACK, 0)
        P.box((cx + sx * 3.1, cy - 11.9, 17.3), (0.4, 0.3, 0.4), WHITE, 0)
    P.box((cx, cy - 10, 6), (2.0, 0.4, 0.6), shade(body, 0.5), 0)
    # shell on the back: spiral of stacked rings
    for j in range(5):
        r = 9.0 - j * 1.6
        P.ball((cx, cy + 6, 11 + j * 3.0), r, shell if j % 2 == 0 else shade(shell, 0.85))
    if st >= 2:
        for j in range(8):
            a = j / 8 * math.tau
            P.tube([(cx + math.cos(a) * 7.5, cy + 6 + math.sin(a) * 7.5, 13), (cx + math.cos(a) * 10.5, cy + 6 + math.sin(a) * 10.5, 16)], [1.2, 0.3], shade(shell, 0.55))
    if st == 3:
        # the castle on top: tower + crenellations + flag
        P.box((cx, cy + 6, 30), (5.0, 5.0, 5.0), rgb(214, 200, 176))
        for j in range(4):
            for sx in (-1, 1):
                P.box((cx + sx * 4, cy + 2 + j * 2.6, 36.2), (1.0, 0.9, 1.2), rgb(214, 200, 176), 0)
        P.box((cx, cy - 1.2, 29), (1.4, 0.4, 2.2), rgb(70, 50, 40), 0)
        P.box((cx, cy + 6, 41), (0.4, 0.4, 5.0), rgb(110, 76, 46), 0)
        P.box((cx + 2.4, cy + 6, 44), (2.2, 0.3, 1.4), rgb(230, 50, 70), 0)
    g.bake_ao(0.2)
    return g


def boarlet(st):
    g = Grid(40, 56, 40)
    P = Painter(g)
    cx = 20
    fur = [rgb(214, 150, 110), rgb(160, 104, 70), rgb(110, 92, 86)][st - 1]
    P.ell((cx, 32, 12), (9, 12, 8.5), fur)
    P.ell((cx, 31, 9), (7, 9, 4.5), shade(fur, 1.2))
    for sx in (-1, 1):
        for yy in (24, 40):
            g.set_part("Leg" + ("F" if yy < 30 else "B") + ("L" if sx < 0 else "R"))
            P.box((cx + sx * 5, yy, 3.5), (2.4, 2.6, 3.5), shade(fur, 0.7))
            P.box((cx + sx * 5, yy - 0.6, 0.8), (2.6, 3.0, 0.8), shade(fur, 0.4))
    g.set_part("Body")
    P.rbox((cx, 17, 16), (8, 7.5, 7.5), fur, 2.6)
    P.rbox((cx, 9.8, 13.5), (4.2, 1.8, 3.0), rgb(250, 170, 160), 1.0)
    for sx in (-1, 1):
        P.box((cx + sx * 1.6, 8.0, 13.6), (0.6, 0.3, 0.8), shade(fur, 0.4), 0)
        tusk = [1.4, 2.6, 3.6][st - 1]
        P.tube([(cx + sx * 3.6, 10, 11.5), (cx + sx * 4.6, 9, 11.5 + tusk)], [0.7, 0.3], WHITE)
        P.box((cx + sx * 6, 18, 23.5), (1.5, 1.2, 2.0), shade(fur, 0.75))
    cute_eyes(P, cx, 9.8, 18.5, gap=3.6, size=0.9)
    P.tube([(cx, 44, 14), (cx + 2, 46, 16), (cx, 47, 18), (cx - 1.5, 46, 16.5)], [0.6, 0.6, 0.6, 0.5], shade(fur, 0.8))
    if st >= 2:
        for k in range(8):
            P.box((cx, 22 + k * 2.6, 21.5 - k * 0.3), (0.9, 1.0, 2.0), rgb(70, 50, 40), 0)
    if st == 3:
        P.rbox((cx, 32, 19.5), (9.6, 10, 2.0), STEEL, 0.8)  # back armor
        P.rbox((cx, 15.5, 23), (7.5, 5, 1.5), STEEL, 0.6)  # helmet plate
        for sx in (-1, 1):
            P.tube([(cx + sx * 4, 16, 23), (cx + sx * 6, 15, 28)], [1.0, 0.3], GOLD)
    g.bake_ao(0.2)
    return g


def gull(st):
    span = [4, 9, 17][st - 1]
    g = Grid(28 + span * 2, 34, 44)
    P = Painter(g)
    cx, cy = 14 + span, 17
    white = rgb(250, 250, 252)
    tip = [rgb(200, 210, 230), rgb(140, 160, 200), rgb(60, 130, 255)][st - 1]
    P.ell((cx, cy, 11), (8, 8, 8.5), white)
    P.ell((cx, cy - 1, 21), (7, 6.5, 6.5), white)
    P.tube([(cx, cy - 6, 20), (cx, cy - 10, 19.5)], [1.6, 0.8], rgb(255, 170, 40))
    cute_eyes(P, cx, cy - 6.6, 22.5, gap=3.0, size=0.85)
    for sx in (-1, 1):
        g.set_part("Leg" + ("L" if sx < 0 else "R"))
        P.box((cx + sx * 3, cy - 1, 1.5), (1.4, 2.2, 1.5), rgb(255, 170, 40), 0)
        w = 4 + span
        g.set_part("Wing" + ("L" if sx < 0 else "R"))
        P.box((cx + sx * (6 + w / 2), cy + 1, 14), (w / 2, 3.0, 1.4), white)
        P.box((cx + sx * (6 + w * 0.85), cy + 1, 14.3), (w * 0.18 + 0.6, 2.6, 1.2), tip)
    g.set_part("Body")
    if st >= 2:
        P.rbox((cx, cy - 1, 28), (6, 5.5, 1.6), rgb(50, 100, 210), 0.6)  # courier cap
        P.box((cx, cy - 6.8, 27), (3.5, 1.4, 0.4), rgb(40, 80, 170), 0)
        P.rbox((cx + 6, cy - 4, 9), (2.4, 1.6, 2.4), rgb(170, 110, 60), 0.6)  # satchel
        P.box((cx + 2, cy - 5.5, 13), (5.0, 0.4, 0.5), rgb(120, 76, 40), 0)
    if st == 3:
        for k in range(3):
            P.box((cx - 2 + k * 2, cy + 1, 31 + (k % 2) * 1.5), (0.6, 0.6, 2.0 + (k % 2)), rgb(255, 230, 60), 0)  # lightning crest
    g.bake_ao(0.2)
    return g


def puffer(st):
    g = Grid(44, 44, 44)
    P = Painter(g)
    cx, cy, cz = 22, 22, 20
    body = [rgb(255, 214, 90), rgb(255, 160, 60), rgb(160, 110, 255)][st - 1]
    spike = [rgb(160, 120, 50), rgb(200, 100, 40), rgb(70, 40, 120)][st - 1]
    r = 11
    P.ball((cx, cy, cz), r, body)
    P.ell((cx, cy - 2, cz - 3), (9, 8, 7), rgb(255, 248, 210))
    n = [14, 26, 40][st - 1]
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(max(0, 1 - y * y))
        a = i * 2.39996
        d = np.array((math.cos(a) * rr, math.sin(a) * rr, y))
        if d[1] < -0.6:
            continue
        p0 = np.array((cx, cy, cz)) + d * (r - 0.5)
        p1 = np.array((cx, cy, cz)) + d * (r + 3.2)
        P.tube([tuple(p0), tuple(p1)], [1.0, 0.25], spike)
    cute_eyes(P, cx, cy - r + 0.6, cz + 2.5, gap=3.6, size=1.05)
    P.ball((cx, cy - r + 0.5, cz - 2.8), 1.3, rgb(230, 80, 80), 0)
    for sx in (-1, 1):
        g.set_part("Wing" + ("L" if sx < 0 else "R"))
        P.box((cx + sx * (r + 0.5), cy, cz - 1), (1.0, 3.0, 2.2), shade(body, 0.85))
    g.set_part("Tail")
    P.box((cx, cy + r + 2, cz), (0.9, 3.0, 4.0), shade(body, 0.85))
    g.set_part("Body")
    if st == 3:
        P.box((cx, cy, cz + r + 1.5), (4.0, 4.0, 1.4), GOLD, 0)
        for j in range(5):
            a = j / 5 * math.tau
            P.box((cx + math.cos(a) * 3.3, cy + math.sin(a) * 3.3, cz + r + 4), (0.9, 0.9, 1.6), GOLD, 0)
    g.bake_ao(0.18)
    return g


def lantern(st):
    g = Grid(40, 52, 50)
    P = Painter(g)
    cx = 20
    body = [rgb(80, 110, 220), rgb(60, 80, 190), rgb(40, 40, 120)][st - 1]
    glow = rgb(130, 255, 240)
    P.ell((cx, 28, 18), (10, 13, 10), body)
    P.ell((cx, 25, 15), (8, 9, 6), rgb(200, 220, 255))
    cute_eyes(P, cx, 15.4, 21, gap=4.0, size=1.0)
    teeth = [2, 4, 6][st - 1]
    for i in range(teeth):
        x = cx - 3 + i * (6 / max(1, teeth - 1))
        P.box((x, 15.8, 14.2), (0.45, 0.4, 0.9), WHITE, 0)
    lures = [1, 1, 3][st - 1]
    for j in range(lures):
        off = (j - (lures - 1) / 2) * 6
        P.tube([(cx + off * 0.3, 22, 27), (cx + off * 0.7, 18, 35), (cx + off, 12, 36)], [0.6, 0.5, 0.4], body)
        P.ball((cx + off, 11, 35), 2.4, glow, 0)
    g.set_part("Tail")
    P.box((cx, 44, 18), (1.0, 4.5, 6.0), shade(body, 1.3))
    for sx in (-1, 1):
        g.set_part("Wing" + ("L" if sx < 0 else "R"))
        P.box((cx + sx * 10.5, 28, 16), (1.0, 4.0, 2.6), shade(body, 1.3))
    g.set_part("Body")
    if st >= 2:
        for k in range(5):
            P.box((cx, 22 + k * 3, 28.3 - k * 0.4), (0.8, 1.0, 1.6), shade(body, 1.4), 0)
        for sx in (-1, 1):
            for k in range(3):
                P.box((cx + sx * 9.6, 22 + k * 5, 19), (0.6, 0.8, 0.8), glow, 0)
    if st == 3:
        for z in (13, 23):
            for k in range(28):
                a = k / 28 * math.tau
                P.box((cx + math.cos(a) * 11.5, 28 + math.sin(a) * 14, z), (0.5, 0.5, 0.5), glow, 0)
    g.bake_ao(0.18)
    return g


def leviathan_pet(st):
    g = Grid(44, 60, 44 + st * 4)
    P = Painter(g)
    cx = 22
    body = [rgb(70, 170, 210), rgb(50, 130, 180), rgb(40, 100, 150)][st - 1]
    belly = rgb(200, 245, 255)
    n = [6, 9, 12][st - 1]
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append((cx + math.sin(t * math.pi * 1.6) * 8, 18 + t * 36, 10 - t * 6 + math.sin(t * math.pi * 2) * 2 + 4))
    radii = [5.0 - 3.5 * (i / (n - 1)) for i in range(n)]
    P.tube(pts, radii, body)
    P.tube([(p[0], p[1] - 1, p[2] - 1.5) for p in pts[:-2]], [r * 0.65 for r in radii[:-2]], belly)
    for i in range(1, n - 1, 2):
        p = pts[i]
        P.box((p[0], p[1], p[2] + radii[i] + 1), (0.7, 1.5, 1.8 * (1 - i / n) + 0.6), rgb(255, 214, 100), 0)
    hx, hy, hz = pts[0][0], 11, 15
    P.rbox((hx, hy, hz), (6.5, 7, 5.5), body, 2.2)
    P.rbox((hx, hy - 6.5, hz - 1.5), (4.0, 2.6, 2.6), body, 1.0)
    P.box((hx, hy - 9.0, hz - 2.8), (3.2, 0.4, 0.4), shade(body, 0.5), 0)
    cute_eyes(P, hx, hy - 7.1, hz + 2.2, gap=3.4, size=1.0)
    horn = [1.5, 3.0, 5.0][st - 1]
    for sx in (-1, 1):
        P.tube([(hx + sx * 3.5, hy + 2, hz + 5), (hx + sx * 4.5, hy + 4, hz + 5 + horn)], [1.0, 0.3], rgb(255, 245, 210))
        P.box((hx + sx * 7, hy + 1, hz), (0.8, 2.6, 2.0), rgb(255, 214, 100), 0)
        if st == 3:
            g.set_part("Wing" + ("L" if sx < 0 else "R"))
            P.box((hx + sx * 12, 30, 22), (6, 4, 0.8), rgb(140, 220, 255))  # wings
            P.tube([(hx + sx * 5, 28, 16), (hx + sx * 17, 30, 24)], [0.8, 0.5], rgb(255, 214, 100))
            g.set_part("Body")
    g.bake_ao(0.18)
    return g


# ---------------------------------------------------------------- fruits
def fruit(base, swirl, kind):
    g = Grid(40, 40, 46)
    P = Painter(g)
    cx, cy, cz = 20, 20, 17
    r = 13
    if kind == "split":
        d = np.minimum(g.d_ellipsoid((cx - 3, cy, cz), (8.5, 13, 13)), g.d_ellipsoid((cx + 3, cy, cz), (8.5, 13, 13)))
    elif kind == "ward":
        d = g.d_box((cx, cy, cz), (9.5, 9.5, 9.5), 0.785) - 2.5  # faceted crystal-like
    elif kind == "haze":
        d = np.minimum.reduce([g.d_sphere((cx, cy, cz), 10), g.d_sphere((cx - 7, cy, cz + 2), 7), g.d_sphere((cx + 7, cy + 1, cz + 3), 7), g.d_sphere((cx, cy - 6, cz + 4), 6.5), g.d_sphere((cx, cy + 2, cz + 9), 6)])
    elif kind == "slick":
        d = np.minimum(g.d_sphere((cx, cy, cz - 2), 12), g.d_sphere((cx, cy, cz + 9), 7.5))
    else:
        d = g.d_ellipsoid((cx, cy, cz), (r, r, r * 0.92))
    rel = g.P - np.array((cx, cy, cz), np.float32)
    phi = np.arctan2(rel[..., 1], rel[..., 0])
    h = rel[..., 2] / r

    def colfn(m):
        # the cursed-fruit swirl: spiral bands around the fruit, crisp voxel edges
        band = np.sin(phi * 3 + h * 5.5)
        c = np.where((band > 0.55)[..., None], np.array(swirl, np.float32), np.array(base, np.float32))
        c = np.where(((band > 0.42) & (band <= 0.55))[..., None], np.array(shade(swirl, 0.75), np.float32), c)
        return c * g.noise(0.03)[..., None]
    g.add(d, colfn)
    top = cz + (12 if kind != "slick" else 16)
    P.tube([(cx, cy, top - 1), (cx + 0.5, cy, top + 3), (cx + 2.5, cy, top + 5)], [1.1, 1.0, 0.8], rgb(110, 70, 40))
    P.box((cx + 5, cy, top + 3.5), (3.6, 0.8, 1.6), rgb(90, 200, 90), 0.03)
    P.box((cx + 4, cy, top + 3.5), (1.4, 1.0, 0.4), rgb(60, 150, 60), 0)
    if kind == "blaze":
        for k, (dx, hh) in enumerate(((0, 9), (-4, 6), (4, 6.5), (-2, 7.5), (2.5, 8))):
            P.tube([(cx + dx, cy - 2, top - 2), (cx + dx * 1.2, cy - 2, top + hh * 0.6), (cx + dx * 0.6, cy - 2, top + hh)], [1.8, 1.2, 0.3], rgb(255, 150 + k * 18, 40))
    g.bake_ao(0.15)
    return g


# ---------------------------------------------------------------- fruits v2 (v0.25.5, owner: each fruit must SHOW its
# power through its shape and pattern, not two-color stripes). Our own designs: Blaze = a ball of flame tongues,
# Haze = a cluster of cloud puffs with grey creases, Ward = a crystal shell with a glowing hex barrier grid,
# Bounce = a rubbery ball of bulging bubbles, Split = cut into floating slices, Slick = a dripping oil drop.
def fib_points(n, radius, center, zscale=1.0):
    pts = []
    for i in range(n):
        y = 1 - (i + 0.5) / n * 2
        rr = math.sqrt(max(0.0, 1 - y * y))
        a = i * math.pi * (3 - math.sqrt(5))
        pts.append((center[0] + math.cos(a) * rr * radius, center[1] + math.sin(a) * rr * radius, center[2] + y * radius * zscale))
    return pts


def lobes(g, pts, radii):
    """union of ellipsoid lobes; returns (d, nearest distance, second nearest) for crease shading"""
    ds = np.stack([g.d_ellipsoid(c, radii) for c in pts], 0)
    srt = np.sort(ds, 0)
    return srt[0], srt[0], srt[1]


def stem(P, cx, cy, top, color=rgb(70, 150, 120)):
    # curly stem + a leaf (shared by every fruit)
    P.tube([(cx, cy, top - 1), (cx + 0.5, cy, top + 3), (cx + 2.5, cy, top + 4.5), (cx + 4, cy, top + 3.5), (cx + 3.5, cy, top + 2.5)], [1.1, 1.0, 0.8, 0.7, 0.6], color)
    P.box((cx - 3.5, cy, top + 2.5), (2.6, 0.7, 1.3), rgb(90, 200, 90), 0.03)


def fruit_v2(kind):
    g = Grid(46, 46, 52)
    P = Painter(g)
    cx, cy, cz = 23, 23, 19
    top = cz + 13
    if kind == "blaze":
        # flame tongues: tall lobes pointing up, tips curl a little; red at the root -> orange -> yellow tips
        pts = fib_points(26, 8.5, (cx, cy, cz), 0.9)
        d, n1, n2 = lobes(g, [(x, y, z + 1.5) for x, y, z in pts], (4.2, 4.2, 6.2))
        d = np.minimum(d, g.d_sphere((cx, cy, cz), 9.5))
        z = g.P[..., 2]
        t = np.clip((z - (cz - 12)) / 26.0, 0, 1)
        crease = np.clip((n2 - n1) / 2.5, 0, 1)

        def col(m):
            c = np.array(rgb(235, 90, 30), np.float32)[None, None, None] * (1 - t[..., None]) + np.array(rgb(255, 170, 40), np.float32) * t[..., None]
            # each tongue lights up toward its outer edge (yellow), deep red only in the cracks between tongues
            c = np.where((crease > 0.55)[..., None], c * 0.4 + np.array(rgb(255, 215, 80), np.float32) * 0.6, c)
            c = np.where((crease < 0.16)[..., None], np.array(rgb(170, 35, 20), np.float32), c)
            return c * g.noise(0.03)[..., None]
        g.add(d, col)
        for k, (dx, hh) in enumerate(((0, 9), (-4, 6), (4, 6.5), (-2, 7.5), (2.5, 8))):
            P.tube([(cx + dx, cy - 1, top - 3), (cx + dx * 1.2, cy - 1, top + hh * 0.6), (cx + dx * 0.6, cy - 1, top + hh)], [1.8, 1.2, 0.3], rgb(255, 160 + k * 16, 40))
        stem(P, cx, cy + 2, top + 1)
    elif kind == "haze":
        # cloud puffs: round lumps, white tops, grey-lilac creases where puffs meet, wisps trailing at the bottom
        pts = fib_points(14, 8, (cx, cy, cz))
        d, n1, n2 = lobes(g, pts, (6, 6, 5.5))
        d = np.minimum(d, g.d_sphere((cx, cy, cz), 9))
        crease = np.clip((n2 - n1) / 2.0, 0, 1)
        up = np.clip((g.P[..., 2] - cz) / 12 + 0.5, 0, 1)

        def col(m):
            c = np.array(rgb(236, 238, 246), np.float32)[None, None, None] * (0.86 + 0.14 * up[..., None])
            c = np.where((crease < 0.25)[..., None], np.array(rgb(160, 156, 186), np.float32), c)
            return c * g.noise(0.02)[..., None]
        g.add(d, col)
        for k in range(4):
            a = k * 1.6
            P.tube([(cx + math.cos(a) * 9, cy + math.sin(a) * 9, cz - 6), (cx + math.cos(a + 0.5) * 12, cy + math.sin(a + 0.5) * 12, cz - 10), (cx + math.cos(a + 1) * 10, cy + math.sin(a + 1) * 10, cz - 13)], [2.0, 1.4, 0.6], rgb(214, 214, 228))
        stem(P, cx, cy, top)
    elif kind == "ward":
        # crystal shell: faceted body, glowing hex barrier lines over pale cyan, a bright core visible at the facets
        d = np.maximum(g.d_sphere((cx, cy, cz), 12), g.d_box((cx, cy, cz), (11, 11, 11), 0.785) - 1.5)  # round, lightly faceted
        rel = g.P - np.array((cx, cy, cz), np.float32)
        phi = np.arctan2(rel[..., 1], rel[..., 0])
        th = np.arccos(np.clip(rel[..., 2] / (np.linalg.norm(rel, axis=-1) + 1e-6), -1, 1))
        u, v = phi * 6 / math.pi, th * 5 / math.pi
        row = np.floor(v)
        uu = u + (row % 2) * 0.5
        hexline = (np.abs(uu - np.round(uu)) < 0.1) | (np.abs(v - np.round(v)) < 0.08)

        def col(m):
            c = np.where(hexline[..., None], np.array(rgb(240, 255, 255), np.float32), np.array(rgb(110, 205, 240), np.float32))
            return c * g.noise(0.02)[..., None]
        g.add(d, col)
        stem(P, cx, cy, top + 1, rgb(80, 170, 200))
    elif kind == "bounce":
        # rubber bubbles: a squashed ball covered in round bulges, pink with purple creases and white shine dots
        pts = fib_points(18, 9, (cx, cy, cz), 0.85)
        d, n1, n2 = lobes(g, pts, (4.6, 4.6, 4.6))
        d = np.minimum(d, g.d_ellipsoid((cx, cy, cz), (10.5, 10.5, 9)))
        crease = np.clip((n2 - n1) / 2.0, 0, 1)

        def col(m):
            c = np.where((crease < 0.22)[..., None], np.array(rgb(170, 70, 200), np.float32), np.array(rgb(255, 130, 190), np.float32))
            return c * g.noise(0.02)[..., None]
        g.add(d, col)
        for x, y, z in pts:
            if z > cz - 2:
                P.ball((x - 1.2, y - 1.2, z + 2.6), 0.9, WHITE, 0)
        stem(P, cx, cy, top - 1)
    elif kind == "split":
        # three floating slices with gaps; green skin outside, lilac flesh with seeds on the cut faces
        d0 = g.d_ellipsoid((cx, cy, cz), (11.5, 11.5, 12))
        z = g.P[..., 2]
        cuts = ((cz - 12.5, cz - 4.2, 0), (cz - 2.6, cz + 3.4, 2.5), (cz + 5.0, cz + 12.5, -1.5))
        for z0, z1, dx in cuts:
            slab = np.maximum(z0 - z, z - z1)
            sh = g.P - np.array((dx, 0, 0), np.float32)
            dd = np.maximum(np.linalg.norm((sh - np.array((cx, cy, cz), np.float32)) / np.array((11.5, 11.5, 12), np.float32), axis=-1) - 1, 0) * 11.5
            dd = np.where(np.linalg.norm((sh - np.array((cx, cy, cz), np.float32)) / np.array((11.5, 11.5, 12), np.float32), axis=-1) < 1, -1.0, dd)
            dslice = np.maximum(dd, slab)
            face = (np.abs(z - z0) < 1.1) | (np.abs(z - z1) < 1.1)
            rim = np.linalg.norm((sh - np.array((cx, cy, cz), np.float32))[..., :2], axis=-1)

            def col(m, face=face, rim=rim):
                c = np.array(rgb(80, 190, 100), np.float32) * np.ones(rim.shape + (1,), np.float32)
                inner = face & (rim < 9.5)
                c = np.where(inner[..., None], np.array(rgb(215, 170, 255), np.float32), c)
                seeds = inner & ((np.floor(g.P[..., 0]) + np.floor(g.P[..., 1])) % 5 == 0) & (rim < 6)
                c = np.where(seeds[..., None], np.array(rgb(90, 40, 120), np.float32), c)
                return c * g.noise(0.02)[..., None]
            g.add(dslice, col)
        stem(P, cx - 1.5, cy, top)
        _ = d0
    else:  # slick
        # an oil drop: round bottom, pointed top, dark amber with a bright yellow gloss streak and drips underneath
        d = np.minimum(g.d_sphere((cx, cy, cz - 1), 11), g.d_ellipsoid((cx, cy, cz + 8), (5.5, 5.5, 10)))
        rel = g.P - np.array((cx, cy, cz), np.float32)

        def col(m):
            c = np.array(rgb(120, 86, 34), np.float32) * np.ones(rel.shape[:-1] + (1,), np.float32)
            gloss = ((rel[..., 0] < -3) & (rel[..., 1] < -2) & (rel[..., 2] > -2) & (rel[..., 2] < 8)) | ((rel[..., 0] > 5) & (rel[..., 2] > 2) & (rel[..., 2] < 5))
            c = np.where(gloss[..., None], np.array(rgb(240, 220, 110), np.float32), c)
            band = (np.abs(rel[..., 2] + 3) < 1.0)
            c = np.where(band[..., None], np.array(rgb(150, 120, 40), np.float32), c)
            return c * g.noise(0.02)[..., None]
        g.add(d, col)
        for k, a in enumerate((0.5, 2.4, 4.2)):
            x, y = cx + math.cos(a) * 7, cy + math.sin(a) * 7
            P.tube([(x, y, cz - 7), (x, y, cz - 11 - k)], [1.6, 1.0], rgb(60, 45, 20))
            P.ball((x, y, cz - 12.5 - k), 1.5, rgb(80, 60, 25), 0)
        stem(P, cx, cy, cz + 18, rgb(110, 90, 40))
    g.bake_ao(0.15)
    return g


PETS = {"Hermit": hermit, "Boarlet": boarlet, "Gull": gull, "Puffer": puffer, "Lantern": lantern, "Leviathan": leviathan_pet}
FRUITS = {
    "Bounce": (rgb(255, 120, 200), rgb(160, 60, 230), "round"),
    "Blaze": (rgb(255, 90, 36), rgb(255, 214, 60), "blaze"),
    "Haze": (rgb(222, 226, 236), rgb(140, 146, 165), "haze"),
    "Ward": (rgb(110, 210, 255), rgb(236, 252, 255), "ward"),
    "Split": (rgb(95, 205, 110), rgb(240, 240, 120), "split"),
    "Slick": (rgb(255, 216, 74), rgb(255, 248, 210), "slick"),
}


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    jobs = []
    for sp, fn in PETS.items():
        for st in (1, 2, 3):
            jobs.append((f"{sp}_{st}", (lambda f, s: (lambda: f(s)))(fn, st)))
    for fid, (a, b, kind) in FRUITS.items():
        jobs.append(("Fruit_" + fid, (lambda k_: (lambda: fruit_v2(k_)))(fid.lower())))
    for name, build in jobs:
        if ONLY and name not in ONLY:
            continue
        K.reset()
        objs = V.mesh_grid(build(), name, 0.2, split=True)
        V.export_parts(objs, os.path.join(OUT, name + ".glb"))
        obj = objs
        if PREVIEW:
            V.preview(obj, os.path.join(OUT, "preview", name + ".png"))
        print("VOXEL", name)


if __name__ == "__main__":
    main()
