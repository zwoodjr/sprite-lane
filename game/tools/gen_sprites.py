#!/usr/bin/env python3
"""Generate Dust Apothecary chunky-pixel sprites for Wanderer MVP.

Style target (inspiration only — original art, not Crazy Gunner IP):
  thick dark outlines, expressive chibi proportions (big head, stubby body),
  2–3 tone cell shading, dust/scrap ochres + vial/apothecary accents.

Tuned for portrait survivor FOV (camera zoom ~1.12, player ~1/12–1/15
screen width): strong silhouettes, low-noise ground, high-contrast accents
that stay readable when small. Heroes are authored at 64×64 with human
faces/hair strands, then scaled in-game to a ~48px footprint.

Run from repo root or game/:
  python3 game/tools/gen_sprites.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"

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
SKIN = (196, 150, 112, 255)
SKIN_DK = (160, 118, 88, 255)
SKIN_LT = (220, 180, 140, 255)
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


def eyes_pair(p, lx, rx, y, w, h, pupil=(30, 22, 18, 255), glow=None, size: int = 4) -> None:
    """Readable chibi eyes: white sclera + dark pupil (+ optional corner glint)."""
    for x0 in (lx, rx):
        fill_rect(p, x0, y, x0 + size - 1, y + size - 1, WHITE, w, h)
        # pupil block (inset) — stays dark so face reads as human, not glowing blob
        px(p, x0 + 1, y + 1, pupil, w, h)
        px(p, x0 + 2, y + 1, pupil, w, h)
        if size >= 4:
            px(p, x0 + 1, y + 2, pupil, w, h)
            px(p, x0 + 2, y + 2, pupil, w, h)
        if glow:
            # tiny outer-corner glint only (not a colored iris)
            px(p, x0 + size - 1, y, glow, w, h)


def brows(p, lx, rx, y, w, h, color=INK, slant: str = "flat") -> None:
    """Eyebrows — personality lever (flat / grit / soft)."""
    for x0 in (lx, rx):
        if slant == "grit":
            # angled down toward center (determined scavenger)
            px(p, x0, y + 1, color, w, h)
            px(p, x0 + 1, y, color, w, h)
            px(p, x0 + 2, y, color, w, h)
            px(p, x0 + 3, y, color, w, h)
        elif slant == "soft":
            # gentle arch
            px(p, x0, y + 1, color, w, h)
            px(p, x0 + 1, y, color, w, h)
            px(p, x0 + 2, y, color, w, h)
            px(p, x0 + 3, y + 1, color, w, h)
        else:
            fill_rect(p, x0, y, x0 + 3, y, color, w, h)


def mouth_line(p, x0, x1, y, w, h, color=INK, style: str = "neutral") -> None:
    """Simple mouth — smirk / smile / grit / neutral."""
    if style == "smirk":
        fill_rect(p, x0, y, x1 - 1, y, color, w, h)
        px(p, x1, y - 1, color, w, h)
    elif style == "smile":
        fill_rect(p, x0 + 1, y, x1 - 1, y, color, w, h)
        px(p, x0, y - 1, color, w, h)
        px(p, x1, y - 1, color, w, h)
    elif style == "grit":
        fill_rect(p, x0, y, x1, y, color, w, h)
        px(p, x0 + 1, y + 1, SKIN_DK, w, h)
    else:
        fill_rect(p, x0, y, x1, y, color, w, h)


def nose_dot(p, x, y, w, h, color=SKIN_DK) -> None:
    """Small nose bridge — 2×2 so it survives FOV shrink."""
    fill_rect(p, x, y, x + 1, y + 1, color, w, h)


def hair_strand(p, pts, c, w, h) -> None:
    """Paint a short jagged strand (list of (x,y))."""
    for x, y in pts:
        px(p, x, y, c, w, h)


# ---------------------------------------------------------------------------
# Characters — humanized chibi (64×64): faces, hair strands, thick outlines
# Scaled in-game so on-screen footprint stays ~48px (~1/13 screen width).
# ---------------------------------------------------------------------------

def make_rook() -> Image.Image:
    """Rook Vex — grit scavenger: messy blonde strands, dust hood pushed back,
    rust scarf, scrap pouches, asymmetric SMG. Readable face (brows/eyes/mouth)."""
    img = new(64, 64)
    p = img.load()
    w, h = 64, 64
    drop_shadow(img, 32, 58, 16, 5, 100)

    olive = (86, 108, 68, 255)
    olive_lt = (118, 148, 92, 255)
    olive_dk = (58, 76, 44, 255)
    scarf = (210, 96, 48, 255)
    scarf_dk = (160, 64, 32, 255)
    hair = (212, 168, 72, 255)
    hair_lt = (236, 200, 110, 255)
    hair_dk = (160, 118, 48, 255)

    # boots
    fill_rect(p, 20, 50, 28, 56, SCRAP_DK, w, h)
    fill_rect(p, 35, 50, 43, 56, SCRAP_DK, w, h)
    fill_rect(p, 20, 50, 28, 52, SCRAP, w, h)
    fill_rect(p, 35, 50, 43, 52, SCRAP, w, h)
    fill_rect(p, 25, 53, 28, 56, SCRAP_LT, w, h)
    fill_rect(p, 40, 53, 43, 56, SCRAP_LT, w, h)

    # legs
    fill_rect(p, 21, 42, 29, 51, DUST_DK, w, h)
    fill_rect(p, 34, 42, 42, 51, DUST_DK, w, h)
    fill_rect(p, 21, 42, 29, 44, DUST, w, h)
    fill_rect(p, 34, 42, 42, 44, DUST, w, h)

    # torso (olive scrap armor)
    fill_rect(p, 17, 26, 46, 44, olive, w, h)
    fill_rect(p, 17, 26, 46, 30, olive_lt, w, h)
    fill_rect(p, 17, 40, 46, 44, olive_dk, w, h)
    for x in (22, 30, 38):
        px(p, x, 33, SCRAP_DK, w, h)
    # left cloak flap
    fill_rect(p, 10, 24, 18, 42, olive_dk, w, h)
    fill_rect(p, 10, 24, 18, 28, olive, w, h)
    fill_rect(p, 10, 38, 14, 46, olive_dk, w, h)

    # hip pouches + belt vial
    fill_rect(p, 14, 36, 22, 44, DUST_DK, w, h)
    fill_rect(p, 14, 36, 22, 38, DUST, w, h)
    px(p, 18, 40, AMBER, w, h)
    fill_rect(p, 40, 37, 48, 45, SCRAP_DK, w, h)
    fill_rect(p, 40, 37, 48, 39, SCRAP, w, h)
    fill_rect(p, 42, 34, 46, 38, AMBER_DK, w, h)
    fill_rect(p, 42, 35, 46, 37, AMBER, w, h)

    # belt
    fill_rect(p, 17, 38, 46, 41, SCRAP_DK, w, h)
    fill_rect(p, 29, 38, 34, 41, GOLD, w, h)

    # scarf under chin (FOV accent)
    fill_rect(p, 18, 23, 45, 29, scarf, w, h)
    fill_rect(p, 18, 23, 45, 25, shade(scarf, 1.18), w, h)
    fill_rect(p, 43, 26, 50, 36, scarf_dk, w, h)
    fill_rect(p, 43, 26, 50, 29, scarf, w, h)
    px(p, 48, 34, scarf, w, h)

    # --- head / face (big chibi, clearly human) ---
    fill_rect(p, 18, 8, 45, 24, SKIN, w, h)
    fill_rect(p, 18, 20, 45, 24, SKIN_DK, w, h)
    fill_rect(p, 19, 9, 26, 15, SKIN_LT, w, h)  # cheek
    # jaw taper
    fill_rect(p, 20, 23, 43, 25, SKIN_DK, w, h)

    # messy blonde hair — spiky clumps / strands (CG-like silhouette, not bowl)
    fill_rect(p, 17, 4, 46, 12, hair, w, h)
    fill_rect(p, 18, 4, 44, 7, hair_lt, w, h)
    fill_rect(p, 17, 10, 46, 12, hair_dk, w, h)
    # tall spikes (individual strands)
    for pts, col in (
        ([(20, 2), (20, 1), (21, 0), (22, 1), (22, 2)], hair_lt),
        ([(24, 2), (25, 0), (26, 0), (27, 1), (26, 2)], hair),
        ([(29, 2), (30, 1), (31, 0), (32, 1), (31, 2)], hair_lt),
        ([(34, 2), (35, 0), (36, 0), (37, 1), (36, 2)], hair),
        ([(39, 2), (40, 1), (41, 0), (42, 1), (42, 2)], hair_lt),
        ([(43, 3), (44, 2), (45, 3)], hair),
    ):
        hair_strand(p, pts, col, w, h)
    # side locks with jagged tips
    fill_rect(p, 14, 5, 19, 18, hair, w, h)
    fill_rect(p, 14, 5, 17, 10, hair_lt, w, h)
    fill_rect(p, 44, 5, 49, 18, hair, w, h)
    fill_rect(p, 46, 5, 49, 10, hair_lt, w, h)
    hair_strand(p, [(14, 12), (13, 14), (14, 16), (15, 18), (15, 20), (16, 21)], hair_dk, w, h)
    hair_strand(p, [(49, 12), (50, 14), (49, 16), (48, 18), (48, 20), (47, 21)], hair_dk, w, h)
    # bang clumps — stop above brow line so expression stays visible
    fill_rect(p, 21, 9, 24, 12, hair, w, h)
    fill_rect(p, 26, 8, 30, 11, hair_lt, w, h)
    fill_rect(p, 32, 9, 35, 12, hair, w, h)
    fill_rect(p, 37, 8, 40, 11, hair_dk, w, h)
    # strand tips hanging between eyes (narrow, not a brow-covering curtain)
    px(p, 25, 12, hair_dk, w, h)
    px(p, 31, 11, hair, w, h)
    px(p, 36, 12, hair_dk, w, h)
    # internal strand separators
    for x in (23, 28, 33, 38, 43):
        px(p, x, 5, hair_dk, w, h)
        px(p, x, 6, hair_dk, w, h)
        px(p, x, 7, hair_dk, w, h)

    # dust hood / band pushed BACK — sits on crown spikes, hair spills everywhere
    fill_rect(p, 22, 1, 40, 5, olive_dk, w, h)
    fill_rect(p, 23, 1, 39, 3, olive, w, h)
    fill_rect(p, 26, 0, 36, 2, olive_lt, w, h)
    fill_rect(p, 28, 0, 34, 1, AMBER, w, h)
    # re-assert spikes poking through / past hood front
    for pts, col in (
        ([(24, 2), (25, 1), (26, 2)], hair_lt),
        ([(30, 1), (31, 0), (32, 1)], hair),
        ([(35, 1), (36, 0), (37, 1)], hair_lt),
    ):
        hair_strand(p, pts, col, w, h)

    # grit face (brows painted last so bangs never hide them)
    brows(p, 22, 36, 12, w, h, INK, slant="grit")
    eyes_pair(p, 22, 36, 14, w, h, pupil=(28, 20, 16, 255), glow=AMBER_LT, size=4)
    nose_dot(p, 31, 18, w, h)
    mouth_line(p, 27, 36, 21, w, h, style="smirk")
    px(p, 29, 19, SKIN_DK, w, h)
    px(p, 34, 19, SKIN_DK, w, h)

    # asymmetric scrap SMG
    fill_rect(p, 46, 28, 62, 36, SCRAP_DK, w, h)
    fill_rect(p, 46, 28, 62, 31, SCRAP, w, h)
    fill_rect(p, 48, 25, 55, 28, SCRAP_LT, w, h)
    fill_rect(p, 48, 35, 55, 44, SCRAP, w, h)
    fill_rect(p, 48, 35, 55, 38, DUST, w, h)
    fill_rect(p, 49, 39, 54, 43, SCRAP_DK, w, h)
    fill_rect(p, 59, 26, 62, 37, AMBER_DK, w, h)
    fill_rect(p, 59, 28, 61, 35, AMBER, w, h)
    px(p, 60, 29, AMBER_LT, w, h)
    # grip hand
    fill_rect(p, 44, 34, 48, 40, SKIN, w, h)
    fill_rect(p, 44, 37, 48, 40, SKIN_DK, w, h)

    return add_outline(img, thickness=2)


def make_cinder() -> Image.Image:
    """Sister Cinder — calm sawbones: ash-auburn strands under teal hood,
    medic-cross apron, satchel + dual vials, tonic blaster. Soft face."""
    img = new(64, 64)
    p = img.load()
    w, h = 64, 64
    drop_shadow(img, 32, 58, 16, 5, 100)

    cloak = (150, 62, 52, 255)
    cloak_lt = (186, 88, 74, 255)
    cloak_dk = (108, 40, 34, 255)
    apron = (220, 200, 170, 255)
    apron_lt = (240, 225, 200, 255)
    teal = VIAL
    teal_lt = VIAL_LT
    hood = (40, 148, 128, 255)
    hood_lt = (90, 200, 170, 255)
    hood_dk = (28, 100, 88, 255)
    # ash-auburn hair (distinct from Rook blonde + from hood teal)
    hair = (118, 72, 58, 255)
    hair_lt = (150, 98, 78, 255)
    hair_dk = (78, 44, 36, 255)

    # boots
    fill_rect(p, 20, 50, 28, 56, SCRAP_DK, w, h)
    fill_rect(p, 35, 50, 43, 56, SCRAP_DK, w, h)
    fill_rect(p, 20, 50, 28, 52, (120, 70, 60, 255), w, h)
    fill_rect(p, 35, 50, 43, 52, (120, 70, 60, 255), w, h)

    # legs
    fill_rect(p, 21, 42, 29, 51, (70, 48, 42, 255), w, h)
    fill_rect(p, 34, 42, 42, 51, (70, 48, 42, 255), w, h)

    # torso cloak
    fill_rect(p, 17, 25, 46, 44, cloak, w, h)
    fill_rect(p, 17, 25, 46, 29, cloak_lt, w, h)
    fill_rect(p, 17, 40, 46, 44, cloak_dk, w, h)
    # apron + medic cross (FOV accent)
    fill_rect(p, 22, 31, 41, 41, apron, w, h)
    fill_rect(p, 22, 31, 41, 34, apron_lt, w, h)
    fill_rect(p, 29, 33, 34, 40, (200, 60, 55, 255), w, h)
    fill_rect(p, 25, 36, 38, 39, (200, 60, 55, 255), w, h)

    # right cloak flap (asymmetric vs Rook left)
    fill_rect(p, 44, 22, 52, 46, cloak_dk, w, h)
    fill_rect(p, 44, 22, 52, 28, cloak, w, h)
    fill_rect(p, 48, 42, 54, 50, cloak_dk, w, h)

    # satchel left hip
    fill_rect(p, 10, 34, 20, 46, (96, 58, 40, 255), w, h)
    fill_rect(p, 10, 34, 20, 38, (130, 82, 56, 255), w, h)
    fill_rect(p, 13, 39, 17, 43, VIAL_DK, w, h)
    fill_rect(p, 14, 40, 16, 42, teal, w, h)
    fill_rect(p, 18, 25, 21, 35, (80, 50, 36, 255), w, h)

    # dual belt vials
    fill_rect(p, 23, 39, 28, 47, VIAL_DK, w, h)
    fill_rect(p, 24, 40, 27, 45, teal, w, h)
    px(p, 24, 41, teal_lt, w, h)
    fill_rect(p, 35, 39, 40, 47, AMBER_DK, w, h)
    fill_rect(p, 36, 40, 39, 45, AMBER, w, h)
    px(p, 36, 41, AMBER_LT, w, h)

    # --- head / face ---
    fill_rect(p, 18, 8, 45, 24, SKIN, w, h)
    fill_rect(p, 18, 20, 45, 24, SKIN_DK, w, h)
    fill_rect(p, 20, 9, 27, 15, SKIN_LT, w, h)
    fill_rect(p, 20, 23, 43, 25, SKIN_DK, w, h)

    # ash-auburn hair FIRST (dominant silhouette) — hood is a rim, not a helmet-blob
    fill_rect(p, 16, 2, 47, 13, hair, w, h)
    fill_rect(p, 17, 2, 45, 6, hair_lt, w, h)
    fill_rect(p, 16, 10, 47, 13, hair_dk, w, h)
    # soft crown waves / strand clusters
    for pts, col in (
        ([(20, 1), (21, 0), (22, 1), (23, 1)], hair_lt),
        ([(25, 1), (26, 0), (27, 0), (28, 1)], hair),
        ([(30, 1), (31, 0), (32, 0), (33, 1)], hair_lt),
        ([(35, 1), (36, 0), (37, 0), (38, 1)], hair),
        ([(40, 1), (41, 0), (42, 1), (43, 2)], hair_lt),
    ):
        hair_strand(p, pts, col, w, h)
    # long side locks (outside any hood)
    fill_rect(p, 13, 5, 18, 22, hair, w, h)
    fill_rect(p, 13, 5, 16, 11, hair_lt, w, h)
    fill_rect(p, 45, 5, 50, 22, hair, w, h)
    fill_rect(p, 47, 5, 50, 11, hair_lt, w, h)
    hair_strand(p, [(13, 14), (12, 16), (13, 18), (14, 20), (14, 22), (15, 23)], hair_dk, w, h)
    hair_strand(p, [(50, 14), (51, 16), (50, 18), (49, 20), (49, 22), (48, 23)], hair_dk, w, h)
    # bang clumps — stop above brow line
    fill_rect(p, 20, 9, 24, 12, hair, w, h)
    fill_rect(p, 26, 8, 31, 11, hair_lt, w, h)
    fill_rect(p, 33, 9, 37, 12, hair, w, h)
    fill_rect(p, 39, 8, 43, 11, hair_dk, w, h)
    px(p, 25, 12, hair_dk, w, h)
    px(p, 32, 11, hair, w, h)
    px(p, 38, 12, hair_dk, w, h)
    for x in (22, 28, 34, 40):
        px(p, x, 4, hair_dk, w, h)
        px(p, x, 5, hair_dk, w, h)
        px(p, x, 6, hair_dk, w, h)

    # teal hood as OPEN COWL — rim on crown + side flaps behind hair locks
    fill_rect(p, 18, 1, 45, 5, hood, w, h)
    fill_rect(p, 19, 1, 44, 3, hood_lt, w, h)
    fill_rect(p, 18, 4, 45, 5, hood_dk, w, h)
    fill_rect(p, 12, 8, 16, 20, hood, w, h)
    fill_rect(p, 47, 8, 51, 20, hood, w, h)
    fill_rect(p, 12, 8, 16, 11, hood_lt, w, h)
    fill_rect(p, 47, 8, 51, 11, hood_lt, w, h)
    # hair peeks over hood rim + re-assert short bangs
    for pts, col in (
        ([(24, 2), (25, 1), (26, 2)], hair_lt),
        ([(30, 1), (31, 0), (32, 1)], hair),
        ([(36, 1), (37, 0), (38, 1)], hair_lt),
    ):
        hair_strand(p, pts, col, w, h)
    fill_rect(p, 20, 9, 24, 12, hair, w, h)
    fill_rect(p, 26, 8, 31, 11, hair_lt, w, h)
    fill_rect(p, 33, 9, 37, 12, hair, w, h)
    fill_rect(p, 39, 8, 43, 11, hair_dk, w, h)
    # side locks over flaps
    fill_rect(p, 14, 8, 18, 18, hair, w, h)
    fill_rect(p, 45, 8, 49, 18, hair, w, h)

    # calm medic face (brows last)
    brows(p, 22, 36, 12, w, h, INK, slant="soft")
    eyes_pair(p, 22, 36, 14, w, h, pupil=(36, 42, 52, 255), glow=VIAL_LT, size=4)
    nose_dot(p, 31, 18, w, h)
    mouth_line(p, 27, 36, 21, w, h, style="smile")

    # vial-blaster
    fill_rect(p, 46, 27, 62, 36, SCRAP_DK, w, h)
    fill_rect(p, 46, 27, 62, 30, SCRAP, w, h)
    fill_rect(p, 49, 18, 58, 28, VIAL_DK, w, h)
    fill_rect(p, 50, 19, 57, 25, teal, w, h)
    px(p, 51, 20, teal_lt, w, h)
    fill_rect(p, 52, 16, 56, 18, SCRAP_LT, w, h)
    fill_rect(p, 59, 28, 62, 36, teal, w, h)
    px(p, 60, 29, teal_lt, w, h)
    fill_rect(p, 44, 33, 48, 40, SKIN, w, h)
    fill_rect(p, 44, 36, 48, 40, SKIN_DK, w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Enemies — unique silhouettes at wide FOV
# ---------------------------------------------------------------------------

def make_raider() -> Image.Image:
    """Scrappy ranged scavenger — tattered rag hood, rust plates, pistol."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 12, 3, 95)

    # boots / legs
    fill_rect(p, 15, 34, 20, 40, SCRAP_DK, w, h)
    fill_rect(p, 27, 34, 32, 40, SCRAP_DK, w, h)
    fill_rect(p, 15, 34, 20, 35, SCRAP, w, h)
    fill_rect(p, 27, 34, 32, 35, SCRAP, w, h)
    # wrapped puttees
    fill_rect(p, 15, 36, 20, 37, DUST, w, h)
    fill_rect(p, 27, 36, 32, 37, DUST, w, h)

    # body rust scrap (asymmetric plate)
    fill_rect(p, 13, 16, 34, 35, RUST, w, h)
    fill_rect(p, 13, 16, 34, 20, shade(RUST, 1.18), w, h)
    fill_rect(p, 13, 30, 34, 35, RUST_DK, w, h)
    # torn rag flap on chest
    fill_rect(p, 16, 18, 24, 26, DUST_DK, w, h)
    fill_rect(p, 16, 18, 24, 20, DUST, w, h)
    px(p, 22, 25, DUST_DK, w, h)
    # oil stain
    fill_ellipse(p, 22, 24, 30, 32, (40, 28, 22, 200), w, h)
    # shoulder plate (left — scrappy silhouette bump)
    fill_rect(p, 8, 13, 15, 25, SCRAP, w, h)
    fill_rect(p, 8, 13, 15, 16, SCRAP_LT, w, h)
    fill_rect(p, 9, 17, 14, 20, RUST_DK, w, h)
    px(p, 10, 12, SCRAP_LT, w, h)  # spike scrap
    # ammo pouch + bone token
    fill_rect(p, 28, 27, 36, 35, DUST_DK, w, h)
    fill_rect(p, 28, 27, 36, 29, DUST, w, h)
    fill_rect(p, 30, 30, 34, 33, BONE, w, h)

    # head (human under rag)
    fill_rect(p, 15, 4, 32, 17, (168, 118, 90, 255), w, h)
    fill_rect(p, 15, 13, 32, 17, (140, 96, 72, 255), w, h)
    # dirty brown hair fringe peeking under rag
    hair_r = (72, 48, 32, 255)
    fill_rect(p, 16, 5, 20, 8, hair_r, w, h)
    fill_rect(p, 27, 5, 31, 8, hair_r, w, h)
    px(p, 18, 4, hair_r, w, h)
    px(p, 29, 4, hair_r, w, h)
    # tattered rag hood (scrappy silhouette — hair still peeks)
    fill_rect(p, 12, 1, 35, 7, DUST_DK, w, h)
    fill_rect(p, 12, 1, 35, 3, DUST, w, h)
    fill_rect(p, 12, 6, 16, 15, DUST_DK, w, h)  # cheek wrap
    fill_rect(p, 33, 5, 36, 12, DUST_DK, w, h)  # trailing rag
    px(p, 35, 11, DUST, w, h)
    px(p, 14, 0, DUST, w, h)  # fray
    px(p, 32, 0, DUST_DK, w, h)
    # re-assert fringe over rag edge
    fill_rect(p, 17, 6, 20, 8, hair_r, w, h)
    fill_rect(p, 28, 6, 31, 8, hair_r, w, h)
    # glare brows + hot coal eyes (FOV accent, still a person)
    brows(p, 18, 26, 8, w, h, INK, slant="grit")
    fill_rect(p, 18, 10, 22, 13, WHITE, w, h)
    fill_rect(p, 26, 10, 30, 13, WHITE, w, h)
    fill_rect(p, 19, 11, 21, 12, (255, 90, 45, 255), w, h)
    fill_rect(p, 27, 11, 29, 12, (255, 90, 45, 255), w, h)
    px(p, 20, 11, AMBER_LT, w, h)
    mouth_line(p, 21, 28, 15, w, h, style="grit")

    # rusty pistol with taped slide
    fill_rect(p, 33, 20, 46, 25, SCRAP_DK, w, h)
    fill_rect(p, 33, 20, 46, 22, SCRAP, w, h)
    fill_rect(p, 36, 21, 40, 23, DUST, w, h)  # tape
    fill_rect(p, 42, 18, 46, 26, RUST_DK, w, h)
    fill_rect(p, 34, 24, 38, 29, (70, 45, 34, 255), w, h)
    fill_rect(p, 33, 23, 36, 27, (150, 110, 85, 255), w, h)  # hand

    return add_outline(img, thickness=2)


