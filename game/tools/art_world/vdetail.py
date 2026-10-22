"""Hand-pixel detail layer for the voxel vehicle wrecks (owner-approved
HAND-DETAIL PASS). The voxel render stays the base (proportions, perspective,
material shading); this module adds what a pixel artist paints on top, driven
by the render's G-buffer (material id, model position + normal per pixel) so
it stays regenerable and per-variant deterministic:

  voxel stage   dents / crumpled corners that break the silhouette, a torn-off
                hood with the engine bay showing (burnt + stripped variants)
  pixel stage   silhouette + material-edge jaggy clean-up, engraved panel
                lines (dark groove + lit lip), lit body creases, chipped paint
                on edges, rust that follows edges (wheel arches, sills) with
                perforation holes and streaks running down from seams, chrome
                with a sky / horizon / ground reflection and specular pixels,
                hubcaps with lugs, tyre tread + sidewall arc, glass reflection
                bands, cracks and shattered fringes with seats behind, lamps
                with bezels and catch-lights, generic plates and badges, bullet
                sprays with bare-metal lips, soot plumes above burnt openings,
                dust settling on horizontal surfaces, drift crests.

Palette: master palette only (pal.py); light top-left; tone-0 outline is
added afterwards by pk.outline."""
import math
import numpy as np
from scipy import ndimage as ndi
from pk import A, E, RU, BR, ST, CL, BL, INK, TONE0
from pal import lab_L

BONE = A[4]
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

# ------------------------------------------------------------------ voxel stage
# hood bay per builder: (x_front, x_rear, z_top, half width, z_floor)
HOOD = {
    "sedan": (-2.26, -0.86, 0.92, 0.84, 0.42),
    "pickup": (-2.56, -0.68, 1.22, 0.90, 0.50),
    "box_truck": (-3.12, -2.26, 1.40, 0.86, 0.62),
    "ambulance": (-2.88, -2.06, 1.30, 0.86, 0.56),
    "semi": (-2.78, -1.06, 1.90, 0.86, 0.80),
    "humvee": (-2.24, -0.86, 1.22, 0.96, 0.62),
    "school_bus": (-4.18, -3.22, 1.50, 0.86, 0.62),
}
# which variants lose the hood
HOOD_VARS = {"sedan": (1,), "sedan_red": (2,), "wagon": (1,), "police": (2,), "pickup": (1,),
             "box_truck": (1,), "ambulance": (1,), "semi": (2,), "humvee": (1,), "school_bus": (1,)}
BUILDER = {"sedan_red": "sedan", "wagon": "sedan", "police": "sedan"}


def _surf_pts(v, mats, cond):
    surf = v.surface() & np.isin(v.m, [v.id[m] for m in mats if m in v.id])
    idx = np.nonzero(surf)
    X, Y, Z = v.coords(idx)
    k = cond(X, Y, Z)
    return X[k], Y[k], Z[k]


def vox_pass(v, name, var, seed, size):
    """Geometric damage on the voxel model (after the builder's own wear)."""
    rs = np.random.RandomState(seed * 7 + 3)
    L, W = size
    paint = ["paint", "paint2", "seam", "rust", "rust2", "scorch", "scorch2", "wood", "canvas"]
    glass_z = None
    gid = [v.id[g] for g in ("glass", "gbroke") if g in v.id]
    if gid:
        gz = np.nonzero(np.isin(v.m, gid))[2]
        if len(gz):
            glass_z = (gz.min() + 0.5) / 64.0
    zmax_dent = (glass_z - 0.1) if glass_z else 1.6
    if name == "moto":
        return
    # 1. side dents (not on thin armour skirts: they would punch through) (shallow concave hollows on the near side panels)
    ymax = _surf_pts(v, paint, lambda X, Y, Z: Y > 0)[1]
    if len(ymax) and name not in ("tank", "apc"):
        yface = np.percentile(ymax, 92)
        X, Y, Z = _surf_pts(v, paint, lambda X, Y, Z: (Y > yface - 0.05) & (Z > 0.3) & (Z < zmax_dent))
        nd = {0: 3, 1: 2, 2: 5}[var] + (2 if L > 6 else 0)
        if len(X):
            for k in rs.choice(len(X), min(nd, len(X)), replace=False):
                rx = rs.uniform(0.16, 0.34); rz = rs.uniform(0.09, 0.18); ry = rs.uniform(0.07, 0.11)
                v.ell(X[k], Y[k] + ry * 0.55, Z[k], rx, ry, rz, None, carve=True)
    # 2. crumpled corner: bites into the top edge of a front or rear fender
    #    (breaks the silhouette); stripped wrecks get both ends
    ends = [rs.choice([0, 1])] if var != 2 else [0, 1]
    if name in ("tank", "apc", "trailer"):
        ends = ends[:1]
    for e in ends:
        X, Y, Z = _surf_pts(v, ["paint", "paint2", "rust", "rust2", "scorch", "scorch2", "chrome", "wood"], lambda X, Y, Z: (Y > 0.2) & (Z > 0.25))
        if not len(X):
            continue
        xe = X.min() if e == 0 else X.max()
        near = np.abs(X - xe) < 0.35
        if not near.any():
            continue
        zt = Z[near].max()
        yt = Y[near].max()
        for j in range(4):
            cx = xe + (1 if e == 0 else -1) * rs.uniform(0.0, 0.3)
            cz = zt + rs.uniform(-0.05, 0.03)
            cy = yt + rs.uniform(-0.12, 0.02)
            r = rs.uniform(0.07, 0.13)
            v.ell(cx, cy, cz, r * 1.3, r * 1.2, r, None, carve=True, only=None)
    # 3. torn-off hood: engine bay with block, rocker covers, air cleaner,
    #    radiator, battery
    b = BUILDER.get(name, name)
    if b in HOOD and var in HOOD_VARS.get(name, ()):
        x0, x1, zt, hw, zf = HOOD[b]
        v.box(x0, x1, -hw, hw, zt - 0.2, zt + 0.15, None, carve=True)
        v.box(x0, x1, -hw, hw, zf, zt - 0.2, "well", only="solid")
        ln = x1 - x0
        burnt = var == 1
        blk = "scorch" if burnt else "steel"
        cx = (x0 + x1) / 2
        v.box(cx - ln * 0.3, cx + ln * 0.25, -0.34 * hw, 0.34 * hw, zf, zt - 0.12, blk, r=0.03)
        for s in (-1, 1):
            v.box(cx - ln * 0.28, cx + ln * 0.22, s * 0.2 * hw - 0.09, s * 0.2 * hw + 0.09, zt - 0.14, zt - 0.06,
                  "rust" if burnt else "rust2", r=0.02)
        v.cyl("z", cx + ln * 0.08, 0.0, min(0.24, ln * 0.18), zt - 0.1, zt - 0.02, "scorch2" if burnt else "hubc")
        v.box(x0 + 0.02, x0 + 0.1, -hw * 0.85, hw * 0.85, zf, zt - 0.08, "grille")
        v.box(cx + ln * 0.25, cx + ln * 0.42, hw * 0.45, hw * 0.85, zf, zt - 0.16, "trim", r=0.02)
        v.box(x0 + 0.1, x1 - 0.05, hw * 0.88, hw, zf, zt - 0.2, "paint", only=None)
        v.box(x0 + 0.1, x1 - 0.05, -hw, -hw * 0.88, zf, zt - 0.2, "paint", only=None)


