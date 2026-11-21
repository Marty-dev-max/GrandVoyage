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


def gem(s, c=(90, 210, 255)):
    s.poly([(8, 12), (12, 6), (20, 6), (24, 12), (16, 27)], c)
    s.poly([(8, 12), (24, 12), (16, 27)], lerp(c, DARK, 0.2))
    s.poly([(12, 6), (16, 12), (20, 6)], lerp(c, WHITE, 0.45), True)
    s.px(11, 9, WHITE)


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


def fruit_ward(s):
    s.oval(16, 18, 11, 11, (110, 205, 240))
    for x in (9, 16, 23):
        s.line([(x, 9), (x, 28)], (240, 255, 255), 1, True)
    for y in (13, 19, 25):
        s.line([(6, y), (26, y)], (240, 255, 255), 1, True)
    fruit_stem(s, 16, 6)


def fruit_bounce(s):
    s.oval(16, 19, 10, 9, (170, 70, 200))
    for x, y in ((10, 15), (17, 13), (23, 17), (11, 22), (18, 21), (22, 25), (14, 27)):
        s.oval(x, y, 4, 4, (255, 130, 190))
        s.px(x - 1, y - 2, WHITE)
    fruit_stem(s, 16, 8)


def fruit_split(s):
    for y0, y1, dx in ((8, 13, 0), (15, 21, 2), (23, 28, -1)):
        s.rect(7 + dx, y0, 25 + dx, y1, (80, 190, 100))
        s.rect(9 + dx, y1 - 1, 23 + dx, y1, (215, 170, 255))
    fruit_stem(s, 16, 6)


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


ICONS = {
    # HUD / menus
    'bag': sack, 'skills': lambda s: (star(s, 16, 16, 13, 5, 4, YEL), sparkle(s, 26, 6, WHITE, 2), sparkle(s, 6, 26, WHITE, 1)),
    'scroll': scroll, 'map': map_icon, 'paw': paw, 'chest': chest, 'stats': chart, 'anchor': menu_icon, 'menu': menu_icon,
    'coin': coin, 'gem': gem, 'pearl': pearl, 'crown': crown, 'flag': flag, 'whiteflag': lambda s: flag(s, (245, 245, 245), False),
    'skull': skull, 'party': heads, 'gear': cog, 'merit': merit,
    'dash': dash, 'flame': flame_icon, 'calm': calm_icon, 'auto': auto, 'manual': manual,
    'graphics': monitor, 'audio': speaker, 'interface': window_ui, 'autobattle': robot, 'developer': dev_tools,
    # items
    'egg': egg, 'golden_egg': gold_egg, 'card': card, 'book': book, 'ship': ship, 'charm': charm, 'wood': logs,
    'cloth': cloth, 'ore': lambda s: rock(s, (140, 140, 155), (200, 210, 230)), 'shard': crystal, 'potion': bottle,
    'juice': cup, 'hat': tricorn, 'armor': vest, 'boots': lambda s: boot(s, 14, 16), 'meat': meat, 'bait': worm_hook,
    'repairkit': toolbox, 'medkit': pouch, 'staff': staff, 'slingshot': slingshot, 'knuckles': knuckles,
    'sword': lambda s: sword(s, 6, 26, 26, 6), 'hammer': hammer,
    'fruit_blaze': lambda s: fruit_blaze(s), 'fruit_bounce': lambda s: fruit_bounce(s), 'fruit_haze': lambda s: fruit_haze(s),
    'fruit_slick': lambda s: fruit_slick(s), 'fruit_split': lambda s: fruit_split(s), 'fruit_ward': lambda s: fruit_ward(s),
    # monster materials
    'crabshell': shell, 'monkeyfur': lambda s: fur(s, (150, 100, 60)), 'tigerpelt': lambda s: fur(s, (240, 150, 40), DARK),
    'boartusk': tusk, 'clownpaint': paint_pot, 'catclaw': claw, 'rivet': rivet, 'sharkfin': fin,
    'ingot': ingot, 'gunpowder': powder_keg, 'scale': scale_icon, 'compass': compass, 'poster': poster,
}


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
