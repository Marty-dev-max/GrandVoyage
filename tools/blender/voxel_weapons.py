"""Voxel weapons, one per class weapon type, in the same voxel style as the monsters and pets.

  python tools/blender/voxel_weapons.py -- --out assets/models3d --preview [--only Wep_Sword]
then upload with tools/upload_models.py (names Wep_<WeaponType>); AssetService loads them into Assets.Weapons/<WeaponType>
and WeaponService straps them to the hands (or shins) while the player fights.
Conventions (Grid: x right, -y forward, z up): the striking end points -Y (the hand's forward), the handle is at +Y;
AssetService puts the pivot on the grip (Config in AssetService.WEAPONS).
"""
import math, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401
import gvkit as K
import voxel as V
from voxel import Grid
from voxel_monsters import Painter, rgb, shade, WHITE, BLACK

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = os.path.abspath(arg("--out", "assets/models3d"))
ONLY = set(filter(None, arg("--only", "").split(",")))
PREVIEW = "--preview" in argv

STEEL = rgb(190, 200, 215)
EDGE = rgb(238, 244, 252)
GOLD = rgb(255, 200, 60)
BRASS = rgb(214, 160, 70)
WOOD = rgb(150, 96, 56)
DARKWOOD = rgb(96, 60, 38)
LEATHER = rgb(120, 70, 44)
RED = rgb(214, 54, 54)
IRON = rgb(80, 86, 100)
BLUE = rgb(90, 190, 255)
ORANGE = rgb(255, 140, 40)


def sword():
    # a pirate cutlass: wide curved blade, gold basket guard, wrapped grip
    g = Grid(18, 64, 14)
    P = Painter(g)
    cx, cz = 9, 7
    for i in range(40):
        y = 5 + i
        bend = 2.2 * (1 - i / 40) ** 2  # the tip curves up
        w = 1.4 + 1.2 * (i / 40)
        P.box((cx, y, cz + bend), (0.9, 0.6, w), STEEL, 0.015)
        P.box((cx, y, cz + bend - w), (0.7, 0.6, 0.7), EDGE, 0.0)  # bright cutting edge
    P.box((cx, 3.5, cz + 2.4), (0.8, 1.6, 1.0), EDGE, 0.0)  # tip
    P.rbox((cx, 46, cz), (6.5, 1.2, 2.2), GOLD, r=1.0, n=0.02)  # guard
    P.tube([(cx + 5.5, 46, cz - 1), (cx + 6, 50, cz - 2.5), (cx + 3, 56, cz - 3)], [0.8, 0.8, 0.8], GOLD)  # knuckle bow
    for i in range(8):
        P.box((cx, 48 + i, cz), (1.3, 0.5, 1.3), LEATHER if i % 2 else shade(LEATHER, 0.8), 0.02)
    P.ball((cx, 57.5, cz), 1.9, GOLD, 0.02)  # pommel
    g.bake_ao(0.3)
    return g


def hammer():
    # shipwright's mallet: long handle, big wooden head with iron bands, nails
    g = Grid(20, 64, 24)
    P = Painter(g)
    cx, cz = 10, 12
    P.tube([(cx, 14, cz), (cx, 60, cz)], [1.3, 1.5], WOOD)
    for y in (52, 56, 59):
        P.box((cx, y, cz), (1.8, 0.6, 1.8), LEATHER, 0.02)  # grip wraps
    P.rbox((cx, 8, cz), (6, 6.5, 10), DARKWOOD, r=1.5)  # head (long up/down: it swings in that plane)
    for z in (cz - 7, cz + 7):
        P.box((cx, 8, z), (6.4, 6.9, 1.0), IRON, 0.02)  # iron bands
    for sx in (-1, 1):
        for z in (cz - 3, cz + 3):
            P.box((cx + sx * 6.2, 8, z), (0.5, 0.8, 0.8), STEEL, 0.0)  # nail heads
    g.bake_ao(0.35)
    return g


def baton():
    # navigator's storm baton: wooden staff, brass compass ring, glowing storm crystal
    g = Grid(20, 70, 20)
    P = Painter(g)
    cx, cz = 10, 10
    P.tube([(cx, 14, cz), (cx, 66, cz)], [1.1, 1.3], DARKWOOD)
    for y in (16, 40, 64):
        P.box((cx, y, cz), (1.6, 0.8, 1.6), BRASS, 0.02)
    # compass ring around the crystal (in the x-y plane... seen from the side it is a ring)
    ring = g.d_tube([(cx + 6 * math.cos(a), 8 + 6 * math.sin(a), cz) for a in np.linspace(0, 2 * math.pi, 25)], [0.9] * 25)[0]
    g.add(ring, P.col(BRASS, 0.02))
    P.ell((cx, 8, cz), (2.6, 3.4, 2.6), BLUE, 0.04)
    P.box((cx, 8, cz), (0.6, 4.5, 0.6), EDGE, 0.0)  # bright crystal core
    g.bake_ao(0.25)
    return g


