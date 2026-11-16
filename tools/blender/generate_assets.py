"""
Grand Voyage low-poly asset generator for Blender (4.x / 5.x).

Builds stylized, flat-shaded low-poly models for every monster, ship part and a set of island props,
reading sizes/colors straight from the game's Lua configs so the models always match the game.
Each asset is exported as its own FBX with a shared palette texture (one material, UVs point at
palette swatches) which imports cleanly into Roblox Studio's 3D Importer.

Usage (Blender installed):
    blender -b -P tools/blender/generate_assets.py -- --out assets/models
    blender -b -P tools/blender/generate_assets.py -- --out assets/models --only monsters --preview
Usage (pip "bpy" module):
    python tools/blender/generate_assets.py --out assets/models --preview

Options:
    --only monsters|ships|props|<AssetId>[,...]   build a subset
    --preview                                     also render a PNG thumbnail per asset (Cycles, CPU)
    --blend                                       also save a .blend per category for hand-editing

Units: 1 Blender unit = 1 Roblox stud. In the 3D Importer set the scale unit to "Stud".
Orientation: models face -Y in Blender (exported as -Z forward, Y up) = Roblox LookVector.
Afterwards run tools/roblox/ImportHelper.lua in Studio to wire monsters/ship parts into ReplicatedStorage.Assets.
"""
import argparse, math, os, random, re, sys

import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CFG = os.path.join(ROOT, 'src', 'shared', 'Config')
GRID = 4.0  # studs per ship grid cell

# ---------------------------------------------------------------- config parsing
def rgb(r, g, b):
    return (int(r) / 255.0, int(g) / 255.0, int(b) / 255.0)

def parse_monsters():
    src = open(os.path.join(CFG, 'Monsters.lua'), encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'(mob|boss)\("(\w+)",\s*\{(.*?)\}\)\n', src, re.S):
        kind, mid, body = m.groups()
        style = re.search(r'style = \{(.*?)\}', body, re.S)
        if not style:
            continue
        st = style.group(1)
        shape = re.search(r'shape = "(\w+)"', st)
        col = re.search(r'Color3\.fromRGB\((\d+), (\d+), (\d+)\)', st)
        scale = re.search(r'scale = ([\d.]+)', st)
        hat = re.search(r'hat = "(\w+)"', st)
        out[mid] = {
            'shape': shape.group(1) if shape else 'humanoid',
            'color': rgb(*col.groups()) if col else (0.8, 0.8, 0.8),
            'scale': float(scale.group(1)) if scale else 1.0,
            'hat': hat.group(1) if hat else None,
            'boss': kind == 'boss',
        }
    return out

def parse_ship_parts():
    src = open(os.path.join(CFG, 'ShipParts.lua'), encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'part\("(\w+)",\s*\{(.*?)\}\)\n', src, re.S):
        pid, body = m.groups()
        size = re.search(r'size = Vector3\.new\((\d+), (\d+), (\d+)\)', body)
        col = re.search(r'color = Color3\.fromRGB\((\d+), (\d+), (\d+)\)', body)
        out[pid] = {
            'size': tuple(int(v) for v in size.groups()) if size else (1, 1, 1),
            'color': rgb(*col.groups()) if col else (0.77, 0.55, 0.35),
            'category': (re.search(r'category = "(\w+)"', body) or [None, 'Hull'])[1],
            'faction': (re.search(r'faction = "(\w+)"', body) or [None, None])[1],
        }
    return out

# ---------------------------------------------------------------- palette texture
PALETTE_SIZE = 16  # 16x16 swatches
_palette = []

def swatch(color):
    """Return the UV center of the palette swatch for this color (adds it if new)."""
    c = tuple(round(v, 3) for v in color)
    if c not in _palette:
        if len(_palette) >= PALETTE_SIZE * PALETTE_SIZE:
            raise RuntimeError('palette full')
        _palette.append(c)
    i = _palette.index(c)
    x, y = i % PALETTE_SIZE, i // PALETTE_SIZE
    return ((x + 0.5) / PALETTE_SIZE, 1 - (y + 0.5) / PALETTE_SIZE)

