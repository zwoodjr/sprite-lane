extends Node2D

const ExtractScatter = preload("res://scripts/world/extract_scatter.gd")
const EnemyScene := preload("res://scenes/entities/enemy.tscn")
const ExtractPadScene := preload("res://scenes/entities/extract_pad.tscn")
const PetScene := preload("res://scenes/entities/pet.tscn")

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
var _match_time: float = 0.0

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
	## In-run level-up picker (pauses on level).
	var picker := CanvasLayer.new()
	picker.set_script(load("res://scripts/ui/run_upgrade_picker.gd"))
	add_child(picker)
	picker.chosen.connect(func(u: Dictionary) -> void:
		if is_instance_valid(hud):
			hud.show_toast(str(u.get("name", "Upgrade")) + "!", UiTheme.TEAL)
	)

	_spawn_pet()
	_phase_index = 0
	_start_phase(0)
	hud.show_banner("DROP IN", "%s · %s" % [
		str(GameState.get_character().get("display_name", "")),
		str(_mode.get("display_name", "")),
	])
	_match_time = 0.0

func _spawn_pet() -> void:
	if not is_instance_valid(player):
		return
	if not bool(GameState.pet.get("active", false)):
		return
	var pet: CharacterBody2D = PetScene.instantiate()
	world.add_child(pet)
	pet.global_position = player.global_position + Vector2(-28, 20)
	if pet.has_method("setup"):
		pet.call("setup", player, GameState.pet)
	var pname := str(GameState.pet.get("name", "Pet"))
	var ability := str(GameState.pet.get("ability_name", ""))
	if ability != "":
		hud.show_toast("%s ready — %s" % [pname, ability], UiTheme.AMBER)

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
	_match_time += delta
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
		Juice.sfx("extract_open")
		Juice.haptic(40)
		if bool(phase.get("is_last", false)):
			hud.show_banner("LAST EXTRACT", "Get to a gold pad or lose your gear", UiTheme.DANGER)
		else:
			hud.show_banner("EXTRACT OPEN", "Stand on a gold pad to leave — or stay for more", Color(0.55, 1.0, 0.6))
		if GameState.selected_character_id == CharacterDefs.ROOK_ID and not _ping_done_for_window:
			_ping_done_for_window = true
			var sg := GameState.add_scrap(2)
			hud.show_toast("Second Glance: +%d scrap" % sg, UiTheme.AMBER)
		if hud.tutorial and is_instance_valid(hud.tutorial):
			hud.tutorial.call("event", "extract_open")
	elif index > 0:
		Juice.sfx("seal")
		hud.show_banner("SEALED", str(phase["label"]), UiTheme.AMBER)

func _advance_phase() -> void:
	if _current_window_was_open and not bool(_phases[_phase_index].get("is_last", false)):
		GameState.on_window_skipped()
		Juice.sfx("threat_up")
		Juice.shake(0.2)
		var tl := ModeDefs.tl_table(GameState.threat_level)
		hud.show_toast("Window skipped → THREAT %d: tougher enemies, payout ×%.2f" % [
			GameState.threat_level, float(tl["payout"])], UiTheme.RUST)
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
	_cull_far_enemies()
	var live := get_tree().get_nodes_in_group("enemies")
	## Soft cap — sheet-detail sprites are heavier; keep pressure without stutter.
	var cap := 12
	if GameState.threat_level >= 2:
		cap = 14
	if bool(_phases[_phase_index].get("is_last", false)) if _phase_index < _phases.size() else false:
		cap = 10 ## fewer but heavier T3 units on Last Extract
	if live.size() >= cap:
		return
	## Spawn just outside the visible area so enemies walk in, biased toward
	## where the player is heading (so you meet them instead of being chased).
	var ang := randf() * TAU
	var heading: Vector2 = player.velocity
	if heading.length() > 40.0 and randf() < 0.6:
		ang = heading.angle() + randf_range(-1.1, 1.1)
	var dist := randf_range(620.0, 780.0)
	var spot := player.global_position + Vector2(cos(ang), sin(ang)) * dist
	var tl := ModeDefs.tl_table(GameState.threat_level)
	var step := float(_mode.get("tl_step_size", 1.0))
	var hp_m := (1.0 + (float(tl["hp"]) - 1.0) * step) * float(_mode.get("enemy_hp", 1.0))
	var dmg_m := (1.0 + (float(tl["damage"]) - 1.0) * step) * float(_mode.get("enemy_damage", 1.0))
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.setup(spot, hp_m, dmg_m, 1.0, _roll_enemy_kind())
	world.add_child(enemy)

## Drop stragglers far behind the player so T2/T3 pressure doesn't accumulate.
func _cull_far_enemies() -> void:
	if not is_instance_valid(player):
		return
	var culled := 0
	for n in get_tree().get_nodes_in_group("enemies"):
		if culled >= 3:
			break
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if e.global_position.distance_to(player.global_position) > 1100.0:
			e.queue_free()
			culled += 1

## Tier mix: T1 early → T2 as Threat rises → T3 on Last Extract.
func _roll_enemy_kind() -> String:
	var progress := clampf(_match_time / 240.0, 0.0, 1.0)
	var tl := float(GameState.threat_level)
	var last_extract := false
	if _phase_index >= 0 and _phase_index < _phases.size():
		var ph: Dictionary = _phases[_phase_index]
		last_extract = bool(ph.get("is_last", false)) or str(ph.get("id", "")) == "last_extract"
	## Weights
	var w3 := 0.0
	var w2 := 0.05 + 0.18 * progress + 0.12 * tl
	if last_extract:
		w3 = 0.45 + 0.1 * tl
		w2 = 0.35
	elif tl >= 2.0:
		w3 = 0.04 + 0.06 * (tl - 1.0)
	var w1 := 1.0 - w2 - w3
	var r := randf()
	var tier := 1
	if r < w3:
		tier = 3
	elif r < w3 + w2:
		tier = 2
	else:
		tier = 1
	var pool: Array[String] = EnemyDefs.ids_for_tier(tier)
	if pool.is_empty():
		pool = EnemyDefs.ids_for_tier(1)
	return pool[randi() % pool.size()]

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
		GameState.add_run_xp(int(2 * loot_w))
		GameState.add_scrap(1)

func _on_extract_requested() -> void:
	if _ended or not _extract_open:
		return
	_ended = true
	GameState.on_extract_success()
	Juice.sfx("extract_win")
	Juice.haptic(60)
	hud.show_banner("EXTRACTED", "Payout %d scrap" % GameState.payout_this_run, Color(0.55, 1.0, 0.6))
	if is_instance_valid(player):
		Juice.burst(player.global_position, Color(1, 0.85, 0.4), 40, 260.0, 0.9, 1.4)
		var tw := player.create_tween()
		tw.tween_property(player, "modulate:a", 0.0, 0.8)
	await get_tree().create_timer(1.6).timeout
	GameState.go_result()

func _on_player_died() -> void:
	_finish_wipe("You went down in the dust.")

func _finish_wipe(reason: String) -> void:
	if _ended:
		return
	_ended = true
	GameState.on_wipe()
	GameState.result_summary = reason + "\n" + GameState.result_summary
	Juice.sfx("wipe")
	hud.show_banner("WIPED", reason, UiTheme.DANGER)
	await get_tree().create_timer(1.8).timeout
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
