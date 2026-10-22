"""Vehicle wrecks modelled on real vehicle types (owner request: "model cars
and buses after real ones, not top hats with wheels").

Each type is built in vox.py from real-world proportions (game-scaled so a
sedan is ~2.3x hero length and a bus ~4x) and rendered from the game's 3/4
top-down camera, so roof, hood, windshield, grille and the near side all read.
Wear per bible D+C: rust creeping from sills and edges, broken glass, flat
tyres or bare rims, missing wheels / doors, sand drifts, bullet holes, scorch.

Types: sedan (1970s full-size), wagon (woody station wagon), police (black and
white cruiser + light bar), pickup (1970 Ford F-250 nod), school_bus,
city_bus, box_truck, semi (cab) + trailer, humvee, tank (Blackout), apc,
ambulance (Quarantine), moto (motorcycle). 3 damage variants each:
  0 worn      rust, dents, a smashed window, bullet holes, a flat
  1 burnt     scorched paint, all glass gone, bare rims, sits low
  2 stripped  a wheel gone (nose / corner down), a door gone, heavy rust, sand
"""
import math
import zlib
import numpy as np
from pk import *
from pk import _post_orphans
import vox
import vdetail as VD
from vox import Vox

# ---------------------------------------------------------------- materials
def _paint(ramp4):
    return (list(ramp4), False)


PAINTS = {
    "beige": [E[1], E[2], E[3], E[4]],
    "red": [RU[0], RU[1], RU[1], RU[2]],
    "blue": [ST[0], ST[1], ST[2], ST[3]],
    "olive": [CL[0], CL[1], CL[2], E[3]],
    "yellow": [BR[0], BR[1], BR[2], BR[3]],
    "white": [A[1], A[2], A[3], E[4]],
    "black": [INK, A[0], A[1], A[2]],
    "tan": [E[1], E[2], E[3], E[4]],
    "brown": [E[0], E[1], E[2], E[3]],
    "teal": [ST[0], ST[1], ST[2], ST[3]],
}


def mats(paint, paint2=None):
    p = PAINTS[paint]
    m = {
        "paint": (p, False),
        "seam": ([p[0], p[0], p[0], p[1]], False),
        "paint2": (PAINTS[paint2] if paint2 else p, False),
        "rust": ([RU[0], RU[1], RU[1], RU[2]], False),
        "rust2": ([RU[0], RU[0], RU[1], RU[1]], False),
        "scorch": ([INK, A[0], A[1], A[2]], False),
        "scorch2": ([INK, A[0], A[0], A[1]], False),
        "glass": ([ST[0], ST[0], ST[1], ST[2], ST[3]], True),
        "gbroke": ([INK, A[0], A[0], A[1]], False),
        "shard": ([ST[0], ST[1], ST[2], ST[3]], False),
        "inside": ([A[0], CL[0], CL[1], CL[2]], False),
        "tyre": ([INK, A[0], A[1], A[2]], False),
        "hub": ([ST[0], ST[1], ST[1], ST[2], ST[3]], True),
        "hubc": ([ST[0], ST[0], ST[1], ST[2]], False),
        "chrome": ([ST[0], ST[1], ST[2], ST[3], E[4]], True),
        "grille": ([INK, A[0], A[0], A[1]], False),
        "trim": ([INK, A[0], A[0], A[1]], False),
        "lamp": ([A[1], A[2], A[3], E[4], E[4]], True),
        "tail": ([RU[0], BL, BL, RU[2]], False),
        "amber": ([BR[1], BR[2], BR[2], BR[3]], False),
        "hole": ([INK, INK, INK, INK], False),
        "rim": ([RU[0], RU[1], RU[2], RU[3]], False),
        "well": ([INK, A[0], A[0], A[0]], False),
        "sand": ([E[1], E[1], E[2], E[3]], False),
        "wood": ([E[0], E[1], E[2], E[3]], False),
        "canvas": ([CL[0], CL[1], CL[2], CL[2]], False),
        "cross": ([RU[0], BL, BL, RU[2]], False),
        "steel": ([ST[0], ST[1], ST[2], ST[3]], False),
        "track": ([INK, A[0], A[1], A[2]], False),
    }
    return m


# ---------------------------------------------------------------- helpers
def wheel_set(v, spec, dmg):
    """spec: list of (x, r, w, y_out, z?) for the NEAR (+y) and FAR (-y)
    wheels; dmg: flat (set of idx), gone (set), bare (bool)."""
    for n, (x, r, w, yo, side) in enumerate(spec):
        if n in dmg.get("gone", ()):
            # brake drum / hub stub on the axle
            yi = yo - side * w * 0.6
            v.cyl("y", x, r, r * 0.35, min(yi, yo - side * 0.04), max(yi, yo - side * 0.04), "rust2")
            continue
        flat = 0.35 if n in dmg.get("flat", ()) else 0.0
        v.wheel(x, yo, r, r, w, flat=flat, bare=dmg.get("bare", False), side=side)


def arches(v, xs, r, hw, depth=0.42, z_top=None):
    """Cut wheel wells on both sides (outer band) and darken the wheelhouse."""
    for x in xs:
        for s in (1, -1):
            y0, y1 = (hw - depth, hw + 0.1) if s > 0 else (-hw - 0.1, -hw + depth)
            v.cyl("y", x, r, r + 0.07, y0, y1, None, carve=True, rz=r + 0.09)
            # wheelhouse wall
            yy = hw - depth if s > 0 else -hw + depth
            v.cyl("y", x, r, r + 0.07, yy - 0.04, yy + 0.04, "well", only="solid", rz=r + 0.09)
            v.cyl("y", x, r, r + 0.10, y0, y1, "well", only="solid", rz=r + 0.12)


def side_glass(v, pts, hw_in, mat="glass"):
    """Paint side windows (profile polygon) on both sides."""
    v.paint_poly(pts, hw_in, 9, mat)
    v.paint_poly(pts, -9, -hw_in, mat)


def seam_x(v, x, z0, z1, hw, mat="seam"):
    v.box(x - 0.012, x + 0.012, hw - 0.06, 9, z0, z1, mat, only="solid")
    v.box(x - 0.012, x + 0.012, -9, -hw + 0.06, z0, z1, mat, only="solid")


def seam_z(v, x0, x1, z, hw, mat="seam"):
    v.box(x0, x1, hw - 0.06, 9, z - 0.012, z + 0.012, mat, only="solid")


def door_gone(v, x0, x1, z0, z1, hw, depth=0.3):
    """Near-side door ripped off: dark cabin interior with a seat back."""
    v.box(x0, x1, hw - depth, hw + 0.2, z0, z1, None, carve=True)
    v.box(x0, x1, hw - depth - 0.05, hw - depth + 0.02, z0, z1, "inside", only="solid")
    v.box(x0 + 0.08, x0 + 0.3, hw - depth - 0.1, hw - 0.12, z0, z1 - 0.05, "inside")
    v.box(x0, x1, hw - depth - 0.1, hw - 0.05, z0 - 0.04, z0, "inside", only="solid")


def wear(v, var, seed, paint_mats=("paint", "paint2"), glass=("glass",), near=lambda X, Y, Z: Y > 0.2, zref=1.0,
         drift=None, holes=8):
    pm = list(paint_mats)
    if var == 1:
        # fire climbs: everything above the sills is burnt to black / dark
        # oxidised metal, the lowest paint survives under a heat halo
        ph = (seed % 17) * 0.37
        burn = lambda X, Y, Z: Z > zref * (0.3 + 0.07 * np.sin(X * 1.9 + ph) + 0.04 * np.sin(X * 5.3 + 2 * ph) + 0.015 * np.sin(X * 9.0))
        v.swap_noise(pm + ["seam"], "scorch", 1.0, 0.35, seed, region=burn)
        v.swap_noise(pm + ["seam"], "scorch", 0.25, 0.08, seed + 7, zbias=-0.4, zref=zref)
        v.swap_noise("scorch", "rust2", 0.3, 0.09, seed + 4)
        v.swap_noise("scorch", "scorch2", 0.35, 0.18, seed + 2)
        v.swap_noise(["chrome", "lamp", "tail", "amber", "steel"], "scorch", 0.8, 0.2, seed + 3)
        for g in glass:
            v.swap_noise(g, "gbroke", 1.1, 0.3, seed)
    else:
        # base rust only creeps up from the bottom; the hand-detail pass
        # (vdetail.py) adds edge-following rust, streaks and perforation
        v.swap_noise(pm + ["seam"], "rust", 0.03 if var == 0 else 0.1, 0.1, seed, zbias=0.5, zref=zref,
                     region=lambda X, Y, Z: Z < 0.4 * zref)
        v.swap_noise("rust", "rust2", 0.4, 0.07, seed + 5)
        for g in glass:
            v.swap_noise(g, "gbroke", 0.35 if var == 0 else 0.6, 0.35, seed + 3)
    holes = 0   # bullet holes are painted per pixel in vdetail.bullets
    if holes:
        v.holes(holes, seed, lambda X, Y, Z: near(X, Y, Z) & (Z > 0.3), only=pm + ["rust", "scorch"])
    if drift:
        for (x0, x1, yf, dp, ht) in drift:
            v.drift(x0, x1, yf, dp, ht, "sand", seed + int(x0 * 10), side=1 if yf >= 0 else -1)


