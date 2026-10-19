extends Node2D

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
var _ended: bool = false
var _mode: Dictionary = {}
var _ping_done_for_window: bool = false
var _pads: Array = []
var _match_time: float = 0.0
var _radio_ping_at: float = -1.0
var _radio_ping_done: bool = false
## Stay-or-go bookkeeping
var _elapsed_in_phases: float = 0.0 ## run clock along the phase schedule
var _window_index: int = 0          ## how many windows have opened
var _pads_pinged_for: int = -1      ## phase index whose pads are already placed
var _storm_left: float = -1.0       ## >=0 while the Dust storm rolls in
var _storm_overlay: ColorRect

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
	_clear_pads()

	player.died.connect(_on_player_died)
	## Extract channel (3 s) resets whenever the hero takes a hit.
	if player.has_signal("hurt"):
		player.hurt.connect(func(_a: float) -> void:
			for pad in _pads:
				if is_instance_valid(pad) and pad.has_method("reset_channel"):
					pad.call("reset_channel")
		)
	player.health_changed.connect(hud.on_health_changed)
	if player.has_signal("buffs_changed"):
		player.buffs_changed.connect(hud.on_buffs_changed)
	hud.setup(self)
	hud.setup_nav(player, _pads, wasteland.get_landmarks())
	hud.set_schedule(_phases)
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
	## Cheap event stub: one radio toast mid-lockout (no quest log).
	_radio_ping_done = false
	_radio_ping_at = 18.0 * GameState.timer_scale()
	if GameState.fast_timers:
		_radio_ping_at = 1.2

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

func _clear_pads() -> void:
	for c in pads_root.get_children():
		c.queue_free()
	## Keep the same Array object — HUD minimap / arrows hold a reference.
	_pads.clear()

## Two fresh pads per window, in new spots 500–900 px from the hero. Placed
## (sealed + pinged on the minimap) PING_LEAD seconds before the window opens.
func _place_window_pads(phase_index: int) -> void:
	_clear_pads()
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.run_seed * 7919 + phase_index * 104729 + 3
	var is_last := bool(_phases[phase_index].get("is_last", false))
	var used: Array[Vector2] = []
	var base_ang := rng.randf() * TAU
	for i in range(2):
		var p := Vector2.ZERO
		for attempt in range(8):
			var ang := base_ang + PI * i + rng.randf_range(-0.9, 0.9)
			p = player.global_position + Vector2(cos(ang), sin(ang)) * rng.randf_range(500.0, 900.0)
			var ok := true
			for u in used:
				if u.distance_to(p) < 450.0:
					ok = false
			if ok:
				break
		used.append(p)
		var pad: Area2D = ExtractPadScene.instantiate()
		pads_root.add_child(pad)
		pad.global_position = p
		pad.pad_name = ("Last Chance %d" if is_last else "Pad %d") % (i + 1)
		if pad.has_method("set_last_chance"):
			pad.call("set_last_chance", is_last)
		if pad.has_signal("extract_requested"):
			pad.extract_requested.connect(_on_extract_requested)
		_pads.append(pad)
	_pads_pinged_for = phase_index
	GameState.extract_pad_info = []
	for pad in _pads:
		GameState.extract_pad_info.append({"name": pad.pad_name, "position": pad.global_position})
	if hud.has_method("ping_pads"):
		hud.call("ping_pads")

## Which upcoming phase (if any) opens within the ping lead time.
func _maybe_ping_next_window() -> void:
	var nxt := _phase_index + 1
	if _extract_open or nxt >= _phases.size() or _pads_pinged_for == nxt:
		return
	if not bool(_phases[nxt].get("extract_open", false)):
		return
	if _phase_time_left > ModeDefs.PING_LEAD * GameState.timer_scale():
		return
	_place_window_pads(nxt)
	var last := bool(_phases[nxt].get("is_last", false))
	hud.show_toast(
		("LAST CHANCE opens in %ds — red pads marked" if last else "Extract opens in %ds — 2 pads marked on the map") % int(ceil(_phase_time_left / GameState.timer_scale())),
		UiTheme.DANGER if last else Color(0.55, 1.0, 0.6))
	Juice.sfx("ui_tap")

