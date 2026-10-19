"""Hangar scene art: a backdrop plus one transparent full-canvas layer per
upgrade stage, so the Hangar screen just stacks them (no positioning data).
Pixel art at 240x150 with the chunky dark outline, then the HD pass (2x).

usage: python3 tools/gen_hangar_art.py   (from game/)
Writes assets/sprites/hangar/<layer>.png. Layer names: backdrop, <id>_<stage>
(stage = the rank the layer appears at: 1, 3 or 5; kennel/stash/trophy stages vary).
"""
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hd_pass import hd  # noqa: E402

W, H = 240, 150
OUT = "assets/sprites/hangar"
O = (24, 18, 14, 255)  # outline (hd pass keys on this)

STEEL = (92, 96, 100)
STEEL_D = (62, 64, 68)
STEEL_L = (132, 136, 138)
RUST = (150, 78, 44)
RUST_D = (104, 52, 32)
WOOD = (122, 84, 52)
WOOD_D = (88, 58, 36)
OLIVE = (92, 104, 58)
OLIVE_D = (64, 74, 40)
AMBER = (240, 180, 76)
BULB = (255, 226, 140)
RED = (206, 58, 46)
TEAL = (90, 196, 158)
BLUE = (96, 170, 236)
PURPLE = (150, 96, 196)
GREEN = (110, 200, 80)
BONE = (226, 214, 186)
CLOTH = (182, 52, 48)
CONC = (104, 92, 78)
CONC_D = (84, 74, 62)
SKY_T = (238, 156, 86)
SKY_B = (250, 206, 128)


def img():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def box(d, x0, y0, x1, y1, fill, outline=True):
    if outline:
        d.rectangle((x0 - 1, y0 - 1, x1 + 1, y1 + 1), fill=O)
    d.rectangle((x0, y0, x1, y1), fill=fill + (255,) if len(fill) == 3 else fill)


def px(d, x, y, c):
    d.point((x, y), fill=c + (255,) if len(c) == 3 else c)


def line(d, pts, c, w=1):
    d.line(pts, fill=c + (255,) if len(c) == 3 else c, width=w)


def oline(d, pts, c, w=1):
    d.line(pts, fill=O, width=w + 2)
    line(d, pts, c, w)


def disc(d, cx, cy, r, c):
    d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=O)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c + (255,))


# ---------------------------------------------------------------- backdrop
def backdrop():
    im = img()
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    # back wall (corrugated)
    d.rectangle((0, 30, W, 96), fill=STEEL_D + (255,))
    for x in range(0, W, 4):
        line(d, [(x, 30), (x, 96)], (74, 76, 80))
        line(d, [(x + 1, 30), (x + 1, 96)], (54, 56, 60))
    # rust streaks
    for _ in range(26):
        x = rnd.randrange(0, W)
        y = rnd.randrange(34, 70)
        line(d, [(x, y), (x, y + rnd.randrange(6, 22))], RUST_D)
    # arched roof trusses
    d.rectangle((0, 0, W, 30), fill=(46, 44, 46, 255))
    for x in range(0, W, 3):
        line(d, [(x, 0), (x, 30)], (56, 54, 56))
    for k in range(5):
        y = 6 + k * 6
        line(d, [(0, y), (W, y)], (34, 30, 30))
    for x in (0, 60, 120, 180, 239):
        line(d, [(x, 0), (x, 34)], (30, 26, 24), 2)
    # roof holes (patched later by the Generator layers)
    for hx, hy, hw in ((34, 8, 10), (150, 4, 14), (204, 12, 8)):
        d.rectangle((hx, hy, hx + hw, hy + 4), fill=SKY_T + (255,))
    # big doorway with the dusty sky + dunes
    d.rectangle((99, 63, 141, 96), fill=O)
    for y in range(64, 96):
        t = (y - 64) / 32.0
        c = tuple(int(SKY_T[i] * (1 - t) + SKY_B[i] * t) for i in range(3))
        line(d, [(100, y), (140, y)], c)
    d.polygon([(100, 88), (112, 82), (124, 86), (134, 80), (140, 84), (140, 96), (100, 96)], fill=(196, 140, 88, 255))
    d.polygon([(100, 92), (118, 88), (140, 91), (140, 96), (100, 96)], fill=(170, 116, 72, 255))
    # sliding door leaves
    for x0 in (88, 141):
        d.rectangle((x0, 60, x0 + 10, 96), fill=RUST_D + (255,))
        for y in range(62, 96, 5):
            line(d, [(x0, y), (x0 + 10, y)], RUST)
    # floor (concrete, oil stains, cracks)
    d.rectangle((0, 96, W, H), fill=CONC + (255,))
    for y in range(98, H, 9):
        line(d, [(0, y), (W, y)], CONC_D)
    for _ in range(8):
        cx, cy = rnd.randrange(10, W - 10), rnd.randrange(104, H - 4)
        d.ellipse((cx - 7, cy - 2, cx + 7, cy + 2), fill=(70, 60, 52, 255))
    for _ in range(40):
        px(d, rnd.randrange(0, W), rnd.randrange(97, H), (120, 108, 92))
    # wall/floor seam
    line(d, [(0, 96), (W, 96)], (40, 34, 30), 2)
    return im


