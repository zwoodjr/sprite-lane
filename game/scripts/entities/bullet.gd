extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var from_player: bool = true
var lifetime: float = 1.4

@onready var poly: Polygon2D = $Poly


func setup(origin: Vector2, dir: Vector2, spd: float, dmg: float, player_shot: bool) -> void:
	global_position = origin
	direction = dir.normalized()
	speed = spd
	damage = dmg
	from_player = player_shot
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if from_player:
		collision_mask = 1 | 4 ## world + enemy
		poly.color = Color(0.95, 0.85, 0.35)
	else:
		collision_mask = 1 | 2 ## world + player
		poly.color = Color(0.9, 0.25, 0.2)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
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
