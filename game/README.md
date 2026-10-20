# Wanderer (Godot 4.3) — iPhone / Xogot first

Solo top-down extraction shooter. **Portrait** (survivor FOV). PC keyboard/mouse also works.

## Controls (phone)

| Input | Action |
|-------|--------|
| Thumb anywhere on the left 60% | Floating MOVE stick (10% dead zone, full speed at 60% deflection, base follows your thumb) |
| — | **Attacks are automatic**: the hero fires / swings at the closest on-screen enemy inside weapon range |
| DASH (big cap) | Burst + brief invincibility (dash through bullets) |
| Ability cap | Character ability, with cooldown ring |
| Pause cap (top-right) | Pause · How to play · Settings · Abandon run |
| Stand on an open gold pad | Extract |

Settings: stick size, left-handed (mirrors stick zone and buttons), hints, sound, vibration, shake.

**PC:** WASD move · Space dash · Q ability · R reload · Esc pause.

## Combat

Weapon data lives in `scripts/data/loadout_stubs.gd`: `trigger_range`, per-hero `muzzle` offset, `projectile` look, or a `melee` hitbox (Pebble maul arc, Nyx twin-blade slashes, Juno chain-gauntlet line). Helm's drones (1–4) each shoot the closest unclaimed enemy near them.

## Camera / FOV

Portrait **720×1280**, camera zoom **1.35**, hero ~45% down the screen with a 15% look-ahead in the move direction. Enemies spawn just outside the view; red edge arrows point at off-screen mobs (bigger for elites/bosses).

## What's in

- First-run interactive tutorial (move → run-and-shoot → dash); replay from Settings
- How to Play pages (menu + pause)
- 3 enemy types with visible wind-up warnings: raider, charger, brute
- Juice: SFX, screen shake, hitstop, hit flashes, damage numbers, particles, recoil, muzzle flash, dash afterimages, low-HP vignette
- HUD explains itself: phase card says what to do now; Threat badge shows the cost/reward
- Save file (`user://wanderer_save.json`): settings, banked scrap, Hangar ranks, account prestige, extracts, unlocks
- Dual-track progression: **run levels** (temporary loadout picks mid-match) + **Hangar scrap** (permanent between runs — stretched costs; insurance buy hidden until loadout UI)
- Event stubs: `EventDefs` radio/world/extract_side catalog + one mid-run radio toast (no quest log)
- Endless chunk map with terrain variation, varied decor, extract beams + arrows + minimap

## Not in yet (waiting on design doc)

Other 8 characters, full armor/weapon/pet/mount trees, Hard+ modes, deep skill trees. MVP pets: **Noel** (Territorial Rampage) + Dust Hound.

## Tools

- `tools/test_runner.tscn` — headless bot playtest: `godot --headless --path game res://tools/test_runner.tscn`
- `tools/screenshot.tscn` — renders every screen to PNG (needs a display / xvfb)
- `tools/audio/build_sfx.py`, `tools/audio/build_music.py` — rebuild all audio from CC0 recordings + synthesis (see `assets/ATTRIBUTION.md`); `tools/gen_sprites.py` — Dust Apothecary chunky-pixel art (`gen_sprites_v2.py` wraps the same generator)

## Meta progression (Phases A–D)
- **Hangar** (`HangarDefs`): shared camp upgrades (Generator, Radio Tower, Scrap Press, Ammo Bench), a station per survivor, Kennel ranks per dog, Stash slots. The hangar picture builds out per rank (`tools/gen_hangar_art.py`). Old flat-Hangar spend is refunded once.
- **Gear** (`GearDefs`): Common→Legendary, 6 armor + 3 accessories, 4 general and 8 survivor sets, per-survivor weapon variants with 2 mods, 8 named Legendaries. Found gear is kept only on extract; one insured item survives a death. Elites (tier 3+) and bosses (tier 5+) pay out per Part 3.
- **Events + Logbook** (`EventDefs`, `QuestDefs`): 1–2 radio events per run, Ambush Bounty / Pet Bond on extract, daily quests, survivor stories ending in their Legendary, camp milestones that add hangar cosmetics.
- **Tiers** (`ModeDefs.TIER_TABLE`): Haze→Dustfall; each unlocks after extracting on the one below.
- Tests: `godot --headless --path game res://tools/test_runner.tscn` (restores your save afterwards). Bot: `tools/playtest_bot.tscn` (arg 13 `max` camp, arg 14 `kit` gear). Screens: `tools/screenshot.tscn -- OUT hangar|gear|events`.

## Depth Update (E1–E7)
All tuning lives in `scripts/data/`: `medicine_defs` (ingredients, pouch, backpack, medicine crates, tonics, plague exposure),
`faction_defs` (weaknesses, elite traits, infighting, raider crews), `recipe_defs` + `bestiary_defs` (evolutions, Field Notes,
lore pages), `radio_defs` (Helm's contracts, camp cameos, Dust Warden, stay-or-go stakes), `kit_defs` (weapon styles, ability
B versions, quirks — picked on the pre-run Loadout screen), `pet_defs` / `hangar_defs` (mech pets from Salvage Cores, built in
the Workshop) and `zone_defs` (tiers 3–10 as zones with twists, tier-exclusive loot, tier trophies, Dust Pacts, Helm's plane).
Art tools: `tools/gen_depth_art.py` (cel items/props/plane), `tools/gen_zone_tiles.py` (zone ground sets),
`tools/gen_mech_pets.py` (mech pets from the machine rigs), `tools/gen_hud_readout.py` (HP/XP readout).
Tests: `tools/test_runner.tscn` (`-- only=depth_e7` runs one section); screenshots: `tools/depth_shots.tscn -- <out> <phase>`.
