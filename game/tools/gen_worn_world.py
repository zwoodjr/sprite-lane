"""World-art worn pass (backlog 2): repaint the remaining clean / toy-looking world
props in the locked worn look (dark grade, grime, rust, dents, bullet holes, scorch,
cracks, welded patches — see tools/worn_fx.py and the hangar option D+C).

Footprint is unchanged: every output keeps its source size and exact alpha, so
world placement and collision (set in code) do not move. Extract pads stay very
readable: the open pad keeps its warm brass + lit vials, the sealed pad goes dark
steel; last chance is tinted red in code (extract_pad.gd).

Clean originals are kept in tools/art_src/world_clean/ (copied there on the first
run), so the pass is deterministic and re-runnable:
    python3 game/tools/gen_worn_world.py            # from the repo root
"""
import os
import random
import shutil
import sys
import zlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import worn_fx as W  # noqa: E402

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(GAME, "assets", "sprites")
SRC = os.path.join(GAME, "tools", "art_src", "world_clean")

DIRS = ["props", "props_hd", "depth/zone", "depth/world"]
SKIP = {"bullet", "plague_fog", "dust_spire"}  # projectile / FX / glowing Dust landmark
# per-name grade overrides (hazard reads that must keep their glow)
OVERRIDE = {"chem_vat": (112, 0.85, 1.1)}

METAL = {"barrels_rust", "scrap_drum", "barrier_scrap", "signal_tower", "wreck", "wreck_car", "wreck_truck",
         "wreck_bus", "tank_wreck", "oil_tank", "chem_vat", "pipe_rack", "hazard_barrier", "street_lamp",
         "bunker", "bunker_open", "vault", "relay", "plane_wreck", "tire", "scrap_pile", "fence_broken",
         "guard_post", "pole_down"}
STONE = {"wall_ruin", "wall_collapsed", "ruin_pillar", "slab_ruin", "rubble_chunk", "shop_ruin",
         "rock_large", "rock_small"}
WOOD = {"sign_post", "sandbags", "watch_tower", "spike_barricade", "raider_totem", "field_tent",
        "quarantine_tent", "market_stall"}
LOOT = {"apothecary_chest", "herb_crate", "vial_crate", "medicine_crate"}
NATURE = {"bones", "cactus", "dead_bush", "crater", "sinkhole", "dust_spire"}
PADS = {"extract_open", "extract_sealed"}

# per-kind grade: (target mean body luminance, saturation, contrast). Brightness is
# solved per sprite so pale painted zone props and dark pixel props land together.
GRADE = {
    "metal": (78, 0.6, 1.12), "stone": (88, 0.58, 1.1), "wood": (84, 0.62, 1.08),
    "loot": (104, 0.78, 1.08), "nature": (92, 0.66, 1.05),
}


def solve_dark(im, m, target, sat):
    import numpy as np
    g = W.grade(im, dark=1.0, sat=sat, contrast=1.0)
    arr = np.asarray(g.convert("L"), np.float32)
    mk = np.asarray(m) > 0
    mean = float(arr[mk].mean()) if mk.any() else target
    return max(0.42, min(1.0, target / max(1.0, mean)))


def kind_of(name):
    for k, s in (("metal", METAL), ("stone", STONE), ("wood", WOOD), ("loot", LOOT), ("nature", NATURE),
                 ("pad", PADS)):
        if name in s:
            return k
    return "metal"


def seed_of(rel):
    return zlib.crc32(rel.encode()) & 0xFFFF


def body_pts(m, rr, n, inset=0.18):
    """Random points well inside the silhouette (for holes / dents / scorch)."""
    import numpy as np
    arr = np.asarray(m.filter(ImageFilter.MinFilter(5)))
    ys, xs = np.nonzero(arr > 0)
    if len(xs) == 0:
        return []
    out = []
    w, h = m.size
    for _ in range(n * 6):
        i = rr.randrange(len(xs))
        x, y = int(xs[i]), int(ys[i])
        if inset * w < x < (1 - inset) * w and inset * h < y < (1 - inset) * h:
            out.append((x, y))
        if len(out) >= n:
            break
    return out


