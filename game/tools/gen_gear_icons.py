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
def s_hood(ic, st):
    out = [(48, 8), (66, 14), (76, 32), (78, 62), (70, 86), (26, 86), (18, 62), (20, 32), (30, 14)]
    ic.poly(out, st["dye"], bevel=5.0, dome=0.8)
    ic.ellipse(48, 52, 18, 22, st["dye"], dome=-0.6)
    ic.ellipse(48, 54, 14, 18, "rubber", dome=0.1)
    ic.bar((40, 74), (38, 88), 1.2, "thread")
    ic.bar((56, 74), (58, 88), 1.2, "thread")
    stitch(ic, [(31, 18), (48, 12), (65, 18)])
    stitch(ic, [(24, 64), (29, 82)])
    stitch(ic, [(72, 64), (67, 82)])
    ic.bar((34, 80), (62, 80), 3.4, st["leather"])
    if st["motif"] == "bell":
        ic.bar((48, 80), (48, 86), 0.9, "leather")
        ic.poly([(45, 85), (51, 85), (53, 92), (43, 92)], "brass", bevel=1.4)
    elif st["motif"] == "cross":
        ic.bar((48, 14), (48, 28), 2.8, "gold")
        ic.bar((43, 18), (53, 18), 2.8, "gold")
    elif st["motif"] == "night":
        ic.ellipse(42, 46, 2.4, 1.6, "arc")
        ic.ellipse(54, 46, 2.4, 1.6, "arc")
    ic.scratches(count=10)


def s_visor(ic, st):
    ic.poly([(18, 56), (20, 30), (34, 14), (62, 14), (76, 30), (78, 56), (72, 70), (24, 70)], st["plate"], bevel=4.0, dome=0.9)
    ic.poly([(24, 40), (72, 40), (70, 56), (26, 56)], "dark", bevel=1.2)
    ic.poly([(27, 42.5), (69, 42.5), (67.5, 53.5), (28.5, 53.5)], st["lens"], bevel=1.4)
    ic.bar((30, 45), (44, 45), 1.2, "frost")
    ic.bar((16, 48), (24, 48), 5.0, st["leather"])
    ic.bar((72, 48), (80, 48), 5.0, st["leather"])
    rivets(ic, [(22, 48), (74, 48), (30, 22), (66, 22), (48, 16)], 1.3)
    ic.bar((48, 14), (48, 38), 3.0, "steel", prof="cyl")
    ic.bar((20, 70), (76, 70), 3.2, "rubber")
    if st["motif"] == "hazard":
        stripes(ic, 28, 30, 68, 30, 4.4, 8)
    ic.patch(64, 62, 8, 5, 0.1, "steel")
    ic.scratches(count=14)


def s_cap(ic, st):
    ic.poly([(20, 56), (22, 36), (34, 22), (62, 22), (74, 36), (76, 56)], st["dye"], bevel=6.0, dome=0.9)
    ic.poly([(14, 56), (82, 56), (86, 64), (10, 64)], st["dye"], bevel=1.8)
    stitch(ic, [(48, 23), (48, 55)])
    stitch(ic, [(22, 52), (74, 52)])
    ic.ellipse(48, 23, 2.4, 1.6, st["dye"])
    # goggles on the brow
    ic.bar((18, 44), (78, 44), 4.4, st["leather"])
    for cx in (37, 59):
        ic.ellipse(cx, 42, 8.5, 7.5, st["trim"], dome=0.9)
        ic.ellipse(cx, 42, 6.2, 5.4, st["lens"], dome=1.0)
        ic.bar((cx - 4, 39), (cx - 1, 37), 1.0, "frost")
    ic.bar((45, 42), (51, 42), 2.4, st["trim"])
    if st["motif"] == "salvage":
        ic.patch(66, 30, 7, 5, 0.2, "steel")
    ic.scratches(count=10)


def s_beak(ic, st):
    # plague doctor beak mask: leather hood, brass-rimmed glass eyes, long beak
    ic.poly([(22, 30), (36, 12), (60, 12), (74, 30), (74, 64), (60, 80), (36, 80), (22, 64)], st["leather"], bevel=5.0, dome=0.8)
    ic.poly([(40, 46), (56, 46), (90, 80), (84, 86), (60, 70), (44, 64)], st["leather"], bevel=3.0, dome=0.8)
    stitch(ic, [(48, 50), (86, 82)], 1.8)
    for cx in (37, 59):
        ic.ellipse(cx, 38, 8, 8, "brass", dome=0.9)
        ic.ellipse(cx, 38, 5.6, 5.6, "glass", dome=1.0)
    ic.bar((24, 52), (34, 66), 3.2, "brass")
    rivets(ic, [(30, 22), (66, 22), (48, 14)], 1.1, "brass")
    stitch(ic, [(36, 14), (48, 10), (60, 14)])


