#!/usr/bin/env python3
"""Import Zach's painted dog sheet into the pet strips the game plays.

Source: tools/art_src/dogs_sheet_latest.png (1536x1024, grey panels). Three
dog bands top to bottom (Noel, Bentley, Lillie); each band is a head portrait
in the left column, then two rows of six side-on frames facing right:

  row A: stand, run 1..5            row B: stand, bark 1, bark 2, lunge, sit, lying

Pipeline (re-run after a new sheet: same layout, any cell sizes):
  1. grid: gutters are found from the median brightness of every row / column
     (dark panel seams), not hard-coded
  2. key: each panel's grey backdrop is modelled (quadratic fit), the dog is
     the strong colour difference that is not flood-connected to the panel
     border through backdrop-like pixels; edges get a soft alpha and the grey
     is un-mixed out of the fringe (no halo). The painted floor shadow is kept
     as a soft ink alpha under the dog
  3. normalise: one scale per dog (stand frame matched to the old strips'
     size), every frame anchored on a shared feet line (shadow line for
     airborne run frames) and centred on its body mass, so nothing jitters
  4. bake: 256 px frames (pet_defs hd = 2), feet at 256 - 20 like the old
     strips; states in the names pet.gd / UnitAnim play, fps in <id>_anim.json;
     strips over 4096 px are folded into grids and listed in strip_grids.json
  5. portraits: the painted head, keyed, square, 192 px
     (assets/sprites/portraits/pet_<id>.png)

    python3 tools/import_dog_sheet.py [--sheet PATH] [--preview DIR] [noel bentley lillie]

Supersedes the puppet bake (tools/pet_puppet.py) for the three dogs.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, ".."))
SHEET = os.path.join(HERE, "art_src", "dogs_sheet_latest.png")
PETS = os.path.join(GAME, "assets", "sprites", "pets")
PORTRAITS = os.path.join(GAME, "assets", "sprites", "portraits")
GRIDS = os.path.join(GAME, "assets", "sprites", "strip_grids.json")
DOGS = ["noel", "bentley", "lillie"]
FS = 256                 # frame px (pet_defs hd = 2)
FEET = FS - 20           # feet line in the frame (UnitAnim FEET_FROM_BOTTOM * hd)
TARGET_GM = 115.0        # stand bbox sqrt(w*h) of the old 256 px dog strips
MAX_TEX = 4096
PORTRAIT_PX = 192
INK = (20, 12, 14)       # style bible shadow ink
SHADOW_MAX = 0.42        # cap on the kept painted floor shadow

# Sheet cells per band: (row, col) with row 0 = A, 1 = B; col 0 = first frame.
A = lambda c: (0, c)
B = lambda c: (1, c)
STAND, RUN = A(0), [A(1), A(2), A(3), A(4), A(5)]
STAND_B, BARK1, BARK2, LUNGE, SIT, LIE = B(0), B(1), B(2), B(3), B(4), B(5)


# ------------------------------------------------------------------ grid
def _gutters(profile, thr, merge=16):
    idx = [i for i, v in enumerate(profile) if v < thr]
    out = []
    for i in idx:
        if out and i - out[-1][1] <= merge:
            out[-1][1] = i
        else:
            out.append([i, i])
    return out


def _spans(gutters, size, min_cell=60):
    edges = [[-1, -1]] + gutters + [[size, size]]
    spans = []
    for a, b in zip(edges, edges[1:]):
        lo, hi = a[1] + 1, b[0] - 1
        if hi - lo >= min_cell:
            spans.append((lo, hi + 1))
    return spans


def detect_grid(lum):
    """-> (portrait column span, frame column spans, band row spans [(A, B)])."""
    h, w = lum.shape
    base = float(np.median(lum))
    colp = np.median(lum, axis=0)
    cols = _spans(_gutters(colp, base * 0.8), w)
    if len(cols) != 7:
        raise SystemExit("grid: expected 7 columns, found %d %s" % (len(cols), cols))
    rowp = np.median(lum[:, cols[1][0]:], axis=1)
    rows = _spans(_gutters(rowp, base * 0.8), h)
    if len(rows) != 6:
        raise SystemExit("grid: expected 6 frame rows, found %d %s" % (len(rows), rows))
    bands = [(rows[i * 2], rows[i * 2 + 1]) for i in range(3)]
    return cols[0], cols[1:], bands


def trim_panel(rgb, bottom=True):
    """Drop the panel's seam / bevel lines: edge rows and columns whose two
    ends are off the backdrop (a seam runs the full length; a row through the
    dog still has backdrop at its ends). -> (y0, y1, x0, x1) in the cell."""
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    h, w = lum.shape
    ref = float(np.median(np.concatenate([lum[4:16, 4:16].ravel(), lum[4:16, w - 16:w - 4].ravel()])))
    nx, ny = max(4, w // 8), max(4, h // 8)
    y0, y1, x0, x1 = 0, h, 0, w

    def off_row(y):
        return np.median(np.abs(np.concatenate([lum[y, x0:x0 + nx], lum[y, x1 - nx:x1]]) - ref)) > 5

    def off_col(x):
        return np.median(np.abs(np.concatenate([lum[y0:y0 + ny, x], lum[y1 - ny:y1, x]]) - ref)) > 5

    for _ in range(12):
        if off_row(y0): y0 += 1
        if bottom and off_row(y1 - 1): y1 -= 1
        if off_col(x0): x0 += 1
        if off_col(x1 - 1): x1 -= 1
    # one more texel for the anti-aliased seam edge
    return y0 + 1, y1 - 1, x0 + 1, x1 - 1


# ------------------------------------------------------------------ key
def _bg_model(rgb, seed_mask):
    """Quadratic surface per channel fitted to backdrop pixels."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    xs, ys = xx / w - 0.5, yy / h - 0.5
    basis = np.stack([np.ones_like(xs), xs, ys, xs * xs, ys * ys, xs * ys], -1)
    m = seed_mask
    out = np.empty_like(rgb)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(basis[m], rgb[..., c][m], rcond=None)
        out[..., c] = basis @ coef
    return out


