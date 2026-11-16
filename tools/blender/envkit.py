"""Stylized 3D environment kit (trees, pines, palms, bushes, boulders, cliff modules) with baked hand-painted shading.

  python tools/blender/envkit.py -- --out assets/models3d --preview [--only BroadTree_1]
Outputs Env_<Kind>_<n>.glb (+ preview). Upload with tools/upload_models.py; the server (EnvService) swaps the baked
world's placeholder props (tagged "EnvProp" by World/Kit.lua) for these meshes.

Look (from the owner's references): chunky foliage clumps with scalloped leafy edges and 3-tone painted light,
twisting trunks with bark grooves, faceted block cliffs and boulders with light tops and dark crevices.
"""
import math, os, random, sys
import bpy
import bmesh
from mathutils import Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gvkit as K
import creatures as CR
from creatures import assign, smooth, skin_body, tuft, lin3

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv
R = math.radians


# ---------------------------------------------------------------- materials (emission, baked by CR.finalize)
def _nodes(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    return m, nt, em


def _mix(nt, a, b, blend="MULTIPLY", fac=1.0):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = blend
    mx.inputs["Factor"].default_value = fac
    if isinstance(a, tuple):
        mx.inputs[6].default_value = a
    else:
        nt.links.new(a, mx.inputs[6])
    if isinstance(b, tuple):
        mx.inputs[7].default_value = b
    else:
        nt.links.new(b, mx.inputs[7])
    return mx.outputs[2]


def _ao(nt, dist, dark):
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = dist
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = (dark, dark * 0.95, dark * 1.05, 1)
    r.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(ao.outputs["AO"], r.inputs[0])
    return r.outputs[0]


def _ramp(nt, value_socket, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, col) in zip(els, stops):
        el.position = pos
        el.color = lin3(col)
    nt.links.new(value_socket, r.inputs[0])
    return r.outputs[0]


def _normal_z(nt):
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1
    mr.inputs["From Max"].default_value = 1
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    return mr.outputs[0]


def _noise(nt, scale, detail=4):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    return n.outputs["Fac"]


def foliage_mat(name, dark, mid, light, tip):
    """3-tone painted foliage: light from above (normal Z), mottled clumps, sunny tips, AO under the clumps"""
    m, nt, em = _nodes(name)
    nz = _normal_z(nt)
    # mottle the light threshold so the shading looks painted, not smooth
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    mot = _noise(nt, 2.2, 3)
    mm = nt.nodes.new("ShaderNodeMath")
    mm.operation = "MULTIPLY"
    nt.links.new(mot, mm.inputs[0])
    mm.inputs[1].default_value = 0.35
    nt.links.new(nz, add.inputs[0])
    nt.links.new(mm.outputs[0], add.inputs[1])
    col = _ramp(nt, add.outputs[0], [(0.32, dark), (0.58, mid), (0.82, light), (1.0, tip)])
    col = _mix(nt, col, _ao(nt, 1.2, 0.35))
    nt.links.new(col, em.inputs["Color"])
    return m


def bark_mat(name, base, dark):
    """vertical bark grooves (stretched noise) + AO"""
    m, nt, em = _nodes(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (9, 9, 1.2)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 2.5
    n.inputs["Detail"].default_value = 6
    nt.links.new(mp.outputs[0], n.inputs["Vector"])
    col = _ramp(nt, n.outputs["Fac"], [(0.38, dark), (0.62, base)])
    col = _mix(nt, col, _ramp(nt, _normal_z(nt), [(0.3, "#b8a8a0"), (0.9, "#ffffff")]))
    col = _mix(nt, col, _ao(nt, 0.8, 0.4))
    nt.links.new(col, em.inputs["Color"])
    return m


def stone_mat(name, dark, mid, light, moss=None):
    """faceted painted stone: top faces light (optionally mossy), sides mid, undersides + crevices dark"""
    m, nt, em = _nodes(name)
    nz = _normal_z(nt)
    stops = [(0.25, dark), (0.5, mid), (0.78, light)]
    if moss:
        stops.append((0.93, moss))
    col = _ramp(nt, nz, stops)
    col = _mix(nt, col, _ramp(nt, _noise(nt, 2.0, 5), [(0.3, "#b0a8a4"), (0.7, "#ffffff")]))
    col = _mix(nt, col, _ao(nt, 0.6, 0.3))
    nt.links.new(col, em.inputs["Color"])
    return m


# ---------------------------------------------------------------- geometry helpers
def clump(center, r, mat, seed, squash=0.8, leafy=0.22):
    """a foliage clump: lumpy ico sphere whose silhouette is scalloped like leaf bunches"""
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=3, location=center)
    o = bpy.context.object
    o.scale = (1, 1, squash)
    bpy.ops.object.transform_apply(scale=True)
    me = o.data
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in me.vertices:
        p = (v.co - Vector(center)) / r
        lump = noise.noise(p * 1.4 + off) * 0.2
        bunch = (abs(noise.noise(p * 3.2 + off * 2)) ** 0.7) * leafy  # rounded leaf bunches
        v.co = Vector(center) + p * r * (1 + lump + bunch - leafy * 0.4)
    return smooth(assign(o, mat))


def facet_rock(center, size, mat, seed, subdiv=1, jitter=0.22, flat=True):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=1, subdivisions=subdiv, location=(0, 0, 0))
    o = bpy.context.object
    rng = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1 + rng.uniform(-jitter, jitter)
    o.scale = size
    o.location = center
    o.rotation_euler = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(0, 6.28))
    bpy.ops.object.transform_apply(scale=True, location=True, rotation=True)
    for p in o.data.polygons:
        p.use_smooth = not flat
    return assign(o, mat)


