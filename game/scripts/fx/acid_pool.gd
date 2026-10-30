extends Node2D

## Spitter puddle: drains a little HP while the hero stands in it.
var at: Vector2 = Vector2.ZERO
var radius: float = 52.0
var life: float = 2.2
var tick_every: float = 0.5
var dmg: float = 1.5
var _tick: float = 0.0


func _ready() -> void:
	z_index = -3
	global_position = at


func _process(delta: float) -> void:
	life -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_every
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null and p.global_position.distance_to(at) <= radius and p.has_method("drain"):
			p.call("drain", dmg)
	modulate.a = clampf(life / 0.6, 0.0, 1.0)
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.85, 0.2, 0.28))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.55, 1.0, 0.3, 0.55), 2.0)
