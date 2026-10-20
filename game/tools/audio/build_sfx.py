"""Wanderer SFX build: layered CC0 recordings + physical-ish synthesis.

Usage:  WANDERER_AUDIO_SRC=/path/to/CC0-Public-Domain-Sounds python3 -I build_sfx.py OUT_DIR [only_prefix]
Sources: github.com/lavenderdotpet/CC0-Public-Domain-Sounds (all CC0, see game/assets/ATTRIBUTION.md).
Each recipe returns one mono variant; variants are written as <id>_<n>.ogg.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import zlib
import numpy as np
from dsp import *  # noqa
import dsp

W = "warfork-cc0/sounds/weapons/"
PL = "warfork-cc0/sounds/players/"
MV = "warfork-cc0/sounds/movers/"
K = "kenney_impactsounds/"
R = "kenney_rpgaudio/"
C1 = "80-CC0-creature-SFX/"
C2 = "80-CC0-creature-sfx-2/"
B = "25-CC0-bang-sfx/"
F = "75-cc0-breaking-falling-hit-sfx/"
S1 = "100-CC0-SFX/"
WM = "100-CC0-wood-metal-SFX/"
S2 = "100-cc0-sfx-2/"
OW = "Micro Pack - Organic Wooshes/"
KN = "Micro Pack - Kitchen Knives/"
EM = "Micro Pack - NazdyNate - Electromagnetic Sounds/"
SM = "bb - Smol Mechanisms (May 2021)/"
TB = "bb - Toolbox Rummaging (Sept 2021)/"
PB = "bb - Pill Bottles (Jun 2021)/"
CE = "bb - Novice Cello (Nov 2021)/"
SC = "Micro Pack - Small Can/"
L = "30-cc0-sfx-loops/"
MUD = "25-CC0-mud-sfx/"
WS = "40-cc0-water-splash-slime-sfx/"
BA = "beast_or_animal/"

RECIPES = {}


def sfx(name, n=1, level=-18.0, space=None, wet=0.0, maxlen=None):
    def deco(fn):
        RECIPES[name] = dict(fn=fn, n=n, level=level, space=space, wet=wet, maxlen=maxlen)
        return fn
    return deco


def T(rel, semis=0.0, start=0.0, dur=None, thr=-45):
    """Load + trim + repitch helper."""
    x = load(rel, start, dur)
    x = trim(x, thr)
    if semis:
        x = repitch(x, semis)
    return x


def pick(lst, i):
    return lst[i % len(lst)]


def jit(a=1.0):
    return float(dsp.RNG.uniform(-a, a))


def kn(n):
    return "%03d" % n


# =========================================================================== WEAPONS
@sfx("fire_rook", 3, -14, "outdoor", 0.18)
def _(i):
    body = thump(95 + 10 * i, 34, 0.45, 0.13, 0.6)
    tube = lp(T(K + "impactPunch_heavy_%s.ogg" % kn(i), -7 + jit(0.5)), 1800)
    mech = lp(T(W + "grenlaunch_strong.ogg", -3 + jit(0.6)), 5000)
    air = whoosh(0.5, 280, 1700, 1.2, 0.35)
    return mix((body, 0, 0), (tube, 0, -2), (mech, 0, -9), (air, 0.03, -10))


@sfx("boom_rook", 3, -12, "outdoor", 0.3)
def _(i):
    ex = T(pick([W + "rocket_strong_explosion.ogg", W + "gren_strong_explosion1.ogg", W + "gren_strong_explosion2.ogg"], i), -2 + jit(1))
    ex = lowshelf(sat(ex, 1.6), 150, 4)
    deb = lp(T(F + "bfh1_rock_falling_0%d.ogg" % (i + 2)), 4000)
    return mix((ex, 0, 0), (thump(80, 26, 0.9, 0.25, 0.3), 0, -3), (deb, 0.09, -11))


@sfx("fire_vesper", 3, -13, "outdoor", 0.32)
def _(i):
    bang = hp(T(B + pick(["bang_01.ogg", "bang_06.ogg", "bang_09.ogg"], i), -2 + jit(0.7)), 90)
    bolt = T(R + "metalClick.ogg", -2)
    return mix((crack(0.05, 2800), 0, -4), (bang, 0, 0), (thump(150, 52, 0.25, 0.07, 0.2), 0, -5), (bolt, 0.42, -17))


@sfx("fire_cinder", 3, -15, "outdoor", 0.2)
def _(i):
    sh = hp(T(B + "shot_0%d.ogg" % (i + 1), 0.5 + jit(0.6)), 140)
    chain = hp(T(WM + "keys_0%d.ogg" % (i + 2), 2), 1500)
    return mix((crack(0.04, 4200), 0, -6), (sh, 0, 0), (thump(170, 70, 0.14, 0.05, 0.2), 0, -6), (chain, 0.05, -22))


@sfx("fire_quill", 4, -19, "room", 0.08, 0.32)
def _(i):
    mg = T(W + "machinegun_fire.ogg", 0.8 * i - 1.2 + jit(0.3), 0, 0.2)
    x = mix((mg, 0, 0), (crack(0.03, 5200), 0, -8), (thump(220, 110, 0.08, 0.03, 0.1), 0, -8))
    return highshelf(lp(fade(x, 0.0005, 0.06), 9000), 5000, -3)


@sfx("fire_helm", 3, -16, "outdoor", 0.16)
def _(i):
    sh = hp(T(pick([S1 + "shot_02.ogg", B + "shot_02.ogg", B + "shot_03.ogg"], i), 1.5 + jit(0.5)), 160)
    return mix((crack(0.035, 3800), 0, -5), (sh, 0, 0), (thump(210, 90, 0.11, 0.04, 0.2), 0, -7))


@sfx("drone_fire", 3, -21, "room", 0.06)
def _(i):
    z = T(W + "laser_hit%d.ogg" % i, -5 + jit(0.5))
    return mix((z, 0, 0), (crackle(0.12, 260, 2000, 8000, 0.04), 0, -6), (servo(0.12, 2100, 2700, 0.4), 0, -14))


@sfx("drone_servo", 2, -24)
def _(i):
    c = lp(T(SM + "Cable Coiler %d.wav" % (i + 1)), 6000)
    return mix((servo(0.55, 650 + 80 * i, 1350, 0.35), 0, 0), (crop(c, 0, 0.5), 0, -10))


@sfx("swing_pebble", 3, -18)
def _(i):
    sw = lp(T(OW + "Swish %d.wav" % (i + 1), -6), 3500)
    cl = T(R + "cloth%d.ogg" % (i + 1))
    return mix((sw, 0, 0), (whoosh(0.42, 160, 800, 1.2, 0.6, "brown"), 0, -4), (cl, 0, -14))


@sfx("impact_pebble", 3, -13, "outdoor", 0.14)
def _(i):
    p = T(K + "impactPunch_heavy_%s.ogg" % kn(i + 1), -5)
    m = lp(T(K + "impactMetal_heavy_%s.ogg" % kn(i), -4), 3000)
    deb = lp(T(F + "bfh1_rock_falling_0%d.ogg" % (i + 5)), 3500)
    return sat(mix((p, 0, 0), (m, 0, -8), (thump(105, 40, 0.3, 0.09, 0.3), 0, -3), (deb, 0.03, -15)), 1.4)


@sfx("swing_juno", 3, -18)
def _(i):
    ch = hp(T(WM + "keys_0%d.ogg" % (i + 4), -1), 900)
    wh = T(OW + "Whistle %d.wav" % (i + 1))
    return mix((wh, 0, -2), (crop(ch, 0, 0.35), 0, -6), (crackle(0.28, 200, 1800, 9000, 0.12), 0.02, -12))


@sfx("impact_juno", 3, -14, "room", 0.08)
def _(i):
    eb = T(W + "electrobolt_hit.ogg", jit(1))
    st = crop(T(W + "electrobolt_strong.ogg", 2 + jit(1)), 0, 0.3)
    p = T(K + "impactPunch_medium_%s.ogg" % kn(i))
    return mix((p, 0, 0), (eb, 0, -3), (fade(st, 0.001, 0.12), 0, -8), (crackle(0.2, 300, 1500, 9000, 0.07), 0, -6))


@sfx("swing_nyx", 4, -19)
def _(i):
    sw = T(OW + pick(["Classic Swish 1.wav", "Classic Swish 2.wav", "Classic Swish 3.wav", "Slash.wav"], i), 2 + jit(0.6))
    ring = hp(T(KN + pick(["Small Knife - Unsheath 1.wav", "Small Knife - Unsheath 2.wav"], i), 3), 2500)
    return mix((sw, 0, 0), (crop(ring, 0, 0.25), 0, -16))


@sfx("impact_nyx", 3, -16, "room", 0.06)
def _(i):
    sl = T(R + pick(["knifeSlice.ogg", "knifeSlice2.ogg"], i), jit(1))
    fl = lp(T(W + "blade_hitflsh%d.ogg" % (i + 1), -2), 6500)
    so = T(K + "impactSoft_medium_%s.ogg" % kn(i))
    return mix((sl, 0, 0), (fl, 0, -8), (so, 0, -7))


@sfx("swing_quill", 3, -19)
def _(i):
    sw = T(OW + "Swish %d.wav" % (i + 4), 1)
    dk = T(R + "drawKnife%d.ogg" % (i + 1), 1)
    return mix((sw, 0, 0), (dk, 0, -10))


@sfx("impact_quill", 3, -16, "room", 0.06)
def _(i):
    sl = T(R + pick(["knifeSlice2.ogg", "knifeSlice.ogg"], i), -1 + jit(1))
    p = T(K + "impactPunch_medium_%s.ogg" % kn(i + 2))
    wet = T(WS + "slime_%02d.ogg" % (i + 3))
    return mix((sl, 0, 0), (p, 0, -4), (crop(wet, 0, 0.25), 0, -14))


def _reload(parts):
    return mix(*[(fade(crop(T(p, s), 0, 0.45), 0.001, 0.12), o, g) for p, s, o, g in parts])


@sfx("reload_rifle", 2, -19, "room", 0.05)
def _(i):
    return _reload([(R + "metalClick.ogg", -2 + i, 0, -2), (R + "metalLatch.ogg", -1, 0.24, 0),
                    (SM + "Ratchet Muted %d.wav" % (i + 1), 0, 0.55, -6)])


@sfx("reload_launcher", 1, -17, "room", 0.06)
def _(i):
    return _reload([(WM + "metal_open_01.ogg", -2, 0, -3), (TB + "Good Thunk.wav", -2, 0.42, 0),
                    (R + "metalLatch.ogg", -3, 0.85, -2)])


@sfx("reload_pistol", 1, -19, "room", 0.05)
def _(i):
    return _reload([(R + "metalClick.ogg", 1, 0, -2), (TB + "Click 1.wav", 0, 0.35, 0), (SM + "Click Button 2.wav", -3, 0.6, -2)])


@sfx("reload_smg", 1, -19, "room", 0.05)
def _(i):
    return _reload([(R + "metalClick.ogg", 0, 0, -3), (SM + "Ratchet Harsh 1.wav", 1, 0.28, -4), (R + "metalLatch.ogg", 1, 0.62, 0)])


@sfx("dry_fire", 2, -21)
def _(i):
    return fade(crop(hp(T(SM + "Click Button %d.wav" % (i + 3), -2), 400), 0, 0.12), 0.0005, 0.05)


@sfx("hit_flesh", 4, -20, maxlen=0.35)
def _(i):
    p = hp(T(K + "impactPunch_medium_%s.ogg" % kn(i), jit(1.5)), 110)
    wet = T(WS + "slime_%02d.ogg" % (i + 6), 1)
    return mix((p, 0, 0), (crop(wet, 0, 0.2), 0, -12))


@sfx("hit_metal", 4, -21, maxlen=0.35)
def _(i):
    m = T(K + "impactMetal_light_%s.ogg" % kn(i), jit(1.5))
    pl = T(K + "impactPlate_light_%s.ogg" % kn(i + 1))
    return mix((m, 0, 0), (pl, 0, -6))


@sfx("explosion", 3, -13, "outdoor", 0.28)
def _(i):
    ex = T(pick([W + "gren_strong_explosion2.ogg", W + "rocket_strong_explosion.ogg", W + "gren_strong_explosion1.ogg"], i), -1 + jit(1))
    deb = lp(T(F + "bfh1_rock_falling_0%d.ogg" % (i + 1)), 4000)
    return mix((lowshelf(sat(ex, 1.4), 160, 3), 0, 0), (thump(75, 28, 0.7, 0.2, 0.2), 0, -4), (deb, 0.1, -13))


# =========================================================================== ABILITIES / HERO
@sfx("ab_rush", 1, -14, "outdoor", 0.15)
def _(i):
    steps = mix(*[(T(K + "footstep_concrete_%s.ogg" % kn(k % 5), -2), 0.09 * k, -4) for k in range(5)])
    grunt = lp(T(PL + "female/jump_1.ogg", -1), 5000)
    return mix((whoosh(0.7, 180, 1400, 1.3, 0.5), 0, 0), (thump(85, 38, 0.4, 0.1, 0.4), 0, -2), (steps, 0.02, -6), (grunt, 0, -13))


@sfx("ab_vial", 1, -15, "outdoor", 0.2)
def _(i):
    pop = T(PB + "Bottle Pop 1.wav")
    bang = lp(T(B + "bang_09.ogg", -1), 4000)
    gl = T(K + "impactGlass_light_001.ogg", 2)
    return mix((bang, 0, 0), (pop, 0, -4), (gl, 0.02, -10), (crack(0.04, 3000), 0, -8))


@sfx("ab_vial_break", 1, -16, "outdoor", 0.15)
def _(i):
    gl = T(K + "impactGlass_medium_000.ogg")
    sp = T(WS + "splash_04.ogg", 1)
    hiss = hp(T(S2 + "sfx100v2_air_01.ogg", -3), 1500)
    return mix((gl, 0, 0), (crop(sp, 0, 0.5), 0.01, -6), (fade(crop(hiss, 0, 1.6), 0.05, 0.8), 0.05, -9))


@sfx("ab_slam", 1, -11, "outdoor", 0.35)
def _(i):
    mi = T(K + "impactMining_002.ogg", -8)
    rk = lp(T(F + "bfh1_rock_breaking_02.ogg"), 5000)
    ex = lp(T(W + "gren_strong_explosion1.ogg", -4), 1500)
    return sat(mix((thump(70, 24, 0.9, 0.25, 0.6), 0, 0), (mi, 0, -2), (ex, 0, -5), (rk, 0.04, -9)), 1.5)


@sfx("ab_overload", 1, -13, "room", 0.12)
def _(i):
    st = T(W + "electrobolt_strong.ogg", -1)
    hum = T(EM + "NazdyNate - EM Room Noise 1.wav", 0, 0.2, 0.9)
    return mix((st, 0, 0), (crackle(0.85, 420, 1200, 10000, 0.35), 0, -2), (thump(60, 30, 0.5, 0.15, 0.4), 0, -5),
               (fade(hp(hum, 80), 0.05, 0.4) * 3, 0, -8))


@sfx("ab_heal", 1, -17, "hall", 0.28)
def _(i):
    bub = T(WS + "bubble_02.ogg")
    cap = T(PB + "Twist Cap 1.wav")
    bell = lp(T(K + "impactBell_heavy_001.ogg", -12), 1600)
    return mix((cap, 0, -2), (fade(crop(bub, 0, 0.6), 0.01, 0.2), 0.15, -4), (bell, 0.1, -8), (whoosh(0.8, 300, 900, 2.0, 0.5), 0.1, -16))


@sfx("ab_mark", 1, -17, "room", 0.08)
def _(i):
    return mix((T(R + "bookFlip1.ogg"), 0, -2), (T(KN + "Big Knife - Unsheath 1.wav"), 0.12, 0), (T(K + "impactGeneric_light_001.ogg", -3), 0.3, -6))


@sfx("ab_blade", 1, -16)
def _(i):
    return mix((T(OW + "Combo 1.wav", 1), 0, 0), (whoosh(0.4, 500, 3000, 1.6, 0.4), 0, -7), (crop(T(KN + "Big Knife - Scrape 2.wav", 3), 0, 0.3), 0.08, -12))


def radio_squelch(d=0.16, seed_off=0):
    x = bp(noise(d, "white"), 500, 3500, 2) * 3
    x = sat(x, 3.0) * env_ar(sec(d), 0.004, 0.05, 1.0)
    click = hp(noise(0.004), 2000) * 2
    return mix((click, 0, -6), (x, 0.002, -4), (click, d - 0.004, -9))


def radio_voice(d=1.2):
    """Garbled far-off radio speech: buzz through moving formants, band-limited."""
    n = sec(d)
    f0 = 135 + 25 * sine(2.3, d) + 10 * dsp.RNG.standard_normal()
    src = saw(f0, d) * 0.6 + noise(d) * 0.25
    out = np.zeros(n, np.float32)
    # syllable envelope
    syl = np.zeros(n, np.float32)
    pos = 0.05
    while pos < d - 0.12:
        L_ = dsp.RNG.uniform(0.07, 0.2)
        a, b = sec(pos), min(n, sec(pos + L_))
        syl[a:b] = np.hanning(b - a) * dsp.RNG.uniform(0.6, 1.0)
        pos += L_ + dsp.RNG.uniform(0.01, 0.09)
    for lo_, hi_ in ((500, 900), (1100, 1700), (2200, 2900)):
        fc = (lo_ + hi_) / 2 + (hi_ - lo_) / 2 * np.interp(np.arange(n), np.linspace(0, n, 12), dsp.RNG.uniform(-1, 1, 12))
        out += svf(src, fc, 5.0, "bp")
    out = bp(out * syl, 350, 3000, 3)
    out = sat(out * 4, 2.5)
    return out


@sfx("ab_drone", 1, -17, "room", 0.08)
def _(i):
    c = lp(T(SM + "Cable Coiler 2.wav"), 6000)
    return mix((radio_squelch(0.14), 0, -4), (servo(0.7, 520, 1500, 0.35), 0.1, 0), (crop(c, 0, 0.6), 0.1, -10))


@sfx("dash", 3, -19)
def _(i):
    sw = lp(T(OW + "Swish %d.wav" % (i + 1), -1 + jit(0.7)), 3500)
    cl = T(R + "cloth%d.ogg" % (i + 2))
    sc = lp(T(K + "footstep_concrete_%s.ogg" % kn(i + 1), -1), 4000)
    return mix((sw, 0, 0), (whoosh(0.28, 260, 1200, 1.4, 0.4), 0, -7), (cl, 0, -11), (sc, 0, -9))


@sfx("hurt_f", 3, -15)
def _(i):
    p = T(K + "impactPunch_heavy_%s.ogg" % kn(i + 2), -2)
    v = lp(T(PL + "female/pain%d.ogg" % (25 * (i + 1)), jit(0.5)), 5200)
    return mix((p, 0, 0), (T(K + "impactSoft_heavy_%s.ogg" % kn(i)), 0, -5), (v, 0.01, -9))


@sfx("hurt_m", 3, -15)
def _(i):
    p = T(K + "impactPunch_heavy_%s.ogg" % kn(i + 2), -2)
    v = lp(T(PL + "male/pain%d.ogg" % (25 * (i + 1)), jit(0.5)), 5200)
    return mix((p, 0, 0), (T(K + "impactSoft_heavy_%s.ogg" % kn(i)), 0, -5), (v, 0.01, -9))


@sfx("shield_block", 1, -16, "room", 0.1)
def _(i):
    return mix((T(K + "impactPlate_heavy_001.ogg"), 0, 0), (T(K + "impactMetal_heavy_002.ogg", -2), 0, -4), (lp(T(K + "impactBell_heavy_002.ogg", -3), 3000), 0, -14))


@sfx("death_f", 1, -14, "outdoor", 0.35)
def _(i):
    v = lp(T(PL + "female/death.ogg"), 5000)
    return mix((v, 0, -3), (thump(90, 35, 0.5, 0.15, 0.2), 0.35, -3), (T(F + "bfh1_falling_03.ogg", -2), 0.33, -6))


@sfx("death_m", 1, -14, "outdoor", 0.35)
def _(i):
    v = lp(T(PL + "male/death.ogg"), 5000)
    return mix((v, 0, -3), (thump(90, 35, 0.5, 0.15, 0.2), 0.35, -3), (T(F + "bfh1_falling_03.ogg", -2), 0.33, -6))


@sfx("lowhp_loop", 1, -16)
def _(i):
    return heartbeat(68, 60 / 68)


@sfx("level_up", 1, -15, "hall", 0.3)
def _(i):
    bell = T(K + "impactBell_heavy_003.ogg", -5)
    gl = T(K + "impactGlass_light_002.ogg", -1)
    rise = whoosh(0.7, 200, 2600, 2.2, 0.92)
    return mix((rise, 0, -8), (bell, 0.62, 0), (gl, 0.64, -10), (thump(110, 50, 0.3, 0.08, 0.1), 0.62, -8))


@sfx("card_show", 1, -18, "room", 0.05)
def _(i):
    return mix(*[(T(R + "bookPlace%d.ogg" % (k + 1), 1), 0.07 * k, -2) for k in range(3)], (T(R + "bookFlip2.ogg"), 0, -6))


@sfx("card_pick", 1, -16, "room", 0.06)
def _(i):
    return mix((T(R + "bookPlace1.ogg"), 0, -2), (T(R + "metalLatch.ogg"), 0.05, 0), (T(TB + "Good Thunk.wav"), 0.08, -4))


@sfx("reroll", 1, -18, "room", 0.05)
def _(i):
    return mix((T(R + "bookFlip3.ogg"), 0, 0), (fade(crop(T(SM + "Ratchet Muted 3.wav"), 0, 0.4), 0.001, 0.12), 0.05, -6))


# =========================================================================== LOOT
@sfx("pick_scrap", 4, -23, maxlen=0.3)
def _(i):
    c = T(R + pick(["handleCoins.ogg", "handleCoins2.ogg"], i), 2 + i * 0.7, 0, 0.25)
    m = T(K + "impactMetal_light_%s.ogg" % kn(i), 5)
    return mix((fade(c, 0.001, 0.08), 0, 0), (m, 0, -12))


@sfx("pick_xp", 3, -26, maxlen=0.22)
def _(i):
    g = T(K + "impactGlass_light_%s.ogg" % kn(i + 1), 3 + i)
    sand = hp(noise(0.08), 3000) * env_exp(sec(0.08), 0.02)
    return mix((lp(g, 9000), 0, 0), (sand, 0, -16))


@sfx("pick_tonic", 2, -18)
def _(i):
    sh = T(PB + "Multivitamin - Shake %d.wav" % (i + 1), 0, 0, 0.35)
    return mix((fade(sh, 0.005, 0.12), 0, 0), (T(PB + "Cap Click %d.wav" % (i + 1)), 0.25, -2))


@sfx("pick_common", 1, -19)
def _(i):
    return mix((T(R + "handleSmallLeather.ogg"), 0, 0), (T(R + "metalClick.ogg", 2), 0.06, -6))


@sfx("pick_rare", 1, -17, "room", 0.08)
def _(i):
    return mix((T(R + "beltHandle1.ogg"), 0, 0), (T(K + "impactPlate_light_002.ogg", 2), 0.05, -3), (T(R + "handleCoins.ogg", 3, 0, 0.3), 0.04, -8))


@sfx("pick_epic", 1, -16, "hall", 0.2)
def _(i):
    return mix((T(R + "metalLatch.ogg"), 0, -2), (T(K + "impactBell_heavy_000.ogg", 4), 0.04, 0), (T(K + "impactGlass_light_003.ogg", 1), 0.05, -10))


@sfx("pick_legendary", 1, -14, "hall", 0.35)
def _(i):
    bell = T(K + "impactBell_heavy_002.ogg", -3)
    hi = T(K + "impactBell_heavy_000.ogg", 7)
    rise = whoosh(0.9, 150, 3000, 2.2, 0.9)
    return mix((rise, 0, -9), (bell, 0.82, 0), (hi, 0.84, -9), (thump(90, 40, 0.5, 0.15, 0.1), 0.82, -6))


@sfx("pick_ammo", 1, -18)
def _(i):
    return mix((fade(crop(T(SC + "Small Can - Tap on Tile.wav", -2), 0, 0.22), 0.0005, 0.08), 0, 0), (T(R + "metalLatch.ogg", 1), 0.08, -2))


@sfx("pick_lore", 1, -18)
def _(i):
    return mix((T(R + "bookOpen.ogg"), 0, 0), (T(R + "bookFlip2.ogg"), 0.15, -5))


@sfx("pack_full", 1, -17)
def _(i):
    return mix((T(R + "dropLeather.ogg", -2), 0, 0), (lp(T(TB + "Big Thump.wav", -2), 900), 0.02, -2), (crop(T(SM + "Click Button 1.wav", -4), 0, 0.1), 0.18, -10))


@sfx("crate_land", 1, -13, "outdoor", 0.25)
def _(i):
    return mix((T(K + "impactWood_heavy_001.ogg", -3), 0, 0), (thump(80, 30, 0.6, 0.18, 0.4), 0, -2), (T(F + "bfh1_wood_breaking_02.ogg", -2), 0.02, -8),
               (lp(T(F + "bfh1_rock_falling_04.ogg"), 3500), 0.1, -14))


@sfx("crate_open", 1, -17, "room", 0.08)
def _(i):
    return mix((T(WM + "lock_open_01.ogg"), 0, 0), (T(R + "doorOpen_1.ogg", -2), 0.15, -4), (T(TB + "Rummage 1.wav", 0, 0, 0.6), 0.45, -8))


# =========================================================================== EXTRACT / RUN FLOW
@sfx("radio_blip", 3, -19)
def _(i):
    return radio_squelch(0.12 + 0.04 * i)


@sfx("radio_chatter", 3, -20)
def _(i):
    d = 1.1 + 0.3 * i
    return mix((radio_squelch(0.1), 0, -4), (radio_voice(d), 0.1, 0), (bp(noise(d + 0.1), 600, 4000) * 0.25, 0.05, -10), (radio_squelch(0.12), d + 0.12, -6))


def far_horn(d=2.6, f=98.0):
    s = saw(f, d) + saw(f * 1.498, d) * 0.6 + saw(f * 2.0, d) * 0.3
    s = lp(s, 700, 2) * env_ar(sec(d), 0.6, 1.0, 1.5)
    vib = 1 + 0.02 * sine(5.0, d)
    return (s * vib * 0.3).astype(np.float32)


@sfx("ext_ping", 1, -18, "outdoor", 0.25)
def _(i):
    return mix((radio_squelch(0.12), 0, -2), (lp(T(K + "impactBell_heavy_001.ogg", 3), 4000), 0.12, -4))


@sfx("ext_open", 1, -14, "hall", 0.3)
def _(i):
    door = T(MV + "door_start.ogg", -3)
    return mix((radio_squelch(0.12), 0, -4), (door, 0.05, -2), (far_horn(2.6, 98), 0.1, 0), (thump(70, 35, 0.6, 0.2, 0.2), 0.05, -6))


@sfx("ext_close", 1, -14, "hangar", 0.3)
def _(i):
    return mix((T(MV + "door_stop.ogg", -3), 0, -2), (T(WM + "metal_slam_01.ogg", -3), 0.02, 0), (thump(75, 30, 0.6, 0.18, 0.3), 0.02, -3))


@sfx("ext_last", 1, -13, "outdoor", 0.4)
def _(i):
    al = lp(T(L + "alarm_01.ogg", -4), 2600)
    al = mix(al, (al, len(al) / SR, -2))
    return mix((al, 0, -3), (far_horn(2.8, 73.4), 0, 0), (radio_squelch(0.14), 0, -6))


def wind(d, lo=180, hi=1200, gust=0.5, seed_=0, color="pink"):
    dsp.seed(5000 + seed_)
    x = noise(d, color)
    n = sec(d)
    k = max(4, int(d * 1.5))
    fc = np.exp(np.interp(np.arange(n), np.linspace(0, n, k), dsp.RNG.uniform(np.log(lo), np.log(hi), k)))
    y = svf(x, fc, 0.9, "bp")
    g = np.interp(np.arange(n), np.linspace(0, n, k), dsp.RNG.uniform(1 - gust, 1.0, k))
    return (y * g * 1.6).astype(np.float32)


@sfx("storm", 1, -11, "outdoor", 0.3)
def _(i):
    d = 4.5
    w_ = wind(d, 120, 1500, 0.3, 3, "brown") * env_ar(sec(d), 1.2, 1.8, 1.2) * 4
    th = T(S2 + "sfx100v2_thunder_01.ogg", -3)
    return mix((w_, 0, 0), (th, 0.2, -2), (thump(55, 28, 1.2, 0.4, 0.1), 0.2, -4))


@sfx("pad_channel", 1, -17, "outdoor", 0.15)
def _(i):
    d = 3.0
    el = T(MV + "elevator_move.ogg", 0)
    el = mix(el, (el, len(el) / SR - 0.05, 0))[: sec(d)]
    rise = sweep_bp(noise(d, "pink"), 200, 2400, 2.0, 1.4) * np.linspace(0.2, 1.0, sec(d)) ** 2 * 2
    return mix((servo(d, 280, 950, 0.25), 0, -2), (fade(el, 0.1, 0.3), 0, -6), (rise, 0, -6), (T(R + "metalLatch.ogg", -3), d - 0.05, 0))


@sfx("pad_cancel", 1, -18)
def _(i):
    return mix((servo(0.45, 900, 250, 0.3), 0, 0), (crop(T(SM + "Click Button 4.wav", -3), 0, 0.1), 0, -4))


def cello(note, kind="Sforzando", take=1):
    """Recorded cello (Ben Burnes, CC0) shifted from the nearest sampled pitch."""
    bases = {36: "C2", 43: "G2", 50: "D3", 57: "A3"}
    b = min(bases, key=lambda m: abs(m - note))
    return T(CE + "%s - %s %d.wav" % (bases[b], kind, take), note - b, thr=-60)


@sfx("ext_success", 1, -13, "hall", 0.35)
def _(i):
    return mix((T(MV + "door_start.ogg", -4), 0, -4), (thump(70, 32, 0.8, 0.25, 0.2), 0, -4), (cello(50, "Sforzando", 1), 0.05, 0),
               (cello(38, "Sforzando", 2), 0.05, -2), (cello(57, "Sustain", 2)[:sec(2.5)] * env_ar(sec(2.5), 0.3, 1.5), 0.3, -10),
               (lp(T(K + "impactBell_heavy_001.ogg", -5), 2500), 0.05, -8))


@sfx("run_wipe", 1, -13, "hall", 0.4)
def _(i):
    w_ = wind(3.5, 100, 700, 0.3, 9, "brown") * env_ar(sec(3.5), 0.3, 2.5) * 4
    return mix((thump(55, 25, 1.2, 0.4, 0.2), 0, 0), (lp(cello(37, "Sforzando", 1), 1500), 0.0, -2), (cello(44, "Sforzando", 2), 0.05, -6), (w_, 0, -6))


@sfx("threat_up", 1, -14, "hall", 0.25)
def _(i):
    bell = lp(T(K + "impactBell_heavy_003.ogg", -14), 1200)
    rum = lp(noise(2.0, "brown"), 200) * env_ar(sec(2.0), 0.4, 1.2) * 3
    return mix((bell, 0, 0), (thump(52, 28, 1.0, 0.3, 0.1), 0, -3), (rum, 0, -6))


@sfx("elite_spawn", 1, -12, "outdoor", 0.3)
def _(i):
    r = T(C2 + "roar_04.ogg", -5)
    sc = lp(T(KN + "Unpleasant Scraping 1.wav", -7), 3000)
    return sat(mix((r, 0, 0), (crop(sc, 0, 1.2), 0, -8), (thump(60, 28, 0.8, 0.25, 0.1), 0, -4)), 1.4)


@sfx("boss_roar_plague", 1, -11, "hall", 0.3)
def _(i):
    a = T(C1 + "roar_01.ogg", -7)
    b = T(C1 + "roar_02.ogg", -3)
    m = T(C1 + "monster_03.ogg", -9)
    return sat(lowshelf(mix((a, 0, 0), (b, 0.05, -3), (m, 0.1, -8), (thump(50, 24, 1.2, 0.4, 0.1), 0, -5)), 140, 4), 1.6)


@sfx("boss_roar_machine", 1, -11, "hangar", 0.3)
def _(i):
    eng = fade(crop(T(L + "machine_08.ogg", -6), 0, 2.2), 0.01, 0.8)
    g = lp(T(C1 + "roar_03.ogg", -10), 1200)
    return sat(mix((eng, 0, -3), (servo(1.6, 140, 55, 0.6), 0, 0), (g, 0.1, -2), (T(WM + "metal_slam_01.ogg", -5), 0.0, -4),
                   (thump(48, 24, 1.2, 0.4, 0.2), 0, -4)), 1.5)


# =========================================================================== MOBS
@sfx("plague_attack", 4, -21, maxlen=0.7)
def _(i):
    return T(C2 + "attack_0%d.ogg" % (i + 1), -2 + jit(1))


@sfx("plague_hurt", 4, -23, maxlen=0.5)
def _(i):
    return lp(T(C1 + "hurt_0%d.ogg" % (i + 1), -2 + jit(1.5)), 6000)


@sfx("plague_die", 4, -19, "outdoor", 0.12, 0.9)
def _(i):
    v = T(C2 + "die_0%d.ogg" % (i + 1), -2 + jit(1))
    sp = T(WS + "slime_%02d.ogg" % (i + 10))
    return mix((v, 0, 0), (crop(sp, 0, 0.35), 0.05, -8), (T(K + "impactSoft_heavy_%s.ogg" % kn(i)), 0.03, -8))


@sfx("plague_spit", 3, -22)
def _(i):
    return T(C1 + "spit_0%d.ogg" % (i + 1), -2)


@sfx("machine_attack", 3, -21)
def _(i):
    return mix((servo(0.22, 1200 + 200 * i, 2400, 0.4), 0, -2), (T(K + "impactMetal_medium_%s.ogg" % kn(i)), 0.12, 0),
               (T(SM + "Spring Loaded Blade %d.wav" % (i + 1)), 0.08, -6))


@sfx("machine_hurt", 4, -22, maxlen=0.4)
def _(i):
    return mix((T(K + "impactMetal_light_%s.ogg" % kn(i + 1), -2 + jit(1)), 0, 0), (crackle(0.12, 200, 2000, 8000, 0.04), 0, -9))


@sfx("machine_die", 3, -17, "outdoor", 0.15)
def _(i):
    return mix((T(F + "bfh1_metal_falling_0%d.ogg" % (i + 1), -1), 0, 0), (crackle(0.35, 300, 1500, 9000, 0.12), 0, -5),
               (servo(0.5, 1600, 180, 0.3), 0, -10), (thump(90, 38, 0.3, 0.08, 0.3), 0, -6))


@sfx("machine_shot", 3, -22, "outdoor", 0.1)
def _(i):
    mg = lp(T(W + "machinegun_fire.ogg", -4 + i, 0, 0.18), 5000)
    return mix((fade(mg, 0.0005, 0.05), 0, 0), (servo(0.06, 2500, 2600, 0.5), 0, -14))


@sfx("raider_attack", 3, -20)
def _(i):
    v = lp(T(PL + "male/jump_%d.ogg" % (i % 2 + 1), -1 - i), 5000)
    return mix((v, 0, 0), (T(OW + "Swish %d.wav" % (i + 2), -2), 0, -6))


@sfx("raider_hurt", 3, -22, maxlen=0.6)
def _(i):
    return mix((lp(T(PL + "male/pain%d.ogg" % (25 * (i + 1)), -2), 5000), 0, 0), (T(K + "impactPunch_medium_%s.ogg" % kn(i + 1)), 0, -6))


@sfx("raider_die", 3, -19, "outdoor", 0.15)
def _(i):
    v = lp(T(PL + pick(["male/death.ogg", "bobot/death.ogg", "male/falldeath.ogg"], i), -1.5), 5000)
    return mix((v, 0, 0), (T(F + "bfh1_falling_0%d.ogg" % (i + 1), -2), 0.25, -7))


@sfx("raider_shot", 3, -20, "outdoor", 0.2)
def _(i):
    sh = lp(hp(T(B + "shot_0%d.ogg" % (i + 1), -2), 150), 6000)
    return mix((crack(0.03, 3500), 0, -9), (sh, 0, 0))


@sfx("brute_slam", 2, -16, "outdoor", 0.2)
def _(i):
    return mix((thump(75, 30, 0.5, 0.15, 0.5), 0, 0), (T(K + "impactMining_00%d.ogg" % i, -6), 0, -3), (lp(T(F + "bfh1_rock_falling_0%d.ogg" % (i + 6)), 3000), 0.04, -12))


# =========================================================================== PETS
@sfx("noel_bark", 3, -19, "outdoor", 0.15, 0.6)
def _(i):
    b = T(C1 + "barking_0%d.ogg" % (i % 2 + 1), -1 - 0.5 * i)
    return fade(crop(b, 0.0 if i < 2 else 0.25, 0.45), 0.001, 0.08)


@sfx("noel_growl", 2, -19, maxlen=1.3)
def _(i):
    return fade(T(BA + pick(["Growl 1.wav", "Growl 2.wav"], i), -1), 0.05, 0.3)


@sfx("bentley_yip", 3, -20, "outdoor", 0.15, 0.4)
def _(i):
    b = T(C1 + "barking_0%d.ogg" % (i % 2 + 1), 5 + i)
    return fade(crop(b, 0.0, 0.28), 0.001, 0.06)


@sfx("lillie_charge", 2, -18)
def _(i):
    hooves = mix(*[(T(K + "footstep_wood_%s.ogg" % kn(k % 5), 2), 0.075 * k, -2 - k * 0.5) for k in range(7)])
    return mix((hooves, 0, 0), (whoosh(0.5, 300, 1500, 1.3, 0.7), 0.05, -8), (lp(T(C1 + "grunt_0%d.ogg" % (i + 1), 3), 5000), 0, -8))


@sfx("lillie_hit", 2, -15, "outdoor", 0.15)
def _(i):
    return mix((T(K + "impactPunch_heavy_%s.ogg" % kn(i + 3), -3), 0, 0), (T(K + "impactWood_heavy_00%d.ogg" % (i + 2), -2), 0, -5), (thump(90, 35, 0.4, 0.1, 0.3), 0, -3))


@sfx("mech_servo", 3, -22)
def _(i):
    return mix((servo(0.4, 500 + 150 * i, 1100 + 200 * i, 0.4), 0, 0), (T(SM + "Ratchet Muted %d.wav" % (i + 2)), 0.05, -8))


@sfx("pet_gift", 1, -19)
def _(i):
    return mix((T(R + "dropLeather.ogg"), 0, 0), (T(K + "impactGeneric_light_002.ogg"), 0.05, -4))


# =========================================================================== WORLD / EVENTS
@sfx("mine_drop", 1, -22)
def _(i):
    return mix((fade(crop(T(SC + "Small Can - Tap on Tile.wav", -3), 0, 0.22), 0.0005, 0.08), 0, 0), (crop(T(SM + "Click Button 2.wav", -2), 0, 0.1), 0.05, -6))


@sfx("mine_boom", 2, -15, "outdoor", 0.2)
def _(i):
    ex = lp(T(W + "gren_strong_explosion%d.ogg" % (i + 1), 1), 4000)
    sp = T(WS + "splash_0%d.ogg" % (i + 6))
    return mix((ex, 0, 0), (crop(sp, 0, 0.5), 0.01, -6))


@sfx("break_wood", 2, -17, "outdoor", 0.12)
def _(i):
    return T(F + "bfh1_wood_breaking_0%d.ogg" % (i + 1))


@sfx("break_metal", 2, -17, "outdoor", 0.12)
def _(i):
    return mix((T(F + "bfh1_metal_hit_0%d.ogg" % (i + 1)), 0, 0), (T(F + "bfh1_metal_falling_0%d.ogg" % (i + 3)), 0.06, -4))


@sfx("event_start", 1, -16, "outdoor", 0.2)
def _(i):
    return mix((radio_squelch(0.12), 0, -2), (radio_voice(0.9), 0.12, -2), (lp(T(K + "impactBell_heavy_000.ogg", -6), 2500), 0.05, -6))


@sfx("supply_crash", 1, -12, "outdoor", 0.3)
def _(i):
    fall = whoosh(1.1, 2400, 250, 1.5, 0.85)
    land = mix((T(K + "impactWood_heavy_001.ogg", -4), 0, 0), (thump(70, 26, 0.8, 0.25, 0.5), 0, -1),
               (lp(T(W + "gren_strong_explosion2.ogg", -3), 2500), 0, -6), (T(F + "bfh1_wood_breaking_03.ogg", -2), 0.02, -8))
    return mix((fall, 0, -6), (land, 1.05, 0))


# =========================================================================== UI (tactile, mechanical)
@sfx("ui_tap", 3, -22, maxlen=0.25)
def _(i):
    c = fade(crop(hp(T(SM + "Click Button %d.wav" % (i + 1), jit(0.5)), 250), 0, 0.11), 0.0005, 0.05)
    return mix((c, 0, 0), (thump(240 + 20 * i, 130, 0.06, 0.015, 0.0), 0, -9), (T(K + "impactMetal_light_%s.ogg" % kn(i + 2), 6), 0, -22))


@sfx("ui_back", 2, -22, maxlen=0.3)
def _(i):
    c = fade(crop(hp(T(TB + "Flashlight Clicky %d.wav" % (i + 1), -2), 200), 0, 0.11), 0.0005, 0.05)
    return mix((c, 0, 0), (thump(200, 110, 0.07, 0.02, 0.0), 0, -8))


@sfx("ui_tab", 2, -23, maxlen=0.25)
def _(i):
    return fade(crop(hp(T(R + "metalClick.ogg", 3 + 2 * i), 300), 0, 0.12), 0.0005, 0.05)


@sfx("ui_toggle", 2, -22, maxlen=0.3)
def _(i):
    return fade(crop(hp(T(TB + "Click %d.wav" % (i + 1)), 200), 0, 0.15), 0.0005, 0.06)


@sfx("ui_open", 1, -21, maxlen=0.7)
def _(i):
    return mix((fade(crop(T(TB + "Drawer Move.wav"), 0, 0.5), 0.01, 0.2), 0, 0), (T(R + "metalLatch.ogg", 2), 0, -8))


@sfx("ui_purchase", 1, -17, "room", 0.1)
def _(i):
    return mix((T(R + "handleCoins.ogg"), 0, -2), (T(TB + "Good Thunk.wav"), 0.12, 0), (fade(crop(T(SM + "Ratchet Harsh 2.wav"), 0, 0.45), 0.001, 0.15), 0.3, -5))


@sfx("ui_denied", 1, -19)
def _(i):
    return mix((lp(T(TB + "Big Thump.wav", -3), 800), 0, 0), (lp(T(W + "weapon_noammo.ogg", -4), 3000), 0, -8))


@sfx("ui_equip", 1, -19, "room", 0.06)
def _(i):
    return mix((T(R + "beltHandle1.ogg"), 0, 0), (T(R + "metalLatch.ogg"), 0.1, -3))


# =========================================================================== build
def render(name, cfg, i):
    dsp.seed(zlib.crc32(name.encode()) % 100000 + i * 7919)
    x = cfg["fn"](i)
    x = to_mono(x) if x.ndim == 2 else x
    x = hp(x, 28)
    if cfg["space"]:
        x = to_mono(reverb(x, cfg["space"], cfg["wet"]))
    if not name.endswith("_loop"):
        x = trim(x, -58, 0.03, -40)
    if cfg["maxlen"]:
        x = fade(x[: sec(cfg["maxlen"])], 0.0005, min(0.08, cfg["maxlen"] * 0.3))
    elif not name.endswith("_loop"):
        x = fade(x, 0.0005, 0.03)
    return active_rms_norm(x, cfg["level"], -1.0)


def main():
    out = sys.argv[1]
    only = sys.argv[2] if len(sys.argv) > 2 else ""
    os.makedirs(out, exist_ok=True)
    total = 0
    for name, cfg in RECIPES.items():
        if only and not name.startswith(only):
            continue
        for i in range(cfg["n"]):
            x = render(name, cfg, i)
            p = os.path.join(out, "%s_%d.ogg" % (name, i + 1))
            write_ogg(p, x, q=5)
            total += os.path.getsize(p)
        print("ok", name, cfg["n"], flush=True)
    print("SFX bytes", total)


if __name__ == "__main__":
    main()
