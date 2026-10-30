"""Wanderer metal soundtrack, part 2: per-act run sets + Greed intensity layers.

Usage (same CC0 sample libraries as build_metal.py):
    WANDERER_METAL_SRC=/path/to/sfz-clones python3 -I build_metal_acts.py OUT_DIR [track ...]

Acts (zone tiers):  I = Haze/Drift/Smog (the original 160 BPM set in build_metal.py),
                    II = Pall/Blight/Shroud, III = Choke/Blackout/Deadfall/Dustfall.
Every act has explore / combat / boss loops on one tempo, length and chord map so the game
crossfades them in lockstep, plus a "greed" layer that plays ON TOP of whichever loop leads,
rising with Greed and threat: doubled harmony rhythm, galloping double kick, china hits and
lead fills. Layers are mastered quieter than the loops so they add weight, not volume.
Every riff, progression and melody here is composed for this game.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa
import build_metal as bm  # noqa
from build_metal import Song, lanes, master, lufs, true_peak_db, SR, write_ogg  # noqa

# ---------------------------------------------------------------- Act I greed layer
def greed_a1():
    s = Song(bm.RUN_BPM, 72)
    for b in range(72):
        r1, r2 = bm._roots(b)
        sec = b // 16 if b < 64 else 4
        # octave chug doubling (L2/R2) a fourth-free harmony: root + octave
        if r1 != r2:
            s.riff(b, " ".join(["%do" % r1] * 8 + ["%do" % r2] * 8), sides=("L2", "R2"), bass=False)
        else:
            s.riff(b, " ".join(["%do" % r1] * 16), sides=("L2", "R2"), bass=False, layer="mf")
        d = dict(kick="xxxxxxxxxxxxxxxx" if sec != 2 else "x.xxx.xxx.xxx.xx")
        if b % 2 == 0:
            d["china"] = "X.......X......."
        s.drums(b, d)
        if b % 8 == 6:
            s.lead_line(b, [(None, 2), (76, 0.5), (79, 0.5), (81, 0.5), (83, 0.5), (84, 2, 0), (83, 1), (81, 1),
                            (79, 4, 1)])
    return s.mix(1.15, 0.08)


# ---------------------------------------------------------------- Act II: galloping, 176 BPM
A2_BPM = 176
A2_BARS = 64
A2_MAP = ([0, 0, 0, 0, 5, 5, 3, 2] * 2 +
          [7, 7, 8, 8, 5, 5, 3, 3] * 2 +
          [0] * 16 +
          [3, 5, 7, 8, 10, 8, 7, 5, 0, 0, 0, 0, 3, 2, 1, 0])
GALLOP = "%dm:2 %dm %dm"


def _gallop_bar(r, accent=None):
    toks = []
    for q in range(4):
        if accent is not None and q == 3:
            toks.append("%dp:4" % accent)
        else:
            toks.append(GALLOP % (r, r, r))
    return " ".join(toks)


def a2_explore():
    s = Song(A2_BPM, A2_BARS)
    for b in range(A2_BARS):
        r = A2_MAP[b]
        sec = b // 16
        if sec == 2 and b % 4 < 2:
            s.riff(b, "%dp:8 . %dm %dm %dm . %dm %dm %dm" % ((r,) * 7))
            s.drums(b, lanes(ride="x.x.x.x.x.x.x.x.", kick="x.......x......."))
            continue
        s.riff(b, "%dp:4 %dm %dm . %dm %dm %dm %dp:2 %dm %dm . %dm" % ((r,) * 10))
        d = dict(kick="x.....x.x.......", snare="........X.......", hat="x.x.x.x.x.x.x.x.")
        if b % 8 == 0:
            d["crash"] = "X..............."
        if b % 8 == 7:
            d["snare"] = "........X...x.x."
        s.drums(b, d)
    return s.mix(1.0, 0.12)


def a2_combat():
    s = Song(A2_BPM, A2_BARS)
    s.quad = True
    for b in range(A2_BARS):
        r = A2_MAP[b]
        sec = b // 16
        if sec == 2:
            riff = ("0m:2 0m 0m 0m:2 0m 0m 1M:4 0m:2 0m 0m" if b % 2 == 0 else
                    "0m:2 0m 0m 0m:2 0m 0m 5M:2 6M:2 7M:4")
            s.riff(b, riff, sides=("L", "R", "L2", "R2"))
            s.drums(b, dict(kick="x.xxx.xxx.xxx.xx", snare="....X.......X...",
                            china="X.......X......." if b % 2 else "X..............."))
            continue
        nxt = A2_MAP[(b + 1) % A2_BARS]
        s.riff(b, _gallop_bar(r, nxt if b % 4 == 3 and nxt != r else None), sides=("L", "R", "L2", "R2"))
        d = dict(kick="x.xxx.xxx.xxx.xx", snare="....X.......X...", hat="x.x.x.x.x.x.x.x.")
        if b % 4 == 0:
            d["crash"] = "X..............."
        if b % 8 == 7:
            d["snare"] = "....X...X.x.XxXx"
            d.pop("hat")
            d["t2"] = "..........x....."
            d["t3"] = "............x..."
        s.drums(b, d)
    return s.mix(1.12, 0.10)


def a2_boss():
    s = Song(A2_BPM, A2_BARS)
    for b in range(A2_BARS):
        r = A2_MAP[b]
        sec = b // 16
        tr = " ".join(["%dm" % r] * 6 + ["%dm" % (r + 1)] * 2 + ["%dm" % r] * 4 + ["%dm" % (r + 6)] * 2 + ["%dm" % (r + 5)] * 2)
        s.riff(b, tr, sides=("L", "R"))
        s.riff(b, "%dp:8 %dp:8" % (r, r + 1) if b % 2 else "%dp:16" % r, sides=("L2", "R2"), bass=False)
        d = dict(kick="xxxxxxxxxxxxxxxx", snare="....X.......X...", crash="X.......X.......")
        if sec == 2:
            d["snare"] = "X.X.X.X.X.X.X.X."
            d["china"] = "X...X...X...X..."
            d.pop("crash")
        if b % 8 == 7:
            d["snare"] = "X.X.X.XXXXXXXXXX"
        s.drums(b, d)
        if sec in (1, 3) and b % 8 == 0:
            s.lead_line(b, [(76, 1), (79, 1), (81, 2), (82, 2), (81, 1), (79, 1), (76, 4), (74, 2), (76, 6, 0),
                            (None, 2), (79, 2), (82, 2), (84, 4), (83, 8, -1)])
    return s.mix(1.25, 0.10, lead_db=-2.0)


def greed_a2():
    s = Song(A2_BPM, A2_BARS)
    for b in range(A2_BARS):
        r = A2_MAP[b]
        s.riff(b, " ".join(["%do:2 %do %do" % (r, r, r)] * 4), sides=("L2", "R2"), bass=False, layer="mf")
        d = dict(kick="xxxxxxxxxxxxxxxx")
        if b % 2 == 0:
            d["china"] = "X...X...X...X..."
        s.drums(b, d)
        if b % 8 == 4:
            s.lead_line(b, [(81, 0.5), (79, 0.5), (76, 0.5), (79, 0.5), (81, 0.5), (84, 0.5), (86, 1), (88, 4, 1),
                            (86, 2), (84, 2), (None, 4)])
    return s.mix(1.15, 0.08)


# ---------------------------------------------------------------- Act III: thrash, 192 BPM
A3_BPM = 192
A3_BARS = 64
A3_MAP = ([0, 0, 1, 0, 0, 0, 6, 5] * 2 +
          [3, 3, 5, 5, 6, 6, 5, 3] * 2 +
          [0] * 16 +
          [8, 7, 6, 5, 8, 7, 6, 5, 0, 1, 0, 1, 6, 5, 3, 1])


def a3_explore():
    s = Song(A3_BPM, A3_BARS)
    for b in range(A3_BARS):
        r = A3_MAP[b]
        # half-time menace: ringing chord, then a chromatic palm-mute crawl
        s.riff(b, "%dp:6 %dm %dm %dm:2 %dm:2 %dm %dm %dm:2" % (r, r, r + 1, r, r + 1, r, r, r))
        d = dict(kick="x.......x.x.....", snare="........X.......", ride="x...x...x...x...")
        if b % 8 == 0:
            d["crash"] = "X..............."
        s.drums(b, d)
    return s.mix(1.0, 0.12)


def a3_combat():
    s = Song(A3_BPM, A3_BARS)
    s.quad = True
    for b in range(A3_BARS):
        r = A3_MAP[b]
        sec = b // 16
        if sec == 2:
            # mosh breakdown
            s.riff(b, "0M:4 0m 0m 0m . 0M:4 6M:2 5M:2", sides=("L", "R", "L2", "R2"))
            s.drums(b, dict(kick="x...x.x.x...x.x.", snare="....X.......X...", china="X...X...X...X..."))
            continue
        # 16th tremolo thrash with a chromatic pickup, skank beat
        tr = " ".join(["%dm" % r] * 12 + ["%dm" % (r + 1)] * 2 + ["%dm" % (r + 3)] * 2) if b % 2 else \
            " ".join(["%dm" % r] * 16)
        s.riff(b, tr, sides=("L", "R", "L2", "R2"))
        d = dict(kick="x.x.x.x.x.x.x.x.", snare="..X...X...X...X.", hat="x.x.x.x.x.x.x.x.")
        if b % 4 == 0:
            d["crash"] = "X..............."
        if b % 8 == 7:
            d["snare"] = "..X...X...XxXxXx"
            d["t3"] = "..............x."
        s.drums(b, d)
    return s.mix(1.15, 0.09)


def a3_boss():
    s = Song(A3_BPM, A3_BARS)
    for b in range(A3_BARS):
        r = A3_MAP[b]
        sec = b // 16
        s.riff(b, " ".join(["%dm" % r] * 8 + ["%dM:2" % (r + 6), "%dm" % r, "%dm" % r, "%dM:2" % (r + 5), "%dm" % r, "%dm" % r]),
               sides=("L", "R"))
        s.riff(b, "%dp:16" % r if b % 2 == 0 else "%dp:8 %dp:8" % (r + 6, r + 5), sides=("L2", "R2"), bass=False)
        d = dict(kick="xxxxxxxxxxxxxxxx", snare="X...X...X...X...", china="X.X.X.X.X.X.X.X." if sec == 2 else "X.......X.......")
        if b % 8 == 7:
            d["snare"] = "XXXXXXXXXXXXXXXX"
        s.drums(b, d)
        if sec in (0, 3) and b % 8 == 4:
            s.lead_line(b, [(88, 0.5), (87, 0.5), (86, 0.5), (85, 0.5), (84, 0.5), (83, 0.5), (82, 0.5), (81, 0.5),
                            (80, 4, 1), (None, 1), (76, 1), (82, 2), (81, 6, -1)])
    return s.mix(1.28, 0.10, lead_db=-2.0)


def greed_a3():
    s = Song(A3_BPM, A3_BARS)
    for b in range(A3_BARS):
        r = A3_MAP[b]
        s.riff(b, " ".join(["%do" % (r + 12 if r < 3 else r)] * 16), sides=("L2", "R2"), bass=False, layer="mf")
        d = dict(kick="xxxxxxxxxxxxxxxx", china="X.......X.......")
        s.drums(b, d)
        if b % 8 == 2:
            s.lead_line(b, [(None, 1), (83, 0.25), (84, 0.25), (83, 0.25), (84, 0.25), (83, 0.25), (84, 0.25), (83, 0.25),
                            (84, 0.25), (86, 2, 1), (88, 4, 0), (None, 4)])
    return s.mix(1.18, 0.08)


# target LUFS: loops like the act I set (-14), layers sit under them (-19)
TRACKS = {
    "mus_greed_a1": (greed_a1, -19.0),
    "mus_a2_explore": (a2_explore, -14.0),
    "mus_a2_combat": (a2_combat, -14.0),
    "mus_a2_boss": (a2_boss, -14.0),
    "mus_greed_a2": (greed_a2, -19.0),
    "mus_a3_explore": (a3_explore, -14.0),
    "mus_a3_combat": (a3_combat, -14.0),
    "mus_a3_boss": (a3_boss, -14.0),
    "mus_greed_a3": (greed_a3, -19.0),
}


def main():
    if not bm.SRC:
        sys.exit("set WANDERER_METAL_SRC")
    out = sys.argv[1]
    names = sys.argv[2:] or list(TRACKS)
    for name in names:
        fn, target = TRACKS[name]
        bm.RNG = np.random.default_rng(sum(map(ord, name)))
        x = fn()
        y = master(x, True, target)
        print("%-16s %6.1fs  LUFS %.2f  TP %.2f dBTP" % (name, y.shape[-1] / SR, lufs(y), true_peak_db(y)), flush=True)
        write_ogg(os.path.join(out, name + ".ogg"), y, q=3)


if __name__ == "__main__":
    main()