# ---------------------------------------------------------------- shared
def generator(stage):
    im = img()
    d = ImageDraw.Draw(im)
    if stage == 1:  # chugging generator, bottom-left
        box(d, 8, 112, 42, 136, OLIVE)
        box(d, 10, 114, 26, 126, OLIVE_D)
        box(d, 30, 116, 40, 132, STEEL)
        disc(d, 35, 124, 3, AMBER)
        box(d, 12, 104, 16, 111, STEEL_D)  # exhaust
        for i, (x, y) in enumerate(((14, 100), (16, 96), (13, 92))):
            px(d, x, y, (140, 130, 120))
        box(d, 6, 137, 44, 139, RUST_D)
        oline(d, [(42, 128), (60, 128), (60, 100), (66, 96)], (40, 40, 40))  # cable to the wall
    elif stage == 3:  # string lights across the roof
        for x in range(4, W, 12):
            y = 24 + int(4 * abs(((x % 48) - 24) / 24.0))
            px(d, x, y, (40, 36, 30))
        line(d, [(0, 24), (24, 28), (48, 24), (72, 28), (96, 24), (120, 28), (144, 24), (168, 28), (192, 24), (216, 28), (240, 24)], (40, 36, 30))
        for x in range(6, W, 12):
            yy = 26 + (2 if (x // 24) % 2 == 0 else 0)
            disc(d, x, yy + 2, 1, BULB)
    elif stage == 5:  # roof patched + floodlights
        for hx, hy, hw in ((34, 8, 10), (150, 4, 14), (204, 12, 8)):
            box(d, hx - 1, hy - 1, hx + hw + 1, hy + 5, RUST)
            for k in range(hx, hx + hw, 3):
                px(d, k, hy + 1, RUST_D)
        for fx in (60, 180):
            box(d, fx - 5, 31, fx + 5, 37, STEEL_L)
            box(d, fx - 3, 37, fx + 3, 39, BULB)
    return im


def radio_tower(stage):
    im = img()
    d = ImageDraw.Draw(im)
    if stage == 1:  # radio desk, bottom-right
        box(d, 206, 120, 236, 124, WOOD)
        box(d, 208, 125, 210, 138, WOOD_D)
        box(d, 232, 125, 234, 138, WOOD_D)
        box(d, 212, 110, 230, 119, STEEL)
        disc(d, 217, 114, 2, AMBER)
        box(d, 222, 112, 228, 116, (40, 60, 40))
        oline(d, [(229, 110), (232, 98)], STEEL_L)
    elif stage == 3:  # mast through the roof
        oline(d, [(226, 110), (226, 2)], STEEL_L, 1)
        for y in range(8, 108, 8):
            oline(d, [(222, y), (230, y + 6)], STEEL)
        box(d, 222, 0, 230, 2, STEEL)
    elif stage == 5:  # dish + blinking light
        d.pieslice((206, 4, 224, 22), 100, 280, fill=O)
        d.pieslice((207, 5, 223, 21), 100, 280, fill=STEEL_L + (255,))
        oline(d, [(215, 13), (226, 13)], STEEL)
        disc(d, 226, 1, 2, RED)
    return im


def scrap_press(stage):
    im = img()
    d = ImageDraw.Draw(im)
    if stage == 1:  # junk pile
        rnd = random.Random(3)
        for _ in range(16):
            x, y = rnd.randrange(54, 92), rnd.randrange(124, 140)
            c = rnd.choice([STEEL, RUST, STEEL_D, RUST_D, WOOD])
            box(d, x, y, x + rnd.randrange(3, 7), y + rnd.randrange(2, 4), c)
    elif stage == 3:  # the press
        box(d, 60, 100, 64, 132, STEEL_D)
        box(d, 84, 100, 88, 132, STEEL_D)
        box(d, 58, 96, 90, 101, RUST)
        box(d, 66, 104, 82, 110, STEEL_L)
        box(d, 72, 101, 76, 104, STEEL)
        box(d, 64, 128, 86, 132, STEEL)
    elif stage == 5:  # crushed cubes stacked
        for (x, y) in ((92, 130), (92, 122), (100, 130)):
            box(d, x - 4, y - 4, x + 4, y + 4, (128, 110, 92))
            line(d, [(x - 3, y - 1), (x + 3, y - 1)], RUST_D)
            line(d, [(x - 3, y + 2), (x + 3, y + 2)], STEEL_D)
    return im


def ammo_bench(stage):
    im = img()
    d = ImageDraw.Draw(im)
    if stage == 1:  # workbench
        box(d, 148, 116, 194, 120, WOOD)
        box(d, 150, 121, 153, 138, WOOD_D)
        box(d, 189, 121, 192, 138, WOOD_D)
        box(d, 156, 110, 166, 115, STEEL)
        box(d, 172, 112, 176, 115, AMBER)
        box(d, 180, 111, 184, 115, AMBER)
    elif stage == 3:  # crates under it
        box(d, 156, 126, 170, 138, OLIVE)
        line(d, [(157, 131), (169, 131)], OLIVE_D)
        box(d, 172, 128, 186, 138, OLIVE_D)
        px(d, 179, 132, AMBER)
    elif stage == 5:  # shelf of coloured cans over the bench
        box(d, 150, 104, 192, 105, WOOD)
        for i, c in enumerate((RED, BLUE, (240, 120, 40), (180, 230, 255), RED, BLUE)):
            box(d, 152 + i * 7, 98, 156 + i * 7, 103, c)
    return im


# ---------------------------------------------------------------- stations
# 8 booths on the back wall: four left of the door, four right of it.
BOOTHS = [2, 24, 46, 68, 150, 172, 194, 216]  # x of each 20-px booth
HEROES = ["ash_rook", "vesper_thorn", "pebble", "bolt_juno", "sister_cinder", "quill_marrow", "nyx_caldera", "helm_wisp"]
BY = 94  # booth floor line


def station(hero, stage):
    im = img()
    d = ImageDraw.Draw(im)
    x = BOOTHS[HEROES.index(hero)]
    m = x + 10  # middle
    if stage == 1:  # every corner starts with a crate/table + a nameplate stripe
        box(d, x + 2, BY - 8, x + 18, BY - 1, WOOD)
        line(d, [(x + 3, BY - 5), (x + 17, BY - 5)], WOOD_D)
    if hero == "ash_rook":
        if stage == 1:
            box(d, x + 4, BY - 22, x + 16, BY - 20, WOOD_D)  # rack
            oline(d, [(x + 4, BY - 14), (x + 16, BY - 14)], RUST, 2)  # launcher
        elif stage == 3:
            for i in range(3):
                box(d, x + 4 + i * 4, BY - 12, x + 6 + i * 4, BY - 9, AMBER)
        elif stage == 5:
            for k in range(0, 20, 4):
                line(d, [(x + k, BY - 30), (x + k + 2, BY - 28)], AMBER)
            oline(d, [(x + 4, BY - 25), (x + 16, BY - 25)], STEEL, 2)
    elif hero == "vesper_thorn":
        if stage == 1:
            oline(d, [(x + 3, BY - 12), (x + 17, BY - 16)], WOOD_D)
            oline(d, [(x + 8, BY - 14), (x + 14, BY - 16)], STEEL_L)
        elif stage == 3:
            d.pieslice((m - 4, BY - 30, m + 4, BY - 20), 180, 360, fill=O)
            box(d, m - 3, BY - 25, m + 3, BY - 21, AMBER)
            px(d, m, BY - 20, AMBER)
        elif stage == 5:
            for i, c in enumerate((PURPLE, GREEN, PURPLE)):
                box(d, x + 3 + i * 6, BY - 17, x + 5 + i * 6, BY - 12, c)
    elif hero == "pebble":
        if stage == 1:
            box(d, m - 5, BY - 13, m + 5, BY - 10, STEEL_D)  # anvil
            box(d, m - 2, BY - 10, m + 2, BY - 9, STEEL_D)
        elif stage == 3:
            oline(d, [(m + 3, BY - 13), (m + 7, BY - 24)], WOOD)
            box(d, m + 4, BY - 28, m + 11, BY - 24, STEEL)
        elif stage == 5:
            for (bx, by) in ((x + 2, BY - 15), (x + 2, BY - 21)):
                box(d, bx, by, bx + 5, by + 4, (150, 140, 128))
    elif hero == "bolt_juno":
        if stage == 1:
            disc(d, m - 3, BY - 12, 3, (196, 120, 60))
            oline(d, [(m, BY - 12), (m + 6, BY - 12)], STEEL)
        elif stage == 3:
            oline(d, [(x + 2, BY - 30), (x + 8, BY - 22), (x + 14, BY - 28), (x + 19, BY - 20)], (40, 40, 40))
            for (sx, sy) in ((x + 8, BY - 21), (x + 14, BY - 27)):
                px(d, sx, sy, BLUE)
        elif stage == 5:
            box(d, x + 13, BY - 20, x + 18, BY - 9, STEEL)
            box(d, x + 14, BY - 18, x + 17, BY - 14, BLUE)
    elif hero == "sister_cinder":
        if stage == 1:
            for i, c in enumerate((GREEN, BONE, TEAL)):
                box(d, x + 4 + i * 5, BY - 13, x + 6 + i * 5, BY - 9, c)
        elif stage == 3:
            box(d, m - 4, BY - 32, m + 4, BY - 18, BONE)
            box(d, m - 1, BY - 30, m + 1, BY - 20, CLOTH)
            box(d, m - 3, BY - 27, m + 3, BY - 25, CLOTH)
        elif stage == 5:
            d.pieslice((x + 2, BY - 14, x + 12, BY - 2), 0, 180, fill=O)
            d.pieslice((x + 3, BY - 13, x + 11, BY - 3), 0, 180, fill=(48, 44, 40, 255))
            line(d, [(x + 4, BY - 8), (x + 10, BY - 8)], GREEN)
    elif hero == "quill_marrow":
        if stage == 1:
            box(d, x + 3, BY - 10, x + 17, BY - 9, BONE)
        elif stage == 3:
            for i in range(3):
                box(d, x + 3 + i * 5, BY - 15, x + 6 + i * 5, BY - 10, (120, 170, 140))
        elif stage == 5:
            box(d, x + 3, BY - 32, x + 17, BY - 19, WOOD_D)
            for (px_, py_) in ((x + 5, BY - 30), (x + 11, BY - 29), (x + 6, BY - 24), (x + 12, BY - 23)):
                box(d, px_, py_, px_ + 3, py_ + 3, BONE)
    elif hero == "nyx_caldera":
        if stage == 1:
            box(d, x + 10, BY - 15, x + 18, BY - 9, (70, 60, 80))
        elif stage == 3:
            oline(d, [(m - 6, BY - 30), (m + 6, BY - 18)], STEEL_L)
            oline(d, [(m + 6, BY - 30), (m - 6, BY - 18)], STEEL_L)
        elif stage == 5:
            box(d, x + 2, BY - 16, x + 6, BY - 10, AMBER)
            box(d, x + 3, BY - 18, x + 5, BY - 17, STEEL_D)
    elif hero == "helm_wisp":
        if stage == 1:
            box(d, m - 4, BY - 13, m + 4, BY - 10, STEEL)
            line(d, [(m - 7, BY - 14), (m + 7, BY - 14)], STEEL_L)
        elif stage == 3:
            box(d, x + 2, BY - 26, x + 8, BY - 23, STEEL)
            line(d, [(x, BY - 27), (x + 10, BY - 27)], STEEL_L)
            px(d, x + 5, BY - 22, TEAL)
        elif stage == 5:
            oline(d, [(m - 8, BY - 34), (m + 8, BY - 30)], WOOD)
            disc(d, m, BY - 32, 1, STEEL)
    return im


# ---------------------------------------------------------------- kennel, stash, trophies
def kennel(pet, stage):
    im = img()
    d = ImageDraw.Draw(im)
    x = {"noel": 100, "bentley": 114, "lillie": 128}[pet]
    col = {"noel": (120, 124, 132), "bentley": (226, 206, 160), "lillie": (204, 120, 64)}[pet]
    if stage == 1:  # dog bed
        d.ellipse((x - 1, 135, x + 13, 145), fill=O)
        d.ellipse((x, 136, x + 12, 144), fill=col + (255,))
        d.ellipse((x + 3, 138, x + 9, 142), fill=tuple(int(c * 0.7) for c in col) + (255,))
    elif stage == 2:  # bowl
        box(d, x + 3, 130, x + 9, 132, STEEL_L)
        line(d, [(x + 4, 130), (x + 8, 130)], WOOD)
    elif stage == 3:  # name plank
        box(d, x + 1, 120, x + 11, 125, WOOD)
        line(d, [(x + 3, 122), (x + 9, 122)], BONE)
    return im


def stash(stage):
    im = img()
    d = ImageDraw.Draw(im)
    if stage == 0:  # the lockbox (always there)
        box(d, 104, 102, 136, 114, OLIVE_D)
        box(d, 104, 102, 136, 104, OLIVE)
        box(d, 118, 106, 122, 110, AMBER)
    else:  # extra lockers
        x = 82 + stage * 0  # stacks above the box
        y = 102 - stage * 7
        box(d, 108, y - 1, 132, y + 4, (80, 90, 64))
        px(d, 120, y + 1, AMBER)
    return im


def trophy(boss):
    im = img()
    d = ImageDraw.Draw(im)
    if boss == "wall":  # empty trophy board above the door
        box(d, 100, 40, 140, 58, WOOD_D)
        for k in range(104, 140, 6):
            line(d, [(k, 40), (k, 58)], WOOD)
    elif boss == "dread_naught":
        box(d, 104, 44, 116, 54, STEEL)
        box(d, 107, 47, 109, 49, RED)
        box(d, 111, 47, 113, 49, RED)
    elif boss == "mutant_overlord":
        disc(d, 130, 49, 5, (140, 170, 90))
        px(d, 128, 48, (250, 240, 120))
        px(d, 132, 48, (250, 240, 120))
    return im


LAYERS = {"backdrop": backdrop}
for s in (1, 3, 5):
    LAYERS["generator_%d" % s] = (lambda s=s: generator(s))
    LAYERS["radio_tower_%d" % s] = (lambda s=s: radio_tower(s))
    LAYERS["scrap_press_%d" % s] = (lambda s=s: scrap_press(s))
    LAYERS["ammo_bench_%d" % s] = (lambda s=s: ammo_bench(s))
    for h in HEROES:
        LAYERS["station_%s_%d" % (h, s)] = (lambda h=h, s=s: station(h, s))
for p in ("noel", "bentley", "lillie"):
    for s in (1, 2, 3):
        LAYERS["kennel_%s_%d" % (p, s)] = (lambda p=p, s=s: kennel(p, s))
for s in (0, 1, 2, 3):
    LAYERS["stash_%d" % s] = (lambda s=s: stash(s))
for b in ("wall", "dread_naught", "mutant_overlord"):
    LAYERS["trophy_%s" % b] = (lambda b=b: trophy(b))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in LAYERS.items():
        hd(fn()).save(os.path.join(OUT, name + ".png"))
    print(len(LAYERS), "hangar layers ->", OUT)