def s_hardhat(ic, st):
    ic.ellipse(48, 50, 30, 26, st["plate"], dome=1.0)
    ic.poly([(10, 54), (86, 54), (88, 62), (8, 62)], st["plate"], bevel=1.8)
    ic.bar((48, 24), (48, 54), 5.0, st["plate"], prof="cyl")
    ic.bar((20, 52), (76, 52), 3.0, "reflect")
    ic.ellipse(48, 40, 7, 5, "dark", dome=0.2)
    ic.ellipse(48, 40, 5, 3.4, "ember", dome=0.6)
    rivets(ic, [(24, 46), (72, 46)], 1.2)
    ic.scratches(count=16)


def s_surgcap(ic, st):
    ic.poly([(20, 44), (24, 26), (36, 16), (60, 16), (72, 26), (76, 44)], st["dye"], bevel=6.0, dome=0.9)
    stitch(ic, [(22, 42), (74, 42)])
    # surgical mask with filter + head mirror
    ic.poly([(26, 52), (70, 52), (66, 74), (48, 80), (30, 74)], st["dye"], bevel=3.0)
    for yy in (58, 64, 70):
        ic.bar((30, yy), (66, yy), 0.6, "dark")
    ic.bar((18, 54), (28, 56), 1.2, "thread")
    ic.bar((68, 56), (78, 54), 1.2, "thread")
    ic.ellipse(48, 30, 8, 8, "steel", dome=0.9)
    ic.ellipse(48, 30, 5.4, 5.4, "glassc", dome=1.0)
    ic.ellipse(61, 70, 3.2, 3.2, "blood")


def s_aviator(ic, st):
    ic.poly([(18, 60), (20, 34), (34, 16), (62, 16), (76, 34), (78, 60), (68, 66), (28, 66)], st["leather"], bevel=5.0, dome=0.9)
    ic.poly([(14, 52), (24, 52), (26, 82), (16, 82)], st["leather"], bevel=2.0)
    ic.poly([(72, 52), (82, 52), (80, 82), (70, 82)], st["leather"], bevel=2.0)
    ic.bar((16, 64), (24, 64), 3.0, "fur")
    ic.bar((72, 64), (80, 64), 3.0, "fur")
    stitch(ic, [(48, 18), (48, 40)])
    stitch(ic, [(24, 56), (72, 56)])
    ic.bar((16, 40), (80, 40), 4.4, "rubber")
    for cx in (37, 59):
        ic.ellipse(cx, 40, 9, 8, "steel", dome=0.9)
        ic.ellipse(cx, 40, 6.6, 5.8, st["lens"], dome=1.0)
        ic.bar((cx - 4, 37), (cx - 1, 35), 1.0, "frost")
    buckle(ic, 21, 76, 4, 4, "steel")


def s_gasmask(ic, st):
    # refinery gas mask: rubber face piece, twin canisters, two glass lenses, valve
    ic.poly([(24, 28), (36, 14), (60, 14), (72, 28), (74, 56), (62, 74), (34, 74), (22, 56)], "rubber", bevel=5.0, dome=0.9)
    for cx in (36, 60):
        ic.ellipse(cx, 36, 9.5, 9, "steel", dome=0.9)
        ic.ellipse(cx, 36, 7, 6.6, "glass", dome=1.0)
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