# ================================================================ cars
def sedan(var, seed, paint="beige", police=False, wagon=False):
    L, W, H = 4.8, 1.9, 1.62
    M = mats("white" if police else paint, "black" if police else None)
    if wagon:
        M["paint2"] = M["wood"]
    v = Vox(L, W, H, M)
    hw = 0.95
    low = [(-2.40, 0.26), (-2.43, 0.58), (-2.38, 0.79), (-2.15, 0.85), (-0.78, 0.89), (1.45, 0.89), (2.36, 0.86),
           (2.43, 0.60), (2.40, 0.26), (2.20, 0.20), (-2.20, 0.20)]
    v.extrude(low, hw, "paint", round_plan=0.22, round_top=0.06)
    if wagon:
        gh = [(-0.80, 0.86), (-0.22, 1.34), (2.18, 1.34), (2.30, 1.26), (2.34, 0.86)]
    else:
        gh = [(-0.80, 0.86), (-0.22, 1.33), (0.92, 1.33), (1.50, 0.86)]
    v.extrude(gh, 0.9, "paint", taper=(0.88, 1.34, 0.14), round_top=0.06, round_plan=0.05)
    # windshield + rear glass on the slopes, side glass with pillars
    v.paint_poly([(-0.76, 0.9), (-0.25, 1.30), (-0.17, 1.30), (-0.66, 0.9)], -0.66, 0.66, "glass")
    v.paint_poly([(-0.70, 0.9), (-0.22, 1.29), (-0.10, 1.29), (-0.55, 0.9)], -0.66, 0.66, "glass")
    if wagon:
        v.paint_poly([(2.2, 0.92), (2.36, 0.92), (2.36, 1.28), (2.2, 1.28)], -0.62, 0.62, "glass")
        side_glass(v, [(-0.62, 0.93), (-0.2, 1.28), (0.42, 1.28), (0.42, 0.93)], 0.62)
        side_glass(v, [(0.52, 0.93), (0.52, 1.28), (1.3, 1.28), (1.3, 0.93)], 0.62)
        side_glass(v, [(1.4, 0.93), (1.4, 1.28), (2.16, 1.28), (2.22, 0.93)], 0.62)
        for x in np.arange(0.0, 2.2, 0.55):
            v.box(x, x + 0.05, -0.62, -0.56, 1.33, 1.42, "chrome")
            v.box(x, x + 0.05, 0.56, 0.62, 1.33, 1.42, "chrome")
        v.box(-0.05, 2.2, 0.56, 0.62, 1.40, 1.44, "chrome")
        v.box(-0.05, 2.2, -0.62, -0.56, 1.40, 1.44, "chrome")
    else:
        v.paint_poly([(1.48, 0.9), (0.95, 1.30), (0.86, 1.30), (1.34, 0.9)], -0.66, 0.66, "glass")
        side_glass(v, [(-0.62, 0.93), (-0.2, 1.28), (0.36, 1.28), (0.36, 0.93)], 0.62)
        side_glass(v, [(0.46, 0.93), (0.46, 1.28), (0.9, 1.28), (1.32, 0.93)], 0.62)
    # body line chrome, door seams, handles, sills
    v.box(-2.3, 2.3, hw - 0.05, hw + 0.02, 0.62, 0.645, "chrome", only="solid")
    for x in (-0.72, 0.40, 1.42 if not wagon else 2.28):
        seam_x(v, x, 0.25, 0.88, hw)
    v.box(-0.25, -0.12, hw - 0.04, hw + 0.03, 0.72, 0.75, "chrome")
    v.box(0.85, 0.98, hw - 0.04, hw + 0.03, 0.72, 0.75, "chrome")
    seam_z(v, -2.3, -0.82, 0.88, hw)
    # hood and trunk shut lines on the deck
    v.box(-0.82, -0.78, -0.85, 0.85, 0.80, 0.95, "seam", only="solid")
    if not wagon:
        v.box(1.48, 1.52, -0.85, 0.85, 0.80, 0.95, "seam", only="solid")
    # front: grille, quad lamps, chrome bumpers
    v.box(-2.5, -2.36, -0.66, 0.66, 0.46, 0.74, "grille", only="solid")
    for z in (0.52, 0.60, 0.68):
        v.box(-2.5, -2.36, -0.66, 0.66, z, z + 0.02, "chrome", only="solid")
    for y in (-0.74, -0.56, 0.56, 0.74):
        v.cyl("x", y, 0.62, 0.075, -2.48, -2.38, "lamp")
        v.cyl("x", y, 0.62, 0.075, -2.40, -2.36, "chrome", only="empty")
    v.box(-2.56, -2.36, -0.97, 0.97, 0.26, 0.44, "chrome", r=0.05)
    v.box(2.36, 2.54, -0.97, 0.97, 0.26, 0.42, "chrome", r=0.05)
    v.box(2.36, 2.46, 0.48, 0.86, 0.58, 0.76, "tail", only="solid")
    v.box(2.36, 2.46, -0.86, -0.48, 0.58, 0.76, "tail", only="solid")
    # mirror
    v.box(-0.72, -0.6, hw, hw + 0.12, 0.9, 1.0, "chrome", r=0.02)
    if police:
        # black hood / trunk / roof, white doors; roof light bar
        v.extrude(low, hw + 0.01, "paint2", only=["paint"])
        v.box(-0.74, 1.42, -2, 2, 0.24, 0.88, "paint", only=["paint2"])
        v.box(-0.1, 0.62, -0.72, 0.72, 1.33, 1.44, "trim", r=0.03)
        v.box(-0.06, 0.58, 0.06, 0.70, 1.37, 1.48, "tail", r=0.03)
        v.box(-0.06, 0.58, -0.70, -0.06, 1.37, 1.48, "steel", r=0.03)
        v.box(0.16, 0.36, -0.06, 0.06, 1.37, 1.47, "chrome")
        # push bar
        v.box(-2.66, -2.58, -0.6, 0.6, 0.3, 0.75, "trim")
        v.box(-2.66, -2.5, -0.6, -0.5, 0.3, 0.75, "trim")
        v.box(-2.66, -2.5, 0.5, 0.6, 0.3, 0.75, "trim")
    elif wagon:
        # wood-grain side panels
        v.box(-2.28, 2.3, hw - 0.04, 2, 0.38, 0.8, "paint2", only=["paint"])
        v.box(-2.28, 2.3, -2, -hw + 0.04, 0.38, 0.8, "paint2", only=["paint"])
        for x in (-2.28, 2.3):
            v.box(x - 0.02, x + 0.02, hw - 0.05, 2, 0.38, 0.8, "trim", only="solid")
        v.box(-2.28, 2.3, hw - 0.05, 2, 0.79, 0.81, "chrome", only="solid")
        v.box(-2.28, 2.3, hw - 0.05, 2, 0.37, 0.39, "chrome", only="solid")
    wx = (-1.45, 1.45)
    arches(v, wx, 0.34, hw)
    dmg = {}
    if var == 0:
        dmg = {"flat": {1}}
    elif var == 1:
        dmg = {"bare": True}
    else:
        dmg = {"gone": {0}, "flat": {3}}
    wheel_set(v, [(wx[0], 0.34, 0.22, hw - 0.02, 1), (wx[1], 0.34, 0.22, hw - 0.02, 1),
                  (wx[0], 0.34, 0.22, -hw + 0.02, -1), (wx[1], 0.34, 0.22, -hw + 0.02, -1)], dmg)
    if var == 2:
        door_gone(v, -0.7, 0.38, 0.32, 0.86, hw)
    drift = [(0.2, 2.6, hw, 0.55, 0.32)] if var == 2 else ([(-2.6, -0.4, -hw, 0.5, 0.28)] if var == 0 else None)
    wear(v, var, seed, paint_mats=("paint", "paint2"), drift=drift, holes=9 if var else 6)
    tilt = {}
    if var == 2:
        tilt = {"pitch": -4.0, "roll": -2.5}
    elif var == 1:
        tilt = {"lift": -0.12}
    return v, (L, W), tilt


