"""Cleanup P3: big landmarks rebuilt as real volumes (vox.py) instead of flat
faces: collapsed floor slab on a broken wall, bunker vault in an earth berm,
army field tent, quarantine tent, giant beast skeleton, wooden watch tower,
raised guard post, crashed bush plane. Same camera, light, ramps and outline
as the vehicles; wear per D+C (spalling, rebar, stains, sand, rust)."""
import math
import numpy as np
from pk import *
import vox
from vox import Vox, rmat
from vehicles import finish_keep

M = {
    "conc": ([A[0], A[1], A[2], A[3]], False),
    "conc2": ([A[0], A[0], A[1], A[2]], False),
    "stain": ([A[0], A[1], A[1], A[2]], False),
    "rebar": ([RU[0], RU[1], RU[2], RU[3]], False),
    "brick": ([RU[0], RU[1], RU[2], RU[3]], False),
    "rust": ([RU[0], RU[1], RU[1], RU[2]], False),
    "rust2": ([RU[0], RU[0], RU[1], RU[1]], False),
    "wood": ([E[0], E[1], E[2], E[3]], False),
    "wood2": ([E[0], E[0], E[1], E[2]], False),
    "olive": ([CL[0], CL[1], CL[2], E[3]], False),
    "canvas": ([CL[0], CL[1], CL[2], CL[2]], False),
    "tarp": ([A[1], A[2], A[3], E[4]], False),
    "sand": ([E[1], E[1], E[2], E[3]], False),
    "earth": ([E[0], E[1], E[1], E[2]], False),
    "bag": ([CL[0], CL[1], CL[2], E[3]], False),
    "steel": ([ST[0], ST[1], ST[2], ST[3]], False),
    "steel2": ([ST[0], ST[0], ST[1], ST[2]], False),
    "chrome": ([ST[0], ST[1], ST[2], ST[3], E[4]], True),
    "hazard": ([BR[1], BR[2], BR[2], BR[3]], False),
    "black": ([INK, A[0], A[0], A[1]], False),
    "bone": ([E[1], E[3], E[4], E[4], BONE], True),
    "bone2": ([E[0], E[1], E[2], E[3]], False),
    "cross": ([RU[0], BL, BL, RU[2]], False),
    "white": ([A[1], A[2], A[3], E[4]], False),
    "plague": ([PL[0], PL[1], PL[2], PL[2]], False),
    "glass": ([ST[0], ST[0], ST[1], ST[2], ST[3]], True),
    "hole": ([INK, INK, INK, INK], False),
    "rim": ([A[1], A[2], A[3], A[3]], False),
    "tyre": ([INK, A[0], A[1], A[2]], False),
}


def _done(v, yaw=6.0, mirror=False, **kw):
    cv, _ = vox.render(v, yaw_deg=yaw, mirror=mirror, **kw)
    return finish_keep(cv)[0]


def _rubble(v, rs, x0, x1, y0, y1, n, mats=("conc", "conc2", "brick"), smax=0.35):
    for _ in range(n):
        s = rs.uniform(0.08, smax)
        c = (rs.uniform(x0, x1), rs.uniform(y0, y1), s * 0.35)
        v.obox(c, (s, s * rs.uniform(0.5, 1.0), s * rs.uniform(0.4, 0.8)), rmat(rs.uniform(0, 90), rs.uniform(-20, 20), rs.uniform(-20, 20)),
               mats[rs.randint(len(mats))], only="empty")


def _jagged_top(v, x0, x1, y0, y1, ztop, amp, seed):
    rs = np.random.RandomState(seed)
    pts = np.cumsum(rs.uniform(-1, 1, 64)) * amp / 4
    def fn(X, Y, Z):
        u = np.clip((X - x0) / (x1 - x0), 0, 1)
        t = ztop - amp * 0.5 + np.interp(u * 63, np.arange(64), pts)
        return Z > t
    v.region((x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, 0, ztop + amp * 2), fn, None, carve=True)


