"""Generate the VFX texture pack (white-on-transparent PNGs; color them with ParticleEmitter.Color / Beam.Color).
   python3 tools/gen_vfx.py            -> assets/vfx/*.png
Anime-style VFX (Anime Vanguards look) = soft glows + hard sparkles + slashes + rings + speed lines, all additive-ish."""
import math, os
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'vfx')
S = 256
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
cx = cy = (S - 1) / 2
r = np.hypot(xx - cx, yy - cy) / (S / 2)
ang = np.arctan2(yy - cy, xx - cx)

def save(name, alpha, blur=0):
    a = np.nan_to_num(np.clip(alpha, 0, 1))
    img = Image.fromarray((a * 255).astype(np.uint8), 'L')
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    rgba = Image.new('RGBA', (img.width, img.height), (255, 255, 255, 0))
    rgba.putalpha(img)
    rgba.save(os.path.join(OUT, name + '.png'))

def main():
    os.makedirs(OUT, exist_ok=True)
    # soft round glow
    save('glow', np.exp(-(r ** 2) * 5.5))
    # 4-point anime sparkle with a hot core
    star = np.maximum(np.exp(-np.abs(xx - cx) / 5) * np.exp(-np.abs(yy - cy) / 60), np.exp(-np.abs(yy - cy) / 5) * np.exp(-np.abs(xx - cx) / 60))
    save('sparkle', np.maximum(star, np.exp(-(r ** 2) * 30)) * (r < 1))
    # impact burst: many sharp spikes (hit flash)
    spikes = np.zeros_like(r)
    rng = np.random.default_rng(7)
    for k in range(14):
        a0 = k / 14 * 2 * math.pi + rng.uniform(-0.15, 0.15)
        length = rng.uniform(0.55, 1.0)
        d = np.abs(np.angle(np.exp(1j * (ang - a0))))
        width = 0.10 * (1 - r / length)
        spikes = np.maximum(spikes, ((d < width) & (r < length)).astype(np.float32) * np.clip(1 - r / length, 0, 1) ** 0.4)
    save('burst', np.maximum(spikes, np.exp(-(r ** 2) * 18)), blur=1)
    # shockwave ring
    save('ring', np.exp(-((r - 0.8) ** 2) / 0.004) + 0.25 * np.exp(-((r - 0.74) ** 2) / 0.02))
    # crescent slash: thick on one side, tapering (use as a particle or flipbook-free slash)
    outer = np.exp(-((r - 0.78) ** 2) / 0.006)
    taper = np.clip((np.sin(ang) + 0.2) / 1.2, 0, 1) ** 1.5
    save('slash', outer * taper, blur=1)
    # smoke puff: blurred noise inside a soft circle
    noise = rng.random((S // 8, S // 8)).astype(np.float32)
    noise = np.array(Image.fromarray((noise * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)) / 255.0
    save('smoke', (0.45 + 0.55 * noise) * np.exp(-(r ** 2) * 3.2), blur=4)
    # flame: teardrop pointing up, hot (opaque) core
    canvas = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(canvas)
    d.ellipse([58, 120, 198, 236], fill=255)
    d.polygon([(64, 170), (192, 170), (128, 18)], fill=255)
    canvas = canvas.filter(ImageFilter.GaussianBlur(12))
    core = np.exp(-(((xx - cx) / 40) ** 2 + ((yy - 175) / 55) ** 2))
    save('flame', np.array(canvas) / 255.0 * (0.55 + 0.45 * core))
    # horizontal speed line (beams / trails)
    w, h = 512, 64
    ly, lx = np.mgrid[0:h, 0:w].astype(np.float32)
    line = np.exp(-((ly - h / 2) ** 2) / 30) * np.clip(lx / (w * 0.6), 0, 1) ** 1.5 * np.clip((w - lx) / (w * 0.08), 0, 1)
    img = Image.fromarray((np.clip(line, 0, 1) * 255).astype(np.uint8), 'L')
    rgba = Image.new('RGBA', (w, h), (255, 255, 255, 0)); rgba.putalpha(img); rgba.save(os.path.join(OUT, 'speedline.png'))
    # lightning strip (beam texture, tiles horizontally)
    canvas = Image.new('L', (512, 128), 0)
    d = ImageDraw.Draw(canvas)
    for pass_, width_ in ((0, 9), (1, 3)):
        y = 64
        pts = [(0, y)]
        rr = np.random.default_rng(11 + pass_)
        for x in range(32, 513, 32):
            y = int(np.clip(y + rr.integers(-30, 31), 16, 112))
            pts.append((x, y))
        pts[-1] = (512, 64)
        d.line(pts, fill=255 if pass_ else 140, width=width_)
    canvas = Image.composite(canvas, canvas.filter(ImageFilter.GaussianBlur(6)), canvas)
    rgba = Image.new('RGBA', canvas.size, (255, 255, 255, 0)); rgba.putalpha(canvas); rgba.save(os.path.join(OUT, 'lightning.png'))
    # ground crack (decal for slams)
    canvas = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(canvas)
    rr = np.random.default_rng(3)
    for k in range(9):
        a0 = k / 9 * 2 * math.pi + rr.uniform(-0.2, 0.2)
        x, y = cx, cy
        for step in range(6):
            a0 += rr.uniform(-0.45, 0.45)
            nx, ny = x + math.cos(a0) * 20, y + math.sin(a0) * 20
            d.line([(x, y), (nx, ny)], fill=255, width=max(1, 6 - step))
            x, y = nx, ny
    save('crack', np.array(canvas) / 255.0 * (r < 0.98))
    # radial speed lines (anime focus burst around a big hit)
    radial = np.zeros_like(r)
    for k in range(48):
        a0 = k / 48 * 2 * math.pi + rng.uniform(-0.03, 0.03)
        dd = np.abs(np.angle(np.exp(1j * (ang - a0))))
        radial = np.maximum(radial, (dd < 0.012 + 0.01 * r) * np.clip((r - rng.uniform(0.35, 0.6)) / 0.4, 0, 1))
    save('focuslines', radial * (r < 1), blur=1)
    # wind wisp: a soft, thin ribbon that fades in and out along its length (used on curved Beams)
    W, H = 512, 64
    u = np.linspace(0, 1, W)[None, :]
    v = np.linspace(-1, 1, H)[:, None]
    along = np.sin(np.pi * u) ** 1.6
    thick = 0.22 + 0.12 * np.sin(u * 9.0)
    wisp = np.exp(-(v / thick) ** 2 * 2.2) * along
    img = Image.fromarray((np.clip(wisp, 0, 1) * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(1.2))
    rgba = Image.new('RGBA', (W, H), (255, 255, 255, 0)); rgba.putalpha(img); rgba.save(os.path.join(OUT, 'windwisp.png'))
    # leaf: light leaf shape with a darker midrib (tinted green/yellow/pink by ParticleEmitter.Color)
    L = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(L)
    pts = []
    for k in range(41):
        t = k / 40
        w = math.sin(math.pi * t) ** 0.8 * 30
        pts.append((64 + w, 10 + t * 108))
    for k in range(40, -1, -1):
        t = k / 40
        w = math.sin(math.pi * t) ** 0.8 * 30
        pts.append((64 - w * 0.85, 10 + t * 108))
    d.polygon(pts, fill=(255, 255, 255, 255))
    d.line([(64, 14), (63, 116)], fill=(190, 190, 190, 255), width=3)
    for k in range(5):
        y0 = 30 + k * 17
        d.line([(64, y0), (64 + 20, y0 - 10)], fill=(215, 215, 215, 255), width=2)
        d.line([(64, y0 + 6), (64 - 17, y0 - 4)], fill=(215, 215, 215, 255), width=2)
    L = L.rotate(35, resample=Image.BICUBIC)
    L.save(os.path.join(OUT, 'leaf.png'))
    print('wrote', sorted(os.listdir(OUT)))

if __name__ == '__main__':
    main()