def pickup(var, seed, paint="red"):
    """1970 Ford F-250: long flat hood, crisp body line, white roof, big
    chrome grille and bumper, step-side-free styleside bed, tall tyres."""
    L, W, H = 5.3, 2.0, 2.0
    M = mats(paint, "white")
    v = Vox(L, W, H, M)
    hw = 1.0
    # front clip + hood (nose at -x), cab, bed
    v.extrude([(-2.62, 0.42), (-2.66, 0.84), (-2.6, 1.14), (-0.62, 1.20), (-0.62, 0.42)], hw, "paint", round_plan=0.1, round_top=0.05)
    v.extrude([(-0.66, 0.40), (-0.66, 1.20), (-0.55, 1.22), (0.70, 1.22), (0.70, 0.40)], hw, "paint", round_top=0.04)
    v.extrude([(-0.56, 1.18), (-0.20, 1.86), (0.62, 1.86), (0.70, 1.18)], 0.96, "paint2", taper=(1.2, 1.86, 0.06), round_top=0.05)
    v.extrude([(0.78, 0.44), (0.78, 1.18), (2.62, 1.18), (2.66, 0.44)], hw, "paint", round_plan=0.06, round_top=0.03)
    v.box(0.86, 2.56, -0.88, 0.88, 0.62, 1.3, None, carve=True)
    v.box(0.86, 2.56, -0.88, 0.88, 0.58, 0.64, "wood", only="solid")
    for s_ in (1, -1):
        v.cyl("y", 1.72, 0.42, 0.56, min(s_ * 0.58, s_ * 0.9), max(s_ * 0.58, s_ * 0.9), "paint", rz=0.52)
    for y in np.arange(-0.8, 0.85, 0.2):
        v.box(0.86, 2.56, y, y + 0.02, 0.6, 0.66, "seam", only="solid")
    # glass
    v.paint_poly([(-0.52, 1.24), (-0.22, 1.80), (-0.12, 1.80), (-0.40, 1.24)], -0.86, 0.86, "glass")
    v.paint_poly([(-0.48, 1.24), (-0.20, 1.79), (-0.06, 1.79), (-0.30, 1.24)], -0.84, 0.84, "glass")
    side_glass(v, [(-0.36, 1.28), (-0.12, 1.78), (0.56, 1.78), (0.56, 1.28)], 0.8)
    v.paint_poly([(0.64, 1.30), (0.64, 1.74), (0.72, 1.74), (0.72, 1.30)], -0.6, 0.6, "glass")
    # body crease line, door seam, handle, mirror
    v.box(-2.6, 2.62, hw - 0.04, 2, 0.88, 0.90, "seam", only="solid")
    v.box(-2.6, 2.62, hw - 0.04, 2, 0.91, 0.925, "chrome", only="solid")
    seam_x(v, -0.6, 0.45, 1.2, hw)
    seam_x(v, 0.64, 0.45, 1.2, hw)
    v.box(0.42, 0.56, hw - 0.04, hw + 0.03, 1.05, 1.08, "chrome")
    v.box(-0.66, -0.56, hw, hw + 0.2, 1.3, 1.5, "chrome")
    v.box(-0.62, -0.58, hw, hw + 0.12, 1.2, 1.3, "chrome")
    v.box(-2.0, -0.7, -0.03, 0.03, 1.14, 1.22, "seam", only="solid")
    # grille (horizontal slots) + round headlights in the grille ends
    v.box(-2.72, -2.6, -0.9, 0.9, 0.62, 1.06, "grille", only="solid")
    for z in np.arange(0.66, 1.04, 0.09):
        v.box(-2.72, -2.58, -0.88, 0.88, z, z + 0.025, "chrome", only="solid")
    v.box(-2.72, -2.58, -0.04, 0.04, 0.62, 1.06, "chrome", only="solid")
    for y in (-0.7, 0.7):
        v.cyl("x", y, 0.86, 0.12, -2.72, -2.62, "chrome")
        v.cyl("x", y, 0.86, 0.085, -2.74, -2.62, "lamp")
    v.box(-2.8, -2.6, -1.02, 1.02, 0.42, 0.62, "chrome", r=0.04)
    v.box(2.62, 2.78, -1.0, 1.0, 0.42, 0.58, "chrome", r=0.04)
    v.box(2.62, 2.7, 0.8, 0.96, 0.7, 1.06, "tail", only="solid")
    v.box(2.62, 2.7, -0.96, -0.8, 0.7, 1.06, "tail", only="solid")
    seam_z(v, 2.6, 2.7, 1.0, hw)
    wx = (-1.72, 1.72)
    arches(v, wx, 0.42, hw, z_top=0.95)
    dmg = {"flat": {3}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {1}, "flat": {0}})
    wheel_set(v, [(wx[0], 0.42, 0.26, hw + 0.02, 1), (wx[1], 0.42, 0.26, hw + 0.02, 1),
                  (wx[0], 0.42, 0.26, -hw - 0.02, -1), (wx[1], 0.42, 0.26, -hw - 0.02, -1)], dmg)
    if var == 2:
        door_gone(v, -0.58, 0.62, 0.48, 1.18, hw)
        v.box(0.95, 1.5, -0.4, 0.3, 0.64, 0.95, "rust", r=0.08)  # junk in the bed
    drift = [(-2.9, -0.3, hw, 0.6, 0.38)] if var == 2 else ([(0.8, 2.9, -hw, 0.5, 0.3)] if var == 0 else None)
    wear(v, var, seed, drift=drift, zref=1.3, holes=8)
    tilt = {"pitch": 3.5, "roll": -3.0} if var == 2 else ({"lift": -0.14} if var == 1 else {})
    return v, (L, W), tilt


# ================================================================ buses / trucks
def school_bus(var, seed):
    """Conventional school bus: short hood up front, tall body, black rub
    rails, red stop arm, roof hatches, 9 side windows."""
    L, W, H = 8.6, 2.4, 2.75
    M = mats("yellow")
    v = Vox(L, W, H, M)
    hw = 1.2
    v.extrude([(-4.3, 0.48), (-4.34, 1.0), (-4.2, 1.38), (-3.15, 1.48), (-3.15, 0.48)], 0.95, "paint", round_plan=0.18, round_top=0.12)
    v.extrude([(-3.2, 0.44), (-3.2, 2.8), (4.3, 2.8), (4.3, 0.44)], hw, "paint", round_top=0.28, round_plan=0.08)
    v.box(-3.3, 4.3, -1.0, 1.0, 2.76, 2.84, "paint", r=0.03)
    # rub rails + window band
    for z in (0.78, 1.12, 1.42):
        v.box(-3.2, 4.3, hw - 0.04, 2, z, z + 0.05, "trim", only="solid")
        v.box(-3.2, 4.3, -2, -hw + 0.04, z, z + 0.05, "trim", only="solid")
    xs = np.arange(-2.4, 4.0, 0.68)
    for x in xs:
        side_glass(v, [(x, 1.6), (x, 2.24), (x + 0.56, 2.24), (x + 0.56, 1.6)], 1.08)
    # entry door (near side, front) and windshield
    v.paint_poly([(-3.1, 0.5), (-3.1, 2.36), (-2.55, 2.36), (-2.55, 0.5)], hw - 0.04, 2, "trim")
    v.paint_poly([(-3.06, 0.56), (-3.06, 2.3), (-2.84, 2.3), (-2.84, 0.56)], hw - 0.04, 2, "glass")
    v.paint_poly([(-2.80, 0.56), (-2.80, 2.3), (-2.59, 2.3), (-2.59, 0.56)], hw - 0.04, 2, "glass")
    v.box(-3.3, -3.14, -1.08, -0.04, 1.62, 2.4, "glass", only="solid")
    v.box(-3.3, -3.14, 0.04, 1.08, 1.62, 2.4, "glass", only="solid")
    v.box(4.24, 4.34, -0.9, 0.9, 1.7, 2.3, "glass", only="solid")
    v.box(4.24, 4.34, -0.25, 0.25, 0.6, 2.1, "trim", only="solid")  # rear emergency door
    # roof hatches, warning lamps
    for x in (-1.6, 1.6):
        v.box(x - 0.3, x + 0.3, -0.35, 0.35, 2.8, 2.88, "steel", r=0.02)
    for y in (-0.8, -0.5, 0.5, 0.8):
        v.cyl("x", y, 2.55, 0.08, -3.32, -3.18, "amber" if abs(y) < 0.6 else "tail")
        v.cyl("x", y, 2.55, 0.08, 4.26, 4.38, "tail")
    # hood front: grille + lamps + bumper
    v.box(-4.42, -4.26, -0.6, 0.6, 0.6, 1.24, "grille", only="solid")
    for z in np.arange(0.66, 1.2, 0.08):
        v.box(-4.42, -4.24, -0.58, 0.58, z, z + 0.02, "chrome", only="solid")
    for y in (-0.8, 0.8):
        v.cyl("x", y, 1.0, 0.13, -4.36, -4.2, "lamp")
    v.box(-4.52, -4.3, -1.2, 1.2, 0.42, 0.66, "trim", r=0.03)
    v.box(4.3, 4.46, -1.2, 1.2, 0.42, 0.62, "trim", r=0.03)
    # stop arm (folded on the near side under the driver's window line)
    v.box(-2.4, -2.0, hw, hw + 0.05, 1.5, 1.86, "tail")
    v.box(-2.36, -2.04, hw + 0.04, hw + 0.06, 1.55, 1.81, "tail")
    v.box(-2.0, -1.96, hw - 0.02, hw + 0.04, 1.6, 1.76, "steel")
    # mirrors on stalks
    v.seg((-4.0, 1.0, 1.5), (-4.4, 1.35, 1.9), 0.025, "trim")
    v.box(-4.48, -4.32, 1.3, 1.42, 1.85, 2.15, "trim", r=0.02)
    wx = (-3.55, 2.6)
    arches(v, wx, 0.48, hw)
    arches(v, (-3.55,), 0.48, 0.95)
    dmg = {"flat": {0}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {1}, "flat": {2}})
    wheel_set(v, [(wx[0], 0.48, 0.3, 0.97, 1), (wx[1], 0.48, 0.36, hw + 0.02, 1),
                  (wx[0], 0.48, 0.3, -0.97, -1), (wx[1], 0.48, 0.36, -hw - 0.02, -1)], dmg)
    drift = [(-1.0, 4.6, hw, 0.8, 0.55)] if var == 2 else ([(-3.0, 1.0, -hw, 0.6, 0.4)] if var == 0 else None)
    wear(v, var, seed, zref=2.6, drift=drift, holes=14)
    tilt = {"pitch": -2.0, "roll": -1.6} if var == 2 else ({"lift": -0.16} if var == 1 else {})
    return v, (L, W), tilt


