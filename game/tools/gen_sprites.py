#!/usr/bin/env python3
"""Generate Dust Apothecary chunky-pixel sprites for Wanderer MVP.

Style target (inspiration only — original art, not Crazy Gunner IP):
  clean polished chibi pixel — large square heads, stubby bodies with
  CLEAR limb separation (head / torso / arms / legs / weapon as separate
  masses — NOT a tapered thumb/sausage), simple 2-dot faces, hair as
  chunky shaped masses, thick dark outlines, one darker shade.

Tuned for portrait survivor FOV (camera zoom ~1.12, player ~1/12–1/15
screen width). Heroes authored at 96×96 so limbs have room; in-match
scale keeps ~48px footprint via player.gd.

Detail bar: match the approved 64×64 dog-face pixelation density —
deliberate chunky blocks, clean thick outlines, no thumb blobs, no
uncanny face detail. Pets (Noel) authored at 64×64 with the same craft.

Run from repo root or game/:
  python3 game/tools/gen_sprites.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
HERO_SIZE = 96  # room for arm/leg gaps; FOV scale handles on-screen size
PET_SIZE = 64   # native 64×64 detail target (Noel face density)

# Palette — Dust Apothecary
INK = (18, 14, 12, 255)
DUST = (124, 92, 62, 255)
DUST_LT = (148, 114, 78, 255)
DUST_DK = (92, 68, 46, 255)
RUST = (156, 72, 42, 255)
RUST_DK = (110, 48, 30, 255)
SCRAP = (90, 86, 82, 255)
SCRAP_LT = (130, 126, 118, 255)
SCRAP_DK = (52, 48, 46, 255)
SKIN = (210, 168, 128, 255)
SKIN_DK = (168, 128, 96, 255)
SKIN_LT = (232, 196, 158, 255)
VIAL = (64, 176, 128, 255)
VIAL_LT = (140, 230, 180, 255)
VIAL_DK = (36, 110, 80, 255)
AMBER = (232, 176, 64, 255)
AMBER_LT = (255, 220, 120, 255)
AMBER_DK = (180, 120, 36, 255)
GOLD = (220, 180, 70, 255)
BONE = (228, 214, 186, 255)
WHITE = (245, 240, 230, 255)
SHADOW = (30, 20, 12, 90)


def save(img: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", rel, img.size)


def new(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def shade(c, k: float):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)


def px(pxls, x: int, y: int, c, w: int, h: int) -> None:
    if 0 <= x < w and 0 <= y < h:
        pxls[x, y] = c


def fill_rect(pxls, x0, y0, x1, y1, c, w, h) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(pxls, x, y, c, w, h)


def fill_ellipse(pxls, x0, y0, x1, y1, c, w, h) -> None:
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    rx = max(0.5, (x1 - x0) / 2)
    ry = max(0.5, (y1 - y0) / 2)
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.05:
                px(pxls, x, y, c, w, h)


def add_outline(img: Image.Image, color=INK, thickness: int = 1) -> Image.Image:
    """Expand opaque silhouette with thick dark outline (Crazy Gunner–like)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    opaque = [[src[x, y][3] > 20 for x in range(w)] for y in range(h)]
    for _t in range(thickness):
        mark = []
        for y in range(h):
            for x in range(w):
                if opaque[y][x]:
                    continue
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and opaque[ny][nx]:
                            mark.append((x, y))
                            break
                    else:
                        continue
                    break
        for x, y in mark:
            dst[x, y] = color
            opaque[y][x] = True
    return out


def drop_shadow(img: Image.Image, cx: int, cy: int, rw: int, rh: int, a: int = 85) -> None:
    d = ImageDraw.Draw(img)
    d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=(30, 20, 12, a))


def eyes_dots(p, lx, rx, y, w, h, color=INK, size: int = 2) -> None:
    """Crazy Gunner–style eyes: two clear dark dots. No sclera/brows/nose/mouth.
    size=2 (2×2) keeps the pair readable after FOV shrink to ~48px."""
    for x0 in (lx, rx):
        fill_rect(p, x0, y, x0 + size - 1, y + size - 1, color, w, h)


def eyes_visor(p, x0, x1, y, w, h, color, hi=None) -> None:
    """Single horizontal visor bar (helmet / goggle characters)."""
    fill_rect(p, x0, y, x1, y + 2, color, w, h)
    if hi:
        fill_rect(p, x0, y, x1, y, hi, w, h)


def hair_mass(p, rects, w, h) -> None:
    """Paint hair as chunky filled blocks — jagged silhouette, no strand noise.
    Each entry: (x0, y0, x1, y1, color)."""
    for x0, y0, x1, y1, c in rects:
        fill_rect(p, x0, y0, x1, y1, c, w, h)


def _stamp(canvas: Image.Image, part: Image.Image, ox: int, oy: int) -> None:
    """Alpha-composite an outlined part onto the hero canvas."""
    canvas.alpha_composite(part, (ox, oy))


def _outlined_part(w: int, h: int, paint, thickness: int = 2) -> Image.Image:
    """Paint into a transparent layer, then outline THAT layer alone.

    Critical anti-thumb trick: outlining limbs separately preserves crotch /
    armpit gaps that a single global outline would flood-fill shut.
    """
    layer = new(w, h)
    paint(layer.load(), w, h)
    return add_outline(layer, thickness=thickness)


# ---------------------------------------------------------------------------
# Characters — 96×96 multi-pass chibi: separate head/torso/arms/legs masses
# Scaled in-game so on-screen footprint stays ~48px (~1/13 screen width).
# ---------------------------------------------------------------------------

