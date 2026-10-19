"""Depth Update item art in the hangar's anime cel-shaded look (tools/celkit.py):
ingredients, tonics, medicine, backpack, plague fog and later phases' items.

usage (from game/):  python3 tools/gen_depth_art.py [group ...] [--sheet DIR]
groups: e1 (default: all)
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


GROUPS = {
    "e1": [herb, plague_gland, dust_shard, machine_oil, medicine, lambda: medicine(False), backpack, exposure,
           *[(lambda t=t: tonic(t)) for t in TONIC_LOOK], plague_fog],
    "e3": [lore_page],
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
