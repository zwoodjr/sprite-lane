#!/usr/bin/env python3
"""Slice AI walk plates → 4×96 game strips + store previews (look locked)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "pets"
STORE = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/pets")
ARTIFACTS = Path("/opt/cursor/artifacts/assets")
FRAME = 96

JOBS = [
    ("noel_walk_gen.jpg", "noel", "noel merle walk"),
    ("bentley_walk_gen.jpg", "bentley", "bentley walk"),
    ("lillie_walk_gen.jpg", "lillie", "lillie walk"),
]


def knock_white(im: Image.Image, thr: int = 242) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if r >= thr and g >= thr and b >= thr:
                px[x, y] = (255, 255, 255, 0)
            elif min(r, g, b) >= thr - 10 and max(r, g, b) - min(r, g, b) < 12:
                px[x, y] = (255, 255, 255, 0)
    return im


def split_four(im: Image.Image) -> list[Image.Image]:
    """Split a wide plate into 4 frames by equal width, then tight-crop each."""
    w, h = im.size
    fw = w // 4
    frames = []
    for i in range(4):
        cell = im.crop((i * fw, 0, (i + 1) * fw if i < 3 else w, h))
        cell = knock_white(cell)
        bbox = cell.getbbox()
        if bbox:
            cell = cell.crop(bbox)
        frames.append(cell)
    return frames


def fit_frame(src: Image.Image) -> Image.Image:
    pad = 3
    sc = min((FRAME - pad * 2) / src.width, (FRAME - pad * 2) / src.height)
    nw, nh = max(1, int(src.width * sc)), max(1, int(src.height * sc))
    mid = src.resize((nw * 2, nh * 2), Image.Resampling.BOX)
    small = mid.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    canvas.paste(small, ((FRAME - nw) // 2, FRAME - nh - pad), small)
    return canvas


def preview_board(frames: list[Image.Image], label: str) -> Image.Image:
    cell, pad, gap = 128, 12, 8
    n = len(frames)
    W = pad * 2 + n * cell + (n - 1) * gap
    H = pad * 2 + cell + 36
    board = Image.new("RGB", (W, H), (28, 24, 22))
    d = ImageDraw.Draw(board)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    except Exception:
        font = ImageFont.load_default()
    d.text((pad, 8), label, fill=(220, 200, 160), font=font)
    for i, fr in enumerate(frames):
        big = fr.resize((cell - 8, cell - 8), Image.Resampling.NEAREST)
        tile = Image.new("RGB", (cell, cell), (255, 255, 255))
        tile.paste(big, (4, 4), big)
        board.paste(tile, (pad + i * (cell + gap), pad + 24))
    return board


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    rows = []
    for src_name, slug, label in JOBS:
        src = ARTIFACTS / src_name
        if not src.exists():
            alt = ARTIFACTS / src_name.replace(".jpg", ".png")
            src = alt if alt.exists() else src
        if not src.exists():
            print("missing", src_name)
            continue
        plate = knock_white(Image.open(src))
        # trim outer plate margins
        bbox = plate.getbbox()
        if bbox:
            plate = plate.crop(bbox)
        frames = [fit_frame(f) for f in split_four(plate)]
        strip = Image.new("RGBA", (FRAME * 4, FRAME), (0, 0, 0, 0))
        for i, fr in enumerate(frames):
            strip.paste(fr, (i * FRAME, 0), fr)
        strip.save(OUT / f"{slug}_walk.png")
        prev = preview_board(frames, label)
        prev.save(STORE / f"{slug}_walk_strip.png", optimize=True)
        rows.append(prev)
        print("walk", slug, strip.size)

    if rows:
        W = max(r.width for r in rows)
        H = sum(r.height for r in rows) + 8 * (len(rows) - 1)
        canvas = Image.new("RGB", (W, H), (22, 20, 18))
        y = 0
        for r in rows:
            canvas.paste(r, (0, y))
            y += r.height + 8
        canvas.save(STORE / "pets_walk_demo.png", optimize=True)

    # before/after boards
    for slug, _, _ in [(a, b, c) for a, b, c in JOBS]:
        pass
    for _src, slug, _lab in JOBS:
        before = STORE / f"{slug}_walk_strip_before.png"
        after = STORE / f"{slug}_walk_strip.png"
        if before.exists() and after.exists():
            b = Image.open(before).convert("RGB")
            a = Image.open(after).convert("RGB")
            W = max(b.width, a.width)
            board = Image.new("RGB", (W, b.height + a.height + 48), (28, 24, 22))
            d = ImageDraw.Draw(board)
            try:
                font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
            except Exception:
                font = ImageFont.load_default()
            d.text((8, 6), f"{slug} walk BEFORE", fill=(220, 160, 140), font=font)
            board.paste(b, (0, 28))
            d.text((8, 34 + b.height), f"{slug} walk AFTER", fill=(160, 220, 160), font=font)
            board.paste(a, (0, 56 + b.height))
            board.save(STORE / f"{slug}_walk_before_after.png", optimize=True)
    print("done →", OUT)


if __name__ == "__main__":
    main()