def slingshot():
    # forked wooden slingshot with a red band
    g = Grid(26, 40, 12)
    P = Painter(g)
    cx, cz = 13, 6
    P.tube([(cx, 38, cz), (cx, 20, cz)], [1.6, 1.8], WOOD)
    for sx in (-1, 1):
        P.tube([(cx, 21, cz), (cx + sx * 4, 15, cz), (cx + sx * 7, 5, cz)], [1.7, 1.4, 1.2], WOOD)
    P.tube([(cx - 7, 4, cz), (cx, 9, cz), (cx + 7, 4, cz)], [0.55, 0.9, 0.55], RED)  # band + pouch
    for y in (29, 33):
        P.box((cx, y, cz), (2.1, 0.6, 2.1), LEATHER, 0.02)
    g.bake_ao(0.3)
    return g


def knuckles():
    # a padded fighting glove with a brass knuckle plate on the punching face (-z = the fist's front when punching)
    g = Grid(24, 24, 18)
    P = Painter(g)
    P.rbox((12, 12, 10), (9, 9, 6), RED, r=2.5, n=0.02)
    P.box((12, 12, 15.5), (9.5, 9.5, 1.2), WHITE, 0.0)  # cuff
    P.rbox((12, 12, 3.6), (8.5, 6, 1.8), BRASS, r=1.0, n=0.02)
    for x in (6.5, 10.2, 13.8, 17.5):
        P.ball((x, 12, 1.8), 1.6, GOLD, 0.0)  # knuckle studs
    g.bake_ao(0.3)
    return g


def shoes():
    # sea cook's kicking greave: a shin guard with a flame stripe (front = -y), strapped around the lower leg
    g = Grid(24, 24, 28)
    P = Painter(g)
    shell = g.d_box((12, 12, 14), (9, 9, 12)) - 1.5
    hole = g.d_box((12, 12, 14), (7.4, 7.4, 13))
    g.add(np.maximum(shell, -hole), P.col(IRON, 0.02))
    P.rbox((12, 3.5, 14), (8.5, 1.6, 12), STEEL, r=1.0, n=0.015)  # front plate
    flame = lambda m: np.where(((g.P[..., 2] + 2.5 * np.sin(g.P[..., 0] * 0.9)) % 9 < 4)[..., None], np.array(ORANGE), np.array(shade(ORANGE, 0.75)))
    g.add(g.d_box((12, 2.0, 9), (6, 0.6, 5)), flame)
    for z in (5, 23):
        P.box((12, 12, z), (9.6, 9.6, 1.0), LEATHER, 0.02)  # straps
    g.bake_ao(0.3)
    return g


def medkit():
    # doctor's kit: white case with a red cross and a leather handle on top
    g = Grid(26, 18, 26)
    P = Painter(g)
    P.rbox((13, 9, 11), (11, 7, 9), WHITE, r=1.5, n=0.015)
    for sy in (1.5, 16.5):
        P.box((13, sy, 11), (2, 0.8, 6.5), RED, 0.0)
        P.box((13, sy, 11), (6.5, 0.8, 2), RED, 0.0)
    P.tube([(8, 9, 20), (9, 9, 24), (17, 9, 24), (18, 9, 20)], [1.0, 1.0, 1.0, 1.0], LEATHER)
    P.box((13, 9, 18.5), (11.4, 7.4, 0.7), shade(WHITE, 0.85), 0.0)  # lid seam
    g.bake_ao(0.3)
    return g


WEAPONS = {
    "Wep_Sword": sword, "Wep_Hammer": hammer, "Wep_StormBaton": baton, "Wep_Slingshot": slingshot,
    "Wep_Knuckles": knuckles, "Wep_Shoes": shoes, "Wep_MedKit": medkit,
}


def main():
    os.makedirs(os.path.join(OUT, "preview"), exist_ok=True)
    for name, fn in WEAPONS.items():
        if ONLY and name not in ONLY:
            continue
        K.reset()
        obj = V.mesh_grid(fn(), name, 0.2)
        K.export_glb(obj, os.path.join(OUT, name + ".glb"))
        if PREVIEW:
            V.preview(obj, os.path.join(OUT, "preview", name + ".png"), 384)
        print("WEAPON", name)


if __name__ == "__main__":
    main()
