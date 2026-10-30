# MVP status (repo mirror)

**Latest (long-term chase + Rook pass):**

- **Wander bosses:** tier 5+ boss windows now roll a named boss per zone that runs its campaign brain: Rad-Gator Matriarch, Mother Vane, Mutant Overlord, Unit Seven. The Dust Warden radio boss got its own brain (sand dash, dust hounds, a phase-2 storm ring). The Wasteland God-Entity is campaign-only, so it no longer rolls in the Wander pool.
- **Ascension (A1–A10):** opens after your first Dustfall extract, with a stepper on the Dustfall card. Each level adds one forced Pact or more starting Greed, on top of the levels below. Payout is +10% per level plus each Pact's own loot bonus. Clearing a level opens the next. Character select shows each survivor's best clear ("BEST CLEAR: DUSTFALL A3" or the highest tier name).

  | Level | Adds | Payout |
  |---|---|---|
  | A1 | Thick Dust: enemies +25% HP | +25% |
  | A2 | Sharp Teeth: enemies hit 20% harder | +55% |
  | A3 | Hungry Dark: +25% enemies | +80% |
  | A4 | Narrow Windows: windows close 3 s sooner | +105% |
  | A5 | No Mercy: no tonic drops | +135% |
  | A6 | Hunted: an elite joins every window | +170% |
  | A7 | Brittle Bones: -25% max HP | +205% |
  | A8 | Start at Greed 1 | +215% |
  | A9 | Start at Greed 2 | +225% |
  | A10 | Start at Greed 3 | +235% |

- **Fresh install:** the Mayday prologue plays first and then returns to the main menu, where the first PLAY ("PLAY — INTO THE HAZE") drops straight into Haze with the default survivor.
- **Rook (Braced Rush):** while she rushes and for 2 s after, she takes half damage. Rammed foes are stunned for 0.8 s (bosses are not), and each ram patches 4 HP (20 per rush). The cooldown dropped from 14 s to 10 s. She also gets a passive 15% damage reduction (heavy frame). Bot check, Haze, stay 3 windows, sloppy driver, the same 16 seeds: deaths went from 11/16 (69%) to 4/16 (25%), and survivors' end HP from 47% to 54%. For comparison, Juno ran 1/8 on the same driver.


**Fix (Choose Your Wanderer, iPhone):** the ADMIN chip moved into the top safe band, right-aligned, so it can no longer cover the hero strip. Hero tiles now shrink to fit the width (76 → min 56 px, scrolling past that), so all 8 heroes and the pet tiles are reachable at 390x844 and 375x667 with a notch and XL text. Review tool: `tools/charsel_shots.tscn`.

**Latest (combat, hangar, insurance pass):**

- **Abilities:** every survivor already had an active ability on the ability cap, with a cooldown ring and an icon: Rook RUSH, Vesper VIAL, Pebble SLAM, Juno ZAP (Overload chain stun), Cinder HEAL (Field Draught), Quill MARK (Dissect), Nyx SLASH (Blade Rush; the B version is Back Way Out), Helm DRONE. Each has a B version on the Loadout screen. New: **Settings → Controls → Aim with the stick** (off by default). Auto-fire still triggers itself but picks the enemy within ±35° of the direction you're steering.
- **Survivability:** Helm +20 max HP; Rook +25 max HP, 9-rocket drum, 420 reach. Vesper +25 max HP, +12% move speed, takes 15% less damage; her Vial Rifle fires 1.3 shots/s (was 1.05) and its slugs pierce 2. Sloppy-driver Vesper deaths 7/8 → 4/8; careful-driver 1/8.
- **Late healing:** each skipped window cuts all healing by 20% (heals, regen, tonics, tonic drops), down to a floor of 30%.
- **Bot table (Haze, stay 3 windows, 8 heroes × clean/sloppy driver, same seeds):**
  - Before this pass: 25% deaths, survivors ended at 86% HP.
  - Final: 13% deaths (4/30), survivors end at 65% and dip to ~54% at their lowest.
  - By hero: Vesper 0/4 (was 2/2), Helm 1/3, Rook 2/4 (still the most fragile; she also got +25 HP, a 9-rocket drum and 420 reach).
  - Leaving at window 1: 0 deaths, ~95% HP.
- **Hangar v5:** shared camp upgrades and survivor stations now have 3 big ranks instead of 5 small ones, for the same total cost.
  - Generator +16/32/50 HP, Radio Tower 5/10/15 s, Scrap Press +12/25/40%, Ammo Bench 3 tiers.
  - Stations give +10/20/32% weapon damage, −7/13/20% ability cooldown, +12/27/45% ability power. Kit styles unlock at station 1/2; ability B at 2.
  - Old saves merge ranks pairwise (5→3, 4→2, 3→2, 2→1, 1→1); scrap paid beyond the merged rank is refunded, with a Hangar notice.
  - The hangar art still builds out: rank 1/2/3 shows art stage 1/3/5.