def make_charger() -> Image.Image:
    """Lean aggressive rusher — forward lean, amber goggles, long scrap blade."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 11, 3, 95)

    # legs planted / staggered lean
    fill_rect(p, 12, 34, 18, 41, (48, 32, 22, 255), w, h)
    fill_rect(p, 25, 32, 31, 41, (48, 32, 22, 255), w, h)
    fill_rect(p, 12, 34, 18, 35, (70, 48, 32, 255), w, h)
    fill_rect(p, 25, 32, 31, 33, (70, 48, 32, 255), w, h)

    # lean torso (narrower — distinct from raider box)
    fill_rect(p, 14, 15, 30, 34, (196, 112, 52, 255), w, h)
    fill_rect(p, 14, 15, 30, 19, (230, 145, 70, 255), w, h)
    fill_rect(p, 14, 28, 30, 34, (150, 80, 40, 255), w, h)
    # muscle / strap lines
    fill_rect(p, 15, 22, 29, 23, (150, 80, 40, 255), w, h)
    fill_rect(p, 19, 17, 24, 31, (170, 95, 45, 255), w, h)
    # dual shoulder spikes (aggressive silhouette)
    fill_rect(p, 10, 13, 15, 21, SCRAP_LT, w, h)
    px(p, 11, 11, SCRAP_LT, w, h)
    px(p, 12, 10, SCRAP, w, h)
    px(p, 13, 9, SCRAP_LT, w, h)
    fill_rect(p, 28, 14, 32, 20, SCRAP, w, h)
    px(p, 30, 12, SCRAP_LT, w, h)

    # head + big amber goggles (FOV identity)
    fill_rect(p, 15, 3, 32, 16, (170, 128, 100, 255), w, h)
    fill_rect(p, 15, 12, 32, 16, (140, 100, 78, 255), w, h)
    # wild spiked hair strands (person, not helmet-blob)
    hair_c = (90, 50, 30, 255)
    hair_cl = (110, 60, 35, 255)
    fill_rect(p, 14, 1, 33, 6, hair_c, w, h)
    for sx, sy in (
        (16, 0), (17, 0), (19, 0), (20, 1),
        (23, 0), (24, 0), (26, 1),
        (28, 0), (29, 0), (31, 1),
    ):
        px(p, sx, sy, hair_cl, w, h)
    # side spikes
    px(p, 13, 3, hair_c, w, h)
    px(p, 12, 4, hair_c, w, h)
    px(p, 33, 3, hair_c, w, h)
    px(p, 34, 4, hair_c, w, h)
    # goggle band — oversized lenses (over hair, strands still above)
    fill_rect(p, 13, 6, 34, 13, SCRAP_DK, w, h)
    fill_rect(p, 15, 6, 22, 13, AMBER, w, h)
    fill_rect(p, 25, 6, 32, 13, AMBER, w, h)
    fill_rect(p, 16, 7, 21, 11, AMBER_LT, w, h)
    fill_rect(p, 26, 7, 31, 11, AMBER_LT, w, h)
    px(p, 17, 8, WHITE, w, h)
    px(p, 27, 8, WHITE, w, h)
    # grit brows peeking above goggle band
    px(p, 17, 5, INK, w, h)
    px(p, 18, 5, INK, w, h)
    px(p, 28, 5, INK, w, h)
    px(p, 29, 5, INK, w, h)
    # snarl mouth
    mouth_line(p, 20, 27, 14, w, h, style="grit")

    # long scrap blade (horizontal reach = charger read)
    fill_rect(p, 29, 17, 47, 22, SCRAP_LT, w, h)
    fill_rect(p, 29, 17, 47, 18, (245, 245, 250, 255), w, h)
    fill_rect(p, 43, 15, 47, 24, SCRAP, w, h)
    px(p, 46, 16, WHITE, w, h)  # tip glint
    # vial wrap on hilt
    fill_rect(p, 30, 20, 35, 26, VIAL_DK, w, h)
    fill_rect(p, 31, 21, 34, 24, VIAL, w, h)
    fill_rect(p, 28, 20, 32, 26, (150, 110, 85, 255), w, h)  # hand

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

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    save(make_rook(), "characters/rook_vex.png")
    save(make_cinder(), "characters/sister_cinder.png")

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
    print("DONE — FOV + personality Dust Apothecary set →", OUT)


if __name__ == "__main__":
    main()
