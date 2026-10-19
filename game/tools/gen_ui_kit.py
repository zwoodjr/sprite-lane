"""Painted scrap-metal UI kit for Wanderer (9-slice plates, buttons, caps,
bars, tile frames), the WANDERER logo and the painted menu backdrop.

Look (locked Oct 2026, matches the smashed amber HP readout): near-black dented
steel plates with chewed edges, rust, grime, a few bullet holes and bead welds
in the corners; buttons are dark worn metal lit by an amber / green / red
phosphor stroke. Wear in the 9-slice edge bands and centre uses noise that is
periodic over the centre tile, so tiled/stretched plates never show seams; the
one-off damage (holes, dents, welds) lives in the corner squares only.
Item rarity frames and the ability / dash / pause bottle caps get the same wear
from their pristine sources in tools/art_src/.

usage: python3 tools/gen_ui_kit.py          (run from game/)
Writes assets/sprites/ui/kit/*.png, assets/sprites/ui/logo_wanderer.png,
assets/sprites/ui/menu_backdrop.png
"""
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage as ndi

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import worn_fx as WF  # noqa: E402

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = "assets/sprites/ui/kit"
FONT_XB = "assets/fonts/BarlowCondensed-ExtraBold.ttf"
os.makedirs(OUT, exist_ok=True)

SEAM = np.array([22, 16, 12], np.float32)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5).astype(np.float32)
RNG = np.random.default_rng(7)


def bayer(h, w):
    return np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]


def periodic_noise(h, w, sigma, seed):
    r = np.random.default_rng(seed).random((h, w)).astype(np.float32)
    n = ndi.gaussian_filter(r, sigma, mode="wrap")
    n -= n.min()
    n /= max(1e-6, n.max())
    return n * 2.0 - 1.0


def rrect_sdf(h, w, x0, y0, x1, y1, r):
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx = np.abs(xx - cx) - hx
    qy = np.abs(yy - cy) - hy
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0)
    return out + inside - r


def cov(sdf, edge=0.0):
    return np.clip(0.5 - (sdf - edge), 0, 1)


def lerp(a, b, t):
    return a + (b - a) * t[..., None]


def quant(rgb, levels=6.0, amt=1.0):
    """Ordered-dither the colour toward a coarse ramp: painted-pixel grit."""
    h, w, _ = rgb.shape
    b = bayer(h, w)[..., None]
    step = 255.0 / (levels * 6)
    return np.round((rgb + b * step * amt) / step) * step


def sdf_normal(sdf):
    gy, gx = np.gradient(sdf)
    n = np.sqrt(gx * gx + gy * gy) + 1e-6
    return gx / n, gy / n