- **Insurance finished:** CAMP sells an **Insurance Locker** (400 scrap, one-time). It enables INSURE on one worn piece per survivor, and that piece survives death. Saves that already had insured gear get the locker free.
- **Deepened systems:**
  - **Medicine, drink or bank:** BACKPACK → DRINK heals 45% (Cinder's dose 70%) but gives up the crate's scrap and Cinder's brewing stock.
  - **Radio jobs:** a finished contract takes Greed −1, and each contract announces its reward up front.
  - The rest (events, lore, bestiary, pacts, weekly) stay light and phase in via onboarding.
- **Bullet pooling skipped:** a bullet costs ~0.11 ms to spawn, roughly 2–3 ms per second of heavy fire. A safe reset would cover about 30 fields plus `_ready`-time dressing and the trail tween, which isn't worth the risk.

Test on device: (1) Hangar on an old save shows the merge/refund notice, 3-rank pips, and art that still builds out; (2) buy the Insurance Locker, INSURE a piece, die, and confirm it came home; (3) a Haze run past window 2 — healing feels scarce, BACKPACK → DRINK works, and finishing a radio contract drops GREED.
**Art pass 9 (painted loot, code-rendered):** `tools/gen_loot_icons.py` paints the loot set toward Zach's armour sheet with the weapon/gear engine (corked glass bottles with liquid + meniscus + handwritten labels, dried sage bundle, fungal cluster, mineral cluster, dented jerry can, glass-and-steel power cell, steel first-aid case, caged amber heart, canvas rucksack, wooden ammo crate, element-stencilled ammo cans, brass rank medal). Wired: 6 ingredients, 7 tonics, Salvage Core + Dust Heart materials, backpack, supply crate, 4 ammo types, level medal (IconSet 48/24 + 96 world pickups). Kept the old art for scrap, XP and extract (the painted versions read worse at 24 px next to numbers).

**Art pass 8 (Zach's painted armour):** every armour / accessory icon (27 generic, 48 set pieces, 8 tier Legendaries) now comes from Zach's painted sheet `tools/art_src/armor_sheet_zach_v1.png`, cut by `tools/slice_armor_sheet.py`: explicit crop table per item with both painted variants (L/R) and a `PICK` letter per item (flip to swap), cell background keyed out (flood from the border; orange-band glow removed; soft contact shadow kept), centred with a 1 px margin, written at 48 / 24 px (IconSet) and 96 px pickups. Frames stay game-drawn. `gen_gear_icons.py` remains the fallback and re-runs the slicer at its end; no items are currently missing from the sheet.

**Art pass 7 (armour readability):** every armour / accessory shape in `tools/gen_gear_icons.py` redrawn from a real-world silhouette: 3/4-view hood (drape, folds, lined opening with a shadowed — not black — interior, rolled hem, drawstring; no eyes), a proper plague-doctor mask (long curved downturned beak to a point, stitched ridge and panel seams, brass-rimmed glass lenses, strap + buckle, brimmed hat), combat helmet with smoked visor, patrol cap, construction hard hat, surgical mask + cap, flying helmet; plate carrier (MOLLE, mag pouches), field coat with sleeves, steel cuirass with neck roll + faulds; asymmetric pauldrons on a yoke, laminated spaulders, cloak mantle with drape folds; greaves with knee cops, cargo trousers with knee patches + wrinkles, trousers-and-puttee leggings; work gloves (seams, cuffs, thumbs), wrapped hands with frayed tails; side-profile combat boots (lacing, toe cap, lugged sole); rabbit's-foot keychain, crown bottle cap with a star. Checked at in-game size and upside down for unintended shapes.

**Art pass 6 (realistic armour + accessories):** `tools/gen_gear_icons.py` renders every gear icon with the weapon engine (stitching, rivets, buckles, straps, plates, padding, lenses, filters; leather / canvas / rubber / plate / chainmail / weave / glass / fur shading, edge wear, chips, rust, grime, AO, 96 px contact shadow). 27 generic pieces (`gear_<slot>_<noun>`, Common-Epic, frame = rarity), 48 matched set pieces (`gset_<set>_<slot>`: 4 general sets x 6 + 8 survivor sets x 3, one palette + motif per set: plague beak mask + waxed canvas, demolition hazard stripes, night-runner slate + teal lenses, salvager ochre + pouches, foreman hi-vis + hard hat, bell-ringer purple + bell, quarry stone plate, lineman teal + rubber + copper, cathedral red + gold cross, surgeon stained whites, smuggler charcoal wraps + coins, flight-crew leather + fur + goggles) and the 8 tier Legendaries (`tleg_<id>`: gas mask, lamplighter coat + lantern, quarantine seal, spiked kingsguard pauldrons, chem-filter canister, officer gauntlets, crater treads, Dust Heart relic). `IconSet.item` now prefers `tleg_<exclusive>` then `gset_<set>_<slot>` before the generic noun icon (falls back if missing). 96 px pickups: `icons/gear/icon_slot_*`, `icon_acc_*`.

**Art pass 5 (realistic weapon render):** all weapon icons (every rarity, 96 + 48 px; 24 px inherits) re-rendered toward real gun art in `tools/gen_legendary_icons.py`. Real-pattern builds in a gun-local frame: Last Shift = RPG-style tube, venturi, wooden heat guard, grips, optic, booster + warhead; Bellwether = bolt-action with comb stock, bolt handle, scope on rings with turrets, muzzle brake; Censer = AR-pattern (buffer tube stock, lower + curved mag, upper with ejection port / forward assist / charging handle, carry handle, vented handguard, front sight, can); Mayday = service pistol (serrated slide, port, sights, hammer, checkered grip + screws) with the flare launcher clamped under. Maul / gauntlet / bayonet / knives get couplings, hose clamps, a hydraulic piston, ribbed grips, bright edge bevels. Shader: environment-reflection metal with anisotropic brushing, specular, edge wear to bright metal, layered chips (paint → primer → bare metal), rust with depth and pitting, wood grain + pores, fabric weave, per-part cast shadows (AO), soft contact shadow on the 96 px icons, final-res grit + light unsharp so detail stays crisp. Layout auto-fits to fill each icon. Rarity / element finishes unchanged.

**Art pass 4 (every weapon icon):** Common→Epic weapon icons repainted in the legendary style by `tools/gen_legendary_icons.py` (one drawing per survivor, finished per rarity): Common = rusted through + a rag tied on; Rare = worn teal service paint/wraps; Epic = element finish (fire scorched black + ember veins, poison toxic-green paint + venom drips, shock blued steel + arcs, frost pale paint + ice blade + rime); Legendary keeps red/brass furniture + its own attachment (bell, censer, coin, live arcs — non-legendaries no longer show them). Element medallions are gone; the frame colour + finish carry rarity. 24 px icons are a simplified variant (thin parts ~2x bolder, no rivets/welds/scratches) and 48/24 px icons auto-shrink until the outline keeps a 1 px margin (fixes Last Shift touching the frame). `icons/weapons/weapon_<hero>.png` (96 px base pickups) come from the same script; `gen_weapon_icons.py` now just runs it. Mob wear retried frame-stably (silhouette-column dirt bands): stable, but invisible at phone size, so not shipped. Hangar camp upgrades already have worn art for every stage (5 each, Kennel 3 per dog); unchanged.

**Art pass 3 (weapons + art audit):**

- **Legendary weapons redrawn** (`tools/gen_legendary_icons.py`) to match the guns on the hero sprites: gunmetal with worn bright edges, red paint chipped to steel, rust bloom and streaks, welded patch plates, rivets, tape/cord wraps, oiled wood, no medallions. Painted at 4x and box-filtered down. Covers the 96 px pickup icons (`icons/legendary/`, faint gold halo) and the IconSet 48/24 px icons the stash / gear / loadout actually show (`set/{48,24}/leg_*` + `wpn_<hero>_<legendary>`). `gen_icons.py` re-runs it at the end, so a full icon rebuild keeps them. Common-Epic base weapon icons (`icons/weapons/`) re-derived from them by `gen_weapon_icons.py`.
- **Sprite resolution audit:** heroes, pets and regular mobs are already 128 px frames, elites 192, bosses 256 (UnitAnim / `MOB_FRAME_WORLD` / `ELITE_SCALE` / `BOSS_SCALE` already map them to the same world size), so no rescale was needed. The old 96 px generators (`gen_sprites.py`, `gen_walk_cycles.py`) predate the current painted art and would regress it; not re-run.
- **Tried and dropped:** a palette-stepped grime/rust pass on the mob roster. The mob strips are painted per frame, so procedural marks crawl between frames and read as noise; not shipped.
- **Texture memory:** unchanged, 506 MiB if every PNG were resident (all lossless, no mipmaps; icon sizes kept). Typical run: hero ~5.6 MiB, pet ~7 MiB, regular mob ~5-7 MiB per kind, elite ~11, boss ~22.

**Prior (difficulty + onboarding pass):** Fixes from the overnight critique.

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
