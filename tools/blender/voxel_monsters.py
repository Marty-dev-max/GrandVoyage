"""Voxel monsters (owner-approved voxel style): animals, humanoid crews with outfits, fishfolk and bosses.

  python tools/blender/voxel_monsters.py -- --out assets/models3d --preview [--only GuardWolf,AxeCaptain]
Outputs Mon_<MonsterId>.glb + preview. Upload with tools/upload_models.py; AssetService puts them in Assets.Monsters.
Every model faces -Y (Roblox forward) and stands on z=0. Colors come from Config/Monsters style colors (passed in here).
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401  (Blender module must load before gvkit)
import gvkit as K
import voxel as V
from voxel import Grid, hexc

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv


def rgb(r, g, b):
    return np.array((r / 255, g / 255, b / 255), np.float32)


def shade(c, k):
    return np.clip(np.array(c, np.float32) * k, 0, 1)


class Painter:
    """small helpers on top of the Grid: solid colors with a little per-voxel noise"""

    def __init__(self, g):
        self.g = g

    def col(self, c, n=0.025):
        g = self.g
        c = np.array(c, np.float32)
        n = min(n, 0.02) if c.mean() > 0.75 else n  # light cloth: almost no speckle
        return lambda m: c * g.noise(n)[..., None]

    def box(self, c, half, color, n=0.025, rot=0.0):
        self.g.add(self.g.d_box(c, half, rot), self.col(color, n))

    def ball(self, c, r, color, n=0.025):
        self.g.add(self.g.d_sphere(c, r), self.col(color, n))

    def ell(self, c, radii, color, n=0.025):
        self.g.add(self.g.d_ellipsoid(c, radii), self.col(color, n))

    def tube(self, pts, radii, color, n=0.025):
        d, _ = self.g.d_tube(pts, radii)
        self.g.add(d, self.col(color, n))

    def rbox(self, c, half, color, r=1.2, n=0.025):
        """rounded box"""
        h = tuple(max(0.5, x - r) for x in half)
        self.g.add(self.g.d_box(c, h) - r, self.col(color, n))


WHITE, BLACK = rgb(250, 250, 250), rgb(26, 22, 34)
SKIN = rgb(252, 214, 176)


def eyes(P, cx, y, z, gap=2.6, color=BLACK, size=1.0, angry=False, glow=None):
    for sx in (-1, 1):
        P.box((cx + sx * gap, y, z), (0.9 * size, 0.6, 1.1 * size), glow if glow is not None else color, 0)
        if glow is None:
            P.box((cx + sx * gap + 0.4, y - 0.3, z + 0.6), (0.35, 0.4, 0.35), WHITE, 0)
        if angry:
            P.box((cx + sx * (gap + 0.2), y - 0.2, z + 2.0 - 0), (1.4, 0.5, 0.35), shade(color, 1.0), 0)


# ---------------------------------------------------------------- humanoids
def humanoid(spec):
    """chibi voxel crew member. spec: outfit color, hat, skin, weapon, boss, extras"""
    g = Grid(44, 30, 60)
    P = Painter(g)
    cx, cy = 22, 15
    outfit = spec["color"]
    skin = spec.get("skin", SKIN)
    pants = spec.get("pants", rgb(60, 62, 90))
    boots = rgb(52, 36, 28)
    hat = spec.get("hat")
    boss = spec.get("boss", False)
    # legs + boots
    for sx in (-1, 1):
        g.set_part("Leg" + ("L" if sx < 0 else "R"))
        P.box((cx + sx * 3.2, cy, 3.2), (2.6, 3.0, 3.2), boots)
        P.box((cx + sx * 3.2, cy, 10.5), (2.4, 2.4, 4.6), pants)
    # torso
    g.set_part("Body")
    P.rbox((cx, cy, 22.5), (7.2, 4.6, 8.0), outfit, 1.4)
    P.box((cx, cy, 15.4), (7.4, 4.8, 1.0), rgb(70, 46, 30))  # belt
    P.box((cx, cy - 4.7, 28.4), (2.2, 0.3, 1.6), skin, 0)  # open collar
    for k in range(3):
        P.box((cx, cy - 4.8, 25.5 - k * 3.0), (0.45, 0.3, 0.45), shade(outfit, 0.55), 0)  # buttons
    for sx in (-1, 1):
        P.box((cx + sx * 7.3, cy, 22.5), (0.3, 4.0, 7.0), shade(outfit, 0.8), 0)  # side seams
    P.box((cx, cy - 4.8, 15.4), (1.2, 0.4, 1.0), rgb(255, 210, 80), 0)  # buckle
    # arms (slightly forward) + hands
    for sx in (-1, 1):
        g.set_part("Arm" + ("L" if sx < 0 else "R"))
        P.rbox((cx + sx * 9.6, cy - 0.5, 23.0), (2.3, 2.3, 6.0), outfit, 0.8)
        P.box((cx + sx * 9.6, cy - 0.8, 15.8), (2.0, 2.0, 1.6), skin)
    # head (big, chibi)
    hz = 37.5
    g.set_part("Head")
    P.rbox((cx, cy, hz), (7.0, 6.2, 7.0), skin, 1.6)
    eyes(P, cx, cy - 6.4, hz + 0.5, angry=spec.get("angry", True), glow=spec.get("glow"))
    P.box((cx, cy - 6.3, hz - 3.4), (1.8, 0.4, 0.4), shade(skin, 0.6), 0)  # mouth
    if spec.get("beard") is not None:
        P.rbox((cx, cy - 4.5, hz - 4.6), (6.0, 2.2, 2.6), spec["beard"], 0.8)
    # hats
    if hat == "marine":
        P.rbox((cx, cy, hz + 7.0), (7.4, 6.6, 1.8), WHITE, 0.6)
        P.box((cx, cy, hz + 5.6), (7.5, 6.7, 0.7), rgb(60, 110, 220), 0)
        P.box((cx, cy - 7.4, hz + 5.2), (5.0, 1.6, 0.5), rgb(40, 60, 120), 0)  # visor
        g.set_part("Body")
        P.box((cx, cy - 4.8, 21.0), (2.0, 0.3, 4.0), rgb(60, 110, 220), 0)  # collar tie
        g.set_part("Head")
    elif hat == "bandana":
        P.rbox((cx, cy, hz + 5.4), (7.3, 6.5, 2.2), rgb(210, 50, 50), 0.6)
        P.box((cx, cy + 7.6, hz + 4.6), (1.2, 1.6, 1.6), rgb(210, 50, 50), 0)
        P.box((cx + 1.6, cy + 8.8, hz + 3.0), (0.8, 1.2, 2.0), rgb(190, 40, 40), 0)
        P.box((cx - 2.6, cy - 6.4, hz + 0.6), (1.6, 0.4, 1.6), BLACK, 0)  # eyepatch
    elif hat == "clown":
        for sx in (-1, 1):
            P.ball((cx + sx * 7.0, cy + 1, hz + 3.0), 3.0, rgb(255, 90, 40))
        P.ball((cx, cy - 6.8, hz - 1.0), 1.4, rgb(255, 40, 40), 0)  # nose
        P.box((cx, cy - 6.3, hz - 3.4), (3.0, 0.5, 0.6), rgb(220, 30, 60), 0)  # big smile
        for k in range(5):
            P.ball((cx, cy, hz + 7.5 + k * 2.0), 3.2 - k * 0.55, (rgb(255, 230, 60) if k % 2 else rgb(120, 60, 220)))
        P.ball((cx, cy, hz + 17.5), 1.3, WHITE)
    elif hat == "cat":
        for sx in (-1, 1):
            g.add(g.d_box((cx + sx * 4.5, cy, hz + 8.4), (1.8, 1.4, 2.2)), P.col(shade(outfit, 0.7)))
            P.box((cx + sx * 4.5, cy - 1.2, hz + 8.0), (0.8, 0.3, 1.2), rgb(255, 160, 180), 0)
            for k in range(2):
                P.box((cx + sx * 7.8, cy - 6.0, hz - 1.4 + k * 1.2), (1.8, 0.3, 0.2), WHITE, 0)  # whiskers
        P.rbox((cx, cy, hz + 6.2), (7.2, 6.4, 1.2), shade(outfit, 0.7), 0.4)
        g.set_part("Tail")
        P.tube([(cx, cy + 5, 16), (cx + 3, cy + 10, 14), (cx + 6, cy + 12, 22)], [1.4, 1.2, 0.9], shade(outfit, 0.7))
        g.set_part("Head")
    elif hat == "helmet":
        P.rbox((cx, cy, hz + 4.6), (7.8, 7.0, 3.8), rgb(170, 175, 190), 0.8)
        P.box((cx, cy, hz + 9.0), (1.0, 6.0, 1.6), rgb(220, 60, 60), 0)  # crest
        P.box((cx, cy - 7.2, hz + 1.0), (6.0, 0.6, 0.6), rgb(120, 125, 140), 0)
        g.set_part("Body")
        for sx in (-1, 1):
            P.rbox((cx + sx * 9.6, cy - 0.5, 28.6), (3.2, 3.2, 1.8), rgb(160, 165, 180), 0.6)  # pauldrons
        P.box((cx, cy - 4.9, 23.0), (5.6, 0.6, 5.0), rgb(150, 155, 170))  # breastplate
        g.set_part("Head")
    elif hat is None and spec.get("hair") is not None:
        P.rbox((cx, cy + 1, hz + 5.2), (7.4, 6.0, 2.4), spec["hair"], 0.8)
    if spec.get("swirl"):  # hypnotized eyes
        for sx in (-1, 1):
            P.box((cx + sx * 2.6, cy - 6.5, hz + 0.5), (1.4, 0.4, 1.4), rgb(255, 255, 255), 0)
            P.box((cx + sx * 2.6, cy - 6.8, hz + 0.5), (0.8, 0.4, 0.8), rgb(200, 60, 220), 0)
    # weapons (right hand, +X)
    w = spec.get("weapon")
    hx, hy = cx + 9.6, cy - 1.5
    g.set_part("ArmR")
    if w == "sword":
        P.box((hx, hy - 1, 16.0), (0.8, 0.8, 2.0), rgb(90, 60, 40), 0)
        P.box((hx, hy - 1, 18.6), (2.2, 0.8, 0.5), rgb(220, 190, 80), 0)
        P.box((hx, hy - 1, 26.5), (0.9, 0.5, 7.5), rgb(220, 228, 240), 0.02)
    elif w == "rifle":
        P.box((hx, hy - 5, 17.0), (0.9, 9.0, 0.9), rgb(70, 72, 84), 0)
        P.box((hx, hy + 3, 16.0), (1.1, 3.0, 1.8), rgb(120, 76, 44), 0)
    elif w == "axe":
        s = 1.8 if boss else 1.0
        P.box((hx + 1, hy, 22 * 1.0), (0.9, 0.9, 11 * s), rgb(110, 76, 46), 0)
        P.box((hx + 1, hy - 3.0 * s, 22 + 9 * s), (1.2, 3.4 * s, 4.0 * s), rgb(200, 205, 220), 0.02)
    elif w == "club":
        P.tube([(hx, hy, 15), (hx, hy - 2, 26)], [0.9, 2.2], rgb(140, 90, 50))
    elif w == "pistol":
        P.box((hx, hy - 3, 16.5), (0.8, 3.2, 1.0), rgb(60, 60, 70), 0)
    elif w == "claws":
        for k in (-1, 0, 1):
            P.box((hx + k * 0.9, hy - 3.0, 15.4), (0.3, 1.8, 0.3), rgb(230, 230, 240), 0)
    # bosses: cape, epaulettes, bigger presence
    g.set_part("Body")
    if boss:
        cape = spec.get("cape", rgb(160, 30, 40))
        P.box((cx, cy + 5.3, 20.0), (8.0, 0.8, 10.5), cape, 0.04)
        for sx in (-1, 1):
            P.rbox((cx + sx * 9.6, cy - 0.5, 29.6), (3.0, 3.0, 1.2), rgb(255, 200, 60), 0.4)
            for k in range(3):
                P.box((cx + sx * (8.0 + k * 1.3), cy - 0.5, 27.8), (0.4, 2.4, 1.0), rgb(255, 210, 90), 0)
        if spec.get("crown"):
            g.set_part("Head")
            for k in range(5):
                P.box((cx - 4 + k * 2, cy, hz + 9 + (k % 2) * 1.2), (0.8, 5.0, 1.8 + (k % 2)), rgb(255, 205, 60), 0)
    g.bake_ao(0.22)
    return g


def fishfolk(spec):
    g = humanoid(dict(spec, hat=None, skin=spec["color"], angry=True))
    P = Painter(g)
    cx, cy, hz = 22, 15, 37.5
    kind = spec["fish"]
    c = spec["color"]
    belly = shade(c, 1.5)
    g.set_part("Head")
    if kind == "shark":
        P.box((cx, cy + 1, hz + 9.5), (0.9, 3.2, 3.0), shade(c, 0.85))  # dorsal fin
        P.box((cx, cy + 3, hz + 12.0), (0.8, 1.6, 1.2), shade(c, 0.85))
        P.box((cx, cy - 6.6, hz - 3.6), (4.6, 0.5, 1.2), WHITE, 0)  # teeth row
        for k in range(5):
            P.box((cx - 3.6 + k * 1.8, cy - 6.9, hz - 4.6), (0.4, 0.3, 0.6), WHITE, 0)
        for sx in (-1, 1):
            for k in range(3):
                P.box((cx + sx * 7.1, cy - 1 + k * 1.6, hz - 1.5), (0.2, 0.3, 1.6), shade(c, 0.6), 0)  # gills
    elif kind == "saw":
        P.box((cx, cy - 13.0, hz - 1.0), (1.4, 6.4, 0.8), rgb(210, 215, 225), 0.02)  # saw snout
        for k in range(6):
            for sx in (-1, 1):
                P.box((cx + sx * 1.9, cy - 8.0 - k * 2.0, hz - 1.0), (0.5, 0.4, 0.5), WHITE, 0)
    elif kind == "octo":
        P.rbox((cx, cy + 1.5, hz + 4.5), (7.6, 7.0, 6.0), c, 2.0)  # big domed head
        for k in range(6):
            a = -0.8 + k * 0.32
            x0 = cx + math.sin(a) * 4.5
            P.tube([(x0, cy - 5.5, hz - 2.5), (x0 + math.sin(a) * 2, cy - 6.5, hz - 7), (x0 + math.sin(a) * 3.5, cy - 5.5, hz - 11)], [1.1, 0.8, 0.5], shade(c, 0.9))
    g.set_part("Body")
    P.box((cx, cy - 4.8, 22.0), (5.0, 0.4, 6.0), belly)
    g.bake_ao(0.2)
    return g


# ---------------------------------------------------------------- animals
def crab(c):
    g = Grid(56, 44, 30)
    P = Painter(g)
    cx, cy = 28, 22
    P.ell((cx, cy, 9), (13, 10, 6.5), c)
    P.ell((cx, cy - 1, 12.5), (10, 7.5, 3.0), shade(c, 1.15))
    for sx in (-1, 1):
        g.set_part("Leg" + ("L" if sx < 0 else "R"))
        for k in range(3):
            P.tube([(cx + sx * 10, cy - 3 + k * 4, 6), (cx + sx * 17, cy - 3 + k * 4, 8), (cx + sx * 20, cy - 4 + k * 4, 0.5)], [1.4, 1.2, 0.8], shade(c, 0.85))
        g.set_part("Arm" + ("L" if sx < 0 else "R"))
        P.tube([(cx + sx * 8, cy - 8, 9), (cx + sx * 15, cy - 15, 11)], [1.8, 2.2], c)
        P.ell((cx + sx * 16, cy - 17, 12), (4.5, 5.0, 3.8), shade(c, 1.1))
        P.box((cx + sx * 16 + sx * 1.6, cy - 22, 13.5), (1.6, 2.4, 1.0), shade(c, 1.25))
        P.box((cx + sx * 16 + sx * 1.6, cy - 22, 10.2), (1.4, 2.2, 0.9), shade(c, 1.25))
        g.set_part("Head")
        P.tube([(cx + sx * 3.5, cy - 7, 13), (cx + sx * 4, cy - 9, 18)], [0.8, 0.7], c)
        P.ball((cx + sx * 4, cy - 9.5, 19.2), 1.8, WHITE, 0)
        P.box((cx + sx * 4, cy - 11.2, 19.4), (0.8, 0.4, 0.9), BLACK, 0)
    g.set_part("Body")
    P.box((cx, cy - 10.2, 7.5), (3.0, 0.4, 0.5), shade(c, 0.5), 0)
    g.bake_ao(0.35)
    return g


def paint(g, d, color, where=None):
    """recolor voxels that are already filled (keeps their part)"""
    m = (d <= 0) & g.fill
    if where is not None:
        m &= where
    g.col[m] = np.array(color, np.float32) * g.noise(0.03)[m][..., None]


def quadruped(c, kind):
    """boar / wolf / lion / cat / tiger on four legs"""
    big = kind == "tiger"
    if big:
        kind = "cat"
    g = Grid(40, 64, 46)
    P = Painter(g)
    cx = 20
    belly = shade(c, 1.25)
    dark = shade(c, 0.65)
    body_z = 16 if kind != "cat" else 17
    P.ell((cx, 34, body_z), (9.5, 15, 8.5), c)
    P.ell((cx, 33, body_z - 4), (7.5, 12, 4.5), belly)
    for sx in (-1, 1):
        for yy in (24, 44):
            g.set_part("Leg" + ("F" if yy < 30 else "B") + ("L" if sx < 0 else "R"))
            P.box((cx + sx * 5.5, yy, 5.5), (2.6, 2.8, 5.5), dark if kind == "boar" else c)
            P.box((cx + sx * 5.5, yy - 0.8, 1.2), (2.9, 3.4, 1.2), shade(c, 0.45))
            if kind in ("cat", "lion", "wolf"):
                for k in (-1, 0, 1):
                    P.box((cx + sx * 5.5 + k * 1.2, yy - 4.0, 0.8), (0.35, 0.8, 0.5), WHITE, 0)
    hy, hz = 16, body_z + 6
    g.set_part("Head")
    if kind == "boar":
        P.rbox((cx, hy, hz - 1), (8, 8, 7), c, 2)
        P.rbox((cx, hy - 8.5, hz - 3), (4.6, 2.6, 3.4), rgb(240, 160, 150), 1)
        for sx in (-1, 1):
            P.box((cx + sx * 1.6, hy - 11.2, hz - 2.6), (0.7, 0.3, 0.8), shade(c, 0.4), 0)
            P.tube([(cx + sx * 4.2, hy - 8, hz - 4), (cx + sx * 5.6, hy - 11, hz + 0.5)], [1.0, 0.4], WHITE)
            P.box((cx + sx * 6.5, hy + 2, hz + 7), (1.4, 1.2, 2.0), dark)
        g.set_part("Body")
        for k in range(9):
            P.box((cx, hy + 4 + k * 3.2, body_z + 8.5 + (2 if k < 4 else 0)), (1.1, 1.4, 2.4 - k * 0.15), shade(c, 0.35), 0)
        g.set_part("Head")
        eyes(P, cx, hy - 8.1, hz + 2.5, gap=3.6, angry=True)
    elif kind in ("wolf", "lion", "cat"):
        head_r = (7, 7.5, 6.5) if kind != "lion" else (7.5, 7.5, 7.0)
        P.rbox((cx, hy, hz + 1), head_r, c, 2.2)
        P.rbox((cx, hy - 8.5, hz - 1.5), (4.0, 3.2, 3.0), belly, 1.2)
        P.box((cx, hy - 11.4, hz - 0.2), (1.4, 0.5, 1.0), BLACK, 0)
        P.box((cx, hy - 11.0, hz - 3.6), (2.6, 0.4, 0.4), shade(c, 0.4), 0)
        for sx in (-1, 1):
            P.box((cx + sx * 1.8, hy - 11.4, hz - 4.6), (0.5, 0.3, 0.9), WHITE, 0)  # fangs
        ear = 3.2 if kind != "lion" else 1.8
        for sx in (-1, 1):
            g.add(g.d_box((cx + sx * 4.4, hy + 1.5, hz + 8 + ear * 0.4), (1.8, 1.2, ear)), P.col(dark))
        eyes(P, cx, hy - 7.9, hz + 2.6, gap=3.4, angry=True, glow=rgb(255, 210, 60) if kind == "cat" and not big else None)
        if kind == "lion":
            # mane: chunky ring of dark-orange tufts around the head
            for k in range(22):
                a = k / 22 * math.tau
                P.ball((cx + math.cos(a) * 9.5, hy + 2.5, hz + 1 + math.sin(a) * 9.0), 3.2, shade(rgb(190, 90, 40), 0.9 + 0.2 * (k % 2)))
        if kind == "wolf":
            g.set_part("Body")
            for k in range(10):
                P.box((cx, hy + 6 + k * 2.6, body_z + 8.2 - k * 0.2), (2.4 - k * 0.12, 1.4, 2.0), dark, 0.03)
        # tail
        tail_c = dark if kind != "lion" else c
        g.set_part("Tail")
        P.tube([(cx, 48, body_z + 3), (cx, 55, body_z + 7), (cx + (3 if kind == "cat" else 0), 60, body_z + (14 if kind == "cat" else 6))], [2.2 if kind == "wolf" else 1.2, 1.8, 1.0], tail_c)
        if kind == "lion":
            P.ball((cx, 60.5, body_z + 6), 2.4, rgb(150, 70, 30))
    if big:
        # tiger: black stripes over the back, flanks, legs, head and tail; white muzzle, cheeks and belly
        stripe = rgb(30, 22, 20)
        Z = g.P[..., 2]
        for k, yy in enumerate(range(22, 48, 4)):
            tilt = 0.25 if k % 2 == 0 else -0.25
            paint(g, g.d_box((cx, yy, body_z + 4), (13, 0.75, 8), tilt), stripe, Z > body_z - 2.5)
        for sx in (-1, 1):
            for yy in (24, 44):
                for zz in (4.5, 8):
                    paint(g, g.d_box((cx + sx * 5.5, yy, zz), (3.2, 3.2, 0.55)), stripe)
        for k in range(3):
            paint(g, g.d_box((cx, hy - 2 + k * 2.4, hz + 7.6), (0.7, 0.6, 1.4 - k * 0.3)), stripe)
        for sx in (-1, 1):
            paint(g, g.d_box((cx + sx * 7, hy - 1, hz + 1.5), (0.6, 2.2, 0.6)), stripe)
            paint(g, g.d_box((cx + sx * 7, hy + 1.5, hz + 3.5), (0.6, 2.0, 0.6)), stripe)
            paint(g, g.d_ellipsoid((cx + sx * 4.6, hy - 6.5, hz - 2.0), (3.6, 3.4, 3.0)), WHITE, Z < hz + 0.5)
            paint(g, g.d_box((cx + sx * 3.2, hy - 7.6, hz + 4.6), (1.0, 0.8, 0.6)), WHITE)
        paint(g, g.d_ellipsoid((cx, hy - 8.5, hz - 1.8), (5.2, 4.6, 4.2)), WHITE, Z < hz + 0.2)
        paint(g, g.d_ellipsoid((cx, 26, body_z - 2), (7.0, 5.0, 6.0)), WHITE, Z < body_z + 1)
        paint(g, g.d_ellipsoid((cx, 33, body_z - 4.5), (6.5, 11, 3.5)), shade(WHITE, 0.95))
        paint(g, g.d_box((cx, hy - 11.4, hz - 0.2), (1.4, 0.5, 1.0)), rgb(60, 36, 36))
        for k in range(4):
            paint(g, g.d_ellipsoid((cx, 50 + k * 2.6, body_z + 4 + k * 2.2), (2.4, 0.7, 2.4)), stripe)
    g.bake_ao(0.35)
    return g


def monkey(c):
    g = Grid(44, 34, 52)
    P = Painter(g)
    cx, cy = 22, 17
    face = rgb(240, 200, 160)
    P.ell((cx, cy, 18), (8.5, 7, 10), c)
    P.ell((cx, cy - 4, 17), (5.5, 3.5, 7), face)
    for sx in (-1, 1):
        sd = "L" if sx < 0 else "R"
        g.set_part("Arm" + sd)
        P.tube([(cx + sx * 7, cy, 25), (cx + sx * 12, cy - 2, 16), (cx + sx * 12, cy - 4, 6)], [2.2, 2.0, 2.0], c)
        P.ball((cx + sx * 12, cy - 4.5, 4.5), 2.6, face)
        g.set_part("Leg" + sd)
        P.tube([(cx + sx * 4, cy, 10), (cx + sx * 5, cy - 1, 3)], [2.6, 2.4], c)
        P.box((cx + sx * 5, cy - 2, 1.2), (2.6, 3.4, 1.2), face)
        g.set_part("Head")
        P.ball((cx + sx * 9.5, cy, 37), 3.0, c)
        P.ball((cx + sx * 9.8, cy - 0.8, 37), 1.8, face)
    g.set_part("Head")
    P.rbox((cx, cy, 36), (8, 7, 7.5), c, 2.4)
    P.rbox((cx, cy - 5.2, 34.5), (5.5, 2.6, 5.0), face, 1.6)
    eyes(P, cx, cy - 7.9, 37, gap=2.4, angry=False)
    P.box((cx, cy - 7.9, 32.2), (2.2, 0.3, 0.4), shade(face, 0.5), 0)
    g.set_part("Tail")
    P.tube([(cx, cy + 6, 12), (cx + 2, cy + 13, 18), (cx - 2, cy + 14, 28), (cx - 5, cy + 12, 31)], [1.4, 1.2, 1.1, 1.0], c)
    g.bake_ao(0.35)
    return g


def conch(c):
    """the giant signal conch (FortCore): a spiral shell on a snail body, glowing mouth"""
    g = Grid(60, 60, 60)
    P = Painter(g)
    cx, cy = 30, 32
    shell = rgb(250, 228, 190)
    for k in range(10):
        t = k / 9
        r = 15 - t * 12
        z = 12 + t * 36
        a = t * math.tau * 1.6
        P.ball((cx + math.cos(a) * (6 - t * 4), cy + math.sin(a) * (6 - t * 4), z), r, shell if k % 2 else shade(shell, 0.88))
        for s in range(8):
            b = s / 8 * math.tau + a
            P.box((cx + math.cos(b) * r * 0.95, cy + math.sin(b) * r * 0.95, z + 2), (1.2, 1.2, 2.2), shade(shell, 0.75), 0)
    P.ell((cx, cy - 14, 5), (11, 15, 5), c)
    eyes(P, cx, cy - 27.5, 9, gap=4, glow=rgb(120, 255, 200))
    P.ell((cx, cy - 8, 20), (7, 3, 7), rgb(255, 120, 160))
    g.bake_ao(0.35)
    return g


def serpent(c, horn=rgb(240, 230, 196)):
    """the Leviathan mob: a purple cousin of the Bay Serpent (reuses its builder with new colors)"""
    g, _, _ = V.bay_serpent()
    # recolor: hue-shift by swapping channels toward purple
    m = g.fill
    col = g.col
    lum = col.mean(-1, keepdims=True)
    tint = np.array(c, np.float32)
    g.col = np.where(m[..., None], np.clip(lum * tint * 1.9, 0, 1), col)
    return g


# ---------------------------------------------------------------- the roster (colors match Config/Monsters)
def cfg(r, g_, b):
    return rgb(r, g_, b)


ROSTER = {
    "BeachCrab": lambda: crab(cfg(255, 110, 90)),
    "ForestMonkey": lambda: monkey(cfg(170, 110, 70)),
    "WildBoar": lambda: quadruped(cfg(140, 95, 75), "boar"),
    "GuardWolf": lambda: quadruped(cfg(150, 150, 165), "wolf"),
    "CircusLion": lambda: quadruped(cfg(240, 180, 80), "lion"),
    "ClawCat": lambda: quadruped(cfg(90, 70, 110), "cat"),
    "JungleTiger": lambda: quadruped(cfg(250, 160, 60), "tiger"),
    "FortCore": lambda: conch(cfg(120, 200, 120)),
    "Leviathan": lambda: serpent(cfg(150, 90, 200)),
    "MountainBandit": lambda: humanoid({"color": cfg(120, 100, 80), "hat": "bandana", "weapon": "club", "beard": rgb(70, 50, 35)}),
    "MarineRecruit": lambda: humanoid({"color": cfg(240, 240, 255), "hat": "marine", "weapon": "sword", "pants": rgb(60, 90, 170)}),
    "MarineRifleman": lambda: humanoid({"color": cfg(220, 230, 255), "hat": "marine", "weapon": "rifle", "pants": rgb(60, 90, 170)}),
    "ClownGrunt": lambda: humanoid({"color": cfg(255, 120, 120), "hat": "clown", "weapon": "club", "skin": rgb(250, 240, 235)}),
    "CircusAcrobat": lambda: humanoid({"color": cfg(255, 200, 80), "hat": "clown", "weapon": None, "skin": rgb(250, 240, 235), "pants": rgb(200, 60, 160)}),
    "NightCatPirate": lambda: humanoid({"color": cfg(70, 60, 80), "hat": "cat", "weapon": "claws", "pants": rgb(40, 34, 50)}),
    "HypnoThug": lambda: humanoid({"color": cfg(200, 120, 220), "hat": None, "hair": rgb(60, 40, 80), "weapon": "club", "swirl": True}),
    "ArmadaRaider": lambda: humanoid({"color": cfg(150, 150, 160), "hat": "helmet", "weapon": "sword"}),
    "StarvedPirate": lambda: humanoid({"color": cfg(180, 140, 110), "hat": "bandana", "weapon": "sword", "beard": rgb(120, 100, 80)}),
    "ArmoredGunner": lambda: humanoid({"color": cfg(110, 110, 120), "hat": "helmet", "weapon": "rifle"}),
    "BountyHunter": lambda: humanoid({"color": cfg(100, 80, 60), "hat": "bandana", "weapon": "pistol", "pants": rgb(50, 40, 34)}),
    "MarineElite": lambda: humanoid({"color": cfg(255, 255, 255), "hat": "marine", "weapon": "sword", "pants": rgb(30, 50, 120)}),
    "MistSoldier": lambda: humanoid({"color": cfg(200, 200, 210), "hat": "marine", "weapon": "rifle", "pants": rgb(110, 110, 130)}),
    "SharkfolkBrawler": lambda: fishfolk({"color": cfg(90, 170, 220), "fish": "shark", "weapon": "claws"}),
    "SawfolkRaider": lambda: fishfolk({"color": cfg(110, 120, 200), "fish": "saw", "weapon": "sword"}),
    "OctofolkBrute": lambda: fishfolk({"color": cfg(230, 120, 160), "fish": "octo", "weapon": "club"}),
    # bosses
    "AxeCaptain": lambda: humanoid({"color": cfg(240, 240, 250), "hat": "marine", "weapon": "axe", "boss": True, "beard": rgb(110, 80, 50), "cape": rgb(40, 70, 150)}),
    "CaptainConfetti": lambda: humanoid({"color": cfg(255, 80, 80), "hat": "clown", "weapon": "club", "boss": True, "skin": rgb(250, 240, 235), "cape": rgb(120, 40, 200)}),
    "RingMaster": lambda: humanoid({"color": cfg(200, 60, 160), "hat": "clown", "weapon": "club", "boss": True, "skin": rgb(250, 240, 235), "cape": rgb(255, 200, 60)}),
    "SilentClaw": lambda: humanoid({"color": cfg(60, 50, 70), "hat": "cat", "weapon": "claws", "boss": True, "glow": rgb(255, 210, 60), "cape": rgb(30, 24, 40)}),
    "ArmadaAdmiral": lambda: humanoid({"color": cfg(230, 190, 60), "hat": "helmet", "weapon": "sword", "boss": True, "crown": True, "cape": rgb(150, 30, 40)}),
    "MistCommodore": lambda: humanoid({"color": cfg(235, 235, 245), "hat": "marine", "weapon": "sword", "boss": True, "beard": rgb(200, 200, 210), "cape": rgb(90, 90, 110)}),
    "SawtoothOverlord": lambda: fishfolk({"color": cfg(90, 120, 210), "fish": "saw", "weapon": "axe", "boss": True, "crown": True, "cape": rgb(30, 40, 90)}),
    "DepthsWarden": lambda: fishfolk({"color": cfg(40, 90, 150), "fish": "shark", "weapon": "club", "boss": True, "cape": rgb(20, 40, 70), "glow": rgb(120, 255, 230)}),
}


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for mid, fn in ROSTER.items():
        if ONLY and mid not in ONLY:
            continue
        K.reset()
        g = fn()
        objs = V.mesh_grid(g, "Mon_" + mid, 0.25, split=True)
        V.export_parts(objs, os.path.join(OUT, "Mon_" + mid + ".glb"))
        obj = objs
        if PREVIEW:
            V.preview(obj, os.path.join(OUT, "preview", "Mon_" + mid + ".png"))
        print("MONSTER", mid)


if __name__ == "__main__":
    main()
