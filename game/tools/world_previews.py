#!/usr/bin/env python3
"""Build before/after + sheet previews under store media/world/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORE = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/world")
TILES = ROOT / "assets" / "sprites" / "tiles"
PROPS = ROOT / "assets" / "sprites" / "props"


def font(size: int = 14):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
    except Exception:
        return ImageFont.load_default()


def magnify(im: Image.Image, s: int = 4) -> Image.Image:
    return im.resize((im.width * s, im.height * s), Image.Resampling.NEAREST)


def main() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    # Ground sheet
    tiles = [Image.open(TILES / f"ground_{i}.png").convert("RGBA") for i in range(6)]
    cell = 64 * 3
    sheet = Image.new("RGB", (cell * 3 + 32, cell * 2 + 48), (28, 24, 22))
    d = ImageDraw.Draw(sheet)
    d.text((12, 10), "ground tiles (chunky wasteland)", fill=(220, 200, 160), font=font())
    for i, t in enumerate(tiles):
        big = magnify(t, 3)
        x = 12 + (i % 3) * (cell + 4)
        y = 36 + (i // 3) * (cell + 4)
        sheet.paste(big.convert("RGB"), (x, y))
    sheet.save(STORE / "ground_tiles_sheet.png", optimize=True)

    # Props sheet
    names = [
        "herb_crate", "vial_crate", "apothecary_chest", "scrap_drum",
        "scrap_pile", "wreck", "signal_tower", "rock_large",
        "dead_bush", "tire", "cactus", "extract_open",
    ]
    cols = 4
    cell = 160
    rows = (len(names) + cols - 1) // cols
    prop_sheet = Image.new("RGB", (cols * cell + 24, rows * cell + 40), (28, 24, 22))
    d = ImageDraw.Draw(prop_sheet)
    d.text((12, 8), "world props + extract pad", fill=(220, 200, 160), font=font())
    for i, name in enumerate(names):
        im = Image.open(PROPS / f"{name}.png").convert("RGBA")
        sc = min(120 / im.width, 120 / im.height)
        show = im.resize((max(1, int(im.width * sc)), max(1, int(im.height * sc))), Image.Resampling.NEAREST)
        tile = Image.new("RGB", (cell - 16, cell - 28), (255, 255, 255))
        tile.paste(show, ((tile.width - show.width) // 2, (tile.height - show.height) // 2), show)
        x = 12 + (i % cols) * cell
        y = 32 + (i // cols) * cell
        prop_sheet.paste(tile, (x, y))
        d.text((x, y + cell - 40), name, fill=(200, 180, 140), font=font(11))
    prop_sheet.save(STORE / "props_sheet.png", optimize=True)

    # Before/after ground
    before = STORE / "ground_0_before.png"
    after = TILES / "ground_0.png"
    if before.exists():
        b = magnify(Image.open(before).convert("RGBA"), 4)
        a = magnify(Image.open(after).convert("RGBA"), 4)
        board = Image.new("RGB", (b.width * 2 + 48, b.height + 56), (28, 24, 22))
        d = ImageDraw.Draw(board)
        d.text((12, 10), "ground_0 before", fill=(220, 200, 160), font=font())
        d.text((b.width + 36, 10), "ground_0 after", fill=(220, 200, 160), font=font())
        board.paste(b.convert("RGB"), (12, 36))
        board.paste(a.convert("RGB"), (b.width + 36, 36))
        board.save(STORE / "ground_before_after.png", optimize=True)

    # Before/after crate
    before = STORE / "herb_crate_before.png"
    after = PROPS / "herb_crate.png"
    if before.exists():
        b = magnify(Image.open(before).convert("RGBA"), 5)
        a = magnify(Image.open(after).convert("RGBA"), 5)
        board = Image.new("RGB", (max(b.width, a.width) * 2 + 48, max(b.height, a.height) + 56), (28, 24, 22))
        d = ImageDraw.Draw(board)
        d.text((12, 10), "herb_crate before", fill=(220, 200, 160), font=font())
        d.text((b.width + 36, 10), "herb_crate after", fill=(220, 200, 160), font=font())
        board.paste(Image.new("RGB", b.size, (255, 255, 255)), (12, 36))
        board.paste(b, (12, 36), b)
        board.paste(Image.new("RGB", a.size, (255, 255, 255)), (b.width + 36, 36))
        board.paste(a, (b.width + 36, 36), a)
        board.save(STORE / "herb_crate_before_after.png", optimize=True)

    # Extract after
    for name in ("extract_open", "extract_sealed"):
        im = Image.open(PROPS / f"{name}.png").convert("RGBA")
        magnify(im, 3).save(STORE / f"{name}_3x.png")

    print("world previews →", STORE)


if __name__ == "__main__":
    main()
