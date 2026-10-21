"""Medium / large world props and road set-pieces (Prop M / L, landmark)."""
import math
import random
import numpy as np
from pk import *
from props_small import WOOD, ROCK, ASH4, SAND, blob_poly, rock

CONC = [A[0], A[1], A[2], A[3]]  # concrete (ASH without BONE)


# ---------------------------------------------------------------- vehicles
def _car_body(cv, x, y, w, body_h, d, paint, cab, seed, wheels, cab_ramp=None):
    cab_ramp = cab_ramp or paint
    box(cv, x, y, w, body_h, d, paint)
    cx0, cy0, cw, ch, cd = cab
    box(cv, cx0, cy0, cw, ch, cd, cab_ramp)
    return cx0, cy0, cw, ch, cd


def _windows(cv, x0, y0, x1, y1, n, frame, broken=()):
    ww = (x1 - x0 - (n - 1) * 3) // n
    for i in range(n):
        wx = x0 + i * (ww + 3)
        cv.rect(wx, y0, wx + ww - 1, y1, ST[0])
        if i in broken:
            cv.rect(wx + 1, y0 + 1, wx + ww - 2, y1, A[0])
            for k in range(3):
                cv.px(wx + 1 + k, y0 + 1 + k % 2, ST[2])
            continue
        # sky glint: a diagonal lit band, top-left
        for k in range(min(ww, y1 - y0)):
            cv.px(wx + 1 + k, y0 + 1 + (k * 2) // 3, ST[2])
            if k < ww - 2:
                cv.px(wx + 2 + k, y0 + 1 + (k * 2) // 3, ST[1])
        cv.px(wx + 1, y0 + 1, ST[3])


def _rust_and_holes(cv, region, seed, holes=4, thresh=0.3):
    blotch(cv, region, [RU[0], RU[1], RU[1], RU[2]], seed, 2.6, thresh + 0.12)
    rnd = random.Random(seed)
    ys, xs = np.nonzero(region)
    for _ in range(holes):
        k = rnd.randrange(len(ys))
        x, y = xs[k], ys[k]
        if region[y, x] and region[min(cv.h - 1, y + 1), min(cv.w - 1, x + 1)]:
            cv.px(x, y, INK); cv.px(x + 1, y, A[0]); cv.px(x, y + 1, A[0]); cv.px(x + 1, y + 1, A[1])


def wreck_car(paint=RU, seed=3):
    cv = Cv(108, 62)
    box(cv, 4, 24, 98, 15, 11, paint)
    box(cv, 26, 6, 50, 17, 10, paint)
    # windows on the cabin side, one door hanging off
    _windows(cv, 30, 18, 72, 27, 2, paint, broken=(1,))
    cv.rect(52, 36, 64, 48, A[0]); cv.rect(52, 36, 64, 36, A[1])  # missing door
    # bumpers + lamps
    cv.rect(4, 44, 6, 48, ST[2]); cv.rect(99, 44, 101, 48, ST[1])
    cv.px(5, 41, BR[3]); cv.px(100, 41, BR[1])
    # roof dent and grime
    body = cv.opaque()
    _rust_and_holes(cv, body, seed, 7, 0.18)
    streaks(cv, body, None, seed, 0)
    wheel(cv, 22, 50, 8)
    wheel(cv, 84, 50, 8)
    # flat tyre sag: shift back wheel's bottom row
    return finish(cv)


def wreck_truck():
    cv = Cv(146, 74)
    G = [CL[0], CL[1], CL[2], E[3]]
    # flatbed (wood planks) then the cab
    box(cv, 4, 24, 92, 14, 14, WOOD, top_ramp=[E[1], E[2], E[3], E[4]])
    for x in range(8, 96, 9):
        cv.rect(x, 25, x, 37, E[2])
    cv.rect(4, 38, 95, 40, ST[1])
    box(cv, 94, 10, 44, 28, 10, G)
    box(cv, 92, 44, 48, 10, 1, G)
    _windows(cv, 112, 22, 134, 33, 1, G)
    cv.rect(98, 22, 108, 44, G[1]); cv.rect(98, 22, 108, 22, G[2]); cv.px(106, 33, BR[2])  # door
    # chassis
    cv.rect(4, 52, 138, 55, ST[0]); cv.rect(4, 52, 138, 52, ST[1])
    _rust_and_holes(cv, cv.opaque(), 12, 6, 0.4)
    for x in (24, 60, 120):
        wheel(cv, x, 58, 9)
    return finish(cv)


def wreck_bus():
    cv = Cv(212, 82)
    Y = [BR[0], BR[1], BR[2], BR[3]]
    box(cv, 4, 8, 202, 46, 12, Y, top_ramp=[A[1], A[2], A[3], A[3]])
    # roof vents + rust
    for x in (40, 110, 170):
        box(cv, x, 10, 16, 2, 5, CONC)
    _windows(cv, 12, 26, 188, 38, 9, Y, broken=(2, 3, 6))
    # black stripe + door + front
    cv.rect(4, 42, 205, 43, INK)
    cv.rect(192, 24, 204, 60, Y[1]); cv.rect(193, 26, 203, 38, ST[0]); cv.px(194, 27, ST[2])
    cv.rect(4, 58, 205, 61, ST[1]); cv.rect(4, 58, 205, 58, ST[2])
    _rust_and_holes(cv, cv.opaque(), 21, 12, 0.42)
    for x in (34, 160):
        wheel(cv, x, 64, 10)
    return finish(cv)


def wreck():
    """Burnt-out car hulk (wreck-field landmark core)."""
    cv = Cv(110, 62)
    box(cv, 4, 26, 100, 14, 11, CONC)
    box(cv, 28, 10, 48, 15, 9, CONC)
    _windows(cv, 32, 20, 72, 28, 2, CONC, broken=(0, 1))
    body = cv.opaque()
    blotch(cv, body, [RU[0], RU[1], RU[1], RU[2]], 5, 2.0, 0.05)
    blotch(cv, body, [A[0], A[0], A[1], A[1]], 9, 1.4, 0.4)
    # on its rims: bare hubs
    for x in (22, 86):
        m = m_ellipse(cv, x, 52, 5, 7)
        cv.fill(m, A[0])
        cv.fill(m_ellipse(cv, x, 52, 2.5, 3.5), RU[1])
        cv.px(x - 1, 50, RU[2])
    return finish(cv)


# ---------------------------------------------------------------- road and walls
def pole_down():
    cv = Cv(184, 48)
    # stump at the base
    box(cv, 4, 22, 9, 14, 4, WOOD)
    beam(cv, (12, 32), (178, 12), 5, WOOD)
    # crossarm near the top end + insulators
    beam(cv, (156, 4), (166, 26), 3, WOOD)
    for (x, y) in ((157, 6), (161, 15), (165, 24)):
        cv.rect(x, y - 2, x + 2, y, ST[2]); cv.px(x, y - 2, ST[3])
    # bolts / climbing pegs
    for t in range(20, 160, 14):
        x = 12 + t
        y = int(32 - (t / 166) * 20)
        cv.px(x, y - 3, ST[2])
    blotch(cv, cv.opaque(), [E[0], E[1], E[1], E[2]], 4, 1.2, 0.5)
    out = finish(cv)
    # sagging wires (no outline: 1 px, dark), drawn after the outline
    big = Cv(out.w, out.h + 10)
    big.a[:out.h] = out.a
    for (x0, y0) in ((157, 4), (161, 13), (165, 22)):
        for i in range(70):
            x = x0 - 2 - i * 2
            y = y0 + int(10 * math.sin(i / 70 * math.pi)) + i // 10
            if 0 <= x < big.w and y < big.h:
                big.px(x, y, A[1]); big.px(x + 1, y, A[1])
    return crop(big)


def fence_broken():
    cv = Cv(122, 56)
    posts = [(6, 6), (34, 4), (64, 10), (94, 5), (116, 14)]
    for i, (x, top) in enumerate(posts):
        lean = 0 if i != 2 else 1
        for y in range(top, 52):
            xx = x + (lean * (52 - y)) // 8
            cv.px(xx, y, ST[3]); cv.px(xx + 1, y, ST[2]); cv.px(xx + 2, y, ST[1])
    # top rail (bent, broken between posts 3-4)
    for x in range(6, 70):
        y = 8 + (x - 6) // 30
        cv.px(x, y, ST[2]); cv.px(x, y + 1, ST[1])
    for x in range(96, 118):
        cv.px(x, 9 + (x - 96) // 6, ST[2]); cv.px(x, 10 + (x - 96) // 6, ST[1])
    rust = blotch(cv, cv.opaque(), RU, 6, 0.9, 0.3)
    out = finish(cv, selout=False)
    # chain-link mesh panels (wire is 1 px; no outline), one panel torn open
    m = np.zeros((out.h, out.w), bool)
    m[10:50, 4:64] = True
    m[12:50, 96:116] = True
    torn = m_poly(Cv(out.w, out.h), [(64, 10), (96, 8), (90, 26), (76, 50), (64, 50)])
    big = Cv(out.w, out.h)
    big.a = out.a.copy()
    for y, x in zip(*np.nonzero(m & ~torn)):
        if ((x + y) % 4 == 0 or (x - y) % 4 == 0) and not big.get(x, y):
            big.px(x, y, A[2] if y < 30 else A[1])
    # torn flap curling down
    for i in range(10):
        for j in range(6 + i // 2):
            x, y = 66 + j + i, 40 + i // 2 + j // 3
            if (x + y) % 4 == 0 and not big.get(x, y):
                big.px(x, y, A[2])
    return big


BRICK = [RU[0], RU[0], RU[1], RU[2]]


def wall_ruin(w=72, hgt=58, seed=7, ramp=BRICK):
    rnd = random.Random(seed)
    cv = Cv(w + 6, hgt + 8)
    d = 5
    base = hgt + 4
    tops = []
    t = 8
    for x in range(w):
        t += rnd.choice((-2, -1, 0, 0, 1, 2))
        if rnd.random() < 0.06:
            t += rnd.randint(4, 10)
        t = max(2, min(hgt - 18, t))
        tops.append(t)
    tops = ndi_smooth(tops)
    for i, t in enumerate(tops):
        x = 2 + i
        for y in range(t, t + d):
            cv.px(x, y, CONC[3] if y == t else CONC[2])  # broken top (lit plaster)
        for y in range(t + d, base):
            cv.px(x, y, ramp[2])
    front = cv.opaque() & ~mask_of(cv, CONC)
    bricks(cv, front, ramp, 8, 4, seed, mortar=A[1])
    # plaster left on the lower wall
    pl = blotch(cv, front, CONC, seed + 1, 3.0, 0.3)
    cv.rect(2, d, 2, base - 1, ramp[3])  # lit left end
    ao_bottom(cv, cv.opaque(), 2)
    # rebar sticking out of the broken top
    for k in range(3):
        i = rnd.randrange(8, w - 8)
        t = tops[i]
        for j in range(rnd.randint(5, 9)):
            cv.px(2 + i + j // 3, t - j, RU[1] if j % 2 else RU[2])
    return finish(cv)


def ndi_smooth(v):
    out = []
    for i in range(len(v)):
        a = v[max(0, i - 1):i + 2]
        out.append(int(round(sum(a) / len(a))))
    return out


def wall_collapsed():
    cv = Cv(116, 64)
    wr = wall_ruin(46, 44, 11)
    paste(cv, wr, 2, 4)
    # fallen slab lying to the right: thick concrete plate
    face(cv, [(44, 34), (104, 30), (112, 46), (52, 52)], CONC[3], edge_hi=BONE if False else CONC[3])
    face(cv, [(52, 52), (112, 46), (112, 51), (52, 57)], CONC[1])
    sl = m_poly(cv, [(44, 34), (104, 30), (112, 46), (52, 52)])
    blotch(cv, sl, [A[0], A[1], A[2], A[2]], 4, 1.4, 0.45)
    bricks(cv, sl & (np.mgrid[0:cv.h, 0:cv.w][1] > 70), [A[0], A[1], A[2], A[3]], 12, 6, 3)
    # rubble chunks along the foot
    for (x, y, s) in ((42, 54, 7), (60, 58, 5), (100, 55, 6), (86, 58, 4)):
        r = rock(s * 2, s + 2, x + y, n=4, ramp=[A[0], A[1], A[2], A[3]])
        paste(cv, r, x - s, y - s // 2 - 2)
    return finish(cv)


def ruin_pillar():
    rnd = random.Random(4)
    cv = Cv(40, 96)
    w, d = 22, 7
    tops = [10, 9, 8, 8, 6, 5, 4, 4, 5, 6, 8, 11, 13, 14, 15, 17, 18, 17, 16, 19, 22, 24]
    for i, t in enumerate(tops):
        x = 6 + i
        for y in range(t, t + d):
            cv.px(x, y, CONC[3] if y < t + 2 else CONC[2])
        for y in range(t + d, 88):
            cv.px(x, y, CONC[3] if i < 3 else (CONC[2] if i < 18 else CONC[1]))
    # plinth
    box(cv, 3, 80, 28, 8, 3, CONC)
    region = cv.opaque()
    blotch(cv, region, [A[0], A[1], A[1], A[2]], 6, 1.5, 0.45)
    # chipped edge + horizontal formwork lines
    for y in range(30, 80, 12):
        for x in range(7, 27):
            if cv.get(x, y) and rnd.random() < 0.8:
                cv.px(x, y, CONC[1])
    for k in range(2):
        x = 10 + k * 8
        for j in range(8):
            cv.px(x + j // 4, tops[x - 6] - j, RU[1] if j % 2 else RU[2])
    return finish(cv)


def signal_tower():
    cv = Cv(84, 184)
    # four-leg lattice tower, converging; the right legs are in shade
    lb, rb, top = (8, 178), (64, 178), (30, 26)
    beam(cv, lb, (top[0], top[1]), 3, ST)
    beam(cv, rb, (top[0] + 14, top[1]), 3, ST)
    beam(cv, (34, 178), (36, 26), 2, [ST[0], ST[1], ST[1], ST[2]])
    # X bracing
    ys = list(range(170, 30, -18))
    for y0, y1 in zip(ys, ys[1:]):
        def lx(y):
            return 8 + (30 - 8) * (178 - y) / 152
        def rx(y):
            return 64 - (64 - 44) * (178 - y) / 152
        for (p, q) in (((lx(y0), y0), (rx(y1), y1)), ((rx(y0), y0), (lx(y1), y1))):
            m = m_line(cv, (int(p[0]) + 1, p[1]), (int(q[0]) + 1, q[1]), 1)
            cv.fill(m & ~cv.opaque(), ST[1])
        cv.fill(m_line(cv, (int(lx(y1)), y1), (int(rx(y1)), y1), 1) & ~cv.opaque(), ST[2])
    # platform + mast + dish
    box(cv, 22, 22, 32, 3, 4, ST)
    for x in range(22, 54, 4):
        cv.rect(x, 14, x, 22, ST[1])
    cv.rect(22, 14, 53, 14, ST[2])
    cv.rect(36, 2, 37, 14, ST[2]); cv.rect(38, 2, 38, 14, ST[1])
    dish = m_ellipse(cv, 18, 12, 8, 10)
    dome(cv, dish, CONC, flat=0.3, hl=False, ao=False)
    cv.fill(m_ellipse(cv, 19, 12, 5, 7), A[2])
    cv.px(19, 12, ST[1])
    # warning plate
    hazard(cv, 30, 120, 12, 6, BR)
    blotch(cv, cv.opaque(), RU, 8, 1.0, 0.35)
    # concrete footings
    for x in (4, 30, 60):
        box(cv, x, 172, 10, 5, 3, CONC)
    return finish(cv)


# ---------------------------------------------------------------- extract pads
def extract_pad(open_=False):
    W, H_ = 180, 150
    cv = Cv(W, H_)
    cx, cy, rx, ry = W / 2, 66, 86, 62
    # concrete apron (with a 6 px front wall), steel hatch ring, hazard band
    side = m_ellipse(cv, cx, cy + 6, rx, ry) & ~m_ellipse(cv, cx, cy, rx, ry)
    cv.fill(side, A[1])
    apron = m_ellipse(cv, cx, cy, rx, ry)
    dome(cv, apron, CONC, flat=0.15, hl=False, ao=False)
    blotch(cv, apron, [A[0], A[1], A[1], A[2]], 3, 2.0, 0.45)
    yy, xx = cv.grid()
    r = np.sqrt(((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2)
    ang = np.arctan2((yy + 0.5 - cy) / ry, (xx + 0.5 - cx) / rx)
    band = (r < 0.8) & (r >= 0.68)
    for y, x in zip(*np.nonzero(band)):
        on = int((ang[y, x] + math.pi) / (2 * math.pi) * 36) % 2 == 0
        cv.px(x, y, BR[2] if on else INK)
    lip = (r < 0.68) & (r >= 0.64)
    cv.fill(lip, ST[0])
    hatch = r < 0.64
    for y, x in zip(*np.nonzero(hatch)):
        lit = -math.cos(ang[y, x]) * 0.6 - math.sin(ang[y, x]) * 0.8
        t = 3 if (r[y, x] > 0.56 and lit < -0.3) else (2 if r[y, x] > 0.2 or lit > 0 else 1)
        cv.px(x, y, ST[t])
    # bolts round the ring
    for k in range(16):
        t = 2 * math.pi * k / 16
        bx, by = cx + math.cos(t) * rx * 0.74, cy + math.sin(t) * ry * 0.74
        if k % 2:
            rivet(cv, int(bx), int(by))
    if not open_:
        # sealed: four-leaf iris hatch, seams + dim lamps
        for k in range(4):
            t = math.pi / 4 + k * math.pi / 2
            for i in range(int(rx * 0.62)):
                x = cx + math.cos(t) * i
                y = cy + math.sin(t) * i * ry / rx
                cv.px(x, y, ST[0])
                cv.px(x + 1, y + 1, ST[3] if i % 3 else ST[2])
        for k in range(4):
            t = k * math.pi / 2
            lx, ly = cx + math.cos(t) * rx * 0.5, cy + math.sin(t) * ry * 0.5
            cv.rect(lx - 2, ly - 1, lx + 2, ly + 1, TE[0])
        cv.fill(m_ellipse(cv, cx, cy, 9, 7), ST[1])
        cv.fill(m_ellipse(cv, cx - 1, cy - 1, 5, 4), ST[2])
    else:
        # open: iris retracted, lit shaft with teal guide lights (friendly)
        shaft = r < 0.5
        cv.fill(shaft, TE[0])
        cv.fill((r < 0.5) & (r >= 0.45), ST[0])
        inner = (r < 0.36) & (r >= 0.31)
        for y, x in zip(*np.nonzero(inner)):
            if int((ang[y, x] + math.pi) / (2 * math.pi) * 24) % 2 == 0:
                cv.px(x, y, TE[1])
        # chevrons pointing in from the four sides
        for k in range(4):
            t = k * math.pi / 2
            for i in range(3):
                ccx, ccy = cx + math.cos(t) * rx * (0.58 - 0.06 * i), cy + math.sin(t) * ry * (0.58 - 0.06 * i)
                for j in range(-3, 4):
                    px_ = ccx + math.cos(t) * abs(j) * 1.0 - math.sin(t) * j
                    py_ = ccy + math.sin(t) * abs(j) * 1.0 + math.cos(t) * j
                    cv.px(px_, py_, TE[1])
        cv.fill(m_ellipse(cv, cx, cy, 6, 4), TE[1])
    return finish(cv, keep=set())


def extract_sealed():
    return extract_pad(False)


def extract_open():
    return extract_pad(True)
