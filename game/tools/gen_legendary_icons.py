"""Legendary weapon icons (art pass 3), painted to match the guns on the hero
sprites: gunmetal with worn edges, red-rust paint chipped back to metal, oiled
wood and tape wraps, welded patch plates, rivets, grime in the recesses.

Each weapon is a stack of parts in a 96-unit box, painted at 4x and box-filtered
down to 96 px (the hero sprites read as painted-then-downsampled, so the icons
do too). Light from the top-left, 1 px INK outline, hard alpha. A faint gold
legendary halo is drawn under the weapon at alpha < 230 (gen_weapon_icons.py
strips it when it derives the Common-Epic icons from these).

Writes icons/legendary/legendary_<id>.png (96, pickups) and the IconSet
icons/set/{48,24}/leg_<id>.png + wpn_<hero>_<id>.png (stash / gear / loadout).
gen_icons.py runs this at its end so a full icon rebuild keeps these.

    python3 tools/gen_legendary_icons.py      (from game/)
then
    python3 tools/gen_weapon_icons.py
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(GAME, "assets", "sprites", "icons", "legendary")
SET = os.path.join(GAME, "assets", "sprites", "icons", "set")
LEG_HERO = {"last_shift": "ash_rook", "bellwether": "vesper_thorn", "gravedigger": "pebble",
            "live_line": "bolt_juno", "censer": "sister_cinder", "bonesaw": "quill_marrow",
            "twin_debts": "nyx_caldera", "mayday": "helm_wisp"}
SS = 4
FIT = 0.88  # 96 px: room for the halo; the IconSet pass draws at FIT_SET
FIT_SET = 0.9
MODE = "hd"
N = 96
W = N * SS
INK = np.array([20, 12, 14], np.float32)
LIGHT = np.array([-0.55, -0.70, 0.45])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hx(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


## material: base colour, specular strength, grime amount, rust amount, chip (paint) -> metal
MAT = {
    "gun": dict(c=hx("#4c525a"), spec=0.55, grime=0.5, rust=0.25),
    "steel": dict(c=hx("#6b7178"), spec=0.8, grime=0.45, rust=0.3),
    "blade": dict(c=hx("#9aa3a8"), spec=1.0, grime=0.3, rust=0.18),
    "dark": dict(c=hx("#30333a"), spec=0.35, grime=0.4, rust=0.15),
    "red": dict(c=hx("#9e3324"), spec=0.35, grime=0.55, rust=0.4, chip="steel"),
    "rust": dict(c=hx("#7a3a1e"), spec=0.2, grime=0.6, rust=0.6),
    "wood": dict(c=hx("#6e4428"), spec=0.25, grime=0.5, rust=0.0, grain=1),
    "leather": dict(c=hx("#4a3324"), spec=0.15, grime=0.4, rust=0.0),
    "tape": dict(c=hx("#6d6650"), spec=0.1, grime=0.7, rust=0.0, wrap=1),
    "cloth": dict(c=hx("#59563a"), spec=0.05, grime=0.6, rust=0.0),
    "brass": dict(c=hx("#9a7330"), spec=0.9, grime=0.45, rust=0.1),
    "olive": dict(c=hx("#5f6340"), spec=0.3, grime=0.55, rust=0.35, chip="steel"),
    "bone": dict(c=hx("#cfc3a6"), spec=0.3, grime=0.5, rust=0.0),
    "glass": dict(c=hx("#6fbf3a"), spec=1.2, grime=0.1, rust=0.0, glow=1),
    "ember": dict(c=hx("#e8761c"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "signal": dict(c=hx("#d8661a"), spec=0.5, grime=0.5, rust=0.3, chip="steel"),
    "arc": dict(c=hx("#7fe6ff"), spec=1.0, grime=0.0, rust=0.0, glow=1),
}


def _scr(x, y):
    """96-unit layout point -> supersampled screen px (after FIT)."""
    FIT = _fit()
    return (((x - N / 2) * FIT + N / 2) * SS, ((y - N / 2) * FIT + N / 2) * SS)


def _fit():
    return FIT if MODE == "hd" else FIT_SET


def noise(seed, scale, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros((W, W), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = max(2, int(W / (scale / (2 ** o))))
        g = rng.random((n, n)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((W, W), Image.BICUBIC)
        out += amp * np.asarray(im, np.float32) / 255.0
        tot += amp
        amp *= 0.5
    return out / tot


class Icon:
    def __init__(self, seed):
        self.seed = seed
        self.rgb = np.zeros((W, W, 3), np.float32)
        self.a = np.zeros((W, W), np.float32)
        self.yy, self.xx = np.mgrid[0:W, 0:W].astype(np.float32) / SS
        # draw the 96-unit layout at FIT scale about the centre (halo margin)
        FIT = _fit()
        self.yy = (self.yy - N / 2) / FIT + N / 2
        self.xx = (self.xx - N / 2) / FIT + N / 2
        self.n_big = noise(seed, 40)
        self.n_mid = noise(seed + 1, 14)
        self.n_fine = noise(seed + 2, 4, 2)
        self.k = 0
        self.edges = np.zeros((W, W), np.float32)

    # ---------------------------------------------------------- core painter
    def _paint(self, mask, nrm, mat, u=None, flat=False):
        """mask: float coverage, nrm: (nx, ny, nz) normal field, mat: MAT key."""
        m = MAT[mat]
        self.k += 1
        nx, ny, nz = nrm
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        shade = 0.38 + 0.78 * lam
        # half vector for a hard-ish spec band
        hv = LIGHT + np.array([0, 0, 1.0])
        hv = hv / np.linalg.norm(hv)
        sp = np.clip(nx * hv[0] + ny * hv[1] + nz * hv[2], 0, 1) ** 18 * m["spec"]
        col = m["c"][None, None, :] * shade[..., None] + 255 * sp[..., None] * 0.55
        sd = self.seed * 31 + self.k * 7
        rn = noise(sd, 9)
        if m.get("chip"):
            chip = (rn > 0.66) | ((self.n_fine > 0.74) & (rn > 0.52))
            base2 = MAT[m["chip"]]["c"][None, None, :] * shade[..., None] * 1.15 + 255 * sp[..., None] * 0.7
            col = np.where(chip[..., None], base2, col)
        if m.get("grain") and u is not None:
            g = np.sin(u * 2.2 + self.n_mid * 9.0) * 0.5 + 0.5
            col = col * (0.86 + 0.16 * g[..., None])
        if m.get("wrap") and u is not None:
            band = (np.mod(u * 0.55 + 0.3 * self.n_fine, 1.0) < 0.16)
            col = np.where(band[..., None], col * 0.62, col)
        # grime: darker in noise valleys and toward the lower side
        gr = np.clip((0.55 - self.n_big) * 2.2, 0, 1) * m["grime"]
        gr += np.clip(ny, 0, 1) * 0.25 * m["grime"]
        col = col * (1.0 - 0.45 * gr[..., None]) + np.array([40, 30, 22])[None, None, :] * 0.45 * gr[..., None]
        # rust bloom
        if m["rust"] > 0:
            rr = noise(sd + 3, 6)
            rmask = np.clip((rr - (1.0 - m["rust"] * 0.75)) * 6.0, 0, 1) * np.clip((self.n_mid - 0.35) * 3, 0, 1)
            rc = np.where((self.n_fine > 0.55)[..., None], hx("#a8541f"), hx("#5e2a14"))
            col = col * (1 - rmask[..., None]) + rc * shade[..., None] * rmask[..., None]
        # worn edges: bevels facing the light are rubbed back to bright metal
        if not m.get("glow") and m["spec"] > 0.12:
            bev = np.clip((1 - nz) * 2.2, 0, 1) * np.clip((lam - 0.55) * 3, 0, 1)
            bev = bev * (self.n_fine > 0.38)
            col = col * (1 - 0.6 * bev[..., None]) + hx("#b9b6aa")[None, None, :] * 0.6 * bev[..., None]
        # rust streaks running down from seams / pits
        if m["rust"] > 0:
            st = noise(sd + 5, 3, 1)
            stm = np.asarray(Image.fromarray((np.clip((st - 0.62) * 4, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(0)).resize((W // 8, W)).resize((W, W)), np.float32) / 255
            stm = stm * np.clip((self.n_big - 0.45) * 4, 0, 1) * m["rust"]
            col = col * (1 - 0.55 * stm[..., None]) + hx("#6a3218")[None, None, :] * 0.55 * stm[..., None]
        # fine pitting
        col = col * (0.88 + 0.24 * self.n_fine[..., None])
        if m.get("glow"):
            col = m["c"][None, None, :] * (0.75 + 0.5 * lam[..., None]) + 255 * sp[..., None]
        a = np.clip(mask, 0, 1)
        self.rgb = self.rgb * (1 - a[..., None]) + np.clip(col, 0, 255) * a[..., None]
        self.a = np.maximum(self.a, a)
        # part boundary seams (dark line where a new part sits on another)
        e = np.clip(a * (1 - a) * 4, 0, 1)
        self.edges = np.maximum(self.edges, e)

    def _local(self, p0, p1):
        x0, y0 = p0
        x1, y1 = p1
        L = math.hypot(x1 - x0, y1 - y0)
        dx, dy = (x1 - x0) / L, (y1 - y0) / L
        u = (self.xx - x0) * dx + (self.yy - y0) * dy
        v = -(self.xx - x0) * dy + (self.yy - y0) * dx
        return u, v, L, dx, dy

    # ----------------------------------------------------------- primitives
    def bar(self, p0, p1, w0, mat, w1=None, prof="box", bevel=0.35, cap=0.0):
        """Rotated bar from p0 to p1, width w0 (tapering to w1). prof: cyl / box."""
        w1 = w0 if w1 is None else w1
        u, v, L, dx, dy = self._local(p0, p1)
        t = np.clip(u / L, 0, 1)
        hw = (w0 + (w1 - w0) * t) / 2
        aa = 1.0 / SS
        cov = np.clip((hw - np.abs(v)) / aa + 0.5, 0, 1) * np.clip((u + cap) / aa + 0.5, 0, 1) * np.clip((L + cap - u) / aa + 0.5, 0, 1)
        s = np.clip(v / np.maximum(hw, 1e-3), -1, 1)
        # perpendicular (screen) of +v
        px_, py_ = -dy, dx
        if prof == "cyl":
            nz = np.sqrt(np.clip(1 - s * s, 0, 1))
            nx, ny = px_ * s, py_ * s
        else:
            e = np.clip((np.abs(s) - (1 - bevel)) / bevel, 0, 1)
            nz = np.sqrt(np.clip(1 - (e * 0.85) ** 2, 0, 1))
            nx, ny = px_ * np.sign(s) * e * 0.85, py_ * np.sign(s) * e * 0.85
            # end bevels
            ee = np.clip(1 - np.minimum(u, L - u) / (bevel * 3 + 0.5), 0, 1) * 0.6
            sgn = np.where(u < L / 2, -1.0, 1.0)
            nx = nx + dx * sgn * ee
            ny = ny + dy * sgn * ee
            n = np.sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
            nx, ny, nz = nx / n, ny / n, nz / n
        self._paint(cov, (nx, ny, nz), mat, u=u)
        return u, v

    def poly(self, pts, mat, dome=0.6, bevel=2.0):
        """Flat plate polygon with bevelled rim (distance-to-edge normal)."""
        im = Image.new("L", (W, W), 0)
        ImageDraw.Draw(im).polygon([_scr(x, y) for x, y in pts], fill=255)
        cov = np.asarray(im, np.float32) / 255.0
        self._dist_paint(cov, mat, bevel, dome)

    def ellipse(self, cx, cy, rx, ry, mat, dome=1.0):
        d = ((self.xx - cx) / rx) ** 2 + ((self.yy - cy) / ry) ** 2
        cov = np.clip((1 - np.sqrt(d)) * min(rx, ry) * SS + 0.5, 0, 1)
        r = np.sqrt(np.clip(d, 0, 1))
        nx = (self.xx - cx) / rx * dome
        ny = (self.yy - cy) / ry * dome
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.02, 1))
        n = np.sqrt(nx * nx + ny * ny + nz * nz)
        self._paint(cov, (nx / n, ny / n, nz / n), mat)

    def _dist_paint(self, cov, mat, bevel, dome):
        from scipy import ndimage as ndi
        inside = cov > 0.5
        dist = ndi.distance_transform_edt(inside) / SS
        e = np.clip(1 - dist / bevel, 0, 1)
        gy, gx = np.gradient(ndi.gaussian_filter(dist, 2.0))
        g = np.sqrt(gx * gx + gy * gy) + 1e-6
        nx, ny = -gx / g * e * dome, -gy / g * e * dome
        nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0.02, 1))
        self._paint(cov, (nx, ny, nz), mat)

    # ------------------------------------------------------------- details
    def rivet(self, x, y, r=1.7, mat="steel"):
        self.ellipse(x + 0.4, y + 0.5, r * 1.15, r * 1.15, "dark", dome=0.3)
        self.ellipse(x, y, r, r, mat, dome=0.95)

    def weld(self, p0, p1, w=1.4):
        """Beaded weld seam: lumpy bright/dark beads along a line."""
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        self.bar(p0, p1, w * 2.4, "rust", prof="cyl")
        n = max(2, int(L / (w * 0.8)))
        for i in range(n + 1):
            t = i / n
            x = p0[0] + (p1[0] - p0[0]) * t
            y = p0[1] + (p1[1] - p0[1]) * t
            self.ellipse(x, y, w * 0.75, w * 0.6, "steel", dome=0.9)

    def patch(self, cx, cy, w, h, ang, mat="steel"):
        """Welded patch plate with corner rivets."""
        c, s = math.cos(ang), math.sin(ang)
        pts = []
        for ox, oy in ((-w / 2, -h / 2), (w / 2, -h / 2 + 0.6), (w / 2, h / 2), (-w / 2 + 0.7, h / 2)):
            pts.append((cx + ox * c - oy * s, cy + ox * s + oy * c))
        self.poly(pts, mat, bevel=1.2)
        for (x, y) in pts:
            self.rivet(cx + (x - cx) * 0.72, cy + (y - cy) * 0.72, 0.9)

    def scratches(self, region_mask_fn=None, count=26, seed=0):
        rng = np.random.default_rng(self.seed * 7 + seed)
        im = Image.new("L", (W, W), 0)
        d = ImageDraw.Draw(im)
        for _ in range(count):
            x, y = rng.uniform(8, 88) * SS, rng.uniform(8, 88) * SS
            a = rng.uniform(-0.6, 0.6) + (-0.5)
            L = rng.uniform(2, 7) * SS
            d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=int(rng.uniform(90, 200)), width=2)  # screen space
        sc = np.asarray(im, np.float32) / 255.0 * (self.a > 0.9)
        self.rgb = self.rgb * (1 - 0.35 * sc[..., None]) + hx("#c9c2b0")[None, None, :] * 0.35 * sc[..., None]

    def glow(self, cx, cy, r, color, strength=0.8):
        d = np.sqrt((self.xx - cx) ** 2 + (self.yy - cy) ** 2) / r
        g = np.clip(1 - d, 0, 1) ** 2 * strength
        return (g, hx(color))

    # ---------------------------------------------------------------- output
    def save(self, name, halo=hx("#ffb030"), extra_glows=()):
        """96 px pickup / HD icon (with the legendary halo) plus the IconSet
        48 / 24 px icons the stash, gear and loadout screens actually show
        (hard alpha, no halo: the legendary frame carries the rarity)."""
        if MODE == "hd":
            Image.fromarray(self._render(N, halo, extra_glows), "RGBA").save(os.path.join(OUT, "legendary_%s.png" % name))
            return
        hero = LEG_HERO[name]
        for n in (48, 24):
            im = Image.fromarray(self._render(n, None, ()), "RGBA")
            for stem in ("leg_%s" % name, "wpn_%s_%s" % (hero, name)):
                im.save(os.path.join(SET, str(n), stem + ".png"))

    def _render(self, n, halo, extra_glows):
        from scipy import ndimage as ndi
        f = W // n
        rgb = self.rgb.copy()
        # darken part seams
        rgb *= (1 - 0.35 * self.edges[..., None])
        # premultiplied box filter down to n px
        pm = np.concatenate([rgb * self.a[..., None], self.a[..., None] * 255], axis=2)
        pm = pm.reshape(n, f, n, f, 4).mean(axis=(1, 3))
        a = pm[..., 3] / 255.0
        col = np.where(a[..., None] > 1e-3, pm[..., :3] / np.maximum(a[..., None], 1e-3), 0)
        if n < N:
            # small sizes lose contrast in the box filter: push it back
            mean = col[a > 0.42].mean(axis=0) if (a > 0.42).any() else 0
            col = np.clip((col - mean) * 1.25 + mean, 0, 255)
        solid = a > 0.42
        # outline: 1 px INK ring, 8-connected, plus darkening the outermost body px
        ring = ndi.binary_dilation(solid, structure=np.ones((3, 3))) & ~solid
        inner_edge = solid & ~ndi.binary_erosion(solid, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
        col = np.where(inner_edge[..., None], col * 0.78, col)
        # light the top-left rim a touch (worn edge catching light)
        tl = solid & ~np.roll(solid, 1, axis=0) | solid & ~np.roll(solid, 1, axis=1)
        col = np.where((tl & solid)[..., None], np.clip(col * 1.18 + 10, 0, 255), col)
        out = np.zeros((n, n, 4), np.float32)
        out[solid, :3] = col[solid]
        out[solid, 3] = 255
        out[ring, :3] = INK
        out[ring, 3] = 255
        if halo is not None:
            # halo under everything, alpha < 230 so the base-icon derivation drops it
            sil = (solid | ring).astype(np.float32)
            hal = ndi.gaussian_filter(sil, 3.2)
            hal = np.clip(hal * 1.6, 0, 1) * (1 - sil)
            ha = (hal * 150).astype(np.float32)
            hc = np.broadcast_to(halo, (n, n, 3)).copy()
            for (g, c) in extra_glows:
                gd = g.reshape(n, f, n, f).mean(axis=(1, 3)) * (1 - sil) * 200
                hc = np.where((gd > ha)[..., None], c[None, None, :], hc)
                ha = np.maximum(ha, gd)
            bg = ha > 1
            out[bg, :3] = hc[bg]
            out[bg, 3] = np.minimum(ha[bg], 200)
        return np.clip(out, 0, 255).astype(np.uint8)


# =============================================================== the weapons
def last_shift():
    """Ash Rook: shoulder rocket tube, red bands, scrap warhead loaded."""
    ic = Icon(11)
    A, B = (10, 66), (70, 30)
    ic.bar((6, 69), (64, 34), 15, "gun", prof="cyl")
    for t, wd in ((0.12, 3.2), (0.42, 4.0), (0.78, 3.0)):
        x = 6 + (64 - 6) * t
        y = 69 + (34 - 69) * t
        ic.bar((x - 1.6, y + 1.0), (x + 1.6, y - 1.0), 17, "red", prof="cyl")
    # flared rear venturi
    ic.bar((2, 72), (9, 68), 15, "dark", w1=18, prof="cyl")
    # warhead
    ic.bar((63, 35), (74, 28), 14, "olive", prof="cyl")
    ic.bar((73, 28.6), (90, 18), 13, "red", w1=2.5, prof="cyl")
    ic.bar((74, 28), (76, 26.8), 14.5, "steel", prof="cyl")
    # grip + trigger, foregrip
    ic.bar((28, 60), (24, 74), 6, "wood", prof="box")
    ic.bar((44, 50), (41, 62), 5.5, "tape", prof="box")
    # sight block on top
    ic.poly([(30, 49), (40, 43), (43, 47), (33, 53)], "dark")
    ic.bar((34, 44), (39, 41), 3, "steel")
    ic.patch(20, 59, 8, 6, -0.55, "steel")
    ic.weld((14, 61), (24, 55), 1.0)
    ic.scratches(count=30)
    ic.save("last_shift")


def bellwether():
    """Vesper Thorn: long vial rifle, wood stock, scope, bell on the sling."""
    ic = Icon(23)
    # stock
    ic.poly([(4, 68), (22, 57), (28, 60), (26, 66), (12, 77), (6, 76)], "wood")
    ic.bar((22, 59), (40, 49), 7.5, "gun")
    # receiver
    ic.poly([(32, 50), (56, 36), (60, 42), (37, 56)], "gun")
    # long barrel + muzzle
    ic.bar((56, 39), (92, 17), 3.6, "steel", prof="cyl")
    ic.bar((86, 20.5), (93, 16.2), 5.5, "dark", prof="cyl")
    ic.bar((58, 41), (78, 29), 5.0, "wood", prof="box")
    # scope
    ic.bar((36, 43), (58, 30), 6.0, "dark", prof="cyl")
    ic.bar((35, 44), (39, 41.5), 8.0, "gun", prof="cyl")
    ic.bar((55, 31.5), (59, 29), 8.0, "gun", prof="cyl")
    ic.ellipse(59.6, 29.4, 1.6, 2.3, "glass")
    # vial cartridge hanging under receiver
    ic.bar((44, 53), (48, 65), 6.5, "glass", prof="cyl")
    ic.bar((43.2, 51), (44.6, 55), 7.5, "brass", prof="cyl")
    ic.bar((47.5, 64), (48.6, 67), 7.0, "brass", prof="cyl")
    # trigger guard
    ic.bar((34, 56), (33, 63), 2.0, "dark")
    # bell on a cord
    ic.bar((62, 42), (63, 52), 1.0, "leather")
    ic.poly([(60, 52), (66, 52), (68, 60), (58, 60)], "brass", bevel=1.6)
    ic.ellipse(63, 61, 1.6, 1.4, "dark")
    ic.patch(27, 64, 6, 4.5, -0.6, "steel")
    ic.scratches(count=22)
    g = ic.glow(46, 59, 9, "#9ccf3e")
    ic.save("bellwether", extra_glows=[g])


def gravedigger():
    """Pebble: scrap-slab maul on a pipe haft, painted X, rebar spikes."""
    ic = Icon(37)
    # haft
    ic.bar((12, 88), (52, 36), 5.5, "steel", prof="cyl")
    ic.bar((12, 88), (24, 72), 6.5, "tape", prof="cyl")
    ic.bar((10, 90.5), (13.5, 86.5), 8, "dark", prof="cyl")
    # head: thick welded slab
    hc = (58, 30)
    ang = math.radians(-37)
    c, s = math.cos(ang), math.sin(ang)

    def P(ox, oy):
        return (hc[0] + ox * c - oy * s, hc[1] + ox * s + oy * c)
    # rebar spikes behind head
    for oy in (-12, -4, 4, 12):
        ic.bar(P(16, oy), P(30, oy + 2.0), 3.4, "rust", w1=0.8, prof="cyl")
    sh = [(x + 2.6, y + 3.2) for (x, y) in (P(-22, -16), P(19, -18), P(21, 17), P(-20, 18))]
    ic.poly(sh, "dark", bevel=1.0)
    ic.poly([P(-22, -16), P(19, -18), P(21, 17), P(-20, 18)], "gun", bevel=3.0)
    # second scrap plate bolted over the top-right corner
    ic.poly([P(2, -19), P(22, -19.5), P(23, -3), P(5, -1)], "steel", bevel=2.0)
    ic.ellipse(*P(13, -10), 2.2, 2.2, "dark", dome=0.1)
    # painted X (red, chipped)
    ic.bar(P(-14, -11), P(12, 12), 5.0, "red", prof="box")
    ic.bar(P(-14, 12), P(12, -11), 5.0, "red", prof="box")
    # weld plates + bolts
    ic.patch(*P(-16, 9), 9, 7, ang + 0.1, "steel")
    ic.weld(P(-21, -2), P(-21, 15), 1.2)
    ic.weld(P(4, -17), P(18, -17.6), 1.1)
    for (ox, oy) in ((-18, -13), (16, -14), (17, 14)):
        ic.rivet(*P(ox, oy), 1.5)
    # collar where haft meets head
    ic.bar(P(-3, 18), P(3, 18.3), 9, "dark", prof="cyl")
    ic.scratches(count=34)
    ic.save("gravedigger")


def live_line():
    """Bolt Juno: red armoured gauntlet (fist, knuckle plates, hooked claws),
    a heavy chain wrapped off the cuff, live arcs between the claws."""
    ic = Icon(41)
    import random
    rnd = random.Random(4)
    # chain: alternating flat / edge-on links hanging down-left from the cuff
    pts = [(26, 70), (21, 75), (17, 80), (13, 85), (10, 90)]
    for i, (x, y) in enumerate(pts):
        if i % 2 == 0:
            ic.ellipse(x, y, 4.6, 3.2, "steel", dome=0.7)
            ic.ellipse(x, y, 2.3, 1.2, "dark", dome=0.1)
        else:
            ic.bar((x - 2.2, y + 2.2), (x + 2.2, y - 2.2), 2.6, "steel", prof="cyl")
    # cuff: thick cylinder with a rust band and rivets
    ic.bar((22, 70), (38, 54), 22, "gun", prof="cyl")
    ic.bar((24, 68), (27, 65), 23, "rust", prof="cyl")
    ic.bar((34, 58), (37, 55), 23, "dark", prof="cyl")
    # back-of-hand plate (red), big
    ic.poly([(32, 50), (52, 28), (70, 40), (52, 64)], "red", bevel=3.0)
    ic.poly([(40, 46), (54, 32), (62, 38), (50, 54)], "dark", bevel=1.5)
    ic.poly([(41, 45), (54, 33), (60, 37.5), (49, 52)], "red", bevel=2.0)
    # fingers: 4 curled segments, each a knuckle plate + claw
    for k, (bx, by) in enumerate(((52, 26), (60, 30), (66, 36), (70, 44))):
        ang = math.radians(-55 + k * 22)
        ex, ey = bx + math.cos(ang) * 9, by + math.sin(ang) * 9
        ic.bar((bx - 2, by + 2), (ex, ey), 6.4, "gun", prof="cyl")
        ic.ellipse(bx, by, 3.6, 3.6, "red", dome=0.9)
        cx, cy = ex + math.cos(ang + 0.5) * 12, ey + math.sin(ang + 0.5) * 12
        ic.bar((ex, ey), (cx, cy), 4.4, "blade", w1=0.7, prof="cyl")
    # thumb
    ic.bar((46, 58), (58, 58), 6.0, "gun", prof="cyl")
    ic.ellipse(46, 58, 3.4, 3.4, "red", dome=0.9)
    ic.weld((34, 52), (50, 33), 1.1)
    for (x, y) in ((36, 52), (44, 43), (54, 56), (62, 46)):
        ic.rivet(x, y, 1.6)
    # capacitor coil on the wrist
    ic.bar((40, 62), (50, 52), 4.8, "brass", prof="cyl")
    ic.scratches(count=26)
    # arcs between the claw tips
    im = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(im)
    for k in range(3):
        x, y = 66 + k * 5, 10 + k * 9
        path = [_scr(x, y)]
        for j in range(5):
            x += rnd.uniform(1.5, 3.5)
            y += rnd.uniform(-2.5, 2.5) + 1.2
            path.append(_scr(x, y))
        d.line(path, fill=255, width=SS + 1)
    arc = np.asarray(im, np.float32) / 255.0
    nz = (np.zeros((W, W)), np.zeros((W, W)), np.ones((W, W)))
    ic._paint(arc, nz, "arc")
    g = ic.glow(78, 24, 16, "#5cd2c0", 0.9)
    ic.save("live_line", extra_glows=[g])


def censer():
    """Sister Cinder: suppressed AR, rust-red furniture, a smoking censer on a chain."""
    ic = Icon(53)
    # stock
    ic.poly([(3, 64), (18, 56), (22, 62), (8, 72), (4, 71)], "red", bevel=1.6)
    ic.bar((16, 59), (30, 52), 4.0, "dark")
    # receiver
    ic.poly([(26, 52), (52, 38), (58, 46), (31, 60)], "gun", bevel=2.0)
    # magazine (curved)
    ic.poly([(38, 54), (45, 50), (50, 62), (44, 67)], "dark", bevel=1.5)
    # grip
    ic.bar((31, 59), (29, 69), 5.0, "red")
    # handguard + suppressor
    ic.bar((52, 41), (70, 31), 7.5, "red", prof="box")
    ic.bar((68, 32), (92, 19), 7.0, "gun", prof="cyl")
    for t in (0.25, 0.55, 0.85):
        x = 68 + 24 * t
        y = 32 - 13 * t
        ic.bar((x - 0.7, y + 0.4), (x + 0.7, y - 0.4), 7.6, "dark", prof="cyl")
    # top rail + sight
    ic.bar((30, 49), (52, 37), 2.4, "steel")
    ic.poly([(40, 43), (45, 40), (47, 43), (42, 46)], "dark")
    # chain + censer
    for i, (x, y) in enumerate(((60, 42), (61, 46), (62, 50), (63, 54))):
        if i % 2:
            ic.ellipse(x, y, 1.1, 2.2, "steel", dome=0.6)
        else:
            ic.ellipse(x, y, 1.9, 1.3, "steel", dome=0.6)
    ic.ellipse(64, 62, 6.5, 5.5, "brass")
    ic.bar((57.5, 61), (70.5, 61), 2.0, "dark")
    for x in (61, 64, 67):
        ic.ellipse(x, 63.5, 0.9, 0.9, "ember")
    ic.patch(34, 49, 7, 5, -0.48, "steel")
    ic.weld((54, 40), (60, 36.5), 0.9)
    ic.scratches(count=26)
    # smoke wisps (soft, under alpha 230: halo layer)
    sm = np.zeros((W, W), np.float32)
    for k in range(5):
        cx, cy, r = 66 + k * 1.8 + math.sin(k) * 2, 54 - k * 6, 3.5 + k * 0.8
        sm = np.maximum(sm, np.clip(1 - np.sqrt((ic.xx - cx) ** 2 + (ic.yy - cy) ** 2) / r, 0, 1) * 0.5)
    g = ic.glow(64, 62, 11, "#e8761c", 0.8)
    ic.save("censer", extra_glows=[g, (sm, hx("#8f877e"))])


def bonesaw():
    """Quill Marrow: field-surgeon's saw-backed bayonet, taped grip, bone pommel."""
    ic = Icon(67)
    # blade: long, slight curve, saw teeth on the spine
    ang = math.radians(-40)
    c, s = math.cos(ang), math.sin(ang)
    o = (34, 62)

    def P(u, v):
        return (o[0] + u * c - v * s, o[1] + u * s + v * c)
    teeth = []
    for i in range(10):
        u = 6 + i * 4.4
        teeth += [P(u, -6.5), P(u + 2.2, -9.4)]
    edge = [P(u, 4.5 - (u / 58) ** 2 * 3) for u in range(56, 2, -6)]
    ic.poly([P(2, -6.5)] + teeth + [P(52, -6.5), P(60, -2), P(64, 0.5)] + edge, "blade", bevel=2.4)
    # fuller groove
    ic.bar(P(8, -1.5), P(40, -1.5), 1.6, "gun")
    # blood + grime streak near the edge
    ic.bar(P(22, 3.0), P(38, 2.4), 2.0, "rust", w1=0.6)
    # guard + muzzle ring
    ic.poly([P(-1, -11), P(3, -11), P(3, 9), P(-1, 9)], "brass", bevel=1.2)
    ic.ellipse(*P(1, -13), 2.6, 2.6, "steel")
    # grip
    ic.bar(P(-22, 0), P(-1, 0), 7.0, "tape", prof="cyl")
    ic.bar(P(-27, 0), P(-21, 0), 8.5, "bone", prof="cyl")
    ic.rivet(*P(-24, 0), 1.2, "steel")
    ic.weld(P(4, -6.6), P(14, -6.6), 0.8)
    ic.scratches(count=30)
    ic.save("bonesaw")


