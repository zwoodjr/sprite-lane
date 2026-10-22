"""Voxel modeller + 3/4 top-down pixel renderer for the vehicle wrecks.

Vehicles are built from real-world dimensions (metres) as solid voxels with
one material per voxel (paint, glass, chrome, tyre, rust ...), then rendered
orthographically from the game's camera: top / roof surfaces foreshortened,
sides and fronts nearly full height. Lighting is the bible's top-left key
(same vector as pk.LV, expressed in screen space); each material shades with
its own palette ramp in 4 hard tones + an optional glint, so the output is
palette-exact pixel art at 1 texel density. pk.finish() then adds the tone-0
outline / selout and cleans orphans like every other Track A prop.

Model axes: x along the vehicle (front at -x), y across (+y = near side, the
side the camera sees), z up. 1 voxel = 1/RES m.
Screen scale: PX_X px per metre along x, PX_Y per metre of ground depth,
PX_Z per metre of height (sedan 4.8 m ~ 230 tx = 2.3 x hero)."""
import math
import numpy as np
from scipy import ndimage as ndi
from pk import Cv, LV, INK

RES = 64
PX_X, PX_Y, PX_Z = 48.0, 26.0, 57.0
# view direction (toward the camera) and screen-up, in model space
_VD = np.array([0.0, PX_Z, PX_Y]); _VD /= np.linalg.norm(_VD)
_UP = np.array([0.0, -PX_Y, PX_Z]); _UP /= np.linalg.norm(_UP)


