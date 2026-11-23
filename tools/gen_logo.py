#!/usr/bin/env python3
"""Title-menu logo (v0.25.87, owner reference: chunky extruded pixel letters, emblem between the lines, small saga line).
Our own bitmap font + our own emblem (a ship's wheel), the game's colors (cream LARPTALES, gold VOXEL SEAS).

  python3 tools/gen_logo.py            -> assets/logo/logo.png (+ logo_preview.png on a dark sky)
Upload it and put the id in GameConfig.LogoImage.
"""
import math, os
from PIL import Image

# 6x7 bold glyphs, 2-pixel strokes
G = {
    "L": ["##....", "##....", "##....", "##....", "##....", "######", "######"],
    "A": [".####.", "##..##", "##..##", "######", "##..##", "##..##", "##..##"],
    "R": ["#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##"],
    "P": ["#####.", "##..##", "##..##", "#####.", "##....", "##....", "##...."],
    "T": ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##.."],
    "E": ["######", "##....", "##....", "#####.", "##....", "##....", "######"],
    "S": [".#####", "##....", "##....", ".####.", "....##", "....##", "#####."],
    "V": ["##..##", "##..##", "##..##", "##..##", ".####.", ".####.", "..##.."],
    "O": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "X": ["##..##", "##..##", ".####.", "..##..", ".####.", "##..##", "##..##"],
    "Z": ["######", "....##", "...##.", "..##..", ".##...", "##....", "######"],
    "U": ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    "G": [".#####", "##....", "##....", "##.###", "##..##", "##..##", ".#####"],
    " ": ["...", "...", "...", "...", "...", "...", "..."],
}
EDGE = (14, 18, 48)


def text_mask(word, cell, gap=1):
    """mask (list of rows of bools) for a word, each glyph pixel = cell x cell subpixels"""
    cols = []
    for ch in word:
        g = G[ch]
        for x in range(len(g[0])):
            cols.append([g[y][x] == "#" for y in range(7)])
        for _ in range(gap):
            cols.append([False] * 7)
    cols = cols[:-gap]
    w, h = len(cols) * cell, 7 * cell
    return [[cols[x // cell][y // cell] for x in range(w)] for y in range(h)], w, h


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None


def draw_word(cv, word, ox, oy, cell, top, bottom, depth_col, shear=0, depth=2):
    m, w, h = text_mask(word, cell)

    def at(x, y):  # sheared placement: higher rows lean right
        return ox + x + (h - y) * shear // h, oy + y
    filled = set()
    for y in range(h):
        for x in range(w):
            if m[y][x]:
                filled.add(at(x, y))
    body = {}
    for y in range(h):
        t = y / max(1, h - 1)
        for x in range(w):
            if m[y][x]:
                c = lerp(top, bottom, t)
                if y % cell == 0 and (y == 0 or not m[y - 1][x]):
                    c = lerp(c, (255, 255, 255), 0.55)  # lit top edge of every stroke
                body[at(x, y)] = c
    ext = set()
    for (x, y) in filled:
        for d in range(1, depth + 1):
            ext.add((x, y + d))
    outline = set()
    for (x, y) in filled | ext:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                outline.add((x + dx, y + dy))
    for p in outline:
        cv.put(*p, EDGE)
    for (x, y) in ext:
        cv.put(x, y, depth_col)
    for p, c in body.items():
        cv.put(*p, c)
    return w + shear, h + depth


def wheel(cv, cx, cy, r):
    gold, dark, ruby = (255, 206, 70), (196, 116, 34), (230, 50, 70)
    mine = set()
    for y in range(cy - r - 6, cy + r + 7):
        for x in range(cx - r - 6, cx + r + 7):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx) % (math.pi / 4)
            near = min(a, math.pi / 4 - a) * d  # distance to the nearest of 8 spokes
            ring = r - 1.2 <= d <= r + 0.9
            spoke = near < 0.8 and d <= r + 3
            knob = math.hypot(d - (r + 3.5), near) < 1.6
            hub = d < 3.2
            if ring or spoke or knob or hub:
                mine.add((x, y))
                cv.put(x, y, dark if (dy > 0 and not hub) else gold)
    for (x, y) in list(mine):
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                if (x + ox, y + oy) not in mine:
                    cv.put(x + ox, y + oy, EDGE)
    for (x, y) in mine:
        dx, dy = x - cx, y - cy
        cv.put(x, y, dark if (dy > 0 and math.hypot(dx, dy) >= 3.2) else gold)
    for y in range(cy - 1, cy + 2):
        for x in range(cx - 1, cx + 2):
            cv.put(x, y, ruby)
    cv.put(cx - 1, cy - 1, (255, 170, 180))


def rays(cv, cx, cy, r):
    for a in (-2.4, -2.0, -1.15, -0.75):  # little yellow sparks above the wheel, both sides
        for k in range(3):
            x, y = int(cx + math.cos(a) * (r + 6 + k)), int(cy + math.sin(a) * (r + 6 + k))
            cv.put(x, y, (255, 230, 90))


def sparkle(cv, x, y, s, c=(255, 255, 255)):
    for k in range(-s, s + 1):
        cv.put(x + k, y, c)
        cv.put(x, y + k, c)


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "logo")
    os.makedirs(out, exist_ok=True)
    cell = 3
    W, H = 214, 136
    cv = Canvas(W, H)
    # line 1: LARPTALES (cream), line 2: VOXEL SEAS (gold, slanted), saga line small underneath
    w1 = len("LARPTALES") * 7 * cell - cell
    draw_word(cv, "LARPTALES", (W - w1) // 2, 6, cell, (255, 251, 236), (226, 196, 140), (150, 112, 70))
    w2 = (len("VOXEL SEAS") * 7 - 1) * cell
    draw_word(cv, "VOXEL SEAS", (W - w2) // 2 - 4, 54, cell, (255, 238, 120), (255, 140, 36), (176, 78, 18), shear=8, depth=3)
    wheel(cv, W // 2, 42, 8)
    rays(cv, W // 2, 42, 10)
    ws = len("AZURE EAST SAGA") * 7 - 1
    draw_word(cv, "AZURE EAST SAGA", (W - ws) // 2, 85, 1, (226, 240, 255), (170, 205, 255), (60, 80, 140), depth=1)
    for x, y, s in ((10, 10, 2), (W - 12, 14, 3), (20, 70, 2), (W - 16, 76, 2), (W // 2 - 60, 46, 1), (W // 2 + 62, 44, 1)):
        sparkle(cv, x, y, s)
    # crop to the drawn area + margin, scale up crisp
    ys = [y for y in range(H) if any(cv.px[y])]
    xs = [x for x in range(W) if any(cv.px[y][x] for y in range(H))]
    x0, x1, y0, y1 = max(0, xs[0] - 2), min(W, xs[-1] + 3), max(0, ys[0] - 2), min(H, ys[-1] + 3)
    S = 1024 // (x1 - x0)
    img = Image.new("RGBA", ((x1 - x0) * S, (y1 - y0) * S), (0, 0, 0, 0))
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = cv.px[y][x]
            if c:
                for yy in range(S):
                    for xx in range(S):
                        img.putpixel(((x - x0) * S + xx, (y - y0) * S + yy), c + (255,))
    img.save(os.path.join(out, "logo.png"))
    bg = Image.new("RGBA", img.size, (40, 70, 140, 255))
    bg.alpha_composite(img)
    bg.save(os.path.join(out, "logo_preview.png"))
    print("logo", img.size, "scale", S)


if __name__ == "__main__":
    main()
