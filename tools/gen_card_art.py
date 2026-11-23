#!/usr/bin/env python3
"""TCG card art background (v0.25.90, owner: pixel cards with manga art): a paper panel with radial speed lines and
halftone screentone toward the edges, drawn at 128 px and scaled x4 (crisp pixels). White = paper (the game tints it
with ImageColor3 by rarity), black = ink.

  python3 tools/gen_card_art.py   -> assets/vfx/card_manga.png (+ card_tone.png: plain halftone strip)
Upload with Studio MCP upload_image (or upload_images.py) and put the ids in Config/Textures (card_manga, card_tone).
"""
import math, os, random
from PIL import Image

N, S = 128, 4
INK, PAPER = (18, 16, 26, 255), (255, 255, 255, 255)


def manga():
    rnd = random.Random(7)
    img = Image.new("RGBA", (N, N), PAPER)
    px = img.load()
    cx, cy = N / 2, N * 0.46
    # speed lines: thin wedges from a ragged inner radius to the border
    wedges = []
    a = 0.0
    while a < math.tau:
        w = rnd.uniform(0.010, 0.03)
        r0 = rnd.uniform(0.32, 0.47) * N
        wedges.append((a, w, r0))
        a += rnd.uniform(0.05, 0.11)
    for y in range(N):
        for x in range(N):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            ang = math.atan2(dy, dx) % math.tau
            for (a0, w, r0) in wedges:
                da = (ang - a0) % math.tau
                # the wedge narrows toward the centre: angular width grows with distance
                if d > r0 and min(da, math.tau - da) * d < w * 40 * min(1.0, (d - r0) / (N * 0.5 - r0 + 1e-6)):
                    px[x, y] = INK
                    break
    # halftone screentone, dots grow toward the corners (4 px grid, round dots)
    for gy in range(0, N, 4):
        for gx in range(0, N, 4):
            ox, oy = gx + 2 - cx, gy + 2 - cy
            d = math.hypot(ox / (N * 0.5), oy / (N * 0.5))
            r = min(1.5, max(0.0, (d - 0.7) * 2.4))
            if r <= 0.15:
                continue
            for y in range(gy, gy + 4):
                for x in range(gx, gx + 4):
                    if math.hypot(x + 0.5 - (gx + 2), y + 0.5 - (gy + 2)) <= r:
                        px[x, y] = INK
    # ink frame line
    for i in range(N):
        for t in (0, N - 1):
            px[i, t] = INK
            px[t, i] = INK
    return img


def tone():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = img.load()
    for gy in range(0, 32, 4):
        for gx in range(0, 32, 4):
            off = 2 if (gy // 4) % 2 else 0
            x, y = (gx + off) % 32, gy
            px[x, y] = INK
            px[(x + 1) % 32, y] = INK
            px[x, y + 1] = INK
            px[(x + 1) % 32, y + 1] = INK
    return img


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "vfx")
    os.makedirs(out, exist_ok=True)
    m = manga()
    assert m.getpixel((64, 58)) == PAPER, "centre must stay clear for the model"
    m.resize((N * S, N * S), Image.NEAREST).save(os.path.join(out, "card_manga.png"))
    tone().resize((128, 128), Image.NEAREST).save(os.path.join(out, "card_tone.png"))
    print("card art written to", out)


if __name__ == "__main__":
    main()
