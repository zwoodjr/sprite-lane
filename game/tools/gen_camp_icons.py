"""Camp, hangar-tab, set-emblem and zone-pickup icons, Helm's plane layers and
the hangar trophies (art pass 14), painted with the weapon / gear engine in
its SOFT finish so they sit with the armour sheet and the other painted icons.

    IconSet (48 / 24 px): camp_<id>, tab_<id>, emb_<set>
    depth/icons/zone_<id>.png (96 px)
    depth/plane/plane_<1..8>.png (300x160 layers, same placement as before)
    hangar/trophy_<id>.png (same pixel sizes as before)

    python3 tools/gen_camp_icons.py [id ...]      (from game/)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_legendary_icons as L  # noqa: E402
import gen_gear_icons as G  # noqa: E402
import gen_loot_icons as LO  # noqa: E402
import gen_card_icons as C  # noqa: E402

hx = L.hx
SET = L.SET
A = os.path.normpath(os.path.join(HERE, "..", "assets", "sprites"))
bez, tone, ring, smoke, spark, ground = G.bez, G.tone, C.ring, C.smoke, C.spark, C.ground
Fr = L.Frame

L.MAT.update({
    "enamel_y": dict(c=hx("#b08a2e"), spec=0.5, grime=0.5, rust=0.2, chip="steel", metal=0.0),
    "tent": dict(c=hx("#6a6446"), spec=0.06, grime=0.6, rust=0.0, metal=0.0, weave=1),
    "brew": dict(c=hx("#6a7a34"), spec=1.0, grime=0.1, rust=0.0, metal=0.0),
    "planep": dict(c=hx("#8e978a"), spec=0.45, grime=0.25, rust=0.1, metal=0.0),
    "planep_d": dict(c=hx("#707a6e"), spec=0.45, grime=0.4, rust=0.15, metal=0.0),
    "canopy": dict(c=hx("#5e8a96"), spec=1.3, grime=0.25, rust=0.0, metal=0.0),
    "navg": dict(c=hx("#7ac88a"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "navr": dict(c=hx("#d0503e"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "eyeglow": dict(c=hx("#c85a34"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "eyegreen": dict(c=hx("#6a8a3a"), spec=1.0, grime=0.0, rust=0.0, glow=1),
    "horn": dict(c=hx("#8a7458"), spec=0.3, grime=0.5, rust=0.0, metal=0.0, pores=1),
})


# ------------------------------------------------------------------- camp
def camp_ammo_bench(ic, st):
    """Reloading bench: plank top on trestle legs, a press bolted on, an
    ammo can and a row of rounds standing ready."""
    ic.poly([(6, 52), (90, 52), (90, 60), (6, 60)], "plank", bevel=1.6, dome=0.6)
    ic.poly([(6, 48), (90, 48), (92, 52), (4, 52)], tone("plank", 1.15, "top"), bevel=0.8)
    for x in (12, 84):
        ic.bar((x, 60), (x - 4, 92), 5, "wood", prof="box")
        ic.bar((x, 60), (x + 4, 92), 5, tone("wood", 0.8, "lg"), prof="box")
    ic.bar((10, 80), (86, 80), 3, tone("wood", 0.8, "st"), prof="box")
    ic.poly([(14, 26), (40, 26), (40, 48), (14, 48)], "olivep", bevel=1.6, dome=0.6)
    ic.bar((20, 24), (34, 24), 2.4, "steel", prof="cyl")
    ic.bar((14, 34), (40, 34), 1.0, tone("olivep", 0.6, "rib"))
    ic.bar((62, 12), (62, 48), 5, "steel", prof="cyl")
    ic.poly([(56, 30), (70, 30), (70, 40), (56, 40)], "redp", bevel=1.0)
    ic.bar((62, 12), (80, 4), 2.4, "steel", prof="cyl")
    ic.ellipse(80, 4, 3, 3, "rubber", dome=0.8)
    for k in range(4):
        x = 76 + k * 4
        ic.bar((x, 47), (x, 34), 3.4, "brass", prof="cyl")
        ic.bar((x, 34), (x, 30), 3.0, "copper", w1=1.0, prof="cyl")
    ic.scratches(count=12)


def camp_generator(ic, st):
    """Diesel generator in a yellow tubular cradle: fuel tank on top, finned
    engine block, red pull-start, alternator drum, exhaust stub."""
    ic.poly([(18, 18), (78, 18), (80, 34), (16, 34)], "enamel_y", bevel=3.0, dome=0.9)
    ic.ellipse(64, 18, 5, 2.4, "gun", dome=0.8)
    ic.poly([(16, 40), (50, 40), (52, 80), (14, 80)], "gun", bevel=2.0, dome=0.7)
    for y in range(44, 78, 4):
        ic.bar((18, y), (48, y), 1.4, tone("gun", 0.5, "fin"))
    ic.bar((68, 42), (68, 78), 30, "steel", prof="cyl")
    ic.ellipse(68, 60, 6, 6, "redp", dome=0.9)
    ic.ellipse(68, 60, 2.4, 2.4, "rubber", dome=0.8)
    for (a, b) in (((8, 34), (8, 88)), ((88, 34), (88, 88)), ((8, 34), (88, 34)), ((8, 88), (88, 88)), ((8, 60), (14, 60))):
        ic.bar(a, b, 4.4, "enamel_y", prof="cyl")
    ic.bar((24, 18), (24, 6), 4.4, "rust", prof="cyl")
    smoke(ic, 26, 2, n=2, dx=3, s=0.6, k0=1.1)
    ic.scratches(count=16)



def camp_radio_tower(ic, st):
    """Lattice radio mast with guy wires, a dish and a red beacon, a field
    radio set at its foot."""
    for (a, b) in (((30, 92), (46, 8)), ((62, 92), (50, 8))):
        ic.bar(a, b, 4.4, "steel", prof="cyl")
    for k in range(8):
        y0 = 88 - k * 10
        y1 = y0 - 10
        xl0, xr0 = 30 + (16 * (92 - y0) / 84), 62 - (12 * (92 - y0) / 84)
        xl1, xr1 = 30 + (16 * (92 - y1) / 84), 62 - (12 * (92 - y1) / 84)
        ic.bar((xl0, y0), (xr1, y1), 1.8, tone("steel", 0.8, "lat"))
        ic.bar((xr0, y0), (xl1, y1), 1.8, tone("steel", 0.8, "lat"))
        ic.bar((xl0, y0), (xr0, y0), 1.2, tone("steel", 0.9, "rung"))
    for (x0, x1) in ((46, 6), (50, 90)):
        ic.bar((x0, 20), (x1, 92), 0.6, "dark")
    ic.bar((48, 8), (48, 0), 1.4, "steel")
    ic.ellipse(48, 2, 2.4, 2.4, "navr", dome=0.6)
    F = Fr(ic, (58, 36), -20, 1.0)
    F.poly([(0, -9), (4, -10), (6, 0), (4, 10), (0, 9)], "dial", bevel=1.0)
    ic.poly([(64, 74), (90, 74), (90, 92), (64, 92)], "olivep", bevel=1.6, dome=0.6)
    ic.ellipse(70, 82, 3, 3, "dial", dome=0.4)
    ic.ellipse(80, 82, 3, 3, "dial", dome=0.4)
    ic.bar((86, 74), (90, 56), 1.0, "rubber")
    ic.scratches(count=8)


def camp_scrap_press(ic, st):
    """Hydraulic scrap press: heavy steel frame, ram and piston, a crushed
    cube of scrap on the bed."""
    ic.poly([(10, 84), (86, 84), (88, 94), (8, 94)], "gun", bevel=1.6)
    for x in (16, 80):
        ic.bar((x, 10), (x, 86), 9, "enamel_y", prof="box")
    ic.poly([(10, 6), (86, 6), (86, 18), (10, 18)], "enamel_y", bevel=2.0, dome=0.6)
    ic.bar((48, 18), (48, 38), 9, "steel", prof="cyl")
    ic.poly([(26, 38), (70, 38), (70, 48), (26, 48)], "gun", bevel=1.6, dome=0.6)
    ic.poly([(30, 62), (66, 62), (68, 84), (28, 84)], "rust", bevel=2.0, dome=0.6)
    for (a, b) in (((30, 70), (66, 66)), ((28, 78), (68, 76)), ((44, 62), (40, 84))):
        ic.bar(a, b, 1.2, "dark")
    ic.patch(52, 74, 10, 8, 0.3, "steel")
    ic.bar((30, 62), (34, 56), 2, "copper", prof="cyl")
    for (x, y) in ((16, 22), (80, 22), (16, 76), (80, 76)):
        ic.rivet(x, y, 1.8)
    ic.patch(80, 50, 6, 16, 0.0, "rust")
    ic.scratches(count=16)


def camp_stash(ic, st):
    """Steel footlocker: ribbed lid, corner guards, side handle, hasp with a
    brass padlock."""
    ic.poly([(8, 46), (88, 46), (88, 88), (8, 88)], "bluegrey", bevel=2.4, dome=0.7)
    ic.poly([(6, 28), (90, 28), (90, 46), (6, 46)], tone("bluegrey", 1.1, "lid"), bevel=2.4, dome=0.8)
    for x in (24, 72):
        ic.bar((x, 28), (x, 88), 2.0, tone("bluegrey", 0.7, "rib"))
    for (x, y) in ((6, 28), (90, 28), (8, 88), (88, 88)):
        ic.poly([(x - 5, y - 5), (x + 5, y - 5), (x + 5, y + 5), (x - 5, y + 5)], "steel", bevel=1.0)
    ic.poly([(42, 40), (54, 40), (54, 54), (42, 54)], "steel", bevel=1.0)
    ring(ic, 48, 56, 4, 4, 1.8, "steel")
    ic.poly([(41, 58), (55, 58), (56, 70), (40, 70)], "brass", bevel=1.4, dome=0.8)
    ic.ellipse(48, 64, 1.4, 2.2, "dark", dome=-0.4)
    ic.bar((90, 60), (94, 60), 3, "rubber")
    ic.patch(70, 74, 12, 8, 0.2, "rust")
    ic.scratches(count=18)


# ------------------------------------------------------------------- tabs
def tab_brew(ic, st):
    """Iron pot on a tripod over a small fire, green brew, a ladle in it."""
    for (a, b) in (((20, 92), (40, 20)), ((76, 92), (56, 20)), ((48, 94), (48, 20))):
        ic.bar(a, b, 2.6, "gun", prof="cyl")
    ic.bar((48, 20), (48, 34), 1.2, "steel")
    C.flame(ic, 40, 86, 0.6)
    C.flame(ic, 56, 88, 0.55)
    ic.ellipse(48, 58, 28, 22, "gun", dome=0.95)
    ic.ellipse(48, 42, 26, 7, tone("gun", 1.2, "rim"), dome=0.5)
    ic.ellipse(48, 42, 23, 5.4, "brew", dome=0.3)
    for (x, y) in ((40, 41), (54, 43), (48, 40)):
        ic.ellipse(x, y, 2.4, 1.4, tone("brew", 1.4, "bub"), dome=0.6)
    ic.bar((60, 42), (78, 14), 3, "steel", prof="cyl")
    smoke(ic, 34, 32, n=3, dx=-2, s=0.7, k0=1.3)
    ic.scratches(count=10)


def tab_camp(ic, st):
    """Canvas A-frame tent: front flap tied back, guy lines and pegs."""
    ground(ic, 48, 88, 44, 6)
    ic.poly([(4, 86), (40, 14), (76, 86)], "tent", bevel=3.0, dome=0.7)
    ic.poly([(40, 14), (92, 22), (92, 86), (76, 86)], tone("tent", 0.72, "side"), bevel=2.0, dome=0.6)
    ic.poly([(26, 86), (40, 40), (54, 86)], tone("dark", 1.6, "door"), bevel=1.0)
    ic.poly([(40, 40), (54, 86), (60, 86), (46, 44)], tone("tent", 1.15, "flap"), bevel=1.0)
    G.stitch(ic, [(40, 16), (6, 84)], 1.8)
    ic.bar((40, 14), (40, 8), 1.6, "wood")
    for (a, b) in (((40, 12), (6, 26)), ((92, 22), (94, 40))):
        ic.bar(a, b, 0.6, "twine")
    ic.patch(64, 56, 10, 8, 0.1, "canvas")
    ic.scratches(count=8)


def tab_crew(ic, st):
    """Three dog tags on a bead chain."""
    pts = bez((14, 6), (48, 44), (82, 6), 18)
    for p in pts:
        ic.ellipse(p[0], p[1], 1.8, 1.8, "steel", dome=0.9)
    for (x, y, a) in ((30, 34, -16), (48, 40, 2), (64, 34, 18)):
        F = Fr(ic, (x, y), a + 90, 1.4)
        F.poly([(-4, -10), (26, -10), (30, -6), (30, 6), (26, 10), (-4, 10), (-6, 6), (-6, -6)], "steel", bevel=1.4, dome=0.6)
        for v in (-4, 0, 4):
            F.bar(6, v, 22, v, 1.0, tone("steel", 0.5, "emb"))
        F.ell(-2, 0, 1.6, 1.6, "dark")
    ic.scratches(count=10)



def tab_daily(ic, st):
    """Tear-off desk calendar block, today's page circled in red grease
    pencil, binder rings on top."""
    ic.poly([(16, 20), (82, 18), (84, 88), (14, 90)], tone("paper", 0.8, "stack"), bevel=1.2, dome=0.4)
    ic.poly([(14, 16), (80, 14), (82, 84), (12, 86)], tone("paper", 1.2, "pg"), bevel=1.2, dome=0.3)
    ic.poly([(14, 16), (80, 14), (80, 32), (14, 34)], "redp", bevel=1.0, dome=0.5)
    for x in (30, 64):
        ring(ic, x, 14, 4, 6, 1.6, "steel")
    for r in range(3):
        for c in range(5):
            x, y = 22 + c * 12, 44 + r * 13
            ic.bar((x, y), (x + 5, y), 2.4, "ink")
    ring(ic, 48, 57, 9, 7, 1.6, "redp")
    ic.scratches(count=6)


def tab_goals(ic, st):
    """Torn red flag on a steel pole, planted in a heap of rubble."""
    C.rubble(ic, [(22, 88, 6), (36, 90, 7), (50, 88, 6), (30, 82, 5)], "concrete")
    ic.bar((34, 86), (30, 6), 4, "steel", prof="cyl")
    pts = [(31, 8), (58, 14), (84, 8), (78, 28), (92, 50), (62, 46), (32, 54)]
    ic.poly(pts, "redp", bevel=2.0, dome=0.6)
    for (a, b) in (((36, 22), (72, 24)), ((38, 38), (70, 40))):
        ic.bar(a, b, 1.2, tone("redp", 0.65, "fold"))
    ic.ellipse(30, 6, 3, 3, "brass", dome=0.9)



def tab_kennel(ic, st):
    """Plank doghouse with a shingled roof, a dented steel bowl in front."""
    ic.poly([(14, 46), (82, 46), (82, 86), (14, 86)], "plank", bevel=2.0, dome=0.5)
    for y in (56, 66, 76):
        ic.bar((14, y), (82, y), 1.0, tone("plank", 0.55, "gap"))
    ic.poly([(6, 48), (48, 14), (90, 48), (84, 52), (48, 24), (12, 52)], "wood", bevel=2.0, dome=0.7)
    ic.poly([(36, 86)] + bez((36, 62), (36, 50), (48, 50), 6) + bez((48, 50), (60, 50), (60, 62), 6) + [(60, 86)], tone("dark", 1.4, "door"), bevel=1.0)
    ic.ellipse(74, 88, 12, 5, "steel", dome=0.7)
    ic.ellipse(74, 86, 9, 3, tone("steel", 0.6, "in"), dome=-0.3)
    ic.poly([(36, 36), (60, 36), (60, 42), (36, 42)], tone("plank", 1.25, "sign"), bevel=0.6)
    ic.scratches(count=10)


def tab_notes(ic, st):
    """Clipboard with a stained page and a pencil tucked under the clip."""
    ic.poly([(16, 10), (80, 10), (82, 92), (14, 92)], "plank", bevel=2.0, dome=0.5)
    ic.poly([(22, 20), (74, 18), (76, 86), (20, 88)], tone("paper", 1.2, "pg"), bevel=1.0, dome=0.3)
    for k in range(7):
        y = 32 + k * 7
        ic.bar((28, y), (68 - (k % 3) * 6, y - 0.4), 1.0, "ink")
    ic.poly([(34, 6), (62, 6), (64, 18), (32, 18)], "steel", bevel=1.4, dome=0.8)
    ic.ellipse(48, 8, 4, 2.4, "dark", dome=-0.4)
    F = Fr(ic, (60, 90), -64, 1.0)
    F.bar(0, 0, 50, 0, 5, "signal", prof="cyl")
    F.bar(50, 0, 56, 0, 5, "plank", w1=1.6, prof="cyl")
    F.bar(-5, 0, 0, 0, 5.4, "brass", prof="cyl")
    ic.ellipse(60, 70, 8, 5, tone("paper", 0.7, "stain"), dome=0.2)


def tab_stories(ic, st):
    """Worn cloth-bound book with a ribbon bookmark, page block showing."""
    ic.poly([(20, 14), (80, 10), (84, 86), (24, 92)], tone("paper", 0.95, "pb"), bevel=1.0, dome=0.3)
    ic.poly([(14, 12), (76, 8), (78, 84), (16, 90)], "redp", bevel=3.0, dome=0.7)
    ic.bar((18, 12), (20, 90), 6, tone("redp", 0.7, "spine"))
    for y in (24, 76):
        ic.bar((22, y + 1), (76, y - 2), 1.6, "gold")
    ic.poly([(36, 40), (62, 38), (62, 54), (36, 56)], tone("paper", 1.1, "lbl"), bevel=0.8)
    ic.bar((40, 46), (58, 45), 1.0, "ink")
    ic.bar((56, 84), (60, 96), 3, "plastic_r")
    ic.scratches(count=10)


def tab_workshop(ic, st):
    """Cast-iron bench vise with a bar handle, jaws clamping a steel bar."""
    ic.poly([(4, 70), (92, 70), (92, 78), (4, 78)], "plank", bevel=1.4, dome=0.5)
    ic.poly([(26, 48), (70, 48), (72, 70), (24, 70)], "bluegrey", bevel=2.4, dome=0.8)
    ic.poly([(12, 30), (44, 30), (44, 50), (12, 50)], "bluegrey", bevel=2.0, dome=0.8)
    ic.poly([(52, 30), (84, 30), (84, 50), (52, 50)], "bluegrey", bevel=2.0, dome=0.8)
    for x in (44, 52):
        ic.poly([(x - 3, 24), (x + 3, 24), (x + 3, 34), (x - 3, 34)], "steel", bevel=0.6)
    ic.bar((20, 28), (78, 28), 6, "steel", prof="cyl")
    ic.bar((84, 40), (94, 40), 5, "steel", prof="cyl")
    ic.bar((94, 26), (94, 56), 3, "steel", prof="cyl")
    for y in (26, 56):
        ic.ellipse(94, y, 3, 3, "steel", dome=0.9)
    ic.patch(30, 60, 10, 6, 0.2, "rust")
    ic.scratches(count=14)


# ----------------------------------------------------------------- emblems
def emb_bell_ringers_shroud(ic, st):
    """Brass hand bell with a turned wooden handle."""
    ic.bar((48, 4), (48, 30), 8, "wood", prof="cyl")
    ic.ellipse(48, 4, 6, 4, "wood", dome=0.9)
    C.bell(ic, 48, 54, 1.45, "brass")


def emb_cathedral_vestments(ic, st):
    """One tall church candle on a spiked iron pricket."""
    ic.poly([(26, 88), (70, 88), (60, 80), (36, 80)], "gun", bevel=1.4, dome=0.6)
    ic.bar((48, 72), (48, 82), 4, "gun", prof="cyl")
    ic.ellipse(48, 72, 18, 4, "gun", dome=0.6)
    ic.bar((48, 26), (48, 70), 18, "candle", prof="cyl")
    ic.ellipse(48, 26, 9, 2.6, tone("candle", 1.15, "ct"), dome=0.4)
    ic.bar((40, 28), (40, 44), 2.6, tone("candle", 1.2, "drip"), prof="cyl")
    ic.bar((48, 26), (48, 20), 1.2, "dark")
    C.flame(ic, 48, 16, 0.55)


def emb_demolition_crew(ic, st):
    """Two dynamite sticks taped together, fuse lit."""
    F = Fr(ic, (16, 82), -50, 1.0)
    for v in (-7, 7):
        F.bar(0, v, 64, v, 13, "dynamite", prof="cyl")
    for u in (16, 48):
        F.bar(u, -14, u, 14, 6, "tape", prof="cyl")
    F.bar(64, 0, 74, -6, 2, "twine", prof="cyl")
    spark(ic, *F.P(75, -7), r=8)


def emb_field_salvager(ic, st):
    """Rusty cog with an open-end wrench laid across it."""
    pts = []
    for k in range(10):
        a0 = k / 10 * math.tau
        for (da, r) in ((-0.12, 30), (-0.08, 36), (0.08, 36), (0.12, 30)):
            pts.append((48 + math.cos(a0 + da * 2) * r, 48 + math.sin(a0 + da * 2) * r))
    ic.poly(pts, "gun", bevel=2.0, dome=0.7)
    ic.ellipse(48, 48, 12, 12, "dark", dome=-0.4)
    ic.patch(36, 64, 14, 8, 0.4, "rust")
    F = Fr(ic, (10, 86), -45, 1.0)
    F.bar(0, 0, 80, 0, 9, "steel", prof="box")
    F.poly([(78, -12), (96, -12), (100, -4), (90, -4), (90, 4), (100, 4), (96, 12), (78, 12)], "steel", bevel=1.4, dome=0.6)
    ic.scratches(count=12)


def emb_flight_crew_gear(ic, st):
    C.up_wingman(ic, st)


def emb_foremans_kit(ic, st):
    G.s_hardhat(ic, dict(G.GENERIC, plate="enamel_y"))


def emb_linemans_rig(ic, st):
    """Enamel high-voltage sign: yellow triangle, black bolt, rusted edge."""
    tri = [(48, 8), (92, 84), (4, 84)]
    ic.poly(tri, "gun", bevel=2.0, dome=0.4)
    ic.poly([(48, 16), (84, 80), (12, 80)], "enamel_y", bevel=2.0, dome=0.5)
    ic.poly([(52, 30), (40, 56), (50, 56), (42, 74), (60, 46), (50, 46), (56, 30)], "ink", bevel=0.6)
    ic.patch(70, 74, 12, 6, 0.2, "rust")
    ic.rivet(48, 22, 1.8)
    ic.scratches(count=14)


def emb_night_runner(ic, st):
    """Pewter crescent-moon pendant with a small star, on a leather cord."""
    ic.bar((22, 2), (40, 12), 1.8, "leatherb", prof="cyl")
    ic.bar((74, 2), (40, 12), 1.8, "leatherb", prof="cyl")
    ring(ic, 40, 14, 3.6, 3.6, 1.6, "steel")
    outer = [(46 + math.cos(a) * 36, 54 + math.sin(a) * 36) for a in np.linspace(-0.9 * math.pi / 2 - 0.5, 0.5 + math.pi, 30)]
    inner = [(62 + math.cos(a) * 28, 46 + math.sin(a) * 28) for a in np.linspace(0.5 + math.pi + 0.3, -0.9 * math.pi / 2 - 0.2, 30)]
    ic.poly(outer + inner, "steel", bevel=3.0, dome=0.8)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = 8 if k % 2 == 0 else 3.4
        pts.append((70 + math.cos(a) * rr, 30 + math.sin(a) * rr))
    ic.poly(pts, "steel", bevel=1.2, dome=0.7)
    ic.scratches(count=10)



def emb_plague_doctor(ic, st):
    """Corked glass phial of dark tincture tied with a sprig of dried herb."""
    body = [(30, 40), (66, 40), (72, 50), (72, 88), (24, 88), (24, 50)]
    LO.bottle(ic, body, "liquid_g", (48, 20, 42, 12), 14, 56, 21)
    ic.bar((40, 34), (58, 35), 2.0, "twine", prof="cyl")
    for k in range(5):
        ic.bar((58, 36), (78 + k * 2, 16 + k * 5), 1.2, "sage", w1=0.6)
        ic.ellipse(74 + k * 2, 20 + k * 5, 3, 1.6, "sage", dome=0.6)
    LO.label(ic, 30, 62, 66, 76, seed=12)


def emb_quarry_plate(ic, st):
    """Pickaxe: chipped iron head on a hickory haft."""
    ic.bar((24, 90), (64, 16), 7, "wood", prof="cyl")
    ic.bar((24, 90), (32, 76), 7.6, "tape", prof="cyl")
    pts = bez((14, 30), (40, 4), (66, 18), 8) + bez((66, 18), (88, 26), (92, 46), 8) + bez((92, 46), (80, 30), (64, 28), 6) + bez((64, 28), (40, 22), (14, 30), 6)
    ic.poly(pts, "gun", bevel=2.0, dome=0.7)
    ic.poly([(58, 12), (70, 14), (68, 28), (56, 26)], "steel", bevel=1.0)
    ic.patch(80, 34, 8, 6, 0.6, "rust")
    ic.scratches(count=12)


def emb_smugglers_wraps(ic, st):
    """Two daggers crossed, wrapped grips."""
    C.knife(ic, 12, 86, -45, 1.05, grip="tape")
    C.knife(ic, 84, 86, -135, 1.05, grip="tape")


def emb_surgeons_coat(ic, st):
    """Bone saw and scalpel crossed, a smear of blood on the saw."""
    B = Fr(ic, (10, 30), 40, 1.0)
    B.bar(0, 0, 18, 0, 10, "wood", prof="cyl")
    B.poly([(18, -10), (76, -8), (76, 8), (18, 10)], "blade", bevel=1.0)
    if L._detail():
        for u in range(20, 76, 3):
            B.bar(u, 8, u + 1.5, 11, 1.0, "blade")
    ic.ellipse(*B.P(54, 0), 7, 4, "blood", dome=0.3)
    S = Fr(ic, (14, 86), -45, 1.15)
    S.bar(0, 0, 44, 0, 6, "steel")
    S.poly([(44, -3), (58, -3.4), (70, 1.0), (60, 3.4), (44, 3)], "blade", bevel=1.0)


# ------------------------------------------------------------ zone pickups
def zone_key(ic, st):
    """Heavy brass warded key with a red cardboard tag on string."""
    ring(ic, 30, 30, 16, 16, 7, "brass")
    F = Fr(ic, (40, 40), 45, 1.0)
    F.bar(0, 0, 56, 0, 7, "brass", prof="cyl")
    F.poly([(40, 3), (44, 3), (44, 14), (48, 14), (48, 3), (52, 3), (52, 18), (40, 18)], "brass", bevel=1.0, dome=0.6)
    ic.bar((18, 22), (8, 8), 1.0, "twine")
    T = Fr(ic, (8, 8), 70, 1.0)
    T.poly([(0, -9), (22, -9), (26, -4), (26, 4), (22, 9), (0, 9)], "redp", bevel=1.0, dome=0.5)
    T.ell(4, 0, 1.6, 1.6, "dark")
    ic.scratches(count=10)


def zone_filter(ic, st):
    """Gas-mask filter canister: olive drum, ribbed, threaded brass neck,
    stencilled band, intake holes on the end."""
    ic.bar((48, 30), (48, 86), 44, "olivep", prof="cyl")
    ic.ellipse(48, 86, 22, 5, tone("olivep", 0.6, "b"), dome=0.4)
    for y in range(40, 84, 6):
        ic.bar((26, y), (70, y), 1.4, tone("olivep", 0.62, "rib"))
    ic.bar((48, 52), (48, 64), 44.6, "stencil", prof="cyl")
    for (x0, x1, y) in ((32, 60, 56), (34, 52, 60)):
        ic.bar((x0, y), (x1, y), 1.0, "ink")
    ic.ellipse(48, 30, 22, 6, tone("olivep", 1.2, "top"), dome=0.6)
    ic.bar((48, 16), (48, 30), 18, "brass", prof="cyl")
    for y in range(18, 30, 2):
        ic.bar((40, y), (56, y + 1), 0.6, tone("brass", 0.6, "thr"))
    ic.patch(64, 74, 8, 8, 0.2, "rust")
    ic.scratches(count=12)


def zone_power_cell(ic, st):
    LO.i_power_cell(ic, st)


def zone_flare(ic, st):
    LO.i_flare(ic, st)


# ------------------------------------------------------------- trophies
def trophy_wall(ic, st):
    """Weathered plank plaque, iron-strapped, a bullet hole, nail heads."""
    ic.poly([(2, 30), (94, 30), (94, 66), (2, 66)], "plank", bevel=2.0, dome=0.5)
    for y in (42, 54):
        ic.bar((2, y), (94, y), 1.0, tone("plank", 0.5, "gap"))
    for x in (12, 84):
        ic.bar((x, 28), (x, 68), 5, "gun", prof="box")
        for y in (34, 48, 62):
            ic.rivet(x, y, 1.4)
    ic.ellipse(52, 46, 2.6, 2.6, "dark", dome=-0.5)
    ic.scratches(count=14)


def trophy_dread_naught(ic, st):
    """Dread Naught's visor: a cracked riveted steel face-plate with a slit
    and two embers still glowing behind it."""
    pts = [(14, 22), (34, 10), (62, 10), (82, 22), (86, 54), (70, 78), (26, 78), (10, 54)]
    ic.poly(pts, "plate", bevel=4.0, dome=0.9)
    ic.poly([(22, 40), (74, 40), (72, 52), (24, 52)], "dark", bevel=1.0)
    for x in (36, 60):
        ic.ellipse(x, 46, 6, 3.2, "eyeglow", dome=0.4)
    ic.bar((50, 10), (44, 40), 1.6, "dark")
    ic.bar((46, 52), (52, 78), 1.6, "dark")
    for (x, y) in ((22, 26), (74, 26), (20, 60), (76, 60), (48, 70)):
        ic.rivet(x, y, 1.8)
    ic.patch(70, 66, 10, 8, 0.3, "rust")
    ic.scratches(count=20)


def trophy_mutant_overlord(ic, st):
    """Mutant Overlord's horned skull: heavy brow, curling horns, cracked
    bone, faint green in the sockets."""
    for s in (-1, 1):
        pts = bez((48 + s * 14, 34), (48 + s * 40, 30), (48 + s * 40, 4), 10)
        for i, (a, b) in enumerate(zip(pts[:-1], pts[1:])):
            ic.bar(a, b, 9 - i * 0.7, "horn", prof="cyl")
    ic.ellipse(48, 44, 24, 22, "bone2", dome=0.95)
    ic.poly([(32, 56), (64, 56), (60, 82), (36, 82)], "bone2", bevel=3.0, dome=0.8)
    for dx in (-10, 10):
        ic.ellipse(48 + dx, 50, 7, 6, "dark", dome=-0.5)
        ic.ellipse(48 + dx, 51, 3, 2.4, "eyegreen", dome=0.4)
    ic.poly([(45, 64), (51, 64), (48, 58)], "dark", bevel=0.4)
    for k in range(5):
        x = 39 + k * 4.5
        ic.bar((x, 74), (x, 82), 1.0, tone("bone2", 0.5, "t"))
    ic.bar((54, 26), (60, 42), 1.4, "dark")
    ic.scratches(count=10)


# ----------------------------------------------------------- Helm's plane
# old layer art was laid out on a 60x32 grid (5 px per unit, 300x160); here
# the same grid maps to the 96-unit canvas at 1.6x with a 22-unit top margin
PK, PY = 1.6, 22.0


def _p(x, y):
    return (x * PK, PY + y * PK)


def _pp(pts):
    return [_p(x, y) for (x, y) in pts]


def plane_1(ic, st):  # fuselage, patched
    body = _pp([(10.0, 14.0), (44.0, 12.0), (50.0, 13.0), (52.0, 17.0), (50.0, 21.0), (44.0, 22.0), (10.0, 19.0), (4.0, 15.4)])
    ic.poly(body, "planep", bevel=5.0, dome=0.9)
    for (x0, y0, x1, y1, m) in ((18.0, 14.0, 23.0, 18.0, "rust"), (30.0, 15.0, 35.0, 19.6, "steel")):
        ic.poly(_pp([(x0, y0), (x1, y0), (x1, y1), (x0, y1)]), m, bevel=1.0, dome=0.5)
        for (x, y) in ((x0 + 0.6, y0 + 0.6), (x1 - 0.6, y0 + 0.6), (x0 + 0.6, y1 - 0.6), (x1 - 0.6, y1 - 0.6)):
            ic.rivet(*_p(x, y), 0.9)
    for x in range(12, 44, 6):
        ic.bar(_p(x, 13.4), _p(x, 20.4), 0.7, tone("planep", 0.6, "seam"))
    ic.bar(_p(8, 18.4), _p(46, 20.6), 1.0, tone("planep", 0.55, "belly"))
    ic.scratches(count=8)


def plane_2(ic, st):  # high wing + struts
    for (a, b) in (((22.0, 12.0), (24.5, 18.0)), ((39.0, 11.6), (35.5, 18.0))):
        ic.bar(_p(*a), _p(*b), 1.8, "gun", prof="cyl")
    ic.poly(_pp([(20.0, 9.6), (46.0, 8.6), (47.0, 11.2), (21.0, 12.2)]), tone("planep", 1.2, "wing"), bevel=1.2, dome=0.5)
    ic.bar(_p(22, 10.6), _p(45, 9.6), 0.6, tone("planep", 0.6, "wl"))
    ic.scratches(count=10)


def plane_3(ic, st):  # tail fin + stabiliser
    ic.poly(_pp([(6.0, 15.0), (3.0, 5.0), (6.6, 5.0), (12.0, 14.4)]), "planep", bevel=1.6, dome=0.6)
    ic.bar(_p(4.6, 6), _p(9, 13), 0.6, tone("planep", 0.6, "rud"))
    ic.poly(_pp([(3.0, 15.6), (13.0, 15.0), (13.0, 16.6), (2.0, 17.0)]), "planep_d", bevel=1.0, dome=0.5)
    ic.scratches(count=8)


def plane_4(ic, st):  # engine cowl
    ic.poly(_pp([(46.0, 11.6), (53.0, 12.4), (54.6, 17.0), (53.0, 21.6), (46.0, 22.4)]), "gun", bevel=3.0, dome=0.9)
    for y in (13.4, 15.4, 17.4, 19.4):
        ic.bar(_p(47.0, y), _p(52.6, y + 0.2), 0.9, tone("gun", 0.5, "louv"))
    ic.bar(_p(48, 21.6), _p(46, 24), 1.6, "rust", prof="cyl")
    ic.scratches(count=10)


def plane_5(ic, st):  # propeller
    for (a, b) in (((55.6, 16.4), (56.8, 3.2)), ((55.6, 17.6), (56.8, 30.6))):
        ic.bar(_p(*a), _p(*b), 4.2, "wood", w1=2.6, prof="cyl")
    ic.ellipse(*_p(55.6, 17.0), 2.6, 2.6, "steel", dome=0.95)


def plane_6(ic, st):  # landing gear
    for x in (40.0, 28.0):
        ic.bar(_p(x - 1.0, 21.0), _p(x, 26.6), 1.4, "gun", prof="cyl")
        ic.ellipse(*_p(x, 27.0), 3.9, 3.9, "rubber", dome=0.9)
        ic.ellipse(*_p(x, 27.0), 1.6, 1.6, "steel", dome=0.9)
    ic.bar(_p(9.0, 18.4), _p(8.0, 25.4), 1.0, "gun", prof="cyl")
    ic.ellipse(*_p(8.0, 26.0), 2.2, 2.2, "rubber", dome=0.9)


def plane_7(ic, st):  # canopy
    ic.poly(_pp([(34.0, 12.6), (36.0, 9.4), (43.0, 9.2), (45.0, 12.2)]), "canopy", bevel=1.4, dome=0.7)
    ic.bar(_p(39.4, 9.4), _p(39.4, 12.4), 1.0, "gun")
    ic.bar(_p(36.8, 10.2), _p(38.4, 10.0), 0.7, "frost")


def plane_8(ic, st):  # paint: stripe, roundel, nav lights, pennant
    ic.poly(_pp([(11.0, 16.4), (46.0, 15.4), (46.0, 17.0), (11.0, 17.8)]), "redp", bevel=0.6, dome=0.4)
    ic.ellipse(*_p(26.0, 17.0), 3.9, 3.9, "stencil", dome=0.6)
    ic.ellipse(*_p(26.0, 17.0), 2.1, 2.1, "redp", dome=0.6)
    ic.ellipse(*_p(46.4, 9.4), 1.2, 1.2, "navg", dome=0.6)
    ic.ellipse(*_p(3.6, 5.0), 1.2, 1.2, "navr", dome=0.6)
    ic.bar(_p(30.0, 9.6), _p(30.0, 3.0), 0.8, "steel", prof="cyl")
    ic.poly(_pp([(30.2, 3.0), (35.0, 4.0), (30.2, 5.4)]), "enamel_y", bevel=0.6)


# ---------------------------------------------------------------- outputs
ICONS = [f for f in list(globals()) if f.startswith(("camp_", "tab_", "emb_")) and callable(globals()[f])]
ZONES = ["zone_key", "zone_filter", "zone_power_cell", "zone_flare"]
TROPHIES = {"trophy_wall": (182, 63), "trophy_dread_naught": (74, 55), "trophy_mutant_overlord": (90, 90)}
PLANES = ["plane_%d" % i for i in range(1, 9)]
ALL = ICONS + ZONES + list(TROPHIES) + PLANES
SKIP = ("camp_backpack",)  # painted in gen_loot_icons.py
for k in ALL:
    G.SHAPES["camp_" + k] = globals()[k]


def _seed(k):
    return 1600 + ALL.index(k)


def render(k, mode):
    L.SOFT = True
    return G.build("camp_" + k, G.GENERIC, _seed(k), mode)


def render_full(k):
    """Unfitted 384 px render (layout units map 1:1): plane layers and
    trophies, which need their own framing."""
    L.SOFT = True
    L.MODE, L.KIND = "hd", "base"
    L.FIT_SET, L.OFF = 1.0, (0.0, 0.0)
    ic, halo, glows = G.paint("camp_" + k, G.GENERIC, _seed(k))
    return ic._render(L.W, None, glows)


def run(k):
    if k in ICONS:
        for mode in ("s48", "s24"):
            Image.fromarray(render(k, mode), "RGBA").save(os.path.join(SET, mode[1:], k + ".png"))
    elif k in ZONES:
        Image.fromarray(render(k, "hd"), "RGBA").save(os.path.join(A, "depth", "icons", k + ".png"))
    elif k in TROPHIES:
        w, h = TROPHIES[k]
        im = Image.fromarray(render_full(k), "RGBA")
        im = im.crop(im.getbbox())
        sc = min((w - 2) / im.width, (h - 2) / im.height)
        im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        out.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
        out.save(os.path.join(A, "hangar", k + ".png"))
    else:
        im = Image.fromarray(render_full(k), "RGBA")
        y0 = round(PY * L.SS)
        im = im.crop((0, y0, L.W, y0 + round(32 * PK * L.SS))).resize((300, 160), Image.LANCZOS)
        im.save(os.path.join(A, "depth", "plane", k + ".png"))
    return k


if __name__ == "__main__":
    import multiprocessing as mp
    ks = [k for k in ALL if k not in SKIP and (not sys.argv[1:] or k in sys.argv[1:])]
    with mp.Pool(min(4, os.cpu_count() or 1)) as pool:
        for k in pool.imap_unordered(run, ks):
            print("ok", k)
