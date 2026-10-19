"""Shared "worn post-apocalyptic" paint-over helpers (art direction locked Oct 2026:
polished but worn down — dark grade, grime, rust, dents, bullet holes, scorch,
cracked glass, loose wires, dim amber phosphor lights; repairs = welded scrap
patches with bead welds and bolts, spliced cables).

Used by tools/gen_hangar_art.py (props, with rank progression) and
tools/gen_ui_kit.py (plates, buttons, caps, frames). Everything is PIL RGBA
and deterministic for a given random.Random / seed. `u` is the size of one
"detail unit" in output pixels (bullet hole radius ~ 1.6u, bead ~ 1u ...).
"""
import math
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

AMBER_LAMP = (232, 146, 44)
AMBER_HOT = (255, 196, 110)
PHOSPHOR = (222, 138, 36)


# ---------------------------------------------------------------- basics
def noise(w, h, blur=0.0, seed=0):
    r = np.random.default_rng(seed)
    im = Image.fromarray((r.random((h, w)) * 255).astype(np.uint8))
    return im.filter(ImageFilter.GaussianBlur(blur)) if blur else im


def over(base, color, alpha):
    """Composite a flat colour through an L alpha mask, keeping base alpha."""
    a0 = base.getchannel("A")
    lay = Image.new("RGBA", base.size, tuple(color[:3]) + (0,))
    lay.putalpha(alpha)
    out = Image.alpha_composite(base, lay)
    out.putalpha(a0)
    return out


def scale_l(m, k):
    return m.point(lambda v: min(255, int(v * k)))


def body_mask(im, thr=200, erode=0):
    a = im.getchannel("A").point(lambda v: 255 if v > thr else 0)
    if erode:
        a = a.filter(ImageFilter.MinFilter(erode * 2 + 1))
    return a


def keep_alpha(im, a):
    im = im.copy()
    im.putalpha(a)
    return im


# ---------------------------------------------------------------- grading
def grade(im, dark=0.62, sat=0.6, warm=(1.0, 0.93, 0.84), contrast=1.12):
    a = im.getchannel("A")
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    rgb = ImageEnhance.Brightness(rgb).enhance(dark)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    arr = np.asarray(rgb, np.float32) * np.array(warm, np.float32)
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(a)
    return out


