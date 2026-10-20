"""Visual tier ground (Oct 2026): native-density floor art.

  * ground_sand.png repainted: wind-smoothed drifts and mottling with shaded
    pebbles — no more ripple contour lines (they read as a wavy artifact when the
    floor scrolls). Zone sets are rebuilt from it (tools/gen_zone_tiles.py).
  * decals/decal_atlas.png repainted at native density (one texel = one screen
    px in the match, ~2x the old pixel size): branching cracks with lit lips,
    dual tyre ruts with tread, glossy oil pools, toxic puddles, shaded pebbles,
    scrap bits, bones, dry grass, dark ground stains. Regions are written to
    scripts/world/decal_atlas.gd.

usage (from game/):  python3 tools/gen_ground_v2.py [--sheet DIR]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_zone_tiles as gzt  # noqa: E402

SPR = os.path.join(HERE, "..", "assets", "sprites")
TILES = os.path.join(SPR, "tiles")
DECALS = os.path.join(SPR, "decals")
ATLAS_GD = os.path.join(HERE, "..", "scripts", "world", "decal_atlas.gd")


def seamless(n, cells, seed):
    return gzt.seamless_noise(n, cells, seed)


# ------------------------------------------------------------------ sand tile
def pebble_layer(n, count, seed, cols, rmin=1.0, rmax=2.6):
    """Seamless scattered pebbles, lit top-left, each with a tiny cast shadow."""
    rr = random.Random(seed)
    big = Image.new("RGBA", (n * 3, n * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for _ in range(count):
        x, y = rr.uniform(n, 2 * n), rr.uniform(n, 2 * n)
        r = rr.uniform(rmin, rmax)
        base = rr.choice(cols)
        for (ox, oy) in ((0, 0), (n, 0), (-n, 0), (0, n), (0, -n), (n, n), (-n, -n), (n, -n), (-n, n)):
            X, Y = x + ox, y + oy
            d.ellipse((X - r + 0.8, Y - r * 0.7 + 1.0, X + r + 0.8, Y + r * 0.7 + 1.0), fill=(20, 14, 10, 110))
            d.ellipse((X - r, Y - r * 0.75, X + r, Y + r * 0.75), fill=tuple(int(c * 0.8) for c in base) + (255,))
            d.ellipse((X - r * 0.7, Y - r * 0.7, X + r * 0.3, Y + r * 0.1), fill=tuple(min(255, int(c * 1.15)) for c in base) + (255,))
    return big.crop((n, n, 2 * n, 2 * n))


def sand_tile(n=512):
    base = np.array([110.0, 92.0, 67.0])
    m1 = seamless(n, 6, 11)
    m2 = seamless(n, 18, 12)
    m3 = seamless(n, 64, 13)
    lum = (m1 - 0.5) * 0.07 + (m2 - 0.5) * 0.06 + (m3 - 0.5) * 0.06
    # soft wind drifts: broad, low-contrast lighter lobes (no lines)
    drift = np.clip((seamless(n, 9, 14) - 0.55) * 3.0, 0, 1) * 0.035
    col = base[None, None] * (1.0 + lum + drift)[..., None]
    warm = np.clip((m2 - 0.5) * 2, -1, 1)[..., None] * np.array([4.0, 1.0, -3.0])[None, None]
    col = col + warm
    a = np.dstack([np.clip(col, 0, 255), np.full((n, n), 255.0)])
    im = Image.fromarray(a.astype(np.uint8), "RGBA")
    peb = pebble_layer(n, 190, 15, [(132, 112, 84), (96, 82, 62), (150, 132, 102), (84, 70, 54)], 0.8, 2.0)
    im = Image.alpha_composite(im, peb)
    # a few tiny dry grass sprigs
    g = Image.new("RGBA", (n * 3, n * 3), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    rr = random.Random(16)
    for _ in range(40):
        x, y = rr.uniform(n, 2 * n), rr.uniform(n, 2 * n)
        for k in range(rr.randint(3, 5)):
            a_ = rr.uniform(-0.9, 0.9)
            L = rr.uniform(3, 7)
            for (ox, oy) in ((0, 0), (n, 0), (-n, 0), (0, n), (0, -n)):
                d.line((x + ox, y + oy, x + ox + math.sin(a_) * L, y + oy - math.cos(a_) * L), fill=(120, 104, 64, 200), width=1)
    im = Image.alpha_composite(im, g.crop((n, n, 2 * n, 2 * n)))
    return im


# ------------------------------------------------------------------ decals
def _soft(im, r):
    return im.filter(ImageFilter.GaussianBlur(r))


def crack(w, h, seed):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    segs = []

    def branch(x, y, a, L, width, depth):
        while L > 4 and 4 < x < w * 2 - 4 and 4 < y < h * 2 - 4:
            a += rr.uniform(-0.5, 0.5)
            s = rr.uniform(6, 14)
            nx, ny = x + math.cos(a) * s, y + math.sin(a) * s
            segs.append((x, y, nx, ny, width))
            if depth < 2 and rr.random() < 0.22:
                branch(nx, ny, a + rr.choice([-1, 1]) * rr.uniform(0.6, 1.2), L * 0.45, max(1.6, width * 0.6), depth + 1)
            x, y, L = nx, ny, L - s
            width = max(1.6, width * 0.93)

    branch(w * 0.15, h * (0.5 + rr.uniform(-0.3, 0.3)), rr.uniform(-0.4, 0.4), w * 1.7, 4.4, 0)
    for (x, y, nx, ny, wd) in segs:          # lit lip below-right
        d.line((x + 2, y + 2, nx + 2, ny + 2), fill=(196, 170, 130, 90), width=max(1, int(wd * 0.6)))
    for (x, y, nx, ny, wd) in segs:          # dark crack
        d.line((x, y, nx, ny), fill=(28, 20, 14, 220), width=int(wd))
    for (x, y, nx, ny, wd) in segs:          # deep core
        d.line((x, y, nx, ny), fill=(10, 7, 5, 230), width=max(1, int(wd * 0.45)))
    return lay.resize((w, h), Image.LANCZOS)


def tracks(w, h, seed):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for cy in (h * 0.3, h * 0.72):
        tw = 8
        for x in range(0, w, 1):
            fade = min(1.0, x / 30.0, (w - x) / 30.0)
            yy = cy + math.sin(x / 70.0 + seed) * 2.0
            a = int(80 * fade * (0.7 + 0.3 * rr.random()))
            d.line((x, yy - tw / 2, x, yy + tw / 2), fill=(30, 22, 16, a))
            if x % 5 == 0:        # tread chevrons
                d.line((x, yy - tw / 2 + 1, x + 2, yy), fill=(18, 12, 8, int(a * 1.3)))
                d.line((x + 2, yy, x, yy + tw / 2 - 1), fill=(18, 12, 8, int(a * 1.3)))
            if x % 3 == 0:        # lit rim along the lower edge of the rut
                d.point((x, yy + tw / 2 + 1), fill=(190, 160, 120, int(50 * fade)))
    return lay


def oil(w, h, seed):
    rr = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((w * 0.1, h * 0.18, w * 0.82, h * 0.86), fill=255)
    for _ in range(5):
        x, y, r = rr.uniform(w * 0.15, w * 0.9), rr.uniform(h * 0.2, h * 0.85), rr.uniform(2, h * 0.22)
        d.ellipse((x - r, y - r * 0.7, x + r, y + r * 0.7), fill=255)
    m = _soft(m, 1.2)
    col = Image.new("RGBA", (w, h), (16, 13, 12, 0))
    col.putalpha(m.point(lambda v: int(v * 0.86)))
    sh = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sh).arc((w * 0.2, h * 0.24, w * 0.7, h * 0.7), 200, 300, fill=200, width=2)
    sh = _soft(sh, 0.8)
    hl = Image.new("RGBA", (w, h), (120, 130, 150, 0))
    hl.putalpha(Image.fromarray((np.asarray(sh, np.float32) * np.asarray(m, np.float32) / 255 * 0.7).astype(np.uint8)))
    return Image.alpha_composite(col, hl)


def toxic(w, h, seed):
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((w * 0.12, h * 0.2, w * 0.88, h * 0.82), fill=255)
    m = _soft(m, 1.0)
    glow = Image.new("RGBA", (w, h), (120, 200, 60, 0))
    glow.putalpha(_soft(m, 3).point(lambda v: int(v * 0.35)))
    body = Image.new("RGBA", (w, h), (84, 130, 30, 0))
    body.putalpha(m.point(lambda v: int(v * 0.9)))
    out = Image.alpha_composite(glow, body)
    d2 = ImageDraw.Draw(out)
    d2.ellipse((w * 0.3, h * 0.32, w * 0.52, h * 0.46), fill=(190, 236, 110, 200))
    d2.ellipse((w * 0.6, h * 0.5, w * 0.68, h * 0.58), fill=(170, 220, 90, 180))
    return out


def stones(w, h, seed, n, cols, rmin, rmax):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    pts = []
    for _ in range(n):
        r = rr.uniform(rmin, rmax)
        pts.append((rr.uniform(r + 2, w - r - 3), rr.uniform(r + 2, h - r - 3), r, rr.choice(cols)))
    pts.sort(key=lambda p: p[1])
    for (x, y, r, c) in pts:
        d.ellipse((x - r + 1.5, y - r * 0.7 + 2, x + r + 1.5, y + r * 0.7 + 2), fill=(16, 12, 8, 120))
    for (x, y, r, c) in pts:
        d.ellipse((x - r - 1, y - r * 0.8 - 1, x + r + 1, y + r * 0.8 + 1), fill=(24, 18, 12, 255))
        d.ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8), fill=tuple(int(v * 0.72) for v in c) + (255,))
        d.ellipse((x - r * 0.85, y - r * 0.8, x + r * 0.45, y + r * 0.2), fill=c + (255,))
        d.ellipse((x - r * 0.55, y - r * 0.62, x - r * 0.05, y - r * 0.25), fill=tuple(min(255, int(v * 1.25)) for v in c) + (255,))
    return lay


def scrap(w, h, seed):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for k in range(3):
        cx, cy = rr.uniform(6, w - 6), rr.uniform(5, h - 5)
        a = rr.uniform(0, math.pi)
        L, t = rr.uniform(5, 10), rr.uniform(2, 3.4)
        pts = [(cx + math.cos(a) * L - math.sin(a) * t, cy + math.sin(a) * L + math.cos(a) * t),
               (cx + math.cos(a) * L + math.sin(a) * t, cy + math.sin(a) * L - math.cos(a) * t),
               (cx - math.cos(a) * L + math.sin(a) * t, cy - math.sin(a) * L - math.cos(a) * t),
               (cx - math.cos(a) * L - math.sin(a) * t, cy - math.sin(a) * L + math.cos(a) * t)]
        col = rr.choice([(122, 124, 120), (140, 84, 50), (96, 100, 98)])
        d.polygon([(x + 1, y + 2) for (x, y) in pts], fill=(16, 12, 8, 120))
        d.polygon(pts, fill=col + (255,), outline=(24, 18, 14, 255))
        d.line([pts[1], pts[2]], fill=tuple(min(255, v + 50) for v in col) + (255,), width=1)
    return lay


def bones(w, h, seed):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for k in range(2):
        cx, cy = rr.uniform(10, w - 10), rr.uniform(8, h - 8)
        a = rr.uniform(-0.6, 0.6)
        L = rr.uniform(8, 14)
        x0, y0 = cx - math.cos(a) * L, cy - math.sin(a) * L
        x1, y1 = cx + math.cos(a) * L, cy + math.sin(a) * L
        d.line((x0 + 1, y0 + 2, x1 + 1, y1 + 2), fill=(16, 12, 8, 110), width=5)
        d.line((x0, y0, x1, y1), fill=(40, 32, 24, 255), width=6)
        d.line((x0, y0, x1, y1), fill=(170, 160, 134, 255), width=4)
        d.line((x0, y0 - 1, x1, y1 - 1), fill=(200, 190, 162, 255), width=1)
        for (x, y) in ((x0, y0), (x1, y1)):
            d.ellipse((x - 3.6, y - 3.6, x + 3.6, y + 3.6), fill=(40, 32, 24, 255))
            d.ellipse((x - 2.6, y - 2.6, x + 2.6, y + 2.6), fill=(176, 166, 140, 255))
    if seed % 3 == 0:     # small skull
        x, y = w * 0.7, h * 0.45
        d.ellipse((x - 6, y - 5, x + 6, y + 6), fill=(40, 32, 24, 255))
        d.ellipse((x - 5, y - 4, x + 5, y + 5), fill=(180, 170, 146, 255))
        d.ellipse((x - 3.4, y - 0.6, x - 1.0, y + 1.8), fill=(30, 24, 18, 255))
        d.ellipse((x + 1.0, y - 0.6, x + 3.4, y + 1.8), fill=(30, 24, 18, 255))
    return lay


def grass(w, h, seed):
    rr = random.Random(seed)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    bx, by = w / 2, h - 3
    d.ellipse((bx - 8, by - 2, bx + 9, by + 2), fill=(16, 12, 8, 90))
    for k in range(11):
        a = rr.uniform(-1.0, 1.0)
        L = rr.uniform(h * 0.45, h * 0.9)
        x1, y1 = bx + math.sin(a) * L, by - math.cos(a) * L
        col = rr.choice([(150, 128, 70), (122, 104, 58), (170, 150, 90), (104, 92, 52)])
        d.line((bx + rr.uniform(-3, 3), by, x1, y1), fill=(40, 30, 18, 255), width=3)
        d.line((bx + rr.uniform(-3, 3), by, x1, y1), fill=col + (255,), width=1)
    return lay


def stain(w, h, seed):
    rr = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for _ in range(7):
        x, y = rr.uniform(w * 0.35, w * 0.65), rr.uniform(h * 0.4, h * 0.6)
        r = rr.uniform(h * 0.1, h * 0.2)
        d.ellipse((x - r * 1.4, y - r, x + r * 1.4, y + r), fill=255)
    m = _soft(m, h * 0.09)
    out = Image.new("RGBA", (w, h), (24, 16, 10, 0))
    out.putalpha(m.point(lambda v: int(v * 0.42)))
    return out


SPEC = [  # kind, count, (w, h), painter
    ("crack", 3, (92, 60), crack),
    ("tracks", 2, (196, 34), tracks),
    ("oil", 2, (64, 34), oil),
    ("toxic", 2, (54, 34), toxic),
    ("pebbles", 3, (42, 28), lambda w, h, s: stones(w, h, s, 6, [(150, 136, 112), (120, 108, 90), (168, 152, 124)], 2.0, 4.6)),
    ("scrap", 3, (30, 22), scrap),
    ("bones", 3, (46, 28), bones),
    ("grass", 3, (34, 26), grass),
    ("stain", 2, (96, 56), stain),
]


def build_atlas():
    W = 512
    x = y = 0
    row_h = 0
    regions = {}
    placed = []
    for kind, cnt, (w, h), fn in SPEC:
        for i in range(cnt):
            if x + w > W:
                x, y = 0, y + row_h + 2
                row_h = 0
            im = fn(w, h, 100 + i * 7 + len(regions))
            placed.append((im, x, y))
            regions["%s_%d" % (kind, i)] = (x, y, w, h)
            x += w + 2
            row_h = max(row_h, h)
    H = y + row_h
    H = 1 << (H - 1).bit_length()
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for im, px, py in placed:
        atlas.alpha_composite(im, (px, py))
    os.makedirs(DECALS, exist_ok=True)
    atlas.save(os.path.join(DECALS, "decal_atlas.png"))
    with open(ATLAS_GD, "w") as f:
        f.write("extends RefCounted\n\n## Generated by tools/gen_ground_v2.py — regions in decals/decal_atlas.png\n")
        f.write("## (native density: one texel = one screen px; see WastelandChunk.DECAL_TEXEL).\n\nconst REGIONS := {\n")
        for k in sorted(regions):
            r = regions[k]
            f.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % (k, r[0], r[1], r[2], r[3]))
        f.write("}\n")
    return atlas


if __name__ == "__main__":
    sand_tile().save(os.path.join(TILES, "ground_sand.png"))
    sheet = []
    gzt.build(sheet)
    atlas = build_atlas()
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        bg = Image.new("RGBA", atlas.size, (110, 92, 67, 255))
        bg.alpha_composite(atlas)
        bg.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).save(os.path.join(out, "decals_v2.png"))
        Image.open(os.path.join(TILES, "ground_sand.png")).save(os.path.join(out, "sand_v2.png"))
    print("ok")
