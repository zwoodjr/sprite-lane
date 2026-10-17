# Art attribution

MVP sprites under `assets/sprites/` are **original chunky pixel art** for Project Wanderer
(**Dust Apothecary Wasteland** theme: dust ochre, rust scrap, copper-green / amber vials).

Style is **inspired by** Crazy Gunner’s chunky-pixel / expressive-chibi readability
(thick outlines, big-head silhouettes, high-contrast accents) but **does not copy**
Crazy Gunner characters, weapons, stages, UI chrome, or other IP.

## Humanize pass (faces + hair)

Playable heroes are authored so they read as **people**, not color blobs:

- Readable faces: eyes (sclera + pupil), brows, nose hint, mouth/expression
- Hair with strand clumps / jagged silhouette — hats/hoods sit *with* visible hair
- Native canvas **64×64** (nearest scale); in-match footprint locked to ~**48px** via
  `Player._body_base_scale` so portrait FOV stays ~**1/12–1/15** screen width

## Wide-FOV pass (portrait survivor camera)

Sprites are authored for **portrait 720×1280** with camera zoom **~1.12**:

- Strong silhouettes + saturated accent blocks (scarf, medic cross, visor, vials)
- Quiet ground tiles (soft patches, sparse grit — not specklemush)
- Thick extract rings / bright pickups / chunkier breakables for findability
- Unit scale: heroes **64×64** (drawn; ~48px on screen); common enemies **48×48**;
  brute **64×64**; pickups **48×48**

Regenerate the full set with Pillow:

```bash
python3 tools/gen_sprites.py
# or: python3 tools/gen_sprites_v2.py  (wrapper → same generator)
```

Audio under `assets/sfx/` is also original (see `tools/gen_sfx.py`).
