#!/usr/bin/env python3
"""Pixel-art UI + item icons (v0.25.3, owner: replace the 3D renders and emoji with pixel art). Same toolkit as the
skill icons (tools/gen_skill_icons.py: 32x32 aliased shapes, lit top-left, dark outline), but on a TRANSPARENT
background because the UI already puts icons on tiles and chips. Names match Config/Icons, so every UI.IconId /
UI.ItemIconId user switches over on upload; new names are wired in UIKit (EMOJI_ICON / ITEM_ICON).

   python3 tools/gen_pixel_icons.py            -> assets/icons/<name>.png + assets/icons_sheet.png
   ROBLOX_API_KEY=... python3 tools/upload_images.py assets/icons src/shared/Config/Icons.lua
"""
import math, os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import gen_skill_icons as K  # noqa: E402
from gen_skill_icons import (Spr, lerp, fist, sword, flame, smoke, bolt, star, shield, heart, plus, sparkle,  # noqa: E402
                             boot, pellet, tornado, hammer, cannonball, wrench, meat, flask, eye, wind, drop,
                             speed_lines, N, SCALE, WHITE, GOLD, GOLD_D, WOOD, WOOD_D, STEEL, STEEL_D, IRON, DARK,
                             RED, PINK, GREEN, YEL, PURP, BROWN, CYAN, FIRE1, FIRE2, FIRE3, SKIN, BLUE)

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons')
OUTLINE = (24, 20, 34)

# ---------- extra shapes ----------
def sack(s, c=(196, 140, 84)):
    s.oval(16, 19, 11, 10, c)
    s.rect(11, 6, 21, 10, lerp(c, WHITE, 0.15))
    s.rect(10, 9, 22, 11, (120, 70, 40))  # drawstring
    s.rect(14, 15, 18, 22, lerp(c, DARK, 0.25))  # patch
    s.px(15, 16, GOLD)


def scroll(s):
    s.rect(8, 7, 24, 25, (240, 222, 176))
    s.rect(6, 5, 26, 8, (200, 160, 100))
    s.rect(6, 24, 26, 27, (200, 160, 100))
    for y in (11, 14, 17, 20):
        s.line([(11, y), (21 if y != 20 else 17, y)], (150, 120, 80), 1, True)


def chart(s):
    s.rect(4, 26, 28, 28, (230, 230, 240))
    for x, h, c in ((7, 8, (90, 200, 255)), (14, 14, (120, 220, 120)), (21, 20, (255, 190, 60))):
        s.rect(x, 26 - h, x + 4, 26, c)
    s.line([(6, 18), (13, 13), (19, 15), (27, 5)], RED, 2, True)


def anchor(s, c=(180, 196, 220)):
    s.oval(16, 6, 3, 3, c)
    s.rect(15, 8, 17, 25, c)
    s.rect(10, 11, 22, 13, c)
    s.arc(16, 18, 9, 30, 150, c, 3, False)
    s.poly([(5, 20), (9, 18), (8, 23)], c)
    s.poly([(27, 20), (23, 18), (24, 23)], c)


def coin(s, cx=16, cy=16, r=11):
    s.oval(cx, cy, r, r, GOLD)
    s.oval(cx, cy, r - 3, r - 3, (255, 225, 110))
    s.rect(cx - 1, cy - 5, cx + 1, cy + 5, GOLD_D)
    s.px(cx - 5, cy - 6, WHITE)


# v0.25.31 (owner: the gem looked squeezed): a wide brilliant cut with real facets. Crown = bright table between a
# light left and a mid right bezel; pavilion = light / mid / dark thirds meeting at the culet; a hot highlight.
def fgem(s, cx, cy, w, h, c, shine=True):
    hw = w / 2.0
    top, girdle, bot = cy - h * 0.42, cy - h * 0.12, cy + h * 0.58
    lite, hot = lerp(c, WHITE, 0.35), lerp(c, WHITE, 0.7)
    mid, dark = c, lerp(c, DARK, 0.4)
    s.poly([(cx - hw, girdle), (cx - hw * 0.35, girdle), (cx, bot)], lerp(c, WHITE, 0.12))
    s.poly([(cx - hw * 0.35, girdle), (cx + hw * 0.35, girdle), (cx, bot)], mid)
    s.poly([(cx + hw * 0.35, girdle), (cx + hw, girdle), (cx, bot)], dark)
    s.poly([(cx - hw, girdle), (cx - hw * 0.55, top), (cx - hw * 0.35, girdle)], lite)
    s.poly([(cx - hw * 0.55, top), (cx + hw * 0.55, top), (cx + hw * 0.35, girdle), (cx - hw * 0.35, girdle)], hot)
    s.poly([(cx + hw * 0.55, top), (cx + hw, girdle), (cx + hw * 0.35, girdle)], lerp(c, WHITE, 0.05))
    if shine and w >= 10:
        s.px(round(cx - hw * 0.3), round(top + 1), WHITE)
        s.px(round(cx - hw * 0.3) + 1, round(top + 1), WHITE)


def gem(s, c=(90, 210, 255)):
    fgem(s, 16, 15, 26, 22, c)
    sparkle(s, 26, 6, WHITE, 2)


def crown(s):
    s.poly([(5, 24), (5, 10), (11, 16), (16, 7), (21, 16), (27, 10), (27, 24)], GOLD)
    s.rect(5, 22, 27, 26, GOLD_D)
    for x, c in ((11, RED), (16, (90, 200, 255)), (21, GREEN)):
        s.rect(x - 1, 23, x + 1, 25, c, True)


def flag(s, c=(30, 30, 40), sym=True):
    s.rect(6, 4, 8, 29, WOOD)
    s.poly([(8, 5), (27, 7), (24, 13), (27, 19), (8, 18)], c)
    if sym:
        s.oval(16, 11, 3, 3, WHITE, True)
        s.line([(12, 15), (20, 15)], WHITE, 1, True)


def skull(s):
    s.oval(16, 13, 10, 9, (240, 236, 222))
    s.rect(11, 18, 21, 25, (240, 236, 222))
    s.rect(10, 11, 14, 15, DARK)
    s.rect(18, 11, 22, 15, DARK)
    s.rect(15, 17, 17, 19, DARK)
    for x in (13, 16, 19):
        s.line([(x, 22), (x, 25)], (150, 150, 140), 1, True)


def egg(s, c=(245, 235, 210), spots=(120, 200, 230)):
    s.oval(16, 17, 9, 11, c)
    for x, y in ((12, 13), (19, 18), (14, 22)):
        s.oval(x, y, 2, 2, spots)
    s.px(12, 9, WHITE)


def card(s):
    s.rect(7, 4, 25, 28, (250, 245, 230))
    s.rect(9, 6, 23, 18, (110, 160, 230))
    star(s, 16, 12, 5, 2, 5, YEL, fx=True)
    for y in (21, 24):
        s.line([(10, y), (22, y)], (150, 140, 120), 1, True)


# v0.25.95 (owner): card icons by monster type (Config/MonsterTypes colors): cream card, art window in the type color
# with the type's sign (STR fist, AGI wind, DEX crosshair, INT orb), type-colored footer band.
TYPE_COL = {'STR': (230, 60, 55), 'AGI': (70, 200, 90), 'DEX': (60, 140, 240), 'INT': (170, 80, 230)}


def type_card(t):
    def draw(s):
        c = TYPE_COL[t]
        s.rect(7, 3, 25, 28, (250, 245, 230))
        s.rect(9, 5, 23, 19, c)
        s.rect(9, 5, 23, 6, lerp(c, WHITE, 0.35))
        if t == 'STR':
            fist(s, 16, 13, 0.62)
        elif t == 'AGI':
            for y, x0 in ((9, 11), (12, 13), (15, 10)):
                s.line([(x0, y + 1), (x0 + 10, y - 1)], WHITE, 1, True)
            s.poly([(18, 8), (22, 10), (19, 12)], WHITE)
        elif t == 'DEX':
            s.oval(16, 12, 5, 5, WHITE)
            s.oval(16, 12, 3, 3, c)
            s.oval(16, 12, 1, 1, RED if c != RED else WHITE)
            s.line([(16, 5), (16, 8)], WHITE, 1, True)
            s.line([(16, 16), (16, 19)], WHITE, 1, True)
        else:
            s.oval(16, 12, 4, 4, lerp(c, WHITE, 0.55))
            s.oval(15, 11, 1, 1, WHITE)
            star(s, 21, 7, 2, 1, 4, YEL, fx=True)
        s.rect(9, 22, 23, 26, c)
        s.line([(11, 24), (21, 24)], lerp(c, WHITE, 0.5), 1, True)
    return draw


def book(s, c=(70, 110, 200)):
    s.rect(6, 6, 25, 27, c)
    s.rect(9, 6, 25, 25, (245, 240, 225))
    s.rect(6, 6, 9, 27, lerp(c, DARK, 0.3))
    for y in (11, 15, 19):
        s.line([(12, y), (22, y)], (150, 140, 120), 1, True)


