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


## Shared-pool + class-exclusive in-run picks (Part 4). Temporary — gone on extract/wipe.
const SHARED_COSTS := [100, 250, 500, 900, 1500]
const STATION_COSTS := [80, 200, 400, 700, 1100]
const KENNEL_COSTS := [150, 400, 900]
const STASH_COSTS := [300, 600, 1000]


static func run_upgrade_pool(char_id: String = "") -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		## Gun
		{"id": "ricochet", "name": "Ricochet Rounds", "desc": "Shots bounce to a second enemy", "stat": "ricochet", "add": 1.0, "max_stacks": 2},
		{"id": "split_shot", "name": "Split Shot", "desc": "Every third shot fires three", "stat": "split", "add": 1.0, "max_stacks": 2},
		{"id": "dust_rounds", "name": "Dust Rounds", "desc": "Hits apply poison DoT", "stat": "poison", "add": 1.0, "max_stacks": 3},
		{"id": "piercing", "name": "Piercing Slugs", "desc": "Shots pass through the first enemy", "stat": "pierce", "add": 1.0, "max_stacks": 2},
		## Helpers
		{"id": "scrap_drone", "name": "Scrap Drone", "desc": "A small drone fires with you", "stat": "drone", "add": 1.0, "max_stacks": 2},
		{"id": "spore_mines", "name": "Spore Mines", "desc": "Drop mines as you move", "stat": "mines", "add": 1.0, "max_stacks": 2},
		{"id": "orbit_blades", "name": "Orbiting Blades", "desc": "Scrap blades circle you", "stat": "blades", "add": 1.0, "max_stacks": 2},
		## Movement / defense
		{"id": "firewalk", "name": "Firewalk", "desc": "Dash leaves a fire trail", "stat": "firewalk", "add": 1.0, "max_stacks": 2},
		{"id": "second_wind", "name": "Second Wind", "desc": "Dashing heals a little", "stat": "dash_heal", "add": 8.0, "max_stacks": 3},
		{"id": "iron_tonic", "name": "Iron Tonic", "desc": "Shield blocks one hit, then recharges", "stat": "shield", "add": 1.0, "max_stacks": 2},
		## Economy
		{"id": "scav_eye", "name": "Scavenger's Eye", "desc": "Enemies drop more scrap", "stat": "scrap_find_run", "add": 0.25, "max_stacks": 3},
		{"id": "lucky_vial", "name": "Lucky Vial", "desc": "Better odds on the next level-up", "stat": "luck", "add": 1.0, "max_stacks": 2},
		## Classic stat bumps (still useful)
		{"id": "harder_hit", "name": "Harder Hit", "desc": "+15% weapon damage", "stat": "damage", "add": 0.15, "max_stacks": 3},
		{"id": "quick_mag", "name": "Quick Mag", "desc": "+20% fire rate", "stat": "firerate", "add": 0.20, "max_stacks": 3},
		{"id": "thick_plate", "name": "Thick Plate", "desc": "+30 max HP", "stat": "max_hp", "add": 30.0, "max_stacks": 3},
		{"id": "dust_runner", "name": "Dust Runner", "desc": "+12% move speed", "stat": "move", "add": 0.12, "max_stacks": 3},
		{"id": "deep_mag", "name": "Deep Mag", "desc": "+8 mag size", "stat": "mag", "add": 8.0, "max_stacks": 3},
		{"id": "cool_head", "name": "Cool Head", "desc": "−20% ability cooldown", "stat": "ability_cd", "add": 0.20, "max_stacks": 2},
	]
	pool.append_array(_class_upgrades(char_id))
	return pool


