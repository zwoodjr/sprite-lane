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
    "molten": dict(c=hx("#e06a1c"), spec=1.0, grime=0.0, rust=0.0, glow=1),
})


# --------------------------------------------------------- style shapes
def k_cluster(ic, st):
    """Cluster Pot: three small bomblets with fins and fuses, bound together."""
    for (x, y, r) in ((34, 62, 15), (62, 62, 15), (48, 40, 15)):
        ic.ellipse(x, y, r, r, "olivep", dome=0.95)
        ic.bar((x - r * 0.7, y + 2), (x + r * 0.7, y + 2), 2.0, tone("olivep", 0.6, "band"))
        ic.bar((x + r * 0.5, y - r * 0.7), (x + r * 0.9, y - r * 1.2), 3.0, "brass", prof="cyl")
        ic.bar((x + r * 0.9, y - r * 1.2), (x + r * 1.3, y - r * 1.6), 1.0, "twine", prof="cyl")
    ic.bar((20, 58), (76, 58), 2.4, "leatherb")
    ic.ellipse(48 + 15 * 1.35, 40 - 15 * 1.7, 2.6, 2.6, "flame", dome=0.4)
    ic.scratches(count=10)


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
        ic.ellipse(x, 44, 9.5, 9.5, "steel", dome=0.9)
        ic.ellipse(x, 44, 5.4, 5.4, "dark", dome=-0.4)
        ic.ellipse(x, 33, 3.0, 2.4, "blade", dome=0.9)
    ic.poly([(18, 52), (78, 52), (72, 74), (24, 74)], "steel", bevel=3.0, dome=0.9)
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
    F.poly([(26, -16)] + teeth + [(86, -16), (88, 12), (28, 12)], "blade", bevel=2.4)
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
    """Flare Pistol: a fat orange break-action flare gun, wide barrel."""
    F = F_(ic, (14, 48), -14, 1.0)
    F.poly([(8, 6), (22, 6), (26, 32), (14, 34), (8, 28)], "signal", bevel=1.8)
    F.bar(2, -4, 66, -4, 14, "signal", prof="cyl")
    F.bar(62, -4, 68, -4, 15, "dark", prof="cyl")
    F.ell(68.5, -4, 1.4, 5.4, "dark", dome=0.2)
    F.bar(0, -10, 8, -10, 3.0, "gun")
    F.bar(22, 8, 24, 16, 1.4, "gun")
    F.bar(24, 16, 32, 15, 1.4, "gun")
    F.screw(18, 0, 0.9)
    ic.scratches(count=10)


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
        """A tin of weapon coating with the lid off, gel brimming and running down."""
        ic.bar((48, 40), (48, 86), 48, "steel", prof="cyl")
        ic.ellipse(48, 86, 24, 6, "steel", dome=0.6)
        ic.ellipse(48, 40, 24, 7, tone("steel", 0.8, "rim"), dome=0.4)
        ic.ellipse(48, 40, 21, 5.6, "gel_" + el, dome=0.7)
        for (x, ln) in ((34, 16), (54, 24), (64, 10)):
            ic.bar((x, 42), (x, 42 + ln), 4.0, "gel_" + el, w1=2.4, prof="cyl")
            ic.ellipse(x, 44 + ln, 2.6, 3.0, "gel_" + el, dome=0.8)
        LO.label(ic, 30, 58, 66, 76, 11)
        ic.poly([(70, 20), (92, 24), (90, 32), (68, 28)], tone("steel", 0.9, "lid"), bevel=1.4)
        ic.scratches(count=8)
    return fn


def m_edge(ic, st):
    """Edge: a whetstone with a blade edge being honed, steel dust."""
    ic.poly([(10, 62), (82, 52), (88, 64), (16, 76)], "stone", bevel=3.0, dome=0.8)
    ic.poly([(12, 74), (86, 62), (88, 70), (14, 82)], tone("stone", 0.7, "side"), bevel=1.4)
    F = F_(ic, (20, 46), -14, 1.0)
    F.poly([(0, -4), (62, -6), (72, 0), (62, 4), (0, 4)], "blade", bevel=2.0)
    F.edge(2, 3.4, 66, 3.0, 0.6)
    ic.bar((14, 38), (28, 36), 6.0, "leatherb", prof="cyl")


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
    """Grip: an angled rubber pistol grip (as on an AR), finger grooves,
    stippled panels, the mounting screw on top."""
    F = F_(ic, (28, 16), 70, 1.0)
    pts = [(0, -12), (0, 14), (66, 22), (74, 12), (72, -6), (60, -16)]
    F.poly(pts, "rubber", bevel=5.0, dome=0.9)
    for u in (22, 38, 54):
        crease(ic, [F.P(u, 17), F.P(u + 2, 10), F.P(u + 4, 18)], 1.6, tone("rubber", 0.45, "fg"), tone("rubber", 1.5, "fh"))
    F.poly([(-6, -16), (2, -16), (2, 18), (-6, 18)], "gun", bevel=1.4)
    F.screw(-2, 0, 1.6)
    F.screw(66, 4, 1.2)
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
    """Weighted Head: a cast-iron weight sleeve with bolts, to clamp on a haft."""
    ic.poly([(18, 26), (78, 26), (84, 34), (84, 70), (78, 78), (18, 78), (12, 70), (12, 34)], "gun", bevel=5.0, dome=0.9)
    ic.ellipse(48, 52, 12, 12, "dark", dome=-0.5)
    ic.ellipse(48, 52, 8, 8, tone("dark", 0.6, "bore"), dome=-0.2)
    for (x, y) in ((22, 34), (74, 34), (22, 70), (74, 70)):
        ic.ellipse(x, y, 3.4, 3.4, "steel", dome=0.9)
        ic.bar((x - 2.4, y), (x + 2.4, y), 0.8, "dark")
    ic.bar((12, 52), (84, 52), 1.2, tone("gun", 0.6, "seam"))
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
SKIP = ("mod_grip", "style_helm_wisp_flare", "mod_edge", "mod_coat_fire", "mod_coat_frost", "mod_coat_poison", "mod_coat_shock")
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