def block(center, size, mat, rot, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("bev", "BEVEL")
        b.width = bevel
        b.segments = 1
        K.apply_mods(o)
    for p in o.data.polygons:
        p.use_smooth = False
    return assign(o, mat)


# ---------------------------------------------------------------- props (all stand on z=0, face -Y)
def broad_tree(variant):
    rng = random.Random(10 + variant)
    bark = bark_mat("bark", "#8a5a3a", "#3e2414")
    leaf = foliage_mat("leaf", "#163d2c", "#2f7a3a", "#6aae42", "#b8d860")
    lean = rng.uniform(-0.6, 0.6)
    # twisting trunk that forks into 3 branches
    V = [(0, 0, 0), (0.15, 0.05, 1.6), (lean * 0.6, 0.1, 3.4), (lean, 0, 4.6)]
    E = [(0, 1), (1, 2), (2, 3)]
    Rd = [(0.75, 0.75), (0.5, 0.5), (0.42, 0.42), (0.36, 0.36)]
    ends = []
    for k in range(3):
        a = k / 3 * math.tau + rng.uniform(-0.4, 0.4)
        reach = rng.uniform(1.6, 2.4)
        mid = (lean + math.cos(a) * reach * 0.5, math.sin(a) * reach * 0.5, 5.6 + rng.uniform(-0.3, 0.3))
        tip = (lean + math.cos(a) * reach, math.sin(a) * reach, 6.6 + rng.uniform(-0.4, 0.6))
        i = len(V)
        V += [mid, tip]
        E += [(3, i), (i, i + 1)]
        Rd += [(0.26, 0.26), (0.14, 0.14)]
        ends.append(tip)
    # roots flaring at the base
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        i = len(V)
        V.append((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.05))
        E.append((0, i))
        Rd.append((0.22, 0.22))
    trunk = skin_body(V, E, Rd, "trunk", subdiv=1, lumps=0.04)
    assign(trunk, bark)
    # foliage: a big crown made of clumps around each branch tip + a top clump
    sd = 0
    for tip in ends:
        for k in range(3):
            sd += 1
            c = Vector(tip) + Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(-0.2, 0.9)))
            clump(c, rng.uniform(1.3, 1.9), leaf, sd + variant * 20)
    sd += 1
    clump((lean, 0, 7.8), 1.9, leaf, sd + variant * 20)
    clump((lean * 0.5, 0, 6.2), 2.2, leaf, sd + 1 + variant * 20)


