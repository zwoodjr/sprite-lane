"""Wanderer icon set (style bible §6.5): every gear slot, mod, weapon style,
ability (8 heroes x 2 versions), quirk, tonic, ingredient, run upgrade, recipe,
special ammo, material, currency, hangar camp upgrade, tab and setting.

Each icon is drawn once from primitives (tools/icon_kit.py) and rasterised
natively at 48 px and 24 px:
  assets/sprites/icons/set/48/<id>.png   cards, gear slots, ability buttons
  assets/sprites/icons/set/24/<id>.png   rows, chips, HUD
Plus rarity frames (assets/sprites/icons/set/frame_<rarity>.png, UI texel x2).

usage: python3 tools/gen_icons.py [sheet.png]     (from game/ or anywhere)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icon_kit import Icon, to_img, colours, PALETTE, INK, BONE, A, E, RU, BR, ST, CL, PL, FL, D, TE, SIG, BLOOD  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets/sprites/icons/set")

ICONS = {}


def icon(name):
    def deco(fn):
        ICONS[name] = fn
        return fn
    return deco


# =================================================================== motifs
def bullet(c, x, y, ang, L=20, w=8, case="brass", tip="steel"):
    """Cartridge pointing along ang (deg), base centre at (x,y)."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    cl = L * 0.6
    hw = w / 2
    p = lambda s, t: (x + ux * s + nx * t, y + uy * s + ny * t)  # noqa: E731
    c.poly([p(0, -hw), p(cl, -hw), p(cl, hw), p(0, hw)], case)
    c.poly([p(cl, -hw), p(cl + L * 0.18, -hw * 0.8), p(L, 0), p(cl + L * 0.18, hw * 0.8), p(cl, hw)], tip)


def blade(c, p0, p1, w=6, ramp="steel", hilt="leather", guard="brass", glen=0.3):
    """Straight blade from hilt end p0 to tip p1."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    g = L * glen
    gx, gy = x0 + ux * g, y0 + uy * g
    hw = w / 2
    c.poly([(gx + nx * hw, gy + ny * hw), (x1 - ux * w * 0.8 + nx * hw, y1 - uy * w * 0.8 + ny * hw), (x1, y1),
            (x1 - ux * w * 0.8 - nx * hw * 0.2, y1 - uy * w * 0.8 - ny * hw * 0.2), (gx - nx * hw * 0.2, gy - ny * hw * 0.2)], ramp)
    c.line((x0, y0), (gx, gy), max(3, w * 0.6), hilt)
    c.line((gx - nx * w * 0.9, gy - ny * w * 0.9), (gx + nx * w * 1.1, gy + ny * w * 1.1), 3.2, guard)


def flame(c, cx, cy, s=1.0, ramp="fire", inner=True):
    pts = [(0, 12), (-9, 4), (-8, -4), (-4, -1), (-5, -10), (0, -5), (3, -15), (6, -6), (9, -2), (8, 6)]
    c.poly([(cx + x * s, cy + y * s) for x, y in pts], "dust" if inner else ramp)
    if inner:
        pts2 = [(0, 11), (-5, 5), (-4, 0), (-1, 2), (1, -5), (4, 1), (5, 6)]
        c.poly([(cx + x * s, cy + y * s) for x, y in pts2], "fire", hl=False)


def bolt_glyph(c, cx, cy, s=1.0, ramp="teal"):
    pts = [(3, -16), (-9, 2), (-1, 2), (-5, 16), (9, -3), (1, -3), (6, -16)]
    c.poly([(cx + x * s, cy + y * s) for x, y in pts], ramp)


def drop(c, cx, cy, s=1.0, ramp="plague"):
    pts = [(0, -14)]
    for i in range(0, 181, 15):
        a = math.radians(i)
        pts.append((9 * math.cos(a), 4 + 9 * math.sin(a)))
    pts = [(0, -14), (6, -5)] + [(9 * math.cos(math.radians(a)), 4 + 9 * math.sin(math.radians(a))) for a in range(-10, 191, 20)] + [(-6, -5)]
    c.poly([(cx + x * s, cy + y * s) for x, y in pts], ramp)


def crystal(c, cx, cy, s=1.0, ramp="dust"):
    c.poly([(cx, cy - 16 * s), (cx + 8 * s, cy - 4 * s), (cx + 5 * s, cy + 14 * s), (cx - 5 * s, cy + 14 * s), (cx - 8 * s, cy - 4 * s)], ramp)
    c.poly([(cx, cy - 16 * s), (cx + 8 * s, cy - 4 * s), (cx + 5 * s, cy + 14 * s), (cx + 1 * s, cy + 14 * s), (cx + 1 * s, cy - 4 * s)], ramp, flat=0)


def snowflake(c, cx, cy, r=15, ramp="frost"):
    for k in range(3):
        a = math.radians(90 + k * 60)
        c.line((cx - math.cos(a) * r, cy - math.sin(a) * r), (cx + math.cos(a) * r, cy + math.sin(a) * r), 3.5, ramp, hl=False)
    for k in range(6):
        a = math.radians(90 + k * 60)
        bx, by = cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6
        for s in (-1, 1):
            b = a + s * math.radians(50)
            c.line((bx, by), (bx + math.cos(b) * r * 0.32, by + math.sin(b) * r * 0.32), 2.6, ramp, hl=False, cap=False)
    c.circle(cx, cy, 3.5, "teal")


def skull(c, cx, cy, s=1.0, ramp="bone", eyes="ink"):
    c.ellipse(cx, cy - 2 * s, 12 * s, 11 * s, ramp)
    c.rect(cx - 7 * s, cy + 4 * s, cx + 7 * s, cy + 12 * s, ramp)
    c.ellipse(cx - 5 * s, cy, 3.4 * s, 3.8 * s, eyes, flat=1)
    c.ellipse(cx + 5 * s, cy, 3.4 * s, 3.8 * s, eyes, flat=1)
    c.poly([(cx, cy + 4 * s), (cx - 2 * s, cy + 7 * s), (cx + 2 * s, cy + 7 * s)], "ink", flat=1)
    for i in (-3, 0, 3):
        c.rect(cx + i * s - 0.6, cy + 9 * s, cx + i * s + 0.6, cy + 12 * s, "ink", flat=1)


def cog(c, cx, cy, r=14, teeth=8, ramp="steel", hole=5):
    c.star(cx, cy, r, r * 0.78, teeth, ramp, rot=0)
    c.circle(cx, cy, r * 0.8, ramp)
    if hole:
        c.cut_circle(cx, cy, hole)


def shield(c, cx, cy, s=1.0, ramp="steel"):
    pts = [(-13, -14), (13, -14), (13, 0), (8, 9), (0, 15), (-8, 9), (-13, 0)]
    c.poly([(cx + x * s, cy + y * s) for x, y in pts], ramp)


def heart(c, cx, cy, s=1.0, ramp="blood"):
    c.circle(cx - 6 * s, cy - 4 * s, 7.5 * s, ramp)
    c.circle(cx + 6 * s, cy - 4 * s, 7.5 * s, ramp)
    c.poly([(cx - 13 * s, cy - 2 * s), (cx + 13 * s, cy - 2 * s), (cx, cy + 13 * s)], ramp)


def burst(c, cx, cy, ro=18, ri=9, n=8, ramp="fire", core="dust"):
    c.star(cx, cy, ro, ri, n, core, rot=-90 + 180 / n)
    c.star(cx, cy, ro * 0.62, ri * 0.6, n, ramp, rot=-90, hl=False)


def nut(c, cx, cy, r=12, ramp="brass", hole=4.5):
    pts = [(cx + r * math.cos(math.radians(30 + 60 * i)), cy + r * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
    c.poly(pts, ramp)
    c.cut_circle(cx, cy, hole)


def bottle(c, kind, liquid, cork="wood", glass="ash", mark=None):
    """Potion bottles with distinct silhouettes."""
    if kind == "round":
        c.rect(20, 7, 28, 13, cork)
        c.rect(19.5, 12, 28.5, 18, glass)
        c.circle(24, 31, 14, glass)
        c.ellipse(24, 34, 11.5, 10, liquid, band=0.2)
    elif kind == "square":
        c.rect(19, 5, 29, 10, cork)
        c.rect(18, 10, 30, 14, glass)
        c.rect(10, 14, 38, 44, glass)
        c.rect(12.5, 21, 35.5, 41.5, liquid)
    elif kind == "flask":
        c.rect(20, 4, 28, 9, cork)
        c.poly([(19.5, 9), (28.5, 9), (28.5, 19), (40, 42), (8, 42), (19.5, 19)], glass)
        c.poly([(15.5, 27), (32.5, 27), (37.5, 39.5), (10.5, 39.5)], liquid)
    elif kind == "tall":
        c.rect(19, 3, 29, 8, cork)
        c.rect(20.5, 8, 27.5, 15, glass)
        c.poly([(20.5, 15), (27.5, 15), (34, 21), (34, 45), (14, 45), (14, 21)], glass)
        c.rect(16.5, 24, 31.5, 42.5, liquid)
    elif kind == "hip":
        c.rect(30, 5, 37, 11, "steel")
        c.poly([(12, 13), (33, 10), (38, 14), (38, 40), (34, 44), (14, 44), (10, 40), (10, 16)], glass)
        c.poly([(13, 23), (35, 21), (35, 39), (32, 41.5), (16, 41.5), (13, 39)], liquid)
    elif kind == "ampoule":
        c.poly([(24, 3), (28, 9), (20, 9)], glass)
        c.rect(21.5, 9, 26.5, 14, glass)
        c.ellipse(24, 30, 10, 16, glass)
        c.ellipse(24, 33, 7.5, 12, liquid)
    elif kind == "ornate":
        c.rect(20, 3, 28, 7, cork)
        c.poly([(19, 7), (29, 7), (29, 13), (36, 18), (36, 36), (30, 44), (18, 44), (12, 36), (12, 18), (19, 13)], glass)
        c.poly([(15, 22), (33, 22), (33, 35), (28.5, 41), (19.5, 41), (15, 35)], liquid)
    if mark:
        mark(c)


def tag_mark(c, ramp, glyph):
    """Small glyph on a bottle front."""
    glyph(c)


def boot(c, x=0, y=0, s=1.0, ramp="leather", sole="dark"):
    P = lambda pts: [(x + px * s, y + py * s) for px, py in pts]  # noqa: E731
    c.poly(P([(12, 6), (27, 6), (27, 28), (40, 32), (43, 38), (43, 42), (10, 42), (10, 30)]), ramp)
    c.rect(x + 9 * s, y + 39 * s, x + 44 * s, y + 44 * s, sole)
    c.rect(x + 11 * s, y + 6 * s, x + 28 * s, y + 10 * s, ramp, flat=0)


def drone(c, cx, cy, s=1.0, body="steel", eye="dust"):
    c.rect(cx - 15 * s, cy - 7 * s, cx + 15 * s, cy - 4.5 * s, "gun", hl=False)
    for dx in (-13, 13):
        c.ellipse(cx + dx * s, cy - 9 * s, 7 * s, 2.2 * s, "ash", hl=False)
        c.rect(cx + dx * s - 1.2 * s, cy - 9 * s, cx + dx * s + 1.2 * s, cy - 4 * s, "gun", hl=False)
    c.ellipse(cx, cy, 9 * s, 7 * s, body)
    c.circle(cx + 2 * s, cy + 1 * s, 3 * s, eye, flat=2)
    c.line((cx - 4 * s, cy + 6 * s), (cx - 7 * s, cy + 11 * s), 2, "gun", hl=False)
    c.line((cx + 4 * s, cy + 6 * s), (cx + 7 * s, cy + 11 * s), 2, "gun", hl=False)


def rifle(c, x0=4, y0=30, ang=-25, L=42, stock="wood", body="gun", barrel="steel"):
    """Generic long gun along ang, butt at (x0,y0)."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    P = lambda s, t: (x0 + ux * s + nx * t, y0 + uy * s + ny * t)  # noqa: E731
    c.poly([P(0, -4), P(12, -4), P(12, 4), P(0, 9)], stock)
    c.poly([P(11, -5), P(27, -5), P(27, 3.5), P(11, 3.5)], body)
    c.poly([P(17, 3), P(22, 3), P(20, 12), P(15, 12)], body)
    c.poly([P(26, -3.4), P(L, -3.4), P(L, 1.2), P(26, 1.2)], barrel)
    return P


