"""Preview render of an exported island (export.luau JSON) with the real stylized env meshes.
python tools/blender/render_island.py -- <island.json> assets/models3d <absolute out prefix>   (ONLY=close for close-ups)
Roblox (x, y up, z) -> Blender (x, -z, y up).
"""
import json, math, os, sys, glob
import numpy as np
import bpy, bmesh
from mathutils import Matrix, Vector

src, models_dir, out = sys.argv[sys.argv.index("--") + 1:][:3] if "--" in sys.argv else sys.argv[1:4]
data = json.load(open(src))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

A = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)


def rbx_matrix(cf, scale=(1, 1, 1)):
    p = np.array(cf[:3], float)
    R = np.array(cf[3:], float).reshape(3, 3)
    Rb = A @ R @ A.T
    pb = A @ p
    M = np.eye(4)
    M[:3, :3] = Rb @ np.diag(scale_b(scale))
    M[:3, 3] = pb
    return M


def scale_b(s):
    # local axes keep their meaning (we rotate the local frame), so sizes map x->x, y->z(local up), z->-y
    return s


# ---------- unit shapes in Roblox local space (then size + cframe) ----------
def unit_shape(shape):
    if shape == "Ball":
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.5)
    elif shape == "Cylinder":
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.5, radius2=0.5, depth=1.0)
        # cone axis is Z (local); Roblox cylinder axis is X
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif shape == "Wedge":
        bm = bmesh.new()
        vs = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
        v = [bm.verts.new(x) for x in vs]
        for f in [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]:
            bm.faces.new([v[i] for i in f])
    else:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
    bm.verts.index_update()
    verts = np.array([v.co[:] for v in bm.verts], float)
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


UNITS = {}


def unit(shape):
    if shape not in UNITS:
        UNITS[shape] = unit_shape(shape)
    return UNITS[shape]


def to_blender_points(local, size, cf):
    # local unit shape is in Roblox local axes
    pts = local * np.array(size, float)
    R = np.array(cf[3:], float).reshape(3, 3)
    world = pts @ R.T + np.array(cf[:3], float)
    return world @ A.T