def city_bus(var, seed, paint="teal"):
    """Transit bus: flat front with a big split windshield and destination
    sign, long window band, two door sets, roof A/C pod, two-tone livery."""
    L, W, H = 8.6, 2.45, 3.1
    M = mats(paint, "red")
    v = Vox(L, W, H, M)
    hw = 1.22
    v.extrude([(-4.3, 0.36), (-4.32, 2.7), (-4.2, 2.86), (4.24, 2.86), (4.3, 2.7), (4.3, 0.36)], hw, "paint", round_top=0.22, round_plan=0.16)
    # livery band
    v.box(-4.4, 4.4, -2, 2, 0.36, 0.95, "paint2", only=["paint"])
    v.box(-4.4, 4.4, -2, 2, 0.95, 1.0, "trim", only="solid")
    # windows
    for x in np.arange(-2.3, 4.0, 1.06):
        side_glass(v, [(x, 1.24), (x, 2.36), (x + 0.96, 2.36), (x + 0.96, 1.24)], 1.1)
    # doors: front + middle (near side)
    for x0 in (-3.95, 0.25):
        v.paint_poly([(x0, 0.4), (x0, 2.42), (x0 + 0.95, 2.42), (x0 + 0.95, 0.4)], hw - 0.04, 2, "trim")
        v.paint_poly([(x0 + 0.04, 0.5), (x0 + 0.04, 2.36), (x0 + 0.45, 2.36), (x0 + 0.45, 0.5)], hw - 0.04, 2, "glass")
        v.paint_poly([(x0 + 0.5, 0.5), (x0 + 0.5, 2.36), (x0 + 0.91, 2.36), (x0 + 0.91, 0.5)], hw - 0.04, 2, "glass")
    # front: destination sign, windshield, lamps
    v.box(-4.42, -4.24, -1.05, 1.05, 2.42, 2.7, "trim", only="solid")
    v.box(-4.42, -4.24, -0.9, 0.5, 2.5, 2.62, "amber", only="solid")
    v.box(-4.42, -4.24, -1.1, -0.03, 1.15, 2.36, "glass", only="solid")
    v.box(-4.42, -4.24, 0.03, 1.1, 1.15, 2.36, "glass", only="solid")
    for y in (-0.9, 0.9):
        v.box(-4.42, -4.26, y - 0.16, y + 0.16, 0.6, 0.76, "lamp", only="solid")
    v.box(-4.5, -4.3, -1.22, 1.22, 0.36, 0.56, "trim", r=0.04)
    v.box(4.26, 4.42, -1.0, 1.0, 1.9, 2.4, "glass", only="solid")
    v.box(4.26, 4.42, -1.1, -0.8, 0.6, 0.9, "tail", only="solid")
    v.box(4.26, 4.42, 0.8, 1.1, 0.6, 0.9, "tail", only="solid")
    v.box(-0.6, 2.2, -0.75, 0.75, 2.84, 3.04, "steel", r=0.06)
    for x in np.arange(-0.4, 2.1, 0.25):
        v.box(x, x + 0.04, -0.75, 0.75, 3.0, 3.06, "seam", only="solid")
    v.seg((-4.2, 1.15, 2.3), (-4.55, 1.3, 2.4), 0.025, "trim")
    v.box(-4.62, -4.5, 1.2, 1.36, 2.05, 2.4, "trim", r=0.02)
    wx = (-2.75, 2.45)
    arches(v, wx, 0.48, hw)
    dmg = {"flat": {1}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}, "flat": {3}})
    wheel_set(v, [(wx[0], 0.48, 0.32, hw - 0.04, 1), (wx[1], 0.48, 0.36, hw - 0.04, 1),
                  (wx[0], 0.48, 0.32, -hw + 0.04, -1), (wx[1], 0.48, 0.36, -hw + 0.04, -1)], dmg)
    drift = [(0.5, 4.6, hw, 0.8, 0.5)] if var == 2 else ([(-4.5, -1.0, -hw, 0.6, 0.4)] if var == 0 else None)
    wear(v, var, seed, zref=2.6, drift=drift, holes=14)
    tilt = {"pitch": -2.2, "roll": -1.5} if var == 2 else ({"lift": -0.16} if var == 1 else {})
    return v, (L, W), tilt


def box_truck(var, seed, paint="white"):
    """Medium-duty box truck: conventional cab, ribbed cargo box, roll-up door."""
    L, W, H = 6.4, 2.3, 3.15
    M = mats(paint)
    M["paint2"] = ([ST[0], ST[1], ST[2], ST[3]], False)
    v = Vox(L, W, H, M)
    hw = 1.0
    v.extrude([(-3.2, 0.55), (-3.24, 1.0), (-3.1, 1.3), (-2.2, 1.36), (-2.2, 0.55)], 0.95, "paint", round_plan=0.14, round_top=0.08)
    v.extrude([(-2.24, 0.52), (-2.24, 1.36), (-2.0, 2.2), (-1.5, 2.22), (-1.5, 0.52)], hw, "paint", round_top=0.08)
    v.extrude([(-1.42, 0.82), (-1.42, 3.05), (3.2, 3.05), (3.2, 0.82)], 1.15, "paint2", round_top=0.03)
    v.box(-1.42, 3.2, -1.2, 1.2, 0.6, 0.82, "trim")
    for x in np.arange(-1.3, 3.2, 0.36):
        v.box(x, x + 0.05, 1.12, 1.19, 0.86, 3.0, "steel")
        v.box(x, x + 0.05, -1.19, -1.12, 0.86, 3.0, "steel")
    v.box(-1.42, 3.2, -1.2, 1.2, 3.0, 3.1, "steel")
    v.box(3.18, 3.26, -1.05, 1.05, 0.9, 2.95, "steel")
    for z in np.arange(1.0, 2.95, 0.18):
        v.box(3.24, 3.28, -1.0, 1.0, z, z + 0.03, "seam", only="solid")
    v.paint_poly([(-2.2, 1.4), (-2.0, 2.16), (-1.92, 2.16), (-2.1, 1.4)], -0.9, 0.9, "glass")
    v.paint_poly([(-2.14, 1.4), (-1.98, 2.1), (-1.86, 2.1), (-2.0, 1.4)], -0.88, 0.88, "glass")
    side_glass(v, [(-1.98, 1.42), (-1.84, 2.1), (-1.58, 2.1), (-1.58, 1.42)], 0.9)
    seam_x(v, -1.56, 0.6, 1.4, hw)
    seam_x(v, -2.18, 0.6, 1.3, hw)
    v.box(-3.3, -3.18, -0.7, 0.7, 0.66, 1.18, "grille", only="solid")
    for z in np.arange(0.7, 1.16, 0.07):
        v.box(-3.3, -3.16, -0.68, 0.68, z, z + 0.02, "chrome", only="solid")
    for y in (-0.82, 0.82):
        v.box(-3.28, -3.12, y - 0.1, y + 0.1, 0.9, 1.08, "lamp", only="solid")
    v.box(-3.38, -3.18, -1.0, 1.0, 0.45, 0.66, "chrome", r=0.04)
    v.box(-1.95, -1.85, hw, hw + 0.3, 1.5, 1.95, "trim", r=0.02)
    wx = (-2.55, 2.2)
    arches(v, wx[:1], 0.46, hw)
    dmg = {"flat": {0}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}})
    wheel_set(v, [(wx[0], 0.46, 0.28, hw + 0.02, 1), (wx[1], 0.46, 0.5, 1.15, 1),
                  (wx[0], 0.46, 0.28, -hw - 0.02, -1), (wx[1], 0.46, 0.5, -1.15, -1)], dmg)
    if var == 2:
        door_gone(v, -2.18, -1.58, 0.6, 1.36, hw, depth=0.25)
    drift = [(-0.5, 3.4, 1.15, 0.8, 0.55)] if var == 2 else ([(-1.4, 1.5, -1.15, 0.5, 0.35)] if var == 0 else None)
    wear(v, var, seed, paint_mats=("paint", "paint2"), zref=2.6, drift=drift, holes=12, near=lambda X, Y, Z: Y > 0.5)
    tilt = {"pitch": -3.0, "roll": -1.6} if var == 2 else ({"lift": -0.15} if var == 1 else {})
    return v, (L, W), tilt