def pistol(c, x=6, y=14, s=1.0, body="gun", grip="wood", barrel_len=24, barrel_w=7):
    P = lambda pts: [(x + px * s, y + py * s) for px, py in pts]  # noqa: E731
    c.poly(P([(0, 0), (barrel_len + 8, 0), (barrel_len + 8, barrel_w), (0, barrel_w)]), body)
    c.poly(P([(2, barrel_w), (12, barrel_w), (14, barrel_w + 18), (4, barrel_w + 20), (0, barrel_w + 18)]), grip)
    c.ring(x + 15 * s, y + (barrel_w + 4) * s, 4.5 * s, 2.5 * s, body, hl=False)


def hammer(c, p0, p1, head_w=16, head_h=10, head="steel", haft="wood"):
    (x0, y0), (x1, y1) = p0, p1
    c.line(p0, p1, 4.5, haft)
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    hw, hh = head_w / 2, head_h / 2
    c.poly([(x1 + nx * hw - ux * hh, y1 + ny * hw - uy * hh), (x1 + nx * hw + ux * hh, y1 + ny * hw + uy * hh),
            (x1 - nx * hw + ux * hh, y1 - ny * hw + uy * hh), (x1 - nx * hw - ux * hh, y1 - ny * hw - uy * hh)], head)


def speed_lines(c, x0, y0, n=3, L=12, gap=6, ramp="ash", ang=0):
    a = math.radians(ang)
    for i in range(n):
        yy = y0 + i * gap
        ll = L - abs(i - (n - 1) / 2) * 4
        c.line((x0 - ll * math.cos(a), yy - ll * math.sin(a)), (x0, yy), 2.2, ramp, hl=False, cap=False)


def chevron_up(c, cx, cy, s=1.0, ramp="dust"):
    c.poly([(cx - 10 * s, cy + 6 * s), (cx, cy - 4 * s), (cx + 10 * s, cy + 6 * s), (cx + 10 * s, cy + 11 * s), (cx, cy + 1 * s), (cx - 10 * s, cy + 11 * s)], ramp)


def crosshair(c, cx, cy, r=14, ramp="signal"):
    c.ring(cx, cy, r, r - 3, ramp, hl=False)
    for (dx, dy) in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        c.line((cx + dx * (r - 6), cy + dy * (r - 6)), (cx + dx * (r + 3), cy + dy * (r + 3)), 3, ramp, cap=False, hl=False)


def cloud(c, cx, cy, s=1.0, ramp="ash"):
    c.circle(cx - 8 * s, cy + 2 * s, 7 * s, ramp)
    c.circle(cx + 1 * s, cy - 4 * s, 9 * s, ramp)
    c.circle(cx + 10 * s, cy + 2 * s, 7 * s, ramp)
    c.rect(cx - 8 * s, cy + 2 * s, cx + 10 * s, cy + 9 * s, ramp)


def paw(c, cx, cy, s=1.0, ramp="bone"):
    c.ellipse(cx, cy + 5 * s, 8 * s, 7 * s, ramp)
    for (dx, dy) in ((-9, -3), (-3.5, -9), (3.5, -9), (9, -3)):
        c.ellipse(cx + dx * s, cy + dy * s, 3.4 * s, 4.2 * s, ramp)


def bag(c, cx, cy, s=1.0, ramp="cloth"):
    """Field backpack: rounded pack, top flap, side pocket, strap loop."""
    c.ring(cx, cy - 12 * s, 6 * s, 3.5 * s, "leather", 180, 360, hl=False)
    c.poly([(cx - 13 * s, cy - 8 * s), (cx + 13 * s, cy - 8 * s), (cx + 15 * s, cy + 16 * s), (cx - 15 * s, cy + 16 * s)], ramp)
    c.poly([(cx - 13 * s, cy - 10 * s), (cx + 13 * s, cy - 10 * s), (cx + 14 * s, cy + 2 * s), (cx - 14 * s, cy + 2 * s)], ramp)
    c.rect(cx - 9 * s, cy + 5 * s, cx + 9 * s, cy + 14 * s, ramp, flat=0)
    c.rect(cx - 2 * s, cy - 2 * s, cx + 2 * s, cy + 5 * s, "leather", hl=False)


def crate(c, x0, y0, x1, y1, ramp="wood"):
    c.rect(x0, y0, x1, y1, ramp)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 2, ramp, flat=0)
    c.line((x0 + 3, y1 - 3), (x1 - 3, y0 + 3), 3, ramp, cap=False)
    c.rect(x0, y0, x1, y0 + 2.5, "steel", hl=False)


def gun_mag(c, x, y, w=8, h=20, curve=4, ramp="gun"):
    c.poly([(x, y), (x + w, y), (x + w + curve, y + h), (x + curve, y + h)], ramp)


def wing(c, cx, cy, s=1.0, ramp="bone", flip=False):
    f = -1 if flip else 1
    pts = [(0, 0), (16, -10), (20, -6), (16, -1), (19, 2), (14, 5), (16, 8), (8, 9), (2, 6)]
    c.poly([(cx + x * s * f, cy + y * s) for x, y in pts], ramp)


def scalpel(c, p0, p1, ramp="steel", handle="steel"):
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux
    m = 0.6
    mx, my = x0 + ux * L * m, y0 + uy * L * m
    c.line((x0, y0), (mx, my), 3.2, "gun")
    c.poly([(mx + nx * 2.4, my + ny * 2.4), (x1, y1), (mx - nx * 1.4, my - ny * 1.4)], ramp)


def tent(c):
    c.poly([(24, 6), (44, 40), (4, 40)], "cloth")
    c.poly([(24, 14), (30, 40), (18, 40)], "dark", flat=1)
    c.rect(3, 40, 45, 43, "leather", hl=False)


def book(c, x0=8, y0=6, x1=40, y1=42, cover="rust", pages="bone"):
    c.rect(x0 + 3, y0 + 3, x1 + 1, y1 + 1, pages, flat=0)
    c.rect(x0, y0, x1, y1, cover)
    c.rect(x0, y0, x0 + 4, y1, cover, flat=0)


def speaker(c, x=6, cy=24, ramp="steel"):
    c.rect(x, cy - 6, x + 8, cy + 6, ramp)
    c.poly([(x + 7, cy - 6), (x + 18, cy - 14), (x + 18, cy + 14), (x + 7, cy + 6)], ramp)


# ============================================================ gear slots (12)
@icon("slot_weapon")
def _(c):
    P = rifle(c, 3, 34, -28, 46)
    c.poly([P(28, 0.6), P(34, 0.6), P(34, 4), P(28, 4)], "gun", hl=False)


@icon("slot_mod1")
def _(c):  # optic
    c.rect(8, 16, 40, 26, "gun")
    c.rect(4, 13, 12, 29, "gun")
    c.rect(36, 14, 44, 28, "gun")
    c.ellipse(41, 21, 2.2, 5.5, "teal", flat=1)
    c.rect(16, 26, 20, 34, "steel")
    c.rect(28, 26, 32, 34, "steel")
    c.rect(12, 33, 36, 37, "steel")
    c.rect(22, 11, 26, 16, "brass")


@icon("slot_mod2")
def _(c):  # tuning: cog + wrench
    cog(c, 19, 27, 14, 8, "steel", 5)
    c.line((26, 22), (42, 6), 5, "rust")
    c.ring(41, 8, 6.5, 2.6, "rust", hl=False)
    c.cut_rect(40, 2, 47, 8)


@icon("slot_head")
def _(c):
    c.ellipse(24, 24, 18, 15, "cloth")
    c.rect(6, 24, 42, 32, "cloth")
    c.rect(4, 30, 44, 34, "leather", hl=False)
    c.rect(9, 18, 39, 23, "leather", hl=False)
    c.circle(17, 20, 6.5, "brass")
    c.circle(31, 20, 6.5, "brass")
    c.circle(17, 20, 3.8, "teal", flat=1)
    c.circle(31, 20, 3.8, "teal", flat=1)


@icon("slot_chest")
def _(c):
    c.poly([(12, 6), (19, 6), (24, 14), (29, 6), (36, 6), (42, 14), (40, 42), (8, 42), (6, 14)], "cloth")
    c.poly([(19, 6), (24, 14), (29, 6), (29, 9), (24, 17), (19, 9)], "dark", flat=1)
    c.rect(11, 20, 21, 30, "cloth", flat=0)
    c.rect(27, 20, 37, 30, "cloth", flat=0)
    c.rect(8, 33, 40, 37, "leather", hl=False)
    c.rect(22, 32, 26, 38, "brass", hl=False)


@icon("slot_shoulders")
def _(c):
    for cx in (12, 36):
        c.ellipse(cx, 22, 10, 12, "rust")
        c.rect(cx - 10, 22, cx + 10, 34, "rust")
        c.rect(cx - 10, 30, cx + 10, 34, "steel", hl=False)
    c.rect(20, 12, 28, 18, "leather", hl=False)
    for cx in (12, 36):
        c.px(cx - 3, 18, "brass", 3)
        c.px(cx + 3, 26, "brass", 3)


@icon("slot_legs")
def _(c):
    c.poly([(10, 5), (38, 5), (40, 44), (28, 44), (24, 18), (20, 44), (8, 44)], "cloth")
    c.rect(10, 5, 38, 10, "leather", hl=False)
    c.rect(22, 5, 26, 10, "brass", hl=False)
    c.rect(11, 24, 19, 31, "cloth", flat=0)
    c.rect(29, 24, 37, 31, "cloth", flat=0)


@icon("slot_hands")
def _(c):
    c.poly([(12, 22), (14, 10), (19, 9), (20, 20), (22, 6), (27, 6), (28, 20), (30, 8), (35, 9), (35, 22), (40, 18), (44, 21), (36, 34), (34, 42), (14, 42)], "leather")
    c.rect(13, 34, 35, 43, "cloth", hl=False)
    c.rect(16, 25, 32, 28, "steel", hl=False)


@icon("slot_boots")
def _(c):
    boot(c, 0, 0, 1.0)
    c.rect(11, 16, 27, 19, "brass", hl=False)
    c.rect(11, 24, 27, 27, "brass", hl=False)


@icon("slot_charm")
def _(c):  # bottle cap on a cord
    c.path([(8, 4), (16, 14), (22, 18)], 2.2, "leather", hl=False)
    c.path([(40, 4), (32, 14), (26, 18)], 2.2, "leather", hl=False)
    c.star(24, 31, 14, 11.5, 14, "brass", rot=0)
    c.circle(24, 31, 10.5, "brass")
    c.circle(24, 31, 6.5, "rust", hl=False)


@icon("slot_vial")
def _(c):
    c.path([(10, 6), (20, 10)], 2.2, "leather", hl=False)
    c.rect(19, 8, 29, 13, "wood")
    c.rect(20.5, 13, 27.5, 18, "ash")
    c.poly([(20.5, 18), (27.5, 18), (34, 26), (34, 44), (14, 44), (14, 26)], "ash")
    c.rect(16.5, 28, 31.5, 41.5, "glow")


@icon("slot_patch")
def _(c):
    shield(c, 24, 24, 1.35, "cloth")
    c.rect(20, 11, 28, 33, "blood", flat=1)
    c.rect(13, 18, 35, 26, "blood", flat=1)
    for (x, y) in ((8, 8), (40, 8), (8, 26), (40, 26), (24, 43)):
        c.px(x, y, "bone", 1)


# ================================================================== mods (12)
@icon("mod_scope")
def _(c):
    c.rect(6, 14, 42, 24, "gun")
    c.rect(4, 11, 10, 27, "gun")
    c.rect(38, 12, 44, 26, "gun")
    c.ellipse(41.5, 19, 2, 5, "teal", flat=1)
    crosshair(c, 22, 36, 8, "brass")


@icon("mod_ext_mag")
def _(c):
    c.poly([(14, 4), (28, 4), (34, 44), (20, 44)], "gun")
    c.poly([(14, 4), (28, 4), (28, 9), (14, 9)], "steel")
    for y in (14, 22, 30, 38):
        c.rect(15 + y * 0.15, y, 27 + y * 0.15, y + 1.2, "dark", flat=0)
    bullet(c, 16, 3, -90, 10, 6)


@icon("mod_barrel")
def _(c):
    c.rect(3, 19, 30, 27, "steel")
    c.rect(28, 15, 45, 31, "gun")
    for x in (32, 37, 42):
        c.rect(x, 18, x + 2, 28, "dark", flat=1)
    c.rect(6, 17, 10, 29, "gun", hl=False)


@icon("mod_stock")
def _(c):
    c.poly([(4, 14), (26, 18), (44, 16), (44, 26), (28, 28), (8, 40), (4, 38)], "wood")
    c.rect(3, 13, 7, 40, "leather")
    c.rect(38, 15, 45, 27, "gun", hl=False)