def s_vest(ic, st):
    body = [(26, 14), (38, 14), (42, 24), (54, 24), (58, 14), (70, 14), (78, 30), (78, 84), (18, 84), (18, 30)]
    ic.poly(body, st["dye"], bevel=4.0, dome=0.7)
    stitch(ic, [(22, 32), (36, 18)])
    stitch(ic, mirror([(22, 32), (36, 18)]))
    ic.bar((48, 26), (48, 84), 1.6, "dark")
    # pouches with flaps + snaps
    for (x, y) in ((22, 54), (35, 54), (52, 54), (65, 54)):
        ic.poly([(x, y), (x + 10, y), (x + 10, y + 16), (x, y + 16)], st["dye"], bevel=1.6)
        ic.poly([(x - 0.5, y - 1), (x + 10.5, y - 1), (x + 10.5, y + 5), (x - 0.5, y + 5)], st["leather"], bevel=1.0)
        ic.ellipse(x + 5, y + 3, 1.2, 1.2, st["trim"], dome=0.9)
        stitch(ic, [(x + 1, y + 15), (x + 9, y + 15)], 1.2)
    strap(ic, (18, 44), (78, 44), 4.0, st, buck=0.5)
    if st["motif"] == "hivis":
        ic.bar((19, 76), (77, 76), 3.6, "reflect")
        ic.bar((30, 16), (30, 84), 3.0, "reflect")
        ic.bar((66, 16), (66, 84), 3.0, "reflect")
    elif st["motif"] == "volt":
        ic.bar((24, 30), (40, 40), 2.4, "copper", prof="cyl")
        ic.bar((40, 40), (40, 52), 2.4, "copper", prof="cyl")
        ic.ellipse(72, 34, 4, 4, "rubber")
        ic.ellipse(72, 34, 2, 2, "arc")
    elif st["motif"] == "salvage":
        ic.bar((24, 30), (72, 30), 2.2, "brass")
        for x in (28, 36, 60, 68):
            ic.bar((x, 26), (x, 34), 1.4, "steel", prof="cyl")
    elif st["motif"] == "night":
        ic.bar((22, 70), (74, 70), 2.0, "dark")
    ic.scratches(count=10)


def s_coat(ic, st):
    body = [(30, 10), (44, 18), (52, 18), (66, 10), (78, 22), (82, 90), (54, 90), (48, 40), (42, 90), (14, 90), (18, 22)]
    ic.poly(body, st["dye"], bevel=4.0, dome=0.7)
    # lapels / collar
    ic.poly([(30, 10), (44, 18), (46, 40), (36, 34), (26, 18)], st["dye"], bevel=2.0)
    ic.poly(mirror([(30, 10), (44, 18), (46, 40), (36, 34), (26, 18)]), st["dye"], bevel=2.0)
    if st["motif"] == "flight":
        ic.poly([(26, 12), (40, 16), (40, 26), (24, 22)], "fur", bevel=2.0)
        ic.poly(mirror([(26, 12), (40, 16), (40, 26), (24, 22)]), "fur", bevel=2.0)
        ic.bar((48, 30), (48, 86), 1.4, "steel")
    for y in (46, 58, 70):
        ic.ellipse(42, y, 1.8, 1.8, st["trim"], dome=0.9)
        ic.ellipse(54, y, 1.8, 1.8, st["trim"], dome=0.9)
    stitch(ic, [(18, 26), (16, 88)])
    stitch(ic, [(78, 26), (80, 88)])
    ic.poly([(20, 62), (34, 62), (34, 74), (20, 74)], st["dye"], bevel=1.4)
    stitch(ic, [(21, 63), (33, 63)], 1.2)
    ic.bar((20, 50), (76, 50), 3.6, st["leather"])
    buckle(ic, 48, 50, 6, 5, st["trim"])
    if st["motif"] == "cross":
        ic.bar((48, 58), (48, 84), 4.0, "gold")
        ic.bar((40, 66), (56, 66), 4.0, "gold")
        stitch(ic, [(14, 88), (82, 88)])
    elif st["motif"] == "surgeon":
        ic.ellipse(64, 72, 4, 3, "blood")
        ic.ellipse(60, 80, 2.4, 2, "blood")
        ic.poly([(58, 26), (66, 26), (66, 34), (58, 34)], "reflect", bevel=0.6)
        ic.bar((62, 27), (62, 33), 1.6, "blood")
        ic.bar((59, 30), (65, 30), 1.6, "blood")
    elif st["motif"] == "plague":
        ic.bar((22, 80), (76, 80), 2.0, "dark")
    ic.scratches(count=10)


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


def s_plate(ic, st):
    body = [(24, 14), (40, 18), (56, 18), (72, 14), (80, 30), (76, 66), (62, 84), (34, 84), (20, 66), (16, 30)]
    ic.poly(body, st["plate"], bevel=6.0, dome=0.95)
    ic.bar((48, 20), (48, 82), 3.0, st["plate"], prof="cyl")
    ic.poly([(30, 62), (66, 62), (60, 82), (36, 82)], st["plate"], bevel=3.0)
    rivets(ic, [(24, 24), (72, 24), (20, 44), (76, 44), (24, 62), (72, 62), (36, 78), (60, 78)], 1.3)
    strap(ic, (14, 36), (24, 32), 4.0, st)
    strap(ic, (72, 32), (82, 36), 4.0, st)
    ic.weld((26, 50), (40, 52), 1.0)
    ic.patch(60, 40, 10, 8, 0.15, "steel")
    if st["motif"] == "hazard":
        stripes(ic, 28, 70, 68, 70, 5.0, 8)
    elif st["motif"] == "stone":
        for (x, y, r) in ((30, 34, 3), (62, 56, 2.4), (40, 70, 2.0)):
            ic.ellipse(x, y, r, r * 0.8, "ash", dome=0.5)
        ic.bar((22, 50), (34, 56), 1.0, "dark")
    ic.scratches(count=20)


