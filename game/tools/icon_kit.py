"""Pixel-icon kit for Wanderer (style bible §6.5).

Icons are described once as primitives in a 48-unit box and rasterised natively
at 48 px and at 24 px (no downscaling). Every primitive is one material part;
parts are shaded by rule so the whole set shares one light:
  * light from the top-left: exposed top/left edge = light tone,
    exposed bottom/right edge = shadow tone, body = base tone,
  * big parts get a shadow band on their lower-right half (form light),
  * a 1-3 px highlight at the part's top-left extreme (optional),
  * 1 px INK outline (4-connected) around the whole silhouette,
  * no alpha other than 0/255, no dither, colours only from the master palette.
"""
import math

import numpy as np
from PIL import Image, ImageDraw


def h(x):
    x = x.lstrip("#")
    return (int(x[0:2], 16), int(x[2:4], 16), int(x[4:6], 16))


INK = h("#140c0e")
BONE = h("#e9dfc9")
A = [h(c) for c in ("#1f1a1d", "#3a3436", "#5d5654", "#8f877e", "#e9dfc9")]
E = [h(c) for c in ("#3a2d27", "#5a4636", "#7c6550", "#a08669", "#c8b08a")]
RU = [h(c) for c in ("#3e1a12", "#763420", "#ad5a2a", "#d98a45")]
BR = [h(c) for c in ("#3e2a10", "#7a5520", "#b88a33", "#e8c972")]
ST = [h(c) for c in ("#1b222c", "#36424f", "#5e6d7a", "#9aa8ad")]
CL = [h(c) for c in ("#2a2a1c", "#59563a", "#8f8a5e")]
SK = [h(c) for c in ("#4a2420", "#8e4c3b", "#c98060", "#eeb48c")]
PL = [h(c) for c in ("#142a18", "#2b5a2c", "#57932f", "#9ccf3e", "#dcf58a")]
FL = [h(c) for c in ("#2e1830", "#5a3254", "#8a5474", "#c08aa0")]
D = [h(c) for c in ("#5e260c", "#a8520f", "#e88a1c", "#ffc040", "#fff2c0")]
BLOOD = h("#9a1e26")
TE = [h("#1f5a58"), h("#5cd2c0")]
SIG = h("#ff4836")
PALETTE = set([INK] + A + E + RU + BR + ST + CL + SK + PL + FL + D + [BLOOD] + TE + [SIG])

## Material ramps: (shadow, base, light, highlight)
M = {
    "steel": (ST[1], ST[2], ST[3], BONE),
    "gun": (ST[0], ST[1], ST[2], ST[3]),
    "brass": (BR[1], BR[2], BR[3], D[4]),
    "rust": (RU[1], RU[2], RU[3], BR[3]),
    "wood": (E[1], E[2], E[3], E[4]),
    "leather": (E[0], E[1], E[2], E[3]),
    "ash": (A[1], A[2], A[3], BONE),
    "bone": (A[3], E[4], BONE, BONE),
    "cloth": (CL[0], CL[1], CL[2], E[4]),
    "skin": (SK[1], SK[2], SK[3], BONE),
    "plague": (PL[1], PL[2], PL[3], PL[4]),
    "glow": (PL[2], PL[3], PL[4], PL[4]),
    "flesh": (FL[1], FL[2], FL[3], BONE),
    "dust": (D[1], D[2], D[3], D[4]),
    "fire": (D[2], D[3], D[4], BONE),
    "blood": (RU[0], BLOOD, BLOOD, SK[3]),
    "teal": (TE[0], TE[1], TE[1], BONE),
    "frost": (ST[2], ST[3], BONE, BONE),
    "signal": (RU[1], SIG, SIG, D[4]),
    "ink": (INK, INK, INK, INK),
    "dark": (A[0], A[1], A[2], A[3]),
}


