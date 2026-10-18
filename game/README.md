# Wanderer (Godot 4.3) — iPhone / Xogot first

Solo top-down extraction shooter. **Portrait** (survivor FOV). PC keyboard/mouse also works.

## Controls (phone)

| Input | Action |
|-------|--------|
| Thumb on lower half | MOVE (stick under thumb). **Aim + auto-fire follow run direction** |
| FIRE (hold) | While idle: shoot nearest enemy |
| DASH | Burst + brief invincibility (dash through bullets) |
| Gold ability button | Character ability (Rook: RUSH, Cinder: HEAL) |
| RIDE | Hop on/off mount |
| II (top-right) | Pause · How to play · Settings · Abandon run |
| Stand on an open gold pad | Extract (ring fills in 1.5s) |

All buttons are true multi-touch. Settings: twin-stick (optional restore), auto-fire while moving, idle auto-aim, aim assist, stick size, left-handed, hints, sound, vibration, shake.

**PC:** WASD move (run = aim + auto-fire) · mouse aim/click while idle · Space or right-click dash · Q ability · F mount · R reload · E extract · Esc pause.

## Camera / FOV

Portrait **720×1280**, orthographic camera zoom **1.12** so the player reads ~**1/13 of screen width** — matched to `docs/art-refs/fov-single-stick-ref.jpg` battlefield scale. Heroes are **64×64** clean polished chibi (2-dot faces, chunky hair masses) scaled in-match to a ~48px footprint; regenerate with `python3 tools/gen_sprites.py`.

## What's in

- First-run interactive tutorial (move → run-and-shoot → dash); replay from Settings
- How to Play pages (menu + pause)
- 3 enemy types with visible wind-up warnings: raider, charger, brute
- Juice: SFX, screen shake, hitstop, hit flashes, damage numbers, particles, recoil, muzzle flash, dash afterimages, low-HP vignette
- HUD explains itself: phase card says what to do now; Threat badge shows the cost/reward
- Save file (`user://wanderer_save.json`): settings, banked scrap, Hangar ranks, account prestige, extracts, unlocks
- Dual-track progression: **run levels** (temporary loadout picks mid-match) + **Hangar scrap** (permanent between runs)
- Endless chunk map with terrain variation, varied decor, extract beams + arrows + minimap

## Not in yet (waiting on design doc)

Other 8 characters, full armor/weapon/pet/mount trees, Hard+ modes, deep skill trees.

## Tools

- `tools/test_runner.tscn` — headless bot playtest: `godot --headless --path game res://tools/test_runner.tscn`
- `tools/screenshot.tscn` — renders every screen to PNG (needs a display / xvfb)
- `tools/gen_sfx.py`, `tools/gen_sprites.py` — regenerate original audio / Dust Apothecary chunky-pixel art (`gen_sprites_v2.py` wraps the same generator)