@icon("mod_weighted_head")
def _(c):
    c.rect(6, 10, 42, 32, "steel")
    c.rect(6, 10, 12, 32, "gun", hl=False)
    c.rect(36, 10, 42, 32, "gun", hl=False)
    c.rect(20, 32, 28, 45, "wood")
    for (x, y) in ((16, 15), (32, 15), (16, 27), (32, 27)):
        c.circle(x, y, 2, "brass", hl=False)


@icon("mod_grip")
def _(c):
    c.rect(16, 4, 32, 44, "leather")
    for y in range(6, 44, 6):
        c.line((16, y + 4), (32, y), 2.2, "cloth", cap=False, hl=False)
    c.rect(13, 3, 35, 8, "brass")
    c.rect(13, 40, 35, 45, "brass")


@icon("mod_edge")
def _(c):
    c.poly([(4, 40), (34, 10), (44, 4), (40, 14), (10, 44)], "steel")
    c.poly([(4, 40), (34, 10), (37, 13), (7, 43)], "frost", flat=2)
    c.rect(4, 38, 12, 45, "gun", hl=False)


@icon("mod_wraps")
def _(c):
    c.ellipse(20, 26, 15, 15, "bone")
    c.ring(20, 26, 10, 5, "bone", flat=0)
    c.circle(20, 26, 4, "dark", flat=1)
    c.poly([(30, 34), (45, 30), (45, 40), (32, 42)], "bone")
    c.circle(38, 37, 2.6, "blood", flat=1)


@icon("mod_coat_poison")
def _(c):
    drop(c, 24, 25, 1.45, "plague")
    c.circle(19, 30, 3, "glow", flat=2)


@icon("mod_coat_fire")
def _(c):
    flame(c, 24, 27, 1.35)


@icon("mod_coat_shock")
def _(c):
    bolt_glyph(c, 24, 24, 1.3, "teal")


@icon("mod_coat_frost")
def _(c):
    snowflake(c, 24, 24, 19)


# ======================================================= weapon styles (24)
@icon("style_ash_rook_boom")
def _(c):
    c.line((6, 34), (38, 16), 10, "rust", cap=False)
    c.line((36, 17), (44, 12), 13, "gun", cap=False)
    c.poly([(14, 34), (20, 31), (23, 41), (17, 43)], "gun")
    c.poly([(38, 14), (46, 9), (44, 4), (40, 6)], "dust", hl=False)
    c.line((4, 36), (9, 33), 8, "gun", cap=False)


@icon("style_ash_rook_cluster")
def _(c):
    for (x, y, r) in ((14, 33, 9), (34, 33, 9), (24, 20, 10)):
        c.circle(x, y, r, "wood")
        c.rect(x - 3, y - r - 3, x + 3, y - r + 2, "rust", hl=False)
    for (x, y) in ((24, 7), (14, 21), (34, 21)):
        c.circle(x + 2, y - 2, 2.5, "fire", flat=1)


@icon("style_ash_rook_mortar")
def _(c):
    c.poly([(10, 40), (28, 12), (38, 18), (22, 44)], "gun")
    c.ellipse(33, 15, 6.5, 4, "dark", flat=1)
    c.rect(6, 40, 30, 45, "rust")
    c.circle(38, 8, 6, "fire")
    c.circle(42, 13, 3, "dust", flat=2)


@icon("style_vesper_thorn_bolt")
def _(c):
    P = rifle(c, 2, 36, -22, 44, stock="wood")
    c.poly([P(24, -4), P(30, -4), P(30, -8), P(24, -8)], "steel", hl=False)
    c.line(P(44, -1), P(52, -1), 3, "plague", cap=False, hl=False)


@icon("style_vesper_thorn_semi")
def _(c):
    P = rifle(c, 4, 30, -10, 40, stock="wood")
    gun_mag(c, 20, 30, 7, 13, 3)
    c.rect(18, 22, 30, 24, "steel", hl=False)


@icon("style_vesper_thorn_coater")
def _(c):
    P = rifle(c, 2, 38, -24, 40, stock="wood")
    c.ellipse(38, 12, 7, 5, "glow")
    c.circle(44, 9, 2.4, "glow", flat=2)
    c.circle(31, 16, 2, "glow", flat=2)


@icon("style_pebble_maul")
def _(c):
    hammer(c, (8, 44), (31, 14), 26, 15, "steel", "wood")


@icon("style_pebble_sweep")
def _(c):
    c.ring(24, 26, 21, 16, "ash", 190, 350, hl=False)
    hammer(c, (4, 38), (34, 30), 20, 12, "steel", "wood")


@icon("style_pebble_driver")
def _(c):
    c.rect(22, 3, 26, 22, "wood")
    c.rect(11, 18, 37, 36, "steel")
    c.rect(11, 18, 37, 22, "gun", hl=False)
    c.poly([(16, 40), (32, 40), (24, 46)], "dust", flat=2)


@icon("style_bolt_juno_chain")
def _(c):
    c.poly([(26, 18), (40, 16), (44, 26), (40, 38), (26, 38), (22, 28)], "steel")
    c.rect(30, 20, 36, 34, "gun", hl=False)
    for i, (x, y) in enumerate(((19, 30), (13, 34), (7, 38))):
        c.ring(x, y, 4, 1.8, "brass", hl=False)


@icon("style_bolt_juno_whip")
def _(c):
    c.rect(32, 30, 44, 38, "leather")
    c.ring(24, 22, 15, 11.5, "leather", 120, 30, hl=False)
    c.ring(22, 22, 8, 5.5, "leather", 0, 260, hl=False)
    bolt_glyph(c, 12, 12, 0.45, "teal")
    bolt_glyph(c, 36, 10, 0.4, "teal")


@icon("style_bolt_juno_knuckle")
def _(c):
    for i in range(4):
        c.ring(10 + i * 9.5, 18, 6, 3, "brass")
    c.poly([(5, 22), (43, 22), (40, 34), (8, 34)], "brass")
    c.rect(14, 26, 34, 29, "dark", flat=1)


@icon("style_sister_cinder_suppressor")
def _(c):
    P = rifle(c, 2, 36, -18, 32)
    c.line(P(32, -1), P(47, -1), 7, "gun", cap=False)
    gun_mag(c, 17, 30, 6, 11, 2)


@icon("style_sister_cinder_burst")
def _(c):
    for ang, (x, y) in ((-30, (6, 34)), (0, (6, 24)), (30, (6, 14))):
        bullet(c, x, y, ang * 0.6 - 0, 24, 8)


@icon("style_sister_cinder_ember")
def _(c):
    bullet(c, 6, 32, -30, 28, 10)
    flame(c, 34, 13, 0.7)


@icon("style_quill_marrow_bayonet")
def _(c):
    blade(c, (8, 42), (42, 6), 8, "steel", "leather", "brass", 0.32)


@icon("style_quill_marrow_scalpels")
def _(c):
    scalpel(c, (8, 42), (40, 8))
    scalpel(c, (40, 42), (8, 8))


@icon("style_quill_marrow_cleaver")
def _(c):
    c.poly([(16, 6), (44, 6), (44, 30), (16, 30)], "steel")
    c.cut_circle(39, 11, 2.5)
    c.line((16, 22), (4, 40), 5, "wood")
    c.rect(16, 27, 44, 30, "frost", flat=1)


@icon("style_nyx_caldera_dustblades")
def _(c):
    for flip in (False, True):
        f = -1 if flip else 1
        cx = 24
        pts = [(cx + f * (-16), 42), (cx + f * (-12), 38), (cx + f * 6, 12), (cx + f * 16, 4), (cx + f * 10, 16), (cx + f * (-9), 42)]
        c.poly(pts, "steel")
        c.line((cx + f * (-17), 44), (cx + f * (-12), 37), 4.5, "dust" if flip else "leather")


@icon("style_nyx_caldera_long")
def _(c):
    blade(c, (6, 44), (44, 4), 6, "steel", "leather", "steel", 0.22)


@icon("style_nyx_caldera_viper")
def _(c):  # fang-curved dagger dripping venom
    c.poly([(12, 44), (10, 34), (14, 22), (24, 12), (38, 4), (30, 16), (22, 28), (18, 38)], "bone")
    c.line((6, 46), (13, 37), 5, "flesh")
    c.line((8, 34), (20, 42), 3.2, "flesh", hl=False)
    drop(c, 34, 22, 0.32, "glow")
    drop(c, 28, 34, 0.4, "glow")


@icon("style_helm_wisp_sidearm")
def _(c):
    pistol(c, 5, 12, 1.0, barrel_len=26, barrel_w=8)


@icon("style_helm_wisp_flare")
def _(c):
    c.rect(4, 12, 34, 24, "rust")
    c.rect(30, 9, 44, 27, "rust")
    c.ellipse(44, 18, 2, 8, "fire", flat=1)
    c.poly([(6, 24), (16, 24), (18, 44), (8, 45), (4, 40)], "wood")


@icon("style_helm_wisp_machine")
def _(c):
    pistol(c, 4, 10, 1.0, barrel_len=28, barrel_w=8)
    gun_mag(c, 7, 30, 7, 15, 1)


# =========================================================== abilities (16)
@icon("ab_ash_rook_a")  # Rattle Rush
def _(c):
    speed_lines(c, 18, 14, 3, 14, 8, "ash")
    c.poly([(16, 10), (34, 10), (45, 24), (34, 38), (16, 38), (24, 24)], "rust")
    c.poly([(30, 18), (38, 24), (30, 30)], "dust", flat=2)


@icon("ab_ash_rook_b")  # Short Charge: slam
def _(c):
    c.ring(24, 38, 21, 16, "dust", 180, 360, hl=False)
    c.poly([(16, 6), (32, 6), (32, 22), (28, 30), (20, 30), (16, 22)], "skin")
    c.rect(16, 6, 32, 12, "rust", hl=False)
    c.poly([(4, 42), (44, 42), (44, 45), (4, 45)], "wood", flat=0)
    c.poly([(22, 34), (26, 34), (28, 42), (20, 42)], "dark", flat=1)


@icon("ab_vesper_thorn_a")  # Vial Shot
def _(c):
    speed_lines(c, 16, 18, 3, 12, 6, "plague")
    c.ellipse(30, 24, 13, 8, "ash")
    c.ellipse(32, 25, 10, 5.5, "glow")
    c.rect(14, 21, 18, 27, "wood")


@icon("ab_vesper_thorn_b")  # Smoke Vial
def _(c):
    cloud(c, 24, 18, 1.3, "ash")
    c.rect(20, 28, 28, 32, "wood")
    c.ellipse(24, 38, 8, 7, "ash")
    c.ellipse(24, 40, 6, 4.5, "glow")


@icon("ab_pebble_a")  # Maul Slam
def _(c):
    burst(c, 30, 36, 14, 7, 8, "fire", "dust")
    hammer(c, (6, 8), (28, 30), 20, 12, "steel", "wood")


@icon("ab_pebble_b")  # Quake Stomp
def _(c):
    c.ring(24, 40, 22, 18, "dust", 180, 360, hl=False)
    c.ring(24, 40, 14, 11, "dust", 180, 360, hl=False)
    boot(c, 4, -2, 0.8)
    c.path([(8, 45), (16, 41), (22, 45), (30, 41), (40, 45)], 2, "ink", flat=1)


@icon("ab_bolt_juno_a")  # Overload
def _(c):
    c.circle(24, 24, 8, "teal")
    for k in range(6):
        a = math.radians(k * 60 + 15)
        x1, y1 = 24 + math.cos(a) * 20, 24 + math.sin(a) * 20
        mx, my = 24 + math.cos(a + 0.35) * 13, 24 + math.sin(a + 0.35) * 13
        c.path([(24 + math.cos(a) * 8, 24 + math.sin(a) * 8), (mx, my), (x1, y1)], 2.6, "teal", hl=False)
    c.circle(24, 24, 3.5, "bone", flat=2)


@icon("ab_bolt_juno_b")  # Static Cage
def _(c):
    c.rect(6, 6, 42, 10, "steel")
    c.rect(6, 38, 42, 42, "steel")
    for x in (9, 18, 27, 36):
        c.rect(x, 10, x + 3, 38, "gun", hl=False)
    bolt_glyph(c, 24, 24, 0.6, "teal")


@icon("ab_sister_cinder_a")  # Field Draught (heal)
def _(c):
    c.circle(24, 24, 19, "teal", flat=0)
    c.circle(24, 24, 16, "dark", flat=1)
    c.rect(19, 9, 29, 39, "bone")
    c.rect(9, 19, 39, 29, "bone")
    c.rect(21, 11, 27, 37, "blood", flat=1)
    c.rect(11, 21, 37, 27, "blood", flat=1)


