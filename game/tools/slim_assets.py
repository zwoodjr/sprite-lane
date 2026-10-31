#!/usr/bin/env python3
"""Shrink the shipped build without touching art content.

  python3 tools/slim_assets.py textures   # lossy WebP import for big art
  python3 tools/slim_assets.py audio      # re-encode music/ambience/SFX OGGs
  python3 tools/slim_assets.py check      # report what would change

textures: flips `compress/mode` to Lossy (WebP, quality LOSSY_Q) in the .import
files of large sprite/art textures: mob, hero and pet strips, hangar art, zone
tiles, props, depth world art, decals and the menu backdrop. The PNGs are not
modified. UI, HUD, icons, pickups, portraits and FX stay lossless. A texture is
only switched when a lossy encode is at least MIN_GAIN smaller than lossless
(tiny pixel art often is not). WebP lossy keeps alpha lossless, so silhouettes,
feet lines and the 'alive' alpha logic are unchanged. Re-run after the art
pipeline regenerates .import files.

audio: re-encodes OGG Vorbis in place (ffmpeg/libvorbis) to the target quality
when the file is above it. Sample count and loop length are verified to be
unchanged (loops are whole-file, loop_offset 0).
"""
import glob
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOSSY_Q = 0.88
MIN_GAIN = 0.25
LOSSY_GLOBS = [
    "assets/sprites/enemies/**/*.png",
    "assets/sprites/characters/**/*.png",
    "assets/sprites/pets/**/*.png",
    "assets/sprites/hangar/*.png",
    "assets/sprites/tiles/**/*.png",
    "assets/sprites/props/**/*.png",
    "assets/sprites/depth/world/**/*.png",
    "assets/sprites/depth/zone/**/*.png",
    "assets/sprites/depth/plane/**/*.png",
    "assets/sprites/decals/**/*.png",
    "assets/sprites/ui/menu_backdrop.png",
]
# (dir glob, libvorbis -q, nominal kbps ceiling that triggers a re-encode)
AUDIO = [
    ("assets/audio/music/*.ogg", 2, 100),
    ("assets/audio/amb/*.ogg", 0, 70),
    ("assets/audio/sfx/*.ogg", 3, 70),
]


def _lossy_worth_it(png):
    from PIL import Image
    im = Image.open(png).convert("RGBA")
    a, b = io.BytesIO(), io.BytesIO()
    im.save(a, "WEBP", lossless=True, method=4)
    im.save(b, "WEBP", quality=int(LOSSY_Q * 100), method=4)
    return b.tell() <= a.tell() * (1.0 - MIN_GAIN)


def textures(dry):
    n = 0
    seen = set()
    for g in LOSSY_GLOBS:
        for png in sorted(glob.glob(os.path.join(ROOT, g), recursive=True)):
            if png in seen:
                continue
            seen.add(png)
            imp = png + ".import"
            if not os.path.exists(imp):
                continue
            t = open(imp).read()
            if "compress/mode=1" in t and ("compress/lossy_quality=%g" % LOSSY_Q) in t:
                continue
            if not _lossy_worth_it(png):
                continue
            t2 = re.sub(r"^compress/mode=\d+", "compress/mode=1", t, flags=re.M)
            t2 = re.sub(r"^compress/lossy_quality=[\d.]+", "compress/lossy_quality=%g" % LOSSY_Q, t2, flags=re.M)
            if t2 != t:
                n += 1
                if not dry:
                    open(imp, "w").write(t2)
    print("textures -> lossy:", n, "(dry run)" if dry else "")


def _probe(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a", "-count_packets", "-show_entries",
                        "stream=channels,sample_rate,bit_rate", "-of", "csv=p=0", path],
                       capture_output=True, text=True).stdout.strip().split(",")
    return int(r[0]), int(r[1]), int(r[2] or 0)


def _samples(path):
    r = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "s16le", "-"], capture_output=True)
    return len(r.stdout)


def audio(dry):
    n = 0
    for g, q, kbps in AUDIO:
        for f in sorted(glob.glob(os.path.join(ROOT, g))):
            sr, ch, br = _probe(f)
            if br and br <= kbps * 1000:
                continue
            n += 1
            if dry:
                continue
            tmp = f + ".tmp.ogg"
            subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", f, "-map_metadata", "-1", "-c:a", "libvorbis",
                            "-q:a", str(q), tmp], check=True)
            if _samples(tmp) != _samples(f):
                os.remove(tmp)
                print("  length changed, kept original:", f)
                continue
            os.replace(tmp, f)
    print("audio re-encoded:", n, "(dry run)" if dry else "")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "check"
    dry = what == "check"
    if what in ("textures", "check"):
        textures(dry)
    if what in ("audio", "check"):
        audio(dry)
