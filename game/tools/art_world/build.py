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
# World-scale pass: real proportions against the hero (body ~100 tx): props
# S <= 0.6x hero, M <= 1.7x, L <= 2.6x, landmark set pieces up to 3.6x tall.
PS, PM, PL_, LM = (60, 140), (170, 320), (260, 440), (360, 520)
import props_big as B
PROPS = {
    # assets/sprites/props (chunk dressing, breakables, extract pads)
    "rock_small": (S.rock_small, "props", PS), "rock_large": (S.rock_large, "props", PS),
    "rock_huge": (B.rock_huge, "props", PM),
    "bones": (S.bones, "props", PS), "dead_bush": (S.dead_bush, "props", PS), "cactus": (S.cactus, "props", PM),
    "tire": (S.tire, "props", PS), "tire_stack": (B.tire_stack, "props", PM), "sign_post": (S.sign_post, "props", PM),
    "scrap_pile": (S.scrap_pile, "props", PS), "crate_stack": (B.crate_stack, "props", PM),
    "barrier_scrap": (S.barrier_scrap, "props", PM), "scrap_drum": (S.scrap_drum, "props", PS),
    "herb_crate": (S.herb_crate, "props", PS), "vial_crate": (S.vial_crate, "props", PS),
    "apothecary_chest": (S.apothecary_chest, "props", PS), "barrels_rust": (B.drum_pair, "props", PM),
    "sandbags": (B.sandbags_big, "props", PM),
    "wreck_car": (B.wreck_car, "props", PM), "wreck_car_red": (B.wreck_car_red, "props", PM),
    "wreck_car_blue": (B.wreck_car_blue, "props", PM), "wreck_car_olive": (B.wreck_car_olive, "props", PM),
    "wreck_truck": (B.wreck_truck, "props", PM), "wreck_bus": (B.wreck_bus, "props", PL_), "wreck": (B.wreck, "props", PM),
    "pole_down": (lambda: B.big("pole_down"), "props", PM),
    "fence_broken": (B.fence_big, "props", PM), "wall_ruin": (B.wall_ruin_big, "props", PM),
    "wall_ruin_b": (B.wall_ruin_b, "props", PM),
    "wall_collapsed": (lambda: B.big("wall_collapsed"), "props", PM), "ruin_pillar": (B.ruin_pillar_big, "props", PM),
    "signal_tower": (lambda: B.big("signal_tower"), "props", LM),
    "extract_sealed": (L.extract_sealed, "props", PL_), "extract_open": (L.extract_open, "props", PL_),
    # assets/sprites/depth/zone
    "chem_vat": (B.chem_vat_big, "depth/zone", PM), "bunker": (B.bunker_big, "depth/zone", PL_),
    "bunker_open": (B.bunker_open_big, "depth/zone", PL_), "rubble_chunk": (lambda: B.big("rubble_chunk"), "depth/zone", PM),
    "wreck_pile": (B.wreck_pile_big, "depth/zone", PM), "buried_wreck": (B.buried_wreck_big, "depth/zone", PM),
    # assets/sprites/depth/world (radio jobs, landmarks, haul crate)
    "medicine_crate": (Z.medicine_crate, "depth/world", PM),
}
for _n, _f in (("pipe_rack", "zone"), ("oil_tank", "zone"), ("street_lamp", "zone"), ("shop_ruin", "zone"),
               ("quarantine_tent", "zone"), ("hazard_barrier", "zone"), ("spike_barricade", "zone"), ("raider_totem", "zone"),
               ("tank_wreck", "zone"), ("guard_post", "zone"), ("slab_ruin", "zone"), ("dust_spire", "zone"),
               ("power_pole", "zone"), ("beast_ribs", "zone"), ("field_tent", "world"), ("market_stall", "world"),
               ("plane_wreck", "world"), ("relay", "world"), ("vault", "world"), ("watch_tower", "world")):
    PROPS[_n] = ((lambda n=_n: B.big(n)), "depth/" + _f, LM if _f == "world" or _n in ("dust_spire",) else PL_)
# Collision from the art: name -> (depth in texels, width fraction of the
# opaque base band). The block sits on the sprite's base line, centred on the
# base band. Props not listed are walk-through.
BLOCK = {
    "wall_ruin": (16, 0.95), "wall_ruin_b": (16, 0.95), "sandbags": (14, 0.92), "wall_collapsed": (18, 0.5),
    "rock_large": (12, 0.8), "rock_huge": (18, 0.8),
    "wreck_car": (24, 0.9), "wreck_car_red": (24, 0.9), "wreck_car_blue": (24, 0.9), "wreck_car_olive": (24, 0.9), "wreck": (24, 0.9),
    "wreck_truck": (26, 0.92), "wreck_bus": (28, 0.95),
    "oil_tank": (30, 0.86), "shop_ruin": (24, 0.95), "quarantine_tent": (24, 0.86), "hazard_barrier": (16, 0.97),
    "spike_barricade": (14, 0.9), "chem_vat": (16, 0.9), "tank_wreck": (30, 0.92), "guard_post": (18, 0.86),
    "slab_ruin": (20, 0.6), "dust_spire": (22, 0.8), "bunker": (44, 0.62), "bunker_open": (44, 0.62),
    "vault": (36, 0.95), "plane_wreck": (26, 0.6), "market_stall": (22, 0.95), "field_tent": (24, 0.8),
    "relay": (26, 0.9), "watch_tower": (18, 0.86), "wreck_pile": (26, 0.9), "buried_wreck": (24, 0.8),
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
            bh, frac = BLOCK[name]
            op = cv.opaque()
            band = op[max(0, cv.h - int(bh * 1.6)):, :].any(0)
            xs = np.nonzero(band)[0]
            bw = int((xs.max() - xs.min() + 1) * frac)
            ox = (xs.min() + xs.max() + 1) / 2 - cv.w / 2
            m["block"] = [bw, bh, ox, cv.h / 2 - bh / 2 - 1]
        if name in FLAT:
            m["flat"] = True
        if name == "street_lamp":
            # glass centre x in the source canvas (50) minus crop offset
            op = cv.opaque()
            ys, xs = np.nonzero((cv.a[:, :, 0] == 255) & (cv.a[:, :, 1] == 192))
            m["light"] = [float(xs.mean() - cv.w / 2), float(cv.h / 2 - 2)]
        if name == "chem_vat":
            m["light"] = [-6.0, -cv.h / 2 + 21.0]
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
        report.append(validate(a, "atlas", zone_cols=z[2], name="decals_%s" % GRADES[gi]))
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
