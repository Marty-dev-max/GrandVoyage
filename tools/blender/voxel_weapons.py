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
    # guard + knuckle bow in the blade's plane (owner v0.25.102: they stuck out sideways off the flat), bow on the edge side
    P.rbox((cx, 46, cz), (2.2, 1.2, 5.5), GOLD, r=1.0, n=0.02)  # guard
    P.tube([(cx, 46, cz - 4.5), (cx, 51, cz - 5.5), (cx, 56.5, cz - 2.2)], [0.8, 0.8, 0.8], GOLD)  # knuckle bow
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
    # navigator's storm staff: three segments that lock together (brass joint rings), capped tips, no orb
    g = Grid(14, 74, 14)
    P = Painter(g)
    cx, cz = 7, 7
    seg = [(4, 26), (26, 48), (48, 70)]
    shades = [STEEL, shade(STEEL, 0.85), STEEL]
    for (a, b), col in zip(seg, shades):
        P.tube([(cx, a, cz), (cx, b, cz)], [1.3, 1.3], col)
        P.tube([(cx, a + 2, cz), (cx, b - 2, cz)], [1.45, 1.45], shade(col, 0.75))  # grip groove band
    for y in (4, 26, 48, 70):
        P.box((cx, y, cz), (2.0, 1.0, 2.0), BRASS, 0.02)  # joint rings / caps
    P.box((cx, 2.5, cz), (1.0, 1.2, 1.0), BLUE, 0.0)  # little storm-glass tip
    g.bake_ao(0.25)
    return g


def baton_pack():
    # the same staff folded up: three short segments strapped side by side (worn on the belt)
    g = Grid(20, 30, 14)
    P = Painter(g)
    for i, x in enumerate((6, 10, 14)):
        P.tube([(x, 4, 7), (x, 26, 7)], [1.4, 1.4], STEEL if i != 1 else shade(STEEL, 0.85))
        for y in (4, 26):
            P.box((x, y, 7), (1.9, 0.9, 1.9), BRASS, 0.02)
    for y in (11, 19):
        P.box((10, y, 7), (6.2, 1.1, 2.2), LEATHER, 0.02)  # straps
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
    # doctor's powder pouch: a cloth drawstring bag of medicinal powders with a herb tag (thrown in pinches)
    g = Grid(22, 22, 26)
    P = Painter(g)
    P.ell((11, 11, 9), (8, 8, 8), rgb(232, 214, 176), 0.03)            # cloth bag
    P.box((11, 11, 16.5), (5.2, 5.2, 1.4), shade(rgb(232, 214, 176), 0.8), 0.02)  # gathered neck
    P.tube([(6, 11, 16.5), (11, 4.5, 17), (16, 11, 16.5), (11, 17.5, 17), (6, 11, 16.5)], [0.7] * 5, RED)  # drawstring
    P.ell((11, 11, 19.5), (3.4, 3.4, 2.4), rgb(150, 230, 170), 0.04)   # puff of green powder at the mouth
    P.box((15.5, 4.2, 8), (2.4, 0.6, 3), rgb(120, 200, 110), 0.0)      # herb tag
    P.box((15.5, 3.8, 8), (0.6, 0.4, 1.8), WHITE, 0.0)
    g.bake_ao(0.3)
    return g


def sword_sheathed():
    # cutlass in its scabbard (worn at the left hip): leather scabbard with brass tip and mouth, hilt sticking out
    g = Grid(18, 64, 14)
    P = Painter(g)
    cx, cz = 9, 7
    P.rbox((cx, 25, cz), (1.6, 21, 3.0), DARKWOOD, r=1.0, n=0.02)
    P.box((cx, 4.5, cz), (1.9, 1.5, 3.2), BRASS, 0.02)
    P.box((cx, 45.5, cz), (1.9, 1.2, 3.2), BRASS, 0.02)
    P.rbox((cx, 47.5, cz), (2.2, 1.2, 5.5), GOLD, r=1.0, n=0.02)  # guard (in the blade's plane, see sword())
    P.tube([(cx, 47.5, cz - 4.5), (cx, 52.5, cz - 5.5), (cx, 57.5, cz - 2.2)], [0.8, 0.8, 0.8], GOLD)
    for i in range(8):
        P.box((cx, 49 + i, cz), (1.3, 0.5, 1.3), LEATHER if i % 2 else shade(LEATHER, 0.8), 0.02)
    P.ball((cx, 58.5, cz), 1.9, GOLD, 0.02)
    g.bake_ao(0.3)
    return g


def scabbard():
    # the empty scabbard (stays at the hip while the cutlass is drawn)
    g = Grid(10, 50, 12)
    P = Painter(g)
    P.rbox((5, 25, 6), (1.6, 21, 3.0), DARKWOOD, r=1.0, n=0.02)
    P.box((5, 4.5, 6), (1.9, 1.5, 3.2), BRASS, 0.02)
    P.box((5, 45.5, 6), (1.9, 1.2, 3.2), BRASS, 0.02)
    g.bake_ao(0.3)
    return g


def sling_bag():
    # sharpshooter's satchel: a round canvas bag with a flap and buckle (ammo pouch), worn at the hip on a strap
    g = Grid(30, 20, 26)
    P = Painter(g)
    tan = rgb(196, 150, 86)
    P.ell((15, 10, 11), (12, 6.5, 10), tan, 0.03)
    P.ell((15, 4.6, 15), (11.5, 2.2, 6.5), shade(tan, 0.82), 0.02)   # flap over the front
    P.box((15, 2.6, 11), (1.6, 0.8, 1.8), STEEL, 0.0)                # buckle
    P.box((15, 3.2, 13.5), (0.8, 0.8, 2.6), LEATHER, 0.0)
    for x in (4.5, 25.5):
        P.box((x, 10, 21), (1.2, 1.4, 1.6), STEEL, 0.0)              # strap rings
    g.bake_ao(0.3)
    return g


WEAPONS = {
    "Wep_Sword": sword, "Wep_Hammer": hammer, "Wep_StormBaton": baton, "Wep_Slingshot": slingshot,
    "Wep_Knuckles": knuckles, "Wep_Shoes": shoes, "Wep_MedKit": medkit,
    "Wep_StormBatonPack": baton_pack, "Wep_SwordSheathed": sword_sheathed, "Wep_Scabbard": scabbard, "Wep_SlingBag": sling_bag,
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
