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


# =========================================================== shared camp
def generator(stage):
    L = Layer()
    if stage == 1:  # olive diesel generator on skids, front-left
        shadow(L, 25, 141, 23, 3.4, 0.55)
        P(L, [("rect", 5, 136.5, 44, 140.5)], WOOD_D, form="cylh", ol=1.6, bevel=2, rust=0.0, grit=0.12)
        P(L, [("poly", [(7, 113), (36, 113), (38, 115), (38, 137), (7, 137)])], OLIVE, ol=2.0, bevel=4, rust=0.35,
          streaks=1.2, wear=0.25)
        # louvres
        for k in range(5):
            P(L, [("rect", 10, 117 + k * 3.2, 23, 118.5 + k * 3.2)], OLIVE_D, ol=0.6, bevel=1.2, form="cylh")
        # control panel + amber gauge
        P(L, [("rect", 26, 117, 35.5, 129)], STEEL_D, ol=1.2, bevel=2, rust=0.2, wear=0.2)
        P(L, [("ell", 30.7, 121.6, 2.4, 2.4)], BONE, form="sphere", ol=0.9, bevel=1.5)
        P(L, [("line", [(30.7, 121.6), (32.2, 120.4)], 0.35)], CLOTH_R, form="flat", ol=0, bevel=1)
        glow(L, 29, 126, 2.6, AMBER, 0.5)
        P(L, [("ell", 29, 126, 0.9, 0.9)], BULB, ol=0.6, form="sphere", bevel=1)
        P(L, [("ell", 33, 126, 0.7, 0.7)], C(150, 60, 40), ol=0.5, form="sphere", bevel=1)
        # fuel tank on top + exhaust stack with smoke
        P(L, [("rect", 9, 108.5, 31, 113.5)], OLIVE_D, form="cylh", ol=1.6, bevel=3, rust=0.3)
        P(L, [("rect", 11.5, 99, 14.5, 109)], STEEL_D, form="cylv", ol=1.4, bevel=2, rust=0.6)
        P(L, [("rect", 10.8, 98, 15.2, 100)], STEEL, form="cylv", ol=1.2, bevel=1.5, rust=0.4)
        soft(L, [("ell", 14, 94, 2.6, 2.4), ("ell", 16.5, 88.5, 3.6, 3.0), ("ell", 20, 82, 4.6, 3.4)], C(120, 108, 98), 0.32, 5)
        # jerrycan
        shadow(L, 43, 141.5, 4, 1.2, 0.5)
        P(L, [("poly", [(39, 131), (45, 131), (46, 132), (46, 141), (39, 141)])], CLOTH_R * 0.9, ol=1.5, bevel=2.5,
          rust=0.3, wear=0.3)
        P(L, [("rect", 40.5, 129.5, 44, 131.2)], STEEL_D, ol=1.0, bevel=1)
        rivets(L, [(9, 115), (34.5, 115), (9, 135), (34.5, 135)])
        # cable snaking to the wall
        cable(L, [(36, 133), (44, 128), (50, 118), (44, 104), (36, 96), (32, 92)], 0.9, CHARC, 1.0)
    elif stage == 3:  # string lights draped between the ribs
        strands = [((4, 46), (64, 30), 6), ((64, 30), (120, 26), 5), ((120, 26), (176, 30), 5),
                   ((176, 30), (236, 46), 6), ((30, 18), (100, 10), 5), ((140, 10), (210, 18), 5)]
        for (a, b, dip) in strands:
            pts = sag(a[0], a[1], b[0], b[1], dip, 18)
            cable(L, pts, 0.45, CHARC, 0.5)
            for t in np.linspace(0.06, 0.94, 7):
                i = t * (len(pts) - 1)
                q0, q1 = pts[int(i)], pts[min(len(pts) - 1, int(i) + 1)]
                fr = i - int(i)
                x, y = q0[0] + (q1[0] - q0[0]) * fr, q0[1] + (q1[1] - q0[1]) * fr + 1.0
                glow(L, x, y, 3.2, AMBER, 0.32)
                P(L, [("ell", x, y, 0.75, 0.95)], BULB, form="sphere", ol=0.6, bevel=1.0, grit=0.02, warm=1)
        # warm pools of light under the strands
        soft(L, [("ell", 60, 96, 40, 3)], C(255, 190, 110), 0.12, 6)
        soft(L, [("ell", 180, 96, 40, 3)], C(255, 190, 110), 0.12, 6)
    elif stage == 5:  # caged floodlights hung off the ribs
        for fx, fy in ((62, 22), (178, 22)):
            cable(L, [(fx, 8), (fx, fy - 2)], 0.5, CHARC, 0.6)
            soft(L, [("poly", [(fx - 3, fy + 2), (fx + 3, fy + 2), (fx + 20, 100), (fx - 18, 100)])],
                 C(255, 212, 150), 0.16, 6)
            soft(L, [("ell", fx + 1, 101, 22, 3.5)], C(255, 200, 130), 0.20, 5)
            P(L, [("poly", [(fx - 4, fy - 2), (fx + 4, fy - 2), (fx + 5, fy + 2), (fx - 5, fy + 2)])], STEEL_D,
              ol=1.4, bevel=2, rust=0.3, form="cylh")
            glow(L, fx, fy + 2.5, 5, BULB, 0.55)
            P(L, [("ell", fx, fy + 2.3, 3.6, 1.1)], BULB, form="flat", ol=0.8, bevel=1, warm=1)
            for k in (-2.4, 0, 2.4):
                P(L, [("line", [(fx + k, fy + 1.4), (fx + k, fy + 3)], 0.3)], CHARC, form="flat", ol=0)
    return L


