# MVP status (repo mirror)

**Latest (admin, economy, tester kit, Ascension curve, mob tricks, scrolling, auto-salvage, Crafter Bench):**

- **Admin panel** (ADMIN chip, top-right): the panel has 5 tabs (RUN / PLAYER / SPAWN / ACCOUNT / DEBUG) with 56 px buttons and −/+ steppers.
  - **RUN:** restart, timer pause (windows and storm hold, enemies keep coming), next window, jump to extract, extract now, teleport to a pad, a Greed stepper, kill all.
  - **PLAYER:** god mode, damage +% and defense +% steppers, run levels, ability and ammo refill.
  - **SPAWN:** elite, zone boss, every named boss, the Warden, or any enemy kind.
  - **ACCOUNT:** scrap and XP, tier and Ascension steppers, unlock tiers / Ascension / stations / mechs, gear grants (by rarity, set piece, Legendary weapon), the onboarding phase-in toggle, and a reset that asks for a second tap.
  - **DEBUG:** game speed 0.5/1/2/3×, FPS + frame-time overlay, hitboxes, enemy-cap toggle.
  - **Admin runs:** using god mode, damage/defense boosts, timer pause or speed flags the run **ADMIN RUN**. Scrap still banks, but bests, tier clears, Ascension records and the daily score are skipped, and the history entry is flagged.
- **Bunker economy v6.** Bot payouts per extract when leaving at window 2 (with max camp from T5 up): Haze 183, Drift 277, Smog 399, Pall 435, Blight 671, Shroud ~1,260, Blackout ~1,590, Deadfall ~1,900, Dustfall ~2,490. Choke had no clean extracts. The top-tier payout multipliers were trimmed (T7–T10: 2.5/3.0/3.5/4.5 → 2.3/2.6/3.0/3.6), so Dustfall now pays about 2,000.

  | Item | Ranks (scrap) | Gates |
  |---|---|---|
  | Shared ×4 | 400 / 1,600 / 4,800 | rank 2 after a Smog extract, rank 3 after Shroud |
  | Station ×8 | 250 / 1,100 / 3,300 | same |
  | Kennel ×6 | 200 / 650 / 1,600 | same |
  | Stash | 300 / 700 / 1,300 / 2,200 / 3,500 | –, Drift, Pall, Shroud, Deadfall |
  | Backpack | 250 / 800 / 1,800 | Smog / Shroud |
  | Insurance | 400 | – |
  | Crafter Bench | 1,200 / 2,800 / 5,000 | Blight / Shroud / Blackout |
  | **Whole bunker** | **99,350** (was 49,390) | about 45–60 runs |

  Owned ranks are kept (a one-time notice explains the change), and the menu's next-goal card skips gated ranks.
- **Tester kit:**
  - A build stamp (`v0.11.0 · dev`) shows on the title, pause and settings screens and in every report.
  - On iPhone/Xogot, SEND opens Mail with the report filled in (falling back to a clipboard copy). Reports now include position and the admin flag.
  - `TESTER_GUIDE.md` explains what to test and how to send feedback.
- **Ascension ladder.** Reordered from mild to harsh, A8/A9 "Dust-hardened", A10 Greed 1, and every level adds +4% enemy HP and +3% damage. Bot: Dustfall, max bunker + kit, clean driver, leave at the first window, 16 seeds (2 per hero) per level.

  | Level | Adds | Payout | Bot deaths |
  |---|---|---|---|
  | A0 | – | – | 4/16 |
  | A1 | No Mercy (no tonic drops) | +30% | 4/16 |
  | A2 | Narrow Windows (−3 s) | +55% | 5/16 |
  | A3 | Hunted (an elite each window) | +90% | 2/16 |
  | A4 | Thick Dust (+25% enemy HP) | +115% | 8/16 |
  | A5 | Hungry Dark (+25% enemies) | +140% | 7/16 |
  | A6 | Sharp Teeth (+20% enemy damage) | +170% | 7/16 |
  | A7 | Brittle Bones (−25% max HP) | +205% | 10/16 |
  | A8 | Dust-hardened (+15% enemy HP and damage) | +215% | 8/16 |
  | A9 | Dust-hardened II | +225% | 12/16 |
  | A10 | Greed 1 at the drop | +235% | 15/16 |

  A1, A2, A3 and A5 were re-run after the ramp was added; the other levels are from the run before it. Per-level noise is about ±2/16.
