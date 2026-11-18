"""Render the Grand Voyage icon pack: chunky 3D items with glossy toon materials, a thick dark outline and rim light,
on a transparent background (the Anime Vanguards "3D render" icon look).

  blender -b -P tools/blender/render_icons.py -- --out assets/icons [--only coin,pearl] [--size 256] [--samples 24]
  (or with the bpy module:  python tools/blender/render_icons.py -- --out assets/icons)

Every icon is built from primitives in a builder function below, normalized to the same size and rendered with the
same camera and lights, so the set stays consistent. Add an icon = add a builder + an entry in ICONS.
"""
import math, os, sys
import bpy
import addon_utils
from mathutils import Vector

try:
    addon_utils.enable("cycles", default_set=True)
except Exception:
    pass

# ---------------- args ----------------
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/icons"))
ONLY = set(filter(None, arg("--only", "").split(",")))
SIZE = int(arg("--size", "256"))
SAMPLES = int(arg("--samples", "24"))
os.makedirs(OUT, exist_ok=True)

def rgb(h):
    """hex sRGB -> linear RGB (Blender color inputs are linear; passing sRGB straight in washes colors out)"""
    h = h.lstrip("#")
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))

_mats = {}

# ---------------- scene ----------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = SIZE
    sc.view_settings.view_transform = "Standard"  # keep colors punchy
    sc.view_settings.look = "None"
    sc.view_settings.exposure = -0.35
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.65, 0.8, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.75
    sc.collection.objects.link(cam)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    def light(name, kind, loc, energy, color, size=2.0):
        l = bpy.data.lights.new(name, kind)
        l.energy = energy
        l.color = color
        if kind == "AREA":
            l.size = size
        o = bpy.data.objects.new(name, l)
        sc.collection.objects.link(o)
        o.location = loc
        d = Vector((0, 0, 0)) - Vector(loc)
        o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    light("key", "AREA", (-3.5, -5, 4.5), 1700, (1.0, 0.96, 0.9), 4)
    light("fill", "AREA", (4, -4, 0.5), 450, (0.75, 0.85, 1.0), 5)
    light("rim", "AREA", (1.5, 5, 3.5), 2600, (1.0, 1.0, 1.0), 3)
    return sc

# ---------------- materials ----------------
def mat(color, rough=0.32, metal=0.0, emit=0.0, coat=0.6):
    key = (color, rough, metal, emit, coat)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = rgb(color) if isinstance(color, str) else color
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    for name in ("Coat Weight", "Clearcoat"):
        if name in b.inputs:
            b.inputs[name].default_value = coat
            break
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[key] = m
    return m

def swirl_mat(base, swirl):
    """Cursed-fruit skin: base color with swirling stripes (wave texture, rings + distortion)."""
    m = bpy.data.materials.new("swirl")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.3
    for name in ("Coat Weight", "Clearcoat"):
        if name in b.inputs:
            b.inputs[name].default_value = 0.8
            break
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = 2.2
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*rgb(base), 1)
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = (*rgb(swirl), 1)
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m

