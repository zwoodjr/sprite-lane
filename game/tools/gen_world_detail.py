#!/usr/bin/env python3
"""Deep Dust Apothecary world art pass — tiles, walls, props, extract pads.

Art-only writer (PNG under assets/sprites/{tiles,props}). Matches wasteland
sheet density: thick outlines, rivets, grit, rust, vial accents — not flat blobs.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"
STORE = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/world")
ARTIFACTS = Path("/opt/cursor/artifacts/assets")

INK = (18, 14, 12, 255)
DUST = (124, 92, 62, 255)
DUST_LT = (152, 118, 82, 255)
DUST_DK = (86, 64, 44, 255)
RUST = (156, 72, 42, 255)
RUST_DK = (110, 48, 30, 255)
SCRAP = (96, 92, 88, 255)
SCRAP_LT = (138, 134, 126, 255)
SCRAP_DK = (48, 44, 42, 255)
VIAL = (64, 176, 128, 255)
VIAL_LT = (140, 230, 180, 255)
VIAL_DK = (36, 110, 80, 255)
AMBER = (232, 176, 64, 255)
AMBER_LT = (255, 220, 120, 255)
AMBER_DK = (180, 120, 36, 255)
BONE = (228, 214, 186, 255)


def shade(c, k: float):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)


def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", rel, img.size)


def px(p, x, y, c, w, h):
    if 0 <= x < w and 0 <= y < h:
        p[x, y] = c


def fill_rect(p, x0, y0, x1, y1, c, w, h):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(p, x, y, c, w, h)


def fill_ellipse(p, x0, y0, x1, y1, c, w, h):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = max(0.5, (x1 - x0) / 2), max(0.5, (y1 - y0) / 2)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.05:
                px(p, x, y, c, w, h)


def add_outline(img: Image.Image, color=INK, thickness: int = 2) -> Image.Image:
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    opaque = [[src[x, y][3] > 20 for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if opaque[y][x]:
                continue
            near = False
            for dy in range(-thickness, thickness + 1):
                for dx in range(-thickness, thickness + 1):
                    if dx * dx + dy * dy > thickness * thickness + 1:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and opaque[ny][nx]:
                        near = True
                        break
                if near:
                    break
            if near:
                dst[x, y] = color
    return out


def drop_shadow(img: Image.Image, cx: int, cy: int, rw: int, rh: int, a: int = 70) -> None:
    d = ImageDraw.Draw(img)
    d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=(20, 14, 10, a))


# ---------------------------------------------------------------------------
# Ground — dense wasteland tiling
# ---------------------------------------------------------------------------

def ground_tile(seed: int, kind: str) -> Image.Image:
    rnd = random.Random(seed)
    base = DUST[:3]
    img = Image.new("RGBA", (64, 64), base + (255,))
    d = ImageDraw.Draw(img)
    p = img.load()

    # Layered dust plates with hard bevels (sheet density)
    for _ in range(7):
        x0, y0 = rnd.randrange(0, 50), rnd.randrange(0, 50)
        bw, bh = rnd.randint(8, 20), rnd.randint(6, 16)
        k = rnd.choice([0.82, 0.88, 0.94, 1.04, 1.10, 1.14])
        col = shade(base + (255,), k)
        d.rectangle([x0, y0, x0 + bw, y0 + bh], fill=col)
        d.rectangle([x0, y0, x0 + bw, y0 + 1], fill=shade(col, 1.15))
        d.rectangle([x0, y0 + bh - 1, x0 + bw, y0 + bh], fill=shade(col, 0.78))
        if rnd.random() < 0.4:
            d.rectangle([x0, y0, x0, y0 + bh], fill=shade(col, 0.85))

    # Scrap grit bricks + rust flecks
    for _ in range(18):
        x, y = rnd.randrange(1, 61), rnd.randrange(1, 61)
        c = rnd.choice([DUST_DK, SCRAP_DK, shade(DUST + (255,), 0.75), (140, 100, 58, 255), RUST_DK])
        bw, bh = rnd.randint(1, 4), rnd.randint(1, 3)
        d.rectangle([x, y, x + bw, y + bh], fill=c)

    # Tire track / seam lines
    if rnd.random() < 0.75:
        y = rnd.randrange(16, 48)
        for x in range(2, 62, 2):
            yy = y + (1 if (x // 2 + seed) % 5 == 0 else 0)
            d.rectangle([x, yy % 64, x + 1, (yy % 64) + 1], fill=shade(base + (255,), 0.72))
            d.rectangle([x, (yy + 5) % 64, x + 1, (yy + 5) % 64 + 1], fill=shade(base + (255,), 0.72))

    if kind == "pebbles":
        for _ in range(9):
            x, y = rnd.randrange(3, 54), rnd.randrange(3, 54)
            r = rnd.choice([2, 3, 3, 4])
            rock = shade(SCRAP + (255,), rnd.uniform(0.7, 1.0))
            d.ellipse([x, y, x + r * 2, y + r], fill=rock)
            d.ellipse([x + 1, y, x + r, y + max(1, r - 1)], fill=shade(rock, 1.2))
            px(p, x, y + r // 2, INK, 64, 64)
            px(p, x + r * 2 - 1, y + r // 2, INK, 64, 64)
    elif kind == "cracks":
        for _ in range(4):
            x, y = rnd.randrange(6, 56), rnd.randrange(6, 56)
            for _step in range(12):
                nx = max(2, min(61, x + rnd.randint(-6, 6)))
                ny = max(2, min(61, y + rnd.randint(-6, 6)))
                d.line([x, y, nx, ny], fill=shade(base + (255,), 0.55), width=2)
                if rnd.random() < 0.3:
                    px(p, x, y, RUST, 64, 64)
                if rnd.random() < 0.15:
                    px(p, x + 1, y, SCRAP_DK, 64, 64)
                x, y = nx, ny
    elif kind == "ripples":
        for row in range(6, 60, 10):
            off = rnd.randint(0, 8)
            for x in range(2, 62, 2):
                yy = (row + int(2 * (((x + off) % 14) > 7))) % 64
                col = shade(base + (255,), 1.12 if (x // 2) % 2 == 0 else 0.88)
                d.rectangle([x, yy, x + 1, yy + 1], fill=col)
                if rnd.random() < 0.08:
                    px(p, x, yy, AMBER_DK, 64, 64)
    elif kind == "vial_glint":
        for _ in range(4):
            x, y = rnd.randrange(6, 50), rnd.randrange(6, 50)
            d.rectangle([x - 1, y - 1, x + 4, y + 3], fill=SCRAP_DK)
            d.rectangle([x, y, x + 3, y + 2], fill=VIAL_DK)
            d.rectangle([x + 1, y, x + 2, y + 1], fill=VIAL)
            px(p, x + 1, y, VIAL_LT, 64, 64)
    elif kind == "scrap_grit":
        for _ in range(6):
            x, y = rnd.randrange(4, 52), rnd.randrange(4, 52)
            d.rectangle([x, y, x + 5, y + 3], fill=SCRAP)
            d.rectangle([x, y, x + 5, y + 1], fill=SCRAP_LT)
            d.rectangle([x, y + 2, x + 5, y + 3], fill=SCRAP_DK)
            px(p, x + 1, y + 1, RUST, 64, 64)
            px(p, x + 4, y + 1, RUST_DK, 64, 64)
    else:  # plain — still dense
        for _ in range(3):
            x, y = rnd.randrange(8, 50), rnd.randrange(8, 50)
            d.rectangle([x, y, x + 3, y + 2], fill=shade(base + (255,), 0.7))
            if rnd.random() < 0.5:
                px(p, x, y, RUST, 64, 64)

    # Corner plate anchors
    for cx, cy in ((0, 0), (60, 0), (0, 60), (60, 60)):
        d.rectangle([cx, cy, cx + 3, cy + 3], fill=shade(base + (255,), 0.86))
        px(p, cx + 1, cy + 1, SCRAP_DK, 64, 64)

    return img


# ---------------------------------------------------------------------------
# Walls / barriers
# ---------------------------------------------------------------------------

def make_wall_ruin() -> Image.Image:
    img = new(72, 48)
    p = img.load()
    w, h = 72, 48
    drop_shadow(img, 36, 42, 28, 5, 75)
    # adobe / scrap wall body
    fill_rect(p, 4, 10, 67, 40, DUST_DK, w, h)
    fill_rect(p, 4, 10, 67, 16, DUST_LT, w, h)
    fill_rect(p, 4, 34, 67, 40, shade(DUST_DK, 0.75), w, h)
    # broken top silhouette
    for x, top in ((8, 6), (18, 4), (28, 8), (40, 3), (52, 7), (62, 5)):
        fill_rect(p, x, top, x + 6, 12, DUST, w, h)
        fill_rect(p, x, top, x + 6, top + 2, DUST_LT, w, h)
    # rebar
    fill_rect(p, 22, 2, 24, 14, SCRAP, w, h)
    fill_rect(p, 48, 1, 50, 12, SCRAP_LT, w, h)
    # rivet plate patch
    fill_rect(p, 30, 18, 50, 32, SCRAP, w, h)
    fill_rect(p, 30, 18, 50, 21, SCRAP_LT, w, h)
    for rx, ry in ((32, 20), (46, 20), (32, 28), (46, 28)):
        px(p, rx, ry, AMBER_DK, w, h)
    # rust streaks + vial stain
    fill_rect(p, 12, 20, 16, 38, RUST, w, h)
    fill_rect(p, 54, 22, 58, 36, RUST_DK, w, h)
    fill_ellipse(p, 38, 24, 46, 34, VIAL_DK, w, h)
    px(p, 40, 26, VIAL, w, h)
    return add_outline(img, thickness=2)


def make_barrier_scrap() -> Image.Image:
    img = new(56, 40)
    p = img.load()
    w, h = 56, 40
    drop_shadow(img, 28, 34, 20, 4, 70)
    # angled scrap fence
    d = ImageDraw.Draw(img)
    d.polygon([(4, 30), (12, 8), (44, 6), (52, 28), (40, 34), (10, 34)], fill=SCRAP_DK)
    fill_rect(p, 10, 12, 46, 30, SCRAP, w, h)
    fill_rect(p, 10, 12, 46, 16, SCRAP_LT, w, h)
    for x in range(14, 44, 6):
        fill_rect(p, x, 10, x + 2, 32, SCRAP_DK, w, h)
    fill_rect(p, 20, 4, 24, 14, RUST, w, h)
    fill_rect(p, 34, 3, 38, 14, RUST_DK, w, h)
    px(p, 28, 18, VIAL, w, h)
    px(p, 29, 19, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_ruin_pillar() -> Image.Image:
    img = new(36, 64)
    p = img.load()
    w, h = 36, 64
    drop_shadow(img, 18, 58, 12, 4, 70)
    fill_rect(p, 8, 8, 27, 58, SCRAP, w, h)
    fill_rect(p, 8, 8, 27, 14, SCRAP_LT, w, h)
    fill_rect(p, 8, 50, 27, 58, SCRAP_DK, w, h)
    for y in range(16, 48, 7):
        fill_rect(p, 8, y, 27, y + 1, SCRAP_DK, w, h)
        px(p, 12, y + 2, RUST, w, h)
        px(p, 22, y + 2, RUST_DK, w, h)
    # broken crown
    fill_rect(p, 6, 2, 14, 10, DUST, w, h)
    fill_rect(p, 20, 4, 30, 12, DUST_DK, w, h)
    fill_rect(p, 14, 0, 22, 6, AMBER_DK, w, h)
    fill_ellipse(p, 14, 18, 22, 28, VIAL_DK, w, h)
    px(p, 16, 20, VIAL, w, h)
    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Props — clearer silhouettes
# ---------------------------------------------------------------------------

def make_herb_crate() -> Image.Image:
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 14, 4, 80)
    fill_rect(p, 6, 16, 41, 42, (118, 78, 42, 255), w, h)
    fill_rect(p, 6, 16, 41, 22, (168, 118, 68, 255), w, h)
    fill_rect(p, 6, 36, 41, 42, (78, 50, 28, 255), w, h)
    for x in (14, 24, 34):
        fill_rect(p, x, 17, x, 41, (70, 46, 24, 255), w, h)
    for y in (26, 32):
        fill_rect(p, 6, y, 41, y, (70, 46, 24, 255), w, h)
    for nx, ny in ((9, 18), (36, 18), (9, 38), (36, 38)):
        px(p, nx, ny, SCRAP, w, h)
    px(p, 8, 40, RUST, w, h)
    px(p, 38, 40, RUST, w, h)
    # tall vial stack silhouette
    fill_rect(p, 16, 2, 31, 18, VIAL_DK, w, h)
    fill_rect(p, 17, 3, 30, 16, VIAL, w, h)
    fill_rect(p, 18, 4, 24, 12, VIAL_LT, w, h)
    fill_rect(p, 17, 0, 30, 3, SCRAP, w, h)
    fill_rect(p, 20, 0, 27, 2, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_vial_crate() -> Image.Image:
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 15, 4, 80)
    fill_rect(p, 5, 18, 42, 42, SCRAP, w, h)
    fill_rect(p, 5, 18, 42, 24, SCRAP_LT, w, h)
    fill_rect(p, 5, 36, 42, 42, SCRAP_DK, w, h)
    for i, col in enumerate([VIAL, AMBER, (90, 140, 210, 255)]):
        x = 9 + i * 11
        fill_rect(p, x, 4, x + 8, 22, shade(col, 0.55), w, h)
        fill_rect(p, x + 1, 5, x + 7, 20, col, w, h)
        fill_rect(p, x + 2, 6, x + 4, 12, shade(col, 1.35), w, h)
        fill_rect(p, x + 1, 2, x + 7, 5, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_apothecary_chest() -> Image.Image:
    img = new(56, 40)
    p = img.load()
    w, h = 56, 40
    drop_shadow(img, 28, 36, 18, 4, 80)
    fill_rect(p, 4, 12, 51, 36, (96, 58, 36, 255), w, h)
    fill_rect(p, 4, 12, 51, 18, (148, 92, 56, 255), w, h)
    fill_rect(p, 4, 30, 51, 36, (70, 42, 26, 255), w, h)
    fill_rect(p, 4, 20, 51, 21, (50, 30, 18, 255), w, h)
    fill_rect(p, 22, 18, 34, 28, AMBER_DK, w, h)
    fill_rect(p, 24, 19, 32, 26, AMBER, w, h)
    px(p, 27, 21, AMBER_LT, w, h)
    fill_rect(p, 38, 2, 50, 16, VIAL_DK, w, h)
    fill_rect(p, 39, 3, 49, 14, VIAL, w, h)
    px(p, 41, 5, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_scrap_drum() -> Image.Image:
    img = new(44, 52)
    p = img.load()
    w, h = 44, 52
    drop_shadow(img, 22, 48, 14, 4, 80)
    fill_rect(p, 8, 12, 35, 46, RUST, w, h)
    fill_rect(p, 8, 12, 35, 18, shade(RUST, 1.25), w, h)
    fill_rect(p, 8, 40, 35, 46, RUST_DK, w, h)
    for y in (22, 30, 36):
        fill_rect(p, 8, y, 35, y + 1, RUST_DK, w, h)
    for y in (24, 32):
        px(p, 12, y, SCRAP_LT, w, h)
        px(p, 30, y, SCRAP_DK, w, h)
    fill_rect(p, 14, 2, 29, 14, VIAL_DK, w, h)
    fill_rect(p, 15, 3, 28, 12, VIAL, w, h)
    px(p, 17, 5, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_scrap_pile() -> Image.Image:
    img = new(56, 36)
    p = img.load()
    w, h = 56, 36
    drop_shadow(img, 28, 32, 20, 4, 75)
    fill_ellipse(p, 4, 14, 52, 34, (70, 48, 34, 255), w, h)
    fill_rect(p, 10, 8, 26, 20, SCRAP, w, h)
    fill_rect(p, 10, 8, 26, 12, SCRAP_LT, w, h)
    fill_rect(p, 26, 6, 44, 18, RUST, w, h)
    fill_rect(p, 26, 6, 44, 10, shade(RUST, 1.2), w, h)
    fill_ellipse(p, 20, 2, 34, 14, VIAL_DK, w, h)
    fill_ellipse(p, 22, 3, 32, 12, VIAL, w, h)
    px(p, 24, 5, VIAL_LT, w, h)
    px(p, 14, 16, AMBER_DK, w, h)
    return add_outline(img, thickness=2)


def make_wreck() -> Image.Image:
    img = new(80, 52)
    p = img.load()
    w, h = 80, 52
    drop_shadow(img, 40, 46, 28, 5, 85)
    d = ImageDraw.Draw(img)
    d.polygon([(6, 36), (18, 12), (58, 10), (74, 34), (60, 42), (12, 44)], fill=RUST_DK)
    fill_rect(p, 10, 28, 68, 42, RUST, w, h)
    fill_rect(p, 10, 28, 68, 32, shade(RUST, 1.25), w, h)
    fill_rect(p, 24, 14, 50, 28, (40, 48, 54, 255), w, h)
    fill_rect(p, 26, 16, 36, 24, (70, 95, 105, 220), w, h)
    fill_rect(p, 40, 16, 48, 24, (50, 70, 80, 200), w, h)
    fill_ellipse(p, 14, 32, 28, 46, SCRAP_DK, w, h)
    fill_ellipse(p, 54, 30, 70, 46, SCRAP_DK, w, h)
    fill_ellipse(p, 17, 35, 25, 43, SCRAP, w, h)
    fill_ellipse(p, 57, 33, 67, 43, SCRAP, w, h)
    fill_rect(p, 34, 4, 44, 16, VIAL_DK, w, h)
    fill_rect(p, 35, 5, 43, 14, VIAL, w, h)
    px(p, 37, 7, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_tower() -> Image.Image:
    img = new(44, 80)
    p = img.load()
    w, h = 44, 80
    drop_shadow(img, 22, 74, 12, 4, 75)
    fill_rect(p, 12, 24, 31, 74, SCRAP, w, h)
    fill_rect(p, 12, 24, 31, 32, SCRAP_LT, w, h)
    fill_rect(p, 12, 64, 31, 74, SCRAP_DK, w, h)
    for y in range(34, 62, 6):
        fill_rect(p, 12, y, 31, y, SCRAP_DK, w, h)
        px(p, 16, y + 2, RUST, w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(6, 28), (22, 2), (36, 28)], fill=RUST)
    fill_rect(p, 16, 8, 28, 18, AMBER, w, h)
    fill_rect(p, 17, 9, 27, 16, AMBER_LT, w, h)
    fill_rect(p, 18, 0, 26, 8, VIAL, w, h)
    px(p, 20, 2, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_rock(seed: int, size: int) -> Image.Image:
    rnd = random.Random(seed)
    img = new(size, size)
    d = ImageDraw.Draw(img)
    p = img.load()
    drop_shadow(img, size // 2, int(size * 0.8), int(size * 0.4), int(size * 0.12), 70)
    pts = []
    for i in range(9):
        a = i / 9 * 6.283
        r = size * 0.36 * rnd.uniform(0.72, 1.05)
        pts.append((size / 2 + math.cos(a) * r, size * 0.55 + math.sin(a) * r * 0.72))
    d.polygon(pts, fill=(104, 92, 82, 255))
    top = [(x, y - 3) for x, y in pts if y < size * 0.55]
    if len(top) >= 3:
        d.polygon(top, fill=(142, 126, 110, 255))
    for _ in range(4):
        x = rnd.randint(size // 4, size * 3 // 4)
        y = rnd.randint(size // 3, size * 2 // 3)
        d.rectangle([x, y, x + 2, y + 1], fill=(78, 68, 60, 255))
    if rnd.random() < 0.7:
        px(p, size // 2, size // 2 + 2, RUST, size, size)
    return add_outline(img, thickness=2)


def make_dead_bush() -> Image.Image:
    img = new(36, 36)
    d = ImageDraw.Draw(img)
    drop_shadow(img, 18, 30, 11, 3, 60)
    for ang, ln in [(-55, 14), (-95, 16), (-130, 12), (-75, 10), (-25, 11), (-155, 9), (-110, 8)]:
        a = math.radians(ang)
        x2 = 18 + math.cos(a) * ln
        y2 = 28 + math.sin(a) * ln
        d.line([(18, 28), (x2, y2)], fill=(98, 72, 48, 255), width=2)
        d.line([(x2, y2), (x2 + 2, y2 - 3)], fill=(120, 88, 58, 255), width=1)
    return add_outline(img, thickness=1)


def make_bones() -> Image.Image:
    img = new(36, 22)
    p = img.load()
    w, h = 36, 22
    drop_shadow(img, 18, 17, 13, 3, 55)
    d = ImageDraw.Draw(img)
    d.line([(5, 13), (28, 8)], fill=BONE, width=3)
    fill_ellipse(p, 3, 11, 8, 16, BONE, w, h)
    fill_ellipse(p, 26, 6, 32, 12, BONE, w, h)
    fill_ellipse(p, 18, 12, 30, 20, BONE, w, h)
    px(p, 22, 15, SCRAP_DK, w, h)
    px(p, 25, 15, SCRAP_DK, w, h)
    return add_outline(img, thickness=1)


def make_tire() -> Image.Image:
    img = new(32, 24)
    p = img.load()
    w, h = 32, 24
    drop_shadow(img, 16, 19, 12, 3, 60)
    fill_ellipse(p, 2, 3, 28, 20, SCRAP_DK, w, h)
    fill_ellipse(p, 9, 8, 21, 16, DUST, w, h)
    fill_ellipse(p, 11, 9, 19, 15, DUST_LT, w, h)
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        px(p, int(15 + math.cos(rad) * 10), int(11 + math.sin(rad) * 6), SCRAP, w, h)
    return add_outline(img, thickness=2)


def make_cactus() -> Image.Image:
    img = new(32, 44)
    p = img.load()
    w, h = 32, 44
    drop_shadow(img, 16, 40, 10, 3, 60)
    green, dark, lt = (92, 120, 70, 255), (70, 94, 54, 255), (120, 148, 90, 255)
    fill_rect(p, 12, 6, 20, 39, green, w, h)
    fill_rect(p, 12, 6, 20, 12, lt, w, h)
    fill_rect(p, 14, 8, 15, 37, dark, w, h)
    fill_rect(p, 4, 14, 11, 28, green, w, h)
    fill_rect(p, 21, 10, 28, 24, green, w, h)
    px(p, 16, 4, (220, 120, 90, 255), w, h)
    return add_outline(img, thickness=2)


def make_sign() -> Image.Image:
    img = new(30, 44)
    p = img.load()
    w, h = 30, 44
    drop_shadow(img, 15, 40, 8, 2, 55)
    fill_rect(p, 13, 12, 17, 40, (86, 62, 42, 255), w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(2, 10), (24, 6), (27, 16), (4, 20)], fill=(150, 112, 70, 255))
    fill_rect(p, 7, 10, 20, 12, (90, 50, 35, 255), w, h)
    px(p, 10, 13, RUST, w, h)
    px(p, 16, 12, RUST, w, h)
    return add_outline(img, thickness=1)


# ---------------------------------------------------------------------------
# Extract pads — procedural fallback + AI plate ingest
# ---------------------------------------------------------------------------

def make_pad(open_state: bool) -> Image.Image:
    img = new(96, 96)
    p = img.load()
    w, h = 96, 96
    ring = AMBER if open_state else (100, 88, 76, 255)
    ring_lt = AMBER_LT if open_state else (130, 118, 105, 255)
    ring_dk = AMBER_DK if open_state else (70, 62, 54, 255)
    # solid dust plate under ring
    fill_ellipse(p, 10, 10, 85, 85, DUST_DK if open_state else (48, 42, 36, 255), w, h)
    fill_ellipse(p, 18, 18, 77, 77, DUST if open_state else (56, 50, 44, 255), w, h)
    # rivet ring plate
    for ang in range(0, 360, 12):
        rad = math.radians(ang)
        x = int(48 + math.cos(rad) * 32)
        y = int(48 + math.sin(rad) * 32)
        px(p, x, y, SCRAP_LT if open_state else SCRAP_DK, w, h)
    # chunky outer ring
    for ang in range(0, 360, 1):
        rad = math.radians(ang)
        for r in range(33, 41):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            if r >= 39:
                col = ring_dk
            elif r in (35, 36) and open_state:
                col = ring_lt
            else:
                col = ring
            px(p, x, y, col, w, h)
    # inner glyph ring
    for ang in range(0, 360, 2):
        rad = math.radians(ang)
        for r in (18, 19, 20):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            px(p, x, y, ring_lt if open_state else SCRAP, w, h)
    # beacon
    fill_rect(p, 43, 14, 52, 52, SCRAP_DK, w, h)
    fill_rect(p, 43, 14, 52, 20, SCRAP, w, h)
    fill_rect(p, 44, 22, 51, 50, SCRAP, w, h)
    if open_state:
        fill_ellipse(p, 36, 2, 59, 22, AMBER, w, h)
        fill_ellipse(p, 40, 6, 55, 18, AMBER_LT, w, h)
        fill_ellipse(p, 44, 9, 51, 15, (255, 250, 210, 255), w, h)
        for dx, dy in ((-12, 0), (12, 0), (0, -10), (-8, -7), (8, -7)):
            px(p, 48 + dx, 10 + dy, AMBER_LT, w, h)
    else:
        fill_ellipse(p, 38, 4, 57, 20, SCRAP, w, h)
        fill_ellipse(p, 42, 8, 53, 16, SCRAP_DK, w, h)
    # vial consoles — large for FOV
    for bx in (16, 70):
        fill_rect(p, bx, 50, bx + 12, 68, SCRAP_DK, w, h)
        fill_rect(p, bx + 1, 51, bx + 11, 66, VIAL_DK if open_state else SCRAP, w, h)
        if open_state:
            fill_rect(p, bx + 2, 52, bx + 7, 60, VIAL, w, h)
            fill_rect(p, bx + 3, 53, bx + 5, 58, VIAL_LT, w, h)
        fill_rect(p, bx + 2, 48, bx + 10, 51, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def knock_white(im: Image.Image, thr: int = 240) -> Image.Image:
    im = im.convert("RGBA")
    pxls = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = pxls[x, y]
            if a < 8:
                continue
            if r >= thr and g >= thr and b >= thr:
                pxls[x, y] = (255, 255, 255, 0)
            elif min(r, g, b) >= thr - 12 and max(r, g, b) - min(r, g, b) < 14:
                pxls[x, y] = (255, 255, 255, 0)
    return im


def ingest_sheet(name: str, out_rel: str, size: tuple[int, int]) -> bool:
    src = ARTIFACTS / name
    if not src.exists():
        alt = ARTIFACTS / name.replace(".jpg", ".png")
        src = alt if alt.exists() else src
    if not src.exists():
        return False
    im = knock_white(Image.open(src))
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    tw, th = size
    sc = min((tw - 2) / im.width, (th - 2) / im.height)
    nw, nh = max(1, int(im.width * sc)), max(1, int(im.height * sc))
    mid = im.resize((nw * 2, nh * 2), Image.Resampling.BOX)
    small = mid.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(small, ((tw - nw) // 2, (th - nh) // 2), small)
    canvas = add_outline(canvas, thickness=2)
    save(canvas, out_rel)
    return True


# ---------------------------------------------------------------------------
# Previews
# ---------------------------------------------------------------------------

def font(sz=14):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", sz)
    except Exception:
        return ImageFont.load_default()


def magnify(im: Image.Image, s: int) -> Image.Image:
    return im.resize((im.width * s, im.height * s), Image.Resampling.NEAREST)


def write_previews() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    # Ground detail sheet
    kinds = ["plain", "pebbles", "scrap_grit", "cracks", "ripples", "vial_glint"]
    tiles = [Image.open(OUT / "tiles" / f"ground_{i}.png").convert("RGBA") for i in range(6)]
    cell = 64 * 3
    sheet = Image.new("RGB", (cell * 3 + 40, cell * 2 + 56), (28, 24, 22))
    d = ImageDraw.Draw(sheet)
    d.text((12, 10), "ground detail — dust / grit / cracks / vial", fill=(220, 200, 160), font=font())
    for i, t in enumerate(tiles):
        big = magnify(t, 3)
        x = 12 + (i % 3) * (cell + 6)
        y = 36 + (i // 3) * (cell + 6)
        sheet.paste(big.convert("RGB"), (x, y))
        d.text((x, y + cell - 4), kinds[i], fill=(180, 160, 130), font=font(11))
    sheet.save(STORE / "ground_detail_sheet.png", optimize=True)

    # Walls sheet
    walls = ["wall_ruin", "barrier_scrap", "ruin_pillar"]
    wsheet = Image.new("RGB", (560, 280), (28, 24, 22))
    d = ImageDraw.Draw(wsheet)
    d.text((12, 10), "walls / barriers / ruins", fill=(220, 200, 160), font=font())
    for i, name in enumerate(walls):
        im = Image.open(OUT / "props" / f"{name}.png").convert("RGBA")
        sc = min(140 / im.width, 160 / im.height)
        show = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.Resampling.NEAREST)
        tile = Image.new("RGB", (160, 180), (255, 255, 255))
        tile.paste(show, ((160 - show.width) // 2, (180 - show.height) // 2), show)
        x = 16 + i * 180
        wsheet.paste(tile, (x, 40))
        d.text((x, 230), name, fill=(200, 180, 140), font=font(12))
    wsheet.save(STORE / "walls_detail_sheet.png", optimize=True)

    # Props sheet
    names = [
        "herb_crate", "vial_crate", "apothecary_chest", "scrap_drum",
        "scrap_pile", "wreck", "signal_tower", "rock_large",
        "wall_ruin", "barrier_scrap", "extract_open", "extract_sealed",
    ]
    cols = 4
    cellp = 150
    rows = (len(names) + cols - 1) // cols
    prop_sheet = Image.new("RGB", (cols * cellp + 24, rows * cellp + 44), (28, 24, 22))
    d = ImageDraw.Draw(prop_sheet)
    d.text((12, 8), "world props + extract (detail pass)", fill=(220, 200, 160), font=font())
    for i, name in enumerate(names):
        im = Image.open(OUT / "props" / f"{name}.png").convert("RGBA")
        sc = min(110 / im.width, 110 / im.height)
        show = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.Resampling.NEAREST)
        tile = Image.new("RGB", (cellp - 16, cellp - 32), (255, 255, 255))
        tile.paste(show, ((tile.width - show.width) // 2, (tile.height - show.height) // 2), show)
        x = 12 + (i % cols) * cellp
        y = 32 + (i // cols) * cellp
        prop_sheet.paste(tile, (x, y))
        d.text((x, y + cellp - 36), name, fill=(200, 180, 140), font=font(11))
    prop_sheet.save(STORE / "props_detail_sheet.png", optimize=True)

    # Extract before/after if before exists
    for state in ("open", "sealed"):
        before = STORE / f"extract_{state}_before.png"
        after = OUT / "props" / f"extract_{state}.png"
        if not before.exists() and (STORE / "extract_open_before.png").exists() and state == "open":
            before = STORE / "extract_open_before.png"
        a = Image.open(after).convert("RGBA")
        magnify(a, 3).save(STORE / f"extract_{state}_3x.png")
        if before.exists():
            b = Image.open(before).convert("RGBA")
            bb, aa = magnify(b, 3), magnify(a, 3)
            board = Image.new("RGB", (bb.width + aa.width + 48, max(bb.height, aa.height) + 48), (28, 24, 22))
            d = ImageDraw.Draw(board)
            d.text((12, 8), f"extract_{state} before", fill=(220, 160, 140), font=font())
            d.text((bb.width + 36, 8), f"extract_{state} after", fill=(160, 220, 160), font=font())
            board.paste(Image.new("RGB", bb.size, (255, 255, 255)), (12, 32))
            board.paste(bb, (12, 32), bb)
            board.paste(Image.new("RGB", aa.size, (255, 255, 255)), (bb.width + 36, 32))
            board.paste(aa, (bb.width + 36, 32), aa)
            board.save(STORE / f"extract_{state}_before_after.png", optimize=True)

    # Ground before/after
    before = STORE / "ground_0_before.png"
    after = OUT / "tiles" / "ground_0.png"
    if before.exists():
        b, a = magnify(Image.open(before).convert("RGBA"), 4), magnify(Image.open(after).convert("RGBA"), 4)
        board = Image.new("RGB", (b.width * 2 + 48, b.height + 48), (28, 24, 22))
        d = ImageDraw.Draw(board)
        d.text((12, 8), "ground_0 before", fill=(220, 160, 140), font=font())
        d.text((b.width + 36, 8), "ground_0 after (detail)", fill=(160, 220, 160), font=font())
        board.paste(b.convert("RGB"), (12, 32))
        board.paste(a.convert("RGB"), (b.width + 36, 32))
        board.save(STORE / "ground_before_after.png", optimize=True)

    print("previews →", STORE)


def main() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    # Snapshot before for extract sealed if missing
    for name in ("extract_open", "extract_sealed", "herb_crate", "wreck"):
        src = OUT / "props" / f"{name}.png"
        dst = STORE / f"{name}_before.png"
        if src.exists() and not dst.exists():
            Image.open(src).save(dst)

    kinds = ["plain", "pebbles", "scrap_grit", "cracks", "ripples", "vial_glint"]
    for i, k in enumerate(kinds):
        save(ground_tile(i * 97 + 11, k), f"tiles/ground_{i}.png")
    for i in range(4):
        save(ground_tile(i * 53 + 200, "plain" if i % 2 == 0 else "pebbles"), f"tiles/dust_{i}.png")

    save(make_wall_ruin(), "props/wall_ruin.png")
    save(make_barrier_scrap(), "props/barrier_scrap.png")
    save(make_ruin_pillar(), "props/ruin_pillar.png")
    # Prefer AI wall if present
    ingest_sheet("wall_ruin_sheet.jpg", "props/wall_ruin.png", (72, 48))
    ingest_sheet("wall_ruin_sheet.png", "props/wall_ruin.png", (72, 48))

    save(make_herb_crate(), "props/herb_crate.png")
    save(make_vial_crate(), "props/vial_crate.png")
    save(make_apothecary_chest(), "props/apothecary_chest.png")
    save(make_scrap_drum(), "props/scrap_drum.png")
    save(make_scrap_pile(), "props/scrap_pile.png")
    save(make_wreck(), "props/wreck.png")
    ingest_sheet("wreck_sheet.jpg", "props/wreck.png", (80, 52))
    ingest_sheet("wreck_sheet.png", "props/wreck.png", (80, 52))
    save(make_tower(), "props/signal_tower.png")
    save(make_rock(1, 32), "props/rock_small.png")
    save(make_rock(7, 48), "props/rock_large.png")
    save(make_dead_bush(), "props/dead_bush.png")
    save(make_bones(), "props/bones.png")
    save(make_tire(), "props/tire.png")
    save(make_cactus(), "props/cactus.png")
    save(make_sign(), "props/sign_post.png")

    # Extract: prefer AI sheets, else procedural detail
    if not ingest_sheet("extract_open_sheet.jpg", "props/extract_open.png", (96, 96)):
        if not ingest_sheet("extract_open_sheet.png", "props/extract_open.png", (96, 96)):
            save(make_pad(True), "props/extract_open.png")
    if not ingest_sheet("extract_sealed_sheet.jpg", "props/extract_sealed.png", (96, 96)):
        if not ingest_sheet("extract_sealed_sheet.png", "props/extract_sealed.png", (96, 96)):
            save(make_pad(False), "props/extract_sealed.png")

    write_previews()
    print("DONE world detail →", OUT)


if __name__ == "__main__":
    main()
