"""Depth Update item art in the hangar's anime cel-shaded look (tools/celkit.py):
ingredients, tonics, medicine, backpack, plague fog and later phases' items.

usage (from game/):  python3 tools/gen_depth_art.py [group ...] [--sheet DIR]
groups: e1 e3 e4 e5 (default: all)
Writes into assets/sprites/depth/.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from celkit import (Canvas, C, cel, ink, hline, fill, soft, glow, shadow, box, bottle, pustule, sheet,  # noqa: E402
                    SPEC, INK3, fbm)

OUT = os.path.join(HERE, "..", "assets", "sprites", "depth")
ICON = os.path.join(OUT, "icons")
WORLD = os.path.join(OUT, "world")
U = 24  # icon canvas in art units
PX = 96
_made = []


def save_icon(cv, name, px=PX):
    im = cv.save(os.path.join(ICON, name + ".png"), px)
    _made.append(im)
    return im


# ------------------------------------------------------------------ palette
LEAF = C(96, 150, 70)
LEAF_D = C(64, 110, 58)
TWINE = C(176, 140, 90)
FLESH = C(150, 84, 112)
FLESH_D = C(112, 60, 92)
SICK = C(150, 196, 70)
AMBER = C(236, 168, 70)
AMBER_HI = C(255, 214, 130)
GUN = C(74, 80, 90)
STEEL = C(126, 132, 138)
YEL = C(206, 164, 64)
CREAM = C(222, 210, 184)
RED = C(178, 52, 44)
CANVAS = C(164, 146, 104)
CANVAS_D = C(120, 104, 74)
LEATHER = C(112, 72, 46)
BRASS = C(184, 140, 70)


# ================================================================== ingredients
def herb():
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 20.6, 6.5, 1.4)
    # stems
    for (a, b) in (((12, 20), (9.5, 7.5)), ((12.4, 20), (14.6, 6.5)), ((12.2, 20), (12, 5))):
        ink(L, [a, ((a[0] + b[0]) / 2 + 0.4, (a[1] + b[1]) / 2), b], 0.55, C(70, 96, 50), 1.0)
    # leaves (pairs along the stems)
    leaves = [(8.2, 9.5, -0.9), (6.8, 13.4, -0.6), (15.6, 8.8, 0.8), (17.2, 12.6, 0.5), (12.0, 5.2, 0.0),
              (10.2, 15.6, -0.4), (14.6, 15.0, 0.4)]
    for k, (x, y, rot) in enumerate(leaves):
        ca, sa = math.cos(rot), math.sin(rot)
        pts = []
        for i in range(17):  # pointed lens leaf: base at the stem, tip outward
            s_ = i / 16.0
            px_, py_ = 1.55 * math.sin(math.pi * s_) * (1 - 0.25 * s_), 3.4 - 6.8 * s_
            pts.append((x + px_ * ca - py_ * sa, y + px_ * sa + py_ * ca))
        for i in range(15, 0, -1):
            s_ = i / 16.0
            px_, py_ = -1.55 * math.sin(math.pi * s_) * (1 - 0.25 * s_), 3.4 - 6.8 * s_
            pts.append((x + px_ * ca - py_ * sa, y + px_ * sa + py_ * ca))
        cel(L, [("poly", pts)], LEAF if k % 2 == 0 else C(110, 162, 76), form="sphere", ol=1.6, bevel=1.0,
            t1=0.42, t2=0.75)
        ink(L, [(x - 3.0 * sa, y + 3.0 * ca), (x + 2.6 * sa, y - 2.6 * ca)], 0.16, LEAF_D * 0.7, 0.8)
    # red taproot + rootlets, twine tie
    cel(L, [("poly", [(10.6, 17.4), (13.8, 17.4), (13.2, 19.6), (12.4, 21.8), (11.8, 21.9), (11.2, 19.6)])],
        C(156, 74, 54), form="cylv", ol=1.6, bevel=0.8)
    for (a, b) in (((11.4, 19.4), (9.8, 21.0)), ((13.0, 19.2), (14.8, 20.8)), ((12.2, 21.6), (12.6, 22.8))):
        ink(L, [a, b], 0.18, C(120, 64, 48), 0.9)
    cel(L, [("rect", 10.4, 16.6, 14.0, 17.8)], TWINE, form="cylh", ol=1.4, bevel=0.5)
    ink(L, [(14.0, 17.2), (15.8, 18.8)], 0.3, TWINE * 0.8, 1.0)
    return save_icon(cv, "herb")


def plague_gland():
    cv = Canvas(U, U)
    L = cv.L
    glow(L, 12, 13, 8, SICK, 0.25)
    shadow(L, 12.5, 20.4, 7, 1.4)
    pts = []
    for i in range(24):
        t = i / 24 * math.pi * 2
        rr = 6.6 + 0.8 * math.sin(3 * t + 0.6) + 0.5 * math.sin(5 * t)
        pts.append((12 + math.cos(t) * rr, 12.6 + math.sin(t) * rr * 0.86))
    cel(L, [("poly", pts)], FLESH, form="sphere", ol=2.4, bevel=2.0, gloss=0.0, t1=0.36, t2=0.7)
    # veins
    for (a, b, c) in (((7.5, 9.5), (10.5, 12.0), (9.5, 16.5)), ((15.5, 8.5), (14.0, 12.0), (16.5, 15.5)),
                      ((11.0, 7.0), (12.5, 10.0), (12.0, 13.0))):
        ink(L, [a, b, c], 0.22, FLESH_D * 0.7, 0.8)
    for (x, y, r) in ((9.0, 10.5, 1.9), (14.6, 14.6, 2.3), (15.4, 9.2, 1.4), (9.8, 15.6, 1.2), (12.4, 12.4, 1.0)):
        pustule(L, x, y, r, SICK)
    # glossy wet highlight + a drip
    hline(L, [(7.4, 10.0), (8.6, 7.8), (10.8, 6.6)], 0.38, SPEC, 0.7)
    cel(L, [("poly", [(15.6, 16.6), (17.2, 16.2), (17.6, 18.6), (17.4, 20.2), (16.8, 20.8), (16.3, 20.0), (16.2, 18.2)])],
        SICK, form="cylv", ol=1.2, bevel=0.5)
    fill(L, [("ell", 16.8, 18.8, 0.22, 0.6)], SPEC, 0.8)
    return save_icon(cv, "plague_gland")


def dust_shard():
    cv = Canvas(U, U)
    L = cv.L
    glow(L, 12, 12, 9, AMBER, 0.5)
    shadow(L, 12.5, 21.0, 6.5, 1.3)
    shards = [  # (base x, base y, tip x, tip y, half width)
        (9.0, 20.5, 6.4, 9.0, 2.0), (15.0, 20.5, 18.0, 10.0, 2.0), (12.0, 21.0, 12.0, 3.6, 3.0),
        (10.2, 21.0, 9.4, 14.0, 1.4), (14.0, 21.0, 15.0, 14.6, 1.3)]
    for k, (bx, by, tx, ty, w) in enumerate(shards):
        ang = math.atan2(ty - by, tx - bx)
        nx, ny = -math.sin(ang), math.cos(ang)
        mid = (bx + (tx - bx) * 0.72, by + (ty - by) * 0.72)
        left = [(bx + nx * w, by + ny * w), (mid[0] + nx * w * 1.05, mid[1] + ny * w * 1.05), (tx, ty), (bx, by)]
        right = [(bx - nx * w, by - ny * w), (mid[0] - nx * w * 1.05, mid[1] - ny * w * 1.05), (tx, ty), (bx, by)]
        cel(L, [("poly", left)], AMBER, n=(-0.7, -0.4, 0.6), ol=1.8, bevel=0.0, line=C(110, 56, 20), rim=0.8)
        cel(L, [("poly", right)], AMBER * 0.82, n=(0.6, -0.2, 0.75), ol=1.8, bevel=0.0, line=C(110, 56, 20), rim=0.3)
        ink(L, [(bx, by), (tx, ty)], 0.18, AMBER_HI, 0.7)
    fill(L, [("ell", 11.0, 9.0, 0.5, 1.4)], SPEC, 0.9)
    fill(L, [("ell", 7.2, 12.0, 0.35, 1.0)], SPEC, 0.8)
    return save_icon(cv, "dust_shard")


def machine_oil():
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 21.2, 7.5, 1.4)
    # jerry-can body
    body = [("poly", [(5.5, 8.0), (16.5, 8.0), (18.0, 9.5), (18.0, 20.5), (5.5, 20.5)])]
    cel(L, body, GUN, form="cylv", ol=2.4, bevel=1.4, metal=0.6, rust=0.25, wear=0.4)
    # pressed X ribs
    for (a, b) in (((7.2, 10.2), (16.2, 18.8)), ((16.2, 10.2), (7.2, 18.8))):
        ink(L, [a, b], 0.36, C(40, 44, 52), 0.75)
        hline(L, [(a[0] - 0.25, a[1] - 0.3), (b[0] - 0.25, b[1] - 0.3)], 0.14, C(150, 156, 166), 0.6)
    # yellow hazard label
    cel(L, [("rect", 8.6, 12.4, 14.8, 16.4)], YEL, n=(0, 0, 1), ol=1.2, bevel=0.3, rim=0)
    fill(L, [("poly", [(11.7, 13.0), (13.0, 15.6), (10.4, 15.6)])], C(40, 34, 30), 0.95)
    # handle + spout
    cel(L, [("rect", 6.6, 5.4, 12.6, 8.2), ("-rect", 7.8, 6.4, 11.4, 8.4)], STEEL, form="cylh", ol=1.8, bevel=0.6,
        metal=0.7)
    cel(L, [("poly", [(15.0, 8.2), (16.6, 8.2), (19.6, 3.8), (18.6, 3.0)])], STEEL, form="cylv", ol=1.8, bevel=0.5,
        metal=0.8)
    cel(L, [("ell", 19.2, 3.4, 0.9, 0.7)], C(36, 36, 40), form="sphere", ol=1.2, bevel=0.4)
    # oil drip
    cel(L, [("poly", [(19.0, 4.2), (19.6, 5.6), (19.4, 7.0), (18.8, 7.2), (18.6, 5.8)])], C(40, 30, 24), form="cylv",
        ol=1.0, bevel=0.3, gloss=0.6)
    fill(L, [("ell", 19.0, 5.6, 0.18, 0.4)], SPEC, 0.9)
    return save_icon(cv, "machine_oil")


def medicine(icon=True):
    """Medicine crate: cream medkit case, red cross, straps; also the world sprite."""
    cv = Canvas(U, U)
    L = cv.L
    if not icon:
        glow(L, 12, 15, 10, C(255, 120, 100), 0.28)
    shadow(L, 12.5, 20.8, 9.5, 1.6)
    dx, dy = box(L, 3.6, 10.0, 17.4, 20.0, 5.2, CREAM, top=C(234, 224, 200), side=C(196, 184, 158), wear=0.3, rust=0.08)
    # red cross on the front
    cel(L, [("rect", 9.0, 12.0, 12.0, 18.2), ("rect", 7.4, 13.6, 13.6, 16.6)], RED, n=(0, 0, 1), ol=1.4, bevel=0.4)
    hline(L, [(9.3, 12.4), (11.6, 12.4)], 0.16, C(240, 140, 120), 0.8)
    # straps over the top + buckles
    for x in (6.0, 15.2):
        cel(L, [("poly", [(x, 10.0), (x + 1.3, 10.0), (x + 1.3 + dx, 10.0 - dy), (x + dx, 10.0 - dy)])], LEATHER,
            n=(0, -0.9, 0.4), ol=1.0, bevel=0.2)
        cel(L, [("rect", x, 10.0, x + 1.3, 20.0)], LEATHER, n=(0, 0, 1), ol=1.0, bevel=0.2)
        cel(L, [("rect", x - 0.2, 14.2, x + 1.5, 15.6)], BRASS, n=(0, 0, 1), ol=0.9, bevel=0.2, metal=0.8)
    # handle on top
    cel(L, [("poly", [(8.6 + dx * 0.5, 10 - dy * 0.5), (13.8 + dx * 0.5, 10 - dy * 0.5), (13.2 + dx * 0.5, 7.4 - dy * 0.5),
                      (9.2 + dx * 0.5, 7.4 - dy * 0.5)]),
         ("-poly", [(9.6 + dx * 0.5, 10 - dy * 0.5), (12.8 + dx * 0.5, 10 - dy * 0.5), (12.5 + dx * 0.5, 8.4 - dy * 0.5),
                    (9.9 + dx * 0.5, 8.4 - dy * 0.5)])], C(60, 58, 60), form="cylh", ol=1.6, bevel=0.4, metal=0.5)
    if icon:
        return save_icon(cv, "medicine")
    im = cv.save(os.path.join(WORLD, "medicine_crate.png"), 128)
    _made.append(im.resize((96, 96), Image.LANCZOS))
    return im


def backpack():
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 21.0, 7.5, 1.4)
    body = [("poly", [(6.0, 7.4), (18.0, 7.4), (19.0, 11.0), (18.6, 20.4), (5.4, 20.4), (5.0, 11.0)])]
    cel(L, body, CANVAS, form="cylv", ol=2.4, bevel=1.8, wear=0.3)
    # flap
    cel(L, [("poly", [(5.6, 7.0), (18.4, 7.0), (18.0, 12.6), (12.0, 14.0), (6.0, 12.6)])], CANVAS_D, form="dome",
        ol=1.8, bevel=1.2)
    # front pocket
    cel(L, [("poly", [(8.0, 15.0), (16.0, 15.0), (16.4, 19.6), (7.6, 19.6)])], CANVAS * 0.92, n=(0, -0.1, 1), ol=1.4,
        bevel=0.8)
    ink(L, [(8.4, 16.4), (15.6, 16.4)], 0.16, CANVAS_D * 0.6, 0.7)
    # straps + buckles
    for x in (8.6, 14.4):
        cel(L, [("rect", x, 11.0, x + 1.2, 16.4)], LEATHER, n=(0, 0, 1), ol=1.0, bevel=0.2)
        cel(L, [("rect", x - 0.25, 12.6, x + 1.45, 13.8)], BRASS, n=(0, 0, 1), ol=0.9, bevel=0.2, metal=0.9)
    # bedroll on top
    cel(L, [("rect", 6.4, 4.0, 17.6, 7.4)], C(118, 70, 56), form="cylh", ol=1.8, bevel=1.0)
    for x in (8.4, 15.4):
        ink(L, [(x, 4.0), (x, 7.4)], 0.32, LEATHER * 0.8, 1.0)
    hline(L, [(7.0, 4.8), (17.0, 4.8)], 0.16, C(200, 140, 120), 0.6)
    return save_icon(cv, "backpack")


def exposure():
    """Plague exposure: a cracked gas-mask filter with green spores."""
    cv = Canvas(U, U)
    L = cv.L
    glow(L, 12, 12, 9, SICK, 0.35)
    cel(L, [("ell", 12, 12, 8.4, 8.4)], C(70, 78, 70), form="sphere", ol=2.4, bevel=1.4, metal=0.4, rust=0.2)
    cel(L, [("ell", 12, 12, 6.2, 6.2)], C(46, 52, 48), form="sphere", ol=1.4, bevel=0.8)
    for k in range(8):
        a = k / 8 * math.pi * 2
        ink(L, [(12 + math.cos(a) * 2.0, 12 + math.sin(a) * 2.0), (12 + math.cos(a) * 5.4, 12 + math.sin(a) * 5.4)],
            0.4, C(28, 30, 30), 0.9)
    cel(L, [("ell", 12, 12, 1.8, 1.8)], C(90, 96, 92), form="sphere", ol=1.0, bevel=0.6, metal=0.8)
    for (x, y, r) in ((16.5, 7.0, 1.5), (7.0, 16.0, 1.2), (17.6, 15.6, 1.0), (6.6, 7.4, 0.8)):
        pustule(L, x, y, r, SICK)
    ink(L, [(9.0, 6.0), (10.4, 8.6), (9.6, 10.0)], 0.2, C(200, 220, 160), 0.8)
    return save_icon(cv, "exposure")


# ------------------------------------------------------------------ tonics
TONIC_LOOK = {
    # id: (liquid, shape, label, glow, emblem)
    "menders": (C(214, 64, 72), "round", CREAM, C(255, 120, 120), "heart"),
    "ward": (C(110, 190, 120), "square", C(200, 196, 176), C(150, 255, 160), "shield"),
    "firebrand": (C(238, 120, 40), "round", CREAM, C(255, 150, 60), "flame"),
    "spark": (C(70, 150, 230), "square", C(196, 204, 214), C(120, 190, 255), "bolt"),
    "quickstep": (C(220, 196, 70), "flask", CREAM, C(255, 230, 120), "wing"),
    "iron": (C(120, 126, 140), "square", C(176, 168, 150), None, "anvil"),
    "saints": (C(236, 224, 190), "round", C(176, 52, 44), C(255, 240, 200), "cross"),
}


def emblem(L, kind, cx, cy, s, col=C(60, 34, 28)):
    if kind == "heart":
        fill(L, [("ell", cx - s * 0.45, cy - s * 0.2, s * 0.5, s * 0.45), ("ell", cx + s * 0.45, cy - s * 0.2, s * 0.5, s * 0.45),
                 ("poly", [(cx - s * 0.92, cy - s * 0.05), (cx + s * 0.92, cy - s * 0.05), (cx, cy + s * 0.9)])], C(190, 40, 48))
    elif kind == "shield":
        fill(L, [("poly", [(cx - s * 0.8, cy - s * 0.8), (cx + s * 0.8, cy - s * 0.8), (cx + s * 0.7, cy + s * 0.2),
                           (cx, cy + s * 0.9), (cx - s * 0.7, cy + s * 0.2)])], C(70, 130, 84))
    elif kind == "flame":
        fill(L, [("poly", [(cx, cy - s), (cx + s * 0.6, cy - s * 0.1), (cx + s * 0.55, cy + s * 0.55), (cx, cy + s * 0.85),
                           (cx - s * 0.55, cy + s * 0.55), (cx - s * 0.5, cy), (cx - s * 0.1, cy - s * 0.3)])], C(214, 90, 30))
    elif kind == "bolt":
        fill(L, [("poly", [(cx + s * 0.2, cy - s), (cx - s * 0.55, cy + s * 0.1), (cx - s * 0.05, cy + s * 0.1),
                           (cx - s * 0.3, cy + s), (cx + s * 0.55, cy - s * 0.15), (cx + s * 0.05, cy - s * 0.15)])], C(40, 100, 190))
    elif kind == "wing":
        fill(L, [("poly", [(cx - s * 0.9, cy + s * 0.4), (cx - s * 0.2, cy - s * 0.8), (cx + s * 0.9, cy - s * 0.9),
                           (cx + s * 0.5, cy - s * 0.3), (cx + s * 0.8, cy - s * 0.1), (cx + s * 0.2, cy + s * 0.3)])], C(150, 110, 30))
    elif kind == "anvil":
        fill(L, [("poly", [(cx - s * 0.9, cy - s * 0.5), (cx + s * 0.9, cy - s * 0.5), (cx + s * 0.4, cy), (cx + s * 0.3, cy + s * 0.5),
                           (cx + s * 0.6, cy + s * 0.8), (cx - s * 0.6, cy + s * 0.8), (cx - s * 0.3, cy + s * 0.5),
                           (cx - s * 0.4, cy)])], C(60, 62, 70))
    elif kind == "cross":
        fill(L, [("rect", cx - s * 0.28, cy - s * 0.85, cx + s * 0.28, cy + s * 0.85),
                 ("rect", cx - s * 0.8, cy - s * 0.28, cx + s * 0.8, cy + s * 0.28)], C(245, 232, 210))


def tonic(tid):
    liq, shp, label, gl, emb = TONIC_LOOK[tid]
    cv = Canvas(U, U)
    L = cv.L
    r = 6.6 if shp != "flask" else 6.8
    cy = 14.0
    bottle(L, 12.0, cy, liq, glass=C(186, 210, 214) * 0.7 + liq * 0.3, shape_=shp, r=r, label=label, glow_col=gl,
           fill_k=0.86)
    ly = cy + r * 0.34
    emblem(L, emb, 12.0, ly, r * 0.25)
    return save_icon(cv, "tonic_" + tid)


# ------------------------------------------------------------------ plague fog (world)
def plague_fog():
    """A soft green spore cloud (additive-ish overlay), 256 px, tileless."""
    n = 256
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    noise = fbm(n, n, 40, 11, 4)
    base = np.clip(1.0 - d ** 1.6, 0, 1) * (0.55 + 0.6 * noise)
    a = np.clip(base * 1.2 - 0.1, 0, 1)
    # cel-step the density into three bands (anime-style smoke)
    bands = np.where(a > 0.62, 1.0, np.where(a > 0.38, 0.72, np.where(a > 0.16, 0.42, a * 2.0)))
    col = np.zeros((n, n, 3), np.float32)
    lo, mid, hi = np.array([70, 104, 52]) / 255, np.array([118, 160, 70]) / 255, np.array([176, 214, 110]) / 255
    t = np.clip((noise - 0.35) * 2.5, 0, 1)
    col[:] = lo
    col = np.where((bands >= 0.72)[..., None], mid, col)
    col = np.where(((bands >= 1.0) & (t > 0.5))[..., None], hi, col)
    alpha = bands * 0.62
    rgba = np.dstack([col, alpha])
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    # spore specks
    px = im.load()
    for _ in range(140):
        x, y = rng.integers(20, n - 20, 2)
        if d[y, x] < 0.8:
            r_ = rng.integers(1, 3)
            for oy in range(-r_, r_ + 1):
                for ox in range(-r_, r_ + 1):
                    if ox * ox + oy * oy <= r_ * r_:
                        c = (40, 54, 30, 200) if rng.random() < 0.6 else (200, 236, 140, 220)
                        px[int(x + ox), int(y + oy)] = c
    os.makedirs(WORLD, exist_ok=True)
    im.save(os.path.join(WORLD, "plague_fog.png"))
    _made.append(im.resize((96, 96), Image.LANCZOS))


# ================================================================== E3
PAPER = C(196, 172, 128)


def lore_page():
    """A torn notebook page with Quill's sketch of a creature, pinned by a red thread."""
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 21.2, 7.5, 1.3)
    pts = [(5.0, 3.6), (18.6, 2.8), (19.6, 8.0), (18.8, 12.0), (19.8, 19.6), (13.0, 20.6), (11.6, 19.6),
           (9.8, 20.8), (4.4, 20.2), (5.4, 14.0), (4.2, 9.0)]
    cel(L, [("poly", pts)], PAPER, n=(-0.15, -0.2, 1), ol=2.0, bevel=0.6, rim=0.6, line=C(90, 70, 46))
    # folded corner
    cel(L, [("poly", [(15.2, 2.9), (18.6, 2.8), (19.0, 6.4)])], PAPER * 0.9, n=(-0.3, -0.3, 0.9), ol=1.2, bevel=0.2,
        line=C(90, 70, 46))
    # ruled lines + handwriting squiggles
    for k, y in enumerate((6.0, 8.2, 15.6, 17.6)):
        ink(L, [(6.4, y), (9.0, y - 0.2), (11.6, y + 0.1), (14.2 - (k % 2) * 2, y - 0.1)], 0.14, C(70, 56, 46), 0.75)
    # sketch of a scorp-like creature in red-brown ink
    ink(L, [(7.4, 12.6), (9.6, 10.6), (12.4, 10.6), (14.6, 12.2), (16.6, 10.4), (17.2, 8.8)], 0.22, C(120, 40, 34), 0.95)
    for x in (9.0, 11.0, 13.0):
        ink(L, [(x, 11.6), (x - 0.8, 13.6)], 0.16, C(120, 40, 34), 0.9)
    fill(L, [("ell", 8.0, 12.2, 1.0, 0.8)], C(120, 40, 34), 0.9)
    # pin + thread
    cel(L, [("ell", 6.6, 4.8, 1.1, 1.1)], C(190, 50, 44), form="sphere", ol=1.0, bevel=0.6, rim=0)
    ink(L, [(6.6, 4.8), (4.6, 8.6), (5.2, 12.4)], 0.16, C(170, 40, 36), 0.8)
    return save_icon(cv, "lore_page")

