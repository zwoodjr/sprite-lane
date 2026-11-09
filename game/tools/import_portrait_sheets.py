#!/usr/bin/env python3
"""Hero + NPC portraits from Zach's painted portrait boards.

Sources (tools/art_src/):
  portraits_heroes.png   4 x 2 painted heads on grey panels (pass 2)
  npc_portraits_board.png  batch-7 composite board; the bottom panel holds the
                           four NPC busts left to right: Mother Vane, Dust,
                           raider, Helm on the radio

Each bust is keyed off its grey backdrop with the dog importer's keyer
(import_dog_sheet.key_cell, portrait mode), cropped square from the top of the
head, faded into the bottom edge and written as 192 px RGBA to
assets/sprites/portraits/<id>.png (same size / format as before).

    python3 tools/import_portrait_sheets.py [--preview DIR] [--dry]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_dog_sheet as dogs  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, ".."))
SRC = os.path.join(HERE, "art_src")
PORTRAITS = os.path.join(GAME, "assets", "sprites", "portraits")
PX = 192

# Heads on the hero board, row-major, matched to the new animated designs.
HERO_CELLS = [
    "ash_rook",        # goggles, scarf, launcher pack   -> heavy minigunner
    "bolt_juno",       # red mohawk, goggles             -> lantern-pack gunner
    "pebble",          # hazard-striped plate helm       -> riot-shield heavy
    "nyx_caldera",     # spiked pauldron, black hair     -> axe fighter
    "helm_wisp",       # cap, goggles, headset           -> drone operator
    "quill_marrow",    # hood, spectacles                -> hooded rifleman
    "sister_cinder",   # red-cross veil                  -> medic
    "vesper_thorn",    # braids, fur collar              -> ghillie sniper
]
# Bottom panel of the NPC board, left to right (None = not used by the game).
NPC_CELLS = ["mother_vane", "dust", "raider", None]


def bust(rgb, zoom=1.0, top_pad=10):
    """Key a bust cell -> 192 px RGBA. `zoom` > 1 crops tighter (head larger)."""
    fg, alpha, _ = dogs.key_cell(rgb, portrait=True, soft_shadows=False)
    h, w = alpha.shape
    m = alpha > 0.5
    ys, xs = np.nonzero(m)
    top = int(ys.min())
    side = int(min(w, h - max(0, top - top_pad), (xs.max() - xs.min() + 1) / zoom))
    # Centre on the head: mass of the top third of the bust.
    head = m[top:top + max(8, side // 3)]
    hx = np.nonzero(head.any(0))[0]
    cols = head.sum(0)
    cx = int((cols * np.arange(w)).sum() / max(1, cols.sum())) if len(hx) else w // 2
    x0 = int(np.clip(cx - side // 2, 0, w - side))
    y0 = int(max(0, top - top_pad))
    side = min(side, h - y0)
    fade = np.clip((h - 1 - np.arange(h)) / 22.0, 0, 1)[:, None]
    a = alpha * fade
    pm = np.dstack([fg * a[..., None], a * 255.0])[y0:y0 + side, x0:x0 + side]
    big = Image.fromarray(np.clip(pm, 0, 255).round().astype(np.uint8), "RGBA").resize((PX, PX), Image.LANCZOS)
    out = np.array(big).astype(float)
    al = out[..., 3:4] / 255.0
    out[..., :3] = np.where(al > 0.004, out[..., :3] / np.maximum(al, 0.004), 0)
    out[out[..., 3] < 3] = 0
    return Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA")


def hero_cells(rgb):
    h, w, _ = rgb.shape
    cw, ch = w / 4.0, h / 2.0
    for i in range(8):
        r, c = divmod(i, 4)
        x0, x1 = int(c * cw) + 8, int((c + 1) * cw) - 8
        y0, y1 = int(r * ch) + 8, int((r + 1) * ch) - 8
        yield HERO_CELLS[i], rgb[y0:y1, x0:x1]


def npc_cells(rgb):
    # Bottom panel: rows 790..1016 of the 1536 x 1024 board.
    y0, y1 = 792, 1014
    x0, x1 = 10, 1526
    cw = (x1 - x0) / 4.0
    for i in range(4):
        if NPC_CELLS[i]:
            yield NPC_CELLS[i], rgb[y0:y1, int(x0 + i * cw):int(x0 + (i + 1) * cw)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    jobs = []
    hr = np.array(Image.open(os.path.join(SRC, "portraits_heroes.png")).convert("RGB")).astype(float)
    jobs += [(k, c, 1.12) for k, c in hero_cells(hr)]
    nr = np.array(Image.open(os.path.join(SRC, "npc_portraits_board.png")).convert("RGB")).astype(float)
    jobs += [(k, c, 1.0) for k, c in npc_cells(nr)]
    sheet = Image.new("RGBA", (PX * len(jobs), PX), (70, 92, 64, 255))
    for i, (k, cell, z) in enumerate(jobs):
        im = bust(cell, zoom=z)
        sheet.alpha_composite(im, (i * PX, 0))
        if not args.dry:
            im.save(os.path.join(PORTRAITS, k + ".png"), optimize=True)
        print(k)
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
        sheet.save(os.path.join(args.preview, "portraits.png"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
