#!/usr/bin/env python3
"""Import a painted animation frame sheet into the per-state strips UnitAnim plays.

Generic version of tools/import_dog_sheet.py (which now uses this module).

Sheet layout: N bands stacked top to bottom, one unit per band. Each band is
`rows` rows (default 2) of `cols` cells (default 6), every cell one side-on
frame facing right on a painted grey backdrop. Cells are named by row letter
and column: A0..A5 is the first row, B0..B5 the second. Panel seams, floor
lines and gutters do not have to be uniform: they are found per sheet.

Pipeline
  1. layout: rows from the empty gaps between the painted figures (the
     strongest seam / floor line inside a gap is used as the cut), columns per
     row from the emptiest x near each expected cut (panel seams win)
  2. key: per cell the grey backdrop is modelled, the figure is what is not
     flood-connected to the border through backdrop-like pixels, edges get a
     soft alpha with the grey un-mixed out of the fringe (no halo); a faint
     painted floor shadow is kept (optional). Full-width floor lines painted
     through a row are inpainted first
  3. normalise: one scale per unit (target visible height, sqrt(w*h) footprint
     or a fixed scale, capped so the fit cells stay inside the frame); every
     frame is anchored on a shared feet line (lowest body px, painted shadow
     line for airborne frames, or body centre for flyers) and centred on its
     body mass, so nothing jitters. Frames that still overflow are nudged,
     then shrunk a little, then edge-faded
  4. bake: square `fs` px frames, feet `feet` px from the top; strips wider
     than 4096 px are folded into grids and listed in strip_grids.json;
     <id>_anim.json gets the fps, <id>_attack.json (optional) the hit frames
     and per-frame attack origins (front-most point of the silhouette)

Spec (JSON file, or a dict passed to import_sheet()):

  {"sheet": "tools/art_src/x.png",          # relative to game/ or absolute
   "bands": 3, "rows": 2, "cols": 6,         # layout (rows / cols optional)
   "units": [
     {"band": 0, "id": "raider_grunt",
      "out": "assets/sprites/enemies/raider_grunt",   # dir, relative to game/
      "fs": 128, "feet": 118,                # frame px, feet line y in frame
      "target": {"h": 107} | {"gm": 80} | {"scale": 0.6},
      "measure": "A0",                       # cell the target is measured on
      "fit": ["A0", "A1", ...],              # cells that must fit (default row A)
      "shadow": true, "flying": false,
      "recolor": {"hue": -0.02, "sat": 1.2, "val": 1.1, "glow": {...}},
      "states": {
        "idle": {"breathe": "A0", "n": 16, "amp": 0.014},
        "walk": ["A1", "A2", "A3", "A4", "A5"],
        "hit": [{"cell": "B4", "sy": 0.94, "sx": 1.04}, "B4"],
        "emerge": {"reveal": "A0", "n": 6},
        ...},
      "fps": {"idle": 8, "walk": 10},
      "attack": {"type": "melee", "hit_frames": "auto" | [1]}}   # optional
   ]}

A frame item is a cell name or {"cell", "sx", "sy", "anchor": "paw" |
"ground" | "cy", "feet": y, "dy": px, "reveal": 0..1}. Defaults: idle /
grounded poses anchor on the lowest body px ("paw"), row A walk frames on the
painted shadow line when there is one ("ground"), flyers on the body centre.

    python3 tools/import_anim_sheet.py SPEC.json [--preview DIR] [--dry] [--only id,id]
"""
import argparse
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, ".."))
GRIDS = os.path.join(GAME, "assets", "sprites", "strip_grids.json")
MAX_TEX = 4096
INK = (20, 12, 14)       # style bible shadow ink
SHADOW_MAX = 0.42        # cap on the kept painted floor shadow
LUMA = np.array([0.299, 0.587, 0.114])


# ------------------------------------------------------------------ grid (seams)
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


def _content(rgb, axis_median):
    """Per-pixel 'figure' mask: far from the backdrop colour of its own line
    (median along `axis_median`), so full-width lines and slow gradients drop
    out and only the painted figures remain."""
    med = np.median(rgb, axis=axis_median, keepdims=True)
    d = np.abs(rgb - med).max(-1)
    return d > 26