# ================================================================== E4 cameo props (world, 40 x 40 units)
WOOD = C(132, 92, 58)
WOOD_D = C(96, 66, 44)
OD = C(96, 104, 66)
STEEL3 = C(124, 130, 134)
CANV = C(178, 162, 128)
RED3 = C(160, 52, 44)


def save_world(cv, name, px=192):
    im = cv.save(os.path.join(WORLD, name + ".png"), px)
    _made.append(im.resize((96, 96), Image.LANCZOS))
    return im


def post(L, x, y0, y1, w=0.9, col=WOOD):
    cel(L, [("rect", x - w, y0, x + w, y1)], col, form="cylv", ol=1.8, bevel=0.5)


def field_tent():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 20, 35.5, 17, 2.4)
    # back flap (darker), front canvas faces, open entrance
    cel(L, [("poly", [(6, 34), (20, 9), (34, 34)])], CANV * 0.8, n=(0.3, -0.3, 0.9), ol=2.2, bevel=0.8, wear=0.2)
    cel(L, [("poly", [(4, 35), (20, 9), (13, 35)])], CANV, n=(-0.7, -0.3, 0.7), ol=2.2, bevel=0.6, wear=0.3)
    cel(L, [("poly", [(27, 35), (20, 9), (36, 35)])], CANV * 0.92, n=(0.6, -0.2, 0.8), ol=2.2, bevel=0.6, wear=0.3)
    cel(L, [("poly", [(13, 35), (20, 14), (27, 35)])], C(40, 30, 26), n=(0, 0, 1), ol=1.2, bevel=0)
    # red cross banner on the flap + guy ropes and pegs
    cel(L, [("rect", 6.6, 22, 11.4, 27)], CREAM, n=(-0.4, -0.2, 0.9), ol=1.2, bevel=0.2)
    fill(L, [("rect", 8.4, 22.6, 9.6, 26.4), ("rect", 7.2, 23.9, 10.8, 25.1)], RED3)
    for (a, b) in (((20, 9), (2, 37)), ((20, 9), (38, 37))):
        ink(L, [a, b], 0.16, C(200, 186, 150), 0.7)
    post(L, 20, 6.5, 10.5, 0.5)
    # crates of tonics outside
    box(L, 29, 31, 34.6, 35.4, 2.4, WOOD, top=WOOD * 1.1, wear=0.3)
    for k, col in enumerate((C(120, 190, 96), C(214, 64, 72), C(220, 196, 70))):
        cel(L, [("rect", 29.7 + k * 1.6, 28.6, 30.8 + k * 1.6, 31)], col, form="cylv", ol=1.0, bevel=0.3, gloss=0.5)
    # lantern glow
    glow(L, 16, 30, 6, AMBER, 0.35)
    return save_world(cv, "field_tent")


