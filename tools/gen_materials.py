"""Stylized hand-painted PBR material pack (tileable 1024 px): color + normal + roughness per material.

Color maps are near-neutral (light values with soft painterly variation) because Roblox tints a MaterialVariant's
color map with BasePart.Color: every island keeps its own palette, the texture adds the painted detail.
  python3 tools/gen_materials.py            -> assets/materials/<Name>_{color,normal,rough}.png
  python3 tools/upload_images.py assets/materials src/shared/Config/MaterialMaps.lua
  python3 tools/gen_materials.py --project  -> writes the MaterialService block into default.project.json
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "materials")
N = 1024
rng = np.random.default_rng(11)


# ---------------------------------------------------------------- tileable building blocks
def fbm(beta=2.2, lo=0.0, seed=None, n=N):
    """fractal noise via spectral synthesis (periodic, so it tiles). beta: higher = smoother"""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    kx = np.fft.fftfreq(n)[:, None]
    ky = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1
    amp = 1 / k ** (beta / 2)
    amp[k < lo] = 0
    out = np.real(np.fft.ifft2(f * amp))
    return norm(out)


def aniso(scale_x, scale_y, beta=2.0, seed=None, n=N):
    """stretched noise (wood grain, grass strokes): filter anisotropically in frequency space"""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    kx = np.fft.fftfreq(n)[:, None] * scale_x
    ky = np.fft.fftfreq(n)[None, :] * scale_y
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1
    return norm(np.real(np.fft.ifft2(f / k ** (beta / 2))))


def norm(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def voronoi(count, seed=None, n=N, jitter=1.0, sx=1.0):
    """tileable cellular noise: returns F1, F2 (distances in pixels) and the cell id"""
    r = np.random.default_rng(seed) if seed is not None else rng
    # jittered grid of points for even-sized cells
    g = int(np.ceil(np.sqrt(count)))
    pts = []
    for i in range(g):
        for j in range(g):
            pts.append(((i + 0.5 + (r.random() - 0.5) * jitter) / g * n, (j + 0.5 + (r.random() - 0.5) * jitter) / g * n))
    pts = np.array(pts)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    cid = np.zeros((n, n), np.int32)
    for idx, (px, py) in enumerate(pts):
        dx = np.abs(x - px)
        dy = np.abs(y - py)
        dx = np.minimum(dx, n - dx)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt((dx * sx) ** 2 + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        cid = np.where(closer, idx, cid)
        f1 = np.where(closer, d, f1)
    return f1, f2, cid, len(pts)


def blur(a, r=2):
    """periodic box blur (cheap painterly softening)"""
    out = a.copy()
    for ax in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-r, r + 1):
            acc += np.roll(out, k, ax)
        out = acc / (2 * r + 1)
    return out


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    # OpenGL convention (+Y up), image rows go down
    return np.stack([(-dx / l) * 0.5 + 0.5, (dy / l) * 0.5 + 0.5, (nz / l) * 0.5 + 0.5], -1)


def light_from_height(h, strength=6.0):
    """baked painterly light: surfaces facing up-left get brighter (hand-painted look), creases darker"""
    nrm = normal_from_height(h, strength) * 2 - 1
    L = np.array([-0.45, 0.55, 0.7])
    L = L / np.linalg.norm(L)
    return np.clip((nrm * L).sum(-1), 0, 1)


def posterize(a, steps):
    return np.round(a * steps) / steps


def tint(v, warm, cool):
    """value map -> RGB, mixing a warm tint in the lights and a cool tint in the shadows"""
    warm, cool = np.array(warm, np.float32), np.array(cool, np.float32)
    return v[..., None] * (cool + (warm - cool) * v[..., None])


def save(name, color, normal, rough):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_color.png"))
    Image.fromarray((np.clip(normal, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_normal.png"))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_rough.png"))
    print("MATERIAL", name)


# ---------------------------------------------------------------- materials
def grass():
    """painted grass: thousands of short curved brush strokes (light tips, darker roots) over soft clumps, drawn on a
    3x3 canvas and cropped so it tiles; near-neutral values (the part's green Color tints it)"""
    from PIL import ImageDraw, ImageFilter
    import math as _m
    r = np.random.default_rng(41)
    big = N * 3
    base = (blur(fbm(2.6, seed=1), 4) * 0.25 + 0.58)
    canvas = Image.fromarray((np.tile(np.clip(base, 0, 1), (3, 3)) * 255).astype(np.uint8), "L").convert("RGB")
    d = ImageDraw.Draw(canvas)
    clumps = fbm(2.2, seed=2)
    for _ in range(5200):
        x, y = r.uniform(0, N), r.uniform(0, N)
        cl = clumps[int(y) % N, int(x) % N]
        ln = r.uniform(34, 70)
        ang = _m.radians(-90 + r.uniform(-35, 35))
        bend = r.uniform(-0.5, 0.5)
        v = 0.45 + 0.5 * cl + r.uniform(-0.14, 0.14)
        tip = min(1.0, v + 0.22)
        for ox in (0, N, 2 * N):
            for oy in (0, N, 2 * N):
                px, py = x + ox, y + oy
                pts = []
                for k in range(4):
                    t = k / 3
                    a2 = ang + bend * t
                    pts.append((px + _m.cos(a2) * ln * t, py + _m.sin(a2) * ln * t))
                # root (dark) -> tip (light) in two segments, warm-yellow tips
                c1 = tuple(int(255 * v * f) for f in (0.92, 0.97, 0.86))
                c2 = tuple(int(255 * tip * f) for f in (1.0, 1.02, 0.84))
                w0 = int(r.integers(5, 9))
                d.line(pts[:3], fill=c1, width=w0)
                d.line(pts[2:], fill=c2, width=max(2, w0 - 3))
    canvas = canvas.filter(ImageFilter.GaussianBlur(0.7)).crop((N, N, 2 * N, 2 * N))
    col = np.asarray(canvas).astype(np.float32) / 255.0
    h = col.mean(-1)
    save("Grass", col, normal_from_height(blur(h, 1), 4), 0.9 * np.ones_like(h))


def rock():
    """cliff faces: wide layered slabs (stretched cells), soft painterly bevels, light top edges, faint strata"""
    f1, f2, cid, k = voronoi(18, seed=5, jitter=1.0, sx=0.45)
    edge = np.clip((f2 - f1) / 34.0, 0, 1)
    cellv = np.random.default_rng(6).random(k)[cid]
    slab = edge ** 0.6 * (0.7 + 0.3 * cellv)
    y = np.mgrid[0:N, 0:N][0].astype(np.float32)
    strata = 0.5 + 0.5 * np.sin(y / N * np.pi * 2 * 9 + fbm(2.6, seed=24) * 6)
    detail = fbm(1.9, seed=7)
    h = slab * 0.75 + 0.12 * strata + 0.13 * detail
    lit = light_from_height(blur(h, 3), 16)
    v = 0.5 + 0.3 * lit + 0.12 * cellv + 0.06 * strata
    v = v * (0.78 + 0.22 * np.clip(edge * 5, 0, 1))
    v = blur(posterize(np.clip(v, 0, 1), 6), 2)
    col = tint(v, (1.04, 1.0, 0.92), (0.85, 0.9, 1.04))
    save("Rock", col, normal_from_height(blur(h, 2), 8), 0.8 + 0.15 * (1 - slab))


def slate():
    """boulders and loose rocks: lumpy, a few soft cracks, chunky painted light"""
    f1, f2, cid, k = voronoi(9, seed=8, jitter=1.0)
    edge = np.clip((f2 - f1) / 30.0, 0, 1)
    cellv = np.random.default_rng(9).random(k)[cid]
    lumps = fbm(2.4, seed=10)
    h = 0.55 * lumps + 0.35 * edge ** 0.5 + 0.1 * fbm(1.5, seed=25)
    lit = light_from_height(blur(h, 2), 12)
    v = 0.55 + 0.3 * lit + 0.1 * cellv
    v = v * (0.8 + 0.2 * np.clip(edge * 6, 0, 1))
    col = tint(blur(posterize(np.clip(v, 0, 1), 6), 1), (1.03, 1.0, 0.94), (0.86, 0.9, 1.03))
    save("Slate", col, normal_from_height(blur(h, 1), 7), 0.85 * np.ones_like(h))


def sand():
    ripples = aniso(0.18, 1.0, 2.6, seed=11)  # long soft dune ripples
    grain = fbm(0.6, seed=12)
    h = 0.6 * ripples + 0.25 * fbm(2.4, seed=13) + 0.15 * grain
    lit = light_from_height(blur(h, 2), 8)
    v = 0.74 + 0.2 * lit + 0.06 * grain
    speck = (np.random.default_rng(14).random((N, N)) > 0.997) * 0.12
    col = tint(np.clip(v - speck, 0, 1), (1.02, 1.0, 0.95), (0.95, 0.94, 1.0))
    save("Sand", col, normal_from_height(h, 5), 0.9 * np.ones_like(h))


def wood():
    """bark / posts: long vertical grain, knots"""
    grain = aniso(0.08, 1.0, 2.2, seed=15)
    fine = aniso(0.25, 1.0, 1.6, seed=16)
    h = 0.6 * grain + 0.4 * fine
    stripes = 0.5 + 0.5 * np.sin(grain * 40)
    lit = light_from_height(h, 6)
    v = 0.6 + 0.18 * stripes + 0.18 * lit
    col = tint(np.clip(v, 0, 1), (1.04, 1.0, 0.92), (0.9, 0.9, 0.98))
    save("Wood", col, normal_from_height(h, 5), 0.8 * np.ones_like(h))


def planks():
    """wood planks: 6 boards per tile, dark gaps, grain, offset end joints, nail dots"""
    y, x = np.mgrid[0:N, 0:N].astype(np.float32)
    boards = 6
    bw = N / boards
    bi = np.floor(x / bw).astype(int)
    off = np.random.default_rng(17).random(boards)[bi] * N
    yy = (y + off) % N
    joint = (np.abs(yy - N / 2) < 3)
    gap = (np.abs((x % bw) - 0) < 4) | joint
    grain = aniso(0.06, 1.0, 2.2, seed=18)
    shade = np.random.default_rng(19).random(boards)[bi]
    h = np.where(gap, 0.0, 0.7 + 0.2 * grain)
    lit = light_from_height(blur(h, 1), 6)
    v = np.where(gap, 0.25, 0.62 + 0.12 * shade + 0.12 * np.sin(grain * 50) * 0.5 + 0.14 * lit)
    nails = ((np.abs((x % bw) - bw * 0.15) < 5) | (np.abs((x % bw) - bw * 0.85) < 5)) & (np.abs(yy - N / 2 - 14) < 5)
    v = np.where(nails, 0.35, v)
    col = tint(np.clip(v, 0, 1), (1.04, 1.0, 0.92), (0.9, 0.9, 0.98))
    save("WoodPlanks", col, normal_from_height(blur(h, 1), 6), np.where(gap, 1.0, 0.75))


def cobble():
    f1, f2, cid, k = voronoi(64, seed=20, jitter=0.7)
    edge = np.clip((f2 - f1) / 10.0, 0, 1)
    stone = np.clip((edge - 0.25) * 2.5, 0, 1)
    cellv = np.random.default_rng(21).random(k)[cid]
    h = np.sqrt(stone) * (0.8 + 0.2 * cellv) + 0.08 * fbm(1.6, seed=22)
    lit = light_from_height(blur(h, 1), 9)
    v = np.where(stone > 0.05, 0.6 + 0.2 * lit + 0.15 * cellv, 0.32 + 0.1 * fbm(1.2, seed=23))
    col = tint(np.clip(v, 0, 1), (1.02, 1.0, 0.95), (0.9, 0.92, 1.0))
    save("Cobblestone", col, normal_from_height(h, 7), np.where(stone > 0.05, 0.75, 0.95))


# ---------------------------------------------------------------- water layers (Texture overlays, scrolled by Ocean.lua)
def water_layers():
    os.makedirs(os.path.join(ROOT, "assets", "water"), exist_ok=True)
    n = 512

    def rgba(a, color=(1, 1, 1)):
        img = np.zeros((n, n, 4), np.float32)
        img[..., :3] = color
        img[..., 3] = np.clip(a, 0, 1)
        return Image.fromarray((img * 255).astype(np.uint8), "RGBA")

    # soft wave crest lines (cellular caustic look)
    # soft, elongated crest lines (stretched cells, blurred, broken up by noise) -> rolling swell, not cracked ice
    f1, f2, _, _ = voronoi(30, seed=30, n=n, sx=0.4)
    lines = np.clip(1 - (f2 - f1) / 14.0, 0, 1) ** 2.6
    lines = blur(lines, 2) * np.clip((fbm(2.2, seed=35, n=n) - 0.2) * 1.8, 0, 1)
    rgba(lines * 0.45).save(os.path.join(ROOT, "assets", "water", "waves.png"))
    # broken foam streaks
    st = aniso(0.12, 1.0, 2.4, seed=31, n=n)
    foam = np.clip((st - 0.62) * 6, 0, 1) * np.clip((fbm(2.0, seed=32, n=n) - 0.35) * 3, 0, 1)
    rgba(foam * 0.85).save(os.path.join(ROOT, "assets", "water", "foam.png"))
    # sun glitter: sparse sharp sparkles
    r = np.random.default_rng(33)
    g = np.zeros((n, n), np.float32)
    for _ in range(420):
        x, y = r.integers(0, n, 2)
        s = r.uniform(1.0, 2.6)
        yy, xx = np.ogrid[-6:7, -6:7]
        star = np.exp(-(xx * xx + yy * yy) / (2 * (s * 0.6) ** 2)) + 0.6 * np.exp(-(xx * xx) / 0.6 - (yy * yy) / (s * 6)) + 0.6 * np.exp(-(yy * yy) / 0.6 - (xx * xx) / (s * 6))
        ys = (np.arange(-6, 7) + y) % n
        xs = (np.arange(-6, 7) + x) % n
        g[np.ix_(ys, xs)] = np.maximum(g[np.ix_(ys, xs)], star * r.uniform(0.6, 1.0))
    rgba(g, (1, 0.98, 0.9)).save(os.path.join(ROOT, "assets", "water", "glitter.png"))
    # shore foam ring (radial: dense at the inner edge, broken outward)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    rr = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    band = np.clip(1 - np.abs(rr - 0.86) / 0.12, 0, 1)
    broken = np.clip((fbm(1.6, seed=34, n=n) - 0.3) * 2.5, 0, 1)
    rgba(np.clip(band * (0.5 + 0.7 * broken), 0, 1) * (rr < 1)).save(os.path.join(ROOT, "assets", "water", "shorefoam.png"))
    print("WATER layers")


# ---------------------------------------------------------------- Rojo project block
VARIANTS = {  # MaterialVariant name -> (base material, color/normal/rough file prefix, studs per tile)
    "GV_Grass": ("Grass", "Grass", 18),
    "GV_Rock": ("Rock", "Rock", 28),
    "GV_Slate": ("Slate", "Slate", 10),
    "GV_Sand": ("Sand", "Sand", 26),
    "GV_Wood": ("Wood", "Wood", 8),
    "GV_WoodPlanks": ("WoodPlanks", "WoodPlanks", 10),
    "GV_Cobblestone": ("Cobblestone", "Cobblestone", 10),
}


def write_project():
    # PX=1: the pixel-art (voxel look) set from tools/gen_pixel_materials.py, tiled on a regular grid
    px = os.environ.get("PX") == "1"
    src = os.path.join(ROOT, "assets", "materials_px") if px else OUT
    ids = json.load(open(os.path.join(src, "uploaded.json")))
    pj_path = os.path.join(ROOT, "default.project.json")
    pj = json.load(open(pj_path))
    ms = {"$className": "MaterialService", "$properties": {"Use2022Materials": True}}
    for vname, (base, pre, studs) in VARIANTS.items():
        props = {
            "BaseMaterial": base,
            "MaterialPattern": "Organic",
            "StudsPerTile": studs,
            "ColorMap": "rbxassetid://" + ids[pre + "_color"]["id"],
            "NormalMap": "rbxassetid://" + ids[pre + "_normal"]["id"],
            "RoughnessMap": "rbxassetid://" + ids[pre + "_rough"]["id"],
        }
        if base in ("WoodPlanks", "Cobblestone") or px:
            props["MaterialPattern"] = "Regular"
        ms[vname] = {"$className": "MaterialVariant", "$properties": props}
        # base material override: every Part with this Material uses the variant (no world code changes).
        # Not for Grass: island ground is Terrain grass now, and Terrain only draws its swaying grass blades on the plain material.
        ms["$properties"][base + "Name"] = vname
    pj["tree"]["MaterialService"] = ms
    json.dump(pj, open(pj_path, "w"), indent=2)
    print("project: MaterialService with", len(VARIANTS), "variants")


if __name__ == "__main__":
    if "--project" in sys.argv:
        write_project()
    else:
        for fn in (grass, rock, slate, sand, wood, planks, cobble):
            fn()
        water_layers()
