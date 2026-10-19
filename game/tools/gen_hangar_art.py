"""Hangar scene art, painted (v2): an abandoned Quonset airplane hangar at dusk
that builds out as camp ranks are bought. Same painted look as the heroes:
muted dusty palette, 4-tone ramps (light from the top-left) with ordered
dither, dark ink outline on props, grit, rust streaks, warm light shafts.

Layout space is still 240x150 "art units" (pets are placed in it by
scripts/ui/hangar.gd) but everything is painted at S=5x (1200x750) and saved
CROPPED to each layer's bounds; the rects go to scripts/data/hangar_art_layout.gd.

usage (from game/):
  python3 tools/gen_hangar_art.py                 # write layers + layout
  python3 tools/gen_hangar_art.py --preview DIR   # also write rank previews
Layer names: backdrop, trophy_wall, <shared id>_<1|3|5>, station_<hero>_<1|3|5>,
kennel_<pet>_<1|2|3>, stash_<0..3>, trophy_<boss>, cosmetic_<id>.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

S = 5
AW, AH = 240, 150
W, H = AW * S, AH * S
SS = 3  # mask supersampling
OUT = "assets/sprites/hangar"
LAYOUT_GD = "scripts/data/hangar_art_layout.gd"
F = np.float32


def C(*c):
    return np.array(c[:3], F) / 255.0


INK = C(20, 15, 13)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], F) / 16.0 - 0.47)

# ---- palette (muted, dusty) ----
RUST = C(116, 64, 42)
RUST_L = C(158, 88, 50)
BRASS = C(168, 128, 66)
STEEL = C(88, 94, 96)
STEEL_D = C(58, 62, 66)
STEEL_L = C(132, 134, 128)
OXID = C(74, 98, 90)
OLIVE = C(82, 86, 56)
OLIVE_D = C(60, 64, 44)
WOOD = C(112, 80, 52)
WOOD_D = C(78, 54, 36)
CANVAS = C(168, 152, 120)
CLOTH_R = C(124, 50, 40)
TONIC = C(118, 168, 78)
AMBER = C(232, 162, 72)
BULB = C(255, 216, 146)
BONE = C(200, 186, 156)
LEATHER = C(92, 60, 40)
CHARC = C(44, 40, 38)
TEALD = C(60, 92, 96)


# =========================================================== core helpers
def bayer(h, w, x0, y0, cell=2):
    ys = ((np.arange(h) + y0) // cell) % 4
    xs = ((np.arange(w) + x0) // cell) % 4
    return BAYER[ys[:, None], xs[None, :]]


def vnoise(h, w, cell, seed):
    r = np.random.default_rng(seed)
    gh, gw = h // cell + 4, w // cell + 4
    g = r.random((gh, gw)).astype(F)
    z = ndi.zoom(g, cell, order=3)
    return np.clip(z[:h, :w], 0, 1)


def fbm(h, w, cell, seed, octs=3):
    tot = np.zeros((h, w), F)
    amp, norm = 1.0, 0.0
    for o in range(octs):
        tot += amp * vnoise(h, w, max(1, int(cell / (2 ** o))), seed + o * 17)
        norm += amp
        amp *= 0.5
    return tot / norm


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-6), 0, 1)
    return t * t * (3 - 2 * t)


class Mask:
    def __init__(self, a, x0, y0):
        self.a, self.x0, self.y0 = a, x0, y0

    @property
    def h(self):
        return self.a.shape[0]

    @property
    def w(self):
        return self.a.shape[1]


def _pts(p):
    out = []
    if p[0] in ("poly", "line"):
        out += list(p[1])
    elif p[0] == "rect":
        out += [(p[1], p[2]), (p[3], p[4])]
    elif p[0] == "ell":
        out += [(p[1] - p[3], p[2] - p[4]), (p[1] + p[3], p[2] + p[4])]
    return out


def shape(prims, pad=8):
    """prims: ('poly',pts) ('rect',x0,y0,x1,y1) ('ell',cx,cy,rx,ry) ('line',pts,w);
    prefix '-' on the kind (e.g. '-ell') cuts it out. Art units."""
    pts = []
    for p in prims:
        pts += _pts((p[0].lstrip("-"),) + tuple(p[1:]))
    xs = [q[0] for q in pts]
    ys = [q[1] for q in pts]
    x0 = max(0, int(math.floor(min(xs) * S)) - pad)
    y0 = max(0, int(math.floor(min(ys) * S)) - pad)
    x1 = min(W, int(math.ceil(max(xs) * S)) + pad)
    y1 = min(H, int(math.ceil(max(ys) * S)) + pad)
    w, h = max(1, x1 - x0), max(1, y1 - y0)
    im = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(im)

    def T(q):
        return ((q[0] * S - x0) * SS, (q[1] * S - y0) * SS)

    for p in prims:
        k = p[0]
        val = 0 if k.startswith("-") else 255
        k = k.lstrip("-")
        if k == "poly":
            d.polygon([T(q) for q in p[1]], fill=val)
        elif k == "rect":
            a, b = T((p[1], p[2])), T((p[3], p[4]))
            d.rectangle((a[0], a[1], b[0] - 1, b[1] - 1), fill=val)
        elif k == "ell":
            a, b = T((p[1] - p[3], p[2] - p[4])), T((p[1] + p[3], p[2] + p[4]))
            d.ellipse((a[0], a[1], b[0], b[1]), fill=val)
        elif k == "line":
            wpx = max(1, int(p[2] * S * SS))
            d.line([T(q) for q in p[1]], fill=val, width=wpx, joint="curve")
            r = wpx / 2.0
            for q in (p[1][0], p[1][-1]):
                c = T(q)
                d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=val)
    a = np.asarray(im.resize((w, h), Image.BOX), F) / 255.0
    return Mask(a, x0, y0)


class Layer:
    def __init__(self):
        self.rgb = np.zeros((H, W, 3), F)
        self.a = np.zeros((H, W), F)

    def blend(self, alpha, x0, y0, col):
        h, w = alpha.shape
        # clip to canvas
        sx0, sy0 = max(0, -x0), max(0, -y0)
        ex, ey = min(w, W - x0), min(h, H - y0)
        if ex <= sx0 or ey <= sy0:
            return
        al = alpha[sy0:ey, sx0:ex]
        col = np.asarray(col, F)
        if col.ndim == 3:
            col = col[sy0:ey, sx0:ex]
        ys, xs = slice(y0 + sy0, y0 + ey), slice(x0 + sx0, x0 + ex)
        da = self.a[ys, xs]
        drgb = self.rgb[ys, xs]
        oa = al + da * (1 - al)
        num = col * al[..., None] + drgb * (da * (1 - al))[..., None]
        self.rgb[ys, xs] = num / np.maximum(oa, 1e-5)[..., None]
        self.a[ys, xs] = oa

    def put(self, m, col, alpha=1.0):
        self.blend(m.a * alpha, m.x0, m.y0, col)

    def image(self):
        rgba = np.dstack([np.clip(self.rgb, 0, 1), np.clip(self.a, 0, 1)])
        return Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")


def ramp(base, warm=0.0):
    b = np.asarray(base, F)
    g = b.mean()
    b = b * 0.88 + g * 0.12  # a touch of desaturation (dusty)
    dark = b * 0.40 + C(10, 6, 14)
    mid = b * 0.70 + C(4, 2, 4)
    light = np.clip(b * 1.16 + C(22, 16, 4) + warm * C(30, 18, 0), 0, 1)
    return np.stack([dark, mid, b, light])


_seed = [100]


def nseed():
    _seed[0] += 7
    return _seed[0]


def paint(L, m, base, form="box", bevel=4.0, ol=2.0, lit=1.0, grit=0.05, rust=0.0,
          wear=0.0, streaks=0.0, tex=None, warm=0.0, alpha=1.0, seam=True, tones=4):
    a = m.a
    h, w = a.shape
    if h < 2 or w < 2:
        return
    inside = a > 0.5
    if ol > 0:
        dout = ndi.distance_transform_edt(~inside)
        ring = np.clip(ol + 0.6 - dout, 0, 1)
        L.blend(np.maximum(ring, a) * alpha, m.x0, m.y0, INK)
    din = ndi.distance_transform_edt(inside).astype(F)
    bev = np.clip(din / bevel, 0, 1)
    bs = ndi.gaussian_filter(bev, 1.0)
    gy, gx = np.gradient(bs)
    edge = np.clip((gx * 0.62 + gy * 0.78) * bevel * 1.2, -1, 1)
    yy = np.linspace(0, 1, h, dtype=F)[:, None]
    xx = np.linspace(0, 1, w, dtype=F)[None, :]
    if form == "box":
        f = 0.20 * (0.5 - yy) + 0.08 * (0.5 - xx)
    elif form == "cylv":
        f = 0.42 * np.cos((xx - 0.34) * np.pi * 1.05) - 0.16
    elif form == "cylh":
        f = 0.42 * np.cos((yy - 0.3) * np.pi * 1.05) - 0.16
    elif form == "sphere":
        dd = np.sqrt((xx - 0.36) ** 2 + (yy - 0.32) ** 2)
        f = 0.36 - dd * 0.75
    else:
        f = np.zeros((h, w), F)
    v = 0.52 + 0.30 * edge * lit + f * lit
    if tex is not None:
        v = v + tex(h, w)
    v = v + (vnoise(h, w, 4, nseed()) - 0.5) * grit * 1.2
    v = v + (fbm(h, w, 22, nseed()) - 0.5) * 0.10
    v = v + bayer(h, w, m.x0, m.y0) * 0.17
    idx = np.clip(np.floor(v * tones), 0, tones - 1).astype(int)
    if tones != 4:
        idx = np.clip((idx * 4) // tones, 0, 3)
    rp = ramp(base, warm)
    col = rp[idx]
    col *= (1 + (np.random.default_rng(nseed()).random((h, w, 1)).astype(F) - 0.5) * 0.025)
    if rust > 0:
        rust = rust * 0.55
        n = fbm(h, w, 12, nseed(), 4)
        n = n * 0.85 + vnoise(h, w, 2, nseed()) * 0.15
        n = n + 0.25 * smooth(0.55, 1.0, 1 - bev)  # rust eats edges first
        th = 1 - rust
        rmask = smooth(th - 0.02, th + 0.02, n)
        rim = smooth(th - 0.06, th - 0.02, n) * (1 - rmask)
        rr = ramp(RUST)[np.clip(idx - 1 + (n > th + 0.08), 0, 3)]
        col = col * (1 - rmask[..., None]) + rr * rmask[..., None]
        col *= (1 - 0.25 * rim)[..., None]
    if streaks > 0:
        r = np.random.default_rng(nseed())
        st = np.zeros((h, w), F)
        for _ in range(int(w / 10 * streaks) + 1):
            sx = r.integers(0, w)
            sy = r.integers(0, max(1, h // 2))
            ln = r.integers(h // 4, h)
            st[sy:sy + ln, sx] = np.linspace(0.9, 0, min(ln, h - sy))
        st = ndi.gaussian_filter(st, (3, 0.8)) * 2.2
        st = np.clip(st, 0, 0.75) * inside
        rr = ramp(RUST)[np.clip(idx - 1, 0, 3)]
        col = col * (1 - st[..., None]) + rr * st[..., None]
    if wear > 0:
        n = vnoise(h, w, 2, nseed())
        chip = (edge > 0.35) & (n > 1 - wear)
        col[chip] = np.clip(col[chip] * 1.25 + 0.06, 0, 1)
    if seam:
        dark_edge = smooth(-0.35, -0.85, edge) * (din < 3)
        col *= (1 - 0.35 * dark_edge)[..., None]
    L.blend(a * alpha, m.x0, m.y0, col)


def P(L, prims, base, **kw):
    m = shape(prims)
    paint(L, m, base, **kw)
    return m


def soft(L, prims, col=(0, 0, 0), alpha=0.45, blur=6.0):
    m = shape(prims, pad=int(blur * 3) + 6)
    a = ndi.gaussian_filter(m.a, blur) * alpha
    L.blend(a, m.x0, m.y0, np.asarray(col, F) if np.asarray(col).max() <= 1 else C(*col))


def shadow(L, cx, cy, rx, ry, alpha=0.5):
    soft(L, [("ell", cx + rx * 0.12, cy, rx, ry)], C(10, 6, 6), alpha, blur=ry * S * 0.5 + 2)


def glow(L, cx, cy, r, col, strength=0.55):
    pad = int(r * S * 1.6)
    x0, y0 = int(cx * S) - pad, int(cy * S) - pad
    yy, xx = np.mgrid[0:2 * pad, 0:2 * pad].astype(F)
    d = np.sqrt((xx - pad) ** 2 + (yy - pad) ** 2) / (r * S)
    a = strength * np.exp(-d * d * 2.2)
    # dither the falloff a little so it reads painted, not airbrushed
    a = np.clip(a + bayer(2 * pad, 2 * pad, x0, y0) * 0.05 * (a > 0.02), 0, 1)
    L.blend(a, x0, y0, col)


def rivets(L, pts, col=STEEL_L, r=0.45):
    for (x, y) in pts:
        m = shape([("ell", x, y, r, r)], pad=3)
        L.put(m, col * 1.15)
        m2 = shape([("ell", x + r * 0.5, y + r * 0.5, r * 0.6, r * 0.6)], pad=3)
        L.put(m2, INK, 0.7)


def cable(L, pts, w=0.9, col=CHARC, ol=1.2):
    P(L, [("line", pts, w)], col, form="flat", bevel=2.0, ol=ol, grit=0.05)


def sag(x0, y0, x1, y1, dip, n=14):
    return [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + dip * 4 * t * (1 - t)) for t in np.linspace(0, 1, n)]


def stripes(L, m, col, period=3.0, ang=1.0, alpha=0.85):
    """Hazard / paint stripes clipped to a mask."""
    h, w = m.a.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(F)
    s = ((xx + yy * ang) / (period * S)) % 2.0 < 1.0
    L.blend(m.a * s * alpha * (m.a > 0.6), m.x0, m.y0, col)


def flame(L, cx, by, w, h):
    glow(L, cx, by - h * 0.5, max(w, h) * 1.1, AMBER, 0.45)
    P(L, [("poly", [(cx - w, by), (cx - w * 0.6, by - h * 0.55), (cx - w * 0.2, by - h * 0.4),
                    (cx, by - h), (cx + w * 0.3, by - h * 0.5), (cx + w * 0.7, by - h * 0.7), (cx + w, by)])],
      C(226, 112, 44), form="flat", ol=1.2, grit=0.1, warm=1)
    P(L, [("poly", [(cx - w * 0.5, by), (cx - w * 0.1, by - h * 0.55), (cx + w * 0.2, by - h * 0.35),
                    (cx + w * 0.5, by)])], BULB, form="flat", ol=0, grit=0.05)


# =========================================================== backdrop
VPX, VPY, FLOOR, RX, RY = 120.0, 70.0, 92.0, 118.0, 80.0
DOOR = (94.0, 44.0, 146.0, 92.0)
HOLES = [  # (depth d range, arch position p range) in the ceiling
    ((0.845, 0.95), (0.30, 0.37)),
    ((0.87, 0.965), (0.60, 0.66)),
    ((0.78, 0.84), (0.83, 0.875)),
]


def _cy(s):
    return VPY + (FLOOR - VPY) * s


def backdrop():
    yy, xx = np.mgrid[0:H, 0:W].astype(F)
    X = (xx + 0.5) / S
    Y = (yy + 0.5) / S
    rng = np.random.default_rng(11)
    img = np.zeros((H, W, 3), F)

    ell0 = ((X - VPX) / RX) ** 2 + ((Y - FLOOR) / RY) ** 2
    floor = Y >= FLOOR
    wall = (ell0 <= 1) & ~floor
    ceil = (ell0 > 1) & ~floor

    # ---- ceiling: solve the rib scale s for every ceiling pixel
    lo = np.ones_like(X)
    hi = np.full_like(X, 9.0)
    for _ in range(34):
        mid = (lo + hi) * 0.5
        f = ((X - VPX) / (RX * mid)) ** 2 + ((Y - _cy(mid)) / (RY * mid)) ** 2 - 1
        pos = f > 0
        lo = np.where(pos, mid, lo)
        hi = np.where(pos, hi, mid)
    s = np.where(ceil, (lo + hi) * 0.5, 1.0)
    d = 1.0 / s  # depth: 1 at the back wall, ->0 toward the camera
    th = np.arctan2((Y - _cy(s)) / (RY * s), (X - VPX) / (RX * s))
    p = np.clip((th + np.pi) / np.pi, 0, 1)  # 0 left floor .. 1 right floor
    # corrugation runs around the arch (constant depth)
    dd = np.abs(np.gradient(d, axis=0)) + np.abs(np.gradient(d, axis=1)) + 1e-6
    freq = 70.0
    amp = np.clip(0.5 / (dd * freq * 4), 0, 1)
    corr = np.sin(d * freq * 2 * np.pi) * amp
    seam_p = np.abs(((p * 14) % 1.0) - 0.5) < 0.035
    base = np.full_like(X, 0.20)
    lum = base + 0.055 * corr + 0.10 * (1 - p) * (1 - d) - 0.06 * np.abs(p - 0.5) * 0
    lum = lum + 0.08 * smooth(0.5, 1.0, d) * np.exp(-((p - 0.5) ** 2) / 0.02)  # bounce from the door
    lum = np.where(seam_p, lum * 0.62, lum)
    # ribs (I-beam trusses) at even depth steps
    rib = np.zeros_like(X)
    ribhl = np.zeros_like(X)
    for k in range(1, 7):
        dk = 1.0 - 0.115 * k
        band = 0.013 * (1 + (1 - dk))
        t = (d - dk) / band
        rib = np.maximum(rib, (np.abs(t) < 1).astype(F))
        ribhl = np.maximum(ribhl, ((t > 0.45) & (t < 1)).astype(F))
        # lattice web: diagonals inside a wider band
        web = (np.abs(t) < 2.6) & (np.abs(t) >= 1) & (np.abs(((p * 40 + t * 0.35) % 1.0) - 0.5) < 0.06)
        rib = np.maximum(rib, web.astype(F) * 0.8)
    # rust on the roof sheets
    n = fbm(H, W, 14, 3, 4)
    rustm = smooth(0.60, 0.66, n) * ceil * 0.45
    ceil_col = np.stack([lum * 1.02, lum * 0.92, lum * 0.86], -1)
    ceil_col = ceil_col * (1 - rustm[..., None] * 0.6) + rustm[..., None] * (RUST * (lum[..., None] * 2.6))
    rib_col = np.stack([0.11 + 0.10 * ribhl, 0.10 + 0.08 * ribhl, 0.10 + 0.06 * ribhl], -1)
    ceil_col = np.where((rib > 0)[..., None], rib_col * (0.6 + 0.4 * rib[..., None]) + ceil_col * 0.0, ceil_col)
    # holes in the roof (sky)
    holes = np.zeros_like(X)
    hn = fbm(H, W, 5, 9) * 0.6 + vnoise(H, W, 2, 10) * 0.4
    for (d0, d1), (p0, p1) in HOLES:
        jag = (hn - 0.5) * 0.035
        inside = (d > d0 + jag) & (d < d1 - jag) & (p > p0 + jag * 0.8) & (p < p1 - jag * 0.8)
        holes = np.maximum(holes, inside.astype(F))
    holes *= ceil
    rim = (ndi.binary_dilation(holes > 0.5, iterations=7) & ~(holes > 0.5)) & ceil
    ty_ = np.clip(Y / 40, 0, 1)[..., None]
    sky_hole = C(240, 178, 112) * (1 - ty_) + C(252, 224, 170) * ty_
    sky_hole = sky_hole * (0.94 + 0.08 * fbm(H, W, 8, 12)[..., None])
    ceil_col = np.where(rim[..., None], ceil_col * 0.45, ceil_col)
    rim2 = (ndi.binary_dilation(holes > 0.5, iterations=3) & ~(holes > 0.5)) & ceil
    lit_side = (np.gradient(ndi.gaussian_filter(holes, 3), axis=0) > 0) | (np.gradient(ndi.gaussian_filter(holes, 3), axis=1) > 0)
    ceil_col = np.where((rim2 & lit_side)[..., None], C(196, 126, 70) + 0 * ceil_col, ceil_col)
    ceil_col = np.where((rim2 & ~lit_side)[..., None], C(38, 24, 18) + 0 * ceil_col, ceil_col)
    ceil_col = np.where((holes > 0.5)[..., None], sky_hole, ceil_col)
    img = np.where(ceil[..., None], ceil_col, img)

    # ---- back wall (corrugated end wall)
    wx = X
    corrw = np.sin(wx * 2 * np.pi / 1.7)
    wl = 0.25 + 0.03 * corrw + 0.05 * (Y - 12) / 80
    panel = np.abs(((wx / 11.0) % 1.0) - 0.5) > 0.47
    wl = np.where(panel, wl * 0.7, wl)
    for gy in (58.0, 76.0):
        g = np.abs(Y - gy) < 1.1
        wl = np.where(g, 0.17 + 0.08 * (Y < gy), wl)
    ws = fbm(H, W, 12, 21, 4)
    wrust = smooth(0.60, 0.66, ws) * 0.7
    # rust streaks running down from the girts and the top
    st = np.zeros((H, W), F)
    for _ in range(90):
        sx = rng.integers(0, W)
        sy = int(rng.choice([12, 58, 76, 30]) * S + rng.integers(0, 20))
        ln = rng.integers(30, 160)
        st[sy:sy + ln, sx] = np.linspace(1, 0, len(range(sy, min(H, sy + ln))))
    st = np.clip(ndi.gaussian_filter(st, (4, 1.0)) * 2.4, 0, 0.8)
    wall_col = np.stack([wl * 1.0, wl * 0.97, wl * 0.92], -1)
    tint = OXID * 1.1
    wall_col = wall_col * (0.75 + 0.25 * tint / tint.mean())
    wall_col = wall_col * (1 - wrust[..., None] * 0.55) + wrust[..., None] * RUST * (wl[..., None] * 2.4)
    wall_col = wall_col * (1 - st[..., None] * 0.6) + st[..., None] * RUST_L * 0.55
    # warm light near the doorway + darker toward the arch
    dx = np.abs(X - 120)
    wall_col *= (0.80 + 0.35 * np.exp(-((dx - 28) ** 2) / 300.0) * (Y > 40))[..., None]
    wall_col *= (0.65 + 0.35 * np.clip((Y - 12) / 50, 0, 1))[..., None]
    img = np.where(wall[..., None], wall_col, img)

    # ---- floor: concrete in perspective
    sf = np.maximum((Y - VPY) / (FLOOR - VPY), 1.0)
    zw = 1.0 / sf
    xw = (X - VPX) / sf
    cn = fbm(H, W, 22, 5) * 0.6 + vnoise(H, W, 3, 6) * 0.4
    fl = 0.30 + 0.07 * (cn - 0.5)
    jx = np.abs(((xw / 26.0) % 1.0) - 0.5) > 0.485
    jz = np.abs((((1 / zw) * 2.2) % 1.0) - 0.5) > 0.47
    fl = np.where(jx | jz, fl * 0.68, fl)
    floor_col = np.stack([fl * 1.04, fl * 0.94, fl * 0.82], -1)
    # oil stains
    for i in range(10):
        ox, oz = rng.uniform(-110, 110), rng.uniform(0.32, 0.98)
        r = rng.uniform(5, 14)
        ex = (xw - ox) / r
        ez = (1 / zw - 1 / oz) * oz * 3.0 / (r / 10)
        e = ex ** 2 + ez ** 2
        stain = smooth(1.0, 0.55, e + (cn - 0.5) * 0.8) * floor
        floor_col *= (1 - 0.28 * stain)[..., None]
        sheen = smooth(0.35, 0.15, np.abs(e - 0.45)) * stain * 0.15
        floor_col += (sheen[..., None] * C(90, 80, 110))
    # tyre / drag marks from the doorway
    for xoff in (-9, -5, 6, 10):
        tm = np.exp(-((xw - xoff - (1 / zw) * 1.2) ** 2) / 1.2) * floor * (Y > 96)
        floor_col *= (1 - 0.12 * tm * vnoise(H, W, 8, 30 + xoff))[..., None]
    # sand blown in through the door
    sn = fbm(H, W, 30, 8, 3)
    sand = smooth(0.12, -0.08, np.abs(xw) / 40 + (1 - zw) * 0.7 - (sn - 0.5) * 0.7 - 0.22) * floor * 0.8
    floor_col = floor_col * (1 - sand[..., None] * 0.65) + sand[..., None] * C(150, 108, 70) * (0.75 + 0.3 * cn[..., None])
    # warm spill of daylight from the door, fanning toward the camera
    spill = smooth(30, 8, np.abs(xw)) * smooth(0.0, 0.9, zw) * floor
    floor_col += spill[..., None] * C(70, 38, 14)
    # cracks
    cr = np.zeros((H, W), F)
    for i in range(10):
        x, y = rng.uniform(0, W), rng.uniform(FLOOR * S + 20, H)
        a = rng.uniform(0, np.pi)
        for k in range(rng.integers(40, 140)):
            a += rng.normal(0, 0.18)
            x += math.cos(a) * 1.5
            y += math.sin(a) * 0.5
            if 0 <= x < W and FLOOR * S < y < H:
                cr[int(y), int(x)] = 1
    cr = cr > 0
    floor_col = np.where(cr[..., None], floor_col * 0.72, floor_col)
    # ambient occlusion at the wall base, vignette toward the camera
    floor_col *= (0.62 + 0.38 * smooth(FLOOR, FLOOR + 6, Y))[..., None]
    floor_col *= (1 - 0.35 * smooth(120, 150, Y) - 0.25 * smooth(60, 120, np.abs(X - 120)))[..., None]
    img = np.where(floor[..., None], floor_col, img)

    L = Layer()
    L.rgb[:] = img
    L.a[:] = 1.0

    # ---- doorway: dusk outside, Helm's crashed plane on the dunes
    x0, y0, x1, y1 = DOOR
    sx0, sy0, sx1, sy1 = int(x0 * S), int(y0 * S), int(x1 * S), int(y1 * S)
    hh, ww = sy1 - sy0, sx1 - sx0
    ty = np.linspace(0, 1, hh, dtype=F)[:, None] * np.ones((1, ww), F)
    tx = np.linspace(0, 1, ww, dtype=F)[None, :] * np.ones((hh, 1), F)
    top, midc, hor = C(96, 48, 30), C(198, 104, 48), C(244, 184, 110)
    sky = np.where((ty < 0.55)[..., None],
                   top + (midc - top) * (ty / 0.55)[..., None],
                   midc + (hor - midc) * ((ty - 0.55) / 0.45)[..., None])
    cl = fbm(hh, ww, 26, 40)
    sky *= (0.93 + 0.12 * cl)[..., None]
    sunx, suny, sunr = 0.40, 0.70, 0.13
    dsun = np.sqrt(((tx - sunx) * ww) ** 2 + ((ty - suny) * hh) ** 2) / (sunr * ww)
    sky += (np.exp(-dsun * dsun * 0.6) * 0.30)[..., None] * C(255, 200, 120)
    sky = np.where((dsun < 1)[..., None], C(252, 222, 160) + 0 * sky, sky)

    def dune(base_y, ampl, ph, col):
        prof = base_y + ampl * np.sin(tx[0] * 5.0 + ph) + ampl * 0.5 * np.sin(tx[0] * 11 + ph * 2)
        m = ty > prof[None, :]
        return m, col

    for by, am, ph, col in ((0.74, 0.03, 0.3, C(156, 82, 50)), (0.82, 0.035, 1.7, C(118, 62, 40)),
                            (0.91, 0.03, 4.0, C(84, 46, 32))):
        m, col = dune(by, am, ph, col)
        shade = (0.92 + 0.1 * vnoise(hh, ww, 6, int(by * 100)))[..., None]
        sky = np.where(m[..., None], col * shade, sky)
    D = Layer()
    D.rgb[sy0:sy1, sx0:sx1] = sky
    D.a[sy0:sy1, sx0:sx1] = 1
    # the wreck: nose buried in the far dune, tail up, broken wing
    wr = C(70, 42, 32)
    P(D, [("poly", [(124, 84.5), (128, 79), (138, 72.5), (141, 73.5), (133, 82), (127, 86)])], wr, ol=0.8,
      bevel=2, grit=0.05, lit=0.7, form="cylv")
    P(D, [("poly", [(137, 73.5), (139, 66.5), (141.5, 67), (141, 74)])], wr * 0.9, ol=0.8, bevel=1.5, grit=0.05)
    P(D, [("poly", [(129, 80.5), (121, 78.5), (120, 80), (128.5, 82)])], wr * 1.1, ol=0.7, bevel=1.5)
    P(D, [("poly", [(132, 78), (139, 81.5), (138.5, 82.5), (131.5, 79.5)])], wr * 0.85, ol=0.7, bevel=1.5)
    soft(D, [("ell", 131, 69, 3, 4), ("ell", 129.5, 63, 4, 4.5), ("ell", 127, 56.5, 5, 4)], C(110, 80, 70), 0.35, 6)
    # haze over everything outside
    D.rgb[sy0:sy1, sx0:sx1] = D.rgb[sy0:sy1, sx0:sx1] * 0.85 + C(220, 140, 80) * 0.15
    L.blend(D.a[sy0:sy1, sx0:sx1], sx0, sy0, D.rgb[sy0:sy1, sx0:sx1])
    # light from the door spills onto the door frame
    glow(L, 120, 80, 30, C(230, 140, 70), 0.18)

    # ---- door frame + track + the two sliding leaves
    P(L, [("rect", 91.5, 42, 94.5, 92.5)], STEEL_D, form="cylv", ol=1.0, bevel=2.5, rust=0.25, streaks=0.4)
    P(L, [("rect", 145.5, 42, 148.5, 92.5)], STEEL_D, form="cylv", ol=1.0, bevel=2.5, rust=0.25, streaks=0.4)
    P(L, [("rect", 60, 39.5, 182, 43.5)], STEEL_D, form="cylh", ol=1.0, bevel=2.5, rust=0.3, streaks=1.0)
    rivets(L, [(x, 41.5) for x in range(64, 180, 6)], STEEL)
    corr_tex = lambda h, w: 0.10 * np.sin(np.arange(w, dtype=F)[None, :] * 2 * np.pi / (1.6 * S)) * np.ones((h, 1), F)
    # left leaf (slid open), faded oxidised-teal paint flaking to rust
    lm = P(L, [("poly", [(66.5, 43.5), (92, 43.5), (92, 92.5), (66.5, 92.5)])], OXID, tex=corr_tex, ol=1.6,
           bevel=3, rust=0.45, streaks=1.4, wear=0.15, grit=0.1)
    for (a, b) in (((67.5, 46), (91, 90)), ((91, 46), (67.5, 90))):
        P(L, [("line", [a, b], 1.4)], STEEL_D, form="flat", ol=0.8, bevel=1.5, rust=0.4)
    P(L, [("rect", 66.5, 66.5, 92, 69)], STEEL_D, form="cylh", ol=0.8, bevel=1.5, rust=0.4)
    # right leaf: off its track, hanging crooked
    P(L, [("poly", [(147.5, 44), (173.5, 45.5), (172, 92.5), (149, 92.5)])], OXID * 0.92, tex=corr_tex, ol=1.6,
      bevel=3, rust=0.4, streaks=1.4, wear=0.15, grit=0.1)
    P(L, [("line", [(149, 47), (171.5, 90)], 1.4)], STEEL_D, form="flat", ol=0.8, bevel=1.5, rust=0.4)
    P(L, [("poly", [(148.5, 67), (172.8, 68.2), (172.7, 70.6), (148.5, 69.5)])], STEEL_D, ol=0.8, bevel=1.5, rust=0.4)
    # torn gap at the right leaf's top corner showing the dark wall
    P(L, [("poly", [(166, 45.2), (173.5, 45.5), (173.2, 51), (169, 48)])], CHARC, ol=0.6, form="flat")
    # loose door-track wheel hanging
    P(L, [("ell", 160, 42.2, 1.4, 1.4)], STEEL, form="sphere", ol=0.8, bevel=1.2)

    # ---- a pair of hanging work lamps (dead until the Generator) + conduits on the wall
    cable(L, [(20, 66), (60, 63.5), (66, 63.5)], 0.7, CHARC, 0.6)
    cable(L, [(174, 63.5), (200, 64.5), (232, 70)], 0.7, CHARC, 0.6)
    P(L, [("rect", 30, 50, 33, 92.5)], STEEL_D, form="cylv", ol=0.8, bevel=1.5, rust=0.4, streaks=0.6)
    P(L, [("rect", 207, 50, 210, 92.5)], STEEL_D, form="cylv", ol=0.8, bevel=1.5, rust=0.4, streaks=0.6)
    # a fuse box and old stencilled sign plate left of the door
    P(L, [("rect", 44, 48, 52, 57)], OLIVE_D, ol=1.0, bevel=2, rust=0.4, streaks=0.8, wear=0.2)
    P(L, [("rect", 186, 47, 200, 52)], C(140, 120, 80), ol=0.9, bevel=1.5, rust=0.35, wear=0.25, grit=0.12)
    for k in range(4):
        P(L, [("rect", 187.5 + k * 3.2, 48.6, 189.3 + k * 3.2, 50.6)], CHARC, ol=0, form="flat")

    # ---- light shafts from the roof holes, slanting down-right, landing on the floor
    SH = Layer()
    for (d0, d1), (p0, p1) in HOLES:
        dm, pm = (d0 + d1) / 2, (p0 + p1) / 2
        sc = 1 / dm
        th0 = -np.pi + pm * np.pi
        hx = VPX + RX * sc * math.cos(th0)
        hy = _cy(sc) + RY * sc * math.sin(th0)
        hw = RX * sc * (p1 - p0) * 1.4
        # landing spot on the floor at the same depth, pushed right/forward by the low sun
        fy = _cy(sc) + 4
        fx = hx + (fy - hy) * 0.42
        fw = hw * 1.25
        soft(SH, [("poly", [(hx - hw * 0.5, hy), (hx + hw * 0.5, hy), (fx + fw * 0.6, fy), (fx - fw * 0.6, fy)])],
             C(255, 196, 120), 0.30, 4)
        soft(SH, [("poly", [(hx - hw * 0.15, hy), (hx + hw * 0.15, hy), (fx + fw * 0.2, fy), (fx - fw * 0.2, fy)])],
             C(255, 220, 160), 0.18, 3)
        soft(SH, [("ell", fx, fy, fw * 0.75, fw * 0.16)], C(255, 190, 110), 0.42, 4)
        # dust motes in the beam
        r = np.random.default_rng(int(pm * 1000))
        for _ in range(26):
            t = r.uniform(0.05, 0.95)
            mx = (hx + (fx - hx) * t) + r.uniform(-0.4, 0.4) * (hw + (fw - hw) * t)
            my = hy + (fy - hy) * t
            m = shape([("ell", mx, my, 0.22, 0.22)], pad=2)
            SH.put(m, BULB, 0.55)
    L.blend(SH.a, 0, 0, SH.rgb)

    # ---- grade + texture: dusty warm haze, vignette, dithered grain
    rgb = L.rgb
    lumi = rgb.mean(-1, keepdims=True)
    rgb = rgb * 0.9 + lumi * 0.1
    rgb = rgb * C(255, 236, 214) * 1.04
    vig = 1 - 0.35 * (((X - 120) / 140) ** 2 + ((Y - 80) / 110) ** 2)
    rgb *= np.clip(vig, 0.5, 1)[..., None]
    grain = (vnoise(H, W, 2, 77) - 0.5) * 0.05 + bayer(H, W, 0, 0) * 0.025
    rgb = rgb + grain[..., None]
    levels = 40.0
    rgb = np.floor(np.clip(rgb, 0, 1) * levels + 0.5 + bayer(H, W, 0, 0)[..., None] * 0.6) / levels
    L.rgb = np.clip(rgb, 0, 1).astype(F)
    return L


# =========================================================== anime cel painter (props, v3)
# Props are drawn like the hero art: confident shapes, a crisp coloured ink line
# (heavier on the shadow side), 3 hard-edged tones (cool shadow / local / warm
# light) with a soft gradient on top, a warm rim along edges that face the door,
# and hard specular streaks on metal and glass. No dither, no grain.
# Key light = the dusk doorway (back wall, centre); a cool fill comes from the camera.
SHADOW_TINT = C(52, 60, 104)
INK3 = C(22, 16, 24)
SPEC = C(255, 242, 214)
RIMC = C(255, 196, 128)
DOOR_LIGHT = (120.0, 66.0)


def _key(cx, cy):
    lx = float(np.clip((DOOR_LIGHT[0] - cx) / 55.0, -1, 1)) * 0.85
    ly = float(np.clip((DOOR_LIGHT[1] - cy) / 45.0, -1, 1)) * 0.85
    if abs(lx) < 0.25 and ly > -0.3:
        ly = -0.5
    v = np.array([lx, ly, -0.30], F)
    return v / np.linalg.norm(v)


FILL = np.array([0.0, -0.25, 0.97], F)
HALF_F = (FILL + np.array([0, 0, 1], F))
HALF_F = HALF_F / np.linalg.norm(HALF_F)


def tone_set(base):
    b = np.asarray(base, F)
    return dict(
        deep=np.clip(b * 0.34 + SHADOW_TINT * 0.16, 0, 1),
        shadow=np.clip(b * 0.58 + SHADOW_TINT * 0.17, 0, 1),
        mid=b,
        light=np.clip(b * 1.12 + C(34, 22, 6), 0, 1),
        line=np.clip(b * 0.24 + INK3 * 0.72, 0, 1),
    )


def cel(L, prims, base, form="flat", n=None, ol=2.6, bevel=2.2, metal=0.0, gloss=0.0, rim=1.0,
        t1=0.40, t2=0.72, grad=0.14, rust=0.0, wear=0.0, alpha=1.0, shade=0.0, pad=10,
        line=None, flip=False, key=None, spec_t=0.965, deep=True):
    """One cel-shaded part. form: flat | cylv | cylh | sphere | dome; n=(nx,ny,nz) for a planar facet."""
    m = shape(prims, pad)
    a = m.a
    h, w = a.shape
    if h < 3 or w < 3:
        return m
    inside = a > 0.5
    if not inside.any():
        return m
    ys, xs = np.nonzero(inside)
    bx0, bx1, by0, by1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cx, cy = (m.x0 + (bx0 + bx1) / 2) / S, (m.y0 + (by0 + by1) / 2) / S
    K = _key(cx, cy) if key is None else np.asarray(key, F) / np.linalg.norm(key)
    T = tone_set(base)
    ink = T["line"] if line is None else np.asarray(line, F)
    u = ((np.arange(w, dtype=F) + 0.5 - bx0) / max(1, bx1 - bx0))[None, :] * np.ones((h, 1), F)
    v = ((np.arange(h, dtype=F) + 0.5 - by0) / max(1, by1 - by0))[:, None] * np.ones((1, w), F)
    if flip:
        u = 1 - u
    nx = np.zeros((h, w), F)
    ny = np.zeros((h, w), F)
    if n is not None:
        nn = np.asarray(n, F) / np.linalg.norm(n)
        nx += nn[0]
        ny += nn[1]
    elif form == "cylv":
        nx = (u - 0.5) * 1.9
        ny += -0.12
    elif form == "cylh":
        ny = (v - 0.5) * 1.9
    elif form == "sphere":
        nx = (u - 0.5) * 1.9
        ny = (v - 0.5) * 1.9
    elif form == "dome":
        nx = (u - 0.5) * 1.6
        ny = (v - 0.5) * 1.0 - 0.45
    # rounded edges: bend the normal outward near the silhouette
    din = ndi.distance_transform_edt(inside).astype(F)
    if bevel > 0:
        g = ndi.gaussian_filter(np.minimum(din, bevel * 2.5), 1.2)
        gy, gx = np.gradient(g)
        gl = np.sqrt(gx * gx + gy * gy) + 1e-5
        ox, oy = -gx / gl, -gy / gl
        wgt = np.clip(1 - din / bevel, 0, 1) ** 1.3
        nx = nx * (1 - wgt) + ox * wgt * 0.95
        ny = ny * (1 - wgt) + oy * wgt * 0.95
    else:
        ox = oy = np.zeros((h, w), F)
    r2 = np.clip(nx * nx + ny * ny, 0, 0.97)
    nz = np.sqrt(1 - r2)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    key_l = np.clip(nx * K[0] + ny * K[1] + nz * K[2], 0, 1)
    fill_l = np.clip(nx * FILL[0] + ny * FILL[1] + nz * FILL[2], 0, 1)
    lam = key_l * 1.0 + fill_l * 0.55 + shade
    s1 = smooth(t1 - 0.012, t1 + 0.012, lam)
    s2 = smooth(t2 - 0.012, t2 + 0.012, lam)
    col = T["shadow"][None, None] + (T["mid"] - T["shadow"])[None, None] * s1[..., None]
    col = col + (T["light"][None, None] - col) * s2[..., None]
    if deep:
        sd = smooth(0.17, 0.15, lam)
        col = col + (T["deep"][None, None] - col) * sd[..., None] * 0.8
    # rust: clean hard-edged patches, cel-toned
    if rust > 0:
        nz_ = fbm(h, w, 14, nseed(), 3) + 0.12 * (din < 5)
        th = 1 - rust * 0.45
        rm = smooth(th - 0.006, th + 0.006, nz_) * inside
        RT = tone_set(RUST)
        rc = RT["shadow"][None, None] + (RT["mid"] - RT["shadow"])[None, None] * s1[..., None]
        rc = rc + (RT["light"][None, None] - rc) * s2[..., None] * 0.7
        col = col * (1 - rm[..., None]) + rc * rm[..., None]
    if wear > 0:
        nw = vnoise(h, w, 3, nseed())
        chip = ((din < 3.5) & (din > 0.8) & (nw > 1 - wear * 0.6)).astype(F)
        chip = ndi.gaussian_filter(chip, 0.5) > 0.5
        col[chip] = np.clip(col[chip] * 0.55 + C(186, 180, 168) * 0.45, 0, 1)
    # hard specular (key half-vector, plus the camera fill for metal)
    if metal > 0 and n is None:
        Hk = K + np.array([0, 0, 1], F)
        Hk = Hk / np.linalg.norm(Hk)
        sk = nx * Hk[0] + ny * Hk[1] + nz * Hk[2]
        sf = nx * HALF_F[0] + ny * HALF_F[1] + nz * HALF_F[2]
        sp = np.maximum(smooth(spec_t - 0.004, spec_t + 0.004, sk), smooth(0.994, 0.997, sf) * 0.7)
        col = col + (SPEC[None, None] - col) * (sp * metal)[..., None]
    if gloss > 0:  # glossy planar: two diagonal streaks (glass / enamel)
        d = u * 0.75 + v * 0.55
        st = (np.abs(d - 0.32) < 0.07) | (np.abs(d - 0.50) < 0.025)
        st = st & (din > 2.5)
        col = col + (SPEC[None, None] - col) * (st * gloss)[..., None]
    # soft gradient on top of the cel tones (top-lit warm -> cool bottom)
    gv = 1 + grad * (0.45 - v)
    col = col * gv[..., None]
    # warm rim on edges facing the door
    if rim > 0:
        facing = ox * K[0] + oy * K[1]
        rm_ = ((din > 0.4) & (din < 2.2) & (facing > 0.45)).astype(F) * inside
        col = col + (np.clip(RIMC * 0.5 + T["light"] * 0.6, 0, 1)[None, None] - col) * (rm_ * 0.75 * rim)[..., None]
    # ink: heavier on the side away from the key light
    if ol > 0:
        dout = ndi.distance_transform_edt(~inside)
        ring = np.clip(ol + 0.5 - dout, 0, 1)
        sx, sy = int(round(-K[0] * ol * 0.6)), int(round(-K[1] * ol * 0.6))
        sh = np.roll(np.roll(inside, sy, 0), sx, 1)
        dout2 = ndi.distance_transform_edt(~sh)
        ring = np.maximum(ring, np.clip(ol * 0.8 + 0.5 - dout2, 0, 1))
        L.blend(np.maximum(ring, a) * alpha, m.x0, m.y0, ink)
    L.blend(a * alpha, m.x0, m.y0, np.clip(col, 0, 1))
    return m


def ink(L, pts, w=0.28, col=INK3, alpha=0.9):
    m = shape([("line", pts, w)], pad=4)
    L.blend(m.a * alpha, m.x0, m.y0, np.asarray(col, F))


def hline(L, pts, w=0.22, col=SPEC, alpha=0.8):
    ink(L, pts, w, col, alpha)


def fill(L, prims, col, alpha=1.0):
    m = shape(prims, pad=4)
    L.blend(m.a * alpha, m.x0, m.y0, np.asarray(col, F))


def cshadow(L, cx, cy, rx, ry, a=0.55):
    """Cool soft contact shadow + a tighter core."""
    soft(L, [("ell", cx, cy, rx, ry)], C(14, 14, 28), a * 0.7, blur=ry * S * 0.7 + 2)
    soft(L, [("ell", cx, cy - ry * 0.1, rx * 0.82, ry * 0.45)], C(10, 8, 18), a * 0.6, blur=2.0)


def glow2(L, cx, cy, r, col, strength=0.5):
    pad = int(r * S * 1.6)
    x0, y0 = int(cx * S) - pad, int(cy * S) - pad
    yy, xx = np.mgrid[0:2 * pad, 0:2 * pad].astype(F)
    d = np.sqrt((xx - pad) ** 2 + (yy - pad) ** 2) / (r * S)
    L.blend(strength * np.exp(-d * d * 2.2), x0, y0, np.asarray(col, F))


def _side(cx):
    """Which side face the camera sees (+1 = right side, -1 = left side)."""
    return 1.0 if cx < VPX else -1.0


def box3(L, x0, y0, x1, y1, d, base, top=None, side=None, ol=2.6, **kw):
    """A box seen from the hangar camera: front face + top + the side facing the centre."""
    cx = (x0 + x1) / 2
    sg = _side(cx)
    k = min(1.0, abs(cx - VPX) / 45.0) * 0.55 + 0.12
    dx = d * k * sg
    dy = d * 0.42
    topf = [("poly", [(x0, y0), (x1, y0), (x1 + dx, y0 - dy), (x0 + dx, y0 - dy)])]
    if sg > 0:
        sidef = [("poly", [(x1, y0), (x1 + dx, y0 - dy), (x1 + dx, y1 - dy), (x1, y1)])]
    else:
        sidef = [("poly", [(x0, y0), (x0 + dx, y0 - dy), (x0 + dx, y1 - dy), (x0, y1)])]
    front = [("rect", x0, y0, x1, y1)]
    # one heavy silhouette line, then faces with thin seams
    un = shape(front + topf + sidef, pad=10)
    inside = un.a > 0.5
    dout = ndi.distance_transform_edt(~inside)
    T = tone_set(base)
    L.blend(np.maximum(np.clip(ol + 0.5 - dout, 0, 1), un.a), un.x0, un.y0, T["line"])
    kw2 = dict(kw)
    kw2.setdefault("bevel", 1.2)
    cel(L, topf, top if top is not None else base, n=(0, -0.92, 0.38), ol=0.9, **kw2)
    cel(L, sidef, side if side is not None else base, n=(sg * 0.95, 0, 0.3), ol=0.9, **kw2)
    cel(L, front, base, n=(0, -0.05, 1), ol=0.9, **kw2)
    return dict(dx=dx, dy=dy, sg=sg)


def drum(L, cx, y0, y1, rx, base, ry=None, top=None, ol=2.6, open_top=False, **kw):
    """Upright cylinder: body + elliptical top."""
    ry = rx * 0.32 if ry is None else ry
    un = shape([("rect", cx - rx, y0, cx + rx, y1), ("ell", cx, y0, rx, ry), ("ell", cx, y1, rx, ry)], pad=10)
    inside = un.a > 0.5
    dout = ndi.distance_transform_edt(~inside)
    T = tone_set(base)
    L.blend(np.maximum(np.clip(ol + 0.5 - dout, 0, 1), un.a), un.x0, un.y0, T["line"])
    cel(L, [("rect", cx - rx, y0, cx + rx, y1), ("ell", cx, y1, rx, ry)], base, form="cylv", ol=0.0, **kw)
    if open_top:
        cel(L, [("ell", cx, y0, rx, ry)], base, n=(0, -0.9, 0.4), ol=0.9, bevel=0.8)
        cel(L, [("ell", cx, y0 + ry * 0.12, rx * 0.86, ry * 0.76)], base * 0.45, n=(0, 0.3, 1), ol=0.6,
            bevel=0, rim=0)
    else:
        cel(L, [("ell", cx, y0, rx, ry)], top if top is not None else base, n=(0, -0.9, 0.4), ol=0.9,
            bevel=0.9, **{k: v for k, v in kw.items() if k in ("metal", "rust", "wear")})


def bulb(L, x, y, r, col=BULB, glow_r=None, strength=0.42):
    glow2(L, x, y, glow_r or r * 4.0, AMBER, strength)
    cel(L, [("ell", x, y, r, r * 1.2)], col, form="sphere", ol=1.2, bevel=1.0, rim=0, t1=0.0, t2=0.3,
        line=C(120, 70, 30))
    fill(L, [("ell", x - r * 0.3, y - r * 0.4, r * 0.28, r * 0.32)], C(255, 255, 240), 0.95)


def bolts(L, pts, col=STEEL_L, r=0.38):
    for (x, y) in pts:
        cel(L, [("ell", x, y, r, r)], col, form="sphere", ol=0.9, bevel=0.6, metal=0.7, rim=0, pad=4)


def wood_grain(L, x0, y0, x1, y1, col, n=3, horiz=True, seed=0, alpha=0.5):
    r = np.random.default_rng(seed + nseed())
    for i in range(n):
        if horiz:
            y = y0 + (y1 - y0) * (i + 0.5 + r.uniform(-0.2, 0.2)) / n
            xa = x0 + r.uniform(0.05, 0.3) * (x1 - x0)
            xb = x1 - r.uniform(0.05, 0.3) * (x1 - x0)
            ink(L, [(xa, y), ((xa + xb) / 2, y + r.uniform(-0.25, 0.25)), (xb, y)], 0.16, col, alpha)
        else:
            x = x0 + (x1 - x0) * (i + 0.5 + r.uniform(-0.2, 0.2)) / n
            ya = y0 + r.uniform(0.05, 0.25) * (y1 - y0)
            yb = y1 - r.uniform(0.05, 0.25) * (y1 - y0)
            ink(L, [(x, ya), (x + r.uniform(-0.2, 0.2), (ya + yb) / 2), (x, yb)], 0.16, col, alpha)


def vents(L, x0, y0, x1, y1, n, base):
    """Pressed louvre slots: dark slot + lit lower lip."""
    T = tone_set(base)
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        fill(L, [("rect", x0, y - 0.45, x1, y + 0.15)], T["line"], 0.9)
        fill(L, [("rect", x0, y + 0.15, x1, y + 0.45)], T["light"], 0.85)


def gauge(L, x, y, r, face=BONE, needle=-0.6):
    cel(L, [("ell", x, y, r + 0.45, r + 0.45)], STEEL_L, form="sphere", ol=1.4, bevel=1.0, metal=0.8)
    cel(L, [("ell", x, y, r, r)], face, n=(0, 0, 1), ol=0.8, bevel=0, rim=0)
    for k in range(5):
        a = math.pi * (0.85 + k * 0.325)
        ink(L, [(x + math.cos(a) * r * 0.62, y + math.sin(a) * r * 0.62),
                (x + math.cos(a) * r * 0.85, y + math.sin(a) * r * 0.85)], 0.14, INK3, 0.8)
    ink(L, [(x, y), (x + math.cos(math.pi * 1.5 + needle) * r * 0.75, y + math.sin(math.pi * 1.5 + needle) * r * 0.75)],
        0.2, C(170, 40, 30), 1.0)
    fill(L, [("poly", [(x - r * 0.7, y - r * 0.2), (x - r * 0.2, y - r * 0.75), (x - r * 0.05, y - r * 0.6),
                       (x - r * 0.55, y - r * 0.05)])], SPEC, 0.55)


# =========================================================== palette v3 (cleaner, still dusty)
OD = C(96, 104, 66)        # olive drab
OD_D = C(70, 76, 52)
GUN = C(70, 76, 84)        # gunmetal
STEEL3 = C(124, 130, 134)
CHROME = C(178, 184, 188)
OXRED = C(140, 68, 50)     # oxide-red machine paint
YEL = C(206, 164, 64)      # safety yellow, faded
TEAL3 = C(64, 104, 108)
WOOD3 = C(132, 92, 58)
WOOD3_D = C(96, 66, 44)
PLY = C(176, 140, 96)
CANV3 = C(178, 162, 128)
CREAM = C(214, 202, 174)
RED3 = C(160, 52, 44)
TONIC3 = C(120, 190, 96)
RUBBER = C(46, 44, 48)
LEATH3 = C(110, 72, 46)


# =========================================================== shared camp
def generator(stage):
    L = Layer()
    if stage == 1:  # diesel genset on a steel skid, front-left
        cshadow(L, 22, 140.5, 21, 2.6, 0.6)
        # skid rails
        box3(L, 4.5, 136, 39.5, 140, 3, GUN, metal=0.5, rust=0.25)
        # main enclosure
        g = box3(L, 6, 112, 36, 136, 8, OD, top=OD * 1.02, rust=0.18, wear=0.4)
        vents(L, 8.5, 115, 21, 131, 7, OD)
        ink(L, [(22.5, 113), (22.5, 135)], 0.25, tone_set(OD)["line"], 0.9)
        # control panel inset
        cel(L, [("rect", 24.5, 115.5, 34, 128.5)], GUN, n=(0, 0, 1), ol=1.6, bevel=1.0, gloss=0.25)
        gauge(L, 27.4, 119.4, 1.9)
        gauge(L, 31.6, 119.4, 1.9, needle=0.5)
        for k, c in enumerate((C(232, 170, 70), C(110, 190, 120), C(60, 60, 64))):
            x = 26.6 + k * 2.5
            if k < 2:
                glow2(L, x, 124.4, 1.8, c, 0.45)
            cel(L, [("ell", x, 124.4, 0.75, 0.75)], c, form="sphere", ol=0.8, bevel=0.5, metal=0.8, rim=0, pad=4)
        cel(L, [("ell", 31.5, 127.0, 1.0, 1.0)], RED3, form="sphere", ol=1.0, bevel=0.6, metal=0.6, pad=4)
        bolts(L, [(25.2, 116.2), (33.3, 116.2), (25.2, 127.8), (33.3, 127.8)], STEEL3, 0.28)
        # door handle + stencil
        cel(L, [("rect", 21.2, 122, 22.0, 126.5)], STEEL3, form="cylv", ol=1.0, metal=0.9, bevel=0.6)
        fill(L, [("rect", 9, 132.2, 19.5, 133.4)], CREAM * 0.8, 0.55)
        # fuel tank saddle on top
        tx0, tx1, ty = 9 + g["dx"] * 0.3, 30 + g["dx"] * 0.3, 108.6
        cel(L, [("rect", tx0, ty - 2.4, tx1, ty + 2.4), ("ell", tx0, ty, 1.3, 2.4), ("ell", tx1, ty, 1.3, 2.4)], OD_D,
            form="cylh", ol=2.2, metal=0.35, rust=0.2)
        cel(L, [("ell", tx1 - 3, ty - 2.3, 1.2, 0.5)], STEEL3, n=(0, -1, 0.3), ol=1.0, metal=0.8, bevel=0.5)
        for xs in (tx0 + 3, tx1 - 6):
            cel(L, [("rect", xs, ty - 2.6, xs + 1.0, ty + 2.6)], GUN, form="cylh", ol=0.9, metal=0.6, bevel=0.5)
        # exhaust: pipe + muffler + rain cap
        cel(L, [("rect", 32.2, 101.5, 34.0, 110.2)], GUN, form="cylv", ol=1.8, metal=0.8, rust=0.45)
        cel(L, [("rect", 31.2, 104.5, 35.0, 108.0)], GUN * 0.9, form="cylv", ol=1.6, metal=0.8, rust=0.5)
        cel(L, [("poly", [(31.4, 101.8), (34.9, 100.6), (35.2, 101.3), (31.6, 102.6)])], STEEL3, ol=1.0, metal=0.9,
            bevel=0.5)
        soft(L, [("ell", 34.5, 97.5, 1.8, 1.6), ("ell", 36.5, 93.5, 2.6, 2.0)], C(150, 138, 128), 0.22, 6)
        # power cable snaking off to the wall
        cel(L, [("line", sag(37, 131, 46, 137, 2.0, 10) + [(50, 134), (52, 126)], 0.75)], RUBBER, form="cylh",
            ol=1.0, bevel=1, rim=0.6)
    elif stage == 3:  # string lights draped between the ribs
        strands = [((6, 46), (62, 31), 6), ((62, 31), (120, 27), 5), ((120, 27), (178, 31), 5),
                   ((178, 31), (234, 46), 6), ((32, 18), (100, 11), 5), ((140, 11), (208, 18), 5)]
        for (a, b, dip) in strands:
            pts = sag(a[0], a[1], b[0], b[1], dip, 24)
            ink(L, pts, 0.42, C(30, 24, 26), 1.0)
            for t in np.linspace(0.07, 0.93, 7):
                i = t * (len(pts) - 1)
                q0, q1 = pts[int(i)], pts[min(len(pts) - 1, int(i) + 1)]
                fr = i - int(i)
                x, y = q0[0] + (q1[0] - q0[0]) * fr, q0[1] + (q1[1] - q0[1]) * fr
                cel(L, [("rect", x - 0.38, y, x + 0.38, y + 0.9)], GUN, form="cylv", ol=0.8, bevel=0.4, metal=0.5, rim=0,
                    pad=4)
                bulb(L, x, y + 1.9, 0.72, BULB, 3.0, 0.30)
        soft(L, [("ell", 60, 96, 40, 3)], C(255, 190, 110), 0.10, 6)
        soft(L, [("ell", 180, 96, 40, 3)], C(255, 190, 110), 0.10, 6)
    elif stage == 5:  # caged industrial floodlights hung off the ribs
        for fx, fy in ((84, 22), (178, 22)):
            ink(L, [(fx - 3, 6), (fx, fy - 4.5)], 0.25, C(40, 36, 40), 1.0)
            ink(L, [(fx + 3, 6), (fx, fy - 4.5)], 0.25, C(40, 36, 40), 1.0)
            soft(L, [("poly", [(fx - 4, fy + 2), (fx + 4, fy + 2), (fx + 21, 100), (fx - 19, 100)])],
                 C(255, 214, 156), 0.13, 7)
            soft(L, [("ell", fx + 1, 101, 22, 3.5)], C(255, 200, 130), 0.16, 5)
            cel(L, [("poly", [(fx - 1.6, fy - 5), (fx + 1.6, fy - 5), (fx + 2, fy - 2.6), (fx - 2, fy - 2.6)])], GUN,
                ol=1.4, metal=0.7, bevel=0.6)
            cel(L, [("poly", [(fx - 3.4, fy - 2.8), (fx + 3.4, fy - 2.8), (fx + 5.6, fy + 1.6), (fx - 5.6, fy + 1.6)])],
                YEL * 0.85, form="cylv", ol=2.0, metal=0.5, bevel=1.4, wear=0.4)
            glow2(L, fx, fy + 2.4, 6, BULB, 0.55)
            cel(L, [("ell", fx, fy + 1.8, 5.4, 1.4)], C(255, 236, 190), n=(0, 0.9, 0.4), ol=1.2, bevel=0, rim=0,
                line=C(150, 110, 60))
            for k in (-3.4, -1.1, 1.1, 3.4):
                ink(L, [(fx + k * 0.9, fy + 0.6), (fx + k, fy + 3.0)], 0.22, C(40, 36, 40), 1.0)
            ink(L, [(fx - 4.6, fy + 2.2), (fx + 4.6, fy + 2.2)], 0.22, C(40, 36, 40), 1.0)
    return L


MAST_X = 236.0


def radio_tower(stage):
    L = Layer()
    if stage == 1:  # radio desk, front-right
        cshadow(L, 221, 140.8, 17, 2.4, 0.55)
        # desk: top slab in 3/4, two legs + rail
        for lx in (207.5, 233.0):
            cel(L, [("rect", lx, 121, lx + 2.0, 140.5)], WOOD3_D, form="cylv", ol=1.8, bevel=0.8)
        cel(L, [("rect", 208, 131, 234.5, 132.6)], WOOD3_D, form="cylh", ol=1.2, bevel=0.6)
        box3(L, 205.5, 118.5, 237, 121.5, 6, WOOD3, top=PLY)
        wood_grain(L, 207, 115, 236, 118, WOOD3_D, 2)
        # the set: steel case with rounded corners in 3/4
        box3(L, 210.5, 106.5, 229.5, 118, 5, GUN, top=GUN * 1.05, metal=0.3, wear=0.35)
        cel(L, [("rect", 212, 108.2, 221, 113.4)], C(230, 168, 80), n=(0, 0, 1), ol=1.2, bevel=0, rim=0, gloss=0.5)
        glow2(L, 216.5, 110.8, 4, AMBER, 0.32)
        for k in range(7):
            ink(L, [(213 + k * 1.2, 109.4), (213 + k * 1.2, 110.4 + (k % 2) * 0.6)], 0.13, C(80, 40, 20), 0.9)
        ink(L, [(217.6, 113.2), (218.6, 108.6)], 0.2, RED3, 1.0)
        # speaker grille (round holes)
        cel(L, [("ell", 225.3, 111.6, 3.0, 3.0)], C(54, 56, 62), n=(0, 0, 1), ol=1.2, bevel=0.5, rim=0)
        for ix in range(-2, 3):
            for iy in range(-2, 3):
                if ix * ix + iy * iy <= 5:
                    fill(L, [("ell", 225.3 + ix * 1.05, 111.6 + iy * 1.05, 0.3, 0.3)], C(18, 16, 20), 1.0)
        for kx in (213.4, 216.8, 220.2):
            cel(L, [("ell", kx, 116.0, 1.05, 1.05)], C(210, 200, 182), form="sphere", ol=1.0, bevel=0.6, metal=0.7)
            ink(L, [(kx, 116.0), (kx + 0.5, 115.3)], 0.14, INK3, 0.9)
        # mic on a stand + coiled cord
        cel(L, [("ell", 232.6, 118.1, 2.1, 0.6)], GUN, n=(0, -0.8, 0.6), ol=1.2, metal=0.6)
        cel(L, [("line", [(232.6, 118), (232.9, 112.5)], 0.4)], CHROME, form="cylv", ol=0.9, metal=1, bevel=0.4)
        cel(L, [("rect", 231.6, 108.8, 234.2, 112.8), ("ell", 232.9, 108.8, 1.3, 0.8), ("ell", 232.9, 112.8, 1.3, 0.8)],
            CHROME * 0.8, form="cylv", ol=1.3, metal=1.0, bevel=0.6)
        for k in range(4):
            ink(L, [(231.8, 109.4 + k * 0.85), (234.0, 109.4 + k * 0.85)], 0.12, INK3, 0.8)
        ink(L, [(229.6, 115.5), (230.6, 117.4), (231.4, 116.2), (232.2, 118.0)], 0.22, RUBBER, 1)
        # headphones resting on the desk
        cel(L, [("line", sag(207.6, 117.6, 213.0, 117.6, -2.4, 10), 0.45)], GUN, form="flat", ol=1.0, metal=0.5)
        for hx in (207.6, 213.0):
            cel(L, [("ell", hx, 117.8, 1.2, 0.9)], RUBBER, form="sphere", ol=1.0, bevel=0.6, metal=0.4)
        # whip antenna
        cel(L, [("line", [(228.6, 106.6), (230.5, 96)], 0.35)], CHROME, form="flat", ol=0.8, metal=1, bevel=0.3)
        cel(L, [("ell", 230.55, 95.8, 0.4, 0.4)], CHROME, form="sphere", ol=0.6, metal=1, bevel=0.3)
    elif stage == 3:  # lattice mast at the far right, up through the roof
        x0, x1 = MAST_X - 2.6, MAST_X + 2.6
        for xa in (x0, x1):
            cel(L, [("line", [(xa, 121), (xa + (MAST_X - xa) * 0.3, -2)], 0.55)], GUN, form="cylv", ol=1.4, metal=0.7,
                bevel=0.5, rust=0.2)
        y = 118.0
        k = 0
        while y > 0:
            sh = 1 - y / 121.0
            ln = x0 + 2.6 * 0.3 * sh
            rn = x1 - 2.6 * 0.3 * sh
            ink(L, [(ln, y), (rn, y - 5.2)] if k % 2 == 0 else [(rn, y), (ln, y - 5.2)], 0.24, C(40, 42, 48), 1)
            ink(L, [(ln, y), (rn, y)], 0.3, C(40, 42, 48), 1)
            hline(L, [(ln + 0.2, y - 0.25), (rn - 0.2, y - 0.25)], 0.1, C(190, 180, 160), 0.6)
            y -= 5.2
            k += 1
        # feeder cable down to the radio
        cel(L, [("line", [(MAST_X - 2, 112), (231, 114), (229.5, 117)], 0.45)], RUBBER, form="flat", ol=0.8, bevel=0.5)
        # guy wire off toward the roof
        ink(L, [(MAST_X - 1.5, 40), (206, 4)], 0.12, C(120, 112, 104), 0.7)
    elif stage == 5:  # dish on the mast + blinking red beacon
        dx, dy = MAST_X - 9.5, 34.0
        cel(L, [("line", [(dx + 2.5, dy), (MAST_X - 1, dy - 1.5)], 0.6)], GUN, form="cylh", ol=1.2, metal=0.7)
        # parabolic dish, three-quarter: lit outside rim + shaded bowl + feed horn on struts
        cel(L, [("ell", dx, dy, 3.8, 7.4)], CREAM * 0.92, form="sphere", ol=2.2, bevel=1.6, metal=0.3, wear=0.3)
        cel(L, [("ell", dx - 0.6, dy, 2.8, 6.2)], CREAM * 0.62, form="sphere", flip=True, ol=0, bevel=0, rim=0)
        for (sy_) in (-5.2, 5.2):
            ink(L, [(dx - 0.6, dy + sy_), (dx - 5.2, dy)], 0.22, C(50, 50, 56), 1)
        cel(L, [("rect", dx - 6.4, dy - 0.9, dx - 4.6, dy + 0.9)], GUN, form="cylh", ol=1.1, metal=0.8, bevel=0.4)
        ink(L, [(dx + 2.6, dy - 4), (dx + 3.4, dy + 1)], 0.16, SPEC, 0.6)
        by = 2.8
        cel(L, [("rect", MAST_X - 1.4, by + 1.2, MAST_X + 1.4, by + 3.0)], GUN, ol=1.2, metal=0.6)
        glow2(L, MAST_X, by, 5, C(240, 70, 50), 0.55)
        cel(L, [("ell", MAST_X, by, 1.4, 1.4)], C(236, 92, 70), form="dome", ol=1.2, bevel=0.6, metal=0.8, rim=0)
    return L


def scrap_press(stage):
    L = Layer()
    if stage == 1:  # salvage pile: tyre, sheet metal, pipe, hubcap, gears
        cshadow(L, 87, 145, 13.5, 2.4, 0.6)
        cel(L, [("poly", [(74.5, 146.2), (78, 138.5), (84, 133.5), (91, 134.5), (97, 139.5), (100, 146.2)])],
            C(84, 74, 66), n=(0, -0.5, 0.9), ol=2.2, bevel=2.5, rust=0.45)
        # corrugated sheet leaning
        cel(L, [("poly", [(84, 146), (86.5, 132), (95.5, 134.5), (93.5, 146.2)])], STEEL3, n=(0.4, -0.2, 0.9),
            ol=2.0, bevel=1, metal=0.4, rust=0.4)
        for k in range(4):
            xa = 86.5 + k * 2.25
            ink(L, [(xa, 133 + k * 0.6), (xa - 1.6, 146)], 0.2, tone_set(STEEL3)["line"], 0.7)
        # pipe
        cel(L, [("line", [(76, 140.5), (91, 137.5)], 1.3)], OXRED * 0.8, form="cylh", ol=1.6, metal=0.5, rust=0.4)
        cel(L, [("ell", 91, 137.5, 0.6, 1.3)], C(30, 24, 22), n=(1, 0, 0.3), ol=0.8, bevel=0)
        # gear
        gx, gy, gr = 81, 143.5, 2.6
        teeth = []
        for i in range(24):
            a = i / 24 * 2 * math.pi
            rr = gr if (i // 2) % 2 == 0 else gr * 0.8
            teeth.append((gx + math.cos(a) * rr, gy + math.sin(a) * rr * 0.75))
        cel(L, [("poly", teeth), ("-ell", gx, gy, 0.8, 0.6)], STEEL3, n=(0, -0.4, 0.9), ol=1.6, metal=0.6, rust=0.3)
        # tyre leaning on the pile
        cel(L, [("ell", 96.5, 140.4, 3.6, 5.2), ("-ell", 96.8, 140.4, 1.6, 2.6)], RUBBER, form="sphere", ol=2.0,
            bevel=2.4, metal=0.25)
        for k in range(6):
            a = -1.2 + k * 0.45
            ink(L, [(96.5 + math.cos(a) * 3.0, 140.4 + math.sin(a) * 4.4),
                    (96.5 + math.cos(a) * 3.5, 140.4 + math.sin(a) * 5.0)], 0.16, C(20, 18, 22), 0.9)
        # hubcap
        cel(L, [("ell", 89, 143.8, 2.4, 1.2)], CHROME, form="sphere", ol=1.4, metal=1.0, bevel=0.8)
    elif stage == 3:  # H-frame hydraulic press
        cshadow(L, 61, 137.6, 15, 2.2, 0.6)
        box3(L, 46.5, 131.5, 75.5, 137, 4, GUN, metal=0.4, rust=0.25)
        for cx in (49.0, 70.0):
            box3(L, cx, 103, cx + 4.2, 131.5, 2.4, OXRED, wear=0.45, rust=0.15)
        box3(L, 45.5, 99.5, 77.5, 105.5, 3.5, OXRED, wear=0.4, rust=0.15)
        st = shape([("rect", 46, 103.0, 77, 104.8)])
        fill(L, [("rect", 46, 103.0, 77, 104.8)], YEL, 0.95)
        stripes(L, st, C(40, 34, 30), 1.2, 1.0, 0.85)
        # hydraulic cylinder + chrome ram
        cel(L, [("rect", 57.8, 105.5, 64.2, 111)], GUN, form="cylv", ol=2.0, metal=0.8)
        cel(L, [("rect", 59.6, 111, 62.4, 117.5)], CHROME, form="cylv", ol=1.6, metal=1.0)
        box3(L, 53, 117.5, 69, 121.5, 2.5, STEEL3, metal=0.6, wear=0.3)
        # crushed car door on the bed
        cel(L, [("poly", [(53.5, 131.5), (54.5, 127.5), (60, 128.6), (66, 126.8), (69, 128.2), (68.5, 131.5)])], TEAL3,
            n=(0, -0.6, 0.8), ol=1.8, metal=0.4, rust=0.4)
        ink(L, [(56, 129.6), (60, 130.4), (65, 128.6)], 0.2, tone_set(TEAL3)["line"], 0.9)
        # hoses + control box with a red lever
        cel(L, [("line", [(64.2, 107), (68, 109), (71, 108)], 0.55)], RUBBER, form="flat", ol=1.0, bevel=0.5)
        cel(L, [("line", [(77.3, 110), (80.5, 112), (80.4, 116)], 0.55)], RUBBER, form="flat", ol=1.0, bevel=0.5)
        box3(L, 77, 116, 83, 123.5, 2, OD_D, wear=0.4)
        cel(L, [("line", [(80, 116), (81.5, 111.8)], 0.4)], CHROME, form="flat", ol=0.9, metal=1, bevel=0.3)
        cel(L, [("ell", 81.6, 111.6, 0.85, 0.85)], RED3, form="sphere", ol=0.9, metal=0.7, bevel=0.5)
        bolts(L, [(47.6, 101.4), (75.4, 101.4), (51.1, 129), (72.1, 129)], STEEL3, 0.33)
        # stencil plate
        fill(L, [("rect", 49.6, 107.5, 52.6, 108.6)], CREAM, 0.6)
    elif stage == 5:  # baled cubes on a pallet in front of the press
        cshadow(L, 60.5, 147.2, 11, 1.8, 0.6)
        box3(L, 50, 144.2, 71, 147.2, 2.2, WOOD3, top=PLY)
        for x in (52, 59.5, 67):
            fill(L, [("rect", x, 145.0, x + 2, 146.6)], C(36, 28, 24), 0.9)
        for (x, y, c) in ((51, 138.3, TEAL3 * 0.9), (60, 138.6, OXRED * 0.85), (55.6, 132.6, C(100, 104, 108))):
            box3(L, x, y, x + 8.4, y + 6, 3.6, c, metal=0.35, rust=0.35, wear=0.5)
            for k in range(3):
                fill(L, [("poly", [(x + 1 + k * 2.6, y + 0.6), (x + 2.2 + k * 2.6, y + 0.6), (x + 1.6 + k * 2.6, y + 5.4),
                                   (x + 0.8 + k * 2.6, y + 5.4)])], tone_set(c)["shadow"], 0.55)
            ink(L, [(x + 0.6, y + 1.6), (x + 3, y + 2.6), (x + 5.4, y + 1.4), (x + 7.8, y + 2.4)], 0.18,
                tone_set(c)["line"], 0.9)
            ink(L, [(x + 0.6, y + 4.0), (x + 3.4, y + 4.8), (x + 7.6, y + 3.8)], 0.18, tone_set(c)["line"], 0.9)
    return L


def ammo_bench(stage):
    L = Layer()
    if stage == 1:  # heavy workbench with pegboard, vice, reloading press, lamp
        cshadow(L, 178, 140.8, 23, 2.6, 0.55)
        # pegboard back panel
        cel(L, [("rect", 158.5, 94.8, 198.5, 109.5)], PLY * 0.86, n=(0, 0, 1), ol=2.0, bevel=0.8)
        for ix in range(20):
            for iy in range(7):
                fill(L, [("ell", 160 + ix * 1.95, 96.4 + iy * 1.95, 0.22, 0.22)], C(70, 48, 32), 0.75)
        for lx in (156.5, 198.5):
            cel(L, [("rect", lx, 94.5, lx + 1.8, 113.5)], WOOD3_D, form="cylv", ol=1.4, bevel=0.6)
        # legs + stretcher
        for lx in (158, 195.5):
            cel(L, [("rect", lx, 116, lx + 2.6, 140.5)], WOOD3_D, form="cylv", ol=1.8, bevel=0.8)
        cel(L, [("rect", 159, 130.5, 197, 132.2)], WOOD3_D, form="cylh", ol=1.2, bevel=0.6)
        # top slab
        box3(L, 155.5, 113.2, 201, 117, 5, WOOD3, top=PLY)
        wood_grain(L, 157, 109.5, 200, 112.8, WOOD3_D, 2)
        wood_grain(L, 157, 113.8, 200, 116.4, WOOD3_D, 2)
        # vice
        box3(L, 160.5, 108.6, 166, 113.2, 2, TEAL3, metal=0.5, wear=0.5)
        cel(L, [("rect", 159.6, 107.2, 167, 108.8)], GUN, form="cylh", ol=1.2, metal=0.7)
        cel(L, [("line", [(158.3, 111.4), (168.2, 111.4)], 0.42)], CHROME, form="cylh", ol=0.9, metal=1.0, bevel=0.3)
        # reloading press (O-frame) with handle
        cel(L, [("rect", 175, 106, 178.4, 113.2)], OXRED, form="cylv", ol=1.6, metal=0.6, wear=0.3)
        cel(L, [("ell", 176.7, 105.5, 2.4, 1.6), ("-ell", 176.7, 105.5, 1.0, 0.7)], OXRED, form="sphere", ol=1.5,
            metal=0.6)
        cel(L, [("line", [(178, 104.6), (183.5, 101.2)], 0.38)], CHROME, form="flat", ol=0.9, metal=1, bevel=0.3)
        cel(L, [("ell", 183.8, 101.0, 0.9, 0.9)], RUBBER, form="sphere", ol=0.9, metal=0.6, bevel=0.5)
        # casings tray
        box3(L, 185.5, 111.6, 195.5, 113.2, 2.4, GUN, metal=0.4)
        for k in range(6):
            x = 186.4 + k * 1.5
            cel(L, [("rect", x, 108.6, x + 1.0, 111.4), ("ell", x + 0.5, 108.6, 0.5, 0.3)], BRASS * 1.1, form="cylv",
                ol=0.8, metal=1.0, bevel=0.3, pad=4)
        # desk lamp pooling light on the work
        cel(L, [("line", [(197.6, 113), (199, 105.2), (194.8, 101.8)], 0.38)], GUN, form="flat", ol=0.9, metal=0.6)
        soft(L, [("poly", [(191.5, 102.6), (196, 101.4), (193, 113), (181, 113)])], BULB, 0.18, 3)
        cel(L, [("poly", [(190.6, 101.4), (195.2, 99.6), (196.6, 102.4), (192.2, 103.6)])], OD, ol=1.4, metal=0.6,
            bevel=0.8)
        glow2(L, 193.6, 103.2, 2.5, AMBER, 0.45)
    elif stage == 3:  # ammo crates stacked under the bench
        cshadow(L, 177, 141, 13, 2.0, 0.5)
        for (x, y, w, h, c) in ((161.5, 133, 14, 7.5, OD), (176.5, 134.5, 12, 6, OD_D), (163, 125.6, 11, 6.6, OD_D)):
            box3(L, x, y, x + w, y + h, 3.2, c, wear=0.4, rust=0.1)
            fill(L, [("rect", x + 0.3, y + h * 0.42, x + w - 0.3, y + h * 0.56)], tone_set(c)["shadow"], 0.85)
            fill(L, [("rect", x + w * 0.22, y + 1.0, x + w * 0.62, y + 2.0)], C(214, 196, 140), 0.55)
            for hx in (x + 0.8, x + w - 1.6):
                cel(L, [("rect", hx, y + 0.6, hx + 0.8, y + h - 0.6)], GUN, form="cylv", ol=0.8, metal=0.7, bevel=0.3,
                    pad=4)
        # a belt of rounds draped over the top crate
        pts = sag(163.5, 125.2, 172.5, 125.2, 1.6, 10)
        for (x, y) in pts[1:-1]:
            cel(L, [("rect", x - 0.32, y - 1.3, x + 0.32, y + 0.2), ("ell", x, y - 1.3, 0.32, 0.2)], BRASS * 1.1,
                form="cylv", ol=0.7, metal=1.0, bevel=0.2, pad=4)
        ink(L, pts, 0.28, C(50, 44, 40), 1)
    elif stage == 5:  # tools on the pegboard + special-ammo cans + a drum
        # wrench
        cel(L, [("line", [(160.5, 97.6), (167.4, 100.6)], 0.55)], CHROME, form="cylh", ol=1.1, metal=1.0, bevel=0.3)
        cel(L, [("ell", 160.2, 97.4, 1.1, 1.1), ("-poly", [(159.0, 96.4), (160.3, 97.2), (159.6, 96.0)])], CHROME,
            form="sphere", ol=1.1, metal=1.0, bevel=0.4)
        # hammer
        cel(L, [("line", [(169.8, 96.6), (169.8, 103.0)], 0.6)], WOOD3, form="cylv", ol=1.1, bevel=0.3)
        cel(L, [("rect", 168, 95.6, 171.8, 97.4)], GUN, form="cylh", ol=1.1, metal=0.9, bevel=0.3)
        # cans on a shelf
        cel(L, [("rect", 172.5, 104.4, 197, 105.6)], WOOD3_D, form="cylh", ol=1.2, bevel=0.5)
        cans = [C(146, 70, 54), C(84, 120, 132), C(184, 148, 76), C(150, 154, 154)]
        for x, c in zip((173.5, 179.4, 185.3, 191.2), cans):
            drum(L, x + 2.2, 100.0, 104.3, 2.2, c, ry=0.55, ol=1.6, metal=0.6, wear=0.3)
            fill(L, [("rect", x + 0.2, 101.6, x + 4.2, 102.6)], tone_set(c)["deep"], 0.8)
        # drum of special rounds by the leg
        cshadow(L, 192.5, 141, 4.6, 1.0, 0.5)
        drum(L, 192.5, 133.5, 140.4, 4.0, C(90, 140, 160), ry=1.2, metal=0.5, wear=0.3)
        fill(L, [("rect", 188.5, 136.0, 196.5, 137.2)], C(30, 30, 36), 0.85)
        pts = sag(195.5, 134.5, 199.5, 140.4, -1, 6)
        for (x, y) in pts:
            cel(L, [("ell", x, y, 0.42, 0.42)], BRASS, form="sphere", ol=0.6, metal=1, bevel=0.2, pad=4)
    return L


# =========================================================== survivor corners
HEROES = ["ash_rook", "vesper_thorn", "pebble", "bolt_juno", "sister_cinder", "quill_marrow", "nyx_caldera",
          "helm_wisp"]
BOOTH = {"ash_rook": 14, "vesper_thorn": 35, "pebble": 56, "bolt_juno": 78,
         "sister_cinder": 162, "quill_marrow": 184, "nyx_caldera": 205, "helm_wisp": 226}
HERO_ACCENT = {"ash_rook": C(150, 60, 48), "vesper_thorn": C(80, 112, 70), "pebble": C(120, 112, 100),
               "bolt_juno": C(70, 110, 130), "sister_cinder": C(140, 56, 52), "quill_marrow": C(140, 112, 70),
               "nyx_caldera": C(76, 64, 96), "helm_wisp": C(96, 108, 76)}
BY = 93.0


def wall_shadow(L, cx, top=0.0, bottom=BY + 0.2, strength=0.38):
    """Soft drop shadow of a layer cast on the back wall, away from the door light."""
    sg = 1.0 if cx < VPX else -1.0
    dx, dy = int(-sg * 0.9 * S), int(0.9 * S)
    sh = np.roll(np.roll(L.a, dy, 0), dx, 1)
    sh = ndi.gaussian_filter(sh, 2.5) * strength
    rows = np.zeros((H, 1), F)
    rows[int(top * S):int(bottom * S)] = 1
    sh = sh * rows
    N = Layer()
    N.blend(sh, 0, 0, C(10, 8, 20) + np.zeros((H, W, 3), F))
    N.blend(L.a, 0, 0, L.rgb)
    return N


def station(hero, stage):
    return wall_shadow(_station(hero, stage), BOOTH[hero])


def _station(hero, stage):
    """Each corner is a tidy zone on the back wall: a rug on the floor (r1), a floor piece (r1),
    a wall piece (r3) and a centre-piece (r5), all inside m +/- 9."""
    L = Layer()
    m = BOOTH[hero]
    acc = HERO_ACCENT[hero]

    def rug():
        cel(L, [("poly", [(m - 9.0, BY + 1.8), (m + 9.0, BY + 1.8), (m + 8.0, BY - 0.4), (m - 8.0, BY - 0.4)])],
            acc * 0.62, n=(0, -0.9, 0.45), ol=0.9, bevel=0, rim=0, alpha=0.75, grad=0)
        ink(L, [(m - 8.4, BY + 1.1), (m + 8.4, BY + 1.1)], 0.12, CREAM * 0.7, 0.35)

    def table(x0, x1, top, col=WOOD3):
        cshadow(L, (x0 + x1) / 2, BY + 0.4, (x1 - x0) * 0.55, 1.0, 0.45)
        for lx in (x0 + 0.8, x1 - 2.0):
            cel(L, [("rect", lx, top + 1.6, lx + 1.2, BY)], col * 0.8, form="cylv", ol=1.4, bevel=0.5)
        box3(L, x0, top, x1, top + 1.8, 2.6, col, top=col * 1.08 + 0.03)

    def shelf(x0, x1, y):
        cel(L, [("rect", x0, y, x1, y + 1.2)], WOOD3_D, form="cylh", ol=1.3, bevel=0.5)
        for bx in (x0 + 1.2, x1 - 2.0):
            cel(L, [("poly", [(bx, y + 1.2), (bx + 0.8, y + 1.2), (bx + 0.8, y + 3.2)])], GUN, ol=0.9, metal=0.6,
                bevel=0.2, pad=4)

    if hero == "ash_rook":
        if stage == 1:  # A-frame rack holding her launcher (left half of the corner)
            rug()
            r0 = m - 3.5
            for (a, b) in (((r0 - 5.5, BY), (r0 - 4.0, BY - 21)), ((r0 + 5.5, BY), (r0 + 4.0, BY - 21))):
                cel(L, [("line", [a, b], 0.85)], WOOD3_D, form="cylv", ol=1.3, bevel=0.5)
            for y in (BY - 8.5, BY - 18):
                cel(L, [("line", [(r0 - 5.2, y), (r0 + 5.2, y)], 0.75)], WOOD3_D, form="cylh", ol=1.2, bevel=0.4)
            cel(L, [("rect", r0 - 6.5, BY - 15.6, r0 + 7.5, BY - 12.0), ("ell", r0 - 6.5, BY - 13.8, 0.7, 1.8)], OD,
                form="cylh", ol=1.8, metal=0.35, wear=0.4)
            cel(L, [("rect", r0 + 7.2, BY - 16.2, r0 + 9.4, BY - 11.4)], GUN, form="cylh", ol=1.4, metal=0.8)
            cel(L, [("ell", r0 + 9.4, BY - 13.8, 0.6, 2.2)], C(24, 20, 20), n=(1, 0, 0.4), ol=0.8, bevel=0)
            cel(L, [("rect", r0 - 0.6, BY - 12.0, r0 + 1.2, BY - 9.2)], RUBBER, n=(0, 0, 1), ol=1.0, bevel=0.4)
            cel(L, [("rect", r0 - 3.4, BY - 18.2, r0 + 0.2, BY - 15.6)], GUN, ol=1.0, metal=0.8, bevel=0.4)
            fill(L, [("rect", r0 + 2.6, BY - 15.0, r0 + 6.0, BY - 14.0)], YEL, 0.75)
        elif stage == 3:  # open crate of rockets on the floor (right half)
            cshadow(L, m + 4.5, BY + 0.6, 5, 1.0, 0.5)
            box3(L, m + 0.8, BY - 4.4, m + 9.0, BY + 0.6, 2.2, OD_D, wear=0.4)
            for k in range(3):
                y = BY - 5.2 - k * 1.3
                x = m + 1.2 + k * 0.6
                cel(L, [("rect", x, y - 0.6, x + 5.6, y + 0.6)], OD, form="cylh", ol=0.9, metal=0.3, bevel=0.3, pad=5)
                cel(L, [("poly", [(x + 5.6, y - 0.65), (x + 7.4, y), (x + 5.6, y + 0.65)])], OXRED, form="cylh", ol=0.9,
                    metal=0.5, bevel=0.3, pad=5)
            fill(L, [("rect", m + 2, BY - 2.4, m + 6.5, BY - 1.6)], C(214, 196, 140), 0.55)
        elif stage == 5:  # spare launcher on wall pegs + a hazard sign
            for x in (m - 7.5, m + 6.5):
                cel(L, [("rect", x, BY - 31, x + 1.2, BY - 26.6)], GUN, ol=0.9, metal=0.6, bevel=0.3)
            cel(L, [("rect", m - 9, BY - 30.2, m + 9, BY - 26.8), ("ell", m + 9, BY - 28.5, 0.6, 1.7)], GUN,
                form="cylh", ol=1.8, metal=0.7, wear=0.3)
            fill(L, [("rect", m - 3, BY - 29.8, m - 1.6, BY - 27.2)], YEL, 0.75)
            fill(L, [("rect", m - 1.0, BY - 29.8, m + 0.4, BY - 27.2)], YEL, 0.75)
            cel(L, [("poly", [(m + 5.5, BY - 24.2), (m + 8.8, BY - 18.6), (m + 2.2, BY - 18.6)])], YEL, n=(0, 0, 1),
                ol=1.3, bevel=0, wear=0.3)
            fill(L, [("rect", m + 5.2, BY - 22.4, m + 5.8, BY - 20.4)], C(30, 24, 22), 1)
            fill(L, [("ell", m + 5.5, BY - 19.6, 0.32, 0.32)], C(30, 24, 22), 1)
    elif hero == "vesper_thorn":
        if stage == 1:  # bench with the long vial rifle on a bipod
            rug()
            table(m - 8.5, m + 8.5, BY - 9.5)
            cel(L, [("poly", [(m - 8, BY - 12.6), (m + 9.6, BY - 13.6), (m + 9.6, BY - 12.6), (m - 8, BY - 11.6)])],
                GUN, ol=1.3, metal=0.8, bevel=0.3)
            cel(L, [("poly", [(m - 9.5, BY - 12.4), (m - 3.4, BY - 13.2), (m - 3.0, BY - 11.0), (m - 9.0, BY - 10.0)])],
                WOOD3, ol=1.4, bevel=0.6)
            cel(L, [("rect", m - 2.2, BY - 15.6, m + 3.2, BY - 13.6)], RUBBER, form="cylh", ol=1.1, metal=0.7)
            cel(L, [("ell", m + 3.2, BY - 14.6, 0.4, 1.0)], C(150, 210, 230), n=(1, 0, 0.5), ol=0.6, bevel=0, gloss=1)
            for k in (-1, 1):
                ink(L, [(m + 7, BY - 12.6), (m + 7 + k * 1.2, BY - 9.6)], 0.2, INK3, 1)
            cel(L, [("rect", m + 0.6, BY - 12.4, m + 2.0, BY - 10.6)], TONIC3, form="cylv", ol=0.8, gloss=0.6,
                metal=0.6)
        elif stage == 3:  # lantern on a bracket + a rack of tonic vials
            ink(L, [(m - 6.5, BY - 30), (m - 3.5, BY - 30), (m - 3.5, BY - 28)], 0.3, C(40, 36, 40), 1)
            glow2(L, m - 3.5, BY - 25, 5.0, AMBER, 0.4)
            cel(L, [("poly", [(m - 5.4, BY - 28), (m - 1.6, BY - 28), (m - 1.2, BY - 26.8), (m - 5.8, BY - 26.8)])],
                BRASS, ol=1.1, metal=0.8, bevel=0.3)
            cel(L, [("rect", m - 5.2, BY - 26.8, m - 1.8, BY - 22.6)], BULB, n=(0, 0, 1), ol=1.1, bevel=0, rim=0,
                line=C(120, 80, 30), gloss=0.5)
            cel(L, [("rect", m - 5.8, BY - 22.6, m - 1.2, BY - 21.6)], BRASS, form="cylh", ol=1.0, metal=0.8, bevel=0.3)
            shelf(m + 0.5, m + 9.5, BY - 19)
            for k in range(4):
                x = m + 1.3 + k * 2.1
                cel(L, [("rect", x, BY - 22.6, x + 1.5, BY - 19), ("ell", x + 0.75, BY - 19, 0.75, 0.3)],
                    TONIC3 * (0.9 + 0.1 * (k % 2)), form="cylv", ol=0.9, metal=0.5, gloss=0.4, pad=4)
                cel(L, [("rect", x + 0.3, BY - 23.6, x + 1.2, BY - 22.6)], LEATH3, ol=0.6, bevel=0.2, pad=4)
        elif stage == 5:  # paper target + glowing tonic crate
            cel(L, [("rect", m - 8.6, BY - 34, m - 0.6, BY - 24)], CREAM, n=(0, 0, 1), ol=1.4, bevel=0.6)
            ink(L, [(m - 6.5, BY - 34), (m - 6.5, BY - 35)], 0.2, INK3, 1)
            for r_ in (3.4, 2.2, 1.0):
                ink(L, [(m - 4.6 + math.cos(t) * r_, BY - 29 + math.sin(t) * r_) for t in np.linspace(0, 2 * math.pi, 28)],
                    0.22, RED3, 0.95)
            for (hx, hy) in ((-4.2, -29.4), (-5.0, -28.2), (-3.6, -30.4), (-2.0, -27.6)):
                fill(L, [("ell", m + hx, BY + hy, 0.32, 0.32)], C(24, 18, 16), 1)
            glow2(L, m + 5.4, BY - 4.5, 5.5, TONIC3, 0.32)
            cshadow(L, m + 5, BY + 0.6, 5, 1.0, 0.5)
            box3(L, m + 1.2, BY - 4.6, m + 8.8, BY + 0.6, 2.2, OD_D, wear=0.4)
            for k in range(3):
                x = m + 2.2 + k * 2.2
                cel(L, [("rect", x, BY - 7.6, x + 1.5, BY - 4.6), ("ell", x + 0.75, BY - 7.6, 0.75, 0.3)], TONIC3,
                    form="cylv", ol=0.8, metal=0.5, gloss=0.4, pad=4)
    elif hero == "pebble":
        if stage == 1:  # anvil on a stump (right half)
            rug()
            a0 = m + 3.0
            cshadow(L, a0, BY + 0.5, 5, 1.0, 0.5)
            drum(L, a0, BY - 7.0, BY, 3.2, WOOD3_D, ry=0.9, top=PLY)
            for r_ in (2.0, 1.1):
                ink(L, [(a0 + math.cos(t) * r_, BY - 7.0 + math.sin(t) * r_ * 0.28) for t in np.linspace(0, 6.3, 20)],
                    0.12, WOOD3_D, 0.6)
            cel(L, [("poly", [(a0 - 6.0, BY - 11.8), (a0 + 3.8, BY - 11.8), (a0 + 6.0, BY - 11.0), (a0 + 3.4, BY - 10.0),
                              (a0 + 2.0, BY - 10.0), (a0 + 2.2, BY - 7.6), (a0 - 2.8, BY - 7.6), (a0 - 2.4, BY - 10.0),
                              (a0 - 4.4, BY - 10.6)])], GUN * 0.9, ol=2.0, metal=0.8, bevel=1.2)
            hline(L, [(a0 - 5.0, BY - 11.4), (a0 + 3.6, BY - 11.4)], 0.16, SPEC, 0.7)
        elif stage == 3:  # the maul leaning on the wall, far right
            cel(L, [("line", [(m + 7.6, BY - 0.6), (m + 8.6, BY - 22)], 0.8)], WOOD3, form="cylv", ol=1.4, bevel=0.4)
            cel(L, [("rect", m + 6.9, BY - 3.4, m + 8.4, BY - 0.6)], LEATH3, ol=0.8, bevel=0.3)
            box3(L, m + 4.4, BY - 26.4, m + 12.4, BY - 21.0, 2.6, GUN, metal=0.6, wear=0.5)
            fill(L, [("rect", m + 4.4, BY - 24.4, m + 12.4, BY - 23.2)], tone_set(GUN)["line"], 0.8)
            cel(L, [("rect", m + 7.8, BY - 21.0, m + 9.2, BY - 19.6)], LEATH3, ol=0.8, bevel=0.3)
        elif stage == 5:  # chain hoist + a quarried stone block (left half)
            hx = m - 5.0
            cel(L, [("rect", m - 9.5, BY - 36, m + 1.5, BY - 34.4)], GUN, form="cylh", ol=1.4, metal=0.7, rust=0.3)
            cel(L, [("rect", hx - 1.7, BY - 34.4, hx + 1.7, BY - 31.4)], OXRED, ol=1.3, metal=0.5, bevel=0.5)
            for k in range(9):
                y = BY - 30.8 + k * 1.6
                cel(L, [("ell", hx, y, 0.5 if k % 2 else 0.25, 0.85)], STEEL3, form="sphere", ol=0.7, metal=0.9,
                    bevel=0.2, pad=4)
            cel(L, [("poly", [(hx - 1.3, BY - 16.4), (hx + 1.3, BY - 16.4), (hx, BY - 14.6)])], GUN, ol=0.9,
                metal=0.8, bevel=0.3)
            ink(L, [(hx, BY - 14.6), (hx - 3.2, BY - 9.6)], 0.2, C(60, 56, 54), 1)
            ink(L, [(hx, BY - 14.6), (hx + 3.2, BY - 9.6)], 0.2, C(60, 56, 54), 1)
            cshadow(L, hx, BY + 0.6, 5.5, 1.0, 0.5)
            box3(L, hx - 4.0, BY - 9.6, hx + 3.2, BY + 0.4, 2.4, C(100, 94, 88), wear=0.3)
            ink(L, [(hx - 2.6, BY - 6), (hx - 1.0, BY - 4.6), (hx - 0.2, BY - 5.6)], 0.15, C(70, 64, 60), 0.8)
    elif hero == "bolt_juno":
        if stage == 1:  # cable spool + car battery
            rug()
            cshadow(L, m, BY + 0.5, 8, 1.0, 0.5)
            cel(L, [("ell", m - 3.4, BY - 5.4, 5.2, 5.4), ("-ell", m - 3.4, BY - 5.4, 1.0, 1.0)], WOOD3,
                n=(0.2, 0, 1), ol=1.8, bevel=1.0)
            cel(L, [("ell", m - 3.4, BY - 5.4, 3.6, 3.7), ("-ell", m - 3.4, BY - 5.4, 1.0, 1.0)], C(186, 104, 54),
                form="sphere", ol=1.0, bevel=0.5, metal=0.9)
            for r_ in (2.0, 2.8):
                ink(L, [(m - 3.4 + math.cos(t) * r_, BY - 5.4 + math.sin(t) * r_) for t in np.linspace(0, 6.3, 24)],
                    0.12, C(110, 54, 24), 0.7)
            box3(L, m + 2.8, BY - 5.6, m + 9.6, BY, 2.4, RUBBER, top=C(60, 58, 64), wear=0.2)
            fill(L, [("rect", m + 3.4, BY - 3.4, m + 9.0, BY - 2.2)], YEL, 0.75)
            for (tx, c) in ((m + 4.2, RED3), (m + 8.0, GUN)):
                cel(L, [("rect", tx, BY - 7.0, tx + 1.2, BY - 6.0)], c, form="cylv", ol=0.8, metal=0.8, bevel=0.2,
                    pad=4)
            cel(L, [("line", [(m + 4.8, BY - 7), (m + 2.4, BY - 10.2), (m - 3.4, BY - 11.6)], 0.32)], RED3, form="flat",
                ol=0.8, bevel=0.3)
        elif stage == 3:  # wires strung on ceramic insulators high on the wall, an arcing spark
            pts = [(m - 8.6, BY - 33), (m - 0.6, BY - 30.5), (m + 8.4, BY - 34)]
            ink(L, sag(pts[0][0], pts[0][1], pts[1][0], pts[1][1], 1.2, 12), 0.3, C(36, 32, 34), 1)
            ink(L, sag(pts[1][0], pts[1][1], pts[2][0], pts[2][1], 1.4, 12), 0.3, C(36, 32, 34), 1)
            for (x, y) in pts:
                cel(L, [("rect", x - 0.4, y - 3.0, x + 0.4, y - 1.4)], GUN, ol=0.8, metal=0.8, bevel=0.2, pad=4)
                for k in range(3):
                    cel(L, [("ell", x, y - 1.2 + k * 0.7, 1.0 - k * 0.15, 0.36)], CREAM, form="sphere", ol=0.8,
                        metal=0.6, bevel=0.2, pad=4)
            glow2(L, m + 3.8, BY - 30.4, 3.6, C(150, 210, 240), 0.55)
            zz = [(m + 3.0, BY - 33.2), (m + 4.6, BY - 31.0), (m + 2.8, BY - 30.2), (m + 4.4, BY - 28.0)]
            ink(L, zz, 0.3, C(170, 220, 255), 0.9)
            ink(L, zz, 0.12, C(255, 255, 255), 1)
        elif stage == 5:  # wall-mounted breaker panel with live gauges + conduit
            box3(L, m - 1.0, BY - 26, m + 9.0, BY - 13, 1.4, TEAL3, metal=0.3, wear=0.4, rust=0.1)
            for gx in (m + 1.6, m + 6.4):
                glow2(L, gx, BY - 22.6, 2.3, C(140, 220, 140), 0.35)
                gauge(L, gx, BY - 22.6, 1.4, C(206, 230, 196), needle=0.3)
            for k in range(4):
                x = m + 0.2 + k * 2.2
                fill(L, [("rect", x, BY - 19.2, x + 1.5, BY - 16.4)], C(26, 26, 30), 1)
                cel(L, [("rect", x + 0.25, BY - 18.9 + (k % 2) * 1.2, x + 1.25, BY - 17.8 + (k % 2) * 1.2)], CREAM,
                    ol=0, bevel=0.2, pad=4)
            st = shape([("rect", m - 0.6, BY - 15.4, m + 8.6, BY - 14.0)])
            fill(L, [("rect", m - 0.6, BY - 15.4, m + 8.6, BY - 14.0)], YEL, 0.9)
            stripes(L, st, C(30, 26, 24), 0.9, 1.0, 0.9)
            cel(L, [("rect", m + 6.6, BY - 13, m + 7.6, BY - 6.4)], GUN, form="cylv", ol=1.0, metal=0.7, bevel=0.3)
    elif hero == "sister_cinder":
        if stage == 1:  # medicine table: tonic bottles, bandage rolls, a basin
            rug()
            table(m - 8.5, m + 8.5, BY - 9.5)
            cel(L, [("rect", m - 8.2, BY - 10.2, m + 8.2, BY - 9.5)], CREAM, n=(0, -0.6, 0.8), ol=0.8, bevel=0)
            for k, c in enumerate((TONIC3, C(214, 150, 70), TONIC3 * 0.85)):
                x = m - 7 + k * 2.6
                glow2(L, x + 0.8, BY - 12, 1.8, c, 0.18)
                cel(L, [("rect", x, BY - 13.4, x + 1.7, BY - 10.2), ("ell", x + 0.85, BY - 10.2, 0.85, 0.3)], c,
                    form="cylv", ol=0.9, metal=0.6, gloss=0.4, pad=4)
                cel(L, [("rect", x + 0.45, BY - 14.4, x + 1.25, BY - 13.4)], LEATH3, ol=0.6, bevel=0.2, pad=4)
            for k in range(2):
                cel(L, [("ell", m + 1.6 + k * 2.4, BY - 11.2, 1.1, 1.1)], CREAM, form="sphere", ol=1.0, bevel=0.4)
                ink(L, [(m + 1.6 + k * 2.4, BY - 11.2), (m + 2.2 + k * 2.4, BY - 11.0)], 0.12, C(150, 130, 100), 0.8)
            cel(L, [("ell", m + 6.6, BY - 10.6, 1.9, 0.7)], CHROME, form="cylh", ol=1.1, metal=1.0, bevel=0.3)
        elif stage == 3:  # enamel wall cabinet with a red cross
            box3(L, m - 6, BY - 30, m + 6, BY - 18.5, 1.6, CREAM, gloss=0.4, wear=0.3)
            fill(L, [("rect", m - 1.1, BY - 28.2, m + 1.1, BY - 20.4)], RED3, 1)
            fill(L, [("rect", m - 3.9, BY - 25.4, m + 3.9, BY - 23.2)], RED3, 1)
            ink(L, [(m, BY - 30), (m, BY - 18.5)], 0.14, tone_set(CREAM)["line"], 0.5)
            cel(L, [("rect", m + 4.2, BY - 25.2, m + 5.0, BY - 23.0)], CHROME, ol=0.6, metal=1, bevel=0.2, pad=4)
        elif stage == 5:  # IV stand by the table + a medic bag on the floor
            cel(L, [("line", [(m + 9.8, BY), (m + 9.8, BY - 22)], 0.38)], CHROME, form="cylv", ol=0.9, metal=1)
            ink(L, [(m + 8.2, BY), (m + 11.4, BY)], 0.36, GUN, 1)
            ink(L, [(m + 8.4, BY - 22), (m + 11.2, BY - 22)], 0.3, GUN, 1)
            glow2(L, m + 9.0, BY - 19.4, 2.2, TONIC3, 0.3)
            cel(L, [("poly", [(m + 8.0, BY - 21.6), (m + 10.0, BY - 21.6), (m + 10.2, BY - 17.8), (m + 9.0, BY - 17.0),
                              (m + 7.8, BY - 17.8)])], TONIC3, ol=0.9, gloss=0.6, metal=0.4, bevel=0.6)
            ink(L, sag(m + 9.0, BY - 17.0, m + 7.0, BY - 9.6, 2.0, 10), 0.12, C(200, 200, 190), 0.8)
            cshadow(L, m - 1, BY + 0.9, 4.5, 0.8, 0.5)
            cel(L, [("poly", [(m - 4.4, BY + 0.9), (m + 2.4, BY + 0.9), (m + 2.0, BY - 3.0), (m + 0.4, BY - 4.0),
                              (m - 2.4, BY - 4.0), (m - 4.0, BY - 3.0)])], RED3 * 0.9, form="cylv", ol=1.4, bevel=1.0)
            fill(L, [("rect", m - 1.6, BY - 2.6, m - 0.4, BY - 0.6)], CREAM, 1)
            fill(L, [("rect", m - 2.0, BY - 2.2, m - 0.0, BY - 1.0)], CREAM, 1)
            cel(L, [("line", sag(m - 2.6, BY - 4.0, m + 0.6, BY - 4.0, -1.4, 8), 0.32)], LEATH3, form="flat", ol=0.7,
                bevel=0.2)
    elif hero == "quill_marrow":
        if stage == 1:  # writing desk with an open field journal + candle
            rug()
            table(m - 8.5, m + 8.5, BY - 9.5, WOOD3_D)
            cel(L, [("poly", [(m - 5.6, BY - 10.0), (m - 0.4, BY - 10.8), (m + 4.8, BY - 10.0), (m + 4.8, BY - 9.6),
                              (m - 5.6, BY - 9.6)])], CREAM, n=(0, -0.8, 0.6), ol=1.0, bevel=0)
            ink(L, [(m - 0.4, BY - 10.8), (m - 0.4, BY - 9.6)], 0.12, C(120, 100, 80), 0.9)
            for k in range(3):
                ink(L, [(m - 4.8, BY - 10.0 - k * 0.0 + 0.1), (m - 1.2, BY - 10.5)], 0.08, C(90, 80, 70), 0.6)
            cel(L, [("line", [(m + 6.2, BY - 14.6), (m + 3.6, BY - 10.4)], 0.22)], CREAM, form="flat", ol=0.6)
            glow2(L, m - 6.8, BY - 15, 3.0, AMBER, 0.42)
            cel(L, [("rect", m - 7.4, BY - 13.4, m - 6.2, BY - 10.0)], CREAM, form="cylv", ol=0.9, bevel=0.3)
            cel(L, [("ell", m - 6.8, BY - 14.3, 0.45, 0.8)], BULB, n=(0, 0, 1), ol=0.5, bevel=0, rim=0,
                line=C(200, 110, 40))
        elif stage == 3:  # shelf of specimen jars
            shelf(m - 9, m + 9, BY - 20)
            for k in range(4):
                x = m - 8 + k * 4.2
                c = [TONIC3 * 0.8, C(170, 156, 100), TONIC3, C(150, 120, 96)][k]
                cel(L, [("rect", x, BY - 24.4, x + 3.2, BY - 20), ("ell", x + 1.6, BY - 20, 1.6, 0.4)], c,
                    form="cylv", ol=1.0, metal=0.5, gloss=0.5)
                cel(L, [("rect", x - 0.2, BY - 25.4, x + 3.4, BY - 24.4)], LEATH3, form="cylh", ol=0.8, bevel=0.3)
                fill(L, [("ell", x + 1.6, BY - 22.2, 0.9, 0.7)], tone_set(c)["deep"], 0.7)
        elif stage == 5:  # pinboard: map, notes, red string
            cel(L, [("rect", m - 9, BY - 38, m + 9, BY - 26)], C(150, 112, 72), n=(0, 0, 1), ol=1.8, bevel=0.8)
            cel(L, [("poly", [(m - 7.6, BY - 36.6), (m + 0.8, BY - 37), (m + 1.2, BY - 29.6), (m - 7.4, BY - 29.2)])],
                C(200, 186, 146), n=(0, 0, 1), ol=1.0, bevel=0)
            ink(L, [(m - 6.5, BY - 33), (m - 4, BY - 34.5), (m - 1.6, BY - 32), (m, BY - 33.6)], 0.14,
                C(110, 130, 120), 0.8)
            for (nx_, ny_) in ((m + 2.4, BY - 36.6), (m + 5.4, BY - 33), (m + 2.8, BY - 30), (m - 5, BY - 28.8)):
                cel(L, [("rect", nx_, ny_, nx_ + 2.6, ny_ + 2.3)], CREAM, n=(0, 0, 1), ol=0.7, bevel=0, rim=0, pad=4)
                fill(L, [("ell", nx_ + 1.3, ny_ + 0.3, 0.35, 0.35)], RED3, 1)
            ink(L, [(m - 4, BY - 34.6), (m + 3.7, BY - 36.3), (m + 6.7, BY - 32.7), (m - 3.7, BY - 28.5)], 0.12, RED3, 1)
    elif hero == "nyx_caldera":
        if stage == 1:  # dark footlocker with brass corners
            rug()
            cshadow(L, m, BY + 0.6, 7.5, 1.0, 0.5)
            box3(L, m - 7, BY - 6.2, m + 7, BY + 0.4, 2.8, C(70, 62, 80), wear=0.3)
            ink(L, [(m - 7, BY - 4.6), (m + 7, BY - 4.6)], 0.2, tone_set(C(70, 62, 80))["line"], 0.9)
            cel(L, [("rect", m - 1.0, BY - 5.6, m + 1.0, BY - 3.6)], BRASS, ol=0.8, metal=1, bevel=0.3)
            for (cx_, cy_) in ((m - 6.4, BY - 5.6), (m + 5.6, BY - 5.6), (m - 6.4, BY - 0.6), (m + 5.6, BY - 0.6)):
                fill(L, [("rect", cx_, cy_, cx_ + 0.8, cy_ + 0.8)], BRASS * 1.1, 1)
        elif stage == 3:  # crossed twin blades on the wall
            for sgn in (-1, 1):
                a, b = (m - 3.5 - 5.5 * sgn, BY - 31), (m - 3.5 + 4.5 * sgn, BY - 19.5)
                mid = ((a[0] + b[0]) * 0.5 + (b[0] - a[0]) * 0.12, (a[1] + b[1]) * 0.5 + 1.0)
                cel(L, [("poly", [(a[0] - 0.2 * sgn, a[1]), (mid[0] - 0.6, mid[1] - 0.2), (b[0], b[1]),
                                  (mid[0] + 0.6, mid[1] + 0.4)])], CHROME, ol=1.4, metal=1.0, bevel=0.6)
                hline(L, [a, mid], 0.12, SPEC, 0.8)
                cel(L, [("line", [(b[0] - sgn * 0.6, b[1] - 1.4), (b[0] + sgn * 1.4, b[1] + 0.4)], 0.5)], BRASS,
                    form="flat", ol=0.8, metal=1, bevel=0.2)
                cel(L, [("line", [b, (b[0] + sgn * 1.4, b[1] + 2.2)], 0.55)], LEATH3, form="flat", ol=0.9, bevel=0.2)
        elif stage == 5:  # hooded cloak on a hook + oil lamp
            cel(L, [("poly", [(m + 3.6, BY - 32.6), (m + 7.0, BY - 32.6), (m + 9.4, BY - 28.6), (m + 9.8, BY - 17),
                              (m + 8.8, BY - 9.0), (m + 6.2, BY - 10.0), (m + 4.4, BY - 8.8), (m + 1.6, BY - 9.6),
                              (m + 0.8, BY - 17), (m + 1.2, BY - 28.6)])], C(66, 58, 76), form="cylv", ol=1.8,
                bevel=1.4)
            for (xa, xb) in ((m + 3.4, m + 2.8), (m + 5.4, m + 5.0), (m + 7.4, m + 7.6)):
                ink(L, [(xa, BY - 27), (xb, BY - 10.2)], 0.14, C(36, 30, 44), 0.8)
            cel(L, [("poly", [(m + 2.8, BY - 33.6), (m + 7.8, BY - 33.6), (m + 8.4, BY - 30.4), (m + 5.3, BY - 28.6),
                              (m + 2.2, BY - 30.4)])], C(54, 48, 64), form="sphere", ol=1.3, bevel=1)
            fill(L, [("ell", m + 5.3, BY - 31.0, 1.4, 1.1)], C(20, 16, 26), 1)
            ink(L, [(m + 5.3, BY - 35.4), (m + 5.3, BY - 33.6)], 0.25, GUN, 1)
            glow2(L, m - 4, BY - 12.6, 3.6, AMBER, 0.45)
            cel(L, [("rect", m - 5.6, BY - 15.6, m - 2.4, BY - 10.2)], BULB, n=(0, 0, 1), ol=1.1, bevel=0, rim=0,
                line=C(120, 80, 30), gloss=0.5)
            cel(L, [("rect", m - 6.0, BY - 16.4, m - 2.0, BY - 15.4)], BRASS, form="cylh", ol=0.9, metal=0.9, bevel=0.2)
            cel(L, [("rect", m - 6.0, BY - 10.4, m - 2.0, BY - 9.4)], BRASS, form="cylh", ol=0.9, metal=0.9, bevel=0.2)
            ink(L, [(m - 4, BY - 16.4), (m - 4, BY - 18)], 0.2, GUN, 1)
    elif hero == "helm_wisp":
        if stage == 1:  # her scout drone on a maintenance stand
            rug()
            cshadow(L, m, BY + 0.5, 5.5, 1.0, 0.5)
            for k in (-1, 1):
                ink(L, [(m + k * 4, BY), (m, BY - 8.6)], 0.34, GUN, 1)
            cel(L, [("poly", [(m - 3.6, BY - 12.8), (m + 3.6, BY - 12.8), (m + 2.8, BY - 9.2), (m - 2.8, BY - 9.2)])],
                C(150, 156, 150), form="cylv", ol=1.6, metal=0.6, wear=0.4)
            cel(L, [("line", [(m - 8, BY - 13.2), (m + 8, BY - 13.2)], 0.45)], GUN, form="cylh", ol=1.0, metal=0.8)
            for x in (m - 8, m + 8):
                cel(L, [("rect", x - 0.4, BY - 14.2, x + 0.4, BY - 13.2)], GUN, ol=0.6, metal=0.8, bevel=0.2, pad=4)
                cel(L, [("ell", x, BY - 14.4, 2.8, 0.45)], C(200, 210, 210), n=(0, -0.9, 0.4), ol=0.7, bevel=0,
                    alpha=0.9)
            glow2(L, m, BY - 10.8, 1.8, C(150, 230, 190), 0.45)
            cel(L, [("ell", m, BY - 10.9, 0.8, 0.8)], C(170, 230, 200), form="sphere", ol=0.6, metal=1, bevel=0.3)
        elif stage == 3:  # a spare drone on wall hooks + her red toolbox
            cel(L, [("line", [(m - 9.6, BY - 27.6), (m + 1.8, BY - 27.6)], 0.4)], GUN, form="cylh", ol=0.9, metal=0.8)
            cel(L, [("poly", [(m - 6.8, BY - 27.2), (m - 0.8, BY - 27.2), (m - 1.4, BY - 24.2), (m - 6.2, BY - 24.2)])],
                C(132, 140, 136), form="cylv", ol=1.4, metal=0.6, wear=0.4)
            for x in (m - 9.6, m + 1.8):
                cel(L, [("ell", x, BY - 28.1, 2.1, 0.4)], C(200, 210, 210), n=(0, -0.9, 0.4), ol=0.6, bevel=0)
            cshadow(L, m + 5.2, BY + 0.5, 4.6, 0.9, 0.5)
            box3(L, m + 1.4, BY - 4.6, m + 9.2, BY + 0.2, 2.2, RED3, wear=0.5, metal=0.3)
            cel(L, [("line", [(m + 3.4, BY - 4.6 - 1.0), (m + 3.8, BY - 6.4), (m + 6.8, BY - 6.4), (m + 7.2, BY - 5.6)],
                     0.36)], GUN, form="flat", ol=0.8, metal=0.8, bevel=0.2)
            fill(L, [("rect", m + 1.4, BY - 2.6, m + 9.2, BY - 2.2)], tone_set(RED3)["line"], 0.9)
        elif stage == 5:  # the bent propeller from her plane + flight jacket on a peg
            cel(L, [("poly", [(m - 8.6, BY - 1), (m - 7.4, BY - 2.0), (m - 2.2, BY - 17.4), (m - 0.8, BY - 29.6),
                              (m - 2.4, BY - 29.8), (m - 4.0, BY - 17.4)])], C(110, 104, 94), ol=1.8, metal=0.5,
                bevel=0.8, wear=0.5)
            fill(L, [("poly", [(m - 1.0, BY - 29.4), (m - 2.4, BY - 29.6), (m - 2.5, BY - 27.6), (m - 1.0, BY - 27.4)])],
                 YEL, 0.9)
            cel(L, [("ell", m - 2.8, BY - 17.2, 1.6, 1.6)], GUN, form="sphere", ol=1.1, metal=0.9, bevel=0.5)
            # flight jacket on a hanger: body + sleeves + shearling collar
            for (sx0, sx1) in (((m + 1.2, m - 0.2), (m + 2.6, m + 1.6)), ((m + 8.8, m + 10.2), (m + 7.4, m + 8.4))):
                cel(L, [("poly", [(sx0[0], BY - 29.6), (sx1[0], BY - 29.0), (sx1[1], BY - 16.6), (sx0[1], BY - 17.2)])],
                    LEATH3 * 0.9, form="cylv", ol=1.5, bevel=0.8)
            cel(L, [("poly", [(m + 1.8, BY - 31), (m + 8.2, BY - 31), (m + 8.4, BY - 15.4), (m + 1.6, BY - 15.4)])],
                LEATH3, form="cylv", ol=1.8, bevel=1.0, wear=0.3)
            cel(L, [("poly", [(m + 1.6, BY - 31.4), (m + 8.4, BY - 31.4), (m + 7.0, BY - 28.6), (m + 5, BY - 27.4),
                              (m + 3.0, BY - 28.6)])], CREAM, ol=1.0, bevel=0.5)
            ink(L, [(m + 5, BY - 27.4), (m + 5, BY - 15.6)], 0.16, tone_set(LEATH3)["line"], 0.9)
            fill(L, [("rect", m + 1.8, BY - 17.0, m + 8.2, BY - 15.6)], tone_set(LEATH3)["shadow"], 0.9)
            ink(L, [(m + 2.0, BY - 31.6), (m + 5, BY - 33), (m + 8.0, BY - 31.6)], 0.22, GUN, 1)
            ink(L, [(m + 5, BY - 33), (m + 5, BY - 34.4)], 0.25, GUN, 1)
    return L


# =========================================================== kennel, stash, trophies, cosmetics
PET_BED = {"noel": 110.0, "bentley": 125.0, "lillie": 140.0}  # bed centre x (art units)
PET_COL = {"noel": C(96, 112, 132), "bentley": C(176, 150, 104), "lillie": C(160, 84, 62)}
BED_Y = 141.0


def kennel(pet, stage):
    L = Layer()
    x = PET_BED[pet]
    col = PET_COL[pet]
    if stage == 1:  # a round bolster bed with a cushion
        cshadow(L, x, BED_Y + 1.6, 7.0, 1.5, 0.6)
        cel(L, [("ell", x, BED_Y, 6.6, 2.9)], col, form="sphere", ol=2.0, bevel=2.0, rim=0.8)
        cel(L, [("ell", x, BED_Y - 0.5, 4.8, 1.8)], col * 0.62 + CREAM * 0.38, n=(0, -0.8, 0.6), ol=1.0, bevel=0.6)
        ink(L, [(x - 5.6, BED_Y + 1.2), (x, BED_Y + 2.4), (x + 5.6, BED_Y + 1.2)], 0.14, tone_set(col)["line"], 0.6)
    elif stage == 2:  # enamel bowl with kibble
        bx = x + 6.4
        cel(L, [("poly", [(bx - 2.2, BED_Y + 3.3), (bx + 2.2, BED_Y + 3.3), (bx + 1.6, BED_Y + 5.2), (bx - 1.6, BED_Y + 5.2)])],
            CHROME, form="cylv", ol=1.4, metal=1.0, bevel=0.5)
        cel(L, [("ell", bx, BED_Y + 3.3, 2.2, 0.55)], C(120, 82, 52), n=(0, -0.9, 0.4), ol=0.9, bevel=0)
        for k in range(4):
            fill(L, [("ell", bx - 1.2 + k * 0.8, BED_Y + 3.2 + (k % 2) * 0.15, 0.32, 0.22)], C(150, 102, 60), 1)
    elif stage == 3:  # a little name sign on a stake behind the bed
        sx = x - 5.4
        cel(L, [("line", [(sx, BED_Y - 1), (sx, BED_Y - 6.6)], 0.5)], WOOD3_D, form="cylv", ol=0.9, bevel=0.2)
        cel(L, [("poly", [(sx - 2.6, BED_Y - 9.0), (sx + 2.6, BED_Y - 9.2), (sx + 2.5, BED_Y - 6.4), (sx - 2.7, BED_Y - 6.3)])],
            PLY, n=(0, 0, 1), ol=1.2, bevel=0.4)
        for k in range(3):
            ink(L, [(sx - 1.8 + k * 1.3, BED_Y - 8.2), (sx - 1.2 + k * 1.3, BED_Y - 7.2)], 0.14, WOOD3_D, 0.9)
        fill(L, [("ell", sx + 1.9, BED_Y - 7.8, 0.45, 0.45)], col, 1)
    return L


def stash(stage):
    L = Layer()
    if stage == 0:  # the lockbox: olive footlocker with a brass hasp, in the door light
        cshadow(L, 120, 112.4, 13, 1.8, 0.6)
        box3(L, 108, 102.5, 132, 112, 5, OD, top=OD * 1.04, wear=0.4, rust=0.12)
        fill(L, [("rect", 108, 104.6, 132, 105.3)], tone_set(OD)["line"], 0.9)
        for x in (110.2, 128.6):
            cel(L, [("rect", x, 102.5, x + 1.2, 112)], GUN, n=(0, 0, 1), ol=0.8, metal=0.7, bevel=0.3)
        cel(L, [("rect", 118.6, 103.6, 121.4, 107.2)], BRASS, ol=1.0, metal=1.0, bevel=0.5)
        cel(L, [("rect", 119.4, 106.4, 120.6, 108.4)], GUN, ol=0.7, metal=0.8, bevel=0.2)
        fill(L, [("rect", 113.4, 108.6, 126.6, 110.2)], C(214, 196, 140), 0.45)
    elif stage == 1:  # a wooden crate on the left
        cshadow(L, 101.5, 112.4, 6.5, 1.4, 0.55)
        box3(L, 95.5, 104.2, 107, 112, 4, WOOD3, top=PLY)
        ink(L, [(96, 104.6), (106.6, 111.6)], 0.4, WOOD3_D, 1)
        for y in (104.2, 111.4):
            fill(L, [("rect", 95.5, y, 107, y + 0.6)], WOOD3_D, 0.9)
    elif stage == 2:  # a steel ammo chest on the right
        cshadow(L, 138.5, 112.4, 6.5, 1.4, 0.55)
        box3(L, 133, 104.6, 144, 112, 3.6, TEAL3, metal=0.35, wear=0.4)
        cel(L, [("line", [(136.6, 103.6), (137, 102.6), (140, 102.6), (140.4, 103.6)], 0.4)], GUN, form="flat",
            ol=0.8, metal=0.8, bevel=0.2)
        cel(L, [("rect", 142.6, 106.6, 143.6, 109.6)], GUN, ol=0.7, metal=0.8, bevel=0.2)
    elif stage == 3:  # a strongbox on top of the lockbox
        box3(L, 112.5, 94.2, 127.5, 100.4, 3.6, C(96, 80, 70), metal=0.4, wear=0.4)
        cel(L, [("ell", 120, 97.3, 1.5, 1.5)], BRASS, form="sphere", ol=1.0, metal=1, bevel=0.4)
        ink(L, [(120, 97.3), (120.9, 96.6)], 0.16, INK3, 1)
        for x in (113.6, 125.8):
            fill(L, [("rect", x, 94.2, x + 0.6, 100.4)], GUN, 1)
    return L


def trophy(boss):
    return wall_shadow(_trophy(boss), 100.0 if boss == "dread_naught" else 140.0, 0, 44)


def _trophy(boss):
    L = Layer()
    if boss == "wall":  # plank board above the door
        cel(L, [("rect", 103, 29.5, 137, 39.5)], WOOD3_D, n=(0, 0, 1), ol=2.0, bevel=0.6)
        for y in (32.8, 36.2):
            ink(L, [(103.4, y), (136.6, y)], 0.16, C(50, 34, 24), 0.8)
        wood_grain(L, 104, 29.8, 136, 39.2, C(70, 48, 32), 4)
        bolts(L, [(105.4, 31.2), (105.4, 37.8), (134.6, 31.2), (134.6, 37.8)], STEEL3, 0.35)
    elif boss == "dread_naught":  # the war-machine's cracked visor plate
        cel(L, [("poly", [(108, 30.2), (118, 30.2), (119.2, 34), (117, 38.6), (109, 38.6), (106.8, 34)])], STEEL3,
            ol=2.0, metal=0.8, bevel=1.2, wear=0.4)
        fill(L, [("rect", 109.4, 33.0, 116.6, 34.8)], C(24, 20, 22), 1)
        for gx in (111.0, 115.0):
            glow2(L, gx, 33.9, 2.0, C(240, 80, 50), 0.45)
            fill(L, [("ell", gx, 33.9, 1.1, 0.5)], C(255, 120, 80), 1)
        ink(L, [(113, 30.4), (112, 33), (114.2, 36), (113.6, 38.4)], 0.2, INK3, 1)
    elif boss == "mutant_overlord":  # horned mutant skull
        bone = C(206, 190, 156)
        for sgn in (-1, 1):
            cel(L, [("line", [(128 + sgn * 3.2, 31.6), (128 + sgn * 6.4, 29.4), (128 + sgn * 7.4, 26.2),
                              (128 + sgn * 6.0, 24.4)], 1.0)], C(140, 120, 92), form="cylv", ol=1.4, bevel=0.6)
        cel(L, [("poly", [(124, 30.5), (128, 29.2), (132, 30.5), (133, 33.5), (131.4, 36), (130.6, 39.4), (125.4, 39.4),
                          (124.6, 36), (123, 33.5)])], bone, form="sphere", ol=2.0, bevel=1.6)
        for x in (126.0, 130.0):
            fill(L, [("poly", [(x - 1.4, 33.2), (x + 1.3, 33.0), (x + 0.6, 35.0), (x - 1.0, 35.0)])], C(30, 26, 22), 1)
            glow2(L, x, 34.1, 1.5, TONIC3, 0.45)
        fill(L, [("poly", [(127.4, 35.8), (128.6, 35.8), (128, 37)])], C(40, 34, 28), 1)
        for k in range(4):
            cel(L, [("rect", 125.8 + k * 1.15, 38.1, 126.6 + k * 1.15, 39.6)], C(226, 214, 184), ol=0.6, bevel=0.2,
                pad=4)
        ink(L, [(129.5, 30), (130.5, 32), (129.6, 33)], 0.18, INK3, 1)
    return L


def cosmetic(cz):
    L = Layer()
    if cz == "banner":  # canvas banner hung from a rib
        cel(L, [("line", [(48, 14), (70, 12.5)], 0.5)], GUN, form="cylh", ol=1.0, metal=0.8)
        pts = [(49, 14.5), (69, 13), (69.5, 36), (64.5, 41), (59, 37.5), (53.5, 41.5), (49, 37)]
        cel(L, [("poly", pts)], CANV3 * 0.95, form="cylv", ol=2.0, bevel=1.2, grad=0.2)
        for k in range(3):
            ink(L, [(53 + k * 5, 15), (52.6 + k * 5.2, 36)], 0.14, tone_set(CANV3)["shadow"], 0.6)
        ink(L, [(59.2 + 5.0 * math.cos(t), 24 + 5.0 * math.sin(t)) for t in np.linspace(0, 6.3, 40)], 1.1, RED3, 0.95)
        fill(L, [("poly", [(59.2, 19.6), (61, 24), (59.2, 28.4), (57.4, 24)])], C(222, 150, 60), 1)
        ink(L, [(50.4, 33), (68.4, 32)], 0.45, RED3, 0.95)
    elif cz == "flag":  # tattered flag on a pole off a rib
        cel(L, [("line", [(206, 12), (192, 18.4)], 0.42)], CHROME, form="flat", ol=0.9, metal=1)
        cel(L, [("poly", [(204.5, 13), (205, 30), (201, 28.5), (198.5, 31.5), (194, 27), (193.5, 18.4)])], TEAL3,
            form="cylv", ol=1.8, bevel=1.2, grad=0.2)
        ink(L, [(196, 22.4), (203, 20.4)], 0.55, CREAM, 0.9)
        ink(L, [(197, 25.4), (202.6, 23.8)], 0.3, CREAM, 0.7)
    elif cz == "campfire":  # burning oil drum (fire barrel)
        bx = 152.0
        cshadow(L, bx, 145.8, 5.6, 1.4, 0.6)
        glow2(L, bx, 128, 12, AMBER, 0.26)
        soft(L, [("ell", bx, 146, 15, 2.8)], C(255, 170, 90), 0.16, 5)
        drum(L, bx, 131.4, 145.4, 4.2, RUST * 1.15, ry=1.2, open_top=True, metal=0.3, rust=0.25)
        for y in (135.2, 141.4):
            cel(L, [("rect", bx - 4.2, y, bx + 4.2, y + 0.9)], RUST, form="cylv", ol=0.8, metal=0.5, bevel=0.2)
        for k in range(4):
            fill(L, [("ell", bx - 2.6 + k * 1.7, 138.4, 0.45, 0.6)], C(255, 150, 60), 0.9)
        # flames: three hard-edged tongues, hot core
        for (fx, fh, fw, c) in ((bx - 1.4, 6.5, 1.8, C(230, 110, 44)), (bx + 1.2, 8.5, 2.0, C(240, 128, 50)),
                                (bx, 5, 1.4, C(255, 200, 110))):
            fill(L, [("poly", [(fx - fw, 131.4), (fx - fw * 0.7, 131.4 - fh * 0.45), (fx - fw * 0.1, 131.4 - fh * 0.7),
                               (fx, 131.4 - fh), (fx + fw * 0.4, 131.4 - fh * 0.55), (fx + fw, 131.4)])], c, 1)
        fill(L, [("ell", bx, 131.0, 2.4, 0.8)], C(255, 236, 180), 1)
        soft(L, [("ell", bx + 1, 117, 2.6, 3.4), ("ell", bx + 2.6, 110, 3.4, 3.4)], C(130, 118, 110), 0.2, 5)
    elif cz == "toys":  # tennis ball + rope toy by the beds
        cel(L, [("ell", 101.6, 145.4, 1.6, 1.6)], C(196, 206, 90), form="sphere", ol=1.2, bevel=0.6)
        ink(L, [(100.4, 144.6), (101.6, 145.6), (102.8, 144.6)], 0.14, CREAM, 0.9)
        cel(L, [("line", [(144.6, 146.4), (149, 145)], 0.8)], CANV3, form="cylh", ol=1.1, bevel=0.3)
        for k in range(4):
            ink(L, [(145.4 + k * 1.0, 145.6 - k * 0.3), (145.8 + k * 1.0, 146.6 - k * 0.3)], 0.12, C(120, 100, 70), 0.9)
        for x in (144.2, 149.3):
            cel(L, [("ell", x, 146.4 - (x - 144.2) * 0.3, 0.8, 0.8)], RED3, form="sphere", ol=0.9, bevel=0.3)
    elif cz == "case":  # glass display case on the right door leaf, a legendary blade inside
        cel(L, [("rect", 152, 47, 166, 63)], WOOD3_D, n=(0, 0, 1), ol=2.0, bevel=0.8)
        cel(L, [("rect", 153.2, 48.2, 164.8, 61.8)], C(46, 52, 60), n=(0, 0, 1), ol=0.8, bevel=0, rim=0)
        glow2(L, 159, 55, 4.5, AMBER, 0.32)
        cel(L, [("poly", [(155, 60.4), (162.6, 50.2), (163.4, 50.8), (155.8, 61)])], C(220, 176, 90), ol=1.0, metal=1,
            bevel=0.3)
        cel(L, [("line", [(155.2, 58.4), (157.4, 60.2)], 0.4)], BRASS, form="flat", ol=0.6, metal=1)
        hline(L, [(154.0, 49.4), (157.2, 53.6)], 0.32, SPEC, 0.5)
        hline(L, [(160.6, 49.2), (163.8, 53.4)], 0.18, SPEC, 0.4)
    return L


# =========================================================== registry
LAYERS = {"backdrop": backdrop, "trophy_wall": (lambda: trophy("wall"))}
for c in ("banner", "flag", "campfire", "toys", "case"):
    LAYERS["cosmetic_%s" % c] = (lambda c=c: cosmetic(c))
for s in (1, 3, 5):
    LAYERS["generator_%d" % s] = (lambda s=s: generator(s))
    LAYERS["radio_tower_%d" % s] = (lambda s=s: radio_tower(s))
    LAYERS["scrap_press_%d" % s] = (lambda s=s: scrap_press(s))
    LAYERS["ammo_bench_%d" % s] = (lambda s=s: ammo_bench(s))
    for h in HEROES:
        LAYERS["station_%s_%d" % (h, s)] = (lambda h=h, s=s: station(h, s))
for p in ("noel", "bentley", "lillie"):
    for s in (1, 2, 3):
        LAYERS["kennel_%s_%d" % (p, s)] = (lambda p=p, s=s: kennel(p, s))
for s in (0, 1, 2, 3):
    LAYERS["stash_%d" % s] = (lambda s=s: stash(s))
for b in ("dread_naught", "mutant_overlord"):
    LAYERS["trophy_%s" % b] = (lambda b=b: trophy(b))

# Same stacking order as scripts/ui/hangar.gd builds the view.
ORDER = (["backdrop", "trophy_wall"] + ["stash_%d" % s for s in range(4)]
         + ["%s_%d" % (i, s) for i in ("generator", "radio_tower", "scrap_press", "ammo_bench") for s in (1, 3, 5)]
         + ["station_%s_%d" % (h, s) for h in HEROES for s in (1, 3, 5)]
         + ["kennel_%s_%d" % (p, s) for p in ("noel", "bentley", "lillie") for s in (1, 2, 3)]
         + ["trophy_dread_naught", "trophy_mutant_overlord"]
         + ["cosmetic_%s" % c for c in ("banner", "flag", "campfire", "toys", "case")])


def crop(im):
    bb = im.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox()
    if bb is None:
        bb = (0, 0, 1, 1)
    return im.crop(bb), bb


def build():
    os.makedirs(OUT, exist_ok=True)
    rects = {}
    for name in ORDER:
        im = LAYERS[name]().image()
        if name == "backdrop":
            bb = (0, 0, W, H)
        else:
            im, bb = crop(im)
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
        rects[name] = bb
        print(name, bb)
    with open(LAYOUT_GD, "w") as f:
        f.write("extends RefCounted\n\n")
        f.write("## GENERATED by tools/gen_hangar_art.py; do not edit by hand.\n")
        f.write("## Each hangar layer PNG is cropped; RECTS gives where it sits on the\n")
        f.write("## %dx%d painted canvas (= the 240x150 art space at %dx).\n\n" % (W, H, S))
        f.write("const CANVAS := Vector2(%d, %d)\n" % (W, H))
        f.write("const RECTS := {\n")
        for n in ORDER:
            x0, y0, x1, y1 = rects[n]
            f.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % (n, x0, y0, x1 - x0, y1 - y0))
        f.write("}\n")
    return rects


# =========================================================== previews
PET_ON_BED = {p: (x, BED_Y + 0.5) for p, x in PET_BED.items()}


def compose(ranks, trophies=(), cosmetics=(), rects=None):
    """ranks: id -> rank. Mirrors hangar.gd visibility + Generator tint + pets."""
    base = Image.open(os.path.join(OUT, "backdrop.png")).convert("RGBA")
    canvas = Image.new("RGBA", base.size)
    for n in ORDER:
        if n in ("backdrop", "trophy_wall", "stash_0"):
            vis = True
        elif n.startswith("trophy_"):
            vis = n[7:] in trophies
        elif n.startswith("cosmetic_"):
            vis = n[9:] in cosmetics
        else:
            cut = n.rfind("_")
            vis = ranks.get(n[:cut], 0) >= int(n[cut + 1:])
        if not vis:
            continue
        im = Image.open(os.path.join(OUT, n + ".png")).convert("RGBA")
        x0, y0 = rects[n][0], rects[n][1]
        canvas.alpha_composite(im, (x0, y0))
    g = ranks.get("generator", 0)
    lit = 0.62 + 0.076 * g
    arr = np.asarray(canvas, F) / 255
    arr[..., 0] *= lit
    arr[..., 1] *= lit * 0.97
    arr[..., 2] *= lit * 0.92
    canvas = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), "RGBA")
    for p, (fx, fy) in PET_ON_BED.items():
        if ranks.get("kennel_" + p, 0) < 1:
            continue
        strip = Image.open("assets/sprites/pets/%s/%s_idle.png" % (p, p)).convert("RGBA")
        hh = strip.height
        fr = strip.crop((0, 0, hh, hh))
        size = int(30 * S)
        fr = fr.resize((size, size), Image.LANCZOS)
        a = np.asarray(fr, F) / 255
        a[..., :3] *= np.array([lit, lit * 0.97, lit * 0.92], F)
        fr = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")
        canvas.alpha_composite(fr, (int(fx * S - size * 0.5), int(fy * S - size * 0.82)))
    return canvas


def all_ids():
    ids = ["generator", "radio_tower", "scrap_press", "ammo_bench", "stash"]
    ids += ["station_" + h for h in HEROES] + ["kennel_" + p for p in PET_BED]
    return ids


def previews(outdir, rects):
    os.makedirs(outdir, exist_ok=True)
    r0 = {}
    mid = {i: 3 for i in all_ids()}
    mid.update({"kennel_noel": 2, "kennel_bentley": 1, "kennel_lillie": 0, "stash": 1, "generator": 3})
    mx = {i: 5 for i in all_ids()}
    mx.update({"kennel_noel": 3, "kennel_bentley": 3, "kennel_lillie": 3, "stash": 3})
    compose(r0, rects=rects).save(os.path.join(outdir, "preview_rank0.png"))
    compose(mid, ("dread_naught",), ("campfire",), rects=rects).save(os.path.join(outdir, "preview_mid.png"))
    full = compose(mx, ("dread_naught", "mutant_overlord"), ("banner", "flag", "campfire", "toys", "case"), rects=rects)
    full.save(os.path.join(outdir, "preview_max.png"))
    closeup(full, os.path.join(outdir, "props_closeup.png"))


def closeup(full, path, k=1.6):
    """Prop zones of the max hangar shown large, next to hero portraits."""
    zones = [(0, 50, 94, 97), (146, 50, 240, 97), (0, 95, 104, 150), (146, 92, 240, 150), (92, 90, 150, 150)]
    tiles = []
    for (x0, y0, x1, y1) in zones:
        c = full.crop((int(x0 * S), int(y0 * S), int(x1 * S), int(y1 * S)))
        tiles.append(c.resize((int(c.width * k), int(c.height * k)), Image.LANCZOS))
    ph = tiles[4].height // 2
    ports = [Image.open("assets/sprites/portraits/%s.png" % h).convert("RGBA").resize((ph, ph), Image.NEAREST)
             for h in ("sister_cinder", "helm_wisp", "pebble", "quill_marrow")]
    gap = 12
    cw = tiles[0].width + tiles[1].width + gap * 3
    rh = [max(tiles[0].height, tiles[1].height), max(tiles[2].height, tiles[3].height), tiles[4].height]
    sheet = Image.new("RGBA", (cw, sum(rh) + gap * 4), (28, 24, 26, 255))
    y = gap
    sheet.alpha_composite(tiles[0], (gap, y))
    sheet.alpha_composite(tiles[1], (gap * 2 + tiles[0].width, y))
    y += rh[0] + gap
    sheet.alpha_composite(tiles[2], (gap, y))
    sheet.alpha_composite(tiles[3], (gap * 2 + tiles[2].width, y))
    y += rh[1] + gap
    sheet.alpha_composite(tiles[4], (gap, y))
    for i, pimg in enumerate(ports):
        sheet.alpha_composite(pimg, (gap * 2 + tiles[4].width + (i % 2) * (ph + gap), y + (i // 2) * ph))
    sheet.save(path)


if __name__ == "__main__":
    rects = build()
    print(len(rects), "hangar layers ->", OUT)
    if "--preview" in sys.argv:
        previews(sys.argv[sys.argv.index("--preview") + 1], rects)
