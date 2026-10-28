# MVP status (repo mirror)

**Latest (overnight polish pass):** In progress — performance + feel + UI polish.

- Perf: kill loot is capped at 70 live drops; overflow value merges into the nearest same-kind drop (a horde used to leave 400+ drops ticking each frame). Magnet radius lookup throttled.
- Perf: enemy separation uses a shared per-frame enemy list and recomputes every 3rd frame per mob (was O(n²) array allocs every frame). Physics time in a 60-mob horde dropped ~12 ms → ~8.5 ms headless.
- Perf: HUD only touches theme overrides / label text when the value changes (was every frame for ~10 labels + buff chips).
- Level-up cards: rarity-coloured frame + panel tint (uncommon green, rare teal, epic mauve, evolution gold), slow glow on epic+, chosen card "stamps" while the others drop away.
- Death: red flash, camera punch-in, 1 s slow-mo, heavy haptic. Extract: warm flash, punch, short slow-mo, hero stretches up and fades into the beam. Result screen waits in real time.
- KILL CHAIN readout under LOOT: kills within 2.2 s stack (shows from x5), heats bone→amber→rust→red, calls RAMPAGE / CARNAGE / MASSACRE / WASTELAND LEGEND at 10/25/50/100. Best chain shows on the result screen (≥10).
- Tests: two timing-flaky checks (boss bar poll, music hold) now wait on the condition.

Test on device: big hordes (frame pacing, scrap/XP all still arrive); level-up card colours; die once and extract once to feel the new moments; kill chain position next to the minimap on a notched phone.

**Prior (per-hero guns):** Playtest “everyone feels like the same SMG” — `LoadoutStubs.weapon_for_character` now gives each of the 8 heroes distinct fire rate / mag / reload / spread / damage (launcher splash, sniper, melee maul, gauntlet burst, medic SMG, dual blades, AR, pistol+drone stub). `GameState.reset_loadout_to_defaults` no longer stamps the shared Scrap SMG. Character select shows kit stats. Re-pull PR #10.

**Prior (Hangar scroll):** Full meta catalog was hard to drag / stuck on iPhone·Xogot portrait. `hangar.gd` now uses a touch-friendly ScrollContainer (no horizontal steal, deadzone, follow-focus), rows pass drag to the scroller, list width syncs for autowrap height, rebuild frees rows immediately and clamps scroll, portrait chrome tightened + end pad for Xogot bottom toolbar. Re-pull PR #10.

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
