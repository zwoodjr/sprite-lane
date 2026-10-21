"""Zone ground tiles (bible 2.2): 256x256, seamless, exactly the zone's 4 ground
colours (crack / base / mid / speck), no outline, no single-pixel noise.
Cracks are 1 px crack colour with a speck lip on the lower-right; pebbles come
in 2-8 px clusters lit top-left. One generator, six surface kinds."""
import math
import random
import numpy as np
from pal import h

KINDS = {
    #          cell  crack_keep mid_amt pebbles grit  pits  ripples  plates
    "earth":   (46, 0.62, 0.30, 0.0026, 0.004, 0.0006, 0, 0),
    "sand":    (70, 0.30, 0.42, 0.0012, 0.002, 0.0002, 1, 0),
    "scrub":   (52, 0.45, 0.22, 0.0018, 0.003, 0.0008, 0, 0),
    "rubble":  (34, 0.55, 0.40, 0.0060, 0.003, 0.0010, 0, 1),
    "riverbed": (30, 0.95, 0.50, 0.0008, 0.001, 0.0002, 0, 0),
    "asphalt": (64, 0.50, 0.06, 0.0004, 0.045, 0.0004, 0, 0),
}


def _pnoise(W, H, rnd, octaves=7, fmax=(4, 5)):
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    n = np.zeros((H, W))
    for k in range(octaves):
        fx, fy = rnd.randint(1, fmax[0]), rnd.randint(1, fmax[1])
        ph = rnd.random() * 6.28
        amp = 1.0 / (1 + k * 0.4)
        n += amp * np.sin(2 * math.pi * (fx * xx / W + fy * yy / H) + ph)
        n += amp * 0.6 * np.sin(2 * math.pi * (fx * 2 * xx / W - fy * yy / H) + ph * 1.7)
    return n / np.abs(n).max()


def _wnoise(W, H, seed, sigma):
    """Tileable smoothed noise (gaussian with wrap-around), like the approved mock."""
    from scipy import ndimage as ndi
    rs = np.random.RandomState(seed)
    n = ndi.gaussian_filter(rs.randn(H, W), sigma, mode="wrap")
    return n / np.abs(n).max()


