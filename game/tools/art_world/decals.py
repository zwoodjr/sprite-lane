"""Floor decals per zone (bible 2.2): tracks, puddles, rubble edges, cracks...
No outline, alpha 0/255, zone ground colours + material ramps. Tyre tracks
come pre-drawn in 4 directions (pixel art is never rotated)."""
import math
import random
import numpy as np
from scipy import ndimage as ndi
from pk import *

SIZES = {"crack": (92, 60, 3), "pebbles": (42, 28, 3), "bones": (46, 28, 3), "grass": (34, 26, 3),
         "oil": (64, 34, 2), "scrap": (30, 22, 3), "stain": (96, 56, 2), "toxic": (54, 34, 2),
         "tracksh": (196, 34, 2), "tracksv": (34, 196, 2), "tracksd": (150, 150, 2), "tracksa": (150, 150, 2),
         "crater": (92, 62, 2), "rubble": (84, 46, 3), "debris": (64, 40, 3), "tufts": (70, 40, 3)}


def zc(zone):
    return [h(c) for c in zone[2]]


def crack(z, seed):
    c0, c1, c2, c3 = zc(z)
    W, H_ = SIZES["crack"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)

    def walk(x, y, ang, L, depth):
        for i in range(L):
            x += math.cos(ang); y += math.sin(ang)
            ang += rnd.uniform(-0.35, 0.35)
            xi, yi = int(round(x)), int(round(y))
            if not (1 <= xi < W - 2 and 1 <= yi < H_ - 2):
                return
            cv.px(xi, yi, c0)
            if not cv.get(xi + 1, yi + 1):
                cv.px(xi + 1, yi + 1, c3)
            if depth < 2 and rnd.random() < 0.06:
                walk(x, y, ang + rnd.choice((-0.9, 0.9)), L // 2, depth + 1)
    walk(6, H_ / 2 + rnd.uniform(-8, 8), rnd.uniform(-0.3, 0.3), 90, 0)
    # widen the main fissure in the middle (2 px dark core)
    return cv


def pebbles(z, seed):
    c0, c1, c2, c3 = zc(z)
    W, H_ = SIZES["pebbles"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    for _ in range(9):
        x, y = rnd.randint(2, W - 6), rnd.randint(2, H_ - 6)
        w, hh = rnd.randint(2, 4), rnd.randint(2, 3)
        for j in range(hh):
            for i in range(w):
                c = c2
                if i == 0 or j == 0:
                    c = c3
                if i == w - 1 or j == hh - 1:
                    c = c0 if (i == w - 1 and j == hh - 1) else c1
                cv.px(x + i, y + j, c)
    return cv


def bones_d(z, seed):
    W, H_ = SIZES["bones"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    c0 = zc(z)[0]
    for _ in range(5):
        x, y = rnd.randint(4, W - 14), rnd.randint(4, H_ - 6)
        L = rnd.randint(5, 10)
        d = rnd.choice((0, 1))
        for i in range(L):
            yy = y + (i // 4 if d else 0)
            cv.px(x + i, yy, E[3]); cv.px(x + i, yy + 1, E[2]); cv.px(x + i + 1, yy + 2, c0)
        cv.px(x - 1, y, E[4]); cv.px(x - 1, y + 1, E[3]); cv.px(x + L, y + (L // 4 if d else 0), E[3])
    return cv


def grass(z, seed):
    W, H_ = SIZES["grass"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    c0 = zc(z)[0]
    for _ in range(3):
        bx, by = rnd.randint(6, W - 8), rnd.randint(12, H_ - 3)
        for k in range(7):
            ang = -math.pi / 2 + (k - 3) * 0.28 + rnd.uniform(-0.1, 0.1)
            L = rnd.randint(5, 11)
            for i in range(L):
                x = bx + math.cos(ang) * i
                y = by + math.sin(ang) * i
                cv.px(x, y, CL[2] if (i > L - 3 and k < 4) else (CL[1] if i > 2 else c0))
    return cv


def _pool(W, H_, seed, n=5):
    rnd = random.Random(seed)
    m = np.zeros((H_, W), bool)
    cv = Cv(W, H_)
    for _ in range(n):
        cx, cy = rnd.uniform(W * 0.25, W * 0.75), rnd.uniform(H_ * 0.3, H_ * 0.7)
        m |= m_ellipse(cv, cx, cy, rnd.uniform(W * 0.14, W * 0.24), rnd.uniform(H_ * 0.16, H_ * 0.26))
    return cv, m


def oil(z, seed):
    W, H_ = SIZES["oil"][:2]
    cv, m = _pool(W, H_, seed)
    inner = ndi.binary_erosion(m, iterations=2)
    # dark oil, but not a hole: ash-dark body, steel sheen on the lit rim
    cv.fill(m, A[0])
    cv.fill(inner, A[1])
    sheen = inner & ~np.roll(np.roll(inner, 2, 0), 2, 1)
    cv.fill(clean_mask(sheen), ST[1])
    ys, xs = np.nonzero(inner)
    if len(ys):
        k = len(ys) // 3
        cv.px(xs[k], ys[k], ST[2]); cv.px(xs[k] + 1, ys[k], ST[2])
    return cv


def toxic(z, seed):
    W, H_ = SIZES["toxic"][:2]
    cv, m = _pool(W, H_, seed)
    inner = ndi.binary_erosion(m, iterations=2)
    cv.fill(m, PL[0])
    cv.fill(ndi.binary_erosion(m, iterations=1), PL[1])
    cv.fill(inner, PL[2])
    ys, xs = np.nonzero(inner)
    rnd = random.Random(seed)
    for _ in range(3):
        k = rnd.randrange(len(ys))
        cv.px(xs[k], ys[k], PL[4]); cv.px(xs[k] + 1, ys[k], PL[3])
    return cv


def scrap(z, seed):
    W, H_ = SIZES["scrap"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    c0 = zc(z)[0]
    for _ in range(5):
        ramp = rnd.choice((RU, ST, BR, RU))
        x, y = rnd.randint(1, W - 8), rnd.randint(1, H_ - 6)
        w, hh = rnd.randint(3, 6), rnd.randint(2, 4)
        for j in range(hh):
            for i in range(w):
                cv.px(x + i, y + j, ramp[3] if j == 0 else ramp[2] if j < hh - 1 else ramp[1])
        for i in range(w):
            if not cv.get(x + i + 1, y + hh):
                cv.px(x + i + 1, y + hh, c0)
    return cv


def stain(z, seed):
    c0, c1, c2, c3 = zc(z)
    W, H_ = SIZES["stain"][:2]
    cv, m = _pool(W, H_, seed, 6)
    core = ndi.binary_erosion(m, iterations=4)
    # dark seep: crack colour core, 2 px checker band to the base colour edge
    band = m & ~core
    yy, xx = cv.grid()
    cv.fill(band & ((xx + yy) % 2 == 0), c0)
    cv.fill(core, c0)
    return cv


def tracks(z, seed, orient):
    c0, c1, c2, c3 = zc(z)
    W, H_ = SIZES["tracks" + orient][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    if orient == "h":
        for off in (6, 24):
            for x in range(2, W - 2):
                if rnd.random() < 0.88:
                    y = off + int(1.5 * math.sin(x / 40 + seed))
                    if x % 4 != 3:
                        cv.px(x, y, c0); cv.px(x, y + 1, c0)
                        cv.px(x, y + 2, c3)
                    else:
                        cv.px(x, y + 1, c0)
    elif orient == "v":
        for off in (6, 24):
            for y in range(2, H_ - 2):
                if rnd.random() < 0.88:
                    x = off + int(1.5 * math.sin(y / 40 + seed))
                    if y % 4 != 3:
                        cv.px(x, y, c0); cv.px(x + 1, y, c0)
                        cv.px(x + 2, y, c3)
                    else:
                        cv.px(x + 1, y, c0)
    else:
        for off in (0, 22):
            for i in range(3, W - 26):
                if rnd.random() < 0.88:
                    x = i + off
                    y = i if orient == "d" else H_ - 1 - i
                    if i % 4 != 3:
                        cv.px(x, y, c0); cv.px(x + 1, y, c0); cv.px(x + 2, y, c3)
                    else:
                        cv.px(x + 1, y, c0)
    return cv


def crater(z, seed, W=92, H_=62):
    """Ground crater: rim lit on the far (lower-right) inner wall, no outline."""
    c0, c1, c2, c3 = zc(z)
    cv = Cv(W, H_)
    cx, cy = W / 2, H_ / 2
    rx, ry = W / 2 - 3, H_ / 2 - 3
    rnd = random.Random(seed)
    yy, xx = cv.grid()
    dx = (xx + 0.5 - cx) / rx
    dy = (yy + 0.5 - cy) / ry
    r = np.sqrt(dx * dx + dy * dy)
    nz = blob_noise((H_, W), 2.0, seed) * 0.08
    r = r + nz
    lit = (dx + dy) > 0  # inner wall facing the top-left light: lower-right
    cv.fill((r < 1.0) & (r >= 0.78), c2)                 # raised lip (mid)
    cv.fill((r < 1.0) & (r >= 0.9) & ~lit, c3)            # lip catches light top-left
    cv.fill((r < 0.78) & ~lit, c0)                        # inner wall in shadow
    cv.fill((r < 0.78) & lit, c2)                         # far inner wall lit
    cv.fill((r < 0.5), c1)                                # floor
    cv.fill((r < 0.5) & ((xx + yy) % 2 == 0) & (r > 0.42) & ~lit, c0)
    # thrown debris clumps outside the lip
    for _ in range(14):
        t = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(1.02, 1.12)
        x, y = int(cx + math.cos(t) * rx * rr), int(cy + math.sin(t) * ry * rr)
        cv.px(x, y, c3); cv.px(x + 1, y, c2); cv.px(x + 1, y + 1, c0)
    return cv


def sinkhole(z, W, seed=4):
    """Sinkhole (Crater City twist): a deep pit, the far wall lit, dark core."""
    c0, c1, c2, c3 = zc(z)
    H_ = int(W * 0.62)
    cv = Cv(W, H_)
    cx, cy = W / 2, H_ / 2
    yy, xx = cv.grid()
    dx = (xx + 0.5 - cx) / (W / 2 - 2)
    dy = (yy + 0.5 - cy) / (H_ / 2 - 2)
    r = np.sqrt(dx * dx + dy * dy) + blob_noise((H_, W), 2.5, seed) * 0.06
    lit = (dx + dy * 1.4) > 0.1
    cv.fill(r < 1.0, c1)
    cv.fill((r < 1.0) & (r > 0.9) & ~lit, c3)
    cv.fill((r < 0.88) & lit, c2)
    cv.fill((r < 0.88) & ~lit, c0)
    cv.fill((r < 0.7), A[0])
    cv.fill((r < 0.52), INK)
    band = (r < 0.72) & (r >= 0.66) & ((xx + yy) % 2 == 0)
    cv.fill(band, c0)
    # broken-off edge chunks
    rnd = random.Random(seed)
    for _ in range(int(W / 6)):
        t = rnd.uniform(0, 2 * math.pi)
        x, y = int(cx + math.cos(t) * (W / 2 - 4) * 0.95), int(cy + math.sin(t) * (H_ / 2 - 4) * 0.95)
        cv.px(x, y, c3); cv.px(x + 1, y, c2); cv.px(x, y + 1, c1); cv.px(x + 1, y + 1, c0)
    return cv


def _chunk(cv, x, y, w, hh, ramp, c0):
    """Small lit rubble chunk: top-left lit, bottom-right shade, ground shadow."""
    for j in range(hh):
        for i in range(w):
            c = ramp[2]
            if i == 0 or j == 0:
                c = ramp[3]
            if i == w - 1 or j == hh - 1:
                c = ramp[1]
            cv.px(x + i, y + j, c)
    for i in range(w):
        if not cv.get(x + i + 1, y + hh):
            cv.px(x + i + 1, y + hh, c0)
    for j in range(hh):
        if not cv.get(x + w, y + j + 1):
            cv.px(x + w, y + j + 1, c0)


def rubble(z, seed):
    """Spread of broken concrete / brick / stone (rubble edges round ruins)."""
    c0 = zc(z)[0]
    W, H_ = SIZES["rubble"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    for _ in range(16):
        ramp = rnd.choice(([A[0], A[1], A[2], A[3]], [A[0], A[1], A[2], A[3]], [RU[0], RU[1], RU[2], RU[3]], [E[0], E[1], E[2], E[3]]))
        # denser in the middle
        x = int(W / 2 + rnd.gauss(0, W / 5)); y = int(H_ / 2 + rnd.gauss(0, H_ / 5))
        w, hh = rnd.randint(2, 7), rnd.randint(2, 5)
        x = max(1, min(W - w - 2, x)); y = max(1, min(H_ - hh - 2, y))
        _chunk(cv, x, y, w, hh, ramp, c0)
    return cv


def debris(z, seed):
    """Mixed junk: a plank, scrap bits, pebbles."""
    c0, c1, c2, c3 = zc(z)
    W, H_ = SIZES["debris"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    x, y = rnd.randint(4, 16), rnd.randint(8, H_ - 12)
    L = rnd.randint(22, 34)
    for i in range(L):
        yy = y + i // 9
        cv.px(x + i, yy, E[3]); cv.px(x + i, yy + 1, E[2]); cv.px(x + i, yy + 2, E[1])
        if not cv.get(x + i + 1, yy + 3):
            cv.px(x + i + 1, yy + 3, c0)
    for _ in range(7):
        ramp = rnd.choice((RU, ST, [A[0], A[1], A[2], A[3]], [E[0], E[1], E[2], E[3]]))
        _chunk(cv, rnd.randint(1, W - 8), rnd.randint(1, H_ - 6), rnd.randint(2, 5), rnd.randint(2, 3), ramp, c0)
    return cv


def tufts(z, seed):
    """Dead-grass patch: several tufts."""
    W, H_ = SIZES["tufts"][:2]
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    c0 = zc(z)[0]
    for _ in range(rnd.randint(4, 6)):
        bx, by = rnd.randint(6, W - 8), rnd.randint(12, H_ - 3)
        for k in range(6):
            ang = -math.pi / 2 + (k - 2.5) * 0.3 + rnd.uniform(-0.1, 0.1)
            L = rnd.randint(4, 9)
            for i in range(L):
                x = bx + math.cos(ang) * i
                y = by + math.sin(ang) * i
                cv.px(x, y, E[2] if (i > L - 3 and k < 3) else (CL[1] if i > 2 else c0))
    return cv


MAKERS = {"rubble": rubble, "debris": debris, "tufts": tufts, "crack": crack, "pebbles": pebbles, "bones": bones_d, "grass": grass, "oil": oil, "scrap": scrap,
          "stain": stain, "toxic": toxic, "crater": crater}


def atlas(z):
    """Pack every decal for zone z: returns (RGBA array, {name: (x, y, w, h)})."""
    items = []
    for kind, (w, hh, n) in SIZES.items():
        for i in range(n):
            if kind.startswith("tracks"):
                cv = tracks(z, i + 1, kind[-1])
            else:
                cv = MAKERS[kind](z, i * 7 + 3)
            items.append(("%s_%d" % (kind, i), cv))
    W = 1024
    x = y = rh = 0
    regions = {}
    pos = []
    for name, cv in items:
        if x + cv.w + 2 > W:
            x = 0; y += rh + 2; rh = 0
        regions[name] = (x, y, cv.w, cv.h)
        pos.append((cv, x, y))
        x += cv.w + 2
        rh = max(rh, cv.h)
    H_ = y + rh
    H_ = 1 << (H_ - 1).bit_length()
    out = np.zeros((H_, W, 4), np.uint8)
    for cv, x, y in pos:
        out[y:y + cv.h, x:x + cv.w] = cv.a
    return out, regions
