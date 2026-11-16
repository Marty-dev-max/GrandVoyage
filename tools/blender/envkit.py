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


TONES = {
    # dark, mid, light, top-highlight (references: warm brown chunky cliffs, grey village rocks, the red wall)
    "Brown": ("#4a2c1c", "#9a6242", "#cf9566", "#e9be8a"),
    "Gray": ("#45464e", "#868892", "#bdbcb8", "#dedbd2"),
    "Red": ("#561c16", "#a8442c", "#dd7450", "#f0a274"),
}


def chunk(center, size, mat, rng, jitter=0.16):
    """an angular rock chunk: a box with chamfered edges whose corners are pushed around -> crisp painted facets"""
    o = block(center, size, mat, (rng.uniform(-0.08, 0.08), rng.uniform(-0.1, 0.1), rng.uniform(-0.15, 0.15)), bevel=min(size) * 0.12)
    for v in o.data.vertices:
        v.co.x += rng.uniform(-jitter, jitter) * size[0]
        v.co.z += rng.uniform(-jitter, jitter) * size[2] * 0.6
    return o


def cliff(variant, tone="Brown"):
    """a cliff wall module (~10 wide x 10 high): stacked angular chunks in uneven columns, flat top so the grass layer
    sits on it as a separate band, rubble at the foot"""
    d0, m0, l0, t0 = TONES[tone]
    mat = stone_mat("cliff", d0, m0, l0, t0)
    rng = random.Random(110 + variant * 7 + len(tone))
    x = -5.2
    while x < 5.2:
        w = rng.uniform(1.8, 3.6)
        z = 0.0
        top = rng.uniform(9.3, 10.0)
        while z < top - 0.3:
            h = min(rng.uniform(2.0, 4.6), top - z)
            d = rng.uniform(2.6, 4.2)
            chunk((x + w / 2 + rng.uniform(-0.25, 0.25), rng.uniform(-0.9, 0.4), z + h / 2), (w * rng.uniform(0.95, 1.2), d, h), mat, rng)
            z += h * rng.uniform(0.9, 1.0)
        x += w * rng.uniform(0.78, 0.95)
    for k in range(6):
        facet_rock((rng.uniform(-4.8, 4.8), -2.6 + rng.uniform(-0.4, 0.4), 0.35), (rng.uniform(0.5, 1.1), rng.uniform(0.5, 0.8), rng.uniform(0.35, 0.6)), mat, 300 + variant * 11 + k, subdiv=1, jitter=0.25)


def grass_cap(variant):
    """the grass layer on top of a plateau (unit radius, top at z=1): flat painted top, a thick rounded lip that
    overhangs the cliff and drips down unevenly - a clear grass band over the rock"""
    rng = random.Random(700 + variant)
    m, nt, em = _nodes("cap")
    nz = _normal_z(nt)
    col = _ramp(nt, nz, [(0.2, "#2a5a24"), (0.55, "#4f8f36"), (0.85, "#7cbc48"), (1.0, "#a6d65a")])
    col = _mix(nt, col, _ramp(nt, _noise(nt, 9.0, 4), [(0.35, "#cfe0b8"), (0.65, "#ffffff")]))
    col = _mix(nt, col, _ao(nt, 0.08, 0.5))
    nt.links.new(col, em.inputs["Color"])
    seed = Vector((variant * 2.3, 0.7, variant * 1.1))
    n = 96
    bm = bmesh.new()

    def ring(rf, z, drip=0.0, wob=1.0):
        out = []
        for i in range(n):
            a = i / n * math.tau
            d = Vector((math.cos(a), math.sin(a), 0))
            w = noise.noise(d * 1.4 + seed) * 0.07 * wob
            dz = 0.0
            if drip:
                dd = max(0.0, noise.noise(d * 6.0 + seed * 2)) ** 0.8
                dz = -drip * dd
            out.append(bm.verts.new((d.x * rf * (1 + w), d.y * rf * (1 + w), z + dz)))
        return out
    rings = [ring(0.9, 0.42), ring(0.985, 0.25, drip=0.25), ring(1.03, 0.5, drip=0.12), ring(1.035, 0.82), ring(1.0, 0.97), ring(0.94, 1.0)]
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]))
    prev = rings[-1]
    for sc in (0.7, 0.4, 0.15):
        cur = []
        for i in range(n):
            v = prev[i].co
            k = sc / (Vector((v.x, v.y, 0)).length + 1e-6) * Vector((v.x, v.y, 0)).length
            cur.append(bm.verts.new((v.x * sc / 0.94, v.y * sc / 0.94, 1.0 + noise.noise(Vector((v.x * 3, v.y * 3, 0)) + seed) * 0.008)))
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((prev[i], prev[j], cur[j], cur[i]))
        prev = cur
    c = bm.verts.new((0, 0, 1.0))
    for i in range(n):
        bm.faces.new((prev[i], prev[(i + 1) % n], c))
    # close the underside so it is solid from every angle
    under = rings[0]
    cu = bm.verts.new((0, 0, 0.45))
    for i in range(n):
        bm.faces.new((under[(i + 1) % n], under[i], cu))
    me = bpy.data.meshes.new("cap")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("cap", me)
    bpy.context.scene.collection.objects.link(o)
    smooth(assign(o, m))
    # a few grass tufts sticking out of the lip
    for k in range(14):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0))
        base = d * 1.0 + Vector((0, 0, 0.9))
        frond(base, base + d * 0.03 + Vector((0, 0, 0.12)), base + d * 0.06 + Vector((0, 0, 0.2)), 0.015, m, segs=3)


