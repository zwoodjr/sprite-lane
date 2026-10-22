"""Campaign speaker portraits that the hero/pet set doesn't cover, made the
same way as tools/gen_portraits.py (idle frame bust, Scale2x twice, 2-px dark
seam, top-left rim light) but with a SIGNAL-red back-glow for the people and
things that are against you:
  mother_vane  raider captain bust     raider  raider grunt bust
  dust         the Wasteland God's head (the Dust, speaking)

    python3 game/tools/gen_campaign_portraits.py
"""
import importlib.util
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("gen_portraits", os.path.join(HERE, "gen_portraits.py"))
gp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gp)  # chdirs into game/

GLOW = {"mother_vane": (255, 72, 54), "raider": (217, 138, 69), "dust": (255, 192, 64)}
SRC = {"mother_vane": "raider_captain", "raider": "raider_grunt", "dust": "wasteland_god_entity"}


def recolor_glow(img, rgb):
    a = np.array(img).astype(np.float32)
    # the amber glow is where the art is absent and the seam isn't: retint it
    glow = (a[..., 3] > 0) & (a[..., 3] < 200) & (a[..., 0] > 200) & (a[..., 1] > 120)
    a[glow, 0], a[glow, 1], a[glow, 2] = rgb
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main():
    for pid, src in SRC.items():
        a = gp.frame0("assets/sprites/enemies/%s/%s_idle.png" % (src, src))
        if pid == "dust":
            x0, y0, s = gp.pet_box(a)
            s = int(s * 0.6)
            x0 += int(s * 0.5)
        else:
            x0, y0, s = gp.bust_box(a)
        img = gp.render(gp.crop_pad(a, x0, y0, s), pid != "dust")
        recolor_glow(img, GLOW[pid]).save(os.path.join(gp.OUT, "%s.png" % pid))
    print("ok")


if __name__ == "__main__":
    main()
