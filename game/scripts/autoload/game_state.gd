extends Node

## Persistent run / meta state for the MVP vertical slice.
## Dual track:
##   A) In-run levels + loadout picks (reset every deploy)
##   B) Meta scrap → Hangar permanent upgrades (survive wipe)

signal run_reset
signal loadout_changed
signal run_xp_changed(run_xp: int, run_level: int)
signal run_level_up(new_level: int, choices: Array)
signal meta_changed

var selected_mode_id: String = ModeDefs.EASY_ID
var selected_character_id: String = CharacterDefs.ROOK_ID
var selected_pet_id: String = PetDefs.NOEL_ID

## Dev-only: compress phase timers for quick playtests (default off).
var fast_timers: bool = false
## Debug flag: shows dev toggles (quick-test timers) in menus. Off for players;
## flip here or launch with `-- --dev` to get them back.
var dev_tools: bool = false
const FAST_TIMER_SCALE := 0.12

## Classic insurance stub — slots from mode + meta; marks brought-in items.
var insured_slots: Array[String] = []

## --- Meta (survives wipe) ---
## Scrap is the permanent upgrade fuel. Account XP = soft prestige only.
var account_scrap: int = 0
var account_xp: int = 0
var account_level: int = 1
var meta_upgrades: Dictionary = {} ## v3 flat Hangar (retired; refunded on load)
## Hangar v4: HangarDefs id -> rank (shared / stations / kennel / stash).
var camp: Dictionary = {}
## Shared lockbox of extracted gear (Phase B items). Capacity: stash_capacity().
var stash: Array = []
## First boss kills: boss kind -> true. Trophies show over the hangar door.
var trophies: Dictionary = {}
## One-time v3 → v4 Hangar migration done (old spend refunded as scrap).
var migrated_hangar_v4: bool = false
## Shown once on the Hangar screen (e.g. the refund note). Not saved.
var hangar_notice: String = ""
var garage_tokens: int = 0
var successful_extracts: int = 0


## Player settings + onboarding flags (persisted to user://).
const SAVE_PATH := "user://wanderer_save.json"
const SAVE_VERSION := 4
var settings: Dictionary = {
	"sfx": true,
	"haptics": true,
	"screen_shake": true,
	"stick_scale": 1.0,
	"left_handed": false,
	"show_hints": true,
	"heat_shimmer": false,
}
var tutorial_done: bool = false
## One-time v1/v2 → v3 save migration (garage tokens → scrap) already applied.
var migrated_v3: bool = false
var best_payout: int = 0
var total_runs: int = 0

## Deployed loadout (copied at deploy).
var armor: Dictionary = {}
var weapon: Dictionary = {}
var pet: Dictionary = {}

## --- In-run (resets every deploy) ---
var threat_level: int = 0
var windows_skipped: int = 0
var extract_windows_seen: int = 0
## Stay-or-go loot multiplier (×1.0 +0.1 / 30 s, capped per tier). Pays on extract.
var loot_mult: float = 1.0
var scrap_found: int = 0
var kills: int = 0
var extracted: bool = false
var wiped: bool = false
## True once this run has been banked (extract / wipe / abandon). Guards double-counting.
var run_finished: bool = false
var result_summary: String = ""
var last_phase_label: String = ""
var run_seed: int = 0
var extract_pad_info: Array = []

## In-run leveling (temporary power)
var run_xp: int = 0 ## toward next run level
var run_level: int = 1
var run_mods: Dictionary = _fresh_run_mods()
var run_picks_taken: Array = [] ## upgrade ids chosen this run
## Phase 4 cards: id -> rank owned this run (see UpgradeDefs).
var run_ranks: Dictionary = {}
var run_rerolls_left: int = 2
var run_luck_charges: int = 0 ## Lucky Vial: level-ups left with better odds
var run_luck: float = 1.0
## Field Notes: kills per enemy kind this run.
var run_kind_kills: Dictionary = {}
var pending_run_choices: Array = []
var run_level_paused: bool = false

## Soft account XP earned this run (prestige, not power)
var account_xp_this_run: int = 0
var payout_this_run: int = 0

## Result-screen build-up (transient)
var result_scrap_before: int = 0
var result_scrap_banked: int = 0
var result_scrap_lost: int = 0
var result_account_xp_before: int = 0
var result_account_level_before: int = 1
var result_levels_gained: int = 0 ## account soft levels
var result_run_level_reached: int = 1
var result_lost_keys: PackedStringArray = []
var result_kept_keys: PackedStringArray = []
var result_unlocks: PackedStringArray = []