class Icon:
    def __init__(self, S, f=1.0, ox=0.0, oy=0.0):
        self.S = S
        self.k = S / 48.0
        self.f, self.ox, self.oy = f, ox, oy
        self.part = np.full((S, S), -1, np.int32)
        self.parts = []  # (ramp, opts)
        self.remap = {}  # ramp -> ramp, applied as parts are added (variants)

    # ---------------------------------------------------------- raster core
    def _mask_from(self, fn):
        img = Image.new("L", (self.S, self.S), 0)
        fn(ImageDraw.Draw(img), self.k)
        return np.array(img) > 0

    def _add(self, m, ramp, **o):
        idx = len(self.parts)
        self.parts.append((self.remap.get(ramp, ramp), o))
        self.part[m] = idx
        return idx

    def T(self, x, y):
        return (24.0 + (x - 24.0) * self.f + self.ox, 24.0 + (y - 24.0) * self.f + self.oy)

    def _p(self, pts, k):
        out = []
        for (x, y) in pts:
            tx, ty = self.T(x, y)
            out.append((tx * k - 0.5, ty * k - 0.5))
        return out

    def poly(self, pts, ramp, **o):
        m = self._mask_from(lambda d, k: d.polygon(self._p(pts, k), fill=255))
        return self._add(m, ramp, **o)

    def rect(self, x0, y0, x1, y1, ramp, **o):
        return self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], ramp, **o)

    def ellipse(self, cx, cy, rx, ry, ramp, **o):
        m = self._ell(cx, cy, rx, ry)
        return self._add(m, ramp, **o)

    def circle(self, cx, cy, r, ramp, **o):
        return self.ellipse(cx, cy, r, r, ramp, **o)

    def _ell(self, cx, cy, rx, ry):
        S, k = self.S, self.k
        cx, cy = self.T(cx, cy)
        rx, ry = rx * self.f, ry * self.f
        yy, xx = np.mgrid[0:S, 0:S]
        px = (xx + 0.5) / k
        py = (yy + 0.5) / k
        return ((px - cx) / max(rx, 0.01)) ** 2 + ((py - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def ring(self, cx, cy, ro, ri, ramp, a0=None, a1=None, **o):
        S, k = self.S, self.k
        cx, cy = self.T(cx, cy)
        ro, ri = ro * self.f, ri * self.f
        yy, xx = np.mgrid[0:S, 0:S]
        px = (xx + 0.5) / k - cx
        py = (yy + 0.5) / k - cy
        r = np.sqrt(px * px + py * py)
        m = (r <= ro) & (r >= ri)
        if a0 is not None:
            ang = (np.degrees(np.arctan2(py, px)) + 360.0) % 360.0
            if a0 <= a1:
                m &= (ang >= a0) & (ang <= a1)
            else:
                m &= (ang >= a0) | (ang <= a1)
        return self._add(m, ramp, **o)

    def line(self, p0, p1, w, ramp, cap=True, **o):
        (x0, y0), (x1, y1) = p0, p1
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * w / 2.0, dx / L * w / 2.0
        pts = [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]
        m = self._mask_from(lambda d, k: d.polygon(self._p(pts, k), fill=255))
        if cap and w >= 3:
            m |= self._ell(x0, y0, w / 2, w / 2) | self._ell(x1, y1, w / 2, w / 2)
        return self._add(m, ramp, **o)

    def path(self, pts, w, ramp, **o):
        m = np.zeros((self.S, self.S), bool)
        for a, b in zip(pts, pts[1:]):
            m |= self._mask_from(lambda d, k, a=a, b=b: d.line(self._p([a, b], k), fill=255, width=max(1, int(round(w * self.f * k)))))
            if w >= 3:
                m |= self._ell(b[0], b[1], w / 2, w / 2)
        return self._add(m, ramp, **o)

    def star(self, cx, cy, ro, ri, n, ramp, rot=-90.0, **o):
        pts = []
        for i in range(n * 2):
            r = ro if i % 2 == 0 else ri
            a = math.radians(rot + i * 180.0 / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        return self.poly(pts, ramp, **o)

    def px(self, x, y, ramp, tone=1, **o):
        """A single pixel/texel (48-space coords), drawn flat."""
        m = np.zeros((self.S, self.S), bool)
        x, y = self.T(x, y)
        xi, yi = int(x * self.k), int(y * self.k)
        if 0 <= xi < self.S and 0 <= yi < self.S:
            m[yi, xi] = True
        o.setdefault("flat", tone)
        return self._add(m, ramp, **o)

    def cut_poly(self, pts):
        m = self._mask_from(lambda d, k: d.polygon(self._p(pts, k), fill=255))
        self.part[m] = -1

    def cut_rect(self, x0, y0, x1, y1):
        self.cut_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)])

    def cut_circle(self, cx, cy, r):
        self.part[self._ell(cx, cy, r, r)] = -1

    def cut_line(self, p0, p1, w):
        (x0, y0), (x1, y1) = p0, p1
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L * w / 2.0, dx / L * w / 2.0
        self.cut_poly([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)])

    # ------------------------------------------------------------- shading
    def render(self):
        S = self.S
        out = np.zeros((S, S, 4), np.uint8)
        P = self.part
        for idx, (ramp, o) in enumerate(self.parts):
            m = P == idx
            if not m.any():
                continue
            sh, base, li, hl = M[ramp]
            if "flat" in o:
                t = o["flat"]
                col = (sh, base, li, hl)[t] if isinstance(t, int) else t
                out[m, :3] = col
                out[m, 3] = 255
                continue
            pad = np.pad(m, 1)
            up = ~pad[:-2, 1:-1] & m
            lf = ~pad[1:-1, :-2] & m
            dn = ~pad[2:, 1:-1] & m
            rt = ~pad[1:-1, 2:] & m
            # Parts on top of other parts: only edges against *other* parts or
            # empty space count; that is the same test (pixel not in this part).
            tl = up | lf
            br = dn | rt
            tone = np.full((S, S), 1, np.int8)
            ys, xs = np.nonzero(m)
            span = max(xs.max() - xs.min(), ys.max() - ys.min()) + 1
            if span >= 7 and not o.get("noband", False):
                cx, cy = xs.mean(), ys.mean()
                diag = ((np.arange(S)[None, :] - cx) + (np.arange(S)[:, None] - cy)) / (span * 1.0)
                tone[(diag > o.get("band", 0.28)) & m] = 0
            tone[tl & ~br] = 2
            tone[br & ~tl] = 0
            tone[tl & br] = 1 if span >= 4 else 2
            if o.get("hl", True) and span >= 5:
                lit = np.nonzero(tl & ~br)
                if len(lit[0]):
                    score = lit[0] + lit[1]
                    order = np.argsort(score)
                    n = 1 if S <= 24 else (2 if span < 16 else 3)
                    for j in order[:n]:
                        tone[lit[0][j], lit[1][j]] = 3
            if "hlpos" in o:
                for (hx, hy) in o["hlpos"]:
                    hx, hy = self.T(hx, hy)
                    xi, yi = int(hx * self.k), int(hy * self.k)
                    if 0 <= xi < S and 0 <= yi < S and m[yi, xi]:
                        tone[yi, xi] = 3
            cols = np.array([sh, base, li, hl], np.uint8)
            out[m, :3] = cols[tone[m]]
            out[m, 3] = 255
        # INK outline, 4-connected
        op = out[:, :, 3] > 0
        pad = np.pad(op, 1)
        nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
        ring = nb & ~op
        out[ring, :3] = INK
        out[ring, 3] = 255
        return out


def to_img(a):
    return Image.fromarray(a, "RGBA")


def colours(a):
    m = a[:, :, 3] > 0
    return set(map(tuple, a[m][:, :3].reshape(-1, 3)))
