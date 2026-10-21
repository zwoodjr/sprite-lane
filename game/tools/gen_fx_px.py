"""Wanderer pixel VFX set (style bible v1, section 5).

Writes horizontal frame strips to assets/sprites/fx/px/ plus fx_px.json (frames,
fps, frame size, anchor, loop, additive) that scripts/fx/px_fx.gd plays.

Rules: master palette only, hard edges, no outline, alpha in {0,64,128,191,255},
<= 8 colours per effect, 1 texel = 1 design px (the game draws them at
UnitAnim.TEXEL). Directional effects (muzzles, swing smears) are drawn at 5 base
angles (0..90 in 22.5 steps) and mirrored with flip_h / flip_v, so no pixel sprite
is ever rotated (projectiles <= 16 px are the only rotated sprites).

    python3 tools/gen_fx_px.py [contact_sheet_dir]
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "sprites", "fx", "px")


def h(x):
    x = x.lstrip("#")
    return (int(x[0:2], 16), int(x[2:4], 16), int(x[4:6], 16))


INK = h("#140c0e")
ASH = [h(c) for c in ["#1f1a1d", "#3a3436", "#5d5654", "#8f877e", "#e9dfc9"]]
EARTH = [h(c) for c in ["#3a2d27", "#5a4636", "#7c6550", "#a08669", "#c8b08a"]]
RUST = [h(c) for c in ["#3e1a12", "#763420", "#ad5a2a", "#d98a45"]]
BRASS = [h(c) for c in ["#3e2a10", "#7a5520", "#b88a33", "#e8c972"]]
STEEL = [h(c) for c in ["#1b222c", "#36424f", "#5e6d7a", "#9aa8ad"]]
CLOTH = [h(c) for c in ["#2a2a1c", "#59563a", "#8f8a5e"]]
PLAGUE = [h(c) for c in ["#142a18", "#2b5a2c", "#57932f", "#9ccf3e", "#dcf58a"]]
FLESH = [h(c) for c in ["#2e1830", "#5a3254", "#8a5474", "#c08aa0"]]
DUST = [h(c) for c in ["#5e260c", "#a8520f", "#e88a1c", "#ffc040", "#fff2c0"]]
BLOOD = h("#9a1e26")
TEAL = [h("#1f5a58"), h("#5cd2c0")]
SIGNAL = h("#ff4836")
BONE = ASH[4]
PALETTE = set([INK, BLOOD, SIGNAL] + ASH + EARTH + RUST + BRASS + STEEL + CLOTH + PLAGUE + FLESH + DUST + TEAL)
ALPHAS = (0, 64, 128, 191, 255)
A100, A75, A50, A25 = 255, 191, 128, 64

MANIFEST = {}
STRIPS = {}  # id -> list of frames (for the contact sheet)


# ---------------------------------------------------------------- drawing kit
def canvas(w, h_):
    return np.zeros((h_, w, 4), np.uint8)


def put(a, x, y, c, al=255):
    x, y = int(math.floor(x)), int(math.floor(y))
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x, :3] = c
        a[y, x, 3] = al


def grid(a):
    H, W = a.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    return xx + 0.5, yy + 0.5


def disc(a, cx, cy, r, c, al=255, sy=1.0):
    xx, yy = grid(a)
    m = (xx - cx) ** 2 + ((yy - cy) / sy) ** 2 <= r * r
    a[m, :3] = c
    a[m, 3] = al
    return m


def ring(a, cx, cy, r, c, al=255, th=1.0, sy=1.0, broken=0, seed=0):
    xx, yy = grid(a)
    d = np.sqrt((xx - cx) ** 2 + ((yy - cy) / sy) ** 2)
    m = np.abs(d - r) < th * 0.5 + 0.08
    if broken:
        ang = np.arctan2((yy - cy) / sy, xx - cx)
        m &= ((ang + seed) * broken / math.pi).astype(int) % 3 != 0
    a[m, :3] = c
    a[m, 3] = al
    return m


def puff(a, cx, cy, r, al=255, ramp=None):
    """Lit smoke ball: base tone, highlight crescent top-left, shade crescent bottom-right."""
    ramp = ramp or (ASH[1], ASH[2], ASH[3])
    xx, yy = grid(a)
    inside = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    hl = inside & ((xx - (cx + 0.35 * r)) ** 2 + (yy - (cy + 0.4 * r)) ** 2 > (0.95 * r) ** 2)
    sh = inside & ((xx - (cx - 0.3 * r)) ** 2 + (yy - (cy - 0.35 * r)) ** 2 > (1.05 * r) ** 2)
    a[inside, :3] = ramp[1]
    a[hl, :3] = ramp[2]
    a[sh, :3] = ramp[0]
    a[inside, 3] = al
    return inside


def line(a, x0, y0, x1, y1, c, al=255):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(n, 1)
        put(a, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c, al)


def streak(a, x, y, ang, length, head, tail, al=255):
    """Spark: bright head pixel, darker tail behind it."""
    for k in range(length):
        put(a, x - math.cos(ang) * k, y - math.sin(ang) * k, head if k == 0 else tail, al)


def chunk(a, x, y, w, h_, light, dark, al=255):
    """Debris bit: lit top-left, dark bottom-right pixel row/col."""
    for j in range(h_):
        for i in range(w):
            c = dark if (i == w - 1 or j == h_ - 1) and (w > 1 and h_ > 1) else light
            put(a, x + i, y + j, c, al)


def fade(a, al):
    """Scale every opaque pixel to an alpha step (never above its own)."""
    m = a[:, :, 3] > 0
    a[m, 3] = np.minimum(a[m, 3], al)
    return a


def snap_alpha(a):
    al = a[:, :, 3].astype(int)
    steps = np.array(ALPHAS)
    idx = np.abs(al[..., None] - steps[None, None, :]).argmin(-1)
    a[:, :, 3] = steps[idx]
    a[a[:, :, 3] == 0, :3] = 0
    return a


def emit(fid, frames, fps, ox=None, oy=None, loop=False, add=False, z=5):
    frames = [snap_alpha(f) for f in frames]
    hh, ww = frames[0].shape[:2]
    strip = np.concatenate(frames, 1)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(strip, "RGBA").save(os.path.join(OUT, fid + ".png"))
    MANIFEST[fid] = {"n": len(frames), "w": ww, "h": hh, "fps": fps,
                     "ox": ww / 2 if ox is None else ox, "oy": hh / 2 if oy is None else oy,
                     "loop": loop, "add": add, "z": z}
    STRIPS[fid] = frames


def validate():
    bad = []
    for fid, frames in STRIPS.items():
        cols = set()
        for f in frames:
            m = f[:, :, 3] > 0
            for c in map(tuple, f[m][:, :3]):
                cols.add(c)
                if c not in PALETTE:
                    bad.append((fid, "offpalette", c))
                    break
            if not set(np.unique(f[:, :, 3])) <= set(ALPHAS):
                bad.append((fid, "alpha", sorted(set(np.unique(f[:, :, 3])))))
        if len(cols) > 8:
            bad.append((fid, "colours", len(cols)))
    return bad


# ------------------------------------------------- directional (mirrored) fx
BASE_ANGLES = [0.0, 22.5, 45.0, 67.5, 90.0]


def render_dir(fn, nframes, reach, pad=2):
    """fn(f, u, v) -> (rgb, alpha) arrays for canonical coords (u along the aim).
    Returns per base angle: frames, origin. Canvas covers the rotated reach box."""
    out = []
    for deg in BASE_ANGLES:
        a = math.radians(deg)
        x0, x1, y0, y1 = reach
        corners = [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]
        rc = [(u * math.cos(a) - v * math.sin(a), u * math.sin(a) + v * math.cos(a)) for u, v in corners]
        minx = math.floor(min(p[0] for p in rc)) - pad
        maxx = math.ceil(max(p[0] for p in rc)) + pad
        miny = math.floor(min(p[1] for p in rc)) - pad
        maxy = math.ceil(max(p[1] for p in rc)) + pad
        W, H = maxx - minx, maxy - miny
        yy, xx = np.mgrid[0:H, 0:W]
        px = xx + 0.5 + minx
        py = yy + 0.5 + miny
        u = px * math.cos(a) + py * math.sin(a)
        v = -px * math.sin(a) + py * math.cos(a)
        frames = []
        for f in range(nframes):
            col, al = fn(f, u, v)
            fr = canvas(W, H)
            fr[:, :, :3] = col
            fr[:, :, 3] = al
            frames.append(fr)
        out.append((frames, -minx, -miny))
    return out


def emit_dir(fid, fn, nframes, fps, reach, z=5, add=False):
    for i, (frames, ox, oy) in enumerate(render_dir(fn, nframes, reach)):
        emit("%s@%d" % (fid, i), frames, fps, ox, oy, z=z, add=add)


def paint(col, al, mask, c, alpha):
    col[mask] = c
    al[mask] = alpha


def hash01(u, v, s=0):
    """Stable per-texel noise from canonical coords (for chips / sparkle)."""
    k = np.floor(u).astype(np.int64) * 73856093 ^ np.floor(v).astype(np.int64) * 19349663 ^ (s * 83492791)
    return (k % 1000) / 1000.0


# ---------------------------------------------------------------- muzzles
def muzzle_fn(L, W, petals=True, core=BONE, mid=DUST[3], outer=DUST[2], smoke=False, frames=3):
    lens = [L * 0.8, L, L * 0.5][:frames] if frames == 3 else [L, L * 0.55]
    wids = [W * 0.8, W, W * 0.6][:frames] if frames == 3 else [W, W * 0.6]

    def fn(f, u, v):
        col = np.zeros(u.shape + (3,), np.uint8)
        al = np.zeros(u.shape, np.uint8)
        Lf, Wf = lens[f], wids[f]
        t = np.clip(u / max(Lf, 1), 0, 1)
        hw = Wf * (1 - t) ** 0.7
        inside = (u >= 0) & (u <= Lf) & (np.abs(v) <= hw)
        last = f == len(lens) - 1
        paint(col, al, inside, outer, 255)
        paint(col, al, inside & (np.abs(v) <= hw * 0.7), mid, 255)
        if not last:
            paint(col, al, inside & (np.abs(v) <= hw * 0.38) & (u < Lf * 0.55), core, 255)
        if petals and not last:
            # side petals (brake / star points), 45 degrees back
            for s in (-1, 1):
                pv = s * (Wf * 0.55 + (u - 1) * 0.55)
                pm = (u >= 1) & (u <= 2 + Wf * 0.9) & (np.abs(v - pv) < 0.75)
                paint(col, al, pm, mid, 255)
        if smoke and f >= 1:
            # launcher back-blast puffs behind the muzzle (fade)
            for k, (cu, cv, r) in enumerate([(-3, -3, 3.2), (-4, 3, 2.8), (-7, 0, 2.5)]):
                rr = r + f
                pm = ((u - cu) ** 2 + (v - cv) ** 2 <= rr * rr) & (al == 0)
                hl = pm & ((u - cu) + (v - cv) < -rr * 0.3)
                paint(col, al, pm, ASH[2], A75 if f == 1 else A50)
                paint(col, al, hl, ASH[3], A75 if f == 1 else A50)
        return col, al
    return fn


def gen_muzzles():
    # Rook: launcher blast — fat flash + back-blast smoke
    emit_dir("mz_launcher", muzzle_fn(14, 6.5, True, smoke=True), 3, 30, (-11, 16, -9, 9))
    # Vesper: heavy rifle — long, narrow, brake petals; plague-tinted outer for the coated slug
    emit_dir("mz_rifle", muzzle_fn(19, 4.0, True), 3, 30, (-2, 21, -7, 7))
    # Cinder: suppressor AR — compact, hotter core
    emit_dir("mz_ar", muzzle_fn(12, 3.5, True), 3, 30, (-2, 14, -6, 6))
    # Helm: pilot sidearm — small bone-white pop
    emit_dir("mz_pistol", muzzle_fn(8, 3.0, False, core=BONE, mid=DUST[4], outer=DUST[3]), 3, 30, (-2, 10, -5, 5))
    # Helm's drones + SMG-class: 2 frames
    emit_dir("mz_drone", muzzle_fn(6, 2.5, False, core=BONE, mid=TEAL[1], outer=TEAL[0], frames=2), 2, 30, (-2, 8, -4, 4))
    emit_dir("mz_smg", muzzle_fn(9, 3.0, True, frames=2), 2, 30, (-2, 11, -5, 5))


# ---------------------------------------------------------------- projectiles
def gen_projectiles():
    def bar(w, cols, hgt=1):
        a = canvas(w, max(2, hgt + 1) if hgt > 1 else 2)
        return a
    # tracers: horizontal, origin at the head (right end)
    def tracer(name, length, cols, thick=1):
        hh = thick + 2
        a = canvas(length, hh)
        cy = hh // 2
        for x in range(length):
            t = x / (length - 1)  # 0 tail -> 1 head
            c = cols[min(len(cols) - 1, int(t * len(cols)))]
            al = A50 if t < 0.25 else (A75 if t < 0.5 else 255)
            for y in range(thick):
                put(a, x, cy - thick // 2 + y, c, al)
        put(a, length - 1, cy - thick // 2 - 0, cols[-1])
        emit(name, [a], 1, length - 3, cy)
    tracer("pj_tracer", 10, [DUST[1], DUST[2], DUST[3], DUST[4]], 2)
    tracer("pj_pistol", 7, [ASH[3], BONE, BONE], 1)
    tracer("pj_drone", 6, [TEAL[0], TEAL[1], BONE], 1)
    tracer("pj_smg", 6, [DUST[2], DUST[3], DUST[4]], 1)
    # Vesper's coated slug: plague-green, 2 px body + bright head
    a = canvas(11, 5)
    for x in range(11):
        c = PLAGUE[1] if x < 3 else (PLAGUE[2] if x < 6 else PLAGUE[3])
        al = A50 if x < 2 else (A75 if x < 4 else 255)
        put(a, x, 2, c, al)
        if x >= 5:
            put(a, x, 1, PLAGUE[3] if x < 9 else PLAGUE[4])
            put(a, x, 3, PLAGUE[2])
    put(a, 10, 2, PLAGUE[4]); put(a, 9, 1, BONE)
    emit("pj_slug", [a], 1, 8, 2.5)
    # Rook rocket 16x7: steel body, brass band, rust nose, flame flicker 2 frames
    fr = []
    for f in range(2):
        a = canvas(16, 7)
        for x in range(5, 14):
            put(a, x, 2, STEEL[3]); put(a, x, 3, STEEL[2]); put(a, x, 4, STEEL[1])
        for y in (2, 3, 4):
            put(a, 9, y, BRASS[2])
        put(a, 14, 3, RUST[2]); put(a, 14, 2, RUST[2]); put(a, 14, 4, STEEL[1]); put(a, 15, 3, RUST[2])
        put(a, 5, 1, STEEL[2]); put(a, 6, 1, STEEL[2]); put(a, 5, 5, STEEL[1]); put(a, 6, 5, STEEL[1])  # fins
        fl = [(4, 3, BONE), (3, 3, DUST[3]), (3, 2, DUST[2]), (3, 4, DUST[2]), (2, 3, DUST[2]), (1, 3, DUST[1])]
        if f == 1:
            fl = [(4, 3, BONE), (3, 3, DUST[4]), (2, 3, DUST[3]), (2, 2, DUST[2]), (2, 4, DUST[2]), (1, 3, DUST[2]), (0, 3, DUST[1])]
        for (x, y, c) in fl:
            c = DUST[2] if c == DUST[1] else (DUST[3] if c == DUST[4] else c)
            put(a, x, y, c)
        fr.append(a)
    emit("pj_rocket", fr, 20, 12, 3.5, loop=True)
    # enemy shot: SIGNAL orb, bone core, 2-frame pulse
    fr = []
    for f in range(2):
        a = canvas(9, 9)
        disc(a, 4.5, 4.5, 4.2 if f == 0 else 3.8, SIGNAL)
        disc(a, 4.5, 4.5, 2.6, h("#ff4836"))
        disc(a, 4.0, 4.0, 1.5 if f == 0 else 1.2, BONE)
        if f == 1:
            ring(a, 4.5, 4.5, 4.0, RUST[2], A50)
        fr.append(a)
    emit("pj_enemy", fr, 10, loop=True)
    # plague spit (enemy plague shooters): green glob with signal rim for danger
    fr = []
    for f in range(2):
        a = canvas(9, 9)
        disc(a, 4.5, 4.5, 4.2, SIGNAL)
        disc(a, 4.5, 4.5, 3.3, PLAGUE[2])
        disc(a, 4.0, 4.0, 2.0, PLAGUE[3])
        put(a, 3, 3, PLAGUE[4] if f == 0 else BONE)
        fr.append(a)
    emit("pj_spit", fr, 10, loop=True)
    # special-ammo rounds (8x5): incendiary / shock / frost / explosive
    def round_(name, body, head, glint):
        fr = []
        for f in range(2):
            a = canvas(10, 5)
            for x in range(10):
                al = A50 if x < 2 else (A75 if x < 4 else 255)
                put(a, x, 2, body[0] if x < 4 else body[1], al)
            for x in range(5, 9):
                put(a, x, 1, body[1]); put(a, x, 3, body[0])
            put(a, 9, 2, head); put(a, 8, 2, head)
            put(a, 7 if f == 0 else 6, 1, glint)
            fr.append(a)
        emit(name, fr, 12, 7, 2.5, loop=True)
    round_("pj_incendiary", (DUST[1], DUST[2]), DUST[3], BONE)
    round_("pj_shock", (TEAL[0], TEAL[1]), BONE, BONE)
    round_("pj_frost", (STEEL[2], STEEL[3]), TEAL[1], BONE)
    round_("pj_explosive", (RUST[1], RUST[2]), DUST[3], DUST[4])
    # Vesper's vial (thrown, spins): glass bottle, plague fill
    a = canvas(8, 10)
    for y in range(3, 9):
        for x in range(1, 7):
            put(a, x, y, PLAGUE[2] if y > 4 else PLAGUE[3])
    for y in range(3, 9):
        put(a, 1, y, STEEL[3]); put(a, 6, y, STEEL[2])
    for x in range(1, 7):
        put(a, x, 9, STEEL[1])
    put(a, 3, 2, STEEL[3]); put(a, 4, 2, STEEL[2]); put(a, 3, 1, RUST[2]); put(a, 4, 1, RUST[2])
    put(a, 2, 4, PLAGUE[4]); put(a, 2, 5, BONE)
    emit("pj_vial", [a], 1)
    # smoke puff for rocket trails: 4 frames, ASH 3 / BONE, alpha steps
    fr = []
    for f in range(4):
        a = canvas(9, 9)
        r = [2.2, 3.2, 3.8, 3.6][f]
        puff(a, 4.5, 4.5, r, [255, 191, 128, 64][f], (ASH[2], ASH[3], BONE if f < 2 else ASH[3]))
        if f == 0:
            put(a, 4, 4, DUST[3])
        fr.append(a)
    emit("smoke_puff", fr, 12, z=4)


# ---------------------------------------------------------------- impacts (16)
def gen_impacts():
    S, c = 16, 8.0
    # generic spark: bone cross -> amber ring -> ash
    fr = []
    for f in range(4):
        a = canvas(S, S)
        if f == 0:
            for d in range(-3, 4):
                put(a, c + d, c, BONE); put(a, c, c + d, BONE)
            disc(a, c, c, 1.6, BONE)
            for k in (-2, 2):
                put(a, c + k, c + k, DUST[3]); put(a, c + k, c - k, DUST[3])
        else:
            r = 2 + f * 2
            for k in range(8):
                t = k * math.pi / 4 + 0.3
                for dd in range(r - 1, r + 1):
                    put(a, c + dd * math.cos(t), c + dd * math.sin(t), [DUST[3], DUST[2], ASH[2]][f - 1], [255, 255, 128][f - 1])
        fr.append(a)
    emit("hit_spark", fr, 24)

    # flesh / plague: purple-green splatter
    rnd = random.Random(3)
    drops = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.6, 1.1)) for _ in range(9)]
    fr = []
    for f in range(4):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c, 3.5, FLESH[2]); disc(a, c - 0.5, c - 0.5, 2.0, FLESH[3]); put(a, c, c, BONE)
        else:
            disc(a, c, c + f * 0.5, [3.0, 2.0, 1.0][f - 1], FLESH[[2, 1, 1][f - 1]], [255, 255, 128][f - 1])
            for i, (t, sp) in enumerate(drops):
                d = (2.5 + f * 1.8) * sp
                x, y = c + math.cos(t) * d, c + math.sin(t) * d + f * f * 0.3
                col = PLAGUE[3] if i % 3 == 0 else (FLESH[3] if i % 3 == 1 else FLESH[2])
                al = [255, 255, 128][f - 1]
                put(a, x, y, col, al)
                if f == 1:
                    put(a, x - math.cos(t), y - math.sin(t), FLESH[1], al)
        fr.append(a)
    emit("hit_flesh", fr, 24)

    # machine: sparks + scrap bits
    rnd = random.Random(7)
    sp = [(rnd.uniform(-2.6, -0.2) if i % 2 else rnd.uniform(0.2, 2.6) - math.pi, rnd.uniform(0.7, 1.2)) for i in range(7)]
    sp = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.7, 1.2)) for _ in range(7)]
    fr = []
    for f in range(4):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c, 2.5, DUST[4]); disc(a, c, c, 1.3, BONE)
            for k in range(4):
                t = k * math.pi / 2 + 0.78
                line(a, c + math.cos(t) * 2, c + math.sin(t) * 2, c + math.cos(t) * 5, c + math.sin(t) * 5, DUST[3])
        else:
            for i, (t, s) in enumerate(sp):
                d = (2 + f * 2.2) * s
                x, y = c + math.cos(t) * d, c + math.sin(t) * d + (f - 1) * 0.8
                if i < 5:
                    streak(a, x, y, t, 3 if f == 1 else 2, DUST[4] if f < 3 else DUST[2], DUST[2] if f < 3 else DUST[1])
                else:
                    chunk(a, x, y, 2, 2, STEEL[3], STEEL[1])
            if f == 3:
                fade(a, A50)
        fr.append(a)
    emit("hit_machine", fr, 24)

    # raider: blood drops + cloth puff
    rnd = random.Random(11)
    drops = [(rnd.uniform(-math.pi, 0.4), rnd.uniform(0.6, 1.1)) for _ in range(6)]
    fr = []
    for f in range(4):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c, 2.6, BLOOD); put(a, c - 1, c - 1, BONE)
        else:
            puff(a, c + 1, c - f * 0.5, 1.5 + f, [191, 128, 64][f - 1], (CLOTH[0], CLOTH[1], CLOTH[2]))
            for (t, s) in drops:
                d = (2 + f * 1.8) * s
                put(a, c + math.cos(t) * d, c + math.sin(t) * d + f * f * 0.4, BLOOD, [255, 255, 128][f - 1])
                if f == 1:
                    put(a, c + math.cos(t) * d, c + math.sin(t) * d + 1, RUST[0])
        fr.append(a)
    emit("hit_raider", fr, 24)

    # ground / props: dust chips + earth puff
    rnd = random.Random(5)
    chips = [(rnd.uniform(-math.pi * 0.95, -0.05), rnd.uniform(0.6, 1.1)) for _ in range(6)]
    fr = []
    for f in range(4):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c + 2, 2.4, EARTH[4]); put(a, c, c + 2, BONE)
        else:
            puff(a, c, c + 2 - f * 0.6, 1.8 + f * 1.1, [255, 191, 128][f - 1], (EARTH[1], EARTH[2], EARTH[3]))
            for (t, s) in chips:
                d = (2.5 + f * 2) * s
                x, y = c + math.cos(t) * d, c + 2 + math.sin(t) * d + f * f * 0.6
                chunk(a, x, y, 2 if s > 0.85 else 1, 1 if s > 0.85 else 1, EARTH[3], EARTH[1], [255, 255, 191][f - 1])
        fr.append(a)
    emit("hit_dust", fr, 24)

    # special-ammo hits
    def elem_hit(name, core, mid, outer, kind):
        rnd = random.Random(hash(name) & 0xffff)
        fr = []
        for f in range(4):
            a = canvas(S, S)
            if kind == "fire":
                if f == 0:
                    disc(a, c, c, 3.5, DUST[2]); disc(a, c, c, 2.2, DUST[3]); disc(a, c, c - 0.5, 1.2, BONE)
                else:
                    for k in range(5):
                        x = c - 4 + k * 2 + (f % 2)
                        hgt = [5, 7, 4, 6, 3][k] - f
                        for y in range(max(0, hgt)):
                            col = DUST[1] if y < 1 else (DUST[2] if y < hgt * 0.6 else DUST[3])
                            put(a, x, c + 3 - y - f, col, 255 if f < 3 else 128)
                    put(a, c + rnd.randint(-3, 3), c - 4 - f, DUST[4])
            elif kind == "shock":
                if f == 0:
                    disc(a, c, c, 2, BONE)
                    for k in range(4):
                        t = k * math.pi / 2 + 0.4
                        line(a, c, c, c + math.cos(t) * 6, c + math.sin(t) * 6, TEAL[1])
                else:
                    pts = [(c, c)]
                    for k in range(3):
                        t = rnd.uniform(0, 2 * math.pi)
                        x, y = c, c
                        for s in range(3 + f):
                            nx, ny = x + math.cos(t) * 2, y + math.sin(t) * 2
                            t += rnd.uniform(-0.9, 0.9)
                            line(a, x, y, nx, ny, TEAL[1] if s < 2 else TEAL[0], 255 if f < 3 else 128)
                            x, y = nx, ny
                        put(a, x, y, BONE)
            elif kind == "frost":
                if f == 0:
                    disc(a, c, c, 2.5, BONE)
                r = 2 + f * 1.6
                for k in range(6):
                    t = k * math.pi / 3
                    x, y = c + math.cos(t) * r, c + math.sin(t) * r
                    line(a, c + math.cos(t) * (r - 2), c + math.sin(t) * (r - 2), x, y, STEEL[3] if f < 3 else TEAL[0], 255 if f < 3 else 128)
                    put(a, x, y, BONE if f < 2 else TEAL[1])
                if f == 1:
                    disc(a, c, c, 1.5, TEAL[1])
            fr.append(a)
        emit(name, fr, 24)
    elem_hit("hit_fire", None, None, None, "fire")
    elem_hit("hit_shock", None, None, None, "shock")
    elem_hit("hit_frost", None, None, None, "frost")


# ---------------------------------------------------------------- explosions
def explosion(S=64, n=8, seed=5, fire=DUST, core=BONE, smoke=(ASH[0], ASH[1], ASH[2]), grows=None, debris=STEEL, nsparks=10, ring_col=None):
    rnd = random.Random(seed)
    cx, cy = S / 2, S / 2 + S / 16
    k = S / 64.0
    xx = np.mgrid[0:S, 0:S][1] + 0.5
    yy = np.mgrid[0:S, 0:S][0] + 0.5
    base = [(rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(0.45, 0.8)) for _ in range(9)]
    sparks = [(math.radians(rnd.uniform(0, 360)), rnd.uniform(0.7, 1.2)) for _ in range(nsparks)]
    bits = [(math.radians(rnd.uniform(200, 340)), rnd.uniform(0.6, 1.0)) for _ in range(5)]
    grows = grows or [0, 13, 17, 19, 20, 21, 22, 22]
    rises = [0, 0, 1, 3, 6, 9, 12, 15]
    if n == 6:
        grows = [0, 14, 18, 20, 21, 22]
        rises = [0, 0, 2, 5, 9, 13]
    fire_ts = [0, 1.6, 1.4, 1.0, 0.62, 0.3, 0.0, 0.0][:n] if n == 8 else [0, 1.6, 1.2, 0.7, 0.3, 0.0]
    smoke_al = [255] * (n - 2) + [191, 128]
    frames = []
    for f in range(n):
        a = canvas(S, S)
        if f == 0:
            r = 7 * k
            disc(a, cx, cy, r, fire[3])
            disc(a, cx - 1, cy - 1, 4 * k, core)
            for kk in range(8):
                t = kk * math.pi / 4
                for d in range(int(8 * k), int((12 if kk % 2 == 0 else 10) * k)):
                    put(a, cx + d * math.cos(t), cy + d * math.sin(t), fire[4] if len(fire) > 4 else core)
            frames.append(a)
            continue
        grow = grows[f] * k
        rise = rises[f] * k
        puffs = [(cx + bx * grow * 0.75, cy - rise * (0.6 + 0.4 * (by + 1) / 2) + by * grow * 0.55,
                  br * grow * (0.95 if f < 4 else 0.8 + 0.06 * f)) for bx, by, br in base]
        heat = np.full((S, S), 9.0)
        m = np.zeros((S, S), bool)
        for (x, y, r) in sorted(puffs, key=lambda p: p[1]):
            inside = puff(a, x, y, r, smoke_al[f], (smoke[0], smoke[1], smoke[2]))
            m |= inside
            dn = np.sqrt((xx - (x - 0.15 * r)) ** 2 + (yy - (y - 0.2 * r)) ** 2) / max(r, 1)
            heat = np.minimum(heat, np.where(inside, dn, 9.0))
        ft = fire_ts[f]
        if ft > 0:
            dc = np.sqrt((xx - cx) ** 2 + (yy - (cy - rise * 0.6)) ** 2) / max(1, grow)
            hv = heat * 0.55 + dc * 0.9
            lim = ft * 1.25
            fm = m & (hv < lim)
            for thr, col in ((1.0, fire[1]), (0.72, fire[2]), (0.45, fire[3]), (0.22, core)):
                if col == core and f > 2:
                    continue
                if col == fire[3] and f > 4:
                    continue
                sel = fm & (hv < lim * thr)
                a[sel, :3] = col
                a[sel, 3] = 255
        if f in (1, 2):
            rr = [0, 17, 24][f] * k
            rc = ring_col or (core, fire[3])
            ring(a, cx, cy, rr, rc[f - 1], 255, 1.0 if k < 1.2 else 2.0, 1 / 1.25, broken=6, seed=f)
        if 1 <= f <= 4:
            for (t, sp) in sparks:
                d = (8 + f * 6) * sp * k
                x, y = cx + math.cos(t) * d, cy + math.sin(t) * d - f
                streak(a, x, y, t, 2 if f < 3 else 1, fire[4] if len(fire) > 4 else core, fire[2])
        if debris is not None and 1 <= f <= n - 2:
            for (t, sp) in bits:
                d = (6 + f * 5) * sp * k
                x = cx + math.cos(t) * d
                y = cy + math.sin(t) * d + (f * f) * 0.9 * k
                chunk(a, x, y, 2, 2, debris[2], debris[0])
        if n - 4 <= f <= n - 2:
            for (t, sp) in sparks[:5]:
                x, y = int(cx + math.cos(t) * grow * 0.4), int(cy - rise + math.sin(t) * grow * 0.3)
                if 0 <= x < S and 0 <= y < S and m[y, x]:
                    put(a, x, y, fire[3] if f == n - 4 else fire[2])
        frames.append(a)
    return frames


def gen_explosions():
    emit("ex_small", explosion(64, 6, seed=5, debris=ASH), 20)
    emit("ex_big", explosion(96, 8, seed=9, nsparks=14, debris=ASH), 20)
    # vial / bloat burst: plague ramp
    emit("ex_plague", explosion(64, 6, seed=21, fire=PLAGUE, core=PLAGUE[4], smoke=(PLAGUE[0], PLAGUE[1], PLAGUE[2]), debris=None, ring_col=(PLAGUE[4], PLAGUE[3])), 20)
    # tiny explosive-ammo pop (32)
    emit("ex_tiny", explosion(32, 6, seed=13, nsparks=6, debris=None), 24)


def gen_shock_burst():
    S = 64
    c = S / 2
    rnd = random.Random(17)
    arms = [rnd.uniform(0, 2 * math.pi) for _ in range(7)]
    fr = []
    for f in range(6):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c, 5, TEAL[1]); disc(a, c, c, 3, BONE)
        else:
            r = 6 + f * 4.5
            ring(a, c, c + 2, r, TEAL[1] if f < 4 else TEAL[0], 255 if f < 5 else 128, 1.0, 0.6, broken=5, seed=f)
            for i, t in enumerate(arms):
                x, y = c, c
                tt = t + f * 0.3
                L = int(3 + f * 1.5) if f < 5 else 2
                for s in range(L):
                    nx, ny = x + math.cos(tt) * 3, y + math.sin(tt) * 3
                    tt += rnd.uniform(-0.8, 0.8)
                    line(a, x, y, nx, ny, BONE if s == L - 1 else TEAL[1], 255 if f < 4 else 128)
                    x, y = nx, ny
            if f < 3:
                disc(a, c, c, 4 - f, BONE)
        fr.append(a)
    emit("ex_shock", fr, 20)


def gen_slam():
    """Ground slam / shockwave: squashed dust ring, cracks, rocks, dust puffs (EARTH + ASH)."""
    W, H = 128, 72
    cx, cy = W / 2, H / 2 + 6
    rnd = random.Random(23)
    rocks = [(rnd.uniform(math.pi * 1.05, math.pi * 1.95), rnd.uniform(0.5, 1.0), rnd.choice([1, 2, 2, 3])) for _ in range(9)]
    puffs_ = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.8, 1.0)) for _ in range(10)]
    fr = []
    for f in range(8):
        a = canvas(W, H)
        if f == 0:
            disc(a, cx, cy, 14, EARTH[4], 255, 0.45)
            disc(a, cx, cy, 8, BONE, 255, 0.45)
            fr.append(a)
            continue
        r = [0, 22, 34, 44, 52, 57, 60, 62][f]
        al = [255, 255, 255, 255, 191, 128, 64, 64][f]
        # dust puffs along the ring (lit)
        for (t, s) in puffs_:
            x, y = cx + math.cos(t) * r * s, cy + math.sin(t) * r * s * 0.42
            pr = 4 + f * 0.8 if f < 6 else 7 - (f - 6)
            puff(a, x, y - f * 0.6, pr, al, (EARTH[1], EARTH[2], EARTH[3]))
        if f <= 4:
            ring(a, cx, cy, r, BONE if f < 3 else EARTH[4], 255, 1.5, 0.42, broken=7, seed=f)
            ring(a, cx, cy, r - 2, EARTH[3], 255 if f < 3 else 191, 1.0, 0.42, broken=5, seed=f + 2)
        # rocks thrown up and falling
        if f <= 6:
            for (t, s, sz) in rocks:
                d = (10 + f * 6) * s
                x = cx + math.cos(t) * d * 1.3
                y = cy + math.sin(t) * d * 0.9 + f * f * 0.75
                chunk(a, x, y, sz, sz, EARTH[3], EARTH[0])
        # centre glow & dust pillar
        if f <= 2:
            disc(a, cx, cy, 10 - f * 3, EARTH[4], 255, 0.45)
        fr.append(a)
    emit("ex_slam", fr, 20, oy=cy, z=3)


# ---------------------------------------------------------------- smears
def arc_smear(R, r_in, half_deg, edge, body, tail, chips=None, sparkle=None):
    half = math.radians(half_deg)

    def fn(f, u, v):
        col = np.zeros(u.shape + (3,), np.uint8)
        al = np.zeros(u.shape, np.uint8)
        d = np.sqrt(u * u + v * v)
        ang = np.arctan2(v, u)  # -half (start) .. +half (end)
        t = (ang + half) / (2 * half)  # 0..1 along the sweep
        prog = [0.6, 1.0, 1.0][f]
        lo = [0.0, 0.0, 0.45][f]
        # crescent: thickest at the leading third, thin at both ends
        thick = np.sin(np.clip(t, 0, 1) * math.pi) ** 0.6
        inner = R - (R - r_in) * thick
        band = (d <= R) & (d >= inner) & (t >= lo) & (t <= prog)
        lead = t > prog - 0.18
        outer_edge = d > R - 2.2
        if f < 2:
            paint(col, al, band, tail, A50)
            paint(col, al, band & (t > prog * 0.3), tail, A75)
            paint(col, al, band & (t > prog * 0.55), body, 255)
            paint(col, al, band & ((outer_edge & (t > prog * 0.3)) | lead), edge, 255)
        else:
            paint(col, al, band & (d > (R + inner) * 0.5), tail, A50)
            paint(col, al, band & outer_edge, body, A50)
        if chips is not None and f >= 1:
            hz = hash01(u / 3, v / 3, f)
            cm = (d > R) & (d < R + 6 + f * 3) & (t > 0.3) & (t < 1.0) & (hz > 0.93) & (al == 0)
            paint(col, al, cm, chips, 255 if f == 1 else A50)
        if sparkle is not None and f == 1:
            sm = (np.abs(d - R + 1) < 0.6) & (np.abs(t - 0.92) < 0.03)
            paint(col, al, sm, sparkle, 255)
        return col, al
    return fn


def line_smear(L, Wd):
    """Juno's chain-gauntlet lash: steel/brass links whipping out, teal-bone spark at the tip."""
    def fn(f, u, v):
        col = np.zeros(u.shape + (3,), np.uint8)
        al = np.zeros(u.shape, np.uint8)
        ext = [0.6, 1.0, 0.75][f] * L
        wave = np.sin(u / L * math.pi * 2.0 + f) * (Wd * 0.12) * (u / L)
        on = (u >= 10) & (u <= ext) & (np.abs(v - wave) <= 1.6)
        link = (np.floor(u / 4) % 2 == 0)
        a_ = 255 if f < 2 else A50
        paint(col, al, on & link, STEEL[3], a_)
        paint(col, al, on & ~link, BRASS[2], a_)
        paint(col, al, on & (v - wave > 0.5), STEEL[1], a_)
        # motion smear beside the chain (bone, thin, alpha)
        sm = (u >= 14) & (u <= ext - 4) & (np.abs(v - wave - Wd * 0.22) <= 0.6)
        if f < 2:
            paint(col, al, sm & (al == 0), BONE, A50)
        # tip: gauntlet spark burst
        tu, tv = ext, np.sin(ext / L * math.pi * 2.0 + f) * (Wd * 0.12) * (ext / L)
        dd = np.sqrt((u - tu) ** 2 + (v - tv) ** 2)
        if f == 1:
            paint(col, al, dd <= 6, TEAL[1], 255)
            paint(col, al, dd <= 3, BONE, 255)
            ang = np.arctan2(v - tv, u - tu)
            rays = (dd > 6) & (dd < 11) & (np.abs(((ang * 4 / math.pi) % 1) - 0.5) < 0.09)
            paint(col, al, rays, TEAL[1], 255)
        elif f == 0:
            paint(col, al, dd <= 3, BONE, 255)
        else:
            paint(col, al, (dd <= 4) & (dd > 2.5), TEAL[0], A50)
        return col, al
    return fn


