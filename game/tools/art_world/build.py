"""Track A build: every world prop, landmark, zone ground set and decal atlas,
validated against STYLE_BIBLE v1 and written into game/assets/sprites/.
Also writes scripts/world/prop_meta.gd (footprints, collision blocks, light
anchors in texels) and scripts/world/decal_atlas.gd (atlas regions).

    cd game/tools/art_world && python3 build.py [--check]
"""
import os
import sys
import json
import numpy as np
from PIL import Image
from pal import ZONES, h
from pk import Cv, validate
import props_small as S
import props_large as L
import props_zone as Z
import ground_tiles as G
import decals as DC

GAME = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPR = GAME + "/assets/sprites/"

# zone grade per tier (index = tier - 1); ZoneDefs "grade" must match
GRADES = ["haze", "drift", "refinery", "city", "quarantine", "raider", "chemical", "military", "crater", "dustfall"]

# name -> (maker, folder, size class (max h, max w))
PS, PM, PL_, LM = (40, 400), (100, 400), (160, 400), (260, 300)
PROPS = {
    # assets/sprites/props (chunk dressing, breakables, extract pads)
    "rock_small": (S.rock_small, "props", PS), "rock_large": (S.rock_large, "props", PS),
    "bones": (S.bones, "props", PS), "dead_bush": (S.dead_bush, "props", PS), "cactus": (S.cactus, "props", PM),
    "tire": (S.tire, "props", PS), "sign_post": (S.sign_post, "props", PM), "scrap_pile": (S.scrap_pile, "props", PS),
    "barrier_scrap": (S.barrier_scrap, "props", PM), "scrap_drum": (S.scrap_drum, "props", PS),
    "herb_crate": (S.herb_crate, "props", PS), "vial_crate": (S.vial_crate, "props", PS),
    "apothecary_chest": (S.apothecary_chest, "props", PS), "barrels_rust": (S.barrels_rust, "props", PM),
    "sandbags": (S.sandbags, "props", PS),
    "wreck_car": (L.wreck_car, "props", PM), "wreck_truck": (L.wreck_truck, "props", PM),
    "wreck_bus": (L.wreck_bus, "props", PM), "wreck": (L.wreck, "props", PM), "pole_down": (L.pole_down, "props", PM),
    "fence_broken": (L.fence_broken, "props", PM), "wall_ruin": (L.wall_ruin, "props", PM),
    "wall_collapsed": (L.wall_collapsed, "props", PM), "ruin_pillar": (L.ruin_pillar, "props", PM),
    "signal_tower": (L.signal_tower, "props", LM),
    "extract_sealed": (L.extract_sealed, "props", PL_), "extract_open": (L.extract_open, "props", PL_),
    # assets/sprites/depth/zone
    "chem_vat": (Z.chem_vat, "depth/zone", PM), "pipe_rack": (Z.pipe_rack, "depth/zone", PL_),
    "oil_tank": (Z.oil_tank, "depth/zone", PL_), "street_lamp": (Z.street_lamp, "depth/zone", PL_),
    "shop_ruin": (Z.shop_ruin, "depth/zone", PL_), "quarantine_tent": (Z.quarantine_tent, "depth/zone", PL_),
    "hazard_barrier": (Z.hazard_barrier, "depth/zone", PM), "spike_barricade": (Z.spike_barricade, "depth/zone", PM),
    "raider_totem": (Z.raider_totem, "depth/zone", PL_), "tank_wreck": (Z.tank_wreck, "depth/zone", PL_),
    "guard_post": (Z.guard_post, "depth/zone", PL_), "bunker": (Z.bunker, "depth/zone", PL_),
    "bunker_open": (Z.bunker_open, "depth/zone", PL_), "slab_ruin": (Z.slab_ruin, "depth/zone", PL_),
    "rubble_chunk": (Z.rubble_chunk, "depth/zone", PM), "dust_spire": (Z.dust_spire, "depth/zone", LM),
    "power_pole": (Z.power_pole, "depth/zone", PL_), "wreck_pile": (Z.wreck_pile, "depth/zone", PM),
    "beast_ribs": (Z.beast_ribs, "depth/zone", PM), "buried_wreck": (Z.buried_wreck, "depth/zone", PM),
    # assets/sprites/depth/world (radio jobs, landmarks, haul crate)
    "field_tent": (Z.field_tent, "depth/world", PL_), "market_stall": (Z.market_stall, "depth/world", PL_),
    "medicine_crate": (Z.medicine_crate, "depth/world", PM), "plane_wreck": (Z.plane_wreck, "depth/world", PL_),
    "relay": (Z.relay, "depth/world", PL_), "vault": (Z.vault, "depth/world", PL_),
    "watch_tower": (Z.watch_tower, "depth/world", LM),
}
# Collision footprints in texels: (w, h, centre x offset from sprite centre).
# They sit on the sprite's base line. Props not listed are walk-through.
BLOCK = {
    "wall_ruin": (62, 12, 0), "sandbags": (88, 14, 0), "wall_collapsed": (44, 14, -31), "rock_large": (40, 12, 0),
    "wreck_truck": (128, 16, 0), "wreck_bus": (196, 18, 0),
    "oil_tank": (118, 22, -2), "shop_ruin": (196, 18, 0), "quarantine_tent": (176, 18, 4), "hazard_barrier": (166, 12, 0),
    "spike_barricade": (150, 12, 0), "chem_vat": (82, 16, -4), "tank_wreck": (174, 20, -4), "guard_post": (100, 16, 0),
    "slab_ruin": (150, 16, 0), "dust_spire": (100, 16, 0), "bunker": (200, 30, 0), "bunker_open": (200, 30, 0),
    "vault": (206, 28, 0), "plane_wreck": (180, 20, 0), "market_stall": (190, 18, 0), "field_tent": (150, 18, -10),
    "relay": (136, 20, 0), "watch_tower": (130, 16, 0), "wreck_pile": (100, 18, 0), "buried_wreck": (80, 16, 0),
}
# Flat ground-level pieces: no contact shadow.
FLAT = {"extract_sealed", "extract_open"}
# Emissive light anchors (texels from sprite centre): name -> [x, y]
LIGHT = {"street_lamp": None, "chem_vat": None}
# deliberate single-pixel highlights (spines, rivets) per asset
GLINTS = {"cactus": 9, "barrier_scrap": 8}
SINK_W = {"s": 190, "m": 240, "l": 290}


