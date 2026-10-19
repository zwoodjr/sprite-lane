extends Node

## Throwaway playtest bot (scratch copy only). Plays like a phone player:
## single stick, run = aim + auto-fire, FIRE when idle, DASH when crowded,
## heads to an open extract pad. Logs a line per second, snaps PNGs.

var _out := "/tmp/shots"
var _secs := 150.0
var _m: Node
var _p: Node2D
var _t := 0.0
var _log_t := 0.0
var _snap_t := 0.0
var _n := 0
var _kills_seen := {}
var _dmg_events := 0
var _last_hp := 100.0
var _wander := Vector2.RIGHT
var _wander_t := 0.0
var _ended := false
var _frames := 0
var _go := false
var _headless := false
var _abil_t := 3.0
var _abil_uses := 0
var _pet_far := 0.0
var _min_hp := 9999.0
var _reload_s := 0.0
var _stuck_s := 0.0
var _last_pos := Vector2.ZERO
## Optional stress / showcase: keep `_horde` enemies alive (arg 6), drawn from
## `_kinds` (arg 7, comma list; empty = whole roster).
var _horde := 0
var _kinds: Array = []
var _horde_t := 0.0
## arg 8 "stand": hero holds still (auto-attacks only) and snaps every 1.5 s.
var _stand := false
var _fps_min := 9999
var _fps_sum := 0.0
var _fps_n := 0
var _leave_at := 1
var _stuck_frames := 0
var _unstick_t := 0.0
var _unstick_side := 1.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: _secs = float(a[1])
	var ch := a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.tutorial_done = true
	TouchInput.touch_primary = true
	if ch != "": GameState.selected_character_id = ch
	if a.size() > 3: GameState.selected_mode_id = a[3]
	if a.size() > 4 and a[4] != "": GameState.selected_pet_id = a[4]
	if a.size() > 5: _horde = int(a[5])
	if a.size() > 6 and a[6] != "": _kinds = Array(a[6].split(","))
	if a.size() > 7: _stand = a[7] == "stand"
	## arg 8: fixed run seed · arg 9: leave at window N (stay-or-go, 1 = first).
	var fixed_seed := int(a[8]) if a.size() > 8 else 0
	if a.size() > 9: _leave_at = int(a[9])
	_headless = DisplayServer.get_name() == "headless"
	print("BOT char=", GameState.selected_character_id, " mode=", GameState.selected_mode_id)
	GameState.begin_run()
	if fixed_seed != 0:
		GameState.run_seed = fixed_seed
		seed(fixed_seed)
	_m = (load("res://scenes/match/match.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_m)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = _m
	_p = _m.get_node("World/Player")
	_p.died.connect(func() -> void: print("EVENT died t=%.1f" % _t))
	_p.health_changed.connect(func(c: float, mx: float) -> void:
		if c < _last_hp: _dmg_events += 1
		_last_hp = c)
	_go = true


func _snap(name: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	## Close-up around the hero (3x, nearest) to check art / muzzles / feet.
	if is_instance_valid(_p):
		var sp: Vector2 = get_viewport().get_canvas_transform() * _p.global_position
		var r := Rect2i(Vector2i(sp) - Vector2i(150, 150), Vector2i(300, 300))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 10 and r.size.y > 10:
			var c := img.get_region(r)
			c.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
			c.save_png("%s/%s_zoom.png" % [_out, name])


func _nearest(group: String) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for e in get_tree().get_nodes_in_group(group):
		if not is_instance_valid(e) or not (e is Node2D): continue
		var d: float = (e as Node2D).global_position.distance_to(_p.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _process(delta: float) -> void:
	if not _go: return
	_frames += 1
	if _p == null or not is_instance_valid(_p):
		if not _ended:
			_ended = true
			_summary()
			print("EVENT scene_changed t=%.1f scene=%s" % [_t, get_tree().current_scene.name if get_tree().current_scene else "?"])
			await get_tree().create_timer(1.0, true, false, true).timeout
			await _snap("zz_end")
			get_tree().quit()
		return
	if get_tree().paused:
		## Upgrade picker or pause menu — log and click first choice-ish by unpausing via picker API.
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("_pick") and n.get("_open"):
				print("EVENT upgrade_picker t=%.1f" % _t)
				await _snap("upgrade_%02d" % _n)
				var ch: Array = Progression.roll_run_choices(2)
				n._pick(ch[0])
				break
		return
	_t += delta
	_drive(delta)
	_extra(delta)
	_top_up_horde(delta)
	_log_t += delta
	_snap_t += delta
	if _log_t >= 1.0:
		_log_t = 0.0
		var en := get_tree().get_nodes_in_group("enemies").size()
		var ne := _nearest("enemies")
		var nd: float = ne.global_position.distance_to(_p.global_position) if ne else -1.0
		if _t > 3.0:
			var f := Engine.get_frames_per_second()
			_fps_min = mini(_fps_min, f)
			_fps_sum += f
			_fps_n += 1
		print("T %5.1f fps=%d hp=%.0f/%.0f enemies=%d nearest=%.0f phase=%d extract=%s pos=(%.0f,%.0f) hits=%d" % [
			_t, Engine.get_frames_per_second(), _p.hp, _p.max_hp, en, nd,
			_m.get("_phase_index"), _m.call("is_extract_open"), _p.global_position.x, _p.global_position.y, _dmg_events])
	if _snap_t >= (1.5 if _stand else (5.0 if _secs < 30.0 else 8.0)):
		_snap_t = 0.0
		_n += 1
		_snap("shot_%02d_t%03d" % [_n, int(_t)])
	if _t >= _secs:
		_summary()
		print("EVENT timeout")
		_ended = true
		await _snap("zz_end")
		get_tree().quit()


func _drive(delta: float) -> void:
	if _stand:
		TouchInput.move_vector = Vector2.ZERO
		return
	## Combat is automatic (hero fires/swings at the closest enemy in range);
	## the bot only steers the move stick and taps DASH / ABILITY.
	var mv := Vector2.ZERO
	var e := _nearest("enemies")
	var rng: float = _p.call("get_trigger_range")
	var melee: bool = _p.call("is_melee")
	var low_hp: bool = float(_p.get("hp")) < float(_p.get("max_hp")) * 0.35
	## Head for pads once they're pinged on the window we plan to leave on;
	## extract when open.
	var going: bool = int(GameState.extract_windows_seen) >= _leave_at - 1 and (_m.call("get_pads") as Array).size() > 0
	if going:
		var best: Node2D = null
		var bd := INF
		for pad in _m.call("get_pads"):
			if is_instance_valid(pad):
				var d: float = pad.global_position.distance_to(_p.global_position)
				if d < bd: bd = d; best = pad
		if best:
			var to := best.global_position - _p.global_position
			mv = to.normalized() if to.length() > 12.0 else Vector2.ZERO
			## Blocked by a prop? Slide around it for a moment.
			if _unstick_t > 0.0:
				_unstick_t -= delta
				mv = mv.rotated(1.3 * _unstick_side)
			elif _stuck_frames > 20:
				_unstick_t = 0.6
				_unstick_side = -_unstick_side
				_stuck_frames = 0
			if e and e.global_position.distance_to(_p.global_position) < 70.0:
				TouchInput.pulse_dash()
			TouchInput.move_vector = mv
			return
	if e:
		var to: Vector2 = e.global_position - _p.global_position
		var d := to.length()
		if melee:
			## Melee: close in (dash in to close gaps), swing, and dash OUT when
			## something nearby winds up. Back off to recover when low.
			var dash_ready: bool = float(_p.call("get_dash_cooldown_ratio")) <= 0.0
			var threat := _winding_up_near(150.0)
			if threat != null:
				var away: Vector2 = (_p.global_position - threat.global_position).normalized()
				mv = away.rotated(0.5)
				if dash_ready:
					TouchInput.pulse_dash()
			elif low_hp and d < 260.0:
				mv = -to.normalized().rotated(0.4 * sin(_t))
			elif d > rng * 0.8:
				mv = to.normalized()
				if d < 240.0 and d > rng + 30.0 and dash_ready and not low_hp:
					TouchInput.pulse_dash()
			else:
				## In reach: orbit slowly so swings keep landing.
				mv = to.normalized().rotated(PI * 0.5) * 0.45
		elif d < 110.0:
			## Too close: run away and dash.
			mv = -to.normalized().rotated(0.6)
			TouchInput.pulse_dash()
		elif d < rng * 0.6:
			mv = -to.normalized().rotated(0.5 * sin(_t))
		elif d < rng * 0.95:
			## In range: strafe around it (auto-fire does the shooting).
			mv = to.normalized().rotated(PI * 0.5 * (1.0 if sin(_t * 0.4) > 0.0 else -1.0)) * 0.8
		else:
			mv = to.normalized() if not low_hp else _wander_dir(delta)
	else:
		mv = _wander_dir(delta)
	TouchInput.move_vector = mv


func _winding_up_near(r: float) -> Node2D:
	for n in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(n): continue
		var en := n as Node2D
		if en.global_position.distance_to(_p.global_position) < r and float(en.get("_windup_left")) > 0.0:
			return en
	return null


func _wander_dir(delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = 3.0
		_wander = Vector2.RIGHT.rotated(randf() * TAU)
	return _wander


func _extra(delta: float) -> void:
	_min_hp = min(_min_hp, _p.hp)
	if _p.get("_reload_left") > 0.0: _reload_s += delta
	if TouchInput.move_vector.length() > 0.5 and _p.global_position.distance_to(_last_pos) < 0.3:
		_stuck_s += delta
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_pos = _p.global_position
	_abil_t -= delta
	var e := _nearest("enemies")
	if _abil_t <= 0.0 and e and e.global_position.distance_to(_p.global_position) < 300.0:
		_abil_t = 4.0
		TouchInput.pulse_ability()
		_abil_uses += 1
	for pet in get_tree().get_nodes_in_group("pets"):
		if is_instance_valid(pet) and pet.global_position.distance_to(_p.global_position) > 500.0:
			_pet_far += delta


func _top_up_horde(delta: float) -> void:
	if _horde <= 0:
		return
	_horde_t -= delta
	if _horde_t > 0.0:
		return
	_horde_t = 0.25
	var live := get_tree().get_nodes_in_group("enemies").size()
	var scene: PackedScene = load("res://scenes/entities/enemy.tscn")
	var pool: Array = _kinds if not _kinds.is_empty() else EnemyDefs.all_kinds().map(func(k: Dictionary) -> String: return str(k["id"]))
	for i in range(mini(6, _horde - live)):
		var e: CharacterBody2D = scene.instantiate()
		var at := _p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(170.0, 330.0)
		e.call("setup", at, 1.0, 0.6, 1.0, str(pool[randi() % pool.size()]))
		_p.get_parent().add_child(e)


func _summary() -> void:
	if _fps_n > 0:
		print("FPS avg=%.0f min=%d horde=%d" % [_fps_sum / _fps_n, _fps_min, _horde])
	var hp_end: float = float(_p.get("hp")) if is_instance_valid(_p) else -1.0
	print("SUMMARY char=%s pet=%s mode=%s seed=%d t=%.0f result=%s payout=%d loot=%.1f hp_end=%.0f min_hp=%.0f kills=%d bag=%d runlv=%d hits=%d abil=%d reload_s=%.0f" % [
		GameState.selected_character_id, GameState.selected_pet_id, GameState.selected_mode_id, GameState.run_seed, _t,
		"EXTRACT" if GameState.extracted else ("DIED" if GameState.wiped else "ALIVE"),
		GameState.payout_this_run, GameState.loot_mult, hp_end, _min_hp, GameState.kills, GameState.bag_value(),
		GameState.run_level, _dmg_events, _abil_uses, _reload_s])
