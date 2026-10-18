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
const FAST_TIMER_SCALE := 0.12

## Classic insurance stub — slots from mode + meta; marks brought-in items.
var insured_slots: Array[String] = []

## --- Meta (survives wipe) ---
## Scrap is the permanent upgrade fuel. Account XP = soft prestige only.
var account_scrap: int = 0
var account_xp: int = 0
var account_level: int = 1
var meta_upgrades: Dictionary = {} ## id -> rank
var garage_tokens: int = 0
var mount_unlock_tier: int = 0 ## 0 = skateboard usable
var successful_extracts: int = 0

## Tank never unlocks for players.
var tank_dev_flag: bool = false

## Player settings + onboarding flags (persisted to user://).
const SAVE_PATH := "user://wanderer_save.json"
const SAVE_VERSION := 4
## One-time garage_tokens → scrap migration (never re-run when scrap hits 0).
var garage_tokens_migrated: bool = false
var settings: Dictionary = {
	"sfx": true,
	"haptics": true,
	"screen_shake": true,
	## Default: survivor single move-stick. twin_stick restores classic dual sticks.
	"twin_stick": false,
	"auto_fire": true,
	"auto_aim": true,
	"aim_autofire": true,
	"aim_assist": 0.6,
	"stick_scale": 1.0,
	"left_handed": false,
	"show_hints": true,
}
var tutorial_done: bool = false
var best_payout: int = 0
var total_runs: int = 0

## Deployed loadout (copied at deploy).
var armor: Dictionary = {}
var weapon: Dictionary = {}
var pet: Dictionary = {}
var mount: Dictionary = {}

## --- In-run (resets every deploy) ---
var threat_level: int = 0
var windows_skipped: int = 0
var extract_windows_seen: int = 0
var stay_bonus: float = 1.0
var scrap_found: int = 0
var kills: int = 0
var extracted: bool = false
var wiped: bool = false
var result_summary: String = ""
var last_phase_label: String = ""
var run_seed: int = 0
var extract_pad_info: Array = []

## In-run leveling (temporary power)
var run_xp: int = 0 ## toward next run level
var run_level: int = 1
var run_mods: Dictionary = {
	"damage": 0.0,
	"firerate": 0.0,
	"max_hp": 0.0,
	"move": 0.0,
	"mag": 0.0,
	"ability_cd": 0.0,
}
var run_picks_taken: Array = [] ## upgrade ids chosen this run
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
	load_profile()
	reset_loadout_to_defaults()

