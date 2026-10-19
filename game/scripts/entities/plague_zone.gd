extends Node2D

## A drifting patch of plague fog (Depth Update E1, tier 5+). Standing in it
## builds plague exposure (scripts/match/plague_system.gd). Two layered fog
## sprites turn slowly against each other so the cloud churns.

const FOG_TEX := "res://assets/sprites/depth/world/plague_fog.png"

var radius: float = 140.0
var life: float = 45.0
var _t: float = 0.0
var _a: Sprite2D
var _b: Sprite2D


func _ready() -> void:
	add_to_group("plague_zones")
	z_index = -3
	if not ResourceLoader.exists(FOG_TEX):
		return
	var tex: Texture2D = load(FOG_TEX)
	var k := radius * 2.3 / float(tex.get_width())
	## Squash the whole patch onto the ground; the fog layers spin inside it.
	scale = Vector2(1.0, 0.62)
	_a = Sprite2D.new()
	_a.texture = tex
	_a.scale = Vector2(k, k)
	_b = Sprite2D.new()
	_b.texture = tex
	_b.scale = Vector2(k * 0.8, k * 0.8)
	_b.rotation = 1.7
	_b.modulate = Color(0.85, 1.05, 0.8, 0.8)
	add_child(_a)
	add_child(_b)
	modulate.a = 0.0


func contains(p: Vector2) -> bool:
	var d := p - global_position
	d.y /= 0.62
	return d.length() <= radius


func _process(delta: float) -> void:
	_t += delta
	var fade := minf(1.0, _t / 1.5) * clampf((life - _t) / 2.0, 0.0, 1.0)
	modulate.a = fade
	if _a:
		_a.rotation = _t * 0.05
		_b.rotation = 1.7 - _t * 0.08
		_b.position = Vector2(cos(_t * 0.4), sin(_t * 0.3)) * radius * 0.12
	if _t >= life:
		queue_free()
