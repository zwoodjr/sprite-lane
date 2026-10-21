"""World-scale pass (density + scale): vehicles, walls, fences and set pieces
redrawn at real proportions against the hero (body ~100 tx tall).

  car ~2.3x hero length, truck ~3x, bus ~4x, barrels ~0.4x hero height,
  walls / fences hero height and up, landmarks as large set pieces.

Same kit and rules as the rest of Track A (pk.py): 1 texel density, top-left
light, 3 tones + highlight per material, tone-0 outline with selout, no baked
ground shadow. Details (seams, rivets, glints, AO) stay 1-2 tx at any size, so
the big art reads at the same density as the hero, not as an upscale."""
import math
import random
import numpy as np
from pk import *
from props_small import WOOD, ROCK, SAND, blob_poly, rock, drum, crate_wood, tire
from props_large import CONC, BRICK, _windows, ndi_smooth

OLIVE = [CL[0], CL[1], CL[2], E[3]]
CANVAS = [CL[0], CL[1], CL[2], E[3], E[4]]
TYRE = [A[0], A[1], A[2], A[3]]
FADED_BLUE = [ST[0], ST[1], ST[2], ST[3]]


# ================================================================ shared bits
def seam_v(cv, x, y0, y1, ramp_dark=None):
    """Vertical panel seam: 1 px dark line + 1 px lit lip to its right."""
    for y in range(int(y0), int(y1) + 1):
        c = cv.get(x, y)
        if c in REV:
            rn, i = REV[c]
            rr = R(rn)
            cv.px(x, y, rr[max(0, i - 1)] if ramp_dark is None else ramp_dark)
            c2 = cv.get(x + 1, y)
            if c2 in REV and REV[c2][0] == rn:
                cv.px(x + 1, y, rr[min(len(rr) - 1, REV[c2][1] + 1)] if rn != "ash" or REV[c2][1] < 3 else c2)


def seam_h(cv, x0, x1, y):
    for x in range(int(x0), int(x1) + 1):
        c = cv.get(x, y)
        if c in REV:
            rn, i = REV[c]
            rr = R(rn)
            cv.px(x, y, rr[max(0, i - 1)])
            c2 = cv.get(x, y + 1)
            if c2 in REV and REV[c2][0] == rn and rn != "ash":
                cv.px(x, y + 1, rr[min(len(rr) - 1, REV[c2][1] + 1)])


def arch(cv, cx, cy, r):
    """Dark wheel-well cut into the body above a wheel."""
    m = m_ellipse(cv, cx, cy, r * 0.78 + 3, r + 4) & (cv.grid()[0] < cy + 2) & cv.opaque()
    cv.fill(m, A[0])
    rim = m & ~m_ellipse(cv, cx, cy, r * 0.78 + 2, r + 3)
    for y, x in zip(*np.nonzero(rim)):
        cv.px(x, y, A[1])


def big_wheel(cv, cx, cy, r, flat=False, bare=False):
    """Car / truck wheel, 3/4 side view: tyre with tread rim, steel hub."""
    rx = r * 0.62
    m = m_ellipse(cv, cx, cy, rx, r)
    if flat:
        m &= cv.grid()[0] < cy + r - 3
    if not bare:
        for y, x in zip(*np.nonzero(m)):
            dy = (y + 0.5 - cy) / r
            dx = (x + 0.5 - cx) / rx
            t = 2 if (dy < -0.62 and dx < 0.4) else (1 if dy < 0.55 else 0)
            cv.px(x, y, A[t])
        # tread blocks on the lit top edge
        for k in range(-3, 4):
            yy = int(cy - r * math.sqrt(max(0, 1 - (k / 4.0) ** 2))) + 1
            cv.px(int(cx + k * rx / 4), yy, A[3] if k < 0 else A[2])
    hub = m_ellipse(cv, cx + 0.5, cy, rx * 0.5, r * 0.48)
    for y, x in zip(*np.nonzero(hub)):
        dy = (y + 0.5 - cy) / (r * 0.48)
        dx = (x + 0.5 - cx) / (rx * 0.5)
        cv.px(x, y, (ST[3] if dx < -0.2 else ST[2]) if dy < -0.25 else (ST[1] if dy < 0.6 else ST[0]))
    if bare:
        cv.fill(m_ellipse(cv, cx, cy, rx * 0.28, r * 0.26), RU[1])
    else:
        cv.fill(m_ellipse(cv, cx + 0.5, cy + 0.5, max(1.5, rx * 0.16), max(1.5, r * 0.16)), ST[0])
        for a in (0.8, 2.4, 4.0, 5.6):
            cv.px(cx + math.cos(a) * rx * 0.34, cy + math.sin(a) * r * 0.32, ST[0])


def dents(cv, region, seed, n=6, size=(4, 9)):
    """Shallow dents: a short dark crescent (shade, lower-right) and a lit
    rim (upper-left), 2-3 px clusters only."""
    rnd = random.Random(seed)
    ys, xs = np.nonzero(region)
    if not len(ys):
        return
    for _ in range(n):
        k = rnd.randrange(len(ys))
        x, y = int(xs[k]), int(ys[k])
        L = rnd.randint(*size)
        for j in range(L):
            for (dx, dy, d) in ((j, 0, -1), (j - 1, -1, 1)):
                xx, yy = x + dx, y + dy + (j * j) // (L * 2)
                if region[min(cv.h - 1, max(0, yy)), min(cv.w - 1, max(0, xx))]:
                    c = cv.get(xx, yy)
                    if c in REV:
                        rn, i = REV[c]
                        rr = R(rn)
                        cv.px(xx, yy, rr[max(0, min(len(rr) - 1 if rn != "ash" else 3, i + d))])


