#!/usr/bin/env python3
"""Import the painted enemy / boss animation sheets (tools/art_src/enemies/).

Every sheet is bands of 2 rows x 6 cells facing right (tools/import_anim_sheet.py
does the slicing, keying and baking):

  row A: idle, walk 1..5          row B: wind-up, strike, follow, recover, flinch, death (lying)

States baked per unit (the names enemy.gd / UnitAnim play):
  idle    breathing A0 (flyers: the A row as a flap cycle)
  walk    A1..A5
  windup  B0 (+ a small squash)            attack  B1 B2 B3 (strike frames)
  hit     flinch B4                        death   flinch B4, then lying B5 held
  roar    B0 -> B1 held (bosses that had a roar)
  emerge  A0 rising out of the ground (Dune-Serpent)

Size: every unit keeps its old frame size (128 normal / 192 elite / 256 boss,
which sets its gameplay size class and hitbox) and its old on-screen size:
bosses match the old visible height, the rest the old sqrt(w*h) footprint,
both capped so idle / walk fit the frame. Feet stay on the old feet line
(flyers keep their old hover height). OLD below was measured from the
previous strips before they were replaced. <id>_attack.json keeps the old
attack type and hit count; origins are re-measured on the new frames.

    python3 tools/import_enemy_sheets.py [--preview DIR] [--dry] [--only id,id]
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import import_anim_sheet as ias  # noqa: E402

SRC = "tools/art_src/enemies/"

# Old strips (idle frame, alpha > 0.5): frame px, visible h / w, lowest px row,
# states present, attack hit frames and type.
OLD = {
    'apocalypse_wraith': {"fs": 128, "h": 88, "w": 58, "bot": 105, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'ash_singer': {"fs": 128, "h": 76, "w": 41, "bot": 119, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "ranged"},
    'ash_wraiths': {"fs": 128, "h": 73, "w": 45, "bot": 119, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'chimera_rat': {"fs": 128, "h": 53, "w": 70, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'coil_spider': {"fs": 128, "h": 46, "w": 78, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [2], "type": "melee"},
    'cyber_juggernaut': {"fs": 192, "h": 141, "w": 125, "bot": 180, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [0, 2], "type": "ranged"},
    'dread_naught': {"fs": 256, "h": 226, "w": 221, "bot": 240, "states": ["attack", "death", "hit", "idle", "roar", "walk", "windup"], "hits": [0], "type": "ranged"},
    'dune_serpent': {"fs": 128, "h": 27, "w": 82, "bot": 114, "states": ["attack", "death", "emerge", "hit", "idle", "walk", "windup"], "hits": [0], "type": "melee"},
    'dune_stalker': {"fs": 128, "h": 43, "w": 81, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'dust_warden': {"fs": 256, "h": 226, "w": 223, "bot": 240, "states": ["attack", "death", "hit", "idle", "roar", "walk", "windup"], "hits": [0], "type": "ranged"},
    'fusion_golem': {"fs": 128, "h": 75, "w": 87, "bot": 116, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'geist_alpha': {"fs": 128, "h": 87, "w": 59, "bot": 119, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'glow_moth': {"fs": 128, "h": 53, "w": 58, "bot": 93, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "ranged"},
    'glow_moth_queen': {"fs": 128, "h": 71, "w": 93, "bot": 95, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'iron_horse': {"fs": 128, "h": 83, "w": 70, "bot": 121, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'mech_wyrm': {"fs": 128, "h": 36, "w": 94, "bot": 114, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'mech_wyrm_b': {"fs": 128, "h": 34, "w": 93, "bot": 115, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1, 3], "type": "melee"},
    'muck_golem': {"fs": 128, "h": 73, "w": 64, "bot": 114, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [2], "type": "melee"},
    'mutant_overlord': {"fs": 256, "h": 223, "w": 211, "bot": 240, "states": ["attack", "death", "hit", "idle", "roar", "walk", "windup"], "hits": [0, 2], "type": "ranged"},
    'rad_bat': {"fs": 128, "h": 59, "w": 52, "bot": 77, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'rad_gator': {"fs": 128, "h": 50, "w": 87, "bot": 118, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'rad_gator_matriarch': {"fs": 256, "h": 80, "w": 173, "bot": 246, "states": ["attack", "death", "hit", "idle", "roar", "walk", "windup"], "hits": [1], "type": "melee"},
    'raider_brute': {"fs": 128, "h": 108, "w": 72, "bot": 119, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [2], "type": "melee"},
    'raider_captain': {"fs": 256, "h": 209, "w": 161, "bot": 238, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [0], "type": "ranged"},
    'raider_grunt': {"fs": 128, "h": 107, "w": 62, "bot": 118, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [0], "type": "ranged"},
    'scav_bear': {"fs": 128, "h": 73, "w": 97, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'scav_bear_cub': {"fs": 128, "h": 53, "w": 75, "bot": 121, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'scorpion_king': {"fs": 192, "h": 114, "w": 133, "bot": 183, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [0, 2], "type": "melee"},
    'scrap_hound': {"fs": 128, "h": 53, "w": 71, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'toxic_scorp': {"fs": 128, "h": 72, "w": 82, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [0], "type": "melee"},
    'void_spider': {"fs": 128, "h": 63, "w": 98, "bot": 120, "states": ["attack", "death", "hit", "idle", "walk", "windup"], "hits": [1], "type": "melee"},
    'wasteland_god_entity': {"fs": 256, "h": 229, "w": 151, "bot": 242, "states": ["attack", "death", "hit", "idle", "roar", "walk", "windup"], "hits": [1], "type": "melee"},
}

BOSSES = {"dust_warden", "mutant_overlord", "dread_naught", "wasteland_god_entity",
          "rad_gator_matriarch", "raider_captain", "mother_vane"}
FLYERS = {"rad_bat", "glow_moth", "glow_moth_queen"}
# Mother Vane (campaign boss / ally NPC) gets her own art set; her stats and
# gameplay size stay the raider captain's.
ART_AS = {"mother_vane": "raider_captain"}

SHEETS = [
    ("raiders.png", 3, ["raider_grunt", "raider_brute", None]),   # band 3 shaman: see warden
    ("raider_captain.png", 1, ["raider_captain"]),
    ("machines.png", 5, ["cyber_juggernaut", "iron_horse", "mech_wyrm", "scrap_hound", "coil_spider"]),
    ("bosses_overlord_warden.png", 2, ["mutant_overlord", "dust_warden"]),
    ("mutants_a.png", 6, ["rad_gator", "rad_gator_matriarch", "scav_bear", "scav_bear_cub", "toxic_scorp", "scorpion_king"]),
    ("mutants_b.png", 6, ["rad_bat", "glow_moth", "glow_moth_queen", "void_spider", "chimera_rat", "dune_stalker"]),
    ("mutants_c.png", 6, ["dune_serpent", "muck_golem", "fusion_golem", "geist_alpha", "ash_singer", "ash_wraiths"]),
    ("bosses_b7.png", 4, ["apocalypse_wraith", "dread_naught", "wasteland_god_entity", "mother_vane"]),
]
# Colour variants baked from another unit's cells (old _b was the hotter wyrm:
# more molten orange glow, warmer metal).
VARIANTS = {"mech_wyrm_b": ("mech_wyrm", {"hue": -0.012, "sat": 1.12, "val": 1.06,
                                          "glow": {"hue": -0.03, "sat": 1.25, "val": 1.35, "s_min": 0.4, "v_min": 0.4}})}


def unit_spec(uid, band, src_id=None):
    old = OLD[ART_AS.get(src_id or uid, src_id or uid)]
    fs = old["fs"]
    boss = uid in BOSSES
    fly = uid in FLYERS
    feet = old["bot"] + 1
    st = {}
    if fly:
        st["idle"] = ["A0", "A1", "A2", "A3", "A4", "A5"]
    else:
        st["idle"] = {"breathe": "A0", "n": 16, "amp": 0.012}
    st["walk"] = ["A1", "A2", "A3", "A4", "A5"]
    st["windup"] = ["B0", {"cell": "B0", "sy": 0.97, "sx": 1.02}]
    st["attack"] = ["B1", "B2", "B3"]
    st["hit"] = [{"cell": "B4", "sy": 0.95, "sx": 1.03}, "B4"]
    hold = 9 if fs >= 256 and "roar" in old["states"] else 5
    st["death"] = ["B4", {"cell": "B4", "sy": 0.96},
                   {"cell": "B5", "sy": 1.06, "sx": 0.98, "anchor": "paw", "bottom": 10}] +                   [{"cell": "B5", "anchor": "paw", "bottom": 10}] * hold
    if "roar" in old["states"]:
        st["roar"] = ["B0", "B1", "B1", {"cell": "B1", "sy": 1.03, "sx": 0.99}, "B1",
                      {"cell": "B1", "sy": 1.03, "sx": 0.99}, "B1", "B0"]
    if "emerge" in old["states"]:
        st["emerge"] = {"reveal": "A0", "n": 6}
    fps = {"idle": 12 if fly else 8, "walk": 14 if fly else 9, "windup": 10, "attack": 9,
           "hit": 12, "death": 10, "roar": 8, "emerge": 10}
    fps = {k: v for k, v in fps.items() if k in st}
    target = {"h": old["h"]} if boss else {"gm": (old["h"] * old["w"]) ** 0.5}
    grow = {"grow": 64, "grow_max": 512} if fs >= 256 else {}
    return {**grow, "band": band, "id": uid, "out": "assets/sprites/enemies/%s" % uid,
            "fs": fs, "feet": feet, "target": target, "flying": fly, "shadow": False,
            "fit": ["A%d" % i for i in range(6)] + ["B4"],
            "states": st, "fps": fps, "grade": GRADE, "rim": True,
            "attack": {"type": old["type"], "hit_frames": "auto", "old_hits": old["hits"]}}


# The painted sheets are murkier than the old pixel mobs: lift the mid-tones
# and bake the bible's 1 px outline + key rim so they read on the ground.
GRADE = {"gamma": 0.8, "sat": 1.12, "contrast": 1.06}
# Trailing wisps may fade off the frame sides rather than shrink the unit.
CLIP_OK = {"apocalypse_wraith"}
# Cells whose raised weapon crosses the floor line and touches the feet above.
REACH_UP = {"raider_brute": ["B1"]}


def specs():
    out = []
    for sheet, bands, ids in SHEETS:
        units = [unit_spec(u, b) for b, u in enumerate(ids) if u]
        for s in units:
            if s["id"] in CLIP_OK:
                s["clip_ok"] = True
            if s["id"] in REACH_UP:
                s["reach_up"] = REACH_UP[s["id"]]
        for vid, (base, rc) in VARIANTS.items():
            if base in ids:
                s = unit_spec(vid, ids.index(base))
                s["recolor"] = rc
                units.append(s)
        out.append({"sheet": SRC + sheet, "bands": bands, "units": units})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", default="")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(","))) or None
    grids = ias.load_grids()
    for s in specs():
        if only and not any(u["id"] in only for u in s["units"]):
            continue
        ias.import_sheet(s, a.preview, a.dry, only, grids)
    if not a.dry:
        ias.save_grids(grids)
    return 0


if __name__ == "__main__":
    sys.exit(main())
