"""Small pixel-art toolkit used for the style-bible demo repaints."""
import numpy as np
from PIL import Image
from pal import INK, TONE0, ALL, lab_L, R

LIGHT = np.array([-0.55, -0.6, 0.58])  # top-left, toward viewer (x right, y down, z out)
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def canvas(w, h):
    return np.zeros((h, w, 4), np.uint8)


def put(a, x, y, c, alpha=255):
    H, W = a.shape[:2]
    if 0 <= x < W and 0 <= y < H:
        a[y, x, :3] = c
        a[y, x, 3] = alpha


def ramp_pick(ramp, v, bias=0.0):
    """v in 0..1 -> ramp tone (tone 0 excluded unless v very low)."""
    n = len(ramp)
    i = int(np.clip(np.floor(v * n + bias), 0, n - 1))
    return ramp[i]


def to_img(a):
    return Image.fromarray(a, "RGBA")


def opaque(a):
    return a[:, :, 3] > 0


def outline(a, color_of=None, selout=False):
    """1-px exterior outline (4-neighbour). Colour = tone 0 of the neighbouring material.
    selout: outline pixels whose opaque neighbour is down/right of them (i.e. on the lit
    top-left side) use the neighbour's ramp tone 1 instead of tone 0."""
    m = opaque(a)
    H, W = m.shape
    out = a.copy()
    for y in range(H):
        for x in range(W):
            if m[y, x]:
                continue
            nb = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and m[yy, xx]:
                    nb.append((dx, dy, tuple(int(v) for v in a[yy, xx, :3])))
            if not nb:
                continue
            c = nb[0][2]
            t0 = color_of(c) if color_of else TONE0.get(c, INK)
            lit = all(dx >= 0 and dy >= 0 for dx, dy, _ in nb) and any(dx > 0 or dy > 0 for dx, dy, _ in nb)
            if selout and lit:
                # one step lighter than tone 0 of that ramp, if the material has one
                for name in ("ash", "earth", "rust", "brass", "steel", "cloth", "skin", "plague", "flesh", "dust"):
                    rr = R(name)
                    if c in rr and len(rr) > 2:
                        t0 = rr[1] if lab_L(rr[1]) < lab_L(c) else rr[0]
            out[y, x, :3] = t0
            out[y, x, 3] = 255
    return out


def remove_orphans(a, passes=1):
    """Replace single pixels whose colour differs from all 4 neighbours with the majority neighbour."""
    for _ in range(passes):
        b = a.copy()
        H, W = a.shape[:2]
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                if a[y, x, 3] == 0:
                    continue
                c = tuple(a[y, x, :3])
                nbs = [tuple(a[y + dy, x + dx, :3]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if a[y + dy, x + dx, 3]]
                if len(nbs) == 4 and c not in nbs:
                    best = max(set(nbs), key=nbs.count)
                    if nbs.count(best) >= 3:
                        b[y, x, :3] = best
        a = b
    return a


def ellipse_mask(w, h, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0


def paste(dst, src, x, y):
    """Alpha-over src RGBA array into dst at (x,y) (hard alpha)."""
    H, W = src.shape[:2]
    for j in range(H):
        yy = y + j
        if not (0 <= yy < dst.shape[0]):
            continue
        for i in range(W):
            xx = x + i
            if 0 <= xx < dst.shape[1] and src[j, i, 3]:
                al = src[j, i, 3] / 255.0
                if al >= 0.999:
                    dst[yy, xx] = src[j, i]
                else:
                    dst[yy, xx, :3] = (dst[yy, xx, :3] * (1 - al) + src[j, i, :3] * al).astype(np.uint8)
                    dst[yy, xx, 3] = max(dst[yy, xx, 3], src[j, i, 3])


def contact_shadow(w, alpha=0.45):
    """Hard-edged pixel ellipse shadow: 2 tones (outer 60% of alpha)."""
    h = max(3, int(round(w * 0.3)))
    a = canvas(w, h)
    outer = ellipse_mask(w, h, w / 2, h / 2, w / 2, h / 2)
    inner = ellipse_mask(w, h, w / 2, h / 2, w / 2 - 2, h / 2 - 1)
    a[outer] = (*INK, int(255 * alpha * 0.6))
    a[inner] = (*INK, int(255 * alpha))
    return a


def scale_nearest(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def count_colors(a):
    m = opaque(a)
    return len(set(map(tuple, a[m][:, :3])))
