#!/usr/bin/env python3
"""Crop AI mount plates → wasteland game sprites + store previews."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "mounts"
STORE = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/mounts")
ARTIFACTS = Path("/opt/cursor/artifacts/assets")

JOBS = [
    ("skateboard_gen.jpg", "skateboard.png", (80, 40), "skateboard"),
    ("scooter_gen.jpg", "scooter.png", (72, 72), "scooter"),
]


def knock_white(im: Image.Image, thr: int = 238) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if r >= thr and g >= thr and b >= thr:
                px[x, y] = (255, 255, 255, 0)
            elif min(r, g, b) >= thr - 12 and max(r, g, b) - min(r, g, b) < 14:
                px[x, y] = (255, 255, 255, 0)
    return im


def tight_crop(im: Image.Image, pad: int = 4) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def fit_canvas(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    tw, th = size
    sc = min((tw - 2) / im.width, (th - 2) / im.height)
    nw, nh = max(1, int(im.width * sc)), max(1, int(im.height * sc))
    # Soft downscale then nearest snap for chunky game pixels
    mid = im.resize((nw * 2, nh * 2), Image.Resampling.BOX)
    small = mid.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(small, ((tw - nw) // 2, th - nh - 1), small)
    return canvas


def preview(im: Image.Image, label: str, scale: int = 6) -> Image.Image:
    big = im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST)
    pad = 16
    board = Image.new("RGB", (big.width + pad * 2, big.height + pad * 2 + 28), (28, 24, 22))
    d = ImageDraw.Draw(board)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    except Exception:
        font = ImageFont.load_default()
    d.text((pad, 8), label, fill=(220, 200, 160), font=font)
    tile = Image.new("RGB", big.size, (255, 255, 255))
    tile.paste(big, (0, 0), big)
    board.paste(tile, (pad, pad + 24))
    return board


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    for src_name, out_name, size, label in JOBS:
        src = ARTIFACTS / src_name
        if not src.exists():
            # also accept .png
            alt = ARTIFACTS / src_name.replace(".jpg", ".png")
            src = alt if alt.exists() else src
        if not src.exists():
            print("missing", src_name)
            continue
        im = knock_white(Image.open(src))
        im = tight_crop(im)
        game = fit_canvas(im, size)
        game.save(OUT / out_name)
        # hi-res store plate + 8x game preview
        store_hi = fit_canvas(tight_crop(knock_white(Image.open(src))), (size[0] * 4, size[1] * 4))
        store_hi.save(STORE / out_name)
        preview(game, label).save(STORE / f"{label}_8x.png", optimize=True)
        print("mount", out_name, game.size)
    # before/after board for skateboard
    before = STORE / "skateboard_before.png"
    after = OUT / "skateboard.png"
    if before.exists() and after.exists():
        b = Image.open(before).convert("RGBA")
        a = Image.open(after).convert("RGBA")
        cell_w = 280
        board = Image.new("RGB", (cell_w * 2 + 36, 220), (28, 24, 22))
        d = ImageDraw.Draw(board)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
        except Exception:
            font = ImageFont.load_default()
        for i, (im, lab) in enumerate([(b, "before (hotdog)"), (a, "after (sheet)")]):
            sc = min(240 / im.width, 140 / im.height)
            show = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.Resampling.NEAREST)
            tile = Image.new("RGB", (260, 160), (255, 255, 255))
            tile.paste(show, ((260 - show.width) // 2, (160 - show.height) // 2), show)
            x = 12 + i * (cell_w + 12)
            board.paste(tile, (x, 40))
            d.text((x, 12), lab, fill=(220, 200, 160), font=font)
        board.save(STORE / "skateboard_before_after.png", optimize=True)
    print("done →", OUT)


if __name__ == "__main__":
    main()
