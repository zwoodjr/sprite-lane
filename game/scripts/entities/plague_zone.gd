extends Node2D

## A drifting patch of plague fog (Depth Update E1, tier 5+). Standing in it
## builds plague exposure (scripts/match/plague_system.gd). Pixel fog (style
## bible §1.5 / §5): a looping PLAGUE-ramp cloud strip from tools/gen_fx_px.py
## ("fog_plague_s/m/l", drawn at world size, never scaled), fading in and out
## in the 4 alpha steps.

var radius: float = 140.0
var life: float = 45.0
var _t: float = 0.0
var _fog: AnimatedSprite2D


## Nearest pre-drawn size for a radius (world px).
static func fog_id(prefix: String, r: float, sizes: Array) -> String:
	var best := "_m"
	var bd := INF
	for pair in sizes:
		var d := absf(float(pair[1]) - r)
		if d < bd:
			bd = d
			best = str(pair[0])
	return prefix + best


func _ready() -> void:
	add_to_group("plague_zones")
	z_index = -3
	_fog = AnimatedSprite2D.new()
	var id := fog_id("fog_plague", radius, [["_s", 120.0], ["_m", 145.0], ["_l", 170.0]])
	if Juice.px and bool(Juice.px.call("dress", _fog, id)):
		_fog.z_as_relative = true
		_fog.z_index = 0
		_fog.speed_scale = randf_range(0.85, 1.15)
		add_child(_fog)
		_fog.play("default")
	modulate.a = 0.0


func contains(p: Vector2) -> bool:
	var d := p - global_position
	d.y /= 0.62
	return d.length() <= radius


func _process(delta: float) -> void:
	_t += delta
	var fade := minf(1.0, _t / 1.5) * clampf((life - _t) / 2.0, 0.0, 1.0)
	## 4 hard alpha steps, no smooth fade.
	modulate.a = ceilf(fade * 4.0) / 4.0
	if _t >= life:
		queue_free()