def holes(cv, region, seed, n=6, big=False):
    """Rust-through holes: INK core, tone-0 rim, lit lower lip."""
    rnd = random.Random(seed)
    ys, xs = np.nonzero(region)
    if not len(ys):
        return
    for _ in range(n):
        k = rnd.randrange(len(ys))
        x, y = int(xs[k]), int(ys[k])
        w, h_ = (rnd.randint(2, 4), rnd.randint(2, 3)) if big else (2, 2)
        if not region[min(cv.h - 1, y + h_), min(cv.w - 1, x + w)]:
            continue
        cv.rect(x, y, x + w - 1, y + h_ - 1, INK)
        cv.rect(x - 1, y, x - 1, y + h_ - 1, RU[0])
        cv.rect(x, y + h_, x + w - 1, y + h_, RU[2])


def rust(cv, region, seed, amount=0.2, scale=3.2):
    """Rust that creeps from the bottom and the panel edges (not polka dots):
    clustered noise biased by height in the region and distance to its edge."""
    if not region.any():
        return
    from scipy import ndimage as _nd
    n = blob_noise((cv.h, cv.w), scale * 0.6, seed)
    ys, xs = np.nonzero(region)
    y0, y1 = ys.min(), ys.max()
    yy = cv.grid()[0]
    low = np.clip((yy - y0) / max(1, y1 - y0), 0, 1)
    edge = _nd.distance_transform_edt(region)
    near = np.clip(1.0 - edge / 6.0, 0, 1)
    score = n + 0.55 * low ** 2 + 0.45 * near - 0.35
    m = clean_mask(region & (score > amount + 0.25))
    retone(cv, m, [RU[0], RU[1], RU[1], RU[2]])
    core = clean_mask(m & (score > amount + 0.55))
    retone(cv, core, [RU[0], RU[0], RU[1], RU[1]])


def lamp(cv, x, y, w, h_, lit_c, dark_c):
    cv.rect(x, y, x + w - 1, y + h_ - 1, dark_c)
    cv.rect(x, y, x + w - 2, y, lit_c)


def glass(cv, x0, y0, x1, y1, broken=False, seed=0):
    """Side window: dark steel glass with a diagonal sky glint (top-left)."""
    cv.rect(x0, y0, x1, y1, ST[0])
    if broken:
        rnd = random.Random(seed)
        cv.rect(x0 + 1, y0 + 1, x1 - 1, y1, A[0])
        # jagged shards left in the frame
        for x in range(x0 + 1, x1):
            L = rnd.choice((0, 0, 1, 2, 3))
            for j in range(L):
                cv.px(x, y0 + 1 + j, ST[1] if j else ST[2])
        return
    ww, hh = x1 - x0, y1 - y0
    for k in range(0, min(ww, hh * 2) - 2):
        y = y0 + 1 + k // 2
        if y >= y1:
            break
        cv.px(x0 + 2 + k, y, ST[2])
        cv.px(x0 + 3 + k, y, ST[1])
    cv.px(x0 + 1, y0 + 1, ST[3])
    cv.rect(x0, y1, x1, y1, ST[1])