def semi(var, seed, paint="red"):
    """Long-nose semi tractor (cab + sleeper), chrome stacks, fuel tanks,
    fifth-wheel deck, tandem drive axles."""
    L, W, H = 5.8, 2.5, 3.2
    M = mats(paint)
    v = Vox(L, W, H, M)
    hw = 1.05
    v.extrude([(-2.85, 0.62), (-2.9, 1.5), (-2.78, 1.78), (-1.0, 1.86), (-1.0, 0.62)], 0.95, "paint", round_plan=0.2, round_top=0.14)
    v.extrude([(-1.05, 0.7), (-1.05, 1.86), (-0.78, 2.7), (0.4, 2.72), (0.4, 0.7)], hw, "paint", round_top=0.12)
    v.extrude([(0.36, 0.7), (0.36, 2.8), (1.35, 2.8), (1.35, 0.7)], hw, "paint", round_top=0.18)
    v.box(1.3, 2.9, -0.55, 0.55, 0.55, 0.95, "trim")
    v.cyl("z", 2.1, 0.0, 0.42, 0.95, 1.02, "steel", rz=0.42)
    # fenders over the steer axle (flared) + fuel tanks + steps
    for s in (1, -1):
        v.cyl("x", s * 0.86, 0.95, 0.22, -0.95, 0.3, "chrome", rz=0.22)
    v.paint_poly([(-1.0, 1.95), (-0.79, 2.62), (-0.67, 2.62), (-0.86, 1.95)], -0.95, 0.95, "glass")
    side_glass(v, [(-0.8, 2.0), (-0.7, 2.58), (0.3, 2.58), (0.3, 2.0)], 0.95)
    seam_x(v, -1.0, 0.75, 1.9, hw)
    seam_x(v, 0.38, 0.75, 2.9, hw)
    # big grille + lamps + bumper
    v.box(-2.98, -2.84, -0.66, 0.66, 0.72, 1.7, "chrome", only="solid")
    for z in np.arange(0.78, 1.66, 0.07):
        v.box(-2.98, -2.84, -0.6, 0.6, z, z + 0.03, "grille", only="solid")
    for y in (-0.82, 0.82):
        v.box(-2.94, -2.8, y - 0.11, y + 0.11, 1.1, 1.3, "lamp", only="solid")
    v.box(-3.08, -2.84, -1.15, 1.15, 0.5, 0.74, "chrome", r=0.05)
    # stacks
    for s in (1, -1):
        v.cyl("z", 0.48, s * 1.0, 0.07, 1.0, 3.12, "chrome")
    v.box(-1.3, -1.12, hw, hw + 0.3, 2.0, 2.5, "trim", r=0.02)
    wx = (-2.1, 1.65, 2.6)
    arches(v, wx[:1], 0.5, 0.95)
    dmg = {"flat": {0}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}})
    sp = [(wx[0], 0.5, 0.3, 0.98, 1), (wx[1], 0.5, 0.55, 1.2, 1), (wx[2], 0.5, 0.55, 1.2, 1),
          (wx[0], 0.5, 0.3, -0.98, -1), (wx[1], 0.5, 0.55, -1.2, -1), (wx[2], 0.5, 0.55, -1.2, -1)]
    wheel_set(v, sp, dmg)
    for s in (1, -1):
        v.cyl("x", s * 0.95, 0.85, 0.28, -0.85, 0.3, "chrome")
        v.cyl("x", s * 0.95, 0.85, 0.26, -0.83, 0.28, "steel", only="solid")
    drift = [(-3.2, -0.6, 1.05, 0.7, 0.5)] if var == 2 else None
    wear(v, var, seed, zref=2.6, drift=drift, holes=10)
    tilt = {"pitch": -3.0, "roll": -1.8} if var == 2 else ({"lift": -0.15} if var == 1 else {})
    return v, (L, W), tilt


def trailer(var, seed):
    """53' van trailer cut to game scale: ribbed box, landing legs, tandem."""
    L, W, H = 7.6, 2.5, 2.95
    M = mats("white")
    M["paint"] = ([ST[0], ST[1], ST[2], ST[3]], False)
    v = Vox(L, W, H, M)
    hw = 1.22
    v.box(-3.8, 3.8, -hw, hw, 1.05, 2.9, "paint", r=0.03)
    v.box(-3.8, 3.8, -hw, hw, 0.95, 1.08, "trim")
    for x in np.arange(-3.7, 3.8, 0.42):
        v.box(x, x + 0.05, hw - 0.03, hw + 0.02, 1.08, 2.85, "chrome")
        v.box(x, x + 0.05, -hw - 0.02, -hw + 0.03, 1.08, 2.85, "chrome")
    v.box(-3.8, 3.8, -hw - 0.02, hw + 0.02, 2.82, 2.9, "chrome")
    v.box(-3.8, 3.8, hw - 0.04, 2, 1.25, 1.33, "tail", only="solid")
    v.box(3.78, 3.86, -1.15, 1.15, 1.1, 2.85, "steel")
    v.box(3.82, 3.88, -0.02, 0.02, 1.1, 2.85, "seam")
    for z in (1.4, 2.55):
        v.box(3.84, 3.9, -1.0, 1.0, z, z + 0.04, "trim")
    for s in (1, -1):
        v.box(-1.9, -1.8, s * 0.9 - 0.05, s * 0.9 + 0.05, 0.0, 1.0, "steel")
        v.box(-1.96, -1.74, s * 0.9 - 0.12, s * 0.9 + 0.12, 0.0, 0.05, "steel")
    v.box(-0.5, 2.5, -0.3, 0.3, 0.75, 1.0, "trim")
    wx = (2.4, 3.3)
    dmg = {"flat": {1}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}})
    wheel_set(v, [(wx[0], 0.5, 0.55, 1.2, 1), (wx[1], 0.5, 0.55, 1.2, 1),
                  (wx[0], 0.5, 0.55, -1.2, -1), (wx[1], 0.5, 0.55, -1.2, -1)], dmg)
    v.box(3.6, 3.8, -1.25, 1.25, 0.5, 0.75, "trim")
    drift = [(-4.0, 1.5, hw, 0.9, 0.6)] if var == 2 else ([(-1.0, 3.0, -hw, 0.6, 0.4)] if var == 0 else None)
    wear(v, var, seed, zref=3.0, drift=drift, holes=12, near=lambda X, Y, Z: Y > 0.8)
    tilt = {"lift": -0.12} if var == 1 else ({"pitch": 2.0, "roll": -1.0} if var == 2 else {})
    return v, (L, W), tilt