def gen_smears():
    TX = 1.35 * 1.25  # world px * MELEE_K -> texels
    R = 80 * TX
    emit_dir("sm_maul", arc_smear(R, R * 0.55, 70, BONE, ASH[3], ASH[2], chips=EARTH[3]), 3, 18, (0, R + 18, -R - 6, R + 6), z=3)
    R = 72 * TX
    emit_dir("sm_blade", arc_smear(R, R * 0.8, 50, BONE, DUST[3], DUST[2], sparkle=DUST[4]), 3, 24, (0, R + 4, -R * 0.8, R * 0.8), z=3)
    emit_dir("sm_bayonet", arc_smear(R, R * 0.78, 50, BONE, STEEL[3], STEEL[2], sparkle=BONE), 3, 24, (0, R + 4, -R * 0.8, R * 0.8), z=3)
    L = 140 * TX
    emit_dir("sm_chain", line_smear(L, 34 * TX), 3, 20, (0, L + 12, -16, 16), z=3)


# ---------------------------------------------------------------- deaths + decals
def gen_deaths():
    S = 64
    c = S / 2
    # plague: purple flesh bursts + green spore spray, then goo drips
    rnd = random.Random(31)
    globs = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.5, 1.0), rnd.uniform(1.5, 3.2)) for _ in range(12)]
    fr = []
    for f in range(5):
        a = canvas(S, S)
        if f == 0:
            disc(a, c, c, 9, FLESH[2]); disc(a, c - 1, c - 2, 6, FLESH[3]); disc(a, c, c, 3, PLAGUE[4])
        else:
            if f < 3:
                ring(a, c, c + 2, 6 + f * 7, PLAGUE[3], 255 if f == 1 else 191, 1.0, 0.7, broken=6, seed=f)
            for i, (t, s, r) in enumerate(globs):
                d = (5 + f * 6) * s
                x, y = c + math.cos(t) * d, c + math.sin(t) * d * 0.8 + f * f * 0.6
                rr = max(0.8, r - f * 0.4)
                col = (PLAGUE[3], FLESH[2], FLESH[3])[i % 3]
                disc(a, x, y, rr, col, [255, 255, 191, 128][f - 1])
                if rr > 1.5:
                    put(a, x - 0.5, y - 0.5, PLAGUE[4] if col == PLAGUE[3] else BONE if f == 1 else col, [255, 255, 191, 128][f - 1])
            if f >= 2:
                puff(a, c, c - f * 2, 4 + f * 2, [255, 191, 128, 64][f - 1], (PLAGUE[1], PLAGUE[2], PLAGUE[3]))
        fr.append(a)
    emit("die_plague", fr, 14)

    # machine: flash, sparks, scrap bits flying, then smoke column
    rnd = random.Random(37)
    sp = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.6, 1.2)) for _ in range(12)]
    bits = [(rnd.uniform(math.pi * 1.1, math.pi * 1.9), rnd.uniform(0.5, 1.0), rnd.choice([(2, 2), (3, 2), (2, 1)]), rnd.random()) for _ in range(9)]
    fr = []
    for f in range(6):
        a = canvas(S, S)
        if f >= 2:
            for k, (dx, dy) in enumerate(((0, -9), (4, -3), (-5, 0))):
                puff(a, c + dx, c + dy - (f - 2) * 4, 4.5 + (f - 2) * 1.4, [255, 255, 191, 128][f - 2], (ASH[1], ASH[2], ASH[3]))
        if f == 0:
            disc(a, c, c, 7, DUST[3]); disc(a, c, c, 4, BONE)
        if f <= 3:
            for (t, s) in sp:
                d = (6 + f * 6) * s
                streak(a, c + math.cos(t) * d, c + math.sin(t) * d + f * f * 0.5, t, 3 if f < 2 else 2, DUST[4], DUST[2])
        if 1 <= f <= 4:
            for (t, s, (w, hh), q) in bits:
                d = (6 + f * 5) * s
                x = c + math.cos(t) * d * 1.2
                y = c + math.sin(t) * d + f * f * 1.1
                chunk(a, x, y, w, hh, STEEL[3], ASH[1])
        if f == 1:
            disc(a, c, c, 4, DUST[3])
        fr.append(a)
    emit("die_machine", fr, 14)

    # raider: dust slump + blood + a cloth scrap
    S2 = 48
    c2 = S2 / 2
    rnd = random.Random(41)
    drops = [(rnd.uniform(-math.pi, 0), rnd.uniform(0.5, 1.0)) for _ in range(8)]
    fr = []
    for f in range(4):
        a = canvas(S2, S2)
        if f == 0:
            disc(a, c2, c2 - 4, 4, BLOOD); put(a, c2 - 1, c2 - 6, BONE)
        for k, dx in enumerate((-9, 0, 9)):
            puff(a, c2 + dx * (0.6 + f * 0.2), c2 + 9 - f * 1.5 - (k % 2) * 2, 3.5 + f * 1.8, [255, 255, 191, 128][f], (EARTH[1], EARTH[2], EARTH[3]))
        if f < 3:
            for (t, s) in drops:
                d = (4 + f * 4) * s
                put(a, c2 + math.cos(t) * d, c2 - 4 + math.sin(t) * d + f * f, BLOOD, 255 if f < 2 else 191)
            chunk(a, c2 + 6 + f * 2, c2 - 10 - f * 2 + f * f, 3, 2, BLOOD, RUST[0])
        fr.append(a)
    emit("die_raider", fr, 14)


