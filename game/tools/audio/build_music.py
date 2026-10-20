"""Wanderer ambience beds + music (menu theme, four in-run stems).

Usage:  WANDERER_AUDIO_SRC=/path/to/CC0-Public-Domain-Sounds python3 -I build_music.py OUT_DIR [amb|music|all]
Music is composed procedurally from recorded CC0 cello (Ben Burnes "Novice Cello"), CC0 impacts
(Kenney) and synthesis. Every file loops seamlessly (tails folded onto the head).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import dsp
from dsp import *  # noqa
from build_sfx import (T, K, R, C1, C2, B, F, S2, L, WS, EM, TB,  # noqa
                       radio_voice, radio_squelch, wind, far_horn, cello)

FD = "bb - Fans and Drones (Jul 2021)/"
RF = "Micro Pack - Record Fuzzies/"
MV = "warfork-cc0/sounds/movers/"


# ------------------------------------------------------------------ helpers
class Loop:
    """Stereo buffer whose writes wrap around (for seamless loops)."""

    def __init__(self, dur):
        self.n = sec(dur)
        self.buf = np.zeros((2, self.n), np.float32)

    def add(self, x, t, g=0.0, p=0.0):
        if x.ndim == 1:
            x = pan(x, p)
        x = x * db(g)
        s = sec(t) % self.n
        pos = 0
        while pos < x.shape[1]:
            m = min(self.n - s, x.shape[1] - pos)
            self.buf[:, s:s + m] += x[:, pos:pos + m]
            pos += m
            s = 0

    def verb(self, space, wet):
        y = reverb(self.buf, space, wet)
        out = y[:, :self.n].copy()
        k = self.n
        while k < y.shape[1]:
            m = min(self.n, y.shape[1] - k)
            out[:, :m] += y[:, k:k + m]
            k += m
        self.buf = out
        return self


def tile(x, d, xf=0.6):
    """Repeat a recorded loop to length d with short crossfades."""
    n = sec(d)
    x = x.copy()
    f = sec(xf)
    out = np.zeros(n + x.shape[-1], np.float32)
    w = np.ones(len(x), np.float32)
    w[:f] = np.linspace(0, 1, f)
    w[-f:] = np.linspace(1, 0, f)
    pos = 0
    while pos < n:
        out[pos:pos + len(x)] += x * w
        pos += len(x) - f
    return out[:n]


def circ_noise_bed(d, fn):
    """Render a continuous texture 4 s longer and fold for a seamless loop."""
    x = fn(d + 4.0)
    return loop_xfade(x, 4.0)


def stereo_wind(d, lo, hi, gust, seed_, color="pink"):
    l = wind(d, lo, hi, gust, seed_, color)
    r = wind(d, lo * 1.05, hi * 0.95, gust, seed_ + 17, color)
    return np.vstack([l, r])


def distant(x, lpf=1800, wet=0.6, space="outdoor"):
    return reverb(lp(x, lpf), space, wet)


def crickets(d, count=5):
    n = sec(d)
    out = np.zeros((2, n), np.float32)
    for c in range(count):
        f = dsp.RNG.uniform(3900, 5200)
        x = np.zeros(n, np.float32)
        t = dsp.RNG.uniform(0, 0.8)
        period = dsp.RNG.uniform(0.45, 0.9)
        syl = int(dsp.RNG.integers(2, 5))
        while t < d - 0.3:
            for s_ in range(syl):
                a = sec(t + s_ * 0.035)
                L_ = sec(0.022)
                if a + L_ < n:
                    tt = np.arange(L_) / SR
                    x[a:a + L_] += np.sin(2 * np.pi * f * tt) * np.hanning(L_)
            t += period * dsp.RNG.uniform(0.9, 1.1)
        out += pan(x, dsp.RNG.uniform(-0.8, 0.8)) * db(dsp.RNG.uniform(-12, -4))
    return out * 0.2


def flies(d, count=3):
    n = sec(d)
    out = np.zeros((2, n), np.float32)
    for c in range(count):
        L_ = dsp.RNG.uniform(2.0, 4.0)
        t0 = dsp.RNG.uniform(0, d - L_)
        base = dsp.RNG.uniform(170, 240)
        k = sec(L_)
        f = base * (1 + 0.04 * np.sin(np.linspace(0, dsp.RNG.uniform(20, 40), k))) * np.linspace(1.04, 0.96, k)
        ph = np.cumsum(f / SR) % 1.0
        x = (2 * ph - 1).astype(np.float32)
        x = bp(x, 250, 3500)
        e = np.hanning(k).astype(np.float32) ** 1.5
        p = np.linspace(dsp.RNG.uniform(-1, 0), dsp.RNG.uniform(0, 1), k)
        st = np.vstack([x * e * np.cos((p + 1) * np.pi / 4), x * e * np.sin((p + 1) * np.pi / 4)])
        a = sec(t0)
        out[:, a:a + k] += st[:, :n - a] * 0.25
    return out


def hum(d, f0=55.0, beat=0.13):
    t = t_axis(d)
    x = sum(np.sin(2 * np.pi * f0 * h * t + h) / h * (1 + 0.3 * np.sin(2 * np.pi * beat * h * t)) for h in (1, 2, 3, 4, 6))
    return lp(x.astype(np.float32), 900) * 0.2


def scatter(loop, d, items, count, g_range, lpf=2200, wet=0.6, space="outdoor"):
    for _ in range(count):
        src = items[int(dsp.RNG.integers(0, len(items)))]
        x = src() if callable(src) else src
        y = distant(x, lpf, wet, space)
        y = y * db(dsp.RNG.uniform(*g_range))
        pp = dsp.RNG.uniform(-0.85, 0.85)
        y = np.vstack([y[0] * (1 - max(0, pp)), y[1] * (1 + min(0, pp))])
        loop.add(y, dsp.RNG.uniform(0, d))


# ------------------------------------------------------------------ ambience
AMB_LEN = 40.0


def amb_base(seed_, wind_lo=160, wind_hi=1100, gust=0.55, wind_g=-6, whistle=True):
    dsp.seed(seed_)
    lp_ = Loop(AMB_LEN)
    w = circ_noise_bed(AMB_LEN, lambda d: stereo_wind(d, wind_lo, wind_hi, gust, seed_))
    lp_.add(w, 0, wind_g)
    if whistle:
        ws = circ_noise_bed(AMB_LEN, lambda d: wind(d, 650, 1500, 0.8, seed_ + 3, "white"))
        ws = svf(ws, 900 + 300 * np.sin(np.linspace(0, 6.28 * 3, len(ws))), 9.0, "bp")
        lp_.add(widen(ws, 0.6), 0, wind_g - 18)
    return lp_


def creak(i=None):
    k = int(dsp.RNG.integers(1, 4))
    return T(R + "creak%d.ogg" % k, -5 - dsp.RNG.uniform(0, 3))


def clank():
    return T(K + "impactMetal_heavy_%03d.ogg" % int(dsp.RNG.integers(0, 5)), -4)


def howl():
    return T(C1 + "howl.ogg", -3 - dsp.RNG.uniform(0, 2))


def far_shot():
    return hp(T(B + "shot_0%d.ogg" % int(dsp.RNG.integers(1, 4)), -2), 200)


def moan():
    return T(C2 + "monster_%02d.ogg" % int(dsp.RNG.integers(8, 21)), -8)


def rocks():
    return T(F + "bfh1_rock_falling_0%d.ogg" % int(dsp.RNG.integers(1, 10)), -3)


def finish(lp_, target=-30.0):
    x = lp_.buf
    x = hp(x, 30)
    return active_rms_norm(x, target, -6.0)


def AMB():
    beds = {}

    a = amb_base(11)
    scatter(a, AMB_LEN, [creak, clank], 6, (-20, -12), 2000, 0.6)
    scatter(a, AMB_LEN, [howl], 1, (-26, -22), 1500, 0.7)
    beds["amb_wasteland"] = finish(a)

    a = amb_base(12, 140, 800, 0.5, -9)
    mach = tile(lp(T(S2 + "sfx100v2_loop_machine_01.ogg"), 1600), AMB_LEN + 4)
    a.add(widen(loop_xfade(mach, 4.0), 0.4), 0, -14)
    hiss = lambda: fade(hp(T(S2 + "sfx100v2_air_0%d.ogg" % int(dsp.RNG.integers(1, 3)), -2), 1200), 0.2, 0.6)
    scatter(a, AMB_LEN, [hiss], 4, (-20, -14), 7000, 0.4)
    scatter(a, AMB_LEN, [clank, creak], 5, (-22, -14), 2500, 0.6)
    beds["amb_refinery"] = finish(a)

    a = amb_base(13, 150, 700, 0.6, -12, False)
    cr = circ_noise_bed(AMB_LEN, lambda d: crickets(d, 6).mean(0))
    crs = circ_noise_bed(AMB_LEN, lambda d: crickets(d, 5)[0])
    a.add(np.vstack([cr, crs]), 0, -10)
    bark = lambda: T(C1 + "barking_0%d.ogg" % int(dsp.RNG.integers(1, 3)), -2)
    scatter(a, AMB_LEN, [bark], 2, (-30, -26), 1500, 0.75)
    scatter(a, AMB_LEN, [creak], 4, (-22, -16), 2000, 0.6)
    beds["amb_city_night"] = finish(a, -32)

    a = amb_base(14, 150, 700, 0.6, -12, False)
    a.add(widen(circ_noise_bed(AMB_LEN, lambda d: hum(d, 49.0, 0.11)), 0.3), 0, -10)
    fl = circ_noise_bed(AMB_LEN, lambda d: flies(d, 6))
    a.add(fl, 0, -12)
    scatter(a, AMB_LEN, [moan], 4, (-26, -20), 1200, 0.75)
    beds["amb_quarantine"] = finish(a)

    a = amb_base(15)
    st = tile(bp(T(EM + "NazdyNate - EM Room Noise 2.wav"), 500, 4000), AMB_LEN + 4)
    gate = np.interp(np.arange(len(st)), np.linspace(0, len(st), 14), dsp.RNG.uniform(0, 1, 14) > 0.5).astype(np.float32)
    st = st * lp(gate, 3)
    a.add(pan(loop_xfade(st, 4.0), -0.4), 0, -20)
    vo = lambda: mix((radio_squelch(0.1), 0, -4), (radio_voice(dsp.RNG.uniform(0.8, 1.6)), 0.1, 0))
    scatter(a, AMB_LEN, [vo], 3, (-24, -20), 3000, 0.35)
    scatter(a, AMB_LEN, [far_shot], 4, (-30, -24), 1500, 0.8)
    scatter(a, AMB_LEN, [clank], 3, (-24, -18), 2000, 0.6)
    beds["amb_raider"] = finish(a)

    a = amb_base(16, 140, 800, 0.5, -11, False)
    hissbed = circ_noise_bed(AMB_LEN, lambda d: np.vstack([bp(noise(d), 2500, 8000), bp(noise(d), 2600, 7800)]))
    a.add(hissbed, 0, -20)
    bub = tile(T(L + "water_boiling.ogg"), AMB_LEN + 4)
    a.add(pan(lp(loop_xfade(bub, 4.0), 3000), 0.3), 0, -12)
    pump = tile(lp(T(L + "pump_01.ogg", -3), 1800), AMB_LEN + 4)
    a.add(pan(loop_xfade(pump, 4.0), -0.4), 0, -18)
    beds["amb_chemical"] = finish(a)

    a = amb_base(17, 160, 1000, 0.55, -9)
    gen = lp(T(FD + "Outdoor AC Unit.wav", 0, 2.0, AMB_LEN + 4), 1800)
    a.add(widen(loop_xfade(gen, 4.0), 0.3), 0, -16)
    alarm = lambda: lp(T(L + "alarm_01.ogg", -3), 1500)
    scatter(a, AMB_LEN, [alarm], 2, (-30, -26), 1300, 0.85)
    scatter(a, AMB_LEN, [clank, creak], 5, (-22, -14), 2200, 0.6)
    beds["amb_military"] = finish(a)

    a = amb_base(18, 90, 700, 0.35, -3, False)
    a.add(circ_noise_bed(AMB_LEN, lambda d: np.vstack([lp(noise(d, "brown"), 160), lp(noise(d, "brown"), 150)])), 0, -6)
    th = lambda: T(S2 + "sfx100v2_thunder_01.ogg", -3 - dsp.RNG.uniform(0, 3))
    scatter(a, AMB_LEN, [th], 2, (-16, -10), 900, 0.5)
    scatter(a, AMB_LEN, [rocks], 6, (-24, -16), 2500, 0.5)
    beds["amb_crater"] = finish(a, -28)

    a = amb_base(19, 90, 600, 0.35, -5, False)
    a.add(circ_noise_bed(AMB_LEN, lambda d: np.vstack([lp(noise(d, "brown"), 140), lp(noise(d, "brown"), 130)])), 0, -8)
    a.add(widen(circ_noise_bed(AMB_LEN, lambda d: hum(d, 41.2, 0.07)), 0.4), 0, -8)
    scatter(a, AMB_LEN, [moan, th], 4, (-24, -16), 1100, 0.75)
    beds["amb_dustfall"] = finish(a, -28)

    a = amb_base(20, 120, 1600, 0.25, 0, True)
    a.add(circ_noise_bed(AMB_LEN, lambda d: np.vstack([lp(noise(d, "brown"), 300), lp(noise(d, "brown"), 280)])), 0, 0)
    beds["amb_storm"] = finish(a, -22)

    # Hangar: generator, roof in the wind, radio left on, dogs, tools.
    dsp.seed(21)
    a = Loop(AMB_LEN)
    gen = lp(T(FD + "Large Fan.wav", 0, 3.0, AMB_LEN + 4), 2500)
    a.add(widen(loop_xfade(gen, 4.0), 0.3), 0, -6)
    a.add(widen(circ_noise_bed(AMB_LEN, lambda d: hum(d, 60.0, 0.05)), 0.2), 0, -16)
    out = circ_noise_bed(AMB_LEN, lambda d: stereo_wind(d, 120, 500, 0.6, 77, "brown"))
    a.add(out, 0, -10)
    vo = lambda: mix((radio_squelch(0.1), 0, -4), (radio_voice(dsp.RNG.uniform(1.0, 2.0)), 0.1, 0))
    scatter(a, AMB_LEN, [vo], 3, (-30, -25), 2500, 0.45, "hangar")
    dog = lambda: T(C1 + "barking_0%d.ogg" % int(dsp.RNG.integers(1, 3)), -1)
    scatter(a, AMB_LEN, [dog], 2, (-32, -28), 2500, 0.6, "hangar")
    tool = lambda: T(K + "impactMetal_light_%03d.ogg" % int(dsp.RNG.integers(0, 5)), -3)
    scatter(a, AMB_LEN, [tool, creak], 6, (-28, -20), 3500, 0.55, "hangar")
    beds["amb_hangar"] = finish(a, -30)
    return beds


# ------------------------------------------------------------------ music
BPM = 80.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
RUN_LEN = BAR * 16  # 48 s
CHORDS = [  # (root midi for bass, cello voicing)
    (38, [38, 45, 53]),   # Dm
    (34, [34, 41, 50]),   # Bb
    (43, [43, 50, 58]),   # Gm
    (45, [45, 52, 49]),   # A (C# in the middle — the one bright colour)
]


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def cello_sus(note, dur, take=1, att=1.6, rel=2.5):
    x = cello(note, "Sustain", take)
    x = x[sec(0.4):]
    if len(x) < sec(dur):
        x = stretch_sustain(x, dur, 0.3, 0.1, 0.9)
    x = x[: sec(dur)]
    return lp(x * env_ar(len(x), att, rel, 1.5), 2800)


def taiko(semis=-10, k=0):
    p = T(K + "impactPunch_heavy_%03d.ogg" % k, semis)
    return mix((lowshelf(p, 120, 5), 0, 0), (thump(70, 40, 0.5, 0.18, 0.2), 0, -4))


def kick():
    return mix((thump(68, 38, 0.45, 0.14, 0.5), 0, 0))


def snare():
    pl = T(K + "impactPlate_heavy_001.ogg", -6)
    nz = bp(noise(0.25), 900, 6000) * env_exp(sec(0.25), 0.07)
    return mix((pl, 0, -2), (nz, 0, -6), (thump(180, 120, 0.12, 0.05, 0.2), 0, -6))


def pulse_note(m, d, cutoff=420, drive=2.0):
    f = mtof(m)
    x = saw(f, d) * 0.6 + saw(f * 1.005, d) * 0.4
    x = lp(x, cutoff, 2)
    x = sat(x * env_exp(sec(d), d * 0.45, 0.003), drive)
    return x


def music_menu():
    dsp.seed(301)
    D = 64.0
    m = Loop(D)
    seg = D / 4
    for ci, (root, voicing) in enumerate(CHORDS):
        for vi, note in enumerate(voicing):
            x = cello_sus(note, seg + 5.0, 1 + (ci + vi) % 2, 3.0, 4.0)
            m.add(x, ci * seg - 1.0 + vi * 0.4, -3 - vi * 2, [-0.35, 0.35, 0.0][vi])
        sub = sine(mtof(root - 12), seg + 4) * env_ar(sec(seg + 4), 2.0, 3.0) * 0.35
        sub = sat(sub * 2.0, 1.5) * 0.5  # harmonics so phones hear it
        m.add(lp(sub, 300), ci * seg - 1.0, -10)
    # pluck motif (sparse, recorded plucks)
    motif = [(4.0, 50), (6.0, 53), (8.5, 52), (20.0, 50), (22.0, 46), (36.0, 55), (38.0, 53), (40.5, 50), (52.0, 57), (54.0, 52), (57.0, 49)]
    for t, n in motif:
        p = cello(n, "Pluck", 1 + int(t) % 2)[: sec(3.0)]
        m.add(fade(p, 0.002, 1.0), t, -6, dsp.RNG.uniform(-0.3, 0.3))
    for t in (0.0, 32.0):
        m.add(taiko(-12, 1), t, -6)
    for t in (24.0, 56.0):
        m.add(lp(T(K + "impactBell_heavy_001.ogg", -14), 1200), t, -10, 0.2)
    m.verb("hall", 0.55)
    w = circ_noise_bed(D, lambda d: stereo_wind(d, 120, 700, 0.6, 33, "brown"))
    m.add(w, 0, -26)
    return m.buf


def stem_base():
    dsp.seed(401)
    m = Loop(RUN_LEN)
    seg = BAR * 4
    for ci, (root, voicing) in enumerate(CHORDS):
        for vi, note in enumerate(voicing[:2]):
            x = cello_sus(note, seg + 3.0, 1 + vi, 2.0, 3.0)
            m.add(x, ci * seg - 0.8, -3 - vi * 3, [-0.3, 0.3][vi])
    m.verb("hall", 0.5)
    w = circ_noise_bed(RUN_LEN, lambda d: stereo_wind(d, 100, 600, 0.5, 44, "brown"))
    m.add(w, 0, -24)
    return m.buf


def stem_pulse():
    dsp.seed(402)
    m = Loop(RUN_LEN)
    e8 = BEAT / 2
    for bar in range(16):
        root = CHORDS[bar // 4][0]
        for k in range(8):
            t = bar * BAR + k * e8
            acc = 0 if k in (0, 4) else -5 if k % 2 == 0 else -8
            m.add(pulse_note(root, e8 * 0.95, 380 if k else 520), t, acc - 4, 0.0)
        for k in range(16):
            t = bar * BAR + k * BEAT / 4
            if k % 4 == 2:
                sh = hp(noise(0.06), 4000) * env_exp(sec(0.06), 0.015)
                m.add(sh, t, -20, 0.4)
            if k % 2 == 1:
                tk = hp(T(K + "impactMetal_light_%03d.ogg" % (k % 5), 7), 2500)[: sec(0.1)]
                m.add(fade(tk, 0.0005, 0.04), t, -30 + (3 if k % 4 == 3 else 0), -0.4)
    m.verb("room", 0.18)
    return m.buf


def stem_tension():
    dsp.seed(403)
    m = Loop(RUN_LEN)
    s16 = BEAT / 4
    for bar in range(16):
        b0 = bar * BAR
        for k in (0, 3, 10):
            m.add(kick(), b0 + k * s16, -2)
        m.add(snare(), b0 + 8 * s16, -6, 0.1)
        if bar % 4 == 3:
            for j, k in enumerate((12, 13, 14, 15)):
                m.add(taiko(-9 - j, j % 5), b0 + k * s16, -4 - (3 - j), [-0.4, 0.4, -0.2, 0.2][j])
        if bar % 2 == 0:
            root = CHORDS[bar // 4][0] + 12
            sf = lp(cello(root, "Sforzando", 1 + (bar // 2) % 2), 3200)[: sec(2.2)]
            m.add(fade(sf, 0.002, 0.6), b0, -5, -0.2)
            m.add(fade(lp(cello(root + 7, "Sforzando", 2), 3000)[: sec(2.0)], 0.002, 0.6), b0 + 0.02, -9, 0.25)
    m.verb("hall", 0.25)
    return m.buf


def stem_boss():
    dsp.seed(404)
    m = Loop(RUN_LEN)
    s16 = BEAT / 4
    pat = [0, 0, 12, 0, 0, 7, 0, 12, 0, 0, 10, 0, 0, 7, 3, 12]
    for bar in range(16):
        b0 = bar * BAR
        root = CHORDS[bar // 4][0] - 12 + 12
        for k in range(16):
            n = root + pat[k]
            m.add(pulse_note(n, s16 * 0.9, 900, 3.5), b0 + k * s16, -8 if k % 4 else -5)
        for k in range(4):
            m.add(kick(), b0 + k * BEAT, -1)
        m.add(snare(), b0 + 2 * BEAT, -4)
        m.add(snare(), b0 + 3.5 * BEAT, -10)
        anv = mix((T(K + "impactBell_heavy_00%d.ogg" % (bar % 4), -8), 0, 0), (hp(T(K + "impactMetal_heavy_00%d.ogg" % (bar % 5), -3), 200), 0, -6))
        m.add(anv, b0, -8, 0.3 if bar % 2 else -0.3)
        if bar % 4 == 0:
            m.add(lp(cello(CHORDS[bar // 4][0], "Sforzando", 1), 2500)[: sec(3.0)], b0, -4)
    trem = cello_sus(57, RUN_LEN + 2, 2, 0.5, 0.5)[: sec(RUN_LEN)]
    trem = trem * (0.55 + 0.45 * np.sign(np.sin(2 * np.pi * (BPM / 60 * 4 / 2) * np.arange(len(trem)) / SR)))
    m.add(lp(trem, 3500), 0, -16, 0.2)
    m.verb("hangar", 0.18)
    return m.buf


def MUSIC():
    out = {"mus_menu": music_menu()}
    stems = {"mus_run_base": stem_base(), "mus_run_pulse": stem_pulse(), "mus_run_tension": stem_tension(), "mus_run_boss": stem_boss()}
    # balance stems so all four together peak under -1.5 dBFS
    targets = {"mus_run_base": -20, "mus_run_pulse": -23, "mus_run_tension": -21, "mus_run_boss": -21}
    for k in stems:
        x = hp(stems[k], 32)
        stems[k] = x * db(targets[k] - rms_db(x))
    s = sum(stems.values())
    pk = 20 * np.log10(np.max(np.abs(s)) + 1e-9)
    if pk > -1.5:
        for k in stems:
            stems[k] = stems[k] * db(-1.5 - pk)
    for k in stems:
        stems[k] = limit(stems[k], -1.0)
    out.update(stems)
    out["mus_menu"] = active_rms_norm(hp(out["mus_menu"], 32), -19, -1.5)
    return out


def main():
    out = sys.argv[1]
    what = sys.argv[2] if len(sys.argv) > 2 else "all"
    os.makedirs(out, exist_ok=True)
    tot = 0
    if what in ("amb", "all"):
        for k, x in AMB().items():
            p = os.path.join(out, k + ".ogg")
            write_ogg(p, x, q=1)
            tot += os.path.getsize(p)
            print("ok", k, round(x.shape[-1] / SR, 2), flush=True)
    if what in ("music", "all"):
        for k, x in MUSIC().items():
            p = os.path.join(out, k + ".ogg")
            write_ogg(p, x, q=3)
            tot += os.path.getsize(p)
            print("ok", k, round(x.shape[-1] / SR, 2), flush=True)
    print("bytes", tot)


if __name__ == "__main__":
    main()
