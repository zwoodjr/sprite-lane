"""Small offline DSP kit for Wanderer's audio build (numpy/scipy only).

Everything works on float32 mono arrays at SR, or (2, N) stereo arrays.
Used by build_audio.py; never shipped with the game.
"""
import os
import subprocess
import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(1977)
_cache = {}
SRC = os.environ.get("WANDERER_AUDIO_SRC", "")


def seed(n):
    global RNG
    RNG = np.random.default_rng(n)


# --------------------------------------------------------------------------- io
def load(rel, start=0.0, dur=None):
    """Decode a source file (relative to SRC) to mono float32 at SR."""
    key = rel
    if key not in _cache:
        path = rel if os.path.isabs(rel) else os.path.join(SRC, rel)
        if not os.path.exists(path):
            top = os.path.join(SRC, rel.split("/")[0])
            base = os.path.basename(rel)
            hits = [os.path.join(dp, f) for dp, _, fs in os.walk(top) for f in fs if f == base and "__MACOSX" not in dp]
            if not hits:
                raise FileNotFoundError(path)
            path = hits[0]
        r =subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                           capture_output=True, check=True)
        x = np.frombuffer(r.stdout, np.float32).astype(np.float32)
        if len(x) == 0:
            raise RuntimeError("empty decode: " + path)
        x = x - np.mean(x)
        _cache[key] = x
    x = _cache[key]
    a = int(start * SR)
    b = len(x) if dur is None else min(len(x), a + int(dur * SR))
    return x[a:b].copy()


def write_ogg(path, x, q=4, stereo=None):
    x = np.asarray(x, np.float32)
    ch = 2 if x.ndim == 2 else 1
    data = (x.T if ch == 2 else x).astype(np.float32).tobytes()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=data, check=True)


def write_wav(path, x):
    from scipy.io import wavfile
    x = np.asarray(x, np.float32)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, SR, (np.clip(x.T if x.ndim == 2 else x, -1, 1) * 32767).astype(np.int16))


# ------------------------------------------------------------------- basics
def sec(n):
    return int(n * SR)


def silence(d):
    return np.zeros(sec(d), np.float32)


def t_axis(d):
    return np.arange(sec(d)) / SR


def pad_to(x, n):
    if x.shape[-1] >= n:
        return x[..., :n]
    w = [(0, 0)] * (x.ndim - 1) + [(0, n - x.shape[-1])]
    return np.pad(x, w)


def mix(*layers, length=None):
    """layers: (array, offset_seconds, gain_db) tuples or bare arrays."""
    items = []
    for L in layers:
        if isinstance(L, tuple):
            arr, off, g = (L + (0.0, 0.0))[:3] if len(L) < 3 else L
        else:
            arr, off, g = L, 0.0, 0.0
        items.append((np.asarray(arr, np.float32), sec(off), db(g)))
    stereo = any(a.ndim == 2 for a, _, _ in items)
    n = length if length else max(o + a.shape[-1] for a, o, _ in items)
    out = np.zeros((2, n) if stereo else n, np.float32)
    for a, o, g in items:
        if stereo and a.ndim == 1:
            a = np.vstack([a, a])
        m = min(a.shape[-1], n - o)
        if m <= 0:
            continue
        out[..., o:o + m] += a[..., :m] * g
    return out


def db(g):
    return float(10 ** (g / 20.0))


def gain(x, g):
    return x * db(g)


def peak_norm(x, target=-1.0):
    p = np.max(np.abs(x)) + 1e-9
    return x * (db(target) / p)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(np.square(x))) + 1e-9)


def active_rms_norm(x, target=-18.0, peak_cap=-1.0):
    """Loudness-ish normalisation on the loud part of the sound, then a peak cap."""
    a = np.abs(x if x.ndim == 1 else x.mean(0))
    thr = a.max() * 0.1
    act = (x if x.ndim == 1 else x.mean(0))[a > thr]
    r = 20 * np.log10(np.sqrt(np.mean(act ** 2)) + 1e-9) if len(act) else -60
    y = x * db(target - r)
    return limit(y, peak_cap)


# ------------------------------------------------------------------- envelopes
def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    n = x.shape[-1]
    a, b = min(sec(fin), n), min(sec(fout), n)
    if a > 0:
        x[..., :a] *= np.linspace(0, 1, a) ** 2
    if b > 0:
        x[..., n - b:] *= np.linspace(1, 0, b) ** 2
    return x


def env_exp(n_or_d, decay, attack=0.001):
    n = n_or_d if isinstance(n_or_d, int) else sec(n_or_d)
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay, 1e-4))
    na = max(1, sec(attack))
    e[:na] *= np.linspace(0, 1, na)
    return e.astype(np.float32)


