#!/usr/bin/env python3
"""Generate Dust Apothecary chunky-pixel sprites for Wanderer MVP.

Style target (inspiration only — original art, not Crazy Gunner IP):
  thick dark outlines, chibi proportions, 2–3 tone cell shading,
  dust/scrap ochres + vial/apothecary accents.

Run from repo root or game/:
  python3 game/tools/gen_sprites.py
"""
from __future__ import annotations

import math
import os
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
VIAL = (64, 176, 128, 255)
VIAL_LT = (140, 230, 180, 255)
VIAL_DK = (36, 110, 80, 255)
AMBER = (232, 176, 64, 255)
AMBER_LT = (255, 220, 120, 255)
AMBER_DK = (180, 120, 36, 255)
GOLD = (220, 180, 70, 255)
BONE = (228, 214, 186, 255)
SHADOW = (30, 20, 12, 90)


def save(img: Image.Image, rel: str) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")
    print("wrote", rel)


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
    for t in range(thickness):
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


# ---------------------------------------------------------------------------
# Characters — chibi, big head, stubby body, side gun
# ---------------------------------------------------------------------------

def make_rook() -> Image.Image:
    """Rook Vex — scrap scavenger, olive armor, amber vial strap, scrap SMG."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 12, 4, 95)

    # boots
    fill_rect(p, 16, 36, 21, 40, SCRAP_DK, w, h)
    fill_rect(p, 26, 36, 31, 40, SCRAP_DK, w, h)
    fill_rect(p, 16, 36, 21, 37, SCRAP, w, h)
    fill_rect(p, 26, 36, 31, 37, SCRAP, w, h)

    # legs
    fill_rect(p, 17, 30, 22, 36, DUST_DK, w, h)
    fill_rect(p, 25, 30, 30, 36, DUST_DK, w, h)

    # torso (olive scrap)
    body = (86, 108, 68, 255)
    body_lt = (112, 138, 88, 255)
    body_dk = (62, 80, 48, 255)
    fill_rect(p, 14, 18, 33, 31, body, w, h)
    fill_rect(p, 14, 18, 33, 21, body_lt, w, h)
    fill_rect(p, 14, 28, 33, 31, body_dk, w, h)
    # cloak flap left
    fill_rect(p, 10, 18, 15, 30, (58, 74, 42, 255), w, h)
    fill_rect(p, 10, 18, 15, 20, (78, 98, 56, 255), w, h)

    # amber vial on belt (readable scrap-apothecary accent)
    fill_rect(p, 29, 22, 36, 31, AMBER_DK, w, h)
    fill_rect(p, 30, 23, 35, 29, AMBER, w, h)
    fill_rect(p, 30, 23, 35, 25, AMBER_LT, w, h)
    fill_rect(p, 31, 21, 34, 22, SCRAP_LT, w, h)

    # head (big)
    fill_rect(p, 15, 4, 32, 18, SKIN, w, h)
    fill_rect(p, 15, 15, 32, 18, SKIN_DK, w, h)
    # blonde messy hair / scrap helm band
    fill_rect(p, 14, 2, 33, 8, GOLD, w, h)
    fill_rect(p, 14, 2, 33, 4, AMBER_LT, w, h)
    fill_rect(p, 14, 7, 33, 8, AMBER_DK, w, h)
    # goggle strip
    fill_rect(p, 17, 9, 30, 12, SCRAP_DK, w, h)
    fill_rect(p, 18, 9, 22, 12, AMBER, w, h)
    fill_rect(p, 25, 9, 29, 12, AMBER, w, h)
    px(p, 19, 10, AMBER_LT, w, h)
    px(p, 26, 10, AMBER_LT, w, h)

    # scrap SMG (side profile, chunky)
    fill_rect(p, 33, 20, 46, 25, SCRAP_DK, w, h)
    fill_rect(p, 33, 20, 46, 22, SCRAP, w, h)
    fill_rect(p, 36, 18, 40, 20, SCRAP_LT, w, h)  # mag
    fill_rect(p, 44, 19, 47, 26, AMBER_DK, w, h)  # muzzle vial tip
    fill_rect(p, 45, 20, 46, 24, AMBER, w, h)
    fill_rect(p, 34, 25, 37, 28, (70, 50, 36, 255), w, h)  # grip

    return add_outline(img, thickness=2)


def make_cinder() -> Image.Image:
    """Sister Cinder — sawbones apothecary, terracotta cloak, teal vials."""
    img = new(48, 48)
    p = img.load()
    w, h = 48, 48
    drop_shadow(img, 24, 42, 12, 4, 95)

    cloak = (150, 62, 52, 255)
    cloak_lt = (178, 84, 70, 255)
    cloak_dk = (110, 42, 36, 255)
    teal = VIAL
    teal_lt = VIAL_LT

    # boots
    fill_rect(p, 16, 36, 21, 40, SCRAP_DK, w, h)
    fill_rect(p, 26, 36, 31, 40, SCRAP_DK, w, h)

    # legs
    fill_rect(p, 17, 30, 22, 36, (70, 48, 42, 255), w, h)
    fill_rect(p, 25, 30, 30, 36, (70, 48, 42, 255), w, h)

    # torso
    fill_rect(p, 14, 18, 33, 31, cloak, w, h)
    fill_rect(p, 14, 18, 33, 21, cloak_lt, w, h)
    fill_rect(p, 14, 28, 33, 31, cloak_dk, w, h)
    # apron / sash
    fill_rect(p, 18, 24, 29, 28, (210, 190, 160, 255), w, h)
    fill_rect(p, 18, 24, 29, 25, (235, 220, 195, 255), w, h)

    # cloak flap right
    fill_rect(p, 32, 17, 37, 32, cloak_dk, w, h)
    fill_rect(p, 32, 17, 37, 20, cloak, w, h)

    # dual vials on belt
    fill_rect(p, 15, 25, 19, 31, VIAL_DK, w, h)
    fill_rect(p, 16, 26, 18, 29, teal, w, h)
    px(p, 16, 27, teal_lt, w, h)
    fill_rect(p, 28, 25, 32, 31, AMBER_DK, w, h)
    fill_rect(p, 29, 26, 31, 29, AMBER, w, h)

    # head
    fill_rect(p, 15, 4, 32, 18, SKIN, w, h)
    fill_rect(p, 15, 15, 32, 18, SKIN_DK, w, h)
    # teal hood / hair
    fill_rect(p, 13, 2, 34, 9, (48, 150, 130, 255), w, h)
    fill_rect(p, 13, 2, 34, 4, (90, 200, 170, 255), w, h)
    fill_rect(p, 13, 8, 34, 10, (32, 110, 96, 255), w, h)
    # hood sides
    fill_rect(p, 12, 8, 15, 16, (40, 130, 112, 255), w, h)
    fill_rect(p, 32, 8, 35, 16, (40, 130, 112, 255), w, h)
    # eyes
    fill_rect(p, 18, 10, 21, 12, SCRAP_DK, w, h)
    fill_rect(p, 26, 10, 29, 12, SCRAP_DK, w, h)
    px(p, 19, 10, (240, 240, 230, 255), w, h)
    px(p, 27, 10, (240, 240, 230, 255), w, h)

    # vial-blaster (apothecary gun)
    fill_rect(p, 33, 19, 46, 25, SCRAP_DK, w, h)
    fill_rect(p, 33, 19, 46, 21, SCRAP, w, h)
    fill_rect(p, 38, 16, 44, 19, VIAL_DK, w, h)  # tank
    fill_rect(p, 39, 17, 43, 18, teal, w, h)
    px(p, 40, 17, teal_lt, w, h)
    fill_rect(p, 44, 20, 47, 24, teal, w, h)  # muzzle drip
    fill_rect(p, 34, 25, 37, 28, (90, 50, 44, 255), w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------

def make_raider() -> Image.Image:
    img = new(40, 40)
    p = img.load()
    w, h = 40, 40
    drop_shadow(img, 20, 35, 11, 3, 90)

    # boots / legs
    fill_rect(p, 13, 28, 17, 33, SCRAP_DK, w, h)
    fill_rect(p, 22, 28, 26, 33, SCRAP_DK, w, h)

    # body rust scrap
    fill_rect(p, 11, 14, 28, 29, RUST, w, h)
    fill_rect(p, 11, 14, 28, 17, shade(RUST, 1.15), w, h)
    fill_rect(p, 11, 25, 28, 29, RUST_DK, w, h)
    # oil stain
    fill_ellipse(p, 15, 19, 22, 25, (40, 30, 24, 220), w, h)
    # shoulder plate
    fill_rect(p, 9, 13, 14, 20, SCRAP, w, h)
    fill_rect(p, 9, 13, 14, 15, SCRAP_LT, w, h)

    # head
    fill_rect(p, 13, 4, 26, 15, (168, 118, 90, 255), w, h)
    fill_rect(p, 13, 12, 26, 15, (140, 96, 72, 255), w, h)
    # rag wrap
    fill_rect(p, 12, 3, 27, 7, DUST_DK, w, h)
    fill_rect(p, 12, 3, 27, 4, DUST, w, h)
    # eye slit
    fill_rect(p, 16, 8, 23, 10, (40, 20, 16, 255), w, h)
    px(p, 18, 8, (255, 90, 50, 255), w, h)

    # rusty pistol
    fill_rect(p, 27, 17, 38, 21, SCRAP_DK, w, h)
    fill_rect(p, 27, 17, 38, 18, SCRAP, w, h)
    fill_rect(p, 36, 16, 38, 22, RUST_DK, w, h)

    return add_outline(img, thickness=2)


def make_charger() -> Image.Image:
    img = new(40, 40)
    p = img.load()
    w, h = 40, 40
    drop_shadow(img, 20, 35, 11, 3, 90)

    fill_rect(p, 14, 28, 18, 34, (50, 34, 24, 255), w, h)
    fill_rect(p, 21, 28, 25, 34, (50, 34, 24, 255), w, h)

    # lean body
    fill_rect(p, 12, 15, 27, 29, (196, 112, 52, 255), w, h)
    fill_rect(p, 12, 15, 27, 18, (220, 140, 70, 255), w, h)
    fill_rect(p, 12, 25, 27, 29, (150, 80, 40, 255), w, h)
    fill_rect(p, 13, 21, 26, 22, (150, 80, 40, 255), w, h)

    # head + goggles
    fill_rect(p, 13, 4, 26, 16, (170, 128, 100, 255), w, h)
    fill_rect(p, 13, 13, 26, 16, (140, 100, 78, 255), w, h)
    fill_rect(p, 13, 8, 26, 12, SCRAP_DK, w, h)
    fill_rect(p, 15, 8, 18, 12, AMBER, w, h)
    fill_rect(p, 21, 8, 24, 12, AMBER, w, h)
    px(p, 16, 9, AMBER_LT, w, h)
    px(p, 22, 9, AMBER_LT, w, h)

    # scrap blade
    fill_rect(p, 26, 17, 38, 20, SCRAP_LT, w, h)
    fill_rect(p, 26, 17, 38, 18, (240, 240, 245, 255), w, h)
    fill_rect(p, 36, 16, 38, 21, SCRAP, w, h)
    # vial wrap on hilt
    fill_rect(p, 27, 19, 30, 22, VIAL_DK, w, h)
    px(p, 28, 20, VIAL, w, h)

    return add_outline(img, thickness=2)


def make_brute() -> Image.Image:
    img = new(56, 56)
    p = img.load()
    w, h = 56, 56
    drop_shadow(img, 28, 50, 16, 4, 100)

    # boots
    fill_rect(p, 16, 42, 24, 50, SCRAP_DK, w, h)
    fill_rect(p, 32, 42, 40, 50, SCRAP_DK, w, h)
    fill_rect(p, 16, 42, 24, 44, SCRAP, w, h)
    fill_rect(p, 32, 42, 40, 44, SCRAP, w, h)

    # heavy armor body
    armor = (88, 98, 120, 255)
    armor_lt = (118, 130, 156, 255)
    armor_dk = (60, 68, 88, 255)
    fill_rect(p, 12, 20, 43, 43, armor, w, h)
    fill_rect(p, 12, 20, 43, 26, armor_lt, w, h)
    fill_rect(p, 12, 38, 43, 43, armor_dk, w, h)
    # rivets
    for x in (18, 28, 38):
        px(p, x, 24, SCRAP_DK, w, h)
        px(p, x, 32, SCRAP_DK, w, h)
    # copper vial plate
    fill_rect(p, 24, 28, 31, 36, VIAL_DK, w, h)
    fill_rect(p, 25, 29, 30, 34, VIAL, w, h)
    px(p, 26, 30, VIAL_LT, w, h)

    # pauldrons
    fill_rect(p, 6, 18, 14, 30, armor_dk, w, h)
    fill_rect(p, 6, 18, 14, 21, armor, w, h)
    fill_rect(p, 41, 18, 49, 30, armor_dk, w, h)
    fill_rect(p, 41, 18, 49, 21, armor, w, h)

    # helm
    fill_rect(p, 18, 4, 37, 20, (70, 76, 92, 255), w, h)
    fill_rect(p, 18, 4, 37, 8, (100, 108, 128, 255), w, h)
    fill_rect(p, 20, 10, 35, 14, (230, 70, 50, 255), w, h)  # visor
    fill_rect(p, 20, 10, 35, 11, (255, 140, 90, 255), w, h)

    # scrap shotgun
    fill_rect(p, 42, 30, 54, 36, SCRAP_DK, w, h)
    fill_rect(p, 42, 30, 54, 32, SCRAP, w, h)
    fill_rect(p, 50, 28, 54, 38, SCRAP_LT, w, h)
    fill_rect(p, 44, 36, 48, 40, (60, 40, 32, 255), w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Mount
# ---------------------------------------------------------------------------

def make_skate() -> Image.Image:
    img = new(48, 24)
    p = img.load()
    w, h = 48, 24
    # deck
    fill_rect(p, 4, 8, 43, 15, (70, 50, 34, 255), w, h)
    fill_rect(p, 4, 8, 43, 10, (160, 100, 48, 255), w, h)
    fill_rect(p, 6, 6, 41, 9, (120, 78, 40, 255), w, h)
    # herb / vial strap
    fill_rect(p, 18, 4, 29, 8, VIAL_DK, w, h)
    fill_rect(p, 19, 5, 28, 7, VIAL, w, h)
    px(p, 20, 5, VIAL_LT, w, h)
    # trucks
    fill_rect(p, 10, 14, 16, 17, SCRAP, w, h)
    fill_rect(p, 31, 14, 37, 17, SCRAP, w, h)
    # wheels
    fill_ellipse(p, 8, 15, 16, 22, SCRAP_DK, w, h)
    fill_ellipse(p, 32, 15, 40, 22, SCRAP_DK, w, h)
    fill_ellipse(p, 10, 17, 14, 20, SCRAP, w, h)
    fill_ellipse(p, 34, 17, 38, 20, SCRAP, w, h)
    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Extract pads
# ---------------------------------------------------------------------------

def make_pad(open_state: bool) -> Image.Image:
    img = new(96, 96)
    p = img.load()
    w, h = 96, 96
    ring = AMBER if open_state else (90, 80, 70, 255)
    ring_lt = AMBER_LT if open_state else (120, 110, 100, 255)
    fill_c = (200, 140, 40, 100) if open_state else (50, 45, 40, 80)

    # outer disc
    fill_ellipse(p, 10, 10, 85, 85, fill_c, w, h)
    # ring pixels (chunky)
    for ang in range(0, 360, 3):
        rad = math.radians(ang)
        for r in (36, 37, 38):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            px(p, x, y, ring, w, h)
        for r in (34, 35):
            x = int(48 + math.cos(rad) * r)
            y = int(48 + math.sin(rad) * r)
            px(p, x, y, ring_lt if open_state else ring, w, h)
    # inner ring
    for ang in range(0, 360, 4):
        rad = math.radians(ang)
        x = int(48 + math.cos(rad) * 18)
        y = int(48 + math.sin(rad) * 18)
        px(p, x, y, ring, w, h)

    # beacon post
    fill_rect(p, 45, 14, 50, 48, SCRAP_DK, w, h)
    fill_rect(p, 45, 14, 50, 18, SCRAP, w, h)
    lamp = AMBER_LT if open_state else SCRAP
    fill_ellipse(p, 40, 6, 55, 18, lamp, w, h)
    if open_state:
        fill_ellipse(p, 43, 9, 52, 15, (255, 250, 200, 255), w, h)

    # vial markers
    fill_rect(p, 20, 50, 28, 62, VIAL_DK, w, h)
    fill_rect(p, 21, 51, 27, 59, VIAL if open_state else SCRAP, w, h)
    fill_rect(p, 68, 50, 76, 62, VIAL_DK, w, h)
    fill_rect(p, 69, 51, 75, 59, VIAL if open_state else SCRAP, w, h)
    fill_rect(p, 22, 48, 26, 50, SCRAP, w, h)
    fill_rect(p, 70, 48, 74, 50, SCRAP, w, h)

    return add_outline(img, thickness=2)


# ---------------------------------------------------------------------------
# Props / breakables
# ---------------------------------------------------------------------------

def make_wreck() -> Image.Image:
    img = new(64, 48)
    p = img.load()
    w, h = 64, 48
    drop_shadow(img, 32, 42, 22, 4, 80)
    # chassis
    pts_fill = [
        (6, 34), (18, 14), (50, 12), (58, 32), (46, 38), (12, 40),
    ]
    d = ImageDraw.Draw(img)
    d.polygon(pts_fill, fill=RUST_DK)
    fill_rect(p, 8, 28, 54, 38, RUST, w, h)
    fill_rect(p, 8, 28, 54, 30, shade(RUST, 1.2), w, h)
    # window
    fill_rect(p, 22, 16, 40, 26, (40, 50, 55, 255), w, h)
    fill_rect(p, 24, 17, 30, 22, (70, 90, 100, 200), w, h)
    # wheels
    fill_ellipse(p, 12, 30, 24, 42, SCRAP_DK, w, h)
    fill_ellipse(p, 44, 28, 56, 40, SCRAP_DK, w, h)
    fill_ellipse(p, 15, 33, 21, 39, SCRAP, w, h)
    fill_ellipse(p, 47, 31, 53, 37, SCRAP, w, h)
    # tonic strapped
    fill_rect(p, 30, 8, 36, 16, VIAL_DK, w, h)
    fill_rect(p, 31, 9, 35, 14, VIAL, w, h)
    px(p, 32, 10, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_herb_crate() -> Image.Image:
    img = new(32, 32)
    p = img.load()
    w, h = 32, 32
    drop_shadow(img, 16, 28, 10, 3, 70)
    fill_rect(p, 4, 10, 27, 27, (118, 78, 42, 255), w, h)
    fill_rect(p, 4, 10, 27, 13, (150, 105, 60, 255), w, h)
    fill_rect(p, 4, 24, 27, 27, (86, 56, 30, 255), w, h)
    # plank lines
    fill_rect(p, 4, 16, 27, 17, (70, 46, 24, 255), w, h)
    fill_rect(p, 4, 21, 27, 22, (70, 46, 24, 255), w, h)
    # sealed vial on top
    fill_rect(p, 12, 3, 19, 12, VIAL_DK, w, h)
    fill_rect(p, 13, 4, 18, 10, VIAL, w, h)
    px(p, 14, 5, VIAL_LT, w, h)
    fill_rect(p, 13, 2, 18, 3, SCRAP, w, h)
    fill_rect(p, 14, 1, 17, 2, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_vial_crate() -> Image.Image:
    img = new(36, 36)
    p = img.load()
    w, h = 36, 36
    drop_shadow(img, 18, 31, 12, 3, 70)
    fill_rect(p, 5, 14, 30, 30, SCRAP, w, h)
    fill_rect(p, 5, 14, 30, 17, SCRAP_LT, w, h)
    fill_rect(p, 5, 26, 30, 30, SCRAP_DK, w, h)
    # three vials
    for i, col in enumerate([VIAL, AMBER, (90, 140, 210, 255)]):
        x = 8 + i * 8
        fill_rect(p, x, 4, x + 5, 16, shade(col, 0.65), w, h)
        fill_rect(p, x + 1, 5, x + 4, 14, col, w, h)
        px(p, x + 1, 6, shade(col, 1.35), w, h)
        fill_rect(p, x + 1, 3, x + 4, 4, SCRAP_LT, w, h)
    return add_outline(img, thickness=2)


def make_apothecary_chest() -> Image.Image:
    img = new(40, 32)
    p = img.load()
    w, h = 40, 32
    drop_shadow(img, 20, 28, 14, 3, 70)
    fill_rect(p, 4, 10, 35, 27, (96, 58, 36, 255), w, h)
    fill_rect(p, 4, 10, 35, 14, (130, 82, 50, 255), w, h)
    fill_rect(p, 4, 22, 35, 27, (70, 42, 26, 255), w, h)
    # lid seam
    fill_rect(p, 4, 16, 35, 17, (50, 30, 18, 255), w, h)
    # brass lock + vial gem
    fill_rect(p, 17, 15, 22, 20, GOLD, w, h)
    fill_rect(p, 18, 16, 21, 19, AMBER, w, h)
    fill_rect(p, 28, 4, 34, 12, VIAL_DK, w, h)
    fill_rect(p, 29, 5, 33, 10, VIAL, w, h)
    px(p, 30, 6, VIAL_LT, w, h)
    return add_outline(img, thickness=2)


def make_scrap_drum() -> Image.Image:
    img = new(36, 44)
    p = img.load()
    w, h = 36, 44
    drop_shadow(img, 18, 40, 12, 3, 70)
    fill_rect(p, 8, 8, 27, 38, RUST, w, h)
    fill_rect(p, 8, 8, 27, 12, shade(RUST, 1.2), w, h)
    fill_rect(p, 8, 32, 27, 38, RUST_DK, w, h)
    # ridges
    for y in (16, 24):
        fill_rect(p, 8, y, 27, y + 1, RUST_DK, w, h)
    # toxic drip mark
    fill_rect(p, 14, 2, 21, 10, VIAL_DK, w, h)
    fill_rect(p, 15, 3, 20, 8, VIAL, w, h)
    px(p, 16, 12, VIAL, w, h)
    px(p, 16, 14, VIAL_DK, w, h)
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
    # lattice
    for y in range(30, 56, 6):
        fill_rect(p, 12, y, 27, y, SCRAP_DK, w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(8, 26), (20, 4), (32, 26)], fill=RUST)
    fill_rect(p, 16, 8, 24, 16, AMBER, w, h)
    fill_rect(p, 17, 9, 23, 14, AMBER_LT, w, h)
    # antenna vial tip
    fill_rect(p, 18, 1, 22, 6, VIAL, w, h)
    return add_outline(img, thickness=2)


def make_bullet() -> Image.Image:
    img = new(12, 6)
    p = img.load()
    w, h = 12, 6
    fill_rect(p, 1, 1, 8, 4, AMBER, w, h)
    fill_rect(p, 1, 1, 8, 2, AMBER_LT, w, h)
    fill_rect(p, 8, 1, 10, 4, VIAL, w, h)
    px(p, 10, 2, VIAL_LT, w, h)
    px(p, 10, 3, VIAL, w, h)
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
    # scrap X mark
    px(p, 10, 11, RUST, w, h)
    px(p, 14, 11, RUST, w, h)
    return add_outline(img, thickness=1)


# ---------------------------------------------------------------------------
# Ground tiles
# ---------------------------------------------------------------------------

def ground_tile(seed: int, kind: str = "plain") -> Image.Image:
    rnd = random.Random(seed)
    base = DUST[:3]
    img = Image.new("RGBA", (64, 64), base + (255,))
    d = ImageDraw.Draw(img)
    for _ in range(160):
        x, y = rnd.randrange(64), rnd.randrange(64)
        k = rnd.choice([0.90, 0.94, 0.97, 1.04, 1.08])
        d.point((x, y), fill=shade(base + (255,), k))
    # sparse scrap / grit chunks (pixel blocks)
    for _ in range(5):
        x, y = rnd.randrange(2, 60), rnd.randrange(2, 60)
        c = rnd.choice([DUST_DK, SCRAP_DK, RUST_DK, (140, 100, 60, 255)])
        d.rectangle([x, y, x + rnd.randint(1, 3), y + rnd.randint(0, 2)], fill=c)
    if kind == "pebbles":
        for _ in range(8):
            x, y = rnd.randrange(2, 60), rnd.randrange(2, 60)
            r = rnd.choice([1, 1, 2])
            d.ellipse([x, y, x + r * 2, y + r], fill=shade(base + (255,), 0.75))
    elif kind == "cracks":
        for _ in range(2):
            x, y = rnd.randrange(64), rnd.randrange(64)
            for _ in range(12):
                nx = max(0, min(63, x + rnd.randint(-4, 4)))
                ny = max(0, min(63, y + rnd.randint(-4, 4)))
                d.line([x, y, nx, ny], fill=shade(base + (255,), 0.72), width=1)
                x, y = nx, ny
    elif kind == "ripples":
        for row in range(6, 64, 11):
            off = rnd.randint(0, 8)
            for x in range(0, 64, 2):
                yy = row + int(2 * ((x + off) % 16 > 8))
                d.point((x, yy % 64), fill=shade(base + (255,), 1.1))
    elif kind == "vial_glint":
        for _ in range(3):
            x, y = rnd.randrange(4, 58), rnd.randrange(4, 58)
            d.point((x, y), fill=VIAL[:3] + (180,))
            d.point((x + 1, y), fill=VIAL_LT[:3] + (120,))
    return img


def dust_tile(seed: int) -> Image.Image:
    return ground_tile(seed + 100, "plain" if seed % 2 == 0 else "pebbles")


# ---------------------------------------------------------------------------
# Pickups — chunky vial / scrap icons
# ---------------------------------------------------------------------------

def pickup_base(accent, symbol_fn) -> Image.Image:
    img = new(40, 40)
    p = img.load()
    w, h = 40, 40
    # bottle body
    fill_rect(p, 12, 10, 27, 34, shade(accent, 0.7), w, h)
    fill_rect(p, 13, 11, 26, 28, accent, w, h)
    fill_rect(p, 13, 11, 26, 16, shade(accent, 1.25), w, h)
    fill_rect(p, 13, 28, 26, 33, shade(accent, 0.55), w, h)
    # neck + cork
    fill_rect(p, 16, 4, 23, 11, SCRAP, w, h)
    fill_rect(p, 16, 4, 23, 6, SCRAP_LT, w, h)
    fill_rect(p, 17, 2, 22, 4, (90, 60, 40, 255), w, h)
    # glint
    fill_rect(p, 14, 13, 16, 22, (255, 255, 255, 90), w, h)
    symbol_fn(p, w, h)
    return add_outline(img, thickness=2)


def make_pickups() -> None:
    def cross(p, w, h):
        fill_rect(p, 18, 16, 21, 26, (250, 250, 240, 255), w, h)
        fill_rect(p, 15, 19, 24, 22, (250, 250, 240, 255), w, h)

    def bolt(p, w, h):
        fill_rect(p, 17, 14, 22, 18, AMBER_LT, w, h)
        fill_rect(p, 19, 18, 24, 22, AMBER_LT, w, h)
        fill_rect(p, 16, 22, 21, 28, AMBER_LT, w, h)

    def shield(p, w, h):
        fill_ellipse(p, 15, 15, 24, 28, (220, 230, 255, 255), w, h)
        fill_ellipse(p, 17, 17, 22, 25, (100, 140, 220, 255), w, h)

    def wing(p, w, h):
        fill_rect(p, 14, 18, 25, 21, (250, 250, 240, 255), w, h)
        fill_rect(p, 12, 16, 15, 23, (250, 250, 240, 255), w, h)
        fill_rect(p, 24, 16, 27, 23, (250, 250, 240, 255), w, h)

    def magnet(p, w, h):
        fill_rect(p, 14, 14, 18, 28, (220, 70, 60, 255), w, h)
        fill_rect(p, 21, 14, 25, 28, (80, 120, 220, 255), w, h)
        fill_rect(p, 14, 14, 25, 18, SCRAP_LT, w, h)

    def quiet(p, w, h):
        fill_ellipse(p, 15, 16, 24, 26, (200, 200, 210, 255), w, h)
        fill_rect(p, 18, 20, 21, 22, SCRAP_DK, w, h)

    def rapid(p, w, h):
        fill_rect(p, 15, 16, 18, 28, AMBER, w, h)
        fill_rect(p, 20, 14, 23, 28, AMBER_LT, w, h)
        fill_rect(p, 25, 17, 27, 28, AMBER, w, h)

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
    # chunky arrow
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
    print("DONE — Dust Apothecary chunky pixel set written to", OUT)


if __name__ == "__main__":
    main()