def tile(cols, kind="earth", seed=1, W=256, H=256):
    cell, crack_keep, mid_amt, pebbles, grit, pits, ripples, plates = KINDS[kind]
    rnd = random.Random(seed * 131 + sum(map(ord, kind)))  # stable across runs (no str hash)
    c0, c1, c2, c3 = [np.array(h(c), np.uint8) for c in cols]
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    n = _wnoise(W, H, rnd.randrange(1 << 30), 9) + 0.6 * _wnoise(W, H, rnd.randrange(1 << 30), 3)
    n /= np.abs(n).max()
    a = np.zeros((H, W, 3), np.uint8)
    a[:] = c1
    midm = n > 1 - 2 * mid_amt
    # 2 px checker band on the mid/base border (bible: allowed on ground tiles)
    band = (n > 1 - 2 * mid_amt - 0.05) & ~midm & (((xx // 1 + yy // 1) % 2) == 0)
    a[midm | band] = c2
    if kind == "scrub":
        # dry scrub tufts: little fans of crack-coloured blades, lit tips
        for _ in range(int(W * H * 0.0016)):
            x, y = rnd.randrange(W), rnd.randrange(H)
            for dx, dy, c in ((0, 0, c0), (1, 0, c0), (2, 0, c0), (3, 0, c0), (0, -1, c0), (1, -2, c0), (2, -1, c0),
                              (3, -2, c0), (4, -1, c0), (1, -3, c3), (3, -3, c3), (-1, -2, c3), (4, 1, c3), (2, 1, c3)):
                a[(y + dy) % H, (x + dx) % W] = c
    if ripples:
        # wind ripples: wavy 2 px dashes of speck over base->mid
        ph = _pnoise(W, H, rnd, 3, (2, 3)) * 3
        wave = np.sin(2 * math.pi * (yy / 16.0) + ph + np.sin(2 * math.pi * xx / 64.0) * 1.2)
        rip = (wave > 0.95) & (_wnoise(W, H, rnd.randrange(1 << 30), 6) > 0.25)
        a[rip] = c3
        a[np.roll(rip, 1, 0) & ~rip] = c1
    # Voronoi cracks (periodic)
    nsites = max(4, int(W * H / (cell * cell)))
    sites = np.array([[rnd.random() * W, rnd.random() * H] for _ in range(nsites)])
    S = np.concatenate([sites + [ox, oy] for ox in (-W, 0, W) for oy in (-H, 0, H)])
    jx = xx + 1.6 * np.sin(yy * 2 * math.pi * 10 / H + 1.0) + 1.0 * np.sin(yy * 2 * math.pi * 37 / H)
    jy = yy + 1.6 * np.sin(xx * 2 * math.pi * 9 / W + 2.0) + 1.0 * np.sin(xx * 2 * math.pi * 33 / W)
    if kind == "asphalt":
        jx, jy = xx + 0.6 * np.sin(yy * 2 * math.pi * 5 / H), yy + 0.6 * np.sin(xx * 2 * math.pi * 4 / W)
    d1 = np.full((H, W), 1e9)
    d2 = np.full((H, W), 1e9)
    for sx, sy in S:
        d = np.sqrt((jx - sx) ** 2 + (jy - sy) ** 2)
        m = d < d1
        d2 = np.where(m, d1, np.minimum(d2, d))
        d1 = np.where(m, d, d1)
    edge = (d2 - d1) < 1.05
    keep = _pnoise(W, H, rnd, 4, (6, 6))
    crack = edge & (keep > (1 - 2 * crack_keep))
    cr = crack.copy()
    blob = cr & np.roll(cr, 1, 0) & np.roll(cr, 1, 1) & np.roll(np.roll(cr, 1, 0), 1, 1)
    cr[blob] = False
    if kind == "riverbed":
        # dried mud: cells slightly raised (mid) with dark gaps and lit lips
        a[(d1 < cell * 0.32)] = c2
    a[cr] = c0
    lip = np.roll(np.roll(cr, 1, 0), 1, 1) & ~cr
    lipm = lip & (np.sin(xx * 2 * math.pi * 45 / W) + np.sin(yy * 2 * math.pi * 57 / H) > -0.2)
    a[lipm] = c3
    if plates:
        # broken concrete chunks: 4-9 px blocks, lit top/left edges, dark bottom/right
        for _ in range(int(W * H * 0.0009)):
            x, y = rnd.randrange(W), rnd.randrange(H)
            w_, h_ = rnd.randint(4, 9), rnd.randint(3, 6)
            for j in range(h_):
                for i in range(w_):
                    c = c2
                    if j == 0 or i == 0:
                        c = c3
                    if j == h_ - 1 or i == w_ - 1:
                        c = c0
                    a[(y + j) % H, (x + i) % W] = c
    # pebbles: clustered, lit top-left, shadow bottom-right
    for _ in range(int(W * H * pebbles)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        r = rnd.random()
        if r < 0.45:
            shape = [(0, 0, c3), (1, 0, c2), (0, 1, c2), (1, 1, c0)]
        elif r < 0.75:
            shape = [(0, 0, c3), (1, 0, c3), (2, 0, c2), (0, 1, c2), (1, 1, c2), (2, 1, c0), (1, 2, c0), (0, 2, c0)]
        else:
            shape = [(0, 0, c3), (1, 0, c0)]
        for gi in range(rnd.choice((1, 1, 2, 3))):
            ox, oy = (rnd.randint(-5, 5), rnd.randint(-3, 3)) if gi else (0, 0)
            for dx, dy, c in shape:
                a[(y + oy + dy) % H, (x + ox + dx) % W] = c
    for _ in range(int(W * H * grit)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        c = (c0 if kind == "asphalt" and rnd.random() < 0.5 else (c2 if rnd.random() < 0.6 else c3))
        a[y % H, x % W] = c
        a[y % H, (x + 1) % W] = c
    for _ in range(int(W * H * pits)):
        x, y = rnd.randrange(W), rnd.randrange(H)
        for dx, dy, c in ((0, 0, c0), (1, 0, c0), (2, 0, c1), (0, 1, c0), (1, 1, c0), (2, 1, c3), (1, 2, c3), (0, 2, c2)):
            a[(y + dy) % H, (x + dx) % W] = c
    return _deorphan(a)


def _deorphan(a):
    """Any pixel unlike all 4 neighbours takes the majority neighbour colour."""
    for _ in range(2):
        up, dn = np.roll(a, 1, 0), np.roll(a, -1, 0)
        lf, rt = np.roll(a, 1, 1), np.roll(a, -1, 1)
        same = lambda b: (a == b).all(-1)
        orphan = ~(same(up) | same(dn) | same(lf) | same(rt))
        if not orphan.any():
            break
        a = a.copy()
        a[orphan] = lf[orphan]
    return a


def lstar_share(a, cols):
    from pal import lab_L
    L = {tuple(h(c)): lab_L(h(c)) for c in cols}
    flat = a.reshape(-1, 3)
    vals = np.array([L[tuple(int(v) for v in p)] for p in flat[::7]])
    return float(((vals >= 30) & (vals <= 46)).mean())
