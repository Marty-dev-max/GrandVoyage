#!/usr/bin/env python3
"""Pixel icons for worn accessories, drawn from their real blocks (v0.25.36, owner: the Bag must show the piece itself).
   lune run tools/export_char.luau build/GrandVoyage.rbxlx /tmp/acc.json accessories
   python3 tools/gen_acc_icons.py /tmp/acc.json          -> assets/icons/acc_<ItemId>.png (only ids that are items)
   then upload_images.py assets/icons src/shared/Config/Icons.lua. UI.ItemIconName prefers acc_<id>.
A 3/4 view (turned 35 deg, looking down 25 deg), flat-shaded faces (top light, front base, side dark) rasterized
straight at 32x32 with no anti-aliasing, then the same shadow + dark outline + 8x scale as gen_pixel_icons.py."""
import json, math, os, re, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import gen_skill_icons as K  # noqa: E402
from gen_pixel_icons import N, SCALE, OUTLINE  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
OUT = os.path.join(ROOT, 'assets', 'icons')
YAW, PITCH = math.radians(35), math.radians(25)


def view(p, yaw=None):
    x, y, z = p
    YAW_ = YAW if yaw is None else yaw
    x, z = x * math.cos(YAW_) - z * math.sin(YAW_), x * math.sin(YAW_) + z * math.cos(YAW_)
    return _pitch(x, y, z)


def _pitch(x, y, z):
    return x, y * math.cos(PITCH) + z * math.sin(PITCH), -y * math.sin(PITCH) + z * math.cos(PITCH)


def _unused(p):
    x, y, z = p
    x, z = x * math.cos(YAW) - z * math.sin(YAW), x * math.sin(YAW) + z * math.cos(YAW)
    y, z = y * math.cos(PITCH) + z * math.sin(PITCH), -y * math.sin(PITCH) + z * math.cos(PITCH)
    return x, y, z


def box_faces(b):
    sx, sy, sz = (v / 2 for v in b['size'])
    c = b['cf']
    pos, rot = c[0:3], c[3:12]

    def world(lx, ly, lz):
        return (pos[0] + rot[0] * lx + rot[1] * ly + rot[2] * lz,
                pos[1] + rot[3] * lx + rot[4] * ly + rot[5] * lz,
                pos[2] + rot[6] * lx + rot[7] * ly + rot[8] * lz)

    def axis(i, s):  # world normal of a local axis
        return (rot[i] * s, rot[3 + i] * s, rot[6 + i] * s)
    faces = []
    for i, s in ((0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)):
        corners = []
        for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            l = [0, 0, 0]
            l[i] = s
            l[(i + 1) % 3], l[(i + 2) % 3] = u, v
            corners.append(world(l[0] * sx, l[1] * sy, l[2] * sz))
        faces.append((axis(i, s), corners))
    return faces


def draw(blocks):
    polys = []
    # capes and other back pieces: look from behind
    acc = [b for b in blocks if not b.get('stand')]
    stands = [b for b in blocks if b.get('stand')]
    back = False
    if acc and stands:
        cz = sum(b['cf'][2] for b in stands) / len(stands)
        back = sum(b['cf'][2] - cz for b in acc) / len(acc) > 0.25
    yaw = YAW + math.pi if back else YAW
    for b in blocks:
        for n, corners in box_faces(b):
            vn = view(n, yaw)
            if vn[2] >= -1e-3:  # facing away from the camera (camera looks along +Z from -Z)
                continue
            light = 1.18 if n[1] > 0.7 else (0.62 if n[1] < -0.7 else (1.0 if abs(n[2]) > abs(n[0]) else 0.8))
            vs = [view(c, yaw) for c in corners]
            depth = sum(v[2] for v in vs) / 4
            col = tuple(max(0, min(255, int(ch * light))) for ch in b['color'])
            polys.append((depth, [(v[0], -v[1]) for v in vs], col))
    if not polys:
        return None
    xs = [p[0] for _, ps, _ in polys for p in ps]
    ys = [p[1] for _, ps, _ in polys for p in ps]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    k = (N - 6) / max(w, h, 1e-3)
    ox, oy = (N - w * k) / 2 - min(xs) * k, (N - h * k) / 2 - min(ys) * k
    spr = K.Spr()
    d = ImageDraw.Draw(spr.im)
    for _, ps, col in sorted(polys, key=lambda t: -t[0]):  # far first
        d.polygon([(x * k + ox, y * k + oy) for x, y in ps], fill=col + (255,))
    shadow, body = K.shade_and_outline(spr, OUTLINE)
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    img = Image.alpha_composite(img, shadow)
    img = Image.alpha_composite(img, body)
    return img.resize((N * SCALE, N * SCALE), Image.NEAREST)


def main():
    data = json.load(open(sys.argv[1]))['acc']
    items = set(re.findall(r'add\("(\w+)"', open(os.path.join(ROOT, 'src', 'shared', 'Config', 'Items.lua')).read()))
    os.makedirs(OUT, exist_ok=True)
    made = []
    for acc_id, blocks in sorted(data.items()):
        if acc_id not in items:
            continue  # monster-only pieces (held weapons) are not items
        img = draw(blocks)
        if img:
            img.save(os.path.join(OUT, 'acc_' + acc_id + '.png'))
            made.append(acc_id)
    sheet = Image.new('RGB', (len(made) * 110, 120), (44, 46, 64))
    for i, n in enumerate(made):
        im = Image.open(os.path.join(OUT, 'acc_' + n + '.png')).resize((96, 96), Image.NEAREST)
        sheet.paste(im, (i * 110 + 7, 12), im)
    sheet.save(os.path.join(ROOT, 'assets', 'acc_icons_sheet.png'))
    assert made, 'no accessory icons drawn'
    print('wrote', len(made), 'accessory icons')


if __name__ == '__main__':
    main()
