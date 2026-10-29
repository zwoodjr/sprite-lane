# MVP status (repo mirror)

**Art pass 4 (every weapon icon):** Common→Epic weapon icons repainted in the legendary style by `tools/gen_legendary_icons.py` (one drawing per survivor, finished per rarity): Common = rusted through + a rag tied on; Rare = worn teal service paint/wraps; Epic = element finish (fire scorched black + ember veins, poison toxic-green paint + venom drips, shock blued steel + arcs, frost pale paint + ice blade + rime); Legendary keeps red/brass furniture + its own attachment (bell, censer, coin, live arcs — non-legendaries no longer show them). Element medallions are gone; the frame colour + finish carry rarity. 24 px icons are a simplified variant (thin parts ~2x bolder, no rivets/welds/scratches) and 48/24 px icons auto-shrink until the outline keeps a 1 px margin (fixes Last Shift touching the frame). `icons/weapons/weapon_<hero>.png` (96 px base pickups) come from the same script; `gen_weapon_icons.py` now just runs it. Mob wear retried frame-stably (silhouette-column dirt bands): stable, but invisible at phone size, so not shipped. Hangar camp upgrades already have worn art for every stage (5 each, Kennel 3 per dog); unchanged.

**Art pass 3 (weapons + art audit):**

- **Legendary weapons redrawn** (`tools/gen_legendary_icons.py`) to match the guns on the hero sprites: gunmetal with worn bright edges, red paint chipped to steel, rust bloom and streaks, welded patch plates, rivets, tape/cord wraps, oiled wood, no medallions. Painted at 4x and box-filtered down. Covers the 96 px pickup icons (`icons/legendary/`, faint gold halo) and the IconSet 48/24 px icons the stash / gear / loadout actually show (`set/{48,24}/leg_*` + `wpn_<hero>_<legendary>`). `gen_icons.py` re-runs it at the end, so a full icon rebuild keeps them. Common-Epic base weapon icons (`icons/weapons/`) re-derived from them by `gen_weapon_icons.py`.
- **Sprite resolution audit:** heroes, pets and regular mobs are already 128 px frames, elites 192, bosses 256 (UnitAnim / `MOB_FRAME_WORLD` / `ELITE_SCALE` / `BOSS_SCALE` already map them to the same world size), so no rescale was needed. The old 96 px generators (`gen_sprites.py`, `gen_walk_cycles.py`) predate the current painted art and would regress it; not re-run.
- **Tried and dropped:** a palette-stepped grime/rust pass on the mob roster. The mob strips are painted per frame, so procedural marks crawl between frames and read as noise; not shipped.
- **Texture memory:** unchanged, 506 MiB if every PNG were resident (all lossless, no mipmaps; icon sizes kept). Typical run: hero ~5.6 MiB, pet ~7 MiB, regular mob ~5-7 MiB per kind, elite ~11, boss ~22.

**Latest (difficulty + onboarding pass):** Fixes from the overnight critique.

- **Greed pressure** (`ModeDefs.greed`, `match_controller._greed_punish`): every extract window you let close → mobs +45% HP, +28% damage, +50% spawn rate, +5 live cap (stacks to 4), plus a two-sided punish wave and a Greed elite on every tier. Base live cap 12 → 18. Tonic drops cut (T1 6% → 3%), idle regen 2 → 1 HP/s. HUD: AT STAKE (what extracting now pays; turns rust/red with greed) and GREED n on the threat line. Wipe result: "Extracting would have paid N."
- **Kill-drop firehose:** one scrap + one XP shard per kill (two from elites/bosses), same value.
- **Bot numbers, Haze, 8 heroes × clean/sloppy driver:** stay 3 windows — before 0/16 deaths, ~96% HP at the pad; after 4/16 deaths (25%), mean end HP 65% incl. deaths (survivors bottom out ~62%). Leave at window 1 — still 0 deaths, ~94% (gentle first run). Frail ranged heroes (Vesper, Helm) die most. 60-mob horde profile unchanged (~13.7 / 12.4 ms).
- **Onboarding phase-in** (`GameState.ONBOARD`): run 1 = move/shoot/level/extract. Then one per finished run: radio events → medicine & backpack (+ kill ingredients) → radio jobs → Daily/Weekly cards. NEW card on the result screen + a toast at the next run's start. Saves with 4+ runs or a tier past Haze see everything; campaign untouched.
- **Fast start:** first PLAY on a fresh save goes straight into Haze with the default survivor (tutorial runs in-match). Main menu shows NEXT/READY: cheapest Hangar upgrade with a scrap bar (tap → Hangar). Note: a brand-new install still auto-plays the campaign prologue first (existing design).
- **Cleanups:** removed the duplicate mid-lockout radio stub, dead combat-tips code, unused `Juice.LEGACY` ids, the no-op Endurance hook (Endurance was already refund-only); `film_grain` setting → `edge_dither` (old saves migrate); insurance purchase stays hidden (noted in code + README); README refreshed. There is no iOS export preset (Xogot loads the folder; the Web preset already excludes `tools/`), so every tools scene is parse-checked instead.

