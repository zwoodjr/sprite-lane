extends Control

## Edge-of-screen arrows pointing at extract pads. Amber when open, muted when sealed.

var _player: Node2D
var _pads: Array = []
var _extract_open: bool = false
var _arrow_tex: Texture2D
var _glyphs: Control
var _g_n: int = 0
var _g_pos := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _g_col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
## Campaign objective markers (meta "map_glyph") draw their own glyph in TEAL.
var _g_id := PackedInt32Array([0, 0, 0, 0, 0, 0])
const C_OBJECTIVE := Color("5cd2c0")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Pad glyphs on a nearest-filtered child (the painted chevron stays smooth).
	_glyphs = Control.new()
	_glyphs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyphs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glyphs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_glyphs)
	_glyphs.draw.connect(func() -> void:
		for i in range(_g_n):
			MapIcons.draw(_glyphs, _g_id[i], _g_pos[i], _g_col[i], 2.0))
	_arrow_tex = UiTheme.tex("extract_arrow")
	if _arrow_tex == null:
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
	_g_n = 0
	if _glyphs:
		_glyphs.queue_redraw()
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
		## Minimap icon language: open = green, sealed = dim, last chance = red.
		var col: Color = MapIcons.C_PAD_OPEN if _extract_open else Color(MapIcons.C_PAD_SEALED, 0.85)
		if bool(pad.get("last_chance")):
			col = MapIcons.C_PAD_LAST
		var objective := (pad as Node).has_meta("map_glyph")
		if objective:
			col = C_OBJECTIVE
		var ang: float = dir.angle() + PI * 0.5
		if _arrow_tex:
			## Painted brass chevron (64 px art) — tinted only for sealed / last chance.
			## Open pads get a bigger, pulsing marker with a light flare behind it.
			var big := 56.0 + 6.0 * sin(Time.get_ticks_msec() * 0.008) if _extract_open else 40.0
			var k := big / float(_arrow_tex.get_width())
			if _extract_open:
				var glow := col
				for gi in 3:
					draw_circle(edge, 30.0 - gi * 8.0, Color(glow, 0.12 + gi * 0.06))
			draw_set_transform(edge, ang, Vector2(k, k))
			var tint := Color(0.6, 1.0, 0.6) if _extract_open else Color(0.75, 0.7, 0.62, 0.85)
			if bool(pad.get("last_chance")):
				tint = Color(1.0, 0.55, 0.45)
			if objective:
				tint = Color(0.62, 1.0, 0.92)
			draw_texture(_arrow_tex, -_arrow_tex.get_size() * 0.5, tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var tip: Vector2 = edge + dir * 12.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir.rotated(0.6) * 18.0, tip - dir.rotated(-0.6) * 18.0]), col)
		## Distance label
		var dist_m := int(_player.global_position.distance_to(pad.global_position) / 10.0)
		var label := "%sm" % dist_m
		if objective:
			pass
		elif _extract_open:
			label = "OPEN " + label
		else:
			label = "SOON " + label
		var f: Font = UiTheme.font_button
		var fs := 20 if _extract_open else 15
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := edge + Vector2(-tw * 0.5 + 9.0, 34)
		if _g_n < _g_pos.size():
			_g_pos[_g_n] = (lp + Vector2(-11.0, -5.0)).round()
			_g_col[_g_n] = col
			_g_id[_g_n] = int((pad as Node).get_meta("map_glyph")) if objective else MapIcons.PAD
			_g_n += 1
		draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.06, 0.04, 0.03, 0.9))
		draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


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
