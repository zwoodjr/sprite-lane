#!/usr/bin/env python3
"""Map-detail art pass: biome ground textures, road/riverbed textures,
mid-scale wasteland props, a clustered-decal atlas and the tumbleweed.

  python3 tools/gen_map_detail.py [REVIEW_DIR]

Writes PNGs under assets/sprites/{tiles,props,decals,fx} and the decal region
table scripts/world/decal_atlas.gd. Style matches the existing props: thick
dark outline, 3-5 tone ramps, light from the top-left, muted wasteland palette.
Ground/decals stay inside the floor's value band (~55-130) so units, pickups and
telegraphs still pop; props are stronger but desaturated.
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
SPR = ROOT / "assets" / "sprites"
REVIEW = Path(sys.argv[1]) if len(sys.argv) > 1 else None
T = 512
OUTL = (24, 18, 14, 255)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16 - 0.5

RAMP = {
    "rust": [(62, 32, 20), (96, 50, 28), (128, 72, 40), (156, 98, 60), (178, 126, 86)],
    "steel": [(34, 36, 38), (56, 60, 62), (82, 86, 88), (112, 114, 112), (146, 146, 140)],
    "concrete": [(70, 66, 60), (98, 94, 86), (124, 120, 110), (150, 145, 132), (174, 168, 152)],
    "wood": [(56, 38, 26), (82, 56, 36), (108, 76, 50), (134, 98, 66), (156, 120, 84)],
    "mustard": [(70, 58, 36), (100, 84, 52), (128, 110, 70), (152, 134, 92), (172, 156, 114)],
    "slate": [(40, 46, 50), (62, 70, 74), (86, 96, 98), (112, 120, 120), (140, 146, 142)],
    "khaki": [(74, 64, 46), (102, 90, 64), (130, 116, 84), (156, 142, 106), (178, 166, 130)],
    "soot": [(22, 20, 20), (36, 32, 30), (52, 46, 42), (70, 62, 56), (90, 80, 72)],
}


def C(name, i, a=255):
    return tuple(RAMP[name][i]) + (a,)


# ---------------------------------------------------------------- helpers
def wrap_noise(nr, sigma, size=T):
    f = ndi.gaussian_filter(nr.random((size, size)), sigma, mode="wrap")
    return (f - f.min()) / (f.max() - f.min())


def quantize(v, ramp, dither=0.6):
    size = v.shape[0]
    bay = np.tile(BAYER, (size // 4, size // 4))
    n = len(ramp) - 1
    idx = np.clip(np.round(v * n + bay * dither), 0, n).astype(int)
    return Image.fromarray(np.array(ramp, np.uint8)[idx]).convert("RGBA")


def wrapped(d_fn, size=T):
    for ox in (-size, 0, size):
        for oy in (-size, 0, size):
            d_fn(ox, oy)


def voronoi_edges(nr, cell, size=T, keep=1.0, jitter=0.9):
    """Wrap-safe Voronoi edge mask (bool) with ~cell px cells."""
    n = size // cell
    pts = []
    for gy in range(n):
        for gx in range(n):
            pts.append(((gx + 0.5 + (nr.random() - 0.5) * jitter) * cell, (gy + 0.5 + (nr.random() - 0.5) * jitter) * cell))
    pts = np.array(pts)
    allp = np.concatenate([pts + [ox, oy] for ox in (-size, 0, size) for oy in (-size, 0, size)])
    yy, xx = np.mgrid[0:size, 0:size]
    from scipy.spatial import cKDTree
    tree = cKDTree(allp)
    d, i = tree.query(np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], 1), k=2)
    gap = (d[:, 1] - d[:, 0]).reshape(size, size)
    owner = (i[:, 0] % len(pts)).reshape(size, size)
    edge = gap < 1.3
    if keep < 1.0:
        # Drop whole runs of edges by masking with smooth noise.
        m = wrap_noise(nr, 10, size)
        edge &= m < keep
    return edge, owner, d[:, 0].reshape(size, size)


def paint(img, mask, rgb, a=255):
    arr = np.array(img)
    arr[mask] = list(rgb[:3]) + [a]
    return Image.fromarray(arr)


def blend_mask(img, mask, rgb, alpha):
    arr = np.array(img).astype(np.float32)
    k = (mask.astype(np.float32) * alpha)[..., None]
    arr[..., :3] = arr[..., :3] * (1 - k) + np.array(rgb[:3], np.float32) * k
    return Image.fromarray(arr.astype(np.uint8))


def shift(mask, dx, dy):
    return np.roll(np.roll(mask, dy, 0), dx, 1)


def outline(img, width=1, thresh=100, color=OUTL):
    a = img.split()[3].point(lambda v: 255 if v > thresh else 0)
    for _ in range(width):
        a = a.filter(ImageFilter.MaxFilter(3))
    o = Image.new("RGBA", img.size, (0, 0, 0, 0))
    o.paste(color, (0, 0), a)
    o.alpha_composite(img)
    return o


def ground_shadow(img, rx, ry, cx=None, cy=None, a=70):
    """Soft dark blob under a prop (offset down-right: light from top-left)."""
    w, h = img.size
    cx = w / 2 + 3 if cx is None else cx
    cy = h - ry - 2 if cy is None else cy
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(20, 14, 10, a))
    sh.alpha_composite(img)
    return sh


def grit(img, nr, ramp_name, amount=0.08, lo=0, hi=4):
    """Sprinkle ramp pixels over opaque parts for texture."""
    arr = np.array(img)
    op = arr[..., 3] > 200
    r = nr.random(op.shape)
    for k, (cut, idx) in enumerate([(amount, lo), (amount * 2, hi)]):
        m = op & (r < cut) & (r >= (amount if k else 0))
        arr[m, :3] = RAMP[ramp_name][idx]
    return Image.fromarray(arr)


def rust_mask(img, nr, colors, cover=0.35, sigma=2.5):
    arr = np.array(img)
    h, w = arr.shape[:2]
    f = ndi.gaussian_filter(nr.random((h, w)), sigma)
    f = (f - f.min()) / max(1e-6, f.max() - f.min())
    op = arr[..., 3] > 200
    for thr, col in zip(np.linspace(1 - cover, 1 - cover * 0.35, len(colors)), colors):
        arr[op & (f > thr), :3] = col[:3]
    return Image.fromarray(arr)


# ---------------------------------------------------------------- ground
def ground_earth(seed=11):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 18) * 0.55 + wrap_noise(nr, 3) * 0.45
    img = quantize(v, [(74, 58, 44), (82, 64, 48), (89, 70, 52), (96, 76, 56), (103, 82, 61)])
    edge, owner, dist = voronoi_edges(nr, 52, keep=0.5)
    img = blend_mask(img, shift(edge, 1, 1), (108, 87, 66), 0.4)
    img = blend_mask(img, edge, (62, 48, 37), 0.6)
    # Slightly lifted plate centres read as baked mud.
    plates = (dist < 9) & (wrap_noise(nr, 12) > 0.55)
    img = blend_mask(img, plates, (108, 86, 64), 0.25)
    return img


def ground_sand(seed=12):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 22) * 0.6 + wrap_noise(nr, 2) * 0.4
    img = quantize(v, [(96, 79, 57), (103, 86, 62), (110, 92, 67), (117, 98, 72), (124, 105, 77)], 0.8)
    # Wind ripples: warped sine bands, wrap-safe (integer cycles over T).
    yy, xx = np.mgrid[0:T, 0:T].astype(np.float32)
    warp = (wrap_noise(nr, 30) - 0.5) * 40
    ph = (yy + warp + 6 * np.sin(xx / T * math.tau * 2)) / T * math.tau * 46
    s = np.sin(ph)
    rid = (s > 0.93) & (wrap_noise(nr, 14) > 0.35)
    img = blend_mask(img, rid, (88, 72, 52), 0.55)
    img = blend_mask(img, shift(rid, 0, -1), (128, 110, 82), 0.35)
    return img


def ground_scrub(seed=13):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 14) * 0.6 + wrap_noise(nr, 3) * 0.4
    img = quantize(v, [(62, 54, 40), (69, 60, 43), (76, 66, 47), (83, 72, 51), (90, 78, 55)])
    # Sparse dry grass blades, clumped.
    clump = wrap_noise(nr, 9)
    r = nr.random((T, T))
    blade = (r < 0.022) & (clump > 0.55)
    img = paint(img, blade, (96, 92, 58))
    img = paint(img, shift(blade, 0, 1), (78, 74, 46))
    dark = (r > 0.985) & (clump < 0.4)
    img = paint(img, dark, (54, 46, 34))
    return img


def ground_rubble(seed=14):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 16) * 0.6 + wrap_noise(nr, 3) * 0.4
    img = quantize(v, [(74, 66, 58), (81, 73, 64), (88, 80, 70), (95, 87, 76), (102, 94, 82)])
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    dens = wrap_noise(nr, 20)
    for _ in range(900):
        x, y = rnd.randrange(T), rnd.randrange(T)
        if dens[y, x] < 0.42:
            continue
        w = rnd.choice((1, 2, 2, 3))
        tone = rnd.choice(((112, 106, 96), (104, 98, 90), (96, 84, 72)))
        def g(ox, oy, x=x, y=y, w=w, tone=tone):
            d.rectangle([x + ox + 1, y + oy + 1, x + ox + w + 1, y + oy + w], fill=(58, 52, 46))
            d.rectangle([x + ox, y + oy, x + ox + w, y + oy + w - 1], fill=tone)
        wrapped(g)
    edge, _, _ = voronoi_edges(nr, 64, keep=0.4)
    img = paint(img, edge, (64, 58, 50))
    return img


def ground_riverbed(seed=15):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 12) * 0.5 + wrap_noise(nr, 2) * 0.5
    img = quantize(v, [(104, 90, 70), (110, 96, 75), (116, 101, 79), (122, 106, 83), (127, 111, 87)])
    edge, owner, dist = voronoi_edges(nr, 26, jitter=1.0)
    # Curled plate edges: light top-left lip, dark crack.
    img = blend_mask(img, shift(edge, 1, 1), (128, 112, 88), 0.45)
    img = blend_mask(img, edge, (84, 71, 56), 0.65)
    return img


def ground_asphalt(seed=16, size=256):
    nr = np.random.default_rng(seed)
    v = wrap_noise(nr, 10, size) * 0.5 + wrap_noise(nr, 1, size) * 0.5
    img = quantize(v, [(54, 52, 50), (59, 57, 54), (64, 61, 58), (69, 66, 62), (74, 71, 66)], 0.9)
    r = nr.random((size, size))
    img = paint(img, r < 0.012, (86, 82, 76))
    img = paint(img, r > 0.992, (44, 42, 40))
    edge, _, _ = voronoi_edges(nr, 64, size, keep=0.35)
    img = paint(img, edge, (44, 42, 40))
    return img


# ---------------------------------------------------------------- props
def vehicle(w, h, body, seed, profile, windows, depth=6, burnt=False, wheels=(), rust=0.22):
    """3/4 side-view vehicle like wreck.png: lighter top surfaces show as a band
    above the side face (light from the top-left), windows, wheels, rust."""
    nr = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = [(x - 2, y - depth) for x, y in profile]
    d.polygon(top, fill=C(body, 3))
    # top-surface highlight along the upper edge
    d.line(top[1:-1], fill=C(body, 4))
    d.polygon(profile, fill=C(body, 2))
    ys = [y for _, y in profile]
    y_lo = max(ys)
    # lower half of the side face darker (body curving under)
    lower = Image.new("L", (w, h), 0)
    ImageDraw.Draw(lower).polygon(profile, fill=255)
    la = np.array(lower)
    yy = np.mgrid[0:h, 0:w][0]
    arr = np.array(img)
    m = (la > 0) & (yy > y_lo - 7)
    arr[m, :3] = RAMP[body][1]
    m2 = (la > 0) & (yy > y_lo - 3)
    arr[m2, :3] = RAMP[body][0]
    img = Image.fromarray(arr)
    d = ImageDraw.Draw(img)
    for poly in windows:
        d.polygon(poly, fill=C("soot", 1))
        xs = [x for x, _ in poly]
        ys2 = [y for _, y in poly]
        d.line([(min(xs) + 1, min(ys2) + 1), (min(xs) + 4, min(ys2) + 1)], fill=C("slate", 3))
    for wx, flat in wheels:
        r = 7
        d.ellipse([wx - r, y_lo - r + 1, wx + r, y_lo + r - 1 - (3 if flat else 0)], fill=C("soot", 0))
        d.ellipse([wx - 3, y_lo - 3, wx + 3, y_lo + 2 - (2 if flat else 0)], fill=C("steel", 1))
        d.point((wx - 1, y_lo - 2), fill=C("steel", 3))
    img = rust_mask(img, nr, [C("rust", 1), C("rust", 2)], cover=rust, sigma=1.6)
    if burnt:
        img = rust_mask(img, np.random.default_rng(seed + 5), [C("soot", 3), C("soot", 2), C("soot", 1)], cover=0.5, sigma=3.0)
    img = grit(img, nr, "rust", 0.015, 0, 3)
    return img


def prop_car():
    w, h = 88, 52
    b = h - 9
    prof = [(4, b), (4, b - 10), (12, b - 15), (26, b - 16), (34, b - 27), (58, b - 27), (66, b - 16),
            (80, b - 14), (84, b - 9), (84, b)]
    win = [[(28, b - 17), (35, b - 25), (45, b - 25), (45, b - 17)], [(48, b - 17), (48, b - 25), (57, b - 25), (63, b - 17)]]
    im = vehicle(w, h, "slate", 21, prof, win, wheels=((18, False), (70, True)), rust=0.34)
    d = ImageDraw.Draw(im)
    d.line([(46, b - 16), (46, b - 4)], fill=C("slate", 0))  # door seam
    d.polygon([(70, b - 22), (82, b - 21), (78, b - 16)], fill=C("slate", 3))  # popped hood
    im = outline(im)
    return ground_shadow(im, 42, 6)


def prop_truck():
    w, h = 120, 62
    b = h - 10
    prof = [(4, b), (4, b - 18), (70, b - 18), (74, b - 18), (78, b - 34), (100, b - 34), (106, b - 20),
            (114, b - 18), (116, b - 10), (116, b)]
    win = [[(80, b - 22), (83, b - 31), (98, b - 31), (102, b - 22)]]
    im = vehicle(w, h, "steel", 22, prof, win, wheels=((20, True), (52, False), (98, False)), rust=0.36)
    d = ImageDraw.Draw(im)
    for x in range(10, 70, 9):  # bed slats
        d.line([(x, b - 17), (x, b - 6)], fill=C("steel", 1))
    for x in (16, 34):  # junk in the bed
        d.rectangle([x, b - 30, x + 12, b - 22], fill=C("wood", 2))
        d.line([x, b - 30, x + 12, b - 30], fill=C("wood", 4))
    d.line([(106, b - 14), (114, b - 14)], fill=C("concrete", 3))  # grille
    im = outline(im)
    return ground_shadow(im, 58, 7)


def prop_bus():
    w, h = 172, 74
    b = h - 10
    prof = [(4, b), (4, b - 40), (8, b - 44), (160, b - 44), (166, b - 38), (168, b - 12), (168, b)]
    win = []
    for i in range(9):
        x = 14 + i * 15
        if i == 4:
            continue
        win.append([(x, b - 38), (x + 11, b - 38), (x + 11, b - 26), (x, b - 26)])
    win.append([(154, b - 38), (164, b - 38), (166, b - 24), (154, b - 24)])
    im = vehicle(172, 74, "mustard", 23, prof, win, depth=8, burnt=True,
                 wheels=((30, True), (138, False)), rust=0.18)
    d = ImageDraw.Draw(im)
    d.rectangle([74, b - 38, 84, b - 4], fill=C("soot", 1))  # open door
    d.line([(6, b - 20), (166, b - 20)], fill=C("mustard", 0))  # trim stripe
    for x in (60, 100, 120):  # soot streaks above windows
        d.line([(x, b - 52), (x + 6, b - 46)], fill=C("soot", 1))
    im = outline(im)
    return ground_shadow(im, 84, 7)


def prop_fence():
    w, h = 116, 46
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    posts = [(6, 6), (40, 6), (74, 10), (108, 6)]
    tops = []
    for i, (x, y) in enumerate(posts):
        lean = 7 if i == 2 else 0
        d.line([x, y + 34, x + lean, y], fill=C("steel", 2), width=3)
        d.line([x - 1, y + 34, x - 1 + lean, y], fill=C("steel", 3), width=1)
        tops.append((x + lean, y))
    # chain-link mesh between posts (diamond lattice), torn in the 3rd bay
    mesh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    md = ImageDraw.Draw(mesh)
    for k in range(-60, 160, 6):
        md.line([k, 4, k + 34, 40], fill=C("steel", 3, 120))
        md.line([k + 34, 4, k, 40], fill=C("steel", 3, 120))
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.polygon([(6, 6), (40, 6), (40, 40), (6, 40)], fill=255)
    mdraw.polygon([(40, 8), (81, 10), (74, 28), (60, 40), (40, 40)], fill=255)  # sagging, torn
    mdraw.polygon([(78, 30), (108, 6), (108, 40), (86, 40)], fill=255)
    clear = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    clear.paste(mesh, (0, 0), mask)
    img = Image.alpha_composite(clear, img)
    d = ImageDraw.Draw(img)
    d.line([6, 6, 40, 6], fill=C("steel", 2), width=2)
    d.line([40, 6, 62, 14], fill=C("steel", 2), width=2)
    d.line([88, 4, 108, 6], fill=C("steel", 2), width=2)
    # curl of torn mesh on the ground
    d.arc([56, 32, 80, 44], 180, 360, fill=C("steel", 2), width=2)
    img = rust_mask(img, np.random.default_rng(31), [C("rust", 2)], cover=0.25, sigma=1.5)
    img = outline(img, thresh=150)
    return ground_shadow(img, 54, 4, a=45)


def prop_pole():
    w, h = 180, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # stump
    d.rectangle([6, 22, 16, 44], fill=C("wood", 1))
    d.rectangle([6, 22, 10, 44], fill=C("wood", 2))
    d.polygon([(6, 22), (9, 14), (12, 22), (14, 17), (16, 22)], fill=C("wood", 3))
    # fallen pole lying diagonally
    p0, p1 = (24, 30), (150, 50)
    d.line([p0, p1], fill=C("wood", 1), width=9)
    d.line([(p0[0], p0[1] - 2), (p1[0], p1[1] - 2)], fill=C("wood", 2), width=4)
    d.line([(p0[0], p0[1] - 3), (p1[0], p1[1] - 3)], fill=C("wood", 3), width=1)
    for t in np.linspace(0.08, 0.95, 9):  # grain
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t
        d.point((x, y + 1), fill=C("wood", 0))
    # crossarm near the top end with insulators
    cx, cy = 136, 48
    d.line([(cx - 4, cy - 14), (cx + 6, cy + 12)], fill=C("wood", 1), width=4)
    d.line([(cx - 5, cy - 14), (cx + 5, cy + 12)], fill=C("wood", 2), width=1)
    ins = [(cx - 3, cy - 13), (cx + 1, cy - 1), (cx + 5, cy + 11)]
    for ix, iy in ins:
        d.rectangle([ix - 1, iy - 2, ix + 2, iy + 1], fill=C("concrete", 3))
        d.point((ix - 1, iy - 2), fill=C("concrete", 4))
    img = outline(img)
    img = ground_shadow(img, 70, 5, cx=92, cy=48, a=50)
    # sagging lines (thin, no outline) running off to the right
    d = ImageDraw.Draw(img)
    for k, (ix, iy) in enumerate(ins):
        pts = []
        for t in np.linspace(0, 1, 24):
            x = ix + (w - 2 - ix) * t
            y = iy + (6 + k * 3 - (iy - 30) * 0.2) * t + 10 * math.sin(math.pi * t) + (k - 1) * 2
            pts.append((x, min(h - 2, y)))
        d.line(pts, fill=(30, 26, 24, 210), width=1)
    return img


def prop_wall():
    w, h = 110, 58
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # standing broken section (left), toppled slab (right), rubble
    d.polygon([(6, 14), (20, 6), (34, 10), (44, 4), (52, 12), (52, 44), (6, 44)], fill=C("concrete", 1))
    d.polygon([(6, 14), (20, 6), (34, 10), (44, 4), (52, 12), (48, 16), (8, 18)], fill=C("concrete", 3))
    d.line([(8, 17), (48, 16)], fill=C("concrete", 4))
    for y in (24, 34):
        d.line([(8, y), (50, y)], fill=C("concrete", 0))
    for x in (20, 36):
        d.line([(x, 26), (x, 33)], fill=C("concrete", 0))
    # rebar from the broken top
    for x in (24, 30, 46):
        d.line([(x, 8), (x + 3, 0)], fill=C("rust", 2), width=1)
    # toppled slab lying flat
    d.polygon([(54, 30), (100, 22), (106, 36), (60, 46)], fill=C("concrete", 2))
    d.polygon([(60, 46), (106, 36), (106, 41), (61, 51)], fill=C("concrete", 0))
    d.line([(55, 30), (100, 22)], fill=C("concrete", 4))
    d.line([(72, 28), (84, 40)], fill=C("concrete", 0))
    for x in (100, 104):
        d.line([(x, 28), (x + 5, 24)], fill=C("rust", 2))
    rnd = random.Random(41)
    for _ in range(14):
        x, y = rnd.randint(4, 104), rnd.randint(44, 53)
        s = rnd.randint(2, 4)
        d.rectangle([x, y, x + s, y + s - 1], fill=C("concrete", rnd.choice((1, 2, 3))))
    img = grit(img, np.random.default_rng(42), "concrete", 0.04, 0, 4)
    img = rust_mask(img, np.random.default_rng(43), [(110, 100, 84, 255)], cover=0.2, sigma=2)
    img = outline(img)
    return ground_shadow(img, 50, 6, a=55)


def prop_barrels():
    w, h = 50, 46
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def barrel(x, y, ramp):
        d.rectangle([x, y + 4, x + 14, y + 22], fill=C(ramp, 1))
        d.rectangle([x, y + 4, x + 4, y + 22], fill=C(ramp, 2))
        for yy in (y + 9, y + 16):
            d.line([x, yy, x + 14, yy], fill=C(ramp, 0))
        d.ellipse([x, y, x + 14, y + 8], fill=C(ramp, 3))
        d.ellipse([x + 3, y + 2, x + 11, y + 6], fill=C(ramp, 2))
        d.point((x + 9, y + 3), fill=C("soot", 1))

    barrel(4, 6, "rust")
    barrel(20, 2, "slate")
    # tipped barrel
    d.rectangle([18, 28, 40, 40], fill=C("rust", 1))
    d.rectangle([18, 28, 40, 31], fill=C("rust", 3))
    for xx in (25, 32):
        d.line([xx, 28, xx, 40], fill=C("rust", 0))
    d.ellipse([38, 27, 46, 41], fill=C("rust", 2))
    d.ellipse([40, 30, 44, 38], fill=C("soot", 1))
    img = rust_mask(img, np.random.default_rng(51), [C("rust", 1), C("rust", 3)], cover=0.35, sigma=1.5)
    img = outline(img)
    # small leak puddle
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([30, 38, 49, 45], fill=(30, 28, 26, 120))
    sh.alpha_composite(img)
    return ground_shadow(sh, 20, 5, cx=26, a=55)


def prop_sandbags():
    w, h = 94, 44
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(61)

    def bag(x, y, bw=19, bh=11):
        d.rounded_rectangle([x, y, x + bw, y + bh], 5, fill=C("khaki", 0))
        d.rounded_rectangle([x, y, x + bw - 1, y + bh - 2], 5, fill=C("khaki", 1))
        d.ellipse([x + 2, y + 1, x + bw - 4, y + bh - 4], fill=C("khaki", 2))
        d.line([x + 5, y + 2, x + bw - 8, y + 2], fill=C("khaki", 3))
        d.line([x + bw - 3, y + 3, x + bw - 3, y + bh - 4], fill=C("khaki", 0))  # tied end

    for row, (y, n, off) in enumerate(((26, 4, 4), (18, 4, 12), (10, 3, 18))):
        for i in range(n):
            if row == 2 and i == 2 and rnd.random() < 2:
                continue
            bag(off + i * 17 + rnd.randint(-1, 1), y + rnd.randint(-1, 1))
    # spilt bag
    d.ellipse([60, 32, 74, 38], fill=C("khaki", 2))
    img = grit(img, np.random.default_rng(62), "khaki", 0.012, 0, 3)
    img = outline(img)
    return ground_shadow(img, 42, 5, a=55)


def prop_crater():
    w, h = 92, 62
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy, rx, ry = w / 2, h / 2, w / 2 - 6, h / 2 - 6
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    nr = np.random.default_rng(71)
    jag = ndi.gaussian_filter(nr.random((h, w)), 2) * 0.5
    r = r + (jag - jag.mean())
    arr = np.zeros((h, w, 4), np.uint8)
    # scorch halo
    halo = (r > 0.95) & (r < 1.35)
    arr[halo] = (62, 50, 40, 110)
    rim = (r > 0.78) & (r <= 0.98)
    lit = (xx - cx) * 0.6 + (yy - cy) > 0  # inner bottom-right faces the light
    arr[rim] = (104, 86, 64, 255)
    arr[rim & ~lit] = (96, 80, 60, 255)
    bowl = r <= 0.78
    shade = np.clip(((xx - cx) / rx + (yy - cy) / ry) * 0.5 + 0.5, 0, 1)
    tones = np.array([(46, 38, 32), (54, 44, 36), (62, 50, 40), (72, 58, 46)], np.uint8)
    bay = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    idx = np.clip(np.round(shade * 3 + bay * 0.8), 0, 3).astype(int)
    arr[bowl, :3] = tones[idx][bowl]
    arr[bowl, 3] = 255
    img = Image.fromarray(arr)
    d = ImageDraw.Draw(img)
    rnd = random.Random(72)
    for _ in range(16):  # thrown clods on the rim
        a = rnd.random() * math.tau
        rr = rnd.uniform(0.95, 1.25)
        x, y = cx + math.cos(a) * rx * rr, cy + math.sin(a) * ry * rr
        d.rectangle([x, y, x + 2, y + 1], fill=(58, 46, 36, 255))
        d.point((x, y), fill=(110, 92, 70, 255))
    # a bit of twisted shrapnel in the bowl
    d.line([(cx - 6, cy + 2), (cx + 2, cy - 1), (cx + 6, cy + 4)], fill=C("steel", 2), width=2)
    d.point((cx - 5, cy + 1), fill=C("steel", 4))
    return img


def tumbleweed():
    s = 26
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(81)
    c = s / 2
    for _ in range(46):
        a0 = rnd.random() * math.tau
        r0 = rnd.uniform(2, 10)
        a1 = a0 + rnd.uniform(-1.6, 1.6)
        r1 = rnd.uniform(5, 11)
        col = rnd.choice(((122, 100, 64, 255), (104, 84, 52, 255), (140, 118, 78, 255), (86, 68, 44, 255)))
        d.line([(c + math.cos(a0) * r0, c + math.sin(a0) * r0), (c + math.cos(a1) * r1, c + math.sin(a1) * r1)], fill=col)
    img = outline(img, thresh=60, color=(40, 30, 22, 255))
    return img


# ---------------------------------------------------------------- decals
def decal_bones(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (22, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rnd.randint(2, 14), rnd.randint(3, 10)
        l = rnd.randint(4, 7)
        d.line([x, y, x + l, y + rnd.randint(-2, 2)], fill=(122, 112, 92, 255))
        d.point((x, y), fill=(130, 120, 98, 255))
    if seed % 2 == 0:
        d.ellipse([12, 2, 18, 7], fill=(120, 110, 90, 255))
        d.point((14, 4), fill=(64, 54, 42, 255))
    return outline(img, color=(60, 48, 36, 200))


def decal_scrap(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (14, 10), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(3):
        x, y = rnd.randint(1, 9), rnd.randint(1, 6)
        col = rnd.choice(((96, 92, 86, 255), (110, 84, 60, 255), (84, 80, 76, 255)))
        d.polygon([(x, y), (x + rnd.randint(2, 4), y + rnd.randint(-1, 1)), (x + 1, y + rnd.randint(2, 3))], fill=col)
    return outline(img, color=(52, 42, 34, 220))


def decal_grass(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(9):
        x = rnd.randint(3, 12)
        top = rnd.randint(1, 6)
        lean = rnd.randint(-3, 3)
        col = rnd.choice(((112, 98, 60, 255), (96, 84, 52, 255), (124, 110, 70, 255)))
        d.line([x, 11, x + lean, top], fill=col)
    d.line([3, 11, 13, 11], fill=(66, 54, 40, 255))
    return img


def decal_oil(seed):
    nr = np.random.default_rng(seed)
    w, h = 30, 16
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w / 2 - 2)) ** 2 + ((yy - h / 2) / (h / 2 - 2)) ** 2)
    r += ndi.gaussian_filter(nr.random((h, w)), 1.5) * 0.6 - 0.3
    arr = np.zeros((h, w, 4), np.uint8)
    arr[r < 1.0] = (34, 30, 30, 130)
    arr[r < 0.75] = (28, 26, 28, 160)
    sheen = (r > 0.45) & (r < 0.55) & (xx < w / 2)
    arr[sheen] = (70, 66, 76, 150)
    return Image.fromarray(arr)


def decal_toxic(seed):
    nr = np.random.default_rng(seed)
    w, h = 26, 16
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((xx - w / 2) / (w / 2 - 4)) ** 2 + ((yy - h / 2) / (h / 2 - 3)) ** 2)
    r += ndi.gaussian_filter(nr.random((h, w)), 1.5) * 0.5 - 0.25
    arr = np.zeros((h, w, 4), np.uint8)
    glow = np.clip(1.6 - r, 0, 1)
    arr[..., :3] = (110, 170, 60)
    arr[..., 3] = (glow * 70).astype(np.uint8)
    arr[r < 1.0] = (62, 100, 40, 255)
    arr[r < 0.8] = (92, 140, 52, 255)
    arr[(r < 0.4)] = (126, 176, 74, 255)
    hi = (r < 0.5) & (xx < w / 2 - 2) & (yy < h / 2)
    arr[hi] = (160, 206, 104, 255)
    return Image.fromarray(arr)


def decal_crack(seed):
    rnd = random.Random(seed)
    w, h = 44, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    def br(x, y, a, n, depth):
        pts = [(x, y)]
        for _ in range(n):
            a += rnd.uniform(-0.6, 0.6)
            x += math.cos(a) * rnd.uniform(3, 6)
            y += math.sin(a) * rnd.uniform(2, 4)
            pts.append((x, y))
            if depth < 2 and rnd.random() < 0.25:
                br(x, y, a + rnd.choice((-1, 1)) * 1.0, n // 2, depth + 1)
        d.line([(px + 1, py + 1) for px, py in pts], fill=(112, 90, 68, 110))
        d.line(pts, fill=(54, 42, 32, 200))
    br(4, h / 2, rnd.uniform(-0.3, 0.3), 9, 0)
    return img


def decal_tracks(seed):
    rnd = random.Random(seed)
    w, h = 96, 18
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for base in (3, 12):
        y = base + rnd.uniform(-1, 1)
        x = 0
        while x < w:
            a = int(110 * (0.5 + 0.5 * math.sin(x / w * math.pi)))
            d.rectangle([x, int(y), x + 1, int(y) + 2], fill=(46, 36, 28, a))
            x += 3
            y += rnd.uniform(-0.25, 0.25)
    return img


def decal_pebbles(seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (20, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(6):
        x, y = rnd.randint(1, 16), rnd.randint(1, 10)
        s = rnd.choice((1, 2))
        d.rectangle([x + 1, y + 1, x + s + 1, y + s + 1], fill=(56, 46, 36, 255))
        d.rectangle([x, y, x + s, y + s], fill=rnd.choice(((108, 94, 76, 255), (98, 88, 74, 255))))
    return img


def build_atlas(decals):
    """Shelf-pack decals into one atlas; return image + {name: (x,y,w,h)}."""
    W = 256
    items = sorted(decals.items(), key=lambda kv: -kv[1].height)
    x = y = 0
    row_h = 0
    regions = {}
    for name, im in items:
        if x + im.width > W:
            x = 0
            y += row_h + 2
            row_h = 0
        regions[name] = (x, y, im.width, im.height)
        x += im.width + 2
        row_h = max(row_h, im.height)
    H = y + row_h
    H = 1 << (H - 1).bit_length()
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for name, im in decals.items():
        rx, ry, _, _ = regions[name]
        atlas.alpha_composite(im, (rx, ry))
    return atlas, regions


def main():
    (SPR / "tiles").mkdir(parents=True, exist_ok=True)
    (SPR / "decals").mkdir(parents=True, exist_ok=True)
    grounds = {
        "ground_earth": ground_earth(),
        "ground_sand": ground_sand(),
        "ground_scrub": ground_scrub(),
        "ground_rubble": ground_rubble(),
        "ground_riverbed": ground_riverbed(),
        "ground_asphalt": ground_asphalt(),
    }
    for k, im in grounds.items():
        im.save(SPR / "tiles" / f"{k}.png")
    props = {
        "wreck_car": prop_car(),
        "wreck_truck": prop_truck(),
        "wreck_bus": prop_bus(),
        "fence_broken": prop_fence(),
        "pole_down": prop_pole(),
        "wall_collapsed": prop_wall(),
        "barrels_rust": prop_barrels(),
        "sandbags": prop_sandbags(),
        "crater": prop_crater(),
    }
    for k, im in props.items():
        im.save(SPR / "props" / f"{k}.png")
    (SPR / "fx").mkdir(parents=True, exist_ok=True)
    tumbleweed().save(SPR / "fx" / "tumbleweed.png")
    decals = {}
    for i in range(3):
        decals[f"bones_{i}"] = decal_bones(100 + i)
        decals[f"scrap_{i}"] = decal_scrap(110 + i)
        decals[f"grass_{i}"] = decal_grass(120 + i)
        decals[f"crack_{i}"] = decal_crack(130 + i)
        decals[f"pebbles_{i}"] = decal_pebbles(140 + i)
    for i in range(2):
        decals[f"oil_{i}"] = decal_oil(150 + i)
        decals[f"toxic_{i}"] = decal_toxic(160 + i)
        decals[f"tracks_{i}"] = decal_tracks(170 + i)
    atlas, regions = build_atlas(decals)
    atlas.save(SPR / "decals" / "decal_atlas.png")
    lines = [
        "extends RefCounted",
        "",
        "## Generated by tools/gen_map_detail.py — regions in decals/decal_atlas.png.",
        "",
        "const REGIONS := {",
    ]
    for name in sorted(regions):
        x, y, w, h = regions[name]
        lines.append(f'\t"{name}": Rect2({x}, {y}, {w}, {h}),')
    lines.append("}")
    (ROOT / "scripts" / "world" / "decal_atlas.gd").write_text("\n".join(lines) + "\n")
    if REVIEW:
        REVIEW.mkdir(parents=True, exist_ok=True)
        review(grounds, props, decals)
    print("ok", len(props), "props", len(decals), "decals")


def review(grounds, props, decals):
    # Ground swatches 2x2 tiled (seam + repetition check) at 1x, side by side.
    cell = 300
    sheet = Image.new("RGBA", (cell * 3, cell * 2), (0, 0, 0, 255))
    for k, (name, im) in enumerate(grounds.items()):
        t = Image.new("RGBA", (im.width * 2, im.height * 2))
        for x in (0, im.width):
            for y in (0, im.height):
                t.alpha_composite(im, (x, y))
        crop = t.crop((im.width - cell // 2, im.height - cell // 2, im.width + cell // 2, im.height + cell // 2))
        sheet.alpha_composite(crop, ((k % 3) * cell, (k // 3) * cell))
        ImageDraw.Draw(sheet).text(((k % 3) * cell + 4, (k // 3) * cell + 4), name, fill=(255, 240, 200, 255))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(REVIEW / "rev_ground.png")
    bg = grounds["ground_earth"]
    items = list(props.items())
    cols = 3
    cw, ch = 190, 90
    s = Image.new("RGBA", (cols * cw, ((len(items) + cols - 1) // cols) * ch), (0, 0, 0, 255))
    for k, (name, im) in enumerate(items):
        x, y = (k % cols) * cw, (k // cols) * ch
        s.alpha_composite(bg.crop((0, 0, cw, ch)), (x, y))
        s.alpha_composite(im, (x + 6, y + 14))
        ImageDraw.Draw(s).text((x + 3, y + 1), name, fill=(255, 240, 200, 255))
    s.resize((s.width * 3, s.height * 3), Image.NEAREST).save(REVIEW / "rev_props.png")
    items = list(decals.items())
    cols = 6
    cw, ch = 104, 40
    s = Image.new("RGBA", (cols * cw, ((len(items) + cols - 1) // cols) * ch), (0, 0, 0, 255))
    for k, (name, im) in enumerate(items):
        x, y = (k % cols) * cw, (k // cols) * ch
        s.alpha_composite(bg.crop((100, 100, 100 + cw, 100 + ch)), (x, y))
        s.alpha_composite(im, (x + 4, y + 12))
        ImageDraw.Draw(s).text((x + 2, y + 1), name, fill=(255, 240, 200, 255))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(REVIEW / "rev_decals.png")


if __name__ == "__main__":
    main()