# ------------------------------------------------------------------ slab ruin
def slab_ruin():
    v = Vox(5.6, 2.8, 2.8, M)
    rs = np.random.RandomState(5)
    # broken wall stub with a window hole, brick showing where render spalled
    v.box(-1.2, 2.6, -0.85, -0.55, 0.0, 2.4, "conc")
    v.box(-0.2, 0.7, -1.0, -0.4, 0.9, 1.7, None, carve=True)
    v.box(1.4, 2.0, -1.0, -0.4, 0.0, 1.9, None, carve=True)
    _jagged_top(v, -1.2, 2.6, -0.9, -0.5, 2.3, 0.7, 3)
    v.swap_noise("conc", "brick", 0.25, 0.18, 9, region=lambda X, Y, Z: Y > -0.6)
    # the fallen floor slab, one edge on the wall, one in the dirt
    R = rmat(4, 0, 27)
    v.obox((-0.6, 0.15, 1.05), (4.0, 2.3, 0.26), R, "conc")
    v.obox((-0.6, 0.15, 0.89), (4.0, 2.3, 0.06), R, "conc2", only="solid")
    # rebar sticking out of the broken edges
    for k in range(9):
        y = -0.9 + k * 0.22
        x0 = 1.15 + rs.uniform(-0.05, 0.05)
        v.seg((x0, y, 2.05), (x0 + rs.uniform(0.2, 0.55), y + rs.uniform(-0.1, 0.1), 2.15 + rs.uniform(0.0, 0.45)), 0.025, "rebar")
    for k in range(6):
        x = -1.0 + k * 0.6
        v.seg((x, -0.7, 2.3), (x + rs.uniform(-0.15, 0.15), -0.7, 2.6 + rs.uniform(0, 0.3)), 0.025, "rebar")
    # spalling + stains + bullet pocks
    v.swap_noise("conc", "stain", 0.3, 0.2, 4, zbias=0.3, zref=2.0)
    v.holes(14, 3, lambda X, Y, Z: Y > -0.2, r=0.03, rim="rim", core="hole", only=["conc", "stain"])
    _rubble(v, rs, -2.7, 2.7, -0.3, 1.3, 46)
    v.drift(-2.8, -0.6, 1.25, 0.5, 0.3, "sand", 2)
    return _done(v, 8)


# ------------------------------------------------------------------ vault
def vault():
    v = Vox(6.0, 3.2, 3.2, M)
    rs = np.random.RandomState(8)
    # earth berm the bunker is dug into
    v.ell(0, -0.6, 0.0, 3.1, 1.7, 2.6, "earth")
    v.swap_noise("earth", "sand", 0.45, 0.3, 3)
    # concrete portal: wing walls + lintel, facing the camera
    v.box(-2.1, 2.1, 0.2, 0.95, 0.0, 2.75, "conc")
    v.box(-2.1, 2.1, 0.2, 1.05, 2.55, 2.85, "conc", r=0.04)
    v.box(-2.3, -1.8, 0.2, 1.35, 0.0, 2.2, "conc")
    v.box(1.8, 2.3, 0.2, 1.35, 0.0, 2.2, "conc")
    for x in np.arange(-2.0, 2.1, 0.5):
        v.box(x, x + 0.02, 0.94, 0.97, 0.0, 2.55, "conc2", only="solid")
    # round vault door: frame ring, door slab, locking wheel, hinge, bolts
    v.cyl("y", 0.0, 1.32, 1.18, 0.9, 1.08, "steel2")
    v.cyl("y", 0.0, 1.32, 1.0, 0.95, 1.14, "steel")
    v.cyl("y", 0.0, 1.32, 0.9, 1.13, 1.16, "steel2", only="solid")
    v.cyl("y", 0.0, 1.32, 0.86, 1.10, 1.17, "steel", only="solid")
    for a in np.linspace(0, 2 * math.pi, 14)[:-1]:
        v.cyl("y", math.cos(a) * 1.08, 1.32 + math.sin(a) * 1.08, 0.04, 1.06, 1.12, "chrome")
    v.cyl("y", 0.0, 1.32, 0.36, 1.16, 1.32, "hazard")
    v.cyl("y", 0.0, 1.32, 0.29, 1.12, 1.34, None, carve=True)
    for a in (0.4, 1.97, 3.54, 5.11):
        v.seg((math.cos(a) * 0.3, 1.27, 1.32 + math.sin(a) * 0.3), (0, 1.27, 1.32), 0.035, "hazard")
    v.cyl("y", 0.0, 1.32, 0.07, 1.16, 1.36, "chrome")
    v.box(-1.3, -1.1, 0.95, 1.2, 0.7, 1.95, "steel2")
    # hazard sill + warning lamp + rust bleeding down
    for k, x in enumerate(np.arange(-1.6, 1.6, 0.2)):
        v.box(x, x + 0.2, 0.95, 1.4, 0.0, 0.12, "hazard" if k % 2 == 0 else "black")
    v.cyl("y", 1.55, 2.3, 0.1, 0.95, 1.12, "rust")
    v.swap_noise("steel", "rust", 0.3, 0.14, 5, zbias=0.35, zref=2.4)
    v.swap_noise("conc", "stain", 0.35, 0.22, 6, zbias=0.4, zref=2.8)
    v.holes(10, 4, lambda X, Y, Z: (Y > 0.9) & (np.abs(X) > 1.3), r=0.03, only=["conc", "stain"])
    # sandbag walls flanking the sill
    for s in (-1, 1):
        for row in range(3):
            for k in range(3):
                x = s * (2.4 + k * 0.42 - row * 0.18)
                v.ell(x, 1.6, 0.13 + row * 0.22, 0.24, 0.17, 0.12, "bag")
    _rubble(v, rs, -2.8, 2.8, 1.0, 1.55, 18, mats=("conc", "conc2", "rust"))
    return _done(v, 4)


