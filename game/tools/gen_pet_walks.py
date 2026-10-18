#!/usr/bin/env python3
"""Quadruped walk strips from locked pet stills (look locked — no redesign).

Replaces the biped upper/lower shear that made Noel/Bentley/Lillie read as
broken squash / hotdog bob. Legs alternate; torso stays cohesive.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORE = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/pets")
OUT_GAME = ROOT / "assets" / "sprites" / "pets"

PETS = [
    ("noel", "noel.png", "noel merle walk"),
    ("bentley", "bentley.png", "bentley walk"),
    ("lillie", "lillie.png", "lillie walk"),
]

FRAME = 96


def load_clean(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    px = im.load()
    # Drop near-white / light gray studio bg to alpha
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            if r >= 245 and g >= 245 and b >= 245:
                px[x, y] = (255, 255, 255, 0)
            elif r >= 230 and g >= 230 and b >= 230 and abs(r - g) < 8 and abs(g - b) < 8:
                px[x, y] = (255, 255, 255, 0)
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    return im


def fit_square(src: Image.Image, size: int = FRAME, pad: int = 4) -> Image.Image:
    sc = min((size - pad * 2) / src.width, (size - pad * 2) / src.height)
    nw = max(1, int(src.width * sc))
    nh = max(1, int(src.height * sc))
    # BOX then NEAREST keeps chunky pixel blocks from hi-res stills
    resized = src.resize((nw, nh), Image.Resampling.BOX)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - nw) // 2
    oy = size - nh - pad  # ground-align paws
    canvas.paste(resized, (ox, oy), resized)
    return canvas


def _paste(dst: Image.Image, src: Image.Image, xy: tuple[int, int]) -> None:
    layer = Image.new("RGBA", dst.size, (0, 0, 0, 0))
    layer.paste(src, xy, src)
    dst.alpha_composite(layer)


def synthesize_quad_walk(base: Image.Image) -> list[Image.Image]:
    """4-frame doodle walk: contact → front plant → pass → hind plant.

    Look locked: full body stays intact (no torso cut). Leg *overlays*
    shift a few pixels on top so we never open white gaps / shear seams.
    """
    w, h = base.size
    bbox = base.getbbox() or (0, 0, w, h)
    x0, y0, x1, y1 = bbox
    bw, bh = x1 - x0, y1 - y0
    # Paw band = lower ~38% — only this overlays move
    leg_y = y0 + int(bh * 0.62)
    mid_x = x0 + bw // 2
    front_x1 = mid_x + int(bw * 0.08)
    hind_x0 = mid_x - int(bw * 0.08)

    # (front_dx, front_dy, hind_dx, hind_dy, body_bob)
    specs = [
        (0, 0, 0, 0, 0),       # contact / idle
        (-2, 1, 1, -2, -1),    # front plant, hind lift
        (0, 0, 0, 0, -2),      # pass-through (bob only — clean silhouette)
        (1, -2, -2, 1, -1),    # hind plant, front lift
    ]

    frames: list[Image.Image] = []
    for fdx, fdy, hdx, hdy, bob in specs:
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # Intact body — never cut upper/lower (avoids hotdog shear + white seams)
        _paste(canvas, base, (0, bob))

        if fdx or fdy or hdx or hdy:
            # Soften source paw band under overlays so double-legs don't ghost hard
            cpx = canvas.load()
            for y in range(max(0, leg_y + bob), min(h, y1 + bob)):
                for x in range(x0, x1):
                    r, g, b, a = cpx[x, y]
                    if a > 0:
                        cpx[x, y] = (r, g, b, max(0, int(a * 0.35)))

            front = base.crop((x0, leg_y, front_x1, y1))
            _paste(canvas, front, (x0 + fdx, leg_y + fdy + bob))
            hind = base.crop((hind_x0, leg_y, x1, y1))
            _paste(canvas, hind, (hind_x0 + hdx, leg_y + hdy + bob))

        frames.append(canvas)
    return frames


def strip_of(frames: list[Image.Image]) -> Image.Image:
    strip = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * FRAME, 0), fr)
    return strip


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


def process(slug: str, still_name: str, label: str) -> None:
    still_path = STORE / still_name
    if not still_path.exists():
        still_path = OUT_GAME / f"{slug}.png"
    src = load_clean(still_path)
    base = fit_square(src, FRAME)
    frames = synthesize_quad_walk(base)
    OUT_GAME.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    strip = strip_of(frames)
    strip.save(OUT_GAME / f"{slug}_walk.png")
    preview_board(frames, label).save(STORE / f"{slug}_walk_strip.png", optimize=True)
    print("pet walk", slug, strip.size)


def family_demo() -> None:
    rows = []
    for slug, _, _ in PETS:
        p = STORE / f"{slug}_walk_strip.png"
        if p.exists():
            rows.append(Image.open(p).convert("RGB"))
    if not rows:
        return
    W = max(r.width for r in rows)
    H = sum(r.height for r in rows) + 8 * (len(rows) - 1)
    canvas = Image.new("RGB", (W, H), (22, 20, 18))
    y = 0
    for r in rows:
        canvas.paste(r, (0, y))
        y += r.height + 8
    canvas.save(STORE / "pets_walk_demo.png", optimize=True)


def main() -> None:
    for slug, still, label in PETS:
        process(slug, still, label)
    family_demo()
    print("done →", OUT_GAME)


if __name__ == "__main__":
    main()