def key_cell(rgb, portrait=False, soft_shadows=True):
    """rgb float (h, w, 3) -> (fg rgb, dog alpha, shadow alpha).
    soft_shadows=False: a smooth dark area is never backdrop (black hair)."""
    t = trim_panel(rgb, bottom=not portrait)
    rgb = rgb[t[0]:t[1], t[2]:t[3]]
    h, w, _ = rgb.shape
    inset = 2
    ring = np.zeros((h, w), bool)
    ring[:inset + 10, :] = ring[-inset - 10:, :] = True
    ring[:, :inset + 10] = ring[:, -inset - 10:] = True
    ring[:inset, :] = ring[-inset:, :] = ring[:, :inset] = ring[:, -inset:] = False
    med = np.median(rgb[ring], axis=0)
    lum0 = rgb @ np.array([0.299, 0.587, 0.114])
    mu0 = ndi.uniform_filter(lum0, 5)
    tex0 = np.sqrt(np.maximum(ndi.uniform_filter(lum0 * lum0, 5) - mu0 * mu0, 0.0))
    edge = np.zeros((h, w), bool)
    edge[:inset, :] = edge[-inset:, :] = edge[:, :inset] = edge[:, -inset:] = True
    seed = (np.abs(rgb - med).max(-1) < 16) & (tex0 < 4.0) & ~edge
    bg = _bg_model(rgb, seed)
    # Local backdrop (normalised convolution of the backdrop pixels): follows
    # the painted glow / vignette that a global surface misses.
    for _ in range(3):
        d = np.abs(rgb - bg).max(-1)
        m = ((d < 10) & (tex0 < 4.0) & ~edge).astype(float)
        wsum = ndi.gaussian_filter(m, 14)
        loc = np.stack([ndi.gaussian_filter(rgb[..., c] * m, 14) for c in range(3)], -1)
        k = np.clip(wsum / 0.15, 0, 1)[..., None]
        bg = k * loc / np.maximum(wsum, 1e-6)[..., None] + (1 - k) * _bg_model(rgb, m > 0)

    lum = rgb @ np.array([0.299, 0.587, 0.114])
    blum = bg @ np.array([0.299, 0.587, 0.114])
    dl = lum - blum
    chroma = (rgb - lum[..., None]) - (bg - blum[..., None])
    dch = np.abs(chroma).max(-1)
    dist = np.sqrt(((rgb - bg) ** 2).sum(-1))
    # A shadow only darkens the grey: no hue shift, bounded depth.
    shadow_like = (dl < 0) & (dch < 7 + 0.12 * -dl) & (dl > -0.42 * blum)
    # Backdrop = flood through quiet pixels; the dog is the rest. Quiet = near
    # the backdrop colour, or a *smooth* hue-less darkening (floor shadow):
    # painted fur is textured even where it is grey / black (Noel's merle).
    mu = ndi.uniform_filter(lum, 3)
    tex = np.sqrt(np.maximum(ndi.uniform_filter(lum * lum, 3) - mu * mu, 0.0))
    soft_shadow = (dl < 0) & (dch < 8 + 0.15 * -dl) & (dl > -0.8 * blum) & (tex < 6.0)
    if not soft_shadows:
        soft_shadow = soft_shadow & (dl > -18)
    quiet = ((dist < 13) & (tex < 6.0)) | soft_shadow
    quiet &= ~((dl > 22) | (dch > 16))
    quiet = ndi.binary_opening(quiet, iterations=1)
    strict = (dist < 10) & (tex < 3.0)
    # Seeds: the panel border, plus sizeable patches of pure backdrop the dog
    # encloses with its legs and contact shadow (gaps between paws).
    lab_s, ns = ndi.label(strict)
    seeds = np.zeros((h, w), bool)
    if ns:
        sz = ndi.sum(strict, lab_s, range(1, ns + 1))
        seeds = np.isin(lab_s, [i + 1 for i, v in enumerate(sz) if v >= 40])
    if portrait:
        # The bust is cut by the bottom edge: seed only from the top / sides.
        border = np.zeros((h, w), bool)
        border[inset, :] = border[:, inset] = border[:, w - 1 - inset] = True
    else:
        border = np.zeros((h, w), bool)
        border[inset, :] = border[h - 1 - inset, :] = True
        border[:, inset] = border[:, w - 1 - inset] = True
    lab, _ = ndi.label(quiet | seeds)
    bg_ids = np.unique(lab[(border & quiet) | seeds])
    outside = np.isin(lab, bg_ids[bg_ids > 0])
    dog = ~outside
    dog[:inset, :] = dog[:, :inset] = dog[:, -inset:] = False
    if not portrait:
        dog[-inset:, :] = False
    if not portrait and dog.any():
        # Dark contact shadow fused under the paws: thin horizontal smears in
        # the lowest rows. A vertical opening keeps paws / legs, drops smears.
        ys = np.nonzero(dog.any(1))[0]
        low = np.zeros((h, w), bool)
        low[max(0, ys.max() - 14):, :] = True
        opened = ndi.binary_opening(dog, structure=np.ones((9, 1), bool))
        smear = dog & low & ~opened & (dl < 6) & (dch < 14)
        dog &= ~smear
    # Largest blob(s): drop specks / seam slivers, keep big detached bits.
    lab, n = ndi.label(dog)
    if n:
        sizes = ndi.sum(dog, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= max(60, sizes.max() * 0.05)]
        dog = np.isin(lab, keep)
    # Fill pinholes only (big enclosed gaps were decided by the seeds above).
    holes = ndi.binary_fill_holes(dog) & ~dog
    lab_h, nh = ndi.label(holes)
    if nh:
        sz = ndi.sum(holes, lab_h, range(1, nh + 1))
        dog |= np.isin(lab_h, [i + 1 for i, v in enumerate(sz) if v < 40])
    # Soft edge: solid core, and a 4 px band at the silhouette whose alpha is
    # the colour distance from the local backdrop (fur wisps fade out, the
    # blurry grey just outside the fur drops away).
    inner = ndi.binary_erosion(dog, iterations=4)
    ramp = np.clip((dist - 9.0) / 26.0, 0.0, 1.0)
    core2 = ndi.binary_erosion(dog, iterations=2)
    alpha = np.where(inner, 1.0, np.where(dog, ramp, 0.0))
    alpha = np.where(core2 & ~inner, np.maximum(alpha, 0.5), alpha)
    alpha = ndi.gaussian_filter(alpha, 0.6)
    alpha = np.where(dog, alpha, 0.0)
    alpha[alpha < 0.04] = 0.0
    # Un-mix the grey out of the fringe: F = (C - (1 - a) B) / a, then pull
    # fringe colour toward the fur 2 px inside so nothing reads grey.
    a3 = np.clip(alpha, 0.05, 1.0)[..., None]
    fg = np.clip((rgb - (1.0 - a3) * bg) / a3, 0, 255)
    if inner.any():
        _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
        inside = rgb[iy, ix]
        fringe = (alpha < 0.98)[..., None] & ~inner[..., None]
        fg = np.where(fringe, 0.5 * fg + 0.5 * inside, fg)
    # Floor shadow: darkening outside the dog, below its middle.
    shadow = np.zeros((h, w))
    if not portrait:
        ys = np.nonzero(dog.any(1))[0]
        if len(ys):
            mid = int(ys.mean())
            depth = np.clip((-dl - 3.0) / np.maximum(blum, 1.0), 0.0, 1.0)
            sh = np.where(~dog & shadow_like, depth * 1.9, 0.0)
            sh[:mid] = 0.0
            sh = ndi.gaussian_filter(sh, 2.0)
            shadow = np.clip(sh, 0.0, SHADOW_MAX)
            shadow[shadow < 0.03] = 0.0
            shadow[:inset + 2, :] = shadow[-inset - 2:, :] = 0.0
            shadow[:, :inset + 2] = shadow[:, -inset - 2:] = 0.0
    return fg, alpha, shadow


