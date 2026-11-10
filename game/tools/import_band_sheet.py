#!/usr/bin/env python3
"""Import a painted "band" sheet (heroes or mech pets) into the strips the game plays.

Sources (tools/art_src/):
  heroes_sheet.png   batch 7, 8 hero bands     -> assets/sprites/characters/<id>/
  pets_sheet_b7.png  batch 7, 3 mech-pet bands -> assets/sprites/pets/<id>/

Each band is two rows of six side-on frames facing right, on a grey backdrop,
separated from the next band by a dark seam:

  row A: idle, walk 1..5
  row B: attack 1..4, then flinch + death (heroes) / sit + knocked out (pets)

Pipeline (same keyer as tools/import_dog_sheet.py):
  1. bands from the dark seams; each band is split into its two rows at the
     painted floor line (darkest row near the middle)
  2. each row is keyed as one panel (backdrop model + flood from the border),
     its blobs are grouped into the six frames by their x centre (muzzle
     flashes, sparks, drones and blood stay with their frame)
  3. one scale per unit: the idle frame is matched to the old strips' size;
     every frame stands on its lowest pixel (fliers: the painted floor line
     sits a fixed hover gap under them) and is centred on its torso, so
     nothing jitters
  4. bake at hd 2 (2 texture px per art texel), strips over 4096 px folded into
     grids (assets/sprites/strip_grids.json); fps / hd / ui window go in
     <id>_anim.json, hero weapon tips + hit frames in <id>_weapon.json

    python3 tools/import_band_sheet.py heroes|pets [ids...] [--preview DIR] [--dry]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_dog_sheet as dogs  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, ".."))
GRIDS = os.path.join(GAME, "assets", "sprites", "strip_grids.json")
MAX_TEX = 4096
HD = 2

A = lambda c: (0, c)
B = lambda c: (1, c)

# Hero bands top to bottom -> hero id. Old idle heights (1x texels) keep each
# hero's on-screen size.
HEROES = {
    "sheet": "heroes_sheet.png",
    "dir": "characters",
    "fs": 448,                  # 224 art texels: lying death pose, long guns
    "ffb": 10 * HD,             # UnitAnim.FEET_FROM_BOTTOM * hd
    "soft_shadows": False,
    "units": [
        ("quill_marrow", 107),   # hooded rifleman
        ("ash_rook", 98),       # heavy minigunner
        ("vesper_thorn", 96),    # ghillie sniper
        ("bolt_juno", 97),       # lantern-pack gunner
        ("pebble", 107),         # riot-shield heavy
        ("helm_wisp", 104),      # drone operator
        ("nyx_caldera", 99),     # axe fighter
        ("sister_cinder", 108),  # medic
    ],
}
PETS = {
    "sheet": "pets_sheet_b7.png",
    "dir": "pets",
    "fs": 256,
    "ffb": 20,
    "soft_shadows": True,
    # (id, target sqrt(w*h) of the idle bbox in 2x px: old 128 px strips x 2)
    "units": [("drone_bat", 110), ("mech_hound", 118), ("rust_mule", 142)],
}
FLYERS = {"drone_bat"}
# Units whose painted drone may hover outside the frame: pulled in.
PULL = {"helm_wisp"}
# Bolt Juno (lantern-pack gunner) and Quill Marrow (hooded rifleman) shoot:
# their painted strips show guns, so they are ranged (no melee hit frames).
MELEE_HITS = {"pebble": [2], "nyx_caldera": [1, 2]}
ABILITY_HITS = {"nyx_caldera": [2, 3], "bolt_juno": [1], "quill_marrow": [2]}


# ------------------------------------------------------------------ layout
def find_bands(lum, n):
    """Dark seam rows -> n (y0, y1) band spans."""
    h, w = lum.shape
    base = float(np.median(lum))
    prof = lum[:, w // 10: w - w // 10].mean(1)
    dark = prof < base * 0.4
    cuts = [0]
    y = 0
    while y < h:
        if dark[y]:
            y2 = y
            while y2 + 1 < h and (dark[y2 + 1] or (y2 + 3 < h and dark[y2 + 3])):
                y2 += 1
            cuts.append((y + y2) // 2)
            y = y2 + 1
        else:
            y += 1
    cuts.append(h)
    spans = [(a + 4, b - 3) for a, b in zip(cuts, cuts[1:]) if b - a > 60]
    if len(spans) != n:
        raise SystemExit("bands: expected %d, found %d %s" % (n, len(spans), spans))
    return spans


def split_rows(lum, y0, y1):
    """Band -> (row A span, row B span, floor A, floor B) in sheet rows."""
    prof = lum[y0:y1, 8:-8].mean(1)
    h = y1 - y0
    lo, hi = int(h * 0.42), int(h * 0.66)
    fa = lo + int(np.argmin(prof[lo:hi]))
    lo2 = int(h * 0.85)
    fb = lo2 + int(np.argmin(prof[lo2:h - 2]))
    cut = y0 + fa + 4
    return (y0, cut), (cut, y1), fa + 4, fb - (fa + 4)


class Frame:
    def __init__(self, fg, alpha, floor):
        self.fg, self.alpha, self.floor = fg, alpha, float(floor)
        m = alpha > 0.5
        ys, xs = np.nonzero(m)
        self.x0, self.x1, self.y0, self.y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        rows = m.sum(1)
        self.foot = float(np.nonzero(rows > 2)[0].max() + 1)
        hgt = self.foot - self.y0
        band = m[int(self.y0 + 0.2 * hgt):int(self.y0 + 0.8 * hgt)]
        bx = np.nonzero(band)[1]
        self.cx = float(np.median(bx)) if len(bx) else float((self.x0 + self.x1) / 2)
        # Flash-free mask for the weapon tip: drop bright, saturated pixels.
        lum = fg @ np.array([0.299, 0.587, 0.114])
        sat = fg.max(-1) - fg.min(-1)
        self.solid = m & ~((lum > 150) & (sat > 60)) & ~((fg[..., 2] > 150) & (fg[..., 2] > fg[..., 0] + 40))

    def height(self):
        return self.foot - self.y0

    def gm(self):
        return float(np.sqrt((self.x1 - self.x0) * (self.foot - self.y0)))


def key_row(rgb, soft_shadows):
    fg, al, sh = dogs.key_cell(rgb, soft_shadows=soft_shadows)
    return fg, al, sh


def split_frames(fg, al, n=6):
    """Group the keyed row's blobs into n frames. The n biggest blobs are the
    bodies; a detached bit (muzzle flash, sparks, drone, blood, smoke) joins
    the body whose box holds its centre, else the nearest body on its left
    (everything faces right), else the nearest body."""
    m = al > 0.05
    lab, k = ndi.label(ndi.binary_dilation(m, iterations=3))
    objs = ndi.find_objects(lab)
    sizes = ndi.sum(m, lab, range(1, k + 1))
    order = list(np.argsort(sizes)[::-1][:n])
    if len(order) < n:
        raise SystemExit("row: found %d bodies, expected %d" % (len(order), n))
    order.sort(key=lambda i: objs[i][1].start)
    box = [(objs[i][1].start, objs[i][1].stop) for i in order]
    owner = {order[j] + 1: j for j in range(n)}
    for i in range(k):
        if i + 1 in owner:
            continue
        xs = np.nonzero((lab[objs[i]] == i + 1).any(0))[0] + objs[i][1].start
        cx = float(xs.mean())
        inside = [j for j, (a, b) in enumerate(box) if a - 6 <= cx <= b + 6]
        left = [j for j, (a, b) in enumerate(box) if (a + b) / 2 < cx]
        if inside:
            owner[i + 1] = inside[0] if len(inside) == 1 else min(inside, key=lambda j: abs(sum(box[j]) / 2 - cx))
        elif left:
            owner[i + 1] = left[-1]
        else:
            owner[i + 1] = int(np.argmin([abs((a + b) / 2 - cx) for a, b in box]))
    out = []
    for c in range(n):
        ids = [lid for lid, j in owner.items() if j == c]
        keep = np.isin(lab, ids) & m
        bits = [(lab == lid) & m for lid in ids if lid != order[c] + 1]
        out.append((np.where(keep, al, 0.0), bits))
    return out


def pull_in(fr_alpha, fg, cx, lim):
    """Fit a frame whose right side (a drone and its spark beam) overruns
    cx + lim: drop the overrun's worth of columns where the beam is sparsest,
    so the drone moves in and the hand / body are untouched."""
    cols = np.nonzero((fr_alpha > 0.05).any(0))[0]
    if not len(cols):
        return fr_alpha, fg
    over = int(np.ceil(cols.max() + 1 - (cx + lim)))
    if over <= 0:
        return fr_alpha, fg
    occ = (fr_alpha > 0.05).sum(0).astype(float)
    lo, hi = int(cx + 0.35 * lim), int(cols.max() - over - 4)
    if hi <= lo:
        return fr_alpha, fg
    win = np.convolve(occ, np.ones(over), "valid")
    c0 = lo + int(np.argmin(win[lo:hi]))
    keep = np.r_[0:c0, c0 + over:fr_alpha.shape[1]]
    pad = lambda x: np.concatenate([x[:, keep], np.zeros_like(x[:, :over])], 1)
    return pad(fr_alpha), pad(fg)


# ------------------------------------------------------------------ bake
def compose(fr, scale, ground, fs, ffb, sy=1.0, sx=1.0, dx=0.0):
    """FS x FS RGBA: cell row `ground` lands on the feet line, torso on centre."""
    rgba = np.dstack([fr.fg * fr.alpha[..., None], fr.alpha])
    kx, ky = scale * sx, scale * sy
    feet = fs - ffb
    v, u = np.mgrid[0:fs, 0:fs].astype(float)
    cxs = (u + 0.5 - fs / 2.0 - dx) / kx + fr.cx - 0.5
    cys = (v + 0.5 - feet) / ky + ground - 0.5
    sig = max(0.0, 0.5 / min(kx, ky) - 0.5) * 0.85
    order = 3 if min(kx, ky) > 1.0 else 1
    out = np.zeros((fs, fs, 4))
    for c in range(4):
        ch = ndi.gaussian_filter(rgba[..., c], sig) if sig > 0 else rgba[..., c]
        out[..., c] = ndi.map_coordinates(ch, [cys, cxs], order=order, mode="constant", cval=0.0)
    a = np.clip(out[..., 3], 0, 1)
    col = np.where(a[..., None] > 1e-3, out[..., :3] / np.maximum(a[..., None], 1e-3), 0)
    res = np.dstack([np.clip(col, 0, 255), a * 255.0])
    # Anything reaching the frame edge (a long muzzle flash) fades out
    # instead of ending in a hard cut.
    edge = np.minimum(np.arange(fs), np.arange(fs)[::-1]).astype(float)
    res[..., 3] *= np.clip(edge / 14.0, 0, 1)[None, :]
    res[res[..., 3] < 5] = 0
    return res.round().astype(np.uint8)


def tip_of(fr, scale, ground, fs, ffb, sx=1.0, sy=1.0):
    """Weapon tip in frame px: the rightmost flash-free pixel in the upper 75%."""
    m = fr.solid
    lim = int(fr.y0 + 0.75 * fr.height())
    sub = m[:lim]
    cols = np.nonzero(sub.any(0))[0]
    if not len(cols):
        return [fs / 2.0, fs / 2.0]
    x = cols.max()
    ys = np.nonzero(sub[:, x])[0]
    y = float(ys.mean())
    feet = fs - ffb
    tx = float(np.clip((x + 0.5 - fr.cx) * scale * sx + fs / 2.0, 8, fs - 8))
    ty = float(np.clip((y - ground) * scale * sy + feet, 8, fs - 8))
    return [round(tx, 1), round(ty, 1)]


def muzzle_fix(frame, tip):
    """Painted fire frames: tip_of() lands on the far end of the muzzle flash.
    Move it back to where the flash starts (the barrel's end), on the flash's
    centre row, so bullets and the FX flash leave the gun itself."""
    f = frame.astype(int)
    a = f[..., 3] > 100
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    flash = a & (r > 170) & (r - b > 60) & (lum > 150)
    ty = int(tip[1])
    y0, x0 = max(0, ty - 14), int(frame.shape[1] * 0.7)
    band = flash[y0:ty + 15, x0:]
    if band.sum() < 6:
        return tip
    y = y0 + int(np.argmax(band.sum(1)))
    row = flash[y - 3:y + 4, x0:]
    cols = np.nonzero(row.sum(0) >= 2)[0]
    if not len(cols):
        return tip
    return [float(x0 + cols.min()), float(y)]


def write_strip(path, frames, grids, key, fs):
    n = len(frames)
    cols = min(n, MAX_TEX // fs)
    rows = (n + cols - 1) // cols
    img = Image.new("RGBA", (cols * fs, rows * fs), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(Image.fromarray(f, "RGBA"), ((i % cols) * fs, (i // cols) * fs))
    img.save(path, optimize=True)
    if rows > 1:
        grids[key] = {"n": n, "fs": fs, "cols": cols, "rows": rows}
    else:
        grids.pop(key, None)


def build(kind, uid, frames, target, cfg):
    fs, ffb = cfg["fs"], cfg["ffb"]
    idle = frames[A(0)]
    if kind == "heroes":
        scale = HD * target / idle.height()
    else:
        scale = target / idle.gm()
    g = {k: f.foot for k, f in frames.items()}
    if uid in FLYERS:
        # Hover: the painted floor line sits a fixed gap under the body.
        for k, f in frames.items():
            if k not in (B(4), B(5)):
                g[k] = f.floor
    plan = {}       # state -> [(cell, kw)]
    fps = {}
    breathe = lambda k, n, amp=0.012: [(k, {"sy": 1 + amp * np.sin(2 * np.pi * i / n),
                                            "sx": 1 - amp * 0.3 * np.sin(2 * np.pi * i / n)}) for i in range(n)]
    walk = [(A(c), {}) for c in range(1, 6)]
    atk = [(B(c), {}) for c in range(4)]
    if kind == "heroes":
        plan["idle"] = breathe(A(0), 8)
        plan["walk"] = walk
        plan["windup"] = [(B(0), {"sy": 0.97, "sx": 1.02}), (B(0), {})]
        plan["attack"] = atk
        plan["hit"] = [(B(4), {}), (B(4), {"sy": 0.97, "sx": 1.02})]
        plan["death"] = [(B(4), {}), (B(4), {"sy": 0.9, "sx": 1.04}), (B(5), {"sy": 1.05, "sx": 0.98}), (B(5), {})]
        plan["dash"] = [(A(c), {"sx": 1.05, "sy": 0.97}) for c in (2, 3, 4, 5)]
        if uid == "sister_cinder":
            plan["ability"] = [(A(0), {}), (A(0), {"sy": 0.96, "sx": 1.02}), (B(0), {}), (B(0), {"sy": 1.02}),
                               (A(0), {"sy": 1.02}), (A(0), {})]
        elif uid == "ash_rook":
            plan["ability"] = [(A(c), {"sx": 1.04, "sy": 0.98}) for c in (1, 2, 3, 4, 5, 1)]
        else:
            plan["ability"] = [(B(0), {}), (B(1), {}), (B(2), {}), (B(3), {}), (B(2), {}), (B(0), {})]
        fps = {"idle": 6, "walk": 9, "windup": 10, "attack": 12, "hit": 10, "death": 8, "dash": 24, "ability": 12}
    else:
        plan["idle"] = breathe(A(0), 16, 0.015 if uid in FLYERS else 0.012)
        plan["walk"] = walk
        plan["windup"] = [(B(0), {"sy": 0.97, "sx": 1.02}), (B(0), {})]
        plan["attack"] = atk
        plan["hit"] = [(A(0), {"sy": 0.94, "sx": 1.04}), (A(0), {})]
        plan["sit"] = [(B(4), {"sy": 0.95, "sx": 1.02}), (B(4), {"sy": 1.02}), (B(4), {})]
        plan["sit_idle"] = breathe(B(4), 16, 0.01)
        plan["death"] = [(B(4), {"sy": 0.96}), (B(5), {"sy": 1.06, "sx": 0.98}), (B(5), {})]
        fps = {"idle": 8, "walk": 12, "windup": 10, "attack": 12, "hit": 12, "sit": 10, "sit_idle": 8, "death": 8}
    states, tips = {}, {}
    for st, seq in plan.items():
        states[st] = [compose(frames[k], scale, g[k], fs, ffb, **kw) for k, kw in seq]
        tips[st] = [tip_of(frames[k], scale, g[k], fs, ffb, kw.get("sx", 1.0), kw.get("sy", 1.0)) for k, kw in seq]
    return states, tips, fps, scale


def pet_portrait(fr, uid):
    """192 px portrait from the painted idle frame at sheet resolution: the
    whole drone, or the head and shoulders (top-right of the body) of a
    walker, square, keyed."""
    x0, x1, y0, y1 = fr.x0, fr.x1, fr.y0, int(fr.foot)
    if uid in FLYERS:
        side = max(x1 - x0, y1 - y0) + 12
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    else:
        side = int((y1 - y0) * 0.78)
        cx, cy = x1 - side // 2 + 4, y0 + side // 2 - 6
    h, w = fr.alpha.shape
    pm = np.zeros((side, side, 4))
    for yy in range(side):
        sy = cy - side // 2 + yy
        if not 0 <= sy < h:
            continue
        lo, hi = cx - side // 2, cx - side // 2 + side
        a, b = max(0, lo), min(w, hi)
        if b <= a:
            continue
        al = fr.alpha[sy, a:b]
        pm[yy, a - lo:b - lo, :3] = fr.fg[sy, a:b] * al[:, None]
        pm[yy, a - lo:b - lo, 3] = al * 255.0
    big = Image.fromarray(np.clip(pm, 0, 255).round().astype(np.uint8), "RGBA").resize((192, 192), Image.LANCZOS)
    out = np.array(big).astype(float)
    al = out[..., 3:4] / 255.0
    out[..., :3] = np.where(al > 0.004, out[..., :3] / np.maximum(al, 0.004), 0)
    out[out[..., 3] < 3] = 0
    return Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["heroes", "pets"])
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--sheet", default="")
    ap.add_argument("--preview", default="")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    cfg = HEROES if args.kind == "heroes" else PETS
    fs, ffb = cfg["fs"], cfg["ffb"]
    sheet = args.sheet or os.path.join(HERE, "art_src", cfg["sheet"])
    rgb = np.array(Image.open(sheet).convert("RGB")).astype(float)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    bands = find_bands(lum, len(cfg["units"]))
    grids = json.load(open(GRIDS)).get("grids", {})
    for bi, (uid, target) in enumerate(cfg["units"]):
        if args.ids and uid not in args.ids:
            continue
        ra, rb, fa, fb = split_rows(lum, *bands[bi])
        frames = {}
        for r, (y0, y1), floor in ((0, ra, fa), (1, rb, fb)):
            fg, al, _ = key_row(rgb[y0:y1, 4:-4], cfg["soft_shadows"])
            for c, (a, bits) in enumerate(split_frames(fg, al)):
                frames[(r, c)] = Frame(fg, a, floor)
                frames[(r, c)].bits = bits
        if uid in PULL:
            sc = HD * target / frames[A(0)].height()
            for key, f in list(frames.items()):
                a2, fg2 = pull_in(f.alpha, f.fg, f.cx, (fs / 2 - 16) / sc)
                frames[key] = Frame(fg2, a2, f.floor)
                frames[key].cx = f.cx
        states, tips, fps, scale = build(args.kind, uid, frames, target, cfg)
        print("%s: scale %.2f, idle %d px tall; %s" % (uid, scale, frames[A(0)].height(),
                                                      ", ".join("%s %d" % (k, len(v)) for k, v in states.items())))
        ext = {}
        for key, f in frames.items():
            xs = np.nonzero((f.alpha > 0.1).any(0))[0]
            ext[key] = int(max(f.cx - xs.min(), xs.max() + 1 - f.cx) * scale)
        print("  half-widths %s" % " ".join("%d%d:%d" % (k[0], k[1], v) for k, v in sorted(ext.items())))
        for k, frs in states.items():
            for i, f in enumerate(frs):
                a = f[..., 3]
                if a[:, :2].max() > 8 or a[:, -2:].max() > 8 or a[:2].max() > 8:
                    print("  warn: %s %s[%d] clipped by the %d px frame" % (uid, k, i, fs))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            for k, frs in states.items():
                strip = np.concatenate(frs, 1)
                bg = np.zeros_like(strip)
                bg[..., :3] = (70, 92, 64)
                bg[..., 3] = 255
                d = np.array(Image.alpha_composite(Image.fromarray(bg, "RGBA"), Image.fromarray(strip, "RGBA")))
                d[fs - ffb, :, :3] = (255, 0, 0)
                d[:, ::fs][..., :3] = (0, 0, 0)
                d[:, fs // 2::fs][..., :3] = (0, 0, 255)
                for i, t in enumerate(tips[k]):
                    x, y = int(t[0]) + i * fs, int(t[1])
                    if args.kind == "heroes" and 0 <= y < fs:
                        d[max(0, y - 2):y + 3, max(0, x - 2):x + 3, :3] = (255, 255, 0)
                Image.fromarray(d).save(os.path.join(args.preview, "%s_%s.png" % (uid, k)))
        if args.dry:
            continue
        out = os.path.join(GAME, "assets", "sprites", cfg["dir"], uid)
        for k, frs in states.items():
            key = "assets/sprites/%s/%s/%s_%s.png" % (cfg["dir"], uid, uid, k)
            write_strip(os.path.join(GAME, key), frs, grids, key, fs)
        side = {"fps": fps, "hd": HD}
        if args.kind == "heroes":
            # UI views (hero select, Gear doll, menus) show the old 128-texel
            # window of the frame: feet at the same place as before.
            w = 128 * HD
            side["ui_window"] = [(fs - w) // 2, fs - w, w, w]
        with open(os.path.join(out, "%s_anim.json" % uid), "w") as fh:
            json.dump(side, fh, indent=1)
        if args.kind == "heroes":
            melee = uid in MELEE_HITS
            if not melee:
                for k in ("attack", "ability"):
                    tips[k] = [muzzle_fix(states[k][i], t) for i, t in enumerate(tips[k])]
            wj = {
                "id": uid, "type": "melee" if melee else "ranged", "frame_size": fs, "baseline_y": fs - ffb,
                "angle_convention": "degrees, 0 = pointing right (+x), positive = counter-clockwise on screen (y up)",
                "hit_frames": {"attack": MELEE_HITS.get(uid, [1]), "ability": ABILITY_HITS.get(uid, [3])},
                "states": {k: [{"tip": t, "angle": 0.0} for t in v] for k, v in tips.items()},
            }
            with open(os.path.join(out, "%s_weapon.json" % uid), "w") as fh:
                json.dump(wj, fh, indent=1)
            # Static 128 px still (fallback art): the UI window of idle frame 0.
            x0, y0, w, _ = side["ui_window"]
            still = Image.fromarray(states["idle"][0], "RGBA").crop((x0, y0, x0 + w, y0 + w))
            still.resize((128, 128), Image.LANCZOS).save(os.path.join(out, "%s.png" % uid), optimize=True)
        else:
            pet_portrait(frames[A(0)], uid).save(
                os.path.join(GAME, "assets", "sprites", "portraits", "pet_%s.png" % uid), optimize=True)
    if not args.dry:
        with open(GRIDS, "w") as fh:
            json.dump({"max": MAX_TEX, "grids": dict(sorted(grids.items()))}, fh, indent=1)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