def relay():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 20, 36, 12, 2.0)
    # tripod mast
    for (a, b) in (((20, 6), (12, 36)), ((20, 6), (28, 36)), ((20, 6), (21, 35))):
        ink(L, [a, b], 0.9, C(40, 40, 44), 1.0)
        ink(L, [a, b], 0.45, STEEL3, 1.0)
    for y in (16, 24, 30):
        k = (y - 6) / 30.0
        ink(L, [(20 - 8 * k, y), (20 + 8 * k, y)], 0.35, STEEL3 * 0.8, 1.0)
    # dish + antenna
    cel(L, [("ell", 14.5, 11.5, 4.8, 5.6)], CREAM, n=(-0.6, -0.2, 0.8), ol=1.8, bevel=0.6, metal=0.3)
    cel(L, [("ell", 14.0, 11.5, 3.0, 3.8)], CREAM * 0.8, n=(0.4, 0.1, 0.9), ol=0.8, bevel=0)
    ink(L, [(20, 6), (20, 1.5)], 0.35, STEEL3, 1.0)
    cel(L, [("ell", 20, 1.6, 0.9, 0.9)], C(255, 90, 60), form="sphere", ol=0.8, bevel=0.3, rim=0)
    glow(L, 20, 1.6, 2.5, C(255, 120, 80), 0.5)
    # transmitter box with dials, cables
    box(L, 22, 27, 33, 35.5, 3.6, OD, top=OD * 1.12, wear=0.35, rust=0.2)
    for k in range(3):
        cel(L, [("ell", 24.2 + k * 2.8, 30.8, 0.9, 0.9)], C(232, 220, 190), form="sphere", ol=0.8, bevel=0.3)
    fill(L, [("rect", 23.2, 33.0, 31.2, 33.6)], C(120, 220, 140), 0.9)
    ink(L, [(22, 33), (17, 35), (12, 34.5)], 0.35, C(30, 30, 32), 1.0)
    return save_world(cv, "relay")