def outline_mat():
    m = bpy.data.materials.new("outline")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (0.02, 0.015, 0.04, 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    # inverted hull: faces of the shell that face the camera are see-through, the ones behind the object
    # (visible only around its silhouette) render dark -> a clean toon outline
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m

# ---------------- primitives ----------------
def _finish(o, m, smooth=True, bevel=0.0):
    o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    if bevel > 0:
        mod = o.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    return o

def box(size, loc, m, rot=(0, 0, 0), bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, m, smooth=False, bevel=bevel)

def ball(r, loc, m, scale=(1, 1, 1), seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg // 2)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, m)

def cyl(r, depth, loc, m, rot=(0, 0, 0), verts=32, bevel=0.03):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    _finish(o, m, smooth=False, bevel=bevel)
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return o

def cone(r1, r2, depth, loc, m, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    return _finish(bpy.context.object, m)

def torus(R, r, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=48, minor_segments=16)
    return _finish(bpy.context.object, m)

def star(points, r_out, r_in, depth, loc, m, rot=(0, 0, 0)):
    import bmesh
    me = bpy.data.meshes.new("star")
    bm = bmesh.new()
    verts = []
    for i in range(points * 2):
        a = i / (points * 2) * math.tau + math.pi / 2
        rr = r_out if i % 2 == 0 else r_in
        verts.append(bm.verts.new((math.cos(a) * rr, 0, math.sin(a) * rr)))
    f = bm.faces.new(verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.y += depth
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, -depth / 2, 0))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("star", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    return _finish(o, m, smooth=False, bevel=0.03)

# ---------------- palette ----------------
GOLD, GOLD_D = "#ffc93a", "#d98a14"
WOOD, WOOD_D = "#b9773f", "#7a4a26"
RED, BLUE, GREEN, PURPLE, PINK = "#ff4b5c", "#3f8cff", "#3fd977", "#9b5cff", "#ff6fb5"
WHITE, STEEL, DARK = "#f6f4ff", "#c9d3e6", "#2b2a3d"

# ---------------- icon builders ----------------
def coin():
    for i, z in enumerate((-0.55, -0.35, -0.15)):
        cyl(0.62, 0.2, (0.18 * (i - 1), 0.1, z), mat(GOLD, 0.25, 0.85), rot=(0, 0, 0))
    c = cyl(0.78, 0.22, (0, -0.1, 0.35), mat(GOLD, 0.22, 0.9), rot=(math.radians(80), 0, 0))
    star(5, 0.38, 0.17, 0.08, (0, -0.25, 0.37), mat(GOLD_D, 0.3, 0.9), rot=(math.radians(-10), 0, 0))

def pearl():
    shell = mat("#ff8fb3", 0.3)
    inner = mat("#ffd3e2", 0.25)
    ball(1.0, (0, 0.1, -0.5), shell, scale=(1.05, 0.85, 0.3))
    ball(0.92, (0, 0.05, -0.4), inner, scale=(1.0, 0.8, 0.2))
    top = ball(1.0, (0, 0.8, 0.3), shell, scale=(1.05, 0.22, 0.85))
    top.rotation_euler = (math.radians(-20), 0, 0)
    ball(0.5, (0, -0.35, -0.05), mat(WHITE, 0.05, coat=1.0))
    ball(0.12, (0.18, -0.78, 0.15), mat(WHITE, 0.0, emit=2.0))

def gem():
    """the premium currency (v0.22.4: Pearls became Gems): a brilliant-cut blue gem with a sparkle"""
    body = mat("#3cc8ff", 0.04, emit=0.35, coat=1.0)
    deep = mat("#1b7ff0", 0.05, emit=0.25, coat=1.0)
    # crown (top, faceted) + table + pavilion (pointed bottom)
    cone(1.0, 0.62, 0.42, (0, 0, 0.21), body, verts=8)
    cyl(0.62, 0.04, (0, 0, 0.43), mat("#bff0ff", 0.02, emit=0.6, coat=1.0), verts=8, bevel=0.0)
    cone(1.0, 0.0, 1.05, (0, 0, -0.525), deep, rot=(math.pi, 0, 0), verts=8)

def chest():
    box((1.7, 1.1, 0.8), (0, 0, -0.35), mat(WOOD, 0.5))
    lid = box((1.75, 1.15, 0.5), (0, 0.05, 0.3), mat(WOOD, 0.5), rot=(math.radians(-8), 0, 0))
    for x in (-0.7, 0.7):
        box((0.14, 1.2, 1.4), (x, 0, -0.05), mat(GOLD, 0.25, 0.85), bevel=0.03)
    box((0.3, 0.12, 0.38), (0, -0.6, 0.0), mat(GOLD, 0.25, 0.85))
    for i in range(6):
        ball(0.17, (-0.5 + i * 0.2, -0.1, 0.62 + (i % 2) * 0.08), mat(GOLD, 0.2, 0.9))
    ball(0.2, (0.35, -0.2, 0.8), mat("#5ad7ff", 0.05, 0.0, emit=0.4), scale=(1, 1, 1.3))

def bag():
    sack = mat("#c9773b", 0.55)
    ball(0.95, (0, 0, -0.3), sack, scale=(1.0, 0.85, 0.9))
    cone(0.62, 0.32, 0.45, (0, 0, 0.6), sack)
    cone(0.32, 0.6, 0.38, (0, 0, 0.98), mat("#d98a4b", 0.55))
    torus(0.34, 0.08, (0, 0, 0.78), mat("#7a4a26", 0.5))
    box((0.12, 0.1, 0.5), (0.3, -0.25, 0.55), mat("#7a4a26", 0.5), rot=(0, math.radians(30), 0), bevel=0.03)
    for x, z in ((-0.25, 1.1), (0.15, 1.18), (0.4, 1.05)):
        ball(0.2, (x, -0.05, z), mat(GOLD, 0.2, 0.9))
    star(5, 0.3, 0.13, 0.08, (0, -0.8, -0.3), mat(GOLD, 0.25, 0.85))

def stats():
    for i, (h, c) in enumerate(((0.7, BLUE), (1.2, GREEN), (1.7, GOLD))):
        box((0.42, 0.42, h), (-0.6 + i * 0.6, 0, -0.85 + h / 2), mat(c, 0.3))
    o = cone(0.0, 0.22, 0.4, (0.9, -0.2, 0.95), mat(RED, 0.3), rot=(0, math.radians(-50), 0))
    box((0.14, 0.14, 1.2), (0.35, -0.2, 0.45), mat(RED, 0.3), rot=(0, math.radians(-50), 0))

def skills():
    star(4, 1.1, 0.32, 0.3, (0, 0, 0), mat(GOLD, 0.2, 0.3, emit=0.3), rot=(0, 0, 0))
    star(4, 0.45, 0.14, 0.2, (0.85, -0.2, 0.75), mat("#fff1a8", 0.2, emit=0.6))
    star(4, 0.3, 0.1, 0.2, (-0.85, -0.2, -0.7), mat("#fff1a8", 0.2, emit=0.6))

def ship():
    hull = ball(1.0, (0, 0, -0.55), mat(WOOD, 0.5), scale=(1.15, 0.5, 0.45))
    box((2.0, 0.9, 0.18), (0, 0, -0.25), mat(WOOD_D, 0.5))
    cyl(0.07, 1.8, (0, 0, 0.55), mat(WOOD_D, 0.5))
    box((1.1, 0.12, 0.9), (0, -0.1, 0.65), mat(WHITE, 0.45), bevel=0.08)
    box((0.5, 0.06, 0.28), (0.3, -0.12, 1.32), mat(RED, 0.4), bevel=0.02)

def anchor():
    m = mat("#9fb3cc", 0.25, 0.8)
    cyl(0.12, 1.6, (0, 0, 0.05), m)
    torus(0.24, 0.08, (0, 0, 1.05), m, rot=(math.radians(90), 0, 0))
    box((0.9, 0.18, 0.16), (0, 0, 0.6), m)
    torus(0.75, 0.1, (0, 0, -0.1), m, rot=(math.radians(90), 0, 0))
    box((2.0, 0.6, 1.0), (0, 0, 0.5), mat("#000000", 1), bevel=0)  # cut helper (removed below)
    bpy.data.objects.remove(bpy.context.object)
    for x in (-0.78, 0.78):
        cone(0.2, 0.0, 0.35, (x, 0, -0.05), m, rot=(0, 0, 0))

def flag():
    cyl(0.06, 2.3, (-0.85, 0, 0), mat(WOOD_D, 0.5))
    ball(0.12, (-0.85, 0, 1.18), mat(GOLD, 0.25, 0.85))
    f = box((1.5, 0.08, 1.0), (0.0, 0, 0.5), mat(DARK, 0.6), bevel=0.04)
    sw = f.modifiers.new("wave", "SIMPLE_DEFORM")
    sw.deform_method = "BEND"
    sw.angle = math.radians(25)
    sk = ball(0.26, (0.0, -0.08, 0.55), mat(WHITE, 0.4), scale=(1, 0.4, 1))
    for s in (1, -1):
        box((0.7, 0.06, 0.08), (0.0, -0.1, 0.55), mat(WHITE, 0.4), rot=(0, math.radians(35 * s), 0), bevel=0.02)

def party():
    for x, c, s in ((-0.45, BLUE, 0.95), (0.45, GREEN, 1.0)):
        ball(0.4 * s, (x, 0, 0.55), mat("#ffd6b0", 0.5))
        ball(0.62 * s, (x, 0.05, -0.45), mat(c, 0.4), scale=(1, 0.75, 1.0))

def mapicon():
    o = box((1.8, 0.06, 1.4), (0, 0, 0), mat("#f3dca4", 0.7), bevel=0.02)
    o.rotation_euler = (0, math.radians(-8), 0)
    for x in (-0.95, 0.95):
        cyl(0.13, 1.5, (x, -0.02, 0), mat("#e3c27c", 0.6))
    for i in range(5):
        box((0.12, 0.04, 0.05), (-0.5 + i * 0.18, -0.06, -0.3 + math.sin(i) * 0.15), mat("#d0423b", 0.5), bevel=0.01)
    for s in (1, -1):
        box((0.45, 0.06, 0.1), (0.45, -0.07, 0.25), mat(RED, 0.4), rot=(0, math.radians(45 * s), 0), bevel=0.02)

def crown():
    m = mat(GOLD, 0.22, 0.9)
    cyl(0.85, 0.45, (0, 0, -0.55), m)
    for i in range(5):
        a = i / 5 * math.tau
        cone(0.28, 0.0, 0.9, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.1), m)
        ball(0.1, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.58), m)
    for i in range(3):
        a = -math.pi / 2 + (i - 1) * 0.6
        ball(0.15, (math.cos(a) * 0.86, math.sin(a) * 0.86, -0.55), mat((RED, BLUE, GREEN)[i], 0.05, emit=0.2))

def scroll():
    box((1.3, 0.06, 1.5), (0, 0, 0), mat("#f6e2b3", 0.7), bevel=0.02)
    for z in (0.78, -0.78):
        cyl(0.17, 1.65, (0, 0, z), mat("#e8cd8e", 0.6), rot=(0, math.radians(90), 0))
        for x in (0.9, -0.9):
            ball(0.12, (x, 0, z), mat(WOOD_D, 0.5))
    for i in range(4):
        box((0.8 - i * 0.1, 0.03, 0.06), (0, -0.05, 0.4 - i * 0.25), mat("#9b7d52", 0.6), bevel=0.01)
    box((0.25, 0.05, 0.6), (0.3, -0.07, -0.45), mat(RED, 0.4), bevel=0.02)

def paw():
    m = mat("#ffb36b", 0.45)
    ball(0.55, (0, 0, -0.35), m, scale=(1.15, 0.6, 0.95))
    for x, z in ((-0.7, 0.3), (-0.25, 0.65), (0.25, 0.65), (0.7, 0.3)):
        ball(0.24, (x, 0, z), m, scale=(1, 0.6, 1.2))

def gear():
    m = mat("#aab6c8", 0.3, 0.8)
    cyl(0.75, 0.32, (0, 0, 0), m, rot=(math.radians(90), 0, 0))
    for i in range(8):
        a = i / 8 * math.tau
        box((0.3, 0.32, 0.32), (math.cos(a) * 0.85, 0, math.sin(a) * 0.85), m, rot=(0, -a, 0), bevel=0.04)
    cyl(0.28, 0.4, (0, 0, 0), mat(DARK, 0.5), rot=(math.radians(90), 0, 0))

def skull():
    m = mat(WHITE, 0.45)
    ball(0.8, (0, 0, 0.15), m, scale=(1, 0.95, 0.95))
    box((0.8, 0.7, 0.45), (0, -0.1, -0.55), m, bevel=0.15)
    for x in (-0.3, 0.3):
        ball(0.22, (x, -0.68, 0.1), mat(DARK, 0.6), scale=(1, 0.5, 1.1))
    for s in (1, -1):
        box((2.1, 0.25, 0.25), (0, 0.3, -0.2), m, rot=(0, math.radians(35 * s), 0), bevel=0.1)

def whiteflag():
    cyl(0.06, 2.3, (-0.85, 0, 0), mat(WOOD_D, 0.5))
    f = box((1.5, 0.08, 1.0), (0.0, 0, 0.5), mat(WHITE, 0.6), bevel=0.04)
    sw = f.modifiers.new("wave", "SIMPLE_DEFORM")
    sw.deform_method = "BEND"
    sw.angle = math.radians(25)

# weapons and gear
def sword():
    m_blade = mat(STEEL, 0.15, 0.9)
    box((0.34, 0.1, 1.9), (0, 0, 0.25), m_blade, bevel=0.04)
    cone(0.24, 0.0, 0.45, (0, 0, 1.42), m_blade, verts=4)
    box((0.95, 0.3, 0.18), (0, 0, -0.75), mat(GOLD, 0.25, 0.85))
    cyl(0.14, 0.6, (0, 0, -1.12), mat("#3a2a55", 0.6))
    ball(0.17, (0, 0, -1.45), mat(GOLD, 0.25, 0.85))

def knuckles():
    m = mat(GOLD, 0.25, 0.85)
    box((1.6, 0.4, 0.45), (0, 0, 0.2), m, bevel=0.15)
    for i in range(4):
        torus(0.2, 0.09, (-0.57 + i * 0.38, 0, 0.2), m, rot=(math.radians(90), 0, 0))
    box((1.2, 0.35, 0.3), (0, 0, -0.35), m, bevel=0.12)

def slingshot():
    m = mat(WOOD, 0.5)
    cyl(0.12, 1.1, (0, 0, -0.65), m)
    for s in (1, -1):
        cyl(0.11, 1.0, (0.2 * s, 0, 0.36), m, rot=(0, math.radians(22 * s), 0))
    box((0.85, 0.05, 0.08), (0, 0, 0.62), mat(RED, 0.5), bevel=0.02)
    box((0.3, 0.12, 0.2), (0, -0.05, 0.62), mat("#7a4a26", 0.6), bevel=0.04)

def boots():
    m = mat("#d84f3d", 0.5)
    box((0.55, 0.6, 1.0), (-0.25, 0, 0.2), m, bevel=0.15)
    box((1.15, 0.6, 0.45), (0.05, 0, -0.45), m, bevel=0.18)
    box((1.2, 0.65, 0.12), (0.05, 0, -0.72), mat(DARK, 0.6), bevel=0.04)
    box((0.62, 0.66, 0.14), (-0.25, 0, 0.62), mat(GOLD, 0.25, 0.85), bevel=0.04)

def staff():
    cyl(0.09, 2.3, (0, 0, -0.1), mat("#6b8cc4", 0.35, 0.4))
    ball(0.38, (0, 0, 1.1), mat("#7fd4ff", 0.05, emit=0.8))
    torus(0.42, 0.07, (0, 0, 1.1), mat(GOLD, 0.25, 0.85), rot=(math.radians(70), 0, 0))
    star(4, 0.28, 0.08, 0.06, (0.45, -0.2, 1.5), mat("#fff1a8", 0.2, emit=1.0))

def medkit():
    box((1.6, 0.8, 1.1), (0, 0, -0.1), mat(WHITE, 0.35), bevel=0.15)
    box((0.7, 0.2, 0.22), (0, -0.42, -0.1), mat(RED, 0.35), bevel=0.04)
    box((0.22, 0.2, 0.7), (0, -0.42, -0.1), mat(RED, 0.35), bevel=0.04)
    torus(0.28, 0.07, (0, 0, 0.55), mat(DARK, 0.5), rot=(math.radians(90), 0, 0))

def hammer():
    box((1.3, 0.6, 0.6), (0, 0, 0.75), mat("#9aa4b8", 0.25, 0.8), bevel=0.08)
    cyl(0.11, 1.7, (0, 0, -0.35), mat(WOOD, 0.5))
    box((0.3, 0.64, 0.64), (0.55, 0, 0.75), mat(GOLD, 0.25, 0.85), bevel=0.04)

def armor():
    m = mat(BLUE, 0.4)
    box((1.3, 0.6, 1.4), (0, 0, -0.1), m, bevel=0.25)
    for s in (1, -1):
        ball(0.36, (0.72 * s, 0, 0.45), mat(GOLD, 0.25, 0.85), scale=(1, 0.8, 0.7))
    box((0.16, 0.64, 1.1), (0, 0, -0.15), mat(GOLD, 0.25, 0.85), bevel=0.05)

def hat():
    cyl(1.05, 0.12, (0, 0, -0.35), mat("#f2d47a", 0.6))
    ball(0.6, (0, 0, -0.2), mat("#f2d47a", 0.6), scale=(1, 1, 0.8))
    cyl(0.62, 0.16, (0, 0, -0.18), mat(RED, 0.4))

def charm():
    torus(0.55, 0.1, (0, 0, 0.1), mat(GOLD, 0.22, 0.9), rot=(math.radians(90), 0, 0))
    ball(0.38, (0, 0, 0.1), mat("#5ad7ff", 0.05, emit=0.3), scale=(1, 0.6, 1))
    ball(0.16, (0, -0.25, 0.1), mat(DARK, 0.4), scale=(1, 0.5, 1))
    cone(0.12, 0.0, 0.3, (0, 0, -0.62), mat(GOLD, 0.22, 0.9), rot=(math.radians(180), 0, 0))

def meat():
    ball(0.75, (0.2, 0, 0.15), mat("#c0533a", 0.45), scale=(1.2, 0.8, 0.9))
    cyl(0.12, 1.3, (-0.6, 0, -0.5), mat(WHITE, 0.4), rot=(0, math.radians(-40), 0))
    for x, z in ((-1.05, -0.95), (-0.9, -1.05)):
        ball(0.17, (x, 0, z), mat(WHITE, 0.4))

def juice():
    ball(0.6, (0, 0, -0.35), mat("#ff9b2f", 0.08, coat=1.0), scale=(1, 1, 1.05))
    cyl(0.2, 0.55, (0, 0, 0.45), mat("#ffd9a8", 0.1))
    cyl(0.24, 0.18, (0, 0, 0.78), mat(WOOD, 0.5))
    ball(0.15, (0.25, -0.45, -0.1), mat(WHITE, 0.05, emit=0.4))

def repairkit():
    box((1.6, 0.8, 0.9), (0, 0, -0.3), mat("#e4502f", 0.4), bevel=0.1)
    box((1.62, 0.82, 0.12), (0, 0, 0.05), mat(DARK, 0.5), bevel=0.03)
    torus(0.32, 0.07, (0, 0, 0.35), mat(DARK, 0.5), rot=(math.radians(90), 0, 0))
    box((0.25, 0.1, 1.2), (0.55, -0.42, 0.4), mat(STEEL, 0.2, 0.9), rot=(0, math.radians(-30), 0), bevel=0.03)

def book():
    box((1.3, 0.35, 1.6), (0, 0, 0), mat("#3a6fd8", 0.45), bevel=0.06)
    box((1.18, 0.3, 1.5), (0.06, 0, 0), mat("#fff6e0", 0.7), bevel=0.02)
    box((1.3, 0.08, 1.6), (0, -0.2, 0), mat("#3a6fd8", 0.45), bevel=0.04)
    star(5, 0.32, 0.14, 0.06, (0, -0.26, 0.1), mat(GOLD, 0.25, 0.85))

def ore():
    ball(0.75, (0, 0, -0.2), mat("#7e7f8e", 0.7), scale=(1.2, 0.9, 0.85))
    for x, z, s in ((-0.35, 0.35, 0.5), (0.3, 0.45, 0.6), (0.6, 0.05, 0.4)):
        cone(0.22 * s * 2, 0.0, 0.9 * s * 1.5, (x, -0.2, z), mat("#9ad0ff", 0.05, emit=0.25), rot=(0, x * 0.8, 0), verts=6)

def shard():
    for x, h, r in ((0, 1.6, 0.35), (-0.45, 1.0, 0.25), (0.45, 1.1, 0.25)):
        cone(r, 0.0, h, (x, 0, -0.4 + h / 2), mat("#5ad7ff", 0.05, emit=0.35), verts=6)
        cone(r, 0.0, 0.35, (x, 0, -0.55), mat("#5ad7ff", 0.05, emit=0.35), rot=(math.pi, 0, 0), verts=6)

def wood():
    for i, (x, z) in enumerate(((-0.35, -0.4), (0.35, -0.4), (0, 0.18))):
        cyl(0.36, 1.7, (x, 0, z), mat(WOOD, 0.6), rot=(0, math.radians(90), math.radians(12)))
        cyl(0.3, 1.72, (x, 0, z), mat("#e8c08a", 0.6), rot=(0, math.radians(90), math.radians(12)))

def cloth():
    for i, c in enumerate((WHITE, "#d8e6ff", WHITE)):
        box((1.6, 0.9, 0.28), (0.05 * i, 0, -0.45 + i * 0.32), mat(c, 0.7), bevel=0.12)
    box((0.18, 0.95, 1.1), (0, 0, -0.1), mat(RED, 0.5), bevel=0.04)

def card():
    box((1.15, 0.08, 1.6), (0, 0, 0), mat(PURPLE, 0.3), rot=(0, math.radians(-10), 0), bevel=0.06)
    box((0.95, 0.06, 1.0), (0, -0.05, 0.12), mat("#e9e3ff", 0.4), rot=(0, math.radians(-10), 0), bevel=0.03)
    star(5, 0.3, 0.13, 0.06, (0.0, -0.1, 0.12), mat(GOLD, 0.25, 0.85), rot=(0, math.radians(-10), 0))

def egg(color="#bfefff", spots="#5bb8e8"):
    ball(0.8, (0, 0, 0), mat(color, 0.25, coat=1.0), scale=(0.85, 0.85, 1.12))
    for x, z, s in ((-0.35, 0.3, 0.17), (0.3, -0.1, 0.22), (-0.15, -0.5, 0.15), (0.35, 0.5, 0.12)):
        ball(s, (x, -0.62, z), mat(spots, 0.3), scale=(1, 0.4, 1))

def golden_egg():
    egg(GOLD, "#ff8a3a")
    for i in range(3):
        star(4, 0.22, 0.06, 0.05, (0.75 - i * 0.15, -0.5, 0.9 - i * 0.55), mat("#fff1a8", 0.2, emit=1.2))

def bait():
    m = mat(STEEL, 0.15, 0.9)
    torus(0.45, 0.07, (0, 0, -0.35), m, rot=(math.radians(90), 0, 0))
    cyl(0.07, 1.4, (0.45, 0, 0.35), m)
    torus(0.12, 0.05, (0.45, 0, 1.1), m, rot=(math.radians(90), 0, 0))
    ball(0.28, (-0.2, -0.05, -0.75), mat("#ff8fb1", 0.4), scale=(1.6, 1, 0.8))

def make_fruit(color, swirl):
    def build():
        ball(0.85, (0, 0, -0.1), swirl_mat(color, swirl), scale=(1.05, 1.05, 0.95), seg=48)
        cyl(0.07, 0.5, (0.05, 0, 0.95), mat(WOOD_D, 0.5), rot=(0, math.radians(15), 0))
        leaf = ball(0.3, (0.38, 0, 1.0), mat("#4fc35a", 0.4), scale=(1.2, 0.25, 0.55))
        leaf.rotation_euler = (0, math.radians(-25), 0)
    return build

def potion_red():
    juice_m = mat("#ff4b5c", 0.08, coat=1.0)
    ball(0.6, (0, 0, -0.35), juice_m)
    cyl(0.2, 0.55, (0, 0, 0.45), mat("#ffd0d6", 0.1))
    cyl(0.24, 0.18, (0, 0, 0.78), mat(WOOD, 0.5))

ICONS = {
    # menu + currencies
    "coin": (coin, (-15, 10)), "pearl": (pearl, (-20, 0)), "gem": (gem, (22, 0)), "chest": (chest, (-25, 15)), "bag": (bag, (-20, 0)),
    "stats": (stats, (-25, 10)), "skills": (skills, (-15, 0)), "ship": (ship, (-30, 10)), "anchor": (anchor, (-20, 0)),
    "flag": (flag, (-25, 5)), "party": (party, (-20, 0)), "map": (mapicon, (-20, 15)), "crown": (crown, (-20, 20)),
    "scroll": (scroll, (-20, 5)), "paw": (paw, (-15, 0)), "gear": (gear, (-25, 10)), "skull": (skull, (-20, 5)),
    "whiteflag": (whiteflag, (-25, 5)),
    # weapons / gear
    "sword": (sword, (-20, -35)), "knuckles": (knuckles, (-25, 15)), "slingshot": (slingshot, (-20, -10)),
    "boots": (boots, (-30, 5)), "staff": (staff, (-20, -25)), "medkit": (medkit, (-30, 10)), "hammer": (hammer, (-25, -30)),
    "armor": (armor, (-25, 5)), "hat": (hat, (-20, 25)), "charm": (charm, (-20, 5)),
    # consumables / materials / misc
    "meat": (meat, (-25, 10)), "juice": (juice, (-20, 5)), "potion": (potion_red, (-20, 5)), "repairkit": (repairkit, (-30, 10)),
    "book": (book, (-25, 5)), "ore": (ore, (-25, 10)), "shard": (shard, (-20, 5)), "wood": (wood, (-30, 10)),
    "cloth": (cloth, (-30, 15)), "card": (card, (-15, 5)), "egg": (egg, (-15, 10)), "golden_egg": (golden_egg, (-15, 10)),
    "bait": (bait, (-15, 5)),
    # cursed fruits
    "fruit_bounce": (make_fruit("#ff78c8", "#9b3ce0"), (-15, 10)), "fruit_blaze": (make_fruit("#ff6a2a", "#ffd94a"), (-15, 10)),
    "fruit_haze": (make_fruit("#d7dbe4", "#8a8fa0"), (-15, 10)), "fruit_ward": (make_fruit("#7ad8ff", "#e9fbff"), (-15, 10)),
    "fruit_split": (make_fruit("#6fd27a", "#f0f07a"), (-15, 10)), "fruit_slick": (make_fruit("#ffe07a", "#fffbe0"), (-15, 10)),
}

def render_icon(name, builder, tilt):
    sc = reset()
    builder()
    meshes = [o for o in sc.objects if o.type == "MESH"]
    # apply modifiers, join, normalize to a 2.1-unit box centered at the origin
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except Exception:
                o.modifiers.remove(mod)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    obj.location = (0, 0, 0)
    dims = max(obj.dimensions)
    s = 2.1 / dims if dims > 0 else 1
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True, location=True)
    obj.rotation_euler = (math.radians(12), math.radians(tilt[1]), math.radians(tilt[0]))
    # thick toon outline: a separate inverted hull (copy pushed out along the normals, faces reversed). Its faces that
    # point at the camera sit behind the object and only show around the silhouette; the rest is see-through.
    if os.environ.get("NO_OUTLINE") != "1":
        import bmesh
        hull = obj.copy()
        hull.data = obj.data.copy()
        sc.collection.objects.link(hull)
        hull.data.materials.clear()
        hull.data.materials.append(outline_mat())
        bm = bmesh.new()
        bm.from_mesh(hull.data)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * 0.045
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(hull.data)
        bm.free()
        for poly in hull.data.polygons:
            poly.material_index = 0
        # camera-only: otherwise the shell shadows (and darkens) the whole object
        for attr in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter"):
            if hasattr(hull, attr):
                setattr(hull, attr, False)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("ICON", name)

for name, (builder, tilt) in ICONS.items():
    if ONLY and name not in ONLY:
        continue
    try:
        render_icon(name, builder, tilt)
    except Exception as e:
        print("FAIL", name, e)
