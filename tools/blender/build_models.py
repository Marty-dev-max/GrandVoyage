"""Build the in-game 3D models (pets x 3 stages, cursed fruits) as .glb + preview renders.

  python tools/blender/build_models.py -- --out assets/models3d [--only Gull_1,Fruit_Blaze] [--preview]

Chibi style: big heads, big shiny eyes, smooth shapes, toon outline. Every stage of a pet adds gear/features
(crests, armor, spikes) so evolutions read at a glance. Models face Blender -Y; the exporter turns them to Roblox -Z.
Upload: python3 tools/upload_models.py assets/models3d src/shared/Config/Models.lua
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gvkit as K
from gvkit import ball, box, cyl, cone, torus, eyes, tube

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)

R = math.radians
WHITE, DARK, GOLD, STEEL = "#f6f4ff", "#1b1630", "#ffc93a", "#b8c4d8"

# ======================= pets =======================
def hermit(st):
    shell = ("#f2d3a0", "#d9b27a", "#b98a52")[st - 1]
    body = "#ff7a5c"
    ball(0.75, (0, 0, 0.55), body, scale=(1.15, 0.9, 0.75))
    # shell on the back (stacked rings = spiral)
    for i in range(4):
        r = 0.7 - i * 0.15
        ball(r, (0, 0.35, 0.95 + i * 0.28), shell, scale=(1, 0.85, 0.6))
    if st >= 2:
        for i in range(5):
            a = i / 5 * math.tau
            cone(0.12, 0, 0.35, (math.cos(a) * 0.6, 0.35 + math.sin(a) * 0.5, 1.1), "#7a5a3a", rot=(R(70) * math.sin(a), R(70) * math.cos(a), 0))
    if st == 3:
        # castle top
        cyl(0.42, 0.45, (0, 0.35, 1.95), "#c9b9a0")
        for i in range(6):
            a = i / 6 * math.tau
            box((0.16, 0.16, 0.2), (math.cos(a) * 0.36, 0.35 + math.sin(a) * 0.36, 2.25), "#c9b9a0", bevel=0.02)
        cyl(0.03, 0.5, (0, 0.35, 2.55), "#7a4a26")
        box((0.3, 0.02, 0.18), (0.15, 0.35, 2.7), "#ff4b5c", bevel=0)
    # eye stalks
    for s in (-1, 1):
        cyl(0.05, 0.45, (s * 0.25, -0.35, 1.0), body)
        ball(0.17, (s * 0.25, -0.38, 1.28), WHITE)
        ball(0.09, (s * 0.25, -0.52, 1.3), DARK)
        ball(0.03, (s * 0.25 + 0.03, -0.6, 1.34), WHITE)
    # claws (grow with stage)
    k = (1.0, 1.3, 1.6)[st - 1]
    for s in (-1, 1):
        ball(0.32 * k, (s * 0.95, -0.55, 0.55), body, scale=(1, 1, 0.8))
        cone(0.14 * k, 0, 0.4 * k, (s * 0.95, -0.95, 0.65), "#ff9a80", rot=(R(-80), 0, 0))
        cone(0.12 * k, 0, 0.35 * k, (s * 0.95, -0.9, 0.42), "#ff9a80", rot=(R(-100), 0, 0))
        if st == 3:
            torus(0.3 * k * 0.7, 0.05, (s * 0.95, -0.55, 0.55), GOLD, rot=(R(90), 0, 0))
    for s in (-1, 1):
        for j in range(3):
            y = -0.25 + j * 0.3
            tube([(s * 0.6, y, 0.45), (s * 0.95, y, 0.45), (s * 1.15, y - 0.05, 0.12), (s * 1.2, y - 0.08, -0.05)], 0.07, body, taper=0.6)
    ball(0.12, (0, -0.68, 0.45), "#c94a3a", scale=(1.6, 0.4, 0.6))  # smile


def boarlet(st):
    fur = ("#c08a5a", "#9a6a42", "#6f5a50")[st - 1]
    ball(0.8, (0, 0.15, 0.75), fur, scale=(0.95, 1.15, 0.85))
    ball(0.62, (0, -0.55, 1.05), fur)
    cyl(0.24, 0.22, (0, -1.12, 0.95), "#ffb3a7", rot=(R(90), 0, 0))
    for s in (-1, 1):
        ball(0.05, (s * 0.08, -1.24, 0.97), "#7a3a3a")
        cone(0.16, 0, 0.32, (s * 0.38, -0.5, 1.6), fur, rot=(0, R(25 * s), 0))
        k = (0.22, 0.35, 0.45)[st - 1]
        cone(0.06, 0, k, (s * 0.3, -1.0, 0.75 + k * 0.35), WHITE, rot=(R(-20), R(-20 * s), 0))
        for zz in (0, 1):
            cyl(0.13, 0.4, (s * 0.42, -0.25 + zz * 0.75, 0.2), fur)
    eyes(0, -1.02, 1.3, r=0.12, spread=0.25)
    torus(0.12, 0.04, (0, 1.12, 0.95), fur, rot=(R(90), 0, 0))
    if st >= 2:
        for i in range(5):
            cone(0.12, 0, 0.45, (0, -0.25 + i * 0.28, 1.55 - i * 0.05), "#3a2a20", rot=(R(-15), 0, 0))
    if st == 3:
        box((1.4, 1.2, 0.18), (0, 0.3, 1.45), STEEL, bevel=0.05)
        box((0.9, 0.18, 0.5), (0, -0.85, 1.35), STEEL, bevel=0.05)
        for s in (-1, 1):
            cone(0.1, 0, 0.35, (s * 0.35, -0.75, 1.7), GOLD, rot=(0, R(20 * s), 0))


def gull(st):
    white = WHITE
    size = (1.0, 1.05, 1.15)[st - 1]
    ball(0.85 * size, (0, 0, 0.95), white, scale=(1, 1, 0.95))
    ball(0.6 * size, (0, -0.15, 1.75), white)
    cone(0.18, 0, 0.45, (0, -0.85, 1.7), "#ffb02e", rot=(R(-90), 0, 0))
    eyes(0, -0.62, 1.85, r=0.12, spread=0.24)
    span = (0.6, 1.0, 1.6)[st - 1]
    tip = ("#c9d3e6", "#8fa6c8", "#3f8cff")[st - 1]
    for s in (-1, 1):
        w = ball(0.55, (s * (0.7 + span * 0.35), 0.1, 1.1), white, scale=(span, 0.35, 0.55), rot=(0, R(-25 * s), 0))
        ball(0.3, (s * (0.75 + span * 0.85), 0.12, 1.25), tip, scale=(span * 0.6, 0.3, 0.4), rot=(0, R(-25 * s), 0))
        cyl(0.05, 0.35, (s * 0.25, 0, 0.15), "#ffb02e")
        ball(0.12, (s * 0.25, -0.12, 0.02), "#ffb02e", scale=(1, 1.6, 0.4))
    if st >= 2:
        torus(0.62, 0.05, (0, 0.0, 1.2), "#7a4a26", rot=(R(90), 0, R(30)))
        box((0.42, 0.18, 0.35), (0.5, -0.45, 0.85), "#b9773f", bevel=0.05)
        cyl(0.42, 0.12, (0, -0.1, 2.3), "#3a6fd8")
        cyl(0.48, 0.04, (0, -0.25, 2.24), "#2b55b0", rot=(R(10), 0, 0))
    if st == 3:
        for i, a in enumerate((-25, 0, 25)):
            cone(0.1, 0, 0.6, (math.sin(R(a)) * 0.3, 0.1, 2.55 + (0.1 if a == 0 else 0)), "#ffe14a", rot=(0, R(a), 0))


def puffer(st):
    body = ("#ffd65a", "#ffb03a", "#a46bff")[st - 1]
    ball(0.95, (0, 0, 1.0), body)
    ball(0.75, (0, -0.15, 0.85), "#fff3c9", scale=(0.95, 0.9, 0.7))
    eyes(0, -0.88, 1.2, r=0.16, spread=0.32)
    ball(0.1, (0, -0.95, 0.85), "#c9423a", scale=(1.5, 0.4, 0.8))
    n = (10, 18, 26)[st - 1]
    spike = ("#8a6a2a", "#c9622a", "#3a1f6a")[st - 1]
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(max(0, 1 - y * y))
        a = i * 2.39996
        d = (math.cos(a) * r, math.sin(a) * r, y)
        if d[1] < -0.55:
            continue
        cone(0.1, 0, 0.42, (d[0] * 1.02, d[1] * 1.02, 1.0 + d[2] * 1.02), spike,
             rot=(math.atan2(math.hypot(d[0], d[1]), d[2]) * 0 + math.acos(max(-1, min(1, d[2]))), 0, math.atan2(d[1], d[0]) + math.pi / 2))
    for s in (-1, 1):
        ball(0.3, (s * 0.95, 0, 0.9), body, scale=(0.4, 0.8, 0.6))
    cone(0.35, 0, 0.5, (0, 1.05, 1.0), body, rot=(R(-90), 0, 0))
    for s_ in (-1, 1):
        ball(0.12, (s_ * 0.55, -0.72, 1.0), "#ff8aa0", scale=(1, 0.4, 0.6))
    if st >= 2:
        ball(0.5, (0, 0.3, 1.9), body, scale=(0.25, 0.9, 0.6))
    if st == 3:
        cyl(0.4, 0.2, (0, 0, 2.05), GOLD)
        for i in range(5):
            a = i / 5 * math.tau
            cone(0.1, 0, 0.3, (math.cos(a) * 0.32, math.sin(a) * 0.32, 2.3), GOLD)


def lantern(st):
    body = ("#4a62c8", "#3a4cb0", "#2a2f86")[st - 1]
    belly = ("#cfe0ff", "#bcd0ff", "#a9b8ff")[st - 1]
    glow = "#7dfff0"
    ball(0.85, (0, 0.1, 1.0), body, scale=(0.95, 1.1, 0.88))
    ball(0.62, (0, -0.2, 0.82), belly, scale=(0.85, 0.85, 0.55))
    eyes(0, -0.85, 1.22, r=0.17, spread=0.3)
    teeth = (2, 4, 6)[st - 1]
    for i in range(teeth):
        x = -0.25 + i * (0.5 / max(1, teeth - 1))
        cone(0.05, 0, 0.14, (x, -0.9, 0.84), WHITE, rot=(R(180), 0, 0))
    lures = (1, 1, 3)[st - 1]
    for j in range(lures):
        a = (j - (lures - 1) / 2) * 0.7
        sx = math.sin(a)
        tip = (sx * 0.75, -0.75 - 0.1 * abs(sx), 2.25 - 0.25 * abs(sx))
        tube([(sx * 0.2, -0.1, 1.75), (sx * 0.45, -0.15, 2.4 - 0.2 * abs(sx)), (tip[0], tip[1] + 0.1, tip[2] + 0.2)], 0.04, body, taper=0.8)
        ball(0.2 if j == (lures - 1) / 2 else 0.15, tip, glow)
    # tail fin + side fins
    for s_ in (-1, 1):
        ball(0.35, (s_ * 0.22, 1.2, 1.05), "#7f95ff", scale=(0.3, 0.8, 0.9), rot=(R(-20), 0, R(20 * s_)))
        ball(0.32, (s_ * 0.88, 0.2, 0.8), "#7f95ff", scale=(0.3, 0.9, 0.5), rot=(0, R(20 * s_), 0))
    if st >= 2:
        for i in range(4):
            cone(0.12, 0, 0.4, (0, -0.15 + i * 0.3, 1.8 - i * 0.07), "#7f95ff", rot=(R(-15), 0, 0))
        for s_ in (-1, 1):
            for z in (0.85, 1.15):
                ball(0.06, (s_ * 0.83, -0.25, z), glow)
    if st == 3:
        torus(0.95, 0.035, (0, 0.1, 1.0), glow, rot=(R(90), 0, 0), major=40)
        for s_ in (-1, 1):
            cone(0.15, 0, 0.5, (s_ * 0.5, 0.25, 1.8), "#7f95ff", rot=(0, R(30 * s_), 0))


def leviathan(st):
    body = ("#3aa6c8", "#2b86b0", "#1f6896")[st - 1]
    belly = "#c8f5ff"
    fin = "#ffd56a"
    n = (8, 10, 12)[st - 1]
    pts = []
    for i in range(n):
        t = i / (n - 1)
        pts.append((math.sin(t * math.pi * 1.6) * 0.65, -0.1 + t * 2.3, 1.15 - t * 0.85 + math.sin(t * math.pi * 2) * 0.15))
    tube(pts, 0.42, body, taper=0.25, res=4)
    tube([(p[0], p[1] - 0.05, p[2] - 0.2) for p in pts[:-2]], 0.3, belly, taper=0.35)
    for i in range(1, n - 2, 2):
        p = pts[i]
        k = 1 - i / n * 0.7
        cone(0.14 * k, 0, 0.4 * k, (p[0], p[1], p[2] + 0.38 * k), fin, rot=(R(-20), 0, 0))
    tail = pts[-1]
    ball(0.3, (tail[0], tail[1] + 0.15, tail[2]), fin, scale=(1.2, 0.8, 0.25))
    hx, hy, hz = pts[0][0], -0.45, 1.35
    ball(0.62, (hx, hy, hz), body, scale=(1, 1.05, 0.92))
    ball(0.42, (hx, hy - 0.5, hz - 0.18), body, scale=(1, 1, 0.75))
    ball(0.3, (hx, hy - 0.55, hz - 0.32), belly, scale=(1, 0.9, 0.5))
    eyes(hx, hy - 0.5, hz + 0.18, r=0.15, spread=0.3)
    horn = (0.3, 0.55, 0.85)[st - 1]
    for s_ in (-1, 1):
        tube([(s_ * 0.3, hy + 0.1, hz + 0.45), (s_ * 0.42, hy + 0.3, hz + 0.45 + horn * 0.6), (s_ * 0.4, hy + 0.6, hz + 0.45 + horn)], 0.09, "#fff3c9", taper=0.15)
        ball(0.22, (s_ * 0.62, hy + 0.1, hz), fin, scale=(0.25, 0.9, 0.6), rot=(R(-20), 0, 0))
        if st >= 2:
            tube([(s_ * 0.3, hy - 0.85, hz - 0.2), (s_ * 0.6, hy - 1.0, hz - 0.35), (s_ * 0.85, hy - 0.9, hz - 0.6)], 0.035, fin, taper=0.3)
    if st == 3:
        for s_ in (-1, 1):
            tube([(s_ * 0.4, 0.4, 1.2), (s_ * 1.1, 0.5, 1.7), (s_ * 1.6, 0.8, 1.5)], 0.06, fin, taper=0.5)
            ball(0.6, (s_ * 1.05, 0.65, 1.35), "#8fe0ff", scale=(1.0, 0.45, 0.12), rot=(0, R(-25 * s_), 0))


# ======================= fruits =======================
def swirl_arms(c, R, color, arms=3, turns=1.3, r=0.075, zc=0.0):
    """raised spiral bands hugging a sphere of radius R at height c: the classic cursed-fruit swirl"""
    for arm in range(arms):
        pts = []
        for i in range(22):
            t = i / 21
            a = arm * math.tau / arms + t * math.tau * turns
            z = -0.92 + t * 1.84
            rr = math.sqrt(max(0.0, 1 - z * z))
            pts.append((math.cos(a) * rr * R, math.sin(a) * rr * R, c + z * R * 0.93))
        tube(pts, r, color)


def stem_leaf(top, leaf="#4fc35a", curl=1):
    tube([(0, 0, top - 0.15), (0.02, 0, top + 0.15), (0.12 * curl, 0, top + 0.35), (0.28 * curl, 0, top + 0.38)], 0.06, "#6b3f20", taper=0.7)
    ball(0.28, (0.3 * curl, -0.05, top + 0.2), leaf, scale=(1.3, 0.22, 0.55), rot=(0, R(-30 * curl), R(-15)))
    tube([(0.1 * curl, -0.08, top + 0.12), (0.5 * curl, -0.1, top + 0.3)], 0.018, "#2f8a3a")


def fruit_bounce():
    ball(0.88, (0, 0, 0.9), "#ff78c8", scale=(1.06, 1.06, 0.94), seg=32)
    swirl_arms(0.9, 0.9, "#a43ce0", arms=4, turns=1.5)
    stem_leaf(1.75)


def fruit_blaze():
    ball(0.85, (0, 0, 0.85), "#ff5a24", scale=(1, 1, 1.0), seg=32)
    swirl_arms(0.85, 0.87, "#ffd23a", arms=3, turns=1.2, r=0.085)
    for i in range(6):
        a = i / 6 * math.tau
        x, y = math.cos(a) * 0.32, math.sin(a) * 0.32
        h = 0.45 + 0.15 * (i % 2)
        tube([(x, y, 1.45), (x * 1.3, y * 1.3, 1.45 + h * 0.4), (x * 0.5, y * 0.5, 1.45 + h)], 0.12, "#ff9a2a", taper=0.1)
    tube([(0, 0, 1.4), (0.08, 0, 1.85), (-0.05, 0, 2.3)], 0.17, "#ffd23a", taper=0.1)


def fruit_haze():
    for (x, y, z, r) in ((0, 0, 0.8, 0.75), (0.5, 0.1, 1.05, 0.5), (-0.5, -0.1, 1.0, 0.52), (0.1, -0.45, 1.05, 0.48), (-0.1, 0.45, 1.1, 0.5), (0, 0, 1.35, 0.5)):
        ball(r, (x, y, z), "#dfe3ec", seg=24)
    swirl_arms(0.95, 0.82, "#8f95a8", arms=3, turns=1.1, r=0.06)
    for (x, y, z, r) in ((0.55, 0.0, 1.75, 0.18), (0.75, 0.05, 2.0, 0.13), (0.62, 0.0, 2.2, 0.09)):
        ball(r, (x, y, z), "#c4c9d6")
    stem_leaf(1.8, "#9ad08a")


def fruit_ward():
    bpy = K.bpy
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.9, subdivisions=1, location=(0, 0, 0.9))
    o = bpy.context.object
    o.scale = (1, 1, 1.05)
    bpy.ops.object.transform_apply(scale=True)
    o["gvcolor"] = "#6fd0ff"
    for p in o.data.polygons:
        p.use_smooth = False
    swirl_arms(0.9, 0.86, "#effcff", arms=3, turns=1.0, r=0.07)
    for i in range(6):
        a = i / 6 * math.tau
        cone(0.09, 0, 0.3, (math.cos(a) * 0.35, math.sin(a) * 0.35, 1.72), "#bff0ff", rot=(R(25) * math.sin(a) * -1, R(25) * math.cos(a), 0))
    stem_leaf(1.8, "#7ae0c8")


def fruit_split():
    for s in (-1, 1):
        ball(0.8, (s * 0.2, 0, 0.85), "#5fcf6c", scale=(0.62, 1, 1), seg=28)
    tube([(0, -0.8, 0.85), (0, -0.55, 1.55), (0, 0, 1.7), (0, 0.55, 1.55), (0, 0.8, 0.85), (0, 0.55, 0.15), (0, -0.55, 0.15), (0, -0.8, 0.85)], 0.07, "#f2f07a")
    for s in (-1, 1):
        swirl_arms(0.85, 0.82, "#f2f07a", arms=1, turns=0.9 * s, r=0.06)
    stem_leaf(1.75)


def fruit_slick():
    ball(0.85, (0, 0, 0.75), "#ffd84a", scale=(1, 1, 0.9), seg=32)
    ball(0.55, (0, 0, 1.45), "#ffd84a", seg=28)
    swirl_arms(0.75, 0.85, "#fff6c8", arms=3, turns=1.0, r=0.065)
    for (x, y, z) in ((0.45, -0.7, 1.0), (-0.5, -0.6, 0.55), (0.1, -0.85, 0.4)):
        ball(0.1, (x, y, z), "#ffffff", scale=(0.8, 0.5, 1.2))
    stem_leaf(1.95)


FRUITS = {"Bounce": fruit_bounce, "Blaze": fruit_blaze, "Haze": fruit_haze, "Ward": fruit_ward, "Split": fruit_split, "Slick": fruit_slick}


MODELS = {}
for sp, fn, target in (("Hermit", hermit, 3.0), ("Boarlet", boarlet, 3.2), ("Gull", gull, 3.0), ("Puffer", puffer, 2.6), ("Lantern", lantern, 3.0), ("Leviathan", leviathan, 3.6)):
    for st in (1, 2, 3):
        MODELS[f"{sp}_{st}"] = (fn, st, target * (0.85 + 0.2 * st))
for fid, fn in FRUITS.items():
    MODELS["Fruit_" + fid] = ((lambda f: (lambda _st: f()))(fn), None, 2.4)


def main():
    for name, (fn, st, target) in MODELS.items():
        if ONLY and name not in ONLY:
            continue
        try:
            K.reset()
            fn(st)
            obj = K.build_mesh(name, outline=0.06 * target / 3, target=target)
            K.export_glb(obj, os.path.join(OUT, name + ".glb"))
            if PREVIEW:
                K.preview(obj, os.path.join(OUT, "preview", name + ".png"))
            print("MODEL", name)
        except Exception as e:
            import traceback
            traceback.print_exc()
            print("FAIL", name, e)


main()