def make_rook() -> Image.Image:
    """Rook Vex — dust scavenger OC.

    CG-card silhouette grammar (original design, not a copy):
      ~55% head · stubby narrower torso · hand-blocks as side masses ·
      wide crotch gap · SMG as right-side mass. Face = two eye dots only.
    """
    S = HERO_SIZE
    img = new(S, S)
    drop_shadow(img, 48, 86, 24, 5, 95)

    olive = (92, 128, 72, 255)
    olive_lt = (128, 168, 100, 255)
    olive_dk = (62, 88, 48, 255)
    scarf = (220, 104, 52, 255)
    scarf_dk = (168, 72, 36, 255)
    hair = (228, 184, 72, 255)
    hair_lt = (248, 214, 120, 255)
    hair_dk = (176, 132, 48, 255)
    pant = (110, 78, 52, 255)

    # Stubby CG legs — short pillars, stamped with a wide crotch gap.
    def paint_leg(p, w, h):
        fill_rect(p, 2, 0, 12, 8, pant, w, h)
        fill_rect(p, 2, 0, 12, 2, shade(pant, 1.12), w, h)
        fill_rect(p, 0, 8, 14, 16, SCRAP_DK, w, h)
        fill_rect(p, 0, 8, 14, 10, SCRAP, w, h)

    # Narrow torso (must read narrower than head).
    def paint_torso(p, w, h):
        fill_rect(p, 2, 4, 25, 22, olive, w, h)
        fill_rect(p, 2, 4, 25, 8, olive_lt, w, h)
        fill_rect(p, 2, 17, 25, 22, olive_dk, w, h)
        for x in (7, 14, 21):
            px(p, x, 12, olive_dk, w, h)
        # rust scarf collar
        fill_rect(p, 0, 0, 27, 6, scarf, w, h)
        fill_rect(p, 0, 0, 27, 2, shade(scarf, 1.15), w, h)
        fill_rect(p, 0, 4, 27, 6, scarf_dk, w, h)
        # belt + buckle
        fill_rect(p, 2, 16, 25, 20, SCRAP_DK, w, h)
        fill_rect(p, 11, 16, 16, 20, GOLD, w, h)

    # Left hand-block (CG style: small side mass, air-gapped from torso).
    def paint_larm(p, w, h):
        fill_rect(p, 4, 0, 14, 8, olive, w, h)
        fill_rect(p, 4, 0, 14, 2, olive_lt, w, h)
        fill_rect(p, 2, 6, 12, 12, olive_dk, w, h)
        fill_rect(p, 0, 10, 12, 18, SKIN, w, h)
        fill_rect(p, 0, 15, 12, 18, SKIN_DK, w, h)

    # Right hand + SMG (weapon = unmistakable silhouette bump).
    def paint_rarm_gun(p, w, h):
        fill_rect(p, 0, 2, 8, 10, olive, w, h)
        fill_rect(p, 0, 2, 8, 4, olive_lt, w, h)
        fill_rect(p, 4, 8, 14, 16, SKIN, w, h)
        fill_rect(p, 4, 13, 14, 16, SKIN_DK, w, h)
        fill_rect(p, 10, 4, 36, 14, SCRAP_DK, w, h)
        fill_rect(p, 10, 4, 36, 7, SCRAP, w, h)
        fill_rect(p, 12, 0, 22, 4, SCRAP_LT, w, h)
        fill_rect(p, 14, 14, 22, 22, SCRAP, w, h)
        fill_rect(p, 14, 14, 22, 16, DUST, w, h)
        fill_rect(p, 34, 2, 38, 16, AMBER_DK, w, h)
        fill_rect(p, 34, 5, 37, 13, AMBER, w, h)

    def paint_head(p, w, h):
        # Large square face — clear skin band for eyes (no bangs over dots).
        fill_rect(p, 8, 16, 45, 42, SKIN, w, h)
        fill_rect(p, 8, 36, 45, 42, SKIN_DK, w, h)
        hair_mass(p, [
            (6, 4, 47, 18, hair),
            (7, 4, 46, 10, hair_lt),
            (6, 14, 47, 18, hair_dk),
            (10, 0, 16, 5, hair_lt),
            (11, 0, 15, 2, hair_lt),
            (18, 0, 26, 5, hair),
            (19, 0, 25, 2, hair),
            (28, 0, 36, 5, hair_lt),
            (29, 0, 35, 2, hair_lt),
            (38, 0, 45, 5, hair),
            (39, 0, 44, 2, hair),
            # side locks stop above eye band so face reads clean
            (2, 8, 10, 30, hair),
            (2, 8, 6, 16, hair_lt),
            (2, 24, 10, 30, hair_dk),
            (43, 8, 51, 30, hair),
            (47, 8, 51, 16, hair_lt),
            (43, 24, 51, 30, hair_dk),
            # bang shelf — ABOVE eyes only
            (12, 14, 20, 19, hair),
            (21, 12, 29, 17, hair_lt),
            (30, 14, 38, 19, hair),
            (39, 12, 46, 17, hair_dk),
        ], w, h)
        # olive dust-hood band
        fill_rect(p, 14, 2, 39, 7, olive_dk, w, h)
        fill_rect(p, 15, 2, 38, 5, olive, w, h)
        fill_rect(p, 20, 1, 33, 3, olive_lt, w, h)
        fill_rect(p, 18, 0, 22, 3, hair_lt, w, h)
        fill_rect(p, 26, 0, 30, 3, hair, w, h)
        fill_rect(p, 34, 0, 38, 3, hair_lt, w, h)
        # 2-dot eyes on clear skin (64px-density: clean dots, no face noise)
        eyes_dots(p, 16, 35, 26, w, h, INK, size=3)
        # cheek shade + ear tip (64×64 craft density without uncanny features)
        fill_rect(p, 10, 32, 14, 36, SKIN_DK, w, h)
        fill_rect(p, 39, 32, 43, 36, SKIN_DK, w, h)
        px(p, 18, 30, SKIN_LT, w, h)
        px(p, 37, 30, SKIN_LT, w, h)
        # scarf knot pixel + vial glint on belt buckle shadow
        fill_rect(p, 22, 38, 30, 42, scarf, w, h)

    # Layout (air gaps intentional — anti-thumb):
    #   head ~x22-74  torso ~x34-62  legs 28/54  arms 10 / 62+gun
    #   crotch core gap ≈ 10px before outlines.
    _stamp(img, _outlined_part(16, 20, paint_leg), 26, 66)          # L leg
    _stamp(img, _outlined_part(16, 20, paint_leg), 54, 66)          # R leg
    _stamp(img, _outlined_part(16, 22, paint_larm), 10, 50)         # L arm OUT
    _stamp(img, _outlined_part(42, 26, paint_rarm_gun), 60, 48)     # gun RIGHT
    _stamp(img, _outlined_part(30, 26, paint_torso), 33, 46)        # narrow torso
    _stamp(img, _outlined_part(54, 46, paint_head), 21, 4)          # big head

    return img


def make_cinder() -> Image.Image:
    """Sister Cinder — dust apothecary OC.

    Same anti-thumb silhouette grammar as Rook, distinct colors/props:
      ash-auburn hair · teal cowl rim · crimson cloak · medic cross · tonic blaster.
    """
    S = HERO_SIZE
    img = new(S, S)
    drop_shadow(img, 48, 86, 24, 5, 95)

    cloak = (168, 68, 58, 255)
    cloak_lt = (200, 96, 80, 255)
    cloak_dk = (120, 44, 38, 255)
    apron = (232, 214, 186, 255)
    cross = (210, 56, 52, 255)
    teal = VIAL
    teal_lt = VIAL_LT
    hood = (48, 168, 140, 255)
    hood_lt = (100, 210, 178, 255)
    hood_dk = (32, 112, 96, 255)
    hair = (132, 78, 62, 255)
    hair_lt = (168, 108, 86, 255)
    hair_dk = (88, 48, 40, 255)
    pant = (72, 48, 42, 255)
    boot_top = (120, 70, 60, 255)

    def paint_leg(p, w, h):
        fill_rect(p, 2, 0, 12, 8, pant, w, h)
        fill_rect(p, 2, 0, 12, 2, shade(pant, 1.15), w, h)
        fill_rect(p, 0, 8, 14, 16, SCRAP_DK, w, h)
        fill_rect(p, 0, 8, 14, 10, boot_top, w, h)

    def paint_torso(p, w, h):
        fill_rect(p, 2, 2, 25, 22, cloak, w, h)
        fill_rect(p, 2, 2, 25, 7, cloak_lt, w, h)
        fill_rect(p, 2, 17, 25, 22, cloak_dk, w, h)
        fill_rect(p, 6, 6, 21, 18, apron, w, h)
        fill_rect(p, 11, 7, 16, 16, cross, w, h)
        fill_rect(p, 7, 10, 20, 13, cross, w, h)
        # vials sit on belt — keep inside torso width (don't bridge crotch)
        fill_rect(p, 5, 18, 10, 24, VIAL_DK, w, h)
        fill_rect(p, 6, 19, 9, 23, teal, w, h)
        px(p, 6, 20, teal_lt, w, h)
        fill_rect(p, 17, 18, 22, 24, AMBER_DK, w, h)
        fill_rect(p, 18, 19, 21, 23, AMBER, w, h)
        px(p, 18, 20, AMBER_LT, w, h)

    def paint_larm(p, w, h):
        # satchel OUTBOARD of arm (extends left silhouette)
        fill_rect(p, 0, 6, 8, 18, (100, 60, 42, 255), w, h)
        fill_rect(p, 0, 6, 8, 9, (136, 86, 58, 255), w, h)
        fill_rect(p, 2, 11, 6, 15, teal, w, h)
        fill_rect(p, 6, 0, 16, 10, cloak, w, h)
        fill_rect(p, 6, 0, 16, 3, cloak_lt, w, h)
        fill_rect(p, 4, 8, 14, 14, cloak_dk, w, h)
        fill_rect(p, 2, 12, 14, 20, SKIN, w, h)
        fill_rect(p, 2, 17, 14, 20, SKIN_DK, w, h)

    def paint_rarm_gun(p, w, h):
        fill_rect(p, 0, 2, 8, 10, cloak, w, h)
        fill_rect(p, 0, 2, 8, 4, cloak_lt, w, h)
        fill_rect(p, 4, 8, 14, 16, SKIN, w, h)
        fill_rect(p, 4, 13, 14, 16, SKIN_DK, w, h)
        fill_rect(p, 10, 6, 36, 16, SCRAP_DK, w, h)
        fill_rect(p, 10, 6, 36, 9, SCRAP, w, h)
        fill_rect(p, 14, 0, 26, 8, VIAL_DK, w, h)
        fill_rect(p, 15, 1, 25, 7, teal, w, h)
        px(p, 16, 2, teal_lt, w, h)
        fill_rect(p, 18, 0, 22, 2, SCRAP_LT, w, h)
        fill_rect(p, 34, 7, 38, 15, teal, w, h)
        px(p, 35, 8, teal_lt, w, h)

    def paint_head(p, w, h):
        fill_rect(p, 8, 16, 47, 42, SKIN, w, h)
        fill_rect(p, 8, 36, 47, 42, SKIN_DK, w, h)
        hair_mass(p, [
            (6, 4, 49, 18, hair),
            (7, 4, 48, 10, hair_lt),
            (6, 14, 49, 18, hair_dk),
            (10, 0, 17, 5, hair_lt),
            (19, 0, 27, 5, hair),
            (29, 0, 37, 5, hair_lt),
            (39, 0, 47, 5, hair),
            (1, 8, 10, 32, hair),
            (1, 8, 5, 16, hair_lt),
            (1, 26, 10, 32, hair_dk),
            (45, 8, 54, 32, hair),
            (50, 8, 54, 16, hair_lt),
            (45, 26, 54, 32, hair_dk),
            (12, 14, 20, 19, hair),
            (21, 12, 30, 17, hair_lt),
            (31, 14, 39, 19, hair),
            (40, 12, 48, 17, hair_dk),
        ], w, h)
        # teal cowl rim — thin band + side clips (not a helmet blob)
        fill_rect(p, 12, 2, 43, 7, hood, w, h)
        fill_rect(p, 13, 2, 42, 4, hood_lt, w, h)
        fill_rect(p, 12, 5, 43, 7, hood_dk, w, h)
        fill_rect(p, 2, 12, 7, 22, hood, w, h)
        fill_rect(p, 48, 12, 53, 22, hood, w, h)
        fill_rect(p, 2, 12, 7, 15, hood_lt, w, h)
        fill_rect(p, 48, 12, 53, 15, hood_lt, w, h)
        fill_rect(p, 18, 0, 23, 3, hair_lt, w, h)
        fill_rect(p, 27, 0, 32, 3, hair, w, h)
        fill_rect(p, 36, 0, 41, 3, hair_lt, w, h)
        fill_rect(p, 4, 12, 10, 28, hair, w, h)
        fill_rect(p, 45, 12, 51, 28, hair, w, h)
        eyes_dots(p, 17, 37, 26, w, h, INK, size=3)
        fill_rect(p, 11, 32, 15, 36, SKIN_DK, w, h)
        fill_rect(p, 42, 32, 46, 36, SKIN_DK, w, h)
        px(p, 19, 30, SKIN_LT, w, h)
        px(p, 39, 30, SKIN_LT, w, h)

    _stamp(img, _outlined_part(16, 20, paint_leg), 26, 66)
    _stamp(img, _outlined_part(16, 20, paint_leg), 54, 66)
    _stamp(img, _outlined_part(18, 24, paint_larm), 8, 50)
    _stamp(img, _outlined_part(42, 20, paint_rarm_gun), 60, 50)
    _stamp(img, _outlined_part(30, 28, paint_torso), 33, 44)
    _stamp(img, _outlined_part(56, 46, paint_head), 20, 4)

    return img