def foot(cv):
    op = cv.opaque()
    ys, xs = np.nonzero(op)
    yb = ys.max()
    sel = ys >= yb - 3
    return int(xs[sel].min()), int(xs[sel].max())


def save(cv, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(cv.a if isinstance(cv, Cv) else cv, "RGBA" if (cv.a if isinstance(cv, Cv) else cv).shape[2] == 4 else "RGB").save(path)


def main(check_only=False):
    report = []
    meta = {}
    for name, (fn, folder, cls) in PROPS.items():
        cv = fn()
        v = validate(cv, "prop", size_max=cls, name=name, glints=GLINTS.get(name, 0))
        report.append(v)
        f0, f1 = foot(cv)
        m = {"size": [cv.w, cv.h], "foot": [f0 - cv.w / 2, f1 - cv.w / 2]}
        if name in BLOCK:
            bw, bh, ox = BLOCK[name]
            m["block"] = [bw, bh, ox, cv.h / 2 - bh / 2 - 1]
        if name in FLAT:
            m["flat"] = True
        if name == "street_lamp":
            # glass centre x in the source canvas (50) minus crop offset
            op = cv.opaque()
            ys, xs = np.nonzero((cv.a[:, :, 0] == 255) & (cv.a[:, :, 1] == 192))
            m["light"] = [float(xs.mean() - cv.w / 2), float(cv.h / 2 - 2)]
        if name == "chem_vat":
            m["light"] = [-4.0, -cv.h / 2 + 14.0]
        meta[name] = m
        if not check_only:
            save(cv, SPR + folder + "/" + name + ".png")
    # sinkholes per zone that has the twist (crater city + dustfall), 3 sizes
    for gi in (8, 9):
        for k, w in SINK_W.items():
            cv = DC.sinkhole(ZONES[gi], w, seed=gi * 3 + len(k))
            report.append(validate(cv, "decal", zone_cols=ZONES[gi][2], name="sinkhole_%s_%s" % (GRADES[gi], k)))
            if not check_only:
                save(cv, SPR + "depth/zone/sinkhole_%s_%s.png" % (GRADES[gi], k))
    # ground tiles: 6 kinds x 10 zones, plus the Haze set as the base fallback
    shares = []
    for gi, z in enumerate(ZONES):
        for kind in G.KINDS:
            t = G.tile(z[2], kind, seed=gi * 11 + 5)
            cols = set(map(tuple, t.reshape(-1, 3).tolist()))
            assert cols <= set(h(c) for c in z[2]), (z[0], kind)
            shares.append((z[0], kind, round(G.lstar_share(t, z[2]), 3)))
            if not check_only:
                Image.fromarray(t, "RGB").save(SPR + "tiles/zones/ground_%s_%s.png" % (kind, GRADES[gi]))
                if gi == 0:
                    Image.fromarray(t, "RGB").save(SPR + "tiles/ground_%s.png" % kind)
    # decal atlases per zone (same regions for every zone)
    regions = None
    for gi, z in enumerate(ZONES):
        a, regions = DC.atlas(z)
        report.append(validate(a, "decal", zone_cols=z[2], name="decals_%s" % GRADES[gi]))
        if not check_only:
            Image.fromarray(a, "RGBA").save(SPR + "decals/decal_atlas_%s.png" % GRADES[gi])
            if gi == 0:
                Image.fromarray(a, "RGBA").save(SPR + "decals/decal_atlas.png")
    if not check_only:
        write_gd(meta, regions)
    bad = [r for r in report if r["errors"]]
    for r in report:
        print("%-22s %-10s cols %2d  %s" % (r["name"], r["bbox"], r["colors"], ", ".join(r["errors"]) or "ok"))
    # roads (asphalt) are a darker minority strip; the 85% band applies to open ground
    low = [s for s in shares if s[2] < 0.85 and s[1] != "asphalt"]
    print("ground L*30-46 share: min %.3f" % min(s[2] for s in shares), "below 85%:", low)
    print("FAILED:", [r["name"] for r in bad])
    return 0 if not bad and not low else 1


def write_gd(meta, regions):
    lines = ["class_name PropMeta", "extends RefCounted", "",
             "## GENERATED by tools/art_world/build.py — do not edit by hand.",
             "## Style-bible world props: sizes, footprints, collision blocks and light",
             "## anchors in art TEXELS, relative to the (centered) sprite. Multiply by",
             "## UnitAnim.TEXEL for world px.", "", "const META := {"]
    for k, m in meta.items():
        parts = ['"size": Vector2(%d, %d)' % tuple(m["size"]), '"foot": Vector2(%.1f, %.1f)' % tuple(m["foot"])]
        if "block" in m:
            parts.append('"block": Rect2(%.1f, %.1f, %d, %d)' % (m["block"][2] - m["block"][0] / 2, m["block"][3] - m["block"][1] / 2, m["block"][0], m["block"][1]))
        if "light" in m:
            parts.append('"light": Vector2(%.1f, %.1f)' % tuple(m["light"]))
        if m.get("flat"):
            parts.append('"flat": true')
        if "deck" in m:
            parts.append('"deck": %d' % m["deck"])
        lines.append('\t"%s": {%s},' % (k, ", ".join(parts)))
    lines += ["}", "",
              "const GRADES := %s" % json.dumps(GRADES), "",
              "",
              "static func info(name: String) -> Dictionary:",
              "\treturn META.get(name, {})", "",
              "",
              "## Collision rect (world px, relative to the sprite centre), or an empty Rect2.",
              "static func block_rect(name: String, flip: bool = false) -> Rect2:",
              "\tvar m: Dictionary = META.get(name, {})",
              "\tif not m.has(\"block\"):",
              "\t\treturn Rect2()",
              "\tvar r: Rect2 = m[\"block\"]",
              "\tif flip:",
              "\t\tr.position.x = -r.position.x - r.size.x",
              "\treturn Rect2(r.position * UnitAnim.TEXEL, r.size * UnitAnim.TEXEL)",
              ""]
    open(GAME + "/scripts/world/prop_meta.gd", "w").write("\n".join(lines))
    dl = ["extends RefCounted", "",
          "## GENERATED by tools/art_world/build.py — regions in decals/decal_atlas_<grade>.png",
          "## (one atlas per zone, same layout; native density: one texel = one screen px).",
          "## Tyre tracks are pre-drawn in 4 directions (h, v, d = down-right, a = up-right):",
          "## pixel art is never rotated.", "", "const REGIONS := {"]
    for k in sorted(regions):
        dl.append('\t"%s": Rect2(%d, %d, %d, %d),' % ((k,) + tuple(regions[k])))
    dl += ["}", ""]
    open(GAME + "/scripts/world/decal_atlas.gd", "w").write("\n".join(dl))


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
