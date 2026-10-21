"""Track A pixel kit: world props, landmarks, ground and decals to STYLE_BIBLE v1.

Every colour comes from pal.py (master palette + zone ground colours). Light is
top-left (azimuth 135, elevation ~45). Sprites: 1 px exterior outline in tone 0
of the enclosed material (selout on the lit side for props >= 64 px), 3 tones +
highlight per material, alpha 0/255, no baked ground shadow (the engine draws
the hard 2-step contact ellipse)."""
import math
import random
import numpy as np
from scipy import ndimage as ndi
from pal import R, INK, BONE, ALL, TONE0, lab_L, h, ZONES, ORDER

A, E, RU, BR, ST = R("ash"), R("earth"), R("rust"), R("brass"), R("steel")
CL, SK, PL, FL, D = R("cloth"), R("skin"), R("plague"), R("flesh"), R("dust")
BL = R("blood")[0]
TE = R("teal")
SIG = h("#ff4836")

# colour -> (ramp name, index)
REV = {}
for _n in ORDER:
    for _i, _c in enumerate(R(_n)):
        REV[_c] = (_n, _i)

LV = np.array([-0.55, -0.6, 0.58])
LV = LV / np.linalg.norm(LV)


class Cv:
    def __init__(self, w, h_):
        self.w, self.h = w, h_
        self.a = np.zeros((h_, w, 4), np.uint8)

    def ok(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def px(self, x, y, c):
        x, y = int(x), int(y)
        if self.ok(x, y):
            self.a[y, x, :3] = c
            self.a[y, x, 3] = 255

    def get(self, x, y):
        x, y = int(x), int(y)
        if self.ok(x, y) and self.a[y, x, 3]:
            return tuple(int(v) for v in self.a[y, x, :3])
        return None

    def fill(self, m, c):
        self.a[m, :3] = c
        self.a[m, 3] = 255

    def opaque(self):
        return self.a[:, :, 3] > 0

    def rect(self, x0, y0, x1, y1, c):
        """inclusive rect"""
        x0, x1 = max(0, int(x0)), min(self.w - 1, int(x1))
        y0, y1 = max(0, int(y0)), min(self.h - 1, int(y1))
        if x1 >= x0 and y1 >= y0:
            self.a[y0:y1 + 1, x0:x1 + 1, :3] = c
            self.a[y0:y1 + 1, x0:x1 + 1, 3] = 255

    def grid(self):
        return np.mgrid[0:self.h, 0:self.w]


# ---------------------------------------------------------------- masks
def m_ellipse(cv, cx, cy, rx, ry):
    yy, xx = cv.grid()
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def m_poly(cv, pts):
    """Even-odd polygon fill (pixel centres)."""
    yy, xx = cv.grid()
    X, Y = xx + 0.5, yy + 0.5
    inside = np.zeros((cv.h, cv.w), bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if y1 == y2:
            continue
        cond = ((Y >= min(y1, y2)) & (Y < max(y1, y2)))
        xint = x1 + (Y - y1) * (x2 - x1) / (y2 - y1)
        inside ^= cond & (X < xint)
    return inside


def m_rect(cv, x0, y0, x1, y1):
    m = np.zeros((cv.h, cv.w), bool)
    m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True
    return m


def m_line(cv, p0, p1, w=1):
    m = np.zeros((cv.h, cv.w), bool)
    x0, y0 = p0
    x1, y1 = p1
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        for dx in range(w):
            for dy in range(w):
                xi, yi = int(round(x - (w - 1) / 2 + dx)), int(round(y - (w - 1) / 2 + dy))
                if 0 <= xi < cv.w and 0 <= yi < cv.h:
                    m[yi, xi] = True
    return m


def blob_noise(shape, scale, seed):
    rs = np.random.RandomState(seed)
    n = ndi.gaussian_filter(rs.randn(*shape), scale)
    return n / (np.abs(n).max() + 1e-9)


def clean_mask(m, min_n=2):
    """Drop pixels with fewer than min_n 4-neighbours in the mask (no orphans)."""
    for _ in range(2):
        nb = np.zeros(m.shape, int)
        nb[1:, :] += m[:-1, :]
        nb[:-1, :] += m[1:, :]
        nb[:, 1:] += m[:, :-1]
        nb[:, :-1] += m[:, 1:]
        m = m & (nb >= min_n)
    return m


# ---------------------------------------------------------------- shading
def light_tone(v, ramp, hl=True):
    """v = n.L in about [-1, 1] -> ramp colour (tones 1..3 + highlight)."""
    n = len(ramp)
    top = n - 1
    if hl and v > 0.9:
        return ramp[top]
    if v > 0.62:
        return ramp[min(3, top - (1 if n == 5 else 0))]
    if v > 0.3:
        return ramp[2]
    if v > -0.15:
        return ramp[1]
    return ramp[0] if n > 4 else ramp[1]


def dome(cv, m, ramp, flat=0.6, bias=0.0, hl=True, ao=True, power=0.5):
    """Smooth dome lighting quantised to the ramp (pillows, bags, bodies)."""
    if not m.any():
        return
    dt = ndi.distance_transform_edt(m)
    mx = dt.max()
    hgt = (dt / mx) ** power * mx * flat
    gy, gx = np.gradient(hgt)
    nz = np.ones_like(hgt)
    nrm = np.stack([-gx, -gy, nz], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    v = nrm @ LV + bias
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        cv.px(x, y, light_tone(v[y, x] * 1.25, ramp, hl))
    if ao:
        # AO on the bottom 1 px edge
        bot = m & ~np.roll(m, -1, 0)
        for y, x in zip(*np.nonzero(bot)):
            c = cv.get(x, y)
            if c in REV:
                rn, i = REV[c]
                cv.px(x, y, R(rn)[max(1 if len(R(rn)) > 2 else 0, min(i, 1))])


def facets(cv, m, ramp, seed=0, n=8, tilt=0.55, hl=True, flat=0.55):
    """Faceted rock: Voronoi facets, each with one normal (dome + jitter)."""
    if not m.any():
        return
    rnd = random.Random(seed)
    ys, xs = np.nonzero(m)
    dt = ndi.distance_transform_edt(m)
    hgt = np.sqrt(dt / dt.max()) * dt.max() * flat
    gy, gx = np.gradient(ndi.gaussian_filter(hgt, 1.2))
    sites = [(xs[k], ys[k]) for k in (rnd.randrange(len(xs)) for _ in range(n))]
    S = np.array(sites, float)
    lab = np.argmin((xs[:, None] - S[None, :, 0]) ** 2 + ((ys[:, None] - S[None, :, 1]) * 1.3) ** 2, 1)
    for k in range(n):
        sel = lab == k
        if not sel.any():
            continue
        yy, xx = ys[sel], xs[sel]
        nx = -gx[yy, xx].mean() + rnd.uniform(-tilt, tilt)
        ny = -gy[yy, xx].mean() + rnd.uniform(-tilt, tilt)
        nn = np.array([nx, ny, 1.0])
        nn /= np.linalg.norm(nn)
        v = nn @ LV
        # upper facets read as tops (more light)
        v += 0.25 * (1 - (yy.mean() - ys.min()) / max(1, ys.max() - ys.min())) - 0.1
        c = light_tone(v * 1.15, ramp, hl)
        for y, x in zip(yy, xx):
            cv.px(x, y, c)
    # crisp facet seams: darker 1 px on the shadow side of tone changes
    a = cv.a.copy()
    for y, x in zip(ys, xs):
        c = tuple(a[y, x, :3])
        if x + 1 < cv.w and m[y, x + 1] and y + 1 < cv.h and m[y + 1, x]:
            cr, cd = tuple(a[y, x + 1, :3]), tuple(a[y + 1, x, :3])
            if c in REV and cr in REV and REV[cr][1] > REV[c][1] + 1:
                pass
    ao_bottom(cv, m, 2)


def ao_bottom(cv, m, k=2):
    """k px of darker tone where the object meets the ground (bottom edge)."""
    ys, xs = np.nonzero(m)
    if not len(ys):
        return
    for x in np.unique(xs):
        col = ys[xs == x]
        yb = col.max()
        for j in range(k):
            y = yb - j
            if m[y, x]:
                c = cv.get(x, y)
                if c in REV:
                    rn, i = REV[c]
                    rr = R(rn)
                    cv.px(x, y, rr[max(0, min(i, 1) - (1 if j == 0 and len(rr) > 3 else 0))] if j == 0 else rr[max(1, min(i, 1))])


def cyl_tone(dx, extra=0.0):
    nz = math.sqrt(max(0.0, 1 - dx * dx))
    i = -0.62 * dx + 0.55 * nz + extra
    if dx > 0.86:
        return 1
    if i > 0.80:
        return 3
    if i > 0.38:
        return 2
    if i > -0.05:
        return 1
    return 0


def cyl_v(cv, cx, rx, ry, yt, yb, ramp, top_ramp=None, rim=True, hollow=False, top=True, lo=0):
    """Vertical cylinder (axis up), 3/4 view: side wall + top ellipse."""
    top_ramp = top_ramp or ramp
    n = len(ramp)
    for y in range(cv.h):
        for x in range(cv.w):
            dx = (x + 0.5 - cx) / rx
            if abs(dx) > 1:
                continue
            f = ry * math.sqrt(max(0, 1 - dx * dx))
            if yt + f - 0.5 <= y + 0.5 <= yb + f:
                v = (y + 0.5 - (yt + f)) / max(1, (yb - yt))
                t = cyl_tone(dx, 0.18 * (0.45 - v))
                t = max(lo, min(n - 1 if n == 4 else 3, t))
                if y + 0.5 > yb + f - 2:
                    t = max(0, t - 1)
                cv.px(x, y, ramp[t])
    if not top:
        return
    for y in range(cv.h):
        for x in range(cv.w):
            ox = (x + 0.5 - cx) / rx
            oy = (y + 0.5 - yt) / ry
            if ox * ox + oy * oy <= 1:
                ix = (x + 0.5 - cx) / max(1, rx - 2)
                iy = (y + 0.5 - yt) / max(1, ry - 1.5)
                inner = ix * ix + iy * iy <= 1
                if hollow and inner:
                    cv.px(x, y, top_ramp[0] if iy < 0.2 else top_ramp[1])
                elif rim and not inner:
                    ang = math.atan2(oy, ox)
                    lit = -math.cos(ang) * 0.6 - math.sin(ang) * 0.8
                    cv.px(x, y, top_ramp[min(len(top_ramp) - 1, 3)] if lit > 0.45 else (top_ramp[2] if lit > -0.35 else top_ramp[1]))
                else:
                    lit = -ox * 0.5 - oy * 0.4
                    cv.px(x, y, top_ramp[3] if lit > 0.25 and len(top_ramp) > 3 else top_ramp[2])


def cyl_h(cv, x0, x1, yc, r, ramp, cap_left=True, cap_right=False):
    """Horizontal cylinder (pipe / log / drum on its side) along x."""
    n = len(ramp)
    for x in range(int(x0), int(x1) + 1):
        for k in range(-r, r + 1):
            y = yc + k
            v = -k / max(1, r)  # +1 top
            t = 3 if v > 0.45 else (2 if v > -0.2 else 1)
            if k == r:
                t = max(0, t - 1) if n > 4 else 1
            t = min(t, n - 1)
            cv.px(x, y, ramp[t])
    for cx, lit in ((x0, cap_left), (x1, cap_right)):
        if not lit:
            continue
        # end cap: an ellipse facing the viewer-left, lit (faces the light),
        # with a darker rim ring and a centre boss
        rx = max(2, int(round(r * 0.45)))
        for y in range(yc - r, yc + r + 1):
            for x in range(int(cx) - rx, int(cx) + rx + 1):
                e = ((x + 0.5 - cx) / (rx + 0.5)) ** 2 + ((y + 0.5 - yc - 0.5) / (r + 0.5)) ** 2
                if e <= 1:
                    c = ramp[min(n - 1, 3)] if (y < yc and x <= cx) else ramp[2]
                    if e > 0.6:
                        c = ramp[min(n - 1, 2)] if y < yc else ramp[1]
                    cv.px(x, y, c)
        if r >= 4:
            cv.px(cx, yc, ramp[1]); cv.px(cx, yc + 1, ramp[1])


def box(cv, x, y, w, hf, d, ramp, top_ramp=None, edge=True, ao=True, left_hl=True):
    """3/4-view box: top face (d rows, lit) above a front face (hf rows).
    (x, y) is the top-left of the top face."""
    top_ramp = top_ramp or ramp
    n, nt = len(ramp), len(top_ramp)
    cv.rect(x, y, x + w - 1, y + d - 1, top_ramp[min(3, nt - 1)])
    if edge and d > 1:
        cv.rect(x, y, x + w - 1, y, top_ramp[nt - 1])
    cv.rect(x, y + d, x + w - 1, y + d + hf - 1, ramp[2])
    if hf > 2:
        cv.rect(x, y + d, x + w - 1, y + d, ramp[min(3, n - 1)] if n > 3 else ramp[2])
    if left_hl and hf > 2:
        cv.rect(x, y + d, x, y + d + hf - 1, ramp[min(3, n - 1)])
    if ao and hf > 3:
        cv.rect(x, y + d + hf - 1, x + w - 1, y + d + hf - 1, ramp[1])


def tone_of(c):
    return REV.get(c, (None, None))


def retone(cv, m, ramp):
    """Repaint masked pixels into another ramp, keeping their tone index."""
    for y, x in zip(*np.nonzero(m & cv.opaque())):
        c = cv.get(x, y)
        if c in REV:
            i = REV[c][1]
            cv.px(x, y, ramp[min(i, len(ramp) - 1)])


def shift(cv, m, d):
    for y, x in zip(*np.nonzero(m & cv.opaque())):
        c = cv.get(x, y)
        if c in REV:
            rn, i = REV[c]
            rr = R(rn)
            cv.px(x, y, rr[max(0, min(len(rr) - 1, i + d))])


def mask_of(cv, ramp):
    s = set(ramp)
    out = np.zeros((cv.h, cv.w), bool)
    op = cv.opaque()
    for y, x in zip(*np.nonzero(op)):
        if tuple(int(v) for v in cv.a[y, x, :3]) in s:
            out[y, x] = True
    return out


def blotch(cv, region, ramp, seed, scale=2.0, thresh=0.35):
    """Clustered patches (rust, grime) re-toned into `ramp`; no single pixels."""
    n = blob_noise((cv.h, cv.w), scale, seed)
    m = clean_mask(region & (n > thresh))
    retone(cv, m, ramp)
    return m


def streaks(cv, region, ramp, seed, count=6, lmin=4, lmax=12, d=-1):
    rnd = random.Random(seed)
    ys, xs = np.nonzero(region)
    if not len(ys):
        return
    for _ in range(count):
        k = rnd.randrange(len(ys))
        x, y = xs[k], ys[k]
        L = rnd.randint(lmin, lmax)
        for j in range(L):
            if region[min(cv.h - 1, y + j), x]:
                c = cv.get(x, y + j)
                if c in REV:
                    i = REV[c][1]
                    cv.px(x, y + j, ramp[max(1, min(len(ramp) - 1, i + d))] if ramp is not None else c)


def rivet(cv, x, y, ramp=BR):
    cv.px(x, y, ramp[3] if len(ramp) > 3 else ramp[-1])
    cv.px(x + 1, y + 1, ramp[0])


def hazard(cv, x0, y0, w, hh, ramp=BR, period=3, shade=0):
    for j in range(hh):
        for i in range(w):
            on = ((i + j) // period) % 2 == 0
            c = ramp[max(1, 2 - shade)] if on else INK
            if j == 0 and on:
                c = ramp[min(3, 3 - shade)]
            cv.px(x0 + i, y0 + j, c)


def remove_orphans(cv, keep=()):
    a = cv.a
    b = a.copy()
    H, W = a.shape[:2]
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if a[y, x, 3] == 0 or (x, y) in keep:
                continue
            c = tuple(a[y, x, :3])
            nbs = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if a[y + dy, x + dx, 3]]
            if len(nbs) == 4 and c not in nbs:
                best = max(set(nbs), key=nbs.count)
                b[y, x, :3] = best
    cv.a = b


def outline(cv, selout=None):
    """1 px 4-connected exterior outline in tone 0 of the neighbouring material.
    selout (default: sprite >= 64 px): lit top-left side uses tone 1."""
    a = cv.a
    m = a[:, :, 3] > 0
    if selout is None:
        ys, xs = np.nonzero(m)
        selout = len(ys) and max(ys.max() - ys.min(), xs.max() - xs.min()) >= 62
    # grow canvas by 1 where needed is the caller's job (leave a 1 px margin)
    H, W = m.shape
    out = a.copy()
    for y in range(H):
        for x in range(W):
            if m[y, x]:
                continue
            nb = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and m[yy, xx]:
                    nb.append((dx, dy, tuple(int(v) for v in a[yy, xx, :3])))
            if not nb:
                continue
            # prefer the darkest-material neighbour for the outline colour
            c = nb[0][2]
            t0 = TONE0.get(c, INK)
            lit = all(dx >= 0 and dy >= 0 for dx, dy, _ in nb)
            if selout and lit and c in REV:
                rn, i = REV[c]
                rr = R(rn)
                if len(rr) > 2 and lab_L(rr[1]) < lab_L(c) + 1:
                    t0 = rr[1]
            out[y, x, :3] = t0
            out[y, x, 3] = 255
    cv.a = out


def finish(cv, selout=None, orphans=True, keep=()):
    if orphans:
        for _ in range(3):
            remove_orphans(cv, keep)
    rim0 = ~cv.opaque()
    outline(cv, selout)
    if orphans:
        _post_orphans(cv, rim0, keep)
    return crop(cv)


def _post_orphans(cv, was_empty, keep=()):
    """After outlining: interior pixels that became orphans next to the new rim
    take their most common non-rim neighbour (rim pixels stay)."""
    a = cv.a
    rim = was_empty & (a[:, :, 3] > 0)
    H, W = a.shape[:2]
    for _ in range(2):
        b = a.copy()
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if a[y, x, 3] == 0 or rim[y, x] or (x, y) in keep:
                    continue
                c = tuple(a[y, x, :3])
                nbs = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if a[y + dy, x + dx, 3]]
                if len(nbs) == 4 and c not in nbs:
                    inner = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if not rim[y + dy, x + dx]] or nbs
                    b[y, x, :3] = max(set(inner), key=inner.count)
        a = b
    cv.a = a


def crop(cv, pad=0):
    m = cv.opaque()
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    out = Cv(x1 - x0 + 1 + 2 * pad, y1 - y0 + 1 + 2 * pad)
    out.a[pad:pad + y1 - y0 + 1, pad:pad + x1 - x0 + 1] = cv.a[y0:y1 + 1, x0:x1 + 1]
    return out


def flip(cv):
    o = Cv(cv.w, cv.h)
    o.a = cv.a[:, ::-1].copy()
    return o


def paste(dst, src, x, y):
    for j in range(src.h):
        for i in range(src.w):
            if src.a[j, i, 3]:
                dst.px(x + i, y + j, tuple(int(v) for v in src.a[j, i, :3]))


# ---------------------------------------------------------------- validator
CAP = {"prop": 24, "decal": 24, "tile": 4}


def validate(cv_or_arr, kind="prop", zone_cols=(), size_max=None, name="", glints=0):
    a = cv_or_arr.a if isinstance(cv_or_arr, Cv) else cv_or_arr
    errs = []
    al = a[:, :, 3]
    if not np.isin(al, (0, 255)).all():
        errs.append("alpha not 0/255")
    op = al > 0
    cols = set(map(tuple, a[op][:, :3].tolist()))
    pal = set(ALL) | set(h(c) for c in zone_cols)
    bad = [c for c in cols if c not in pal]
    if bad:
        errs.append("off-palette %d e.g. %s" % (len(bad), bad[:3]))
    cap = CAP.get(kind, 24)
    nc = len(cols)
    if kind == "tile":
        nc = len([c for c in cols if c in set(h(x) for x in zone_cols)])
        if len(cols) > 4:
            errs.append("tile colours %d > 4" % len(cols))
    else:
        # cap excludes the outline (tone-0 colours used only on the rim)
        inner = op.copy()
        rim = op & ~ndi.binary_erosion(op)
        inner_cols = set(map(tuple, a[op & ~rim][:, :3].tolist()))
        if len(inner_cols) > cap:
            errs.append("colours %d > %d" % (len(inner_cols), cap))
        nc = len(inner_cols)
    # orphans
    H, W = al.shape
    orph = 0
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if not op[y, x]:
                continue
            c = tuple(a[y, x, :3])
            nbs = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if op[y + dy, x + dx]]
            dg = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)) if op[y + dy, x + dx]]
            # isolated = unlike all 8 neighbours (checker dither bands and
            # 1 px staircase lines keep a same-colour diagonal)
            if len(nbs) == 4 and c not in nbs and c not in dg:
                orph += 1
    if orph > max(8, op.sum() // 150) + glints:  # rivets / glints / spines are allowed
        errs.append("orphans %d" % orph)
    ys, xs = np.nonzero(op)
    bb = (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)) if len(ys) else (0, 0)
    if size_max and (bb[1] > size_max[0] or bb[0] > size_max[1]):
        errs.append("bbox %s > %s" % (bb, size_max))
    return {"name": name, "colors": nc, "orphans": orph, "bbox": bb, "errors": errs}