# ---------------------------------------------------------------------------
# Pets — Noel (64×64, face markings from approved pixelate/face_pixel_64)
# ---------------------------------------------------------------------------

# Noel fur palette (cream fluff + dark eye-mask + black nose — Dust Apothecary)
NOEL_CREAM = (232, 224, 210, 255)
NOEL_CREAM_LT = (246, 240, 230, 255)
NOEL_CREAM_DK = (198, 186, 168, 255)
NOEL_TAN = (188, 168, 140, 255)
NOEL_MASK = (42, 34, 32, 255)
NOEL_MASK_LT = (68, 56, 52, 255)
NOEL_NOSE = (22, 16, 14, 255)
NOEL_COLLAR = (156, 72, 42, 255)
NOEL_TAG = (220, 180, 70, 255)


def make_noel(rampage: bool = False) -> Image.Image:
    """Noel — territorial fluff-mask terrier OC.

    Face grammar from approved 64×64 dog pixelation: cream curly mass,
    dark patch around eyes, big black nose, light muzzle. Body is chibi
    with separated head / torso / legs / tail (anti-thumb).
    """
    S = PET_SIZE
    img = new(S, S)
    drop_shadow(img, 32, 58, 16, 4, 90)

    fur = NOEL_CREAM
    fur_lt = NOEL_CREAM_LT
    fur_dk = NOEL_CREAM_DK
    if rampage:
        ## Rust-tinted enrage tint on the cream (readable rampage state).
        fur = (236, 190, 170, 255)
        fur_lt = (250, 214, 196, 255)
        fur_dk = (190, 130, 110, 255)

    def paint_leg(p, w, h):
        fill_rect(p, 1, 0, 7, 10, fur_dk, w, h)
        fill_rect(p, 1, 0, 7, 3, fur, w, h)
        fill_rect(p, 0, 8, 8, 12, NOEL_MASK, w, h)
        fill_rect(p, 0, 8, 8, 9, NOEL_MASK_LT, w, h)

    def paint_tail(p, w, h):
        ## Fluffy curl up and right
        fill_rect(p, 2, 6, 10, 14, fur, w, h)
        fill_rect(p, 4, 2, 12, 10, fur_lt, w, h)
        fill_rect(p, 6, 0, 13, 5, fur, w, h)
        fill_rect(p, 8, 0, 13, 2, fur_lt, w, h)
        fill_rect(p, 2, 10, 6, 14, fur_dk, w, h)

    def paint_body(p, w, h):
        fill_ellipse(p, 2, 2, 25, 22, fur, w, h)
        fill_ellipse(p, 4, 4, 23, 14, fur_lt, w, h)
        fill_ellipse(p, 4, 14, 23, 22, fur_dk, w, h)
        ## curly fluff bumps (64px density)
        for cx, cy in ((4, 6), (8, 3), (14, 2), (20, 4), (24, 8), (6, 16), (22, 16)):
            fill_rect(p, cx, cy, cx + 2, cy + 2, fur_lt, w, h)
        ## collar + gold tag
        fill_rect(p, 6, 16, 21, 20, NOEL_COLLAR if not rampage else RUST, w, h)
        fill_rect(p, 6, 16, 21, 17, shade(NOEL_COLLAR if not rampage else RUST, 1.2), w, h)
        fill_rect(p, 12, 18, 16, 23, NOEL_TAG, w, h)
        fill_rect(p, 13, 19, 15, 21, AMBER_LT, w, h)

    def paint_head(p, w, h):
        ## Big round cream head — dominant silhouette mass (64px density)
        fill_ellipse(p, 4, 8, 35, 36, fur, w, h)
        fill_ellipse(p, 6, 10, 33, 24, fur_lt, w, h)
        fill_ellipse(p, 8, 26, 31, 36, fur_dk, w, h)
        ## Wiry/curly top — stair blocks matching face_pixel_64 fluff
        hair_mass(p, [
            (10, 2, 16, 10, fur_lt),
            (16, 0, 24, 9, fur),
            (22, 2, 30, 10, fur_lt),
            (8, 6, 12, 14, fur),
            (28, 6, 34, 14, fur),
            (12, 4, 18, 8, fur_lt),
            (20, 1, 26, 6, fur_lt),
            (14, 0, 18, 3, fur_lt),
            (24, 0, 28, 3, fur),
            (9, 8, 13, 12, NOEL_TAN if not rampage else fur_dk),
            (27, 8, 31, 12, NOEL_TAN if not rampage else fur_dk),
        ], w, h)
        ## floppy ears (side masses)
        fill_ellipse(p, 0, 10, 10, 26, fur_dk, w, h)
        fill_ellipse(p, 1, 12, 8, 22, fur, w, h)
        fill_ellipse(p, 2, 14, 6, 20, fur_lt, w, h)
        fill_ellipse(p, 30, 10, 39, 26, fur_dk, w, h)
        fill_ellipse(p, 32, 12, 38, 22, fur, w, h)
        fill_ellipse(p, 33, 14, 37, 20, fur_lt, w, h)
        ## Asymmetric dark eye-mask (ref: heavier patch on viewer's left)
        fill_ellipse(p, 7, 15, 19, 27, NOEL_MASK, w, h)
        fill_ellipse(p, 21, 16, 31, 26, NOEL_MASK_LT, w, h)
        fill_ellipse(p, 9, 16, 17, 23, NOEL_MASK_LT, w, h)
        fill_ellipse(p, 23, 17, 29, 23, shade(NOEL_MASK_LT, 1.15), w, h)
        ## Cream muzzle — high contrast vs mask (face_pixel_64 grammar)
        fill_ellipse(p, 11, 23, 29, 35, NOEL_CREAM_LT, w, h)
        fill_ellipse(p, 13, 25, 27, 33, WHITE, w, h)
        fill_rect(p, 14, 28, 18, 32, shade(WHITE, 0.92), w, h)
        fill_rect(p, 22, 28, 26, 32, shade(WHITE, 0.92), w, h)
        ## eyes — clean dark dots (cute, not uncanny)
        eye_c = INK if not rampage else (200, 40, 30, 255)
        eyes_dots(p, 11, 25, 18, w, h, eye_c, size=3)
        if rampage:
            px(p, 12, 18, AMBER_LT, w, h)
            px(p, 26, 18, AMBER_LT, w, h)
        ## big black nose low on muzzle
        fill_ellipse(p, 16, 26, 24, 32, NOEL_NOSE, w, h)
        fill_rect(p, 18, 27, 20, 28, SCRAP_LT, w, h)

    # Layout: legs with crotch gap · body · head on top · tail out back
    _stamp(img, _outlined_part(10, 14, paint_leg, thickness=2), 18, 46)
    _stamp(img, _outlined_part(10, 14, paint_leg, thickness=2), 36, 46)
    _stamp(img, _outlined_part(16, 16, paint_tail, thickness=2), 44, 34)
    _stamp(img, _outlined_part(28, 26, paint_body, thickness=2), 18, 30)
    _stamp(img, _outlined_part(40, 40, paint_head, thickness=2), 12, 2)

    return img


