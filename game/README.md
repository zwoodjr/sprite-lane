# Wanderer (Godot 4 MVP)

Solo top-down extraction survival vertical slice. Design source of truth: Project Context `docs/game-design.md`.

## Layout

This Godot project lives in **`game/`** so it sits beside the existing web prototype at the repo root without overwriting it.

```
game/
  project.godot          # Open this folder in Godot 4.3+
  scenes/                # UI + match + entities
  scripts/               # GDScript (autoload, match, entities, data stubs)
  assets/                # Placeholder hooks (silhouettes are Polygon2D for now)
```

## Requirements

- **Godot 4.3+** (project features target 4.3)
- PC keyboard/mouse

## How to run

1. Install [Godot 4.3+](https://godotengine.org/download).
2. In the Project Manager: **Import** → select `game/project.godot` → Open.
3. Press **F5** (main scene: `scenes/ui/main_menu.tscn`).

### Headless smoke check

```bash
godot4 --headless --path game --quit-after 2
```

(Or `godot` if that is your 4.x binary.)

## Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Move |
| Mouse | Aim |
| LMB | Shoot |
| E | Extract (on open pad) |
| Q | Character ability (Sister Cinder heal) |
| F | Mount toggle (skateboard) |
| Esc | Abort to main menu |

## Flow

**Main menu → Mode (Easy/Medium) → Character (Rook/Cinder) → Deploy → Match → Extract success / Wipe**

On Mode Select, optional **Fast timers (dev)** compresses phase lengths for quick playtests. Full Easy (~5 min) / Medium (~10 min) timings are the default.

## Status

See [`/cursor/stores/self/docs/mvp-status.md`](/cursor/stores/self/docs/mvp-status.md) (Project Context) for what’s in/out of this slice.
