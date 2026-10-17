extends Node

## Persistent run / meta state for the MVP vertical slice.

signal run_reset
signal loadout_changed

const CharacterDefs = preload("res://scripts/data/character_defs.gd")
const ModeDefs = preload("res://scripts/data/mode_defs.gd")
const LoadoutStubs = preload("res://scripts/data/loadout_stubs.gd")

var selected_mode_id: String = ModeDefs.EASY_ID
var selected_character_id: String = CharacterDefs.ROOK_ID

## Dev-only: compress phase timers for quick playtests (default off).
var fast_timers: bool = false
const FAST_TIMER_SCALE := 0.12

## Classic insurance stub — slots from mode; marks brought-in items.
var insured_slots: Array[String] = []

## Account-ish stubs (survive wipe).
var account_xp: int = 0
var garage_tokens: int = 0
var mount_unlock_tier: int = 0 ## 0 = skateboard usable
var successful_extracts: int = 0

## Tank never unlocks for players.
var tank_dev_flag: bool = false

## Player settings + onboarding flags (persisted to user://).
const SAVE_PATH := "user://wanderer_save.json"
const SAVE_VERSION := 1
var settings: Dictionary = {
	"sfx": true,
	"haptics": true,
	"screen_shake": true,
	"auto_aim": true,       ## FIRE button snaps to nearest enemy
	"aim_autofire": true,   ## pushing the aim stick fires
	"aim_assist": 0.6,      ## 0..1 bullet magnetism toward enemies near your aim line
	"stick_scale": 1.0,
	"left_handed": false,   ## swaps move/aim halves
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

## In-run / result
var threat_level: int = 0
var windows_skipped: int = 0
var extract_windows_seen: int = 0
var stay_bonus: float = 1.0
var scrap_found: int = 0
var xp_this_run: int = 0
var payout_this_run: int = 0
var kills: int = 0
var extracted: bool = false
var wiped: bool = false
var result_summary: String = ""
var last_phase_label: String = ""
var run_seed: int = 0
var extract_pad_info: Array = []


func _ready() -> void:
	load_profile()
	reset_loadout_to_defaults()


func save_profile() -> void:
	var data := {
		"version": SAVE_VERSION,
		"settings": settings,
		"tutorial_done": tutorial_done,
		"account_xp": account_xp,
		"garage_tokens": garage_tokens,
		"successful_extracts": successful_extracts,
		"mount_unlock_tier": mount_unlock_tier,
		"best_payout": best_payout,
		"total_runs": total_runs,
		"selected_mode_id": selected_mode_id,
		"selected_character_id": selected_character_id,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
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
	account_xp = int(d.get("account_xp", 0))
	garage_tokens = int(d.get("garage_tokens", 0))
	successful_extracts = int(d.get("successful_extracts", 0))
	mount_unlock_tier = int(d.get("mount_unlock_tier", 0))
	best_payout = int(d.get("best_payout", 0))
	total_runs = int(d.get("total_runs", 0))
	var mode_id := str(d.get("selected_mode_id", selected_mode_id))
	if mode_id in [ModeDefs.EASY_ID, ModeDefs.MEDIUM_ID]:
		selected_mode_id = mode_id
	var char_id := str(d.get("selected_character_id", selected_character_id))
	if CharacterDefs.is_playable(char_id):
		selected_character_id = char_id


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_profile()


func reset_profile() -> void:
	tutorial_done = false
	account_xp = 0
	garage_tokens = 0
	successful_extracts = 0
	mount_unlock_tier = 0
	best_payout = 0
	total_runs = 0
	save_profile()


func get_mode() -> Dictionary:
	return ModeDefs.get_mode(selected_mode_id)


func get_character() -> Dictionary:
	return CharacterDefs.get_character(selected_character_id)


func reset_loadout_to_defaults() -> void:
	armor = LoadoutStubs.default_armor()
	weapon = LoadoutStubs.default_weapon()
	pet = LoadoutStubs.default_pet()
	mount = LoadoutStubs.default_mount(mount_unlock_tier)
	insured_slots.clear()
	var slots: int = int(get_mode().get("insurance_slots", 2))
	## Auto-insure weapon + pet stubs on Easy/Medium nets.
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
	stay_bonus = 1.0
	scrap_found = 0
	xp_this_run = 0
	payout_this_run = 0
	kills = 0
	extracted = false
	wiped = false
	result_summary = ""
	last_phase_label = ""
	run_seed = int(Time.get_unix_time_from_system()) ^ (randi() << 1) ^ Time.get_ticks_msec()
	if run_seed == 0:
		run_seed = 1
	extract_pad_info = []
	reset_loadout_to_defaults()
	run_reset.emit()


func on_window_skipped() -> void:
	windows_skipped += 1
	threat_level += 1


func on_extract_success() -> void:
	extracted = true
	wiped = false
	var mode := get_mode()
	var tl := ModeDefs.tl_table(threat_level)
	var base := 100 + scrap_found * 2 + kills * 5
	payout_this_run = int(base * stay_bonus * float(tl["payout"]) * float(mode["payout_mult"]))
	xp_this_run = int((30 + kills * 8 + scrap_found) * float(tl["payout"]) * float(mode["payout_mult"]))
	account_xp += xp_this_run
	garage_tokens += maxi(1, payout_this_run / 50)
	successful_extracts += 1
	## Mount unlock stubs (skateboard always; scooter after 3 extracts).
	if successful_extracts >= 3 and mount_unlock_tier < 1:
		mount_unlock_tier = 1
	result_summary = "Extracted. Payout %d Scrap · XP %d · TL %d" % [payout_this_run, xp_this_run, threat_level]
	best_payout = maxi(best_payout, payout_this_run)
	total_runs += 1
	save_profile()


func on_wipe() -> void:
	extracted = false
	wiped = true
	## Classic: lose brought-in + found unless insured. XP always kept (stub grant for survival time).
	xp_this_run = maxi(xp_this_run, 10 + kills * 2)
	account_xp += xp_this_run
	payout_this_run = 0
	var lost: PackedStringArray = []
	for key in ["weapon", "armor", "pet", "mount"]:
		if key in insured_slots:
			continue
		lost.append(key)
	result_summary = "Wiped. Kept XP %d. Lost: %s. Insured: %s" % [
		xp_this_run,
		", ".join(lost) if lost.size() else "(nothing)",
		", ".join(insured_slots) if insured_slots.size() else "(none)",
	]
	total_runs += 1
	save_profile()


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


func go_match() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	save_profile()
	begin_run()
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")


func go_result() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")
