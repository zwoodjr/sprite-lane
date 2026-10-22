"""Rad Gator Matriarch (campaign boss, Chapter 1) from the rad_gator strips.

Per frame (128 px source -> 256 px boss frame, style bible §1-3):
  1. the rad gator's war-surplus tank is lifted off its back and the back line
     is closed over (interpolated top contour, FLESH 2 body + FLESH 1 shade);
  2. the 1-px outline is stripped, the body is doubled with Scale2x (EPX: exact
     colours, new single-texel detail, no blur, no 2-texel blocks);
  3. a brood of plague egg-sacs grows along the back (FLESH rims, PLAGUE 3/4
     self-lit cores; the only bright spots) plus a ridge of bone spines;
  4. a fresh 1-px FLESH 0 outline goes round the new silhouette with tone-1
     selout on the lit top-left side; feet land on y = 246 (frame - 10).
States: idle 8 / walk 8 / windup 4 / attack 4 / hit 2 / death 8, and a roar
(windup + attack) for the entrance. Attack JSON origins scale with the art.

    python3 game/tools/gen_matriarch.py
"""
import json
import os

import numpy as np
from PIL import Image

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(GAME, "assets", "sprites", "enemies", "rad_gator")
OUT = os.path.join(GAME, "assets", "sprites", "enemies", "rad_gator_matriarch")
UID = "rad_gator_matriarch"

FLESH = [(46, 24, 48), (90, 50, 84), (138, 84, 116), (192, 138, 160)]
PLAGUE = [(20, 42, 24), (43, 90, 44), (87, 147, 47), (156, 207, 62), (220, 245, 138)]
BONE = (233, 223, 201)
ASH3 = (143, 135, 126)
STEEL = {(94, 109, 122), (154, 168, 173), (54, 66, 79), (27, 34, 44), (118, 52, 32), (173, 90, 42), (217, 138, 69),
         (62, 26, 18), (54, 66, 79)}
SHIFT_Y = 10
PICK = {"idle": 8, "walk": 8, "windup": 4, "attack": 4, "hit": 2, "death": 8}


def frames(state):
    a = np.asarray(Image.open(os.path.join(SRC, f"rad_gator_{state}.png")).convert("RGBA")).copy()
    n = a.shape[1] // 128
    return [a[:, i * 128:(i + 1) * 128].copy() for i in range(n)]


def pick(fs, k):
    if len(fs) <= k:
        return fs
    return [fs[int(round(i * len(fs) / k)) % len(fs)] for i in range(k)]


def is_steel(px):
    r, g, b = int(px[0]), int(px[1]), int(px[2])
    if (r, g, b) in STEEL:
        return True
    # blue-grey metal: b >= r and low saturation-ish, not purple flesh
    return b > r + 6 and g > r - 4 and abs(int(g) - int(b)) < 40 and r < 180


def lift_tank(f):
    """Remove the back tank and close the back line over it."""
    a = f[..., 3] > 0
    h, w = a.shape
    steel = np.zeros_like(a)
    for y in range(h):
        for x in range(w):
            if a[y, x] and is_steel(f[y, x]):
                steel[y, x] = True
    # Also clear the tank's dark outline/shadow pixels that sit above the body:
    rows = np.where(steel.any(1))[0]
    cols = np.where(steel.any(0))[0]
    if len(rows) == 0:
        return f
    y0, y1 = rows.min(), rows.max()
    x0, x1 = max(0, cols.min() - 2), min(w - 1, cols.max() + 2)
    # body top per column, outside the tank columns
    def top(x):
        col = np.where(a[:, x] & ~steel[:, x])[0]
        col = col[col > y1 - 2] if len(col) else col
        return col.min() if len(col) else None
    f[y0 - 3:y1 + 2, x0:x1 + 1][steel[y0 - 3:y1 + 2, x0:x1 + 1]] = 0
    # clear anything left above the body inside the tank span (outline, specks)
    left = top(x0 - 1) if x0 > 0 else None
    right = top(x1 + 1) if x1 < w - 1 else None
    if left is None or right is None:
        return f
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(1, (x1 - x0))
        ty = int(round(left * (1 - t) + right * t - 2 * np.sin(np.pi * t)))
        col = f[:, x]
        # remove leftovers above the new back line
        col[:ty][col[:ty, 3] > 0] = 0
        # fill from the new back line down to the first remaining body pixel
        below = np.where(col[ty:, 3] > 0)[0]
        stop = ty + (below.min() if len(below) else 0)
        for y in range(ty, stop):
            col[y] = (*FLESH[2], 255) if y > ty + 1 else (*FLESH[1], 255)
    return f


def strip_outline(f):
    a = f[..., 3] > 0
    p = np.pad(a, 1)
    edge = a & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    lum = f[..., 0].astype(int) * 3 + f[..., 1].astype(int) * 6 + f[..., 2].astype(int)
    dark = lum < 70 * 10
    g = f.copy()
    g[edge & dark] = 0
    return g


