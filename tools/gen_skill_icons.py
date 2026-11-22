#!/usr/bin/env python3
"""Pixel-art skill icons (v0.24.14, owner): one 32x32 sprite per skill, drawn from little shape recipes that match
what the skill does, then shaded (lit top-left), outlined and set on a dithered tile in the class / fruit color.
Saved at 8x (256 px, nearest neighbour) so they stay crisp in game.

   python3 tools/gen_skill_icons.py            -> assets/skillicons/<SkillId>.png + assets/skillicons_sheet.png
   ROBLOX_API_KEY=... python3 tools/upload_images.py assets/skillicons src/shared/Config/SkillIcons.lua
UI/SkillLook.IconId uses Config/SkillIcons first."""
import math, os
from PIL import Image, ImageDraw

N = 32
SCALE = 8
ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'skillicons')

# tile color per class / fruit
TILE = {
    'Common': (120, 128, 150), 'Brawler': (214, 92, 52), 'Swordsman': (70, 110, 190), 'Sniper': (70, 150, 80),
    'Cook': (220, 160, 50), 'Navigator': (60, 160, 220), 'Doctor': (220, 100, 160), 'Shipwright': (150, 100, 60),
    'Bounce': (230, 90, 120), 'Blaze': (235, 110, 30), 'Haze': (130, 120, 160), 'Ward': (60, 190, 210),
    'Split': (150, 80, 190), 'Slick': (150, 190, 50),
}

# palette
SKIN = (246, 196, 150); SKIN_D = (205, 140, 100)
STEEL = (210, 222, 236); STEEL_D = (130, 145, 170)
GOLD = (255, 205, 70); GOLD_D = (200, 140, 30)
WOOD = (150, 95, 55); WOOD_D = (100, 60, 35)
FIRE1 = (255, 240, 120); FIRE2 = (255, 160, 40); FIRE3 = (230, 70, 30)
SMOKE1 = (235, 235, 240); SMOKE2 = (180, 180, 195)
CYAN = (120, 235, 255); WHITE = (255, 255, 255)
RED = (230, 60, 60); PINK = (255, 140, 180); GREEN = (110, 220, 110); YEL = (255, 230, 80)
PURP = (190, 120, 255); BROWN = (140, 85, 50); DARK = (40, 40, 52); IRON = (90, 96, 110)
OIL = (60, 50, 30); OIL_HI = (200, 190, 80); BLUE = (90, 150, 255)


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


class Spr:
    """a 32x32 sprite drawn with aliased shapes (pixel art); each shape has a flat color, shading comes later"""
    def __init__(self):
        self.im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
        self.fx = Image.new('RGBA', (N, N), (0, 0, 0, 0))  # effects layer: no outline / bevel (glows, lines)
        self.e = ImageDraw.Draw(self.fx)

    def poly(self, pts, c, fx=False):
        (self.e if fx else self.d).polygon([(round(x), round(y)) for x, y in pts], fill=c + (255,))

    def rect(self, x0, y0, x1, y1, c, fx=False):
        x0, x1 = round(min(x0, x1)), round(max(x0, x1))
        y0, y1 = round(min(y0, y1)), round(max(y0, y1))
        (self.e if fx else self.d).rectangle([x0, y0, x1, y1], fill=c + (255,))

    def oval(self, cx, cy, rx, ry, c, fx=False):
        (self.e if fx else self.d).ellipse([round(cx - rx), round(cy - ry), round(cx + rx), round(cy + ry)], fill=c + (255,))

    def line(self, pts, c, w=1, fx=False):
        (self.e if fx else self.d).line([(round(x), round(y)) for x, y in pts], fill=c + (255,), width=w)

    def px(self, x, y, c, fx=True):
        if 0 <= x < N and 0 <= y < N:
            (self.fx if fx else self.im).putpixel((int(x), int(y)), c + (255,))

    def arc(self, cx, cy, r, a0, a1, c, w=2, fx=True):
        pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(a0, a1 + 1, 6)]
        self.line(pts, c, w, fx)