# ------------------------------------------------------------------ tents
def _tent(mat, quarantine=False):
    L, W = 4.8, 3.0
    v = Vox(L + 1.2, W + 1.4, 2.7, M)
    hw, wall, ridge = W / 2, 1.05, 2.45
    def body(X, Y, Z):
        sag = 0.08 * np.sin(np.pi * (X / (L / 2)) * 2) ** 2
        roof = ridge - (ridge - wall) * np.abs(Y) / hw - sag * (np.abs(Y) / hw)
        return (np.abs(X) <= L / 2) & (np.abs(Y) <= hw) & (Z <= np.minimum(roof, ridge))
    v.region((-L / 2, L / 2, -hw, hw, 0, ridge), body, mat)
    # panel seams down the roof, rolled-up side windows, door flaps at the left end
    for x in np.arange(-L / 2 + 0.8, L / 2, 0.8):
        v.box(x - 0.015, x + 0.015, -hw, hw, 0.0, ridge + 0.1, "canvas" if not quarantine else "steel2", only="solid")
    for x in (-1.2, 0.4, 1.6):
        v.box(x - 0.35, x + 0.35, hw - 0.04, hw + 0.04, 0.55, 0.9, "black", only="solid")
        v.cyl("x", hw + 0.03, 0.93, 0.06, x - 0.4, x + 0.4, mat)
    v.box(-L / 2 - 0.05, -L / 2 + 0.06, -0.5, 0.5, 0.0, 1.7, "black", only="solid")
    v.obox((-L / 2 - 0.05, 0.62, 0.8), (0.06, 0.55, 1.6), rmat(-35), mat)
    # ridge pole caps, guy ropes and stakes
    for x in (-L / 2, 0.0, L / 2):
        v.cyl("z", x, 0.0, 0.05, 0.0, ridge + 0.22, "wood")
    for x in np.arange(-L / 2 + 0.4, L / 2, 1.2):
        for s in (1, -1):
            v.seg((x, s * hw, wall), (x, s * (hw + 0.62), 0.03), 0.012, "wood2")
            v.box(x - 0.03, x + 0.03, s * (hw + 0.62) - 0.03, s * (hw + 0.62) + 0.03, 0.0, 0.12, "wood")
    if quarantine:
        # hazard band, plague growth creeping up the skirt, sealed door
        v.box(-L / 2, L / 2, -hw - 0.02, hw + 0.02, 0.22, 0.34, "hazard", only="solid")
        for x in np.arange(-L / 2, L / 2, 0.24):
            v.box(x, x + 0.12, -hw - 0.02, hw + 0.02, 0.22, 0.34, "black", only="solid")
        v.swap_noise(mat, "plague", 0.55, 0.12, 4, zbias=0.6, zref=0.6, region=lambda X, Y, Z: Z < 0.25)
        v.box(-0.5, 0.5, -0.5, 0.5, ridge - 0.25, ridge + 0.1, "cross", only="solid")
        v.box(-0.18, 0.18, -1.0, 1.0, ridge - 0.5, ridge + 0.1, "cross", only=[mat])
    else:
        # red cross panel on the roof (medic tent), supply crates by the door
        v.box(-0.45, 0.45, 0.25, 1.0, 0.0, 3, "white", only="solid")
        v.box(-0.12, 0.12, 0.3, 0.95, 0.0, 3, "cross", only=["white"])
        v.box(-0.4, 0.4, 0.5, 0.75, 0.0, 3, "cross", only=["white"])
        for (x, y, h_) in ((-2.9, 1.1, 0.45), (-2.9, 1.6, 0.45), (-2.9, 1.35, 0.9)):
            v.box(x - 0.25, x + 0.25, y - 0.2, y + 0.2, h_ - 0.45, h_, "wood", r=0.02)
    v.swap_noise(mat, "stain" if quarantine else "canvas", 0.3, 0.2, 7, zbias=0.4, zref=1.2)
    v.drift(-2.2, 1.8, hw + 0.05, 0.6, 0.28, "sand", 3)
    return _done(v, 10, smooth=2.6)


