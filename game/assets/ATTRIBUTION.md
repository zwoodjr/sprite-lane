# Art attribution

MVP sprites under `assets/sprites/` are **original chunky pixel art** for Project Wanderer
(**Dust Apothecary Wasteland** theme: dust ochre, rust scrap, copper-green / amber vials).

Style is **inspired by** Crazy Gunner’s chunky-pixel / expressive-chibi readability
(thick outlines, big-head silhouettes, high-contrast accents) but **does not copy**
Crazy Gunner characters, weapons, stages, UI chrome, or other IP.

## Wide-FOV pass (portrait survivor camera)

Sprites are authored for **portrait 720×1280** with camera zoom **~1.12** so the
48px player reads ~**1/12–1/15** of screen width:

- Strong silhouettes + saturated accent blocks (scarf, hood, visor, vials)
- Quiet ground tiles (soft patches, sparse grit — not specklemush)
- Thick extract rings / bright pickups / chunkier breakables for findability
- Unit scale: players & common enemies **48×48**; brute **64×64**; pickups **48×48**

Regenerate the full set with Pillow:

```bash
python3 tools/gen_sprites.py
# or: python3 tools/gen_sprites_v2.py  (wrapper → same generator)
```

Audio under `assets/sfx/` is also original (see `tools/gen_sfx.py`).