- **Mob tricks** (Wander, from run 2; not in the campaign). Every attack shows a red ring first.

  | Trick | Mobs | Faction / tier | What it does |
  |---|---|---|---|
  | Spitter | Ash-Singer, Glow-Moth Queen (3 globs) | plague, T1/T2 | lobs acid at your spot and leaves a puddle |
  | Burrower | Dune-Stalker, Dune-Serpent | plague, T1/T2 | dives, tunnels at you (untargetable), pops up under a ring |
  | Exploder | Coil-Spider, Void-Spider | machine T1, plague T3 | stops and blinks, then blows; killed mid-blink, it blasts its friends instead; no loot when it self-destructs |
  | Shield-bearer | Iron-Horse, Fusion-Golem | machine, T1/T2 | front shield; shield bash shoves you |
  | Summoner | Geist-Alpha, Apocalypse Wraith | plague, T2/T3 | calls minions in a purple ring; minions drop no loot, die with it, and are capped |

  In Haze 50% of these mobs use their trick, in Drift 75%, and from Smog up all of them. Bot A/B (Haze, stay 3, 8 heroes × clean/sloppy): the first tune took deaths from 2/16 to 12/15, the re-tune brings it to 5/15. The bot never dodges rings.
- **Scrolling.**
  - One shared touch-scroll helper attaches to every ScrollContainer.
  - A drag that starts on a row or button scrolls and never presses it. A tap without movement still fires.
  - Lists have momentum, a 12 px dead zone and an axis lock (no sideways steal).
  - A tap that rebuilds a list keeps its scroll position, and lists get bottom padding past the home bar.
  - Headless drag tests cover the Hangar tabs, settings, campaign map, prep, admin and a test list.
- **Auto-salvage.**
  - Settings and Stash offer Off / Commons / Up to Rare / Up to Epic, plus a separate set-piece toggle.
  - It never takes Legendary, locked, insured, worn, crafted, exclusive or Heart Vial items, or an upgrade.
  - Locked items show a LOCK tag in the stash.
  - The result screen breaks salvage down by rarity. BUY BACK still works.
- **Crafter Bench** (Hangar → Camp). Three craft-only 6-piece sets, about 15–25 focused runs each. The recipe screen shows what you have, what's missing and where each material drops.

  | Set | Bench | Per piece (×6) | 2 / 4 / 6 pc |
  |---|---|---|---|
  | Rustwright's Harness | 1 (Blight) | 900 scrap, 16 Salvage Core, 10 Machine Oil, 4 Dust Shard | +12% damage / machines take +25% and hit you −20% / every 12th kill a stunning nova |
  | Ashwalker's Shroud | 2 (Shroud) | 1,300 scrap, 16 Plague Gland, 6 Ashroot, 6 Dust Shard, 1 Dust Heart | 1 HP every 2 s / plague hits −30% / kills leave a poison cloud |
  | Dustborn Regalia | 3 (Blackout) | 2,000 scrap, 12 Dust Shard, 10 Salvage Core, 10 Plague Gland, 2 Dust Heart | +25 max HP / +10% crit / Dust Ward blocks one big hit every 30 s |


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
**Art pass 15 (unit repaint filter):** `tools/repaint_sprites.py` re-renders existing mob strips without changing frames, poses, silhouettes or attack data: edges softened at 4x, muted earthy palette with the same hue identity, top-left volume lighting from a pseudo height map, hide / metal texture, grime, rust streaks and specular in body space (phase-correlated per frame so nothing crawls), soft glow on toxic greens, translucent spills. Source is always the original art at `SRC_REV`, so re-runs never compound. Shipped on 20 units: rad gator, rad bat, scav bear, muck golem, glow moth, toxic scorp, apocalypse wraith, ash singer, ash wraiths, chimera rat, dune serpent, geist alpha, void spider, glow moth queen, scorpion king, wasteland god entity, rad gator matriarch, dread naught, dust warden, mutant overlord. Skipped because it muddied them or lost their colour identity: coil spider, dune stalker, fusion golem, iron horse, mech wyrm (both), scav bear cub, scrap hound, cyber juggernaut, and the human raiders (grunt, brute, captain). Heroes untouched. Noel, Bentley and Lillie get the `--light` pass only (palette and brightness toned down toward the earthy palette, darks and pixels kept, faint grime).