def ship(s):
    s.poly([(3, 20), (29, 20), (25, 27), (7, 27)], (150, 95, 55))
    s.rect(3, 19, 29, 21, (110, 70, 40))
    s.rect(15, 4, 17, 20, WOOD_D)
    s.poly([(17, 5), (27, 16), (17, 16)], (245, 240, 225))
    s.poly([(15, 7), (7, 16), (15, 16)], (230, 225, 210))
    s.poly([(17, 3), (23, 5), (17, 7)], RED)


def charm(s, c=(200, 80, 220)):
    s.arc(16, 12, 8, 200, 340, GOLD, 2, False)
    s.oval(16, 20, 6, 6, GOLD)
    s.oval(16, 20, 4, 4, c)
    s.px(14, 18, WHITE)


def logs(s):
    for y, x0 in ((20, 4), (12, 8)):
        s.rect(x0, y - 4, x0 + 20, y + 4, WOOD)
        s.oval(x0 + 20, y, 4, 4, (220, 180, 120))
        s.oval(x0 + 20, y, 2, 2, WOOD)


def cloth(s):
    s.rect(5, 9, 27, 25, (245, 242, 232))
    s.rect(5, 15, 27, 18, RED)
    s.rect(5, 9, 27, 11, lerp((245, 242, 232), WHITE, 0.5))
    s.line([(5, 21), (27, 21)], (210, 205, 195), 1, True)


def rock(s, c=(140, 140, 155), crystal=None):
    s.poly([(4, 26), (8, 14), (14, 10), (22, 12), (28, 22), (26, 27)], c)
    if crystal:
        s.poly([(13, 18), (15, 6), (18, 18)], crystal)
        s.poly([(18, 20), (22, 10), (24, 21)], lerp(crystal, WHITE, 0.2))


def crystal(s, c=(90, 230, 220)):
    s.poly([(16, 3), (24, 12), (20, 29), (12, 29), (8, 12)], c)
    s.poly([(16, 3), (16, 29), (12, 29), (8, 12)], lerp(c, WHITE, 0.3))
    sparkle(s, 25, 6, WHITE, 1)


def pearl(s):
    s.oval(16, 17, 10, 10, (245, 240, 250))
    s.oval(13, 13, 3, 3, WHITE, True)
    s.oval(19, 21, 4, 3, (215, 205, 235))


def bottle(s, c=RED):
    s.rect(13, 3, 19, 8, (200, 160, 110))
    s.rect(14, 7, 18, 11, (220, 235, 245))
    s.oval(16, 20, 9, 9, (220, 235, 245))
    s.oval(16, 21, 7, 7, c)
    s.px(13, 17, WHITE)


def cup(s, c=(255, 170, 60)):
    s.poly([(8, 8), (24, 8), (22, 27), (10, 27)], (230, 240, 250))
    s.poly([(9, 12), (23, 12), (21, 26), (11, 26)], c)
    s.oval(21, 9, 4, 4, (255, 150, 40))
    s.line([(18, 3), (15, 14)], (255, 255, 255), 1, True)


def tricorn(s, c=(60, 44, 40)):
    s.poly([(3, 20), (16, 10), (29, 20), (16, 16)], c)
    s.rect(9, 13, 23, 19, lerp(c, WHITE, 0.08))
    s.rect(9, 18, 23, 20, GOLD)
    skull_tiny = (240, 236, 222)
    s.rect(15, 14, 17, 16, skull_tiny, True)


def vest(s, c=(70, 120, 210)):
    s.poly([(7, 6), (13, 6), (16, 10), (19, 6), (25, 6), (27, 27), (5, 27)], c)
    s.rect(15, 10, 17, 27, lerp(c, WHITE, 0.6))
    for y in (14, 19, 24):
        s.px(18, y, GOLD, False)


def cog(s, c=(170, 178, 196)):
    for i in range(8):
        a = i * math.pi / 4
        s.rect(16 + math.cos(a) * 11 - 2, 16 + math.sin(a) * 11 - 2, 16 + math.cos(a) * 11 + 2, 16 + math.sin(a) * 11 + 2, c)
    s.oval(16, 16, 10, 10, c)
    s.oval(16, 16, 4, 4, (60, 64, 80))


def heads(s):
    for x, c, hair in ((11, (100, 170, 240), (60, 40, 30)), (21, (240, 130, 90), (230, 190, 80))):
        s.rect(x - 6, 18, x + 6, 28, c)
        s.rect(x - 4, 7, x + 4, 15, SKIN)
        s.rect(x - 5, 5, x + 5, 8, hair)
        s.px(x - 2, 11, DARK, False)
        s.px(x + 2, 11, DARK, False)


def worm_hook(s):
    s.line([(16, 3), (16, 20)], STEEL, 2)
    s.arc(12, 20, 4, 0, 180, STEEL, 2, False)
    s.oval(19, 22, 4, 3, PINK)
    s.oval(22, 19, 3, 3, PINK)


def toolbox(s):
    s.rect(4, 13, 28, 27, RED)
    s.rect(4, 13, 28, 16, lerp(RED, WHITE, 0.25))
    s.rect(12, 8, 20, 10, IRON)
    s.rect(11, 8, 13, 13, IRON)
    s.rect(19, 8, 21, 13, IRON)
    s.rect(14, 18, 18, 21, GOLD)


def pouch(s):
    s.oval(16, 19, 10, 9, (240, 230, 220))
    s.rect(11, 8, 21, 12, (240, 230, 220))
    plus(s, 16, 19, 5, RED, 1, False)
    s.line([(9, 11), (23, 11)], (200, 70, 90), 2)


def staff(s):
    s.line([(7, 28), (22, 9)], (90, 120, 200), 3)
    s.oval(24, 7, 4, 4, (120, 220, 255))
    bolt(s, 24, 7, 0.3, YEL)
    s.line([(11, 23), (14, 19)], GOLD, 3)


def slingshot(s):
    s.line([(16, 29), (16, 17)], WOOD, 3)
    s.line([(16, 18), (9, 6)], WOOD, 3)
    s.line([(16, 18), (23, 6)], WOOD, 3)
    s.line([(9, 7), (16, 14), (23, 7)], (150, 90, 70), 1, True)
    pellet(s, 16, 14, 2, IRON)


def knuckles(s):
    # v0.25.6 (owner): the Brawler fights bare-fisted, so this is a fist, not knuckle dusters
    fist(s, 16, 17, 1.25)
    sparkle(s, 26, 6, YEL, 2)


def fruit(s, c, swirl):
    s.oval(16, 18, 11, 10, c)
    # curls (little spirals), not stripes: stripes read as a frowning face at this size
    for cx, cy, r in ((11, 15, 3), (20, 13, 3), (17, 22, 3)):
        s.arc(cx, cy, r, 0, 300, swirl, 1, True)
        s.px(cx, cy, swirl)
    s.line([(16, 8), (19, 3)], (80, 130, 50), 2)
    s.poly([(19, 4), (26, 3), (22, 8)], GREEN)
    s.px(10, 14, WHITE)


# fruits v2 (match the voxel models of v0.25.5)
def fruit_stem(s, x=16, y=7):
    s.line([(x, y + 2), (x + 1, y - 2), (x + 4, y - 3)], (70, 150, 120), 2)
    s.poly([(x - 1, y - 2), (x - 7, y - 3), (x - 3, y + 1)], GREEN)


def fruit_blaze(s):
    s.oval(16, 19, 10, 9, (235, 90, 30))
    for x, y in ((9, 14), (14, 11), (20, 12), (24, 17), (11, 21), (18, 19), (22, 24), (13, 26)):
        s.poly([(x - 3, y + 3), (x, y - 4), (x + 3, y + 3)], (255, 170, 40))
        s.poly([(x - 1, y + 2), (x, y - 1), (x + 1, y + 2)], (255, 225, 90), True)
    fruit_stem(s, 16, 8)


def fruit_haze(s):
    for x, y, r in ((10, 19, 6), (22, 19, 6), (16, 14, 7), (16, 23, 6), (11, 13, 4), (21, 13, 4)):
        s.oval(x, y, r, r, (236, 238, 246))
    for x, y in ((13, 17), (19, 20), (15, 21)):
        s.line([(x, y), (x + 3, y)], (160, 156, 186), 1, True)
    fruit_stem(s, 16, 6)


def fruit_bounce(s):
    s.oval(16, 19, 10, 9, (255, 120, 190))  # v0.25.33 (owner): purple bulges over pink creases
    for x, y in ((10, 15), (17, 13), (23, 17), (11, 22), (18, 21), (22, 25), (14, 27)):
        s.oval(x, y, 4, 4, (175, 70, 215))
        s.px(x - 1, y - 2, WHITE)
    fruit_stem(s, 16, 8)


def fruit_slick(s):
    drop(s, 16, 17, 1.0, (120, 86, 34), (240, 220, 110))
    s.rect(9, 18, 12, 22, (240, 220, 110), True)
    s.rect(14, 27, 15, 30, (80, 60, 25))
    s.rect(20, 26, 21, 29, (80, 60, 25))


def monitor(s):
    s.rect(4, 6, 28, 22, (60, 66, 84))
    s.rect(6, 8, 26, 20, (90, 180, 255))
    s.poly([(6, 20), (14, 12), (19, 16), (26, 10), (26, 20)], (100, 220, 120))
    s.rect(14, 22, 18, 26, (60, 66, 84))
    s.rect(9, 26, 23, 28, (60, 66, 84))


