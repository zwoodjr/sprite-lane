"""HD pass for Wanderer pixel art: 2x pixel-art upscale + volume lighting,
material texture, rim light and selective outline. Keeps the chunky dark outline style.

usage: python3 hd.py SRC_DIR DST_DIR
Strips (width > height, width % height == 0) are processed frame by frame."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

OUTL = np.array([24, 18, 14])
LIGHT = np.array([-0.62, -0.62, 0.48])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def scale2x(a):
    """EPX/Scale2x on an HxWx4 uint8 array (exact colors, no blending)."""
    h, w, _ = a.shape
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    P = p[1:-1, 1:-1]
    A = p[:-2, 1:-1]; B = p[1:-1, 2:]; C = p[1:-1, :-2]; D = p[2:, 1:-1]
    eq = lambda x, y: np.all(x == y, axis=2)
    o = np.zeros((h * 2, w * 2, 4), np.uint8)
    e0 = np.where((eq(C, A) & ~eq(C, D) & ~eq(A, B))[..., None], A, P)
    e1 = np.where((eq(A, B) & ~eq(A, C) & ~eq(B, D))[..., None], B, P)
    e2 = np.where((eq(D, C) & ~eq(D, B) & ~eq(C, A))[..., None], C, P)
    e3 = np.where((eq(B, D) & ~eq(B, A) & ~eq(D, C))[..., None], D, P)
    o[0::2, 0::2] = e0; o[0::2, 1::2] = e1; o[1::2, 0::2] = e2; o[1::2, 1::2] = e3
    return o


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def hd_frame(img):
    a = scale2x(np.array(img.convert("RGBA")))
    rgb = a[..., :3].astype(np.float32)
    al = a[..., 3].astype(np.float32)
    solid = al >= 250
    is_out = solid & (np.abs(rgb - OUTL).sum(axis=2) < 30)
    body = solid & ~is_out
    if body.sum() < 4:
        return Image.fromarray(a)

    # --- volume lighting from a height map (distance to the body edge)
    dist = ndi.distance_transform_edt(body)
    height = np.sqrt(np.clip(dist, 0, 10) / 10.0)
    height = ndi.gaussian_filter(height, 1.2)
    gy, gx = np.gradient(height)
    n = np.dstack([-gx * 6, -gy * 6, np.ones_like(gx)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    lam = np.clip((n * LIGHT).sum(axis=2), 0, 1)
    shade = (lam - LIGHT[2]) * 1.6                       # ~0 on flat tops, +/- on slopes
    # quantize to 4 bands so it stays pixel-art, dithered at band edges
    hh, ww = shade.shape
    bay = np.tile(BAYER, (hh // 4 + 1, ww // 4 + 1))[:hh, :ww]
    shade_q = np.round(shade * 3 + bay * 0.9) / 3.0
    shade_q = np.clip(shade_q, -0.5, 0.45)

    # --- ambient occlusion on the bottom-right inner edge, rim light on top-left
    edge = body & ~ndi.binary_erosion(body, iterations=1)
    up_left_open = ~np.roll(np.roll(body, 1, 0), 1, 1)
    down_right_open = ~np.roll(np.roll(body, -1, 0), -1, 1)
    rim = edge & up_left_open
    ao = edge & down_right_open & ~rim

    # --- material texture: tiny ordered-dither grain, stronger on mid tones
    lum = rgb.mean(axis=2) / 255.0
    grain = bay * (0.10 * (1 - np.abs(lum - 0.5) * 1.4))

    f = 1.0 + shade_q + grain
    f = np.where(rim, f + 0.28, f)
    f = np.where(ao, f - 0.30, f)
    out = rgb.copy()
    lit = np.clip(rgb * f[..., None], 0, 255)
    # rim light also pushes toward warm white a bit
    lit = np.where(rim[..., None], lit * 0.8 + np.array([255, 244, 220]) * 0.2, lit)
    out[body] = lit[body]

    # --- selective outline: inner half of the 2px outline takes a darkened neighbor color
    near_body = ndi.binary_dilation(body, iterations=1) & is_out
    nb = np.zeros_like(rgb)
    cnt = np.zeros(rgb.shape[:2], np.float32)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        sh = np.roll(np.roll(out, dy, 0), dx, 1)
        sb = np.roll(np.roll(body, dy, 0), dx, 1)
        nb += sh * sb[..., None]
        cnt += sb
    avg = nb / np.maximum(cnt, 1)[..., None]
    sel = near_body & (cnt > 0)
    out[sel] = (avg[sel] * 0.38 + OUTL * 0.62)

    res = a.copy()
    res[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
    return Image.fromarray(res)


def hd(img):
    w, h = img.size
    if w > h and w % h == 0:
        n = w // h
        frames = [hd_frame(img.crop((i * h, 0, i * h + h, h))) for i in range(n)]
        s = Image.new("RGBA", (w * 2, h * 2))
        for i, f in enumerate(frames):
            s.alpha_composite(f, (i * h * 2, 0))
        return s
    if h > w and h % w == 0 and False:
        pass
    return hd_frame(img)


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    n = 0
    for root, _, files in os.walk(src):
        for fn in files:
            if not fn.endswith(".png"):
                continue
            rel = os.path.relpath(os.path.join(root, fn), src)
            os.makedirs(os.path.dirname(os.path.join(dst, rel)), exist_ok=True)
            hd(Image.open(os.path.join(root, fn))).save(os.path.join(dst, rel))
            n += 1
    print(n, "files")
