"""Painted scrap-metal UI kit for Wanderer (9-slice plates, buttons, caps,
bars, tile frames), the WANDERER logo and the painted menu backdrop.

Look: dust-apothecary wasteland. Riveted iron/brass plates, light from the
top-left, 3-4 tone shading, ordered-dither grit, dark seams.

usage: python3 tools/gen_ui_kit.py          (run from game/)
Writes assets/sprites/ui/kit/*.png, assets/sprites/ui/logo_wanderer.png,
assets/sprites/ui/menu_backdrop.png
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage as ndi

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
          margin=24, seed=1, grit=14.0, scratches=6, bolt_col=None, glow=None):
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


# --- palettes -----------------------------------------------------------------
IRON_T, IRON_B = (58, 45, 36), (36, 28, 22)
BRASS_HI, BRASS_LO = (226, 180, 104), (96, 64, 34)
STEEL_HI, STEEL_LO = (170, 160, 150), (62, 56, 52)

BUTTONS = {
    # name: (face_top, face_bot, rim_hi, rim_lo)
    "amber": ((214, 150, 58), (150, 88, 30), (255, 214, 130), (104, 62, 22)),
    "teal": ((70, 150, 112), (36, 92, 70), (170, 232, 196), (24, 64, 48)),
    "rust": ((176, 72, 44), (112, 38, 24), (240, 150, 110), (76, 26, 16)),
    "steel": ((96, 82, 70), (62, 52, 44), (178, 160, 140), (52, 44, 38)),
    "neutral": ((190, 190, 190), (128, 128, 128), (250, 250, 250), (80, 80, 80)),
}


def build_kit():
    # Panels (96px, 28px margins, rivets in the corners)
    # Panel faces are flat (no vertical ramp): the centre tiles, so a ramp would band.
    save(plate(96, 96, 12, 7, (44, 34, 27), (44, 34, 27), BRASS_HI, BRASS_LO, margin=28, seed=3, grit=7, scratches=0), "panel.png")
    save(plate(96, 96, 12, 7, (54, 41, 31), (54, 41, 31), (255, 210, 120), (120, 80, 40), margin=28, seed=4, grit=7, scratches=0), "panel_hi.png")
    save(plate(64, 64, 9, 4, (28, 22, 18), (28, 22, 18), STEEL_HI, STEEL_LO, rivets=False, inset=True, margin=18, seed=5, grit=5, scratches=0), "inset.png")
    save(plate(96, 96, 12, 7, (34, 29, 26), (34, 29, 26), STEEL_HI, STEEL_LO, margin=28, seed=6, grit=7, scratches=0), "panel_steel.png")
    # Slim HUD plate: thin brass rim, small rivets, see-through smoky face.
    hud = plate(48, 48, 8, 3, (26, 20, 16), (26, 20, 16), BRASS_HI, BRASS_LO, margin=14, seed=8, grit=5, scratches=0)
    sdf = rrect_sdf(48, 48, 2, 2, 46, 46, 8)
    face = sdf < -5
    hud[..., 3] = np.where(face, (hud[..., 3] * 0.8).astype(np.uint8), hud[..., 3])
    save(hud, "hud.png")
    # Buttons (normal / hover / pressed / disabled)
    for name, (ft, fb, rh, rl) in BUTTONS.items():
        ft, fb, rh, rl = [np.array(c, np.float32) for c in (ft, fb, rh, rl)]
        save(plate(80, 64, 12, 5, ft, fb, rh, rl, margin=22, seed=11, grit=10, scratches=4), "btn_%s.png" % name)
        save(plate(80, 64, 12, 5, ft * 1.12 + 8, fb * 1.12 + 6, rh, rl, margin=22, seed=11, grit=10, scratches=4), "btn_%s_hover.png" % name)
        save(plate(80, 64, 12, 5, fb * 0.9, ft * 0.85, rl * 1.4, rh * 0.8, margin=22, seed=11, grit=10, scratches=4, inset=True), "btn_%s_pressed.png" % name)
    g = np.array([90, 82, 74], np.float32)
    save(plate(80, 64, 12, 5, g * 0.7, g * 0.5, g * 1.2, g * 0.4, margin=22, seed=11, grit=6, scratches=0), "btn_disabled.png")
    # Tile frames (roster / pet / slot tiles)
    save(plate(72, 72, 10, 5, (40, 31, 25), (28, 22, 18), BRASS_HI, BRASS_LO, margin=20, seed=21, grit=6, scratches=0), "tile.png")
    save(plate(84, 84, 10, 6, (64, 46, 30), (40, 30, 22), (255, 226, 150), (176, 112, 40), margin=26, seed=21, grit=6,
               scratches=0, glow=(255, 190, 80)), "tile_on.png")
    # Progress bar groove + fill (fill is neutral: tinted per use)
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
    save(cap(96, (96, 88, 80), (70, 64, 60), "back"), "cap_back.png")
    save(cap(96, (176, 72, 44), (90, 40, 26), "close"), "cap_close.png")
    save(cap(96, (214, 150, 58), (110, 70, 30), "none"), "cap_amber.png")
    save(cap(36, (214, 150, 58), (110, 70, 30), "none"), "cap_grab.png")


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