def decal_blob(W, H, seed, tones, specks=None, n=7, spread=0.38):
    rnd = random.Random(seed)
    a = canvas(W, H)
    cx, cy = W / 2, H / 2
    blobs = [(cx + rnd.uniform(-1, 1) * W * spread, cy + rnd.uniform(-1, 1) * H * spread, rnd.uniform(0.18, 0.32) * W) for _ in range(n)]
    xx, yy = grid(a)
    m = np.zeros((H, W), bool)
    for (x, y, r) in blobs:
        m |= ((xx - x) / r) ** 2 + ((yy - y) / (r * 0.5)) ** 2 <= 1
    a[m, :3] = tones[0]
    a[m, 3] = 255
    inner = np.zeros((H, W), bool)
    for (x, y, r) in blobs:
        inner |= ((xx - x + 1) / (r * 0.6)) ** 2 + ((yy - y + 0.5) / (r * 0.3)) ** 2 <= 1
    a[inner & m, :3] = tones[1]
    if specks:
        for i in range(max(3, W // 6)):
            x, y = rnd.uniform(0.2, 0.8) * W, rnd.uniform(0.25, 0.75) * H
            if m[int(y), int(x)]:
                put(a, x, y, specks[i % len(specks)])
    # drips / outlying droplets
    for i in range(5):
        t = rnd.uniform(0, 2 * math.pi)
        put(a, cx + math.cos(t) * W * 0.47, cy + math.sin(t) * H * 0.45, tones[0])
    return a


def gen_decals():
    emit("dc_splat_plague", [decal_blob(36, 18, 1, (FLESH[0], FLESH[1]), [PLAGUE[3], PLAGUE[2]])], 1, z=-4)
    emit("dc_splat_blood", [decal_blob(30, 14, 2, (RUST[0], BLOOD), [BLOOD])], 1, z=-4)
    # scrap pile: dark oil patch + steel/brass bits
    a = decal_blob(30, 14, 3, (STEEL[0], STEEL[1]), None, n=4)
    rnd = random.Random(4)
    for i in range(7):
        x, y = rnd.uniform(5, 24), rnd.uniform(3, 10)
        chunk(a, x, y, rnd.choice([2, 3]), 2, [STEEL[2], BRASS[2], RUST[2]][i % 3], STEEL[0])
    emit("dc_scrap", [a], 1, z=-4)
    # scorch: 2-tone ash, a few dying embers
    for name, W in (("dc_scorch", 40), ("dc_scorch_big", 72)):
        a = canvas(W, W // 2)
        xx, yy = grid(a)
        cx, cy = W / 2, W / 4
        rnd = random.Random(W)
        th = np.arctan2((yy - cy) * 2, xx - cx)
        wob = 1 + 0.14 * np.sin(5 * th + 0.7) + 0.08 * np.sin(9 * th + 2.1)
        d = np.sqrt(((xx - cx) / (W * 0.48)) ** 2 + ((yy - cy) / (W * 0.24)) ** 2) / wob
        outer = d < 0.8
        a[outer, :3] = ASH[1]; a[outer, 3] = 255
        inner = d < 0.5
        a[inner, :3] = ASH[0]
        # radial streaks out of the blast
        for k in range(10):
            t = k * math.pi / 5 + rnd.uniform(-0.2, 0.2)
            r0, r1 = 0.4, rnd.uniform(0.85, 1.0)
            line(a, cx + math.cos(t) * W * 0.48 * r0, cy + math.sin(t) * W * 0.24 * r0,
                 cx + math.cos(t) * W * 0.48 * r1, cy + math.sin(t) * W * 0.24 * r1, ASH[1])
        for k in range(3):
            put(a, cx + rnd.uniform(-W * 0.15, W * 0.15), cy + rnd.uniform(-W * 0.06, W * 0.06), DUST[1])
        emit(name, [a], 1, z=-4)
    # slam crack: earth cracks radiating
    W, H = 96, 40
    a = canvas(W, H)
    cx, cy = W / 2, H / 2
    rnd = random.Random(9)
    disc(a, cx, cy, 9, EARTH[0], 255, 0.42)
    for k in range(8):
        t = k * math.pi / 4 + rnd.uniform(-0.25, 0.25)
        x, y = cx, cy
        for s in range(6):
            nx = x + math.cos(t) * rnd.uniform(4, 7)
            ny = y + math.sin(t) * rnd.uniform(1.6, 3)
            line(a, x, y, nx, ny, EARTH[0])
            line(a, x + 1, y + 1, nx + 1, ny + 1, EARTH[3] if s < 4 else EARTH[2])  # lit lower-right lip
            x, y = nx, ny
            t += rnd.uniform(-0.4, 0.4)
    emit("dc_crack", [a], 1, z=-4)
    # plague puddle (vial cloud floor) — used under Vesper's cloud
    emit("dc_plague_pool", [decal_blob(48, 22, 6, (PLAGUE[0], PLAGUE[1]), [PLAGUE[2], PLAGUE[3]], n=8, spread=0.3)], 1, z=-4)


# ---------------------------------------------------------------- abilities, status, pickups, misc
def gen_ability():
    # heal: teal crosses rising + bone ring (Cinder, tonics, Second Wind)
    W, H = 48, 64
    rnd = random.Random(51)
    crosses = [(rnd.uniform(8, 40), rnd.uniform(36, 56), rnd.uniform(0.7, 1.2)) for _ in range(6)]
    fr = []
    for f in range(6):
        a = canvas(W, H)
        if f < 3:
            ring(a, W / 2, 52, 8 + f * 7, BONE if f == 0 else TEAL[1], 255 if f < 2 else 191, 1.0, 0.4)
        for i, (x, y, s) in enumerate(crosses):
            yy_ = y - f * 6 * s
            al = 255 if f < 4 else (191 if f == 4 else 128)
            big = i % 2 == 0
            col = TEAL[1] if (i + f) % 3 else BONE
            put(a, x, yy_, col, al)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(a, x + dx, yy_ + dy, col, al)
            if big:
                for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
                    put(a, x + dx, yy_ + dy, TEAL[0] if col == BONE else TEAL[1], al)
        fr.append(a)
    emit("fx_heal", fr, 14, oy=52)
    # small heal (tonic pickup): 24, 4 frames
    fr = []
    for f in range(4):
        a = canvas(24, 24)
        ring(a, 12, 16, 3 + f * 2.5, TEAL[1] if f else BONE, [255, 255, 191, 128][f], 1.0, 0.5)
        y = 12 - f * 2
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            put(a, 12 + dx, y + dy, BONE if f < 2 else TEAL[1], [255, 255, 191, 128][f])
        fr.append(a)
    emit("fx_heal_small", fr, 14, oy=16)
    # level-up: dust-amber pillar + rings + sparks (64)
    S = 64
    rnd = random.Random(61)
    sp = [(rnd.uniform(14, 50), rnd.uniform(0.6, 1.2)) for _ in range(10)]
    fr = []
    for f in range(6):
        a = canvas(S, 80)
        base_y = 64
        if f < 4:
            ring(a, 32, base_y, 6 + f * 8, DUST[4] if f == 0 else DUST[3], 255 if f < 3 else 191, 2.0 if f < 2 else 1.0, 0.38)
        # pillar: columns in alpha steps
        if f < 5:
            hgt = [20, 44, 60, 60, 40][f]
            for x in range(26, 39):
                dx = abs(x - 32)
                col = BONE if dx < 2 else (DUST[4] if dx < 4 else DUST[3])
                al = 255 if dx < 2 else (191 if dx < 4 else 64)
                if f >= 3:
                    al = min(al, 128 if f == 3 else 64)
                for y in range(base_y - hgt, base_y):
                    put(a, x, y, col, al)
        for (x, s) in sp:
            y = base_y - 6 - f * 9 * s
            put(a, x, y, DUST[4] if f < 4 else DUST[2])
            put(a, x, y + 1, DUST[2])
        fr.append(a)
    emit("fx_levelup", fr, 14, ox=32, oy=64)
    # shield hit: teal hex arc + bone flash (40)
    fr = []
    for f in range(4):
        a = canvas(40, 40)
        r = 14 + f * 2
        for k in range(6):
            t0 = k * math.pi / 3 + math.pi / 6
            t1 = t0 + math.pi / 3
            x0, y0 = 20 + math.cos(t0) * r, 20 + math.sin(t0) * r
            x1, y1 = 20 + math.cos(t1) * r, 20 + math.sin(t1) * r
            line(a, x0, y0, x1, y1, BONE if f == 0 else TEAL[1], [255, 255, 191, 64][f])
        if f < 2:
            for k in range(6):
                t = k * math.pi / 3 + math.pi / 6
                put(a, 20 + math.cos(t) * r, 20 + math.sin(t) * r, BONE)
        if f == 0:
            disc(a, 20, 20, 4, TEAL[1], 128)
        fr.append(a)
    emit("fx_shield_hit", fr, 20)
    # mark reticle (Quill Dissect): DUST corners closing in
    fr = []
    for f in range(4):
        a = canvas(28, 28)
        g = [12, 9, 7, 7][f]
        col = BONE if f == 2 else DUST[3]
        for sx in (-1, 1):
            for sy in (-1, 1):
                x, y = 14 + sx * g, 14 + sy * g
                for k in range(4):
                    put(a, x - sx * k, y, col)
                    put(a, x, y - sy * k, col)
        if f >= 2:
            put(a, 14, 14, SIGNAL); put(a, 13, 14, SIGNAL); put(a, 14, 13, SIGNAL); put(a, 13, 13, SIGNAL)
        fr.append(a)
    emit("fx_mark", fr, 16)
    # drone call / teleport (Helm): teal rings + bone sparks
    fr = []
    for f in range(5):
        a = canvas(32, 32)
        if f < 4:
            ring(a, 16, 16, 3 + f * 3.5, BONE if f == 0 else TEAL[1], 255 if f < 3 else 128, 1.0)
        if f >= 1:
            ring(a, 16, 16, max(1, 10 - f * 2), TEAL[0], 191, 1.0)
        for k in range(4):
            t = k * math.pi / 2 + f * 0.4
            put(a, 16 + math.cos(t) * (5 + f * 2), 16 + math.sin(t) * (5 + f * 2), BONE if f < 3 else TEAL[1])
        fr.append(a)
    emit("fx_drone_call", fr, 16)
    # rush trail puff (Rook rattle rush / dashes): dust kicked up, 4 frames 24
    fr = []
    for f in range(4):
        a = canvas(24, 20)
        puff(a, 12, 13 - f, 3 + f * 1.6, [255, 191, 128, 64][f], (EARTH[1], EARTH[2], EARTH[3]))
        if f < 2:
            chunk(a, 5 - f, 10 - f * 2, 2, 1, EARTH[3], EARTH[1])
            chunk(a, 18 + f, 9 - f * 2, 1, 1, EARTH[3], EARTH[1])
        fr.append(a)
    emit("fx_kickup", fr, 16, oy=16, z=-1)


def gen_status():
    # burn: flame flicker loop
    fr = []
    shapes = [[3, 6, 4, 5, 2], [4, 5, 6, 3, 3], [2, 6, 5, 6, 2], [3, 4, 6, 5, 3]]
    for f in range(4):
        a = canvas(12, 12)
        for k, hgt in enumerate(shapes[f]):
            x = 3 + k * 1.5
            for y in range(hgt):
                col = DUST[1] if y == 0 else (DUST[2] if y < hgt * 0.55 else (DUST[3] if y < hgt - 1 else DUST[4]))
                put(a, x, 11 - y, col)
        fr.append(a)
    emit("st_burn", fr, 12, oy=11, loop=True)
    # poison: rising bubbles loop
    fr = []
    for f in range(4):
        a = canvas(12, 14)
        for k, (x, ph) in enumerate(((3, 0), (7, 2), (5, 1))):
            y = 12 - ((f + ph) % 4) * 3
            r = 1.2 if k != 1 else 1.6
            disc(a, x + 0.5, y + 0.5, r, PLAGUE[3])
            put(a, x, y, PLAGUE[4])
            if (f + ph) % 4 == 3:
                fade(a, 191)
        fr.append(a)
    emit("st_poison", fr, 8, oy=13, loop=True)
    # stun: stars orbiting (squashed ellipse)
    fr = []
    for f in range(4):
        a = canvas(22, 9)
        for k in range(3):
            t = (k / 3.0 + f / 12.0) * 2 * math.pi
            x, y = 11 + math.cos(t) * 8, 4.5 + math.sin(t) * 2.5
            col = DUST[3] if k else BONE
            put(a, x, y, col)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(a, x + dx, y + dy, DUST[2] if k else DUST[3])
        fr.append(a)
    emit("st_stun", fr, 12, loop=True)
    # slow / frost: crystals twinkling
    fr = []
    pts = [(3, 4), (8, 2), (6, 8), (10, 7)]
    for f in range(4):
        a = canvas(13, 11)
        for i, (x, y) in enumerate(pts):
            lit = (i + f) % 4 == 0
            put(a, x, y, BONE if lit else TEAL[1])
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(a, x + dx, y + dy, STEEL[3] if lit else STEEL[2])
        fr.append(a)
    emit("st_slow", fr, 8, loop=True)


def gen_pickups():
    rar = {"common": (ASH[3], BONE), "rare": (TEAL[1], BONE), "epic": (FLESH[3], BONE), "legendary": (DUST[3], DUST[4])}
    for name, (c1, c2) in rar.items():
        fr = []
        for f in range(4):
            a = canvas(12, 12)
            L = [2, 4, 5, 3][f]
            put(a, 6, 6, c2)
            for k in range(1, L + 1):
                col = c2 if k == 1 else c1
                al = 255 if k < L else 191
                put(a, 6 + k, 6, col, al); put(a, 6 - k, 6, col, al)
                if k < L:
                    put(a, 6, 6 + k, col, al); put(a, 6, 6 - k, col, al)
            if f == 2:
                for d in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                    put(a, 6 + d[0], 6 + d[1], c1, 191)
            fr.append(a)
        emit("sp_" + name, fr, 8, loop=True, z=6)


def gen_beam():
    """Extract sky-beam: teal column in 4 alpha bands, bone core, rising motes (loop)."""
    W, H = 56, 220
    rnd = random.Random(71)
    motes = [(rnd.uniform(-20, 20), rnd.uniform(0, H)) for _ in range(14)]
    fr = []
    for f in range(4):
        a = canvas(W, H)
        cx = W / 2
        for y in range(H):
            t = y / H  # 0 top .. 1 bottom
            hw = 10 + 12 * t
            for x in range(W):
                dx = abs(x + 0.5 - cx)
                if dx > hw:
                    continue
                band = dx / hw
                if band < 0.18:
                    col, al = BONE, 191
                elif band < 0.45:
                    col, al = TEAL[1], 128
                else:
                    col, al = TEAL[1], 64
                # vertical fade toward the sky in 4 steps
                if t < 0.25:
                    al = min(al, 64)
                elif t < 0.5:
                    al = min(al, 128)
                if al:
                    put(a, x, y, col, al)
        for (mx, my) in motes:
            y = (my - f * 14) % H
            put(a, cx + mx * (0.5 + y / H * 0.5), y, BONE, 255)
            put(a, cx + mx * (0.5 + y / H * 0.5), y + 1, TEAL[1], 191)
        fr.append(a)
    emit("fx_beam", fr, 8, ox=W / 2, oy=H, loop=True, add=True, z=24)


def contact_sheet(path):
    order = list(STRIPS.keys())
    rows = []
    for fid in order:
        frames = STRIPS[fid]
        rows.append((fid, np.concatenate(frames, 1)))
    from PIL import ImageDraw
    pad = 4
    bg = (0x5b, 0x4a, 0x3b, 255)
    for scale in (1, 2):
        Wmax = 0
        Htot = 0
        for fid, s in rows:
            Wmax = max(Wmax, s.shape[1] * scale + 170)
            Htot += s.shape[0] * scale + pad
        Wmax = min(Wmax, 4000)
        im = Image.new("RGBA", (Wmax, Htot + pad), bg)
        d = ImageDraw.Draw(im)
        y = pad
        for fid, s in rows:
            si = Image.fromarray(s, "RGBA")
            if scale != 1:
                si = si.resize((si.width * scale, si.height * scale), Image.NEAREST)
            im.alpha_composite(si, (166, y))
            d.text((4, y + 2), fid, fill=(233, 223, 201, 255))
            y += si.height + pad
        im.save(path.replace(".png", "_%dx.png" % scale))


if __name__ == "__main__":
    gen_muzzles()
    gen_projectiles()
    gen_impacts()
    gen_explosions()
    gen_shock_burst()
    gen_slam()
    gen_smears()
    gen_deaths()
    gen_decals()
    gen_ability()
    gen_status()
    gen_pickups()
    gen_beam()
    with open(os.path.join(OUT, "fx_px.json"), "w") as fh:
        json.dump(MANIFEST, fh, indent=0, sort_keys=True)
    bad = validate()
    for b in bad:
        print("WARN", b)
    print("fx:", len(MANIFEST), "strips;", "warnings:", len(bad))
    if len(sys.argv) > 1:
        os.makedirs(sys.argv[1], exist_ok=True)
        contact_sheet(os.path.join(sys.argv[1], "vfx_sheet.png"))
