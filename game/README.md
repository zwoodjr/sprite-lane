# Wanderer (Godot 4 MVP) — iPhone / Xogot first

Solo top-down extraction. **Primary: iPhone in Xogot/Godot Play (landscape).** PC keyboard/mouse still works.

## Control scheme

| Control | Touch | PC |
|---------|-------|-----|
| Move | **Left stick** (large pad) | WASD |
| Aim | **Right stick** | Mouse |
| Fire | Hold **FIRE** (auto-aim ON by default) | LMB |
| Extract / Ability / Mount | Large bottom buttons | E / Q / F |
| Pause | Top-right **PAUSE** | Esc |
| Auto-aim toggle | **AUTO-AIM** (top-left) | — |
| Fill screen | **FILL** (top-left) | — |

Sticks: bigger hit zones, low idle opacity / high when active, deadzone + smoothed response.

**Landscape only.**

## Display / fullscreen

- Stretch: `canvas_items` + `expand` — game fills the host viewport.
- Safe-area padding is for **controls/HUD only**; the world draws full-bleed behind.
- **FILL** tries OS fullscreen. **Xogot Play chrome cannot be removed from game code** — maximize inside Play only.

## Run on iPhone (Xogot)

1. Clone/copy repo so `game/project.godot` is on the phone (Working Copy / Files / ZIP). Branch: `cursor/wanderer-godot-mvp-83de`.
2. Xogot → Import → **Play** (keep landscape).
3. Left = move, right = aim, hold FIRE to shoot.

### Limits

| Works | Doesn't |
|-------|---------|
| In-editor Play + touch controls | Removing Xogot editor chrome |
| Light script edits on phone | App Store IPA without Mac/Xcode |

## Run on PC

Godot 4.3+ → open `game/project.godot` → F5.

```bash
godot4 --headless --path game --quit-after 3
```

## Status

`MVP_STATUS.md` · Project Context `docs/mvp-status.md`