def watch_tower():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 20, 37, 13, 2.0)
    for x0, x1 in ((10, 14), (30, 26)):
        ink(L, [(x0, 37), (x1, 14)], 1.1, WOOD_D * 0.6, 1.0)
        ink(L, [(x0, 37), (x1, 14)], 0.7, WOOD, 1.0)
    for y in (22, 30):
        k = (y - 14) / 23.0
        ink(L, [(14 - 4 * k, y), (26 + 4 * k, y)], 0.45, WOOD, 1.0)
        ink(L, [(14 - 4 * k, y), (26 + 4 * k, y + 4)], 0.3, WOOD_D, 0.9)
    # platform + railing + sandbags
    box(L, 9, 12, 31, 15, 2.6, WOOD, top=WOOD * 1.12, wear=0.3)
    for x in range(11, 31, 4):
        cel(L, [("ell", x, 11.2, 2.0, 1.1)], CANV * 0.9, form="sphere", ol=1.2, bevel=0.5)
    # tarp roof on poles
    post(L, 10.5, 3, 12)
    post(L, 29.5, 3, 12)
    cel(L, [("poly", [(6, 5.5), (34, 5.5), (32, 2.2), (8, 2.2)])], C(110, 96, 70), n=(0, -0.7, 0.7), ol=1.8, bevel=0.4, wear=0.3)
    for x in (12, 18, 24, 30):
        ink(L, [(x, 2.6), (x - 0.6, 5.2)], 0.18, C(70, 60, 44), 0.7)
    # bell hanging (Vesper's bell tower nod)
    cel(L, [("poly", [(19, 8), (21, 8), (22.4, 11), (17.6, 11)])], BRASS, form="cylv", ol=1.2, bevel=0.4, metal=0.8)
    return save_world(cv, "watch_tower", 224)


