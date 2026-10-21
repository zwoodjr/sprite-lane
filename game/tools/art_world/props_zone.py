"""Zone props (depth/zone) and radio-job / landmark set pieces (depth/world)."""
import math
import random
import numpy as np
from pk import *
from props_small import WOOD, ROCK, SAND, blob_poly, rock, drum, crate_wood, tire, sandbags
from props_large import CONC, BRICK, wall_ruin, _windows, _rust_and_holes, ndi_smooth

OLIVE = [CL[0], CL[1], CL[2], E[3]]
CANVAS = [CL[0], CL[1], CL[2], E[3], E[4]]


def _wrap(arr):
    cv = Cv(arr.shape[1], arr.shape[0])
    cv.a = arr.copy()
    return cv


# ================================================================ T7 CHOKE
def chem_vat():
    import vat
    return crop(_wrap(vat.make_vat()))


def pipe_rack():
    cv = Cv(206, 112)
    # two steel trestles (I-beam legs + crossbar)
    for x0 in (26, 162):
        for dx in (0, 22):
            beam(cv, (x0 + dx, 108), (x0 + dx + (6 if dx == 0 else -6), 30), 4, ST)
        box(cv, x0 - 6, 26, 40, 4, 4, ST)
        box(cv, x0 - 2, 70, 32, 3, 3, ST)
    # pipes: big steel, rust-painted, brass line on the low bar
    cyl_h(cv, 4, 202, 18, 9, ST, cap_left=True)
    cyl_h(cv, 8, 198, 42, 6, RU, cap_left=True)
    cyl_h(cv, 12, 194, 64, 4, BR, cap_left=True)
    # flanges
    for x in (60, 120):
        for y in range(8, 30):
            cv.px(x, y, ST[3] if y < 18 else ST[1]); cv.px(x + 1, y, ST[2] if y < 18 else ST[0])
        for y in range(35, 50):
            cv.px(x + 20, y, RU[3] if y < 42 else RU[1])
    # valve wheel on the rust pipe
    vx, vy = 140, 38
    for a in range(0, 360, 12):
        t = math.radians(a)
        cv.px(vx + 7 * math.cos(t), vy - 6 + 4 * math.sin(t), RU[3] if math.sin(t) < 0 else RU[2])
    for i in range(-6, 7):
        cv.px(vx + i, vy - 6, RU[1])
    cv.rect(vx, vy - 6, vx, vy, ST[1])
    _rust_and_holes(cv, mask_of(cv, ST), 31, 3, 0.4)
    return finish(cv)


