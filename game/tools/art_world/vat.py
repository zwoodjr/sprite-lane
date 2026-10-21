"""Chem vat repaint (Choke zone prop) to the bible: 1 texel density, steel/brass/rust/plague ramps,
light top-left, 4 tones per material, coloured outline with selout, no baked ground shadow."""
import numpy as np, random, math
from pal import R, INK
from px import canvas, put, outline, remove_orphans, ellipse_mask, to_img, LIGHT

ST, BR, RU, PL, ASH = R("steel"), R("brass"), R("rust"), R("plague"), R("ash")


def cyl_tone(dx, extra=0.0):
    """Vertical cylinder shading, light top-left. Returns index into a 4-tone ramp (0..3)."""
    nz = math.sqrt(max(0.0, 1 - dx * dx))
    i = -0.62 * dx + 0.55 * nz + extra  # simplified n.L (y term is 0 on the side wall)
    if dx > 0.86:
        return 1  # reflected light on the far rim
    if i > 0.80:
        return 3
    if i > 0.38:
        return 2
    if i > -0.05:
        return 1
    return 0


def make_vat(seed=3, W=100, H=108):
    rnd = random.Random(seed)
    a = canvas(W, H)
    cx, rx, ry = 44.0, 35.0, 12.0
    yt, yb = 22.0, 86.0

    def front(dx):
        return ry * math.sqrt(max(0.0, 1 - dx * dx))

    # concrete plinth
    for y in range(H):
        for x in range(W):
            dx = (x + 0.5 - cx) / (rx + 5)
            if abs(dx) <= 1:
                f = (ry + 3) * math.sqrt(1 - dx * dx)
                top = yb + 1 - f
                bot = yb + 1 + f
                if top <= y + 0.5 <= bot:
                    a[y, x, :3] = ASH[3] if (dx < -0.2 and y + 0.5 < yb + 1 - f * 0.2) else ASH[2]
                    a[y, x, 3] = 255
                elif bot < y + 0.5 <= bot + 3:
                    a[y, x, :3] = ASH[1] if dx < 0.3 else ASH[0]
                    a[y, x, 3] = 255
    # body
    for y in range(H):
        for x in range(W):
            dx = (x + 0.5 - cx) / rx
            if abs(dx) > 1:
                continue
            f = front(dx)
            if yt + f - 0.5 <= y + 0.5 <= yb + f:
                v = (y + 0.5 - (yt + f)) / (yb - yt)
                t = cyl_tone(dx, extra=0.22 * (0.45 - v))
                if y + 0.5 > yb + f - 3:  # AO where it meets the plinth
                    t = max(0, t - 1)
                a[y, x, :3] = ST[t]
                a[y, x, 3] = 255
    # hoops (brass), relative to the front curve
    for off in (10, 47):
        for x in range(W):
            dx = (x + 0.5 - cx) / rx
            if abs(dx) > 1:
                continue
            f = front(dx)
            y0 = int(round(yt + f + off))
            t = cyl_tone(dx)
            cols = [BR[3] if t == 3 else (BR[2] if t == 2 else BR[1]), BR[2] if t >= 2 else BR[1], BR[0]]
            for k, c in enumerate(cols):
                put(a, x, y0 + k, c)
            # rivets every 6 px on the middle row
            if x % 6 == 2 and abs(dx) < 0.92:
                put(a, x, y0 + 1, BR[3] if t >= 2 else BR[2])
                put(a, x, y0 + 2, BR[0])
                # rust streak under some rivets
                if rnd.random() < 0.3:
                    L = rnd.randint(3, 9)
                    for k in range(L):
                        yy = y0 + 3 + k
                        if a[yy, x, 3] and tuple(a[yy, x, :3]) in [tuple(c) for c in ST]:
                            put(a, x, yy, RU[2] if k == 0 and t >= 2 else RU[1])
    # rust bloom near the base: clustered noise (no single pixels)
    for x in range(W):
        dx = (x + 0.5 - cx) / rx
        if abs(dx) > 0.97:
            continue
        f = front(dx)
        base = yb + f - 3
        h = 3 + 4 * (0.5 + 0.5 * math.sin(x * 0.45 + 1.3)) * (0.6 + 0.4 * math.sin(x * 0.13))
        for k in range(int(h)):
            y = int(base - k)
            if a[y, x, 3] and tuple(a[y, x, :3]) in [tuple(c) for c in ST]:
                t = cyl_tone(dx)
                put(a, x, y, RU[2] if (t >= 2 and k < h - 2) else RU[1])
    # hazard plate (brass + ink stripes) on the lit side
    px0, py0, pw, ph = 26, 0, 22, 11
    for j in range(ph):
        for i in range(pw):
            x = px0 + i
            dx = (x + 0.5 - cx) / rx
            y = int(round(yt + front(dx) + 20 + j))
            if i in (0, pw - 1) or j in (0, ph - 1):
                c = ST[0]
            else:
                c = BR[2] if ((i + j) // 3) % 2 == 0 else INK
                if j == 1 and c != INK:
                    c = BR[3]
            put(a, x, y, c)
    stl = [tuple(c) for c in ST]
    def is_steel(x, y):
        return 0 <= y < H and 0 <= x < W and a[y, x, 3] and tuple(a[y, x, :3]) in stl
    # grime: vertical darker streak clusters (2 px wide) on lit areas
    for gx in (14, 22, 40, 47, 70):
        dx = (gx + 0.5 - cx) / rx
        y0 = int(yt + front(dx) + rnd.randint(14, 30))
        L = rnd.randint(8, 18)
        for k in range(L):
            for w in range(2 if k < L - 3 else 1):
                x = gx + w
                if is_steel(x, y0 + k):
                    t = [tuple(c) for c in ST].index(tuple(a[y0 + k, x, :3]))
                    put(a, x, y0 + k, ST[max(1, t - 1)])
    # welded patch plate (jury-rigged) on the shadow side
    pxs, pys, pw, ph = 58, 0, 14, 16
    for j in range(ph):
        for i in range(pw):
            x = pxs + i
            dx = (x + 0.5 - cx) / rx
            y = int(round(yt + front(dx) + 24 + j))
            t = cyl_tone(dx)
            edge = i in (0, pw - 1) or j in (0, ph - 1)
            if edge:
                c = RU[2] if (j == 0 or i == 0) else RU[0]
            else:
                c = RU[1] if t <= 1 else RU[2]
                if (i * 7 + j * 3) % 11 == 0:
                    c = ST[1]
            put(a, x, y, c)
            if edge and (i in (1, pw - 2)) and (j in (0, ph - 1)):
                put(a, x, y, BR[2])
    # bullet holes; one leaks plague
    for (hx, hoff, leak) in ((20, 34, True), (36, 52, False), (66, 50, False)):
        dx = (hx + 0.5 - cx) / rx
        hy = int(round(yt + front(dx) + hoff))
        put(a, hx, hy, INK); put(a, hx + 1, hy, INK); put(a, hx, hy + 1, INK); put(a, hx + 1, hy + 1, ST[0])
        put(a, hx - 1, hy, ST[1]); put(a, hx, hy - 1, ST[1])
        put(a, hx + 2, hy + 1, ST[3]); put(a, hx + 1, hy + 2, ST[3])
        if leak:
            for k in range(2, 13):
                put(a, hx, hy + k, PL[3] if k < 9 else PL[2])
                if k > 3:
                    put(a, hx + 1, hy + k, PL[2] if k < 11 else PL[1])
            put(a, hx, hy + 13, PL[1]); put(a, hx + 1, hy + 13, PL[1])
    # edge wear: highlight nicks just below the upper hoop on the lit side, scratches, a dent
    for (x, y, L) in ((12, 52, 4), (18, 66, 3), (27, 44, 5), (43, 70, 3), (50, 40, 4)):
        for k in range(L):
            if is_steel(x + k, y - k // 2):
                t = stl.index(tuple(a[y - k // 2, x + k, :3]))
                put(a, x + k, y - k // 2, ST[min(3, t + 1)])
    for (x, y) in ((8, 46), (9, 46), (15, 38), (24, 37), (25, 37), (33, 39)):
        if is_steel(x, y):
            put(a, x, y, ST[3])
    dxc, dyc = 30, 76  # dent: shadow top-left, light bottom-right
    for (ddx, ddy, c) in ((-2, -1, ST[1]), (-1, -2, ST[1]), (0, -2, ST[1]), (-2, 0, ST[1]), (-1, -1, ST[1]),
                          (2, 1, ST[3]), (1, 2, ST[3]), (0, 2, ST[3]), (2, 0, ST[3])):
        if is_steel(dxc + ddx, dyc + ddy):
            put(a, dxc + ddx, dyc + ddy, c)
    # weld bead around the patch
    for j in range(-1, 17):
        for i in (57, 72):
            dx = (i + 0.5 - cx) / rx
            y = int(round(yt + front(dx) + 24 + j))
            if (j % 2) == 0:
                put(a, i, y, ASH[3] if i == 57 else ASH[2])
    # top rim + interior + liquid
    for y in range(H):
        for x in range(W):
            ox = (x + 0.5 - cx) / rx
            oy = (y + 0.5 - yt) / ry
            r_out = ox * ox + oy * oy
            ix = (x + 0.5 - cx) / (rx - 3)
            iy = (y + 0.5 - yt) / (ry - 2.5)
            r_in = ix * ix + iy * iy
            if r_out <= 1 and r_in > 1:
                ang = math.atan2(oy, ox)  # rim: lit on the back-left (faces up/left)
                lit = -math.cos(ang) * 0.6 - math.sin(ang) * 0.8
                c = ST[3] if lit > 0.45 else (ST[2] if lit > -0.35 else ST[1])
                a[y, x, :3] = c
                a[y, x, 3] = 255
            elif r_in <= 1:
                # interior: back wall dark, liquid surface lower
                lx = (x + 0.5 - cx) / (rx - 4)
                ly = (y + 0.5 - (yt + 3.5)) / (ry - 3.5)
                if lx * lx + ly * ly <= 1:
                    d = math.sqrt(lx * lx + ly * ly)
                    # wall shadow falls on the upper-left of the liquid
                    sh = (lx * -0.6 + ly * -0.8)
                    if sh > 0.62:
                        c = PL[1]
                    elif d > 0.86 and ly > 0.2:
                        c = PL[4] if (x % 3) else PL[3]
                    elif d > 0.82:
                        c = PL[2]
                    elif d > 0.45:
                        c = PL[3] if (lx + ly * 0.5) > -0.35 else PL[2]
                        if abs(math.sin(lx * 7 + ly * 3)) < 0.18 and d > 0.55:
                            c = PL[2]
                    else:
                        c = PL[3]
                    a[y, x, :3] = c
                else:
                    a[y, x, :3] = ST[0] if iy < 0 else ST[1]
                a[y, x, 3] = 255
    # glints + bubbles on the liquid
    for (bx, by, r) in ((50, 24, 2), (38, 27, 1), (58, 21, 1)):
        for ang in range(0, 360, 30):
            put(a, int(round(bx + r * math.cos(math.radians(ang)))), int(round(by + r * 0.7 * math.sin(math.radians(ang)))), PL[4])
    for i in range(6):
        put(a, 44 + i, 18, PL[4])
    for i in range(3):
        put(a, 47 + i, 17, PL[4])
    # drips over the front lip
    for (x, L) in ((30, 12), (31, 12), (52, 7), (53, 7), (61, 15), (62, 15)):
        dx = (x + 0.5 - cx) / rx
        y0 = int(round(yt + front(dx)))
        left = (x in (30, 52, 61))
        for k in range(L):
            put(a, x, y0 + k, PL[3] if left else PL[2])
        if left:
            for (ddx, ddy, c) in ((-1, L - 1, PL[3]), (-1, L, PL[2]), (0, L, PL[3]), (1, L, PL[2]), (2, L, PL[1]),
                                  (-1, L + 1, PL[1]), (0, L + 1, PL[2]), (1, L + 1, PL[1]), (0, L + 2, PL[1]), (2, L - 1, PL[1])):
                put(a, x + ddx, y0 + ddy, c)
    # pipe out of the right side + valve
    py = 52
    for x in range(int(cx + rx - 3), int(cx + rx + 10)):
        for k, c in enumerate([ST[3], ST[2], ST[2], ST[1], ST[1]]):
            put(a, x, py + k, c)
    for y in range(py, int(yb + 6)):
        for k, c in enumerate([ST[2], ST[2], ST[1], ST[1], ST[0]]):
            put(a, int(cx + rx + 6) + k, y, c)
    for k, c in enumerate([ST[3], ST[2], ST[2], ST[1], ST[1]]):  # elbow highlight
        put(a, int(cx + rx + 6) + k, py, c)
    for j in range(-1, 6):  # brass flange at the wall
        put(a, int(cx + rx - 2), py + j, BR[2] if j < 3 else BR[1])
        put(a, int(cx + rx - 1), py + j, BR[1] if j < 3 else BR[0])
    vx, vy = int(cx + rx + 8), 70
    for ang in range(0, 360, 15):
        t = math.radians(ang)
        x = int(round(vx + 5 * math.cos(t)))
        y = int(round(vy + 3.2 * math.sin(t)))
        put(a, x, y, RU[3] if (math.cos(t) < 0.2 and math.sin(t) < 0.3) else RU[2])
    for i in range(-4, 5):
        put(a, vx + i, vy, RU[1])
    for j in range(-2, 3):
        put(a, vx, vy + j, RU[1])
    put(a, vx, vy, BR[3])
    a = remove_orphans(a)
    a = outline(a, selout=True)
    return a


if __name__ == "__main__":
    import sys
    a = make_vat()
    img = to_img(a)
    img.save(sys.argv[1] if len(sys.argv) > 1 else "/tmp/vat.png")
    from px import count_colors
    print(img.size, img.getbbox(), count_colors(a))