# ---------------------------------------------------------------- more shapes
def beam(cv, p0, p1, w, ramp, cap=True):
    """Thick straight member (pole, log, girder) shaded across its width:
    the side facing up-left is lit."""
    x0, y0 = p0
    x1, y1 = p1
    L = math.hypot(x1 - x0, y1 - y0)
    if L < 1e-6:
        return np.zeros((cv.h, cv.w), bool)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny = -uy, ux
    if nx * -0.7 + ny * -0.7 < 0:
        nx, ny = -nx, -ny  # n points toward the light
    yy, xx = cv.grid()
    X, Y = xx + 0.5 - x0, yy + 0.5 - y0
    t = X * ux + Y * uy
    s = X * nx + Y * ny
    m = (t >= 0) & (t <= L) & (np.abs(s) <= w / 2)
    n = len(ramp)
    for y, x in zip(*np.nonzero(m)):
        v = s[y, x] / (w / 2)
        tt = 3 if v > 0.45 else (2 if v > -0.3 else 1)
        if w <= 2:
            tt = 2 if v > 0 else 1
        cv.px(x, y, ramp[min(tt, n - 1)])
    return m


def face(cv, pts, c, edge_hi=None, edge_lo=None):
    """Flat polygon face; optional lit top edge / dark bottom edge."""
    m = m_poly(cv, pts)
    cv.fill(m, c)
    if edge_hi is not None:
        cv.fill(m & ~np.roll(m, 1, 0), edge_hi)
    if edge_lo is not None:
        cv.fill(m & ~np.roll(m, -1, 0), edge_lo)
    return m


