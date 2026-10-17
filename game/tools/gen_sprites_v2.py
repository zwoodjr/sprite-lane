#!/usr/bin/env python3
"""Wanderer art pass 2 (original pixel art, matches gen_sprites.py style).

Run from game/:  python3 tools/gen_sprites_v2.py
Adds: softer ground tiles, varied decor, charger + brute enemies.
"""
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("wrote", rel)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + ((c[3],) if len(c) == 4 else (255,))


# ---------------------------------------------------------------- ground
def ground(seed, base, kind):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (64, 64), base + (255,))
    d = ImageDraw.Draw(img)
    # soft grain: tiny low-contrast specks
    for _ in range(140):
        x, y = rnd.randrange(64), rnd.randrange(64)
        k = rnd.choice([0.93, 0.96, 1.04, 1.07])
        d.point((x, y), fill=shade(base, k))
    if kind == "pebbles":
        for _ in range(7):
            x, y = rnd.randrange(2, 60), rnd.randrange(2, 60)
            r = rnd.choice([1, 1, 2])
            d.ellipse([x, y, x + r * 2, y + r], fill=shade(base, 0.78))
            d.point((x, y), fill=shade(base, 1.18))
    elif kind == "cracks":
        for _ in range(2):
            x, y = rnd.randrange(64), rnd.randrange(64)
            for _ in range(10):
                nx = max(0, min(63, x + rnd.randint(-4, 4)))
                ny = max(0, min(63, y + rnd.randint(-4, 4)))
                d.line([x, y, nx, ny], fill=shade(base, 0.8), width=1)
                x, y = nx, ny
    elif kind == "ripples":
        for row in range(6, 64, 11):
            off = rnd.randint(0, 8)
            for x in range(0, 64, 2):
                yy = row + int(2 * ((x + off) % 16 > 8))
                d.point((x, yy % 64), fill=shade(base, 1.08))
    return img


BASE = (124, 92, 62)
kinds = ["plain", "pebbles", "plain", "cracks", "ripples", "plain"]
for i, k in enumerate(kinds):
    save(ground(i * 31 + 5, BASE, k), f"tiles/ground_{i}.png")


# ---------------------------------------------------------------- decor
def shadow(d, cx, cy, w, h, a=80):
    d.ellipse([cx - w, cy - h, cx + w, cy + h], fill=(30, 20, 12, a))


def rock(seed, size):
    rnd = random.Random(seed)
    w = h = size
    img = new(w, h)
    d = ImageDraw.Draw(img)
    shadow(d, w // 2, int(h * 0.78), int(w * 0.42), int(h * 0.14))
    pts = []
    for i in range(8):
        import math
        a = i / 8 * 6.283
        r = size * 0.36 * rnd.uniform(0.75, 1.0)
        pts.append((w / 2 + math.cos(a) * r, h * 0.55 + math.sin(a) * r * 0.7))
    d.polygon(pts, fill=(104, 92, 82, 255))
    top = [(x, y - 2) for x, y in pts if y < h * 0.55]
    if len(top) >= 3:
        d.polygon(top, fill=(134, 120, 106, 255))
    d.line([(w * 0.35, h * 0.45), (w * 0.45, h * 0.6)], fill=(80, 70, 62, 255))
    return img


def dead_bush():
    img = new(32, 32)
    d = ImageDraw.Draw(img)
    shadow(d, 16, 27, 10, 3)
    for ang, ln in [(-60, 12), (-100, 14), (-130, 11), (-80, 9), (-30, 9), (-150, 8)]:
        import math
        a = math.radians(ang)
        x2 = 16 + math.cos(a) * ln
        y2 = 26 + math.sin(a) * ln
        d.line([(16, 26), (x2, y2)], fill=(98, 72, 48, 255), width=1)
        d.line([(x2, y2), (x2 + 2, y2 - 2)], fill=(116, 86, 58, 255))
    return img


def bones():
    img = new(32, 20)
    d = ImageDraw.Draw(img)
    shadow(d, 16, 15, 12, 3, 60)
    d.line([(5, 12), (25, 8)], fill=(222, 210, 186, 255), width=2)
    for x, y in [(4, 11), (4, 13), (26, 7), (26, 9)]:
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=(232, 222, 200, 255))
    d.ellipse([18, 11, 25, 17], fill=(226, 214, 190, 255))
    d.point((20, 14), fill=(60, 45, 35, 255))
    d.point((23, 14), fill=(60, 45, 35, 255))
    return img


