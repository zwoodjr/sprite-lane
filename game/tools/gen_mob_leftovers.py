"""Mob animation leftovers (backlog 3), re-runnable from the sources kept in
tools/art_src/mob_leftovers/ (copied there on the first run):

1. Flyers (glow_moth, glow_moth_queen, rad_bat): real wing-flap in-betweens. Every
   pair of painted flap frames gets a flow-warped middle frame (dense optical flow
   both ways, each key warped half way; the colour comes from the nearer key, never
   a cross-fade, so wings sweep instead of ghosting). idle 32 -> 64 @ 16 fps,
   walk 12 -> 24 @ 28 fps: same cycle time, twice the poses.
2. Boss roars (dread_naught, dust_warden, mutant_overlord, wasteland_god_entity):
   a keyed body move on top of the painted roar — crouch, rear up (front lifts,
   pivot on the rear feet), stretch, shake, settle. Each frame is fitted inside the
   frame with a 3 px margin: slid sideways first, then scaled down only as far as
   still needed (never clipped); feet stay on the baseline.
3. raider_captain death: the fall drifts right so the body never reaches the
   frame edge (min 14 px margin).

    python3 game/tools/gen_mob_leftovers.py
"""
import json
import math
import os
import shutil

import cv2
import numpy as np
from PIL import Image

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(GAME, "assets", "sprites", "enemies")
SRC = os.path.join(GAME, "tools", "art_src", "mob_leftovers")

FLYERS = ["glow_moth", "glow_moth_queen", "rad_bat"]
ROARS = ["dread_naught", "dust_warden", "mutant_overlord", "wasteland_god_entity"]
FLY_FPS = {"idle": 16, "walk": 28}
MARGIN = 3


def src_path(uid, state):
    rel = os.path.join(uid, f"{uid}_{state}.png")
    p = os.path.join(SRC, rel)
    if not os.path.exists(p):
        os.makedirs(os.path.dirname(p), exist_ok=True)
        shutil.copy2(os.path.join(EN, rel), p)
    return p