def vault():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 20, 35.5, 17, 2.4)
    # bunker half buried: concrete block, round vault door
    box(L, 4, 14, 32, 35, 5.0, C(126, 122, 112), top=C(144, 138, 126), wear=0.4, rust=0.15)
    cel(L, [("ell", 18, 24.5, 8.2, 8.2)], STEEL3, form="sphere", ol=2.2, bevel=1.2, metal=0.7, rust=0.25)
    cel(L, [("ell", 18, 24.5, 6.2, 6.2)], STEEL3 * 0.85, n=(0, 0, 1), ol=1.2, bevel=0.4, metal=0.5)
    for k in range(6):
        a = k / 6 * math.pi * 2
        ink(L, [(18 + math.cos(a) * 1.6, 24.5 + math.sin(a) * 1.6), (18 + math.cos(a) * 5.4, 24.5 + math.sin(a) * 5.4)], 0.5, C(60, 62, 66), 0.9)
    cel(L, [("ell", 18, 24.5, 1.6, 1.6)], BRASS, form="sphere", ol=1.0, bevel=0.4, metal=0.9)
    # hazard stripes + rubble
    for k in range(6):
        x = 5 + k * 4.4
        fill(L, [("poly", [(x, 33.4), (x + 2, 33.4), (x + 3.4, 31.6), (x + 1.4, 31.6)])], YEL, 0.9)
    for (x, y, r) in ((3, 35, 1.6), (34, 34.6, 2.0), (31, 36, 1.2)):
        cel(L, [("ell", x, y, r, r * 0.7)], C(120, 112, 100), form="sphere", ol=1.2, bevel=0.6)
    return save_world(cv, "vault")


def market_stall():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 20, 36, 16, 2.2)
    post(L, 7, 8, 35)
    post(L, 33, 8, 35)
    # striped awning
    for k in range(7):
        x0 = 4 + k * 4.6
        col = C(110, 60, 120) if k % 2 == 0 else C(214, 202, 174)
        cel(L, [("poly", [(x0, 6), (x0 + 4.6, 6), (x0 + 5.2, 12.5), (x0 + 0.6, 12.5)])], col, n=(0, -0.6, 0.8), ol=1.4, bevel=0.3)
    for k in range(8):
        cel(L, [("ell", 4.6 + k * 4.6, 12.8, 2.3, 1.5)], C(110, 60, 120) if k % 2 == 0 else C(214, 202, 174),
            form="sphere", ol=1.2, bevel=0.4)
    # counter with goods: bottles, ammo can, medkit
    box(L, 6, 25, 34, 35, 3.0, WOOD_D, top=WOOD, wear=0.3)
    for k, col in enumerate((C(214, 64, 72), C(110, 190, 120), C(70, 150, 230), C(220, 196, 70))):
        cel(L, [("rect", 9 + k * 2.4, 20.5, 10.6 + k * 2.4, 24.6)], col, form="cylv", ol=1.0, bevel=0.3, gloss=0.6)
    box(L, 21, 21, 26, 24.8, 1.6, OD, wear=0.3)
    box(L, 27.5, 21, 32, 24.8, 1.6, CREAM, wear=0.2)
    fill(L, [("rect", 29.3, 21.6, 30.2, 24.2), ("rect", 28.3, 22.5, 31.2, 23.3)], RED3)
    # hanging lantern
    ink(L, [(20, 12), (20, 16)], 0.2, C(40, 36, 30), 1.0)
    glow(L, 20, 17, 4, AMBER, 0.45)
    cel(L, [("ell", 20, 17, 1.2, 1.5)], C(255, 210, 130), form="sphere", ol=1.0, bevel=0.3, rim=0)
    return save_world(cv, "market_stall")


def plane_wreck():
    cv = Canvas(40, 40)
    L = cv.L
    shadow(L, 21, 34, 18, 3.0)
    # crumpled fuselage tail section, olive with roundel, broken prop + wing
    cel(L, [("poly", [(4, 30), (6, 22), (26, 18), (36, 12), (38, 14), (34, 26), (24, 32), (8, 33)])], OD,
        form="cylh", ol=2.4, bevel=1.2, rust=0.3, wear=0.4)
    cel(L, [("poly", [(30, 15), (35, 4), (38, 4), (37, 15)])], OD * 0.92, n=(0.3, -0.3, 0.9), ol=2.0, bevel=0.6, rust=0.2)
    cel(L, [("ell", 18, 25, 3, 3)], CREAM, n=(0, 0, 1), ol=1.2, bevel=0.2)
    cel(L, [("ell", 18, 25, 1.6, 1.6)], RED3, n=(0, 0, 1), ol=0.8, bevel=0)
    cel(L, [("poly", [(10, 30), (2, 36), (14, 37), (20, 31)])], OD * 0.85, n=(0, -0.8, 0.6), ol=2.0, bevel=0.5, rust=0.3)
    # torn, jagged front edge (the nose is gone), a bent prop blade in the dirt
    fill(L, [("poly", [(3, 21), (8, 21.6), (6.4, 24), (8.6, 26.4), (5.6, 28.4), (7.4, 31), (3, 33)])], C(0, 0, 0), 0.0)
    cel(L, [("poly", [(4.6, 21.4), (8.4, 21.8), (6.6, 24.2), (8.8, 26.4), (6.0, 28.6), (7.6, 31.2), (4.2, 31.6)])],
        C(40, 40, 38), n=(0.4, 0, 0.9), ol=1.4, bevel=0.2)
    cel(L, [("poly", [(26, 35.4), (34, 33.8), (36, 34.6), (27, 36.6)])], STEEL3 * 0.8, n=(0, -0.6, 0.8), ol=1.4, bevel=0.3, metal=0.5)
    # smoke wisp + black box glint (orange)
    soft(L, [("ell", 9, 9, 3.5, 6)], C(120, 112, 104), 0.45, blur=5)
    box(L, 22, 27.5, 26, 30.5, 1.4, C(230, 120, 40), wear=0.2)
    glow(L, 24, 29, 4, C(255, 150, 60), 0.4)
    soft(L, [("ell", 12, 14, 4, 5)], C(150, 140, 130), 0.35, blur=6)
    return save_world(cv, "plane_wreck", 224)


# ================================================================== E5 weapon styles
# Weapon icons drawn in a local frame (x along the weapon, y across, art units around
# 0,0) and laid on a diagonal (muzzle / tip up-right), the hangar cel look.
ANG = math.radians(-38)
WOOD_W = C(132, 86, 52)
GRIP = C(58, 44, 38)
FIRE = C(250, 140, 50)
TOX = C(140, 210, 80)
VOLT = C(110, 190, 255)
BLADE = C(196, 202, 206)


class Frame:
    def __init__(self, ang=ANG, cx=12.0, cy=12.4, k=1.08):
        self.c, self.s, self.cx, self.cy, self.k = math.cos(ang), math.sin(ang), cx, cy, k

    def p(self, x, y):
        x, y = x * self.k, y * self.k
        return (self.cx + x * self.c - y * self.s, self.cy + x * self.s + y * self.c)

    def poly(self, pts):
        return ("poly", [self.p(x, y) for (x, y) in pts])

    def rect(self, x0, y0, x1, y1):
        return self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def ell(self, x, y, r):
        q = self.p(x, y)
        return ("ell", q[0], q[1], r * self.k, r * self.k)

    def line(self, pts):
        return [self.p(x, y) for (x, y) in pts]


def part(L, prims, col, ol=2.1, bevel=0.8, **kw):
    cel(L, prims if isinstance(prims, list) else [prims], col, ol=ol, bevel=bevel, **kw)