def twin_debts():
    """Nyx Caldera: two crossed dustblades, cord-wrapped, one notched."""
    ic = Icon(79)
    for flip in (0, 1):
        if flip == 0:
            p0, p1 = (12, 84), (82, 12)
        else:
            p0, p1 = (84, 84), (14, 12)
        # handle part
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        dx, dy = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L

        def Q(t, v=0.0):
            return (p0[0] + dx * t - dy * v, p0[1] + dy * t + dx * v)
        ic.bar(Q(4), Q(26), 6.5, "leather", prof="cyl")
        ic.bar(Q(6), Q(24), 7.0, "cloth" if flip else "tape", prof="cyl")
        ic.bar(Q(0), Q(5), 8.0, "steel", prof="cyl")
        # guard
        ic.bar(Q(26, -7), Q(26, 7), 3.4, "gun", prof="cyl")
        # blade with a clipped point
        pts = [Q(28, -4.2), Q(84, -3.0), Q(98, 0.5), Q(86, 3.6), Q(28, 4.2)]
        if flip:
            pts = [Q(28, -4.2), Q(56, -4.0), Q(58, -2.0), Q(61, -4.0), Q(84, -3.0), Q(98, 0.5), Q(86, 3.6), Q(28, 4.2)]
        ic.poly(pts, "blade", bevel=2.2)
        ic.bar(Q(32, -0.6), Q(78, -0.4), 1.2, "gun")
        ic.rivet(*Q(15), 1.0, "brass")
    # coin pinned at the cross
    ic.ellipse(48, 48, 6.5, 6.5, "brass")
    ic.ellipse(48, 48, 3.2, 3.2, "rust", dome=0.4)
    ic.scratches(count=26)
    ic.save("twin_debts")