def load(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
    h = a.shape[0]
    return [a[:, i * h:(i + 1) * h].copy() for i in range(a.shape[1] // h)]


def save(frames, uid, state):
    out = np.concatenate(frames, 1).clip(0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(EN, uid, f"{uid}_{state}.png"))


# ------------------------------------------------------------------ flyers
def _gray(f):
    al = f[..., 3:4] / 255.0
    rgb = f[..., :3] * al + 70 * (1 - al)
    g = cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY)
    return cv2.addWeighted(g, 0.6, (al[..., 0] * 255).astype(np.uint8), 0.4, 0)


def _flow(a, b):
    return cv2.calcOpticalFlowFarneback(_gray(a), _gray(b), None, 0.5, 5, 21, 5, 7, 1.5, 0)


def _warp(img, fl, t):
    h, w = fl.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    pm = img.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    return cv2.remap(pm, gx - t * fl[..., 0], gy - t * fl[..., 1], cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def tween(a, b, t=0.5):
    wa = _warp(a, _flow(a, b), t)
    wb = _warp(b, _flow(b, a), 1 - t)
    soft = (1 - t) * wa[..., 3] + t * wb[..., 3]
    solid = soft > 127
    alpha = np.where(solid, 255.0, soft)  # soft only for the ground shadow / glow
    near, far = (wa, wb) if t <= 0.5 else (wb, wa)
    pick = np.where((near[..., 3] > 128)[..., None], near, far)
    pm = np.where(solid[..., None], pick, (1 - t) * wa + t * wb)
    rgb = np.clip(pm[..., :3] / np.maximum(pm[..., 3:4], 1) * 255.0, 0, 255)
    out = np.dstack([rgb, alpha]).astype(np.float32)
    out[..., :3] *= (alpha > 0)[..., None]
    return out


def flyers():
    for uid in FLYERS:
        for st in ("idle", "walk"):
            keys = load(src_path(uid, st))
            out = []
            for i, k in enumerate(keys):
                out.append(k)
                out.append(tween(k, keys[(i + 1) % len(keys)]))
            save(out, uid, st)
        jp = os.path.join(EN, uid, f"{uid}_anim.json")
        d = json.load(open(jp)) if os.path.exists(jp) else {}
        d.setdefault("fps", {}).update(FLY_FPS)
        json.dump(d, open(jp, "w"), indent=1)
        print("flyer", uid)


# ------------------------------------------------------------------ roars
def keyed(t, pts):
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t <= t1:
            u = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
            u = u * u * (3 - 2 * u)
            return v0 + (v1 - v0) * u
    return pts[-1][1]


def _affine(f, rot, sx, sy, dx, dy, piv):
    """Scale about piv, rotate about piv, then translate."""
    px, py = piv
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    # y-down image: positive rot lifts the right (front) side
    A = np.array([[c * sx, s * sy], [-s * sx, c * sy]], np.float32)
    off = np.array([px, py], np.float32) - A @ np.array([px, py], np.float32) + np.array([dx, dy], np.float32)
    M = np.hstack([A, off[:, None]])
    pm = f.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    h, w = f.shape[:2]
    o = cv2.warpAffine(pm, M, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    rgb = np.clip(o[..., :3] / np.maximum(o[..., 3:4], 1) * 255.0, 0, 255)
    return np.dstack([rgb, o[..., 3]]).astype(np.float32)


def _fits(f):
    a = f[..., 3] > 24
    ys, xs = np.nonzero(a)
    h, w = a.shape
    return xs.min() >= MARGIN and xs.max() <= w - 1 - MARGIN and ys.min() >= MARGIN


def roars():
    for uid in ROARS:
        fr = load(src_path(uid, "roar"))
        n = len(fr)
        F = fr[0].shape[0]
        a0 = fr[0][..., 3] > 24
        ys, xs = np.nonzero(a0)
        base = float(ys.max())
        x0, x1 = float(xs.min()), float(xs.max())
        rear = (x0 + (x1 - x0) * 0.3, base)  # pivot on the rear feet
        out = []
        for i, f in enumerate(fr):
            t = i / (n - 1)
            rot = keyed(t, [(0, 0), (0.14, -1.2), (0.45, 4.5), (0.72, 4.0), (1, 0)])
            sy = keyed(t, [(0, 1), (0.14, 0.94), (0.45, 1.05), (0.72, 1.04), (1, 1)])
            sx = keyed(t, [(0, 1), (0.14, 1.04), (0.45, 0.97), (0.72, 0.98), (1, 1)])
            shake = [0, 0, 0, 0, 3.0, -3.0, 2.0, 0][i] if n == 8 else 0.0
            k = 1.0
            while True:
                g = _affine(f, rot, sx * k, sy * k, shake, 0.0, rear)
                # re-centre first (slide inside the frame), shrink only if still too big
                xs = np.nonzero((g[..., 3] > 24).max(0))[0]
                lo, hi = xs.min() - MARGIN, F - 1 - MARGIN - xs.max()
                if lo < 0 <= hi + lo or hi < 0 <= hi + lo:
                    g = _affine(f, rot, sx * k, sy * k, shake + (-lo if lo < 0 else hi), 0.0, rear)
                if _fits(g) or k < 0.7:
                    break
                k -= 0.01
            out.append(g)
            print(f"  {uid} roar f{i}: rot {rot:.1f} sx {sx:.2f} sy {sy:.2f} fit {k:.2f}")
        save(out, uid, "roar")


# ------------------------------------------------------------------ captain death
def captain_death():
    uid = "raider_captain"
    fr = load(src_path(uid, "death"))
    out = []
    for i, f in enumerate(fr):
        dx = int(round(keyed(i / (len(fr) - 1), [(0, 0), (0.3, 2), (0.6, 14), (1, 14)])))
        g = np.zeros_like(f)
        g[:, dx:] = f[:, :f.shape[1] - dx] if dx > 0 else f
        cols = np.nonzero((g[..., 3] > 24).max(0))[0]
        assert cols.min() >= 14 and cols.max() <= f.shape[1] - 1 - 10, (i, cols.min(), cols.max())
        out.append(g)
    save(out, uid, "death")
    print("captain death drift ok")


if __name__ == "__main__":
    flyers()
    roars()
    captain_death()
