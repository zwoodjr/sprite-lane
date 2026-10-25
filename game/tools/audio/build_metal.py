"""Wanderer metal soundtrack: original heavy-metal music rendered from CC0 multisamples.

Usage:
    WANDERER_METAL_SRC=/path/to/sfz-clones python3 -I build_metal.py OUT_DIR [track ...]

WANDERER_METAL_SRC holds shallow clones of three CC0 1.0 sample libraries by Karoryfer Samples
(github.com/sfzinstruments):
    karoryfer.black-and-green-guitars   DI electric guitars (Gretsch + Hofner), note-by-note
    karoryfer.growlybass                Squier Jazz Bass, sustain + staccato
    karoryfer.big-rusty-drums           multi-mic rock kit
Every riff, progression and melody below is composed for this game. The guitar "amp" is a
4x-oversampled two-stage tube-style waveshaper with a scooped tone stack and a 4x12 cab
simulation; rhythm parts are double-tracked (one guitar per side, separate takes).
Run tracks share tempo, length and a bar-by-bar chord map so the game can crossfade them
while they play in lockstep. Every loop is circular: tails wrap onto the head.
"""
import os
import sys
import subprocess
from fractions import Fraction
import numpy as np
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import SR, db, eq, lowshelf, highshelf, lp, hp, reverb, pan, compress, write_ogg, write_wav  # noqa

SRC = os.environ.get("WANDERER_METAL_SRC", "")
GTR = "karoryfer.black-and-green-guitars/Samples/"
BASS = "karoryfer.growlybass/"
DRM = "karoryfer.big-rusty-drums/Samples/"
RNG = np.random.default_rng(1986)
NAMES = {"c": 0, "db": 1, "d": 2, "eb": 3, "e": 4, "f": 5, "gb": 6, "g": 7, "ab": 8, "a": 9, "bb": 10, "b": 11}

# ============================================================================ sample io
_cache = {}


def _decode(rel, ch):
    key = (rel, ch)
    if key not in _cache:
        path = os.path.join(SRC, rel)
        r = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
                           capture_output=True, check=True)
        x = np.frombuffer(r.stdout, np.float32).astype(np.float32)
        if ch == 2:
            x = x.reshape(-1, 2).T.copy()
        x = x - np.mean(x, axis=-1, keepdims=True)
        _cache[key] = x
    return _cache[key]


def _onset_trim(x, thr=0.02, pre=0.002):
    m = np.abs(x if x.ndim == 1 else x.max(0))
    i = int(np.argmax(m > thr * m.max()))
    return x[..., max(0, i - int(pre * SR)):]


def midi_of(name):
    """Library note names run an octave above MIDI convention (keycenter 40 = 'e3')."""
    i = 2 if len(name) > 2 and name[1] == "b" else 1
    return 12 * (int(name[i:]) + 1) + NAMES[name[:i]] - 12


def _index(folder, parse):
    out = {}
    for f in sorted(os.listdir(os.path.join(SRC, folder))):
        k = parse(f)
        if k is not None:
            out.setdefault(k, []).append(folder + f)
    return out


_idx = {}


def gtr_index(guitar, art):
    """guitar: green|black, art: ord|stac -> {(midi, layer): [paths]}"""
    key = (guitar, art)
    if key not in _idx:
        def parse(f):
            p = f[:-4].split("_")
            if art == "ord":
                return (midi_of(p[1]), p[2])
            return (midi_of(p[1]), "f")
        _idx[key] = _index(GTR + "%s/%s/" % (guitar, art), parse)
    return _idx[key]


def bass_index(art):
    if art not in _idx:
        def parse(f):
            p = f[:-4].split("_")
            return (midi_of(p[0]), "s" if p[1] == "staccato" else p[1])
        _idx[art] = _index(BASS + art + "/", parse)
    return _idx[art]


def pick(paths):
    return paths[int(RNG.integers(len(paths)))]


def resamp(x, ratio):
    """Play x at `ratio` x speed (pitch up when ratio > 1)."""
    if abs(ratio - 1) < 1e-4:
        return x
    r = Fraction(ratio).limit_denominator(400)
    return signal.resample_poly(x, r.denominator, r.numerator, axis=-1).astype(np.float32)


def gtr_note(guitar, midi, art="ord", layer="f"):
    idx = gtr_index(guitar, art)
    best = min({k[0] for k in idx}, key=lambda m: abs(m - midi))
    lay = layer if (best, layer) in idx else next(k[1] for k in idx if k[0] == best)
    x = _onset_trim(_decode(pick(idx[(best, lay)]), 1))
    x = x / (np.max(np.abs(x[: int(0.2 * SR)])) + 1e-9)
    return resamp(x, 2 ** ((midi - best) / 12))


def bass_note(midi, art="sustain", layer="f"):
    idx = bass_index(art)
    best = min({k[0] for k in idx}, key=lambda m: abs(m - midi))
    lay = layer if art == "sustain" else "s"
    if (best, lay) not in idx:
        lay = next(k[1] for k in idx if k[0] == best)
    x = _onset_trim(_decode(pick(idx[(best, lay)]), 1))
    x = x / (np.max(np.abs(x[: int(0.2 * SR)])) + 1e-9)
    return resamp(x, 2 ** ((midi - best) / 12))