# ---------- shape recipes (32x32, y down) ----------
def fist(s, cx=16, cy=17, k=1.0, glove=None):
    c, cd = (glove, lerp(glove, DARK, 0.3)) if glove else (SKIN, SKIN_D)
    w, h = 13 * k, 11 * k
    s.rect(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, c)
    for i in range(4):  # knuckles
        x = cx - w / 2 + 1 + i * (w - 2) / 4
        s.rect(x, cy - h / 2 - 2 * k, x + (w - 2) / 4 - 1, cy - h / 2 + 1, c)
        s.line([(x + (w - 2) / 4 - 1, cy - h / 2 - 1), (x + (w - 2) / 4 - 1, cy - 1)], cd)
    s.rect(cx - w / 2 - 3 * k, cy - 1, cx - w / 2 + 2, cy + h / 2 - 1, c)  # thumb
    s.rect(cx - w / 2 + 1, cy + h / 2, cx + w / 2 - 1, cy + h / 2 + 4 * k, cd)  # wrist


def speed_lines(s, x0, y0, x1, y1, n=4, c=WHITE, gap=3):
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    for i in range(n):
        o = (i - (n - 1) / 2) * gap
        k = 0.55 + 0.45 * ((i * 37) % 5) / 4
        s.line([(x0 + nx * o, y0 + ny * o), (x0 + dx * k + nx * o, y0 + dy * k + ny * o)], c, 1, True)


def sword(s, x0=7, y0=25, x1=25, y1=7, blade=STEEL):
    """a sword from its pommel end (x0, y0) to its tip (x1, y1): grip, cross guard, blade with a bright edge"""
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    gx, gy = x0 + ux * 5, y0 + uy * 5  # guard position
    s.line([(gx + ux, gy + uy), (x1, y1)], blade, 3)
    s.line([(gx + ux * 2 - nx * 0.6, gy + uy * 2 - ny * 0.6), (x1 - ux * 1.5, y1 - uy * 1.5)], WHITE, 1, True)
    s.line([(gx - nx * 4, gy - ny * 4), (gx + nx * 4, gy + ny * 4)], GOLD, 2)
    s.line([(x0, y0), (gx - ux, gy - uy)], WOOD, 3)
    s.px(x0 - ux, y0 - uy, GOLD, False)


def flame(s, cx, cy, r, tall=1.4):
    s.poly([(cx, cy - r * tall * 1.6), (cx + r, cy - r * 0.2), (cx + r * 0.8, cy + r * 0.7), (cx, cy + r), (cx - r * 0.8, cy + r * 0.7), (cx - r, cy - r * 0.2)], FIRE3)
    s.poly([(cx + r * 0.1, cy - r * tall * 1.0), (cx + r * 0.6, cy), (cx, cy + r * 0.75), (cx - r * 0.6, cy)], FIRE2)
    s.poly([(cx, cy - r * 0.3), (cx + r * 0.3, cy + r * 0.25), (cx, cy + r * 0.55), (cx - r * 0.3, cy + r * 0.25)], FIRE1, True)


def smoke(s, cx, cy, k=1.0, c1=SMOKE1, c2=SMOKE2):
    for dx, dy, r in ((-5, 2, 5), (4, 2, 5), (0, -3, 6), (-8, 5, 3), (8, 5, 3)):
        s.oval(cx + dx * k, cy + dy * k, r * k, r * k, c2)
    for dx, dy, r in ((-4, 0, 3), (2, -4, 4), (5, 1, 3)):
        s.oval(cx + dx * k, cy + dy * k, r * k, r * k, c1)


def bolt(s, cx=16, cy=16, k=1.0, c=YEL):
    p = [(2, -13), (-6, 1), (0, 1), (-3, 13), (7, -3), (1, -3), (5, -13)]
    s.poly([(cx + x * k, cy + y * k) for x, y in p], c)


def star(s, cx, cy, r1, r2, n, c, rot=-90, fx=False):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    s.poly(pts, c, fx)


def boom(s, cx=16, cy=16, k=1.0):
    star(s, cx, cy, 14 * k, 7 * k, 9, FIRE3)
    star(s, cx, cy, 10 * k, 5 * k, 8, FIRE2, rot=-70)
    star(s, cx, cy, 5 * k, 3 * k, 6, FIRE1, rot=-60, fx=True)


def shield(s, cx=16, cy=16, c=STEEL, k=1.0):
    s.poly([(cx - 10 * k, cy - 11 * k), (cx + 10 * k, cy - 11 * k), (cx + 10 * k, cy + 1 * k), (cx, cy + 12 * k), (cx - 10 * k, cy + 1 * k)], c)
    s.poly([(cx - 6 * k, cy - 7 * k), (cx + 6 * k, cy - 7 * k), (cx + 6 * k, cy), (cx, cy + 7 * k), (cx - 6 * k, cy)], lerp(c, WHITE, 0.35))