def _pauldron(ic, cx, st, spiked=False, flip=1):
    cy = 40
    pts = [(cx - 18 * flip, cy + 16), (cx - 16 * flip, cy - 6), (cx - 4 * flip, cy - 16), (cx + 12 * flip, cy - 12), (cx + 18 * flip, cy + 6), (cx + 14 * flip, cy + 20)]
    ic.poly(pts, st["plate"], bevel=5.0, dome=0.95)
    for k in range(2):
        yy = cy + 20 + k * 8
        ic.poly([(cx - 16 * flip, yy), (cx + 14 * flip, yy - 2), (cx + 12 * flip, yy + 6), (cx - 14 * flip, yy + 8)], st["plate"], bevel=2.4)
        rivets(ic, [(cx - 10 * flip, yy + 3), (cx + 8 * flip, yy + 2)], 0.9)
    ic.bar((cx - 14 * flip, cy + 2), (cx + 12 * flip, cy - 2), 3.0, st["leather"])
    rivets(ic, [(cx - 6 * flip, cy - 8), (cx + 8 * flip, cy - 4)], 1.2, st["trim"])
    if spiked:
        for (dx, dy) in ((-8, -14), (2, -18), (12, -12)):
            ic.bar((cx + dx * flip, cy + dy + 4), (cx + (dx + 2) * flip, cy + dy - 8), 4.0, "steel", w1=0.6, prof="cyl")


def s_pauldrons(ic, st, spiked=False):
    _pauldron(ic, 30, st, spiked, 1)
    _pauldron(ic, 66, st, spiked, -1)
    if st["motif"] == "hazard":
        stripes(ic, 18, 56, 40, 54, 3.2, 5)
    elif st["motif"] == "stone":
        ic.ellipse(28, 36, 3, 2.4, "ash", dome=0.5)
    ic.scratches(count=16)


def s_spiked(ic, st):
    s_pauldrons(ic, st, spiked=True)
    ic.bar((20, 44), (76, 44), 2.0, "leather")
    for x in (34, 62):
        ic.bar((x, 44), (x + 2, 60), 3.0, "cloth", w1=1.6)


def s_mantle(ic, st):
    ic.poly([(48, 14), (70, 20), (86, 44), (80, 76), (60, 70), (48, 84), (36, 70), (16, 76), (10, 44), (26, 20)], st["dye"], bevel=6.0, dome=0.8)
    ic.ellipse(48, 22, 12, 7, "dark", dome=0.2)
    for x in (24, 36, 60, 72):
        ic.bar((x, 30), (x - (48 - x) * 0.1, 72), 1.0, "dark")
    stitch(ic, [(16, 74), (36, 68), (48, 82), (60, 68), (80, 74)])
    ic.ellipse(48, 30, 4.5, 4.5, st["trim"], dome=0.95)
    ic.bar((40, 30), (56, 30), 1.4, st["trim"])
    if st["motif"] == "bell":
        ic.bar((48, 34), (48, 44), 0.9, "leather")
        ic.poly([(44, 44), (52, 44), (55, 54), (41, 54)], "brass", bevel=1.6)
    elif st["motif"] == "plague":
        ic.bar((26, 40), (70, 40), 1.4, "brass")
    ic.scratches(count=8)


def s_spaulders(ic, st):
    for k in range(4):
        y = 22 + k * 13
        w = 36 - k * 3
        ic.poly([(48 - w, y + 6), (48 - w + 4, y - 4), (48 + w - 4, y - 4), (48 + w, y + 6), (48 + w - 2, y + 12), (48 - w + 2, y + 12)], st["plate"], bevel=3.0)
        rivets(ic, [(48 - w + 6, y + 4), (48 + w - 6, y + 4)], 1.0)
    ic.bar((48, 16), (48, 72), 4.0, st["leather"])
    buckle(ic, 48, 26, 6, 5, st["trim"])
    if st["motif"] == "salvage":
        ic.patch(30, 50, 7, 5, 0.1, "brass")
    ic.scratches(count=16)