# ================================================================ military
def humvee(var, seed, paint="olive"):
    """HMMWV: wide, low, flat-sided; flat split windshield, slanted hood with
    grille slots, tyres right out at the corners, canvas rear."""
    L, W, H = 4.7, 2.2, 1.95
    M = mats(paint)
    v = Vox(L, W, H, M)
    hw = 1.08
    v.extrude([(-2.32, 0.5), (-2.38, 0.98), (-2.25, 1.08), (-0.75, 1.18), (2.3, 1.18), (2.35, 0.5)], hw, "paint", round_top=0.03, round_plan=0.04)
    v.extrude([(-0.8, 1.15), (-0.62, 1.82), (0.75, 1.82), (0.75, 1.15)], 0.96, "paint", round_top=0.03, taper=(1.2, 1.82, 0.05))
    v.extrude([(0.72, 1.15), (0.72, 1.78), (2.25, 1.78), (2.3, 1.15)], 0.95, "canvas", round_top=0.06, taper=(1.2, 1.78, 0.06))
    for x in (1.2, 1.75):
        v.box(x - 0.02, x + 0.02, -0.97, 0.97, 1.15, 1.79, "seam", only=["canvas"])
    # flat split windshield
    v.paint_poly([(-0.78, 1.2), (-0.62, 1.76), (-0.52, 1.76), (-0.68, 1.2)], -0.88, -0.04, "glass")
    v.paint_poly([(-0.78, 1.2), (-0.62, 1.76), (-0.52, 1.76), (-0.68, 1.2)], 0.04, 0.88, "glass")
    side_glass(v, [(-0.56, 1.24), (-0.5, 1.74), (0.0, 1.74), (0.0, 1.24)], 0.86)
    side_glass(v, [(0.08, 1.24), (0.08, 1.74), (0.66, 1.74), (0.66, 1.24)], 0.86)
    for x in (-0.65, 0.04, 0.7):
        seam_x(v, x, 0.62, 1.18, hw)
    # hood slots, brush guard, lamps
    for y in np.arange(-0.6, 0.65, 0.12):
        v.box(-2.36, -2.24, y, y + 0.05, 0.66, 0.96, "grille", only="solid")
    for y in (-0.88, 0.88):
        v.box(-2.4, -2.28, y - 0.08, y + 0.08, 0.82, 0.94, "lamp", only="solid")
    v.box(-2.5, -2.36, -0.9, 0.9, 0.52, 0.66, "trim")
    v.box(-2.48, -2.4, -0.7, 0.7, 0.66, 1.0, "trim")
    v.box(-2.48, -2.4, -0.04, 0.04, 0.66, 1.0, "trim")
    v.box(-2.0, -0.95, -0.95, 0.95, 1.1, 1.22, "seam", only="solid")
    v.box(-1.95, -1.0, -0.88, 0.88, 1.18, 1.21, "paint")
    # star
    v.cyl("y", 0.0, 0.9, 0.12, hw - 0.02, hw + 0.01, "white", only="solid") if "white" in v.id else None
    wx = (-1.6, 1.62)
    arches(v, wx, 0.44, hw, depth=0.5)
    dmg = {"flat": {1}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}, "flat": {3}})
    wheel_set(v, [(wx[0], 0.44, 0.34, hw + 0.04, 1), (wx[1], 0.44, 0.34, hw + 0.04, 1),
                  (wx[0], 0.44, 0.34, -hw - 0.04, -1), (wx[1], 0.44, 0.34, -hw - 0.04, -1)], dmg)
    if var == 2:
        door_gone(v, -0.62, 0.02, 0.6, 1.16, hw)
    drift = [(0.2, 2.6, hw, 0.6, 0.4)] if var == 2 else ([(-2.5, 0.0, -hw, 0.5, 0.3)] if var == 0 else None)
    wear(v, var, seed, paint_mats=("paint", "canvas"), drift=drift, holes=10, zref=1.3)
    tilt = {"pitch": -4.0, "roll": -3.0} if var == 2 else ({"lift": -0.14} if var == 1 else {})
    return v, (L, W), tilt


def tank(var, seed, paint="tan"):
    """Main battle tank hulk: low wedge hull, side skirts over the tracks,
    angular turret with bustle, long gun (drooped / turret slewed when
    wrecked), road wheels showing under the skirts."""
    L, W, H = 6.2, 3.0, 2.3
    M = mats(paint)
    v = Vox(L + 2.2, W, H, M)
    hw = 1.5
    # tracks: belt runs the length, road wheels on the near side
    for s in (1, -1):
        y0, y1 = (hw - 0.55, hw) if s > 0 else (-hw, -hw + 0.55)
        v.extrude([(-3.0, 0.32), (-3.15, 0.6), (-2.85, 0.82), (2.95, 0.82), (3.12, 0.55), (2.95, 0.12), (-2.6, 0.12)], 0.275, "track", yc=(y0 + y1) / 2)
        for x in np.arange(-2.95, 3.1, 0.12):
            v.box(x, x + 0.04, y0, y1, 0.1, 0.84, "trim", only=["track"])
    for x in np.arange(-2.3, 2.6, 0.68):
        v.cyl("y", x, 0.34, 0.26, hw - 0.02, hw + 0.04, "steel")
        v.cyl("y", x, 0.34, 0.1, hw + 0.02, hw + 0.06, "hubc")
    # hull: glacis wedge, deck, skirts
    v.extrude([(-3.1, 0.62), (-3.15, 0.9), (-1.7, 1.25), (3.05, 1.25), (3.1, 0.7), (2.9, 0.5), (-2.9, 0.5)], hw - 0.55, "paint")
    v.extrude([(-2.95, 0.55), (-2.95, 1.0), (-1.7, 1.22), (3.0, 1.22), (3.0, 0.55)], hw - 0.05, "paint", only="empty")
    v.box(-2.9, 3.0, hw - 0.04, hw + 0.03, 0.52, 1.18, "paint", only=None)
    for x in np.arange(-2.4, 3.0, 0.62):
        seam_x(v, x, 0.52, 1.18, hw + 0.03)
    v.box(-2.9, 3.0, -hw - 0.03, -hw + 0.04, 0.52, 1.18, "paint")
    # turret (angular, wedge front), bustle rack, hatches
    tx, ry = 0.25, (6.0 if var == 1 else (-12.0 if var == 2 else 0.0))
    tur = [(-1.45, 1.25), (-1.65, 1.5), (-1.05, 1.86), (1.55, 1.9), (1.95, 1.62), (1.95, 1.25)]
    v.extrude(tur, 1.1, "paint", taper=(1.3, 1.9, 0.18), round_plan=0.25)
    v.box(1.9, 2.45, -0.95, 0.95, 1.4, 1.75, "trim")
    for x in np.arange(1.95, 2.45, 0.1):
        v.box(x, x + 0.03, -0.95, 0.95, 1.4, 1.75, "steel", only=["trim"])
    v.cyl("z", 0.55, 0.45, 0.24, 1.86, 1.98, "steel")
    v.cyl("z", 0.4, -0.45, 0.2, 1.86, 1.95, "steel")
    v.box(0.1, 0.5, -0.65, -0.25, 1.92, 2.08, "steel", r=0.03)
    # gun: mantlet + barrel with fume extractor; droops when wrecked
    droop = {0: 0.0, 1: -0.18, 2: 0.25}[var]
    v.box(-1.85, -1.4, -0.36, 0.36, 1.4, 1.75, "paint", r=0.04)
    gy = {0: 0.0, 1: 0.0, 2: 0.35}[var]
    v.seg((-1.8, 0.0, 1.58), (-4.15, gy, 1.58 + droop), 0.085, "steel")
    v.seg((-2.7, 0.0, 1.58 + droop * 0.38), (-3.1, gy * 0.55, 1.58 + droop * 0.55), 0.13, "steel")
    # tow hooks, lamps, track guards
    for y in (-1.1, 1.1):
        v.box(-3.25, -3.1, y - 0.12, y + 0.12, 0.75, 0.9, "trim")
    dmg = {}
    drift = [(-1.0, 3.3, hw + 0.05, 0.9, 0.6)] if var == 2 else ([(-3.2, -1.0, -hw, 0.6, 0.45)] if var == 0 else None)
    if var == 1:
        v.box(-1.4, 1.9, -1.2, 1.2, 1.88, 2.2, None, carve=True)  # turret top blown open
    wear(v, var, seed, paint_mats=("paint",), glass=(), drift=drift, holes=8, zref=1.8, near=lambda X, Y, Z: Y > 0.5)
    if var == 1:
        v.swap_noise("track", "scorch2", 0.6, 0.2, seed)
    tilt = {"pitch": 1.5, "roll": -1.8} if var == 2 else {}
    return v, (L + 0.3, W), tilt


