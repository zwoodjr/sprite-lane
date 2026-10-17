# Wanderer (Godot 4) — iPhone / Xogot first

Endless top-down extraction MVP. Landscape dual-stick + FIRE. PC WASD/mouse still work.

## What’s in this build

- **Endless chunk wasteland** (Crazy Gunner–scale explore feel)
- **Minimap + extract arrows** (open vs sealed)
- **Per-run randomized extract pads** near landmarks
- **Breakable crates/drums/chests** → temporary power-ups
- **Real sprites** (Dust Apothecary palette) — see `assets/`
- Characters: **Rook + Cinder** playable; more IDs stubbed data-only

## Controls

| Touch | Action |
|-------|--------|
| Left stick | Move |
| Right stick | Aim |
| FIRE (hold) | Shoot (auto-aim ON by default) |
| EXTRACT / ABILITY / MOUNT | Actions |
| PAUSE / FILL / AUTO-AIM | Top toggles |

## Run on iPhone (Xogot)

1. Clone/copy repo branch `cursor/wanderer-godot-mvp-83de` so `game/project.godot` is on device.
2. Import in Xogot → **Play** (landscape).
3. Follow arrows to extracts; shoot breakables for buffs.

**Xogot limit:** editor Play chrome stays; FILL only expands the game viewport inside Play.

## Run on PC

Godot 4.3+ → open `game/project.godot` → F5.

```bash
godot4 --headless --path game --quit-after 3
```

## Map notes

Chunks = 512px; ~5×5 loaded. No hard edge nearby — streaming unload only. Extracts re-roll each deploy from run seed.