def speaker(s):
    s.rect(5, 12, 11, 20, (160, 168, 190))
    s.poly([(11, 12), (19, 5), (19, 27), (11, 20)], (160, 168, 190))
    for r in (5, 9):
        s.arc(19, 16, r, 300, 420, WHITE, 2, True)


def window_ui(s):
    s.rect(4, 6, 28, 26, (230, 232, 245))
    s.rect(4, 6, 28, 10, (120, 100, 230))
    s.rect(24, 7, 27, 9, RED, True)
    s.rect(7, 13, 14, 23, (180, 190, 220))
    for y in (14, 17, 20):
        s.line([(17, y), (25, y)], (150, 150, 170), 1, True)


def keyboard(s):
    # v0.25.44: Settings -> Hotkeys. A keyboard: dark case, rows of light key caps, a long space bar, one gold key
    s.rect(3, 9, 29, 25, (70, 76, 98))
    for row, (y, n, off) in enumerate(((11, 6, 5), (15, 6, 6), (19, 5, 7))):
        for i in range(n):
            x = off + i * 4
            s.rect(x, y, x + 2, y + 2, GOLD if (row == 1 and i == 2) else (220, 224, 240), True)
    s.rect(9, 22, 23, 23, (220, 224, 240), True)


def robot(s):
    s.rect(7, 9, 25, 24, (170, 180, 200))
    s.rect(10, 13, 13, 16, CYAN, True)
    s.rect(19, 13, 22, 16, CYAN, True)
    s.rect(12, 19, 20, 21, DARK)
    s.line([(16, 9), (16, 4)], STEEL_D, 1)
    s.oval(16, 4, 2, 2, RED)
    s.rect(5, 14, 7, 19, STEEL_D)
    s.rect(25, 14, 27, 19, STEEL_D)


def dev_tools(s):
    hammer(s)
    s.line([(24, 26), (14, 16)], STEEL, 3)
    s.oval(26, 28, 3, 3, STEEL)


def dash(s):
    boot(s, 19, 15)
    speed_lines(s, 1, 9, 11, 9, 2, WHITE, 3)
    speed_lines(s, 1, 20, 9, 20, 2, WHITE, 3)
    for x, y in ((6, 27), (10, 28), (3, 26)):
        s.rect(x, y, x + 1, y + 1, (220, 210, 190), True)


def auto(s):
    sword(s, 6, 26, 26, 6)
    sword(s, 26, 26, 6, 6)
    s.oval(16, 16, 6, 6, (40, 160, 90))
    s.rect(15, 12, 17, 20, WHITE, True)
    s.rect(13, 14, 19, 15, WHITE, True)


def manual(s):
    # a pointing hand (you aim and click yourself)
    s.rect(13, 3, 17, 16, SKIN)
    s.rect(9, 14, 25, 26, SKIN)
    for x in (18, 21):
        s.rect(x, 11, x + 2, 16, SKIN)
    s.rect(6, 15, 10, 21, SKIN)
    s.rect(10, 26, 24, 29, (90, 150, 230))
    s.px(14, 4, WHITE, False)


def fur(s, c, stripe=None):
    s.poly([(4, 22), (8, 8), (14, 12), (18, 6), (24, 11), (28, 24), (20, 27), (12, 26)], c)
    for x in (9, 15, 21):
        s.line([(x, 12), (x + 2, 22)], stripe or lerp(c, DARK, 0.3), 2, False)


def shell(s):
    s.oval(16, 18, 12, 9, (230, 110, 70))
    for x in (8, 13, 18, 23):
        s.line([(16, 26), (x, 11)], (180, 70, 50), 1, True)
    s.rect(4, 24, 28, 27, (200, 90, 60))


def tusk(s):
    s.arc(22, 22, 14, 180, 260, (245, 240, 220), 4, False)
    s.oval(9, 23, 3, 3, (210, 200, 180))


def paint_pot(s):
    s.rect(8, 12, 24, 27, (230, 230, 240))
    s.rect(8, 12, 24, 15, RED)
    s.poly([(10, 12), (14, 6), (17, 12)], RED)
    s.oval(20, 8, 2, 2, (90, 200, 255), True)


def claw(s):
    for x in (9, 16, 23):
        s.poly([(x - 2, 26), (x + 2, 26), (x + 4, 8), (x + 1, 12)], (240, 235, 220))


def rivet(s):
    s.oval(16, 12, 9, 5, (170, 175, 190))
    s.rect(13, 12, 19, 27, (140, 145, 160))


def fin(s, c=(110, 140, 170)):
    s.poly([(4, 27), (14, 4), (28, 27)], c)
    s.poly([(10, 27), (15, 12), (20, 27)], lerp(c, WHITE, 0.3))


def ingot(s, c=(170, 178, 196)):
    s.poly([(4, 24), (9, 14), (27, 14), (28, 24)], c)
    s.poly([(9, 14), (13, 10), (24, 10), (27, 14)], lerp(c, WHITE, 0.3))


def powder_keg(s):
    s.rect(8, 9, 24, 27, (150, 95, 55))
    for y in (11, 18, 25):
        s.rect(7, y, 25, y + 1, IRON)
    s.line([(16, 9), (19, 4)], (60, 50, 40), 1)
    star(s, 20, 4, 3, 1, 5, YEL, fx=True)


def scale_icon(s):
    for x, y in ((10, 12), (20, 12), (15, 20)):
        s.poly([(x - 6, y), (x, y - 6), (x + 6, y), (x, y + 7)], (70, 200, 190))
        s.px(x - 1, y - 2, WHITE)


def compass(s):
    s.oval(16, 16, 12, 12, GOLD)
    s.oval(16, 16, 9, 9, (245, 240, 225))
    s.poly([(16, 7), (19, 16), (16, 25), (13, 16)], RED)
    s.poly([(16, 16), (19, 16), (16, 25), (13, 16)], (60, 70, 90))


def poster(s):
    s.rect(6, 4, 26, 28, (240, 222, 176))
    s.rect(9, 9, 23, 20, (200, 170, 120))
    s.oval(16, 14, 4, 4, (120, 90, 60))
    s.line([(9, 24), (23, 24)], (120, 90, 60), 2, True)


def map_icon(s):
    s.poly([(4, 8), (11, 5), (20, 8), (28, 5), (28, 26), (20, 29), (11, 26), (4, 29)], (240, 222, 176))
    s.line([(11, 5), (11, 26)], (200, 180, 140), 1, True)
    s.line([(20, 8), (20, 29)], (200, 180, 140), 1, True)
    s.line([(7, 22), (13, 16), (18, 19)], (200, 120, 80), 1, True)
    s.line([(21, 11), (25, 15)], RED, 2, True)
    s.line([(25, 11), (21, 15)], RED, 2, True)


def paw(s, c=(240, 180, 120)):
    s.oval(16, 21, 7, 6, c)
    for x, y in ((8, 13), (13, 8), (19, 8), (24, 13)):
        s.oval(x, y, 3, 3, c)


def chest(s):
    s.rect(4, 14, 28, 27, (160, 100, 55))
    s.poly([(4, 14), (8, 7), (24, 7), (28, 14)], (190, 120, 65))
    s.rect(4, 13, 28, 15, GOLD)
    s.rect(14, 13, 18, 19, GOLD)
    s.rect(15, 16, 17, 17, DARK)


# v0.25.29 (owner reference: a real backpack, a real shop front) in the same 32px lit-top-left style
def backpack(s):
    body, dark, flap = (214, 74, 140), (160, 46, 104), (248, 150, 62)
    s.arc(16, 7, 3, 180, 360, (110, 64, 40), w=2)  # small top loop
    s.rect(4, 13, 6, 25, (120, 70, 44))  # shoulder straps peeking out at the sides
    s.rect(26, 13, 28, 25, (120, 70, 44))
    s.poly([(11, 7), (21, 7), (25, 10), (26, 14), (26, 28), (6, 28), (6, 14), (7, 10)], body)  # domed top
    s.rect(4, 21, 6, 26, dark)  # side pockets
    s.rect(26, 21, 28, 26, dark)
    s.rect(9, 20, 23, 27, dark)  # front pocket
    s.rect(10, 21, 22, 21, lerp(dark, WHITE, 0.25))  # pocket seam
    s.poly([(10, 8), (22, 8), (25, 11), (25, 17), (16, 20), (7, 17), (7, 11)], flap)  # flap over the top
    s.rect(10, 9, 22, 9, lerp(flap, WHITE, 0.35))  # flap highlight
    s.rect(14, 16, 18, 19, GOLD)  # buckle
    s.px(16, 17, DARK)