def build_palette_image(path):
    px = 8  # pixels per swatch
    n = PALETTE_SIZE * px
    img = bpy.data.images.get('GV_Palette') or bpy.data.images.new('GV_Palette', n, n, alpha=False)
    pixels = [0.0] * (n * n * 4)
    for i, c in enumerate(_palette):
        sx, sy = i % PALETTE_SIZE, PALETTE_SIZE - 1 - i // PALETTE_SIZE
        for yy in range(sy * px, sy * px + px):
            for xx in range(sx * px, sx * px + px):
                k = (yy * n + xx) * 4
                pixels[k:k + 4] = [c[0], c[1], c[2], 1.0]
    img.pixels[:] = pixels
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img

def palette_material():
    mat = bpy.data.materials.get('GV_Palette')
    if mat:
        return mat
    mat = bpy.data.materials.new('GV_Palette')
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get('Principled BSDF')
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.name = 'Palette'
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = 0.8
    return mat

# ---------------------------------------------------------------- mesh helpers
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.curves):
        for b in list(block):
            if b.users == 0:
                block.remove(b)

def _finish(obj, color, loc=(0, 0, 0), rot=(0, 0, 0)):
    obj.location = loc
    obj.rotation_euler = rot
    u, v = swatch(color)
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name='UVMap')
    for loop in me.uv_layers.active.data:
        loop.uv = (u, v)
    for p in me.polygons:
        p.use_smooth = False
    obj.data.materials.append(palette_material())
    obj['gv_color'] = color
    return obj

def box(size, color, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        m = o.modifiers.new('bevel', 'BEVEL')
        m.width = bevel
        m.segments = 1
        bpy.ops.object.modifier_apply(modifier=m.name)
    return _finish(o, color, loc, rot)

def ball(d, color, loc=(0, 0, 0), sub=1, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=d / 2)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(o, color, loc)

def cyl(depth, d, color, loc=(0, 0, 0), rot=(0, 0, 0), verts=10, d2=None):
    if d2 is not None:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=d / 2, radius2=d2 / 2, depth=depth)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=d / 2, depth=depth)
    return _finish(bpy.context.active_object, color, loc, rot)

def cone(depth, d, color, loc=(0, 0, 0), rot=(0, 0, 0), verts=8):
    return cyl(depth, d, color, loc, rot, verts, d2=0.0)