# ================================================================ T3 SMOG
def oil_tank():
    cv = Cv(140, 162)
    cx, rx, ry = 66, 58, 16
    cyl_v(cv, cx, rx, ry, 22, 140, ST, top_ramp=ST, rim=True)
    # weld seams / bands
    for off in (30, 62, 94):
        for x in range(cv.w):
            dx = (x + 0.5 - cx) / rx
            if abs(dx) > 1:
                continue
            f = ry * math.sqrt(1 - dx * dx)
            y = int(round(22 + f + off))
            t = cyl_tone(dx)
            cv.px(x, y, ST[max(0, t - 1)])
            if x % 6 == 2:
                cv.px(x, y - 1, BR[2] if t >= 2 else BR[1])
    # painted band (rust paint) with stencil blocks
    for x in range(cv.w):
        dx = (x + 0.5 - cx) / rx
        if abs(dx) > 0.98:
            continue
        f = ry * math.sqrt(1 - dx * dx)
        t = cyl_tone(dx)
        for k in range(10):
            y = int(round(22 + f + 70 + k))
            c = RU[min(3, max(1, t))]
            if 30 <= x <= 70 and 2 <= k <= 7 and (x // 5) % 2 == 0:
                c = RU[max(0, t - 1)]
            cv.px(x, y, c)
    # ladder up the lit side
    for y in range(28, 150):
        cv.px(22, y, ST[3]); cv.px(29, y, ST[2])
        if y % 6 == 0:
            cv.rect(22, y, 29, y, ST[3])
    # top hatch + railing posts
    box(cv, 70, 14, 12, 4, 4, ST)
    _rust_and_holes(cv, mask_of(cv, ST), 9, 3, 0.45)
    streaks(cv, mask_of(cv, ST), RU, 4, 8, 6, 16, 0)
    # concrete plinth
    m = m_ellipse(cv, cx, 142, rx + 6, ry + 4) & ~m_ellipse(cv, cx, 138, rx, ry)
    cv.fill(m & ~cv.opaque(), A[2])
    return finish(cv)


# ================================================================ T4 PALL
def street_lamp():
    cv = Cv(66, 156)
    beam(cv, (14, 150), (14, 24), 4, ST)
    box(cv, 8, 138, 13, 12, 3, ST)
    # curved arm
    pts = [(14 + i, 24 - int(10 * math.sin(i / 34 * math.pi / 2))) for i in range(0, 35)]
    for (x, y) in pts:
        cv.px(x, y, ST[2]); cv.px(x, y + 1, ST[1]); cv.px(x, y - 1, ST[3])
    # lamp head: steel hood, emissive glass underneath (self-lit, no shadow side)
    face(cv, [(40, 10), (60, 12), (62, 18), (38, 18)], ST[2], edge_hi=ST[3], edge_lo=ST[1])
    cv.rect(41, 19, 59, 21, D[3]); cv.rect(44, 21, 56, 22, D[4]); cv.rect(41, 19, 59, 19, D[2])
    # posted flyer + band
    cv.rect(12, 70, 17, 80, CL[2]); cv.rect(12, 70, 17, 70, E[3]); cv.rect(13, 73, 15, 73, CL[1])
    cv.rect(12, 100, 16, 101, BR[2])
    _rust_and_holes(cv, mask_of(cv, ST), 7, 1, 0.4)
    return finish(cv, keep={(x, y) for x in range(40, 61) for y in range(18, 24)})


def shop_ruin():
    cv = Cv(226, 156)
    rnd = random.Random(12)
    # roof slab top (dark tar) above a plaster/brick front
    W_, top, base = 200, 22, 140
    profile = []
    t = 0
    for x in range(W_):
        t += rnd.choice((-1, 0, 0, 1))
        if 70 < x < 110:
            t = max(t, 14 + int(10 * math.sin((x - 70) / 40 * math.pi)))
        t = max(0, min(18, t))
        profile.append(t)
    profile = ndi_smooth(profile)
    for i, t in enumerate(profile):
        x = 8 + i
        for y in range(top - 14 + t, top + t):
            cv.px(x, y, A[1] if y > top - 12 + t else A[2])
        for y in range(top + t, base):
            cv.px(x, y, A[3] if i < 3 else A[2])
    front = cv.opaque() & ~mask_of(cv, [A[1]])
    # exposed brick where the plaster fell off
    br = clean_mask(front & (blob_noise((cv.h, cv.w), 5, 3) > 0.25))
    retone(cv, br, BRICK)
    bricks(cv, br, BRICK, 8, 4, 2, mortar=A[1])
    # shop window (big, broken) + door + sign board (no lettering)
    cv.rect(20, 70, 100, 124, ST[0])
    _windows(cv, 22, 72, 98, 122, 2, A, broken=(1,))
    cv.rect(18, 68, 102, 69, A[3]); cv.rect(18, 125, 102, 127, A[1])
    box(cv, 120, 66, 30, 72, 2, WOOD)
    cv.rect(124, 72, 145, 100, E[1]); cv.rect(124, 104, 145, 132, E[1]); cv.px(144, 104, BR[3])
    box(cv, 30, 34, 120, 14, 3, BR)
    blotch(cv, m_rect(cv, 30, 34, 150, 51), [RU[0], RU[1], RU[1], RU[2]], 5, 1.4, 0.2)
    # torn awning (rust / cloth stripes) sagging over the window
    for x in range(14, 110):
        drop = 6 + int(3 * math.sin(x * 0.4)) + (x % 7 == 0) * 4
        for k in range(drop):
            stripe = (x // 6) % 2
            c = [RU[2], CL[2]][stripe] if k < drop - 1 else [RU[1], CL[1]][stripe]
            if k == 0:
                c = [RU[3], E[3]][stripe]
            cv.px(x, 56 + k, c)
    _rust_and_holes(cv, front, 15, 6, 0.55)
    ao_bottom(cv, cv.opaque(), 2)
    # rubble at the foot
    for (x, s) in ((40, 7), (110, 5), (170, 8), (196, 5), (12, 5)):
        r = rock(s * 2, s + 2, x, n=4, ramp=[A[0], A[1], A[2], A[3]])
        paste(cv, r, x, base - s // 2 - 1)
    return finish(cv)


# ================================================================ T5 BLIGHT
def quarantine_tent():
    cv = Cv(206, 132)
    # long ridge tent: gable end at the left (lit), long front slope (mid),
    # ridge line lit, white plastic canvas (ash) over olive frame
    P = [A[0], A[1], A[2], A[3]]
    ax, ay = 46, 12            # gable apex
    bx = 196                   # far end of the ridge
    face(cv, [(ax, ay), (bx, ay), (bx + 6, 110), (ax + 40, 112)], P[2], edge_hi=P[3])
    for x in range(ax + 26, bx, 30):  # frame hoops show through
        cv.fill(m_line(cv, (x - 2 + (x - ax) // 30, ay + 2), (x + 8 + (x - ax) // 30, 110), 1) & m_poly(cv, [(ax, ay), (bx, ay), (bx + 6, 110), (ax + 40, 112)]), P[1])
    face(cv, [(ax, ay), (ax + 40, 112), (ax - 40, 112)], CANVAS[3])
    cv.fill(m_line(cv, (ax, ay), (ax - 40, 112), 2), CANVAS[4])
    face(cv, [(ax, ay + 44), (ax + 14, 112), (ax - 14, 112)], CL[0])  # zipped door
    cv.rect(ax, ay + 46, ax, 111, CL[1])
    # red cross panel + hazard tape along the hem
    cv.rect(118, 44, 142, 68, CANVAS[4]); cv.rect(126, 47, 134, 65, BL); cv.rect(121, 52, 139, 60, BL)
    tape = m_line(cv, (ax + 40, 100), (bx + 4, 98), 4)
    for y, x in zip(*np.nonzero(tape)):
        cv.px(x, y, BR[2] if ((x + y) // 3) % 2 == 0 else INK)
    blotch(cv, mask_of(cv, P), [A[0], A[1], A[1], A[2]], 3, 2.6, 0.5)
    # plague creeping up the hem (non-emissive tones only)
    for x in range(4, 204):
        hgt = int(2 + 6 * max(0, math.sin(x * 0.07) + 0.4 * math.sin(x * 0.31)))
        col = [y for y in range(cv.h) if cv.get(x, y)]
        if not col:
            continue
        yb = max(col)
        for k in range(hgt):
            cv.px(x, yb - k, PL[1] if k < hgt - 2 else PL[0])
    out = finish(cv)
    for (x0, y0, x1, y1) in ((10, 114, 2, 128), (150, 110, 170, 128)):
        for i in range(30):
            x = x0 + (x1 - x0) * i / 30
            y = y0 + (y1 - y0) * i / 30
            if 0 <= x < out.w and 0 <= y < out.h and not out.get(x, y):
                out.px(x, y, E[2])
    return out


def hazard_barrier():
    cv = Cv(178, 56)
    for x0, w in ((4, 82), (90, 82)):
        # jersey barrier: sloped lit top, front face, flared foot
        face(cv, [(x0 + 4, 8), (x0 + w - 4, 8), (x0 + w - 4, 14), (x0 + 4, 14)], A[3])
        face(cv, [(x0 + 4, 14), (x0 + w - 4, 14), (x0 + w, 40), (x0, 40)], A[2])
        face(cv, [(x0, 40), (x0 + w, 40), (x0 + w, 48), (x0, 48)], A[1])
        hazard(cv, x0 + 6, 18, w - 12, 6, BR, period=4)
        cv.rect(x0, 40, x0, 47, A[2])
    # quarantine sign hung on the chain between
    for x in range(78, 98):
        cv.px(x, 20 + int(3 * math.sin((x - 78) / 20 * math.pi)), ST[1])
    box(cv, 80, 22, 18, 12, 2, CANVAS)
    m = m_ellipse(cv, 89, 30, 4, 4)
    cv.fill(m, PL[2]); cv.px(89, 30, CL[2]); cv.px(88, 29, PL[1])
    blotch(cv, mask_of(cv, A), [A[0], A[1], A[1], A[2]], 7, 1.5, 0.45)
    return finish(cv, keep={(89, 30)})


# ================================================================ T6 SHROUD (raiders: red rags)
def _rag(cv, x, y, L, seed):
    rnd = random.Random(seed)
    for k in range(L):
        w = 6 - k // 3
        for i in range(max(1, w)):
            cv.px(x + i + (k // 4) * rnd.choice((0, 1)), y + k, BL if i < w - 1 else RU[0])
        if k == 0:
            cv.rect(x, y, x + 3, y, RU[2])


def _skull(cv, x, y):
    B = [E[0], E[2], E[3], E[4]]
    m = m_ellipse(cv, x + 4, y + 4, 4.2, 4.0) | m_rect(cv, x + 2, y + 6, x + 6, y + 9)
    dome(cv, m, B, flat=0.5, hl=False, ao=False)
    cv.px(x + 2, y + 4, INK); cv.px(x + 3, y + 4, INK); cv.px(x + 5, y + 4, INK); cv.px(x + 6, y + 4, INK)
    cv.px(x + 4, y + 6, E[1])
    for i in range(3):
        cv.px(x + 3 + i, y + 8, E[1] if i % 2 else B[2])


def spike_barricade():
    cv = Cv(168, 70)
    # crossed timbers on a base log, sharpened, barbed wire, red rags, a skull
    cyl_h(cv, 6, 160, 50, 5, WOOD, cap_left=True)
    for x in range(14, 160, 30):
        beam(cv, (x - 10, 62), (x + 12, 8), 4, WOOD)
        beam(cv, (x + 14, 62), (x - 6, 10), 4, [E[0], E[1], E[1], E[2]])
        for (tx, ty) in ((x + 12, 8), (x - 6, 10)):
            cv.px(tx, ty - 1, E[4]); cv.px(tx, ty, E[3])
    _rag(cv, 42, 28, 13, 1)
    _rag(cv, 102, 24, 15, 2)
    _rag(cv, 144, 32, 12, 3)
    _skull(cv, 76, 38)
    blotch(cv, mask_of(cv, WOOD), [E[0], E[1], E[1], E[2]], 2, 1.2, 0.5)
    out = finish(cv)
    # barbed wire (1 px, no outline), with barbs
    for x in range(4, out.w - 4):
        y = 26 + int(3 * math.sin(x * 0.13))
        if not out.get(x, y):
            out.px(x, y, A[2])
        if x % 7 == 0:
            out.px(x, y - 1, A[3]); out.px(x + 1, y + 1, A[1])
    return out


def raider_totem():
    cv = Cv(66, 146)
    beam(cv, (30, 140), (30, 8), 5, WOOD)
    beam(cv, (10, 30), (52, 26), 4, WOOD)
    # stacked tyres at the foot
    t = tire()
    for k in range(3):
        paste(cv, t, 16, 116 - k * 11)
    _skull(cv, 26, 0)
    _skull(cv, 8, 32)
    _skull(cv, 44, 28)
    _rag(cv, 14, 42, 16, 4)
    _rag(cv, 46, 38, 20, 5)
    _rag(cv, 31, 60, 12, 6)
    # spikes nailed through the pole
    for y in (70, 84):
        for i in range(10):
            cv.px(20 + i, y, ST[2] if i < 5 else ST[1])
            cv.px(36 + i, y + 3, ST[2])
    return finish(cv)


# ================================================================ T8 BLACKOUT
def tank_wreck():
    cv = Cv(190, 92)
    T = [A[0], A[1], A[2], A[3]]
    # tracks: long rounded box with road wheels
    box(cv, 6, 50, 170, 20, 4, T)
    for x in range(14, 172, 20):
        m = m_ellipse(cv, x, 64, 8, 7)
        dome(cv, m, [A[0], A[1], A[2], A[3]], flat=0.35, hl=False, ao=False)
        cv.px(x, 64, A[1])
    for x in range(6, 176, 4):
        cv.px(x, 53, T[1]); cv.px(x, 73, T[0])
    # hull
    box(cv, 12, 30, 158, 14, 10, OLIVE)
    face(cv, [(170, 40), (184, 46), (184, 54), (170, 54)], OLIVE[1])
    # turret + barrel (aimed up-right, it went down fighting)
    m = m_ellipse(cv, 84, 26, 30, 14)
    dome(cv, m, OLIVE, flat=0.45, hl=True)
    beam(cv, (110, 22), (184, 4), 4, OLIVE)
    cv.rect(181, 1, 186, 7, OLIVE[1])
    cv.fill(m_ellipse(cv, 78, 18, 7, 4), INK)  # blown hatch
    cv.fill(m_ellipse(cv, 78, 17, 6, 3) & ~m_ellipse(cv, 78, 18, 7, 4), OLIVE[1])
    # stencil star (faded brass) + rust
    for (dx, dy) in ((0, -2), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (0, -1), (-1, 1), (1, 1), (0, 1)):
        cv.px(60 + dx, 38 + dy, BR[1])
    _rust_and_holes(cv, mask_of(cv, OLIVE), 23, 8, 0.25)
    return finish(cv, keep={(60, 36)})


def guard_post():
    cv = Cv(118, 166)
    # stilts with bracing
    for x in (18, 92):
        beam(cv, (x, 160), (x + (6 if x < 50 else -6), 60), 4, ST)
    beam(cv, (22, 150), (88, 70), 2, [ST[0], ST[1], ST[1], ST[2]])
    beam(cv, (88, 150), (22, 70), 2, [ST[0], ST[1], ST[1], ST[2]])
    # booth: olive plate walls, view slit, corrugated roof
    box(cv, 10, 40, 96, 34, 8, OLIVE)
    cv.rect(20, 54, 96, 59, INK); cv.rect(20, 54, 96, 54, A[1])
    for x in range(14, 104, 4):
        cv.rect(x, 61, x, 80, OLIVE[1])
    face(cv, [(4, 30), (112, 30), (110, 40), (6, 40)], ST[3], edge_hi=ST[3], edge_lo=ST[1])
    for x in range(6, 110, 5):
        cv.rect(x, 31, x, 39, ST[2])
    face(cv, [(30, 22), (90, 22), (112, 30), (4, 30)], ST[2], edge_hi=ST[3])
    # searchlight on the roof (dead lamp: steel lens, no emissive)
    box(cv, 76, 14, 14, 6, 4, ST)
    cv.rect(78, 18, 88, 22, A[2]); cv.px(79, 19, A[3])
    # sandbags around the legs
    sb = sandbags()
    paste(cv, sb, 8, 136)
    # ladder
    for y in range(80, 150):
        cv.px(60, y, ST[3]); cv.px(66, y, ST[1])
        if y % 6 == 0:
            cv.rect(60, y, 66, y, ST[2])
    _rust_and_holes(cv, mask_of(cv, OLIVE), 4, 4, 0.4)
    return finish(cv)


def bunker(open_=False):
    cv = Cv(212, 116)
    # earth berm piled over the sides and roof
    berm = m_poly(cv, [(4, 108), (30, 40), (70, 18), (140, 16), (184, 38), (208, 108)])
    dome(cv, berm, [E[0], E[1], E[2], E[2]], flat=0.35, hl=False)
    cv.fill(m_line(cv, (30, 40), (70, 18), 2) & berm, E[3])
    cv.fill(m_line(cv, (70, 18), (140, 16), 2) & berm, E[3])
    blotch(cv, berm, [CL[0], CL[1], CL[1], CL[2]], 2, 2.0, 0.4)
    # concrete face with hazard header
    box(cv, 40, 44, 132, 56, 8, CONC)
    hazard(cv, 44, 54, 124, 5, BR, period=4)
    blotch(cv, m_rect(cv, 40, 52, 171, 107), [A[0], A[1], A[1], A[2]], 6, 1.8, 0.4)
    # door
    if not open_:
        box(cv, 84, 64, 44, 42, 2, ST)
        for y in range(70, 104, 8):
            cv.rect(86, y, 125, y, ST[1])
        m = m_ellipse(cv, 106, 84, 8, 8)
        for y, x in zip(*np.nonzero(m & ~m_ellipse(cv, 106, 84, 6, 6))):
            cv.px(x, y, BR[3] if y < 83 else BR[1])
        for i in range(-6, 7):
            cv.px(106 + i, 84, BR[2]); cv.px(106, 84 + i, BR[2])
        for (x, y) in ((88, 68), (122, 68), (88, 100), (122, 100)):
            rivet(cv, x, y)
    else:
        cv.rect(84, 66, 127, 107, INK)
        cv.rect(86, 70, 125, 107, A[0])
        cv.rect(86, 100, 125, 107, A[1])  # floor catching light
        # door swung open toward the viewer (edge-on plate)
        face(cv, [(128, 64), (142, 70), (142, 112), (128, 107)], ST[2], edge_hi=ST[3], edge_lo=ST[1])
        m = m_ellipse(cv, 135, 88, 3, 7)
        cv.fill(m, BR[1])
    _rust_and_holes(cv, mask_of(cv, ST), 13, 2, 0.4)
    return finish(cv)


def bunker_open():
    return bunker(True)


# ================================================================ T9 DEADFALL
def slab_ruin():
    cv = Cv(206, 118)
    # big slab leaning on a broken wall stub, second slab flat, rebar everywhere
    wr = wall_ruin(64, 70, 21, CONC)
    paste(cv, wr, 120, 30)
    face(cv, [(10, 70), (120, 22), (138, 34), (30, 92)], A[3], edge_hi=A[3])
    face(cv, [(30, 92), (138, 34), (138, 42), (30, 100)], A[1])
    sl = m_poly(cv, [(10, 70), (120, 22), (138, 34), (30, 92)])
    blotch(cv, sl, [A[0], A[1], A[2], A[2]], 5, 1.6, 0.3)
    # crack across the slab
    x, y = 60, 52
    for k in range(30):
        x += 1; y += random.Random(k).choice((0, 1, 1))
        if sl[y, x]:
            cv.px(x, y, A[1]); cv.px(x + 1, y + 1, A[3])
    # flat slab in front
    face(cv, [(90, 96), (170, 92), (190, 104), (106, 110)], A[2], edge_hi=A[3])
    face(cv, [(106, 110), (190, 104), (190, 108), (106, 114)], A[1])
    # rebar
    for (x0, y0, dx, dy) in ((122, 26, 6, -14), (130, 30, 10, -10), (24, 82, -10, -6), (32, 88, -8, 2)):
        for i in range(14):
            cv.px(x0 + dx * i / 14, y0 + dy * i / 14, RU[2] if i % 3 else RU[1])
    return finish(cv)


def rubble_chunk():
    cv = Cv(66, 62)
    m = m_poly(cv, blob_poly(32, 32, 27, 24, 9, n=7, jit=0.15, flat_bottom=False))
    facets(cv, m, [A[0], A[1], A[2], A[3]], seed=6, n=8, tilt=0.3)
    blotch(cv, m, BRICK, 3, 2.0, 0.55)
    for (x0, y0, dx, dy) in ((40, 14, 10, -10), (20, 20, -8, -12)):
        for i in range(12):
            cv.px(x0 + dx * i / 12, y0 + dy * i / 12, RU[2] if i % 3 else RU[1])
    return finish(cv)


# ================================================================ T10 DUSTFALL
def dust_spire():
    cv = Cv(128, 186)
    base = m_poly(cv, blob_poly(64, 160, 58, 22, 3, n=10, jit=0.14))
    facets(cv, base, ROCK, seed=2, n=10, tilt=0.3)
    rnd = random.Random(8)
    shards = [(64, 4, 16, 160), (38, 50, 12, 162), (92, 40, 13, 160), (20, 100, 9, 166), (110, 96, 9, 164), (74, 70, 10, 168)]
    for (tx, ty, hw, by) in shards:
        L = [(tx, ty), (tx - hw, by - 12), (tx, by)]
        Rr = [(tx, ty), (tx, by), (tx + hw, by - 12)]
        # Dust crystal: lit left face amber 2, shade face amber 1, cores 0
        # Dust crystal: lit face amber 1, shade face amber 0; only the lit
        # edge and tip glint are emissive (the Dust itself is the loot colour)
        face(cv, L, D[1])
        face(cv, Rr, D[0])
        for k in range(ty + 3, by - 14):
            cv.px(tx - 1, k, D[2])
        for k in range(ty + 6, by - 20, 7):
            cv.px(tx - 2, k, D[3]); cv.px(tx - 2, k + 1, D[2])
        cv.px(tx - 1, ty + 1, D[4]); cv.px(tx - 1, ty + 2, D[3])
    ao_bottom(cv, cv.opaque(), 2)
    return finish(cv)


# ================================================================ radio-job / landmark set pieces
def field_tent():
    cv = Cv(206, 150)
    ax, ay = 76, 14  # apex of the front gable
    # far roof slope (shade) receding to the back-right
    face(cv, [(ax, ay), (ax + 96, ay - 8), (ax + 166, 118), (ax + 70, 126)], CANVAS[1], edge_hi=CANVAS[2])
    # front gable: lit, canvas
    face(cv, [(ax, ay), (ax + 70, 126), (ax - 66, 126)], CANVAS[2])
    cv.fill(m_line(cv, (ax, ay), (ax - 66, 126), 2), CANVAS[3])
    cv.fill(m_line(cv, (ax, ay), (ax + 96, ay - 8), 2), CANVAS[3])
    # door flap opening (dark) with a pinned-back flap
    face(cv, [(ax, ay + 40), (ax + 26, 126), (ax - 22, 126)], CL[0])
    face(cv, [(ax - 22, 126), (ax, ay + 40), (ax - 6, 126)], CANVAS[3])
    # red cross patch
    cv.rect(ax + 26, 70, ax + 46, 90, CANVAS[4]); cv.rect(ax + 33, 73, ax + 39, 87, BL); cv.rect(ax + 29, 77, ax + 43, 83, BL)
    blotch(cv, cv.opaque(), [CL[0], CL[1], CL[1], CL[2], E[3]], 6, 2.2, 0.5)
    # crate + drum beside it
    cr = crate_wood(26, 16, 7)
    remove_orphans(cr); outline(cr, False)
    paste(cv, cr, 170, 110)
    out = finish(cv)
    # guy ropes (1 px) to pegs
    for (x0, y0, x1, y1) in ((10, 128, 30, 146), (150, 120, 196, 146), (172, 20, 204, 60)):
        for i in range(40):
            x = x0 + (x1 - x0) * i / 40
            y = y0 + (y1 - y0) * i / 40
            if 0 <= x < out.w and 0 <= y < out.h and not out.get(x, y):
                out.px(x, y, E[2])
    return out


def market_stall():
    cv = Cv(206, 176)
    # posts
    for x in (16, 182):
        beam(cv, (x, 166), (x, 40), 4, WOOD)
    # counter with goods
    box(cv, 8, 96, 186, 56, 14, WOOD, top_ramp=[E[1], E[2], E[3], E[4]])
    for y in range(112, 152, 8):
        cv.rect(9, y, 192, y, E[1])
    rnd = random.Random(3)
    for i, x in enumerate(range(20, 186, 14)):
        liq = [PL[2], FL[3], BR[2], RU[2], TE[0]][i % 5]
        h_ = rnd.randint(10, 16)
        for y in range(104 - h_, 104):
            for xx in range(x, x + 7):
                edge = xx in (x, x + 6)
                c = ST[1] if edge else (ST[3] if xx == x + 1 else ST[2])
                if y > 104 - h_ + 4 and not edge:
                    c = liq if xx != x + 1 else ST[3]
                cv.px(xx, y, c)
        cv.rect(x + 2, 104 - h_ - 2, x + 4, 104 - h_ - 1, E[2])
    # hanging herb bundles + lamp
    for x in (40, 70, 130):
        for y in range(52, 64):
            cv.px(x + (y % 3 == 0), y, CL[2] if y % 2 else CL[1])
    cv.rect(160, 50, 160, 58, ST[1]); cv.rect(156, 58, 164, 62, ST[2]); cv.rect(157, 63, 163, 65, D[3]); cv.rect(159, 63, 161, 64, D[4])
    # awning: sloped striped canvas with a scalloped front edge
    for y in range(18, 48):
        k = (y - 18) / 30
        x0, x1 = int(10 - 6 * k), int(196 + 6 * k)
        for x in range(x0, x1):
            stripe = ((x - x0) * 12 // (x1 - x0)) % 2
            base = [RU[2], CL[2]][stripe]
            if y < 21:
                base = [RU[3], E[3]][stripe]
            if y > 44:
                base = [RU[1], CL[1]][stripe]
            cv.px(x, y, base)
    for x in range(4, 202):
        if (x // 8) % 2 == 0:
            cv.px(x, 48, [RU[1], CL[1]][((x - 4) * 12 // 198) % 2]); cv.px(x, 49, [RU[1], CL[1]][((x - 4) * 12 // 198) % 2])
    blotch(cv, cv.opaque(), [E[0], E[1], E[1], E[2], E[3]], 5, 2.2, 0.55)
    return finish(cv, keep={(157 + i, 63) for i in range(7)})


def medicine_crate():
    cv = Cv(50, 44)
    box(cv, 2, 4, 44, 26, 10, ST)
    # lid seam + latches + carry handle
    cv.rect(2, 22, 45, 22, ST[1])
    for x in (8, 36):
        cv.rect(x, 20, x + 3, 24, BR[2]); cv.px(x, 20, BR[3])
    cv.rect(18, 1, 29, 3, ST[1]); cv.rect(18, 1, 29, 1, ST[2])
    # white panel with blood-red cross (medicine)
    cv.rect(16, 25, 31, 37, CANVAS[4]); cv.rect(22, 26, 25, 36, BL); cv.rect(18, 29, 29, 32, BL)
    cv.rect(14, 6, 33, 11, CANVAS[4]); cv.rect(22, 7, 25, 10, BL); cv.rect(19, 8, 28, 9, BL)
    _rust_and_holes(cv, mask_of(cv, ST), 2, 1, 0.5)
    return finish(cv)


def plane_wreck():
    cv = Cv(290, 168)
    G = OLIVE
    # far wing (shade), fuselage, near wing broken off, tail, prop
    face(cv, [(120, 64), (190, 20), (222, 24), (170, 70)], G[1], edge_hi=G[2])
    cyl_h(cv, 40, 236, 86, 18, G, cap_left=False)
    # tapered tail section
    for x in range(40, 90):
        k = (90 - x) / 50
        for y in range(68, 106):
            if abs(y - 86) > 18 * (1 - 0.55 * k):
                cv.a[y, x, 3] = 0
    # tail fin + stabiliser
    face(cv, [(40, 80), (56, 34), (72, 36), (76, 76)], G[2], edge_hi=G[3], edge_lo=G[1])
    face(cv, [(30, 92), (74, 90), (80, 100), (34, 104)], G[3], edge_lo=G[1])
    # cockpit canopy (glass)
    m = m_ellipse(cv, 168, 68, 22, 10) & (np.mgrid[0:cv.h, 0:cv.w][0] < 72)
    cv.fill(m, ST[0])
    for k in range(12):
        cv.px(152 + k, 62 + k // 3, ST[2])
    for x in (160, 174):
        cv.rect(x, 58, x, 71, G[1])
    # engine cowl + prop (one blade snapped)
    cyl_h(cv, 236, 254, 86, 16, [A[0], A[1], A[2], A[3]], cap_left=False)
    cv.fill(m_ellipse(cv, 258, 86, 5, 8), A[2])
    beam(cv, (258, 86), (270, 48), 4, [A[0], A[1], A[2], A[3]])
    beam(cv, (258, 86), (276, 110), 4, [A[0], A[1], A[2], A[3]])
    beam(cv, (258, 86), (250, 100), 3, [A[0], A[1], A[2], A[3]])
    # near wing, snapped and lying in front
    face(cv, [(96, 112), (196, 104), (214, 134), (84, 150)], G[3], edge_hi=G[3], edge_lo=G[1])
    face(cv, [(84, 150), (214, 134), (214, 140), (84, 156)], G[1])
    # roundel: brass ring, rust core
    for (rx_, ry_, c) in ((11, 7, BR[2]), (8, 5, INK), (6, 4, RU[2])):
        cv.fill(m_ellipse(cv, 150, 126, rx_, ry_), c)
    for (rx_, ry_, c) in ((9, 9, BR[2]), (6, 6, INK), (4, 4, RU[2])):
        cv.fill(m_ellipse(cv, 120, 86, rx_, ry_), c)
    _rust_and_holes(cv, mask_of(cv, G), 8, 10, 0.3)
    # debris
    for (x, y) in ((40, 140), (232, 140), (262, 130)):
        r = rock(10, 6, x, n=3, ramp=[A[0], A[1], A[2], A[3]])
        paste(cv, r, x, y)
    return finish(cv)


def relay():
    cv = Cv(156, 156)
    # concrete pad
    box(cv, 8, 116, 140, 12, 22, CONC)
    # generator cabinet
    box(cv, 22, 72, 62, 46, 10, OLIVE)
    for y in range(90, 116, 4):
        cv.rect(30, y, 60, y, OLIVE[1])
    cv.rect(66, 88, 78, 98, ST[0]); cv.px(68, 90, TE[1]); cv.px(72, 90, TE[1]); cv.px(76, 90, TE[0])
    hazard(cv, 24, 112, 58, 4, BR)
    # lattice mast + dish
    beam(cv, (110, 136), (114, 12), 3, ST)
    beam(cv, (130, 136), (118, 12), 3, ST)
    for y in range(130, 20, -12):
        cv.fill(m_line(cv, (111, y), (127, y - 12), 1) & ~cv.opaque(), ST[1])
    dish = m_ellipse(cv, 96, 36, 14, 18)
    dome(cv, dish, CONC, flat=0.3, hl=False, ao=False)
    cv.fill(m_ellipse(cv, 98, 36, 9, 12), A[2])
    beam(cv, (98, 36), (110, 32), 2, ST)
    # cables to the cabinet
    for i in range(30):
        cv.px(84 + i, 100 + int(8 * math.sin(i / 30 * math.pi)), A[1])
    _rust_and_holes(cv, mask_of(cv, OLIVE), 3, 3, 0.45)
    return finish(cv, keep={(68, 90), (72, 90), (76, 90)})


def vault():
    cv = Cv(226, 158)
    box(cv, 8, 20, 208, 96, 34, CONC)
    blotch(cv, cv.opaque(), [A[0], A[1], A[1], A[2]], 3, 2.2, 0.35)
    bricks(cv, m_rect(cv, 9, 55, 214, 150), CONC, 26, 12, 1)
    # round vault door: steel, brass bolts, spoked wheel
    cx, cy = 112, 96
    for rr, c in ((40, ST[0]), (37, ST[1])):
        cv.fill(m_ellipse(cv, cx, cy, rr, rr * 0.92), c)
    door = m_ellipse(cv, cx, cy, 34, 31)
    dome(cv, door, ST, flat=0.25, hl=False, ao=False)
    for k in range(12):
        t = 2 * math.pi * k / 12
        rivet(cv, int(cx + 30 * math.cos(t)), int(cy + 27 * math.sin(t)))
    for k in range(3):
        t = k * math.pi / 3
        cv.fill(m_line(cv, (cx - 14 * math.cos(t), cy - 14 * math.sin(t)), (cx + 14 * math.cos(t), cy + 14 * math.sin(t)), 2), BR[2])
    for y, x in zip(*np.nonzero(m_ellipse(cv, cx, cy, 15, 14) & ~m_ellipse(cv, cx, cy, 12, 11))):
        cv.px(x, y, BR[3] if y < cy else BR[1])
    cv.fill(m_ellipse(cv, cx, cy, 4, 4), BR[1])
    hazard(cv, 12, 140, 200, 5, BR, period=5)
    return finish(cv)


def watch_tower():
    cv = Cv(156, 254)
    # legs (the far pair in shade), cross bracing, ladder, platform at y~64
    for (x0, x1, rmp) in ((14, 30, WOOD), (140, 124, [E[0], E[1], E[1], E[2]]), (44, 50, [E[0], E[1], E[1], E[2]]), (112, 106, WOOD)):
        beam(cv, (x0, 250), (x1, 64), 5, rmp)
    for y0 in range(240, 80, -44):
        for (a, b) in (((18, y0), (122, y0 - 40)), ((136, y0), (28, y0 - 40))):
            cv.fill(m_line(cv, a, b, 2) & ~cv.opaque(), E[1])
        cv.fill(m_line(cv, (16, y0), (138, y0), 2) & ~cv.opaque(), E[2])
    for y in range(80, 250):
        cv.px(70, y, E[3]); cv.px(80, y, E[1])
        if y % 7 == 0:
            cv.rect(70, y, 80, y, E[2])
    # platform deck + plank parapet + sandbags
    box(cv, 8, 58, 140, 8, 12, WOOD, top_ramp=[E[1], E[2], E[3], E[4]])
    box(cv, 8, 36, 140, 22, 2, WOOD)
    for x in range(12, 146, 10):
        cv.rect(x, 39, x, 59, E[1])
    sb = sandbags()
    paste(cv, sb, 24, 28)
    # roof on four posts
    for x in (12, 140):
        cv.rect(x, 6, x + 2, 36, E[2]); cv.rect(x, 6, x, 36, E[3])
    face(cv, [(2, 6), (154, 6), (148, 14), (8, 14)], RU[2], edge_hi=RU[3], edge_lo=RU[1])
    for x in range(6, 152, 6):
        cv.rect(x, 7, x, 13, RU[1])
    blotch(cv, mask_of(cv, WOOD), [E[0], E[1], E[1], E[2]], 9, 1.4, 0.5)
    return finish(cv)


# the platform deck (y of its top surface) in the final sprite, for NPC perches
WATCH_TOWER_DECK = 58


# ================================================================ T1 HAZE / T2 DRIFT
def power_pole():
    cv = Cv(70, 156)
    beam(cv, (34, 152), (34, 10), 5, WOOD)
    beam(cv, (6, 22), (64, 20), 4, WOOD)
    beam(cv, (16, 36), (52, 35), 3, WOOD)
    for (x, y) in ((8, 18), (22, 17), (46, 16), (60, 16), (18, 32), (50, 31)):
        cv.rect(x, y - 3, x + 2, y, ST[2]); cv.px(x, y - 3, ST[3])
    # transformer can + climbing pegs
    cyl_v(cv, 22, 6, 2, 46, 62, ST, rim=True)
    for y in range(70, 140, 9):
        cv.rect(38, y, 41, y, ST[2])
    # a red rag tied at head height: someone marked the road
    cv.rect(37, 96, 40, 99, BL); cv.px(41, 100, BL); cv.px(42, 101, RU[0]); cv.rect(37, 96, 40, 96, RU[2])
    blotch(cv, mask_of(cv, WOOD), [E[0], E[1], E[1], E[2]], 7, 1.3, 0.5)
    out = finish(cv)
    # snapped wires hanging off the arm (1 px, no outline)
    for (x0, y0, L) in ((8, 19, 30), (61, 17, 22)):
        for i in range(L):
            out.px(x0 + int(3 * math.sin(i / 9)), y0 + i, A[1])
    return out


def wreck_pile():
    cv = Cv(116, 96)
    # two crushed cars stacked, the top one skewed
    box(cv, 4, 54, 104, 22, 12, RU)
    _windows(cv, 30, 70, 80, 76, 2, RU, broken=(0, 1))
    face(cv, [(16, 24), (98, 14), (104, 40), (20, 52)], ST[3], edge_hi=ST[3])
    face(cv, [(20, 52), (104, 40), (104, 56), (20, 66)], ST[2], edge_lo=ST[1])
    cv.fill(m_poly(cv, [(40, 48), (76, 43), (76, 52), (40, 57)]), ST[0])
    for k in range(6):
        cv.px(42 + k * 5, 50 - k, ST[2])
    wheel(cv, 24, 84, 7); wheel(cv, 90, 84, 7)
    _rust_and_holes(cv, cv.opaque(), 33, 8, 0.3)
    return finish(cv)


def beast_ribs():
    cv = Cv(150, 96)
    B = [E[0], E[2], E[3], E[4]]
    # spine along the ground, ribs arching up out of the sand
    for x in range(10, 140):
        y = 82 - int(4 * math.sin((x - 10) / 130 * math.pi))
        cv.px(x, y, B[2]); cv.px(x, y + 1, B[1]); cv.px(x, y + 2, B[1])
        if x % 6 == 0:
            cv.px(x, y - 1, B[3])
    for i, x0 in enumerate(range(26, 128, 13)):
        hgt = 60 - abs(i - 3) * 9
        pts = [(x0 + 10 * math.cos(math.pi * t / 20) - 4, 80 - hgt * math.sin(math.pi * t / 20)) for t in range(21)]
        for (p0, p1) in zip(pts, pts[1:]):
            lit = p1[0] > x0 - 4
            m = m_line(cv, p0, p1, 2)
            cv.fill(m, B[2] if lit else B[1])
            cv.px(p0[0] - 1, p0[1], B[3] if lit else B[2])
    # skull at the front end, half in the sand
    m = m_ellipse(cv, 16, 72, 13, 10) | m_poly(cv, [(4, 70), (-6, 82), (8, 84)])
    dome(cv, m, B, flat=0.5, hl=True, ao=False)
    cv.fill(m_ellipse(cv, 14, 70, 3, 3), E[0]); cv.px(15, 69, INK)
    # sand drift over the base (earth facets)
    sand = m_poly(cv, [(0, 92), (20, 82), (60, 86), (100, 83), (146, 88), (150, 95), (0, 95)])
    facets(cv, sand, [E[0], E[1], E[2], E[3]], seed=5, n=8, tilt=0.2, hl=False)
    return finish(cv)


def buried_wreck():
    cv = Cv(110, 96)
    # a car nose-down in a dune: roof and windscreen up, boot in the air
    face(cv, [(30, 6), (84, 18), (92, 60), (34, 52)], RU[2], edge_hi=RU[3], edge_lo=RU[1])   # roof/boot face (lit)
    face(cv, [(84, 18), (100, 26), (104, 66), (92, 60)], RU[1])                                # side in shade
    face(cv, [(36, 52), (92, 60), (90, 70), (38, 64)], ST[0])                                  # rear window
    for k in range(10):
        cv.px(42 + k * 4, 56 + k // 2, ST[2])
    cv.rect(34, 8, 40, 11, BR[1]); cv.rect(76, 18, 82, 21, BR[1])                                # tail lights (dead)
    cv.fill(m_line(cv, (30, 4), (86, 16), 2), ST[2])                                             # bumper
    wheel(cv, 100, 34, 8)
    _rust_and_holes(cv, cv.opaque(), 17, 5, 0.3)
    dune = m_poly(cv, [(2, 92), (18, 66), (50, 60), (88, 64), (108, 80), (108, 95), (2, 95)])
    facets(cv, dune, [E[0], E[1], E[2], E[3]], seed=3, n=9, tilt=0.2, hl=False)
    return finish(cv)