def pine(variant):
    rng = random.Random(30 + variant)
    bark = bark_mat("bark", "#7a4a30", "#3a2012")
    nd = foliage_mat("needles", "#0e2e24", "#1d5a3c", "#3f8a4a", "#7ab45a")
    skin_body([(0, 0, 0), (0, 0, 3), (0, 0, 9.5)], [(0, 1), (1, 2)], [(0.45, 0.45), (0.3, 0.3), (0.08, 0.08)], "trunk", subdiv=1, lumps=0.02)
    bpy.context.object.data.materials.clear()
    assign(bpy.context.object, bark)
    tiers = 5
    for t in range(tiers):
        k = t / (tiers - 1)
        z = 2.2 + t * 1.55
        r = 2.6 * (1 - k) + 0.7
        h = 2.4 - k * 0.6
        bm = bmesh.new()
        n = 14
        top = bm.verts.new((0, 0, z + h))
        ring = []
        for i in range(n):
            a = i / n * math.tau + t * 0.3
            rr = r * (1.0 if i % 2 == 0 else 0.72)
            droop = (0.45 if i % 2 == 0 else 0.1) * (1 + rng.uniform(-0.2, 0.2))
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z - droop)))
        inner = [bm.verts.new((math.cos(i / n * math.tau + t * 0.3) * r * 0.45, math.sin(i / n * math.tau + t * 0.3) * r * 0.45, z + 0.15)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((ring[i], ring[j], top))
            bm.faces.new((inner[j], ring[j], ring[i], inner[i]))
        me = bpy.data.meshes.new("tier")
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("tier", me)
        bpy.context.scene.collection.objects.link(o)
        assign(o, nd)
        for p in o.data.polygons:
            p.use_smooth = False


def frond(p0, p1, p2, width, mat, segs=10):
    """a palm leaf: a strip along a bezier with serrated leaflet edges, folded slightly in a V, double-sided"""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    bm = bmesh.new()
    pts = []
    for i in range(segs + 1):
        t = i / segs
        c = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        tan = (2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)).normalized()
        side = tan.cross(Vector((0, 0, 1))).normalized()
        w = width * math.sin(math.pi * min(1, t * 1.15)) ** 0.7 * (1.0 if i % 2 == 0 else 0.62)
        fold = Vector((0, 0, 0.18 * w))
        pts.append((c + side * w - fold, c + fold * 0.5, c - side * w - fold))
    # two layers (front + back faces on separate verts): Roblox culls back faces, so a single sheet would vanish from below
    for layer, dz in ((0, 0.0), (1, -0.03)):
        rows = [tuple(bm.verts.new(p + Vector((0, 0, dz))) for p in row) for row in pts]
        for i in range(segs):
            a0, b0, c0 = rows[i]
            a1, b1, c1 = rows[i + 1]
            for quad in ((a0, a1, b1, b0), (b0, b1, c1, c0)):
                bm.faces.new(quad if layer == 0 else tuple(reversed(quad)))
    me = bpy.data.meshes.new("frond")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("frond", me)
    bpy.context.scene.collection.objects.link(o)
    return assign(o, mat)


def palm(variant):
    rng = random.Random(50 + variant)
    bark = bark_mat("bark", "#9a7048", "#4a301c")
    leaf = foliage_mat("frond", "#1c5030", "#3a8a3e", "#78bc4a", "#bcdc66")
    bend = rng.uniform(1.4, 2.2) * (1 if variant % 2 else -1)
    pts = [(bend * (t / 8) ** 1.8, 0, t / 8 * 10) for t in range(9)]
    skin_body(pts, [(i, i + 1) for i in range(8)], [(0.62 - i * 0.04, 0.62 - i * 0.04) for i in range(9)], "trunk", subdiv=1, lumps=0.0)
    assign(bpy.context.object, bark)
    # ring bands
    for i in range(1, 8):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        tuft(a, a.lerp(b, 0.15), a.lerp(b, 0.3), 0.7 - i * 0.04, bark, n=10, rings=1, flat=1.0)
    top = Vector(pts[-1])
    for k in range(9):
        a = k / 9 * math.tau + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        L = rng.uniform(4.6, 5.8)
        frond(top, top + d * L * 0.45 + Vector((0, 0, 1.3)), top + d * L + Vector((0, 0, -1.8)), rng.uniform(0.75, 0.95), leaf)
    coco = CR.flat_mat("coco", "#5a3a1e")
    for k in range(3):
        a = k * 2.1
        CR.blob(0.36, top + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, -0.55)), coco)


