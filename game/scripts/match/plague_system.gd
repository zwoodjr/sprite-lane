extends Node

## Depth Update E1 — medicine & plague in a run:
##   * places this run's medicine crates (MedicineDefs.CRATES_BY_TIER),
##   * tier 5+: drifts plague fog patches in ahead of the hero and runs the
##     exposure meter (fog + plague hits build it; stages slow you, then drain HP),
##   * pushes pack / exposure / tonic state to the HUD.

const ZoneScript := preload("res://scripts/entities/plague_zone.gd")

var _match: Node
var _player: Node2D
var _world: Node2D
var _hud: Node
var _zone_t: float = 0.0
var _stage: int = -1
var _active: bool = false
var _rng := RandomNumberGenerator.new()


func setup(match_node: Node, player: Node2D, world: Node2D, hud: Node) -> void:
	_match = match_node
	_player = player
	_world = world
	_hud = hud
	_active = GameState.exposure_active()
	_rng.seed = GameState.run_seed * 31 + 7
	_zone_t = 20.0 * GameState.timer_scale()
	if player.has_signal("attacked"):
		player.attacked.connect(_on_attacked)
	_place_crates.call_deferred()
	if _hud and _hud.has_method("set_tonics"):
		_hud.call("set_tonics", GameState.run_tonics)


## Medicine crates in clear spots around the drop-in.
func _place_crates() -> void:
	if not is_instance_valid(_player):
		return
	var n := MedicineDefs.crates_for_tier(int(GameState.get_mode().get("tier", 1)))
	var base := _rng.randf() * TAU
	for i in range(n):
		var p := Vector2.ZERO
		for attempt in range(12):
			var ang := base + TAU * float(i) / float(n) + _rng.randf_range(-0.5, 0.5)
			p = _player.global_position + Vector2(cos(ang), sin(ang)) * _rng.randf_range(MedicineDefs.CRATE_DIST_MIN, MedicineDefs.CRATE_DIST_MAX)
			if _match.has_method("_spot_free") and bool(_match.call("_spot_free", p, 40.0)):
				break
		HaulPickup.spawn(_world, p, "medicine", 1, false)
	_place_lore_page()


## Depth E3: sometimes a hidden lore page lies out in the Dust.
func _place_lore_page() -> void:
	var left := GameState.missing_pages()
	if left.is_empty() or _rng.randf() > BestiaryDefs.PAGE_CHANCE:
		return
	spawn_page(str(left[_rng.randi() % left.size()]))


func spawn_page(id: String, at: Vector2 = Vector2.INF) -> Node2D:
	var p := at
	if p == Vector2.INF:
		var ang := _rng.randf() * TAU
		p = _player.global_position + Vector2(cos(ang), sin(ang)) * _rng.randf_range(BestiaryDefs.PAGE_DIST.x, BestiaryDefs.PAGE_DIST.y)
	var n := Node2D.new()
	n.set_script(load("res://scripts/entities/lore_page.gd"))
	n.set("page_id", id)
	n.position = p
	_world.add_child(n)
	return n


func _on_attacked(attacker: Node) -> void:
	if not _active or attacker == null or not is_instance_valid(attacker):
		return
	if str(attacker.get("faction")) == EnemyDefs.PLAGUE:
		GameState.add_exposure(MedicineDefs.HIT_GAIN)


func is_in_fog(p: Vector2) -> bool:
	for z in get_tree().get_nodes_in_group("plague_zones"):
		if is_instance_valid(z) and bool(z.call("contains", p)):
			return true
	return false


func spawn_zone(at: Vector2, r: float = -1.0) -> Node2D:
	var z := Node2D.new()
	z.set_script(ZoneScript)
	z.set("radius", r if r > 0.0 else _rng.randf_range(MedicineDefs.ZONE_RADIUS.x, MedicineDefs.ZONE_RADIUS.y))
	z.set("life", MedicineDefs.ZONE_LIFE)
	z.position = at
	_world.add_child(z)
	return z


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or GameState.run_finished:
		return
	if _active:
		_tick_zones(delta)
		_tick_exposure(delta)
	if _hud and _hud.has_method("set_pack"):
		_hud.call("set_pack", GameState.pack_weight(), GameState.pack_capacity(), GameState.medicine_carried())


func _tick_zones(delta: float) -> void:
	_zone_t -= delta
	if _zone_t > 0.0:
		return
	_zone_t = 60.0 / MedicineDefs.ZONES_PER_MIN * _rng.randf_range(0.7, 1.3) * GameState.timer_scale()
	if get_tree().get_nodes_in_group("plague_zones").size() >= MedicineDefs.ZONES_MAX:
		return
	## Ahead of where the hero is heading, so they have to choose to go around.
	var heading: Vector2 = _player.velocity if "velocity" in _player else Vector2.ZERO
	var ang := heading.angle() + _rng.randf_range(-0.8, 0.8) if heading.length() > 30.0 else _rng.randf() * TAU
	var at := _player.global_position + Vector2(cos(ang), sin(ang)) * _rng.randf_range(MedicineDefs.ZONE_DIST.x, MedicineDefs.ZONE_DIST.y)
	spawn_zone(at)


func _tick_exposure(delta: float) -> void:
	if is_in_fog(_player.global_position):
		GameState.add_exposure(MedicineDefs.ZONE_RATE * delta)
	else:
		GameState.cleanse_exposure(MedicineDefs.DECAY * delta)
	var st := MedicineDefs.stage_of(GameState.exposure)
	if st != _stage:
		if st > _stage and st >= 0 and _hud and _hud.has_method("show_toast"):
			_hud.call("show_toast", "PLAGUE: %s" % str(MedicineDefs.STAGES[st]["name"]).to_upper(), Color(0.7, 1.0, 0.45))
			Juice.sfx("threat_up", -6.0)
		_stage = st
	var mv := 0.0
	var fr := 0.0
	var dps := 0.0
	if st >= 0:
		var sd: Dictionary = MedicineDefs.STAGES[st]
		mv = float(sd["move"])
		fr = float(sd["firerate"])
		dps = float(sd["dps"])
	_player.set("exposure_move", mv)
	_player.set("exposure_rate", fr)
	if dps > 0.0 and _player.has_method("drain"):
		_player.call("drain", dps * delta)
	if _hud and _hud.has_method("set_exposure"):
		_hud.call("set_exposure", GameState.exposure, st)