def _gun(L, f, length=17.0, barrel=GUN, body=GUN, stock=WOOD_W, mag=None, suppressor=0.0, scope=False, short=False):
    """A generic long-gun: stock, receiver, barrel (+ suppressor), magazine, scope."""
    x0 = -length / 2
    if not short:
        part(L, f.poly([(x0, -0.6), (x0 + 4.6, -1.0), (x0 + 4.6, 1.1), (x0 + 0.6, 2.6), (x0 - 0.3, 2.4)]), stock, wear=0.25)
    part(L, f.poly([(x0 + 5.4, 1.0), (x0 + 6.8, 1.0), (x0 + 6.2, 4.0), (x0 + 4.9, 4.0)]), GRIP)
    if mag is not None:
        part(L, f.poly([(x0 + 8.0, 1.0), (x0 + 9.8, 1.0), (x0 + 10.4, mag), (x0 + 8.6, mag)]), C(70, 66, 60), metal=0.4)
    part(L, f.rect(x0 + 4.2, -1.4, x0 + 11.0, 1.2), body, metal=0.6, wear=0.2)
    bx = x0 + 11.0
    bend = length / 2 - suppressor
    part(L, f.rect(bx - 0.2, -0.75, bend, 0.35), barrel, ol=1.3, bevel=0.4, metal=0.8)
    if suppressor:
        part(L, f.rect(bend - 0.1, -1.1, bend + suppressor, 0.7), C(46, 48, 54), ol=1.4, bevel=0.6, metal=0.7)
        for k in range(1, 4):
            xx = bend + suppressor * k / 4
            ink(L, f.line([(xx, -1.0), (xx, 0.6)]), 0.12, C(20, 20, 24), 0.8)
    if scope:
        part(L, f.rect(x0 + 5.0, -3.0, x0 + 10.6, -1.7), C(52, 56, 62), ol=1.3, bevel=0.5, metal=0.8)
        part(L, f.ell(x0 + 10.6, -2.35, 0.9), C(90, 150, 200), ol=1.0, bevel=0.3, gloss=0.6)
    hline(L, f.line([(x0 + 4.6, -1.0), (x0 + 10.6, -1.0)]), 0.14, SPEC, 0.6)


def _sparks(L, pts, col, n=5, seed=1):
    rnd = np.random.default_rng(seed)
    for (x, y) in pts:
        for _ in range(n):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(0.8, 2.0)
            ink(L, [(x, y), (x + math.cos(a) * r, y + math.sin(a) * r)], 0.16, col, 0.9)


def _rocket(L, f, x, scale=1.0, col=C(196, 70, 44)):
    part(L, f.poly([(x, -1.5 * scale), (x + 2.2 * scale, -1.2 * scale), (x + 4.0 * scale, 0), (x + 2.2 * scale, 1.2 * scale),
                    (x, 1.5 * scale)]), col, ol=1.4, bevel=0.6, gloss=0.4)


def _blade(L, f, x0, x1, w, col=BLADE, curve=0.0, serr=False, hilt=GRIP, guard=BRASS):
    """A knife along +x from x0 (hilt end) to x1 (tip); curve bends the tip down."""
    hx = x0 + (x1 - x0) * 0.3
    part(L, f.rect(x0, -0.75, hx, 0.75), hilt, wear=0.2)
    for k in range(3):
        xx = x0 + (hx - x0) * (k + 0.6) / 3.4
        ink(L, f.line([(xx, -0.7), (xx, 0.7)]), 0.14, C(30, 22, 18), 0.7)
    part(L, f.rect(hx - 0.3, -w * 0.95, hx + 0.5, w * 0.95), guard, ol=1.2, bevel=0.3, metal=0.9)
    top = [(hx + 0.5, -w * 0.55), (x1 - (x1 - hx) * 0.25, -w * 0.6 + curve * 0.3), (x1, curve)]
    bot = [(x1 - (x1 - hx) * 0.18, w * 0.5 + curve), (hx + 0.5, w * 0.6)]
    if serr:
        bot = []
        n = 7
        for k in range(n + 1):
            xx = x1 - (x1 - hx - 0.5) * k / n
            bot.append((xx, w * 0.6 + (0.45 if k % 2 else 0)))
    part(L, f.poly(top + bot), col, ol=1.4, bevel=0.5, metal=1.0, gloss=0.5)
    hline(L, f.line([(hx + 0.8, -w * 0.2), (x1 - 1.0, curve * 0.5 - w * 0.1)]), 0.16, SPEC, 0.8)


def _hammer(L, f, hl, head, hw, hh, col=STEEL, wood=WOOD_W):
    part(L, f.rect(-hl / 2, -0.55, hl / 2, 0.55), wood, wear=0.3)
    part(L, f.rect(-hl / 2, -0.7, -hl / 2 + 2.4, 0.7), GRIP)
    x = hl / 2 - 0.5
    part(L, f.rect(x - hw / 2, -hh, x + hw / 2, hh), col, ol=2.0, bevel=0.8, metal=0.7, rust=0.15, wear=0.3)
    return x