DRUMS = {
    # piece: (folder, {mic: gain dB}, number of velocity layers)
    "kick": ("kick_24/kick/", {"kick": 0, "oh": -8}, 10),
    "snare": ("snare_14/center/", {"top": 0, "btm": -9, "oh": -6}, 10),
    "rim": ("snare_14/rimshot/", {"top": 0, "btm": -10, "oh": -6}, 6),
    "hat": ("hihat_14/tc/", {"cl": 0, "oh": -6}, 8),
    "hato": ("hihat_14/qo/", {"cl": 0, "oh": -5}, 4),
    "crash": ("crash_17/cr/", {"cl": -2, "oh": 0}, 5),
    "china": ("china_18/cn/", {"cl": -1, "oh": 0}, 5),
    "ride": ("ride_22/rd/", {"cl": 0, "oh": -4}, 10),
    "bell": ("ride_22/bl/", {"cl": 0, "oh": -4}, 4),
    "t1": ("tom_14/center/", {"cl": 0, "oh": -6}, 6),
    "t2": ("tom_18/center/", {"cl": 0, "oh": -6}, 8),
    "t3": ("tom_22/center/", {"cl": 0, "oh": -6}, 7),
}
_kit = {}


def drum_hit(piece, vel):
    """Stereo multi-mic hit at velocity 0..1 (random round robin)."""
    folder, mics, nvl = DRUMS[piece]
    if piece not in _kit:
        files = {}
        first = sorted(mics)[0]
        for f in os.listdir(os.path.join(SRC, DRM + folder + first)):
            p = f[:-5].split("_")
            vl = int([s for s in p if s.startswith("vl")][0][2:])
            files.setdefault(vl, []).append(f)
        _kit[piece] = files
    files = _kit[piece]
    layers = sorted(files)
    vl = layers[min(len(layers) - 1, int(round(vel * (len(layers) - 1))))]
    f = pick(files[vl])
    out = None
    for mic, g in mics.items():
        rel = DRM + folder + mic + "/" + f
        if not os.path.exists(os.path.join(SRC, rel)):
            continue
        x = _decode(rel, 2) * db(g)
        out = x if out is None else _sum(out, x)
    return out


def _sum(a, b):
    n = max(a.shape[-1], b.shape[-1])
    o = np.zeros(a.shape[:-1] + (n,), np.float32)
    o[..., :a.shape[-1]] += a
    o[..., :b.shape[-1]] += b
    return o


# ============================================================================ circular buffers
class Loop:
    def __init__(self, n, ch=1, wrap=True):
        self.n = n
        self.wrap = wrap
        self.buf = np.zeros((ch, n) if ch == 2 else n, np.float32)

    def add(self, x, t, g=1.0):
        s = int(round(t * SR))
        if self.wrap:
            s %= self.n
        elif s < 0:
            x = x[..., -s:]
            s = 0
        x = x * g
        pos = 0
        L = x.shape[-1]
        while pos < L:
            if s >= self.n:
                if not self.wrap:
                    return
                s = 0
            m = min(self.n - s, L - pos)
            self.buf[..., s:s + m] += x[..., pos:pos + m]
            pos += m
            s += m


def circ(fn, x, pad=2.0):
    """Apply a stateful (IIR / nonlinear) process to a loop without a seam."""
    p = min(int(pad * SR), x.shape[-1])
    y = fn(np.concatenate([x[..., -p:], x], axis=-1))
    return y[..., p:p + x.shape[-1]].astype(np.float32)


def circ_tail(y, n):
    """Fold anything past n samples (reverb tails) back onto the head."""
    out = y[..., :n].copy()
    k = n
    while k < y.shape[-1]:
        m = min(n, y.shape[-1] - k)
        out[..., :m] += y[..., k:k + m]
        k += m
    return out


# ============================================================================ amp + cab
def _sos4(kind, f, order=2):
    return signal.butter(order, f / (SR * 2), btype=kind, output="sos")


def amp(di, gain=1.0, scoop=-5.0, tight=110, fizz=5200):
    """High-gain amp: tight boost -> 2 asymmetric tube stages (4x oversampled) -> tone stack -> 4x12 cab."""
    x = hp(di, tight, 2)
    x = eq(x, 760, 5.0, 0.6)
    x = lp(x, 7000, 1)
    u = signal.resample_poly(x, 4, 1).astype(np.float64)
    g1 = 28.0 * gain
    u = np.tanh(g1 * u + 0.25) - np.tanh(0.25)
    u = signal.sosfilt(_sos4("highpass", 40), u)
    u = signal.sosfilt(_sos4("lowpass", 9000, 1), u)
    u = np.tanh(4.5 * u - 0.1) + np.tanh(0.1)
    u = signal.sosfilt(_sos4("lowpass", 11000, 2), u)
    y = signal.resample_poly(u, 1, 4).astype(np.float32)
    # tone stack: tight lows, scooped mids, presence
    y = lowshelf(y, 140, 2.5)
    y = eq(y, 500, scoop, 0.7)
    y = eq(y, 2400, 2.0, 0.9)
    # 4x12 cabinet
    y = hp(y, 75, 2)
    y = eq(y, 115, 3.0, 1.4)
    y = eq(y, 1500, -1.5, 1.2)
    y = eq(y, 3300, 3.5, 1.6)
    y = lp(y, fizz, 4)
    y = eq(y, 6800, -6.0, 2.0)
    return y.astype(np.float32)


