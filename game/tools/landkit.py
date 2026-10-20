"""landkit: landmark / prop painting kit for the visual tier (Oct 2026).

Built on celkit (the hangar's anime cel shading, key light top-left) with:
  * 3/4 top-down construction helpers: extrude() a ground footprint into a solid
    (top face + the faces turned toward the camera), vcyl() upright drums / tanks,
    hcyl() a lying cylinder along any axis (fuselages, pipes, logs), plate()
    a thin sheet with a visible edge (wings, slabs, roofs)
  * panel lines + rivet rows, dark seams with lit lips
  * finish(): crisp silhouette, 1 px dark rim, 3-4 tone value snap, worn D+C
    detail at native resolution (grime low down, rust streaks from seams, chipped
    edges, scratches, a few dents; bullet holes only where asked), then a soft
    cool contact shadow baked underneath (offset away from the light).

Everything is rendered large (S px per art unit) and LANCZOS-reduced to the
asset's NATIVE size: one output pixel = one screen pixel in the match
(UnitAnim.TEXEL). Native px for an old world size = 2 x that size.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import celkit  # noqa: E402
from celkit import Canvas, C, cel, ink, hline, fill, soft, glow, SPEC  # noqa: E402,F401
import worn_fx as wf  # noqa: E402

UP = (0.0, -0.55, 0.83)          # a face looking up at the sky (3/4 view)
INK = C(22, 16, 12)


def _centroid(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def extrude(L, foot, h, base, top=None, top_n=UP, ol=2.0, bevel=0.6, side_k=1.0, **kw):
    """A solid: ground footprint `foot` (polygon, art units) raised by `h`.
    Draws the camera-facing side faces then the top face. Returns the top polygon."""
    cx, cy = _centroid(foot)
    n = len(foot)
    faces = []
    for i in range(n):
        a, b = foot[i], foot[(i + 1) % n]
        ex, ey = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(ex, ey) or 1.0
        nx, ny = ey / ln, -ex / ln
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if (mx - cx) * nx + (my - cy) * ny < 0:
            nx, ny = -nx, -ny
        if ny <= 0.02:
            continue
        q = [a, b, (b[0], b[1] - h), (a[0], a[1] - h)]
        faces.append((my, q, (nx * 0.85, 0.32, 0.9)))
    faces.sort(key=lambda f: f[0])
    for _, q, nn in faces:
        cel(L, [("poly", q)], base * side_k, n=nn, ol=ol, bevel=bevel * 0.5, **kw)
    tp = [(p[0], p[1] - h) for p in foot]
    cel(L, [("poly", tp)], top if top is not None else base, n=top_n, ol=ol, bevel=bevel, **kw)
    return tp


def vcyl(L, cx, by, rx, h, base, top=None, cap=True, ol=2.0, **kw):
    """Upright cylinder standing on (cx, by): body + elliptical top."""
    ry = rx * 0.38
    cel(L, [("rect", cx - rx, by - h, cx + rx, by), ("ell", cx, by, rx, ry)], base, form="cylv", ol=ol, bevel=0.8, **kw)
    if cap:
        cel(L, [("ell", cx, by - h, rx, ry)], top if top is not None else base * 1.08, n=UP, ol=ol * 0.8, bevel=0.5, **kw)
    return by - h, ry


def hcyl(L, p0, p1, r0, r1=None, base=None, bands=6, ol=2.0, spec=True, end=True, **kw):
    """A lying cylinder / cone from p0 to p1 (radii r0 -> r1), shaded in bands
    across its axis (cel facets), with an outline and an optional end cap at p0."""
    r1 = r0 if r1 is None else r1
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]
    ln = math.hypot(ax, ay) or 1.0
    ux, uy = ax / ln, ay / ln
    px, py = -uy, ux
    if py < 0:
        px, py = -px, -py           # perp points toward the camera-bottom side
    outline = [(p0[0] - px * r0, p0[1] - py * r0), (p1[0] - px * r1, p1[1] - py * r1),
               (p1[0] + px * r1, p1[1] + py * r1), (p0[0] + px * r0, p0[1] + py * r0)]
    # ink silhouette first (bands draw without their own outline)
    cel(L, [("poly", outline)], base * 0.3, n=(0, 0, 1), ol=ol, bevel=0.0, rim=0)
    edges = np.linspace(-1.0, 1.0, bands + 1)
    for i in range(bands):
        t0, t1 = edges[i], edges[i + 1]
        tm = (t0 + t1) / 2
        q = [(p0[0] + px * r0 * t0, p0[1] + py * r0 * t0), (p1[0] + px * r1 * t0, p1[1] + py * r1 * t0),
             (p1[0] + px * r1 * t1, p1[1] + py * r1 * t1), (p0[0] + px * r0 * t1, p0[1] + py * r0 * t1)]
        # explicit cel ramp across the body: lit crown -> mid -> shadow -> deep belly
        sh = -(tm + 1.0) * 0.5 * 1.02 + (0.06 if tm < -0.5 else 0.0)
        cel(L, [("poly", q)], base, n=(0.0, 0.0, 1.0), shade=sh, ol=0.0, bevel=0.0, rim=0, **kw)
    if spec:
        t = -0.55
        hline(L, [(p0[0] + px * r0 * t + ux * r0 * 0.4, p0[1] + py * r0 * t + uy * r0 * 0.4),
                  (p1[0] + px * r1 * t - ux * r1 * 0.4, p1[1] + py * r1 * t - uy * r1 * 0.4)], 0.22, SPEC, 0.35)
    return (ux, uy), (px, py)


def plate(L, pts, thick, base, top_n=UP, edge_k=0.62, ol=2.0, **kw):
    """A thin sheet (wing, slab, roof panel): top face + the visible lower edge."""
    return extrude(L, pts, thick, base, top=base, top_n=top_n, ol=ol, side_k=edge_k, **kw)


def seam(L, pts, w=0.18, dark=C(26, 20, 16), lip=C(255, 240, 210), a=0.75):
    """Panel seam: dark groove with a thin lit lip below-right of it."""
    ink(L, pts, w, dark, a)
    ink(L, [(x + w * 0.9, y + w * 0.9) for (x, y) in pts], w * 0.6, lip, a * 0.28)


def rivets(L, p0, p1, n, r=0.16, col=C(210, 200, 180)):
    for i in range(n):
        t = (i + 0.5) / n
        x, y = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
        fill(L, [("ell", x + r * 0.5, y + r * 0.5, r, r)], C(20, 14, 10), 0.6)
        fill(L, [("ell", x, y, r, r)], col, 0.7)


def ground_scorch(L, cx, cy, rx, ry, a=0.55):
    soft(L, [("ell", cx, cy, rx, ry)], C(22, 16, 12), a, blur=ry * celkit.g.S * 0.5 + 3)


# ------------------------------------------------------------------ finishing
def _snap_tones(rgb, inside, levels=10):
    """Gentle value snap: pull each pixel's luminance toward a few bands so the
    reduced painting keeps cel-crisp tone steps instead of LANCZOS mush."""
    lum = rgb.mean(axis=2, keepdims=True)
    q = np.round(lum / 255.0 * levels) / levels * 255.0
    k = np.where(lum > 1, q / np.maximum(lum, 1), 1.0)
    out = rgb * (0.6 + 0.4 * k)
    return np.where(inside[..., None], out, rgb)


def finish(im, seed=1, u=1.0, grime=150, streaks=10, wear=120, scratch=20, dents=(), holes=(),
           shadow=None, rim=True, keep_soft=None):
    """Native-res finishing. im: RGBA painting without ground shadow.
    shadow: (cx, cy, rx, ry, alpha) in output px, drawn under the object.
    keep_soft: optional L mask of pixels that stay soft (smoke, glow)."""
    rr = random.Random(seed)
    a = np.asarray(im.getchannel("A"), np.float32)
    rgb = np.asarray(im.convert("RGB"), np.float32)
    inside = a > 110
    if keep_soft is not None:
        soft_m = np.asarray(keep_soft, np.float32) > 20
    else:
        soft_m = np.zeros_like(inside)
    rgb = _snap_tones(rgb, inside & ~soft_m)
    hard = np.where(inside, 255, 0).astype(np.uint8)
    alpha = np.where(soft_m & ~inside, a, hard).astype(np.uint8)
    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(Image.fromarray(alpha))
    m = Image.fromarray(hard)
    if grime:
        out = wf.grime(out, m, amt=int(grime * 0.8), blur=5.0 * u, seed=seed)
    if streaks:
        out = wf.rust_streaks(out, m.filter(ImageFilter.MinFilter(3)), n=streaks, u=u, length=(3, 10), seed=seed + 1, amt=150)
    if wear:
        out = wf.edge_wear(out, m, amt=wear, u=u, seed=seed + 2)
    if scratch:
        out = wf.scratches(out, m, n=scratch, u=u, length=(2, 6), seed=seed + 3, amt=70)
    for (x, y, r) in dents:
        out = wf.dent(out, m, x, y, r, amt=90)
    for (x, y, r) in holes:
        out = wf.bullet_hole(out, m, x, y, r, seed=rr.randint(0, 999))
    out = out.filter(ImageFilter.UnsharpMask(radius=0.7, percent=45, threshold=1))
    if rim:
        # 1 px dark rim outside the silhouette (units' crisp-pass look)
        ring = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(3)), m)
        rim_l = Image.new("RGBA", out.size, (20, 14, 10, 0))
        rim_l.putalpha(ring.point(lambda v: 235 if v > 0 else 0))
        out = Image.alpha_composite(rim_l, out)
    if shadow is not None:
        cx, cy, rx, ry, sa = shadow
        sh = Image.new("L", out.size, 0)
        ImageDraw.Draw(sh).ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=int(255 * sa))
        sh = sh.filter(ImageFilter.GaussianBlur(max(2.0, ry * 0.45)))
        core = Image.new("L", out.size, 0)
        ImageDraw.Draw(core).ellipse((cx - rx * 0.8, cy - ry * 0.45, cx + rx * 0.8, cy + ry * 0.45), fill=int(255 * sa * 0.5))
        core = core.filter(ImageFilter.GaussianBlur(2.0))
        sl = Image.new("RGBA", out.size, (12, 10, 20, 0))
        sl.putalpha(ImageChops.add(sh, core))
        out = Image.alpha_composite(sl, out)
    return out


def render(cv, px, py=None):
    """Canvas -> image at native px (LANCZOS), no sharpening (finish() does it)."""
    im = cv.image()
    py = py or int(round(px * cv.h / cv.w))
    return im.resize((px, py), Image.LANCZOS)


def pad_canvas(im, pad):
    out = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    out.alpha_composite(im, (pad, pad))
    return out