def shopfront(s):
    wood, wood_d = (188, 124, 70), (130, 80, 44)
    s.rect(6, 15, 26, 28, wood)  # stall body
    s.rect(9, 18, 23, 24, (70, 44, 56))  # open window
    s.rect(10, 21, 12, 23, (90, 210, 255))  # goods: a gem
    s.oval(16, 22, 2, 2, GOLD)  # a coin
    s.rect(20, 20, 21, 23, (90, 220, 110))  # a potion
    s.px(20, 19, WHITE)
    s.rect(5, 24, 27, 27, lerp(wood, WHITE, 0.2))  # counter
    s.rect(5, 27, 27, 28, wood_d)
    s.rect(7, 3, 25, 6, wood_d)  # sign board
    s.rect(9, 4, 23, 5, GOLD)
    for i in range(6):  # striped awning
        c = (232, 76, 62) if i % 2 == 0 else (255, 226, 160)
        s.poly([(3 + i * 4.4, 8), (7.4 + i * 4.4, 8), (8.4 + i * 4.4, 14), (2 + i * 4.4, 14)], c)
        s.oval(5.2 + i * 4.4, 14, 2.2, 1.6, c)  # scalloped edge


def market_stall(s):
    # v0.25.36 (owner reference): an open market stall, red/white scalloped awning, two posts, empty plank counter
    wood, wood_l, wood_d = (214, 160, 98), (236, 196, 136), (150, 100, 56)
    s.rect(5, 4, 26, 5, (196, 200, 214))  # awning rod
    for i in range(6):
        c = (226, 62, 58) if i % 2 == 0 else (250, 244, 236)
        s.poly([(4 + i * 4, 6), (8 + i * 4, 6), (8.6 + i * 4, 12), (3.4 + i * 4, 12)], c)
        s.oval(6 + i * 4, 12.5, 2, 1.5, c)  # scalloped edge
    s.rect(6, 14, 7, 21, wood)  # posts
    s.rect(24, 14, 25, 21, wood)
    s.rect(3, 21, 28, 22, wood_l)  # counter top
    s.rect(4, 23, 27, 25, wood)  # two planks
    s.rect(4, 26, 27, 28, wood)
    s.rect(4, 25, 27, 25, wood_d)
    s.rect(5, 29, 26, 29, wood_d)


