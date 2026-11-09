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
The keying / framing / strip code lives in tools/import_anim_sheet.py.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

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

# Sheet cells per band: (row, col) with row 0 = A, 1 = B; col 0 = first frame.
A = lambda c: (0, c)
B = lambda c: (1, c)
STAND, RUN = A(0), [A(1), A(2), A(3), A(4), A(5)]
STAND_B, BARK1, BARK2, LUNGE, SIT, LIE = B(0), B(1), B(2), B(3), B(4), B(5)


# Keying, framing and strip baking are shared with every painted sheet:
# tools/import_anim_sheet.py (generic bands x rows x cells importer).
sys.path.insert(0, HERE)
from import_anim_sheet import (  # noqa: E402
    _gutters, _spans, key_cell, Cell, ground_of, write_strip,
    compose as _compose, breathe as _breathe)


def compose(cell, scale, ground, sy=1.0, sx=1.0):
    return _compose(cell, scale, ground, sy=sy, sx=sx, fs=FS, feet=FEET)


def breathe(cell, scale, ground, n, amp=0.014):
    return _breathe(cell, scale, ground, n, amp=amp, fs=FS, feet=FEET)


# ------------------------------------------------------------------ grid
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
