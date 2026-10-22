extends Node

## Campaign playtest bot: plays levels like a phone player, driven by the
## level's objective (walk to the marker, stay in hold rings, keep near the
## escort, kite mobs, close on bosses), auto-picks level-ups, dashes when
## crowded or stuck. Story scenes / cards auto-advance.
##   godot --headless --fixed-fps 60 --path game res://tools/campaign_bot.tscn -- LEVELS [hero] [god=1] [max_secs=900]
## Prints a SUMMARY line per level: won / failed, time, deaths, objectives.
## Run with a throwaway XDG_DATA_HOME (it writes campaign progress).

var _levels: Array = []
var _hero: String = ""
var _god: bool = true
var _max: float = 900.0
var _m: Node
var _p: Node2D
var _t: float = 0.0
var _stuck_t: float = 0.0
var _side_t: float = 0.0
var _side: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _dash_t: float = 0.0
var _abil_t: float = 4.0
var _min_hp: float = 1.0e9
var _objs: Array = []
var _picking: bool = false
var _orbit: float = 0.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_levels = str(a[0]).split(",")
	if a.size() > 1:
		_hero = str(a[1])
	if a.size() > 2:
		_god = str(a[2]) != "0"
	if a.size() > 3:
		_max = float(a[3])
	_run.call_deferred()


func _run() -> void:
	GameState.tutorial_done = true
	GameState.campaign_autoplay = true
	GameState.campaign_autoplay_exit = false
	for id in _levels:
		await _play(str(id))
	get_tree().quit()


