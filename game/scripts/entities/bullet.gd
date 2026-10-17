extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var from_player: bool = true
var lifetime: float = 1.4

@onready var sprite: Sprite2D = $Sprite


func setup(origin: Vector2, dir: Vector2, spd: float, dmg: float, player_shot: bool) -> void:
	global_position = origin
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = player_shot
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite and sprite.texture == null:
		sprite.texture = load("res://assets/sprites/props/bullet.png")
	if from_player:
		collision_mask = 1 | 4 ## world + enemy (breakables are layer 1)
		if sprite:
			sprite.modulate = Color(0.95, 0.85, 0.35)
	else:
		collision_mask = 1 | 2
		if sprite:
			sprite.modulate = Color(0.9, 0.3, 0.25)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if from_player and body.is_in_group("breakables"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	if from_player and body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif not from_player and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D or body is TileMap:
		queue_free()