def radio_tower(stage):
    L = Layer()
    if stage == 1:  # radio desk, front-right
        shadow(L, 221, 141, 17, 3, 0.5)
        P(L, [("rect", 205, 119, 237, 122.5)], WOOD, form="cylh", ol=1.6, bevel=2.5, grit=0.12,
          tex=lambda h, w: 0.08 * np.sin(np.arange(h, dtype=F)[:, None] * 1.3 + np.arange(w)[None, :] * 0.03))
        for lx in (207, 234):
            P(L, [("rect", lx, 122.5, lx + 2.4, 140.5)], WOOD_D, form="cylv", ol=1.4, bevel=1.5)
        P(L, [("rect", 207, 131, 236, 132.5)], WOOD_D, form="cylh", ol=1.0, bevel=1)
        # the set: dented steel case, amber dial, speaker grille, knobs
        P(L, [("poly", [(210, 107), (229, 107), (230, 108), (230, 119), (210, 119)])], STEEL, ol=1.8, bevel=3,
          rust=0.3, wear=0.3, streaks=0.6)
        glow(L, 216, 112, 4, AMBER, 0.35)
        P(L, [("rect", 212, 109.5, 220.5, 114.2)], C(210, 150, 70), ol=0.9, bevel=1.5, form="flat", warm=1)
        for k in range(6):
            P(L, [("line", [(213 + k * 1.4, 110.5), (213 + k * 1.4, 113.2)], 0.25)], CHARC, form="flat", ol=0)
        P(L, [("line", [(216.8, 114), (218.3, 110)], 0.35)], CLOTH_R, form="flat", ol=0)
        P(L, [("rect", 222, 109.5, 228.5, 117)], CHARC, ol=0.8, bevel=1, form="flat",
          tex=lambda h, w: 0.25 * ((np.arange(h)[:, None] // 3 + np.arange(w)[None, :] // 3) % 2))
        for kx in (213, 216.5, 220):
            P(L, [("ell", kx, 116.5, 1.0, 1.0)], C(170, 160, 140), form="sphere", ol=0.6, bevel=1)
        # mic + headset + coiled cord, a mug
        P(L, [("line", [(232, 119), (233, 113)], 0.5)], STEEL_D, form="flat", ol=0.6)
        P(L, [("ell", 233.2, 112, 1.4, 1.9)], CHARC, form="sphere", ol=0.8, bevel=1.2)
        cable(L, [(229.5, 116), (231.5, 118.8), (233, 117.5), (234.5, 119)], 0.35, CHARC, 0.4)
        P(L, [("rect", 206.5, 115, 209.2, 119)], BONE * 0.85, form="cylv", ol=1.0, bevel=1.2, rust=0.2)
        # whip antenna
        P(L, [("line", [(228.5, 107.5), (231.5, 95)], 0.45)], STEEL_L, form="flat", ol=0.6)
        cable(L, [(210, 118), (205, 126), (206, 140), (212, 143)], 0.5, CHARC, 0.6)
    elif stage == 3:  # lattice mast up through the roof
        x0, x1 = 226.5, 233.5
        for xa, xb in ((x0, x0 + 2.0), (x1, x1 - 2.0)):
            P(L, [("line", [(xa, 106), (xb, -2)], 0.9)], STEEL_D, form="flat", ol=1.0, bevel=1.5, rust=0.35)
        y = 104.0
        k = 0
        while y > 0:
            ln = x0 + 2.0 * (1 - y / 106)
            rn = x1 - 2.0 * (1 - y / 106)
            P(L, [("line", [(ln, y), (rn, y - 3.8 if k % 2 == 0 else y)], 0.4),
                  ("line", [(ln, y - 3.8), (rn, y)], 0.4), ("line", [(ln, y), (rn, y)], 0.45)],
              STEEL, form="flat", ol=0.6, bevel=1, rust=0.4)
            y -= 7.6
            k += 1
        # guy wire + a feeder cable down to the radio
        P(L, [("line", [(229, 30), (196, 92)], 0.18)], C(120, 110, 100), form="flat", ol=0)
        cable(L, [(226.8, 104), (224, 108.5)], 0.5, CHARC, 0.6)
        rivets(L, [(227, 100), (233, 100)])
    elif stage == 5:  # dish + blinking red beacon
        P(L, [("line", [(222, 22), (229.5, 18)], 0.7)], STEEL_D, form="flat", ol=0.8)
        # dish seen three-quarter: rim ellipse, dark bowl interior, lit lip, feed horn on struts
        P(L, [("ell", 218.5, 21, 3.4, 6.6)], STEEL_L, form="sphere", ol=1.5, bevel=2.2, rust=0.3, wear=0.3)
        P(L, [("ell", 218.0, 21.2, 2.4, 5.4)], STEEL_D, form="sphere", ol=0, bevel=2.0, lit=-0.6)
        P(L, [("line", [(217, 15.6), (213, 21), (217, 26.4)], 0.25)], STEEL, form="flat", ol=0.3)
        P(L, [("rect", 212, 20.2, 214, 21.8)], STEEL_D, ol=0.7, bevel=0.8)
        P(L, [("rect", 220.5, 19.5, 223, 22.5)], STEEL_D, ol=0.8, bevel=1)
        glow(L, 230.5, 2.5, 4.5, C(230, 70, 50), 0.5)
        P(L, [("ell", 230.5, 2.6, 1.3, 1.3)], C(232, 96, 70), form="sphere", ol=0.8, bevel=1, warm=1)
        P(L, [("rect", 229, 3.8, 232, 5.4)], STEEL_D, ol=0.8, bevel=1)
    return L


def scrap_press(stage):
    L = Layer()
    if stage == 1:  # junk pile
        shadow(L, 86, 145.5, 16, 2.8, 0.55)
        r = np.random.default_rng(3)
        pieces = []
        for i in range(22):
            x = r.uniform(72, 98)
            y = r.uniform(130, 144)
            pieces.append((y, x, i))
        P(L, [("poly", [(70, 146), (76, 134), (84, 128), (92, 131), (99, 140), (101, 146)])], C(64, 54, 46), ol=1.5,
          bevel=4, rust=0.4, grit=0.18, form="box")
        for (y, x, i) in sorted(pieces):
            kind = i % 5
            col = [STEEL, RUST, STEEL_D, OXID, BRASS][i % 5]
            if kind == 0:  # bent sheet
                P(L, [("poly", [(x - 3, y + 1), (x, y - 2), (x + 3.5, y - 1), (x + 2, y + 1.5)])], col, ol=1.0,
                  bevel=1.5, rust=0.4)
            elif kind == 1:  # pipe
                P(L, [("line", [(x - 3, y + 1), (x + 3, y - 1)], 1.3)], col, form="flat", ol=1.0, bevel=1.5, rust=0.5)
            elif kind == 2:  # gear
                P(L, [("ell", x, y, 2.2, 1.6), ("-ell", x, y, 0.8, 0.6)], col, form="sphere", ol=1.0, bevel=1.5,
                  rust=0.3)
            elif kind == 3:  # can
                P(L, [("rect", x - 1.2, y - 2.2, x + 1.2, y + 1)], col, form="cylv", ol=0.9, bevel=1.2, rust=0.4)
            else:  # spring / brass fitting
                P(L, [("ell", x, y, 1.3, 1.0)], col, form="sphere", ol=0.8, bevel=1.2)
        # old tyre leaning on the pile
        P(L, [("ell", 77, 139, 4.6, 5.4), ("-ell", 77, 139, 2.0, 2.6)], CHARC, form="sphere", ol=1.5, bevel=2.5,
          grit=0.14)
    elif stage == 3:  # the hydraulic press
        shadow(L, 61, 137, 15, 2.6, 0.55)
        P(L, [("rect", 47, 130, 75, 136.5)], STEEL_D, form="cylh", ol=1.8, bevel=2.5, rust=0.4)
        for cx in (49.5, 69.5):
            P(L, [("rect", cx, 97, cx + 4, 131)], C(116, 60, 40), form="cylv", ol=1.8, bevel=2.5, rust=0.45,
              streaks=1.2, wear=0.25)
        P(L, [("rect", 46, 93, 76.5, 99)], C(116, 60, 40), form="cylh", ol=1.8, bevel=3, rust=0.45, streaks=1.0,
          wear=0.2)
        stm = shape([("rect", 47, 96.5, 75.5, 98.5)])
        stripes(L, stm, C(186, 140, 60), 1.4, 1.0, 0.65)
        P(L, [("rect", 59, 99, 63, 107)], STEEL_L, form="cylv", ol=1.4, bevel=1.5, grit=0.04)
        P(L, [("rect", 54, 107, 68, 113)], STEEL, form="cylh", ol=1.6, bevel=2, rust=0.3, wear=0.3)
        # half-crushed car door under the ram
        P(L, [("poly", [(54, 125), (68, 125), (69, 130), (53, 130)])], OXID, ol=1.2, bevel=1.5, rust=0.6)
        P(L, [("rect", 52, 123.5, 70, 125.2)], STEEL_D, ol=0.8, bevel=1)
        # hydraulic lines + control box with a red lever
        cable(L, [(73.5, 100), (79, 104), (78, 118), (74, 122)], 0.6, CHARC, 0.7)
        P(L, [("rect", 76, 114, 82, 122)], OLIVE_D, ol=1.4, bevel=1.5, rust=0.3, wear=0.3)
        P(L, [("line", [(79, 114), (80.5, 109.5)], 0.5)], STEEL, form="flat", ol=0.6)
        P(L, [("ell", 80.6, 109.3, 0.9, 0.9)], CLOTH_R, form="sphere", ol=0.6, bevel=1)
        rivets(L, [(48, 95.5), (74.5, 95.5), (51.5, 128), (71.5, 128)])
    elif stage == 5:  # crushed cubes on a pallet
        shadow(L, 94, 147.5, 11, 2.2, 0.55)
        P(L, [("rect", 84, 144, 104, 147)], WOOD, form="cylh", ol=1.4, bevel=1.5, grit=0.12)
        for (x, y, c) in ((86, 137.5, OXID), (95, 137.5, RUST_L), (90.5, 130.5, STEEL)):
            P(L, [("rect", x, y, x + 8, y + 6.5)], c, ol=1.6, bevel=2.5, rust=0.45, grit=0.16, wear=0.3,
              tex=lambda h, w: 0.18 * (vnoise(h, w, 4, nseed()) - 0.5) + 0.06 * np.sin(np.arange(h, dtype=F)[:, None] * 1.4))
    return L


def ammo_bench(stage):
    L = Layer()
    wood_tex = lambda h, w: 0.09 * np.sin(np.arange(h, dtype=F)[:, None] * 1.1 + vnoise(h, w, 9, nseed()) * 4)
    if stage == 1:  # heavy workbench with a vice + reloading press
        shadow(L, 178, 141, 22, 3, 0.55)
        for lx in (156.5, 198):
            P(L, [("rect", lx, 94.5, lx + 1.6, 113)], WOOD_D, form="cylv", ol=1.0, bevel=1)
        P(L, [("rect", 157, 95.5, 199.5, 104.5)], C(120, 98, 70), ol=1.4, bevel=1.6, grit=0.08, rust=0.2,
          tex=lambda h, w: -0.15 * (((np.arange(h)[:, None] % 9) < 2) & ((np.arange(w)[None, :] % 9) < 2)))
        P(L, [("rect", 155.5, 104.5, 201, 106.3)], WOOD_D, form="cylh", ol=1.2, bevel=1.2)
        P(L, [("rect", 156, 113, 200, 117)], WOOD, form="cylh", ol=1.8, bevel=2.5, tex=wood_tex, grit=0.1, wear=0.3)
        for lx in (158, 196):
            P(L, [("rect", lx, 117, lx + 2.6, 140.5)], WOOD_D, form="cylv", ol=1.5, bevel=1.5, tex=wood_tex)
        P(L, [("rect", 159, 129, 197, 131)], WOOD_D, form="cylh", ol=1.0, bevel=1.2)
        # vice
        P(L, [("rect", 160, 108, 166, 113)], C(54, 74, 78), ol=1.4, bevel=2, rust=0.35, wear=0.3)
        P(L, [("line", [(158, 111.5), (168, 111.5)], 0.5)], STEEL_L, form="flat", ol=0.6)
        # reloading press
        P(L, [("rect", 175, 101, 178, 113)], CLOTH_R * 0.85, form="cylv", ol=1.3, bevel=1.5, rust=0.3, wear=0.3)
        P(L, [("line", [(178, 104), (184, 100)], 0.5)], STEEL_L, form="flat", ol=0.6)
        P(L, [("ell", 184.2, 99.8, 0.9, 0.9)], CHARC, form="sphere", ol=0.6, bevel=1)
        # brass casings + a tray
        P(L, [("rect", 186, 111, 196, 113)], STEEL_D, ol=1.0, bevel=1)
        for k in range(6):
            P(L, [("rect", 186.6 + k * 1.55, 108.4, 187.6 + k * 1.55, 111.2)], BRASS, form="cylv", ol=0.5, bevel=1,
              grit=0.03, warm=1)
        P(L, [("rect", 168, 110.5, 172, 113)], BONE * 0.8, form="cylv", ol=0.8, bevel=1)
        # a desk lamp pooling amber light on the work
        P(L, [("line", [(197, 113), (198.5, 104), (194, 100.5)], 0.45)], STEEL_D, form="flat", ol=0.6)
        P(L, [("poly", [(191, 100), (195.5, 98.5), (196.5, 101.5), (192.5, 102.5)])], OLIVE_D, ol=0.9, bevel=1)
        soft(L, [("poly", [(192, 102), (196, 101), (192, 113), (180, 113)])], BULB, 0.22, 3)
        glow(L, 193.5, 102, 2.5, AMBER, 0.45)
    elif stage == 3:  # ammo crates stacked by the bench
        shadow(L, 166, 141, 12, 2.2, 0.5)
        for (x, y, w, h, c) in ((157, 131, 15, 9.5, OLIVE), (172.5, 133, 12, 7.5, OLIVE_D), (159, 122, 11, 9, OLIVE_D)):
            P(L, [("rect", x, y, x + w, y + h)], c, ol=1.6, bevel=2.5, rust=0.25, wear=0.3, grit=0.12)
            P(L, [("rect", x + 0.6, y + h * 0.45, x + w - 0.6, y + h * 0.6)], c * 0.75, ol=0, bevel=1, form="flat")
            P(L, [("rect", x + w * 0.35, y + 1.2, x + w * 0.65, y + 2.4)], C(186, 160, 100) * 0.9, ol=0,
              bevel=1, form="flat")
            rivets(L, [(x + 1, y + 1), (x + w - 1, y + 1)], STEEL)
        # a belt of rounds draped over the top crate
        cable(L, sag(160, 122.3, 168, 122.3, 1.6, 8), 0.8, BRASS, 0.7)
    elif stage == 5:  # pegboard of tools + shelf of special-ammo cans
        cans = [C(140, 64, 44), C(96, 128, 136), C(198, 150, 70), C(170, 176, 160)]
        for x, c in zip((157.6, 162.8, 168.0, 185.8), cans):
            P(L, [("rect", x, 99.6, x + 4.4, 104.5)], c, form="cylv", ol=1.1, bevel=1.4, rust=0.25, wear=0.3)
            P(L, [("rect", x + 0.3, 101.4, x + 4.1, 102.6)], c * 0.6, ol=0, form="flat")
        # tools on pegs: wrench + hammer
        P(L, [("line", [(158.5, 96.6), (165, 98.2)], 0.6)], STEEL, form="flat", ol=0.7)
        P(L, [("line", [(166.5, 96.8), (172.5, 96.8)], 0.6)], WOOD, form="flat", ol=0.7)
        P(L, [("rect", 172, 95.8, 173.6, 98.4)], STEEL_D, ol=0.7, bevel=0.8)
        # a belt-fed drum of special rounds by the bench leg
        shadow(L, 193, 141, 4, 1.2, 0.5)
        P(L, [("rect", 188.5, 133, 196.5, 140.5)], C(96, 128, 136), form="cylv", ol=1.4, bevel=1.8, rust=0.3, wear=0.3)
        P(L, [("rect", 188.5, 135.5, 196.5, 137)], CHARC, ol=0, form="flat")
        cable(L, sag(196, 134, 199.5, 140, -1, 6), 0.8, BRASS, 0.7)
    return L


# =========================================================== survivor corners
HEROES = ["ash_rook", "vesper_thorn", "pebble", "bolt_juno", "sister_cinder", "quill_marrow", "nyx_caldera",
          "helm_wisp"]
BOOTH = {"ash_rook": 14, "vesper_thorn": 35, "pebble": 56, "bolt_juno": 78,
         "sister_cinder": 162, "quill_marrow": 184, "nyx_caldera": 205, "helm_wisp": 226}
BY = 93.0


def station(hero, stage):
    L = Layer()
    m = BOOTH[hero]
    wt = lambda h, w: 0.08 * np.sin(np.arange(h, dtype=F)[:, None] * 1.2 + vnoise(h, w, 9, nseed()) * 3)

    def crate(x0, x1, top, col=WOOD):
        shadow(L, (x0 + x1) / 2, BY + 0.5, (x1 - x0) * 0.6, 1.4, 0.5)
        P(L, [("rect", x0, top, x1, BY)], col, ol=1.5, bevel=2, tex=wt, grit=0.1, wear=0.3)
        P(L, [("line", [(x0 + 0.5, top + 0.8), (x1 - 0.5, BY - 0.8)], 0.5)], col * 0.75, form="flat", ol=0)

    def table(x0, x1, top, col=WOOD):
        shadow(L, (x0 + x1) / 2, BY + 0.5, (x1 - x0) * 0.6, 1.4, 0.5)
        P(L, [("rect", x0, top, x1, top + 2.2)], col, form="cylh", ol=1.5, bevel=1.5, tex=wt, wear=0.3)
        for lx in (x0 + 0.8, x1 - 2.2):
            P(L, [("rect", lx, top + 2.2, lx + 1.4, BY)], col * 0.75, form="cylv", ol=1.1, bevel=1)

    if hero == "ash_rook":
        if stage == 1:  # A-frame weapon rack holding her launcher
            P(L, [("line", [(m - 8, BY), (m - 6, BY - 24)], 1.0), ("line", [(m + 8, BY), (m + 6, BY - 24)], 1.0),
                  ("line", [(m - 7, BY - 12), (m + 7, BY - 12)], 0.9), ("line", [(m - 6.5, BY - 21), (m + 6.5, BY - 21)], 0.9)],
              WOOD_D, form="flat", ol=1.2, bevel=1.2, tex=wt)
            P(L, [("rect", m - 9, BY - 17, m + 8, BY - 13.4)], OLIVE_D, form="cylh", ol=1.5, bevel=1.8, rust=0.3,
              wear=0.35)
            P(L, [("rect", m + 8, BY - 17.6, m + 10, BY - 12.8)], STEEL_D, form="cylh", ol=1.2, bevel=1)
            P(L, [("rect", m - 2, BY - 13.4, m, BY - 10.5)], CHARC, ol=0.8, bevel=1)
            P(L, [("rect", m - 5, BY - 19.4, m - 1, BY - 17)], STEEL, ol=0.8, bevel=1)
        elif stage == 3:  # open crate of rockets
            crate(m - 8, m + 4, BY - 6.5, OLIVE_D)
            for k in range(3):
                y = BY - 7.4 - k * 1.9
                x = m - 7.5 + k * 0.8
                P(L, [("rect", x, y - 0.8, x + 8, y + 0.8)], OLIVE, form="cylh", ol=0.8, bevel=0.8)
                P(L, [("poly", [(x + 8, y - 0.9), (x + 10.6, y), (x + 8, y + 0.9)])], C(150, 110, 60), ol=0.7, bevel=0.8,
                  warm=1)
                P(L, [("poly", [(x - 1.2, y - 1.3), (x + 0.4, y - 0.6), (x + 0.4, y + 0.6), (x - 1.2, y + 1.3)])], STEEL_D,
                  ol=0.6, bevel=0.6)
        elif stage == 5:  # sandbags + a second launcher + hazard plate
            for (x, y) in ((m - 3, BY - 2.2), (m + 3.4, BY - 2.2), (m + 0.2, BY - 6)):
                P(L, [("ell", x + 3, y, 3.4, 2.1)], CANVAS * 0.85, form="sphere", ol=1.2, bevel=2, grit=0.14)
            pl = P(L, [("rect", m - 9, BY - 34, m + 7, BY - 28)], C(150, 120, 70), ol=1.3, bevel=1.5, rust=0.4,
                   wear=0.3)
            stripes(L, pl, CHARC, 1.3, 1.0, 0.85)
            P(L, [("rect", m - 10, BY - 26.5, m + 9, BY - 23.6)], STEEL, form="cylh", ol=1.4, bevel=1.5, rust=0.3,
              wear=0.3)
            P(L, [("line", [(m - 9, BY - 26), (m - 7.6, BY - 29)], 0.4), ("line", [(m + 7, BY - 26), (m + 5.6, BY - 29)], 0.4)],
              STEEL_D, form="flat", ol=0.5)
    elif hero == "vesper_thorn":
        if stage == 1:  # bench with the long vial rifle on a bipod
            table(m - 9, m + 9, BY - 10)
            P(L, [("poly", [(m - 9, BY - 12.5), (m + 10, BY - 14), (m + 10, BY - 12.8), (m - 9, BY - 11.2)])],
              STEEL_D, ol=1.1, bevel=1, rust=0.2)
            P(L, [("poly", [(m - 10, BY - 13), (m - 3.5, BY - 13.6), (m - 3.2, BY - 11.2), (m - 9.5, BY - 10.6)])],
              WOOD, ol=1.1, bevel=1.2, tex=wt)
            P(L, [("rect", m - 2, BY - 16, m + 3, BY - 14)], CHARC, form="cylh", ol=0.9, bevel=1)
            P(L, [("rect", m + 1, BY - 12.6, m + 2.2, BY - 11)], TONIC, form="cylv", ol=0.6, bevel=1)
        elif stage == 3:  # hanging lantern + a rack of vials
            P(L, [("line", [(m - 4, BY - 36), (m - 4, BY - 30)], 0.3)], CHARC, form="flat", ol=0.3)
            glow(L, m - 4, BY - 27, 5.5, AMBER, 0.42)
            P(L, [("poly", [(m - 6, BY - 30), (m - 2, BY - 30), (m - 1.6, BY - 24), (m - 6.4, BY - 24)])], BRASS,
              ol=1.1, bevel=1.2, rust=0.2)
            P(L, [("rect", m - 5.3, BY - 29, m - 2.7, BY - 25)], BULB, form="flat", ol=0, warm=1)
            P(L, [("rect", m + 1, BY - 21, m + 10, BY - 19.8)], WOOD_D, form="cylh", ol=1.0, bevel=1)
            for k in range(4):
                P(L, [("rect", m + 1.6 + k * 2.2, BY - 24, m + 3.1 + k * 2.2, BY - 21)], TONIC * (0.85 + 0.1 * (k % 2)),
                  form="cylv", ol=0.6, bevel=1, warm=0.4)
        elif stage == 5:  # target sheet riddled with holes + glowing tonic crate
            P(L, [("rect", m - 8, BY - 36, m + 2, BY - 24)], CANVAS, ol=1.2, bevel=1.2, rust=0.2, grit=0.12)
            for r_ in (4.0, 2.6, 1.2):
                P(L, [("ell", m - 3, BY - 30, r_, r_), ("-ell", m - 3, BY - 30, r_ - 0.5, r_ - 0.5)], CLOTH_R,
                  form="flat", ol=0)
            for (hx, hy) in ((-2.6, -30.4), (-3.8, -29), (-1.5, -31.5)):
                P(L, [("ell", m + hx, BY + hy, 0.4, 0.4)], INK, form="flat", ol=0)
            glow(L, m + 6, BY - 4, 5, TONIC, 0.3)
            crate(m + 2, m + 10, BY - 5, OLIVE_D)
            for k in range(3):
                P(L, [("rect", m + 3 + k * 2.4, BY - 8, m + 4.6 + k * 2.4, BY - 5)], TONIC, form="cylv", ol=0.6,
                  bevel=1, warm=0.5)
    elif hero == "pebble":
        if stage == 1:  # anvil on a stump
            shadow(L, m, BY + 0.5, 7, 1.4, 0.5)
            P(L, [("rect", m - 4, BY - 8, m + 4, BY)], WOOD_D, form="cylv", ol=1.5, bevel=2, tex=wt)
            P(L, [("ell", m, BY - 8, 4, 0.9)], WOOD * 1.1, form="flat", ol=0.8, bevel=1)
            P(L, [("poly", [(m - 7, BY - 13), (m + 5, BY - 13), (m + 7.5, BY - 12), (m + 4, BY - 10.6),
                            (m + 2, BY - 10.6), (m + 2.5, BY - 8.2), (m - 3.5, BY - 8.2), (m - 3, BY - 10.6), (m - 5, BY - 11.6)])],
              STEEL_D, ol=1.6, bevel=2, grit=0.05, wear=0.4)
        elif stage == 3:  # the maul leaning on the wall
            P(L, [("line", [(m + 3, BY - 1), (m + 8, BY - 26)], 1.0)], WOOD, form="flat", ol=1.2, bevel=1.2, tex=wt)
            P(L, [("poly", [(m + 3.5, BY - 31), (m + 12, BY - 29.5), (m + 11.2, BY - 23.5), (m + 2.8, BY - 25)])],
              STEEL, ol=1.6, bevel=2, rust=0.3, wear=0.4)
            P(L, [("rect", m + 6.6, BY - 27.6, m + 8.6, BY - 24.4)], LEATHER, ol=0.5, form="flat")
        elif stage == 5:  # stone blocks + a chain hoist
            for (x, y, w, h) in ((m - 10, BY - 6, 7, 6), (m - 9, BY - 11.5, 6, 5.5), (m - 3, BY - 4.5, 5, 4.5)):
                P(L, [("rect", x, y, x + w, y + h)], C(132, 122, 108), ol=1.4, bevel=2, grit=0.2)
            P(L, [("rect", m - 9, BY - 40, m + 9, BY - 38)], STEEL_D, form="cylh", ol=1.2, bevel=1, rust=0.4)
            for k in range(9):
                P(L, [("ell", m - 2, BY - 37 + k * 2.0, 0.6, 1.0), ("-ell", m - 2, BY - 37 + k * 2.0, 0.25, 0.5)],
                  STEEL_L, form="flat", ol=0.4, bevel=0.6)
            P(L, [("poly", [(m - 3.5, BY - 19.5), (m - 0.5, BY - 19.5), (m - 2, BY - 16.5)])], STEEL, ol=0.8, bevel=1)
    elif hero == "bolt_juno":
        if stage == 1:  # cable spool + car battery
            shadow(L, m, BY + 0.5, 8, 1.4, 0.5)
            P(L, [("ell", m - 3, BY - 5.5, 5.5, 5.5), ("-ell", m - 3, BY - 5.5, 1.2, 1.2)], WOOD, form="flat", ol=1.5,
              bevel=1.8, tex=wt)
            P(L, [("ell", m - 3, BY - 5.5, 3.8, 3.8), ("-ell", m - 3, BY - 5.5, 1.2, 1.2)], C(176, 100, 56),
              form="sphere", ol=0.8, bevel=1.5, warm=0.6,
              tex=lambda h, w: 0.15 * np.sin(np.hypot(*np.mgrid[0:h, 0:w] - np.array([h / 2, w / 2])[:, None, None]) * 2.5))
            P(L, [("rect", m + 3, BY - 6, m + 10, BY)], CHARC, ol=1.4, bevel=1.5, wear=0.3)
            P(L, [("rect", m + 4, BY - 7, m + 5.4, BY - 6)], CLOTH_R, ol=0.6, form="flat")
            P(L, [("rect", m + 7.6, BY - 7, m + 9, BY - 6)], STEEL_L, ol=0.6, form="flat")
            cable(L, [(m + 4.7, BY - 7), (m + 2, BY - 10), (m - 3, BY - 11.5)], 0.4, CLOTH_R, 0.5)
        elif stage == 3:  # wires strung on ceramic insulators, a spark
            for (x, y) in ((m - 9, BY - 30), (m - 1, BY - 26), (m + 8, BY - 31)):
                P(L, [("rect", x - 0.9, y - 1.6, x + 0.9, y + 0.6)], BONE, form="cylv", ol=0.8, bevel=1)
            cable(L, sag(m - 9, BY - 30, m - 1, BY - 26, 1.2, 8), 0.4, CHARC, 0.5)
            cable(L, sag(m - 1, BY - 26, m + 8, BY - 31, 1.5, 8), 0.4, CHARC, 0.5)
            glow(L, m + 3.5, BY - 27.3, 3.4, C(150, 200, 230), 0.5)
            P(L, [("line", [(m + 3, BY - 29.5), (m + 4.5, BY - 27.5), (m + 2.8, BY - 26.8), (m + 4.2, BY - 24.5)], 0.25)],
              C(230, 240, 250), form="flat", ol=0)
        elif stage == 5:  # breaker cabinet with live gauges
            shadow(L, m + 4, BY + 0.5, 6, 1.4, 0.5)
            P(L, [("rect", m - 1, BY - 22, m + 9.5, BY)], C(70, 84, 82), ol=1.6, bevel=2, rust=0.4, streaks=1.0, wear=0.3)
            for (gx, gy) in ((m + 1.8, BY - 18), (m + 6.4, BY - 18)):
                glow(L, gx, gy, 2.2, C(140, 200, 120), 0.35)
                P(L, [("ell", gx, gy, 1.6, 1.6)], BONE, form="sphere", ol=0.7, bevel=1)
                P(L, [("line", [(gx, gy), (gx + 0.9, gy - 0.9)], 0.2)], CHARC, form="flat", ol=0)
            for k in range(4):
                P(L, [("rect", m + 0.6 + k * 2.2, BY - 13, m + 2.0 + k * 2.2, BY - 10)], CHARC, ol=0.4, form="flat")
                P(L, [("rect", m + 0.8 + k * 2.2, BY - 12.6 + (k % 2) * 1.2, m + 1.8 + k * 2.2, BY - 11.6 + (k % 2) * 1.2)],
                  BONE, ol=0, form="flat")
            pl = shape([("rect", m, BY - 6, m + 8.5, BY - 4)])
            stripes(L, pl, C(186, 140, 60), 1.0, 1.0, 0.8)
    elif hero == "sister_cinder":
        if stage == 1:  # medicine table: tonic bottles, bandage rolls, a basin
            table(m - 9, m + 9, BY - 10, WOOD)
            P(L, [("rect", m - 8.6, BY - 10.6, m + 8.6, BY - 9.8)], CANVAS, form="flat", ol=0.6, bevel=1)
            for k, c in enumerate((TONIC, AMBER * 0.85, TONIC * 0.8)):
                x = m - 7 + k * 2.8
                glow(L, x + 0.8, BY - 12, 1.6, c, 0.18)
                P(L, [("rect", x, BY - 14, x + 1.8, BY - 10.6)], c, form="cylv", ol=0.7, bevel=1, warm=0.5)
                P(L, [("rect", x + 0.4, BY - 15, x + 1.4, BY - 14)], LEATHER, ol=0.4, form="flat")
            for k in range(2):
                P(L, [("ell", m + 2 + k * 2.6, BY - 11.6, 1.2, 1.1)], BONE, form="sphere", ol=0.7, bevel=1)
            P(L, [("ell", m + 7, BY - 11.2, 2.0, 0.8)], STEEL_L, form="cylh", ol=0.8, bevel=1)
        elif stage == 3:  # wall cabinet with a faded red cross
            P(L, [("rect", m - 6, BY - 30, m + 6, BY - 18)], BONE * 0.9, ol=1.5, bevel=2, rust=0.35, streaks=0.8,
              wear=0.3)
            P(L, [("rect", m - 1.2, BY - 28, m + 1.2, BY - 20)], CLOTH_R, ol=0, form="flat", grit=0.15)
            P(L, [("rect", m - 4, BY - 25.2, m + 4, BY - 22.8)], CLOTH_R, ol=0, form="flat", grit=0.15)
            P(L, [("rect", m + 4.4, BY - 25, m + 5.2, BY - 23)], STEEL, ol=0.4, form="flat")
        elif stage == 5:  # cot with a blanket + IV stand
            shadow(L, m, BY + 0.6, 10, 1.4, 0.5)
            P(L, [("rect", m - 10, BY - 6, m + 6, BY - 4.4)], STEEL_D, form="cylh", ol=1.2, bevel=1)
            for lx in (m - 9.5, m + 4.8):
                P(L, [("line", [(lx, BY - 4.4), (lx + 0.6, BY)], 0.5)], STEEL_D, form="flat", ol=0.6)
            P(L, [("poly", [(m - 10, BY - 6), (m + 6, BY - 6), (m + 6.5, BY - 3.6), (m - 1, BY - 3.2), (m - 10.5, BY - 4)])],
              C(108, 112, 84), ol=1.2, bevel=1.5, grit=0.15)
            P(L, [("ell", m - 8, BY - 6.8, 2.2, 1.2)], CANVAS, form="sphere", ol=0.8, bevel=1)
            P(L, [("line", [(m + 9, BY), (m + 9, BY - 20)], 0.5), ("line", [(m + 7, BY), (m + 11, BY)], 0.5),
                  ("line", [(m + 7.8, BY - 20), (m + 10.2, BY - 20)], 0.4)], STEEL, form="flat", ol=0.6)
            glow(L, m + 8.4, BY - 17.5, 2.0, TONIC, 0.3)
            P(L, [("rect", m + 7.4, BY - 19.6, m + 9.4, BY - 15.6)], TONIC, ol=0.6, form="cylv", bevel=1, warm=0.5)
            cable(L, sag(m + 8.4, BY - 15.6, m + 3, BY - 6.5, 3, 8), 0.2, C(180, 180, 170), 0.2)
    elif hero == "quill_marrow":
        if stage == 1:  # writing desk with an open field journal + candle
            table(m - 9, m + 9, BY - 10, WOOD_D)
            P(L, [("poly", [(m - 6, BY - 10.6), (m - 0.4, BY - 11.4), (m + 5, BY - 10.6), (m + 5, BY - 10), (m - 6, BY - 10)])],
              BONE, ol=0.8, bevel=1, form="flat")
            for k in range(3):
                P(L, [("line", [(m - 5, BY - 10.5 + 0 * k), (m - 1, BY - 10.9)], 0.12)], CHARC, form="flat", ol=0)
            P(L, [("line", [(m + 6, BY - 14.5), (m + 3.6, BY - 10.6)], 0.25)], BONE, form="flat", ol=0.3)
            glow(L, m - 7, BY - 15, 2.6, AMBER, 0.4)
            P(L, [("rect", m - 7.6, BY - 13.6, m - 6.4, BY - 10.6)], BONE, form="cylv", ol=0.5, bevel=1)
            P(L, [("ell", m - 7, BY - 14.4, 0.4, 0.7)], BULB, form="flat", ol=0)
        elif stage == 3:  # shelf of specimen jars
            P(L, [("rect", m - 9, BY - 21, m + 9, BY - 19.6)], WOOD_D, form="cylh", ol=1.0, bevel=1)
            for k in range(4):
                x = m - 8 + k * 4.3
                c = [TONIC * 0.8, C(150, 140, 90), TONIC, C(120, 100, 80)][k]
                P(L, [("rect", x, BY - 25, x + 3.2, BY - 21)], c, form="cylv", ol=0.7, bevel=1.2, warm=0.2)
                P(L, [("rect", x - 0.2, BY - 25.8, x + 3.4, BY - 25)], LEATHER, ol=0.4, form="flat")
                P(L, [("ell", x + 1.6, BY - 23, 0.9, 0.7)], BONE * 0.8, form="sphere", ol=0, bevel=1)
        elif stage == 5:  # pinboard: map, notes, red string
            P(L, [("rect", m - 9, BY - 40, m + 9, BY - 27)], C(128, 98, 66), ol=1.4, bevel=1.6, grit=0.14)
            P(L, [("poly", [(m - 7.6, BY - 38.6), (m + 1, BY - 39), (m + 1.4, BY - 31.4), (m - 7.4, BY - 31)])],
              C(176, 160, 120), ol=0.6, bevel=1, grit=0.12)
            for (nx, ny) in ((m + 2.6, BY - 38), (m + 5.4, BY - 34), (m + 3, BY - 31), (m - 5, BY - 30)):
                P(L, [("rect", nx, ny, nx + 2.6, ny + 2.4)], BONE, ol=0.4, bevel=0.6, form="flat")
            P(L, [("line", [(m - 4, BY - 36), (m + 4, BY - 37), (m + 6.6, BY - 33), (m - 3.6, BY - 29)], 0.15)],
              CLOTH_R, form="flat", ol=0)
    elif hero == "nyx_caldera":
        if stage == 1:  # dark footlocker
            crate(m - 7, m + 7, BY - 7, C(64, 56, 66))
            P(L, [("rect", m - 1, BY - 6.4, m + 1, BY - 4.6)], BRASS, ol=0.5, bevel=0.8, warm=1)
        elif stage == 3:  # crossed twin blades on the wall
            for (a, b) in (((m - 6, BY - 32), (m + 5, BY - 19)), ((m + 6, BY - 32), (m - 5, BY - 19))):
                P(L, [("line", [a, ((a[0] + b[0]) * 0.5 + (b[0] - a[0]) * 0.18, (a[1] + b[1]) * 0.5 + 1.4)], 0.9),
                      ("line", [((a[0] + b[0]) * 0.5 + (b[0] - a[0]) * 0.18, (a[1] + b[1]) * 0.5 + 1.4), b], 0.9)],
                  STEEL_L, form="flat", ol=1.0, bevel=1.0, grit=0.03)
            for (x, y) in ((m - 4.6, BY - 20.6), (m + 4.6, BY - 20.6)):
                P(L, [("ell", x, y, 1.2, 1.2)], LEATHER, form="sphere", ol=0.6, bevel=1)
        elif stage == 5:  # hooded cloak on a hook + a smoke-bomb pouch + amber lamp
            P(L, [("poly", [(m + 3, BY - 34), (m + 7, BY - 33), (m + 9, BY - 20), (m + 8, BY - 9), (m + 2.5, BY - 9),
                            (m + 1.8, BY - 22)])], C(60, 54, 64), ol=1.4, bevel=2.5, grit=0.12, form="cylv")
            P(L, [("ell", m + 5, BY - 33.4, 2.4, 2.2)], C(48, 44, 52), form="sphere", ol=1.0, bevel=1.5)
            glow(L, m - 4, BY - 13, 3.4, AMBER, 0.45)
            P(L, [("rect", m - 5.6, BY - 15.4, m - 2.4, BY - 10.4)], BRASS, ol=0.9, bevel=1)
            P(L, [("rect", m - 5, BY - 14.6, m - 3, BY - 11.4)], BULB, ol=0, form="flat")
            for k in range(3):
                P(L, [("ell", m - 6 + k * 2.4, BY - 8.6, 1.0, 1.0)], CHARC, form="sphere", ol=0.6, bevel=1)
    elif hero == "helm_wisp":
        if stage == 1:  # her scout drone on a maintenance stand
            shadow(L, m, BY + 0.5, 6, 1.4, 0.5)
            P(L, [("line", [(m - 4, BY), (m, BY - 9)], 0.6), ("line", [(m + 4, BY), (m, BY - 9)], 0.6)], STEEL_D,
              form="flat", ol=0.7)
            P(L, [("poly", [(m - 3.4, BY - 13), (m + 3.4, BY - 13), (m + 2.6, BY - 9.4), (m - 2.6, BY - 9.4)])],
              C(110, 116, 112), ol=1.4, bevel=1.8, wear=0.4, rust=0.15)
            P(L, [("line", [(m - 8, BY - 13.6), (m + 8, BY - 13.6)], 0.5)], STEEL_D, form="flat", ol=0.6)
            for x in (m - 8, m + 8):
                P(L, [("ell", x, BY - 14, 2.6, 0.5)], STEEL_L, form="flat", ol=0.5)
            glow(L, m, BY - 11, 1.6, C(150, 210, 180), 0.4)
            P(L, [("ell", m, BY - 11.2, 0.7, 0.7)], C(170, 220, 190), form="sphere", ol=0.4, bevel=0.8)
        elif stage == 3:  # a second drone hung on the wall + her toolbox
            P(L, [("poly", [(m - 7, BY - 28), (m - 1, BY - 28), (m - 1.6, BY - 25), (m - 6.4, BY - 25)])],
              C(96, 104, 100), ol=1.2, bevel=1.5, wear=0.3)
            P(L, [("line", [(m - 11, BY - 28.6), (m + 3, BY - 28.6)], 0.4)], STEEL_D, form="flat", ol=0.5)
            P(L, [("line", [(m - 4, BY - 33), (m - 4, BY - 28.6)], 0.25)], CHARC, form="flat", ol=0.3)
            shadow(L, m + 5, BY + 0.5, 5, 1.2, 0.5)
            P(L, [("rect", m + 1.5, BY - 5, m + 9.5, BY)], CLOTH_R * 0.95, ol=1.3, bevel=1.5, rust=0.35, wear=0.4)
            P(L, [("line", [(m + 3.5, BY - 5), (m + 4, BY - 6.6), (m + 7, BY - 6.6), (m + 7.5, BY - 5)], 0.4)], STEEL,
              form="flat", ol=0.5)
        elif stage == 5:  # the bent propeller from her plane + flight jacket on a peg
            P(L, [("poly", [(m - 9, BY - 1), (m - 7.6, BY - 2), (m - 2, BY - 18), (m - 0.6, BY - 30), (m - 2.4, BY - 30),
                            (m - 4, BY - 18)])], C(96, 90, 80), ol=1.4, bevel=1.5, rust=0.45, wear=0.4)
            P(L, [("ell", m - 2.6, BY - 17.4, 1.6, 1.6)], STEEL_D, form="sphere", ol=0.9, bevel=1)
            P(L, [("rect", m - 1.5, BY - 31, m - 0.5, BY - 28)], C(186, 150, 60), ol=0, form="flat")
            P(L, [("poly", [(m + 2, BY - 31), (m + 8, BY - 31), (m + 9.4, BY - 20), (m + 7, BY - 15), (m + 3, BY - 15),
                            (m + 0.6, BY - 20)])], LEATHER, ol=1.3, bevel=2, grit=0.12, wear=0.3, form="cylv")
            P(L, [("poly", [(m + 2.6, BY - 31), (m + 7.4, BY - 31), (m + 5, BY - 28.5)])], C(160, 140, 112), ol=0.6,
              bevel=1, grit=0.2)
    return L


# =========================================================== kennel, stash, trophies, cosmetics
PET_BED = {"noel": 110.0, "bentley": 125.0, "lillie": 140.0}  # bed centre x (art units)
PET_COL = {"noel": C(118, 118, 120), "bentley": C(178, 156, 116), "lillie": C(158, 96, 58)}
BED_Y = 141.0


def kennel(pet, stage):
    L = Layer()
    x = PET_BED[pet]
    col = PET_COL[pet]
    if stage == 1:  # a padded bed made from an old tyre + blanket
        shadow(L, x, BED_Y + 1.5, 7.2, 1.6, 0.6)
        P(L, [("ell", x, BED_Y, 6.6, 2.9)], CHARC, form="sphere", ol=1.5, bevel=2.2, grit=0.14)
        P(L, [("ell", x, BED_Y - 0.6, 5.0, 1.9)], col, form="sphere", ol=0.8, bevel=1.6, grit=0.14)
        P(L, [("poly", [(x - 4.5, BED_Y - 1), (x + 1, BED_Y - 2.2), (x + 4, BED_Y + 0.8), (x - 3, BED_Y + 1.4)])],
          col * 0.8 + CANVAS * 0.2, ol=0, bevel=1.2, grit=0.2, form="flat")
    elif stage == 2:  # dented bowl
        P(L, [("poly", [(x + 4.4, BED_Y + 3.4), (x + 8.6, BED_Y + 3.4), (x + 8.0, BED_Y + 5.2), (x + 5.0, BED_Y + 5.2)])],
          STEEL_L, ol=1.0, bevel=1.2, form="cylv", wear=0.3)
        P(L, [("ell", x + 6.5, BED_Y + 3.4, 2.1, 0.5)], C(110, 76, 50), form="flat", ol=0)
    elif stage == 3:  # carved name plank on a stake
        P(L, [("line", [(x - 5.6, BED_Y - 1), (x - 5.6, BED_Y - 9)], 0.6)], WOOD_D, form="flat", ol=0.7)
        P(L, [("poly", [(x - 9, BED_Y - 11.4), (x - 2, BED_Y - 11.8), (x - 2.2, BED_Y - 8.6), (x - 9.2, BED_Y - 8.4)])],
          WOOD, ol=1.1, bevel=1.2, grit=0.1, wear=0.3)
        for k in range(3):
            P(L, [("line", [(x - 8 + k * 2.0, BED_Y - 10.2), (x - 7 + k * 2.0, BED_Y - 9.6)], 0.25)], WOOD_D * 0.6,
              form="flat", ol=0)
        P(L, [("ell", x - 3.4, BED_Y - 10, 0.6, 0.6)], col, form="flat", ol=0)
    return L


def stash(stage):
    L = Layer()
    if stage == 0:  # the lockbox: olive footlocker with a brass hasp, in the door light
        shadow(L, 120, 112.5, 13, 2.2, 0.6)
        P(L, [("rect", 108, 102, 132, 112)], OLIVE, ol=2.0, bevel=2.6, rust=0.3, wear=0.35, streaks=0.6)
        P(L, [("rect", 107.5, 100, 132.5, 103.4)], OLIVE_D, form="cylh", ol=1.6, bevel=1.6, rust=0.3, wear=0.3)
        for x in (110, 129):
            P(L, [("rect", x, 100.5, x + 1.4, 112)], STEEL_D, ol=0.6, bevel=0.8, rust=0.4)
        P(L, [("rect", 118.6, 103, 121.4, 106.6)], BRASS, ol=1.0, bevel=1.2, warm=1)
        P(L, [("rect", 114, 107, 126, 109.6)], C(170, 150, 104) * 0.8, ol=0.4, form="flat", grit=0.18)
    elif stage == 1:  # a second crate on the left
        shadow(L, 102, 112.5, 7, 1.6, 0.55)
        P(L, [("rect", 95.5, 104, 107.5, 112)], WOOD, ol=1.6, bevel=2, grit=0.12, wear=0.3)
        P(L, [("line", [(96.2, 104.8), (106.8, 111.2)], 0.5)], WOOD_D, form="flat", ol=0)
        rivets(L, [(96.4, 104.8), (106.6, 104.8)], STEEL)
    elif stage == 2:  # a steel ammo chest on the right
        shadow(L, 138, 112.5, 7, 1.6, 0.55)
        P(L, [("rect", 132.5, 104.5, 144, 112)], C(70, 84, 82), ol=1.6, bevel=2, rust=0.4, wear=0.35)
        P(L, [("rect", 136.5, 103.2, 140, 104.6)], STEEL_D, ol=0.6, bevel=0.8)
    elif stage == 3:  # a strongbox on top of the stack
        P(L, [("rect", 112, 92.5, 128, 100)], C(84, 70, 60), ol=1.6, bevel=2, rust=0.35, wear=0.35)
        P(L, [("rect", 118.8, 94.6, 121.2, 97.4)], BRASS, ol=0.7, bevel=1, warm=1)
        for x in (113, 126.4):
            P(L, [("rect", x, 92.5, x + 0.9, 100)], STEEL_D, ol=0, bevel=0.8)
    return L


def trophy(boss):
    L = Layer()
    if boss == "wall":  # an empty plank board above the door
        P(L, [("rect", 103, 29, 137, 39.5)], WOOD_D, ol=1.6, bevel=2, grit=0.12, wear=0.2,
          tex=lambda h, w: 0.1 * ((np.arange(h)[:, None] // 11) % 2) + 0.05 * np.sin(np.arange(w)[None, :] * 0.05))
        for x in (106, 134):
            rivets(L, [(x, 31), (x, 37.5)], STEEL)
    elif boss == "dread_naught":  # the war-machine's cracked visor plate
        P(L, [("poly", [(108, 30), (118, 30), (119, 34), (117, 38.5), (109, 38.5), (107, 34)])], STEEL, ol=1.5,
          bevel=2, rust=0.4, wear=0.4)
        P(L, [("rect", 109.5, 33, 116.5, 34.6)], CHARC, ol=0, form="flat")
        glow(L, 111, 33.8, 1.8, C(220, 70, 50), 0.4)
        glow(L, 115, 33.8, 1.8, C(220, 70, 50), 0.4)
        P(L, [("line", [(113, 30), (112, 33), (114, 36)], 0.2)], INK, form="flat", ol=0)
    elif boss == "mutant_overlord":  # horned mutant skull
        bone = C(170, 156, 124)
        for sgn in (-1, 1):  # curled horns
            P(L, [("line", [(128 + sgn * 3.2, 31.6), (128 + sgn * 6.4, 29.6), (128 + sgn * 7.4, 26.4), (128 + sgn * 6.2, 24.6)], 1.1)],
              C(120, 104, 80), form="flat", ol=1.0, bevel=1.0, grit=0.1)
        P(L, [("poly", [(124, 30.5), (128, 29.2), (132, 30.5), (133, 33.5), (131.4, 36), (130.6, 39.4), (125.4, 39.4),
                        (124.6, 36), (123, 33.5)])], bone, form="sphere", ol=1.5, bevel=2.2, grit=0.08, rust=0.15)
        for x in (126.0, 130.0):
            P(L, [("poly", [(x - 1.4, 33.2), (x + 1.3, 33.0), (x + 0.6, 35.0), (x - 1.0, 35.0)])], C(28, 30, 22), form="flat", ol=0)
            glow(L, x, 34.1, 1.4, TONIC, 0.4)
        P(L, [("poly", [(127.4, 35.8), (128.6, 35.8), (128, 37)])], C(40, 34, 28), form="flat", ol=0)
        for k in range(4):
            P(L, [("rect", 125.8 + k * 1.15, 38.2, 126.5 + k * 1.15, 39.6)], C(210, 196, 160), ol=0.3, form="flat")
        P(L, [("line", [(129.5, 30), (130.5, 32), (129.6, 33)], 0.18)], INK, form="flat", ol=0)
    return L


def cosmetic(cz):
    L = Layer()
    if cz == "banner":  # Generator maxed: a painted canvas banner hung from a rib
        P(L, [("line", [(48, 14), (70, 12.5)], 0.6)], STEEL_D, form="flat", ol=0.8)
        pts = [(49, 14.5), (69, 13), (69.5, 36), (64.5, 41), (59, 37.5), (53.5, 41.5), (49, 37)]
        P(L, pts and [("poly", pts)], CANVAS * 0.9, ol=1.4, bevel=2.5, grit=0.14, form="cylv", rust=0.15)
        P(L, [("ell", 59.2, 24, 5.4, 5.4), ("-ell", 59.2, 24, 4.0, 4.0)], CLOTH_R, form="flat", ol=0, grit=0.15)
        P(L, [("poly", [(59.2, 19.6), (61, 24), (59.2, 28.4), (57.4, 24)])], AMBER * 0.85, form="flat", ol=0, grit=0.1)
        P(L, [("line", [(50, 33), (68.6, 32)], 0.5)], CLOTH_R, form="flat", ol=0)
    elif cz == "flag":  # 25 extracts: tattered flag on a pole off a rib
        P(L, [("line", [(206, 12), (192, 18)], 0.5)], STEEL_L, form="flat", ol=0.7)
        P(L, [("poly", [(204.5, 13), (205, 30), (201, 28.5), (198.5, 31.5), (194, 27), (193.5, 18.4)])], TEALD,
          ol=1.2, bevel=2, grit=0.15, form="cylv")
        P(L, [("line", [(196, 22), (203, 20)], 0.6)], BONE, form="flat", ol=0)
    elif cz == "campfire":  # every station r3: a burning oil drum
        shadow(L, 153, 145.5, 6, 1.6, 0.6)
        glow(L, 153, 128, 12, AMBER, 0.28)
        soft(L, [("ell", 153, 146, 16, 3)], C(255, 170, 90), 0.18, 5)
        P(L, [("rect", 148.5, 131, 157.5, 145.5)], RUST, form="cylv", ol=1.6, bevel=2, rust=0.6, streaks=1.2)
        for y in (134.5, 141.5):
            P(L, [("rect", 148.5, y, 157.5, y + 1)], RUST * 0.7, form="cylv", ol=0, bevel=1)
        P(L, [("ell", 153, 131, 4.5, 1.2)], CHARC, form="flat", ol=1.0)
        flame(L, 153, 131.2, 3.6, 8)
        soft(L, [("ell", 154, 116, 3, 4), ("ell", 156, 108, 4, 4)], C(110, 100, 92), 0.25, 5)
    elif cz == "toys":  # kennel maxed: ball + rope toy by the beds
        P(L, [("ell", 101.5, 145.6, 1.7, 1.7)], CLOTH_R, form="sphere", ol=1.0, bevel=1.4)
        P(L, [("line", [(144.5, 146.5), (149, 145)], 0.9)], CANVAS, form="flat", ol=0.8, bevel=1, grit=0.2)
        for x in (144.2, 149.3):
            P(L, [("ell", x, 146.4 - (x - 144.2) * 0.3, 0.8, 0.8)], CANVAS * 0.8, form="sphere", ol=0.6, bevel=0.8)
    elif cz == "case":  # first Legendary: glass display case on the right door leaf
        P(L, [("rect", 152, 47, 166, 63)], WOOD_D, ol=1.5, bevel=1.6, grit=0.1)
        P(L, [("rect", 153.2, 48.2, 164.8, 61.8)], C(70, 86, 88), ol=0, bevel=1, form="flat")
        glow(L, 159, 55, 4, AMBER, 0.3)
        P(L, [("line", [(155, 60), (163, 50)], 0.8)], C(200, 160, 80), form="flat", ol=0.6, warm=1)
        P(L, [("line", [(154, 49), (157, 52.5)], 0.3), ("line", [(161, 49), (164, 52.5)], 0.25)],
          C(200, 220, 220), form="flat", ol=0, alpha=0.6)
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
    # side by side with a hero portrait at the same on-screen pixel density
    hero = Image.open("assets/sprites/characters/sister_cinder/sister_cinder.png").convert("RGBA")
    crop_ = full.crop((int(150 * S), int(60 * S), int(210 * S), int(100 * S)))
    hs = crop_.height
    hero = hero.resize((hs, hs), Image.NEAREST)
    pet = Image.open("assets/sprites/portraits/pet_noel.png").convert("RGBA").resize((hs, hs), Image.LANCZOS)
    cmp_ = Image.new("RGBA", (crop_.width + hs * 2 + 20, hs), (30, 24, 20, 255))
    cmp_.alpha_composite(crop_, (0, 0))
    cmp_.alpha_composite(hero, (crop_.width + 10, 0))
    cmp_.alpha_composite(pet, (crop_.width + hs + 20, 0))
    cmp_.save(os.path.join(outdir, "compare_with_hero.png"))


if __name__ == "__main__":
    rects = build()
    print(len(rects), "hangar layers ->", OUT)
    if "--preview" in sys.argv:
        previews(sys.argv[sys.argv.index("--preview") + 1], rects)
