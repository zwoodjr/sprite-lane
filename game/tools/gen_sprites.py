#!/usr/bin/env python3
"""Generate Dust Apothecary Wasteland-themed 2D sprites (original MVP art)."""
from PIL import Image, ImageDraw
import os

OUT = "/workspace/game/assets/sprites"

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("wrote", path)

def new(w, h, bg=(0,0,0,0)):
    return Image.new("RGBA", (w, h), bg)

# --- Ground tiles ---
def ground_tile(seed=0):
    img = new(64, 64)
    d = ImageDraw.Draw(img)
    # dust ochre base
    base = (92 + seed*3, 68, 42, 255)
    d.rectangle([0,0,63,63], fill=base)
    for i in range(18):
        x = (i*17 + seed*9) % 64
        y = (i*29 + seed*5) % 64
        c = (110 + (i%5)*4, 78 + (i%3)*3, 48, 255)
        d.ellipse([x, y, x+4, y+3], fill=c)
    # sparse scrap glints
    for i in range(4):
        x = (i*21 + 7) % 60
        y = (i*13 + seed) % 60
        d.point((x,y), fill=(140, 90, 55, 200))
    return img

for i in range(4):
    save(ground_tile(i), f"{OUT}/tiles/dust_{i}.png")

# --- Characters ---
def make_character(body_rgb, accent_rgb, name):
    img = new(48, 48)
    d = ImageDraw.Draw(img)
    # shadow
    d.ellipse([12, 36, 36, 44], fill=(30, 20, 12, 90))
    # boots
    d.rectangle([16, 34, 22, 40], fill=(40, 28, 20, 255))
    d.rectangle([26, 34, 32, 40], fill=(40, 28, 20, 255))
    # legs / scrap pants
    d.rectangle([17, 26, 31, 35], fill=(body_rgb[0]-20, body_rgb[1]-15, body_rgb[2]-10, 255))
    # torso armor
    d.rectangle([14, 14, 34, 28], fill=body_rgb + (255,))
    # cloak flap
    d.polygon([(12,16),(16,14),(15,32),(10,30)], fill=(body_rgb[0]-30, body_rgb[1]-25, body_rgb[2]-15, 220))
    # head
    d.ellipse([18, 6, 30, 18], fill=(180, 140, 110, 255))
    # helm / hood
    d.arc([16, 4, 32, 18], 180, 0, fill=(accent_rgb[0], accent_rgb[1], accent_rgb[2], 255), width=3)
    # satchel / vial accent
    d.rectangle([32, 18, 38, 26], fill=accent_rgb + (255,))
    d.rectangle([33, 19, 37, 22], fill=(200, 230, 180, 200))  # tonic glint
    # gun
    d.rectangle([34, 20, 46, 24], fill=(60, 50, 40, 255))
    d.rectangle([44, 19, 47, 25], fill=accent_rgb + (255,))
    return img

save(make_character((90, 110, 70), (210, 170, 60), "rook"), f"{OUT}/characters/rook_vex.png")
save(make_character((160, 70, 55), (80, 190, 140), "cinder"), f"{OUT}/characters/sister_cinder.png")

# --- Enemy ---
def make_enemy():
    img = new(40, 40)
    d = ImageDraw.Draw(img)
    d.ellipse([8, 28, 32, 38], fill=(20, 10, 8, 80))
    d.rectangle([12, 14, 28, 32], fill=(120, 40, 30, 255))
    d.rectangle([10, 12, 30, 18], fill=(70, 30, 25, 255))  # scrap shoulder
    d.ellipse([14, 4, 26, 16], fill=(160, 100, 80, 255))
    d.rectangle([26, 18, 38, 22], fill=(50, 40, 35, 255))  # rusty gun
    # oil stain
    d.ellipse([16, 20, 22, 26], fill=(30, 25, 20, 180))
    return img
save(make_enemy(), f"{OUT}/enemies/raider.png")

# --- Mount skateboard ---
def make_skate():
    img = new(48, 24)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 8, 44, 16], radius=4, fill=(70, 55, 40, 255))
    d.rectangle([8, 6, 40, 10], fill=(160, 90, 40, 255))  # deck
    d.ellipse([8, 14, 16, 22], fill=(40, 40, 40, 255))
    d.ellipse([32, 14, 40, 22], fill=(40, 40, 40, 255))
    d.rectangle([18, 4, 28, 8], fill=(100, 160, 90, 200))  # herb strap
    return img
