"""Voxel environment kit (v0.24.0, owner: the whole map goes voxel). Same names as tools/blender/envkit.py
(Env_<Kind>_<n>), so uploading them replaces the stylized meshes everywhere AssetService.DressWorld puts them.
Shapes are signed-distance functions sampled on a voxel grid (tools/blender/voxel.py Grid), colored per voxel, then
greedy-meshed into one light mesh with a palette texture. Pivot = bottom center; AssetService normalizes the size.

  python tools/blender/voxel_env.py -- --out assets/models3d --preview [--only BroadTree_1,Pine_2]
  ROBLOX_API_KEY=... python3 tools/upload_models.py assets/models3d src/shared/Config/Models.lua --only Env_...
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voxel as V
import gvkit as K

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv

hexc = V.hexc


def shade(g, base, light=None, dark=None, amount=0.08, zlo=None, zhi=None):
    """per-voxel color: base with speckle, lighter toward zhi and darker toward zlo"""
    c = np.broadcast_to(hexc(base), g.shape + (3,)).copy()
    z = g.P[..., 2]
    if light is not None and zhi is not None:
        k = np.clip((z - (zlo or 0)) / max(1e-3, zhi - (zlo or 0)), 0, 1)[..., None]
        c = c * (1 - k) + hexc(light) * k
    if dark is not None and zlo is not None:
        k = np.clip(1 - (z - zlo) / 3.0, 0, 1)[..., None]
        c = c * (1 - k) + hexc(dark) * k
    return c * g.noise(amount)[..., None]


def speckle(g, a, b, p=0.25):
    """two-color voxel mix"""
    m = (g.rng.random(g.shape) < p)[..., None]
    return np.where(m, hexc(b), hexc(a)) * g.noise(0.05)[..., None]


# ------------------------------------------------------------------ trees
LEAF = {1: ("4CB04A", "8EDC5A", "2E7A34"), 2: ("3C9440", "6CC452", "22602A"), 3: ("7CC448", "B8E86A", "4A8A30")}


def broad_tree(v):
    g = V.Grid(22, 22, 28)
    rng = np.random.default_rng(v)
    trunk = g.d_box((11, 11, 6), (1.6, 1.6, 6.5))
    g.add(trunk, lambda m: shade(g, "7A5236", amount=0.1))
    for k in range(2):
        a = rng.uniform(0, 6.28)
        p1 = (11 + math.cos(a) * 4, 11 + math.sin(a) * 4, 13)
        d, _ = g.d_tube([(11, 11, 9), p1], [1.0, 0.8])
        g.add(d, lambda m: shade(g, "6E4A30", amount=0.1))
    base, light, dark = LEAF[v]
    blobs = [((11, 11, 18), (8, 8, 6))]
    for k in range(4):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(3.5, 5.5)
        blobs.append(((11 + math.cos(a) * r, 11 + math.sin(a) * r, rng.uniform(15, 21)), (rng.uniform(4.5, 6), rng.uniform(4.5, 6), rng.uniform(3.5, 5))))
    d = None
    for c, rr in blobs:
        dd = g.d_ellipsoid(c, rr)
        d = dd if d is None else np.minimum(d, dd)
    g.add(d, lambda m: shade(g, base, light, dark, 0.1, zlo=12, zhi=25))
    g.bake_ao(0.35)
    return g


def pine(v):
    # stacked square tiers with gaps between them (the classic voxel pine), trunk showing under the lowest tier
    g = V.Grid(16, 16, 34)
    g.add(g.d_box((8, 8, 6), (1.2, 1.2, 6)), lambda m: shade(g, "6A4630", amount=0.1))
    col = ("2E7A44", "4CA05A", "1C5030") if v == 1 else ("336E52", "5A9A70", "1E4A38")
    tiers = [(9, 7.0), (13, 6.0), (17, 5.0), (21, 4.0), (25, 3.0), (28.5, 2.0), (31.5, 1.0)]
    for i, (z, half) in enumerate(tiers):
        d = g.d_box((8, 8, z), (half, half, 1.6), rot_z=0.25 * (i % 2))
        g.add(d, lambda m: shade(g, col[0], col[1], col[2], 0.1, zlo=z - 1.6, zhi=z + 1.6))
    g.bake_ao(0.3)
    return g


def palm(v):
    g = V.Grid(24, 24, 30)
    lean = 1 if v == 1 else -1
    pts = [(12, 12, 0), (12 + lean * 1.5, 12, 8), (12 + lean * 3.5, 12, 16), (12 + lean * 5, 12, 24)]
    d, t = g.d_tube(pts, [1.6, 1.4, 1.2, 1.1])
    band = ((t * 12).astype(np.int32) % 2 == 0)[..., None]
    g.add(d, lambda m: np.where(band, hexc("9A6E44"), hexc("7E5636")) * g.noise(0.06)[..., None])
    top = np.array(pts[-1])
    for k in range(7):
        a = k * 6.28 / 7 + 0.3
        mid = top + np.array([math.cos(a) * 5, math.sin(a) * 5, 1.5])
        end = top + np.array([math.cos(a) * 9.5, math.sin(a) * 9.5, -2.5])
        dd, tt = g.d_tube([tuple(top), tuple(mid), tuple(end)], [1.2, 1.0, 0.5])
        g.add(dd, lambda m: np.where((tt < 0.5)[..., None], hexc("5CB848"), hexc("3E9238")) * g.noise(0.08)[..., None])
    for k in range(3):
        a = k * 2.1
        c = top + np.array([math.cos(a) * 1.4, math.sin(a) * 1.4, -1.6])
        g.add(g.d_sphere(tuple(c), 1.0), lambda m: shade(g, "6A4426", amount=0.05))
    g.bake_ao(0.3)
    return g


def bush(v):
    g = V.Grid(14, 14, 9)
    rng = np.random.default_rng(10 + v)
    d = None
    for k in range(4):
        c = (7 + rng.uniform(-2.5, 2.5), 7 + rng.uniform(-2.5, 2.5), rng.uniform(3, 4.5))
        dd = g.d_ellipsoid(c, (rng.uniform(3, 4.5), rng.uniform(3, 4.5), rng.uniform(2.6, 3.6)))
        d = dd if d is None else np.minimum(d, dd)
    base, light, dark = LEAF[v]
    g.add(d, lambda m: shade(g, base, light, dark, 0.12, zlo=0, zhi=8))
    if v == 2:
        berries = (g.rng.random(g.shape) < 0.05)
        g.col[g.fill & berries] = hexc("E04A5A")
    g.bake_ao(0.3)
    return g


# ------------------------------------------------------------------ rocks + cliffs
ROCK = {"Brown": ("8C7258", "B09478", "5E4A3A"), "Gray": ("8A8C92", "B4B6BC", "5C5E66"), "Red": ("B0563E", "D27C5A", "7A3426")}


def boulder(v):
    g = V.Grid(14, 12, 9)
    rng = np.random.default_rng(20 + v)
    d = None
    for k in range(3):
        c = (7 + rng.uniform(-2, 2), 6 + rng.uniform(-1.5, 1.5), rng.uniform(2.5, 4))
        dd = g.d_box(c, (rng.uniform(2.5, 4.5), rng.uniform(2.2, 3.8), rng.uniform(2, 3.5)), rot_z=rng.uniform(0, 1))
        d = dd if d is None else np.minimum(d, dd)
    base, light, dark = ROCK["Gray"]
    g.add(d, lambda m: shade(g, base, light, dark, 0.1, zlo=0, zhi=8))
    top = g.fill & (np.roll(g.fill, -1, 2) == False) & (g.P[..., 2] > 4.5)
    moss = top & (g.rng.random(g.shape) < 0.6)
    g.col[moss] = hexc("6AA048") * g.noise(0.08)[moss][..., None]
    g.bake_ao(0.3)
    return g


def cliff(v, tone="Brown"):
    # a slab of rock with stepped strata, jagged top and sides (fits the cliff ring's box: wide, thin, tall)
    g = V.Grid(16, 8, 20)
    rng = np.random.default_rng(30 + v)
    d = g.d_box((8, 4, 10), (7.5, 3.5, 10))
    g.add(d, lambda m: hexc("8C7258"))
    # jagged: steps carved from the top edge and the two side edges only (no holes in the face)
    for k in range(8):
        side = 0 if k % 2 == 0 else 16
        c = (side, 4, rng.uniform(1, 20))
        g.cut(g.d_box(c, (rng.uniform(1, 2.5), 5, rng.uniform(1, 2.5))))
    for k in range(3):
        c = (rng.uniform(1, 15), -0.5, rng.uniform(3, 18))
        g.cut(g.d_box(c, (rng.uniform(1, 3), 1.0, rng.uniform(0.6, 1.4))))
    for k in range(5):
        c = (rng.uniform(0, 16), 4, 20)
        g.cut(g.d_box(c, (rng.uniform(1, 2), 5, rng.uniform(0.8, 2.2))))
    base, light, dark = ROCK.get(tone, ROCK["Brown"])
    z = g.P[..., 2]
    layer = (np.floor((z + v) / 3).astype(np.int32) % 3)[..., None]
    col = np.where(layer == 0, hexc(light), np.where(layer == 1, hexc(base), hexc(dark)))
    g.col[:] = col * g.noise(0.06)[..., None]
    g.bake_ao(0.35)
    return g


def grass_cap(v):
    # a round voxel grass layer with dripping edges and a few tufts on top
    g = V.Grid(24, 24, 6)
    rng = np.random.default_rng(40 + v)
    r = np.hypot(g.P[..., 0] - 12, g.P[..., 1] - 12)
    top = 4 + 0.0 * r
    d = np.maximum(r - 11.5, np.abs(g.P[..., 2] - 3.5) - 1.0)
    g.add(d, lambda m: shade(g, "5CB04C", "86D060", None, 0.1, zlo=2, zhi=5))
    # drips around the rim
    for k in range(18):
        a = k * 6.28 / 18 + rng.uniform(-0.1, 0.1)
        c = (12 + math.cos(a) * 11, 12 + math.sin(a) * 11, 2)
        g.add(g.d_box(c, (0.8, 0.8, rng.uniform(1, 2.2))), lambda m: shade(g, "4A9A40", amount=0.08))
    for k in range(10):
        c = (12 + rng.uniform(-8, 8), 12 + rng.uniform(-8, 8), 5)
        g.add(g.d_box(c, (0.5, 0.5, rng.uniform(0.6, 1.2))), lambda m: shade(g, "7CCB58", amount=0.1))
    g.bake_ao(0.25)
    return g


# ------------------------------------------------------------------ ground plants
def grass_tuft(v):
    g = V.Grid(10, 10, 6)
    rng = np.random.default_rng(50 + v)
    for k in range(16):
        x, y = rng.integers(1, 9), rng.integers(1, 9)
        if math.hypot(x - 4.5, y - 4.5) > 4.2:
            continue
        h = rng.integers(2, 6)
        g.add(g.d_box((x + 0.5, y + 0.5, h / 2), (0.45, 0.45, h / 2)), lambda m: shade(g, "4CA844", "9EE070", None, 0.1, zlo=0, zhi=5))
    return g


def grass_patch(v):
    g = V.Grid(14, 14, 4)
    rng = np.random.default_rng(55 + v)
    for k in range(40):
        x, y = rng.integers(0, 14), rng.integers(0, 14)
        if math.hypot(x - 7, y - 7) > 6.5:
            continue
        h = rng.integers(1, 4)
        g.add(g.d_box((x + 0.5, y + 0.5, h / 2), (0.45, 0.45, h / 2)), lambda m: shade(g, "52AC48", "96D86C", None, 0.1, zlo=0, zhi=3))
    return g


def fern(v):
    g = V.Grid(12, 12, 6)
    for k in range(6 + v):
        a = k * 6.28 / (6 + v)
        end = (6 + math.cos(a) * 5.5, 6 + math.sin(a) * 5.5, 1.5)
        d, t = g.d_tube([(6, 6, 0.5), (6 + math.cos(a) * 3, 6 + math.sin(a) * 3, 4), end], [0.7, 0.6, 0.4])
        g.add(d, lambda m: np.where((t > 0.6)[..., None], hexc("7CC858"), hexc("3E9A3E")) * g.noise(0.08)[..., None])
    return g


def leaf_plant(v):
    g = V.Grid(12, 12, 9)
    for k in range(4 + v):
        a = k * 6.28 / (4 + v) + 0.4
        c = (6 + math.cos(a) * 3.2, 6 + math.sin(a) * 3.2, 4 + (k % 2) * 1.5)
        g.add(g.d_box(c, (2.0, 1.2, 0.5), rot_z=a), lambda m: shade(g, "3E9E4A", "70CC66", None, 0.1, zlo=2, zhi=7))
    g.add(g.d_box((6, 6, 2), (0.5, 0.5, 2)), lambda m: shade(g, "4A8A34", amount=0.05))
    return g


def mushroom(v):
    g = V.Grid(8, 8, 9)
    g.add(g.d_box((4, 4, 2.5), (1.0, 1.0, 2.5)), lambda m: shade(g, "F0E6D2", amount=0.05))
    cap = "D23C3C" if v == 1 else "A0703C"
    d = np.maximum(g.d_ellipsoid((4, 4, 5.5), (3.6, 3.6, 2.6)), -(g.P[..., 2] - 4.6))
    g.add(d, lambda m: shade(g, cap, amount=0.05))
    if v == 1:
        dots = g.fill & (g.P[..., 2] > 5) & (g.rng.random(g.shape) < 0.18)
        g.col[dots] = hexc("FAF6EE")
    return g


FLOWER = {1: "E8414A", 2: "F6D23C", 3: "F08AC0", 4: "9A64DC", 5: "F6F6F6"}


def flowers(v):
    g = V.Grid(8, 8, 6)
    rng = np.random.default_rng(60 + v)
    for k in range(5):
        x, y = rng.integers(1, 7), rng.integers(1, 7)
        h = rng.integers(2, 5)
        g.add(g.d_box((x + 0.5, y + 0.5, h / 2), (0.4, 0.4, h / 2)), lambda m: shade(g, "4CA040", amount=0.05))
        g.add(g.d_box((x + 0.5, y + 0.5, h + 0.5), (1.0, 1.0, 0.5)), lambda m: shade(g, FLOWER[v], amount=0.06))
        g.add(g.d_box((x + 0.5, y + 0.5, h + 1.05), (0.45, 0.45, 0.1)), lambda m: shade(g, "F6D23C" if v != 2 else "E87A2A", amount=0.02))
    return g


PROPS = {}
for i in (1, 2, 3):
    PROPS[f"BroadTree_{i}"] = (broad_tree, i)
    PROPS[f"Boulder_{i}"] = (boulder, i)
    PROPS[f"Cliff_{i}"] = ((lambda vv: cliff(vv, "Brown")), i)
    PROPS[f"GrassCap_{i}"] = (grass_cap, i)
    for tone in ("Brown", "Gray", "Red"):
        PROPS[f"Cliff{tone}_{i}"] = ((lambda tn: (lambda vv: cliff(vv, tn)))(tone), i)
for i in (1, 2):
    PROPS[f"Pine_{i}"] = (pine, i)
    PROPS[f"Palm_{i}"] = (palm, i)
    PROPS[f"Bush_{i}"] = (bush, i)
    PROPS[f"GrassTuft_{i}"] = (grass_tuft, i)
    PROPS[f"GrassPatch_{i}"] = (grass_patch, i)
    PROPS[f"Fern_{i}"] = (fern, i)
    PROPS[f"LeafPlant_{i}"] = (leaf_plant, i)
    PROPS[f"Mushroom_{i}"] = (mushroom, i)
for i in (1, 2, 3, 4, 5):
    PROPS[f"Flowers_{i}"] = (flowers, i)


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for name, (fn, variant) in PROPS.items():
        if ONLY and name not in ONLY:
            continue
        K.reset()
        g = fn(variant)
        obj = V.mesh_grid(g, "Env_" + name, 1.0)
        K.export_glb(obj, os.path.join(OUT, "Env_" + name + ".glb"))
        if PREVIEW:
            V.preview(obj, os.path.join(OUT, "preview", "Env_" + name + ".png"), size=256)
        print("PROP", name)


if __name__ == "__main__":
    main()