def heart(s, cx=16, cy=16, k=1.0, c=RED):
    s.oval(cx - 5 * k, cy - 4 * k, 5.5 * k, 5.5 * k, c)
    s.oval(cx + 5 * k, cy - 4 * k, 5.5 * k, 5.5 * k, c)
    s.poly([(cx - 10.5 * k, cy - 2 * k), (cx + 10.5 * k, cy - 2 * k), (cx, cy + 11 * k)], c)
    s.px(cx - 6, cy - 6, WHITE)
    s.px(cx - 7, cy - 5, WHITE)


def plus(s, cx, cy, r, c=WHITE, t=2, fx=True):
    s.rect(cx - t, cy - r, cx + t, cy + r, c, fx)
    s.rect(cx - r, cy - t, cx + r, cy + t, c, fx)


def sparkle(s, x, y, c=WHITE, r=2):
    s.px(x, y, c)
    for i in range(1, r + 1):
        for dx, dy in ((i, 0), (-i, 0), (0, i), (0, -i)):
            s.px(x + dx, y + dy, c)


def aura_rings(s, cx, cy, c):
    for r, w in ((13, 1), (10, 1)):
        s.arc(cx, cy, r, 200, 340, c, w)


def boot(s, cx=15, cy=16, c=(170, 90, 50)):
    s.poly([(cx - 4, cy - 12), (cx + 3, cy - 12), (cx + 3, cy + 3), (cx + 11, cy + 5), (cx + 11, cy + 10), (cx - 5, cy + 10)], c)
    s.rect(cx - 5, cy + 8, cx + 11, cy + 10, lerp(c, DARK, 0.45))
    s.rect(cx - 4, cy - 12, cx + 3, cy - 9, lerp(c, WHITE, 0.25))