def env_ar(n, attack, release, curve=2.0):
    t = np.arange(n) / SR
    up = np.clip(t / max(attack, 1e-4), 0, 1) ** curve
    down = np.clip((n / SR - t) / max(release, 1e-4), 0, 1) ** curve
    return (up * down).astype(np.float32)


def trim(x, thr_db=-50, tail=0.05, start_db=-30):
    a = np.abs(x if x.ndim == 1 else x.mean(0))
    thr = a.max() * db(thr_db)
    idx = np.where(a > thr)[0]
    st = np.where(a > a.max() * db(start_db))[0]
    if len(idx) == 0:
        return x
    s, e = max(0, st[0] - sec(0.003)), min(x.shape[-1], idx[-1] + sec(tail))
    return x[..., s:e]


def crop(x, start, dur=None):
    a = sec(start)
    b = x.shape[-1] if dur is None else a + sec(dur)
    return x[..., a:b]


# ------------------------------------------------------------------- filters
def _sos(kind, f, order=2):
    nyq = SR / 2
    if isinstance(f, (list, tuple)):
        w = [min(max(v / nyq, 1e-4), 0.999) for v in f]
    else:
        w = min(max(f / nyq, 1e-4), 0.999)
    return signal.butter(order, w, btype=kind, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("lowpass", f, order), x, axis=-1).astype(np.float32)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("highpass", f, order), x, axis=-1).astype(np.float32)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", [lo, hi], order), x, axis=-1).astype(np.float32)


def _biquad(kind, f0, g_db, q=0.707):
    A = 10 ** (g_db / 40)
    w0 = 2 * np.pi * f0 / SR
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    if kind == "peak":
        b = [1 + al * A, -2 * c, 1 - al * A]
        a = [1 + al / A, -2 * c, 1 - al / A]
    elif kind == "lowshelf":
        sq = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) - (A - 1) * c + sq), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sq)]
        a = [(A + 1) + (A - 1) * c + sq, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sq]
    else:  # highshelf
        sq = 2 * np.sqrt(A) * al
        b = [A * ((A + 1) + (A - 1) * c + sq), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sq)]
        a = [(A + 1) - (A - 1) * c + sq, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sq]
    return np.array(b) / a[0], np.array(a) / a[0]


def eq(x, f, g, q=0.9, kind="peak"):
    b, a = _biquad(kind, f, g, q)
    return signal.lfilter(b, a, x, axis=-1).astype(np.float32)


def lowshelf(x, f, g):
    return eq(x, f, g, 0.707, "lowshelf")


def highshelf(x, f, g):
    return eq(x, f, g, 0.707, "highshelf")


def sweep_bp(x, f0, f1, q=2.0, curve=1.0):
    """Time-varying band-pass (state-variable filter) from f0 to f1."""
    n = x.shape[-1]
    fc = f0 * (f1 / f0) ** (np.linspace(0, 1, n) ** curve)
    return svf(x, fc, q, "bp")


def svf(x, fc, q=1.0, mode="lp"):
    """Chamberlin state variable filter with per-sample cutoff (mono)."""
    x = np.asarray(x, np.float64)
    fc = np.broadcast_to(np.asarray(fc, np.float64), x.shape)
    f = 2 * np.sin(np.pi * np.clip(fc, 10, SR / 6) / SR)
    damp = 1.0 / q
    out = np.zeros_like(x)
    low = band = 0.0
    sel = {"lp": 0, "bp": 1, "hp": 2}[mode]
    for i in range(len(x)):
        low += f[i] * band
        high = x[i] - low - damp * band
        band += f[i] * high
        out[i] = (low, band, high)[sel]
    return out.astype(np.float32)


# ------------------------------------------------------------------- dynamics / colour
def sat(x, drive=2.0):
    return (np.tanh(x * drive) / np.tanh(drive)).astype(np.float32)


def limit(x, ceiling=-1.0):
    c = db(ceiling)
    # soft knee: tanh above 70% of the ceiling
    y = x / c
    k = 0.7
    over = np.abs(y) > k
    y = np.where(over, np.sign(y) * (k + (1 - k) * np.tanh((np.abs(y) - k) / (1 - k))), y)
    return (y * c).astype(np.float32)


def compress(x, thr=-18.0, ratio=3.0, attack=0.005, release=0.12, makeup=0.0):
    mono = x if x.ndim == 1 else np.max(np.abs(x), axis=0)
    a = np.abs(mono).astype(np.float64)
    ga = np.exp(-1 / (SR * attack))
    gr = np.exp(-1 / (SR * release))
    env = signal.lfilter([1 - gr], [1, -gr], a)  # quick release follower
    env = np.maximum(env, signal.lfilter([1 - ga], [1, -ga], a))
    lvl = 20 * np.log10(env + 1e-9)
    over = np.maximum(lvl - thr, 0)
    g = db(makeup) * 10 ** (-(over - over / ratio) / 20)
    return (x * g).astype(np.float32)