# ---------------------------------------------------------------- ground cover (reference: stylized plant pack)
def blade(base, lean_dir, height, width, mat, curl=0.35, segs=4):
    """a grass blade / leaf strip: tapered, curved, two-sided (thin box-like strip so Roblox never culls it away)"""
    base = Vector(base)
    d = Vector(lean_dir).normalized()
    tip = base + Vector((0, 0, height)) + d * height * curl
    mid = base + Vector((0, 0, height * 0.6)) + d * height * curl * 0.25
    return frond(base, mid, tip, width, mat, segs=segs)


def grass_tuft(variant):
    rng = random.Random(200 + variant)
    g = foliage_mat("grass", "#1e5a2a", "#4a9a36", "#8cc83e", "#d6ec6a") if variant != 2 else foliage_mat("grass", "#3a6a24", "#7aa832", "#b8d24a", "#eef08a")
    for k in range(16):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 0.35)
        base = (math.cos(a) * r, math.sin(a) * r, 0)
        blade(base, (math.cos(a), math.sin(a), 0), rng.uniform(1.2, 2.2), rng.uniform(0.09, 0.14), g, curl=rng.uniform(0.25, 0.55), segs=4)


def fern(variant):
    rng = random.Random(220 + variant)
    g = foliage_mat("fern", "#174a26", "#3a8a34", "#7cc040", "#c8e46a") if variant == 1 else foliage_mat("fern", "#5a3a12", "#a86a22", "#e0a032", "#f6d27a")
    for k in range(8):
        a = k / 8 * math.tau + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        side = d.cross(Vector((0, 0, 1)))
        L = rng.uniform(1.9, 2.6)
        p0, p1, p2 = Vector((0, 0, 0.05)), d * L * 0.35 + Vector((0, 0, 1.9)), d * L + Vector((0, 0, 0.7))
        # thin spine + pairs of narrow leaflets that shrink toward the tip (the feathery fern look)
        tuft(p0, p1, p2, 0.04, g, n=4, rings=4)
        for i in range(1, 13):
            t = i / 13
            c = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
            tan = (2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)).normalized()
            ln = 0.55 * (1 - t) ** 0.6 + 0.08
            for sgn in (-1, 1):
                out = (side * sgn * 0.85 + tan * 0.5).normalized()
                frond(c, c + out * ln * 0.5 + Vector((0, 0, 0.06)), c + out * ln - Vector((0, 0, 0.05)), 0.07, g, segs=3)


def leaf_plant(variant):
    rng = random.Random(240 + variant)
    g = foliage_mat("leaf", "#123d24", "#2a7a3a", "#5aaa46", "#a6d45e") if variant == 1 else foliage_mat("leaf", "#6a2a10", "#c05a1e", "#ee8a32", "#ffc46a")
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.25, 0.25)
        d = Vector((math.cos(a), math.sin(a), 0))
        L = rng.uniform(1.6, 2.4)
        frond((0, 0, 0.05), d * L * 0.3 + Vector((0, 0, 2.0)), d * L * 0.95 + Vector((0, 0, 1.1)), rng.uniform(0.42, 0.55), g, segs=8)


