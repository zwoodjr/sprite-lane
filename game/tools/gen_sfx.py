#!/usr/bin/env python3
"""Procedural SFX for Wanderer (original, no third-party audio).

Usage: python3 tools/gen_sfx.py   (run from game/)
Writes 16-bit mono WAVs to assets/sfx/.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, attack=0.005, decay_pow=2.0):
    a = int(SR * attack)
    e = np.ones(n)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** decay_pow
    e[a:] *= tail
    return e


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, k=6):
    kernel = np.ones(k) / k
    return np.convolve(x, kernel, mode="same")


def sweep(f0, f1, dur, shape="sine"):
    tt = t(dur)
    f = np.linspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    return np.sin(ph)


def save(name, x, gain=0.8):
    os.makedirs(OUT, exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name)


# Player shot: short punchy noise + falling tone
d = 0.09
n = int(SR * d)
x = lowpass(noise(n), 3) * env(n, 0.001, 3) * 0.7 + sweep(900, 180, d, "square") * env(n, 0.001, 4) * 0.4
save("shot", x, 0.55)

# Enemy shot: lower, buzzier
d = 0.12
n = int(SR * d)
x = sweep(420, 120, d, "saw") * env(n, 0.002, 3) * 0.6 + lowpass(noise(n), 5) * env(n, 0.001, 4) * 0.4
save("enemy_shot", x, 0.4)

# Hit: thud
d = 0.08
n = int(SR * d)
x = sweep(260, 70, d) * env(n, 0.001, 2) + lowpass(noise(n), 8) * env(n, 0.001, 6) * 0.5
save("hit", x, 0.6)

# Enemy death: crunch + downward sweep
d = 0.32
n = int(SR * d)
x = lowpass(noise(n), 4) * env(n, 0.002, 2.5) * 0.8 + sweep(300, 40, d, "square") * env(n, 0.002, 2) * 0.35
save("enemy_die", x, 0.65)

# Player hurt
d = 0.18
n = int(SR * d)
x = sweep(220, 90, d, "square") * env(n, 0.002, 2) * 0.6 + lowpass(noise(n), 6) * env(n, 0.001, 3) * 0.4
save("hurt", x, 0.6)

# Dash: airy whoosh
d = 0.22
n = int(SR * d)
nz = noise(n)
x = lowpass(nz, 12) * np.sin(np.linspace(0, np.pi, n)) ** 1.5
save("dash", x, 0.5)

# Reload: two clicks
d = 0.35
n = int(SR * d)
x = np.zeros(n)
for start in (0.0, 0.22):
    s = int(SR * start)
    m = int(SR * 0.03)
    x[s:s + m] += noise(m) * env(m, 0.0005, 5)
    x[s:s + m] += sweep(1800, 900, 0.03, "square")[:m] * env(m, 0.0005, 6) * 0.4
save("reload", x, 0.45)

# Crate break: woody crack
d = 0.25
n = int(SR * d)
x = lowpass(noise(n), 2) * env(n, 0.001, 4) + sweep(180, 60, d) * env(n, 0.001, 2) * 0.5
save("break", x, 0.6)

# Pickup: rising arpeggio
notes = [523.25, 659.25, 783.99, 1046.5]
x = np.concatenate([np.sin(2 * np.pi * f * t(0.06)) * env(int(SR * 0.06), 0.002, 1.5) for f in notes])
save("pickup", x, 0.45)

# Extract open: bright two-tone horn
d = 0.7
n = int(SR * d)
tt = t(d)
x = (np.sin(2 * np.pi * 440 * tt) + 0.6 * np.sin(2 * np.pi * 660 * tt) + 0.3 * np.sign(np.sin(2 * np.pi * 220 * tt)))
x *= env(n, 0.04, 1.2)
save("extract_open", x, 0.45)

# Seal: low descending
d = 0.6
n = int(SR * d)
x = sweep(330, 110, d, "saw") * env(n, 0.02, 1.5)
x = lowpass(x, 10)
save("seal", x, 0.45)

# Extract success: fanfare
seq = [(523.25, 0.12), (659.25, 0.12), (783.99, 0.12), (1046.5, 0.45)]
x = np.concatenate([
    (np.sin(2 * np.pi * f * t(dd)) + 0.4 * np.sign(np.sin(2 * np.pi * f / 2 * t(dd)))) * env(int(SR * dd), 0.005, 1.2)
    for f, dd in seq
])
save("extract_win", x, 0.5)

# Wipe: sad descending
seq = [(392.0, 0.18), (329.63, 0.18), (261.63, 0.5)]
x = np.concatenate([sweep(f, f * 0.97, dd, "saw") * env(int(SR * dd), 0.005, 1.4) for f, dd in seq])
x = lowpass(x, 8)
save("wipe", x, 0.5)

# UI tap
d = 0.05
n = int(SR * d)
x = np.sin(2 * np.pi * 880 * t(d)) * env(n, 0.001, 3)
save("ui_tap", x, 0.35)

# Threat up: alarm
d = 0.8
n = int(SR * d)
tt = t(d)
f = 500 + 180 * np.sign(np.sin(2 * np.pi * 5 * tt))
x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * env(n, 0.01, 1.0)
x = lowpass(x, 6)
save("threat_up", x, 0.35)

# Ability: shimmering heal
d = 0.5
n = int(SR * d)
tt = t(d)
x = sum(np.sin(2 * np.pi * f * tt) for f in (660, 880, 1320)) * env(n, 0.02, 1.3)
x *= 1 + 0.3 * np.sin(2 * np.pi * 12 * tt)
save("ability", x, 0.4)

# Mount rev
d = 0.4
n = int(SR * d)
x = sweep(60, 180, d, "saw") * env(n, 0.01, 0.8)
x = lowpass(x, 5)
save("mount", x, 0.45)

# Empty click
d = 0.04
n = int(SR * d)
save("empty", noise(n) * env(n, 0.0005, 6), 0.3)
