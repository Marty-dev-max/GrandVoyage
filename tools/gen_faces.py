"""Anime-style face images for the character creator (v0.24.0, owner): drawn here, uploaded with
   python3 tools/gen_faces.py              -> assets/faces/*.png (+ assets/faces/preview.png contact sheet)
   ROBLOX_API_KEY=... python3 tools/upload_images.py assets/faces src/shared/Config/FaceImages.lua
Eyes (both eyes in one 512x256 image) come in 4 layers so the iris can take the player's two colors:
   eye<N>_white  sclera (untinted, drawn first)
   eye<N>_iris   iris, white -> tinted with Eyes Color 1
   eye<N>_iris2  lower half of the iris, white -> tinted with Eyes Color 2 (a gradient feel)
   eye<N>_over   lashes, lids, pupil, shine (untinted, on top)
Mouths are one finished image each (mouth<N>, 256x128, not tinted).
Everything is drawn 4x and downsampled for smooth anti-aliased lines. All designs are original."""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'faces')
SS = 4
EW, EH = 512, 256
MW, MH = 256, 128
INK = (34, 24, 30, 255)
WHITE = (255, 255, 255, 255)


def canvas(w, h):
    return Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))


def down(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def S(v):
    return v * SS


def ellipse_pts(cx, cy, rx, ry, a0=0, a1=360, n=60, tilt=0.0):
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        x, y = math.cos(a) * rx, math.sin(a) * ry
        xr = x * math.cos(tilt) - y * math.sin(tilt)
        yr = x * math.sin(tilt) + y * math.cos(tilt)
        pts.append((S(cx + xr), S(cy + yr)))
    return pts


def star(cx, cy, r, points=4, inner=0.35, rot=-90):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        rr = r if i % 2 == 0 else r * inner
        pts.append((S(cx + math.cos(a) * rr), S(cy + math.sin(a) * rr)))
    return pts


def heart(cx, cy, r):
    pts = []
    for i in range(80):
        t = math.pi * 2 * i / 80
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((S(cx + x * r / 17), S(cy + y * r / 17)))
    return pts


# ---------- eyes ----------
# style keys: rx, ry (eye opening), tilt (radians, outer corner up > 0), lid (upper lid thickness), lash (flick count),
# iris (iris radius factor), pupil: dot|slit|star|heart|ring|none, shine (highlights), lower (lower lash line),
# lidcut (0..1 top of the eye hidden by a heavy lid), closed: None|'happy'|'line'|'wink', brow: angle in degrees (+ = angry)
EYES = [
    dict(name='Bright', rx=52, ry=58, tilt=0.05, lid=9, lash=2, iris=0.82, pupil='dot', shine=2, lower=True),
    dict(name='Gentle', rx=56, ry=48, tilt=-0.12, lid=8, lash=1, iris=0.8, pupil='dot', shine=2, lower=True, brow=-8),
    dict(name='Sharp', rx=62, ry=34, tilt=0.22, lid=10, lash=2, iris=0.75, pupil='dot', shine=1, lower=False, brow=10),
    dict(name='Fierce', rx=58, ry=38, tilt=0.15, lid=12, lash=1, iris=0.7, pupil='dot', shine=1, lower=True, brow=22, lidcut=0.25),
    dict(name='Sleepy', rx=56, ry=46, tilt=-0.05, lid=9, lash=1, iris=0.8, pupil='dot', shine=1, lower=False, lidcut=0.5),
    dict(name='Sparkle', rx=54, ry=62, tilt=0.0, lid=9, lash=3, iris=0.86, pupil='dot', shine=3, lower=True, sparkle=True),
    dict(name='Cat', rx=58, ry=46, tilt=0.2, lid=10, lash=2, iris=0.85, pupil='slit', shine=1, lower=True),
    dict(name='Calm', rx=60, ry=36, tilt=0.0, lid=9, lash=0, iris=0.78, pupil='dot', shine=1, lower=False, lidcut=0.15),
    dict(name='Happy', closed='happy'),
    dict(name='Wink', rx=52, ry=56, tilt=0.05, lid=9, lash=2, iris=0.82, pupil='dot', shine=2, lower=True, closed='wink'),
    dict(name='Tired', rx=54, ry=42, tilt=-0.08, lid=9, lash=0, iris=0.72, pupil='dot', shine=0, lower=True, lidcut=0.35, bags=True),
    dict(name='Starry', rx=54, ry=58, tilt=0.03, lid=9, lash=2, iris=0.84, pupil='star', shine=1, lower=True),
    dict(name='Lovestruck', rx=54, ry=56, tilt=0.0, lid=9, lash=2, iris=0.84, pupil='heart', shine=1, lower=True),
    dict(name='Determined', rx=58, ry=42, tilt=0.1, lid=13, lash=1, iris=0.74, pupil='dot', shine=1, lower=True, brow=16),
    dict(name='Shy', rx=50, ry=50, tilt=-0.1, lid=8, lash=2, iris=0.8, pupil='dot', shine=2, lower=True, look=-14, brow=-12),
    dict(name='Cool', rx=62, ry=40, tilt=0.12, lid=11, lash=3, iris=0.66, pupil='dot', shine=1, lower=False, lidcut=0.3),
    dict(name='Spiral', rx=54, ry=56, tilt=0.0, lid=8, lash=1, iris=0.86, pupil='ring', shine=0, lower=True),
    dict(name='Shocked', rx=56, ry=60, tilt=0.0, lid=7, lash=1, iris=0.42, pupil='dot', shine=1, lower=True, brow=-18),
    dict(name='Closed', closed='line'),
    dict(name='Round', rx=46, ry=50, tilt=0.0, lid=8, lash=0, iris=0.9, pupil='dot', shine=2, lower=False),
    # v0.25.91 (owner: monsters all had the same face): rougher eyes for monsters (players may pick them too)
    dict(name='Thug', rx=52, ry=28, tilt=0.2, lid=15, lash=0, iris=0.95, pupil='dot', shine=0, lower=True, brow=30, bw=15, lidcut=0.18),
    dict(name='Stern', rx=56, ry=30, tilt=0.03, lid=14, lash=0, iris=0.82, pupil='dot', shine=1, lower=False, brow=8, bw=15, lidcut=0.22),
    dict(name='Beady', rx=30, ry=32, tilt=0.0, lid=7, lash=0, iris=0.98, pupil='bead', shine=1, lower=False, brow=20, bw=12),
    dict(name='Crazed', rx=58, ry=54, tilt=0.0, lid=7, lash=0, iris=0.3, pupil='dot', shine=0, lower=True, brow=-12, bags=True),
    dict(name='Feral', rx=56, ry=36, tilt=0.26, lid=12, lash=1, iris=0.9, pupil='slit', shine=1, lower=True, brow=26, bw=12, lidcut=0.12),
]


def draw_eye(layers, cx, cy, st, mirror):
    white, iris, iris2, over = [ImageDraw.Draw(l) for l in layers]
    m = -1 if mirror else 1
    rx, ry = st['rx'], st['ry']
    tilt = st.get('tilt', 0) * m
    # opening
    body = ellipse_pts(cx, cy, rx, ry, tilt=tilt)
    white.polygon(body, fill=WHITE)
    # iris + pupil (clipped to the opening below)
    ir = min(rx, ry) * st['iris']
    ix = cx + st.get('look', 0) * m * 0 + st.get('look', 0)
    iy = cy + ry * 0.08
    iris.ellipse([S(ix - ir), S(iy - ir * 1.12), S(ix + ir), S(iy + ir * 1.12)], fill=WHITE)
    iris2.ellipse([S(ix - ir), S(iy - ir * 1.12), S(ix + ir), S(iy + ir * 1.12)], fill=WHITE)
    # keep only the lower ~45% for color 2 (fades in)
    cut = Image.new('L', layers[2].size, 0)
    cd = ImageDraw.Draw(cut)
    top = iy - ir * 0.05
    for k in range(40):
        a = int(255 * min(1, k / 18))
        y0 = S(top + (ir * 1.2) * k / 40)
        cd.rectangle([0, y0, cut.width, y0 + S(ir * 1.2 / 40) + 1], fill=a)
    cd.rectangle([0, S(top + ir * 1.2), cut.width, cut.height], fill=255)
    layers[2].putalpha(Image.composite(layers[2].getchannel('A'), Image.new('L', cut.size, 0), cut))
    # iris ring + pupil
    over.ellipse([S(ix - ir), S(iy - ir * 1.12), S(ix + ir), S(iy + ir * 1.12)], outline=(30, 20, 30, 150), width=S(3))
    p = st.get('pupil', 'dot')
    if p == 'dot':
        pr = ir * 0.45
        over.ellipse([S(ix - pr), S(iy - pr * 1.15), S(ix + pr), S(iy + pr * 1.15)], fill=(20, 14, 24, 235))
    elif p == 'bead':
        over.ellipse([S(ix - ir * 0.9), S(iy - ir), S(ix + ir * 0.9), S(iy + ir)], fill=(20, 14, 24, 245))
    elif p == 'slit':
        over.ellipse([S(ix - ir * 0.16), S(iy - ir * 0.95), S(ix + ir * 0.16), S(iy + ir * 0.95)], fill=(20, 14, 24, 240))
    elif p == 'star':
        over.polygon(star(ix, iy, ir * 0.62, 5, 0.45), fill=(255, 250, 220, 255))
    elif p == 'heart':
        over.polygon(heart(ix, iy + 2, ir * 0.6), fill=(255, 90, 140, 255))
    elif p == 'ring':
        for k in range(3):
            rr = ir * (0.3 + 0.22 * k)
            over.ellipse([S(ix - rr), S(iy - rr), S(ix + rr), S(iy + rr)], outline=(20, 14, 24, 220), width=S(4))
    # shine
    shines = st.get('shine', 1)
    if shines >= 1:
        over.ellipse([S(ix - ir * 0.62), S(iy - ir * 0.8), S(ix - ir * 0.12), S(iy - ir * 0.3)], fill=WHITE)
    if shines >= 2:
        over.ellipse([S(ix + ir * 0.25), S(iy + ir * 0.3), S(ix + ir * 0.5), S(iy + ir * 0.55)], fill=WHITE)
    if shines >= 3 or st.get('sparkle'):
        over.polygon(star(ix + ir * 0.4, iy - ir * 0.55, ir * 0.32, 4, 0.3), fill=WHITE)
    # heavy lid hides the top of the eye
    lidcut = st.get('lidcut', 0)
    clip = Image.new('L', layers[0].size, 0)
    ImageDraw.Draw(clip).polygon(body, fill=255)
    if lidcut > 0:
        ImageDraw.Draw(clip).rectangle([0, 0, clip.width, S(cy - ry + 2 * ry * lidcut)], fill=0)
    for li in (0, 1, 2):
        a = layers[li].getchannel('A')
        layers[li].putalpha(Image.composite(a, Image.new('L', a.size, 0), clip))
    # over layer: everything except lashes is clipped too (pupil/shine stay inside)
    a = layers[3].getchannel('A')
    layers[3].putalpha(Image.composite(a, Image.new('L', a.size, 0), clip))
    over = ImageDraw.Draw(layers[3])
    # upper lid line (thick) + lashes
    ytop = cy - ry + 2 * ry * lidcut
    if lidcut > 0:
        # flat heavy lid line across the cut
        xs = ry * math.sqrt(max(0.0, 1 - ((ytop - cy) / ry) ** 2)) * rx / ry
        over.line([(S(cx - xs - 4), S(ytop)), (S(cx + xs + 4), S(ytop + tilt * -20))], fill=INK, width=S(st['lid']))
    else:
        lid = ellipse_pts(cx, cy, rx + 2, ry + 2, 195, 345, 40, tilt=tilt)
        over.line(lid, fill=INK, width=S(st['lid']), joint='curve')
    # outer lash flicks
    for k in range(st.get('lash', 0)):
        ox = cx + m * (rx * 0.9)
        oy = cy - ry * (0.35 - k * 0.22)
        over.line([(S(ox), S(oy)), (S(ox + m * (16 + 4 * k)), S(oy - 12 + 6 * k))], fill=INK, width=S(6))
    if st.get('lower'):
        low = ellipse_pts(cx, cy, rx * 0.8, ry, 40, 140, 30, tilt=tilt)
        over.line(low, fill=(60, 40, 50, 170), width=S(3), joint='curve')
    if st.get('bags'):
        bag = ellipse_pts(cx, cy + ry * 0.35, rx * 0.7, ry * 0.9, 30, 150, 30, tilt=tilt)
        over.line(bag, fill=(120, 90, 110, 140), width=S(3))
    # brow
    by = cy - ry - 22
    ang = math.radians(st.get('brow', 0)) * m
    bx0, bx1 = cx - rx * 0.85, cx + rx * 0.85
    y0 = by + math.tan(ang) * (-rx * 0.85) * -1
    y1 = by + math.tan(ang) * (rx * 0.85) * -1
    over.line([(S(bx0), S(y0)), (S(bx1), S(y1))], fill=(60, 40, 40, 230), width=S(st.get('bw', 9)))


def draw_closed(over, cx, cy, kind, m=1):
    if kind == 'happy':
        arc = ellipse_pts(cx, cy + 30, 72, 56, 200, 340, 30)
        over.line(arc, fill=INK, width=S(11), joint='curve')
    else:
        arc = ellipse_pts(cx, cy - 16, 74, 34, 20, 160, 30)
        over.line(arc, fill=INK, width=S(10), joint='curve')
        over.line([(S(cx + m * 50), S(cy)), (S(cx + m * 64), S(cy - 8))], fill=INK, width=S(6))
    over.line([(S(cx - 60), S(cy - 92)), (S(cx + 60), S(cy - 96))], fill=(60, 40, 40, 230), width=S(9))


def make_eyes(i, st):
    layers = [canvas(EW, EH) for _ in range(4)]
    L, R = (EW * 0.25, EH * 0.58), (EW * 0.75, EH * 0.58)
    closed = st.get('closed')
    if closed in ('happy', 'line'):
        over = ImageDraw.Draw(layers[3])
        draw_closed(over, *L, closed, -1)
        draw_closed(over, *R, closed, 1)
    else:
        # each eye on its own layers (the per-eye clipping must not erase the other eye), then merged
        big = dict(st)
        big['rx'], big['ry'] = st['rx'] * 1.5, st['ry'] * 1.5
        big['lid'] = int(st['lid'] * 1.3)
        sides = [(L, True)] + ([] if closed == 'wink' else [(R, False)])
        for (ex, ey), mir in sides:
            tmp = [canvas(EW, EH) for _ in range(4)]
            draw_eye(tmp, ex, ey, big, mir)
            for k in range(4):
                layers[k] = Image.alpha_composite(layers[k], tmp[k])
        if closed == 'wink':
            draw_closed(ImageDraw.Draw(layers[3]), R[0], R[1], 'happy', 1)
    for name, l in zip(('white', 'iris', 'iris2', 'over'), layers):
        down(l, EW, EH).save(os.path.join(OUT, f'eye{i}_{name}.png'))


# ---------- mouths ----------
TEETH = (250, 250, 250, 255)
TONGUE = (238, 110, 120, 255)
INSIDE = (120, 36, 46, 255)


def make_mouth(i, kind):
    img = canvas(MW, MH)
    d = ImageDraw.Draw(img)
    cx, cy = MW / 2, MH / 2
    def arc(rx, ry, a0, a1, w=8, dy=0, col=INK):
        d.line(ellipse_pts(cx, cy + dy, rx, ry, a0, a1, 40), fill=col, width=S(w), joint='curve')
    def opening(rx, ry, dy=0, teeth=False, tongue=True, flat_top=False):
        pts = ellipse_pts(cx, cy + dy, rx, ry, 0, 180, 40) if flat_top else ellipse_pts(cx, cy + dy, rx, ry)
        d.polygon(pts, fill=INSIDE)
        if tongue:
            d.ellipse([S(cx - rx * 0.6), S(cy + dy + ry * 0.2), S(cx + rx * 0.6), S(cy + dy + ry * 1.1)], fill=TONGUE)
        if teeth:
            d.rectangle([S(cx - rx * 0.8), S(cy + dy - (0 if flat_top else ry) - 1), S(cx + rx * 0.8), S(cy + dy - (0 if flat_top else ry) + ry * 0.32)], fill=TEETH)
        # re-clip to the opening
        clip = Image.new('L', img.size, 0)
        ImageDraw.Draw(clip).polygon(pts, fill=255)
        return pts, clip
    if kind == 'smile':
        arc(34, 16, 20, 160)
    elif kind == 'small':
        arc(18, 9, 25, 155, 7)
    elif kind == 'grin':
        pts, _ = opening(40, 26, -6, teeth=True, flat_top=True)
        d.line(pts + [pts[0]], fill=INK, width=S(6))
    elif kind == 'laugh':
        pts, _ = opening(36, 34, -10, teeth=False, flat_top=True)
        d.line(pts + [pts[0]], fill=INK, width=S(6))
    elif kind == 'o':
        d.ellipse([S(cx - 14), S(cy - 16), S(cx + 14), S(cy + 16)], fill=INSIDE, outline=INK, width=S(5))
    elif kind == 'flat':
        d.line([(S(cx - 24), S(cy)), (S(cx + 24), S(cy))], fill=INK, width=S(7))
    elif kind == 'frown':
        arc(28, 14, 200, 340, 8, dy=14)
    elif kind == 'smirk':
        d.line(ellipse_pts(cx + 6, cy - 4, 28, 12, 10, 120, 30), fill=INK, width=S(7), joint='curve')
        d.line([(S(cx - 24), S(cy + 4)), (S(cx - 4), S(cy + 8))], fill=INK, width=S(6))
    elif kind == 'cat':
        d.line(ellipse_pts(cx - 13, cy - 2, 13, 11, 10, 170, 20), fill=INK, width=S(7), joint='curve')
        d.line(ellipse_pts(cx + 13, cy - 2, 13, 11, 10, 170, 20), fill=INK, width=S(7), joint='curve')
    elif kind == 'fang':
        arc(36, 16, 15, 165, 8)
        d.polygon([(S(cx + 12), S(cy + 13)), (S(cx + 22), S(cy + 12)), (S(cx + 17), S(cy + 26))], fill=TEETH, outline=INK)
    elif kind == 'shout':
        d.polygon(ellipse_pts(cx, cy + 2, 26, 30), fill=INSIDE)
        d.ellipse([S(cx - 16), S(cy + 10), S(cx + 16), S(cy + 32)], fill=TONGUE)
        d.line(ellipse_pts(cx, cy + 2, 26, 30) + [ellipse_pts(cx, cy + 2, 26, 30)[0]], fill=INK, width=S(6))
    elif kind == 'tongue':
        arc(30, 12, 15, 165, 8)
        d.ellipse([S(cx - 12), S(cy + 6), S(cx + 12), S(cy + 34)], fill=TONGUE, outline=INK, width=S(4))
    elif kind == 'wavy':
        pts = [(S(cx - 30 + k * 4), S(cy + math.sin(k * 0.9) * 6)) for k in range(16)]
        d.line(pts, fill=INK, width=S(6), joint='curve')
    elif kind == 'toothy':
        d.rectangle([S(cx - 34), S(cy - 12), S(cx + 34), S(cy + 12)], fill=TEETH, outline=INK, width=S(6))
        for k in range(1, 6):
            x = cx - 34 + k * 68 / 6
            d.line([(S(x), S(cy - 12)), (S(x), S(cy + 12))], fill=INK, width=S(3))
        d.line([(S(cx - 34), S(cy)), (S(cx + 34), S(cy))], fill=INK, width=S(3))
    elif kind == 'pout':
        d.ellipse([S(cx - 10), S(cy - 6), S(cx + 10), S(cy + 8)], fill=(230, 120, 130, 255), outline=INK, width=S(4))
    elif kind == 'open_smile':
        pts, _ = opening(30, 20, -4, teeth=False, flat_top=True)
        d.line(pts + [pts[0]], fill=INK, width=S(6))
    elif kind == 'clench':
        d.rounded_rectangle([S(cx - 30), S(cy - 10), S(cx + 30), S(cy + 10)], radius=S(8), fill=TEETH, outline=INK, width=S(6))
        d.line([(S(cx - 30), S(cy)), (S(cx + 30), S(cy))], fill=INK, width=S(3))
    elif kind == 'snarl':  # lip pulled up on one side over bared teeth
        pts = [(S(cx - 34), S(cy + 6)), (S(cx - 6), S(cy + 2)), (S(cx + 16), S(cy - 12)), (S(cx + 34), S(cy - 4)),
               (S(cx + 30), S(cy + 12)), (S(cx - 34), S(cy + 12))]
        d.polygon(pts, fill=TEETH)
        for k in range(1, 6):
            x = cx - 34 + k * 64 / 6
            d.line([(S(x), S(cy - 6)), (S(x), S(cy + 12))], fill=INK, width=S(3))
        d.polygon([(S(cx + 12), S(cy - 8)), (S(cx + 20), S(cy - 9)), (S(cx + 16), S(cy + 6))], fill=TEETH, outline=INK)
        d.line(pts + [pts[0]], fill=INK, width=S(6), joint='curve')
    elif kind == 'scowl':
        arc(30, 12, 200, 340, 11, dy=16)
        d.line([(S(cx - 34), S(cy + 14)), (S(cx - 26), S(cy + 22))], fill=INK, width=S(7))
        d.line([(S(cx + 34), S(cy + 14)), (S(cx + 26), S(cy + 22))], fill=INK, width=S(7))
    elif kind == 'painted':  # clown: wide red painted smile with a white grin inside
        d.polygon(ellipse_pts(cx, cy - 14, 54, 40, 10, 170, 40) + ellipse_pts(cx, cy - 14, 40, 22, 170, 10, 40)[::1],
                  fill=(220, 40, 60, 255))
        pts, _ = opening(30, 16, -4, teeth=True, tongue=False, flat_top=True)
        d.line(pts + [pts[0]], fill=INK, width=S(5))
    down(img, MW, MH).save(os.path.join(OUT, f'mouth{i}.png'))


# ---------- face marks (monsters, v0.25.91): one full-face overlay (256x256) on top of eyes + mouth ----------
FW = 256


def make_mark(name):
    img = canvas(FW, FW)
    d = ImageDraw.Draw(img)
    # where things sit on the face (matches VoxelChar faceLayer boxes): eyes ~ (0.27|0.73, 0.5), mouth (0.5, 0.75)
    ex, ey, mx, my = FW * 0.27, FW * 0.5, FW * 0.5, FW * 0.76
    if name == 'Scar':  # slash over the right eye (viewer's left) with stitches
        a, b = (ex - 30, ey - 52), (ex + 26, ey + 46)
        d.line([(S(a[0]), S(a[1])), (S(b[0]), S(b[1]))], fill=(176, 72, 80, 255), width=S(7))
        for k in range(1, 5):
            t = k / 5
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            d.line([(S(x - 9), S(y + 4)), (S(x + 9), S(y - 4))], fill=(90, 40, 46, 255), width=S(3))
    elif name == 'Stubble':
        import random
        rnd = random.Random(3)
        for _ in range(90):
            x, y = rnd.uniform(FW * 0.18, FW * 0.82), rnd.uniform(FW * 0.72, FW * 0.97)
            if abs(x - mx) < 26 and abs(y - my) < 12:
                continue  # keep the mouth clear
            d.ellipse([S(x - 1.6), S(y - 1.6), S(x + 1.6), S(y + 1.6)], fill=(40, 30, 30, 120))
    elif name == 'ClownPaint':
        for cx in (ex, FW - ex):
            d.polygon([(S(cx), S(ey - 62)), (S(cx + 9), S(ey - 40)), (S(cx), S(ey - 30)), (S(cx - 9), S(ey - 40))], fill=(60, 110, 230, 255))
            d.polygon([(S(cx), S(ey + 30)), (S(cx + 9), S(ey + 42)), (S(cx), S(ey + 62)), (S(cx - 9), S(ey + 42))], fill=(60, 110, 230, 255))
            d.ellipse([S(cx - 16), S(ey + 52), S(cx + 16), S(ey + 76)], fill=(255, 110, 140, 200))
    elif name == 'WarPaint':
        for cx, m in ((ex, -1), (FW - ex, 1)):
            for k in range(2):
                y = ey + 40 + k * 13
                d.line([(S(cx - 22), S(y)), (S(cx + 22), S(y - 6 * m * 0))], fill=(200, 40, 40, 235), width=S(6))
    elif name == 'Gills':
        for cx, m in ((FW * 0.1, 1), (FW * 0.9, -1)):
            for k in range(3):
                y = ey + 34 + k * 14
                d.line(ellipse_pts(cx, y, 14, 9, 270 - 60 * m, 270 + 60 * m, 16), fill=(40, 60, 90, 220), width=S(4))
    elif name == 'Whiskers':
        for cx, m in ((FW * 0.2, -1), (FW * 0.8, 1)):
            for k in range(3):
                y = my - 18 + k * 10
                d.line([(S(cx - 20 * m), S(y)), (S(cx + 16 * m), S(y - 8 + k * 8))], fill=(40, 30, 40, 220), width=S(3))
    down(img, FW, FW).save(os.path.join(OUT, f'mark{name}.png'))


MARKS = ['Scar', 'Stubble', 'ClownPaint', 'WarPaint', 'Gills', 'Whiskers']


MOUTHS = [('Smile', 'smile'), ('Grin', 'grin'), ('Smirk', 'smirk'), ('Open', 'o'), ('Flat', 'flat'), ('Frown', 'frown'),
          ('Cat', 'cat'), ('Fang', 'fang'), ('Shout', 'shout'), ('Tongue', 'tongue'), ('Small Smile', 'small'),
          ('Nervous', 'wavy'), ('Toothy', 'toothy'), ('Pout', 'pout'), ('Laugh', 'laugh'), ('Clench', 'clench'),
          ('Happy', 'open_smile'), ('Snarl', 'snarl'), ('Scowl', 'scowl'), ('Painted', 'painted')]


def preview():
    cols = 5
    rows = math.ceil(len(EYES) / cols) + math.ceil(len(MOUTHS) / cols)
    sheet = Image.new('RGBA', (cols * 260, rows * 150), (246, 210, 180, 255))
    tints = [((90, 170, 255), (40, 70, 200)), ((255, 120, 60), (180, 40, 30)), ((90, 220, 120), (20, 110, 70))]
    for i, _ in enumerate(EYES, 1):
        c1, c2 = tints[i % 3]
        x, y = ((i - 1) % cols) * 260, ((i - 1) // cols) * 150
        tile = Image.new('RGBA', (EW, EH), (0, 0, 0, 0))
        for name, tint in (('white', None), ('iris', c1), ('iris2', c2), ('over', None)):
            l = Image.open(os.path.join(OUT, f'eye{i}_{name}.png'))
            if tint:
                solid = Image.new('RGBA', l.size, tint + (255,))
                solid.putalpha(l.getchannel('A'))
                l = solid
            tile = Image.alpha_composite(tile, l)
        sheet.alpha_composite(tile.resize((250, 125)), (x + 5, y + 10))
    base = math.ceil(len(EYES) / cols)
    for i, _ in enumerate(MOUTHS, 1):
        x, y = ((i - 1) % cols) * 260, (base + (i - 1) // cols) * 150
        sheet.alpha_composite(Image.open(os.path.join(OUT, f'mouth{i}.png')), (x + 2, y + 10))
    sheet.save(os.path.join(OUT, '..', 'faces_preview.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    for i, st in enumerate(EYES, 1):
        make_eyes(i, st)
    for i, (_, kind) in enumerate(MOUTHS, 1):
        make_mouth(i, kind)
    for mk in MARKS:
        make_mark(mk)
    preview()
    print('eyes', len(EYES), 'mouths', len(MOUTHS))
    print('EYE NAMES', [e['name'] for e in EYES])
    print('MOUTH NAMES', [m[0] for m in MOUTHS])