# ------------------------------------------------------------------ frames
class Cell:
    def __init__(self, fg, alpha, shadow):
        self.fg, self.alpha, self.shadow = fg, alpha, shadow
        m = alpha > 0.5
        ys, xs = np.nonzero(m)
        self.x0, self.x1, self.y0, self.y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        w = alpha * m
        self.cx = float((w.sum(0) * np.arange(alpha.shape[1])).sum() / w.sum())
        # Paw line: lowest rows of the body (ignore a stray tuft).
        rows = m.sum(1)
        self.paw = float(np.nonzero(rows > 2)[0].max() + 1)
        sw = shadow.sum()
        if sw > 40:
            self.shadow_y = float((shadow.sum(1) * np.arange(alpha.shape[0])).sum() / sw)
        else:
            self.shadow_y = None

    def gm(self):
        return float(np.sqrt((self.x1 - self.x0) * (self.y1 - self.y0)))


def compose(cell, scale, ground, sy=1.0, sx=1.0):
    """Frame (FS x FS RGBA uint8): `ground` (cell px) lands on FEET, body
    centre on the frame centre; sy / sx squash about the feet."""
    h, w = cell.alpha.shape
    rgba = np.dstack([cell.fg * cell.alpha[..., None], cell.alpha])  # premultiplied
    ink = np.array(INK, float)
    sh = np.dstack([ink * cell.shadow[..., None], cell.shadow])
    kx, ky = scale * sx, scale * sy
    # Output pixel (u, v) <- cell pixel ((u - FS/2) / kx + cx, (v - FEET) / ky + ground)
    v, u = np.mgrid[0:FS, 0:FS].astype(float)
    cxs = (u + 0.5 - FS / 2.0) / kx + cell.cx - 0.5
    cys = (v + 0.5 - FEET) / ky + ground - 0.5
    out = np.zeros((FS, FS, 4))
    # Area-average when shrinking: blur the source by the scale first.
    sig = max(0.0, 0.5 / min(kx, ky) - 0.5) * 0.85
    for src, dst_w in ((sh, None), (rgba, None)):
        layer = np.zeros((FS, FS, 4))
        for c in range(4):
            ch = ndi.gaussian_filter(src[..., c], sig) if sig > 0 else src[..., c]
            layer[..., c] = ndi.map_coordinates(ch, [cys, cxs], order=1, mode="constant", cval=0.0)
        # over (premultiplied)
        out = layer + out * (1.0 - layer[..., 3:4])
    a = np.clip(out[..., 3], 0, 1)
    col = np.where(a[..., None] > 1e-4, out[..., :3] / np.maximum(a[..., None], 1e-4), 0)
    res = np.dstack([np.clip(col, 0, 255), a * 255.0])
    res[a < 0.01] = 0
    return res.round().astype(np.uint8)