# ------------------------------------------------------------------ pixel stage
class Ctx:
    def __init__(self, cv, G, var, seed, name):
        self.cv, self.G, self.var, self.name = cv, G, var, name
        self.a = cv.a
        self.H, self.W = cv.a.shape[:2]
        self.rs = np.random.RandomState(seed * 13 + var)
        self.names = G["names"]
        self.mat = G["mat"].copy()
        self.tag = np.zeros((self.H, self.W), np.uint8)
        self.keep = np.zeros((self.H, self.W), bool)
        n = G["n"]
        self.nz, self.ny, self.nx = n[..., 2], n[..., 1], n[..., 0]
        self.pos = G["pos"]
        lv = G["light"]
        self.lev = np.where(lv >= 0.6, 3, np.where(lv >= 0.22, 2, np.where(lv >= -0.12, 1, 0)))
        self.lev[G["crease"]] = 0

    def m(self, *names):
        ids = [self.names.index(n) for n in names if n in self.names]
        return np.isin(self.mat, ids) & (self.a[..., 3] > 0)

    def op(self):
        return self.a[..., 3] > 0

    def put(self, mask, col, tag=None, keep=False):
        self.a[mask, :3] = col
        self.a[mask, 3] = 255
        if tag is not None:
            self.tag[mask] = tag
        if keep:
            self.keep |= mask

    def put_lev(self, mask, ramp4, tag=None):
        for l in range(4):
            mm = mask & (self.lev == l)
            if mm.any():
                self.put(mm, ramp4[l], tag)

    def px(self, x, y, col, tag=None, keep=False, need=None):
        if 0 <= x < self.W and 0 <= y < self.H and self.a[y, x, 3]:
            if need is not None and not need[y, x]:
                return False
            self.a[y, x, :3] = col
            if tag is not None:
                self.tag[y, x] = tag
            if keep:
                self.keep[y, x] = True
            return True
        return False

    def colour(self, y, x):
        return tuple(int(c) for c in self.a[y, x, :3])