def worn(im, name, rel):
    a0 = im.getchannel("A")
    sd = seed_of(rel)
    rr = random.Random(sd)
    w, h = im.size
    u = max(1.0, min(w, h) / 46.0)
    m = W.body_mask(im, thr=120)
    k = kind_of(name)
    if k == "pad":
        return worn_pad(im, name, sd)
    target, sat, con = OVERRIDE.get(name, GRADE[k])
    out = W.grade(im, dark=solve_dark(im, m, target, sat), sat=sat, contrast=con)
    ew = 1.0 if min(w, h) >= 90 else 0.45  # small pixel props: lighter edge chipping
    out = W.grime(out, m, amt=150 if k != "loot" else 110, blur=max(1.5, 2.2 * u), seed=sd + 1)
    if k == "metal":
        out = W.rust_patches(out, m, amount=0.42, u=u, seed=sd + 2, alpha=200)
        out = W.rust_streaks(out, m, n=int(6 + w * h / 1600), u=u, length=(3, 10), seed=sd + 3, amt=150)
        out = W.edge_wear(out, m, amt=int(150 * ew), u=u, seed=sd + 4)
        out = W.scratches(out, m, n=int(8 + w * h / 1200), u=u, length=(2, 7), seed=sd + 5, amt=80)
        for (x, y) in body_pts(m, rr, 1):
            out = W.dent(out, m, x, y, 3.0 * u, amt=90)
        for (x, y) in body_pts(m, rr, 1):
            out = W.scorch(out, m, x, y, rr.uniform(5, 9) * u, seed=sd + 6, amt=170)
        if min(w, h) >= 40:
            for i, (x, y) in enumerate(body_pts(m, rr, rr.randint(2, 4))):
                out = W.bullet_hole(out, m, x, y, max(1.0, 1.1 * u), seed=sd + 10 + i)
        if min(w, h) >= 90 and rr.random() < 0.6:
            pts = body_pts(m, rr, 1, inset=0.25)
            if pts:
                x, y = pts[0]
                s = rr.uniform(2.6, 4.0) * u
                lay = Image.new("RGBA", out.size, (0, 0, 0, 0))
                W.weld_patch(lay, m, (x - s, y - s * 0.7, x + s, y + s * 0.7), u=u * 0.8, seed=sd + 20)
                out = Image.alpha_composite(out, lay)
    elif k == "stone":
        out = W.edge_wear(out, m, amt=int(130 * ew), u=u, seed=sd + 4, col=(150, 140, 122))
        for i, (x, y) in enumerate(body_pts(m, rr, 2 + int(w * h > 9000))):
            out = W.cracks(out, x, y, n=4, length=14 * u, col=(18, 14, 10, 200), width=max(1, int(0.5 * u)),
                           seed=sd + 30 + i, clip=m)
        for (x, y) in body_pts(m, rr, 1):
            out = W.scorch(out, m, x, y, rr.uniform(6, 10) * u, seed=sd + 6, amt=190)
        if min(w, h) >= 40:
            for i, (x, y) in enumerate(body_pts(m, rr, rr.randint(1, 3))):
                out = W.bullet_hole(out, m, x, y, max(1.0, 0.9 * u), seed=sd + 10 + i, petal=(92, 86, 76))
        out = W.scratches(out, m, n=int(4 + w * h / 2400), u=u, length=(2, 5), seed=sd + 5, amt=50,
                          col=(40, 34, 28))
    elif k == "wood":
        out = W.edge_wear(out, m, amt=int(110 * ew), u=u, seed=sd + 4, col=(150, 132, 104))
        out = W.scratches(out, m, n=int(6 + w * h / 1600), u=u, length=(2, 6), seed=sd + 5, amt=70,
                          col=(30, 24, 18))
        for (x, y) in body_pts(m, rr, 1):
            out = W.scorch(out, m, x, y, rr.uniform(5, 9) * u, seed=sd + 6, amt=170)
        if min(w, h) >= 100:
            pts = body_pts(m, rr, 1, inset=0.25)
            if pts:
                x, y = pts[0]
                s = rr.uniform(2.6, 4.0) * u
                lay = Image.new("RGBA", out.size, (0, 0, 0, 0))
                W.stitch_patch(lay, m, (x - s, y - s * 0.7, x + s, y + s * 0.7), u=u * 0.8, seed=sd + 20)
                out = Image.alpha_composite(out, lay)
    elif k == "loot":
        out = W.edge_wear(out, m, amt=int(120 * ew), u=u, seed=sd + 4)
        out = W.scratches(out, m, n=int(5 + w * h / 1800), u=u, length=(2, 6), seed=sd + 5, amt=70)
        out = W.rust_streaks(out, m, n=int(3 + w * h / 3000), u=u, length=(2, 6), seed=sd + 3, amt=110)
    else:  # nature: just grade + grime + a little grit
        out = W.scratches(out, m, n=int(3 + w * h / 3000), u=u, length=(2, 4), seed=sd + 5, amt=40,
                          col=(30, 24, 18))
    out.putalpha(a0)
    return out