func _play(id: String) -> void:
	GameState.campaign = GameState._fresh_campaign()
	GameState.campaign_debug_unlock_to(id)
	Admin.god = _god
	if not GameState.prepare_campaign_level(id, _hero):
		print("SUMMARY level=%s result=missing" % id)
		return
	_m = (load(CampaignDefs.MATCH_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(_m)
	get_tree().current_scene = _m
	_p = _m.get_node("World/Player")
	_t = 0.0
	_min_hp = 1.0e9
	_objs = []
	var runner: Node = _m.get("runner")
	var last := -1
	var result := "timeout"
	while _t < _max:
		await get_tree().physics_frame
		if GameState.campaign_level_done(id):
			result = "won"
			break
		if bool(_m.get("_ended")) and not bool(_m.get("won")):
			result = "failed:" + str(GameState.campaign_result.get("reason", ""))
			break
		if get_tree().paused:
			await _maybe_pick()
			continue
		if not bool(_m.get("started")):
			continue
		var dt := get_physics_process_delta_time()
		_t += dt
		if int(runner.get("idx")) != last:
			last = int(runner.get("idx"))
			_objs.append("%s@%d" % [str((runner.get("obj") as Dictionary).get("type", "?")), int(_t)])
		if is_instance_valid(_p):
			_min_hp = minf(_min_hp, float(_p.get("hp")))
			_drive(runner, dt)
		if int(_t * 60.0) % 600 == 0:
			print("T %.0f obj=%s %s hp=%.0f pos=%s" % [_t, str((runner.get("obj") as Dictionary).get("type", "")), str((runner.get("obj") as Dictionary).get("text", "")), float(_p.get("hp")) if is_instance_valid(_p) else -1.0, str(_p.global_position.round()) if is_instance_valid(_p) else "?"])
	TouchInput.set_move(Vector2.ZERO)
	print("SUMMARY level=%s hero=%s result=%s time=%.1f level_time=%.1f kills=%d min_hp=%.0f objectives=%s" % [
		id, GameState.selected_character_id, result, _t, float(_m.get("level_time")), GameState.kills, _min_hp, " ".join(_objs)])
	for k in range(90):
		await get_tree().process_frame
	get_tree().paused = false
	_m.queue_free()
	GameState.leave_campaign_run()
	for k in range(3):
		await get_tree().process_frame


func _maybe_pick() -> void:
	if _picking:
		return
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("pick_index") and bool(n.call("is_open")):
			_picking = true
			await get_tree().process_frame
			n.call("pick_index", 0)
			_picking = false
			return


func _nearest_enemy(from: Vector2, r: float) -> Node2D:
	var best: Node2D = null
	var bd := r
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null or not is_instance_valid(en) or bool(en.get("_dead")):
			continue
		var d := en.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = en
	return best


func _drive(runner: Node, dt: float) -> void:
	var o: Dictionary = runner.get("obj")
	var typ := str(o.get("type", "reach"))
	var pos := _p.global_position
	var melee := bool(_p.call("is_melee"))
	var target: Vector2 = runner.call("current_target")
	var e := _nearest_enemy(pos, 420.0)
	var dir := Vector2.ZERO
	match typ:
		"hold", "defend":
			var c: Vector2 = o["at"]
			var r := float(o.get("r", 140.0))
			if pos.distance_to(c) > r * 0.6:
				dir = pos.direction_to(c)
			elif e:
				dir = _fight(pos, e, melee) * 0.7
				if pos.distance_to(c) > r * 0.45:
					dir = (dir + pos.direction_to(c)).normalized()
		"escort":
			var n: Node2D = (runner.get("npcs") as Dictionary).get(str(o.get("npc", "")), null)
			if n:
				var d2 := pos.distance_to(n.global_position)
				if d2 > 140.0:
					dir = pos.direction_to(n.global_position)
				elif e and e.global_position.distance_to(n.global_position) < 300.0:
					dir = _fight(pos, e, melee)
				else:
					dir = pos.direction_to(n.global_position + Vector2(0, -60)) * 0.5
		"kill", "clear", "survive", "wait", "boss":
			if typ == "boss" and target != Vector2.INF and e == null:
				e = _nearest_enemy(pos, 2400.0)
			if e == null:
				e = _nearest_enemy(pos, 1600.0)
			if e:
				dir = _fight(pos, e, melee)
			elif target != Vector2.INF:
				dir = pos.direction_to(target)
			else:
				_orbit += dt * 0.6
				dir = Vector2.from_angle(_orbit) * 0.6
		"extract":
			## Stand on the pad and channel (the auto-fire keeps mobs busy).
			if target != Vector2.INF and pos.distance_to(target) > 30.0:
				dir = pos.direction_to(target)
		_:
			if target != Vector2.INF:
				dir = pos.direction_to(target)
				if pos.distance_to(target) < 20.0:
					dir = Vector2.ZERO
			if e and pos.distance_to(e.global_position) < 110.0:
				dir = (dir + (pos - e.global_position).normalized() * 0.8).normalized()
	## Unstick: pushing but not moving -> slide sideways for a moment.
	var moved := pos.distance_to(_last_pos)
	_last_pos = pos
	if dir.length() > 0.3 and moved < 40.0 * dt:
		_stuck_t += dt
	else:
		_stuck_t = maxf(0.0, _stuck_t - dt * 2.0)
	if _stuck_t > 0.6 and _side_t <= 0.0 and OS.get_environment("CBOT_DEBUG") != "":
		var q := PhysicsShapeQueryParameters2D.new()
		var c := CircleShape2D.new()
		c.radius = 60.0
		q.shape = c
		q.transform = Transform2D(0.0, pos)
		q.collision_mask = 1
		for h in _p.get_world_2d().direct_space_state.intersect_shape(q, 8):
			var col: Object = h["collider"]
			print("STUCK near ", (col as Node).get_path() if col is Node else col, " at ", (col as Node2D).global_position if col is Node2D else "")
	if _stuck_t > 0.6 and _side_t <= 0.0:
		_side = dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		_side_t = 0.8
		_stuck_t = 0.0
	if _side_t > 0.0:
		_side_t -= dt
		dir = (_side + dir * 0.3).normalized()
	TouchInput.set_move(dir.limit_length(1.0))
	_dash_t -= dt
	if _dash_t <= 0.0 and ((e and pos.distance_to(e.global_position) < 70.0) or _side_t > 0.5):
		TouchInput.pulse_dash()
		_dash_t = 2.0
	_abil_t -= dt
	if _abil_t <= 0.0 and e:
		TouchInput.pulse_ability()
		_abil_t = 6.0


## Melee heroes close in; ranged heroes keep ~220 px and circle.
func _fight(pos: Vector2, e: Node2D, melee: bool) -> Vector2:
	var to := e.global_position - pos
	var d := to.length()
	var want := 46.0 + 20.0 * float(e.get("body_scale")) if melee else 230.0
	if d > want + 30.0:
		return to.normalized()
	if d < want - 40.0:
		return (-to.normalized() + to.normalized().orthogonal() * 0.6).normalized()
	return to.normalized().orthogonal()