def ground_of(cell, paw_to_shadow):
    if cell.shadow_y is None:
        return cell.paw
    return max(cell.paw, cell.shadow_y + paw_to_shadow)


def breathe(cell, scale, ground, n, amp=0.014):
    out = []
    for i in range(n):
        s = np.sin(2 * np.pi * i / n)
        out.append(compose(cell, scale, ground, sy=1.0 + amp * s, sx=1.0 - amp * 0.3 * s))
    return out


def build_states(cells, dog):
    """cells[(row, col)] -> {state: [frames]}, fps."""
    st = cells[STAND]
    # One scale per sheet row: each row's stand frame is matched to the old
    # strips' stand (the painter drew row B a little larger than row A).
    rs = {0: TARGET_GM / st.gm(), 1: TARGET_GM / cells[STAND_B].gm()}
    sc = {k: rs[k[0]] for k in cells}
    scale = rs[0]
    p2s = {}
    for r, k in ((0, STAND), (1, STAND_B)):
        c = cells[k]
        p2s[r] = (c.paw - c.shadow_y) if c.shadow_y is not None else 0.0
    g = {k: ground_of(c, p2s[k[0]]) for k, c in cells.items()}
    # Grounded poses sit their lowest pixel on the line.
    for k in (STAND, STAND_B, SIT, LIE, BARK1, BARK2):
        g[k] = cells[k].paw
    f = lambda k, **kw: compose(cells[k], sc[k], g[k], **kw)
    states = {
        "idle": breathe(st, scale, g[STAND], 16),
        "walk": [f(k) for k in RUN],
        "windup": [f(STAND_B), f(BARK1)],
        "attack": [f(BARK1), f(LUNGE), f(BARK2)],
        "hit": [f(STAND_B, sy=0.94, sx=1.04), f(STAND_B)],
        "sit": [f(SIT, sy=0.95, sx=1.02), f(SIT, sy=1.02), f(SIT)],
        "sit_idle": breathe(cells[SIT], sc[SIT], g[SIT], 16, amp=0.01),
        "death": [f(SIT, sy=0.96), f(LIE, sy=1.06, sx=0.98), f(LIE)],
    }
    fps = {"idle": 8, "walk": 12, "windup": 10, "attack": 12, "hit": 12,
           "sit": 10, "sit_idle": 8, "death": 8}
    if dog == "noel":
        states["rampage"] = [f(k) for k in RUN]
        fps["rampage"] = 16
    elif dog == "bentley":
        states["bark"] = [f(BARK1), f(BARK2), f(BARK1), f(BARK2)]
        states["drop"] = [f(BARK1), f(SIT), f(SIT), f(SIT), f(STAND_B)]
        fps["bark"] = 10
        fps["drop"] = 8
    elif dog == "lillie":
        states["charge"] = [f(k) for k in RUN]
        states["impact"] = [f(LUNGE), f(BARK2), f(BARK1)]
        fps["charge"] = 16
        fps["impact"] = 12
    return states, fps, scale


