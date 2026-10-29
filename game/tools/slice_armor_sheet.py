"""Slice Zach's painted armour sheet (tools/art_src/armor_sheet_zach_v1.png)
into the gear icons the game shows.

The sheet holds two painted variants of every piece, side by side:
  L = left half (tier Legendaries on the orange band)
  R = right half (tier Legendaries on the brown band)
CROPS maps every item id to its two cells (x, y, w, h in sheet px) and PICK
records which variant is used, so any choice can be flipped by editing one
letter. Extra rows on the sheet (the big 3-charm strip, the second left
Foreman's Kit row, the brown 6-piece rows) are not used.

Each cell: the purple / dark cell background is keyed out to transparency
(flood-filled from the cell border so dark gloves keep their shape), pixels
darker than the background next to the item stay as a soft contact shadow,
then the item is centred and fitted with a 1 px margin and written at
  icons/set/48/<id>.png, icons/set/24/<id>.png   (IconSet; frames are drawn
                                                  by the game, not baked in)
  icons/gear/icon_slot_<slot>.png / icon_acc_<slot>.png  (96 px pickups, from
                                                  each slot's first generic)
Ids follow IconSet.item: tleg_<exclusive> -> gset_<set>_<slot> -> gear_<slot>_<n>.
Anything not in CROPS keeps the code-drawn icon from gen_gear_icons.py.

    python3 tools/slice_armor_sheet.py            (from game/)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
SHEET = os.path.join(HERE, "art_src", "armor_sheet_zach_v1.png")
SET = os.path.join(GAME, "assets", "sprites", "icons", "set")
GEAR96 = os.path.join(GAME, "assets", "sprites", "icons", "gear")


def row(xs, y, h, ws):
    return [(x, y, w, h) for x, w in zip(xs, ws)]


L3 = ([318, 503, 699], [182, 192, 183])          # left generic columns
R3 = ([1575, 1735, 1908], [157, 170, 163])       # right generic columns
LA = ([5, 194, 382], [185, 184, 178])            # left accessories
RA = ([1237, 1401, 1566], [161, 161, 157])       # right accessories
L6 = ([4, 194, 381, 564, 747, 929], [186, 184, 179, 180, 178, 185])
R6 = ([1237, 1401, 1565, 1735, 1900, 2076], [161, 162, 167, 164, 173, 181])
LS = ([4, 196, 392], [188, 191, 190])            # left survivor-set rows
LS2 = ([3, 208, 412], [202, 201, 200])
RS = ([1237, 1388, 1538], [149, 149, 150])

CROPS = {}


def put(ids, lcells, rcells):
    for i, k in enumerate(ids):
        CROPS[k] = {"L": lcells[i] if lcells else None, "R": rcells[i] if rcells else None}


SLOTS = ["head", "chest", "shoulders", "legs", "hands", "boots"]
_LY = [(4, 140), (146, 143), (292, 110), (405, 131), (539, 109), (650, 118)]
_RY = [(6, 154), (162, 156), (321, 139), (463, 142), (607, 135), (745, 147)]
for s, (ly, lh), (ry, rh) in zip(SLOTS, _LY, _RY):
    put(["gear_%s_%d" % (s, i) for i in range(3)], row(L3[0], ly, lh, L3[1]), row(R3[0], ry, rh, R3[1]))
for s, (ly, lh), (ry, rh) in zip(["charm", "vial", "patch"], [(903, 151), (1057, 152), (1213, 147)], [(901, 144), (1048, 151), (1202, 147)]):
    put(["gear_%s_%d" % (s, i) for i in range(3)], row(LA[0], ly, lh, LA[1]), row(RA[0], ry, rh, RA[1]))
for sid, ly, lh, ry, rh in (("plague_doctor", 1363, 151, 1356, 148), ("demolition_crew", 1517, 143, 1507, 148),
                            ("night_runner", 1663, 147, 1658, 145), ("field_salvager", 1813, 142, 1806, 142)):
    put(["gset_%s_%s" % (sid, s) for s in SLOTS], row(L6[0], ly, lh, L6[1]), row(R6[0], ry, rh, R6[1]))
SURV = [
    ("foremans_kit", ["head", "chest", "hands"], (L6[0][:3], 1958, 137, L6[1][:3]), ([1235, 1386, 1538], 2260, 150, [151, 151, 152])),
    ("bell_ringers_shroud", ["head", "shoulders", "legs"], (LS[0], 2479, 166, LS[1]), (RS[0], 2423, 148, RS[1])),
    ("quarry_plate", ["chest", "shoulders", "legs"], (LS[0], 2649, 160, LS[1]), (RS[0], 2584, 148, RS[1])),
    ("linemans_rig", ["hands", "chest", "boots"], (LS[0], 2814, 174, LS[1]), (RS[0], 2745, 147, [149, 150, 152])),
    ("cathedral_vestments", ["chest", "head", "legs"], (LS2[0], 3004, 179, LS2[1]), (RS[0], 2904, 145, RS[1])),
    ("surgeons_coat", ["chest", "hands", "head"], (LS2[0], 3185, 177, LS2[1]), (RS[0], 3060, 147, RS[1])),
    ("smugglers_wraps", ["hands", "legs", "boots"], (LS2[0], 3364, 159, LS2[1]), ([1237, 1387, 1546], 3219, 143, [149, 151, 144])),
    ("flight_crew_gear", ["head", "chest", "boots"], (LS2[0], 3525, 176, LS2[1]), ([1237, 1387, 1545], 3373, 150, [149, 150, 145])),
]
for sid, slots, lrow, rrow in SURV:
    put(["gset_%s_%s" % (sid, s) for s in slots], row(lrow[0], lrow[1], lrow[2], lrow[3]), row(rrow[0], rrow[1], rrow[2], rrow[3]))
TLEG = ["refinery_gasmask", "lamplighter_coat", "quarantine_seal", "raider_kingsguard",
        "chem_filter_vial", "officer_gauntlets", "crater_treads", "dust_heart_relic"]
put(["tleg_" + t for t in TLEG],
    [(3, 3704, 148, 182), (154, 3704, 149, 182), (306, 3704, 141, 182), (450, 3704, 162, 182), (615, 3704, 121, 182), (739, 3704, 152, 182), (894, 3704, 154, 182), (1051, 3704, 146, 182)],
    [(1239, 3535, 146, 159), (1388, 3535, 148, 159), (1539, 3535, 147, 159), (1688, 3535, 145, 159), (1838, 3535, 143, 159), (1986, 3535, 146, 159), (2136, 3535, 146, 159), (2284, 3535, 140, 159)])

## Variant used per item ("L" / "R"); flip any letter to swap.
PICK = {k: "R" for k in CROPS}
PICK.update({
    # generic
    "gear_chest_0": "L", "gear_shoulders_2": "L",
    "gset_demolition_crew_hands": "L",
    # sets: left variant reads better / fits the set palette
    "gset_foremans_kit_chest": "L", "gset_foremans_kit_hands": "L",
    "gset_quarry_plate_chest": "L", "gset_quarry_plate_shoulders": "L", "gset_quarry_plate_legs": "L",
    "gset_linemans_rig_hands": "L", "gset_linemans_rig_chest": "L",
    "gset_cathedral_vestments_chest": "L", "gset_cathedral_vestments_head": "L", "gset_cathedral_vestments_legs": "L",
    "gset_surgeons_coat_chest": "L", "gset_surgeons_coat_hands": "L", "gset_surgeons_coat_head": "L",
    "gset_smugglers_wraps_hands": "L", "gset_smugglers_wraps_legs": "L", "gset_smugglers_wraps_boots": "L",
    "gset_flight_crew_gear_chest": "L", "gset_flight_crew_gear_boots": "L",
    # tier Legendaries
    "tleg_quarantine_seal": "L", "tleg_raider_kingsguard": "L", "tleg_chem_filter_vial": "L",
    "tleg_officer_gauntlets": "L", "tleg_crater_treads": "L", "tleg_dust_heart_relic": "L",
})


## per-item key threshold overrides (dark items on the dark cell need a tighter flood)
KEY = {"gset_night_runner_legs": 7, "gset_night_runner_hands": 8, "gset_night_runner_boots": 8, "gset_night_runner_chest": 8,
       "gset_night_runner_shoulders": 8, "gset_smugglers_wraps_hands": 8, "gset_smugglers_wraps_legs": 8}


def cut(sheet, box, thr=12, orange=False):
    """Key the cell background out; returns an RGBA float image of the item."""
    x, y, w, h = box
    ins = 4
    c = sheet[y + ins:y + h - ins, x + ins:x + w - ins].astype(np.float32)
    H, W, _ = c.shape
    border = np.concatenate([c[:3].reshape(-1, 3), c[-3:].reshape(-1, 3), c[:, :3].reshape(-1, 3), c[:, -3:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    # per-pixel background estimate: smooth vignette from the border ring
    d = np.sqrt(((c - bg) ** 2).sum(axis=2))
    lum = c.mean(axis=2)
    bgl = bg.mean()
    near = d < thr
    if orange:
        # the left Legendary band is orange with a painted darker glow round each
        # item: any warm, saturated pixel joined to the border is background
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        warm = (r > g * 1.25) & (g > b * 1.15) & (r - b > 45)
        near = near | warm
    lab, n = ndi.label(near)
    edge_ids = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bgm = np.isin(lab, list(edge_ids))
    # anything else touching the border that is still close to bg (vignette)
    near2 = (d < thr * 1.4) | (warm if orange else False)
    lab2, _ = ndi.label(near2)
    ids2 = set(np.unique(lab2[bgm])) - {0}
    bgm = bgm | np.isin(lab2, list(ids2))
    obj = ~bgm
    obj = ndi.binary_opening(obj, iterations=1)
    lab3, n3 = ndi.label(obj)
    if n3:
        sizes = ndi.sum(obj, lab3, range(1, n3 + 1))
        touch = set(np.unique(np.concatenate([lab3[0], lab3[-1], lab3[:, 0], lab3[:, -1]]))) - {0}
        big = int(np.argmax(sizes)) + 1
        # keep real parts of the item; drop specks and slivers of neighbouring cells
        keep = [i + 1 for i, sz in enumerate(sizes) if sz >= max(30, 0.04 * sizes.max()) and (i + 1 == big or (i + 1) not in touch or sz >= 0.25 * sizes.max())]
        obj = np.isin(lab3, keep)
    obj = ndi.binary_fill_holes(obj)
    a = ndi.gaussian_filter(obj.astype(np.float32), 0.7)
    a = np.clip((a - 0.15) / 0.7, 0, 1)
    # soft contact shadow: background pixels darker than the cell, near the item
    near_item = ndi.binary_dilation(obj, iterations=10)
    sh = np.clip((bgl - lum - 3) / 30.0, 0, 0.55) * near_item * (1 - a) * (0.0 if orange else 1.0)
    rgb = c.copy()
    out = np.zeros((H, W, 4), np.float32)
    out[..., :3] = rgb
    out[..., 3] = a
    # shadow as dark translucent pixels where the item is not
    shm = sh > 0.02
    out[shm, :3] = np.array([14, 10, 12], np.float32)
    out[shm, 3] = np.maximum(out[shm, 3], sh[shm])
    return out


def fit(img, n):
    """Centre on the item's bbox and fit into n x n with a 1 px margin."""
    a = img[..., 3]
    ys, xs = np.nonzero(a > 0.05)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = img[y0:y1, x0:x1]
    h, w = crop.shape[:2]
    side = max(h, w)
    sq = np.zeros((side, side, 4), np.float32)
    oy, ox = (side - h) // 2, (side - w) // 2
    sq[oy:oy + h, ox:ox + w] = crop
    inner = n - 2
    # premultiplied resize
    pm = sq.copy()
    pm[..., :3] *= pm[..., 3:4]
    im = Image.fromarray(np.clip(pm[..., :3], 0, 255).astype(np.uint8))
    al = Image.fromarray(np.clip(pm[..., 3] * 255, 0, 255).astype(np.uint8))
    im = im.resize((inner, inner), Image.LANCZOS)
    al = al.resize((inner, inner), Image.LANCZOS)
    rgbp = np.asarray(im, np.float32)
    aa = np.asarray(al, np.float32) / 255.0
    rgb = np.where(aa[..., None] > 1e-3, rgbp / np.maximum(aa[..., None], 1e-3), 0)
    rgbi = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    if n >= 48:
        rgbi = rgbi.filter(ImageFilter.UnsharpMask(radius=1.0, percent=60 if n == 96 else 45, threshold=1))
    else:
        rgbi = rgbi.filter(ImageFilter.UnsharpMask(radius=0.8, percent=70, threshold=0))
    out = np.zeros((n, n, 4), np.uint8)
    out[1:-1, 1:-1, :3] = np.asarray(rgbi)
    out[1:-1, 1:-1, 3] = np.clip(aa * 255, 0, 255).astype(np.uint8)
    return out


def main(only=()):
    sheet = np.asarray(Image.open(SHEET).convert("RGB"))
    done = []
    for k, cells in CROPS.items():
        if only and k not in only:
            continue
        box = cells[PICK[k]] or cells["L"] or cells["R"]
        item = cut(sheet, box, KEY.get(k, 12), orange=(k.startswith("tleg_") and PICK[k] == "L"))
        for n in (48, 24):
            Image.fromarray(fit(item, n), "RGBA").save(os.path.join(SET, str(n), k + ".png"))
        if k.startswith("gear_") and k.endswith("_0"):
            slot = k[5:-2]
            fn = ("icon_acc_%s.png" if slot in ("charm", "vial", "patch") else "icon_slot_%s.png") % slot
            Image.fromarray(fit(item, 96), "RGBA").save(os.path.join(GEAR96, fn))
        done.append(k)
    print("sliced", len(done))


if __name__ == "__main__":
    main(tuple(sys.argv[1:]))