def _line_score(lum, axis):
    """Signed strength of straight lines across the sheet: per row (axis=1) or
    column (axis=0), median of the difference to the lines 3 px either side."""
    if axis == 1:
        up = np.roll(lum, 3, 0)
        dn = np.roll(lum, -3, 0)
        return np.median(lum - 0.5 * (up + dn), axis=1)
    lf = np.roll(lum, 3, 1)
    rt = np.roll(lum, -3, 1)
    return np.median(lum - 0.5 * (lf + rt), axis=0)


def _gaps(count, thr):
    """Runs where count <= thr -> [(lo, hi)] (hi exclusive)."""
    low = count <= thr
    out, i, n = [], 0, len(count)
    while i < n:
        if low[i]:
            j = i
            while j < n and low[j]:
                j += 1
            out.append((i, j))
            i = j
        else:
            i += 1
    return out


def _row_cut_candidates(score, cnt, w, h, line_thr, cnt_frac, edge=24):
    """Painted seams / floor lines that run across (almost) empty rows ->
    [(cut y, strength)]; a thick seam (two edge lines) or a floor line plus
    separator merge into one candidate cut at its last strong line."""
    ys = [y for y in range(edge, h - edge) if score[y] > line_thr and cnt[y] < cnt_frac * w]
    runs = []
    for y in ys:
        if runs and y - runs[-1][1] <= 20:
            runs[-1][1] = y
        else:
            runs.append([y, y])
    out = []
    for a, b in runs:
        s = score[a:b + 1]
        strong = np.nonzero(s > max(line_thr, s.max() * 0.5))[0]
        out.append((a + int(strong[-1]) + 1, float(s.max())))
    return out