**Art pass 14 (camp, tabs, emblems, zone pickups, plane, trophies, painted):** `tools/gen_camp_icons.py` repaints the camp icons (reloading bench, diesel generator in a yellow cradle, lattice radio mast, hydraulic scrap press, steel footlocker), the 10 hangar tabs (pot of brew over a fire, canvas tent, dog tags, tear-off calendar, flag on rubble, plank doghouse, clipboard, cloth-bound book, footlocker, bench vise), the 12 set emblems as objects (hand bell, church candle, dynamite, cog + wrench, pilot wings, hard hat, high-voltage sign, crescent pendant, tincture phial + herb, pickaxe, crossed daggers, bone saw + scalpel), the 4 zone pickups (brass key with tag, gas-mask filter, power cell, road flare), Helm's 8 plane layers (same 60x32 grid and placement, painted worn aluminium, so the hangar composites unchanged) and the 3 hangar trophies (plank plaque, Dread Naught's cracked visor, Mutant Overlord's horned skull) at their old pixel sizes. HUD and settings icons stay flat on purpose. Note: `gen_depth_art.py` / `gen_hangar_art.py` would overwrite the zone, plane and trophy files if re-run; run `gen_camp_icons.py` after them.

**Art pass 13 (ability / upgrade / evolution / quirk icons, painted):** `tools/gen_card_icons.py` repaints all 78 card icons (abilities, upgrades, evolutions, quirks) as one real object each in the SOFT finish, e.g. stop-sign ram shield, dynamite bundle, toxin dart-vial, smoke grenade, sledge into a slab, car battery with jumper clamps, tesla coil, red-cross canteen, brass censer, toe tag + scalpel, rifle bayonet, drone + radio; stopwatch with frost (Cool Head), drum mag, knife through a playing card, molotov, saw blade, sandbags, paper target, shotgun shell + pellets, breaker box, anvil, pilot wings; aerial bomb, shock round, autopsy tray, riot shield, stained-glass window, scope, cracked bell, split road slab, coin stack, knifed IOU, beehive frame, storm cloud; war-painted skull, IV blood bag, glass cannon, ammo belt, dog collar, junk sack, magnet, spirit level. Effects kept small and muted.

**Art pass 12 (kept items redone + realism pass):** no old flat art left in the weapon-style, mod or loot sets. Redrawn: flare-pistol style (chunky signal-orange flare gun), grip (tape-wrapped pistol grip), edge (two-grit whetstone with a honed bevel), the 4 coatings (fire = steel tin with a red flame label, frost = frosted glass jar with a snowflake, poison = dark glass bottle with a drop mark and drip, shock = steel canister with copper terminals and a bolt label), scrap (big bolt, heavy nut, washer), XP (faceted amber crystal with a lit top facet), extract (thick road flare with a spark burst and smoke). Realism pass on every shipped weapon, style, mod and loot icon: muted paints (red, signal orange, glass, element tints, ammo-can stripes), broken-up specular, per-part value and saturation variation, subtler Epic element veins, arcs and drips; cluster bombs, knuckle duster and weighted head re-materialled to cast iron, cleaver rusted, Dust Heart cage now dark iron.

**Art pass 11 (kit + mods, painted):** `tools/gen_kit_icons.py`: the 24 weapon-style icons (each survivor's default style is its painted base weapon; the other 16 are new painted objects: cluster bomblets, slag mortar, battle rifle, coater rifle, sledgehammer, pile driver, cable whip, knuckle duster, cartridge fan, incendiary round, scalpels, cleaver, long knife, viper fangs, machine pistol) and 7 of 12 mods (barrel, extended mag, scope, stock, weighted head, wraps; 96 px too). Kept old art: flare-pistol style, grip, edge and the 4 coatings (the old element symbols read better).

**Art pass 10 (painted weapon finish):** all 32 weapon icons (+ 96 px legendary/base pickups) re-rendered in a painted finish to sit with the armour sheet: anti-aliased edges straight from the 4x render (no INK outline, no stair-steps), slightly brighter and richer paint, a soft darker rim and thin soft fringe instead of a line, and a real soft contact shadow at every size. Silhouettes, mechanical detail and rarity/element finishes unchanged (`SOFT` mode in `gen_legendary_icons.py`).

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