def plate(w, h, radius, rim, face_top, face_bot, rim_hi, rim_lo, rivets=True, inset=False,
          margin=24, seed=1, grit=14.0, scratches=6, bolt_col=None, glow=None, accent=None, accent_a=1.0):
    """A riveted metal plate. Returns RGBA uint8 (h, w, 4)."""
    face_top = np.array(face_top, np.float32); face_bot = np.array(face_bot, np.float32)
    rim_hi = np.array(rim_hi, np.float32); rim_lo = np.array(rim_lo, np.float32)
    pad = 2 if glow is None else 6
    sdf = rrect_sdf(h, w, pad, pad, w - pad, h - pad, radius)
    nx, ny = sdf_normal(sdf)
    # light from top-left: outward normal pointing up-left is lit
    lit = np.clip((-nx - ny) * 0.7071, -1, 1)
    img = np.zeros((h, w, 3), np.float32)
    # rim
    t = (lit * 0.5 + 0.5)
    if inset:
        t = 1.0 - t
    rimc = lerp(rim_lo, rim_hi, t)
    img[:] = rimc
    # bevel highlight line on the outermost lit edge
    edge_band = (sdf > -3.0) & (sdf < -1.0)
    hl = np.clip(lit, 0, 1) * edge_band
    img += (hl[..., None] * 60.0) * (-1 if inset else 1)
    # face
    cw, ch = max(4, w - 2 * margin), max(4, h - 2 * margin)
    tile = periodic_noise(ch, cw, 1.2, seed) * 0.6 + periodic_noise(ch, cw, 4.0, seed + 1) * 0.4
    yy, xx = np.mgrid[0:h, 0:w]
    noise = tile[(yy - margin) % ch, (xx - margin) % cw]
    vt = np.clip((yy - rim) / max(1, h - 2 * rim), 0, 1).astype(np.float32)
    face = lerp(face_top, face_bot, vt)
    face += noise[..., None] * grit
    # brushed streaks (horizontal)
    streak = periodic_noise(ch, 1, 0.8, seed + 2)[:, 0]
    face += (streak[(yy - margin) % ch][..., None] * grit * 0.35)
    inner = sdf + rim
    face_mask = cov(inner, 0.0)
    img = lerp(img, face, face_mask)
    # inner seam + inner shadow on the face top-left (recessed face reads as a panel)
    seam_band = np.exp(-((inner + 0.2) ** 2) / 0.9)
    img = lerp(img, SEAM, np.clip(seam_band, 0, 1) * 0.85)
    ishadow = np.clip(1.0 - (-inner) / 6.0, 0, 1) * face_mask * np.clip(-lit * 0.6 + 0.4, 0, 1)
    if not inset:
        img = lerp(img, img * 0.55, ishadow * 0.6)
    else:
        img = lerp(img, img * 0.45, np.clip(1.0 - (-inner) / 9.0, 0, 1) * face_mask)
    # scratches on the face
    sc = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(sc)
    rr = np.random.default_rng(seed + 9)
    for _ in range(scratches):
        x = rr.uniform(margin * 0.6, w - margin * 0.6); y = rr.uniform(rim + 4, h - rim - 4)
        L = rr.uniform(4, 12); a = rr.uniform(-0.5, 0.5)
        d.line([(x, y), (x + L * np.cos(a), y + L * np.sin(a))], fill=int(rr.uniform(90, 160)), width=1)
    scm = np.array(sc, np.float32) / 255.0 * face_mask
    img = lerp(img, img + 38.0, scm)
    # rivets
    if rivets:
        rc = np.array(bolt_col if bolt_col is not None else rim_hi * 0.85, np.float32)
        off = pad + rim * 0.5 + max(2.0, radius * 0.25)
        for (cx, cy) in [(off, off), (w - off, off), (off, h - off), (w - off, h - off)]:
            dd = np.sqrt((xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2)
            rr_ = max(2.2, rim * 0.42)
            m = np.clip(rr_ + 0.5 - dd, 0, 1)
            # sphere shading
            sx = (xx + 0.5 - cx) / rr_; sy = (yy + 0.5 - cy) / rr_
            sh = np.clip(-(sx + sy) * 0.55 + 0.25, -0.8, 1.0)
            col = rc[None, None, :] * (1.0 + sh[..., None] * 0.55)
            ring = np.clip(rr_ + 1.4 - dd, 0, 1) - m
            img = lerp(img, SEAM, np.clip(ring, 0, 1) * 0.8)
            img = lerp(img, col, m)
    if accent is not None:
        # phosphor stroke just inside the rim + its glow onto the face and rim
        ac = np.array(accent, np.float32)
        line = np.exp(-((inner + 1.4) ** 2) / 1.1)
        halo = np.exp(-((inner + 1.4) ** 2) / 14.0) * 0.45
        k = np.clip(line + halo, 0, 1) * accent_a
        img = img * (1 - k[..., None]) + np.maximum(img, ac * (0.55 + 0.45 * line[..., None])) * k[..., None]
    img = quant(img, 7.0, 1.0)
    img = np.clip(img, 0, 255)
    alpha = cov(sdf, 0.0)
    # outer dark seam
    oseam = np.clip(cov(sdf, 0.0) - cov(sdf, -1.6), 0, 1)
    img = lerp(img, SEAM, oseam)
    out = np.dstack([img, alpha * 255.0])
    if glow is not None:
        g = np.array(glow, np.float32)
        ga = np.clip(1.0 - np.maximum(sdf, 0) / pad, 0, 1) ** 2 * (sdf > 0) * 200.0
        gl = np.dstack([np.broadcast_to(g, (h, w, 3)), ga])
        a1 = out[..., 3:4] / 255.0
        out = np.concatenate([out[..., :3] * a1 + gl[..., :3] * (1 - a1), np.maximum(out[..., 3:4], gl[..., 3:4])], axis=2)
    return np.clip(out, 0, 255).astype(np.uint8)


def save(a, name):
    Image.fromarray(a, "RGBA").save(os.path.join(OUT, name))


# --- worn pass ------------------------------------------------------------------
def tiled_noise(h, w, margin, sigma, seed):
    """Noise that repeats with the 9-slice centre period (seamless when tiled)."""
    ch, cw = max(4, h - 2 * margin), max(4, w - 2 * margin)
    t = periodic_noise(ch, cw, sigma, seed) * 0.5 + 0.5
    yy, xx = np.mgrid[0:h, 0:w]
    return t[(yy - margin) % ch, (xx - margin) % cw]


def wear_plate(a, margin, seed, rust=0.45, grime=0.55, holes=1, dents=1, welds=1, chew=1.0, edge_grime=False):
    """Worn post-pass for a 9-slice plate (uint8 RGBA). Seamless outside the corners."""
    h, w = a.shape[:2]
    rr = random.Random(seed)
    img = a[..., :3].astype(np.float32)
    al = a[..., 3].astype(np.float32) / 255.0
    inside = al > 0.5
    dist = ndi.distance_transform_edt(inside)  # perpendicular in the bands -> seamless
    # grime: dark blotches, heavier toward the edge
    n1 = tiled_noise(h, w, margin, 2.2, seed + 1)
    fall = np.exp(-dist / 7.0) if edge_grime else (0.55 + 0.45 * np.exp(-dist / 10.0))
    g = np.clip((n1 - 0.45) * 2.4, 0, 1) * grime * fall
    img = img * (1 - g[..., None] * 0.6)
    # rust: patchy, concentrated along the rim
    n2 = tiled_noise(h, w, margin, 1.6, seed + 2)
    n3 = tiled_noise(h, w, margin, 0.6, seed + 3)
    rv = np.clip((n2 - (1 - rust * 0.62)) * 5 + (n3 - 0.5) * 0.6, 0, 1) * np.exp(-dist / 7.0)
    rc = np.dstack([88 + 46 * n3, 40 + 24 * n3, 18 + 10 * n3])
    img = img * (1 - rv[..., None] * 0.85) + rc * rv[..., None] * 0.85
    pit = (n3 > 0.8) & (rv > 0.3)
    img[pit] *= 0.45
    # edge chips (bare steel catching light) on the outer edge
    n4 = tiled_noise(h, w, margin, 1.4, seed + 4)
    chip = ((dist > 1.5) & (dist < 3.0) & (n4 > 0.8)).astype(np.float32)
    img = img * (1 - chip[..., None] * 0.4) + np.array([132, 124, 110], np.float32) * chip[..., None] * 0.4
    # chewed silhouette: sparse irregular bites out of the outer edge
    if chew > 0:
        n5 = tiled_noise(h, w, margin, 2.0, seed + 5)
        n6 = tiled_noise(h, w, margin, 0.7, seed + 6)
        depth = np.clip((n5 - 0.6) * 9.0, 0, 1) * 3.5 * chew + (n6 > 0.75) * 0.9
        bite = dist < depth
        al = np.where(bite, 0.0, al)
        # the torn edge is darker (no bevel highlight left)
        torn = (dist < depth + 1.6) & ~bite & (depth > 0.5)
        img[torn] *= 0.55
    out = np.dstack([np.clip(img, 0, 255), al * 255]).astype(np.uint8)
    im = Image.fromarray(out, "RGBA")
    # one-off damage, inside the corner squares only (they are never tiled)
    m = Image.fromarray((inside * 255).astype(np.uint8), "L")
    corners = [(margin * 0.5, margin * 0.5), (w - margin * 0.5, margin * 0.5),
               (margin * 0.5, h - margin * 0.5), (w - margin * 0.5, h - margin * 0.5)]
    rr.shuffle(corners)
    k = 0
    for _ in range(holes):
        x, y = corners[k % 4]; k += 1
        im = WF.bullet_hole(im, m, x + rr.uniform(-2, 2), y + rr.uniform(-2, 2), max(1.8, margin * 0.085),
                            rr.randrange(999), petal=(96, 90, 80))
    for _ in range(dents):
        x, y = corners[k % 4]; k += 1
        im = WF.dent(im, m, x, y, margin * 0.32, 90)
    for _ in range(welds):  # short bead weld across a corner (a cracked plate welded up)
        x, y = corners[k % 4]; k += 1
        d = ImageDraw.Draw(im)
        a0 = rr.uniform(0, 6.28)
        L = margin * 0.38
        pts = [(x + np.cos(a0) * L * t, y + np.sin(a0) * L * t) for t in np.linspace(-1, 1, 7)]
        r = max(1.1, margin * 0.05)
        for (px, py) in pts:
            d.ellipse((px - r, py - r, px + r, py + r), fill=(96, 86, 72, 255), outline=(26, 21, 17, 255))
        for (px, py) in pts:
            d.point((px - r * 0.3, py - r * 0.4), fill=(160, 148, 124, 255))
    out = np.array(im)
    out[..., 3] = np.minimum(out[..., 3], (al * 255).astype(np.uint8))
    return out


def wear_icon(im, seed, dark=0.8, sat=0.72, rust=0.3, chew=0.0, dent=True, cracks=False, scratch_rim_only=False):
    """Same wear for round caps / item frames (keeps the silhouette and hue identity)."""
    rr = random.Random(seed)
    a0 = im.getchannel("A")
    m = a0.point(lambda v: 255 if v > 160 else 0)
    w, h = im.size
    u = max(1.0, w / 48.0)
    out = WF.grade(im, dark, sat, (1.0, 0.94, 0.86), 1.08)
    rim = ImageChops_sub(m, m.filter(ImageFilter.MinFilter(int(max(3, w * 0.12)) | 1)))
    out = WF.rust_patches(out, rim, rust, u * 0.9, seed + 1, alpha=210)
    out = WF.rust_patches(out, m, rust * 0.35, u * 1.2, seed + 2, alpha=150)
    out = WF.grime(out, m, 170, (12, 9, 6), u * 1.5, seed + 3)
    out = WF.edge_wear(out, m, 120, u, seed + 4)
    out = WF.scratches(out, rim if scratch_rim_only else m, max(4, w // 10), u, (2, 6), seed + 5, amt=80)
    if dent:
        x, y = rr.uniform(0.3, 0.7) * w, rr.uniform(0.25, 0.45) * h
        out = WF.dent(out, m, x, y, w * 0.12, 80)
    if cracks:
        out = WF.cracks(out, w * rr.uniform(0.6, 0.75), h * rr.uniform(0.25, 0.4), 4, w * 0.35,
                        (230, 228, 215, 150), max(1, int(u * 0.5)), seed + 6, clip=m)
    a = a0
    if chew > 0:
        a = Image.fromarray(np.minimum(np.asarray(a0), np.asarray(WF.chew_alpha(a0, chew, 0.8, seed + 7)) * 0 + np.asarray(
            WF.chew_alpha(a0, chew, 0.8, seed + 7))), "L")
    out.putalpha(a)
    return out


def ImageChops_sub(a, b):
    from PIL import ImageChops
    return ImageChops.subtract(a, b)


def save_worn(a, name, margin, seed, **kw):
    save(wear_plate(a, margin, seed, **kw), name)


# --- palettes -----------------------------------------------------------------
IRON_T, IRON_B = (58, 45, 36), (36, 28, 22)
BRASS_HI, BRASS_LO = (226, 180, 104), (96, 64, 34)
STEEL_HI, STEEL_LO = (170, 160, 150), (62, 56, 52)
DARK_HI, DARK_LO = (104, 98, 90), (22, 20, 19)  # near-black dented steel rim
BOLT = (92, 86, 78)
PHOS_AMBER = (236, 150, 46)
PHOS_GREEN = (120, 214, 128)
PHOS_RED = (226, 84, 52)

BUTTONS = {
    # name: (face_top, face_bot, rim_hi, rim_lo, accent)
    "amber": ((66, 48, 28), (36, 26, 16), (128, 104, 74), (26, 20, 14), PHOS_AMBER),
    "teal": ((40, 52, 42), (22, 30, 25), (96, 116, 100), (18, 24, 20), PHOS_GREEN),
    "rust": ((66, 36, 27), (36, 20, 15), (124, 84, 66), (26, 16, 12), PHOS_RED),
    "steel": ((58, 54, 50), (34, 32, 30), (122, 116, 106), (24, 22, 21), (150, 136, 112)),
    "neutral": ((150, 148, 144), (100, 98, 96), (220, 216, 210), (60, 58, 56), (236, 232, 224)),
}


def build_kit():
    # Panels (96px, 28px margins, rivets in the corners). Faces are flat: the centre tiles.
    save_worn(plate(96, 96, 10, 7, (30, 27, 25), (30, 27, 25), DARK_HI, DARK_LO, margin=28, seed=3, grit=7,
                    scratches=0, bolt_col=BOLT), "panel.png", 28, 103, holes=1, dents=1, welds=1)
    save_worn(plate(96, 96, 10, 7, (38, 32, 27), (38, 32, 27), (130, 112, 88), (30, 24, 18), margin=28, seed=4, grit=7,
                    scratches=0, bolt_col=BOLT, accent=PHOS_AMBER, accent_a=0.55), "panel_hi.png", 28, 104,
              holes=1, dents=1, welds=1)
    save_worn(plate(64, 64, 8, 4, (14, 11, 9), (14, 11, 9), (90, 86, 80), (18, 16, 15), rivets=False, inset=True,
                    margin=18, seed=5, grit=5, scratches=0), "inset.png", 18, 105, rust=0.3, holes=0, dents=0,
              welds=0, chew=0.6)
    save_worn(plate(96, 96, 10, 7, (24, 23, 23), (24, 23, 23), (96, 98, 100), (20, 20, 22), margin=28, seed=6, grit=7,
                    scratches=0, bolt_col=BOLT), "panel_steel.png", 28, 106, holes=1, dents=1, welds=0)
    # Slim HUD plate: thin brass rim, small rivets, see-through smoky face (HUD: unchanged).
    hud = plate(48, 48, 8, 3, (26, 20, 16), (26, 20, 16), BRASS_HI, BRASS_LO, margin=14, seed=8, grit=5, scratches=0)
    sdf = rrect_sdf(48, 48, 2, 2, 46, 46, 8)
    face = sdf < -5
    hud[..., 3] = np.where(face, (hud[..., 3] * 0.8).astype(np.uint8), hud[..., 3])
    save(hud, "hud.png")
    # Buttons (normal / hover / pressed / disabled): dark worn metal + phosphor stroke
    for i, (name, (ft, fb, rh, rl, ac)) in enumerate(BUTTONS.items()):
        ft, fb, rh, rl, ac = [np.array(c, np.float32) for c in (ft, fb, rh, rl, ac)]
        sd = 200 + i * 10
        save_worn(plate(80, 64, 10, 5, ft, fb, rh, rl, margin=22, seed=11, grit=8, scratches=0, bolt_col=BOLT,
                        accent=ac, accent_a=0.85), "btn_%s.png" % name, 22, sd, rust=0.35, holes=1, dents=0, welds=0,
                  edge_grime=True)
        save_worn(plate(80, 64, 10, 5, ft * 1.25 + 8, fb * 1.2 + 6, rh * 1.1, rl, margin=22, seed=11, grit=8,
                        scratches=0, bolt_col=BOLT, accent=np.minimum(255, ac * 1.12 + 12), accent_a=1.0),
                  "btn_%s_hover.png" % name, 22, sd, rust=0.35, holes=1, dents=0, welds=0, edge_grime=True)
        save_worn(plate(80, 64, 10, 5, fb * 0.8, ft * 0.75, rl * 1.6, rh * 0.7, margin=22, seed=11, grit=8,
                        scratches=0, inset=True, accent=ac * 0.8, accent_a=0.6), "btn_%s_pressed.png" % name, 22,
                  sd, rust=0.35, holes=1, dents=0, welds=0, edge_grime=True)
    g = np.array([60, 56, 52], np.float32)
    save_worn(plate(80, 64, 10, 5, g * 0.62, g * 0.45, g * 1.2, g * 0.35, margin=22, seed=11, grit=6, scratches=0,
                    bolt_col=BOLT), "btn_disabled.png", 22, 260, rust=0.55, grime=0.8, holes=1, dents=1, welds=0)
    # Tile frames (roster / pet / slot tiles)
    save_worn(plate(72, 72, 8, 5, (32, 29, 26), (22, 20, 18), DARK_HI, DARK_LO, margin=20, seed=21, grit=6,
                    scratches=0, bolt_col=BOLT), "tile.png", 20, 121, rust=0.4, holes=0, dents=1, welds=0)
    save_worn(plate(84, 84, 8, 6, (44, 34, 24), (28, 22, 16), (150, 116, 70), (40, 28, 16), margin=26, seed=21,
                    grit=6, scratches=0, glow=(236, 150, 46), bolt_col=BOLT, accent=PHOS_AMBER, accent_a=0.9),
              "tile_on.png", 26, 122, rust=0.3, holes=0, dents=0, welds=0, chew=0.0)
    # Progress bar groove + fill (fill is neutral: tinted per use) — HUD bars: unchanged
    save(plate(48, 24, 7, 3, (16, 12, 10), (24, 19, 15), STEEL_HI, STEEL_LO, rivets=False, inset=True, margin=10, seed=31, grit=4, scratches=0), "bar_bg.png")
    bar = np.zeros((20, 32, 4), np.float32)
    yy = np.mgrid[0:20, 0:32][0].astype(np.float32)
    v = 1.0 - np.abs((yy - 6) / 14.0)
    col = 150 + 105 * np.clip(v, 0, 1)
    bar[..., 0] = col; bar[..., 1] = col; bar[..., 2] = col
    bar[2:4, :, :3] = 255
    bar[-3:, :, :3] *= 0.6
    bar[..., :3] = quant(bar[..., :3], 6.0, 1.0)
    bar[..., 3] = 255
    sdf = rrect_sdf(20, 32, 0, 0, 32, 20, 6)
    bar[..., 3] = cov(sdf) * 255
    Image.fromarray(np.clip(bar, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "bar_fill.png"))
    build_caps()
    build_divider()
    build_hud_bits()
    build_worn_icons()


def build_worn_icons():
    """Rarity frames + ability/dash/pause caps from their pristine sources."""
    src = "tools/art_src"
    for i, r in enumerate(("common", "rare", "epic", "legendary")):
        im = Image.open(os.path.join(src, "frames", "frame_%s.png" % r)).convert("RGBA")
        wear_icon(im, 400 + i, dark=0.85, sat=0.8, rust=0.35, chew=0.0, dent=False, scratch_rim_only=True).save(
            "assets/sprites/icons/frames/frame_%s.png" % r)
    for i, f in enumerate(sorted(os.listdir(os.path.join(src, "ui")))):
        if not f.endswith(".png"):
            continue
        im = Image.open(os.path.join(src, "ui", f)).convert("RGBA")
        wear_icon(im, 500 + i, dark=0.78, sat=0.7, rust=0.4, dent=True, cracks=(i % 3 == 0)).save(
            os.path.join("assets/sprites/ui", f))


def cap(size, face, rim_dark, glyph, seed=0):
    """Bottle cap button (round, crimped edge) with a glyph."""
    S = size * 4
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
    c = S / 2
    dx, dy = xx - c, yy - c
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    crimp = c * 0.94 + np.cos(ang * 21) * c * 0.04
    body = r < crimp
    face_r = c * 0.74
    img = np.zeros((S, S, 4), np.float32)
    face = np.array(face, np.float32)
    rimc = np.array(rim_dark, np.float32)
    lit = np.clip(-(dx + dy) / (r + 1e-3) * 0.7071, -1, 1)
    edge = rimc[None, None] * (1.0 + lit[..., None] * 0.6) + 20
    img[..., :3] = edge
    infc = (r < face_r)
    fshade = 1.0 + np.clip(-(dx + dy) / (c * 1.6), -0.4, 0.4)[..., None]
    img[..., :3] = np.where(infc[..., None], face[None, None] * fshade, img[..., :3])
    ring = np.abs(r - face_r) < S * 0.012
    img[..., :3] = np.where(ring[..., None], SEAM, img[..., :3])
    hl = (np.abs(r - face_r * 0.9) < S * 0.01) & (lit > 0.4)
    img[..., :3] = np.where(hl[..., None], np.minimum(255, face * 1.5 + 40), img[..., :3])
    outer = (r > crimp - S * 0.018) & body
    img[..., :3] = np.where(outer[..., None], SEAM, img[..., :3])
    img[..., 3] = body * 255.0
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    s = size
    g = (246, 236, 214, 255)
    if glyph == "back":
        d.line([(s * 0.56, s * 0.32), (s * 0.40, s * 0.5), (s * 0.56, s * 0.68)], fill=(24, 18, 14, 255), width=max(3, int(s * 0.13)))
        d.line([(s * 0.56, s * 0.30), (s * 0.40, s * 0.48), (s * 0.56, s * 0.66)], fill=g, width=max(2, int(s * 0.09)))
    elif glyph == "close":
        for o, col, wd in [(2, (24, 18, 14, 255), 0.13), (0, g, 0.09)]:
            d.line([(s * 0.36, s * 0.36 + o), (s * 0.64, s * 0.64 + o)], fill=col, width=max(2, int(s * wd)))
            d.line([(s * 0.64, s * 0.36 + o), (s * 0.36, s * 0.64 + o)], fill=col, width=max(2, int(s * wd)))
    a = np.array(im).astype(np.float32)
    a[..., :3] = quant(a[..., :3], 7.0, 0.8)
    return np.clip(a, 0, 255).astype(np.uint8)


def build_caps():
    for k, (sz, face, rim, glyph, name) in enumerate([(96, (70, 66, 62), (52, 48, 46), "back", "cap_back"),
                                                      (96, (150, 62, 40), (80, 36, 24), "close", "cap_close"),
                                                      (96, (200, 136, 50), (100, 64, 28), "none", "cap_amber"),
                                                      (36, (200, 136, 50), (100, 64, 28), "none", "cap_grab")]):
        im = Image.fromarray(cap(sz, face, rim, glyph), "RGBA")
        wear_icon(im, 300 + k, dark=0.9, sat=0.8, rust=0.4, dent=sz > 40).save(os.path.join(OUT, name + ".png"))


def ring(size, r_out, r_in, hi, lo, rivets=0, face=None, face_alpha=0.0, ticks=False, seed=0):
    """Round brass bezel (light top-left), optional smoky glass face + rivets."""
    S = size * 4
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) + 0.5
    c = S / 2
    dx, dy = xx - c, yy - c
    r = np.sqrt(dx * dx + dy * dy) / 4.0
    lit = np.clip(-(dx + dy) / (np.sqrt(dx * dx + dy * dy) + 1e-3) * 0.7071, -1, 1)
    img = np.zeros((S, S, 4), np.float32)
    band = (r <= r_out) & (r >= r_in)
    mid = (r_out + r_in) / 2
    bev = np.clip(1.0 - np.abs(r - mid) / ((r_out - r_in) / 2 + 1e-3), 0, 1)
    t = np.clip(lit * 0.5 + 0.5, 0, 1) * (0.6 + 0.4 * bev)
    col = lerp(np.array(lo, np.float32), np.array(hi, np.float32), t)
    img[..., :3] = col
    img[..., 3] = band * 255.0
    seam = (np.abs(r - r_out) < 0.9) | (np.abs(r - r_in) < 0.9)
    img[seam] = [22, 16, 12, 255]
    if face is not None:
        fm = r < r_in - 0.5
        img[fm, :3] = np.array(face, np.float32)
        img[fm, 3] = face_alpha * 255
        # glass glint top-left
        g = fm & (np.abs(r - r_in * 0.78) < 1.2) & (lit > 0.55)
        img[g, :3] = [255, 240, 210]; img[g, 3] = 90
    if ticks:
        for k in range(12):
            a = k / 12 * np.pi * 2
            px, py = c + np.cos(a) * mid * 4, c + np.sin(a) * mid * 4
            m = (np.sqrt((xx - px) ** 2 + (yy - py) ** 2) < (2.2 if k % 3 == 0 else 1.4) * 4)
            img[m] = [40, 28, 18, 255]
    if rivets:
        for k in range(rivets):
            a = k / rivets * np.pi * 2 + np.pi / 4
            px, py = c + np.cos(a) * mid * 4, c + np.sin(a) * mid * 4
            d = np.sqrt((xx - px) ** 2 + (yy - py) ** 2) / 4.0
            rr = (r_out - r_in) * 0.28
            m = d < rr
            sh = np.clip(-((xx - px) + (yy - py)) / (rr * 4) * 0.6 + 0.3, -0.6, 1)
            img[m, :3] = (np.array(hi, np.float32)[None] * (0.8 + sh[m][:, None] * 0.5))
            img[m, 3] = 255
            img[(d >= rr) & (d < rr + 0.8)] = [22, 16, 12, 255]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
    a = np.array(im).astype(np.float32)
    a[..., :3] = quant(a[..., :3], 7.0, 0.8)
    return np.clip(a, 0, 255).astype(np.uint8)


def build_hud_bits():
    save(ring(256, 124, 112, (226, 196, 150), (90, 70, 50), rivets=8, face=(16, 12, 10), face_alpha=0.28), "stick_base.png")
    knob = cap(128, (120, 110, 100), (70, 64, 60), "none")
    save(knob, "stick_knob.png")
    save(ring(192, 95, 82, BRASS_HI, BRASS_LO, rivets=4, face=(30, 22, 16), face_alpha=0.72, ticks=True), "minimap_bezel.png")
    # extract arrow: brass chevron with an amber core, points up
    S = 256
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(128, 20), (224, 170), (170, 150), (128, 236), (86, 150), (32, 170)]
    pts = [(128, 18), (228, 196), (128, 150), (28, 196)]
    d.polygon(pts, fill=(22, 16, 12, 255))
    inner = [(128, 44), (200, 178), (128, 140), (56, 178)]
    d.polygon(inner, fill=(236, 170, 70, 255))
    hl = [(128, 44), (56, 178), (128, 140)]
    d.polygon(hl, fill=(255, 220, 140, 255))
    core = [(128, 84), (160, 150), (128, 132), (96, 150)]
    d.polygon(core, fill=(150, 76, 26, 255))
    im = im.resize((64, 64), Image.LANCZOS)
    a = np.array(im).astype(np.float32)
    a[..., :3] = quant(a[..., :3], 7.0, 0.8)
    save(np.clip(a, 0, 255).astype(np.uint8), "extract_arrow.png")


def build_divider():
    w, h = 64, 10
    a = np.zeros((h, w, 4), np.float32)
    a[3:7, :, :3] = np.array(BRASS_LO, np.float32)
    a[3, :, :3] = np.array(BRASS_HI, np.float32)
    a[6, :, :3] = np.array(SEAM, np.float32)
    a[2:8, :, 3] = 255
    a[2, :, :3] = SEAM; a[7, :, :3] = SEAM
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "divider.png"))


