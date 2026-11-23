r"""Python mirror of Shared/Modules/BladeModel.lua (preview only): reads blade specs from Items.lua, writes parts JSON
for tools/blender/render_parts.py. Usage: python tools/blade_preview.py out.json [sheathed], then
blender -b -P tools/blender/render_parts.py -- out.json out.png front 1800 1100. Keep in sync with BladeModel.lua."""
import json, math, re, sys
import numpy as np

import os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = open(os.path.join(ROOT, 'src', 'shared', 'Config', 'Items.lua'), encoding='utf-8').read()

def parse_spec(t):
    return {k: (v.strip('"') if v.startswith('"') else (v == 'true')) for k, v in re.findall(r'(\w+) = ("[^"]*"|true)', t)}

specs = []
for gid, body in re.findall(r'\n\t(Plain|Keen|Master|Grand|Supreme) = (\{[^\n]*\}),', src):
    specs.append(('Sword_' + gid, parse_spec(body)))
for bid, name, tier, body in re.findall(r'\nblade\("(\w+)", "([^"]+)", "(\w+)", (\{[^\n]*\})\)', src):
    specs.append((bid, parse_spec(body)))

FORMS = {
    'Katana': dict(z0=-0.5, len=3.5, w0=0.22, w1=0.2, curve=0.2, grip=0.95, thick=0.07),
    'Cutlass': dict(z0=-0.45, len=3.3, w0=0.3, w1=0.42, curve=0.32, grip=0.85, thick=0.08),
    'Wooden': dict(z0=-0.5, len=3.4, w0=0.24, w1=0.22, curve=0.14, grip=0.95, thick=0.12),
}
SHAPES = {'straight': dict(curve=0.25), 'deep': dict(curve=1.8), 'slim': dict(w0=0.8, w1=0.75, len=1.06),
          'broad': dict(w0=1.25, w1=1.35), 'long': dict(len=1.15, w1=0.9), 'hooked': dict(curve=2.1, w1=1.1),
          'falchion': dict(w0=1.1, w1=1.6, curve=0.6)}
SEG = 8

def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])

def lerp(a, b, t):
    return a + (b - a) * t

def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

class CF:
    def __init__(self, p=(0, 0, 0), R=None):
        self.p = np.array(p, float); self.R = np.eye(3) if R is None else R
    def __mul__(self, o):
        return CF(self.p + self.R @ o.p, self.R @ o.R)

def T(x, y, z):
    return CF((x, y, z))

