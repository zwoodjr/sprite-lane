"""Pet puppet bake: Zach's painted 3/4 dog art (tools/art_src/pets_sheet.png)
cut out, split into parts and posed by a small 2D rig, baked into the same
strips the game plays (assets/sprites/pets/<id>/<id>_<state>.png).

  * cutout: white panel flood-filled from the border, the white fringe
    un-mixed against the fur 3 px inside, floating FX dropped (largest blob)
  * parts: head, two ear flaps, body (+ collar), tail, four legs split at
    the knee, extras (tag, satchel ...) with their own pivots; hidden areas
    filled by cloning real fur (no blur), joints overlap with soft edges
  * poses per state (2-bone IK on every leg), composed at 2x the 256 px
    frame, box-filtered down, alpha thresholded (hard edge, no halo),
    specks opened away, mirrored to face right like every unit strip
  * size, centre and feet line are matched to the dog's live strip (rig
    TARGET); frame counts come from the strips already in the pet folder,
    so fps sidecars and pet.gd stay as they are. Pets with hd=2 in
    pet_defs draw these 256 px frames at the usual world size.

    python3 tools/pet_puppet.py [noel bentley lillie] [--out DIR] [--states walk,idle] [--no-portrait]

Per-dog rigs live in tools/pet_rigs/<id>.py (polygons and joints in the
dog's panel pixels). Portraits: assets/sprites/portraits/pet_<id>.png,
rendered from the cutout with gen_portraits.render.
"""
import importlib
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, ".."))
SHEET = os.path.join(HERE, "art_src", "pets_sheet.png")
PETS = os.path.join(GAME, "assets", "sprites", "pets")
PORTRAITS = os.path.join(GAME, "assets", "sprites", "portraits")
FS = 256            # frame size (hd = 2)
CW = FS * 2         # compose canvas
sys.path.insert(0, HERE)


# ================================================================ cutout
def cutout(panel):
    x0, y0, x1, y1 = panel
    src = np.asarray(Image.open(SHEET).convert("RGB"))
    c = src[y0:y1, x0:x1].astype(np.float32)
    f = c.astype(np.int32)
    white = (f.min(-1) >= 226) & ((f.max(-1) - f.min(-1)) < 20)
    lab, _ = ndi.label(white)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ndi.binary_fill_holes(~np.isin(lab, list(border)))
    l2, n2 = ndi.label(fg)
    fg = l2 == (np.argmax(ndi.sum(fg, l2, range(1, n2 + 1))) + 1)
    inner = ndi.binary_erosion(fg, iterations=3)
    _, (iy, ix) = ndi.distance_transform_edt(~inner, return_indices=True)
    fur = c[iy, ix]
    ring = fg & ~inner
    a_est = np.clip(((255.0 - c) / np.maximum(255.0 - fur, 12.0)).mean(-1), 0, 1)
    fg = fg & (~ring | (a_est >= 0.5))
    fg = ndi.binary_opening(fg, iterations=1) | (fg & inner)
    col = c.copy()
    mix = ring & fg & (a_est < 0.95)
    col[mix] = fur[mix] * 0.55 + np.clip((c[mix] - 255 * (1 - a_est[mix, None])) / np.maximum(a_est[mix, None], 0.5), 0, 255) * 0.45
    edge1 = fg & ~ndi.binary_erosion(fg)
    col[edge1] = np.minimum(col[edge1], fur[edge1] * 0.6)
    return col, fg.astype(np.float32)


# ================================================================ math
def rot(deg, about, to):
    a = math.radians(deg)
    c_, s_ = math.cos(a), math.sin(a)
    return np.array([[c_, -s_, to[0] - (c_ * about[0] - s_ * about[1])],
                     [s_, c_, to[1] - (s_ * about[0] + c_ * about[1])], [0, 0, 1]], np.float64)


def ap(M, p):
    return (M[0, 0] * p[0] + M[0, 1] * p[1] + M[0, 2], M[1, 0] * p[0] + M[1, 1] * p[1] + M[1, 2])


def ang(v):
    return math.degrees(math.atan2(v[1], v[0]))


def ik(s, t, l1, l2, side):
    """Knee between s and t; side +1 puts it toward +x of the s->t midpoint."""
    dx, dy = t[0] - s[0], t[1] - s[1]
    d = max(1e-3, min(math.hypot(dx, dy), l1 + l2 - 1e-3))
    a = math.atan2(dy, dx)
    b = math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    best = None
    for sg in (1, -1):
        k = (s[0] + math.cos(a + sg * b) * l1, s[1] + math.sin(a + sg * b) * l1)
        score = (k[0] - (s[0] + dx * 0.5)) * side
        if best is None or score > best[0]:
            best = (score, k)
    return best[1]