@icon("ab_sister_cinder_b")  # Smoke Censer
def _(c):
    c.path([(24, 3), (24, 14)], 2, "brass", hl=False)
    c.poly([(12, 18), (36, 18), (34, 32), (14, 32)], "brass")
    c.rect(10, 15, 38, 19, "brass")
    c.rect(18, 22, 30, 25, "dark", flat=1)
    cloud(c, 24, 38, 0.8, "teal")


@icon("ab_quill_marrow_a")  # Dissect: mark
def _(c):
    crosshair(c, 22, 26, 15, "dust")
    scalpel(c, (40, 44), (24, 26))


@icon("ab_quill_marrow_b")  # Long Lunge
def _(c):
    speed_lines(c, 14, 12, 3, 10, 6, "ash")
    blade(c, (6, 30), (45, 30), 7, "steel", "leather", "brass", 0.2)


@icon("ab_nyx_caldera_a")  # Blade Rush
def _(c):
    c.ring(18, 30, 22, 17, "frost", 250, 20, hl=False)
    blade(c, (10, 44), (40, 10), 6, "steel", "leather", "dust", 0.25)


@icon("ab_nyx_caldera_b")  # Shadow Slip
def _(c):
    c.poly([(24, 4), (36, 12), (40, 44), (8, 44), (12, 12)], "flesh")
    c.ellipse(24, 18, 7, 8, "dark", flat=0)
    c.px(21, 18, "dust", 3)
    c.px(26, 18, "dust", 3)
    for x in (4, 42):
        c.rect(x, 20, x + 2, 40, "flesh", flat=0)


@icon("ab_helm_wisp_a")  # Drone Call
def _(c):
    drone(c, 24, 22, 1.25)


@icon("ab_helm_wisp_b")  # Overdrive
def _(c):
    drone(c, 20, 28, 1.0)
    chevron_up(c, 36, 10, 0.7, "dust")
    chevron_up(c, 36, 18, 0.7, "dust")


# ============================================================== quirks (9)
@icon("quirk_no_reload")
def _(c):
    c.rect(4, 16, 40, 30, "gun")
    c.rect(26, 16, 40, 30, "rust", hl=False)
    c.rect(36, 13, 45, 33, "dust")
    for x in (10, 16, 22):
        c.path([(x, 12), (x + 2, 8), (x, 4)], 2, "fire", hl=False)


@icon("quirk_pack_leader")
def _(c):
    paw(c, 22, 28, 1.25, "bone")
    chevron_up(c, 38, 8, 0.6, "dust")


@icon("quirk_glass_cannon")
def _(c):
    c.circle(24, 26, 17, "frost")
    c.path([(16, 12), (22, 22), (18, 28), (26, 36), (24, 42)], 2, "ink", flat=1)
    c.path([(22, 22), (32, 20)], 2, "ink", flat=1)
    c.circle(18, 19, 3, "bone", flat=2)


@icon("quirk_bloodthirst")
def _(c):
    drop(c, 24, 27, 1.4, "blood")
    c.poly([(16, 14), (20, 14), (18, 22)], "bone", flat=2)
    c.poly([(28, 14), (32, 14), (30, 22)], "bone", flat=2)


@icon("quirk_scavenger")
def _(c):
    c.ring(24, 20, 17, 8, "signal", 180, 360, hl=False)
    c.rect(7, 20, 15, 34, "signal")
    c.rect(33, 20, 41, 34, "signal")
    c.rect(7, 30, 15, 35, "steel", hl=False)
    c.rect(33, 30, 41, 35, "steel", hl=False)
    nut(c, 24, 38, 6, "brass", 2)


@icon("quirk_berserker")
def _(c):
    skull(c, 24, 24, 1.4, "bone", "signal")
    c.poly([(6, 10), (12, 2), (14, 14)], "bone")
    c.poly([(42, 10), (36, 2), (34, 14)], "bone")


@icon("quirk_steady")
def _(c):
    crosshair(c, 24, 24, 18, "teal")
    c.circle(24, 24, 3.5, "dust", flat=2)


@icon("quirk_dust_eater")
def _(c):  # gas mask, green filter
    c.ellipse(24, 20, 16, 15, "dark")
    c.circle(16, 18, 6, "brass")
    c.circle(32, 18, 6, "brass")
    c.circle(16, 18, 4, "glow", flat=1)
    c.circle(32, 18, 4, "glow", flat=1)
    c.rect(18, 30, 30, 44, "steel")
    c.rect(18, 34, 30, 36, "gun", flat=0)
    c.rect(18, 39, 30, 41, "gun", flat=0)


@icon("quirk_packrat")
def _(c):
    bag(c, 22, 28, 1.2, "cloth")
    c.poly([(30, 4), (44, 4), (44, 18)], "dust")
    c.rect(36, 10, 40, 16, "dust", flat=1)


# ============================================================== tonics (7)
@icon("tonic_menders")
def _(c):
    bottle(c, "round", "blood")
    heart(c, 24, 33, 0.5, "bone")


@icon("tonic_iron")
def _(c):
    bottle(c, "square", "steel")
    shield(c, 24, 31, 0.55, "gun")


@icon("tonic_ward")
def _(c):
    bottle(c, "flask", "glow")


@icon("tonic_firebrand")
def _(c):
    bottle(c, "ampoule", "dust")
    flame(c, 24, 34, 0.42)


@icon("tonic_spark")
def _(c):
    bottle(c, "tall", "teal")
    bolt_glyph(c, 24, 33, 0.45, "bone")


@icon("tonic_quickstep")
def _(c):
    bottle(c, "hip", "plague")
    wing(c, 18, 32, 0.6, "bone")


@icon("tonic_saints")
def _(c):
    bottle(c, "ornate", "bone", cork="brass")
    c.rect(22.5, 25, 25.5, 38, "brass", flat=1)
    c.rect(19, 28, 29, 31, "brass", flat=1)


# ========================================================= ingredients (6)
@icon("ing_herb")
def _(c):
    c.path([(24, 44), (24, 22)], 3, "wood", hl=False)
    c.path([(24, 44), (16, 46), (10, 42)], 2.4, "wood", hl=False)
    c.path([(24, 44), (32, 46), (38, 43)], 2.4, "wood", hl=False)
    for (x, y, a) in ((14, 16, -1), (34, 16, 1), (24, 8, 0), (16, 28, -1), (32, 28, 1)):
        c.ellipse(x, y, 6.5 if a else 5, 4.5 if a else 8, "plague")


@icon("ing_plague_gland")
def _(c):
    c.ellipse(24, 26, 17, 15, "flesh")
    c.circle(16, 36, 6, "flesh")
    c.circle(31, 22, 5.5, "glow")
    c.circle(19, 20, 3.5, "glow")
    c.circle(26, 33, 3, "glow")


@icon("ing_dust_shard")
def _(c):
    crystal(c, 22, 26, 1.25, "dust")
    crystal(c, 37, 34, 0.6, "dust")


@icon("ing_machine_oil")
def _(c):
    c.rect(8, 14, 36, 44, "rust")
    c.rect(8, 22, 36, 34, "dust")
    c.poly([(30, 14), (36, 14), (45, 4), (42, 2)], "steel")
    c.rect(12, 8, 22, 14, "steel")
    drop(c, 18, 28, 0.32, "dark")


@icon("ing_salvage_core")
def _(c):
    c.rect(8, 8, 40, 40, "steel")
    c.rect(4, 14, 8, 34, "gun", hl=False)
    c.rect(40, 14, 44, 34, "gun", hl=False)
    c.rect(14, 4, 34, 8, "gun", hl=False)
    c.circle(24, 24, 10, "dark", flat=1)
    c.circle(24, 24, 7, "teal")
    c.circle(22, 22, 2.2, "bone", flat=2)


@icon("ing_medicine")
def _(c):
    c.rect(4, 14, 44, 42, "bone")
    c.rect(16, 8, 32, 14, "steel", hl=False)
    c.rect(20, 18, 28, 38, "blood", flat=1)
    c.rect(14, 24, 34, 32, "blood", flat=1)


# ===================================================== materials / currency
@icon("mat_dust_heart")
def _(c):
    heart(c, 24, 25, 1.45, "dust")
    crystal(c, 24, 25, 0.5, "fire")


@icon("mat_salvage_core")
def _(c):
    ICONS["ing_salvage_core"](c)


@icon("cur_scrap")
def _(c):
    nut(c, 18, 28, 14, "brass", 5)
    c.line((30, 6), (42, 18), 6, "steel")
    c.rect(26, 2, 34, 10, "steel")


@icon("cur_xp")
def _(c):
    crystal(c, 24, 24, 1.35, "dust")
    c.px(41, 9, "dust", 3)
    c.px(7, 36, "dust", 3)


@icon("cur_level")
def _(c):
    shield(c, 24, 24, 1.3, "gun")
    chevron_up(c, 24, 14, 0.9, "dust")
    chevron_up(c, 24, 24, 0.9, "dust")


@icon("cur_extract")
def _(c):
    c.ellipse(24, 38, 20, 7, "teal")
    c.ellipse(24, 38, 14, 4, "dark", flat=1)
    chevron_up(c, 24, 14, 1.0, "teal")
    chevron_up(c, 24, 24, 0.8, "teal")


# ========================================================== ammo (4)
@icon("ammo_incendiary")
def _(c):
    bullet(c, 8, 40, -45, 34, 11, "brass", "dust")
    flame(c, 36, 12, 0.55)


@icon("ammo_shock")
def _(c):
    bullet(c, 8, 40, -45, 34, 11, "steel", "teal")
    bolt_glyph(c, 38, 30, 0.42, "teal")


@icon("ammo_explosive")
def _(c):
    c.ellipse(24, 26, 13, 17, "gun")
    c.rect(11, 22, 37, 27, "signal")
    c.rect(18, 4, 30, 10, "brass")
    c.rect(22, 1, 26, 4, "steel", hl=False)


@icon("ammo_frost")
def _(c):
    bullet(c, 8, 40, -45, 34, 11, "steel", "frost")
    snowflake(c, 37, 32, 8)


# ====================================================== run upgrades (35)
@icon("up_harder_hit")
def _(c):
    burst(c, 30, 18, 15, 8, 8, "fire", "dust")
    c.poly([(6, 24), (24, 22), (28, 30), (24, 42), (8, 42)], "skin")
    c.rect(6, 28, 26, 31, "skin", flat=0)


@icon("up_quick_mag")
def _(c):
    gun_mag(c, 12, 10, 12, 28, 6)
    speed_lines(c, 10, 18, 3, 8, 7, "ash")
    chevron_up(c, 36, 30, 0.6, "dust")


@icon("up_thick_plate")
def _(c):
    c.rect(6, 6, 42, 42, "steel")
    c.rect(10, 10, 38, 38, "steel", flat=0)
    for (x, y) in ((10, 10), (38, 10), (10, 38), (38, 38)):
        c.circle(x, y, 2.6, "brass", hl=False)


@icon("up_dust_runner")
def _(c):
    boot(c, -2, 2, 0.95)
    wing(c, 22, 12, 0.85, "bone")


@icon("up_deep_mag")
def _(c):
    c.poly([(16, 2), (32, 2), (34, 46), (14, 46)], "gun")
    for y in range(6, 44, 5):
        c.rect(17, y, 31, y + 2, "brass", hl=False)


@icon("up_cool_head")
def _(c):
    c.rect(20, 4, 28, 34, "frost")
    c.circle(24, 38, 8, "teal")
    c.rect(22, 18, 26, 36, "teal", flat=1)
    for y in (8, 14, 20):
        c.rect(29, y, 33, y + 1.5, "ash", flat=2)


@icon("up_ricochet")
def _(c):
    c.path([(4, 8), (18, 34), (30, 12)], 3, "dust", hl=False)
    c.rect(2, 38, 30, 42, "steel", hl=False)
    bullet(c, 30, 12, -40, 18, 7)


@icon("up_split_shot")
def _(c):
    for ang in (-30, 0, 30):
        a = math.radians(ang)
        bullet(c, 8 + math.cos(a) * 8, 24 + math.sin(a) * 8, ang, 22, 7)
    c.circle(8, 24, 4, "fire", flat=1)


@icon("up_dust_rounds")
def _(c):
    bullet(c, 4, 26, -15, 36, 11)
    c.circle(30, 33, 3, "glow", flat=2)
    drop(c, 18, 40, 0.38, "glow")
    drop(c, 34, 42, 0.3, "glow")


