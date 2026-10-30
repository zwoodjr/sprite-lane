extends Node2D

## Spitter acid glob: arcs from the spitter to `to`, splashes, leaves a puddle.
## (Its own script — no inner classes in enemy_behaviors.gd.)
var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var flight: float = 0.5
var dmg: float = 10.0
var radius: float = 52.0
var pool_time: float = 2.2
var pool_tick: float = 0.5
var pool_dmg: float = 1.5
var src: Node = null
var _t: float = 0.0


func _ready() -> void:
	z_index = 50
	global_position = from


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / maxf(flight, 0.01), 0.0, 1.0)
	global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0)
	queue_redraw()
	if k < 1.0:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and p.global_position.distance_to(to) <= radius + 14.0 and p.has_method("take_damage"):
		p.call("take_damage", dmg, src if is_instance_valid(src) else null)
	Juice.fx("ex_plague", to + Vector2(0, -6))
	Juice.sfx_at("hit_flesh", to, -4.0)
	var pool: Node2D = load("res://scripts/fx/acid_pool.gd").new()
	pool.set("at", to)
	pool.set("radius", radius)
	pool.set("life", pool_time)
	pool.set("tick_every", pool_tick)
	pool.set("dmg", pool_dmg)
	get_parent().add_child(pool)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.55, 1.0, 0.3, 0.95))
	draw_circle(Vector2(-2, -2), 3.5, Color(0.9, 1.0, 0.7, 0.9))