def style_icon(hero, sid):
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 21.0, 8.0, 1.3)
    f = Frame()
    if hero == "ash_rook":
        if sid == "boom":
            part(L, f.rect(-8.5, -2.0, 5.0, 2.0), C(110, 116, 74), form="cylh", wear=0.35, rust=0.2)
            part(L, f.rect(-9.2, -2.4, -7.6, 2.4), C(70, 72, 60), metal=0.5)
            part(L, f.rect(3.8, -2.4, 5.4, 2.4), C(70, 72, 60), metal=0.5)
            part(L, f.poly([(-3.0, 2.0), (-1.6, 2.0), (-2.0, 4.8), (-3.4, 4.8)]), GRIP)
            _rocket(L, f, 5.4, 1.05)
            glow(L, *f.p(-9.6, 0), 2.4, FIRE, 0.35)
        elif sid == "cluster":
            part(L, f.rect(-8.5, -2.0, 3.0, 2.0), C(96, 104, 120), form="cylh", wear=0.3, rust=0.15)
            part(L, f.poly([(-3.0, 2.0), (-1.6, 2.0), (-2.0, 4.8), (-3.4, 4.8)]), GRIP)
            for (x, y) in ((5.4, -1.9), (5.8, 1.7), (8.4, -0.1)):
                part(L, f.ell(x, y, 1.9), C(200, 150, 60), form="sphere", gloss=0.5)
                ink(L, f.line([(x - 0.4, y - 1.4), (x - 0.2, y - 2.2)]), 0.2, C(40, 30, 20), 0.9)
        else:  # mortar
            g = Frame(math.radians(-62), 11.0, 14.0)
            part(L, g.rect(-6.0, -2.8, 4.0, 2.8), C(64, 60, 58), form="cylh", metal=0.6, rust=0.3)
            part(L, g.rect(3.6, -3.2, 5.0, 3.2), C(84, 80, 76), metal=0.6)
            part(L, g.poly([(-6.5, -3.0), (-7.4, 0), (-6.5, 3.0)]), C(54, 50, 48))
            glow(L, *g.p(7.5, 0), 4.0, FIRE, 0.65)
            part(L, g.ell(7.8, 0, 2.4), C(240, 110, 40), form="sphere", rim=0.4, gloss=0.7)
            fill(L, [g.ell(7.2, -0.6, 1.0)], C(255, 220, 120), 0.9)
    elif hero == "vesper_thorn":
        if sid == "bolt":
            _gun(L, f, 19.0, scope=True)
            part(L, f.ell(-0.6, 1.8, 0.7), C(150, 150, 156), form="sphere", metal=0.8)
            part(L, f.poly([(9.0, -0.9), (11.0, -0.2), (9.0, 0.5)]), C(220, 206, 170), ol=1.0, bevel=0.2)
        elif sid == "semi":
            _gun(L, f, 16.0, mag=5.2, body=C(80, 86, 70))
        else:
            _gun(L, f, 18.0, body=C(70, 76, 66))
            glow(L, *f.p(-0.6, -3.0), 3.0, TOX, 0.5)
            bottle(L, *f.p(-0.6, -3.4), TOX, shape_="round", r=1.9, glow_col=None, fill_k=0.7)
    elif hero == "pebble":
        if sid == "maul":
            x = _hammer(L, f, 17.0, 0, 4.6, 3.0)
            for yy in (-1.6, 1.6):
                part(L, f.ell(x, yy, 0.45), C(150, 150, 150), form="sphere", ol=0.8, bevel=0.2, metal=1)
        elif sid == "sweep":
            g = Frame(math.radians(-24))
            x = _hammer(L, g, 18.0, 0, 3.2, 4.0, C(150, 120, 70))
            for r in (6.0, 7.4):
                pts = [(12 + math.cos(a) * r * 1.4, 13 + math.sin(a) * r) for a in np.linspace(math.pi * 1.05, math.pi * 1.7, 8)]
                ink(L, pts, 0.24, C(255, 236, 200), 0.6)
        else:
            x = _hammer(L, f, 16.0, 0, 5.4, 2.4, C(92, 96, 104))
            part(L, f.rect(x + 2.7, -1.4, x + 4.4, 1.4), C(150, 152, 160), ol=1.4, bevel=0.6, metal=1)
            for yy in (-1.6, 0, 1.6):
                part(L, f.ell(x - 1.2, yy, 0.4), C(186, 160, 90), form="sphere", ol=0.7, bevel=0.2, metal=1)
    elif hero == "bolt_juno":
        if sid == "chain":
            g = Frame(math.radians(-30), 12, 12.6)
            for k in range(5):
                part(L, g.ell(-8.0 + k * 1.9, 0.4 * math.sin(k), 1.0), C(140, 144, 150), ol=1.1, bevel=0.3, metal=1)
            part(L, g.rect(1.0, -3.0, 5.0, 3.0), C(88, 92, 104), metal=0.7, wear=0.3)
            part(L, g.poly([(5.0, -3.2), (8.4, -2.6), (9.0, 0), (8.4, 2.6), (5.0, 3.2)]), C(120, 126, 140), metal=0.8)
            for k in range(4):
                ink(L, g.line([(8.6, -2.0 + k * 1.3), (9.0, -2.0 + k * 1.3)]), 0.2, C(30, 30, 36), 0.8)
            _sparks(L, [g.p(9.4, -1.6)], VOLT, 4)
        elif sid == "whip":
            pts = [(12 + math.cos(a) * (2.0 + a * 1.25), 12 + math.sin(a) * (2.0 + a * 1.1)) for a in np.linspace(0, 5.6, 40)]
            ink(L, pts, 0.9, C(40, 50, 70), 1.0)
            ink(L, pts, 0.5, VOLT, 0.9)
            glow(L, pts[-1][0], pts[-1][1], 2.4, VOLT, 0.5)
            part(L, Frame(math.radians(50), 10.0, 13.0).rect(-1.0, -0.8, 3.6, 0.8), GRIP)
            _sparks(L, [pts[-1], pts[22]], C(200, 230, 255), 4, 3)
        else:
            g = Frame(math.radians(-12), 12, 12.2)
            rings = [g.ell(-5.1 + k * 3.4, -1.2, 1.75) for k in range(4)]
            holes = [("-" + r[0],) + r[1:] for r in [g.ell(-5.1 + k * 3.4, -1.2, 1.0) for k in range(4)]]
            part(L, rings + [g.poly([(-7.0, -0.4), (7.0, -0.4), (6.0, 3.8), (3.0, 5.0), (-3.0, 5.0), (-6.0, 3.8)])] + holes, BRASS,
                 metal=0.9, wear=0.35, gloss=0.5, ol=2.2)
            for k in range(4):
                part(L, g.poly([(-5.9 + k * 3.4, -2.6), (-5.1 + k * 3.4, -4.4), (-4.3 + k * 3.4, -2.6)]), C(170, 172, 180),
                     metal=1, ol=1.2, bevel=0.3)
            hline(L, g.line([(-5.6, 3.6), (5.0, 3.6)]), 0.18, SPEC, 0.6)
            _sparks(L, [g.p(6.6, -3.4)], VOLT, 3, 5)
    elif hero == "sister_cinder":
        if sid == "suppressor":
            _gun(L, f, 20.0, mag=4.6, suppressor=4.4, stock=C(70, 64, 60))
        elif sid == "burst":
            _gun(L, f, 17.0, mag=4.4, stock=C(70, 64, 60))
            cx, cy = f.p(3.0, 5.0)
            ink(L, [f.p(1.5, 1.0), (cx, cy - 1.6)], 0.2, BRASS, 0.9)
            soft(L, [("ell", cx + 1.0, cy + 2.4, 2.6, 1.6)], C(200, 196, 190), 0.4, blur=3)
            part(L, [("ell", cx, cy, 1.7, 1.7)], BRASS, form="sphere", metal=0.9, gloss=0.5)
            glow(L, cx, cy, 1.8, FIRE, 0.4)
        else:
            g = Frame(math.radians(-38), 12, 12)
            for k, off in enumerate((-3.2, 0, 3.2)):
                h = Frame(math.radians(-38), 12 + off * 0.62, 12 + off * 0.78)
                part(L, h.rect(-6.0, -1.2, 1.0, 1.2), BRASS, metal=0.9, wear=0.2)
                part(L, h.poly([(1.0, -1.1), (3.4, -0.8), (5.0, 0), (3.4, 0.8), (1.0, 1.1)]), C(220, 90, 30), gloss=0.5)
                glow(L, *h.p(5.4, 0), 1.8, FIRE, 0.55)
                fill(L, [h.ell(5.6, 0, 0.6)], C(255, 230, 140), 0.9)
    elif hero == "quill_marrow":
        if sid == "bayonet":
            _blade(L, f, -9.0, 9.4, 1.6)
        elif sid == "scalpels":
            for a in (-55, -20):
                g = Frame(math.radians(a), 12, 12.4)
                part(L, g.rect(-8.0, -0.5, 0.0, 0.5), C(160, 164, 172), metal=1, ol=1.2, bevel=0.3)
                part(L, g.poly([(0.0, -0.8), (5.0, -0.9), (7.8, 0.6), (0.0, 0.8)]), BLADE, metal=1, gloss=0.6, ol=1.2, bevel=0.3)
                hline(L, g.line([(0.6, -0.4), (6.4, -0.2)]), 0.12, SPEC, 0.8)
        else:
            part(L, f.rect(-9.0, -0.8, -3.0, 0.8), GRIP)
            part(L, f.poly([(-3.0, -1.0), (8.0, -2.4), (9.2, 3.0), (-3.0, 3.6)] + [(-3.0, 3.6)]), BLADE, metal=0.9, rust=0.2,
                 gloss=0.4, ol=2.0)
            for k in range(9):
                x = -2.6 + k * 1.3
                fill(L, [f.poly([(x, 3.4 - k * 0.06), (x + 0.65, 4.3 - k * 0.06), (x + 1.3, 3.4 - k * 0.06)])], C(150, 154, 160))
            part(L, f.ell(5.4, -0.4, 0.8), C(40, 30, 30), ol=0.8)
            fill(L, [f.ell(1.0, 2.0, 0.9), f.ell(2.0, 2.8, 0.5)], C(150, 30, 30), 0.8)
    elif hero == "nyx_caldera":
        if sid == "dustblades":
            for a in (-60, -20):
                g = Frame(math.radians(a), 12, 12.4)
                _blade(L, g, -8.0, 8.0, 1.4, col=C(176, 168, 190), curve=-1.4, guard=C(90, 70, 110))
        elif sid == "long":
            _blade(L, f, -10.0, 10.4, 1.2, col=C(170, 176, 196), guard=C(90, 70, 110))
        else:
            _blade(L, f, -8.0, 8.6, 2.2, col=C(170, 190, 150), curve=-2.6, guard=C(60, 90, 50))
            p = f.p(6.4, -0.6)
            glow(L, p[0], p[1] + 1.0, 2.2, TOX, 0.45)
            fill(L, [("ell", p[0], p[1] + 0.6, 0.45, 0.9), ("ell", p[0] + 0.1, p[1] + 2.2, 0.5, 0.7)], TOX, 0.95)
            fill(L, [f.ell(1.0, 0.0, 0.5), f.ell(3.0, 0.2, 0.4)], TOX, 0.85)
    else:  # helm_wisp
        g = Frame(math.radians(-14), 12, 11.4)
        if sid == "sidearm":
            part(L, g.rect(-6.0, -2.0, 6.0, 0.6), C(86, 90, 100), metal=0.8, wear=0.2)
            part(L, g.poly([(-5.6, 0.6), (-2.0, 0.6), (-2.6, 3.6), (-3.4, 6.4), (-6.6, 6.0), (-6.0, 3.0)]), C(100, 70, 50), wear=0.3)
            ink(L, g.line([(-2.0, 0.8), (0.2, 0.9), (0.4, 2.6), (-2.4, 2.8)]), 0.3, C(60, 62, 70), 1.0)
            for k in range(4):
                ink(L, g.line([(-5.0 + k * 0.8, -1.8), (-5.0 + k * 0.8, -0.2)]), 0.14, C(30, 30, 34), 0.8)
            part(L, g.rect(5.6, -2.2, 6.6, -1.6), C(70, 72, 80), ol=0.8, bevel=0.2)
        elif sid == "flare":
            part(L, g.rect(-6.0, -2.4, 0.0, 1.0), C(200, 80, 40), wear=0.3, rust=0.1)
            part(L, g.rect(-0.4, -2.6, 5.0, 1.2), C(220, 96, 46), form="cylh", wear=0.3)
            part(L, g.poly([(5.0, -2.9), (6.8, -3.6), (6.8, 2.2), (5.0, 1.5)]), C(200, 84, 40), wear=0.3, metal=0.3)
            fill(L, [g.ell(6.9, -0.7, 1.5)], C(40, 20, 14))
            part(L, g.poly([(-5.6, 1.0), (-2.0, 1.0), (-3.0, 6.4), (-6.4, 6.0)]), C(90, 66, 50))
            glow(L, *g.p(7.6, -0.7), 3.0, FIRE, 0.6)
            fill(L, [g.ell(7.4, -0.7, 1.2)], C(255, 210, 120), 0.95)
        else:
            part(L, g.rect(-7.0, -2.0, 7.0, 0.6), C(60, 64, 72), metal=0.8, wear=0.2)
            part(L, g.poly([(-5.0, 0.6), (-2.2, 0.6), (-3.0, 5.4), (-5.6, 5.0)]), GRIP)
            part(L, g.rect(-0.6, 0.6, 1.4, 8.2), C(80, 76, 70), metal=0.5)
            ink(L, g.line([(-7.0, -0.6), (-10.0, -0.4), (-10.4, 2.6)]), 0.5, C(50, 52, 58), 1.0)
            for k in range(3):
                ink(L, g.line([(2.4 + k * 1.3, -1.8), (2.4 + k * 1.3, 0.4)]), 0.14, C(20, 20, 24), 0.8)
    return _save_inked(cv, "style_%s_%s" % (hero, sid))