PETALS = {1: ("#fffaf2", "#ffd23a"), 2: ("#ffd23a", "#c8641e"), 3: ("#a07aff", "#ffe27a"), 4: ("#7ac8ff", "#ffffff"), 5: ("#ff7aa8", "#ffe27a")}


def petal(center, ang, length, width, lift, mat):
    """one pointed petal: a two-sided strip from the flower center outward, curving up by `lift`"""
    d = Vector((math.cos(ang), math.sin(ang), 0))
    c = Vector(center)
    return frond(c, c + d * length * 0.5 + Vector((0, 0, length * lift * 0.6)), c + d * length + Vector((0, 0, length * lift)), width, mat, segs=4)


FLOWER_KINDS = {
    1: ("daisy", "#fffaf2", "#ffcf2e"),
    2: ("daisy", "#ffd23a", "#b8541a"),
    3: ("tulip", "#ff4a5e", "#ffd86a"),
    4: ("lupine", "#9a6aff", "#e6d8ff"),
    5: ("star", "#6ab8ff", "#ffffff"),
}


def flowers(variant):
    rng = random.Random(260 + variant)
    kind, pet, mid = FLOWER_KINDS[variant]
    stem_m = foliage_mat("stem", "#1e5a2a", "#3f8e36", "#7cc040", "#a8d860")
    pet_m = CR.flat_mat("petal", pet)
    mid_m = CR.flat_mat("center", mid)
    heads = 4 if kind != "lupine" else 3
    for k in range(heads):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0, 0.6) if k else 0
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        h = rng.uniform(0.6, 1.0) * (1.6 if kind == "lupine" else 1.0)
        top = base + Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), h))
        tuft(base, base.lerp(top, 0.5) + Vector((0.04, 0, 0)), top, 0.035, stem_m, n=5, rings=2)
        rot = rng.uniform(0, math.tau)
        if kind == "daisy":
            for j in range(10):
                petal(top, rot + j / 10 * math.tau, 0.24, 0.05, 0.15, pet_m)
            CR.blob(0.07, top + Vector((0, 0, 0.03)), mid_m, scale=(1, 1, 0.5), seg=8)
        elif kind == "star":
            for j in range(5):
                petal(top, rot + j / 5 * math.tau, 0.2, 0.08, 0.3, pet_m)
            CR.blob(0.045, top + Vector((0, 0, 0.03)), mid_m, scale=(1, 1, 0.6), seg=6)
        elif kind == "tulip":
            # a cup: petals rising steeply around the center
            for j in range(5):
                petal(top - Vector((0, 0, 0.04)), rot + j / 5 * math.tau, 0.13, 0.09, 2.2, pet_m)
            CR.blob(0.05, top + Vector((0, 0, 0.06)), mid_m, scale=(1, 1, 1.4), seg=6)
        else:  # lupine spike: whorls of tiny petals up the top of the stem, shrinking to the tip
            for t in range(9):
                zc = top + Vector((0, 0, -0.45 + t * 0.06))
                sz = 0.13 * (1 - t / 11)
                for j in range(4):
                    petal(zc, rot + j / 4 * math.tau + t * 0.6, sz, 0.05, 0.5, pet_m)
        # leaves at the base of each stem
        for j in (0, 1, 2):
            dd = Vector((math.cos(a + j * 2.1), math.sin(a + j * 2.1), 0))
            frond(base, base + dd * 0.22 + Vector((0, 0, 0.28)), base + dd * 0.5 + Vector((0, 0, 0.1)), 0.11, stem_m, segs=4)


def mushroom(variant):
    rng = random.Random(280 + variant)
    stem_m = CR.flat_mat("stem", "#f2eadc")
    cap_m = CR.flat_mat("cap", "#e8322a" if variant == 1 else "#ff7a22")
    dot_m = CR.flat_mat("dots", "#fffaf0")
    for k in range(2 + variant):
        a = rng.uniform(0, math.tau)
        r = 0 if k == 0 else rng.uniform(0.5, 0.8)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        s = 1.0 if k == 0 else rng.uniform(0.45, 0.7)
        tuft(base, base + Vector((0, 0, 0.5 * s)), base + Vector((0.05, 0, 0.95 * s)), 0.17 * s, stem_m, n=10, rings=3)
        top = base + Vector((0.05, 0, 0.95 * s))
        CR.blob(0.55 * s, top, cap_m, scale=(1, 1, 0.55), seg=16)
        for j in range(7):
            b = j / 7 * math.tau + rng.uniform(-0.2, 0.2)
            el = rng.uniform(0.35, 0.8)
            p = top + Vector((math.cos(b) * math.cos(el) * 0.52 * s, math.sin(b) * math.cos(el) * 0.52 * s, math.sin(el) * 0.3 * s))
            CR.blob(0.07 * s, p, dot_m, scale=(1, 1, 0.5), seg=6)


