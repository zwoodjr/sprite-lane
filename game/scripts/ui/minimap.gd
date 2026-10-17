extends Control

## Top-down minimap: player, landmarks, extract pads (open vs sealed).

@export var world_radius: float = 2200.0 ## world units shown from center to edge

var _player: Node2D
var _pads: Array = []
var _landmarks: Array = []
var _extract_open: bool = false


func setup(player: Node2D, pads: Array, landmarks: Array) -> void:
	_player = player
	_pads = pads
	_landmarks = landmarks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(148, 148)


func set_pads(pads: Array) -> void:
	_pads = pads


func set_landmarks(landmarks: Array) -> void:
	_landmarks = landmarks


func set_extract_open(is_open: bool) -> void:
	_extract_open = is_open
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := size
	var center := r * 0.5
	var map_r := mini(r.x, r.y) * 0.5 - 4.0
	## Frame
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.08, 0.06, 0.04, 0.75), true)
	draw_arc(center, map_r, 0, TAU, 48, Color(0.85, 0.65, 0.3, 0.8), 2.0, true)
	draw_circle(center, map_r, Color(0.22, 0.16, 0.11, 0.55))
	if _player == null or not is_instance_valid(_player):
		return
	var origin := _player.global_position
	## Landmarks
	for lm in _landmarks:
		var p: Vector2 = lm["position"]
		var local := _world_to_map(p - origin, map_r)
		if local.length() <= map_r:
			draw_circle(center + local, 3.0, Color(0.75, 0.4, 0.25, 0.9))
	## Extract pads
	for pad in _pads:
		if not is_instance_valid(pad):
			continue
		var local2 := _world_to_map(pad.global_position - origin, map_r)
		if local2.length() > map_r:
			continue
		var col := Color(1.0, 0.85, 0.3, 1.0) if _extract_open else Color(0.45, 0.42, 0.38, 1.0)
		draw_rect(Rect2(center + local2 - Vector2(4, 4), Vector2(8, 8)), col, true)
	## Player
	draw_circle(center, 4.5, Color(0.4, 0.9, 0.45, 1.0))
	draw_arc(center, 4.5, 0, TAU, 16, Color(1, 1, 1, 0.7), 1.0, true)
	## Label
	draw_string(ThemeDB.fallback_font, Vector2(8, 14), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.8, 0.55, 0.85))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(8, r.y - 6),
		"EXTRACT OPEN" if _extract_open else "SEALED",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		10,
		Color(1.0, 0.85, 0.35, 0.9) if _extract_open else Color(0.7, 0.65, 0.55, 0.8)
	)


func _world_to_map(delta: Vector2, map_r: float) -> Vector2:
	var v := delta / world_radius * map_r
	if v.length() > map_r:
		v = v.limit_length(map_r)
	return v
