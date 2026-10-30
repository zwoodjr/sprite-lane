"""Repaint pass for unit sprite strips: keeps every existing frame, pose,
silhouette and weapon tip, and re-renders the pixels toward the painted
icons / puppet bake look:

  * stair-steps softened: each palette region is upscaled 4x and its
    boundary smoothed (per-colour blurred masks, arg-max), alpha likewise
  * muted, earthy palette with the same hue identity (glows stay lit)
  * volume from a pseudo height map (distance to the silhouette and to part
    boundaries + the old shading), lit from the top-left, rim darkening
  * material texture, grime and metal brushing / specular / edge wear in
    body-relative coordinates (per-frame offset found by phase correlation
    against the unit's reference frame, so the texture does not crawl)
  * soft glow round emissive colours (toxic green, embers)

The source is always the original art at SRC_REV (read through git), so
re-running never compounds.

    python3 tools/repaint_sprites.py <unit dir under assets/sprites> ... [--out DIR] [--light]
    e.g. enemies/rad_gator;  --light = palette mute + light grime only
    --crisp = the --light palette tone-down applied per pixel on the original
    grid (pets): alpha copied exactly, no grime, no resampling, contrast
    stretched round the unit's mid value plus a 1 px unsharp so eyes, nose,
    collar and fur edges stay sharp
    --real = crisp palette, shapes rebuilt at 4x with Scale2x x2 (edge
    preserving, no blur), then painted: top-left volume, fur strokes along
    the body (LIC, body-anchored noise), hair strands on the silhouette,
    wet specular on eyes / nose / dark leather, paw contact occlusion;
    Lanczos down to 2x frame size (pets ship 256 px frames; pet.gd draws
    them at the same world size) + light unsharp, alpha thresholded (hard)
"""
import colorsys
import io
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, ".."))
SPR = os.path.join(GAME, "assets", "sprites")
SRC_REV = "358ad4a7fa74432abd95639229527d720d9277e8"
K = 4                               # supersample
REAL_OUT = 2                        # --real frame size multiple
LIGHT = np.array([-0.55, -0.68, 0.48])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def git_png(rel):
    try:
        b = subprocess.run(["git", "show", "%s:game/assets/sprites/%s" % (SRC_REV, rel)], cwd=GAME,
                           capture_output=True, check=True).stdout
        return Image.open(io.BytesIO(b)).convert("RGBA")
    except subprocess.CalledProcessError:
        return Image.open(os.path.join(SPR, rel)).convert("RGBA")


def noise(shape, scale, seed, octaves=3):
    rng = np.random.default_rng(seed)
    out = np.zeros(shape, np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(1.0, scale / (2 ** o))
        h, w = int(shape[0] / s) + 3, int(shape[1] / s) + 3
        g = rng.random((h, w)).astype(np.float32)
        g = cv2.resize(g, (int(w * s), int(h * s)), interpolation=cv2.INTER_CUBIC)[:shape[0], :shape[1]]
        out += g * amp
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.mean()) / (out.std() + 1e-6) * 0.5 + 0.5


# ------------------------------------------------------------------ palette
def classify(rgb):
    r, g, b = [c / 255.0 for c in rgb]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    v = max(r, g, b)
    hd = h * 360
    if s > 0.45 and v > 0.5 and 55 <= hd <= 115 and l > 0.35:
        return "glow"
    if s > 0.55 and v > 0.8 and (hd < 45 or hd > 330) and l > 0.55:
        return "glow"
    if l < 0.11:
        return "ink"
    if 70 <= hd <= 150 and s > 0.3:
        return "toxic"
    if (hd <= 40 or hd >= 345) and 0.18 <= s <= 0.75 and 0.42 <= l <= 0.85:
        return "skin"
    if (s < 0.22 or (190 <= hd <= 235 and s < 0.35)) and l > 0.12:
        return "metal"
    if 8 <= hd <= 32 and s > 0.35 and l < 0.42:
        return "rust"
    return "organic"


