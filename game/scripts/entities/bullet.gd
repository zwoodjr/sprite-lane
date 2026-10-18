extends Area2D

## Layers: 1 world/breakables · 2 player · 4 enemies · 8 projectiles

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var from_player: bool = true
var lifetime: float = 1.1
## Who fired — used to ignore self-hits and for pet enrage attribution.
var source: Node = null
var splash_radius: float = 0.0
var splash_mult: float = 0.5
var status_effect: Dictionary = {} ## special ammo / run mods
var pierce_left: int = 0
var ricochet_left: int = 0
var _hit_ids: Dictionary = {} ## instance_id -> true, avoid re-hitting same foe when piercing

@onready var sprite: Sprite2D = $Sprite

var _trail: Line2D
var _hit: bool = false
var _arm_left: float = 0.04 ## brief spawn grace so muzzle overlap can't self-hit


func setup(
	origin: Vector2,
	dir: Vector2,
	spd: float,
	dmg: float,
	player_shot: bool,
	src: Node = null,
	life: float = -1.0,
	splash_r: float = 0.0,
	splash_m: float = 0.5
) -> void:
	global_position = origin
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = player_shot
	source = src
	splash_radius = splash_r
	splash_mult = splash_m
	rotation = direction.angle()
	## Enemy bullets live longer but are slower — readable and dodgeable.
	if life > 0.0:
		lifetime = life
	else:
		lifetime = 1.0 if player_shot else 1.8
	## Set masks before enter-tree so the first overlap uses the right team.
	_apply_team_collision()


func _apply_team_collision() -> void:
	collision_layer = 8
	if from_player:
		## World + enemies only — never the player layer (2).
		collision_mask = 1 | 4
	else:
		## World + player only.
		collision_mask = 1 | 2


func _ready() -> void:
	_apply_team_collision()
	body_entered.connect(_on_body_entered)
	if sprite and sprite.texture == null:
		sprite.texture = load("res://assets/sprites/props/bullet.png")
	var col := Color(1.0, 0.88, 0.4) if from_player else Color(1.0, 0.32, 0.22)
	if not from_player and sprite:
		## Slightly larger enemy shots so they read against dust at survivor FOV.
		sprite.scale = Vector2(1.25, 1.25)
	if sprite:
		sprite.modulate = col * 1.4
	_trail = Line2D.new()
	_trail.width = 3.0 if from_player else 5.0
	_trail.top_level = true
	_trail.z_index = 4
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.7))
	_trail.gradient = g
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _hit:
		return
	if _arm_left > 0.0:
		_arm_left -= delta
	global_position += direction * speed * delta
	_trail.add_point(global_position)
	while _trail.get_point_count() > (5 if from_player else 7):
		_trail.remove_point(0)
	lifetime -= delta
	if lifetime <= 0.0:
		_fizzle()


func _is_friendly(body: Node) -> bool:
	if body == null:
		return true
	if source != null and is_instance_valid(source) and body == source:
		return true
	if from_player:
		return body.is_in_group("player") or body.is_in_group("pets")
	## Enemy shots shouldn't hurt other enemies.
	return body.is_in_group("enemies")


func _on_body_entered(body: Node2D) -> void:
	if _hit or _arm_left > 0.0:
		return
	if _is_friendly(body):
		return
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return

	if from_player:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			_hit_ids[id] = true
			var dmg := damage
			## Backstab / mark / field notes / short circuit.
			if source != null and is_instance_valid(source) and source.has_method("mod_bullet_damage"):
				dmg = float(source.call("mod_bullet_damage", dmg, body, direction))
			body.take_damage(dmg, direction)
			_apply_status(body)
			_apply_splash(body)
			if pierce_left > 0:
				pierce_left -= 1
				Juice.burst(global_position, Color(1, 0.85, 0.45), 4, 80.0, 0.2)
				return
			if ricochet_left > 0:
				ricochet_left -= 1
				if _try_ricochet(body):
					Juice.burst(global_position, Color(0.9, 0.95, 1.0), 6, 100.0, 0.25)
					return
			_impact(Color(1, 0.85, 0.45))
		elif body.is_in_group("breakables") and body.has_method("take_damage"):
			body.take_damage(damage)
			_apply_splash(body)
			_impact(Color(1, 0.85, 0.45))
		elif body is StaticBody2D or body is TileMap:
			_apply_splash(null)
			_impact(Color(0.8, 0.7, 0.55))
	else:
		if body.is_in_group("player"):
			if body.has_method("is_dashing") and body.is_dashing():
				return  ## dashed through it
			if body.has_method("take_damage"):
				## Player signature: (float, Node attacker)
				var attacker: Node = source if source != null and is_instance_valid(source) else null
				body.take_damage(damage, attacker)
			_impact(Color(1, 0.35, 0.25))
		elif body is StaticBody2D or body is TileMap:
			_impact(Color(0.8, 0.7, 0.55))


