"""Ability, upgrade, evolution and quirk icons (art pass 12), painted with the
weapon / gear engine in its SOFT finish: each idea is one real object (a bell,
a door, a magazine, a drone, a boot...) with at most one simple effect, so the
cards read like the painted armour instead of flat symbols.

IconSet ids (48 / 24 px): ab_<hero>_<a|b>, up_<id>, rec_<id>, quirk_<id>.
WIRE lists what ships; anything else keeps today's art.

    python3 tools/gen_card_icons.py [id ...]      (from game/)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_legendary_icons as L  # noqa: E402
import gen_gear_icons as G  # noqa: E402
import gen_loot_icons as LO  # noqa: E402
import gen_kit_icons as K  # noqa: E402

hx = L.hx
SET = L.SET
bez, crease, tone, rivets = G.bez, G.crease, G.tone, G.rivets
Fr = L.Frame

L.MAT.update({
    "cloud": dict(c=hx("#6a6a72"), spec=0.05, grime=0.2, rust=0.0, metal=0.0),
    "cloud_d": dict(c=hx("#3e3e48"), spec=0.05, grime=0.2, rust=0.0, metal=0.0),
    "bone2": dict(c=hx("#c8bca0"), spec=0.3, grime=0.5, rust=0.0, metal=0.0, pores=1),
    "petal": dict(c=hx("#7a4a6a"), spec=0.3, grime=0.3, rust=0.0, metal=0.0),
    "leaf": dict(c=hx("#5a6a3a"), spec=0.2, grime=0.3, rust=0.0, metal=0.0),
    "honey": dict(c=hx("#c8902a"), spec=0.9, grime=0.2, rust=0.0, metal=0.0),
    "wax2": dict(c=hx("#a88a4a"), spec=0.4, grime=0.4, rust=0.0, metal=0.0),
    "feather": dict(c=hx("#b85a24"), spec=0.2, grime=0.2, rust=0.0, metal=0.0, fur=1),
    "brick": dict(c=hx("#7a5a4a"), spec=0.1, grime=0.6, rust=0.0, metal=0.0, pores=1),
    "mortarj": dict(c=hx("#8a8270"), spec=0.05, grime=0.5, rust=0.0, metal=0.0),
    "door": dict(c=hx("#5a4636"), spec=0.2, grime=0.6, rust=0.0, metal=0.0, grain=1),
    "glow_red": dict(c=hx("#d8402a"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "ghost": dict(c=hx("#9aa8a8"), spec=0.3, grime=0.1, rust=0.0, metal=0.0),
    "mercury": dict(c=hx("#8a3a2a"), spec=1.0, grime=0.0, rust=0.0, metal=0.0),
    "magnet_r": dict(c=hx("#9a2a24"), spec=0.6, grime=0.4, rust=0.2, chip="steel", metal=0.0),
})


L.MAT.update({
    "concrete": dict(c=hx("#6a6660"), spec=0.08, grime=0.6, rust=0.0, metal=0.0, pores=1),
    "dynamite": dict(c=hx("#8a3a2a"), spec=0.12, grime=0.55, rust=0.0, metal=0.0),
    "burlap": dict(c=hx("#7a6646"), spec=0.05, grime=0.55, rust=0.0, metal=0.0, weave=1),
    "candle": dict(c=hx("#c4b796"), spec=0.45, grime=0.35, rust=0.0, metal=0.0),
    "glassfire": dict(c=hx("#c0662c"), spec=0.6, grime=0.1, rust=0.0, glow=1),
    "glassred": dict(c=hx("#8a2a24"), spec=0.6, grime=0.1, rust=0.0, glow=1),
    "clay": dict(c=hx("#36302c"), spec=0.15, grime=0.5, rust=0.0, metal=0.0, pores=1),
    "dial": dict(c=hx("#c8bfa4"), spec=0.3, grime=0.45, rust=0.0, metal=0.0),
    "bluegrey": dict(c=hx("#4a5a66"), spec=0.4, grime=0.55, rust=0.3, chip="steel", metal=0.0),
    "plastic_r": dict(c=hx("#7e2a24"), spec=0.5, grime=0.4, rust=0.0, metal=0.0),
    "bloodbag": dict(c=hx("#6e1a1a"), spec=0.9, grime=0.15, rust=0.0, metal=0.0),
    "bubble": dict(c=hx("#9ab04a"), spec=1.0, grime=0.05, rust=0.0, glow=1),
})


# ------------------------------------------------------------------ props
def flame(ic, cx, cy, s=1.0):
    outer = bez((cx - 9 * s, cy + 8 * s), (cx - 12 * s, cy - 10 * s), (cx, cy - 22 * s), 8) + bez((cx, cy - 22 * s), (cx + 12 * s, cy - 8 * s), (cx + 9 * s, cy + 8 * s), 8) + bez((cx + 9 * s, cy + 8 * s), (cx, cy + 14 * s), (cx - 9 * s, cy + 8 * s), 6)
    ic.poly(outer, "flame", bevel=2.0)
    inner = [(cx + (x - cx) * 0.55, cy + 3 * s + (y - cy) * 0.55) for (x, y) in outer]
    ic.poly(inner, "flame_hot", bevel=1.0)


def ground(ic, cx, cy, rx, ry=None, k=0.45):
    ic.ellipse(cx, cy, rx, ry or rx * 0.18, tone("dust", k, "gnd%d" % int(k * 100)), dome=0.2)


def dust_cloud(ic, cx, cy, s=1.0, mat="dust"):
    for i, (dx, dy, r) in enumerate(((-24, 6, 6), (-16, 2, 9), (20, 4, 7), (-4, -4, 11), (10, 0, 10))):
        ic.ellipse(cx + dx * s, cy + dy * s, r * s, r * s * 0.75, tone(mat, 0.78 + 0.07 * i, "dc%d" % i), dome=0.55)


def smoke(ic, x, y, n=5, dx=3.0, s=1.0, k0=1.3, mat="smoke"):
    for k in range(n):
        ic.ellipse(x + k * dx * s, y - k * 6 * s, (6 + k * 1.8) * s, (5 + k * 1.3) * s, tone(mat, k0 - k * 0.07, "sm%d" % int(k0 * 10 + k)), dome=0.35)


def rubble(ic, pts, mat="stone"):
    for i, (x, y, r) in enumerate(pts):
        ic.poly([(x - r, y), (x - r * 0.3, y - r * 0.9), (x + r, y - r * 0.4), (x + r * 0.7, y + r * 0.6), (x - r * 0.5, y + r * 0.7)],
                tone(mat, 0.75 + 0.12 * (i % 3), "rb%d" % (i % 3)), bevel=0.8, dome=0.6)


def spark(ic, x, y, r=6.0, n=7):
    ic.ellipse(x, y, r * 0.75, r * 0.7, tone("flame", 0.8, "spk"), dome=0.4)
    ic.ellipse(x, y, r * 0.42, r * 0.4, "flame_hot", dome=0.5)
    for k in range(n):
        a = k / n * math.tau + 0.3
        ln = r * (1.2 + 0.5 * (k % 2))
        ic.bar((x + math.cos(a) * r * 0.5, y + math.sin(a) * r * 0.5), (x + math.cos(a) * ln, y + math.sin(a) * ln), 1.3, "flame", w1=0.4)


def arc(ic, p0, p1, seed, segs=6, jit=4.0, w=1.4):
    rng = np.random.default_rng(seed)
    pts = [p0]
    for i in range(1, segs):
        t = i / segs
        pts.append((p0[0] + (p1[0] - p0[0]) * t + rng.uniform(-jit, jit), p0[1] + (p1[1] - p0[1]) * t + rng.uniform(-jit, jit)))
    pts.append(p1)
    for a, b in zip(pts[:-1], pts[1:]):
        ic.bar(a, b, w, "arc")


def cracks(ic, cx, cy, s=1.0, n=6, seed=0):
    rng = np.random.default_rng(int(cx * 3 + cy) + seed)
    for k in range(n):
        a = math.pi * (k / n) * 2 + rng.uniform(-0.3, 0.3)
        x, y = cx, cy
        for j in range(3):
            nx, ny = x + math.cos(a) * 8 * s, y + math.sin(a) * 2.6 * s + rng.uniform(-1, 1)
            ic.bar((x, y), (nx, ny), 1.5 - j * 0.35, "dark")
            x, y = nx, ny
            a += rng.uniform(-0.4, 0.4)


def ring(ic, cx, cy, rx, ry, w, mat, n=32):
    pts = LO.ellipse_pts(cx, cy, rx, ry, n)
    for a, b in zip(pts, pts[1:] + pts[:1]):
        ic.bar(a, b, w, mat, prof="cyl")


def cartridge(ic, x, y, ang, s=1.0, tip="copper", case="brass", ln=36):
    F = Fr(ic, (x, y), ang, s)
    F.bar(0, 0, ln * 0.62, 0, 10, case, prof="cyl")
    F.bar(0, 0, 1.6, 0, 11, tone(case, 0.7, "rim"), prof="cyl")
    F.bar(2.4, 0, 3.4, 0, 9.0, tone(case, 0.5, "ext"), prof="cyl")
    F.bar(ln * 0.62, 0, ln * 0.66, 0, 10, case, w1=8.4, prof="cyl")
    F.bar(ln * 0.66, 0, ln, 0, 8.4, tip, w1=2.4, prof="cyl")
    return F


def mag_pts(cx, cy, s=1.0, curve=0.0, flip=1):
    pts = bez((-8, -30), (-9 + curve, 0), (-6 + curve * 1.6, 30), 8) + bez((10 + curve * 1.6, 28), (9 + curve, 0), (8, -30), 8)
    return [(cx + u * s, cy + v * s * flip) for (u, v) in pts]


def mag(ic, cx, cy, s=1.0, curve=0.0, flip=1):
    ic.poly(mag_pts(cx, cy, s, curve, flip), "gun", bevel=3.0, dome=0.8)
    ic.bar((cx - 7 * s, cy - 32 * s * flip), (cx + 7 * s, cy - 32 * s * flip), 4 * s, "brass", prof="cyl")
    ic.bar((cx - 6 * s, cy - 35 * s * flip), (cx + 6 * s, cy - 35 * s * flip), 3.4 * s, tone("brass", 1.15, "r2"), prof="cyl")
    for k in range(5):
        y = cy + (-20 + k * 10) * s * flip
        ic.bar((cx - 6 * s + curve * k * 0.2, y), (cx + 6 * s + curve * k * 0.2, y), 0.9, tone("gun", 0.6, "rb"))


def boot(ic, x, y, k=1.0, st=None):
    G._combat_boot(ic, x, y, st or G.GENERIC, "boots", k)


def coin(ic, cx, cy, r, mat="gold", ry=None, mark=True):
    ry = ry or r
    ic.ellipse(cx, cy + ry * 0.12, r, ry, tone(mat, 0.6, "edge"), dome=0.5)
    ic.ellipse(cx, cy, r, ry, mat, dome=0.8)
    ic.ellipse(cx, cy, r * 0.78, ry * 0.78, tone(mat, 0.85, "cf"), dome=0.4)
    if mark:
        pts = []
        for k in range(10):
            a = -math.pi / 2 + k * math.pi / 5
            rr = 0.5 if k % 2 == 0 else 0.22
            pts.append((cx + math.cos(a) * r * rr, cy + math.sin(a) * ry * rr))
        ic.poly(pts, tone(mat, 1.2, "cs"), bevel=0.6)


def knife(ic, x, y, ang, s=1.0, mat="blade", grip="leatherb"):
    F = Fr(ic, (x, y), ang, s)
    F.bar(-2, 0, 22, 0, 8.0, grip, prof="cyl")
    for u in (4, 10, 16):
        F.bar(u, -4, u, 4, 1.0, tone(grip, 0.6, "kg"))
    F.bar(-4, 0, -1, 0, 9.0, "steel", prof="cyl")
    F.bar(22, -8, 22, 8, 3.6, "brass", prof="cyl")
    F.poly([(24, -4.6), (66, -3.6), (78, 0.6), (66, 4.6), (24, 4.6)], mat, bevel=1.8)
    F.bar(28, -0.8, 60, -0.6, 1.2, tone(mat, 0.62, "fl"))
    F.edge(26, 4.2, 70, 3.6, 0.5)
    return F


def drone(ic, cx, cy, s=1.0, light="glow_red", hot=False):
    """3/4 quadcopter: carbon arms out to four motor cans with blurred prop
    discs, olive shell with a camera pod and a status light."""
    mots = ((-22, -9), (22, -9), (-26, 11), (26, 11))
    for (dx, dy) in mots:
        ic.bar((cx, cy), (cx + dx * s, cy + dy * s), 3.4 * s, "gun", prof="cyl")
    for (dx, dy) in mots:
        mx, my = cx + dx * s, cy + dy * s
        ic.bar((mx, my + 2 * s), (mx, my - 3 * s), 6 * s, "ember" if hot else "dark", prof="cyl")
        ic.ellipse(mx, my - 4 * s, 13 * s, 3.4 * s, tone("smoke", 0.75, "prop"), dome=0.25)
        ic.bar((mx - 12 * s, my - 4 * s), (mx + 12 * s, my - 4 * s), 1.4 * s, tone("dark", 1.3, "bl"))
        ic.ellipse(mx, my - 4.5 * s, 2.2 * s, 1.6 * s, "steel", dome=0.9)
    ic.poly([(cx - 11 * s, cy - 7 * s), (cx + 11 * s, cy - 7 * s), (cx + 14 * s, cy + 5 * s), (cx + 8 * s, cy + 9 * s), (cx - 8 * s, cy + 9 * s), (cx - 14 * s, cy + 5 * s)], "olivep", bevel=2.4, dome=0.9)
    ic.bar((cx - 9 * s, cy - 2 * s), (cx + 9 * s, cy - 2 * s), 1.0, tone("olivep", 0.6, "seam"))
    ic.ellipse(cx, cy + 9 * s, 5 * s, 4.4 * s, "dark", dome=0.7)
    ic.ellipse(cx, cy + 9.4 * s, 2.6 * s, 2.4 * s, "lens", dome=0.8)
    ic.ellipse(cx + 8 * s, cy - 4 * s, 1.4 * s, 1.4 * s, light, dome=0.6)
    if hot:
        for (dx, dy) in mots:
            smoke(ic, cx + dx * s, cy + dy * s - 8 * s, n=2, dx=1.5, s=0.6 * s, k0=1.25)


def bell(ic, cx, cy, s=1.0, mat="brass"):
    body = bez((cx - 7 * s, cy - 22 * s), (cx - 11 * s, cy - 6 * s), (cx - 15 * s, cy + 12 * s), 6) + [(cx - 23 * s, cy + 18 * s), (cx + 23 * s, cy + 18 * s)] + bez((cx + 15 * s, cy + 12 * s), (cx + 11 * s, cy - 6 * s), (cx + 7 * s, cy - 22 * s), 6)
    ic.poly(body, mat, bevel=5.0, dome=0.95)
    ic.ellipse(cx, cy - 23 * s, 8 * s, 4 * s, tone(mat, 1.1, "crn"), dome=0.8)
    for y in (-14, 6):
        ic.bar((cx - (10 + y * 0.25) * s, cy + y * s), (cx + (10 + y * 0.25) * s, cy + y * s), 1.4 * s, tone(mat, 0.7, "bnd"))
    ic.bar((cx - 22 * s, cy + 16 * s), (cx + 22 * s, cy + 16 * s), 2.6 * s, tone(mat, 1.2, "lip"))
    ic.ellipse(cx, cy + 18.4 * s, 22 * s, 3.4 * s, tone(mat, 0.35, "mouth"), dome=-0.3)
    ic.ellipse(cx + 2 * s, cy + 21 * s, 4.4 * s, 4.4 * s, "gun", dome=0.9)


# ---------------------------------------------------------------- abilities
def ab_rook_a(ic, st):  # Rattle Rush: braced sprint behind a stop-sign ram shield
    dust_cloud(ic, 26, 82, 1.1)
    oct_ = [(48 + math.cos(math.pi / 8 + k * math.pi / 4) * 36, 46 + math.sin(math.pi / 8 + k * math.pi / 4) * 38) for k in range(8)]
    ic.poly([(x + 3, y + 3) for (x, y) in oct_], tone("gun", 0.6, "sb"), bevel=2.0)
    ic.poly(oct_, "ash", bevel=2.4, dome=0.6)
    inner = [(48 + (x - 48) * 0.86, 46 + (y - 46) * 0.86) for (x, y) in oct_]
    ic.poly(inner, "redp", bevel=1.6, dome=0.7)
    for (x0, x1, y) in ((28, 66, 42), (30, 62, 50)):
        ic.bar((x0, y), (x1, y), 3.4, tone("ash", 0.85, "txt"))
    ic.patch(64, 64, 14, 10, 0.4, "rust")
    for (x, y) in ((48, 16), (48, 76), (22, 46), (74, 46)):
        ic.rivet(x, y, 1.8)
    ic.ellipse(36, 30, 4, 3, tone("redp", 0.5, "dent"), dome=-0.6)
    ic.scratches(count=18)


def ab_rook_b(ic, st):  # Short Charge: three taped dynamite sticks, short lit fuse
    F = Fr(ic, (14, 74), -28, 1.0)
    for v in (-11, 11, 0):
        F.bar(0, v, 58, v, 11, "dynamite", prof="cyl")
        F.ell(58, v, 1.8, 5.2, tone("paper", 0.85, "dcap"))
    for u in (12, 44):
        F.bar(u, -17, u, 17, 7, "tape", prof="cyl")
    F.bar(20, -3, 36, -3, 6.0, tone("paper", 1.1, "lbl"))
    F.bar(59, 0, 66, -2, 1.8, "twine", prof="cyl")
    F.bar(66, -2, 72, -8, 1.8, "twine", prof="cyl")
    spark(ic, *F.P(73, -9), r=8)
    ic.scratches(count=8)


def ab_vesper_a(ic, st):  # Vial Shot: thick toxin dart-vial, needle forward
    for k in range(3):
        ic.ellipse(18 + k * 6, 82 - k * 3, 7 + k, 5 + k, tone("gel_poison", 0.55 + 0.05 * k, "pw%d" % k), dome=0.4)
    F = Fr(ic, (20, 76), -40, 1.0)
    F.bar(-6, 0, 2, 0, 18, "rubber", prof="cyl")
    F.bar(0, 0, 50, 0, 22, "glassd", prof="cyl")
    F.bar(3, 0, 40, 0, 17, "gel_poison", prof="cyl")
    F.ell(40, 0, 1.6, 8.0, tone("gel_poison", 1.3, "men"))
    for u in (12, 20, 28, 36):
        F.bar(u, -10, u, -6, 0.8, tone("glassw", 1.2, "tick"))
    F.bar(6, -7, 46, -7, 1.6, "frost")
    F.bar(50, 0, 60, 0, 20, "brass", prof="cyl")
    F.bar(60, 0, 64, 0, 10, "brass", w1=6, prof="cyl")
    F.bar(64, 0, 76, 0, 2.4, "steel", w1=0.8, prof="cyl")


def ab_vesper_b(ic, st):  # Smoke Vial: smoke grenade venting a grey cloud
    smoke(ic, 44, 34, n=5, dx=5.0, s=1.0, k0=1.35)
    ground(ic, 36, 88, 20)
    ic.bar((36, 48), (36, 86), 28, "olivep", prof="cyl")
    ic.ellipse(36, 86, 14, 4, tone("olivep", 0.6, "bt"), dome=0.4)
    ic.bar((36, 60), (36, 72), 28.6, tone("olivep", 0.72, "band"), prof="cyl")
    for y in (63, 66.5, 70):
        ic.bar((27, y), (43, y), 0.9, "stencil")
    ic.ellipse(36, 48, 14, 4.4, tone("olivep", 1.15, "top"), dome=0.6)
    ic.bar((36, 40), (36, 48), 8, "steel", prof="cyl")
    ic.poly([(40, 40), (46, 40), (50, 76), (46, 78)], "steel", bevel=0.8)
    ring(ic, 26, 38, 6, 5, 1.4, "steel")
    ic.scratches(count=10)


def ab_pebble_a(ic, st):  # Maul Slam: sledge head driving into a cracking slab
    ic.poly([(2, 74), (94, 70), (94, 92), (2, 94)], "concrete", bevel=2.0, dome=0.5)
    ic.poly([(2, 70), (94, 66), (94, 72), (2, 76)], tone("concrete", 1.15, "top"), bevel=0.8)
    cracks(ic, 60, 76, 1.4, n=7)
    dust_cloud(ic, 60, 70, 1.0)
    ic.bar((10, 8), (50, 58), 6.5, "wood", prof="cyl")
    ic.bar((10, 8), (20, 20), 7.2, "tape", prof="cyl")
    F = Fr(ic, (54, 62), math.degrees(math.atan2(50, 40)), 1.0)
    F.poly([(-10, -22), (12, -22), (12, 22), (-10, 22)], "gun", bevel=2.6, dome=0.7)
    F.poly([(12, -22), (16, -19), (16, 19), (12, 22)], tone("steel", 1.1, "face"), bevel=0.8)
    F.bar(-4, -22, -4, 22, 1.0, tone("gun", 0.6, "bevl"))
    rubble(ic, [(30, 58, 3.4), (84, 54, 3.0), (78, 44, 2.2), (24, 66, 2.4), (90, 62, 2.0)], "concrete")
    ic.scratches(count=12)


def ab_pebble_b(ic, st):  # Quake Stomp: boot stamped into a slab that breaks apart
    ic.poly([(4, 76), (44, 72), (48, 92), (6, 92)], "concrete", bevel=2.0, dome=0.5)
    ic.poly([(52, 70), (94, 76), (92, 92), (50, 92)], tone("concrete", 0.86, "sl2"), bevel=2.0, dome=0.5)
    ic.poly([(44, 72), (52, 70), (50, 92), (48, 92)], "dark", bevel=0.5)
    dust_cloud(ic, 22, 72, 0.9)
    dust_cloud(ic, 78, 72, 0.8)
    boot(ic, 54, 74, 1.1)
    rubble(ic, [(14, 62, 3.0), (88, 60, 2.6), (8, 70, 2.0), (94, 68, 2.0)], "concrete")


def ab_juno_a(ic, st):  # Overload: car battery, jumper clamps arcing
    ic.poly([(14, 40), (62, 40), (62, 88), (14, 88)], "rubber", bevel=2.0, dome=0.6)
    ic.poly([(14, 40), (62, 40), (78, 30), (30, 30)], tone("rubber", 1.45, "bt"), bevel=1.6, dome=0.5)
    ic.poly([(62, 40), (78, 30), (78, 78), (62, 88)], tone("rubber", 0.75, "bs"), bevel=1.6, dome=0.5)
    ic.poly([(18, 52), (58, 52), (58, 70), (18, 70)], "hazardw", bevel=1.0)
    for y in (57, 61, 65):
        ic.bar((22, y), (50 - (y % 4) * 2, y), 1.0, "ink")
    for (x, y, cap) in ((30, 34, "plastic_r"), (58, 32, "rubber")):
        ic.bar((x, y + 2), (x, y - 3), 6, "ash", prof="cyl")
        ic.ellipse(x, y - 3, 3, 1.4, tone("ash", 1.2, "tt"), dome=0.5)
    for (p, c, col) in ((((30, 30), (34, 12), (54, 10)), "plastic_r", "copper"), (((58, 28), (70, 22), (70, 12)), "rubber", "copper")):
        a, b, e = p
        pts = bez(a, b, e, 8)
        for q0, q1 in zip(pts[:-1], pts[1:]):
            ic.bar(q0, q1, 3.6, c, prof="cyl")
    F = Fr(ic, (54, 10), 10, 1.0)
    F.poly([(0, -4), (12, -5), (14, 0), (12, 5), (0, 4)], "plastic_r", bevel=1.0)
    F.bar(12, -3, 20, -2, 2.0, "copper")
    F.bar(12, 3, 20, 2, 2.0, "copper")
    F2 = Fr(ic, (70, 12), 170, 1.0)
    F2.poly([(0, -4), (12, -5), (14, 0), (12, 5), (0, 4)], "rubber", bevel=1.0)
    F2.bar(12, -3, 18, -2, 2.0, "copper")
    F2.bar(12, 3, 18, 2, 2.0, "copper")
    spark(ic, 64, 10, r=7)
    ic.scratches(count=10)


def ab_juno_b(ic, st):  # Static Cage: tesla coil throwing arcs
    ground(ic, 48, 90, 34)
    ic.poly([(18, 78), (78, 78), (84, 90), (12, 90)], "plank", bevel=2.0, dome=0.6)
    ic.poly([(18, 74), (78, 74), (78, 78), (18, 78)], tone("plank", 1.15, "pt"), bevel=0.6)
    ic.bar((48, 34), (48, 76), 20, "copper", prof="cyl")
    if L._detail():
        for y in range(36, 76, 2):
            ic.bar((38.5, y), (57.5, y + 0.8), 0.6, tone("copper", 0.55, "w"))
    ic.bar((48, 32), (48, 36), 22, "dark", prof="cyl")
    ic.ellipse(48, 26, 28, 9, "steel", dome=0.95)
    ic.ellipse(48, 24, 16, 3.6, tone("steel", 1.25, "tt"), dome=0.5)
    arc(ic, (22, 26), (4, 8), 3, jit=3)
    arc(ic, (74, 26), (92, 14), 5, jit=3)
    arc(ic, (62, 20), (78, 2), 7, segs=4, jit=3)
    arc(ic, (30, 30), (10, 44), 9, segs=4, jit=3)
    ic.scratches(count=8)


def ab_cinder_a(ic, st):  # Field Draught: canvas-covered canteen with a red cross
    body = bez((24, 30), (16, 56), (26, 88), 10) + bez((70, 88), (80, 56), (72, 30), 10)
    ic.poly(body, "steel", bevel=4.0, dome=0.95)
    cov = bez((22, 44), (16, 64), (26, 88), 8) + bez((70, 88), (80, 64), (74, 44), 8)
    ic.poly(cov, "canvas", bevel=3.0, dome=0.85)
    G.stitch(ic, [(23, 46), (48, 48), (73, 46)], 1.6)
    ic.bar((48, 58), (48, 80), 7, "redp")
    ic.bar((37, 69), (59, 69), 7, "redp")
    for x in (30, 66):
        ic.ellipse(x, 52, 2.4, 2.4, "brass", dome=0.9)
    ic.bar((48, 18), (48, 30), 16, "steel", prof="cyl")
    ic.bar((48, 14), (48, 20), 18, "gun", prof="cyl")
    for k in range(5):
        ic.ellipse(60 + k * 3, 18 + k * 2.6, 1.4, 1.1, "steel", dome=0.8)
    ic.scratches(count=12)


def ab_cinder_b(ic, st):  # Smoke Censer: pierced brass censer on chains, smoking
    for (x0, x1) in ((48, 30), (48, 66), (48, 48)):
        for k in range(8):
            t0, t1 = k / 8, (k + 0.6) / 8
            ic.bar((x0 + (x1 - x0) * t0, 4 + 32 * t0), (x0 + (x1 - x0) * t1, 4 + 32 * t1), 1.6, "steel", prof="cyl")
    smoke(ic, 40, 34, n=3, dx=-2, s=0.8, k0=1.35)
    smoke(ic, 58, 32, n=3, dx=2, s=0.8, k0=1.3)
    ic.ellipse(48, 62, 26, 18, "brass", dome=0.95)
    ic.bar((22, 60), (74, 60), 3.0, tone("brass", 1.2, "rim"))
    ic.ellipse(48, 48, 20, 12, tone("brass", 0.9, "lid"), dome=0.95)
    for (x, y) in ((38, 46), (48, 42), (58, 46), (42, 52), (54, 52)):
        ic.ellipse(x, y, 2.0, 1.6, "dark", dome=-0.4)
        ic.ellipse(x, y + 0.3, 1.0, 0.8, "ember", dome=0.4)
    ic.bar((48, 78), (48, 86), 12, tone("brass", 0.8, "ft"), w1=18, prof="cyl")
    ic.scratches(count=10)


def ab_quill_a(ic, st):  # Dissect: scalpel and a red-marked toe tag
    F = Fr(ic, (20, 30), 22, 1.0)
    F.poly([(0, -14), (30, -14), (36, -8), (36, 8), (30, 14), (0, 14)], "paper", bevel=1.2, dome=0.5)
    F.ell(6, 0, 3.4, 3.4, "brass")
    F.ell(6, 0, 1.6, 1.6, "dark")
    F.bar(14, -7, 28, 7, 2.2, "redp")
    F.bar(14, 7, 28, -7, 2.2, "redp")
    ic.bar(F.P(3, 0), (4, 12), 1.0, "twine")
    S = Fr(ic, (16, 88), -42, 1.15)
    S.bar(0, 0, 44, 0, 6, "steel", prof="box")
    for u in range(6, 30, 4):
        S.bar(u, -2.4, u, 2.4, 0.8, tone("steel", 0.6, "kn"))
    S.poly([(44, -3), (58, -3.4), (70, 1.0), (60, 3.4), (44, 3)], "blade", bevel=1.0)
    S.edge(46, 3.0, 66, 2.0, 0.6)


def ab_quill_b(ic, st):  # Long Lunge: rifle muzzle with a long fixed bayonet
    for k in range(4):
        ic.ellipse(12 + k * 7, 86 - k * 4, 6 + k, 3.4 + k * 0.5, tone("dust", 0.7 + 0.05 * k, "ld%d" % k), dome=0.4)
    F = Fr(ic, (4, 82), -34, 1.0)
    F.bar(0, 0, 22, 0, 13, "wood", prof="box")
    F.bar(0, 0, 36, 0, 6.4, "gun", prof="cyl")
    F.bar(22, -6, 26, -6, 6, "gun")
    F.poly([(26, -7), (32, -12), (34, -7)], "gun", bevel=0.6)
    F.bar(30, 4, 38, 4, 5, "steel", prof="cyl")
    F.bar(36, -6, 36, 8, 3.6, "steel", prof="cyl")
    F.poly([(38, -4.4), (100, -3.4), (112, 0.6), (100, 4.6), (38, 4.6)], "blade", bevel=1.6)
    F.bar(42, -0.6, 90, -0.4, 1.3, tone("blade", 0.6, "fl"))
    F.edge(42, 4.2, 104, 3.2, 0.5)
    ic.scratches(count=8)


def ab_nyx_a(ic, st):  # Blade Rush: knife at the end of a pale slash arc
    pts = bez((6, 70), (30, 16), (86, 12), 14)
    for i, (a, b) in enumerate(zip(pts[:-1], pts[1:])):
        ic.bar(a, b, 1.0 + i * 0.45, tone("ash", 0.75 + i * 0.02, "sl%d" % i))
    knife(ic, 30, 86, -38, 1.25)
    ic.scratches(count=6)


def ab_nyx_b(ic, st):  # Shadow Slip: cracked smoke pellet pouring dark smoke
    for i, (x, y, r) in enumerate(((22, 58, 13), (36, 44, 15), (56, 34, 16), (72, 46, 13), (62, 58, 12), (28, 30, 10), (78, 26, 10))):
        ic.ellipse(x, y, r, r * 0.82, tone("smoke", 0.5 + 0.05 * (i % 4), "ds%d" % i), dome=0.4)
    ground(ic, 48, 88, 22)
    ic.ellipse(48, 74, 16, 14, "clay", dome=0.95)
    ic.poly([(40, 66), (48, 60), (56, 66), (50, 70)], "dark", bevel=0.5)
    ic.ellipse(48, 66, 3.6, 2.2, "ember", dome=0.4)
    ic.bar((46, 74), (52, 82), 0.9, "dark")
    ic.bar((52, 82), (50, 86), 0.9, "dark")


def ab_helm_a(ic, st):  # Drone Call: drone lifting off, handheld radio in front
    drone(ic, 56, 30, 1.45)
    F = Fr(ic, (28, 88), -78, 1.0)
    F.poly([(0, -11), (36, -11), (38, -9), (38, 9), (36, 11), (0, 11)], "olivep", bevel=2.0, dome=0.8)
    F.bar(36, 6, 58, 6, 3.4, "rubber", w1=2.4, prof="cyl")
    F.bar(4, -6, 18, -6, 9, "dark")
    if L._detail():
        for u in range(5, 18, 3):
            F.bar(u, -10, u, -2, 0.8, tone("dark", 1.6, "gr"))
    F.ell(28, -2, 3.4, 3.4, "plastic_r")
    F.bar(22, 6, 32, 6, 3, tone("olivep", 0.6, "kn"))
    ic.scratches(count=8)


def ab_helm_b(ic, st):  # Overdrive: drone with motors running hot
    drone(ic, 48, 50, 1.65, hot=True)
    ic.scratches(count=8)


# ------------------------------------------------------------- upgrades
def up_aftershock(ic, st):  # dud mortar round buried in cracked ground
    ic.ellipse(48, 78, 44, 14, tone("dust", 0.55, "cr"), dome=0.4)
    cracks(ic, 48, 80, 1.5, n=8)
    F = Fr(ic, (40, 82), -64, 1.0)
    F.bar(0, 0, 34, 0, 20, "olivep", prof="cyl")
    F.bar(34, 0, 54, 0, 20, "olivep", w1=5, prof="cyl")
    F.bar(24, 0, 28, 0, 20.4, "hazardw", prof="cyl")
    F.bar(52, 0, 62, 0, 6, "brass", w1=4, prof="cyl")
    ic.poly([(18, 82), (36, 76), (52, 78), (70, 84), (56, 90), (26, 90)], "dust", bevel=3.0, dome=0.7)
    smoke(ic, 64, 30, n=4, dx=3, s=1.0, k0=1.3)
    rubble(ic, [(20, 74, 2.6), (78, 76, 2.4), (72, 70, 1.8)], "concrete")
    ic.scratches(count=10)


def up_back_way_out(ic, st):  # steel door kicked open, daylight spilling out
    ic.poly([(14, 6), (82, 6), (82, 92), (14, 92)], "concrete", bevel=2.0, dome=0.4)
    ic.poly([(26, 14), (72, 14), (72, 88), (26, 88)], tone("paper", 1.35, "day"), bevel=1.0, dome=0.3)
    ic.poly([(26, 88), (72, 88), (88, 96), (8, 96)], tone("paper", 1.1, "spill"), bevel=1.0, dome=0.3)
    ic.poly([(26, 14), (44, 6), (44, 96), (26, 88)], "plate", bevel=1.8, dome=0.6)
    ic.bar((28, 52), (42, 50), 3.4, "steel", prof="cyl")
    ic.patch(34, 30, 8, 10, 0.1, "rust")
    for y in (20, 80):
        ic.bar((24, y), (28, y), 4, "gun")
    ic.bar((26, 14), (72, 14), 2.4, tone("concrete", 0.6, "lintel"))
    ic.scratches(count=12)


def up_bayonet(ic, st):  # M7-style bayonet with muzzle ring and scabbard behind
    F0 = Fr(ic, (20, 86), -50, 1.0)
    F0.bar(0, 0, 70, 0, 10, "olivep", w1=7, prof="cyl")
    F0.bar(0, 0, 8, 0, 11, "steel", prof="cyl")
    F = Fr(ic, (8, 72), -38, 1.05)
    F.bar(0, 0, 26, 0, 10, "rubber", prof="box")
    for u in (4, 9, 14, 19):
        F.bar(u, -5, u, 5, 1.0, tone("rubber", 1.5, "gr"))
    F.bar(-3, 0, 1, 0, 11, "steel", prof="cyl")
    F.bar(26, -9, 26, 9, 4, "steel", prof="cyl")
    F.ell(26, -11, 4.4, 4.4, "steel")
    F.ell(26, -11, 2.4, 2.4, "dark")
    F.poly([(28, -5), (78, -4), (90, 0.6), (78, 5), (28, 5)], "blade", bevel=1.6)
    F.bar(32, -0.6, 72, -0.4, 1.3, tone("blade", 0.6, "fl"))
    F.edge(32, 4.4, 84, 3.6, 0.5)
    ic.scratches(count=8)


def up_bell_tower(ic, st):  # tarnished bell hung in a timber yoke
    ic.bar((6, 14), (90, 14), 11, "wood", prof="box")
    for x in (12, 84):
        ic.bar((x, 14), (x, 94), 8, tone("wood", 0.8, "post"), prof="box")
        ic.rivet(x, 14, 1.8)
    bell(ic, 48, 46, 1.55, "brass")
    ic.patch(36, 40, 8, 10, 0.2, tone("tealp", 0.9, "verd"))
    for k in range(6):
        ic.bar((74, 22 + k * 7), (75, 28 + k * 7), 2.4, "rope", prof="cyl")
    ic.scratches(count=10)


def up_burn_it_down(ic, st):  # molotov: bottle of fuel, burning rag in the neck
    ground(ic, 50, 90, 22)
    body = [(34, 50), (64, 50), (68, 58), (68, 88), (30, 88), (30, 58)]
    LO.bottle(ic, body, "liq_firebrand", (49, 26, 50, 11), 26, 62, 7)
    ic.bar((48, 26), (40, 14), 8, "cloth", prof="cyl")
    ic.bar((46, 26), (56, 40), 4.4, "cloth", w1=2, prof="cyl")
    flame(ic, 38, 16, 0.75)
    LO.label(ic, 36, 66, 62, 78, seed=5)


def up_cool_head(ic, st):  # brass stopwatch with frost creeping over it
    ic.bar((48, 6), (48, 16), 10, "brass", prof="cyl")
    ring(ic, 48, 6, 6, 4, 2.0, "brass")
    ic.bar((62, 14), (68, 20), 5, "brass", prof="cyl")
    ic.ellipse(48, 56, 36, 36, "brass", dome=0.95)
    ic.ellipse(48, 56, 30, 30, "dial", dome=0.4)
    for k in range(12):
        a = k / 12 * math.tau
        r0 = 25 if k % 3 else 22
        ic.bar((48 + math.cos(a) * r0, 56 + math.sin(a) * r0), (48 + math.cos(a) * 28, 56 + math.sin(a) * 28), 1.4 if k % 3 == 0 else 0.8, "ink")
    ic.bar((48, 56), (48, 34), 1.8, "ink", w1=0.8)
    ic.bar((48, 56), (62, 64), 1.4, "redp", w1=0.6)
    ic.ellipse(48, 56, 2.6, 2.6, "brass", dome=0.9)
    for (x, y, r) in ((24, 74, 8), (34, 84, 7), (20, 60, 5), (60, 86, 5)):
        ic.ellipse(x, y, r, r * 0.8, tone("frost", 0.82, "rime"), dome=0.3)
    ic.bar((26, 40), (34, 32), 2.0, "frost")
    ic.scratches(count=8)


def up_deep_mag(ic, st):  # drum magazine with feed tower
    ic.poly([(18, 10), (36, 10), (40, 36), (22, 40)], "gun", bevel=2.0, dome=0.7)
    ic.bar((22, 10), (34, 10), 4, "brass", prof="cyl")
    ic.bar((24, 6), (32, 6), 3.4, tone("brass", 1.1, "r2"), prof="cyl")
    ic.ellipse(52, 60, 38, 34, tone("gun", 0.7, "drb"), dome=0.6)
    ic.ellipse(48, 58, 36, 32, "gun", dome=0.9)
    ring(ic, 48, 58, 28, 25, 1.4, tone("gun", 0.6, "rib"))
    ring(ic, 48, 58, 18, 16, 1.4, tone("gun", 1.25, "rib2"))
    ic.ellipse(48, 58, 9, 8, "steel", dome=0.9)
    ic.bar((42, 58), (54, 58), 3.0, "steel", prof="cyl")
    ic.bar((48, 52), (48, 64), 1.0, "dark")
    ic.patch(70, 44, 10, 8, 0.6, "rust")
    ic.scratches(count=16)


def up_double_cross(ic, st):  # dagger driven through a playing card
    F = Fr(ic, (48, 52), -14, 1.0)
    F.poly([(-22, -30), (22, -30), (22, 30), (-22, 30)], tone("paper", 1.25, "card"), bevel=1.2, dome=0.4)
    for (u, v, r) in ((-14, -20, 3.2), (14, 20, 3.2), (0, 0, 7.5)):
        F.poly([(u, v - r * 1.3), (u + r, v), (u, v + r * 1.3), (u - r, v)], "redp", bevel=0.6)
    knife(ic, 20, 90, -60, 1.2)
    F2 = Fr(ic, (20, 90), -60, 1.2)
    F2.poly([(52, -4.4), (66, -3.6), (78, 0.6), (66, 4.6), (52, 4.4)], "blade", bevel=1.6)
    ic.scratches(count=6)


def up_dust_rounds(ic, st):  # cartridges with amber dust-crystal tips
    for (x, y, a) in ((14, 84, -62), (30, 88, -52), (48, 90, -40)):
        F = cartridge(ic, x, y, a, 1.25, tip="amber", ln=40)
        F.ell(34, -1.2, 1.2, 1.6, tone("amber", 1.5, "tg"))
    for (x, y) in ((70, 26, ), (80, 40), (64, 14), (86, 22)):
        ic.ellipse(x, y, 1.6, 1.6, tone("amber", 1.3, "mote"), dome=0.5)


def up_dust_runner(ic, st):  # running boot kicking up a dust trail
    dust_cloud(ic, 74, 74, 1.1)
    dust_cloud(ic, 86, 64, 0.6)
    F = Fr(ic, (46, 70), -12, 1.0)
    G._combat_boot(ic, 46, 72, G.GENERIC, "boots", 1.05)


def up_field_notes(ic, st):  # battered leather notebook with a pencil
    ic.poly([(18, 18), (74, 12), (82, 82), (24, 90)], tone("paper", 0.95, "pg"), bevel=1.0, dome=0.3)
    ic.poly([(16, 14), (72, 8), (78, 78), (20, 86)], "leatherb", bevel=3.0, dome=0.8)
    ic.bar((60, 8), (66, 80), 3.4, tone("dark", 1.5, "elastic"))
    G.stitch(ic, [(20, 18), (68, 13), (74, 76), (24, 82), (20, 18)], 1.8)
    ic.patch(34, 40, 14, 10, -0.1, tone("leatherb", 1.3, "scuff"))
    F = Fr(ic, (14, 76), -40, 1.0)
    F.bar(0, 0, 60, 0, 6, "signal", prof="cyl")
    F.bar(-6, 0, 0, 0, 6.4, "brass", prof="cyl")
    F.bar(-10, 0, -6, 0, 6, "plastic_r", prof="cyl")
    F.bar(60, 0, 68, 0, 6, "plank", w1=2.0, prof="cyl")
    F.bar(68, 0, 70, 0, 2.0, "dark", w1=0.6, prof="cyl")
    ic.scratches(count=8)


def up_firewalk(ic, st):  # boot on scorched ground, flames licking the sole
    ic.ellipse(48, 84, 44, 9, "scorch", dome=0.3)
    for (x, s) in ((20, 0.7), (78, 0.75)):
        flame(ic, x, 82, s)
    boot(ic, 50, 76, 1.05, dict(G.GENERIC, leather=tone("leatherb", 0.75, "sc")))
    flame(ic, 46, 86, 0.65)
    for (x, y) in ((30, 60), (70, 52), (24, 46)):
        ic.ellipse(x, y, 1.4, 1.4, "ember", dome=0.5)


def up_harder_hit(ic, st):  # heavy rusted pipe wrench
    F = Fr(ic, (14, 86), -45, 1.0)
    F.bar(0, 0, 70, 0, 14, "redp", prof="box")
    F.bar(0, 0, 10, 0, 15, "rubber", prof="box")
    F.poly([(66, -14), (98, -14), (100, 0), (66, 2)], "gun", bevel=2.0, dome=0.7)
    F.poly([(74, 6), (96, 6), (98, 18), (72, 18)], "gun", bevel=2.0, dome=0.7)
    if L._detail():
        for u in range(72, 96, 3):
            F.bar(u, 1, u + 1, 5, 0.8, tone("gun", 0.6, "teeth"))
    F.bar(64, 4, 74, 4, 8, "steel", prof="cyl")
    F.ell(52, 0, 2.0, 2.0, "steel")
    ic.patch(36, 64, 12, 6, -0.8, "rust")
    ic.scratches(count=14)


def up_iron_tonic(ic, st):
    LO.TONICS["iron"](ic, st)


def up_live_wire(ic, st):  # cut power cable, copper strands sparking
    pts = bez((4, 92), (14, 40), (52, 50), 12)
    for a, b in zip(pts[:-1], pts[1:]):
        ic.bar(a, b, 12, "rubber", prof="cyl")
    ic.bar((48, 49), (58, 47), 10, tone("rubber", 1.35, "cut"), prof="cyl")
    for k in range(6):
        a = -0.5 + k * 0.2
        ic.bar((56, 47), (56 + math.cos(a) * 18, 47 + math.sin(a) * 18), 1.4, "copper", w1=0.8, prof="cyl")
    spark(ic, 76, 44, r=10)
    arc(ic, (74, 40), (90, 22), 11, segs=4, jit=3)
    ic.scratches(count=6)


def up_lucky_vial(ic, st):  # small tonic with a lucky coin tied on twine
    body = [(32, 42), (60, 42), (66, 52), (66, 88), (26, 88), (26, 52)]
    LO.bottle(ic, body, "liq_saints", (46, 22, 44, 10), 18, 58, 11)
    ic.bar((40, 36), (54, 37), 1.6, "twine", prof="cyl")
    ic.bar((52, 37), (66, 50), 1.2, "twine", prof="cyl")
    coin(ic, 70, 58, 10)
    LO.label(ic, 32, 66, 58, 78, seed=3)


def up_marked(ic, st):  # paper silhouette target, red ring round the head, holes
    ic.poly([(14, 8), (82, 8), (84, 92), (12, 92)], tone("paper", 1.15, "tp"), bevel=1.2, dome=0.3)
    ic.ellipse(48, 32, 12, 13, "ink", dome=0.2)
    ic.poly([(26, 92), (24, 64), (36, 48), (60, 48), (72, 64), (70, 92)], "ink", bevel=1.0, dome=0.2)
    for r in (8, 16):
        ring(ic, 48, 66, r, r * 1.1, 0.8, tone("paper", 1.0, "rg"))
    ring(ic, 48, 32, 17, 18, 2.4, "redp")
    for (x, y) in ((46, 30), (52, 36), (44, 68), (56, 60), (30, 20)):
        ic.ellipse(x, y, 2.0, 2.0, "dark", dome=-0.5)
        ic.ellipse(x - 0.6, y - 0.6, 2.2, 2.2, tone("paper", 1.3, "torn"), dome=0.2) if (x, y) == (30, 20) else None
    ic.bar((40, 8), (56, 8), 5, "tape")


def _sawblade(ic, cx, cy, r, ry=None, n=24, mat="steel"):
    ry = ry or r
    pts = []
    for k in range(n):
        a0 = k / n * math.tau
        a1 = (k + 0.7) / n * math.tau
        pts.append((cx + math.cos(a0) * r * 0.86, cy + math.sin(a0) * ry * 0.86))
        pts.append((cx + math.cos(a1) * r, cy + math.sin(a1) * ry))
    ic.poly(pts, mat, bevel=1.4, dome=0.5)
    ic.ellipse(cx, cy, r * 0.8, ry * 0.8, tone(mat, 1.08, "disc"), dome=0.4)
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        ic.bar((cx + math.cos(a) * r * 0.45, cy + math.sin(a) * ry * 0.45), (cx + math.cos(a) * r * 0.7, cy + math.sin(a) * ry * 0.7), 1.2, "dark")
    ic.ellipse(cx, cy, r * 0.22, ry * 0.22, "gun", dome=0.8)
    ic.ellipse(cx, cy, r * 0.1, ry * 0.1, "dark", dome=-0.4)


def up_orbit_blades(ic, st):  # rusty circular saw blade
    _sawblade(ic, 48, 50, 40, 36)
    ic.patch(30, 64, 14, 10, 0.5, "rust")
    ic.patch(66, 30, 10, 8, -0.3, "rust")
    ic.scratches(count=16)


def up_piercing(ic, st):  # slug punched clean through a plank
    ic.poly([(10, 30), (62, 14), (70, 76), (18, 92)], "plank", bevel=2.0, dome=0.5)
    ic.poly([(62, 14), (70, 12), (78, 74), (70, 76)], tone("plank", 0.7, "edge"), bevel=1.0)
    ic.ellipse(40, 52, 5, 6, "dark", dome=-0.5)
    for k in range(6):
        a = k / 6 * math.tau
        ic.bar((40 + math.cos(a) * 5, 52 + math.sin(a) * 6), (40 + math.cos(a) * 10, 52 + math.sin(a) * 11), 1.6, tone("plank", 1.25, "spl"), w1=0.4)
    F = Fr(ic, (72, 48), -12, 1.2)
    F.bar(0, 0, 18, 0, 10, "copper", prof="cyl")
    F.bar(18, 0, 26, 0, 10, "copper", w1=3, prof="cyl")
    for k in range(4):
        ic.ellipse(50 + k * 4, 50 - k * 1, 1.4, 1.0, tone("plank", 1.2, "chip"), dome=0.4)


def up_quarry_slam(ic, st):  # stone block split with plug-and-feather wedges
    ic.poly([(8, 40), (60, 30), (90, 42), (38, 54)], tone("stone", 1.15, "top"), bevel=2.0, dome=0.5)
    ic.poly([(8, 40), (38, 54), (38, 92), (8, 78)], tone("stone", 0.8, "l"), bevel=2.0, dome=0.5)
    ic.poly([(38, 54), (90, 42), (90, 80), (38, 92)], tone("stone", 0.62, "r"), bevel=2.0, dome=0.5)
    for (a, b) in (((40, 38), (56, 52)), ((56, 52), (58, 66)), ((58, 66), (64, 86))):
        ic.bar(a, b, 2.0, "dark")
    for (x, y) in ((34, 34), (48, 36), (62, 38)):
        ic.bar((x, y), (x, y - 12), 4, "steel", prof="cyl")
        ic.ellipse(x, y - 12, 2.6, 1.2, tone("steel", 1.2, "pt"), dome=0.5)
    rubble(ic, [(76, 90, 3), (88, 88, 2.4), (12, 88, 2.4)])
    ic.scratches(count=10)


def up_quick_mag(ic, st):  # two magazines taped together, jungle style
    mag(ic, 38, 50, 1.25, curve=4)
    mag(ic, 60, 52, 1.25, curve=-4, flip=-1)
    for y in (40, 60):
        ic.bar((24, y), (74, y + 1), 7, "tape", prof="cyl")
    ic.scratches(count=10)


def up_ricochet(ic, st):  # steel plate target dented, bullet glancing off
    ic.bar((48, 60), (48, 94), 5, "gun", prof="cyl")
    ic.poly([(16, 20), (78, 14), (82, 64), (20, 70)], "plate", bevel=2.6, dome=0.6)
    for (x, y) in ((22, 26), (74, 20), (76, 58), (26, 64)):
        ic.rivet(x, y, 1.6)
    ic.ellipse(42, 42, 7, 6, tone("plate", 0.55, "dent"), dome=-0.7)
    ic.ellipse(42, 42, 4, 3.4, tone("plate", 1.45, "dhi"), dome=0.5)
    ic.bar((44, 40), (82, 10), 1.4, "flame", w1=0.4)
    F = Fr(ic, (78, 12), -40, 1.0)
    F.bar(0, 0, 10, 0, 6, "copper", w1=2, prof="cyl")
    spark(ic, 44, 40, r=5, n=6)
    ic.scratches(count=14)


def up_rubble_wall(ic, st):  # stacked sandbags
    rows = ((84, (14, 38, 62, 86)), (64, (26, 50, 74)), (44, (38, 62)))
    for y, xs in rows:
        for i, x in enumerate(xs):
            ic.ellipse(x, y, 13, 10, tone("burlap", 0.9 + 0.08 * ((i + y) % 3), "sb%d" % ((i + y) % 3)), dome=0.85)
            ic.bar((x - 10, y - 2), (x + 10, y - 3), 0.8, tone("burlap", 0.6, "sm"))
            ic.ellipse(x + 12, y - 4, 2.4, 2.0, "twine", dome=0.6)
    ic.scratches(count=8)


def up_sanctuary(ic, st):  # three church candles on an iron dish
    ic.ellipse(48, 86, 38, 8, "gun", dome=0.6)
    ic.ellipse(48, 84, 32, 5, tone("candle", 0.8, "pool"), dome=0.4)
    for (x, top, w) in ((30, 46, 14), (50, 30, 16), (68, 54, 13)):
        ic.bar((x, top), (x, 84), w, "candle", prof="cyl")
        ic.ellipse(x, top, w / 2, 2.2, tone("candle", 1.15, "ct"), dome=0.4)
        ic.bar((x - w / 2 + 1, top + 1), (x - w / 2 + 1.4, top + 12), 2.0, tone("candle", 1.2, "drip"), prof="cyl")
        ic.bar((x, top), (x, top - 4), 1.0, "dark")
        flame(ic, x, top - 6, 0.38)
    ic.scratches(count=4)


def up_scavengers_eye(ic, st):  # brass loupe over a nut
    LO._nut(ic, 40, 44, 22, 0.3)
    ring(ic, 40, 44, 28, 28, 5.0, "brass")
    ic.ellipse(40, 44, 26, 26, tone("glassw", 0.9, "lg"), dome=0.25)
    LO._nut(ic, 40, 44, 22, 0.3)
    ic.bar((24, 30), (34, 22), 3.0, "frost")
    ic.bar((60, 64), (88, 92), 8, "wood", prof="cyl")
    ic.bar((58, 62), (64, 68), 9, "brass", prof="cyl")
    ic.scratches(count=6)


def up_scrap_drone(ic, st):  # drone carrying a bolt in a grabber claw
    drone(ic, 48, 32, 1.4)
    ic.bar((48, 46), (48, 62), 2.4, "steel", prof="cyl")
    for s in (-1, 1):
        ic.bar((48, 62), (48 + s * 9, 70), 2.4, "gun", prof="cyl")
        ic.bar((48 + s * 9, 70), (48 + s * 5, 78), 2.0, "gun", prof="cyl")
    LO._bolt(ic, 34, 76, 64, 74, 6)
    LO._nut(ic, 66, 74, 6, 0.2)


def up_second_wind(ic, st):  # oxygen bottle with hose and rubber mask
    ic.bar((34, 26), (34, 90), 26, "olivep", prof="cyl")
    ic.ellipse(34, 26, 13, 6, tone("olivep", 1.15, "sh"), dome=0.8)
    ic.bar((34, 14), (34, 24), 8, "brass", prof="cyl")
    ic.bar((28, 14), (40, 14), 3, "brass", prof="cyl")
    ic.ellipse(46, 18, 6, 6, "steel", dome=0.8)
    ic.ellipse(46, 18, 4.4, 4.4, "dial", dome=0.3)
    ic.bar((46, 18), (48, 15), 0.7, "redp")
    ic.bar((34, 46), (34, 52), 26.4, "stencil", prof="cyl")
    pts = bez((40, 14), (78, 6), (70, 46), 12)
    for a, b in zip(pts[:-1], pts[1:]):
        ic.bar(a, b, 3.4, "rubber", prof="cyl")
    ic.poly([(56, 46), (80, 44), (86, 62), (68, 74), (54, 62)], "rubber", bevel=2.4, dome=0.9)
    ic.ellipse(70, 58, 8, 7, tone("rubber", 1.4, "cup"), dome=-0.3)
    ic.scratches(count=10)


def up_short_circuit(ic, st):  # breaker box, one breaker blown and scorched
    ic.poly([(14, 10), (78, 10), (78, 90), (14, 90)], "bluegrey", bevel=2.4, dome=0.6)
    ic.poly([(78, 10), (86, 16), (86, 94), (78, 90)], tone("bluegrey", 0.65, "side"), bevel=1.0)
    ic.poly([(20, 18), (72, 18), (72, 82), (20, 82)], "dark", bevel=1.0, dome=0.2)
    for i, x in enumerate((30, 46, 62)):
        ic.poly([(x - 6, 30), (x + 6, 30), (x + 6, 70), (x - 6, 70)], "ash" if i != 1 else "scorch", bevel=1.0, dome=0.6)
        ic.bar((x, 46), (x, 38 if i != 1 else 56), 5, "rubber" if i != 1 else "ash", prof="box")
    ic.ellipse(46, 40, 10, 12, tone("scorch", 0.7, "soot"), dome=0.2)
    smoke(ic, 46, 22, n=3, dx=3, s=1.0, k0=1.2)
    spark(ic, 52, 34, r=6)
    ic.scratches(count=12)


def up_split_shot(ic, st):  # opened shotgun shell, pellets spilling out
    F = Fr(ic, (14, 80), -30, 1.15)
    F.bar(0, 0, 14, 0, 18, "brass", prof="cyl")
    F.bar(0, 0, 2, 0, 20, tone("brass", 0.7, "rim"), prof="cyl")
    F.bar(14, 0, 46, 0, 17.4, "plastic_r", prof="cyl")
    for k in range(4):
        F.bar(46, (k - 1.5) * 4, 52, (k - 1.5) * 6, 3, "plastic_r", w1=1.6)
    rng = np.random.default_rng(4)
    for k in range(16):
        u = 54 + rng.uniform(0, 26)
        v = rng.uniform(-6, 6) * (1 + (u - 54) / 20)
        x, y = F.P(u, v)
        ic.ellipse(x, y, 3.0, 3.0, "gun", dome=0.95)


def up_spore_mines(ic, st):  # rusted landmine overgrown with fungus
    ic.ellipse(48, 74, 40, 16, tone("olivep", 0.6, "ms"), dome=0.5)
    ic.ellipse(48, 66, 40, 15, "olivep", dome=0.6)
    ic.ellipse(48, 64, 16, 6, "gun", dome=0.6)
    ic.ellipse(48, 63, 9, 3.4, "steel", dome=0.8)
    ic.patch(30, 70, 14, 6, 0.1, "rust")
    for (x, y, r) in ((70, 52, 10), (80, 60, 7), (24, 56, 8), (60, 44, 6)):
        ic.bar((x, y + r * 0.2), (x, y + r * 0.9), r * 0.5, "fungus_st", prof="cyl")
        ic.ellipse(x, y, r, r * 0.6, "fungus", dome=0.9)
    for (x, y) in ((64, 34), (74, 38), (56, 30), (82, 46), (20, 42)):
        ic.ellipse(x, y, 1.4, 1.4, tone("fungus", 1.4, "spore"), dome=0.5)
    ic.scratches(count=10)


def up_squadron(ic, st):
    drone(ic, 48, 26, 0.95)
    drone(ic, 22, 66, 0.95)
    drone(ic, 74, 66, 0.95)


def up_supply_drop(ic, st):  # crate under a gored parachute
    canopy = bez((6, 36), (48, -12), (90, 36), 16)
    ic.poly(canopy + [(76, 40), (62, 34), (48, 38), (34, 34), (20, 40)], "olivep", bevel=2.0, dome=0.8)
    for x in (24, 40, 56, 72):
        ic.bar((x, 6 + abs(x - 48) * 0.4), (x + (x - 48) * 0.1, 36), 1.0, tone("olivep", 0.6, "gore"))
    for x in (8, 26, 48, 70, 88):
        ic.bar((x, 38), (36 + (x - 48) * 0.2, 60), 0.8, "twine")
    ic.poly([(26, 60), (70, 60), (70, 92), (26, 92)], "plank", bevel=2.0, dome=0.6)
    ic.bar((26, 70), (70, 70), 1.0, tone("plank", 0.55, "gap"))
    ic.bar((26, 82), (70, 82), 1.0, tone("plank", 0.55, "gap"))
    for x in (30, 66):
        ic.bar((x, 60), (x, 92), 3.4, tone("plank", 1.2, "batten"))
    ic.bar((40, 74), (56, 74), 3.0, "stencil")


def up_thick_plate(ic, st):  # dented ballistic plate in a worn carrier edge
    pts = [(22, 14), (34, 8), (62, 8), (74, 14), (76, 84), (48, 90), (20, 84)]
    ic.poly([(x + 3, y + 3) for (x, y) in pts], tone("canvas", 0.7, "cv"), bevel=2.0)
    ic.poly(pts, "plate", bevel=4.0, dome=0.9)
    for (x, y, r) in ((40, 34, 5), (58, 52, 4.4), (36, 66, 4)):
        ic.ellipse(x, y, r, r * 0.9, tone("plate", 0.5, "dent"), dome=-0.7)
        ic.ellipse(x - 1, y - 1, r * 0.5, r * 0.45, tone("copper", 1.1, "frag"), dome=0.6)
    ic.patch(62, 22, 8, 10, 0.2, "rust")
    ic.scratches(count=20)


def up_unbreakable(ic, st):  # anvil on a stump
    ic.poly([(26, 70), (70, 70), (76, 94), (20, 94)], "wood", bevel=2.0, dome=0.6)
    ic.ellipse(48, 70, 22, 5, tone("wood", 1.2, "stp"), dome=0.4)
    ic.poly([(32, 52), (64, 52), (68, 72), (28, 72)], "gun", bevel=2.0, dome=0.7)
    pts = [(4, 34)] + bez((4, 34), (16, 44), (32, 44), 6) + [(32, 52), (64, 52), (64, 44), (88, 44), (88, 30), (30, 30)]
    ic.poly(pts, "gun", bevel=2.6, dome=0.7)
    ic.poly([(30, 28), (88, 28), (88, 32), (30, 32)], tone("steel", 1.2, "face"), bevel=0.8)
    ic.ellipse(78, 30, 2.4, 1.0, "dark", dome=-0.4)
    ic.scratches(count=14)


def up_wingman(ic, st):  # brass pilot wings badge
    for s in (-1, 1):
        for k in range(6):
            x0 = 48 + s * 8
            x1 = 48 + s * (44 - k * 5)
            y = 44 + k * 3.6
            ic.bar((x0, 48), (x1, y - 4), 8.4 - k * 0.7, tone("gold", 1.0 - k * 0.04, "f%d" % k), w1=2.0, prof="cyl")
    ic.poly([(38, 34), (58, 34), (58, 50), (48, 62), (38, 50)], "gold", bevel=1.8, dome=0.8)
    ic.ellipse(48, 46, 5, 6, tone("gold", 0.7, "ctr"), dome=0.4)
    ic.scratches(count=8)


# --------------------------------------------------------------- evolutions
def rec_air_raid(ic, st):  # finned aerial bomb dropping
    F = Fr(ic, (20, 14), 56, 1.0)
    F.bar(-6, 0, 12, 0, 12, "olivep", w1=26, prof="cyl")
    F.bar(12, 0, 50, 0, 28, "olivep", prof="cyl")
    F.bar(50, 0, 66, 0, 28, "olivep", w1=6, prof="cyl")
    F.bar(64, 0, 70, 0, 5, "brass", prof="cyl")
    F.bar(20, -15, 20, 15, 3, "hazardw")
    for v in (-1, 1):
        F.poly([(-12, v * 4), (4, v * 6), (2, v * 16), (-14, v * 16)], tone("olivep", 0.85, "fin"), bevel=1.0)
    F.bar(-14, -16, -14, 16, 2.4, tone("olivep", 0.7, "ring"))
    for k in range(3):
        ic.bar((10 + k * 8, 4), (2 + k * 8, -6), 1.0, tone("ash", 0.8, "trail"))
    ic.scratches(count=14)


def rec_arc_storm(ic, st):  # shock round crackling, arcs jumping off it
    cartridge(ic, 18, 84, -48, 2.2, tip="voltp", ln=40)
    arc(ic, (58, 26), (88, 8), 1, jit=3)
    arc(ic, (62, 32), (90, 40), 2, jit=3)
    arc(ic, (52, 22), (54, 2), 4, segs=4, jit=3)


def rec_autopsy_table(ic, st):  # steel tray with scalpel, forceps and a bone saw
    ic.poly([(6, 34), (84, 22), (92, 70), (14, 84)], "steel", bevel=4.0, dome=0.4)
    ic.poly([(12, 38), (80, 27), (86, 66), (18, 78)], tone("steel", 0.8, "pan"), bevel=1.0, dome=-0.2)
    ic.ellipse(60, 58, 10, 5, "blood", dome=0.4)
    S = Fr(ic, (22, 70), -12, 0.85)
    S.bar(0, 0, 40, 0, 5, "steel")
    S.poly([(40, -2.4), (52, -2.6), (60, 1), (52, 2.6), (40, 2.4)], "blade", bevel=0.8)
    for v in (-2, 2):
        ic.bar((30, 44 + v), (58, 36 + v * 2.4), 2.0, "steel", prof="cyl")
    B = Fr(ic, (52, 76), -32, 0.8)
    B.bar(0, 0, 14, 0, 7, "wood", prof="cyl")
    B.poly([(14, -6), (48, -6), (48, 6), (14, 6)], "blade", bevel=0.8)
    if L._detail():
        for u in range(16, 48, 3):
            B.bar(u, 6, u + 1.5, 8, 0.8, "blade")


def rec_blade_storm(ic, st):  # sawblade ringed with throwing knives
    for k in range(4):
        a = k / 4 * math.tau + 0.6
        knife(ic, 48 + math.cos(a) * 18, 48 + math.sin(a) * 18, math.degrees(a), 0.5)
    _sawblade(ic, 48, 48, 30, 30)
    ic.patch(40, 54, 8, 6, 0.4, "rust")


def rec_bulwark(ic, st):  # tall riot shield with a vision slot, resting
    ground(ic, 48, 92, 32)
    pts = [(18, 10), (78, 10), (82, 20), (82, 90), (14, 90), (14, 20)]
    ic.poly(pts, "plate", bevel=4.0, dome=0.85)
    ic.poly([(26, 20), (70, 20), (70, 28), (26, 28)], "dark", bevel=0.8)
    ic.poly([(27, 21), (69, 21), (69, 27), (27, 27)], tone("glassw", 0.7, "slot"), bevel=0.4)
    for (x, y) in ((20, 16), (76, 16), (20, 86), (76, 86), (48, 86)):
        ic.rivet(x, y, 1.8)
    for (x, y, r) in ((34, 52, 4), (60, 66, 3.6)):
        ic.ellipse(x, y, r, r, tone("plate", 0.5, "dent"), dome=-0.7)
    ic.patch(64, 42, 12, 16, 0.1, "rust")
    ic.bar((14, 60), (82, 58), 6, "hazardw")
    ic.scratches(count=20)


def rec_cathedral_fire(ic, st):  # lancet window, firelight through stained glass
    outer = [(16, 92), (16, 40)] + bez((16, 40), (16, 6), (48, 2), 8) + bez((48, 2), (80, 6), (80, 40), 8) + [(80, 92)]
    ic.poly(outer, "stone", bevel=3.0, dome=0.6)
    inner = [(26, 88), (26, 42)] + bez((26, 42), (26, 14), (48, 10), 8) + bez((48, 10), (70, 14), (70, 42), 8) + [(70, 88)]
    ic.poly(inner, "glassfire", bevel=1.0, dome=0.3)
    for (x, y, rx, ry, m) in ((48, 30, 8, 8, "glassred"), (36, 66, 6, 10, "glassred"), (60, 66, 6, 10, "glassred")):
        ic.ellipse(x, y, rx, ry, m, dome=0.3)
    for x in (37, 48, 59):
        ic.bar((x, 14 if x == 48 else 20), (x, 88), 1.4, "dark")
    for y in (44, 56, 72):
        ic.bar((26, y), (70, y), 1.4, "dark")
    ring(ic, 48, 30, 8, 8, 1.2, "dark")
    ic.poly([(10, 88), (86, 88), (86, 96), (10, 96)], tone("stone", 0.8, "sill"), bevel=1.0)
    ic.scratches(count=10)


def rec_deadeye(ic, st):  # rifle scope in 3/4, reticle visible in the lens
    F = Fr(ic, (10, 70), -26, 1.0)
    F.bar(0, 0, 18, 0, 14, "gun", w1=16, prof="cyl")
    F.bar(18, 0, 56, 0, 11, "gun", prof="cyl")
    F.bar(56, 0, 72, 0, 11, "gun", w1=22, prof="cyl")
    F.bar(72, 0, 76, 0, 22, tone("gun", 1.1, "bell"), prof="cyl")
    F.bar(34, -6, 34, -14, 6, "gun", prof="cyl")
    F.bar(38, 6, 38, 12, 5, "gun", prof="cyl")
    for u in (24, 50):
        F.bar(u, 5, u, 12, 5, "steel", prof="box")
    cx, cy = F.P(76, 0)
    ic.ellipse(cx, cy, 6, 11, "lens", dome=0.4)
    ic.bar((cx, cy - 9), (cx, cy + 9), 0.6, "ink")
    ic.bar((cx - 5, cy), (cx + 5, cy), 0.6, "ink")
    ic.ellipse(cx, cy, 0.9, 0.9, "glow_red", dome=0.4)
    ic.bar((cx - 2.4, cy - 6), (cx - 1, cy - 2), 1.0, "frost")
    ic.scratches(count=12)


def rec_death_knell(ic, st):  # cracked black iron bell with a mourning ribbon
    ic.bar((20, 10), (76, 10), 7, "wood", prof="box")
    bell(ic, 48, 44, 1.6, "gun")
    for (a, b) in (((56, 34), (60, 46)), ((60, 46), (56, 56)), ((56, 56), (62, 70))):
        ic.bar(a, b, 1.6, "dark")
    ic.poly([(40, 18), (48, 24), (40, 34), (34, 30)], "rubber", bevel=0.8)
    ic.poly([(56, 18), (48, 24), (56, 34), (62, 30)], "rubber", bevel=0.8)
    ic.bar((36, 30), (32, 44), 3, "rubber")
    ic.bar((58, 30), (64, 44), 3, "rubber")
    ic.scratches(count=12)


def rec_earthquake(ic, st):  # road slab split open, halves heaved apart
    ic.poly([(4, 46), (42, 36), (46, 70), (6, 82)], "concrete", bevel=2.0, dome=0.5)
    ic.poly([(6, 82), (46, 70), (46, 78), (6, 92)], tone("concrete", 0.6, "f1"), bevel=1.0)
    ic.poly([(54, 50), (92, 40), (92, 76), (52, 86)], tone("concrete", 0.9, "s2"), bevel=2.0, dome=0.5)
    ic.poly([(52, 86), (92, 76), (92, 84), (52, 94)], tone("concrete", 0.55, "f2"), bevel=1.0)
    ic.poly([(42, 36), (54, 50), (52, 94), (46, 78)], "dark", bevel=0.6)
    for (a, b) in (((12, 60), (36, 54)), ((60, 62), (86, 56))):
        ic.bar(a, b, 2.2, "hazardw")
    rubble(ic, [(48, 30, 3.6), (40, 24, 2.6), (58, 34, 2.4), (30, 32, 2.0)], "concrete")
    dust_cloud(ic, 48, 34, 0.8)


def rec_fortune(ic, st):  # stack of tarnished coins and loose ones
    for k in range(6):
        coin(ic, 40, 80 - k * 6, 20, ry=7, mark=(k == 5))
    coin(ic, 70, 72, 14, ry=13)
    coin(ic, 74, 50, 10, ry=9, mat="brass")
    coin(ic, 18, 84, 8, ry=3)


def rec_ghost_debt(ic, st):  # IOU note knifed to a plank, bloody thumbprint
    ic.poly([(4, 20), (92, 12), (92, 88), (4, 92)], "plank", bevel=2.0, dome=0.4)
    for y in (38, 64):
        ic.bar((4, y + 2), (92, y - 4), 1.0, tone("plank", 0.5, "gap"))
    F = Fr(ic, (48, 52), 8, 1.0)
    F.poly([(-26, -20), (26, -22), (28, 22), (-24, 24)], tone("paper", 1.1, "iou"), bevel=1.0, dome=0.3)
    for v in (-10, -4, 2):
        F.bar(-16, v, 14 - v, v, 1.0, "ink")
    F.ell(14, 12, 5, 6, "blood")
    knife(ic, 6, 82, -52, 1.0)


def rec_hellfire_stride(ic, st):  # boot wreathed in flame, scorched print
    ic.ellipse(48, 86, 44, 9, "scorch", dome=0.3)
    flame(ic, 20, 74, 1.0)
    flame(ic, 80, 74, 0.9)
    boot(ic, 52, 76, 1.05, dict(G.GENERIC, leather="scorch"))
    flame(ic, 36, 84, 0.8)
    flame(ic, 64, 86, 0.7)


def rec_hive(ic, st):  # wooden hive box, honeycomb frame lifted out
    ic.poly([(10, 50), (70, 50), (70, 92), (10, 92)], "plank", bevel=2.0, dome=0.6)
    ic.poly([(10, 50), (70, 50), (86, 40), (26, 40)], tone("plank", 1.15, "ht"), bevel=1.0)
    ic.poly([(70, 50), (86, 40), (86, 82), (70, 92)], tone("plank", 0.7, "hs"), bevel=1.0)
    ic.bar((10, 70), (70, 70), 1.0, tone("plank", 0.5, "gap"))
    ic.poly([(30, 8), (76, 8), (76, 46), (30, 46)], "wood", bevel=1.6)
    for r in range(5):
        for c in range(6):
            x = 36 + c * 7 + (r % 2) * 3.5
            y = 14 + r * 7
            if x < 74:
                pts = [(x + math.cos(k * math.pi / 3 + math.pi / 6) * 3.6, y + math.sin(k * math.pi / 3 + math.pi / 6) * 3.6) for k in range(6)]
                ic.poly(pts, "honey" if (r + c) % 3 else "wax2", bevel=0.6, dome=0.5)
    ic.scratches(count=8)


def rec_lead_rain(ic, st):  # rounds slanting down into the dirt
    ground(ic, 48, 88, 44, 7)
    for (x, y) in ((22, 22), (50, 12), (76, 26), (34, 50), (64, 52)):
        F = Fr(ic, (x, y), 70, 1.35)
        F.bar(0, 0, 14, 0, 7, "copper", prof="cyl")
        F.bar(14, 0, 20, 0, 7, "copper", w1=2, prof="cyl")
        ic.bar((x - 4, y - 12), (x, y), 1.0, tone("ash", 0.75, "tr"))
    for x in (30, 54, 74):
        ic.ellipse(x, 84, 6, 3, tone("dust", 0.9, "imp"), dome=0.5)


def rec_mountain(ic, st):  # massive layered boulder
    pts = [(4, 90), (12, 58), (24, 44), (32, 22), (40, 26), (50, 6), (60, 20), (68, 16), (80, 42), (90, 60), (92, 90)]
    ic.poly(pts, "stone", bevel=4.0, dome=0.8)
    ic.poly([(50, 6), (60, 20), (54, 40), (44, 30)], tone("stone", 1.35, "f1"), bevel=1.0)
    ic.poly([(32, 22), (40, 26), (34, 46), (24, 44)], tone("stone", 1.2, "f2"), bevel=1.0)
    ic.poly([(68, 16), (80, 42), (70, 54), (62, 34)], tone("stone", 0.7, "f3"), bevel=1.0)
    for (a, b, c) in (((10, 66), (48, 56), (88, 70)), ((8, 80), (48, 72), (90, 82)), ((22, 44), (48, 34), (78, 46))):
        for p, q in zip(bez(a, b, c, 8)[:-1], bez(a, b, c, 8)[1:]):
            ic.bar(p, q, 1.2, tone("stone", 0.6, "str"))
    ic.poly([(46, 14), (60, 22), (52, 30), (40, 24)], tone("stone", 1.3, "lit"), bevel=1.0)
    ic.bar((60, 40), (66, 58), 1.4, "dark")
    ic.scratches(count=10)


def rec_phoenix(ic, st):  # draught flask with a burning red feather
    F = Fr(ic, (64, 88), -100, 1.0)
    F.bar(0, 0, 70, 0, 3, "bone", w1=1.4, prof="cyl")
    for k in range(10):
        u = 12 + k * 6
        w = 10 - abs(k - 4) * 1.2
        F.bar(u, 0, u + 4, -w * 1.4, 3.6, "feather")
        F.bar(u, 0, u + 4, w * 1.4, 3.6, tone("feather", 0.8, "fb"))
    flame(ic, *F.P(76, 0), 0.6)
    body = [(18, 52), (44, 52), (50, 60), (50, 90), (12, 90), (12, 60)]
    LO.bottle(ic, body, "liq_firebrand", (31, 32, 52, 9), 28, 62, 9)


def rec_plague_bloom(ic, st):  # diseased bulb flower shedding spores
    ic.bar((48, 52), (46, 92), 4, "stem", prof="cyl")
    ic.poly([(46, 80), (24, 70), (16, 74), (40, 84)], "leaf", bevel=1.4, dome=0.7)
    ic.poly([(48, 70), (70, 62), (78, 66), (50, 76)], "leaf", bevel=1.4, dome=0.7)
    for k in range(6):
        a = k / 6 * math.tau + 0.3
        ic.ellipse(48 + math.cos(a) * 16, 38 + math.sin(a) * 13, 12, 9, tone("petal", 0.85 + 0.05 * (k % 3), "pt%d" % (k % 3)), dome=0.85)
    ic.ellipse(48, 38, 11, 10, "fungus", dome=0.9)
    for (x, y) in ((44, 34), (52, 40), (48, 44)):
        ic.ellipse(x, y, 1.6, 1.6, tone("fungus", 1.5, "pk"), dome=0.5)
    for (x, y) in ((70, 18), (80, 30), (60, 10), (28, 14), (18, 28)):
        ic.ellipse(x, y, 1.6, 1.6, tone("fungus", 1.4, "spr"), dome=0.5)


def rec_thunderhead(ic, st):  # heavy storm cloud, forked bolt, rain
    for (dx, dy, r) in ((-24, 6, 14), (-6, -6, 20), (16, -2, 17), (30, 8, 12), (0, 10, 18)):
        ic.ellipse(48 + dx, 36 + dy, r, r * 0.8, tone("cloud_d", 0.9 + (dy + 6) * 0.01, "td%d" % (dx + 30)), dome=0.75)
    ic.ellipse(48, 48, 36, 7, tone("cloud_d", 0.7, "tb"), dome=0.3)
    arc(ic, (50, 52), (40, 92), 21, segs=5, jit=5, w=2.4)
    arc(ic, (46, 70), (64, 84), 22, segs=3, jit=3, w=1.4)
    for x in (22, 30, 66, 74, 82):
        ic.bar((x, 58), (x - 4, 72), 0.8, tone("glassw", 0.8, "rain"))


# --------------------------------------------------------------- quirks
def quirk_berserker(ic, st):  # skull smeared with a red war-paint handprint
    ic.ellipse(48, 40, 30, 28, "bone2", dome=0.95)
    ic.poly([(28, 52), (68, 52), (64, 80), (32, 80)], "bone2", bevel=3.0, dome=0.8)
    for dx in (-11, 11):
        ic.ellipse(48 + dx, 46, 8, 7.4, "dark", dome=-0.5)
    ic.poly([(44, 62), (52, 62), (48, 54)], "dark", bevel=0.4)
    for k in range(7):
        x = 36 + k * 4
        ic.bar((x, 70), (x, 78), 1.0, tone("bone2", 0.5, "teeth"))
    ic.poly([(22, 30), (74, 24), (76, 34), (24, 40)], tone("redp", 1.1, "paint"), bevel=1.0, dome=0.3)
    for x in (30, 46, 62):
        ic.bar((x, 36), (x - 2, 46), 2.0, tone("redp", 1.1, "paint"), w1=0.8)
    ic.bar((30, 22), (40, 36), 1.4, "dark")
    ic.scratches(count=10)


def quirk_bloodthirst(ic, st):  # IV blood bag with tube and clamp
    ic.bar((48, 4), (48, 12), 3, "steel", prof="cyl")
    ic.poly([(26, 12), (70, 12), (74, 18), (74, 70), (66, 78), (30, 78), (22, 70), (22, 18)], tone("glassw", 1.1, "bag"), bevel=3.0, dome=0.8)
    ic.poly([(26, 30), (70, 30), (70, 68), (64, 74), (32, 74), (26, 68)], "bloodbag", bevel=2.0, dome=0.85)
    LO.label(ic, 32, 40, 64, 56, seed=8)
    ic.bar((48, 78), (48, 96), 2.4, "glassw", prof="cyl")
    ic.bar((48, 80), (48, 96), 1.4, "bloodbag")
    ic.bar((42, 88), (54, 88), 3, "plastic_r")
    ic.bar((30, 20), (30, 64), 1.6, "frost")


def quirk_dust_eater(ic, st):
    G.s_gasmask(ic, dict(G.GENERIC, dye="rubber", plate="steel", lens="glass"))


def quirk_glass_cannon(ic, st):  # small cannon with a cracked glass barrel
    ic.ellipse(32, 78, 14, 14, "wood", dome=0.8)
    ic.ellipse(32, 78, 5, 5, "gun", dome=0.9)
    for k in range(6):
        a = k / 6 * math.tau
        ic.bar((32, 78), (32 + math.cos(a) * 13, 78 + math.sin(a) * 13), 2.0, tone("wood", 0.7, "sp"))
    ic.poly([(18, 70), (56, 62), (60, 74), (22, 82)], tone("wood", 0.85, "car"), bevel=1.6)
    F = Fr(ic, (20, 66), -28, 1.0)
    F.bar(0, 0, 12, 0, 22, "brass", prof="cyl")
    F.bar(12, 0, 70, 0, 18, "glassw", w1=13, prof="cyl")
    F.bar(68, 0, 74, 0, 16, "brass", prof="cyl")
    F.bar(16, -6, 64, -4, 1.6, "frost")
    for (a, b) in (((30, -6), (38, 2)), ((38, 2), (34, 7)), ((48, -7), (54, 5))):
        F.bar(a[0], a[1], b[0], b[1], 0.9, "dark")
    ic.scratches(count=6)


def quirk_no_reload(ic, st):  # coiled linked ammo belt
    pts = bez((10, 86), (4, 30), (48, 26), 12) + bez((48, 26), (88, 26), (82, 70), 10)[1:] + bez((82, 70), (70, 92), (40, 70), 8)[1:]
    for a, b in zip(pts[:-1], pts[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        ang = math.degrees(math.atan2(dy, dx)) - 90
        cartridge(ic, a[0], a[1], ang, 0.55, ln=34)
    for a, b in zip(pts[:-1], pts[1:]):
        ic.bar(a, b, 2.2, "gun")


def quirk_pack_leader(ic, st):  # leather dog collar, brass tag and buckle
    ring(ic, 48, 46, 34, 26, 9, "leatherb", n=40)
    for k in range(8):
        a = math.pi + k / 7 * math.pi
        ic.ellipse(48 + math.cos(a) * 34, 46 + math.sin(a) * 26, 1.8, 1.8, "steel", dome=0.9)
    G.buckle(ic, 16, 46, 10, 14, "steel")
    ring(ic, 48, 74, 4, 4, 1.6, "steel")
    ic.ellipse(48, 84, 9, 9, "brass", dome=0.8)
    ic.bar((43, 84), (53, 84), 0.8, "ink")
    ic.scratches(count=10)


def quirk_packrat(ic, st):  # bulging burlap sack, junk sticking out
    F = Fr(ic, (34, 22), -60, 1.0)
    F.bar(0, 0, 30, 0, 6, "redp", prof="box")
    F.poly([(28, -6), (38, -6), (40, 0), (38, 6), (28, 6)], "gun", bevel=1.0)
    ic.bar((58, 30), (70, 6), 6, "steel", prof="cyl")
    ic.poly([(26, 40), (70, 40), (84, 66), (76, 92), (20, 92), (12, 66)], "burlap", bevel=6.0, dome=0.95)
    ic.poly([(32, 34), (64, 34), (60, 44), (36, 44)], tone("burlap", 0.8, "neck"), bevel=1.4)
    ic.bar((34, 44), (62, 44), 3.0, "rope", prof="cyl")
    ic.patch(56, 72, 14, 10, 0.2, "canvas")
    G.stitch(ic, [(49, 67), (63, 66), (64, 77), (50, 78), (49, 67)], 1.6)
    ic.scratches(count=6)


def quirk_scavenger(ic, st):  # chipped horseshoe magnet with nuts stuck on
    F = Fr(ic, (48, 46), 0, 1.0)
    pts = bez((-28, 30), (-32, -34), (0, -34), 12) + bez((0, -34), (32, -34), (28, 30), 12) + [(14, 30)] + bez((14, 30), (16, -18), (0, -18), 8) + bez((0, -18), (-16, -18), (-14, 30), 8)
    ic.poly([F.P(u, v) for (u, v) in pts], "magnet_r", bevel=3.0, dome=0.9)
    ic.poly([F.P(-28, 30), F.P(-14, 30), F.P(-14, 42), F.P(-28, 42)], "steel", bevel=1.4)
    ic.poly([F.P(14, 30), F.P(28, 30), F.P(28, 42), F.P(14, 42)], "steel", bevel=1.4)
    LO._nut(ic, 27, 92, 7, 0.2)
    LO._washer(ic, 70, 92, 6)
    ic.scratches(count=14)


def quirk_steady(ic, st):  # aluminium spirit level, bubble centred
    F = Fr(ic, (6, 84), -36, 1.0)
    F.poly([(0, -9), (90, -9), (90, 9), (0, 9)], "hazardw", bevel=1.6, dome=0.6)
    F.poly([(0, 9), (90, 9), (90, 13), (0, 13)], tone("hazardw", 0.6, "lsd"), bevel=0.6)
    F.poly([(34, -6), (56, -6), (56, 6), (34, 6)], "dark", bevel=0.6)
    F.bar(36, 0, 54, 0, 8, tone("bubble", 0.8, "vial"), prof="cyl")
    F.ell(45, -0.6, 3.6, 2.6, tone("bubble", 1.5, "bub"))
    F.bar(41, -5, 41, 5, 0.8, "ink")
    F.bar(49, -5, 49, 5, 0.8, "ink")
    for u in (10, 80):
        F.ell(u, 0, 4, 4, "dark")
    ic.scratches(count=12)


SHAPES = {
    "ab_ash_rook_a": ab_rook_a, "ab_ash_rook_b": ab_rook_b, "ab_vesper_thorn_a": ab_vesper_a, "ab_vesper_thorn_b": ab_vesper_b,
    "ab_pebble_a": ab_pebble_a, "ab_pebble_b": ab_pebble_b, "ab_bolt_juno_a": ab_juno_a, "ab_bolt_juno_b": ab_juno_b,
    "ab_sister_cinder_a": ab_cinder_a, "ab_sister_cinder_b": ab_cinder_b, "ab_quill_marrow_a": ab_quill_a, "ab_quill_marrow_b": ab_quill_b,
    "ab_nyx_caldera_a": ab_nyx_a, "ab_nyx_caldera_b": ab_nyx_b, "ab_helm_wisp_a": ab_helm_a, "ab_helm_wisp_b": ab_helm_b,
}
for _k, _v in list(globals().items()):
    if _k.startswith(("up_", "rec_", "quirk_")) and callable(_v):
        SHAPES[_k] = _v
ALL = list(SHAPES)
WIRE = list(ALL)

for k, fn in SHAPES.items():
    G.SHAPES["card_" + k] = fn


def render(k, mode):
    L.SOFT = True
    return G.build("card_" + k, G.GENERIC, 1200 + ALL.index(k), mode)


def run(k):
    for mode in ("s48", "s24"):
        Image.fromarray(render(k, mode), "RGBA").save(os.path.join(SET, mode[1:], k + ".png"))
    return k


if __name__ == "__main__":
    import multiprocessing as mp
    ks = [k for k in WIRE if not sys.argv[1:] or k in sys.argv[1:]]
    with mp.Pool(min(4, os.cpu_count() or 1)) as pool:
        for k in pool.imap_unordered(run, ks):
            print("ok", k)
