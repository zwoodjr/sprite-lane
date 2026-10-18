extends CharacterBody2D

## Active companion. Follows the player; Noel enrages when the player is hit
## and AOE-rampages until THAT attacking unit dies.

signal rampage_started(target: Node)
signal rampage_ended

const BODY_FOV_PX := 40.0

var _def: Dictionary = {}
var _player: Node2D
var _target: Node2D ## rampage focus (the unit that hit the player)
var _rampaging: bool = false
var _bite_cd: float = 0.0
var _aoe_cd: float = 0.0
var _bob_t: float = 0.0
var _body_base_scale: float = 1.0
var _flash_left: float = 0.0

@onready var body: Sprite2D = $Body
@onready var name_label: Label = $NameLabel


func setup(owner_player: Node2D, def: Dictionary) -> void:
	_player = owner_player
	_def = def.duplicate(true)
	if is_inside_tree():
		_apply_look()


func _ready() -> void:
	add_to_group("pets")
	collision_layer = 0
	collision_mask = 1
	if _def.is_empty() and GameState.pet:
		_def = GameState.pet.duplicate(true)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_apply_look()
	if _player and _player.has_signal("attacked"):
		if not _player.attacked.is_connected(_on_player_attacked):
			_player.attacked.connect(_on_player_attacked)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _apply_look() -> void:
	var path := str(_def.get("sprite", "res://assets/sprites/pets/noel.png"))
	if _rampaging and str(_def.get("sprite_rampage", "")) != "":
		path = str(_def["sprite_rampage"])
	var tex := load(path) as Texture2D
	if body and tex:
		body.texture = tex
	_sync_body_scale()
	if name_label:
		name_label.text = str(_def.get("name", "Pet"))
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.45, 0.3) if _rampaging else Color(0.92, 0.86, 0.72)
		)


func _sync_body_scale() -> void:
	var tw := 48.0
	if body and body.texture != null:
		tw = float(body.texture.get_width())
	_body_base_scale = BODY_FOV_PX / maxf(tw, 1.0)
	if body:
		body.scale = Vector2.ONE * _body_base_scale


