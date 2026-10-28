# MVP status (repo mirror)

**Latest (overnight polish pass):** Performance + feel + UI polish (parse-checked on Godot 4.3 and 4.6; full test suite passes on both).

Performance
- Kill loot capped at 70 live drops; overflow value merges into the nearest same-kind drop (a horde used to leave 400+ drops ticking every frame).
- Enemy separation: shared per-frame enemy list, recomputed every 3rd frame per mob (was O(n²) with an array alloc per mob per frame). 60-mob horde physics ~12 → ~8.5 ms headless.
- Mob art warm-up: one enemy kind's strips load per frame at run start (likeliest tiers first, then elites/bosses/raiders). First spawn of a kind was an 8–30 ms hitch; now ~1 ms.
- Attack JSON + telegraph frames cached (were re-read/parsed per spawn). Bullet tail gradients shared (no Gradient/dict per shot).
- Pools: debris bursts (16 emitters/scene, cached ramps) and floating callouts (24 labels/scene) — no node+timer per effect.
- HUD only touches theme overrides / label text on change (was every frame); mobs skip the status-overlay lookup when they have none.

Feel
- DROP IN: hero falls into frame and lands with dust ring, shake, thud, haptic.
- Death: red flash, camera punch-in, 1 s slow-mo, heavy haptic. Extract: warm flash, punch, short slow-mo, hero stretches up into the beam. Boss arrival: half-speed beat + heavy haptic.
- KILL CHAIN readout under LOOT (from x5; RAMPAGE / CARNAGE / MASSACRE / WASTELAND LEGEND at 10/25/50/100), best chain on results.
- Damage numbers scale with size (chip / 80+ / 250+), crits get "!". XP pickup streak climbs in pitch.
- Extract channel: haptic ticks + sparks quicken toward lift-off.

UI
- Level-up cards: rarity-coloured frame + tint (uncommon green, rare teal, epic mauve, evolution gold), glow on epic+, chosen card stamps; cards grow to fit 2-line text (evolution tags were spilling out).
- BUILD PATHS button on the level-up screen: every evolution for this hero with part progress, READY first.
- Pause shows YOUR BUILD (icons + ranks).
- Result: NEW BEST HAUL stamp; best kill chain line.
- Hangar: scrap total rolls down on purchase; red squash when you can't afford.
- Helm radio panel sits left of the minimap/loot column (it covered both).
- Tests: three timing-flaky checks now wait on the condition (boss bar poll, music hold, pan voice).

Test on device: (1) a big horde on Dustfall/Last Extract — frame pacing, and all scrap/XP still arrive; (2) die once + extract once + meet a boss — slow-mo beats must always return to full speed; (3) level-up card colours, BUILD PATHS overlay scroll, pause YOUR BUILD row on a notched phone.

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