def sh(m, dy, dx):
    """Shift a mask: out[y, x] = m[y - dy, x - dx] (zero fill)."""
    out = np.zeros_like(m)
    H, W = m.shape
    ys0, ys1 = max(0, dy), min(H, H + dy)
    xs0, xs1 = max(0, dx), min(W, W + dx)
    out[ys0:ys1, xs0:xs1] = m[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def lighter(c):
    """One step up the colour's own ramp (BONE above the top)."""
    for rr in (A, E, RU, BR, ST, CL):
        if c in rr:
            i = rr.index(c)
            return rr[i + 1] if i + 1 < len(rr) else BONE
    return BONE


def darker(c):
    for rr in (A, E, RU, BR, ST, CL):
        if c in rr:
            i = rr.index(c)
            return rr[i - 1] if i > 0 else INK
    return INK


RUST4 = [RU[0], RU[1], RU[1], RU[2]]
SAND4 = [E[1], E[2], E[3], E[4]]
SOOT4 = [INK, A[0], A[0], A[1]]
PAINTS = ("paint", "paint2", "seam")
BIG = ("paint", "paint2", "rust", "rust2", "scorch", "scorch2", "glass", "gbroke", "sand", "canvas", "wood", "inside", "tyre", "track", "well")


def _noise(H, W, scale, seed):
    rs = np.random.RandomState(seed)
    g = rs.rand(H // scale + 3, W // scale + 3)
    g = ndi.zoom(g, scale, order=3)[:H, :W]
    g = (g - g.min()) / (g.max() - g.min() + 1e-9)
    return g


# ---------------------------------------------------------------- 0 clean-up
def smooth_jaggies(c):
    """Silhouette: fill 1 px notches, drop 1 px nubs. Material edges: a pixel
    whose material is a minority of its 3x3 joins the majority (kills voxel
    stair-step teeth; small parts like lamps and handles are exempt)."""
    a = c.a
    for _ in range(2):
        op = a[..., 3] > 0
        cnt = sum(sh(op, dy, dx).astype(int) for dx, dy in N4)
        notch = ~op & (cnt >= 3)
        for y, x in zip(*np.nonzero(notch)):
            for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < c.H and 0 <= xx < c.W and op[yy, xx]:
                    a[y, x] = a[yy, xx]
                    c.mat[y, x] = c.mat[yy, xx]
                    c.lev[y, x] = c.lev[yy, xx]
                    c.pos[y, x] = c.pos[yy, xx]
                    c.nz[y, x], c.ny[y, x], c.nx[y, x] = c.nz[yy, xx], c.ny[yy, xx], c.nx[yy, xx]
                    break
        nub = op & (cnt <= 1)
        a[nub, 3] = 0
    big = [c.names.index(n) for n in BIG if n in c.names]
    op = a[..., 3] > 0
    for _ in range(2):
        votes = {}
        for mid in big:
            mm = (c.mat == mid) & op
            votes[mid] = ndi.uniform_filter(mm.astype(np.float32), 3) * 9
        own = np.zeros(op.shape, np.float32)
        for mid in big:
            own = np.where(c.mat == mid, votes[mid], own)
        best = np.zeros(op.shape, np.int32); bestv = np.zeros(op.shape, np.float32)
        for mid in big:
            u = votes[mid] > bestv + 0.5
            best = np.where(u, mid, best); bestv = np.where(u, votes[mid], bestv)
        isbig = np.isin(c.mat, big)
        chg = op & isbig & (own < 2.5) & (bestv >= 5.5) & (best != c.mat)
        for y, x in zip(*np.nonzero(chg)):
            tgt = best[y, x]
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if (dy or dx) and 0 <= yy < c.H and 0 <= xx < c.W and c.mat[yy, xx] == tgt:
                        a[y, x] = a[yy, xx]; c.mat[y, x] = tgt; c.lev[y, x] = c.lev[yy, xx]
                        break
                else:
                    continue
                break


# ---------------------------------------------------------------- 1 panels
def panel_lines(c):
    """Seams become engraved: dark groove (already there) + a lit lip on the
    groove's lower-right wall; the top row of each lit near-side panel under
    a crease gets one lighter tone (body-line highlight)."""
    seam = c.m("seam")
    paint = c.m("paint", "paint2", "wood")
    for dy, dx in ((1, 0), (0, 1)):
        lip = sh(seam, dy, dx) & paint & ~seam
        for y, x in zip(*np.nonzero(lip)):
            c.a[y, x, :3] = lighter(c.colour(y, x))
            c.tag[y, x] = 9
    # convex body creases: top surface over a side surface
    top = (c.nz > 0.5)
    side = (c.nz < 0.35)
    rim = paint & side & sh(top & paint, 1, 0) & (c.tag == 0)
    rs = c.rs
    for y, x in zip(*np.nonzero(rim)):
        c.a[y, x, :3] = lighter(c.colour(y, x))
        c.tag[y, x] = 8
    return rim


def edge_wear(c, rim):
    """Paint chipped along creases and corners in short runs (a dark nick of
    primer / rust with a bright bare-metal pixel where it catches the light),
    never random blotches and never on the outer silhouette."""
    paint = c.m(*PAINTS)
    op = c.op()
    inner = ndi.binary_erosion(op, iterations=2)
    front = np.abs(c.nx) > 0.6
    nearside = c.ny > 0.6
    corner = paint & ((front & (sh(nearside, 0, 1) | sh(nearside, 0, -1))) | (nearside & (sh(front, 0, 1) | sh(front, 0, -1))))
    seamlip = c.tag == 9
    edges = (rim | corner | seamlip) & paint & inner
    nz = _noise(c.H, c.W, 7, c.rs.randint(1 << 30))
    amt = {0: 0.2, 1: 0.12, 2: 0.34}[c.var]
    chip = edges & (nz < amt)
    lab, n = ndi.label(chip, np.ones((3, 3)))
    for i in range(1, n + 1):
        yy, xx = np.nonzero(lab == i)
        o = np.lexsort((yy, xx))
        yy, xx = yy[o], xx[o]
        for k, (y, x) in enumerate(zip(yy, xx)):
            if c.tag[y, x] in (1, 2):
                continue
            if c.var == 1:
                col = RU[0]
            elif k == 0 and c.lev[y, x] >= 2 and len(yy) > 1:
                col = ST[3]
            else:
                col = RU[1] if c.lev[y, x] >= 2 else RU[0]
            c.a[y, x, :3] = col
            c.tag[y, x] = 4


# ---------------------------------------------------------------- 2 rust
def rust_edges(c):
    """Rust that follows the metal: ragged bands round the wheel arches and
    along the sills, heavier near the ground, with perforation holes."""
    if c.var == 1:
        return
    paint = c.m(*PAINTS)
    well = c.m("well")
    side = (np.abs(c.nz) < 0.5)
    z = c.pos[..., 2]
    nz = _noise(c.H, c.W, 3, c.rs.randint(1 << 30))
    reach = {0: 2.2, 2: 4.0}[c.var]
    d_arch = ndi.distance_transform_edt(~well)
    nz2 = _noise(c.H, c.W, 9, c.rs.randint(1 << 30))
    band = paint & side & (d_arch <= (reach + 3 * nz) * np.clip(nz2 * 1.8 - 0.3, 0, 1.3))
    # sills: paint just above the body's lower edge / tyre / ground
    below = ~sh(c.op(), -1, 0) | sh(c.m("tyre", "well", "sand", "track"), -1, 0)
    low = np.zeros_like(paint)
    acc = below & paint
    for k in range(int(reach) + 3):
        low |= acc
        acc = sh(acc, -1, 0) & paint
    sill = low & side & (z < 0.75) & (nz < 0.55 + 0.15 * c.var)
    # ground-weighted bloom from the lower edge upward
    bloom = paint & side & (z < 0.55) & (nz > 1.0 - 0.18 * (1 + c.var)) & sh(paint, 1, 0)
    r = (band | sill | bloom) & (c.tag == 0)
    r = ndi.binary_opening(r, np.ones((1, 2))) | (r & band)
    c.put_lev(r, RUST4, tag=1)
    # bright bloom fringe on the upper edge of each rust area (lit wall)
    fringe = sh(r, -1, 0) & paint & (c.tag == 0) & (nz > 0.5)
    c.put(fringe & (c.lev >= 2), RU[2], tag=1)
    # perforation: clusters of holes inside the heavier rust
    core = ndi.binary_erosion(r, iterations=1)
    ys, xs = np.nonzero(core & (z < 0.7))
    n = {0: 4, 2: 10}[c.var] + (c.W // 120)
    if len(ys):
        for k in c.rs.choice(len(ys), min(n, len(ys)), replace=False):
            y, x = ys[k], xs[k]
            m = c.rs.randint(1, 4)
            for j in range(m):
                yy, xx = y + c.rs.randint(-1, 2), x + j * 2 + c.rs.randint(0, 2)
                big = c.rs.rand() < 0.4
                for (oy, ox) in ([(0, 0), (0, 1)] if big else [(0, 0)]):
                    if c.px(xx + ox, yy + oy, INK, tag=2, need=r):
                        c.px(xx + ox, yy + oy + 1, RU[2], tag=2, need=r)
                        c.px(xx + ox + 1, yy + oy, RU[2], tag=2, need=r & (c.tag != 2))


def rust_streaks(c):
    """Streaks running down from seams, trim, window sills, chips and holes."""
    paint = c.m(*PAINTS)
    side = (np.abs(c.nz) < 0.45)
    src = (c.m("seam", "trim", "hole") | (c.tag == 4) | (c.tag == 2) | (c.tag == 9))
    win = c.m("glass", "gbroke", "chrome")
    start = (sh(src, 1, 0) | (sh(win, 1, 0) & (c.rs.rand(c.H, c.W) < 0.3))) & paint & side & (c.tag != 1)
    ys, xs = np.nonzero(start)
    if not len(ys):
        return
    p = {0: 0.05, 1: 0.03, 2: 0.09}[c.var]
    strong = (c.tag == 4) | (c.tag == 2)
    used = []
    o = c.rs.permutation(len(ys))
    for y, x in zip(ys[o], xs[o]):
        if c.rs.rand() > (p * 4 if sh(strong, 1, 0)[y, x] else p):
            continue
        gap = c.rs.randint(6, 22)
        if any(abs(x - ux) < gap and abs(y - uy) < 18 for ux, uy in used):
            continue
        used.append((x, y))
        L = int(c.rs.choice([3, 4, 5, 7, 9, 12, 15])) + 3 * (c.var == 2)
        dark = c.lev[y, x] <= 1
        for k in range(L):
            yy = y + k
            if yy >= c.H or not paint[yy, x] or not side[yy, x]:
                break
            if k > L * 0.6 and c.rs.rand() < 0.4:
                continue
            col = RU[0] if dark else (RU[1] if k < L * 0.5 else RU[1])
            if c.var == 1:
                col = A[0] if not dark else INK
            c.a[yy, x, :3] = col
            c.tag[yy, x] = 5
        # a short twin trail on wide streaks
        if c.rs.rand() < 0.35:
            for k in range(1, L // 2):
                yy = y + k
                if yy < c.H and x + 1 < c.W and paint[yy, x + 1] and c.tag[yy, x + 1] == 0:
                    c.a[yy, x + 1, :3] = RU[1] if not dark else RU[0]
                    c.tag[yy, x + 1] = 5


# ---------------------------------------------------------------- 3 chrome
def chrome(c):
    """Bumpers, grilles and trim: per column, the chrome run gets sky
    specular on top, a dark horizon band in the middle, ground bounce below."""
    ch = c.m("chrome")
    if not ch.any():
        return
    lab, n = ndi.label(ch)
    pit = _noise(c.H, c.W, 2, c.rs.randint(1 << 30))
    for x in range(c.W):
        col = ch[:, x]
        if not col.any():
            continue
        ys = np.nonzero(col)[0]
        runs = np.split(ys, np.nonzero(np.diff(ys) > 1)[0] + 1)
        for r in runs:
            n_ = len(r)
            for k, y in enumerate(r):
                if n_ >= 4:
                    f = k / (n_ - 1)
                    cc = BONE if k == 0 else (ST[3] if f < 0.3 else (ST[0] if f < 0.55 else (ST[1] if f < 0.75 else ST[2])))
                elif n_ == 3:
                    cc = (ST[3], ST[1], ST[2])[k]
                elif n_ == 2:
                    cc = (ST[3], ST[1])[k]
                else:
                    cc = ST[3] if c.lev[y, x] >= 2 else ST[1]
                if k == 0 and n_ >= 4 and (x * 7 + y) % 5:
                    cc = ST[3]
                if c.var == 2 and pit[y, x] < 0.22 and k > 0:
                    cc = RU[1] if k % 2 else RU[2]
                c.a[y, x, :3] = cc
                c.tag[y, x] = 6
    # specular glints at the top-left end of each long run
    for i in range(1, n + 1):
        yy, xx = np.nonzero(lab == i)
        if len(yy) < 12:
            continue
        j = np.argmin(xx + yy * 2)
        for d in range(0, 3):
            c.px(xx[j] + d + 1, yy[j], BONE, keep=True, need=ch)


def wheels(c):
    """Hub caps (dish, rim lip, lugs, centre cap, catch-light) and tyres
    (tread blocks on the rim, sidewall highlight arc)."""
    hub = c.m("hub", "hubc")
    tyre = c.m("tyre")
    lab, n = ndi.label(hub)
    for i in range(1, n + 1):
        yy, xx = np.nonzero(lab == i)
        if len(yy) < 10:
            continue
        cy, cx = (yy.min() + yy.max()) / 2, (xx.min() + xx.max()) / 2
        ry, rx = max(1, (yy.max() - yy.min()) / 2), max(1, (xx.max() - xx.min()) / 2)
        dx, dy = (xx - cx) / rx, (yy - cy) / ry
        d = np.sqrt(dx * dx + dy * dy)
        ang = np.arctan2(dy, dx)
        lit = (-dx - dy) > 0.2
        for y, x, dd, lt in zip(yy, xx, d, lit):
            if dd > 0.82:
                cc = ST[3] if lt else ST[0]
            elif dd > 0.6:
                cc = ST[1] if lt else ST[2]
            elif dd > 0.25:
                cc = ST[2] if lt else ST[1]
            else:
                cc = ST[3]
            if c.var == 1:
                cc = {ST[3]: A[2], ST[2]: A[1], ST[1]: A[0], ST[0]: INK}[cc]
            c.a[y, x, :3] = cc
            c.tag[y, x] = 6
        if rx >= 4 and ry >= 4:
            for k in range(5):
                a_ = k * 2 * math.pi / 5 + 0.3
                x_, y_ = int(round(cx + math.cos(a_) * rx * 0.45)), int(round(cy + math.sin(a_) * ry * 0.45))
                c.px(x_, y_, ST[0] if c.var != 1 else INK, keep=True)
            c.px(int(cx - rx * 0.12), int(cy - ry * 0.15), BONE if c.var != 1 else A[3], keep=True)
    # tyres
    lab, n = ndi.label(tyre)
    for i in range(1, n + 1):
        m = lab == i
        yy, xx = np.nonzero(m)
        if len(yy) < 20:
            continue
        cy, cx = (yy.min() + yy.max()) / 2, (xx.min() + xx.max()) / 2
        ry, rx = max(1, (yy.max() - yy.min()) / 2), max(1, (xx.max() - xx.min()) / 2)
        edge = m & ~ndi.binary_erosion(m)
        ey, ex = np.nonzero(edge)
        for y, x in zip(ey, ex):
            a_ = math.atan2(y - cy, x - cx)
            # tread blocks: alternate along the rim
            k = int((a_ + math.pi) / (2 * math.pi) * (rx + ry) * 1.6)
            if k % 2 == 0:
                c.a[y, x, :3] = A[1] if (x - cx) + (y - cy) < 0 else INK
                c.tag[y, x] = 7
        # sidewall highlight arc, upper-left
        for t in np.linspace(math.pi * 1.05, math.pi * 1.45, 10):
            x_, y_ = int(round(cx + math.cos(t) * rx * 0.74)), int(round(cy + math.sin(t) * ry * 0.74))
            c.px(x_, y_, A[2], tag=7, need=m & (c.tag != 6))


# ---------------------------------------------------------------- 4 glass
def glass(c):
    g = c.m("glass")
    lab, n = ndi.label(g)
    crack_done = False
    comps = []
    for i in range(1, n + 1):
        m = lab == i
        yy, xx = np.nonzero(m)
        if len(yy) < 6:
            continue
        comps.append((len(yy), i))
        y0, y1, x0, x1 = yy.min(), yy.max(), xx.min(), xx.max()
        # shade band under the roof edge
        top = m & ~sh(m, 1, 0)
        c.put(top, ST[0], tag=3)
        if y1 - y0 >= 4:
            c.put(sh(top, 1, 0) & m & (c.lev <= 2), ST[0], tag=3)
        # reflection: two diagonal "/" bands
        w = x1 - x0 + 1
        hgt = y1 - y0 + 1
        if w >= 4 and hgt >= 3:
            base = x0 + int(w * (0.25 + 0.3 * c.rs.rand()))
            for (off, wid, col) in ((0, 2, ST[2]), (4, 1, ST[2])):
                for y in range(y0 + 1, y1 + 1):
                    xs_ = base + off + (y1 - y)
                    for q in range(wid):
                        x = xs_ + q
                        if 0 <= x < c.W and m[y, x]:
                            c.a[y, x, :3] = col if q < wid - 1 or wid == 1 else ST[3]
                            c.tag[y, x] = 3
            # glint on the top-left corner
            c.px(x0 + 1, y0 + 1, ST[3], keep=True, need=m)
        # dust on the lower sill of the glass
        bot = m & ~sh(m, -1, 0)
        if c.var != 1:
            c.put(bot & (c.rs.rand(c.H, c.W) < 0.6), E[2], tag=3)
    # crack web in the biggest pane(s)
    comps.sort(reverse=True)
    ncr = {0: 2, 1: 0, 2: 1}[c.var]
    for _, i in comps[:6]:
        if ncr <= 0:
            break
        if c.rs.rand() < 0.4:
            continue
        m = lab == i
        yy, xx = np.nonzero(m)
        if len(yy) < 40:
            continue
        k = c.rs.randint(len(yy))
        cy, cx = yy[k], xx[k]
        for t in np.linspace(0, 2 * math.pi, 7)[:-1] + c.rs.rand():
            L = c.rs.randint(4, 11)
            for s in range(1, L):
                x, y = int(round(cx + math.cos(t) * s)), int(round(cy + math.sin(t) * s * 0.8))
                c.px(x, y, ST[3] if s % 4 else BONE, tag=3, keep=True, need=m)
        c.px(cx, cy, INK, tag=3, keep=True, need=m)
        c.px(cx + 1, cy, INK, tag=3, keep=True, need=m)
        ncr -= 1
    # shattered panes: jagged fringe of glass left in the frame, seat behind
    gb = c.m("gbroke")
    lab, n = ndi.label(gb)
    for i in range(1, n + 1):
        m = lab == i
        yy, xx = np.nonzero(m)
        if len(yy) < 8:
            continue
        y0, y1, x0, x1 = yy.min(), yy.max(), xx.min(), xx.max()
        hgt = y1 - y0 + 1
        # seat back in the lower part (cabin seen through the hole)
        if hgt >= 6 and c.var != 1:
            for y, x in zip(yy, xx):
                f = (y - y0) / hgt
                if f > 0.55:
                    c.a[y, x, :3] = CL[1] if f < 0.62 else CL[0]
                    c.tag[y, x] = 3
        elif hgt >= 6:
            # burnt-out cabin: seat frames left as bare wire
            for y, x in zip(yy, xx):
                f = (y - y0) / hgt
                if abs(f - 0.62) < 0.5 / hgt or (f > 0.62 and (x - x0) % 6 == 2):
                    c.a[y, x, :3] = A[1]
                    c.tag[y, x] = 3
        # shards: teeth hanging from the top frame and standing on the sill
        for x in range(x0, x1 + 1):
            col = np.nonzero(m[:, x])[0]
            if not len(col):
                continue
            t_, b_ = col.min(), col.max()
            lt = int(c.rs.choice([0, 0, 1, 2, 3])) if c.var != 1 else int(c.rs.choice([0, 0, 0, 1]))
            for k in range(lt):
                if m[t_ + k, x]:
                    c.a[t_ + k, x, :3] = ST[2] if k == 0 else ST[1]
            lb = int(c.rs.choice([0, 1, 1, 2, 4])) if c.var != 1 else int(c.rs.choice([0, 0, 1]))
            for k in range(lb):
                if b_ - k >= 0 and m[b_ - k, x]:
                    c.a[b_ - k, x, :3] = ST[3] if k == lb - 1 else ST[1]


# ---------------------------------------------------------------- 5 lamps
def lamps(c):
    for names, ramp in ((("lamp",), (ST[1], A[3], E[4], BONE)), (("tail",), (RU[0], BL, BL, RU[3])), (("amber",), (BR[1], BR[2], BR[2], BR[3]))):
        mm = c.m(*names)
        lab, n = ndi.label(mm)
        for i in range(1, n + 1):
            m = lab == i
            yy, xx = np.nonzero(m)
            if len(yy) < 3:
                continue
            broken = c.var >= 1 and c.rs.rand() < (0.7 if c.var == 1 else 0.5)
            inner = ndi.binary_erosion(m)
            rim = m & ~inner
            if broken:
                c.put(m, INK if c.var == 1 else A[0], tag=6)
                c.put(rim & ((sh(~m, 1, 0)) | sh(~m, 0, 1)), ST[2] if names[0] == "lamp" else ramp[1], tag=6)
                continue
            c.put(m, ramp[2], tag=6)
            c.put(rim & (sh(~m, -1, 0) | sh(~m, 0, -1)), ramp[0], tag=6)   # lower-right bezel shade
            c.put(rim & (sh(~m, 1, 0) | sh(~m, 0, 1)) & ~(sh(~m, -1, 0) | sh(~m, 0, -1)), ramp[1], tag=6)
            j = np.argmin(xx + yy)
            c.px(xx[j] + 1, yy[j] + 1, ramp[3], keep=True, need=m)
    # mirrors: chrome housings already bright; nothing extra


# ---------------------------------------------------------------- 6 plates + badges
def plates(c):
    """Generic licence plate on the bumpers (no text: INK pips) and a small
    round badge on the grille / tailgate. No brands, no wordmarks."""
    if c.name in ("tank", "apc", "trailer", "moto"):
        return
    ch = c.m("chrome", "trim")
    py = c.pos[..., 1]
    face = np.abs(c.nx) > 0.6
    zz = c.pos[..., 2]
    for sgn in (-1, 1):
        mm = ch & face & (np.sign(c.nx) == sgn) & (np.abs(py) < 0.24) & (zz < 0.8)
        ys, xs = np.nonzero(mm)
        if len(ys) < 6:
            continue
        cy, cx = int(np.median(ys)), int(np.median(xs))
        pw = max(5, min(9, xs.max() - xs.min() + 1))
        x0 = cx - pw // 2
        for y in range(cy - 1, cy + 2):
            for x in range(x0, x0 + pw):
                if 0 <= x < c.W and 0 <= y < c.H and c.a[y, x, 3]:
                    edge = y == cy + 1 or x == x0 + pw - 1
                    cc = A[2] if edge else (E[4] if c.var != 1 else A[2])
                    if y == cy and (x - x0) % 2 == 1 and 0 < x - x0 < pw - 1:
                        cc = A[1] if c.var != 1 else A[0]
                    c.a[y, x, :3] = cc
                    c.tag[y, x] = 6
                    c.keep[y, x] = True
    # badge on the grille centre
    gr = c.m("grille")
    mm = gr & (np.abs(py) < 0.12) & face
    ys, xs = np.nonzero(mm)
    if len(ys) >= 4:
        cy, cx = int(np.median(ys)), int(np.median(xs))
        for (dx, dy, cc) in ((0, 0, ST[3]), (1, 0, ST[2]), (0, 1, ST[2]), (1, 1, ST[1]), (-1, 0, ST[1]), (0, -1, BONE)):
            c.px(cx + dx, cy + dy, cc if c.var != 1 else darker(cc), keep=True)


# ---------------------------------------------------------------- 7 bullets
def bullets(c):
    paint = c.m(*PAINTS, "rust", "rust2", "scorch", "scorch2", "canvas", "steel")
    side = (np.abs(c.nz) < 0.45) & (c.pos[..., 2] > 0.35)
    ok = paint & side
    ys, xs = np.nonzero(ok)
    if not len(ys):
        return
    bursts = {0: 1, 1: 1, 2: 2}[c.var] + (1 if c.W > 300 else 0) + (2 if c.name in MIL else 0)
    for b in range(bursts):
        k = c.rs.randint(len(ys))
        y, x = ys[k], xs[k]
        ang = c.rs.uniform(-0.35, 0.35)
        nh = c.rs.randint(3, 7)
        step = c.rs.uniform(4, 8)
        for j in range(nh):
            xx = int(round(x + j * step * math.cos(ang) + c.rs.randint(-1, 2)))
            yy = int(round(y + j * step * math.sin(ang) + c.rs.randint(-1, 2)))
            if not (0 <= yy < c.H - 2 and 0 <= xx < c.W - 2 and ok[yy, xx]):
                continue
            big = c.rs.rand() < 0.5
            core = [(0, 0), (1, 0)] if big else [(0, 0)]
            for (dx, dy) in core:
                c.px(xx + dx, yy + dy, INK, tag=2, keep=True, need=ok)
            # bare-metal lip lit on the lower-right, dent shade upper-left
            c.px(xx + len(core), yy + 1, ST[3] if c.var != 1 else A[2], tag=2, keep=True, need=ok)
            c.px(xx, yy + 1, ST[2] if c.var != 1 else A[1], tag=2, keep=True, need=ok)
            c.px(xx - 1, yy, darker(c.colour(yy, max(0, xx - 1))), tag=2, need=ok & (c.tag != 2))
            if c.var != 1 and c.rs.rand() < 0.5:
                for s in range(2, 2 + c.rs.randint(2, 6)):
                    c.px(xx, yy + s, RU[1], tag=5, need=ok & (c.tag == 0))


MIL = ("tank", "apc", "humvee")


def impacts(c):
    """Military / police hulls: shell or RPG strike - soot star round a
    torn hole with a hot rust lip, radiating scorch rays."""
    if c.name not in MIL + ("police",) or c.var == 1:
        return
    ok = c.m(*PAINTS, "rust", "rust2", "canvas", "steel") & (np.abs(c.nz) < 0.6) & (c.pos[..., 2] > 0.3)
    ok = ndi.binary_erosion(ok, iterations=4)
    ys, xs = np.nonzero(ok)
    if not len(ys):
        return
    full = c.m(*PAINTS, "rust", "rust2", "canvas", "steel", "chrome", "trim")
    for _ in range(1 + (c.var == 2)):
        k = c.rs.randint(len(ys))
        cy, cx = ys[k], xs[k]
        R_ = c.rs.randint(8, 13)
        for t in np.linspace(0, 2 * math.pi, 11)[:-1] + c.rs.rand():
            L = R_ * c.rs.uniform(0.7, 1.5)
            for s_ in np.arange(1, L, 0.7):
                x, y = int(round(cx + math.cos(t) * s_)), int(round(cy + math.sin(t) * s_ * 0.75))
                col = INK if s_ < L * 0.35 else (A[0] if s_ < L * 0.7 else A[1])
                c.px(x, y, col, tag=10, need=full)
        yy, xx = np.mgrid[-R_:R_ + 1, -R_:R_ + 1]
        for dy, dx in zip(yy.ravel(), xx.ravel()):
            d = math.hypot(dx, dy / 0.75)
            if d < R_ * 0.55:
                c.px(cx + dx, cy + dy, INK if d < R_ * 0.3 else A[0], tag=10, need=full)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            c.px(cx + dx, cy + dy, INK, tag=2, keep=True)
        for dx, dy, col in ((2, 1, RU[2]), (1, 2, RU[3]), (2, 2, RU[1]), (-1, 0, RU[1]), (0, -1, RU[0])):
            c.px(cx + dx, cy + dy, col, tag=2, keep=True)


# ---------------------------------------------------------------- 8 scorch
def soot(c):
    """Burnt wrecks: soot plumes licking up from every opening (windows,
    engine bay, door holes) and a heat-tinted halo round scorched paint."""
    if c.var != 1:
        return
    src = c.m("gbroke", "well", "inside")
    op = c.op()
    nz = _noise(c.H, c.W, 4, c.rs.randint(1 << 30))
    plume = np.zeros_like(src)
    acc = src.copy()
    for k in range(14):
        acc = sh(acc, -1, 0) & op
        thr = 0.25 + k * 0.05
        acc &= nz > thr
        plume |= acc
    tgt = plume & c.m(*PAINTS, "rust", "chrome", "canvas", "steel") & (c.tag != 2)
    c.put_lev(tgt, SOOT4, tag=10)
    sc = c.m("scorch", "scorch2") | (c.tag == 10)
    paint = c.m(*PAINTS) & (c.tag == 0)
    halo1 = paint & ndi.binary_dilation(sc, iterations=1)
    halo2 = paint & ndi.binary_dilation(sc, iterations=2) & ~halo1 & (nz > 0.45)
    c.put(halo1, RU[0], tag=11)
    c.put_lev(halo2, [RU[0], RU[1], RU[1], E[1]], tag=11)


# ---------------------------------------------------------------- 9 dust
def dust(c):
    """Sand settles on horizontal surfaces (thicker away from edges and in
    the corner against a raised face); drift crests get a lit lip."""
    top = (c.nz > 0.62) & c.op()
    surf = top & c.m(*PAINTS, "rust", "rust2", "scorch", "scorch2", "canvas", "steel", "wood", "trim", "glass", "inside")
    inner = ndi.distance_transform_edt(surf)
    # wind-blown: noise stretched along x so dust lies in long thin drifts
    rs = np.random.RandomState(c.rs.randint(1 << 30))
    g = rs.rand(c.H // 3 + 3, c.W // 14 + 3)
    nz = ndi.zoom(g, (3, 14), order=3)[:c.H, :c.W]
    nz = (nz - nz.min()) / (nz.max() - nz.min() + 1e-9)
    amt = {0: 0.07, 1: 0.04, 2: 0.13}[c.var]
    up = sh(c.op() & (c.nz < 0.5), -1, 0)
    corner = ndi.binary_dilation(up & surf, iterations=2) & surf
    cov = surf & (((nz < amt) & (inner >= 3)) | (corner & (nz < amt + 0.3)))
    cov = ndi.binary_opening(cov, np.ones((2, 3))) | (cov & corner & (nz < amt + 0.2))
    cov &= ~c.keep
    ramp = SAND4 if c.var != 1 else [E[0], E[1], E[2], E[2]]
    c.put_lev(cov & (c.lev >= 2), [ramp[1], ramp[2], ramp[3], ramp[3]], tag=12)
    c.put_lev(cov & (c.lev < 2), [ramp[0], ramp[1], ramp[2], ramp[2]], tag=12)
    # kicked-up dust caked on the lower hull of military vehicles
    if c.name in ("tank", "apc", "humvee") and c.var != 1:
        side = (np.abs(c.nz) < 0.5) & c.m(*PAINTS, "rust", "rust2", "canvas")
        z = c.pos[..., 2]
        g2 = _noise(c.H, c.W, 4, c.rs.randint(1 << 30))
        band = side & (z < 0.45 + 0.25 * g2) & (z > 0.05) & ~c.keep & (c.tag != 2)
        c.put_lev(band, [E[1], E[2], E[2], E[3]], tag=12)
    # sand drift: lit crest on the top rows, wind ripples
    sand = c.m("sand")
    if sand.any():
        crest = sand & ~sh(sand | (c.op() & ~sand), 1, 0)
        c.put(crest, E[4], tag=12)
        yy_, xx_ = np.mgrid[0:c.H, 0:c.W]
        wave = (yy_ + np.round(1.6 * np.sin(xx_ / 5.5 + yy_ * 0.4))).astype(int)
        rip = sand & ~crest & (wave % 4 == 0) & (nz > 0.35)
        rip = ndi.binary_opening(rip, np.ones((1, 4)))
        c.put(rip, E[3], tag=12)
        c.put(sh(rip, 1, 0) & sand & ~rip & ~crest, E[1], tag=12)


# ---------------------------------------------------------------- 10 patches
def patch(c):
    """Jury-rigged welded plate (bible D+C): STEEL 1 plate, bevel, dotted
    weld bead, on a stripped wreck's near side."""
    if c.var != 2 or c.name in ("moto",):
        return
    paint = c.m(*PAINTS, "rust", "rust2")
    side = (c.ny > 0.6) & (c.pos[..., 2] > 0.35)
    ok = ndi.binary_erosion(paint & side, iterations=5)
    ys, xs = np.nonzero(ok)
    if not len(ys):
        return
    k = c.rs.randint(len(ys))
    cy, cx = ys[k], xs[k]
    w, hh = c.rs.randint(9, 15), c.rs.randint(6, 9)
    x0, y0 = cx - w // 2, cy - hh // 2
    region = paint & side
    for y in range(y0, y0 + hh):
        for x in range(x0, x0 + w):
            if not (0 <= y < c.H and 0 <= x < c.W) or not region[y, x]:
                continue
            e = y == y0 or x == x0 or y == y0 + hh - 1 or x == x0 + w - 1
            if e:
                cc = (A[3] if (x + y) % 2 else A[2])
            elif y == y0 + 1 or x == x0 + 1:
                cc = ST[2]
            elif y == y0 + hh - 2 or x == x0 + w - 2:
                cc = ST[0]
            else:
                cc = ST[1]
            c.a[y, x, :3] = cc
            c.tag[y, x] = 13
            c.keep[y, x] = True


# ---------------------------------------------------------------- run
def iso_clean(c):
    """Kill pixels unlike all 8 neighbours unless they are deliberate."""
    a = c.a
    op = a[..., 3] > 0
    key = (a[..., 0].astype(np.int64) << 16) | (a[..., 1].astype(np.int64) << 8) | a[..., 2]
    same = np.zeros(op.shape, int)
    cnt = np.zeros(op.shape, int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy or dx:
                same += (sh(key, dy, dx) == key) & sh(op, dy, dx)
                cnt += sh(op, dy, dx)
    n4 = sum(sh(op, dy, dx).astype(int) for dx, dy in N4)
    iso = op & (same == 0) & (n4 == 4) & (~c.keep if c.name != "moto" else True)
    for y, x in zip(*np.nonzero(iso)):
        nb = [tuple(a[y + dy, x + dx, :3]) for dx, dy in N4]
        a[y, x, :3] = max(set(nb), key=nb.count)


def cap_colours(c, cap=24):
    """Bible cap: <= 24 inner colours per prop. Merge the rarest into their
    nearest used neighbour in L* / hue."""
    a = c.a
    op = a[..., 3] > 0
    inner = op & ndi.binary_erosion(op)
    while True:
        cols, cnt = np.unique(a[inner][:, :3], axis=0, return_counts=True)
        if len(cols) <= cap - 1:   # outline may add tone-0s that also sit inside
            return
        i = np.argmin(cnt)
        src = tuple(int(v) for v in cols[i])
        best, bd = None, 1e9
        for j, cc in enumerate(cols):
            if j == i:
                continue
            cc = tuple(int(v) for v in cc)
            d = (lab_L(cc) - lab_L(src)) ** 2 + 0.002 * sum((p - q) ** 2 for p, q in zip(cc, src))
            if d < bd:
                bd, best = d, cc
        m = op & (a[..., 0] == src[0]) & (a[..., 1] == src[1]) & (a[..., 2] == src[2])
        a[m, :3] = best


STEPS = ("smooth", "panels", "rust", "streaks", "chrome", "wheels", "glass", "lamps", "plates", "bullets", "soot", "patch", "dust")


def paint(cv, G, name, var, seed, steps=STEPS):
    c = Ctx(cv, G, var, seed, name)
    if name == "moto":
        steps = [s_ for s_ in steps if s_ not in ("bullets", "plates", "patch", "streaks")]
    if "smooth" in steps:
        smooth_jaggies(c)
    rim = np.zeros((c.H, c.W), bool)
    if "panels" in steps:
        rim = panel_lines(c)
    if "rust" in steps:
        rust_edges(c)
        edge_wear(c, rim)
    if "chrome" in steps:
        chrome(c)
    if "wheels" in steps:
        wheels(c)
    if "glass" in steps:
        glass(c)
    if "lamps" in steps:
        lamps(c)
    if "plates" in steps:
        plates(c)
    if "bullets" in steps:
        impacts(c)
        bullets(c)
    if "streaks" in steps:
        rust_streaks(c)
    if "soot" in steps:
        soot(c)
    if "patch" in steps:
        patch(c)
    if "dust" in steps:
        dust(c)
    iso_clean(c)
    cap_colours(c)
    cv.a = c.a
    return cv