func _process(delta: float) -> void:
	if _ended:
		return
	if GameState.run_finished:
		## Banked elsewhere (e.g. Abandon from the pause menu) — stop the sim here.
		_ended = true
		return
	_match_time += delta
	_update_spawns(delta)
	if _storm_left >= 0.0:
		_tick_storm(delta)
		return
	_phase_time_left -= delta
	_elapsed_in_phases += delta
	_maybe_radio_stub()
	## Loot multiplier climbs with run time; Threat follows it.
	var before_tl := GameState.threat_level
	GameState.set_loot_mult(ModeDefs.loot_mult_at(_mode, _match_time / GameState.timer_scale()))
	if GameState.threat_level > before_tl:
		Juice.sfx("threat_up")
		hud.show_toast("Loot ×%.1f — THREAT %d: the dust gets meaner" % [GameState.loot_mult, GameState.threat_level], UiTheme.RUST)
	_maybe_ping_next_window()
	hud.update_match(
		_phases[_phase_index],
		_phase_time_left,
		GameState.threat_level,
		GameState.loot_mult,
		player
	)
	hud.set_schedule_clock(_elapsed_in_phases)
	hud.set_extract_open(_extract_open)
	if _phase_time_left <= 0.0:
		_advance_phase()

func _maybe_radio_stub() -> void:
	if _radio_ping_done or _radio_ping_at < 0.0:
		return
	if _match_time < _radio_ping_at:
		return
	_radio_ping_done = true
	var ping := EventDefs.debug_radio_ping()
	if ping.is_empty():
		return
	hud.show_toast(str(ping.get("toast", "Radio static…")), UiTheme.AMBER)

func _start_phase(index: int) -> void:
	_phase_index = index
	var phase: Dictionary = _phases[index]
	_phase_time_left = float(phase["duration"])
	_extract_open = bool(phase["extract_open"])
	## Hangar Pad Linger — modest extra open time (does not skip TL for free).
	if _extract_open:
		_phase_time_left += GameState.extract_grace_sec() * GameState.timer_scale()
	_current_window_was_open = _extract_open
	_ping_done_for_window = false
	GameState.last_phase_label = str(phase["label"])
	if _extract_open and _pads_pinged_for != index:
		_place_window_pads(index)
	if not _extract_open:
		_clear_pads()
	_set_pads_open(_extract_open)
	hud.set_extract_open(_extract_open)
	if _extract_open:
		_window_index += 1
		GameState.extract_windows_seen += 1
		_spawn_ambush()
		Juice.sfx("extract_open")
		Juice.haptic(40)
		if bool(phase.get("is_last", false)):
			hud.show_banner("LAST CHANCE", "Reach a red pad before the Dust storm hits", UiTheme.DANGER)
		else:
			hud.show_banner("EXTRACT OPEN", "Hold a pad 3s to leave at ×%.1f — or stay for more" % GameState.loot_mult, Color(0.55, 1.0, 0.6))
		if GameState.selected_character_id == CharacterDefs.ROOK_ID and not _ping_done_for_window:
			_ping_done_for_window = true
			var sg := GameState.add_scrap(2)
			hud.show_toast("Second Glance: +%d scrap" % sg, UiTheme.AMBER)
		if hud.tutorial and is_instance_valid(hud.tutorial):
			hud.tutorial.call("event", "extract_open")
	elif index > 0:
		Juice.sfx("seal")
		hud.show_banner("SEALED", "Next window in %ds" % int(ceil(_phase_time_left / GameState.timer_scale())), UiTheme.AMBER)

func _advance_phase() -> void:
	var was_last := bool(_phases[_phase_index].get("is_last", false))
	if _current_window_was_open and not was_last:
		GameState.on_window_skipped()
		Juice.shake(0.15)
		hud.show_toast("You stayed — loot ×%.1f, Threat %d" % [GameState.loot_mult, GameState.threat_level], UiTheme.AMBER)
	if was_last or _phase_index + 1 >= _phases.size():
		_start_dust_storm()
		return
	_start_phase(_phase_index + 1)

