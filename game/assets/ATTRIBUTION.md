# Art attribution

MVP sprites under `assets/sprites/` are **original chunky pixel art** for Project Wanderer
(**Dust Apothecary Wasteland** theme: dust ochre, rust scrap, copper-green / amber vials).

Style is **inspired by** Crazy Gunner’s clean polished chibi pixel readability
(thick outlines, big-head silhouettes, simple faces, chunky hair masses) but
**does not copy** Crazy Gunner characters, weapons, stages, UI chrome, or other IP.

## Clean chibi pass (CG quality bar)

Playable heroes target the polished selection-bar look:

- Large square heads, stubby bodies with **clear limb separation**
  (head / torso / arms / legs / weapon as separate masses — not a thumb blob)
- Multi-pass outlines per limb so crotch/armpit gaps survive
- **Simple faces** — two clear eye dots (or a visor bar); mouths/noses/brows absent
- Hair as **chunky shaped masses** with jagged stair-step silhouette — not sparse strands
- Thick dark outlines, one darker shade, vibrant readable colors
- Native canvas **96×96** (room for limb gaps); in-match footprint ~**48px** via
  `Player._body_base_scale` so portrait FOV stays ~**1/12–1/15** screen width

## Wide-FOV pass (portrait survivor camera)

Sprites are authored for **portrait 720×1280** with camera zoom **~1.12**:

- Strong silhouettes + saturated accent blocks (scarf, medic cross, visor, vials)
- Quiet ground tiles (soft patches, sparse grit — not specklemush)
- Thick extract rings / bright pickups / chunkier breakables for findability
- Unit scale: heroes **96×96** (drawn; ~48px on screen); common enemies **48×48**;
  brute **64×64**; pickups **48×48**

Regenerate the full set with Pillow:

```bash
python3 tools/gen_sprites.py
# or: python3 tools/gen_sprites_v2.py  (wrapper → same generator)
```

# Audio attribution

Everything under `assets/audio/` is built by `tools/audio/build_sfx.py` (SFX) and
`tools/audio/build_music.py` (ambience beds + music) from public-domain recordings,
layered, re-pitched, filtered, compressed and given room/outdoor/hall space, plus
offline synthesis (wind, crickets, flies, hums, servos, radio squelch and garbled radio
voice, electrical arcing, body thumps, supersonic cracks, sub-bass pulses).
The music is composed procedurally from recorded cello notes, impacts and synthesis.

All source recordings are **CC0 1.0 (public domain)** — no attribution required; credited
here anyway. They were taken from the collection
<https://github.com/lavenderdotpet/CC0-Public-Domain-Sounds> (repository licence: CC0 1.0),
whose individual packs carry their own CC0 statements:

| Pack (folder in that repo) | Author | Licence text | Used for |
|---|---|---|---|
| `warfork-cc0/` (Warfork game assets, `warfork_assets_cc0.txt`) | Team Forbidden | CC0 1.0 | launcher/explosion bodies, SMG + turret bursts, electro-bolt crackle, blade hits, door/elevator movers, player pain/death voices, dry fire |
| `kenney_impactsounds/`, `kenney_rpgaudio/` (`License.txt`) | Kenney (kenney.nl) | CC0 1.0 | punches, metal/plate/bell/glass/wood impacts, footsteps, cloth, coins, knives, latches, book/paper foley |
| `25-CC0-bang-sfx/`, `75-cc0-breaking-falling-hit-sfx/`, `80-CC0-creature-SFX/`, `80-CC0-creature-sfx-2/`, `100-CC0-SFX/`, `100-CC0-wood-metal-SFX/`, `100-cc0-sfx-2/`, `30-cc0-sfx-loops/`, `40-cc0-water-splash-slime-sfx/` | rubberduck (OpenGameArt) | CC0 1.0 (pack titles) | rifle/pistol shots, debris and breaking, creature vocals (plague mobs, roars, dog barks), chains/keys, metal slams, thunder, hiss, machine/pump/alarm loops, wet hits |
| `bb - Novice Cello`, `bb - Smol Mechanisms`, `bb - Toolbox Rummaging`, `bb - Pill Bottles`, `bb - Fans and Drones`, `Micro Pack - Organic Wooshes`, `Micro Pack - Kitchen Knives`, `Micro Pack - Small Can`, `Micro Pack - NazdyNate - Electromagnetic Sounds` (`_README.txt`) | Ben Burnes (and NazdyNate) | CC0 1.0 ("public domain (Creative Commons 0)") | all music cello, UI clicks/clunks, ratchets, reload foley, medicine bottles, generator/AC hum, swings and whooshes, blade rings, EM static |
| `beast_or_animal/` | uploader of the collection | CC0 1.0 (repository licence) | Noel's growl |

## Music (metal score)

`assets/audio/music/` is an original heavy-metal score composed for Wanderer (every riff,
progression and melody is new) and rendered by `tools/audio/build_metal.py` from three
**CC0 1.0 (public domain)** multisample libraries by Karoryfer Samples, distributed at
<https://github.com/sfzinstruments> (each repository ships the CC0 1.0 legal code as `LICENSE`):

| Library (repository) | Recorded instrument | Used for |
|---|---|---|
| `karoryfer.black-and-green-guitars` (Brian Wood / Karoryfer Lecolds) | DI electric guitars (Gretsch Anniversary, Hofner Club), note by note | rhythm guitars (one per side), leads, clean arpeggios |
| `karoryfer.growlybass` | Squier Jazz Bass, sustain + staccato | bass |
| `karoryfer.big-rusty-drums` | multi-mic rock kit (24" kick, 14" snare, toms, hats, crash, china, ride) | drums |

The guitar tone (two-stage tube-style distortion, scooped tone stack, 4x12 cab simulation),
mixing and mastering are done in the script; no amp impulse responses or third-party
recordings beyond those libraries are used. Tracks: `mus_menu`, `mus_explore`, `mus_combat`,
`mus_boss`, `mus_story` (loops) and `mus_sting_death`, `mus_sting_extract`.
The earlier cello-based music from `build_music.py` was retired; that script still builds the ambience beds.

The pre-2026-10 chiptune-style generator (`tools/gen_sfx.py`, `assets/sfx/`) was retired.
