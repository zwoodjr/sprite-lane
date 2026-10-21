"""Small / medium world props (Prop S / M), bible density 1 texel = 1 world texel."""
import math
import random
import numpy as np
from pk import *

ROCK = [E[0], E[1], E[2], E[3], E[4]]
ASH4 = [A[0], A[1], A[2], A[3]]
SAND = [CL[0], CL[1], CL[2], E[3], E[4]]
WOOD = [E[0], E[1], E[2], E[3]]


def blob_poly(cx, cy, rx, ry, seed, n=11, jit=0.22, flat_bottom=True):
    rnd = random.Random(seed)
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n + rnd.uniform(-0.15, 0.15)
        r = 1 + rnd.uniform(-jit, jit)
        x = cx + math.cos(t) * rx * r
        y = cy + math.sin(t) * ry * r
        if flat_bottom and math.sin(t) > 0.5:
            y = min(y, cy + ry * 0.85)
        pts.append((x, y))
    return pts


def rock(w, hh, seed, n=7, ramp=ROCK):
    cv = Cv(w + 4, hh + 4)
    m = m_poly(cv, blob_poly(cv.w / 2, cv.h / 2 + 1, w / 2, hh / 2, seed, n=9, jit=0.18))
    facets(cv, m, ramp, seed=seed, n=n, hl=True, tilt=0.3)
    # a crack + a few pits
    rnd = random.Random(seed + 9)
    ys, xs = np.nonzero(m)
    x0 = int(xs.mean()) + rnd.randint(-3, 3)
    y0 = ys.min() + 3
    for k in range(max(3, hh // 3)):
        x0 += rnd.choice((0, 0, 1, -1))
        if m[y0 + k, x0] and m[y0 + k, x0 + 1]:
            cv.px(x0, y0 + k, ramp[1])
            cv.px(x0 + 1, y0 + k, ramp[3])
    return finish(cv)


def rock_small():
    return rock(26, 18, 5, n=6)


def rock_large():
    cv = Cv(58, 46)
    m = m_poly(cv, blob_poly(26, 26, 22, 17, 21, n=10, jit=0.16))
    m2 = m_poly(cv, blob_poly(42, 32, 11, 9, 4, n=8, jit=0.2))
    facets(cv, m, ROCK, seed=3, n=13, tilt=0.3)
    facets(cv, m2 & ~m, ROCK, seed=8, n=4, tilt=0.3)
    # strata lines
    for y in (24, 31):
        for x in range(6, 48):
            if m[y, x] and (x // 5) % 3 != 2:
                c = cv.get(x, y)
                if c in REV and REV[c][0] == "earth":
                    cv.px(x, y, ROCK[max(1, REV[c][1] - 1)])
    blotch(cv, m | m2, [A[0], A[1], A[2], A[3]], 7, scale=1.6, thresh=0.55)
    return finish(cv)


def bones():
    cv = Cv(40, 20)
    B = [E[0], E[2], E[3], E[4]]
    # long bone (femur) lying diagonal
    def bone(x0, y0, x1, y1):
        m = m_line(cv, (x0, y0), (x1, y1), 2)
        for (x, y) in ((x0, y0), (x1, y1)):
            m |= m_ellipse(cv, x + 0.5, y + 0.5, 2.2, 1.8)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            top = not m[max(0, y - 1), x]
            cv.px(x, y, B[3] if top else (B[2] if m[min(cv.h - 1, y + 1), x] else B[1]))
    bone(4, 14, 18, 11)
    bone(20, 16, 30, 15)
    # ribs: arcs
    for k in range(4):
        for t in range(0, 9):
            x = 22 + k * 3 + int(t * 0.3)
            y = 6 + t
            if t < 7:
                cv.px(x, y, B[3] if t < 3 else B[2])
    # skull
    sk = m_ellipse(cv, 33, 9, 4.5, 3.8)
    dome(cv, sk, B, flat=0.5, hl=False)
    cv.px(32, 9, E[0]); cv.px(34, 9, E[0]); cv.px(33, 11, B[1])
    return finish(cv, selout=False, keep={(32, 9), (34, 9)})


def dead_bush(seed=2):
    cv = Cv(40, 40)
    rnd = random.Random(seed)
    TW = [E[0], E[1], E[2], E[3]]

    def branch(x, y, ang, L, w, depth):
        for i in range(int(L)):
            x += math.cos(ang)
            y += math.sin(ang)
            ang += rnd.uniform(-0.12, 0.12)
            cv.px(round(x), round(y), TW[2] if math.cos(ang) < 0.2 else TW[1])
            if w > 1:
                cv.px(round(x) + 1, round(y), TW[1])
            if depth < 2 and i > 3 and rnd.random() < 0.16:
                branch(x, y, ang + rnd.choice((-0.55, 0.55)), L * 0.45, 1, depth + 1)
    for a in (-1.05, -1.35, -1.65, -1.95, -2.25):
        branch(19, 36, a + rnd.uniform(-0.06, 0.06), rnd.uniform(16, 25), 2 if abs(a + 1.65) < 0.2 else 1, 0)
    # twig tips catch the light
    for y, x in zip(*np.nonzero(cv.opaque())):
        if y < 20 and not cv.get(x, y - 1) and rnd.random() < 0.5:
            cv.px(x, y, TW[3])
    # dry tufts at the base
    for (x, y) in ((12, 36), (22, 36), (17, 35)):
        for i in range(6):
            cv.px(x + i, y + (1 if i in (0, 5) else 0), SAND[2] if i < 3 else SAND[1])
            cv.px(x + i, y + 1, SAND[1])
    return finish(cv, selout=False)


def cactus():
    cv = Cv(34, 48)
    G = [CL[0], CL[1], CL[2], E[3]]
    def col(x0, x1, y0, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                dx = (x + 0.5 - (x0 + x1 + 1) / 2) / ((x1 - x0 + 1) / 2)
                t = cyl_tone(dx)
                cv.px(x, y, G[max(1, t)] if t < 3 else G[3])
        # rounded top
        cv.a[y0, x0, 3] = 0
        cv.a[y0, x1, 3] = 0
    col(13, 21, 4, 46)
    col(4, 10, 14, 28)
    cv.rect(8, 27, 13, 30, G[1]); cv.rect(8, 27, 13, 27, G[2])
    col(24, 29, 9, 22)
    cv.rect(21, 21, 25, 24, G[1]); cv.rect(21, 21, 25, 21, G[2])
    # ribs
    for x in (16, 19):
        for y in range(7, 45, 1):
            if (y // 2) % 2 == 0:
                cv.px(x, y, G[1])
    # spines (light dashes)
    for (x, y) in ((12, 10), (12, 20), (12, 33), (22, 15), (22, 30), (3, 18), (11, 24), (30, 13), (23, 40)):
        cv.px(x, y, E[4])
    return finish(cv, orphans=False)


def tire():
    cv = Cv(32, 22)
    T = [A[0], A[1], A[2], A[3]]
    outer = m_ellipse(cv, 16, 9, 14, 7.5)
    inner = m_ellipse(cv, 16, 8.5, 7.5, 3.5)
    side = m_ellipse(cv, 16, 12, 14, 7.5) & ~outer
    for y, x in zip(*np.nonzero(outer | side)):
        dx = (x + 0.5 - 16) / 14
        if side[y, x]:
            c = T[1] if dx < 0.3 else T[0]
        else:
            dy = (y + 0.5 - 9) / 7.5
            ang = math.atan2(dy, dx)
            lit = -math.cos(ang) * 0.6 - math.sin(ang) * 0.8
            c = T[3] if lit > 0.6 else (T[2] if lit > -0.3 else T[1])
        cv.px(x, y, c)
    for y, x in zip(*np.nonzero(inner)):
        dy = (y + 0.5 - 8.5) / 3.5
        dx = (x + 0.5 - 16) / 7.5
        # hole: far (lower-right) inner wall lit, near wall dark
        cv.px(x, y, T[2] if (dx + dy) > 0.9 else (T[0] if dy < 0.4 else T[1]))
    for x in range(4, 29, 3):
        for y in range(16, 20):
            if cv.get(x, y) is not None and side[y, x]:
                cv.px(x, y, T[0] if cv.get(x, y) == T[1] else T[1])
    return finish(cv, selout=False)


def sign_post():
    cv = Cv(34, 52)
    cv.rect(15, 14, 18, 50, WOOD[2]); cv.rect(15, 14, 15, 50, WOOD[3]); cv.rect(18, 14, 18, 50, WOOD[1])
    cv.rect(15, 48, 18, 50, WOOD[1])
    # slanted board (arrow), rust paint
    pts = [(3, 8), (26, 4), (31, 10), (27, 17), (4, 19)]
    m = m_poly(cv, pts)
    cv.fill(m, RU[2])
    top = m & ~np.roll(m, 1, 0)
    cv.fill(top, RU[3])
    bot = m & ~np.roll(m, -1, 0)
    cv.fill(bot, RU[1])
    blotch(cv, m, WOOD, 3, 1.4, 0.3)
    # scratched arrow
    for i in range(14):
        cv.px(8 + i, 12 - i // 5, RU[1])
    for k in range(3):
        cv.px(20 + k, 9 + k, RU[1]); cv.px(20 + k, 13 - k, RU[1])
    rivet(cv, 16, 9); rivet(cv, 16, 15)
    # rag tied to the post
    cv.rect(18, 22, 21, 24, BL); cv.px(21, 25, BL); cv.px(22, 26, RU[0]); cv.rect(18, 22, 20, 22, RU[2])
    return finish(cv)


def scrap_pile(seed=4, w=58, hh=34):
    rnd = random.Random(seed)
    cv = Cv(w + 4, hh + 4)
    base = m_poly(cv, blob_poly(cv.w / 2, cv.h * 0.66, w / 2, hh * 0.38, seed, n=10, jit=0.12))
    dome(cv, base, ASH4, flat=0.4, hl=False)
    # plates leaning in the heap
    for i in range(16):
        ramp = rnd.choice((RU, RU, ST, ST, BR))
        pw, ph = rnd.randint(6, 13), rnd.randint(4, 9)
        x = rnd.randint(4, w - pw)
        y = int(hh * 0.25 + rnd.randint(0, int(hh * 0.45)))
        ang = rnd.uniform(-0.6, 0.6)
        c, s = math.cos(ang), math.sin(ang)
        pts = [(x + px_ * c - py_ * s, y + px_ * s + py_ * c) for px_, py_ in ((0, 0), (pw, 0), (pw, ph), (0, ph))]
        m = m_poly(cv, pts)
        cv.fill(m, ramp[2])
        tp = m & ~np.roll(m, 1, 0)
        cv.fill(tp, ramp[3])
        bt = m & ~np.roll(m, -1, 0)
        cv.fill(bt, ramp[1])
    cyl_h(cv, 8, 30, int(hh * 0.45), 2, ST, cap_left=True)
    # spring / rebar strokes
    for k in range(3):
        x = rnd.randint(10, w - 10)
        for j in range(8):
            cv.px(x + j // 3, int(hh * 0.2) + j, RU[1] if j % 2 else RU[3])
    blotch(cv, cv.opaque(), RU, seed + 3, 1.3, 0.5)
    return finish(cv)


def barrier_scrap():
    cv = Cv(60, 44)
    # welded plate wall: three plates, slight stagger
    box(cv, 3, 8, 18, 26, 5, RU, top_ramp=RU)
    box(cv, 20, 5, 20, 30, 5, ST, top_ramp=ST)
    box(cv, 39, 9, 17, 25, 5, RU, top_ramp=RU)
    # weld beads at seams
    for y in range(12, 38, 4):
        cv.px(20, y, A[3]); cv.px(20, y + 1, A[3]); cv.px(39, y + 1, A[3]); cv.px(39, y + 2, A[3])
    hazard(cv, 22, 26, 16, 4, BR)
    for (x, y) in ((6, 16), (16, 16), (24, 12), (35, 12), (42, 17), (52, 17)):
        rivet(cv, x, y)
    blotch(cv, mask_of(cv, ST), RU, 5, 1.5, 0.35)
    # feet / sandbag props at the base
    cv.rect(8, 38, 14, 41, ST[1]); cv.rect(44, 38, 50, 41, ST[1]); cv.rect(8, 38, 14, 38, ST[2]); cv.rect(44, 38, 50, 38, ST[2])
    return finish(cv)


def drum(painted=RU, band=True, W=26, H=34, seed=0, dent=True):
    cv = Cv(W + 2, H + 2)
    cx, rx, ry, yt, yb = (W + 2) / 2, W / 2 - 0.5, 4.0, 5, H - 4
    cyl_v(cv, cx, rx, ry, yt, yb, painted, top_ramp=painted, rim=True)
    for y in range(cv.h):
        for x in range(cv.w):
            dx = (x + 0.5 - cx) / rx
            if abs(dx) > 1:
                continue
            f = ry * math.sqrt(max(0, 1 - dx * dx))
            rel = y + 0.5 - (yt + f)
            t = cyl_tone(dx)
            for rib in (7, 17):
                if int(rel) == rib:
                    cv.px(x, y, painted[min(3, t + 1)])
                if int(rel) == rib + 1:
                    cv.px(x, y, painted[max(0, t - 1)])
            if band and 11 <= rel < 14:
                c = BR[2] if ((x + int(rel)) // 2) % 2 == 0 else INK
                if t <= 1 and c is not INK:
                    c = BR[1]
                cv.px(x, y, c)
    # bung on the lid
    cv.px(int(cx) + 3, yt, painted[0]); cv.px(int(cx) + 4, yt, painted[0])
    body = cv.opaque()
    blotch(cv, body, RU if painted is not RU else [RU[0], RU[1], RU[1], RU[2]], seed + 11, 1.2, 0.45)
    return finish(cv)


def scrap_drum():
    return drum(RU, True, 26, 34, 2)


def crate_wood(w, hh, d, seed=0):
    cv = Cv(w + 2, hh + d + 2)
    box(cv, 1, 1, w, hh, d, WOOD, top_ramp=[E[1], E[2], E[3], E[4]])
    # planks on top (lines) and on front
    for x in range(1 + w // 3, w, w // 3):
        for y in range(1, d + 1):
            cv.px(x, y, E[2])
    for y in range(d + 1 + hh // 3, d + hh, hh // 3):
        cv.rect(2, y, w - 1, y, E[1])
    # cross brace on front
    for i in range(hh - 2):
        x = 2 + int(i * (w - 4) / (hh - 2))
        cv.px(x, d + 1 + i, E[3])
        cv.px(x, d + 2 + i, E[1])
    # corner brackets
    for (x, y) in ((1, d + 1), (w - 2, d + 1), (1, d + hh - 2), (w - 2, d + hh - 2)):
        cv.rect(x, y, x + 1, y + 1, ST[2])
        cv.px(x + 1, y + 1, ST[1])
    return cv


def herb_crate():
    cv = crate_wood(28, 18, 7, 1)
    # dried herb bundles sticking out of the lid
    H = [CL[0], CL[1], CL[2]]
    big = Cv(cv.w, cv.h + 8)
    big.a[8:] = cv.a
    for bx, c in ((6, H[2]), (12, H[1]), (18, H[2]), (23, PL[1])):
        for j in range(9):
            big.px(bx + (j % 3 == 0), 4 + j, c if j % 4 else H[1])
            big.px(bx + 1, 3 + j, H[2] if j < 3 else c)
        big.px(bx, 3, PL[2] if bx == 23 else CL[2])
    # tie string
    for x in range(5, 26):
        big.px(x, 12, RU[1])
    return finish(big)


def vial_crate():
    cv = crate_wood(30, 18, 8, 2)
    big = Cv(cv.w, cv.h + 9)
    big.a[9:] = cv.a
    # open top: dark interior, three vials standing up
    big.rect(3, 11, 28, 15, E[0])
    for vx, liq in ((6, PL[2]), (13, FL[3]), (20, BR[2])):
        for y in range(3, 15):
            for x in range(vx, vx + 5):
                edge = x in (vx, vx + 4)
                c = ST[3] if x == vx + 1 else (ST[1] if edge else ST[2])
                if y >= 8 and not edge:
                    c = liq if x != vx + 1 else (D[4] if liq is BR[2] else liq)
                big.px(x, y, c)
        big.rect(vx + 1, 1, vx + 3, 2, E[2]); big.px(vx + 1, 1, E[3])  # cork
        big.px(vx + 1, 9, ST[3])
    return finish(big)


def apothecary_chest():
    W_, H_, d = 40, 20, 9
    cv = Cv(W_ + 2, H_ + d + 2)
    box(cv, 1, 1, W_, H_, d, WOOD, top_ramp=[E[1], E[2], E[3], E[4]])
    # lid curve: lighter band
    cv.rect(1, d - 2, W_, d, E[2])
    cv.rect(1, d + 1, W_, d + 1, E[1])
    # brass corners + straps + lock
    for x in (1, W_ - 3):
        cv.rect(x, 1, x + 2, H_ + d, BR[1])
        cv.rect(x, 1, x, H_ + d, BR[3] if x == 1 else BR[2])
    cv.rect(W_ // 2 - 2, d + 3, W_ // 2 + 2, d + 9, BR[2])
    cv.rect(W_ // 2 - 2, d + 3, W_ // 2 + 2, d + 3, BR[3])
    cv.px(W_ // 2, d + 6, INK); cv.px(W_ // 2, d + 7, INK)
    # stencilled cross (blood) on the lid
    cv.rect(10, 3, 12, 7, BL); cv.rect(8, 4, 14, 6, BL)
    blotch(cv, cv.opaque(), [E[0], E[1], E[1], E[2]], 4, 1.3, 0.55)
    return finish(cv)


def barrels_rust():
    cv = Cv(56, 50)
    a = drum(RU, True, 24, 32, 1)
    b = drum(ST, False, 22, 30, 4)
    paste(cv, b, 26, 2)
    paste(cv, a, 6, 6)
    # one lying on its side in front
    lie = Cv(30, 18)
    cyl_h(lie, 3, 24, 8, 7, RU, cap_left=True)
    for x in (9, 17):
        for k in range(-7, 8):
            c = lie.get(x, 8 + k)
            if c:
                lie.px(x, 8 + k, RU[min(3, REV[c][1] + 1)])
    blotch(lie, lie.opaque(), [RU[0], RU[1], RU[1], RU[2]], 9, 1.2, 0.45)
    remove_orphans(lie)
    outline(lie, False)
    paste(cv, lie, 22, 30)
    return finish(cv)


def sandbags():
    cv = Cv(100, 40)
    rnd = random.Random(7)
    BAG = [E[0], E[1], E[2], CL[2], E[3]]
    rows = [(9, 6, 1), (17, 7, 6), (26, 7, 0)]
    for (y, n, off) in rows:
        for i in range(n):
            x = 9 + off + i * 13 + rnd.randint(-1, 1)
            m = m_poly(cv, blob_poly(x, y, 8.0, 5.2, rnd.randint(0, 99), n=10, jit=0.07, flat_bottom=False))
            dome(cv, m, BAG, flat=0.42, bias=-0.12, hl=True)
            # tied ends: pinched lighter tuft on the left, seam line
            cv.px(x - 7, y - 1, CL[2]); cv.px(x - 8, y, CL[2])
            for k in range(-3, 3):
                if m[y + k, x + 3]:
                    cv.px(x + 3, y + k, CL[1])
    blotch(cv, cv.opaque(), [E[0], E[1], E[2], E[3]], 3, 2.0, 0.5)
    return finish(cv)