def write_strip(path, frames, grids, key):
    n = len(frames)
    cols = min(n, MAX_TEX // FS)
    rows = (n + cols - 1) // cols
    img = Image.new("RGBA", (cols * FS, rows * FS), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        img.paste(Image.fromarray(fr, "RGBA"), ((i % cols) * FS, (i // cols) * FS))
    img.save(path, optimize=True)
    if rows > 1:
        grids[key] = {"n": n, "fs": FS, "cols": cols, "rows": rows}
    else:
        grids.pop(key, None)


# ------------------------------------------------------------------ portrait
def portrait(rgb):
    fg, alpha, _ = key_cell(rgb, portrait=True)
    h, w = alpha.shape
    m = alpha > 0.5
    ys, xs = np.nonzero(m)
    # Head = the top of the bust: square from the top of the ears.
    top = ys.min()
    side = int(min(w, h - top + 6, (xs.max() - xs.min()) * 1.0))
    cx = int((xs.min() + xs.max()) / 2)
    x0 = int(np.clip(cx - side // 2, 0, w - side))
    y0 = int(max(0, top - 6))
    side = min(side, h - y0)
    a = alpha.copy()
    # Fade the bust into the bottom edge instead of a hard cut.
    fade = np.clip((h - 1 - np.arange(h)) / 18.0, 0, 1)[:, None]
    a = a * fade
    rgba = np.dstack([fg, a * 255.0])[y0:y0 + side, x0:x0 + side]
    im = Image.fromarray(np.clip(rgba, 0, 255).round().astype(np.uint8), "RGBA")
    # Resize premultiplied to avoid dark fringes.
    pm = np.array(im).astype(float)
    pm[..., :3] *= pm[..., 3:4] / 255.0
    big = Image.fromarray(pm.round().astype(np.uint8), "RGBA").resize((PORTRAIT_PX, PORTRAIT_PX), Image.LANCZOS)
    out = np.array(big).astype(float)
    al = out[..., 3:4] / 255.0
    out[..., :3] = np.where(al > 0.004, out[..., :3] / np.maximum(al, 0.004), 0)
    return Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dogs", nargs="*", default=DOGS)
    ap.add_argument("--sheet", default=SHEET)
    ap.add_argument("--preview", default="", help="write keyed cells / contact sheets here")
    ap.add_argument("--dry", action="store_true", help="preview only, write nothing in assets/")
    args = ap.parse_args()
    rgb = np.array(Image.open(args.sheet).convert("RGB")).astype(float)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    pcol, fcols, bands = detect_grid(lum)
    print("grid: portrait x%s, frame cols %s" % (pcol, fcols))
    print("      bands %s" % bands)
    grids = json.load(open(GRIDS)).get("grids", {})
    for bi, dog in enumerate(DOGS):
        if dog not in args.dogs:
            continue
        cells = {}
        for r in range(2):
            y0, y1 = bands[bi][r]
            for c, (x0, x1) in enumerate(fcols):
                fg, al, sh = key_cell(rgb[y0:y1, x0:x1])
                if al[:6].max() > 0.5 or al[:, :6].max() > 0.5 or al[:, -6:].max() > 0.5:
                    print("  warn: %s cell %d,%d touches its panel edge" % (dog, r, c))
                cells[(r, c)] = Cell(fg, al, sh)
        states, fps, scale = build_states(cells, dog)
        print("%s: scale %.3f, %s" % (dog, scale, ", ".join("%s %d" % (k, len(v)) for k, v in states.items())))
        for k, frs in states.items():
            for i, fr in enumerate(frs):
                a = fr[..., 3]
                if a[:, :2].max() > 8 or a[:, -2:].max() > 8 or a[:2].max() > 8:
                    print("  warn: %s %s[%d] clipped by the %d px frame" % (dog, k, i, FS))
        py0, py1 = bands[bi][0][0], bands[bi][1][1]
        por = portrait(rgb[py0:py1, pcol[0]:pcol[1]])
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            for k, frs in states.items():
                strip = np.concatenate(frs, 1)
                bgc = np.zeros_like(strip)
                bgc[..., :3] = (70, 92, 64)
                bgc[..., 3] = 255
                im = Image.alpha_composite(Image.fromarray(bgc, "RGBA"), Image.fromarray(strip, "RGBA"))
                d = np.array(im)
                d[FEET, :, :3] = (255, 0, 0)
                d[:, ::FS][..., :3] = (0, 0, 0)
                Image.fromarray(d).save(os.path.join(args.preview, "%s_%s.png" % (dog, k)))
            por.save(os.path.join(args.preview, "pet_%s.png" % dog))
        if args.dry:
            continue
        out = os.path.join(PETS, dog)
        for k, frs in states.items():
            key = "assets/sprites/pets/%s/%s_%s.png" % (dog, dog, k)
            write_strip(os.path.join(GAME, key), frs, grids, key)
        with open(os.path.join(out, "%s_anim.json" % dog), "w") as fh:
            json.dump({"fps": fps}, fh, indent=1)
        por.save(os.path.join(PORTRAITS, "pet_%s.png" % dog), optimize=True)
    if not args.dry:
        with open(GRIDS, "w") as fh:
            json.dump({"max": MAX_TEX, "grids": dict(sorted(grids.items()))}, fh, indent=1)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
