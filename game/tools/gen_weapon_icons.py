"""Base weapon icons (Common-Epic variants) from the Legendary icons: drop the
coloured glow and mute the colours a little so Legendaries still pop.
usage: python3 tools/gen_weapon_icons.py   (from game/)"""
from PIL import Image, ImageEnhance

MAP = {"ash_rook": "last_shift", "vesper_thorn": "bellwether", "pebble": "gravedigger",
       "bolt_juno": "live_line", "sister_cinder": "censer", "quill_marrow": "bonesaw",
       "nyx_caldera": "twin_debts", "helm_wisp": "mayday"}
for hero, leg in MAP.items():
    im = Image.open("assets/sprites/icons/legendary/legendary_%s.png" % leg).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a < 230:
                px[x, y] = (0, 0, 0, 0)
    im = ImageEnhance.Color(im).enhance(0.6)
    im.save("assets/sprites/icons/weapons/weapon_%s.png" % hero)
print("ok")
