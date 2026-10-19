"""Painted HD pass for flat low-res props / pickups (Wanderer).

Turns flat-colour pixel sprites into the approved painted cutout look at 2x:
  * Scale2x twice then resample to 2x  -> smooth silhouettes, no blur
  * every flat colour region gets its own light ramp (top-left lit,
    bottom-right shaded) quantised to 4 tones with ordered dither
  * material grit (dithered noise), bevel highlight on region top-left
    edges, dark seams on bottom-right edges, warm rim on the silhouette
  * chunky 2 px dark outline kept

usage: python3 tools/paint_pass.py SRC.png [SRC2.png ...] OUT_DIR
"""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

OUTL = np.array([22, 16, 12], np.float32)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5).astype(np.float32)


def scale2x(a):
    h, w, _ = a.shape
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    P = p[1:-1, 1:-1]; A = p[:-2, 1:-1]; B = p[1:-1, 2:]; C = p[1:-1, :-2]; D = p[2:, 1:-1]
    eq = lambda x, y: np.all(x == y, axis=2)
    o = np.zeros((h * 2, w * 2, a.shape[2]), a.dtype)
    o[0::2, 0::2] = np.where((eq(C, A) & ~eq(C, D) & ~eq(A, B))[..., None], A, P)
    o[0::2, 1::2] = np.where((eq(A, B) & ~eq(A, C) & ~eq(B, D))[..., None], B, P)
    o[1::2, 0::2] = np.where((eq(D, C) & ~eq(D, B) & ~eq(C, A))[..., None], C, P)
    o[1::2, 1::2] = np.where((eq(B, D) & ~eq(B, A) & ~eq(D, C))[..., None], D, P)
    return o


def paint(img, seed=0):
    src = np.array(img.convert("RGBA"))
    # label flat colour regions on the source (before upscaling)
    a = scale2x(src)                      # 2x, exact colours
    h, w, _ = a.shape
    rgb = a[..., :3].astype(np.float32)
    al = a[..., 3]
    solid = al > 128
    dark = solid & (rgb.sum(axis=2) < 150)
    body = solid & ~dark
    # quantise colours a little so near-identical shades join one region
    key = (a[..., 0].astype(np.int32) // 12) * 10000 + (a[..., 1].astype(np.int32) // 12) * 100 + (a[..., 2].astype(np.int32) // 12)
    key[~body] = -1
    out = rgb.copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    bay = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    rng = np.random.default_rng(seed)
    grit = ndi.gaussian_filter(rng.random((h, w)).astype(np.float32), 0.7)
    grit = (grit - grit.mean()) / (grit.std() + 1e-6)
    shade = np.zeros((h, w), np.float32)
    for k in np.unique(key):
        if k < 0:
            continue
        m = key == k
        lab, n = ndi.label(m)
        for i in range(1, n + 1):
            r = lab == i
            ys, xs = np.nonzero(r)
            if len(ys) < 3:
                continue
            y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
            # diagonal ramp across the region's box, light from top-left
            ty = (yy - y0) / max(1.0, y1 - y0)
            tx = (xx - x0) / max(1.0, x1 - x0)
            t = (ty * 0.7 + tx * 0.3)
            # distance-to-edge gives a soft round volume
            d = ndi.distance_transform_edt(r)
            vol = np.clip(d / max(2.0, min(y1 - y0, x1 - x0) * 0.35), 0, 1)
            s = (0.5 - t) * 0.42 + (vol - 0.5) * 0.12
            shade[r] = s[r]
    # 4 tones with dithered transitions
    q = np.round(shade * 4.0 + bay * 0.9) / 4.0
    q = np.clip(q, -0.32, 0.3)
    lum = rgb.mean(axis=2) / 255.0
    f = 1.0 + q + grit * 0.045 * (1.0 - np.abs(lum - 0.5))
    # region edges: bevel highlight (top/left) and seam (bottom/right)
    edge_tl = body & ((np.roll(key, 1, 0) != key) | (np.roll(key, 1, 1) != key))
    edge_br = body & ((np.roll(key, -1, 0) != key) | (np.roll(key, -1, 1) != key))
    f = np.where(edge_tl & ~edge_br, f + 0.16, f)
    f = np.where(edge_br & ~edge_tl, f - 0.2, f)
    out[body] = np.clip(rgb * f[..., None], 0, 255)[body]
    # warm rim where the silhouette faces top-left
    sil = solid
    rim = body & ~np.roll(np.roll(sil, 2, 0), 2, 1)
    out[rim] = np.clip(out[rim] * 0.82 + np.array([255, 236, 200]) * 0.18, 0, 255)
    # outline: dark pixels pulled toward the shared seam colour
    res = np.zeros((h, w, 4), np.float32)
    res[..., :3] = out
    res[..., 3] = al
    res[dark, :3] = OUTL * 0.6 + rgb[dark] * 0.4
    return Image.fromarray(np.clip(res, 0, 255).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    srcs, dst = sys.argv[1:-1], sys.argv[-1]
    os.makedirs(dst, exist_ok=True)
    for i, s in enumerate(srcs):
        paint(Image.open(s), seed=i).save(os.path.join(dst, os.path.basename(s)))
    print(len(srcs), "files")
