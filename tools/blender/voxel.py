"""Voxel creature generator (blocky "voxel art" style): shapes are signed-distance functions sampled on a grid, every
voxel gets its own color (base + bands + noise + belly + baked ambient occlusion), then the surface is greedy-meshed
into a light single mesh with one palette texture (same importer path as gvkit: one MeshPart per model).

  python tools/blender/voxel.py -- --out assets/models3d --preview [--only BaySerpent]
Outputs Mon_<Id>.glb (face Blender -Y = Roblox forward) + preview/Mon_<Id>.png. Upload with tools/upload_models.py.
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import bmesh
import gvkit as K
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv


def hexc(h):
    return np.array(K.rgb(h), dtype=np.float32)


# ---------------------------------------------------------------- the grid
class Grid:
    """dims in voxels; x right, y forward(+Y = back of the creature), z up. Creature faces -Y."""

    def __init__(self, nx, ny, nz):
        self.shape = (nx, ny, nz)
        x, y, z = np.meshgrid(np.arange(nx) + 0.5, np.arange(ny) + 0.5, np.arange(nz) + 0.5, indexing="ij")
        self.P = np.stack([x, y, z], -1).astype(np.float32)
        self.fill = np.zeros(self.shape, bool)
        self.col = np.zeros(self.shape + (3,), np.float32)
        self.tag = np.zeros(self.shape, np.int16)  # material ids (0 = none), used by colorers
        self.rng = np.random.default_rng(3)

    # --- sdf primitives (negative = inside)
    def d_sphere(self, c, r):
        return np.linalg.norm(self.P - np.array(c, np.float32), axis=-1) - r

    def d_ellipsoid(self, c, radii):
        q = (self.P - np.array(c, np.float32)) / np.array(radii, np.float32)
        k = np.linalg.norm(q, axis=-1)
        return (k - 1) * min(radii)

    def d_box(self, c, half, rot_z=0.0):
        q = self.P - np.array(c, np.float32)
        if rot_z:
            cs, sn = math.cos(rot_z), math.sin(rot_z)
            q = np.stack([q[..., 0] * cs + q[..., 1] * sn, -q[..., 0] * sn + q[..., 1] * cs, q[..., 2]], -1)
        d = np.abs(q) - np.array(half, np.float32)
        return np.linalg.norm(np.maximum(d, 0), axis=-1) + np.minimum(d.max(-1), 0)

    def d_tube(self, pts, radii):
        """distance to a polyline with per-point radius (smooth taper); returns (dist, param t along the tube)"""
        pts = np.array(pts, np.float32)
        best = np.full(self.shape, 1e9, np.float32)
        tpar = np.zeros(self.shape, np.float32)
        n = len(pts) - 1
        for i in range(n):
            a, b = pts[i], pts[i + 1]
            ab = b - a
            h = np.clip(((self.P - a) @ ab) / float(ab @ ab), 0, 1)
            d = np.linalg.norm(self.P - (a + h[..., None] * ab), axis=-1) - (radii[i] + (radii[i + 1] - radii[i]) * h)
            m = d < best
            best = np.where(m, d, best)
            tpar = np.where(m, (i + h) / n, tpar)
        return best, tpar

    def add(self, d, color_fn, tag=1):
        m = d <= 0
        self.fill |= m
        self.tag[m] = tag
        c = color_fn(m)
        self.col[m] = c if np.ndim(c) == 1 else c[m]

    def cut(self, d):
        self.fill &= ~(d <= 0)

    def noise(self, amount):
        return 1 + (self.rng.random(self.shape, dtype=np.float32) - 0.5) * 2 * amount

    def bake_ao(self, strength=0.5, radius=2):
        """darken voxels with many filled neighbours above/around (cheap ambient occlusion)"""
        f = self.fill.astype(np.float32)
        acc = np.zeros_like(f)
        cnt = 0
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                for dz in range(0, radius + 1):
                    if dx == dy == dz == 0:
                        continue
                    acc += np.roll(np.roll(np.roll(f, -dx, 0), -dy, 1), -dz, 2)
                    cnt += 1
        occ = acc / cnt
        self.col *= (1 - strength * np.clip(occ - 0.25, 0, 1))[..., None]


# ---------------------------------------------------------------- greedy mesher -> palette mesh
def quantize(col, levels=12):
    q = np.round(np.clip(col, 0, 1) * (levels - 1)).astype(np.int32)
    return q[..., 0] * levels * levels + q[..., 1] * levels + q[..., 2]


def mesh_grid(g, name, voxel=1.0, levels=16):
    fill = g.fill
    while True:
        cid = np.where(fill, quantize(g.col, levels), -1)
        uniq = np.unique(cid[fill])
        if len(uniq) <= K.PAL_CELLS * K.PAL_CELLS - 1 or levels <= 4:
            break
        levels -= 1
    lut = {int(u): i for i, u in enumerate(uniq)}
    pal = K.Palette()
    for u in uniq:
        u = int(u)
        r, gg, b = u // (levels * levels), (u // levels) % levels, u % levels
        pal.cell("#%02x%02x%02x" % tuple(int(round(v / (levels - 1) * 255)) for v in (r, gg, b)))
    colors = pal.colors
    verts, faces, uvs = [], [], []
    nx, ny, nz = fill.shape
    pad = np.pad(fill, 1)
    for axis in range(3):
        for sgn in (-1, 1):
            # exposed faces: filled voxel whose neighbour along axis*sgn is empty
            nb = np.roll(pad, -sgn, axis)[1:-1, 1:-1, 1:-1]
            exposed = fill & ~nb
            u_ax, v_ax = [a for a in range(3) if a != axis]
            for s in range(fill.shape[axis]):
                sl = [slice(None)] * 3
                sl[axis] = s
                mask = exposed[tuple(sl)]
                if not mask.any():
                    continue
                ids = np.where(mask, cid[tuple(sl)], -1)
                done = np.zeros_like(mask)
                H, W = ids.shape
                for i in range(H):
                    for j in range(W):
                        c = ids[i, j]
                        if c < 0 or done[i, j]:
                            continue
                        w = 1
                        while j + w < W and ids[i, j + w] == c and not done[i, j + w]:
                            w += 1
                        h = 1
                        while i + h < H and np.all(ids[i + h, j:j + w] == c) and not done[i + h, j:j + w].any():
                            h += 1
                        done[i:i + h, j:j + w] = True
                        plane = s + (1 if sgn > 0 else 0)
                        quad = []
                        for (a, b) in ((0, 0), (h, 0), (h, w), (0, w)):
                            p = [0.0, 0.0, 0.0]
                            p[axis] = plane
                            p[u_ax] = i + a
                            p[v_ax] = j + b
                            quad.append(p)
                        # winding so the normal points along axis*sgn
                        nrm = np.cross(np.subtract(quad[1], quad[0]), np.subtract(quad[3], quad[0]))
                        if (nrm[axis] > 0) != (sgn > 0):
                            quad.reverse()
                        base = len(verts)
                        verts += quad
                        faces.append((base, base + 1, base + 2, base + 3))
                        uvs.append(pal.cell(colors[lut[int(c)]]))
    me = bpy.data.meshes.new(name)
    v = np.array(verts, np.float32)
    v = (v - np.array([nx / 2, ny / 2, 0], np.float32)) * voxel
    me.from_pydata(v.tolist(), [], faces)
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly, uv in zip(me.polygons, uvs):
        for li in poly.loop_indices:
            uvl.data[li].uv = uv
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # merge shared corners (smaller file, no cracks)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.to_mesh(me)
    bm.free()
    img = pal.image(name + "_pal")
    m = bpy.data.materials.new(name + "_mat")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.8
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    me.materials.append(m)
    print("VOXELS", name, int(fill.sum()), "faces", len(faces), "colors", len(colors))
    return obj


# ---------------------------------------------------------------- creatures
def bay_serpent():
    """boss: a sea serpent rearing out of the water in an S-curve; armored head, fin crest, open jaws, glowing eyes"""
    g = Grid(64, 80, 112)
    back_c, side_c, belly_c = hexc("#123a56"), hexc("#2a86a0"), hexc("#b8f4dc")
    crest_c, crest_tip = hexc("#1e8fe0"), hexc("#8fe4ff")
    N = 16
    spine = []
    for i in range(N):
        t = i / (N - 1)
        spine.append((32 + math.sin(t * math.pi * 1.7) * 13, 42 + math.sin(t * math.pi * 1.3 + 0.4) * 16 - t * 4, 3 + t * 72))
    radii = [12.0 - 5.0 * (i / (N - 1)) ** 1.1 for i in range(N)]
    d, tp = g.d_tube(spine, radii)
    sp = np.array(spine, np.float32)

    def body_col(m):
        k = np.clip(np.round(tp * (N - 1)), 0, N - 1).astype(int)
        rel = g.P - sp[k]
        r = np.array(radii, np.float32)[k]
        fwd = -rel[..., 1] / np.maximum(r, 1)  # 1 = facing the camera side (-Y), -1 = back
        c = side_c * np.ones_like(g.col)
        c = np.where((fwd < -0.25)[..., None], back_c, c)
        belly = fwd > 0.55
        c = np.where(belly[..., None], belly_c, c)
        # belly plates: horizontal segments; scales on the sides: diamond checker
        plates = (np.floor(tp * 40) % 2 == 0)
        c = np.where((belly & plates)[..., None], belly_c * 0.86, c)
        diamond = ((np.floor((g.P[..., 0] + g.P[..., 2]) / 3) + np.floor((g.P[..., 2] - g.P[..., 0]) / 3)) % 2 == 0)
        c = np.where((~belly & diamond)[..., None], c * 0.86, c)
        return c * g.noise(0.05)[..., None]

    g.add(d, body_col)
    # dorsal crest: fin plates along the back, bright tips
    for i in range(1, N - 1):
        p = sp[i]
        tdir = sp[min(i + 1, N - 1)] - sp[i - 1]
        h = 5 + 8 * (i / N)
        base = np.array([p[0], p[1] + radii[i] * 0.85, p[2]])
        g.add(g.d_box(tuple(base + [0, h * 0.5, 0]), (0.9, h * 0.5, 2.0)), lambda m: crest_c)
        g.add(g.d_box(tuple(base + [0, h, 0]), (0.9, 1.2, 1.6)), lambda m: crest_tip)
    # side fins every few segments
    for i in ():  # side fins read as flat boards; off for now
        p = sp[i]
        for sx in (-1, 1):
            g.add(g.d_box((p[0] + sx * (radii[i] + 3), p[1] + 2, p[2] - 1), (3.5, 1.0, 4.5)), lambda m: crest_c * g.noise(0.05)[..., None])
    # head: big skull, long snout, open jaws
    top = sp[-1]
    hx, hy, hz = float(top[0]), float(top[1]) - 10, float(top[2]) + 12
    head_c = hexc("#1d5f80")
    g.add(np.minimum(g.d_ellipsoid((hx, hy + 2, hz), (10, 13, 9)), g.d_box((hx, hy - 13, hz + 1), (6.5, 9, 3.6))),
          lambda m: head_c * g.noise(0.05)[..., None])
    # armored brow and snout plates
    for sx in (-1, 1):
        g.add(g.d_box((hx + sx * 5.5, hy - 5, hz + 7), (3.2, 8, 1.6)), lambda m: back_c)
        g.add(g.d_box((hx + sx * 7.5, hy - 2, hz + 4), (1.2, 3.5, 2.5)), lambda m: back_c)
    g.add(g.d_box((hx, hy - 15, hz + 4.8), (3.5, 7, 1.0)), lambda m: back_c)
    # horns: two long swept-back + two small
    for sx in (-1, 1):
        for k in range(12):
            g.add(g.d_sphere((hx + sx * (6 + k * 0.5), hy + 3 + k * 1.8, hz + 8 + k * 1.5 - (k / 11) ** 2 * 4), 2.2 - k * 0.13), lambda m: hexc("#efe6c4") * (0.8 + 0.2 * g.noise(0.1)[..., None]))
        for k in range(5):
            g.add(g.d_sphere((hx + sx * (9 + k * 0.8), hy + 6 + k * 1.2, hz + 2 + k * 0.6), 1.3 - k * 0.15), lambda m: hexc("#efe6c4"))
        # frills behind the jaw
        for k in range(4):
            g.add(g.d_box((hx + sx * (10 + k * 1.2), hy + 6 + k * 2, hz - 2 + k * 1.5), (0.8, 2.5, 4.5 - k * 0.7)), lambda m: crest_c)
            g.add(g.d_box((hx + sx * (10 + k * 1.2), hy + 6 + k * 2, hz + 2.8 - k * 0.2), (0.8, 2.5, 0.8)), lambda m: crest_tip)
    # lower jaw (dropped open), mouth, teeth, tongue
    g.add(g.d_box((hx, hy - 11, hz - 9.5), (5.6, 9.5, 1.8)), lambda m: head_c)
    g.add(g.d_box((hx, hy - 11, hz - 10.8), (4.6, 8.5, 0.8)), lambda m: belly_c)
    g.cut(g.d_box((hx, hy - 15, hz - 4.6), (5.0, 10, 3.6)))
    g.add(g.d_box((hx, hy - 6, hz - 5), (5.0, 3, 3.6)), lambda m: hexc("#4a0c18"))
    g.add(g.d_box((hx, hy - 12, hz - 7.4), (2.4, 6.5, 0.6)), lambda m: hexc("#c03050"))
    for sx in (-1, 1):
        for k in range(6):
            big = k in (0, 1)
            g.add(g.d_box((hx + sx * 4.6, hy - 21 + k * 3, hz - 1.6 - (1.0 if big else 0)), (0.6, 0.6, 1.6 if big else 1.0)), lambda m: hexc("#fffbea"))
            g.add(g.d_box((hx + sx * 4.6, hy - 20 + k * 3, hz - 7.4 + (0.8 if big else 0)), (0.6, 0.6, 1.4 if big else 0.9)), lambda m: hexc("#fffbea"))
    # glowing eyes with a dark socket
    for sx in (-1, 1):
        g.add(g.d_box((hx + sx * 7.6, hy - 8.5, hz + 3.6), (1.0, 2.6, 1.8)), lambda m: hexc("#0a1a26"))
        g.add(g.d_box((hx + sx * 7.9, hy - 8.8, hz + 3.6), (1.0, 1.8, 1.1)), lambda m: hexc("#ff2a4a"))
    g.bake_ao(0.4)
    return g, "BaySerpent", 0.4


CREATURES = {"BaySerpent": bay_serpent}


def preview(obj, path, size=512):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.7, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc.world = world
    dims = obj.dimensions
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    sc.collection.objects.link(cam)
    d = max(dims) * 1.75
    cam.location = (-d * 0.42, -d * 0.9, dims.z * 0.55)
    cam.rotation_euler = (Vector((0, 0, dims.z * 0.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    sc.collection.objects.link(sun)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for key, fn in CREATURES.items():
        if ONLY and key not in ONLY:
            continue
        K.reset()
        g, name, voxel = fn()
        obj = mesh_grid(g, "Mon_" + name, voxel)
        K.export_glb(obj, os.path.join(OUT, "Mon_" + name + ".glb"))
        if PREVIEW:
            preview(obj, os.path.join(OUT, "preview", "Mon_" + name + ".png"))
        print("CREATURE", name)


main()
