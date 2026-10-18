# MVP status (repo mirror)

**Latest (Hangar scroll):** Full meta catalog was hard to drag / stuck on iPhone·Xogot portrait. `hangar.gd` now uses a touch-friendly ScrollContainer (no horizontal steal, deadzone, follow-focus), rows pass drag to the scroller, list width syncs for autowrap height, rebuild frees rows immediately and clamps scroll, portrait chrome tightened + end pad for Xogot bottom toolbar. Re-pull PR #10.

**Prior (Xogot preload fix):** `enemy.gd` / `player.gd` failed with “Could not preload resource…” because `scenes/entities/bullet.tscn` had a GDScript `##` comment (invalid in `.tscn`; use `;`). Also dropped leftover `const ExtractScatter = preload(...)` shadowing `class_name ExtractScatter`.

**Prior (Hangar + events):** Full Hangar meta catalog (HP, endurance stub, scrap/loot, damage/crit/AoE, dodge/block, move, pickup, pet, dash, extract grace/payout; insurance still hidden). Thin `EventDefs` + mid-lockout radio toast stub. Design: store `docs/events-and-quests.md`.

**Prior (Xogot parse fix):** Removed `const X = preload(...)` that shadowed `class_name X` (MobileLayout, PetDefs, CharacterDefs, …). That shadowing is a **parser error** on Godot 4.7 / Xogot (“The member MobileLayout…”). Use global class names only. Re-pull clean PR #10 branch after this.

**Prior (feel + wasteland pets):** Pets Noel / Bentley / Lillie redrawn to **wasteland sheet detail** (same bar as heroes/mobs — chibi retired). Walk strips via `UnitAnim`. On-device feel pass for iPhone / Xogot portrait:

- Single-stick: deadzone ↑ slightly (0.12 move / 0.14 virtual), softer response curve, snappier release lerp
- Auto-fire run threshold 0.22 (less twitch-fire from micro-drags)
- Camera zoom **1.0** (was 1.12) + lighter look-ahead so sheet heroes/mobs read at survivor scale
- Body FOV: player 52px, enemies 44px, pets 42px
- Spawn soft-cap 12–14 + cull enemies >1100px; Last Extract prefers fewer heavier T3
- Character select: scrollable 8-hero strip (56px tiles); pet tiles unchanged
- Safe-area padding bumped for notch / home indicator

Full notes: store `docs/mvp-status.md`. Previews: `media/pets/`, `media/heroes/`, `media/mobs/`.