def worn_pad(im, name, sd):
    """Pads: worn metal rim, but the open pad keeps warm brass + lit vials and the
    sealed one reads clearly dark and dead."""
    a0 = im.getchannel("A")
    w, h = im.size
    u = max(1.0, min(w, h) / 46.0)
    m = W.body_mask(im, thr=120)
    rr = random.Random(sd)
    if name == "extract_open":
        out = W.grade(im, dark=0.95, sat=0.92, contrast=1.1)
        out = W.grime(out, m, amt=90, blur=2.0 * u, seed=sd + 1)
        out = W.rust_patches(out, m, amount=0.22, u=u, seed=sd + 2, alpha=150)
        out = W.edge_wear(out, m, amt=140, u=u, seed=sd + 4)
        out = W.scratches(out, m, n=18, u=u, length=(2, 6), seed=sd + 5, amt=70)
        for i, ang in enumerate((0.7, 3.6)):
            import math
            x = w / 2 + math.cos(ang) * w * 0.41
            y = h / 2 + math.sin(ang) * h * 0.41
            out = W.bullet_hole(out, m, x, y, max(1.0, 1.0 * u), seed=sd + 10 + i)
        # warm phosphor glow back on the centre beacon so "open" pops
        lay = Image.new("RGBA", out.size, (0, 0, 0, 0))
        W.amber_lamp(lay, w / 2, h * 0.36, max(1.5, 1.2 * u), glow=4.0, strength=0.7)
        out = Image.alpha_composite(out, lay)
    else:
        out = W.grade(im, dark=0.68, sat=0.45, contrast=1.15)
        out = W.grime(out, m, amt=150, blur=2.0 * u, seed=sd + 1)
        out = W.rust_patches(out, m, amount=0.4, u=u, seed=sd + 2, alpha=200)
        out = W.rust_streaks(out, m, n=12, u=u, length=(2, 6), seed=sd + 3, amt=140)
        out = W.edge_wear(out, m, amt=140, u=u, seed=sd + 4)
        out = W.scratches(out, m, n=18, u=u, length=(2, 6), seed=sd + 5, amt=70)
        for i, (x, y) in enumerate(body_pts(m, rr, 3)):
            out = W.bullet_hole(out, m, x, y, max(1.0, 1.0 * u), seed=sd + 10 + i)
    out.putalpha(a0)
    return out


def main():
    done = 0
    for d in DIRS:
        folder = os.path.join(SPR, d)
        for fn in sorted(os.listdir(folder)):
            if not fn.endswith(".png"):
                continue
            name = fn[:-4]
            if name in SKIP:
                continue
            rel = os.path.join(d, fn)
            src = os.path.join(SRC, rel)
            if not os.path.exists(src):
                os.makedirs(os.path.dirname(src), exist_ok=True)
                shutil.copy2(os.path.join(folder, fn), src)
            im = Image.open(src).convert("RGBA")
            out = worn(im, name, rel)
            assert out.size == im.size and ImageChops.difference(out.getchannel("A"), im.getchannel("A")).getbbox() is None
            out.save(os.path.join(folder, fn))
            done += 1
    print("worn world props:", done)


if __name__ == "__main__":
    main()