@icon("up_piercing")
def _(c):
    c.rect(18, 4, 24, 44, "steel")
    c.cut_rect(17, 19, 25, 29)
    c.path([(2, 24), (18, 24)], 4, "fire", hl=False)
    bullet(c, 22, 24, 0, 24, 10)


@icon("up_scrap_drone")
def _(c):
    drone(c, 24, 24, 1.1, "rust", "dust")


@icon("up_spore_mines")
def _(c):
    c.star(24, 28, 19, 12, 8, "flesh", rot=0)
    c.circle(24, 28, 12, "flesh")
    c.circle(24, 28, 5, "glow", flat=2)
    c.circle(18, 22, 2.2, "glow", flat=2)


@icon("up_orbit_blades")
def _(c):
    c.ring(24, 24, 17, 15, "ash", flat=1)
    c.circle(24, 24, 5, "dust", flat=2)
    for k in range(3):
        a = math.radians(-90 + k * 120)
        x, y = 24 + math.cos(a) * 16, 24 + math.sin(a) * 16
        b = a + math.pi / 2
        c.poly([(x - math.cos(b) * 8, y - math.sin(b) * 8), (x + math.cos(a) * 4, y + math.sin(a) * 4), (x + math.cos(b) * 8, y + math.sin(b) * 8), (x - math.cos(a) * 3, y - math.sin(a) * 3)], "steel")


@icon("up_firewalk")
def _(c):
    flame(c, 14, 36, 0.55)
    flame(c, 34, 24, 0.55)
    boot(c, 18, -2, 0.6)


@icon("up_second_wind")
def _(c):
    c.ring(22, 24, 16, 12, "teal", 200, 80, hl=False)
    c.ring(22, 24, 9, 5.5, "teal", 20, 260, hl=False)
    heart(c, 36, 36, 0.45, "blood")


@icon("up_iron_tonic")
def _(c):
    c.ring(24, 24, 21, 18, "teal", hl=False)
    shield(c, 24, 25, 1.0, "steel")
    c.rect(22, 15, 26, 33, "brass", flat=1)


@icon("up_scavengers_eye")
def _(c):
    c.ellipse(24, 22, 20, 12, "bone")
    c.circle(24, 22, 8, "brass")
    c.circle(24, 22, 4, "ink", flat=1)
    c.px(21, 19, "bone", 2)
    nut(c, 36, 39, 7, "brass", 2.5)


@icon("up_lucky_vial")
def _(c):
    bottle(c, "round", "dust")
    c.star(24, 33, 7, 3, 5, "fire", hl=False)


@icon("up_aftershock")
def _(c):
    burst(c, 24, 28, 20, 10, 10, "fire", "dust")
    c.circle(24, 28, 6, "bone", flat=2)


@icon("up_rubble_wall")
def _(c):
    for row in range(4):
        y = 10 + row * 8
        off = 0 if row % 2 == 0 else 6
        for i in range(-1, 4):
            x = 4 + off + i * 12
            x0, x1 = max(4, x), min(44, x + 11)
            if x1 - x0 > 3:
                c.rect(x0, y, x1, y + 7, "ash")
    c.circle(38, 6, 3.5, "ash")


@icon("up_bell_tower")
def _(c):
    c.poly([(24, 4), (32, 10), (34, 30), (40, 36), (8, 36), (14, 30), (16, 10)], "brass")
    c.circle(24, 40, 4, "brass")
    c.rect(20, 2, 28, 6, "steel", hl=False)


@icon("up_marked")
def _(c):
    skull(c, 24, 22, 1.05, "flesh")
    crosshair(c, 24, 24, 21, "dust")


@icon("up_unbreakable")
def _(c):
    c.poly([(4, 14), (36, 14), (44, 8), (44, 22), (36, 22), (30, 28), (30, 34), (38, 42), (10, 42), (18, 34), (18, 28), (8, 22)], "gun")
    c.rect(4, 14, 36, 18, "steel", hl=False)


@icon("up_quarry_slam")
def _(c):
    hammer(c, (40, 6), (20, 30), 22, 12, "ash", "wood")
    c.path([(4, 44), (14, 38), (22, 44), (30, 38), (44, 44)], 2.2, "dust", hl=False)


@icon("up_live_wire")
def _(c):
    for k in range(4):
        c.ellipse(14 + k * 7, 26, 4, 12, "brass", hl=False)
        c.ellipse(14 + k * 7, 26, 2, 9, "dark", flat=1)
    c.path([(2, 34), (10, 30)], 2.5, "rust", hl=False)
    bolt_glyph(c, 42, 14, 0.4, "teal")


@icon("up_short_circuit")
def _(c):
    c.rect(6, 18, 18, 30, "dark")
    c.rect(18, 20, 22, 23, "brass", hl=False)
    c.rect(18, 26, 22, 29, "brass", hl=False)
    c.rect(30, 18, 42, 30, "dark")
    c.rect(26, 22, 30, 26, "brass", hl=False)
    burst(c, 24, 24, 9, 4, 6, "teal", "teal")
    c.path([(2, 24), (6, 24)], 3, "rust", hl=False)


@icon("up_sanctuary")
def _(c):
    c.ellipse(24, 36, 21, 8, "teal")
    c.ellipse(24, 36, 15, 5, "teal", flat=0)
    c.rect(20, 4, 28, 30, "bone")
    c.rect(12, 10, 36, 18, "bone")


@icon("up_burn_it_down")
def _(c):
    flame(c, 24, 26, 1.25)
    c.rect(21, 32, 27, 44, "bone")
    c.rect(16, 34, 32, 38, "bone")


@icon("up_field_notes")
def _(c):
    book(c, 8, 6, 36, 42, "leather", "bone")
    c.line((44, 4), (30, 30), 4, "brass")
    for y in (14, 20, 26):
        c.rect(14, y, 30, y + 1.5, "ash", flat=2)


@icon("up_bayonet")
def _(c):
    P = rifle(c, 2, 40, -32, 28)
    blade(c, P(26, -1), P(48, -1), 5, "frost", "gun", "gun", 0.1)


@icon("up_back_way_out")
def _(c):
    c.rect(10, 4, 38, 44, "wood")
    c.rect(14, 8, 34, 44, "dark", flat=1)
    c.poly([(14, 8), (28, 12), (28, 44), (14, 44)], "wood")
    c.circle(25, 28, 1.8, "brass", flat=2)


@icon("up_double_cross")
def _(c):
    blade(c, (6, 42), (42, 6), 6, "steel", "leather", "brass", 0.25)
    blade(c, (42, 42), (6, 6), 6, "steel", "leather", "brass", 0.25)


@icon("up_wingman")
def _(c):
    wing(c, 24, 26, 1.2, "bone", flip=False)
    wing(c, 24, 26, 1.2, "bone", flip=True)
    c.circle(24, 26, 4, "dust", flat=2)


@icon("up_supply_drop")
def _(c):
    c.ellipse(24, 12, 18, 10, "cloth")
    c.cut_rect(4, 13, 46, 24)
    for x in (8, 40):
        c.path([(x, 12), (24 + (x - 24) * 0.4, 30)], 1.6, "bone", hl=False)
    crate(c, 14, 28, 34, 45, "wood")


@icon("up_squadron")
def _(c):
    drone(c, 24, 14, 0.7)
    drone(c, 11, 34, 0.6)
    drone(c, 37, 34, 0.6)


# ========================================================== recipes (18)
@icon("rec_plague_bloom")
def _(c):
    for k in range(5):
        a = math.radians(-90 + k * 72)
        c.ellipse(24 + math.cos(a) * 11, 22 + math.sin(a) * 11, 8, 8, "flesh")
    c.circle(24, 22, 7, "glow")
    c.path([(24, 32), (24, 46)], 3, "plague", hl=False)


@icon("rec_arc_storm")
def _(c):
    cloud(c, 24, 14, 1.2, "dark")
    bolt_glyph(c, 18, 32, 0.6, "teal")
    bolt_glyph(c, 32, 34, 0.5, "teal")


@icon("rec_blade_storm")
def _(c):
    for k in range(4):
        a = math.radians(k * 90 + 20)
        b = a + math.radians(70)
        c.poly([(24, 24), (24 + math.cos(a) * 21, 24 + math.sin(a) * 21), (24 + math.cos(b) * 12, 24 + math.sin(b) * 12)], "steel")
    c.circle(24, 24, 5, "dust")


@icon("rec_lead_rain")
def _(c):
    cloud(c, 24, 10, 1.0, "dark")
    for (x, y) in ((10, 24), (22, 30), (34, 24), (16, 40), (30, 42)):
        bullet(c, x, y - 8, 90, 12, 5)


@icon("rec_hellfire_stride")
def _(c):
    flame(c, 24, 22, 1.3)
    boot(c, 8, 12, 0.66)


@icon("rec_phoenix")
def _(c):
    wing(c, 24, 22, 1.25, "dust")
    wing(c, 24, 22, 1.25, "dust", flip=True)
    flame(c, 24, 30, 0.6)


@icon("rec_bulwark")
def _(c):  # spiked tower shield
    c.poly([(8, 6), (40, 6), (40, 34), (24, 45), (8, 34)], "steel")
    c.poly([(12, 10), (36, 10), (36, 32), (24, 40), (12, 32)], "rust")
    c.rect(22, 10, 26, 40, "steel", hl=False)
    for x in (8, 24, 40):
        c.poly([(x - 3, 6), (x, 0), (x + 3, 6)], "steel", hl=False)


@icon("rec_deadeye")
def _(c):
    c.ellipse(24, 24, 20, 12, "bone")
    c.circle(24, 24, 8, "signal")
    c.circle(24, 24, 3.5, "ink", flat=1)
    crosshair(c, 24, 24, 20, "dust")