def bush(variant):
    rng = random.Random(70 + variant)
    leaf = foliage_mat("leaf", "#163d2c", "#2f7a3a", "#6aae42", "#b8d860")
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        r = rng.uniform(0.7, 1.1)
        clump((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.7 + rng.uniform(0, 0.4)), r, leaf, k + variant * 9, squash=0.75, leafy=0.26)
    clump((0, 0, 1.3), 1.15, leaf, 50 + variant, squash=0.8)


def boulder(variant):
    mat = stone_mat("stone", "#3a363e", "#6c6670", "#a8a09c", "#6f9a4a" if variant != 3 else None)
    rng = random.Random(90 + variant)
    facet_rock((0, 0, 0.8), (1.7, 1.35, 1.05), mat, variant * 7 + 1, subdiv=2, jitter=0.12)
    for k in range(2 + variant % 2):
        a = rng.uniform(0, 6.28)
        facet_rock((math.cos(a) * 1.6, math.sin(a) * 1.6, 0.35), (0.65, 0.55, 0.45), mat, variant * 7 + 2 + k, subdiv=1, jitter=0.2)


def cliff(variant):
    """a cliff wall module: irregular columns of chunky faceted slabs, mossy tops, rubble at the foot"""
    mat = stone_mat("cliff", "#3c3438", "#76686a", "#b4a69c", "#7aa850")
    rng = random.Random(110 + variant)
    x = -5.0
    while x < 5.0:
        w = rng.uniform(1.6, 3.4)
        z = 0.0
        top = rng.uniform(8.0, 10.5)
        while z < top:
            h = rng.uniform(1.4, 4.2)
            h = min(h, top - z + 0.6)
            d = rng.uniform(2.4, 4.0)
            facet = (rng.uniform(-0.12, 0.12), rng.uniform(-0.15, 0.15), rng.uniform(-0.2, 0.2))
            block((x + w / 2 + rng.uniform(-0.2, 0.2), rng.uniform(-0.7, 0.5), z + h / 2), (w * rng.uniform(0.95, 1.15), d, h), mat, facet, bevel=0.3)
            z += h * rng.uniform(0.85, 0.98)
        x += w * rng.uniform(0.8, 0.95)
    for k in range(4):
        facet_rock((rng.uniform(-4.5, 4.5), -2.4 + rng.uniform(-0.3, 0.3), 0.4), (rng.uniform(0.6, 1.0), 0.7, 0.55), mat, 300 + variant * 5 + k, subdiv=1, jitter=0.25)


PROPS = {}
for i in (1, 2, 3):
    PROPS[f"BroadTree_{i}"] = (broad_tree, i, 14)
for i in (1, 2):
    PROPS[f"Pine_{i}"] = (pine, i, 14)
    PROPS[f"Palm_{i}"] = (palm, i, 14)
    PROPS[f"Bush_{i}"] = (bush, i, 5)
for i in (1, 2, 3):
    PROPS[f"Boulder_{i}"] = (boulder, i, 5)
    PROPS[f"Cliff_{i}"] = (cliff, i, 12)


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for name, (fn, variant, target) in PROPS.items():
        if ONLY and name not in ONLY:
            continue
        K.reset()
        fn(variant)
        obj = CR.finalize("Env_" + name, target)
        K.export_glb(obj, os.path.join(OUT, "Env_" + name + ".glb"))
        if PREVIEW:
            CR.preview(obj, os.path.join(OUT, "preview", "Env_" + name + ".png"), size=320)
        print("PROP", name)


if __name__ == "__main__":
    main()
