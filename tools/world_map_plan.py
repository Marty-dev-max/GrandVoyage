# Draws docs/screenshots/world_map_plan.png: the proposed world layout (owner ref: a world map with four seas around
# a cross of cliffs and a belt across the middle). Coordinates are world studs with the mountain at (0, 0),
# north = -Z (up in the picture). Run: Blender's python with PYTHONPATH=%LOCALAPPDATA%\gv-pylib (PIL).
import math
import random
from PIL import Image, ImageDraw, ImageFont

HX, HZ = 18000, 12500          # world half size
K = 0.05                        # px per stud
W, H = int(HX * 2 * K), int(HZ * 2 * K)
WALL = 300                      # half thickness of the middle wall
BAND = 1500                     # half width of the Grand Current
BELT = 800                      # Doldrums width on each side of the band
EDGE = 500                      # wall at the world edges

def px(x, z):
    return ((x + HX) * K, (z + HZ) * K)

img = Image.new("RGB", (W, H), (58, 110, 160))
d = ImageDraw.Draw(img)
try:
    F = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 30)
    Fm = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 20)
    Fs = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
except OSError:
    F = Fm = Fs = ImageFont.load_default()

# belts + band
d.rectangle([px(-HX, -BAND - BELT), px(HX, BAND + BELT)], fill=(120, 175, 215))
d.rectangle([px(-HX, -BAND), px(HX, BAND)], fill=(44, 92, 150))

# jagged wall strips
rnd = random.Random(7)
def wall_poly(x0, x1, z0, z1, vertical=True, jag=260):
    pts = []
    n = 60
    if vertical:
        for i in range(n + 1):
            z = z0 + (z1 - z0) * i / n
            pts.append(px(x0 - rnd.uniform(0, jag), z))
        for i in range(n, -1, -1):
            z = z0 + (z1 - z0) * i / n
            pts.append(px(x1 + rnd.uniform(0, jag), z))
    else:
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            pts.append(px(x, z0 - rnd.uniform(0, jag)))
        for i in range(n, -1, -1):
            x = x0 + (x1 - x0) * i / n
            pts.append(px(x, z1 + rnd.uniform(0, jag)))
    d.polygon(pts, fill=(172, 40, 38))

wall_poly(-WALL, WALL, -HZ, -BAND - BELT, True, 500)
wall_poly(-WALL, WALL, BAND + BELT, HZ, True, 500)
wall_poly(HX - EDGE, HX, -HZ, HZ, True, 200)
wall_poly(-HX, -HX + EDGE, -HZ, HZ, True, 200)
wall_poly(-HX, HX, -HZ, -HZ + EDGE, False, 200)
wall_poly(-HX, HX, HZ - EDGE, HZ, False, 200)
# the mountain in the middle of the cross
d.ellipse([px(-900, -900), px(900, 900)], fill=(150, 34, 34), outline=(240, 220, 200), width=3)
# canals: the one from the Azure East (NE) climbs to the summit, the way down runs east into the band
d.line([px(1800, -BAND - BELT - 900), px(0, 0)], fill=(150, 220, 255), width=7)
d.line([px(0, 0), px(1200, 0)], fill=(150, 220, 255), width=7)
for (dx, dz) in ((-1800, -BAND - BELT - 900), (-1800, BAND + BELT + 900), (1800, BAND + BELT + 900)):
    d.line([px(dx, dz), px(0, 0)], fill=(110, 150, 180), width=4)

def label(x, z, text, font, fill=(255, 255, 255), anchor="mm"):
    d.text(px(x, z), text, font=font, fill=fill, anchor=anchor, stroke_width=3, stroke_fill=(20, 30, 50))

# sea names
label(9200, -11200, "SEA 1  AZURE EAST  (Lv 1-70)", F, (255, 236, 140))
label(-9200, -11200, "AZURE NORTH  (closed, later)", Fm, (200, 215, 230))
label(-9200, 11200, "AZURE WEST  (closed, later)", Fm, (200, 215, 230))
label(9200, 11200, "AZURE SOUTH  (closed, later)", Fm, (200, 215, 230))
label(9200, 0, "SEA 2  GRAND CURRENT  (Lv 70+)  ->", F, (255, 236, 140))
label(-9200, 0, "SEA 3  (new name)  ->", F, (255, 236, 140))
label(9200, -BAND - BELT / 2, "DOLDRUMS  (no wind, Leviathans)", Fs, (30, 60, 90))
label(9200, BAND + BELT / 2, "DOLDRUMS", Fs, (30, 60, 90))
label(-9200, -BAND - BELT / 2, "DOLDRUMS", Fs, (30, 60, 90))
label(-9200, BAND + BELT / 2, "DOLDRUMS", Fs, (30, 60, 90))
label(0, -6500, "CRIMSON WALL", Fm, (255, 210, 190))
label(0, 6500, "CRIMSON WALL", Fm, (255, 210, 190))
label(0, 1250, "BACKFLOW PEAK", Fm, (255, 255, 255))

# the route through the Azure East (Daybreak at the east, Epilogue by the mountain)
ROUTE = [
    ("Daybreak 1-10", 15600, -6200),
    ("Conch Bay 10-20", 13400, -8000),
    ("Marmalade 20-30", 11200, -5600),
    ("Honeyslope 30-40", 9000, -8200),
    ("Barracuda 40-50", 6800, -5400),
    ("Mikan 50-60", 4600, -7800),
    ("Epilogue 60-70", 2700, -4600),
]
pts = [px(x, z) for _, x, z in ROUTE] + [px(1800, -BAND - BELT - 900)]
for a, b in zip(pts, pts[1:]):
    ax, ay = a; bx, by = b
    n = int(math.hypot(bx - ax, by - ay) / 10)
    for i in range(0, n, 2):
        t0, t1 = i / n, min(1, (i + 1) / n)
        d.line([(ax + (bx - ax) * t0, ay + (by - ay) * t0), (ax + (bx - ax) * t1, ay + (by - ay) * t1)], fill=(235, 70, 60), width=3)
for name, x, z in ROUTE:
    cx, cy = px(x, z)
    d.ellipse([cx - 13, cy - 13, cx + 13, cy + 13], fill=(120, 190, 90), outline=(40, 70, 30), width=2)
    label(x, z - 520, name, Fs)
ORIG = [("Bastion Rock", 16900, -7100), ("Smuggler's Hollow", 17200, -6500), ("Shackle Reef", 17200, -5900), ("Inkwell Isle", 16900, -5300)]
for name, x, z in ORIG:
    cx, cy = px(x, z)
    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(200, 200, 120), outline=(70, 70, 30), width=2)
label(16300, -4300, "4 home islands", Fs, (240, 240, 180))

# the underpass: east edge of the band -> under the wall -> the west edge
d.line([px(HX - 1800, 0), px(HX - EDGE, 0)], fill=(255, 255, 255), width=3)
d.ellipse([*px(HX - 1300, -500), *px(HX - 300, 500)], outline=(255, 255, 255), width=3)
label(HX - 2400, 900, "dive under the wall", Fs)
label(HX - 2400, 1250, "(undersea city)", Fs)
d.line([px(-HX + EDGE, 0), px(-HX + 1800, 0)], fill=(255, 255, 255), width=3)
label(-HX + 2600, 900, "surface here", Fs)

img.save("docs/screenshots/world_map_plan.png")
print(W, H)
