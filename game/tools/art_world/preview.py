"""Review sheet: every asset on its zone ground next to Rook, 1x and 2x, plus
validator results. usage: python3 preview.py OUT.png module:fn[,module:fn...] [zone]"""
import sys
import importlib
import numpy as np
from PIL import Image, ImageDraw
from pal import ZONES
from pk import Cv, validate
import os

ROOT = os.path.dirname(os.path.abspath(__file__)) + "/../../"
ROOK = ROOT + "assets/sprites/characters/ash_rook/ash_rook_idle.png"


def ground_img(w, h_, zone):
    from ground_tiles import tile
    t = tile(ZONES[zone][2], "earth", seed=3)
    reps = np.tile(t, ((h_ // t.shape[0]) + 1, (w // t.shape[1]) + 1, 1))[:h_, :w]
    return Image.fromarray(reps).convert("RGBA")


def sheet(items, zone=0, scale=2):
    rook = Image.open(ROOK).convert("RGBA").crop((0, 0, 128, 128))
    rook = rook.crop(rook.getbbox())
    pad = 10
    imgs = [(n, Image.fromarray(cv.a, "RGBA")) for n, cv in items]
    W = 1400
    rows = []
    x = pad
    row = []
    rh = 0
    for n, im in imgs:
        w = rook.width + im.width + 3 * pad
        if x + w * 1 > W and row:
            rows.append((row, rh)); row = []; x = pad; rh = 0
        row.append((n, im)); x += w; rh = max(rh, im.height, rook.height)
    rows.append((row, rh))
    H = sum(r[1] + 2 * pad + 14 for r in rows)
    g = ground_img(W, H, zone)
    d = ImageDraw.Draw(g)
    y = pad
    for row, rh in rows:
        x = pad
        for n, im in row:
            base = y + rh
            g.alpha_composite(rook, (x, base - rook.height))
            g.alpha_composite(im, (x + rook.width + pad, base - im.height))
            d.text((x, base + 2), n, fill=(233, 223, 201))
            x += rook.width + im.width + 3 * pad
        y += rh + 2 * pad + 14
    return g


def zoom(items, zone=0, k=4, W=1000):
    """Props only, k x, on zone ground (for close review)."""
    pad = 6
    ims = [Image.fromarray(cv.a, "RGBA") for _, cv in items]
    rows, row, x, rh = [], [], 0, 0
    for im in ims:
        if x + (im.width + pad) * k > W and row:
            rows.append((row, rh)); row, x, rh = [], 0, 0
        row.append(im); x += (im.width + pad) * k; rh = max(rh, im.height)
    rows.append((row, rh))
    H = sum((r[1] + pad) * k for r in rows) + pad * k
    g = ground_img(W // k + 1, H // k + 1, zone)
    y = pad
    for row, rh in rows:
        x = pad
        for im in row:
            g.alpha_composite(im, (x, y + rh - im.height))
            x += im.width + pad
        y += rh + pad
    return g.resize((g.width * k, g.height * k), Image.NEAREST)


if __name__ == "__main__":
    out = sys.argv[1]
    zone = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    items = []
    for spec in sys.argv[2].split(","):
        mod, fn = spec.split(":")
        m = importlib.import_module(mod)
        cv = getattr(m, fn)()
        v = validate(cv, name=fn)
        print(fn, v["bbox"], "cols", v["colors"], "orph", v["orphans"], v["errors"] or "OK")
        items.append((fn, cv))
    s = sheet(items, zone)
    s.save(out)
    s.resize((s.width * 2, s.height * 2), Image.NEAREST).save(out.replace(".png", "_2x.png"))
    for i in range(0, len(items), 6):
        zoom(items[i:i + 6], zone).save(out.replace(".png", "_z%d.png" % (i // 6)))
