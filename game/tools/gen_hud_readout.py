"""In-match health / XP readout art (the locked "smashed readout" style):
a near-black dented, rusted, chewed-edge housing with a recessed LCD screen,
a broken corner with exposed wires and a bullet hole; plus a glass overlay
(cracks, grime, scratches) that sits on top of the cells. The segmented
cells, scanlines, glow, label and live number are drawn at runtime by
scripts/ui/readout_bar.gd so the bar follows HP.

usage (from game/):  python3 tools/gen_hud_readout.py
writes assets/sprites/ui/readout_{hp,xp}_{housing,glass}.png (520x76)
Screen geometry (art units, shared with readout_bar.gd): screen 22,20 -> 498,56;
cells from x=92 to x=398.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites", "ui")
S = 3
UW, UH = 520, 76
W, H = UW * S, UH * S
SCREEN = (22, 20, 498, 56)


def setup(seed):
    global rng
    rng = np.random.default_rng(seed)
    random.seed(seed)


def noise(blur=0):
    im = Image.fromarray((rng.random((H, W)) * 255).astype(np.uint8))
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def thresh(im, t):
    return im.point(lambda v: 255 if v > t else 0)


def jag_poly(box, amp=3, step=6, bite=0):
    x0, y0, x1, y1 = box
    pts = []

    def edge(ax, ay, bx, by):
        n = max(2, int(math.hypot(bx - ax, by - ay) / (step * S)))
        for i in range(n):
            t = i / n
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t
            j = random.uniform(-amp, amp) * S
            if bite and random.random() < 0.06:
                j -= random.uniform(2, bite) * S
            nx, ny = (by - ay), -(bx - ax)
            L = math.hypot(nx, ny) or 1
            pts.append((x + nx / L * j, y + ny / L * j))
    edge(x0, y0, x1, y0)
    edge(x1, y0, x1, y1)
    edge(x1, y1, x0, y1)
    edge(x0, y1, x0, y0)
    return pts


def mask_poly(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def layer(color):
    return Image.new("RGBA", (W, H), color + (255,))


def put(base, lay, mask, a=255):
    l = lay.copy()
    l.putalpha(ImageChops.multiply(mask, Image.new("L", (W, H), a)) if a != 255 else mask)
    return Image.alpha_composite(base, l)


def vgrad(top, bot):
    a = np.linspace(0, 1, H)[:, None, None]
    c = np.array(top)[None, None] * (1 - a) + np.array(bot)[None, None] * a
    return Image.fromarray(np.repeat(c, W, 1).astype(np.uint8), "RGB").convert("RGBA")


def rust(base, mask, amount):
    n1 = np.array(noise(5 * S)).astype(float) / 255
    n2 = np.array(noise(1)).astype(float) / 255
    v = np.clip((n1 - (1 - amount * .55)) * 6 + (n2 - .5) * .35, 0, 1)
    col = np.dstack([95 + 55 * n2, 45 + 28 * n2, 22 + 12 * n2, v * 215]).astype(np.uint8)
    r = Image.fromarray(col, "RGBA")
    r.putalpha(ImageChops.multiply(r.split()[3], mask))
    base = Image.alpha_composite(base, r)
    pit = thresh(noise(0.6 * S), 238)
    pit = ImageChops.multiply(pit, Image.fromarray((v * 255).astype(np.uint8)))
    return put(base, layer((35, 18, 8)), ImageChops.multiply(pit, mask), 200)


def grime(base, mask, a=170, col=(28, 20, 12), blur=6):
    n = noise(blur * S).point(lambda v: max(0, v - 115) * 3)
    n = ImageChops.multiply(n, mask).point(lambda v: int(v * a / 255))
    l = layer(col)
    l.putalpha(n)
    return Image.alpha_composite(base, l)


def edge_wear(base, mask, a=170):
    e = mask.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(S * .5))
    n = thresh(noise(2 * S), 128)
    e = ImageChops.multiply(e, n).point(lambda v: int(min(255, v * 2) * a / 255))
    l = layer((205, 188, 155))
    l.putalpha(e)
    return Image.alpha_composite(base, l)


def dent(base, cx, cy, r):
    d = Image.new("L", (W, H), 0)
    ImageDraw.Draw(d).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d = d.filter(ImageFilter.GaussianBlur(r / 3))
    sh = layer((0, 0, 0))
    sh.putalpha(d.point(lambda v: int(v * .45)))
    base = Image.alpha_composite(base, sh)
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).arc((cx - r, cy - r, cx + r, cy + r), 200, 340, fill=255, width=max(2, int(r / 5)))
    hl = hl.filter(ImageFilter.GaussianBlur(r / 6))
    l = layer((230, 215, 190))
    l.putalpha(hl.point(lambda v: int(v * .5)))
    return Image.alpha_composite(base, l)


def bullet_hole(base, cx, cy, r):
    d = ImageDraw.Draw(base)
    pts = []
    for i in range(14):
        a = i / 14 * math.tau
        rr = r * random.uniform(1.0, 1.9)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=(170, 160, 140, 255))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(12, 8, 6, 255))
    d.arc((cx - r, cy - r, cx + r, cy + r), 200, 330, fill=(80, 70, 60, 255), width=S)
    return base


def scratches(base, n=25, a=80):
    d = ImageDraw.Draw(base)
    for _ in range(n):
        x = random.uniform(0, W)
        y = random.uniform(0, H)
        L = random.uniform(10, 60) * S
        g = random.uniform(-.6, .6)
        d.line((x, y, x + L * math.cos(g), y + L * math.sin(g)), fill=(225, 205, 175, a), width=max(1, S // 2))
    return base


def cracks(base, x, y, n=5, length=40, col=(235, 235, 225, 170)):
    d = ImageDraw.Draw(base)
    for _ in range(n):
        a = random.uniform(0, math.tau)
        px, py = x, y
        for k in range(random.randint(3, 6)):
            a += random.uniform(-.6, .6)
            L = random.uniform(.3, 1) * length / 4 * S
            nx, ny = px + math.cos(a) * L, py + math.sin(a) * L
            d.line((px, py, nx, ny), fill=col, width=S)
            px, py = nx, ny
    return base


def housing(seed, crack_x):
    """Housing + screen recess (no cells, no text) and the glass overlay."""
    setup(seed)
    im = Image.new("RGBA", (W, H))
    hm = mask_poly(jag_poly((6 * S, 8 * S, W - 6 * S, H - 8 * S), 1.5, 9, 5))
    im = put(im, vgrad((42, 38, 34), (16, 14, 13)), hm)
    im = rust(im, hm, .55)
    im = dent(im, 60 * S, 14 * S, 6 * S)
    scr = tuple(v * S for v in SCREEN)
    sm = mask_poly(jag_poly(scr, .8, 14))
    im = put(im, layer((12, 7, 3)), sm)
    # broken corner exposing wires
    d = ImageDraw.Draw(im)
    d.polygon([(W - 60 * S, H - 8 * S), (W - 6 * S, H - 8 * S), (W - 6 * S, H - 30 * S)], fill=(0, 0, 0, 0))
    for k, c in enumerate([(200, 40, 30), (40, 120, 200), (230, 200, 60)]):
        d.line((W - 40 * S + k * 6 * S, H - 14 * S, W - 30 * S + k * 8 * S, H - 2 * S), fill=c + (255,), width=2 * S)
    im = grime(im, hm, 230, (10, 8, 6), 5)
    im = bullet_hole(im, 14 * S, 14 * S, 3 * S)
    im = edge_wear(im, hm)
    im = scratches(im, 25)
    # glass overlay: cracks + grime on the screen only
    glass = Image.new("RGBA", (W, H))
    glass = cracks(glass, crack_x * S, H * .5, 9, 100)
    glass = grime(glass, sm, 120, (40, 30, 15), 3)
    return im, glass


def save(im, name):
    im.resize((UW, UH), Image.LANCZOS).save(os.path.join(OUT, name))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    h, g = housing(11, 208)
    save(h, "readout_hp_housing.png")
    save(g, "readout_hp_glass.png")
    h2, g2 = housing(23, 330)
    save(h2, "readout_xp_housing.png")
    save(g2, "readout_xp_glass.png")
    print("ok")
