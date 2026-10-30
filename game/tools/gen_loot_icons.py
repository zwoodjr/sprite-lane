"""Loot / consumable icons (art pass 9), painted with the weapon + gear engine
toward Zach's armour sheet: real objects, believable worn materials, muted
earthy palette, soft top-left studio light, contact shadow, no outlines-only
look, rendered at 4x and box-filtered down.

Each item is drawn once in a 96-unit box and written to every place the game
shows it (IconSet 48 / 24 px and the 96 px world pickup). WIRE lists the items
that are actually shipped; anything left out keeps today's art.

    python3 tools/gen_loot_icons.py [id ...]      (from game/)
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

hx = L.hx
A = os.path.join(L.GAME, "assets", "sprites")
SET = L.SET
bez, crease, tone, stitch, buckle, rivets = G.bez, G.crease, G.tone, G.stitch, G.buckle, G.rivets

L.MAT.update({
    "glassd": dict(c=hx("#3c4842"), spec=1.3, grime=0.25, rust=0.0, metal=0.0),
    "glassw": dict(c=hx("#8a9690"), spec=1.3, grime=0.3, rust=0.0, metal=0.0),
    "paper": dict(c=hx("#b8a67c"), spec=0.05, grime=0.75, rust=0.0, metal=0.0, pores=1),
    "ink": dict(c=hx("#2a2018"), spec=0.0, grime=0.1, rust=0.0, metal=0.0),
    "twine": dict(c=hx("#9a8258"), spec=0.05, grime=0.4, rust=0.0, metal=0.0, wrap=1),
    "sage": dict(c=hx("#7a8a6a"), spec=0.15, grime=0.35, rust=0.0, metal=0.0, fur=1),
    "stem": dict(c=hx("#6a5a3a"), spec=0.1, grime=0.4, rust=0.0, metal=0.0),
    "fungus": dict(c=hx("#7a5a5e"), spec=0.35, grime=0.4, rust=0.0, metal=0.0, pores=1),
    "fungus_st": dict(c=hx("#b8a88a"), spec=0.15, grime=0.45, rust=0.0, metal=0.0),
    "amber": dict(c=hx("#c8802a"), spec=1.2, grime=0.15, rust=0.0, metal=0.0),
    "olivep": dict(c=hx("#55593a"), spec=0.35, grime=0.55, rust=0.4, chip="steel", metal=0.0),
    "redp": dict(c=hx("#8a2a22"), spec=0.35, grime=0.55, rust=0.35, chip="steel", metal=0.0),
    "cellglass": dict(c=hx("#4a7a78"), spec=1.3, grime=0.2, rust=0.0, metal=0.0),
    "plank": dict(c=hx("#7a5a36"), spec=0.2, grime=0.55, rust=0.0, grain=1, metal=0.0),
    "rope": dict(c=hx("#8e7a52"), spec=0.05, grime=0.45, rust=0.0, metal=0.0, wrap=1),
    "stencil": dict(c=hx("#d8cfb0"), spec=0.05, grime=0.7, rust=0.0, metal=0.0),
    "ribbon_r": dict(c=hx("#7a2026"), spec=0.2, grime=0.4, rust=0.0, metal=0.0, weave=1),
    "ribbon_b": dict(c=hx("#2a3a5a"), spec=0.2, grime=0.4, rust=0.0, metal=0.0, weave=1),
    "flame": dict(c=hx("#f0a040"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "flame_hot": dict(c=hx("#fff0c0"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "smoke": dict(c=hx("#6a6460"), spec=0.0, grime=0.0, rust=0.0, metal=0.0),
})
LIQ = {
    "menders": "#a8302a", "iron": "#6a6e72", "ward": "#5e8a2e", "firebrand": "#d0661c",
    "spark": "#2e70b0", "quickstep": "#d0b83a", "saints": "#d8c49a",
}
for k, c in LIQ.items():
    L.MAT["liq_" + k] = dict(c=hx(c), spec=1.1, grime=0.05, rust=0.0, metal=0.0)


# ------------------------------------------------------------------ helpers
def label(ic, x0, y0, x1, y1, seed=0):
    """Stained paper label with a few lines of small handwritten print."""
    ic.poly([(x0, y0), (x1, y0 + 0.6), (x1 - 0.4, y1), (x0 + 0.3, y1 - 0.5)], "paper", bevel=0.8, dome=0.5)
    if not L._detail():
        return
    rng = np.random.default_rng(seed)
    n = max(1, int((y1 - y0) / 3.4))
    for i in range(n):
        y = y0 + 2.2 + i * 3.2
        if y > y1 - 1.5:
            break
        xa = x0 + 1.6
        xb = x1 - 1.6 - rng.uniform(0, (x1 - x0) * 0.35)
        pts = [(xa + (xb - xa) * t, y + math.sin(t * 9 + i) * 0.35) for t in np.linspace(0, 1, 6)]
        for a, b in zip(pts[:-1], pts[1:]):
            ic.bar(a, b, 0.55, "ink")


def bottle(ic, body, liquid, neck, cork_top, liq_level, seed, glass="glassd"):
    """Glass bottle: body poly + neck bar, liquid inside with a meniscus,
    cork, rim highlight, left specular streak. `neck` = (x, y0, y1, w)."""
    nx, ny0, ny1, nw = neck
    ic.bar((nx, ny0), (nx, ny1), nw, glass, prof="cyl")
    ic.poly(body, glass, bevel=4.0, dome=0.95)
    # liquid: body clipped at the fill level, inset from the glass wall
    ys = [y for _, y in body]
    cx = sum(x for x, _ in body) / len(body)
    inner = [(cx + (x - cx) * 0.86, max(y, liq_level)) for (x, y) in body]
    inner = [(x, y if y < max(ys) else y - 1.6) for (x, y) in inner]
    ic.poly(inner, liquid, bevel=4.0, dome=0.9)
    # meniscus: a lit ellipse across the liquid top
    w = max(x for x, y in inner if abs(y - liq_level) < 6) - min(x for x, y in inner if abs(y - liq_level) < 6) if any(abs(y - liq_level) < 6 for x, y in inner) else 10
    ic.ellipse(cx, liq_level + 0.6, max(3, w / 2 - 1), 1.4, tone(liquid, 1.35, "men"), dome=0.4)
    # cork + lip
    ic.bar((nx, ny0 + 0.5), (nx, ny0 - 1.2), nw + 2.0, tone(glass, 1.2, "lip"), prof="cyl")
    ic.bar((nx, ny0 - 1.0), (nx, cork_top), nw - 0.6, "cork", prof="cyl")
    ic.ellipse(nx, cork_top, (nw - 0.6) / 2, 1.0, tone("cork", 1.2, "ct"), dome=0.5)
    # glass highlights
    left = min(x for x, _ in body)
    top = min(ys)
    ic.bar((left + 3.2, top + 5), (left + 3.0, max(ys) - 6), 1.4, "frost")
    ic.bar((nx - nw / 2 + 1.0, ny0 + 1), (nx - nw / 2 + 1.0, ny1 - 1), 0.8, "frost")


def ellipse_pts(cx, cy, rx, ry, n=28, a0=0.0):
    return [(cx + math.cos(a0 + k / n * math.tau) * rx, cy + math.sin(a0 + k / n * math.tau) * ry) for k in range(n)]


# ------------------------------------------------------------------- items
def i_herb(ic, st):
    """Dried sage bundle tied with twine: a tight fan of broad, soft grey-green
    leaves, stems gathered and cut square below the tie."""
    rng = np.random.default_rng(3)
    for dx in (-6, -3, 0, 3, 6):
        ic.bar((48 + dx * 0.5, 70), (48 + dx * 1.2, 92), 2.0, "stem", prof="cyl")
    ic.ellipse(48, 92, 5, 1.6, tone("stem", 0.7, "cut"), dome=0.4)
    for k in range(34):
        a = math.radians(-90 + rng.uniform(-38, 38))
        r = rng.uniform(10, 50)
        x, y = 48 + math.cos(a) * r * 0.75, 70 + math.sin(a) * r
        rot = a + rng.uniform(-0.25, 0.25)
        ln = rng.uniform(6.5, 9.5)
        lx, ly = math.cos(rot) * ln, math.sin(rot) * ln
        ic.bar((x - lx, y - ly), (x + lx, y + ly), rng.uniform(5.5, 7.5), tone("sage", rng.uniform(0.78, 1.15), "s%d" % (k % 5)), w1=1.4, prof="cyl")
        if L._detail() and k % 2 == 0:
            ic.bar((x - lx * 0.8, y - ly * 0.8), (x + lx * 0.8, y + ly * 0.8), 0.5, tone("sage", 0.6, "vein"))
    for k in range(4):
        y = 68 + k * 2.4
        ic.bar((39, y + 1), (57, y - 1), 1.8, "twine", prof="cyl")
    ic.bar((56, 69), (66, 80), 1.3, "twine", prof="cyl")
    ic.bar((56, 69), (63, 84), 1.3, "twine", prof="cyl")



def i_fungus(ic, st):
    """A real cluster of plague fungus: domed caps on pale stems, gills, spots."""
    caps = [(34, 52, 16, 10), (58, 40, 20, 12), (66, 64, 12, 8), (44, 70, 10, 6)]
    # stems first
    for (x, y, rx, ry) in caps:
        ic.bar((x, y + ry * 0.4), (x + (48 - x) * 0.3, 86), rx * 0.42, "fungus_st", w1=rx * 0.55, prof="cyl")
    ic.ellipse(48, 86, 20, 5, tone("dust", 0.7, "soil"), dome=0.6)
    for (x, y, rx, ry) in caps:
        ic.ellipse(x, y + ry * 0.55, rx * 0.92, ry * 0.45, tone("fungus_st", 0.7, "gill"), dome=0.3)
        for g in range(7):
            gx = x - rx * 0.8 + g * rx * 0.27
            ic.bar((gx, y + ry * 0.35), (gx + (x - gx) * 0.2, y + ry * 0.75), 0.5, tone("fungus_st", 0.5, "gl"))
        cap = [(x - rx, y + ry * 0.4)] + bez((x - rx, y + ry * 0.4), (x - rx * 0.8, y - ry * 1.1), (x, y - ry), 8) + bez((x, y - ry), (x + rx * 0.8, y - ry * 1.1), (x + rx, y + ry * 0.4), 8) + [(x, y + ry * 0.6)]
        ic.poly(cap, "fungus", bevel=4.0, dome=0.95)
        rng = np.random.default_rng(int(x * 7 + y))
        for s in range(5):
            sx = x + rng.uniform(-rx * 0.6, rx * 0.6)
            sy = y - ry * rng.uniform(0.1, 0.7)
            ic.ellipse(sx, sy, rng.uniform(1.0, 2.0), rng.uniform(0.8, 1.4), tone("fungus_st", 0.95, "spot"), dome=0.6)
    # a wet drip of ooze
    ic.bar((70, 68), (71, 78), 1.4, tone("plague", 0.8, "ooze") if "plague" in L.MAT else "glass", prof="cyl")


def i_crystal_cluster(ic, st):
    """Mineral cluster: faceted amber prisms on a rock base, flat-cut facets."""
    ic.poly([(22, 80), (36, 72), (62, 70), (78, 78), (70, 88), (28, 90)], tone("ash", 0.7, "rock"), bevel=3.0, dome=0.8)
    for (x, w, h, lean) in ((48, 13, 58, -2), (34, 9, 38, -14), (62, 10, 44, 12), (42, 7, 28, -6), (56, 7, 26, 6)):
        bx, by = x, 78
        tx, ty = x + lean * 0.6, by - h
        # two facets (lit left, shaded right) + a cap facet
        ic.poly([(bx - w / 2, by), (bx, by + 2), (tx, ty + w * 0.6), (tx - w * 0.45, ty + w * 0.9)], tone("amber", 1.12, "fl"), bevel=0.8, dome=0.2)
        ic.poly([(bx, by + 2), (bx + w / 2, by), (tx + w * 0.45, ty + w * 0.9), (tx, ty + w * 0.6)], tone("amber", 0.72, "fr"), bevel=0.8, dome=0.2)
        ic.poly([(tx - w * 0.45, ty + w * 0.9), (tx, ty + w * 0.6), (tx + w * 0.45, ty + w * 0.9), (tx, ty)], tone("amber", 1.3, "fc"), bevel=0.6, dome=0.2)
        ic.bar((bx - w * 0.2, by - 4), (tx - w * 0.15, ty + w), 0.6, "frost")


def i_jerrycan(ic, st):
    """Dented steel jerry can: X-embossed sides, triple handle, spout cap with
    clamp, weld seam, chipped olive paint, rust at the bottom."""
    body = [(20, 22), (70, 22), (76, 28), (76, 88), (70, 92), (20, 92), (16, 88), (16, 28)]
    ic.poly(body, "olivep", bevel=5.0, dome=0.8)
    # X emboss (raised ridges)
    for (a, b) in (((22, 34), (70, 86)), ((70, 34), (22, 86))):
        ic.bar(a, b, 5.0, tone("olivep", 1.12, "xr"), prof="cyl")
    ic.bar((16, 58), (76, 58), 2.4, tone("olivep", 0.7, "seam"))
    ic.weld((18, 58), (74, 58), 0.8)
    # handles on top
    for x in (28, 42, 56):
        ic.bar((x, 22), (x, 12), 3.0, "olivep", prof="cyl")
    ic.bar((26, 12), (58, 12), 3.0, "olivep", prof="cyl")
    # spout with cap + clamp lever
    ic.bar((68, 22), (74, 12), 9.0, "steel", prof="cyl")
    ic.ellipse(74, 11, 4.6, 2.4, tone("steel", 1.2, "cap"), dome=0.6)
    ic.bar((62, 18), (70, 8), 2.0, "steel", prof="cyl")
    # dents (a dark crease + lit lip)
    crease(ic, bez((24, 74), (32, 70), (36, 78), 5), 1.2, tone("olivep", 0.55, "dent"), tone("olivep", 1.3, "dl"))
    ic.scratches(count=18)


def i_power_cell(ic, st):
    """Glass-and-steel power cell, stocky: knurled steel end caps, three guard
    rods, a thick glass drum with a pale cyan charge, brass contacts."""
    ic.bar((48, 30), (48, 72), 44, "cellglass", prof="cyl")
    ic.bar((48, 36), (48, 66), 24, tone("cellglass", 1.45, "core"), prof="cyl")
    ic.ellipse(48, 51, 7, 9, tone("cellglass", 1.9, "hot"), dome=0.6)
    ic.bar((33, 32), (33, 70), 1.8, "frost")
    for x in (24, 48, 72):
        ic.bar((x, 26), (x, 76), 3.6, "steel", prof="cyl")
    for (y0, y1) in ((16, 30), (72, 86)):
        ic.bar((48, y0), (48, y1), 56, "gun", prof="cyl")
        for k in range(12):
            x = 23 + k * 4.6
            ic.bar((x, y0 + 1), (x, y1 - 1), 0.6, "dark")
        ic.bar((20, y0 + 1), (76, y0 + 1), 1.2, tone("gun", 1.4, "rim"))
    for x in (38, 48, 58):
        ic.bar((x, 86), (x, 92), 2.6, "brass", prof="cyl")
    rivets(ic, [(24, 22), (72, 22), (24, 80), (72, 80)], 1.2)
    ic.scratches(count=10)


def i_medkit(ic, st):
    """Worn steel first-aid case: rounded box, hinge line, two latches, carry
    handle, chipped red cross, dents and grime."""
    ic.poly([(12, 30), (84, 30), (88, 36), (88, 82), (84, 86), (12, 86), (8, 82), (8, 36)], "steel", bevel=5.0, dome=0.85)
    ic.bar((8, 44), (88, 44), 1.4, tone("steel", 0.6, "hinge"))
    ic.bar((36, 30), (36, 20), 3.2, "rubber", prof="cyl")
    ic.bar((60, 30), (60, 20), 3.2, "rubber", prof="cyl")
    ic.bar((35, 20), (61, 20), 3.6, "rubber", prof="cyl")
    for x in (22, 74):
        ic.poly([(x - 4, 40), (x + 4, 40), (x + 4, 50), (x - 4, 50)], tone("steel", 1.15, "latch"), bevel=1.0)
        ic.rivet(x, 48, 0.9)
    ic.bar((48, 52), (48, 78), 9.0, "redp", prof="box")
    ic.bar((35, 65), (61, 65), 9.0, "redp", prof="box")
    crease(ic, bez((66, 72), (72, 70), (78, 76), 4), 1.0, tone("steel", 0.55, "dent"), tone("steel", 1.3, "dl"))
    ic.scratches(count=16)


def _tonic(kind, body, neck, cork_top, level, seed, extra=None):
    def fn(ic, st):
        bottle(ic, body, "liq_" + kind, neck, cork_top, level, seed)
        ys = [y for _, y in body]
        xs = [x for x, _ in body]
        cy = (min(ys) + max(ys)) / 2 + 4
        lw = (max(xs) - min(xs)) * 0.46
        label(ic, 48 - lw / 2 + 2, cy - 4, 48 + lw / 2 + 2, cy + 6, seed)
        if extra:
            extra(ic)
    return fn


def _twine_neck(ic, y=26):
    ic.bar((42, y), (54, y + 1), 1.4, "twine", prof="cyl")
    ic.bar((52, y + 1), (58, y + 9), 1.0, "twine", prof="cyl")


def _copper_wire(ic):
    for k in range(5):
        ic.bar((42, 22 + k * 2), (54, 23 + k * 2), 1.0, "copper", prof="cyl")


def _iron_band(ic):
    ic.bar((28, 66), (68, 66), 3.0, "gun", prof="box")
    ic.rivet(48, 66, 1.0)


def _wax_seal(ic):
    ic.ellipse(48, 16, 6.4, 3.2, "wax", dome=0.8)
    ic.bar((44, 18), (44, 26), 2.4, "wax", prof="cyl")


def _brass_stopper(ic):
    ic.ellipse(48, 12, 5.6, 5.6, "brass", dome=0.95)
    ic.bar((48, 6), (48, 18), 1.4, "brass", prof="cyl")
    ic.bar((44, 10), (52, 10), 1.4, "brass", prof="cyl")


TONICS = {
    # round flask
    "menders": _tonic("menders", G.ellipse_pts(48, 62, 26, 26, 32) if hasattr(G, "ellipse_pts") else ellipse_pts(48, 62, 26, 26, 32), (48, 22, 38, 9), 14, 52, 1, lambda ic: _twine_neck(ic)),
    # square shouldered bottle
    "iron": _tonic("iron", [(26, 36), (70, 36), (72, 40), (72, 90), (24, 90), (24, 40)], (48, 18, 37, 10), 10, 48, 2, _iron_band),
    # flat rectangular apothecary bottle with wax-sealed cork
    "ward": _tonic("ward", [(30, 34), (66, 34), (70, 40), (70, 88), (26, 88), (26, 40)], (48, 20, 35, 9), 14, 44, 3, _wax_seal),
    # round-bottom firebrand flask
    "firebrand": _tonic("firebrand", ellipse_pts(48, 64, 24, 24, 32), (48, 20, 42, 8), 12, 56, 4),
    # tall slim bottle with copper wire
    "spark": _tonic("spark", [(36, 34), (60, 34), (62, 40), (62, 92), (34, 92), (34, 40)], (48, 16, 35, 8), 8, 46, 5, _copper_wire),
    # conical (erlenmeyer) flask
    "quickstep": _tonic("quickstep", [(42, 36), (54, 36), (78, 88), (18, 88)], (48, 16, 37, 9), 8, 52, 6),
    # ornate round bottle with brass cross stopper
    "saints": _tonic("saints", ellipse_pts(48, 62, 24, 26, 32), (48, 22, 38, 8), 18, 54, 7, _brass_stopper),
}


def i_dust_heart(ic, st):
    """Amber heart relic in a riveted wire cage (matches the armour Legendary)."""
    heart = []
    for k in range(48):
        t = k / 48 * math.tau
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        heart.append((48 + x * 1.9, 50 + y * 1.9))
    ic.poly(heart, "amber", bevel=8.0, dome=0.95)
    crease(ic, bez((48, 30), (44, 46), (50, 64), 6), 0.8, tone("amber", 0.6, "crack"))
    ic.bar((34, 36), (40, 30), 2.0, "frost")
    ic.ellipse(48, 50, 14, 16, tone("amber", 1.45, "glowcore"), dome=0.4)
    for (a, b, c) in (((18, 40), (48, 28), (78, 40)), ((20, 52), (48, 62), (76, 52)), ((48, 20), (44, 52), (48, 84))):
        for p, q in zip(bez(a, b, c, 10)[:-1], bez(a, b, c, 10)[1:]):
            ic.bar(p, q, 2.0, "gun", prof="cyl")
    ic.bar((48, 10), (48, 22), 1.6, "gold", prof="cyl")
    ic.ellipse(48, 9, 3.6, 3.6, "gold", dome=0.9)
    ic.ellipse(48, 9, 2.0, 2.0, "dark", dome=-0.2)
    rivets(ic, [(18, 40), (78, 40), (48, 84), (48, 22)], 1.4, "brass")


def _nut(ic, x, y, r, rot, mat="steel"):
    ic.poly([(x + math.cos(rot + k * math.pi / 3) * r, y + math.sin(rot + k * math.pi / 3) * r * 0.8) for k in range(6)], mat, bevel=1.8, dome=0.7)
    ic.ellipse(x, y, r * 0.42, r * 0.34, "dark", dome=-0.4)
    ic.ellipse(x - 0.4, y - 0.3, r * 0.3, r * 0.22, tone(mat, 0.6, "thr"), dome=-0.2)


def _washer(ic, x, y, r, mat="steel"):
    ic.ellipse(x, y, r, r * 0.72, mat, dome=0.6)
    ic.ellipse(x, y, r * 0.45, r * 0.32, "dark", dome=-0.4)


def _bolt(ic, x0, y0, x1, y1, w, mat="steel"):
    ic.bar((x0, y0), (x1, y1), w, mat, prof="cyl")
    L_ = math.hypot(x1 - x0, y1 - y0)
    n = int(L_ / 1.6)
    if L._detail():
        for i in range(2, n):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            dx, dy = -(y1 - y0) / L_ * w * 0.5, (x1 - x0) / L_ * w * 0.5
            ic.bar((x - dx, y - dy), (x + dx + 0.3, y + dy + 0.3), 0.4, tone(mat, 0.55, "th"))
    _nut(ic, x0, y0, w * 1.15, math.atan2(y1 - y0, x1 - x0), mat)


def i_scrap(ic, st):
    """Scrap: three big chunky pieces of hardware: a fat hex bolt with deep
    threads, a heavy hex nut, a thick washer: worn steel, rust in the threads."""
    ic.ellipse(48, 84, 36, 6, tone("dust", 0.45, "sh"), dome=0.2)
    _bolt(ic, 20, 30, 62, 72, 12.0, "steel")
    _nut(ic, 66, 46, 18, 0.15, "gun")
    _washer(ic, 30, 72, 14, "steel")
    ic.scratches(count=12)



def i_xp_shard(ic, st):
    """XP: one chunky faceted amber crystal leaning right: hexagonal body
    with an angled termination whose broad top facet catches the light,
    inner glow, a chipped edge and a dusty base."""
    a = math.radians(14)
    ca, sa = math.cos(a), math.sin(a)
    def P(u, v):  # u across, v up from base centre (44, 86)
        return (44 + u * ca + v * sa, 86 + u * sa - v * ca)
    w = 22
    ic.ellipse(46, 87, 30, 6, tone("dust", 0.45, "xs"), dome=0.2)
    L0, L1, R1, R0 = -w, -w * 0.4, w * 0.4, w
    body = [
        ([P(L0, 4), P(L1, 0), P(L1, 52), P(L0, 50)], 1.1),
        ([P(L1, 0), P(R1, 0), P(R1, 46), P(L1, 52)], 0.88),
        ([P(R1, 0), P(R0, 4), P(R0, 40), P(R1, 46)], 0.6),
    ]
    for i, (pts, t) in enumerate(body):
        ic.poly(pts, tone("amber", t, "xf%d" % i), bevel=1.0, dome=0.25)
    tip = P(-4, 72)
    ic.poly([P(L0, 50), P(L1, 52), P(R1, 46), tip], tone("amber", 1.5, "top"), bevel=0.8, dome=0.15)
    ic.poly([P(L0, 50), tip, P(L0 + 4, 60)], tone("amber", 1.2, "t0"), bevel=0.5, dome=0.15)
    ic.poly([P(R1, 46), P(R0, 40), tip], tone("amber", 0.72, "t2"), bevel=0.5, dome=0.15)
    ic.ellipse(*P(-4, 26), 8, 15, tone("amber", 1.45, "core"), dome=0.3)
    ic.bar(P(L1, 4), P(L1, 50), 1.0, tone("amber", 1.7, "edge"))
    ic.bar(P(L0 + 3, 8), P(L0 + 3, 46), 1.4, "frost")
    ic.poly([P(R1 + 2, 22), P(R0, 18), P(R0, 30)], tone("amber", 0.45, "chip"), bevel=0.4)





def i_backpack(ic, st):
    """Worn canvas rucksack: top flap with straps and buckles, two side
    pockets, a front pocket, stitching, patches, a rolled bedroll on top."""
    ic.bar((24, 16), (72, 16), 12, "olivep" if False else tone("canvas", 0.9, "roll"), prof="cyl")
    ic.bar((26, 16), (26, 16.2), 12.4, "leatherb")
    ic.bar((70, 16), (70, 16.2), 12.4, "leatherb")
    ic.poly([(18, 30), (78, 30), (82, 40), (80, 90), (16, 90), (14, 40)], "canvas", bevel=6.0, dome=0.8)
    ic.poly([(16, 28), (80, 28), (82, 50), (48, 54), (14, 50)], tone("canvas", 1.1, "flap"), bevel=3.0, dome=0.8)
    G.stitch(ic, [(18, 48), (48, 52), (78, 48)], 1.4)
    for x in (32, 64):
        G.strap(ic, (x, 36), (x, 66), 4.0, G.GENERIC, buck=0.85)
    ic.poly([(28, 62), (68, 62), (70, 86), (26, 86)], tone("canvas", 0.92, "fp"), bevel=2.0, dome=0.7)
    G.stitch(ic, [(29, 64), (67, 64), (68, 84), (28, 84), (29, 64)], 1.4)
    for x in (10, 86):
        ic.poly([(x - 5, 52), (x + 5, 52), (x + 5, 84), (x - 5, 84)], tone("canvas", 0.85, "sp"), bevel=2.0, dome=0.8)
    ic.patch(64, 74, 8, 6, 0.1, "leatherb")
    ic.scratches(count=8)


def i_crate(ic, st):
    """Wooden ammo crate: planks with grain, steel corner brackets, rope
    handle, stencilled chevron + bars (no readable text)."""
    ic.poly([(10, 30), (86, 30), (86, 88), (10, 88)], "plank", bevel=3.0, dome=0.6)
    for y in (44, 58, 72):
        ic.bar((10, y), (86, y), 1.0, tone("plank", 0.55, "gap"))
    ic.poly([(8, 24), (88, 24), (90, 32), (6, 32)], tone("plank", 1.1, "lid"), bevel=1.6, dome=0.7)
    for (x0, y0) in ((10, 30), (78, 30), (10, 80), (78, 80)):
        ic.poly([(x0, y0), (x0 + 8, y0), (x0 + 8, y0 + 8), (x0, y0 + 8)], "steel", bevel=1.0)
        ic.rivet(x0 + 4, y0 + 4, 0.9)
    # stencil: chevron + two bars, worn
    ic.poly([(30, 50), (48, 40), (66, 50), (66, 56), (48, 46), (30, 56)], "stencil", bevel=0.6, dome=0.2)
    ic.bar((32, 66), (64, 66), 3.0, "stencil")
    ic.bar((36, 72), (60, 72), 2.0, "stencil")
    for x in (2, 94):
        ic.bar((x, 46), (x, 62), 2.4, "rope", prof="cyl")
    ic.scratches(count=10)


AMMO_COL = {"explosive": "#7a3428", "frost": "#5e7a8a", "incendiary": "#9a5a2a", "shock": "#3a6470"}


def _ammo(el):
    def fn(ic, st):
        """Steel ammo can (M2A1 pattern): lid with a lever latch, folding
        handle, olive paint chipped to steel, an element-coloured stencil
        band with a painted mark."""
        ic.poly([(16, 34), (80, 34), (82, 38), (82, 90), (14, 90), (14, 38)], "olivep", bevel=4.0, dome=0.8)
        ic.poly([(12, 26), (84, 26), (86, 36), (10, 36)], tone("olivep", 1.1, "lid"), bevel=2.0, dome=0.8)
        ic.bar((36, 26), (36, 18), 2.6, "steel", prof="cyl")
        ic.bar((60, 26), (60, 18), 2.6, "steel", prof="cyl")
        ic.bar((35, 18), (61, 18), 2.6, "steel", prof="cyl")
        ic.poly([(70, 26), (82, 26), (82, 46), (76, 50), (70, 46)], "steel", bevel=1.2)
        ic.rivet(76, 30, 1.0)
        dye = L.MAT.setdefault("ammo_" + el, dict(c=hx(AMMO_COL[el]), spec=0.3, grime=0.6, rust=0.2, chip="olivep", metal=0.0))
        ic.bar((16, 60), (80, 60), 22, "ammo_" + el, prof="box")
        ic.bar((12, 31), (84, 31), 3.0, "ammo_" + el)
        # painted mark per element
        if el == "explosive":
            ic.ellipse(48, 60, 6.0, 6.0, "stencil", dome=0.2)
            for k in range(8):
                a = k / 8 * math.tau
                ic.bar((48 + math.cos(a) * 7, 60 + math.sin(a) * 7), (48 + math.cos(a) * 11, 60 + math.sin(a) * 11), 1.8, "stencil")
        elif el == "frost":
            for k in range(3):
                a = k / 3 * math.pi
                ic.bar((48 - math.cos(a) * 10, 60 - math.sin(a) * 9), (48 + math.cos(a) * 10, 60 + math.sin(a) * 9), 2.2, "stencil")
        elif el == "incendiary":
            ic.poly([(48, 49), (56, 60), (52, 70), (44, 70), (40, 60)], "stencil", bevel=0.6)
        else:
            ic.poly([(52, 48), (41, 62), (49, 62), (44, 73), (56, 57), (48, 57)], "stencil", bevel=0.4)
        for x in (22, 30, 66, 74):
            ic.bar((x, 74), (x, 88), 0.8, tone("olivep", 0.6, "rib"))
        ic.scratches(count=12)
    return fn


def i_medal(ic, st):
    """Stamped brass rank medal hanging from a striped ribbon."""
    ic.poly([(32, 6), (64, 6), (60, 40), (36, 40)], "ribbon_r", bevel=1.4, dome=0.6)
    for x in (40, 48, 56):
        ic.bar((x, 6), (x - 1.0, 40), 2.4, "ribbon_b")
    ic.bar((34, 40), (62, 40), 3.0, "brass", prof="cyl")
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 28 if k % 2 == 0 else 13
        pts.append((48 + math.cos(a) * r, 66 + math.sin(a) * r))
    ic.poly(pts, "brass", bevel=3.0, dome=0.9)
    ic.ellipse(48, 66, 10, 10, tone("brass", 0.85, "boss"), dome=0.8)
    for k in range(2):
        y = 62 + k * 6
        ic.poly([(41, y + 3), (48, y - 2), (55, y + 3), (55, y + 5), (48, y), (41, y + 5)], tone("brass", 1.25, "chev"), bevel=0.4)
    ic.scratches(count=8)


def i_flare(ic, st):
    """Extract: a thick road flare stuck in the dirt at an angle: red waxed
    tube, worn label band, black striker cap, bright painted spark burst
    and a smoke trail rising off the burning tip."""
    ic.ellipse(30, 86, 18, 5, tone("dust", 0.45, "fs"), dome=0.2)
    a, b = (26, 86), (52, 46)
    def L(t):
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    ic.bar(L(0.0), L(1.0), 22, "redp", prof="cyl")
    ic.bar(L(0.38), L(0.6), 22.6, "paper", prof="cyl")
    for t in (0.44, 0.5, 0.56):
        p = L(t)
        ic.bar((p[0] - 6, p[1] - 4), (p[0] + 4, p[1] + 2.4), 0.6, "ink")
    ic.bar(L(-0.02), L(0.16), 23, "dark", prof="cyl")
    ic.bar(L(0.96), L(1.08), 20, tone("redp", 0.45, "char"), prof="cyl")
    tip = L(1.1)
    for k in range(5):
        ic.ellipse(tip[0] + 6 + k * 5, tip[1] - 8 - k * 6, 6 + k * 1.8, 5 + k * 1.3, tone("smoke", 1.45 - k * 0.08, "sm%d" % k), dome=0.3)
    ic.ellipse(tip[0], tip[1], 16, 15, tone("flame", 0.8, "halo"), dome=0.3)
    ic.ellipse(tip[0], tip[1], 12, 11, "flame", dome=0.5)
    ic.ellipse(tip[0], tip[1], 7, 6.5, "flame_hot", dome=0.5)
    for k in range(10):
        ang = -math.pi / 2 + (k - 4.5) * 0.36
        ln = 17 + (k % 3) * 7
        ic.bar((tip[0] + math.cos(ang) * 8, tip[1] + math.sin(ang) * 8), (tip[0] + math.cos(ang) * ln, tip[1] + math.sin(ang) * ln),
               2.0 if k % 2 else 2.8, "flame_hot" if k % 2 else "flame", w1=0.6)




ITEMS = {
    "herb": i_herb, "plague_gland": i_fungus, "dust_shard": i_crystal_cluster, "machine_oil": i_jerrycan,
    "salvage_core": i_power_cell, "medicine": i_medkit,
    **{"tonic_" + k: v for k, v in TONICS.items()},
    "dust_heart": i_dust_heart, "scrap": i_scrap, "xp": i_xp_shard, "backpack": i_backpack, "supply_crate": i_crate,
    **{"ammo_" + e: _ammo(e) for e in ("explosive", "frost", "incendiary", "shock")},
    "level": i_medal, "extract": i_flare,
}
## where each item goes: IconSet ids (48 + 24) and 96 px world files (relative to sprites/)
OUT = {
    "herb": (["ing_herb"], ["depth/icons/herb.png"]),
    "plague_gland": (["ing_plague_gland"], ["depth/icons/plague_gland.png"]),
    "dust_shard": (["ing_dust_shard"], ["depth/icons/dust_shard.png"]),
    "machine_oil": (["ing_machine_oil"], ["depth/icons/machine_oil.png"]),
    "salvage_core": (["ing_salvage_core", "mat_salvage_core"], ["depth/icons/salvage_core.png", "pickups/salvage_core.png"]),
    "medicine": (["ing_medicine"], ["depth/icons/medicine.png"]),
    **{"tonic_" + k: (["tonic_" + k], ["depth/icons/tonic_%s.png" % k]) for k in TONICS},
    "dust_heart": (["mat_dust_heart"], ["pickups/dust_heart.png"]),
    "scrap": (["cur_scrap"], []),
    "xp": (["cur_xp"], []),
    "backpack": (["camp_backpack"], ["depth/icons/backpack.png"]),
    "supply_crate": ([], ["pickups/supply_crate.png"]),
    **{"ammo_" + e: (["ammo_" + e], ["pickups/ammo_%s.png" % e]) for e in ("explosive", "frost", "incendiary", "shock")},
    "level": (["cur_level"], []),
    "extract": (["cur_extract"], []),
}
## Shipped items (judged side by side with the armour at in-game size).
## Left out: scrap (a hardware pile is messy next to numbers at 24 px; the
## old nut-and-bolt currency mark reads better), xp (reads as a cone), extract
## (the flare is a thin diagonal at 24 px; the portal mark reads better).
WIRE = list(ITEMS)

for k, fn in ITEMS.items():
    G.SHAPES["loot_" + k] = fn


def render(k, mode):
    return G.build("loot_" + k, G.GENERIC, 700 + sorted(ITEMS).index(k), mode)


def run(k):
    sets, worlds = OUT[k]
    for sid in sets:
        for mode in ("s48", "s24"):
            Image.fromarray(render(k, mode), "RGBA").save(os.path.join(SET, mode[1:], sid + ".png"))
    for w in worlds:
        Image.fromarray(render(k, "hd"), "RGBA").save(os.path.join(A, w))
    return k


if __name__ == "__main__":
    import multiprocessing as mp
    ks = [k for k in WIRE if not sys.argv[1:] or k in sys.argv[1:]]
    with mp.Pool(min(4, os.cpu_count() or 1)) as pool:
        for k in pool.imap_unordered(run, ks):
            print("ok", k)
