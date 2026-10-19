"""celkit: the hangar's anime cel-shading (tools/gen_hangar_art.py) on small item
canvases — icons, pickups, props. Same tone ramps, ink weight, hard specular and
warm rim; the key light comes from the top-left instead of the hangar door.

usage:
    from celkit import Canvas, cel, ink, fill, ...
    cv = Canvas(24, 24)            # art units (S px each)
    cel(cv.L, [("ell", 12, 12, 6, 6)], C(200, 60, 50), form="sphere", key=KEY)
    cv.save("out.png", 96)         # LANCZOS down to 96 px
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_hangar_art as g  # noqa: E402
from gen_hangar_art import (C, INK3, SPEC, RIMC, cel as _cel, ink, hline, fill, soft, glow2, tone_set,  # noqa: E402,F401
                            shape, F, fbm, vnoise, smooth)

KEY = (-0.55, -0.72, 0.42)


class Canvas:
    """A cel canvas of w x h art units at S px per unit."""

    def __init__(self, w, h, S=8):
        self.w, self.h, self.S = w, h, S
        g.S = S
        g.W, g.H = int(w * S), int(h * S)
        self.L = g.Layer()

    def image(self):
        return self.L.image()

    def save(self, path, px=None, py=None, sharpen=True):
        im = self.image()
        if px:
            py = py or int(round(px * self.h / self.w))
            im = im.resize((px, py), Image.LANCZOS)
            if sharpen:
                im = im.filter(ImageFilter.UnsharpMask(radius=0.8, percent=40, threshold=2))
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        im.save(path)
        return im


def cel(L, prims, base, **kw):
    kw.setdefault("key", KEY)
    return _cel(L, prims, base, **kw)


def shadow(L, cx, cy, rx, ry, a=0.5):
    soft(L, [("ell", cx, cy, rx, ry)], C(14, 12, 24), a * 0.75, blur=ry * g.S * 0.6 + 2)
    soft(L, [("ell", cx, cy - ry * 0.1, rx * 0.8, ry * 0.45)], C(10, 8, 18), a * 0.5, blur=2.0)


def glow(L, cx, cy, r, col, strength=0.5):
    glow2(L, cx, cy, r, col, strength)


def box(L, x0, y0, x1, y1, d, base, top=None, side=None, ol=2.4, **kw):
    """A box seen slightly from above-right: front + top + right side."""
    dx, dy = d * 0.55, d * 0.42
    topf = [("poly", [(x0, y0), (x1, y0), (x1 + dx, y0 - dy), (x0 + dx, y0 - dy)])]
    sidef = [("poly", [(x1, y0), (x1 + dx, y0 - dy), (x1 + dx, y1 - dy), (x1, y1)])]
    front = [("rect", x0, y0, x1, y1)]
    un = shape(front + topf + sidef, pad=10)
    inside = un.a > 0.5
    dout = ndi.distance_transform_edt(~inside)
    T = tone_set(base)
    L.blend(np.maximum(np.clip(ol + 0.5 - dout, 0, 1), un.a), un.x0, un.y0, T["line"])
    kw2 = dict(kw)
    kw2.setdefault("bevel", 1.0)
    cel(L, topf, top if top is not None else base, n=(0, -0.92, 0.38), ol=0.8, **kw2)
    cel(L, sidef, side if side is not None else base, n=(0.95, 0, 0.3), ol=0.8, **kw2)
    cel(L, front, base, n=(0, -0.05, 1), ol=0.8, **kw2)
    return dx, dy


def bottle(L, cx, cy, liquid, glass=C(186, 210, 214), shape_="round", r=6.0, cork=C(150, 104, 62),
           label=None, fill_k=0.62, glow_col=None):
    """Glass tonic bottle: body (round / flask / square), neck, cork, liquid, label, gloss."""
    if glow_col is not None:
        glow(L, cx, cy + r * 0.3, r * 1.9, glow_col, 0.45)
    shadow(L, cx + 0.5, cy + r + 0.6, r * 0.95, r * 0.28, 0.55)
    if shape_ == "round":
        body = [("ell", cx, cy, r, r)]
        top_y = cy - r
    elif shape_ == "flask":
        body = [("poly", [(cx - r * 0.32, cy - r * 1.05), (cx + r * 0.32, cy - r * 1.05), (cx + r * 0.36, cy - r * 0.35),
                          (cx + r * 1.05, cy + r * 0.78), (cx + r * 0.9, cy + r), (cx - r * 0.9, cy + r),
                          (cx - r * 1.05, cy + r * 0.78), (cx - r * 0.36, cy - r * 0.35)])]
        top_y = cy - r * 1.05
    else:
        body = [("rect", cx - r * 0.82, cy - r * 0.95, cx + r * 0.82, cy + r)]
        top_y = cy - r * 0.95
    # glass body (dark inside), then the liquid level, then gloss
    cel(L, body, glass * 0.55, form="sphere" if shape_ == "round" else "cylv", ol=2.4, bevel=1.4, rim=0.6,
        line=C(30, 34, 40))
    lt = cy + r - (2 * r) * fill_k
    if shape_ == "round":
        liq = [("ell", cx, cy + 0.15, r * 0.88, r * 0.88), ("-rect", cx - r * 2, cy - r * 2, cx + r * 2, lt)]
    elif shape_ == "flask":
        liq = body[:1] + [("-rect", cx - r * 2, cy - r * 2, cx + r * 2, lt)]
    else:
        liq = [("rect", cx - r * 0.7, lt, cx + r * 0.7, cy + r - 0.5)]
    cel(L, liq, liquid, form="sphere" if shape_ == "round" else "cylv", ol=0.0, bevel=1.0, rim=0.4, t1=0.3, t2=0.62)
    # meniscus line
    hw = r * (0.82 if shape_ != "square" else 0.68)
    if shape_ == "flask":
        hw = r * min(1.0, 0.4 + (lt - (cy - r * 0.35)) / (r * 1.15) * 0.62)
    hline(L, [(cx - hw * 0.92, lt + 0.05), (cx + hw * 0.92, lt + 0.05)], 0.28,
          np.clip(np.asarray(liquid) * 1.4 + 0.1, 0, 1), 0.85)
    # neck + lip + cork
    nw = r * 0.34
    cel(L, [("rect", cx - nw, top_y - r * 0.5, cx + nw, top_y + 0.6)], glass * 0.62, form="cylv", ol=2.0,
        bevel=0.6, line=C(30, 34, 40))
    cel(L, [("rect", cx - nw * 1.25, top_y - r * 0.62, cx + nw * 1.25, top_y - r * 0.38)], glass * 0.8,
        form="cylv", ol=1.8, bevel=0.4, line=C(30, 34, 40))
    cel(L, [("poly", [(cx - nw * 0.95, top_y - r * 0.6), (cx + nw * 0.95, top_y - r * 0.6), (cx + nw * 1.1, top_y - r * 1.05),
                      (cx - nw * 1.1, top_y - r * 1.05)])], cork, form="cylv", ol=1.8, bevel=0.5)
    if label is not None:
        lw, lh = r * 0.5, r * 0.3
        ly = cy + r * 0.34
        cel(L, [("rect", cx - lw, ly - lh, cx + lw, ly + lh)], label, n=(0, -0.05, 1), ol=1.2, bevel=0.3, rim=0)
    # glass gloss streaks (left, top-left light)
    gx = cx - r * 0.55
    hline(L, [(gx, cy - r * 0.45), (gx - r * 0.12, cy), (gx, cy + r * 0.35)], 0.42, SPEC, 0.75)
    fill(L, [("ell", cx - r * 0.42, cy - r * 0.62, r * 0.16, r * 0.12)], SPEC, 0.9)
    return lt


def pustule(L, x, y, r, col=C(150, 196, 70)):
    cel(L, [("ell", x, y, r, r * 0.9)], col, form="sphere", ol=1.2, bevel=0.8, gloss=0.0, rim=0.6, t1=0.32, t2=0.66)
    fill(L, [("ell", x - r * 0.35, y - r * 0.38, r * 0.3, r * 0.24)], SPEC, 0.85)


def sheet(images, path, cols=8, bg=(52, 42, 36), pad=8):
    """Contact sheet for review."""
    ws = max(i.width for i in images)
    hs = max(i.height for i in images)
    rows = (len(images) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (ws + pad) + pad, rows * (hs + pad) + pad), bg + (255,))
    for k, im in enumerate(images):
        out.alpha_composite(im, (pad + (k % cols) * (ws + pad), pad + (k // cols) * (hs + pad)))
    out.save(path)
    return out