func save_profile() -> void:
	_sync_account_level()
	var data := {
		"version": SAVE_VERSION,
		"settings": settings,
		"tutorial_done": tutorial_done,
		"account_scrap": account_scrap,
		"account_xp": account_xp,
		"account_level": account_level,
		"meta_upgrades": meta_upgrades,
		"garage_tokens": garage_tokens,
		"garage_tokens_migrated": garage_tokens_migrated,
		"successful_extracts": successful_extracts,
		"mount_unlock_tier": mount_unlock_tier,
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
		_sync_account_level()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	var saved_settings: Variant = d.get("settings", {})
	if typeof(saved_settings) == TYPE_DICTIONARY:
		for k in (saved_settings as Dictionary).keys():
			settings[k] = saved_settings[k]
	tutorial_done = bool(d.get("tutorial_done", false))
	account_scrap = int(d.get("account_scrap", 0))
	## Migrate v1/v2: old saves had account_xp as pseudo-power; keep XP, prefer scrap.
	account_xp = int(d.get("account_xp", 0))
	garage_tokens_migrated = bool(d.get("garage_tokens_migrated", false))
	garage_tokens = int(d.get("garage_tokens", 0))
	## Soft migrate once: leftover garage tokens → scrap so hangar isn't empty.
	## Gate so spending scrap to 0 never re-grants free scrap on every load.
	if not garage_tokens_migrated and d.has("garage_tokens"):
		if account_scrap <= 0 and garage_tokens > 0:
			account_scrap = garage_tokens * 10
		garage_tokens_migrated = true
	elif not garage_tokens_migrated:
		## New / already-scrap saves: mark done so a future zero-scrap load is safe.
		garage_tokens_migrated = true
	var mu: Variant = d.get("meta_upgrades", {})
	if typeof(mu) == TYPE_DICTIONARY:
		meta_upgrades = (mu as Dictionary).duplicate()
	successful_extracts = int(d.get("successful_extracts", 0))
	mount_unlock_tier = int(d.get("mount_unlock_tier", 0))
	best_payout = int(d.get("best_payout", 0))
	total_runs = int(d.get("total_runs", 0))
	_sync_account_level()
	var mode_id := str(d.get("selected_mode_id", selected_mode_id))
	if mode_id in [ModeDefs.EASY_ID, ModeDefs.MEDIUM_ID]:
		selected_mode_id = mode_id
	var char_id := str(d.get("selected_character_id", selected_character_id))
	if char_id == "rook_vex":
		char_id = CharacterDefs.ASH_ROOK_ID
	if CharacterDefs.is_playable(char_id):
		selected_character_id = char_id
	var pet_id := str(d.get("selected_pet_id", selected_pet_id))
	if PetDefs.is_equipable(pet_id):
		selected_pet_id = pet_id

func _sync_account_level() -> void:
	account_level = Progression.account_level_from_xp(account_xp)

func account_bar_state() -> Dictionary:
	return Progression.account_progress(account_xp)

func run_bar_state() -> Dictionary:
	return Progression.run_progress(run_xp, run_level)

func meta_rank(id: String) -> int:
	return int(meta_upgrades.get(id, 0))

func scrap_find_mult() -> float:
	return 1.0 + Progression.meta_bonus(meta_upgrades, "scrap_find")

func starting_hp_bonus() -> float:
	return Progression.meta_bonus(meta_upgrades, "max_hp")

func starting_damage_bonus() -> float:
	return Progression.meta_bonus(meta_upgrades, "damage")

func insurance_bonus_slots() -> int:
	return int(Progression.meta_bonus(meta_upgrades, "insurance"))

func dash_cooldown_mult() -> float:
	## Hangar Loose Boots — floor so dash never becomes free spam.
	return maxf(0.55, 1.0 - Progression.meta_bonus(meta_upgrades, "dash_cd"))

func extract_payout_mult() -> float:
	return 1.0 + Progression.meta_bonus(meta_upgrades, "extract_payout")

## Dust Lungs — stamina stub: stretches dash i-frames until a real stamina bar exists.
func endurance_iframe_mult() -> float:
	return 1.0 + Progression.meta_bonus(meta_upgrades, "endurance")

func crit_chance() -> float:
	## Soft cap so meta never guarantees crits.
	return clampf(Progression.meta_bonus(meta_upgrades, "crit_chance"), 0.0, 0.35)

func crit_damage_bonus() -> float:
	## Added on top of base crit multiplier (1.5).
	return Progression.meta_bonus(meta_upgrades, "crit_damage")

func aoe_damage_mult() -> float:
	return 1.0 + Progression.meta_bonus(meta_upgrades, "aoe_damage")

func dodge_chance() -> float:
	return clampf(Progression.meta_bonus(meta_upgrades, "dodge"), 0.0, 0.20)

func block_chance() -> float:
	## Half strength without Bastion / block_affinity characters.
	var raw := Progression.meta_bonus(meta_upgrades, "block")
	var affinity := bool(get_character().get("block_affinity", false))
	var scale := 1.0 if affinity else 0.5
	return clampf(raw * scale, 0.0, 0.25)

func move_speed_bonus() -> float:
	## Modest — TL and enemies still catch up.
	return clampf(Progression.meta_bonus(meta_upgrades, "move_speed"), 0.0, 0.15)

func pickup_radius_bonus() -> float:
	return Progression.meta_bonus(meta_upgrades, "pickup_radius")

func pet_power_mult() -> float:
	return 1.0 + Progression.meta_bonus(meta_upgrades, "pet_power")

func loot_quality_bonus() -> float:
	## Added to crate power-up chance; still capped in breakable.
	return Progression.meta_bonus(meta_upgrades, "loot_quality")

func extract_grace_sec() -> float:
	return Progression.meta_bonus(meta_upgrades, "extract_grace")

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_profile()

func reset_profile() -> void:
	tutorial_done = false
	account_scrap = 0
	account_xp = 0
	account_level = 1
	meta_upgrades.clear()
	garage_tokens = 0
	successful_extracts = 0
	mount_unlock_tier = 0
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
	weapon = LoadoutStubs.weapon_for_character(selected_character_id)
	pet = LoadoutStubs.default_pet(selected_pet_id)
	mount = LoadoutStubs.default_mount(mount_unlock_tier)
	insured_slots.clear()
	var slots: int = int(get_mode().get("insurance_slots", 2)) + insurance_bonus_slots()
	slots = mini(slots, 4)
	if slots >= 1:
		insured_slots.append("weapon")
	if slots >= 2:
		insured_slots.append("pet")
	if slots >= 3:
		insured_slots.append("armor")
	if slots >= 4:
		insured_slots.append("mount")
	loadout_changed.emit()

func begin_run() -> void:
	threat_level = 0
	windows_skipped = 0
	extract_windows_seen = 0
	stay_bonus = 1.0
	scrap_found = 0
	kills = 0
	extracted = false
	wiped = false
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
	run_mods = {"damage": 0.0, "firerate": 0.0, "max_hp": 0.0, "move": 0.0, "mag": 0.0, "ability_cd": 0.0}
	run_picks_taken.clear()
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
	threat_level += 1

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
		var choices := Progression.roll_run_choices(2, run_picks_taken)
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
	if uid != "" and uid not in run_picks_taken:
		run_picks_taken.append(uid)
	pending_run_choices.clear()
	run_level_paused = false
	loadout_changed.emit()

func try_buy_hangar(entry_id: String) -> bool:
	var entry: Dictionary = {}
	for e in Progression.hangar_catalog():
		if str(e["id"]) == entry_id:
			entry = e
			break
	if entry.is_empty():
		return false
	## Insurance slots stay data-ready but unpurchasable until Loadout UI ships.
	if bool(entry.get("requires_loadout_ui", false)) and not Progression.LOADOUT_UI_SHIPPED:
		return false
	var rank := meta_rank(entry_id)
	if rank >= int(entry.get("max_rank", 1)):
		return false
	if account_level < int(entry.get("min_account_level", 1)):
		return false
	var cost := Progression.hangar_cost(entry, rank)
	if account_scrap < cost:
		return false
	account_scrap -= cost
	meta_upgrades[entry_id] = rank + 1
	save_profile()
	meta_changed.emit()
	return true

func on_extract_success() -> void:
	extracted = true
	wiped = false
	_clear_result_meta()
	var mode := get_mode()
	var tl := ModeDefs.tl_table(threat_level)
	var base := 100 + scrap_found * 2 + kills * 5
	payout_this_run = int(
		base * stay_bonus * float(tl["payout"]) * float(mode["payout_mult"]) * extract_payout_mult()
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
		kills, float(tl["payout"]), float(mode["payout_mult"])
	)
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	successful_extracts += 1
	if successful_extracts >= 3 and mount_unlock_tier < 1:
		mount_unlock_tier = 1
		result_unlocks.append("Scooter unlocked in the hangar")
	elif mount_unlock_tier < 1:
		var left := 3 - successful_extracts
		if left > 0 and left <= 2:
			result_unlocks.append("Scooter in %d more extract%s" % [left, "s" if left != 1 else ""])
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d (Hangar gates)" % account_level)
	result_summary = "Extracted. +%d scrap banked · run Lv %d · TL %d" % [
		payout_this_run, run_level, threat_level,
	]
	best_payout = maxi(best_payout, payout_this_run)
	total_runs += 1
	## In-run power dies here — only banked scrap/meta remain.
	_reset_run_power_after_end()
	save_profile()

func on_wipe() -> void:
	extracted = false
	wiped = true
	_clear_result_meta()
	var mode := get_mode()
	result_scrap_before = account_scrap
	result_scrap_banked = 0
	result_scrap_lost = scrap_found
	result_account_xp_before = account_xp
	result_account_level_before = account_level
	account_xp_this_run = Progression.award_wipe_account_xp(kills, float(mode["payout_mult"]))
	account_xp += account_xp_this_run
	var new_lv := Progression.account_level_from_xp(account_xp)
	result_levels_gained = maxi(0, new_lv - result_account_level_before)
	_sync_account_level()
	result_run_level_reached = run_level
	payout_this_run = 0
	result_lost_keys = PackedStringArray()
	result_kept_keys = PackedStringArray()
	for key in ["weapon", "armor", "pet", "mount"]:
		if key in insured_slots:
			result_kept_keys.append(key)
		else:
			result_lost_keys.append(key)
	if result_levels_gained > 0:
		result_unlocks.append("Account prestige Lv %d" % account_level)
	result_summary = "Wiped. Kept scrap %d + Hangar. Lost bag scrap %d. Lost gear: %s" % [
		account_scrap,
		result_scrap_lost,
		", ".join(result_lost_keys) if result_lost_keys.size() else "(nothing)",
	]
	total_runs += 1
	_reset_run_power_after_end()
	save_profile()

func _reset_run_power_after_end() -> void:
	## Permanent power never comes from run levels — clear after banking rewards.
	run_xp = 0
	run_mods = {"damage": 0.0, "firerate": 0.0, "max_hp": 0.0, "move": 0.0, "mag": 0.0, "ability_cd": 0.0}
	run_picks_taken.clear()
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
	## Always unpause — extract/wipe delay can leave the tree paused (result freezes).
	get_tree().paused = false
	Engine.time_scale = 1.0
	TouchInput.clear_sticks()
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")


func run_already_ended() -> bool:
	return extracted or wiped
