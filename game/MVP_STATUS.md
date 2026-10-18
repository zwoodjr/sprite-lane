# MVP status (repo mirror)

**Latest (Master Brief Phases 0–9):** Full brief pass on the Godot MVP.

- **P0 bugs** fixed (picker OOB, touch shoot, sticks, result unpause, scrap migration, chargers, focus-out pause, polygon spam, Dev chrome).
- **P1 feel:** on-screen auto-fire, 0.5s i-frames, heal drops, larger heroes / smaller pets, bottle-cap DASH/ABILITY, HEALTH/XP HUD.
- **P2 stay-or-go:** Haze/Drift + loot × mult / Threat, extract windows, 3s pad channel (hit resets), death keep %.
- **P3–4:** special ammo + shared/class run upgrades; survivor tricks (Overload, Rush, Heal, etc.).
- **P5:** elite/boss rewards, Rad Gator death cloud, role roster.
- **P6–7:** Hangar layers (Generator/Radio/Scrap Press/Ammo Bench, stations, kennel, stash) + gear/legendary stubs.
- **P8–9:** Dust tiers 1–10 unlock ladder; events (Supply Crash, Dust Surge, Elite Hunt…) + logbook/quest stubs.
  Headless `test_runner` PASS (both bot matches extract).

**Combat wiring pass:** Class upgrades now apply (was dropped by `run_mods.has`); shared shot mods (split/pierce/ricochet/poison), scrap drone / spore mines / orbit blades, firewalk / second wind / iron tonic, kennel ranks scale Noel/Bentley/Lillie, events (Scrap Spike / Dust Surge / etc.) apply timed effects, set-bonus tags from armor + stations.


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
