#!/usr/bin/env python3
"""Pixel-art island emblems for the sea map (v0.25.19, owner: map tiles show each island's landmark, like a stamp
with a ribbon). 64x56 scenes, flat shapes + top-left bevel + dark outline (same look as gen_pixel_icons.py), the
ribbon at the bottom is left blank: the game writes our island name on it.
   python3 tools/gen_island_icons.py   -> assets/icons/isl_<IslandId>.png (+ assets/island_icons_sheet.png)
   ROBLOX_API_KEY=... python3 tools/upload_images.py assets/icons src/shared/Config/Icons.lua
"""
import os
from PIL import Image, ImageDraw

W, H, SCALE = 64, 56, 6
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons')
OUTLINE = (24, 20, 34)
WHITE = (255, 255, 255)


def lerp(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))


class C:
    def __init__(self):
        self.im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=c + (255,))

    def oval(self, cx, cy, rx, ry, c):
        self.d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c + (255,))

    def poly(self, pts, c):
        self.d.polygon(pts, fill=c + (255,))

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((x, y), c + (255,))


def finish(c):
    src = c.im.load()
    out = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    o = out.load()
    a = [[src[x, y][3] > 0 for y in range(H)] for x in range(W)]
    for x in range(W):
        for y in range(H):
            if a[x][y]:
                col = src[x, y][:3]
                if y == 0 or not a[x][y - 1] or x == 0 or not a[x - 1][y]:
                    col = lerp(col, WHITE, 0.28)
                elif y == H - 1 or not a[x][y + 1] or x == W - 1 or not a[x + 1][y]:
                    col = lerp(col, (0, 0, 0), 0.25)
                o[x, y] = col + (255,)
            elif any(0 <= x + dx < W and 0 <= y + dy < H and a[x + dx][y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o[x, y] = OUTLINE + (255,)
    return out.resize((W * SCALE, H * SCALE), Image.NEAREST)


# ---------- shared pieces ----------
SEA, SEA_D, FOAM = (60, 170, 230), (40, 120, 200), (220, 245, 255)
SAND, GRASS, GRASS_D, ROCK, ROCK_D = (240, 214, 150), (110, 200, 80), (70, 150, 60), (150, 140, 130), (110, 100, 95)
RIB, RIB_D = (170, 110, 60), (120, 70, 40)


def base(c, top=26, grass=GRASS, rock=False):
    c.oval(32, 41, 30, 9, SEA_D)
    c.oval(32, 40, 28, 7, SEA)
    for x in (8, 20, 44, 56):
        c.rect(x, 41, x + 3, 41, FOAM)
    c.oval(32, 37, 23, 7, ROCK if rock else SAND)
    c.oval(32, 34, 21, 7, grass)
    c.rect(11, 34 - (37 - top) // 3, 53, 34, grass)


def ribbon(c):
    c.poly([(2, 46), (10, 46), (10, 54), (6, 51), (2, 54)], RIB_D)
    c.poly([(54, 46), (62, 46), (62, 54), (58, 51), (54, 54)], RIB_D)
    c.rect(8, 44, 56, 52, RIB)
    c.rect(8, 44, 56, 45, lerp(RIB, WHITE, 0.25))


def house(c, x, y, roof, wall=(250, 240, 220), w=7, h=5):
    c.rect(x, y, x + w, y + h, wall)
    c.poly([(x - 1, y), (x + w // 2, y - 4), (x + w + 1, y)], roof)
    c.px(x + w // 2, y + h - 1, (110, 70, 45))


def tree(c, x, y, r=4, col=GRASS_D):
    c.rect(x, y, x + 1, y + 4, (120, 80, 50))
    c.oval(x, y - 1, r, r - 1, col)


def palm(c, x, y):
    c.rect(x, y - 8, x + 1, y, (150, 100, 60))
    for dx, dy in ((-5, -9), (5, -9), (-4, -11), (4, -11)):
        c.poly([(x, y - 9), (x + dx, y - 9 + dy // 3), (x + dx // 2, y - 10)], (80, 180, 70))


# ---------- islands ----------
def daybreak(c):
    base(c)
    tree(c, 14, 30), tree(c, 48, 31, 5), palm(c, 54, 34)
    house(c, 20, 29, (230, 90, 70)), house(c, 38, 30, (240, 160, 60))
    # windmill: tower + 4 blades
    c.poly([(29, 32), (31, 12), (35, 12), (37, 32)], (245, 235, 215))
    c.poly([(29, 12), (33, 7), (37, 12)], (200, 70, 60))
    c.rect(32, 26, 34, 32, (120, 80, 50))
    for pts in (((33, 12), (24, 3), (27, 1)), ((33, 12), (42, 21), (39, 23)), ((33, 12), (42, 3), (44, 6)), ((33, 12), (24, 21), (22, 18))):
        c.poly(list(pts), (235, 225, 200))
    c.oval(33, 12, 1, 1, (90, 60, 40))
    ribbon(c)


def conch_bay(c):
    base(c, rock=True)
    for y, w in ((33, 21), (29, 17), (25, 13)):  # terraced cliff
        c.rect(32 - w, y, 32 + w, y + 4, ROCK if y % 2 else ROCK_D)
        c.rect(32 - w, y, 32 + w, y, GRASS)
    c.rect(18, 17, 46, 26, (235, 225, 205))  # fort wall
    for x in range(18, 47, 4):
        c.rect(x, 15, x + 1, 17, (235, 225, 205))
    c.rect(30, 20, 34, 26, (120, 90, 60))  # gate
    for cx in (24, 40):  # two conch-shell towers with blue domes
        c.rect(cx - 4, 6, cx + 4, 20, (120, 175, 230))
        c.oval(cx, 6, 5, 4, (70, 120, 210))
        for k in range(3):
            c.rect(cx - 4, 9 + k * 4, cx + 4, 9 + k * 4, (200, 230, 255))
        c.px(cx, 1, (255, 220, 90))
    c.rect(30, 34, 34, 43, (180, 130, 80))  # long pier
    ribbon(c)


def marmalade(c):
    base(c)
    tree(c, 12, 28, 5), tree(c, 52, 28, 5)
    for x, y in ((14, 33), (22, 31), (42, 31), (50, 33)):
        house(c, x, y, (235, 120, 50))
    c.rect(26, 16, 38, 30, (245, 235, 220))  # town hall
    c.poly([(24, 16), (32, 10), (40, 16)], (60, 110, 210))
    c.rect(36, 4, 40, 16, (230, 210, 180))  # clock tower
    c.oval(38, 8, 2, 2, WHITE)
    c.poly([(35, 4), (38, 0), (41, 4)], (200, 70, 50))
    # striped circus big top on the shore
    c.poly([(6, 37), (14, 28), (22, 37)], (230, 60, 60))
    for k in range(3):
        c.poly([(9 + k * 4, 37), (14, 28), (11 + k * 4, 37)], WHITE)
    c.px(14, 27, (255, 220, 90))
    ribbon(c)


def honeyslope(c):
    base(c, top=20)
    c.oval(34, 24, 18, 9, GRASS)  # the slope
    tree(c, 12, 31, 5), tree(c, 50, 30, 5)
    c.rect(24, 10, 44, 22, (250, 245, 235))  # mansion on the hill
    c.poly([(22, 10), (34, 3), (46, 10)], (70, 100, 190))
    for x in (27, 31, 37, 41):
        c.rect(x, 13, x + 1, 15, (120, 170, 230))
    c.rect(33, 17, 35, 22, (130, 90, 60))
    c.rect(20, 22, 48, 23, (60, 140, 60))  # hedge
    for x in (14, 20):  # beehives
        c.oval(x, 36, 3, 3, (240, 190, 60))
        c.rect(x - 3, 36, x + 3, 36, (200, 140, 40))
    house(c, 40, 32, (230, 160, 70), (240, 225, 190))
    ribbon(c)


def barracuda(c):
    c.oval(32, 41, 30, 9, SEA_D)
    c.oval(32, 40, 28, 7, SEA)
    c.oval(32, 35, 24, 7, (190, 130, 70))  # round wooden deck
    c.oval(32, 34, 22, 6, (215, 155, 90))
    c.rect(20, 18, 44, 33, (130, 210, 180))  # round mint restaurant
    c.rect(20, 18, 44, 20, (190, 60, 50))
    for x in (23, 29, 35, 41):
        c.rect(x, 24, x + 2, 27, (255, 230, 140))
    c.rect(30, 28, 34, 33, (130, 80, 50))
    c.rect(31, 4, 32, 18, (130, 90, 60))  # mast + striped sail
    for k in range(4):
        c.rect(24, 6 + k * 3, 40, 7 + k * 3, (250, 160, 50) if k % 2 == 0 else WHITE)
    # swordfish bow (long sharp bill): our own figurehead
    c.poly([(8, 33), (20, 29), (20, 36)], (80, 120, 180))
    c.poly([(0, 32), (9, 32), (9, 34)], (200, 210, 230))
    c.px(14, 31, WHITE)
    ribbon(c)


def mikan(c):
    base(c)
    for x, y in ((12, 32), (20, 34), (44, 34), (52, 32)):  # pools
        c.oval(x, y, 4, 2, (90, 190, 230))
    c.rect(22, 20, 42, 31, (240, 225, 200))  # palace walls
    for k, w in enumerate((10, 8, 6, 4)):  # tiered roofs, coral crest on top
        y = 20 - k * 4
        c.poly([(32 - w - 2, y), (32, y - 4), (32 + w + 2, y)], (210, 80, 60))
        c.rect(32 - w, y, 32 + w, y + 1, (240, 225, 200))
    c.poly([(30, 2), (32, 0), (34, 2), (33, 4), (31, 4)], (255, 130, 140))
    c.rect(30, 26, 34, 31, (90, 150, 210))  # water gate
    for x in (8, 56):  # tangerine trees
        tree(c, x - 1, 30, 4, (60, 150, 60))
        for dx, dy in ((-2, -1), (1, 0), (0, -3)):
            c.px(x + dx, 29 + dy, (255, 150, 40))
    ribbon(c)


def epilogue(c):
    base(c, rock=True)
    cols = [(230, 120, 70), (70, 110, 200), (230, 120, 70), (70, 110, 200)]
    for i, x in enumerate(range(10, 54, 7)):  # dense harbor city
        house(c, x, 30 + (i % 2) * 2, cols[i % 4], (245, 235, 215), 6, 5)
    c.rect(20, 18, 34, 29, (245, 240, 230))  # domed hall
    c.oval(27, 17, 6, 5, (70, 110, 200))
    c.rect(38, 6, 42, 29, (235, 220, 190))  # bell tower
    c.poly([(37, 6), (40, 1), (43, 6)], (190, 60, 50))
    c.oval(40, 10, 1, 1, (255, 210, 80))
    c.rect(48, 16, 51, 30, WHITE)  # lighthouse
    c.rect(48, 20, 51, 21, (220, 60, 60)), c.rect(48, 25, 51, 26, (220, 60, 60))
    c.rect(47, 13, 52, 16, (255, 230, 120))
    c.rect(12, 33, 14, 43, (180, 130, 80)), c.rect(50, 33, 52, 43, (180, 130, 80))  # piers
    ribbon(c)


ISLANDS = {'Daybreak': daybreak, 'ConchBay': conch_bay, 'Marmalade': marmalade, 'Honeyslope': honeyslope,
           'Barracuda': barracuda, 'Mikan': mikan, 'Epilogue': epilogue}


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new('RGB', (len(ISLANDS) * W * 4, H * 4), (40, 44, 70))
    for i, (name, fn) in enumerate(ISLANDS.items()):
        c = C()
        fn(c)
        img = finish(c)
        img.save(os.path.join(OUT, 'isl_' + name + '.png'))
        s = img.resize((W * 4, H * 4), Image.NEAREST)
        sheet.paste(s, (i * W * 4, 0), s)
    sheet.save(os.path.join(OUT, '..', 'island_icons_sheet.png'))
    print('wrote', len(ISLANDS), 'island icons')


if __name__ == '__main__':
    main()