def pellet(s, cx, cy, r=4, c=IRON):
    s.oval(cx, cy, r, r, c)
    s.px(cx - r // 2, cy - r // 2, WHITE)


def tornado(s, cx=16, top=5, bot=27, c=SMOKE1):
    rows = 6
    for i in range(rows):
        y = top + i * (bot - top) / rows
        w = 12 - i * 1.7
        s.oval(cx + math.sin(i * 1.1) * 2, y + 2, w, 2.2, c if i % 2 == 0 else lerp(c, DARK, 0.25))


def wave_slash(s, c=CYAN):
    s.arc(14, 20, 12, 250, 360, c, 3, False)
    s.arc(14, 20, 8, 260, 350, WHITE, 1, True)


def hammer(s):
    s.line([(9, 27), (19, 13)], WOOD, 3)
    s.poly([(12, 4), (24, 12), (20, 18), (8, 10)], IRON)
    s.poly([(13, 6), (22, 12), (21, 13), (12, 7)], STEEL, True)


def cannonball(s, cx=15, cy=18, r=8):
    s.oval(cx, cy, r, r, DARK)
    s.oval(cx - 3, cy - 3, 2, 2, IRON, True)
    s.line([(cx + 4, cy - 7), (cx + 7, cy - 11)], WOOD, 2)
    star(s, cx + 8, cy - 12, 4, 1.5, 5, YEL, fx=True)


def wrench(s):
    s.line([(8, 25), (20, 12)], STEEL, 4)
    s.oval(22, 9, 5, 5, STEEL)
    s.rect(21, 4, 24, 9, (0, 0, 0))  # mouth (punched out later)
    s.oval(7, 26, 3, 3, STEEL)


def meat(s):
    s.oval(15, 15, 9, 7, (190, 80, 60))
    s.oval(13, 13, 5, 3, (230, 120, 90), True)
    s.line([(21, 20), (27, 26)], (245, 240, 225), 3)
    s.oval(28, 26, 2, 2, (245, 240, 225))
    s.oval(26, 28, 2, 2, (245, 240, 225))


def flask(s, c=GREEN):
    s.rect(13, 4, 19, 10, (220, 230, 240))
    s.rect(12, 3, 20, 5, WOOD)
    s.poly([(12, 10), (20, 10), (27, 25), (24, 28), (8, 28), (5, 25)], (220, 230, 240))
    s.poly([(9, 18), (23, 18), (26, 25), (24, 27), (8, 27), (6, 25)], c)
    s.px(10, 22, WHITE)
    s.px(15, 24, WHITE)


def syringe(s):
    s.line([(7, 25), (20, 12)], (220, 235, 245), 5)
    s.line([(9, 23), (18, 14)], PINK, 2, True)
    s.line([(20, 12), (26, 6)], STEEL, 1)
    s.line([(4, 22), (10, 28)], STEEL_D, 2)


def eye(s):
    s.poly([(3, 16), (10, 9), (22, 9), (29, 16), (22, 23), (10, 23)], WHITE)
    s.oval(16, 16, 6, 6, (60, 140, 70))
    s.oval(16, 16, 3, 3, DARK)
    s.px(14, 14, WHITE)


def wind(s, c=(200, 240, 255)):
    for y, x0, x1 in ((10, 4, 22), (16, 8, 27), (22, 4, 20)):
        s.line([(x0, y), (x1, y)], c, 2)
        s.arc(x1, y - 3, 3, 270, 450, c, 2, False)


def hexwall(s, c=CYAN, k=1.0, cx=16, cy=16):
    pts = [(cx + 12 * k * math.cos(math.radians(60 * i + 30)), cy + 12 * k * math.sin(math.radians(60 * i + 30))) for i in range(6)]
    s.poly(pts, c)
    pts2 = [(cx + 8 * k * math.cos(math.radians(60 * i + 30)), cy + 8 * k * math.sin(math.radians(60 * i + 30))) for i in range(6)]
    s.poly(pts2, lerp(c, WHITE, 0.45))


def dome(s, c=CYAN):
    s.arc(16, 24, 13, 180, 360, c, 3, False)
    s.arc(16, 24, 9, 200, 340, lerp(c, WHITE, 0.5), 1, True)
    s.rect(2, 24, 30, 26, lerp(c, DARK, 0.3))


def drop(s, cx=16, cy=17, k=1.0, c=OIL, hi=OIL_HI):
    s.poly([(cx, cy - 13 * k), (cx + 8 * k, cy + 1 * k), (cx, cy + 9 * k), (cx - 8 * k, cy + 1 * k)], c)
    s.oval(cx, cy + 2 * k, 8 * k, 7 * k, c)
    s.px(cx - 3, cy - 1, hi)
    s.px(cx - 4, cy, hi)


def arrow_up(s, cx, top, c=WHITE):
    s.poly([(cx, top), (cx + 5, top + 6), (cx + 2, top + 6), (cx + 2, top + 12), (cx - 2, top + 12), (cx - 2, top + 6), (cx - 5, top + 6)], c, True)


def cracks(s, cy=27, c=BROWN):
    s.rect(2, cy, 29, cy + 3, c)
    for x0, x1 in ((6, 3), (14, 17), (23, 27)):
        s.line([(x0, cy), (x1, cy - 4)], lerp(c, DARK, 0.4), 1, True)
    for x, y in ((5, cy - 6), (26, cy - 7), (11, cy - 9)):
        s.rect(x, y, x + 2, y + 2, lerp(c, WHITE, 0.15))


def balloon(s):
    s.oval(16, 14, 11, 10, PINK)
    s.oval(12, 10, 3, 2, WHITE, True)
    s.poly([(14, 24), (18, 24), (16, 27)], PINK)


def hand_open(s, cx=16, cy=17, c=SMOKE1):
    s.rect(cx - 6, cy - 2, cx + 6, cy + 8, c)
    for i, h in enumerate((7, 9, 9, 7)):
        x = cx - 6 + i * 3.4
        s.rect(x, cy - 2 - h, x + 2, cy, c)
    s.rect(cx - 10, cy - 1, cx - 6, cy + 3, c)


def split_pieces(s, base):
    # a fist split into floating pieces with dashed seams
    fist(s, 16, 17, 1.0)
    for y in (12, 18):
        for x in range(4, 30, 3):
            s.px(x, y, base)
            s.px(x + 1, y, base)


def scalpel(s):
    s.poly([(6, 26), (20, 12), (25, 8), (22, 14), (9, 28)], STEEL)
    s.line([(6, 26), (12, 20)], (60, 60, 70), 3)


def chef_hat_aura(s):
    s.oval(12, 9, 5, 5, WHITE)
    s.oval(20, 9, 5, 5, WHITE)
    s.oval(16, 7, 5, 5, WHITE)
    s.rect(10, 11, 22, 18, WHITE)
    s.rect(10, 16, 22, 18, (210, 210, 220))


def ring_burst(s, cx=16, cy=16, c=WHITE):
    for a in range(0, 360, 45):
        r0, r1 = 9, 14
        s.line([(cx + r0 * math.cos(math.radians(a)), cy + r0 * math.sin(math.radians(a))), (cx + r1 * math.cos(math.radians(a)), cy + r1 * math.sin(math.radians(a)))], c, 1, True)


def stretch_arm(s):
    s.rect(2, 14, 18, 19, SKIN)
    s.line([(2, 14), (18, 14)], SKIN_D, 1, True)
    fist(s, 23, 16, 0.8)
    speed_lines(s, 2, 9, 14, 9, 1)
    speed_lines(s, 2, 24, 14, 24, 1)


def gatling(s):
    for (x, y) in ((10, 9), (22, 11), (12, 22), (23, 23)):
        fist(s, x, y, 0.5)
    ring_burst(s, 16, 16, YEL)


def eye_star(s):
    eye(s)
    sparkle(s, 26, 6, YEL, 2)


# ---------- skills -> recipe ----------
def R(tile, draw):
    return (tile, draw)


SKILLS = {
    # Common
    'FirstAid': R('Common', lambda s: (heart(s, 16, 17, 1.0), plus(s, 23, 8, 4, WHITE, 1))),
    'Bash': R('Common', lambda s: (fist(s, 17, 17, 1.25), star(s, 7, 7, 6, 2.5, 5, YEL, fx=True))),
    # Brawler
    'JabRush': R('Brawler', lambda s: (fist(s, 20, 11, 0.6), fist(s, 13, 21, 0.75), speed_lines(s, 3, 10, 11, 10, 3, WHITE, 3), speed_lines(s, 2, 22, 7, 22, 2))),
    'RisingUppercut': R('Brawler', lambda s: (fist(s, 16, 15, 1.0), arrow_up(s, 16, 2, YEL), speed_lines(s, 9, 31, 9, 22, 2, WHITE, 3), speed_lines(s, 23, 31, 23, 22, 2, WHITE, 3))),
    'GroundPound': R('Brawler', lambda s: (fist(s, 16, 11, 0.9), cracks(s, 26), star(s, 16, 24, 7, 3, 6, YEL, fx=True))),
    'IronFist': R('Brawler', lambda s: (flame(s, 16, 17, 10, 1.2), fist(s, 16, 19, 0.85, glove=(175, 185, 205)), sparkle(s, 9, 15, WHITE, 1))),
    # Swordsman
    'OniSlash': R('Swordsman', lambda s: (sword(s, 6, 26, 26, 6), sword(s, 26, 26, 6, 6), s.line([(3, 29), (29, 3)], RED, 1, True), s.line([(29, 29), (3, 3)], RED, 1, True))),
    'TornadoCut': R('Swordsman', lambda s: (tornado(s, 16, 5, 27, (200, 230, 255)), sword(s, 8, 26, 22, 12))),
    'FlyingSlash': R('Swordsman', lambda s: (wave_slash(s), sword(s, 4, 29, 13, 20))),
    'IronBody': R('Swordsman', lambda s: (shield(s, 16, 16, STEEL), sparkle(s, 25, 6, WHITE, 2))),
    # Sniper
    'LeadPellet': R('Sniper', lambda s: (pellet(s, 22, 14, 5, IRON), speed_lines(s, 3, 14, 15, 14, 4, WHITE, 3))),
    'BlazeShot': R('Sniper', lambda s: (flame(s, 20, 16, 7, 1.2), pellet(s, 20, 18, 3, DARK), speed_lines(s, 2, 18, 11, 18, 3, FIRE1, 3))),
    'SmokePellet': R('Sniper', lambda s: (smoke(s, 16, 18, 1.1), pellet(s, 8, 8, 3, IRON))),
    'EagleEye': R('Sniper', lambda s: eye_star(s)),
    # Sea Cook
    'HookKick': R('Cook', lambda s: (boot(s, 13, 15), s.arc(16, 16, 13, 300, 420, WHITE, 2, True))),
    'BanquetKick': R('Cook', lambda s: (tornado(s, 16, 6, 28, (255, 240, 200)), boot(s, 14, 15))),
    'HeatedLeg': R('Cook', lambda s: (flame(s, 16, 18, 10, 1.3), boot(s, 13, 16, (120, 60, 40)))),
    'HeartyMeal': R('Cook', lambda s: (meat(s), sparkle(s, 6, 6, YEL, 2), sparkle(s, 26, 5, WHITE, 1))),
    # Navigator
    'ThunderCall': R('Navigator', lambda s: (smoke(s, 16, 8, 0.9, (200, 205, 220), (130, 135, 160)), bolt(s, 16, 20, 0.75))),
    'CycloneCall': R('Navigator', lambda s: (tornado(s, 16, 4, 28, (200, 240, 255)), sparkle(s, 25, 22, WHITE, 1))),
    # v0.25.51: the base Navigator fights with a folding baton (storms above = Storm Caller job 2 later)
    'BatonFlurry': R('Navigator', lambda s: (s.line([(6, 26), (24, 8)], (120, 110, 200), 3, True), s.line([(20, 12), (24, 8)], (235, 225, 255), 2, True), speed_lines(s, 14, 22, 28, 22, 3, WHITE, 3), sparkle(s, 26, 6, WHITE, 2))),
    'TrickVault': R('Navigator', lambda s: (s.line([(9, 29), (15, 9)], (120, 110, 200), 3, True), s.arc(14, 18, 11, 200, 330, WHITE, 2, True), boot(s, 22, 20), sparkle(s, 6, 8, WHITE, 1))),
    'MirageVeil': R('Navigator', lambda s: (s.oval(16, 16, 11, 11, (120, 200, 255)), s.oval(13, 16, 9, 9, (190, 230, 255)), s.oval(10, 16, 6, 6, (240, 250, 255)))),
    'Tailwind': R('Navigator', lambda s: (s.poly([(8, 5), (8, 24), (24, 24)], (245, 240, 225)), s.line([(8, 4), (8, 28)], WOOD, 2), wind(s, (210, 245, 255)))),
    # Doctor
    'Heal': R('Doctor', lambda s: (plus(s, 16, 16, 11, WHITE, 4, False), plus(s, 16, 16, 9, (255, 110, 140), 2, True))),
    'Scalpel': R('Doctor', lambda s: (scalpel(s), speed_lines(s, 16, 26, 27, 15, 2, WHITE, 3))),
    'Adrenaline': R('Doctor', lambda s: (syringe(s), bolt(s, 24, 22, 0.35, YEL))),
    'BurstTonic': R('Doctor', lambda s: (flask(s, (180, 255, 120)), star(s, 22, 9, 6, 2.5, 6, YEL, fx=True))),
    # Shipwright
    'HammerSmash': R('Shipwright', lambda s: (hammer(s), star(s, 9, 25, 5, 2, 5, YEL, fx=True))),
    'CannonDrop': R('Shipwright', lambda s: (cannonball(s, 15, 17, 8), speed_lines(s, 15, 2, 15, 7, 3, WHITE, 4))),
    'FieldRepair': R('Shipwright', lambda s: (wrench(s), plus(s, 24, 22, 4, GREEN, 1))),
    'SteelFrame': R('Shipwright', lambda s: (shield(s, 16, 16, (170, 140, 100)), s.line([(6, 9), (26, 9)], IRON, 2), s.line([(16, 4), (16, 26)], IRON, 2))),
    # Bounce
    'F_StretchPistol': R('Bounce', stretch_arm),
    'F_BounceGatling': R('Bounce', gatling),
    'F_BalloonBody': R('Bounce', lambda s: balloon(s)),
    'F_GearUp': R('Bounce', lambda s: (s.oval(16, 16, 11, 11, (255, 120, 150)), fist(s, 16, 17, 0.8), smoke(s, 26, 6, 0.4, (255, 220, 230), (255, 180, 200)), smoke(s, 6, 6, 0.4, (255, 220, 230), (255, 180, 200)))),
    # Blaze
    'F_FireFist': R('Blaze', lambda s: (flame(s, 18, 16, 10, 1.0), fist(s, 19, 18, 0.7, glove=FIRE2), speed_lines(s, 2, 18, 8, 18, 3, FIRE1, 3))),
    'F_FlamePillar': R('Blaze', lambda s: (s.rect(10, 3, 22, 27, FIRE3), s.rect(13, 3, 19, 27, FIRE2), s.rect(15, 6, 17, 26, FIRE1, True), cracks(s, 27, (90, 50, 40)))),
    'F_FireDash': R('Blaze', lambda s: (flame(s, 22, 16, 7, 0.9), speed_lines(s, 2, 16, 15, 16, 5, FIRE2, 2))),
    'F_Inferno': R('Blaze', lambda s: boom(s, 16, 16, 1.0)),
    # Haze
    'F_SmokeGrip': R('Haze', lambda s: (smoke(s, 9, 22, 0.7), hand_open(s, 19, 14, SMOKE1))),
    'F_SmokeScreen': R('Haze', lambda s: (smoke(s, 16, 12, 1.0), smoke(s, 16, 22, 1.0))),
    'F_SmokeBody': R('Haze', lambda s: (smoke(s, 16, 20, 1.0), s.oval(16, 9, 5, 5, SMOKE2), s.oval(16, 9, 3, 3, SMOKE1, True))),
    'F_WhiteOut': R('Haze', lambda s: (tornado(s, 16, 4, 28, SMOKE1), sparkle(s, 6, 8, WHITE, 2))),
    # Ward
    'F_BarrierBash': R('Ward', lambda s: (hexwall(s, CYAN, 0.8, 18, 16), fist(s, 9, 20, 0.6), speed_lines(s, 2, 8, 9, 8, 2))),
    'F_BarrierWall': R('Ward', lambda s: (s.rect(5, 4, 27, 28, CYAN), s.rect(8, 7, 24, 25, lerp(CYAN, WHITE, 0.5)), s.line([(16, 4), (16, 28)], WHITE, 1, True), s.line([(5, 16), (27, 16)], WHITE, 1, True))),
    'F_BarrierCrash': R('Ward', lambda s: (hexwall(s, CYAN, 0.6, 21, 16), speed_lines(s, 2, 16, 12, 16, 4, CYAN, 3))),
    'F_BarrierDome': R('Ward', lambda s: (dome(s, CYAN), sparkle(s, 16, 16, WHITE, 2))),
    # Split
    'F_SplitCannon': R('Split', lambda s: (fist(s, 21, 15, 0.8), s.rect(2, 13, 10, 17, SKIN), s.line([(11, 13), (11, 17)], PURP, 1, True), speed_lines(s, 2, 22, 11, 22, 2, WHITE, 3))),
    'F_ChopRush': R('Split', lambda s: (sword(s, 6, 26, 22, 10), s.line([(4, 6), (28, 6)], PURP, 1, True), s.line([(4, 26), (28, 26)], PURP, 1, True))),
    'F_SplitEscape': R('Split', lambda s: (s.rect(10, 3, 22, 10, SKIN), s.rect(9, 12, 23, 20, (90, 90, 140)), s.rect(10, 22, 22, 29, (60, 60, 100)), speed_lines(s, 26, 6, 30, 6, 1), speed_lines(s, 2, 24, 6, 24, 1))),
    'F_SplitFestival': R('Split', lambda s: (fist(s, 8, 8, 0.45), fist(s, 24, 9, 0.45), fist(s, 9, 24, 0.45), fist(s, 24, 24, 0.45), star(s, 16, 16, 6, 2.5, 6, PURP, fx=True))),
    # Slick
    'F_SlickSlide': R('Slick', lambda s: (drop(s, 20, 16, 0.75, OIL, OIL_HI), speed_lines(s, 2, 16, 12, 16, 4, OIL_HI, 3))),
    'F_SlipAway': R('Slick', lambda s: (drop(s, 16, 18, 0.9, OIL, OIL_HI), sparkle(s, 25, 6, YEL, 2))),
    'F_SlickSpin': R('Slick', lambda s: (s.arc(16, 16, 11, 0, 300, OIL_HI, 3, False), s.arc(16, 16, 6, 60, 360, OIL, 2, False), drop(s, 16, 17, 0.35))),
    'F_OilSlick': R('Slick', lambda s: (s.oval(16, 24, 13, 4, OIL), s.oval(13, 23, 6, 2, OIL_HI, True), drop(s, 16, 11, 0.55))),
}


def shade_and_outline(spr, tile):
    """bevel (lit from the top-left) + 1 px dark outline around the main layer, then the fx layer on top"""
    src = spr.im.load()
    out = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    o = out.load()
    alpha = [[src[x, y][3] > 0 for y in range(N)] for x in range(N)]
    ol = lerp(tile, (10, 8, 20), 0.75)
    for x in range(N):
        for y in range(N):
            if alpha[x][y]:
                r, g, b, _ = src[x, y]
                c = (r, g, b)
                up = y == 0 or not alpha[x][y - 1]
                left = x == 0 or not alpha[x - 1][y]
                down = y == N - 1 or not alpha[x][y + 1]
                right = x == N - 1 or not alpha[x + 1][y]
                if up or left:
                    c = lerp(c, (255, 255, 255), 0.32)
                elif down or right:
                    c = lerp(c, (0, 0, 0), 0.28)
                o[x, y] = c + (255,)
            else:
                near = any(0 <= x + dx < N and 0 <= y + dy < N and alpha[x + dx][y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    o[x, y] = ol + (255,)
    # drop shadow (1 px down-right) under the outline, on the tile
    shadow = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    sp = shadow.load()
    op = out.load()
    for x in range(N - 1):
        for y in range(N - 1):
            if op[x, y][3] and not op[x + 1, y + 1][3]:
                sp[x + 1, y + 1] = (0, 0, 0, 90)
    return shadow, out


def tile_bg(tile):
    bg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    p = bg.load()
    top = lerp(tile, (255, 255, 255), 0.18)
    bot = lerp(tile, (0, 0, 0), 0.45)
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(N):
        for x in range(N):
            # rounded corners (2 px)
            if (x < 2 and y < 2 and x + y < 2) or (x > N - 3 and y < 2 and (N - 1 - x) + y < 2) or (x < 2 and y > N - 3 and x + (N - 1 - y) < 2) or (x > N - 3 and y > N - 3 and (N - 1 - x) + (N - 1 - y) < 2):
                continue
            k = y / (N - 1)
            # radial glow in the middle
            d = math.hypot(x - 15.5, y - 14) / 18
            k = min(1, max(0, k * 0.8 + d * 0.35 - 0.1))
            k2 = (bayer[y % 4][x % 4] / 16 - 0.5) * 0.18
            c = lerp(top, bot, min(1, max(0, k + k2)))
            if x == 0 or y == 0 or x == N - 1 or y == N - 1:
                c = lerp(tile, (10, 8, 20), 0.7)
            elif x == 1 or y == 1:
                c = lerp(tile, (255, 255, 255), 0.45)
            elif x == N - 2 or y == N - 2:
                c = lerp(tile, (0, 0, 0), 0.55)
            p[x, y] = c + (255,)
    return bg


def render(skill_id):
    tile_name, draw = SKILLS[skill_id]
    tile = TILE[tile_name]
    spr = Spr()
    draw(spr)
    shadow, body = shade_and_outline(spr, tile)
    img = tile_bg(tile)
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, body)
    img = Image.alpha_composite(img, spr.fx)
    # keep the frame border on top
    frame = tile_bg(tile).load()
    p = img.load()
    for i in range(N):
        for (x, y) in ((i, 0), (i, N - 1), (0, i), (N - 1, i)):
            p[x, y] = frame[x, y]
    return img.resize((N * SCALE, N * SCALE), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    ids = list(SKILLS)
    for sid in ids:
        render(sid).save(os.path.join(OUT, sid + '.png'))
    # contact sheet for review
    cols = 9
    cell = 140
    rows = math.ceil(len(ids) / cols)
    sheet = Image.new('RGB', (cols * cell, rows * cell), (24, 24, 34))
    d = ImageDraw.Draw(sheet)
    for i, sid in enumerate(ids):
        im = render(sid).resize((112, 112), Image.NEAREST)
        x, y = (i % cols) * cell + 14, (i // cols) * cell + 6
        sheet.paste(im, (x, y), im)
        d.text((x, y + 116), sid.replace('F_', '')[:16], fill=(220, 220, 230))
    sheet.save(os.path.join(ROOT, 'assets', 'skillicons_sheet.png'))
    print('wrote', len(ids), 'skill icons')


if __name__ == '__main__':
    main()