def make_dust_hound() -> Image.Image:
    """Dust Hound — scrap-mutt filler pet (Hunt stub). Leaner, dust-brown."""
    S = PET_SIZE
    img = new(S, S)
    drop_shadow(img, 32, 58, 15, 4, 90)
    coat = DUST
    coat_lt = DUST_LT
    coat_dk = DUST_DK

    def paint_leg(p, w, h):
        fill_rect(p, 1, 0, 6, 10, coat_dk, w, h)
        fill_rect(p, 0, 8, 7, 12, SCRAP_DK, w, h)

    def paint_body(p, w, h):
        fill_ellipse(p, 2, 2, 22, 18, coat, w, h)
        fill_ellipse(p, 4, 3, 20, 10, coat_lt, w, h)
        fill_rect(p, 6, 12, 18, 16, SCRAP_DK, w, h)
        fill_rect(p, 10, 13, 14, 17, VIAL, w, h)

    def paint_head(p, w, h):
        fill_ellipse(p, 4, 8, 28, 30, coat, w, h)
        fill_ellipse(p, 6, 10, 26, 20, coat_lt, w, h)
        fill_rect(p, 0, 10, 8, 22, coat_dk, w, h)
        fill_rect(p, 24, 10, 32, 22, coat_dk, w, h)
        fill_ellipse(p, 10, 20, 22, 28, (210, 190, 160, 255), w, h)
        eyes_dots(p, 10, 20, 15, w, h, INK, size=2)
        fill_ellipse(p, 13, 22, 19, 26, NOEL_NOSE, w, h)

    def paint_tail(p, w, h):
        fill_rect(p, 0, 4, 8, 10, coat, w, h)
        fill_rect(p, 4, 0, 10, 6, coat_lt, w, h)

    _stamp(img, _outlined_part(9, 14, paint_leg, thickness=2), 18, 46)
    _stamp(img, _outlined_part(9, 14, paint_leg, thickness=2), 34, 46)
    _stamp(img, _outlined_part(12, 12, paint_tail, thickness=2), 42, 34)
    _stamp(img, _outlined_part(26, 22, paint_body, thickness=2), 18, 32)
    _stamp(img, _outlined_part(34, 34, paint_head, thickness=2), 14, 4)
    return img


# ---------------------------------------------------------------------------
# Enemies — unique silhouettes at wide FOV
# ---------------------------------------------------------------------------

def make_raider() -> Image.Image:
    """Scrappy ranged scavenger — rag hood, rust plates, pistol. Clean 2-dot face."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 12, 3, 95)

    # boots / legs — wide crotch gap (anti-thumb)
    fill_rect(p, 12, 34, 18, 41, SCRAP_DK, w, h)
    fill_rect(p, 29, 34, 35, 41, SCRAP_DK, w, h)
    fill_rect(p, 12, 34, 18, 36, SCRAP, w, h)
    fill_rect(p, 29, 34, 35, 36, SCRAP, w, h)
    fill_rect(p, 13, 30, 18, 35, DUST_DK, w, h)
    fill_rect(p, 29, 30, 34, 35, DUST_DK, w, h)

    # body rust scrap (narrower so arms/legs read)
    fill_rect(p, 15, 16, 32, 32, RUST, w, h)
    fill_rect(p, 15, 16, 32, 20, shade(RUST, 1.18), w, h)
    fill_rect(p, 15, 28, 32, 32, RUST_DK, w, h)
    fill_rect(p, 17, 18, 24, 26, DUST_DK, w, h)
    fill_rect(p, 17, 18, 24, 20, DUST, w, h)
    # shoulder plate (left side mass)
    fill_rect(p, 7, 14, 15, 26, SCRAP, w, h)
    fill_rect(p, 7, 14, 15, 17, SCRAP_LT, w, h)
    # ammo pouch (right hip, not bridging crotch)
    fill_rect(p, 30, 24, 37, 32, DUST_DK, w, h)
    fill_rect(p, 30, 24, 37, 26, DUST, w, h)

    # big head
    fill_rect(p, 15, 4, 32, 17, (178, 130, 98, 255), w, h)
    fill_rect(p, 15, 13, 32, 17, (148, 104, 78, 255), w, h)
    # chunky brown hair mass under rag
    hair_r = (78, 52, 36, 255)
    hair_rl = (100, 68, 46, 255)
    fill_rect(p, 14, 2, 33, 8, hair_r, w, h)
    fill_rect(p, 15, 2, 32, 4, hair_rl, w, h)
    fill_rect(p, 16, 1, 20, 3, hair_rl, w, h)
    fill_rect(p, 27, 1, 31, 3, hair_r, w, h)
    # rag hood band
    fill_rect(p, 12, 1, 35, 5, DUST_DK, w, h)
    fill_rect(p, 12, 1, 35, 2, DUST, w, h)
    fill_rect(p, 12, 6, 16, 14, DUST_DK, w, h)
    fill_rect(p, 33, 5, 36, 11, DUST_DK, w, h)
    # two hot eye dots (no brows/mouth/sclera)
    eyes_dots(p, 19, 27, 10, w, h, (230, 70, 40, 255), size=2)

    # rusty pistol
    fill_rect(p, 33, 20, 46, 25, SCRAP_DK, w, h)
    fill_rect(p, 33, 20, 46, 22, SCRAP, w, h)
    fill_rect(p, 36, 21, 40, 23, DUST, w, h)
    fill_rect(p, 42, 18, 46, 26, RUST_DK, w, h)
    fill_rect(p, 33, 23, 36, 27, (150, 110, 85, 255), w, h)

    return add_outline(img, thickness=2)


def make_charger() -> Image.Image:
    """Lean rusher — amber goggle visor, chunky hair mass, scrap blade."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 11, 3, 95)

    # legs with clear crotch gap
    fill_rect(p, 11, 33, 17, 41, (48, 32, 22, 255), w, h)
    fill_rect(p, 28, 33, 34, 41, (48, 32, 22, 255), w, h)

    # lean torso (narrower than head)
    fill_rect(p, 15, 15, 30, 33, (196, 112, 52, 255), w, h)
    fill_rect(p, 15, 15, 30, 19, (230, 145, 70, 255), w, h)
    fill_rect(p, 15, 28, 30, 33, (150, 80, 40, 255), w, h)
    # shoulder spikes (blocky side masses)
    fill_rect(p, 8, 12, 15, 22, SCRAP_LT, w, h)
    fill_rect(p, 9, 9, 12, 12, SCRAP_LT, w, h)
    fill_rect(p, 30, 13, 36, 22, SCRAP, w, h)

    # head
    fill_rect(p, 15, 3, 32, 16, (178, 134, 104, 255), w, h)
    fill_rect(p, 15, 12, 32, 16, (148, 108, 82, 255), w, h)
    # chunky spiked hair mass (stair blocks, not strands)
    hair_c = (96, 54, 34, 255)
    hair_cl = (120, 70, 42, 255)
    fill_rect(p, 14, 1, 33, 7, hair_c, w, h)
    fill_rect(p, 15, 1, 32, 3, hair_cl, w, h)
    fill_rect(p, 16, 0, 19, 2, hair_cl, w, h)
    fill_rect(p, 21, 0, 25, 2, hair_c, w, h)
    fill_rect(p, 27, 0, 31, 2, hair_cl, w, h)
    fill_rect(p, 12, 3, 14, 7, hair_c, w, h)
    fill_rect(p, 33, 3, 35, 7, hair_c, w, h)
    # amber goggle visor (clean geometric — CG helmet language)
    fill_rect(p, 13, 7, 34, 13, SCRAP_DK, w, h)
    fill_rect(p, 15, 7, 22, 13, AMBER, w, h)
    fill_rect(p, 25, 7, 32, 13, AMBER, w, h)
    fill_rect(p, 16, 8, 21, 11, AMBER_LT, w, h)
    fill_rect(p, 26, 8, 31, 11, AMBER_LT, w, h)

    # scrap blade
    fill_rect(p, 29, 17, 47, 22, SCRAP_LT, w, h)
    fill_rect(p, 29, 17, 47, 18, (245, 245, 250, 255), w, h)
    fill_rect(p, 43, 15, 47, 24, SCRAP, w, h)
    fill_rect(p, 30, 20, 35, 26, VIAL_DK, w, h)
    fill_rect(p, 31, 21, 34, 24, VIAL, w, h)
    fill_rect(p, 28, 20, 32, 26, (150, 110, 85, 255), w, h)

    return add_outline(img, thickness=2)