## Last chance closed: the Dust storm rolls in and ends the run as a death.
func _start_dust_storm() -> void:
	_extract_open = false
	_clear_pads()
	hud.set_extract_open(false)
	_storm_left = ModeDefs.STORM_SECONDS
	hud.show_banner("DUST STORM", "The last window closed", Color(0.85, 0.6, 0.35))
	Juice.sfx("threat_up")
	Juice.shake(0.5)
	_storm_overlay = ColorRect.new()
	_storm_overlay.color = Color(0.55, 0.38, 0.2, 0.0)
	_storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_storm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	layer.add_child(_storm_overlay)

func _tick_storm(delta: float) -> void:
	_storm_left -= delta
	if _storm_overlay:
		_storm_overlay.color.a = clampf(1.0 - _storm_left / ModeDefs.STORM_SECONDS, 0.0, 0.92)
	Juice.shake(0.05)
	if _storm_left <= 0.0:
		_storm_left = -1.0
		_finish_wipe("The Dust storm swallowed you.")

func is_storming() -> bool:
	return _storm_left >= 0.0

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
	var spot := _spawn_point_outside_view(Vector2(cos(ang), sin(ang)))
	var tl := ModeDefs.tl_table(GameState.threat_level)
	var step := float(_mode.get("tl_step_size", 1.0))
	var hp_m := (1.0 + (float(tl["hp"]) - 1.0) * step) * float(_mode.get("enemy_hp", 1.0))
	var dmg_m := (1.0 + (float(tl["damage"]) - 1.0) * step) * float(_mode.get("enemy_damage", 1.0))
	var enemy: CharacterBody2D = EnemyScene.instantiate()
	enemy.setup(spot, hp_m, dmg_m, 1.0, _roll_enemy_kind())
	world.add_child(enemy)

## Just outside the visible screen along dir (from the camera's view centre),
## kept within SPAWN_MIN..SPAWN_MAX of the hero so mobs walk in quickly.
const SPAWN_MARGIN := 48.0
const SPAWN_MIN := 520.0
const SPAWN_MAX := 760.0

func _spawn_point_outside_view(dir: Vector2) -> Vector2:
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var center := player.global_position
	var half := Vector2(360, 640)
	if cam:
		center += cam.offset
		half = get_viewport().get_visible_rect().size / cam.zoom * 0.5
	var tx := INF if absf(dir.x) < 0.001 else half.x / absf(dir.x)
	var ty := INF if absf(dir.y) < 0.001 else half.y / absf(dir.y)
	var edge := center + dir * (minf(tx, ty) + SPAWN_MARGIN)
	var from_hero := edge - player.global_position
	var d := clampf(from_hero.length(), SPAWN_MIN, SPAWN_MAX)
	return player.global_position + from_hero.normalized() * d

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

func _on_extract_requested() -> void:
	if _ended or not _extract_open:
		return
	_ended = true
	GameState.on_extract_success()
	Juice.sfx("extract_win")
	Juice.haptic(60)
	hud.show_banner("EXTRACTED", "Payout %d scrap (×%.1f)" % [GameState.payout_this_run, GameState.loot_mult], Color(0.55, 1.0, 0.6))
	if is_instance_valid(player):
		Juice.burst(player.global_position, Color(1, 0.85, 0.4), 40, 260.0, 0.9, 1.4)
		var tw := player.create_tween()
		tw.tween_property(player, "modulate:a", 0.0, 0.8)
	_go_result_after(1.6)

## Timer callback bound to this node: if the scene is already gone (Abandon,
## quit), the connection dies with it — no double go_result.
func _go_result_after(sec: float) -> void:
	get_tree().create_timer(sec).timeout.connect(_go_result_now)

func _go_result_now() -> void:
	if is_inside_tree() and get_tree().current_scene == self:
		GameState.go_result()

func is_run_over() -> bool:
	return _ended or GameState.run_finished

## App went to background (TouchInput) — open the pause menu if the run is live.
func request_auto_pause() -> void:
	if is_run_over():
		return
	if hud and hud.has_method("open_pause"):
		hud.call("open_pause")

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
	_go_result_after(1.8)

func get_phase_progress() -> float:
	var dur := float(_phases[_phase_index]["duration"])
	if dur <= 0.0:
		return 1.0
	return 1.0 - (_phase_time_left / dur)

func is_extract_open() -> bool:
	return _extract_open

func get_pads() -> Array:
	return _pads