def apc(var, seed, paint="olive"):
    """Tracked APC (M113-like): slab-sided aluminium box, sloped front,
    trim vane, cupola with a gun shield, rear ramp."""
    L, W, H = 5.0, 2.65, 2.35
    M = mats(paint)
    v = Vox(L, W, H, M)
    hw = 1.3
    for s in (1, -1):
        y0, y1 = (hw - 0.45, hw) if s > 0 else (-hw, -hw + 0.45)
        v.extrude([(-2.35, 0.32), (-2.5, 0.55), (-2.25, 0.72), (2.4, 0.72), (2.55, 0.5), (2.35, 0.1), (-2.0, 0.1)], 0.225, "track", yc=(y0 + y1) / 2)
        for x in np.arange(-2.4, 2.6, 0.11):
            v.box(x, x + 0.04, y0, y1, 0.08, 0.74, "trim", only=["track"])
    for x in np.arange(-1.85, 2.1, 0.75):
        v.cyl("y", x, 0.32, 0.25, hw - 0.02, hw + 0.04, "steel")
        v.cyl("y", x, 0.32, 0.09, hw + 0.02, hw + 0.06, "hubc")
    v.extrude([(-2.5, 0.55), (-2.6, 1.0), (-1.55, 1.85), (2.5, 1.85), (2.5, 0.55)], hw - 0.2, "paint", round_top=0.02)
    v.box(-2.2, 2.5, hw - 0.22, hw + 0.04, 0.72, 0.9, "paint")
    v.box(-2.2, 2.5, -hw - 0.04, -hw + 0.22, 0.72, 0.9, "paint")
    v.box(-2.66, -2.56, -1.0, 1.0, 0.95, 1.25, "trim")
    for y in np.arange(-0.9, 1.0, 0.3):
        v.box(-2.68, -2.6, y, y + 0.04, 0.95, 1.25, "steel", only=["trim"])
    v.cyl("z", 0.0, 0.25, 0.42, 1.85, 2.02, "steel")
    v.box(-0.55, -0.42, -0.3, 0.8, 1.98, 2.3, "steel")
    v.seg((-0.4, 0.25, 2.12), (-1.5, 0.25, 2.1 - (0.15 if var else 0)), 0.04, "trim")
    v.box(0.6, 1.4, -0.7, 0.2, 1.84, 1.9, "seam", only="solid")
    v.box(2.48, 2.56, -0.9, 0.9, 0.62, 1.78, "steel")
    for x in np.arange(-1.6, 2.5, 0.8):
        seam_x(v, x, 0.95, 1.85, hw - 0.2)
    for y in (-0.95, 0.95):
        v.box(-2.4, -2.2, y - 0.08, y + 0.08, 1.2, 1.32, "lamp", only="solid")
    drift = [(-0.5, 2.8, hw, 0.8, 0.5)] if var == 2 else ([(-2.7, -0.5, -hw, 0.6, 0.4)] if var == 0 else None)
    if var == 2:
        v.box(2.3, 2.6, -0.85, 0.85, 0.6, 1.75, None, carve=True)
        v.box(2.3, 3.4, -0.85, 0.85, 0.1, 0.2, "steel")  # ramp down
    wear(v, var, seed, glass=(), drift=drift, holes=10, zref=1.8, near=lambda X, Y, Z: Y > 0.5)
    if var == 1:
        v.swap_noise("track", "scorch2", 0.6, 0.2, seed)
    return v, (L, W), ({"pitch": 1.5, "roll": -1.5} if var == 2 else {})


# ================================================================ service
def ambulance(var, seed):
    """Type III ambulance: van cab + square patient module, red stripe and
    cross, light bar, corner lamps."""
    L, W, H = 5.9, 2.25, 2.95
    M = mats("white")
    v = Vox(L, W, H, M)
    hw = 1.02
    v.extrude([(-2.95, 0.5), (-3.0, 0.9), (-2.85, 1.15), (-2.0, 1.28), (-2.0, 0.5)], 0.95, "paint", round_plan=0.16, round_top=0.1)
    v.extrude([(-2.05, 0.46), (-2.05, 1.28), (-1.62, 2.12), (-1.1, 2.16), (-1.1, 0.46)], hw, "paint", round_top=0.1)
    v.extrude([(-1.15, 0.6), (-1.15, 2.85), (2.95, 2.85), (2.95, 0.6)], 1.12, "paint", round_top=0.06)
    v.box(-1.15, 2.95, -1.12, 1.12, 1.15, 1.32, "cross", only=["paint"])
    v.box(-2.1, -1.15, -2, 2, 0.95, 1.08, "cross", only=["paint"])
    # crosses on the side and roof
    for (cx, cz) in ((0.9, 2.12),):
        v.box(cx - 0.32, cx + 0.32, 1.08, 1.14, cz - 0.1, cz + 0.1, "cross", only="solid")
        v.box(cx - 0.1, cx + 0.1, 1.08, 1.14, cz - 0.32, cz + 0.32, "cross", only="solid")
    v.box(0.6, 1.4, -0.12, 0.12, 2.8, 2.9, "cross", only="solid")
    v.box(0.88, 1.12, -0.4, 0.4, 2.8, 2.9, "cross", only="solid")
    v.paint_poly([(-2.0, 1.32), (-1.66, 2.06), (-1.58, 2.06), (-1.9, 1.32)], -0.9, 0.9, "glass")
    v.paint_poly([(-1.94, 1.32), (-1.64, 2.0), (-1.5, 2.0), (-1.78, 1.32)], -0.88, 0.88, "glass")
    side_glass(v, [(-1.62, 1.38), (-1.5, 1.98), (-1.18, 1.98), (-1.18, 1.38)], 0.9)
    seam_x(v, -1.98, 0.5, 1.28, hw)
    # module: side door, compartment doors, corner lamps
    v.paint_poly([(-0.95, 0.66), (-0.95, 2.4), (-0.25, 2.4), (-0.25, 0.66)], 1.08, 2, "seam")
    v.paint_poly([(-0.9, 0.72), (-0.9, 2.34), (-0.3, 2.34), (-0.3, 0.72)], 1.08, 2, "paint")
    v.paint_poly([(-0.86, 1.7), (-0.86, 2.24), (-0.34, 2.24), (-0.34, 1.7)], 1.08, 2, "glass")
    for x0 in (1.6, 2.25):
        v.paint_poly([(x0, 0.66), (x0, 1.1), (x0 + 0.55, 1.1), (x0 + 0.55, 0.66)], 1.08, 2, "seam")
    for (x, y) in ((-1.15, 1.06), (-1.15, -1.06), (2.95, 1.06), (2.95, -1.06)):
        v.box(x - 0.06, x + 0.06, y - 0.08, y + 0.08, 2.6, 2.78, "tail", only="solid")
    v.box(-1.95, -1.25, -0.8, 0.8, 2.12, 2.26, "trim", r=0.03)
    v.box(-1.92, -1.6, 0.05, 0.75, 2.18, 2.3, "tail", r=0.02)
    v.box(-1.92, -1.6, -0.75, -0.05, 2.18, 2.3, "tail", r=0.02)
    v.box(2.92, 3.0, -0.02, 0.02, 0.62, 2.8, "seam")
    v.box(3.0, 3.1, -0.9, 0.9, 1.6, 2.2, "glass", only=None)
    v.box(-3.08, -2.95, -0.62, 0.62, 0.62, 1.0, "grille", only="solid")
    for z in np.arange(0.66, 0.98, 0.07):
        v.box(-3.08, -2.93, -0.6, 0.6, z, z + 0.02, "chrome", only="solid")
    for y in (-0.8, 0.8):
        v.box(-3.04, -2.92, y - 0.12, y + 0.12, 0.84, 0.98, "lamp", only="solid")
    v.box(-3.16, -2.95, -1.0, 1.0, 0.44, 0.62, "chrome", r=0.04)
    v.box(-1.85, -1.75, hw, hw + 0.25, 1.4, 1.75, "trim", r=0.02)
    wx = (-2.45, 1.9)
    arches(v, wx[:1], 0.4, 0.95)
    arches(v, wx[1:], 0.4, 1.12)
    dmg = {"flat": {1}} if var == 0 else ({"bare": True} if var == 1 else {"gone": {0}})
    wheel_set(v, [(wx[0], 0.4, 0.26, 0.97, 1), (wx[1], 0.4, 0.4, 1.12, 1),
                  (wx[0], 0.4, 0.26, -0.97, -1), (wx[1], 0.4, 0.4, -1.12, -1)], dmg)
    if var == 2:
        v.box(-0.9, -0.3, 0.85, 1.3, 0.72, 2.34, None, carve=True)   # side door torn off
        v.box(-0.9, -0.3, 0.8, 0.87, 0.72, 2.34, "inside", only="solid")
        v.box(-0.88, -0.35, 0.5, 0.85, 0.66, 0.95, "white" if "white" in v.id else "lamp")
    drift = [(0.0, 3.2, 1.12, 0.8, 0.5)] if var == 2 else ([(-3.0, -0.6, -hw, 0.5, 0.35)] if var == 0 else None)
    wear(v, var, seed, zref=2.6, drift=drift, holes=10, near=lambda X, Y, Z: Y > 0.5)
    tilt = {"pitch": -3.5, "roll": -1.8} if var == 2 else ({"lift": -0.14} if var == 1 else {})
    return v, (L, W), tilt


