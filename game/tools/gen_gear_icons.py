"""Armour + accessory icons (art pass 6), rendered with the weapon-icon engine
(gen_legendary_icons.py): real construction (stitching, rivets, buckles,
straps, plates, padding, seams, filters, lenses) and material shading
(leather, canvas, rubber, steel plate, chainmail, cloth weave, glass, fur),
edge wear, layered chips, rust with depth, grime, cast shadows, a soft contact
shadow at 96 px and crisp final-res grit.

IconSet ids written (48 + 24 px; 24 px is the bold simplified variant):
  gear_<slot>_<noun>      generic pieces (Common / Rare / Epic; frame = rarity)
  gset_<set>_<slot>       set pieces: one palette + motif per set, so a set's
                          pieces read as a matched kit
  tleg_<exclusive id>     the 8 tier-exclusive Legendaries
96 px world-pickup icons: icons/gear/icon_slot_<slot>.png, icon_acc_<slot>.png.

    python3 tools/gen_gear_icons.py      (from game/)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_legendary_icons as L  # noqa: E402

hx = L.hx
GAME = L.GAME
SET = L.SET
GEAR96 = os.path.join(GAME, "assets", "sprites", "icons", "gear")

L.MAT.update({
    "canvas": dict(c=hx("#5d5a3c"), spec=0.08, grime=0.6, rust=0.0, weave=1),
    "leatherb": dict(c=hx("#5a3c28"), spec=0.3, grime=0.45, rust=0.0, pores=1, metal=0.0),
    "rubber": dict(c=hx("#2c2b2c"), spec=0.25, grime=0.5, rust=0.0, metal=0.0),
    "plate": dict(c=hx("#6a7078"), spec=0.75, grime=0.5, rust=0.35),
    "mail": dict(c=hx("#7a8088"), spec=0.7, grime=0.45, rust=0.25, mail=1),
    "lens": dict(c=hx("#3a6d7a"), spec=1.3, grime=0.05, rust=0.0, metal=0.0),
    "fur": dict(c=hx("#cdbf9c"), spec=0.05, grime=0.4, rust=0.0, fur=1, metal=0.0),
    "thread": dict(c=hx("#c9b98c"), spec=0.05, grime=0.2, rust=0.0, metal=0.0),
    "pad": dict(c=hx("#6a6448"), spec=0.06, grime=0.55, rust=0.0, quilt=1, weave=1),
    "hazard": dict(c=hx("#d8a21c"), spec=0.3, grime=0.5, rust=0.2, chip="steel", metal=0.0),
    "reflect": dict(c=hx("#c8c8bc"), spec=0.6, grime=0.4, rust=0.0, metal=0.0),
    "gold": dict(c=hx("#b88a33"), spec=1.0, grime=0.35, rust=0.05),
    "copper": dict(c=hx("#a35a2e"), spec=0.9, grime=0.4, rust=0.2),
    "wax": dict(c=hx("#8a1e22"), spec=0.5, grime=0.2, rust=0.0, metal=0.0),
    "liquid_g": dict(c=hx("#6fbf3a"), spec=1.2, grime=0.0, rust=0.0, glow=1),
    "liquid_a": dict(c=hx("#e8901c"), spec=1.2, grime=0.0, rust=0.0, glow=1),
    "liquid_r": dict(c=hx("#b0202a"), spec=1.2, grime=0.0, rust=0.0, glow=1),
    "cork": dict(c=hx("#9a7448"), spec=0.1, grime=0.4, rust=0.0, metal=0.0, pores=1),
    "blood": dict(c=hx("#7e1a20"), spec=0.7, grime=0.1, rust=0.0, metal=0.0),
    "dust": dict(c=hx("#a08669"), spec=0.05, grime=0.5, rust=0.0, metal=0.0),
    "ash": dict(c=hx("#8f877e"), spec=0.05, grime=0.4, rust=0.0, metal=0.0),
    "skinp": dict(c=hx("#b07a5c"), spec=0.2, grime=0.45, rust=0.0, metal=0.0),
    "glassc": dict(c=hx("#8fb0b0"), spec=1.3, grime=0.15, rust=0.0, metal=0.0),
})


def dye(name, col, **kw):
    d = dict(c=hx(col), spec=0.1, grime=0.55, rust=0.0, weave=1, metal=0.0)
    d.update(kw)
    L.MAT[name] = d
    return name


## per-set palette + motif. dye = main fabric, leather, plate, trim (buckles / rivets)
GENERIC = {"dye": "canvas", "leather": "leatherb", "plate": "plate", "trim": "brass", "lens": "lens", "motif": ""}
STYLES = {
    "plague_doctor": dict(dye=dye("d_plague", "#33492c", spec=0.35), leather=dye("l_plague", "#2e2620", spec=0.4, pores=1, weave=0),
                          plate="brass", trim="brass", lens="glass", motif="plague"),
    "demolition_crew": dict(dye=dye("d_demo", "#7e4224"), leather="leatherb", plate="plate", trim="steel", lens="lens", motif="hazard"),
    "night_runner": dict(dye=dye("d_night", "#333c48"), leather=dye("l_night", "#26282c", spec=0.35, pores=1, weave=0),
                         plate="dark", trim="dark", lens="arc", motif="night"),
    "field_salvager": dict(dye=dye("d_salv", "#7a5c2a"), leather="leatherb", plate="rust", trim="brass", lens="lens", motif="salvage"),
    "foremans_kit": dict(dye=dye("d_fore", "#c0641a"), leather="leatherb", plate="hazard", trim="steel", lens="lens", motif="hivis"),
    "bell_ringers_shroud": dict(dye=dye("d_bell", "#583354"), leather="leatherb", plate="brass", trim="brass", lens="lens", motif="bell"),
    "quarry_plate": dict(dye=dye("d_quarry", "#5e4c3a"), leather="leatherb", plate=dye("p_quarry", "#7a7468", spec=0.6, rust=0.3, weave=0, metal=1.0),
                         trim="steel", lens="lens", motif="stone"),
    "linemans_rig": dict(dye=dye("d_line", "#25625e"), leather="rubber", plate="plate", trim="copper", lens="arc", motif="volt"),
    "cathedral_vestments": dict(dye=dye("d_cath", "#8e1c24"), leather="leatherb", plate="gold", trim="gold", lens="lens", motif="cross"),
    "surgeons_coat": dict(dye=dye("d_surg", "#a8a284"), leather="rubber", plate="steel", trim="steel", lens="glassc", motif="surgeon"),
    "smugglers_wraps": dict(dye=dye("d_smug", "#3c3638"), leather=dye("l_smug", "#3a2c24", spec=0.3, pores=1, weave=0),
                            plate="dark", trim="brass", lens="lens", motif="wrap"),
    "flight_crew_gear": dict(dye=dye("d_flight", "#4e5c6a", spec=0.3), leather=dye("l_flight", "#5a3a26", spec=0.35, pores=1, weave=0),
                             plate="steel", trim="steel", lens="glass", motif="flight"),
}
GENERAL_SETS = ["plague_doctor", "demolition_crew", "night_runner", "field_salvager"]
ARMOR = ["head", "chest", "shoulders", "legs", "hands", "boots"]
HERO_SETS = {
    "foremans_kit": ["head", "chest", "hands"], "bell_ringers_shroud": ["head", "shoulders", "legs"],
    "quarry_plate": ["chest", "shoulders", "legs"], "linemans_rig": ["hands", "chest", "boots"],
    "cathedral_vestments": ["chest", "head", "legs"], "surgeons_coat": ["chest", "hands", "head"],
    "smugglers_wraps": ["hands", "legs", "boots"], "flight_crew_gear": ["head", "chest", "boots"],
}
## which base shape each set uses per slot (generic noun index or a special)
SET_SHAPE = {
    "plague_doctor": {"head": "beak", "chest": "coat", "shoulders": "mantle", "legs": "trousers", "hands": "gloves", "boots": "boots"},
    "demolition_crew": {"head": "visor", "chest": "plate", "shoulders": "pauldrons", "legs": "greaves", "hands": "grips", "boots": "treads"},
    "night_runner": {"head": "hood", "chest": "vest", "shoulders": "mantle", "legs": "leggings", "hands": "wraps", "boots": "striders"},
    "field_salvager": {"head": "cap", "chest": "vest", "shoulders": "spaulders", "legs": "trousers", "hands": "gloves", "boots": "boots"},
    "foremans_kit": {"head": "hardhat", "chest": "vest", "hands": "gloves"},
    "bell_ringers_shroud": {"head": "hood", "shoulders": "mantle", "legs": "leggings"},
    "quarry_plate": {"chest": "plate", "shoulders": "pauldrons", "legs": "greaves"},
    "linemans_rig": {"hands": "gloves", "chest": "vest", "boots": "treads"},
    "cathedral_vestments": {"chest": "coat", "head": "hood", "legs": "trousers"},
    "surgeons_coat": {"chest": "coat", "hands": "gloves", "head": "surgcap"},
    "smugglers_wraps": {"hands": "wraps", "legs": "leggings", "boots": "striders"},
    "flight_crew_gear": {"head": "aviator", "chest": "coat", "boots": "boots"},
}
NOUN_SHAPES = {
    "head": ["hood", "visor", "cap"], "chest": ["vest", "coat", "plate"], "shoulders": ["pauldrons", "mantle", "spaulders"],
    "legs": ["greaves", "trousers", "leggings"], "hands": ["gloves", "grips", "wraps"], "boots": ["boots", "treads", "striders"],
    "charm": ["rabbit", "bottlecap", "dogtags"], "vial": ["tonic", "draught", "ward"], "patch": ["squad", "cross", "union"],
}
TLEG = {
    "refinery_gasmask": ("head", "gasmask"), "lamplighter_coat": ("chest", "lampcoat"), "quarantine_seal": ("charm", "seal"),
    "raider_kingsguard": ("shoulders", "spiked"), "chem_filter_vial": ("vial", "chemvial"), "officer_gauntlets": ("hands", "gauntlets"),
    "crater_treads": ("boots", "cratertreads"), "dust_heart_relic": ("patch", "heartrelic"),
}
TLEG_STYLE = {
    "refinery_gasmask": dict(GENERIC, dye="rubber", plate="steel", lens="glass"),
    "lamplighter_coat": dict(GENERIC, dye=dye("d_lamp", "#3e3a30"), leather="leatherb", trim="brass"),
    "quarantine_seal": dict(GENERIC, trim="steel"),
    "raider_kingsguard": dict(GENERIC, plate="red", trim="brass", leather="leatherb"),
    "chem_filter_vial": dict(GENERIC),
    "officer_gauntlets": dict(GENERIC, leather=dye("l_off", "#2a2422", spec=0.45, pores=1, weave=0), plate="steel", trim="gold"),
    "crater_treads": dict(GENERIC, plate="plate", leather="leatherb"),
    "dust_heart_relic": dict(GENERIC, trim="gold"),
}


# ------------------------------------------------------------------ helpers
def stitch(ic, pts, gap=1.6):
    """Running stitch along a polyline (light thread dashes)."""
    if not L._detail():
        return
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        Ls = math.hypot(x1 - x0, y1 - y0)
        n = max(1, int(Ls / gap))
        for i in range(n):
            if i % 2:
                continue
            t0, t1 = i / n, (i + 0.7) / n
            ic.bar((x0 + (x1 - x0) * t0, y0 + (y1 - y0) * t0), (x0 + (x1 - x0) * t1, y0 + (y1 - y0) * t1), 0.55, "thread")


def buckle(ic, x, y, w, h, mat):
    ic.poly([(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2), (x - w / 2, y + h / 2)], mat, bevel=0.9)
    ic.poly([(x - w / 2 + 1, y - h / 2 + 1), (x + w / 2 - 1, y - h / 2 + 1), (x + w / 2 - 1, y + h / 2 - 1), (x - w / 2 + 1, y + h / 2 - 1)], "dark", bevel=0.3)
    ic.bar((x, y - h / 2 + 1), (x, y + h / 2 - 1), 0.8, mat)


def strap(ic, p0, p1, w, st, buck=None):
    ic.bar(p0, p1, w, st["leather"], prof="box", bevel=0.4)
    if buck is not None:
        t = buck
        bx, by = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
        buckle(ic, bx, by, w + 1.6, w + 1.0, st["trim"])


def rivets(ic, pts, r=1.1, mat="steel"):
    for (x, y) in pts:
        ic.rivet(x, y, r, mat)


def mirror(pts, cx=48):
    return [(2 * cx - x, y) for (x, y) in pts]


def stripes(ic, x0, y0, x1, y1, w, n):
    """Hazard stripes as short diagonal bars along a band (black / yellow)."""
    ic.bar((x0, y0), (x1, y1), w, "hazard", prof="box")
    for i in range(n):
        t = (i + 0.5) / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        ic.bar((x - w * 0.3, y + w * 0.45), (x + w * 0.3, y - w * 0.45), w * 0.28, "dark")


# ------------------------------------------------------------------- shapes
def s_gasmask(ic, st):
    # refinery gas mask: rubber face piece, twin canisters, two glass lenses, valve
    ic.poly([(24, 28), (36, 14), (60, 14), (72, 28), (74, 56), (62, 74), (34, 74), (22, 56)], "rubber", bevel=5.0, dome=0.9)
    for cx in (36, 60):
        ic.ellipse(cx, 36, 9.5, 9, "steel", dome=0.9)
        ic.ellipse(cx, 36, 7, 6.6, "glassc", dome=1.0)
        ic.bar((cx - 4, 33), (cx - 1, 31), 1.1, "frost")
        rivets(ic, [(cx - 7, 36), (cx + 7, 36)], 0.8)
    for (x0, x1) in ((40, 22), (56, 74)):
        ic.bar((x0, 62), (x1, 80), 12, "olive", prof="cyl")
        ic.bar((x1 - (x1 - x0) * 0.1, 80 - 2), (x1, 80), 13, "steel", prof="cyl")
        ic.bar(((x0 + x1) / 2 - 2, 70), ((x0 + x1) / 2 + 2, 72), 12.6, "dark", prof="cyl")
    ic.ellipse(48, 62, 7, 6, "steel", dome=0.9)
    for dx in (-3, 0, 3):
        ic.bar((48 + dx, 58), (48 + dx, 66), 0.8, "dark")
    ic.bar((18, 34), (26, 40), 4.0, "rubber")
    ic.bar((70, 40), (78, 34), 4.0, "rubber")
    buckle(ic, 20, 36, 4, 4, "steel")
    ic.scratches(count=14)


def s_lampcoat(ic, st):
    s_coat(ic, st)
    # lantern hung on the belt
    ic.bar((64, 50), (66, 60), 1.0, "steel")
    ic.poly([(60, 60), (72, 60), (73, 78), (59, 78)], "brass", bevel=1.4)
    ic.poly([(62, 63), (70, 63), (70.5, 75), (61.5, 75)], "liquid_a", bevel=1.0)
    ic.bar((66, 64), (66, 74), 1.2, "frost")
    ic.bar((58, 60), (74, 60), 2.0, "dark")
    ic.bar((58, 78), (74, 78), 2.0, "dark")
    rivets(ic, [(30, 50), (40, 50)], 1.0, "brass")


def s_spiked(ic, st):
    s_pauldrons(ic, st, spiked=True)
    ic.bar((20, 44), (76, 44), 2.0, "leather")
    for x in (34, 62):
        ic.bar((x, 44), (x + 2, 60), 3.0, "cloth", w1=1.6)


def _glove(ic, cx, st, fingerless=False, flip=1, gaunt=False):
    palm = [(cx - 12, 46), (cx + 12, 46), (cx + 13, 70), (cx - 11, 72)]
    ic.poly([(cx - 12, 68), (cx + 12, 68), (cx + 11, 86), (cx - 11, 86)], st["leather"] if not gaunt else st["plate"], bevel=2.0)
    ic.poly(palm, st["leather"], bevel=3.0, dome=0.9)
    for i, fx in enumerate((-9, -3, 3, 9)):
        top = 22 + abs(fx) * 0.5 + (4 if i == 0 else 0)
        if fingerless:
            top = 36
        ic.bar((cx + fx, 48), (cx + fx, top), 5.4, st["leather"], prof="cyl")
        if fingerless:
            ic.ellipse(cx + fx, top - 1, 2.6, 2, "skin" if "skin" in L.MAT else "leather")
    ic.bar((cx - 13 * flip, 60), (cx - 20 * flip, 46), 6.0, st["leather"], prof="cyl")
    stitch(ic, [(cx - 11, 66), (cx + 12, 66)], 1.4)
    if gaunt:
        ic.poly([(cx - 12, 46), (cx + 12, 46), (cx + 12, 58), (cx - 12, 58)], st["plate"], bevel=2.0)
        rivets(ic, [(cx - 8, 52), (cx, 52), (cx + 8, 52)], 1.0, st["trim"])
        ic.bar((cx - 11, 74), (cx + 11, 74), 2.0, st["trim"])
    else:
        ic.poly([(cx - 10, 47), (cx + 10, 47), (cx + 10, 53), (cx - 10, 53)], st["plate"] if fingerless else st["leather"], bevel=1.4)
        strap(ic, (cx - 12, 78), (cx + 12, 78), 3.2, st, buck=0.7)


def s_grips(ic, st):
    _glove(ic, 32, st, fingerless=True, flip=1)
    _glove(ic, 64, st, fingerless=True, flip=-1)
    if st["motif"] == "hazard":
        stripes(ic, 54, 84, 74, 84, 3.0, 4)
    ic.scratches(count=10)


def _boot(ic, x, st, kind="boots", flip=1):
    sole = st["leather"] if kind != "treads" else "rubber"
    ic.poly([(x - 9, 10), (x + 9, 10), (x + 10, 58), (x + 26 * flip if flip > 0 else x - 26, 66), (x + 26 * flip if flip > 0 else x - 26, 78), (x - 11, 78)][:6], st["leather"], bevel=4.0, dome=0.85)
    ic.poly([(x - 12, 76), (x + 28 * flip if flip > 0 else x - 28, 76), (x + 28 * flip if flip > 0 else x - 28, 84), (x - 12, 84)], "rubber", bevel=1.6)
    if kind == "treads":
        for k in range(7):
            xx = x - 10 + k * 5.4 * (1 if flip > 0 else -1)
            ic.bar((xx, 82), (xx, 86), 2.2, "rubber")
        ic.poly([(x - 10, 42), (x + 10, 42), (x + 11, 58), (x - 11, 58)], st["plate"], bevel=2.0)
        rivets(ic, [(x - 6, 50), (x + 6, 50)], 1.0)
    # laces / buckles
    if kind == "striders":
        for y in (24, 40, 56):
            strap(ic, (x - 10, y), (x + 10, y - 2), 3.0, st, buck=0.7)
    else:
        for y in range(16, 60, 6):
            ic.bar((x - 5, y), (x + 5, y + 3), 0.8, "thread")
            ic.bar((x - 5, y + 3), (x + 5, y), 0.8, "thread")
            ic.ellipse(x - 6, y + 1.5, 0.8, 0.8, "steel")
            ic.ellipse(x + 6, y + 1.5, 0.8, 0.8, "steel")
    stitch(ic, [(x - 11, 74), (x + 24 * (1 if flip > 0 else -1), 74)], 1.4)
    ic.bar((x - 9, 12), (x + 9, 12), 3.0, st["dye"] if kind != "treads" else st["leather"])


def s_treads(ic, st):
    s_boots(ic, st, "treads")


def s_striders(ic, st):
    s_boots(ic, st, "striders")


def s_gauntlets(ic, st):
    s_gloves(ic, st, gaunt=True)


# accessories
def s_dogtags(ic, st):
    pts = [(20, 10), (30, 30), (40, 44), (48, 50), (56, 44), (66, 30), (76, 10)]
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        n = 4
        for i in range(n):
            t = (i + 0.5) / n
            ic.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, 1.3, 1.3, "steel", dome=0.9)
    for (cx, cy, ang) in ((40, 66, -0.25), (56, 70, 0.2)):
        c, s = math.cos(ang), math.sin(ang)
        loc = [(-10, -14), (10, -14), (12, -8), (12, 10), (10, 15), (-10, 15), (-12, 10), (-12, -8)]
        ic.poly([(cx + u * c - v * s, cy + u * s + v * c) for (u, v) in loc], "steel", bevel=2.0, dome=0.9)
        for k in range(4):
            yy = -7 + k * 5
            ic.bar((cx - 7 * c - yy * s, cy - 7 * s + yy * c), (cx + 6 * c - yy * s, cy + 6 * s + yy * c), 0.9, "dark")
        ic.ellipse(cx - 13 * s, cy + 13 * c * -1 + 0, 1.6, 1.6, "dark", dome=0.2)
    ic.scratches(count=12)


def s_seal(ic, st):
    # quarantine seal: lead seal disc stamped with the biohazard, red wax + tag
    ic.bar((48, 6), (48, 24), 1.4, "thread")
    pts = []
    for k in range(36):
        a = k / 36 * math.tau
        r = 26 + (1.8 if k % 3 == 0 else 0)
        pts.append((48 + math.cos(a) * r, 52 + math.sin(a) * r))
    ic.poly(pts, "wax", bevel=4.0, dome=0.9)
    ic.ellipse(48, 52, 18, 18, "steel", dome=0.6)
    for k in range(3):
        a = k / 3 * math.tau - math.pi / 2
        ic.ellipse(48 + math.cos(a) * 7, 52 + math.sin(a) * 7, 5.4, 5.4, "dark", dome=0.2)
        ic.ellipse(48 + math.cos(a) * 8.6, 52 + math.sin(a) * 8.6, 3.0, 3.0, "steel", dome=0.6)
    ic.ellipse(48, 52, 3.4, 3.4, "dark", dome=0.2)
    ic.ellipse(48, 52, 1.8, 1.8, "steel", dome=0.6)
    ic.bar((66, 70), (80, 88), 6.0, "reflect")
    ic.bar((70, 76), (77, 85), 1.0, "blood")
    ic.scratches(count=10)


def _flask(ic, body, liquid, neck=(42, 54), top=18, cork="cork"):
    ic.bar((48, top), (48, top + 14), 10, "glassc", prof="cyl")
    ic.bar((48, top - 6), (48, top + 2), 9.4, cork, prof="cyl")
    ic.poly(body, "glassc", bevel=4.0, dome=1.0)
    lq = [(x, max(y, 50)) for (x, y) in body]
    ic.poly([(x * 0.94 + 48 * 0.06, y * 0.96 + 3) for (x, y) in lq], liquid, bevel=3.0)
    ic.bar((36, 40), (36, 70), 2.0, "frost")


def s_tonic(ic, st):
    _flask(ic, [(36, 32), (60, 32), (64, 40), (64, 82), (60, 88), (36, 88), (32, 82), (32, 40)], "liquid_g")
    ic.poly([(36, 56), (60, 56), (60, 72), (36, 72)], "reflect", bevel=0.8)
    ic.bar((40, 62), (56, 62), 1.2, "dark")
    ic.bar((40, 66), (52, 66), 1.0, "dark")
    ic.bar((40, 30), (56, 30), 2.4, "thread")


def s_draught(ic, st):
    _flask(ic, [(30, 40), (42, 30), (54, 30), (66, 40), (72, 62), (66, 84), (30, 84), (24, 62)], "liquid_a")
    ic.bar((28, 58), (68, 58), 3.6, "leatherb")
    buckle(ic, 48, 58, 5, 5, "brass")
    stitch(ic, [(30, 56), (66, 56)], 1.4)


def s_ward(ic, st):
    ic.bar((48, 10), (48, 26), 8.0, "steel", prof="cyl")
    ic.bar((48, 26), (48, 80), 14.0, "glassc", prof="cyl")
    ic.bar((48, 40), (48, 79), 12.4, "liquid_g", prof="cyl")
    ic.bar((48, 78), (48, 88), 15.0, "steel", prof="cyl")
    for y in (32, 50, 68):
        ic.bar((40, y), (56, y), 1.4, "steel", prof="cyl")
    ic.bar((43, 30), (43, 76), 1.6, "frost")
    rivets(ic, [(42, 84), (54, 84)], 0.9)


def s_chemvial(ic, st):
    # chem-filter vial: armoured canister with a threaded filter cap and gauge window
    ic.bar((48, 16), (48, 86), 24, "olive", prof="cyl")
    ic.bar((48, 8), (48, 22), 20, "steel", prof="cyl")
    for y in range(9, 21, 2):
        ic.bar((38, y), (58, y), 0.5, "dark")
    ic.poly([(42, 36), (54, 36), (54, 74), (42, 74)], "dark", bevel=0.8)
    ic.bar((48, 50), (48, 73), 10, "liquid_g", prof="cyl")
    ic.bar((44, 38), (44, 72), 1.2, "frost")
    for y in (30, 80):
        ic.bar((36, y), (60, y), 3.0, "steel", prof="cyl")
    rivets(ic, [(39, 30), (57, 30), (39, 80), (57, 80)], 0.9)
    ic.ellipse(48, 15, 4, 3, "dark", dome=0.2)
    ic.scratches(count=12)


def _badge_shield(ic, mat):
    ic.poly([(22, 16), (74, 16), (76, 52), (64, 74), (48, 84), (32, 74), (20, 52)], mat, bevel=3.0, dome=0.7)
    stitch(ic, [(25, 19), (71, 19), (73, 51), (62, 71), (48, 80), (34, 71), (23, 51), (25, 19)], 1.4)


def s_squad(ic, st):
    _badge_shield(ic, "olive")
    for k in range(3):
        y = 30 + k * 12
        ic.poly([(30, y + 6), (48, y - 4), (66, y + 6), (66, y + 12), (48, y + 2), (30, y + 12)], "brass", bevel=1.4)


def s_cross(ic, st):
    _badge_shield(ic, "reflect")
    ic.bar((48, 26), (48, 70), 10, "blood", prof="box")
    ic.bar((30, 44), (66, 44), 10, "blood", prof="box")
    ic.ellipse(66, 66, 3, 2.4, "rust")


def s_union(ic, st):
    pts = []
    for k in range(32):
        a = k / 32 * math.tau
        r = 30 if (k // 2) % 2 else 24
        pts.append((48 + math.cos(a) * r, 50 + math.sin(a) * r))
    ic.poly(pts, "brass", bevel=3.0, dome=0.9)
    ic.ellipse(48, 50, 16, 16, "dark", dome=0.3)
    ic.ellipse(48, 50, 12, 12, "steel", dome=0.9)
    ic.bar((40, 50), (56, 50), 2.4, "dark")
    ic.bar((48, 42), (48, 58), 2.4, "dark")
    rivets(ic, [(48, 24), (48, 76), (22, 50), (74, 50)], 1.2)
    ic.scratches(count=10)


def s_heartrelic(ic, st):
    # dust heart relic: amber heart-shaped crystal in a riveted cage on a patch
    _badge_shield(ic, "leatherb")
    heart = []
    for k in range(40):
        t = k / 40 * math.tau
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        heart.append((48 + x * 1.15, 46 + y * 1.15))
    ic.poly(heart, "liquid_a", bevel=4.0, dome=1.0)
    for (x0, y0, x1, y1) in ((32, 36, 64, 36), (48, 26, 48, 68), (34, 50, 62, 50)):
        ic.bar((x0, y0), (x1, y1), 1.8, "gold", prof="cyl")
    rivets(ic, [(32, 36), (64, 36), (48, 68)], 1.2, "gold")
    ic.bar((40, 38), (44, 34), 1.4, "frost")


# ---------------------------------------------------------------- realism kit
def tone(mat, k, tag):
    """A darker / lighter variant of a material (lining, inner shadow)."""
    name = "%s~%s" % (mat, tag)
    if name not in L.MAT:
        d = dict(L.MAT[mat])
        d["c"] = np.clip(d["c"] * k, 0, 255)
        L.MAT[name] = d
    return name


def bez(p0, p1, p2, n=14, p3=None):
    out = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        else:
            x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0] + t ** 3 * p3[0]
            y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1] + t ** 3 * p3[1]
        out.append((x, y))
    return out


def crease(ic, pts, w, mat, light=None):
    """A fold: dark crease line with a lit ridge just above-left of it."""
    for (a, b) in zip(pts[:-1], pts[1:]):
        if light:
            ic.bar((a[0] - 0.7, a[1] - 0.7), (b[0] - 0.7, b[1] - 0.7), w * 0.8, light)
        ic.bar(a, b, w, mat)


def frayed(ic, x, y, ang, mat, n=4, ln=5.0):
    if not L._detail():
        return
    for k in range(n):
        a = ang + (k - n / 2) * 0.22
        ic.bar((x, y), (x + math.cos(a) * ln * (0.7 + 0.1 * k), y + math.sin(a) * ln * (0.7 + 0.1 * k)), 0.6, mat)


# ---------------------------------------------------------------- hood (3/4)
def s_hood(ic, st):
    d = st["dye"]
    lining = tone(d, 1.35, "lin")
    deep = tone(d, 0.5, "deep")
    ridge = tone(d, 1.25, "ridge")
    fold = tone(d, 0.62, "fold")
    # cowl / shoulders the hood drapes onto
    ic.poly(bez((6, 92), (8, 66), (34, 62), 10) + bez((34, 62), (62, 58), (90, 70), 10) + [(92, 92)], d, bevel=5.0, dome=0.8)
    # hood shell: peak at the back (top-right), face opening turned to the left
    shell = bez((20, 70), (8, 40), (30, 16), 12) + bez((30, 16), (52, 2), (76, 12), 12) + bez((76, 12), (90, 30), (84, 66), 12) + bez((84, 66), (60, 78), (20, 70), 12)
    ic.poly(shell, d, bevel=7.0, dome=0.9)
    # folds running from the peak down the back of the hood
    crease(ic, bez((70, 14), (80, 34), (76, 62), 8), 1.2, fold, ridge)
    crease(ic, bez((60, 10), (70, 36), (64, 66), 8), 1.0, fold, ridge)
    crease(ic, bez((40, 66), (52, 70), (66, 74), 6), 1.0, fold, ridge)
    crease(ic, bez((30, 70), (40, 78), (56, 82), 6), 0.9, fold, ridge)
    # face opening: lining rim -> soft shadowed interior (never a black hole)
    rim = bez((26, 66), (14, 42), (30, 22), 12) + bez((30, 22), (44, 12), (54, 26), 10) + bez((54, 26), (60, 50), (48, 66), 10) + bez((48, 66), (36, 72), (26, 66), 8)
    ic.poly(rim, lining, bevel=2.4, dome=0.6)
    inner = [(x * 0.8 + 39 * 0.2 + 3.0, y * 0.84 + 44 * 0.16 + 1.0) for (x, y) in rim]
    ic.poly(inner, tone(d, 0.68, "in1"), bevel=3.0, dome=-0.4)
    inner2 = [(x * 0.55 + 41 * 0.45 + 6, y * 0.66 + 46 * 0.34 + 3) for (x, y) in rim]
    ic.poly(inner2, deep, bevel=5.0, dome=-0.5)
    # rolled hem along the opening with running stitch
    for (a, b) in zip(rim[:-1], rim[1:]):
        ic.bar(a, b, 2.2, ridge, prof="cyl")
    # drawstring with metal aglets at the throat
    ic.bar((30, 66), (28, 84), 1.2, "thread", prof="cyl")
    ic.bar((40, 68), (42, 86), 1.2, "thread", prof="cyl")
    ic.bar((28, 84), (28, 88), 1.6, "steel", prof="cyl")
    ic.bar((42, 86), (42, 90), 1.6, "steel", prof="cyl")
    # back seam stitching up the hood
    stitch(ic, bez((80, 64), (88, 34), (74, 12), 10), 1.6)
    if st["motif"] == "bell":
        ic.bar((70, 72), (70, 80), 0.9, "leather")
        ic.poly([(67, 80), (73, 80), (75, 87), (65, 87)], "brass", bevel=1.4)
    elif st["motif"] == "cross":
        ic.bar((72, 30), (72, 50), 3.0, "gold")
        ic.bar((65, 37), (79, 37), 3.0, "gold")
    elif st["motif"] == "night":
        ic.bar((14, 80), (86, 76), 3.0, tone(d, 0.7, "band"))
        ic.ellipse(74, 78, 2.4, 2.4, "steel")
    ic.scratches(count=6)


# ------------------------------------------------- plague doctor mask (3/4)
def s_beak(ic, st):
    lea = st["leather"]
    lea_hi = tone(lea, 1.35, "hi")
    seam = tone(lea, 0.6, "seam")
    # wide-brimmed hat behind/over the head
    ic.poly(bez((26, 30), (48, 14), (92, 22), 12) + bez((92, 22), (96, 30), (80, 34), 6) + bez((80, 34), (52, 38), (26, 30), 10), tone(lea, 0.8, "hat"), bevel=2.0)
    ic.poly(bez((46, 24), (48, 2), (68, 4), 10) + bez((68, 4), (84, 8), (80, 26), 8) + [(46, 26)], tone(lea, 0.8, "hat"), bevel=4.0, dome=0.9)
    ic.bar((46, 22), (81, 22), 3.2, tone(lea, 0.55, "band"))
    # head: leather hood shell under the hat, turned 3/4 left
    head = bez((40, 30), (36, 52), (48, 74), 10) + bez((48, 74), (66, 88), (84, 72), 10) + bez((84, 72), (92, 46), (78, 30), 10)
    ic.poly(head, lea, bevel=6.0, dome=0.9)
    # beak: long, curved, tapering, slightly downturned, comes to a point
    top = bez((48, 40), (22, 40), (2, 74), 16, p3=None)
    bot = bez((1, 76), (26, 58), (54, 62), 16)
    ic.poly(top + bot, lea, bevel=3.4, dome=0.8)
    # stitched seam along the ridge of the beak, panel seams across it
    stitch(ic, bez((47, 42), (27, 45), (9, 68), 14), 1.5)
    for (a, b) in (((36, 44), (38, 58)), ((24, 50), (25, 61)), ((14, 59), (14, 66))):
        ic.bar(a, b, 0.9, seam)
    # lit ridge along the top of the beak
    for (a, b) in zip(top[1:-2], top[2:-1]):
        ic.bar((a[0], a[1] + 0.8), (b[0], b[1] + 0.8), 0.9, lea_hi)
    # breathing vent near the base of the beak
    for (x, y) in ((44, 56), (41, 57), (38, 57.5)):
        ic.ellipse(x, y, 0.9, 0.8, "dark", dome=0.1)
    # eye lenses in brass rims (near eye big, far eye foreshortened)
    ic.ellipse(57, 46, 8.0, 8.0, "brass", dome=0.9)
    ic.ellipse(57, 46, 5.6, 5.6, "glassc", dome=1.0)
    ic.bar((53.5, 43.5), (55.5, 41.5), 1.1, "frost")
    ic.ellipse(78, 44, 4.0, 6.4, "brass", dome=0.9)
    ic.ellipse(78, 44, 2.6, 4.6, "glassc", dome=1.0)
    # strap round the back of the head with a buckle
    ic.bar((66, 60), (90, 56), 3.6, tone(lea, 0.7, "strap"))
    buckle(ic, 84, 57, 5, 5, "brass")
    stitch(ic, bez((52, 70), (66, 82), (82, 72), 8), 1.5)
    ic.scratches(count=10)


# -------------------------------------------------------- hand wraps (pair)
def _wrapped_hand(ic, cx, st, flip=1):
    d = st["dye"]
    skin = "skinp"
    strip = d
    shade = tone(d, 0.62, "wsh")
    hi = tone(d, 1.3, "whi")
    # bare fingers + thumb (fingerless wraps)
    for i, fx in enumerate((-8.5, -3, 2.5, 8)):
        top = 20 + abs(fx - 0) * 0.45 + (3 if i == 0 else 0)
        ic.bar((cx + fx * flip, 40), (cx + fx * flip, top), 5.2, skin, prof="cyl")
        ic.ellipse(cx + fx * flip, top + 1.5, 1.6, 1.1, tone(skin, 1.15, "nail"))
    # palm/knuckles + wrist wrapped in overlapping diagonal strips
    ic.poly([(cx - 12, 36), (cx + 12, 36), (cx + 13, 60), (cx + 10, 88), (cx - 10, 88), (cx - 13, 60)], strip, bevel=3.0, dome=0.9)
    for k in range(8):
        y = 38 + k * 6.4
        a, b = (cx - 13, y + 3.2 * flip), (cx + 13, y - 3.2 * flip)
        ic.bar((a[0], a[1] + 1.6), (b[0], b[1] + 1.6), 1.6, shade)
        ic.bar(a, b, 0.7, hi)
    # knuckle wrap across the fingers' base
    ic.bar((cx - 12, 37), (cx + 12, 37), 3.4, strip, prof="cyl")
    # loose frayed tail
    tail = bez((cx - 10 * flip, 82), (cx - 16 * flip, 88), (cx - 18 * flip, 95), 6)
    for (a, b) in zip(tail[:-1], tail[1:]):
        ic.bar(a, b, 3.0, strip)
    frayed(ic, tail[-1][0], tail[-1][1], math.pi / 2 + 0.3 * flip, hi, 4, 3.5)
    stitch(ic, [(cx - 10, 86), (cx + 10, 86)], 1.4)


def s_wraps(ic, st):
    _wrapped_hand(ic, 30, st, 1)
    _wrapped_hand(ic, 64, st, -1)
    if st["motif"] == "wrap":
        ic.ellipse(30, 62, 2.6, 2.6, "brass")
        ic.ellipse(64, 70, 2.6, 2.6, "brass")
    ic.scratches(count=4)


# ------------------------------------ leggings: trousers + wrapped puttees
def _legging(ic, cx, st, lean):
    d = st["dye"]
    fold = tone(d, 0.6, "lfold")
    ridge = tone(d, 1.25, "lridge")
    puttee = tone(d, 1.12, "putt")
    psh = tone(d, 0.55, "psh")
    # upper leg cloth with folds
    ic.poly([(cx - 12, 8), (cx + 11, 8), (cx + 11 + lean, 46), (cx - 11 + lean, 46)], d, bevel=4.0, dome=0.8)
    crease(ic, bez((cx - 6, 14), (cx - 2, 26), (cx - 7 + lean, 40), 6), 0.9, fold, ridge)
    crease(ic, bez((cx + 5, 12), (cx + 7, 24), (cx + 4 + lean, 38), 6), 0.8, fold, ridge)
    # knee patch, stitched, with wrinkles round the joint
    ic.poly([(cx - 8 + lean, 40), (cx + 8 + lean, 40), (cx + 9 + lean, 54), (cx - 9 + lean, 54)], tone(d, 0.85, "kp"), bevel=1.6)
    stitch(ic, [(cx - 7 + lean, 41), (cx + 7 + lean, 41), (cx + 8 + lean, 53), (cx - 8 + lean, 53), (cx - 7 + lean, 41)], 1.3)
    for k in range(3):
        crease(ic, bez((cx - 10 + lean, 56 + k * 2), (cx + lean, 58 + k * 2.5), (cx + 10 + lean, 56 + k * 2), 4), 0.6, fold)
    # lower leg: puttee strip wound in overlapping spirals
    l2 = lean * 1.5
    ic.poly([(cx - 10 + lean, 54), (cx + 10 + lean, 54), (cx + 8 + l2, 88), (cx - 8 + l2, 88)], puttee, bevel=3.0, dome=0.9)
    for k in range(6):
        y = 58 + k * 5.4
        xo = lean + (l2 - lean) * (k / 6)
        ic.bar((cx - 10 + xo, y + 2.4), (cx + 10 + xo, y - 1.4), 1.4, psh)
        ic.bar((cx - 10 + xo, y + 1.0), (cx + 10 + xo, y - 2.8), 0.6, ridge)
    # tie tape + frayed end at the top of the puttee
    ic.bar((cx - 10 + lean, 56), (cx + 10 + lean, 56), 1.6, "thread")
    frayed(ic, cx + 10 + lean, 56, 0.3, "thread", 3, 4.0)
    ic.bar((cx - 9 + l2, 88), (cx + 9 + l2, 88), 2.6, st["leather"])
    # waist seam
    ic.bar((cx - 12, 9), (cx + 11, 9), 3.0, tone(d, 0.75, "waist"))


def s_leggings(ic, st):
    _legging(ic, 34, st, -2.5)
    _legging(ic, 62, st, 2.0)
    if st["motif"] == "bell":
        ic.poly([(46, 14), (52, 14), (54, 22), (44, 22)], "brass", bevel=1.4)
    elif st["motif"] == "wrap":
        ic.ellipse(30, 70, 2.6, 2.6, "brass")
        ic.ellipse(64, 64, 2.6, 2.6, "brass")
    ic.scratches(count=4)


def s_surgcap(ic, st):
    """Surgeon's kit: pleated cloth face mask with ear loops and ties, a scrub
    cap behind it, a blood spatter."""
    d = st["dye"]
    ic.poly(bez((22, 40), (24, 8), (56, 8), 10) + bez((56, 8), (86, 10), (82, 42), 10) + [(22, 42)], d, bevel=5.0, dome=0.8)
    stitch(ic, [(24, 38), (80, 38)], 1.4)
    crease(ic, bez((40, 14), (44, 26), (40, 36), 5), 0.8, tone(d, 0.6, "sf"))
    # mask: pleated rectangle, wider at the top
    mask = [(14, 46), (82, 44), (78, 76), (52, 86), (20, 78)]
    ic.poly(mask, "reflect", bevel=3.0, dome=0.7)
    for k in range(3):
        y = 54 + k * 8
        crease(ic, [(17, y + 1), (48, y + 2.5), (80, y - 1)], 1.0, tone("reflect", 0.55, "pl"), tone("reflect", 1.15, "plh"))
    ic.bar((14, 46), (82, 44), 2.2, tone("reflect", 0.85, "edge"))
    ic.bar((30, 45.4), (62, 44.6), 1.2, "steel")
    # ear loops + ties
    for side in (-1, 1):
        x = 14 if side < 0 else 82
        ic.bar((x, 47), (x + 8 * side, 56), 1.0, "thread")
        ic.bar((x + 8 * side, 56), (x - 1 * side, 74), 1.0, "thread")
    ic.ellipse(60, 66, 3.6, 2.8, "blood")
    ic.ellipse(66, 72, 1.8, 1.4, "blood")
    ic.ellipse(55, 74, 1.2, 1.0, "blood")


def s_aviator(ic, st):
    """Leather flying helmet, 3/4 view: panelled crown, fur-edged ear flap with
    chin strap and buckle, goggles pushed up on the forehead."""
    lea = st["leather"]
    crown = bez((18, 50), (16, 14), (54, 10), 10) + bez((54, 10), (86, 12), (84, 50), 10) + bez((84, 50), (84, 74), (66, 80), 8) + [(30, 70)]
    ic.poly(crown, lea, bevel=6.0, dome=0.95)
    stitch(ic, bez((50, 11), (44, 36), (46, 64), 10), 1.5)
    stitch(ic, bez((70, 14), (78, 40), (74, 70), 10), 1.5)
    # ear flap with fur edge
    flap = [(56, 50), (76, 50), (78, 86), (60, 90), (54, 70)]
    ic.poly(flap, tone(lea, 0.9, "flap"), bevel=3.0, dome=0.8)
    for (a, b) in zip(flap, flap[1:] + flap[:1]):
        ic.bar(a, b, 2.4, "fur")
    ic.bar((60, 88), (40, 92), 3.0, lea)
    buckle(ic, 44, 91, 5, 4.6, "steel")
    # goggles on the forehead
    ic.bar((16, 36), (86, 30), 4.4, "rubber")
    for (cx, cy, rx) in ((32, 34, 9.0), (54, 32, 8.0)):
        ic.ellipse(cx, cy, rx, rx * 0.86, "steel", dome=0.9)
        ic.ellipse(cx, cy, rx * 0.72, rx * 0.62, st["lens"], dome=1.0)
        ic.bar((cx - rx * 0.45, cy - 2), (cx - rx * 0.15, cy - 3.6), 1.0, "frost")
    ic.bar((41, 33.5), (46, 33), 2.6, "steel")
    ic.scratches(count=8)


def s_vest(ic, st):
    """Plate carrier: shoulder straps with pads, MOLLE webbing rows, three
    magazine pouches with flaps, side cummerbund, drag handle."""
    d = st["dye"]
    web = tone(d, 0.72, "web")
    body = [(22, 18), (34, 16), (40, 28), (56, 28), (62, 16), (74, 18), (80, 34), (78, 86), (18, 86), (16, 34)]
    ic.poly(body, d, bevel=4.0, dome=0.7)
    # shoulder straps + pads
    for x in (28, 68):
        ic.poly([(x - 7, 10), (x + 7, 10), (x + 6, 30), (x - 6, 30)], tone(d, 0.85, "pad"), bevel=2.0, dome=0.8)
        stitch(ic, [(x - 5, 12), (x - 5, 28)], 1.3)
    ic.bar((42, 22), (54, 22), 3.0, web)
    # MOLLE rows
    for y in (40, 47):
        ic.bar((20, y), (76, y), 2.0, web)
        for x in range(22, 76, 6):
            ic.bar((x, y - 1), (x, y + 1), 0.6, "dark")
    # magazine pouches
    for x in (22, 37, 52):
        ic.poly([(x, 52), (x + 13, 52), (x + 13, 80), (x, 80)], d, bevel=1.8, dome=0.6)
        ic.poly([(x - 0.5, 50.5), (x + 13.5, 50.5), (x + 13.5, 58), (x - 0.5, 58)], web, bevel=1.0)
        ic.bar((x + 6.5, 56), (x + 6.5, 62), 2.4, "rubber")
        stitch(ic, [(x + 1, 78), (x + 12, 78)], 1.2)
    ic.poly([(67, 52), (77, 52), (77, 78), (67, 78)], d, bevel=1.4)
    ic.bar((72, 54), (72, 76), 1.4, "dark")
    if st["motif"] == "hivis":
        ic.bar((19, 70), (77, 70), 3.6, "reflect")
        ic.bar((24, 30), (24, 86), 2.6, "reflect")
        ic.bar((72, 30), (72, 86), 2.6, "reflect")
    elif st["motif"] == "volt":
        ic.bar((24, 30), (40, 38), 2.4, "copper", prof="cyl")
        ic.ellipse(72, 36, 4, 4, "rubber")
        ic.ellipse(72, 36, 2, 2, "arc")
    elif st["motif"] == "salvage":
        for x in (26, 34, 42):
            ic.bar((x, 33), (x, 42), 1.6, "steel", prof="cyl")
        ic.bar((56, 36), (68, 32), 2.4, "brass", prof="cyl")
    elif st["motif"] == "night":
        ic.bar((20, 84), (76, 84), 2.0, "dark")
    ic.scratches(count=10)


def s_coat(ic, st):
    """Long field coat hung open: collar, lapels, sleeves hanging at the sides,
    button front, belt with buckle, pocket flaps."""
    d = st["dye"]
    fold = tone(d, 0.62, "ff")
    ridge = tone(d, 1.2, "fr")
    # sleeves (behind the body), slightly bent
    for side in (-1, 1):
        x0 = 48 + side * 22
        ic.poly([(x0, 14), (x0 + side * 12, 20), (x0 + side * 16, 70), (x0 + side * 8, 74), (x0 + side * 2, 40)], tone(d, 0.88, "sl"), bevel=3.0, dome=0.8)
        ic.bar((x0 + side * 16, 70), (x0 + side * 8, 74), 3.0, tone(d, 0.7, "cuff"))
        crease(ic, [(x0 + side * 6, 30), (x0 + side * 10, 48), (x0 + side * 11, 64)], 0.8, fold)
    body = [(30, 10), (44, 18), (52, 18), (66, 10), (72, 22), (76, 92), (54, 92), (48, 42), (42, 92), (20, 92), (24, 22)]
    ic.poly(body, d, bevel=4.0, dome=0.7)
    crease(ic, bez((30, 50), (28, 70), (30, 90), 6), 0.9, fold, ridge)
    crease(ic, bez((66, 52), (68, 72), (66, 90), 6), 0.9, fold, ridge)
    # collar + lapels
    ic.poly([(30, 10), (44, 18), (46, 42), (36, 34), (26, 18)], tone(d, 1.08, "lap"), bevel=2.0)
    ic.poly(mirror([(30, 10), (44, 18), (46, 42), (36, 34), (26, 18)]), tone(d, 1.08, "lap"), bevel=2.0)
    if st["motif"] == "flight":
        ic.poly([(24, 10), (40, 15), (42, 30), (22, 24)], "fur", bevel=2.0)
        ic.poly(mirror([(24, 10), (40, 15), (42, 30), (22, 24)]), "fur", bevel=2.0)
        ic.bar((47, 30), (47, 88), 1.4, "steel")
        for y in range(32, 88, 4):
            ic.bar((46, y), (48, y), 0.6, "dark")
    for y in (48, 60, 72):
        ic.ellipse(44, y, 1.8, 1.8, st["trim"], dome=0.9)
    # pocket flaps
    for x in (26, 56):
        ic.poly([(x, 66), (x + 14, 66), (x + 14, 72), (x, 72)], tone(d, 0.9, "pf"), bevel=1.0)
        stitch(ic, [(x + 1, 67), (x + 13, 67)], 1.2)
    ic.bar((22, 54), (74, 54), 3.6, st["leather"])
    buckle(ic, 36, 54, 6, 5, st["trim"])
    if st["motif"] == "cross":
        ic.bar((62, 60), (62, 86), 3.6, "gold")
        ic.bar((55, 68), (69, 68), 3.6, "gold")
        stitch(ic, [(20, 90), (76, 90)])
    elif st["motif"] == "surgeon":
        ic.ellipse(64, 78, 4, 3, "blood")
        ic.ellipse(60, 86, 2.4, 2, "blood")
        ic.poly([(56, 26), (64, 26), (64, 34), (56, 34)], "reflect", bevel=0.6)
        ic.bar((60, 27), (60, 33), 1.6, "blood")
        ic.bar((57, 30), (63, 30), 1.6, "blood")
    elif st["motif"] == "plague":
        ic.bar((22, 84), (74, 84), 2.0, "dark")
    ic.scratches(count=10)


def _work_glove(ic, cx, cy, ang, st, back=False):
    """One work glove, back of the hand up: cuff, knuckle seam, finger seams
    with stitched tips, thumb out to the side. Drawn in a local frame."""
    F = L.Frame(ic, (cx, cy), ang, 1.0)
    lea = st["leather"] if not back else tone(st["leather"], 0.85, "gb")
    seam = tone(st["leather"], 0.55, "gs")
    F.poly([(-12, 0), (12, 0), (11, 18), (-11, 18)], tone(lea, 0.8, "cuf"), bevel=2.0)
    F.poly([(-13, -24), (13, -24), (12, 2), (-12, 2)], lea, bevel=3.0, dome=0.9)
    for i, fx in enumerate((-9, -3, 3, 9)):
        top = -46 + abs(fx - 1) * 0.6 + (4 if i == 0 else 0)
        F.bar(fx, -22, fx, top, 5.6, lea, prof="cyl")
        F.bar(fx, top + 6, fx, top + 6.2, 5.0, seam)
        F.bar(fx - 2.6, -22, fx - 2.6, top + 3, 0.5, seam)
    F.bar(-13, -8, -22, -24, 6.0, lea, prof="cyl")
    F.bar(-12, -22, 12, -22, 1.0, seam)
    F.bar(-11, -2, 11, -2, 2.4, tone(lea, 0.7, "band"))
    st2 = dict(st)
    strap(ic, F.P(-12, 10), F.P(12, 10), 3.4, st2, buck=0.7)
    return F


def s_gloves(ic, st, gaunt=False):
    _work_glove(ic, 34, 70, -8, st, back=True)
    F = _work_glove(ic, 60, 76, 10, st)
    if gaunt:
        for (FF, cx) in ((None, 0),):
            pass
        for cxx, cyy, a in ((34, 70, -8), (60, 76, 10)):
            G = L.Frame(ic, (cxx, cyy), a, 1.0)
            G.poly([(-13, -24), (13, -24), (12, -8), (-12, -8)], st["plate"], bevel=2.0, dome=0.9)
            G.bar(-11, -16, 11, -16, 1.0, "dark")
            for fx in (-9, -3, 3, 9):
                G.ell(fx, -24, 2.6, 2.0, st["plate"], dome=0.9)
            for fx in (-8, 0, 8):
                rv = G.P(fx, -12)
                ic.rivet(rv[0], rv[1], 1.0, st["trim"])
            G.bar(-11, 6, 11, 6, 2.2, st["trim"])
    if st["motif"] == "volt":
        for cxx, cyy, a in ((34, 70, -8), (60, 76, 10)):
            G = L.Frame(ic, (cxx, cyy), a, 1.0)
            G.bar(-11, 15, 11, 15, 2.6, "hazard")
    elif st["motif"] == "surgeon":
        ic.ellipse(36, 44, 2.6, 2.0, "blood")
        ic.ellipse(64, 60, 2.0, 1.6, "blood")
    elif st["motif"] == "hivis":
        for cxx, cyy, a in ((34, 70, -8), (60, 76, 10)):
            G = L.Frame(ic, (cxx, cyy), a, 1.0)
            G.bar(-11, 4, 11, 4, 2.4, "reflect")
    ic.scratches(count=8)


def _combat_boot(ic, x, y, st, kind="boots", k=1.0):
    """Side-profile combat boot, toe to the left: tall laced shaft, padded
    collar, heel counter, rubber toe cap, lugged sole."""
    F = L.Frame(ic, (x, y), 0, k)
    lea = st["leather"]
    dark = tone(lea, 0.7, "bd")
    shaft = [(4, -56), (22, -56), (24, -18), (26, 0), (-28, 0), (-30, -8), (-22, -16), (-6, -20), (2, -30)]
    F.poly(shaft, lea, bevel=3.0, dome=0.85)
    F.poly([(2, -58), (24, -58), (24, -52), (2, -52)], tone(lea, 0.85, "col"), bevel=1.4, dome=0.8)
    # heel counter + toe cap
    F.poly([(10, -16), (26, -16), (26, 0), (8, 0)], dark, bevel=1.6)
    F.poly([(-30, -9), (-22, -16), (-12, -14), (-12, 0), (-28, 0)], "rubber" if kind != "striders" else dark, bevel=1.6, dome=0.9)
    # sole + lugs
    F.poly([(-31, -1), (28, -1), (28, 6), (-29, 6)], "rubber", bevel=1.2)
    for i in range(8):
        u = -26 + i * 7
        F.bar(u, 5, u, 8, 3.0, "rubber")
    F.bar(-31, 0.5, 28, 0.5, 0.8, tone("rubber", 1.6, "welt"))
    # lacing up the front of the shaft
    if kind == "striders":
        for v in (-48, -36, -24):
            F.bar(2, v, 22, v + 1, 3.0, dark)
            pt = F.P(18, v + 0.8)
            buckle(ic, pt[0], pt[1], 3.4 * k, 3.4 * k, st["trim"])
    else:
        for i in range(7):
            v = -52 + i * 6
            u = 4 - i * 0.6 if v < -28 else -2 - (v + 28) * 0.7
            F.ell(u, v, 0.9, 0.9, "steel")
            F.bar(u - 1, v, u + 5, v + 3, 0.7, "thread")
            F.bar(u - 1, v + 3, u + 5, v, 0.7, "thread")
    if kind == "treads":
        F.poly([(-2, -40), (22, -40), (23, -26), (-4, -26)], st["plate"], bevel=1.8)
        for u in (2, 18):
            p = F.P(u, -33)
            ic.rivet(p[0], p[1], 1.0)
    stitch(ic, [F.P(-26, -3), F.P(24, -3)], 1.4)
    return F


def s_boots(ic, st, kind="boots"):
    _combat_boot(ic, 60, 80, st, kind, 0.95)
    _combat_boot(ic, 44, 88, st, kind, 1.0)
    if st["motif"] == "flight":
        for (x, y, k) in ((60, 80, 0.95), (44, 88, 1.0)):
            F = L.Frame(ic, (x, y), 0, k)
            F.bar(3, -56, 23, -56, 4.0, "fur")
    elif st["motif"] == "volt":
        ic.bar((14, 92), (72, 92), 1.6, "hazard")
    ic.scratches(count=10)


def s_trousers(ic, st):
    d = st["dye"]
    fold = tone(d, 0.6, "tf")
    ridge = tone(d, 1.22, "tr")
    ic.poly([(24, 10), (72, 10), (76, 88), (56, 88), (48, 34), (40, 88), (20, 88)], d, bevel=3.6, dome=0.7)
    ic.bar((24, 13), (72, 13), 5.0, st["leather"])
    buckle(ic, 48, 13, 7, 6, st["trim"])
    for x in (30, 40, 56, 66):
        ic.bar((x, 10), (x, 17), 1.6, tone(d, 0.85, "loop"))
    for (x, y) in ((22, 44), (62, 44)):
        ic.poly([(x, y), (x + 12, y), (x + 12, y + 14), (x, y + 14)], d, bevel=1.4)
        ic.poly([(x - 0.5, y - 1), (x + 12.5, y - 1), (x + 12.5, y + 4), (x - 0.5, y + 4)], tone(d, 0.9, "flp"), bevel=1.0)
        stitch(ic, [(x + 1, y + 13), (x + 11, y + 13)], 1.2)
        ic.ellipse(x + 6, y + 2, 1.1, 1.1, st["trim"], dome=0.9)
    stitch(ic, [(44, 18), (40, 86)])
    stitch(ic, [(52, 18), (56, 86)])
    # knee wrinkles + reinforced knee patches
    for x in (30, 66):
        ic.poly([(x - 7, 62), (x + 7, 62), (x + 7, 74), (x - 7, 74)], tone(d, 0.85, "kn"), bevel=1.4)
        stitch(ic, [(x - 6, 63), (x + 6, 63), (x + 6, 73), (x - 6, 73), (x - 6, 63)], 1.3)
        for k in range(3):
            crease(ic, [(x - 9, 76 + k * 3), (x, 78 + k * 3), (x + 9, 76 + k * 3)], 0.6, fold)
    crease(ic, bez((26, 20), (28, 34), (24, 52), 6), 0.8, fold, ridge)
    crease(ic, bez((70, 20), (68, 34), (72, 52), 6), 0.8, fold, ridge)
    if st["motif"] == "cross":
        ic.bar((22, 84), (42, 84), 2.0, "gold")
        ic.bar((54, 84), (74, 84), 2.0, "gold")
    elif st["motif"] == "plague":
        ic.bar((22, 80), (42, 80), 3.0, st["leather"])
        ic.bar((54, 80), (74, 80), 3.0, st["leather"])
    ic.scratches(count=6)


def s_cratertreads(ic, st):
    s_boots(ic, st, "treads")
    for (x, y, k) in ((60, 80, 0.95), (44, 88, 1.0)):
        F = L.Frame(ic, (x, y), 0, k)
        F.poly([(-30, -12), (-10, -18), (-8, -4), (-30, -4)], "plate", bevel=1.6, dome=0.9)
        for u in (-24, -14):
            p = F.P(u, -9)
            ic.rivet(p[0], p[1], 0.9)
        F.bar(-28, 9, 26, 9, 2.4, "rubber")
    ic.ellipse(40, 66, 3, 2, "dust", dome=0.4)


def s_visor(ic, st):
    """Combat helmet with a smoked flip-down visor, 3/4 view: domed shell,
    visor hinge boss, rim trim, chin strap with buckle, NVG mount plate."""
    pl = st["plate"]
    shell = bez((14, 60), (10, 14), (52, 10), 14) + bez((52, 10), (90, 12), (88, 58), 14) + bez((88, 58), (86, 70), (76, 72), 4) + [(18, 72)]
    ic.poly(shell, pl, bevel=8.0, dome=0.95)
    # rim trim
    ic.bar((16, 70), (78, 72), 3.0, "rubber")
    ic.bar((78, 72), (88, 60), 3.0, "rubber")
    # visor: smoked glass band across the front-left, with a lit edge
    vis = bez((12, 44), (28, 34), (64, 38), 10) + bez((64, 38), (70, 52), (62, 66), 6) + bez((62, 66), (30, 64), (14, 66), 8)
    ic.poly(vis, tone("lens", 0.75, "smk") if st["lens"] == "lens" else st["lens"], bevel=2.4, dome=0.9)
    crease(ic, bez((16, 46), (30, 38), (60, 41), 8), 0.9, "frost")
    # hinge boss + pivot screw
    ic.ellipse(72, 50, 6.0, 6.0, tone(pl, 0.8, "hb"), dome=0.9)
    ic.ellipse(72, 50, 2.4, 2.4, "steel", dome=0.9)
    # NVG mount plate on the brow
    ic.poly([(40, 18), (56, 16), (57, 26), (41, 28)], "dark", bevel=1.2)
    rivets(ic, [(43, 21), (54, 19)], 0.8)
    # chin strap
    ic.bar((74, 70), (62, 90), 3.0, st["leather"])
    ic.bar((26, 72), (40, 90), 3.0, st["leather"])
    buckle(ic, 52, 90, 6, 4.6, "steel")
    ic.bar((40, 90), (62, 90), 3.0, st["leather"])
    if st["motif"] == "hazard":
        stripes(ic, 30, 22, 80, 30, 4.0, 8)
    ic.patch(78, 30, 7, 5, 0.3, "steel")
    ic.scratches(count=14)


def s_cap(ic, st):
    """Patrol cap, 3/4 view: rounded crown, curved stiff bill, button on top,
    goggles strapped round the band."""
    d = st["dye"]
    crown = bez((18, 64), (14, 20), (52, 16), 12) + bez((52, 16), (86, 16), (84, 60), 12) + [(18, 64)]
    ic.poly(crown, d, bevel=7.0, dome=0.9)
    for (a, b, c) in (((52, 17), (44, 40), (40, 62)), ((52, 17), (64, 40), (66, 62))):
        stitch(ic, bez(a, b, c, 8), 1.5)
    ic.ellipse(52, 17, 3.0, 2.0, tone(d, 0.9, "btn"), dome=0.9)
    # bill: curved, projecting forward-left, darker underside visible
    bill = bez((16, 62), (2, 70), (10, 80), 8) + bez((10, 80), (40, 86), (58, 70), 8) + [(40, 64)]
    ic.poly(bill, tone(d, 0.92, "bill"), bevel=3.0, dome=0.8)
    stitch(ic, bez((12, 76), (36, 82), (54, 70), 8), 1.3)
    ic.bar((16, 63), (84, 59), 3.4, tone(d, 0.75, "band"))
    # goggles on the band
    ic.bar((20, 54), (84, 50), 4.2, "rubber")
    for (cx, cy, rx) in ((34, 52, 9.0), (56, 50.5, 8.0)):
        ic.ellipse(cx, cy, rx, rx * 0.86, st["trim"], dome=0.9)
        ic.ellipse(cx, cy, rx * 0.72, rx * 0.62, st["lens"], dome=1.0)
        ic.bar((cx - rx * 0.45, cy - 2), (cx - rx * 0.15, cy - 3.6), 1.0, "frost")
    ic.bar((43, 51.5), (48, 51), 2.6, st["trim"])
    buckle(ic, 78, 50.5, 5, 5.4, "steel")
    if st["motif"] == "salvage":
        ic.patch(70, 32, 7, 5, 0.2, "steel")
    ic.scratches(count=8)


def s_mantle(ic, st):
    """Shoulder mantle / short cloak as worn, seen from the front: sloping
    shoulders, neck opening with a clasp, open front edge with lining, heavy
    vertical drape folds, uneven stitched hem."""
    d = st["dye"]
    fold = tone(d, 0.58, "mf")
    ridge = tone(d, 1.25, "mr")
    lin = tone(d, 1.32, "ml")
    hem = [(84, 84), (74, 88), (64, 84), (54, 90), (48, 86)]
    left = [(48, 86), (40, 90), (30, 85), (20, 89), (10, 83)]
    body = bez((40, 16), (20, 16), (10, 34), 8) + [(6, 50), (10, 83)] + left[::-1][1:] + hem[::-1] + [(84, 84), (90, 50)] + bez((86, 34), (76, 16), (56, 16), 8)
    ic.poly(body, d, bevel=6.0, dome=0.8)
    # lining at the open front
    ic.poly([(44, 26), (48, 30), (52, 26), (54, 88), (48, 86), (42, 88)], lin, bevel=1.6)
    ic.bar((48, 30), (48, 86), 1.6, tone(d, 0.5, "gap"))
    for (a, b, c) in (((20, 30), (16, 56), (18, 84)), ((32, 26), (30, 56), (32, 86)), ((64, 26), (66, 56), (64, 86)), ((76, 30), (80, 56), (78, 84))):
        crease(ic, bez(a, b, c, 7), 1.3, fold, ridge)
    stitch(ic, left + hem[1:], 1.6)
    # collar + clasp
    ic.poly(bez((36, 18), (48, 8), (60, 18), 8) + [(58, 26), (48, 30), (38, 26)], tone(d, 0.85, "col"), bevel=2.0, dome=0.8)
    ic.ellipse(48, 28, 3.8, 3.8, st["trim"], dome=0.95)
    ic.ellipse(48, 28, 1.6, 1.6, "dark", dome=0.2)
    if st["motif"] == "bell":
        ic.bar((48, 32), (48, 42), 0.9, "leather")
        ic.poly([(44, 42), (52, 42), (55, 52), (41, 52)], "brass", bevel=1.6)
    elif st["motif"] == "plague":
        ic.bar((10, 60), (86, 60), 1.4, "brass")
    ic.scratches(count=6)


def _shoulder_guard(ic, cx, st, flip, lames=2, spiked=False):
    pl = st["plate"]
    # leather strap the lames hang on
    ic.bar((cx, 40), (cx, 50 + lames * 9 + 4), 6.0, st["leather"])
    # lames under the cap (bottom first), each tucked under the one above
    for k in range(lames, 0, -1):
        y = 44 + k * 9
        w = 18 - k * 1.2
        lame = bez((cx - w, y - 5), (cx, y + 1), (cx + w, y - 5), 8) + bez((cx + w, y + 4), (cx, y + 10), (cx - w, y + 4), 8)
        ic.poly(lame, pl, bevel=2.4, dome=0.9)
        rivets(ic, [(cx - w + 4, y), (cx + w - 4, y)], 0.9, st["trim"])
    # domed cap: a quarter-sphere sitting on the shoulder
    # asymmetric: the high point sits toward the neck (inner side), the
    # outer edge flares down over the arm
    hi = cx + 8 * flip
    cap = bez((cx - 19, 52 + 4 * flip), (cx - 20, 22), (hi, 16), 10) + bez((hi, 16), (cx + 20, 22), (cx + 19, 52 - 4 * flip), 10) + bez((cx + 19, 52 - 4 * flip), (cx, 44), (cx - 19, 52 + 4 * flip), 8)
    ic.poly(cap, pl, bevel=6.0, dome=0.95)
    crease(ic, bez((cx - 18, 48), (cx, 40), (cx + 18, 46), 8), 0.9, tone(pl, 0.6, "pf"), tone(pl, 1.3, "ph"))
    rivets(ic, [(cx - 14, 40), (cx + 14, 38), (cx, 22)], 1.1)
    if spiked:
        for dx in (-10, 0, 10):
            ic.bar((cx + dx, 22), (cx + dx + 2 * flip, 4), 4.0, "steel", w1=0.6, prof="cyl")


def s_pauldrons(ic, st, spiked=False):
    """A pair of pauldrons joined by a leather yoke strap across the chest."""
    ic.bar((20, 30), (76, 30), 4.4, st["leather"])
    buckle(ic, 48, 30, 7, 6, st["trim"])
    _shoulder_guard(ic, 22, st, -1, 2, spiked)
    _shoulder_guard(ic, 74, st, 1, 2, spiked)
    if st["motif"] == "hazard":
        stripes(ic, 8, 64, 38, 66, 3.2, 6)
    elif st["motif"] == "stone":
        ic.ellipse(22, 34, 3, 2.4, "ash", dome=0.5)
    ic.weld((60, 26), (68, 22), 0.8)
    ic.scratches(count=14)


def s_spaulders(ic, st):
    """Layered spaulders: a pair of laminated shoulder guards, four narrow
    lames each on riveted leather straps, no yoke."""
    for cx, flip in ((22, -1), (74, 1)):
        ic.bar((cx, 14), (cx, 86), 5.0, st["leather"])
        _shoulder_guard(ic, cx, dict(st), flip, 4)
        rivets(ic, [(cx, 60), (cx, 70), (cx, 80)], 1.0, st["trim"])
    if st["motif"] == "salvage":
        ic.patch(70, 30, 7, 5, 0.1, "brass")
    ic.scratches(count=12)


def _greave(ic, cx, st):
    pl = st["plate"]
    ic.poly([(cx - 10, 26), (cx + 10, 26), (cx + 12, 46), (cx + 9, 80), (cx - 9, 80), (cx - 12, 46)], pl, bevel=4.0, dome=0.95)
    ic.bar((cx, 28), (cx, 78), 2.0, tone(pl, 1.3, "gr"), prof="cyl")
    # knee cop with a side wing
    ic.ellipse(cx, 20, 11, 9, pl, dome=1.0)
    ic.poly([(cx + 8, 16), (cx + 16, 12), (cx + 16, 26), (cx + 8, 24)], pl, bevel=1.6)
    ic.bar((cx - 10, 20), (cx + 10, 20), 0.9, tone(pl, 0.6, "kc"))
    for y in (36, 66):
        strap(ic, (cx - 13, y), (cx + 13, y), 3.6, st, buck=0.75)
    ic.poly([(cx - 9, 80), (cx + 9, 80), (cx + 11, 88), (cx - 11, 88)], pl, bevel=1.6)
    rivets(ic, [(cx - 6, 84), (cx + 6, 84)], 0.9)


def s_greaves(ic, st):
    _greave(ic, 30, st)
    _greave(ic, 64, st)
    if st["motif"] == "hazard":
        stripes(ic, 54, 50, 74, 50, 3.6, 4)
    elif st["motif"] == "stone":
        ic.ellipse(28, 56, 2.6, 2.0, "ash", dome=0.5)
    ic.scratches(count=14)


def s_hardhat(ic, st):
    """Construction hard hat, 3/4 view: tall dome with a raised centre ridge,
    short peaked brim at the front, narrow rim round the sides, suspension
    strap inside, reflective band, scuffs."""
    pl = st["plate"]
    dome = bez((14, 70), (10, 18), (50, 14), 14) + bez((50, 14), (86, 14), (86, 66), 14) + [(14, 70)]
    ic.poly(dome, pl, bevel=8.0, dome=0.95)
    # raised ridge running front to back
    crease(ic, bez((40, 16), (32, 40), (30, 66), 10), 1.6, tone(pl, 0.6, "hr"), tone(pl, 1.3, "hh"))
    crease(ic, bez((58, 15), (62, 40), (64, 64), 10), 1.0, tone(pl, 0.7, "hr2"))
    # peaked front brim + narrow side rim
    brim = bez((6, 70), (2, 80), (20, 84), 8) + bez((20, 84), (60, 86), (90, 70), 10) + [(86, 64), (14, 68)]
    ic.poly(brim, tone(pl, 0.92, "brim"), bevel=2.0, dome=0.8)
    ic.bar((10, 70), (88, 66), 1.2, tone(pl, 0.55, "rimsh"))
    # reflective band + inner suspension strap glimpse
    ic.bar((20, 58), (84, 54), 3.4, "reflect")
    ic.bar((24, 80), (60, 82), 2.0, "rubber")
    ic.poly([(70, 30), (80, 28), (82, 38), (72, 40)], "reflect", bevel=0.8)
    ic.scratches(count=18)


def s_plate(ic, st):
    """Steel cuirass: rolled neck guard, concave arm openings, centre ridge,
    riveted fauld lames at the waist, shoulder straps with buckles."""
    pl = st["plate"]
    body = bez((24, 18), (34, 22), (40, 22), 4) + [(56, 22)] + bez((56, 22), (62, 22), (72, 18), 4) + bez((72, 18), (58, 34), (80, 46), 8) + [(74, 70), (22, 70)] + bez((16, 46), (38, 34), (24, 18), 8)
    ic.poly(body, pl, bevel=7.0, dome=0.95)
    crease(ic, bez((48, 24), (46, 46), (48, 68), 8), 1.4, tone(pl, 0.6, "cr"), tone(pl, 1.35, "ch"))
    # rolled neck guard
    for (a, b) in zip(bez((34, 22), (48, 30), (62, 22), 8)[:-1], bez((34, 22), (48, 30), (62, 22), 8)[1:]):
        ic.bar(a, b, 3.0, tone(pl, 1.1, "roll"), prof="cyl")
    # arm-opening rolled edges
    for side in (-1, 1):
        pts = bez((48 + side * 24, 18), (48 + side * 10, 34), (48 + side * 32, 46), 8)
        for (a, b) in zip(pts[:-1], pts[1:]):
            ic.bar(a, b, 2.4, tone(pl, 1.1, "roll"), prof="cyl")
    # fauld lames
    for k in range(3):
        y = 70 + k * 7
        ic.poly([(20 + k, y), (76 - k, y), (74 - k, y + 8), (22 + k, y + 8)], pl, bevel=2.0, dome=0.9)
        rivets(ic, [(26 + k, y + 4), (70 - k, y + 4)], 0.9)
    # shoulder straps
    strap(ic, (26, 6), (28, 22), 4.0, st, buck=0.4)
    strap(ic, (70, 6), (68, 22), 4.0, st, buck=0.4)
    ic.weld((30, 50), (40, 54), 1.0)
    ic.patch(62, 40, 10, 8, 0.15, "steel")
    if st["motif"] == "hazard":
        stripes(ic, 24, 64, 72, 64, 5.0, 9)
    elif st["motif"] == "stone":
        for (x, y, r) in ((32, 36, 3), (62, 58, 2.4)):
            ic.ellipse(x, y, r, r * 0.8, "ash", dome=0.5)
    ic.scratches(count=18)


def s_bottlecap(ic, st):
    """Lucky bottle cap on a cord: crimped crown cap (21 flutes), printed star
    logo, worn paint, punched hole with the cord knotted through."""
    ic.bar((48, 4), (48, 22), 1.4, "thread", prof="cyl")
    ic.bar((48, 4), (36, 2), 1.4, "thread", prof="cyl")
    ic.ellipse(48, 22, 2.2, 1.6, "thread")
    pts = []
    for k in range(42):
        a = k / 42 * math.tau
        r = 25 if k % 2 else 21.5
        pts.append((48 + math.cos(a) * r, 54 + math.sin(a) * r))
    ic.poly(pts, "steel", bevel=3.0, dome=0.9)
    ic.ellipse(48, 54, 19, 19, "red", dome=0.5)
    star = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 12 if k % 2 == 0 else 5
        star.append((48 + math.cos(a) * r, 54 + math.sin(a) * r))
    ic.poly(star, "reflect", bevel=1.0)
    ic.ellipse(48, 33, 2.4, 2.4, "dark", dome=-0.3)
    ic.scratches(count=12)


def s_rabbit(ic, st):
    """Rabbit's-foot keychain: split ring + bead chain, crimped cap, then a
    fluffy hind foot in an L: short furry ankle dropping from the cap, long
    foot turning out to the side with rounded toes and tiny claws."""
    fur = "fur"
    sh = tone(fur, 0.7, "fs")
    ic.ellipse(28, 12, 8, 8, "steel", dome=0.9)
    ic.ellipse(28, 12, 5.6, 5.6, "dark", dome=-0.2)
    for k in range(4):
        ic.ellipse(32 + k * 3.0, 18 + k * 3.0, 1.4, 1.4, "steel", dome=0.9)
    ic.poly([(38, 28), (50, 28), (52, 36), (36, 36)], "brass", bevel=1.4, dome=0.9)
    for x in range(37, 52, 3):
        ic.bar((x, 29), (x, 35), 0.5, "dark")
    # L-shaped foot with a bumpy fur outline
    out = [(36, 36), (52, 36), (56, 52), (56, 64), (66, 64), (78, 66), (86, 70), (88, 78), (84, 84), (70, 86), (52, 86), (40, 84), (32, 76), (34, 60), (32, 48)]
    bumpy = []
    for (a1, b1) in zip(out, out[1:] + out[:1]):
        bumpy.append(a1)
        mx, my = (a1[0] + b1[0]) / 2, (a1[1] + b1[1]) / 2
        cx, cy = 58, 66
        dx, dy = mx - cx, my - cy
        n = max(1e-3, math.hypot(dx, dy))
        bumpy.append((mx + dx / n * 2.2, my + dy / n * 2.2))
    ic.poly(bumpy, fur, bevel=7.0, dome=0.9)
    # soft fur shading: underside darker, short strands
    crease(ic, bez((36, 78), (56, 84), (82, 80), 8), 1.6, sh)
    for (x, y) in ((40, 50), (44, 62), (60, 72), (72, 74)):
        ic.bar((x, y), (x + 3, y + 5), 0.7, sh)
    # toes + claws at the front of the foot
    for (x, y) in ((84, 72), (88, 78), (84, 83)):
        ic.ellipse(x, y, 3.6, 3.0, fur, dome=0.9)
        ic.bar((x + 3, y), (x + 6.5, y + 1.2), 1.2, "dark", w1=0.4, prof="cyl")
    ic.scratches(count=3)


SHAPES = {k[2:]: v for k, v in globals().items() if k.startswith("s_")}


# ------------------------------------------------------------------- driver
def paint(shape, st, seed):
    ic = L.Icon(seed)
    SHAPES[shape](ic, st)
    ic.save(shape)
    return L.RESULT


def build(shape, st, seed, mode):
    L.MODE = mode
    L.KIND = "base"
    n = {"hd": 96, "s48": 48, "s24": 24}[mode]
    key = (shape, seed)
    if key not in _FITS:
        L.FIT_SET, L.OFF = 1.0, (0.0, 0.0)
        paint(shape, st, seed)
        x0, y0, x1, y1 = L._bbox_units(L.RESULT[0])
        _FITS[key] = ((L.N / 2 - (x0 + x1) / 2, L.N / 2 - (y0 + y1) / 2), max(x1 - x0, y1 - y0))
    L.OFF, span = _FITS[key]
    L.FIT_SET = {"hd": 82.0, "s48": 90.0, "s24": 92.0}[mode] / span
    while True:
        ic, halo, glows = paint(shape, st, seed)
        arr = ic._render(n, None, glows)
        if mode == "hd" or L._margin(arr) >= 1 or L.FIT_SET < 0.5:
            return arr
        L.FIT_SET *= 0.97


_FITS = {}


def jobs():
    out = []
    for slot, shapes in NOUN_SHAPES.items():
        for i, sh in enumerate(shapes):
            out.append(("gear_%s_%d" % (slot, i), sh, GENERIC, 100 + len(out), slot if i == 0 else None))
    for sid in GENERAL_SETS:
        for slot in ARMOR:
            out.append(("gset_%s_%s" % (sid, slot), SET_SHAPE[sid][slot], dict(GENERIC, **STYLES[sid]), 300 + len(out), None))
    for sid, slots in HERO_SETS.items():
        for slot in slots:
            out.append(("gset_%s_%s" % (sid, slot), SET_SHAPE[sid][slot], dict(GENERIC, **STYLES[sid]), 300 + len(out), None))
    for tid, (slot, sh) in TLEG.items():
        out.append(("tleg_%s" % tid, sh, TLEG_STYLE[tid], 500 + len(out), None))
    return out


def run(job):
    name, shape, st, seed, hd_slot = job
    for mode in ("s48", "s24"):
        L.Image.fromarray(build(shape, st, seed, mode), "RGBA").save(os.path.join(SET, mode[1:], name + ".png"))
    if hd_slot:
        fn = ("icon_acc_%s.png" if hd_slot in ("charm", "vial", "patch") else "icon_slot_%s.png") % hd_slot
        L.Image.fromarray(build(shape, st, seed, "hd"), "RGBA").save(os.path.join(GEAR96, fn))
    return name


if __name__ == "__main__":
    import multiprocessing as mp
    only = sys.argv[1:]
    js = [j for j in jobs() if not only or any(o in j[0] for o in only)]
    with mp.Pool(min(4, os.cpu_count() or 1)) as pool:
        for nm in pool.imap_unordered(run, js):
            print("ok", nm)
