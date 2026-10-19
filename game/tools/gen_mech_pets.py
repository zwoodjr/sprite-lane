"""Mech pets (Depth E6): the approved machine cutout rigs (scrap_hound, iron_horse,
rad_bat strips in assets/sprites/enemies/) rebuilt in the hangar's Workshop —
repainted frame by frame so the full rig animation carries over:
  * bare iron      -> the pet's own paint (lit by the original shading)
  * rust / brown   -> brass trim
  * red/orange/green glow (eyes, furnaces, flames) -> friendly cyan optics / ion exhaust
  * a hazard-stripe band + white chevron pinned to each frame's body box (rides the bob)
usage (from game/):  python3 tools/gen_mech_pets.py [--sheet DIR]
writes assets/sprites/pets/<id>/<id>_<state>.png (+ _anim.json) and the
192 px tile portrait assets/sprites/portraits/pet_<id>.png (like the dogs').
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.join(HERE, "..")
SRC = os.path.join(GAME, "assets", "sprites", "enemies")
DST = os.path.join(GAME, "assets", "sprites", "pets")
STATES = ["idle", "walk", "windup", "attack", "hit", "death"]

MECHS = {
    # id: (source rig, paint dark, paint light, trim dark, trim light, glow, stripe band (v0, v1) of body box)
    "mech_hound": ("scrap_hound", (22, 52, 56), (120, 196, 184), (96, 70, 30), (232, 190, 96), (110, 236, 255), (0.30, 0.40)),
    "rust_mule": ("iron_horse", (70, 52, 18), (238, 186, 70), (40, 44, 48), (150, 156, 160), (120, 220, 255), (0.36, 0.44)),
    "drone_bat": ("rad_bat", (40, 30, 16), (232, 186, 92), (26, 36, 52), (150, 176, 206), (110, 236, 255), None),
}
FPS = {"idle": 8, "walk": 14, "windup": 10, "attack": 12, "hit": 12, "death": 10}


def lerp(a, b, t):
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    return a + (b - a) * t[..., None]


def repaint(fr, spec, seed):
    _, pd, pl, td, tl, glow, band = spec
    a = np.asarray(fr).astype(np.float32)
    rgb = a[..., :3]
    al = a[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1)
    lum = (0.3 * r + 0.55 * g + 0.15 * b) / 255.0
    ## Ink (dark seams / outlines) and soft edge pixels keep their colour.
    vis = (al > 150) & (lum > 0.11)
    out = rgb.copy()
    # glows: bright + saturated warm, or bright saturated green (bat eyes / spores)
    warm = vis & (r > 150) & (r > g + 25) & (r > b + 60) & (mx > 170)
    green_glow = vis & (g > 150) & (g > r + 30) & (g > b + 30) & (sat > 0.35)
    glowm = warm | green_glow
    # rust / brown / organic green: saturated mid tones that are not glows
    trim = vis & ~glowm & (sat > 0.22) & (mx < 210)
    paint = vis & ~glowm & ~trim
    t = np.clip((lum - 0.04) / 0.62, 0, 1) ** 0.85
    out[paint] = lerp(pd, pl, t)[paint] * 0.82 + rgb[paint] * 0.18
    out[trim] = lerp(td, tl, t)[trim]
    gl = np.clip(lum * 1.4, 0.55, 1.0)
    out[glowm] = (np.asarray(glow, np.float32)[None] * gl[glowm][:, None]) * 0.85 + 255 * 0.15 * gl[glowm][:, None]
    # hazard stripes on the body band (pinned to this frame's opaque box)
    if band is not None:
        ys, xs = np.nonzero(al > 200)
        if len(xs):
            x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
            h = y1 - y0
            yy0 = int(y0 + band[0] * h)
            yy1 = int(y0 + band[1] * h)
            xa = int(x0 + (x1 - x0) * 0.30)
            xb = int(x0 + (x1 - x0) * 0.62)
            for y in range(yy0, yy1 + 1):
                for x in range(xa, xb):
                    if al[y, x] > 200 and paint[y, x]:
                        k = ((x + y) // 3) % 2
                        base = np.array((236, 196, 60) if k else (30, 26, 22), np.float32)
                        out[y, x] = base * (0.6 + 0.5 * t[y, x])
    a[..., :3] = np.clip(out, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def build(mid, spec, sheet):
    src = spec[0]
    od = os.path.join(DST, mid)
    os.makedirs(od, exist_ok=True)
    for st in STATES:
        im = Image.open(os.path.join(SRC, src, "%s_%s.png" % (src, st))).convert("RGBA")
        n = im.width // im.height
        fs = im.height
        frames = [repaint(im.crop((i * fs, 0, (i + 1) * fs, fs)), spec, i) for i in range(n)]
        strip = Image.new("RGBA", (fs * n, fs))
        for i, f in enumerate(frames):
            strip.paste(f, (i * fs, 0))
        strip.save(os.path.join(od, "%s_%s.png" % (mid, st)))
        sheet.append((mid, st, frames))
    aj = os.path.join(SRC, src, "%s_attack.json" % src)
    if os.path.exists(aj):
        with open(aj) as f:
            atk = json.load(f)
        with open(os.path.join(od, "%s_attack.json" % mid), "w") as f:
            json.dump(atk, f)
    ## Carry the rig's own fps sidecar (organic pass: long idles / in-between gaits).
    fps = dict(FPS)
    sj = os.path.join(SRC, src, "%s_anim.json" % src)
    side = {}
    if os.path.exists(sj):
        with open(sj) as f:
            side = json.load(f)
        fps.update(side.get("fps", {}))
    side["fps"] = fps
    with open(os.path.join(od, "%s_anim.json" % mid), "w") as f:
        json.dump(side, f, indent=1)
    portrait(mid, spec, sheet[-6][2][0])


def portrait(mid, spec, fr):
    """Idle frame 0 cropped to the figure on a soft glow of the mech's optic colour."""
    a = np.asarray(fr)
    ys, xs = np.nonzero(a[..., 3] > 40)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    fig = fr.crop(box)
    k = 168.0 / max(fig.width, fig.height)
    fig = fig.resize((max(1, int(fig.width * k)), max(1, int(fig.height * k))), Image.NEAREST)
    n = 192
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    d = np.sqrt((xx - n * 0.42) ** 2 + (yy - n * 0.40) ** 2) / (n * 0.48)
    g = np.clip(1.0 - d, 0, 1) ** 1.6 * 0.32
    col = np.asarray(spec[5], np.float32)
    bg = np.dstack([np.broadcast_to(col[i], (n, n)) for i in range(3)] + [g * 255]).astype(np.uint8)
    out = Image.fromarray(bg, "RGBA")
    out.alpha_composite(fig, ((n - fig.width) // 2, (n - fig.height) // 2 + 4))
    out.save(os.path.join(GAME, "assets", "sprites", "portraits", "pet_%s.png" % mid))


if __name__ == "__main__":
    sheet = []
    for mid, spec in MECHS.items():
        build(mid, spec, sheet)
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        rows = {}
        for mid, st, frs in sheet:
            rows.setdefault(mid, []).append(frs[min(len(frs) - 1, 2)])
        bg = (92, 74, 54, 255)
        W = 128 * 2
        im = Image.new("RGBA", (W * 6, W * len(rows)), bg)
        for r, (mid, frs) in enumerate(rows.items()):
            for c, f in enumerate(frs):
                im.alpha_composite(f.resize((W, W), Image.NEAREST), (c * W, r * W))
        im.save(os.path.join(out, "mech_pets.png"))
    print("ok")
