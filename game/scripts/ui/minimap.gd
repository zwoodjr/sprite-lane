extends Control

## Top-down minimap: player, landmarks, extract pads (open vs sealed).

@export var world_radius: float = 2200.0 ## world units shown from center to edge

var _player: Node2D
var _pads: Array = []
var _landmarks: Array = []
var _extract_open: bool = false
var _ping_t: float = 0.0


## New pads placed: rings pulse out from them for a few seconds.
func ping() -> void:
	_ping_t = 3.0


func setup(player: Node2D, pads: Array, landmarks: Array) -> void:
	_player = player
	_pads = pads
	_landmarks = landmarks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func set_pads(pads: Array) -> void:
	_pads = pads


func set_landmarks(landmarks: Array) -> void:
	_landmarks = landmarks


func set_extract_open(is_open: bool) -> void:
	_extract_open = is_open
	queue_redraw()


func _process(delta: float) -> void:
	_ping_t = maxf(0.0, _ping_t - delta)
	queue_redraw()


func _draw() -> void:
	var r := size
	var center := r * 0.5
	var side := minf(r.x, r.y)
	## Painted brass bezel (192 px art: rim 82..95 of a 96 radius).
	var bezel := UiTheme.tex("minimap_bezel")
	var map_r := side * 0.5 * (80.0 / 96.0) if bezel else side * 0.5 - 4.0
	if bezel:
		draw_texture_rect(bezel, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
	else:
		draw_circle(center, map_r, Color(0.22, 0.16, 0.11, 0.75))
		draw_arc(center, map_r, 0, TAU, 48, Color(0.85, 0.65, 0.3, 0.8), 2.0, true)
	if _player == null or not is_instance_valid(_player):
		return
	var origin := _player.global_position
	## Landmarks
	for lm in _landmarks:
		var p: Vector2 = lm["position"]
		var local := _world_to_map(p - origin, map_r)
		if local.length() <= map_r:
			var lp := center + local
			draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -4), lp + Vector2(4, 0), lp + Vector2(0, 4), lp + Vector2(-4, 0)]), Color(0.08, 0.05, 0.03, 0.9))
			draw_colored_polygon(PackedVector2Array([lp + Vector2(0, -3), lp + Vector2(3, 0), lp + Vector2(0, 3), lp + Vector2(-3, 0)]), Color(0.8, 0.45, 0.28, 0.95))
	## Depth Update markers (medicine crates, contracts, cameos): a small plus.
	for mk in get_tree().get_nodes_in_group("map_markers"):
		if not is_instance_valid(mk) or not (mk is Node2D):
			continue
		var lm2 := _world_to_map((mk as Node2D).global_position - origin, map_r)
		if lm2.length() >= map_r - 0.5:
			continue
		var mc: Color = mk.get("map_color") if mk.get("map_color") is Color else Color(1, 0.4, 0.35)
		var mp := center + lm2
		draw_rect(Rect2(mp - Vector2(4, 1.8), Vector2(8, 3.6)), Color(0.06, 0.04, 0.03, 0.9))
		draw_rect(Rect2(mp - Vector2(1.8, 4), Vector2(3.6, 8)), Color(0.06, 0.04, 0.03, 0.9))
		draw_rect(Rect2(mp - Vector2(3, 1), Vector2(6, 2)), mc)
		draw_rect(Rect2(mp - Vector2(1, 3), Vector2(2, 6)), mc)
	## Extract pads
	for pad in _pads:
		if not is_instance_valid(pad):
			continue
		var local2 := _world_to_map(pad.global_position - origin, map_r)
		if local2.length() > map_r:
			continue
		var col := Color(1.0, 0.85, 0.3, 1.0) if _extract_open else Color(0.75, 0.65, 0.4, 1.0)
		if bool(pad.get("last_chance")):
			col = Color(1.0, 0.35, 0.3, 1.0)
		draw_circle(center + local2, 6.0, Color(0.06, 0.04, 0.03, 0.9))
		draw_circle(center + local2, 4.5, col)
		draw_circle(center + local2 + Vector2(-1.2, -1.2), 1.6, Color(1, 1, 0.9, 0.8))
		if _ping_t > 0.0:
			var ph := fmod(3.0 - _ping_t, 1.0)
			draw_arc(center + local2, 4.0 + ph * 16.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 1.0 - ph), 2.0, true)
	## Player
	draw_circle(center, 6.0, Color(0.05, 0.04, 0.03, 0.9))
	draw_circle(center, 4.5, UiTheme.TEAL)
	draw_circle(center + Vector2(-1.2, -1.2), 1.6, Color(0.9, 1.0, 0.95, 0.9))
	## Status plate on the lower rim (fits inside the box at any size).
	var txt := "OPEN" if _extract_open else "SEALED"
	var f: Font = UiTheme.font_button
	var fs := 12
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pr := Rect2(Vector2(center.x - tw * 0.5 - 6, r.y - 17), Vector2(tw + 12, 15))
	draw_rect(pr, Color(0.07, 0.05, 0.035, 0.92))
	draw_rect(pr, Color(0.55, 0.4, 0.22, 0.9), false, 1.0)
	draw_string(f, Vector2(pr.position.x + 6, r.y - 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(1.0, 0.85, 0.35) if _extract_open else Color(0.78, 0.72, 0.62))


func _world_to_map(delta: Vector2, map_r: float) -> Vector2:
	var v := delta / world_radius * map_r
	if v.length() > map_r:
		v = v.limit_length(map_r)
	return v