def moto(var, seed, paint="red"):
    """Motorcycle: standing on its kickstand (worn), or dumped on its side."""
    L, W, H = 2.2, 0.85, 1.2
    M = mats(paint)
    v = Vox(L, W, H, M)
    r = 0.32
    for x in (-0.74, 0.74):
        if var == 1:
            v.cyl("y", x, r, r, -0.06, 0.06, "hub")
            v.cyl("y", x, r, r * 0.86, -0.07, 0.07, None, carve=True)
            for a in np.linspace(0, math.pi, 7)[:-1]:
                v.seg((x + math.cos(a) * r * 0.85, 0, r + math.sin(a) * r * 0.85), (x - math.cos(a) * r * 0.85, 0, r - math.sin(a) * r * 0.85), 0.012, "hub")
        else:
            v.cyl("y", x, r, r, -0.07, 0.07, "tyre")
            v.cyl("y", x, r, r * 0.66, -0.08, 0.08, "hub")
            v.cyl("y", x, r, r * 0.22, -0.09, 0.09, "hubc")
    # fork + frame + engine + tank + seat + bars
    v.seg((-0.74, 0, r), (-0.5, 0, 0.98), 0.035, "chrome")
    v.seg((-0.5, 0, 0.98), (0.1, 0, 0.82), 0.035, "trim")
    v.seg((-0.42, 0, 0.62), (0.74, 0, r), 0.035, "trim")
    v.box(-0.32, 0.12, -0.16, 0.16, 0.3, 0.62, "steel", r=0.05)
    for x in (-0.24, -0.12, 0.0):
        v.box(x, x + 0.04, -0.18, 0.18, 0.4, 0.6, "chrome", only="solid")
    v.ell(-0.22, 0, 0.84, 0.32, 0.17, 0.12, "paint")
    v.box(0.05, 0.7, -0.14, 0.14, 0.72, 0.84, "trim", r=0.04)
    v.ell(0.72, 0, 0.62, 0.3, 0.14, 0.05, "paint")
    v.seg((-0.52, -0.38, 1.08), (-0.52, 0.38, 1.08), 0.022, "chrome")
    v.seg((-0.5, 0, 0.98), (-0.52, 0, 1.08), 0.03, "chrome")
    v.cyl("x", 0, 0.92, 0.08, -0.7, -0.6, "lamp")
    v.seg((-0.1, 0.18, 0.32), (0.9, 0.2, 0.42), 0.045, "chrome")
    if var != 1:
        v.seg((0.0, 0.18, 0.35), (0.12, 0.4, 0.0), 0.02, "steel")
    wear(v, var, seed, glass=(), holes=2, zref=1.0, near=lambda X, Y, Z: Y > -1)
    if var == 2:
        return v, (L, 0.6), {"roll": -78.0, "lift": 0.1}
    return v, (L, 0.6), {"roll": -9.0}


# ================================================================ build
TYPES = {
    # name: (builder, kwargs per variant, yaw per variant, mirror per variant, size class)
    "sedan": (sedan, [{"paint": "beige"}, {"paint": "beige"}, {"paint": "blue"}]),
    "sedan_red": (sedan, [{"paint": "red"}, {"paint": "red"}, {"paint": "olive"}]),
    "wagon": (sedan, [{"paint": "brown", "wagon": True}, {"paint": "beige", "wagon": True}, {"paint": "blue", "wagon": True}]),
    "police": (sedan, [{"police": True}] * 3),
    "pickup": (pickup, [{"paint": "red"}, {"paint": "blue"}, {"paint": "olive"}]),
    "school_bus": (school_bus, [{}] * 3),
    "city_bus": (city_bus, [{"paint": "teal"}, {"paint": "white"}, {"paint": "teal"}]),
    "box_truck": (box_truck, [{"paint": "white"}, {"paint": "red"}, {"paint": "beige"}]),
    "semi": (semi, [{"paint": "red"}, {"paint": "blue"}, {"paint": "white"}]),
    "trailer": (trailer, [{}] * 3),
    "humvee": (humvee, [{"paint": "olive"}, {"paint": "tan"}, {"paint": "olive"}]),
    "tank": (tank, [{"paint": "tan"}, {"paint": "olive"}, {"paint": "tan"}]),
    "apc": (apc, [{"paint": "olive"}, {"paint": "tan"}, {"paint": "olive"}]),
    "ambulance": (ambulance, [{}] * 3),
    "moto": (moto, [{"paint": "red"}, {"paint": "blue"}, {"paint": "black"}]),
}
YAW = [16.0, -14.0, 20.0]      # per variant; negative = front turned away (rear toward camera)
MIRROR = [False, True, True]


def finish_keep(cv):
    """pk.finish without the crop, returning the crop offset."""
    for _ in range(3):
        remove_orphans(cv)
    rim0 = ~cv.opaque()
    outline(cv, None)
    _post_orphans(cv, rim0)
    m = cv.opaque()
    ys, xs = np.nonzero(m)
    x0, y0 = xs.min(), ys.min()
    out = crop(cv)
    return out, (int(x0), int(y0))


def make(name, var, seed=None, detail=True, steps=None):
    """Voxel base render + hand-pixel detail layer (vdetail.py). The canvas,
    crop, footprint and y-sort anchors are fixed by the undamaged model, so
    dents / torn hoods never move collision or sorting."""
    fn, kws = TYPES[name]
    seed = seed if seed is not None else (zlib.crc32(name.encode()) % 997) * 7 + var * 31
    v, (L, W), tilt = fn(var, seed, **kws[var])
    yaw = YAW[var] * min(1.0, 5.6 / L)
    mir = MIRROR[var]
    rk = dict(yaw_deg=yaw, mirror=mir, roll_deg=tilt.get("roll", 0.0), pitch_deg=tilt.get("pitch", 0.0), lift=tilt.get("lift", 0.0))
    fp = vox.footprint(L, W, yaw, mir, tilt.get("roll", 0.0), tilt.get("pitch", 0.0))
    if not detail:
        cv, (ox, oy) = vox.render(v, **rk)
        out, (cx, cy) = finish_keep(cv)
        fp = [(x - ox - cx, y - oy - cy) for (x, y) in fp]
        return out, fp
    frame, al0 = vox.frame_of(v, **rk)
    ox, oy = frame[0], frame[1]
    ys, xs = np.nonzero(al0)
    cx, cy = int(xs.min()) - 1, int(ys.min()) - 1          # outline adds 1 px
    cw, ch = int(xs.max()) - cx + 2, int(ys.max()) - cy + 2
    VD.vox_pass(v, name, var, seed, (L, W))
    cv, _, G = vox.render(v, frame=frame, gbuf=True, **rk)
    for _ in range(3):
        remove_orphans(cv)
    VD.paint(cv, G, name, var, seed, **({"steps": steps} if steps else {}))
    cv.a[:, :, 3] = np.where(cv.a[:, :, 3] > 0, 255, 0)
    outline(cv, None)
    out = Cv(cw, ch)
    out.a = cv.a[cy:cy + ch, cx:cx + cw].copy()
    fp = [(x - ox - cx, y - oy - cy) for (x, y) in fp]
    return out, fp


# ================================================================ composites
def _rend(fn, var, seed, kw, yaw, mirror=False, **rk):
    v, (L, W), tilt = fn(var, seed, **kw)
    r = dict(roll_deg=tilt.get("roll", 0.0), pitch_deg=tilt.get("pitch", 0.0), lift=tilt.get("lift", 0.0))
    r.update(rk)
    cv, _ = vox.render(v, yaw_deg=yaw, mirror=mirror, **r)
    out, _ = finish_keep(cv)
    return out


def _stack(layers, W, H):
    """Paste finished sprites bottom-up: [(cv, x, y_bottom)]."""
    cv = Cv(W, H)
    for c, x, yb in layers:
        paste(cv, c, int(x), int(yb - c.h))
    return crop(cv)


def wreck_pile():
    """Scrapyard stack: three crushed cars (a sedan, a wagon on its roof, a
    pickup cab) and loose tyres."""
    a = _rend(sedan, 0, 41, {"paint": "blue"}, 10, squash=0.6, lift=-0.1)
    b = _rend(sedan, 1, 43, {"paint": "beige", "wagon": True}, -8, True, squash=0.55, roll_deg=180, ground=True)
    c = _rend(sedan, 0, 47, {"paint": "red"}, 22, squash=0.6, pitch_deg=8, ground=True)
    W, H = 330, 200
    t = vox_tyre()
    return _stack([(a, 20, 196), (b, 60, 150), (c, 95, 108), (t, 0, 198), (t, 268, 198)], W, H)


def vox_tyre():
    M = mats("black")
    v = Vox(0.8, 0.8, 0.3, M)
    v.cyl("z", 0, 0, 0.34, 0.0, 0.24, "tyre")
    v.cyl("z", 0, 0, 0.17, 0.0, 0.3, None, carve=True)
    v.cyl("z", 0, 0, 0.17, 0.0, 0.05, "hubc")
    cv, _ = vox.render(v, 0)
    return finish_keep(cv)[0]


def buried_wreck():
    """Drift: a sedan nose-down in a dune, rear wheels in the air."""
    car = _rend(sedan, 0, 53, {"paint": "red"}, 24, pitch_deg=-28, ground=True, lift=-0.75)
    M = mats("beige")
    v = Vox(4.6, 2.8, 1.0, M)
    v.ell(0, 0, 0.0, 2.3, 1.35, 0.95, "sand")
    surf = v.surface()
    idx = np.nonzero(surf)
    n = v.noise(idx, 0.25, 7)
    X, Y, Z = v.coords(idx)
    rip = (n > 0.72) & (Z > 0.2)
    v.m[idx[0][rip], idx[1][rip], idx[2][rip]] = v.id["wood"]
    dn, _ = vox.render(v, 0)
    dune, _ = finish_keep(dn)
    W, H = 340, 240
    return _stack([(car, 70, 200), (dune, 0, 236)], W, H)