def grass_mat(name, base, mid, tip):
    """blades: dark at the root -> bright sunny tips (by height), slight per-patch mottling"""
    m, nt, em = _nodes(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    col = _ramp(nt, mr.outputs[0], [(0.0, base), (0.45, mid), (1.0, tip)])
    col = _mix(nt, col, _ramp(nt, _noise(nt, 1.5, 2), [(0.3, "#d8e0c8"), (0.7, "#ffffff")]))
    nt.links.new(col, em.inputs["Color"])
    return m


def grass_patch(variant):
    """a 4 x 4 stud patch of short stylized blades (two-sided thin triangles), placed densely around the player"""
    rng = random.Random(400 + variant)
    g = grass_mat("blades", "#1e4a1e", "#4c9a34", "#b8e05a")
    bm = bmesh.new()
    for k in range(48):
        x, y = rng.uniform(-2, 2), rng.uniform(-2, 2)
        h = rng.uniform(0.45, 1.0)
        w = rng.uniform(0.07, 0.12)
        a = rng.uniform(0, math.tau)
        side = Vector((math.cos(a), math.sin(a), 0))
        lean = Vector((-math.sin(a), math.cos(a), 0)) * rng.uniform(0.1, 0.35) * h
        base = Vector((x, y, 0))
        pts = [base - side * w, base + side * w, base + side * w * 0.55 + lean * 0.4 + Vector((0, 0, h * 0.55)),
               base - side * w * 0.55 + lean * 0.4 + Vector((0, 0, h * 0.55)), base + lean + Vector((0, 0, h))]
        for back in (False, True):
            off = Vector((0, 0, 0)) if not back else (side.cross(Vector((0, 0, 1))) * 0.01)
            vs = [bm.verts.new(p + off) for p in pts]
            faces = [(vs[0], vs[1], vs[2], vs[3]), (vs[3], vs[2], vs[4])]
            for f in faces:
                bm.faces.new(tuple(reversed(f)) if back else f)
    if variant == 2:
        # a few tiny wild flowers in the patch
        for k in range(4):
            c = Vector((rng.uniform(-1.6, 1.6), rng.uniform(-1.6, 1.6), rng.uniform(0.5, 0.8)))
            col = ["#fffaf0", "#ffe04a", "#c9a0ff", "#ff9ac0"][k % 4]
            CR.blob(0.09, c, CR.flat_mat("fl%d" % k, col), scale=(1, 1, 0.5), seg=6)
    me = bpy.data.meshes.new("blades")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("blades", me)
    bpy.context.scene.collection.objects.link(o)
    assign(o, g)
    for p in o.data.polygons:
        p.use_smooth = False


def ledge_mat(name, grass_dark, grass, grass_light, dirt, dirt_dark):
    """grassy ledge: grass on the top and draping unevenly over the rim, painted earth sides with horizontal strokes,
    darker toward the foot, AO in the creases (reference: soft stylized grass ledges)"""
    m, nt, em = _nodes(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    # uneven grass line: height threshold + noise
    edge_n = _noise(nt, 4.0, 3)
    th = nt.nodes.new("ShaderNodeMath")
    th.operation = "MULTIPLY_ADD"
    nt.links.new(edge_n, th.inputs[0])
    th.inputs[1].default_value = 0.16
    th.inputs[2].default_value = 0.78
    gm = nt.nodes.new("ShaderNodeMath")
    gm.operation = "GREATER_THAN"
    nt.links.new(sep.outputs["Z"], gm.inputs[0])
    nt.links.new(th.outputs[0], gm.inputs[1])
    # grass color: light on top (normal Z), mottled
    gcol = _ramp(nt, _normal_z(nt), [(0.5, grass_dark), (0.8, grass), (1.0, grass_light)])
    gcol = _mix(nt, gcol, _ramp(nt, _noise(nt, 6.0, 4), [(0.3, "#d8e6c0"), (0.7, "#ffffff")]))
    # earth: horizontal painterly strokes, darker at the foot
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.0, 2.0, 14.0)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    sn = nt.nodes.new("ShaderNodeTexNoise")
    sn.inputs["Scale"].default_value = 2.0
    sn.inputs["Detail"].default_value = 5
    nt.links.new(mp.outputs[0], sn.inputs["Vector"])
    dcol = _ramp(nt, sn.outputs["Fac"], [(0.35, dirt_dark), (0.65, dirt)])
    foot = _ramp(nt, sep.outputs["Z"], [(0.0, "#8a8090"), (0.5, "#ffffff")])
    dcol = _mix(nt, dcol, foot)
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(gm.outputs[0], mx.inputs["Factor"])
    nt.links.new(dcol, mx.inputs[6])
    nt.links.new(gcol, mx.inputs[7])
    col = _mix(nt, mx.outputs[2], _ao(nt, 0.15, 0.45))
    nt.links.new(col, em.inputs["Color"])
    return m


def mesa(variant):
    """an organic grassy plateau in a unit-ish box (radius 1, height 1): wobbly outline, soft rounded rim with a grass
    overhang, slightly flared skirt so neighbouring plateaus blend into each other and into the ground"""
    rng = random.Random(500 + variant)
    mat = ledge_mat("ledge", "#3e7a2e", "#68b04a", "#a6d65e", "#9a5a3a", "#5a321e")
    seed = Vector((variant * 3.7, variant * 1.3, 0.5))
    n = 72
    # (height, radius factor) profile from the foot to the top rim and over onto the top
    prof = [(0.0, 1.06), (0.18, 1.0), (0.45, 0.985), (0.7, 0.99), (0.86, 1.015), (0.94, 1.02), (0.985, 0.995), (1.0, 0.95)]
    bm = bmesh.new()
    rings = []
    for h, rf in prof:
        ring = []
        for i in range(n):
            a = i / n * math.tau
            d = Vector((math.cos(a), math.sin(a), 0))
            wob = noise.noise(d * 1.4 + seed) * 0.08 + noise.noise(d * 4.0 + seed + Vector((0, 0, h * 3))) * 0.025
            ring.append(bm.verts.new((d.x * rf * (1 + wob), d.y * rf * (1 + wob), h)))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[r][i], rings[r][j], rings[r + 1][j], rings[r + 1][i]))
    # top: gentle dome inside the rim
    inner = []
    for k, (sc, hh) in enumerate(((0.8, 1.012), (0.5, 1.02), (0.22, 1.024))):
        ring = []
        for i in range(n):
            v = rings[-1][i].co
            ring.append(bm.verts.new((v.x * sc / 0.95, v.y * sc / 0.95, hh + noise.noise(Vector((v.x, v.y, 0)) * 2 + seed) * 0.01)))
        inner.append(ring)
    prev = rings[-1]
    for ring in inner:
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
        prev = ring
    center = bm.verts.new((0, 0, 1.026))
    for i in range(n):
        bm.faces.new((prev[i], prev[(i + 1) % n], center))
    me = bpy.data.meshes.new("mesa")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("mesa", me)
    bpy.context.scene.collection.objects.link(o)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    K.apply_mods(o)
    smooth(assign(o, mat))
    # a few grass clumps hanging over the rim (the draping look)
    for k in range(10):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0))
        clump(d * 0.99 + Vector((0, 0, 0.93)), rng.uniform(0.05, 0.08), mat, 600 + k + variant * 20, squash=0.6, leafy=0.2)


PROPS = {}
for i in (1, 2):
    PROPS[f"GrassTuft_{i}"] = (grass_tuft, i, 2.2)
    PROPS[f"Fern_{i}"] = (fern, i, 3)
    PROPS[f"LeafPlant_{i}"] = (leaf_plant, i, 3)
    PROPS[f"Mushroom_{i}"] = (mushroom, i, 1.4)
for i in (1, 2, 3, 4, 5):
    PROPS[f"Flowers_{i}"] = (flowers, i, 1.6)
for i in (1, 2):
    PROPS[f"GrassPatch_{i}"] = (grass_patch, i, 4)
for i in (1, 2, 3):
    PROPS[f"Mesa_{i}"] = (mesa, i, 2)
    PROPS[f"GrassCap_{i}"] = (grass_cap, i, 2)
    for tone in ("Brown", "Gray", "Red"):
        PROPS[f"Cliff{tone}_{i}"] = ((lambda tn: (lambda v: cliff(v, tn)))(tone), i, 12)

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
