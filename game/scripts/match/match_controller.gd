extends Node2D

const ModeDefs = preload("res://scripts/data/mode_defs.gd")
const CharacterDefs = preload("res://scripts/data/character_defs.gd")
const ExtractScatter = preload("res://scripts/world/extract_scatter.gd")
const EnemyScene := preload("res://scenes/entities/enemy.tscn")
const ExtractPadScene := preload("res://scenes/entities/extract_pad.tscn")

@onready var player: CharacterBody2D = $World/Player
@onready var world: Node2D = $World
@onready var pads_root: Node2D = $World/ExtractPads
@onready var wasteland: Node2D = $World/Wasteland
@onready var hud: CanvasLayer = $HUD

var _phases: Array[Dictionary] = []
var _phase_index: int = 0
var _phase_time_left: float = 0.0
var _extract_open: bool = false
var _current_window_was_open: bool = false
var _spawn_accum: float = 0.0
var _stay_accum: float = 0.0
var _ended: bool = false
var _mode: Dictionary = {}
var _ping_done_for_window: bool = false
var _pads: Array = []


func _ready() -> void:
	_mode = GameState.get_mode()
	if GameState.run_seed == 0:
		GameState.run_seed = int(Time.get_unix_time_from_system()) ^ randi()
	_phases = []
	for p in _mode["phases"]:
		var phase: Dictionary = p.duplicate(true)
		phase["duration"] = float(phase["duration"]) * GameState.timer_scale()
		_phases.append(phase)

	## Endless wasteland chunks
	wasteland.setup(GameState.run_seed, player)
	_roll_extracts()

	player.died.connect(_on_player_died)
	player.health_changed.connect(hud.on_health_changed)
	if player.has_signal("buffs_changed"):
		player.buffs_changed.connect(hud.on_buffs_changed)
	TouchInput.extract_pressed.connect(_on_touch_extract)
	hud.setup(self)
	hud.setup_nav(player, _pads, wasteland.get_landmarks())

	_phase_index = 0
	_start_phase(0)
	if GameState.selected_character_id == CharacterDefs.ROOK_ID:
		hud.show_toast("Rook: Pocket Rattle active — Stay Bonus boosts scrap weight.")
	hud.show_toast("Wasteland stretches forever — follow extract arrows.")


func _roll_extracts() -> void:
	for c in pads_root.get_children():
		c.queue_free()
	_pads.clear()
	var rolled := ExtractScatter.roll_positions(GameState.run_seed, wasteland.get_landmarks(), 3)
	for i in range(rolled.size()):
		var info: Dictionary = rolled[i]
		var pad: Area2D = ExtractPadScene.instantiate()
		pads_root.add_child(pad)
		pad.global_position = info["position"]
		pad.pad_name = str(info["name"])
		if pad.has_signal("extract_requested"):
			pad.extract_requested.connect(_on_extract_requested)
		_pads.append(pad)
	GameState.extract_pad_info = rolled


func _on_touch_extract() -> void:
	if _ended or not _extract_open:
		return
	for pad in _pads:
		if is_instance_valid(pad) and pad.has_method("try_touch_extract") and pad.try_touch_extract():
			return


func _process(delta: float) -> void:
	if _ended:
		return
	_phase_time_left -= delta
	_update_spawns(delta)
	_update_stay_bonus(delta)
	hud.update_match(
		_phases[_phase_index],
		_phase_time_left,
		GameState.threat_level,
		GameState.stay_bonus,
		player
	)
	hud.set_extract_open(_extract_open)
	if _phase_time_left <= 0.0:
		_advance_phase()