# --- logo -------------------------------------------------------------------
def build_logo():
    text = "WANDERER"
    fs = 190
    font = ImageFont.truetype(FONT_XB, fs)
    bb = font.getbbox(text)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    pad = 40
    W, H = tw + pad * 2, th + pad * 2 + 20
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).text((pad - bb[0], pad - bb[1]), text, font=font, fill=255)
    mask = np.array(m, np.float32) / 255.0
    # bevel via distance inside the letters
    inside = ndi.distance_transform_edt(mask > 0.5)
    hgt = ndi.gaussian_filter(np.clip(inside, 0, 7) / 7.0, 1.0)
    gy, gx = np.gradient(hgt)
    lit = np.clip((-gx - gy) * 6.0, -1, 1)
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    t = np.clip((yy - pad) / th, 0, 1)
    top = np.array([255, 226, 140], np.float32)
    mid = np.array([236, 158, 60], np.float32)
    bot = np.array([150, 66, 28], np.float32)
    col = np.where(t[..., None] < 0.5, lerp(top, mid, t * 2), lerp(mid, bot, (t - 0.5) * 2))
    col = col * (1.0 + lit[..., None] * 0.35)
    # grime / rust speckle
    n = periodic_noise(H, W, 1.5, 77)
    n2 = periodic_noise(H, W, 6.0, 78)
    col += n[..., None] * 18
    rust = (n2 > 0.45) & (t > 0.3)
    col = np.where(rust[..., None], col * np.array([0.72, 0.5, 0.36]), col)
    # horizontal plate seam across letters
    seam_y = pad + int(th * 0.56)
    col[seam_y:seam_y + 2] *= 0.45
    col[seam_y + 2:seam_y + 3] *= 1.25
    # top highlight line
    edge_top = (mask > 0.5) & (np.roll(mask, 3, axis=0) < 0.5)
    col = np.where(edge_top[..., None], np.minimum(255, col * 1.35 + 30), col)
    col = quant(col, 7.0, 1.0)
    # outline (dark seam) + drop shadow
    out_m = ndi.binary_dilation(mask > 0.5, iterations=7)
    shadow = np.roll(np.roll(out_m, 9, axis=0), 5, axis=1)
    img = np.zeros((H, W, 4), np.float32)
    img[shadow] = [10, 6, 4, 150]
    img[out_m] = [24, 16, 11, 255]
    ring = out_m & ~ndi.binary_erosion(out_m, iterations=2)
    img[ring] = [56, 38, 24, 255]
    a = mask[..., None]
    img[..., :3] = img[..., :3] * (1 - a) + col * a
    img[..., 3] = np.maximum(img[..., 3], a[..., 0] * 255)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save("assets/sprites/ui/logo_wanderer.png")