def _greave(ic, cx, st):
    ic.poly([(cx - 10, 12), (cx + 10, 12), (cx + 12, 40), (cx + 9, 76), (cx - 9, 76), (cx - 12, 40)], st["plate"], bevel=4.0, dome=0.95)
    ic.ellipse(cx, 38, 9, 8, st["plate"], dome=1.0)
    ic.bar((cx, 14), (cx, 74), 2.0, st["plate"], prof="cyl")
    for y in (24, 60):
        strap(ic, (cx - 13, y), (cx + 13, y), 3.6, st, buck=0.75)
    rivets(ic, [(cx - 7, 32), (cx + 7, 32), (cx - 7, 46), (cx + 7, 46)], 0.9)
    ic.poly([(cx - 9, 76), (cx + 9, 76), (cx + 11, 84), (cx - 11, 84)], st["plate"], bevel=1.6)


def s_greaves(ic, st):
    _greave(ic, 32, st)
    _greave(ic, 64, st)
    if st["motif"] == "hazard":
        stripes(ic, 56, 68, 72, 68, 3.6, 4)
    elif st["motif"] == "stone":
        ic.ellipse(30, 66, 2.6, 2.0, "ash", dome=0.5)
    ic.scratches(count=16)


def s_trousers(ic, st):
    ic.poly([(24, 10), (72, 10), (76, 88), (56, 88), (48, 34), (40, 88), (20, 88)], st["dye"], bevel=3.6, dome=0.7)
    ic.bar((24, 13), (72, 13), 5.0, st["leather"])
    buckle(ic, 48, 13, 7, 6, st["trim"])
    for x in (30, 40, 56, 66):
        ic.bar((x, 10), (x, 17), 1.6, st["dye"])
    # cargo pockets + knee pads
    for (x, y) in ((22, 46), (62, 46)):
        ic.poly([(x, y), (x + 12, y), (x + 12, y + 14), (x, y + 14)], st["dye"], bevel=1.4)
        ic.poly([(x - 0.5, y - 1), (x + 12.5, y - 1), (x + 12.5, y + 4), (x - 0.5, y + 4)], st["dye"], bevel=1.0)
        stitch(ic, [(x + 1, y + 13), (x + 11, y + 13)], 1.2)
        ic.ellipse(x + 6, y + 2, 1.1, 1.1, st["trim"], dome=0.9)
    stitch(ic, [(44, 18), (40, 86)])
    stitch(ic, [(52, 18), (56, 86)])
    for x in (30, 66):
        ic.ellipse(x, 70, 7, 6, "pad" if st["motif"] != "cross" else st["dye"], dome=0.8)
    if st["motif"] == "cross":
        ic.bar((22, 84), (42, 84), 2.0, "gold")
        ic.bar((54, 84), (74, 84), 2.0, "gold")
    elif st["motif"] == "plague":
        ic.bar((22, 78), (42, 78), 3.0, st["leather"])
        ic.bar((54, 78), (74, 78), 3.0, st["leather"])
    ic.scratches(count=8)


def s_leggings(ic, st):
    for cx in (34, 62):
        ic.poly([(cx - 11, 10), (cx + 11, 10), (cx + 10, 84), (cx - 10, 84)], st["dye"], bevel=4.0, dome=0.8)
        for k in range(9):
            y = 16 + k * 7.5
            ic.bar((cx - 11, y + 1.5), (cx + 11, y - 1.5), 1.0, "dark")
        ic.bar((cx - 10, 84), (cx + 10, 84), 3.0, st["leather"])
    if st["motif"] == "bell":
        ic.poly([(44, 18), (52, 18), (54, 26), (42, 26)], "brass", bevel=1.4)
    elif st["motif"] == "wrap":
        for (x, y) in ((30, 40), (60, 58)):
            ic.ellipse(x, y, 3.0, 3.0, "brass", dome=0.9)
    ic.scratches(count=6)


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


def s_gloves(ic, st, gaunt=False):
    _glove(ic, 32, st, flip=1, gaunt=gaunt)
    _glove(ic, 64, st, flip=-1, gaunt=gaunt)
    if st["motif"] == "volt":
        for cx in (32, 64):
            ic.bar((cx - 12, 82), (cx + 12, 82), 2.0, "rubber")
            ic.bar((cx - 6, 54), (cx + 6, 54), 1.6, "copper", prof="cyl")
    elif st["motif"] == "surgeon":
        ic.ellipse(36, 40, 2.6, 2.0, "blood")
        ic.ellipse(68, 58, 2.0, 1.6, "blood")
    elif st["motif"] == "hivis":
        for cx in (32, 64):
            ic.bar((cx - 11, 72), (cx + 11, 72), 2.4, "reflect")
    ic.scratches(count=10)


