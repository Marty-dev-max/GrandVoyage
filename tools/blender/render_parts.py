"""Quick preview render of exported Roblox parts (JSON { parts = [{shape, cf, size, color}] }), e.g. from
tools/export_char.luau or tools/export_ship.luau.
python tools/blender/render_parts.py -- <parts.json> <out.png> [front|three|top] [width] [height]
Roblox (x, y up, z) -> Blender (x, -z, y up); Roblox front (-Z) faces Blender +Y, so "front" looks from +Y.
"""
import json, math, sys
import numpy as np
import bpy, bmesh
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
src, out = args[0], args[1]
view = args[2] if len(args) > 2 else "front"
W = int(args[3]) if len(args) > 3 else 1600
H = int(args[4]) if len(args) > 4 else 900
data = json.load(open(src))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
A = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)

CUBE = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)], float)
CUBE_FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
WEDGE = np.array([(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)], float)
WEDGE_FACES = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]

verts, faces, cols = [], [], []
images = [p for p in data["parts"] if p.get("img")]
for p in data["parts"]:
    if p.get("img"):
        continue
    unit, uf = (WEDGE, WEDGE_FACES) if p.get("shape") == "Wedge" else (CUBE, CUBE_FACES)
    cf = p["cf"]
    pos = np.array(cf[:3], float)
    R = np.array(cf[3:], float).reshape(3, 3)
    local = unit * np.array(p["size"], float)
    world = (R @ local.T).T + pos
    world = (A @ world.T).T
    base = len(verts)
    verts.extend(world.tolist())
    c = p.get("color", [0.8, 0.8, 0.8])
    for f in uf:
        faces.append([base + i for i in f])
        cols.append(c)

me = bpy.data.meshes.new("parts")
me.from_pydata(verts, [], faces)
me.update()
attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
li = 0
for poly, c in zip(me.polygons, cols):
    for _ in poly.loop_indices:
        attr.data[li].color = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1)
        li += 1
ob = bpy.data.objects.new("parts", me)
scene.collection.objects.link(ob)
mat = bpy.data.materials.new("vc")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
vc = nt.nodes.new("ShaderNodeVertexColor")
vc.layer_name = "Col"
nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85
me.materials.append(mat)

# face images: one textured quad each (alpha blended, tinted by "color")
import os
for k, p in enumerate(images):
    path = os.path.abspath(p["img"])
    if not os.path.exists(path):
        continue
    cf = p["cf"]
    pos = np.array(cf[:3], float)
    R = np.array(cf[3:], float).reshape(3, 3)
    w, h = p["size"][0], p["size"][1]
    quad = np.array([[-w / 2, -h / 2, 0], [w / 2, -h / 2, 0], [w / 2, h / 2, 0], [-w / 2, h / 2, 0]])
    wv = (A @ ((R @ quad.T).T + pos).T).T
    m = bpy.data.meshes.new(f"img{k}")
    m.from_pydata(wv.tolist(), [], [[0, 1, 2, 3]])
    uv = m.uv_layers.new()
    # front faces -Z, screen-left is +X: u runs from +X to -X
    for li, (uu, vv) in enumerate([(1, 0), (0, 0), (0, 1), (1, 1)]):
        uv.data[li].uv = (uu, vv)
    o = bpy.data.objects.new(f"img{k}", m)
    scene.collection.objects.link(o)
    mt = bpy.data.materials.new(f"imgm{k}")
    mt.use_nodes = True
    mt.blend_method = "BLEND" if hasattr(mt, "blend_method") else None
    t = mt.node_tree
    bs = t.nodes["Principled BSDF"]
    tex = t.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    mix = t.nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1
    c = p.get("color", [1, 1, 1])
    mix.inputs[2].default_value = (c[0] ** 2.2, c[1] ** 2.2, c[2] ** 2.2, 1)
    t.links.new(tex.outputs["Color"], mix.inputs[1])
    t.links.new(mix.outputs[0], bs.inputs["Base Color"])
    t.links.new(tex.outputs["Alpha"], bs.inputs["Alpha"])
    bs.inputs["Roughness"].default_value = 0.9
    m.materials.append(mt)

# ground + light + sky
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.01))
g = bpy.context.object
gm = bpy.data.materials.new("g")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.5, 0.75, 1)
g.data.materials.append(gm)
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.2
sun.angle = 0.1
so = bpy.data.objects.new("sun", sun)
so.rotation_euler = (math.radians(50), 0, math.radians(30))
scene.collection.objects.link(so)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.7, 1.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world

V = np.array(verts)
lo, hi = V.min(0), V.max(0)
center = (lo + hi) / 2
size = hi - lo
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
co = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(co)
aspect = W / H
if view == "top":
    co.location = (center[0], center[1], hi[2] + 50)
    co.rotation_euler = (0, 0, 0)
    cam.ortho_scale = max(size[0], size[1] * aspect) * 1.1
elif view == "three":
    d = Vector((1, 1.2, 0.8)).normalized()
    co.location = Vector(center) + d * 200
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = max(size[0], size[1]) * 1.25
else:
    co.location = (center[0], hi[1] + 60, center[2] + size[2] * 0.05)
    co.rotation_euler = (math.radians(88), 0, math.radians(180))
    cam.ortho_scale = max(size[0], size[2] * aspect) * 1.12
cam.clip_end = 2000
scene.camera = co
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.device = "CPU"
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.filepath = out
scene.view_settings.view_transform = "Standard"
bpy.ops.render.render(write_still=True)
print("rendered", out)