# ================================================================ rig
class Dog:
    def __init__(self, pid):
        R = importlib.import_module("pet_rigs." + pid).RIG
        self.id, self.R = pid, R
        col, A = cutout(R["panel"])
        self.col, self.A = col, A
        H, W = A.shape
        self.H, self.W = H, W
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        self.yy, self.xx = yy, xx
        poly = self.poly
        ry = lambda y0, y1: np.clip((yy - y0) / max(1e-3, y1 - y0), 0, 1)
        rx = lambda x0, x1: np.clip((xx - x0) / max(1e-3, x1 - x0), 0, 1)
        P = {}
        body_a = np.ones((H, W), np.float32)
        F = 10
        self.legs = R["legs"]
        for k, L in self.legs.items():
            x0, x1 = L["x"]
            colm = poly([(x0, L["cut"] - F), (x1, L["cut"] - F), (x1, H), (x0, H)])
            top = ry(L["cut"] - F, L["cut"]) if L["near"] else ry(L["cut"] - F - 2, L["cut"] - F)
            leg = colm * top
            kn = L["knee"][1]
            P[k + "_u"] = self.part(leg * (1 - ry(kn + 6, kn + 7)))
            P[k + "_l"] = self.part(leg * ry(kn - 6, kn + 2))
            body_a -= colm * ry(L["cut"] - (F if not L["near"] else 1), L["cut"])
        body_a = np.clip(body_a, 0, 1)
        T = R["tail"]
        tail_m = poly(T["poly"])
        P["tail"] = self.part(tail_m * rx(T["base_x"], T["base_x"] + 10))
        body_a *= 1 - tail_m * rx(T["base_x"] + 10, T["base_x"] + 16)
        Hd = R["head"]
        head_m = poly(Hd["poly"])
        fc, fr = Hd["face"]
        face = ((((xx - fc[0]) / fr[0]) ** 2 + ((yy - fc[1]) / fr[1]) ** 2) <= 1).astype(np.float32)
        ears_out = np.zeros((H, W), np.float32)
        ears_all = np.zeros((H, W), np.float32)
        for k, E in R["ears"].items():
            m = poly(E["poly"])
            P[k] = self.part(m)
            ears_out = np.maximum(ears_out, m * (1 - face))
            ears_all = np.maximum(ears_all, m)
        P["head"] = self.part(head_m * (1 - ears_out))
        nc, nr = Hd["neck"]
        neck = (((xx - nc[0]) / nr[0]) ** 2 + ((yy - nc[1]) / nr[1]) ** 2) <= 1
        body_rgb = col.copy()
        hole = (head_m > 0) & neck
        hy, hx = np.nonzero(hole)
        cx0, cx1 = Hd.get("neck_src_x", (0, W - 1))
        body_rgb[hy, hx] = col[np.clip(hy + Hd["neck_clone_dy"], 0, H - 1), np.clip(hx, cx0, cx1)]
        body_mask = np.where(head_m > 0, neck.astype(np.float32), 1.0) * body_a
        body_mask *= 1 - ears_all * (head_m == 0)        # ear tips live on the ear flaps only
        self.extras = []
        for E in R.get("extras", []):
            m = poly(E["poly"]) * (A > 0)
            if "keep" in E:
                m = m * E["keep"](col)
            P[E["name"]] = self.part(m)
            if E.get("clone_dy"):
                ey, ex = np.nonzero(m > 0)
                body_rgb[ey, ex] = col[np.clip(ey + E["clone_dy"], 0, H - 1), ex]
            self.extras.append(E)
        P["body"] = self.part(body_mask, body_rgb)
        self.P = P
        # size / placement matched to the live strip
        ys, xs = np.nonzero(A)
        tg = R["target"]
        self.sc = tg["h"] / float(ys.max() - ys.min() + 1) * 2       # src -> canvas (2x)
        self.src_feet = float(ys.max())
        self.src_cx = (xs.min() + xs.max()) / 2.0
        # mirrored later: canvas centre = 2 * (FS - cx)
        self.anch = (2.0 * (FS - tg["cx"]), 2.0 * tg["feet"])

    def poly(self, pts):
        m = np.zeros((self.H, self.W), np.uint8)
        cv2.fillPoly(m, [np.array(pts, np.int32)], 1)
        return m.astype(np.float32)

    def part(self, alpha, rgb=None):
        rgb = self.col if rgb is None else rgb
        a = np.clip(alpha, 0, 1) * self.A
        return np.dstack([rgb * a[..., None], a * 255]).astype(np.float32)

    # ------------------------------------------------------------ poses
    def pose(self, state, i, n):
        R = self.R
        t = i / n
        tw = math.sin(2 * math.pi * t)
        p = dict(dx=0.0, dy=0.0, body=0.0, head=0.0, hdx=0.0, ear=0.0, tail=0.0, swing=0.0,
                 feet={k: tuple(L["paw"]) for k, L in self.legs.items()}, breathe=0.0, sit=0.0)

        def gait(stride, lift, phase_t, far_lag=0.0):
            ph = {}
            for k, L in self.legs.items():
                diag = (k in ("FL", "BN"))
                q = (phase_t + (0.0 if diag else 0.5) + (far_lag if not L["near"] else 0.0)) % 1
                x0, y0 = L["paw"]
                if q < 0.5:
                    fx, fy = x0 - stride / 2 + stride * (q / 0.5), y0
                else:
                    r = (q - 0.5) / 0.5
                    fx = x0 + stride / 2 - stride * (0.5 - 0.5 * math.cos(math.pi * r))
                    fy = y0 - lift * math.sin(math.pi * r)
                ph[k] = (fx, fy)
            return ph

        if state == "idle":
            p["breathe"] = tw
            p["dy"] = 0.6 * tw
            p["head"] = 1.5 * math.sin(2 * math.pi * t + 0.8)
            p["ear"] = -2.0 * math.sin(2 * math.pi * t + 0.2)
            p["tail"] = 14 * math.sin(4 * math.pi * t)
            p["swing"] = 4 * math.sin(4 * math.pi * t + 1)
        elif state == "walk":
            p["feet"] = gait(30.0, 12.0, t, far_lag=0.08)
            p["dy"] = -2.5 * abs(math.sin(2 * math.pi * t))
            # lean into the travel direction and lead with the head
            p["body"] = -2.5 + 1.2 * math.sin(2 * math.pi * t)
            p["head"] = 3.0 - 2.0 * math.sin(4 * math.pi * t + 0.5)
            p["hdx"] = -4.0
            p["ear"] = 4.0 * math.sin(4 * math.pi * t - 0.6)
            p["tail"] = 10 * math.sin(2 * math.pi * t)
            p["swing"] = 8 * math.sin(4 * math.pi * t - 1.0)
        elif state == "charge":
            p["feet"] = gait(44.0, 18.0, t, far_lag=0.1)
            p["dy"] = -5.0 * abs(math.sin(2 * math.pi * t)) + 3
            p["body"] = -5 + 2 * math.sin(2 * math.pi * t)
            p["head"], p["hdx"] = -8.0, -8.0
            p["ear"] = 12.0
            p["tail"] = -8 + 8 * math.sin(4 * math.pi * t)
            p["swing"] = 10 * math.sin(4 * math.pi * t)
        elif state in ("sit", "sit_idle"):
            s = 1.0 if state == "sit_idle" else min(1.0, (i + 1) / n)
            s = 0.5 - 0.5 * math.cos(math.pi * s)
            p["sit"] = s
            p["body"] = 26 * s
            p["dy"] = 4 * s
            p["head"] = -20 * s
            p["tail"] = 22 * s
            if state == "sit_idle":
                p["breathe"] = tw
                p["head"] += 2.0 * math.sin(2 * math.pi * t + 0.8)
                p["ear"] = -2.5 * math.sin(2 * math.pi * t + 0.2)
                p["tail"] += 8 * math.sin(4 * math.pi * t)
                p["swing"] = 3 * math.sin(4 * math.pi * t + 1)
        elif state == "windup":
            k = math.sin(0.5 * math.pi * min(1.0, (i + 1) / n))
            p["dx"], p["dy"], p["body"], p["head"] = 10 * k, 6 * k, 6 * k, 8 * k
            p["ear"], p["tail"] = -6 * k, -10 * k
        elif state in ("attack", "impact"):
            prof = [0.3, 0.8, 1.0, 1.0, 0.6, 0.2] if n >= 6 else [1.0, 0.85, 0.45, 0.15]
            k = prof[i % len(prof)]
            head = 10 if state == "attack" else -14          # bite vs headbutt
            p["dx"], p["dy"], p["body"], p["head"] = -26 * k, 2 * k, 5 * k, head * k
            p["ear"], p["tail"], p["swing"] = 10 * k, 12 * k, -12 * k
            for kk, L in self.legs.items():
                x0, y0 = L["paw"]
                front = kk[0] == "F"
                p["feet"][kk] = (x0 - (28 * k if front else -8 * k), y0 - (10 * k if front else 0))
        elif state in ("rampage", "bark"):
            k = abs(math.sin(2 * math.pi * t))
            if state == "bark":                              # head-up bark bob
                pulse = max(0.0, math.sin(2 * math.pi * t * (2 if n >= 6 else 1))) ** 2
                p["dy"] = -3 * pulse
                p["head"] = 4 + 12 * pulse
                p["ear"] = 8 * pulse
                p["body"] = -2 * pulse
                p["tail"] = 14 * math.sin(4 * math.pi * t)
                p["swing"] = 6 * pulse
            else:
                p["dy"] = -8 * k
                p["head"] = -10 * math.sin(4 * math.pi * t)
                p["ear"] = 9 * math.sin(4 * math.pi * t - 0.8)
                p["body"] = 3 * math.sin(2 * math.pi * t)
                p["tail"] = 18 * math.sin(4 * math.pi * t)
                p["swing"] = 12 * math.sin(4 * math.pi * t)
                for kk, L in self.legs.items():
                    x0, y0 = L["paw"]
                    front = kk[0] == "F"
                    p["feet"][kk] = (x0 + (-6 if front else 6) * k, y0 - (6 * k if front else 0))
        elif state == "drop":                                # nose down, drop the find, back up
            k = math.sin(math.pi * min(1.0, (i + 0.5) / n))
            p["body"] = -6 * k
            p["head"] = -22 * k
            p["hdx"] = -4 * k
            p["dy"] = 3 * k
            p["ear"] = 8 * k
            p["tail"] = 16 * math.sin(4 * math.pi * t)
            p["swing"] = 10 * k
        elif state == "hit":
            k = [1.0, 0.8, 0.45, 0.15][i % 4]
            p["dx"], p["body"], p["head"], p["ear"] = 10 * k, -6 * k, -12 * k, -10 * k
            p["tail"], p["swing"] = -14 * k, 10 * k
        elif state == "death":
            q = (i + 1) / n
            b = min(1.0, q / 0.4)
            r = float(np.clip((q - 0.3) / 0.55, 0, 1))
            r = 0.5 - 0.5 * math.cos(math.pi * r)
            p["dy"] = 14 * b + 36 * r
            p["body"] = -8 * r
            p["head"] = 6 * b - 34 * r
            p["ear"] = 10 * r
            p["tail"] = -10 * b + 18 * r
            for kk, L in self.legs.items():
                x0, y0 = L["paw"]
                front = kk[0] == "F"
                p["feet"][kk] = (x0 + (-6 - 22 * r if front else 6 + 22 * r) * b, y0)
        return p

    # ------------------------------------------------------------ render
    def render(self, p):
        R, P = self.R, self.P
        Gs = np.array([[self.sc, 0, self.anch[0] - self.sc * self.src_cx],
                       [0, self.sc, self.anch[1] - self.sc * self.src_feet], [0, 0, 1]])
        bp = R["body_p"]
        B = rot(p["body"], bp, (bp[0] + p["dx"], bp[1] + p["dy"]))
        if p["sit"] > 0:
            sp = R["sit_p"]
            B = rot(p["body"], sp, (sp[0] + p["dx"], sp[1] + p["dy"] * 0.3))
        br = 1.0 + 0.012 * p["breathe"]
        Bb = B @ np.array([[1, 0, 0], [0, br, bp[1] * (1 - br)], [0, 0, 1]])
        legs = {}
        for k, L in self.legs.items():
            hip_w = ap(B, L["hip"])
            foot = p["feet"][k]
            if p["sit"] > 0:
                foot = (L["paw"][0] - 26 * p["sit"], L["paw"][1] + 2 * p["sit"]) if k[0] == "B" else (L["paw"][0] + p["dx"], L["paw"][1])
            l1 = math.dist(L["hip"], L["knee"])
            l2 = math.dist(L["knee"], L["paw"])
            kn = ik(hip_w, foot, l1, l2, 1 if k[0] == "F" else -1)
            au = ang((kn[0] - hip_w[0], kn[1] - hip_w[1])) - ang((L["knee"][0] - L["hip"][0], L["knee"][1] - L["hip"][1]))
            al = ang((foot[0] - kn[0], foot[1] - kn[1])) - ang((L["paw"][0] - L["knee"][0], L["paw"][1] - L["knee"][1]))
            legs[k] = [(P[k + "_u"], rot(au, L["hip"], hip_w)), (P[k + "_l"], rot(al, L["knee"], kn))]
        layers = []
        for k in R["order"]["behind"]:
            layers += legs[k]
        tp = R["tail"]["pivot"]
        layers.append((P["tail"], B @ rot(p["tail"], tp, tp)))
        layers.append((P["body"], Bb))
        front_extras = []
        for E in self.extras:
            M = Bb @ rot(p["swing"] * E.get("swing", 1.0), E["pivot"], E["pivot"])
            (front_extras if E.get("front") else layers).append((P[E["name"]], M))
        for k in R["order"]["front"]:
            layers += legs[k]
        layers += front_extras
        hp = R["head"]["pivot"]
        Hm = B @ rot(p["head"], hp, (hp[0] + p["hdx"], hp[1]))
        layers.append((P["head"], Hm))
        for k, E in R["ears"].items():
            layers.append((P[k], Hm @ rot(p["ear"] * E["dir"], E["pivot"], E["pivot"])))
        out = np.zeros((CW, CW, 4), np.float32)
        for img, M in layers:
            lay = cv2.warpAffine(img, (Gs @ M)[:2].astype(np.float32), (CW, CW), flags=cv2.INTER_LINEAR,
                                 borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            out = lay + out * (1 - lay[..., 3:4] / 255.0)
        return self.finish(out)

    @staticmethod
    def finish(out):
        sm = cv2.resize(out, (FS, FS), interpolation=cv2.INTER_AREA)
        a = sm[..., 3] / 255.0
        rgb = sm[..., :3] / np.maximum(a[..., None], 1e-3)
        hard = a >= 0.5
        hard = ndi.binary_opening(hard, structure=ndi.generate_binary_structure(2, 1))
        lb, nb = ndi.label(hard)
        if nb > 1:
            sz = ndi.sum(hard, lb, range(1, nb + 1))
            hard = np.isin(lb, 1 + np.nonzero(sz >= max(24, 0.02 * sz.max()))[0])
        m = hard.astype(np.float32)[..., None]
        bl = cv2.GaussianBlur(rgb * m, (0, 0), 0.8) / np.maximum(cv2.GaussianBlur(m[..., 0], (0, 0), 0.8), 1e-3)[..., None]
        rgb = np.clip(rgb + (rgb - bl) * 0.3, 0, 255)
        res = np.zeros((FS, FS, 4), np.uint8)
        res[..., :3] = np.where(hard[..., None], np.rint(rgb), 0).astype(np.uint8)
        res[..., 3] = hard * 255
        return res[:, ::-1]

    def ground(self, fr):
        """Never sink below the live feet line (+1 px): lift the frame."""
        rows = np.nonzero(fr[..., 3].any(1))[0]
        if rows.size == 0:
            return fr
        over = int(rows.max()) - (int(self.R["target"]["feet"]) + 1)
        if over > 0:
            fr = np.concatenate([fr[over:], np.zeros((over,) + fr.shape[1:], fr.dtype)], 0)
        return fr

    # ------------------------------------------------------------ outputs
    def states(self):
        pre = self.id + "_"
        out = {}
        for f in sorted(os.listdir(os.path.join(PETS, self.id))):
            if f.startswith(pre) and f.endswith(".png"):
                im = Image.open(os.path.join(PETS, self.id, f))
                out[f[len(pre):-4]] = max(1, round(im.width / im.height))
        return out

    def bake(self, out_dir, only=None):
        os.makedirs(out_dir, exist_ok=True)
        for st, n in self.states().items():
            if only and st not in only:
                continue
            fr = [self.ground(self.render(self.pose(st, i, n))) for i in range(n)]
            Image.fromarray(np.concatenate(fr, 1), "RGBA").save(os.path.join(out_dir, "%s_%s.png" % (self.id, st)))
            print("baked", self.id, st, n)

    def portrait(self, out_dir):
        import gen_portraits as GP                      # noqa: E402  (chdirs to game/)
        a = np.dstack([self.col, self.A * 255]).astype(np.uint8)[:, ::-1]
        x0, y0, s = GP.pet_box(a)
        GP.render(GP.crop_pad(a, x0, y0, s), False).save(os.path.join(out_dir, "pet_%s.png" % self.id))
        print("portrait", self.id)


def main(argv):
    out, only, portrait, ids = None, None, True, []
    it = iter(argv)
    for a in it:
        if a == "--out":
            out = os.path.abspath(next(it))
        elif a == "--states":
            only = next(it).split(",")
        elif a == "--no-portrait":
            portrait = False
        else:
            ids.append(a)
    for pid in ids or ["noel", "bentley", "lillie"]:
        d = Dog(pid)
        d.bake(os.path.join(out, pid) if out else os.path.join(PETS, pid), only)
        if portrait:
            d.portrait(out or PORTRAITS)


if __name__ == "__main__":
    main(sys.argv[1:])