def detect_rows(rgb, n_rows):
    """-> [(y0, y1)] * n_rows. Rows are cut at the painted seams / floor lines
    that cross the sheet through empty space (thresholds relax until enough
    are found); with spares, the set with the most even row heights wins.
    Without lines at all, the widest empty gaps are used."""
    import itertools
    h, w = rgb.shape[:2]
    need = n_rows - 1
    if need == 0:
        return [(0, h)]
    lum = rgb @ LUMA
    cnt = ndi.minimum_filter1d(_content(rgb, 1).sum(1), 5)
    score = np.abs(_line_score(lum, 1))
    score[:4] = score[-4:] = 0
    cands = []
    for lt, cf in ((6.0, 0.03), (6.0, 0.08), (4.0, 0.15), (3.0, 0.25)):
        cands = _row_cut_candidates(score, cnt, w, h, lt, cf)
        if len(cands) >= need:
            break
    if len(cands) < need:
        # No painted lines: widest empty gaps, cut in the middle.
        sm = ndi.uniform_filter1d(cnt.astype(float), 5)
        gaps = [g for g in _gaps(sm, max(2.0, 0.004 * w)) if g[0] > 8 and g[1] < h - 8]
        gaps.sort(key=lambda g: -(g[1] - g[0]))
        cands = [((lo + hi) // 2, 1.0) for lo, hi in gaps[:need]]
        if len(cands) < need:
            raise SystemExit("layout: found %d row cuts, need %d" % (len(cands), need))
    cuts = sorted(c for c, _ in cands)
    if len(cuts) > need:
        best, best_v = None, -1.0
        combos = itertools.combinations(cuts, need) if len(cuts) - need <= 4 else [
            sorted(c for c, _ in sorted(cands, key=lambda t: -t[1])[:need])]
        for combo in combos:
            e = [0] + list(combo) + [h]
            v = min(b - a for a, b in zip(e, e[1:]))
            if v > best_v:
                best, best_v = list(combo), v
        cuts = best
    edges = [0] + cuts + [h]
    return [(edges[i], edges[i + 1]) for i in range(n_rows)]


def detect_cols(rgb, n_cols):
    """-> [(x0, x1)] * n_cols for one row strip: each cut at the emptiest x
    near its expected place (a panel seam there wins)."""
    w = rgb.shape[1]
    lum = rgb @ LUMA
    raw = _content(rgb, 0).sum(0).astype(float)
    cnt = ndi.uniform_filter1d(raw, 9)
    score = np.abs(_line_score(lum, 0))
    # A seam runs through empty space; a staff / gun barrel does not.
    score[ndi.minimum_filter1d(raw, 3) > 0.04 * rgb.shape[0]] = 0.0
    cuts = []
    prev = 0
    for k in range(1, n_cols):
        exp = prev + (w - prev) / float(n_cols - k + 1)
        cw = w / float(n_cols)
        lo = int(max(prev + cw * 0.45, exp - cw * 0.4))
        hi = int(min(w - cw * 0.45 * (n_cols - k), exp + cw * 0.4))
        seg = cnt[lo:hi]
        sc = score[lo:hi]
        if sc.size and sc.max() > 6.0:
            c = lo + int(np.argmax(sc))
        else:
            # emptiest, tie-break toward the expected place
            pen = seg + 0.002 * np.abs(np.arange(lo, hi) - exp) * (seg.max() + 1)
            c = lo + int(np.argmin(pen))
        cuts.append(c)
        prev = c
    edges = [0] + cuts + [w]
    return [(edges[i], edges[i + 1]) for i in range(n_cols)]


def remove_hlines(rgb):
    """Inpaint full-width painted lines (floor lines, row separators) inside a
    row strip: only the pixels that behave like the line are replaced, so a
    figure crossing it is untouched."""
    lum = rgb @ LUMA
    h = rgb.shape[0]
    sc = _line_score(lum, 1)
    sc[:3] = sc[-3:] = 0
    rows = np.nonzero(np.abs(sc) > 2.0)[0]
    if not len(rows):
        return rgb
    out = rgb.copy()
    runs = []
    for y in rows:
        if runs and y - runs[-1][1] <= 2:
            runs[-1][1] = y
        else:
            runs.append([y, y])
    for a, b in runs:
        a0, b1 = max(0, a - 2), min(h - 1, b + 2)
        top, bot = rgb[a0], rgb[b1]
        ref = 0.5 * (top + bot)
        for y in range(a0 + 1, b1):
            t = (y - a0) / float(b1 - a0)
            fill = (1 - t) * top + t * bot
            d = lum[y] - (ref @ LUMA)
            like = np.abs(d - np.median(d)) < 10
            out[y][like] = fill[like]
    return out


def detect_layout(rgb, bands, rows=2, cols=6):
    """-> {"rows": [(y0, y1)], "cols": [[(x0, x1)] per row]} for the sheet."""
    rs = detect_rows(rgb, bands * rows)
    cs = [detect_cols(rgb[y0:y1], cols) for y0, y1 in rs]
    return {"rows": rs, "cols": cs, "per_band": rows}


def trim_panel(rgb, bottom=True):
    """Drop the panel's seam / bevel lines: edge rows and columns whose two
    ends are off the backdrop (a seam runs the full length; a row through the
    figure still has backdrop at its ends). -> (y0, y1, x0, x1) in the cell."""
    lum = rgb @ LUMA
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


def key_cell(rgb, portrait=False, keep_shadow=True, soft_shadows=True):
    """rgb float (h, w, 3) -> (fg rgb, figure alpha, shadow alpha).
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
    lum0 = rgb @ LUMA
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

    lum = rgb @ LUMA
    blum = bg @ LUMA
    dl = lum - blum
    chroma = (rgb - lum[..., None]) - (bg - blum[..., None])
    dch = np.abs(chroma).max(-1)
    dist = np.sqrt(((rgb - bg) ** 2).sum(-1))
    # A shadow only darkens the grey: no hue shift, bounded depth.
    shadow_like = (dl < 0) & (dch < 7 + 0.12 * -dl) & (dl > -0.42 * blum)
    # Backdrop = flood through quiet pixels; the figure is the rest. Quiet =
    # near the backdrop colour, or a *smooth* hue-less darkening (floor
    # shadow): painted fur / cloth is textured even where it is grey / black.
    mu = ndi.uniform_filter(lum, 3)
    tex = np.sqrt(np.maximum(ndi.uniform_filter(lum * lum, 3) - mu * mu, 0.0))
    soft_shadow = (dl < 0) & (dch < 8 + 0.15 * -dl) & (dl > -0.8 * blum) & (tex < 6.0)
    if not soft_shadows:
        soft_shadow = soft_shadow & (dl > -18)
    quiet = ((dist < 13) & (tex < 6.0)) | soft_shadow
    quiet &= ~((dl > 22) | (dch > 16))
    quiet = ndi.binary_opening(quiet, iterations=1)
    strict = (dist < 10) & (tex < 3.0)
    # Seeds: the panel border, plus sizeable patches of pure backdrop the
    # figure encloses with its legs and contact shadow (gaps between feet).
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
    fig = ~outside
    fig[:inset, :] = fig[:, :inset] = fig[:, -inset:] = False
    if not portrait:
        fig[-inset:, :] = False
    if not portrait and fig.any():
        # Dark contact shadow fused under the feet: thin horizontal smears in
        # the lowest rows. A vertical opening keeps feet / legs, drops smears.
        ys = np.nonzero(fig.any(1))[0]
        low = np.zeros((h, w), bool)
        low[max(0, ys.max() - 14):, :] = True
        opened = ndi.binary_opening(fig, structure=np.ones((9, 1), bool))
        smear = fig & low & ~opened & (dl < 6) & (dch < 14)
        fig &= ~smear
    # Largest blob(s): drop specks / seam slivers, keep big detached bits.
    lab, n = ndi.label(fig)
    if n:
        sizes = ndi.sum(fig, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= max(60, sizes.max() * 0.05)]
        fig = np.isin(lab, keep)
    # Fill pinholes only (big enclosed gaps were decided by the seeds above).
    holes = ndi.binary_fill_holes(fig) & ~fig
    lab_h, nh = ndi.label(holes)
    if nh:
        sz = ndi.sum(holes, lab_h, range(1, nh + 1))
        fig |= np.isin(lab_h, [i + 1 for i, v in enumerate(sz) if v < 40])
    # Soft edge: solid core, and a 4 px band at the silhouette whose alpha is
    # the colour distance from the local backdrop (wisps fade out, the blurry
    # grey just outside drops away).
    inner = ndi.binary_erosion(fig, iterations=4)
    ramp = np.clip((dist - 9.0) / 26.0, 0.0, 1.0)
    core2 = ndi.binary_erosion(fig, iterations=2)
    alpha = np.where(inner, 1.0, np.where(fig, ramp, 0.0))
    alpha = np.where(core2 & ~inner, np.maximum(alpha, 0.5), alpha)
    alpha = ndi.gaussian_filter(alpha, 0.6)
    alpha = np.where(fig, alpha, 0.0)
    alpha[alpha < 0.04] = 0.0
    # Un-mix the grey out of the fringe: F = (C - (1 - a) B) / a, then pull
    # fringe colour toward the figure 2 px inside so nothing reads grey.
    a3 = np.clip(alpha, 0.05, 1.0)[..., None]
    fg = np.clip((rgb - (1.0 - a3) * bg) / a3, 0, 255)
    if inner.any():
        _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
        inside = rgb[iy, ix]
        fringe = (alpha < 0.98)[..., None] & ~inner[..., None]
        fg = np.where(fringe, 0.5 * fg + 0.5 * inside, fg)
    # Floor shadow: darkening outside the figure, below its middle.
    shadow = np.zeros((h, w))
    if not portrait and keep_shadow:
        ys = np.nonzero(fig.any(1))[0]
        if len(ys):
            mid = int(ys.mean())
            depth = np.clip((-dl - 3.0) / np.maximum(blum, 1.0), 0.0, 1.0)
            sh = np.where(~fig & shadow_like, depth * 1.9, 0.0)
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
        if not m.any():
            m = alpha > 0.05
        ys, xs = np.nonzero(m)
        self.x0, self.x1, self.y0, self.y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        w = alpha * m
        self.cx = float((w.sum(0) * np.arange(alpha.shape[1])).sum() / w.sum())
        self.cy = float((w.sum(1) * np.arange(alpha.shape[0])).sum() / w.sum())
        # Feet line: lowest rows of the body (ignore a stray tuft).
        rows = m.sum(1)
        self.paw = float(np.nonzero(rows > 2)[0].max() + 1)
        sw = shadow.sum()
        if sw > 40:
            self.shadow_y = float((shadow.sum(1) * np.arange(alpha.shape[0])).sum() / sw)
        else:
            self.shadow_y = None

    def gm(self):
        return float(np.sqrt((self.x1 - self.x0) * (self.y1 - self.y0)))

    def height(self):
        return float(self.y1 - self.y0)


def compose(cell, scale, ground, sy=1.0, sx=1.0, fs=256, feet=None, shift=0.0):
    """Frame (fs x fs RGBA uint8): `ground` (cell px) lands on `feet` (frame
    px, default fs - 20), body centre on the frame centre + `shift`; sy / sx
    squash about the feet."""
    if feet is None:
        feet = fs - 20
    rgba = np.dstack([cell.fg * cell.alpha[..., None], cell.alpha])  # premultiplied
    ink = np.array(INK, float)
    sh = np.dstack([ink * cell.shadow[..., None], cell.shadow])
    kx, ky = scale * sx, scale * sy
    # Output pixel (u, v) <- cell pixel ((u - fs/2 - shift) / kx + cx, (v - feet) / ky + ground)
    v, u = np.mgrid[0:fs, 0:fs].astype(float)
    cxs = (u + 0.5 - fs / 2.0 - shift) / kx + cell.cx - 0.5
    cys = (v + 0.5 - feet) / ky + ground - 0.5
    out = np.zeros((fs, fs, 4))
    # Area-average when shrinking: blur the source by the scale first.
    sig = max(0.0, 0.5 / min(kx, ky) - 0.5) * 0.85
    for src in (sh, rgba):
        if not src[..., 3].any():
            continue
        layer = np.zeros((fs, fs, 4))
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


def breathe(cell, scale, ground, n, amp=0.014, **kw):
    out = []
    for i in range(n):
        s = np.sin(2 * np.pi * i / n)
        out.append(compose(cell, scale, ground, sy=1.0 + amp * s, sx=1.0 - amp * 0.3 * s, **kw))
    return out


def write_strip(path, frames, grids, key):
    fs = frames[0].shape[0]
    n = len(frames)
    cols = min(n, MAX_TEX // fs)
    rows = (n + cols - 1) // cols
    img = Image.new("RGBA", (cols * fs, rows * fs), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        img.paste(Image.fromarray(fr, "RGBA"), ((i % cols) * fs, (i // cols) * fs))
    img.save(path, optimize=True)
    if rows > 1:
        grids[key] = {"n": n, "fs": fs, "cols": cols, "rows": rows}
    else:
        grids.pop(key, None)


def load_grids():
    return json.load(open(GRIDS)).get("grids", {})


def save_grids(grids):
    with open(GRIDS, "w") as fh:
        json.dump({"max": MAX_TEX, "grids": dict(sorted(grids.items()))}, fh, indent=1)
        fh.write("\n")


def preview_strip(path, frames, feet):
    fs = frames[0].shape[0]
    strip = np.concatenate(frames, 1)
    bgc = np.zeros_like(strip)
    bgc[..., :3] = (70, 92, 64)
    bgc[..., 3] = 255
    im = Image.alpha_composite(Image.fromarray(bgc, "RGBA"), Image.fromarray(strip, "RGBA"))
    d = np.array(im)
    d[feet, :, :3] = (255, 0, 0)
    d[:, ::fs][..., :3] = (0, 0, 0)
    Image.fromarray(d).save(path)


# ------------------------------------------------------------------ recolor
def recolor_cell(cell, rc):
    """Palette variant of a keyed cell: hue shift / saturation / value, with
    an optional stronger push on glowing (saturated + bright) pixels."""
    fg = cell.fg / 255.0
    flat = fg.reshape(-1, 3)
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in flat])
    h, s, v = hsv[:, 0], hsv[:, 1], hsv[:, 2]
    glow = rc.get("glow")
    if glow:
        g = np.clip((s - glow.get("s_min", 0.45)) / 0.2, 0, 1) * np.clip((v - glow.get("v_min", 0.45)) / 0.2, 0, 1)
    else:
        g = np.zeros_like(h)
    gh, gs, gv = (glow or {}).get("hue", 0.0), (glow or {}).get("sat", 1.0), (glow or {}).get("val", 1.0)
    h = (h + rc.get("hue", 0.0) + g * gh) % 1.0
    s = np.clip(s * rc.get("sat", 1.0) * (1 + g * (gs - 1)), 0, 1)
    v = np.clip(v * rc.get("val", 1.0) * (1 + g * (gv - 1)), 0, 1)
    rgb = np.array([colorsys.hsv_to_rgb(*p) for p in np.stack([h, s, v], -1)])
    out = Cell.__new__(Cell)
    out.__dict__.update(cell.__dict__)
    out.fg = (rgb.reshape(fg.shape) * 255.0)
    return out


# ------------------------------------------------------------------ units
def cell_key(name):
    """'A0' -> (0, 0), 'B5' -> (1, 5)."""
    return (ord(name[0].upper()) - ord("A"), int(name[1:]))


def slice_band(rgb, layout, band, shadow=True):
    """-> {(row, col): Cell} for one band."""
    per = layout["per_band"]
    cells = {}
    for r in range(per):
        ri = band * per + r
        y0, y1 = layout["rows"][ri]
        strip = remove_hlines(rgb[y0:y1])
        for c, (x0, x1) in enumerate(layout["cols"][ri]):
            fg, al, sh = key_cell(strip[:, x0:x1], keep_shadow=shadow)
            if not (al > 0.05).any():
                raise SystemExit("band %d cell %s%d is empty" % (band, chr(65 + r), c))
            cells[(r, c)] = Cell(fg, al, sh)
    return cells


def _item(it):
    return {"cell": it} if isinstance(it, str) else dict(it)


def build_unit(cells, u, log=print):
    """cells {(r, c): Cell} + unit spec -> ({state: [frames]}, fps, info)."""
    fs = int(u["fs"])
    feet = float(u.get("feet", fs - 10))
    flying = bool(u.get("flying", False))
    ref = cells[cell_key(u.get("measure", "A0"))]
    tgt = u.get("target", {})
    if "scale" in tgt:
        scale = float(tgt["scale"])
    elif "h" in tgt:
        scale = float(tgt["h"]) / ref.height()
    elif "gm" in tgt:
        scale = float(tgt["gm"]) / ref.gm()
    else:
        scale = (fs * 0.8) / ref.height()
    margin = 3.0
    # Ground lines: row A walk frames may be airborne -> painted shadow line.
    p2s = (ref.paw - ref.shadow_y) if ref.shadow_y is not None else 0.0

    def ground(cell, anchor):
        if anchor == "ground":
            return ground_of(cell, p2s)
        if anchor == "cy":
            return cell.cy + (ref.paw - ref.cy)
        return cell.paw

    def default_anchor(key):
        if flying:
            return "cy"
        return "ground" if key[0] == 0 and key != cell_key(u.get("measure", "A0")) else "paw"

    # Cap the scale so the fit cells stay inside the frame.
    fit = [cell_key(k) for k in u.get("fit", ["A%d" % i for i in range(6)])]
    cap = 9.0
    for k in fit:
        c = cells[k]
        half = max(c.cx - c.x0, c.x1 - c.cx)
        cap = min(cap, (fs / 2.0 - margin) / half)
        g = ground(c, default_anchor(k))
        cap = min(cap, (feet - margin) / max(1.0, g - c.y0))
    if scale > cap:
        log("  %s: scale %.3f capped to %.3f to fit %d px" % (u["id"], scale, cap, fs))
        scale = cap

    clip_notes = []

    def frame(it, st):
        it = _item(it)
        k = cell_key(it["cell"])
        c = cells[k]
        anchor = it.get("anchor", default_anchor(k))
        if flying and k == cell_key(u.get("death_cell", "B5")):
            anchor = it.get("anchor", "paw")
        f_feet = float(it.get("feet", u.get("ground_feet", feet) if (flying and anchor == "paw") else feet))
        f_feet -= float(it.get("dy", 0.0))
        g = ground(c, anchor)
        sx, sy = float(it.get("sx", 1.0)), float(it.get("sy", 1.0))
        k_s = 1.0
        # Fit: nudge sideways, then shrink (<= 15 %), then fade the edges.
        def ext(ks):
            kx, ky = scale * sx * ks, scale * sy * ks
            return ((c.cx - c.x0) * kx, (c.x1 - c.cx) * kx, (g - c.y0) * ky)
        l, r, t = ext(1.0)
        half = fs / 2.0 - margin
        shift = 0.0
        if l + r <= 2 * half:
            if r > half:
                shift = -(r - half)
            elif l > half:
                shift = l - half
        else:
            k_s = max(0.85, (2 * half) / (l + r))
            l, r, t = ext(k_s)
            shift = (l - r) / 2.0
        if t > f_feet - margin:
            k_s = min(k_s, max(0.85, (f_feet - margin) / (t / k_s)))
        if abs(shift) > 0.5 or k_s < 1.0:
            clip_notes.append("%s %s shift %+.0f scale x%.2f" % (st, it["cell"], shift, k_s))
        out = compose(c, scale * k_s, g, sy=sy, sx=sx, fs=fs, feet=f_feet, shift=shift)
        rv = it.get("reveal")
        if rv is not None:
            out = reveal(out, float(rv), f_feet)
        return edge_fade(out)

    states = {}
    for st, spec in u["states"].items():
        if isinstance(spec, dict) and "breathe" in spec:
            k = cell_key(spec["breathe"])
            c = cells[k]
            anchor = spec.get("anchor", "cy" if flying else "paw")
            states[st] = [edge_fade(f) for f in breathe(c, scale, ground(c, anchor), int(spec.get("n", 16)),
                                                        amp=float(spec.get("amp", 0.014)), fs=fs, feet=feet)]
        elif isinstance(spec, dict) and "reveal" in spec:
            n = int(spec.get("n", 6))
            states[st] = [frame({"cell": spec["reveal"], "reveal": (i + 1) / float(n)}, st) for i in range(n)]
        else:
            states[st] = [frame(it, st) for it in spec]
    for note in clip_notes:
        log("  %s: %s" % (u["id"], note))
    fps = dict(u.get("fps", {}))
    return states, fps, {"scale": scale}


def reveal(fr, t, feet):
    """Rise out of the ground: the frame sunk by (1 - t) of its height and cut
    at the feet line (emerge)."""
    a = fr[..., 3]
    ys = np.nonzero(a.max(1) > 8)[0]
    if not len(ys):
        return fr
    hgt = feet - ys.min()
    d = int(round((1.0 - t) * hgt))
    out = np.zeros_like(fr)
    if d < fr.shape[0]:
        out[d:] = fr[:fr.shape[0] - d]
    cut = int(feet) + 2
    out[cut:] = 0
    return out


def edge_fade(fr, px=3):
    """Soft 3 px fade at the frame border so a clipped effect never shows a
    hard cut line."""
    fs = fr.shape[0]
    r = np.minimum(np.arange(fs), np.arange(fs)[::-1]).astype(float)
    k = np.clip(r / px, 0, 1)
    m = np.minimum(k[:, None], k[None, :])
    out = fr.copy()
    out[..., 3] = (fr[..., 3] * m).round().astype(np.uint8)
    return out


def attack_meta(frames, fs, feet, spec, old_hits=None):
    """Per attack frame origin = front-most point of the silhouette (mouth,
    claw, blade, muzzle); hit frame(s) = widest reach unless given."""
    origin, reach = [], []
    for fr in frames:
        a = fr[..., 3] > 128
        xs = np.nonzero(a.any(0))[0]
        if not len(xs):
            origin.append([fs / 2.0, feet - fs * 0.3])
            reach.append(0)
            continue
        x1 = xs.max()
        band = a[:, max(0, x1 - 5):x1 + 1]
        ys = np.nonzero(band.any(1))[0]
        origin.append([round(float(x1 - 2), 1), round(float(np.median(ys)), 1)])
        reach.append(int(x1))
    hf = spec.get("hit_frames", "auto")
    if hf == "auto":
        n_hits = len(old_hits) if old_hits else 1
        best = int(np.argmax(reach))
        if n_hits <= 1:
            hf = [best]
        else:
            hf = sorted({best, max(0, best - 2) if best >= 2 else min(len(frames) - 1, best + 2)})
    return {"hit_frames": hf, "origin": origin, "type": spec.get("type", "melee")}


# ------------------------------------------------------------------ driver
def _abs(p):
    return p if os.path.isabs(p) else os.path.join(GAME, p)


def import_sheet(spec, preview="", dry=False, only=None, grids=None, log=print):
    """Run one sheet spec. Returns {unit id: info}. `grids` (strip_grids
    entries) is updated in place; saved by the caller (or main)."""
    rgb = np.array(Image.open(_abs(spec["sheet"])).convert("RGB")).astype(float)
    layout = detect_layout(rgb, int(spec["bands"]), int(spec.get("rows", 2)), int(spec.get("cols", 6)))
    log("%s: rows %s" % (os.path.basename(spec["sheet"]), layout["rows"]))
    own_grids = grids is None
    if own_grids:
        grids = load_grids()
    info = {}
    cache = {}
    for u in spec["units"]:
        if only and u["id"] not in only:
            continue
        b = int(u["band"])
        key = (b, bool(u.get("shadow", True)))
        if key not in cache:
            cache[key] = slice_band(rgb, layout, b, shadow=key[1])
        cells = cache[key]
        if u.get("recolor"):
            cells = {k: recolor_cell(c, u["recolor"]) for k, c in cells.items()}
        states, fps, inf = build_unit(cells, u, log)
        fs = int(u["fs"])
        feet = int(round(float(u.get("feet", fs - 10))))
        log("%s: scale %.3f, %s" % (u["id"], inf["scale"], ", ".join("%s %d" % (k, len(v)) for k, v in states.items())))
        out_dir = _abs(u["out"])
        uid = u["id"]
        atk = None
        if u.get("attack") is not None and "attack" in states:
            atk = attack_meta(states["attack"], fs, feet, u["attack"], u["attack"].get("old_hits"))
            inf["attack"] = atk
        info[uid] = inf
        if preview:
            os.makedirs(preview, exist_ok=True)
            for k, frs in states.items():
                preview_strip(os.path.join(preview, "%s_%s.png" % (uid, k)), frs, feet)
        if dry:
            continue
        os.makedirs(out_dir, exist_ok=True)
        rel = os.path.relpath(out_dir, GAME)
        for k, frs in states.items():
            gkey = "%s/%s_%s.png" % (rel, uid, k)
            write_strip(os.path.join(GAME, gkey), frs, grids, gkey)
        side = os.path.join(out_dir, "%s_anim.json" % uid)
        old = {}
        if os.path.exists(side):
            try:
                old = json.load(open(side))
            except ValueError:
                old = {}
        old["fps"] = fps
        with open(side, "w") as fh:
            json.dump(old, fh, indent=1)
            fh.write("\n")
        if atk is not None:
            with open(os.path.join(out_dir, "%s_attack.json" % uid), "w") as fh:
                json.dump(atk, fh, indent=1)
                fh.write("\n")
    if own_grids and not dry:
        save_grids(grids)
    return info


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("spec", help="JSON spec file (see module doc)")
    ap.add_argument("--preview", default="", help="write keyed contact strips here")
    ap.add_argument("--dry", action="store_true", help="preview only, write nothing in assets/")
    ap.add_argument("--only", default="", help="comma list of unit ids")
    args = ap.parse_args()
    spec = json.load(open(args.spec))
    only = set(filter(None, args.only.split(","))) or None
    specs = spec if isinstance(spec, list) else [spec]
    grids = load_grids()
    for s in specs:
        import_sheet(s, args.preview, args.dry, only, grids)
    if not args.dry:
        save_grids(grids)
    return 0


if __name__ == "__main__":
    sys.exit(main())