def clean_amp(di):
    y = np.tanh(1.6 * hp(di, 70)) / 1.6
    y = eq(y, 300, -2.0, 0.8)
    y = highshelf(y, 3000, 2.0)
    return lp(y, 9000, 2)


def chorus(x, depth=0.0025, rate=0.6, mix=0.45):
    n = x.shape[-1]
    t = np.arange(n) / SR
    out = []
    for ph in (0.0, np.pi * 0.7):
        d = (0.008 + depth * (1 + np.sin(2 * np.pi * rate * t + ph))) * SR
        idx = np.arange(n) - d
        out.append(x * (1 - mix) + np.interp(idx, np.arange(n), x, period=n) * mix)
    return np.vstack(out).astype(np.float32)


def bass_amp(di):
    lo = lp(di, 220, 2)
    hi = hp(di, 400, 2)
    hi = np.tanh(9.0 * hi) * 0.35
    hi = lp(eq(hi, 1200, 3.0, 0.8), 3800, 4)
    y = lo + hi + 0.4 * di
    y = compress(y, -16, 4, 0.004, 0.08)
    return eq(lowshelf(y, 90, 2.0), 800, -2.0, 0.8)


# ============================================================================ performance
class Song:
    def __init__(self, bpm, bars, beats=4, wrap=True, tail=0.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.beats = beats
        self.n = int(round(bars * beats * self.beat * SR)) + int(tail * SR)
        self.wrap = wrap
        self.gtr = {"L": Loop(self.n, 1, wrap), "R": Loop(self.n, 1, wrap), "L2": Loop(self.n, 1, wrap),
                    "R2": Loop(self.n, 1, wrap)}
        self.bass = Loop(self.n, 1, wrap)
        self.lead = Loop(self.n, 1, wrap)
        self.clean = Loop(self.n, 1, wrap)
        self.kick = Loop(self.n, 2, wrap)
        self.snare = Loop(self.n, 2, wrap)
        self.toms = Loop(self.n, 2, wrap)
        self.cym = Loop(self.n, 2, wrap)
        self.quad = False

    def t(self, bar, beat=0.0):
        return (bar * self.beats + beat) * self.beat

    # --- guitars --------------------------------------------------------------
    def _note(self, side, midi, art, dur, layer="f"):
        guitar = "green" if side.startswith("L") else "black"
        if art in ("m", "M"):
            x = gtr_note(guitar, midi, "ord", layer)
            n = min(len(x), int((min(dur, 0.32) + 0.03) * SR))
            x = x[:n].copy()
            tt = np.arange(n) / SR
            x *= np.exp(-tt / 0.085)
            # palm on the strings: the brightness dies in the first few ms
            x = 0.65 * lp(x, 520, 2) + 0.35 * x * np.exp(-tt / 0.012)
            fo = min(n, int(0.012 * SR))
            x[-fo:] *= np.linspace(1, 0, fo)
            return x * 0.9
        x = gtr_note(guitar, midi, "ord", layer)
        n = min(len(x), int((dur + 0.04) * SR))
        x = x[:n].copy()
        fo = min(n, int(0.03 * SR))
        x[-fo:] *= np.linspace(1, 0, fo)
        return x

    def riff(self, bar, tokens, grid=4, sides=("L", "R"), layer="f", beats=None, bass=True, oct_bass=-12):
        """tokens: '<fret><art>[:len]' on the low E string (fret 0 = E2) or '.[:len]' rests.
        art m palm-muted note, M muted 5th chord, p ringing power chord, n ringing single note,
        o octave (root + octave)."""
        step = self.beat / grid
        pos = 0.0
        evs = []
        for tok in tokens.split():
            ln = 1.0
            if ":" in tok:
                tok, l2 = tok.split(":")
                ln = float(l2)
            if tok != ".":
                evs.append((pos, ln, int(tok[:-1]), tok[-1]))
            pos += ln
        if pos > grid * self.beats + 1e-6:
            print("WARN riff overflows bar %d: %s" % (bar, tokens), file=sys.stderr)
        for side in sides:
            jit = 0.006 if side.startswith("R") else 0.0
            for i, (p, ln, fret, art) in enumerate(evs):
                dur = ln * step
                if i + 1 < len(evs) and evs[i + 1][0] < p + ln + 1e-6:
                    dur = (evs[i + 1][0] - p) * step
                t0 = self.t(bar) + p * step + jit + RNG.uniform(-0.004, 0.004)
                root = 40 + fret
                notes = [root]
                if art in ("M", "p"):
                    notes = [root, root + 7] + ([root + 12] if art == "p" else [])
                elif art == "o":
                    notes = [root, root + 12]
                for k, m in enumerate(notes):
                    g = 1.0 if k == 0 else 0.8
                    self.gtr[side].add(self._note(side, m, art, dur, layer), t0 + k * 0.004, g)
        if bass:
            for i, (p, ln, fret, art) in enumerate(evs):
                dur = ln * step
                if i + 1 < len(evs) and evs[i + 1][0] < p + ln + 1e-6:
                    dur = (evs[i + 1][0] - p) * step
                m = 40 + fret + oct_bass
                while m > 45:
                    m -= 12
                stac = art in ("m", "M")
                x = bass_note(m, "staccato" if stac else "sustain", "ff" if stac else "f")
                n = min(len(x), int((dur + 0.02) * SR))
                x = x[:n].copy()
                fo = min(n, int(0.02 * SR))
                x[-fo:] *= np.linspace(1, 0, fo)
                self.bass.add(x, self.t(bar) + p * step + RNG.uniform(0, 0.004), 0.9 if stac else 1.0)
        return pos

    def lead_line(self, bar, notes, vib=0.25, side="lead"):
        """notes: list of (midi|None, beats[, bend_semis]) played legato with delayed vibrato."""
        pos = 0.0
        for nt in notes:
            m, ln = nt[0], nt[1]
            if m is not None:
                dur = ln * self.beat
                x = gtr_note("green", m, "ord", "f")
                n = min(len(x), int((dur + 0.05) * SR))
                x = x[:n].astype(np.float64)
                tt = np.arange(n) / SR
                cents = vib * np.clip((tt - 0.25) / 0.3, 0, 1) * np.sin(2 * np.pi * 5.4 * tt) * 100
                if len(nt) > 2:
                    cents = cents + nt[2] * 100 * np.clip(tt / 0.12, 0, 1)
                rate = 2 ** (cents / 1200)
                ph = np.cumsum(rate)
                ph = ph[ph < n - 1]
                y = np.interp(ph, np.arange(n), x).astype(np.float32)
                fo = min(len(y), int(0.04 * SR))
                y[-fo:] *= np.linspace(1, 0, fo)
                self.lead.add(y, self.t(bar) + pos * self.beat)
            pos += ln

    def arp(self, bar, chord, pattern, grid=2, guitar="L", ring=True):
        """Clean arpeggio: chord = list of midi, pattern = indices (or '.')."""
        step = self.beat / grid
        for i, c in enumerate(pattern):
            if c == ".":
                continue
            m = chord[int(c)]
            for side, g in (("green", 1.0), ("black", 0.0)):
                if g <= 0:
                    continue
                x = gtr_note(side, m, "ord", "mf")
                n = min(len(x), int(((len(pattern) - i) * step + 0.6 if ring else step * 1.5) * SR))
                x = x[:n].copy()
                fo = min(n, int(0.25 * SR))
                x[-fo:] *= np.linspace(1, 0, fo)
                self.clean.add(x, self.t(bar) + i * step + RNG.uniform(0, 0.006), 0.6)

    # --- drums -----------------------------------------------------------------
    def drums(self, bar, lanes, grid=4):
        step = self.beat / grid
        for piece, pat in lanes.items():
            for i, c in enumerate(pat.replace(" ", "")):
                if c in ".-":
                    continue
                vel = {"X": 1.0, "x": 0.82, "o": 0.45, "g": 0.25}[c]
                vel = float(np.clip(vel + RNG.uniform(-0.06, 0.04), 0, 1))
                t0 = self.t(bar) + i * step + RNG.uniform(-0.003, 0.003)
                x = drum_hit(piece, vel)
                if x is None:
                    continue
                if piece in ("crash", "china", "ride", "bell", "hat", "hato"):
                    dest = self.cym
                elif piece == "kick":
                    dest = self.kick
                elif piece in ("t1", "t2", "t3"):
                    p = {"t1": -0.35, "t2": 0.1, "t3": 0.4}[piece]
                    x = x * np.array([[np.cos((p + 1) * np.pi / 4)], [np.sin((p + 1) * np.pi / 4)]]) * 1.41
                    dest = self.toms
                else:
                    dest = self.snare
                if piece == "hat":
                    x = x[:, : int(0.6 * SR)]
                dest.add(x, t0, 0.55 + 0.45 * vel)

    # --- mix ---------------------------------------------------------------------
    def mix(self, guitar_gain=1.0, verb_wet=0.12, lead_db=-3.0, clean_db=0.0, dist_from=None, scoop=-5.0):
        n = self.n
        c = (lambda f, x: circ(f, x)) if self.wrap else (lambda f, x: f(x))
        tail = (lambda y: circ_tail(y, n)) if self.wrap else (lambda y: y[..., :n])
        out = np.zeros((2, n), np.float32)

        def lvl(x, target):
            r = np.sqrt(np.mean(np.square(x))) + 1e-9
            return x * db(target - 20 * np.log10(r)) if r > 1e-6 else x

        # rhythm guitars
        gl = c(lambda x: amp(x, guitar_gain, scoop), self.gtr["L"].buf)
        gr = c(lambda x: amp(x, guitar_gain * 0.92, scoop - 1, fizz=5600), self.gtr["R"].buf)
        gs = np.vstack([gl * 0.98 + gr * 0.12, gr * 0.98 + gl * 0.12])
        if np.any(self.gtr["L2"].buf):
            g2l = c(lambda x: amp(x, guitar_gain * 1.2, scoop + 2, fizz=4500), self.gtr["L2"].buf)
            g2r = c(lambda x: amp(x, guitar_gain * 1.2, scoop + 2, fizz=4500), self.gtr["R2"].buf)
            gs += np.vstack([0.75 * g2l + 0.35 * g2r, 0.75 * g2r + 0.35 * g2l]) * 0.6
        gs = lvl(gs, -17.5)
        out += gs
        # bass
        if np.any(self.bass.buf):
            b = lvl(c(bass_amp, self.bass.buf), -20.0)
            out += np.vstack([b, b])
        # lead: distorted, centre-ish, with a dotted-eighth delay and plate
        if np.any(self.lead.buf):
            ld = c(lambda x: amp(x, 0.8, -1.0, tight=180, fizz=6000), self.lead.buf)
            ld = lvl(ld, -21.0 + lead_db)
            d = int(self.beat * 0.75 * SR)
            echo = np.roll(ld, d) * 0.28 + np.roll(ld, 2 * d) * 0.12
            ls = np.vstack([ld + 0.6 * echo, ld + np.roll(echo, int(0.011 * SR))])
            out += tail(reverb(ls, "plate", 0.25)) if self.wrap else reverb(ls, "plate", 0.25)[:, :n]
        # clean guitar (story)
        if np.any(self.clean.buf):
            cl = c(clean_amp, self.clean.buf)
            cl = lvl(cl, -20.0 + clean_db)
            cs = chorus(cl)
            out += tail(reverb(cs, "hall", 0.35)) if self.wrap else reverb(cs, "hall", 0.35)[:, :n]
        # drums
        kk = c(lambda x: compress(eq(eq(lowshelf(x, 70, 3.0), 380, -6.0, 0.9), 4200, 7.0, 1.0), -18, 4, 0.002, 0.07),
               self.kick.buf)
        sn = c(lambda x: compress(eq(eq(x, 210, 3.0, 1.0), 5200, 3.0, 0.8), -18, 3.5, 0.003, 0.1), self.snare.buf)
        tm = c(lambda x: compress(eq(x, 500, -4.0, 0.8), -18, 3, 0.003, 0.15), self.toms.buf)
        cy = c(lambda x: hp(eq(x, 400, -3.0, 0.8), 250, 2), self.cym.buf)
        kk, sn, tm, cy = lvl(kk, -19.0), lvl(sn, -20.0), lvl(tm, -22.0), lvl(cy, -25.0)
        dr = kk + sn + tm + cy
        dr_room = (tail(reverb(sn + tm, "room", 0.5)) if self.wrap else reverb(sn + tm, "room", 0.5)[:, :n])
        out += dr + 0.35 * dr_room
        out += verb_wet * (tail(reverb(out, "hangar", 1.0)) if self.wrap else reverb(out, "hangar", 1.0)[:, :n]) * 0.3
        return out


# ============================================================================ mastering
def brickwall(x, ceil_db=-1.3, hold=0.004, smooth=0.004):
    a = np.max(np.abs(x), axis=0)
    need = np.minimum(1.0, db(ceil_db) / np.maximum(a, 1e-9))
    h = int(hold * SR)
    g = minimum_filter1d(need, size=2 * h + 1, mode="wrap")
    g = uniform_filter1d(g, size=max(1, int(smooth * SR)), mode="wrap")
    g = np.minimum(g, minimum_filter1d(need, 3, mode="wrap"))
    return (x * g).astype(np.float32)


def true_peak_db(x):
    u = signal.resample_poly(x, 4, 1, axis=-1)
    return 20 * np.log10(np.max(np.abs(u)) + 1e-12)


def lufs(x):
    import pyloudnorm as pyln
    return pyln.Meter(SR).integrated_loudness(x.T.astype(np.float64))


def master(x, wrap=True, target=-14.0):
    c = (lambda f, y: circ(f, y)) if wrap else (lambda f, y: f(y))
    x = c(lambda y: hp(y, 30, 2), x)
    x = c(lambda y: compress(y, -14, 2.0, 0.01, 0.2), x)
    x = c(lambda y: highshelf(eq(y, 300, -1.0, 0.8), 9000, 1.5), x)
    # iterate gain -> limiter until integrated loudness lands on target with peaks under -1 dBTP
    g = 0.0
    for _ in range(6):
        y = brickwall(x * db(g), -1.6)
        L = lufs(y)
        if abs(L - target) < 0.15:
            break
        g += target - L
    while true_peak_db(y) > -1.1:
        y = brickwall(y * 0.995, -1.8)
    return y


# ============================================================================ the songs
D = {
    "rock": {"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."},
}


def lanes(**kw):
    return kw


# Shared chord map for the three run tracks (frets on the low E string, one entry per bar).
# 160 BPM, 72 bars: A (E pedal + phrygian turns) / B (C D E B) / C (descending A G F E) / D (E breakdown) / E turnaround.
RUN_BPM = 160
RUN_MAP = ([0, 0, 0, "3/1", 0, 0, 0, "8/7", 0, 0, 0, "3/1", 0, 0, 8, 10] +
           [8, 10, 0, 0, 8, 10, 7, 7] * 2 +
           [5, 5, 3, 3, 1, 1, 0, 0] * 2 +
           [0] * 16 +
           [8, 10, 0, 0, 8, 10, 7, 7])


def _roots(b):
    v = RUN_MAP[b]
    if isinstance(v, str):
        a, c = v.split("/")
        return int(a), int(c)
    return v, v


def song_explore():
    s = Song(RUN_BPM, 72)
    for b in range(72):
        r1, r2 = _roots(b)
        sec = b // 16 if b < 64 else 4
        quiet = (b % 16) in (0, 1, 2, 3) and sec in (0, 3)
        if quiet:
            # space: ringing chord once, palm mutes trickle in, hats only
            s.riff(b, "%dp:8 . %dm %dm . %dm %dm %dm" % (r1, r1, r1, r1, r1, r1) if b % 2 == 0 else
                   "%dm:2 . %dm %dm:2 . . %dm %dm %dm . %dm %dm:2" % (r1, r1, r1, r1, r1, r1, r1, r1))
            s.drums(b, lanes(hat="x.o.x.o.x.o.x.o." if b % 4 else "....x.o.x.o.x.o.",
                             kick="x...............", crash="X..............." if b % 16 == 0 else "................"))
            continue
        if r1 != r2:
            s.riff(b, "%dm %dm %dm %dm %dm %dm %dp:2 %dm %dm %dm %dm %dp:4" % ((r1,) * 6 + (r1,) + (r2,) * 4 + (r2,)))
        elif b % 4 == 3:
            s.riff(b, "%dm %dm . %dm %dm %dm . %dm 3p:2 5p:2 %dm %dm 7p:2" % ((r1,) * 6 + (r1, r1)) if r1 == 0 else
                   "%dm %dm . %dm %dm %dm . %dm %dp:4 %dm %dm %dm" % ((r1,) * 10))
        else:
            s.riff(b, "%dp:3 %dm %dm . %dm %dm %dm %dm . %dm %dm %dm %dm %dm" % ((r1,) * 12))
        hat = "x.x.x.x.x.x.x.x." if sec != 2 else ""
        ride = "x.x.x.x.x.x.x.x." if sec == 2 else ""
        d = dict(kick="x.....x...x.....", snare="........X.......")
        if hat:
            d["hat"] = hat
        if ride:
            d["ride"] = ride
        if b % 8 == 0 or (b % 16 == 4 and sec in (0, 3)):
            d["crash"] = "X..............."
        if b % 8 == 7:
            d["snare"] = "........X...x.xx"
        s.drums(b, d)
    return s.mix(1.0, 0.12)


def song_combat():
    s = Song(RUN_BPM, 72)
    s.quad = True
    for b in range(72):
        r1, r2 = _roots(b)
        sec = b // 16 if b < 64 else 4
        if sec == 3:
            # breakdown: double kick under a chromatic gallop
            riff = ("0m 0m 0m 1M:2 0m 0m 0m 0m 0m 0m 6M:2 0m 0m 5M" if b % 2 == 0 else
                    "0m 0m 0m 0m 3p:2 0m 0m 0m 0m 0m 0m 2p:2 1p:2")
            s.riff(b, riff, sides=("L", "R", "L2", "R2"))
            d = dict(kick="xxxxxxxxxxxxxxxx", snare="....X.......X...", china="X.......X......." if b % 2 else "X...............")
            if b % 4 == 3:
                d["snare"] = "....X.......XxXx"
            s.drums(b, d)
            continue
        if r1 != r2:
            riff = "%dm:2 %dm %dm %dm:2 %dm %dm %dp:2 %dm %dm %dm:2 %dm %dm" % ((r1,) * 6 + (r2,) * 6)
        else:
            if b % 4 == 3 and sec in (0, 4):
                riff = "%dm:2 %dm %dm %dm:2 %dm %dm 7p:2 6p:2 5p:2 3p:2" % ((r1,) * 6)
            else:
                riff = "%dm:2 %dm %dm %dm:2 %dm %dm %dm:2 %dm %dm %dp:2 %dm %dm" % ((r1,) * 12)
        s.riff(b, riff, sides=("L", "R", "L2", "R2"))
        if sec == 2:
            d = dict(kick="x.x.x.x.x.x.x.x.", snare="..x...x...x...x.", ride="x.x.x.x.x.x.x.x.")
        else:
            d = dict(kick="x.xxx.xxx.xxx.xx", snare="....X.......X...", hat="x.x.x.x.x.x.x.x.")
        if b % 4 == 0:
            d["crash"] = "X..............."
        if b % 8 == 7:
            d["snare"] = "....X...X.x.XxXx"
            d.pop("hat", None)
            d["t2"] = "..........x....."
        s.drums(b, d)
    return s.mix(1.1, 0.10)


def song_boss():
    s = Song(RUN_BPM, 72)
    for b in range(72):
        r1, r2 = _roots(b)
        sec = b // 16 if b < 64 else 4
        if sec == 3:
            # tritone stomp
            s.riff(b, "0M:2 0m 0m 6M:2 0m 0m 0M:2 0m 0m 6p:2 5p:2", sides=("L", "R", "L2", "R2"))
            s.drums(b, dict(kick="xxxxxxxxxxxxxxxx", snare="X...X...X...X...", china="X.X.X.X.X.X.X.X."))
            if b % 4 == 0:
                s.lead_line(b, [(76, 4, 0), (77, 2), (76, 2), (82, 8, -1)])
            continue
        if r1 != r2:
            tr = " ".join(["%dm" % r1] * 8 + ["%dm" % r2] * 8)
        elif b % 2 == 1:
            tr = " ".join(["%dm" % r1] * 4 + ["%dm" % (r1 + 1)] * 2 + ["%dm" % r1] * 2 + ["%dm" % (r1 + 6)] * 2 +
                          ["%dm" % r1] * 2 + ["%dm" % (r1 + 1)] * 4)
        else:
            tr = " ".join(["%dm" % r1] * 16)
        s.riff(b, tr, sides=("L", "R"))
        s.riff(b, "%dp:8 %dp:8" % (r1, r2) if r1 != r2 else "%dp:16" % r1, sides=("L2", "R2"), bass=False)
        d = dict(kick="xxxxxxxxxxxxxxxx", snare="..X...X...X...X.", crash="X...x...x...x..." if sec == 1 else "X.......x.......")
        if sec == 2:
            d["snare"] = "X.X.X.X.X.X.X.X."
            d["kick"] = "x.x.x.x.x.x.x.x."
            d["ride"] = "xxxxxxxxxxxxxxxx"
            d.pop("crash")
        if b % 8 == 7:
            d["snare"] = "X.X.X.XXXXXXXXXX"
            d["t3"] = "............x.x."
        s.drums(b, d)
        if sec in (1, 4) and b % 8 == 0:
            s.lead_line(b, [(71, 1), (74, 1), (76, 2), (79, 2), (78, 1), (76, 1), (74, 4), (76, 6, 0), (None, 2),
                            (79, 2), (81, 2), (82, 4), (83, 6), (None, 2)])
    return s.mix(1.25, 0.10, lead_db=-2.0)


def song_menu():
    # 84 BPM, 40 bars of slow menacing groove on a triplet grid (12 steps per bar).
    s = Song(84, 40)
    for b in range(40):
        part = "intro" if b < 4 else "A" if b < 20 else "B" if b < 28 else "A2" if b < 36 else "outro"
        if part in ("intro", "outro"):
            ch = [0, 1, 0, 6][b % 4]
            s.riff(b, "%dp:12" % ch, grid=3)
            s.drums(b, dict(t3="X.....x.....", t2="......x..x..", crash="X..........." if b % 2 == 0 else "............",
                            kick="X....." + "x....." if b % 4 == 3 else "X..........."), grid=3)
            continue
        cell = (b - 4) % 4
        if part == "B":
            prog = [8, 7, 5, 6][(b - 20) % 4]
            s.riff(b, "%dp:6 %dm %dm:2 %dp:3" % (prog, prog, prog, prog), grid=3)
            s.drums(b, dict(kick="x.....x.x...", snare="......X.....", ride="x..x..x..x..",
                            crash="X..........." if b % 2 == 0 else "............"), grid=3)
            if b % 4 == 0:
                s.lead_line(b, [(64, 3), (67, 1.5), (66, 1.5), (64, 2), (62, 2), (59, 4), (None, 2)], vib=0.3)
            if b % 4 == 2:
                s.lead_line(b, [(64, 3), (67, 1.5), (69, 1.5), (70, 4, 0), (71, 6), (None, 1)], vib=0.3)
            continue
        if cell in (0, 2):
            r = "0p:3 0m:2 0m 0m:2 0m 1p:3"
        elif cell == 1:
            r = "0m:2 0m 0m:2 0m 3p:3 2m:2 1m"
        else:
            r = "0m:2 0m 6p:3 5p:3 . 0m 0m" if part == "A" else "0m:2 0m 6p:3 7p:3 8m:2 7m"
        s.riff(b, r, grid=3)
        d = dict(kick="x....x.x....", snare="......X.....", hat="x..x..x..x..")
        if cell == 0:
            d["crash"] = "X..........."
            d.pop("hat")
        if cell == 3:
            d["snare"] = "......X..x.x"
        s.drums(b, d, grid=3)
    return s.mix(1.0, 0.18)


def song_story():
    # 72 BPM, 36 bars: clean arpeggios (16) -> swell (4) -> distorted with lead (16), looping back.
    s = Song(72, 36)
    prog = [[40, 47, 52, 55, 59, 64], [48, 55, 59, 64, 67], [45, 52, 57, 60, 64], [47, 54, 59, 63, 66]]
    roots = [0, 8, 5, 7]
    pat = "0123432143212343"
    for b in range(36):
        ci = b % 4
        if b < 20:
            s.arp(b, prog[ci], pat, grid=4)
            if b >= 8:
                s.drums(b, dict(ride="x...x...x...x..." if b < 16 else "x.x.x.x.x.x.x.x.",
                                kick="x.........x....." if b >= 12 else "................"))
            if b >= 16:
                s.drums(b, dict(t3="x...x...x..." + ("xxxx" if b == 19 else "x..."), t2="..........x.x.x." if b == 19 else ""))
            if b == 18:
                s.riff(b, "%dp:16" % roots[ci], bass=True)
            if b == 19:
                s.riff(b, "%dp:8 %dp:8" % (roots[ci], roots[ci] - 0), bass=True)
            elif 8 <= b < 18:
                s.riff(b, "%dp:16" % roots[ci], sides=(), bass=True)
            continue
        s.riff(b, "%dp:6 %dm %dm %dp:8" % ((roots[ci],) * 4) if ci != 3 else "%dp:8 %dp:4 %dm %dm %dm %dm" % (7, 7, 7, 7, 7, 7))
        s.drums(b, dict(kick="x.....x...x.....", snare="........X.......", hat="x.x.x.x.x.x.x.x.",
                        crash="X..............." if b % 2 == 0 else "................"))
        if b % 8 == 4:
            s.lead_line(b, [(71, 3), (69, 1), (67, 2), (66, 2), (64, 4), (67, 2), (71, 2), (74, 6), (72, 2),
                            (71, 4), (69, 2), (67, 2), (66, 8)], vib=0.3)
        if b >= 28:
            s.arp(b, [p + 12 for p in prog[ci]][:5], "0123432143212343", grid=4)
    return s.mix(1.0, 0.2, clean_db=-2.0)


def sting_death():
    s = Song(90, 2, wrap=False, tail=2.5)
    s.riff(0, "0p:4 1p:4 0p:8", bass=True)
    s.riff(1, "6p:16", bass=True)
    s.drums(0, dict(crash="X.......X.......", kick="X...X...X.......", t3="........x.x.X..."))
    s.drums(1, dict(china="X...............", kick="X..............."))
    return s.mix(1.0, 0.25)


def sting_extract():
    s = Song(120, 3, wrap=False, tail=2.0)
    s.riff(0, "5m 5m 5m 5m 5p:4 7m 7m 7m 7m 7p:4")
    s.riff(1, "8p:4 10p:4 12p:8", sides=("L", "R"))
    s.riff(2, "0p:16")
    s.drums(0, dict(kick="xxxxx...xxxxx...", snare="....X.......X...", crash="X..............."))
    s.drums(1, dict(kick="X...X...X.......", snare="X...X...XXXXXXXX", crash="X...X...X......."))
    s.drums(2, dict(kick="X...............", crash="X...............", china="X..............."))
    s.lead_line(1, [(None, 2), (76, 2), (79, 4, 0), (83, 4)])
    return s.mix(1.0, 0.25)


TRACKS = {
    "mus_menu": (song_menu, True),
    "mus_explore": (song_explore, True),
    "mus_combat": (song_combat, True),
    "mus_boss": (song_boss, True),
    "mus_story": (song_story, True),
    "mus_sting_death": (sting_death, False),
    "mus_sting_extract": (sting_extract, False),
}


def main():
    out = sys.argv[1]
    names = sys.argv[2:] or list(TRACKS)
    wav_dir = os.environ.get("WANDERER_METAL_WAV", "")
    for name in names:
        fn, loop = TRACKS[name]
        global RNG
        RNG = np.random.default_rng(abs(hash(name)) % 100000)
        x = fn()
        if not loop:
            n = x.shape[-1]
            f = int(1.5 * SR)
            x[:, -f:] *= np.linspace(1, 0, f) ** 2
        y = master(x, loop)
        print("%-18s %6.1fs  LUFS %.2f  TP %.2f dBTP" % (name, y.shape[-1] / SR, lufs(y), true_peak_db(y)), flush=True)
        write_ogg(os.path.join(out, name + ".ogg"), y, q=3)
        if wav_dir:
            write_wav(os.path.join(wav_dir, name + ".wav"), y)


if __name__ == "__main__":
    main()
