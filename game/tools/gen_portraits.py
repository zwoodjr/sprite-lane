"""Hero + pet portraits rendered from the painted cutout art (idle frame 0).

Heroes: head-and-shoulders bust. Pets: whole animal. Upscaled with Scale2x
twice (keeps the painted pixel clusters crisp) then resampled to 192 px, with
a soft amber back-glow, a 2 px dark seam and a top-left rim light.

usage: python3 tools/gen_portraits.py
Writes assets/sprites/portraits/<id>.png and assets/sprites/portraits/pet_<id>.png
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = "assets/sprites/portraits"
os.makedirs(OUT, exist_ok=True)
SIZE = 192
HEROES = ["ash_rook", "vesper_thorn", "pebble", "bolt_juno", "sister_cinder", "quill_marrow", "nyx_caldera", "helm_wisp"]
PETS = ["bentley", "lillie", "noel"]


def scale2x(a):
    h, w, _ = a.shape
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    P = p[1:-1, 1:-1]; A = p[:-2, 1:-1]; B = p[1:-1, 2:]; C = p[1:-1, :-2]; D = p[2:, 1:-1]
    eq = lambda x, y: np.all(x == y, axis=2)
    o = np.zeros((h * 2, w * 2, 4), np.uint8)
    o[0::2, 0::2] = np.where((eq(C, A) & ~eq(C, D) & ~eq(A, B))[..., None], A, P)
    o[0::2, 1::2] = np.where((eq(A, B) & ~eq(A, C) & ~eq(B, D))[..., None], B, P)
    o[1::2, 0::2] = np.where((eq(D, C) & ~eq(D, B) & ~eq(C, A))[..., None], C, P)
    o[1::2, 1::2] = np.where((eq(B, D) & ~eq(B, A) & ~eq(D, C))[..., None], D, P)
    return o


def frame0(path):
    im = Image.open(path).convert("RGBA")
    h = im.height
    return np.array(im.crop((0, 0, h, h)))


def bust_box(a):
    al = a[..., 3] > 40
    ys, xs = np.nonzero(al)
    y0, y1 = ys.min(), ys.max()
    bh = y1 - y0 + 1
    # head centre: centroid of the top 16% of the silhouette, weighted to the
    # widest-but-not-weapon cluster (ignore thin long lines by eroding first)
    top = al.copy()
    top[int(y0 + bh * 0.16):] = False
    top = ndi.binary_opening(top, iterations=1) if top.sum() > 30 else top
    ## legs centre (feet band) anchors which top cluster is the head, not a weapon
    ly, lx = np.nonzero(al[int(y0 + bh * 0.75):])
    legs_x = lx.mean() if len(lx) else (xs.min() + xs.max()) / 2
    lab, n = ndi.label(top)
    if n > 1:
        best, best_d = 1, 1e9
        for k in range(1, n + 1):
            kx = np.nonzero(lab == k)[1]
            if len(kx) < 12:
                continue
            dd = abs(kx.mean() - legs_x)
            if dd < best_d:
                best, best_d = k, dd
        top = lab == best
    ty, tx = np.nonzero(top)
    head_x = tx.mean() if len(tx) else legs_x
    cx = head_x * 0.65 + legs_x * 0.35
    s = int(bh * 0.5)
    x0 = int(round(cx - s / 2))
    yy0 = int(y0 - bh * 0.04)
    return x0, yy0, s


def pet_box(a):
    al = a[..., 3] > 40
    ys, xs = np.nonzero(al)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    s = int(max(y1 - y0, x1 - x0) * 1.12)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return int(cx - s / 2), int(cy - s / 2), s


def crop_pad(a, x0, y0, s):
    h, w, _ = a.shape
    out = np.zeros((s, s, 4), np.uint8)
    sx0, sy0 = max(0, x0), max(0, y0)
    sx1, sy1 = min(w, x0 + s), min(h, y0 + s)
    out[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = a[sy0:sy1, sx0:sx1]
    return out


def render(a, fade_bottom):
    a = scale2x(scale2x(a))
    im = Image.fromarray(a, "RGBA")
    inner = SIZE - 16
    im = im.resize((inner, inner), Image.LANCZOS)
    art = np.array(im).astype(np.float32)
    al = art[..., 3] / 255.0
    # rim light: top-left edge of the silhouette
    solid = al > 0.5
    edge = solid & ~np.roll(np.roll(solid, 2, axis=0), 2, axis=1)
    art[..., :3] = np.where(edge[..., None], np.minimum(255, art[..., :3] * 1.18 + 26), art[..., :3])
    # seam (dark outline 2px) behind the art
    out_m = ndi.binary_dilation(solid, iterations=2)
    canvas = np.zeros((SIZE, SIZE, 4), np.float32)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    # soft amber back-glow
    d = np.sqrt((xx - SIZE * 0.45) ** 2 + (yy - SIZE * 0.42) ** 2)
    g = np.clip(1.0 - d / (SIZE * 0.55), 0, 1) ** 1.6
    canvas[..., 0] = 255; canvas[..., 1] = 176; canvas[..., 2] = 80
    canvas[..., 3] = g * 120
    o = 8
    seam = np.zeros((SIZE, SIZE), bool)
    seam[o:o + inner, o:o + inner] = out_m
    canvas[seam] = [20, 14, 10, 255]
    sub = canvas[o:o + inner, o:o + inner]
    a1 = al[..., None]
    sub[..., :3] = sub[..., :3] * (1 - a1) + art[..., :3] * a1
    sub[..., 3] = np.maximum(sub[..., 3], art[..., 3])
    if fade_bottom:
        f = np.clip((SIZE - yy) / (SIZE * 0.16), 0, 1)
        canvas[..., 3] *= f
    return Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGBA")


def main():
    for hid in HEROES:
        a = frame0("assets/sprites/characters/%s/%s_idle.png" % (hid, hid))
        x0, y0, s = bust_box(a)
        render(crop_pad(a, x0, y0, s), True).save(os.path.join(OUT, "%s.png" % hid))
    for pid in PETS:
        a = frame0("assets/sprites/pets/%s/%s_idle.png" % (pid, pid))
        x0, y0, s = pet_box(a)
        render(crop_pad(a, x0, y0, s), False).save(os.path.join(OUT, "pet_%s.png" % pid))
    print("ok")


if __name__ == "__main__":
    main()
