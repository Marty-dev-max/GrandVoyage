"""Detailed creature models (v3): organic sculpt-like bodies + baked textures, for monsters and late pet stages.

Technique (all procedural, no hand sculpting):
  1. a "bone" skeleton of vertices/edges with per-vertex radii -> Skin modifier -> Subdivision = one organic body with
     muscles where the radii bulge (no more stacked balls);
  2. noise displacement for lumpy, hand-sculpted surfaces;
  3. details as separate meshes: fur tufts, mane spikes, ears, fangs, claws, glowing eyes;
  4. everything is UV-unwrapped and its shading (two-tone fur, streaks, belly gradient, ambient occlusion) is BAKED into one
     1024 px color texture, so it looks the same in Roblox as in Blender.

  python tools/blender/creatures.py -- --out assets/models3d --only GuardWolf --preview
  (or open this file in Blender's Scripting tab and press Run Script: it builds into the open scene so you can look around)
"""
import math, os, random, sys
import bpy
import bmesh
from mathutils import Vector, Euler

def _tools_dir():
    """folder holding gvkit.py, both for `python creatures.py` and for Blender's Scripting tab (Open -> Run Script)"""
    cands = []
    try:
        cands.append(os.path.dirname(os.path.abspath(__file__)))
    except NameError:
        pass
    cands += [os.path.dirname(bpy.path.abspath(t.filepath)) for t in bpy.data.texts if t.filepath]
    for c in cands:
        if os.path.exists(os.path.join(c, "gvkit.py")):
            return c
    raise RuntimeError("Open this file from GrandVoyage/tools/blender (gvkit.py must be next to it)")


sys.path.insert(0, _tools_dir())
import gvkit as K

GUI = not bpy.app.background
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv
TEX = int(arg("--tex", "1024"))
R = math.radians


def lin3(h):
    c = K.rgb(h)
    return (K.lin(c[0]), K.lin(c[1]), K.lin(c[2]), 1.0)


