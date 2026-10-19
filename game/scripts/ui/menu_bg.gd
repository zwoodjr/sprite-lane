extends Control

## Animated menu backdrop: painted dusk wasteland (tools/gen_ui_kit.py) with a
## breathing sun glow and drifting dust motes on top. Cheap on mobile.

const BACKDROP := "res://assets/sprites/ui/menu_backdrop.png"

var _t: float = 0.0
var _motes: Array[Dictionary] = []
var _tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(BACKDROP):
		_tex = load(BACKDROP) as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(60):
		_motes.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"v": rng.randf_range(0.008, 0.035),
			"s": rng.randf_range(1.0, 2.8),
			"a": rng.randf_range(0.12, 0.45),
			"ph": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	var cover := Rect2(Vector2.ZERO, sz)
	if _tex:
		## Cover-fit, anchored to the horizon so tall phones show more sky.
		var ts := Vector2(_tex.get_size())
		var k := maxf(sz.x / ts.x, sz.y / ts.y)
		var ds := ts * k
		cover = Rect2((sz - ds) * Vector2(0.5, 0.55), ds)
		draw_texture_rect(_tex, cover, false)
	else:
		draw_rect(cover, Color(0.2, 0.11, 0.08))
	## Sun breathes a little
	var sun := cover.position + cover.size * Vector2(0.68, 0.5)
	var pulse := 0.5 + 0.5 * sin(_t * 0.6)
	for i in range(4):
		draw_circle(sun, (90.0 + i * 38.0) * cover.size.x / 720.0, Color(1.0, 0.72, 0.38, 0.025 + 0.015 * pulse))
	## Dust motes
	for m in _motes:
		var p: Vector2 = m["p"]
		var x := fposmod(p.x + _t * float(m["v"]), 1.0) * sz.x
		var y := (p.y + sin(_t * 0.8 + float(m["ph"])) * 0.01) * sz.y
		draw_rect(Rect2(Vector2(x, y).floor(), Vector2.ONE * roundf(float(m["s"]))), Color(1.0, 0.85, 0.6, float(m["a"])))