def _save_inked(cv, name, px=PX, width=4.0):
    """Hangar-style heavy silhouette ink around thin weapon shapes, then save."""
    im = cv.image()
    a = np.asarray(im).astype(np.float32)
    solid = a[..., 3] > 170
    from scipy import ndimage as _ndi
    d = _ndi.distance_transform_edt(~solid)
    ring = np.clip(width + 0.5 - d, 0, 1) * (~solid)
    ink_rgb = np.array([34, 24, 22], np.float32)
    al = a[..., 3:4] / 255.0
    r = ring[..., None]
    rgb = a[..., :3] * (1 - r) + ink_rgb * r
    out_a = np.maximum(a[..., 3], ring * 255)
    # keep glows / shadow under the ink where they were already there
    rgb = np.where(r > 0, (ink_rgb * r + a[..., :3] * al * (1 - r)) / np.maximum(r + al * (1 - r), 1e-4), rgb)
    im2 = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), np.clip(out_a, 0, 255)]).astype(np.uint8), "RGBA")
    im2 = im2.resize((px, px), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.8, percent=40, threshold=2))
    im2.save(os.path.join(ICON, name + ".png"))
    _made.append(im2)
    return im2


E5_STYLES = [(h, s) for h, ss in (
    ("ash_rook", ("boom", "cluster", "mortar")), ("vesper_thorn", ("bolt", "semi", "coater")),
    ("pebble", ("maul", "sweep", "driver")), ("bolt_juno", ("chain", "whip", "knuckle")),
    ("sister_cinder", ("suppressor", "burst", "ember")), ("quill_marrow", ("bayonet", "scalpels", "cleaver")),
    ("nyx_caldera", ("dustblades", "long", "viper")), ("helm_wisp", ("sidearm", "flare", "machine"))) for s in ss]


# ================================================================== E6 salvage core
def salvage_core():
    """A war machine's core: a cyan glowing cell in a dented steel cage with torn wires."""
    cv = Canvas(U, U)
    L = cv.L
    shadow(L, 12.5, 21.4, 8.5, 1.5)
    glow(L, 12, 12.0, 10.5, C(90, 220, 255), 0.75)
    for (x, c) in ((8.6, C(200, 60, 44)), (12.0, C(230, 196, 70)), (15.4, C(60, 120, 200))):
        ink(L, [(x, 18.0), (x - 1.0, 19.8), (x + 0.5, 21.4)], 0.55, c, 1.0)
    cel(L, [("rect", 6.6, 6.2, 17.4, 17.6)], C(30, 110, 140), form="cylv", ol=2.4, bevel=1.2, rim=0.6, gloss=0.4)
    cel(L, [("ell", 12.0, 11.9, 3.9, 4.6)], C(120, 236, 255), form="sphere", ol=0.0, bevel=1.0, gloss=0.6, t1=0.22, t2=0.5)
    fill(L, [("ell", 11.0, 10.2, 1.4, 1.8)], C(245, 255, 255), 0.95)
    for x in (8.2, 12.0, 15.8):
        cel(L, [("rect", x - 0.55, 6.0, x + 0.55, 17.8)], C(120, 126, 134), n=(0, 0, 1), ol=1.4, bevel=0.3, metal=0.9)
    cel(L, [("rect", 5.0, 3.4, 19.0, 6.6)], C(96, 102, 110), form="cylh", ol=2.4, bevel=0.9, metal=0.8, wear=0.3, rust=0.2)
    cel(L, [("rect", 5.0, 17.2, 19.0, 20.4)], C(96, 102, 110), form="cylh", ol=2.4, bevel=0.9, metal=0.8, wear=0.3, rust=0.2)
    for x in (6.8, 17.2):
        for y in (5.0, 18.8):
            cel(L, [("ell", x, y, 0.7, 0.7)], C(190, 160, 90), form="sphere", ol=0.7, bevel=0.2, metal=1)
    hline(L, [(7.4, 7.4), (7.4, 16.4)], 0.26, SPEC, 0.6)
    return save_icon(cv, "salvage_core")


GROUPS = {
    "e1": [herb, plague_gland, dust_shard, machine_oil, medicine, lambda: medicine(False), backpack, exposure,
           *[(lambda t=t: tonic(t)) for t in TONIC_LOOK], plague_fog],
    "e3": [lore_page],
    "e4": [field_tent, relay, watch_tower, vault, market_stall, plane_wreck],
    "e6": [salvage_core],
    "e5": [(lambda h=h, s=s: style_icon(h, s)) for (h, s) in E5_STYLES],
}


if __name__ == "__main__":
    argv = sys.argv[1:]
    if "--sheet" in argv:
        i = argv.index("--sheet")
        argv = argv[:i] + argv[i + 2:]
    args = [a for a in argv if not a.startswith("--")]
    groups = args or list(GROUPS)
    os.makedirs(ICON, exist_ok=True)
    os.makedirs(WORLD, exist_ok=True)
    for gname in groups:
        for fn in GROUPS[gname]:
            fn()
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        sheet(_made, os.path.join(out, "depth_art_%s.png" % "_".join(groups)))
        big = [im.resize((im.width * 2, im.height * 2), Image.LANCZOS) for im in _made]
        sheet(big, os.path.join(out, "depth_art_%s_zoom.png" % "_".join(groups)), cols=4)
    print("ok", len(_made))