Test on device: (1) Haze, stay past 2–3 windows — the seal should hit hard (punish wave + Greed elite), AT STAKE climbing; (2) fresh install / cleared save → PLAY lands in Haze, then NEW cards over the next 4 runs; (3) main-menu NEXT/READY card + Settings → Edge dither keeps its old value.

**Prior (overnight polish pass):** Performance + feel + UI polish (parse-checked on Godot 4.3 and 4.6; full test suite passes on both).

Performance
- Kill loot capped at 70 live drops; overflow value merges into the nearest same-kind drop (a horde used to leave 400+ drops ticking every frame).
- Enemy separation: shared per-frame enemy list, recomputed every 3rd frame per mob (was O(n²) with an array alloc per mob per frame).
- Mob art warm-up: one enemy kind's strips load per frame at run start (likeliest tiers first, then elites/bosses/raiders). First spawn of a kind was an 8–30 ms hitch; now ~1 ms.
- Attack JSON + telegraph frames cached (were re-read/parsed per spawn). Bullet tail gradients shared (no Gradient/dict per shot).
- Pools: debris bursts (16 emitters/scene, cached ramps) and floating callouts (24 labels/scene) — no node+timer per effect.
- HUD only touches theme overrides / label text on change (was every frame); mobs skip the status-overlay lookup when they have none; pack/pouch readout at 5 Hz.
- GPU: the world colour grade now draws as a multiply blend (no full-screen back-buffer copy + read every frame); the screen-read shader only comes back if Brightness is moved off default. Same look (mean diff ~1/255).
- Same-seed 60-mob horde, headless 4.3, before → after: physics ~16 → ~11.5 ms, process ~14.7 → ~13.3 ms. 4-minute run: node/object counts flat (no leaks).

Feel
- DROP IN: hero falls into frame and lands with dust ring, shake, thud, haptic.
- Death: red flash, camera punch-in, 1 s slow-mo, heavy haptic. Extract: warm flash, punch, short slow-mo, hero stretches up into the beam. Boss arrival: half-speed beat + heavy haptic. Boss kill: slow-mo, big blast, warm flash. Level-up: gold screen pop.
- Low HP (<25%): heartbeat double-tap haptic, quicker as HP drops.
- KILL CHAIN readout under LOOT (from x5; RAMPAGE / CARNAGE / MASSACRE / WASTELAND LEGEND at 10/25/50/100), best chain on results.
- Damage numbers scale with size (chip / 80+ / 250+), crits get "!". XP pickup streak climbs in pitch.
- Extract channel: haptic ticks + sparks quicken toward lift-off.

UI
- Level-up cards: rarity-coloured frame + tint (uncommon green, rare teal, epic mauve, evolution gold), glow on epic+, chosen card stamps; cards grow to fit 2-line text (evolution tags were spilling out).
- BUILD PATHS button on the level-up screen: every evolution for this hero with part progress, READY first.
- Pause shows YOUR BUILD (icons + ranks).
- Result: NEW BEST HAUL stamp; best kill chain line; wipe explains "Kept N% of the bag. Extract to keep it all."
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
