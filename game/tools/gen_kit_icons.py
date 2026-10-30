"""Kit (weapon style) + mod icons (art pass 11), painted with the weapon engine
in its SOFT finish so they sit with the armour sheet.

  style_<hero>_<style>   the 3 weapon styles per survivor (IconSet 48 / 24);
                         each survivor's default style is its base weapon
  mod_<id>               the 12 weapon mods (IconSet 48 / 24) + 96 px
                         icons/mods/icon_mod_<id>.png

WIRE lists what ships; anything left out keeps today's art.

    python3 tools/gen_kit_icons.py [id ...]      (from game/)
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
import gen_loot_icons as LO  # noqa: E402  (materials + label helper)

hx = L.hx
SET = L.SET
MODS96 = os.path.join(L.GAME, "assets", "sprites", "icons", "mods")
bez, crease, tone, rivets = G.bez, G.crease, G.tone, G.rivets
F_ = L.Frame

L.MAT.update({
    "gel_fire": dict(c=hx("#c8601e"), spec=1.0, grime=0.05, rust=0.0, metal=0.0),
    "gel_frost": dict(c=hx("#8ab4c8"), spec=1.1, grime=0.05, rust=0.0, metal=0.0),
    "gel_poison": dict(c=hx("#5e8a2e"), spec=1.0, grime=0.05, rust=0.0, metal=0.0),
    "gel_shock": dict(c=hx("#2e78a8"), spec=1.1, grime=0.05, rust=0.0, metal=0.0),
    "stone": dict(c=hx("#6e6a62"), spec=0.15, grime=0.4, rust=0.0, metal=0.0, pores=1),
    "whet_c": dict(c=hx("#8a5a3a"), spec=0.1, grime=0.4, rust=0.0, metal=0.0, pores=1),
    "hazardw": dict(c=hx("#a8852e"), spec=0.3, grime=0.6, rust=0.2, metal=0.0),
    "molten": dict(c=hx("#e06a1c"), spec=1.0, grime=0.0, rust=0.0, glow=1),
})


# --------------------------------------------------------- style shapes
def k_cluster(ic, st):
    """Cluster Pot: three cast-iron bomblets with tail fins and brass fuses,
    strapped together; olive paint worn off the iron."""
    for (x, y, r, a) in ((30, 64, 14, -0.5), (60, 66, 14, 0.4), (46, 42, 14, -0.1)):
        F = F_(ic, (x, y), math.degrees(a) - 90, 1.0)
        F.bar(r * 0.6, 0, r * 1.5, 0, r * 0.6, "gun", w1=r * 0.3, prof="cyl")
        for v in (-1, 1):
            F.poly([(r * 1.2, 0), (r * 1.7, v * r * 0.7), (r * 1.8, v * r * 0.6), (r * 1.45, 0)], "dark", bevel=0.6)
        ic.ellipse(x, y, r, r * 1.05, "gun", dome=0.95)
        ic.ellipse(x, y, r * 0.98, r * 0.45, "olivep", dome=0.6)
        tip = F.P(-r * 1.1, 0)
        ic.bar(F.P(-r * 0.8, 0), tip, 3.2, "brass", prof="cyl")
    ic.bar((18, 60), (76, 62), 2.6, "leatherb")
    ic.scratches(count=12)



def k_mortar(ic, st):
    """Slag Mortar: a squat tube on a bipod and baseplate, molten slag at the mouth."""
    ic.poly([(14, 80), (70, 80), (76, 88), (10, 88)], "gun", bevel=2.0, dome=0.8)
    F = F_(ic, (32, 80), -60, 1.0)
    F.bar(0, 0, 62, 0, 14, "gun", prof="cyl")
    F.bar(58, 0, 64, 0, 16, "dark", prof="cyl")
    F.bar(20, 0, 26, 0, 15, "rust", prof="cyl")
    tip = F.P(64, 0)
    ic.ellipse(tip[0], tip[1], 6, 4, "molten", dome=0.6)
    ic.bar(F.P(34, 6), (66, 86), 2.6, "steel", prof="cyl")
    ic.bar(F.P(34, 6), (52, 88), 2.6, "steel", prof="cyl")
    rivets(ic, [(20, 84), (64, 84)], 1.2)
    ic.scratches(count=10)


def k_semi(ic, st):
    """Fast semi-auto: magazine-fed battle rifle with a box mag and short scope."""
    F = F_(ic, (6, 66), -28, 0.92)
    F.poly([(0, -3), (22, -3), (30, -1), (30, 5), (14, 9), (0, 9)], "wood", bevel=2.0)
    F.poly([(28, -5), (56, -5), (56, 3), (28, 4)], "gun", bevel=1.4)
    F.poly([(40, 3), (48, 3), (49, 18), (41, 18)], "dark", bevel=1.2)
    F.bar(32, 4, 31, 12, 4.0, "wood")
    F.bar(56, -1.5, 100, -1.5, 2.6, "gun", prof="cyl")
    F.bar(56, 1.6, 82, 1.6, 4.0, "wood")
    F.bar(32, -9, 50, -9, 3.6, "dark", prof="cyl")
    F.bar(96, -1.5, 102, -1.5, 3.6, "dark", prof="cyl")
    F.edge(28, -4.6, 55, -4.6, 0.4)
    ic.scratches(count=14)


def k_coater(ic, st):
    """Charge-shot coater: heavy rifle with a fat green toxin canister on top."""
    F = F_(ic, (6, 66), -28, 0.92)
    F.poly([(0, -3), (22, -3), (30, -1), (30, 5), (14, 9), (0, 9)], "wood", bevel=2.0)
    F.poly([(28, -5), (60, -5), (60, 4), (28, 4)], "gun", bevel=1.4)
    F.bar(32, 4, 31, 12, 4.0, "wood")
    F.bar(60, -1, 98, -1, 4.0, "gun", prof="cyl")
    F.bar(94, -1, 102, -1, 6.0, "dark", prof="cyl")
    F.bar(34, -12, 58, -12, 9, "glassd", prof="cyl")
    F.bar(36, -12, 56, -12, 6.5, "gel_poison", prof="cyl")
    F.bar(33, -12, 35, -12, 10, "brass", prof="cyl")
    F.bar(57, -12, 59, -12, 10, "brass", prof="cyl")
    tip = F.P(103, -1)
    ic.ellipse(tip[0] + 2, tip[1], 3.4, 2.6, "gel_poison", dome=0.8)
    ic.scratches(count=12)


def k_sweep(ic, st):
    """Sledge Sweep: a big two-hand sledgehammer laid diagonally, broad steel
    head, ash haft with tape."""
    F = F_(ic, (12, 86), -45, 1.0)
    F.bar(0, 0, 76, 0, 8.0, "wood", prof="cyl")
    F.bar(0, 0, 20, 0, 9.0, "tape", prof="cyl")
    F.poly([(66, -24), (90, -24), (92, 22), (64, 22)], "gun", bevel=4.0, dome=0.9)
    F.bar(64, -24, 64, 22, 2.4, tone("gun", 1.3, "fh"))
    F.bar(92, -24, 92, 22, 2.4, tone("gun", 1.3, "fh2"))
    F.poly([(60, -8), (66, -8), (66, 8), (60, 8)], "steel", bevel=1.0)
    ic.weld(F.P(68, 16), F.P(88, 16), 1.0)
    ic.scratches(count=12)



def k_driver(ic, st):
    """Pile Driver: a hydraulic ram hammer: steel cylinder head with a piston
    and hoses on a short haft."""
    F = F_(ic, (24, 86), -60, 1.0)
    F.bar(0, 0, 44, 0, 6.0, "steel", prof="cyl")
    F.bar(0, 0, 14, 0, 7.0, "tape", prof="cyl")
    F.bar(40, -16, 40, 16, 22, "gun", prof="cyl")
    F.bar(40, 16, 40, 26, 10, "blade", prof="cyl")
    F.bar(40, -16, 40, -22, 16, "dark", prof="cyl")
    F.bar(34, 8, 20, 6, 2.2, "rubber", prof="cyl")
    F.bar(34, -8, 18, -4, 2.2, "rubber", prof="cyl")
    rivets(ic, [F.P(32, -8), F.P(48, -8), F.P(32, 8), F.P(48, 8)], 1.1)
    ic.scratches(count=12)


def k_whip(ic, st):
    """Live Whip: a coiled insulated cable whip with a copper tip and a handle."""
    ic.bar((18, 80), (32, 66), 6.0, "rubber", prof="cyl")
    ic.bar((16, 82), (20, 78), 8.0, "steel", prof="cyl")
    pts = []
    for k in range(60):
        t = k / 59
        r = 26 - t * 14
        a = t * math.tau * 1.6 + 2.4
        pts.append((52 + math.cos(a) * r, 44 + math.sin(a) * r * 0.8))
    path = [(32, 66)] + pts
    for (a, b) in zip(path[:-1], path[1:]):
        ic.bar(a, b, 3.4, "rubber", prof="cyl")
    ic.bar(path[-1], (path[-1][0] + 4, path[-1][1] - 4), 3.0, "copper", prof="cyl")
    ic.scratches(count=6)


def k_knuckle(ic, st):
    """Knuckle Duster: heavy steel knuckles with four rings, studded."""
    for k in range(4):
        x = 24 + k * 16
        ic.ellipse(x, 44, 9.5, 9.5, "gun", dome=0.9)
        ic.ellipse(x, 44, 5.4, 5.4, "dark", dome=-0.4)
        ic.ellipse(x, 33, 3.0, 2.4, "blade", dome=0.9)
    ic.poly([(18, 52), (78, 52), (72, 74), (24, 74)], "gun", bevel=3.0, dome=0.9)
    ic.bar((26, 64), (70, 64), 1.0, tone("steel", 0.6, "kg"))
    ic.scratches(count=14)


def k_burst(ic, st):
    """Censer Burst: three fat rifle cartridges side by side, fanned, brass
    cases with rims and copper-jacketed bullets."""
    for k, ang in enumerate((-70, -55, -40)):
        F = F_(ic, (30 + k * 10, 88), ang, 1.0)
        F.bar(0, 0, 50, 0, 14.0, "brass", prof="cyl")
        F.bar(0, 0, 4, 0, 15.5, tone("brass", 0.7, "rim"), prof="cyl")
        F.bar(42, 0, 52, 0, 13.0, tone("brass", 0.85, "neck"), w1=10.0, prof="cyl")
        F.bar(52, 0, 70, 0, 10.0, "copper", w1=3.0, prof="cyl")
        F.edge(6, -5, 44, -5, 0.6)
    ic.scratches(count=6)



def k_ember(ic, st):
    """Ember Rounds: a single incendiary cartridge, glowing orange tip."""
    F = F_(ic, (22, 80), -40, 1.2)
    F.bar(0, 0, 40, 0, 12.0, "brass", prof="cyl")
    F.bar(0, 0, 3, 0, 13.0, tone("brass", 0.7, "rim"), prof="cyl")
    F.bar(34, 0, 42, 0, 11.0, tone("brass", 0.85, "neck"), w1=8.5, prof="cyl")
    F.bar(42, 0, 58, 0, 8.5, "molten", w1=2.0, prof="cyl")
    F.bar(12, 0, 16, 0, 12.4, "redp", prof="cyl")
    ic.scratches(count=4)


def k_scalpels(ic, st):
    """Scalpel Pair: two surgical scalpels crossed: ribbed steel handles,
    curved bright blades."""
    for flip in (0, 1):
        F = F_(ic, (14, 84) if not flip else (82, 84), -50 if not flip else -130, 1.0)
        F.poly([(0, -5), (52, -4), (54, 4), (0, 5)], "steel", bevel=1.6, dome=0.9)
        for u in range(6, 34, 4):
            F.bar(u, -3.5, u, 3.5, 0.8, "dark")
        F.poly([(54, -4), (76, -2.0), (90, 2.5), (70, 6), (54, 4)], "blade", bevel=1.6)
        F.edge(56, 5.0, 86, 2.8, 0.5)



def k_cleaver(ic, st):
    """Bonesaw Cleaver: broad rectangular cleaver, saw teeth on the spine, bone grip."""
    F = F_(ic, (12, 76), -30, 1.0)
    F.bar(0, 0, 26, 0, 8.0, "bone", prof="cyl")
    for u in (6, 18):
        p = F.P(u, 0)
        ic.rivet(p[0], p[1], 1.0, "brass")
    teeth = []
    for i in range(9):
        u = 30 + i * 6
        teeth += [(u, -16), (u + 3, -19)]
    F.poly([(26, -16)] + teeth + [(86, -16), (88, 12), (28, 12)], "steel", bevel=2.4)
    F.poly([(60, -12), (78, -12), (80, 2), (62, 4)], "rust", bevel=1.0)
    F.bar(30, -10, 80, -10, 1.2, "gun")
    F.edge(30, 11, 86, 11, 0.5)
    F.bar(56, 4, 76, 6, 2.2, "rust", w1=0.6)
    ic.scratches(count=10)


def k_long(ic, st):
    """Long Knives: one long fighting knife (Bowie pattern), cord grip."""
    F = F_(ic, (10, 86), -45, 1.0)
    F.bar(0, 0, 26, 0, 7.0, "leather", prof="cyl")
    F.bar(2, 0, 24, 0, 7.4, "cloth", prof="cyl")
    F.bar(26, -8, 26, 8, 3.2, "brass", prof="cyl")
    F.poly([(28, -4.6), (96, -3.8), (110, 0.5), (96, 5), (28, 4.6)], "blade", bevel=2.2)
    F.bar(32, -0.4, 86, -0.4, 1.2, "gun")
    F.edge(30, 4.2, 100, 3.8, 0.45)
    ic.scratches(count=8)


def k_viper(ic, st):
    """Viper Fangs: two curved fang daggers, green venom beading on the edges."""
    for flip in (0, 1):
        o = (20, 84) if not flip else (76, 84)
        F = F_(ic, o, -70 if not flip else -110, 1.0)
        F.bar(0, 0, 18, 0, 6.5, "leatherb", prof="cyl")
        F.bar(18, -6, 18, 6, 3.0, "gun", prof="cyl")
        pts = bez((20, -3.5), (48, -8), (70, 4), 10) + bez((70, 4), (46, 2), (20, 3.5), 10)
        F.poly(pts, "blade", bevel=2.0)
        for u in (40, 54):
            p = F.P(u, 2)
            ic.ellipse(p[0], p[1] + 1.5, 1.8, 2.2, "gel_poison", dome=0.8)


def k_flarepistol(ic, st):
    """Flare Pistol: chunky break-action flare gun: fat signal-orange barrel
    and frame (chipped to steel, grimy), black grip, big hammer, a red flare
    shell loaded at the breech."""
    F = F_(ic, (10, 46), -14, 1.15)
    F.poly([(10, 4), (26, 4), (32, 34), (24, 38), (12, 38), (8, 30)], "rubber", bevel=2.0, dome=0.9)
    for v in range(12, 34, 4):
        F.bar(13, v, 27, v + 1, 0.7, tone("rubber", 0.6, "chk"))
    F.poly([(4, -14), (64, -14), (66, 8), (4, 8)], "signal", bevel=3.0, dome=0.9)
    F.bar(30, -3, 74, -3, 22, "signal", prof="cyl")
    F.bar(70, -3, 76, -3, 24, tone("signal", 0.8, "muz"), prof="cyl")
    F.ell(76.5, -3, 2.0, 9.5, "dark", dome=-0.3)
    F.bar(26, 8, 28, 18, 2.0, "gun")
    F.bar(28, 18, 40, 16, 2.0, "gun")
    F.bar(-2, -18, 6, -12, 4.0, "gun", prof="cyl")
    F.bar(26, -14, 30, 8, 1.2, tone("signal", 0.5, "hinge"))
    F.screw(18, -4, 1.1)
    F.edge(6, -13, 62, -13, 0.5)
    ic.scratches(count=14)



def k_machine(ic, st):
    """Machine Pistol: compact pistol with an extended magazine and front grip."""
    F = F_(ic, (14, 40), -14, 1.0)
    F.poly([(8, 7), (22, 7), (25, 30), (11, 32)], "dark", bevel=1.6)
    F.poly([(14, 28), (22, 28), (24, 58), (16, 58)], "gun", bevel=1.2)
    F.poly([(2, -7), (60, -7), (60, 6), (2, 6)], "gun", bevel=1.6)
    F.slots(6, 18, -1, 6, w=0.6, h=9.0)
    F.bar(60, -2, 70, -2, 4.5, "dark", prof="cyl")
    F.bar(44, 6, 44, 18, 4.0, "rubber", prof="cyl")
    F.edge(3, -6.5, 59, -6.5, 0.4)
    ic.scratches(count=10)



# ------------------------------------------------ painted element marks
def mark_flame(ic, cx, cy, r, mat):
    pts = bez((cx - r * 0.6, cy + r * 0.6), (cx - r * 0.9, cy - r * 0.2), (cx - r * 0.1, cy - r), 6) + bez((cx - r * 0.1, cy - r), (cx + r * 0.1, cy - r * 0.3), (cx + r * 0.3, cy - r * 0.5), 4) + bez((cx + r * 0.3, cy - r * 0.5), (cx + r * 0.9, cy), (cx + r * 0.6, cy + r * 0.6), 6) + bez((cx + r * 0.6, cy + r * 0.6), (cx, cy + r * 0.95), (cx - r * 0.6, cy + r * 0.6), 4)
    ic.poly(pts, mat, bevel=0.6, dome=0.2)


def mark_snow(ic, cx, cy, r, mat):
    for k in range(3):
        a = k / 3 * math.pi + math.pi / 2
        ic.bar((cx - math.cos(a) * r, cy - math.sin(a) * r), (cx + math.cos(a) * r, cy + math.sin(a) * r), r * 0.22, mat)
        for sgn in (-1, 1):
            px, py = cx + math.cos(a) * r * 0.6 * sgn, cy + math.sin(a) * r * 0.6 * sgn
            for t in (-0.6, 0.6):
                b = a + t
                ic.bar((px, py), (px + math.cos(b + (math.pi if sgn < 0 else 0)) * r * 0.32, py + math.sin(b + (math.pi if sgn < 0 else 0)) * r * 0.32), r * 0.14, mat)


def mark_drop(ic, cx, cy, r, mat):
    pts = bez((cx, cy - r), (cx - r * 0.7, cy + r * 0.1), (cx - r * 0.55, cy + r * 0.45), 6) + bez((cx - r * 0.55, cy + r * 0.45), (cx, cy + r * 1.1), (cx + r * 0.55, cy + r * 0.45), 6) + bez((cx + r * 0.55, cy + r * 0.45), (cx + r * 0.7, cy + r * 0.1), (cx, cy - r), 6)
    ic.poly(pts, mat, bevel=0.6, dome=0.2)


def mark_bolt(ic, cx, cy, r, mat):
    ic.poly([(cx + r * 0.3, cy - r), (cx - r * 0.55, cy + r * 0.1), (cx - r * 0.05, cy + r * 0.1), (cx - r * 0.35, cy + r), (cx + r * 0.6, cy - r * 0.2), (cx + r * 0.1, cy - r * 0.2)], mat, bevel=0.5, dome=0.2)


def label_plate(ic, x0, y0, x1, y1, mat="paper"):
    ic.poly([(x0, y0), (x1, y0 + 0.6), (x1 - 0.4, y1), (x0 + 0.3, y1 - 0.5)], mat, bevel=1.0, dome=0.5)


# ----------------------------------------------------------- mod shapes
def m_barrel(ic, st):
    """Barrel: a heavy fluted rifle barrel with a perforated heat shroud and a
    muzzle brake, short and chunky."""
    F = F_(ic, (14, 74), -35, 1.0)
    F.bar(0, 0, 70, 0, 12.0, "gun", prof="cyl")
    F.bar(10, 0, 50, 0, 18.0, tone("gun", 0.85, "shroud"), prof="cyl")
    for u in range(14, 48, 6):
        F.ell(u, -3, 1.6, 1.6, "dark", dome=-0.3)
        F.ell(u + 3, 3, 1.6, 1.6, "dark", dome=-0.3)
    F.bar(68, 0, 84, 0, 17, "dark", prof="cyl")
    F.slots(70, 82, 0, 3, w=1.2, h=14.0)
    F.bar(-4, 0, 2, 0, 14, "steel", prof="cyl")
    F.edge(12, -8.4, 48, -8.4, 0.6)



def m_coat(el):
    def fn(ic, st):
        """Weapon coating: a different real container per element, each with a
        paper label carrying a bold painted element mark.
          fire   squat round tin with a lever lid, red label + flame
          frost  frosted glass jar with a screw lid, pale label + snowflake
          poison stoppered dark glass bottle, drip down the side + drop
          shock  steel canister with terminals on top + lightning bolt"""
        if el == "fire":
            ic.bar((48, 34), (48, 80), 60, "steel", prof="cyl")
            ic.ellipse(48, 80, 30, 7, tone("steel", 0.7, "b"), dome=0.5)
            ic.ellipse(48, 34, 30, 8, tone("steel", 1.1, "lid"), dome=0.6)
            ic.ellipse(48, 34, 22, 5, tone("steel", 0.8, "lr"), dome=0.3)
            ic.bar((26, 32), (70, 30), 2.4, "gun", prof="cyl")
            label_plate(ic, 22, 46, 74, 74, "redp")
            mark_flame(ic, 48, 60, 11, "stencil")
            ic.bar((70, 40), (70, 54), 3.6, "gel_fire", w1=2.0, prof="cyl")
        elif el == "frost":
            ic.poly([(30, 30), (66, 30), (70, 36), (70, 86), (26, 86), (26, 36)], "glassw", bevel=4.0, dome=0.9)
            ic.poly([(30, 40), (66, 40), (67, 84), (29, 84)], "gel_frost", bevel=3.0, dome=0.8)
            ic.bar((30, 22), (66, 22), 14, "gun", prof="box")
            for x in range(32, 66, 4):
                ic.bar((x, 16), (x, 28), 0.7, "dark")
            label_plate(ic, 30, 50, 66, 76, "paper")
            mark_snow(ic, 48, 63, 10, "ribbon_b")
            ic.bar((32, 38), (32, 82), 1.6, "frost")
        elif el == "poison":
            body = [(32, 40), (64, 40), (70, 50), (70, 88), (26, 88), (26, 50)]
            LO.bottle(ic, body, "gel_poison", (48, 20, 42, 12), 14, 50, 5, glass="glassd")
            label_plate(ic, 32, 58, 64, 82, "paper")
            mark_drop(ic, 48, 68, 10, "toxicp")
            ic.bar((68, 54), (69, 70), 2.6, "gel_poison", w1=1.6, prof="cyl")
        else:
            ic.bar((48, 30), (48, 86), 40, "gun", prof="cyl")
            ic.ellipse(48, 30, 20, 5, tone("gun", 1.2, "top"), dome=0.6)
            for x in (38, 58):
                ic.bar((x, 22), (x, 30), 6, "copper", prof="cyl")
                ic.ellipse(x, 22, 3, 1.4, tone("copper", 1.3, "ct"), dome=0.5)
            label_plate(ic, 28, 44, 68, 76, "hazardw")
            mark_bolt(ic, 48, 60, 12, "dark")
            for y in (40, 80):
                ic.bar((28, y), (68, y), 1.4, tone("gun", 0.6, "ring"))
        ic.scratches(count=8)
    return fn



def m_edge(ic, st):
    """Edge: one two-grit whetstone (coarse brown on fine grey) seen in 3/4,
    with a bright sharpened bevel along the top edge, wet sheen and steel
    filings."""
    top = [(8, 42), (70, 22), (90, 34), (28, 56)]
    ic.poly([(28, 56), (90, 34), (90, 56), (28, 80)], tone("stone", 0.62, "face"), bevel=1.6)
    ic.poly([(8, 42), (28, 56), (28, 80), (8, 64)], tone("stone", 0.48, "end"), bevel=1.4)
    ic.poly([(28, 68), (90, 45), (90, 56), (28, 80)], "whet_c", bevel=1.2)
    ic.poly([(8, 53), (28, 68), (28, 80), (8, 64)], tone("whet_c", 0.75, "ce"), bevel=1.0)
    ic.poly(top, "stone", bevel=2.6, dome=0.7)
    # sharpened bevel: a honed, polished strip along the near top edge
    ic.poly([(10, 43), (28, 55), (90, 33.6), (88, 31)], "blade", bevel=0.8)
    ic.bar((12, 44.5), (86, 33), 0.7, "frost")
    ic.ellipse(50, 38, 16, 3.4, tone("stone", 1.35, "wet"), dome=0.3)
    for (x, y) in ((40, 36), (56, 31), (64, 38), (32, 44)):
        ic.bar((x, y), (x + 2.5, y - 0.6), 0.6, "steel")
    ic.scratches(count=6)



def m_ext_mag(ic, st):
    """Extended magazine: long curved box magazine, rounds visible at the lips."""
    pts = bez((34, 10), (30, 50), (44, 90), 10) + bez((60, 88), (48, 50), (52, 10), 10)
    ic.poly(pts, "gun", bevel=3.0, dome=0.8)
    for k in range(6):
        y = 24 + k * 11
        ic.bar((32 + k * 1.2, y), (52 + k * 1.2, y), 1.0, tone("gun", 0.6, "rib"))
    ic.bar((34, 10), (52, 10), 3.0, "brass", prof="cyl")
    ic.bar((38, 6), (50, 6), 4.0, "brass", prof="cyl")
    ic.poly([(42, 88), (62, 86), (64, 94), (42, 96)], "dark", bevel=1.0)
    ic.scratches(count=10)


def m_grip(ic, st):
    """Grip: an angled pistol grip wrapped in cloth tape (visible overlapping
    turns, frayed end), steel frame stub on top with the mounting screw, a
    worn highlight down the front strap."""
    F = F_(ic, (26, 18), 66, 1.0)
    F.poly([(-8, -16), (4, -16), (4, 18), (-8, 18)], "gun", bevel=1.6, dome=0.8)
    F.screw(-2, 0, 1.6)
    pts = [(2, -13), (2, 15), (70, 22), (78, 12), (76, -6), (64, -16)]
    F.poly(pts, "tape", bevel=5.0, dome=0.9)
    for u in range(8, 74, 7):
        F.bar(u, -14 + u * 0.05, u + 3, 20, 1.2, tone("tape", 0.62, "turn"))
        F.bar(u + 1.4, -14 + u * 0.05, u + 4.4, 20, 0.6, tone("tape", 1.25, "tlit"))
    F.bar(6, -11, 70, -12, 1.4, tone("tape", 1.45, "hi"))
    tail = F.P(76, 18)
    G.frayed(ic, tail[0], tail[1], 1.4, "thread", 4, 4.0)
    ic.scratches(count=4)




def m_scope(ic, st):
    """Scope: a rifle scope on two rings, turrets, glass at both ends."""
    F = F_(ic, (8, 62), -20, 1.0)
    F.bar(14, 0, 70, 0, 9, "dark", prof="cyl")
    F.bar(0, 0, 16, 0, 12, "dark", w1=9.5, prof="cyl")
    F.bar(68, 0, 86, 0, 9.5, "dark", w1=14, prof="cyl")
    F.ell(86.5, 0, 1.6, 6.4, "glassc", dome=1.0)
    F.ell(-0.5, 0, 1.2, 5.4, "glassc", dome=1.0)
    F.bar(40, -5, 40, -10, 6, "gun", prof="box")
    F.bar(34, 5, 34, 10, 6, "gun", prof="box")
    for u in (24, 58):
        F.bar(u, 4, u, 12, 5, "gun")
        F.screw(u, 10, 0.8)
    F.edge(16, -4, 68, -4, 0.45)


def m_stock(ic, st):
    """Stock: a walnut rifle buttstock with a rubber butt pad and sling swivel."""
    F = F_(ic, (14, 70), -22, 1.0)
    F.poly([(0, -10), (14, -12), (66, -4), (78, -3), (78, 5), (62, 7), (14, 16), (0, 16)], "wood", bevel=3.0)
    F.bar(-1, -10, -1, 16, 4.0, "rubber")
    F.bar(76, -3, 82, -3, 7.0, "gun", prof="cyl")
    F.bar(30, 12, 30, 16, 1.4, "steel")
    F.screw(70, 1, 0.8)


def m_weighted_head(ic, st):
    """Weighted Head: a heavy cast-iron sleeve weight, seen in 3/4: knurled
    band, bore through the middle, two clamp bolts, rust in the knurling."""
    ic.bar((48, 30), (48, 74), 64, "gun", prof="cyl")
    ic.ellipse(48, 30, 32, 10, tone("gun", 1.2, "face"), dome=0.5)
    ic.ellipse(48, 30, 10, 3.4, "dark", dome=-0.4)
    for k in range(16):
        x = 18 + k * 4
        ic.bar((x, 44), (x + 2, 60), 0.8, tone("gun", 0.55, "kn"))
    ic.bar((16, 44), (80, 44), 1.2, tone("gun", 1.3, "kh"))
    for x in (28, 68):
        ic.ellipse(x, 66, 3.6, 3.6, "steel", dome=0.9)
        ic.bar((x - 2.4, 66), (x + 2.4, 66), 0.8, "dark")
    ic.ellipse(48, 74, 32, 8, tone("gun", 0.6, "bot"), dome=0.3)
    ic.scratches(count=14)



def m_wraps(ic, st):
    """Wraps: a roll of cloth grip tape with a loose frayed tail."""
    ic.ellipse(44, 50, 30, 30, "tape", dome=0.9)
    for r in (22, 15):
        ic.ellipse(44, 50, r, r, tone("tape", 0.85 + r / 100, "w%d" % r), dome=0.6)
    ic.ellipse(44, 50, 9, 9, "dark", dome=-0.4)
    tail = bez((62, 72), (74, 82), (88, 84), 6)
    for a, b in zip(tail[:-1], tail[1:]):
        ic.bar(a, b, 9.0, "tape")
    G.frayed(ic, 88, 84, 0.2, "thread", 5, 4.0)
    ic.scratches(count=4)


SHAPES = {
    "style_ash_rook_cluster": k_cluster, "style_ash_rook_mortar": k_mortar,
    "style_vesper_thorn_semi": k_semi, "style_vesper_thorn_coater": k_coater,
    "style_pebble_sweep": k_sweep, "style_pebble_driver": k_driver,
    "style_bolt_juno_whip": k_whip, "style_bolt_juno_knuckle": k_knuckle,
    "style_sister_cinder_burst": k_burst, "style_sister_cinder_ember": k_ember,
    "style_quill_marrow_scalpels": k_scalpels, "style_quill_marrow_cleaver": k_cleaver,
    "style_nyx_caldera_long": k_long, "style_nyx_caldera_viper": k_viper,
    "style_helm_wisp_flare": k_flarepistol, "style_helm_wisp_machine": k_machine,
    "mod_barrel": m_barrel, **{"mod_coat_" + e: m_coat(e) for e in ("fire", "frost", "poison", "shock")},
    "mod_edge": m_edge, "mod_ext_mag": m_ext_mag, "mod_grip": m_grip, "mod_scope": m_scope,
    "mod_stock": m_stock, "mod_weighted_head": m_weighted_head, "mod_wraps": m_wraps,
}
## default style of each survivor = its painted base weapon
BASE = {"style_ash_rook_boom": "ash_rook", "style_vesper_thorn_bolt": "vesper_thorn", "style_pebble_maul": "pebble",
        "style_bolt_juno_chain": "bolt_juno", "style_sister_cinder_suppressor": "sister_cinder",
        "style_quill_marrow_bayonet": "quill_marrow", "style_nyx_caldera_dustblades": "nyx_caldera",
        "style_helm_wisp_sidearm": "helm_wisp"}
ALL = list(BASE) + list(SHAPES)
## shipped (judged side by side with the armour at in-game size)
## Kept old art: mod_grip (the painted grip reads as a black slab), style_helm_wisp_flare
## (the orange flare gun goes blotchy at 48 px), mod_edge (whetstone + blade is
## ambiguous; the old bright edge reads instantly) and the 4 coatings (painted
## tins only differ by gel colour; the old element symbols read better at 24 px).
SKIP = ()
WIRE = [k for k in ALL if k not in SKIP]

for k, fn in SHAPES.items():
    G.SHAPES["kit_" + k] = fn


def render(k, mode):
    L.SOFT = True
    if k in BASE:
        L.MODE = mode
        return L.build(BASE[k], "base")
    return G.build("kit_" + k, G.GENERIC, 900 + ALL.index(k), mode)


def run(k):
    for mode in ("s48", "s24"):
        Image.fromarray(render(k, mode), "RGBA").save(os.path.join(SET, mode[1:], k + ".png"))
    if k.startswith("mod_"):
        Image.fromarray(render(k, "hd"), "RGBA").save(os.path.join(MODS96, "icon_" + k + ".png"))
    return k


if __name__ == "__main__":
    import multiprocessing as mp
    ks = [k for k in WIRE if not sys.argv[1:] or k in sys.argv[1:]]
    with mp.Pool(min(4, os.cpu_count() or 1)) as pool:
        for k in pool.imap_unordered(run, ks):
            print("ok", k)
