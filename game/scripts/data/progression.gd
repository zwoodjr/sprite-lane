class_name Progression
extends RefCounted

## Dual-track progression (MVP):
##   A) In-run levels — kill/stay XP → loadout picks; RESETS every deploy.
##   B) Meta scrap — banked on extract; spent in Hangar on permanent upgrades.
## Account XP is soft prestige only (gates a few Hangar tiers); scrap is the fuel.

## --- In-run level curve (fast) ---
## L1→2: 30 · L2→3: 42 · L3→4: 54 · …
const RUN_XP_BASE := 30
const RUN_XP_STEP := 12
const RUN_LEVEL_CAP := 8

## --- Soft account prestige (not spend power) ---
const ACCOUNT_XP_BASE := 120
const ACCOUNT_XP_STEP := 60
const EXTRACT_ACCOUNT_XP := 25
const WIPE_ACCOUNT_XP_FLOOR := 8

## Loadout / stash UI not shipped — hide insurance buy CTA until it exists.
const LOADOUT_UI_SHIPPED := false


static func run_xp_to_next(level: int) -> int:
	var lv := clampi(level, 1, RUN_LEVEL_CAP)
	return RUN_XP_BASE + (lv - 1) * RUN_XP_STEP


static func run_progress(run_xp: int, run_level: int) -> Dictionary:
	if run_level >= RUN_LEVEL_CAP:
		return {"level": run_level, "into": 0, "need": 1, "ratio": 1.0, "capped": true}
	var need := run_xp_to_next(run_level)
	## run_xp is XP earned toward the *next* level (resets on level-up).
	return {
		"level": run_level,
		"into": run_xp,
		"need": need,
		"ratio": clampf(float(run_xp) / float(need), 0.0, 1.0),
		"capped": false,
	}


static func account_xp_to_next(level: int) -> int:
	var lv := maxi(1, level)
	return ACCOUNT_XP_BASE + (lv - 1) * ACCOUNT_XP_STEP


static func account_progress(total_xp: int) -> Dictionary:
	var xp := maxi(0, total_xp)
	var level := 1
	while xp >= account_xp_to_next(level):
		xp -= account_xp_to_next(level)
		level += 1
	var need := account_xp_to_next(level)
	return {
		"level": level,
		"into": xp,
		"need": need,
		"ratio": clampf(float(xp) / float(need), 0.0, 1.0),
	}


static func account_level_from_xp(total_xp: int) -> int:
	return int(account_progress(total_xp)["level"])


static func award_extract_account_xp(kills: int, tl_payout: float, mode_payout: float) -> int:
	## Soft prestige only — small vs scrap payout.
	var raw := EXTRACT_ACCOUNT_XP + kills * 2
	return maxi(1, int(float(raw) * tl_payout * mode_payout))


static func award_wipe_account_xp(kills: int, mode_payout: float) -> int:
	return maxi(WIPE_ACCOUNT_XP_FLOOR + kills, int(float(WIPE_ACCOUNT_XP_FLOOR + kills) * mode_payout))


## In-run upgrade pick pool (temporary — gone on extract/wipe).
static func run_upgrade_pool() -> Array[Dictionary]:
	return [
		{"id": "harder_hit", "name": "Harder Hit", "desc": "+15% weapon damage", "stat": "damage", "add": 0.15},
		{"id": "quick_mag", "name": "Quick Mag", "desc": "+20% fire rate", "stat": "firerate", "add": 0.20},
		{"id": "thick_plate", "name": "Thick Plate", "desc": "+30 max HP (heals the gain)", "stat": "max_hp", "add": 30.0},
		{"id": "dust_runner", "name": "Dust Runner", "desc": "+12% move speed", "stat": "move", "add": 0.12},
		{"id": "deep_mag", "name": "Deep Mag", "desc": "+8 mag size", "stat": "mag", "add": 8.0},
		{"id": "cool_head", "name": "Cool Head", "desc": "−20% ability cooldown", "stat": "ability_cd", "add": 0.20},
	]