def build_mesh(name, parts):
    V, F, C = [], [], []
    off = 0
    for k, p in enumerate(parts):
        lv, lf = unit(p["shape"])
        pts = to_blender_points(lv, p["size"], p["cf"])
        pts[:, 2] += (k % 11) * 0.004  # coplanar overlapping parts make Cycles shadow acne (Roblox just z-fights same colors)
        V.append(pts)
        for f in lf:
            F.append([i + off for i in f])
            C.append(p["color"])
        off += len(pts)
    if not V:
        return None
    me = bpy.data.meshes.new(name)
    me.from_pydata(np.concatenate(V).tolist(), [], F)
    attr = me.color_attributes.new("col", "FLOAT_COLOR", "CORNER")
    cols = []
    for f, c in zip(me.polygons, C):
        for _ in f.loop_indices:
            cols.extend([c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1])
    attr.data.foreach_set("color", cols)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def vc_material(name, emission=0.0, alpha=1.0, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    a = nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "col"
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        nt.links.new(a.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    return m


groups = {"solid": [], "neon": [], "glass": []}
for p in data["parts"]:
    if p["mat"] == "Neon":
        groups["neon"].append(p)
    elif p["mat"] == "Glass" or p["t"] > 0.2:
        groups["glass"].append(p)
    else:
        groups["solid"].append(p)
mats = {"solid": vc_material("solid"), "neon": vc_material("neon", 2.0), "glass": vc_material("glass", 0, 0.55, 0.1)}
for k, ps in groups.items():
    ob = build_mesh(k, ps)
    if ob:
        ob.data.materials.append(mats[k])

# ---------- env meshes ----------
cache = {}


def load_variants(kind):
    if kind in cache:
        return cache[kind]
    out = []
    for path in sorted(glob.glob(os.path.join(models_dir, f"Env_{kind}_*.glb"))):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        for o in bpy.data.objects:
            if o not in before:
                o.hide_render = True
                o.hide_viewport = True
        if not new:
            continue
        # join into one mesh with transforms applied
        dg = bpy.context.evaluated_depsgraph_get()
        bm = bmesh.new()
        for o in new:
            tmp = o.evaluated_get(dg).to_mesh()
            tmp.transform(o.matrix_world)
            bm.from_mesh(tmp)
            o.evaluated_get(dg).to_mesh_clear()
        me = bpy.data.meshes.new(f"V_{kind}")
        bm.to_mesh(me)
        bm.free()
        for o in new:
            for s in o.material_slots:
                if s.material and s.material.name not in [m.name for m in me.materials]:
                    me.materials.append(s.material)
        vs = np.array([v.co[:] for v in me.vertices])
        lo, hi = vs.min(0), vs.max(0)
        out.append((me, lo, hi))
    cache[kind] = out
    return out


def place(me, M):
    ob = bpy.data.objects.new(me.name, me)
    ob.matrix_world = Matrix(M.tolist())
    scene.collection.objects.link(ob)


def hashpos(p):
    return abs(math.floor(p[0] * 7.31 + p[2] * 13.17 + p[1] * 3.7))


for pr in data["props"]:
    vs = load_variants(pr["kind"])
    if not vs:
        continue
    hv = hashpos(pr["base"])
    me, lo, hi = vs[hv % len(vs)]
    hgt = hi[2] - lo[2]
    s = pr["h"] / max(hgt, 1e-3)
    center = np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    yaw = (hv % 628) / 100
    base_b = A @ np.array(pr["base"], float)
    T = np.eye(4); T[:3, 3] = base_b
    Rz = np.eye(4); Rz[:3, :3] = np.array(Matrix.Rotation(yaw, 3, "Z"))
    S = np.diag([s, s, s, 1.0])
    C0 = np.eye(4); C0[:3, 3] = -center
    place(me, T @ Rz @ S @ C0)

for ep in data["envparts"]:
    vs = load_variants(ep["kind"])
    if not vs:
        continue
    cf = ep["cf"]
    me, lo, hi = vs[hashpos(cf[:3]) % len(vs)]
    grow = 1.15 if ep["kind"] == "Boulder" else 1.0
    size = np.array(ep["size"], float) * grow  # roblox local x, y(up), z
    ext = hi - lo  # blender mesh extents x, y, z(up)
    # local roblox axes in blender terms: x->x, y(up)->z, z->-y
    sx, sy, sz = size[0] / max(ext[0], 1e-3), size[2] / max(ext[1], 1e-3), size[1] / max(ext[2], 1e-3)
    C0 = np.eye(4); C0[:3, 3] = -(lo + hi) / 2
    S = np.diag([sx, sy, sz, 1.0])
    R = np.array(cf[3:], float).reshape(3, 3)
    M = np.eye(4); M[:3, :3] = A @ R @ A.T; M[:3, 3] = A @ np.array(cf[:3], float)
    place(me, M @ S @ C0)

# ---------- sea, sky, light ----------
bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, 0))
water = bpy.context.object
wm = bpy.data.materials.new("water")
wm.use_nodes = True
b = wm.node_tree.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.05, 0.42, 0.55, 1)
b.inputs["Roughness"].default_value = 0.15
b.inputs["Alpha"].default_value = 0.78
water.data.materials.append(wm)
bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, -6))
sand = bpy.context.object
sm = bpy.data.materials.new("lagoon")
sm.use_nodes = True
sm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.75, 0.7, 1)
sand.data.materials.append(sm)

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.75, 1.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.2
sun.angle = 0.2
so = bpy.data.objects.new("sun", sun)
so.rotation_euler = (math.radians(40), math.radians(15), math.radians(120))
scene.collection.objects.link(so)

scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 3
scene.render.threads_mode = "AUTO"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000


