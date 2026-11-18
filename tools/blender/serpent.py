"""Bay Serpent v2 (owner, v0.22.5): a full-body sea serpent that slithers. Built as pieces that the game chains:

  Mon_BaySerpent   head (parts "Head" + "Jaw", jaw hinged so the bite clip can open it) + a neck stub; this is the
                   monster model (HumanoidRootPart + Humanoid are added by AssetService)
  Serp_Seg         one body segment (scaled down toward the tail by Controllers/SerpentBody)
  Serp_Tail        the tapering tail with a fin

  python tools/blender/serpent.py -- --out assets/models3d --preview
then upload with tools/upload_models.py (Mon_BaySerpent replaces the old rearing model).
Voxel style like every monster: SDF shapes on a grid, per-voxel colors, greedy-meshed palette mesh. Faces -Y.
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401
import gvkit as K
import voxel as V
from voxel import Grid, hexc

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
PREVIEW = "--preview" in argv
VOX = 0.5  # studs per voxel (AssetService sizes below are measured from this)

BACK, SIDE, BELLY = hexc("#1f5f86"), hexc("#3cb0c8"), hexc("#c8f8e4")
CREST, CREST_TIP = hexc("#1e8fe0"), hexc("#8fe4ff")
HEAD_C, HORN = hexc("#2a78a2"), hexc("#efe6c4")
R_BODY = 8.5  # body radius in voxels


def body_colors(g, center_z):
    """horizontal body: back (top) dark, sides teal with diamond scales, belly plates underneath"""
    def fn(m):
        up = (g.P[..., 2] - center_z) / R_BODY
        c = SIDE * np.ones_like(g.col)
        c = np.where((up > 0.6)[..., None], BACK, c)
        belly = up < -0.5
        c = np.where(belly[..., None], BELLY, c)
        plates = (np.floor(g.P[..., 1] / 2.5) % 2 == 0)
        c = np.where((belly & plates)[..., None], BELLY * 0.86, c)
        diamond = ((np.floor((g.P[..., 1] + g.P[..., 2]) / 3) + np.floor((g.P[..., 2] - g.P[..., 1]) / 3)) % 2 == 0)
        c = np.where((~belly & diamond)[..., None], c * 0.86, c)
        return c * g.noise(0.05)[..., None]
    return fn


def crest(g, x, y0, y1, ztop, h, step=4):
    """dorsal fin plates along the back with bright tips"""
    y = y0
    while y <= y1:
        g.add(g.d_box((x, y, ztop + h * 0.5), (0.9, 1.6, h * 0.5)), lambda m: CREST)
        g.add(g.d_box((x, y, ztop + h), (0.9, 1.3, 1.1)), lambda m: CREST_TIP)
        y += step


def segment():
    g = Grid(22, 18, 30)
    cx, cz = 11, R_BODY + 1
    d, _ = g.d_tube([(cx, 0.5, cz), (cx, 17.5, cz)], [R_BODY, R_BODY])
    g.add(d, body_colors(g, cz))
    crest(g, cx, 3, 15, cz + R_BODY - 1, 6, step=6)
    # little side fins
    for sx in (-1, 1):
        g.add(g.d_box((cx + sx * (R_BODY + 1), 9, cz - 2), (1.6, 3, 0.6)), lambda m: CREST)
    g.bake_ao(0.35)
    return g


def tail():
    g = Grid(22, 44, 34)
    cx, cz = 11, R_BODY + 1
    pts = [(cx, 0.5, cz), (cx, 14, cz - 0.5), (cx, 26, cz - 1.5), (cx, 36, cz - 2)]
    rad = [R_BODY, R_BODY * 0.72, R_BODY * 0.42, 1.6]
    d, _ = g.d_tube(pts, rad)
    g.add(d, body_colors(g, cz))
    crest(g, cx, 4, 26, cz + R_BODY * 0.7 - 1, 5, step=6)
    # tail fin: a tall vertical blade at the end
    for k in range(9):
        y = 33 + k
        h = 2 + k * 0.65  # moderate fluke (v0.22.8: the tall blade stuck out above and below)
        g.add(g.d_box((cx, y, cz - 2), (0.8, 0.6, h)), lambda m: CREST if k < 7 else CREST_TIP)
    g.bake_ao(0.35)
    return g


def head():
    g = Grid(38, 58, 40)
    hx, hy, hz = 19.0, 22.0, 18.0
    # neck stub going back (+Y) to meet the first body segment at body height
    g.set_part("Head")
    d, _ = g.d_tube([(hx, hy + 6, hz - 2), (hx, 57.5, R_BODY + 1)], [9.5, R_BODY])
    g.add(d, body_colors(g, R_BODY + 1))
    crest(g, hx, hy + 10, 54, hz + 4, 6, step=6)
    # skull + snout
    g.add(np.minimum(g.d_ellipsoid((hx, hy + 2, hz), (10, 13, 9)), g.d_box((hx, hy - 13, hz + 1), (6.5, 9, 3.6))),
          lambda m: HEAD_C * g.noise(0.05)[..., None])
    for sx in (-1, 1):
        g.add(g.d_box((hx + sx * 5.5, hy - 5, hz + 7), (3.2, 8, 1.6)), lambda m: BACK)
        g.add(g.d_box((hx + sx * 7.5, hy - 2, hz + 4), (1.2, 3.5, 2.5)), lambda m: BACK)
    g.add(g.d_box((hx, hy - 15, hz + 4.8), (3.5, 7, 1.0)), lambda m: BACK)
    for sx in (-1, 1):
        for k in range(12):
            g.add(g.d_sphere((hx + sx * (6 + k * 0.5), hy + 3 + k * 1.8, hz + 8 + k * 1.5 - (k / 11) ** 2 * 4), 2.2 - k * 0.13),
                  lambda m: HORN * (0.8 + 0.2 * g.noise(0.1)[..., None]))
        for k in range(4):
            g.add(g.d_box((hx + sx * (10 + k * 1.2), hy + 6 + k * 2, hz - 2 + k * 1.5), (0.8, 2.5, 4.5 - k * 0.7)), lambda m: CREST)
            g.add(g.d_box((hx + sx * (10 + k * 1.2), hy + 6 + k * 2, hz + 2.8 - k * 0.2), (0.8, 2.5, 0.8)), lambda m: CREST_TIP)
    # mouth: hollow under the upper jaw, upper teeth, dark throat
    g.cut(g.d_box((hx, hy - 15, hz - 4.6), (5.0, 10, 3.6)))
    g.add(g.d_box((hx, hy - 6, hz - 5), (5.0, 3, 3.6)), lambda m: hexc("#4a0c18"))
    for sx in (-1, 1):
        for k in range(6):
            big = k in (0, 1)
            g.add(g.d_box((hx + sx * 4.6, hy - 21 + k * 3, hz - 1.6 - (1.0 if big else 0)), (0.6, 0.6, 1.6 if big else 1.0)), lambda m: hexc("#fffbea"))
    # glowing eyes
    for sx in (-1, 1):
        g.add(g.d_box((hx + sx * 7.6, hy - 8.5, hz + 3.6), (1.0, 2.6, 1.8)), lambda m: hexc("#0a1a26"))
        g.add(g.d_box((hx + sx * 7.9, hy - 8.8, hz + 3.6), (1.0, 1.8, 1.1)), lambda m: hexc("#ff2a4a"))
    # lower jaw: its own part (the bite clip swings it open from the hinge at its back end)
    g.set_part("Jaw")
    g.add(g.d_box((hx, hy - 11, hz - 7.6), (5.6, 9.5, 1.8)), lambda m: HEAD_C)
    g.add(g.d_box((hx, hy - 11, hz - 6.2), (4.6, 8.5, 0.6)), lambda m: hexc("#c03050"))
    for sx in (-1, 1):
        for k in range(6):
            big = k in (0, 1)
            g.add(g.d_box((hx + sx * 4.6, hy - 20 + k * 3, hz - 5.0 + (0.8 if big else 0)), (0.6, 0.6, 1.4 if big else 0.9)), lambda m: hexc("#fffbea"))
    g.bake_ao(0.4)
    return g


def build(name, g, split=False):
    K.reset()
    obj = V.mesh_grid(g, name, VOX, split=split)
    objs = obj if isinstance(obj, list) else [obj]
    path = os.path.join(OUT, name + ".glb")
    if split:
        V.export_parts(objs, path)
    else:
        K.export_glb(objs[0], path)
    dims = [max(o.dimensions[i] for o in objs) for i in range(3)]
    # whole-model extents
    xs, ys, zs = [], [], []
    for o in objs:
        for v in o.bound_box:
            w = o.matrix_world @ V.Vector(v)
            xs.append(w.x); ys.append(w.y); zs.append(w.z)
    ext = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    print("SIZE", name, "x %.2f y(len) %.2f z(up) %.2f  longest %.2f" % (ext[0], ext[1], ext[2], max(ext)))
    if PREVIEW:
        os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
        V.preview(objs if split else objs[0], os.path.join(OUT, "preview", name + ".png"))
    return ext


def assembly_preview(path, n_seg=9):
    """the whole serpent along an S-curve, as Controllers/SerpentBody chains it in game (for review only)"""
    K.reset()
    hd = V.mesh_grid(head(), "H", VOX, split=True)
    sg = V.mesh_grid(segment(), "S", VOX)
    tl = V.mesh_grid(tail(), "T", VOX)
    y = 14.25 + 3.5
    objs = list(hd)
    for i in range(n_seg + 1):
        last = i == n_seg
        src = tl if last else sg
        o = src.copy()
        o.data = src.data
        bpy.context.scene.collection.objects.link(o)
        k = 1 - 0.035 * i
        yy = y + (6 if last else 0)
        o.location = (math.sin(i * 0.65) * 7, yy, 0)
        o.rotation_euler = (0, 0, -math.cos(i * 0.65) * 0.45)
        o.scale = (k, k, k)
        objs.append(o)
        y += 8 * k
    sg.hide_render = True
    tl.hide_render = True
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.7, 0.9, 1)
    sc.world = world
    ground = bpy.data.objects.new("g", bpy.data.meshes.new("g"))
    ground.data.from_pydata([(-200, -200, 0), (200, -200, 0), (200, 200, 0), (-200, 200, 0)], [], [(0, 1, 2, 3)])
    gm = bpy.data.materials.new("gm")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.42, 0.28, 1)
    ground.data.materials.append(gm)
    sc.collection.objects.link(ground)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 35
    sc.collection.objects.link(cam)
    cam.location = (-70, -60, 55)
    cam.rotation_euler = (V.Vector((0, 40, 4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(-35))
    sc.collection.objects.link(sun)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build("Mon_BaySerpent", head(), split=True)
    build("Serp_Seg", segment())
    build("Serp_Tail", tail())
    if PREVIEW:
        assembly_preview(os.path.join(OUT, "preview", "BaySerpent_full.png"))
