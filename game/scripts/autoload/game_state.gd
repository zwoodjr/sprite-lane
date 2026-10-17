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
	reset_loadout_to_defaults()


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


func timer_scale() -> float:
	return FAST_TIMER_SCALE if fast_timers else 1.0


func go_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func go_mode_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")


func go_character_select() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func go_match() -> void:
	begin_run()
	get_tree().change_scene_to_file("res://scenes/match/match.tscn")


func go_result() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/result_screen.tscn")