def field_tent():
    return _tent("olive")


def quarantine_tent():
    return _tent("tarp", quarantine=True)


# ------------------------------------------------------------------ beast ribs
def beast_ribs():
    """A giant beast's skeleton half sunk in a dune: thick vertebrae, ribs
    arching up in pairs, horned skull at the head end."""
    v = Vox(7.4, 4.4, 2.9, M)
    rs = np.random.RandomState(2)
    v.ell(0.2, 0.0, 0.0, 3.6, 1.7, 0.5, "sand")
    xs = np.linspace(-1.9, 2.7, 16)
    for i, x in enumerate(xs):
        z = 0.42 + 0.25 * math.sin(i / 15 * math.pi)
        v.ell(x, 0.0, z, 0.17, 0.2, 0.17, "bone")
        v.seg((x, 0, z), (x + 0.05, 0, z + 0.32), 0.05, "bone")
    for i, x in enumerate(np.linspace(-1.5, 1.9, 8)):
        rh = 2.1 - abs(i - 3) * 0.16
        for s in (1, -1):
            if s == 1 and i in (2, 6):
                continue  # broken ribs
            pts = []
            for t in np.linspace(0, 1, 9):
                a = t * math.pi * 0.95
                pts.append((x + 0.12 * t, s * (0.15 + 1.25 * math.sin(a * 0.9)), 0.5 + rh * math.sin(a) * (1 - 0.25 * t) - 0.35 * t))
            for p0, p1 in zip(pts[:-1], pts[1:]):
                v.seg(p0, p1, 0.11 - 0.035 * (p0[2] > 1.6), "bone")
    # broken ribs lying in the sand
    for x in (-0.5, 1.4):
        v.seg((x, 1.0, 0.45), (x + 0.9, 1.5, 0.52), 0.1, "bone")
    # skull: cranium, snout, jaw, sockets, horns
    v.ell(-2.55, 0.0, 0.75, 0.7, 0.55, 0.5, "bone")
    v.ell(-3.15, 0.0, 0.58, 0.55, 0.36, 0.3, "bone")
    v.obox((-2.95, 0.0, 0.25), (1.1, 0.5, 0.14), rmat(0, 0, -12), "bone")
    for s in (1, -1):
        v.ell(-2.75, s * 0.4, 0.85, 0.16, 0.12, 0.14, None, carve=True)
        v.ell(-2.75, s * 0.36, 0.85, 0.15, 0.12, 0.13, "black", only="solid")
        p = (-2.3, s * 0.4, 1.05)
        for k in range(6):
            q = (p[0] + 0.15, p[1] + s * 0.18, p[2] + 0.2 - 0.03 * k)
            v.seg(p, q, 0.09 - 0.012 * k, "bone")
            p = q
    for x in np.linspace(-3.55, -2.75, 6):
        v.box(x, x + 0.05, -0.3, 0.3, 0.3, 0.45, "bone2", only="solid")
    v.swap_noise("bone", "bone2", 0.25, 0.08, 3)
    v.drift(-1.0, 3.2, 0.9, 0.9, 0.45, "sand", 5)
    return _done(v, 34)