# fruit-themed UI particles (v0.25.36, owner): Panels / UI.RarityFx float these around a fruit's tile and stage
def pt_swirl(s):
    for i in range(260):
        a = i * 0.075
        r = 1 + i * 0.045
        c = (255, 140, 210) if (i // 40) % 2 == 0 else (190, 90, 235)
        for dx, dy in ((0, 0), (1, 0), (0, 1)):  # 2 px thick line
            s.px(int(16 + math.cos(a) * r) + dx, int(16 + math.sin(a) * r) + dy, c)


def pt_cloud(s):
    for cx, cy, r in ((11, 18, 6), (18, 14, 7), (23, 19, 5)):
        s.oval(cx, cy, r, r * 0.85, (226, 230, 240))
    s.oval(17, 21, 9, 3, (186, 190, 204))


def pt_hex(s):
    pts = [(16 + math.cos(math.radians(60 * i + 30)) * 12, 16 + math.sin(math.radians(60 * i + 30)) * 12) for i in range(6)]
    s.poly(pts, (90, 220, 255))
    inner = [(16 + math.cos(math.radians(60 * i + 30)) * 8, 16 + math.sin(math.radians(60 * i + 30)) * 8) for i in range(6)]
    s.poly(inner, (20, 40, 70))


def pt_slice(s):
    s.oval(16, 16, 12, 6, (90, 200, 110))
    s.oval(16, 16, 10, 4, (220, 180, 255))
    for x in (11, 16, 21):
        s.px(x, 16, (60, 40, 70))


def menu_icon(s):
    anchor(s, (210, 220, 240))


def flame_icon(s):
    flame(s, 16, 18, 10, 1.3)


def calm_icon(s):
    s.oval(16, 18, 9, 9, (90, 110, 160))
    s.oval(19, 15, 8, 8, (0, 0, 0))  # bite: punched out below
    sparkle(s, 24, 8, (200, 220, 255), 1)
    sparkle(s, 8, 9, (200, 220, 255), 1)


def gold_egg(s):
    egg(s, GOLD, (255, 240, 160))
    sparkle(s, 25, 7, WHITE, 2)


def merit(s):
    s.poly([(10, 3), (16, 10), (22, 3)], (60, 110, 220))
    s.oval(16, 19, 9, 9, GOLD)
    star(s, 16, 19, 6, 2.5, 5, (255, 240, 160), fx=True)


# ---------- Store icons (v0.25.12, owner: pretty pixel art for every Store entry) ----------
GLYPH = {  # 3x5 pixel font
    '2': ['###', '..#', '###', '#..', '###'], 'x': ['...', '#.#', '.#.', '#.#', '...'],
    '1': ['.#.', '##.', '.#.', '.#.', '###'], '0': ['###', '#.#', '#.#', '#.#', '###'], '3': ['###', '..#', '.##', '..#', '###'],
    'S': ['###', '#..', '###', '..#', '###'], 'M': ['#.#', '###', '###', '#.#', '#.#'], 'L': ['#..', '#..', '#..', '#..', '###'],
}


def text(s, x, y, t, c=WHITE):
    for ch in t:
        for j, row in enumerate(GLYPH[ch]):
            for i, v in enumerate(row):
                if v == '#':
                    s.px(x + i, y + j, c)
        x += 4


def badge(s, t, c=(220, 50, 60)):
    w = len(t) * 4 + 3
    s.rect(31 - w, 22, 31, 30, c)
    text(s, 33 - w, 24, t)


# v0.25.55 (owner): potion sizes S / M / L carry a gold letter disc (reference: HP / SP potion picker)
def size_disc(s, t, cx=26, cy=26):
    s.oval(cx, cy, 5, 5, (255, 214, 90))
    s.oval(cx, cy, 4, 4, (240, 170, 40))
    text(s, cx - 1, cy - 2, t, (90, 40, 20))


# v0.25.56 (owner references): S = round manga meat on the bone, M = three roast drumsticks, L = a big roast with the
# marbled cut face and the bone through its middle
ROAST, ROAST_HI, ROAST_D = (165, 88, 45), (205, 130, 75), (110, 55, 30)
FLESH, FLESH_D = (245, 190, 180), (205, 115, 110)
BONE, BONE_D = (248, 244, 232), (205, 198, 182)


def bone(s, x0, y0, x1, y1, w=3):
    s.line([(x0, y0), (x1, y1)], BONE, w)
    dx, dy = x1 - x0, y1 - y0
    n = max(1, math.hypot(dx, dy))
    px_, py_ = -dy / n * 2, dx / n * 2  # the knuckle's two knobs, across the bone
    s.oval(round(x1 + px_), round(y1 + py_), 2, 2, BONE)
    s.oval(round(x1 - px_), round(y1 - py_), 2, 2, BONE)


def meat_s(s):
    # v0.25.58 (owner: sizes must differ like the drinks): a small piece, about half the slot
    bone(s, 13, 21, 9, 26, 2)
    s.oval(17, 17, 6, 6, ROAST)
    s.oval(15, 15, 3, 2, ROAST_HI, True)
    s.px(14, 13, WHITE)
    s.px(20, 20, ROAST_D, True)


def meat_m(s):
    # three drumsticks side by side, back to front, each a step lower (owner reference), about two thirds of the slot
    for i, x in enumerate((21, 15, 9)):
        y = 4 + i * 2
        pts = [(x + 2, 6 + y, 3.4), (x + 1, 9 + y, 3.1), (x + 1, 12 + y, 2.7), (x, 14 + y, 2.2)]
        for cx, cy, r in pts:  # dark rim first so neighbours stay apart
            s.oval(cx, cy, round(r) + 1, round(r) + 1, ROAST_D)
        for cx, cy, r in pts:
            s.oval(cx, cy, round(r), round(r), ROAST)
        s.oval(x + 2, 6 + y, 1, 2, ROAST_HI, True)
        s.oval(x, 16 + y, 2, 1, FLESH)
        s.line([(x - 1, 17 + y), (x - 2, 20 + y)], BONE, 1)
        s.oval(x - 2, 21 + y, 1, 1, BONE)


def meat_l(s):
    # the full slot (v0.25.58): a big roast with the marbled cut face and the bone through its middle
    s.rect(10, 5, 27, 29, ROAST)
    s.oval(27, 17, 4, 12, ROAST)
    s.rect(11, 6, 26, 8, ROAST_HI, True)  # glaze shine along the top
    for x in (15, 20, 25):  # glaze drips
        s.line([(x, 8), (x, 12)], ROAST_D, 1, True)
    s.oval(10, 17, 8, 12, FLESH)  # the cut face: marbled rings
    s.oval(10, 17, 6, 9, FLESH_D)
    s.oval(10, 17, 4, 7, FLESH)
    s.oval(10, 17, 2, 4, FLESH_D)
    s.oval(10, 17, 1, 1, BONE, True)
    bone(s, 9, 17, 2, 17)


def meat_size(t):
    body = {'S': meat_s, 'M': meat_m, 'L': meat_l}[t]

    def draw(s):
        body(s)
        size_disc(s, t)
    return draw


# SP drinks (v0.25.57, owner references): the sizes must read at a glance, not only by the letter.
# S = a small barrel tankard with the drink splashing over, M = an upright barrel, L = a big keg on its side.
OAK, OAK_HI, OAK_D = (170, 112, 62), (205, 150, 95), (118, 74, 40)
HOOP, HOOP_HI = (88, 90, 104), (150, 154, 170)


def grog_s(s):
    liquid = (255, 170, 60)
    x0, x1, y0, y1 = 9, 19, 16, 29
    s.rect(x0, y0, x1, y1, OAK)
    for x in (12, 16):
        s.line([(x, y0 + 1), (x, y1 - 1)], OAK_D, 1)
    for y in (18, 26):
        s.rect(x0 - 1, y, x1 + 1, y + 1, (200, 170, 80))
    s.arc(21, 23, 3, 280, 440, OAK_D, 2, False)
    lc = lerp(liquid, WHITE, 0.35)
    s.oval(14, 15, 6, 2, liquid)
    s.oval(11, 12, 2, 2, liquid)
    s.oval(16, 11, 2, 3, liquid)
    s.px(15, 9, lc)
    s.px(8, 9, lc)
    s.px(20, 10, lc)


def grog_m(s):
    liquid = (90, 220, 140)
    s.rect(8, 8, 22, 29, OAK)
    s.rect(6, 11, 24, 26, OAK)  # the bulge
    for x in (11, 15, 19):
        s.line([(x, 9), (x, 28)], OAK_D, 1)
    s.rect(9, 12, 10, 25, OAK_HI, True)
    for y in (10, 18, 26):
        s.rect(6 if y == 18 else 7, y, 24 if y == 18 else 23, y + 1, HOOP)
        s.px(9, y, HOOP_HI, True)
    s.oval(15, 8, 7, 2, OAK_HI)  # lid, drink brimming over it
    s.oval(15, 7, 5, 2, liquid)
    s.oval(19, 5, 2, 2, liquid)
    s.px(12, 4, lerp(liquid, WHITE, 0.35))
    s.line([(22, 8), (24, 14)], liquid, 1, True)  # a trickle down the side


def grog_l(s):
    liquid = (80, 170, 255)
    s.rect(7, 6, 27, 28, OAK)  # body lying on its side
    s.rect(9, 4, 25, 30, OAK)
    for y in (10, 15, 20, 25):
        s.line([(10, y), (27, y)], OAK_D, 1)
    s.rect(11, 6, 26, 7, OAK_HI, True)
    for x in (13, 22):  # iron hoops round the body
        s.rect(x, 4, x + 1, 30, HOOP)
        s.px(x, 7, HOOP_HI, True)
    s.oval(7, 17, 6, 12, HOOP)  # the round end facing us
    s.oval(7, 17, 5, 11, OAK_HI)
    for y in (11, 15, 19, 23):
        s.line([(3, y), (11, y)], OAK, 1, True)
    s.oval(7, 22, 1, 1, (40, 30, 24), True)  # bung hole...
    s.line([(6, 24), (4, 28)], liquid, 2, True)  # ...spilling the drink
    s.oval(3, 29, 2, 1, liquid)


# Cursed Fruit marker (owner reference): a black fruit silhouette with a white question mark and a white aura
# Toki (v0.25.88, owner references): Armament = a fist hardened dark blue-black with white shine streaks in a violet
# aura; Observation = a wide-open glowing eye with sense rays; Conqueror = a crown crackling with lightning
def toki_arm(s):
    # fist seen from the front, fingers curled toward the viewer, forearm running off to the right (owner reference)
    D, M, L = (22, 26, 74), (40, 50, 140), (90, 110, 230)
    s.rect(18, 11, 31, 21, D)  # forearm
    s.poly([(9, 7), (19, 7), (21, 9), (21, 22), (19, 24), (9, 24)], M)  # fist body, cut corners
    for i, y in enumerate((9, 13, 17, 21)):  # four curled fingers bulging toward the viewer (left)
        s.oval(8, y + 1, 4, 2, M)
        s.line([(5, y), (6, y)], L, 1, True)
        s.line([(6, y + 3), (12, y + 3)], D, 1, True)
    s.poly([(12, 5), (19, 5), (21, 8), (14, 10), (11, 8)], M)  # thumb over the top
    s.line([(13, 5), (18, 5)], L, 1, True)
    for pts in (((21, 13), (30, 12)), ((22, 17), (31, 18)), ((15, 13), (18, 12))):
        s.line(list(pts), WHITE, 1, True)
    for x, y in ((5, 10), (5, 14), (5, 18), (14, 6)):
        s.px(x, y, WHITE)
    for a0, a1, r in ((100, 200, 14), (200, 260, 13), (60, 110, 13), (250, 300, 15)):  # violet aura wisps
        s.arc(14, 15, r, a0, a1, (160, 140, 255), 1, True)


def toki_obs(s):
    for a in range(0, 360, 30):  # sense rays
        r0, r1 = 12, 15
        x, y = math.cos(math.radians(a)), math.sin(math.radians(a))
        s.line([(16 + x * r0, 16 + y * r0 * 0.8), (16 + x * r1, 16 + y * r1 * 0.8)], (160, 230, 255), 1, True)
    s.poly([(3, 16), (10, 9), (22, 9), (29, 16), (22, 23), (10, 23)], (236, 244, 255))
    s.oval(16, 16, 6, 6, (40, 170, 230))
    s.oval(16, 16, 4, 4, (120, 230, 255), True)
    s.oval(16, 16, 2, 2, DARK, True)
    s.px(14, 14, WHITE)
    s.line([(4, 15), (10, 8), (22, 8), (28, 15)], (40, 50, 90), 1, True)  # lid line


def toki_conq(s):
    s.poly([(5, 25), (5, 11), (11, 17), (16, 8), (21, 17), (27, 11), (27, 25)], GOLD)
    s.rect(5, 23, 27, 27, GOLD_D)
    for x, c in ((11, RED), (16, (200, 90, 255)), (21, RED)):
        s.rect(x - 1, 24, x + 1, 26, c, True)
    for pts in (((3, 4), (6, 8), (4, 9), (8, 14)), ((29, 3), (26, 7), (28, 8), (24, 13)), ((16, 0), (14, 3), (17, 4), (15, 6))):
        s.line(list(pts), (210, 120, 255), 1, True)  # black-violet lightning around the crown
    s.px(16, 13, WHITE)


# fruits matching the v0.25.85 models: Shield = round shield with hex glass plates; Split = three drifting slices
def fruit_ward(s):
    s.oval(16, 18, 12, 12, (40, 80, 175))  # rim
    s.oval(16, 18, 10, 10, (70, 160, 225))
    for x, y in ((16, 18), (16, 11), (16, 25), (10, 14), (22, 14), (10, 22), (22, 22)):
        s.poly([(x - 2, y - 3), (x + 2, y - 3), (x + 4, y), (x + 2, y + 3), (x - 2, y + 3), (x - 4, y)], (45, 125, 215))
        s.poly([(x - 1, y - 2), (x + 1, y - 2), (x + 3, y), (x + 1, y + 2), (x - 1, y + 2), (x - 3, y)], (190, 242, 255))
        s.px(x - 1, y - 2, WHITE)
    for a in (45, 135, 225, 315):
        s.px(16 + math.cos(math.radians(a)) * 11, 18 + math.sin(math.radians(a)) * 11, GOLD, True)
    fruit_stem(s, 16, 6)


def fruit_split(s):
    # a round fruit cut in three slices that drift apart sideways; lilac flesh + pale rind on each top cut
    cy, r = 18, 11
    for y0, y1, dx in ((7, 12, 2), (14, 20, -2), (22, 29, 2)):
        for y in range(y0, y1 + 1):
            t = (y - cy) / r
            hw = int(round(r * math.sqrt(max(0.0, 1 - t * t))))
            if hw > 0:
                s.rect(16 - hw + dx, y, 16 + hw + dx, y, (80, 190, 100))
        t = (y0 - cy) / r
        hw = int(round(r * math.sqrt(max(0.0, 1 - t * t))))
        if y0 > 8:
            s.rect(16 - hw + 1 + dx, y0, 16 + hw - 1 + dx, y0, (205, 245, 160), True)
            s.rect(16 - hw + 3 + dx, y0, 16 + hw - 3 + dx, y0, (200, 150, 250), True)
            s.px(16 + dx - 3, y0, (80, 30, 120))
            s.px(16 + dx + 3, y0, (80, 30, 120))
    s.line([(10, 16), (12, 15)], (40, 125, 62), 1, True)
    s.line([(19, 25), (22, 24)], (40, 125, 62), 1, True)
    fruit_stem(s, 18, 5)


def fruit_unknown(s):
    aura = (255, 255, 255)
    ink = (22, 20, 28)
    # white aura: a fat halo around the body + the stem
    s.oval(16, 20, 13, 11, aura)
    s.line([(16, 12), (15, 3)], aura, 5)
    s.oval(21, 4, 4, 4, aura)
    # black fruit + a thick stem that curls over to the right (owner reference)
    s.oval(16, 20, 11, 9, ink)
    s.line([(16, 12), (15, 3)], ink, 3)
    s.arc(20, 4, 3, 170, 470, ink, 2, False)
    q = WHITE
    s.arc(16, 17, 4, 180, 400, q, 2, True)
    s.line([(18, 20), (16, 22), (16, 24)], q, 2, True)
    s.rect(15, 26, 17, 28, q, True)


def round_arrow(s, cx, cy, r, c):
    s.arc(cx, cy, r, 200, 520, c, 2, True)
    s.poly([(cx + r - 3, cy - 1), (cx + r + 3, cy - 1), (cx + r, cy + 3)], c, True)


def st_fruit_remover(s):
    fruit(s, (130, 210, 90), (70, 150, 60))
    s.line([(19, 19), (29, 29)], (230, 40, 50), 3, True)
    s.line([(29, 19), (19, 29)], (230, 40, 50), 3, True)


def st_reset_stats(s):
    chart(s)
    s.oval(23, 9, 7, 7, (40, 44, 70))
    round_arrow(s, 23, 9, 5, (120, 255, 160))


def st_boss_respawn(s):
    skull(s)
    s.poly([(8, 9), (8, 3), (12, 6), (16, 1), (20, 6), (24, 3), (24, 9)], GOLD, True)
    s.px(16, 4, RED)
    round_arrow(s, 25, 24, 5, (120, 255, 160))


def st_notifier(s):
    s.oval(16, 16, 13, 13, (30, 70, 50))
    s.oval(16, 16, 10, 10, (40, 110, 70))
    s.arc(16, 16, 6, 0, 360, (90, 200, 120), 1, False)
    s.poly([(16, 16), (27, 10), (27, 16)], (120, 255, 160), True)
    s.oval(21, 21, 3, 3, (255, 120, 60), True)
    s.px(21, 18, GREEN)
    sparkle(s, 21, 21, WHITE, 1)


def st_exp(s):
    star(s, 14, 14, 13, 5.5, 5, YEL)
    star(s, 14, 14, 7, 3, 5, (255, 250, 200), fx=True)
    sparkle(s, 27, 5, WHITE, 2)
    badge(s, 'x2', (60, 170, 255))


def st_drop(s):
    sack(s, (230, 180, 60))
    coin(s, 7, 24, 5)
    sparkle(s, 26, 5, WHITE, 2)
    badge(s, 'x2', (220, 60, 160))


def mini_gem(s, x, y, c=(90, 210, 255), k=1.0):
    fgem(s, x, y, 9 * k, 8 * k, c, shine=False)


GEM_C = (90, 210, 255)
GEM_COLS = ((90, 210, 255), (200, 110, 255), (90, 230, 160), (255, 120, 170))


def gem_heap(s, x0, x1, y_base, h, seed=0):
    """a mound of small faceted gems, back row first so the front ones overlap"""
    s.poly([(x0, y_base), (x0 + (x1 - x0) * 0.25, y_base - h * 0.8), ((x0 + x1) / 2, y_base - h),
            (x0 + (x1 - x0) * 0.75, y_base - h * 0.8), (x1, y_base)], lerp(GEM_C, DARK, 0.25))
    rows = [(y_base - h * 0.75, 0.55), (y_base - h * 0.35, 0.85), (y_base, 1.0)]
    i = seed
    for y, span in rows:
        n = max(2, int((x1 - x0) * span / 6))
        for k in range(n):
            x = (x0 + x1) / 2 + ((k + 0.5) / n - 0.5) * (x1 - x0) * span
            fgem(s, x, y - 2, 7, 6, GEM_COLS[i % len(GEM_COLS)], shine=False)
            i += 1


# Pile of Gems (small pack): three big faceted gems stacked
def st_gems_s(s):
    fgem(s, 10, 22, 14, 12, (90, 210, 255))
    fgem(s, 22, 22, 14, 12, (200, 110, 255))
    fgem(s, 16, 12, 16, 14, (90, 230, 160))
    sparkle(s, 26, 6, WHITE, 2)
    sparkle(s, 5, 10, WHITE, 1)


# Chest of Gems (medium): an open chest overflowing, gems spilling at its foot
def st_gems_m(s):
    wood, wood_d = (176, 108, 58), (120, 70, 38)
    s.poly([(5, 13), (8, 5), (24, 5), (27, 13)], wood_d)  # lid thrown back
    s.rect(8, 6, 24, 7, GOLD)
    s.rect(4, 17, 28, 28, wood)  # box
    s.rect(4, 17, 28, 18, GOLD)
    s.rect(4, 22, 28, 23, wood_d)
    s.rect(14, 19, 18, 24, GOLD)  # lock plate
    s.px(16, 21, DARK)
    gem_heap(s, 5, 27, 18, 8, 1)
    fgem(s, 6, 28, 7, 6, (255, 120, 170), shine=False)  # spilled
    fgem(s, 26, 28, 7, 6, GEM_C, shine=False)
    sparkle(s, 27, 3, WHITE, 2)


# Trophy of Gems (big): a gold cup heaped with gems, handles, pedestal
def st_gems_l(s):
    gold_d = lerp(GOLD, DARK, 0.35)
    s.rect(11, 26, 21, 29, gold_d)  # pedestal
    s.rect(13, 23, 19, 26, GOLD)  # stem
    s.poly([(5, 13), (27, 13), (24, 20), (19, 23), (13, 23), (8, 20)], GOLD)  # bowl
    s.rect(5, 13, 27, 14, lerp(GOLD, WHITE, 0.45))  # rim light
    s.arc(5, 17, 3, 90, 270, gold_d, w=2)  # handles
    s.arc(27, 17, 3, 270, 450, gold_d, w=2)
    gem_heap(s, 6, 26, 13, 9, 2)
    sparkle(s, 4, 5, WHITE, 2)
    sparkle(s, 28, 4, WHITE, 2)


def st_ticket(s):
    s.rect(3, 9, 29, 23, (230, 70, 80))
    for y in (12, 16, 20):
        s.px(3, y, (0, 0, 0))
        s.px(29, y, (0, 0, 0))
    s.rect(9, 9, 10, 23, (255, 220, 120), True)
    star(s, 19, 16, 5, 2.2, 5, (255, 230, 120), fx=True)


def st_stall(s):
    s.rect(5, 15, 27, 28, (190, 130, 80))
    s.rect(7, 18, 25, 22, (120, 80, 50))
    for i, x in enumerate(range(3, 29, 4)):
        s.rect(x, 7, x + 3, 14, (230, 70, 80) if i % 2 == 0 else (250, 245, 235))
    s.rect(3, 5, 29, 7, (150, 90, 60))
    coin(s, 11, 19, 3)
    mini_gem(s, 21, 19, (90, 210, 255), 0.7)
    badge(s, '2', (60, 170, 90))


# v0.25.97: materials that shared art get their own (rarer twin = richer colors)
def logs_gold(s):
    for y, x0 in ((20, 4), (12, 8)):
        s.rect(x0, y - 4, x0 + 20, y + 4, (190, 120, 50))
        s.line([(x0 + 2, y - 1), (x0 + 16, y - 1)], GOLD, 1, True)
        s.oval(x0 + 20, y, 4, 4, GOLD)
        s.oval(x0 + 20, y, 2, 2, (200, 120, 40))
    sparkle(s, 6, 6, YEL, 2)
    sparkle(s, 27, 27, WHITE, 1)


def crystal_pure(s):
    crystal(s, (235, 250, 255))
    s.poly([(16, 9), (19, 14), (16, 22), (13, 14)], (150, 240, 255))
    sparkle(s, 6, 24, CYAN, 1)


def marine_badge(s):
    s.poly([(7, 6), (25, 6), (25, 17), (16, 28), (7, 17)], (50, 90, 170))
    s.poly([(9, 8), (23, 8), (23, 16), (16, 25), (9, 16)], (235, 240, 250))
    s.oval(16, 10, 1.5, 1.5, (50, 90, 170))
    s.rect(15.5, 11, 16.5, 21, (50, 90, 170))
    s.rect(12, 13, 20, 14, (50, 90, 170))
    s.arc(16, 17, 4, 30, 150, (50, 90, 170), 1, False)
    s.rect(7, 4, 25, 6, GOLD)


# ---------- v0.25.97 (owner: weapon tiers need their own look): one icon per weapon line + grade ----------
# w_<WeaponType>_<Grade>; grades go wood/plain -> steel -> themed -> ornate gold -> Supreme (glow + sparkles)
GRADES = ['Plain', 'Keen', 'Master', 'Grand', 'Supreme']


def tier_fx(s, g):
    if g >= 4:
        sparkle(s, 27, 5, YEL if g == 4 else WHITE, 2)
    if g == 5:
        sparkle(s, 5, 8, CYAN, 1)
        sparkle(s, 26, 26, PINK, 1)


def katana(s, blade, edge, guard, grip, w=3, gw=4, x0=6, y0=26, x1=26, y1=6):
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy, nx, ny = dx / L, dy / L, -dy / L, dx / L
    gx, gy = x0 + ux * 6, y0 + uy * 6
    s.line([(gx + ux, gy + uy), (x1, y1)], blade, w)
    s.line([(gx + ux * 2 - nx, gy + uy * 2 - ny), (x1 - ux * 2, y1 - uy * 2)], edge, 1, True)
    s.line([(gx - nx * gw, gy - ny * gw), (gx + nx * gw, gy + ny * gw)], guard, 2)
    s.line([(x0, y0), (gx - ux, gy - uy)], grip, 3)
    return gx, gy


def w_sword(g):
    def draw(s):
        if g == 1:  # Driftwood Katana
            katana(s, (200, 160, 110), (235, 205, 160), WOOD_D, (170, 130, 80))
        elif g == 2:  # Seagull Katana
            gx, gy = katana(s, STEEL, WHITE, GOLD, (245, 245, 250))
            s.oval(gx, gy, 2, 2, GOLD)
            s.px(7, 24, DARK)
            s.px(9, 22, DARK)
        elif g == 3:  # Tidecutter
            gx, gy = katana(s, (110, 200, 245), WHITE, (40, 90, 170), (30, 50, 110), 4)
            s.arc(gx + 1, gy - 1, 4, 180, 330, CYAN, 2, False)
        elif g == 4:  # Moonwave Blade
            gx, gy = katana(s, (215, 205, 255), WHITE, GOLD, (110, 60, 170), 4, 5, 5, 27, 27, 4)
            s.oval(gx, gy, 3, 3, GOLD)
            s.oval(gx + 1, gy - 1, 2, 2, (0, 0, 0))
        else:  # Stormfang
            katana(s, (60, 60, 95), YEL, GOLD, (30, 30, 40), 4, 5, 5, 27, 27, 4)
            bolt(s, 22, 12, 0.35, YEL)
        tier_fx(s, g)
    return draw


def w_sling(g):
    frame = [(130, 90, 50), (225, 175, 70), (150, 95, 55), (110, 90, 220), (245, 240, 230)][g - 1]
    band = [(150, 90, 70), (120, 70, 50), (120, 70, 50), GOLD, CYAN][g - 1]
    w = 2 if g == 1 else 3

    def draw(s):
        s.line([(16, 29), (16, 17)], frame, w)
        s.line([(16, 18), (9, 6)], frame, w)
        s.line([(16, 18), (23, 6)], frame, w)
        s.rect(14, 23, 18, 26, band)
        s.line([(9, 7), (16, 14), (23, 7)], (150, 90, 70) if g < 5 else CYAN, 1, True)
        if g == 3:  # Falcon Sling: feathers on the fork tips
            for x, d in ((9, -1), (23, 1)):
                s.poly([(x, 6), (x + 5 * d, 2), (x + 6 * d, 6), (x + 2 * d, 9)], (245, 240, 225))
                s.line([(x + 2 * d, 4), (x + 5 * d, 4)], BROWN, 1, True)
        if g == 4:  # Stardrop: star at the fork
            star(s, 16, 18, 5, 2, 5, YEL)
        if g == 5:  # Skybreaker
            bolt(s, 16, 18, 0.35, YEL)
        pellet(s, 16, 14, 2, IRON if g < 4 else (120, 220, 255))
        tier_fx(s, g)
    return draw


def w_leg(g):
    # owner: Sea Cook fights bare-legged: a bare leg + foot with wraps, no boot
    wrap = [(240, 232, 210), (210, 60, 60), STEEL, (210, 60, 40), (250, 250, 255)][g - 1]

    def draw(s):
        if g == 4:
            flame(s, 9, 22, 6, 1.2)
        if g == 5:
            for x, y, r in ((6, 27, 4), (12, 28, 4), (19, 28, 4), (25, 27, 4)):
                s.oval(x, y, r, r - 1, (235, 245, 255))
        s.poly([(10, 3), (17, 3), (18, 18), (26, 20), (27, 25), (9, 25)], SKIN)
        s.rect(9, 24, 27, 25, lerp(SKIN, DARK, 0.3))
        s.rect(10, 15, 18, 19, wrap)  # ankle wrap
        if g >= 2:
            s.rect(10, 6, 17, 8, wrap)
        if g == 3:  # Iron Leg: shin plate
            s.rect(10, 6, 17, 14, STEEL)
            s.line([(11, 7), (11, 13)], WHITE, 1, True)
        tier_fx(s, g)
    return draw


def w_fist(g):
    def draw(s):
        k = 1.35 if g == 5 else 1.2
        if g == 4:
            bolt(s, 26, 9, 0.45, YEL)
        fist(s, 15, 17, k)
        tape = [(245, 242, 232), (245, 242, 232), (90, 120, 150), (250, 215, 60), GOLD][g - 1]
        s.rect(15 - 6 * k, 17 + 5.5 * k, 15 + 5 * k, 17 + 5.5 * k + 3, tape)  # wrist wrap
        if g == 2:  # Iron Fists: plate over the knuckles
            s.rect(15 - 6.5 * k, 17 - 6.5 * k, 15 + 6.5 * k, 17 - 3.5 * k, IRON)
        if g == 3:  # Sharktooth: teeth on the knuckles
            for i in range(4):
                x = 15 - 5.5 * k + i * 3.4 * k
                s.poly([(x, 17 - 6 * k), (x + 1.6 * k, 17 - 10 * k), (x + 3 * k, 17 - 6 * k)], (250, 250, 240))
        if g == 5:  # Titan: gold knuckle plate
            s.rect(15 - 6.5 * k, 17 - 6.5 * k, 15 + 6.5 * k, 17 - 3.5 * k, GOLD)
        tier_fx(s, g)
    return draw


def w_baton(g):
    def draw(s):
        a, b = (7, 27), (24, 7)
        if g == 1:  # Bamboo Staff
            s.line([a, b], (120, 190, 80), 3)
            for t in (0.25, 0.5, 0.75):
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                s.rect(x - 1, y - 1, x + 1, y + 1, (80, 130, 50))
        elif g == 2:  # Deckhand Baton
            s.line([a, b], WOOD, 3)
            s.line([(7, 27), (9, 25)], IRON, 4)
            s.line([(22, 9), (24, 7)], IRON, 4)
        elif g == 3:  # Folding Baton
            s.line([a, b], STEEL, 3)
            for t in (0.33, 0.66):
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                s.rect(x - 1.5, y - 1.5, x + 1.5, y + 1.5, IRON)
            s.line([(7, 27), (10, 24)], DARK, 3)
        elif g == 4:  # Tide Baton
            s.line([a, (22, 9)], (40, 80, 170), 3)
            s.oval(24, 7, 4, 4, CYAN)
            s.arc(24, 7, 3, 200, 340, WHITE, 1, True)
            s.line([(10, 24), (12, 21)], GOLD, 3)
        else:  # Mariner's Rod
            s.line([a, (22, 9)], GOLD, 3)
            s.oval(24, 7, 5, 5, GOLD)
            s.oval(24, 7, 3, 3, (40, 70, 140))
            star(s, 24, 7, 3, 1, 4, WHITE, -90, True)
        tier_fx(s, g)
    return draw


def w_pouch(g):
    bag = [(120, 170, 80), (240, 230, 220), (250, 250, 255), (255, 170, 210), GOLD][g - 1]
    tie = [(80, 60, 40), (200, 70, 90), (80, 130, 220), (200, 80, 160), RED][g - 1]

    def draw(s):
        if g >= 3:  # powder puff
            for x, y, r in ((26, 9, 3), (23, 5, 2), (28, 4, 2)):
                s.oval(x, y, r, r, (245, 245, 255) if g < 5 else YEL)
        s.oval(15, 20, 10, 9, bag)
        s.rect(10, 9, 20, 13, bag)
        s.line([(8, 12), (22, 12)], tie, 2)
        if g == 1:  # Herb Pouch: a leaf
            s.poly([(11, 22), (15, 16), (19, 19), (15, 24)], (60, 140, 60))
            s.line([(11, 23), (17, 18)], (40, 100, 40), 1, True)
        elif g == 4:
            star(s, 15, 20, 5, 2, 4, WHITE)
        else:
            plus(s, 15, 20, 5, {2: RED, 3: BLUE, 5: WHITE}[g], 1, False)
        tier_fx(s, g)
    return draw


def w_hammer(g):
    head, face, L, W = [((200, 150, 100), WOOD_D, 6.0, 3.0), (IRON, DARK, 7.2, 3.3), ((70, 74, 88), DARK, 8.4, 4.0),
                        ((190, 90, 50), (120, 50, 30), 8.4, 4.0), (GOLD, GOLD_D, 9.0, 4.3)][g - 1]

    def draw(s):
        hx, hy = 1 / math.sqrt(2), -1 / math.sqrt(2)
        ax, ay = -hy, hx
        cx, cy = 18.6, 12.6

        def pt(u, v):
            return (cx + ax * u + hx * v, cy + ay * u + hy * v)
        s.line([(7, 27), pt(0, -W + 0.5)], WOOD if g < 5 else (120, 60, 40), 3)
        s.line([(7, 27), (10, 24)], (110, 70, 40) if g < 4 else GOLD, 3)
        s.poly([pt(-L, -W), pt(L, -W), pt(L, W), pt(-L, W)], head)
        s.poly([pt(-L, -W), pt(-L + 2.2, -W), pt(-L + 2.2, W), pt(-L, W)], face)
        s.poly([pt(L - 2.2, -W), pt(L, -W), pt(L, W), pt(L - 2.2, W)], face)
        if g == 3:  # Keel Breaker: rivets
            for u in (-3, 0, 3):
                x, y = pt(u, 0)
                s.px(round(x), round(y), STEEL)
        if g == 4:  # Galley Maul: gold bands
            s.poly([pt(-L + 2.6, -W), pt(-L + 3.6, -W), pt(-L + 3.6, W), pt(-L + 2.6, W)], GOLD)
            s.poly([pt(L - 3.6, -W), pt(L - 2.6, -W), pt(L - 2.6, W), pt(L - 3.6, W)], GOLD)
        s.poly([pt(-L + 2.6, W - 1.4), pt(L - 2.6, W - 1.4), pt(L - 2.6, W - 0.4), pt(-L + 2.6, W - 0.4)],
               WHITE if g == 5 else STEEL, True)
        tier_fx(s, g)
    return draw


# v0.25.112 (owner): the Musket Ball as it flies in game = a chunky lead BLOCK ball (cube with stepped corners), lit
# top-left like every icon; (a flight streak read as a pencil tip).
def lead_ball(s, cx, cy, r):
    lt, md, dk = (132, 130, 146), (78, 76, 88), (46, 44, 52)
    c = max(1, r // 3)  # stepped corner = voxel look, not a smooth circle
    s.rect(cx - r, cy - r + c, cx + r, cy + r - c, md)
    s.rect(cx - r + c, cy - r, cx + r - c, cy + r, md)
    s.rect(cx - r + c, cy + r - c, cx + r, cy + r, dk)        # shade bottom
    s.rect(cx + r - c, cy - r + c, cx + r, cy + r - c, dk)    # shade right
    s.rect(cx - r + c, cy - r, cx + r - c - 1, cy - r + c, lt)  # lit top
    s.rect(cx - r, cy - r + c, cx - r + c, cy + r - c - 1, lt)  # lit left
    s.rect(cx - r + c, cy - r + c, cx - r + 2 * c, cy - r + 2 * c, WHITE)  # glint


def musket_ball(s):
    lead_ball(s, 16, 16, 10)


WEAPON_GRADE_ICONS = {}
for _wt, _fn in (('Sword', w_sword), ('Slingshot', w_sling), ('Shoes', w_leg), ('Knuckles', w_fist),
                 ('StormBaton', w_baton), ('MedKit', w_pouch), ('Hammer', w_hammer)):
    for _i, _g in enumerate(GRADES):
        WEAPON_GRADE_ICONS['w_%s_%s' % (_wt, _g)] = _fn(_i + 1)


def sailor_vest(s):
    """acc_SailorVest (owner: the 3/4 projection read as a half blue/gray block): open blue vest over a striped shirt"""
    blue, white, navy, gold = (60, 110, 200), (245, 245, 250), (36, 52, 110), (250, 200, 70)
    s.poly([(8, 6), (24, 6), (26, 10), (26, 28), (6, 28), (6, 10)], white)
    for y in (12, 16, 20, 24):
        s.rect(6, y, 26, y + 1, navy)
    s.poly([(9, 5), (13, 5), (16, 17), (16, 28), (6, 28), (6, 15), (8, 12)], lerp(blue, white, 0.12))
    s.poly([(23, 5), (19, 5), (16, 17), (16, 28), (26, 28), (26, 15), (24, 12)], lerp(blue, (0, 0, 0), 0.12))
    s.line([(13, 5), (16, 17)], white, 1)
    s.line([(19, 5), (16, 17)], white, 1)
    s.rect(6, 27, 26, 28, white)
    s.line([(16, 17), (16, 27)], lerp(blue, (0, 0, 0), 0.35), 1)
    for y in (19, 23):
        s.px(17, y, gold, False)
        s.px(18, y, gold, False)
    s.rect(8, 20, 12, 22, lerp(blue, (0, 0, 0), 0.25))


ICONS = {
    # HUD / menus
    'bag': backpack, 'shop': shopfront, 'stall': market_stall, 'pt_swirl': pt_swirl, 'pt_cloud': pt_cloud,
    'pt_hex': pt_hex, 'pt_slice': pt_slice, 'pt_flame': lambda s: flame(s, 16, 18, 10, 1.3),
    'pt_drop': lambda s: drop(s, 16, 17, 1.0, (120, 86, 34), (240, 220, 110)), 'skills': lambda s: (star(s, 16, 16, 13, 5, 4, YEL), sparkle(s, 26, 6, WHITE, 2), sparkle(s, 6, 26, WHITE, 1)),
    'scroll': scroll, 'map': map_icon, 'paw': paw, 'chest': chest, 'stats': chart, 'anchor': menu_icon, 'menu': menu_icon,
    'coin': coin, 'gem': gem, 'pearl': pearl, 'crown': crown, 'flag': flag, 'whiteflag': lambda s: flag(s, (245, 245, 245), False),
    'skull': skull, 'party': heads, 'gear': cog, 'merit': merit,
    'dash': dash, 'flame': flame_icon, 'calm': calm_icon, 'auto': auto, 'manual': manual,
    'graphics': monitor, 'audio': speaker, 'interface': window_ui, 'autobattle': robot, 'developer': dev_tools, 'keyboard': keyboard,
    # items
    'egg': egg, 'golden_egg': gold_egg, 'card': card, 'card_STR': type_card('STR'), 'card_AGI': type_card('AGI'), 'card_DEX': type_card('DEX'), 'card_INT': type_card('INT'), 'book': book, 'ship': ship, 'charm': charm, 'wood': logs,
    'cloth': cloth, 'ore': lambda s: rock(s, (140, 140, 155), (200, 210, 230)), 'shard': crystal, 'potion': bottle,
    'meat_s': meat_size('S'), 'meat_m': meat_size('M'), 'meat_l': meat_size('L'),
    'grog_s': lambda s: (grog_s(s), size_disc(s, 'S')), 'grog_m': lambda s: (grog_m(s), size_disc(s, 'M')),
    'grog_l': lambda s: (grog_l(s), size_disc(s, 'L')),
    'fruit_unknown': fruit_unknown, 'toki_arm': toki_arm, 'toki_obs': toki_obs, 'toki_conq': toki_conq,
    'juice': cup, 'hat': tricorn, 'armor': vest, 'boots': lambda s: boot(s, 14, 16), 'meat': meat, 'bait': worm_hook,
    'repairkit': toolbox, 'medkit': pouch, 'staff': staff, 'slingshot': slingshot, 'knuckles': knuckles,
    'sword': lambda s: sword(s, 6, 26, 26, 6), 'hammer': hammer,
    'fruit_blaze': lambda s: fruit_blaze(s), 'fruit_bounce': lambda s: fruit_bounce(s), 'fruit_haze': lambda s: fruit_haze(s),
    'fruit_slick': lambda s: fruit_slick(s), 'fruit_split': lambda s: fruit_split(s), 'fruit_ward': lambda s: fruit_ward(s),
    # monster materials
    'crabshell': shell, 'monkeyfur': lambda s: fur(s, (150, 100, 60)), 'tigerpelt': lambda s: fur(s, (240, 150, 40), DARK),
    'boartusk': tusk, 'clownpaint': paint_pot, 'catclaw': claw, 'rivet': rivet, 'sharkfin': fin,
    # store
    'st_fruit_remover': st_fruit_remover, 'st_reset_stats': st_reset_stats, 'st_boss_respawn': st_boss_respawn,
    'st_notifier': st_notifier, 'st_exp': st_exp, 'st_drop': st_drop, 'st_gems_s': st_gems_s, 'st_gems_m': st_gems_m,
    'st_gems_l': st_gems_l, 'st_ticket': st_ticket, 'st_stall': st_stall,
    'ingot': ingot, 'gunpowder': powder_keg, 'scale': scale_icon, 'compass': compass, 'poster': poster,
}
ICONS.update(WEAPON_GRADE_ICONS)
ICONS.update({'musket_ball': musket_ball, 'acc_SailorVest': sailor_vest, 'wood_gold': logs_gold, 'shard_pure': crystal_pure, 'badge': marine_badge})


def render(name):
    spr = Spr()
    ICONS[name](spr)
    # black (0,0,0) pixels are "holes" (wrench mouth, moon bite): clear them before shading
    px = spr.im.load()
    for x in range(N):
        for y in range(N):
            r, g, b, a = px[x, y]
            if a and r == 0 and g == 0 and b == 0:
                px[x, y] = (0, 0, 0, 0)
    shadow, body = K.shade_and_outline(spr, OUTLINE)
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, body)
    img = Image.alpha_composite(img, spr.fx)
    return img.resize((N * SCALE, N * SCALE), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sorted(ICONS)
    for n in names:
        render(n).save(os.path.join(OUT, n + '.png'))
    cols, cell = 10, 120
    rows = math.ceil(len(names) / cols)
    sheet = Image.new('RGB', (cols * cell, rows * cell), (44, 46, 64))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        im = render(n).resize((96, 96), Image.NEAREST)
        x, y = (i % cols) * cell + 12, (i // cols) * cell + 4
        sheet.paste(im, (x, y), im)
        d.text((x, y + 100), n[:15], fill=(220, 220, 230))
    sheet.save(os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons_sheet.png'))
    print('wrote', len(names), 'pixel icons')


if __name__ == '__main__':
    main()