def mayday():
    """Helm Wisp: chunky pilot sidearm with an orange flare launcher slung under it."""
    ic = Icon(83)
    # grip
    ic.poly([(20, 56), (34, 52), (36, 78), (30, 84), (20, 82), (24, 66)], "dark", bevel=2.0)
    for y in (62, 67, 72, 77):
        ic.bar((25, y), (33, y - 1.6), 1.2, "gun")
    # slide
    ic.poly([(16, 40), (76, 26), (80, 36), (20, 50)], "gun", bevel=2.6)
    # slide serrations
    for i in range(6):
        x = 22 + i * 2.6
        ic.bar((x, 39.5 - i * 0.6), (x + 1.2, 47 - i * 0.6), 0.9, "dark")
    # barrel bushing + muzzle
    ic.bar((74, 29), (84, 26.5), 7.5, "steel", prof="cyl")
    ic.ellipse(84.5, 26.8, 1.6, 3.0, "dark", dome=0.2)
    # flare tube under barrel (signal orange, chipped)
    ic.bar((40, 50), (82, 40), 9.0, "rust", prof="cyl")
    ic.bar((42, 49.5), (80, 40.5), 8.6, "signal", prof="cyl")
    ic.bar((70, 43), (73, 42.2), 9.4, "dark", prof="cyl")
    ic.ellipse(83, 39.5, 2.2, 4.4, "dark", dome=0.2)
    ic.ellipse(83.4, 39.4, 1.2, 2.6, "ember", dome=0.2)
    # trigger guard
    ic.bar((34, 52), (44, 50), 1.8, "dark")
    ic.bar((44, 50), (43, 56), 1.8, "dark")
    # rear sight + hammer
    ic.poly([(16, 38), (20, 36), (22, 41), (18, 42)], "dark")
    ic.patch(52, 32, 9, 6, -0.23, "olive")
    ic.weld((45, 47.5), (56, 45), 1.0)
    for x in (58, 66):
        ic.rivet(x, 44.5 - (x - 58) * 0.25, 1.0)
    ic.scratches(count=28)
    g = ic.glow(84, 39, 8, "#ff8a2a", 0.7)
    ic.save("mayday", extra_glows=[g])


if __name__ == "__main__":
    WEAPONS = (last_shift, bellwether, gravedigger, live_line, censer, bonesaw, twin_debts, mayday)
    for MODE in ("hd", "set"):
        for fn in WEAPONS:
            fn()
        print("ok", MODE, len(WEAPONS))