def tire():
    img = new(28, 22)
    d = ImageDraw.Draw(img)
    shadow(d, 14, 17, 12, 4)
    d.ellipse([3, 4, 25, 18], fill=(42, 38, 36, 255))
    d.ellipse([9, 8, 19, 14], fill=(110, 82, 56, 255))
    d.arc([3, 4, 25, 18], 200, 320, fill=(72, 66, 62, 255))
    return img


def cactus():
    img = new(28, 40)
    d = ImageDraw.Draw(img)
    shadow(d, 14, 36, 9, 3)
    green = (92, 120, 70, 255)
    dark = (70, 94, 54, 255)
    d.rounded_rectangle([11, 6, 17, 36], 3, fill=green)
    d.rounded_rectangle([4, 14, 9, 26], 2, fill=green)
    d.rectangle([6, 24, 12, 27], fill=green)
    d.rounded_rectangle([19, 10, 24, 22], 2, fill=green)
    d.rectangle([16, 19, 22, 22], fill=green)
    d.line([(13, 8), (13, 34)], fill=dark)
    d.point((15, 4), fill=(220, 120, 90, 255))
    return img


def sign_post():
    img = new(26, 40)
    d = ImageDraw.Draw(img)
    shadow(d, 13, 36, 7, 2)
    d.rectangle([12, 10, 14, 36], fill=(86, 62, 42, 255))
    d.polygon([(3, 8), (21, 6), (23, 12), (5, 15)], fill=(150, 112, 70, 255))
    d.line([(7, 10), (17, 9)], fill=(90, 50, 35, 255))
    return img


save(rock(1, 30), "props/rock_small.png")
save(rock(7, 46), "props/rock_large.png")
save(dead_bush(), "props/dead_bush.png")
save(bones(), "props/bones.png")
save(tire(), "props/tire.png")
save(cactus(), "props/cactus.png")
save(sign_post(), "props/sign_post.png")


# ---------------------------------------------------------------- enemies
def charger():
    img = new(40, 40)
    d = ImageDraw.Draw(img)
    shadow(d, 20, 35, 11, 3)
    d.rectangle([15, 28, 18, 34], fill=(50, 34, 24, 255))
    d.rectangle([22, 28, 25, 34], fill=(50, 34, 24, 255))
    d.polygon([(13, 16), (27, 16), (25, 29), (15, 29)], fill=(196, 112, 52, 255))
    d.line([(14, 22), (26, 22)], fill=(150, 80, 40, 255))
    d.ellipse([14, 5, 26, 17], fill=(170, 128, 100, 255))
    d.rectangle([14, 9, 26, 12], fill=(40, 36, 34, 255))       # goggle band
    d.rectangle([16, 9, 19, 12], fill=(250, 210, 90, 255))     # lens
    d.rectangle([21, 9, 24, 12], fill=(250, 210, 90, 255))
    d.polygon([(27, 18), (37, 13), (38, 15), (28, 21)], fill=(200, 200, 205, 255))  # blade
    d.line([(27, 18), (37, 13)], fill=(255, 255, 255, 255))
    return img


def brute():
    img = new(56, 56)
    d = ImageDraw.Draw(img)
    shadow(d, 28, 50, 17, 4, 100)
    d.rectangle([17, 40, 24, 49], fill=(44, 40, 44, 255))
    d.rectangle([32, 40, 39, 49], fill=(44, 40, 44, 255))
    d.rounded_rectangle([12, 18, 44, 42], 5, fill=(92, 104, 128, 255))   # armor
    d.rounded_rectangle([14, 20, 42, 28], 3, fill=(118, 132, 158, 255))
    for x in (18, 28, 38):
        d.point((x, 24), fill=(60, 60, 70, 255))                         # rivets
    d.rounded_rectangle([7, 18, 15, 30], 3, fill=(80, 90, 112, 255))      # pauldrons
    d.rounded_rectangle([41, 18, 49, 30], 3, fill=(80, 90, 112, 255))
    d.rounded_rectangle([20, 4, 36, 19], 4, fill=(70, 76, 92, 255))       # helm
    d.rectangle([22, 10, 34, 13], fill=(230, 80, 60, 255))                # visor glow
    d.rectangle([40, 30, 55, 35], fill=(40, 38, 38, 255))                 # shotgun
    d.rectangle([52, 29, 55, 36], fill=(70, 66, 62, 255))
    return img


save(charger(), "enemies/charger.png")
save(brute(), "enemies/brute.png")
