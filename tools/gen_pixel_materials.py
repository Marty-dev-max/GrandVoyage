"""Pixel-art (voxel look) versions of the map materials (v0.24.0, owner: the whole map voxel).
   python3 tools/gen_pixel_materials.py                  -> assets/materials_px/*.png (from assets/materials)
   ROBLOX_API_KEY=... python3 tools/upload_images.py assets/materials_px src/shared/Config/MaterialMaps.lua
   PX=1 python3 tools/gen_materials.py --project          -> MaterialService uses them (Regular pattern, crisp pixels)
Color maps are box-downsampled to a small grid, quantized to a few colors and scaled back up with nearest-neighbour
(each texel = one crisp square), with a light top-left / dark bottom-right bevel per tile pixel so ground reads as blocks.
Normal and roughness maps get the same pixel grid."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = os.path.join(ROOT, 'assets', 'materials')
OUT = os.path.join(ROOT, 'assets', 'materials_px')
GRID = {'Grass': 16, 'Rock': 16, 'Slate': 16, 'Sand': 16, 'Wood': 16, 'WoodPlanks': 16, 'Cobblestone': 16}
UP = 256


def pixelize(img, g, colors=None):
    small = img.convert('RGB').resize((g, g), Image.BOX)
    if colors:
        small = small.quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert('RGB')
    return small


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, g in GRID.items():
        col = Image.open(os.path.join(SRC, name + '_color.png'))
        small = np.asarray(pixelize(col, g, 6), np.float32)
        # stronger texel-to-texel contrast so the pixel grid reads under the Part.Color tint
        mean = small.reshape(-1, 3).mean(0)
        small = np.clip(mean + (small - mean) * 2.2, 0, 255)
        # per-pixel bevel: each texel becomes a tiny block (light top-left edge, dark bottom-right edge)
        big = np.repeat(np.repeat(small, UP // g, 0), UP // g, 1)
        k = UP // g
        yy, xx = np.mgrid[0:UP, 0:UP]
        fx, fy = xx % k, yy % k
        edge = np.ones((UP, UP), np.float32)
        edge[(fx == 0) | (fy == 0)] = 1.08
        edge[(fx == k - 1) | (fy == k - 1)] = 0.86
        big = np.clip(big * edge[..., None], 0, 255).astype(np.uint8)
        Image.fromarray(big, 'RGB').save(os.path.join(OUT, name + '_color.png'))
        # normal: flat with the same bevel tilt
        n = np.zeros((UP, UP, 3), np.float32)
        n[..., 0], n[..., 1], n[..., 2] = 128, 128, 255
        n[fx == 0, 0] = 96
        n[fx == k - 1, 0] = 160
        n[fy == 0, 1] = 160
        n[fy == k - 1, 1] = 96
        Image.fromarray(n.astype(np.uint8), 'RGB').save(os.path.join(OUT, name + '_normal.png'))
        r = pixelize(Image.open(os.path.join(SRC, name + '_rough.png')), g).convert('L').resize((UP, UP), Image.NEAREST)
        r.save(os.path.join(OUT, name + '_rough.png'))
        print('pixel material', name)


if __name__ == '__main__':
    main()
