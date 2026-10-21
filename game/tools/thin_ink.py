"""Thin the outer ink line of painted props from 2 px to 1 px so their line
weight matches the 1-texel outlines on heroes / mobs (audit quick win #1).

python3 tools/thin_ink.py assets/sprites/props_hd/*.png   (in-place, idempotent-ish:
a second pass only touches lines that are still 2 px thick)
"""
import sys
import numpy as np
from PIL import Image

INK_LUM = 60      # darker than this (0-255) and opaque = ink
SOLID_A = 200     # alpha at/above this counts as inside the sprite


def thin(path):
    im = np.array(Image.open(path).convert("RGBA")).astype(np.int32)
    h, w = im.shape[:2]
    a = im[..., 3]
    lum = (im[..., 0] * 299 + im[..., 1] * 587 + im[..., 2] * 114) // 1000
    ink = (a >= SOLID_A) & (lum < INK_LUM)
    solid = a >= SOLID_A
    pad_s = np.pad(solid, 2, constant_values=False)
    pad_i = np.pad(ink, 2, constant_values=False)
    kill = np.zeros_like(ink)
    edge = np.zeros_like(ink)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        # outside neighbour on one side, ink on the opposite side = 2-px line
        out_n = ~pad_s[2 + dy:2 + dy + h, 2 + dx:2 + dx + w]
        in_n = pad_i[2 - dy:2 - dy + h, 2 - dx:2 - dx + w]
        edge |= ink & out_n
        kill |= ink & out_n & in_n
    # Bridge 1-2 px gaps (rivets / highlights behind the line) so the thinned
    # silhouette never turns dotted.
    for _ in range(2):
        k = np.pad(kill, 2, constant_values=False)
        lr = k[2:2 + h, 1:1 + w] & k[2:2 + h, 3:3 + w]
        ud = k[1:1 + h, 2:2 + w] & k[3:3 + h, 2:2 + w]
        lr2 = k[2:2 + h, 0:w] & k[2:2 + h, 4:4 + w]
        ud2 = k[0:h, 2:2 + w] & k[4:4 + h, 2:2 + w]
        kill |= edge & (lr | ud | lr2 | ud2)
    if not kill.any() or kill.sum() < 0.4 * edge.sum():
        return 0
    # The removed ink pixel keeps a faint soft edge if a shadow sits under it.
    im[kill, 3] = 0
    Image.fromarray(im.astype(np.uint8), "RGBA").save(path)
    return int(kill.sum())


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, thin(p))