# ================================================================ vehicles
def _car(paint, seed, burnt=False, door_open=True, hood_up=False):
    WY = 100  # wheel centre row
    """Sedan wreck, 3/4 view from the front-left-top, ~236 x 110 tx."""
    rnd = random.Random(seed)
    W, H_ = 244, 128
    cv = Cv(W, H_)
    # lower body: deck (hood + boot) on top, side below
    body_ramp = paint
    # hood slopes down to the nose on the left: draw the deck as a polygon
    face(cv, [(10, 58), (60, 50), (178, 50), (232, 56), (232, 76), (10, 78)], body_ramp[3], edge_hi=body_ramp[min(3, len(body_ramp) - 1)])
    cv.rect(10, 58, 59, 58, body_ramp[3])
    # side panel
    face(cv, [(8, 78), (234, 76), (234, 106), (10, 108)], body_ramp[2])
    cv.rect(8, 78, 234, 78, body_ramp[3] if len(body_ramp) > 3 else body_ramp[2])
    # lower sill in shade
    face(cv, [(10, 100), (234, 98), (234, 106), (10, 108)], body_ramp[1])
    # cabin: roof + pillars + glass
    face(cv, [(66, 16), (166, 16), (176, 26), (58, 26)], body_ramp[3])           # roof top (lit)
    cv.rect(66, 16, 166, 16, body_ramp[3])
    face(cv, [(58, 26), (176, 26), (186, 50), (48, 50)], body_ramp[2])            # cabin side
    # windscreen strip seen over the hood (front, left) and rear screen (right)
    face(cv, [(48, 50), (58, 26), (66, 26), (60, 50)], ST[0])
    face(cv, [(176, 26), (186, 50), (178, 50), (170, 26)], ST[0])
    if not burnt:
        for k in range(10):
            cv.px(57 - k // 3, 30 + k * 2, ST[2])
    # side windows: front door, rear door, quarter glass
    glass(cv, 64, 30, 104, 46, broken=burnt, seed=seed)
    glass(cv, 110, 30, 150, 46, broken=True, seed=seed + 1)
    glass(cv, 156, 30, 172, 46, broken=burnt, seed=seed + 2)
    for x in (106, 152):
        cv.rect(x, 28, x + 2, 49, body_ramp[1]); cv.rect(x, 28, x, 49, body_ramp[2])
    # door seams + handles on the side
    for x in (62, 108, 156):
        seam_v(cv, x, 79, 104)
    seam_h(cv, 10, 232, 88)
    for x in (96, 142):
        cv.rect(x, 83, x + 6, 84, ST[2] if not burnt else A[1]); cv.rect(x, 85, x + 6, 85, ST[0])
    # hood / boot shut lines on the deck
    seam_v(cv, 60, 51, 77)
    seam_v(cv, 178, 51, 76)
    # nose: grille + headlight, tail: lamp
    cv.rect(8, 80, 13, 96, ST[0]); cv.rect(9, 81, 12, 81, ST[1])
    for y in range(83, 96, 3):
        cv.rect(9, y, 12, y, ST[1])
    lamp(cv, 10, 70, 8, 5, (BONE if not burnt else A[2]), A[1])
    lamp(cv, 226, 66, 6, 6, RU[3] if not burnt else A[2], RU[1])
    # bumpers
    face(cv, [(4, 98), (14, 98), (14, 106), (4, 106)], ST[2] if not burnt else A[2])
    cv.rect(4, 98, 14, 98, ST[3] if not burnt else A[3])
    face(cv, [(228, 96), (238, 96), (238, 104), (228, 104)], ST[1] if not burnt else A[1])
    cv.rect(228, 96, 238, 96, ST[2] if not burnt else A[2])
    # mirror
    cv.rect(54, 44, 58, 48, body_ramp[1]); cv.rect(54, 44, 57, 44, body_ramp[3])
    # wheel wells + wheels (back one flat)
    arch(cv, 50, WY, 16)
    arch(cv, 190, WY, 16)
    if door_open and not burnt:
        # rear door gone: dark interior with a seat back
        cv.rect(110, 79, 154, 104, A[0])
        cv.rect(110, 79, 154, 80, A[1])
        cv.rect(112, 84, 116, 104, CL[1]); cv.rect(112, 84, 116, 84, CL[2])
    body = cv.opaque()
    if burnt:
        blotch(cv, body, [RU[0], RU[0], RU[1], RU[1]], seed, 3.0, 0.15)
        blotch(cv, body, [A[0], A[0], A[1], A[1]], seed + 4, 2.6, 0.3)
    else:
        rust(cv, mask_of(cv, body_ramp) & (cv.grid()[0] > 77), seed, 0.1, 2.4)
        rust(cv, mask_of(cv, body_ramp) & (cv.grid()[0] <= 77), seed + 7, 0.3, 2.0)
        dents(cv, mask_of(cv, body_ramp), seed, 9, (5, 10))
    holes(cv, body & (cv.grid()[0] > 80), seed + 3, 7, big=True)
    streaks(cv, body & (cv.grid()[0] > 78), None, seed, 0)
    big_wheel(cv, 50, WY + 2, 16, bare=burnt)
    big_wheel(cv, 190, WY + 2, 16, flat=not burnt, bare=burnt)
    return finish(cv)


FADED = [E[0], E[1], E[2], E[3]]
RED = [RU[0], RU[0], RU[1], E[2]]


def wreck_car():
    return _car(FADED, 3)


def wreck_car_red():
    return _car(RED, 17)


def wreck_car_blue():
    return _car(FADED_BLUE, 8)


def wreck_car_olive():
    return _car(OLIVE, 13)


def wreck():
    """Burnt-out car hulk on its rims (wreck-field core)."""
    return _car([A[0], A[1], A[1], A[2]], 5, burnt=True)


def wreck_truck():
    """Flatbed truck, cab on the right, ~300 x 140."""
    W, H_ = 312, 150
    cv = Cv(W, H_)
    G = [CL[0], CL[1], CL[2], E[3]]
    # flatbed deck (planks) + low side boards
    face(cv, [(8, 58), (196, 58), (196, 84), (8, 84)], E[2])
    for x in range(14, 196, 12):
        cv.rect(x, 59, x, 83, E[1])
        cv.rect(x + 1, 59, x + 1, 83, E[3])
    cv.rect(8, 58, 196, 58, E[3])
    face(cv, [(6, 84), (198, 84), (198, 104), (6, 104)], WOOD[2])
    cv.rect(6, 84, 198, 84, WOOD[3])
    for y in (91, 98):
        cv.rect(6, y, 198, y, E[1])
    cv.rect(6, 84, 7, 104, WOOD[3])
    for x in (60, 130):
        cv.rect(x, 84, x + 3, 104, ST[1]); cv.rect(x, 84, x, 104, ST[2])
    # cargo: tarp-covered load + a strapped drum
    tarp = m_poly(cv, [(20, 66), (40, 40), (110, 34), (150, 44), (160, 70), (24, 74)])
    dome(cv, tarp, OLIVE, flat=0.3, hl=True)
    for x in (60, 112):
        cv.fill(m_line(cv, (x, 34), (x + 6, 76), 2) & tarp, BR[1])
    dr = drum(ST, True, 22, 30, 6)
    paste(cv, dr, 164, 44)
    # cab: hood + cab box
    face(cv, [(196, 28), (250, 28), (256, 40), (196, 40)], G[3])                 # cab roof
    face(cv, [(196, 40), (256, 40), (256, 104), (196, 104)], G[2])               # cab side
    face(cv, [(256, 52), (298, 56), (298, 70), (256, 70)], G[3])                 # hood top
    face(cv, [(256, 70), (298, 70), (302, 106), (256, 106)], G[2])               # nose side
    cv.rect(256, 52, 298, 52, G[3])
    face(cv, [(256, 40), (264, 40), (264, 52), (256, 52)], ST[0])               # windscreen edge
    glass(cv, 220, 46, 250, 66, broken=False)
    seam_v(cv, 214, 42, 102)
    seam_v(cv, 256, 41, 105)
    cv.rect(242, 76, 248, 77, ST[2]); cv.rect(242, 78, 248, 78, ST[0])
    # grille + headlight
    cv.rect(296, 74, 302, 100, ST[0])
    for y in range(76, 100, 3):
        cv.rect(297, y, 301, y, ST[1])
    lamp(cv, 292, 62, 8, 6, BONE, A[1])
    face(cv, [(294, 102), (308, 102), (308, 110), (294, 110)], ST[2]); cv.rect(294, 102, 308, 102, ST[3])
    # exhaust stack behind the cab
    cv.rect(190, 10, 194, 58, ST[2]); cv.rect(190, 10, 190, 58, ST[3]); cv.rect(194, 10, 194, 58, ST[1])
    cv.rect(189, 8, 195, 10, ST[1])
    # chassis rail
    face(cv, [(6, 104), (302, 104), (302, 112), (6, 112)], ST[0])
    cv.rect(6, 104, 302, 104, ST[1])
    arch(cv, 44, 120, 19)
    arch(cv, 150, 120, 19)
    arch(cv, 270, 118, 19)
    body = cv.opaque()
    rust(cv, mask_of(cv, G), 12, 0.15, 2.4)
    dents(cv, mask_of(cv, G), 12, 7, (5, 9))
    holes(cv, mask_of(cv, G) & (cv.grid()[0] > 70), 4, 4, big=True)
    blotch(cv, mask_of(cv, WOOD) | mask_of(cv, [E[1], E[2], E[3]]), [E[0], E[1], E[1], E[2]], 7, 1.6, 0.5)
    big_wheel(cv, 44, 122, 19)
    big_wheel(cv, 150, 122, 19, flat=True)
    big_wheel(cv, 270, 120, 19)
    return finish(cv)


def wreck_bus():
    """School-bus-yellow (brass) coach on its side wheels, ~410 x 160."""
    W, H_ = 420, 170
    cv = Cv(W, H_)
    Y = [BR[0], BR[1], BR[2], BR[3]]
    # roof (grey, lit), side (brass), skirt
    face(cv, [(12, 14), (396, 14), (404, 34), (6, 34)], A[3])
    cv.rect(12, 14, 396, 14, A[3])
    face(cv, [(6, 34), (404, 34), (404, 128), (6, 128)], Y[2])
    cv.rect(6, 34, 404, 35, Y[3])
    face(cv, [(6, 118), (404, 118), (404, 130), (6, 130)], Y[1])
    # roof hatches + rust on the roof
    for x in (70, 190, 310):
        face(cv, [(x, 18), (x + 34, 18), (x + 36, 28), (x - 2, 28)], A[2]); cv.rect(x, 18, x + 34, 18, A[3])
        cv.rect(x - 2, 28, x + 36, 28, A[1])
    # window band: 10 windows, some smashed, pillars between
    xs = list(range(22, 370, 36))
    for i, x in enumerate(xs):
        glass(cv, x, 46, x + 28, 72, broken=(i in (2, 3, 6, 9)), seed=i)
    cv.rect(10, 44, 400, 44, Y[1]); cv.rect(10, 74, 400, 75, Y[1])
    # black rub strips
    for y in (86, 104):
        cv.rect(6, y, 404, y + 1, INK); cv.rect(6, y + 2, 404, y + 2, Y[3])
    # door at the front (right) + front face
    face(cv, [(372, 44), (398, 44), (398, 126), (372, 126)], Y[1])
    cv.rect(374, 48, 384, 122, ST[0]); cv.rect(386, 48, 396, 122, ST[0])
    cv.px(375, 49, ST[3]); cv.px(387, 49, ST[3])
    cv.rect(375, 50, 375, 70, ST[2]); cv.rect(387, 50, 387, 70, ST[2])
    face(cv, [(404, 34), (414, 40), (414, 128), (404, 128)], Y[1])
    lamp(cv, 406, 104, 6, 6, BONE, A[1])
    # stop-arm sign folded on the side (blood red, no lettering)
    face(cv, [(340, 82), (356, 82), (360, 90), (356, 98), (340, 98), (336, 90)], BL)
    cv.rect(340, 82, 356, 82, RU[2])
    # panel rivet lines
    for x in range(10, 400, 48):
        seam_v(cv, x, 77, 116)
    for x in range(14, 400, 8):
        if cv.get(x, 79) in (Y[2], Y[1]):
            rivet(cv, x, 79, Y)
    # skirt + bumper
    face(cv, [(2, 128), (414, 128), (414, 136), (2, 136)], ST[1])
    cv.rect(2, 128, 414, 128, ST[2])
    arch(cv, 70, 138, 21)
    arch(cv, 330, 138, 21)
    body = cv.opaque()
    rust(cv, mask_of(cv, Y), 21, 0.12, 2.6)
    rust(cv, mask_of(cv, [A[1], A[2], A[3]]) & (cv.grid()[0] < 34), 22, 0.3, 2.0)
    dents(cv, mask_of(cv, Y), 21, 12, (6, 12))
    holes(cv, mask_of(cv, Y) & (cv.grid()[0] > 76), 23, 10, big=True)
    streaks(cv, mask_of(cv, Y) & (cv.grid()[0] > 76), None, 2, 0)
    big_wheel(cv, 70, 140, 21, flat=True)
    big_wheel(cv, 330, 140, 21)
    return finish(cv)


# ================================================================ re-laid-out zone props / landmarks
import props_zone as _Z
import props_large as _L
from rescale import rescaled as _rs

_K = {
    # zone props (T1-T10)
    "pipe_rack": (_Z.pipe_rack, 1.6), "oil_tank": (_Z.oil_tank, 1.45), "street_lamp": (_Z.street_lamp, 1.5),
    "shop_ruin": (_Z.shop_ruin, 1.6), "quarantine_tent": (_Z.quarantine_tent, 1.5), "hazard_barrier": (_Z.hazard_barrier, 1.7),
    "spike_barricade": (_Z.spike_barricade, 1.7), "raider_totem": (_Z.raider_totem, 1.35), "tank_wreck": (_Z.tank_wreck, 1.75),
    "guard_post": (_Z.guard_post, 1.5), 
    "slab_ruin": (_Z.slab_ruin, 1.7), "rubble_chunk": (_Z.rubble_chunk, 1.3), "dust_spire": (_Z.dust_spire, 1.5),
    "power_pole": (_Z.power_pole, 1.5), "beast_ribs": (_Z.beast_ribs, 1.9),
    # radio-job / landmark set pieces
    "field_tent": (_Z.field_tent, 1.6), "market_stall": (_Z.market_stall, 1.6), "plane_wreck": (_Z.plane_wreck, 1.7),
    "relay": (_Z.relay, 1.5), "vault": (_Z.vault, 1.6), "watch_tower": (_Z.watch_tower, 1.35),
    # road / ruin dressing
    "wall_collapsed": (_L.wall_collapsed, 2.0), 
    "pole_down": (_L.pole_down, 1.4), "signal_tower": (_L.signal_tower, 1.6),
}


def big(name):
    fn, k = _K[name]
    return _rs(fn, k)()


# ================================================================ hand-drawn at the new scale
def bunker_open_big():
    return bunker_big(True)


def sandbags_big(n_cols=10, rows=5, seed=7):
    """Waist-high sandbag wall (~0.55x hero), bags stacked in running bond."""
    bw, bh = 14, 9
    W = n_cols * bw + 16
    H_ = rows * (bh - 1) + 14
    cv = Cv(W, H_)
    rnd = random.Random(seed)
    BAG = [E[0], E[1], E[2], CL[2], E[3]]
    for r in range(rows):
        y = H_ - 8 - r * (bh - 1)
        off = (bw // 2) * (r % 2)
        n = n_cols - (r % 2) - (1 if r == rows - 1 else 0)
        for i in range(n):
            x = 8 + off + i * bw + rnd.randint(-1, 1) + (bw // 2 if r == rows - 1 else 0)
            m = m_poly(cv, blob_poly(x + bw / 2, y, bw / 2 + 1, bh / 2 + 0.5, rnd.randint(0, 99), n=10, jit=0.06, flat_bottom=False))
            dome(cv, m, BAG, flat=0.42, bias=-0.12, hl=True)
            for k in range(-2, 2):
                if m[min(cv.h - 1, y + k), x + bw // 2 + 3] and m[min(cv.h - 1, y + k), x + bw // 2 + 4]:
                    cv.px(x + bw // 2 + 3, y + k, CL[1]); cv.px(x + bw // 2 + 4, y + k, CL[1])
    blotch(cv, cv.opaque(), [E[0], E[1], E[2], E[3]], 3, 2.0, 0.5)
    out = finish(cv)
    for _ in range(3):
        remove_orphans(out)
    return out


def wall_ruin_big():
    return _L.wall_ruin(150, 124, 7)


def wall_ruin_b():
    """Ruined brick wall with a window gap (building footprint piece)."""
    cv = Cv(200, 140)
    wr = _L.wall_ruin(190, 128, 19)
    paste(cv, wr, 2, 4)
    op = cv.opaque()
    # window hole: dark interior + lit sill + lintel
    cv.rect(70, 46, 108, 86, A[0])
    cv.rect(70, 46, 108, 47, A[1])
    face(cv, [(68, 87), (110, 87), (110, 91), (68, 91)], CONC[3]); cv.rect(68, 91, 110, 91, CONC[1])
    face(cv, [(66, 40), (112, 40), (112, 45), (66, 45)], CONC[2]); cv.rect(66, 40, 112, 40, CONC[3])
    cv.a[:, :, 3] = np.where(op, cv.a[:, :, 3], 0)
    return finish(cv)


def ruin_pillar_big():
    rnd = random.Random(4)
    cv = Cv(56, 158)
    w, d = 34, 10
    tops = [16, 14, 13, 12, 10, 8, 7, 6, 6, 7, 8, 10, 13, 15, 17, 19, 20, 22, 24, 25, 26, 27, 26, 25, 27, 29, 32, 34, 36, 37, 38, 39, 40, 41]
    for i, t in enumerate(tops):
        x = 8 + i
        for y in range(t, t + d):
            cv.px(x, y, CONC[3] if y < t + 3 else CONC[2])
        for y in range(t + d, 146):
            cv.px(x, y, CONC[3] if i < 4 else (CONC[2] if i < 27 else CONC[1]))
    box(cv, 4, 136, 42, 12, 5, CONC)
    region = cv.opaque()
    blotch(cv, region, [A[0], A[1], A[1], A[2]], 6, 2.0, 0.45)
    for y in range(40, 136, 16):
        for x in range(9, 41):
            if cv.get(x, y) and rnd.random() < 0.85:
                cv.px(x, y, CONC[1])
    for k in range(3):
        x = 12 + k * 9
        for j in range(12):
            cv.px(x + j // 4, tops[x - 8] - j, RU[1] if j % 2 else RU[2])
    return finish(cv)


def fence_big():
    """Chain-link fence run (hero height+), one panel torn open, ~240 x 120."""
    W, H_ = 246, 126
    cv = Cv(W, H_)
    posts = [(8, 8), (66, 6), (126, 14), (186, 6), (238, 18)]
    for i, (x, top) in enumerate(posts):
        lean = 0 if i != 2 else 1
        for y in range(top, 118):
            xx = x + (lean * (118 - y)) // 6
            cv.px(xx, y, ST[3]); cv.px(xx + 1, y, ST[2]); cv.px(xx + 2, y, ST[1]); cv.px(xx + 3, y, ST[1])
        cv.rect(x - 1, 114, x + 4, 118, CONC[2]); cv.rect(x - 1, 114, x + 4, 114, CONC[3])
    for x in range(8, 130):
        y = 10 + (x - 8) // 40
        cv.px(x, y, ST[2]); cv.px(x, y + 1, ST[1])
    for x in range(186, 240):
        y = 9 + (x - 186) // 6
        cv.px(x, y, ST[2]); cv.px(x, y + 1, ST[1])
    blotch(cv, cv.opaque(), RU, 6, 0.9, 0.3)
    out = finish(cv, selout=False)
    big = Cv(out.w, out.h)
    big.a = out.a.copy()
    m = np.zeros((out.h, out.w), bool)
    m[12:114, 10:128] = True
    m[12:114, 190:238] = True
    torn = m_poly(Cv(out.w, out.h), [(128, 12), (190, 10), (178, 50), (150, 114), (128, 114)])
    for y, x in zip(*np.nonzero(m & ~torn)):
        if ((x + y) % 5 == 0 or (x - y) % 5 == 0) and not big.get(x, y):
            big.px(x, y, A[2] if y < 64 else A[1])
    # barbed wire on top
    for x in range(8, 238):
        y = 4 + int(2 * math.sin(x * 0.21))
        if not big.get(x, y):
            big.px(x, y, A[2])
        if x % 6 == 0:
            big.px(x, y - 1, A[3]); big.px(x + 1, y + 1, A[1])
    # torn flap curling down + a hazard plate on the lit post
    for i in range(18):
        for j in range(10 + i // 2):
            x, y = 132 + j + i, 86 + i // 2 + j // 3
            if (x + y) % 5 == 0 and not big.get(x, y):
                big.px(x, y, A[2])
    hazard(big, 30, 52, 20, 10, BR, period=3)
    return big


def buried_wreck_big():
    """Car standing nose-down in a dune, seen from the rear (hand-cleaned):
    rounded roof, rear screen, boot, tail lights, bumper, wheels at the sides."""
    W, H_ = 206, 168
    cv = Cv(W, H_)
    P = [RU[0], RU[1], RU[2], RU[3]]
    sk = lambda y: int(round((126 - y) * 0.08))    # slight lean to the right toward the top
    def band(y0, y1, x0, x1, c, inset=0.0):
        for y in range(y0, y1 + 1):
            t = (y - y0) / max(1, y1 - y0)
            cv.rect(x0 + sk(y) + int(inset * (1 - t)), y, x1 + sk(y) - int(inset * (1 - t)), y, c)
    # shaded right flank (depth) behind the rear face
    for y in range(14, 126):
        cv.rect(158 + sk(y), y, 166 + sk(y), y, P[0] if y < 58 else P[1])
    # roof cap (faded, lit), rear screen, boot lid, rear panel
    band(10, 30, 52, 158, A[2], inset=10)
    cv.rect(62 + sk(10), 10, 150 + sk(10), 11, A[3])
    band(31, 58, 46, 160, ST[0], inset=4)
    for k in range(20):
        cv.px(60 + sk(34 + k) + k * 2, 34 + k, ST[2]); cv.px(61 + sk(34 + k) + k * 2, 34 + k, ST[1])
    band(59, 84, 42, 162, P[2])
    cv.rect(42 + sk(59), 59, 162 + sk(59), 59, P[3])
    band(85, 116, 40, 164, P[1])
    seam_h(cv, 42, 168, 84)
    # tail lights (dead, rust-red glass), plate, keyhole
    for x0 in (46, 140):
        cv.rect(x0 + sk(92), 90, x0 + 18 + sk(92), 100, RU[3]); cv.rect(x0 + sk(92), 90, x0 + 18 + sk(92), 90, D[1])
        cv.rect(x0 + sk(92), 101, x0 + 18 + sk(92), 101, RU[0])
    cv.rect(90 + sk(100), 96, 114 + sk(100), 108, ST[2]); cv.rect(90 + sk(100), 96, 114 + sk(100), 96, ST[3])
    cv.rect(91 + sk(100), 108, 114 + sk(100), 108, ST[1])
    # bumper
    band(117, 126, 34, 168, ST[1])
    cv.rect(34 + sk(117), 117, 168 + sk(117), 117, ST[3])
    # wheels peeking out at both sides (lit left one, shaded right one)
    big_wheel(cv, 32, 108, 15)
    big_wheel(cv, 178, 104, 14)
    body = mask_of(cv, P)
    rust(cv, body, 17, 0.12, 2.2)
    dents(cv, mask_of(cv, [P[2]]), 17, 4, (5, 9))
    holes(cv, body, 5, 4, big=True)
    # dune: rounded mound swallowing the nose, dome-lit with wind ripples
    yy, xx = cv.grid()
    crest = 126 - 9 * np.exp(-((xx - 100) / 60.0) ** 2) + 2 * np.sin(xx / 13.0)
    dune = (yy >= crest) & (yy < H_ - 2) & (xx >= 2) & (xx < W - 2)
    dune &= ((xx - W / 2) / (W / 2 - 2)) ** 2 + ((yy - (H_ - 2)) / 48.0) ** 2 <= 1.0
    cv.a[dune] = 0
    dome(cv, dune, [E[0], E[1], E[2], E[2]], flat=0.35, hl=False, ao=False)
    lip = dune & ~np.roll(dune, 2, 0)
    cv.fill(lip, E[3])
    for k in range(3):
        y0 = 138 + k * 8
        for x in range(10, W - 10):
            y = int(y0 + 3 * math.sin(x / 11.0 + k))
            if dune[min(H_ - 1, y), x] and dune[min(H_ - 1, y + 1), x]:
                cv.px(x, y, E[1]); cv.px(x, y + 1, E[3] if x < W // 2 else E[2])
    return finish(cv)


def wreck_pile_big():
    """Crushed cars stacked at a scrapyard: flattened hulls, skewed top one."""
    W, H_ = 236, 160
    cv = Cv(W, H_)
    lo = [E[0], E[1], E[2], E[3]]
    # bottom car (flattened): deck + side
    face(cv, [(8, 92), (222, 88), (228, 104), (6, 108)], lo[3])
    face(cv, [(6, 108), (228, 104), (228, 136), (6, 140)], lo[2])
    face(cv, [(6, 128), (228, 124), (228, 136), (6, 140)], lo[1])
    for (x0, x1) in ((40, 90), (100, 150)):
        face(cv, [(x0, 110), (x1, 109), (x1, 120), (x0, 121)], ST[0])
    for x in (36, 96, 156):
        seam_v(cv, x, 108, 136)
    # middle car: steel, crushed and offset
    face(cv, [(30, 56), (200, 48), (206, 62), (26, 72)], ST[3])
    face(cv, [(26, 72), (206, 62), (208, 90), (24, 98)], ST[2])
    face(cv, [(24, 88), (208, 80), (208, 90), (24, 98)], ST[1])
    for (x0, x1) in ((60, 110), (120, 170)):
        face(cv, [(x0, 72), (x1, 69), (x1, 78), (x0, 81)], ST[0])
    # top car: rust red, skewed
    face(cv, [(54, 22), (170, 8), (182, 22), (60, 40)], RU[2])
    face(cv, [(60, 40), (182, 22), (188, 44), (62, 62)], RU[1])
    face(cv, [(84, 38), (150, 28), (152, 38), (86, 48)], ST[0])
    cv.fill(m_line(cv, (54, 22), (170, 8), 1), RU[3])
    body = cv.opaque()
    rust(cv, body, 33, 0.05, 2.4)
    dents(cv, body, 33, 14, (5, 10))
    holes(cv, body, 9, 10, big=True)
    streaks(cv, body, None, 3, 0)
    big_wheel(cv, 40, 140, 13, bare=True)
    big_wheel(cv, 196, 138, 13, flat=True)
    return finish(cv)


def bunker_big(open_=False):
    """Earth-bermed concrete bunker, sandbag crown, steps down to a blast door."""
    W, H_ = 344, 190
    cv = Cv(W, H_)
    # berm: piled earth with a cloth/grass crust and stones
    berm = m_poly(cv, [(4, 182), (34, 110), (70, 60), (130, 34), (220, 32), (282, 56), (320, 108), (340, 182)])
    dome(cv, berm, [E[0], E[1], E[2], E[3]], flat=0.3, hl=False)
    blotch(cv, berm, [CL[0], CL[1], CL[1], CL[2]], 2, 2.6, 0.38)
    rnd = random.Random(5)
    for k in range(9):
        x = rnd.randint(30, 310); y = rnd.randint(70, 170)
        if berm[y, x]:
            r_ = rock(rnd.randint(8, 14), rnd.randint(6, 9), k + 4, n=4, ramp=[A[0], A[1], A[2], A[3]])
            paste(cv, r_, x, y)
    # sandbag crown on top
    sb = sandbags_big(10, 2, 3)
    paste(cv, sb, 110, 20)
    # concrete face: thick frame, panel joints, vents, hazard header
    face(cv, [(70, 74), (274, 74), (274, 84), (70, 84)], CONC[3])
    face(cv, [(70, 84), (274, 84), (274, 176), (70, 176)], CONC[2])
    cv.rect(70, 84, 71, 176, CONC[3])
    face(cv, [(70, 166), (274, 166), (274, 176), (70, 176)], CONC[1])
    for x in (118, 226):
        seam_v(cv, x, 86, 164)
    seam_h(cv, 72, 272, 128)
    hazard(cv, 76, 90, 192, 7, BR, period=5)
    for vx in (88, 238):
        cv.rect(vx, 108, vx + 20, 118, INK)
        for y in range(109, 118, 3):
            cv.rect(vx + 1, y, vx + 19, y, CONC[1])
        cv.rect(vx, 119, vx + 20, 119, CONC[3])
    blotch(cv, m_rect(cv, 70, 84, 274, 176), [A[0], A[1], A[1], A[2]], 6, 2.4, 0.42)
    streaks(cv, m_rect(cv, 72, 100, 272, 164), [A[0], A[1], A[2], A[3]], 9, 14, 6, 18, -1)
    # door recess
    cv.rect(132, 104, 212, 176, A[0])
    cv.rect(132, 104, 212, 105, A[1])
    if not open_:
        face(cv, [(138, 108), (206, 108), (206, 172), (138, 172)], ST[2])
        cv.rect(138, 108, 206, 108, ST[3]); cv.rect(138, 108, 138, 172, ST[3])
        cv.rect(206, 108, 206, 172, ST[1]); cv.rect(138, 172, 206, 172, ST[1])
        for y in range(118, 168, 12):
            seam_h(cv, 140, 204, y)
        m = m_ellipse(cv, 172, 140, 12, 12)
        for y, x in zip(*np.nonzero(m & ~m_ellipse(cv, 172, 140, 9, 9))):
            cv.px(x, y, BR[3] if y < 139 else BR[1])
        for i in range(-9, 10):
            cv.px(172 + i, 140, BR[2]); cv.px(172, 140 + i, BR[2])
        cv.fill(m_ellipse(cv, 172, 140, 3, 3), BR[1])
        for (x, y) in ((142, 112), (200, 112), (142, 166), (200, 166)):
            rivet(cv, x, y)
        # padlock plate (yellow = locked on the minimap too)
        cv.rect(194, 134, 200, 146, BR[2]); cv.rect(194, 134, 200, 134, BR[3]); cv.rect(196, 140, 198, 142, INK)
    else:
        cv.rect(138, 108, 206, 176, INK)
        for i, y in enumerate(range(150, 177, 6)):     # steps down into the dark
            cv.rect(138 + i * 2, y, 206 - i * 2, y + 1, A[1] if i < 3 else A[2])
        face(cv, [(212, 104), (234, 112), (234, 182), (212, 176)], ST[2], edge_hi=ST[3], edge_lo=ST[1])
        cv.fill(m_ellipse(cv, 223, 142, 4, 10), BR[1])
    rust(cv, mask_of(cv, ST), 13, 0.25, 2.0)
    return finish(cv)


def rock_huge(seed=11):
    """Boulder for crater fields / rock gardens (~0.7x hero)."""
    cv = Cv(110, 82)
    m = m_poly(cv, blob_poly(50, 46, 44, 30, seed, n=11, jit=0.14))
    m2 = m_poly(cv, blob_poly(84, 58, 20, 15, seed + 3, n=8, jit=0.2))
    facets(cv, m, ROCK, seed=seed, n=20, tilt=0.3)
    facets(cv, m2 & ~m, ROCK, seed=seed + 1, n=6, tilt=0.3)
    for y in (40, 52):
        for x in range(10, 92):
            if m[y, x] and (x // 6) % 3 != 2:
                c = cv.get(x, y)
                if c in REV and REV[c][0] == "earth":
                    cv.px(x, y, ROCK[max(1, REV[c][1] - 1)])
    blotch(cv, m | m2, [A[0], A[1], A[2], A[3]], seed, scale=2.2, thresh=0.5)
    return finish(cv)


def tire_stack():
    cv = Cv(48, 56)
    t = tire()
    for k in range(4):
        paste(cv, t, 6 + (k % 2), 36 - k * 11)
    return finish(cv)


def crate_stack():
    cv = Cv(84, 72)
    a = crate_wood(36, 22, 10, 1)
    b = crate_wood(32, 20, 9, 2)
    c = crate_wood(30, 18, 9, 3)
    for cr in (a, b, c):
        remove_orphans(cr); outline(cr, False)
    paste(cv, a, 2, 36); paste(cv, b, 40, 40); paste(cv, c, 16, 6)
    return finish(cv)


def drum_pair():
    """Two upright drums (0.4x hero) + one rolled over."""
    cv = Cv(80, 60)
    a = drum(RU, True, 26, 40, 1)
    b = drum(ST, False, 24, 38, 4)
    paste(cv, b, 30, 0)
    paste(cv, a, 4, 8)
    lie = Cv(40, 22)
    cyl_h(lie, 3, 34, 10, 9, RU, cap_left=True)
    blotch(lie, lie.opaque(), [RU[0], RU[1], RU[1], RU[2]], 9, 1.2, 0.45)
    remove_orphans(lie); outline(lie, False)
    paste(cv, lie, 38, 36)
    return finish(cv)


def chem_vat_big():
    import vat
    return crop(_Z._wrap(_rs(vat.make_vat, 1.5)(3, 150, 162)))
