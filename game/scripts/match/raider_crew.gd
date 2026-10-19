extends Node

## Depth Update E2 — a rival raider crew. Spawns off screen, walks the map
## looting medicine crates, turns on the hero when they get close, carry
## medicine (the crew smells profit too) or start shooting at them. The
## carrier (captain, else a brute) holds the bag: kill it and the bag drops
## with everything the crew looted.

var _match: Node
var _player: Node2D
var _world: Node2D
var _hud: Node
var members: Array = []
var carrier: Node2D = null
var bag_medicine: int = 0
var hunting: bool = false
var done: bool = false
var _goal: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func setup(match_node: Node, player: Node2D, world: Node2D, hud: Node) -> void:
	_match = match_node
	_player = player
	_world = world
	_hud = hud
	_rng.randomize()


## Spawn the crew for this tier near `at` (defaults to just off screen).
func spawn(tier: int, at: Vector2 = Vector2.INF) -> void:
	var kinds: Array = []
	if tier >= FactionDefs.CREW_CAPTAIN_TIER:
		kinds.append("raider_captain")
	for i in range(FactionDefs.crew_brutes(tier)):
		kinds.append("raider_brute")
	for i in range(maxi(1, FactionDefs.crew_grunts(tier))):
		kinds.append("raider_grunt")
	var centre := at
	if centre == Vector2.INF:
		var ang := _rng.randf() * TAU
		centre = _player.global_position + Vector2(cos(ang), sin(ang)) * FactionDefs.CREW_SPAWN_DIST
	var mode := GameState.get_mode()
	var tl := ModeDefs.tl_table(GameState.threat_level)
	var hp_m := float(tl["hp"]) * float(mode.get("enemy_hp", 1.0))
	var dmg_m := float(tl["damage"]) * float(mode.get("enemy_damage", 1.0))
	var scene: PackedScene = load("res://scenes/entities/enemy.tscn")
	for i in range(kinds.size()):
		var e: CharacterBody2D = scene.instantiate()
		var off := Vector2.RIGHT.rotated(TAU * float(i) / float(kinds.size())) * (24.0 + 10.0 * i)
		e.setup(centre + off, hp_m, dmg_m, 1.0, str(kinds[i]))
		e.set("crew", self)
		e.add_to_group("raiders")
		if str(kinds[i]) == "raider_captain":
			e.call("set_role", "boss")
		_world.add_child(e)
		members.append(e)
	_pick_carrier()
	_goal = centre
	if _hud and _hud.has_method("show_toast"):
		_hud.call("show_toast", "RADIO: a raider crew is working the area — they're after the medicine", FactionDefs.CREW_MAP_COLOR)
	Juice.sfx("threat_up", -4.0)


func _pick_carrier() -> void:
	carrier = null
	for want in ["raider_captain", "raider_brute", "raider_grunt"]:
		for m in members:
			if is_instance_valid(m) and str(m.get("kind")) == want:
				carrier = m
				break
		if carrier != null:
			break
	if carrier != null:
		carrier.add_to_group("map_markers")
		carrier.set("map_color", FactionDefs.CREW_MAP_COLOR)


func is_hunting() -> bool:
	return hunting


## Where each member walks while the crew is on the move (a loose wedge).
func goal_for(m: Node) -> Vector2:
	var i := members.find(m)
	if i <= 0:
		return _goal
	return _goal + Vector2.RIGHT.rotated(2.4 * i) * (36.0 + 8.0 * i)


func _centre() -> Vector2:
	if carrier != null and is_instance_valid(carrier):
		return carrier.global_position
	for m in members:
		if is_instance_valid(m):
			return (m as Node2D).global_position
	return _goal


func _process(_delta: float) -> void:
	if done or _player == null or not is_instance_valid(_player):
		return
	members = members.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not bool(m.get("_dead")))
	if members.is_empty():
		_finish()
		return
	var c := _centre()
	var d := c.distance_to(_player.global_position)
	if not hunting:
		var hurt := false
		for m in members:
			if float(m.get("hp")) < float(m.get("max_hp")) - 0.5:
				hurt = true
		if hurt or d < FactionDefs.CREW_HUNT_RANGE or (GameState.medicine_carried() > 0 and d < FactionDefs.CREW_SMELL_RANGE):
			hunting = true
			if _hud and _hud.has_method("show_toast"):
				_hud.call("show_toast", "The raiders are coming for you!", FactionDefs.CREW_MAP_COLOR)
			return
		_loot_step(c)


## Head for the nearest medicine crate and take it; none left → roam toward the hero.
func _loot_step(c: Vector2) -> void:
	var best: Node2D = null
	var bd := INF
	for cr in get_tree().get_nodes_in_group("medicine_crates"):
		if not is_instance_valid(cr):
			continue
		var dd := (cr as Node2D).global_position.distance_to(c)
		if dd < bd:
			bd = dd
			best = cr
	if best == null:
		_goal = _player.global_position
		return
	_goal = best.global_position
	if bd <= FactionDefs.CREW_LOOT_R:
		bag_medicine += 1
		best.queue_free()
		Juice.burst(best.global_position, Color(1.0, 0.45, 0.4), 10, 120.0, 0.4)
		if _hud and _hud.has_method("show_toast"):
			_hud.call("show_toast", "Raiders looted a medicine crate — their bag holds %d" % bag_medicine, FactionDefs.CREW_MAP_COLOR)


func on_member_died(m: Node) -> void:
	members.erase(m)
	if m == carrier:
		_drop_bag((m as Node2D).global_position)
		_pick_carrier()
	if members.is_empty():
		_finish()


## The crew's bag: looted medicine + some scrap and ingredients.
func _drop_bag(at: Vector2) -> void:
	for i in range(bag_medicine):
		HaulPickup.spawn(_world, at + Vector2(18 * i - 9 * bag_medicine, 16), "medicine", 1)
	bag_medicine = 0
	LootDrop.spawn_burst(_world, at, "scrap", 4, float(_rng.randi_range(FactionDefs.BAG_SCRAP.x, FactionDefs.BAG_SCRAP.y)))
	for i in range(FactionDefs.BAG_INGREDIENTS):
		HaulPickup.spawn(_world, at, str(MedicineDefs.INGREDIENT_IDS[_rng.randi() % MedicineDefs.INGREDIENT_IDS.size()]))
	Juice.float_text(at + Vector2(0, -50), "RAIDER BAG", FactionDefs.CREW_MAP_COLOR, 18)
	GameState.quest_event("raider_bag")


func _finish() -> void:
	if done:
		return
	done = true
	if _hud and _hud.has_method("show_toast"):
		_hud.call("show_toast", "Raider crew down.", FactionDefs.CREW_MAP_COLOR)
	queue_free()