# ------------------------------------------------------------------ watch tower
def watch_tower():
    """Timber watch tower: splayed legs with X-bracing, ladder, plank deck,
    sandbag parapet, corrugated tin roof on posts."""
    v = Vox(3.2, 3.2, 4.8, M)
    deck = 2.85
    legs = [(-1.25, -1.1), (1.25, -1.1), (-1.25, 1.1), (1.25, 1.1)]
    for (x, y) in legs:
        v.seg((x * 1.12, y * 1.12, 0.0), (x * 0.9, y * 0.9, deck), 0.11, "wood")
    for z0, z1 in ((0.2, 1.5), (1.5, 2.75), (2.75, 3.95)):
        for (a, b) in ((0, 1), (2, 3), (0, 2), (1, 3)):
            pa, pb = legs[a], legs[b]
            fa = 1.12 - 0.22 * z0 / deck; fb = 1.12 - 0.22 * z1 / deck
            v.seg((pa[0] * fa, pa[1] * fa, z0), (pb[0] * fb, pb[1] * fb, z1), 0.05, "wood2")
            v.seg((pb[0] * fa, pb[1] * fa, z0), (pa[0] * fb, pa[1] * fb, z1), 0.05, "wood2")
            v.seg((pa[0] * fb, pa[1] * fb, z1), (pb[0] * fb, pb[1] * fb, z1), 0.06, "wood")
    # ladder up the front
    for s in (-0.25, 0.25):
        v.seg((s, 1.35, 0.0), (s, 1.08, deck), 0.04, "wood")
    for z in np.arange(0.3, deck, 0.32):
        y = 1.35 - 0.27 * z / deck
        v.seg((-0.25, y, z), (0.25, y, z), 0.025, "wood2")
    # deck + parapet + roof
    v.box(-1.5, 1.5, -1.4, 1.4, deck, deck + 0.14, "wood")
    for y in np.arange(-1.4, 1.4, 0.25):
        v.box(-1.5, 1.5, y, y + 0.02, deck + 0.1, deck + 0.15, "wood2", only="solid")
    for row in range(3):
        for k in range(7):
            x = -1.3 + k * 0.42 + (row % 2) * 0.2
            if x > 1.35:
                continue
            v.ell(x, 1.25, deck + 0.24 + row * 0.2, 0.22, 0.16, 0.11, "bag")
    for s in (-1, 1):
        for k in range(6):
            y = -1.2 + k * 0.42
            v.ell(s * 1.35, y, deck + 0.24, 0.15, 0.22, 0.11, "bag")
    for (x, y) in ((-1.4, -1.3), (1.4, -1.3), (-1.4, 1.3), (1.4, 1.3)):
        v.box(x - 0.06, x + 0.06, y - 0.06, y + 0.06, deck, deck + 1.55, "wood")
    def roof(X, Y, Z):
        zr = deck + 1.75 - 0.25 * (Y + 1.6) / 3.2
        return (Z <= zr) & (Z >= zr - 0.1 - 0.04 * (np.sin(X * 26) > 0))
    v.region((-1.75, 1.75, -1.65, 1.65, deck + 1.3, deck + 1.9), roof, "steel")
    v.swap_noise("steel", "rust", 0.5, 0.15, 3)
    v.swap_noise("wood", "wood2", 0.3, 0.1, 4)
    # a lamp + rag flag
    v.cyl("y", 1.3, deck + 1.35, 0.08, 1.3, 1.45, "hazard")
    return _done(v, 12)


# ------------------------------------------------------------------ guard post
def guard_post():
    """Raised sentry box on steel legs: ply walls, firing slit, tin roof,
    sandbag ring round the legs, ladder."""
    v = Vox(2.6, 2.6, 3.6, M)
    base = 1.45
    for (x, y) in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
        v.seg((x * 1.1, y * 1.1, 0), (x, y, base), 0.07, "steel")
    for (a, b) in (((-0.95, 0.95), (0.95, 0.95)), ((-0.95, -0.95), (-0.95, 0.95)), ((0.95, -0.95), (0.95, 0.95))):
        v.seg((a[0], a[1], 0.2), (b[0], b[1], base - 0.1), 0.035, "steel2")
        v.seg((b[0], b[1], 0.2), (a[0], a[1], base - 0.1), 0.035, "steel2")
    v.box(-1.05, 1.05, -1.05, 1.05, base, base + 1.25, "olive", r=0.02)
    v.box(-0.8, 0.8, 1.0, 1.1, base + 0.75, base + 0.95, "black", only="solid")
    v.box(1.0, 1.1, -0.6, 0.6, base + 0.75, base + 0.95, "black", only="solid")
    for x in np.arange(-1.0, 1.05, 0.35):
        v.box(x, x + 0.02, 1.02, 1.07, base, base + 1.25, "canvas", only="solid")
    def roof(X, Y, Z):
        zr = base + 1.6 - 0.2 * (Y + 1.3) / 2.6
        return (Z <= zr) & (Z >= zr - 0.08 - 0.04 * (np.sin(X * 26) > 0))
    v.region((-1.3, 1.3, -1.3, 1.3, base + 1.2, base + 1.7), roof, "steel")
    for s in (-0.22, 0.22):
        v.seg((s, 1.5, 0), (s, 1.08, base), 0.035, "steel")
    for z in np.arange(0.3, base, 0.3):
        y = 1.5 - 0.42 * z / base
        v.seg((-0.22, y, z), (0.22, y, z), 0.022, "steel2")
    for row in range(2):
        for k in range(12):
            a = k / 12 * 2 * math.pi
            v.ell(math.cos(a) * 1.25, math.sin(a) * 1.25, 0.13 + row * 0.22, 0.24, 0.24, 0.12, "bag", only="empty")
    v.swap_noise(["olive", "steel"], "rust", 0.3, 0.12, 6, zbias=0.3, zref=3.0)
    v.holes(8, 2, lambda X, Y, Z: Y > 0.9, r=0.03, only=["olive"])
    return _done(v, 12)