func _try_ricochet(from_body: Node) -> bool:
	var best: Node2D = null
	var best_d := 220.0 * 220.0
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == from_body or not is_instance_valid(n) or not (n is Node2D):
			continue
		if _hit_ids.has(n.get_instance_id()):
			continue
		var e := n as Node2D
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return false
	direction = (best.global_position - global_position).normalized()
	rotation = direction.angle()
	damage *= 0.7
	_arm_left = 0.02
	return true


func _apply_status(body: Node) -> void:
	if status_effect.is_empty() or body == null or not is_instance_valid(body):
		return
	var id := str(status_effect.get("id", ""))
	match id:
		"shock":
			if body.has_method("distract"):
				body.call("distract", float(status_effect.get("stun", 0.55)))
			if body.has_method("set_meta"):
				body.set_meta("stunned_machine", true)
		"frost":
			if body.has_method("apply_slow"):
				body.call("apply_slow", float(status_effect.get("slow", 0.55)), float(status_effect.get("slow_sec", 1.4)))
			elif body.has_method("distract"):
				body.call("distract", float(status_effect.get("slow_sec", 1.4)) * 0.5)
		"incendiary":
			if body.has_method("apply_dot"):
				body.call("apply_dot", float(status_effect.get("dot", 4.0)), float(status_effect.get("dot_ticks", 3)) * 0.5)
			elif body.has_method("take_damage"):
				body.call("take_damage", float(status_effect.get("dot", 4.0)), Vector2.ZERO)
		"poison", "dust":
			if body.has_method("apply_dot"):
				body.call("apply_dot", 3.0 + float(status_effect.get("stacks", 1.0)), 2.0)
		"explosive":
			pass
		_:
			pass
	## Marked (Vesper class): enemies take extra damage from all sources.
	if float(status_effect.get("mark", 0.0)) > 0.0 and body.has_method("apply_mark"):
		body.call("apply_mark", 4.0)


func _apply_splash(primary: Node) -> void:
	if splash_radius <= 0.0 or not from_player:
		return
	var tree := get_tree()
	if tree == null:
		return
	var splash_dmg := damage * splash_mult * GameState.aoe_damage_mult()
	var r2 := splash_radius * splash_radius
	for n in tree.get_nodes_in_group("enemies"):
		if n == primary or not is_instance_valid(n):
			continue
		if not (n is Node2D) or not n.has_method("take_damage"):
			continue
		var other := n as Node2D
		if global_position.distance_squared_to(other.global_position) > r2:
			continue
		var knock := (other.global_position - global_position).normalized()
		if knock.length_squared() < 0.01:
			knock = direction
		other.take_damage(splash_dmg, knock)
	for n in tree.get_nodes_in_group("breakables"):
		if n == primary or not is_instance_valid(n):
			continue
		if not (n is Node2D) or not n.has_method("take_damage"):
			continue
		var crate := n as Node2D
		if global_position.distance_squared_to(crate.global_position) > r2:
			continue
		crate.take_damage(splash_dmg)


func _impact(col: Color) -> void:
	_hit = true
	var amount := 10 if splash_radius > 0.0 else 6
	var spd := 180.0 if splash_radius > 0.0 else 140.0
	Juice.burst(global_position, col, amount, spd, 0.28, 1.1 if splash_radius > 0.0 else 0.8)
	_cleanup()


func _fizzle() -> void:
	_hit = true
	_cleanup()


func _cleanup() -> void:
	if is_instance_valid(_trail):
		_trail.queue_free()
	queue_free()
