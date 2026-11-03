#!/usr/bin/env python3
"""Fold animation strips wider than the GPU-safe texture size into grids.

WebGL (and some phone GPUs) refuse textures over MAX_TEXTURE_SIZE: the upload
fails ("texImage2D: ... out of range") and the sprite draws as a black box.
The 256-px pet / boss strips were 9216 px wide. Every strip wider than MAX is
rewritten as a grid of square frames (row-major, frame i at column i % cols,
row i // cols) and listed in assets/sprites/strip_grids.json, which
UnitAnim.strip_layout() reads. Re-running is safe: grids already listed are
skipped, and a strip that is regenerated as a single row is re-folded.

    python3 tools/repack_strips.py          # from game/
"""
import json
import os
import sys

from PIL import Image

MAX = 4096
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(ROOT, "assets", "sprites", "strip_grids.json")


def main() -> int:
    grids = {}
    if os.path.exists(MANIFEST):
        grids = json.load(open(MANIFEST)).get("grids", {})
    changed = 0
    for base, _dirs, files in os.walk(os.path.join(ROOT, "assets", "sprites")):
        for name in sorted(files):
            if not name.endswith(".png"):
                continue
            path = os.path.join(base, name)
            key = os.path.relpath(path, ROOT).replace(os.sep, "/")
            im = Image.open(path)
            w, h = im.size
            if key in grids:
                g = grids[key]
                if (w, h) == (g["cols"] * g["fs"], g["rows"] * g["fs"]):
                    continue
            if w <= MAX:
                continue
            fs = h
            n = max(1, round(w / fs))
            cols = max(1, MAX // fs)
            rows = (n + cols - 1) // cols
            out = Image.new("RGBA", (cols * fs, rows * fs), (0, 0, 0, 0))
            src = im.convert("RGBA")
            for i in range(n):
                fr = src.crop((i * fs, 0, i * fs + fs, fs))
                out.paste(fr, ((i % cols) * fs, (i // cols) * fs))
            out.save(path, optimize=True)
            grids[key] = {"n": n, "fs": fs, "cols": cols, "rows": rows}
            changed += 1
            print("grid %-70s %dx%d -> %dx%d (%d frames, %d cols)" % (key, w, h, cols * fs, rows * fs, n, cols))
    with open(MANIFEST, "w") as f:
        json.dump({"max": MAX, "grids": dict(sorted(grids.items()))}, f, indent=1)
        f.write("\n")
    print("%d strip(s) folded, %d grids listed" % (changed, len(grids)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