def make_brute() -> Image.Image:
    """Bulky armored tank — pauldrons, helm visor, scrap shotgun."""
    img = new(64, 64)
    p = img.load()
    w, h = 64, 64
    drop_shadow(img, 32, 58, 18, 5, 110)

    armor = (88, 98, 120, 255)
    armor_lt = (124, 136, 162, 255)
    armor_dk = (56, 64, 82, 255)

    # boots
    fill_rect(p, 16, 48, 26, 58, SCRAP_DK, w, h)
    fill_rect(p, 38, 48, 48, 58, SCRAP_DK, w, h)
    fill_rect(p, 16, 48, 26, 51, SCRAP, w, h)
    fill_rect(p, 38, 48, 48, 51, SCRAP, w, h)
    fill_rect(p, 22, 54, 26, 58, SCRAP_LT, w, h)
    fill_rect(p, 44, 54, 48, 58, SCRAP_LT, w, h)

    # heavy legs
    fill_rect(p, 18, 42, 28, 50, armor_dk, w, h)
    fill_rect(p, 36, 42, 46, 50, armor_dk, w, h)

    # heavy armor body
    fill_rect(p, 12, 20, 51, 48, armor, w, h)
    fill_rect(p, 12, 20, 51, 28, armor_lt, w, h)
    fill_rect(p, 12, 42, 51, 48, armor_dk, w, h)
    # rivets
    for x in (18, 28, 38, 46):
        px(p, x, 26, SCRAP_DK, w, h)
        px(p, x, 36, SCRAP_DK, w, h)
    # copper vial plate center (apothecary brand)
    fill_rect(p, 26, 30, 37, 42, VIAL_DK, w, h)
    fill_rect(p, 27, 31, 36, 40, VIAL, w, h)
    fill_rect(p, 28, 32, 35, 35, VIAL_LT, w, h)
    fill_rect(p, 30, 36, 33, 39, (20, 80, 60, 255), w, h)  # seal mark

    # huge pauldrons (bulky silhouette)
    fill_rect(p, 4, 16, 16, 34, armor_dk, w, h)
    fill_rect(p, 4, 16, 16, 22, armor, w, h)
    fill_rect(p, 5, 17, 10, 20, armor_lt, w, h)
    fill_rect(p, 48, 16, 60, 34, armor_dk, w, h)
    fill_rect(p, 48, 16, 60, 22, armor, w, h)
    fill_rect(p, 52, 17, 58, 20, armor_lt, w, h)
    # pauldron spikes
    px(p, 8, 14, SCRAP_LT, w, h)
    px(p, 10, 13, SCRAP_LT, w, h)
    px(p, 54, 14, SCRAP_LT, w, h)
    px(p, 56, 13, SCRAP_LT, w, h)

    # helm
    fill_rect(p, 20, 2, 43, 22, (70, 76, 92, 255), w, h)
    fill_rect(p, 20, 2, 43, 8, (108, 116, 138, 255), w, h)
    fill_rect(p, 22, 4, 28, 8, armor_lt, w, h)
    # glowing red visor bar (FOV identity)
    fill_rect(p, 22, 11, 41, 16, (230, 55, 40, 255), w, h)
    fill_rect(p, 22, 11, 41, 12, (255, 150, 90, 255), w, h)
    fill_rect(p, 24, 13, 28, 15, (255, 220, 180, 255), w, h)
    # chin guard
    fill_rect(p, 24, 17, 39, 22, armor_dk, w, h)

    # scrap shotgun
    fill_rect(p, 48, 34, 62, 42, SCRAP_DK, w, h)
    fill_rect(p, 48, 34, 62, 37, SCRAP, w, h)
    fill_rect(p, 56, 30, 62, 44, SCRAP_LT, w, h)
    fill_rect(p, 50, 41, 55, 47, (60, 40, 32, 255), w, h)
    fill_rect(p, 46, 36, 50, 42, (150, 110, 85, 255), w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Mount
# ---------------------------------------------------------------------------

def make_skate() -> Image.Image:
    """Scrap skateboard with vial strap + taped trucks."""
    img = new(48, 24)
    p = img.load()
    w, h = 48, 24
    # deck
    fill_rect(p, 3, 8, 44, 16, (70, 50, 34, 255), w, h)
    fill_rect(p, 3, 8, 44, 11, (160, 100, 48, 255), w, h)
    fill_rect(p, 5, 6, 42, 10, (120, 78, 40, 255), w, h)
    # grip tape strip
    fill_rect(p, 8, 9, 39, 11, SCRAP_DK, w, h)
    # nose/tail kick
    fill_rect(p, 2, 7, 5, 12, (140, 90, 48, 255), w, h)
    fill_rect(p, 42, 7, 45, 12, (140, 90, 48, 255), w, h)
    # herb / vial strap
    fill_rect(p, 17, 3, 30, 9, VIAL_DK, w, h)
    fill_rect(p, 18, 4, 29, 8, VIAL, w, h)
    px(p, 19, 5, VIAL_LT, w, h)
    fill_rect(p, 21, 2, 26, 4, SCRAP, w, h)
    # trucks
    fill_rect(p, 9, 14, 16, 18, SCRAP, w, h)
    fill_rect(p, 31, 14, 38, 18, SCRAP, w, h)
    fill_rect(p, 10, 14, 15, 15, DUST, w, h)  # tape
    fill_rect(p, 32, 14, 37, 15, DUST, w, h)
    # wheels
    fill_ellipse(p, 7, 15, 16, 22, SCRAP_DK, w, h)
    fill_ellipse(p, 31, 15, 40, 22, SCRAP_DK, w, h)
    fill_ellipse(p, 9, 17, 14, 20, AMBER_DK, w, h)
    fill_ellipse(p, 33, 17, 38, 20, AMBER_DK, w, h)
    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Extract pads — thick rings that pop at wide FOV
# ---------------------------------------------------------------------------

def make_pad(open_state: bool) -> Image.Image:
    img = new(96, 96)
    p = img.load()
    w, h = 96, 96
    ring = AMBER if open_state else (100, 88, 76, 255)
    ring_lt = AMBER_LT if open_state else (130, 118, 105, 255)
    ring_dk = AMBER_DK if open_state else (70, 62, 54, 255)
    fill_c = (210, 150, 45, 140) if open_state else (48, 42, 36, 110)

    # outer disc (solid enough to find at distance)
    fill_ellipse(p, 8, 8, 87, 87, fill_c, w, h)
    # chunky ring (4–5 px) — FOV readability
    for ang in range(0, 360, 2):
        rad = math.radians(ang)
        for r in range(34, 40):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            col = ring_lt if r in (35, 36) and open_state else (ring_dk if r >= 38 else ring)
            px(p, x, y, col, w, h)
    # inner ring
    for ang in range(0, 360, 3):
        rad = math.radians(ang)
        for r in (16, 17, 18):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            px(p, x, y, ring, w, h)

    # beacon post
    fill_rect(p, 44, 12, 51, 50, SCRAP_DK, w, h)
    fill_rect(p, 44, 12, 51, 18, SCRAP, w, h)
    fill_rect(p, 45, 20, 50, 48, SCRAP, w, h)
    lamp = AMBER_LT if open_state else SCRAP_LT
    fill_ellipse(p, 38, 4, 57, 20, lamp, w, h)
    if open_state:
        fill_ellipse(p, 42, 8, 53, 16, (255, 250, 200, 255), w, h)
        # glow rays (chunky, few)
        for dx, dy in ((-10, 2), (10, 2), (0, -8), (-7, -5), (7, -5)):
            px(p, 48 + dx, 10 + dy, AMBER_LT, w, h)

    # vial markers (larger for FOV)
    for bx in (18, 68):
        fill_rect(p, bx, 48, bx + 10, 64, VIAL_DK, w, h)
        fill_rect(p, bx + 1, 49, bx + 9, 60, VIAL if open_state else SCRAP, w, h)
        if open_state:
            fill_rect(p, bx + 2, 50, bx + 5, 56, VIAL_LT, w, h)
        fill_rect(p, bx + 2, 46, bx + 8, 48, SCRAP, w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Props / breakables
# ---------------------------------------------------------------------------

def make_wreck() -> Image.Image:
    img = new(64, 48)
    p = img.load()
    w, h = 64, 48
    drop_shadow(img, 32, 42, 22, 4, 80)
    d = ImageDraw.Draw(img)
    d.polygon([(6, 34), (18, 14), (50, 12), (58, 32), (46, 38), (12, 40)], fill=RUST_DK)
    fill_rect(p, 8, 28, 54, 38, RUST, w, h)
    fill_rect(p, 8, 28, 54, 30, shade(RUST, 1.2), w, h)
    fill_rect(p, 22, 16, 40, 26, (40, 50, 55, 255), w, h)
    fill_rect(p, 24, 17, 30, 22, (70, 90, 100, 200), w, h)
    fill_ellipse(p, 12, 30, 24, 42, SCRAP_DK, w, h)
    fill_ellipse(p, 44, 28, 56, 40, SCRAP_DK, w, h)
    fill_ellipse(p, 15, 33, 21, 39, SCRAP, w, h)
    fill_ellipse(p, 47, 31, 53, 37, SCRAP, w, h)
    fill_rect(p, 30, 8, 36, 16, VIAL_DK, w, h)
    fill_rect(p, 31, 9, 35, 14, VIAL, w, h)
    px(p, 32, 10, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_herb_crate() -> Image.Image:
    """Breakable — chunky wood + bright vial lid (FOV pop)."""
    img = new(40, 40)
    p = img.load()
    w, h = 40, 40
    drop_shadow(img, 20, 35, 12, 3, 75)
    fill_rect(p, 5, 12, 34, 34, (118, 78, 42, 255), w, h)
    fill_rect(p, 5, 12, 34, 16, (158, 110, 62, 255), w, h)
    fill_rect(p, 5, 30, 34, 34, (86, 56, 30, 255), w, h)
    fill_rect(p, 5, 20, 34, 21, (70, 46, 24, 255), w, h)
    fill_rect(p, 5, 26, 34, 27, (70, 46, 24, 255), w, h)
    # sealed vial on top — tall for silhouette
    fill_rect(p, 14, 2, 25, 14, VIAL_DK, w, h)
    fill_rect(p, 15, 3, 24, 12, VIAL, w, h)
    fill_rect(p, 16, 4, 20, 9, VIAL_LT, w, h)
    fill_rect(p, 15, 1, 24, 3, SCRAP, w, h)
    fill_rect(p, 17, 0, 22, 2, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_vial_crate() -> Image.Image:
    img = new(40, 40)
    p = img.load()
    w, h = 40, 40
    drop_shadow(img, 20, 35, 13, 3, 75)
    fill_rect(p, 5, 16, 34, 34, SCRAP, w, h)
    fill_rect(p, 5, 16, 34, 20, SCRAP_LT, w, h)
    fill_rect(p, 5, 30, 34, 34, SCRAP_DK, w, h)
    for i, col in enumerate([VIAL, AMBER, (90, 140, 210, 255)]):
        x = 8 + i * 9
        fill_rect(p, x, 4, x + 6, 18, shade(col, 0.65), w, h)
        fill_rect(p, x + 1, 5, x + 5, 16, col, w, h)
        px(p, x + 1, 6, shade(col, 1.35), w, h)
        fill_rect(p, x + 1, 3, x + 5, 5, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_apothecary_chest() -> Image.Image:
    img = new(48, 36)
    p = img.load()
    w, h = 48, 36
    drop_shadow(img, 24, 32, 16, 3, 75)
    fill_rect(p, 4, 12, 43, 32, (96, 58, 36, 255), w, h)
    fill_rect(p, 4, 12, 43, 16, (138, 86, 52, 255), w, h)
    fill_rect(p, 4, 26, 43, 32, (70, 42, 26, 255), w, h)
    fill_rect(p, 4, 18, 43, 19, (50, 30, 18, 255), w, h)
    fill_rect(p, 20, 17, 27, 24, GOLD, w, h)
    fill_rect(p, 21, 18, 26, 22, AMBER, w, h)
    fill_rect(p, 34, 3, 42, 14, VIAL_DK, w, h)
    fill_rect(p, 35, 4, 41, 12, VIAL, w, h)
    px(p, 36, 5, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_scrap_drum() -> Image.Image:
    img = new(40, 48)
    p = img.load()
    w, h = 40, 48
    drop_shadow(img, 20, 44, 13, 3, 75)
    fill_rect(p, 8, 10, 31, 42, RUST, w, h)
    fill_rect(p, 8, 10, 31, 15, shade(RUST, 1.2), w, h)
    fill_rect(p, 8, 36, 31, 42, RUST_DK, w, h)
    for y in (18, 26, 32):
        fill_rect(p, 8, y, 31, y + 1, RUST_DK, w, h)
    fill_rect(p, 14, 2, 25, 12, VIAL_DK, w, h)
    fill_rect(p, 15, 3, 24, 10, VIAL, w, h)
    px(p, 16, 4, VIAL_LT, w, h)
    px(p, 18, 14, VIAL, w, h)
    px(p, 18, 16, VIAL_DK, w, h)
    return add_outline(img, thickness=2)


def make_scrap_pile() -> Image.Image:
    img = new(48, 32)
    p = img.load()
    w, h = 48, 32
    drop_shadow(img, 24, 28, 18, 3, 70)
    fill_ellipse(p, 4, 12, 44, 30, (75, 50, 35, 255), w, h)
    fill_rect(p, 10, 8, 22, 18, SCRAP, w, h)
    fill_rect(p, 10, 8, 22, 11, SCRAP_LT, w, h)
    fill_rect(p, 24, 6, 38, 16, RUST, w, h)
    fill_rect(p, 24, 6, 38, 9, shade(RUST, 1.15), w, h)
    fill_ellipse(p, 18, 3, 28, 12, VIAL_DK, w, h)
    fill_ellipse(p, 20, 4, 26, 10, VIAL, w, h)
    px(p, 21, 5, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_tower() -> Image.Image:
    img = new(40, 72)
    p = img.load()
    w, h = 40, 72
    drop_shadow(img, 20, 68, 10, 3, 70)
    fill_rect(p, 12, 22, 27, 68, SCRAP, w, h)
    fill_rect(p, 12, 22, 27, 28, SCRAP_LT, w, h)
    fill_rect(p, 12, 58, 27, 68, SCRAP_DK, w, h)
    for y in range(30, 56, 6):
        fill_rect(p, 12, y, 27, y, SCRAP_DK, w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(8, 26), (20, 4), (32, 26)], fill=RUST)
    fill_rect(p, 16, 8, 24, 16, AMBER, w, h)
    fill_rect(p, 17, 9, 23, 14, AMBER_LT, w, h)
    fill_rect(p, 18, 1, 22, 6, VIAL, w, h)
    return add_outline(img, thickness=2)


def make_bullet() -> Image.Image:
    """Slightly larger amber→vial slug for FOV visibility."""
    img = new(14, 8)
    p = img.load()
    w, h = 14, 8
    fill_rect(p, 1, 2, 9, 5, AMBER, w, h)
    fill_rect(p, 1, 2, 9, 3, AMBER_LT, w, h)
    fill_rect(p, 9, 2, 12, 5, VIAL, w, h)
    px(p, 12, 3, VIAL_LT, w, h)
    px(p, 12, 4, VIAL, w, h)
    return add_outline(img, thickness=1)


# ---------------------------------------------------------------------------
# Decor
# ---------------------------------------------------------------------------

def make_rock(seed: int, size: int) -> Image.Image:
    rnd = random.Random(seed)
    img = new(size, size)
    d = ImageDraw.Draw(img)
    drop_shadow(img, size // 2, int(size * 0.78), int(size * 0.4), int(size * 0.12), 70)
    pts = []
    for i in range(8):
        a = i / 8 * 6.283
        r = size * 0.34 * rnd.uniform(0.78, 1.0)
        pts.append((size / 2 + math.cos(a) * r, size * 0.55 + math.sin(a) * r * 0.7))
    d.polygon(pts, fill=(104, 92, 82, 255))
    top = [(x, y - 2) for x, y in pts if y < size * 0.55]
    if len(top) >= 3:
        d.polygon(top, fill=(134, 120, 106, 255))
    return add_outline(img, thickness=2)


def make_dead_bush() -> Image.Image:
    img = new(32, 32)
    d = ImageDraw.Draw(img)
    drop_shadow(img, 16, 27, 10, 3, 60)
    for ang, ln in [(-60, 12), (-100, 14), (-130, 11), (-80, 9), (-30, 9), (-150, 8)]:
        a = math.radians(ang)
        x2 = 16 + math.cos(a) * ln
        y2 = 26 + math.sin(a) * ln
        d.line([(16, 26), (x2, y2)], fill=(98, 72, 48, 255), width=2)
        d.line([(x2, y2), (x2 + 2, y2 - 2)], fill=(116, 86, 58, 255), width=1)
    return add_outline(img, thickness=1)


def make_bones() -> Image.Image:
    img = new(32, 20)
    p = img.load()
    w, h = 32, 20
    drop_shadow(img, 16, 15, 12, 3, 55)
    d = ImageDraw.Draw(img)
    d.line([(5, 12), (25, 8)], fill=BONE, width=3)
    fill_ellipse(p, 3, 10, 7, 14, BONE, w, h)
    fill_ellipse(p, 24, 6, 28, 10, BONE, w, h)
    fill_ellipse(p, 18, 11, 26, 18, BONE, w, h)
    px(p, 20, 14, SCRAP_DK, w, h)
    px(p, 23, 14, SCRAP_DK, w, h)
    return add_outline(img, thickness=1)


def make_tire() -> Image.Image:
    img = new(28, 22)
    p = img.load()
    w, h = 28, 22
    drop_shadow(img, 14, 17, 11, 3, 60)
    fill_ellipse(p, 3, 4, 24, 18, SCRAP_DK, w, h)
    fill_ellipse(p, 9, 8, 18, 14, DUST, w, h)
    fill_ellipse(p, 11, 9, 16, 13, DUST_LT, w, h)
    return add_outline(img, thickness=2)


def make_cactus() -> Image.Image:
    img = new(28, 40)
    p = img.load()
    w, h = 28, 40
    drop_shadow(img, 14, 36, 9, 3, 60)
    green = (92, 120, 70, 255)
    dark = (70, 94, 54, 255)
    lt = (120, 148, 90, 255)
    fill_rect(p, 11, 6, 17, 35, green, w, h)
    fill_rect(p, 11, 6, 17, 10, lt, w, h)
    fill_rect(p, 13, 8, 13, 33, dark, w, h)
    fill_rect(p, 4, 14, 9, 26, green, w, h)
    fill_rect(p, 6, 24, 12, 27, green, w, h)
    fill_rect(p, 19, 10, 24, 22, green, w, h)
    fill_rect(p, 16, 19, 22, 22, green, w, h)
    px(p, 15, 4, (220, 120, 90, 255), w, h)
    return add_outline(img, thickness=2)


def make_sign() -> Image.Image:
    img = new(26, 40)
    p = img.load()
    w, h = 26, 40
    drop_shadow(img, 13, 36, 7, 2, 55)
    fill_rect(p, 12, 10, 14, 36, (86, 62, 42, 255), w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(3, 8), (21, 6), (23, 13), (5, 16)], fill=(150, 112, 70, 255))
    fill_rect(p, 7, 9, 17, 10, (90, 50, 35, 255), w, h)
    px(p, 10, 11, RUST, w, h)
    px(p, 14, 11, RUST, w, h)
    return add_outline(img, thickness=1)


# ---------------------------------------------------------------------------
# Ground tiles — low-frequency soft patches (readable, not noisy at FOV)
# ---------------------------------------------------------------------------

def _soft_blob(d: ImageDraw.ImageDraw, cx: int, cy: int, rw: int, rh: int, col) -> None:
    d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=col)


def ground_tile(seed: int, kind: str = "plain") -> Image.Image:
    """Wide-FOV ground: soft value patches, sparse mid-scale grit — no specklemush."""
    rnd = random.Random(seed)
    base = DUST[:3]
    img = Image.new("RGBA", (64, 64), base + (255,))
    d = ImageDraw.Draw(img)

    # large soft value patches (read as terrain when zoomed out)
    for _ in range(4):
        cx, cy = rnd.randrange(8, 56), rnd.randrange(8, 56)
        rw, rh = rnd.randint(6, 14), rnd.randint(4, 10)
        k = rnd.choice([0.88, 0.92, 1.06, 1.10])
        _soft_blob(d, cx, cy, rw, rh, shade(base + (255,), k))

    # sparse mid-scale grit blocks (not 160 single pixels)
    for _ in range(6):
        x, y = rnd.randrange(2, 58), rnd.randrange(2, 58)
        c = rnd.choice([DUST_DK, shade(DUST + (255,), 0.85), (140, 100, 60, 255)])
        bw, bh = rnd.randint(2, 4), rnd.randint(1, 3)
        d.rectangle([x, y, x + bw, y + bh], fill=c)

    if kind == "pebbles":
        for _ in range(5):
            x, y = rnd.randrange(4, 56), rnd.randrange(4, 56)
            r = rnd.choice([2, 2, 3])
            d.ellipse([x, y, x + r * 2, y + r], fill=shade(base + (255,), 0.78))
            d.ellipse([x + 1, y, x + r, y + r - 1], fill=shade(base + (255,), 0.95))
    elif kind == "cracks":
        for _ in range(2):
            x, y = rnd.randrange(8, 56), rnd.randrange(8, 56)
            for _step in range(8):
                nx = max(2, min(61, x + rnd.randint(-5, 5)))
                ny = max(2, min(61, y + rnd.randint(-5, 5)))
                d.line([x, y, nx, ny], fill=shade(base + (255,), 0.70), width=2)
                x, y = nx, ny
    elif kind == "ripples":
        for row in range(10, 58, 14):
            off = rnd.randint(0, 6)
            for x in range(4, 60, 3):
                yy = row + int(2 * ((x + off) % 18 > 9))
                d.rectangle([x, yy % 64, x + 1, (yy % 64) + 1], fill=shade(base + (255,), 1.08))
    elif kind == "vial_glint":
        # rare larger glint (not sparkle noise)
        for _ in range(2):
            x, y = rnd.randrange(8, 52), rnd.randrange(8, 52)
            d.rectangle([x, y, x + 2, y + 1], fill=VIAL[:3] + (160,))
            d.point((x, y), fill=VIAL_LT[:3] + (200,))
    # plain / default: already has soft patches

    return img


def dust_tile(seed: int) -> Image.Image:
    return ground_tile(seed + 100, "plain" if seed % 2 == 0 else "pebbles")


# ---------------------------------------------------------------------------
# Pickups — chunky vials that pop on dust
# ---------------------------------------------------------------------------

def pickup_base(accent, symbol_fn) -> Image.Image:
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 10, 3, 70)
    # bottle body (taller / brighter for FOV)
    fill_rect(p, 14, 12, 33, 40, shade(accent, 0.65), w, h)
    fill_rect(p, 15, 13, 32, 32, accent, w, h)
    fill_rect(p, 15, 13, 32, 18, shade(accent, 1.28), w, h)
    fill_rect(p, 15, 34, 32, 39, shade(accent, 0.52), w, h)
    # neck + cork
    fill_rect(p, 19, 5, 28, 13, SCRAP, w, h)
    fill_rect(p, 19, 5, 28, 8, SCRAP_LT, w, h)
    fill_rect(p, 20, 2, 27, 5, (90, 60, 40, 255), w, h)
    # glint
    fill_rect(p, 16, 15, 19, 26, (255, 255, 255, 100), w, h)
    symbol_fn(p, w, h)
    return add_outline(img, thickness=2)


def make_pickups() -> None:
    def cross(p, w, h):
        fill_rect(p, 21, 18, 26, 32, WHITE, w, h)
        fill_rect(p, 17, 22, 30, 27, WHITE, w, h)

    def bolt(p, w, h):
        fill_rect(p, 20, 16, 27, 21, AMBER_LT, w, h)
        fill_rect(p, 22, 21, 29, 26, AMBER_LT, w, h)
        fill_rect(p, 18, 26, 25, 34, AMBER_LT, w, h)

    def shield(p, w, h):
        fill_ellipse(p, 17, 17, 30, 34, (220, 230, 255, 255), w, h)
        fill_ellipse(p, 19, 19, 28, 31, (100, 140, 220, 255), w, h)

    def wing(p, w, h):
        fill_rect(p, 16, 22, 31, 26, WHITE, w, h)
        fill_rect(p, 14, 18, 18, 30, WHITE, w, h)
        fill_rect(p, 29, 18, 33, 30, WHITE, w, h)

    def magnet(p, w, h):
        fill_rect(p, 16, 16, 21, 34, (220, 70, 60, 255), w, h)
        fill_rect(p, 26, 16, 31, 34, (80, 120, 220, 255), w, h)
        fill_rect(p, 16, 16, 31, 21, SCRAP_LT, w, h)

    def quiet(p, w, h):
        fill_ellipse(p, 17, 18, 30, 32, (200, 200, 210, 255), w, h)
        fill_rect(p, 21, 23, 26, 26, SCRAP_DK, w, h)

    def rapid(p, w, h):
        fill_rect(p, 17, 18, 21, 34, AMBER, w, h)
        fill_rect(p, 23, 16, 27, 34, AMBER_LT, w, h)
        fill_rect(p, 29, 19, 32, 34, AMBER, w, h)

    save(pickup_base(VIAL, cross), "pickups/heal.png")
    save(pickup_base(RUST, bolt), "pickups/damage.png")
    save(pickup_base((70, 110, 190, 255), shield), "pickups/shield.png")
    save(pickup_base((70, 170, 90, 255), wing), "pickups/speed.png")
    save(pickup_base((180, 80, 140, 255), magnet), "pickups/magnet.png")
    save(pickup_base((100, 110, 130, 255), quiet), "pickups/quiet.png")
    save(pickup_base(AMBER, rapid), "pickups/rapid.png")


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

def make_ui() -> None:
    def icon(color, size=8):
        img = new(size, size)
        p = img.load()
        fill_ellipse(p, 0, 0, size - 1, size - 1, color, size, size)
        return add_outline(img, thickness=1)

    save(icon((100, 220, 120, 255)), "ui/mm_player.png")
    save(icon((240, 190, 60, 255)), "ui/mm_extract_open.png")
    save(icon((120, 110, 100, 255)), "ui/mm_extract_sealed.png")
    save(icon((180, 90, 60, 255)), "ui/mm_landmark.png")

    img = new(32, 32)
    p = img.load()
    for y in range(2, 28):
        width = max(2, 14 - abs(y - 8) // 2) if y < 18 else max(2, 6)
        x0 = 16 - width
        x1 = 16 + width
        if y >= 18:
            x0, x1 = 12, 20
        fill_rect(p, x0, y, x1, y, AMBER, 32, 32)
        if y < 10:
            fill_rect(p, x0, y, x1, y, AMBER_LT, 32, 32)
    save(add_outline(img, thickness=2), "ui/extract_arrow.png")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def write_noel_previews(preview_dir: Path) -> None:
    """Export magnified previews for store media/noel-pet/ comparison."""
    preview_dir.mkdir(parents=True, exist_ok=True)

    def magnify(img: Image.Image, scale: int = 8) -> Image.Image:
        return img.resize((img.width * scale, img.height * scale), Image.NEAREST)

    noel = make_noel(False)
    noel_r = make_noel(True)
    rook = make_rook()
    cinder = make_cinder()
    hound = make_dust_hound()

    noel.save(preview_dir / "noel.png")
    noel_r.save(preview_dir / "noel_rampage.png")
    magnify(noel, 8).save(preview_dir / "noel_8x.png")
    magnify(noel_r, 8).save(preview_dir / "noel_rampage_8x.png")
    magnify(hound, 8).save(preview_dir / "dust_hound_8x.png")
    magnify(rook, 6).save(preview_dir / "rook_vex_6x.png")
    magnify(cinder, 6).save(preview_dir / "sister_cinder_6x.png")

    ## Sheet: Noel idle | rampage | face ref strip | heroes
    sheet = Image.new("RGBA", (640, 320), (48, 36, 28, 255))
    sheet.paste(magnify(noel, 4), (16, 40))
    sheet.paste(magnify(noel_r, 4), (290, 40))
    sheet.paste(magnify(rook, 2), (16, 200))
    sheet.paste(magnify(cinder, 2), (220, 200))
    sheet.paste(magnify(hound, 2), (424, 200))
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), "Noel idle 64px", fill=(240, 220, 180, 255))
    d.text((290, 12), "Noel RAMPAGE", fill=(240, 120, 80, 255))
    d.text((16, 176), "Rook / Cinder / Dust Hound (heroes 96 · pets 64)", fill=(200, 180, 140, 255))
    sheet.save(preview_dir / "noel_sheet.png")

    ## Side-by-side vs approved face pixelation if present
    face_ref = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/pixelate/face_pixel_64.png")
    if face_ref.exists():
        face = Image.open(face_ref).convert("RGBA")
        ## Display face as ~256 so both columns match
        face_s = face.resize((256, 256), Image.NEAREST)
        noel_face = magnify(noel.crop((12, 2, 52, 42)), 6)  # head crop ~40 → 240
        cmp = Image.new("RGBA", (560, 300), (40, 30, 24, 255))
        cmp.paste(face_s, (16, 28))
        cmp.paste(noel_face, (290, 28))
        dc = ImageDraw.Draw(cmp)
        dc.text((16, 8), "Approved face_pixel_64 (detail bar)", fill=(220, 200, 160, 255))
        dc.text((290, 8), "Noel sprite head (64 craft)", fill=(220, 200, 160, 255))
        cmp.save(preview_dir / "noel_vs_face_ref.png")

    print("wrote previews →", preview_dir)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    save(make_rook(), "characters/rook_vex.png")
    save(make_cinder(), "characters/sister_cinder.png")

    save(make_noel(False), "pets/noel.png")
    save(make_noel(True), "pets/noel_rampage.png")
    save(make_dust_hound(), "pets/dust_hound.png")

    save(make_raider(), "enemies/raider.png")
    save(make_charger(), "enemies/charger.png")
    save(make_brute(), "enemies/brute.png")

    save(make_skate(), "mounts/skateboard.png")

    save(make_pad(False), "props/extract_sealed.png")
    save(make_pad(True), "props/extract_open.png")
    save(make_wreck(), "props/wreck.png")
    save(make_herb_crate(), "props/herb_crate.png")
    save(make_vial_crate(), "props/vial_crate.png")
    save(make_apothecary_chest(), "props/apothecary_chest.png")
    save(make_scrap_drum(), "props/scrap_drum.png")
    save(make_scrap_pile(), "props/scrap_pile.png")
    save(make_tower(), "props/signal_tower.png")
    save(make_bullet(), "props/bullet.png")

    save(make_rock(1, 30), "props/rock_small.png")
    save(make_rock(7, 46), "props/rock_large.png")
    save(make_dead_bush(), "props/dead_bush.png")
    save(make_bones(), "props/bones.png")
    save(make_tire(), "props/tire.png")
    save(make_cactus(), "props/cactus.png")
    save(make_sign(), "props/sign_post.png")

    kinds = ["plain", "pebbles", "plain", "cracks", "ripples", "vial_glint"]
    for i, k in enumerate(kinds):
        save(ground_tile(i * 31 + 5, k), f"tiles/ground_{i}.png")
    for i in range(4):
        save(dust_tile(i), f"tiles/dust_{i}.png")

    make_pickups()
    make_ui()

    preview = Path("/cursor/stores/bc-01a1472d-6408-7edd-b9ed-fb76363c6b5e/media/noel-pet")
    write_noel_previews(preview)
    print("DONE — 64-detail Noel + anti-thumb heroes →", OUT)


if __name__ == "__main__":
    main()
