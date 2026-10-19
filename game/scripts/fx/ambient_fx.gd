extends Node2D

## Cheap ambient life on top of the camera's dust motes: an occasional
## tumbleweed bouncing across the view with the wind, and (opt-in setting
## "heat_shimmer", off by default — it needs a screen copy) a faint heat haze.

const TUMBLE_TEX := preload("res://assets/sprites/fx/tumbleweed.png")
const WIND := Vector2(1.0, 0.15)

var _cam: Camera2D
var _next := 6.0
var _weeds: Array[Dictionary] = [] ## {node, vel, t, life}
var _rng := RandomNumberGenerator.new()


func setup(cam: Camera2D) -> void:
	_cam = cam
	top_level = true
	z_index = -1 ## above the floor/props, under units
	_rng.randomize()
	_next = _rng.randf_range(5.0, 12.0)
	if bool(GameState.settings.get("heat_shimmer", false)):
		_add_shimmer()


func _process(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(14.0, 30.0)
		_spawn_weed()
	for i in range(_weeds.size() - 1, -1, -1):
		var w: Dictionary = _weeds[i]
		var n: Node2D = w["node"]
		w["t"] = float(w["t"]) + delta
		var t: float = w["t"]
		var vel: Vector2 = w["vel"]
		## Gusty speed + bounces; spin matches roll speed.
		var gust := 1.0 + 0.35 * sin(t * 1.3 + float(w["ph"]))
		var base: Vector2 = w["base"] + vel * gust * delta
		w["base"] = base
		var hop := absf(sin(t * 4.2 + float(w["ph"]))) * 7.0
		n.position = base
		var spr: Sprite2D = n.get_child(1)
		spr.position.y = -hop - 8.0
		spr.rotation += vel.x * gust * delta / 12.0
		var sh: Sprite2D = n.get_child(0)
		sh.scale = Vector2.ONE * (1.0 - hop / 18.0)
		if t > float(w["life"]):
			n.queue_free()
			_weeds.remove_at(i)


func _spawn_weed() -> void:
	var center := _cam.get_screen_center_position()
	var half := _cam.get_viewport_rect().size / _cam.zoom * 0.5
	var speed := _rng.randf_range(80.0, 130.0)
	var vel := WIND.normalized() * speed
	var start := center + Vector2(-half.x - 40.0, _rng.randf_range(-half.y * 0.8, half.y * 0.6))
	var node := Node2D.new()
	var sh := Sprite2D.new()
	sh.texture = TUMBLE_TEX
	sh.modulate = Color(0, 0, 0, 0.25)
	sh.scale = Vector2.ONE
	sh.position = Vector2(2, 2)
	var spr := Sprite2D.new()
	spr.texture = TUMBLE_TEX
	node.add_child(sh)
	node.add_child(spr)
	add_child(node)
	node.position = start
	_weeds.append({"node": node, "vel": vel, "t": 0.0, "base": start,
		"life": (half.x * 2.0 + 120.0) / (speed * 0.85), "ph": _rng.randf() * TAU})


func _add_shimmer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	layer.follow_viewport_enabled = false
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	// Faint rising heat haze, strongest in slow-moving bands.
	float band = 0.5 + 0.5 * sin(SCREEN_UV.y * 9.0 - TIME * 0.7);
	float wob = sin(SCREEN_UV.y * 140.0 + TIME * 5.0) * sin(SCREEN_UV.x * 23.0 + TIME * 1.3);
	vec2 uv = SCREEN_UV + vec2(wob * 0.0011 * band, 0.0);
	COLOR = texture(screen_tex, uv);
}
"""
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)