def remap(rgb, kind):
    r, g, b = [c / 255.0 for c in rgb]
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if kind == "glow":
        s, l = s * 0.85, l * 0.92
    elif kind == "skin":
        s, l = s * 0.78, 0.04 + l * 0.94
    elif kind == "toxic":
        s, l = s * 0.8, l * 1.05
    elif kind == "ink":
        s, l = s * 0.5, l
    elif kind == "metal":
        s, l = s * 0.5, 0.12 + l * 0.85
    elif kind == "rust":
        s, l = s * 0.62, l * 0.95
    else:
        s, l = s * 0.7, 0.08 + l * 0.9
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    c = np.array([r, g, b]) * 255
    if kind not in ("glow", "ink", "toxic", "skin"):
        c = c * 0.92 + np.array([104, 92, 74]) * 0.08   # earthy cast
    return c


# ------------------------------------------------------------------- frame
class Unit:
    def __init__(self, rel):
        self.rel = rel
        self.name = os.path.basename(rel)
        self.files = sorted(f for f in os.listdir(os.path.join(SPR, rel)) if f.endswith(".png"))
        self.strips = {f: git_png(os.path.join(rel, f)) for f in self.files}
        # one shared palette for the whole unit (stable labels across states)
        allpx = np.concatenate([np.asarray(im).reshape(-1, 4) for im in self.strips.values()])
        allpx = allpx[allpx[:, 3] > 0][:, :3]
        cols, counts = np.unique(allpx, axis=0, return_counts=True)
        self.detailed = len(cols) > 48
        self.pal = cols.astype(np.float32)
        self.key = {int(c[0]) << 16 | int(c[1]) << 8 | int(c[2]): i for i, c in enumerate(cols)}
        self.kind = [classify(tuple(c)) for c in self.pal]
        self.new = np.array([remap(tuple(c), k) for c, k in zip(self.pal, self.kind)], np.float32)
        # metal-heavy units get sparse rust so they keep their colour identity
        cnt = {tuple(c): n for c, n in zip(cols, counts)}
        met_px = sum(cnt.get(tuple(c.astype(int)), 0) for c, k in zip(self.pal, self.kind) if k == "metal")
        self.metal_frac = met_px / max(1, counts.sum())
        self.rust_t = (0.84, 0.84) if self.metal_frac > 0.2 else (0.7, 0.72)
        ref = self.strips.get(self.name + "_idle.png") or next(iter(self.strips.values()))
        fs = ref.height
        self.ref_a = np.asarray(ref)[:, :fs, 3].astype(np.float32) / 255.0
        big = (fs * K * 2, fs * K * 2)
        seed = sum(map(ord, self.name))
        self.n_fine = noise(big, 3, seed)
        self.n_mid = noise(big, 14, seed + 1)
        self.n_big = noise(big, 44, seed + 2)
        self.n_scale = noise(big, 7, seed + 3, 1)
        self.n_brush = cv2.resize(noise((big[0], big[1] // 8), 2, seed + 4, 2), (big[1], big[0]))
        self.n_streak = cv2.resize(noise((big[0] // 10, big[1]), 3, seed + 5, 2), (big[1], big[0]))

    def labels(self, rgb):
        r = rgb.astype(np.int64)
        packed = r[..., 0] << 16 | r[..., 1] << 8 | r[..., 2]
        flat = packed.ravel()
        out = np.zeros(flat.shape, np.int32)
        for v in np.unique(flat):
            out[flat == v] = self.key.get(int(v), 0)
        return out.reshape(packed.shape)

    def frame(self, fr, fs):
        a0 = fr[..., 3].astype(np.float32) / 255.0
        if a0.max() == 0:
            return fr
        rgb0 = fr[..., :3].astype(np.float32)
        lab = self.labels(rgb0)
        # body-relative offset (phase correlation against the reference frame)
        try:
            (dx, dy), _ = cv2.phaseCorrelate(self.ref_a.astype(np.float64), a0.astype(np.float64))
        except cv2.error:
            dx, dy = 0.0, 0.0
        W = fs * K
        # ---- smooth region boundaries at 4x
        up_a = cv2.resize(a0, (W, W), interpolation=cv2.INTER_NEAREST)
        cover = np.clip((cv2.GaussianBlur((up_a > 0).astype(np.float32), (0, 0), 2.2) - 0.5) * 3.2 + 0.5, 0, 1)
        a = cover * cv2.GaussianBlur(cv2.dilate(up_a, np.ones((K + 1, K + 1), np.uint8)), (0, 0), 1.5)
        up_l = cv2.resize(lab.astype(np.int32), (W, W), interpolation=cv2.INTER_NEAREST)
        if self.detailed:
            # fine hand-pixelled art: keep every pixel, just resample smoothly
            L = up_l
            c128 = self.new[lab] * a0[..., None]
            cu = cv2.resize(c128.astype(np.float32), (W, W), interpolation=cv2.INTER_CUBIC)
            au = np.clip(cv2.resize(a0, (W, W), interpolation=cv2.INTER_CUBIC), 1e-3, 1)
            col = np.clip(cu / au[..., None], 0, 255)
            col = np.where((up_a > 0)[..., None], col, self.new[L])
        else:
            present = np.unique(lab[a0 > 0])
            best = np.full((W, W), -1.0, np.float32)
            L = np.zeros((W, W), np.int32)
            for k in present:
                m = cv2.GaussianBlur((up_l == k).astype(np.float32) * (up_a > 0), (0, 0), 2.0)
                sel = m > best
                best = np.where(sel, m, best)
                L = np.where(sel, k, L)
            col = self.new[L]
        kind = np.array(self.kind)[L]
        old_lum = cv2.GaussianBlur(cv2.resize(rgb0.mean(-1), (W, W), interpolation=cv2.INTER_CUBIC) / 255.0, (0, 0), 1.5)
        # ---- pseudo height: silhouette volume + part volume + old shading
        solid = (cover > 0.5).astype(np.uint8)
        d_out = cv2.distanceTransform(solid, cv2.DIST_L2, 5)
        if self.detailed:
            lum = cv2.resize(rgb0.mean(-1), (W, W), interpolation=cv2.INTER_NEAREST)
            edge = (cv2.morphologyEx(lum, cv2.MORPH_GRADIENT, np.ones((3, 3))) > 40) | (solid == 0)
        else:
            edge = (cv2.morphologyEx(L.astype(np.float32), cv2.MORPH_GRADIENT, np.ones((3, 3))) > 0) | (solid == 0)
        d_part = cv2.distanceTransform((~edge).astype(np.uint8), cv2.DIST_L2, 5)
        h = 0.75 * np.sqrt(np.clip(d_out / (9.0 * K), 0, 1)) + 0.3 * np.sqrt(np.clip(d_part / (3.0 * K), 0, 1)) + 0.35 * old_lum
        h = cv2.GaussianBlur(h, (0, 0), 1.6)
        gy, gx = np.gradient(h * 7.0 * K / 2.0)
        nz = np.ones_like(h)
        nrm = np.stack([-gx, -gy, nz], -1)
        nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
        ndl = np.clip((nrm * LIGHT).sum(-1), 0, 1)
        if self.detailed:
            shade = 0.72 + 0.42 * ndl
            rim = np.clip(1 - d_out / (1.2 * K), 0, 1) * 0.15
            crease = np.zeros_like(shade)
        else:
            shade = 0.36 + 1.0 * ndl
            rim = np.clip(1 - d_out / (1.6 * K), 0, 1) * 0.35
            crease = np.clip(1 - d_part / (1.2 * K), 0, 1) * 0.18
        # ---- texture in body space
        ys, xs = np.mgrid[0:W, 0:W].astype(np.float32)
        mx = (xs - dx * K + W / 2).astype(np.float32)
        my = (ys - dy * K + W / 2).astype(np.float32)
        smp = lambda f: cv2.remap(f, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        nf, nm, nb, nsc, nbr, nst = smp(self.n_fine), smp(self.n_mid), smp(self.n_big), smp(self.n_scale), smp(self.n_brush), smp(self.n_streak)
        skn = kind == "skin"
        org = kind == "organic"
        met = kind == "metal"
        rst = kind == "rust"
        glw = (kind == "glow") | (kind == "toxic")
        tex = 1 + (nf - 0.5) * 0.22 + (nm - 0.5) * 0.28
        cell = np.abs(np.sin(mx / 5.0 + 0.6 * np.sin(my / 4.0)) * np.sin(my / 4.4 + 0.5 * np.sin(mx / 6.0)))
        tex = np.where(org, tex * (0.9 + 0.2 * cell), tex)
        tex = np.where(met, 1 + (nbr - 0.5) * 0.18 + (nm - 0.5) * 0.14, tex)
        tex = np.where(skn, 1 + (nm - 0.5) * 0.06, tex)
        if self.detailed:
            tex = 1 + (tex - 1) * 0.6
        grime = np.clip((nb - 0.5) * 2.2, 0, 1) * 0.2 + np.clip(ys / W - 0.6, 0, 1) * 0.3
        col = col * tex[..., None]
        grime_c = np.array([62, 50, 38], np.float32)
        if self.detailed:
            grime = grime * 0.6
        gm = (grime * (~glw) * np.where(skn, 0.35, 1.0))[..., None]
        col = col * (1 - gm * 0.55) + grime_c * gm * 0.55
        # rust on metal: vertical run-off streaks plus a few distinct patches
        streak = met & (nst > self.rust_t[0]) & (nm > 0.35)
        patch = met & (nm > self.rust_t[1]) & (nb > 0.45)
        rmask = streak | patch
        rust_c = np.array([118, 64, 36], np.float32) * (0.85 + 0.3 * nf)[..., None]
        col = np.where(rmask[..., None], col * 0.2 + rust_c * 0.8, col)
        edge_r = met & ~rmask & (cv2.dilate(rmask.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)
        col = np.where(edge_r[..., None], col * 0.72, col)
        lit = shade[..., None] * (1 - rim - crease)[..., None]
        col = np.where(glw[..., None], col * (0.85 + 0.3 * ndl[..., None]), col * lit)
        # specular breakup + edge wear on metal
        spec = (ndl ** 6) * np.clip(0.3 + 1.2 * (nm - 0.3), 0, 1) * np.where(nf > 0.72, 0.3, 1.0)
        wear = np.clip(1 - d_part / (1.0 * K), 0, 1) * (ndl > 0.55) * (nf > 0.45)
        col = col + (met | rst)[..., None] * (255 * (spec * 0.2 + wear * 0.1))[..., None]
        col = col + org[..., None] * (255 * (ndl ** 10) * 0.06)[..., None]
        # ---- glow halo
        g1 = np.isin(lab, [i for i, k in enumerate(self.kind) if k in ("glow", "toxic")]) & (a0 > 0)
        cc, ncc = ndi.label(g1)
        big_ids = [i for i in range(1, ncc + 1) if (cc == i).sum() > 40]
        spill1 = np.isin(cc, big_ids)
        spill = cv2.resize(spill1.astype(np.uint8), (W, W), interpolation=cv2.INTER_NEAREST) > 0
        if spill.any():
            col = np.where(spill[..., None], col * (0.8 + 0.4 * nm[..., None]) * (0.9 + 0.2 * nf[..., None]), col)
            a = np.where(spill, a * (0.55 + 0.3 * nm), a)
        gmask = ((kind == "glow") & (a > 0.3) & ~spill).astype(np.float32) * a
        out_a = a
        if gmask.any():
            gcol = (self.new[L] * gmask[..., None]).sum((0, 1)) / max(gmask.sum(), 1)
            halo = cv2.GaussianBlur(gmask, (0, 0), 2.0 * K) * 2.4
            halo = np.clip(halo, 0, 0.6)
            col = col + gcol * halo[..., None] * 0.35 * (1 - gmask[..., None])
            out_a = np.maximum(a, halo * 0.55)
            col = np.where((a < 0.05)[..., None], gcol, col)
        col = np.clip(col, 0, 255)
        # ---- back to frame size (premultiplied box filter) + light sharpen
        pm = np.concatenate([col * out_a[..., None], out_a[..., None] * 255], -1)
        sm = pm.reshape(fs, K, fs, K, 4).mean((1, 3))
        aa = sm[..., 3] / 255.0
        c = np.where(aa[..., None] > 1e-3, sm[..., :3] / np.maximum(aa[..., None], 1e-3), 0)
        bl = cv2.GaussianBlur(c, (0, 0), 0.8)
        if self.detailed:
            # put the original 1 px detail back (faces, straps, rivets)
            b1 = self.new[lab].astype(np.float32)
            hi = b1 - cv2.GaussianBlur(b1, (0, 0), 1.0)
            c = np.clip(c + hi * 1.1 * (a0[..., None] > 0), 0, 255)
        else:
            c = np.clip(c + (c - bl) * 0.45, 0, 255)
        # exposure match: keep the frame's overall value close to the muted
        # original so dark metal units don't sink into mud
        ref = self.new[lab].mean(-1)
        w0 = a0 > 0
        if w0.any():
            tgt = ref[w0].mean() * 0.9
            cur = (c.mean(-1) * aa).sum() / max(aa.sum(), 1e-3)
            c = np.clip(c * np.clip(tgt / max(cur, 1.0), 0.95, 1.15), 0, 255)
        out = np.concatenate([c, aa[..., None] * 255], -1)
        return np.clip(out, 0, 255).astype(np.uint8)

    def light(self, fr, fs):
        """Light pass (pets): mute saturation and brightness toward the
        earthy palette, keep darks and contrast, a little low-frequency grime;
        pixels, alpha and outlines untouched."""
        a0 = fr[..., 3]
        if a0.max() == 0:
            return fr
        rgb = fr[..., :3].astype(np.float32) / 255.0
        hls = cv2.cvtColor(rgb, cv2.COLOR_RGB2HLS)
        h, l, s_ = hls[..., 0], hls[..., 1], hls[..., 2]
        s_ = s_ * 0.76
        l = np.clip(0.93 * l ** 1.04, 0, 1)
        out = cv2.cvtColor(np.stack([h, l, s_], -1), cv2.COLOR_HLS2RGB) * 255
        out = out * 0.92 + np.array([104, 92, 74], np.float32) * 0.08
        try:
            (dx, dy), _ = cv2.phaseCorrelate(self.ref_a.astype(np.float64), (a0 / 255.0).astype(np.float64))
        except cv2.error:
            dx, dy = 0.0, 0.0
        ys, xs = np.mgrid[0:fs, 0:fs].astype(np.float32)
        mx, my = (xs - dx) * K + fs * K / 2, (ys - dy) * K + fs * K / 2
        nb = cv2.remap(self.n_big, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        nm = cv2.remap(self.n_mid, mx.astype(np.float32), my.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
        g = (np.clip((nb - 0.5) * 2, 0, 1) * 0.1 + (nm - 0.5) * 0.06 + np.clip(ys / fs - 0.62, 0, 1) * 0.3)[..., None]
        out = out * (1 - g) + np.array([62, 50, 38], np.float32) * g
        res = fr.copy()
        res[..., :3] = np.clip(out, 0, 255).astype(np.uint8)
        return res

    def tone(self, rgb):
        """--light palette tone-down on float RGB 0..255 (no grime)."""
        hls = cv2.cvtColor((rgb / 255.0).astype(np.float32), cv2.COLOR_RGB2HLS)
        h, l, s_ = hls[..., 0], hls[..., 1], hls[..., 2]
        out = cv2.cvtColor(np.stack([h, np.clip(0.93 * l ** 1.04, 0, 1), s_ * 0.76], -1), cv2.COLOR_HLS2RGB) * 255
        return out * 0.92 + np.array([104, 92, 74], np.float32) * 0.08

    def crisp(self, fr, fs):
        """Crisp pass (pets): the light tone-down mapped colour-for-colour on
        the original pixel grid. Alpha copied exactly (hard silhouette), no
        noise, no resampling; contrast widened round the unit's mid value and
        a light 1 px unsharp inside the silhouette for edge definition."""
        a0 = fr[..., 3]
        if a0.max() == 0:
            return fr
        if not hasattr(self, "_crisp_pal"):
            t = self.tone(self.pal[None])[0]
            lum = t @ np.array([0.299, 0.587, 0.114], np.float32)
            mid = float(np.median(lum))
            k = (mid + (lum - mid) * np.where(lum < mid, 1.22, 1.02)) / np.maximum(lum, 1.0)
            self._crisp_pal = np.clip(t * k[:, None], 0, 255).astype(np.float32)
        col = self._crisp_pal[self.labels(fr[..., :3].astype(np.float32))]
        m = (a0 > 0).astype(np.float32)[..., None]
        # unsharp against a blur that only sees the sprite (no halo from bg)
        bl = cv2.GaussianBlur(col * m, (0, 0), 0.75) / np.maximum(cv2.GaussianBlur(m[..., 0], (0, 0), 0.75), 1e-3)[..., None]
        col = np.clip(col + (col - bl) * 0.3, 0, 255)
        res = fr.copy()
        res[..., :3] = np.where(m > 0, np.rint(col), fr[..., :3]).astype(np.uint8)
        return res

    @staticmethod
    def scale2x(L):
        """EPX / Scale2x on an integer label map (edge preserving, no blur)."""
        P = np.pad(L, 1, mode="edge")
        A, B, C, D = P[:-2, 1:-1], P[1:-1, :-2], P[1:-1, 2:], P[2:, 1:-1]
        E = L
        ok = (A != D) & (B != C)
        e0 = np.where(ok & (B == A), A, E)
        e1 = np.where(ok & (A == C), C, E)
        e2 = np.where(ok & (B == D), B, E)
        e3 = np.where(ok & (D == C), D, E)
        out = np.empty((L.shape[0] * 2, L.shape[1] * 2), L.dtype)
        out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
        return out

    def real(self, fr, fs):
        """Real pass (pets): see module doc. Same frames, poses, markings."""
        a0 = fr[..., 3]
        if a0.max() == 0:
            return fr
        if not hasattr(self, "_real_pal"):
            self.crisp(fr, fs)                      # builds _crisp_pal
            pal = self._crisp_pal
            lum = pal @ np.array([0.299, 0.587, 0.114], np.float32)
            self._dark = lum < 60
            self._real_pal = np.concatenate([pal, np.zeros((1, 3), np.float32)])
            seed = sum(map(ord, self.name)) + 7
            rng = np.random.default_rng(seed)
            W2 = fs * K * 2
            self._fur_n = cv2.GaussianBlur(rng.random((W2, W2)).astype(np.float32), (0, 0), 1.3)
        BG = len(self.pal)
        lab = self.labels(fr[..., :3].astype(np.float32))
        lab = np.where(a0 > 0, lab, BG)
        W = fs * K
        L = self.scale2x(self.scale2x(lab))
        solid = L != BG
        col = self._real_pal[L].astype(np.float32)
        dark = np.append(self._dark, False)[L]
        # body offset so texture sticks to the dog, not the frame
        try:
            (dx, dy), _ = cv2.phaseCorrelate(self.ref_a.astype(np.float64), (a0 / 255.0).astype(np.float64))
        except cv2.error:
            dx, dy = 0.0, 0.0
        # ---- volume: height from silhouette distance, lit from top-left
        d_out = cv2.distanceTransform(solid.astype(np.uint8), cv2.DIST_L2, 5)
        hgt = cv2.GaussianBlur(np.sqrt(np.clip(d_out / (7.0 * K), 0, 1)), (0, 0), 2.0 * K)
        gy, gx = np.gradient(hgt * 6.0 * K)
        nrm = np.stack([-gx, -gy, np.ones_like(hgt)], -1)
        nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
        ndl = np.clip((nrm * LIGHT).sum(-1), 0, 1)
        shade = 0.86 + 0.24 * ndl
        # ---- fur: line-integral convolution of body-anchored noise along
        # the contour tangent, biased to fall down and back
        hb = cv2.GaussianBlur(d_out, (0, 0), 3.0 * K)
        ty, tx = np.gradient(hb)
        vx, vy = -ty, tx
        flip = vy < 0
        vx, vy = np.where(flip, -vx, vx), np.where(flip, -vy, vy)
        vx, vy = vx + 0.25, vy + 0.6
        nv = np.sqrt(vx * vx + vy * vy) + 1e-6
        vx, vy = (vx / nv).astype(np.float32), (vy / nv).astype(np.float32)
        ys, xs = np.mgrid[0:W, 0:W].astype(np.float32)
        ox, oy = W / 2 - dx * K, W / 2 - dy * K
        acc = np.zeros((W, W), np.float32)
        for sgn in (1.0, -1.0):
            px, py = xs.copy(), ys.copy()
            for _ in range(7):
                acc += cv2.remap(self._fur_n, px + ox, py + oy, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
                sx = cv2.remap(vx, px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
                sy = cv2.remap(vy, px, py, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
                px, py = px + sgn * sx * 1.4, py + sgn * sy * 1.4
        fur = acc / 14.0
        fur = (fur - fur[solid].mean()) / (fur[solid].std() + 1e-6)
        fur_k = np.where(dark, 0.025, 0.05)
        col = col * (1 + fur_k * np.clip(fur, -2, 2))[..., None]
        # ---- crease shadow where a lighter patch meets a darker one
        lum4 = col.mean(-1)
        crease = np.clip(cv2.GaussianBlur(lum4, (0, 0), 1.5 * K) - lum4, 0, 40) / 40.0
        col = col * (1 - 0.12 * crease)[..., None]
        col = col * shade[..., None]
        # ---- wet specular on small dark blobs (eyes, nose) + leather sheen
        rows = np.nonzero(solid.any(1))[0]
        top, bot_y = rows[0], rows[-1]
        sml = ndi.label(dark & solid)
        spec = np.zeros((W, W), np.float32)
        for i, sl in enumerate(ndi.find_objects(sml[0]), 1):
            m = sml[0][sl] == i
            area = m.sum() / (K * K)
            if not (1.5 <= area <= 14) or d_out[sl][m].min() < 1.5 * K or sl[0].stop > top + 0.42 * (bot_y - top) \
                    or max(sl[0].stop - sl[0].start, sl[1].stop - sl[1].start) > 2.2 * min(sl[0].stop - sl[0].start, sl[1].stop - sl[1].start):
                continue
            yy, xx = np.nonzero(m)
            cy, cx = sl[0].start + yy.mean(), sl[1].start + xx.mean()
            r = max(1.2, 0.22 * np.sqrt(m.sum()))
            sy_, sx_ = int(round(cy - 0.35 * r - 0.5)), int(round(cx - 0.35 * r - 0.5))
            dot = ((ys - sy_) ** 2 + (xs - sx_) ** 2) <= (0.9 * r) ** 2
            spec = np.maximum(spec, dot * (sml[0] == i) * 0.85)
        sheen = dark & (ndl ** 6 > 0.35) & (d_out > 1.5 * K)
        col = col + 255 * (spec[..., None] * 0.9) + sheen[..., None] * 18.0
        # ---- paw contact occlusion (bottom of the silhouette)
        bot = np.zeros_like(d_out)
        colmax = np.where(solid.any(0), W - 1 - np.argmax(solid[::-1], 0), -1)
        dist_bot = colmax[None, :] - ys
        ao = np.clip(1 - dist_bot / (3.0 * K), 0, 1) * solid * (colmax[None, :] > W * 0.6)
        col = col * (1 - 0.22 * ao)[..., None]
        # ---- hair strands: a few short tufts out along the outward normal
        edge_out = (~solid) & (cv2.distanceTransform((~solid).astype(np.uint8), cv2.DIST_L2, 5) <= 2.5)
        tuft = edge_out & (cv2.remap(self._fur_n, xs + ox, ys + oy, cv2.INTER_NEAREST) > 0.62) & (ys < (colmax[None, :] - 3 * K))
        nb = cv2.erode(np.where(solid[..., None], col, 255).astype(np.float32), np.ones((5, 5), np.uint8))
        col = np.where(tuft[..., None], nb, col)
        alpha = (solid | tuft).astype(np.float32)
        col = np.clip(col, 0, 255)
        # ---- back to frame size: Lanczos (premultiplied) + light unsharp,
        # hard alpha (threshold, no halo)
        pm = np.concatenate([col * alpha[..., None], alpha[..., None]], -1)
        T = fs * REAL_OUT
        sm = cv2.resize(pm, (T, T), interpolation=cv2.INTER_AREA)
        lz = cv2.resize(pm, (T, T), interpolation=cv2.INTER_LANCZOS4)
        a1 = sm[..., 3]
        hard = a1 >= 0.5
        c = np.clip(lz[..., :3], 0, None) / np.maximum(np.clip(lz[..., 3], 0, 1), 0.35)[..., None]
        m = hard.astype(np.float32)[..., None]
        bl = cv2.GaussianBlur(c * m, (0, 0), 0.8) / np.maximum(cv2.GaussianBlur(m[..., 0], (0, 0), 0.8), 1e-3)[..., None]
        c = np.clip(c + (c - bl) * 0.4, 0, 255)
        res = np.zeros((T, T, 4), np.uint8)
        res[..., :3] = np.where(hard[..., None], np.rint(c), 0).astype(np.uint8)
        res[..., 3] = np.where(hard, 255, 0).astype(np.uint8)
        return res

    def run(self, out_dir, light=False, crisp=False, real=False):
        os.makedirs(out_dir, exist_ok=True)
        for f, im in self.strips.items():
            arr = np.asarray(im)
            fs = arr.shape[0]
            n = arr.shape[1] // fs
            fn = self.real if real else self.crisp if crisp else self.light if light else self.frame
            frames = [fn(arr[:, i * fs:(i + 1) * fs], fs) for i in range(n)]
            Image.fromarray(np.concatenate(frames, 1), "RGBA").save(os.path.join(out_dir, f))
            print("repainted", self.rel, f, n)


def main(argv):
    out = None
    light = False
    crisp = False
    real = False
    units = []
    it = iter(argv)
    for a in it:
        if a == "--out":
            out = next(it)
        elif a == "--light":
            light = True
        elif a == "--crisp":
            crisp = True
        elif a == "--real":
            real = True
        else:
            units.append(a)
    for rel in units:
        u = Unit(rel)
        u.run(os.path.join(out, u.name) if out else os.path.join(SPR, rel), light=light, crisp=crisp, real=real)


if __name__ == "__main__":
    main(sys.argv[1:])