# --- backdrop -------------------------------------------------------------------
def silhouette_layer(W, H, base, amp, freq, seed, props=()):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    rr = np.random.default_rng(seed)
    ph = rr.uniform(0, 6)
    pts = []
    for x in range(0, W + 8, 8):
        y = base + np.sin(x * freq + ph) * amp + np.sin(x * freq * 2.7 + ph * 2) * amp * 0.35
        pts.append((x, y))
    pts += [(W, H), (0, H)]
    d.polygon(pts, fill=255)
    for kind, x, s in props:
        y = base + np.sin(x * freq + ph) * amp + np.sin(x * freq * 2.7 + ph * 2) * amp * 0.35
        if kind == "tower":
            d.polygon([(x - 10 * s, y), (x - 3 * s, y - 120 * s), (x + 3 * s, y - 120 * s), (x + 10 * s, y)], fill=255)
            for k in range(5):
                yy = y - 22 * s * k
                d.line([(x - 9 * s + k * 1.2 * s, yy), (x + 9 * s - k * 1.2 * s, yy - 20 * s)], fill=255, width=max(1, int(2 * s)))
            d.line([(x, y - 120 * s), (x, y - 150 * s)], fill=255, width=max(1, int(2 * s)))
        elif kind == "bus":
            d.rounded_rectangle([x - 70 * s, y - 34 * s, x + 70 * s, y + 4], radius=int(6 * s), fill=255)
            d.polygon([(x - 70 * s, y - 34 * s), (x - 62 * s, y - 44 * s), (x + 20 * s, y - 40 * s), (x + 30 * s, y - 34 * s)], fill=255)
        elif kind == "car":
            d.rounded_rectangle([x - 34 * s, y - 16 * s, x + 34 * s, y + 4], radius=int(5 * s), fill=255)
            d.polygon([(x - 18 * s, y - 16 * s), (x - 10 * s, y - 30 * s), (x + 14 * s, y - 30 * s), (x + 22 * s, y - 16 * s)], fill=255)
        elif kind == "pole":
            d.line([(x, y), (x + 14 * s, y - 90 * s)], fill=255, width=max(2, int(4 * s)))
            d.line([(x - 10 * s, y - 70 * s), (x + 30 * s, y - 80 * s)], fill=255, width=max(1, int(3 * s)))
        elif kind == "rock":
            d.polygon([(x - 40 * s, y + 4), (x - 26 * s, y - 50 * s), (x + 4 * s, y - 64 * s), (x + 36 * s, y - 30 * s), (x + 46 * s, y + 4)], fill=255)
    return np.array(m, np.float32) / 255.0


