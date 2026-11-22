"""Pose preview renderer (v0.25.66): draws tools/export_pose.luau output as flat-shaded cubes, no Blender needed.
python3 tools/render_pose.py poses.json out.png [scale]
Each pose gets a tile pair: FRONT (looking at the character's face; it faces -Z) above SIDE (from its right, +X).
"""
import json, sys
import numpy as np
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
S = float(sys.argv[3]) if len(sys.argv) > 3 else 34.0
data = json.load(open(src))
labels = data.get("labels", [])
n = max(1, len(labels))
TW, TH = int(9 * S), int(8.2 * S)
img = Image.new("RGB", (TW * n, TH * 2 + 20), (40, 44, 58))
draw = ImageDraw.Draw(img)

CUBE = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)], float)
FACES = [((0, 1, 3, 2), (-1, 0, 0)), ((4, 6, 7, 5), (1, 0, 0)), ((0, 4, 5, 1), (0, -1, 0)), ((2, 3, 7, 6), (0, 1, 0)),
         ((0, 2, 6, 4), (0, 0, -1)), ((1, 5, 7, 3), (0, 0, 1))]
LIGHT = np.array([0.45, 0.8, -0.4]); LIGHT /= np.linalg.norm(LIGHT)

# view = (right axis, up axis, toward-camera axis) in Roblox space
VIEWS = {"front": (np.array([-1, 0, 0.]), np.array([0, 1, 0.]), np.array([0, 0, -1.])),
         "side": (np.array([0, 0, -1.]), np.array([0, 1, 0.]), np.array([1, 0, 0.]))}

def render(parts, view, ox, oy, off):
    right, up, toward = VIEWS[view]
    polys = []
    for p in parts:
        cf = p["cf"]
        pos = np.array(cf[:3], float) - np.array([off, 0, 0])
        R = np.array(cf[3:], float).reshape(3, 3)
        w = (R @ (CUBE * np.array(p["size"], float)).T).T + pos
        col = np.array(p["color"], float)
        for idx, nrm in FACES:
            nw = R @ np.array(nrm, float)
            if nw @ toward <= 0:
                continue
            q = w[list(idx)]
            depth = (q @ toward).mean()
            shade = 0.5 + 0.5 * max(0.0, nw @ LIGHT)
            c = tuple(int(min(255, v * 255 * shade)) for v in col)
            pts = [(ox + TW / 2 + (v @ right) * S, oy + TH - 0.4 * S - (v @ up) * S) for v in q]
            polys.append((depth, pts, c))
    polys.sort(key=lambda e: e[0])
    for _, pts, c in polys:
        draw.polygon(pts, fill=c, outline=tuple(max(0, v - 40) for v in c))

for i, lab in enumerate(labels):
    parts = [p for p in data["parts"] if p.get("pose") == i]
    render(parts, "front", i * TW, 0, lab["x"])
    render(parts, "side", i * TW, TH, lab["x"])
    draw.text((i * TW + 6, 4), lab["text"], fill=(255, 240, 160))
    draw.line([(i * TW, 0), (i * TW, TH * 2)], fill=(80, 86, 110))
draw.line([(0, TH), (TW * n, TH)], fill=(80, 86, 110))
img.save(out)
print("wrote", out, img.size)
