extends Control

## Edge-of-screen arrows pointing at extract pads. Amber when open, muted when sealed.

var _player: Node2D
var _pads: Array = []
var _extract_open: bool = false
var _arrow_tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_tex = load("res://assets/sprites/ui/extract_arrow.png")


func setup(player: Node2D, pads: Array) -> void:
	_player = player
	_pads = pads
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_pads(pads: Array) -> void:
	_pads = pads


func set_extract_open(is_open: bool) -> void:
	_extract_open = is_open


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var vp := get_viewport_rect().size
	var center := vp * 0.5
	var margin := 72.0 ## clears the extract bar on the left edge
	for pad in _pads:
		if not is_instance_valid(pad):
			continue
		var xform: Transform2D = get_viewport().get_canvas_transform()
		var screen: Vector2 = xform * pad.global_position
		var on_screen: bool = (
			screen.x > 40.0 and screen.x < vp.x - 40.0
			and screen.y > 40.0 and screen.y < vp.y - 40.0
		)
		if on_screen:
			continue
		var dir: Vector2 = (screen - center).normalized()
		if dir.length() < 0.01:
			dir = Vector2.UP
		var edge: Vector2 = _edge_point(center, dir, vp, margin)
		var col: Color = Color(1.0, 0.85, 0.35, 0.95) if _extract_open else Color(0.55, 0.5, 0.45, 0.7)
		var ang: float = dir.angle() + PI * 0.5
		if _arrow_tex:
			draw_set_transform(edge, ang, Vector2(1.1, 1.1))
			draw_texture(_arrow_tex, -_arrow_tex.get_size() * 0.5, col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var tip: Vector2 = edge + dir * 12.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir.rotated(0.6) * 18.0, tip - dir.rotated(-0.6) * 18.0]), col)
		## Distance label
		var dist_m := int(_player.global_position.distance_to(pad.global_position) / 10.0)
		var label := "%sm" % dist_m
		if _extract_open:
			label = "OPEN " + label
		else:
			label = "SEALED " + label
		draw_string(ThemeDB.fallback_font, edge + Vector2(-28, 28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


func _edge_point(center: Vector2, dir: Vector2, vp: Vector2, margin: float) -> Vector2:
	## Intersect ray from center along dir with inset rectangle
	var t_x := INF
	var t_y := INF
	if absf(dir.x) > 0.001:
		var edge_x := (vp.x - margin) if dir.x > 0.0 else margin
		t_x = (edge_x - center.x) / dir.x
	if absf(dir.y) > 0.001:
		var edge_y := (vp.y - margin) if dir.y > 0.0 else margin
		t_y = (edge_y - center.y) / dir.y
	var t := minf(absf(t_x), absf(t_y))
	return center + dir * t
