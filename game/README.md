# Wanderer (Godot 4 MVP) — iPhone first

Solo top-down extraction survival vertical slice. **Primary target: iPhone** (Godot on device). PC keyboard/mouse still works.

Design SoT: Project Context `docs/game-design.md`.

## Layout

Godot project lives in **`game/`** (repo root keeps the legacy web prototype).

```
game/
  project.godot          # Open this in Godot 4.3+
  scenes/                # UI + match + entities + touch controls
  scripts/               # GDScript (TouchInput, match, entities, data)
```

## Orientation & display

- **Landscape** (locked via `window/handheld/orientation`)
- Viewport **1280×720**, stretch `canvas_items` + `expand` (fits common iPhone landscape aspects + notches via safe-area padding)
- Rendering method: **mobile**
- Touch emulation from mouse enabled (desktop testing of sticks)

## Control scheme (shipped)

| Control | Touch (primary) | PC |
|---------|-----------------|-----|
| Move | **Left virtual stick** | WASD / arrows |
| Aim + fire | **Right virtual stick** (drag past deadzone → aim and auto-fire) | Mouse aim + LMB |
| Extract | Large **EXTRACT** button (must be on open pad) | E |
| Ability | **ABILITY** (Sister Cinder heal) | Q |
| Mount | **MOUNT** (skateboard) | F |
| Pause / menu | **PAUSE** | Esc |

## How to run on iPhone (Godot installed)

### 1. Get `game/` onto the phone

Pick one:

**A. Working Copy (recommended for git)**  
1. Install [Working Copy](https://workingcopyapp.com/).  
2. Clone `https://github.com/zwoodjr/sprite-lane` (or your fork). Checkout branch `cursor/wanderer-godot-mvp-83de` if needed.  
3. In Files / Working Copy, note the folder that contains `game/project.godot`.

**B. GitHub app + Files**  
1. Open the repo in GitHub / download ZIP of the branch.  
2. Save/extract into **On My iPhone** (Files app), e.g. `sprite-lane/game/`.

**C. AirDrop / iCloud Drive**  
1. On a computer: zip the `game/` folder.  
2. AirDrop or put in iCloud Drive → open in Files on iPhone → unzip.

You need the folder that **directly contains** `project.godot` (the `game/` directory).

### 2. Open in Godot on iOS

1. Launch **Godot** on the iPhone.  
2. **Import** → browse to `game/project.godot` (Files picker / Working Copy location).  
3. Open the project.  
4. Press **Play** (▶). Phone should stay **landscape**.  
5. Use left stick to move, right stick to aim/fire, bottom buttons for Extract / Ability / Mount / Pause.

### 3. What works / limits on phone

| Works | Limitations |
|-------|-------------|
| Edit GDScript / scenes in Godot iOS editor | Small screen — prefer light edits |
| Run the MVP in-editor (Play) | Full App Store **export/signing** needs a Mac + Xcode / Apple Developer account — not from phone alone |
| Touch dual-stick + menus | External keyboard optional; mouse not required |
| Fast timers checkbox for quick loops | Heavy debugging / profilers are awkward on device |

## How to run on PC

1. Install [Godot 4.3+](https://godotengine.org/download).  
2. Import `game/project.godot` → F5.  
3. Sticks still appear (dimmed); WASD + mouse work.

### Headless smoke

```bash
godot4 --headless --path game --quit-after 3
godot4 --headless --path game -s res://tools/smoke_test.gd
```

## Flow

**Main → Mode (Easy/Medium) → Character (Rook/Cinder) → Deploy → Match → Extract / Wipe**

## Status

See `MVP_STATUS.md` and Project Context `docs/mvp-status.md`.