# ------------------------------------------------------------------ plane wreck
def plane_wreck():
    """Crashed high-wing bush plane: fuselage nosed into the dirt, one wing
    snapped and lying on the ground, bent prop, tail fin up."""
    v = Vox(8.2, 6.0, 2.8, M)
    def fus(X, Y, Z):
        u = np.clip((X + 2.6) / 6.8, 0, 1)
        r = 0.62 * (1 - 0.72 * u ** 1.6) * np.where(u < 0.08, 0.75 + u * 3, 1)
        zc = 0.75 + 0.55 * u
        return (X >= -2.6) & (X <= 4.2) & (((Y / (r * 0.85 + 1e-6)) ** 2 + ((Z - zc) / (r + 1e-6)) ** 2) <= 1)
    v.region((-2.7, 4.3, -0.7, 0.7, 0, 2.0), fus, "olive")
    # cockpit glazing, door, roundel stripe
    v.paint_poly([(-1.7, 1.05), (-1.3, 1.38), (-0.2, 1.38), (-0.2, 1.05)], 0.2, 1, "glass")
    v.paint_poly([(-1.7, 1.05), (-1.3, 1.38), (-0.2, 1.38), (-0.2, 1.05)], -1, -0.2, "glass")
    v.paint_poly([(-1.5, 1.2), (-1.3, 1.38), (-1.0, 1.38), (-1.1, 1.2)], -0.4, 0.4, "glass")
    v.paint_poly([(0.1, 0.45), (0.1, 1.25), (0.7, 1.25), (0.7, 0.45)], 0.3, 1, "steel2")
    v.box(1.4, 1.6, -1, 1, 0, 3, "hazard", only=["olive"])
    # wing: left half on the fuselage roof, right half snapped onto the ground
    v.obox((-0.9, -1.75, 1.6), (1.3, 3.3, 0.14), rmat(0, -6, 0), "olive")
    v.obox((-0.9, 0.0, 1.5), (1.3, 0.9, 0.14), rmat(0, 0, 0), "olive")
    v.obox((-0.75, 1.95, 0.8), (1.3, 3.0, 0.14), rmat(8, 30, 0), "olive")
    v.seg((-0.8, -0.5, 1.2), (-0.8, -2.3, 1.45), 0.04, "steel")
    v.seg((-0.8, 0.5, 1.2), (-0.6, 0.95, 0.3), 0.04, "steel")
    # tail: fin + stabiliser
    v.obox((3.8, 0.0, 1.85), (0.9, 0.08, 1.0), rmat(0, 0, -12), "olive")
    v.obox((3.9, 0.0, 1.38), (0.7, 2.0, 0.08), rmat(0, 5, 0), "olive")
    # nose: engine cowl, bent prop, gear
    v.cyl("x", 0.0, 0.62, 0.42, -2.75, -2.5, "steel2")
    v.obox((-2.82, 0.0, 0.85), (0.06, 0.12, 1.3), rmat(0, 0, 15), "steel")
    v.obox((-2.82, 0.15, 0.35), (0.06, 0.12, 0.7), rmat(20, 60, 0), "steel")
    v.seg((-1.6, 0.4, 0.4), (-1.6, 0.7, 0.05), 0.04, "steel")
    v.cyl("y", -1.6, 0.18, 0.18, 0.62, 0.78, "tyre")
    v.swap_noise("olive", "rust", 0.28, 0.18, 4, zbias=0.3, zref=1.6)
    v.holes(10, 6, lambda X, Y, Z: Y > 0.2, r=0.03, only=["olive", "rust"])
    v.drift(-3.6, -1.6, 0.7, 0.9, 0.5, "sand", 2)
    _rubble(v, np.random.RandomState(4), -3.8, -2.6, -0.8, 1.2, 10, mats=("earth", "sand", "rust"))
    return _done(v, 28)
