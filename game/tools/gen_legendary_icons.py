"""Weapon icons, every rarity (art passes 3-4), painted to match the guns on the
hero sprites: gunmetal with worn edges, paint chipped back to metal, oiled wood
and tape wraps, welded patch plates, rivets, grime in the recesses.

One drawing per survivor weapon, finished per rarity so the tier reads at a
glance even before the frame colour:
  Common (patched)  rusted through, red paint gone to rust, a rag tied on
  Rare              worn teal service paint, teal wraps
  Epic              element finish: fire = scorched black + ember veins,
                    poison = toxic green paint + dripping venom, shock = blued
                    steel + arcs, frost = pale paint + rime on the top edges
  Legendary         red/brass furniture + its own attachment (bell, censer,
                    coin, live arcs) + gold halo on the 96 px pickup icon

Each weapon is a stack of parts in a 96-unit box, painted at 4x and box-filtered
down. Light from the top-left, 1 px INK outline, hard alpha (the 96 px
legendary halo is alpha < 230). The 24 px icons are a simplified variant: thin
parts drawn ~1.8x bolder, no rivets / welds / scratches, lower coverage
threshold, values lifted. 48 / 24 px icons are auto-fitted so the outline keeps
a 1 px margin.

Writes
  icons/legendary/legendary_<id>.png      96 px legendary pickups (with halo)
  icons/weapons/weapon_<hero>.png         96 px base weapon pickups
  icons/set/{48,24}/wpn_<hero>_<variant>.png and leg_<id>.png (stash / gear /
  loadout; IconSet)
gen_icons.py runs this at its end so a full icon rebuild keeps them.

    python3 tools/gen_legendary_icons.py      (from game/)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(GAME, "assets", "sprites", "icons", "legendary")
SET = os.path.join(GAME, "assets", "sprites", "icons", "set")
WPN = os.path.join(GAME, "assets", "sprites", "icons", "weapons")
LEG_HERO = {"last_shift": "ash_rook", "bellwether": "vesper_thorn", "gravedigger": "pebble",
            "live_line": "bolt_juno", "censer": "sister_cinder", "bonesaw": "quill_marrow",
            "twin_debts": "nyx_caldera", "mayday": "helm_wisp"}
SS = 4
FIT = 0.88  # 96 px: room for the halo; the IconSet sizes are auto-fitted
FIT_SET = 0.9
MODE = "hd"      # hd (96) / s48 / s24
KIND = "legendary"  # base / patched / rare / epic / legendary
ELEMENT = ""
## (variant id, kind, element) per survivor, matching GearDefs.WEAPON_VARIANTS
VARIANTS = {
    "ash_rook": [("patched", "patched", ""), ("long_fuse", "rare", ""), ("cluster", "epic", "fire")],
    "vesper_thorn": [("patched", "patched", ""), ("bell_tuned", "rare", ""), ("hollowpoint", "epic", "poison")],
    "pebble": [("patched", "patched", ""), ("rebar", "rare", ""), ("quarry", "epic", "shock")],
    "bolt_juno": [("patched", "patched", ""), ("coiled", "rare", ""), ("arc", "epic", "shock")],
    "sister_cinder": [("patched", "patched", ""), ("chapel", "rare", ""), ("thurible", "epic", "fire")],
    "quill_marrow": [("patched", "patched", ""), ("surgical", "rare", ""), ("autopsy", "epic", "poison")],
    "nyx_caldera": [("patched", "patched", ""), ("night", "rare", ""), ("smuggler", "epic", "frost")],
    "helm_wisp": [("patched", "patched", ""), ("flight", "rare", ""), ("flare", "epic", "fire")],
}
## material swaps per finish
REMAP = {
    "patched": {"red": "rust", "olive": "rust", "brass": "rust", "signal": "rust", "blade": "steel", "bone": "leather"},
    "rare": {"red": "tealp", "signal": "tealp", "olive": "tealp", "tape": "tealwrap", "cloth": "tealwrap"},
    "epic:fire": {"red": "scorch", "olive": "scorch", "signal": "scorch", "tape": "leather", "wood": "scorch"},
    "epic:poison": {"red": "toxicp", "olive": "toxicp", "signal": "toxicp", "tape": "cloth"},
    "epic:shock": {"red": "voltp", "olive": "voltp", "signal": "voltp", "brass": "steel"},
    "epic:frost": {"red": "frostp", "olive": "frostp", "signal": "frostp", "tape": "leather",
                   "blade": "iceblade", "cloth": "frostp"},
}
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
    "gun": dict(c=hx("#5a616b"), spec=0.55, grime=0.5, rust=0.25),
    "steel": dict(c=hx("#6b7178"), spec=0.8, grime=0.45, rust=0.3),
    "blade": dict(c=hx("#9aa3a8"), spec=1.0, grime=0.3, rust=0.18),
    "dark": dict(c=hx("#30333a"), spec=0.45, grime=0.4, rust=0.15, metal=0.8),
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
    "tealp": dict(c=hx("#3f857b"), spec=0.4, grime=0.5, rust=0.3, chip="steel"),
    "tealwrap": dict(c=hx("#3a6e68"), spec=0.1, grime=0.6, rust=0.0, wrap=1),
    "scorch": dict(c=hx("#3a2622"), spec=0.3, grime=0.3, rust=0.2, chip="dark"),
    "toxicp": dict(c=hx("#5c7a26"), spec=0.35, grime=0.5, rust=0.3, chip="steel"),
    "voltp": dict(c=hx("#2f4f78"), spec=0.6, grime=0.4, rust=0.15, chip="steel"),
    "frostp": dict(c=hx("#9db4c2"), spec=0.6, grime=0.35, rust=0.1, chip="steel"),
    "frost": dict(c=hx("#dff2ff"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "iceblade": dict(c=hx("#8fd0ea"), spec=1.1, grime=0.15, rust=0.0),
}


OFF = (0.0, 0.0)  # layout shift applied before FIT (auto-centring)


def _scr(x, y):
    """96-unit layout point -> supersampled screen px (after OFF + FIT)."""
    FIT = _fit()
    return (((x + OFF[0] - N / 2) * FIT + N / 2) * SS, ((y + OFF[1] - N / 2) * FIT + N / 2) * SS)


def _fit():
    return FIT_SET


def _bold():
    """Small icons draw thin parts thicker (simplified 24 px variant)."""
    return {"hd": 1.0, "s48": 1.25, "s24": 2.2}[MODE]


def _detail():
    return MODE != "s24"


def _remap():
    if KIND in ("patched", "rare"):
        return REMAP[KIND]
    if KIND == "epic":
        return REMAP["epic:" + ELEMENT]
    return {}


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
        self.yy = (self.yy - N / 2) / FIT + N / 2 - OFF[1]
        self.xx = (self.xx - N / 2) / FIT + N / 2 - OFF[0]
        self.n_big = noise(seed, 40)
        self.n_mid = noise(seed + 1, 14)
        self.n_fine = noise(seed + 2, 4, 2)
        self.k = 0
        self.edges = np.zeros((W, W), np.float32)
        self.leg = KIND == "legendary"
        self.remap = _remap()

    # ---------------------------------------------------------- core painter
    def _paint(self, mask, nrm, mat, u=None, v=None, flat=False):
        """Material shader. mask: float coverage, nrm: (nx, ny, nz) normal field,
        mat: MAT key, u/v: part-local coords (along / across) for anisotropic
        brushing, grain and weave."""
        m = dict(MAT[self.remap.get(mat, mat)])
        if KIND == "patched" and not m.get("glow") and m["spec"] > 0.12:
            m["rust"] = min(1.0, m["rust"] * 1.6 + 0.25)
            m["grime"] = min(1.0, m["grime"] * 1.3)
        self.k += 1
        a = np.clip(mask, 0, 1)
        live = a > 0.002
        if not live.any():
            return
        # work only inside the part's bbox (+ room for its cast shadow)
        ys_, xs_ = np.nonzero(live)
        P = 7 * SS
        sl = (slice(max(0, ys_.min() - P), min(W, ys_.max() + P + 1)), slice(max(0, xs_.min() - P), min(W, xs_.max() + P + 1)))
        a = a[sl]
        nx, ny, nz = (np.broadcast_to(c, (W, W))[sl] for c in nrm)
        XX, YY = self.xx[sl], self.yy[sl]
        n_big, n_mid, n_fine = self.n_big[sl], self.n_mid[sl], self.n_fine[sl]
        if u is None:
            # polys / ellipses: brush along the weapon's long axis (about -30 deg)
            u = XX * 0.866 - YY * 0.5
            v = XX * 0.5 + YY * 0.866
        else:
            u, v = u[sl], v[sl]
        metal = m.get("metal", 1.0 if (m["spec"] >= 0.5 and not m.get("glow")) else 0.0)
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        hv = LIGHT + np.array([0, 0, 1.0])
        hv = hv / np.linalg.norm(hv)
        ndh = np.clip(nx * hv[0] + ny * hv[1] + nz * hv[2], 0, 1)
        sd = self.seed * 31 + self.k * 7
        # anisotropic brushing: per-streak random level across v, stretched along u
        vq = np.floor(v * SS * 0.9)
        streak = np.mod(np.sin(vq * 12.9898 + sd) * 43758.5453, 1.0)
        streak = streak * 0.6 + 0.4 * np.mod(np.sin(np.floor(u * 0.35) * 7.1 + vq * 3.3) * 9631.7, 1.0)
        base = m["c"][None, None, :]
        if metal > 0:
            # environment reflection: warm bright sky up-left, dark dirt below
            ry = ny * 2 * nz - 0.0  # reflected y (view along z)
            env = np.clip(0.55 - ry * 0.75 - nx * 0.2, 0, 1.25)
            env = env * (0.88 + 0.22 * streak)
            dif = 0.30 + 0.55 * lam
            sp = ndh ** 26 * m["spec"] * (0.75 + 0.5 * streak) + ndh ** 6 * 0.18 * m["spec"]
            col = base * (dif * (1 - 0.55 * metal) + env * 0.95 * metal)[..., None] + 255 * sp[..., None] * 0.6
        else:
            dif = 0.34 + 0.76 * lam
            sp = ndh ** 14 * m["spec"] * 0.5
            col = base * dif[..., None] + 255 * sp[..., None] * 0.5
        shade = (0.38 + 0.78 * lam)[..., None]
        rn = noise(sd, 7)[sl]
        if m.get("chip"):
            # layered chips: paint -> dark primer -> bright bare metal at the centre
            c1 = (rn > 0.62) | ((n_fine > 0.76) & (rn > 0.5))
            c2 = (rn > 0.70) | ((n_fine > 0.84) & (rn > 0.56))
            primer = hx("#4a2c22")[None, None, :] * shade
            bare = MAT[m["chip"]]["c"][None, None, :] * shade * 1.35 + 255 * (ndh ** 20)[..., None] * 0.7
            col = np.where(c1[..., None], primer, col)
            col = np.where(c2[..., None], bare, col)
        if m.get("grain"):
            w = v * 3.1 + n_mid * 7.0 + np.sin(u * 0.22) * 0.8
            g = np.abs(np.sin(w))
            line = np.clip((0.18 - g) * 6, 0, 1)
            pores = (n_fine > 0.72) & (np.mod(np.floor(u * SS * 0.6) + np.floor(v * SS), 5) == 0)
            col = col * (0.9 + 0.14 * np.sin(w * 0.37)[..., None]) * (1 - 0.32 * line[..., None]) * np.where(pores, 0.8, 1.0)[..., None]
        if m.get("wrap"):
            band = (np.mod(u * 0.55 + 0.3 * n_fine, 1.0) < 0.16)
            col = np.where(band[..., None], col * 0.6, col)
        if m.get("weave") or m.get("wrap") or mat in ("cloth", "leather"):
            k = SS * 1.2
            wv = (np.sin(u * k) * np.sin(v * k)) * 0.5 + 0.5
            col = col * (0.9 + 0.16 * wv[..., None])
        # grime: soot in noise valleys and on the underside
        gr = np.clip((0.55 - n_big) * 2.2, 0, 1) * m["grime"]
        gr += np.clip(ny, 0, 1) * 0.3 * m["grime"]
        col = col * (1.0 - 0.45 * gr[..., None]) + np.array([38, 28, 20])[None, None, :] * 0.45 * gr[..., None]
        # rust with depth: orange core -> brown -> dark rim, pitted
        if m["rust"] > 0:
            rr = noise(sd + 3, 6)[sl]
            t = (rr - (1.0 - m["rust"] * 0.75)) * 6.0
            rmask = np.clip(t, 0, 1) * np.clip((n_mid - 0.35) * 3, 0, 1)
            depth = np.clip(t - 0.6, 0, 1.5) / 1.5
            rc = (hx("#3e1c10")[None, None, :] * (1 - depth[..., None]) + hx("#b4602a")[None, None, :] * depth[..., None])
            rc = rc * (0.8 + 0.4 * n_fine[..., None])
            pit = (n_fine > 0.8) & (rmask > 0.5)
            rc = np.where(pit[..., None], rc * 0.45, rc)
            col = col * (1 - rmask[..., None]) + rc * shade * rmask[..., None]
            # streaks running down from seams / pits
            st = noise(sd + 5, 3, 1)
            stm = (np.asarray(Image.fromarray((np.clip((st - 0.62) * 4, 0, 1) * 255).astype(np.uint8)).resize((W // 8, W)).resize((W, W)), np.float32) / 255)[sl]
            stm = stm * np.clip((n_big - 0.45) * 4, 0, 1) * m["rust"]
            col = col * (1 - 0.5 * stm[..., None]) + hx("#6a3218")[None, None, :] * 0.5 * stm[..., None]
        # worn edges: every bevel rubbed back to bright metal (strongest facing the light)
        if not m.get("glow") and m["spec"] > 0.12:
            edge = np.clip((1 - nz) * 2.4, 0, 1)
            bev = edge * np.clip(0.35 + (lam - 0.45) * 2.5, 0, 1) * (n_fine > 0.36)
            col = col * (1 - 0.65 * bev[..., None]) + hx("#c9c6bb")[None, None, :] * 0.65 * bev[..., None]
        # fine pitting / grit
        col = col * (0.9 + 0.2 * n_fine[..., None])
        if m.get("glow"):
            col = m["c"][None, None, :] * (0.75 + 0.5 * lam[..., None]) + 255 * (ndh ** 18)[..., None]
        # this part casts a soft shadow onto the parts under it (offset down-right)
        if _detail() or MODE == "s24":
            from scipy import ndimage as ndi
            sh = ndi.gaussian_filter(a, 1.3 * SS)
            sh = np.roll(np.roll(sh, int(1.0 * SS), axis=1), int(1.4 * SS), axis=0)
            occ = np.clip(sh * 0.55, 0, 0.55) * (1 - a) * (self.a[sl] > 0)
            self.rgb[sl] = self.rgb[sl] * (1 - occ[..., None])
        self.rgb[sl] = self.rgb[sl] * (1 - a[..., None]) + np.clip(col, 0, 255) * a[..., None]
        self.a[sl] = np.maximum(self.a[sl], a)
        # part boundary seams (dark line where a new part sits on another)
        e = np.clip(a * (1 - a) * 4, 0, 1)
        self.edges[sl] = np.maximum(self.edges[sl], e)

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
        b = _bold()
        if b != 1.0:
            # thin parts thicken most; big bodies stay close to their size
            w0 = w0 + (b - 1.0) * min(w0, 6.0)
            w1 = w1 + (b - 1.0) * min(w1, 6.0)
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
        self._paint(cov, (nx, ny, nz), mat, u=u, v=v)
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
        if not _detail():
            return
        self.ellipse(x + 0.4, y + 0.5, r * 1.15, r * 1.15, "dark", dome=0.3)
        self.ellipse(x, y, r, r, mat, dome=0.95)

    def weld(self, p0, p1, w=1.4):
        """Beaded weld seam: lumpy bright/dark beads along a line."""
        if not _detail():
            return
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
        if not _detail():
            return
        c, s = math.cos(ang), math.sin(ang)
        pts = []
        for ox, oy in ((-w / 2, -h / 2), (w / 2, -h / 2 + 0.6), (w / 2, h / 2), (-w / 2 + 0.7, h / 2)):
            pts.append((cx + ox * c - oy * s, cy + ox * s + oy * c))
        self.poly(pts, mat, bevel=1.2)
        for (x, y) in pts:
            self.rivet(cx + (x - cx) * 0.72, cy + (y - cy) * 0.72, 0.9)

    def scratches(self, region_mask_fn=None, count=26, seed=0):
        if not _detail():
            return
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
        """Apply the rarity finish overlays and hand the result to the driver
        (main), which renders it at the current MODE size."""
        global RESULT
        if KIND == "patched":
            self._rag()
        if KIND == "epic":
            extra_glows = list(extra_glows) + self._element(ELEMENT)
        RESULT = (self, halo if (KIND == "legendary" and MODE == "hd") else None, extra_glows)

    def _axis(self):
        ys, xs = np.nonzero(self.a > 0.5)
        cy, cx = ys.mean() / SS, xs.mean() / SS
        cov = np.cov(np.stack([xs / SS, ys / SS]))
        w, v = np.linalg.eigh(cov)
        ax = v[:, 1]
        return cx, cy, ax

    def _rag(self):
        """Common: a filthy rag knotted round the middle, two tails hanging."""
        cx, cy, ax = self._axis()
        # layout coords of the screen centroid
        fit = _fit()
        lx, ly = (cx - N / 2) / fit + N / 2 - OFF[0], (cy - N / 2) / fit + N / 2 - OFF[1]
        px_, py_ = -ax[1], ax[0]
        L = 7.0
        self.bar((lx - px_ * L, ly - py_ * L), (lx + px_ * L, ly + py_ * L), 6.5, "cloth", prof="cyl")
        self.bar((lx + px_ * 3, ly + py_ * 3 + 2), (lx + px_ * 2 + 3, ly + py_ * 2 + 13), 3.2, "cloth", w1=2.0, prof="cyl")
        self.bar((lx + px_ * 4, ly + py_ * 4 + 2), (lx + px_ * 6 + 1, ly + py_ * 6 + 11), 2.8, "cloth", w1=1.6, prof="cyl")

    def _element(self, el):
        """Epic element finish on top of the painted weapon. Returns extra glows."""
        sil = self.a > 0.5
        from scipy import ndimage as ndi
        rng = np.random.default_rng(self.seed + 500)
        zero = np.zeros((W, W))
        flatn = (zero, zero, np.ones((W, W)))
        inner = ndi.binary_erosion(sil, iterations=int(1.5 * SS))
        if el == "fire":
            n = noise(self.seed + 50, 22, 1)
            vein = inner & (np.abs(n - 0.5) < 0.02)
            it = {"hd": 0, "s48": 1, "s24": 2}[MODE]
            if it:
                vein = ndi.binary_dilation(vein, iterations=it)
            self._paint(vein.astype(np.float32), flatn, "ember")
            return [(ndi.gaussian_filter(vein.astype(np.float32), 6) * 3.0, hx("#ff8a2a"))]
        if el == "poison":
            n = noise(self.seed + 51, 12, 2)
            vein = inner & (np.abs(n - 0.5) < 0.016)
            self._paint(vein.astype(np.float32), flatn, "glass")
            # venom drips under the lowest edge points
            ys, xs = np.nonzero(sil)
            cols = rng.choice(np.unique(xs), size=4, replace=False)
            drops = np.zeros((W, W), np.float32)
            for c in cols:
                yb = ys[xs == c].max()
                ux, uy = c / SS, yb / SS
                fit = _fit()
                lx, ly = (ux - N / 2) / fit + N / 2 - OFF[0], (uy - N / 2) / fit + N / 2 - OFF[1]
                ln = rng.uniform(3, 7)
                self.bar((lx, ly - 1), (lx, ly + ln), 1.6, "glass", w1=1.0, prof="cyl")
                self.ellipse(lx, ly + ln + 1.2, 1.7 * _bold(), 2.0 * _bold(), "glass")
            return [(ndi.gaussian_filter((self.a > 0.5).astype(np.float32), 5) * 0.0, hx("#9ccf3e"))]
        if el == "shock":
            im = Image.new("L", (W, W), 0)
            d = ImageDraw.Draw(im)
            ys, xs = np.nonzero(sil)
            for k in range(3):
                i = rng.integers(len(xs))
                x, y = float(xs[i]), float(ys[i])
                path = [(x, y)]
                for j in range(5):
                    x += rng.uniform(-2, 4) * SS
                    y += rng.uniform(-4, 1) * SS
                    path.append((x, y))
                d.line(path, fill=255, width=SS + (1 if MODE == "hd" else SS))
            arc = np.asarray(im, np.float32) / 255.0
            self._paint(arc, flatn, "arc")
            return [(ndi.gaussian_filter(arc, 6) * 3.0, hx("#5cd2c0"))]
        if el == "frost":
            up = np.zeros_like(sil)
            sh = int(2.0 * SS)
            up[sh:] = sil[:-sh]
            rime = sil & ~up
            n = noise(self.seed + 52, 3, 1)
            rime = rime & (n > 0.35)
            rime = ndi.binary_opening(rime, iterations=1)
            self._paint(rime.astype(np.float32) * 0.9, flatn, "frost")
            return [(ndi.gaussian_filter(rime.astype(np.float32), 6) * 2.0, hx("#bfe8ff"))]
        return []

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
            mean = col[a > 0.3].mean(axis=0) if (a > 0.3).any() else 0
            col = np.clip((col - mean) * 1.25 + mean, 0, 255)
            # and lift the values: dark gunmetal sinks into the dark wells
            col = np.clip(255 * (col / 255) ** 0.8 + 6, 0, 255)
        if n >= 48:
            # keep the fine detail crisp after the box filter: light unsharp mask
            from PIL import ImageFilter as _IF
            im = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB").filter(_IF.UnsharpMask(radius=1.0, percent=55 if n == 96 else 40, threshold=1))
            col = np.asarray(im, np.float32)
            # crisp per-pixel grit (final-resolution, never blurred)
            rng = np.random.default_rng(self.seed * 13 + n)
            col = col * (0.95 + 0.1 * rng.random((n, n)))[..., None]
        solid = a > (0.3 if n <= 24 else 0.42)
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
        if n == 96:
            # soft contact shadow under the weapon (alpha < 230)
            sil0 = (solid | ring).astype(np.float32)
            shd = ndi.gaussian_filter(np.roll(np.roll(sil0, 2, axis=1), 3, axis=0), 1.8) * (1 - sil0)
            sm = shd > 0.02
            out[sm, :3] = INK
            out[sm, 3] = np.minimum(shd[sm] * 150, 120)
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
            bg = (ha > 1) & (ha > out[..., 3])
            out[bg, :3] = hc[bg]
            out[bg, 3] = np.minimum(ha[bg], 200)
        return np.clip(out, 0, 255).astype(np.uint8)


# =============================================================== the weapons
class Frame:
    """Gun-local drawing frame: u runs muzzle-ward (right), v runs down, in
    96-unit layout units; rotated by `deg` (negative = muzzle up-right) and
    scaled by `k` about the layout point `o`."""
    def __init__(self, ic, o, deg, k=1.0):
        self.ic, self.o, self.k = ic, o, k
        self.c, self.s = math.cos(math.radians(deg)), math.sin(math.radians(deg))

    def P(self, u, v=0.0):
        u, v = u * self.k, v * self.k
        return (self.o[0] + u * self.c - v * self.s, self.o[1] + u * self.s + v * self.c)

    def bar(self, u0, v0, u1, v1, w, mat, w1=None, **kw):
        self.ic.bar(self.P(u0, v0), self.P(u1, v1), w * self.k, mat, w1=None if w1 is None else w1 * self.k, **kw)

    def poly(self, pts, mat, **kw):
        self.ic.poly([self.P(u, v) for (u, v) in pts], mat, **kw)

    def ell(self, u, v, rx, ry, mat, **kw):
        x, y = self.P(u, v)
        self.ic.ellipse(x, y, rx * self.k, ry * self.k, mat, **kw)

    def screw(self, u, v, r=0.9):
        if not _detail():
            return
        x, y = self.P(u, v)
        self.ic.ellipse(x + 0.25, y + 0.3, r * 1.2, r * 1.2, "dark", dome=0.2)
        self.ic.ellipse(x, y, r, r, "steel", dome=0.9)
        # slot
        self.ic.bar((x - r * 0.7, y + r * 0.4), (x + r * 0.7, y - r * 0.4), 0.35, "dark")

    def slots(self, u0, u1, v, n, w=0.7, h=2.2, mat="dark"):
        """Row of short dark cuts across the part (serrations / vents)."""
        for i in range(n):
            uu = u0 + (u1 - u0) * (i + 0.5) / n
            self.bar(uu, v - h / 2, uu, v + h / 2, w, mat)

    def edge(self, u0, v0, u1, v1, w=0.5):
        """Bright rubbed edge line (worn metal catching light)."""
        if not _detail():
            return
        self.bar(u0, v0, u1, v1, w, "blade", prof="cyl")


def last_shift():
    """Ash Rook: RPG-pattern launcher. Long tube, flared venturi, wooden heat
    guard with bands, pistol grip + trigger guard, optic on the left rail,
    iron sights, and a loaded warhead with a booster ring."""
    ic = Icon(11)
    F = Frame(ic, (6, 70), -30, 0.86)
    # tube + venturi
    F.bar(6, 0, 78, 0, 9.0, "gun", prof="cyl")
    F.bar(-4, 0, 8, 0, 13.0, "dark", w1=9.5, prof="cyl")
    F.bar(-4.6, 0, -3.4, 0, 13.4, "steel", prof="cyl")
    # wooden heat guard (two halves) with metal bands
    F.bar(30, 0, 54, 0, 11.4, "wood", prof="cyl")
    for uu in (30, 42, 54):
        F.bar(uu - 0.8, 0, uu + 0.8, 0, 12.0, "red", prof="cyl")
    # rear grip + trigger
    F.poly([(56, 4), (61, 4), (63, 17), (58.5, 18)], "wood", bevel=1.4)
    F.bar(51, 5, 51, 10, 1.4, "dark")
    F.bar(49, 10.5, 56, 10.5, 1.2, "dark")
    F.bar(52.5, 5, 53.5, 8.5, 1.0, "steel")
    # front grip
    F.poly([(20, 4), (24, 4), (24.5, 13), (21, 13.5)], "wood", bevel=1.2)
    # optic on the left rail
    F.poly([(36, -6), (50, -6), (50, -11.5), (36, -11.5)], "dark", bevel=1.2)
    F.bar(33, -9, 37, -9, 3.6, "gun", prof="cyl")
    F.ell(32.6, -9, 1.0, 1.7, "glass")
    F.bar(44, -5, 46, -5, 1.6, "steel")
    F.screw(48, -8.6, 0.8)
    # iron sights
    F.bar(66, -4.5, 66, -7.5, 1.0, "steel")
    F.bar(57, -4.5, 57, -6.5, 1.6, "steel")
    # warhead: booster tube, olive body, cone, nose fuse
    F.bar(77, 0, 82, 0, 6.5, "steel", prof="cyl")
    F.bar(81, 0, 90, 0, 13.0, "olive", prof="cyl")
    F.bar(89.5, 0, 103, 0, 12.6, "red", w1=3.0, prof="cyl")
    F.bar(102.5, 0, 106, 0, 2.6, "brass", w1=1.4, prof="cyl")
    F.bar(84, 0, 85, 0, 13.4, "dark", prof="cyl")
    # sling + weld patch
    F.bar(14, 4.5, 26, 6.5, 1.6, "leather", prof="cyl")
    F.edge(8, -4.0, 29, -4.0, 0.45)
    F.edge(55, -4.0, 76, -4.0, 0.45)
    ic.patch(*F.P(20, 0.5), 7, 5.5, math.radians(-30), "steel")
    ic.weld(F.P(13, -3.6), F.P(13, 3.6), 0.9)
    ic.scratches(count=30)
    ic.save("last_shift")


def bellwether():
    """Vesper Thorn: bolt-action rifle with a vial feed. Walnut stock with
    comb and recoil pad, receiver, bolt handle, trigger + guard, scope on
    rings with turrets, free-floated barrel with a muzzle brake."""
    ic = Icon(23)
    F = Frame(ic, (4, 70), -30, 0.9)
    # stock: butt, wrist, forend
    F.poly([(0, -3), (6, -4.5), (24, -2.6), (32, -1.5), (32, 4.5), (26, 5), (16, 9.5), (2, 10.5), (0, 9)], "wood", bevel=2.2)
    F.bar(-1.2, -3.0, -1.2, 10.0, 2.4, "dark")
    F.bar(34, 1.6, 62, 1.6, 4.4, "wood", w1=3.6)
    # receiver + bolt
    F.poly([(30, -3.2), (48, -3.2), (49, 1.0), (30, 1.4)], "gun", bevel=1.4)
    F.slots(33, 41, -1.2, 1, w=6.0, h=1.0, mat="dark")
    F.bar(36, -0.4, 39, 5.5, 1.3, "steel", prof="cyl")
    F.ell(39.4, 6.3, 1.5, 1.5, "steel")
    # trigger + guard + magazine plate
    F.bar(36, 4.2, 37.4, 7.6, 0.9, "steel")
    F.bar(33, 8.4, 41.5, 8.4, 1.0, "dark")
    F.bar(41.5, 8.4, 42.5, 4.5, 1.0, "dark")
    # vial cartridge under the receiver
    F.bar(44, 4.0, 44, 12.5, 4.4, "glass", prof="cyl")
    F.bar(44, 3.0, 44, 4.8, 5.0, "brass", prof="cyl")
    F.bar(44, 12.0, 44, 13.6, 4.8, "brass", prof="cyl")
    # barrel + brake
    F.bar(48, -1.4, 99, -1.4, 2.6, "gun", w1=2.1, prof="cyl")
    F.bar(97, -1.4, 104, -1.4, 3.6, "dark", prof="cyl")
    F.slots(98.5, 103, -1.4, 3, w=0.7, h=2.6)
    F.bar(90, -2.8, 90, -4.2, 1.2, "steel")
    # scope on rings
    F.bar(30, -8, 60, -8, 3.8, "dark", prof="cyl")
    F.bar(26, -8, 32, -8, 5.0, "dark", w1=4.0, prof="cyl")
    F.bar(56, -8, 63, -8, 4.0, "dark", w1=6.0, prof="cyl")
    F.ell(63.2, -8, 0.9, 2.6, "glass")
    F.bar(43, -10, 43, -12, 2.6, "gun", prof="box")
    for uu in (35, 52):
        F.bar(uu, -6, uu, -3, 2.0, "gun")
        F.screw(uu, -4.6, 0.6)
    F.edge(30, -9.6, 58, -9.6, 0.4)
    F.edge(49, -2.6, 96, -2.4, 0.35)
    # sling swivel
    F.bar(14, 9.4, 14, 11.4, 1.2, "steel")
    # bell on a cord (legendary)
    if ic.leg:
        F.bar(60, 3.5, 61, 12, 0.9, "leather")
        F.poly([(58, 12), (64, 12), (66, 19), (56, 19)], "brass", bevel=1.6)
        F.ell(61, 19.8, 1.4, 1.2, "dark")
    ic.patch(*F.P(12, 3), 6, 4.5, math.radians(-30), "steel")
    ic.scratches(count=22)
    g = ic.glow(*F.P(44, 8), 9, "#9ccf3e")
    ic.save("bellwether", extra_glows=[g])


def censer():
    """Sister Cinder: AR-pattern carbine. Collapsible stock on a buffer tube,
    lower with mag well and a curved magazine, angled pistol grip, upper with
    ejection port, forward assist and charging handle, carry handle sight,
    vented handguard, front sight post, can suppressor."""
    ic = Icon(53)
    F = Frame(ic, (3, 64), -28, 0.86)
    # stock + buffer tube
    F.bar(10, -1, 28, -1, 3.4, "gun", prof="cyl")
    F.poly([(0, -4), (14, -3.4), (14, 2.6), (7, 7.5), (0, 8)], "red", bevel=1.6)
    F.bar(-0.8, -4, -0.8, 8, 1.8, "dark")
    # lower receiver, mag well, magazine
    F.poly([(27, -1.5), (50, -1.5), (50, 3.5), (44, 4.5), (31, 4.5), (27, 3)], "gun", bevel=1.2)
    F.poly([(40, 3.5), (47, 3.5), (49.5, 16), (43, 17.5)], "dark", bevel=1.4)
    F.slots(41.5, 47, 8, 1, w=4.0, h=0.6, mat="gun")
    # pistol grip + trigger + guard
    F.poly([(31, 3.5), (36, 3.5), (34.5, 14), (29.5, 13)], "red", bevel=1.4)
    F.bar(37.6, 3.8, 38.6, 7.2, 0.9, "steel")
    F.bar(35.5, 8.0, 42, 8.0, 0.9, "dark")
    # upper: receiver, ejection port, forward assist, charging handle
    F.poly([(27, -7), (52, -7), (52, -1.4), (27, -1.4)], "gun", bevel=1.4)
    F.poly([(37, -5.4), (44, -5.4), (44, -3.0), (37, -3.0)], "dark", bevel=0.6)
    F.ell(48, -2.6, 1.3, 1.3, "steel")
    F.bar(25, -6.4, 29, -6.4, 1.6, "steel")
    # carry handle + rear sight
    F.poly([(29, -7), (44, -7), (44, -11), (41, -11.6), (31, -11.6), (29, -10)], "gun", bevel=1.2)
    F.slots(32, 40, -9.4, 1, w=7.0, h=1.4, mat="dark")
    # handguard with vents
    F.bar(52, -3.4, 76, -3.4, 7.0, "red", prof="cyl")
    F.slots(55, 74, -3.4, 7, w=1.0, h=2.6)
    # front sight post + barrel stub
    F.bar(74, -7, 74, -11, 1.4, "gun")
    F.bar(72, -7, 77, -7, 1.2, "gun")
    F.bar(76, -3.4, 80, -3.4, 2.4, "gun", prof="cyl")
    # suppressor
    F.bar(79, -3.4, 104, -3.4, 7.0, "gun", prof="cyl")
    for uu in (84, 92, 100):
        F.bar(uu - 0.4, -3.4, uu + 0.4, -3.4, 7.4, "dark", prof="cyl")
    F.bar(103.5, -3.4, 105, -3.4, 5.0, "dark", prof="cyl")
    F.edge(27, -6.6, 51, -6.6, 0.4)
    F.edge(80, -6.4, 103, -6.4, 0.4)
    for (uu, vv) in ((30, 1.5), (48, 1.5), (46, -5.6)):
        F.screw(uu, vv, 0.6)
    ic.patch(*F.P(64, -3.4), 7, 5, math.radians(-28), "steel")
    ic.weld(F.P(57, 0), F.P(70, 0), 0.8)
    ic.scratches(count=26)
    if not ic.leg:
        ic.save("censer")
        return
    # chain + censer (legendary)
    for i in range(4):
        x, y = F.P(62, 1 + i * 3.6)
        if i % 2:
            ic.ellipse(x, y, 1.0, 2.0, "steel", dome=0.6)
        else:
            ic.ellipse(x, y, 1.7, 1.2, "steel", dome=0.6)
    cx, cy = F.P(62, 19)
    ic.ellipse(cx, cy, 6.0, 5.0, "brass")
    ic.bar((cx - 6, cy - 1), (cx + 6, cy - 1), 1.8, "dark")
    for dx in (-3, 0, 3):
        ic.ellipse(cx + dx, cy + 1.6, 0.9, 0.9, "ember")
    sm = np.zeros((W, W), np.float32)
    for k in range(5):
        sx, sy, r = cx + 2 + k * 1.6 + math.sin(k) * 2, cy - 7 - k * 6, 3.5 + k * 0.8
        sm = np.maximum(sm, np.clip(1 - np.sqrt((ic.xx - sx) ** 2 + (ic.yy - sy) ** 2) / r, 0, 1) * 0.5)
    g = ic.glow(cx, cy, 11, "#e8761c", 0.8)
    ic.save("censer", extra_glows=[g, (sm, hx("#8f877e"))])


def mayday():
    """Helm Wisp: service-pattern pistol (slide with serrations, ejection
    port, sights; frame with trigger guard, hammer, slide stop, checkered
    grip panels and screws, magazine base) with a flare launcher clamped
    under the dust cover."""
    ic = Icon(83)
    F = Frame(ic, (14, 46), -14, 1.0)
    # grip + panels
    F.poly([(8, 7), (22, 7), (25, 33), (21, 35), (11, 35), (8, 31)], "dark", bevel=1.8)
    F.poly([(10.5, 10), (20, 10), (22.5, 30), (12.5, 31)], "leather", bevel=1.6)
    for vv in range(12, 30, 3):
        F.bar(11.5, vv, 22, vv + 0.4, 0.45, "dark")
    F.screw(14, 13, 0.8)
    F.screw(18, 28, 0.8)
    F.bar(10, 34.5, 23, 34.5, 2.6, "gun")
    # frame + trigger guard + trigger
    F.poly([(4, 1), (50, 1), (50, 6), (26, 7.5), (8, 7.5)], "gun", bevel=1.4)
    F.bar(24, 7, 25, 16, 1.6, "gun")
    F.bar(25, 16, 36, 15, 1.6, "gun")
    F.bar(36, 15, 39, 7, 1.6, "gun")
    F.bar(28.5, 7.5, 30, 12.5, 1.1, "steel", w1=0.8)
    F.ell(30, 4.5, 1.2, 1.2, "steel")
    # hammer
    F.poly([(1, -4), (5, -4.5), (5.5, 1), (2, 1.5)], "dark", bevel=0.8)
    # slide
    F.poly([(3, -8.5), (60, -8.5), (61, -2), (60, 1), (3, 1)], "gun", bevel=1.8)
    F.slots(6, 15, -3.8, 7, w=0.6, h=7.0)
    F.poly([(30, -8.2), (40, -8.2), (40, -5.4), (30, -5.4)], "dark", bevel=0.6)
    F.bar(5, -8.4, 8, -8.4, 2.0, "dark")
    F.bar(55, -8.4, 57, -8.4, 1.6, "steel")
    F.ell(60.4, -3.6, 0.9, 2.0, "dark", dome=0.2)
    F.edge(4, -8.0, 59, -8.0, 0.45)
    # flare launcher under the dust cover
    F.bar(34, 1.5, 44, 1.5, 3.0, "dark")
    F.bar(38, 4.8, 74, 4.8, 7.2, "signal", prof="cyl")
    F.bar(72, 4.8, 75, 4.8, 7.8, "dark", prof="cyl")
    F.ell(75.3, 4.8, 1.4, 3.2, "dark", dome=0.2)
    F.ell(75.6, 4.8, 0.8, 2.0, "ember", dome=0.2)
    F.bar(48, 1.6, 48, 8.4, 1.0, "steel", prof="cyl")
    F.bar(62, 1.6, 62, 8.4, 1.0, "steel", prof="cyl")
    F.screw(48, 1.6, 0.7)
    F.screw(62, 1.6, 0.7)
    ic.patch(*F.P(50, -4.5), 8, 5, math.radians(-14), "olive")
    ic.scratches(count=28)
    g = ic.glow(*F.P(76, 4.8), 8, "#ff8a2a", 0.7)
    ic.save("mayday", extra_glows=[g])


def gravedigger():
    """Pebble: scrap-slab maul on a pipe haft, painted X, rebar spikes."""
    ic = Icon(37)
    # haft
    ic.bar((12, 88), (52, 36), 5.5, "steel", prof="cyl")
    ic.bar((12, 88), (24, 72), 6.5, "tape", prof="cyl")
    ic.bar((10, 90.5), (13.5, 86.5), 8, "dark", prof="cyl")
    # threaded coupling + hose clamp
    ic.bar((40, 51.6), (45, 45.2), 7.4, "steel", prof="cyl")
    if _detail():
        for t in range(5):
            x0, y0 = 40.6 + t, 50.8 - t * 1.28
            ic.bar((x0 - 2.8, y0 - 2.2), (x0 + 2.8, y0 + 2.2), 0.45, "dark")
    ic.bar((28, 67), (29.5, 65), 7.8, "steel", prof="cyl")
    ic.rivet(29.8, 64.0, 1.0)
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
    if _detail():
        for t in range(5):
            x0, y0 = 41 + t * 2, 61 - t * 2
            ic.bar((x0 - 1.8, y0 - 1.8), (x0 + 1.8, y0 + 1.8), 0.5, "dark")
    # hydraulic piston: cylinder + bright rod into the knuckle block
    ic.bar((30, 50), (44, 36), 3.6, "dark", prof="cyl")
    ic.bar((43, 37), (52, 28), 1.6, "blade", prof="cyl")
    ic.ellipse(30, 50, 2.2, 2.2, "steel")
    ic.scratches(count=26)
    if not ic.leg:
        ic.save("live_line")
        return
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
    for uu in range(-19, -2, 3):
        ic.bar(P(uu, -3.4), P(uu, 3.4), 0.6, "dark")
    ic.ellipse(*P(-28.5, 0), 2.6, 2.6, "steel", dome=0.8)
    ic.ellipse(*P(-6, -3.6), 1.2, 1.2, "red", dome=0.9)
    if _detail():
        ic.bar(P(6, 3.4), P(56, 2.2), 0.6, "blade", prof="cyl")
        ic.bar(P(4, -5.8), P(50, -5.8), 0.5, "blade", prof="cyl")
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
        if _detail():
            ic.bar(Q(30, 3.0), Q(88, 2.6), 0.55, "blade", prof="cyl")
        for t in range(8, 24, 3):
            ic.bar(Q(t, -3.4), Q(t, 3.4), 0.55, "dark")
        ic.bar(Q(27, -4.2), Q(31, -4.2), 0.9, "dark")
        ic.rivet(*Q(15), 1.0, "brass")
    # coin pinned at the cross
    if ic.leg:
        ic.ellipse(48, 48, 6.5, 6.5, "brass")
        ic.ellipse(48, 48, 3.2, 3.2, "rust", dome=0.4)
    ic.scratches(count=26)
    ic.save("twin_debts")


HERO_FN = {"ash_rook": last_shift, "vesper_thorn": bellwether, "pebble": gravedigger,
           "bolt_juno": live_line, "sister_cinder": censer, "quill_marrow": bonesaw,
           "nyx_caldera": twin_debts, "helm_wisp": mayday}
RESULT = None


def _margin(arr):
    ys, xs = np.nonzero(arr[..., 3] == 255)
    n = arr.shape[0]
    return min(xs.min(), ys.min(), n - 1 - xs.max(), n - 1 - ys.max())


def _bbox_units(ic):
    ys, xs = np.nonzero(ic.a > 0.4)
    return xs.min() / SS, ys.min() / SS, xs.max() / SS, ys.max() / SS


def build(hero, kind, element=""):
    """Paint one weapon finish at the current MODE. The layout is auto-fitted:
    a measuring pass finds the silhouette box, then it is centred and scaled to
    fill the icon (96 px leaves room for the halo / contact shadow); set sizes
    then shrink until the outline keeps a 1 px margin. Returns RGBA."""
    global KIND, ELEMENT, FIT_SET, OFF
    KIND, ELEMENT = kind, element
    n = {"hd": 96, "s48": 48, "s24": 24}[MODE]
    key = (hero, kind, element)
    if key not in _FITS:
        FIT_SET, OFF = 1.0, (0.0, 0.0)
        HERO_FN[hero]()
        x0, y0, x1, y1 = _bbox_units(RESULT[0])
        span = max(x1 - x0, y1 - y0)
        _FITS[key] = ((N / 2 - (x0 + x1) / 2, N / 2 - (y0 + y1) / 2), span)
    OFF, span = _FITS[key]
    target = {"hd": 84.0, "s48": 92.0, "s24": 92.0}[MODE]
    FIT_SET = target / span
    while True:
        HERO_FN[hero]()
        ic, halo, glows = RESULT
        arr = ic._render(n, halo, glows)
        if MODE == "hd" or _margin(arr) >= 1 or FIT_SET < 0.5:
            return arr
        FIT_SET *= 0.97


_FITS = {}


def save(arr, path):
    Image.fromarray(arr, "RGBA").save(path)


def job(hero):
    global MODE
    leg = HERO_FN[hero].__name__
    for MODE in ("hd", "s48", "s24"):
        if MODE == "hd":
            save(build(hero, "legendary"), os.path.join(OUT, "legendary_%s.png" % leg))
            save(build(hero, "base"), os.path.join(WPN, "weapon_%s.png" % hero))
            continue
        sz = MODE[1:]
        arr = build(hero, "legendary")
        save(arr, os.path.join(SET, sz, "leg_%s.png" % leg))
        save(arr, os.path.join(SET, sz, "wpn_%s_%s.png" % (hero, leg)))
        for vid, kind, el in VARIANTS[hero]:
            save(build(hero, kind, el), os.path.join(SET, sz, "wpn_%s_%s.png" % (hero, vid)))
    return hero


if __name__ == "__main__":
    import multiprocessing as mp
    with mp.Pool(min(8, os.cpu_count() or 1)) as pool:
        for h in pool.imap_unordered(job, list(HERO_FN)):
            print("ok", h)