# ---------------------------------------------------------------- materials (procedural, baked later)
def fur_mat(name, back, belly, streak=0.35, scale=26.0, axis="Y"):
    """two-tone fur: dark back -> light belly by height, long noise streaks along the body, AO in the creases"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    # back color on top, lighter on the underside (normal facing down: belly, chin, inner legs), darker lower legs
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sepn.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.15
    ramp.color_ramp.elements[0].color = lin3(belly)
    ramp.color_ramp.elements[1].position = 0.55
    ramp.color_ramp.elements[1].color = lin3(back)
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sepn.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    socks = nt.nodes.new("ShaderNodeMapRange")
    socks.inputs["From Min"].default_value = 0.15
    socks.inputs["From Max"].default_value = 0.6
    socks.inputs["To Min"].default_value = 0.55
    socks.inputs["To Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], socks.inputs["Value"])
    sm = nt.nodes.new("ShaderNodeMix")
    sm.data_type = "RGBA"
    sm.blend_type = "MULTIPLY"
    sm.inputs["Factor"].default_value = 1
    nt.links.new(ramp.outputs[0], sm.inputs[6])
    nt.links.new(socks.outputs[0], sm.inputs[7])
    # fur streaks: noise stretched along the body axis
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale * 0.12, scale) if axis == "Y" else (scale, scale, scale * 0.12)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Detail"].default_value = 8
    noise.inputs["Roughness"].default_value = 0.65
    nt.links.new(mp.outputs[0], noise.inputs["Vector"])
    nramp = nt.nodes.new("ShaderNodeValToRGB")
    nramp.color_ramp.elements[0].position = 0.35
    nramp.color_ramp.elements[0].color = (1 - streak, 1 - streak, 1 - streak, 1)
    nramp.color_ramp.elements[1].position = 0.7
    nramp.color_ramp.elements[1].color = (1.15, 1.12, 1.1, 1)
    nt.links.new(noise.outputs["Fac"], nramp.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1
    nt.links.new(sm.outputs[2], mul.inputs[6])
    nt.links.new(nramp.outputs[0], mul.inputs[7])
    # ambient occlusion -> darker creases (sells the "sculpted" look in Roblox's flat lighting)
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.35
    aor = nt.nodes.new("ShaderNodeValToRGB")
    aor.color_ramp.elements[0].color = (0.28, 0.24, 0.26, 1)
    aor.color_ramp.elements[1].color = (1, 1, 1, 1)
    nt.links.new(ao.outputs["AO"], aor.inputs[0])
    mul2 = nt.nodes.new("ShaderNodeMix")
    mul2.data_type = "RGBA"
    mul2.blend_type = "MULTIPLY"
    mul2.inputs["Factor"].default_value = 1
    nt.links.new(mul.outputs[2], mul2.inputs[6])
    nt.links.new(aor.outputs[0], mul2.inputs[7])
    nt.links.new(mul2.outputs[2], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def flat_mat(name, color, ao=True, glow=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    col = lin3(color)
    if ao and not glow:
        a = nt.nodes.new("ShaderNodeAmbientOcclusion")
        a.inputs["Color"].default_value = col
        a.inputs["Distance"].default_value = 0.2
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 0.75
        mix.inputs[6].default_value = col
        nt.links.new(a.outputs["AO"], mix.inputs[7])
        nt.links.new(mix.outputs[2], em.inputs["Color"])
    else:
        em.inputs["Color"].default_value = col
    m["glow"] = glow
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def gradient_mat(name, base, tip):
    """claws/teeth/horns: dark root -> light tip (by object Z, set per object via a scaled gradient)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    g = nt.nodes.new("ShaderNodeTexGradient")
    g.gradient_type = "SPHERICAL"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = lin3(tip)
    ramp.color_ramp.elements[1].color = lin3(base)
    nt.links.new(tc.outputs["Generated"], g.inputs[0])
    nt.links.new(g.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def assign(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True
    return o


# ---------------------------------------------------------------- organic body from a skeleton
def skin_body(verts, edges, radii, name="body", subdiv=2, lumps=0.025, seed=1):
    me = bpy.data.meshes.new(name)
    me.from_pydata([Vector(v) for v in verts], edges, [])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    sk.branch_smoothing = 0.6
    for i, r in enumerate(radii):
        rx, ry = r if isinstance(r, tuple) else (r, r)
        o.data.skin_vertices[0].data[i].radius = (rx, ry)
    o.data.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    if lumps > 0:
        tex = bpy.data.textures.new(name + "_lumps", "CLOUDS")
        tex.noise_scale = 0.35
        d = o.modifiers.new("lumps", "DISPLACE")
        d.texture = tex
        d.strength = lumps
        d.mid_level = 0.5
    K.apply_mods(o)
    return smooth(o)


def spike(base, direction, length, r, mat, seg=8):
    """a curved fur tuft / spike: cone from base pointing along direction"""
    d = Vector(direction).normalized()
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=0, depth=length, vertices=seg, location=Vector(base) + d * length * 0.5)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(rotation=True)
    return smooth(assign(o, mat))


def tuft(p0, p1, p2, r, mat, n=5, rings=4, flat=1.0):
    """curved tapered spike along a quadratic bezier (fur clump, mane lock, fang, claw, horn). Cheap: ~10*rings tris."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    bm = bmesh.new()
    prev = None
    side_ref = Vector((0, 0, 1))
    for i in range(rings + 1):
        t = i / rings
        c = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2
        tan = (2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)).normalized()
        if i == rings:
            tip = bm.verts.new(c)
            for k in range(n):
                bm.faces.new((prev[k], prev[(k + 1) % n], tip))
            break
        a = tan.cross(side_ref if abs(tan.dot(side_ref)) < 0.95 else Vector((1, 0, 0))).normalized()
        b = tan.cross(a).normalized()
        rr = r * (1 - t) ** 0.7
        ring = [bm.verts.new(c + (a * math.cos(k / n * math.tau) * flat + b * math.sin(k / n * math.tau)) * rr) for k in range(n)]
        if prev:
            for k in range(n):
                bm.faces.new((prev[k], prev[(k + 1) % n], ring[(k + 1) % n], ring[k]))
        else:
            bm.faces.new(list(reversed(ring)))
        prev = ring
    me = bpy.data.meshes.new("tuft")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("tuft", me)
    bpy.context.scene.collection.objects.link(o)
    return smooth(assign(o, mat))


def grow_fur(body, rule, count, rng, mats):
    """scatter tufts over the body surface. rule(pos, normal) -> None or (length, radius, sweep Vector, droop, mat index)"""
    me = body.data
    faces = []
    weights = []
    for f in me.polygons:
        res = rule(f.center, f.normal)
        if res:
            faces.append((f, res))
            weights.append(f.area * res[5] if len(res) > 5 else f.area)
    if not faces:
        return
    picks = rng.choices(range(len(faces)), weights=weights, k=count)
    for i in picks:
        f, (length, radius, sweep, droop, mi, *_r) = faces[i]
        length *= rng.uniform(0.7, 1.25)
        nrm = Vector(f.normal)
        # random point inside the face
        vs = [Vector(me.vertices[v].co) for v in f.vertices]
        w = [rng.random() for _ in vs]
        base = sum((v * (x / sum(w)) for v, x in zip(vs, w)), Vector()) - nrm * radius * 0.6
        d = (nrm * 0.55 + Vector(sweep)).normalized()
        mid = base + d * length * 0.55
        tip = base + d * length + Vector((0, 0, -droop * length))
        tuft(base, mid, tip, radius * rng.uniform(0.8, 1.2), mats[mi], n=5, rings=3, flat=0.55)


def blob(r, loc, mat, scale=(1, 1, 1), rot=(0, 0, 0), seg=20):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg // 2, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    return smooth(assign(o, mat))


# ---------------------------------------------------------------- creatures (face -Y, feet at z=0)
def guard_wolf():
    """a heavy, menacing red-brown wolf: hunched muscular shoulders, shaggy mane, bared fangs, glowing eyes"""
    fur = fur_mat("fur", "#3d1612", "#8e3e30", streak=0.45)
    fur_dark = fur_mat("fur_dark", "#2a0d0b", "#6e2a22", streak=0.5)
    fur_tip = fur_mat("fur_tip", "#5a221a", "#a85a44", streak=0.35)
    gum = flat_mat("gum", "#3a0c10")
    tongue = flat_mat("tongue", "#b0404a")
    tooth = gradient_mat("tooth", "#c9b38a", "#fffaf0")
    claw = gradient_mat("claw", "#1a1414", "#d8ccb8")
    eye = flat_mat("eye", "#ff2a2a", glow=True)
    nose = flat_mat("nose", "#140c0e")
    V = [
        (0, 0.95, 1.08),   # 0 hip
        (0, 0.4, 1.1),     # 1 waist
        (0, -0.3, 1.25),   # 2 chest / shoulders (big hump)
        (0, -0.78, 1.42),  # 3 neck
        (0, -1.1, 1.5),    # 4 skull
        (0, -1.5, 1.42),   # 5 muzzle
        (0, -1.84, 1.36),  # 6 nose
        (0.34, -0.42, 0.95), (0.36, -0.5, 0.5), (0.33, -0.52, 0.17), (0.34, -0.68, 0.08),
        (-0.34, -0.42, 0.95), (-0.36, -0.5, 0.5), (-0.33, -0.52, 0.17), (-0.34, -0.66, 0.07),
        (0.3, 0.9, 0.88), (0.36, 0.6, 0.55), (0.33, 0.98, 0.26), (0.33, 0.84, 0.07),
        (-0.3, 0.9, 0.88), (-0.36, 0.6, 0.55), (-0.33, 0.98, 0.26), (-0.33, 0.84, 0.07),
        (0, 1.32, 1.06), (0, 1.72, 0.9), (0, 2.05, 0.66), (0, 2.3, 0.42),
        (0, -1.36, 1.25), (0, -1.72, 1.2),
    ]
    E = [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6),
         (2, 7), (7, 8), (8, 9), (9, 10), (2, 11), (11, 12), (12, 13), (13, 14),
         (0, 15), (15, 16), (16, 17), (17, 18), (0, 19), (19, 20), (20, 21), (21, 22),
         (0, 23), (23, 24), (24, 25), (25, 26), (4, 27), (27, 28)]
    Rd = [(0.4, 0.44), (0.33, 0.36), (0.5, 0.56), (0.36, 0.38), (0.34, 0.33), (0.2, 0.18), (0.11, 0.1),
          (0.24, 0.26), (0.15, 0.16), (0.1, 0.1), (0.16, 0.1), (0.24, 0.26), (0.15, 0.16), (0.1, 0.1), (0.16, 0.1),
          (0.28, 0.32), (0.17, 0.19), (0.1, 0.1), (0.16, 0.1), (0.28, 0.32), (0.17, 0.19), (0.1, 0.1), (0.16, 0.1),
          (0.14, 0.14), (0.12, 0.12), (0.09, 0.09), (0.03, 0.03), (0.14, 0.08), (0.09, 0.05)]
    # muscle masses (shoulder blades, thighs) so the legs read as powerful, not tubes
    body = skin_body(V, E, Rd, "wolf", subdiv=2, lumps=0.035)
    for sx in (-1, 1):
        blob(0.3, (sx * 0.3, -0.42, 1.0), fur, scale=(0.7, 1.0, 1.35), rot=(R(-15), 0, 0))
        blob(0.34, (sx * 0.3, 0.78, 0.82), fur, scale=(0.72, 1.1, 1.25), rot=(R(20), 0, 0))
        # toes
        for leg in ((sx * 0.34, -0.68), (sx * 0.33, 0.84)):
            for k in (-1, 0, 1):
                blob(0.065, (leg[0] + k * 0.07, leg[1] - 0.1, 0.06), fur_dark, scale=(1, 1.3, 0.8))
    assign(body, fur)
    rng = random.Random(7)
    back = Vector((0, 1, 0.1))

    def rule(c, n):
        x, y, z = c
        if z < 0.3 or y < -1.25:  # paws + face stay sleek
            return None
        if y < 0.05 and z > 1.15 and n.z > -0.3:  # mane: long shaggy locks over neck + shoulders
            return (0.5, 0.065, back * 0.9 + Vector((0, 0, 0.35)), 0.55, rng.choice((1, 1, 0)), 6.0)
        if y < -0.9 and abs(x) > 0.18 and z > 1.0:  # cheek ruff
            return (0.28, 0.06, Vector((math.copysign(0.6, x), 0.7, -0.1)), 0.3, 0, 4.0)
        if n.z < -0.6 and z > 0.7:  # belly fringe hangs down
            return (0.2, 0.05, Vector((0, 0.5, -0.8)), 0.4, 2, 2.0)
        if z > 0.75:  # short coat everywhere else
            return (0.17, 0.035, back, 0.25, rng.choice((0, 0, 1, 2)), 1.2)
        if 0.35 < z <= 0.75:  # elbows / knees tufts
            return (0.14, 0.035, Vector((0, 0.8, -0.4)), 0.3, 0, 1.4)
        return None

    grow_fur(body, rule, 650, rng, [fur, fur_dark, fur_tip])
    # spine ridge: a row of bigger dark locks
    for i in range(10):
        y = -0.15 + i * 0.11
        z = 1.62 - i * 0.045
        tuft((0, y, z - 0.08), (0, y + 0.18, z + 0.18), (0, y + 0.42, z + 0.05), 0.08, fur_dark, rings=3)
    # bushy tail
    for i in range(36):
        t = i / 35
        p = Vector(V[23]).lerp(Vector(V[26]), t * 0.95)
        a = rng.uniform(0, math.tau)
        out = Vector((math.cos(a), 0, math.sin(a)))
        L = 0.32 * (1 - t * 0.5)
        tuft(p, p + out * L * 0.4 + Vector((0, L * 0.4, 0)), p + out * L * 0.5 + Vector((0, L, -L * 0.2)), 0.08 * (1 - t * 0.4), fur_dark if i % 3 else fur_tip, rings=3)
    # ears: tall, swept back, pink inside
    for sx in (-1, 1):
        b0 = Vector((sx * 0.18, -1.0, 1.72))
        tuft(b0, b0 + Vector((sx * 0.12, 0.08, 0.25)), b0 + Vector((sx * 0.17, 0.26, 0.34)), 0.11, fur_dark, n=4, rings=3, flat=0.45)
        tuft(b0 + Vector((0, -0.04, 0.02)), b0 + Vector((sx * 0.1, 0.02, 0.2)), b0 + Vector((sx * 0.16, 0.18, 0.3)), 0.07, gum, n=4, rings=2, flat=0.4)
    # heavy brow, glowing slit eyes
    for sx in (-1, 1):
        blob(0.11, (sx * 0.15, -1.32, 1.62), fur_dark, scale=(1.5, 0.9, 0.45), rot=(R(-15), R(-25 * sx), 0))
        blob(0.06, (sx * 0.16, -1.36, 1.56), eye, scale=(1.35, 0.5, 0.7), rot=(0, R(-20 * sx), 0))
    blob(0.085, V[6], nose, scale=(1.25, 1, 0.8))
    # snarling mouth: gums, tongue, fangs (big canines + small teeth)
    blob(0.15, (0, -1.56, 1.3), gum, scale=(1.0, 1.75, 0.42))
    blob(0.09, (0, -1.55, 1.25), tongue, scale=(1.0, 2.0, 0.35))
    for z, flip in ((1.35, -1), (1.25, 1)):
        for i in range(9):
            t = i / 8
            x = math.sin((t - 0.5) * 2.4) * 0.14
            y = -1.78 + abs(t - 0.5) * 0.6
            big = i in (1, 7)
            L = 0.16 if big else 0.06
            p = Vector((x, y, z))
            tuft(p, p + Vector((0, -0.02, flip * L * 0.6)), p + Vector((0, 0.03, flip * L)), 0.03 if big else 0.016, tooth, n=4, rings=2)
    # hooked claws
    for leg in (10, 14, 18, 22):
        p = Vector(V[leg])
        for k in (-1.5, -0.5, 0.5, 1.5):
            b0 = Vector((p.x + k * 0.05, p.y - 0.08, 0.07))
            tuft(b0, b0 + Vector((0, -0.1, 0.0)), b0 + Vector((0, -0.16, -0.08)), 0.03, claw, n=4, rings=2)
    return "GuardWolf", 6.5


CREATURES = {"GuardWolf": guard_wolf}


# ---------------------------------------------------------------- bake + export
def finalize(name, target):
    """join every mesh, unwrap, bake the procedural shading into one texture, return the textured object"""
    sc = bpy.context.scene
    objs = [o for o in sc.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    # keep it light enough for Roblox (MeshPart triangle budget)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("TRIS", name, tris)
    if tris > 18000:
        d = obj.modifiers.new("dec", "DECIMATE")
        d.ratio = 18000 / tris
        K.apply_mods(obj)
    def unwrap():
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=R(66), island_margin=0.004)
        bpy.ops.object.mode_set(mode="OBJECT")
    view = None
    if GUI:  # run from the Text Editor: UV operators want a 3D viewport context
        for area in bpy.context.screen.areas:
            if area.type == "VIEW_3D":
                view = (area, next(r for r in area.regions if r.type == "WINDOW"))
    if view:
        with bpy.context.temp_override(area=view[0], region=view[1], active_object=obj, object=obj):
            unwrap()
    else:
        unwrap()
    img = bpy.data.images.new(name + "_color", TEX, TEX, alpha=False)
    for m in obj.data.materials:
        node = m.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        m.node_tree.nodes.active = node
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24
    sc.render.bake.margin = 4
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="EMIT")
    img.pack()
    glow = any(m.get("glow") for m in obj.data.materials)
    # final material: the baked texture (what Roblox gets)
    fm = bpy.data.materials.new(name + "_mat")
    fm.use_nodes = True
    nt = fm.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.7
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(fm)
    obj["glow"] = glow
    # scale so the longest side is `target` studs, then stand it on z=0 (centered on x/y)
    s_ = target / max(obj.dimensions)
    obj.scale = (s_, s_, s_)
    bpy.ops.object.transform_apply(scale=True)
    xs = [v.co for v in obj.data.vertices]
    mn = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
    mx = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
    off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in obj.data.vertices:
        v.co -= off
    return obj


def preview(obj, path, size=512):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 60
    sc.collection.objects.link(cam)
    dims = obj.dimensions
    d = max(dims) * 1.5
    cam.location = (-d * 0.62, -d * 0.78, dims.z * 0.5 + d * 0.1)
    target = Vector((0, 0, dims.z * 0.45))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    for nm, loc, e in (("key", (-6, -8, 9), 2600), ("rim", (5, 8, 6), 3000), ("fill", (8, -5, 2), 700)):
        l = bpy.data.lights.new(nm, "AREA")
        l.energy = e
        l.size = 4
        o = bpy.data.objects.new(nm, l)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for key, fn in CREATURES.items():
        if ONLY and key not in ONLY:
            continue
        if GUI:
            # inside the Blender app: build into a fresh scene so the user's own scene is untouched
            sc = bpy.data.scenes.new(key)
            bpy.context.window.scene = sc
        else:
            K.reset()
        name, target = fn()
        obj = finalize("Mon_" + name, target)
        if GUI:
            for area in bpy.context.screen.areas:
                if area.type == "VIEW_3D":
                    area.spaces[0].shading.type = "MATERIAL"
            continue
        # Roblox: the baked texture goes into the GLB; models face -Y = Roblox forward
        K.export_glb(obj, os.path.join(OUT, "Mon_" + name + ".glb"))
        if PREVIEW:
            preview(obj, os.path.join(OUT, "preview", "Mon_" + name + ".png"))
        print("CREATURE", name)


if __name__ == "__main__":
    main()
