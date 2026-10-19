"""Zone ground sets (Depth E7): each tier 3-10 zone gets its own floor, built from
the wasteland ground textures (assets/sprites/tiles/ground_<k>.png) so the
shader's biomes, riverbeds and roads keep working:
  * a luminance-preserving regrade into the zone palette (detail kept)
  * seamless zone motifs: oil blotches, concrete slab seams, ash, scorch,
    toxic puddles, painted base lines, extra cracks, glinting Dust
Everything wraps (tiles repeat), and values stay inside the original range so
props and units still read.

usage (from game/):  python3 tools/gen_zone_tiles.py [--sheet DIR]
writes assets/sprites/tiles/zones/ground_<k>_<grade>.png
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "sprites", "tiles")
DST = os.path.join(SRC, "zones")
KINDS = ["earth", "sand", "scrub", "rubble", "riverbed", "asphalt"]

# grade: (dark, light) per kind group ("ground" for earth/sand/scrub/rubble/riverbed, "road" for asphalt), motifs
GRADES = {
    "refinery": {"ground": ((34, 28, 24), (120, 104, 86)), "road": ((20, 19, 20), (78, 74, 72)), "motifs": ["oil", "rust"]},
    "city": {"ground": ((44, 44, 48), (138, 136, 134)), "road": ((24, 24, 28), (84, 84, 88)), "motifs": ["slabs", "cracks"]},
    "quarantine": {"ground": ((40, 46, 36), (136, 146, 116)), "road": ((26, 28, 26), (82, 86, 78)), "motifs": ["ash", "lime"]},
    "raider": {"ground": ((58, 30, 20), (176, 112, 74)), "road": ((30, 22, 20), (92, 74, 66)), "motifs": ["scorch", "tracks"]},
    "chemical": {"ground": ((50, 46, 22), (168, 150, 84)), "road": ((28, 28, 22), (90, 86, 70)), "motifs": ["toxic", "rust"]},
    "military": {"ground": ((62, 58, 40), (150, 140, 104)), "road": ((26, 28, 26), (88, 90, 86)), "motifs": ["slabs_big", "paint"]},
    "crater": {"ground": ((30, 26, 24), (110, 98, 88)), "road": ((20, 18, 18), (72, 66, 64)), "motifs": ["cracks", "cracks", "ash"]},
    "dustfall": {"ground": ((66, 42, 20), (214, 160, 92)), "road": ((40, 30, 22), (120, 92, 66)), "motifs": ["dust", "glint"]},
}


def seamless_noise(n, cells, seed, smooth=Image.BICUBIC):
    rng = np.random.default_rng(seed)
    small = rng.random((cells, cells)).astype(np.float32)
    big = np.tile(small, (3, 3))
    im = Image.fromarray((big * 255).astype(np.uint8)).resize((n * 3, n * 3), smooth)
    a = np.asarray(im).astype(np.float32)[n:2 * n, n:2 * n] / 255.0
    return a


def regrade(a, dark, light, keep=0.2):
    """Recolour to the zone palette keeping the source's own (low) contrast:
    each pixel = palette mid colour x its luminance relative to the tile mean."""
    rgb = a[..., :3].astype(np.float32)
    lum = 0.3 * rgb[..., 0] + 0.55 * rgb[..., 1] + 0.15 * rgb[..., 2]
    rel = lum / max(1.0, float(lum.mean()))
    mid = (np.asarray(dark, np.float32) + np.asarray(light, np.float32)) * 0.5
    col = mid[None, None] * rel[..., None]
    hue = rgb - rgb.mean(axis=(0, 1))
    a = a.copy()
    a[..., :3] = np.clip(col + hue * keep, 0, 255)
    return a


def blend(a, mask, col, k):
    m = np.clip(mask, 0, 1)[..., None] * k
    a[..., :3] = a[..., :3] * (1 - m) + np.asarray(col, np.float32)[None, None] * m
    return a


def draw_wrapped(n, fn):
    """Draw on a 3x tile canvas and fold it back so strokes wrap seamlessly."""
    big = Image.new("L", (n * 3, n * 3), 0)
    d = ImageDraw.Draw(big)
    fn(d, n)
    a = np.asarray(big).astype(np.float32) / 255.0
    out = np.zeros((n, n), np.float32)
    for i in range(3):
        for j in range(3):
            out = np.maximum(out, a[i * n:(i + 1) * n, j * n:(j + 1) * n])
    return out


def motif(a, name, kind, seed):
    n = a.shape[0]
    rng = np.random.default_rng(seed)
    road = kind == "asphalt"
    if name == "oil":
        m = seamless_noise(n, 14, seed)
        a = blend(a, np.clip((m - 0.78) * 7, 0, 1), (22, 18, 16), 0.55)
    elif name == "rust":
        m = seamless_noise(n, 16, seed)
        a = blend(a, np.clip((m - 0.8) * 6, 0, 1), (120, 62, 30), 0.3)
    elif name in ("slabs", "slabs_big") and not road and kind not in ("rubble", "riverbed"):
        step = n // (2 if name == "slabs" else 1)

        def f(d, n_):
            for k in range(step // 2, 3 * n_ + 1, step):
                d.line([(k, 0), (k, 3 * n_)], fill=255, width=3)
                d.line([(0, k), (3 * n_, k)], fill=255, width=3)
        seams = draw_wrapped(n, f)
        a = blend(a, seams, (30, 30, 32), 0.55)
        hl = np.roll(seams, 2, axis=0) * (1 - seams)
        a = blend(a, hl, (190, 186, 178), 0.12)
    elif name == "cracks":
        def f(d, n_):
            for k in range(14 if not road else 6):
                x, y = rng.uniform(n_, 2 * n_), rng.uniform(n_, 2 * n_)
                ang = rng.uniform(0, 6.28)
                pts = [(x, y)]
                for s in range(rng.integers(4, 9)):
                    ang += rng.uniform(-0.7, 0.7)
                    L = rng.uniform(10, 34)
                    x, y = x + np.cos(ang) * L, y + np.sin(ang) * L
                    pts.append((x, y))
                d.line(pts, fill=255, width=2)
        a = blend(a, draw_wrapped(n, f), (18, 16, 16), 0.6)
    elif name == "ash":
        m = seamless_noise(n, 20, seed) * 0.6 + seamless_noise(n, 64, seed + 5) * 0.4
        a = blend(a, np.clip((m - 0.6) * 3, 0, 1), (196, 192, 184), 0.1)
    elif name == "lime":
        m = seamless_noise(n, 14, seed)
        a = blend(a, np.clip((m - 0.8) * 6, 0, 1), (176, 196, 110), 0.22)
    elif name == "scorch":
        m = seamless_noise(n, 7, seed)
        a = blend(a, np.clip((m - 0.7) * 5, 0, 1), (30, 18, 14), 0.55)
    elif name == "tracks" and not road:
        def f(d, n_):
            for k in range(3):
                y0 = rng.uniform(n_, 2 * n_)
                for off in (-7, 7):
                    pts = [(x, y0 + off + 10 * np.sin(x / 90.0 + k)) for x in range(0, 3 * n_, 12)]
                    d.line(pts, fill=255, width=3)
        a = blend(a, draw_wrapped(n, f), (60, 34, 24), 0.35)
    elif name == "toxic":
        m = seamless_noise(n, 14, seed)
        pud = np.clip((m - 0.8) * 8, 0, 1)
        a = blend(a, pud, (110, 136, 34), 0.45)
        a = blend(a, np.clip((m - 0.87) * 10, 0, 1), (170, 196, 70), 0.3)
    elif name == "paint" and road:
        def f(d, n_):
            for k in range(0, 3 * n_, n_ // 2):
                d.rectangle([k + 20, int(1.5 * n_) - 3, k + 70, int(1.5 * n_) + 3], fill=255)
        a = blend(a, draw_wrapped(n, f), (206, 170, 60), 0.55)
    elif name == "dust":
        m = seamless_noise(n, 5, seed)
        a = blend(a, np.clip((m - 0.55) * 3, 0, 1), (236, 190, 120), 0.2)
    elif name == "glint":
        m = seamless_noise(n, n // 3, seed, Image.NEAREST)
        a = blend(a, (m > 0.993).astype(np.float32), (255, 226, 150), 0.85)
    return a


def build(sheet):
    os.makedirs(DST, exist_ok=True)
    for gi, (grade, g) in enumerate(GRADES.items()):
        row = []
        for ki, k in enumerate(KINDS):
            src = np.asarray(Image.open(os.path.join(SRC, "ground_%s.png" % k)).convert("RGBA")).astype(np.float32)
            dark, light = g["road" if k == "asphalt" else "ground"]
            if k == "riverbed":
                dark = tuple(int(v * 0.85) for v in dark)
            a = regrade(src, dark, light)
            for mi, mname in enumerate(g["motifs"]):
                a = motif(a, mname, k, 1000 * gi + 37 * ki + mi)
            im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
            im.save(os.path.join(DST, "ground_%s_%s.png" % (k, grade)))
            row.append(im)
        sheet.append((grade, row))


if __name__ == "__main__":
    sheet = []
    build(sheet)
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        S = 160
        im = Image.new("RGBA", (S * 6, S * len(sheet)))
        for r, (grade, row) in enumerate(sheet):
            for c, t in enumerate(row):
                im.paste(t.crop((0, 0, min(t.width, 256), min(t.height, 256))).resize((S, S)), (c * S, r * S))
        im.save(os.path.join(out, "zone_tiles.png"))
    print("ok")
