"""Visual tier landmarks + props, repainted at native resolution (tools/landkit.py).

Every asset is rendered at 2 x its old world size in px, so in the match one
texel = one screen pixel (UnitAnim.TEXEL with ART_GROW). Look: the hangar's anime
cel shading lit from the top-left, 3/4 top-down construction (real tops + front
faces), crisp dark outline, worn D+C detail, baked cool contact shadow.

usage (from game/):  python3 tools/gen_landmarks_v2.py [name ...] [--sheet DIR]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from landkit import (Canvas, C, cel, ink, hline, fill, soft, glow, extrude, vcyl, hcyl, plate, seam, rivets,  # noqa: E402
                     finish, render, UP, SPEC)

ROOT = os.path.join(HERE, "..", "assets", "sprites")
WORLD = os.path.join(ROOT, "depth", "world")
ZONE = os.path.join(ROOT, "depth", "zone")
PROPS = os.path.join(ROOT, "props_hd")

OL = 4.5      # outline px at S=8 (≈1.4 px at native)
BV = 3.0
OD = C(92, 100, 62)
OD_D = C(70, 76, 50)
ALU = C(150, 154, 150)
STEEL = C(112, 118, 122)
GUN = C(64, 68, 74)
RUBBER = C(40, 38, 38)
DARK = C(22, 18, 16)
CREAM = C(214, 202, 172)
RED = C(160, 50, 42)
ORANGE = C(232, 120, 40)
CONC = C(150, 146, 136)
CONC_D = C(112, 108, 100)
WOOD = C(128, 90, 58)
WOOD_D = C(92, 64, 42)
CANVAS = C(176, 160, 122)
RUST = C(126, 68, 40)
HAZ = C(220, 178, 52)
GLASS = C(70, 96, 100)

_made = []


def kw(**k):
    d = dict(ol=OL, bevel=BV)
    d.update(k)
    return d


def fx_layer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def smoke(base, x, y, h, w, seed=0, col=(120, 112, 104), a=110):
    """Soft rising smoke plume (soft pixels on purpose) composited over `base`."""
    rr = random.Random(seed)
    lay = Image.new("L", base.size, 0)
    d = ImageDraw.Draw(lay)
    for k in range(9):
        t = k / 8
        cx = x + math.sin(t * 2.6 + seed) * w * 0.4 + t * w * 0.5
        cy = y - t * h
        r = w * (0.25 + 0.55 * t) * rr.uniform(0.8, 1.15)
        d.ellipse((cx - r, cy - r * 0.8, cx + r, cy + r * 0.8), fill=int(a * (1 - t * 0.75)))
    lay = lay.filter(ImageFilter.GaussianBlur(w * 0.18))
    sl = Image.new("RGBA", base.size, tuple(col) + (0,))
    sl.putalpha(lay)
    return Image.alpha_composite(base, sl)


def glow_px(base, x, y, r, col, a=150):
    g = Image.new("L", base.size, 0)
    ImageDraw.Draw(g).ellipse((x - r, y - r, x + r, y + r), fill=a)
    g = g.filter(ImageFilter.GaussianBlur(r * 0.45))
    gl = Image.new("RGBA", base.size, tuple(col) + (0,))
    gl.putalpha(g)
    return Image.alpha_composite(base, gl)


def save(im, folder, name):
    os.makedirs(folder, exist_ok=True)
    im.save(os.path.join(folder, name + ".png"))
    _made.append((name, im))
    return im


# ======================================================================= plane
def plane_wreck():
    """Helm's downed plane: broken fuselage lying across the dirt, torn-open nose
    with ribs showing, upright tail fin, a separated wing in front, the radial
    engine and bent prop thrown clear, scattered skin panels, the black box."""
    cv = Canvas(120, 80)
    L = cv.L
    # far wing (behind the fuselage), seen from above, broken tip
    plate(L, [(52, 43), (63, 23), (74, 21), (79, 24), (70, 44)], 1.6, OD * 0.95, **kw(rust=0.1, wear=0.4))
    seam(L, [(60, 40), (69, 24)])
    seam(L, [(66, 42), (75, 24)])
    # horizontal stabiliser at the tail (far + near halves)
    plate(L, [(90, 40), (99, 33), (106, 33), (99, 42)], 1.0, OD * 0.9, **kw(wear=0.3))
    # fuselage: lying cylinder, front torn open (p0), tail up-right (p1)
    p0, p1 = (30.0, 51.0), (101.0, 40.0)
    hcyl(L, p0, p1, 11.0, 3.6, base=OD, bands=7, ol=OL, rust=0.12, wear=0.45)
    # belly strip (lighter grey underside visible along the lower edge)
    cel(L, [("poly", [(31, 60.5), (100, 43.2), (100.4, 44.0), (32, 62.0)])], C(128, 134, 128), n=(0, 0.7, 0.7), ol=0, bevel=0, rim=0)
    # panel seams: rings across the body + two stringers along it
    for t in (0.18, 0.36, 0.55, 0.72, 0.86):
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t
        r = 11.0 + (3.6 - 11.0) * t
        seam(L, [(x + 1.4 * r / 11, y - r * 0.98), (x + 0.6, y - r * 0.2), (x, y + r * 0.9)], w=0.2)
        rivets(L, (x + 2.2 * r / 11, y - r * 0.9), (x + 1.1, y + r * 0.8), max(3, int(r * 0.9)), r=0.18)
    seam(L, [(33, 45.5), (99, 37.4)], w=0.16)
    seam(L, [(33, 56.0), (99, 42.4)], w=0.16)
    rivets(L, (36, 46.6), (96, 38.6), 22, r=0.16)
    # faded roundel (foreshortened) + stencilled code bars
    cel(L, [("ell", 66, 47.2, 3.4, 4.2)], CREAM * 0.92, n=(0.05, 0.1, 1), ol=2.0, bevel=0.8, wear=0.5)
    cel(L, [("ell", 66, 47.2, 1.8, 2.3)], RED, n=(0.05, 0.1, 1), ol=0, bevel=0.5, wear=0.4)
    for k in range(3):
        fill(L, [("poly", [(74 + k * 2.4, 44.0), (75.6 + k * 2.4, 43.7), (75.8 + k * 2.4, 47.4), (74.2 + k * 2.4, 47.7)])], CREAM * 0.8, 0.55)
    # cockpit frame with shattered canopy on top of the body
    cel(L, [("poly", [(40, 40.5), (44, 36.5), (52, 35.4), (55, 38.6), (52, 42.4), (43, 43.6)])], GLASS, n=(-0.2, -0.5, 0.85),
        ol=OL, bevel=2.0, gloss=0.6)
    for (a, b) in (((44, 36.6), (45.5, 43.2)), ((48.4, 35.8), (49.4, 42.8)), ((52.4, 35.6), (53, 41.6))):
        ink(L, [a, b], 0.5, C(38, 40, 36), 1.0)
    ink(L, [(42, 39.5), (47, 38.2), (46, 41.0), (50, 39.4)], 0.18, C(200, 226, 220), 0.7)
    # torn nose: jagged opening, dark interior, ribs and dangling stringers
    jag = [(27.4, 40.0), (30.6, 41.6), (29.2, 44.4), (32.2, 46.4), (30.0, 49.0), (32.8, 51.6), (30.4, 54.2),
           (33.0, 57.2), (30.2, 59.4), (31.4, 62.2), (27.8, 61.6), (25.2, 56.0), (24.8, 46.0)]
    cel(L, [("poly", jag)], C(30, 26, 24), n=(0.5, 0, 0.85), ol=OL, bevel=0.6)
    for k, x in enumerate((27.2, 29.0)):
        ink(L, [(x, 42.0 + k), (x + 1.4, 51.0), (x, 60.0 - k)], 0.42, C(120, 120, 112), 0.95)
    ink(L, [(26.0, 47.0), (31.0, 48.2)], 0.3, C(150, 146, 136), 0.9)
    ink(L, [(26.4, 55.0), (30.6, 55.6)], 0.3, C(150, 146, 136), 0.9)
    ink(L, [(28.6, 61.0), (27.0, 64.4), (28.0, 66.6)], 0.22, C(170, 60, 40), 0.9)     # loose wire
    ink(L, [(29.6, 60.6), (30.6, 64.0)], 0.22, C(60, 120, 170), 0.9)
    # tail fin rising from the tail, rudder hinge, torn tip
    cel(L, [("poly", [(86.0, 37.4), (99.6, 35.2), (101.4, 16.0), (97.6, 13.8), (95.0, 16.4), (88.0, 33.0)])], OD * 1.04,
        n=(-0.55, -0.15, 0.82), ol=OL, bevel=BV, rust=0.1, wear=0.45)
    seam(L, [(96.0, 34.0), (98.0, 17.0)], w=0.2)
    rivets(L, (90.0, 33.0), (96.4, 17.0), 9, r=0.16)
    cel(L, [("poly", [(98.0, 34.6), (101.0, 34.0), (102.4, 17.0), (99.6, 16.6)])], OD_D, n=(0.5, -0.1, 0.85), ol=2.5, bevel=1.0, wear=0.3)
    # near (front) horizontal stabiliser half, bent down
    plate(L, [(93, 42.4), (104, 44.4), (106.6, 48.6), (97.6, 47.2)], 1.0, OD * 0.92, **kw(wear=0.35))
    # separated main wing lying in front-left, root torn, aileron + flap seams
    wing = [(10.0, 63.0), (16.0, 57.4), (46.0, 59.6), (49.0, 61.2), (47.0, 64.4), (44.4, 63.2), (42.0, 66.8), (20.0, 71.6)]
    plate(L, wing, 2.4, OD * 0.98, **kw(rust=0.12, wear=0.5))
    seam(L, [(16.6, 64.6), (44.0, 60.6)], w=0.2)
    seam(L, [(14.0, 63.2), (20.6, 69.0)], w=0.2)
    seam(L, [(28.0, 59.4), (32.0, 66.0)], w=0.18)
    rivets(L, (17.6, 66.0), (41.0, 62.6), 14, r=0.16)
    cel(L, [("ell", 25.0, 63.6, 2.6, 1.8)], CREAM * 0.85, n=UP, ol=1.6, bevel=0.6, wear=0.5)
    cel(L, [("ell", 25.0, 63.6, 1.3, 0.9)], RED, n=UP, ol=0, bevel=0.3)
    # radial engine thrown clear + bent prop blades
    cel(L, [("ell", 13.0, 48.6, 6.6, 6.0)], GUN, form="sphere", ol=OL, bevel=BV, metal=0.7, rust=0.125)
    for k in range(9):
        a = k / 9 * math.tau
        x, y = 13.0 + math.cos(a) * 5.0, 48.6 + math.sin(a) * 4.5
        cel(L, [("ell", x, y, 1.5, 1.4)], STEEL, form="sphere", ol=2.0, bevel=0.8, metal=0.8, rust=0.12)
    cel(L, [("ell", 13.0, 48.6, 2.4, 2.2)], C(150, 120, 70), form="sphere", ol=2.4, bevel=1.0, metal=0.8)
    for (a, b, c) in (((13.6, 46.2), (19.0, 37.4), (21.4, 36.8)), ((11.0, 50.0), (3.6, 52.6), (2.4, 55.6)), ((14.6, 51.0), (17.0, 58.4), (15.6, 61.0))):
        cel(L, [("line", [a, b, c], 1.6)], C(84, 78, 70), ol=2.4, bevel=0.6, metal=0.5, rust=0.12)
        fill(L, [("line", [b, c], 1.0)], HAZ, 0.85)
    # scattered skin panels + a strut
    for (pts, col) in (([(54, 66), (60, 64.6), (61.6, 67.4), (55.4, 68.6)], OD * 0.9),
                       ([(76, 56), (81, 55.4), (80.4, 58.2), (76.6, 58.6)], ALU),
                       ([(86, 58), (89, 57.6), (88.6, 59.6)], OD_D),
                       ([(6, 70), (10.4, 69.4), (9.6, 71.6)], ALU)):
        plate(L, pts, 0.7, col, **kw(ol=3.0, bevel=1.0, wear=0.4))
    cel(L, [("line", [(64, 61.6), (72.6, 64.0)], 0.9)], STEEL, ol=2.4, bevel=0.4, metal=0.7, rust=0.4)
    # the black box (gameplay cue: orange, glints)
    extrude(L, [(36.0, 66.6), (41.4, 65.6), (42.6, 67.6), (37.2, 68.8)], 2.6, ORANGE, **kw(ol=3.4, bevel=1.4, wear=0.3))
    fill(L, [("poly", [(37.4, 64.6), (41.0, 63.8), (41.4, 64.4), (37.8, 65.2)])], C(40, 30, 24), 0.9)
    hline(L, [(37.0, 64.0), (40.4, 63.2)], 0.25, SPEC, 0.9)
    im = render(cv, 300)
    im = finish(im, seed=11, u=1.0, grime=170, streaks=14, wear=150, scratch=34,
                dents=[(170, 112, 7), (210, 110, 5)], holes=[(196, 118, 1.6), (120, 160, 1.4), (240, 98, 1.3)],
                shadow=(150, 170, 128, 20, 0.55))
    im = glow_px(im, 98, 167, 14, (255, 150, 60), 110)
    im = smoke(im, 72, 120, 90, 26, seed=3)
    return save(im, WORLD, "plane_wreck")


# ======================================================================= vehicles
def _wheel(L, cx, cy, r, flat=0.0):
    cel(L, [("ell", cx, cy, r * 0.62, r)], RUBBER, form="sphere", ol=OL, bevel=BV)
    cel(L, [("ell", cx + r * 0.08, cy, r * 0.34, r * 0.55)], C(96, 92, 86), form="sphere", ol=2.4, bevel=1.0, metal=0.6, rust=0.3)
    fill(L, [("ell", cx + r * 0.08, cy, r * 0.1, r * 0.16)], DARK, 0.9)


def _car_body(L, x0, x1, gy, h, roof, col, seed, glass=True, burnt=False):
    """Sedan seen 3/4 from above-front: hood + cabin + trunk tops, the near side face."""
    w = x1 - x0
    d = h * 0.55                     # depth of the top surfaces on screen
    # near side (front-facing) body panel
    side = [(x0 + 1.0, gy - 1.0), (x1 - 0.6, gy - 1.0), (x1, gy - h * 0.55), (x1 - 0.6, gy - h), (x0 + 0.6, gy - h), (x0, gy - h * 0.5)]
    cel(L, [("poly", side)], col * 0.86, n=(0.0, 0.35, 0.93), **kw(rust=0.15, wear=0.5))
    # top: hood / roof / trunk as one deck, then the cabin raised on it
    deck = [(x0 + 0.6, gy - h), (x1 - 0.6, gy - h), (x1 - 1.4, gy - h - d), (x0 + 1.6, gy - h - d)]
    cel(L, [("poly", deck)], col, n=UP, **kw(rust=0.12, wear=0.5))
    cx0, cx1 = x0 + w * roof[0], x0 + w * roof[1]
    ch = h * 0.62
    cab_side = [(cx0 - 1.6, gy - h), (cx1 + 1.4, gy - h), (cx1 - 0.6, gy - h - ch), (cx0 + 0.6, gy - h - ch)]
    cel(L, [("poly", cab_side)], col * 0.9, n=(0.0, 0.3, 0.95), **kw(wear=0.4))
    cab_top = [(cx0 + 0.6, gy - h - ch), (cx1 - 0.6, gy - h - ch), (cx1 - 1.4, gy - h - ch - d * 0.8), (cx0 + 1.4, gy - h - ch - d * 0.8)]
    cel(L, [("poly", cab_top)], col * 1.06, n=UP, **kw(wear=0.5, rust=0.1))
    if glass:
        for (a0, a1) in ((0.06, 0.46), (0.54, 0.94)):
            gx0 = cx0 - 0.6 + (cx1 - cx0 + 1.2) * a0
            gx1 = cx0 - 0.6 + (cx1 - cx0 + 1.2) * a1
            cel(L, [("poly", [(gx0, gy - h - 0.7), (gx1, gy - h - 0.7), (gx1 - 0.4, gy - h - ch + 0.7), (gx0 + 0.6, gy - h - ch + 0.7)])],
                C(30, 34, 36) if burnt else GLASS * 0.7, n=(0, 0.2, 1), ol=2.0, bevel=0.6, gloss=0.0 if burnt else 0.5)
        if not burnt:
            ink(L, [(cx0 + 2.0, gy - h - ch + 1.4), (cx0 + 3.6, gy - h - 1.6), (cx0 + 5.0, gy - h - ch + 2.0)], 0.16, C(210, 230, 224), 0.6)
    # windscreen on the deck (front = right end)
    cel(L, [("poly", [(cx1 + 1.4, gy - h), (cx1 + 4.4, gy - h - d * 0.2), (cx1 - 0.2, gy - h - ch - d * 0.75), (cx1 - 0.6, gy - h - ch)])],
        C(30, 34, 36) if burnt else GLASS * 0.85, n=(0.5, -0.3, 0.8), ol=2.4, bevel=0.8, gloss=0.0 if burnt else 0.6)
    seam(L, [(x0 + w * 0.32, gy - 1.6), (x0 + w * 0.32, gy - h + 0.4)], w=0.18)
    seam(L, [(x0 + w * 0.62, gy - 1.6), (x0 + w * 0.62, gy - h + 0.4)], w=0.18)
    fill(L, [("rect", x0 + w * 0.36, gy - h * 0.62, x0 + w * 0.42, gy - h * 0.55)], C(190, 186, 170), 0.8)
    # bumpers + lamps
    cel(L, [("rect", x1 - 0.6, gy - h * 0.5, x1 + 0.8, gy - 1.6)], STEEL, n=(0.8, 0, 0.6), ol=2.0, bevel=0.6, metal=0.8, rust=0.3)
    fill(L, [("ell", x1 - 0.2, gy - h * 0.72, 0.7, 0.55)], C(230, 214, 160) if not burnt else DARK, 0.9)


def wreck_car():
    cv = Canvas(44, 26)
    L = cv.L
    _car_body(L, 4.0, 40.0, 21.0, 7.4, (0.28, 0.62), C(150, 132, 102), 1)
    _wheel(L, 11.0, 21.4, 3.6)
    _wheel(L, 32.0, 21.4, 3.6)
    # missing door, hanging bumper, roof dent shading
    cel(L, [("poly", [(17.0, 19.0), (24.0, 19.0), (24.0, 14.6), (17.6, 14.4)])], C(26, 22, 22), n=(0, 0, 1), ol=2.4, bevel=0.4)
    ink(L, [(5.0, 18.4), (2.6, 21.6)], 0.5, STEEL, 0.9)
    im = finish(render(cv, 176), seed=21, grime=180, streaks=12, wear=150, scratch=24,
                dents=[(70, 50, 6)], holes=[(118, 60, 1.4)], shadow=(90, 92, 80, 10, 0.6))
    return save(im, PROPS, "wreck_car")


def wreck():
    cv = Canvas(40, 26)
    L = cv.L
    _car_body(L, 4.0, 36.0, 21.0, 7.0, (0.3, 0.64), C(92, 70, 52), 2, burnt=True)
    _wheel(L, 10.4, 21.4, 3.2)
    cel(L, [("ell", 29.0, 22.4, 3.2, 1.6)], C(54, 46, 40), form="sphere", ol=2.4, bevel=0.6)     # wheel gone, hub on the dirt
    im = finish(render(cv, 160), seed=22, grime=220, streaks=22, wear=110, scratch=18,
                holes=[(70, 70, 1.6), (100, 56, 1.4), (50, 62, 1.3)], shadow=(82, 92, 74, 10, 0.6))
    im = im.convert("RGBA")
    # scorch + rust-out: a burnt shell
    m = im.getchannel("A")
    import worn_fx as wf
    im = wf.rust_patches(im, m, amount=0.55, u=1.2, seed=5, alpha=200)
    im = wf.scorch(im, m, 90, 40, 26, seed=4, amt=160)
    return save(im, PROPS, "wreck")


def wreck_truck():
    cv = Canvas(60, 31)
    L = cv.L
    gy = 26.0
    # flatbed (left) with slats, cab (right)
    extrude(L, [(4.0, gy - 2.0), (38.0, gy - 2.0), (39.0, gy - 9.0), (5.0, gy - 9.0)], 6.0, WOOD, top=WOOD * 1.08, **kw(wear=0.5))
    for x in range(8, 38, 5):
        seam(L, [(x, gy - 14.6), (x + 1.0, gy - 8.6)], w=0.2)
    extrude(L, [(37.0, gy - 1.0), (56.0, gy - 1.0), (56.6, gy - 9.6), (37.4, gy - 9.6)], 9.0, C(84, 104, 116), top=C(96, 118, 128), **kw(rust=0.2, wear=0.5))
    cel(L, [("poly", [(44.0, gy - 11.0), (55.0, gy - 11.0), (54.0, gy - 17.4), (45.0, gy - 17.4)])], GLASS * 0.8, n=(0.2, 0.2, 1), ol=2.4, bevel=0.6, gloss=0.4)
    cel(L, [("rect", 55.6, gy - 9.0, 57.6, gy - 3.0)], STEEL, n=(0.8, 0, 0.6), ol=2.0, bevel=0.6, metal=0.8, rust=0.3)
    fill(L, [("rect", 39.0, gy - 8.0, 43.0, gy - 3.0)], DARK, 0.9)
    for x in (12.0, 28.0, 49.0):
        _wheel(L, x, gy, 4.0)
    im = finish(render(cv, 240), seed=23, grime=180, streaks=16, wear=140, scratch=26,
                dents=[(200, 60, 7)], holes=[(160, 74, 1.5)], shadow=(122, 112, 112, 12, 0.6))
    return save(im, PROPS, "wreck_truck")


def wreck_bus():
    cv = Canvas(86, 37)
    L = cv.L
    gy = 32.0
    col = C(196, 150, 56)
    extrude(L, [(3.0, gy - 1.0), (82.0, gy - 1.0), (82.6, gy - 8.0), (3.6, gy - 8.0)], 14.0, col * 0.95, top=C(170, 166, 150), **kw(rust=0.25, wear=0.5))
    for i in range(9):
        x = 8.0 + i * 8.0
        cel(L, [("rect", x, gy - 13.6, x + 6.0, gy - 8.6)], GLASS * 0.6 if i % 3 else C(26, 24, 24), n=(0, 0.2, 1), ol=2.2, bevel=0.5, gloss=0.3)
    seam(L, [(3.4, gy - 6.4), (81.6, gy - 6.4)], w=0.25)
    fill(L, [("rect", 3.4, gy - 5.8, 81.6, gy - 4.8)], C(40, 34, 28), 0.75)
    for (x0, x1) in ((20, 34), (50, 60)):                 # roof caved in
        cel(L, [("poly", [(x0, gy - 15.0), (x1, gy - 15.0), (x1 - 1.0, gy - 20.0), (x0 + 1.0, gy - 20.0)])], C(36, 30, 28), n=(0, 0.3, 1), ol=2.0, bevel=0.4)
    for x in (14.0, 70.0):
        _wheel(L, x, gy, 4.0)
    im = finish(render(cv, 344), seed=24, grime=200, streaks=26, wear=150, scratch=34,
                dents=[(110, 70, 8), (240, 60, 6)], holes=[(180, 92, 1.6), (300, 88, 1.4)], shadow=(172, 134, 168, 14, 0.6))
    import worn_fx as wf
    im = wf.rust_patches(im, im.getchannel("A"), amount=0.35, u=1.2, seed=8, alpha=190)
    return save(im, PROPS, "wreck_bus")


def tank_wreck():
    cv = Canvas(64, 39)
    L = cv.L
    gy = 34.0
    # tracks: long rounded slabs with road wheels and track plates
    for (y0, k) in ((gy - 8.0, 0.86), (gy, 1.0)):
        cel(L, [("poly", [(4.0, y0 - 1.0), (8.0, y0 - 6.4), (56.0, y0 - 6.4), (60.0, y0 - 1.0), (56.0, y0 + 1.0), (8.0, y0 + 1.0)])],
            RUBBER * 1.3 * k, n=(0, 0.3, 1), **kw(metal=0.3))
        for x in range(9, 56, 6):
            cel(L, [("ell", x, y0 - 2.6, 2.4, 2.2)], C(76, 76, 70) * k, form="sphere", ol=2.4, bevel=0.8, metal=0.6, rust=0.2)
        for x in range(6, 58, 2):
            ink(L, [(x, y0 + 0.6), (x + 0.6, y0 - 0.6)], 0.18, C(16, 14, 12), 0.6)
    # hull
    extrude(L, [(6.0, gy - 6.0), (58.0, gy - 6.0), (54.0, gy - 16.0), (10.0, gy - 16.0)], 5.4, OD, top=OD * 1.06, **kw(rust=0.15, wear=0.5))
    # turret knocked askew + bent barrel
    cel(L, [("poly", [(20.0, gy - 21.0), (24.0, gy - 27.6), (40.0, gy - 28.0), (44.0, gy - 21.6), (40.0, gy - 18.6), (24.0, gy - 18.4)])],
        OD * 1.04, form="dome", **kw(rust=0.12, wear=0.5))
    hcyl(L, (42.0, gy - 25.0), (63.0, gy - 31.0), 1.3, 1.0, base=C(76, 82, 54), bands=4, ol=3.0)
    cel(L, [("ell", 30.0, gy - 26.6, 3.0, 1.4)], C(60, 66, 44), n=UP, ol=2.4, bevel=0.6)
    fill(L, [("ell", 32.0, gy - 22.6, 1.4, 1.4)], CREAM, 0.8)
    for x in (16, 24, 32, 40, 48):
        rivets(L, (x, gy - 15.4), (x + 1.0, gy - 11.0), 3, r=0.2)
    im = finish(render(cv, 256, 156), seed=25, grime=200, streaks=18, wear=140, scratch=30,
                dents=[(120, 70, 7)], holes=[(150, 86, 1.6)], shadow=(128, 140, 124, 12, 0.6))
    im = smoke(im, 120, 40, 60, 18, seed=6, a=80)
    return save(im, ZONE, "tank_wreck")


# ======================================================================= camp / jobs
def field_tent():
    cv = Canvas(48, 40)
    L = cv.L
    gy = 36.0
    # ridge tent seen 3/4: lit left roof, shaded right roof, open dark front
    cel(L, [("poly", [(4.0, gy), (18.0, 8.0), (38.0, 8.0), (26.0, gy)])], CANVAS * 1.04, n=(-0.6, -0.3, 0.75), **kw(wear=0.4))
    cel(L, [("poly", [(26.0, gy), (38.0, 8.0), (46.0, gy - 2.0)])], CANVAS * 0.8, n=(0.7, 0.1, 0.7), **kw(wear=0.3))
    cel(L, [("poly", [(10.0, gy), (18.0, 14.0), (24.0, gy)])], C(36, 28, 24), n=(0, 0, 1), ol=3.0, bevel=0.6)
    cel(L, [("poly", [(18.0, 14.0), (24.0, gy), (27.0, gy - 1.0)])], CANVAS * 0.95, n=(0.4, 0, 0.9), ol=2.4, bevel=0.6)  # flap
    for t in (0.33, 0.66):
        seam(L, [(4.0 + 14.0 * t, gy - 28.0 * t), (26.0 + 12.0 * t, gy - 28.0 * t)], w=0.2)
    ink(L, [(18.0, 8.0), (38.0, 8.0)], 0.5, WOOD_D, 1.0)
    for (a, b) in (((4.0, gy), (0.6, gy + 2.0)), ((46.0, gy - 2.0), (47.6, gy + 1.6))):
        ink(L, [a, b], 0.2, C(190, 170, 130), 0.9)
    # red cross patch + supply crates + lantern
    cel(L, [("rect", 27.0, 16.0, 33.0, 22.0)], CREAM, n=(-0.5, -0.3, 0.8), ol=2.0, bevel=0.6, wear=0.4)
    fill(L, [("rect", 29.4, 16.8, 30.6, 21.2), ("rect", 27.8, 18.4, 32.2, 19.6)], RED, 0.95)
    extrude(L, [(30.0, gy + 2.0), (38.0, gy + 2.0), (38.6, gy - 1.6), (30.6, gy - 1.6)], 4.0, WOOD, **kw(wear=0.5))
    fill(L, [("rect", 33.0, gy - 1.2, 35.4, gy + 1.4)], RED * 0.9, 0.8)
    vcyl(L, 8.0, gy + 1.0, 1.4, 3.4, STEEL, ol=2.4, metal=0.6)
    im = finish(render(cv, 220, 184), seed=31, grime=140, streaks=6, wear=110, scratch=10, shadow=(112, 168, 96, 10, 0.55))
    im = glow_px(im, 37, 168, 12, (255, 196, 110), 120)
    return save(im, WORLD, "field_tent")


def market_stall():
    cv = Canvas(48, 44)
    L = cv.L
    gy = 40.0
    for x in (6.0, 41.0):
        cel(L, [("rect", x, 12.0, x + 1.4, gy)], WOOD_D, form="cylv", ol=OL, bevel=1.4, wear=0.4)
    # counter (box) with goods on top
    extrude(L, [(4.0, gy), (44.0, gy), (44.6, gy - 5.0), (4.6, gy - 5.0)], 10.0, WOOD, top=WOOD * 1.12, **kw(wear=0.5))
    for x in range(8, 44, 6):
        seam(L, [(x, gy - 1.0), (x, gy - 9.4)], w=0.2)
    for (x, col) in ((9.0, C(96, 150, 70)), (13.0, C(200, 120, 50)), (17.0, C(140, 60, 90)), (21.0, C(110, 168, 200))):
        vcyl(L, x, gy - 12.4, 1.2, 3.6, col, ol=2.4, gloss=0.5)
    extrude(L, [(26.0, gy - 11.6), (34.0, gy - 11.6), (34.4, gy - 14.6), (26.4, gy - 14.6)], 3.2, OD, **kw(ol=3.0, wear=0.4))
    extrude(L, [(36.0, gy - 11.6), (41.6, gy - 11.6), (42.0, gy - 14.0), (36.4, gy - 14.0)], 4.0, CREAM, **kw(ol=3.0, wear=0.4))
    fill(L, [("rect", 38.0, gy - 17.0, 39.6, gy - 15.0), ("rect", 37.2, gy - 16.6, 40.4, gy - 15.4)], RED, 0.9)
    # striped awning: front valance + sloped top, scalloped edge
    for i in range(8):
        x0 = 3.0 + i * 5.25
        col = C(150, 52, 60) if i % 2 == 0 else C(218, 204, 176)
        cel(L, [("poly", [(x0 + 1.4, 6.0), (x0 + 6.65, 6.0), (x0 + 5.25, 13.0), (x0, 13.0)])], col, n=UP, ol=3.0, bevel=0.8, wear=0.45)
        cel(L, [("ell", x0 + 2.6, 13.4, 2.6, 1.6)], col * 0.88, n=(0, 0.4, 0.9), ol=2.6, bevel=0.6, wear=0.3)
    im = finish(render(cv, 220, 202), seed=32, grime=140, streaks=6, wear=120, scratch=14, shadow=(112, 186, 104, 10, 0.55))
    return save(im, WORLD, "market_stall")


def watch_tower():
    cv = Canvas(40, 52)
    L = cv.L
    gy = 50.0
    legs = [((6.0, gy), (11.0, 18.0)), ((34.0, gy), (29.0, 18.0)), ((14.0, gy - 3.0), (14.6, 17.0)), ((26.0, gy - 3.0), (25.4, 17.0))]
    for (a, b) in legs[2:]:
        cel(L, [("line", [a, b], 1.2)], WOOD_D * 0.8, ol=3.0, bevel=0.6, wear=0.4)
    for y in (26.0, 36.0, 45.0):
        t = (gy - y) / (gy - 18.0)
        xa, xb = 6.0 + 5.0 * t, 34.0 - 5.0 * t
        cel(L, [("line", [(xa, y), (xb, y)], 0.8)], WOOD, ol=2.6, bevel=0.4, wear=0.4)
    cel(L, [("line", [(7.0, gy - 2.0), (31.0, 20.0)], 0.6)], WOOD_D, ol=2.4, bevel=0.3)
    cel(L, [("line", [(33.0, gy - 2.0), (9.0, 20.0)], 0.6)], WOOD_D, ol=2.4, bevel=0.3)
    for (a, b) in legs[:2]:
        cel(L, [("line", [a, b], 1.5)], WOOD, ol=OL, bevel=1.0, wear=0.4)
    # ladder
    for x in (18.0, 21.0):
        cel(L, [("line", [(x, gy), (x, 20.0)], 0.5)], WOOD * 1.1, ol=2.0, bevel=0.2)
    for y in range(22, 50, 3):
        ink(L, [(18.0, y), (21.0, y)], 0.4, WOOD * 1.15, 1.0)
    # platform + sandbag lip + roof
    extrude(L, [(5.0, 20.0), (35.0, 20.0), (35.6, 15.0), (5.6, 15.0)], 2.0, WOOD, top=WOOD * 1.12, **kw(wear=0.5))
    for i in range(7):
        x = 6.4 + i * 4.2
        cel(L, [("ell", x + 2.0, 12.0, 2.2, 1.5)], C(166, 146, 104), form="sphere", ol=2.6, bevel=1.0, wear=0.4)
    for x in (7.0, 32.0):
        cel(L, [("rect", x, 2.0, x + 1.0, 12.0)], WOOD_D, form="cylv", ol=2.4, bevel=0.6)
    plate(L, [(3.0, 3.6), (37.0, 3.6), (35.0, 0.6), (5.0, 0.6)], 1.2, C(120, 110, 90), top_n=(0, -0.7, 0.7), **kw(rust=0.12, wear=0.5))
    im = finish(render(cv, 230, 300), seed=33, grime=120, streaks=8, wear=100, scratch=12, shadow=(115, 290, 92, 9, 0.55))
    return save(im, WORLD, "watch_tower")


def relay():
    cv = Canvas(40, 40)
    L = cv.L
    gy = 37.0
    # lattice mast + dish + generator box with amber lamps
    for (a, b) in (((10.0, gy), (15.0, 4.0)), ((20.0, gy), (15.0, 4.0))):
        cel(L, [("line", [a, b], 0.7)], STEEL, ol=2.6, bevel=0.3, metal=0.6, rust=0.2)
    for y in range(8, 36, 4):
        t = (gy - y) / (gy - 4.0)
        xa, xb = 10.0 + 5.0 * t, 20.0 - 5.0 * t
        ink(L, [(xa, y), (xb, y - 4.0)], 0.3, C(90, 94, 96), 0.9)
    cel(L, [("ell", 9.0, 9.0, 5.0, 6.2)], C(190, 186, 176), form="dome", **kw(metal=0.4, wear=0.4))
    cel(L, [("ell", 9.6, 9.0, 3.0, 4.0)], C(150, 146, 138), n=(0.4, 0, 0.9), ol=2.0, bevel=0.8)
    ink(L, [(9.6, 9.0), (13.0, 7.6)], 0.4, GUN, 1.0)
    fill(L, [("ell", 15.0, 3.0, 0.9, 0.9)], C(255, 90, 60), 0.95)
    extrude(L, [(20.0, gy), (36.0, gy), (36.6, gy - 6.0), (20.6, gy - 6.0)], 8.0, OD, top=OD * 1.08, **kw(rust=0.12, wear=0.5))
    for x in range(22, 35, 2):
        seam(L, [(x, gy - 1.0), (x, gy - 6.0)], w=0.16)
    for x in (24.0, 28.0, 32.0):
        fill(L, [("ell", x, gy - 10.6, 0.9, 0.7)], C(255, 180, 70), 0.95)
    cel(L, [("line", [(20.0, gy - 4.0), (14.0, gy + 1.0), (8.0, gy + 0.6)], 0.4)], C(30, 28, 26), ol=1.6, bevel=0.1)
    im = finish(render(cv, 184), seed=34, grime=140, streaks=10, wear=120, scratch=14, shadow=(110, 176, 80, 9, 0.55))
    for x in (24.0, 28.0, 32.0):
        im = glow_px(im, x * 4.6, (gy - 10.6) * 4.6, 8, (255, 180, 70), 110)
    return save(im, WORLD, "relay")


def vault():
    cv = Canvas(44, 36)
    L = cv.L
    gy = 33.0
    extrude(L, [(4.0, gy), (40.0, gy), (40.6, gy - 7.0), (4.6, gy - 7.0)], 18.0, CONC_D, top=CONC, **kw(wear=0.6))
    # round steel door with spokes + hazard band
    cel(L, [("ell", 22.0, gy - 9.0, 8.0, 7.6)], C(84, 90, 94), form="sphere", **kw(metal=0.8, rust=0.15))
    cel(L, [("ell", 22.0, gy - 9.0, 5.4, 5.0)], C(104, 110, 114), form="sphere", ol=2.6, bevel=1.2, metal=0.9)
    for k in range(6):
        a = k / 6 * math.tau
        ink(L, [(22.0, gy - 9.0), (22.0 + math.cos(a) * 4.8, gy - 9.0 + math.sin(a) * 4.4)], 0.5, C(60, 64, 68), 1.0)
    cel(L, [("ell", 22.0, gy - 9.0, 1.4, 1.3)], C(176, 140, 70), form="sphere", ol=2.0, bevel=0.6, metal=0.8)
    for k in range(9):
        x0 = 5.0 + k * 3.9
        fill(L, [("poly", [(x0, gy - 2.6), (x0 + 2.0, gy - 2.6), (x0 + 3.2, gy - 0.8), (x0 + 1.2, gy - 0.8)])], HAZ if k % 2 == 0 else DARK, 0.9)
    seam(L, [(4.6, gy - 13.0), (40.0, gy - 13.0)], w=0.2)
    # charges taped to the door (orange cue)
    for (x, y) in ((16.0, gy - 12.0), (27.6, gy - 6.6)):
        extrude(L, [(x, y), (x + 2.6, y), (x + 2.8, y - 1.0), (x + 0.2, y - 1.0)], 1.6, ORANGE, **kw(ol=2.4, bevel=0.6))
    im = finish(render(cv, 240, 196), seed=35, grime=170, streaks=18, wear=150, scratch=24,
                dents=[(60, 90, 6)], holes=[(190, 70, 1.4)], shadow=(120, 182, 112, 12, 0.6))
    return save(im, WORLD, "vault")


# ======================================================================= zone props
def oil_tank():
    cv = Canvas(36, 44)
    L = cv.L
    gy = 42.0
    for x in (9.0, 27.0):
        cel(L, [("rect", x, gy - 8.0, x + 1.6, gy)], GUN, form="cylv", ol=OL, bevel=0.8, metal=0.6, rust=0.2)
    top, ry = vcyl(L, 18.0, gy - 6.0, 15.0, 28.0, C(156, 126, 84), top=C(170, 142, 98), metal=0.4, rust=0.15, wear=0.5)
    for y in (gy - 14.0, gy - 23.0):
        ink(L, [(3.2, y), (32.8, y)], 0.35, C(70, 48, 30), 0.7)
        rivets(L, (4.0, y - 0.8), (32.0, y - 0.8), 14, r=0.2)
    for x in (24.0, 26.0):
        cel(L, [("line", [(x, gy - 6.0), (x, top + 1.0)], 0.35)], C(60, 56, 54), ol=1.6, bevel=0.1)
    for y in range(int(top) + 3, int(gy - 6), 3):
        ink(L, [(24.0, y), (26.0, y)], 0.3, C(60, 56, 54), 0.95)
    for k in range(7):
        x0 = 6.0 + k * 2.2
        fill(L, [("poly", [(x0, gy - 19.0), (x0 + 1.1, gy - 19.0), (x0 + 2.2, gy - 17.0), (x0 + 1.1, gy - 17.0)])], HAZ if k % 2 == 0 else DARK, 0.9)
    vcyl(L, 12.0, top + 1.0, 2.0, 2.6, GUN, ol=2.6, metal=0.7)
    im = finish(render(cv, 246, 300), seed=41, grime=180, streaks=28, wear=150, scratch=24,
                dents=[(80, 140, 9)], holes=[(160, 170, 1.5)], shadow=(126, 286, 108, 10, 0.6))
    return save(im, ZONE, "oil_tank")


def pipe_rack():
    cv = Canvas(40, 30)
    L = cv.L
    gy = 28.0
    for x in (7.0, 32.0):
        for dx in (-3.0, 3.0):
            cel(L, [("line", [(x + dx, gy), (x, 7.0)], 0.6)], C(126, 92, 64), ol=2.6, bevel=0.3, metal=0.5, rust=0.2)
        ink(L, [(x - 2.0, gy - 6.0), (x + 2.0, gy - 6.0)], 0.4, C(100, 72, 50), 1.0)
    for (y, r, col) in ((9.0, 2.0, C(150, 142, 124)), (13.6, 1.6, C(178, 124, 72)), (17.6, 1.3, C(118, 128, 132))):
        hcyl(L, (1.0, y), (39.0, y), r, base=col, bands=5, ol=OL, metal=0.5)
        for x in (12.0, 24.0):
            cel(L, [("rect", x, y - r - 0.3, x + 1.2, y + r + 0.3)], col * 0.8, form="cylv", ol=2.0, bevel=0.4, metal=0.6)
    cel(L, [("ell", 18.0, 9.0, 2.8, 2.8), ("-ell", 18.0, 9.0, 1.6, 1.6)], C(190, 52, 40), form="sphere", ol=2.4, bevel=0.6, metal=0.5)
    ink(L, [(16.4, 9.0), (19.6, 9.0)], 0.35, C(150, 40, 30), 0.95)
    fill(L, [("ell", 30.0, 22.0, 3.0, 0.8)], C(18, 16, 14), 0.6)    # drip puddle
    ink(L, [(30.0, 14.8), (30.0, 21.0)], 0.2, C(30, 26, 22), 0.7)
    im = finish(render(cv, 292, 220), seed=42, grime=150, streaks=20, wear=130, scratch=20, shadow=(146, 210, 130, 8, 0.5))
    return save(im, ZONE, "pipe_rack")


def street_lamp():
    cv = Canvas(22, 40)
    L = cv.L
    gy = 38.0
    extrude(L, [(7.0, gy), (13.0, gy), (13.4, gy - 2.0), (7.4, gy - 2.0)], 2.6, CONC_D, top=CONC, **kw(wear=0.5))
    cel(L, [("poly", [(9.4, gy - 3.6), (11.0, gy - 3.6), (11.2, 9.0), (13.6, 5.0), (16.6, 4.4), (16.6, 5.8), (14.0, 6.4), (12.0, 9.6), (12.0, gy - 3.6)])],
        C(70, 76, 80), n=(0, 0, 1), **kw(metal=0.8, rust=0.12))
    cel(L, [("rect", 9.0, gy - 12.0, 12.4, gy - 9.6)], C(80, 84, 88), form="cylv", ol=2.4, bevel=0.6, metal=0.8, rust=0.2)
    cel(L, [("poly", [(13.6, 4.8), (20.4, 4.8), (19.4, 7.2), (14.4, 7.2)])], C(60, 64, 70), n=UP, ol=3.0, bevel=0.6, metal=0.8)
    fill(L, [("ell", 17.0, 7.4, 2.2, 0.6)], C(255, 226, 150), 0.95)
    ink(L, [(9.6, gy - 20.0), (8.4, gy - 18.0), (8.8, gy - 15.0)], 0.2, C(150, 70, 40), 0.8)
    im = finish(render(cv, 143, 260), seed=43, grime=120, streaks=10, wear=110, scratch=10, shadow=(66, 250, 34, 6, 0.55))
    im = glow_px(im, 110, 52, 22, (255, 200, 110), 120)
    return save(im, ZONE, "street_lamp")


def shop_ruin():
    cv = Canvas(40, 36)
    L = cv.L
    gy = 34.0
    # broken storefront: walls with a ragged top, empty window, door, faded awning
    extrude(L, [(2.0, gy), (34.0, gy), (37.0, gy - 6.0), (5.0, gy - 6.0)], 20.0, C(150, 120, 100), top=C(168, 140, 116), **kw(wear=0.6))
    cel(L, [("poly", [(1.0, 7.4), (6.0, 6.4), (9.0, 9.6), (13.0, 7.0), (16.0, 9.0), (15.0, 0.0), (0.0, 0.0)])], C(0, 0, 0), alpha=0.0, ol=0)
    for (x, y, r) in ((6.0, 7.6, 2.2), (12.0, 8.2, 1.6), (30.0, 7.2, 2.0)):
        cel(L, [("poly", [(x - r, y), (x, y - r * 0.4), (x + r, y + 0.2), (x + r * 0.4, y + r * 0.6)])], C(126, 100, 84), n=UP, ol=2.4, bevel=0.6)
    cel(L, [("rect", 5.0, 18.0, 16.0, 28.0)], C(24, 22, 26), n=(0, 0, 1), ol=3.0, bevel=0.4)
    for (a, b) in (((5.4, 19.0), (9.0, 23.0)), ((9.0, 23.0), (7.0, 27.4)), ((12.0, 18.6), (15.4, 22.0))):
        ink(L, [a, b], 0.2, C(160, 170, 180), 0.6)
    cel(L, [("rect", 20.0, 17.0, 27.0, gy)], C(78, 56, 40), n=(0, 0.1, 1), ol=3.0, bevel=0.6, wear=0.5)
    fill(L, [("ell", 25.6, 26.0, 0.5, 0.5)], C(190, 170, 110), 0.9)
    for i in range(6):
        col = C(176, 52, 44) if i % 2 == 0 else C(218, 204, 176)
        cel(L, [("poly", [(3.0 + i * 5.2, 13.0), (8.2 + i * 5.2, 13.0), (7.6 + i * 5.2, 16.4 + (i % 3) * 0.6), (3.4 + i * 5.2, 16.0)])], col,
            n=(0, -0.3, 1), ol=2.4, bevel=0.5, wear=0.5)
    cel(L, [("rect", 8.0, 9.6, 26.0, 12.0)], C(60, 70, 90), n=(0, 0, 1), ol=2.4, bevel=0.4, wear=0.5)
    for k, x in enumerate((10.0, 14.0, 18.0, 22.0)):
        fill(L, [("rect", x, 10.2, x + 2.2, 11.4)], C(230, 200, 90), 0.9 if k != 2 else 0.25)
    for (x, y) in ((33.0, gy + 0.6), (36.0, gy - 0.6), (1.0, gy + 0.6)):
        cel(L, [("ell", x, y, 1.8, 1.1)], CONC_D, form="sphere", ol=2.4, bevel=0.6, wear=0.4)
    im = finish(render(cv, 334, 300), seed=44, grime=170, streaks=18, wear=140, scratch=20, shadow=(160, 288, 150, 10, 0.55))
    return save(im, ZONE, "shop_ruin")


def quarantine_tent():
    cv = Canvas(40, 30)
    L = cv.L
    gy = 27.0
    cel(L, [("poly", [(2.0, gy), (14.0, 6.0), (30.0, 6.0), (24.0, gy)])], C(220, 216, 204), n=(-0.6, -0.3, 0.75), **kw(wear=0.4))
    cel(L, [("poly", [(24.0, gy), (30.0, 6.0), (38.0, gy - 1.6)])], C(176, 172, 160), n=(0.7, 0.1, 0.7), **kw(wear=0.3))
    cel(L, [("poly", [(8.0, gy), (14.0, 12.0), (19.0, gy)])], C(36, 38, 40), n=(0, 0, 1), ol=3.0, bevel=0.4)
    cel(L, [("poly", [(14.0, 12.0), (19.0, gy), (21.4, gy - 0.8)])], C(206, 202, 190), n=(0.4, 0, 0.9), ol=2.4, bevel=0.5)
    cel(L, [("rect", 23.2, 12.0, 27.8, 18.0), ("rect", 21.6, 13.6, 29.4, 16.4)], C(190, 44, 40), n=(-0.5, -0.3, 0.8), ol=2.4, bevel=0.4)
    for t in (0.35, 0.7):
        seam(L, [(2.0 + 12.0 * t, gy - 21.0 * t), (24.0 + 6.0 * t, gy - 21.0 * t)], w=0.18)
    for k in range(10):
        x0 = 1.0 + k * 3.8
        fill(L, [("poly", [(x0, gy + 1.6), (x0 + 1.9, gy + 1.6), (x0 + 3.2, gy - 0.2), (x0 + 1.3, gy - 0.2)])], HAZ if k % 2 == 0 else DARK, 0.9)
    vcyl(L, 34.0, gy + 2.0, 2.4, 4.6, C(190, 168, 60), ol=3.0, metal=0.5, rust=0.2)
    fill(L, [("poly", [(34.0, gy - 1.4), (35.4, gy + 0.6), (32.6, gy + 0.6)])], DARK, 0.9)
    im = finish(render(cv, 320, 240), seed=45, grime=130, streaks=8, wear=100, scratch=10, shadow=(156, 222, 150, 9, 0.5))
    return save(im, ZONE, "quarantine_tent")


def hazard_barrier():
    cv = Canvas(40, 14)
    L = cv.L
    gy = 13.0
    extrude(L, [(2.0, gy), (38.0, gy), (37.0, gy - 3.0), (3.0, gy - 3.0)], 7.0, CONC, top=CONC * 1.08, **kw(wear=0.6))
    for k in range(10):
        x0 = 3.0 + k * 3.5
        fill(L, [("poly", [(x0, gy - 1.0), (x0 + 1.75, gy - 1.0), (x0 + 3.5, gy - 5.0), (x0 + 1.75, gy - 5.0)])], HAZ if k % 2 == 0 else DARK, 0.9)
    for x in (12.0, 28.0):
        cel(L, [("ell", x, gy - 10.6, 1.0, 0.6)], C(140, 70, 40), form="sphere", ol=2.0, bevel=0.4, metal=0.6, rust=0.4)
    im = finish(render(cv, 400, 140), seed=46, grime=160, streaks=12, wear=170, scratch=20, shadow=(200, 128, 190, 8, 0.5))
    return save(im, ZONE, "hazard_barrier")


def spike_barricade():
    cv = Canvas(40, 20)
    L = cv.L
    gy = 18.0
    for x in (6.0, 20.0, 34.0):
        for sgn in (-1, 1):
            cel(L, [("line", [(x - 4.4 * sgn, gy), (x + 4.4 * sgn, 4.0)], 1.2)], WOOD, ol=OL, bevel=1.0, wear=0.5)
    hcyl(L, (1.0, 10.6), (39.0, 9.6), 1.2, base=WOOD_D, bands=4, ol=OL)
    for x in range(3, 38, 4):
        cel(L, [("poly", [(x, 10.0), (x + 1.2, 10.0), (x + 3.2, 4.8)])], C(170, 170, 176), n=(0, 0, 1), ol=2.4, bevel=0.3, metal=0.9, rust=0.15)
    ink(L, [(2.0, 8.0), (10.0, 6.0), (20.0, 8.6), (30.0, 6.4), (38.0, 8.2)], 0.25, C(150, 150, 150), 0.9)    # wire
    cel(L, [("ell", 20.0, 7.0, 2.2, 2.0)], C(222, 214, 190), form="sphere", ol=2.6, bevel=0.6, wear=0.3)
    fill(L, [("ell", 19.2, 6.8, 0.55, 0.6), ("ell", 20.8, 6.8, 0.55, 0.6)], DARK, 1.0)
    im = finish(render(cv, 320, 160), seed=47, grime=150, streaks=6, wear=120, scratch=14, shadow=(160, 146, 150, 8, 0.5))
    return save(im, ZONE, "spike_barricade")


def raider_totem():
    cv = Canvas(20, 40)
    L = cv.L
    gy = 38.0
    cel(L, [("ell", 10.0, gy, 4.0, 1.4)], C(110, 96, 80), form="sphere", ol=3.0, bevel=0.8)
    cel(L, [("rect", 9.0, 4.0, 11.0, gy)], WOOD, form="cylv", ol=OL, bevel=1.0, wear=0.5)
    for y in (30.0, 26.4):
        cel(L, [("ell", 10.0, y, 5.0, 1.8), ("-ell", 10.0, y, 2.8, 0.9)], RUBBER * 1.2, form="sphere", ol=3.0, bevel=0.8)
    for (y, x) in ((9.0, 10.0), (14.6, 7.4), (14.6, 12.6), (20.0, 10.0)):
        cel(L, [("ell", x, y, 2.2, 2.0)], C(224, 214, 186), form="sphere", ol=3.0, bevel=0.8, wear=0.3)
        fill(L, [("ell", x - 0.8, y - 0.1, 0.5, 0.6), ("ell", x + 0.8, y - 0.1, 0.5, 0.6)], DARK, 1.0)
        fill(L, [("rect", x - 0.8, y + 0.9, x + 0.8, y + 1.3)], DARK, 0.7)
    cel(L, [("poly", [(11.0, 4.4), (18.6, 5.6), (16.6, 7.6), (19.0, 9.8), (11.0, 8.8)])], C(176, 44, 36), n=(0, 0, 1), ol=3.0, bevel=0.6, wear=0.5)
    ink(L, [(9.0, 22.0), (12.0, 24.0), (8.6, 25.0)], 0.25, C(150, 140, 120), 0.9)
    im = finish(render(cv, 130, 260), seed=48, grime=140, streaks=10, wear=110, scratch=10, shadow=(66, 248, 40, 6, 0.55))
    return save(im, ZONE, "raider_totem")


def chem_vat():
    cv = Canvas(32, 32)
    L = cv.L
    gy = 30.0
    top, ry = vcyl(L, 16.0, gy, 12.0, 17.0, C(176, 170, 120), cap=False, metal=0.4, rust=0.15, wear=0.5)
    cel(L, [("ell", 16.0, top, 12.0, ry)], C(90, 94, 80), n=UP, ol=OL, bevel=1.4, metal=0.5)
    cel(L, [("ell", 16.0, top + 0.4, 10.4, ry * 0.8)], C(140, 210, 60), n=UP, ol=2.0, bevel=0.8, gloss=0.5)
    for (x, r) in ((11.0, 1.0), (19.0, 0.8), (15.0, 0.5)):
        fill(L, [("ell", x, top, r, r * 0.6)], C(220, 250, 140), 0.85)
    for y in (top + 6.0, top + 12.0):
        ink(L, [(4.2, y), (27.8, y)], 0.3, C(90, 84, 54), 0.8)
    for k in range(8):
        x0 = 5.0 + k * 2.8
        fill(L, [("poly", [(x0, top + 9.6), (x0 + 1.4, top + 9.6), (x0 + 2.8, top + 7.6), (x0 + 1.4, top + 7.6)])], HAZ if k % 2 == 0 else DARK, 0.9)
    cel(L, [("poly", [(16.0, top + 10.6), (18.4, top + 14.4), (13.6, top + 14.4)])], HAZ, n=(0, 0, 1), ol=2.0, bevel=0.3)
    fill(L, [("rect", 15.7, top + 11.6, 16.3, top + 13.4)], DARK, 1.0)
    ink(L, [(6.0, top + 1.0), (5.4, top + 8.0)], 0.4, C(140, 210, 60), 0.6)  # spill run
    im = finish(render(cv, 260), seed=49, grime=160, streaks=22, wear=130, scratch=16, shadow=(130, 244, 110, 10, 0.55))
    im = glow_px(im, 130, int(top * 8.1), 60, (140, 220, 70), 70)
    return save(im, ZONE, "chem_vat")


def guard_post():
    cv = Canvas(30, 40)
    L = cv.L
    gy = 38.0
    for x in (6.0, 23.0):
        cel(L, [("rect", x, 16.0, x + 1.4, gy)], WOOD_D, form="cylv", ol=OL, bevel=1.0, wear=0.4)
    ink(L, [(6.6, 18.0), (23.6, 35.0)], 0.4, WOOD_D * 0.8, 0.95)
    ink(L, [(23.6, 18.0), (6.6, 35.0)], 0.4, WOOD_D * 0.8, 0.95)
    extrude(L, [(4.0, 17.0), (26.0, 17.0), (26.6, 13.0), (4.6, 13.0)], 7.0, OD, top=OD * 1.08, **kw(rust=0.12, wear=0.5))
    cel(L, [("rect", 6.0, 11.4, 24.0, 13.4)], C(24, 24, 26), n=(0, 0, 1), ol=2.4, bevel=0.3)
    plate(L, [(2.0, 6.6), (28.0, 6.6), (24.0, 2.0), (6.0, 2.0)], 1.0, C(96, 90, 72), top_n=(0, -0.7, 0.7), **kw(rust=0.15, wear=0.5))
    for k in range(7):
        x = 2.4 + k * 3.8
        cel(L, [("ell", x + 1.9, gy - 0.6, 2.2, 1.4)], C(150, 132, 92), form="sphere", ol=2.6, bevel=0.8, wear=0.4)
    im = finish(render(cv, 225, 300), seed=50, grime=140, streaks=12, wear=120, scratch=14, shadow=(112, 290, 100, 9, 0.55))
    return save(im, ZONE, "guard_post")


def slab_ruin():
    cv = Canvas(40, 30)
    L = cv.L
    gy = 28.0
    extrude(L, [(2.0, gy), (16.0, gy), (17.0, gy - 4.0), (3.0, gy - 4.0)], 15.0, CONC, top=CONC * 1.08, **kw(wear=0.6))
    plate(L, [(13.0, gy), (26.0, gy - 12.0), (37.0, gy - 9.0), (35.0, gy)], 2.6, CONC_D, top_n=(0.3, -0.5, 0.8), **kw(wear=0.6))
    for (a, b) in (((5.0, gy - 19.0), (3.6, gy - 25.0)), ((10.0, gy - 19.0), (11.0, gy - 26.0)), ((27.0, gy - 12.0), (29.0, gy - 18.0)), ((31.0, gy - 11.0), (33.6, gy - 15.0))):
        ink(L, [a, b], 0.4, C(130, 70, 40), 1.0)                     # rebar
    ink(L, [(7.0, gy - 12.0), (9.0, gy - 9.0), (8.0, gy - 5.0)], 0.2, C(60, 58, 56), 0.8)
    for (x, y, r) in ((4.0, gy + 0.6, 1.6), (37.0, gy + 0.6, 1.4), (21.0, gy + 1.0, 1.2), (24.0, gy + 0.4, 0.8)):
        cel(L, [("poly", [(x - r, y), (x - r * 0.4, y - r), (x + r, y - r * 0.6), (x + r * 0.8, y + r * 0.2)])], CONC_D, n=UP, ol=2.4, bevel=0.6)
    im = finish(render(cv, 294, 220), seed=51, grime=150, streaks=14, wear=150, scratch=18, shadow=(146, 210, 140, 9, 0.5))
    return save(im, ZONE, "slab_ruin")


def dust_spire():
    cv = Canvas(30, 40)
    L = cv.L
    gy = 38.0
    for (x0, x1, top) in ((8.0, 14.0, 12.0), (13.0, 19.6, 2.0), (18.0, 24.0, 10.0), (4.0, 9.0, 21.0), (22.6, 27.0, 18.0)):
        cx = (x0 + x1) / 2
        cel(L, [("poly", [(x0, gy), (x0 + 0.4, top + 3.0), (cx, top), (x1 - 0.4, top + 3.0), (x1, gy)])], C(232, 168, 72),
            n=(-0.3, -0.2, 1), ol=OL, bevel=1.6, gloss=0.5, rim=0.8)
        cel(L, [("poly", [(cx, top), (x1 - 0.4, top + 3.0), (x1, gy), (cx + 0.6, gy)])], C(190, 120, 50), n=(0.6, 0, 0.8), ol=0, bevel=0.4)
        hline(L, [(x0 + 1.0, gy - 1.0), (cx - 0.4, top + 2.0)], 0.25, C(255, 236, 170), 0.8)
    cel(L, [("ell", 15.0, gy, 13.0, 2.0)], C(150, 110, 70), form="sphere", ol=2.4, bevel=0.6)
    im = finish(render(cv, 240, 320), seed=52, grime=60, streaks=0, wear=40, scratch=6, shadow=(120, 308, 110, 9, 0.5))
    im = glow_px(im, 120, 160, 90, (255, 180, 80), 60)
    return save(im, ZONE, "dust_spire")


def _bunker(opened):
    cv = Canvas(40, 30)
    L = cv.L
    gy = 28.0
    extrude(L, [(1.0, gy), (39.0, gy), (35.0, gy - 6.0), (5.0, gy - 6.0)], 12.0, CONC_D, top=CONC, **kw(wear=0.6))
    for k in range(10):
        x0 = 6.0 + k * 3.0
        fill(L, [("poly", [(x0, gy - 17.0), (x0 + 1.5, gy - 17.0), (x0 + 2.6, gy - 18.4), (x0 + 1.1, gy - 18.4)])], HAZ if k % 2 == 0 else DARK, 0.9)
    if opened:
        cel(L, [("rect", 13.0, gy - 11.0, 27.0, gy)], C(14, 12, 12), n=(0, 0, 1), ol=3.0, bevel=0.3)
        cel(L, [("poly", [(27.0, gy - 11.0), (33.0, gy - 10.0), (33.0, gy + 1.0), (27.0, gy)])], C(96, 102, 106), n=(0.8, 0, 0.6), **kw(metal=0.8, rust=0.15))
    else:
        cel(L, [("rect", 13.0, gy - 11.0, 27.0, gy)], C(96, 102, 106), n=(0, 0.05, 1), **kw(metal=0.8, rust=0.15, wear=0.4))
        for y in (gy - 8.6, gy - 2.6):
            seam(L, [(13.4, y), (26.6, y)], w=0.25)
        cel(L, [("ell", 20.0, gy - 5.6, 2.4, 2.4), ("-ell", 20.0, gy - 5.6, 1.4, 1.4)], C(80, 84, 88), form="sphere", ol=2.4, bevel=0.6, metal=0.9)
        extrude(L, [(23.0, gy - 4.0), (25.6, gy - 4.0), (25.8, gy - 5.0), (23.2, gy - 5.0)], 3.0, HAZ, **kw(ol=2.4, bevel=0.4))
    im = finish(render(cv, 256, 192), seed=53, grime=180, streaks=20, wear=160, scratch=24, dents=[(60, 110, 7)],
                shadow=(128, 182, 126, 10, 0.6))
    if opened:
        im = glow_px(im, 128, 150, 30, (255, 200, 110), 90)
    return save(im, ZONE, "bunker_open" if opened else "bunker")


def bunker():
    return _bunker(False)


def bunker_open():
    return _bunker(True)


def signal_tower():
    cv = Canvas(22, 40)
    L = cv.L
    gy = 38.0
    for (a, b) in (((4.0, gy), (10.0, 6.0)), ((18.0, gy), (12.0, 6.0))):
        cel(L, [("line", [a, b], 0.8)], C(150, 80, 50), ol=3.0, bevel=0.4, metal=0.5, rust=0.2)
    for y in range(9, 37, 4):
        t = (gy - y) / (gy - 6.0)
        xa, xb = 4.0 + 6.0 * t, 18.0 - 6.0 * t
        ink(L, [(xa, y), (xb, y - 4.0)], 0.3, C(120, 70, 46), 0.95)
        ink(L, [(xb, y), (xa, y - 4.0)], 0.3, C(120, 70, 46), 0.95)
    cel(L, [("rect", 10.0, 1.0, 12.0, 7.0)], C(200, 200, 196), form="cylv", ol=2.4, bevel=0.6, metal=0.6)
    fill(L, [("ell", 11.0, 1.0, 1.2, 1.2)], C(255, 90, 60), 0.95)
    cel(L, [("ell", 15.0, 12.0, 2.6, 3.2)], C(196, 190, 180), form="dome", ol=2.6, bevel=0.8)
    im = finish(render(cv, 88, 160), seed=54, grime=100, streaks=6, wear=80, scratch=6, shadow=(44, 152, 26, 4, 0.5))
    im = glow_px(im, 44, 4, 10, (255, 90, 60), 120)
    return save(im, PROPS, "signal_tower")


def medicine_crate():
    cv = Canvas(24, 22)
    L = cv.L
    gy = 20.0
    extrude(L, [(2.0, gy), (20.0, gy), (22.0, gy - 6.0), (4.0, gy - 6.0)], 9.0, C(200, 192, 170), top=C(222, 214, 192), **kw(wear=0.5))
    for x in (2.6, 19.4):
        fill(L, [("rect", x - 0.3, gy - 9.0, x + 0.9, gy)], C(150, 140, 120), 0.8)
    fill(L, [("rect", 9.6, gy - 8.0, 12.4, gy - 1.0), ("rect", 7.6, gy - 6.0, 14.4, gy - 3.0)], RED, 0.95)
    fill(L, [("poly", [(10.6, gy - 14.0), (14.4, gy - 14.0), (15.6, gy - 12.4), (11.8, gy - 12.4)])], RED, 0.9)
    cel(L, [("poly", [(8.0, gy - 15.6), (14.0, gy - 15.6), (14.6, gy - 16.8), (8.6, gy - 16.8)])], GUN, n=UP, ol=2.4, bevel=0.4, metal=0.6)
    im = finish(render(cv, 80, 74), seed=55, grime=120, streaks=4, wear=100, scratch=8, shadow=(40, 68, 34, 5, 0.55))
    return save(im, WORLD, "medicine_crate")


def wall_collapsed():
    cv = Canvas(56, 30)
    L = cv.L
    gy = 26.0
    # standing brick stub (left) + toppled slab (right) + rubble
    extrude(L, [(3.0, gy), (19.0, gy), (19.6, gy - 4.0), (3.6, gy - 4.0)], 15.0, CONC_D, top=CONC, **kw(wear=0.6))
    cel(L, [("poly", [(3.6, gy - 19.0), (7.0, gy - 21.6), (10.0, gy - 19.4), (14.0, gy - 22.4), (19.6, gy - 19.0), (19.6, gy - 16.0), (3.6, gy - 16.0)])],
        CONC, n=UP, ol=OL, bevel=1.6, wear=0.6)
    for y in (gy - 4.0, gy - 8.0, gy - 12.0):
        seam(L, [(3.4, y), (19.0, y)], w=0.2)
        for x in (7.0, 12.0, 16.0):
            seam(L, [(x + (2.0 if int(y) % 8 else 0.0), y), (x + (2.0 if int(y) % 8 else 0.0), y + 4.0)], w=0.16)
    for (a, b) in (((8.0, gy - 21.0), (7.0, gy - 26.0)), ((15.0, gy - 22.0), (17.0, gy - 27.0))):
        ink(L, [a, b], 0.4, C(130, 70, 40), 1.0)
    plate(L, [(22.0, gy - 1.0), (42.0, gy - 9.0), (52.0, gy - 6.0), (34.0, gy + 1.0)], 4.0, CONC_D * 1.05, top_n=(0.25, -0.6, 0.8), **kw(wear=0.6))
    for t in (0.33, 0.66):
        seam(L, [(22.0 + 20.0 * t, gy - 5.0 - 8.0 * t), (34.0 + 18.0 * t, gy - 3.0 - 7.0 * t)], w=0.18)
    for (x, y, r) in ((21.0, gy + 1.0, 1.4), (26.0, gy + 1.6, 1.0), (46.0, gy - 1.0, 1.2), (53.0, gy - 3.0, 0.9), (1.6, gy + 0.8, 1.0)):
        cel(L, [("poly", [(x - r, y), (x - r * 0.4, y - r), (x + r, y - r * 0.6), (x + r * 0.8, y + r * 0.2)])], CONC_D, n=UP, ol=2.4, bevel=0.6)
    im = finish(render(cv, 220, 118), seed=61, grime=150, streaks=10, wear=150, scratch=16, shadow=(110, 108, 104, 8, 0.55))
    return save(im, PROPS, "wall_collapsed")


def fence_broken():
    cv = Canvas(58, 24)
    L = cv.L
    gy = 22.0
    posts = [(4.0, 0.0), (22.0, 0.0), (40.0, 0.18), (54.0, -0.3)]
    tops = []
    for (x, lean) in posts:
        top = (x + lean * 14.0, 6.0)
        tops.append(top)
        cel(L, [("line", [(x, gy), top], 0.9)], C(100, 104, 106), ol=3.0, bevel=0.4, metal=0.7, rust=0.2)
    # chain-link panels (diagonal mesh), one torn and sagging
    for i in range(3):
        (x0, _), (x1, _) = posts[i], posts[i + 1]
        tx0, tx1 = tops[i][0], tops[i + 1][0]
        sag = 3.5 if i == 1 else 0.0
        poly = [(x0, gy - 1.0), (x1, gy - 1.0), (tx1, 7.0 + sag), (tx0, 7.0)]
        fill(L, [("poly", poly)], C(120, 124, 120), 0.12)
        for k in range(-12, 24):
            xa = x0 + k * 1.6
            ink(L, [(xa, gy - 1.0), (xa + 15.0, 7.0 + sag * 0.5)], 0.09, C(156, 158, 150), 0.7)
            ink(L, [(xa + 15.0, gy - 1.0), (xa, 7.0 + sag * 0.5)], 0.09, C(156, 158, 150), 0.7)
        ink(L, [(tx0, 7.0), ((tx0 + tx1) / 2, 7.0 + sag * 1.4), (tx1, 7.0 + sag)], 0.3, C(110, 112, 108), 1.0)
    ink(L, [(26.0, 14.0), (29.0, 18.0), (27.0, 21.0)], 0.12, C(150, 152, 146), 0.8)
    im = finish(render(cv, 232, 96), seed=62, grime=80, streaks=6, wear=60, scratch=0, rim=False, shadow=(116, 90, 110, 4, 0.4))
    return save(im, PROPS, "fence_broken")


def pole_down():
    cv = Canvas(90, 32)
    L = cv.L
    # snapped stump + toppled pole with crossarm, sagging lines
    extrude(L, [(6.0, 22.0), (9.0, 22.0), (9.4, 20.6), (6.4, 20.6)], 9.0, WOOD_D, top=WOOD, **kw())
    cel(L, [("poly", [(6.4, 11.6), (7.4, 9.0), (8.2, 11.0), (9.0, 8.6), (9.4, 11.6)])], WOOD, n=UP, ol=3.0, bevel=0.6)
    hcyl(L, (12.0, 20.0), (78.0, 26.0), 1.7, 1.4, base=WOOD, bands=4, ol=OL, wear=0.5)
    cel(L, [("line", [(70.0, 19.0), (74.0, 31.0)], 0.9)], WOOD_D, ol=3.0, bevel=0.4, wear=0.4)
    for (x, y) in ((70.6, 20.6), (73.4, 29.0)):
        cel(L, [("ell", x, y, 0.9, 0.7)], C(120, 160, 150), form="sphere", ol=2.0, bevel=0.4, gloss=0.4)
    for (a, b, c) in (((70.6, 20.6), (80.0, 26.0), (89.0, 21.0)), ((73.4, 29.0), (82.0, 31.0), (89.0, 29.6))):
        ink(L, [a, b, c], 0.18, C(26, 22, 20), 0.9)
    im = finish(render(cv, 360, 128), seed=63, grime=120, streaks=4, wear=100, scratch=10, shadow=(180, 98, 160, 7, 0.5))
    return save(im, PROPS, "pole_down")


def crater():
    """Floor-level blast crater (no outline rim; it is ground, drawn under units)."""
    w, h = 184, 124
    rr = random.Random(64)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).ellipse((10, 14, w - 10, h - 10), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(8))
    halo = Image.new("RGBA", (w, h), (70, 56, 42, 0))
    halo.putalpha(m.point(lambda v: int(v * 0.55)))
    im = Image.alpha_composite(im, halo)
    pit = Image.new("L", (w, h), 0)
    ImageDraw.Draw(pit).ellipse((36, 34, w - 36, h - 30), fill=255)
    pit = pit.filter(ImageFilter.GaussianBlur(5))
    pl = Image.new("RGBA", (w, h), (40, 30, 22, 0))
    pl.putalpha(pit.point(lambda v: int(v * 0.72)))
    im = Image.alpha_composite(im, pl)
    d = ImageDraw.Draw(im)
    d.arc((40, 40, w - 40, h - 32), 20, 160, fill=(150, 128, 98, 160), width=3)       # lit far-lower lip
    d.arc((36, 34, w - 36, h - 30), 200, 340, fill=(30, 22, 16, 200), width=3)        # shaded near-upper lip
    for _ in range(26):                                                               # thrown clods
        a = rr.uniform(0, math.tau)
        r = rr.uniform(0.75, 0.98)
        x, y = w / 2 + math.cos(a) * (w / 2 - 14) * r, h / 2 + 4 + math.sin(a) * (h / 2 - 14) * r
        s = rr.uniform(1.4, 3.6)
        d.ellipse((x - s + 1, y - s * 0.7 + 1.5, x + s + 1, y + s * 0.7 + 1.5), fill=(20, 14, 10, 120))
        d.ellipse((x - s, y - s * 0.7, x + s, y + s * 0.7), fill=(104, 86, 64, 255))
        d.ellipse((x - s * 0.7, y - s * 0.6, x + s * 0.2, y), fill=(140, 118, 90, 255))
    return save(im, PROPS, "crater")


def extract_pads():
    """Pads keep their approved design, rebuilt to native 192 px (2x) smoothly."""
    for n in ("extract_open", "extract_sealed"):
        src = Image.open(os.path.join(ROOT, "props", n + ".png")).convert("RGBA")
        big = src.resize((src.width * 4, src.height * 4), Image.NEAREST).filter(ImageFilter.GaussianBlur(1.6))
        out = big.resize((src.width * 2, src.height * 2), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 80, 2))
        a = np.asarray(out.getchannel("A"))
        out.putalpha(Image.fromarray(np.where(a > 100, 255, 0).astype(np.uint8)))
        save(out, PROPS, n)


# ======================================================================= sheet
def sheet(path):
    cols = 4
    cell = 320
    rows = (len(_made) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cell, rows * cell), (92, 72, 54, 255))
    # ground-ish backdrop so shading reads like in the match
    for k, (name, im) in enumerate(_made):
        t = im.copy()
        if t.width > cell - 10 or t.height > cell - 10:
            t.thumbnail((cell - 10, cell - 10), Image.LANCZOS)
        x = (k % cols) * cell + (cell - t.width) // 2
        y = (k // cols) * cell + (cell - t.height) // 2
        out.alpha_composite(t, (x, y))
    out.save(path)


ALL = ["plane_wreck", "wreck_car", "wreck", "wreck_truck", "wreck_bus", "tank_wreck", "field_tent", "market_stall",
       "watch_tower", "relay", "vault", "oil_tank", "pipe_rack", "street_lamp", "shop_ruin", "quarantine_tent",
       "hazard_barrier", "spike_barricade", "raider_totem", "chem_vat", "guard_post", "slab_ruin", "dust_spire",
       "bunker", "bunker_open", "signal_tower", "medicine_crate", "wall_collapsed", "fence_broken", "pole_down", "crater", "extract_pads"]

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sh = None
    if "--sheet" in sys.argv:
        sh = sys.argv[sys.argv.index("--sheet") + 1]
        args = [a for a in args if a != sh]
    for name in (args or ALL):
        globals()[name]()
        print("made", name)
    if sh:
        sheet(sh)