def s_grips(ic, st):
    _glove(ic, 32, st, fingerless=True, flip=1)
    _glove(ic, 64, st, fingerless=True, flip=-1)
    if st["motif"] == "hazard":
        stripes(ic, 54, 84, 74, 84, 3.0, 4)
    ic.scratches(count=10)


def s_wraps(ic, st):
    for cx, flip in ((32, 1), (64, -1)):
        ic.poly([(cx - 12, 30), (cx + 12, 30), (cx + 13, 70), (cx + 11, 86), (cx - 11, 86), (cx - 13, 70)], st["dye"], bevel=3.0, dome=0.9)
        for fx in (-8, -2.5, 3, 8.5):
            ic.bar((cx + fx, 32), (cx + fx, 22 + abs(fx) * 0.4), 5.0, st["dye"], prof="cyl")
        for k in range(8):
            y = 32 + k * 7
            ic.bar((cx - 12, y + 2 * flip), (cx + 12, y - 2 * flip), 0.9, "dark")
        ic.bar((cx + 12 * flip, 82), (cx + 18 * flip, 92), 2.2, "cloth", w1=1.0)
    if st["motif"] == "wrap":
        ic.ellipse(32, 50, 2.6, 2.6, "brass")
        ic.ellipse(64, 60, 2.6, 2.6, "brass")
    elif st["motif"] == "night":
        ic.bar((22, 70), (42, 70), 2.0, "dark")
    ic.scratches(count=6)


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


def s_boots(ic, st, kind="boots"):
    _boot(ic, 24, st, kind, 1)
    _boot(ic, 56, st, kind, 1)
    if st["motif"] == "flight":
        ic.bar((15, 14), (33, 14), 3.6, "fur")
        ic.bar((47, 14), (65, 14), 3.6, "fur")
    elif st["motif"] == "volt":
        ic.bar((14, 72), (80, 72), 2.0, "hazard")
    ic.scratches(count=12)


def s_treads(ic, st):
    s_boots(ic, st, "treads")


def s_striders(ic, st):
    s_boots(ic, st, "striders")


def s_cratertreads(ic, st):
    s_boots(ic, st, "treads")
    for x in (24, 56):
        ic.poly([(x - 12, 64), (x + 30, 64), (x + 30, 70), (x - 12, 70)], "plate", bevel=1.4)
        rivets(ic, [(x - 6, 67), (x + 8, 67), (x + 22, 67)], 0.9)
    ic.ellipse(40, 30, 3, 2, "dust", dome=0.4)


def s_gauntlets(ic, st):
    s_gloves(ic, st, gaunt=True)


# accessories
def s_rabbit(ic, st):
    for i in range(3):
        y = 24 + i * 4.4
        if i % 2:
            ic.ellipse(48, y, 1.2, 2.4, "steel", dome=0.6)
        else:
            ic.ellipse(48, y, 2.2, 1.4, "steel", dome=0.6)
    ic.bar((44, 36), (52, 36), 4.0, "brass", prof="cyl")
    ic.poly([(40, 38), (56, 38), (60, 64), (56, 82), (40, 82), (36, 64)], "fur", bevel=6.0, dome=0.9)
    for (x, y) in ((42, 80), (48, 84), (54, 80)):
        ic.ellipse(x, y, 4, 3.4, "fur")
        ic.ellipse(x, y + 1.5, 1.4, 1.0, "leather")
    ic.bar((40, 52), (56, 52), 1.0, "thread")


def s_bottlecap(ic, st):
    ic.bar((48, 6), (48, 24), 1.2, "leather")
    ic.bar((30, 10), (48, 24), 1.2, "leather")
    pts = []
    for k in range(42):
        a = k / 42 * math.tau
        r = 24 if k % 2 else 21
        pts.append((48 + math.cos(a) * r, 52 + math.sin(a) * r))
    ic.poly(pts, "brass", bevel=3.0, dome=0.9)
    ic.ellipse(48, 52, 15, 15, "red", dome=0.4)
    ic.ellipse(48, 52, 9, 9, "brass", dome=0.6)
    ic.bar((42, 52), (54, 52), 2.0, "dark")
    ic.scratches(count=10)


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