save(make_skate(), f"{OUT}/mounts/skateboard.png")

# --- Extract pad ---
def make_pad(open_state=False):
    img = new(96, 96)
    d = ImageDraw.Draw(img)
    ring = (240, 190, 60, 220) if open_state else (90, 80, 70, 180)
    fill = (200, 140, 40, 90) if open_state else (50, 45, 40, 70)
    d.ellipse([8, 8, 88, 88], fill=fill, outline=ring, width=4)
    d.ellipse([28, 28, 68, 68], outline=ring, width=2)
    # beacon post
    d.rectangle([45, 10, 51, 48], fill=(60, 50, 40, 255))
    lamp = (255, 220, 100, 255) if open_state else (80, 70, 60, 255)
    d.ellipse([40, 4, 56, 18], fill=lamp)
    # copper vial marks
    d.rectangle([20, 50, 28, 62], fill=(60, 140, 100, 200))
    d.rectangle([68, 50, 76, 62], fill=(60, 140, 100, 200))
    return img
save(make_pad(False), f"{OUT}/props/extract_sealed.png")
save(make_pad(True), f"{OUT}/props/extract_open.png")

# --- Props ---
def wreck():
    img = new(64, 48)
    d = ImageDraw.Draw(img)
    d.polygon([(4,36),(20,12),(52,10),(60,34),(48,40),(10,42)], fill=(70, 45, 35, 255))
    d.rectangle([22, 16, 40, 28], fill=(40, 50, 55, 255))  # broken window
    d.ellipse([12, 30, 24, 42], fill=(35, 35, 35, 255))
    d.ellipse([44, 28, 56, 40], fill=(35, 35, 35, 255))
    d.rectangle([30, 8, 36, 16], fill=(90, 160, 110, 200))  # tonic strapped
    return img
save(wreck(), f"{OUT}/props/wreck.png")

def crate():
    img = new(32, 32)
    d = ImageDraw.Draw(img)
    d.rectangle([4, 8, 28, 28], fill=(110, 75, 40, 255), outline=(60, 40, 20, 255))
    d.line([(4,16),(28,16)], fill=(60, 40, 20, 255))
    d.ellipse([12, 4, 20, 12], fill=(70, 150, 100, 230))  # sealed vial
    return img
save(crate(), f"{OUT}/props/herb_crate.png")

def tower():
    img = new(40, 72)
    d = ImageDraw.Draw(img)
    d.rectangle([12, 20, 28, 70], fill=(80, 70, 60, 255))
    d.polygon([(8,24),(20,4),(32,24)], fill=(100, 55, 40, 255))
    d.rectangle([16, 8, 24, 16], fill=(200, 160, 50, 255))  # signal lamp
    return img
save(tower(), f"{OUT}/props/signal_tower.png")

def scrap_pile():
    img = new(48, 32)
    d = ImageDraw.Draw(img)
    d.ellipse([4, 12, 44, 30], fill=(75, 50, 35, 255))
    d.rectangle([10, 8, 22, 18], fill=(90, 90, 95, 255))
    d.rectangle([24, 6, 38, 16], fill=(120, 70, 45, 255))
    d.ellipse([18, 4, 26, 12], fill=(50, 130, 100, 220))
    return img
save(scrap_pile(), f"{OUT}/props/scrap_pile.png")

# bullet
def bullet():
    img = new(12, 6)
    d = ImageDraw.Draw(img)
    d.ellipse([0,0,11,5], fill=(240, 210, 80, 255))
    return img
save(bullet(), f"{OUT}/props/bullet.png")

# minimap icons
def icon(color, size=8):
    img = new(size, size)
    d = ImageDraw.Draw(img)
    d.ellipse([0,0,size-1,size-1], fill=color)
    return img
save(icon((100, 220, 120, 255)), f"{OUT}/ui/mm_player.png")
save(icon((240, 190, 60, 255)), f"{OUT}/ui/mm_extract_open.png")
save(icon((120, 110, 100, 255)), f"{OUT}/ui/mm_extract_sealed.png")
save(icon((180, 90, 60, 255)), f"{OUT}/ui/mm_landmark.png")

# extract arrow
def arrow():
    img = new(32, 32)
    d = ImageDraw.Draw(img)
    d.polygon([(16,2),(28,28),(16,22),(4,28)], fill=(255, 200, 60, 230))
    return img
save(arrow(), f"{OUT}/ui/extract_arrow.png")

print("DONE")