def shot(name, loc, target, ortho=None, lens=35):
    cam = bpy.data.cameras.new(name)
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    cam.lens = lens
    cam.clip_end = 5000
    co = bpy.data.objects.new(name, cam)
    scene.collection.objects.link(co)
    co.location = loc
    d = Vector(target) - Vector(loc)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.camera = co
    scene.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)


# island center in Blender: Daybreak x = 0
import os as _os
if _os.environ.get("ONLY") == "ramps":
    scene.render.resolution_x, scene.render.resolution_y = 1200, 760
    shot("ramp_terrace", (40, -40, 22), (-12, -64, 8), lens=30)      # the terrace ramp (east side), like the owner's screenshot
    shot("ramp_north", (-45, -40, 40), (-45, -100, 12), lens=30)     # north hill ramp (faces the village side, -Z)
    shot("ramp_bandit", (-35, 50, 45), (-35, 110, 12), lens=30)
    raise SystemExit
if _os.environ.get("ONLY") == "review":
    # Roblox (x, y, z) -> Blender (x, -z, y)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 760
    shot("village", (0, 90, 70), (60, 0, 8), lens=28)               # like the owner's screenshot 2
    shot("tavern", (86, 16, 20), (112, 37, 9), lens=35)
    shot("spawn", (-152, -10, 14), (-108, -34, 12), lens=30)        # eye level at the spawn, looking down the trail
    shot("hill", (35, -150, 50), (-40, -110, 12), lens=32)
    shot("harbor", (330, 0, 60), (230, 0, 0), lens=35)
    raise SystemExit
if _os.environ.get("ONLY") == "plaza":
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    shot("plaza", (60, 0, 400), (60, 0.001, 0), ortho=130)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    shot("quay", (300, -50, 60), (225, 0, 7), lens=35)
    raise SystemExit
if _os.environ.get("ONLY") == "conch":
    # Conch Bay after tools/island_local.py (pier = +Z in Roblox = -Y here)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 1200
    shot("top", (0, 0, 900), (0, 0.001, 0), ortho=540)
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    shot("aerial", (240, -420, 190), (0, -20, 10), lens=30)              # the concept's aerial view
    shot("market", (14, -214, 14), (0, 58, 84), lens=26)               # street level by the stalls: tall tower ahead
    shot("stairs", (0, -140, 22), (0, 40, 40), lens=26)                 # on terrace 1, up the stairs to the gate
    shot("yard", (30, -20, 36), (0, 58, 50), lens=26)                   # inside the gate: courtyard + towers
    raise SystemExit
if _os.environ.get("ONLY") == "marm":
    # Marmalade Town after tools/island_local.py (harbor = +Z in Roblox = -Y here)
    scene.render.resolution_x, scene.render.resolution_y = 1200, 1200
    shot("top", (0, 0, 900), (0, 0.001, 0), ortho=540)
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    shot("aerial", (70, -440, 240), (0, 10, 10), lens=30)               # the concept's view from the harbor
    shot("boulevard", (8, -186, 14), (0, 110, 20), lens=26)            # street level off the ship, toward the hall
    shot("square", (40, 40, 16), (0, 108, 15), lens=26)                # the town hall square + clock tower
    shot("ship", (70, -235, 34), (0, -302, 14), lens=30)               # the circus ship at anchor + pier
    raise SystemExit
if _os.environ.get("ONLY") == "close":
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    shot("close", (150, -60, 40), (70, 0, 12), lens=35)
    shot("camp", (-120, 30, 30), (-165, 0, 8), lens=30)
    raise SystemExit
scene.render.resolution_x, scene.render.resolution_y = 1400, 1400
shot("top", (0, 0, 900), (0, 0.001, 0), ortho=560)
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
# like the concept: from the harbor side (east, +X), high and looking west
shot("harbor", (520, 40, 330), (-10, 0, 0), lens=30)
# from the jungle side looking east over the camp toward the village
shot("jungle", (-330, -60, 120), (-60, 10, 10), lens=28)
