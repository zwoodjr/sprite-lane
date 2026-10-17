extends Control

## Animated menu backdrop: dusk gradient sky, layered dune silhouettes,
## a slow sun, and drifting dust motes. Pure _draw — cheap on mobile.

var _t: float = 0.0
var _motes: Array[Dictionary] = []
var _sky: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(0.30, 0.15, 0.10))
	g.add_point(0.55, Color(0.55, 0.30, 0.16))
	g.set_color(g.get_point_count() - 1, Color(0.16, 0.10, 0.07))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 128
	_sky = tex
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(70):
		_motes.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": rng.randf_range(0.01, 0.04),
			"s": rng.randf_range(1.0, 3.2),
			"a": rng.randf_range(0.15, 0.55),
			"ph": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, sz), false)
	## Sun
	var sun := Vector2(sz.x * 0.72, sz.y * 0.42 + sin(_t * 0.2) * 4.0)
	for i in range(6):
		draw_circle(sun, 70.0 + i * 26.0, Color(1.0, 0.7, 0.35, 0.05))
	draw_circle(sun, 62.0, Color(1.0, 0.78, 0.45, 0.9))
	## Dunes (three parallax layers)
	_dune(sz, sz.y * 0.62, 38.0, 0.0018, _t * 6.0, Color(0.36, 0.20, 0.12))
	_dune(sz, sz.y * 0.72, 30.0, 0.0026, _t * 12.0 + 300.0, Color(0.25, 0.14, 0.09))
	_dune(sz, sz.y * 0.84, 22.0, 0.0035, _t * 22.0 + 900.0, Color(0.15, 0.09, 0.06))
	## Dust motes
	for m in _motes:
		var p: Vector2 = m["p"]
		var x := fposmod(p.x + _t * float(m["v"]), 1.0) * sz.x
		var y := (p.y + sin(_t * 0.8 + float(m["ph"])) * 0.01) * sz.y
		draw_circle(Vector2(x, y), float(m["s"]), Color(1.0, 0.85, 0.6, float(m["a"])))
	## Bottom vignette
	draw_rect(Rect2(0, sz.y * 0.9, sz.x, sz.y * 0.1), Color(0, 0, 0, 0.25))


func _dune(sz: Vector2, base_y: float, amp: float, freq: float, scroll: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var step := 24.0
	var x := 0.0
	while x <= sz.x + step:
		var xx := x + scroll
		var y := base_y + sin(xx * freq) * amp + sin(xx * freq * 2.3 + 1.7) * amp * 0.4
		pts.append(Vector2(x, y))
		x += step
	pts.append(Vector2(sz.x, sz.y))
	pts.append(Vector2(0, sz.y))
	draw_colored_polygon(pts, col)