static func _class_upgrades(char_id: String) -> Array[Dictionary]:
	var id := CharacterDefs._canonicalize(char_id) if char_id != "" else ""
	match id:
		CharacterDefs.ASH_ROOK_ID:
			return [
				{"id": "rook_aftershock", "name": "Aftershock", "desc": "RUSH ends in an explosion", "stat": "class_aftershock", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "rook_rubble", "name": "Rubble Wall", "desc": "Knocked-back foes slam into each other", "stat": "class_rubble", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.VESPER_THORN_ID:
			return [
				{"id": "vesper_bell", "name": "Bell Tower", "desc": "Standing still charges stronger shots", "stat": "class_bell", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "vesper_mark", "name": "Marked", "desc": "Hits make enemies take extra damage", "stat": "class_mark", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.PEBBLE_ID:
			return [
				{"id": "pebble_unbreakable", "name": "Unbreakable", "desc": "Reduced damage below half HP", "stat": "class_unbreakable", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "pebble_quarry", "name": "Quarry Slam", "desc": "Every few swings, ground slam stun", "stat": "class_quarry", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.BOLT_JUNO_ID:
			return [
				{"id": "juno_livewire", "name": "Live Wire", "desc": "Overload chains to more enemies", "stat": "class_livewire", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "juno_short", "name": "Short Circuit", "desc": "Stunned machines take double damage", "stat": "class_short", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.CINDER_ID:
			return [
				{"id": "cinder_sanctuary", "name": "Sanctuary", "desc": "Heal leaves a healing puddle", "stat": "class_sanctuary", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "cinder_burn", "name": "Burn It Down", "desc": "Healing while hurt ignites nearby foes", "stat": "class_burn", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.QUILL_MARROW_ID:
			return [
				{"id": "quill_notes", "name": "Field Notes", "desc": "Kills of a type strengthen you vs that type", "stat": "class_notes", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "quill_bayonet", "name": "Bayonet", "desc": "Close enemies are stabbed automatically", "stat": "class_bayonet", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.NYX_CALDERA_ID:
			return [
				{"id": "nyx_back", "name": "Back Way Out", "desc": "Dash makes you briefly invisible", "stat": "class_stealth", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "nyx_cross", "name": "Double Cross", "desc": "Hits from behind deal triple damage", "stat": "class_backstab", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		CharacterDefs.HELM_WISP_ID:
			return [
				{"id": "helm_wingman", "name": "Wingman", "desc": "Drone fires alongside you", "stat": "class_wingman", "add": 1.0, "class_id": id, "max_stacks": 1},
				{"id": "helm_supply", "name": "Supply Drop", "desc": "Periodically calls special ammo", "stat": "class_supply", "add": 1.0, "class_id": id, "max_stacks": 1},
			]
		_:
			return []


static func roll_run_choices(count: int = 2, exclude: Array = [], char_id: String = "") -> Array[Dictionary]:
	var cid := char_id if char_id != "" else GameState.selected_character_id
	var pool := run_upgrade_pool(cid)
	var available: Array[Dictionary] = []
	for u in pool:
		if str(u["id"]) in exclude:
			continue
		## Class picks only for their survivor.
		var req := str(u.get("class_id", ""))
		if req != "" and req != CharacterDefs._canonicalize(cid):
			continue
		available.append(u)
	available.shuffle()
	var out: Array[Dictionary] = []
	for i in range(mini(count, available.size())):
		out.append(available[i])
	return out


## Hangar: shared camp · survivor stations · kennel · stash (Part 2 + 6).
static func hangar_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"id": "generator", "layer": "shared", "name": "Generator", "desc": "Lights the hangar · +8 HP for all per rank", "costs": SHARED_COSTS, "max_rank": 5, "min_account_level": 1, "effect": "max_hp", "per_rank": 8.0},
		{"id": "radio_tower", "layer": "shared", "name": "Radio Tower", "desc": "Reveals extract pads sooner (+2s warning / rank)", "costs": SHARED_COSTS, "max_rank": 5, "min_account_level": 1, "effect": "pad_warning", "per_rank": 2.0},
		{"id": "scrap_press", "layer": "shared", "name": "Scrap Press", "desc": "+10% scrap found per rank", "costs": SHARED_COSTS, "max_rank": 5, "min_account_level": 1, "effect": "scrap_find", "per_rank": 0.10},
		{"id": "ammo_bench", "layer": "shared", "name": "Ammo Bench", "desc": "Rank 1: special-ammo pickups appear. Higher: longer / better odds", "costs": SHARED_COSTS, "max_rank": 5, "min_account_level": 1, "effect": "ammo_bench", "per_rank": 1.0},
		{"id": "stash_expand", "layer": "stash", "name": "Stash Lockbox", "desc": "+10 stash slots per rank (starts at 20)", "costs": STASH_COSTS, "max_rank": 3, "min_account_level": 1, "effect": "stash_slots", "per_rank": 10.0},
	]
	for cid in CharacterDefs.PLAYABLE_IDS:
		var c := CharacterDefs.get_character(cid)
		out.append({
			"id": "station_%s" % cid,
			"layer": "station",
			"survivor_id": cid,
			"name": "%s's Station" % str(c.get("display_name", cid)),
			"desc": "Upgrades %s's gun and signature trick" % str(c.get("display_name", cid)),
			"costs": STATION_COSTS,
			"max_rank": 5,
			"min_account_level": 1,
			"effect": "station",
			"per_rank": 1.0,
		})
	for pet in PetDefs.all_pets():
		out.append({
			"id": "kennel_%s" % str(pet["id"]),
			"layer": "kennel",
			"pet_id": str(pet["id"]),
			"name": "Kennel · %s" % str(pet["name"]),
			"desc": str(pet.get("ability_desc", "Stronger pet ability")),
			"costs": KENNEL_COSTS,
			"max_rank": 3,
			"min_account_level": 1,
			"effect": "kennel",
			"per_rank": 1.0,
		})
	return out


static func hangar_catalog_visible() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in hangar_catalog():
		if bool(entry.get("requires_loadout_ui", false)) and not LOADOUT_UI_SHIPPED:
			continue
		out.append(entry)
	return out


static func hangar_cost(entry: Dictionary, current_rank: int) -> int:
	## Prefer fixed cost tables from the Master Brief (Part 6).
	var costs: Variant = entry.get("costs", null)
	if typeof(costs) == TYPE_ARRAY:
		var arr: Array = costs
		if current_rank >= 0 and current_rank < arr.size():
			return int(arr[current_rank])
		if arr.size() > 0:
			return int(arr[arr.size() - 1])
	## Legacy formula fallback.
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