# ---------------------------------------------------------------- dirt + rust
def grime(im, m, amt=200, col=(16, 12, 8), blur=5.0, seed=1, bottom=True):
    w, h = im.size
    n = noise(w, h, blur, seed).point(lambda v: max(0, v - 112) * 3)
    if bottom:
        grad = Image.linear_gradient("L").resize((w, h))
        n = ImageChops.multiply(n, grad.point(lambda v: 90 + v * 165 // 255))
    return over(im, col, ImageChops.multiply(n, m).point(lambda v: v * amt // 255))


def rust_streaks(im, m, n=20, u=3.0, length=(8, 30), seed=2, amt=200):
    rr = random.Random(seed)
    w, h = im.size
    st = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(st)
    ys, xs = np.nonzero(np.asarray(m) > 0)
    if len(xs) == 0:
        return im
    for _ in range(n):
        i = rr.randrange(len(xs))
        x, y = float(xs[i]), float(ys[i])
        L = rr.uniform(*length) * u
        d.line((x, y, x + rr.uniform(-0.6, 0.6) * u, y + L), fill=rr.randint(120, 230),
               width=max(1, int(rr.uniform(0.4, 1.0) * u)))
    st = st.filter(ImageFilter.GaussianBlur(0.7 * u))
    st = ImageChops.multiply(st, noise(w, h, 1, seed).point(lambda v: 120 + v // 2))
    return over(im, (105, 52, 22), ImageChops.multiply(st, m).point(lambda v: v * amt // 255))


def rust_patches(im, m, amount=0.45, u=3.0, seed=3, alpha=225):
    w, h = im.size
    n1 = np.asarray(noise(w, h, 2.2 * u, seed), np.float32) / 255
    n2 = np.asarray(noise(w, h, 0, seed + 1), np.float32) / 255
    # stretch the blurred noise back to 0..1 so `amount` means coverage
    lo, hi = np.percentile(n1, 2), np.percentile(n1, 98)
    n1 = np.clip((n1 - lo) / max(1e-4, hi - lo), 0, 1)
    v = np.clip((n1 - (1 - amount * 0.55)) * 6 + (n2 - 0.5) * 0.35, 0, 1)
    col = np.dstack([92 + 50 * n2, 42 + 26 * n2, 18 + 10 * n2, v * alpha]).astype(np.uint8)
    r = Image.fromarray(col, "RGBA")
    r.putalpha(ImageChops.multiply(r.getchannel("A"), m))
    a0 = im.getchannel("A")
    im = Image.alpha_composite(im, r)
    im.putalpha(a0)
    pit = noise(w, h, 0.25 * u, seed + 2).point(lambda x: 255 if x > 150 else 0)
    pit = ImageChops.multiply(pit, Image.fromarray((v * 255).astype(np.uint8)))
    return over(im, (30, 15, 6), ImageChops.multiply(pit, m).point(lambda x: x * 200 // 255))


def edge_wear(im, m, amt=150, u=3.0, seed=4, col=(170, 158, 136)):
    e = m.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(0.35 * u))
    n = noise(im.width, im.height, 0.9 * u, seed)
    lo, hi = np.percentile(np.asarray(n), 5), np.percentile(np.asarray(n), 95)
    n = n.point(lambda v: 255 if (v - lo) / max(1, hi - lo) > 0.68 else 0)
    e = ImageChops.multiply(scale_l(e, 2.2), n)
    return over(im, col, e.point(lambda v: v * amt // 255))


def scratches(im, m, n=30, u=3.0, length=(3, 12), seed=5, col=(210, 195, 165), amt=90):
    rr = random.Random(seed)
    s = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(s)
    for _ in range(n):
        x = rr.uniform(0, im.width)
        y = rr.uniform(0, im.height)
        L = rr.uniform(*length) * u
        g = rr.uniform(-0.7, 0.7)
        d.line((x, y, x + L * math.cos(g), y + L * math.sin(g)), fill=amt, width=max(1, int(u * 0.3)))
    return over(im, col, ImageChops.multiply(s, m))


# ---------------------------------------------------------------- damage
def dent(im, m, cx, cy, r, amt=110):
    d = Image.new("L", im.size, 0)
    ImageDraw.Draw(d).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d = ImageChops.multiply(d.filter(ImageFilter.GaussianBlur(r / 3)), m)
    im = over(im, (0, 0, 0), d.point(lambda v: v * amt // 255))
    hl = Image.new("L", im.size, 0)
    ImageDraw.Draw(hl).arc((cx - r, cy - r, cx + r, cy + r), 200, 340, fill=255, width=max(2, int(r / 5)))
    hl = ImageChops.multiply(hl.filter(ImageFilter.GaussianBlur(r / 6)), m)
    return over(im, (200, 185, 160), hl.point(lambda v: v * amt * 9 // 10 // 255))


def bullet_hole(im, m, cx, cy, r, seed=0, petal=(120, 112, 98), clip=True):
    """Punched-through hole with peeled petals. Clipped to the mask so holes never
    spill off the silhouette."""
    rr = random.Random(seed)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    pts = [(cx + math.cos(i / 12 * math.tau) * r * rr.uniform(1.0, 1.85),
            cy + math.sin(i / 12 * math.tau) * r * rr.uniform(1.0, 1.85)) for i in range(12)]
    d.polygon(pts, fill=tuple(petal) + (255,))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(8, 6, 5, 255))
    d.arc((cx - r, cy - r, cx + r, cy + r), 200, 330, fill=(70, 62, 52, 255), width=max(1, int(r * 0.35)))
    if clip:
        lay.putalpha(ImageChops.multiply(lay.getchannel("A"), m))
    a0 = im.getchannel("A")
    out = Image.alpha_composite(im, lay)
    out.putalpha(a0)
    return out


def scorch(im, m, cx, cy, r, seed=6, amt=230):
    s = Image.new("L", im.size, 0)
    ImageDraw.Draw(s).ellipse((cx - r, cy - r * 0.7, cx + r, cy + r * 0.7), fill=255)
    s = s.filter(ImageFilter.GaussianBlur(r / 2.5))
    s = ImageChops.multiply(s, noise(im.width, im.height, r / 12 + 1, seed).point(lambda v: min(255, v + 70)))
    return over(im, (8, 6, 4), ImageChops.multiply(s, m).point(lambda v: v * amt // 255))


def cracks(im, x, y, n=6, length=20.0, col=(225, 225, 215, 170), width=1, seed=7, clip=None):
    rr = random.Random(seed)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(n):
        a = rr.uniform(0, math.tau)
        px, py = x, y
        for _k in range(rr.randint(3, 5)):
            a += rr.uniform(-0.6, 0.6)
            L = rr.uniform(0.3, 1.0) * length / 4
            nx, ny = px + math.cos(a) * L, py + math.sin(a) * L
            d.line((px, py, nx, ny), fill=tuple(col), width=width)
            px, py = nx, ny
    if clip is not None:
        lay.putalpha(ImageChops.multiply(lay.getchannel("A"), clip))
    a0 = im.getchannel("A")
    out = Image.alpha_composite(im, lay)
    out.putalpha(a0)
    return out


def wires(lay, start, n=3, u=3.0, seed=9, drop=1.0):
    """Loose dangling wires (draws onto lay, an RGBA image)."""
    rr = random.Random(seed)
    d = ImageDraw.Draw(lay)
    cols = [(150, 35, 25), (35, 70, 120), (170, 150, 40)]
    for k in range(n):
        x, y = start[0] + k * 1.1 * u, start[1]
        pts = [(x, y)]
        for _i in range(4):
            x += rr.uniform(-1.6, 2.6) * u
            y += rr.uniform(1.4, 3.2) * u * drop
            pts.append((x, y))
        d.line(pts, fill=(14, 10, 8, 255), width=max(2, int(1.0 * u)), joint="curve")
        d.line(pts, fill=cols[k % 3] + (255,), width=max(1, int(0.6 * u)), joint="curve")
        d.line((pts[-1][0], pts[-1][1], pts[-1][0] + 0.6 * u, pts[-1][1] + 1.0 * u), fill=(200, 160, 90, 255),
               width=max(1, int(0.35 * u)))
    return lay


def jag_poly(box, amp=2.0, step=6.0, bite=0.0, seed=0):
    """Rect outline with jittered, chewed edges (points list)."""
    rr = random.Random(seed)
    x0, y0, x1, y1 = box
    pts = []

    def edge(ax, ay, bx, by):
        n = max(2, int(math.hypot(bx - ax, by - ay) / step))
        for i in range(n):
            t = i / n
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t
            j = rr.uniform(-amp, amp)
            if bite and rr.random() < 0.08:
                j -= rr.uniform(bite * 0.4, bite)
            nx, ny = (by - ay), -(bx - ax)
            L = math.hypot(nx, ny) or 1
            pts.append((x + nx / L * j, y + ny / L * j))

    edge(x0, y0, x1, y0)
    edge(x1, y0, x1, y1)
    edge(x1, y1, x0, y1)
    edge(x0, y1, x0, y0)
    return pts


# ---------------------------------------------------------------- repairs
PATCH_COLS = [(58, 56, 52), (70, 50, 38), (50, 54, 48), (66, 62, 54)]


def weld_patch(lay, m, box, u=3.0, seed=8, col=None, src=None, bolts=True):
    """A scrap plate welded on (bead weld around the edge, bolts in the corners).
    Draws onto `lay` (RGBA), clipped to mask m. If `src` (RGBA image) is given the
    plate face is that image (a cleaner replacement panel) instead of flat scrap."""
    rr = random.Random(seed)
    x0, y0, x1, y1 = box
    j = 0.9 * u
    pts = [(x0 + rr.uniform(-j, j), y0 + rr.uniform(-j, j)), (x1 + rr.uniform(-j, j), y0 + rr.uniform(-j, j)),
           (x1 + rr.uniform(-j, j), y1 + rr.uniform(-j, j)), (x0 + rr.uniform(-j, j), y1 + rr.uniform(-j, j))]
    pm = Image.new("L", lay.size, 0)
    ImageDraw.Draw(pm).polygon(pts, fill=255)
    pm = ImageChops.multiply(pm, m)
    c = col if col is not None else PATCH_COLS[rr.randrange(len(PATCH_COLS))]
    face = Image.new("RGBA", lay.size, tuple(c) + (255,))
    # plate shading: lit top-left, darker bottom-right + a little grit
    g = Image.linear_gradient("L").rotate(45, expand=False).resize(lay.size)
    face = over(face, (0, 0, 0), g.point(lambda v: v * 70 // 255))
    face = rust_patches(face, pm, 0.3, u * 1.5, seed + 3, alpha=150)
    face = scratches(face, pm, 6, u, (2, 6), seed + 4, amt=70)
    if src is not None:  # a cleaner replacement panel cut from the undamaged prop
        face = Image.alpha_composite(face, src)
    face.putalpha(pm)
    # drop shadow peeking out under the plate edge (it sits proud of the surface)
    sh = ImageChops.offset(pm.filter(ImageFilter.GaussianBlur(0.6 * u)), int(0.5 * u), int(0.6 * u))
    sh = ImageChops.subtract(ImageChops.multiply(sh, m), pm)
    shadow = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    shadow.putalpha(sh.point(lambda v: v * 170 // 255))
    lay.alpha_composite(shadow)
    lay.alpha_composite(face)
    # bead weld along the outline
    beads = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(beads)
    ring = pts + [pts[0]]
    r = max(1.2, 0.55 * u)
    for (ax, ay), (bx, by) in zip(ring, ring[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay) / (1.05 * r)))
        for i in range(n):
            t = i / n
            x = ax + (bx - ax) * t + rr.uniform(-0.15, 0.15) * u
            y = ay + (by - ay) * t + rr.uniform(-0.15, 0.15) * u
            tone = rr.randint(0, 22)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(84 + tone, 76 + tone, 64 + tone, 255),
                      outline=(30, 25, 20, 255))
            d.ellipse((x - r * 0.45, y - r * 0.7, x + r * 0.2, y - r * 0.15), fill=(150, 138, 116, 255))
    # heat tint just inside the bead (blued/straw steel)
    if bolts:
        ins = 1.8 * u
        cx0, cy0 = min(p[0] for p in pts) + ins, min(p[1] for p in pts) + ins
        cx1, cy1 = max(p[0] for p in pts) - ins, max(p[1] for p in pts) - ins
        br = max(1.2, 0.6 * u)
        if cx1 - cx0 > 3 * br and cy1 - cy0 > 3 * br:
            for (bx, by) in [(cx0, cy0), (cx1, cy0), (cx0, cy1), (cx1, cy1)]:
                d.ellipse((bx - br, by - br, bx + br, by + br), fill=(112, 104, 90, 255), outline=(24, 20, 16, 255))
                d.ellipse((bx - br * 0.5, by - br * 0.6, bx, by - br * 0.1), fill=(170, 160, 138, 255))
    beads.putalpha(ImageChops.multiply(beads.getchannel("A"), m))
    lay.alpha_composite(beads)
    return lay


def stitch_patch(lay, m, box, u=3.0, seed=8, col=(120, 104, 80)):
    """A sewn-on fabric patch with a dashed stitch border (cloth repairs)."""
    rr = random.Random(seed)
    x0, y0, x1, y1 = box
    j = 0.6 * u
    pts = [(x0 + rr.uniform(-j, j), y0 + rr.uniform(-j, j)), (x1 + rr.uniform(-j, j), y0 + rr.uniform(-j, j)),
           (x1 + rr.uniform(-j, j), y1 + rr.uniform(-j, j)), (x0 + rr.uniform(-j, j), y1 + rr.uniform(-j, j))]
    p = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.polygon(pts, fill=tuple(col) + (255,), outline=(30, 22, 16, 255))
    ring = pts + [pts[0]]
    for (ax, ay), (bx, by) in zip(ring, ring[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay) / (1.4 * u)))
        for i in range(n):
            t0, t1 = (i + 0.2) / n, (i + 0.6) / n
            ix = lambda t: (ax + (bx - ax) * t, ay + (by - ay) * t)
            a, b = ix(t0), ix(t1)
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            k = 0.85
            a = (cx + (a[0] - cx) * k, cy + (a[1] - cy) * k)
            b = (cx + (b[0] - cx) * k, cy + (b[1] - cy) * k)
            d.line((a, b), fill=(214, 196, 150, 255), width=max(1, int(0.35 * u)))
    p.putalpha(ImageChops.multiply(p.getchannel("A"), m))
    lay.alpha_composite(p)
    return lay


def splice(lay, a, b, u=3.0, seed=10, col=(28, 24, 22)):
    """A cable patched across a gap with tape wraps and a crimp sleeve."""
    rr = random.Random(seed)
    d = ImageDraw.Draw(lay)
    mx = (a[0] + b[0]) / 2 + rr.uniform(-1, 1) * u
    my = (a[1] + b[1]) / 2 + rr.uniform(1, 3) * u
    pts = [a, (mx, my), b]
    d.line(pts, fill=(10, 8, 6, 255), width=max(2, int(1.5 * u)), joint="curve")
    d.line(pts, fill=col + (255,), width=max(2, int(1.0 * u)), joint="curve")
    for t in (0.3, 0.7):
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (my - a[1]) * (1 - abs(t - 0.5) * 2) * 0.9 + (b[1] - a[1]) * t * 0.1
        r = 1.1 * u
        d.rectangle((x - r * 0.6, y - r, x + r * 0.6, y + r), fill=(150, 140, 110, 255), outline=(30, 26, 20, 255))
    return lay


def amber_lamp(lay, x, y, r, glow=3.5, strength=0.75, col=AMBER_LAMP):
    """A lit amber lamp: hot core + soft phosphor glow (drawn onto lay)."""
    g = Image.new("RGBA", lay.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(g)
    R = r * glow
    gd.ellipse((x - R, y - R, x + R, y + R), fill=tuple(col) + (int(255 * strength * 0.55),))
    g = g.filter(ImageFilter.GaussianBlur(R * 0.45))
    lay.alpha_composite(g)
    d = ImageDraw.Draw(lay)
    d.ellipse((x - r, y - r, x + r, y + r), fill=tuple(col) + (255,))
    d.ellipse((x - r * 0.55, y - r * 0.6, x + r * 0.15, y - r * 0.05), fill=AMBER_HOT + (255,))
    return lay


def kill_light(im, x, y, r, glow_r):
    """Dead lamp: the glass goes dark/grey and the halo it threw is dimmed."""
    w, h = im.size
    arr = np.asarray(im, np.float32).copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
    core = np.clip((r + 1.0 - d), 0, 1)
    halo = np.exp(-(d / max(1.0, glow_r)) ** 2 * 1.6) * (1 - core)
    rgb = arr[..., :3]
    lum = rgb.mean(-1, keepdims=True)
    dead = np.array([46, 40, 36], np.float32) + (lum - 60) * 0.25
    rgb = rgb * (1 - core[..., None]) + dead * core[..., None]
    # halo: desaturate + darken what the glow lit up
    lum = rgb.mean(-1, keepdims=True)
    rgb = rgb * (1 - halo[..., None] * 0.55) + lum * 0.7 * halo[..., None] * 0.55
    arr[..., :3] = rgb
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- outlines
def chew_alpha(a, amp=2.0, blur=1.2, seed=0, bites=0, bite_r=4.0):
    """Chewed / pitted silhouette: erode the alpha edge by noise + a few bites."""
    w, h = a.size
    arr = np.asarray(a, np.float32) / 255.0
    # distance-ish via blur of the mask
    soft = np.asarray(a.filter(ImageFilter.GaussianBlur(amp)), np.float32) / 255.0
    n = np.asarray(noise(w, h, blur, seed), np.float32) / 255.0
    lo, hi = np.percentile(n, 2), np.percentile(n, 98)
    n = np.clip((n - lo) / max(1e-4, hi - lo), 0, 1)
    keep = soft > (0.25 + n * 0.5)
    out = arr * keep
    if bites:
        rr = random.Random(seed + 1)
        bm = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(bm)
        edge_pts = np.argwhere((arr > 0.5) & (soft < 0.85))
        for _ in range(bites):
            if len(edge_pts) == 0:
                break
            y, x = edge_pts[rr.randrange(len(edge_pts))]
            r = rr.uniform(0.5, 1.0) * bite_r
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        out = out * (1 - np.asarray(bm, np.float32) / 255.0)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "L")
