#!/usr/bin/env python3
"""Turn a generated character image into a hi-res Spirit Lane model.

    python3 tools/import-model.py art.png --id sparkfist            # tower idle
    python3 tools/import-model.py swing.png --id sparkfist --frame atk0
    python3 tools/import-model.py bug.png --mob sparkgrub --frame walk0

Removes the flat/dark background, trims to the figure, scales it to
--px tall (default 144 = 1.5 tiles at the game's 3x render), writes
assets/models/<id>/<frame>.png and registers it in assets/models/hires.js.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
HIRES = ROOT / "assets" / "models" / "hires.js"


def remove_background(im: Image.Image, tol: int) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    # Already cut out? keep it.
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    if all(c[3] < 10 for c in corners):
        return im
    border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)]
    border += [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
    bg = tuple(sorted(c[i] for c in border)[len(border) // 2] for i in range(3))

    def is_bg(c):
        return sum(abs(c[i] - bg[i]) for i in range(3)) <= tol

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        c = px[x, y]
        if not is_bg(c):
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    return im


def main() -> None:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--id", help="tower/unit id (e.g. sparkfist)")
    g.add_argument("--mob", help="mob kind (e.g. sparkgrub)")
    ap.add_argument("image")
    ap.add_argument("--frame", default=None, help="idle0, idle1, atk0, atk1, walk0..")
    ap.add_argument("--px", type=int, default=None, help="output height in pixels")
    ap.add_argument("--tiles", type=float, default=None, help="height on the map in tiles")
    ap.add_argument("--tol", type=int, default=60, help="background colour tolerance")
    a = ap.parse_args()

    kind = "units" if a.id else "mobs"
    ident = a.id or a.mob
    frame = a.frame or ("idle0" if kind == "units" else "walk0")
    tiles = a.tiles or (1.5 if kind == "units" else 1.15)
    px_h = a.px or int(round(tiles * 32 * 3))

    im = remove_background(Image.open(a.image), a.tol)
    bbox = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    if not bbox:
        raise SystemExit("Nothing left after background removal — try a lower --tol.")
    im = im.crop(bbox)
    scale = px_h / im.height
    out = im.resize((max(1, round(im.width * scale)), px_h), Image.LANCZOS)
    # Crisp silhouette: firm up alpha so edges don't go soft/halo.
    a_ch = out.getchannel("A").point(lambda v: 0 if v < 70 else (255 if v > 170 else v))
    out.putalpha(a_ch)
    out = out.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))

    dest_dir = ROOT / "assets" / "models" / ident
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / f"{frame}.png"
    out.save(dest, optimize=True)

    src = HIRES.read_text(encoding="utf-8")
    m = re.search(r"/\* MANIFEST:BEGIN \*/\n  const MANIFEST = (\{.*?\});\n  /\* MANIFEST:END \*/", src, re.S)
    body = m.group(1)
    js = re.sub(r"(\w+):", r'"\1":', body)
    js = re.sub(r",(\s*[}\]])", r"\1", js)
    manifest = json.loads(js)
    entry = manifest[kind].setdefault(ident, {"h": tiles})
    entry["h"] = tiles
    key = re.sub(r"\d+$", "", frame)
    rel = f"assets/models/{ident}/{frame}.png"
    entry.setdefault(key, [])
    if rel not in entry[key]:
        entry[key].append(rel)
        entry[key].sort()
    new_body = json.dumps(manifest, indent=2).replace("\n", "\n  ")
    src = src[: m.start(1)] + new_body + src[m.end(1):]
    HIRES.write_text(src, encoding="utf-8")

    sw = ROOT / "sw.js"
    s = sw.read_text(encoding="utf-8")
    line = f'  "./{rel}",\n'
    if line not in s:
        s = s.replace('  "./assets/models/hires.js",\n', '  "./assets/models/hires.js",\n' + line)
        sw.write_text(s, encoding="utf-8")
    print(f"{rel}  {out.width}x{out.height}  ({kind}, {tiles} tiles tall)")


if __name__ == "__main__":
    main()