def bitcrush_free_grit(x, amt=0.3):
    """Analog-ish grit: asymmetric saturation + a little band-limited noise."""
    y = np.tanh(x * (1 + 3 * amt) + 0.08 * amt) - np.tanh(0.08 * amt)
    return (y / (np.max(np.abs(y)) + 1e-9) * np.max(np.abs(x))).astype(np.float32)


# ------------------------------------------------------------------- pitch / time
def repitch(x, semis):
    """Varispeed (pitch + length) by resampling."""
    if abs(semis) < 1e-3:
        return x.copy()
    from fractions import Fraction
    r = Fraction(2 ** (semis / 12.0)).limit_denominator(240)
    return signal.resample_poly(x, r.denominator, r.numerator, axis=-1).astype(np.float32)


def _resample(x, n):
    xi = np.linspace(0, x.shape[-1] - 1, n)
    if x.ndim == 1:
        return np.interp(xi, np.arange(x.shape[-1]), x).astype(np.float32)
    return np.vstack([np.interp(xi, np.arange(x.shape[-1]), c) for c in x]).astype(np.float32)


def stretch_sustain(x, dur, grain=0.25, start=0.3, end=0.8):
    """Extend a sustained tone by overlap-adding grains from its steady middle."""
    n_out = sec(dur)
    g = sec(grain)
    hop = g // 2
    a, b = int(len(x) * start), int(len(x) * end) - g
    w = np.hanning(g).astype(np.float32)
    out = np.zeros(n_out + g, np.float32)
    pos = 0
    while pos < n_out:
        s = RNG.integers(a, max(a + 1, b))
        out[pos:pos + g] += x[s:s + g] * w
        pos += hop
    return out[:n_out]


# ------------------------------------------------------------------- generators
def noise(d, color="white"):
    n = sec(d)
    w = RNG.standard_normal(n).astype(np.float32)
    if color == "white":
        return w * 0.3
    if color == "pink":
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        return (signal.lfilter(b, a, w) * 1.2).astype(np.float32)
    if color == "brown":
        y = np.cumsum(w) * 0.02
        y = signal.lfilter([1, -1], [1, -0.995], y)
        return (y / (np.std(y) + 1e-9) * 0.25).astype(np.float32)
    raise ValueError(color)


def sine(f, d, phase=0.0):
    t = t_axis(d)
    if np.ndim(f) == 0:
        return np.sin(2 * np.pi * f * t + phase).astype(np.float32)
    ph = np.cumsum(np.asarray(f) / SR) * 2 * np.pi
    return np.sin(ph + phase).astype(np.float32)


def glide(f0, f1, d, curve=2.0):
    n = sec(d)
    k = np.linspace(0, 1, n) ** (1 / curve)
    return (f1 + (f0 - f1) * (1 - k)).astype(np.float64)


def saw(f, d):
    n = sec(d)
    fr = np.broadcast_to(np.asarray(f, np.float64), (n,))
    ph = np.cumsum(fr / SR) % 1.0
    # PolyBLEP-free but softened by a gentle low-pass afterwards
    return (2 * ph - 1).astype(np.float32)


def thump(f0=120, f1=42, d=0.35, decay=0.12, click=0.4):
    """Body thump: pitch-dropping sine + click transient."""
    f = glide(f0, f1, d, 3.0)
    s = sine(f, d) * env_exp(sec(d), decay)
    c = hp(noise(0.012), 1500) * env_exp(sec(0.012), 0.002) * click * 3
    return mix(s, c)


def crack(d=0.06, bright=3500):
    """Supersonic crack / muzzle blast transient."""
    x = noise(d) * env_exp(sec(d), d / 6, attack=0.0002)
    return hp(x, bright, 2) * 3.0


def whoosh(d=0.35, f0=400, f1=2500, q=1.5, peak=0.55, color="pink"):
    n = sec(d)
    x = noise(d, color)
    x = sweep_bp(x, f0, f1, q)
    t = np.linspace(0, 1, n)
    e = np.where(t < peak, (t / peak) ** 2, ((1 - t) / (1 - peak)) ** 1.5)
    return (x * e * 2.5).astype(np.float32)


