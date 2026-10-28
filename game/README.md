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

Settings (tabbed): audio, video (frame cap, effects quality, edge dither, brightness), controls (stick size, left-handed), accessibility (text size, reduce motion, shake / flash strength), vibration.

**PC:** WASD move · Space dash · Q ability · R reload · Esc pause.

## Combat

Weapon data lives in `scripts/data/loadout_stubs.gd`: `trigger_range`, per-hero `muzzle` offset, `projectile` look, or a `melee` hitbox (Pebble maul arc, Nyx twin-blade slashes, Juno chain-gauntlet line). Helm's drones (1–4) each shoot the closest unclaimed enemy near them.

## Camera / FOV

Portrait **720×1280**, camera zoom **1.35**, hero ~45% down the screen with a 15% look-ahead in the move direction. Enemies spawn just outside the view; red edge arrows point at off-screen mobs (bigger for elites/bosses).

## What's in

- **First run:** PLAY on a fresh save drops the default survivor straight into Haze; the interactive tutorial (move → run-and-shoot → dash) runs in-match; replay from Settings
- **Onboarding phase-in:** run 1 is move / shoot / level up / extract. Each finished run switches on one more system (radio events → medicine & backpack → radio jobs → Daily / Weekly), announced on the result screen (`GameState.ONBOARD`). Saves with 4+ runs or a tier past Haze see everything
- **8 survivors** with distinct weapons, abilities, kits and quirks; pets Noel, Bentley, Lillie (+ buildable mech pets)
- **Roster:** ~30 enemy kinds across plague / machine / raider factions, elites with traits, bosses, raider crews, the Dust Warden
- **Stay-or-go:** extract windows open on a schedule; the loot multiplier climbs while you stay. **Greed pressure** (`ModeDefs.greed`): every window you let close makes mobs tougher / harder-hitting / denser, raises the live cap, and sends a punish wave + a Greed elite. HUD shows AT STAKE (what extracting now pays)
- **10 tiers** (Haze → Dustfall) with zone twists, Dust Pacts, tier loot; plus a story campaign (prologue, 12 levels, epilogue)
- **Level-ups:** rarity cards with tags, rerolls, evolutions (BUILD PATHS overlay shows every recipe)
- **Meta:** scrap is the only lasting currency; death keeps 10% of the bag at Haze (+5% per tier), extracting pays it all × multiplier. Hangar (shared camp, per-survivor stations, kennel, stash, backpack, brew, workshop), gear with sets and Legendaries, logbook, trophies. Main menu shows the next upgrade and how close you are
- **Juice:** hitstop, shake, flashes, merged damage numbers, kill chain, slow-mo beats on death / extract / bosses, haptics
- Save file `user://wanderer_save.json` (atomic, with backup) and a live-run snapshot so a force-quit can resume

## Not in yet

Insurance purchase UI (insured items already survive a death; the buy flow is intentionally hidden). Full mount trees.

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