class Vox:
    def __init__(self, L, W, H, mats, pad=0.25):
        """L, W, H: extent in metres (x -L/2..L/2, y -W/2..W/2, z 0..H)."""
        self.x0, self.y0, self.z0 = -L / 2 - pad, -W / 2 - pad, 0.0
        self.nx, self.ny, self.nz = int((L + 2 * pad) * RES), int((W + 2 * pad) * RES), int((H + pad) * RES)
        self.m = np.zeros((self.nx, self.ny, self.nz), np.uint8)
        self.names = ["_"]
        self.tones = [None]
        self.glint = [False]
        for name, (tones, gl) in mats.items():
            self.names.append(name)
            self.tones.append(tones)
            self.glint.append(gl)
        self.id = {n: i for i, n in enumerate(self.names)}

    # ------------------------------------------------------------ regions
    def _ix(self, a, a0, n):
        return int(np.clip(math.floor((a - a0) * RES), 0, n))

    def sub(self, x0, x1, y0, y1, z0, z1):
        i0, i1 = self._ix(x0, self.x0, self.nx), self._ix(x1, self.x0, self.nx) + 1
        j0, j1 = self._ix(y0, self.y0, self.ny), self._ix(y1, self.y0, self.ny) + 1
        k0, k1 = self._ix(z0, self.z0, self.nz), self._ix(z1, self.z0, self.nz) + 1
        i1, j1, k1 = min(i1, self.nx), min(j1, self.ny), min(k1, self.nz)
        X = (np.arange(i0, i1) + 0.5) / RES + self.x0
        Y = (np.arange(j0, j1) + 0.5) / RES + self.y0
        Z = (np.arange(k0, k1) + 0.5) / RES + self.z0
        return (slice(i0, i1), slice(j0, j1), slice(k0, k1)), X[:, None, None], Y[None, :, None], Z[None, None, :]

    def _apply(self, sl, mask, mat, only=None, carve=False):
        blk = self.m[sl]
        if carve:
            blk[mask] = 0
            return
        if only is not None:
            ids = [self.id[o] for o in only] if not isinstance(only, str) else ([0] if only == "empty" else ([i for i in range(1, len(self.names))] if only == "solid" else [self.id[only]]))
            mask = mask & np.isin(blk, ids)
        blk[mask] = self.id[mat] if mat else 0

    # ------------------------------------------------------------ shapes
    def extrude(self, pts, hw, mat, round_plan=0.0, round_top=0.0, taper=None, only=None, carve=False, yc=0.0):
        """Side-profile polygon pts [(x, z)] extruded across |y - yc| <= hw.
        round_plan rounds the plan corners at both x ends; round_top rounds
        the top edge; taper=(z_a, z_b, inset) pulls the sides in by `inset`
        between heights z_a..z_b (tumblehome)."""
        xs = [p[0] for p in pts]; zs = [p[1] for p in pts]
        sl, X, Y, Z = self.sub(min(xs), max(xs), yc - hw, yc + hw, min(zs), max(zs))
        prof = _poly_mask(X[:, 0, 0], Z[0, 0, :], pts)[:, None, :]
        h = np.full(prof.shape, hw, float)
        if taper:
            za, zb, ins = taper
            t = np.clip((Z - za) / max(1e-6, zb - za), 0, 1)
            h = h - ins * t
        if round_plan > 0:
            x_lo, x_hi = _span_x(X[:, 0, 0], Z[0, 0, :], prof[:, 0, :])
            dx = np.minimum(X - x_lo, x_hi - X)
            r = round_plan
            k = np.clip(r - dx, 0, r)
            h = h - (r - np.sqrt(np.maximum(0, r * r - k * k)))
        if round_top > 0:
            z_top = _top_z(X[:, 0, 0], Z[0, 0, :], prof[:, 0, :])
            dz = z_top - Z
            r = round_top
            k = np.clip(r - dz, 0, r)
            h = h - (r - np.sqrt(np.maximum(0, r * r - k * k)))
        mask = prof & (np.abs(Y - yc) <= h)
        self._apply(sl, mask, mat, only, carve)

    def box(self, x0, x1, y0, y1, z0, z1, mat, r=0.0, only=None, carve=False):
        sl, X, Y, Z = self.sub(x0, x1, y0, y1, z0, z1)
        if r <= 0:
            mask = (X >= x0) & (X <= x1) & (Y >= y0) & (Y <= y1) & (Z >= z0) & (Z <= z1)
        else:
            cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
            qx = np.abs(X - cx) - ((x1 - x0) / 2 - r)
            qy = np.abs(Y - cy) - ((y1 - y0) / 2 - r)
            qz = np.abs(Z - cz) - ((z1 - z0) / 2 - r)
            d = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2) + np.minimum(np.maximum(np.maximum(qx, qy), qz), 0)
            mask = d <= r
        self._apply(sl, mask, mat, only, carve)

    def cyl(self, axis, c1, c2, r, a0, a1, mat, only=None, carve=False, rz=None, flat_z=None):
        """Cylinder along `axis` ('x', 'y' or 'z'); (c1, c2) is the centre in
        the other two axes (x/y/z order), a0..a1 its extent along the axis."""
        rz = rz or r
        if axis == "y":
            sl, X, Y, Z = self.sub(c1 - r, c1 + r, a0, a1, c2 - rz, c2 + rz)
            mask = (((X - c1) / r) ** 2 + ((Z - c2) / rz) ** 2 <= 1) & (Y >= a0) & (Y <= a1)
            if flat_z is not None:
                mask &= Z >= flat_z
        elif axis == "x":
            sl, X, Y, Z = self.sub(a0, a1, c1 - r, c1 + r, c2 - rz, c2 + rz)
            mask = (((Y - c1) / r) ** 2 + ((Z - c2) / rz) ** 2 <= 1) & (X >= a0) & (X <= a1)
        else:
            sl, X, Y, Z = self.sub(c1 - r, c1 + r, c2 - rz, c2 + rz, a0, a1)
            mask = (((X - c1) / r) ** 2 + ((Y - c2) / rz) ** 2 <= 1) & (Z >= a0) & (Z <= a1)
        self._apply(sl, mask, mat, only, carve)

    def ell(self, cx, cy, cz, rx, ry, rz, mat, only=None, carve=False, zmin=None):
        sl, X, Y, Z = self.sub(cx - rx, cx + rx, cy - ry, cy + ry, cz - rz, cz + rz)
        mask = ((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2 + ((Z - cz) / rz) ** 2 <= 1
        if zmin is not None:
            mask &= Z >= zmin
        self._apply(sl, mask, mat, only, carve)

    def seg(self, p0, p1, r, mat, only=None, carve=False):
        """Round rod from p0 to p1 (x, y, z), radius r."""
        p0, p1 = np.array(p0, float), np.array(p1, float)
        lo, hi = np.minimum(p0, p1) - r, np.maximum(p0, p1) + r
        sl, X, Y, Z = self.sub(lo[0], hi[0], lo[1], hi[1], lo[2], hi[2])
        d = p1 - p0
        L2 = max(1e-9, d @ d)
        t = np.clip(((X - p0[0]) * d[0] + (Y - p0[1]) * d[1] + (Z - p0[2]) * d[2]) / L2, 0, 1)
        dist2 = (X - p0[0] - t * d[0]) ** 2 + (Y - p0[1] - t * d[1]) ** 2 + (Z - p0[2] - t * d[2]) ** 2
        self._apply(sl, dist2 <= r * r, mat, only, carve)

    def region(self, bbox, fn, mat, only=None, carve=False):
        """Generic shape: fn(X, Y, Z) -> bool mask over bbox (x0,x1,y0,y1,z0,z1)."""
        sl, X, Y, Z = self.sub(*bbox)
        self._apply(sl, np.broadcast_to(fn(X, Y, Z), self.m[sl].shape), mat, only, carve)

    def obox(self, c, size, R, mat, only=None, carve=False):
        """Oriented box: centre c, full size (sx, sy, sz), rotation matrix R
        (box axes -> model axes)."""
        c = np.array(c, float); hs = np.array(size, float) / 2
        ext = np.abs(R) @ hs
        sl, X, Y, Z = self.sub(c[0] - ext[0], c[0] + ext[0], c[1] - ext[1], c[1] + ext[1], c[2] - ext[2], c[2] + ext[2])
        dx, dy, dz = X - c[0], Y - c[1], Z - c[2]
        m = np.ones(self.m[sl].shape, bool)
        for k in range(3):
            u = R[0, k] * dx + R[1, k] * dy + R[2, k] * dz
            m &= np.abs(u) <= hs[k]
        self._apply(sl, m, mat, only, carve)

    def paint_poly(self, pts, y0, y1, mat, only="solid"):
        """Paint the side-profile polygon region (x, z) for y0 <= y <= y1."""
        xs = [p[0] for p in pts]; zs = [p[1] for p in pts]
        sl, X, Y, Z = self.sub(min(xs), max(xs), y0, y1, min(zs), max(zs))
        prof = _poly_mask(X[:, 0, 0], Z[0, 0, :], pts)[:, None, :]
        self._apply(sl, prof & (Y >= y0) & (Y <= y1), mat, only)

    def paint_box(self, x0, x1, y0, y1, z0, z1, mat, only="solid"):
        self.box(x0, x1, y0, y1, z0, z1, mat, only=only)

    def wheel(self, x, y_out, z, r, w, flat=0.0, bare=False, mats=("tyre", "hub", "hubc"), side=1):
        """Road wheel: tyre cylinder (y from the outer face inward), hub cap
        on the outer face. flat: fraction of radius squashed (bulge + flat
        contact). bare: rim only, no rubber (burnt)."""
        t, hb, hc = mats
        yo, yi = (y_out - w, y_out) if side > 0 else (y_out, y_out + w)
        zc = z - flat * r * 0.6
        if not bare:
            self.cyl("y", x, zc, r * (1 + flat * 0.12), yo, yi, t, flat_z=0.0, rz=r)
            rr = r * 0.52
        else:
            rr = r * 0.6
            zc = rr + 0.005
        if bare:
            hb, hc = "rust2", "hubc"
        face = (yi - 0.03, yi) if side > 0 else (yo, yo + 0.03)
        self.cyl("y", x, zc, rr, yo + 0.02, yi - 0.02, hb)
        self.cyl("y", x, zc, rr, face[0], face[1], hb)
        self.cyl("y", x, zc, rr * 0.4, face[0] - (0.01 if side < 0 else 0), face[1] + (0.01 if side > 0 else 0), hc)

    # ------------------------------------------------------------ damage
    def surface(self):
        solid = self.m > 0
        return solid & ~ndi.binary_erosion(solid, ndi.generate_binary_structure(3, 1), border_value=0)

    def noise(self, idx, scale, seed):
        """3-D value noise at voxel indices idx (3 x N), cell size `scale` m."""
        rs = np.random.RandomState(seed)
        cell = scale * RES
        g = rs.rand(int(self.nx / cell) + 3, int(self.ny / cell) + 3, int(self.nz / cell) + 3)
        g = ndi.gaussian_filter(g, 0.6)
        g = (g - g.min()) / (g.max() - g.min() + 1e-9)
        return ndi.map_coordinates(g, [i / cell for i in idx], order=1)

    def coords(self, idx):
        return (idx[0] + 0.5) / RES + self.x0, (idx[1] + 0.5) / RES + self.y0, (idx[2] + 0.5) / RES + self.z0

    def swap_noise(self, src, dst, amount, scale, seed, zbias=0.0, zref=1.0, region=None):
        """Material src -> dst on surface voxels where noise (biased toward the
        bottom by zbias) exceeds 1 - amount. Clustered: rust creeps, scorch
        blooms, never polka dots."""
        sid = [self.id[s] for s in (src if isinstance(src, (list, tuple)) else [src])]
        surf = self.surface() & np.isin(self.m, sid)
        idx = np.nonzero(surf)
        if not len(idx[0]):
            return
        n = self.noise(idx, scale, seed)
        X, Y, Z = self.coords(idx)
        n = n + zbias * (1 - np.clip(Z / zref, 0, 1))
        sel = n > 1 - amount
        if region is not None:
            sel &= region(X, Y, Z)
        if isinstance(dst, dict):
            for s, d in dst.items():
                k = sel & (self.m[idx] == self.id[s])
                self.m[idx[0][k], idx[1][k], idx[2][k]] = self.id[d]
        else:
            self.m[idx[0][sel], idx[1][sel], idx[2][sel]] = self.id[dst]

    def holes(self, n, seed, region, r=0.022, rim="rim", core="hole", only=None):
        """Bullet holes: small dark punctures with a lit bent-metal rim, on
        surface voxels inside region(X, Y, Z) facing the camera."""
        rs = np.random.RandomState(seed)
        surf = self.surface()
        if only:
            surf &= np.isin(self.m, [self.id[o] for o in only])
        idx = np.nonzero(surf)
        X, Y, Z = self.coords(idx)
        ok = np.nonzero(region(X, Y, Z))[0]
        if not len(ok):
            return
        for k in rs.choice(ok, min(n, len(ok)), replace=False):
            cx, cy, cz = X[k], Y[k], Z[k]
            self.ell(cx, cy, cz, r * 1.9, r * 2.2, r * 1.9, rim, only="solid")
            self.ell(cx, cy, cz, r, r * 2.2, r, core, only="solid")

    def drift(self, x0, x1, y_face, depth, height, mat, seed, side=1):
        """Wind-blown sand heaped against a face at y_face (dune profile)."""
        rs = np.random.RandomState(seed)
        sl, X, Y, Z = self.sub(x0, x1, min(y_face, y_face + side * depth), max(y_face, y_face + side * depth), 0, height)
        u = np.clip((X - x0) / max(1e-6, x1 - x0), 0, 1)
        ph = rs.rand() * 6
        prof = height * np.sin(np.pi * u) ** 0.7 * (0.75 + 0.25 * np.sin(u * 9 + ph))
        d = np.abs(Y - y_face) / depth
        top = prof * np.clip(1 - d, 0, 1) ** 1.3
        self._apply(sl, Z <= top, mat, only="empty")


def _poly_mask(xs, zs, pts):
    X, Z = np.meshgrid(xs, zs, indexing="ij")
    inside = np.zeros(X.shape, bool)
    n = len(pts)
    for i in range(n):
        x1, z1 = pts[i]
        x2, z2 = pts[(i + 1) % n]
        if z1 == z2:
            continue
        cond = (Z >= min(z1, z2)) & (Z < max(z1, z2))
        xint = x1 + (Z - z1) * (x2 - x1) / (z2 - z1)
        inside ^= cond & (X < xint)
    return inside


def _span_x(xs, zs, prof):
    """Per-z min / max x of the profile (for plan rounding), broadcast (x, 1, z)."""
    any_ = prof.any(0)
    lo = np.where(any_, xs[np.argmax(prof, 0)], 0)
    hi = np.where(any_, xs[len(xs) - 1 - np.argmax(prof[::-1], 0)], 0)
    return lo[None, None, :], hi[None, None, :]


def _top_z(xs, zs, prof):
    any_ = prof.any(1)
    hi = np.where(any_, zs[len(zs) - 1 - np.argmax(prof[:, ::-1], 1)], 0)
    return hi[:, None, None]


# ================================================================ render
def rmat(yaw=0.0, roll=0.0, pitch=0.0):
    """Rotation (degrees) for Vox.obox: yaw about z, roll about x, pitch about y."""
    return _rot(math.radians(yaw), math.radians(roll), math.radians(pitch)).T


def _rot(yaw, roll=0.0, pitch=0.0):
    cy, sy = math.cos(yaw), math.sin(yaw)
    Rz = np.array([[cy, sy, 0], [-sy, cy, 0], [0, 0, 1]])   # front (-x) swings toward +y
    cr, sr = math.cos(roll), math.sin(roll)
    Rx = np.array([[1, 0, 0], [0, cr, -sr], [0, sr, cr]])
    cp, sp = math.cos(pitch), math.sin(pitch)
    Ry = np.array([[cp, 0, sp], [0, 1, 0], [-sp, 0, cp]])
    return Rz @ Rx @ Ry


def render(vx, yaw_deg=14.0, mirror=False, roll_deg=0.0, pitch_deg=0.0, lift=0.0, thr=(-0.12, 0.22, 0.6, 0.92), squash=1.0, ground=False, smooth=1.25):
    """Render to a pk.Cv (uncropped, unoutlined) + footprint polygon in
    canvas px. mirror: front at +x (vehicle faces right). roll/pitch tilt the
    body (missing wheel, sunk in sand); lift raises it (m)."""
    solid = vx.m > 0
    surf = solid & ~ndi.binary_erosion(solid, ndi.generate_binary_structure(3, 1), border_value=0)
    idx = np.nonzero(surf)
    sm = ndi.gaussian_filter(solid.astype(np.float32), smooth)
    occ = ndi.gaussian_filter(solid.astype(np.float32), 3.2)
    i, j, k = idx
    def at(a, di, dj, dk):
        return a[np.clip(i + di, 0, vx.nx - 1), np.clip(j + dj, 0, vx.ny - 1), np.clip(k + dk, 0, vx.nz - 1)]
    g = np.stack([at(sm, 1, 0, 0) - at(sm, -1, 0, 0), at(sm, 0, 1, 0) - at(sm, 0, -1, 0), at(sm, 0, 0, 1) - at(sm, 0, 0, -1)], 1)
    nrm = -g / (np.linalg.norm(g, axis=1, keepdims=True) + 1e-9)
    ao = at(occ, 0, 0, 0)
    X, Y, Z = vx.coords(idx)
    P = np.stack([X, Y, Z], 1)
    if mirror:
        P[:, 0] *= -1
        nrm[:, 0] *= -1
    R = _rot(math.radians(yaw_deg), math.radians(roll_deg), math.radians(pitch_deg))
    P = P @ R.T
    nrm = nrm @ R.T
    if squash != 1.0:
        P[:, 2] *= squash
        nrm[:, 2] /= squash
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
    if ground:
        P[:, 2] -= P[:, 2].min()
    P[:, 2] += lift
    keep = P[:, 2] >= -0.004
    P, nrm, idx = P[keep], nrm[keep], tuple(a[keep] for a in idx)
    ao = ao[keep]
    # screen-space normal -> bible light (pk.LV: x right, y down, z out)
    ns = np.stack([nrm[:, 0], -(nrm @ _UP), nrm @ _VD], 1)
    v = ns @ LV
    sx = P[:, 0] * PX_X
    sy = P[:, 1] * PX_Y - P[:, 2] * PX_Z
    depth = P[:, 1] * _VD[1] + P[:, 2] * _VD[2]
    mat = vx.m[idx]
    # tone index 0 deep .. 3 lit, 4 glint
    t = np.full(len(v), 3)
    t[v < thr[2]] = 2
    t[v < thr[1]] = 1
    t[v < thr[0]] = 0
    gl = np.array(vx.glint)[mat] & (v > thr[3])
    t[gl] = 4
    # ambient occlusion: crevices and ground contact one tone down
    t = np.where((ao > 0.7) & (t < 4) & (v < 0.75), np.maximum(0, t - 1), t)
    t = np.where((P[:, 2] < 0.05) & (t < 4), np.maximum(0, t - 1), t)
    # canvas
    pad = 4
    ix = np.floor(sx).astype(int)
    iy = np.floor(sy).astype(int)
    # footprint (ground rectangle) for collision
    L = (vx.nx / RES - 0.5)
    W = (vx.ny / RES - 0.5)
    ox, oy = ix.min() - pad, iy.min() - pad
    w, h_ = ix.max() - ox + pad + 1, iy.max() - oy + pad + 1
    ix -= ox; iy -= oy
    order = np.argsort(depth, kind="stable")
    col = np.zeros((h_, w, 3), np.uint8)
    alpha = np.zeros((h_, w), np.uint8)
    dbuf = np.full((h_, w), -1e9)
    mbuf = np.zeros((h_, w), np.int32)
    tones = vx.tones
    rgb = np.zeros((len(t), 3), np.uint8)
    for mid in np.unique(mat):
        sel = mat == mid
        tl = tones[mid]
        tl5 = list(tl) + [tl[-1]] * (5 - len(tl))
        rgb[sel] = np.array(tl5, np.uint8)[t[sel]]
    # half-pixel duplicate splat (down): slopes facing the camera stretch
    # past 1 px per voxel step and would leave see-through gaps
    iy2 = np.floor(sy + 0.5).astype(int) - oy
    IX = np.concatenate([ix, ix]); IY = np.concatenate([iy2, iy])
    D = np.concatenate([depth, depth]); RGB = np.concatenate([rgb, rgb]); MT = np.concatenate([mat, mat])
    o = np.argsort(D, kind="stable")
    col[IY[o], IX[o]] = RGB[o]
    alpha[IY[o], IX[o]] = 255
    dbuf[IY[o], IX[o]] = D[o]
    mbuf[IY[o], IX[o]] = MT[o]
    # inner silhouette lines: a surface far behind its neighbour gets that
    # neighbour's deep tone (the crevice / overhang edge), 1 px.
    jump = 0.09
    out = col.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nb_d = np.roll(np.roll(dbuf, dy, 0), dx, 1)
        nb_m = np.roll(np.roll(mbuf, dy, 0), dx, 1)
        nb_a = np.roll(np.roll(alpha, dy, 0), dx, 1)
        dj = nb_d - dbuf
        edge = (alpha > 0) & (nb_a > 0) & (((dj > jump) & (nb_m != mbuf)) | (dj > jump * 3.5))
        if edge.any():
            ys, xs = np.nonzero(edge)
            for y, x in zip(ys, xs):
                tl = tones[nb_m[y, x]]
                out[y, x] = tl[0]
    out = _mode_clean(out, alpha, mbuf)
    a = np.dstack([out, alpha])
    cv = Cv(w, h_)
    cv.a = a
    return cv, (ox, oy)


def footprint(vx_len, vx_wid, yaw_deg, mirror=False, roll_deg=0.0, pitch_deg=0.0, lift=0.0, x_off=0.0):
    """Screen px corners of the ground rectangle (before canvas offset)."""
    R = _rot(math.radians(yaw_deg), math.radians(roll_deg), math.radians(pitch_deg))
    pts = []
    for sx_ in (-1, 1):
        for sy_ in (-1, 1):
            p = np.array([sx_ * vx_len / 2 + x_off, sy_ * vx_wid / 2, 0.0])
            if mirror:
                p[0] *= -1
            q = R @ p
            pts.append((q[0] * PX_X, q[1] * PX_Y - (q[2] + lift) * PX_Z))
    return pts


def _mode_clean(col, alpha, mbuf, passes=2):
    """Majority filter inside each material: kills the staircase speckle a
    voxel surface leaves after tone quantisation (pixel art has no dither on
    props < 96 px and none at all on these flat panels)."""
    H, W = alpha.shape
    key = (col[:, :, 0].astype(np.int64) << 16) | (col[:, :, 1].astype(np.int64) << 8) | col[:, :, 2]
    for _ in range(passes):
        new = key.copy()
        counts = {}
        shifts = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1)]
        nk = [np.roll(np.roll(key, dy, 0), dx, 1) for dy, dx in shifts]
        nm = [np.roll(np.roll(mbuf, dy, 0), dx, 1) for dy, dx in shifts]
        na = [np.roll(np.roll(alpha, dy, 0), dx, 1) for dy, dx in shifts]
        best = key.copy(); bestn = np.zeros_like(key)
        for a_k in nk:
            n = np.zeros_like(key)
            for b_k, b_m, b_a in zip(nk, nm, na):
                n += ((b_k == a_k) & (b_m == mbuf) & (b_a > 0)).astype(np.int64)
            upd = n > bestn
            best = np.where(upd, a_k, best); bestn = np.where(upd, n, bestn)
        own = np.zeros_like(key)
        for b_k, b_m, b_a in zip(nk, nm, na):
            own += ((b_k == key) & (b_a > 0)).astype(np.int64)
        chg = (alpha > 0) & (own <= 2) & (bestn >= 5)
        new[chg] = best[chg]
        key = new
    out = np.zeros_like(col)
    out[:, :, 0] = (key >> 16) & 255; out[:, :, 1] = (key >> 8) & 255; out[:, :, 2] = key & 255
    return out