def bricks(cv, region, ramp, bw=8, bh=4, seed=0, mortar=None):
    """Brick / block coursing inside a region (keeps existing tones as light)."""
    rnd = random.Random(seed)
    ys, xs = np.nonzero(region)
    if not len(ys):
        return
    for y, x in zip(ys, xs):
        row = y // bh
        off = (bw // 2) * (row % 2)
        if y % bh == bh - 1 or (x + off) % bw == bw - 1:
            c = cv.get(x, y)
            if c in REV:
                rn, i = REV[c]
                rr = R(rn)
                cv.px(x, y, mortar if mortar is not None else rr[max(0, i - 1)])
        elif (x + off) % bw == 0 or y % bh == 0:
            c = cv.get(x, y)
            if c in REV and rnd.random() < 0.7:
                rn, i = REV[c]
                rr = R(rn)
                cv.px(x, y, rr[min(len(rr) - 1, i + 1)] if rn != "ash" or i + 1 < 4 else c)


def chainlink(cv, region, c, step=4):
    ys, xs = np.nonzero(region)
    for y, x in zip(ys, xs):
        if (x + y) % step == 0 or (x - y) % step == 0:
            cv.px(x, y, c)


def wheel(cv, cx, cy, r, side=True):
    """Car wheel in 3/4 side view: dark tyre, small steel hub, lit top."""
    m = m_ellipse(cv, cx, cy, r * 0.6, r)
    hub = m_ellipse(cv, cx + 0.5, cy, r * 0.26, r * 0.42)
    for y, x in zip(*np.nonzero(m)):
        dy = (y + 0.5 - cy) / r
        cv.px(x, y, A[2] if dy < -0.7 else (A[1] if dy < 0.6 else A[0]))
    for y, x in zip(*np.nonzero(hub)):
        dy = (y + 0.5 - cy) / (r * 0.42)
        cv.px(x, y, ST[2] if dy < -0.2 else ST[1])
