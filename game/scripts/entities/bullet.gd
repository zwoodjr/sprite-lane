extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var from_player: bool = true
var lifetime: float = 1.1
## Who fired (enemies only) — pets use this to enrage on the right unit.
var source: Node = null

@onready var sprite: Sprite2D = $Sprite

var _trail: Line2D
var _hit: bool = false


func setup(origin: Vector2, dir: Vector2, spd: float, dmg: float, player_shot: bool, src: Node = null) -> void:
	global_position = origin
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = player_shot
	source = src
	rotation = direction.angle()
	## Enemy bullets live longer but are slower — readable and dodgeable.
	lifetime = 1.0 if player_shot else 1.8


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite and sprite.texture == null:
		sprite.texture = load("res://assets/sprites/props/bullet.png")
	var col := Color(1.0, 0.88, 0.4) if from_player else Color(1.0, 0.32, 0.22)
	if from_player:
		collision_mask = 1 | 4
	else:
		collision_mask = 1 | 2
		## Slightly larger enemy shots so they read against dust at survivor FOV.
		if sprite:
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
	global_position += direction * speed * delta
	_trail.add_point(global_position)
	while _trail.get_point_count() > (5 if from_player else 7):
		_trail.remove_point(0)
	lifetime -= delta
	if lifetime <= 0.0:
		_fizzle()


func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	if from_player and (body.is_in_group("enemies") or body.is_in_group("breakables")):
		if body.has_method("take_damage"):
			if body.is_in_group("enemies"):
				body.take_damage(damage, direction)
			else:
				body.take_damage(damage)
		_impact(Color(1, 0.85, 0.45))
	elif not from_player and body.is_in_group("player"):
		if body.has_method("is_dashing") and body.is_dashing():
			return  ## dashed through it
		if body.has_method("take_damage"):
			body.take_damage(damage, source)
		_impact(Color(1, 0.35, 0.25))
	elif body is StaticBody2D or body is TileMap:
		_impact(Color(0.8, 0.7, 0.55))


func _impact(col: Color) -> void:
	_hit = true
	Juice.burst(global_position, col, 6, 140.0, 0.25, 0.8)
	_cleanup()


func _fizzle() -> void:
	_hit = true
	_cleanup()


func _cleanup() -> void:
	set_deferred("monitoring", false)
	if sprite:
		sprite.visible = false
	var tw := _trail.create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
