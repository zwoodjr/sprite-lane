#!/usr/bin/env python3
"""Synthesize short walk cycles from locked sheet crops (no redesign).

Produces 4-frame horizontal strips:
  frame 0 idle lean, 1 left-step, 2 pass-through, 3 right-step
Lower half shifts (leg fake), whole-body squash/stretch, tiny upper counter-sway.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORE_HEROES = Path("/cursor/stores/self/media/heroes")
STORE_MOBS = Path("/cursor/stores/self/media/mobs/sprites")
OUT_CHARS = ROOT / "assets" / "sprites" / "characters" / "walk"
OUT_ENEMIES = ROOT / "assets" / "sprites" / "enemies" / "walk"

HEROES = [
    "ash_rook", "vesper_thorn", "pebble", "bolt_juno",
    "sister_cinder", "quill_marrow", "nyx_caldera", "helm_wisp",
]


def load_rgb(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def synthesize_frames(src: Image.Image, frame_h: int = 96) -> list[Image.Image]:
    """Build 4 walk frames from one still. Look locked — geometric only."""
    # Fit into square canvas for consistent atlas cells
    sc = min((frame_h - 4) / src.width, (frame_h - 4) / src.height)
    nw, nh = max(1, int(src.width * sc)), max(1, int(src.height * sc))
    base = src.resize((nw, nh), Image.Resampling.BOX)

    frames: list[Image.Image] = []
    # (leg_shift_x, squash_y, stretch_x, upper_counter, bob_y)
    specs = [
        (0, 1.00, 1.00, 0, 0),      # idle / contact
        (-3, 0.94, 1.05, 1, -2),    # left plant
        (0, 1.04, 0.96, 0, -4),     # airborne stretch
        (3, 0.94, 1.05, -1, -2),    # right plant
    ]
    for leg_dx, sy, sx, upper_dx, bob in specs:
        canvas = Image.new("RGBA", (frame_h, frame_h), (0, 0, 0, 0))
        # Split upper / lower for limb fake
        split = int(nh * 0.58)
        upper = base.crop((0, 0, nw, split))
        lower = base.crop((0, split, nw, nh))
        # Squash/stretch whole pieces
        uw, uh = max(1, int(nw * sx)), max(1, int(split * sy))
        lw, lh = max(1, int(nw * sx)), max(1, int((nh - split) * sy))
        upper_r = upper.resize((uw, uh), Image.Resampling.NEAREST)
        lower_r = lower.resize((lw, lh), Image.Resampling.NEAREST)
        ox = (frame_h - uw) // 2
        oy = (frame_h - (uh + lh)) // 2 + bob
        canvas.paste(upper_r, (ox + upper_dx, oy), upper_r)
        canvas.paste(lower_r, (ox + leg_dx, oy + uh), lower_r)
        frames.append(canvas)
    return frames


def strip_of(frames: list[Image.Image]) -> Image.Image:
    w = frames[0].width * len(frames)
    h = frames[0].height
    strip = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        strip.paste(fr, (i * fr.width, 0), fr)
    return strip


def preview_board(frames: list[Image.Image], label: str) -> Image.Image:
    cell = 128
    pad = 12
    gap = 8
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


def process_unit(slug: str, still_path: Path, out_dir: Path, preview_dir: Path) -> None:
    if not still_path.exists():
        # fallback to game 96 texture
        alt = ROOT / "assets" / "sprites" / ("characters" if "heroes" in str(preview_dir) or out_dir == OUT_CHARS else "enemies") / f"{slug}.png"
        # simpler: try game path passed separately
        print("missing still", still_path)
        return
    src = load_rgb(still_path)
    # Drop near-white to alpha for cleaner composites
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if r >= 248 and g >= 248 and b >= 248:
                px[x, y] = (255, 255, 255, 0)
    frames = synthesize_frames(src, 96)
    out_dir.mkdir(parents=True, exist_ok=True)
    preview_dir.mkdir(parents=True, exist_ok=True)
    strip = strip_of(frames)
    strip.save(out_dir / f"{slug}_walk.png")
    # also copy strip next to still for Godot path convenience
    preview_board(frames, f"{slug} walk").save(preview_dir / f"{slug}_walk_strip.png", optimize=True)
    print("walk", slug, strip.size)


def main() -> None:
    OUT_CHARS.mkdir(parents=True, exist_ok=True)
    OUT_ENEMIES.mkdir(parents=True, exist_ok=True)

    for slug in HEROES:
        still = STORE_HEROES / f"{slug}_still.png"
        if not still.exists():
            still = ROOT / "assets" / "sprites" / "characters" / f"{slug}.png"
        process_unit(slug, still, OUT_CHARS, STORE_HEROES)
        # also place strip where game loads easily
        src = OUT_CHARS / f"{slug}_walk.png"
        if src.exists():
            (ROOT / "assets" / "sprites" / "characters" / f"{slug}_walk.png").write_bytes(src.read_bytes())

    mob_stills = sorted(STORE_MOBS.glob("*_still.png"))
    for still in mob_stills:
        slug = still.name.replace("_still.png", "")
        process_unit(slug, still, OUT_ENEMIES, STORE_MOBS)
        src = OUT_ENEMIES / f"{slug}_walk.png"
        if src.exists():
            (ROOT / "assets" / "sprites" / "enemies" / f"{slug}_walk.png").write_bytes(src.read_bytes())

    # Family demo strips
    _family_demo_heroes()
    _family_demo_mobs()
    print("done")


def _family_demo_heroes() -> None:
    rows = []
    for slug in HEROES:
        p = STORE_HEROES / f"{slug}_walk_strip.png"
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
    canvas.save(STORE_HEROES / "heroes_walk_demo.png", optimize=True)


def _family_demo_mobs() -> None:
    # Pick a few per tier for a compact demo
    picks = [
        "rad_gator", "scrap_hound", "glow_moth", "toxic_scorp",
        "scav_bear", "dune_serpent", "dread_naught",
        "ash_wraiths", "mutant_overlord", "cyber_juggernaut",
    ]
    rows = []
    for slug in picks:
        p = STORE_MOBS / f"{slug}_walk_strip.png"
        if p.exists():
            rows.append(Image.open(p).convert("RGB"))
    if not rows:
        return
    W = max(r.width for r in rows)
    H = sum(r.height for r in rows) + 6 * (len(rows) - 1)
    canvas = Image.new("RGB", (W, H), (22, 20, 18))
    y = 0
    for r in rows:
        canvas.paste(r, (0, y))
        y += r.height + 6
    canvas.save(STORE_MOBS / "mobs_walk_demo.png", optimize=True)
    canvas.save(Path("/cursor/stores/self/media/mobs") / "mobs_walk_demo.png", optimize=True)


if __name__ == "__main__":
    main()