def build(spec, mode):
    base = FORMS[spec.get('form', 'Katana')]
    f = dict(base)
    for k, v in SHAPES.get(spec.get('shape'), {}).items():
        f[k] = base[k] * v
    parts = []
    def block(name, size, cf, c):
        parts.append((name, np.array(size, float), cf, c))
    guardC = hexc(spec['guard']); wrapC = hexc(spec['wrap'])
    wrap2 = hexc(spec['wrap2']) if 'wrap2' in spec else lerp(wrapC, np.zeros(3), 0.25)
    pommelC = hexc(spec.get('pommel', spec['guard']))
    zg = f['z0'] + 0.08
    light = lerp(guardC, np.ones(3), 0.22); dark = lerp(guardC, np.zeros(3), 0.2)
    def g(size, y, z=0, c=None):
        block('Guard', size, T(0, y, zg + z), guardC if c is None else c)
    style = spec.get('hilt'); form = spec.get('form')
    if form == 'Wooden':
        g((0.34, 0.4, 0.08), 0)
    elif form == 'Cutlass':
        def bow():
            g((0.1, 0.12, f['grip'] + 0.1), -0.32, (f['grip'] + 0.1) / 2)
            g((0.1, 0.18, 0.1), -0.24, f['grip'] + 0.08)
        if style == 'basket':
            g((0.12, 0.66, 0.1), -0.05); bow()
            for x in (-0.16, 0.16):
                block('Guard', (0.05, 0.36, 0.5), T(x, -0.16, zg + 0.27), dark)
                block('Guard', (0.06, 0.06, 0.5), T(x * 1.15, -0.02, zg + 0.27), light)
        elif style == 'shell':
            g((0.12, 0.5, 0.1), -0.05); bow()
            g((0.44, 0.36, 0.06), -0.12, 0.07, dark); g((0.34, 0.46, 0.06), -0.12, 0.07, dark); g((0.18, 0.18, 0.08), -0.12, 0.08, light)
        elif style == 'cross':
            g((0.12, 0.74, 0.1), 0); g((0.12, 0.1, 0.16), 0.36, -0.1, light); g((0.12, 0.1, 0.16), -0.36, -0.1, light)
        elif style == 'ring':
            g((0.12, 0.58, 0.1), -0.05); bow(); g((0.08, 0.06, 0.26), 0.3, 0.1, light); g((0.08, 0.22, 0.06), 0.3, 0.22, light)
        else:
            g((0.12, 0.62, 0.1), -0.05); bow(); g((0.3, 0.3, 0.06), -0.1, 0.07, dark)
    else:
        if style == 'round':
            g((0.5, 0.34, 0.08), 0); g((0.34, 0.54, 0.08), 0); g((0.44, 0.46, 0.08), 0); g((0.24, 0.3, 0.1), 0, 0, light)
        elif style == 'flower':
            g((0.3, 0.34, 0.08), 0)
            for ox, oy in ((0, 0.22), (0, -0.22), (0.2, 0), (-0.2, 0)):
                block('Guard', (0.16, 0.16, 0.08), T(ox, oy, zg), light)
        elif style == 'oval':
            g((0.3, 0.62, 0.08), 0); g((0.22, 0.5, 0.1), 0, 0, light)
        elif style == 'bar':
            g((0.2, 0.36, 0.06), 0)
        else:
            g((0.46, 0.5, 0.08), 0); g((0.36, 0.4, 0.1), 0, 0, light)
    n = 6; seg = f['grip'] / n
    for i in range(n):
        z = zg + 0.04 + seg * (i + 0.5); big = i % 2 == 0
        block('Grip', (0.22 if big else 0.19, 0.26 if big else 0.23, seg + 0.01), T(0, 0, z), wrapC if big else wrap2)
    block('Pommel', (0.25, 0.29, 0.12), T(0, 0, zg + 0.04 + f['grip'] + 0.05), pommelC)
    if mode == 'sheathed':
        c = hexc(spec.get('scabbard', '3A2A22')); trim = hexc(spec.get('pommel', spec['guard']))
        ln = f['len'] + 0.08; zc = f['z0'] - ln / 2; mw = max(f['w0'], f['w1'])
        block('Scabbard', (f['thick'] + 0.12, mw + 0.12, ln), CF((0, f['curve'] * 0.3, zc), rx(math.radians(-3))), c)
        block('Scabbard', (f['thick'] + 0.16, mw + 0.16, 0.14), T(0, 0.02, f['z0'] - 0.1), trim)
        block('Scabbard', (f['thick'] + 0.16, mw + 0.12, 0.18), T(0, f['curve'] * 0.62, f['z0'] - ln + 0.1), trim)
        return parts
    bladeC = hexc(spec['blade']); edgeC = hexc(spec.get('edge', spec['blade'])); wood = form == 'Wooden'
    segLen = f['len'] / SEG
    at = lambda t: f['curve'] * t * t
    for i in range(SEG):
        tm = (i + 0.5) / SEG
        w = f['w0'] + (f['w1'] - f['w0']) * tm
        y, z = at(tm), f['z0'] - (i + 0.5) * segLen
        if i == SEG - 1:
            w *= 0.62; y += w * 0.3
        cf = T(0, y, z); lastTop, lastW = y + w / 2, w
        block('Blade', (f['thick'], w, segLen), cf, bladeC)
        if not wood:
            block('Edge', (f['thick'] + 0.012, 0.07, segLen), cf * T(0, -w / 2 + 0.03, 0), edgeC)
    tw = lastW * 0.5
    block('Blade', (f['thick'], tw, segLen * 0.5), T(0, lastTop - tw / 2, f['z0'] - f['len'] - segLen * 0.25), bladeC if wood else edgeC)
    if form == 'Katana':
        block('Collar', (f['thick'] + 0.06, f['w0'] + 0.06, 0.1), T(0, 0, f['z0'] + 0.02), hexc(spec.get('pommel', 'D9A441')))
    return parts

mode = sys.argv[2] if len(sys.argv) > 2 else 'drawn'
ry = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]], float)  # CFrame.Angles(0, 90deg, 0): blade along -X, flats face +-Z
out = []
for i, (bid, spec) in enumerate(specs):
    col, row = i % 4, i // 4
    off = np.array([col * 5.2, 8 - row * 1.4, 0])
    for name, size, cf, c in build(spec, mode):
        R = ry @ cf.R; p = ry @ cf.p + off
        out.append({'cf': list(p) + list(R.flatten()), 'size': list(size), 'color': list(c)})
json.dump({'parts': out}, open(sys.argv[1], 'w'))
print(len(specs), [s[0] for s in specs])