def build_backdrop():
    W, H = 720, 1280
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / H
    sky_stops = [(0.0, (34, 20, 22)), (0.22, (78, 38, 30)), (0.42, (168, 86, 44)), (0.55, (222, 140, 70)), (0.62, (240, 176, 96))]
    sky = np.zeros((H, W, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(sky_stops, sky_stops[1:]):
        m = (t >= t0) & (t < t1)
        k = ((t - t0) / (t1 - t0))
        sky[m] = lerp(np.array(c0, np.float32), np.array(c1, np.float32), k)[m]
    sky[t >= 0.62] = (240, 176, 96)
    # sun + glow
    sx, sy = W * 0.68, H * 0.5
    d = np.sqrt((xx - sx) ** 2 + ((yy - sy) * 1.05) ** 2)
    glow = np.exp(-d / 210.0)
    sky += glow[..., None] * np.array([90, 60, 20], np.float32)
    sun = np.clip(78 - d, 0, 1)
    sky = lerp(sky, np.array([255, 226, 160], np.float32), sun)
    # haze bands
    for i, y0 in enumerate([0.3, 0.37, 0.45]):
        band = np.exp(-((t - y0) ** 2) / 0.0004) * (0.5 + 0.5 * periodic_noise(1, W, 30, 300 + i)[0])
        sky += band[..., None] * np.array([40, 20, 10], np.float32) * 0.6
    sky += periodic_noise(H, W, 2.0, 5)[..., None] * 5
    img = quant(sky, 9.0, 1.4)
    layers = [
        (H * 0.56, 22, 0.006, 11, (120, 62, 40), [("rock", 120, 1.2), ("tower", 560, 1.1)]),
        (H * 0.62, 26, 0.009, 12, (84, 44, 30), [("bus", 200, 1.0), ("pole", 470, 1.0), ("car", 640, 0.9)]),
        (H * 0.72, 30, 0.007, 13, (52, 30, 22), [("car", 90, 1.4), ("pole", 600, 1.4)]),
        (H * 0.84, 24, 0.005, 14, (30, 19, 15), []),
    ]
    for base, amp, freq, seed, col, props in layers:
        m = silhouette_layer(W, H, base, amp, freq, seed, props)
        col = np.array(col, np.float32)
        # rim light along the top edge of each layer (sun side)
        top = m - np.roll(m, 2, axis=0)
        rim = np.clip(top, 0, 1) * np.exp(-np.abs(xx - sx) / 380.0)
        tex = col[None, None] * (1.0 + periodic_noise(H, W, 1.6, seed + 50)[..., None] * 0.08)
        tex = tex * (1.0 - (yy - base).clip(0, 400)[..., None] / 400.0 * 0.35)
        tex = quant(tex, 8.0, 1.2)
        img = lerp(img, tex, m)
        img = lerp(img, np.array([255, 190, 110], np.float32), np.clip(rim, 0, 1) * 0.7)
    # dust in the air near the ground
    dust = np.exp(-((t - 0.66) ** 2) / 0.003) * 0.25
    img = lerp(img, np.array([220, 150, 90], np.float32), dust * (0.6 + 0.4 * periodic_noise(H, W, 18, 9)))
    # vignette
    v = np.sqrt(((xx - W / 2) / W) ** 2 + ((yy - H / 2) / H) ** 2)
    img *= (1.0 - np.clip(v - 0.3, 0, 1) * 0.9)[..., None]
    img = np.clip(quant(img, 9.0, 0.8), 0, 255).astype(np.uint8)
    Image.fromarray(img, "RGB").save("assets/sprites/ui/menu_backdrop.png")


if __name__ == "__main__":
    build_kit()
    build_logo()
    build_backdrop()
    print("ok")