def wedge(size, color, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Roblox-style wedge: tall at +Y (back), thin edge at -Y (front)."""
    sx, sy, sz = size
    verts = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, sy / 2, -sz / 2), (-sx / 2, sy / 2, -sz / 2),
             (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
    faces = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    me = bpy.data.meshes.new('wedge')
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new('wedge', me)
    bpy.context.collection.objects.link(o)
    return _finish(o, color, loc, rot)

def jitter(obj, amount=0.08, seed=0):
    """Small vertex noise for a hand-made low-poly look."""
    rnd = random.Random(seed)
    for v in obj.data.vertices:
        v.co += Vector((rnd.uniform(-amount, amount), rnd.uniform(-amount, amount), rnd.uniform(-amount, amount)))
    return obj

def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

WHITE, BLACK = (1, 1, 1), (0.1, 0.1, 0.14)

def finalize(name, origin_to_bottom=True):
    """Join everything in the scene into one object named `name`, origin at the base center."""
    objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    if origin_to_bottom:
        minz = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
        bpy.context.scene.cursor.location = (0, 0, minz)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        obj.location = (0, 0, 0)
    return obj

# ---------------------------------------------------------------- monsters (chibi, matches ModelFactory)
def eyes(head_loc, size, fwd, spacing, height):
    hx, hy, hz = head_loc
    for side in (-1, 1):
        ball(size, WHITE, (hx + side * spacing, hy - fwd, hz + height), sub=1)
        ball(size * 0.55, BLACK, (hx + side * spacing, hy - fwd - size * 0.32, hz + height), sub=1)

def hat(kind, head_loc, head_d, s):
    hx, hy, hz = head_loc
    top = hz + head_d * 0.45
    if kind == 'marine':
        cyl(0.5 * s, 2.2 * s, WHITE, (hx, hy, top))
        cyl(0.25 * s, 2.26 * s, rgb(40, 90, 200), (hx, hy, top - 0.2 * s))
    elif kind == 'bandana':
        ball(2.1 * s, rgb(220, 60, 60), (hx, hy, top - 0.3 * s), scale=(1, 1, 0.52))
    elif kind == 'clown':
        ball(0.7 * s, rgb(255, 40, 40), (hx, hy - head_d * 0.5, hz))
    elif kind == 'cat':
        for side in (-1, 1):
            cone(0.9 * s, 0.7 * s, rgb(40, 35, 45), (hx + side * 0.6 * s, hy, top + 0.2 * s), verts=4)
    elif kind == 'helmet':
        ball(2.3 * s, rgb(150, 150, 160), (hx, hy, top - 0.35 * s), scale=(1, 1, 0.7))

def build_monster(mid, d):
    s, c, shape = d['scale'], d['color'], d['shape']
    if shape == 'crab':
        body = ball(3.2 * s, c, (0, 0, 1.2 * s), scale=(1, 0.8, 0.56))
        jitter(body, 0.05 * s, 1)
        for side in (-1, 1):
            ball(1.3 * s, lerp(c, WHITE, 0.15), (side * 1.9 * s, -1.2 * s, 1.6 * s))
            cone(0.8 * s, 0.6 * s, lerp(c, WHITE, 0.15), (side * 2.2 * s, -1.9 * s, 1.7 * s), rot=(math.radians(90), 0, 0), verts=5)
            for i in (-1, 0, 1):
                box((1.2 * s, 0.25 * s, 0.25 * s), c, (side * 1.6 * s, i * 0.6 * s, 0.5 * s), rot=(0, side * 0.5, 0))
        eyes((0, 0, 1.2 * s), 0.6 * s, 1.1 * s, 0.5 * s, 0.9 * s)
    elif shape == 'seaking':
        for i in range(6):
            k = 1 - i * 0.12
            ball(3.6 * s * k, lerp(c, BLACK, i * 0.05), (0, i * 2.4 * s, (2 - i * 0.55) * s), sub=1)
        ball(2.6 * s, rgb(250, 230, 180), (0, -0.9 * s, 1.6 * s))
        for side in (-1, 1):
            cone(2.4 * s, 1.6 * s, rgb(255, 120, 80), (side * 1.9 * s, 0.4 * s, 3.4 * s), rot=(0, side * 0.5, 0), verts=3)
        eyes((0, 0, 2 * s), 1.0 * s, 1.8 * s, 0.9 * s, 0.9 * s)
    elif shape == 'snail':
        box((2.2 * s, 4.4 * s, 1.2 * s), rgb(255, 220, 170), (0, 0, 0.6 * s), bevel=0.2 * s)
        ball(3 * s, c, (0, 0.7 * s, 2.3 * s), sub=2)
        ball(1.4 * s, lerp(c, WHITE, 0.35), (1.05 * s, 0.7 * s, 2.3 * s))
        ball(1.6 * s, rgb(255, 220, 170), (0, -1.9 * s, 1.6 * s))
        box((1.8 * s, 0.5 * s, 0.4 * s), rgb(40, 40, 40), (0, 0.7 * s, 4 * s), bevel=0.1 * s)
        eyes((0, -1.9 * s, 1.6 * s), 0.4 * s, 0.7 * s, 0.35 * s, 0.6 * s)
    elif shape in ('boar', 'wolf', 'lion', 'cat'):
        ball(3.6 * s, c, (0, 0, 1.8 * s), scale=(0.72, 1, 0.62))
        head = (0, -1.9 * s, 2.5 * s)
        ball(2.2 * s, lerp(c, WHITE, 0.08), head)
        for sx in (-1, 1):
            for sy in (-1, 1):
                box((0.6 * s, 0.6 * s, 1.2 * s), lerp(c, BLACK, 0.2), (sx * 0.8 * s, sy * 1.1 * s, 0.6 * s), bevel=0.08 * s)
        if shape == 'boar':
            for sx in (-1, 1):
                cone(0.7 * s, 0.25 * s, (1, 1, 0.95), (head[0] + sx * 0.5 * s, head[1] - 1 * s, head[2] - 0.1 * s), rot=(math.radians(-60), 0, 0), verts=5)
            cyl(0.4 * s, 0.9 * s, lerp(c, (1, 0.7, 0.7), 0.4), (head[0], head[1] - 1.05 * s, head[2] - 0.2 * s), rot=(math.radians(90), 0, 0), verts=8)
        elif shape == 'lion':
            ball(3.2 * s, rgb(180, 90, 40), (head[0], head[1] + 0.5 * s, head[2]), scale=(1, 0.5, 0.95))
        else:
            for sx in (-1, 1):
                cone(0.9 * s, 0.6 * s, c, (head[0] + sx * 0.6 * s, head[1], head[2] + 1.1 * s), verts=4)
        cone(1.6 * s, 0.5 * s, c, (0, 1.9 * s, 2.2 * s), rot=(math.radians(-110), 0, 0), verts=5)
        eyes(head, 0.55 * s, 0.95 * s, 0.45 * s, 0.25 * s)
    else:  # humanoid / monkey / fishman: big head, small body
        skin = c if shape == 'fishman' else rgb(255, 215, 180)
        if shape == 'monkey':
            skin = lerp(c, (1, 0.9, 0.8), 0.4)
        box((2 * s, 1.3 * s, 2 * s), c, (0, 0, 2.3 * s), bevel=0.15 * s)
        head = (0, 0, 4.5 * s)
        jitter(ball(2.4 * s, skin, head, sub=2), 0.04 * s, 3)
        for sx in (-1, 1):
            box((0.6 * s, 0.6 * s, 1.6 * s), skin, (sx * 1.35 * s, 0, 2.3 * s), bevel=0.1 * s)
            box((0.75 * s, 0.75 * s, 1.1 * s), lerp(c, BLACK, 0.35), (sx * 0.5 * s, 0, 0.55 * s), bevel=0.1 * s)
        box((2.1 * s, 1.4 * s, 0.35 * s), lerp(c, BLACK, 0.45), (0, 0, 1.55 * s))
        if shape == 'fishman':
            cone(1.4 * s, 1.4 * s, lerp(c, BLACK, 0.25), (0, 0.3 * s, 5.7 * s), rot=(math.radians(-35), 0, 0), verts=3)
            if d['boss']:
                cone(2.2 * s, 0.35 * s, (0.9, 0.9, 0.9), (0, -1.8 * s, 4.5 * s), rot=(math.radians(90), 0, 0), verts=5)
        elif shape == 'monkey':
            cone(1.8 * s, 0.3 * s, c, (0, 1.2 * s, 1.5 * s), rot=(math.radians(-50), 0, 0), verts=5)
        eyes(head, 0.55 * s, 1.05 * s, 0.45 * s, 0.15 * s)
        hat(d['hat'], head, 2.4 * s, s)
    return finalize(mid)

# ---------------------------------------------------------------- ship parts (grid sized, bow toward -Y)
WOOD_DARK = rgb(120, 70, 35)

def planks(size, color):
    """A plank block with recessed seams and a darker trim."""
    sx, sy, sz = size
    box((sx, sy, sz), color, (0, 0, sz / 2), bevel=0.12)
    n = max(2, int(sy / 1.0))
    for i in range(1, n):
        box((sx + 0.04, 0.08, sz + 0.04), lerp(color, BLACK, 0.3), (0, -sy / 2 + i * sy / n, sz / 2))
    box((sx + 0.06, sy + 0.06, 0.25), lerp(color, BLACK, 0.25), (0, 0, sz - 0.12))

def build_ship_part(pid, d):
    cx, cy, cz = d['size']
    sx, sy, sz = cx * GRID, cz * GRID, cy * GRID  # Roblox Z (depth) -> Blender Y, Roblox Y (up) -> Blender Z
    c = d['color']
    if pid in ('PlankBlock', 'OakBlock', 'TreasureBlock'):
        planks((sx, sy, sz), c)
    elif pid == 'IronPlate':
        box((sx, sy, sz), c, (0, 0, sz / 2), bevel=0.15)
        for x in (-1, 1):
            for y in (-1, 1):
                ball(0.45, lerp(c, WHITE, 0.3), (x * sx * 0.35, y * sy * 0.35, sz + 0.05))
    elif pid == 'PlankSlab':
        planks((sx, sy, GRID * 0.35), c)
    elif pid == 'PlankWedge':
        wedge((sx, sy, sz), c, (0, 0, sz / 2), rot=(0, math.pi, 0))
    elif pid == 'Helm':
        box((sx, sy, GRID * 0.25), c, (0, 0, GRID * 0.125), bevel=0.1)
        box((0.6, 0.6, GRID * 0.7), c, (0, -GRID * 0.35, GRID * 0.5))
        wheel = (0, -GRID * 0.42, GRID * 0.8)
        cyl(0.3, GRID * 0.8, WOOD_DARK, wheel, rot=(math.radians(90), 0, 0), verts=12)
        cyl(0.35, GRID * 0.55, (0, 0, 0), wheel, rot=(math.radians(90), 0, 0), verts=12)  # hollow look
        for i in range(8):
            a = i * math.pi / 4
            box((0.18, 0.18, GRID * 1.05), rgb(230, 190, 120), wheel, rot=(0, a, 0))
    elif d['category'] == 'Sail' and pid != 'OarBench':
        h = sz
        cyl(h, 0.9, WOOD_DARK, (0, 0, h / 2), verts=8)
        cyl(GRID * 2.8, 0.4, WOOD_DARK, (0, 0, h * 0.86), rot=(0, math.radians(90), 0), verts=6)
        cyl(GRID * 2.4, 0.4, WOOD_DARK, (0, 0, h * 0.32), rot=(0, math.radians(90), 0), verts=6)
        # billowing sail: a subdivided plane bent forward
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=6, y_subdivisions=6, size=1)
        sail = bpy.context.active_object
        sail.scale = (GRID * 2.6, h * 0.55, 1)
        bpy.ops.object.transform_apply(scale=True)
        for v in sail.data.vertices:
            x, y = v.co.x / (GRID * 1.3), v.co.y / (h * 0.275)
            v.co.z = -(1 - x * x) * (1 - 0.3 * y * y) * GRID * 0.45
        sail.rotation_euler = (math.radians(90), 0, 0)
        sail.location = (0, -0.4, h * 0.59)
        m = sail.modifiers.new('solid', 'SOLIDIFY')
        m.thickness = 0.15
        bpy.context.view_layer.objects.active = sail
        bpy.ops.object.modifier_apply(modifier=m.name)
        _finish(sail, c, sail.location, sail.rotation_euler)
        cyl(0.8, 2.2, rgb(150, 100, 60), (0, 0, h - 0.4), verts=8)
        if d['faction'] == 'Pirate':
            ball(1.6, WHITE, (0, -1.5, h * 0.62))
            for side in (-1, 1):
                box((1.8, 0.2, 0.35), WHITE, (0, -1.4, h * 0.5), rot=(0, side * 0.6, 0))
        elif d['faction'] == 'Marine':
            box((2.4, 0.2, 0.5), rgb(40, 90, 200), (0, -1.45, h * 0.62))
    elif pid == 'OarBench':
        box((sx, sy * 0.5, GRID * 0.3), c, (0, 0, GRID * 0.3), bevel=0.06)
        for side in (-1, 1):
            cyl(GRID * 1.6, 0.25, rgb(200, 150, 90), (side * GRID * 0.9, 0, GRID * 0.2), rot=(0, math.radians(90) + side * 0.35, 0), verts=6)
            box((0.15, 0.7, 0.9), rgb(200, 150, 90), (side * GRID * 1.65, 0, -0.1), rot=(0, side * 0.35, 0))
    elif pid in ('LightCannon', 'HeavyCannon'):
        heavy = pid == 'HeavyCannon'
        box((GRID * 0.8, GRID * 0.8, GRID * 0.35), rgb(120, 80, 45), (0, 0, GRID * 0.175), bevel=0.08)
        L = GRID * (1.25 if heavy else 1.05)
        D = GRID * (0.5 if heavy else 0.4)
        cyl(L, D, c, (0, -GRID * 0.15, GRID * 0.5), rot=(math.radians(85), 0, 0), verts=10)
        cyl(0.3, D * 1.25, lerp(c, WHITE, 0.15), (0, -GRID * 0.15 - L / 2, GRID * 0.5 + 0.05), rot=(math.radians(85), 0, 0), verts=10)
        ball(D * 0.9, c, (0, -GRID * 0.15 + L / 2, GRID * 0.48))
        for side in (-1, 1):
            cyl(0.3, GRID * 0.4, rgb(70, 45, 25), (side * GRID * 0.42, 0, GRID * 0.2), rot=(0, math.radians(90), 0), verts=8)
    elif pid == 'CrewCabin':
        box((sx, sy, sz * 0.7), c, (0, 0, sz * 0.35), bevel=0.1)
        for side in (-1, 1):
            wedge((sx + 0.6, sy / 2 + 0.3, sz * 0.32), rgb(200, 70, 60), (0, side * sy / 4, sz * 0.86), rot=(0, 0, math.pi if side > 0 else 0))
        box((GRID * 0.6, 0.2, GRID * 0.9), rgb(90, 55, 30), (0, -sy / 2 - 0.05, GRID * 0.45))
        box((GRID * 0.5, 0.2, GRID * 0.4), rgb(255, 230, 150), (sx * 0.25, -sy / 2 - 0.05, sz * 0.45))
    elif pid in ('RamHead', 'LionHead'):
        box((GRID * 0.6, GRID * 0.6, GRID * 0.6), rgb(196, 140, 88), (0, 0, GRID * 0.3))
        head = (0, -GRID * 0.2, GRID * 0.75)
        jitter(ball(GRID * 1.1, c, head, sub=2), 0.06, 5)
        if pid == 'RamHead':
            for side in (-1, 1):
                bpy.ops.mesh.primitive_torus_add(major_radius=GRID * 0.28, minor_radius=GRID * 0.1, major_segments=10, minor_segments=5)
                _finish(bpy.context.active_object, rgb(240, 200, 120), (side * GRID * 0.5, -GRID * 0.1, GRID * 0.95), (0, math.radians(90), 0))
        else:
            cyl(GRID * 0.35, GRID * 1.7, rgb(230, 120, 40), (0, 0, GRID * 0.75), rot=(math.radians(90), 0, 0), verts=12)
        eyes(head, GRID * 0.18, GRID * 0.48, GRID * 0.2, GRID * 0.12)
    elif pid == 'Lantern':
        cyl(GRID * 0.5, GRID * 0.3, c, (0, 0, GRID * 0.3), verts=6)
        cone(GRID * 0.2, GRID * 0.38, rgb(50, 50, 55), (0, 0, GRID * 0.6), verts=6)
    else:
        box((sx, sy, sz), c, (0, 0, sz / 2))
    return finalize(pid)

# ---------------------------------------------------------------- island props
def prop_palm():
    lean = 0.25
    for i in range(6):
        cyl(3.4, 1.7 - i * 0.14, lerp(rgb(170, 120, 70), rgb(120, 80, 40), (i % 2) * 0.45), (lean * i * 1.6, 0, 1.7 + i * 3.2), rot=(0, lean * 0.35, 0), verts=7)
    top = (lean * 6 * 1.6, 0, 20)
    for i in range(7):
        a = i / 7 * math.pi * 2
        leaf = wedge((2.4, 9, 0.4), rgb(70, 180, 80) if i % 2 else rgb(110, 210, 90), (top[0] + math.cos(a) * 4, top[1] + math.sin(a) * 4, top[2] - 1), rot=(math.radians(-25), 0, a + math.pi / 2))
    for i in range(3):
        ball(1.4, rgb(120, 80, 40), (top[0] + math.cos(i * 2) * 0.9, math.sin(i * 2) * 0.9, top[2] - 1.2))

def prop_round_tree(fruit=None):
    cyl(7, 1.6, rgb(140, 94, 56), (0, 0, 3.5), verts=7)
    jitter(ball(9, rgb(80, 190, 80), (0, 0, 9), sub=1), 0.4, 7)
    jitter(ball(6.5, rgb(110, 210, 90), (2, 1, 11.4), sub=1), 0.3, 8)
    jitter(ball(5.5, rgb(60, 160, 70), (-2.4, -1.5, 9.8), sub=1), 0.3, 9)
    if fruit:
        for i in range(9):
            a = i * 2.4
            ball(1.1, fruit, (math.cos(a) * 4.2, math.sin(a) * 4.2, 9 + math.sin(i * 1.7) * 2.5))

def prop_pine():
    cyl(5, 1.4, rgb(140, 94, 56), (0, 0, 2.5), verts=6)
    for i in range(4):
        cone(4.5, 9 - i * 2, lerp(rgb(46, 140, 82), rgb(118, 214, 92), i * 0.08), (0, 0, 6 + i * 2.8), verts=8)

def prop_windmill():
    cyl(22, 11, (0.98, 0.97, 0.95), (0, 0, 11), verts=10, d2=9)
    cone(8, 12, rgb(200, 90, 70), (0, 0, 26), verts=10)
    box((3, 0.4, 5), rgb(110, 70, 42), (0, -5.3, 2.5))
    hub = (0, -6.2, 20)
    ball(2.6, WOOD_DARK, hub)
    for i in range(4):
        a = i * math.pi / 2
        box((14, 0.4, 0.6), WOOD_DARK, (hub[0] + math.cos(a) * 7, hub[1], hub[2] + math.sin(a) * 7), rot=(0, -a, 0))
        box((11, 0.25, 3.2), WHITE if i % 2 else rgb(232, 96, 72), (hub[0] + math.cos(a) * 8 - math.sin(a) * 1.8, hub[1] - 0.2, hub[2] + math.sin(a) * 8 + math.cos(a) * 1.8), rot=(0, -a, 0))

def prop_barrel():
    cyl(2.6, 2.2, rgb(150, 98, 58), (0, 0, 1.3), verts=10)
    for z in (0.5, 2.1):
        cyl(0.25, 2.35, rgb(122, 120, 122), (0, 0, z), verts=10)

def prop_crate():
    box((2.4, 2.4, 2.4), rgb(206, 152, 96), (0, 0, 1.2), bevel=0.1)
    for r in (math.radians(45), math.radians(-45)):
        box((0.3, 0.1, 3.2), rgb(104, 66, 40), (0, -1.22, 1.2), rot=(0, r, 0))

def prop_lamp():
    cyl(8, 0.5, rgb(50, 50, 58), (0, 0, 4), verts=6)
    box((1.4, 1.4, 1.6), rgb(255, 220, 140), (0, 0, 8.6))
    cone(1, 2, rgb(50, 50, 58), (0, 0, 9.8), verts=4)

def prop_rock():
    r = ball(6, rgb(150, 148, 150), (0, 0, 2), sub=1, scale=(1, 0.9, 0.7))
    jitter(r, 0.6, 11)

def prop_house():
    box((16, 12, 1.2), rgb(176, 172, 166), (0, 0, 0.6))
    box((15, 11, 9), rgb(255, 244, 222), (0, 0, 5.7), bevel=0.1)
    for side in (-1, 1):
        wedge((17.5, 6.9, 5), rgb(232, 96, 72), (0, side * 3.1, 12.7), rot=(0, 0, math.pi if side > 0 else 0))
    box((3.2, 0.4, 5.6), rgb(110, 70, 42), (0, -5.6, 4))
    for x in (-4.5, 4.5):
        box((2.8, 0.25, 3.2), rgb(104, 66, 40), (x, -5.55, 6.2))
        box((2.2, 0.3, 2.6), rgb(170, 222, 255), (x, -5.6, 6.2))
    box((1.8, 1.8, 6), rgb(176, 92, 70), (4.5, 2.6, 13))

def prop_mesa():
    """A layer-cake cliff tier like the islands use (rock body, strata, grass cap, rim)."""
    jitter(cyl(12, 40, rgb(184, 104, 84), (0, 0, 6), verts=14), 0.5, 13)
    cyl(5, 41.6, rgb(140, 80, 64), (0, 0, 2.5), verts=14)
    cyl(2.2, 43, rgb(124, 214, 92), (0, 0, 12.1), verts=14)
    cyl(0.9, 43.6, rgb(232, 96, 72), (0, 0, 11), verts=14)
    for i in range(18):
        a = i / 18 * math.pi * 2
        ball(random.Random(i).uniform(4.5, 7), rgb(110, 200, 80), (math.cos(a) * 21.8, math.sin(a) * 21.8, 11), sub=1)

PROPS = {
    'PalmTree': prop_palm, 'RoundTree': prop_round_tree, 'TangerineTree': lambda: prop_round_tree(rgb(255, 150, 20)),
    'PineTree': prop_pine, 'Windmill': prop_windmill, 'Barrel': prop_barrel, 'Crate': prop_crate, 'Lamp': prop_lamp,
    'Rock': prop_rock, 'Cottage': prop_house, 'Mesa': prop_mesa,
}

# ---------------------------------------------------------------- export / preview
def export_fbx(obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS',
                             axis_forward='-Z', axis_up='Y', path_mode='COPY', embed_textures=True, mesh_smooth_type='FACE',
                             bake_space_transform=True)

def setup_preview():
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.device = 'CPU'
    scn.cycles.samples = 24
    scn.render.resolution_x = scn.render.resolution_y = 384
    scn.render.film_transparent = False
    world = bpy.data.worlds.get('GV') or bpy.data.worlds.new('GV')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.55, 0.78, 0.95, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
    scn.world = world

def render_preview(obj, path):
    dims = obj.dimensions
    size = max(dims) or 1
    center = Vector((0, 0, dims.z / 2))
    cam_data = bpy.data.cameras.new('cam')
    cam = bpy.data.objects.new('cam', cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = center + Vector((size * 1.3, -size * 1.6, size * 1.0))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    sun_data = bpy.data.lights.new('sun', 'SUN')
    sun_data.energy = 3.5
    sun = bpy.data.objects.new('sun', sun_data)
    sun.rotation_euler = Euler((math.radians(50), math.radians(10), math.radians(30)))
    bpy.context.collection.objects.link(sun)
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (cam, sun):
        bpy.data.objects.remove(o, do_unlink=True)

# ---------------------------------------------------------------- main
def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(ROOT, 'assets', 'models'))
    ap.add_argument('--only', default='')
    ap.add_argument('--preview', action='store_true')
    ap.add_argument('--blend', action='store_true')
    a = ap.parse_args(argv)
    only = set(filter(None, a.only.split(',')))
    jobs = []
    for mid, d in parse_monsters().items():
        jobs.append(('monsters', mid, lambda mid=mid, d=d: build_monster(mid, d)))
    for pid, d in parse_ship_parts().items():
        jobs.append(('ships', pid, lambda pid=pid, d=d: build_ship_part(pid, d)))
    for name, fn in PROPS.items():
        jobs.append(('props', name, lambda name=name, fn=fn: (fn(), finalize(name))[1]))
    all_jobs = list(jobs)
    if only:
        jobs = [j for j in jobs if j[0] in only or j[1] in only]
    if a.preview:
        setup_preview()
    tex_dir = os.path.join(a.out, 'textures')
    os.makedirs(tex_dir, exist_ok=True)
    # pass 1: register every color (of ALL assets, so the shared palette never changes with --only)
    for cat, name, fn in all_jobs:
        clear_scene()
        fn()
    img = build_palette_image(os.path.join(tex_dir, 'gv_palette.png'))
    palette_material().node_tree.nodes['Palette'].image = img
    done = 0
    for cat, name, fn in jobs:
        clear_scene()
        obj = fn()
        folder = os.path.join(a.out, cat)
        os.makedirs(folder, exist_ok=True)
        export_fbx(obj, os.path.join(folder, name + '.fbx'))
        if a.preview:
            os.makedirs(os.path.join(a.out, 'previews'), exist_ok=True)
            render_preview(obj, os.path.join(a.out, 'previews', name + '.png'))
        done += 1
        print(f'[GV] {cat:9} {name:20} tris={sum(len(p.vertices) - 2 for p in obj.data.polygons)}')
    print(f'[GV] exported {done} assets to {os.path.abspath(a.out)} (palette: {len(_palette)} colors)')

if __name__ == '__main__':
    main()