@icon("rec_hive")
def _(c):
    for (x, y) in ((16, 16), (32, 16), (24, 30), (8, 30), (40, 30)):
        pts = [(x + 8 * math.cos(math.radians(30 + 60 * i)), y + 8 * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
        c.poly(pts, "brass")
    c.circle(24, 30, 3, "dust", flat=2)


@icon("rec_fortune")
def _(c):
    c.circle(24, 24, 18, "brass")
    c.circle(24, 24, 14, "brass", flat=0)
    c.star(24, 25, 11, 5, 5, "fire")


@icon("rec_earthquake")
def _(c):
    c.poly([(2, 30), (46, 30), (46, 46), (2, 46)], "wood")
    c.path([(24, 30), (20, 36), (26, 40), (22, 46)], 3, "ink", flat=1)
    for (x, y) in ((10, 18), (36, 14), (24, 8)):
        c.poly([(x - 4, y), (x + 4, y - 3), (x + 5, y + 4), (x - 2, y + 6)], "ash")


@icon("rec_death_knell")
def _(c):
    ICONS["up_bell_tower"](c)
    skull(c, 24, 22, 0.5, "bone")


@icon("rec_mountain")
def _(c):
    c.poly([(2, 44), (18, 10), (26, 22), (32, 14), (46, 44)], "ash")
    c.poly([(18, 10), (24, 18), (20, 20), (14, 18)], "bone", flat=2)


@icon("rec_thunderhead")
def _(c):
    cloud(c, 24, 18, 1.5, "dark")
    bolt_glyph(c, 24, 36, 0.55, "dust")


@icon("rec_cathedral_fire")
def _(c):
    c.poly([(8, 44), (8, 18), (24, 4), (40, 18), (40, 44)], "ash")
    c.poly([(14, 44), (14, 22), (24, 12), (34, 22), (34, 44)], "dark", flat=1)
    flame(c, 24, 32, 0.75)


@icon("rec_autopsy_table")
def _(c):
    c.rect(4, 26, 44, 32, "steel")
    c.rect(8, 32, 12, 44, "gun")
    c.rect(36, 32, 40, 44, "gun")
    scalpel(c, (10, 20), (38, 8))


@icon("rec_ghost_debt")
def _(c):
    c.poly([(10, 44), (10, 18), (16, 8), (32, 8), (38, 18), (38, 44), (32, 38), (24, 44), (16, 38)], "frost")
    c.circle(19, 20, 3, "ink", flat=1)
    c.circle(29, 20, 3, "ink", flat=1)
    nut(c, 24, 32, 5, "brass", 1.8)


@icon("rec_air_raid")
def _(c):
    c.poly([(4, 14), (40, 14), (46, 18), (40, 22), (4, 22)], "steel")
    c.poly([(16, 14), (24, 4), (28, 4), (24, 14)], "steel")
    c.poly([(16, 22), (24, 30), (28, 30), (24, 22)], "steel")
    for (x, y) in ((14, 34), (26, 40)):
        c.ellipse(x, y, 3, 5, "gun")


# ========================================================= hangar camp (6)
@icon("camp_generator")
def _(c):
    c.rect(4, 14, 44, 40, "rust")
    c.rect(8, 18, 26, 36, "dark", flat=1)
    for y in (21, 26, 31):
        c.rect(10, y, 24, y + 2, "ash", flat=2)
    c.circle(35, 26, 6, "brass")
    bolt_glyph(c, 35, 26, 0.3, "dust")
    c.rect(8, 40, 14, 44, "gun", hl=False)
    c.rect(34, 40, 40, 44, "gun", hl=False)


@icon("camp_radio_tower")
def _(c):
    c.poly([(24, 8), (34, 44), (30, 44), (24, 16), (18, 44), (14, 44)], "steel")
    c.rect(17, 30, 31, 32, "steel", hl=False)
    c.ring(24, 10, 12, 9.5, "teal", 210, 330, hl=False)
    c.ring(24, 10, 20, 17.5, "teal", 215, 325, hl=False)
    c.circle(24, 8, 3, "signal", flat=1)


@icon("camp_scrap_press")
def _(c):
    c.rect(4, 4, 44, 10, "gun")
    c.rect(8, 10, 12, 44, "gun")
    c.rect(36, 10, 40, 44, "gun")
    c.rect(14, 10, 34, 20, "steel")
    nut(c, 24, 34, 9, "brass", 3)


@icon("camp_ammo_bench")
def _(c):
    c.rect(4, 28, 44, 33, "wood")
    c.rect(6, 33, 10, 44, "wood")
    c.rect(38, 33, 42, 44, "wood")
    for x in (10, 18, 26, 34):
        bullet(c, x + 2, 28, -90, 18, 6)


@icon("camp_stash")
def _(c):
    c.rect(4, 18, 44, 42, "gun")
    c.poly([(4, 18), (8, 8), (40, 8), (44, 18)], "steel")
    c.rect(20, 22, 28, 32, "brass")
    c.rect(23, 26, 25, 30, "ink", flat=1)


@icon("camp_backpack")
def _(c):
    bag(c, 24, 26, 1.35, "cloth")


# ================================================================ tabs (10)
@icon("tab_camp")
def _(c):
    tent(c)


@icon("tab_crew")
def _(c):
    for (x, y, s, r) in ((14, 18, 0.8, "dark"), (34, 18, 0.8, "dark"), (24, 14, 1.0, "rust")):
        c.circle(x, y, 6 * s, r)
        c.poly([(x - 10 * s, y + 26 * s), (x - 9 * s, y + 10 * s), (x + 9 * s, y + 10 * s), (x + 10 * s, y + 26 * s)], r)


@icon("tab_kennel")
def _(c):
    c.poly([(24, 4), (44, 20), (40, 20), (40, 44), (8, 44), (8, 20), (4, 20)], "wood")
    c.poly([(16, 44), (16, 30), (24, 24), (32, 30), (32, 44)], "dark", flat=1)
    paw(c, 24, 38, 0.38, "bone")


@icon("tab_brew")
def _(c):
    c.ellipse(24, 30, 18, 14, "gun")
    c.rect(4, 18, 44, 24, "gun")
    c.ellipse(24, 20, 17, 4, "glow")
    c.circle(20, 12, 3, "glow")
    c.circle(29, 6, 2.2, "glow")
    c.rect(8, 42, 12, 46, "gun", hl=False)
    c.rect(36, 42, 40, 46, "gun", hl=False)


@icon("tab_stash")
def _(c):
    ICONS["camp_stash"](c)


@icon("tab_workshop")
def _(c):
    cog(c, 30, 30, 14, 8, "steel", 4)
    c.line((4, 6), (22, 24), 5, "rust")
    c.ring(5, 6, 5, 2.4, "rust", hl=False)


@icon("tab_daily")
def _(c):
    c.rect(6, 8, 42, 44, "bone")
    c.rect(6, 8, 42, 16, "signal")
    c.rect(12, 4, 16, 12, "steel")
    c.rect(32, 4, 36, 12, "steel")
    c.path([(14, 30), (21, 37), (34, 22)], 3.5, "plague", hl=False)


@icon("tab_stories")
def _(c):
    book(c, 6, 4, 40, 42, "rust", "bone")
    c.rect(26, 4, 30, 46, "dust", flat=1)


@icon("tab_goals")
def _(c):
    c.rect(10, 4, 14, 46, "steel")
    c.poly([(14, 6), (42, 10), (36, 16), (42, 22), (14, 24)], "signal")


@icon("tab_notes")
def _(c):
    c.rect(8, 4, 38, 44, "bone")
    for y in (12, 18, 24, 30, 36):
        c.rect(12, y, 34, y + 1.5, "ash", flat=1)
    c.line((44, 10), (26, 40), 4.5, "dust")


# ============================================================ settings (15)
@icon("set_stick")
def _(c):
    c.ellipse(24, 38, 20, 7, "gun")
    c.rect(22, 16, 26, 38, "steel")
    c.circle(24, 13, 9, "signal")


@icon("set_lefty")
def _(c):
    c.poly([(16, 22), (18, 8), (23, 8), (24, 20), (26, 4), (31, 4), (32, 20), (34, 8), (39, 9), (39, 30), (34, 44), (18, 44)], "skin")
    c.poly([(2, 24), (12, 14), (12, 20), (16, 20), (16, 28), (12, 28), (12, 34)], "dust")


@icon("set_hints")
def _(c):
    c.circle(24, 18, 14, "fire")
    c.rect(18, 28, 30, 40, "steel")
    c.rect(18, 32, 30, 34, "gun", flat=0)
    c.rect(20, 40, 28, 44, "gun", hl=False)


@icon("set_mute")
def _(c):
    speaker(c, 4, 24, "steel")
    c.line((30, 16), (44, 32), 3.5, "signal", hl=False)
    c.line((44, 16), (30, 32), 3.5, "signal", hl=False)


@icon("set_volume")
def _(c):
    speaker(c, 4, 24, "steel")
    c.ring(22, 24, 11, 8, "dust", 300, 60, hl=False)
    c.ring(22, 24, 19, 16, "dust", 305, 55, hl=False)


@icon("set_music")
def _(c):
    c.rect(18, 6, 22, 36, "brass")
    c.rect(34, 4, 38, 32, "brass")
    c.poly([(18, 6), (38, 2), (38, 10), (18, 14)], "brass")
    c.ellipse(14, 37, 7, 5.5, "brass")
    c.ellipse(30, 33, 7, 5.5, "brass")


@icon("set_sfx")
def _(c):
    burst(c, 24, 24, 20, 9, 7, "fire", "rust")


@icon("set_ambience")
def _(c):
    for (y, L) in ((12, 34), (24, 40), (36, 28)):
        c.path([(4, y), (4 + L * 0.5, y - 3), (4 + L, y)], 3, "ash", hl=False)
    c.ellipse(40, 34, 5, 3, "plague")


@icon("set_ui")
def _(c):
    c.poly([(10, 4), (34, 26), (24, 27), (30, 40), (25, 42), (19, 30), (10, 36)], "bone")


@icon("set_vibration")
def _(c):
    c.rect(14, 4, 34, 44, "gun")
    c.rect(17, 8, 31, 36, "teal", flat=0)
    for x in (6, 40):
        c.path([(x, 14), (x + 3, 20), (x, 26), (x + 3, 32)], 2.2, "dust", hl=False)


@icon("set_shake")
def _(c):
    c.rect(8, 14, 40, 38, "steel")
    c.rect(18, 8, 30, 14, "steel")
    c.circle(24, 26, 8, "gun")
    c.circle(24, 26, 5, "teal", flat=1)
    c.path([(2, 10), (6, 6)], 2.2, "dust", hl=False)
    c.path([(46, 40), (42, 44)], 2.2, "dust", hl=False)


@icon("set_shimmer")
def _(c):
    c.circle(24, 34, 10, "fire")
    c.cut_rect(0, 36, 48, 48)
    for y in (8, 16, 24):
        c.path([(8, y), (16, y - 3), (24, y), (32, y - 3), (40, y)], 2.4, "dust", hl=False)
    c.rect(4, 36, 44, 40, "wood", hl=False)


@icon("set_grain")
def _(c):
    c.circle(24, 24, 19, "gun")
    for k in range(5):
        a = math.radians(-90 + k * 72)
        c.cut_circle(24 + math.cos(a) * 11, 24 + math.sin(a) * 11, 4.5)
    c.circle(24, 24, 3.5, "steel")


@icon("set_tutorial")
def _(c):
    c.poly([(4, 18), (24, 8), (44, 18), (24, 28)], "dark")
    c.poly([(12, 22), (36, 22), (36, 34), (24, 38), (12, 34)], "dark")
    c.path([(40, 20), (40, 34)], 2, "dust", hl=False)
    c.circle(40, 36, 3, "dust")


@icon("set_reset")
def _(c):
    c.ring(24, 26, 17, 12, "signal", 300, 230, hl=False)
    c.poly([(26, 2), (38, 10), (26, 18)], "signal")


# ================================================================= HUD (6)
@icon("hud_kills")
def _(c):
    skull(c, 24, 22, 1.45, "bone")


@icon("hud_timer")
def _(c):
    c.circle(24, 27, 17, "steel")
    c.circle(24, 27, 13, "bone")
    c.rect(20, 4, 28, 9, "steel")
    c.path([(24, 27), (24, 17)], 3, "ink", flat=1)
    c.path([(24, 27), (31, 31)], 3, "ink", flat=1)


@icon("hud_loot")
def _(c):
    bag(c, 24, 26, 1.3, "leather")
    nut(c, 24, 32, 6, "brass", 2.2)


@icon("hud_threat")
def _(c):
    c.poly([(24, 4), (45, 42), (3, 42)], "signal")
    c.rect(22, 16, 26, 31, "ink", flat=1)
    c.rect(22, 34, 26, 38, "ink", flat=1)


@icon("hud_pause")
def _(c):
    c.rect(12, 8, 20, 40, "bone")
    c.rect(28, 8, 36, 40, "bone")


@icon("hud_pack")
def _(c):
    ICONS["camp_backpack"](c)


# ===================================================== gear identity (gear UX)
# Every stash item reads as itself: armour / accessories get one icon per noun
# (3 per slot), weapons one per variant (finish + a medallion glyph), named
# Legendaries a gilded weapon with their own medallion, sets an emblem
# (shown on a set-coloured badge in the UI), plus the stash lock.


def medallion(c, cx, cy, r, ramp, glyph):
    """Round badge on the icon's lower-right: INK ring keeps it apart from
    the weapon under it; glyph(c, cx, cy, r) draws inside."""
    c.circle(cx, cy, r + 1.6, "ink", flat=1)
    c.circle(cx, cy, r, ramp, hl=False)
    glyph(c, cx, cy, r)


def g_spark(c, x, y, r):
    c.star(x, y, r * 0.85, r * 0.3, 4, "fire", rot=-90, hl=False)


def g_bell(c, x, y, r):
    s = r / 9.0
    c.poly([(x - 2 * s, y - 6 * s), (x + 2 * s, y - 6 * s), (x + 4 * s, y + 2 * s), (x + 6 * s, y + 4 * s), (x - 6 * s, y + 4 * s), (x - 4 * s, y + 2 * s)], "brass", hl=False)
    c.circle(x, y + 5.5 * s, 1.6 * s, "brass", flat=2)


def g_bars(c, x, y, r):
    s = r / 9.0
    for dx in (-3, 3):
        c.line((x + dx * s - 2 * s, y + 6 * s), (x + dx * s + 2 * s, y - 6 * s), 2.4 * s, "rust", hl=False)


def g_coil(c, x, y, r):
    s = r / 9.0
    c.path([(x - 6 * s, y + 4 * s), (x - 3 * s, y - 5 * s), (x, y + 4 * s), (x + 3 * s, y - 5 * s), (x + 6 * s, y + 4 * s)], 2.2 * s, "brass", hl=False)


def g_cross(c, x, y, r, ramp="bone"):
    s = r / 9.0
    c.rect(x - 1.6 * s, y - 6 * s, x + 1.6 * s, y + 6 * s, ramp, flat=2)
    c.rect(x - 5 * s, y - 2.8 * s, x + 5 * s, y + 0.4 * s, ramp, flat=2)


def g_blade(c, x, y, r):
    s = r / 9.0
    c.poly([(x - 6 * s, y + 6 * s), (x + 6 * s, y - 6 * s), (x + 3 * s, y + 1 * s)], "frost", hl=False)


def g_moon(c, x, y, r):
    c.circle(x, y, r * 0.7, "bone", flat=2)
    c.cut_circle(x + r * 0.35, y - r * 0.25, r * 0.55)


def g_wing(c, x, y, r):
    s = r / 16.0
    wing(c, x - 7 * s, y + 2 * s, s * 0.9, "bone")


def g_flame(c, x, y, r):
    flame(c, x, y + 1, r / 15.0 * 0.95, inner=False)


def g_drop(c, x, y, r):
    drop(c, x, y + 1, r / 15.0, "glow")


def g_bolt(c, x, y, r):
    bolt_glyph(c, x, y, r / 17.0, "dust")


def g_frost(c, x, y, r):
    snowflake(c, x, y, r * 0.8, "frost")


def g_burst(c, x, y, r):
    c.star(x, y, r * 0.85, r * 0.42, 6, "fire", rot=-90, hl=False)


def g_skull(c, x, y, r):
    skull(c, x, y - 1, r / 13.0, "bone")


def g_cloud(c, x, y, r):
    cloud(c, x, y, r / 13.0, "ash")


def g_saw(c, x, y, r):
    c.star(x, y, r * 0.85, r * 0.62, 10, "steel", rot=0, hl=False)
    c.circle(x, y, r * 0.25, "dark", flat=1)


def g_coins(c, x, y, r):
    s = r / 9.0
    c.circle(x - 2.5 * s, y + 1.5 * s, 4 * s, "brass", hl=False)
    c.circle(x + 2.5 * s, y - 1.5 * s, 4 * s, "dust", hl=False)


ELEMENT_GLYPH = {"fire": g_flame, "poison": g_drop, "shock": g_bolt, "frost": g_frost}

# hero -> base silhouette (KitDefs style 0) and variants
# (variant id, kind, glyph or element / legendary id)
WEAPON_BASE = {
    "ash_rook": "style_ash_rook_boom", "vesper_thorn": "style_vesper_thorn_bolt",
    "pebble": "style_pebble_maul", "bolt_juno": "style_bolt_juno_chain",
    "sister_cinder": "style_sister_cinder_suppressor", "quill_marrow": "style_quill_marrow_bayonet",
    "nyx_caldera": "style_nyx_caldera_dustblades", "helm_wisp": "style_helm_wisp_sidearm",
}
WEAPON_VARIANTS = {
    "ash_rook": [("patched", None), ("long_fuse", g_spark), ("cluster", "fire"), ("last_shift", "L")],
    "vesper_thorn": [("patched", None), ("bell_tuned", g_bell), ("hollowpoint", "poison"), ("bellwether", "L")],
    "pebble": [("patched", None), ("rebar", g_bars), ("quarry", "shock"), ("gravedigger", "L")],
    "bolt_juno": [("patched", None), ("coiled", g_coil), ("arc", "shock"), ("live_line", "L")],
    "sister_cinder": [("patched", None), ("chapel", g_cross), ("thurible", "fire"), ("censer", "L")],
    "quill_marrow": [("patched", None), ("surgical", lambda c, x, y, r: g_cross(c, x, y, r, "blood")), ("autopsy", "poison"), ("bonesaw", "L")],
    "nyx_caldera": [("patched", None), ("night", g_moon), ("smuggler", "frost"), ("twin_debts", "L")],
    "helm_wisp": [("patched", None), ("flight", g_wing), ("flare", "fire"), ("mayday", "L")],
}
LEGENDARY_GLYPH = {
    "last_shift": g_burst, "bellwether": g_bell, "gravedigger": g_skull, "live_line": g_bolt,
    "censer": g_cloud, "bonesaw": g_saw, "twin_debts": g_coins, "mayday": g_wing,
}
PATCHED = {"steel": "rust", "gun": "dark", "brass": "rust", "dust": "rust"}
GILDED = {"steel": "brass", "gun": "dark", "wood": "rust", "rust": "dust"}
EPIC_TINT = {"fire": {"steel": "rust"}, "poison": {"steel": "plague"}, "shock": {"steel": "teal"}, "frost": {"steel": "frost"}}


def _weapon_icon(base, kind, extra):
    def fn(c):
        if kind == "patched":
            c.remap = dict(PATCHED)
            ICONS[base](c)
            c.remap = {}
            c.line((18, 31), (26, 19), 5, "cloth", hl=False)
            return
        if kind == "legendary":
            c.remap = dict(GILDED)
            ICONS[base](c)
            c.remap = {}
            medallion(c, 36, 36, 10.5, "dark", LEGENDARY_GLYPH[extra])
            c.ring(36, 36, 10.5, 9.0, "dust", hl=False)
            return
        if kind == "epic":
            c.remap = dict(EPIC_TINT[extra])
            ICONS[base](c)
            c.remap = {}
            medallion(c, 37, 37, 9.5, "flesh", ELEMENT_GLYPH[extra])
            return
        ICONS[base](c)
        medallion(c, 37, 37, 9.5, "teal", extra)
    return fn


for _hero, _vs in WEAPON_VARIANTS.items():
    for _i, (_vid, _x) in enumerate(_vs):
        _kind = ["patched", "rare", "epic", "legendary"][_i]
        _ic = _weapon_icon(WEAPON_BASE[_hero], _kind, _x if _kind != "legendary" else _vid)
        ICONS["wpn_%s_%s" % (_hero, _vid)] = _ic
        if _kind == "legendary":
            ICONS["leg_%s" % _vid] = _ic


# ---------------------------------------------------- armour + accessories (27)
@icon("gear_head_0")
def _(c):  # Hood
    c.poly([(24, 4), (36, 9), (42, 22), (42, 44), (6, 44), (6, 22), (12, 9)], "cloth")
    c.ellipse(24, 28, 10, 12, "dark", flat=0)
    c.ellipse(20, 26, 1.6, 1.4, "fire", flat=2)
    c.ellipse(28, 26, 1.6, 1.4, "fire", flat=2)
    c.rect(6, 40, 42, 44, "leather", hl=False)


@icon("gear_head_1")
def _(c):  # Visor
    c.ellipse(24, 24, 18, 17, "steel")
    c.rect(6, 24, 42, 36, "steel")
    c.rect(8, 20, 40, 28, "teal", flat=1)
    c.rect(8, 20, 40, 22, "teal", flat=3)
    c.rect(22, 6, 26, 20, "steel", flat=2)
    c.rect(4, 34, 44, 38, "gun", hl=False)


@icon("gear_head_2")
def _(c):  # Cap (goggled field cap)
    ICONS["slot_head"](c)


@icon("gear_chest_0")
def _(c):  # Vest
    ICONS["slot_chest"](c)


@icon("gear_chest_1")
def _(c):  # Coat
    c.poly([(14, 4), (34, 4), (42, 12), (40, 46), (8, 46), (6, 12)], "leather")
    c.poly([(19, 4), (24, 22), (29, 4)], "dark", flat=1)
    c.poly([(19, 4), (15, 10), (21, 24), (24, 22)], "leather", flat=2)
    c.poly([(29, 4), (33, 10), (27, 24), (24, 22)], "leather", flat=2)
    c.line((24, 22), (24, 46), 1.4, "dark", hl=False, cap=False)
    for y in (27, 33, 39):
        c.circle(27, y, 1.6, "brass", flat=2)


@icon("gear_chest_2")
def _(c):  # Plate
    c.poly([(10, 8), (38, 8), (42, 18), (38, 40), (24, 45), (10, 40), (6, 18)], "steel")
    c.poly([(24, 10), (24, 43), (38, 39), (41, 18), (37, 10)], "steel", flat=0)
    c.rect(10, 22, 38, 25, "gun", hl=False)
    for (x, y) in ((12, 12), (36, 12), (12, 36), (36, 36)):
        c.px(x, y, "brass", 3)


@icon("gear_shoulders_0")
def _(c):  # Pauldrons
    ICONS["slot_shoulders"](c)


@icon("gear_shoulders_1")
def _(c):  # Mantle
    c.poly([(8, 20), (16, 10), (32, 10), (40, 20), (44, 38), (34, 34), (24, 40), (14, 34), (4, 38)], "cloth")
    c.ellipse(24, 14, 7, 4, "dark", flat=0)
    c.rect(18, 18, 30, 21, "leather", hl=False)
    c.circle(24, 19.5, 2.4, "brass", flat=2)


@icon("gear_shoulders_2")
def _(c):  # Spaulders (layered plates)
    for i, y in enumerate((10, 18, 26)):
        c.ellipse(24, y + 6, 18 - i * 2, 7, "steel")
        c.rect(6 + i * 2, y + 6, 42 - i * 2, y + 10, "steel", flat=0)
    c.rect(20, 38, 28, 44, "leather", hl=False)


@icon("gear_legs_0")
def _(c):  # Greaves
    for x in (8, 26):
        c.poly([(x, 6), (x + 14, 6), (x + 13, 40), (x + 1, 40)], "steel")
        c.ellipse(x + 7, 20, 6, 5, "steel", flat=2)
        c.rect(x, 40, x + 14, 44, "leather", hl=False)
        c.rect(x, 11, x + 14, 13, "leather", hl=False)


@icon("gear_legs_1")
def _(c):  # Trousers
    ICONS["slot_legs"](c)


@icon("gear_legs_2")
def _(c):  # Leggings with knee pads
    c.poly([(12, 4), (36, 4), (37, 44), (28, 44), (24, 16), (20, 44), (11, 44)], "leather")
    c.rect(12, 4, 36, 8, "dark", hl=False)
    c.ellipse(15.5, 26, 5, 5.5, "rust")
    c.ellipse(32.5, 26, 5, 5.5, "rust")


@icon("gear_hands_0")
def _(c):  # Gloves
    ICONS["slot_hands"](c)


@icon("gear_hands_1")
def _(c):  # Grips (fingerless, steel knuckles)
    c.poly([(12, 20), (36, 20), (40, 18), (44, 22), (37, 33), (35, 44), (13, 44)], "leather")
    for i, x in enumerate((12, 18, 24, 30)):
        c.rect(x, 12 + (i % 2) * 2, x + 5.5, 21, "skin")
    c.rect(11, 19, 37, 25, "steel")
    for x in (14, 20, 26, 32):
        c.px(x, 22, "bone", 2)


@icon("gear_hands_2")
def _(c):  # Wraps (bandaged fist)
    c.poly([(10, 14), (36, 12), (42, 18), (40, 34), (34, 44), (12, 44), (8, 30)], "bone")
    for y in (18, 25, 32, 39):
        c.line((9, y + 2), (41, y - 2), 1.6, "ash", hl=False, cap=False)
    c.rect(26, 40, 30, 47, "bone", hl=False)


@icon("gear_boots_0")
def _(c):  # Boots
    ICONS["slot_boots"](c)


@icon("gear_boots_1")
def _(c):  # Treads (steel-shod)
    boot(c, 0, 0, 1.0, "dark", "steel")
    c.rect(8, 42, 45, 46, "gun", hl=False)
    for x in (12, 20, 28, 36):
        c.rect(x, 44, x + 4, 47, "gun", hl=False)
    c.rect(11, 20, 27, 23, "steel", hl=False)


@icon("gear_boots_2")
def _(c):  # Striders (tall, strapped)
    c.poly([(14, 2), (28, 2), (28, 30), (40, 34), (43, 40), (43, 44), (11, 44), (12, 30)], "cloth")
    c.rect(10, 41, 45, 46, "dark")
    for y in (8, 16, 24):
        c.rect(13, y, 29, y + 3, "leather", hl=False)
        c.px(26, y + 1, "brass", 3)


@icon("gear_charm_0")
def _(c):  # Rabbit's Foot
    c.path([(24, 2), (24, 10)], 2.2, "leather", hl=False)
    c.rect(20, 9, 28, 14, "brass")
    c.ellipse(24, 26, 9, 13, "bone")
    c.ellipse(20, 39, 4.5, 4, "bone")
    c.ellipse(28, 39, 4.5, 4, "bone")
    c.ellipse(24, 40, 4, 4.5, "bone")


@icon("gear_charm_1")
def _(c):  # Lucky Bottle Cap
    ICONS["slot_charm"](c)


@icon("gear_charm_2")
def _(c):  # Dog Tags
    c.path([(10, 2), (18, 16)], 1.6, "steel", hl=False)
    c.path([(38, 2), (30, 14)], 1.6, "steel", hl=False)
    c.rect(10, 16, 26, 40, "steel")
    c.rect(22, 12, 38, 36, "steel")
    for y in (20, 25, 30):
        c.rect(25, y, 35, y + 1.6, "gun", hl=False)


@icon("gear_vial_0")
def _(c):  # Tonic Vial
    ICONS["slot_vial"](c)


@icon("gear_vial_1")
def _(c):  # Dust Draught
    bottle(c, "round", "dust")


@icon("gear_vial_2")
def _(c):  # Plague Ward
    bottle(c, "flask", "plague")
    c.rect(21, 30, 27, 33, "bone", flat=2)
    c.rect(22.5, 28, 25.5, 36, "bone", flat=2)


@icon("gear_patch_0")
def _(c):  # Squad Patch
    shield(c, 24, 24, 1.35, "cloth")
    chevron_up(c, 24, 16, 1.1, "dust")
    chevron_up(c, 24, 26, 1.1, "dust")


@icon("gear_patch_1")
def _(c):  # Hospital Cross
    ICONS["slot_patch"](c)


@icon("gear_patch_2")
def _(c):  # Scrap Union Badge
    cog(c, 24, 24, 20, 10, "brass", 0)
    c.circle(24, 24, 10, "rust", hl=False)
    c.rect(19, 18, 29, 30, "steel")
    c.rect(19, 18, 29, 21, "steel", flat=2)


# ------------------------------------------------------------ set emblems (12)
@icon("emb_plague_doctor")
def _(c):  # beaked mask
    c.ellipse(20, 20, 13, 14, "dark")
    c.poly([(26, 22), (46, 40), (24, 32)], "bone")
    c.circle(16, 17, 4.5, "glow", flat=2)
    c.circle(16, 17, 4.5, "ink", flat=1)
    c.circle(16, 17, 3, "glow", flat=2)


@icon("emb_demolition_crew")
def _(c):  # bomb
    c.circle(22, 28, 15, "dark")
    c.rect(28, 8, 36, 16, "steel")
    c.path([(34, 9), (40, 4), (44, 6)], 2.2, "rust", hl=False)
    c.star(44, 5, 5, 2, 4, "fire", hl=False)


@icon("emb_night_runner")
def _(c):  # crescent + star
    c.circle(22, 26, 18, "frost")
    c.cut_circle(31, 19, 15)
    c.star(36, 34, 7, 2.5, 4, "bone", hl=False)


@icon("emb_field_salvager")
def _(c):  # cog + wrench
    cog(c, 20, 26, 16, 8, "brass", 6)
    c.line((26, 22), (42, 6), 5, "steel")
    c.ring(41, 8, 6.5, 2.6, "steel", hl=False)
    c.cut_rect(40, 2, 47, 8)


@icon("emb_foremans_kit")
def _(c):  # hard hat
    c.ellipse(24, 26, 18, 16, "dust")
    c.cut_rect(0, 27, 48, 48)
    c.rect(2, 26, 46, 32, "dust")
    c.rect(21, 10, 27, 26, "dust", flat=0)


@icon("emb_bell_ringers_shroud")
def _(c):
    g_bell(c, 24, 22, 20)


@icon("emb_quarry_plate")
def _(c):  # pickaxe
    c.line((10, 42), (34, 14), 4.5, "wood")
    c.ring(28, 20, 20, 15, "steel", 200, 340, hl=False)


@icon("emb_linemans_rig")
def _(c):
    bolt_glyph(c, 24, 24, 1.4, "dust")


@icon("emb_cathedral_vestments")
def _(c):  # candle
    c.rect(17, 20, 31, 44, "bone")
    c.rect(15, 42, 33, 46, "brass", hl=False)
    flame(c, 24, 11, 0.7, inner=False)


@icon("emb_surgeons_coat")
def _(c):  # scalpel over a blood drop
    drop(c, 20, 28, 1.2, "blood")
    scalpel(c, (12, 42), (42, 6))


@icon("emb_smugglers_wraps")
def _(c):  # crossed daggers
    blade(c, (8, 42), (40, 6), 6, "frost")
    blade(c, (40, 42), (8, 6), 6, "frost")


@icon("emb_flight_crew_gear")
def _(c):  # wings
    wing(c, 26, 22, 1.2, "brass")
    wing(c, 22, 22, 1.2, "brass", flip=True)
    c.circle(24, 24, 4.5, "dust")


@icon("ui_lock")
def _(c):  # padlock
    c.ring(24, 18, 12, 7.5, "steel", 180, 360, hl=False)
    c.rect(12, 18, 16.5, 24, "steel", hl=False)
    c.rect(31.5, 18, 36, 24, "steel", hl=False)
    c.rect(8, 22, 40, 44, "brass")
    c.circle(24, 31, 3.5, "ink", flat=1)
    c.rect(22.5, 31, 25.5, 39, "ink", flat=1)


# ================================================================ render
RARITY_RAMPS = {
    "common": ((0x5d, 0x56, 0x54), (0x8f, 0x87, 0x7e), (0xe9, 0xdf, 0xc9)),
    "rare": ((0x1f, 0x5a, 0x58), (0x5c, 0xd2, 0xc0), (0xe9, 0xdf, 0xc9)),
    "epic": ((0x5a, 0x32, 0x54), (0xc0, 0x8a, 0xa0), (0xe9, 0xdf, 0xc9)),
    "legendary": ((0xa8, 0x52, 0x0f), (0xff, 0xc0, 0x40), (0xff, 0xf2, 0xc0)),
}


FRAME_BG = {"common": (0x1f, 0x1a, 0x1d), "rare": (0x1b, 0x22, 0x2c), "epic": (0x2e, 0x18, 0x30), "legendary": (0x3e, 0x2a, 0x10)}
## Rim thickness (texels) and the colour-blind gem in the top-left corner:
## common = square, rare = diamond, epic = triangle, legendary = crown.
FRAME_RIM = {"common": 1, "rare": 1, "epic": 2, "legendary": 3}
FRAME_GEM = {
    "common": ["XX", "XX"],
    "rare": [".X.", "XXX", ".X."],
    "epic": ["..X..", ".XXX.", "XXXXX"],
    "legendary": ["X.X.X", "XXXXX", "XXXXX"],
}


def frame(rarity, tx=28):
    """Recessed icon well with a painted rarity rim (UI texel units, saved x2).
    tx x tx texels; 9-slice margin = 8 texels (16 px). Rarity reads three ways:
    rim colour + thickness, the well's tint, and the corner gem's shape."""
    sh, base, hi = RARITY_RAMPS[rarity]
    rim = FRAME_RIM[rarity]
    a = np.zeros((tx, tx, 4), np.uint8)
    a[:, :, 3] = 255
    a[:, :, :3] = INK
    a[1:-1, 1:-1, :3] = FRAME_BG[rarity]
    # rarity rim: rim texels; outer = base (shadow tone for common), inner = shadow
    outer = sh if rarity == "common" else base
    for i in range(rim):
        col = outer if i == 0 else (hi if (rarity == "legendary" and i == rim - 1) else sh)
        a[i, i:tx - i, :3] = col
        a[tx - 1 - i, i:tx - i, :3] = col
        a[i:tx - i, i, :3] = col
        a[i:tx - i, tx - 1 - i, :3] = col
    # inset bevel just inside the rim: dark top-left, light bottom-right (recessed)
    r = rim
    a[r, r:-r, :3] = INK
    a[r:-r, r, :3] = INK
    a[-1 - r, r + 1:-r, :3] = (0x36, 0x42, 0x4f)
    a[r + 1:-r, -1 - r, :3] = (0x36, 0x42, 0x4f)
    # corner brackets for rare+
    if rarity != "common":
        for (x, y, dx, dy) in ((0, 0, 1, 1), (tx - 1, 0, -1, 1), (0, tx - 1, 1, -1), (tx - 1, tx - 1, -1, -1)):
            for i in range(6):
                a[y, x + dx * i, :3] = hi if rarity == "legendary" else base
                a[y + dy * i, x, :3] = hi if rarity == "legendary" else base
            a[y, x, :3] = hi
    # rarity stripe on the left edge (bible: painted rim stripe on the left)
    a[8:-8, 0:rim, :3] = base if rarity != "legendary" else hi
    # gem, INK-outlined, top-left inside the 8-texel corner
    g = FRAME_GEM[rarity]
    gx, gy = r + 2, r + 2
    if rarity == "legendary":
        gx, gy = 3, 4
    m = np.zeros((tx, tx), bool)
    for yy, row in enumerate(g):
        for xx, ch in enumerate(row):
            if ch == "X":
                m[gy + yy, gx + xx] = True
    pad = np.pad(m, 1)
    ring = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~m
    a[ring, :3] = INK
    a[m, :3] = hi if rarity != "common" else base
    for c0 in ((0, 0), (0, -1), (-1, 0), (-1, -1)):
        a[c0[0], c0[1], 3] = 0
    return Image.fromarray(a, "RGBA").resize((tx * 2, tx * 2), Image.NEAREST)


def reduce_colours(a, cap):
    """Merge the rarest colours into their nearest used neighbour until the
    icon is under the bible's colour cap (outline included)."""
    m = a[:, :, 3] > 0
    while True:
        px = a[m][:, :3]
        cols, counts = np.unique(px.reshape(-1, 3), axis=0, return_counts=True)
        if len(cols) <= cap:
            return a
        order = np.argsort(counts)
        for j in order:
            if tuple(cols[j]) != INK:
                break
        src = cols[j].astype(int)
        others = [cc for i, cc in enumerate(cols) if i != j and tuple(cc) != INK]
        lum = lambda c: 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]  # noqa: E731
        dst = min(others, key=lambda cc: float(np.sum((cc.astype(int) - src) ** 2)) + 2.0 * (lum(cc) - lum(src)) ** 2)
        sel = m & np.all(a[:, :, :3] == cols[j], axis=2)
        a[sel, :3] = dst


def fit(fn):
    """Scale + centre so the silhouette (outline included) spans 2..45 at 48 px:
    2 px safe margin, subject fills the box."""
    f, ox, oy = 1.0, 0.0, 0.0
    for _ in range(7):
        c = Icon(48, f, ox, oy)
        fn(c)
        a = c.render()
        ys, xs = np.nonzero(a[:, :, 3])
        w, h = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        span = max(w, h)
        target = 44.0
        if abs(span - target) <= 1 and xs.min() >= 2 and ys.min() >= 2 and xs.max() <= 45 and ys.max() <= 45:
            break
        g = (target - 2.0) / max(span - 2.0, 1.0)
        f *= g
        # recentre the bbox
        cx, cy = (xs.min() + xs.max() + 1) / 2.0, (ys.min() + ys.max() + 1) / 2.0
        ox = (ox + 24.0 - cx) * g
        oy = (oy + 24.0 - cy) * g
    return f, ox, oy


def main():
    sheet_path = sys.argv[1] if len(sys.argv) > 1 else None
    for S in (48, 24):
        os.makedirs(os.path.join(OUT, str(S)), exist_ok=True)
    bad = []
    tiles = []
    for name, fn in ICONS.items():
        f, ox, oy = fit(fn)
        for S in (48, 24):
            c = Icon(S, f, ox, oy)
            fn(c)
            a = reduce_colours(c.render(), 12)
            cols = colours(a)
            off = [col for col in cols if col not in PALETTE]
            if off:
                bad.append((name, S, "off-palette", off[:3]))
            if len(cols) > 12:
                bad.append((name, S, "colours", len(cols)))
            ys, xs = np.nonzero(a[:, :, 3])
            if S == 48 and (xs.min() < 1 or ys.min() < 1 or xs.max() > 46 or ys.max() > 46):
                bad.append((name, S, "margin", (xs.min(), ys.min(), xs.max(), ys.max())))
            to_img(a).save(os.path.join(OUT, str(S), name + ".png"))
            if S == 48:
                big = a
            else:
                tiles.append((name, big, a))
    for r in RARITY_RAMPS:
        frame(r).save(os.path.join(OUT, "frame_%s.png" % r))
    print("icons:", len(ICONS))
    for b in bad:
        print("WARN", *b)
    if sheet_path:
        cols = 10
        cw, ch = 48 * 2 + 24 * 2 + 12, 48 * 2 + 8
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cw, rows * ch), (0x2a, 0x24, 0x26, 255))
        for i, (n, b, s) in enumerate(tiles):
            x, y = (i % cols) * cw + 4, (i // cols) * ch + 4
            sheet.alpha_composite(to_img(b).resize((96, 96), Image.NEAREST), (x, y))
            sheet.alpha_composite(to_img(s).resize((48, 48), Image.NEAREST), (x + 100, y + 24))
        sheet.save(sheet_path)


if __name__ == "__main__":
    main()