def crackle(d=0.4, density=180, lo=1500, hi=9000, decay=None):
    """Electrical arcing: sparse impulses through resonant bands + mains buzz."""
    n = sec(d)
    imp = np.zeros(n, np.float32)
    k = int(density * d)
    pos = RNG.integers(0, n, k)
    imp[pos] = RNG.uniform(-1, 1, k) * RNG.uniform(0.3, 1.0, k)
    x = bp(imp, lo, hi) * 4
    buzz = saw(100 + 20 * RNG.random(), d) * 0.15
    buzz = bp(buzz, 200, 3000)
    gate = (lp(np.abs(imp) * 50, 30) > 0.05).astype(np.float32)
    y = x + buzz * lp(gate, 40)
    if decay:
        y = y * env_exp(n, decay)
    return y.astype(np.float32)


def servo(d=0.35, f0=900, f1=1500, grit=0.3):
    """Small motor / servo whine with gear grain."""
    f = glide(f0, f1, d, 1.5)
    tone = sum(sine(f * h, d) / h ** 1.3 for h in range(1, 7))
    grain = bp(noise(d), 2000, 7000) * (0.5 + 0.5 * np.sign(sine(f / 6, d))) * grit
    e = env_ar(sec(d), 0.03, 0.08, 1.0)
    return ((tone * 0.35 + grain) * e).astype(np.float32)


def heartbeat(bpm=72, d=None):
    beat = 60.0 / bpm
    d = d or beat
    out = silence(d)
    for off, g in ((0.0, 0.0), (0.18, -4.0)):
        th = lp(thump(70, 38, 0.22, 0.06, 0.05), 180)
        out = mix((out, 0, 0), (th, off, g), length=sec(d))
    return out


# ------------------------------------------------------------------- space
def make_ir(t60=1.2, pre=0.01, damp=4000, er=6, width=1.0, size=1.0):
    n = sec(t60 * 1.1 + pre)
    out = np.zeros((2, n), np.float32)
    t = np.arange(n) / SR
    for ch in range(2):
        nz = RNG.standard_normal(n).astype(np.float32)
        hi = hp(nz, damp) * np.exp(-t * 6.9 / (t60 * 0.35))
        lo = lp(nz, damp) * np.exp(-t * 6.9 / t60)
        tail = (lo + hi * 0.5)
        tail[: sec(pre)] = 0
        out[ch] = tail * 0.08
        for i in range(er):
            p = sec(pre + RNG.uniform(0.003, 0.03 * size) * (i + 1) / er * 2)
            if p < n:
                out[ch, p] += RNG.uniform(0.2, 0.5) * (1 if RNG.random() > 0.5 else -1)
    m = out.mean(0)
    out = m + (out - m) * width
    return out / (np.sqrt(np.sum(out ** 2)) + 1e-9) * 0.9


IRS = {}


def ir(name):
    if name not in IRS:
        cfg = {
            "room": dict(t60=0.35, pre=0.003, damp=5000, er=8, size=0.4),
            "outdoor": dict(t60=0.7, pre=0.012, damp=2500, er=4, size=2.0),
            "hangar": dict(t60=2.2, pre=0.02, damp=3000, er=10, size=2.5),
            "hall": dict(t60=4.0, pre=0.03, damp=2200, er=12, size=3.0),
            "plate": dict(t60=1.6, pre=0.005, damp=6000, er=2, size=0.5),
        }[name]
        IRS[name] = make_ir(**cfg)
    return IRS[name]


def reverb(x, space="outdoor", wet=0.2, tail_keep=True):
    """Convolution reverb, returns stereo."""
    h = ir(space)
    if x.ndim == 1:
        x2 = np.vstack([x, x])
    else:
        x2 = x
    n = x2.shape[-1] + (h.shape[-1] - 1 if tail_keep else 0)
    w = np.vstack([signal.fftconvolve(x2[c], h[c])[:n] for c in range(2)])
    d = pad_to(x2, n)
    return ((d * (1 - wet * 0.5) + w * wet)).astype(np.float32)


def to_mono(x):
    return x.mean(0).astype(np.float32) if x.ndim == 2 else x


def pan(x, p):
    """p in [-1, 1], constant power, returns stereo."""
    a = (p + 1) * np.pi / 4
    return np.vstack([x * np.cos(a), x * np.sin(a)]).astype(np.float32)


def widen(x, amt=0.5, delay=0.012):
    """Mono -> stereo with a short Haas offset and decorrelated top end."""
    d = sec(delay)
    l = x
    r = np.concatenate([np.zeros(d, np.float32), x[:-d]]) if d > 0 else x
    m = (l + r) / 2
    s = (l - r) / 2
    return np.vstack([m + s * amt, m - s * amt]).astype(np.float32)


def loop_xfade(x, xf=2.0):
    """Make a seamless loop: fold the last xf seconds over the head (equal power)."""
    n = sec(xf)
    body = x[..., :-n].copy()
    tail = x[..., -n:]
    t = np.linspace(0, np.pi / 2, n)
    body[..., :n] = body[..., :n] * np.sin(t) + tail * np.cos(t)
    return body