static func roll_run_choices(count: int = 2, exclude: Array = []) -> Array[Dictionary]:
	var pool := run_upgrade_pool()
	var available: Array[Dictionary] = []
	for u in pool:
		if str(u["id"]) in exclude:
			continue
		available.append(u)
	available.shuffle()
	var out: Array[Dictionary] = []
	for i in range(mini(count, available.size())):
		out.append(available[i])
	return out


## Meta Hangar catalog — scrap spend, permanent. Soft-gated by account_level.
## Tuned so ~3 extracts cannot dump the tree (more ranks, steeper costs, extra skills).
## Avoided: wipe immunity, infinite ammo, huge flat DR stacks.
static func hangar_catalog() -> Array[Dictionary]:
	return [
		{
			"id": "starting_hp",
			"name": "Iron Rations",
			"desc": "+10 starting HP per rank",
			"cost": 90,
			"cost_step": 55,
			"cost_curve": 1.35,
			"max_rank": 8,
			"min_account_level": 1,
			"effect": "max_hp",
			"per_rank": 10.0,
		},
		{
			"id": "endurance",
			"name": "Dust Lungs",
			"desc": "+4% dash invulnerability time per rank",
			"cost": 80,
			"cost_step": 48,
			"cost_curve": 1.38,
			"max_rank": 6,
			"min_account_level": 1,
			"effect": "endurance",
			"per_rank": 0.04,
		},
		{
			"id": "scrap_find",
			"name": "Magnet Fingers",
			"desc": "+8% scrap found in-run per rank",
			"cost": 75,
			"cost_step": 50,
			"cost_curve": 1.4,
			"max_rank": 8,
			"min_account_level": 1,
			"effect": "scrap_find",
			"per_rank": 0.08,
		},
		{
			"id": "loot_quality",
			"name": "Apothecary Eye",
			"desc": "+3% chance crates drop a buff, per rank",
			"cost": 95,
			"cost_step": 58,
			"cost_curve": 1.4,
			"max_rank": 6,
			"min_account_level": 2,
			"effect": "loot_quality",
			"per_rank": 0.03,
		},
		{
			"id": "starting_damage",
			"name": "Honed Edge",
			"desc": "+4% base weapon damage per rank",
			"cost": 110,
			"cost_step": 65,
			"cost_curve": 1.4,
			"max_rank": 8,
			"min_account_level": 2,
			"effect": "damage",
			"per_rank": 0.04,
		},
		{
			"id": "crit_chance",
			"name": "Lucky Chamber",
			"desc": "+2% crit chance per rank",
			"cost": 100,
			"cost_step": 60,
			"cost_curve": 1.42,
			"max_rank": 6,
			"min_account_level": 2,
			"effect": "crit_chance",
			"per_rank": 0.02,
		},
		{
			"id": "crit_damage",
			"name": "Glass Tips",
			"desc": "+8% crit damage per rank (on top of ×1.5 crit base)",
			"cost": 115,
			"cost_step": 68,
			"cost_curve": 1.42,
			"max_rank": 6,
			"min_account_level": 3,
			"effect": "crit_damage",
			"per_rank": 0.08,
		},
		{
			"id": "aoe_damage",
			"name": "Shockwave Tape",
			"desc": "+5% pet / splash AoE damage per rank",
			"cost": 105,
			"cost_step": 62,
			"cost_curve": 1.4,
			"max_rank": 6,
			"min_account_level": 3,
			"effect": "aoe_damage",
			"per_rank": 0.05,
		},
		{
			"id": "dodge",
			"name": "Dust Sidestep",
			"desc": "+1.5% chance to dodge a hit per rank",
			"cost": 100,
			"cost_step": 60,
			"cost_curve": 1.45,
			"max_rank": 5,
			"min_account_level": 3,
			"effect": "dodge",
			"per_rank": 0.015,
		},
		{
			"id": "block",
			"name": "Brace Plate",
			"desc": "+2% chance to block half a hit per rank (full value for Sister Cinder, half for others)",
			"cost": 110,
			"cost_step": 65,
			"cost_curve": 1.45,
			"max_rank": 5,
			"min_account_level": 4,
			"effect": "block",
			"per_rank": 0.02,
		},
		{
			"id": "move_speed",
			"name": "Trail Dust",
			"desc": "+2% move speed per rank",
			"cost": 85,
			"cost_step": 50,
			"cost_curve": 1.38,
			"max_rank": 5,
			"min_account_level": 2,
			"effect": "move_speed",
			"per_rank": 0.02,
		},
		{
			"id": "pickup_radius",
			"name": "Long Reach",
			"desc": "+6 px pickup radius per rank",
			"cost": 70,
			"cost_step": 42,
			"cost_curve": 1.35,
			"max_rank": 5,
			"min_account_level": 1,
			"effect": "pickup_radius",
			"per_rank": 6.0,
		},
		{
			"id": "pet_power",
			"name": "Pack Rations",
			"desc": "+5% pet damage (bites, bark pressure, rampage / ram) per rank",
			"cost": 100,
			"cost_step": 60,
			"cost_curve": 1.4,
			"max_rank": 6,
			"min_account_level": 2,
			"effect": "pet_power",
			"per_rank": 0.05,
		},
		{
			"id": "dash_cooldown",
			"name": "Loose Boots",
			"desc": "−4% dash cooldown per rank",
			"cost": 85,
			"cost_step": 50,
			"cost_curve": 1.35,
			"max_rank": 6,
			"min_account_level": 2,
			"effect": "dash_cd",
			"per_rank": 0.04,
		},
		{
			"id": "extract_grace",
			"name": "Pad Linger",
			"desc": "+0.6s extract window open time per rank",
			"cost": 125,
			"cost_step": 75,
			"cost_curve": 1.45,
			"max_rank": 5,
			"min_account_level": 3,
			"effect": "extract_grace",
			"per_rank": 0.6,
		},
		{
			"id": "extract_payout",
			"name": "Ledger Grease",
			"desc": "+5% extract scrap payout per rank",
			"cost": 120,
			"cost_step": 70,
			"cost_curve": 1.45,
			"max_rank": 6,
			"min_account_level": 3,
			"effect": "extract_payout",
			"per_rank": 0.05,
		},
		{
			"id": "hangar_notes",
			"name": "Field Notes",
			"desc": "Hangar lore from the wastes — collect all three",
			"cost": 60,
			"cost_step": 40,
			"cost_curve": 1.2,
			"max_rank": 3,
			"min_account_level": 1,
			"effect": "notes",
			"per_rank": 1.0,
		},
		{
			## Hidden until a real loadout / stash screen ships — buying slots with nowhere to assign them is confusing.
			"id": "insurance_slot",
			"name": "Extra Tape",
			"desc": "+1 insurance slot — keep one more item on a wipe",
			"cost": 200,
			"cost_step": 120,
			"cost_curve": 1.5,
			"max_rank": 3,
			"min_account_level": 4,
			"effect": "insurance",
			"per_rank": 1.0,
			"requires_loadout_ui": true,
		},
	]


static func hangar_catalog_visible() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in hangar_catalog():
		if bool(entry.get("requires_loadout_ui", false)) and not LOADOUT_UI_SHIPPED:
			continue
		out.append(entry)
	return out


static func hangar_cost(entry: Dictionary, current_rank: int) -> int:
	## Base + linear step, then multiply by cost_curve^rank for late-rank stretch.
	var base := float(entry.get("cost", 50)) + float(entry.get("cost_step", 0)) * float(current_rank)
	var curve := float(entry.get("cost_curve", 1.0))
	if curve > 1.001 and current_rank > 0:
		base *= pow(curve, float(current_rank))
	return maxi(1, int(round(base)))


static func meta_bonus(meta: Dictionary, effect: String) -> float:
	var total := 0.0
	for entry in hangar_catalog():
		if str(entry.get("effect", "")) != effect:
			continue
		var rank := int(meta.get(str(entry["id"]), 0))
		total += float(entry.get("per_rank", 0.0)) * float(rank)
	return total