func _physics_process(delta: float) -> void:
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_aoe_cd = maxf(0.0, _aoe_cd - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	_refresh_rampage_target()
	_update_move(delta)
	_update_combat(delta)
	_update_visuals(delta)


func _refresh_rampage_target() -> void:
	if not _rampaging:
		return
	if _target == null or not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_end_rampage()
		return
	## Enemy removed from group on death before free — treat as dead.
	if _target.is_in_group("enemies") == false and _target.get("hp") != null:
		if float(_target.get("hp")) <= 0.0:
			_end_rampage()
			return
	if not _target.is_in_group("enemies"):
		_end_rampage()


func _on_player_attacked(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	if not attacker.is_in_group("enemies"):
		return
	if str(_def.get("ability_id", "")) != "territorial_rampage":
		## Non-Noel pets: snap toward the attacker for a bite, no rampage.
		_target = attacker as Node2D
		return
	_begin_rampage(attacker as Node2D)


func _begin_rampage(attacker: Node2D) -> void:
	_target = attacker
	_rampaging = true
	_aoe_cd = 0.05
	_apply_look()
	Juice.sfx("ability", -2.0)
	Juice.burst(global_position, Color(1.0, 0.35, 0.2), 20, 200.0, 0.55)
	Juice.float_text(global_position + Vector2(0, -28), "NOEL RAMPAGE!", Color(1.0, 0.45, 0.25), 18)
	Juice.shake(0.18)
	rampage_started.emit(_target)


func _end_rampage() -> void:
	if not _rampaging:
		_target = null
		return
	_rampaging = false
	_target = null
	_apply_look()
	Juice.float_text(global_position + Vector2(0, -24), "Settled", Color(0.85, 0.8, 0.7), 14)
	rampage_ended.emit()


func _update_move(delta: float) -> void:
	var speed := float(_def.get("follow_speed", 260.0))
	if _rampaging:
		speed *= float(_def.get("rampage_speed_mult", 1.5))
	var goal: Vector2
	if _rampaging and _target != null and is_instance_valid(_target):
		goal = _target.global_position
	elif _target != null and is_instance_valid(_target) and global_position.distance_to(_target.global_position) < 220.0:
		goal = _target.global_position
	else:
		## Orbit behind / beside the player.
		var facing := Vector2.RIGHT
		if _player.get("velocity") is Vector2 and (_player.velocity as Vector2).length() > 20.0:
			facing = (_player.velocity as Vector2).normalized()
		var behind := -facing * 36.0 + facing.orthogonal() * 14.0
		goal = _player.global_position + behind
	var to := goal - global_position
	var dist := to.length()
	if dist > 8.0:
		var want := to.normalized() * speed
		if not _rampaging and dist < 40.0:
			want *= dist / 40.0
		velocity = velocity.move_toward(want, 1800.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2200.0 * delta)
	move_and_slide()
	if body and to.length() > 4.0:
		body.flip_h = to.x < 0.0


func _update_combat(delta: float) -> void:
	if _rampaging:
		_tick_rampage_aoe()
		return
	## Idle territorial bites on nearest nearby enemy.
	if _bite_cd > 0.0:
		return
	var nearest := _nearest_enemy(float(_def.get("bite_range", 40.0)) + 8.0)
	if nearest == null:
		return
	_bite(nearest)


func _tick_rampage_aoe() -> void:
	if _aoe_cd > 0.0:
		return
	var tick := float(_def.get("rampage_tick", 0.28))
	_aoe_cd = tick
	var radius := float(_def.get("rampage_aoe_radius", 110.0))
	var dmg := float(_def.get("rampage_aoe_damage", 38.0))
	Juice.burst(global_position, Color(1.0, 0.4, 0.2, 0.9), 14, radius * 1.4, 0.35, 1.2)
	Juice.dust_puff(global_position + Vector2(0, 10), 10)
	Juice.shake(0.1)
	_flash_left = 0.12
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("take_damage"):
			var dir := (e.global_position - global_position).normalized()
			e.call("take_damage", dmg, dir)
	## Focus bite on the attacker too (extra punch).
	if _target != null and is_instance_valid(_target) and _target.has_method("take_damage"):
		if global_position.distance_to(_target.global_position) <= radius:
			_target.call("take_damage", dmg * 0.35, (_target.global_position - global_position).normalized())


func _bite(enemy: Node2D) -> void:
	_bite_cd = float(_def.get("bite_cooldown", 0.6))
	var dmg := float(_def.get("bite_damage", 8.0))
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", dmg, (enemy.global_position - global_position).normalized())
	Juice.sfx("hit", -10.0)
	Juice.burst(enemy.global_position, Color(0.95, 0.75, 0.45), 6, 90.0, 0.25)


func _nearest_enemy(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best


func _update_visuals(delta: float) -> void:
	if body == null:
		return
	var bs := _body_base_scale
	_bob_t += delta * (18.0 if _rampaging else 12.0)
	body.position.y = -absf(sin(_bob_t)) * (4.0 if _rampaging else 2.0)
	var pulse := 1.0 + (0.08 if _rampaging else 0.0) * sin(_bob_t * 2.0)
	body.scale = Vector2.ONE * bs * pulse
	if _rampaging:
		body.modulate = Color(1.35, 0.75, 0.65) if int(_bob_t * 8.0) % 2 == 0 else Color(1.15, 0.85, 0.8)
	elif _flash_left > 0.0:
		body.modulate = Color(1.4, 1.2, 1.0)
	else:
		body.modulate = Color.WHITE


func is_rampaging() -> bool:
	return _rampaging


func get_pet_name() -> String:
	return str(_def.get("name", "Pet"))