func _ready() -> void:
	if "--dev" in OS.get_cmdline_user_args():
		dev_tools = true
	load_profile()
	reset_loadout_to_defaults()

func save_profile() -> void:
	_sync_account_level()
	var data := {
		"version": SAVE_VERSION,
		"settings": settings,
		"tutorial_done": tutorial_done,
		"migrated_v3": migrated_v3,
		"account_scrap": account_scrap,
		"account_xp": account_xp,
		"account_level": account_level,
		"meta_upgrades": meta_upgrades,
		"camp": camp,
		"stash": stash,
		"trophies": trophies,
		"migrated_hangar_v4": migrated_hangar_v4,
		"garage_tokens": garage_tokens,
		"successful_extracts": successful_extracts,
		"best_payout": best_payout,
		"total_runs": total_runs,
		"selected_mode_id": selected_mode_id,
		"selected_character_id": selected_character_id,
		"selected_pet_id": selected_pet_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		migrated_hangar_v4 = true
		_sync_account_level()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	apply_save(parsed)

## Loads a parsed save dictionary (any version — missing keys get safe defaults).
func apply_save(d: Dictionary) -> void:
	var saved_settings: Variant = d.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for k in (saved_settings as Dictionary).keys():
			settings[k] = saved_settings[k]
	tutorial_done = bool(d.get("tutorial_done", false))
	account_scrap = int(d.get("account_scrap", 0))
	## Migrate v1/v2: old saves had account_xp as pseudo-power; keep XP, prefer scrap.
	account_xp = int(d.get("account_xp", 0))
	migrated_v3 = bool(d.get("migrated_v3", false))
	if not migrated_v3:
		## One-time soft migrate: leftover garage tokens → a bit of scrap. Never repeats,
		## so spending to 0 scrap can't re-mint free scrap on the next launch.
		if account_scrap <= 0 and int(d.get("version", 0)) < SAVE_VERSION and d.has("garage_tokens"):
			account_scrap = int(d.get("garage_tokens", 0)) * 10
		migrated_v3 = true
	var mu: Variant = d.get("meta_upgrades", {})
	if typeof(mu) == TYPE_DICTIONARY:
		meta_upgrades = (mu as Dictionary).duplicate()
	var cp: Variant = d.get("camp", {})
	camp = {}
	if typeof(cp) == TYPE_DICTIONARY:
		for k in (cp as Dictionary).keys():
			var id := str(k)
			if HangarDefs.layer_of(id) != "":
				camp[id] = clampi(int((cp as Dictionary)[k]), 0, HangarDefs.max_rank(id))
	var st: Variant = d.get("stash", [])
	stash = []
	if typeof(st) == TYPE_ARRAY:
		for it in (st as Array):
			if typeof(it) == TYPE_DICTIONARY:
				stash.append(it)
	migrated_hangar_v4 = bool(d.get("migrated_hangar_v4", false))
	var tr: Variant = d.get("trophies", {})
	trophies = (tr as Dictionary).duplicate() if typeof(tr) == TYPE_DICTIONARY else {}
	garage_tokens = int(d.get("garage_tokens", 0))
	successful_extracts = int(d.get("successful_extracts", 0))
	best_payout = int(d.get("best_payout", 0))
	total_runs = int(d.get("total_runs", 0))
	_sync_account_level()
	var mode_id := str(d.get("selected_mode_id", selected_mode_id))
	mode_id = ModeDefs.canonical_id(mode_id)
	if ModeDefs.is_exposed(mode_id):
		selected_mode_id = mode_id
	var char_id := str(d.get("selected_character_id", selected_character_id))
	if char_id == "rook_vex":
		char_id = CharacterDefs.ASH_ROOK_ID
	if CharacterDefs.is_playable(char_id):
		selected_character_id = char_id
	var pet_id := str(d.get("selected_pet_id", selected_pet_id))
	if PetDefs.is_equipable(pet_id):
		selected_pet_id = pet_id
	_migrate_hangar_v4()

## v3 flat %-stat Hangar → v4 camp: refund every scrap spent on the old list once.
func _migrate_hangar_v4() -> void:
	if migrated_hangar_v4:
		return
	migrated_hangar_v4 = true
	var refund := HangarDefs.legacy_refund(meta_upgrades)
	meta_upgrades.clear()
	if refund > 0:
		account_scrap += refund
		hangar_notice = "The Hangar was rebuilt. Your old upgrades were refunded: +%d scrap." % refund
	save_profile()

func _sync_account_level() -> void:
	account_level = Progression.account_level_from_xp(account_xp)

func account_bar_state() -> Dictionary:
	return Progression.account_progress(account_xp)

func run_bar_state() -> Dictionary:
	return Progression.run_progress(run_xp, run_level)

func meta_rank(id: String) -> int:
	return camp_rank(id)

## --- Hangar (camp) ranks: HangarDefs ids -> rank -------------------------
func camp_rank(id: String) -> int:
	return int(camp.get(id, 0))

func station_rank(hero_id: String = "") -> int:
	return camp_rank(HangarDefs.station_id(hero_id if hero_id != "" else selected_character_id))

func kennel_rank(pet_id: String = "") -> int:
	return camp_rank(HangarDefs.kennel_id(pet_id if pet_id != "" else selected_pet_id))

func has_trophy(boss: String) -> bool:
	return bool(trophies.get(boss, false))

func stash_capacity() -> int:
	return HangarDefs.stash_slots(camp_rank("stash"))

## Next-rank price for a Hangar id (-1 = maxed / unknown).
func camp_cost(id: String) -> int:
	return HangarDefs.cost(id, camp_rank(id))

func try_buy_camp(id: String) -> bool:
	if HangarDefs.layer_of(id) == "":
		return false
	var c := camp_cost(id)
	if c < 0 or account_scrap < c:
		return false
	account_scrap -= c
	camp[id] = camp_rank(id) + 1
	save_profile()
	meta_changed.emit()
	return true

## Old name kept for scripts / tests that still call it.
func try_buy_hangar(entry_id: String) -> bool:
	return try_buy_camp(entry_id)

## Generator: +HP for all.
func starting_hp_bonus() -> float:
	return float(HangarDefs.shared_val("generator", "hp", camp_rank("generator"), 0))

## Scrap Press: more scrap per run.
func scrap_find_mult() -> float:
	return 1.0 + float(HangarDefs.shared_val("scrap_press", "scrap", camp_rank("scrap_press"), 0.0))

## Radio Tower: seconds earlier the next pads are revealed.
func pad_reveal_bonus() -> float:
	return float(HangarDefs.shared_val("radio_tower", "reveal", camp_rank("radio_tower"), 0.0))

func pad_ping_lead() -> float:
	return ModeDefs.PING_LEAD + pad_reveal_bonus()

## Ammo Bench: rank 1 lets special-ammo pickups drop for everyone.
func ammo_pickups_enabled() -> bool:
	return camp_rank("ammo_bench") >= 1

func ammo_pickup_types() -> Array:
	return HangarDefs.shared_val("ammo_bench", "types", camp_rank("ammo_bench"), [])

func ammo_duration_bonus() -> float:
	return float(HangarDefs.shared_val("ammo_bench", "duration", camp_rank("ammo_bench"), 0.0))

func ammo_odds_mult() -> float:
	return float(HangarDefs.shared_val("ammo_bench", "odds", camp_rank("ammo_bench"), 0.0))

## Survivor station: weapon damage for the selected hero.
func starting_damage_bonus() -> float:
	return HangarDefs.station_weapon_damage(station_rank())

## Ability dict for the selected hero with its station applied.
func hero_ability() -> Dictionary:
	return HangarDefs.apply_station_ability(selected_character_id, get_character().get("ability", {}), station_rank())

## Retired v3 flat stats — neutral now (gear in Phase B feeds some of these).
func insurance_bonus_slots() -> int:
	return 0

func dash_cooldown_mult() -> float:
	return 1.0

func extract_payout_mult() -> float:
	return 1.0

func endurance_iframe_mult() -> float:
	return 1.0

func crit_chance() -> float:
	return 0.0

func crit_damage_bonus() -> float:
	return 0.0

func aoe_damage_mult() -> float:
	return 1.0

func dodge_chance() -> float:
	return 0.0

func block_chance() -> float:
	return 0.0

func move_speed_bonus() -> float:
	return 0.0

func pickup_radius_bonus() -> float:
	return 0.0

func pet_power_mult() -> float:
	return 1.0

func loot_quality_bonus() -> float:
	return 0.0

func extract_grace_sec() -> float:
	return 0.0

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_profile()

func reset_profile() -> void:
	tutorial_done = false
	migrated_v3 = true
	account_scrap = 0
	account_xp = 0
	account_level = 1
	meta_upgrades.clear()
	camp.clear()
	stash.clear()
	trophies.clear()
	migrated_hangar_v4 = true
	garage_tokens = 0
	successful_extracts = 0
	best_payout = 0
	total_runs = 0
	save_profile()
	meta_changed.emit()

func get_mode() -> Dictionary:
	return ModeDefs.get_mode(selected_mode_id)

func get_character() -> Dictionary:
	return CharacterDefs.get_character(selected_character_id)

func reset_loadout_to_defaults() -> void:
	armor = LoadoutStubs.default_armor()
	## Kit follows the selected hero — never the old shared Scrap SMG.
	weapon = HangarDefs.apply_station_weapon(selected_character_id,
		LoadoutStubs.weapon_for_character(selected_character_id), station_rank())
	pet = HangarDefs.apply_kennel(LoadoutStubs.default_pet(selected_pet_id), kennel_rank())
	insured_slots.clear()
	var slots: int = int(get_mode().get("insurance_slots", 2)) + insurance_bonus_slots()
	slots = mini(slots, 3)
	if slots >= 1:
		insured_slots.append("weapon")
	if slots >= 2:
		insured_slots.append("pet")
	if slots >= 3:
		insured_slots.append("armor")
	loadout_changed.emit()

func begin_run() -> void:
	threat_level = 0
	windows_skipped = 0
	extract_windows_seen = 0
	loot_mult = 1.0
	scrap_found = 0
	kills = 0
	extracted = false
	wiped = false
	run_finished = false
	result_summary = ""
	last_phase_label = ""
	account_xp_this_run = 0
	payout_this_run = 0
	run_seed = int(Time.get_unix_time_from_system()) ^ (randi() << 1) ^ Time.get_ticks_msec()
	if run_seed == 0:
		run_seed = 1
	extract_pad_info = []
	## Reset in-run track completely.
	run_xp = 0
	run_level = 1
	_reset_run_cards()
	pending_run_choices.clear()
	run_level_paused = false
	_clear_result_meta()
	reset_loadout_to_defaults()
	run_reset.emit()
	run_xp_changed.emit(run_xp, run_level)

func _clear_result_meta() -> void:
	result_scrap_before = 0
	result_scrap_banked = 0
	result_scrap_lost = 0
	result_account_xp_before = 0
	result_account_level_before = 1
	result_levels_gained = 0
	result_run_level_reached = 1
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	result_unlocks = PackedStringArray()

func on_window_skipped() -> void:
	windows_skipped += 1

## Called every frame by the match: multiplier from run time, Threat follows it.
func set_loot_mult(mult: float) -> void:
	loot_mult = mult
	threat_level = ModeDefs.threat_for_mult(mult)

## What the bag is worth right now (before the multiplier).
func bag_value() -> int:
	return scrap_found * 2 + kills * 5

## Add bag scrap with meta magnet applied.
func add_scrap(amount: int) -> int:
	var gained := maxi(0, int(round(float(amount) * scrap_find_mult())))
	scrap_found += gained
	return gained

## In-run XP → levels → upgrade picker. Does NOT become permanent power.
func add_run_xp(amount: int) -> void:
	if amount <= 0 or extracted or wiped:
		return
	if run_level >= Progression.RUN_LEVEL_CAP:
		run_xp_changed.emit(run_xp, run_level)
		return
	run_xp += amount
	var leveled := false
	while run_level < Progression.RUN_LEVEL_CAP and run_xp >= Progression.run_xp_to_next(run_level):
		run_xp -= Progression.run_xp_to_next(run_level)
		run_level += 1
		leveled = true
		var choices := Progression.roll_run_choices(UpgradeDefs.CHOICES_PER_LEVEL, [], consume_luck())
		pending_run_choices = choices
		run_level_paused = true
		run_level_up.emit(run_level, choices)
		## One pick UI per level; break so player chooses before next threshold.
		break
	run_xp_changed.emit(run_xp, run_level)
	if not leveled and run_level >= Progression.RUN_LEVEL_CAP:
		run_xp = 0

func apply_run_upgrade(upgrade: Dictionary) -> void:
	var stat := str(upgrade.get("stat", ""))
	var add := float(upgrade.get("add", 0.0))
	if run_mods.has(stat):
		run_mods[stat] = float(run_mods[stat]) + add
	var uid := str(upgrade.get("id", ""))
	if uid != "":
		run_ranks[uid] = mini(run_rank(uid) + 1, int(upgrade.get("max_rank", 3)))
		if uid not in run_picks_taken:
			run_picks_taken.append(uid)
		if uid == "lucky_vial":
			run_luck_charges = int(UpgradeDefs.val(uid, "charges", run_rank(uid), 0))
			run_luck = float(UpgradeDefs.val(uid, "luck", run_rank(uid), 1.0))
	pending_run_choices.clear()
	run_level_paused = false
	loadout_changed.emit()

func run_rank(id: String) -> int:
	return int(run_ranks.get(id, 0))

## Shorthand: an upgrade's value at the rank owned this run.
func up(id: String, key: String, default: Variant = 0.0) -> Variant:
	return UpgradeDefs.val(id, key, run_rank(id), default)

## Lucky Vial: returns the luck multiplier for this level-up (uses a charge).
func consume_luck() -> float:
	if run_luck_charges <= 0:
		return 1.0
	run_luck_charges -= 1
	return run_luck

func use_reroll() -> bool:
	if run_rerolls_left <= 0:
		return false
	run_rerolls_left -= 1
	return true

func note_kill(kind: String) -> void:
	run_kind_kills[kind] = int(run_kind_kills.get(kind, 0)) + 1

## Scavenger's Eye multiplier on kill scrap.
func run_scrap_mult() -> float:
	return 1.0 + float(up("scavengers_eye", "scrap", 0.0))

static func _fresh_run_mods() -> Dictionary:
	return {"damage": 0.0, "firerate": 0.0, "max_hp": 0.0, "move": 0.0, "mag": 0.0, "ability_cd": 0.0}

func _reset_run_cards() -> void:
	run_mods = _fresh_run_mods()
	run_picks_taken.clear()
	run_ranks.clear()
	run_rerolls_left = UpgradeDefs.REROLLS_PER_RUN
	run_luck_charges = 0
	run_luck = 1.0
	run_kind_kills.clear()

func on_extract_success() -> void:
	if run_finished:
		return
	run_finished = true
	extracted = true
	wiped = false
	_clear_result_meta()
	var mode := get_mode()
	## Extract pays the full bag (plus a 100 scrap stipend) × loot multiplier.
	var base := 100 + bag_value()
	payout_this_run = int(
		base * loot_mult * float(mode["payout_mult"]) * extract_payout_mult()
	)
	result_scrap_before = account_scrap
	account_scrap += payout_this_run
	result_scrap_banked = payout_this_run
	result_scrap_lost = 0
	garage_tokens += maxi(1, payout_this_run / 50)
	## Soft prestige XP (not spend power).
	result_account_xp_before = account_xp
	result_account_level_before = account_level
	account_xp_this_run = Progression.award_extract_account_xp(
		kills, loot_mult, float(mode["payout_mult"])
	)
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	successful_extracts += 1
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d (Hangar gates)" % account_level)
	result_summary = "Extracted. +%d scrap banked (×%.1f loot) · run Lv %d · Threat %d" % [
		payout_this_run, loot_mult, run_level, threat_level,
	]
	best_payout = maxi(best_payout, payout_this_run)
	total_runs += 1
	## In-run power dies here — only banked scrap/meta remain.
	_reset_run_power_after_end()
	save_profile()

func on_wipe() -> void:
	if run_finished:
		return
	run_finished = true
	extracted = false
	wiped = true
	_clear_result_meta()
	var mode := get_mode()
	result_scrap_before = account_scrap
	## Death keeps a slice of the carried bag (Haze 10%, Drift 15%), no multiplier.
	var keep := int(round(float(bag_value()) * float(mode.get("death_keep", 0.1))))
	account_scrap += keep
	result_scrap_banked = keep
	result_scrap_lost = maxi(0, bag_value() - keep)
	result_account_xp_before = account_xp
	result_account_level_before = account_level
	account_xp_this_run = Progression.award_wipe_account_xp(kills, float(mode["payout_mult"]))
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	payout_this_run = keep
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	for key in ["weapon", "armor", "pet"]:
		if key in insured_slots:
			result_kept_keys.append(key)
		else:
			result_lost_keys.append(key)
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d" % account_level)
	result_summary = "Wiped. Kept %d%% of the bag (+%d scrap). Lost %d. Lost gear: %s" % [
		int(round(float(mode.get("death_keep", 0.1)) * 100.0)),
		keep,
		result_scrap_lost,
		", ".join(result_lost_keys) if result_lost_keys.size() else "(nothing)",
	]
	total_runs += 1
	_reset_run_power_after_end()
	save_profile()

func _reset_run_power_after_end() -> void:
	## Permanent power never comes from run levels — clear after banking rewards.
	run_xp = 0
	_reset_run_cards()
	pending_run_choices.clear()
	run_level_paused = false

func timer_scale() -> float:
	return FAST_TIMER_SCALE if fast_timers else 1.0

func go_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func go_mode_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")

func go_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func go_how_to_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/how_to_play.tscn")

func go_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func go_hangar() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/hangar.tscn")

func go_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	save_profile()
	begin_run()
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")

func go_result() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	TouchInput.clear_sticks()
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")