func _start_phase(index: int) -> void:
	_phase_index = index
	var phase: Dictionary = _phases[index]
	_phase_time_left = float(phase["duration"])
	_extract_open = bool(phase["extract_open"])
	_current_window_was_open = _extract_open
	_ping_done_for_window = false
	GameState.last_phase_label = str(phase["label"])
	_set_pads_open(_extract_open)
	hud.set_extract_open(_extract_open)
	if _extract_open:
		GameState.extract_windows_seen += 1
		_spawn_ambush()
		if GameState.selected_character_id == CharacterDefs.ROOK_ID and not _ping_done_for_window:
			_ping_done_for_window = true
			hud.show_toast("Second Glance: nearby loot crates pinged (stub).")
			GameState.scrap_found += 2
	hud.show_toast(str(phase["label"]))


func _advance_phase() -> void:
	if _current_window_was_open and not bool(_phases[_phase_index].get("is_last", false)):
		GameState.on_window_skipped()
		hud.show_toast("Window skipped — Threat Level %d" % GameState.threat_level)
	if bool(_phases[_phase_index].get("is_last", false)):
		_finish_wipe("Last Extract closed. You didn't make it out.")
		return
	if _phase_index + 1 >= _phases.size():
		_finish_wipe("Match timer ended.")
		return
	_start_phase(_phase_index + 1)


func _set_pads_open(is_open: bool) -> void:
	for pad in _pads:
		if is_instance_valid(pad) and pad.has_method("set_open"):
			pad.set_open(is_open)


func _update_spawns(delta: float) -> void:
	var tl := ModeDefs.tl_table(GameState.threat_level)
	var step := float(_mode.get("tl_step_size", 1.0))
	var spawn_mult := 1.0 + (float(tl["spawn"]) - 1.0) * step
	spawn_mult *= float(_mode.get("spawn_density", 1.0))
	var interval := 3.8 / maxf(0.4, spawn_mult)
	if _extract_open:
		interval *= 0.7
	_spawn_accum += delta
	if _spawn_accum >= interval:
		_spawn_accum = 0.0
		_spawn_enemy()


func _spawn_enemy() -> void:
	if not is_instance_valid(player):
		return
	var live := get_tree().get_nodes_in_group("enemies")
	if live.size() >= 16:
		return
	var ang := randf() * TAU
	var dist := randf_range(320.0, 520.0)
	var spot := player.global_position + Vector2(cos(ang), sin(ang)) * dist
	var tl := ModeDefs.tl_table(GameState.threat_level)
	var step := float(_mode.get("tl_step_size", 1.0))
	var hp_m := (1.0 + (float(tl["hp"]) - 1.0) * step) * float(_mode.get("enemy_hp", 1.0))
	var dmg_m := (1.0 + (float(tl["damage"]) - 1.0) * step) * float(_mode.get("enemy_damage", 1.0))
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	world.add_child(enemy)
	enemy.setup(spot, hp_m, dmg_m)


func _spawn_ambush() -> void:
	for i in range(3 + GameState.threat_level):
		_spawn_enemy()


func _update_stay_bonus(delta: float) -> void:
	if not _extract_open:
		return
	_stay_accum += delta
	if _stay_accum >= 5.0:
		_stay_accum = 0.0
		var loot_w := 1.0 + float(GameState.get_character().get("loot_weight_bonus", 0.0))
		GameState.stay_bonus += 0.05 * loot_w
		GameState.xp_this_run += int(2 * loot_w)
		GameState.scrap_found += 1


func _on_extract_requested() -> void:
	if _ended or not _extract_open:
		return
	_ended = true
	GameState.on_extract_success()
	hud.show_toast("Extracting…")
	await get_tree().create_timer(0.6).timeout
	GameState.go_result()


func _on_player_died() -> void:
	_finish_wipe("You went down in the dust.")


func _finish_wipe(reason: String) -> void:
	if _ended:
		return
	_ended = true
	GameState.on_wipe()
	GameState.result_summary = reason + "\n" + GameState.result_summary
	await get_tree().create_timer(0.8).timeout
	GameState.go_result()


func get_phase_progress() -> float:
	var dur := float(_phases[_phase_index]["duration"])
	if dur <= 0.0:
		return 1.0
	return 1.0 - (_phase_time_left / dur)


func is_extract_open() -> bool:
	return _extract_open


func get_pads() -> Array:
	return _pads
