"""Grand Voyage Blender toolkit: primitives, palette material, toon outline, glTF export for Roblox, preview renders.

Game models are ONE mesh with ONE palette texture (every face's UVs point at its color swatch), so the Roblox importer
turns them into a single MeshPart. The toon outline is an inverted hull inside the same mesh: Roblox culls back faces,
so only the far side of the hull shows around the silhouette, exactly like in the icon renders.
"""
import math
import bpy
import bmesh
import addon_utils
from mathutils import Vector

for mod in ("cycles", "io_scene_gltf2"):
    try:
        addon_utils.enable(mod, default_set=True)
    except Exception:
        pass

OUTLINE = "#140f22"
PAL_CELLS = 16  # 16x16 swatches in a 256 px texture


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ---------------- scene ----------------
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def _tag(o, color):
    o["gvcolor"] = color
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def _bevel(o, width):
    if width > 0:
        m = o.modifiers.new("bev", "BEVEL")
        m.width = width
        m.segments = 2
        m.limit_method = "ANGLE"


def box(size, loc, color, rot=(0, 0, 0), bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    _bevel(o, bevel)
    o["gvcolor"] = color
    return o


def ball(r, loc, color, scale=(1, 1, 1), seg=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=max(8, seg // 2), rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _tag(o, color)


def cyl(r, depth, loc, color, rot=(0, 0, 0), verts=20, bevel=0.03):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    _bevel(o, bevel)
    o["gvcolor"] = color
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return o


def cone(r1, r2, depth, loc, color, rot=(0, 0, 0), verts=20):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    return _tag(bpy.context.object, color)


def torus(R, r, loc, color, rot=(0, 0, 0), major=32, minor=10):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=major, minor_segments=minor)
    return _tag(bpy.context.object, color)


def tube(points, r, color, taper=None, res=3):
    """A smooth round tube through `points` (swirls, legs, tails, antennae). taper: end radius factor (cone-like tip)."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        w = 1.0 if taper is None else 1.0 + (taper - 1.0) * i / max(1, len(points) - 1)
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        sp.points[i].radius = w
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    sp.resolution_u = 6
    o = bpy.data.objects.new("tube", cu)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    return _tag(o, color)


def apply_mods(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception:
            o.modifiers.remove(m)


def eyes(x, y, z, color="#1b1630", r=0.13, spread=0.22, shine=True):
    """chibi eyes on the -Y face: dark ovals with a white highlight"""
    for s in (-1, 1):
        ball(r, (x + s * spread, y, z), color, scale=(0.8, 0.5, 1.1))
        if shine:
            ball(r * 0.36, (x + s * spread + r * 0.25, y - r * 0.42, z + r * 0.4), "#ffffff")
            ball(r * 0.16, (x + s * spread - r * 0.25, y - r * 0.45, z - r * 0.45), "#ffffff")


# ---------------- palette + outline ----------------
class Palette:
    def __init__(self):
        self.colors = []

    def cell(self, color):
        if color not in self.colors:
            self.colors.append(color)
        i = self.colors.index(color)
        cx, cy = i % PAL_CELLS, i // PAL_CELLS
        return ((cx + 0.5) / PAL_CELLS, 1 - (cy + 0.5) / PAL_CELLS)

    def image(self, name="gv_palette"):
        size = PAL_CELLS * 16
        img = bpy.data.images.new(name, size, size, alpha=False)
        px = [0.0] * (size * size * 4)
        for i, color in enumerate(self.colors):
            c = rgb(color)
            cx, cy = i % PAL_CELLS, i // PAL_CELLS
            for y in range(cy * 16, cy * 16 + 16):
                for x in range(cx * 16, cx * 16 + 16):
                    k = ((size - 1 - y) * size + x) * 4
                    px[k:k + 4] = [lin(c[0]), lin(c[1]), lin(c[2]), 1.0]
        img.pixels = px
        img.pack()
        return img


def build_mesh(name, outline=0.04, target=None):
    """Join every tagged object into one mesh with palette UVs (+ inverted hull outline). Returns the object."""
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type == "MESH" and "gvcolor" in o]
    pal = Palette()
    for o in objs:
        apply_mods(o)
        me = o.data
        uv = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
        u, v = pal.cell(o["gvcolor"])
        for loop in me.loops:
            uv.data[loop.index].uv = (u, v)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    if target:
        s = target / max(obj.dimensions)
        obj.scale = (s, s, s)
    obj.location = (0, 0, 0)
    bpy.ops.object.transform_apply(scale=True, location=True)
    # palette material
    img = pal.image()
    m = bpy.data.materials.new("gv_palette")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.45
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(m)
    obj["outline"] = outline
    obj["outline_uv"] = pal.cell(OUTLINE)
    return obj


def make_hull(obj):
    """Inverted hull as a separate object (same palette material, UVs on the outline swatch)."""
    hull = obj.copy()
    hull.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(hull)
    bm = bmesh.new()
    bm.from_mesh(hull.data)
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.active
    ou = tuple(obj["outline_uv"])
    for v in bm.verts:
        v.co += v.normal * obj["outline"]
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    for f in bm.faces:
        for l in f.loops:
            l[uv_layer].uv = ou
    bm.to_mesh(hull.data)
    bm.free()
    return hull


def export_glb(obj, path):
    """Export for Roblox (mesh + outline hull as ONE mesh). The model faces Blender -Y; it is turned to face Roblox -Z."""
    tmp = obj.copy()
    tmp.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(tmp)
    parts = [tmp]
    if obj.get("outline", 0) > 0:
        parts.append(make_hull(obj))
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tmp
    bpy.ops.object.join()
    tmp.rotation_euler = (0, 0, math.pi)
    bpy.ops.object.transform_apply(rotation=True)
    bpy.ops.object.select_all(action="DESELECT")
    tmp.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_materials="EXPORT", export_image_format="AUTO")
    bpy.data.objects.remove(tmp)


# ---------------- preview render (Cycles, same look as the icons) ----------------
def preview(obj, path, size=256, samples=16, yaw=-25):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.exposure = -0.35
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.65, 0.8, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(obj.dimensions) * 1.25
    sc.collection.objects.link(cam)
    cam.location = (0, -10, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    for name, loc, energy, size_ in (("key", (-3.5, -5, 4.5), 1700, 4), ("fill", (4, -4, 0.5), 450, 5), ("rim", (1.5, 5, 3.5), 2600, 3)):
        l = bpy.data.lights.new(name, "AREA")
        l.energy = energy
        l.size = size_
        o = bpy.data.objects.new(name, l)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    obj.rotation_euler = (math.radians(10), 0, math.radians(yaw))
    hull = None
    if obj.get("outline", 0) > 0:
        hull = make_hull(obj)
        om = bpy.data.materials.new("outline")
        om.use_nodes = True
        nt = om.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mix = nt.nodes.new("ShaderNodeMixShader")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs[0].default_value = (0.01, 0.008, 0.02, 1)
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
        nt.links.new(em.outputs[0], mix.inputs[1])
        nt.links.new(tr.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs[0])
        hull.data.materials.clear()
        hull.data.materials.append(om)
        hull.rotation_euler = obj.rotation_euler
        for attr in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter"):
            if hasattr(hull, attr):
                setattr(hull, attr, False)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    obj.rotation_euler = (0, 0, 0)
    if hull:
        bpy.data.objects.remove(hull)