def scale2x(a):
    h, w = a.shape[:2]
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    B = p[:-2, 1:-1]; D = p[1:-1, :-2]; E = p[1:-1, 1:-1]; F = p[1:-1, 2:]; H = p[2:, 1:-1]
    eq = lambda x, y: np.all(x == y, axis=-1)
    c1 = eq(D, B) & ~eq(D, H) & ~eq(B, F)
    c2 = eq(B, F) & ~eq(B, D) & ~eq(F, H)
    c3 = eq(D, H) & ~eq(D, B) & ~eq(H, F)
    c4 = eq(H, F) & ~eq(H, D) & ~eq(F, B)
    out = np.zeros((h * 2, w * 2, 4), a.dtype)
    out[0::2, 0::2] = np.where(c1[..., None], D, E)
    out[0::2, 1::2] = np.where(c2[..., None], F, E)
    out[1::2, 0::2] = np.where(c3[..., None], D, E)
    out[1::2, 1::2] = np.where(c4[..., None], F, E)
    return out


def disc(img, cx, cy, r, ring, fill, core=None, hi=None):
    h, w = img.shape[:2]
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if not (0 <= x < w and 0 <= y < h):
                continue
            d = ((x - cx) ** 2 + ((y - cy) * 1.15) ** 2) ** 0.5
            if d <= r:
                c = fill
                if d > r * 0.55 and (x - cx) + (y - cy) > r * 0.35:
                    c = FLESH[1]
                if d > r - 1.6:
                    c = ring
                elif core is not None and d < r * 0.45:
                    c = core
                if hi is not None and d < r * 0.35 and x < cx and y < cy:
                    c = hi
                img[y, x] = (*c, 255)


def brood(img, frame_i, state):
    """Egg sacs + spines along the back (2x coordinates)."""
    a = img[..., 3] > 0
    cols = np.where(a.any(0))[0]
    if len(cols) == 0:
        return img
    x0, x1 = cols.min(), cols.max()
    span = x1 - x0
    def top(x):
        r = np.where(a[:, int(x)])[0]
        return r.min() if len(r) else None
    pulse = 1 if (frame_i % 2 == 0) else 0
    sacs = [(0.30, 9), (0.40, 12), (0.50, 10), (0.58, 13), (0.67, 9), (0.45, 7)]
    if state == "death":
        sacs = sacs[: max(1, 6 - frame_i)]
    for k, (t, r) in enumerate(sacs):
        x = x0 + span * t
        ty = top(x)
        if ty is None:
            continue
        rr = r + (pulse if k % 2 == 0 else 0)
        cy = ty - rr * 0.55 + (6 if k == 5 else 0)
        disc(img, x, cy, rr, FLESH[0], FLESH[3] if k % 2 else FLESH[2], core=PLAGUE[3], hi=PLAGUE[4])
    # bone spines along the tail half (behind the sacs)
    for t in (0.14, 0.19, 0.24, 0.76, 0.81):
        x = int(x0 + span * t)
        ty = top(x)
        if ty is None:
            continue
        for d in range(12):
            yy = ty - d
            if 0 <= yy < img.shape[0] and img[yy, x, 3] == 0:
                img[yy, x] = (*BONE, 255) if d < 9 else (*ASH3, 255)
                if d < 6 and img[yy, x + 1, 3] == 0:
                    img[yy, x + 1] = (*ASH3, 255)
                if d < 3 and img[yy, x - 1, 3] == 0:
                    img[yy, x - 1] = (*BONE, 255)
    return img


def outline(img):
    a = img[..., 3] > 0
    p = np.pad(a, 1)
    ring = ~a & (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])
    out = img.copy()
    out[ring] = (*FLESH[0], 255)
    # selout: outline pixels whose body lies down-right of them (lit top-left side)
    lit = ring & (p[2:, 1:-1] | p[1:-1, 2:]) & ~(p[:-2, 1:-1] | p[1:-1, :-2])
    out[lit] = (*FLESH[1], 255)
    return out


def build(f, i, state):
    g = lift_tank(f.copy())
    g = strip_outline(g)
    big = scale2x(g)
    big = brood(big, i, state)
    big = outline(big)
    out = np.zeros((256, 256, 4), np.uint8)
    out[SHIFT_Y:, :] = big[:256 - SHIFT_Y, :]
    out[..., 3] = np.where(out[..., 3] > 0, 255, 0)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for st, k in PICK.items():
        fs = pick(frames(st), k)
        strip = [build(f, i, st) for i, f in enumerate(fs)]
        made[st] = strip
        Image.fromarray(np.concatenate(strip, 1), "RGBA").save(os.path.join(OUT, f"{UID}_{st}.png"))
    roar = made["windup"] + made["attack"]
    Image.fromarray(np.concatenate(roar, 1), "RGBA").save(os.path.join(OUT, f"{UID}_roar.png"))
    with open(os.path.join(OUT, f"{UID}_anim.json"), "w") as fh:
        json.dump({"fps": {"idle": 8, "walk": 12, "roar": 8}}, fh, indent=1)
    src = json.load(open(os.path.join(SRC, "rad_gator_attack.json")))
    src["origin"] = [[round(o[0] * 2, 1), round(o[1] * 2 + SHIFT_Y, 1)] for o in src["origin"]]
    with open(os.path.join(OUT, f"{UID}_attack.json"), "w") as fh:
        json.dump(src, fh)
    print("matriarch strips:", {k: len(v) for k, v in made.items()})


if __name__ == "__main__":
    main()
